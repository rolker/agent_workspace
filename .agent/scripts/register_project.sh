#!/usr/bin/env bash
# .agent/scripts/register_project.sh
# Register a project with this workspace, or remove one (issue #332, D1
# step 1). The workspace side of onboarding: it writes the registry line
# and the project's settings file, checks them, runs the project's build
# and test, and enables the workspace plugin at the project's root. The
# project side (D1 step 2) is `/agent-workspace:onboard-project`, run in a
# session started at the project root.
#
# Usage:
#   register_project.sh <path|name> [<type>] [--name N] [--parent P]
#                       [--distro D] [--role R] [--worktrees W]
#                       [--default-instance I] [--set key=value]...
#                       [--no-setup] [--skip-run] [--install-user-tier]
#                       [--dry-run]
#   register_project.sh --remove <name> [--keep-settings] [--dry-run]
#   register_project.sh --detect <path>
#
#   <path|name>    the project's root (written to the registry as an
#                  absolute path, never the projects/<name> default), or the
#                  name of a project already registered (adoption, below).
#                  A bare word that is a registered name is that project;
#                  otherwise a relative path needs a '/' (./x) unless that
#                  directory exists.
#   <type>         single_project, ros2_colcon, or the pseudo-type project
#                  (a parent root grouping instances). Omitted: ros2_colcon
#                  when <path>/configs/manifest exists or --set
#                  bootstrap_url=... is given, else single_project.
#   --name N       the project's name (default: the directory's name)
#   --parent, --distro, --role, --worktrees, --default-instance
#                  the registry's trailing fields (_project_registry.sh
#                  header); --worktrees is written as an absolute path
#   --set key=value  a settings-file key (project_setting.sh's keys), e.g.
#                  --set build=./scripts/build.sh --set test=none
#   --no-setup     never run `adapter setup`, even for a type whose
#                  registration.conf runs it when the directory is missing
#   --skip-run     do not run the build and test verbs; the status says so
#   --install-user-tier
#                  run user_tier_install.sh even when the user tier is not
#                  installed yet (it then installs it)
#   --dry-run      print every step it would take, and write nothing
#   --remove N     unregister: refused while the root has live worktrees
#                  or is a parent with instances; disables the plugin in
#                  the root, then removes the registry line and the settings
#                  file (printed first, so it can be restored). The project,
#                  its records and its memory are left alone.
#   --keep-settings  with --remove: keep the settings file
#   --detect P     read-only: print the build and test commands the files
#                  at P propose, one key=value per line (notes on stderr).
#                  Only a single correct command is proposed: a Makefile,
#                  Cargo.toml, go.mod, package.json scripts, a pytest
#                  config. CMake needs configure then build, which is not
#                  one command, so nothing is proposed: point build= at a
#                  script.
#
# Registering, in order, so a failed registration leaves nothing behind:
#   1. write the registry line (a temporary copy, re-parsed, then renamed)
#      and the settings file. Its command keys come from --set, else the
#      legacy .agent/projects.d/<name>.sh, else --detect's proposals.
#      Then, when the type's registration.conf says setup=when-missing and
#      the hosting directory does not exist, `adapter setup`.
#   2. the static gate, registration_verify.sh <name> (read-only).
#   3. the verbs registration.conf names in run= (build, test), unless
#      --skip-run.
#   4. only then the user tier: when ~/.claude/agent-workspace-root names
#      this checkout (or with --install-user-tier), user_tier_install.sh,
#      then registration_verify.sh <name> --user-tier. Otherwise a warning
#      and the next step, not a failure.
# A failure in 1 to 4 removes the registry line and the settings file (on
# INT, TERM and HUP too); after the installer ran it first calls
# user_tier_install.sh --disable-root <name>. A hosting directory that
# setup created is kept and named on KEPT= (its clones are slow to redo,
# and a re-run reuses it); a directory that existed before is never
# touched. The type's facts come from
# .agent/project_types/<type>/registration.conf, so this script names no
# type; a type without one is refused.
#
# Adopting a project that is already registered (by hand, or before) is
# the same command on its name or path: its registry line is kept as it
# is (a different type or path, or a field with a different value, is
# refused: no silent rewrite; the one exception is adding a missing
# default_instance to a parent root, which can only be set once its
# instances are registered). A project with no settings file gets one
# (the legacy .sh values copied, then detection); one with a file gets
# only the --set keys. Adoption warns, naming each, when the config the
# project used to read (its legacy .sh, else the shared project_config.sh)
# sets or exports variables beyond the ones the adapters read: a command
# in the settings file runs without sourcing it, so that environment no
# longer reaches the command, and belongs in the script the key points at.
# An adopted project that fails a check is reported NOT READY and kept,
# never rolled back. A second identical run changes nothing and says so.
#
# Runs only from the main checkout: the registry and settings files are per
# machine and gitignored, so a linked worktree has none (--detect excepted).
# It never writes into the project. It is not promoted to the user tier.
#
# Last output lines (stable, for skills and tests):
#   STATUS=registered | registered, <verbs> not run | NOT READY | refused
#          | removed | dry-run
#   NAME=<name>
#   ROOT=<the project's root>
#   KEPT=<dir>                 only when setup created a directory that a
#                              failed registration keeps
#   NEXT=<what to do next>
#
# Exit codes: 0 registered (or removed, or a dry run); 1 refused, NOT
# READY, or a failure; 2 usage.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
ADAPTER="$SCRIPT_DIR/adapter"
VERIFY="$SCRIPT_DIR/registration_verify.sh"
INSTALLER="$SCRIPT_DIR/user_tier_install.sh"

usage() {
    sed -n '/^# Usage:/,/^# Registering, in order/p' "${BASH_SOURCE[0]}" | sed -e '$d' -e 's/^# \{0,1\}//' >&2
}

die_usage() { echo "ERROR: $*" >&2; exit 2; }

# ------------------------------------------------------------ arguments ---
MODE="register"
TARGET=""
TYPE_ARG=""
NAME_ARG=""
SETS=()
NO_SETUP=0
SKIP_RUN=0
INSTALL_UT=0
DRY_RUN=0
KEEP_SETTINGS=0
# Trailing registry fields given on the command line, in this order; each
# is read indirectly through its F_<key> variable.
FIELD_KEYS="parent distro role worktrees default_instance"
# shellcheck disable=SC2034  # read as ${!_v} below
F_parent="" F_distro="" F_role="" F_worktrees="" F_default_instance=""

