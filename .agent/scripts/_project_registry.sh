#!/bin/bash
# .agent/scripts/_project_registry.sh
# Per-machine project registry helpers (issue #227 — #172 step 2; parent
# roots, trailing fields, worktree dirs and the root guard: issue #265).
#
# The registry lives at .agent/projects.local (gitignored). It maps a
# project name to a hosting directory and a project type, plus optional
# trailing key=value fields:
#
#   # <name>  <project_type>  <path>  [key=value ...]
#   boat_sim            single_project  /home/me/src/boat_sim
#   shore_tools         project         /home/me/shore_tools   default_instance=shore_tools-rolling
#   shore_tools-jazzy   ros2_colcon     /home/me/shore_tools/jazzy    parent=shore_tools distro=jazzy
#   shore_tools-rolling ros2_colcon     /home/me/shore_tools/rolling  parent=shore_tools distro=rolling
#
# - name: [A-Za-z0-9][A-Za-z0-9._-]* — also the worktree repo key
# - project_type: must have an adapter at .agent/project_types/<type>/,
#   except the pseudo-type "project": a parent root that groups instances
#   (session and memory unit, no adapter of its own)
# - path: the hosting dir, required (issue #265 part 4 retired the
#   projects/<name> default); relative paths resolve against the
#   workspace root. Paths must not contain spaces or '=' (a third token
#   containing '=' is read as a field, so such an entry has no path and is
#   a parse error).
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
# - keys (the only per-project settings; the old projects.d/<name>.sh and
#   the shared .agent/project_config.sh are no longer read, issue #265
#   part 4):
#     build, test, install  a command, or 'none' (a recorded "this project
#                           has none"). The value is split on blanks into
#                           argv and run without a shell, from the project
#                           root, with no globbing (* ? [ are literal).
#                           Quotes, & | ; < > $ ( ) ` and backslash are
#                           refused, and so is a first word VAR=value (no
#                           shell applies it) and any word starting with ~
#                           (no shell expands it): anything that needs them
#                           is a script, so point the key at one
#                           (build=./scripts/build.sh, or an absolute path).
#     bootstrap_url         http(s):// or file:// URL of a ros2_colcon
#                           bootstrap.yaml (replaces MANIFEST_BOOTSTRAP_URL)
#     source                where the project's source description lives
#                           (read by no route today: a ros2_colcon root
#                           without .repos-manifest/ that sets it is
#                           refused at use, naming the manifest tool's
#                           init and the unset; on the tool route validate
#                           names it as a second record; removing the
#                           three keys is a line of the workspace
#                           roadmap): an
#                           absolute path to the file, or a URL of a git
#                           repository that holds it, of one of two shapes:
#                           https://<host>[:port]/<path> (an ASCII host,
#                           no user name or password, no '?' or '#') or
#                           file:///<path>
#                           (not plain http://)
#     source_ref            branch, tag or commit of a URL source (not
#                           HEAD): required with a URL, refused with a path
#     source_path           the file's path inside that repository
#                           (relative; no '..', '.' or empty component, no
#                           trailing '/'; default manifest.yaml); refused
#                           with a path
#   source_ref and source_path are refused without source, and source is
#   refused beside bootstrap_url (one source only). Each refusal names the
#   one command that removes the three together (project_setting.sh unset
#   <name> source source_ref source_path), since set and unset judge the
#   whole resulting file: unsetting source alone, while source_ref stays,
#   is refused.
# - a key the project's type never reads is an error, at `set` and in the
#   parser (so a hand-written one fails check and stops the adapter): each
#   type lists such keys with the reason in
#   .agent/project_types/<type>/unused_settings (_project_type_unused_setting).
#   Today ros2_colcon lists build and test (colcon owns them; it reads
#   install), and single_project lists bootstrap_url, source, source_ref
#   and source_path.
# - a key a project of the type can never be registered with (the type
#   reads it, but its adapter refuses it) is refused by register_project.sh
#   --set before anything is written: each type lists such keys with the
#   reason, in the same grammar, in
#   .agent/project_types/<type>/registration_refused
#   (registration_refused_setting). Today ros2_colcon lists source,
#   source_ref and source_path; `project_setting.sh set` still accepts
#   them on a registered project.
#     location              project | outside       where the loop's records
#     location_path         absolute path           (work plans, progress
#     tracking              project | untracked | repo   timelines) live
#     instructions          none | tracked          may the workspace offer
#                           agent instructions in tracked project files
#     goals, design, roadmap  where the project keeps its goals, design and
#                           roadmap (issue #551): 'none' (a recorded "this
#                           project keeps none"), or a file inside the
#                           project as a path relative to its root, with no
#                           leading '/' or '~', no '..', '.' or empty
#                           component, no trailing '/', not a URL, and only
#                           ASCII letters, digits, '.', '_', '-' and '/' in
#                           the path (what every reader handles: the design
#                           citation scanner reads no other; any other
#                           character is refused, named); goals and design may add
#                           #<heading> (a section of the file), roadmap may
#                           not (its readers use the file's '## Direction'
#                           section, or the whole file), must end in .md
#                           and may not be README.md, AGENTS.md, CLAUDE.md,
#                           CODEX.md, docs/design.md or the design
#                           setting's file (the merge gate counts commits
#                           to it as bookkeeping). Read through
#                           project_document_path, which checks again that
#                           the file exists and does not resolve outside the
#                           root (and that a roadmap is no symbolic link,
#                           nor the design's file reached through one).
#                           Unset, a reader uses the first existing
#                           candidate: roadmap docs/roadmap.md,
#                           docs/ROADMAP.md, ROADMAP.md; design
#                           docs/design.md; goals none; a candidate that
#                           resolves outside the root is read as before,
#                           with a warning. A set key that is unusable stops
#                           the reader (exit 2); a registry or settings
#                           file unreadable for a reason outside the key
#                           gives a warning and the key's own line, or the
#                           candidates (fails open) -- except for a writer
#                           (PROJECT_DOC_STRICT=1), which does nothing when
#                           whether the key is set cannot be told. A part's documents
#                           are named only by the root roadmap's
#                           `| Sub-roadmap | Root |` table (ADR-0022), never
#                           here. Every type reads these keys.
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
# - build/test/install/bootstrap_url come from this file alone (issue #265
#   part 4 retired the legacy .agent/projects.d/<name>.sh and the shared
#   .agent/project_config.sh layers). project_command_source says whether
#   the file sets a command, without running it. The retired files are
#   still read, never for a value, only by the stale-shape report
#   (registry_stale_report), which names what is left in them to move.
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
# drop the offending line. An optional <file> parses that file as the
# registry of <root> (relative paths still resolve against <root>):
# register_project.sh checks a new registry before renaming it into place.
# Usage: entries=$(registry_entries_full "$root" [<file>]) || { ...parse error... }
registry_entries_full() {
    local root="$1" file lineno=0 rc=0
    local raw name type path rest field key value fields known
    local -a lines=()
    file="${2:-$(registry_file "$root")}"
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
        # project 'x''s legacy command config (issue #332). Any letter case:
        # on a case-insensitive filesystem (macOS by default) x.SH is x.sh.
        if [[ "$name" == *.[sS][hH] ]]; then
            echo "ERROR: ${file}:${lineno}: invalid project name '$name': a name may not end in '.sh', in any letter case (its settings file would collide with the legacy .agent/projects.d/<name>.sh of project '${name:0:${#name}-3}')" >&2
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
        if [ -z "$path" ]; then
            echo "ERROR: ${file}:${lineno}: '$name' has no path: a registry entry needs its hosting directory (register it with .agent/scripts/register_project"".sh <path>)" >&2
            rc=2
            continue
        fi
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
        # A worktrees= that is or holds the workspace root, or is, holds or
        # lies in the workspace's own worktrees/workspace, would make a
        # workspace worktree (or the workspace itself) count as that
        # project's, or a project worktree as a workspace one.
        if [ -n "$wt" ] && { _registry_path_under "$root" "$wt" || _registry_path_under "$root/worktrees/workspace" "$wt" || _registry_path_under "$wt" "$root/worktrees/workspace"; }; then
            echo "ERROR: ${file}:${lineno}: worktrees '$wt' for '$name' is or holds the workspace root, or is, holds or lies in its worktrees/workspace; a project's worktrees go in a folder of their own" >&2
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

# The sentence a script prints when nothing names a project: the cwd is
# under no registered root and no --project was given (issue #265 part 4:
# the project/ symlink and the projects/ default no longer stand in). It
# lists the registered names, so the caller can say which to pass. Printed
# on stdout without an "ERROR:" prefix; callers add their own and send it
# to stderr. A registry parse error still prints the sentence (the parse
# diagnostics go to stderr) and returns 2; otherwise returns 0. The
# registration script is named with the split-token idiom so the test
# selector does not read this message as a use of that script (the hub
# guard in test_script_tests_hook_scope.sh).
# Usage: echo "ERROR: $(registry_no_project_message "$root" "$PWD")" >&2
registry_no_project_message() {
    local root="$1" cwd="${2:-$PWD}" names rc=0 list
    names="$(registry_names "$root")" || rc=$?
    list="$(printf '%s' "$names" | tr '\n' ' ' | sed -e 's/ *$//' -e 's/ /, /g')"
    if [ -z "$list" ]; then
        echo "no registered project here (cwd $cwd), and none is registered. Register one: .agent/scripts/register_project"".sh <path>"
    else
        echo "no registered project here (cwd $cwd). Registered: $list. Pass --project <name> or register one: .agent/scripts/register_project"".sh <path>"
    fi
    return $rc
}

# The refusal for a name that is not registered (issue #265 part 4: an
# unregistered name no longer falls back to the retired
# worktrees/project/<name> location). On stderr.
_registry_not_registered() {
    local root="$1" name="$2" names list
    names="$(registry_names "$root" 2>/dev/null)" || true
    list="$(printf '%s' "$names" | tr '\n' ' ' | sed -e 's/ *$//' -e 's/ /, /g')"
    echo "ERROR: project '$name' is not registered (registered: ${list:-none}); register it: .agent/scripts/register_project"".sh <path>" >&2
}

# Resolve a --project argument the way every worktree script must (#265):
# a registered parent root becomes its default/only instance (or an error
# listing the instances); any other registered name is printed back. An
# unregistered name is refused (issue #265 part 4). Return 1 on an
# unregistered name or an ambiguous parent, 2 on registry parse errors.
# Usage: name=$(registry_resolve_project_arg "$root" "$arg") || exit 1
registry_resolve_project_arg() {
    local root="$1" arg="$2" entry rc=0
    entry="$(registry_lookup "$root" "$arg")" || rc=$?
    [ "$rc" -eq 2 ] && return 2
    if [ "$rc" -eq 1 ]; then
        _registry_not_registered "$root" "$arg"
        return 1
    fi
    if [ "$(cut -f1 <<< "$entry")" = "$REGISTRY_PARENT_TYPE" ]; then
        registry_default_instance "$root" "$arg"
        return $?
    fi
    echo "$arg"
}

# Print the directory a root's worktrees live in: its worktrees= field,
# else <hosting_dir>/worktrees. A name that is not registered is refused
# (issue #265 part 4 retired the <root>/worktrees/project/<name>
# fallback). Return 1 on an invalid or unregistered name, 2 on parse
# errors.
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
    _registry_not_registered "$root" "$name"
    return 1
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
# the workspace root, say), and a session in one of its
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
# registered project root or in its worktrees= directory
# (registry_resolve_session_dir: longest-prefix match, so an instance beats
# its parent), or "workspace\t" when it is inside the workspace checkout.
# Registered roots are checked FIRST: a project registered inside the
# workspace tree, or a worktrees= directory there, is still a project's.
# Return 1 when the directory implies neither, 2 on registry parse errors.
# Callers must let an explicit --type/--project win over this.
# Usage: derived=$(registry_derive_type_from_dir "$root" "$PWD")
registry_derive_type_from_dir() {
    local root="$1" dir="${2:-$PWD}" abs wsabs entry rc=0
    abs="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
    entry="$(registry_resolve_session_dir "$root" "$abs")" || rc=$?
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

# Print the main checkout of the workspace repository whose checkout is
# <root> (issue #295), which holds the gitignored registry a linked
# worktree does not have. It decides the "is a project registered?"
# messages only; the mirror in lib/workspace.py is get_main_checkout_root.
# The rule:
#   - <root> is not the top level of its own repository (not a git
#     checkout, or a plain directory inside another repository, which must
#     not borrow that repository's registry): print <root>;
#   - git's --git-dir equals its --git-common-dir (a main checkout, also
#     one made with `git clone --separate-git-dir`): print <root>;
#   - otherwise (a linked worktree): print the first worktree that
#     `git worktree list --porcelain` names, which is the main checkout,
#     when that is a directory that is the top level of a checkout sharing
#     this common dir; else print <root>.
# Any git failure prints <root>. Always returns 0. A linked worktree whose
# main checkout git does not name (a linked worktree of a checkout made with
# `git clone --separate-git-dir`, whose first `worktree list` entry is the
# git dir, not a checkout) falls back to <root>; registry_main_checkout_fallback
# says when that happened, so a "none registered" message can say instead
# that no registry was found from this linked worktree (issue #265 part 4,
# PR 454's F2).
# Usage: main="$(registry_main_checkout "$root")"
registry_main_checkout() {
    _registry_main_checkout_status "$1" | cut -f1
}

# Succeeds when registry_main_checkout fell back to <root> from a linked
# worktree whose main checkout could not be found (see above).
# Usage: if registry_main_checkout_fallback "$root"; then ...
registry_main_checkout_fallback() {
    [ "$(_registry_main_checkout_status "$1" | cut -f2)" = 1 ]
}

# "<main checkout>\t<1 when it fell back from a linked worktree, else 0>".
_registry_main_checkout_status() {
    local root="$1" abs top gitdir common main mtop mcommon
    abs="$(cd "$root" 2>/dev/null && pwd -P)" || { printf '%s\t0\n' "$root"; return 0; }
    top="$(git -C "$abs" rev-parse --show-toplevel 2>/dev/null)" &&
        top="$(cd "$top" 2>/dev/null && pwd -P)" &&
        [ "$top" = "$abs" ] &&
        gitdir="$(git -C "$abs" rev-parse --path-format=absolute --git-dir 2>/dev/null)" &&
        gitdir="$(cd "$gitdir" 2>/dev/null && pwd -P)" &&
        common="$(git -C "$abs" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" &&
        common="$(cd "$common" 2>/dev/null && pwd -P)" ||
        { printf '%s\t0\n' "$root"; return 0; }
    if [ "$gitdir" = "$common" ]; then
        printf '%s\t0\n' "$root"
        return 0
    fi
    main="$(git -C "$abs" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')" || main=""
    [ -n "$main" ] &&
        main="$(cd "$main" 2>/dev/null && pwd -P)" &&
        mtop="$(git -C "$main" rev-parse --show-toplevel 2>/dev/null)" &&
        mtop="$(cd "$mtop" 2>/dev/null && pwd -P)" &&
        [ "$mtop" = "$main" ] &&
        mcommon="$(git -C "$main" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" &&
        mcommon="$(cd "$mcommon" 2>/dev/null && pwd -P)" &&
        [ "$mcommon" = "$common" ] ||
        { printf '%s\t1\n' "$root"; return 0; }
    printf '%s\t0\n' "$main"
}

# Print the GitHub slug (owner/repo) of the `origin` remote of every
# registered non-parent root, one per line, for the repo-safety checks of
# gh_create_pr.sh and gh_create_issue.sh (issue #295): a project session
# runs from the project's own checkout, so its repository is accepted
# because it is registered, not because of a project/ symlink. Only
# github.com remotes are reduced (the same sed the callers apply to their
# own remote); an entry whose root is not a git checkout, has no origin or
# a non-GitHub origin prints nothing. "Not a git checkout" means the root is
# not the top level of its own repository: git would otherwise walk up from
# a plain directory to an enclosing repository (the workspace, say) and
# return that repository's origin, so the entry is skipped unless
# `rev-parse --show-toplevel` is the root itself. A missing registry or one
# with parse errors prints nothing; always returns 0 (callers run under
# set -e).
# Usage: slugs=$(registry_repo_slugs "$root")
registry_repo_slugs() {
    local root="$1" entries name type path abs top remote
    entries="$(registry_entries "$root" 2>/dev/null)" || return 0
    [ -n "$entries" ] || return 0
    while IFS=$'\t' read -r name type path; do
        [ -z "$name" ] && continue
        [ "$type" = "$REGISTRY_PARENT_TYPE" ] && continue
        abs="$(cd "$path" 2>/dev/null && pwd -P)" || continue
        top="$(git -C "$abs" rev-parse --show-toplevel 2>/dev/null)" || continue
        top="$(cd "$top" 2>/dev/null && pwd -P)" || continue
        [ "$top" = "$abs" ] || continue
        remote="$(git -C "$abs" remote get-url origin 2>/dev/null)" || continue
        [[ "$remote" == *github.com[:/]* ]] || continue
        printf '%s\n' "$remote" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//'
    done <<< "$entries"
    return 0
}

# ------------------------------------------- per-project settings (#332) ---
# The file .agent/projects.d/<name>; grammar and keys in the header above.

# Keys the per-project file accepts.
_PROJECT_FILE_KEYS=" build test install bootstrap_url source source_ref source_path location location_path tracking instructions goals design roadmap "
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

# Whether $1 matches the extended regex $2 in the C locale, where [A-Za-z0-9]
# is ASCII only (under en_US.UTF-8 it also matches 'é' and fullwidth letters).
_project_matches_in_c() {
    local LC_ALL=C
    [[ "$1" =~ $2 ]]
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
            # A first word VAR=value would be exec'd as a command name (no
            # shell applies it as an environment assignment).
            local first="${value%%[[:blank:]]*}"
            if [[ "$first" == *=* ]]; then
                echo "'$key' starts with an environment assignment '$first': a command here is run without a shell, so it would be run as a command named '$first'; point the key at a script that sets the variable instead ($key=./scripts/$key.sh, relative to the project root, or an absolute path)"
                return 1
            fi
            # A word starting with ~ would reach the command literally (no
            # shell expands it), so ~/bin/build fails as "not found".
            local -a words=()
            local w
            read -r -a words <<< "$value"
            for w in "${words[@]}"; do
                if [[ "$w" == "~"* ]]; then
                    echo "'$key' has a word starting with '~' ('$w'): a command here is run without a shell, so '~' is not expanded and would be passed literally; point the key at a script or an absolute path instead ($key=./scripts/$key.sh, relative to the project root, or /home/<you>/...)"
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
        source)
            # A value with a scheme (any case, with or without '//') may hold
            # a credential, so no refusal of one prints it. It is accepted
            # only if it matches one of two shapes whole (an allow-list):
            #   https://<host>[:port]/<path>, the host a name of letters,
            #     digits, '.' and '-' (starting and ending with a letter or
            #     digit) or an IPv6 address in brackets, the port 1 to 5
            #     digits, the path not empty and without '?' or '#';
            #   file:///<path>: exactly three slashes (no authority), the
            #     path not empty ('?', '#', '@' and ':' are ordinary in it).
            # So there is no place for a user name or password. A refusal
            # names the cause where it can be told.
            local https_re file_re
            https_re='^https://([A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?|\[[0-9A-Fa-f:.]+\])(:[0-9]{1,5})?/[^?#[:space:][:cntrl:]]+$'
            file_re='^file:///[^/[:space:][:cntrl:]][^[:space:][:cntrl:]]*$'
            local lower authority
            lower="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
            if [[ "$lower" =~ ^[a-z][a-z0-9+.-]*: ]]; then
                if { _project_matches_in_c "$value" "$https_re" || _project_matches_in_c "$value" "$file_re"; } \
                    && [[ "$value" != *[[:space:][:cntrl:]]* ]]; then
                    return 0
                fi
                # The part before the path, however many '/' follow the
                # scheme: an '@' there is a user name or password to git.
                authority="${value#*:}"
                while [[ "$authority" == /* ]]; do authority="${authority#/}"; done
                authority="${authority%%/*}"
                if [[ "$authority" == *@* ]]; then
                    echo "source must not carry a user name or password in its URL (the part before '@'; the value is not shown): credentials belong in a git credential helper, or use an ssh mirror through a url.<base>.insteadOf rule"
                elif [[ "$lower" == http:* ]]; then
                    # The manifest decides which repositories are cloned and
                    # built, so it must not be open to change on the way.
                    echo "source must not be a plain http:// URL: the manifest decides which repositories are cloned and built, and plain http lets anyone on the network change it on the way; use https:// (a url.<base>.insteadOf rule in your git configuration may send it to an ssh mirror), or file:// for a repository on this machine"
                elif [[ "$lower" == https:* ]] && [[ "$value" == *[?#]* ]]; then
                    echo "source must not have a query or a fragment (the part from '?' or '#'; the value is not shown: it may hold a token): name the repository's URL alone, and keep credentials in a git credential helper"
                elif [[ "$lower" =~ ^(https|file):// ]] && ! [[ "$value" =~ ^(https|file):// ]]; then
                    echo "source must be an absolute path to a file, or an https:// or file:// URL (scheme in lower case) of a git repository, with no blanks or control characters (the value is not shown: a URL may hold a credential)"
                else
                    echo "source must be an absolute path to a file, or an https:// or file:// URL of one of two shapes: https://<host>[:port]/<path> (the host a name or an IPv6 address in brackets, no '?' or '#') or file:///<path> (three slashes), with no blanks or control characters (the value is not shown: a URL may hold a credential)"
                fi
                return 1
            elif [[ "$value" != /* ]] || [[ "$value" == *[[:space:][:cntrl:]]* ]]; then
                # A value holding '://' or '@' (a URL in quotes or brackets,
                # say) may hold a credential: it is not shown.
                if [[ "$value" == *://* ]] || [[ "$value" == *@* ]]; then
                    echo "source must be an absolute path to a file, or an https:// or file:// URL of a git repository (a URL with nothing around it: no quotes or brackets), with no blanks or control characters (the value is not shown: it may hold a credential)"
                else
                    echo "source must be an absolute path to a file, or an https:// or file:// URL of a git repository, with no blanks or control characters, got '$value'"
                fi
                return 1
            fi
            ;;
        source_ref)
            # A branch, tag or commit, never an option: letters, digits,
            # '.', '_', '/', '-', starting with a letter or digit, no '..',
            # no '//', not ending in '/', '.' or '.lock' (git's ref rules,
            # and the manifest resolver's).
            if ! [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || [[ "$value" == *..* ]] \
                || [[ "$value" == *//* ]] || [[ "$value" == */ ]] || [[ "$value" == *. ]] \
                || [[ "$value" == *.lock ]] || [[ "$value" == */.* ]]; then
                echo "source_ref must be a branch, tag or commit: letters, digits, '.', '_', '/' and '-', starting with a letter or digit, with no '..' or '//' and not ending in '/', '.' or '.lock', got '$value'"
                return 1
            fi
            # HEAD is not a branch, tag or commit of the source but git's
            # name for whatever a repository has checked out.
            if [ "$value" = HEAD ]; then
                echo "source_ref must be a branch, tag or commit, not HEAD (git's name for what is checked out): name the branch, e.g. source_ref=main"
                return 1
            fi
            ;;
        source_path)
            local comp bad=0
            local -a comps=()
            # A file, never a directory: no '.' or empty component, no
            # trailing '/'.
            if [[ "$value" == /* ]] || [[ "$value" == */ ]] || [[ "$value" == *//* ]] \
                || [[ "$value" == *[[:space:][:cntrl:]]* ]]; then
                bad=1
            else
                IFS='/' read -r -a comps <<< "$value"
                for comp in "${comps[@]}"; do
                    case "$comp" in ..|.|'') bad=1 ;; esac
                done
            fi
            if [ "$bad" -eq 1 ]; then
                echo "source_path must be the relative path of a file inside the source repository: no '..' or '.' component, no leading or trailing '/', no '//' and no blanks, got '$value'"
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
        goals|design|roadmap)
            _project_document_value_error "$key" "$value" || return 1
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

# Why the settings-file path <file> cannot be used: prints the reason and
# returns 0 when its directory exists but is not a searchable directory (a
# regular file, a dangling link, no search permission), when the path is a
# symlink that does not resolve to an existing
# file (dangling, a loop, a missing directory on the way), or exists
# (directly or through a symlink) but is not a readable regular file;
# returns 1 when it can be used (absent, or a readable regular file, also
# through a chain of symlinks with absolute or relative targets).
_project_file_path_error() {
    local file="$1" dir
    if [ ! -e "$file" ] && [ ! -L "$file" ]; then
        # Absent only when the lookup could see: a projects.d that exists
        # (or is a link) but is not a searchable directory hides the file,
        # and reading that as "no file" would fall through to the shared
        # config.
        dir="$(dirname "$file")"
        if { [ -e "$dir" ] || [ -L "$dir" ]; } && { [ ! -d "$dir" ] || [ ! -x "$dir" ]; }; then
            echo "the settings directory $dir exists but is not a searchable directory, so $file cannot be looked up"
            return 0
        fi
        return 1
    fi
    if [ -L "$file" ] && [ ! -e "$file" ]; then
        echo "$file is a symlink (to '$(readlink -- "$file" 2>/dev/null)') that does not resolve to an existing file: create its target or remove the link"
        return 0
    fi
    if [ -e "$file" ]; then
        if [ ! -f "$file" ]; then
            echo "$file exists but is not a regular file"
            return 0
        fi
        if [ ! -r "$file" ]; then
            echo "$file is not readable"
            return 0
        fi
    fi
    return 1
}

# Does settings file <file> have a key=value line whose key is exactly
# <key>, whatever the key (unknown keys included)? Comment lines never
# count. Return 1 when not, or when the file cannot be read.
_project_file_has_line_key() {
    local file="$1" want="$2" raw line
    [ -f "$file" ] && [ -r "$file" ] || return 1
    while IFS= read -r raw || [ -n "$raw" ]; do
        line="$(_project_file_trim "${raw%$'\r'}")"
        [[ "$line" == \#* ]] && continue
        [[ "$line" == *=* ]] || continue
        [ "$(_project_file_trim "${line%%=*}")" = "$want" ] && return 0
    done < "$file"
    return 1
}

# Does project type <type> refuse settings key <key> because it never
# reads it? Prints the reason and returns 0 when it does; returns 1 when the
# type reads the key (or <type> is empty or has no list); prints the reason
# and returns 2 when the list exists but cannot be read (never read as "no
# list": that would let a refused key through). CRLF lines are read as LF
# lines. The list is the
# type's own data file .agent/project_types/<type>/unused_settings under
# workspace <root> ("<key> <reason>" lines, '#' comments), so no script
# here names a type.
# Usage: reason=$(_project_type_unused_setting "$root" "$type" build)
_project_type_unused_setting() {
    _project_type_setting_listed "$1" "$2" unused_settings "$3" \
        "the list of settings project type '$2' never reads"
}

# Does project type <type> refuse settings key <key> at registration (its
# adapter refuses a project that sets it, so registering one with it can
# never succeed)? The same returns and grammar as
# _project_type_unused_setting, read from the type's data file
# .agent/project_types/<type>/registration_refused. Read by
# register_project.sh for each --set key, before anything is written.
# Usage: reason=$(registration_refused_setting "$root" "$type" source)
registration_refused_setting() {
    _project_type_setting_listed "$1" "$2" registration_refused "$3" \
        "the list of settings project type '$2' refuses at registration"
}

# The reader behind both lists: <lname> is the file's name under the
# type's directory, <what> names it in the unreadable-file reason.
_project_type_setting_listed() {
    local root="$1" type="$2" lname="$3" want="$4" what="$5" f k reason
    [ -n "$type" ] || return 1
    f="$root/.agent/project_types/$type/$lname"
    [ -e "$f" ] || [ -L "$f" ] || return 1
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
        echo "$what, $f, exists but is not a readable file"
        return 2
    fi
    while read -r k reason || [ -n "$k" ]; do
        k="${k%$'\r'}"; reason="${reason%$'\r'}"
        [ -z "$k" ] && continue
        [[ "$k" == \#* ]] && continue
        if [ "$k" = "$want" ]; then
            printf '%s\n' "$reason"
            return 0
        fi
    done < "$f"
    return 1
}

# Check a type's unused_settings or registration_refused list <file> (the
# grammar _project_type_setting_listed reads): readable; each line that is
# not blank or a '#' comment names a known settings key, once, followed by
# a reason. Prints one problem per line ("line N: ...") and returns 1 when
# there is any; returns 0 when the list is valid or absent. Used by
# validate_adapter.sh for both lists.
# Usage: project_type_unused_settings_problems "$file"
project_type_unused_settings_problems() {
    local f="$1" raw k reason lineno=0 bad=0 seen=" " known
    [ -e "$f" ] || [ -L "$f" ] || return 0
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
        echo "$f exists but is not a readable file"
        return 1
    fi
    known="${_PROJECT_FILE_KEYS# }"; known="${known% }"
    while IFS= read -r raw || [ -n "$raw" ]; do
        lineno=$((lineno + 1))
        raw="${raw%$'\r'}"
        read -r k reason <<< "$raw" || true
        [ -z "$k" ] && continue
        [[ "$k" == \#* ]] && continue
        if ! _project_file_key_in "$k" "$_PROJECT_FILE_KEYS"; then
            echo "line $lineno: unknown settings key '$k' (known keys: $known)"
            bad=1; continue
        fi
        if [[ "$seen" == *" $k "* ]]; then
            echo "line $lineno: '$k' is listed twice"
            bad=1; continue
        fi
        seen="$seen$k "
        if [ -z "$reason" ]; then
            echo "line $lineno: '$k' has no reason (the reason is what the user is shown when the key is refused)"
            bad=1; continue
        fi
    done < "$f"
    return "$bad"
}

# Parse a settings file. Prints "key<TAB>value" per setting. A missing
# file prints nothing and returns 0 (every setting at its default). Any
# error (line grammar, unknown or duplicate key, empty or ill-typed value,
# refused records combination) is reported on stderr naming the file and
# line, nothing is printed, and the return is 2: a malformed file never
# resolves. <name> (default: the file's base name) is the project named in
# the repair hints. With <root> and <type>, a key that project type never
# reads (_project_type_unused_setting) is an error too.
# Usage: _project_file_parse <file> [<name> [<root> <type>]]
_project_file_parse() {
    local file="$1" name="${2:-}" root="${3:-}" ptype="${4:-}" raw line key value lineno=0 rc=0 urc seen=" " reason known
    [ -n "$name" ] || name="$(basename "$file")"
    local -a out=()
    if reason="$(_project_file_path_error "$file")"; then
        echo "ERROR: $reason" >&2
        return 2
    fi
    [ -e "$file" ] || return 0
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
            echo "ERROR: ${file}:${lineno}: unknown key '$key' (known keys: $known); remove it with: .agent/scripts/project_setting.sh unset $name '$key', or edit the file by hand" >&2
            rc=2; continue
        fi
        if [[ "$seen" == *" $key "* ]]; then
            echo "ERROR: ${file}:${lineno}: duplicate key '$key' (edit the file by hand to keep one line, or remove both with: .agent/scripts/project_setting.sh unset $name $key)" >&2
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
        urc=0; reason="$(_project_type_unused_setting "$root" "$ptype" "$key")" || urc=$?
        if [ "$urc" -eq 0 ]; then
            echo "ERROR: ${file}:${lineno}: '$key' is not read for project '$name' (type $ptype): $reason; remove it with: .agent/scripts/project_setting.sh unset $name $key" >&2
            rc=2; continue
        fi
        if [ "$urc" -eq 2 ]; then
            echo "ERROR: ${file}:${lineno}: cannot tell whether '$key' applies to project '$name': $reason" >&2
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
    if ! reason="$(_project_source_combination "$entries" "$name")"; then
        echo "ERROR: ${file}: $reason" >&2
        return 2
    fi
    if ! reason="$(_project_document_pair_error "$(_project_file_value_of "$entries" roadmap)" "$(_project_file_value_of "$entries" design)")"; then
        echo "ERROR: ${file}: $reason" >&2
        return 2
    fi
    [ -n "$entries" ] && printf '%s\n' "$entries"
    return 0
}

# The source keys together (issue #436): source_ref and source_path need
# source; a URL source needs source_ref; a path source takes neither; and
# source is refused beside bootstrap_url (one source only, never a silent
# choice). Prints the reason and returns 1 for a refused combination; each
# reason names the one command that removes all three, since unsetting
# source alone (source_ref left) is itself refused. Pure: no filesystem.
# Usage: reason=$(_project_source_combination "$entries" "$name")
_project_source_combination() {
    local entries="$1" name="$2" src ref spath boot fix
    src="$(_project_file_value_of "$entries" source)" || src=""
    ref="$(_project_file_value_of "$entries" source_ref)" || ref=""
    spath="$(_project_file_value_of "$entries" source_path)" || spath=""
    boot="$(_project_file_value_of "$entries" bootstrap_url)" || boot=""
    fix="to stop using a source, remove the three together: .agent/scripts/project_setting.sh unset $name source source_ref source_path"
    if [ -z "$src" ]; then
        if [ -n "$ref" ] || [ -n "$spath" ]; then
            echo "$([ -n "$ref" ] && echo source_ref || echo source_path) is only valid with source (set source=<url-or-path>); $fix"
            return 1
        fi
        return 0
    fi
    if [ -n "$boot" ]; then
        echo "source and bootstrap_url are both set: a project has one source only; remove bootstrap_url (.agent/scripts/project_setting.sh unset $name bootstrap_url), or $fix"
        return 1
    fi
    if [[ "$src" =~ ^(https?|file):// ]]; then
        if [ -z "$ref" ]; then
            echo "source '$src' is a URL, so source_ref (the branch, tag or commit to use) is required; set it with: .agent/scripts/project_setting.sh set $name source_ref=<ref>, or $fix"
            return 1
        fi
    elif [ -n "$ref" ] || [ -n "$spath" ]; then
        echo "source '$src' is a path to a file, so $([ -n "$ref" ] && echo source_ref || echo source_path) does not apply (it is for a URL source); remove it with: .agent/scripts/project_setting.sh unset $name source_ref source_path, or $fix"
        return 1
    fi
    return 0
}

# Parse project <name>'s settings file (see _project_file_parse).
# Usage: entries=$(project_file_entries "$root" "$name") || { ...invalid... }
project_file_entries() {
    local entry ptype=""
    entry="$(registry_lookup "$1" "$2" 2>/dev/null)" && ptype="$(cut -f1 <<< "$entry")"
    _project_file_parse "$(project_file_path "$1" "$2")" "$2" "$1" "$ptype"
}

# Print the stored value of <key> for project <name>. Return 1 when the key
# is not set (or there is no file), 2 when the file is invalid.
# Usage: v=$(project_file_get "$root" "$name" build)
project_file_get() {
    local entries
    entries="$(project_file_entries "$1" "$2")" || return 2
    _project_file_value_of "$entries" "$3"
}

# ------------------------- where a project keeps its documents (#551) ---
# The settings goals, design and roadmap name where a project keeps each of
# those documents; grammar in the header above. One helper answers for
# every reader (sitrep_root.sh, update_roadmap.sh, check_design_anchors.sh,
# the merge gate's bookkeeping paths, and the skills through
# project_setting.sh doc).

# The fallback for an unset key, in order: the first that exists is used
# (update_roadmap.sh ticks every one that exists). goals has none.
_PROJECT_DOCUMENT_CANDIDATES_roadmap="docs/roadmap.md docs/ROADMAP.md ROADMAP.md"
_PROJECT_DOCUMENT_CANDIDATES_design="docs/design.md"
_PROJECT_DOCUMENT_CANDIDATES_goals=""

# Print a document key's fallback candidates, one per line.
# Usage: project_document_candidates roadmap
project_document_candidates() {
    local var="_PROJECT_DOCUMENT_CANDIDATES_$1" c IFS=' '
    case "$1" in goals|design|roadmap) ;; *) return 1 ;; esac
    for c in ${!var}; do printf '%s\n' "$c"; done
}

# The path characters every reader of a goals/design/roadmap setting
# handles: check_design_anchors.sh's citation scanner reads a design path
# only as a run of its path characters, and the merge gate's bookkeeping
# list matches the roadmap's path literally. A path with any other
# character would be read short by one of them (a broken citation passing
# unseen), so it is refused, never read differently by each reader.
_PROJECT_DOCUMENT_PATH_CHARS='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/'

# Print the first character of <path> outside _PROJECT_DOCUMENT_PATH_CHARS
# and return 1; return 0, printing nothing, when there is none. An explicit
# list, not a range, so no locale widens it.
_project_document_path_char() {
    local p="$1" i ch
    for ((i = 0; i < ${#p}; i++)); do
        ch="${p:i:1}"
        [[ "$_PROJECT_DOCUMENT_PATH_CHARS" == *"$ch"* ]] || { printf '%s' "$ch"; return 1; }
    done
    return 0
}

# Check a goals/design/roadmap value. Prints the reason and returns 1 when
# it is not 'none' or a project-relative file path (optionally #<heading>;
# never on roadmap, whose path must also end in .md). The path is checked
# before the heading, so a refusal never suggests an invalid path. Pure: no
# filesystem access (containment is checked again when the path is read,
# project_document_path).
_project_document_value_error() {
    local key="$1" value="$2" path heading="" comp bad="" c
    local -a comps=()
    [ "$value" = none ] && return 0
    path="${value%%#*}"
    [[ "$value" == *#* ]] && heading="${value#*#}"
    if [[ "$path" == *://* ]]; then
        echo "$key must be a file inside the project (a path relative to the project root), not a URL: a document outside the project is not supported"
        return 1
    fi
    if [ -z "$path" ]; then
        bad="the path is empty"
    elif [[ "$path" == /* ]] || [[ "$path" == "~"* ]]; then
        bad="it must be relative to the project root (no leading '/' or '~'): a document outside the project is not supported"
    elif [[ "$path" == */ ]]; then
        bad="it must name a file, not a directory (no trailing '/')"
    elif [[ "$path" == *[[:space:][:cntrl:]]* ]] || [[ "$path" == *\\* ]]; then
        bad="the path must not hold blanks, control characters or a backslash"
    elif [[ "$path" == *[\*\?\[\]]* ]]; then
        bad="the path must not hold '*', '?', '[' or ']' (it is a file, not a pattern)"
    elif ! c="$(_project_document_path_char "$path")"; then
        bad="the path may hold only the characters every reader of the setting handles (ASCII letters, digits, '.', '_', '-' and '/'), not '$c'"
    else
        IFS='/' read -r -a comps <<< "$path"
        for comp in "${comps[@]}"; do
            case "$comp" in
                ..|.|'') bad="no '..', '.' or empty path component (the path stays inside the project)"; break ;;
            esac
        done
    fi
    if [ -n "$bad" ]; then
        echo "$key must be 'none' or a file inside the project, as a path relative to the project root$([ "$key" != roadmap ] && echo ", optionally followed by #<heading>"): $bad; got '$value'"
        return 1
    fi
    if [ "$key" = roadmap ]; then
        # The merge gate exempts post-review commits to this file from the
        # review- and CI-staleness checks (bookkeeping_roadmap_paths), so it
        # may only name a Markdown file, never code.
        if [[ "$path" != *.md ]]; then
            echo "roadmap must name a Markdown file (a path ending in .md): commits to it after review count as bookkeeping in the merge gate; got '$value'"
            return 1
        fi
        case "$(tr '[:upper:]' '[:lower:]' <<< "${path##*/}")" in
            readme.md|agents.md|claude.md|codex.md)
                echo "roadmap must not name ${path##*/}: commits to the roadmap after review count as bookkeeping in the merge gate, so it may not be the project's README or an agent instruction file; got '$value'"
                return 1 ;;
        esac
        if [ "$(tr '[:upper:]' '[:lower:]' <<< "$path")" = "$(tr '[:upper:]' '[:lower:]' <<< "${_PROJECT_DOCUMENT_CANDIDATES_design%% *}")" ]; then
            echo "roadmap must not name the design fallback ${_PROJECT_DOCUMENT_CANDIDATES_design%% *}: commits to the roadmap after review count as bookkeeping in the merge gate; got '$value'"
            return 1
        fi
        if [[ "$value" == *#* ]]; then
            echo "roadmap takes a file, not a section ('#$heading'): the sit-rep reads the file's '## Direction' section and update_roadmap.sh edits the whole file, so name the file alone (roadmap=$path)"
            return 1
        fi
    elif [[ "$value" == *#* ]]; then
        if [ -z "$(_project_file_trim "$heading")" ] || [[ "$heading" == *[[:cntrl:]]* ]]; then
            echo "$key: the heading after '#' must not be empty or hold control characters, got '$value'"
            return 1
        fi
    fi
    return 0
}

# The roadmap and design settings together: the roadmap may not be the
# design's file (compared without #heading, ignoring case), since commits
# to the roadmap after review count as bookkeeping. Prints the reason and
# returns 1; empty values (unset) and 'none' always pass. Pure.
_project_document_pair_error() {
    local roadmap="$1" design="${2%%#*}"
    [ -n "$roadmap" ] && [ -n "$design" ] && [ "$roadmap" != none ] && [ "$design" != none ] || return 0
    if [ "$(tr '[:upper:]' '[:lower:]' <<< "$roadmap")" = "$(tr '[:upper:]' '[:lower:]' <<< "$design")" ]; then
        echo "roadmap=$roadmap names the design's file (design=$2): commits to the roadmap after review count as bookkeeping in the merge gate, so it must be a file of its own"
        return 1
    fi
    return 0
}

# The registered project whose documents a directory <dir> reads: printed
# when <dir> is that project's registered root, or the top of a checkout
# (a worktree) of the root's own repository when the root is the top of
# that repository, since only then is a root-relative path also relative to
# <dir>. Returns 1 for every other directory: a checkout of the workspace
# itself (the workspace is not registered; its documents are the fixed
# candidates, and its own checks never read the registry), a directory in
# no registered root, a subdirectory of one, or a checkout of a package
# repository of a multi-repository project. Returns 2 when the registry
# <ws_root>/.agent/projects.local cannot be parsed. A parent root ("project"
# type) is printed too: it keeps no settings, so project_document_path
# answers it from the candidates.
# Limit: a worktree is found through the registry's session-directory
# match (registry_resolve_session_dir), so it must lie inside the root or
# its `worktrees=` directory, as worktree_create.sh makes them. A
# hand-made `git worktree add` elsewhere is not tied to its project and
# reads the candidates; matching every registered root's git common
# directory would cost a git call per project on every lookup.
# Usage: name="$(project_document_name_for_root "$ws_root" "$dir")"
# git for the lookups below, without the repository an outer git (a hook
# of another repository, say) exports: GIT_DIR or GIT_WORK_TREE would make
# every `git -C` answer for that repository instead of the directory named.
_project_document_git() {
    env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR git "$@"
}

project_document_name_for_root() {
    local ws="$1" dir="$2" abs top wscommon common entry rc=0 name path pabs ptop pcommon
    abs="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
    top="$(_project_document_git -C "$abs" rev-parse --show-toplevel 2>/dev/null)" && top="$(cd "$top" 2>/dev/null && pwd -P)" || top=""
    common="$(_project_document_git -C "$abs" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
        && common="$(cd "$common" 2>/dev/null && pwd -P)" || common=""
    wscommon="$(_project_document_git -C "$ws" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
        && wscommon="$(cd "$wscommon" 2>/dev/null && pwd -P)" || wscommon=""
    # A checkout of the workspace's own repository is the workspace.
    if [ -n "$top" ] && [ "$top" = "$abs" ] && [ -n "$common" ] && [ "$common" = "$wscommon" ]; then
        return 1
    fi
    entry="$(registry_resolve_session_dir "$ws" "$abs" 2>/dev/null)" || rc=$?
    [ "$rc" -eq 2 ] && return 2
    [ "$rc" -eq 0 ] || return 1
    name="$(cut -f1 <<< "$entry")"
    path="$(cut -f3 <<< "$entry")"
    pabs="$(cd "$path" 2>/dev/null && pwd -P)" || return 1
    if [ "$abs" = "$pabs" ]; then
        printf '%s\n' "$name"
        return 0
    fi
    # A worktree: the root must be the top of its own repository, and <dir>
    # the top of a checkout sharing that repository.
    ptop="$(_project_document_git -C "$pabs" rev-parse --show-toplevel 2>/dev/null)" && ptop="$(cd "$ptop" 2>/dev/null && pwd -P)" || return 1
    [ "$ptop" = "$pabs" ] || return 1
    pcommon="$(_project_document_git -C "$pabs" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
        && pcommon="$(cd "$pcommon" 2>/dev/null && pwd -P)" || return 1
    [ -n "$top" ] && [ "$top" = "$abs" ] && [ "$common" = "$pcommon" ] || return 1
    printf '%s\n' "$name"
}

# Is <rel> an existing regular file inside <dir>, also after symlinks are
# followed? Prints the reason and returns 1 when it is missing (or not a
# regular file), 2 when it resolves outside <dir>, 3 when it is a symbolic
# link that resolves to nothing (dangling, a loop).
_project_document_file_error() {
    local dir="$1" rel="$2" dabs real
    dabs="$(cd "$dir" 2>/dev/null && pwd -P)" || { echo "$dir is not a directory"; return 1; }
    if [ ! -e "$dabs/$rel" ] && [ ! -L "$dabs/$rel" ]; then
        echo "$rel does not exist in $dabs"
        return 1
    fi
    if [ ! -e "$dabs/$rel" ]; then
        echo "$rel in $dabs is a symbolic link that resolves to no file (to '$(readlink -- "$dabs/$rel" 2>/dev/null)')"
        return 3
    fi
    real="$(readlink -f -- "$dabs/$rel" 2>/dev/null)" || real=""
    if [ -z "$real" ] || { [ "$real" != "$dabs" ] && [[ "$real" != "$dabs/"* ]]; }; then
        echo "$rel resolves outside $dabs (${real:-a link that cannot be resolved}): a document must be inside the project"
        return 2
    fi
    if [ ! -f "$real" ]; then
        echo "$rel in $dabs is not a regular file"
        return 1
    fi
    return 0
}

# The values of <key> in settings file <file> as written, one per line
# (trimmed, CR dropped), whatever else the file holds: lets a reader tell
# its own key when another line of the file is invalid. Prints nothing
# when the key has no line.
_project_document_raw_values() {
    local file="$1" want="$2" raw line
    [ -f "$file" ] && [ -r "$file" ] || return 0
    while IFS= read -r raw || [ -n "$raw" ]; do
        line="$(_project_file_trim "${raw%$'\r'}")"
        [[ "$line" == \#* ]] && continue
        [[ "$line" == *=* ]] || continue
        [ "$(_project_file_trim "${line%%=*}")" = "$want" ] || continue
        printf '%s\n' "$(_project_file_trim "${line#*=}")"
    done < "$file"
}

# Where project <name> keeps document <key> (goals, design or roadmap),
# read in directory <dir> (default: the project's registered root; a
# worktree of the root's own repository reads the same relative paths).
# An empty <name> (an unregistered root, such as the workspace) has no
# settings: only the candidates. Prints one line "<source> <value>":
#   set <path>[#<heading>]  the key names <path>, an existing file
#   fallback <path>         the key is unset; the first candidate that
#                           exists (project_document_candidates; goals has
#                           none)
#   none                    the key is 'none': the project keeps no such
#                           document
# Returns 0 for these; 1 with the reason on stderr when there is nothing to
# read (unset goals, no candidate exists, or the file a set key names is
# missing -- then "set <value>" is still printed, so a reader can name the
# file the project chose); 2 with the reason when a SET key cannot be used:
# it is set more than once or to an invalid value (also a roadmap naming
# the design's file), the file it names resolves outside <dir> or is a
# symbolic link that resolves to nothing, or (roadmap only) that file is a
# symbolic link or reached through one (update_roadmap.sh replaces the file
# it edits, and the merge gate's bookkeeping exemption names the path, not
# a link's target).
# Fails open where nothing is set (issue #551: "with no setting, each
# keeps today's fixed search"):
#   - an unset key's candidate that resolves outside <dir> is read as
#     before, with a warning (a dangling one is passed over, as before);
#   - when the key cannot be read for a reason outside it -- the registry
#     cannot be parsed, <name> is not registered, a parent root holds a
#     settings file, the settings file cannot be read, or another line of
#     it is invalid -- one "warning: ..." line names the problem on stderr
#     and the key is read from its own line when that is valid, else as
#     unset (the candidates). Where whether the key is set cannot be told
#     at all (the registry cannot be parsed, the settings file cannot be
#     read) and PROJECT_DOC_STRICT=1 is set, as a writer sets it, the
#     return is 3 with the reason instead: a writer does nothing it cannot
#     tell the project chose.
# Without <dir> there is nowhere to look for candidates, and a registry
# problem returns 2.
# Usage: line="$(project_document_path "$ws_root" "$name" roadmap [<dir>])"
project_document_path() {
    local ws="$1" name="$2" key="$3" dir="${4:-}" entry entries value="" dvalue="" rc=0 path dpath reason c file real
    # Set by project_document_for_dir when the registry cannot be parsed.
    local untold="${_project_document_untold:-}"
    local -a vals=() dvals=()
    ws="$(cd "$ws" 2>/dev/null && pwd -P)" || ws="$1"
    case "$key" in goals|design|roadmap) ;; *)
        echo "ERROR: project_document_path: unknown document '$key' (goals, design or roadmap)" >&2; return 2 ;;
    esac
    if [ -n "$name" ]; then
        entry="$(registry_lookup "$ws" "$name" 2>/dev/null)" || rc=$?
        if [ "$rc" -ne 0 ]; then
            if [ -z "$dir" ]; then
                if [ "$rc" -eq 2 ]; then
                    echo "ERROR: the registry $(registry_file "$ws") has errors; fix it first" >&2
                else
                    echo "ERROR: project '$name' is not registered in $(registry_file "$ws")" >&2
                fi
                return 2
            fi
            if [ "$rc" -eq 2 ]; then
                untold="the registry $(registry_file "$ws") has errors"
            else
                echo "warning: project '$name' is not registered in $(registry_file "$ws"); its documents are the fixed candidates" >&2
            fi
            name=""
        else
            [ -n "$dir" ] || dir="$(cut -f2 <<< "$entry")"
            file="$(project_file_path "$ws" "$name")"
            if [ "$(cut -f1 <<< "$entry")" = "$REGISTRY_PARENT_TYPE" ]; then
                if [ -e "$file" ] || [ -L "$file" ]; then
                    echo "warning: $file: '$name' is a parent root, so nothing reads this file (remove it); its documents are the fixed candidates" >&2
                fi
            elif entries="$(project_file_entries "$ws" "$name" 2>/dev/null)"; then
                value="$(_project_file_value_of "$entries" "$key")" || value=""
                dvalue="$(_project_file_value_of "$entries" design)" || dvalue=""
            elif reason="$(_project_file_path_error "$file")"; then
                untold="$reason"
            else
                mapfile -t vals < <(_project_document_raw_values "$file" "$key")
                if [ "${#vals[@]}" -gt 1 ]; then
                    echo "ERROR: $file: $key is set more than once; keep one line" >&2
                    return 2
                fi
                if [ "${#vals[@]}" -eq 1 ]; then
                    if ! reason="$(_project_document_value_error "$key" "${vals[0]}")"; then
                        echo "ERROR: $file: $reason" >&2
                        return 2
                    fi
                    if [ "$key" = roadmap ]; then
                        mapfile -t dvals < <(_project_document_raw_values "$file" design)
                        if [ "${#dvals[@]}" -eq 1 ] && ! reason="$(_project_document_pair_error "${vals[0]}" "${dvals[0]}")"; then
                            echo "ERROR: $file: $reason" >&2
                            return 2
                        fi
                    fi
                    value="${vals[0]}"
                    [ "${#dvals[@]}" -ne 1 ] || dvalue="${dvals[0]}"
                fi
                echo "warning: $file has errors (.agent/scripts/project_setting.sh check $name names them); each document setting is read from its own line, an absent one as unset" >&2
            fi
        fi
    fi
    if [ -z "$dir" ]; then
        echo "ERROR: project_document_path: no directory to read $key in" >&2
        return 2
    fi
    if [ -n "$untold" ]; then
        if [ "${PROJECT_DOC_STRICT:-}" = 1 ]; then
            echo "whether $key is set cannot be told: $untold" >&2
            return 3
        fi
        echo "warning: $untold, so whether a document is set cannot be told; using the fixed candidates" >&2
    fi
    if [ "$value" = none ]; then
        echo "none"
        return 0
    fi
    if [ -n "$value" ]; then
        path="${value%%#*}"
        rc=0; reason="$(_project_document_file_error "$dir" "$path")" || rc=$?
        if [ "$rc" -eq 1 ]; then
            echo "$key=$value (project '$name'): $reason" >&2
            printf 'set %s\n' "$value"
            return 1
        fi
        if [ "$rc" -ne 0 ]; then
            echo "$key=$value (project '$name'): $reason" >&2
            return 2
        fi
        if [ "$key" = roadmap ] && [ "$(readlink -f -- "$dir/$path" 2>/dev/null)" != "$(cd "$dir" 2>/dev/null && pwd -P)/$path" ]; then
            echo "$key=$value (project '$name'): $path is a symbolic link or is reached through one; name the file itself (update_roadmap.sh replaces the file it edits)" >&2
            return 2
        fi
        # The design's file (set, else the fallback) may be a link to it:
        # the pair rule compares the files, not only their names.
        dpath="${dvalue%%#*}"; dpath="${dpath:-${_PROJECT_DOCUMENT_CANDIDATES_design%% *}}"
        if [ "$key" = roadmap ] && [ "$dvalue" != none ] && [ "$(readlink -f -- "$dir/$dpath" 2>/dev/null)" = "$(readlink -f -- "$dir/$path")" ]; then
            echo "$key=$value (project '$name'): the design's file $dpath is this file through a symbolic link; commits to the roadmap after review count as bookkeeping in the merge gate, so it must be a file of its own" >&2
            return 2
        fi
        printf 'set %s\n' "$value"
        return 0
    fi
    while IFS= read -r c; do
        [ -n "$c" ] || continue
        rc=0; reason="$(_project_document_file_error "$dir" "$c")" || rc=$?
        [ "$rc" -eq 0 ] && { printf 'fallback %s\n' "$c"; return 0; }
        if [ "$rc" -eq 2 ]; then
            # Unset: read as before this setting existed, with a warning.
            real="$(readlink -f -- "$dir/$c" 2>/dev/null)" || real=""
            if [ -n "$real" ] && [ -f "$real" ]; then
                echo "warning: $key: $reason; read as before, since $key is not set" >&2
                printf 'fallback %s\n' "$c"
                return 0
            fi
        fi
    done < <(project_document_candidates "$key")
    if [ -n "$untold" ]; then
        echo "whether $key is set cannot be told ($untold), and none of $(project_document_candidates "$key" | tr '\n' ' ' | sed 's/ $//') exists in $dir" >&2
    elif [ "$key" = goals ]; then
        echo "goals is not set${name:+ for project '$name'} (there is no fallback for goals)" >&2
    else
        echo "$key is not set${name:+ for project '$name'} and none of $(project_document_candidates "$key" | tr '\n' ' ' | sed 's/ $//') exists in $dir" >&2
    fi
    return 1
}

# project_document_path for the project directory <dir> belongs to
# (project_document_name_for_root): a registered root or a worktree of its
# own repository reads the project's setting; any other directory (the
# workspace) reads the candidates in <dir>. When the registry cannot be
# parsed, whether <dir> has a setting cannot be told: one "warning: ..."
# line and the candidates, or with PROJECT_DOC_STRICT=1 return 3. Same
# output and returns.
# Usage: line="$(project_document_for_dir "$ws_root" "$dir" design)"
project_document_for_dir() {
    local ws="$1" dir="$2" key="$3" name="" rc=0 _project_document_untold=""
    ws="$(cd "$ws" 2>/dev/null && pwd -P)" || ws="$1"
    name="$(project_document_name_for_root "$ws" "$dir")" || rc=$?
    [ "$rc" -eq 2 ] && _project_document_untold="the registry $(registry_file "$ws") has errors"
    [ "$rc" -eq 0 ] || name=""
    project_document_path "$ws" "$name" "$key" "$dir"
}

# project_document_query <fn> <args...>: run <fn> (project_document_path
# or project_document_for_dir) in this shell and set PROJECT_DOC_RC (its
# return), PROJECT_DOC_LINE (its stdout line, also on return 1 when a set
# key names a missing file) and PROJECT_DOC_WHY (the last line of its
# reason, tabs, CRs and other control characters made blanks, so it fits
# a TSV row or a key=value line). Its "warning: ..." lines are passed on to
# stderr, each once per shell (a reader asking for two documents gets one
# warning about one bad settings file). No temporary file: the two streams
# are told apart by content (an answer is "set ...", "fallback ..." or
# "none"; no reason starts so).
PROJECT_DOC_WARNED=""
project_document_query() {
    local fn="$1" all line
    shift
    PROJECT_DOC_RC=0; PROJECT_DOC_LINE=""; PROJECT_DOC_WHY=""
    case "$fn" in project_document_path|project_document_for_dir) ;; *)
        PROJECT_DOC_RC=2; PROJECT_DOC_WHY="project_document_query: unknown function '$fn'"; return 0 ;;
    esac
    all="$("$fn" "$@" 2>&1)" || PROJECT_DOC_RC=$?
    while IFS= read -r line; do
        case "$line" in
            "set "*|"fallback "*|none) PROJECT_DOC_LINE="$line" ;;
            warning:*)
                case "$PROJECT_DOC_WARNED" in
                    *$'\n'"$line"$'\n'*) ;;
                    *) printf '%s\n' "$line" >&2; PROJECT_DOC_WARNED="${PROJECT_DOC_WARNED:-$'\n'}$line"$'\n' ;;
                esac ;;
            "") ;;
            *) PROJECT_DOC_WHY="$line" ;;
        esac
    done <<< "$all"
    PROJECT_DOC_WHY="${PROJECT_DOC_WHY//[[:cntrl:]]/ }"
    return 0
}

# ------------------------------------- where a command comes from (#332) ---

# Value of shell variable <var> after sourcing a retired config file <file>
# (a projects.d/<name>.sh or the shared .agent/project_config.sh) in a
# subshell, the way the adapters used to read it (the variable is cleared
# first, so only the file sets it). Prints the value; return 1 when the file
# cannot be sourced. Kept for the stale-shape report alone (issue #265 part
# 4, plan review N3): no adapter reads these files for a value any more.
_project_config_value() {
    local file="$1" var="$2"
    (
        eval "$var="
        # shellcheck source=/dev/null
        source "$file" >/dev/null 2>&1 || exit 1
        printf '%s' "${!var:-}"
    )
}

# Where project <name>'s command setting <key> (build, test or install)
# comes from: its settings file ('none' included), the one source since
# issue #265 part 4. Prints "file\t<value>", or "missing\t" when the file
# does not set it. Return 2 when the settings file is invalid or <key> is
# not a command setting (the reason on stderr).
# Usage: src=$(project_command_source "$root" "$name" test)
project_command_source() {
    local root="$1" name="$2" key="$3" entries v
    case "$key" in
        build|test|install) : ;;
        *)
            echo "ERROR: project_command_source: '$key' is not a command setting (build, test, install)" >&2
            return 2
            ;;
    esac
    entries="$(project_file_entries "$root" "$name")" || return 2
    if v="$(_project_file_value_of "$entries" "$key")"; then
        printf 'file\t%s\n' "$v"
        return 0
    fi
    printf 'missing\t\n'
}

# The variables the adapters used to read from a retired config file
# (stale-shape report only).
_PROJECT_CONFIG_READ_VARS=" PROJECT_TYPE BUILD_CMD TEST_CMD INSTALL_CMD MANIFEST_BOOTSTRAP_URL ROS_DISTRO ROS_ROOT_DIR "

# The variables retired config file <file> sets, changes or exports beyond
# the ones the adapters used to read (_PROJECT_CONFIG_READ_VARS), one name
# per line, sorted (stale-shape report only, plan review S8). A command in
# the settings file runs without sourcing the config, so such a variable
# (an SDK path, PATH) does not reach it. The file is sourced
# in a clean bash (env -i, keeping HOME and PATH), and every variable is
# compared before and after. Returns non-zero when the file cannot be
# sourced (call it as a condition: under set -e a failure would stop the
# caller).
# Usage: extra=$(project_config_extra_vars "$file") || { ...cannot source... }
project_config_extra_vars() {
    local file="$1"
    env -i HOME="${HOME:-}" PATH="$PATH" bash --noprofile --norc -c '
        __pcx_before="$(declare -p)"
        # shellcheck source=/dev/null
        source "$1" >/dev/null 2>&1 || exit 1
        __pcx_after="$(declare -p)"
        comm -13 <(printf "%s\n" "$__pcx_before" | sort) <(printf "%s\n" "$__pcx_after" | sort) \
            | sed -n "s/^declare -[^ ]* \([A-Za-z_][A-Za-z0-9_]*\).*/\1/p" | sort -u
    ' _ "$file" | while IFS= read -r n; do
        case "$n" in
            __pcx_*|_|BASH*|FUNCNAME|LINENO|RANDOM|SECONDS|SRANDOM|EPOCHREALTIME|EPOCHSECONDS|PIPESTATUS|COLUMNS|LINES|OLDPWD|PWD|SHLVL|HISTCMD|DIRSTACK|GROUPS|PPID|UID|EUID|SHELLOPTS|IFS|OPTIND|OPTERR|PS1|PS2|PS4|HOSTNAME|HOSTTYPE|MACHTYPE|OSTYPE|COMP_WORDBREAKS) continue ;;
        esac
        [[ "$_PROJECT_CONFIG_READ_VARS" == *" $n "* ]] && continue
        echo "$n"
    done
    # The sourcing shell's status, not the filter's.
    return "${PIPESTATUS[0]}"
}

# ------------------------------------------ retired shapes (#265 part 4) ---
# Nothing reads <ws>/project, <ws>/projects/<unregistered>, the worktree
# fallbacks, a projects.d/<name>.sh or the shared .agent/project_config.sh
# any more. Retirement is not silent: these helpers name what is still on
# disk and what to do with it. Warnings only, never a failure: a machine
# may keep the files until its owner moves the settings.

# The values retired config file <file> sets (non-empty after sourcing it
# in a clean subshell, every read variable cleared first), one
# "<VAR>\t<value>" line per variable, in _PROJECT_CONFIG_READ_VARS order.
# Return 1 when the file cannot be sourced.
_stale_config_values() {
    local file="$1"
    (
        # shellcheck disable=SC2086  # the list is words by design
        for __v in $_PROJECT_CONFIG_READ_VARS; do eval "$__v="; done
        # shellcheck source=/dev/null
        source "$file" >/dev/null 2>&1 || exit 1
        for __v in $_PROJECT_CONFIG_READ_VARS; do
            [ -n "${!__v:-}" ] && printf '%s\t%s\n' "$__v" "${!__v}"
        done
        exit 0
    )
}

# The settings key a retired command variable maps to, or nothing.
_stale_var_key() {
    case "$1" in
        BUILD_CMD) echo build ;;
        TEST_CMD) echo test ;;
        INSTALL_CMD) echo install ;;
        MANIFEST_BOOTSTRAP_URL) echo bootstrap_url ;;
    esac
}

# The retired config file that applied to registered project <name> under
# the old resolution order (plan review N3): its .agent/projects.d/<name>.sh
# when that exists (it was then the whole legacy layer), else the shared
# .agent/project_config.sh when that exists; prints the path, or nothing.
registry_stale_config_for() {
    local root="$1" name="$2"
    if [ -f "$root/.agent/projects.d/$name.sh" ]; then
        echo "$root/.agent/projects.d/$name.sh"
    elif [ -f "$root/.agent/project_config.sh" ]; then
        echo "$root/.agent/project_config.sh"
    fi
    return 0
}

# Does project type <type> read what retired variable <var> used to set?
# ROS_DISTRO became the registry line's distro=, which the dispatcher hands
# a type's adapter as ACTIVE_PROJECT_DISTRO; ROS_ROOT_DIR is read from the
# environment by name. The answer is the type's own adapter.sh naming that
# variable, so no script here names a type (ADR-0011). An empty or unknown
# type answers yes: advice is never dropped for want of a type.
# Usage: _stale_type_reads "$root" "$type" ROS_DISTRO
_stale_type_reads() {
    local root="$1" type="$2" var="$3" word f
    case "$var" in
        ROS_DISTRO) word=ACTIVE_PROJECT_DISTRO ;;
        ROS_ROOT_DIR) word=ROS_ROOT_DIR ;;
        *) return 1 ;;
    esac
    [ -n "$type" ] || return 0
    f="$root/.agent/project_types/$type/adapter.sh"
    [ -f "$f" ] || return 0
    grep -qw -- "$word" "$f"
}

