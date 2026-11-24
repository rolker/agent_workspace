#!/usr/bin/env bash
# .agent/scripts/register_project.sh
# Register a project with this workspace, or remove one (issue #332, D1
# step 1). The workspace side of onboarding: it writes the registry line
# and the project's settings file, checks them, runs the project's build
# and test, and checks that the user tier reaches a session at the
# project's root. Nothing is enabled per root: the workspace plugin is
# enabled once, at user scope, by user_tier_install.sh (ADR-0018), so it
# already reaches the new root. The project side (D1 step 2) is
# `/agent-workspace:onboard-project`, run in a session started at the
# project root. Run there in a folder not yet registered, onboarding
# registers it through register_session_root.sh (#466, ADR-0021), which
# calls this script on that folder with --skip-run and never
# --install-user-tier.
#
# Usage:
#   register_project.sh <path|name> [<type>] [--name N] [--parent P]
#                       [--distro D] [--role R] [--worktrees W]
#                       [--default-instance I] [--set key=value]...
#                       [--no-setup] [--skip-run] [--install-user-tier]
#                       [--dry-run]
#   register_project.sh <path> [<type>] --manifest <file> --distro D
#                       [--role R] [--with <group>]...
#                       [--fetch-from <prefix>] [other options as above]
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
#                  when <path>/configs/manifest or <path>/.repos-manifest
#                  (a root the manifest tool set up; issue 503) exists or
#                  --set bootstrap_url=... is given, else single_project.
#                  With --manifest: the type whose registration.conf says
#                  manifest=local-file (one such type, else give it).
#   --name N       the project's name (default: the directory's name)
#   --manifest F   set a new root up from the manifest file F on the local
#                  disk, then register it (issue 503 part 2): the
#                  directory is made when missing, and `adapter setup
#                  --manifest <F made absolute> --distro D [--role R]
#                  [--with G]... [--fetch-from P]` runs the manifest tool's
#                  init --distro-dirs --yes in it. --distro is required;
#                  --distro and --role go to init, not to the registry
#                  line; --with (repeatable) and --fetch-from go to init
#                  and need --manifest. Nothing about the manifest is
#                  recorded in the workspace: the tool's .repos-manifest/
#                  is the one record. Refused before anything is written
#                  (a dry run too): with --no-setup (usage), a registered
#                  name or path, a type whose registration.conf says
#                  manifest=none, a root that holds .repos-manifest/ (set
#                  up already: register it without --manifest), a root
#                  that exists and holds anything but .claude, a manifest
#                  that is not a regular file, a URL or a git location
#                  (scheme://..., user@host:path) that is not an existing
#                  file (the tool reads a local file only in this version;
#                  issue 498), and bootstrap_url given or in a kept
#                  settings file (the bootstrap route's setting, a second
#                  record on the tool's route)
#   --parent, --distro, --role, --worktrees, --default-instance
#                  the registry's trailing fields (_project_registry.sh
#                  header); --worktrees is written as an absolute path.
#                  --distro and --role without --manifest on a root that
#                  holds .repos-manifest/ are refused before anything is
#                  written, for a type that reads the tool's record
#                  (manifest=local-file): validate refuses them there as a
#                  second record
#   --set key=value  a settings-file key (project_setting.sh's keys), e.g.
#                  --set build=./scripts/build.sh --set test=none; a key
#                  the type lists in its registration_refused is refused
#                  before anything is written, with the list's reason, and
#                  so is one a settings file kept from an earlier
#                  registration (--remove --keep-settings) sets
#   --no-setup     never run `adapter setup`, even for a type whose
#                  registration.conf runs it when the directory is missing
#   --skip-run     do not run the build and test verbs; the status says so
#   --install-user-tier
#                  run user_tier_install.sh before the user-tier check (it
#                  installs or repairs the user tier, the plugin's
#                  user-scope enable included); without it registration
#                  never runs the installer
#   --dry-run      print every step it would take, and write nothing
#   --remove N     unregister: refused while the root has live worktrees
#                  or is a parent with instances; removes the registry line
#                  and the settings file (printed first, so it can be
#                  restored). The project, its records, its memory and the
#                  user tier (the plugin stays enabled at user scope) are
#                  left alone.
#   --keep-settings  with --remove: keep the settings file
#   --detect P     read-only: print the build and test commands the files
#                  at P propose, one key=value per line (notes on stderr).
#                  Only a single correct command is proposed: a Makefile,
#                  Cargo.toml, go.mod, package.json scripts, a pytest
#                  config. CMake needs configure then build, which is not
#                  one command, so nothing is proposed: point build= at a
#                  script.
#
# A settings path that is a dangling symlink, or not a regular file (a
# directory, say), is refused before anything is written.
#
# Registering, in order, so a failed registration leaves nothing behind:
#   1. write the registry line (a temporary copy, re-parsed, then renamed)
#      and the settings file. Its command keys come from --set, else
#      --detect's proposals (issue #265 part 4: a legacy
#      .agent/projects.d/<name>.sh is not read or copied; make validate's
#      stale-shape report names what is left in it to move).
#      Then, when the type's registration.conf says setup=when-missing and
#      the hosting directory does not exist, `adapter setup`; with
#      --manifest, `adapter setup --manifest ...` (the root missing or
#      empty).
#   2. the static gate, registration_verify.sh <name> (read-only).
#   3. the verbs registration.conf names in run= (build, test), unless
#      --skip-run.
#   4. only then the user tier: with --install-user-tier,
#      user_tier_install.sh; then, when ~/.claude/agent-workspace-root
#      names this checkout, registration_verify.sh <name> --user-tier (a
#      read-only check: the user tier installed and current, and a session
#      at the root resolving to it). Otherwise a warning and the next step,
#      not a failure.
# A failure in 1 to 4 removes the registry line and the settings file (on
# INT, TERM and HUP too; a settings file that existed before is copied
# aside first, the run refused when that copy fails, and put back by a
# rename, or, when the run stops before writing the file, the copy is
# removed). Nothing in the project root or in ~/.claude is undone: the
# run wrote neither, except through an installer run asked for with
# --install-user-tier, which is kept. A rollback step that fails is
# named in the output and on NEXT=, never reported as a clean result, and
# while the registry line is left the status is NOT READY. A signal that
# arrives while a failure, an interrupt or an unexpected exit is being
# handled (the rollback included) waits for it to finish; a rollback cut
# short all the same (an unexpected exit inside it) is reported NOT READY,
# "the rollback stopped part way", naming what it left (the hidden backup
# of a settings file that existed before included, while it is there). A hosting directory that
# setup created is kept and named on KEPT= (its clones are slow to redo,
# and a re-run reuses it); a directory that existed before is never
# touched. With --manifest, a root setup made that is still empty (init
# made nothing, or the adapter was stopped by a signal before its own
# cleanup) is removed with rmdir, with each directory above it the run
# made, and not named on KEPT=; a root that existed before is never on
# KEPT=, and is named when init left something in it; when the root then
# holds .repos-manifest/, NEXT= names the tool's sync and registering the
# root without --manifest. A settings file changed after this run wrote it (a
# project_setting.sh set during the build, say) is kept, with a warning,
# never overwritten. An exit no step chose (an unset variable, say) is
# handled as a failure, by an EXIT trap. The type's facts come from
# .agent/project_types/<type>/registration.conf, so this script names no
# type; a type without one is refused.
#
# Adopting a project that is already registered (by hand, or before) is
# the same command on its name or path: its registry line is kept as it
# is (a different type or path, or a field with a different value, is
# refused: no silent rewrite; the one exception is adding a missing
# default_instance to a parent root, which can only be set once its
# instances are registered). A project with no settings file gets one
# (from detection); one with a file gets only the --set keys.
# An adopted project that fails a check, or whose run is interrupted, is
# reported NOT READY and kept, never rolled back; the output says what the
# run already changed (its line, its settings file). A second identical run changes nothing and says so.
#
# Runs only from the main checkout: the registry and settings files are per
# machine and gitignored, so a linked worktree has none (--detect excepted).
# One registration or removal runs at a time: each holds the registry lock
# from before its first check to its last step, and a second run waits
# for it (PROJECT_FILE_LOCK_WAIT seconds, default 10), then refuses having
# changed nothing. A --dry-run takes no lock.
# It never writes into the project. It is not promoted to the user tier.
#
# Last output lines (stable, for skills and tests):
#   STATUS=registered | registered, <verbs> not run | NOT READY | refused
#          | removed | removed, settings file left | dry-run
#          (NOT READY also when a rollback could not remove the line,
#          or stopped part way;
#          "removed, settings file left" exits 1)
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
# --manifest and the options only init takes (issue 503 part 2).
MANIFEST=""
M_WITH=()
M_FETCH=""
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
        --manifest)
            need_value "$@"; [ -z "$MANIFEST" ] || die_usage "--manifest given twice"
            MANIFEST="$2"; shift 2 ;;
        --with) need_value "$@"; M_WITH+=("$2"); shift 2 ;;
        --fetch-from)
            need_value "$@"; [ -z "$M_FETCH" ] || die_usage "--fetch-from given twice"
            M_FETCH="$2"; shift 2 ;;
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
   || [ "$INSTALL_UT" -eq 1 ] || [ -n "$TYPE_ARG" ] || [ -n "$MANIFEST" ] || [ "${#M_WITH[@]}" -gt 0 ] \
   || [ -n "$M_FETCH" ]; then
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
        if [ -z "$MANIFEST" ]; then
            { [ "${#M_WITH[@]}" -eq 0 ] && [ -z "$M_FETCH" ]; } \
                || die_usage "--with and --fetch-from go to the manifest tool's init, with --manifest"
        else
            [ -n "$F_distro" ] || die_usage "--manifest needs --distro: the manifest tool's init --distro-dirs sets the root up for one distro"
            [ "$NO_SETUP" -eq 0 ] || die_usage "--manifest sets the root up, so it cannot go with --no-setup"
        fi
        ;;