need_value() { [ $# -ge 2 ] && [ -n "$2" ] || die_usage "$1 needs a value"; }
set_mode() {
    [ "$MODE" = "register" ] || [ "$MODE" = "$1" ] || die_usage "--$1 and --$MODE cannot be combined"
    MODE="$1"
}
while [ $# -gt 0 ]; do
    case "$1" in
        --detect) need_value "$@"; set_mode detect; TARGET="$2"; shift 2 ;;
        --remove) need_value "$@"; set_mode remove; TARGET="$2"; shift 2 ;;
        --name) need_value "$@"; NAME_ARG="$2"; shift 2 ;;
        --parent|--distro|--role|--worktrees|--default-instance)
            need_value "$@"; _k="${1#--}"; printf -v "F_${_k//-/_}" '%s' "$2"; shift 2 ;;
        --set) need_value "$@"; SETS+=("$2"); shift 2 ;;
        --no-setup) NO_SETUP=1; shift ;;
        --skip-run) SKIP_RUN=1; shift ;;
        --install-user-tier) INSTALL_UT=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --keep-settings) KEEP_SETTINGS=1; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) die_usage "unknown option '$1' (see --help)" ;;
        *)
            if [ -z "$TARGET" ] && [ "$MODE" = "register" ]; then TARGET="$1"
            elif [ -z "$TYPE_ARG" ] && [ "$MODE" = "register" ]; then TYPE_ARG="$1"
            else die_usage "unexpected argument '$1'"
            fi
            shift ;;
    esac
done
[ -n "$TARGET" ] || { usage; exit 2; }

REGISTER_ONLY_GIVEN=0
for _f in $FIELD_KEYS; do
    _v="F_$_f"
    [ -n "${!_v}" ] && REGISTER_ONLY_GIVEN=1
done
if [ -n "$NAME_ARG" ] || [ "${#SETS[@]}" -gt 0 ] || [ "$NO_SETUP" -eq 1 ] || [ "$SKIP_RUN" -eq 1 ] \
   || [ "$INSTALL_UT" -eq 1 ] || [ -n "$TYPE_ARG" ]; then
    REGISTER_ONLY_GIVEN=1
fi
case "$MODE" in
    detect)
        [ "$REGISTER_ONLY_GIVEN" -eq 0 ] && [ "$DRY_RUN" -eq 0 ] && [ "$KEEP_SETTINGS" -eq 0 ] \
            || die_usage "--detect takes only a path"
        ;;
    remove)
        [ "$REGISTER_ONLY_GIVEN" -eq 0 ] || die_usage "--remove takes only a name, --keep-settings and --dry-run"
        ;;
    register)
        [ "$KEEP_SETTINGS" -eq 0 ] || die_usage "--keep-settings goes with --remove"
        ;;
esac

# ------------------------------------------------------------ detection ---

# Print the build and test commands the files in <dir> propose, one
# key=value line each; notes on stderr. Read-only.
detect_commands() {
    local d="$1" mk="" mgr key cands n
    local b_list="" t_list=""   # "command|source" lines
    add() { # <key> <command> <source>
        if [ "$1" = build ]; then b_list="$b_list$2|$3"$'\n'; else t_list="$t_list$2|$3"$'\n'; fi
    }
    for n in GNUmakefile makefile Makefile; do
        [ -f "$d/$n" ] && { mk="$d/$n"; break; }
    done
    if [ -n "$mk" ]; then
        add build "make" "$(basename "$mk")"
        if grep -qE '^test[[:space:]]*:' "$mk"; then
            add test "make test" "$(basename "$mk") test target"
        fi
    fi
    if [ -f "$d/Cargo.toml" ]; then
        add build "cargo build" Cargo.toml
        add test "cargo test" Cargo.toml
    fi
    if [ -f "$d/go.mod" ]; then
        add build "go build ./..." go.mod
        add test "go test ./..." go.mod
    fi
    if [ -f "$d/package.json" ]; then
        mgr=npm
        [ -f "$d/yarn.lock" ] && mgr=yarn
        [ -f "$d/pnpm-lock.yaml" ] && mgr=pnpm
        local sb="" st=""
        if command -v jq >/dev/null 2>&1; then
            sb="$(jq -r '.scripts.build // empty' "$d/package.json" 2>/dev/null)" || sb=""
            st="$(jq -r '.scripts.test // empty' "$d/package.json" 2>/dev/null)" || st=""
        elif command -v python3 >/dev/null 2>&1; then
            sb="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("scripts",{}).get("build",""))' "$d/package.json" 2>/dev/null)" || sb=""
            st="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("scripts",{}).get("test",""))' "$d/package.json" 2>/dev/null)" || st=""
        else
            echo "note: package.json found, but neither jq nor python3 is available to read its scripts" >&2
        fi
        [ -n "$sb" ] && add build "$mgr run build" "package.json scripts.build"
        # npm init's placeholder is not a test suite.
        if [ -n "$st" ] && [[ "$st" != *"no test specified"* ]]; then
            add test "$mgr test" "package.json scripts.test"
        fi
    fi
    if [ -f "$d/pytest.ini" ] || [ -f "$d/conftest.py" ] \
       || { [ -f "$d/pyproject.toml" ] && grep -q '^\[tool\.pytest\.ini_options\]' "$d/pyproject.toml"; } \
       || { [ -f "$d/setup.cfg" ] && grep -q '^\[tool:pytest\]' "$d/setup.cfg"; } \
       || { [ -f "$d/tox.ini" ] && grep -q '^\[pytest\]' "$d/tox.ini"; }; then
        add test "pytest" "pytest config"
    fi
    if [ -f "$d/CMakeLists.txt" ] && [ -z "$mk" ]; then
        echo "note: CMakeLists.txt: a CMake build is configure then build, which is not one command, so none is proposed; point build= at a script (--set build=./scripts/build.sh)" >&2
    fi
    for key in build test; do
        if [ "$key" = build ]; then cands="$b_list"; else cands="$t_list"; fi
        cands="$(printf '%s' "$cands" | sed '/^$/d')"
        if [ -z "$cands" ]; then
            echo "note: no $key command detected: set one (--set $key=<command>, a script path when it needs a shell), or --set $key=none" >&2
            continue
        fi
        if [ "$(cut -d'|' -f1 <<< "$cands" | sort -u | wc -l | tr -d ' ')" -eq 1 ]; then
            echo "$key=$(head -1 <<< "$cands" | cut -d'|' -f1)"
            echo "note: $key from $(cut -d'|' -f2 <<< "$cands" | paste -sd, - | sed 's/,/, /g')" >&2
        else
            echo "note: several build systems propose different $key commands ($(tr '\n' ';' <<< "$cands" | sed 's/;$//; s/|/ from /g; s/;/; /g')), so none is proposed: choose one with --set $key=..." >&2
        fi
    done
}

