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
#       current git toplevel is issue <N>'s checkout by
#       _wpd_checkout_is_issue (below: not the default branch; a branch
#       "feature/issue-<M>[-<description>]", case-insensitive, decides by
#       M = N; otherwise the folder "issue-*-<N>" decides), return the same
#       toplevel-anchored path. This covers EnterWorktree-based sessions
#       (issue #224) where the cwd is inside the correct worktree but
#       worktree_enter.sh was never sourced. A set-but-mismatched
#       $WORKTREE_ISSUE never takes this fallback.
#   3. Else abort with remediation guidance pointing at worktree_enter.sh.
#
# Every rule's answer passes records_path, so none returns a directory
# inside a package worktree that is not the issue's own checkout (issue 429).
#
# THE records gate (issue 429, ADR-0012 package worktrees). Every script
# that reads or writes an issue's records reaches the path through one of
# these two, and both end in the same check:
#   records_path [--write] <path> [<from-dir>]
#     <path> is a file or directory at or under
#     <repo>/.agent/work-plans/issue-<N>/ (relative to $PWD; it need not
#     exist yet). Prints <path> unchanged when the repository holding it
#     may hold issue <N>'s records, and refuses (stderr, naming the right
#     checkout, return 1) when it may not: inside a package worktree (a
#     .worktree-repos manifest encloses the path's repository, the path
#     itself, or <from-dir> when that shares the path's git toplevel), only
#     the manifest's issue checkout may (issue_checkout_of). A sibling
#     checkout with the same issue number and the worktree's top folder
#     (whose git toplevel is some other repository, the workspace's main
#     checkout, say) are refused for reads and writes alike. No manifest:
#     a no-op, so workspace issues and single-repo project worktrees are
#     unchanged, from wherever the command runs.
#     The shape `(^|/).agent/work-plans/issue-<N>(/|$)` is matched twice:
#     on <path> as given, and on its physical location (every symlink
#     resolved, by cd -P / pwd -P / readlink, no GNU-only option). Each
#     match is judged where it lies: the given one at the directory that
#     holds the named .agent (so a records folder that is a symlink is
#     judged where the link sits, not only where it points), the physical
#     one where it resolves. Two different issue numbers refuse, and so
#     does a path that cannot be resolved (a dangling symlink included).
#     Neither matching: no timeline, printed unchanged (a --no-progress
#     temp dir, a test fixture).
#     --write (issue 437): <path> is the file the caller will change (append
#     and commit, tick a box), never its folder. The write rule, in one
#     statement: the file's fully resolved physical path (every symlink in
#     the path and the file itself resolved) sits in issue <N>'s own
#     checkout by _wpd_checkout_is_issue, at the place <path> names, so the
#     checkout the caller's `git commit` runs in is the one the file is in.
#     "At the place it names" compares two paths computed the same way, not
#     text: <path> made absolute (from $PWD) and lexically normalised with
#     no symlink resolved (".", "..", repeated and trailing slashes gone),
#     and <path> fully resolved. Below the checkout root they must be equal,
#     and the named part above it must resolve to that root (a worktree
#     reached through a linked parent folder, or -C through a link, passes).
#     The issue number comes from either path, so a bare progress.md run
#     inside the records folder is judged too. A main checkout on its
#     default branch, another issue's worktree, a path in no git checkout,
#     or a symlink anywhere inside the checkout on the way to the file is
#     refused (stderr naming the issue's worktree, or the command that
#     creates it; return 1). Without --write nothing changes: reads are
#     never refused by this rule.
#   records_dir <N> [<dir>]
#     <dir>'s git toplevel (default .) + /.agent/work-plans/issue-<N>,
#     through records_path with <dir> as <from-dir>. A read: a writer
#     passes the file itself to records_path --write.
# Callers: resolve_work_plans_dir (every rule), progress_append.sh, every
# review_progress.sh subcommand that takes or builds a records path (round,
# persist, sources, findings, check, plan-sha), dispatch_phase.sh
# (resolve_issue_dir and `next --progress`) and merge_pr.sh's gate lookup.
# The ones that change a timeline pass the file to records_path --write:
# progress_append.sh, review_progress.sh persist (compatibility mode;
# strict mode writes through progress_append.sh) and review_progress.sh
# check.
# tests/test_records_write_gate.sh fails when a script commits a
# work-plans path without records_path --write.
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
#     toplevel, then <dir>, then <from-dir> (default $PWD), the last only
#     when <dir> is in no repository or <from-dir> has the same toplevel:
#     an unrelated repository's checkout says nothing about <dir>.
#   _wpd_checkout_is_issue <toplevel> <N>
#     Whether the checkout at <toplevel> is issue <N>'s: refused on its
#     default branch (origin/HEAD's, else main or master); on a branch
#     "feature/issue-<M>[-<description>]" (case-insensitive) the branch
#     decides (M = N; an issue-*-20 folder on feature/issue-21 is issue
#     21's); for a detached HEAD or any other branch name the folder
#     decides ("issue-*-<N>", exact trailing number). No package-manifest
#     shortcut: records_path's manifest check runs before it. Returns 0 or
#     1, prints nothing; on 1 sets _WPD_WHY to the reason. Shared by rule
#     2b and records_path --write, so the two cannot drift.
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
        local otop=""
        otop=$(git -C "$other" rev-parse --show-toplevel 2>/dev/null) || otop=""
        if [ -z "$top" ] || { [ -n "$otop" ] \
            && [ "$(cd "$otop" 2>/dev/null && pwd -P)" = "$(cd "$top" 2>/dev/null && pwd -P)" ]; }; then
            wt=$(_wpd_enclosing_manifest "$other") || wt=""
        fi
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

