#!/bin/bash
# .agent/scripts/worktree_enter.sh
# Enter a worktree and set up the environment
#
# Usage:
#   source ./worktree_enter.sh --issue <number> [--repo-slug <slug>]
#   source ./worktree_enter.sh --skill <name> [--repo-slug <slug>]
#
# This script should be SOURCED (not executed) to affect the current shell.
# It will:
#   1. Change to the worktree directory
#   2. Set helpful environment variables
#
# Examples:
#   source ./.agent/scripts/worktree_enter.sh --issue 123
#   source ./.agent/scripts/worktree_enter.sh --skill research

# Don't use set -e since we're sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "$SCRIPT_DIR/_worktree_helpers.sh"

ISSUE_NUM=""
SKILL_NAME=""
REPO_SLUG=""

show_usage() {
    echo "Usage: source $0 (--issue <number> | --skill <name>) [--repo-slug <slug>]"
    echo "   or: source $0 <number>"
    echo ""
    echo "Options:"
    echo "  --issue <number>        Issue number (required, unless --skill is used)"
    echo "  --skill <name>          Skill name (alternative to --issue)"
    echo "  --repo-slug <slug>      Repository slug (optional, for disambiguation)"
    echo "  <number>                Issue number as positional argument"
    echo ""
    echo "Note: This script must be SOURCED to affect your current shell."
    echo ""
    echo "Examples:"
    echo "  source $0 --issue 123"
    echo "  source $0 123"
    echo "  source $0 --skill research"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --issue)
            ISSUE_NUM="$2"
            shift 2
            ;;
        --skill)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --skill requires a skill name"
                show_usage
                return 1 2>/dev/null || exit 1
            fi
            SKILL_NAME="$2"
            shift 2
            ;;
        --repo-slug)
            REPO_SLUG="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            return 0 2>/dev/null || exit 0
            ;;
        [0-9]*)
            ISSUE_NUM="$1"
            shift
            ;;
        *)
            echo "Error: Unknown option $1"
            show_usage
            return 1 2>/dev/null || exit 1
            ;;
    esac
done

if [ -n "$ISSUE_NUM" ] && [ -n "$SKILL_NAME" ]; then
    echo "Error: --issue and --skill are mutually exclusive"
    show_usage
    return 1 2>/dev/null || exit 1
fi
if [ -z "$ISSUE_NUM" ] && [ -z "$SKILL_NAME" ]; then
    echo "Error: either --issue or --skill is required"
    show_usage
    return 1 2>/dev/null || exit 1
fi

# Sanitize repo slug
if [ -n "$REPO_SLUG" ]; then
    REPO_SLUG=$(echo "$REPO_SLUG" | sed 's/[^A-Za-z0-9_]/_/g')
fi

# Function to find worktree directory
find_worktree() {
    local base_dir="$1"
    local issue_num="$2"
    local repo_slug="$3"

    if [ -n "$repo_slug" ]; then
        local exact_path="$base_dir/issue-${repo_slug}-${issue_num}"
        if [ -d "$exact_path" ]; then
            echo "$exact_path"
            return 0
        fi
        return 1
    fi

    local matches=()
    for path in "$base_dir"/issue-*-"${issue_num}"; do
        if [ -d "$path" ] && [ "$path" != "$base_dir/issue-*-${issue_num}" ]; then
            matches+=( "$path" )
        fi
    done

    # Legacy format: issue-{NUMBER}
    local legacy_path="$base_dir/issue-${issue_num}"
    if [ -d "$legacy_path" ]; then
        matches+=( "$legacy_path" )
    fi

    if [ "${#matches[@]}" -eq 1 ]; then
        echo "${matches[0]}"
        return 0
    elif [ "${#matches[@]}" -gt 1 ]; then
        echo "Error: Multiple worktrees found for issue ${issue_num}:" >&2
        for path in "${matches[@]}"; do
            echo "  - $(basename "$path")" >&2
        done
        echo "" >&2
        echo "Use --repo-slug to specify which one:" >&2
        for path in "${matches[@]}"; do
            local slug
            slug=$(basename "$path" | sed -E 's/^issue-(.+)-[0-9]+$/\1/')
            echo "  source ${BASH_SOURCE[0]} --issue ${issue_num} --repo-slug ${slug}" >&2
        done
        return 1
    fi

    return 1
}

WORKTREE_DIR=""
WORKTREE_TYPE=""