if [ "$MODE" = "detect" ]; then
    if [ ! -d "$TARGET" ]; then
        echo "ERROR: $TARGET is not a directory" >&2
        exit 1
    fi
    detect_commands "$TARGET"
    exit 0
fi

# ------------------------------------------------------- main checkout ---
_GITDIR="$(cd "$ROOT" && cd "$(git rev-parse --git-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || _GITDIR=""
_COMMON="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd -P)" || _COMMON=""
if [ -n "$_GITDIR" ] && [ -n "$_COMMON" ] && [ "$_GITDIR" != "$_COMMON" ]; then
    echo "ERROR: refusing to run from a linked worktree ($ROOT): the registry and the settings files are per machine and live in the main checkout. Run: $(dirname "$_COMMON")/.agent/scripts/register_project.sh ..." >&2
    exit 1
fi

REGISTRY="$(registry_file "$ROOT")"
PROJECTS_D="$ROOT/.agent/projects.d"
REG_LOCK="$PROJECTS_D/.registry.lock"

if ! registry_entries_full "$ROOT" >/dev/null; then
    echo "ERROR: the registry $REGISTRY does not parse (above); fix it first" >&2
    exit 1
fi

# --------------------------------------------------------- final lines ---
# The project's name and root, as known so far (for the status lines).
NAME=""
PROJECT_ROOT=""
KEPT=""
final() { # <status> <next> [exit code]
    echo ""
    echo "STATUS=$1"
    echo "NAME=$NAME"
    echo "ROOT=$PROJECT_ROOT"
    [ -n "$KEPT" ] && echo "KEPT=$KEPT"
    echo "NEXT=$2"
    exit "${3:-0}"
}

# ---------------------------------------------------- registry writing ---
# Hold the registry lock (fd 8) for the rest of the run, the project's
# build and test included (children get the descriptor closed, so nothing
# they leave running holds it). Without flock
# (macOS by default) the write is unlocked. The lock file is never
# removed, as for the settings writer: removing it while another holder has
# it open would let a third lock a new file of the same name.
take_registry_lock() {
    mkdir -p "$PROJECTS_D" || return 1
    command -v flock >/dev/null 2>&1 || return 0
    exec 8>>"$REG_LOCK" || { echo "ERROR: cannot open the registry lock $REG_LOCK" >&2; return 1; }
    if ! flock -x -w "${PROJECT_FILE_LOCK_WAIT:-10}" 8; then
        echo "ERROR: another registration holds the registry lock $REG_LOCK; try again" >&2
        return 1
    fi
}

# Replace the registry with <tmp> after it parses, and holds <name> when
# <expect> is "present" (or not, when "absent"). The registry's mode is
# kept. Prints the parser's errors and returns 1 when it does not parse.
install_registry() { # <tmp> <name> <present|absent>
    local tmp="$1" want="$2" expect="$3" err mode has=0
    if ! err="$(registry_entries_full "$ROOT" "$tmp" 2>&1 >/dev/null)"; then
        printf '%s\n' "${err//$tmp/$REGISTRY}" >&2
        rm -f "$tmp"
        return 1
    fi
    registry_entries_full "$ROOT" "$tmp" 2>/dev/null | cut -f1 | grep -qxF -- "$want" && has=1
    if { [ "$expect" = present ] && [ "$has" -eq 0 ]; } || { [ "$expect" = absent ] && [ "$has" -eq 1 ]; }; then
        echo "ERROR: the new registry does not hold '$want' as expected; not writing it" >&2
        rm -f "$tmp"
        return 1
    fi
    mode="644"
    [ -f "$REGISTRY" ] && mode="$(stat -c %a "$REGISTRY" 2>/dev/null || stat -f %Lp "$REGISTRY" 2>/dev/null || echo 644)"
    chmod "$mode" "$tmp" && mv -f "$tmp" "$REGISTRY"
}

# A new registry (in projects.d, gitignored, on the registry's filesystem):
# the current one with <line> appended.
registry_with_line() { # <line> → prints the temporary file
    local tmp
    tmp="$(mktemp "$PROJECTS_D/.registry.XXXXXX")" || return 1
    if [ -f "$REGISTRY" ]; then
        cat "$REGISTRY" > "$tmp" || { rm -f "$tmp"; return 1; }
        [ -s "$tmp" ] && [ -n "$(tail -c1 "$tmp")" ] && echo >> "$tmp"
    fi
    printf '%s\n' "$1" >> "$tmp"
    echo "$tmp"
}

# A new registry without the line that registers <name> (its first token,
# outside a comment); every other line, comments included, kept.
registry_without_name() { # <name> → prints the temporary file
    local want="$1" tmp raw first
    tmp="$(mktemp "$PROJECTS_D/.registry.XXXXXX")" || return 1
    while IFS= read -r raw || [ -n "$raw" ]; do
        first=""
        read -r first _ <<< "${raw%%#*}" || true
        [ "${first%$'\r'}" = "$want" ] && continue
        printf '%s\n' "$raw"
    done < "$REGISTRY" > "$tmp"
    echo "$tmp"
}

# The registry line for <name> as written (comments stripped), or empty.
registry_raw_line() {
    local want="$1" raw first
    [ -f "$REGISTRY" ] || return 1
    while IFS= read -r raw || [ -n "$raw" ]; do
        first=""
        read -r first _ <<< "${raw%%#*}" || true
        if [ "${first%$'\r'}" = "$want" ]; then
            printf '%s\n' "${raw%$'\r'}"
            return 0
        fi
    done < "$REGISTRY"
    return 1
}

# ------------------------------------------------------------- removal ---
if [ "$MODE" = "remove" ]; then
    NAME="$TARGET"
    _RC=0
    ENTRY="$(registry_lookup "$ROOT" "$NAME")" || _RC=$?
    if [ "$_RC" -ne 0 ]; then
        echo "ERROR: project '$NAME' is not registered in $REGISTRY" >&2
        final refused "nothing to remove" 1
    fi
    TYPE="$(cut -f1 <<< "$ENTRY")"
    PROJECT_ROOT="$(cut -f2 <<< "$ENTRY")"
    SETTINGS="$(project_file_path "$ROOT" "$NAME")"
    if [ "$TYPE" = "$REGISTRY_PARENT_TYPE" ]; then
        INSTANCES="$(registry_instances "$ROOT" "$NAME" 2>/dev/null || true)"
        if [ -n "$INSTANCES" ]; then
            echo "ERROR: '$NAME' is a parent root with instances; remove them first:" >&2
            sed 's/^/  /' <<< "$INSTANCES" >&2
            final refused "remove its instances first (register_project.sh --remove <instance>)" 1
        fi
    fi
    WT_DIR="$(registry_worktree_dir "$ROOT" "$NAME" 2>/dev/null || true)"
    LIVE=""
    if [ -n "$WT_DIR" ] && [ -d "$WT_DIR" ]; then
        for _wt in "$WT_DIR"/issue-* "$WT_DIR"/skill-*; do
            [ -d "$_wt" ] && LIVE="$LIVE$_wt"$'\n'
        done
    fi
    if [ -n "$LIVE" ]; then
        echo "ERROR: '$NAME' has live worktrees; finish or remove them first (worktree_remove.sh):" >&2
        printf '%s' "$LIVE" | sed 's/^/  /' >&2
        final refused "remove its worktrees first" 1
    fi
    LINE="$(registry_raw_line "$NAME")"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "DRY RUN: nothing is changed."
        echo "would run: user_tier_install.sh --disable-root $NAME (removes the plugin from $PROJECT_ROOT when this checkout enabled it there)"
        echo "would remove the registry line: $LINE"
        if [ -e "$SETTINGS" ]; then
            if [ "$KEEP_SETTINGS" -eq 1 ]; then echo "would keep the settings file $SETTINGS (--keep-settings)"
            else echo "would remove the settings file $SETTINGS:"; sed 's/^/    /' "$SETTINGS"; fi
        fi
        echo "would leave alone: the project at $PROJECT_ROOT, its records and its memory"
        final dry-run "run again without --dry-run to remove '$NAME'"
    fi
    take_registry_lock || final refused "try again" 1
    # The registry without the line must parse (a parent's default_instance
    # may name it) before anything changes.
    TMP="$(registry_without_name "$NAME")" || final refused "could not write a new registry" 1
    if ! _err="$(registry_entries_full "$ROOT" "$TMP" 2>&1 >/dev/null)"; then
        printf '%s\n' "${_err//$TMP/$REGISTRY}" >&2
        rm -f "$TMP"
        echo "ERROR: the registry without '$NAME' would not parse (above); nothing removed" >&2
        final refused "fix the line that names '$NAME', then re-run" 1
    fi
    # Then the plugin: the installer finds the root through the registry,
    # so it goes before the line.
    if ! "$INSTALLER" --disable-root "$NAME" 8>&-; then
        rm -f "$TMP"
        echo "ERROR: could not remove the workspace plugin from $PROJECT_ROOT (above); nothing else was changed" >&2
        final refused "fix the plugin removal above, then re-run register_project.sh --remove $NAME" 1
    fi
    if ! install_registry "$TMP" "$NAME" absent; then
        echo "ERROR: could not write the registry without '$NAME' (above)" >&2
        final refused "remove its line from $REGISTRY by hand" 1
    fi
    echo "removed the registry line: $LINE"
    if [ -e "$SETTINGS" ] || [ -L "$SETTINGS" ]; then
        if [ "$KEEP_SETTINGS" -eq 1 ]; then
            echo "kept the settings file $SETTINGS (--keep-settings)"
        else
            echo "removed the settings file $SETTINGS; its content was:"
            sed 's/^/    /' "$SETTINGS" 2>/dev/null
            rm -f "$SETTINGS"
        fi
    fi
    [ -f "$PROJECTS_D/$NAME.sh" ] && echo "note: the legacy $PROJECTS_D/$NAME.sh is left in place; remove it by hand when it is no longer wanted"
    echo "left alone: the project at $PROJECT_ROOT, its records (in the project, or where its settings put them) and its memory"
    final removed "nothing; register it again with register_project.sh $PROJECT_ROOT"
fi

# --------------------------------------------------- what to register ---
# Absolute and lexically normal; the physical form when it exists.
abs_path() {
    local p="$1"
    case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
    p="$(_registry_normpath "$p")"
    if [ -d "$p" ]; then (cd "$p" && pwd -P); else echo "$p"; fi
}
# The physical form of a path, for comparisons (itself when missing).
phys() { (cd "$1" 2>/dev/null && pwd -P) || _registry_normpath "$1"; }

ADOPT=0
ENTRY=""
# A bare word that is a registered name is that project.
if [[ "$TARGET" != */* ]] && [[ "$TARGET" != .* ]] && ENTRY="$(registry_lookup "$ROOT" "$TARGET" 2>/dev/null)"; then
    ADOPT=1
    NAME="$TARGET"
    PROJECT_ROOT="$(cut -f2 <<< "$ENTRY")"
    if [ -n "$NAME_ARG" ] && [ "$NAME_ARG" != "$NAME" ]; then
        echo "ERROR: '$TARGET' is a registered name; --name $NAME_ARG would rename it (no silent rewrite)" >&2
        final refused "drop --name, or remove and register again" 1
    fi
else
    if [[ "$TARGET" != */* ]] && [[ "$TARGET" != .* ]] && [ ! -d "$TARGET" ]; then
        echo "ERROR: '$TARGET' is neither a registered project nor an existing directory (write ./$TARGET or an absolute path for a directory to be created)" >&2
        final refused "give the project's path" 1
    fi
    PROJECT_ROOT="$(abs_path "$TARGET")"
    # A path already registered under some name is that project.
    _want="$(phys "$PROJECT_ROOT")"
    while IFS=$'\t' read -r _n _t _p; do
        [ -n "$_n" ] || continue
        if [ "$(phys "$_p")" = "$_want" ]; then
            ADOPT=1; NAME="$_n"; ENTRY="$(printf '%s\t%s' "$_t" "$_p")"; PROJECT_ROOT="$_p"
            break
        fi
    done < <(registry_entries "$ROOT" 2>/dev/null)
    if [ "$ADOPT" -eq 1 ] && [ -n "$NAME_ARG" ] && [ "$NAME_ARG" != "$NAME" ]; then
        echo "ERROR: $PROJECT_ROOT is already registered as '$NAME'; --name $NAME_ARG would register it twice" >&2
        final refused "use the name '$NAME', or remove it first" 1
    fi
    if [ "$ADOPT" -eq 0 ]; then
        NAME="${NAME_ARG:-$(basename "$PROJECT_ROOT")}"
    fi
fi

if [ "$ADOPT" -eq 0 ]; then
    if ! [[ "$NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || [[ "$NAME" == *..* ]] || [[ "$NAME" == *.[sS][hH] ]]; then
        echo "ERROR: '$NAME' is not a valid project name ([A-Za-z0-9][A-Za-z0-9._-]*, no '..', not ending in .sh); choose one with --name" >&2
        final refused "choose a name with --name" 1
    fi
    if _other="$(registry_lookup "$ROOT" "$NAME" 2>/dev/null)"; then
        echo "ERROR: the name '$NAME' is already registered, at $(cut -f2 <<< "$_other"); a different path for a registered name is refused (no silent rewrite)" >&2
        final refused "choose another name with --name, or remove '$NAME' first" 1
    fi
    if [[ "$PROJECT_ROOT" == *[[:space:]=]* ]]; then
        echo "ERROR: the registry cannot hold a path with a blank or '=' ($PROJECT_ROOT)" >&2
        final refused "move the project to a path without blanks or '='" 1
    fi
fi

# The --set keys, validated one by one (the whole file is validated again
# before it is written).
SET_KEYS=" "
for _kv in ${SETS[@]+"${SETS[@]}"}; do
    if [[ "$_kv" != *=* ]]; then
        die_usage "--set takes key=value, got '$_kv'"
    fi
    _k="${_kv%%=*}"
    if ! _project_file_key_in "$_k" "$_PROJECT_FILE_KEYS"; then
        die_usage "--set: unknown settings key '$_k' (known: ${_PROJECT_FILE_KEYS# })"
    fi
    [[ "$SET_KEYS" == *" $_k "* ]] && die_usage "--set $_k given twice"
    SET_KEYS="$SET_KEYS$_k "
done
set_value() { # <key> → the --set value, or return 1
    local kv
    for kv in ${SETS[@]+"${SETS[@]}"}; do
        [ "${kv%%=*}" = "$1" ] && { printf '%s\n' "${kv#*=}"; return 0; }
    done
    return 1
}

# The type.
if [ "$ADOPT" -eq 1 ]; then
    TYPE="$(cut -f1 <<< "$ENTRY")"
    if [ -n "$TYPE_ARG" ] && [ "$TYPE_ARG" != "$TYPE" ]; then
        echo "ERROR: '$NAME' is registered as type $TYPE; registering it as $TYPE_ARG would rewrite its line (no silent rewrite)" >&2
        final refused "remove it and register it again to change its type" 1
    fi
elif [ -n "$TYPE_ARG" ]; then
    TYPE="$TYPE_ARG"
elif [ -d "$PROJECT_ROOT/configs/manifest" ] || set_value bootstrap_url >/dev/null; then
    TYPE="ros2_colcon"
else
    TYPE="single_project"
fi
IS_PARENT=0
[ "$TYPE" = "$REGISTRY_PARENT_TYPE" ] && IS_PARENT=1
if [ "$IS_PARENT" -eq 0 ]; then
    if [ ! -f "$ROOT/.agent/project_types/$TYPE/adapter.sh" ]; then
        echo "ERROR: no project type '$TYPE' (types: $(cd "$ROOT/.agent/project_types" && ls -d -- */ 2>/dev/null | tr -d / | tr '\n' ' ')$REGISTRY_PARENT_TYPE)" >&2
        final refused "choose a type" 1
    fi
    if ! _conf_err="$(registration_conf_problems "$ROOT" "$TYPE")"; then
        echo "ERROR: project type '$TYPE' cannot be registered: its registration.conf is missing or invalid:" >&2
        printf '%s\n' "$_conf_err" | sed 's/^/  /' >&2
        final refused "add or fix $(registration_conf_path "$ROOT" "$TYPE")" 1
    fi
    REQUIRED="$(registration_conf_get "$ROOT" "$TYPE" required_commands)"
    CONF_SETUP="$(registration_conf_get "$ROOT" "$TYPE" setup)"
    CONF_RUN="$(registration_conf_get "$ROOT" "$TYPE" run)"
else
    REQUIRED=""; CONF_SETUP="never"; CONF_RUN=""
    [ "${#SETS[@]}" -eq 0 ] || die_usage "a parent root ($REGISTRY_PARENT_TYPE) has no settings of its own; --set them on its instances"
fi
if [ -n "$F_default_instance" ] && [ "$IS_PARENT" -eq 0 ]; then
    die_usage "--default-instance is for a parent root (type $REGISTRY_PARENT_TYPE)"
fi

# The registry line: new, or the existing one kept (with a missing
# default_instance added to a parent root).
[ -n "$F_worktrees" ] && F_worktrees="$(abs_path "$F_worktrees")"
LINE_CHANGE=""
if [ "$ADOPT" -eq 1 ]; then
    OLD_LINE="$(registry_raw_line "$NAME")"
    _fields="$(registry_entries_full "$ROOT" | awk -F'\t' -v n="$NAME" '$1 == n { print $4 }')"
    for _f in $FIELD_KEYS; do
        _v="F_$_f"
        [ -n "${!_v}" ] || continue
        _have="$(_registry_field_of "$_fields" "$_f" || true)"
        if [ -z "$_have" ] && [ "$_f" = default_instance ]; then
            LINE_CHANGE="${OLD_LINE%%#*}"
            LINE_CHANGE="$(_project_file_trim "${LINE_CHANGE%$'\r'}")  default_instance=$F_default_instance"
            continue
        fi
        if [ "$_have" != "${!_v}" ]; then
            echo "ERROR: '$NAME' is registered with ${_f}=${_have:-(none)}; --${_f//_/-} ${!_v} would rewrite its line (no silent rewrite; edit $REGISTRY by hand)" >&2
            final refused "drop --${_f//_/-}, or edit the line by hand" 1
        fi
    done
else
    NEW_LINE="$NAME  $TYPE  $PROJECT_ROOT"
    for _f in $FIELD_KEYS; do
        _v="F_$_f"
        [ -n "${!_v}" ] && NEW_LINE="$NEW_LINE  $_f=${!_v}"
    done
fi

# ------------------------------------------------- the settings to write ---
SETTINGS="$(project_file_path "$ROOT" "$NAME")"
LEGACY="$PROJECTS_D/$NAME.sh"
SETTINGS_EXISTED=0
{ [ -e "$SETTINGS" ] || [ -L "$SETTINGS" ]; } && SETTINGS_EXISTED=1
KV=()          # key=value to write
KV_NOTES=()    # where each came from
if [ "$IS_PARENT" -eq 0 ]; then
    for _kv in ${SETS[@]+"${SETS[@]}"}; do
        KV+=("$_kv"); KV_NOTES+=("${_kv%%=*}: from --set")
    done
    if [ "$SETTINGS_EXISTED" -eq 0 ]; then
        # The legacy .sh values, for a key the type reads and --set leaves.
        if [ -f "$LEGACY" ]; then
            for _pair in build:BUILD_CMD test:TEST_CMD install:INSTALL_CMD bootstrap_url:MANIFEST_BOOTSTRAP_URL; do
                _k="${_pair%%:*}"; _var="${_pair#*:}"
                [[ "$SET_KEYS" == *" $_k "* ]] && continue
                _project_type_unused_setting "$ROOT" "$TYPE" "$_k" >/dev/null && continue
                if ! _val="$(_project_config_value "$LEGACY" "$_var")"; then
                    echo "WARNING: cannot source the legacy $LEGACY; nothing copied from it" >&2
                    break
                fi
                _val="$(_project_file_trim "$_val")"
                [ -n "$_val" ] || continue
                if _why="$(_project_file_value_error "$_k" "$_val")"; then
                    KV+=("$_k=$_val"); KV_NOTES+=("$_k: copied from $_var in $LEGACY")
                    SET_KEYS="$SET_KEYS$_k "
                else
                    echo "WARNING: $_var in $LEGACY is not copied ($_why); the adapters keep reading it from the legacy file" >&2
                    SET_KEYS="$SET_KEYS$_k "
                fi
            done
        fi
        # Detection, for a required command still without a value.
        if [ -n "$REQUIRED" ] && [ -d "$PROJECT_ROOT" ]; then
            # Read-only and cheap: once for the proposals, once for the notes.
            _det="$(detect_commands "$PROJECT_ROOT" 2>/dev/null)" || _det=""
            _det_notes="$(detect_commands "$PROJECT_ROOT" 2>&1 >/dev/null)" || _det_notes=""
            for _k in $REQUIRED; do
                [[ "$SET_KEYS" == *" $_k "* ]] && continue
                _val="$(sed -n "s/^$_k=//p" <<< "$_det")"
                if [ -n "$_val" ]; then
                    KV+=("$_k=$_val"); KV_NOTES+=("$_k: detected ($(sed -n "s/^note: $_k from //p" <<< "$_det_notes"))")
                else
                    grep -E "^note: (no $_k |several build systems propose different $_k |CMakeLists)" <<< "$_det_notes" | sort -u >&2
                fi
            done
        fi
    fi
fi

# Check the resulting settings file before anything is written.
if [ "${#KV[@]}" -gt 0 ]; then
    _tmpd="$(mktemp -d)" || final refused "could not make a temporary directory" 1
    _tmpf="$_tmpd/$NAME"
    if [ "$SETTINGS_EXISTED" -eq 1 ] && [ -f "$SETTINGS" ]; then cat "$SETTINGS" > "$_tmpf"; fi
    _tmpk=""
    for _kv in "${KV[@]}"; do _tmpk="$_tmpk ${_kv%%=*} "; done
    if [ -f "$_tmpf" ]; then
        # Lines for keys about to be set are replaced, as the writer does.
        while IFS= read -r _l || [ -n "$_l" ]; do
            _lk="$(_project_file_trim "${_l%%=*}")"
            [[ "$_l" == *=* ]] && [[ "$_tmpk" == *" $_lk "* ]] && continue
            printf '%s\n' "$_l"
        done < "$_tmpf" > "$_tmpf.new" && mv "$_tmpf.new" "$_tmpf"
    fi
    printf '%s\n' "${KV[@]}" >> "$_tmpf"
    _RC=0
    _err="$(_project_file_parse "$_tmpf" "$NAME" "$ROOT" "$TYPE" 2>&1 >/dev/null)" || _RC=$?
    if [ "$_RC" -eq 0 ]; then
        _ent="$(_project_file_parse "$_tmpf" "$NAME" "$ROOT" "$TYPE" 2>/dev/null)"
        _loc="$(_project_file_value_of "$_ent" location || true)"
        _lp="$(_project_file_value_of "$_ent" location_path || true)"
        _tr="$(_project_file_value_of "$_ent" tracking || true)"
        if { [ -n "$_loc" ] && [ "$_loc" != project ]; } || { [ -n "$_tr" ] && [ "$_tr" != project ]; } || [ -n "$_lp" ]; then
            _err="records settings other than the default (project, project) are not stored until the records lookup lands ($PROJECT_RECORDS_LOOKUP_ISSUE)"
            _RC=1
        fi
    fi
    rm -rf "$_tmpd"
    if [ "$_RC" -ne 0 ]; then
        echo "ERROR: the settings for '$NAME' would be invalid:" >&2
        printf '%s\n' "${_err//$_tmpf/$SETTINGS}" | sed 's/^/  /' >&2
        final refused "fix the --set values" 1
    fi
fi

# Adoption: the environment a command no longer gets.
EXTRA_WARN=""
if [ "$IS_PARENT" -eq 0 ]; then
    _cfg=""
    if [ -f "$LEGACY" ]; then _cfg="$LEGACY"
    elif [ "$ADOPT" -eq 1 ] && [ -f "$ROOT/.agent/project_config.sh" ]; then _cfg="$ROOT/.agent/project_config.sh"
    fi
    if [ -n "$_cfg" ] && [ "${#KV[@]}" -gt 0 ]; then
        if _extra="$(project_config_extra_vars "$_cfg")"; then
            if [ -n "$_extra" ]; then
                EXTRA_WARN="WARNING: $_cfg sets or exports $(tr '\n' ' ' <<< "$_extra" | sed 's/ $//; s/ /, /g'), which a command in the settings file no longer gets (it runs without sourcing that config): move that environment into the script the key points at"
            fi
        else
            EXTRA_WARN="WARNING: cannot source $_cfg to check what environment it sets"
        fi
    fi
fi

# Setup: when the type runs it and the hosting directory is missing.
RUN_SETUP=0
if [ "$CONF_SETUP" = "when-missing" ] && [ ! -e "$PROJECT_ROOT" ] && [ "$NO_SETUP" -eq 0 ]; then
    RUN_SETUP=1
fi
RUN_VERBS=""
[ "$SKIP_RUN" -eq 0 ] && RUN_VERBS="$CONF_RUN"

# The user tier.
ROOT_FILE="${HOME:-}/.claude/agent-workspace-root"
UT_STATE="absent"
if [ -f "$ROOT_FILE" ]; then
    if [ "$(phys "$(cat "$ROOT_FILE")")" = "$(phys "$ROOT")" ]; then UT_STATE="here"; else UT_STATE="elsewhere"; fi
fi
RUN_UT=0
{ [ "$UT_STATE" = here ] || [ "$INSTALL_UT" -eq 1 ]; } && RUN_UT=1
ONBOARD_NEXT="start a Claude Code session at $PROJECT_ROOT and run /agent-workspace:onboard-project"
ut_note() {
    case "$UT_STATE" in
        absent) echo "WARNING: the user tier is not installed, so a session started at $PROJECT_ROOT gets no workspace layer or skills: install it with .agent/scripts/user_tier_install.sh (or re-run with --install-user-tier)" ;;
        elsewhere) echo "WARNING: the user tier is installed for another checkout ($(cat "$ROOT_FILE")), so the installer is not run from here: run that checkout's installer, or this one's with --force to take it over" ;;
    esac
}
ut_next() {
    case "$UT_STATE" in
        here) echo "$ONBOARD_NEXT" ;;
        *) [ "$RUN_UT" -eq 1 ] && { echo "$ONBOARD_NEXT"; return; }
           echo "install the user tier (.agent/scripts/user_tier_install.sh), then $ONBOARD_NEXT" ;;
    esac
}

