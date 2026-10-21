#!/usr/bin/env bash
# .agent/scripts/project_setting.sh
# Read and write a registered project's settings file,
# .agent/projects.d/<name> (issue #332). The grammar and the keys are in the
# header of _project_registry.sh and in .agent/projects.local.example.
#
# Usage:
#   project_setting.sh get   <name> <key>          print the stored value
#   project_setting.sh set   <name> <key=value>... set keys (validated as
#                                                   the whole resulting file)
#   project_setting.sh unset <name> <key>...        remove keys (also an
#                                                   unknown key the file
#                                                   holds, e.g. a misspelt one)
#   project_setting.sh list  <name>                 stored keys, then the
#                                                   resolved records settings
#   project_setting.sh check <name>                 validate the file and its
#                                                   records settings
#
# Records keys (location, location_path, tracking) are set and removed
# together, e.g. `set <name> location=project tracking=project`. Until the
# records lookup lands (#393) only the default combination (project,
# project) is stored: `set` refuses any other, and `check` flags a
# hand-written one as "not yet honoured".
#
# The registry and the settings files are per machine and gitignored, so a
# linked worktree of the workspace has none of its own: run from one, this
# script reads the main checkout's files (get, list, check) and refuses to
# write (set, unset) — run the main checkout's copy instead.
#
# Exit codes:
#   0  done; for check: valid, and honoured today
#   1  usage error, unknown project, absent key (get), or a refused write
#   2  the settings file is invalid (malformed, or records settings refused:
#      a records repository must not be a workspace), or the registry
#      .agent/projects.local is malformed (every command, before the
#      project is looked up)
#   3  check only: valid, but records settings not yet honoured (#393)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

usage() {
    sed -n '/^# Usage:/,/^# Records keys/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//' >&2
}

# The workspace checkout this copy belongs to, and the main checkout when
# it is a linked worktree (the parent of git's common dir).
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
MAIN_ROOT="$ROOT"
_GITDIR="$(cd "$ROOT" && cd "$(git rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || _GITDIR=""
_COMMON="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || _COMMON=""
IN_WORKTREE=0
if [ -n "$_GITDIR" ] && [ -n "$_COMMON" ] && [ "$_GITDIR" != "$_COMMON" ]; then
    IN_WORKTREE=1
    MAIN_ROOT="$(dirname "$_COMMON")"
fi

[ $# -ge 1 ] || { usage; exit 1; }
CMD="$1"
shift
case "$CMD" in
    -h|--help) usage; exit 0 ;;
    get|set|unset|list|check) ;;
    *) echo "ERROR: unknown command '$CMD'" >&2; usage; exit 1 ;;
esac
[ $# -ge 1 ] || { echo "ERROR: $CMD needs a project name" >&2; usage; exit 1; }
NAME="$1"
shift

# The project must be registered (in the main checkout's registry).
_RC=0
registry_lookup "$MAIN_ROOT" "$NAME" >/dev/null || _RC=$?
if [ "$_RC" -eq 2 ]; then
    echo "ERROR: the registry $(registry_file "$MAIN_ROOT") has errors (above); fix it first" >&2
    exit 2
fi
if [ "$_RC" -ne 0 ]; then
    echo "ERROR: project '$NAME' is not registered in $(registry_file "$MAIN_ROOT")" >&2
    exit 1
fi
FILE="$(project_file_path "$MAIN_ROOT" "$NAME")"

case "$CMD" in
    get)
        [ $# -eq 1 ] || { echo "ERROR: get takes one key" >&2; exit 1; }
        _RC=0
        project_file_get "$MAIN_ROOT" "$NAME" "$1" || _RC=$?
        [ "$_RC" -eq 1 ] && echo "($1 is not set in $FILE)" >&2
        exit "$_RC"
        ;;
    set|unset)
        if [ "$IN_WORKTREE" -eq 1 ]; then
            echo "ERROR: refusing to write from a linked worktree ($ROOT): the settings files are per machine and live in the main checkout. Run: $MAIN_ROOT/.agent/scripts/project_setting.sh $CMD $NAME $*" >&2
            exit 1
        fi
        [ $# -ge 1 ] || { echo "ERROR: $CMD needs at least one key" >&2; exit 1; }
        if [ "$CMD" = "set" ]; then
            for _arg in "$@"; do
                if [[ "$_arg" != *=* ]]; then
                    echo "ERROR: set takes key=value arguments, got '$_arg' (to remove a key: unset $NAME $_arg)" >&2
                    exit 1
                fi
            done
            project_file_set "$MAIN_ROOT" "$NAME" "$@"
        else
            for _arg in "$@"; do
                if [[ "$_arg" == *=* ]]; then
                    echo "ERROR: unset takes key names, got '$_arg'" >&2
                    exit 1
                fi
            done
            project_file_unset "$MAIN_ROOT" "$NAME" "$@"
        fi
        ;;
    list)
        [ $# -eq 0 ] || { echo "ERROR: list takes no arguments" >&2; exit 1; }
        ENTRIES="$(project_file_entries "$MAIN_ROOT" "$NAME")" || exit 2
        echo "# $FILE"
        if [ -n "$ENTRIES" ]; then
            while IFS=$'\t' read -r _k _v; do
                printf '%s=%s\n' "$_k" "$_v"
            done <<< "$ENTRIES"
        else
            echo "# (no settings stored; every setting at its default)"
        fi
        _RC=0
        _REC="$(_project_records_check_entries "$MAIN_ROOT" "$NAME" "$ENTRIES" 2>/dev/null)" || _RC=$?
        [ "$_RC" -eq 2 ] && { echo "# records: refused (run: project_setting.sh check $NAME)"; exit 2; }
        IFS=$'\t' read -r _loc _track _lpath <<< "$_REC"
        _note=""
        _project_file_value_of "$ENTRIES" location >/dev/null || _note=" (location: default, provisional)"
        _project_file_value_of "$ENTRIES" tracking >/dev/null || _note="$_note (tracking: default, provisional)"
        echo "# records: location=$_loc tracking=$_track${_lpath:+ location_path=$_lpath}$_note"
        [ "$_RC" -eq 3 ] && echo "# records: not yet honoured ($PROJECT_RECORDS_LOOKUP_ISSUE)"
        exit 0
        ;;
    check)
        [ $# -eq 0 ] || { echo "ERROR: check takes no arguments" >&2; exit 1; }
        ENTRIES="$(project_file_entries "$MAIN_ROOT" "$NAME")" || {
            echo "INVALID: $FILE" >&2
            exit 2
        }
        _RC=0
        _REC="$(_project_records_check_entries "$MAIN_ROOT" "$NAME" "$ENTRIES")" || _RC=$?
        if [ "$_RC" -eq 2 ]; then
            echo "INVALID: $FILE" >&2
            exit 2
        fi
        IFS=$'\t' read -r _loc _track _lpath <<< "$_REC"
        if [ -f "$FILE" ]; then
            echo "OK: $FILE"
        else
            echo "OK: no settings file for '$NAME' ($FILE); every setting at its default"
        fi
        echo "records: location=$_loc tracking=$_track${_lpath:+ location_path=$_lpath}"
        exit "$_RC"
        ;;
esac
