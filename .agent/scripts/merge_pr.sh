#!/bin/bash
# .agent/scripts/merge_pr.sh
# Merge a PR, remove its worktree, delete the branch, and sync main.
#
# Usage:
#   .agent/scripts/merge_pr.sh --pr <N> [--type workspace|project]
#
# If --type is omitted, the script auto-detects by checking which worktree
# exists for the issue. If neither or both exist, it asks.
#
# Steps:
#   1. Merge the PR (--merge strategy)
#   2. cd to workspace root (required for worktree removal)
#   3. Remove the worktree
#   4. Delete local and remote branches
#   5. Pull main to sync
#
# Exit codes:
#   0 — success
#   1 — merge failed or dependency missing
#   2 — invalid arguments

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/framework_config.sh"

PR_NUMBER=""
WORKTREE_TYPE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)
            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --pr" >&2; exit 2; }
            PR_NUMBER="$2"; shift 2 ;;
        --type)
            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --type" >&2; exit 2; }
            WORKTREE_TYPE="$2"; shift 2 ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "Usage: $0 --pr <N> [--type workspace|project]" >&2
            exit 2 ;;
    esac
done

if [[ -z "$PR_NUMBER" ]]; then
    echo "ERROR: --pr <N> is required" >&2
    echo "Usage: $0 --pr <N> [--type workspace|project]" >&2
    exit 2
fi

if [[ -n "$WORKTREE_TYPE" ]] && [[ "$WORKTREE_TYPE" != "workspace" && "$WORKTREE_TYPE" != "project" ]]; then
    echo "ERROR: --type must be 'workspace' or 'project'" >&2
    exit 2
fi

# --- Resolve workspace root ---
ROOT_DIR="$SCRIPT_DIR/../.."
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

# --- Extract issue number from PR branch ---
PR_BRANCH=$(gh pr view "$PR_NUMBER" --json headRefName --jq '.headRefName' 2>/dev/null)
if [[ -z "$PR_BRANCH" ]]; then
    echo "ERROR: Could not fetch PR #${PR_NUMBER}" >&2
    exit 1
fi

ISSUE_NUM=$(echo "$PR_BRANCH" | sed -nE 's/^feature\/[iI]ssue-([0-9]+).*/\1/p')
if [[ -z "$ISSUE_NUM" ]]; then
    echo "ERROR: Could not extract issue number from branch '$PR_BRANCH'" >&2
    echo "Expected pattern: feature/issue-<N> or feature/ISSUE-<N>-<desc>" >&2
    exit 1
fi

# --- Auto-detect worktree type if not specified ---
if [[ -z "$WORKTREE_TYPE" ]]; then
    WS_PATH="$ROOT_DIR/worktrees/workspace/issue-workspace-${ISSUE_NUM}"
    PJ_PATH="$ROOT_DIR/worktrees/project/issue-project-${ISSUE_NUM}"
    # Also check legacy path
    WS_LEGACY="$ROOT_DIR/.workspace-worktrees/issue-workspace-${ISSUE_NUM}"

    WS_EXISTS=false
    PJ_EXISTS=false
    [[ -d "$WS_PATH" || -d "$WS_LEGACY" ]] && WS_EXISTS=true
    [[ -d "$PJ_PATH" ]] && PJ_EXISTS=true

    if $WS_EXISTS && ! $PJ_EXISTS; then
        WORKTREE_TYPE="workspace"
    elif $PJ_EXISTS && ! $WS_EXISTS; then
        WORKTREE_TYPE="project"
    elif $WS_EXISTS && $PJ_EXISTS; then
        echo "ERROR: Both workspace and project worktrees exist for issue #${ISSUE_NUM}" >&2
        echo "  Specify --type workspace or --type project" >&2
        exit 2
    else
        echo "WARNING: No worktree found for issue #${ISSUE_NUM} — will merge and sync only" >&2
    fi
fi

echo "========================================"
echo "Merging PR #${PR_NUMBER} (issue #${ISSUE_NUM})"
echo "========================================"

# --- Step 1: Merge ---
echo "  Merging PR..."
if ! gh pr merge "$PR_NUMBER" --merge; then
    echo "ERROR: Merge failed for PR #${PR_NUMBER}" >&2
    exit 1
fi
echo "  ✅ PR merged"

# --- Step 2: Remove worktree ---
if [[ -n "$WORKTREE_TYPE" ]]; then
    echo "  Removing worktree..."
    # Must run from root, not from inside the worktree
    cd "$ROOT_DIR"
    if "$SCRIPT_DIR/worktree_remove.sh" --issue "$ISSUE_NUM" --type "$WORKTREE_TYPE" --force 2>/dev/null; then
        echo "  ✅ Worktree removed"
    else
        echo "  ⚠️  Worktree removal failed (may already be removed)" >&2
    fi
fi

# --- Step 3: Delete branches ---
echo "  Cleaning up branches..."
cd "$ROOT_DIR"
git branch -d "$PR_BRANCH" 2>/dev/null && echo "  ✅ Local branch deleted" || true
git push origin --delete "$PR_BRANCH" 2>/dev/null && echo "  ✅ Remote branch deleted" || true

# --- Step 4: Sync main ---
echo "  Syncing main..."
git pull --ff-only
echo "  ✅ Main synced"

echo ""
echo "========================================"
echo "✅ Done: PR #${PR_NUMBER} merged, cleaned up, and synced"
echo "========================================"
