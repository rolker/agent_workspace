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
#   - AI signature footer (Authored-By / Model) is appended unless
#     (a) --no-signature is passed, or
#     (b) body already contains `**Authored-By**:` (case-sensitive)
#   - AGENT_NAME and AGENT_MODEL env vars MUST be set when signature is
#     to be added; missing vars hard-fail with instructions. Set via:
#     source .agent/scripts/set_git_identity_env.sh "Name" "email" "<model>"
#   - Labels are validated against .agent/github_metadata.json
#   - Repo-safety: prevents gh from targeting the wrong repo when run
#     from a scratchpad clone or other nested git repo (see issue #72)
#   - Pass-through to `gh pr create` for everything else (--base, --head,
#     --draft, --reviewer, --assignee, --milestone, etc.)
#
# Exit codes:
#   0 - Success
#   1 - Invalid label detected
#   2 - Invalid arguments (bad label, missing -R value, repo mismatch,
#       or unset AGENT_NAME/AGENT_MODEL without --no-signature)
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

# Normalize joined-equals flag forms (--flag=VALUE → --flag VALUE) so the
# downstream parse + rewrite logic only has to handle one shape per flag.
# Without this, rewriting `ORIGINAL_ARGS[i]` for signature injection would
# drop the `--body=` / `--body-file=` prefix.
_RAW_ARGS=("$@")
ORIGINAL_ARGS=()
for arg in "${_RAW_ARGS[@]}"; do
    case "$arg" in
        --body=*)      ORIGINAL_ARGS+=(--body "${arg#*=}") ;;
        --body-file=*) ORIGINAL_ARGS+=(--body-file "${arg#*=}") ;;
        --repo=*)      ORIGINAL_ARGS+=(--repo "${arg#*=}") ;;
        --label=*)     ORIGINAL_ARGS+=(--label "${arg#*=}") ;;
        *)             ORIGINAL_ARGS+=("$arg") ;;
    esac
done

# Parse command-line arguments. We need to know:
#   - --label / -l values (for validation)
#   - -R / --repo value (for repo-safety check)
#   - --body / --body-file / --body-stdin (for signature injection)
#   - --no-signature (skip footer)
LABELS=()
EXPLICIT_REPO=""
NO_SIGNATURE=false
BODY_TEXT=""
BODY_FILE_PATH=""
BODY_STDIN=false
BODY_FLAG_PRESENT=false
BODY_ARG_INDEX=-1
BODY_FILE_ARG_INDEX=-1

i=0
while [ $i -lt ${#ORIGINAL_ARGS[@]} ]; do
    arg="${ORIGINAL_ARGS[$i]}"
    case "$arg" in
        -R|--repo)
            if [ -n "${ORIGINAL_ARGS[$((i+1))]:-}" ]; then
                EXPLICIT_REPO="${ORIGINAL_ARGS[$((i+1))]}"
                i=$((i + 2))
            else
                echo "❌ Error: -R/--repo requires a value (owner/repo)" >&2
                exit 2
            fi
            ;;
        --label|-l)
            if [ -n "${ORIGINAL_ARGS[$((i+1))]:-}" ]; then
                LABELS+=("${ORIGINAL_ARGS[$((i+1))]}")
                i=$((i + 2))
            else
                i=$((i + 1))
            fi
            ;;
        --body)
            # Track flag presence separately from content so `--body ""`
            # is still recognized as non-interactive (would otherwise
            # collapse into the "no body provided → editor mode" branch
            # in needs_signature()).
            BODY_FLAG_PRESENT=true
            if [ $((i + 1)) -lt ${#ORIGINAL_ARGS[@]} ]; then
                BODY_TEXT="${ORIGINAL_ARGS[$((i+1))]}"
                BODY_ARG_INDEX=$((i + 1))
                i=$((i + 2))
            else
                i=$((i + 1))
            fi
            ;;
        --body-file)
            if [ -n "${ORIGINAL_ARGS[$((i+1))]:-}" ]; then
                BODY_FILE_PATH="${ORIGINAL_ARGS[$((i+1))]}"
                BODY_FILE_ARG_INDEX=$((i + 1))
                i=$((i + 2))
            else
                i=$((i + 1))
            fi
            ;;
        --body-stdin)
            BODY_STDIN=true
            i=$((i + 1))
            ;;
        --no-signature)
            NO_SIGNATURE=true
            i=$((i + 1))
            ;;
        *)
            i=$((i + 1))
            ;;
    esac
done

# --- Repo-safety check (issue #72) -------------------------------------------
# Prevent gh from targeting the wrong repo when running inside scratchpad
# clones or other nested git repos.
if [ -z "$EXPLICIT_REPO" ]; then
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

