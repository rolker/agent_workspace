#!/bin/bash
# .agent/scripts/_bookkeeping.sh
# The one "same reviewed state" rule, shared by merge_pr.sh (gate condition
# (a) #286, the Step 2 CI target #284, the CI walk-back #300) and
# review_progress.sh sources (#309).
#
# Source it from bash:
#   source "$SCRIPT_DIR/_bookkeeping.sh"
# or run it as a read-only bridge from a non-bash caller (review_progress.sh
# sources' Python):
#   bash _bookkeeping.sh --review <wt> <review-sha> <head-sha> <issue>
#   exit 0 covered, 1 stale, 3 unverifiable, 2 usage; the reason (one line)
#   is printed on stdout for 1 and 3.
#
# Nothing here writes to a repository or fetches: every git call is a read
# (rev-parse, merge-base --is-ancestor, diff --name-only).

# The roadmap files the workflow updates on a reviewed branch
# (update_roadmap.sh, merge_pr.sh Step 1). docs/roadmap.md is the #334
# spelling (docs reorganisation); the uppercase paths stay for checkouts
# and branches that predate it.
BOOKKEEPING_ROADMAP_PATHS=("ROADMAP.md" "docs/ROADMAP.md" "docs/roadmap.md")

# _only_bookkeeping_between <wt> <from-sha> <to-sha> <allowed-path>...
# <to> is "the same reviewed state" as <from> when <from> is an ancestor of
# <to> and every path that differs is one of the document files this
# workflow writes on the reviewed branch after review (progress.md records,
# work-plan addenda, roadmap updates). The comparison is the endpoint tree
# diff, so a later bookkeeping commit can never hide an earlier code commit,
# and renames are not detected, so a move into an allowed path still counts
# its source path. An allowed entry may be a glob. Returns 0 on equivalence; on failure
# returns 1 and prints the reason (one line, for the caller to quote). Both
# SHAs must be full and resolvable in <wt>; callers resolve short SHAs first
# so an ambiguous prefix is a failure there, not a silent match here.
_only_bookkeeping_between() {
    local wt="$1" from="$2" to="$3"; shift 3
    local -a allowed=("$@")
    local diff_paths p a ok
    if ! git -C "$wt" merge-base --is-ancestor "$from" "$to" 2>/dev/null; then
        echo "\`${from:0:7}\` is not an ancestor of \`${to:0:7}\` (force-push or a concurrent history change)"
        return 1
    fi
    # --no-renames: a rename is reported as its deletion AND its addition, so
    # a code file moved into an exempt directory still names its old path.
    # (With rename detection only the destination would be listed.)
    diff_paths=$(git -C "$wt" diff --no-renames --name-only "$from" "$to" 2>/dev/null) || {
        echo "could not diff \`${from:0:7}\`..\`${to:0:7}\` in $wt"
        return 1
    }
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        ok=false
        for a in ${allowed[@]+"${allowed[@]}"}; do
            # Unquoted RHS on purpose: an allowed entry may be a glob (the
            # review policy passes the issue's whole work-plans dir). Callers
            # that pass literal paths are unaffected — those carry no glob
            # metacharacters.
            # shellcheck disable=SC2053
            [[ "$p" == $a ]] && { ok=true; break; }
        done
        if [[ "$ok" == false ]]; then
            echo "touches \`${p}\`, which is not a merge-time document file"
            return 1
        fi
    done <<<"$diff_paths"
    return 0
}

# _review_bookkeeping_between <wt> <review-sha> <head-sha> <issue>
# The review policy: is a review recorded at <review-sha> still a review of
# <head-sha>? Yes when only THIS issue's work-plan directory and the roadmap
# files changed in between. Another issue's work-plan directory is not
# exempt (a stray commit of it is a real change to this branch). The SHAs
# may be short; each must resolve to exactly one commit in <wt>.
# Returns 0 covered; 1 stale (a verified code/other-path change or a
# non-ancestor); 3 unverifiable (bad issue, <wt> not a repository, a SHA
# that does not resolve there). Prints the reason for 1 and 3.
_review_bookkeeping_between() {
    local wt="$1" from="$2" to="$3" issue="$4" from_full to_full
    if [[ ! "$issue" =~ ^[0-9]+$ ]]; then
        echo "no issue number to scope the work-plan exemption (got '${issue}')"
        return 3
    fi
    if ! git -C "$wt" rev-parse --git-dir >/dev/null 2>&1; then
        echo "$wt is not a git repository"
        return 3
    fi
    # Hex only: a ref name ("HEAD", a branch) or an option-like argument
    # must never be resolved as if it were a recorded commit.
    from_full=""
    if [[ "$from" =~ ^[0-9a-fA-F]{4,64}$ ]]; then
        from_full=$(git -C "$wt" rev-parse --verify --quiet "${from}^{commit}" 2>/dev/null) || from_full=""
    fi
    if [[ -z "$from_full" ]]; then
        echo "review \`${from:-?}\` does not resolve to one commit in $wt"
        return 3
    fi
    to_full=""
    if [[ "$to" =~ ^[0-9a-fA-F]{4,64}$ ]]; then
        to_full=$(git -C "$wt" rev-parse --verify --quiet "${to}^{commit}" 2>/dev/null) || to_full=""
    fi
    if [[ -z "$to_full" ]]; then
        echo "head \`${to:-?}\` does not resolve to one commit in $wt"
        return 3
    fi
    _only_bookkeeping_between "$wt" "$from_full" "$to_full" \
        ".agent/work-plans/issue-${issue}/*" "${BOOKKEEPING_ROADMAP_PATHS[@]}"
}

# Bridge for non-bash callers. Arguments are passed as data, never evaluated.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "$#" -ne 5 || "$1" != "--review" ]]; then
        echo "usage: _bookkeeping.sh --review <wt> <review-sha> <head-sha> <issue>" >&2
        exit 2
    fi
    shift
    _review_bookkeeping_between "$@"
    exit $?
fi
