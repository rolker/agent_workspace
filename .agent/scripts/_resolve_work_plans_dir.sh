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
#      --work-plans-dir), return it verbatim (no normalization), once
#      records_path (below) has let it through.
#   2. Else if $WORKTREE_ISSUE equals the requested issue number, return
#      "$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<N>".
#   2b. Else if $WORKTREE_ISSUE is UNSET (not merely different) and the
#       current git toplevel's basename matches "issue-*-<N>" or the current
#       branch matches "feature/issue-<N>" (optionally "-<description>",
#       case-insensitive), return the same toplevel-anchored path. This
#       covers EnterWorktree-based sessions (issue #224) where the cwd is
#       inside the correct worktree but worktree_enter.sh was never sourced.
#       A set-but-mismatched $WORKTREE_ISSUE never takes this fallback.
#   3. Else abort with remediation guidance pointing at worktree_enter.sh.
#
# Every rule's answer passes records_path, so none returns a directory
# inside a package worktree that is not the issue's own checkout (issue 429).
#
# THE records gate (issue 429, ADR-0012 package worktrees). Every script
# that reads or writes an issue's records reaches the path through one of
# these two, and both end in the same check:
#   records_path <path> [<from-dir>]
#     <path> is a file or directory at or under
#     <repo>/.agent/work-plans/issue-<N>/ (relative to $PWD; it need not
#     exist yet); <N> is read from the path. Prints <path> unchanged when
#     the repository holding it may hold issue <N>'s records, and refuses
#     (stderr, naming the right checkout, return 1) when it may not:
#     inside a package worktree (a .worktree-repos manifest encloses the
#     path's repository, the path itself, or <from-dir>, default $PWD),
#     only the manifest's issue checkout may (issue_checkout_of). A sibling
#     checkout with the same issue number and the worktree's top folder
#     (whose git toplevel is some other repository, the workspace's main
#     checkout, say) are refused for reads and writes alike. No manifest
#     anywhere: a no-op, so workspace issues and single-repo project
#     worktrees are unchanged. A path not of that shape is no timeline and
#     is printed unchanged (a --no-progress temp dir, a test fixture).
#   records_dir <N> [<dir>]
#     <dir>'s git toplevel (default .) + /.agent/work-plans/issue-<N>,
#     through records_path with <dir> as <from-dir>.
# Callers: resolve_work_plans_dir (every rule), progress_append.sh, every
# review_progress.sh subcommand that takes or builds a records path (round,
# persist, sources, findings, check, plan-sha), dispatch_phase.sh
# (resolve_issue_dir and `next --progress`) and merge_pr.sh's gate lookup.
#
# Also exposes:
#   issue_checkout_of <worktree-dir> <N>
#     The directory issue <N>'s work and records happen in. A worktree with
#     no .worktree-repos manifest is that directory itself (workspace and
#     single-repo project worktrees write none). A manifest's issue checkout
#     is the entry on feature/issue-<N> (or a lone "." entry, the worktree
#     itself): the owning repository, by the adapter's branch rule
#     (ros2_colcon worktree_repos names every sibling
#     feature/<repo>-issue-<N>). Refuses (stderr, return 1) when the
#     manifest's header names another issue number or no single entry is on
#     that branch. dispatch_phase.sh decides the working directory with it.
#   issue_checkout_guard <dir> <N> [<from-dir>]
#     The check records_path runs; callers use records_path or records_dir,
#     never this directly. Looks for the manifest enclosing <dir>'s
#     toplevel, then <dir>, then <from-dir> (default $PWD).
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
# user-tier: inert -- this file only defines functions and environment
# variables; it performs no repo-affecting action, so it needs no
# registry_require_root guard (#265 PR 3, ADR-0016).

