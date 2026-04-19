#!/bin/bash
# .agent/scripts/_resolve_work_plans_dir.sh
# Shared helper for resolving the per-issue work-plans directory.
#
# Source this file from other scripts:
#   source "$SCRIPT_DIR/_resolve_work_plans_dir.sh"
#
# Exposes: resolve_work_plans_dir <issue-number>
#   On success: echoes the resolved work-plans directory path on stdout.
#               If $WORK_PLANS_DIR_OVERRIDE is set, that value is echoed
#               as-is (may be relative, not normalized). Otherwise the
#               returned path is absolute. No trailing slash either way.
#   On failure: prints error to stderr and returns 1.
#
# Resolution rules (in order):
#   1. If $WORK_PLANS_DIR_OVERRIDE is set (callers export this after parsing
#      --work-plans-dir), return it verbatim (no normalization).
#   2. Else if $WORKTREE_ISSUE equals the requested issue number, return
#      "$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<N>".
#   3. Else abort with remediation guidance pointing at worktree_enter.sh.
#
# Caller-gotcha: prefer a bare assignment (`WORK_PLANS_DIR=$(resolve ... )
# || exit 4`) over `local WORK_PLANS_DIR=$(resolve ... )`. The `local`
# builtin's own exit status masks the command substitution's, so the
# `|| exit` never fires on failure.
#
# Rationale: see issue #147. Using `git rev-parse --show-toplevel` without a
# worktree check lets scripts silently write per-issue artifacts into `main`
# when invoked from the wrong tree. Callers source this helper to fail loudly
# instead.

resolve_work_plans_dir() {
    # Use "${1:-}" so callers running under `set -u` (e.g.
    # cross_model_review.sh runs with set -euo pipefail) don't trigger
    # "unbound variable" before the explicit empty-string check below.
    local issue="${1:-}"

    if [ -z "$issue" ]; then
        echo "ERROR: resolve_work_plans_dir: issue number required" >&2
        return 1
    fi

    # Rule 1: explicit override wins.
    if [ -n "${WORK_PLANS_DIR_OVERRIDE:-}" ]; then
        echo "$WORK_PLANS_DIR_OVERRIDE"
        return 0
    fi

    # Rule 2: WORKTREE_ISSUE must match.
    if [ -n "${WORKTREE_ISSUE:-}" ] && [ "$WORKTREE_ISSUE" = "$issue" ]; then
        local toplevel
        toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || {
            echo "ERROR: resolve_work_plans_dir: not inside a git repository" >&2
            return 1
        }
        echo "${toplevel}/.agent/work-plans/issue-${issue}"
        return 0
    fi

    # Rule 3: abort.
    {
        echo "ERROR: refusing to resolve work-plans dir for issue #${issue} outside its worktree."
        echo ""
        if [ -n "${WORKTREE_ISSUE:-}" ]; then
            echo "  Current \$WORKTREE_ISSUE is '${WORKTREE_ISSUE}', not '${issue}'."
        else
            echo "  \$WORKTREE_ISSUE is not set — you're likely in the main tree or a shell"
            echo "  that didn't source worktree_enter.sh."
        fi
        echo ""
        echo "  Enter the matching worktree first (pick workspace or project by issue):"
        echo "    source .agent/scripts/worktree_enter.sh --issue ${issue} --type workspace"
        echo "    source .agent/scripts/worktree_enter.sh --issue ${issue} --type project"
        echo ""
        echo "  Or pass --work-plans-dir <path> (sets \$WORK_PLANS_DIR_OVERRIDE) to"
        echo "  override explicitly."
    } >&2
    return 1
}

# Warn if the file is executed directly — it only defines a function and
# must be sourced.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "ERROR: _resolve_work_plans_dir.sh must be sourced, not executed directly." >&2
    echo "Usage: source .agent/scripts/_resolve_work_plans_dir.sh" >&2
    exit 1
fi
