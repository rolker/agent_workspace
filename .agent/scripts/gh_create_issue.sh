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
#   - AI signature footer (Authored-By / Model) is appended to the body
#     (--body / -b, --body-file / -F, and their --flag=VALUE forms) unless
#     (a) --no-signature is passed (stripped before gh), or
#     (b) the body already contains `**Authored-By**:` (case-sensitive)
#   - AGENT_NAME and AGENT_MODEL env vars MUST be set when the signature is
#     to be added; missing vars hard-fail (exit 2) before any gh call. Set via:
#     source .agent/scripts/set_git_identity_env.sh "Name" "email" "<model>"
#   - No body flag at all (interactive editor mode) means nothing is signed.
#   - A --body-file is never modified: the wrapper signs a temporary copy
#     (under TMPDIR), removed on exit. The footer comes after the
#     auto-added parent reference, and the git-bug path is signed too.
#
# Exit codes:
#   0 - Success
#   1 - Invalid label detected
#   2 - Argument / usage errors:
#         - missing value for -R/--repo, --label/-l, --body/-b, or --body-file/-F
#         - both a body and a body file provided
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

# Normalize flag forms (--flag=VALUE → --flag VALUE, -b → --body,
# -F → --body-file) so the parse, the parent-ref injection, the signature
# injection and the git-bug path each handle one shape per flag. Without
# this, `--body=X` or `-b X` would reach gh unsigned.
_RAW_ARGS=("$@")
ORIGINAL_ARGS=()
for arg in "${_RAW_ARGS[@]}"; do
    case "$arg" in
        --body=*)      ORIGINAL_ARGS+=(--body "${arg#*=}") ;;
        --body-file=*) ORIGINAL_ARGS+=(--body-file "${arg#*=}") ;;
        --repo=*)      ORIGINAL_ARGS+=(--repo "${arg#*=}") ;;
        --label=*)     ORIGINAL_ARGS+=(--label "${arg#*=}") ;;
        -b)            ORIGINAL_ARGS+=(--body) ;;
        -F)            ORIGINAL_ARGS+=(--body-file) ;;
        *)             ORIGINAL_ARGS+=("$arg") ;;
    esac
done