# One line per setting a retired config file holds for registered project
# <name> that its settings file lacks, each with its remedy (plan review
# N3): build/test/install/bootstrap_url by project_setting.sh set (skipped
# for a key the project's type never reads, its unused_settings); ROS_DISTRO
# by distro= on the registry line, by hand (project_setting.sh has no such
# key), only while the line has none; ROS_ROOT_DIR from the environment;
# each ROS_* line only for a type that reads it (_stale_type_reads);
# variables beyond the read set (plan review S8) belong in the script a key
# points at. <file> defaults to registry_stale_config_for's; with
# <shared_only>=1 the ROS_ROOT_DIR and extra-variable lines are left out
# (the whole report says those once for the shared file). Prints nothing
# when nothing is left to move. Return 1 when what is left cannot be told
# (a line says why): the file cannot be sourced, the registry has errors,
# or the project's settings file is invalid. Never read as "nothing left":
# the adapter's install refuses on it, the report shows the line.
# Usage: registry_stale_settings_lines "$root" "$name" [<file>] [<shared_only>]
registry_stale_settings_lines() {
    local root="$1" name="$2" file="${3:-}" shared_only="${4:-0}"
    local rel vals var val key type entry entries extra distro rc=0
    [ -n "$file" ] || file="$(registry_stale_config_for "$root" "$name")"
    [ -n "$file" ] || return 0
    rel=".agent/${file#"$root/.agent/"}"
    if ! vals="$(_stale_config_values "$file")"; then
        echo "$rel cannot be sourced, so what is left in it for '$name' is unknown: read it by hand, move what it sets with .agent/scripts/project_setting.sh set $name <key>=<value>, then delete it"
        return 1
    fi
    entry="$(registry_lookup "$root" "$name" 2>/dev/null)" || rc=$?
    if [ "$rc" -eq 2 ]; then
        echo "$rel: .agent/projects.local has errors, so what is left in $rel for '$name' cannot be told: fix the registry (make validate names each bad line), then look again"
        return 1
    fi
    type="$(cut -f1 <<< "$entry")"
    if ! entries="$(project_file_entries "$root" "$name" 2>/dev/null)"; then
        echo "$rel: the settings file of '$name', .agent/projects.d/$name, is invalid, so what is left in $rel to move cannot be told: fix it (.agent/scripts/project_setting.sh check $name), then look again"
        return 1
    fi
    while IFS=$'\t' read -r var val; do
        [ -n "$var" ] || continue
        key="$(_stale_var_key "$var")"
        if [ -n "$key" ]; then
            _project_file_value_of "$entries" "$key" >/dev/null && continue
            _project_type_unused_setting "$root" "$type" "$key" >/dev/null 2>&1 && continue
            if [ "$key" = bootstrap_url ]; then
                echo "$rel sets $var=\"$val\", which .agent/projects.d/$name lacks and nothing reads any more: .agent/scripts/project_setting.sh set $name bootstrap_url=<url>"
            else
                echo "$rel sets $var=\"$val\", which .agent/projects.d/$name lacks and nothing reads any more: .agent/scripts/project_setting.sh set $name $key=<command> (or $key=none)"
            fi
            continue
        fi
        _stale_type_reads "$root" "$type" "$var" || continue
        case "$var" in
            ROS_DISTRO)
                distro="$(registry_field "$root" "$name" distro 2>/dev/null)" || distro=""
                [ -n "$distro" ] && continue
                echo "$rel sets ROS_DISTRO=\"$val\", which nothing reads any more: if $name's manifest declares no distro, add distro=$val to its line in .agent/projects.local by hand"
                ;;
            ROS_ROOT_DIR)
                [ "$shared_only" = 1 ] && continue
                echo "$rel sets ROS_ROOT_DIR=\"$val\", which is no longer read from a file: export ROS_ROOT_DIR=$val in the environment that runs the adapter"
                ;;
        esac
    done <<< "$vals"
    if [ "$shared_only" != 1 ]; then
        if extra="$(project_config_extra_vars "$file")" && [ -n "$extra" ]; then
            echo "$rel sets or exports $(printf '%s' "$extra" | tr '\n' ' ' | sed 's/ $//; s/ /, /g'), which no command gets any more: move that environment into the script $name's settings keys point at"
        fi
    fi
    return 0
}

