#!/bin/bash
# Helper script for creating GitHub issues with label validation and AI
# signature injection. Mirrors gh_create_pr.sh's signature contract.
# Usage: gh_create_issue.sh [gh issue create options] [--no-signature]
#
# This script wraps 'gh issue create' and validates labels against .agent/github_metadata.json
# before calling the GitHub CLI. This prevents failures from invalid label names.
#
# Examples:
#   # Create issue with labels
#   .agent/scripts/gh_create_issue.sh --title "Fix bug" --body "Description" --label "bug" --label "enhancement"
#
#   # Create issue with body from file
#   .agent/scripts/gh_create_issue.sh --title "My Issue" --body-file /tmp/body.md --label "documentation"
#
#   # Suppress signature (rare; human-authored issues)
#   .agent/scripts/gh_create_issue.sh --title T --body B --no-signature
#
#   # Interactive mode (no validation since labels selected from GitHub)
#   .agent/scripts/gh_create_issue.sh
#
# Note: Labels with spaces should be quoted: --label "good first issue"
#
# Behavior:
#   - The command line is read the way gh reads it (_gh_create_args.sh):
#     a value-taking flag consumes its value whatever it looks like, and
#     every spelling of the body flags is recognised (--body X, --body=X,
#     -b X, -bX, -b=X, a cluster such as -wb X; the same for
#     --body-file / -F).
#   - AI signature footer (Authored-By / Model) is appended to the body
#     unless
#     (a) --no-signature is passed as a flag (stripped before gh), or
#     (b) the body already contains `**Authored-By**:` (case-sensitive)
#   - AGENT_NAME and AGENT_MODEL env vars MUST be set when the signature is
#     to be added; missing vars hard-fail (exit 2) before any gh call. Set via:
#     source .agent/scripts/set_git_identity_env.sh "Name" "email" "<model>"
#   - No body flag at all (interactive editor mode) means nothing is signed.
#   - A --body-file is read once into a temporary copy (under TMPDIR,
#     removed on exit), which is what gets signed and what gh reads: a
#     pipe, FIFO or process substitution is signed like a regular file,
#     and the caller's file is never modified. The footer comes after the
#     auto-added parent reference, and the git-bug path is signed too.
#
# Exit codes:
#   0 - Success
#   1 - Invalid label detected
#   2 - Argument / usage errors:
#         - a value-taking flag with no value (-R/--repo also refuses an
#           empty one)
#         - both a body and a body file provided
#         - --template / -T with no body, or --recover with or without
#           one, and no --no-signature (gh would write a body this wrapper
#           cannot sign)
#         - a --body-file that cannot be read
#         - repo-safety mismatch (gh would target the wrong remote)
#         - AGENT_NAME / AGENT_MODEL unset when a body is provided and
#           --no-signature was not passed
#   3 - Missing dependencies

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: This script should be executed, not sourced."
    echo "  Run: ${BASH_SOURCE[0]} $*"
    return 1
fi
set -euo pipefail

# Get repository root
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

# Check for required dependencies
if ! command -v gh &> /dev/null; then
    echo "❌ Error: 'gh' (GitHub CLI) is not installed or not in PATH"
    echo "   Install from: https://cli.github.com/"
    exit 3
fi

if ! command -v jq &> /dev/null; then
    echo "❌ Error: 'jq' is not installed or not in PATH"
    echo "   Install with: sudo apt-get install jq (or brew install jq)"
    exit 3
fi

# Parse the command line the way gh does (_gh_create_args.sh): each
# value-taking flag consumes its value, whatever it looks like, and every
# spelling (--body X, --body=X, -b X, -bX, -b=X, a cluster like -wb X) is
# rewritten to `--body X` so the injections below handle one shape. The
# result is GH_ARGS plus the indexes of the values the wrapper reads.
# shellcheck source=_gh_create_args.sh
source "$_UT_SCRIPT_DIR/_gh_create_args.sh"
gh_create_parse issue "$@" || exit 2

# --- Mutually exclusive body sources -----------------------------------------
# Both would mean the wrapper signs one source while gh may use the other
# (or error), leaving the issue unsigned.
if [ "$GH_BODY_INDEX" -ge 0 ] && [ "$GH_BODY_FILE_INDEX" -ge 0 ]; then
    echo "❌ Error: --body and --body-file are mutually exclusive" >&2
    exit 2
fi

