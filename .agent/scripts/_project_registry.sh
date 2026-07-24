#!/bin/bash
# .agent/scripts/_project_registry.sh
# Per-machine project registry helpers (issue #227 — #172 step 2).
#
# The registry lives at .agent/projects.local (gitignored). It maps a
# project name to a hosting directory and a project type:
#
#   # <name>  <project_type>  [<path>]
#   gz4d  single_project
#   coastal  single_project  /data/checkouts/coastal_mapper
#
# - name: [A-Za-z0-9][A-Za-z0-9._-]* — also the default hosting dir name
#   (projects/<name>/) and the worktree repo key (worktrees/project/<name>/)
# - project_type: must have an adapter at .agent/project_types/<type>/
# - path: optional hosting dir; relative paths resolve against the
#   workspace root; default projects/<name>. Paths must not contain spaces.
#
# See .agent/projects.local.example for a commented template.
#
# Source this file from other scripts:
#   source "$SCRIPT_DIR/_project_registry.sh"
#
# All functions take the workspace root as their first argument and are
# silent on stdout except for their documented output. Malformed registry
# lines are reported on stderr and make the parse fail (return 2) — a bad
# registry must never silently resolve to the wrong project.

# Print the registry file path for a workspace root.
# Usage: file=$(registry_file "$root")
registry_file() {
    echo "$1/.agent/projects.local"
}

# Parse the registry and print one entry per line as:
#   <name>\t<type>\t<abs_path>
# Missing file → no output, return 0 (registry is optional).
# Malformed lines → diagnostics on stderr, return 2 (valid lines still print).
# Usage: entries=$(registry_entries "$root") || { ...parse error... }
registry_entries() {
    local root="$1" file lineno=0 rc=0
    local raw name type path extra
    file="$(registry_file "$root")"
    [ -f "$file" ] || return 0
    while IFS= read -r raw || [ -n "$raw" ]; do
        lineno=$((lineno + 1))
        raw="${raw%%#*}"
        name=""; type=""; path=""; extra=""
        read -r name type path extra <<< "$raw" || true
        [ -z "$name" ] && continue
        if [ -n "$extra" ]; then
            echo "ERROR: ${file}:${lineno}: too many fields (paths must not contain spaces)" >&2
            rc=2
            continue
        fi
        if ! [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
            echo "ERROR: ${file}:${lineno}: invalid project name '$name'" >&2
            rc=2
            continue
        fi
        if [ -z "$type" ] || ! [[ "$type" =~ ^[a-z0-9][a-z0-9_]*$ ]]; then
            echo "ERROR: ${file}:${lineno}: invalid or missing project type for '$name'" >&2
            rc=2
            continue
        fi
        [ -z "$path" ] && path="projects/$name"
        case "$path" in
            /*) : ;;
            *) path="$root/$path" ;;
        esac
        printf '%s\t%s\t%s\n' "$name" "$type" "$path"
    done < "$file"
    return $rc
}

# Print all registered project names, one per line.
# Return codes follow registry_entries.
# Usage: names=$(registry_names "$root")
registry_names() {
    local root="$1" entries rc=0
    entries="$(registry_entries "$root")" || rc=$?
    [ -n "$entries" ] && cut -f1 <<< "$entries"
    return $rc
}

# Look up one project by name. Prints "<type>\t<abs_path>".
# Return 1 if the name is not registered, 2 on registry parse errors.
# Usage: entry=$(registry_lookup "$root" "$name")
registry_lookup() {
    local root="$1" want="$2" entries name type path
    entries="$(registry_entries "$root")" || return 2
    while IFS=$'\t' read -r name type path; do
        [ -z "$name" ] && continue
        if [ "$name" = "$want" ]; then
            printf '%s\t%s\n' "$type" "$path"
            return 0
        fi
    done <<< "$entries"
    return 1
}

# Resolve the project owning a directory: the registry entry whose hosting
# dir is the directory itself or an ancestor of it. Longest match wins.
# Prints "<name>\t<type>\t<abs_path>".
# Return 1 if no entry matches, 2 on registry parse errors.
# Usage: entry=$(registry_resolve_from_dir "$root" "$dir")
registry_resolve_from_dir() {
    local root="$1" dir="$2" abs entries name type path
    local rpath best="" best_len=0
    abs="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
    entries="$(registry_entries "$root")" || return 2
    while IFS=$'\t' read -r name type path; do
        [ -z "$name" ] && continue
        rpath="$(cd "$path" 2>/dev/null && pwd -P)" || continue
        if [ "$abs" = "$rpath" ] || [[ "$abs" == "$rpath/"* ]]; then
            if [ "${#rpath}" -gt "$best_len" ]; then
                best="$(printf '%s\t%s\t%s' "$name" "$type" "$path")"
                best_len=${#rpath}
            fi
        fi
    done <<< "$entries"
    if [ -n "$best" ]; then
        printf '%s\n' "$best"
        return 0
    fi
    return 1
}
