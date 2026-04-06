#!/bin/bash
# .agent/scripts/worktree_enter.sh
# Enter a worktree and set up the environment
#
# Usage:
#   source ./worktree_enter.sh --issue <number> --type workspace|project [--repo <name>] [--repo-slug <slug>]
#   source ./worktree_enter.sh --skill <name> --type workspace|project [--repo <name>] [--repo-slug <slug>]
#   ./worktree_enter.sh --issue <number> --type workspace|project --print-path
#   ./worktree_enter.sh --issue <number> --type workspace|project --shell-snippet
#
# Source this script to affect the current shell.
# Execute it only with --print-path or --shell-snippet when you need a
# one-shot output for tools that do not preserve shell state.
# When sourced, it will:
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
source "$SCRIPT_DIR/_issue_helpers.sh"

ISSUE_NUM=""
SKILL_NAME=""
WORKTREE_TYPE=""
REPO_SLUG=""
PROJECT_REPO=""
PRINT_PATH=false
SHELL_SNIPPET=false

shell_quote() {
    printf "%q" "$1"
}

show_usage() {
    echo "Usage: source $0 (--issue <number> | --skill <name>) --type workspace|project [options]"
    echo ""
    echo "Options:"
    echo "  --issue <number>        Issue number (required, unless --skill is used)"
    echo "  --skill <name>          Skill name (alternative to --issue)"
    echo "  --type <type>           Worktree type: 'workspace' or 'project' (required)"
    echo "  --repo <name>           Project repo name (for multi-project disambiguation)"
    echo "  --repo-slug <slug>      Repository slug (optional, for disambiguation)"
    echo "  --print-path            Print the resolved worktree path and exit"
    echo "  --shell-snippet         Print 'cd' and 'export' commands for one-shot eval"
    echo ""
    echo "Note: source the script for interactive shells; use --print-path or"
    echo "      --shell-snippet when your tool runs each command in a fresh shell."
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
        --print-path)
            PRINT_PATH=true
            shift
            ;;
        --shell-snippet)
            SHELL_SNIPPET=true
            shift
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
if [ "$PRINT_PATH" = true ] && [ "$SHELL_SNIPPET" = true ]; then
    echo "Error: --print-path and --shell-snippet are mutually exclusive"
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
            if ! NEW_BASE="$(wt_project_base "$ROOT_DIR" "$PROJECT_REPO")"; then
                return 1 2>/dev/null || exit 1
            fi
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
        CURRENT_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
        if [ -n "$CURRENT_TOPLEVEL" ] && [[ "$(basename "$CURRENT_TOPLEVEL")" == issue-*-"$ISSUE_NUM" ]]; then
            case "$WORKTREE_TYPE" in
                workspace)
                    if [[ "$CURRENT_TOPLEVEL" == */worktrees/workspace/* ]]; then
                        WORKTREE_DIR="$CURRENT_TOPLEVEL"
                    fi
                    ;;
                project)
                    if [[ "$CURRENT_TOPLEVEL" == */worktrees/project/* ]]; then
                        WORKTREE_DIR="$CURRENT_TOPLEVEL"
                    fi
                    ;;
            esac
        fi
        unset CURRENT_TOPLEVEL
        if [ -z "$WORKTREE_DIR" ]; then
            echo "Error: No $WORKTREE_TYPE worktree found for issue #$ISSUE_NUM"
            echo ""
            echo "Create one with:"
            echo "  .agent/scripts/worktree_create.sh --issue $ISSUE_NUM --type $WORKTREE_TYPE"
            return 1 2>/dev/null || exit 1
        fi
    fi
fi

if [ -n "$SKILL_NAME" ]; then
    WORKTREE_SKILL_VALUE="$SKILL_NAME"
    WORKTREE_ISSUE_VALUE=""
    WORKTREE_ISSUE_TITLE_VALUE=""
else
    WORKTREE_SKILL_VALUE=""
    WORKTREE_ISSUE_VALUE="$ISSUE_NUM"
    WORKTREE_ISSUE_TITLE_VALUE=""
fi

if [ "$PRINT_PATH" = true ]; then
    echo "$WORKTREE_DIR"
    return 0 2>/dev/null || exit 0
fi

if [ -z "$SKILL_NAME" ] && [ "$SHELL_SNIPPET" != true ]; then

    # Fetch and display issue title (git-bug first, then gh fallback)
    _ISSUE_TITLE=""
    _WS_REMOTE=$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "")
    _WS_SLUG=""
    if [[ -n "$_WS_REMOTE" && "$_WS_REMOTE" == *"github.com"* ]]; then
        _WS_SLUG=$(echo "$_WS_REMOTE" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')
        [[ "$_WS_SLUG" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || _WS_SLUG=""
    fi

    if [ -n "$_WS_SLUG" ]; then
        issue_lookup "$ISSUE_NUM" --repo "$_WS_SLUG" --root "$ROOT_DIR" || true
        _ISSUE_TITLE="$ISSUE_TITLE"
    fi
    WORKTREE_ISSUE_TITLE_VALUE="$_ISSUE_TITLE"
fi

# Load parent issue from metadata file (written by worktree_create.sh)
_PARENT_ISSUE_FILE="$WORKTREE_DIR/.agent/scratchpad/.parent_issue"
if [ -f "$_PARENT_ISSUE_FILE" ]; then
    WORKTREE_PARENT_ISSUE_VALUE="$(tr -d '[:space:]' < "$_PARENT_ISSUE_FILE")"
else
    WORKTREE_PARENT_ISSUE_VALUE=""
fi
unset _PARENT_ISSUE_FILE

if [ "$SHELL_SNIPPET" = true ]; then
    echo "cd $(shell_quote "$WORKTREE_DIR")"
    echo "export WORKTREE_TYPE=$(shell_quote "$WORKTREE_TYPE")"
    echo "export WORKTREE_ROOT=$(shell_quote "$WORKTREE_DIR")"
    if [ -n "$WORKTREE_SKILL_VALUE" ]; then
        echo "export WORKTREE_SKILL=$(shell_quote "$WORKTREE_SKILL_VALUE")"
        echo "unset WORKTREE_ISSUE"
        echo "unset WORKTREE_ISSUE_TITLE"
    else
        echo "unset WORKTREE_SKILL"
        echo "export WORKTREE_ISSUE=$(shell_quote "$WORKTREE_ISSUE_VALUE")"
        echo "export WORKTREE_ISSUE_TITLE=$(shell_quote "$WORKTREE_ISSUE_TITLE_VALUE")"
    fi
    if [ -n "$WORKTREE_PARENT_ISSUE_VALUE" ]; then
        echo "export WORKTREE_PARENT_ISSUE=$(shell_quote "$WORKTREE_PARENT_ISSUE_VALUE")"
    else
        echo "unset WORKTREE_PARENT_ISSUE"
    fi
    return 0 2>/dev/null || exit 0
fi

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Error: This script must be sourced for interactive use."
    echo "Use --print-path or --shell-snippet when running it as a command."
    exit 1
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

if [ -n "$WORKTREE_SKILL_VALUE" ]; then
    export WORKTREE_SKILL="$WORKTREE_SKILL_VALUE"
    unset WORKTREE_ISSUE WORKTREE_ISSUE_TITLE
    echo "  Skill worktree — no issue to verify"
    echo ""
else
    export WORKTREE_ISSUE="$WORKTREE_ISSUE_VALUE"
    export WORKTREE_ISSUE_TITLE="$WORKTREE_ISSUE_TITLE_VALUE"
    unset WORKTREE_SKILL

    if [ -n "$WORKTREE_ISSUE_TITLE_VALUE" ]; then
        echo "  Title: $WORKTREE_ISSUE_TITLE_VALUE"
        echo "  >>> Verify this matches your task <<<"
        echo ""
    else
        echo "  Title: (could not fetch)"
        echo "  Run: gh issue view $ISSUE_NUM --json title --jq '.title'"
        echo ""
    fi
fi

if [ -n "$WORKTREE_PARENT_ISSUE_VALUE" ]; then
    export WORKTREE_PARENT_ISSUE="$WORKTREE_PARENT_ISSUE_VALUE"
else
    unset WORKTREE_PARENT_ISSUE
fi

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
