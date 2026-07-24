# shellcheck shell=bash
# .agent/project_types/single_project/adapter.sh
# single_project adapter — one repo cloned or symlinked at $WORKSPACE_ROOT/project.
#
# Pure facade over the pre-adapter workspace scripts (ADR-0011, #210):
# behavior is intentionally identical to the old build.sh/test.sh/
# setup_project.sh/sync_project.py flow.
#
# Sourced by .agent/scripts/adapter with WORKSPACE_ROOT and ADAPTER_TYPE_DIR
# set as shell variables (not exported). Not executable on its own; must be
# silent at source time.

# Resolve the command-config file for the active project: the per-project
# override (.agent/projects.d/<name>.sh, set by the dispatcher as
# ACTIVE_PROJECT_CONFIG) when it exists, else the shared
# .agent/project_config.sh.
_single_project_config_file() {
    if [ -n "${ACTIVE_PROJECT_CONFIG:-}" ] && [ -f "$ACTIVE_PROJECT_CONFIG" ]; then
        echo "$ACTIVE_PROJECT_CONFIG"
    else
        echo "$WORKSPACE_ROOT/.agent/project_config.sh"
    fi
}

# Load the command config and require the named command variable to be set
# (e.g. BUILD_CMD). Prints the same guidance the old scripts printed.
#
# Callers must NOT guard this with `||` — verbs run under the dispatcher's
# set -e, and an unguarded call is what makes a failure inside the sourced
# config abort the verb (matching the old top-level-source behavior).
# A `|| return 1` guard would disable errexit for the whole call, silently
# swallowing config failures.
_single_project_load_cmd() {
    local var_name="$1"
    local config
    config="$(_single_project_config_file)"

    if [ ! -f "$config" ]; then
        echo "❌ No project_config.sh found."
        echo ""
        echo "Create $config with your project commands:"
        echo ""
        echo "  cat > $config << 'EOF'"
        echo "  # Per-developer project configuration (gitignored)"
        echo "  PROJECT_TYPE=\"single_project\""
        echo "  BUILD_CMD=\"make\"          # or: cmake --build build, cargo build, etc."
        echo "  TEST_CMD=\"make test\"      # or: cargo test, pytest, etc."
        echo "  INSTALL_CMD=\"\"            # optional deploy/install command"
        echo "  EOF"
        echo ""
        if [ -n "${ACTIVE_PROJECT_NAME:-}" ]; then
            echo "  (active project: $ACTIVE_PROJECT_NAME — per-project override: ${ACTIVE_PROJECT_CONFIG:-unset})"
            echo ""
        fi
        return 1
    fi

    # shellcheck source=/dev/null
    source "$config"

    if [ -z "${!var_name:-}" ]; then
        echo "❌ $var_name is not set in $config"
        echo ""
        echo "Add to $config:"
        echo "  $var_name=\"...\"   # your project's command"
        echo ""
        return 1
    fi
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
    exec python3 "$WORKSPACE_ROOT/.agent/scripts/validate_workspace.py" "$@"
}

adapter_build() {
    _single_project_load_cmd BUILD_CMD
    echo "Running: $BUILD_CMD $*"
    echo ""
    cd "$(adapter_project_root)" || return 1
    # shellcheck disable=SC2086
    exec $BUILD_CMD "$@"
}

adapter_test() {
    _single_project_load_cmd TEST_CMD
    echo "Running: $TEST_CMD $*"
    echo ""
    cd "$(adapter_project_root)" || return 1
    # shellcheck disable=SC2086
    exec $TEST_CMD "$@"
}

adapter_install() {
    local config
    config="$(_single_project_config_file)"
    if [ -f "$config" ]; then
        # shellcheck source=/dev/null
        source "$config"
    fi
    if [ -z "${INSTALL_CMD:-}" ]; then
        echo "INSTALL_CMD not set — nothing to install (this is fine for most projects)."
        return 0
    fi
    echo "Running: $INSTALL_CMD $*"
    echo ""
    cd "$(adapter_project_root)" || return 1
    # shellcheck disable=SC2086
    exec $INSTALL_CMD "$@"
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

adapter_scope_for_pr() {
    local path="${1:-}"
    if [ -z "$path" ]; then
        echo "ERROR: scope_for_pr requires a path argument" >&2
        return 1
    fi
    local url
    if ! url="$(git -C "$path" remote get-url origin 2>/dev/null)"; then
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