# <path> as the filesystem names it, without following <path> itself when
# it is a link: its parent resolved physically, then its own name. Falls
# back to the lexical form when the parent does not exist.
_registry_phys_nofollow() {
    local p d
    p="$(_registry_normpath "$1")"
    d="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)" || { echo "$p"; return 0; }
    echo "${d%/}/$(basename "$p")"
}

# How folder <x> stands to the registered roots in <full> (the
# registry_entries_full lines). <mode> 'name' compares the path that names
# <x> (lexical, and with its parents resolved but <x> itself not followed);
# 'target' compares what <x> resolves to (physical). Each root, and each
# root's worktrees= folder (live worktrees: as much the project's as its
# root), is compared in the same forms (lexical, parents resolved,
# physical). Prints "<relation>\t<root name>\t<what>" for the first match:
# relation 'self' (the same folder), 'inside' (<x> lies in it) or 'holds'
# (it lies in <x>), 'self' first; <what> is 'root' or 'worktrees' (the
# root's worktrees= folder). Returns 1 when <x> stands in no relation to
# any of them.
# Usage: rel=$(_stale_root_relation "$full" "$x" name)
_stale_root_relation() {
    local full="$1" x="$2" mode="$3" name type path fields f r p what wt best="" bestname="" bestwhat=""
    local -a xs=() rs=()
    if [ "$mode" = name ]; then
        xs=("$(_registry_normpath "$x")" "$(_registry_phys_nofollow "$x")")
    else
        f="$(cd "$x" 2>/dev/null && pwd -P)" || return 1
        xs=("$f")
    fi
    while IFS=$'\t' read -r name type path fields; do
        [ -n "$name" ] || continue
        wt="$(_registry_field_of "$fields" worktrees)" || wt=""
        for what in root worktrees; do
            if [ "$what" = root ]; then p="$path"; else p="$wt"; fi
            [ -n "$p" ] || continue
            rs=("$(_registry_normpath "$p")" "$(_registry_phys_nofollow "$p")")
            f="$(cd "$p" 2>/dev/null && pwd -P)" && rs+=("$f")
            for f in "${xs[@]}"; do
                for r in "${rs[@]}"; do
                    if [ "$f" = "$r" ]; then
                        printf 'self\t%s\t%s\n' "$name" "$what"
                        return 0
                    elif [[ "$f" == "$r/"* ]]; then
                        [ -z "$best" ] && { best=inside; bestname="$name"; bestwhat="$what"; }
                    elif [[ "$r" == "$f/"* ]]; then
                        [ -z "$best" ] && { best=holds; bestname="$name"; bestwhat="$what"; }
                    fi
                done
            done
        done
    done <<< "$full"
    [ -n "$best" ] || return 1
    printf '%s\t%s\t%s\n' "$best" "$bestname" "$bestwhat"
}

