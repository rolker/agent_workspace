#!/usr/bin/env bash
# .agent/scripts/register_session_root.sh
# Register the folder this session was started in, from that session
# (#466, ADR-0021). `/agent-workspace:onboard-project`, run in a session
# started in a folder that is not registered, uses it to register the
# folder and then carries on onboarding. It writes what registration from
# the workspace writes -- the folder's own line in the workspace's registry
# and its settings file -- and nothing else, by handing over to
# register_project.sh in the workspace's main checkout.
#
# Usage:
#   register_session_root.sh [--dry-run] [--set build=<command>]
#                            [--set test=<command>]
#
#   The folder is the current directory (its pwd -P form): there is no
#   path argument, and no other option. --set takes only build= and test=,
#   each at most once; register_project.sh validates the values. A key
#   with no --set is detected from the folder's files at this run, or,
#   when a settings file under the folder's name is kept, taken from that
#   file. So onboard-project passes the commands as --set on the real
#   call, the same arguments its second dry run checked: the permission
#   prompt then shows the build and test commands written (a kept file's
#   other keys are shown only in the skill's question), and a folder
#   changed since the dry run cannot change them.
#   --dry-run prints what registration would write and writes nothing.
#
# Refused, exit 1, before anything is handed over (nothing written):
#   - the folder is already a registered root: onboard it instead. Checked
#     here because register_project.sh reads a registered path as adopting
#     that registration and would write the --set keys into its settings
#     file;
#   - it lies inside a registered root (or a root's worktrees= directory),
#     or inside the workspace checkout or its repository;
#   - it contains a registered root or the workspace checkout (a session in
#     the home directory, say);
#   - it is in a git repository but not at its top (start the session at
#     the top), or it is a linked worktree (register the main checkout);
#   - its name is not a valid project name (register_project.sh's rule) or
#     is already registered (register it from the workspace with
#     register_project.sh --name).
# Exit 2: a usage error, or a registry that does not parse.
#
# Then: register_project.sh <folder> --skip-run [--dry-run] [--set ...],
# from the main checkout of this script's own repository. The build and
# test are not run (the status says so), and --install-user-tier is never
# passed: the installer rewrites ~/.claude, which no project session does.
# The output and the exit code from there on are register_project.sh's
# (its STATUS=, NAME=, ROOT=, NEXT= lines). Its refusal of a name or a
# path it finds registered under its lock stands; a path registered by
# another call between the checks here and that lock would be adopted.
#
# A folder in no git repository: register_project.sh's gate (adapter
# validate, through registration_verify.sh) refuses it and rolls back, so
# registration needs a git repository today. A dry run does not run the
# gate, so it looks clean until the real run refuses.
#
# Not promoted to the user tier (ADR-0016 decision 6;
# .agent/user_tier_scripts.txt names it among the scripts never promoted),
# so no permission rule allows it: each call asks for permission, showing
# the full command, unless the owner has allowed the command himself (a
# "don't ask again" answer, auto mode, a broader allow rule). A session in
# a folder he does not trust must not be able to register the folder, and
# so make its own build command runnable by the promoted build.sh, without
# him seeing the full command. The prompt is a gate, not the yes:
# onboard-project asks his yes in text before the real call.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The main checkout of this script's own repository, resolved as
# session_root.sh does (the registry is gitignored, so a worktree has
# none); outside any git repository, the script's own checkout.
WS_ROOT="$({ git -C "$SCRIPT_DIR" worktree list --porcelain 2>/dev/null | head -n1 | sed 's/^worktree //'; } || true)"
[[ -n "$WS_ROOT" ]] || WS_ROOT="$SCRIPT_DIR/../.."
WS_ROOT="$(cd "$WS_ROOT" && pwd -P)"
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

usage() {
    echo "usage: register_session_root.sh [--dry-run] [--set build=<command>] [--set test=<command>]" >&2
    exit 2
}

DRY_RUN=0
SETS=()
SEEN=" "
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --set)
            [[ $# -ge 2 ]] || usage
            case "$2" in
                build=?*|test=?*) ;;
                *) echo "register_session_root: --set takes only build=<command> or test=<command>, got '$2'" >&2; exit 2 ;;
            esac
            _k="${2%%=*}"
            [[ "$SEEN" == *" $_k "* ]] && { echo "register_session_root: --set $_k given twice" >&2; exit 2; }
            SEEN="$SEEN$_k "
            SETS+=(--set "$2")
            shift 2 ;;
        -h|--help)
            sed -n '2,/^set -uo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'
            exit 0 ;;
        *) usage ;;
    esac
