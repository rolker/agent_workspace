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

# --- Resolve workspace root (main tree) ---
# Use `git worktree list --porcelain` instead of $SCRIPT_DIR/../.. so the
# resolution is correct when the script is invoked from inside a
# worktree (e.g. `make merge-pr` from a feature worktree). With the
# relative-path approach, ROOT_DIR resolved to the worktree root, not
# the main tree, so downstream worktree detection and cleanup silently
# skipped. See issue #146.
#
# git worktree list always prints the main worktree first, in absolute
# form, regardless of invocation cwd.
# `|| true` so invocation outside any repo (git fails, pipefail would
# otherwise trip set -e) falls through to the explicit empty-string
# check below with a clearer error.
ROOT_DIR=$({ git -C "$SCRIPT_DIR" worktree list --porcelain 2>/dev/null \
    | head -n1 | sed 's/^worktree //'; } || true)
if [[ -z "$ROOT_DIR" ]]; then
    echo "ERROR: merge_pr.sh must run from within a git repository" >&2
    exit 1
fi

# --- Helper: find a worktree for a given branch ---
# Issue #173: previous logic globbed `worktrees/project/issue-project-<N>`,
# which never matched the actual multi-project layout
# (`worktrees/project/<repo>/issue-<repo>-<N>`). Asking git for the
# authoritative location side-steps that whole class of path-encoding bug
# AND naturally covers legacy `.workspace-worktrees/` paths — anything git
# tracks as a worktree shows up here regardless of where it lives on disk.
find_worktree_for_branch() {
    local repo="$1"
    local branch="$2"
    git -C "$repo" worktree list --porcelain 2>/dev/null \
        | awk -v target="refs/heads/$branch" '
            /^worktree / { wt = substr($0, 10); next }
            /^branch /   { if ($2 == target) { print wt; exit } }
        '
}

# --- Discover the workspace and (optional) project remotes ---
# Workspace remote always exists (we just resolved ROOT_DIR via git).
# Project remote is only resolved when project/ is configured. Empty
# project remote with project/ present is a misconfiguration — surface
# it now rather than letting it manifest as a silent "PR not found"
# (issue #173 root cause).
WS_REMOTE=$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "")
PJ_REMOTE=""
if [[ -e "$ROOT_DIR/project/.git" ]]; then
    PJ_REMOTE=$(git -C "$ROOT_DIR/project" remote get-url origin 2>/dev/null || echo "")
    if [[ -z "$PJ_REMOTE" ]]; then
        echo "ERROR: $ROOT_DIR/project has no 'origin' remote configured." >&2
        echo "  Cannot resolve project PRs. Configure the remote, or pass" >&2
        echo "  --type workspace if this is intentionally workspace-only." >&2
        exit 1
    fi
fi

# --- Resolve which repo owns the PR (collision-safe) ---
# PR numbers are repo-local: workspace #84 ≠ project #84. Trying repos
# in sequence and taking the first hit (the original design) silently
# picks the wrong one when both repos have an open PR with the same
# number. Query both, filter to OPEN, then:
#   0 hits → error
#   1 hit  → use it (and implicitly determine WORKTREE_TYPE if --type
#            was not supplied)
#   2 hits → error and require --type to disambiguate
# When --type IS supplied, query only the matching repo.

# Query a single repo. On OPEN PR, populates QUERY_BRANCH/QUERY_TITLE
# and returns 0. On not-found OR not-OPEN, returns 1 silently. On other
# errors (auth, network), prints the error and returns 2.
QUERY_BRANCH=""
QUERY_TITLE=""
query_pr() {
    local remote="$1"
    local out err rc=0
    local err_file
    err_file=$(mktemp)
    out=$(gh pr view "$PR_NUMBER" -R "$remote" \
            --json state,headRefName,title 2>"$err_file") || rc=$?
    err=$(<"$err_file")
    rm -f "$err_file"

    if [[ $rc -eq 0 ]] && [[ -n "$out" ]]; then
        local state
        state=$(echo "$out" | jq -r '.state // empty')
        if [[ "$state" == "OPEN" ]]; then
            QUERY_BRANCH=$(echo "$out" | jq -r '.headRefName // empty')
            QUERY_TITLE=$(echo "$out" | jq -r '.title // empty')
            return 0
        fi
        return 1   # exists but not OPEN — irrelevant for merge
    fi

    # Distinguish "PR not found" from auth/network errors. Silently
    # picking the only authed repo would be the same class of bug
    # we're fixing — propagate other errors and require --type.
    case "$err" in
        *"Could not resolve to"*|*"GraphQL: Could not"*|*"no pull"*|*"404"*)
            return 1 ;;
        *)
            echo "ERROR: gh failed against $remote:" >&2
            echo "  $err" >&2
            return 2 ;;
    esac
}