# Parse command-line arguments. We need to know:
#   - --label / -l values (for validation)
#   - -R / --repo value (for repo-safety check)
#   - --body / --body-file (for signature injection)
#   - --no-signature (skip footer)
LABELS=()
EXPLICIT_REPO=""
NO_SIGNATURE=false
BODY_FLAG_PRESENT=false
BODY_FILE_PATH=""

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
            if [ $((i + 1)) -ge ${#ORIGINAL_ARGS[@]} ]; then
                echo "❌ Error: --label requires a value" >&2
                exit 2
            fi
            LABELS+=("${ORIGINAL_ARGS[$((i+1))]}")
            i=$((i + 2))
            ;;
        --body)
            # `--body ""` is flag-present (non-interactive) and is signed.
            BODY_FLAG_PRESENT=true
            if [ $((i + 1)) -ge ${#ORIGINAL_ARGS[@]} ]; then
                echo "❌ Error: --body requires a value" >&2
                exit 2
            fi
            i=$((i + 2))
            ;;
        --body-file)
            if [ $((i + 1)) -ge ${#ORIGINAL_ARGS[@]} ]; then
                echo "❌ Error: --body-file requires a value" >&2
                exit 2
            fi
            BODY_FILE_PATH="${ORIGINAL_ARGS[$((i+1))]}"
            i=$((i + 2))
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

# --- Mutually exclusive body sources -----------------------------------------
# Both would mean the wrapper signs one source while gh may use the other
# (or error), leaving the issue unsigned.
if [ "$BODY_FLAG_PRESENT" = true ] && [ -n "$BODY_FILE_PATH" ]; then
    echo "❌ Error: --body and --body-file are mutually exclusive" >&2
    exit 2
fi

# Index of a flag's value in ORIGINAL_ARGS (the last occurrence, which is
# the one gh uses), or -1.
_arg_value_index() {
    local flag="$1" idx=-1 j
    for (( j=0; j<${#ORIGINAL_ARGS[@]}; j++ )); do
        if [ "${ORIGINAL_ARGS[$j]}" = "$flag" ] && [ $((j + 1)) -lt ${#ORIGINAL_ARGS[@]} ]; then
            idx=$((j + 1))
        fi
    done
    echo "$idx"
}

# Temp copies of a --body-file (parent reference and/or signature). One
# file, one trap: the copy is made once and both injections append to it.
# Honours TMPDIR (mktemp -t), and gh runs as a child (never `exec`) so the
# EXIT trap always removes it.
BODY_COPY_FILE=""
trap 'rm -f "${BODY_COPY_FILE:-}"' EXIT
_body_file_copy() {
    # Point the --body-file argument at a temp copy (created on first use).
    # `--body-file -` (gh reads stdin) is drained into the copy, so it is
    # signed like any other body file.
    if [ -z "$BODY_COPY_FILE" ]; then
        local idx
        idx=$(_arg_value_index --body-file)
        BODY_COPY_FILE=$(mktemp -t gh_issue_body.XXXXXX.md)
        if [ "$BODY_FILE_PATH" = "-" ]; then
            cat > "$BODY_COPY_FILE"
        else
            cp "$BODY_FILE_PATH" "$BODY_COPY_FILE"
        fi
        ORIGINAL_ARGS[$idx]="$BODY_COPY_FILE"
        BODY_FILE_PATH="$BODY_COPY_FILE"
    fi
}
if [ "$BODY_FILE_PATH" = "-" ]; then
    _body_file_copy
fi

# --- AI signature: decide, and hard-fail before any gh call -------------------
# Sign unless --no-signature, no body flag at all (interactive editor mode),
# or the body already contains the marker. The footer itself is appended
# after the parent-ref injection below, so it stays last.
SIG_MARKER='**Authored-By**:'
needs_signature() {
    [ "$NO_SIGNATURE" = true ] && return 1
    [ "$BODY_FLAG_PRESENT" = false ] && [ -z "$BODY_FILE_PATH" ] && return 1
    if [ "$BODY_FLAG_PRESENT" = true ]; then
        local idx
        idx=$(_arg_value_index --body)
        printf '%s' "${ORIGINAL_ARGS[$idx]}" | grep -Fq -- "$SIG_MARKER" && return 1
    elif [ -f "$BODY_FILE_PATH" ]; then
        grep -Fq -- "$SIG_MARKER" "$BODY_FILE_PATH" && return 1
    fi
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
if [ -z "$EXPLICIT_REPO" ]; then
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

    # Validate slug format (owner/repo) before comparing — non-GitHub remotes
    # (enterprise hosts, SSH aliases, GitLab) produce slugs that won't match.
    # Skip the safety check rather than false-positive aborting.
    _SLUG_PATTERN='^[^/[:space:]]+/[^/[:space:]]+$'

    # Check if current repo matches workspace or project
    _REPO_OK=false
    if [ -n "$_CURRENT_SLUG" ] && [[ "$_CURRENT_SLUG" =~ $_SLUG_PATTERN ]]; then
        if [ "$_CURRENT_SLUG" = "$_WS_SLUG" ]; then
            _REPO_OK=true
        elif [ -n "$_PROJECT_SLUG" ] && [ "$_CURRENT_SLUG" = "$_PROJECT_SLUG" ]; then
            _REPO_OK=true
        fi
    else
        # Slug is empty or not in owner/repo format — can't validate, allow through
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

    # Check if body already references the parent issue
    BODY_TEXT=""
    BODY_ARG_INDEX=-1
    if [ "$BODY_FLAG_PRESENT" = true ]; then
        BODY_ARG_INDEX=$(_arg_value_index --body)
        BODY_TEXT="${ORIGINAL_ARGS[$BODY_ARG_INDEX]}"
    fi

    NEEDS_INJECTION=true
    # Use word-boundary regex to avoid substring false positives (e.g., #12 matching #123)
    _PARENT_PATTERN="(^|[^0-9])#${WORKTREE_ISSUE}([^0-9]|$)"
    if [ -n "$BODY_TEXT" ]; then
        if printf '%s\n' "$BODY_TEXT" | grep -Eq "$_PARENT_PATTERN"; then
            NEEDS_INJECTION=false
        fi
    elif [ -n "$BODY_FILE_PATH" ] && [ -f "$BODY_FILE_PATH" ]; then
        if grep -Eq "$_PARENT_PATTERN" "$BODY_FILE_PATH"; then
            NEEDS_INJECTION=false
        fi
    fi

    if [ "$NEEDS_INJECTION" = true ]; then
        if [ -n "$BODY_TEXT" ]; then
            # Append to --body value
            ORIGINAL_ARGS[$BODY_ARG_INDEX]="${BODY_TEXT}

Part of ${PARENT_REF}"
            echo "ℹ️  Auto-added parent reference: Part of ${PARENT_REF}"
        elif [ -n "$BODY_FILE_PATH" ] && [ -f "$BODY_FILE_PATH" ]; then
            # Append to a temp copy; the caller's file is never modified
            _body_file_copy
            printf '\n\nPart of %s\n' "$PARENT_REF" >> "$BODY_COPY_FILE"
            echo "ℹ️  Auto-added parent reference: Part of ${PARENT_REF}"
        else
            echo "⚠️  No --body or --body-file provided; cannot auto-inject parent reference (Part of ${PARENT_REF})"
        fi
    fi
fi

# --- AI signature injection --------------------------------------------------
# After the parent reference (so the footer stays last) and before the
# git-bug path (so git-bug issues are signed too).
if [ "$SIGN_BODY" = true ]; then
    SIG_BLOCK=$(printf '\n\n---\n**Authored-By**: `%s`\n**Model**: `%s`\n' \
                       "$AGENT_NAME" "$AGENT_MODEL")
    if [ "$BODY_FLAG_PRESENT" = true ]; then
        _idx=$(_arg_value_index --body)
        ORIGINAL_ARGS[$_idx]="${ORIGINAL_ARGS[$_idx]}${SIG_BLOCK}"
    elif [ -f "$BODY_FILE_PATH" ]; then
        _body_file_copy
        printf '%s' "$SIG_BLOCK" >> "$BODY_COPY_FILE"
    fi
    # A --body-file that does not exist is passed through unsigned; gh
    # then fails on it, so no unsigned issue is created.
fi

# Strip the wrapper-only flag before invoking gh or git-bug
_STRIPPED_ARGS=()
for arg in "${ORIGINAL_ARGS[@]}"; do
    [ "$arg" = "--no-signature" ] && continue
    _STRIPPED_ARGS+=("$arg")
done
ORIGINAL_ARGS=("${_STRIPPED_ARGS[@]}")

# Optional: create via git-bug + push (offline-capable, opt-in via GITBUG_CREATE=1)
# Placed before label validation so it's reachable with or without labels.
if [ "${GITBUG_CREATE:-}" = "1" ] && command -v git-bug &>/dev/null; then
    _TITLE=""
    _BODY=""
    _BODY_FILE=""
    for (( i=0; i<${#ORIGINAL_ARGS[@]}; i++ )); do
        case "${ORIGINAL_ARGS[$i]}" in
            --title) _TITLE="${ORIGINAL_ARGS[$((i+1))]:-}" ;;
            --body) _BODY="${ORIGINAL_ARGS[$((i+1))]:-}" ;;
            --body-file) _BODY_FILE="${ORIGINAL_ARGS[$((i+1))]:-}" ;;
        esac
    done
    if [ ${#LABELS[@]} -gt 0 ]; then
        echo "⚠️  This script's git-bug path does not apply labels — labels will be skipped."
        echo "   Add labels manually after sync, or unset GITBUG_CREATE to use gh CLI."
    fi
    if [ -n "$_TITLE" ]; then
        _GB_ARGS=(--title "$_TITLE")
        if [ -n "$_BODY_FILE" ] && [ -f "$_BODY_FILE" ]; then
            _BODY=$(cat "$_BODY_FILE")
        fi
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
if [ ${#LABELS[@]} -eq 0 ]; then
    echo "ℹ️  No labels specified, passing through to 'gh issue create'"
    gh issue create "${ORIGINAL_ARGS[@]}"; exit $?
fi

if [ ! -f "$METADATA_FILE" ]; then
    echo "⚠️  Warning: $METADATA_FILE not found"
    echo "   Skipping label validation. Labels will be validated by GitHub."
    echo "   To enable validation, create the metadata file with valid labels."
    gh issue create "${ORIGINAL_ARGS[@]}"; exit $?
fi

# Load valid labels from metadata
VALID_LABELS=$(jq -r '.labels[]' "$METADATA_FILE" 2>/dev/null) || {
    echo "⚠️  Warning: Failed to parse $METADATA_FILE"
    echo "   Skipping label validation."
    gh issue create "${ORIGINAL_ARGS[@]}"; exit $?
}

# Validate each label
# `--` terminates grep option parsing so labels starting with `-` are not
# misread as flags (matters under ugrep / stricter grep).
INVALID_LABELS=()
for label in "${LABELS[@]}"; do
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
gh issue create "${ORIGINAL_ARGS[@]}"
exit $?
