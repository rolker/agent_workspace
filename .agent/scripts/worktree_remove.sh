#!/bin/bash
# .agent/scripts/worktree_remove.sh
# Remove a git worktree and clean up
#
# Usage:
#   ./worktree_remove.sh --issue <number> [--repo-slug <slug>] [--force]
#   ./worktree_remove.sh --skill <name> [--repo-slug <slug>] [--force]
#
# Examples:
#   ./worktree_remove.sh --issue 123
#   ./worktree_remove.sh --issue 123 --force
#   ./worktree_remove.sh --skill research
#
# This will:
#   1. Check for uncommitted changes (unless --force)
#   2. Remove the worktree directory
#   3. Prune the git worktree reference
#   4. Show branch deletion instructions

set -eo pipefail

CALLER_PWD="$(pwd -P)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ISSUE_NUM=""
SKILL_NAME=""
FORCE=false
REPO_SLUG=""

show_usage() {
    echo "Usage: $0 (--issue <number> | --skill <name>) [--repo-slug <slug>] [--force]"
    echo "   or: $0 <number> [--force]"
    echo ""
    echo "Options:"
    echo "  --issue <number>        Issue number (required, unless --skill is used)"
    echo "  --skill <name>          Skill name (alternative to --issue)"
    echo "  <number>                Issue number as positional argument"
    echo "  --repo-slug <slug>      Repository slug (optional, for disambiguation)"
    echo "  --force                 Force removal even with uncommitted changes"
}

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
                exit 1
            fi
            SKILL_NAME="$2"
            shift 2
            ;;
        --repo-slug)
            REPO_SLUG="$2"
            shift 2
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        [0-9]*)
            ISSUE_NUM="$1"
            shift
            ;;
        *)
            echo "Error: Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
done

# Resolve ROOT_DIR via git, not relative paths. When called from inside a
# worktree, SCRIPT_DIR points to the worktree's copy of .agent/scripts/,
# so dirname-based resolution gives the worktree root instead of the main
# workspace. The main worktree is always the first entry in git worktree list.
# Deferred until after arg parsing so --help works without a git repo.
ROOT_DIR="$(git worktree list --porcelain | head -1 | sed 's/^worktree //')"

source "$SCRIPT_DIR/_worktree_helpers.sh"

if [ -n "$REPO_SLUG" ]; then
    REPO_SLUG=$(echo "$REPO_SLUG" | sed 's/[^A-Za-z0-9_]/_/g')
fi

if [ -n "$ISSUE_NUM" ] && [ -n "$SKILL_NAME" ]; then
    echo "Error: --issue and --skill are mutually exclusive"
    show_usage
    exit 1
fi
if [ -z "$ISSUE_NUM" ] && [ -z "$SKILL_NAME" ]; then
    echo "Error: either --issue or --skill is required"
    show_usage
    exit 1
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
            echo "  $0 --issue ${issue_num} --repo-slug ${slug}" >&2
        done
        return 1
    fi

    return 1
}

WORKTREE_DIR=""
WORKTREE_TYPE=""

if [ -n "$SKILL_NAME" ]; then
    # Check project worktrees first, then workspace
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
        echo "List worktrees with: ./.agent/scripts/worktree_list.sh"
        exit 1
    fi
else
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
        echo "List worktrees with: ./.agent/scripts/worktree_list.sh"
        exit 1
    fi
fi

# Get branch name
cd "$ROOT_DIR"
BRANCH_NAME=$(git -C "$WORKTREE_DIR" branch --show-current 2>/dev/null || echo "")

echo "========================================"
echo "Removing Worktree"
echo "========================================"
if [ -n "$SKILL_NAME" ]; then
    echo "  Skill:  $SKILL_NAME"
else
    echo "  Issue:  #$ISSUE_NUM"
fi
echo "  Type:   $WORKTREE_TYPE"
echo "  Path:   $WORKTREE_DIR"
echo "  Branch: ${BRANCH_NAME:-detached HEAD}"
echo ""

if [[ ! -d "$WORKTREE_DIR" ]]; then
    echo "❌ Error: Worktree directory '$WORKTREE_DIR' does not exist."
    exit 1
fi
if ! WORKTREE_DIR="$(cd "$WORKTREE_DIR" && pwd -P)"; then
    echo "❌ Error: Failed to access worktree directory '$WORKTREE_DIR'."
    exit 1
fi
if [[ "$CALLER_PWD" == "$WORKTREE_DIR" || "$CALLER_PWD" == "$WORKTREE_DIR/"* ]]; then
    echo "❌ Error: Your shell is currently inside this worktree."
    echo ""
    echo "   Run this first:  cd $ROOT_DIR"
    if [ -n "$SKILL_NAME" ]; then
        echo "   Then re-run:     $0 --skill $SKILL_NAME"
    else
        echo "   Then re-run:     $0 --issue $ISSUE_NUM"
    fi
    exit 1
fi

# Check for uncommitted changes
if [ -d "$WORKTREE_DIR" ]; then
    cd "$WORKTREE_DIR"
    UNCOMMITTED=$(git status --porcelain 2>/dev/null)

    if [ -n "$UNCOMMITTED" ] && [ "$FORCE" != true ]; then
        echo "⚠️  Warning: Worktree has uncommitted changes:"
        echo ""
        git status --short
        echo ""
        echo "Use --force to remove anyway, or commit/stash your changes first."
        exit 1
    fi
    cd "$ROOT_DIR"
fi

# Remove the worktree
echo "Removing worktree..."

# Determine which git repo owns this worktree
if [ "$WORKTREE_TYPE" == "project" ]; then
    # Project worktrees: git worktrees of the project repo
    PROJECT_DIR="$ROOT_DIR/project"
    if [ "$FORCE" = true ]; then
        git -C "$PROJECT_DIR" worktree remove --force "$WORKTREE_DIR"
    else
        git -C "$PROJECT_DIR" worktree remove "$WORKTREE_DIR"
    fi
    git -C "$PROJECT_DIR" worktree prune
else
    # Workspace worktrees: git worktrees of the workspace repo
    if [ "$FORCE" = true ]; then
        git worktree remove --force "$WORKTREE_DIR"
    else
        git worktree remove "$WORKTREE_DIR"
    fi
    git worktree prune
fi

echo ""
echo "✅ Worktree removed successfully"

# Show branch deletion instructions
if [ -n "$BRANCH_NAME" ]; then
    echo ""
    REPO_CONTEXT="the project repo"
    REPO_PATH="$ROOT_DIR/project"
    if [ "$WORKTREE_TYPE" == "workspace" ]; then
        REPO_CONTEXT="the workspace repo"
        REPO_PATH="$ROOT_DIR"
    fi
    if git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
        echo "The branch '$BRANCH_NAME' still exists in $REPO_CONTEXT."
        echo ""
        echo "To delete it locally:"
        echo "  git -C $REPO_PATH branch -d $BRANCH_NAME"
        echo ""
        echo "To delete it on origin (if pushed):"
        echo "  git -C $REPO_PATH push origin --delete $BRANCH_NAME"
    fi
fi

echo ""
echo "Remaining worktrees:"
"$SCRIPT_DIR/worktree_list.sh" 2>/dev/null || git worktree list