# How a _stale_root_relation answer names what it matched: "registered
# project '<n>'" or "the worktrees= folder of registered project '<n>'".
_stale_relation_noun() {
    local rel="$1" name what
    IFS=$'\t' read -r _ name what <<< "$rel"
    if [ "$what" = worktrees ]; then
        echo "the worktrees= folder of registered project '$name'"
    else
        echo "registered project '$name'"
    fi
}

# What to check before removing a checkout, worktree or folder that may hold
# a repository: every hint that says remove or delete one uses this text
# (the retired-shape report here, worktree_remove.sh), so none forgets
# ignored files, stashes or commits no branch holds (a detached HEAD's).
# It reads as a clause: "..., <this>, remove it".
CHECK_BEFORE_REMOVING="after checking each repository in it for uncommitted, untracked and ignored files (git status --ignored), stashes (git stash list) and commits on no remote, detached ones included (git log --all --not --remotes), and keeping or pushing what you need"

# The line for one retired folder, <ws>/project or an entry under
# <ws>/projects/ (<label> is how the line names it), or nothing. The case
# table is in the header of tests/test_validate_workspace_stale.sh. Sets
# _STALE_UNREGISTERED=1 when it names a folder that is not registered (an
# old-order reader of the shared config file may have been it).
_stale_folder_line() {
    local root="$1" full="$2" x="$3" label="$4" rel target tabs qx
    # The path that names it is, holds or lies in a registered root: the
    # registry reads it (or reads through it), so it is silent.
    _stale_root_relation "$full" "$x" name >/dev/null && return 0
    # The path as the shell must read it in the printed command (a space in
    # the workspace path would otherwise split it).
    qx="$(printf '%q' "$x")"
    if [ -L "$x" ]; then
        target="$(readlink "$x")"
        if [ ! -e "$x" ]; then
            echo "$label is a link to $target, which does not exist; nothing reads the link any more: remove it (rm $qx)"
            return 0
        fi
        if ! tabs="$(cd "$x" 2>/dev/null && pwd -P)"; then
            echo "$label is a link to $target, which is not a folder; nothing reads the link any more: remove it (rm $qx)"
            return 0
        fi
        if rel="$(_stale_root_relation "$full" "$x" target)"; then
            case "${rel%%$'\t'*}" in
                self) echo "$label is a link to $(_stale_relation_noun "$rel"); nothing reads the link any more: remove the link (rm $qx)" ;;
                inside) echo "$label is a link to $tabs, inside $(_stale_relation_noun "$rel"); nothing reads the link any more: remove the link (rm $qx)" ;;
                holds) echo "$label is a link to $tabs, which holds $(_stale_relation_noun "$rel"); nothing reads the link any more: remove the link (rm $qx)" ;;
            esac
            return 0
        fi
        _STALE_UNREGISTERED=1
        echo "$label is a link to $target, which is not registered; nothing reads the link any more: register $tabs with .agent/scripts/register_project"".sh <path> if it is a project, and remove the link (rm $qx)"
        return 0
    fi
    [ -d "$x" ] || return 0
    _STALE_UNREGISTERED=1
    echo "$label is not registered; nothing reads it any more: register it with .agent/scripts/register_project"".sh <path>, or, $CHECK_BEFORE_REMOVING, remove it"
}

