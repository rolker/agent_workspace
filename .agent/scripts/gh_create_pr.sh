#!/bin/bash
# Helper script for creating GitHub pull requests with AI signature
# injection and repo-safety. Mirrors gh_create_issue.sh.
#
# Usage: gh_create_pr.sh [gh pr create options]
#
# Collapses the heredoc + mktemp + `gh pr create --body-file` + cleanup
# sequence (which generates 2-3 permission prompts) into a single
# allowlistable call. Auto-injects the AI signature footer when
# AGENT_NAME / AGENT_MODEL are set.
#
# Examples:
#   # Simple PR with inline body
#   .agent/scripts/gh_create_pr.sh --title "Fix bug" --body "Description"
#
#   # PR with body from file
#   .agent/scripts/gh_create_pr.sh --title "My PR" --body-file /tmp/body.md
#
#   # Body from stdin
#   echo "PR body" | .agent/scripts/gh_create_pr.sh --title "T" --body-stdin
#
#   # Cross-repo
#   .agent/scripts/gh_create_pr.sh -R rolker/agent_workspace --title T --body-file b.md
#
#   # Suppress signature (rare; mostly for revert PRs or human-authored)
#   .agent/scripts/gh_create_pr.sh --title T --body B --no-signature
#
# Behavior:
#   - The command line is read the way gh reads it (_gh_create_args.sh,
#     shared with gh_create_issue.sh): a value-taking flag consumes its
#     value whatever it looks like, and every spelling of the body flags is
#     recognised (--body X, --body=X, -b X, -bX, -b=X, a cluster such as
#     -db X; the same for --body-file / -F).
#   - AI signature footer (Authored-By / Model) is appended unless
#     (a) --no-signature is passed as a flag, or
#     (b) body already contains `**Authored-By**:` (case-sensitive)
#   - AGENT_NAME and AGENT_MODEL env vars MUST be set when signature is
#     to be added; missing vars hard-fail with instructions. Set via:
#     source .agent/scripts/set_git_identity_env.sh "Name" "email" "<model>"
#   - A --body-file (or the --body-stdin drain) is read once into a
#     temporary copy (under TMPDIR, removed on exit), which is what gets
#     signed and what gh reads: a pipe, FIFO or process substitution is
#     signed like a regular file, and the caller's file is never modified.
#   - Labels are validated against .agent/github_metadata.json
#   - Repo-safety: prevents gh from targeting the wrong repo when run
#     from a scratchpad clone or other nested git repo (see issue #72)
#   - Pass-through to `gh pr create` for everything else (--base, --head,
#     --draft, --reviewer, --assignee, --milestone, etc.)
#
# Exit codes:
#   0 - Success
#   1 - Invalid label value (label not in .agent/github_metadata.json)
#   2 - Argument / usage errors:
#         - a value-taking flag with no value (-R/--repo also refuses an
#           empty one)
#         - more than one of {--body, --body-file, --body-stdin} provided
#         - --fill / -f, --fill-first, --fill-verbose, --template / -T or
#           --recover with no body and no --no-signature (gh would write
#           a body this wrapper cannot sign)
#         - a --body-file that cannot be read
#         - repo-safety mismatch (gh would target the wrong remote)
#         - AGENT_NAME / AGENT_MODEL unset when a body is provided and
#           --no-signature was not passed
#   3 - Missing dependencies (gh, jq)

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: This script should be executed, not sourced."
    echo "  Run: ${BASH_SOURCE[0]} $*"
    return 1
fi
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "❌ Error: Not in a git repository"
    exit 3
}

# ---------------------------------------------------- user-tier guard (#265) ---
# This script is promoted to the user tier (.agent/user_tier_scripts.txt), so
# it can be invoked from any cwd on the machine. Refuse outside the workspace
# checkout and outside every registered project root, BEFORE any git/gh call,
# so a stray invocation in an unrelated repo touches nothing. See
# docs/decisions/0016-session-roots-and-the-user-tier.md.
_UT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_project_registry.sh
source "$_UT_SCRIPT_DIR/_project_registry.sh"
registry_require_root "$(cd "$_UT_SCRIPT_DIR/../.." && pwd)" || exit 1

METADATA_FILE="$REPO_ROOT/.agent/github_metadata.json"

if ! command -v gh &>/dev/null; then
    echo "❌ Error: 'gh' (GitHub CLI) is not installed or not in PATH"
    echo "   Install from: https://cli.github.com/"
    exit 3
fi