# --------------------------------------------------------------- dry run ---
if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN: nothing is written."
    if [ "$ADOPT" -eq 1 ]; then
        if [ -n "$LINE_CHANGE" ]; then
            echo "would change the registry line to: $LINE_CHANGE"
        else
            echo "registry line kept as it is: $(registry_raw_line "$NAME")"
        fi
    else
        echo "would add the registry line: $NEW_LINE"
    fi
    if [ "${#KV[@]}" -gt 0 ]; then
        if [ "$SETTINGS_EXISTED" -eq 1 ]; then echo "would set in $SETTINGS:"; else echo "would write $SETTINGS:"; fi
        for _i in "${!KV[@]}"; do echo "    ${KV[$_i]}    (${KV_NOTES[$_i]#*: })"; done
    elif [ "$IS_PARENT" -eq 0 ]; then
        if [ "$SETTINGS_EXISTED" -eq 1 ]; then echo "settings file kept as it is: $SETTINGS"
        else echo "no settings file (nothing to write)"; fi
    fi
    [ -n "$EXTRA_WARN" ] && echo "$EXTRA_WARN"
    [ "$RUN_SETUP" -eq 1 ] && echo "would run: adapter --project $NAME setup ($PROJECT_ROOT does not exist)"
    echo "would run: registration_verify.sh $NAME"
    for _v in $RUN_VERBS; do echo "would run: adapter --project $NAME $_v"; done
    [ "$SKIP_RUN" -eq 1 ] && [ -n "$CONF_RUN" ] && echo "would not run: $CONF_RUN (--skip-run)"
    if [ "$RUN_UT" -eq 1 ]; then
        echo "would run: user_tier_install.sh, then registration_verify.sh $NAME --user-tier"
    else
        ut_note
    fi
    final dry-run "run again without --dry-run"
