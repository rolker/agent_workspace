#!/bin/bash
# .agent/scripts/_worktree_helpers.sh
# Shared helper functions for worktree scripts
#
# Source this file from other worktree scripts:
#   source "$SCRIPT_DIR/_worktree_helpers.sh"

# --- Worktree base directory helpers ---
# New layout (issue #25):
#   worktrees/workspace/          — workspace worktrees
#   worktrees/project/<repo>/     — project worktrees (per-repo)
# Legacy layout (deprecated):
#   .workspace-worktrees/         — old workspace worktrees
#   project/worktrees/            — old project worktrees

# Resolve the workspace worktree base directory.
# Usage: dir=$(wt_workspace_base "$root_dir")
wt_workspace_base() {
    echo "$1/worktrees/workspace"
}

# Resolve the project worktree base directory for a given repo.
# Usage: dir=$(wt_project_base "$root_dir" "$repo_name")
wt_project_base() {
    local root_dir="$1"
    local repo_name="$2"

    # Validate repo_name to prevent path traversal
    if [[ -z "$repo_name" ]]; then
        echo "Error: repo name must not be empty." >&2
        return 1
    fi
    if [[ "$repo_name" == *"/"* ]] || [[ "$repo_name" == *".."* ]] || [[ "$repo_name" == "." ]]; then
        echo "Error: invalid repo name '$repo_name': must not contain '/' or '..'." >&2
        return 1
    fi
    if [[ ! "$repo_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo "Error: invalid repo name '$repo_name': only letters, numbers, '.', '_', and '-' are allowed." >&2
        return 1
    fi

    echo "$root_dir/worktrees/project/$repo_name"
}

# Resolve the project worktree base glob (all repos).
# Usage: for dir in $(wt_project_base_glob "$root_dir"); do ...
wt_project_base_glob() {
    echo "$1/worktrees/project"
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
#   # project=<name> issue=<owner/repo#N|N> layer=<l>
#   <origin_repo_abs_path>\t<rel_path_in_worktree>\t<branch>
#   ...
# Every worktree script reads this file (never the adapter, never the
# directory name) to learn which repos compose the worktree. A worktree
# without this file is a legacy single-repo worktree: wt_read_manifest
# falls back to one synthetic entry (the worktree root itself).

# Write the manifest. Entry lines (worktree_repos output) are read from
# stdin. Usage:
#   printf '%s\n' "$repo_lines" | wt_write_manifest "$dir" "$project" "$issue" "$layer"
wt_write_manifest() {
    local worktree_dir="$1" project="$2" issue="$3" layer="$4"
    {
        printf '# project=%s issue=%s layer=%s\n' "$project" "$issue" "$layer"
        cat
    } > "$worktree_dir/.worktree-repos"
}

# Read the manifest for a worktree dir. Prints entry lines (without the
# header) to stdout, and sets WT_MANIFEST_PROJECT / WT_MANIFEST_ISSUE /
# WT_MANIFEST_LAYER from the header. Legacy fallback (no manifest file):
# one entry — the worktree root itself, "." , current branch — and all
# three header variables empty.
# Usage: entries=$(wt_read_manifest "$worktree_dir")
wt_read_manifest() {
    local worktree_dir="$1" manifest header
    manifest="$worktree_dir/.worktree-repos"
    WT_MANIFEST_PROJECT=""
    WT_MANIFEST_ISSUE=""
    WT_MANIFEST_LAYER=""
    if [ -f "$manifest" ]; then
        header="$(head -n1 "$manifest")"
        # Read by callers (worktree_list.sh, dashboard.sh, etc.), not this file.
        # shellcheck disable=SC2034
        WT_MANIFEST_PROJECT="$(sed -n 's/^# project=\([^ ]*\).*/\1/p' <<< "$header")"
        # shellcheck disable=SC2034
        WT_MANIFEST_ISSUE="$(sed -n 's/.* issue=\([^ ]*\).*/\1/p' <<< "$header")"
        # shellcheck disable=SC2034
        WT_MANIFEST_LAYER="$(sed -n 's/.* layer=\([^ ]*\)$/\1/p' <<< "$header")"
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

# Create one repo's git worktree, trying (in order): the target branch
# locally, the target branch on origin, the parent branch (locally then on
# origin) as the base for a new target branch, and finally a brand new
# branch off HEAD. Every attempt's stderr is captured; only the final
# failure's combined output is printed — never swallowed with 2>/dev/null.
# Never falls back to a symlink (ADR-0012's structural no-symlink rule).
# Usage: _wt_add_repo <origin_repo> <dest_dir> <branch> [<parent_branch>]
_wt_add_repo() {
    local origin="$1" dest="$2" branch="$3" parent_branch="${4:-}"
    local out="" rc=1

    if git -C "$origin" show-ref --verify --quiet "refs/heads/$branch"; then
        out="$(git -C "$origin" worktree add "$dest" "$branch" 2>&1)"; rc=$?
    else
        out="$(git -C "$origin" fetch origin -- "$branch" 2>&1)"; rc=$?
        if [ "$rc" -eq 0 ]; then
            out="$(git -C "$origin" worktree add --track -b "$branch" "$dest" "origin/$branch" 2>&1)"; rc=$?
        fi

        if [ "$rc" -ne 0 ] && [ -n "$parent_branch" ]; then
            local base=""
            if git -C "$origin" show-ref --verify --quiet "refs/heads/$parent_branch"; then
                base="$parent_branch"
            else
                local fetch_out; fetch_out="$(git -C "$origin" fetch origin -- "$parent_branch" 2>&1)"
                if [ $? -eq 0 ]; then
                    base="origin/$parent_branch"
                else
                    out="$fetch_out"
                fi
            fi
            if [ -n "$base" ]; then
                out="$(git -C "$origin" worktree add -b "$branch" "$dest" "$base" 2>&1)"; rc=$?
            fi
        fi

        if [ "$rc" -ne 0 ]; then
            out="$(git -C "$origin" worktree add -b "$branch" "$dest" 2>&1)"; rc=$?
        fi
    fi

    if [ "$rc" -eq 0 ]; then
        return 0
    fi
    echo "ERROR: could not create a worktree for $origin at $dest (branch '$branch')" >&2
    [ -n "$out" ] && echo "$out" >&2
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
