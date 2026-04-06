#!/bin/bash
# .agent/scripts/merge_pr.sh
# Merge a PR, remove its worktree, delete the branch, and sync main.
#
# Usage:
#   .agent/scripts/merge_pr.sh --pr <N> [--type workspace|project] [--no-roadmap-update]
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
#   1. Roadmap update (commit + push to feature branch before merge)
#   2. Merge the PR (--merge strategy)
#   3. Remove the worktree (cd to root first; fails safely if uncommitted changes)
#   4. Delete local and remote branches
#   5. Pull main to sync (workspace and project repos)
#
# Exit codes:
#   0 — success
#   1 — merge failed or dependency missing
#   2 — invalid arguments

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=_issue_helpers.sh
source "$SCRIPT_DIR/_issue_helpers.sh"

PR_NUMBER=""
WORKTREE_TYPE=""
NO_ROADMAP_UPDATE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)
            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --pr" >&2; exit 2; }
            PR_NUMBER="$2"; shift 2 ;;
        --type)
            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --type" >&2; exit 2; }
            WORKTREE_TYPE="$2"; shift 2 ;;
        --no-roadmap-update)
            NO_ROADMAP_UPDATE=true; shift ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "Usage: $0 --pr <N> [--type workspace|project] [--no-roadmap-update]" >&2
            exit 2 ;;
    esac
done

if [[ -z "$PR_NUMBER" ]]; then
    echo "ERROR: --pr <N> is required" >&2
    echo "Usage: $0 --pr <N> [--type workspace|project] [--no-roadmap-update]" >&2
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

# --- Step 1: Roadmap update (pre-merge) ---
if [[ "$NO_ROADMAP_UPDATE" == false ]]; then
    echo "  Checking roadmap for #${ISSUE_NUM}..."

    # Resolve the worktree that has the feature branch checked out.
    # The roadmap must be updated there (not in ROOT_DIR, which is on main).
    _WT_ROOT=""
    if [[ "$WORKTREE_TYPE" == "workspace" ]]; then
        _WT_PATH="$ROOT_DIR/worktrees/workspace/issue-workspace-${ISSUE_NUM}"
        [[ -d "$_WT_PATH" ]] && _WT_ROOT="$_WT_PATH"
    elif [[ "$WORKTREE_TYPE" == "project" ]]; then
        _WT_PATH="$ROOT_DIR/worktrees/project/issue-project-${ISSUE_NUM}"
        [[ -d "$_WT_PATH" ]] && _WT_ROOT="$_WT_PATH"
    fi

    if [[ -z "$_WT_ROOT" ]]; then
        echo "  ⚠️  No worktree found for issue #${ISSUE_NUM} — skipping roadmap update"
    else
        # Verify the worktree is on the expected feature branch
        _WT_BRANCH=$(git -C "$_WT_ROOT" branch --show-current 2>/dev/null || echo "")
        if [[ "$_WT_BRANCH" != "$PR_BRANCH" ]]; then
            echo "  ⚠️  Worktree is on '${_WT_BRANCH:-unknown}', expected '$PR_BRANCH' — skipping roadmap update"
        else
            # Run update_roadmap.sh in the worktree (stdout = changed file paths, stderr = status)
            _CHANGED_FILES=$("$SCRIPT_DIR/update_roadmap.sh" --issue "$ISSUE_NUM" --root "$_WT_ROOT" || true)

            if [[ -n "$_CHANGED_FILES" ]]; then
                echo "  Committing roadmap update to feature branch..."
                _WT_TOPLEVEL=$(git -C "$_WT_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "")

                if [[ -z "$_WT_TOPLEVEL" ]]; then
                    echo "  ⚠️  Unable to resolve worktree root — skipping roadmap commit"
                else
                    # Stage changed files using paths relative to the worktree root
                    while IFS= read -r changed_file; do
                        [[ -z "$changed_file" ]] && continue
                        case "$changed_file" in
                            "${_WT_TOPLEVEL}"/*)
                                _REL="${changed_file#"${_WT_TOPLEVEL}/"}"
                                git -C "$_WT_ROOT" add -- "$_REL" 2>/dev/null || true
                                ;;
                            *)
                                echo "  ⚠️  Skipping non-repo path: $changed_file" >&2
                                ;;
                        esac
                    done <<< "$_CHANGED_FILES"

                    if git -C "$_WT_ROOT" diff --cached --quiet 2>/dev/null; then
                        echo "  ⚠️  No staged changes — skipping roadmap commit"
                    else
                        git -C "$_WT_ROOT" commit -m "Update roadmap: mark #${ISSUE_NUM} as done" 2>/dev/null \
                            && echo "  ✅ Roadmap updated" \
                            || echo "  ⚠️  Roadmap commit failed — proceeding with merge"
                        git -C "$_WT_ROOT" push origin "$PR_BRANCH" 2>/dev/null \
                            && echo "  ✅ Roadmap commit pushed" \
                            || echo "  ⚠️  Roadmap push failed — proceeding with merge"
                    fi
                fi
            fi
        fi
    fi
else
    echo "  Roadmap update skipped (--no-roadmap-update)"
fi

# --- Step 2: Merge ---
echo "  Merging PR..."
resolve_gh_repo_args
if ! gh pr merge "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --merge; then
    echo "ERROR: Merge failed for PR #${PR_NUMBER}" >&2
    exit 1
fi
echo "  ✅ PR merged"

# --- Step 3: Remove worktree ---
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

# --- Step 4: Delete branches ---
echo "  Cleaning up branches..."
if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -d "$ROOT_DIR/project/.git" ]]; then
    BRANCH_REPO="$ROOT_DIR/project"
else
    BRANCH_REPO="$ROOT_DIR"
fi
git -C "$BRANCH_REPO" branch -d "$PR_BRANCH" 2>/dev/null && echo "  ✅ Local branch deleted" || true
git -C "$BRANCH_REPO" push origin --delete "$PR_BRANCH" 2>/dev/null && echo "  ✅ Remote branch deleted" || true

# --- Step 5: Sync ---
echo "  Syncing main..."
git pull --ff-only
echo "  ✅ Workspace synced"

# Also sync project repo for project-type merges
if [[ "$WORKTREE_TYPE" == "project" ]] && [[ -d "$ROOT_DIR/project/.git" ]]; then
    echo "  Syncing project..."
    git -C "$ROOT_DIR/project" pull --ff-only 2>/dev/null && echo "  ✅ Project synced" || true
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