fi

# ------------------------------------------------------------- register ---
ROLLBACK_ARMED=0
INSTALLER_RAN=0
LINE_WRITTEN=0
SETTINGS_BACKUP=""
SETUP_RAN=0
CHANGED=0

rollback() {
    [ "$ROLLBACK_ARMED" -eq 1 ] || return 0
    ROLLBACK_ARMED=0
    echo "" >&2
    echo "Rolling back the registration of '$NAME':" >&2
    if [ "$INSTALLER_RAN" -eq 1 ]; then
        "$INSTALLER" --disable-root "$NAME" >&2 8>&- \
            || echo "  WARNING: could not remove the workspace plugin from $PROJECT_ROOT (above)" >&2
    fi
    if [ "$LINE_WRITTEN" -eq 1 ]; then
        local tmp
        if tmp="$(registry_without_name "$NAME")" && install_registry "$tmp" "$NAME" absent; then
            echo "  removed the registry line" >&2
        else
            echo "  WARNING: could not remove the registry line for '$NAME' from $REGISTRY; remove it by hand" >&2
        fi
    fi
    if [ -n "$SETTINGS_BACKUP" ]; then
        cat "$SETTINGS_BACKUP" > "$SETTINGS" && echo "  restored the settings file $SETTINGS" >&2
        rm -f "$SETTINGS_BACKUP"
    elif [ "$SETTINGS_EXISTED" -eq 0 ] && [ -e "$SETTINGS" ]; then
        rm -f "$SETTINGS" && echo "  removed the settings file $SETTINGS" >&2
    fi
    if [ "$SETUP_RAN" -eq 1 ] && [ -e "$PROJECT_ROOT" ]; then
        KEPT="$PROJECT_ROOT"
        echo "  kept $PROJECT_ROOT: created by setup; remove it, or re-run register_project.sh to reuse it" >&2
    fi
}
on_signal() {
    trap - INT TERM HUP
    rollback
    final refused "interrupted; nothing is registered" "$1"
}
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
trap 'on_signal 129' HUP

