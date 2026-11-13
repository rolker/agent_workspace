#!/bin/bash
# Script: .agent/scripts/check_branch_updates.sh
# Purpose: Check if the default branch (or a named base branch) has new commits
#          and provide merge/rebase recommendations
# Usage: check_branch_updates.sh [--strict] [--base <branch>]
#
#   --strict         exit 1 when the branch is behind
#   --base <branch>  compare with origin/<branch> instead of the default branch
#                    (issue 429: a package issue's branch started from its
#                    recorded base, which need not be the default branch).
#                    With no --base the comparison is with the default
#                    branch, as before; the pre-commit hook and
#                    worktree_enter.sh call it that way.
#
# The fetch names an explicit refspec, +refs/heads/<b>:refs/remotes/origin/<b>,
# so a --single-branch or otherwise narrowed clone (whose configured refspec
# does not cover <b>) still gets a fresh origin/<b>; a plain
# `git fetch origin <b>` there writes FETCH_HEAD only and the counts would
# compare with a missing or stale origin/<b>.
#
# Exit codes:
#   0 - No updates needed or on the compared branch (also when origin cannot
#       be fetched or did not answer in time: a warning is printed, nothing
#       is blocked)
#   1 - Strict mode only: the branch is behind
#   2 - Error occurred (also an unknown option or a missing --base value;
#       origin answers but has no branch <b>; or origin/<b> is missing after
#       a fetch that reported success)

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: This script should be executed, not sourced."
    echo "  Run: ${BASH_SOURCE[0]} $*"
    return 1
fi
set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [--strict] [--base <branch>]" >&2
}

