# shellcheck shell=bash
# .agent/project_types/single_project/adapter.sh
# single_project adapter — one repo cloned or symlinked at $WORKSPACE_ROOT/project.
#
# Facade over the pre-adapter workspace scripts (ADR-0011, #210): behavior
# matches the old build.sh/test.sh/setup_project.sh/sync_project.py flow,
# except that a registered project's build/test/install command comes first
# from its settings file .agent/projects.d/<name> (issue #332; see
# _single_project_resolve_cmd) and a fall-through to the shared
# .agent/project_config.sh is reported on stderr. Changed from main (issue
# #332): BUILD_CMD, TEST_CMD and INSTALL_CMD inherited from the caller's
# environment are no longer honoured; they are cleared before the legacy or
# shared config is sourced, so only a config file sets them (a config line
# such as BUILD_CMD="${BUILD_CMD:-make}" now always gives its default).
#
# Sourced by .agent/scripts/adapter with WORKSPACE_ROOT and ADAPTER_TYPE_DIR
# set as shell variables (not exported). Not executable on its own; must be
# silent at source time.

# Resolve one command setting (issue #332), per setting in this order:
#   1. the key in the per-project settings file .agent/projects.d/<name>
#      (the dispatcher's ACTIVE_PROJECT_BUILD/_TEST/_INSTALL);
#   2. <VAR> in the legacy .agent/projects.d/<name>.sh, when that file
#      exists (it is then the whole legacy layer, as before #332);
#   3. otherwise <VAR> in the shared .agent/project_config.sh.
# Sets SP_CMD (the value; empty when nothing sets it) and SP_CMD_FROM
# (file | legacy | shared | empty). The legacy or shared config is sourced
# in the current shell, as the pre-adapter scripts did; <VAR> is cleared
# first so only a config file can set it, never the caller's environment.
#
# Callers must NOT guard this with `||` — verbs run under the dispatcher's
# set -e, and an unguarded call is what makes a failure inside a sourced
# config abort the verb (matching the old top-level-source behavior).
_single_project_resolve_cmd() {
    local key="$1" var_name="$2" shared pf=""
    SP_CMD=""
    SP_CMD_FROM=""
    case "$key" in
        build) pf="${ACTIVE_PROJECT_BUILD:-}" ;;
        test) pf="${ACTIVE_PROJECT_TEST:-}" ;;
        install) pf="${ACTIVE_PROJECT_INSTALL:-}" ;;
    esac
    if [ -n "$pf" ]; then
        SP_CMD="$pf"
        SP_CMD_FROM="file"
        return 0
    fi
    printf -v "$var_name" '%s' ""
    if [ -n "${ACTIVE_PROJECT_CONFIG:-}" ] && [ -f "$ACTIVE_PROJECT_CONFIG" ]; then
        # shellcheck source=/dev/null
        source "$ACTIVE_PROJECT_CONFIG"
        if [ -n "${!var_name:-}" ]; then
            SP_CMD="${!var_name}"
            SP_CMD_FROM="legacy"
        fi
        return 0
    fi
    shared="$WORKSPACE_ROOT/.agent/project_config.sh"
    if [ -f "$shared" ]; then
        # shellcheck source=/dev/null
        source "$shared"
        if [ -n "${!var_name:-}" ]; then
            SP_CMD="${!var_name}"
            SP_CMD_FROM="shared"
        fi
    fi
    return 0
}