# A failure: a new registration is rolled back; an adopted one is kept.
failed() { # <what failed> <next>
    if [ "$ADOPT" -eq 1 ]; then
        echo "" >&2
        echo "'$NAME' was already registered, so it is kept as it is: $1" >&2
        final "NOT READY" "$2" 1
    fi
    rollback
    if [ -n "$KEPT" ]; then
        final refused "$2; then re-run register_project.sh (setup is not run again on the kept $KEPT; remove it first to start over)" 1
    fi
    final refused "$2" 1
}

take_registry_lock || final refused "try again" 1
[ "$ADOPT" -eq 0 ] && ROLLBACK_ARMED=1

# 1. The registry line and the settings file.
if [ "$ADOPT" -eq 0 ]; then
    TMP="$(registry_with_line "$NEW_LINE")" || failed "could not write a new registry" "check $PROJECTS_D is writable"
    install_registry "$TMP" "$NAME" present || failed "the new registry line does not parse (above)" "fix the arguments"
    LINE_WRITTEN=1
    CHANGED=1
    echo "added the registry line: $NEW_LINE"
elif [ -n "$LINE_CHANGE" ]; then
    # The changed line where the old one was; every other line kept.
    TMP="$(mktemp "$PROJECTS_D/.registry.XXXXXX")" || failed "could not write a new registry" "check $PROJECTS_D is writable"
    while IFS= read -r _raw || [ -n "$_raw" ]; do
        _first=""; read -r _first _ <<< "${_raw%%#*}" || true
        if [ "${_first%$'\r'}" = "$NAME" ]; then printf '%s\n' "$LINE_CHANGE"; else printf '%s\n' "$_raw"; fi
    done < "$REGISTRY" > "$TMP"
    install_registry "$TMP" "$NAME" present || failed "the changed registry line does not parse (above)" "fix --default-instance"
    CHANGED=1
    echo "changed the registry line to: $LINE_CHANGE"
