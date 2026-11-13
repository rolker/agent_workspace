#!/bin/bash
# .agent/scripts/_worktree_helpers.sh
# Shared helper functions for worktree scripts
#
# Source this file from other worktree scripts:
#   source "$SCRIPT_DIR/_worktree_helpers.sh"

# Registry helpers (registry_worktree_dir, registry_entries_full,
# REGISTRY_PARENT_TYPE, ...) are used throughout this file, so pull them
# in here rather than requiring every caller to source both files in the
# right order.
_WT_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_project_registry.sh
source "$_WT_HELPERS_DIR/_project_registry.sh"
unset _WT_HELPERS_DIR

# --- Worktree base directory helpers ---
# Worktrees live under whichever root owns them (issue #265):
#   worktrees/workspace/                — workspace worktrees (unchanged)
#   <registered_root>/worktrees/        — project worktrees, one dir per
#                                        registered root (registry_worktree_dir;
#                                        honors a worktrees= override)
#   worktrees/project/<name>/           — TRANSITION FALLBACK (PR 2 -> PR 4):
#                                        a project with no registry entry
#                                        (legacy project/ symlink) still
#                                        lands here, exactly as before #265.
# Legacy layout (deprecated):
#   .workspace-worktrees/         — old workspace worktrees
#   project/worktrees/            — old project worktrees

# Resolve the workspace worktree base directory.
# Usage: dir=$(wt_workspace_base "$root_dir")
wt_workspace_base() {
    echo "$1/worktrees/workspace"
}

# Resolve the project worktree base directory for a given registered
# project (or, unregistered, the legacy fallback). Delegates entirely to
# registry_worktree_dir (#265): a registered name resolves under its own
# root (or its worktrees= override); an unregistered name falls back to
# the pre-#265 <root>/worktrees/project/<name> location so legacy
# projects keep working mid-rollout.
# Usage: dir=$(wt_project_base "$root_dir" "$repo_name")
wt_project_base() {
    local root_dir="$1"
    local repo_name="$2"

    if [[ -z "$repo_name" ]]; then
        echo "Error: repo name must not be empty." >&2
        return 1
    fi
    registry_worktree_dir "$root_dir" "$repo_name"
}

# Resolve the LEGACY project worktree base glob (all repos with no
# registry entry, or predating #265). Registered projects are NOT under
# here (they're under their own root) — use wt_registry_worktree_dirs for
# those. Usage: for dir in $(wt_project_base_glob "$root_dir"); do ...
wt_project_base_glob() {
    echo "$1/worktrees/project"
}

# Enumerate every registered non-parent project's worktree directory that
# currently exists on disk, as "<name>\t<worktree_dir>" (one per line).
# Parent roots are skipped (#265): they have no worktrees of their own —
# their instances do. Registry parse errors are reported on stderr; the
# return code follows registry_entries_full (0 clean, 2 on parse errors —
# valid entries still print).
# Usage: while IFS=$'\t' read -r name dir; do ...; done < <(wt_registry_worktree_dirs "$root")
wt_registry_worktree_dirs() {
    local root_dir="$1" entries name type path fields wtdir rc=0
    entries="$(registry_entries_full "$root_dir")" || rc=$?
    [ -n "$entries" ] || return $rc
    # shellcheck disable=SC2034  # fields is unused here; the loop only needs name/type
    while IFS=$'\t' read -r name type path fields; do
        [ -z "$name" ] && continue
        [ "$type" = "$REGISTRY_PARENT_TYPE" ] && continue
        wtdir="$(registry_worktree_dir "$root_dir" "$name")" || continue
        [ -d "$wtdir" ] || continue
        printf '%s\t%s\n' "$name" "$wtdir"
    done <<< "$entries"
    return $rc
}

# Enumerate legacy project worktree dirs still under
# <root>/worktrees/project/*, one "<name>\t<dir>" per line — for
# unregistered projects AND for registered ones whose worktrees were
# created before registration (the transition case, #265 PR 2 review):
# registering a project must never make its existing worktrees invisible
# to list/enter/remove/merge. A dir is skipped only when it IS the
# registered worktree dir (a worktrees= override pointing here), so a
# project is never listed twice for the same directory.
# Usage: while IFS=$'\t' read -r name dir; do ...; done < <(wt_legacy_worktree_dirs "$root")
wt_legacy_worktree_dirs() {
    local root_dir="$1" base name d regdir lrc
    base="$(wt_project_base_glob "$root_dir")"
    [ -d "$base" ] || return 0
    # Fail closed on a malformed registry: rc 2 from the parser means "cannot
    # tell what is registered", so nothing here may be listed as legacy.
    registry_entries "$root_dir" >/dev/null 2>&1; lrc=$?
    if [ "$lrc" -eq 2 ]; then
        echo "ERROR: project registry is malformed; refusing to enumerate legacy worktrees (fix .agent/projects.local)" >&2
        return 2
    fi
    for d in "$base"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "${d%/}")"
        if registry_lookup "$root_dir" "$name" >/dev/null 2>&1; then
            regdir="$(registry_worktree_dir "$root_dir" "$name" 2>/dev/null || true)"
            [ -n "$regdir" ] && [ "$(realpath -m "$regdir")" = "$(realpath -m "${d%/}")" ] && continue
        fi
        printf '%s\t%s\n' "$name" "${d%/}"
    done
}

# The transition location for a registered project: <ws>/worktrees/project/
# <name>/, where its worktrees lived before registration. Prints it when it
# exists and differs from the project's current worktree dir; prints
# nothing otherwise. enter/remove search it after the current dir.
# Usage: t=$(wt_transition_project_base "$root_dir" "$name")
wt_transition_project_base() {
    local root_dir="$1" name="$2" cur t rc=0
    t="$(wt_project_base_glob "$root_dir")/$name"
    [ -d "$t" ] || return 0
    cur="$(registry_worktree_dir "$root_dir" "$name" 2>/dev/null)" || rc=$?
    if [ "$rc" -eq 2 ]; then
        echo "ERROR: project registry is malformed; cannot resolve the transition worktree dir for '$name'" >&2
        return 2
    fi
    [ -n "$cur" ] && [ "$(realpath -m "$cur")" = "$(realpath -m "$t")" ] && return 0
    echo "$t"
}

# Count every existing project worktree (issue/skill subdirectory), across
# every registered non-parent root's worktree dir AND the legacy fallback
# location. Does not include the ancient pre-#25 project/worktrees/ shape
# (callers add that separately if they still care about it).
# Usage: n=$(wt_count_project_worktrees "$root_dir")
wt_count_project_worktrees() {
    local root_dir="$1" total=0 name dir
    while IFS=$'\t' read -r name dir; do
        [ -z "$dir" ] && continue
        total=$((total + $(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)))
    done < <(wt_registry_worktree_dirs "$root_dir" 2>/dev/null; wt_legacy_worktree_dirs "$root_dir" 2>/dev/null)
    echo "$total"
}

