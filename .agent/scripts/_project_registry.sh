#!/bin/bash
# .agent/scripts/_project_registry.sh
# Per-machine project registry helpers (issue #227 — #172 step 2; parent
# roots, trailing fields, worktree dirs and the root guard: issue #265).
#
# The registry lives at .agent/projects.local (gitignored). It maps a
# project name to a hosting directory and a project type, plus optional
# trailing key=value fields:
#
#   # <name>  <project_type>  [<path>]  [key=value ...]
#   gz4d         single_project  /home/me/src/gz4d
#   p11          project         /home/me/project11-ng   default_instance=p11-rolling
#   p11-jazzy    ros2_colcon     /home/me/project11-ng/jazzy    parent=p11 distro=jazzy
#   p11-rolling  ros2_colcon     /home/me/project11-ng/rolling  parent=p11 distro=rolling
#
# - name: [A-Za-z0-9][A-Za-z0-9._-]* — also the default hosting dir name
#   (projects/<name>/) and the worktree repo key
# - project_type: must have an adapter at .agent/project_types/<type>/,
#   except the pseudo-type "project": a parent root that groups instances
#   (session and memory unit, no adapter of its own)
# - path: optional hosting dir; relative paths resolve against the
#   workspace root; default projects/<name>. Paths must not contain spaces
#   or '=' (a third token containing '=' is read as a field).
# - trailing fields (values must not contain spaces):
#     parent=<name>            this entry is an instance of parent root <name>
#                              (<name> must be a "project"-type entry)
#     worktrees=<path>         where this root's worktrees live (default
#                              <path>/worktrees); must lie under the entry's
#                              own path or under the workspace root, so the
#                              root guard always accepts a worktree
#     role=<name>              passed to the adapter as ACTIVE_PROJECT_ROLE
#     distro=<name>            passed to the adapter as ACTIVE_PROJECT_DISTRO
#                              ([a-z0-9_]+, the same rule ros2_colcon applies)
#     default_instance=<name>  parent lines only: the instance used when the
#                              parent is selected without --project
#
# See .agent/projects.local.example for a commented template.
#
# Source this file from other scripts:
#   source "$SCRIPT_DIR/_project_registry.sh"
#
# All functions take the workspace root as their first argument and are
# silent on stdout except for their documented output. Malformed registry
# lines are reported on stderr and make the parse fail (return 2) — a bad
# registry must never silently resolve to the wrong project. Duplicate
# names and two entries with the same canonical path are parse errors
# (the first definition is kept). CRLF line endings are tolerated.

# The pseudo-type of a parent root.
# shellcheck disable=SC2034
REGISTRY_PARENT_TYPE="project"

# Keys accepted as trailing fields.
_REGISTRY_KEYS=" parent worktrees role distro default_instance "

# Print the registry file path for a workspace root.
# Usage: file=$(registry_file "$root")
registry_file() {
    echo "$1/.agent/projects.local"
}