else
    echo "registry line kept as it is: $(registry_raw_line "$NAME")"
fi
if [ "${#KV[@]}" -gt 0 ]; then
    if [ "$SETTINGS_EXISTED" -eq 1 ] && [ "$ADOPT" -eq 0 ] && [ -f "$SETTINGS" ]; then
        SETTINGS_BACKUP="$(mktemp "$PROJECTS_D/.settings-backup.XXXXXX")" && cat "$SETTINGS" > "$SETTINGS_BACKUP"
    fi
    for _i in "${!KV[@]}"; do echo "  ${KV[$_i]}    (${KV_NOTES[$_i]#*: })"; done
    _out="$(project_file_set "$ROOT" "$NAME" "${KV[@]}")" || failed "the settings file could not be written (above)" "fix the --set values"
    echo "$_out"
    [[ "$_out" == unchanged* ]] || CHANGED=1
elif [ "$IS_PARENT" -eq 0 ]; then
    if [ "$SETTINGS_EXISTED" -eq 1 ]; then echo "unchanged $SETTINGS"; else echo "no settings file (nothing to write)"; fi
fi
[ "$CHANGED" -eq 0 ] && echo "nothing changed: '$NAME' was registered with these settings already"
[ -n "$EXTRA_WARN" ] && echo "$EXTRA_WARN"

