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
#   boat_sim            single_project  /home/me/src/boat_sim
#   shore_tools         project         /home/me/shore_tools   default_instance=shore_tools-rolling
#   shore_tools-jazzy   ros2_colcon     /home/me/shore_tools/jazzy    parent=shore_tools distro=jazzy
#   shore_tools-rolling ros2_colcon     /home/me/shore_tools/rolling  parent=shore_tools distro=rolling
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
# Per-project settings file (issue #332): .agent/projects.d/<name> (no
# extension; gitignored, per machine). The registry line stays the index;
# the file holds the project's own settings, one key=value per line:
#
#   build=./scripts/build.sh
#   test=make test
#   instructions=none
#
# - split at the first '='; blank lines and lines whose first non-blank
#   character is '#' are ignored (no trailing comments: a command may
#   contain '#'); surrounding blanks and a trailing CR are stripped.
# - an unknown key, a duplicate key, an empty value or a line with no '='
#   is an error naming the file, the line and the known keys. A malformed
#   file stops the adapter dispatcher and `validate`; it never resolves.
# - keys (everything else stays in the legacy projects.d/<name>.sh):
#     build, test, install  a command, or 'none' (a recorded "this project
#                           has none"). The value is split on blanks into
#                           argv and run without a shell, from the project
#                           root, with no globbing. Quotes, & | ; < > $ ( )
#                           ` and backslash are refused: anything that needs
#                           them is a script, so point the key at one
#                           (build=./scripts/build.sh, or an absolute path).
#     bootstrap_url         http(s):// or file:// URL of a ros2_colcon
#                           bootstrap.yaml (replaces MANIFEST_BOOTSTRAP_URL)
#     location              project | outside       where the loop's records
#     location_path         absolute path           (work plans, progress
#     tracking              project | untracked | repo   timelines) live
#     instructions          none | tracked          may the workspace offer
#                           agent instructions in tracked project files
# - records combinations (docs/design.md, Worktrees Target): valid are
#   (project, project), (project, untracked), (outside, untracked),
#   (outside, repo); refused are (outside, project), (project, repo),
#   location_path without location=outside, and location=outside without
#   tracking. An absent pair is (project, project). Every default and the
#   outside layout come from project_records_default, and are provisional.
#   Only (project, project) is honoured until the records lookup (#393)
#   lands, so project_file_set refuses to store any other combination.
# - a records repository must not be a workspace: project_records_check
#   refuses tracking=repo when the records clone is the workspace or a copy
#   of it (remote URL, local-path remote, or the workspace marker files).
# - precedence for build/test/install/bootstrap_url: this file, key by key;
#   for a key it leaves unset, the legacy .agent/projects.d/<name>.sh
#   variable when that file exists (it is then the whole legacy layer, as
#   before #332), otherwise the shared .agent/project_config.sh (the
#   dispatcher and the adapters).
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
        # Project 'x.sh' would own the file .agent/projects.d/x.sh, which is
        # project 'x''s legacy command config (issue #332).
        if [[ "$name" == *.sh ]]; then
            echo "ERROR: ${file}:${lineno}: invalid project name '$name': a name may not end in '.sh' (its settings file would collide with the legacy .agent/projects.d/<name>.sh of project '${name%.sh}')" >&2
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