done

refuse() {
    echo "register_session_root: refusing to register $HERE: $*" >&2
    exit 1
}

HERE="$(pwd -P)" || { echo "register_session_root: cannot read the current directory" >&2; exit 1; }
phys() { (cd "$1" 2>/dev/null && pwd -P) || _registry_normpath "$1"; }
common_dir() {  # <dir>: its git common dir (pwd -P), or empty
    local c
    c="$(cd "$1" 2>/dev/null && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
    [[ -n "$c" ]] || return 0
    phys "$c"
}

ENTRIES="$(registry_entries_full "$WS_ROOT")" || {
    echo "register_session_root: cannot parse $(registry_file "$WS_ROOT") (above)" >&2
    exit 2
}

# Already registered, or inside a registered root (worktrees= included).
rc=0
entry="$(registry_resolve_session_dir "$WS_ROOT" "$HERE")" || rc=$?
[[ $rc -eq 2 ]] && exit 2
if [[ $rc -eq 0 ]]; then
    IFS=$'\t' read -r r_name _r_type r_path <<< "$entry"
    if [[ "$(phys "$r_path")" == "$HERE" ]]; then
        refuse "it is already registered as '$r_name'; nothing to register (run /agent-workspace:onboard-project to onboard it)"
    fi
    refuse "it lies inside the registered root of '$r_name' ($r_path); a session works only under its own root, so start the session at $r_path"
fi

# Inside the workspace checkout, or a worktree of its repository.
WS_REPO="$(common_dir "$WS_ROOT")"
if [[ "$HERE" == "$WS_ROOT" || "$HERE" == "$WS_ROOT"/* ]] \
        || [[ -n "$WS_REPO" && "$(common_dir "$HERE")" == "$WS_REPO" ]]; then
    refuse "it is in the workspace checkout ($WS_ROOT) or its repository, which is no project"
fi

# Over a registered root or the workspace.
if _registry_path_under "$WS_ROOT" "$HERE"; then
    refuse "the workspace checkout ($WS_ROOT) lies inside it; a folder that contains the workspace is no project"
fi
while IFS=$'\t' read -r o_name _o_type o_path _o_fields; do
    [[ -n "$o_name" ]] || continue
    if _registry_path_under "$(phys "$o_path")" "$HERE"; then
        refuse "the registered root of '$o_name' ($o_path) lies inside it; a folder that contains a registered root is no project of its own"
    fi
done <<< "$ENTRIES"

# The top of its git repository, and not a linked worktree.
if top="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$top" ]]; then
    top="$(phys "$top")"
    if [[ "$top" != "$HERE" ]]; then
        refuse "it is inside the git repository at $top but not at its top; start the session at $top"
    fi
    gd="$(phys "$(git -C "$HERE" rev-parse --path-format=absolute --git-dir 2>/dev/null)")"
    cd_="$(common_dir "$HERE")"
    if [[ -n "$gd" && -n "$cd_" && "$gd" != "$cd_" ]]; then
        refuse "it is a linked worktree of the repository whose main checkout is $(dirname "$cd_"); start the session at the main checkout and register that"
    fi
fi

# Its name, the folder's own: register_project.sh's refusals would point at
# --name, which this script does not take. The name rule is
# register_project.sh's.
NAME="$(basename "$HERE")"
if ! [[ "$NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || [[ "$NAME" == *..* ]] || [[ "$NAME" == *.[sS][hH] ]]; then
    refuse "its name '$NAME' is not a valid project name ([A-Za-z0-9][A-Za-z0-9._-]*, no '..', not ending in .sh); register it under another name from a workspace session: $WS_ROOT/.agent/scripts/register_project.sh $HERE --name <name>"
fi
if other="$(registry_lookup "$WS_ROOT" "$NAME" 2>/dev/null)"; then
    refuse "the name '$NAME' is already registered, at $(cut -f2 <<< "$other"); register this folder under another name from a workspace session: $WS_ROOT/.agent/scripts/register_project.sh $HERE --name <name>"
fi

REGISTER="$WS_ROOT/.agent/scripts/register_project.sh"
[[ -x "$REGISTER" ]] || { echo "register_session_root: $REGISTER is missing or not executable" >&2; exit 1; }

ARGS=("$HERE" --skip-run)
[[ $DRY_RUN -eq 1 ]] && ARGS+=(--dry-run)
ARGS+=(${SETS[@]+"${SETS[@]}"})
exec "$REGISTER" "${ARGS[@]}"