# Nearest directory at or above <dir> that holds a .worktree-repos manifest.
# Prints it and returns 0; returns 1 when there is none up to /.
_wpd_enclosing_manifest() {
    local p
    p=$(cd "$1" 2>/dev/null && pwd -P) || return 1
    while :; do
        if [ -f "$p/.worktree-repos" ]; then
            echo "$p"
            return 0
        fi
        [ "$p" = "/" ] && return 1
        p=$(dirname "$p")
    done
}

issue_checkout_of() {
    local wt="${1:-}" issue="${2:-}" manifest header ref num
    if [ -z "$wt" ] || ! [[ "$issue" =~ ^[0-9]+$ ]]; then
        echo "ERROR: issue_checkout_of: <worktree-dir> and a numeric <N> are required" >&2
        return 1
    fi
    manifest="$wt/.worktree-repos"
    if [ ! -f "$manifest" ]; then
        echo "$wt"
        return 0
    fi
    header=$(head -n1 "$manifest")
    ref=$(sed -n 's/.* issue=\([^ ]*\).*/\1/p' <<< "$header")
    num="${ref##*#}"
    if [ -n "$num" ] && [ "$num" != "$issue" ]; then
        echo "ERROR: $wt is the package worktree for ${ref}, not for issue #${issue}." >&2
        return 1
    fi
    local -a rels=() branches=()
    local _origin rel branch
    while IFS=$'\t' read -r _origin rel branch; do
        [ -z "$rel" ] && continue
        rels+=("$rel")
        branches+=("$branch")
    done < <(tail -n +2 "$manifest")
    # A lone "." entry (a legacy single-repo manifest) is the worktree
    # itself. Any other single entry still has to be on feature/issue-<N>: a
    # package worktree made with only a sibling repository has no owning
    # checkout, and taking its one entry would commit into the sibling.
    local pick="" i n=0
    if [ "${#rels[@]}" -eq 1 ] && [ "${rels[0]}" = "." ]; then
        pick="."
    else
        for i in "${!rels[@]}"; do
            if [ "${branches[$i]}" = "feature/issue-${issue}" ]; then
                pick="${rels[$i]}"
                n=$((n + 1))
            fi
        done
        if [ "$n" -ne 1 ]; then
            {
                echo "ERROR: the package worktree $wt (${ref:-issue #$issue}) has $n entries on feature/issue-${issue}, so its issue checkout is undecided. Entries:"
                for i in "${!rels[@]}"; do
                    echo "  ${rels[$i]} (${branches[$i]})"
                done
            } >&2
            return 1
        fi
    fi
    if [ "$pick" = "." ]; then
        echo "$wt"
    else
        echo "$wt/$pick"
    fi
}

issue_checkout_guard() {
    local dir="${1:-.}" issue="${2:-}" other="${3:-$PWD}" top="" wt="" want ref
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || top=""
    if [ -n "$top" ]; then
        wt=$(_wpd_enclosing_manifest "$top") || wt=""
    fi
    if [ -z "$wt" ]; then
        wt=$(_wpd_enclosing_manifest "$dir") || wt=""
    fi
    if [ -z "$wt" ]; then
        wt=$(_wpd_enclosing_manifest "$other") || wt=""
    fi
    [ -z "$wt" ] && return 0
    ref=$(head -n1 "$wt/.worktree-repos" | sed -n 's/.* issue=\([^ ]*\).*/\1/p')
    want=$(issue_checkout_of "$wt" "$issue") || {
        echo "ERROR: refusing to read or write issue #${issue}'s records inside $wt (see above)." >&2
        return 1
    }
    want=$(cd "$want" 2>/dev/null && pwd -P) || {
        echo "ERROR: refusing to read or write issue #${issue}'s records: its checkout $want (from $wt/.worktree-repos) does not exist." >&2
        return 1
    }
    if [ -n "$top" ] && [ "$(cd "$top" && pwd -P)" = "$want" ]; then
        return 0
    fi
    {
        echo "ERROR: refusing to read or write issue #${issue}'s records in ${top:-$dir}."
        echo "  That is not the issue's checkout in the package worktree for ${ref:-issue #$issue}"
        echo "  ($wt). Its records go in $want. Run from that checkout:"
        echo "    cd $want"
    } >&2
    return 1
}

