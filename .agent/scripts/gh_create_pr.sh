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

# Parse command-line arguments. We need to know:
#   - --label / -l values (for validation)
#   - -R / --repo value (for repo-safety check)
#   - --body / --body-file / --body-stdin (for signature injection)
#   - --no-signature (skip footer)
ORIGINAL_ARGS=("$@")

LABELS=()
EXPLICIT_REPO=""
NO_SIGNATURE=false
BODY_TEXT=""
BODY_FILE_PATH=""
BODY_STDIN=false
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
        --repo=*)
            EXPLICIT_REPO="${arg#*=}"
            i=$((i + 1))
            ;;
        --label|-l)
            if [ -n "${ORIGINAL_ARGS[$((i+1))]:-}" ]; then
                LABELS+=("${ORIGINAL_ARGS[$((i+1))]}")
                i=$((i + 2))
            else
                i=$((i + 1))
            fi
            ;;
        --label=*)
            LABELS+=("${arg#*=}")
            i=$((i + 1))
            ;;
        --body)
            if [ -n "${ORIGINAL_ARGS[$((i+1))]:-}" ]; then
                BODY_TEXT="${ORIGINAL_ARGS[$((i+1))]}"
                BODY_ARG_INDEX=$((i + 1))
                i=$((i + 2))
            else
                i=$((i + 1))
            fi
            ;;
        --body=*)
            BODY_TEXT="${arg#*=}"
            BODY_ARG_INDEX=$i
            i=$((i + 1))
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
        --body-file=*)
            BODY_FILE_PATH="${arg#*=}"
            BODY_FILE_ARG_INDEX=$i
            i=$((i + 1))
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

# --- AI signature injection --------------------------------------------------
# Append the canonical signature footer unless:
#   - --no-signature was passed
#   - body already contains **Authored-By**:
# When signature is required but AGENT_NAME / AGENT_MODEL are unset,
# hard-fail with instructions (workspace policy: PRs are signed).
SIG_MARKER='**Authored-By**:'
needs_signature() {
    [ "$NO_SIGNATURE" = true ] && return 1
    if [ -n "$BODY_TEXT" ]; then
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

    if [ -n "$BODY_TEXT" ]; then
        ORIGINAL_ARGS[$BODY_ARG_INDEX]="${BODY_TEXT}${SIG_BLOCK}"
    elif [ -n "$BODY_FILE_PATH" ] && [ -f "$BODY_FILE_PATH" ]; then
        SIGNED_BODY_FILE=$(mktemp /tmp/gh_pr_body.XXXXXX.md)
        trap 'rm -f "$SIGNED_BODY_FILE"' EXIT
        cp "$BODY_FILE_PATH" "$SIGNED_BODY_FILE"
        printf '%s' "$SIG_BLOCK" >> "$SIGNED_BODY_FILE"
        ORIGINAL_ARGS[$BODY_FILE_ARG_INDEX]="$SIGNED_BODY_FILE"
    elif [ "$BODY_STDIN" = true ]; then
        # Drain stdin, append signature, then convert --body-stdin to --body-file
        SIGNED_BODY_FILE=$(mktemp /tmp/gh_pr_body.XXXXXX.md)
        trap 'rm -f "$SIGNED_BODY_FILE"' EXIT
        cat > "$SIGNED_BODY_FILE"
        printf '%s' "$SIG_BLOCK" >> "$SIGNED_BODY_FILE"
        # Rewrite ORIGINAL_ARGS: --body-stdin → --body-file <path>
        NEW_ARGS=()
        for arg in "${ORIGINAL_ARGS[@]}"; do
            if [ "$arg" = "--body-stdin" ]; then
                NEW_ARGS+=(--body-file "$SIGNED_BODY_FILE")
            else
                NEW_ARGS+=("$arg")
            fi
        done
        ORIGINAL_ARGS=("${NEW_ARGS[@]}")
    fi
    # If no body was provided at all, we leave args alone; gh pr create
    # will open an editor and the user can add the signature there.
fi

# Strip the wrapper-only flag before invoking gh
FINAL_ARGS=()
for arg in "${ORIGINAL_ARGS[@]}"; do
    [ "$arg" = "--no-signature" ] && continue
    FINAL_ARGS+=("$arg")
done

# --- Label validation -------------------------------------------------------
# Skip when no labels were passed or metadata file is absent.
if [ ${#LABELS[@]} -eq 0 ]; then
    echo "ℹ️  No labels specified, passing through to 'gh pr create'"
    exec gh pr create "${FINAL_ARGS[@]}"
fi

if [ ! -f "$METADATA_FILE" ]; then
    echo "⚠️  Warning: $METADATA_FILE not found"
    echo "   Skipping label validation. Labels will be validated by GitHub."
    exec gh pr create "${FINAL_ARGS[@]}"
fi

VALID_LABELS=$(jq -r '.labels[]' "$METADATA_FILE" 2>/dev/null) || {
    echo "⚠️  Warning: Failed to parse $METADATA_FILE"
    echo "   Skipping label validation."
    exec gh pr create "${FINAL_ARGS[@]}"
}

INVALID_LABELS=()
for label in "${LABELS[@]}"; do
    if ! echo "$VALID_LABELS" | grep -Fxq "$label"; then
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
exec gh pr create "${FINAL_ARGS[@]}"