if [ -n "$SKILL_NAME" ]; then
    # Skill mode: search project worktrees first, then workspace
    if FOUND=$(find_worktree_by_skill "$ROOT_DIR/project/worktrees" "$SKILL_NAME" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
        WORKTREE_TYPE="project"
    elif FOUND=$(find_worktree_by_skill "$ROOT_DIR/.workspace-worktrees" "$SKILL_NAME" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
        WORKTREE_TYPE="workspace"
    else
        echo "Error: No worktree found for skill '$SKILL_NAME'"
        echo ""
        echo "Checked locations:"
        echo "  - $ROOT_DIR/project/worktrees/skill-*-${SKILL_NAME}-*"
        echo "  - $ROOT_DIR/.workspace-worktrees/skill-*-${SKILL_NAME}-*"
        echo ""
        echo "Create one with:"
        echo "  .agent/scripts/worktree_create.sh --skill $SKILL_NAME --type workspace"
        return 1 2>/dev/null || exit 1
    fi
else
    # Issue mode: check project worktrees first, then workspace
    if FOUND=$(find_worktree "$ROOT_DIR/project/worktrees" "$ISSUE_NUM" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
        WORKTREE_TYPE="project"
    elif FOUND=$(find_worktree "$ROOT_DIR/.workspace-worktrees" "$ISSUE_NUM" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
        WORKTREE_TYPE="workspace"
    else
        echo "Error: No worktree found for issue #$ISSUE_NUM"
        echo ""
        echo "Checked locations:"
        if [ -n "$REPO_SLUG" ]; then
            echo "  - $ROOT_DIR/project/worktrees/issue-${REPO_SLUG}-$ISSUE_NUM"
            echo "  - $ROOT_DIR/.workspace-worktrees/issue-${REPO_SLUG}-$ISSUE_NUM"
        else
            echo "  - $ROOT_DIR/project/worktrees/issue-*-$ISSUE_NUM"
            echo "  - $ROOT_DIR/.workspace-worktrees/issue-*-$ISSUE_NUM"
        fi
        echo ""
        echo "Create one with:"
        echo "  ./.agent/scripts/worktree_create.sh --issue $ISSUE_NUM --type workspace"
        return 1 2>/dev/null || exit 1
    fi
fi

echo "========================================"
echo "Entering Worktree"
echo "========================================"
if [ -n "$SKILL_NAME" ]; then
    echo "  Skill: $SKILL_NAME"
else
    echo "  Issue:  #$ISSUE_NUM"
fi
echo "  Type:   $WORKTREE_TYPE"
echo "  Path:   $WORKTREE_DIR"
echo ""

# Change to worktree directory
cd "$WORKTREE_DIR" || { echo "Error: Failed to cd to $WORKTREE_DIR"; return 1 2>/dev/null || exit 1; }

# Set environment variables
export WORKTREE_TYPE="$WORKTREE_TYPE"
export WORKTREE_ROOT="$WORKTREE_DIR"

if [ -n "$SKILL_NAME" ]; then
    export WORKTREE_SKILL="$SKILL_NAME"
    unset WORKTREE_ISSUE WORKTREE_ISSUE_TITLE
    echo "  Skill worktree — no issue to verify"
    echo ""
else
    export WORKTREE_ISSUE="$ISSUE_NUM"
    unset WORKTREE_SKILL

    # Fetch and display issue title
    _ISSUE_TITLE=""

    if command -v gh &>/dev/null; then
        _ISSUE_TITLE=$(gh issue view "$ISSUE_NUM" --json title --jq '.title' 2>/dev/null || echo "")
        # Retry with workspace repo if needed
        if [ -z "$_ISSUE_TITLE" ]; then
            _WS_REMOTE=$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "")
            if [[ -n "$_WS_REMOTE" && "$_WS_REMOTE" == *"github.com"* ]]; then
                _WS_SLUG=$(echo "$_WS_REMOTE" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')
                if [[ "$_WS_SLUG" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
                    _ISSUE_TITLE=$(gh issue view "$ISSUE_NUM" --repo "$_WS_SLUG" --json title --jq '.title' 2>/dev/null || echo "")
                fi
            fi
        fi
    fi
    export WORKTREE_ISSUE_TITLE="$_ISSUE_TITLE"

    if [ -n "$_ISSUE_TITLE" ]; then
        echo "  Title: $_ISSUE_TITLE"
        echo "  >>> Verify this matches your task <<<"
        echo ""
    else
        echo "  Title: (could not fetch)"
        echo "  Run: gh issue view $ISSUE_NUM --json title --jq '.title'"
        echo ""
    fi
fi

# Load parent issue from metadata file (written by worktree_create.sh)
_PARENT_ISSUE_FILE="$WORKTREE_DIR/.agent/scratchpad/.parent_issue"
if [ -f "$_PARENT_ISSUE_FILE" ]; then
    WORKTREE_PARENT_ISSUE="$(tr -d '[:space:]' < "$_PARENT_ISSUE_FILE")"
    export WORKTREE_PARENT_ISSUE
else
    unset WORKTREE_PARENT_ISSUE
fi
unset _PARENT_ISSUE_FILE

# Show current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
echo ""
if [ -n "$SKILL_NAME" ]; then
    echo "✅ Now in worktree for skill: $SKILL_NAME"
else
    echo "✅ Now in worktree for issue #$ISSUE_NUM"
fi
echo "   Branch: $CURRENT_BRANCH"
if [ -n "${WORKTREE_PARENT_ISSUE:-}" ]; then
    echo "   Parent: #$WORKTREE_PARENT_ISSUE (feature/issue-$WORKTREE_PARENT_ISSUE)"
fi
echo "   PWD:    $(pwd)"
echo ""

# Check if feature branch is behind default branch
_CHECK_SCRIPT="$ROOT_DIR/.agent/scripts/check_branch_updates.sh"
if [ -x "$_CHECK_SCRIPT" ]; then
    ("$_CHECK_SCRIPT") || true
fi
unset _CHECK_SCRIPT

# Show helpful commands
echo "Helpful commands:"
echo "  git status                    # Check changes"
echo "  git diff                      # See what changed"
if [ -n "$SKILL_NAME" ]; then
    echo "  \"$ROOT_DIR/.agent/scripts/worktree_remove.sh\" --skill $SKILL_NAME  # Remove worktree"
else
    echo "  \"$ROOT_DIR/.agent/scripts/worktree_remove.sh\" $ISSUE_NUM  # Remove worktree"
fi
