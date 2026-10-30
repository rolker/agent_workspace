#!/usr/bin/env bash
# .agent/scripts/registration_verify.sh
# The static gate for a registered project (issue #332): is its
# registration complete and usable? register_project.sh runs it after
# writing the registry line and the settings file, before it runs the
# project's build and test; the integration audit reads it too.
#
# Usage:
#   registration_verify.sh <name> [--user-tier]
#
# Checks, for a project of a type (a parent root has no adapter: only its
# entry and that no settings file sits under its name):
#   - the registry parses and <name> is registered
#   - the type's registration.conf exists and is valid
#   - the settings file .agent/projects.d/<name> is valid (malformed, a key
#     the type never reads, or a records repository that is a workspace
#     fail); a records combination other than the default is flagged "not
#     yet honoured" (#393), a warning
#   - every command the type requires (registration.conf required_commands)
#     is the project's own: its settings file (a command or 'none'), or its
#     legacy .agent/projects.d/<name>.sh. One that falls through to the
#     shared .agent/project_config.sh, or none at all, fails
#   - `adapter --project <name> validate`, scoped to this project
#   - a project root that is a git repository with no remote is a warning
#     (a project without GitHub is supported)
#   - with --user-tier: `user_tier_install.sh --check --require` passes,
#     and `session_root.sh --dir <root>` names this project
#
# It never runs the project's build or test (register_project.sh does),
# and writes nothing. Like project_setting.sh, from a linked worktree of
# the workspace it reads the main checkout's registry and settings files
# and runs the main checkout's adapter, since a worktree has none of its
# own.
#
# Output: one line per check (OK:, WARN:, FAIL:), then VERIFY=pass|fail.
# Exit codes: 0 pass (warnings allowed); 1 a check failed; 2 usage, an
# unregistered name, or a registry that does not parse.
#
# user-tier: inert -- read-only: prints a verdict and writes nothing. It
# runs the project's `adapter validate`, `user_tier_install.sh --check` and
# `session_root.sh`, all read-only; no gh call and no repo-changing git
# call.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

usage() {
    sed -n '/^# Usage:/,/^# Checks,/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//' >&2
}

NAME=""
USER_TIER=0
while [ $# -gt 0 ]; do
    case "$1" in
        --user-tier) USER_TIER=1; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "ERROR: unknown option '$1'" >&2; usage; exit 2 ;;
        *)
            if [ -n "$NAME" ]; then
                echo "ERROR: one project name only (got '$NAME' and '$1')" >&2
                exit 2
            fi
            NAME="$1"; shift ;;
    esac
done
[ -n "$NAME" ] || { usage; exit 2; }

# The main checkout (the parent of git's common dir) when this copy is a
# linked worktree: the registry and settings files are per machine and live
# only there.
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
MAIN_ROOT="$ROOT"
_GITDIR="$(cd "$ROOT" && cd "$(git rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || _GITDIR=""
_COMMON="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || _COMMON=""
if [ -n "$_GITDIR" ] && [ -n "$_COMMON" ] && [ "$_GITDIR" != "$_COMMON" ]; then
    MAIN_ROOT="$(dirname "$_COMMON")"
fi

FAILS=0
ok()   { echo "OK: $*"; }
warn() { echo "WARN: $*"; }
fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }
# Indent a block of captured output under the line that names it.
indent() { [ -n "$1" ] && printf '%s\n' "$1" | sed 's/^/    /'; }

_RC=0
ENTRY="$(registry_lookup "$MAIN_ROOT" "$NAME")" || _RC=$?
if [ "$_RC" -eq 2 ]; then
    echo "ERROR: the registry $(registry_file "$MAIN_ROOT") does not parse (above); fix it first" >&2
    exit 2
fi
if [ "$_RC" -ne 0 ]; then
    echo "ERROR: project '$NAME' is not registered in $(registry_file "$MAIN_ROOT")" >&2
    exit 2
fi
TYPE="$(cut -f1 <<< "$ENTRY")"
PROJECT_ROOT="$(cut -f2 <<< "$ENTRY")"
SETTINGS="$(project_file_path "$MAIN_ROOT" "$NAME")"
ok "registry entry: $NAME ($TYPE) at $PROJECT_ROOT"

if [ "$TYPE" = "$REGISTRY_PARENT_TYPE" ]; then
    INSTANCES="$(registry_instances "$MAIN_ROOT" "$NAME" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
    ok "parent root: no adapter of its own; its instances carry the settings (${INSTANCES:-none registered yet})"
    if [ -e "$SETTINGS" ] || [ -L "$SETTINGS" ]; then
        fail "$SETTINGS sits under a parent root's name, which nothing reads; set the settings on its instances and remove this file"
    fi