# Resolve the project checkout root for --type project scripts that need
# the repo itself (not just its worktree dir) — e.g. merge_pr.sh's PR/
# branch resolution. Precedence matches worktree_create.sh (#265):
#   1. an explicit registered name (a parent root resolves to its
#      default/only instance)
#   2. the legacy project/ symlink, if it is a git checkout
#   3. the single registered non-parent project, if there is exactly one
# Prints the absolute path on success. Returns 1 (message on stderr) when
# nothing resolves or the registry has more than one candidate and no
# name was given; 2 on registry parse errors.
# Usage: dir=$(wt_resolve_project_repo_root "$root_dir" ["$name"])
wt_resolve_project_repo_root() {
    local root_dir="$1" name="${2:-}" entry rc=0
    if [ -n "$name" ]; then
        name="$(registry_resolve_project_arg "$root_dir" "$name")" || return $?
        entry="$(registry_lookup "$root_dir" "$name")" || return $?
        cut -f2 <<< "$entry"
        return 0
    fi
    if [ -d "$root_dir/project" ] && git -C "$root_dir/project" rev-parse --git-dir &>/dev/null; then
        echo "$root_dir/project"
        return 0
    fi
    local entries count
    entries="$(registry_entries "$root_dir")" || return $?
    [ -n "$entries" ] && entries="$(awk -F'\t' -v p="$REGISTRY_PARENT_TYPE" '$2 != p' <<< "$entries")"
    count=0
    [ -n "$entries" ] && count="$(wc -l <<< "$entries")"
    if [ "$count" -eq 1 ]; then
        cut -f3 <<< "$entries"
        return 0
    elif [ "$count" -gt 1 ]; then
        echo "ERROR: multiple projects registered; pass --project <name> to disambiguate" >&2
        return 1
    fi
    echo "ERROR: no project configured (no legacy project/ checkout, nothing registered)" >&2
    return 1
}

# Ensure a registered project's worktree directory is excluded from that
# root's own git status. Type-specific markers (a ros2_colcon root's
# COLCON_IGNORE) are the adapter's job — its worktree_env verb writes them
# — never a type check here (ADR-0012). Idempotent; never touches a
# tracked file. A no-op for:
#   - an unregistered project (the transition fallback already lives
#     under the WORKSPACE's own worktrees/, which is already gitignored)
#   - a worktree dir that lies outside the project's own root (a
#     worktrees= override pointed at the workspace root instead — the
#     registry parser already requires one or the other)
# Writes:
#   - <epath>/.git/info/exclude gains the worktree dir's path relative to
#     <epath> (with a trailing '/'), if <epath> is a git repo and the
#     line is not already present.
# Usage: wt_ensure_exclusion "$root_dir" "$project_name"
wt_ensure_exclusion() {
    local root_dir="$1" name="$2" entry etype epath wtdir rel exclude_file
    entry="$(registry_lookup "$root_dir" "$name")" || return 0
    etype="$(cut -f1 <<< "$entry")"
    epath="$(cut -f2 <<< "$entry")"
    [ "$etype" = "$REGISTRY_PARENT_TYPE" ] && return 0
    wtdir="$(registry_worktree_dir "$root_dir" "$name")" || return 0
    if [ "$wtdir" = "$epath" ] || [[ "$wtdir" == "$epath/"* ]]; then
        rel="${wtdir#"$epath"/}"
        if git -C "$epath" rev-parse --git-dir >/dev/null 2>&1; then
            exclude_file="$(git -C "$epath" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null || true)"
            if [ -n "$exclude_file" ]; then
                mkdir -p "$(dirname "$exclude_file")"
                touch "$exclude_file"
                if ! grep -qxF "$rel/" "$exclude_file" 2>/dev/null; then
                    echo "$rel/" >> "$exclude_file"
                fi
            fi
        fi
    fi
}

# Legacy base directories (for migration/deprecation warnings)
wt_legacy_workspace_base() {
    echo "$1/.workspace-worktrees"
}

wt_legacy_project_base() {
    echo "$1/project/worktrees"
}

# Find an issue worktree in a given base directory.
# Returns the path if found, returns 1 if not found.
# On multiple matches, prints disambiguation help to stderr and returns 1.
# Usage: path=$(find_worktree "$base_dir" "$issue_num" "$repo_slug")
find_worktree() {
    local base_dir="$1"
    local issue_num="$2"
    local repo_slug="$3"

    if [ -n "$repo_slug" ]; then
        local exact_path="$base_dir/issue-${repo_slug}-${issue_num}"
        if [ -d "$exact_path" ]; then
            echo "$exact_path"
            return 0
        fi
        return 1
    fi

    local matches=()
    for path in "$base_dir"/issue-*-"${issue_num}"; do
        if [ -d "$path" ] && [ "$path" != "$base_dir/issue-*-${issue_num}" ]; then
            matches+=( "$path" )
        fi
    done

    # Legacy format: issue-{NUMBER}
    local legacy_path="$base_dir/issue-${issue_num}"
    if [ -d "$legacy_path" ]; then
        matches+=( "$legacy_path" )
    fi

    if [ "${#matches[@]}" -eq 1 ]; then
        echo "${matches[0]}"
        return 0
    elif [ "${#matches[@]}" -gt 1 ]; then
        echo "Error: Multiple worktrees found for issue ${issue_num}:" >&2
        for path in "${matches[@]}"; do
            echo "  - $(basename "$path")" >&2
        done
        echo "" >&2
        echo "Use --repo-slug to specify which one:" >&2
        for path in "${matches[@]}"; do
            local slug
            slug=$(basename "$path" | sed -E 's/^issue-(.+)-[0-9]+$/\1/')
            echo "  --issue ${issue_num} --repo-slug ${slug}" >&2
        done
        return 1
    fi

    return 1
}

# Read the issue= field from a worktree's .worktree-repos header, if any.
# Empty stdout (not an error) when no manifest file exists.
# Usage: ref=$(_wt_manifest_issue_field "$worktree_dir")
_wt_manifest_issue_field() {
    local dir="$1" manifest header
    manifest="$dir/.worktree-repos"
    [ -f "$manifest" ] || { echo ""; return 0; }
    header="$(head -n1 "$manifest")"
    sed -n 's/.* issue=\([^ ]*\).*/\1/p' <<< "$header"
}