if ! command -v jq &>/dev/null; then
    echo "❌ Error: 'jq' is not installed or not in PATH"
    echo "   Install with: sudo apt-get install jq (or brew install jq)"
    exit 3
fi

# Parse the command line the way gh does (_gh_create_args.sh, shared with
# gh_create_issue.sh): each value-taking flag consumes its value, whatever
# it looks like, and every spelling (--body X, --body=X, -b X, -bX, -b=X,
# a cluster like -db X) is rewritten to `--body X` so signature injection
# handles one shape. --body-stdin becomes `--body-file -`.
# shellcheck source=_gh_create_args.sh
source "$_UT_SCRIPT_DIR/_gh_create_args.sh"
gh_create_parse pr "$@" || exit 2

# --- Mutually exclusive body sources -----------------------------------------
# Multiple body sources would mean the wrapper signs one source while
# `gh pr create` may use a different one (or error). Either outcome can
# leave the PR unsigned, defeating the strict-policy stance.
_BODY_SOURCE_COUNT=0
[ "$GH_BODY_INDEX" -ge 0 ]           && _BODY_SOURCE_COUNT=$((_BODY_SOURCE_COUNT + 1))
[ "$GH_BODY_FILE_GIVEN" = true ]     && _BODY_SOURCE_COUNT=$((_BODY_SOURCE_COUNT + 1))
[ "$GH_BODY_STDIN" = true ]          && _BODY_SOURCE_COUNT=$((_BODY_SOURCE_COUNT + 1))
if [ "$_BODY_SOURCE_COUNT" -gt 1 ]; then
    echo "❌ Error: --body, --body-file, and --body-stdin are mutually exclusive" >&2
    exit 2
fi

# --fill / -f, --fill-first, --fill-verbose, --template / -T and --recover with no body let gh write the body itself, out of the wrapper's
# reach: refuse unless --no-signature says an unsigned PR is meant.
gh_refuse_unsigned_fill PR && exit 2