records_path() {
    local path="${1:-}" from="${2:-$PWD}" abs probe issue
    if [ -z "$path" ]; then
        echo "ERROR: records_path: a path is required" >&2
        return 1
    fi
    abs=$(realpath -m -- "$path" 2>/dev/null) || abs="$path"
    if [[ "$abs" =~ /\.agent/work-plans/issue-([0-9]+)(/|$) ]]; then
        issue="${BASH_REMATCH[1]}"
    else
        printf '%s\n' "$path"
        return 0
    fi
    probe="$abs"
    while [ ! -d "$probe" ] && [ "$probe" != "/" ]; do
        probe=$(dirname "$probe")
    done
    issue_checkout_guard "$probe" "$issue" "$from" || return 1
    printf '%s\n' "$path"
}

records_dir() {
    local issue="${1:-}" dir="${2:-.}" top
    if ! [[ "$issue" =~ ^[0-9]+$ ]]; then
        echo "ERROR: records_dir: a numeric issue number is required (got '${issue}')" >&2
        return 1
    fi
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || {
        echo "ERROR: records_dir: '$dir' is not inside a git repository" >&2
        return 1
    }
    records_path "$top/.agent/work-plans/issue-$issue" "$dir"
}

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
        records_path "$WORK_PLANS_DIR_OVERRIDE" "$PWD" >/dev/null || return 1
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
        records_path "${toplevel}/.agent/work-plans/issue-${issue}" "$PWD"
        return
    fi

    # Rule 2b: WORKTREE_ISSUE unset — derive the issue from the worktree
    # path or branch name (issue #224). Sessions entered via the native
    # EnterWorktree tool switch cwd without sourcing worktree_enter.sh, so
    # the env var is never exported even though the session is inside the
    # correct worktree. The worktree basename (issue-<slug>-<N>) and branch
    # (feature/issue-<N>[-<description>]) already encode the fact the env
    # var asserts, so trusting them keeps the #147 guard's purpose intact:
    # the main tree (basename != issue-*-<N>, branch = main) still refuses,
    # and a set-but-mismatched WORKTREE_ISSUE never reaches this fallback.
    if [ -z "${WORKTREE_ISSUE:-}" ] && [[ "$issue" =~ ^[0-9]+$ ]]; then
        local toplevel base branch
        toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || toplevel=""
        if [ -n "$toplevel" ]; then
            base=$(basename "$toplevel")
            branch=$(git -C "$toplevel" branch --show-current 2>/dev/null) || branch=""
            # Worktree directory naming: issue-<slug>-<N> (worktree_create.sh).
            # The trailing -<N> match is exact, so issue-x-2244 can't satisfy
            # a request for 224.
            case "$base" in
                issue-*-"$issue")
                    records_path "${toplevel}/.agent/work-plans/issue-${issue}" "$PWD"
                    return
                    ;;
            esac
            # Branch naming: feature/issue-<N> or feature/ISSUE-<N>-<desc>.
            # (-|$) anchors the number so feature/issue-2244 can't satisfy 224.
            if [[ "${branch,,}" =~ ^feature/issue-${issue}(-|$) ]]; then
                records_path "${toplevel}/.agent/work-plans/issue-${issue}" "$PWD"
                return
            fi
        fi
    fi

    # Rule 3: abort.
    {
        echo "ERROR: refusing to resolve work-plans dir for issue #${issue} outside its worktree."
        echo ""
        if [ -n "${WORKTREE_ISSUE:-}" ]; then
            echo "  Current \$WORKTREE_ISSUE is '${WORKTREE_ISSUE}', not '${issue}'."
        else
            echo "  \$WORKTREE_ISSUE is not set, and neither the current worktree path nor"
            echo "  the branch name encodes issue ${issue} — you're likely in the main tree"
            echo "  or a shell that didn't source worktree_enter.sh."
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