# Find a --type project worktree by issue reference — a bare number, or a
# qualified owner/repo#N (ADR-0012 package worktree). Returns the path on
# stdout, same disambiguation-failure contract as find_worktree (nonzero,
# guidance on stderr).
#
# - Qualified ref: only a directory whose .worktree-repos header's `issue=`
#   field is *exactly* that ref is a match — the directory name (and its
#   trailing number) is never trusted alone for this shape. No manifest, or
#   a mismatched one, is not a match; this never falls back to "any
#   directory with that trailing number" for a qualified ref, because that
#   would defeat the whole point of qualifying it.
# - Bare number: identical to find_worktree, except that when more than one
#   directory matches AND at least one of them carries a manifest (i.e. the
#   ambiguity is between package worktrees for different repos, which
#   --repo-slug cannot resolve — --repo-slug disambiguates *registered
#   projects*, not sibling package repos within the same project), the
#   error instead lists the qualified `--issue owner/repo#N` refs to use.
#
# Usage: path=$(find_worktree_by_issue "$base_dir" "$issue_ref" "$repo_slug")
find_worktree_by_issue() {
    local base_dir="$1" issue_ref="$2" repo_slug="$3"
    local issue_num
    if [[ "$issue_ref" == *#* ]]; then
        issue_num="${issue_ref##*#}"
    else
        issue_num="$issue_ref"
    fi

    if [ -n "$repo_slug" ]; then
        local exact_path="$base_dir/issue-${repo_slug}-${issue_num}"
        if [ -d "$exact_path" ]; then
            if [[ "$issue_ref" == *#* ]] && [ "$(_wt_manifest_issue_field "$exact_path")" != "$issue_ref" ]; then
                return 1
            fi
            echo "$exact_path"
            return 0
        fi
        return 1
    fi

    local matches=()
    for path in "$base_dir"/issue-*-"${issue_num}"; do
        if [ -d "$path" ] && [ "$path" != "$base_dir/issue-*-${issue_num}" ]; then
            matches+=( "$path" )
        fi
    done
    local legacy_path="$base_dir/issue-${issue_num}"
    [ -d "$legacy_path" ] && matches+=( "$legacy_path" )

    if [[ "$issue_ref" == *#* ]]; then
        # Qualified: manifest-exact matches only.
        local filtered=() path hdr
        for path in "${matches[@]}"; do
            hdr="$(_wt_manifest_issue_field "$path")"
            [ -n "$hdr" ] && [ "$hdr" = "$issue_ref" ] && filtered+=( "$path" )
        done
        if [ "${#filtered[@]}" -eq 1 ]; then
            echo "${filtered[0]}"
            return 0
        elif [ "${#filtered[@]}" -gt 1 ]; then
            echo "Error: multiple worktrees found matching issue '${issue_ref}':" >&2
            for path in "${filtered[@]}"; do
                echo "  - $(basename "$path")" >&2
            done
            return 1
        fi
        return 1
    fi

    # Bare number.
    if [ "${#matches[@]}" -eq 1 ]; then
        echo "${matches[0]}"
        return 0
    elif [ "${#matches[@]}" -gt 1 ]; then
        local -a manifest_refs=()
        local path hdr
        for path in "${matches[@]}"; do
            hdr="$(_wt_manifest_issue_field "$path")"
            [ -n "$hdr" ] && manifest_refs+=( "$hdr" )
        done
        echo "Error: Multiple worktrees found for issue ${issue_num}:" >&2
        for path in "${matches[@]}"; do
            echo "  - $(basename "$path")" >&2
        done
        echo "" >&2
        if [ "${#manifest_refs[@]}" -gt 0 ]; then
            echo "These include package worktrees for different repos — --repo-slug cannot" >&2
            echo "disambiguate them. Use the qualified --issue form instead:" >&2
            for hdr in "${manifest_refs[@]}"; do
                echo "  --issue ${hdr}" >&2
            done
        else
            echo "Use --repo-slug to specify which one:" >&2
            for path in "${matches[@]}"; do
                local slug
                slug=$(basename "$path" | sed -E 's/^issue-(.+)-[0-9]+$/\1/')
                echo "  --issue ${issue_num} --repo-slug ${slug}" >&2
            done
        fi
        return 1
    fi

    return 1
}

# --- Per-worktree repo manifest (.worktree-repos, ADR-0012) ---
#
# A package worktree (multiple git worktrees composed under one aggregate
# directory) records a manifest at <worktree_dir>/.worktree-repos:
#   # project=<name> issue=<owner/repo#N|N> layer=<l>[ base=<branch>]
#   <origin_repo_abs_path>\t<rel_path_in_worktree>\t<branch>
#   ...
# Every worktree script reads this file (never the adapter, never the
# directory name) to learn which repos compose the worktree. A worktree
# without this file is a legacy single-repo worktree: wt_read_manifest
# falls back to one synthetic entry (the worktree root itself).
# base= (issue 429) is the branch the owning repository's pull request
# targets and its feature/issue-<N> branch started from (the project's pin,
# adapter repo_pin, or worktree_create.sh --base). It describes the owning
# entry only; a header without it is a worktree made before the field
# existed (dispatch_phase.sh base writes it on resume, wt_set_manifest_base).
# Header fields are read unanchored, so a reader ignores fields it does not
# know.

# Write the manifest. Entry lines (worktree_repos output) are read from
# stdin. <base> is optional; without it the header has no base= field.
# Usage:
#   printf '%s\n' "$repo_lines" | wt_write_manifest "$dir" "$project" "$issue" "$layer" ["$base"]
wt_write_manifest() {
    local worktree_dir="$1" project="$2" issue="$3" layer="$4" base="${5:-}"
    {
        printf '# project=%s issue=%s layer=%s%s\n' "$project" "$issue" "$layer" "${base:+ base=$base}"
        cat
    } > "$worktree_dir/.worktree-repos"
}

# Record <base> as the base= field of an existing manifest's header, for a
# worktree made before the field existed (issue 429). The entry lines are
# kept byte for byte; the file is replaced in one rename, so a reader never
# sees half a header. A header that already records the same base is left
# as it is; one that records another base is refused, since the base a
# branch started from is not changed after the fact. The caller checks the
# branch on origin first (dispatch_phase.sh base).
# Status: 0 recorded (or already so); 1 refused or failed, a message on
# stderr, the manifest unchanged.
# Usage: wt_set_manifest_base <worktree_dir> <base>
wt_set_manifest_base() {
    local worktree_dir="$1" base="$2" manifest header have tmp
    manifest="$worktree_dir/.worktree-repos"
    if [ ! -f "$manifest" ]; then
        echo "ERROR: $worktree_dir has no .worktree-repos manifest to record a base in" >&2
        return 1
    fi
    if [ -z "$base" ] || [[ "$base" == *[[:space:]]* ]]; then
        echo "ERROR: wt_set_manifest_base: '$base' is not a branch name a manifest header can hold" >&2
        return 1
    fi
    header="$(head -n1 "$manifest")"
    if [[ "$header" != "# project="* ]]; then
        echo "ERROR: the first line of $manifest is not a manifest header: $header" >&2
        return 1
    fi
    have="$(sed -n 's/.* base=\([^ ]*\).*/\1/p' <<< "$header")"
    if [ -n "$have" ]; then
        [ "$have" = "$base" ] && return 0
        echo "ERROR: $manifest already records base=$have; not changed to $base" >&2
        return 1
    fi
    tmp="$(mktemp "$manifest.XXXXXX")" || {
        echo "ERROR: could not create a temporary file beside $manifest" >&2
        return 1
    }
    if { printf '%s base=%s\n' "$header" "$base"; tail -n +2 "$manifest"; } > "$tmp" \
        && mv -f "$tmp" "$manifest"; then
        return 0
    fi
    rm -f "$tmp"
    echo "ERROR: could not rewrite $manifest" >&2
    return 1
}

# Whether <branch> in <checkout> started from origin's <base> (issue 429),
# asked before a base is recorded for a branch this run did not start
# there: a worktree made before base= existed (dispatch_phase.sh base) or
# an owning branch that already existed at creation (worktree_create.sh).
# A commit in origin/<base>..<branch> that another branch on origin also
# has is foreign: the branch carries history the base does not, so a pull
# request against <base> would carry it too. Commits only <branch> has
# (its own work, pushed to origin's <branch> or not) are not foreign; the
# issue branch on origin and <base> itself are left out of "another".
#
# One bounded fetch (wt_bounded_git) of every origin branch, into a private
# ref namespace removed again before returning: the checkout's own
# remote-tracking refs are neither read (they can be stale) nor changed.
#
# Sets WT_FOREIGN_COUNT (foreign commits), WT_FOREIGN_FROM (the origin
# branches they are on, most first and, among equals, the one with the
# fewest commits <branch> lacks first: "main (3), dev (1)"; at most three
# named, then "and N more") and WT_FOREIGN_REASON (one line, for 2 and 3).
# Returns 0 none foreign; 1 foreign; 2 origin has no branch <base>; 3 not
# decided (origin did not answer, or <checkout> has no branch <branch>).
# Usage: wt_base_foreign_history <checkout> <branch> <base>
# shellcheck disable=SC2034  # the WT_FOREIGN_* results are read by callers
wt_base_foreign_history() {
    local checkout="$1" branch="$2" base="$3"
    local ns="refs/wt-base-check/$$-${RANDOM}" err rc=0 tip
    WT_FOREIGN_COUNT=0
    WT_FOREIGN_FROM=""
    WT_FOREIGN_REASON=""
    tip="$(git -C "$checkout" rev-parse --verify --quiet "refs/heads/$branch^{commit}" 2>/dev/null)" || tip=""
    if [ -z "$tip" ]; then
        WT_FOREIGN_REASON="$checkout has no branch '$branch'"
        return 3
    fi
    err="$(wt_bounded_git -C "$checkout" fetch --quiet --no-tags --no-write-fetch-head origin "+refs/heads/*:$ns/*" 2>&1)" || rc=$?
    if [ "$rc" -ne 0 ]; then
        WT_FOREIGN_REASON="$(wt_fetch_why "$rc" "${err:-git fetch exited $rc}")"
        git -C "$checkout" for-each-ref --format='delete %(refname)' "$ns/" 2>/dev/null \
            | git -C "$checkout" update-ref --stdin 2>/dev/null || true
        return 3
    fi
    local status=0 ref name mbs n extra all_mbs="" total
    local -a found=()
    if ! git -C "$checkout" rev-parse --verify --quiet "$ns/$base^{commit}" >/dev/null 2>&1; then
        WT_FOREIGN_REASON="origin has no branch '$base'"
        status=2
    else
        while IFS= read -r ref; do
            [ -n "$ref" ] || continue
            name="${ref#"$ns/"}"
            [ "$name" = "$base" ] && continue
            [ "$name" = "$branch" ] && continue
            mbs="$(git -C "$checkout" merge-base --all "$tip" "$ref" 2>/dev/null | tr '\n' ' ')" || mbs=""
            [ -n "$mbs" ] || continue
            # shellcheck disable=SC2086  # merge bases are hex ids
            n="$(git -C "$checkout" rev-list --count $mbs "^$ns/$base" 2>/dev/null)" || n=0
            if [ "${n:-0}" -gt 0 ]; then
                # Ties are named closest first: the branch with the fewest
                # commits <branch> does not have (main, not a branch made
                # from main since).
                extra="$(git -C "$checkout" rev-list --count "$ref" "^$tip" 2>/dev/null)" || extra=0
                found+=("$n $extra $name")
                all_mbs="$all_mbs $mbs"
            fi
        done < <(git -C "$checkout" for-each-ref --format='%(refname)' "$ns/")
        if [ "${#found[@]}" -gt 0 ]; then
            # shellcheck disable=SC2086
            total="$(git -C "$checkout" rev-list --count $all_mbs "^$ns/$base" 2>/dev/null)" || total=""
            WT_FOREIGN_COUNT="${total:-?}"
            local line i=0 more=0
            while IFS= read -r line; do
                [ -n "$line" ] || continue
                i=$((i + 1))
                if [ "$i" -le 3 ]; then
                    WT_FOREIGN_FROM="${WT_FOREIGN_FROM:+$WT_FOREIGN_FROM, }${line#* * } (${line%% *})"
                else
                    more=$((more + 1))
                fi
            done < <(printf '%s\n' "${found[@]}" | sort -k1,1nr -k2,2n -k3,3)
            [ "$more" -gt 0 ] && WT_FOREIGN_FROM="$WT_FOREIGN_FROM and $more more"
            status=1
        fi
    fi
    git -C "$checkout" for-each-ref --format='delete %(refname)' "$ns/" 2>/dev/null \
        | git -C "$checkout" update-ref --stdin 2>/dev/null || true
    return "$status"
}

# Read the manifest for a worktree dir. Prints entry lines (without the
# header) to stdout, and sets WT_MANIFEST_PROJECT / WT_MANIFEST_ISSUE /
# WT_MANIFEST_LAYER / WT_MANIFEST_BASE from the header. Legacy fallback (no
# manifest file): one entry — the worktree root itself, "." , current
# branch — and all four header variables empty. Every field is read
# unanchored, so a field added after it (base=, after layer=) leaves the
# others readable.
# Usage: entries=$(wt_read_manifest "$worktree_dir")
wt_read_manifest() {
    local worktree_dir="$1" manifest header
    manifest="$worktree_dir/.worktree-repos"
    WT_MANIFEST_PROJECT=""
    WT_MANIFEST_ISSUE=""
    WT_MANIFEST_LAYER=""
    WT_MANIFEST_BASE=""
    if [ -f "$manifest" ]; then
        header="$(head -n1 "$manifest")"
        # Read by callers (worktree_list.sh, dashboard.sh, etc.), not this file.
        # shellcheck disable=SC2034
        WT_MANIFEST_PROJECT="$(sed -n 's/^# project=\([^ ]*\).*/\1/p' <<< "$header")"
        # shellcheck disable=SC2034
        WT_MANIFEST_ISSUE="$(sed -n 's/.* issue=\([^ ]*\).*/\1/p' <<< "$header")"
        # shellcheck disable=SC2034
        WT_MANIFEST_LAYER="$(sed -n 's/.* layer=\([^ ]*\).*/\1/p' <<< "$header")"
        # shellcheck disable=SC2034
        WT_MANIFEST_BASE="$(sed -n 's/.* base=\([^ ]*\).*/\1/p' <<< "$header")"
        tail -n +2 "$manifest"
    else
        local branch
        branch="$(git -C "$worktree_dir" branch --show-current 2>/dev/null)"
        printf '%s\t.\t%s\n' "$worktree_dir" "$branch"
    fi
}

# True (0) if a worktree dir has a .worktree-repos manifest with more than
# one entry (a real multi-repo package worktree, not a legacy/single-repo
# one whose manifest — if any — has exactly one "." entry).
# Usage: if wt_is_package_worktree "$worktree_dir"; then ...
wt_is_package_worktree() {
    local worktree_dir="$1" count
    [ -f "$worktree_dir/.worktree-repos" ] || return 1
    count="$(wt_read_manifest "$worktree_dir" | wc -l)"
    [ "$count" -gt 1 ]
}

# Every git call worktree creation makes to origin runs through this
# (#323): GIT_TERMINAL_PROMPT=0 stops git asking for HTTPS credentials (a
# credential helper still answers), and `timeout` (when installed) ends it
# after WT_FETCH_TIMEOUT seconds (default 60), which also bounds an SSH
# passphrase or host-key prompt. The exit status is git's, or 124 (137
# after the -k grace) when the limit ended it.
# Usage: wt_bounded_git -C <repo> fetch ...
wt_fetch_limit() {  # prints the validated WT_FETCH_TIMEOUT
    local limit="${WT_FETCH_TIMEOUT:-60}"
    [[ "$limit" =~ ^[1-9][0-9]*$ ]] || limit=60
    echo "$limit"
}
wt_bounded_git() {
    local -a bound=()
    if command -v timeout >/dev/null 2>&1; then
        bound=(timeout -k 5 "$(wt_fetch_limit)")
    fi
    GIT_TERMINAL_PROMPT=0 ${bound[@]+"${bound[@]}"} git "$@"
}
# A one-line reason for a failed wt_bounded_git call: the timeout, or the
# first non-blank line of its stderr (no pipe: a `| sed q` under pipefail
# can fail the assignment and so the caller's set -e).
# Usage: why=$(wt_fetch_why <rc> "<stderr>")
wt_fetch_why() {
    local rc="$1" err="$2" why
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        echo "timed out after $(wt_fetch_limit)s"
        return 0
    fi
    why="${err#"${err%%[![:space:]]*}"}"
    why="${why%%$'\n'*}"
    echo "${why:-git fetch exited $rc}"
}

# Look up one named branch (an issue's or a parent's) on origin, every
# probe bounded by wt_bounded_git (#323), and sort the result into one of
# three outcomes. It prints nothing: it sets WT_FETCH_OUTCOME (present,
# absent or unknown) and WT_FETCH_REASON (one line, no final period) and
# returns 0, 1 or 2 to match, so each caller words its own message.
#
# The fetch names an explicit refspec, +refs/heads/<b>:refs/remotes/origin/<b>,
# and the outcome is decided by the ref the callers use, never by the
# fetch's exit code alone: a --single-branch or --depth clone narrows the
# configured refspec, and a plain `git fetch origin <b>` there exits 0
# having written FETCH_HEAD only. Any timeout (124, or 137 after the -k
# grace) or failure at any probe is "unknown", never "absent".
#
#   probes                                              outcome  reason
#   no origin remote                                    absent   there is no origin remote
#   fetch 0, origin/<b> verifies                        present  fetched
#   fetch 0, origin/<b> missing                         unknown  the fetch exited 0 but wrote no origin/<b>
#   fetch timed out                                     unknown  fetching '<b>' timed out after Ns
#   fetch failed, ls-remote 2 (origin lacks <b>)        absent   origin has no branch '<b>'
#   fetch failed, ls-remote 0 (origin has <b>)          unknown  origin has '<b>', but fetching it failed (<git's line>)
#   fetch failed, ls-remote timed out                   unknown  fetching '<b>' failed (<line>), and asking origin for it timed out after Ns
#   fetch failed, ls-remote failed, origin/<b> from     unknown  fetching '<b>' failed (<line>), and origin could not be asked; it had '<b>' at the last fetch (origin/<b>)
#     an earlier fetch
#   fetch failed, ls-remote failed, no origin/<b>       unknown  fetching '<b>' failed (<line>), and origin could not be asked whether it has '<b>'
#
# What each caller does with it:
#   - The issue branch, with no local branch of that name
#     (worktree_create.sh fetch_remote_branch; _wt_add_repo's target),
#     through wt_lookup_for_new_branch: present, check out origin/<b> with
#     its upstream set (wt_set_upstream), and a failure there is an error,
#     not a fresh branch; absent, start the branch afresh; unknown, stop.
#     A skill worktree's branch, minted this run with a timestamp
#     (WT_MINTED_BRANCH), is not looked up: origin cannot have it.
#   - A sub-issue's parent, when the sub-issue branch is new (the same two
#     scripts, through wt_lookup_for_new_branch): present, start the
#     sub-issue branch from origin/<parent>; absent, from the default
#     branch, with a warning; unknown, stop.
#   - A stop makes nothing in that repository. In a project worktree of
#     several repositories, those already added this run are rolled back
#     (their worktrees and the branches made for them) and the worktree
#     directory is removed.
#   - With --allow-unverified-branch (WT_ALLOW_UNVERIFIED_BRANCH=true),
#     "unknown" is treated as absent by those two, with a warning that
#     names the reason. Nothing else turns "unknown" into a fresh branch.
#   - A package worktree's base branch (worktree_create.sh --base, the
#     owning entry's new branch; _wt_add_repo's strict start path, issue
#     429): present, start the branch from origin/<base> with no upstream;
#     absent or unknown, stop having made nothing, also with
#     --allow-unverified-branch.
#   - An existing branch's parent (worktree_create.sh
#     check_existing_branch_parent, workspace and project types): only
#     the draft PR's base depends on it. present, the draft PR targets the
#     parent; absent or unknown, a warning names the reason and
#     `gh pr edit --base <parent>`, and the PR targets the default branch.
# Only the default-branch lookup (_wt_default_start_point) falls back to a
# local ref on a failed fetch: it never decides whether a branch exists.
# Usage: wt_fetch_named_branch <repo> <branch> || true; case "$WT_FETCH_OUTCOME" in ...
wt_fetch_named_branch() {
    local repo="$1" branch="$2" err="" rc=0 lrc=0 why=""
    WT_FETCH_OUTCOME=unknown
    WT_FETCH_REASON=""
    if ! git -C "$repo" remote get-url origin >/dev/null 2>&1; then
        WT_FETCH_OUTCOME=absent
        WT_FETCH_REASON="there is no origin remote"
        return 1
    fi
    err="$(wt_bounded_git -C "$repo" fetch --quiet origin -- \
        "+refs/heads/$branch:refs/remotes/origin/$branch" 2>&1 >/dev/null)" || rc=$?
    if [ "$rc" -eq 0 ]; then
        if git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$branch^{commit}" >/dev/null; then
            WT_FETCH_OUTCOME=present
            WT_FETCH_REASON="fetched"
            return 0
        fi
        WT_FETCH_REASON="the fetch exited 0 but wrote no origin/$branch"
        return 2
    fi
    why="$(wt_fetch_why "$rc" "$err")"
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        WT_FETCH_REASON="fetching '$branch' $why"
        return 2
    fi
    wt_bounded_git -C "$repo" ls-remote --exit-code --heads origin "refs/heads/$branch" >/dev/null 2>&1 || lrc=$?
    case "$lrc" in
        2)
            WT_FETCH_OUTCOME=absent
            WT_FETCH_REASON="origin has no branch '$branch'"
            return 1
            ;;
        0)
            WT_FETCH_REASON="origin has '$branch', but fetching it failed ($why)"
            ;;
        124|137)
            WT_FETCH_REASON="fetching '$branch' failed ($why), and asking origin for it $(wt_fetch_why "$lrc" "")"
            ;;
        *)
            if git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$branch^{commit}" >/dev/null; then
                WT_FETCH_REASON="fetching '$branch' failed ($why), and origin could not be asked; it had '$branch' at the last fetch (origin/$branch)"
            else
                WT_FETCH_REASON="fetching '$branch' failed ($why), and origin could not be asked whether it has '$branch'"
            fi
            ;;
    esac
    return 2
}

# The policy for a branch that does not exist locally and is about to be
# made (worktree_create.sh's workspace path and _wt_add_repo): look <want>
# up with wt_fetch_named_branch, where <want> is the new branch itself or
# the parent it would start from, and word the outcome for <new>.
#   0  present: origin/<want> is current, use it;
#   1  absent (or unknown with WT_ALLOW_UNVERIFIED_BRANCH=true, warned):
#      start without it;
#   2  unknown: an error naming the reason is on stderr; the caller stops
#      without making anything in <repo> (and worktree_create.sh rolls back
#      the repositories it already added this run), since a branch started
#      now could diverge from one origin has.
# WT_FETCH_OUTCOME and WT_FETCH_REASON are left as the lookup set them.
# Usage: wt_lookup_for_new_branch <repo> <want> <new>; rc=$?
wt_lookup_for_new_branch() {
    local repo="$1" want="$2" new="$3" rc=0 what="" instead=""
    wt_fetch_named_branch "$repo" "$want" || rc=$?
    [ "$rc" -ne 2 ] && return "$rc"
    if [ "$want" = "$new" ]; then
        what="cannot tell whether origin has '$new' (in $repo): $WT_FETCH_REASON"
        instead="a new '$new' is not started, since it would diverge from one origin may have"
    else
        what="cannot tell whether origin has the parent branch '$want' of '$new' (in $repo): $WT_FETCH_REASON"
        instead="'$new' is not started from the default branch in its place, since origin may have the parent"
    fi
    if [ "${WT_ALLOW_UNVERIFIED_BRANCH:-false}" = true ]; then
        if [ "$want" = "$new" ]; then
            echo "WARNING: $what. --allow-unverified-branch was given, so '$new' is started afresh; if origin has it, its first push is rejected." >&2
        else
            echo "WARNING: $what. --allow-unverified-branch was given, so '$new' starts from the default branch." >&2
        fi
        return 1
    fi
    echo "ERROR: $what; $instead. Retry when origin answers (for a slow origin, raise WT_FETCH_TIMEOUT, now $(wt_fetch_limit)s), or pass --allow-unverified-branch to start it anyway." >&2
    return 2
}

# Set <branch>'s upstream to origin/<branch> by writing only that
# branch's own settings (branch.<b>.remote, branch.<b>.merge), which is
# what `--track` writes. `--track` itself is not used: in a --single-branch
# or --depth clone no fetch refspec maps origin/<b>, and git refuses it;
# and origin's fetch refspecs are left as they were found, since one added
# for <b> would outlive the branch and fail every plain `git fetch` there
# once origin deletes it. In such a clone `<b>@{upstream}` does not
# resolve (no remote-tracking ref is mapped), but `git pull` and
# `git push` read these settings.
# Usage: wt_set_upstream <repo> <branch>
wt_set_upstream() {
    git -C "$1" config "branch.$2.remote" origin \
        && git -C "$1" config "branch.$2.merge" "refs/heads/$2"
}

# The start point for a new branch in <repo> that has no parent branch
# (issue #323): the repo's default branch as origin has it, never the
# invoking checkout's HEAD, so a worktree created from inside a feature
# worktree does not inherit that feature's commits.
#   - The ref resolve_default_branch returns (`main` or `origin/main`) is
#     reduced to its name and fetched quietly into origin/<name>.
#   - Fetched: prints `origin/<name>`.
#   - The fetch never prompts and never hangs (wt_bounded_git).
#   - Origin unreachable, the fetch timed out, or the ref missing there:
#     prints the local `<name>` (else a stale `origin/<name>`) with a
#     warning on stderr that names why (the timeout, or git's first error
#     line).
#   - Nothing resolves: an error with the `git remote set-head origin -a`
#     hint, and returns 1 (never a silent HEAD).
# Callers create the branch with `git worktree add --no-track`, so it stays
# untracked until its first `push -u`, as before.
# _resolve_default_branch.sh is sourced here, at call time, not when this
# file is sourced, so callers that never create a branch do not need it.
# Usage: start=$(_wt_default_start_point <repo>) || exit 1
_wt_default_start_point() {
    local repo="$1" ref="" name="" helper=""
    if ! declare -F resolve_default_branch >/dev/null; then
        helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_resolve_default_branch.sh"
        if [ ! -f "$helper" ]; then
            echo "ERROR: cannot pick a start point for a new branch: $helper is missing" >&2
            return 1
        fi
        # shellcheck source=_resolve_default_branch.sh
        source "$helper"
    fi
    if ! ref="$(resolve_default_branch "$repo")" || [ -z "$ref" ]; then
        echo "ERROR: cannot resolve the default branch of $repo, so a new branch has no start point." >&2
        echo "  Run: git -C $repo remote set-head origin -a" >&2
        return 1
    fi
    name="${ref#origin/}"
    local err="" rc=0 why=""
    err="$(wt_bounded_git -C "$repo" fetch --quiet origin -- "+refs/heads/$name:refs/remotes/origin/$name" 2>&1 >/dev/null)" \
        || rc=$?
    if [ "$rc" -eq 0 ] \
       && git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$name^{commit}" >/dev/null; then
        echo "origin/$name"
        return 0
    fi
    why="$(wt_fetch_why "$rc" "$err")"
    if git -C "$repo" rev-parse --verify --quiet "refs/heads/$name^{commit}" >/dev/null; then
        echo "WARNING: could not fetch '$name' from origin in $repo ($why); starting the new branch from the local '$name', which may be behind origin" >&2
        echo "$name"
        return 0
    fi
    if git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$name^{commit}" >/dev/null; then
        echo "WARNING: could not fetch '$name' from origin in $repo ($why); starting the new branch from the last fetched 'origin/$name'" >&2
        echo "origin/$name"
        return 0
    fi
    echo "ERROR: the default branch '$name' of $repo is neither on origin nor local, so a new branch has no start point." >&2
    echo "  Run: git -C $repo remote set-head origin -a" >&2
    return 1
}

# Make the new branch <branch> at <start> in <repo> and check it out at
# <dest> (#323), in two steps so that a failure undoes only what this run
# made. `git branch` either makes <branch> or refuses, never taking over
# one that exists, so its success is the proof that the branch is this
# run's; only then does `git worktree add` check it out. It runs right
# before the checkout, after the origin lookup (which can take
# WT_FETCH_TIMEOUT): a '<branch>' that another run created in the meantime
# is refused here, with nothing made and nothing to undo. <option>s go to
# `git branch` (e.g. --no-track). git's output is printed, never swallowed.
# Status: 0 checked out; 1 failed after this run made <branch> (the caller
# undoes it, with any worktree the checkout left on it); 2 failed having
# made nothing (the caller undoes nothing).
# Usage: wt_add_new_branch <repo> <dest> <branch> <start> [<option>...]
wt_add_new_branch() {
    local repo="$1" dest="$2" branch="$3" start="$4"
    shift 4
    if ! git -C "$repo" branch "$@" "$branch" "$start"; then
        if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
            echo "ERROR: another run created the branch '$branch' in $repo while this run was asking origin about it; this run made nothing and removes nothing." >&2
        fi
        return 2
    fi
    git -C "$repo" worktree add "$dest" "$branch" || return 1
    return 0
}

# Create one repo's git worktree from the first of: the target branch
# locally, the target branch on origin (tracked), the parent branch
# (locally then on origin) as the base for a new target branch, or a brand
# new untracked branch off the repo's default branch (_wt_default_start_point,
# never HEAD). A branch or parent found but failing to check out is an
# error, never a reason to start from the default instead. The failing
# git command's output is printed — never swallowed with 2>/dev/null.
# When origin cannot tell whether it has the target or the parent branch
# (wt_fetch_named_branch's "unknown"), it returns 1 having made nothing in
# <origin_repo>, unless WT_ALLOW_UNVERIFIED_BRANCH=true (worktree_create.sh's
# --allow-unverified-branch). A branch it makes for a checkout that then
# fails is removed again, with any worktree that checkout left; a branch
# another run created during the origin lookup is refused, never removed.
# It sets WT_ADD_PARENT_LOOKED_UP=true when it asked origin about <parent_branch>.
# Never falls back to a symlink (ADR-0012's structural no-symlink rule).
#
# <base_branch> (issue 429; worktree_create.sh --base, the owning entry of a
# package worktree only, never with <parent_branch>) is the strict start
# path: a NEW '$branch' (neither local nor on origin) starts at origin's
# <base_branch>, fetched now, with no upstream (--no-track). Origin lacking
# it, or not answering, stops here having made nothing, whatever
# WT_ALLOW_UNVERIFIED_BRANCH says: a branch started on a base nobody
# verified would open a pull request against history the base does not
# have. The local <base_branch> is never used (a vcs-imported checkout can
# hold unpushed or stale commits there), nor the default branch in its
# place. A '$branch' that already exists locally or on origin is checked
# out as without a base. WT_ADD_STARTED_FROM_BASE is true after a success
# only when this call started '$branch' at origin's <base_branch>: the
# caller records base= for it as it is, and checks an existing branch
# first (wt_base_foreign_history).
# Usage: _wt_add_repo <origin_repo> <dest_dir> <branch> [<parent_branch>] [<base_branch>]
_wt_add_repo() {
    local origin="$1" dest="$2" branch="$3" parent_branch="${4:-}" base_branch="${5:-}"
    local out="" rc=1 made_branch=false started_from_base=false
    WT_ADD_PARENT_LOOKED_UP=false
    WT_ADD_STARTED_FROM_BASE=false

    if git -C "$origin" show-ref --verify --quiet "refs/heads/$branch"; then
        out="$(git -C "$origin" worktree add "$dest" "$branch" 2>&1)"; rc=$?
    else
        # Every add below makes '$branch' (wt_add_new_branch): made_branch
        # is true only once this run has made it, and only then is a
        # failure undone at the end. wt_lookup_for_new_branch has printed
        # the reason for a stop (2).
        local frc=0 prc=0 arc=0 base="" start=""
        if [ -n "${WT_MINTED_BRANCH:-}" ] && [ "$branch" = "$WT_MINTED_BRANCH" ]; then
            frc=1   # minted this run: origin cannot have it, so it is not asked
        else
            wt_lookup_for_new_branch "$origin" "$branch" "$branch" || frc=$?
        fi
        if [ "$frc" -eq 2 ]; then
            return 1
        elif [ "$frc" -eq 0 ]; then
            # origin has the branch: check it out with its upstream set, or
            # fail; never start another '$branch' in its place.
            out="$(wt_add_new_branch "$origin" "$dest" "$branch" "origin/$branch" --no-track 2>&1)" || arc=$?
            rc=$arc; if [ "$arc" -ne 2 ]; then made_branch=true; fi
            if [ "$rc" -eq 0 ] && ! wt_set_upstream "$origin" "$branch"; then
                out="could not set the upstream of '$branch' to origin/$branch"; rc=1
            fi
        elif [ -n "$base_branch" ]; then
            # The strict start path: origin's base, fetched now, or nothing.
            wt_fetch_named_branch "$origin" "$base_branch" || true
            case "$WT_FETCH_OUTCOME" in
                present)
                    out="$(wt_add_new_branch "$origin" "$dest" "$branch" "origin/$base_branch" --no-track 2>&1)" || arc=$?
                    rc=$arc; if [ "$arc" -ne 2 ]; then made_branch=true; fi
                    started_from_base=true
                    ;;
                absent)
                    echo "ERROR: '$branch' starts from its base branch '$base_branch' as origin has it, and origin does not have it (in $origin): $WT_FETCH_REASON. Nothing was made here; '$branch' is not started from the local '$base_branch' or the default branch in its place. Push '$base_branch' to origin, or pass --base with a branch origin has." >&2
                    return 1
                    ;;
                *)
                    echo "ERROR: cannot tell whether origin has the base branch '$base_branch' of '$branch' (in $origin): $WT_FETCH_REASON. Nothing was made here; a branch started on a base origin did not confirm can diverge from it, so --allow-unverified-branch does not apply to a base. Retry when origin answers (for a slow origin, raise WT_FETCH_TIMEOUT, now $(wt_fetch_limit)s)." >&2
                    return 1
                    ;;
            esac
        else
            if [ -n "$parent_branch" ]; then
                if git -C "$origin" show-ref --verify --quiet "refs/heads/$parent_branch"; then
                    base="$parent_branch"
                else
                    # shellcheck disable=SC2034  # read by worktree_create.sh
                    WT_ADD_PARENT_LOOKED_UP=true
                    wt_lookup_for_new_branch "$origin" "$parent_branch" "$branch" || prc=$?
                    if [ "$prc" -eq 2 ]; then
                        return 1
                    elif [ "$prc" -eq 0 ]; then
                        base="origin/$parent_branch"
                    elif [ "$WT_FETCH_OUTCOME" = absent ]; then
                        echo "WARNING: parent branch '$parent_branch' is not in $origin ($WT_FETCH_REASON); starting '$branch' from the default branch" >&2
                    fi
                fi
            fi
            # A parent that was found is the base or the error; the default
            # branch is the start only when there is no parent to use.
            if [ -n "$base" ]; then
                out="$(wt_add_new_branch "$origin" "$dest" "$branch" "$base" 2>&1)" || arc=$?
                rc=$arc; if [ "$arc" -ne 2 ]; then made_branch=true; fi
            elif start="$(_wt_default_start_point "$origin")"; then
                out="$(wt_add_new_branch "$origin" "$dest" "$branch" "$start" --no-track 2>&1)" || arc=$?
                rc=$arc; if [ "$arc" -ne 2 ]; then made_branch=true; fi
            else
                out=""; rc=1
            fi
        fi
    fi

    if [ "$rc" -eq 0 ]; then
        # shellcheck disable=SC2034  # read by worktree_create.sh
        WT_ADD_STARTED_FROM_BASE="$started_from_base"
        return 0
    fi
    echo "ERROR: could not create a worktree for $origin at $dest (branch '$branch')" >&2
    [ -n "$out" ] && echo "$out" >&2
    # A failed checkout leaves the branch this run made and, when the
    # checkout itself failed, a registered worktree: remove both, so a
    # retry asks origin again instead of taking the left-behind branch as
    # the local one. A branch this run did not make (made_branch=false:
    # it existed, or another run created it) is never touched.
    if [ "$made_branch" = true ] \
       && git -C "$origin" show-ref --verify --quiet "refs/heads/$branch"; then
        # Only a worktree on the branch this run made is ours to remove.
        if [ "$(git -C "$dest" symbolic-ref -q HEAD 2>/dev/null)" = "refs/heads/$branch" ]; then
            git -C "$origin" worktree remove --force "$dest" >/dev/null 2>&1 || true
        fi
        if git -C "$origin" branch -D "$branch" >/dev/null 2>&1; then
            echo "  The branch '$branch' made for it was removed again." >&2
        else
            echo "  WARNING: the branch '$branch' made for it is left in $origin; remove it with: git -C $origin branch -D $branch" >&2
        fi
    fi
    return 1
}