# --- Repo-safety check (issue #72) -------------------------------------------
# Prevent gh from targeting the wrong repo when running inside scratchpad
# clones or other nested git repos.
if [ -z "$GH_REPO" ]; then
    _CURRENT_REMOTE=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "")
    _CURRENT_SLUG=$(echo "$_CURRENT_REMOTE" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')

    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _WORKSPACE_ROOT="$(cd "$_SCRIPT_DIR/../.." && pwd)"
    _WS_REMOTE=$(git -C "$_WORKSPACE_ROOT" remote get-url origin 2>/dev/null || echo "")
    _WS_SLUG=$(echo "$_WS_REMOTE" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')

    _PROJECT_SLUG=""
    if [ -d "$_WORKSPACE_ROOT/project" ] && git -C "$_WORKSPACE_ROOT/project" rev-parse --is-inside-work-tree &>/dev/null; then
        _PROJ_REMOTE=$(git -C "$_WORKSPACE_ROOT/project" remote get-url origin 2>/dev/null || echo "")
        _PROJECT_SLUG=$(echo "$_PROJ_REMOTE" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')
    fi

    _SLUG_PATTERN='^[^/[:space:]]+/[^/[:space:]]+$'
    _REPO_OK=false
    if [ -n "$_CURRENT_SLUG" ] && [[ "$_CURRENT_SLUG" =~ $_SLUG_PATTERN ]]; then
        if [ "$_CURRENT_SLUG" = "$_WS_SLUG" ]; then
            _REPO_OK=true
        elif [ -n "$_PROJECT_SLUG" ] && [ "$_CURRENT_SLUG" = "$_PROJECT_SLUG" ]; then
            _REPO_OK=true
        fi
    else
        _REPO_OK=true
    fi

    if [ "$_REPO_OK" = false ]; then
        echo "❌ Error: gh would target '${_CURRENT_SLUG}', which is not the workspace or project repo." >&2
        echo "   Workspace repo: ${_WS_SLUG:-<not detected>}" >&2
        echo "   Project repo:   ${_PROJECT_SLUG:-<not configured>}" >&2
        echo "" >&2
        echo "   You are likely inside a scratchpad clone. Use -R to target the correct repo:" >&2
        echo "   $0 -R ${_WS_SLUG:-owner/repo} [other args]" >&2
        exit 2
    fi
fi

# --- Read the body file once -------------------------------------------------
# A --body-file (or the --body-stdin drain, now `--body-file -`) is read
# once into a temp copy under TMPDIR before anything looks at it: a pipe or
# process substitution can be read only once, and the caller's file is
# never modified. The signature check and the footer both use the copy.
# gh runs as a child (never `exec`) so the EXIT trap always removes it.
GH_BODY_COPY=""
trap 'rm -f "${GH_BODY_COPY:-}"' EXIT
gh_body_copy gh_pr_body.XXXXXX.md || exit 2

# --- AI signature injection --------------------------------------------------
# Append the canonical signature footer unless:
#   - --no-signature was passed
#   - no body was provided at all (interactive `gh pr create` opens an editor)
#   - body already contains **Authored-By**:
# When signature is required but AGENT_NAME / AGENT_MODEL are unset,
# hard-fail with instructions (workspace policy: PRs are signed).
SIG_MARKER='**Authored-By**:'
needs_signature() {
    [ "$GH_NO_SIGNATURE" = true ] && return 1
    # No body input flag at all → interactive editor mode → no injection.
    # `--body ""` counts as flag-present (non-interactive) and will be signed,
    # so it does NOT take this branch.
    [ "$GH_BODY_INDEX" -lt 0 ] && [ "$GH_BODY_FILE_INDEX" -lt 0 ] && return 1
    gh_body_is_signed "$SIG_MARKER" && return 1
    return 0
}

if needs_signature; then
    if [ -z "${AGENT_NAME:-}" ] || [ -z "${AGENT_MODEL:-}" ]; then
        echo "❌ Error: AGENT_NAME and/or AGENT_MODEL are unset; cannot sign PR." >&2
        echo "" >&2
        echo "   Set them via:" >&2
        echo "     source .agent/scripts/set_git_identity_env.sh \"Name\" \"email\" \"<model>\"" >&2
        echo "" >&2
        echo "   Or pass --no-signature to skip signing (rare; revert PRs only)." >&2
        exit 2
    fi

    SIG_BLOCK=$(printf '\n\n---\n**Authored-By**: `%s`\n**Model**: `%s`\n' \
                       "$AGENT_NAME" "$AGENT_MODEL")

    if [ "$GH_BODY_INDEX" -ge 0 ]; then
        GH_ARGS[$GH_BODY_INDEX]="${GH_ARGS[$GH_BODY_INDEX]}${SIG_BLOCK}"
    else
        printf '%s' "$SIG_BLOCK" >> "$GH_BODY_COPY"
    fi
fi

# The wrapper-only --no-signature and --body-stdin never reached GH_ARGS.
FINAL_ARGS=("${GH_ARGS[@]}")

# --- Label validation -------------------------------------------------------
# Skip when no labels were passed or metadata file is absent.
#
# We invoke `gh pr create` without `exec` because `exec` replaces the shell
# process and skips the EXIT trap, which would leak the body copy.
if [ ${#GH_LABELS[@]} -eq 0 ]; then
    echo "ℹ️  No labels specified, passing through to 'gh pr create'"
    gh pr create "${FINAL_ARGS[@]}"
    exit $?
fi

if [ ! -f "$METADATA_FILE" ]; then
    echo "⚠️  Warning: $METADATA_FILE not found"
    echo "   Skipping label validation. Labels will be validated by GitHub."
    gh pr create "${FINAL_ARGS[@]}"
    exit $?
fi

VALID_LABELS=$(jq -r '.labels[]' "$METADATA_FILE" 2>/dev/null) || {
    echo "⚠️  Warning: Failed to parse $METADATA_FILE"
    echo "   Skipping label validation."
    gh pr create "${FINAL_ARGS[@]}"
    exit $?
}

INVALID_LABELS=()
for label in "${GH_LABELS[@]}"; do
    # `--` terminates grep option parsing so labels starting with `-`
    # are not misread as flags (matters under ugrep / stricter grep).
    if ! echo "$VALID_LABELS" | grep -Fxq -- "$label"; then
        INVALID_LABELS+=("$label")
    fi
done

if [ ${#INVALID_LABELS[@]} -gt 0 ]; then
    echo "❌ Invalid label(s) detected: ${INVALID_LABELS[*]}"
    echo ""
    echo "Valid labels (from $METADATA_FILE):"
    echo "$VALID_LABELS" | sed 's/^/  - /'
    echo ""
    echo "To add a new label to the repository:"
    echo "  1. Create it: gh label create '<name>' --description '<desc>' --color '<hex>'"
    echo "  2. Update $METADATA_FILE"
    exit 1
fi

echo "✅ All labels valid, creating PR..."
gh pr create "${FINAL_ARGS[@]}"
exit $?