# Parse arguments
STRICT_MODE=false
BASE_BRANCH=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict) STRICT_MODE=true; shift ;;
        --base)
            if [[ $# -lt 2 || -z "$2" ]]; then
                echo -e "${RED}✗ Error:${NC} --base needs a branch name" >&2
                usage
                exit 2
            fi
            BASE_BRANCH="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo -e "${RED}✗ Error:${NC} unknown argument '$1'" >&2
            usage
            exit 2 ;;
    esac
done
if [[ -n "$BASE_BRANCH" ]] && ! git check-ref-format --branch "$BASE_BRANCH" >/dev/null 2>&1; then
    echo -e "${RED}✗ Error:${NC} --base '$BASE_BRANCH' is not a valid branch name" >&2
    exit 2
fi

# Every call to origin is bounded: no credential prompt, and at most
# CHECK_BRANCH_UPDATES_TIMEOUT seconds (default 60) when `timeout` exists.
# A call that times out is a failed call (the fetch warning below).
fetch_limit() {
    local limit="${CHECK_BRANCH_UPDATES_TIMEOUT:-60}"
    [[ "$limit" =~ ^[1-9][0-9]*$ ]] || limit=60
    echo "$limit"
}
bounded_git() {
    if command -v timeout >/dev/null 2>&1; then
        GIT_TERMINAL_PROMPT=0 timeout -k 5 "$(fetch_limit)" git "$@"
    else
        GIT_TERMINAL_PROMPT=0 git "$@"
    fi
}

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD) || {
    echo -e "${RED}✗ Error:${NC} Could not determine current Git branch. Are you in a Git repository with a checked-out branch?"
    exit 2
}

# The branch compared with: --base when given, else the default branch.
# DEFAULT_BRANCH keeps its name for the rest of the script; KIND names it in
# the messages ("default branch" or "base branch").
if [[ -n "$BASE_BRANCH" ]]; then
    DEFAULT_BRANCH="$BASE_BRANCH"
    KIND="base branch"
else
    KIND="default branch"
    REMOTE_HEAD=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || echo "")
    if [ -n "$REMOTE_HEAD" ]; then
        DEFAULT_BRANCH=${REMOTE_HEAD#refs/remotes/origin/}
    else
        # Fallback: query remote (slower)
        DEFAULT_BRANCH=$(bounded_git remote show origin 2>/dev/null | grep "HEAD branch" | cut -d: -f2 | xargs || echo "main")
    fi
    # The pipeline above can succeed with no output (origin unreachable:
    # xargs still exits 0), which would leave the name empty.
    [[ -n "$DEFAULT_BRANCH" ]] || DEFAULT_BRANCH="main"
fi

# If we're on the compared branch, no need to check
if [ "$CURRENT_BRANCH" == "$DEFAULT_BRANCH" ]; then
    echo -e "${GREEN}✓${NC} On $KIND ($DEFAULT_BRANCH). No update check needed."
    exit 0
fi

# Fetch latest from origin (quietly)
# For shallow clones, we may need to unshallow or fetch with depth
echo "Checking for updates in $KIND ($DEFAULT_BRANCH)..."

# Check if this is a shallow clone
IS_SHALLOW=$(git rev-parse --is-shallow-repository 2>/dev/null || echo "false")
DEPTH_ARGS=()
# For shallow clones, fetch with depth to get enough history
[ "$IS_SHALLOW" == "true" ] && DEPTH_ARGS=(--depth=50)

FETCH_RC=0
bounded_git fetch --quiet ${DEPTH_ARGS[@]+"${DEPTH_ARGS[@]}"} origin -- \
    "+refs/heads/$DEFAULT_BRANCH:refs/remotes/origin/$DEFAULT_BRANCH" 2>/dev/null || FETCH_RC=$?
if [ "$FETCH_RC" -ne 0 ]; then
    if [ "$FETCH_RC" -eq 124 ] || [ "$FETCH_RC" -eq 137 ]; then
        echo -e "${YELLOW}⚠️  Warning: origin did not answer within $(fetch_limit)s; not compared with $DEFAULT_BRANCH${NC}"
        exit 0  # Don't block on fetch failures
    fi
    # Did the fetch fail because origin has no such branch, or because
    # origin could not be reached? ls-remote --exit-code tells them apart
    # (2: origin answered and has no such branch).
    LS_RC=0
    bounded_git ls-remote --exit-code --heads origin "refs/heads/$DEFAULT_BRANCH" >/dev/null 2>&1 || LS_RC=$?
    if [ "$LS_RC" -eq 2 ]; then
        echo -e "${RED}✗ Error:${NC} origin has no branch '$DEFAULT_BRANCH'; nothing to compare with" >&2
        exit 2
    fi
    echo -e "${YELLOW}⚠️  Warning: Could not fetch '$DEFAULT_BRANCH' from origin; not compared${NC}"
    exit 0  # Don't block on fetch failures
fi
if ! git rev-parse --verify --quiet "refs/remotes/origin/$DEFAULT_BRANCH^{commit}" >/dev/null; then
    echo -e "${RED}✗ Error:${NC} the fetch of '$DEFAULT_BRANCH' reported success but wrote no origin/$DEFAULT_BRANCH; nothing to compare with" >&2
    exit 2
fi

# Get commit counts
COMMITS_BEHIND=$(git rev-list --count HEAD..origin/"$DEFAULT_BRANCH" 2>/dev/null || echo "0")
COMMITS_AHEAD=$(git rev-list --count origin/"$DEFAULT_BRANCH"..HEAD 2>/dev/null || echo "0")

# Check merge base to detect divergence
# In shallow clones, this might not work, so we handle gracefully
MERGE_BASE=$(git merge-base HEAD origin/"$DEFAULT_BRANCH" 2>/dev/null || echo "")
if [ -z "$MERGE_BASE" ]; then
    # Merge base not found - likely shallow clone or unrelated histories
    # We can still provide useful info based on commit counts
    if [ "$COMMITS_BEHIND" -eq 0 ] && [ "$COMMITS_AHEAD" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Branch appears to be in sync with $DEFAULT_BRANCH"
        exit 0
    fi
    # Continue with limited information
    echo -e "${YELLOW}⚠️  Note: Limited history available (shallow clone)${NC}"
fi

# Display status
if [ "$COMMITS_BEHIND" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Feature branch is up-to-date with $DEFAULT_BRANCH"
    exit 0
fi

# Branch is behind
echo ""
if [[ -n "$BASE_BRANCH" ]]; then
    echo -e "${YELLOW}⚠️  Base branch has new commits!${NC}"
    echo ""
    echo -e "  Current branch:  ${BLUE}$CURRENT_BRANCH${NC}"
    echo -e "  Base branch:     ${BLUE}origin/$DEFAULT_BRANCH${NC}"
else
    echo -e "${YELLOW}⚠️  Default branch has new commits!${NC}"
    echo ""
    echo -e "  Current branch:  ${BLUE}$CURRENT_BRANCH${NC}"
    echo -e "  Default branch:  ${BLUE}$DEFAULT_BRANCH${NC}"
fi
echo -e "  Commits behind:  ${YELLOW}$COMMITS_BEHIND${NC}"
echo -e "  Commits ahead:   ${GREEN}$COMMITS_AHEAD${NC}"
echo ""

# Check if branches have diverged
DIVERGED=false
if [ "$COMMITS_AHEAD" -gt 0 ] && [ "$COMMITS_BEHIND" -gt 0 ]; then
    DIVERGED=true
    echo -e "${YELLOW}Branches have diverged${NC}"
    echo ""
fi

# Provide recommendations
echo -e "${BLUE}Recommendations:${NC}"
echo ""

if [ "$DIVERGED" == "true" ]; then
    echo "  Your branch has diverged from $DEFAULT_BRANCH."
    echo "  You have two options:"
    echo ""
    echo "  1.  MERGE (Recommended for collaborative work):"
    echo "     ${GREEN}git merge origin/$DEFAULT_BRANCH${NC}"
    echo "     • Preserves complete history"
    echo "     • Creates a merge commit"
    echo "     • Safe and reversible"
    echo ""
    echo "  2.  REBASE (For cleaner history):"
    echo "     ${YELLOW}git rebase origin/$DEFAULT_BRANCH${NC}"
    echo "     • Replays your commits on top of latest $DEFAULT_BRANCH"
    echo "     • Creates linear history"
    echo "     • May require force-push if already pushed"
    echo "     • ⚠️  Use with caution on shared branches"
else
    # Only behind, not ahead - fast-forward possible
    echo "  Your branch is behind but has no unique commits."
    echo ""
    echo "  Fast-forward update:"
    echo "     ${GREEN}git merge origin/$DEFAULT_BRANCH${NC}"
    echo "     • Will fast-forward (no merge commit needed)"
    echo "     • Safe and automatic"
fi

echo ""
echo -e "${BLUE}After updating:${NC}"
echo "   • Re-run your tests to ensure compatibility"
echo "   • Review any merge conflicts carefully"
echo "   • Consider rebasing only if you haven't pushed yet"
echo ""

# Show recent commits in default branch
echo -e "${BLUE}Recent commits in $DEFAULT_BRANCH:${NC}"
git log --oneline --max-count=5 origin/"$DEFAULT_BRANCH" --not HEAD 2>/dev/null || echo "  (Could not retrieve commits)"
echo ""

# Exit with appropriate code
if [ "$STRICT_MODE" == "true" ]; then
    echo -e "${RED}❌ Strict mode: Blocking due to outdated branch${NC}"
    echo "   Run one of the recommended commands above and try again."
    exit 1
fi

echo -e "${YELLOW}ℹ️  Informational: You may want to update your branch${NC}"
echo ""
# In informational mode, we don't block the commit
exit 0
