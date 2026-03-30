#!/bin/bash
# .agent/scripts/worktree_enter.sh
# Enter a worktree and set up the environment
#
# Usage:
#   source ./worktree_enter.sh --issue <number> --type workspace|project [--repo <name>] [--repo-slug <slug>]
#   source ./worktree_enter.sh --skill <name> --type workspace|project [--repo <name>] [--repo-slug <slug>]
#
# This script should be SOURCED (not executed) to affect the current shell.
# It will:
#   1. Change to the worktree directory
#   2. Set helpful environment variables
#
# Examples:
#   source ./.agent/scripts/worktree_enter.sh --issue 123 --type workspace
#   source ./.agent/scripts/worktree_enter.sh --issue 123 --type project
#   source ./.agent/scripts/worktree_enter.sh --skill research --type workspace

# Don't use set -e since we're sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "$SCRIPT_DIR/_worktree_helpers.sh"

ISSUE_NUM=""
SKILL_NAME=""
WORKTREE_TYPE=""
REPO_SLUG=""
PROJECT_REPO=""

show_usage() {
    echo "Usage: source $0 (--issue <number> | --skill <name>) --type workspace|project [options]"
    echo ""
    echo "Options:"
    echo "  --issue <number>        Issue number (required, unless --skill is used)"
    echo "  --skill <name>          Skill name (alternative to --issue)"
    echo "  --type <type>           Worktree type: 'workspace' or 'project' (required)"
    echo "  --repo <name>           Project repo name (for multi-project disambiguation)"
    echo "  --repo-slug <slug>      Repository slug (optional, for disambiguation)"
    echo ""
    echo "Note: This script must be SOURCED to affect your current shell."
    echo ""
    echo "Examples:"
    echo "  source $0 --issue 123 --type workspace"
    echo "  source $0 --issue 123 --type project"
    echo "  source $0 --skill research --type workspace"
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
        --type)
            WORKTREE_TYPE="$2"
            shift 2
            ;;
        --repo)
            PROJECT_REPO="$2"
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
if [ -z "$WORKTREE_TYPE" ]; then
    echo "Error: --type is required (workspace or project)"
    show_usage
    return 1 2>/dev/null || exit 1
fi
if [ "$WORKTREE_TYPE" != "workspace" ] && [ "$WORKTREE_TYPE" != "project" ]; then
    echo "Error: --type must be 'workspace' or 'project'"
    return 1 2>/dev/null || exit 1
fi
if [ -n "$PROJECT_REPO" ] && [ "$WORKTREE_TYPE" == "workspace" ]; then
    echo "Error: --repo is only valid with --type project"
    return 1 2>/dev/null || exit 1
fi

# Sanitize repo slug
if [ -n "$REPO_SLUG" ]; then
    REPO_SLUG=$(echo "$REPO_SLUG" | sed 's/[^A-Za-z0-9_]/_/g')
fi

# Resolve base directory for the specified type
_resolve_base_dirs() {
    local type="$1"
    NEW_BASE=""
    LEGACY_BASE=""

    if [ "$type" == "workspace" ]; then
        NEW_BASE="$(wt_workspace_base "$ROOT_DIR")"
        LEGACY_BASE="$(wt_legacy_workspace_base "$ROOT_DIR")"
    else
        # Project type: resolve repo-specific directory
        if [ -n "$PROJECT_REPO" ]; then
            NEW_BASE="$(wt_project_base "$ROOT_DIR" "$PROJECT_REPO")"
        else
            # Auto-detect: find the single project repo directory, or scan all
            local proj_base
            proj_base="$(wt_project_base_glob "$ROOT_DIR")"
            if [ -d "$proj_base" ]; then
                local repo_dirs=()
                for d in "$proj_base"/*/; do
                    [ -d "$d" ] && repo_dirs+=("$d")
                done
                if [ "${#repo_dirs[@]}" -eq 1 ]; then
                    NEW_BASE="${repo_dirs[0]%/}"
                elif [ "${#repo_dirs[@]}" -gt 1 ]; then
                    echo "Error: Multiple project repos found. Use --repo to specify:" >&2
                    for d in "${repo_dirs[@]}"; do
                        echo "  --repo $(basename "${d%/}")" >&2
                    done
                    return 1
                fi
            fi
        fi
        LEGACY_BASE="$(wt_legacy_project_base "$ROOT_DIR")"
    fi
}

WORKTREE_DIR=""

_resolve_base_dirs "$WORKTREE_TYPE" || { return 1 2>/dev/null || exit 1; }

if [ -n "$SKILL_NAME" ]; then
    # Skill mode: search new location, then legacy
    if [ -n "$NEW_BASE" ] && FOUND=$(find_worktree_by_skill "$NEW_BASE" "$SKILL_NAME" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
    elif [ -n "$LEGACY_BASE" ] && FOUND=$(find_worktree_by_skill "$LEGACY_BASE" "$SKILL_NAME" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
        echo "⚠️  Found worktree in legacy location. Remove and recreate to use new layout." >&2
    else
        echo "Error: No $WORKTREE_TYPE worktree found for skill '$SKILL_NAME'"
        echo ""
        echo "Create one with:"
        echo "  .agent/scripts/worktree_create.sh --skill $SKILL_NAME --type $WORKTREE_TYPE"
        return 1 2>/dev/null || exit 1
    fi
else
    # Issue mode: search new location, then legacy
    if [ -n "$NEW_BASE" ] && FOUND=$(find_worktree "$NEW_BASE" "$ISSUE_NUM" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
    elif [ -n "$LEGACY_BASE" ] && FOUND=$(find_worktree "$LEGACY_BASE" "$ISSUE_NUM" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
        echo "⚠️  Found worktree in legacy location. Remove and recreate to use new layout." >&2
    else
        echo "Error: No $WORKTREE_TYPE worktree found for issue #$ISSUE_NUM"
        echo ""
        echo "Create one with:"
        echo "  .agent/scripts/worktree_create.sh --issue $ISSUE_NUM --type $WORKTREE_TYPE"
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
    echo "  \"$ROOT_DIR/.agent/scripts/worktree_remove.sh\" --skill $SKILL_NAME --type $WORKTREE_TYPE  # Remove worktree"
else
    echo "  \"$ROOT_DIR/.agent/scripts/worktree_remove.sh\" --issue $ISSUE_NUM --type $WORKTREE_TYPE  # Remove worktree"
fi