WS_HIT=false; WS_BRANCH=""; WS_TITLE=""
PJ_HIT=false; PJ_BRANCH=""; PJ_TITLE=""

if [[ -z "$WORKTREE_TYPE" || "$WORKTREE_TYPE" == "workspace" ]] && [[ -n "$WS_REMOTE" ]]; then
    if query_pr "$WS_REMOTE"; then
        WS_HIT=true
        WS_BRANCH="$QUERY_BRANCH"
        WS_TITLE="$QUERY_TITLE"
    elif [[ $? -eq 2 ]]; then
        echo "  Pass --type to bypass auto-detection." >&2
        exit 1
    fi
fi

if [[ -z "$WORKTREE_TYPE" || "$WORKTREE_TYPE" == "project" ]] && [[ -n "$PJ_REMOTE" ]]; then
    if query_pr "$PJ_REMOTE"; then
        PJ_HIT=true
        PJ_BRANCH="$QUERY_BRANCH"
        PJ_TITLE="$QUERY_TITLE"
    elif [[ $? -eq 2 ]]; then
        echo "  Pass --type to bypass auto-detection." >&2
        exit 1
    fi
fi

GH_REPO_ARGS=()
if $WS_HIT && $PJ_HIT; then
    echo "ERROR: PR #${PR_NUMBER} is open in BOTH repos:" >&2
    echo "  workspace: $WS_TITLE" >&2
    echo "  project:   $PJ_TITLE" >&2
    echo "  Pass --type workspace or --type project to disambiguate." >&2
    exit 2
elif $WS_HIT; then
    WORKTREE_TYPE="workspace"
    PR_BRANCH="$WS_BRANCH"
elif $PJ_HIT; then
    WORKTREE_TYPE="project"
    PR_BRANCH="$PJ_BRANCH"
    GH_REPO_ARGS=("-R" "$PJ_REMOTE")
else
    if [[ -n "$WORKTREE_TYPE" ]]; then
        echo "ERROR: PR #${PR_NUMBER} not open in $WORKTREE_TYPE repo." >&2
    else
        echo "ERROR: PR #${PR_NUMBER} not open in either workspace or project." >&2
    fi
    exit 1
fi

ISSUE_NUM=$(echo "$PR_BRANCH" | sed -nE 's/^feature\/[iI]ssue-([0-9]+).*/\1/p')
if [[ -z "$ISSUE_NUM" ]]; then
    echo "ERROR: Could not extract issue number from branch '$PR_BRANCH'" >&2
    echo "Expected pattern: feature/issue-<N> or feature/ISSUE-<N>-<desc>" >&2
    echo "Note: skill worktree branches are not supported by this script" >&2
    exit 1
fi

echo "========================================"
echo "Merging PR #${PR_NUMBER} (issue #${ISSUE_NUM})"
echo "========================================"

# --- Step 1: Roadmap update (pre-merge) ---
if [[ "$NO_ROADMAP_UPDATE" == false ]]; then
    echo "  Checking roadmap for #${ISSUE_NUM}..."

    # Resolve the worktree that has the feature branch checked out via
    # find_worktree_for_branch (issue #173) — git is the authority on
    # where worktrees live, so we don't have to re-encode path
    # conventions here. For project worktrees, list against the project
    # repo since project worktrees are tracked there.
    _WT_REPO="$ROOT_DIR"
    [[ "$WORKTREE_TYPE" == "project" ]] && _WT_REPO="$ROOT_DIR/project"
    _WT_ROOT=$(find_worktree_for_branch "$_WT_REPO" "$PR_BRANCH")

    if [[ -z "$_WT_ROOT" ]]; then
        echo "  ⚠️  No worktree found for issue #${ISSUE_NUM} — skipping roadmap update"
    else
        # Belt-and-braces: confirm git's worktree-list output really is on
        # the expected branch (handles a detached-HEAD edge case where the
        # `branch ` line was present but transient).
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
# GH_REPO_ARGS was set during PR resolution above (-R <project-remote> for
# project PRs, empty for workspace PRs). Don't re-resolve.
echo "  Merging PR..."
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