# --- Drain --body-stdin (always; wrapper-only flag) --------------------------
# `--body-stdin` is not understood by `gh pr create`. Always rewrite it to
# `--body-file <tmp>` regardless of signature decision; otherwise the flag
# leaks through to gh and fails as "unknown flag".
if [ "$BODY_STDIN" = true ]; then
    STDIN_BODY_FILE=$(mktemp /tmp/gh_pr_body.XXXXXX.md)
    trap 'rm -f "$STDIN_BODY_FILE"' EXIT
    cat > "$STDIN_BODY_FILE"
    NEW_ARGS=()
    for arg in "${ORIGINAL_ARGS[@]}"; do
        if [ "$arg" = "--body-stdin" ]; then
            NEW_ARGS+=(--body-file "$STDIN_BODY_FILE")
        else
            NEW_ARGS+=("$arg")
        fi
    done
    ORIGINAL_ARGS=("${NEW_ARGS[@]}")
    BODY_FILE_PATH="$STDIN_BODY_FILE"
    # Find the new --body-file value's index so signature injection can rewrite it.
    for (( j=0; j<${#ORIGINAL_ARGS[@]}; j++ )); do
        if [ "${ORIGINAL_ARGS[$j]}" = "--body-file" ]; then
            BODY_FILE_ARG_INDEX=$((j + 1))
            break
        fi
    done
fi

# --- AI signature injection --------------------------------------------------
# Append the canonical signature footer unless:
#   - --no-signature was passed
#   - no body was provided at all (interactive `gh pr create` opens an editor)
#   - body already contains **Authored-By**:
# When signature is required but AGENT_NAME / AGENT_MODEL are unset,
# hard-fail with instructions (workspace policy: PRs are signed).
SIG_MARKER='**Authored-By**:'
needs_signature() {
    [ "$NO_SIGNATURE" = true ] && return 1
    # No body input flag at all → interactive editor mode → no injection.
    # `--body ""` counts as flag-present (non-interactive) and will be signed,
    # so it does NOT take this branch.
    [ "$BODY_FLAG_PRESENT" = false ] && [ -z "$BODY_FILE_PATH" ] && return 1
    # Already signed (catches stdin-drained content too, since BODY_FILE_PATH
    # now points at the temp file)
    if [ "$BODY_FLAG_PRESENT" = true ] && [ -n "$BODY_TEXT" ]; then
        printf '%s' "$BODY_TEXT" | grep -Fq "$SIG_MARKER" && return 1
    elif [ -n "$BODY_FILE_PATH" ] && [ -f "$BODY_FILE_PATH" ]; then
        grep -Fq "$SIG_MARKER" "$BODY_FILE_PATH" && return 1
    fi
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

    if [ "$BODY_FLAG_PRESENT" = true ] && [ "$BODY_ARG_INDEX" -ge 0 ]; then
        ORIGINAL_ARGS[$BODY_ARG_INDEX]="${BODY_TEXT}${SIG_BLOCK}"
    elif [ -n "$BODY_FILE_PATH" ] && [ -f "$BODY_FILE_PATH" ]; then
        # Append directly to the existing temp file (for stdin) or copy+append
        # for a user-provided body file. Either way, the on-disk file gets the
        # signature and gh sees the same --body-file path.
        if [ "$BODY_STDIN" = true ]; then
            printf '%s' "$SIG_BLOCK" >> "$BODY_FILE_PATH"
        else
            SIGNED_BODY_FILE=$(mktemp /tmp/gh_pr_body.XXXXXX.md)
            trap 'rm -f "$SIGNED_BODY_FILE" "${STDIN_BODY_FILE:-}"' EXIT
            cp "$BODY_FILE_PATH" "$SIGNED_BODY_FILE"
            printf '%s' "$SIG_BLOCK" >> "$SIGNED_BODY_FILE"
            ORIGINAL_ARGS[$BODY_FILE_ARG_INDEX]="$SIGNED_BODY_FILE"
        fi
    fi
fi

# Strip the wrapper-only flag before invoking gh
FINAL_ARGS=()
for arg in "${ORIGINAL_ARGS[@]}"; do
    [ "$arg" = "--no-signature" ] && continue
    FINAL_ARGS+=("$arg")
done

# --- Label validation -------------------------------------------------------
# Skip when no labels were passed or metadata file is absent.
#
# We invoke `gh pr create` without `exec` because `exec` replaces the shell
# process and skips the EXIT trap, which would leak STDIN_BODY_FILE and
# SIGNED_BODY_FILE in /tmp.
if [ ${#LABELS[@]} -eq 0 ]; then
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
for label in "${LABELS[@]}"; do
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