# Load a required command (build or test) into SP_CMD / SP_CMD_FROM, or
# print guidance and return 1. Prints the fallback note when a registered
# project's command comes from the shared config.
#
# Callers must NOT guard this with `||` (see _single_project_resolve_cmd).
_single_project_load_cmd() {
    local key="$1" var_name="$2" shared
    shared="$WORKSPACE_ROOT/.agent/project_config.sh"
    _single_project_resolve_cmd "$key" "$var_name"
    if [ -n "$SP_CMD" ]; then
        [ "$SP_CMD_FROM" = "shared" ] && active_project_fallback_note "$key"
        return 0
    fi
    if [ -n "${ACTIVE_PROJECT_NAME:-}" ]; then
        echo "❌ project '$ACTIVE_PROJECT_NAME' has no $key command."
        if [ -n "${ACTIVE_PROJECT_CONFIG:-}" ] && [ -f "$ACTIVE_PROJECT_CONFIG" ]; then
            echo "   ($var_name is not set in its legacy config $ACTIVE_PROJECT_CONFIG)"
        fi
        echo ""
        echo "Set it in its settings file ($ACTIVE_PROJECT_FILE):"
        echo ""
        echo "  .agent/scripts/project_setting.sh set $ACTIVE_PROJECT_NAME $key=<command>"
        echo ""
        echo "  (a plain command run from the project root, or a script path;"
        echo "   $key=none records that the project has none)"
        echo ""
        return 1
    fi
    if [ ! -f "$shared" ]; then
        echo "❌ No project_config.sh found."
        echo ""
        echo "Create $shared with your project commands:"
        echo ""
        echo "  cat > $shared << 'EOF'"
        echo "  # Per-developer project configuration (gitignored)"
        echo "  PROJECT_TYPE=\"single_project\""
        echo "  BUILD_CMD=\"make\"          # or: cmake --build build, cargo build, etc."
        echo "  TEST_CMD=\"make test\"      # or: cargo test, pytest, etc."
        echo "  INSTALL_CMD=\"\"            # optional deploy/install command"
        echo "  EOF"
        echo ""
        return 1
    fi
    echo "❌ $var_name is not set in $shared"
    echo ""
    echo "Add to $shared:"
    echo "  $var_name=\"...\"   # your project's command"
    echo ""
    return 1
}

# Run the resolved command (SP_CMD / SP_CMD_FROM) from the project root.
# A settings-file value is split into argv and run without a shell; a
# legacy or shared value keeps the pre-adapter word splitting.
_single_project_exec_cmd() {
    echo "Running: $SP_CMD $*"
    echo ""
    cd "$(adapter_project_root)" || return 1
    if [ "$SP_CMD_FROM" = "file" ]; then
        active_project_exec "$SP_CMD" "$@"
    fi
    # shellcheck disable=SC2086
    exec $SP_CMD "$@"
}

adapter_setup() {
    if [ -n "${ACTIVE_PROJECT_NAME:-}" ]; then
        exec "$ADAPTER_TYPE_DIR/setup.sh" --project-root "$(adapter_project_root)" "$@"
    fi
    exec "$ADAPTER_TYPE_DIR/setup.sh" "$@"
}

adapter_sync() {
    if [ -n "${ACTIVE_PROJECT_NAME:-}" ]; then
        exec python3 "$ADAPTER_TYPE_DIR/sync.py" --project-root "$(adapter_project_root)" "$@"
    fi
    exec python3 "$ADAPTER_TYPE_DIR/sync.py" "$@"
}

adapter_validate() {
    # Checkout shape for this one project only (issue #330): a git repo at
    # the project root. The whole-workspace check is validate_workspace.py
    # (`make validate`), which delegates each registry entry back here.
    #
    # `.git` must be present AT the root (symlink-resolved, the same test
    # validate_workspace.py uses) — not `git rev-parse --git-dir`, which
    # succeeds for any directory nested inside another repo and would pass a
    # non-git hosting dir under the workspace checkout.
    #
    # Messages name the path, not the project: validate_workspace.py
    # prefixes each line with the project's name when it delegates here.
    local root
    root="$(adapter_project_root)"
    if [ ! -e "$root" ]; then
        echo "❌ checkout does not exist: $root" >&2
        return 1
    fi
    local resolved
    resolved="$(cd "$root" 2>/dev/null && pwd -P)" || resolved="$root"
    if [ ! -e "$root/.git" ] && [ ! -e "$resolved/.git" ]; then
        echo "❌ $root is not a git repository (no .git at its root)" >&2
        return 1
    fi
    echo "✅ single_project checkout is a git repository: $root"
}

adapter_build() {
    _single_project_load_cmd build BUILD_CMD
    if [ "$SP_CMD" = "none" ] && [ "$SP_CMD_FROM" = "file" ]; then
        echo "build=none: project '$ACTIVE_PROJECT_NAME' records that it has no build step — nothing to build."
        return 0
    fi
    _single_project_exec_cmd "$@"
}

