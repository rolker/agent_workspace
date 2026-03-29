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
# Returns the path if found, exits 1 if not found.
# On multiple matches, prints disambiguation help to stderr and exits 1.
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

# Get branch name from the first inner package git worktree in a layer worktree.
# Returns empty string if no inner git worktree is found.
# Usage: branch=$(wt_layer_branch "$worktree_dir")
wt_layer_branch() {
    local worktree_dir="$1"

    for ws_dir in "$worktree_dir"/*_ws; do
        [ -d "$ws_dir" ] || continue
        [ -L "$ws_dir" ] && continue  # skip symlinked layers

        local src_dir="$ws_dir/src"
        [ -d "$src_dir" ] || continue

        for pkg_dir in "$src_dir"/*; do
            [ -d "$pkg_dir" ] || continue
            [ -L "$pkg_dir" ] && continue  # skip symlinked packages

            if git -C "$pkg_dir" rev-parse --git-dir &>/dev/null; then
                local branch
                branch=$(git -C "$pkg_dir" branch --show-current 2>/dev/null)
                if [ -n "$branch" ]; then
                    echo "$branch"
                    return 0
                fi
            fi
        done
    done

    return 1
}

# Check if a layer worktree has uncommitted changes in any inner package git worktree.
# Ignores symlinked layers/packages and infrastructure directories.
# Returns 0 (true) if dirty, 1 (false) if clean.
# Usage: if wt_layer_is_dirty "$worktree_dir"; then ...
wt_layer_is_dirty() {
    local worktree_dir="$1"

    for ws_dir in "$worktree_dir"/*_ws; do
        [ -d "$ws_dir" ] || continue
        [ -L "$ws_dir" ] && continue  # skip symlinked layers

        local src_dir="$ws_dir/src"
        [ -d "$src_dir" ] || continue

        for pkg_dir in "$src_dir"/*; do
            [ -d "$pkg_dir" ] || continue
            [ -L "$pkg_dir" ] && continue  # skip symlinked packages

            if git -C "$pkg_dir" rev-parse --git-dir &>/dev/null; then
                if [ -n "$(git -C "$pkg_dir" status --porcelain 2>/dev/null)" ]; then
                    return 0  # dirty
                fi
            fi
        done
    done

    return 1  # clean
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
