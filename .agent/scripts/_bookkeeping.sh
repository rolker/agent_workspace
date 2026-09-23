#!/bin/bash
# Shared reviewed-tree equivalence for review sources and the merge gate.
# user-tier: inert -- sourcing only defines functions; direct execution is read-only.

# _only_bookkeeping_between <wt> <from-sha> <to-sha> <allowed-path>...
# The one equivalence rule shared by gate condition (a) (#286) and the
# Step 2 CI target (#284): <to> is "the same reviewed state" as <from> when
# <from> is an ancestor of <to> and every path that differs is one of the
# document files this workflow writes on the reviewed branch after review
# (progress.md records, work-plan addenda, roadmap updates). An allowed
# entry may be a glob. Returns 0 on equivalence; on
# failure returns 1 and prints the reason (one line, for the caller to
# quote). Both SHAs must be full and resolvable in <wt>; callers resolve
# short SHAs first (see the gate) so an ambiguous prefix is a failure
# there, not a silent match here.
_only_bookkeeping_between() {
    local wt="$1" from="$2" to="$3"; shift 3
    local -a allowed=("$@")
    local diff_paths p a ok
    if ! git -C "$wt" merge-base --is-ancestor "$from" "$to" 2>/dev/null; then
        echo "\`${from:0:7}\` is not an ancestor of \`${to:0:7}\` (force-push or a concurrent history change)"
        return 1
    fi
    diff_paths=$(git -C "$wt" diff --name-only "$from" "$to" 2>/dev/null) || {
        echo "could not diff \`${from:0:7}\`..\`${to:0:7}\` in $wt"
        return 1
    }
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        ok=false
        for a in ${allowed[@]+"${allowed[@]}"}; do
            # Unquoted RHS on purpose: an allowed entry may be a glob (the
            # gate passes the issue's whole work-plans dir). Callers that
            # pass literal paths are unaffected — those carry no glob
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

# Shared review policy. CI callers retain their own explicit path allowances.
_review_bookkeeping_between() {  # <wt> <review-sha> <head-sha> <issue>
    local wt="$1" from="$2" to="$3" issue="$4"
    [[ "$issue" =~ ^[0-9]+$ ]] || return 1
    from=$(git -C "$wt" rev-parse --verify --quiet "${from}^{commit}" 2>/dev/null) || return 1
    to=$(git -C "$wt" rev-parse --verify --quiet "${to}^{commit}" 2>/dev/null) || return 1
    _only_bookkeeping_between "$wt" "$from" "$to" \
        ".agent/work-plans/issue-${issue}/*" "ROADMAP.md" "docs/ROADMAP.md"
}

# Read-only bridge for the Python sources consumer; arguments are never evaluated.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    [[ "$#" == 5 && "$1" == --review ]] || exit 2
    shift
    _review_bookkeeping_between "$@"
fi