# --template / -T with no body, and --recover with or without one, let gh
# write the body itself, out of the wrapper's reach: refuse unless
# --no-signature says an unsigned issue is meant.
gh_refuse_unsigned_fill issue && exit 2

# A --body-file is read once into a temp copy (under TMPDIR, removed on
# exit) before anything looks at it: a pipe or process substitution can be
# read only once, and the caller's file is never modified. Every check and
# injection below reads and appends to the copy. gh runs as a child (never
# `exec`) so the EXIT trap always fires.
GH_BODY_COPY=""
trap 'rm -f "${GH_BODY_COPY:-}"' EXIT
gh_body_copy gh_issue_body.XXXXXX.md || exit 2

# --- AI signature: decide, and hard-fail before any gh call -------------------
# Sign unless --no-signature, no body flag at all (interactive editor mode),
# or the body already contains the marker. The footer itself is appended
# after the parent-ref injection below, so it stays last.
SIG_MARKER='**Authored-By**:'
needs_signature() {
    [ "$GH_NO_SIGNATURE" = true ] && return 1
    [ "$GH_BODY_INDEX" -lt 0 ] && [ "$GH_BODY_FILE_INDEX" -lt 0 ] && return 1
    gh_body_is_signed "$SIG_MARKER" && return 1
    return 0
}

SIGN_BODY=false
if needs_signature; then
    if [ -z "${AGENT_NAME:-}" ] || [ -z "${AGENT_MODEL:-}" ]; then
        echo "❌ Error: AGENT_NAME and/or AGENT_MODEL are unset; cannot sign issue." >&2
        echo "" >&2
        echo "   Set them via:" >&2
        echo "     source .agent/scripts/set_git_identity_env.sh \"Name\" \"email\" \"<model>\"" >&2
        echo "" >&2
        echo "   Or pass --no-signature to skip signing (rare; human-authored issues only)." >&2
        exit 2
    fi
    SIGN_BODY=true
fi