# Parse the registry and print one entry per line as:
#   <name>\t<type>\t<abs_path>\t<fields>
# where <fields> is the space-separated key=value list (possibly empty).
# Missing file → no output, return 0 (registry is optional).
# Malformed lines → diagnostics on stderr, return 2 (valid lines still
# print). Cross-line rules (parent must exist and be a parent root;
# default_instance must be an instance of that parent) also return 2 and
# drop the offending line.
# Usage: entries=$(registry_entries_full "$root") || { ...parse error... }
registry_entries_full() {
    local root="$1" file lineno=0 rc=0
    local raw name type path rest field key value fields known
    local -a lines=()
    file="$(registry_file "$root")"
    [ -f "$file" ] || return 0
    while IFS= read -r raw || [ -n "$raw" ]; do
        lineno=$((lineno + 1))
        raw="${raw%$'\r'}"
        raw="${raw%%#*}"
        name=""; type=""; path=""; rest=""; fields=""
        read -r name type path rest <<< "$raw" || true
        [ -z "$name" ] && continue
        # A third token containing '=' is a field, not a path ('=' is
        # forbidden in paths so the two can never be confused).
        if [[ "$path" == *=* ]]; then
            rest="$path${rest:+ $rest}"
            path=""
        fi
        # '..' is rejected so a registered name can never trip
        # wt_project_base's path-traversal rule downstream.
        if ! [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || [[ "$name" == *..* ]]; then
            echo "ERROR: ${file}:${lineno}: invalid project name '$name'" >&2
            rc=2
            continue
        fi
        if [ -z "$type" ] || ! [[ "$type" =~ ^[a-z0-9][a-z0-9_]*$ ]]; then
            echo "ERROR: ${file}:${lineno}: invalid or missing project type for '$name'" >&2
            rc=2
            continue
        fi
        local bad=0
        local -a rest_fields=()
        read -r -a rest_fields <<< "$rest"   # array, never word-splitting-with-globbing
        for field in ${rest_fields[@]+"${rest_fields[@]}"}; do
            key="${field%%=*}"
            value="${field#*=}"
            if [ "$key" = "$field" ] || [ -z "$key" ] || [ -z "$value" ]; then
                echo "ERROR: ${file}:${lineno}: expected key=value, got '$field' (paths must not contain spaces)" >&2
                bad=1
                break
            fi
            if [[ "$_REGISTRY_KEYS" != *" $key "* ]]; then
                known="${_REGISTRY_KEYS# }"; known="${known% }"
                echo "ERROR: ${file}:${lineno}: unknown field '$key' for '$name' (known: $known)" >&2
                bad=1
                break
            fi
            if _registry_field_of "$fields" "$key" >/dev/null; then
                echo "ERROR: ${file}:${lineno}: duplicate field '$key' for '$name'" >&2
                bad=1
                break
            fi
            case "$key" in
                parent|default_instance)
                    if ! [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || [[ "$value" == *..* ]]; then
                        echo "ERROR: ${file}:${lineno}: invalid $key '$value' for '$name'" >&2
                        bad=1
                        break
                    fi
                    ;;
                role)
                    if ! [[ "$value" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
                        echo "ERROR: ${file}:${lineno}: invalid $key '$value' for '$name'" >&2
                        bad=1
                        break
                    fi
                    ;;
                distro)
                    # Same rule as ros2_colcon's _rc_distro, so a registry-
                    # valid distro can never fail in the adapter.
                    if ! [[ "$value" =~ ^[a-z0-9_]+$ ]]; then
                        echo "ERROR: ${file}:${lineno}: invalid $key '$value' for '$name'" >&2
                        bad=1
                        break
                    fi
                    ;;
                worktrees)
                    case "$value" in
                        /*) : ;;
                        *) value="$root/$value" ;;
                    esac
                    value="$(_registry_normpath "$value")"
                    ;;
            esac
            fields="${fields:+$fields }$key=$value"
        done
        [ "$bad" -eq 1 ] && { rc=2; continue; }
        [ -z "$path" ] && path="projects/$name"
        case "$path" in
            /*) : ;;
            *) path="$root/$path" ;;
        esac
        path="$(_registry_normpath "$path")"
        local wt
        wt="$(_registry_field_of "$fields" worktrees)" || wt=""
        if [ -n "$wt" ] && ! _registry_path_under "$wt" "$path" && ! _registry_path_under "$wt" "$root"; then
            echo "ERROR: ${file}:${lineno}: worktrees '$wt' for '$name' must lie under $path or under the workspace root $root" >&2
            rc=2
            continue
        fi
        lines+=("$(printf '%s\t%s\t%s\t%s\t%s' "$lineno" "$name" "$type" "$path" "$fields")")
    done < "$file"

    # Cross-line rules.
    local l lno lname ltype lpath lfields ref reftype seen=" " seen_paths=$'\n' canon
    for l in ${lines[@]+"${lines[@]}"}; do
        IFS=$'\t' read -r lno lname ltype lpath lfields <<< "$l"
        if [[ "$seen" == *" $lname "* ]]; then
            echo "ERROR: ${file}:${lno}: duplicate project name '$lname'" >&2
            rc=2; continue
        fi
        seen="$seen$lname "
        # Two entries must never resolve to one directory (literal duplicate
        # or symlink alias): cwd discovery would be ambiguous.
        canon="$(cd "$lpath" 2>/dev/null && pwd -P || echo "$lpath")"
        if [[ "$seen_paths" == *$'\n'"$canon"$'\n'* ]]; then
            echo "ERROR: ${file}:${lno}: '$lname' resolves to $canon, already registered by another entry" >&2
            rc=2; continue
        fi
        seen_paths="$seen_paths$canon"$'\n'
        ref="$(_registry_field_of "$lfields" parent)"
        if [ -n "$ref" ]; then
            if [ "$ltype" = "$REGISTRY_PARENT_TYPE" ]; then
                echo "ERROR: ${file}:${lno}: parent root '$lname' may not itself have a parent (no nesting)" >&2
                rc=2; continue
            fi
            reftype="$(_registry_type_in_lines "$ref" ${lines[@]+"${lines[@]}"})"
            if [ -z "$reftype" ]; then
                echo "ERROR: ${file}:${lno}: parent '$ref' of '$lname' is not registered" >&2
                rc=2; continue
            fi
            if [ "$reftype" != "$REGISTRY_PARENT_TYPE" ]; then
                echo "ERROR: ${file}:${lno}: parent '$ref' of '$lname' is type '$reftype', not '$REGISTRY_PARENT_TYPE'" >&2
                rc=2; continue
            fi
        fi
        ref="$(_registry_field_of "$lfields" default_instance)"
        if [ -n "$ref" ]; then
            if [ "$ltype" != "$REGISTRY_PARENT_TYPE" ]; then
                echo "ERROR: ${file}:${lno}: default_instance is only valid on a '$REGISTRY_PARENT_TYPE' line ('$lname' is '$ltype')" >&2
                rc=2; continue
            fi
            if [ "$(_registry_parent_in_lines "$ref" ${lines[@]+"${lines[@]}"})" != "$lname" ]; then
                echo "ERROR: ${file}:${lno}: default_instance '$ref' is not an instance of '$lname'" >&2
                rc=2; continue
            fi
        fi
        printf '%s\t%s\t%s\t%s\n' "$lname" "$ltype" "$lpath" "$lfields"
    done
    return $rc
}

# Lexically normalize an absolute path: collapse '//', drop '.', resolve
# '..' against the preceding segment. No filesystem access, so the answer
# does not depend on what exists yet (a ros2_colcon hosting dir may not).
_registry_normpath() {
    local -a in out=()
    local seg
    IFS='/' read -r -a in <<< "$1"
    for seg in ${in[@]+"${in[@]}"}; do
        case "$seg" in
            ''|'.') ;;
            '..') [ "${#out[@]}" -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
            *) out+=("$seg") ;;
        esac
    done
    local joined=""
    for seg in ${out[@]+"${out[@]}"}; do joined="$joined/$seg"; done
    echo "${joined:-/}"
}

# True when <path> equals <base> or lies beneath it (both absolute; both
# normalized first so '..' segments cannot escape the check).
_registry_path_under() {
    local p b
    p="$(_registry_normpath "$1")"
    b="$(_registry_normpath "$2")"
    [ "$p" = "$b" ] || [[ "$p" == "$b/"* ]]
}

# Value of <key> in a space-separated "k=v k=v" list, or empty.
_registry_field_of() {
    local fields="$1" key="$2" f
    local -a arr=()
    read -r -a arr <<< "$fields"   # array, never word-splitting-with-globbing
    for f in ${arr[@]+"${arr[@]}"}; do
        [ "${f%%=*}" = "$key" ] && { echo "${f#*=}"; return 0; }
    done
    return 1
}

# Type of <name> among parsed lines (lineno\tname\ttype\tpath\tfields), or empty.
_registry_type_in_lines() {
    local want="$1" l lno lname ltype rest
    shift
    for l in "$@"; do
        IFS=$'\t' read -r lno lname ltype rest <<< "$l"
        [ "$lname" = "$want" ] && { echo "$ltype"; return 0; }
    done
    return 1
}

# parent= of <name> among parsed lines, or empty.
_registry_parent_in_lines() {
    local want="$1" l lno lname ltype lpath lfields
    shift
    for l in "$@"; do
        IFS=$'\t' read -r lno lname ltype lpath lfields <<< "$l"
        [ "$lname" = "$want" ] && { _registry_field_of "$lfields" parent; return 0; }
    done
    return 1
}

# Parse the registry and print one entry per line as:
#   <name>\t<type>\t<abs_path>
# (the three-column form every pre-#265 consumer reads). Return codes
# follow registry_entries_full.
# Usage: entries=$(registry_entries "$root") || { ...parse error... }
registry_entries() {
    local root="$1" full rc=0
    full="$(registry_entries_full "$root")" || rc=$?
    [ -n "$full" ] && cut -f1-3 <<< "$full"
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

# Print the value of trailing field <key> for project <name>.
# Return 1 if the project has no such field (or is not registered),
# 2 on registry parse errors.
# Usage: v=$(registry_field "$root" "$name" distro)
registry_field() {
    local root="$1" want="$2" key="$3" entries name type path fields
    entries="$(registry_entries_full "$root")" || return 2
    while IFS=$'\t' read -r name type path fields; do
        [ -z "$name" ] && continue
        if [ "$name" = "$want" ]; then
            _registry_field_of "$fields" "$key"
            return $?
        fi
    done <<< "$entries"
    return 1
}

# Print the names of the instances of parent root <parent>, one per line.
# Return codes follow registry_entries_full.
# Usage: names=$(registry_instances "$root" "$parent")
registry_instances() {
    local root="$1" parent="$2" entries name type path fields rc=0
    entries="$(registry_entries_full "$root")" || rc=$?
    [ -z "$entries" ] && return $rc
    while IFS=$'\t' read -r name type path fields; do
        [ -z "$name" ] && continue
        [ "$(_registry_field_of "$fields" parent)" = "$parent" ] && echo "$name"
    done <<< "$entries"
    return $rc
}

# Resolve a parent root to the instance to operate on: its
# default_instance if set, else its only instance. Prints the instance
# name. With several instances and no default, lists them on stderr and
# returns 1. Return 2 on registry parse errors. A non-parent name is
# printed back unchanged (return 0), so callers can apply this to any
# selected project.
# Usage: inst=$(registry_default_instance "$root" "$name")
registry_default_instance() {
    local root="$1" name="$2" entry type dflt instances count
    entry="$(registry_lookup "$root" "$name")" || return $?
    type="$(cut -f1 <<< "$entry")"
    if [ "$type" != "$REGISTRY_PARENT_TYPE" ]; then
        echo "$name"
        return 0
    fi
    dflt="$(registry_field "$root" "$name" default_instance 2>/dev/null || true)"
    if [ -n "$dflt" ]; then
        echo "$dflt"
        return 0
    fi
    instances="$(registry_instances "$root" "$name")" || return 2
    count=0
    [ -n "$instances" ] && count="$(wc -l <<< "$instances")"
    if [ "$count" -eq 1 ]; then
        echo "$instances"
        return 0
    fi
    if [ "$count" -eq 0 ]; then
        echo "ERROR: parent root '$name' has no instances registered" >&2
        return 1
    fi
    echo "ERROR: '$name' is a parent root with several instances; select one with --project:" >&2
    local inst
    while IFS= read -r inst; do
        [ -n "$inst" ] && echo "  --project $inst" >&2
    done <<< "$instances"
    echo "(or set default_instance=<name> on the '$name' line in $(registry_file "$root"))" >&2
    return 1
}

# Resolve a --project argument the way every worktree script must (#265):
# a registered parent root becomes its default/only instance (or an error
# listing the instances); any other name — registered or not — is printed
# back unchanged so legacy callers keep working. Return 1 on an ambiguous
# parent, 2 on registry parse errors.
# Usage: name=$(registry_resolve_project_arg "$root" "$arg") || exit 1
registry_resolve_project_arg() {
    local root="$1" arg="$2" entry rc=0
    entry="$(registry_lookup "$root" "$arg")" || rc=$?
    [ "$rc" -eq 2 ] && return 2
    if [ "$rc" -eq 1 ]; then
        echo "$arg"
        return 0
    fi
    if [ "$(cut -f1 <<< "$entry")" = "$REGISTRY_PARENT_TYPE" ]; then
        registry_default_instance "$root" "$arg"
        return $?
    fi
    echo "$arg"
}

# Print the directory a root's worktrees live in: its worktrees= field,
# else <hosting_dir>/worktrees. Transition rule (#265, until the legacy
# project/ shape is removed): a name that is not registered maps to the
# pre-#265 location <root>/worktrees/project/<name>, so unregistered
# legacy projects keep working mid-rollout. The name is validated like a
# registry name (no '/', no '..') so the fallback can never leave the
# workspace. Return 1 on an invalid name, 2 on parse errors.
# Usage: dir=$(registry_worktree_dir "$root" "$name")
registry_worktree_dir() {
    local root="$1" name="$2" entries ename etype epath efields override
    if ! [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || [[ "$name" == *..* ]]; then
        echo "ERROR: invalid project name '$name'" >&2
        return 1
    fi
    entries="$(registry_entries_full "$root")" || return 2
    while IFS=$'\t' read -r ename etype epath efields; do
        [ -z "$ename" ] && continue
        if [ "$ename" = "$name" ]; then
            override="$(_registry_field_of "$efields" worktrees)" || true
            if [ -n "$override" ]; then
                echo "$override"
            else
                echo "$epath/worktrees"
            fi
            return 0
        fi
    done <<< "$entries"
    echo "$root/worktrees/project/$name"
    return 0
}

# Resolve the project owning a directory: the registry entry whose hosting
# dir is the directory itself or an ancestor of it. Longest match wins,
# so a cwd inside an instance resolves to the instance, not its parent.
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

# Guard for scripts that may be invoked from anywhere (the user-tier
# allow-list, #265): succeed only when <dir> (default $PWD) is inside the
# workspace checkout itself or inside a registered root. Otherwise print
# a one-line reason on stderr and return 1 (2 on registry parse errors).
# Callers must invoke this before any repo-affecting action.
# Usage: registry_require_root "$root" || exit 1
registry_require_root() {
    local root="$1" dir="${2:-$PWD}" abs wsabs rc=0
    abs="$(cd "$dir" 2>/dev/null && pwd -P)" || {
        echo "ERROR: $dir is not a directory" >&2
        return 1
    }
    wsabs="$(cd "$root" 2>/dev/null && pwd -P)" || return 1
    if [ "$abs" = "$wsabs" ] || [[ "$abs" == "$wsabs/"* ]]; then
        return 0
    fi
    registry_resolve_from_dir "$root" "$abs" >/dev/null || rc=$?
    [ "$rc" -eq 0 ] && return 0
    [ "$rc" -eq 2 ] && return 2
    echo "ERROR: refusing to run: $abs is neither inside the workspace ($wsabs) nor under a registered project root ($(registry_file "$root"))" >&2
    return 1
}