# Resolve the root a SESSION in <dir> belongs to (ADR-0018 decision 6):
# registry_resolve_from_dir, else the entry whose worktrees= directory
# contains <dir> -- that directory may lie outside the hosting dir (under
# the workspace's worktrees/project/, say), and a session in one of its
# worktrees is still that root's. Longest worktrees= match wins.
# Prints "<name>\t<type>\t<abs_path>" (the hosting dir, as registered).
# Return 1 if no entry owns <dir>, 2 on registry parse errors.
# Usage: entry=$(registry_resolve_session_dir "$root" "$dir")
registry_resolve_session_dir() {
    local root="$1" dir="$2" out rc=0 abs entries name type path fields wt wabs
    local best="" best_len=0
    out="$(registry_resolve_from_dir "$root" "$dir")" || rc=$?
    if [ "$rc" -eq 0 ]; then
        printf '%s\n' "$out"
        return 0
    fi
    [ "$rc" -eq 2 ] && return 2
    abs="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
    entries="$(registry_entries_full "$root")" || return 2
    while IFS=$'\t' read -r name type path fields; do
        [ -z "$name" ] && continue
        wt="$(_registry_field_of "$fields" worktrees)" || continue
        wabs="$(cd "$wt" 2>/dev/null && pwd -P)" || continue
        if [ "$abs" = "$wabs" ] || [[ "$abs" == "$wabs/"* ]]; then
            if [ "${#wabs}" -gt "$best_len" ]; then
                best="$(printf '%s\t%s\t%s' "$name" "$type" "$path")"
                best_len=${#wabs}
            fi
        fi
    done <<< "$entries"
    [ -n "$best" ] || return 1
    printf '%s\n' "$best"
}

# Derive the worktree type (and project name) a directory implies (#317,
# #265 PR 3), for scripts whose --type is optional when the cwd already
# says which checkout you are in.
# Prints "<type>\t<project>": "project\t<name>" when <dir> is under a
# registered project root (longest-prefix match, so an instance beats its
# parent), or "workspace\t" when it is inside the workspace checkout.
# Registered roots are checked FIRST: a project registered inside the
# workspace tree is still a project.
# Return 1 when the directory implies neither, 2 on registry parse errors.
# Callers must let an explicit --type/--project win over this.
# Usage: derived=$(registry_derive_type_from_dir "$root" "$PWD")
registry_derive_type_from_dir() {
    local root="$1" dir="${2:-$PWD}" abs wsabs entry rc=0
    abs="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
    entry="$(registry_resolve_from_dir "$root" "$abs")" || rc=$?
    [ "$rc" -eq 2 ] && return 2
    if [ "$rc" -eq 0 ] && [ -n "$entry" ]; then
        printf 'project\t%s\n' "${entry%%$'\t'*}"
        return 0
    fi
    wsabs="$(cd "$root" 2>/dev/null && pwd -P)" || return 1
    if [ "$abs" = "$wsabs" ] || [[ "$abs" == "$wsabs/"* ]]; then
        printf 'workspace\t\n'
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

# ------------------------------------------- per-project settings (#332) ---
# The file .agent/projects.d/<name>; grammar and keys in the header above.

# Keys the per-project file accepts.
_PROJECT_FILE_KEYS=" build test install bootstrap_url location location_path tracking instructions "
# The records keys, which are set and validated together.
_PROJECT_RECORDS_KEYS=" location location_path tracking "
# Characters refused in a command value: anything that needs them is a script.
_PROJECT_FILE_CMD_REFUSED=$'\'"`$&|;<>()\\'
# The issue that builds the records lookup; until it lands only the default
# records combination is honoured, so it is cited by every refusal.
# shellcheck disable=SC2034
PROJECT_RECORDS_LOOKUP_ISSUE="#393"
# The workspace's own plugin name, one of its marker files' contents.
_WORKSPACE_PLUGIN_NAME="agent-workspace"

# Is $1 exactly one of the words in the space-separated list $2? A whole-word
# comparison, never a substring test: "build test" or "location
# location_path" must not pass as a key because it appears inside the list.
# Usage: _project_file_key_in "$key" "$_PROJECT_FILE_KEYS"
_project_file_key_in() {
    local want="$1" k
    local -a list
    [ -n "$want" ] || return 1
    read -r -a list <<< "$2"
    for k in "${list[@]}"; do
        [ "$k" = "$want" ] && return 0
    done
    return 1
}

# Print the per-project settings file path.
# Usage: file=$(project_file_path "$root" "$name")
project_file_path() {
    echo "$1/.agent/projects.d/$2"
}

# Strip leading and trailing blanks (spaces and tabs) from $1.
_project_file_trim() {
    local s="$1"
    s="${s#"${s%%[![:blank:]]*}"}"
    s="${s%"${s##*[![:blank:]]}"}"
    printf '%s' "$s"
}

# Check one value against its key's type. Prints the reason and returns 1
# when the value is invalid.
_project_file_value_error() {
    local key="$1" value="$2" i c
    case "$key" in
        build|test|install)
            [ "$value" = "none" ] && return 0
            for ((i = 0; i < ${#_PROJECT_FILE_CMD_REFUSED}; i++)); do
                c="${_PROJECT_FILE_CMD_REFUSED:i:1}"
                if [[ "$value" == *"$c"* ]]; then
                    echo "'$key' contains '$c': a command here is split on blanks and run without a shell, so quotes, & | ; < > \$ ( ) \` and backslash are refused; point the key at a script instead ($key=./scripts/$key.sh, relative to the project root, or an absolute path)"
                    return 1
                fi
            done
            ;;
        bootstrap_url)
            if ! [[ "$value" =~ ^(https?|file)://[^[:space:]]+$ ]]; then
                echo "bootstrap_url must be an http://, https:// or file:// URL with no blanks, got '$value'"
                return 1
            fi
            ;;
        location)
            case "$value" in project|outside) ;; *) echo "location must be 'project' or 'outside', got '$value'"; return 1 ;; esac
            ;;
        location_path)
            if [[ "$value" != /* ]]; then
                echo "location_path must be an absolute path, got '$value'"
                return 1
            fi
            if [[ "$value" == *[[:cntrl:]]* ]]; then
                echo "location_path must not contain control characters (tabs included)"
                return 1
            fi
            ;;
        tracking)
            case "$value" in project|untracked|repo) ;; *) echo "tracking must be 'project', 'untracked' or 'repo', got '$value'"; return 1 ;; esac
            ;;
        instructions)
            case "$value" in none|tracked) ;; *) echo "instructions must be 'none' or 'tracked', got '$value'"; return 1 ;; esac
            ;;
    esac
    return 0
}

# Value of <key> in parsed entries ("key<TAB>value" lines), or return 1.
_project_file_value_of() {
    local entries="$1" want="$2" k v
    while IFS=$'\t' read -r k v; do
        [ "$k" = "$want" ] && { printf '%s\n' "$v"; return 0; }
    done <<< "$entries"
    return 1
}

# The default records combination and outside-path layout. THE ONE PLACE a
# records default lives (#332): the validator, the audit and the records
# lookup (#393) call it; nothing else writes a default or a layout.
#
# PROVISIONAL (owner, 2026-10-13: where the defaults should be "is not
# settled even in my mind"). They are chosen when the records lookup is
# built and may be revised after the first real onboarding; changing them
# touches this function and its test only.
#
# Modes: accepts-footprint (the default) is what an absent location/
# tracking pair resolves to, for every file: (project, project), the
# Target's default and what every reader does today. zero-footprint only
# feeds onboarding's proposal; nothing stored says a project is
# zero-footprint, so it never resolves a file.
#
# Prints "<location>\t<tracking>\t<outside_layout>\tprovisional", where
# <outside_layout> is the location_path used when location=outside omits
# it: provisionally the sibling "<clone>-records" of the project clone
# (empty when <name> is not given or not registered).
# Usage: project_records_default "$root" "$name" [accepts-footprint|zero-footprint]
project_records_default() {
    local root="${1:-}" name="${2:-}" mode="${3:-accepts-footprint}" entry clone="" layout=""
    if [ -n "$root" ] && [ -n "$name" ]; then
        entry="$(registry_lookup "$root" "$name" 2>/dev/null)" && clone="$(cut -f2 <<< "$entry")"
    fi
    [ -n "$clone" ] && layout="$(dirname "$clone")/$(basename "$clone")-records"
    case "$mode" in
        accepts-footprint) printf 'project\tproject\t%s\tprovisional\n' "$layout" ;;
        zero-footprint)    printf 'outside\tuntracked\t%s\tprovisional\n' "$layout" ;;
        *) echo "ERROR: project_records_default: unknown mode '$mode' (accepts-footprint|zero-footprint)" >&2; return 1 ;;
    esac
}

# Resolve the records combination from raw key values (empty = absent).
# Prints "<location>\t<tracking>" or, for a refused combination, the
# reason (return 1). Pure: no filesystem access.
_project_records_combination() {
    local loc="$1" lpath="$2" track="$3" dflt dloc dtrack
    if [ -n "$lpath" ] && [ "$loc" != "outside" ]; then
        echo "location_path is only valid with location=outside"
        return 1
    fi
    if [ "$loc" = "outside" ] && [ -z "$track" ]; then
        echo "location=outside needs tracking=untracked or tracking=repo"
        return 1
    fi
    dflt="$(project_records_default "" "" accepts-footprint)"
    IFS=$'\t' read -r dloc dtrack _ <<< "$dflt"
    [ -z "$loc" ] && loc="$dloc"
    [ -z "$track" ] && track="$dtrack"
    case "$loc/$track" in
        project/project|project/untracked|outside/untracked|outside/repo)
            printf '%s\t%s\n' "$loc" "$track"
            ;;
        outside/project)
            echo "location=outside with tracking=project is refused: records outside the project cannot be committed in it (use tracking=untracked or tracking=repo)"
            return 1
            ;;
        project/repo)
            echo "tracking=repo is refused with location=project: a records repository is a separate clone, so it needs location=outside"
            return 1
            ;;
        *)
            echo "records combination location=$loc tracking=$track is not valid"
            return 1
            ;;
    esac
}

# Parse a settings file. Prints "key<TAB>value" per setting. A missing
# file prints nothing and returns 0 (every setting at its default). Any
# error (line grammar, unknown or duplicate key, empty or ill-typed value,
# refused records combination) is reported on stderr naming the file and
# line, nothing is printed, and the return is 2: a malformed file never
# resolves.
_project_file_parse() {
    local file="$1" raw line key value lineno=0 rc=0 seen=" " reason known
    local -a out=()
    [ -e "$file" ] || return 0
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        echo "ERROR: $file: not a readable file" >&2
        return 2
    fi
    known="${_PROJECT_FILE_KEYS# }"; known="${known% }"
    while IFS= read -r raw || [ -n "$raw" ]; do
        lineno=$((lineno + 1))
        line="$(_project_file_trim "${raw%$'\r'}")"
        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue
        if [[ "$line" != *=* ]]; then
            echo "ERROR: ${file}:${lineno}: expected key=value, got '$line' (known keys: $known)" >&2
            rc=2; continue
        fi
        key="$(_project_file_trim "${line%%=*}")"
        value="$(_project_file_trim "${line#*=}")"
        if ! _project_file_key_in "$key" "$_PROJECT_FILE_KEYS"; then
            echo "ERROR: ${file}:${lineno}: unknown key '$key' (known keys: $known)" >&2
            rc=2; continue
        fi
        if [[ "$seen" == *" $key "* ]]; then
            echo "ERROR: ${file}:${lineno}: duplicate key '$key'" >&2
            rc=2; continue
        fi
        seen="$seen$key "
        if [ -z "$value" ]; then
            echo "ERROR: ${file}:${lineno}: empty value for '$key' (remove the line to use the default; build, test and install take 'none' for a recorded \"this project has none\")" >&2
            rc=2; continue
        fi
        if ! reason="$(_project_file_value_error "$key" "$value")"; then
            echo "ERROR: ${file}:${lineno}: $reason" >&2
            rc=2; continue
        fi
        out+=("$key"$'\t'"$value")
    done < "$file"
    [ "$rc" -eq 0 ] || return 2
    local entries="" loc lpath track
    [ "${#out[@]}" -gt 0 ] && entries="$(printf '%s\n' "${out[@]}")"
    loc="$(_project_file_value_of "$entries" location)" || loc=""
    lpath="$(_project_file_value_of "$entries" location_path)" || lpath=""
    track="$(_project_file_value_of "$entries" tracking)" || track=""
    if ! reason="$(_project_records_combination "$loc" "$lpath" "$track")"; then
        echo "ERROR: ${file}: $reason" >&2
        return 2
    fi
    [ -n "$entries" ] && printf '%s\n' "$entries"
    return 0
}

# Parse project <name>'s settings file (see _project_file_parse).
# Usage: entries=$(project_file_entries "$root" "$name") || { ...invalid... }
project_file_entries() {
    _project_file_parse "$(project_file_path "$1" "$2")"
}

# Print the stored value of <key> for project <name>. Return 1 when the key
# is not set (or there is no file), 2 when the file is invalid.
# Usage: v=$(project_file_get "$root" "$name" build)
project_file_get() {
    local entries
    entries="$(project_file_entries "$1" "$2")" || return 2
    _project_file_value_of "$entries" "$3"
}

# Git common dir of the repository at or above <dir>, absolute and
# symlink-resolved. Return 1 when <dir> is in no repository.
_records_git_common_dir() {
    local common
    common="$(git -C "$1" rev-parse --git-common-dir 2>/dev/null)" || return 1
    (cd "$1" 2>/dev/null && cd "$common" 2>/dev/null && pwd -P)
}

# The local path a remote URL names, resolved against <top> when relative;
# return 1 for a network URL (scheme://host/..., or scp form host:path).
# Git's own rule: "://" makes a URL; else a ':' before the first '/' is scp
# form; else it is a path.
_records_local_remote_path() {
    local top="$1" url="$2" head
    case "$url" in
        file://*) url="${url#file://}"; url="${url#localhost}"; printf '%s\n' "$url"; return 0 ;;
        *://*) return 1 ;;
    esac
    head="${url%%/*}"
    [[ "$head" == *:* ]] && return 1
    # shellcheck disable=SC2088  # a literal "~/" prefix is what we look for
    if [ "${url:0:2}" = '~/' ]; then
        printf '%s\n' "$HOME/${url:2}"
        return 0
    fi
    case "$url" in
        /*) printf '%s\n' "$url" ;;
        *) printf '%s\n' "$top/$url" ;;
    esac
}

# Normalise a network remote URL to "host/owner/repo" (lowercase; scheme,
# user, port, trailing '/' and '.git' dropped) so https, ssh and scp forms
# of one repository compare equal.
_records_norm_url() {
    local u="${1,,}"
    u="${u%/}"; u="${u%.git}"; u="${u%/}"
    if [[ "$u" =~ ^[a-z][a-z0-9+.-]*://([^/@]*@)?([^/:]+)(:[0-9]*)?/+(.*)$ ]]; then
        printf '%s/%s\n' "${BASH_REMATCH[2]}" "${BASH_REMATCH[4]}"
    elif [[ "$u" =~ ^([^@/:]+@)?([^/:]+):/*(.*)$ ]]; then
        printf '%s/%s\n' "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    else
        printf '%s\n' "$u"
    fi
}

# Print which workspace marker a repository carries (working tree or HEAD),
# or return 1. The markers: .agent/user_tier_scripts.txt, and
# .claude-plugin/plugin.json naming the workspace's plugin.
_records_workspace_marker() {
    local top="$1" plugin_re
    plugin_re="\"name\"[[:space:]]*:[[:space:]]*\"${_WORKSPACE_PLUGIN_NAME}\""
    if [ -f "$top/.agent/user_tier_scripts.txt" ]; then
        echo ".agent/user_tier_scripts.txt"; return 0
    fi
    if [ -f "$top/.claude-plugin/plugin.json" ] && grep -Eq "$plugin_re" "$top/.claude-plugin/plugin.json" 2>/dev/null; then
        echo ".claude-plugin/plugin.json (plugin '$_WORKSPACE_PLUGIN_NAME')"; return 0
    fi
    if git -C "$top" cat-file -e HEAD:.agent/user_tier_scripts.txt 2>/dev/null; then
        echo ".agent/user_tier_scripts.txt (in its HEAD commit)"; return 0
    fi
    if git -C "$top" show HEAD:.claude-plugin/plugin.json 2>/dev/null | grep -Eq "$plugin_re"; then
        echo ".claude-plugin/plugin.json (plugin '$_WORKSPACE_PLUGIN_NAME', in its HEAD commit)"; return 0
    fi
    return 1
}

# Is the repository holding records directory <dir> the workspace, or a
# copy of it? A records repository must not be a workspace (owner,
# 2026-10-13: a fork would carry other projects' records, and a pull
# request sent back would bring them past the merge gate's bookkeeping
# exemption). Prints the reason and returns 0 when it is; returns 1 when it
# is not; returns 3 when it cannot tell yet (no repository at <dir>).
# Checks: the same repository as the workspace checkout (any worktree);
# the workspace's marker files (contents, so a clone of a fork under any
# owner is caught offline); a local-path or file:// remote at the
# workspace checkout or one of its worktrees; a network remote equal to
# one of the workspace's.
_records_repo_workspace_reason() {
    local root="$1" dir="$2" top ws_common rec_common marker r url lpath lcommon norm wurl wnorm
    [ -d "$dir" ] || return 3
    top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 3
    ws_common="$(_records_git_common_dir "$root")" || ws_common=""
    rec_common="$(_records_git_common_dir "$top")" || rec_common=""
    if [ -n "$ws_common" ] && [ "$rec_common" = "$ws_common" ]; then
        echo "$dir is in the workspace's own repository ($top)"
        return 0
    fi
    if marker="$(_records_workspace_marker "$top")"; then
        echo "the repository at $top contains the workspace marker $marker: it is a copy of the workspace"
        return 0
    fi
    while IFS= read -r r; do
        [ -n "$r" ] || continue
        url="$(git -C "$top" remote get-url "$r" 2>/dev/null)" || continue
        if lpath="$(_records_local_remote_path "$top" "$url")"; then
            lcommon="$(_records_git_common_dir "$lpath")" || continue
            if [ -n "$ws_common" ] && [ "$lcommon" = "$ws_common" ]; then
                echo "its remote '$r' ($url) is the workspace checkout or one of its worktrees"
                return 0
            fi
            continue
        fi
        norm="$(_records_norm_url "$url")"
        while IFS= read -r wurl; do
            [ -n "$wurl" ] || continue
            wnorm="$(_records_norm_url "$(git -C "$root" remote get-url "$wurl" 2>/dev/null)")"
            if [ -n "$wnorm" ] && [ "$norm" = "$wnorm" ]; then
                echo "its remote '$r' ($url) is the workspace's remote '$wurl'"
                return 0
            fi
        done < <(git -C "$root" remote 2>/dev/null)
    done < <(git -C "$top" remote 2>/dev/null)
    return 1
}

# Check parsed settings <entries> of project <name> (hosting dir <clone>):
# resolve the records combination with its defaults and refuse a records
# repository that is a workspace. Prints
#   "<location>\t<tracking>\t<location_path>"   (location_path empty for
#                                                location=project)
# on stdout and notes on stderr. Return 0 when valid and honoured today
# (the default combination), 3 when valid but not yet honoured (#393), 2
# when refused.
_project_records_check_entries() {
    local root="$1" name="$2" entries="$3" loc lpath track combo dflt layout reason rc
    loc="$(_project_file_value_of "$entries" location)" || loc=""
    lpath="$(_project_file_value_of "$entries" location_path)" || lpath=""
    track="$(_project_file_value_of "$entries" tracking)" || track=""
    if ! combo="$(_project_records_combination "$loc" "$lpath" "$track")"; then
        echo "ERROR: project '$name': $combo" >&2
        return 2
    fi
    IFS=$'\t' read -r loc track <<< "$combo"
    if [ "$loc" = "outside" ] && [ -z "$lpath" ]; then
        dflt="$(project_records_default "$root" "$name" accepts-footprint)"
        IFS=$'\t' read -r _ _ layout _ <<< "$dflt"
        lpath="$layout"
        if [ -z "$lpath" ]; then
            echo "ERROR: project '$name': location=outside without location_path, and no default layout (the project is not registered)" >&2
            return 2
        fi
        echo "NOTE: project '$name': location_path is the provisional default $lpath (project_records_default)" >&2
    fi
    if [ "$track" = "repo" ]; then
        rc=0
        reason="$(_records_repo_workspace_reason "$root" "$lpath")" || rc=$?
        if [ "$rc" -eq 0 ]; then
            echo "ERROR: project '$name': a records repository must not be a workspace: $reason. Use a separate records repository, or tracking=untracked for records kept on this machine only" >&2
            return 2
        fi
        if [ "$rc" -eq 3 ]; then
            echo "NOTE: project '$name': records repository $lpath is unverifiable until cloned (no git repository there yet)" >&2
        fi
    fi
    printf '%s\t%s\t%s\n' "$loc" "$track" "$lpath"
    if [ "$loc/$track" != "project/project" ]; then
        echo "WARNING: project '$name': records location=$loc tracking=$track is valid but not yet honoured: until the records lookup lands ($PROJECT_RECORDS_LOOKUP_ISSUE) every reader and writer still builds <worktree>/.agent/work-plans/issue-N/" >&2
        return 3
    fi
    return 0
}

# Validate project <name>'s settings file and check its records settings
# (see _project_records_check_entries for output and return codes; 2 also
# covers a malformed file).
# Usage: project_records_check "$root" "$name"
project_records_check() {
    local entries
    entries="$(project_file_entries "$1" "$2")" || return 2
    _project_records_check_entries "$1" "$2" "$entries"
}

# The one writer for .agent/projects.d/<name>. Arguments are 'key=value'
# (set) or '-key' (remove). The result is validated as a whole file before
# an atomic rename; comment lines and the order of untouched lines are
# kept. Refuses: an unregistered name, a parent root (settings belong to
# its instances), and, until the records lookup lands (#393), a write that
# touches the records keys and leaves any combination other than the
# default (project, project). Prints "unchanged <file>" or "updated
# <file>". Return 0 on success, 1 when refused, 2 when the result would be
# an invalid file (the existing file is left as it was). An existing file
# keeps its mode (a new one is 644), and a symlinked file stays a link:
# its target is rewritten in place of the link, and emptied rather than
# removed when nothing is left.
# Usage: project_file_set "$root" "$name" build=./b.sh -install
project_file_set() {
    local root="$1" name="$2" entry ptype file dest dir tmp arg key value i found line lkey
    local touches_records=0 reason entries rc=0 combo loc track lpath mode
    local -a keys=() vals=() done_k=()
    shift 2
    if [ $# -eq 0 ]; then
        echo "ERROR: project_file_set: nothing to set" >&2
        return 1
    fi
    entry="$(registry_lookup "$root" "$name")" || rc=$?
    if [ "$rc" -eq 2 ]; then
        echo "ERROR: the registry $(registry_file "$root") has errors; fix it first" >&2
        return 1
    fi
    if [ "$rc" -ne 0 ]; then
        echo "ERROR: project '$name' is not registered in $(registry_file "$root")" >&2
        return 1
    fi
    ptype="$(cut -f1 <<< "$entry")"
    if [ "$ptype" = "$REGISTRY_PARENT_TYPE" ]; then
        echo "ERROR: '$name' is a parent root (no adapter of its own); settings belong to its instances" >&2
        return 1
    fi
    for arg in "$@"; do
        if [[ "$arg" == -* ]]; then
            key="${arg#-}"; value=""
        elif [[ "$arg" == *=* ]]; then
            key="${arg%%=*}"; value="${arg#*=}"
            if [ -z "$value" ]; then
                echo "ERROR: empty value for '$key' (use '-$key' to remove it)" >&2
                return 1
            fi
        else
            echo "ERROR: expected key=value or -key, got '$arg'" >&2
            return 1
        fi
        if ! _project_file_key_in "$key" "$_PROJECT_FILE_KEYS"; then
            local known="${_PROJECT_FILE_KEYS# }"; known="${known% }"
            echo "ERROR: unknown key '$key' (known keys: $known)" >&2
            return 1
        fi
        if [[ "$value" == *$'\n'* ]] || [[ "$value" == *$'\r'* ]]; then
            echo "ERROR: the value for '$key' contains a line break" >&2
            return 1
        fi
        for ((i = 0; i < ${#keys[@]}; i++)); do
            if [ "${keys[$i]}" = "$key" ]; then
                echo "ERROR: '$key' given twice" >&2
                return 1
            fi
        done
        _project_file_key_in "$key" "$_PROJECT_RECORDS_KEYS" && touches_records=1
        keys+=("$key"); vals+=("$arg")
    done

    file="$(project_file_path "$root" "$name")"
    # The path the new contents are renamed onto: the file itself, or the
    # target of a symlinked one, so the rename never replaces the link.
    dest="$file"
    if [ -L "$file" ]; then
        if ! dest="$(readlink -f -- "$file" 2>/dev/null)" || [ -z "$dest" ]; then
            echo "ERROR: $file is a symlink whose target cannot be resolved" >&2
            return 1
        fi
        if [ -e "$dest" ] && [ ! -f "$dest" ]; then
            echo "ERROR: $file is a symlink to $dest, which is not a regular file" >&2
            return 1
        fi
    fi
    dir="$(dirname "$dest")"
    mkdir -p "$dir" || return 1
    tmp="$(mktemp "$dir/.${name}.XXXXXX")" || return 1
    {
        if [ -f "$file" ]; then
            while IFS= read -r line || [ -n "$line" ]; do
                line="${line%$'\r'}"
                lkey=""
                if [[ "$(_project_file_trim "$line")" != \#* ]] && [[ "$line" == *=* ]]; then
                    lkey="$(_project_file_trim "${line%%=*}")"
                fi
                found=-1
                for ((i = 0; i < ${#keys[@]}; i++)); do
                    [ -n "$lkey" ] && [ "${keys[$i]}" = "$lkey" ] && found=$i
                done
                if [ "$found" -lt 0 ]; then
                    printf '%s\n' "$line"
                elif [[ "${vals[$found]}" != -* ]] && [[ " ${done_k[*]-} " != *" $lkey "* ]]; then
                    printf '%s\n' "${vals[$found]}"
                    done_k+=("$lkey")
                fi
            done < "$file"
        fi
        for ((i = 0; i < ${#keys[@]}; i++)); do
            [[ "${vals[$i]}" == -* ]] && continue
            [[ " ${done_k[*]-} " == *" ${keys[$i]} "* ]] && continue
            printf '%s\n' "${vals[$i]}"
        done
    } > "$tmp"

    # Captures the parser's stderr only; its exit status is kept.
    if ! reason="$(_project_file_parse "$tmp" 2>&1 >/dev/null)"; then
        rm -f "$tmp"
        echo "ERROR: not writing $file: the result would be invalid:" >&2
        # Name the real file in the messages, not the temporary one.
        printf '%s\n' "${reason//$tmp/$file}" >&2
        return 2
    fi
    entries="$(_project_file_parse "$tmp")"
    if [ "$touches_records" -eq 1 ]; then
        loc="$(_project_file_value_of "$entries" location)" || loc=""
        lpath="$(_project_file_value_of "$entries" location_path)" || lpath=""
        track="$(_project_file_value_of "$entries" tracking)" || track=""
        combo="$(_project_records_combination "$loc" "$lpath" "$track")"
        IFS=$'\t' read -r loc track <<< "$combo"
        if [ "$loc/$track" != "project/project" ] || [ -n "$lpath" ]; then
            rm -f "$tmp"
            echo "ERROR: not storing records location=$loc tracking=$track${lpath:+ location_path=$lpath} for '$name': not honoured until the records lookup lands ($PROJECT_RECORDS_LOOKUP_ISSUE): every reader and writer still builds <worktree>/.agent/work-plans/issue-N/. Set or remove location, location_path and tracking together; only the default (project, project) is stored today" >&2
            return 1
        fi
    fi
    if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
        rm -f "$tmp"
        echo "unchanged $file"
        return 0
    fi
    if [ ! -s "$tmp" ] && [ ! -L "$file" ]; then
        # Nothing left: no file is the same as an empty one (every setting
        # at its default), so remove it rather than leave an empty file. A
        # symlinked file is emptied instead (below), so the link stays.
        rm -f "$tmp"
        if [ -f "$file" ]; then
            rm -f "$file" || return 1
            echo "removed $file"
        else
            echo "unchanged $file"
        fi
        return 0
    fi
    # Keep the existing file's mode (it may be 600 on purpose); a new file
    # is 644 (mktemp creates 600).
    mode=""
    if [ -f "$dest" ]; then
        mode="$(stat -c %a "$dest" 2>/dev/null || stat -f %Lp "$dest" 2>/dev/null)" || mode=""
    fi
    if ! chmod "${mode:-644}" "$tmp"; then
        rm -f "$tmp"
        echo "ERROR: could not set the mode of the new $file" >&2
        return 1
    fi
    mv -f "$tmp" "$dest" || { rm -f "$tmp"; return 1; }
    echo "updated $file"
}

# Remove keys from project <name>'s settings file (project_file_set with
# '-key' arguments). Usage: project_file_unset "$root" "$name" build test
project_file_unset() {
    local root="$1" name="$2" k
    local -a args=()
    shift 2
    for k in "$@"; do args+=("-$k"); done
    project_file_set "$root" "$name" ${args[@]+"${args[@]}"}
}