# --- Repo-safety check ---
# Prevent gh from targeting the wrong repo when running inside scratchpad
# clones or other nested git repos (see issue #72).
if [ -z "$GH_REPO" ]; then
    # Extract slug from current repo's remote
    _CURRENT_REMOTE=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "")
    _CURRENT_SLUG=$(echo "$_CURRENT_REMOTE" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')

    # Extract workspace repo slug
    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _WORKSPACE_ROOT="$(cd "$_SCRIPT_DIR/../.." && pwd)"
    _WS_REMOTE=$(git -C "$_WORKSPACE_ROOT" remote get-url origin 2>/dev/null || echo "")
    _WS_SLUG=$(echo "$_WS_REMOTE" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')

    # Extract project repo slug (if configured)
    _PROJECT_SLUG=""
    if [ -d "$_WORKSPACE_ROOT/project" ] && git -C "$_WORKSPACE_ROOT/project" rev-parse --is-inside-work-tree &>/dev/null; then
        _PROJ_REMOTE=$(git -C "$_WORKSPACE_ROOT/project" remote get-url origin 2>/dev/null || echo "")
        _PROJECT_SLUG=$(echo "$_PROJ_REMOTE" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')
    fi

    # Every registered root's repository (issue #295): a project session runs
    # from the project's own checkout, so it is accepted because it is
    # registered in this checkout's .agent/projects.local. _PROJECT_SLUGS is
    # the whole accepted project set, one per line.
    _PROJECT_SLUGS="$(registry_repo_slugs "$_WORKSPACE_ROOT")"
    if [ -n "$_PROJECT_SLUG" ]; then
        _PROJECT_SLUGS="$(printf '%s\n%s' "$_PROJECT_SLUG" "$_PROJECT_SLUGS")"
    fi
    _PROJECT_SLUGS="$(printf '%s\n' "$_PROJECT_SLUGS" | awk 'NF && !seen[$0]++')"

    # Validate slug format (owner/repo) before comparing — non-GitHub remotes
    # (enterprise hosts, SSH aliases, GitLab) produce slugs that won't match.
    # Skip the safety check rather than false-positive aborting.
    _SLUG_PATTERN='^[^/[:space:]]+/[^/[:space:]]+$'

    # Check if current repo matches workspace or project
    _REPO_OK=false
    if [ -n "$_CURRENT_SLUG" ] && [[ "$_CURRENT_SLUG" =~ $_SLUG_PATTERN ]]; then
        if [ "$_CURRENT_SLUG" = "$_WS_SLUG" ]; then
            _REPO_OK=true
        elif [ -n "$_PROJECT_SLUGS" ] && grep -qxF -- "$_CURRENT_SLUG" <<< "$_PROJECT_SLUGS"; then
            _REPO_OK=true
        fi
    else
        # Slug is empty or not in owner/repo format — can't validate, allow through
        _REPO_OK=true
    fi

    if [ "$_REPO_OK" = false ]; then
        echo "❌ Error: gh would target '${_CURRENT_SLUG}', which is not the workspace or project repo." >&2
        echo "   Workspace repo: ${_WS_SLUG:-<not detected>}" >&2
        if [ -n "$_PROJECT_SLUGS" ]; then
            echo "   Project repo:   $(printf '%s' "$_PROJECT_SLUGS" | paste -sd, - | sed 's/,/, /g')" >&2
        else
            echo "   Project repo:   <none registered>" >&2
        fi
        echo "" >&2
        echo "   You are likely inside a scratchpad clone. Use -R to target the correct repo:" >&2
        echo "   $0 -R ${_WS_SLUG:-owner/repo} [other args]" >&2
        exit 2
    fi
fi

# Auto-inject parent issue reference when $WORKTREE_ISSUE is set
if [ -n "${WORKTREE_ISSUE:-}" ]; then
    # Determine the correct issue reference format (cross-repo vs same-repo)
    PARENT_REF="#${WORKTREE_ISSUE}"
    CURRENT_REPO_SLUG=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
    WORKSPACE_REPO_SLUG=""
    WORKSPACE_ROOT="$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$REPO_ROOT")"
    if [ -n "$WORKSPACE_ROOT" ] && git -C "$WORKSPACE_ROOT" remote get-url origin &>/dev/null; then
        _WS_URL=$(git -C "$WORKSPACE_ROOT" remote get-url origin)
        WORKSPACE_REPO_SLUG=$(echo "$_WS_URL" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')
    fi
    if [ -n "$CURRENT_REPO_SLUG" ] && [ -n "$WORKSPACE_REPO_SLUG" ] && [ "$CURRENT_REPO_SLUG" != "$WORKSPACE_REPO_SLUG" ]; then
        PARENT_REF="${WORKSPACE_REPO_SLUG}#${WORKTREE_ISSUE}"
    fi

    # Check if body already references the parent issue. Word-boundary
    # regex avoids substring false positives (e.g., #12 matching #123); a
    # bash match, not a pipe, so a long body cannot cut the check short.
    NEEDS_INJECTION=true
    _PARENT_PATTERN="(^|[^0-9])#${WORKTREE_ISSUE}([^0-9]|$)"
    if [ "$GH_BODY_INDEX" -ge 0 ]; then
        [[ "${GH_ARGS[$GH_BODY_INDEX]}" =~ $_PARENT_PATTERN ]] && NEEDS_INJECTION=false
    elif [ -n "$GH_BODY_COPY" ]; then
        grep -Eq -- "$_PARENT_PATTERN" "$GH_BODY_COPY" && NEEDS_INJECTION=false
    fi

    if [ "$NEEDS_INJECTION" = true ]; then
        if [ "$GH_BODY_INDEX" -ge 0 ]; then
            # Append to --body value
            GH_ARGS[$GH_BODY_INDEX]="${GH_ARGS[$GH_BODY_INDEX]}

Part of ${PARENT_REF}"
            echo "ℹ️  Auto-added parent reference: Part of ${PARENT_REF}"
        elif [ -n "$GH_BODY_COPY" ]; then
            # Append to the temp copy; the caller's file is never modified
            printf '\n\nPart of %s\n' "$PARENT_REF" >> "$GH_BODY_COPY"
            echo "ℹ️  Auto-added parent reference: Part of ${PARENT_REF}"
        else
            echo "⚠️  No --body or --body-file provided; cannot auto-inject parent reference (Part of ${PARENT_REF})"
        fi
    fi
fi

# --- AI signature injection --------------------------------------------------
# After the parent reference (so the footer stays last) and before the
# git-bug path (so git-bug issues are signed too). The wrapper-only
# --no-signature never reached GH_ARGS.
if [ "$SIGN_BODY" = true ]; then
    SIG_BLOCK=$(printf '\n\n---\n**Authored-By**: `%s`\n**Model**: `%s`\n' \
                       "$AGENT_NAME" "$AGENT_MODEL")
    if [ "$GH_BODY_INDEX" -ge 0 ]; then
        GH_ARGS[$GH_BODY_INDEX]="${GH_ARGS[$GH_BODY_INDEX]}${SIG_BLOCK}"
    else
        printf '%s' "$SIG_BLOCK" >> "$GH_BODY_COPY"
    fi
fi

# Optional: create via git-bug + push (offline-capable, opt-in via GITBUG_CREATE=1)
# Placed before label validation so it's reachable with or without labels.
if [ "${GITBUG_CREATE:-}" = "1" ] && command -v git-bug &>/dev/null; then
    _TITLE=""
    _BODY=""
    [ "$GH_TITLE_INDEX" -ge 0 ] && _TITLE="${GH_ARGS[$GH_TITLE_INDEX]}"
    if [ "$GH_BODY_INDEX" -ge 0 ]; then
        _BODY="${GH_ARGS[$GH_BODY_INDEX]}"
    elif [ -n "$GH_BODY_COPY" ]; then
        _BODY=$(cat "$GH_BODY_COPY")
    fi
    if [ ${#GH_LABELS[@]} -gt 0 ]; then
        echo "⚠️  This script's git-bug path does not apply labels — labels will be skipped."
        echo "   Add labels manually after sync, or unset GITBUG_CREATE to use gh CLI."
    fi
    if [ -n "$_TITLE" ]; then
        _GB_ARGS=(--title "$_TITLE")
        if [ -n "$_BODY" ]; then
            _GB_ARGS+=(--message "$_BODY")
        fi
        if git bug new "${_GB_ARGS[@]}" 2>/dev/null; then
            if git bug bridge push github 2>/dev/null; then
                echo "✅ Issue created via git-bug and synced to GitHub"
            else
                echo "✅ Issue created locally via git-bug"
                echo "⚠️  git bug bridge push failed — sync manually with: git bug bridge push github"
            fi
            exit 0
        else
            echo "⚠️  git-bug create failed — falling through to gh CLI"
        fi
    fi
fi

# If no labels specified or metadata file doesn't exist, just pass through to gh
if [ ${#GH_LABELS[@]} -eq 0 ]; then
    echo "ℹ️  No labels specified, passing through to 'gh issue create'"
    gh issue create "${GH_ARGS[@]}"; exit $?
fi

if [ ! -f "$METADATA_FILE" ]; then
    echo "⚠️  Warning: $METADATA_FILE not found"
    echo "   Skipping label validation. Labels will be validated by GitHub."
    echo "   To enable validation, create the metadata file with valid labels."
    gh issue create "${GH_ARGS[@]}"; exit $?
fi

# Load valid labels from metadata
VALID_LABELS=$(jq -r '.labels[]' "$METADATA_FILE" 2>/dev/null) || {
    echo "⚠️  Warning: Failed to parse $METADATA_FILE"
    echo "   Skipping label validation."
    gh issue create "${GH_ARGS[@]}"; exit $?
}

# Validate each label
# `--` terminates grep option parsing so labels starting with `-` are not
# misread as flags (matters under ugrep / stricter grep).
INVALID_LABELS=()
for label in "${GH_LABELS[@]}"; do
    if ! echo "$VALID_LABELS" | grep -Fxq -- "$label"; then
        INVALID_LABELS+=("$label")
    fi
done

# If invalid labels found, report and exit
if [ ${#INVALID_LABELS[@]} -gt 0 ]; then
    echo "❌ Invalid label(s) detected: ${INVALID_LABELS[*]}"
    echo ""
    echo "Valid labels (from $METADATA_FILE):"
    echo "$VALID_LABELS" | sed 's/^/  - /'
    echo ""
    echo "To add a new label to the repository:"
    echo "  1. Create it: gh label create '<name>' --description '<desc>' --color '<hex>'"
    echo "  2. Update $METADATA_FILE"
    echo ""
    echo "Or fetch current labels: gh label list --json name --jq '.[].name' | sort"
    exit 1
fi

# All labels valid, proceed with gh issue create.
# Not `exec`: exec replaces the shell and skips the EXIT trap, which would
# leak the temp body copy.
echo "✅ All labels valid, creating issue..."
gh issue create "${GH_ARGS[@]}"
exit $?