# Physical absolute form of <path>: every existing component resolved,
# symlinks included (a symlinked last component too), and a missing tail
# appended as written. Fails on a "." or ".." in the missing tail, on a
# symlink chain longer than 40, on a dangling symlink (one whose target does
# not exist), or when a directory cannot be entered.
# POSIX tools only (cd -P, pwd -P, readlink with no option), so it behaves
# the same where GNU realpath -m does not exist.
_wpd_physical() {
    local p="${1:-}" rest="" base d target hops=0
    [ -n "$p" ] || return 1
    case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
    while :; do
        while [ "${#p}" -gt 1 ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done
        if [ -L "$p" ]; then
            hops=$((hops + 1))
            [ "$hops" -le 40 ] || return 1
            target=$(readlink "$p") || return 1
            case "$target" in
                /*) p="$target" ;;
                *) p="$(dirname "$p")/$target" ;;
            esac
            # A dangling link (its target does not exist) cannot be resolved.
            [ -e "$p" ] || [ -L "$p" ] || return 1
            continue
        fi
        if [ -d "$p" ]; then
            d=$(cd -P "$p" 2>/dev/null && pwd -P) || return 1
            break
        fi
        base=$(basename "$p")
        case "$base" in .|..) return 1 ;; esac
        rest="/$base$rest"
        p=$(dirname "$p")
    done
    if [ "$d" = "/" ]; then
        printf '%s\n' "${rest:-/}"
    else
        printf '%s%s\n' "$d" "$rest"
    fi
}

# Lexical absolute form of <path>: relative to $PWD, with ".", "..",
# repeated and trailing slashes removed by text alone, no symlink resolved
# (the counterpart _wpd_physical is compared against).
_wpd_lexical() {
    local p="${1:-}" part out=""
    local -a parts=() stack=()
    case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
    IFS=/ read -r -a parts <<< "$p"
    for part in "${parts[@]}"; do
        case "$part" in
            ""|.) ;;
            ..) [ "${#stack[@]}" -gt 0 ] && unset 'stack[${#stack[@]}-1]' ;;
            *) stack+=("$part") ;;
        esac
    done
    for part in "${stack[@]}"; do out="$out/$part"; done
    printf '%s\n' "${out:-/}"
}

# Nearest existing directory at or above <path> (an absolute path).
_wpd_existing_dir() {
    local p="$1"
    while [ ! -d "$p" ] && [ "$p" != "/" ]; do
        p=$(dirname "$p")
    done
    printf '%s\n' "$p"
}

# The workspace's own scripts folder, for the refusal below to tell a
# workspace issue's worktree command from a project issue's.
_WPD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

_wpd_checkout_is_issue() {
    local top="${1:-}" issue="${2:-}" branch="" def=""
    _WPD_WHY=""
    if [ -z "$top" ] || ! [[ "$issue" =~ ^[0-9]+$ ]]; then
        _WPD_WHY="no checkout to judge"
        return 1
    fi
    branch=$(git -C "$top" branch --show-current 2>/dev/null) || branch=""
    if [ -n "$branch" ]; then
        def=$(git -C "$top" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) || def=""
        def="${def#origin/}"
        if { [ -n "$def" ] && [ "$branch" = "$def" ]; } \
            || { [ -z "$def" ] && { [ "$branch" = main ] || [ "$branch" = master ]; }; }; then
            _WPD_WHY="it is on its default branch '$branch'"
            return 1
        fi
        # (-|$) anchors the number so feature/issue-2244 is not issue 224's.
        if [[ "${branch,,}" =~ ^feature/issue-([0-9]+)(-|$) ]]; then
            [ "${BASH_REMATCH[1]}" = "$issue" ] && return 0
            _WPD_WHY="its branch '$branch' is issue #${BASH_REMATCH[1]}'s"
            return 1
        fi
    fi
    # Worktree directory naming: issue-<slug>-<N> (worktree_create.sh). The
    # trailing -<N> match is exact, so issue-x-2244 is not issue 224's.
    case "$(basename "$top")" in
        issue-*-"$issue") return 0 ;;
    esac
    if [ -n "$branch" ]; then
        _WPD_WHY="its branch '$branch' is not feature/issue-${issue} and its folder is not issue-*-${issue}"
    else
        _WPD_WHY="it is on a detached HEAD in a folder not named issue-*-${issue}"
    fi
    return 1
}

# The write rule of records_path --write, for the checkout holding <dir>.
_wpd_write_guard() {
    local dir="${1:-}" issue="${2:-}" top="" wt="" line cur="" common="" scommon="" type="project"
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || top=""
    if [ -z "$top" ]; then
        {
            echo "ERROR: refusing to write issue #${issue}'s records in $dir: it is in no git checkout."
            echo "  A write that changes a timeline happens only in the issue's own checkout"
            echo "  (branch feature/issue-${issue}); reads are not refused."
        } >&2
        return 1
    fi
    _wpd_checkout_is_issue "$top" "$issue" && return 0
    # The issue's worktree in the same repository, when there is one.
    while IFS= read -r line; do
        case "$line" in
            "worktree "*) cur="${line#worktree }" ;;
            "branch "*)
                if [[ "${line,,}" =~ ^branch\ refs/heads/feature/issue-${issue}(-|$) ]]; then
                    wt="$cur"
                    break
                fi
                ;;
        esac
    done < <(git -C "$top" worktree list --porcelain 2>/dev/null)
    {
        echo "ERROR: refusing to write issue #${issue}'s records in $top: $_WPD_WHY."
        echo "  A write that changes a timeline (an entry, a commit, a ticked box) happens only in"
        echo "  the issue's own checkout: branch feature/issue-${issue}, or for a detached HEAD or"
        echo "  another branch name a folder issue-*-${issue}. Reads are not refused."
        if [ -n "$wt" ]; then
            echo "  The issue's worktree is $wt. Run from it, or point -C at it:"
            echo "    cd $wt"
        else
            common=$(cd "$top" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P) || common=""
            if [ -n "$_WPD_SCRIPT_DIR" ]; then
                scommon=$(cd "$_WPD_SCRIPT_DIR" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P) || scommon=""
            fi
            [ -n "$common" ] && [ "$common" = "$scommon" ] && type="workspace"
            echo "  No worktree of this repository is on feature/issue-${issue}. Create it from the root:"
            echo "    .agent/scripts/worktree_create.sh --issue ${issue} --type ${type}"
            if [ "$type" = project ]; then
                echo "  (for an issue of a package repository in a multi-repository project:"
                echo "    --issue <owner>/<repo>#${issue})"
            fi
        fi
    } >&2
    return 1
}

records_path() {
    local write=0
    if [ "${1:-}" = "--write" ]; then
        write=1
        shift
    fi
    local path="${1:-}" from="${2:-$PWD}" gn="" gprefix="" rn="" phys gloc="" named="" top="" rel=""
    local re='^(.*/)?\.agent/work-plans/issue-([0-9]+)(/.*)?$'
    if [ -z "$path" ]; then
        echo "ERROR: records_path: a path is required" >&2
        return 1
    fi
    if [[ "$path" =~ $re ]]; then
        gn="${BASH_REMATCH[2]}"
        gprefix="${BASH_REMATCH[1]:-./}"
    fi
    phys=$(_wpd_physical "$path") || {
        echo "ERROR: refusing to use $path as an issue's records: it cannot be resolved to a physical location." >&2
        return 1
    }
    if [[ "$phys" =~ $re ]]; then
        rn="${BASH_REMATCH[2]}"
    fi
    if [ -z "$gn" ] && [ -z "$rn" ]; then
        printf '%s\n' "$path"
        return 0
    fi
    if [ -n "$gn" ] && [ -n "$rn" ] && [ "$gn" != "$rn" ]; then
        echo "ERROR: refusing to use $path: it names issue #${gn}'s records but resolves to issue #${rn}'s ($phys)." >&2
        return 1
    fi
    # Where the named records folder sits: the directory that holds its .agent.
    if [ -n "$gn" ]; then
        gloc=$(_wpd_physical "$gprefix") || {
            echo "ERROR: refusing to use $path as issue #${gn}'s records: ${gprefix} cannot be resolved." >&2
            return 1
        }
        issue_checkout_guard "$(_wpd_existing_dir "$gloc")" "$gn" "$from" || return 1
    fi
    # Where it resolves to.
    issue_checkout_guard "$(_wpd_existing_dir "$phys")" "${gn:-$rn}" "$from" || return 1
    # The write rule (issue 437), one statement: the physical file sits in
    # issue <N>'s own checkout, at the place the path names. "At the place
    # it names": inside that checkout, the path as named (made absolute and
    # lexically normalised, no symlink resolved) and the path fully resolved
    # are the same, and the named part above it resolves to the checkout.
    if [ "$write" = 1 ]; then
        _wpd_write_guard "$(_wpd_existing_dir "$phys")" "${gn:-$rn}" || return 1
        named=$(_wpd_lexical "$path")
        top=$(git -C "$(_wpd_existing_dir "$phys")" rev-parse --show-toplevel 2>/dev/null) || top=""
        [ -n "$top" ] && top=$(cd -P "$top" 2>/dev/null && pwd -P) || top=""
        rel="${phys#"$top"/}"
        if [ -z "$top" ] || [ "$rel" = "$phys" ] || [ "${named%/"$rel"}" = "$named" ] \
            || [ "$(_wpd_physical "${named%/"$rel"}")" != "$top" ]; then
            {
                echo "ERROR: refusing to write issue #${gn:-$rn}'s records through $path: it resolves to"
                echo "  $phys, not to the place it names ($named)."
                echo "  A write that changes a timeline goes to the file at the place its path names, in"
                echo "  the issue's own checkout: a symlink on the way would put the write in one place"
                echo "  and the commit in another. Reads are not refused."
            } >&2
            return 1
        fi
    fi
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
    # the main tree (default branch) still refuses, and a set-but-mismatched
    # WORKTREE_ISSUE never reaches this fallback. The branch-and-folder test
    # is _wpd_checkout_is_issue, the same one records_path --write applies
    # (issue 437), so the resolver and the commit gate cannot disagree.
    if [ -z "${WORKTREE_ISSUE:-}" ] && [[ "$issue" =~ ^[0-9]+$ ]]; then
        local toplevel
        toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || toplevel=""
        if [ -n "$toplevel" ] && _wpd_checkout_is_issue "$toplevel" "$issue"; then
            records_path "${toplevel}/.agent/work-plans/issue-${issue}" "$PWD"
            return
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