adapter_test() {
    _single_project_load_cmd test TEST_CMD
    if [ "$SP_CMD" = "none" ] && [ "$SP_CMD_FROM" = "file" ]; then
        echo "test=none: project '$ACTIVE_PROJECT_NAME' records that it has no tests — nothing to run."
        return 0
    fi
    _single_project_exec_cmd "$@"
}

adapter_install() {
    _single_project_resolve_cmd install INSTALL_CMD
    if [ "$SP_CMD" = "none" ] && [ "$SP_CMD_FROM" = "file" ]; then
        echo "install=none: project '$ACTIVE_PROJECT_NAME' records that it has no install step — nothing to install."
        return 0
    fi
    if [ -z "$SP_CMD" ]; then
        echo "INSTALL_CMD not set — nothing to install (this is fine for most projects)."
        return 0
    fi
    [ "$SP_CMD_FROM" = "shared" ] && active_project_fallback_note install
    _single_project_exec_cmd "$@"
}

adapter_env() {
    # single_project exposes no project environment.
    :
}

adapter_project_root() {
    # ACTIVE_PROJECT_ROOT is set by the dispatcher (registry hosting dir for
    # named projects, project/ for the legacy shape).
    echo "${ACTIVE_PROJECT_ROOT:-$WORKSPACE_ROOT/project}"
}

adapter_repos() {
    local root
    root="$(adapter_project_root)"
    if [ ! -d "$root" ] || ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
        if [ -n "${ACTIVE_PROJECT_NAME:-}" ]; then
            echo "ERROR: project '$ACTIVE_PROJECT_NAME' is not checked out at $root" >&2
        else
            echo "ERROR: project/ is not configured (run: make setup)" >&2
        fi
        return 1
    fi
    local name
    name="$(basename "$(cd "$root" && pwd -P)")"
    echo "${name}:${root}"
}

adapter_worktree_repos() {
    # Single repo, single entry: the project checkout itself, rel path ".".
    # single_project never branches on --layer/--package-repos (ADR-0012).
    local issue="" layer="" package_repos=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --issue) issue="${2:-}"; shift 2 ;;
            --layer) layer="${2:-}"; shift 2 ;;
            --package-repos) package_repos="${2:-}"; shift 2 ;;
            *) echo "ERROR: worktree_repos: unknown argument '$1'" >&2; return 1 ;;
        esac
    done
    if [ -z "$issue" ]; then
        echo "ERROR: worktree_repos requires --issue <N|owner/repo#N>" >&2
        return 1
    fi
    if [ -n "$layer" ] || [ -n "$package_repos" ]; then
        echo "ERROR: single_project does not support --layer/--package-repos (no layers to worktree)" >&2
        return 1
    fi
    local num="${issue##*#}"
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --issue must be a number or end in #<number> (got '$issue')" >&2
        return 1
    fi
    printf '%s\t.\tfeature/issue-%s\n' "$(adapter_project_root)" "$num"
}

adapter_worktree_env() {
    # single_project has no per-worktree environment to overlay.
    :
}

adapter_scope_for_pr() {
    local path="${1:-}"
    if [ -z "$path" ]; then
        echo "ERROR: scope_for_pr requires a path argument" >&2
        return 1
    fi
    # `git -C` needs a directory; a file path resolves from its parent.
    local dir="$path"
    [ -d "$dir" ] || dir="$(dirname "$dir")"
    local url
    if ! url="$(git -C "$dir" remote get-url origin 2>/dev/null)"; then
        echo "ERROR: no git repository with an 'origin' remote at or above: $path" >&2
        return 1
    fi
    url="${url%.git}"
    url="${url%/}"
    # URL form must be tried first: an SCP-form pattern would greedily match
    # ssh://git@github.com:22/owner/repo and capture "22/owner/repo".
    if [[ "$url" =~ ^[A-Za-z][A-Za-z0-9+.-]*://[^/]+/(.+)$ ]]; then
        # URL form: https://github.com/owner/repo, ssh://git@github.com:22/owner/repo
        echo "${BASH_REMATCH[1]}"
    elif [[ "$url" =~ ^[^@/]+@[^:/]+:(.+)$ ]]; then
        # SCP form: git@github.com:owner/repo (no slashes before the colon)
        echo "${BASH_REMATCH[1]}"
    else
        echo "ERROR: cannot parse owner/repo from origin URL: $url" >&2
        return 1
    fi
}