esac
# With --manifest, --distro and --role go to init and not to the registry
# line (the tool's record is the one record).
M_DISTRO=""
M_ROLE=""
if [ -n "$MANIFEST" ]; then
    M_DISTRO="$F_distro"; M_ROLE="$F_role"
    F_distro=""; F_role=""
fi
# The next step that registers a root the manifest tool has set up: the
# command as given, keeping its other options (--name, --set and the rest).
M_OPTS="--manifest, --distro, --role, --with and --fetch-from"
M_RERUN="re-run the same register_project.sh command without $M_OPTS"

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
            # As jq's '// empty': a missing, null or false script is empty.
            sb="$(python3 -I -c 'import json,sys; print((json.load(open(sys.argv[1])).get("scripts") or {}).get("build") or "")' "$d/package.json" 2>/dev/null)" || sb=""
            st="$(python3 -I -c 'import json,sys; print((json.load(open(sys.argv[1])).get("scripts") or {}).get("test") or "")' "$d/package.json" 2>/dev/null)" || st=""
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

# --------------------------------------------------------- final lines ---
# The project's name and root, as known so far (for the status lines).
NAME=""
PROJECT_ROOT=""
KEPT=""
FINAL_DONE=0   # the last lines are printed (the EXIT trap then does nothing)
final() { # <status> <next> [exit code]
    FINAL_DONE=1
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
# they leave running holds it). It is taken before any check that reads
# the registry or projects.d (is the name free, is it an adoption, does a
# settings file exist), so those answers still hold when this run writes,
# and a run that loses the race refuses before it writes or removes
# anything. Without flock (macOS by default) the run is unlocked. The lock
# file is never removed, as for the settings writer: removing it while
# another holder has it open would let a third lock a new file of the
# same name.
take_registry_lock() {
    mkdir -p "$PROJECTS_D" || return 1
    command -v flock >/dev/null 2>&1 || return 0
    exec 8>>"$REG_LOCK" || { echo "ERROR: cannot open the registry lock $REG_LOCK" >&2; return 1; }
    if ! flock -x -w "${PROJECT_FILE_LOCK_WAIT:-10}" 8; then
        echo "ERROR: another registration holds the registry lock $REG_LOCK; try again" >&2
        return 1
    fi
}

# A dry run writes nothing, the lock file included, and reads unlocked.
if [ "$DRY_RUN" -eq 0 ]; then
    [ "$MODE" = "remove" ] && NAME="$TARGET"
    take_registry_lock || final refused "try again" 1
fi

if ! registry_entries_full "$ROOT" >/dev/null; then
    echo "ERROR: the registry $REGISTRY does not parse (above); fix it first" >&2
    exit 1
fi

# Replace the registry with <tmp> after it parses, and holds <name> when
# <expect> is "present" (or not, when "absent"). With <entry> (the
# parser's "name<TAB>type<TAB>path<TAB>fields" line), the entry read back
# must be exactly that one, so a line the parser reads differently from
# what was asked is never written. The registry's mode is kept. Prints the
# parser's errors and returns 1 when it does not parse.
install_registry() { # <tmp> <name> <present|absent> [<entry>]
    local tmp="$1" want="$2" expect="$3" entry="${4:-}" err mode has=0 got
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
    if [ -n "$entry" ]; then
        got="$(registry_entries_full "$ROOT" "$tmp" 2>/dev/null | awk -F'\t' -v n="$want" '$1 == n')"
        if [ "$got" != "$entry" ]; then
            echo "ERROR: the new registry reads '$want' back as '${got//$'\t'/  }', not as asked ('${entry//$'\t'/  }'); not writing it" >&2
            rm -f "$tmp"
            return 1
        fi
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
        echo "would remove the registry line: $LINE"
        if [ -e "$SETTINGS" ]; then
            if [ "$KEEP_SETTINGS" -eq 1 ]; then echo "would keep the settings file $SETTINGS (--keep-settings)"
            else echo "would remove the settings file $SETTINGS:"; sed 's/^/    /' "$SETTINGS"; fi
        fi
        echo "would leave alone: the project at $PROJECT_ROOT, its records and its memory"
        final dry-run "run again without --dry-run to remove '$NAME'"
    fi
    # The registry without the line must parse (a parent's default_instance
    # may name it) before anything changes.
    TMP="$(registry_without_name "$NAME")" || final refused "could not write a new registry" 1
    if ! _err="$(registry_entries_full "$ROOT" "$TMP" 2>&1 >/dev/null)"; then
        printf '%s\n' "${_err//$TMP/$REGISTRY}" >&2
        rm -f "$TMP"
        echo "ERROR: the registry without '$NAME' would not parse (above); nothing removed" >&2
        final refused "fix the line that names '$NAME', then re-run" 1
    fi
    if ! install_registry "$TMP" "$NAME" absent; then
        echo "ERROR: could not write the registry without '$NAME' (above); the registry line and the settings file are kept" >&2
        final refused "remove its line from $REGISTRY by hand, or re-run register_project.sh --remove $NAME" 1
    fi
    echo "removed the registry line: $LINE"
    _remove_status="removed"
    _remove_next="nothing; register it again with register_project.sh $PROJECT_ROOT"
    _remove_rc=0
    if [ -e "$SETTINGS" ] || [ -L "$SETTINGS" ]; then
        if [ "$KEEP_SETTINGS" -eq 1 ]; then
            echo "kept the settings file $SETTINGS (--keep-settings)"
        else
            # Read before the removal, printed only once it is gone.
            _content="$(sed 's/^/    /' "$SETTINGS" 2>/dev/null)" || _content=""
            if rm -f -- "$SETTINGS" && [ ! -e "$SETTINGS" ] && [ ! -L "$SETTINGS" ]; then
                echo "removed the settings file $SETTINGS; its content was:"
                [ -n "$_content" ] && printf '%s\n' "$_content"
            else
                echo "ERROR: could not remove the settings file $SETTINGS (above); '$NAME' is unregistered, so nothing reads the file now" >&2
                _remove_status="removed, settings file left"
                _remove_next="remove $SETTINGS by hand"
                _remove_rc=1
            fi
        fi
    fi
    [ -f "$PROJECTS_D/$NAME.sh" ] && echo "NOTE: $PROJECTS_D/$NAME.sh is no longer read (issue #265 part 4) and is left in place: delete it"
    echo "left alone: the project at $PROJECT_ROOT, its records (in the project, or where its settings put them) and its memory"
    final "$_remove_status" "$_remove_next" "$_remove_rc"
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
    # A blank or '=' splits the line into other fields, and a '#' starts a
    # comment, so the parser would read back a different directory.
    if [[ "$PROJECT_ROOT" == *[[:space:]=#]* ]]; then
        echo "ERROR: the registry cannot hold a path with a blank, '=' or '#' ($PROJECT_ROOT): a '#' starts a comment there, so a shorter path would be registered" >&2
        final refused "move the project to a path without blanks, '=' or '#'" 1
    fi
fi

# --manifest sets a new root up: never on a registered name or path.
if [ -n "$MANIFEST" ] && [ "$ADOPT" -eq 1 ]; then
    echo "ERROR: '$NAME' is registered already, at $PROJECT_ROOT; --manifest sets a new root up and registers it, and is not used on a registered project (a root set up with the manifest tool already is registered by the same register_project.sh command without $M_OPTS)" >&2
    final refused "drop $M_OPTS, or give a new directory" 1
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

# The type that sets a root up from a manifest file: the one whose
# registration.conf says manifest=local-file. Prints it; returns 1 with
# the reason on stderr when there is not exactly one, or when a type's
# registration.conf cannot be read (so a type is never chosen by a list
# that skipped one).
manifest_type() {
    local d t v rc found="" bad=""
    for d in "$ROOT/.agent/project_types"/*/; do
        t="$(basename "$d")"
        [ -f "$d/adapter.sh" ] || continue
        rc=0; v="$(registration_conf_get "$ROOT" "$t" manifest 2>/dev/null)" || rc=$?
        if [ "$rc" -ne 0 ]; then bad="${bad:+$bad }$t"; continue; fi
        [ "$v" = local-file ] && found="${found:+$found }$t"
    done
    if [ -n "$bad" ]; then
        echo "ERROR: cannot tell which project type sets a root up from a manifest: the registration.conf of $bad is missing or invalid (.agent/scripts/validate_adapter.sh names the problem)" >&2
        return 1
    fi
    case "$found" in
        "") echo "ERROR: no project type sets a root up from a manifest (none has manifest=local-file in its registration.conf)" >&2; return 1 ;;
        *" "*) echo "ERROR: more than one project type sets a root up from a manifest ($found); give the type after the path" >&2; return 1 ;;
    esac
    echo "$found"
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
elif [ -n "$MANIFEST" ]; then
    TYPE="$(manifest_type)" || final refused "fix the project types' registration.conf, or give the type" 1
# .repos-manifest is tested as the adapter's route test does (there, or a
# link, even a dangling one), so a link to nothing is typed as it is routed.
elif [ -d "$PROJECT_ROOT/configs/manifest" ] || [ -e "$PROJECT_ROOT/.repos-manifest" ] || [ -L "$PROJECT_ROOT/.repos-manifest" ] \
    || set_value bootstrap_url >/dev/null; then
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
    CONF_MANIFEST="$(registration_conf_get "$ROOT" "$TYPE" manifest)"
    # A --set key the type lists in its registration_refused: its adapter
    # refuses a project that sets it, so the registration could never
    # pass; refused here, before anything is written.
    for _kv in ${SETS[@]+"${SETS[@]}"}; do
        _k="${_kv%%=*}"
        _rrc=0; _why="$(registration_refused_setting "$ROOT" "$TYPE" "$_k")" || _rrc=$?
        if [ "$_rrc" -eq 0 ]; then
            echo "ERROR: --set $_k is refused for a project of type $TYPE: $_why" >&2
            final refused "register $PROJECT_ROOT without --set $_k, after the steps above" 1
        elif [ "$_rrc" -eq 2 ]; then
            echo "ERROR: cannot tell whether type $TYPE refuses --set $_k: $_why" >&2
            final refused "fix $ROOT/.agent/project_types/$TYPE/registration_refused" 1
        fi
    done
    # A settings file kept from an earlier registration (--remove
    # --keep-settings) that sets such a key: the same, with the way on
    # for a file (project_setting.sh unset refuses an unregistered name).
    _kept="$(project_file_path "$ROOT" "$NAME")"
    if [ "$ADOPT" -eq 0 ] && [ -f "$_kept" ] && [ -r "$_kept" ]; then
        _refused_keys=""
        for _k in $_PROJECT_FILE_KEYS; do
            registration_refused_setting "$ROOT" "$TYPE" "$_k" >/dev/null 2>&1 && _refused_keys="${_refused_keys:+$_refused_keys, }$_k"
        done
        while IFS= read -r _l || [ -n "$_l" ]; do
            _l="$(_project_file_trim "${_l%$'\r'}")"
            [ -z "$_l" ] || [[ "$_l" == \#* ]] || [[ "$_l" != *=* ]] && continue
            _k="$(_project_file_trim "${_l%%=*}")"
            [[ "$SET_KEYS" == *" $_k "* ]] && continue
            _rrc=0; _why="$(registration_refused_setting "$ROOT" "$TYPE" "$_k")" || _rrc=$?
            if [ "$_rrc" -eq 0 ]; then
                echo "ERROR: the settings file $_kept, kept from an earlier registration, sets $_k, which is refused for a project of type $TYPE: $_why" >&2
                final refused "remove the $_refused_keys lines from $_kept (or remove the file), then re-run" 1
            elif [ "$_rrc" -eq 2 ]; then
                echo "ERROR: cannot tell whether type $TYPE refuses $_k (set in $_kept): $_why" >&2
                final refused "fix $ROOT/.agent/project_types/$TYPE/registration_refused" 1
            fi
        done < "$_kept"
    fi
else
    REQUIRED=""; CONF_SETUP="never"; CONF_RUN=""; CONF_MANIFEST=""
    [ "${#SETS[@]}" -eq 0 ] || die_usage "a parent root ($REGISTRY_PARENT_TYPE) has no settings of its own; --set them on its instances"
fi

# --manifest: the type, the root and the manifest, checked before anything
# is written (a dry run too).
TOOL_BIN="$ROOT/.venv/bin/repos-manifest"
M_ABS=""
ROOT_EXISTED=0
{ [ -e "$PROJECT_ROOT" ] || [ -L "$PROJECT_ROOT" ]; } && ROOT_EXISTED=1
# A root holding only these entries counts as empty: a Claude Code session
# started in the folder may have written its .claude/ there (issue 473).
root_is_empty() {
    local e
    for e in "$PROJECT_ROOT"/* "$PROJECT_ROOT"/.[!.]* "$PROJECT_ROOT"/..?*; do
        [ -e "$e" ] || [ -L "$e" ] || continue
        [ "$(basename "$e")" = .claude ] && continue
        return 1
    done
    return 0
}
# A location the manifest tool does not read in this version: a URL or a
# git location (scheme://..., user@host:path). Checked only for an
# argument that is not an existing regular file. The one place this script
# knows it; issue 498 replaces it (the tool reading a manifest from a git
# repo, and registration.conf then saying which locations a type takes).
manifest_is_remote() {
    [[ "$1" == *://* ]] || [[ "$1" =~ ^[^/:@]+@[^/:]+: ]]
}
if [ -n "$MANIFEST" ]; then
    if [ "$CONF_MANIFEST" != local-file ]; then
        echo "ERROR: a project of type $TYPE is not set up from a manifest (its registration.conf says manifest=${CONF_MANIFEST:-none})" >&2
        final refused "drop --manifest, or give a type that is set up from a manifest" 1
    fi
    if [ -e "$PROJECT_ROOT/.repos-manifest" ] || [ -L "$PROJECT_ROOT/.repos-manifest" ]; then
        echo "ERROR: $PROJECT_ROOT is set up already (it holds .repos-manifest/), so the manifest tool's init is not run there again; when its first sync did not finish, the tool's sync finishes it: cd $PROJECT_ROOT && $TOOL_BIN sync --distro $M_DISTRO" >&2
        final refused "register it: $M_RERUN" 1
    fi
    if [ "$ROOT_EXISTED" -eq 1 ] && [ ! -d "$PROJECT_ROOT" ]; then
        echo "ERROR: $PROJECT_ROOT is there and is not a directory" >&2
        final refused "give a new or empty directory" 1
    fi
    if [ "$ROOT_EXISTED" -eq 1 ] && ! root_is_empty; then
        echo "ERROR: $PROJECT_ROOT holds files already; a root is set up from a manifest in a new or empty directory (only a .claude/ may be there), so the tool's directories are not mixed with others" >&2
        final refused "give a new or empty directory" 1
    fi
    if [ -f "$MANIFEST" ]; then
        # Anchored first, and -- before each path, so a name that starts
        # with '-' is not read as an option; no CDPATH for this cd.
        case "$MANIFEST" in /*) _m="$MANIFEST" ;; *) _m="$PWD/$MANIFEST" ;; esac
        M_ABS="$(CDPATH='' cd -- "$(dirname -- "$_m")" && pwd -P)/$(basename -- "$_m")"
    elif manifest_is_remote "$MANIFEST"; then
        echo "ERROR: --manifest $MANIFEST: the manifest tool reads a manifest from the local disk only in this version (issue 498 adds a URL or a file in a git repo); clone the repo that holds it, keep the clone up to date by hand, and give the file in the clone (docs/manifest/design.md, \"A root that sets source\")" >&2
        final refused "give --manifest a file on the local disk" 1
    elif [ -e "$MANIFEST" ]; then
        echo "ERROR: --manifest $MANIFEST is not a regular file" >&2
        final refused "give --manifest a manifest file" 1
    else
        echo "ERROR: --manifest $MANIFEST: no such file" >&2
        final refused "give --manifest a manifest file on the local disk" 1
    fi
    # bootstrap_url is the bootstrap route's: on the tool's route validate
    # refuses it as a second record, after init has cloned every repo.
    _bu=""
    if set_value bootstrap_url >/dev/null; then
        _bu="--set bootstrap_url"
    elif [ "$ADOPT" -eq 0 ] && [ -f "$_kept" ] && grep -qE '^[[:space:]]*bootstrap_url[[:space:]]*=' "$_kept" 2>/dev/null; then
        _bu="the settings file $_kept, kept from an earlier registration,"
    fi
    if [ -n "$_bu" ]; then
        echo "ERROR: $_bu sets bootstrap_url, the bootstrap route's setting; a root set up from a manifest is on the manifest tool's route, where validate refuses it as a second record beside the tool's" >&2
        if [ "${_bu#--set}" != "$_bu" ]; then
            final refused "drop --set bootstrap_url" 1
        fi
        final refused "remove the bootstrap_url line from $_kept (or remove the file), then re-run" 1
    fi
fi
# --distro or --role without --manifest on a root the manifest tool set up,
# for a type that reads the tool's record: validate refuses them there as
# a second record, so the registration could never pass.
if [ -z "$MANIFEST" ] && [ "$CONF_MANIFEST" = local-file ] && { [ -n "$F_distro" ] || [ -n "$F_role" ]; } \
   && { [ -e "$PROJECT_ROOT/.repos-manifest" ] || [ -L "$PROJECT_ROOT/.repos-manifest" ]; }; then
    echo "ERROR: $PROJECT_ROOT holds .repos-manifest/: the manifest tool records its distros and role there, and a distro= or role= on the registry line is a second record that validate refuses" >&2
    final refused "drop --distro and --role" 1
fi
if [ -n "$F_default_instance" ] && [ "$IS_PARENT" -eq 0 ]; then
    die_usage "--default-instance is for a parent root (type $REGISTRY_PARENT_TYPE)"
fi

# The registry line: new, or the existing one kept (with a missing
# default_instance added to a parent root).
[ -n "$F_worktrees" ] && F_worktrees="$(abs_path "$F_worktrees")"
# The same for the trailing fields: a value with a blank, '=' or '#' would
# be read back as another value (role=sim#x as role=sim), so it is refused
# before anything is written.
for _f in $FIELD_KEYS; do
    _v="F_$_f"
    if [[ "${!_v}" == *[[:space:]=#]* ]]; then
        echo "ERROR: --${_f//_/-} '${!_v}': the registry cannot hold a value with a blank, '=' or '#' (a '#' starts a comment there)" >&2
        final refused "give --${_f//_/-} a value without blanks, '=' or '#'" 1
    fi
done
LINE_CHANGE=""
LINE_CHANGE_ENTRY=""
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
            LINE_CHANGE_ENTRY="$(registry_entries_full "$ROOT" | awk -F'\t' -v n="$NAME" '$1 == n { print $1 "\t" $2 "\t" $3 }')"
            LINE_CHANGE_ENTRY="$LINE_CHANGE_ENTRY"$'\t'"${_fields:+$_fields }default_instance=$F_default_instance"
            continue
        fi
        if [ "$_have" != "${!_v}" ]; then
            echo "ERROR: '$NAME' is registered with ${_f}=${_have:-(none)}; --${_f//_/-} ${!_v} would rewrite its line (no silent rewrite; edit $REGISTRY by hand)" >&2
            final refused "drop --${_f//_/-}, or edit the line by hand" 1
        fi
    done
else
    NEW_LINE="$NAME  $TYPE  $PROJECT_ROOT"
    _fields=""
    for _f in $FIELD_KEYS; do
        _v="F_$_f"
        [ -n "${!_v}" ] || continue
        NEW_LINE="$NEW_LINE  $_f=${!_v}"
        _fields="${_fields:+$_fields }$_f=${!_v}"
    done
    # What the parser must read back from NEW_LINE.
    NEW_ENTRY="$(printf '%s\t%s\t%s\t%s' "$NAME" "$TYPE" "$PROJECT_ROOT" "$_fields")"
fi

# ------------------------------------------------- the settings to write ---
SETTINGS="$(project_file_path "$ROOT" "$NAME")"
SETTINGS_EXISTED=0
{ [ -e "$SETTINGS" ] || [ -L "$SETTINGS" ]; } && SETTINGS_EXISTED=1
# A settings path that is there but is not a regular file (or a link to
# one) cannot be backed up or checked, and the writer would create a file
# through a dangling link: refused before anything is written.
if [ -L "$SETTINGS" ] && [ ! -e "$SETTINGS" ]; then
    echo "ERROR: the settings file $SETTINGS is a symlink to $(readlink -- "$SETTINGS" 2>/dev/null || echo '?'), which does not exist" >&2
    final refused "remove the link, or create its target, then re-run" 1
fi
if [ -e "$SETTINGS" ] && [ ! -f "$SETTINGS" ]; then
    echo "ERROR: the settings file $SETTINGS is there but is not a regular file (a directory, say)" >&2
    final refused "move $SETTINGS aside, then re-run" 1
fi
KV=()          # key=value to write
KV_NOTES=()    # where each came from
if [ "$IS_PARENT" -eq 0 ]; then
    for _kv in ${SETS[@]+"${SETS[@]}"}; do
        KV+=("$_kv"); KV_NOTES+=("${_kv%%=*}: from --set")
    done
    if [ "$SETTINGS_EXISTED" -eq 0 ]; then
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
    if [ "$SETTINGS_EXISTED" -eq 1 ] && [ -f "$SETTINGS" ] && ! cat "$SETTINGS" > "$_tmpf"; then
        rm -rf "$_tmpd"
        echo "ERROR: cannot read the settings file $SETTINGS (above), so the settings to write cannot be checked" >&2
        final refused "make $SETTINGS readable, then re-run" 1
    fi
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

# Setup: when the type runs it and the hosting directory is missing, or
# with --manifest (the root missing or empty, checked above).
RUN_SETUP=0
if [ "$CONF_SETUP" = "when-missing" ] && [ ! -e "$PROJECT_ROOT" ] && [ "$NO_SETUP" -eq 0 ]; then
    RUN_SETUP=1
fi
SETUP_ARGS=()
# SETUP_ARGS as printed: a --fetch-from prefix with its user name and
# password masked (mask_url_userinfo); SETUP_ARGS passes it as given.
SETUP_SHOWN=()
SETUP_WHY="$PROJECT_ROOT does not exist"
if [ -n "$MANIFEST" ]; then
    RUN_SETUP=1
    SETUP_ARGS=(--manifest "$M_ABS" --distro "$M_DISTRO")
    [ -n "$M_ROLE" ] && SETUP_ARGS+=(--role "$M_ROLE")
    for _g in ${M_WITH[@]+"${M_WITH[@]}"}; do SETUP_ARGS+=(--with "$_g"); done
    SETUP_SHOWN=("${SETUP_ARGS[@]}")
    [ -n "$M_FETCH" ] && SETUP_ARGS+=(--fetch-from "$M_FETCH") \
        && SETUP_SHOWN+=(--fetch-from "$(mask_url_userinfo "$M_FETCH")")
    SETUP_WHY="from the manifest; $PROJECT_ROOT $([ "$ROOT_EXISTED" -eq 1 ] && echo "is empty" || echo "does not exist")"
    # What the adapter's setup runs in the root, for the dry run.
    INIT_LINE="cd $(printf '%q' "$PROJECT_ROOT") && $(printf '%q' "$TOOL_BIN") init $(printf '%q' "$M_ABS") --distro-dirs --distro $(printf '%q' "$M_DISTRO")"
    [ -n "$M_ROLE" ] && INIT_LINE="$INIT_LINE --role $(printf '%q' "$M_ROLE")"
    for _g in ${M_WITH[@]+"${M_WITH[@]}"}; do INIT_LINE="$INIT_LINE --with $(printf '%q' "$_g")"; done
    if [ -n "$M_FETCH" ]; then
        # Masked, the value is shown, not quoted: it is not run as printed.
        _f="$(mask_url_userinfo "$M_FETCH")"
        [ "$_f" = "$M_FETCH" ] && _f="$(printf '%q' "$M_FETCH")"
        INIT_LINE="$INIT_LINE --fetch-from $_f"
    fi
    INIT_LINE="$INIT_LINE --yes"
fi
# The directories setup would make (the root, and each missing one above
# it), the shallowest first: a rollback with --manifest removes those
# still empty, deepest first, with rmdir alone.
MISSING_DIRS=()
if [ -n "$MANIFEST" ]; then
    _d="$PROJECT_ROOT"
    while [ ! -e "$_d" ] && [ ! -L "$_d" ]; do
        MISSING_DIRS=("$_d" ${MISSING_DIRS[@]+"${MISSING_DIRS[@]}"})
        _d="$(dirname "$_d")"
    done
fi
RUN_VERBS=""
[ "$SKIP_RUN" -eq 0 ] && RUN_VERBS="$CONF_RUN"

# The user tier.
ROOT_FILE="${HOME:-}/.claude/agent-workspace-root"
UT_STATE="absent"
# An empty (or unreadable) file names no checkout: it is read as absent,
# never as a path (phys "" would answer the current directory).
UT_ROOT=""
[ -f "$ROOT_FILE" ] && { UT_ROOT="$(cat "$ROOT_FILE" 2>/dev/null)" || UT_ROOT=""; }
if [ -n "$UT_ROOT" ]; then
    if [ "$(phys "$UT_ROOT")" = "$(phys "$ROOT")" ]; then UT_STATE="here"; else UT_STATE="elsewhere"; fi
fi
RUN_UT=0
{ [ "$UT_STATE" = here ] || [ "$INSTALL_UT" -eq 1 ]; } && RUN_UT=1
ONBOARD_NEXT="start a Claude Code session at $PROJECT_ROOT and run /agent-workspace:onboard-project"
ut_note() {
    case "$UT_STATE" in
        absent)
            [ -f "$ROOT_FILE" ] && echo "WARNING: $ROOT_FILE is empty or unreadable, so it names no checkout"
            echo "WARNING: the user tier is not installed, so a session started at $PROJECT_ROOT gets no workspace layer or skills: install it with .agent/scripts/user_tier_install.sh (or re-run with --install-user-tier)" ;;
        elsewhere) echo "WARNING: the user tier is installed for another checkout ($UT_ROOT), so it is not checked from here: run that checkout's installer, or this one's with --force to take it over" ;;
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
    if [ "$RUN_SETUP" -eq 1 ]; then
        echo "would run: adapter --project $NAME setup${SETUP_SHOWN[*]:+ ${SETUP_SHOWN[*]}} ($SETUP_WHY)"
        [ -n "$MANIFEST" ] && echo "    which runs: $INIT_LINE"
    fi
    echo "would run: registration_verify.sh $NAME"
    for _v in $RUN_VERBS; do echo "would run: adapter --project $NAME $_v"; done
    [ "$SKIP_RUN" -eq 1 ] && [ -n "$CONF_RUN" ] && echo "would not run: $CONF_RUN (--skip-run)"
    if [ "$RUN_UT" -eq 1 ]; then
        [ "$INSTALL_UT" -eq 1 ] && echo "would run: user_tier_install.sh (--install-user-tier)"
        echo "would run: registration_verify.sh $NAME --user-tier"
    else
        ut_note
    fi
    final dry-run "run again without --dry-run"
fi

# ------------------------------------------------------------- register ---
ROLLBACK_ARMED=0
LINE_WRITTEN=0
SETTINGS_BACKUP=""
SETUP_RAN=0
CHANGED=0
LINE_CHANGED=0       # an adopted line got its default_instance
SETTINGS_CHANGED=0   # the settings file was written by this run
# What a rollback could not undo, "; "-separated, and whether the registry
# line is among it (the project is then still registered).
ROLLBACK_LEFT=""
LINE_LEFT=0
ROLLBACK_RUNNING=0      # a rollback has started and not finished
ROLLBACK_DONE=" "       # its steps finished so far, " "-separated
ENDING=0                # a handler is ending the run: a signal then waits
SETTINGS_WRITING=0      # this run started writing the settings file
SETTINGS_WRITTEN_SUM="" # the file's checksum once this run wrote it
# The settings file's checksum, "absent" when there is none.
settings_sum() {
    if [ -e "$SETTINGS" ]; then cksum < "$SETTINGS" 2>/dev/null || echo unreadable
    else echo absent; fi
}
rollback_left() { ROLLBACK_LEFT="${ROLLBACK_LEFT:+$ROLLBACK_LEFT; }$1"; }

# Copy the settings file aside before a new registration changes it (an
# existing file with no registry line, kept by --remove --keep-settings).
# Returns 1, with SETTINGS_BACKUP empty and nothing left behind, when the
# copy cannot be made.
backup_settings() {
    SETTINGS_BACKUP="$(mktemp "$PROJECTS_D/.settings-backup.XXXXXX")" || { SETTINGS_BACKUP=""; return 1; }
    if ! cp -p -- "$SETTINGS" "$SETTINGS_BACKUP"; then
        rm -f -- "$SETTINGS_BACKUP"
        SETTINGS_BACKUP=""
        return 1
    fi
}

# Put the backup back: a copy beside the destination (the file, or a
# symlink's target), renamed onto it, so the file is never seen half
# written; then checked against the backup. On failure the backup is kept
# and named, for a restore by hand.
restore_settings() {
    local dest tmp
    if dest="$(_project_file_dest "$SETTINGS")" \
       && tmp="$(mktemp "$(dirname "$dest")/.settings-restore.XXXXXX")"; then
        if cp -p -- "$SETTINGS_BACKUP" "$tmp" && mv -f -- "$tmp" "$dest" && cmp -s -- "$SETTINGS_BACKUP" "$SETTINGS"; then
            rm -f -- "$SETTINGS_BACKUP"
            echo "  restored the settings file $SETTINGS" >&2
            return 0
        fi
        rm -f -- "$tmp"
    fi
    echo "  WARNING: could not restore the settings file $SETTINGS (above); its content before this run is kept in $SETTINGS_BACKUP: copy it back by hand" >&2
    return 1
}

rollback() {
    [ "$ROLLBACK_ARMED" -eq 1 ] || return 0
    ROLLBACK_ARMED=0
    ROLLBACK_RUNNING=1
    echo "" >&2
    echo "Rolling back the registration of '$NAME':" >&2
    # LINE_WRITTEN is set before the registry is renamed, so a signal
    # between the rename and the next line still gets here; the line is
    # looked for, since the rename may not have happened. The name was free
    # under the lock this run holds, so a line with it is this run's.
    if [ "$LINE_WRITTEN" -eq 1 ] && registry_raw_line "$NAME" >/dev/null; then
        local tmp
        if tmp="$(registry_without_name "$NAME")" && install_registry "$tmp" "$NAME" absent; then
            echo "  removed the registry line" >&2
        else
            echo "  WARNING: could not remove the registry line for '$NAME' from $REGISTRY; remove it by hand" >&2
            rollback_left "its registry line in $REGISTRY"
            LINE_LEFT=1
        fi
    fi
    ROLLBACK_DONE+="line "
    if [ "$SETTINGS_WRITING" -eq 1 ] && [ -n "$SETTINGS_WRITTEN_SUM" ] \
       && [ "$(settings_sum)" != "$SETTINGS_WRITTEN_SUM" ]; then
        # Changed after this run wrote it (a project_setting.sh set during
        # the build, say): someone else's change, kept as it is.
        echo "  WARNING: the settings file $SETTINGS changed after this run wrote it (a project_setting.sh set during the run, say), so it is kept as it is, with no registry line${SETTINGS_BACKUP:+; its content before this run is in $SETTINGS_BACKUP}" >&2
    elif [ "$SETTINGS_WRITING" -eq 0 ]; then
        # This run never wrote the file: not this run's to restore or
        # remove. A backup taken before the write (an exit between the two)
        # only duplicates it, so it goes.
        if [ -n "$SETTINGS_BACKUP" ] && [ -e "$SETTINGS_BACKUP" ] \
           && ! { rm -f -- "$SETTINGS_BACKUP" && [ ! -e "$SETTINGS_BACKUP" ]; }; then
            echo "  WARNING: could not remove the backup $SETTINGS_BACKUP of the settings file (above); the settings file was not changed, so remove it by hand" >&2
            rollback_left "the backup of the settings file's content before this run, $SETTINGS_BACKUP (remove it)"
        fi
    elif [ -n "$SETTINGS_BACKUP" ]; then
        restore_settings || rollback_left "the settings file $SETTINGS as this run wrote it (its content before the run is in $SETTINGS_BACKUP)"
    elif [ "$SETTINGS_EXISTED" -eq 0 ] && { [ -e "$SETTINGS" ] || [ -L "$SETTINGS" ]; }; then
        if rm -f -- "$SETTINGS" && [ ! -e "$SETTINGS" ] && [ ! -L "$SETTINGS" ]; then
            echo "  removed the settings file $SETTINGS" >&2
        else
            echo "  WARNING: could not remove the settings file $SETTINGS (above); remove it by hand" >&2
            rollback_left "the settings file $SETTINGS"
        fi
    fi
    ROLLBACK_DONE+="settings "
    if [ "$SETUP_RAN" -eq 1 ] && [ -n "$MANIFEST" ]; then
        rollback_manifest_root
    elif [ "$SETUP_RAN" -eq 1 ] && [ -e "$PROJECT_ROOT" ]; then
        KEPT="$PROJECT_ROOT"
        echo "  kept $PROJECT_ROOT: created by setup; remove it, or re-run register_project.sh to reuse it" >&2
    fi
    ROLLBACK_RUNNING=0
}
# The root after a failed setup from a manifest. One that did not exist:
# removed with each directory above it this run made, deepest first, by
# rmdir alone while they are empty (init made nothing, or the adapter was
# stopped before its own cleanup); otherwise kept and named on KEPT=
# (init made the system: its clones are slow to redo, and the tool's sync
# finishes it). One that existed before: never on KEPT=, never touched,
# and named when init left something in it. Prints nothing else.
rollback_manifest_root() {
    local i
    if [ "$ROOT_EXISTED" -eq 0 ]; then
        if [ -d "$PROJECT_ROOT" ]; then
            if ! rmdir -- "$PROJECT_ROOT" 2>/dev/null; then
                KEPT="$PROJECT_ROOT"
                echo "  kept $PROJECT_ROOT: created by setup, and the manifest tool's init left something there" >&2
                return 0
            fi
            echo "  removed $PROJECT_ROOT (empty, made by setup)" >&2
        fi
        for (( i=${#MISSING_DIRS[@]}-1; i>=0; i-- )); do
            [ "${MISSING_DIRS[$i]}" = "$PROJECT_ROOT" ] && continue
            [ -d "${MISSING_DIRS[$i]}" ] || continue
            rmdir -- "${MISSING_DIRS[$i]}" 2>/dev/null || break
            echo "  removed ${MISSING_DIRS[$i]} (empty, made by setup)" >&2
        done
    elif ! root_is_empty; then
        echo "  $PROJECT_ROOT existed before; it holds what init left" >&2
    fi
}
# With --manifest, once the root holds the tool's record: the tool's own
# next step and registering without --manifest. Empty otherwise.
manifest_next() {
    [ -n "$MANIFEST" ] && [ "$SETUP_RAN" -eq 1 ] || return 0
    [ -e "$PROJECT_ROOT/.repos-manifest" ] || [ -L "$PROJECT_ROOT/.repos-manifest" ] || return 0
    echo "cd $PROJECT_ROOT && $TOOL_BIN sync --distro $M_DISTRO when the sync did not finish, then $M_RERUN"
}
# What a rollback cut short leaves (an exit inside it): each step it had
# not finished, under the conditions that step undoes, checked on disk
# where it can be.
rollback_unfinished() {
    if [[ "$ROLLBACK_DONE" != *" line "* ]] && [ "$LINE_WRITTEN" -eq 1 ] && registry_raw_line "$NAME" >/dev/null; then
        rollback_left "its registry line in $REGISTRY"
        LINE_LEFT=1
    fi
    # The hidden backup is always named while it is there: beside the file
    # as this run wrote it, or alone when the file no longer matches that
    # write (put back by a restore cut short after its rename, or changed
    # during the run, when the backup is the only copy of the content
    # before the run).
    if [[ "$ROLLBACK_DONE" != *" settings "* ]]; then
        local ours=0
        if [ "$SETTINGS_WRITING" -eq 1 ] \
           && { [ -z "$SETTINGS_WRITTEN_SUM" ] || [ "$(settings_sum)" = "$SETTINGS_WRITTEN_SUM" ]; }; then
            ours=1
        fi
        if [ -n "$SETTINGS_BACKUP" ] && [ -e "$SETTINGS_BACKUP" ]; then
            if [ "$ours" -eq 1 ]; then
                rollback_left "the settings file $SETTINGS as this run wrote it (its content before the run is in $SETTINGS_BACKUP)"
            else
                rollback_left "the backup of the settings file's content before this run, $SETTINGS_BACKUP (remove it once $SETTINGS is right)"
            fi
        elif [ "$ours" -eq 1 ] && [ -z "$SETTINGS_BACKUP" ] && [ "$SETTINGS_EXISTED" -eq 0 ] \
             && { [ -e "$SETTINGS" ] || [ -L "$SETTINGS" ]; }; then
            rollback_left "the settings file $SETTINGS"
        fi
    fi
    if [ "$SETUP_RAN" -eq 1 ] && [ -e "$PROJECT_ROOT" ] && { [ -z "$MANIFEST" ] || [ "$ROOT_EXISTED" -eq 0 ]; }; then
        KEPT="$PROJECT_ROOT"
    fi
}
# What an adopted project keeps when a run stops early: it is never
# rolled back, so say what this run already changed.
adopt_kept() {
    local line="its registry line is unchanged" settings="its settings file is unchanged"
    [ "$LINE_CHANGED" -eq 1 ] && line="its registry line keeps the change above"
    [ "$SETTINGS_CHANGED" -eq 1 ] && settings="its settings file keeps the values written above"
    [ "$IS_PARENT" -eq 1 ] && settings="a parent root has no settings file"
    echo "  '$NAME' was already registered, so nothing is rolled back: it stays registered; $line; $settings" >&2
}
# The last lines after a rollback: "refused" with <next> when it undid
# everything; otherwise what it left, and NOT READY while the registry line
# is among it (the project is then still registered, unchecked).
rolled_back_final() { # <next> <exit code>
    local status=refused
    if [ -z "$ROLLBACK_LEFT" ]; then
        final refused "$1" "$2"
    fi
    echo "" >&2
    echo "ERROR: the rollback could not undo everything; left: $ROLLBACK_LEFT" >&2
    [ "$LINE_LEFT" -eq 1 ] && status="NOT READY"
    final "$status" "undo by hand what the rollback left ($ROLLBACK_LEFT), then $1" "$2"
}
# A signal while a handler is already ending the run (a failure, an
# interrupt or an unexpected exit, its rollback included) waits for it to
# finish: bash runs this after the running command returns, and the
# return resumes the handler where it was.
on_signal() {
    if [ "$ENDING" -eq 1 ] || [ "$ROLLBACK_RUNNING" -eq 1 ]; then
        if [ "$ROLLBACK_RUNNING" -eq 1 ]; then
            echo "  (signal received: finishing the rollback first)" >&2
        else
            echo "  (signal received: finishing the run's last steps first)" >&2
        fi
        return 0
    fi
    ENDING=1
    if [ "$ADOPT" -eq 1 ]; then
        echo "" >&2
        echo "Interrupted." >&2
        adopt_kept
        final "NOT READY" "interrupted before its checks finished; re-run register_project.sh $NAME" "$1"
    fi
    rollback
    local mnext
    mnext="$(manifest_next)"
    if [ -n "$ROLLBACK_LEFT" ]; then
        rolled_back_final "${mnext:-re-run register_project.sh} (interrupted)" "$1"
    fi
    final refused "interrupted; nothing is registered${mnext:+; then $mnext}" "$1"
}
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
trap 'on_signal 129' HUP

# A failure: a new registration is rolled back; an adopted one is kept.
failed() { # <what failed> <next>
    ENDING=1
    if [ "$ADOPT" -eq 1 ]; then
        echo "" >&2
        echo "ERROR: $1" >&2
        adopt_kept
        final "NOT READY" "$2" 1
    fi
    echo "" >&2
    echo "ERROR: $1" >&2
    rollback
    local mnext
    mnext="$(manifest_next)"
    if [ -n "$mnext" ]; then
        rolled_back_final "$2; then $mnext${KEPT:+ (setup is not run again on the kept $KEPT; remove it first to start over)}" 1
    fi
    if [ -n "$KEPT" ]; then
        rolled_back_final "$2; then re-run register_project.sh (setup is not run again on the kept $KEPT; remove it first to start over)" 1
    fi
    rolled_back_final "$2" 1
}

# An exit that no step chose (an unset variable under set -u, say): the
# same rollback and last lines as a failure, never a silent stop.
RUN_STARTED=0
on_exit() {
    local rc=$?
    { [ "$FINAL_DONE" -eq 0 ] && [ "$RUN_STARTED" -eq 1 ]; } || return 0
    ENDING=1
    [ "$rc" -eq 0 ] && rc=1
    echo "" >&2
    echo "ERROR: register_project.sh stopped unexpectedly (exit $rc, above)" >&2
    if [ "$ROLLBACK_RUNNING" -eq 1 ]; then
        # It stopped inside the rollback: never a clean result.
        rollback_unfinished
        echo "ERROR: the rollback stopped part way; left: ${ROLLBACK_LEFT:-nothing it undoes was found left}" >&2
        if [ -n "$ROLLBACK_LEFT" ]; then
            final "NOT READY" "the rollback stopped part way: undo by hand what it left ($ROLLBACK_LEFT), then re-run register_project.sh, and report the error above" "$rc"
        fi
        final "NOT READY" "the rollback stopped part way: check $REGISTRY and $SETTINGS for '$NAME' by hand, then re-run register_project.sh, and report the error above" "$rc"
    fi
    if [ "$ADOPT" -eq 1 ]; then
        adopt_kept
        final "NOT READY" "stopped unexpectedly; re-run register_project.sh $NAME, and report the error above if it recurs" "$rc"
    fi
    rollback
    local mnext
    mnext="$(manifest_next)"
    rolled_back_final "${mnext:-re-run register_project.sh}, and report the error above if it recurs" "$rc"
}
trap on_exit EXIT

RUN_STARTED=1
[ "$ADOPT" -eq 0 ] && ROLLBACK_ARMED=1

# 1. The registry line and the settings file.
if [ "$ADOPT" -eq 0 ]; then
    TMP="$(registry_with_line "$NEW_LINE")" || failed "could not write a new registry" "check $PROJECTS_D is writable"
    # Before the rename: a signal right after it must still remove the line.
    LINE_WRITTEN=1
    install_registry "$TMP" "$NAME" present "$NEW_ENTRY" || failed "the new registry line does not parse as asked (above)" "fix the arguments"
    CHANGED=1
    echo "added the registry line: $NEW_LINE"
elif [ -n "$LINE_CHANGE" ]; then
    # The changed line where the old one was; every other line kept.
    TMP="$(mktemp "$PROJECTS_D/.registry.XXXXXX")" || failed "could not write a new registry" "check $PROJECTS_D is writable"
    while IFS= read -r _raw || [ -n "$_raw" ]; do
        _first=""; read -r _first _ <<< "${_raw%%#*}" || true
        if [ "${_first%$'\r'}" = "$NAME" ]; then printf '%s\n' "$LINE_CHANGE"; else printf '%s\n' "$_raw"; fi
    done < "$REGISTRY" > "$TMP"
    install_registry "$TMP" "$NAME" present "$LINE_CHANGE_ENTRY" || failed "the changed registry line does not parse as asked (above)" "fix --default-instance"
    CHANGED=1
    LINE_CHANGED=1
    echo "changed the registry line to: $LINE_CHANGE"
else
    echo "registry line kept as it is: $(registry_raw_line "$NAME")"
fi
if [ "${#KV[@]}" -gt 0 ]; then
    if [ "$SETTINGS_EXISTED" -eq 1 ] && [ "$ADOPT" -eq 0 ] && [ -f "$SETTINGS" ]; then
        backup_settings || failed "could not back up the settings file $SETTINGS (above), so it is not changed" "check $PROJECTS_D is writable and $SETTINGS readable"
    fi
    for _i in "${!KV[@]}"; do echo "  ${KV[$_i]}    (${KV_NOTES[$_i]#*: })"; done
    SETTINGS_WRITING=1
    _out="$(project_file_set "$ROOT" "$NAME" "${KV[@]}")" || failed "the settings file could not be written (above)" "fix the --set values"
    SETTINGS_WRITTEN_SUM="$(settings_sum)"
    echo "$_out"
    [[ "$_out" == unchanged* ]] || { CHANGED=1; SETTINGS_CHANGED=1; }
elif [ "$IS_PARENT" -eq 0 ]; then
    if [ "$SETTINGS_EXISTED" -eq 1 ]; then echo "unchanged $SETTINGS"; else echo "no settings file (nothing to write)"; fi
fi
[ "$CHANGED" -eq 0 ] && echo "nothing changed: '$NAME' was registered with these settings already"

if [ "$RUN_SETUP" -eq 1 ]; then
    echo ""
    echo "== adapter --project $NAME setup${SETUP_SHOWN[*]:+ ${SETUP_SHOWN[*]}} ($SETUP_WHY)"
    SETUP_RAN=1
    if [ -n "$MANIFEST" ]; then
        "$ADAPTER" --from "$ROOT" --project "$NAME" setup "${SETUP_ARGS[@]}" 8>&- || failed "adapter setup failed (above)" "fix what the manifest tool reports"
    else
        "$ADAPTER" --from "$ROOT" --project "$NAME" setup 8>&- || failed "adapter setup failed (above)" "fix the setup failure (its bootstrap_url, say)"
    fi
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
    if [ "$INSTALL_UT" -eq 1 ]; then
        echo "== user_tier_install.sh"
        "$INSTALLER" 8>&- || failed "the user-tier installer failed (above)" "fix the installer failure"
        echo ""
    fi
    echo "== registration_verify.sh $NAME --user-tier"
    "$VERIFY" "$NAME" --user-tier 8>&- || failed "the user-tier check failed (above)" "fix what registration_verify.sh reports (a user tier that is out of date is repaired by .agent/scripts/user_tier_install.sh, or by re-running with --install-user-tier)"
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
