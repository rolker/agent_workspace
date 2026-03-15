#!/bin/bash
# .agent/scripts/worktree_list.sh
# List all git worktrees for this workspace
#
# Usage:
#   ./worktree_list.sh [--verbose]
#
# Shows all active worktrees including:
#   - Issue number / skill name
#   - Type (project/workspace)
#   - Branch name
#   - Path
#   - Status (clean/dirty)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "$SCRIPT_DIR/_worktree_helpers.sh"

VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--verbose]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show detailed status for each worktree"
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            exit 1
            ;;
    esac
done

cd "$ROOT_DIR"

echo "========================================"
echo "Git Worktrees"
echo "========================================"
echo ""

# Get worktree list from git (workspace repo: main + workspace worktrees)
WORKTREES=$(git worktree list --porcelain)

WORKSPACE_COUNT=0
PROJECT_COUNT=0

# Helper: extract issue/repo/skill from worktree directory basename
extract_issue_repo() {
    local basename="$1"
    WT_ISSUE=""
    WT_REPO=""
    WT_SKILL=""

    # Skill format: skill-{REPO_SLUG}-{SKILL_NAME}-{TIMESTAMP}
    if [[ "$basename" =~ ^skill-([a-zA-Z0-9_]+)-([a-zA-Z0-9_-]+)-([0-9]{8}-[0-9]{6}(-[0-9]+)?)$ ]]; then
        WT_REPO="${BASH_REMATCH[1]}"
        WT_SKILL="${BASH_REMATCH[2]}"
    # New format: issue-{REPO_SLUG}-{NUMBER}
    elif [[ "$basename" =~ ^issue-([a-zA-Z0-9_]+)-([0-9]+)$ ]]; then
        WT_REPO="${BASH_REMATCH[1]}"
        WT_ISSUE="${BASH_REMATCH[2]}"
    # Legacy format: issue-{NUMBER}
    elif [[ "$basename" =~ ^issue-([0-9]+)$ ]]; then
        WT_ISSUE="${BASH_REMATCH[1]}"
        WT_REPO="(legacy)"
    fi
}

# Print a worktree entry
print_worktree() {
    local path="$1"
    local branch="$2"
    local head="$3"

    local type="main"
    local issue=""
    local repo=""
    local skill=""

    if [[ "$path" == *"/.workspace-worktrees/"* ]]; then
        type="workspace"
        extract_issue_repo "$(basename "$path")"
        issue="$WT_ISSUE"
        repo="$WT_REPO"
        skill="$WT_SKILL"
        ((WORKSPACE_COUNT++)) || true
    fi

    local status="clean"
    if [ -d "$path" ]; then
        if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
            status="dirty"
        fi
    fi

    if [ "$type" == "main" ]; then
        echo "[main] Main Workspace"
        echo "   Path:   $path"
        echo "   Branch: ${branch:-detached at $head}"
        echo "   Status: $status"
    elif [ -n "$skill" ]; then
        echo "[workspace] Skill: $skill - Repository: $repo"
        echo "   Path:   $path"
        echo "   Branch: ${branch:-detached at $head}"
        echo "   Status: $status"
        if [ "$VERBOSE" = true ] && [ -d "$path" ]; then
            echo "   Files changed: $(git -C "$path" status --porcelain 2>/dev/null | wc -l)"
        fi
    else
        echo "[workspace] Issue #$issue - Repository: $repo"
        echo "   Path:   $path"
        echo "   Branch: ${branch:-detached at $head}"
        echo "   Status: $status"
        if [ "$VERBOSE" = true ] && [ -d "$path" ]; then
            echo "   Files changed: $(git -C "$path" status --porcelain 2>/dev/null | wc -l)"
        fi
    fi
    echo ""
}

# Parse and display workspace worktrees from git worktree list
CURRENT_PATH=""
CURRENT_BRANCH=""
CURRENT_HEAD=""

while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line == worktree* ]]; then
        if [ -n "$CURRENT_PATH" ]; then
            print_worktree "$CURRENT_PATH" "$CURRENT_BRANCH" "$CURRENT_HEAD"
        fi
        CURRENT_PATH="${line#worktree }"
        CURRENT_BRANCH=""
        CURRENT_HEAD=""
    elif [[ $line == HEAD* ]]; then
        CURRENT_HEAD="${line#HEAD }"
    elif [[ $line == branch* ]]; then
        CURRENT_BRANCH="${line#branch refs/heads/}"
    fi
done <<< "$WORKTREES"

if [ -n "$CURRENT_PATH" ]; then
    print_worktree "$CURRENT_PATH" "$CURRENT_BRANCH" "$CURRENT_HEAD"
fi

# Discover project worktrees by scanning project/worktrees/
PROJECT_WT_DIR="$ROOT_DIR/project/worktrees"
if [ -d "$PROJECT_WT_DIR" ]; then
    for proj_wt in "$PROJECT_WT_DIR"/issue-* "$PROJECT_WT_DIR"/skill-*; do
        [ -d "$proj_wt" ] || continue

        extract_issue_repo "$(basename "$proj_wt")"
        local_issue="$WT_ISSUE"
        local_repo="$WT_REPO"
        local_skill="$WT_SKILL"

        local_branch=$(git -C "$proj_wt" branch --show-current 2>/dev/null || echo "")
        local_status="clean"
        if [ -n "$(git -C "$proj_wt" status --porcelain 2>/dev/null)" ]; then
            local_status="dirty"
        fi

        if [ -n "$local_skill" ]; then
            echo "[project] Skill: $local_skill - Repository: $local_repo"
        else
            echo "[project] Issue #$local_issue - Repository: $local_repo"
        fi
        echo "   Path:   $proj_wt"
        echo "   Branch: ${local_branch:-unknown}"
        echo "   Status: $local_status"

        if [ "$VERBOSE" = true ]; then
            echo "   Files changed: $(git -C "$proj_wt" status --porcelain 2>/dev/null | wc -l)"
        fi

        echo ""
        ((PROJECT_COUNT++)) || true
    done
fi

if [ -z "$WORKTREES" ] && [ "$WORKSPACE_COUNT" -eq 0 ] && [ "$PROJECT_COUNT" -eq 0 ]; then
    echo "No worktrees found."
    echo ""
    echo "Create one with:"
    echo "  ./.agent/scripts/worktree_create.sh --issue <number> --type workspace"
    exit 0
fi

echo "========================================"
echo "Summary"
echo "========================================"
echo "  Workspace worktrees: $WORKSPACE_COUNT"
echo "  Project worktrees:   $PROJECT_COUNT"
echo ""
echo "Locations:"
echo "  Workspace: .workspace-worktrees/"
echo "  Project:   project/worktrees/"
