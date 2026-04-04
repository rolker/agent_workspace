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
# Limitations:
#   - Only works for issue-based branches (feature/issue-<N> pattern)
#   - Skill worktree branches are not supported
#   - If run from inside the worktree being removed, your shell's CWD
#     will be invalid after the script completes — cd to the workspace root
#
# Steps:
#   1. Merge the PR (--merge strategy)
#   2. cd to workspace root (required for worktree removal)
#   3. Remove the worktree (fails safely if uncommitted changes exist)
#   4. Delete local and remote branches
#   5. Pull main to sync (workspace and project repos)
#   6. Roadmap reminder (soft check if merged issue relates to a roadmap item)
#
# Exit codes:
#   0 — success
#   1 — merge failed or dependency missing
#   2 — invalid arguments

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# --- Resolve target repo for gh commands ---
# For project PRs, gh must target the project repo, not the workspace repo.
GH_REPO_ARGS=()
resolve_gh_repo_args() {
    GH_REPO_ARGS=()
    if [[ "$WORKTREE_TYPE" == "project" ]]; then
        local project_remote
        project_remote=$(git -C "$ROOT_DIR/project" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$project_remote" ]]; then
            GH_REPO_ARGS=("-R" "$project_remote")
        fi
    fi
}

# --- Extract issue number from PR branch ---
# Note: GH_REPO_ARGS may be empty at this point (type not yet known).
# We try without -R first; if --type project was specified, we resolve after.
resolve_gh_repo_args
PR_BRANCH=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json headRefName --jq '.headRefName' 2>/dev/null)
if [[ -z "$PR_BRANCH" ]]; then
    echo "ERROR: Could not fetch PR #${PR_NUMBER}" >&2
    exit 1
fi

ISSUE_NUM=$(echo "$PR_BRANCH" | sed -nE 's/^feature\/[iI]ssue-([0-9]+).*/\1/p')
if [[ -z "$ISSUE_NUM" ]]; then
    echo "ERROR: Could not extract issue number from branch '$PR_BRANCH'" >&2
    echo "Expected pattern: feature/issue-<N> or feature/ISSUE-<N>-<desc>" >&2
    echo "Note: skill worktree branches are not supported by this script" >&2
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
resolve_gh_repo_args
if ! gh pr merge "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --merge; then
    echo "ERROR: Merge failed for PR #${PR_NUMBER}" >&2
    exit 1
fi
echo "  ✅ PR merged"

# --- Step 2: Remove worktree ---
if [[ -n "$WORKTREE_TYPE" ]]; then
    echo "  Removing worktree..."
    # Must run from root, not from inside the worktree
    cd "$ROOT_DIR"
    if "$SCRIPT_DIR/worktree_remove.sh" --issue "$ISSUE_NUM" --type "$WORKTREE_TYPE"; then
        echo "  ✅ Worktree removed"
    else
        echo "  ⚠️  Worktree removal failed — check for uncommitted changes" >&2
    fi
fi

# --- Step 3: Delete branches ---
echo "  Cleaning up branches..."
if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -d "$ROOT_DIR/project/.git" ]]; then
    BRANCH_REPO="$ROOT_DIR/project"
else
    BRANCH_REPO="$ROOT_DIR"
fi
git -C "$BRANCH_REPO" branch -d "$PR_BRANCH" 2>/dev/null && echo "  ✅ Local branch deleted" || true
git -C "$BRANCH_REPO" push origin --delete "$PR_BRANCH" 2>/dev/null && echo "  ✅ Remote branch deleted" || true

# --- Step 4: Sync ---
echo "  Syncing main..."
git pull --ff-only
echo "  ✅ Workspace synced"

# Also sync project repo for project-type merges
if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -d "$ROOT_DIR/project/.git" ]]; then
    echo "  Syncing project..."
    git -C "$ROOT_DIR/project" pull --ff-only 2>/dev/null && echo "  ✅ Project synced" || true
fi

# --- Step 5: Roadmap reminder ---
# Soft check: does the merged issue relate to a roadmap item?
ISSUE_TITLE=$(gh issue view "$ISSUE_NUM" "${GH_REPO_ARGS[@]}" --json title --jq '.title' 2>/dev/null || echo "")
if [[ -n "$ISSUE_TITLE" ]]; then
    ROADMAP_MATCHES=()
    # Extract significant keywords (3+ chars, skip common words)
    KEYWORDS=$(echo "$ISSUE_TITLE" | tr '[:upper:]' '[:lower:]' | grep -oE '[a-z]{3,}' \
        | grep -vxE '(the|and|for|with|from|that|this|into|when|also|not|but|are|was|has|have|will|can|its|all|new|add|use|get|set|fix|run)' \
        | head -5)
    if [[ -n "$KEYWORDS" ]]; then
        for roadmap in "$ROOT_DIR/docs/ROADMAP.md" "$ROOT_DIR/project/ROADMAP.md"; do
            [[ -f "$roadmap" ]] || continue
            roadmap_rel="${roadmap#"$ROOT_DIR/"}"
            while IFS= read -r keyword; do
                if grep -qi "$keyword" "$roadmap" 2>/dev/null; then
                    ROADMAP_MATCHES+=("$roadmap_rel")
                    break
                fi
            done <<< "$KEYWORDS"
        done
    fi
    if [[ ${#ROADMAP_MATCHES[@]} -gt 0 ]]; then
        echo ""
        echo "📋 Roadmap reminder: issue #${ISSUE_NUM} (\"${ISSUE_TITLE}\") may relate to:"
        for match in "${ROADMAP_MATCHES[@]}"; do
            echo "   - $match"
        done
        echo "   Consider updating the roadmap if this completes a tracked item."
    fi
fi

echo ""
echo "========================================"
echo "✅ Done: PR #${PR_NUMBER} merged, cleaned up, and synced"
echo "========================================"

# Warn if the caller's shell may be in a deleted directory
if [[ -n "$WORKTREE_TYPE" ]]; then
    echo ""
    echo "NOTE: If you ran this from inside the worktree, run:"
    echo "  cd $ROOT_DIR"
fi