# The variables retired config file <file> sets (the read set's non-empty
# ones, then the extra ones), comma separated. Return 1 when it cannot be
# sourced.
_stale_set_names() {
    local file="$1" vals extra
    vals="$(_stale_config_values "$file")" || return 1
    extra="$(project_config_extra_vars "$file")" || return 1
    { [ -n "$vals" ] && cut -f1 <<< "$vals"; [ -n "$extra" ] && printf '%s\n' "$extra"; } | paste -sd, - | sed 's/,/, /g'
}

# The deepest a checkout sits under a retired worktree location in the
# layouts that used it (worktrees/project/<name>/<worktree>/<ws>/src/<repo>
# is 5); the scan goes no deeper.
_STALE_WORKTREE_SCAN_DEPTH=6

# The whole stale-shape report for the workspace whose registry is at
# <root> (the main checkout): one warning per line, nothing when the
# machine holds no retired shape. A root registered inside the workspace
# tree (projects/<name>, or <ws>/project itself) is silent: ADR-0016
# decision 1 allows it. A registry with errors gives one line saying so and
# nothing else: what is registered decides every other line, and a
# registry read as empty would advise removing registered checkouts. The
# case table every check follows is the header of
# tests/test_validate_workspace_stale.sh.
# Always returns 0 (a report, never a failure).
# Usage: registry_stale_report "$main_root"
registry_stale_report() {
    local root="$1" full name type path fields d dphys f n lines shared any
    local g applied rootdir plines setnames insts why where
    if ! full="$(registry_entries_full "$root" 2>/dev/null)"; then
        echo ".agent/projects.local has errors, so which retired shapes are still in use cannot be told: fix the registry (make validate names each bad line), then read this report again"
        return 0
    fi
    _STALE_UNREGISTERED=0
    # <ws>/project.
    if [ -L "$root/project" ] || [ -e "$root/project" ]; then
        _stale_folder_line "$root" "$full" "$root/project" project
    fi
    # The retired worktree locations: a checkout (a folder holding .git) left
    # under them that no registered root or worktrees= directory holds. The
    # walk stops at each checkout (never descending into it) and at
    # _STALE_WORKTREE_SCAN_DEPTH. Empty folders left after the worktrees were
    # removed are not named.
    for d in "$root/worktrees/project" "$root/.workspace-worktrees"; do
        [ -d "$d" ] || continue
        dphys="$(cd "$d" && pwd -P)" || continue
        while IFS= read -r g; do
            # A checkout that is, lies in or holds a registered root or a
            # root's worktrees= folder is the registry's: skipped.
            _stale_root_relation "$full" "$g" name >/dev/null && continue
            _STALE_UNREGISTERED=1
            # git worktree remove deletes ignored files without asking and
            # leaves a detached HEAD's commits on no branch, so the check
            # comes first for a worktree as for a plain clone.
            if [ "$d" = "$root/.workspace-worktrees" ]; then
                where="recreate it as a workspace worktree with .agent/scripts/worktree_create.sh --type workspace"
            else
                where="recreate it under its project's registered root with .agent/scripts/worktree_create.sh --type project"
            fi
            echo "${d#"$root/"}/ holds worktrees that are no longer found: for each, $CHECK_BEFORE_REMOVING, remove it (a worktree with git -C <its repository> worktree remove <path>; a plain clone, which is not a worktree, by moving or deleting it), then $where"
            break
        done < <(find "$dphys" -mindepth 1 -maxdepth "$_STALE_WORKTREE_SCAN_DEPTH" \
            \( -name .git -prune \) -o \( -type d -exec test -e '{}/.git' \; -prune -print \) 2>/dev/null)
    done
    # <ws>/projects/<entry>: a folder, a link, a link to nothing.
    if [ -d "$root/projects" ]; then
        for d in "$root/projects"/*; do
            [ -L "$d" ] || [ -d "$d" ] || continue
            _stale_folder_line "$root" "$full" "$d" "projects/$(basename "$d")"
        done
    fi
    # projects.d/<name>.sh, each read as the old layer of its project.
    for f in "$root/.agent/projects.d"/*.sh; do
        [ -f "$f" ] || continue
        n="$(basename "$f" .sh)"
        if ! type="$(registry_lookup "$root" "$n" 2>/dev/null | cut -f1)" || [ -z "$type" ]; then
            if ! setnames="$(_stale_set_names "$f")"; then
                echo ".agent/projects.d/$n.sh belongs to no registered project and cannot be sourced: read it by hand; if '$n' is a project not registered yet, register it first (.agent/scripts/register_project"".sh <path>) and this report names what to move; otherwise delete it"
            elif [ -n "$setnames" ]; then
                echo ".agent/projects.d/$n.sh belongs to no registered project and still sets $setnames: if '$n' is a project not registered yet, register it first (.agent/scripts/register_project"".sh <path>) and this report names what to move; otherwise delete it"
            else
                echo ".agent/projects.d/$n.sh belongs to no registered project and sets nothing; nothing reads it any more: delete it"
            fi
            continue
        fi
        if [ "$type" = "$REGISTRY_PARENT_TYPE" ]; then
            insts="$(registry_instances "$root" "$n" 2>/dev/null | paste -sd, - | sed 's/,/, /g')"
            if ! setnames="$(_stale_set_names "$f")"; then
                echo ".agent/projects.d/$n.sh belongs to parent root '$n', which has no settings of its own (its instances have theirs: ${insts:-none registered}), and cannot be sourced: read it by hand, move what an instance needs with .agent/scripts/project_setting.sh set <instance> <key>=<value> (a distro goes on the instance's line in .agent/projects.local), then delete it"
            elif [ -n "$setnames" ]; then
                echo ".agent/projects.d/$n.sh belongs to parent root '$n', which has no settings of its own (its instances have theirs: ${insts:-none registered}), and still sets $setnames: move what an instance needs with .agent/scripts/project_setting.sh set <instance> <key>=<value> (a distro goes on the instance's line in .agent/projects.local), then delete it"
            else
                echo ".agent/projects.d/$n.sh belongs to parent root '$n', which has no settings of its own, and sets nothing; nothing reads it any more: delete it"
            fi
            continue
        fi
        lines="$(registry_stale_settings_lines "$root" "$n" "$f")" || true
        if [ -n "$lines" ]; then
            printf '%s\n' "$lines"
        else
            echo ".agent/projects.d/$n.sh is no longer read and holds nothing left to move: delete it"
        fi
    done
    # The shared file: per registered project it applied to (no .sh of its
    # own), per key; its ROS_ROOT_DIR and extra-variable lines once, and
    # only when a project it applied to would have read them. While it
    # still sets something and applied to no registered project, or an
    # unregistered folder named above may have read it, it is never called
    # safe to delete.
    shared="$root/.agent/project_config.sh"
    if [ -f "$shared" ]; then
        any=0
        applied=0
        rootdir=0
        if lines="$(_stale_config_values "$shared")" && setnames="$(_stale_set_names "$shared")"; then
            while IFS=$'\t' read -r name type path fields; do
                [ -n "$name" ] || continue
                [ "$type" = "$REGISTRY_PARENT_TYPE" ] && continue
                [ -f "$root/.agent/projects.d/$name.sh" ] && continue
                applied=1
                _stale_type_reads "$root" "$type" ROS_ROOT_DIR && rootdir=1
                plines="$(registry_stale_settings_lines "$root" "$name" "$shared" 1)" || true
                [ -n "$plines" ] && { printf '%s\n' "$plines"; any=1; }
            done <<< "$full"
            local var val
            while IFS=$'\t' read -r var val; do
                if [ "$var" = ROS_ROOT_DIR ] && [ "$rootdir" -eq 1 ]; then
                    echo ".agent/project_config.sh sets ROS_ROOT_DIR=\"$val\", which is no longer read from a file: export ROS_ROOT_DIR=$val in the environment that runs the adapter"
                    any=1
                fi
            done <<< "$lines"
            if [ "$applied" -eq 1 ] && lines="$(project_config_extra_vars "$shared")" && [ -n "$lines" ]; then
                echo ".agent/project_config.sh sets or exports $(printf '%s' "$lines" | tr '\n' ' ' | sed 's/ $//; s/ /, /g'), which no command gets any more: move that environment into the scripts the projects' settings keys point at"
                any=1
            fi
            if [ -n "$setnames" ] && { [ "$applied" -eq 0 ] || [ "$_STALE_UNREGISTERED" -eq 1 ]; }; then
                if [ "$applied" -eq 0 ]; then
                    why="it applies to no registered project (none is registered, or each has its own .agent/projects.d/<name>.sh)"
                else
                    why="an unregistered folder or retired worktree named above may have used it"
                fi
                echo ".agent/project_config.sh still sets $setnames, and $why: register that project first (.agent/scripts/register_project"".sh <path>) and this report names what to move; delete the file only when no project needs it"
                any=1
            fi
        else
            echo ".agent/project_config.sh cannot be sourced, so what is left in it is unknown: read it by hand, move what it sets with .agent/scripts/project_setting.sh set <name> <key>=<value>, then delete it"
            any=1
        fi
        [ "$any" -eq 0 ] && echo ".agent/project_config.sh is no longer read and holds nothing left to move: delete it"
    fi
    return 0
}

# ------------------------------ per-type registration facts (#332, PR 2) ---
# .agent/project_types/<type>/registration.conf: what register_project.sh
# does for a project of that type, as data, so no script branches on a type
# name. The settings file's line grammar (key=value split at the first
# '=', blank lines and '#' comment lines ignored, CRLF tolerated); every
# key is required, once:
#   required_commands  'none', or the command settings (build test install)
#                      a project of the type must have of its own, or
#                      declare 'none'; registration_verify.sh refuses one
#                      the settings file does not set
#   setup              'never' (the checkout is the user's), or
#                      'when-missing' (register_project.sh runs `adapter
#                      setup` when the hosting directory does not exist)
#   run                'none', or the verbs (build test) register_project.sh
#                      runs after the static gate
_REGISTRATION_KEYS=" required_commands setup run "

# Usage: f=$(registration_conf_path "$root" "$type")
registration_conf_path() {
    echo "$1/.agent/project_types/$2/registration.conf"
}

# Check one value of registration.conf; prints the reason, return 1.
_registration_value_error() {
    local key="$1" value="$2" allowed w seen=" "
    local -a words=()
    case "$key" in
        setup)
            case "$value" in never|when-missing) return 0 ;; esac
            echo "setup must be 'never' or 'when-missing', got '$value'"
            return 1
            ;;
        required_commands) allowed=" build test install " ;;
        run) allowed=" build test " ;;
    esac
    [ "$value" = "none" ] && return 0
    read -r -a words <<< "$value"
    for w in "${words[@]}"; do
        if [ "$w" = "none" ]; then
            echo "$key: 'none' stands alone, got '$value'"
            return 1
        fi
        if [[ "$allowed" != *" $w "* ]]; then
            echo "$key: '$w' is not one of:${allowed% } (or 'none')"
            return 1
        fi
        if [[ "$seen" == *" $w "* ]]; then
            echo "$key: '$w' is listed twice"
            return 1
        fi
        seen="$seen$w "
    done
    return 0
}

# Parse registration.conf <file>. Prints "key<TAB>value" per key, or one
# problem per line ("<file>: line N: ..." or "<file>: ...") on stderr and
# returns 1. With <root> and <type>, a required command the type never
# reads (its unused_settings) is a problem too.
# Usage: entries=$(_registration_conf_parse "$file" [<root> <type>])
_registration_conf_parse() {
    local f="$1" root="${2:-}" ptype="${3:-}" raw line key value lineno=0 bad=0 seen=" " reason k known urc
    local -a out=()
    if [ ! -e "$f" ] && [ ! -L "$f" ]; then
        echo "$f: missing (every project type needs one: required_commands, setup, run)" >&2
        return 1
    fi
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
        echo "$f: exists but is not a readable file" >&2
        return 1
    fi
    known="${_REGISTRATION_KEYS# }"; known="${known% }"
    while IFS= read -r raw || [ -n "$raw" ]; do
        lineno=$((lineno + 1))
        line="$(_project_file_trim "${raw%$'\r'}")"
        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue
        if [[ "$line" != *=* ]]; then
            echo "$f: line $lineno: expected key=value, got '$line' (keys: $known)" >&2
            bad=1; continue
        fi
        key="$(_project_file_trim "${line%%=*}")"
        value="$(_project_file_trim "${line#*=}")"
        if ! _project_file_key_in "$key" "$_REGISTRATION_KEYS"; then
            echo "$f: line $lineno: unknown key '$key' (keys: $known)" >&2
            bad=1; continue
        fi
        if [[ "$seen" == *" $key "* ]]; then
            echo "$f: line $lineno: '$key' is set twice" >&2
            bad=1; continue
        fi
        seen="$seen$key "
        if [ -z "$value" ]; then
            echo "$f: line $lineno: empty value for '$key' (use 'none' for an empty list)" >&2
            bad=1; continue
        fi
        if ! reason="$(_registration_value_error "$key" "$value")"; then
            echo "$f: line $lineno: $reason" >&2
            bad=1; continue
        fi
        if [ "$key" = "required_commands" ] && [ -n "$ptype" ] && [ "$value" != "none" ]; then
            for k in $value; do
                urc=0; reason="$(_project_type_unused_setting "$root" "$ptype" "$k")" || urc=$?
                if [ "$urc" -eq 0 ]; then
                    echo "$f: line $lineno: '$k' is required, but the type's unused_settings says it never reads it ($reason)" >&2
                    bad=1
                elif [ "$urc" -eq 2 ]; then
                    echo "$f: line $lineno: cannot tell whether type $ptype reads '$k': $reason" >&2
                    bad=1
                fi
            done
        fi
        out+=("$key"$'\t'"$value")
    done < "$f"
    for k in $_REGISTRATION_KEYS; do
        if [[ "$seen" != *" $k "* ]]; then
            echo "$f: '$k' is not set (every key is required: $known)" >&2
            bad=1
        fi
    done
    [ "$bad" -eq 0 ] || return 1
    printf '%s\n' "${out[@]}"
}

# Problems with type <type>'s registration.conf under workspace <root>, one
# per line on stdout; return 1 when there are any. Used by
# validate_adapter.sh.
# Usage: registration_conf_problems "$root" "$type"
registration_conf_problems() {
    local out
    if ! out="$(_registration_conf_parse "$(registration_conf_path "$1" "$2")" "$1" "$2" 2>&1 >/dev/null)"; then
        printf '%s\n' "$out"
        return 1
    fi
    return 0
}

# Print the value of <key> in type <type>'s registration.conf, with 'none'
# printed as an empty line. Return 2 (problems on stderr) when the file is
# missing or invalid.
# Usage: run=$(registration_conf_get "$root" "$type" run)
registration_conf_get() {
    local entries v
    entries="$(_registration_conf_parse "$(registration_conf_path "$1" "$2")" "$1" "$2")" || return 2
    v="$(_project_file_value_of "$entries" "$3")" || return 2
    [ "$v" = "none" ] && v=""
    printf '%s\n' "$v"
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
# of one repository compare equal. tr, not ${1,,}: bash 3.2 (macOS
# /bin/bash) has no case conversion, and an empty result there would skip
# the workspace-remote refusal.
_records_norm_url() {
    local u
    u="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
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
# is not; prints why and returns 3 when it cannot tell yet: no repository
# at <dir>, or <dir> is not the top of a clone but lies inside another
# repository (a home dotfiles repository, say), which is not the records
# repository. That enclosing repository is still refused when it is a
# workspace, since records there would be committed into it.
# Checks: the same repository as the workspace checkout (any worktree);
# the workspace's marker files (contents, so a clone of a fork under any
# owner is caught offline); a local-path or file:// remote at the
# workspace checkout or one of its worktrees; a network remote equal to
# one of the workspace's.
_records_repo_workspace_reason() {
    local root="$1" dir="$2" top ws_common rec_common marker r url lpath lcommon norm wurl wnorm
    local here enclosed=0
    [ -d "$dir" ] || { echo "no directory there yet"; return 3; }
    top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || { echo "no git repository there yet"; return 3; }
    here="$(cd "$dir" 2>/dev/null && pwd -P)" || here="$dir"
    [ "$(cd "$top" 2>/dev/null && pwd -P)" = "$here" ] || enclosed=1
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
    if [ "$enclosed" -eq 1 ]; then
        echo "$dir is not the top of a clone: it lies inside the repository at $top"
        return 3
    fi
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
        # cut, not read: a tab is IFS whitespace, so read would collapse an
        # empty layout field and take the next field ("provisional").
        layout="$(cut -f3 <<< "$dflt")"
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
            echo "NOTE: project '$name': records repository $lpath is unverifiable until cloned ($reason)" >&2
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
# (set) or '-key' (remove; also an unknown key the file holds, so a
# misspelt key can be repaired). The result is validated as a whole file before
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
#
# Concurrency: the read-modify-rename runs in a subshell holding an
# exclusive flock on a sidecar beside the resolved destination,
# <dir>/.lock.<basename> (projects.d/.lock.<name> for an ordinary file;
# waits PROJECT_FILE_LOCK_WAIT seconds, default 10, then refuses), so two
# writers of one file never lose an update, even through two projects
# whose settings files are links to one target. A link repointed while
# the writer waited, or a file that stopped being a readable regular file
# (replaced by a directory, say), is refused. Without flock (macOS by
# default) the write is unlocked. The lock file is never removed: removing
# it while another writer has it open would let a third lock a new file of
# the same name and write alongside. So a settings file that is a link into
# another directory leaves an untracked .lock.<basename> there, beside its
# target (in a git checkout, ignore it).
# The temporary file is removed on every exit, INT, TERM and HUP included.
# A writer whose caller (the shell that ran project_file_set, $$ in the
# subshell) has ended, killed by PID while it waited, say, writes nothing:
# it checks once the lock is taken and again just before the rename or
# removal, so an orphan cannot overwrite a later set.
# Usage: project_file_set "$root" "$name" build=./b.sh -install
project_file_set() {
    ( _project_file_set_locked "$@" )
}

# The path the writer renames new contents onto: the file itself, or the
# target of a symlinked one, so the rename never replaces the link. Prints
# it, or the reason on stderr and returns 1 for a link that cannot be
# resolved.
_project_file_dest() {
    local file="$1" d
    if [ -L "$file" ]; then
        if ! d="$(readlink -f -- "$file" 2>/dev/null)" || [ -z "$d" ]; then
            echo "ERROR: $file is a symlink whose target cannot be resolved" >&2
            return 1
        fi
        printf '%s\n' "$d"
        return 0
    fi
    printf '%s\n' "$file"
}

# Is the shell that called project_file_set still running? In the
# subshell $$ is that caller's PID. Prints why on stderr and returns 1 when
# it has ended.
_project_file_caller_alive() {
    kill -0 "$$" 2>/dev/null && return 0
    echo "ERROR: not writing $1: the process that started this write ($$) has ended" >&2
    return 1
}

# The body of project_file_set, run in its own subshell (its traps and the
# lock's file descriptor end with it).
_project_file_set_locked() {
    local root="$1" name="$2" entry ptype file dest dir tmp arg key value i found line lkey
    local touches_records=0 reason entries rc=0 combo loc track lpath mode lock urc
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
        # An unknown key is refused, except that '-key' may remove one
        # the file holds (a misspelt key is repaired with unset).
        if ! _project_file_key_in "$key" "$_PROJECT_FILE_KEYS" \
            && ! { [ -n "$key" ] && [ -z "$value" ] && [[ "$arg" == -* ]] \
                   && _project_file_has_line_key "$(project_file_path "$root" "$name")" "$key"; }; then
            local known="${_PROJECT_FILE_KEYS# }"; known="${known% }"
            echo "ERROR: unknown key '$key' (known keys: $known)" >&2
            return 1
        fi
        if [[ "$value" == *$'\n'* ]] || [[ "$value" == *$'\r'* ]]; then
            echo "ERROR: the value for '$key' contains a line break" >&2
            return 1
        fi
        if [[ "$arg" != -* ]]; then
            urc=0; reason="$(_project_type_unused_setting "$root" "$ptype" "$key")" || urc=$?
            if [ "$urc" -eq 0 ]; then
                echo "ERROR: not setting '$key' for project '$name' (type $ptype): $reason" >&2
                return 1
            fi
            if [ "$urc" -eq 2 ]; then
                echo "ERROR: not setting '$key' for project '$name': $reason" >&2
                return 1
            fi
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
    # A path that exists but cannot be read as a settings file is never
    # treated as absent: its settings would be lost, or the new file moved
    # inside a directory. Checked before the lock, whose sidecar lives
    # beside the file (or beside the target of a symlinked one).
    if reason="$(_project_file_path_error "$file")"; then
        echo "ERROR: not writing: $reason (fix or remove it by hand first)" >&2
        return 1
    fi
    mkdir -p "$(dirname "$file")" || return 1
    dest="$(_project_file_dest "$file")" || return 1
    dir="$(dirname "$dest")"
    mkdir -p "$dir" || return 1
    # Serialize writers of the destination. The lock is a sidecar, not the
    # file: the rename replaces the file's inode, so a lock on the file
    # itself would not exclude the next writer. It is named after the
    # resolved destination, not the project, so two projects whose files
    # link to one target take one lock.
    lock="$dir/.lock.$(basename "$dest")"
    if command -v flock >/dev/null 2>&1; then
        if ! exec 9>>"$lock"; then
            echo "ERROR: cannot open the lock file $lock" >&2
            return 1
        fi
        if ! flock -x -w "${PROJECT_FILE_LOCK_WAIT:-10}" 9; then
            echo "ERROR: not writing $file: another writer holds its lock $lock (waited ${PROJECT_FILE_LOCK_WAIT:-10} s); try again" >&2
            return 1
        fi
        # The lock covers the destination resolved before it was taken; a
        # link repointed meanwhile would be written under the wrong lock.
        if [ "$(_project_file_dest "$file" 2>/dev/null)" != "$dest" ]; then
            echo "ERROR: not writing $file: it was changed while waiting for the lock $lock (it no longer leads to $dest); try again" >&2
            return 1
        fi
        # The same path may have stopped being a readable regular file
        # (replaced by a directory, say): mv would then move the new
        # contents inside it and report success.
        if reason="$(_project_file_path_error "$file")"; then
            echo "ERROR: not writing: $reason (changed while waiting for the lock $lock; fix or remove it by hand first)" >&2
            return 1
        fi
    fi
    # The caller may have been killed while this writer waited.
    _project_file_caller_alive "$file" || return 1
    # Remove the temporary file however this subshell ends.
    _PF_TMP=""
    trap 'rm -f -- "${_PF_TMP:-}"' EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    tmp="$(mktemp "$dir/.${name}.XXXXXX")" || return 1
    _PF_TMP="$tmp"
    # Each write stops the writer itself (the EXIT trap removes the
    # temporary file): a caller running project_file_set as a condition
    # (if, ||) turns set -e off, and a cut-off file would then be
    # validated and renamed, silently dropping a setting.
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
                    printf '%s\n' "$line" || exit 1
                elif [[ "${vals[$found]}" != -* ]] && [[ " ${done_k[*]-} " != *" $lkey "* ]]; then
                    printf '%s\n' "${vals[$found]}" || exit 1
                    done_k+=("$lkey")
                fi
            done < "$file"
        fi
        for ((i = 0; i < ${#keys[@]}; i++)); do
            [[ "${vals[$i]}" == -* ]] && continue
            [[ " ${done_k[*]-} " == *" ${keys[$i]} "* ]] && continue
            printf '%s\n' "${vals[$i]}" || exit 1
        done
    } > "$tmp"

    # Captures the parser's stderr only; its exit status is kept.
    if ! reason="$(_project_file_parse "$tmp" "$name" "$root" "$ptype" 2>&1 >/dev/null)"; then
        rm -f "$tmp"
        echo "ERROR: not writing $file: the result would be invalid:" >&2
        # Name the real file in the messages, not the temporary one.
        printf '%s\n' "${reason//$tmp/$file}" >&2
        return 2
    fi
    entries="$(_project_file_parse "$tmp" "$name" "$root" "$ptype")"
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
            _project_file_caller_alive "$file" || return 1
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
    _project_file_caller_alive "$file" || { rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$dest" || { rm -f "$tmp"; return 1; }
    _PF_TMP=""
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