if [ "$RUN_SETUP" -eq 1 ]; then
    echo ""
    echo "== adapter --project $NAME setup ($PROJECT_ROOT does not exist)"
    SETUP_RAN=1
    "$ADAPTER" --from "$ROOT" --project "$NAME" setup 8>&- || failed "adapter setup failed (above)" "fix the setup failure (its bootstrap_url, say)"
fi

# 2. The static gate.
echo ""
echo "== registration_verify.sh $NAME"
"$VERIFY" "$NAME" 8>&- || failed "the static gate failed (above)" "fix what registration_verify.sh reports"

# 3. The project's own verbs.
for _v in $RUN_VERBS; do
    echo ""
    echo "== adapter --project $NAME $_v"
    "$ADAPTER" --from "$ROOT" --project "$NAME" "$_v" 8>&- || failed "adapter $_v failed (above)" "fix the $_v failure, or its command (project_setting.sh set $NAME $_v=...)"
done

# 4. The user tier.
echo ""
if [ "$RUN_UT" -eq 1 ]; then
    echo "== user_tier_install.sh"
    INSTALLER_RAN=1
    "$INSTALLER" 8>&- || failed "the user-tier installer failed (above)" "fix the installer failure"
    echo ""
    echo "== registration_verify.sh $NAME --user-tier"
    "$VERIFY" "$NAME" --user-tier 8>&- || failed "the user-tier check failed (above)" "fix what registration_verify.sh reports"
else
    ut_note
fi

ROLLBACK_ARMED=0
[ -n "$SETTINGS_BACKUP" ] && rm -f "$SETTINGS_BACKUP"
trap - INT TERM HUP
STATUS="registered"
if [ "$SKIP_RUN" -eq 1 ] && [ -n "$CONF_RUN" ]; then
    STATUS="registered, $(sed 's/ / and /g' <<< "$CONF_RUN") not run"
fi
final "$STATUS" "$(ut_next)"