# Find the most recent skill worktree matching a skill name.
# Skill worktree dirs are named: skill-{REPO_SLUG}-{SKILL}-{TIMESTAMP}
# Usage: path=$(find_worktree_by_skill "$base_dir" "$skill_name" ["$repo_slug"])
# Optional repo_slug filters to a specific repository.
find_worktree_by_skill() {
    local base_dir="$1"
    local skill="$2"
    local repo_slug="${3:-}"

    local matches=()
    # Use an array for the glob to avoid word-splitting issues
    local -a glob_patterns
    if [ -n "$repo_slug" ]; then
        glob_patterns=( "$base_dir"/skill-"${repo_slug}"-"${skill}"-* )
    else
        glob_patterns=( "$base_dir"/skill-*-"${skill}"-* )
    fi
    for path in "${glob_patterns[@]}"; do
        # When glob doesn't match, bash returns the literal pattern
        if [ -d "$path" ]; then
            matches+=( "$path" )
        fi
    done

    if [ "${#matches[@]}" -eq 0 ]; then
        return 1
    fi

    if [ "${#matches[@]}" -gt 1 ]; then
        echo "Warning: multiple skill worktrees found for '$skill'; using most recent" >&2
    fi

    # Find the most recent by comparing the timestamp suffix in the basename,
    # not the full path (which includes repo_slug and can sort incorrectly)
    local latest_path="" latest_ts=""
    for path in "${matches[@]}"; do
        local basename="${path##*/}"
        # Basename format: skill-{REPO_SLUG}-{SKILL}-{TIMESTAMP}
        # Extract timestamp: everything after the last occurrence of -{skill}-
        local ts="${basename##*-"${skill}"-}"
        if [ -z "$latest_ts" ] || [[ "$ts" > "$latest_ts" ]]; then
            latest_ts="$ts"
            latest_path="$path"
        fi
    done

    echo "$latest_path"
    return 0
}