else
    # The type's registration facts.
    _CONF_ERR=""
    if ! REQUIRED="$(registration_conf_get "$MAIN_ROOT" "$TYPE" required_commands 2>/dev/null)"; then
        _CONF_ERR="$(registration_conf_problems "$MAIN_ROOT" "$TYPE")"
        fail "type '$TYPE' has no valid registration.conf, so what its registration needs is unknown:"
        indent "$_CONF_ERR"
        REQUIRED=""
    else
        ok "type '$TYPE': registration.conf is valid"
    fi

    # The settings file, and its records settings.
    _RC=0
    _ERR="$(project_records_check "$MAIN_ROOT" "$NAME" 2>&1 >/dev/null)" || _RC=$?
    case "$_RC" in
        0)
            if [ -f "$SETTINGS" ]; then ok "settings file $SETTINGS is valid"
            else ok "no settings file ($SETTINGS); every setting at its default"; fi ;;
        3)
            ok "settings file $SETTINGS is valid"
            warn "records settings are valid but not yet honoured ($PROJECT_RECORDS_LOOKUP_ISSUE):"
            indent "$_ERR" ;;
        *)
            fail "settings file $SETTINGS is invalid (check it with: .agent/scripts/project_setting.sh check $NAME):"
            indent "$_ERR" ;;
    esac

    # Each command the type requires is the project's own.
    for KEY in $REQUIRED; do
        _RC=0
        _SRC="$(project_command_source "$MAIN_ROOT" "$NAME" "$KEY" 2>&1)" || _RC=$?
        if [ "$_RC" -ne 0 ]; then
            fail "cannot tell where the $KEY command comes from:"
            indent "$_SRC"
            continue
        fi
        _FROM="$(cut -f1 <<< "$_SRC")"
        _VAL="$(cut -f2- <<< "$_SRC")"
        case "$_FROM" in
            file)
                ok "$KEY: $_VAL (settings file)" ;;
            legacy)
                ok "$KEY: $_VAL (legacy $MAIN_ROOT/.agent/projects.d/$NAME.sh, read until #265 PR 4 retires it)" ;;
            shared)
                fail "$KEY falls through to the shared .agent/project_config.sh ('$_VAL'), which is not this project's own: set it with .agent/scripts/project_setting.sh set $NAME $KEY=<command> (a script path when it needs a shell), or $KEY=none" ;;
            *)
                fail "no $KEY command: set it with .agent/scripts/project_setting.sh set $NAME $KEY=<command> (a script path when it needs a shell), or $KEY=none to record that the project has none" ;;
        esac
    done

    # The checkout itself, scoped to this project.
    _RC=0
    _OUT="$("$MAIN_ROOT/.agent/scripts/adapter" --from "$MAIN_ROOT" --project "$NAME" validate 2>&1)" || _RC=$?
    if [ "$_RC" -eq 0 ]; then
        ok "adapter validate passed"
    else
        fail "adapter --project $NAME validate failed (exit $_RC):"
        indent "$_OUT"
    fi

    # A git checkout with no remote is supported (no GitHub), but worth saying.
    if [ -e "$PROJECT_ROOT/.git" ] && [ -z "$(git -C "$PROJECT_ROOT" remote 2>/dev/null)" ]; then
        warn "$PROJECT_ROOT has no git remote: supported (a project without GitHub), but nothing the workspace does with issues or pull requests will work there"
    fi
fi

if [ "$USER_TIER" -eq 1 ]; then
    _RC=0
    _OUT="$("$MAIN_ROOT/.agent/scripts/user_tier_install.sh" --check --require 2>&1)" || _RC=$?
    if [ "$_RC" -eq 0 ]; then
        ok "user tier installed and current"
    else
        fail "user_tier_install.sh --check --require failed (exit $_RC):"
        indent "$_OUT"
    fi
    if [ -d "$PROJECT_ROOT" ]; then
        _RC=0
        _OUT="$("$MAIN_ROOT/.agent/scripts/session_root.sh" --dir "$PROJECT_ROOT" 2>&1)" || _RC=$?
        _PROJ="$(sed -n 's/^project=//p' <<< "$_OUT")"
        if [ "$_RC" -eq 0 ] && [ "$_PROJ" = "$NAME" ]; then
            ok "a session started at $PROJECT_ROOT has root '$NAME'"
        else
            fail "a session started at $PROJECT_ROOT does not resolve to '$NAME' (session_root.sh exit $_RC):"
            indent "$_OUT"
        fi
    else
        warn "$PROJECT_ROOT is not on disk, so no session can start there yet"
    fi
fi

if [ "$FAILS" -eq 0 ]; then
    echo "VERIFY=pass"
    exit 0
fi
echo "VERIFY=fail"
exit 1
