# shellcheck shell=bash
# .agent/project_types/ros2_colcon/adapter.sh
# ros2_colcon adapter — layered colcon workspaces (#172 step 6, issue #235).
#
# Hosts a project shaped like rolker/ros2_agent_workspace: ordered colcon
# layers under layers/main/<layer>_ws/, driven by an in-tree manifest at
# configs/manifest/ (layers.txt, optional_layers.txt, repos/<layer>.repos,
# bootstrap.yaml). Manifest-repo formalization is #172 step 4; this adapter
# reads the manifest from the hosting dir only.
#
# Distro handling (new capability — the ros2 scripts hardcoded jazzy):
#   1. `distro:` field in configs/manifest/bootstrap.yaml
#   2. ROS_DISTRO in the per-project config (.agent/projects.d/<name>.sh,
#      falling back to .agent/project_config.sh)
#   3. otherwise: error. No silent default.
# ROS_ROOT_DIR (per-project config; default /opt/ros) locates the distro
# underlay — override it for tests or non-standard installs.
#
# Environment discipline ported from ros2 build.sh (their ADR-0016): scrub
# inherited COLCON/AMENT/CMAKE prefix paths, source ONLY the distro base
# before the first layer, then source each layer's install/local_setup.bash
# progressively after it builds. Sourcing the full chain up front bakes
# higher layers into lower layers' parent chains and inverts overlay
# precedence.
#
# Sourced by .agent/scripts/adapter with WORKSPACE_ROOT, ADAPTER_TYPE_DIR,
# and ACTIVE_PROJECT_* set as shell variables. Must be silent at source
# time; no top-level exit.

# --- Config / manifest helpers -------------------------------------------

# Per-project command config: the projects.d override when it exists, else
# the shared project_config.sh (same resolution as single_project).
_rc_config_file() {
    if [ -n "${ACTIVE_PROJECT_CONFIG:-}" ] && [ -f "$ACTIVE_PROJECT_CONFIG" ]; then
        echo "$ACTIVE_PROJECT_CONFIG"
    else
        echo "$WORKSPACE_ROOT/.agent/project_config.sh"
    fi
}

_rc_root() {
    echo "${ACTIVE_PROJECT_ROOT:-$WORKSPACE_ROOT/project}"
}

_rc_manifest_dir() {
    echo "$(_rc_root)/configs/manifest"
}

# Require the manifest dir (dir or resolving symlink) with at least one
# layer defined. Errors with guidance — an empty layers.txt must not let
# the layer loops run zero times and report success.
_rc_require_manifest() {
    local mdir
    mdir="$(_rc_manifest_dir)"
    if [ ! -d "$mdir" ] || [ ! -f "$mdir/layers.txt" ]; then
        echo "ERROR: no manifest at $mdir (expected layers.txt)" >&2
        echo "The hosting dir must contain configs/manifest/ with layers.txt," >&2
        echo "repos/<layer>.repos, and optionally bootstrap.yaml — the" >&2
        echo "ros2_agent_workspace manifest shape. See issue #235." >&2
        return 1
    fi
    if [ -z "$(_rc_layers)" ]; then
        echo "ERROR: $mdir/layers.txt defines no layers (empty or comments only)" >&2
        return 1
    fi
    # Layer names become filesystem paths (layers/main/<layer>_ws) — enforce
    # the same rule as ros2's setup_layers.sh so an entry like '../x' can
    # never escape the hosting dir. The charset excludes '.', so no '..'.
    local layer
    while IFS= read -r layer; do
        if ! [[ "$layer" =~ ^[A-Za-z0-9_-]+$ ]]; then
            echo "ERROR: invalid layer name '$layer' in $mdir/layers.txt" >&2
            echo "Layer names must contain only letters, numbers, hyphens, and underscores." >&2
            return 1
        fi
    done < <(_rc_layers)
}

# Ordered layer names from layers.txt (comments/blanks stripped, whitespace
# trimmed — a stray trailing space must not produce a "<layer> _ws" path).
_rc_layers() {
    local mdir
    mdir="$(_rc_manifest_dir)"
    grep -v '^[[:space:]]*#' "$mdir/layers.txt" 2>/dev/null \
        | grep -v '^[[:space:]]*$' \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# True if the layer is listed in optional_layers.txt.
_rc_is_optional_layer() {
    local layer="$1" mdir
    mdir="$(_rc_manifest_dir)"
    [ -f "$mdir/optional_layers.txt" ] || return 1
    grep -v '^[[:space:]]*#' "$mdir/optional_layers.txt" 2>/dev/null \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
        | grep -qx "$layer"
}

_rc_layer_dir() {
    echo "$(_rc_root)/layers/main/${1}_ws"
}

# Resolve the ROS distro (manifest first, then config). Errors loudly.
_rc_distro() {
    local mdir distro="" config
    mdir="$(_rc_manifest_dir)"
    if [ -f "$mdir/bootstrap.yaml" ]; then
        distro="$(grep '^distro:' "$mdir/bootstrap.yaml" 2>/dev/null \
            | head -1 | cut -d '#' -f 1 | awk '{print $2}')"
    fi
    if [ -z "$distro" ]; then
        config="$(_rc_config_file)"
        if [ -f "$config" ]; then
            # Suppress the config's stdout only (env output must stay
            # eval-safe); a failing config is a hard error, never an empty
            # value — matching single_project's config-failure semantics.
            if ! distro="$(
                ROS_DISTRO=
                # shellcheck source=/dev/null
                source "$config" >/dev/null || exit 1
                echo "${ROS_DISTRO:-}"
            )"; then
                echo "ERROR: failed to source $config" >&2
                return 1
            fi
        fi
    fi
    if [ -z "$distro" ]; then
        echo "ERROR: cannot resolve the ROS distro for this project." >&2
        echo "Declare it in one of:" >&2
        echo "  $mdir/bootstrap.yaml            distro: <name>" >&2
        echo "  $(_rc_config_file)   ROS_DISTRO=<name>" >&2
        return 1
    fi
    if ! [[ "$distro" =~ ^[a-z0-9_]+$ ]]; then
        echo "ERROR: invalid ROS distro name '$distro'" >&2
        return 1
    fi
    echo "$distro"
}

# Root under which distro underlays live (default /opt/ros). Overridable via
# ROS_ROOT_DIR in the per-project config for tests / non-standard installs.
_rc_ros_root() {
    local config root=""
    config="$(_rc_config_file)"
    if [ -f "$config" ]; then
        # A failing config must not silently discard the user's override
        # and fall back to /opt/ros (wrong ROS install, no warning).
        if ! root="$(
            ROS_ROOT_DIR=
            # shellcheck source=/dev/null
            source "$config" >/dev/null || exit 1
            echo "${ROS_ROOT_DIR:-}"
        )"; then
            echo "ERROR: failed to source $config" >&2
            return 1
        fi
    fi
    echo "${root:-/opt/ros}"
}

# Path to the distro's setup.bash; errors if missing.
_rc_underlay() {
    local distro ros_root underlay
    distro="$(_rc_distro)" || return 1
    ros_root="$(_rc_ros_root)" || return 1
    underlay="$ros_root/$distro/setup.bash"
    if [ ! -f "$underlay" ]; then
        echo "ERROR: ROS underlay not found: $underlay" >&2
        echo "Install ROS 2 '$distro' (or set ROS_ROOT_DIR in $(_rc_config_file))." >&2
        return 1
    fi
    echo "$underlay"
}

# Parse a vcstool .repos file: emit "<name>\t<version>" per repository.
# Format: two-space-indented "name:" entries under "repositories:", with
# four-space-indented keys (type/url/version).
_rc_repos_entries() {
    local repos_file="$1"
    [ -f "$repos_file" ] || return 0
    awk '
        /^[[:space:]]*#/ { next }
        /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ {
            name = $1; sub(/:$/, "", name)
            next
        }
        /^    version:/ && name != "" {
            version = $2; sub(/#.*/, "", version)
            printf "%s\t%s\n", name, version
            name = ""
        }
    ' "$repos_file"
}

# --- Contract verbs -------------------------------------------------------

adapter_project_root() {
    _rc_root
}

adapter_env() {
    # Emit eval-able statements: prefix-path scrub, distro underlay, then
    # each built layer's local_setup.bash in layers.txt order (local_setup
    # adds only that layer — the chain provides the rest; see header note).
    _rc_require_manifest || return 1
    local underlay layer layer_dir
    underlay="$(_rc_underlay)" || return 1
    echo "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX"
    printf 'source %q\n' "$underlay"
    while IFS= read -r layer; do
        layer_dir="$(_rc_layer_dir "$layer")"
        if [ -f "$layer_dir/install/local_setup.bash" ]; then
            printf 'source %q\n' "$layer_dir/install/local_setup.bash"
        fi
    done < <(_rc_layers)
}

adapter_setup() {
    # In-tree manifest: import each layer's repos with vcs. Optional layers
    # (optional_layers.txt) may fail — e.g. private repos; everything else
    # aborts loudly. Manifest bootstrap-from-URL is phase 2 (#235 scope).
    _rc_require_manifest || return 1
    if ! command -v vcs >/dev/null 2>&1; then
        echo "ERROR: 'vcs' (vcstool) not found — required to import layer repos." >&2
        return 1
    fi
    local mdir layer layer_dir repos_file
    mdir="$(_rc_manifest_dir)"
    while IFS= read -r layer; do
        repos_file="$mdir/repos/${layer}.repos"
        layer_dir="$(_rc_layer_dir "$layer")"
        if [ ! -f "$repos_file" ]; then
            if _rc_is_optional_layer "$layer"; then
                echo "Skipping optional layer '$layer' (no ${layer}.repos)"
                continue
            fi
            echo "ERROR: missing repos file for layer '$layer': $repos_file" >&2
            return 1
        fi
        echo "Setting up layer: $layer"
        mkdir -p "$layer_dir/src"
        if ! vcs import --skip-existing "$layer_dir/src" < "$repos_file"; then
            if _rc_is_optional_layer "$layer"; then
                echo "WARNING: import failed for optional layer '$layer' (private repo?) — continuing"
                continue
            fi
            echo "ERROR: vcs import failed for layer '$layer'" >&2
            return 1
        fi
    done < <(_rc_layers)
    echo "Setup complete. Next: .agent/scripts/adapter build"
}

adapter_build() {
    # Build layers in layers.txt order, sourcing each successful layer's
    # local_setup.bash so later layers overlay it. Stop on first failure.
    # ROS setup scripts reference unbound variables — relax set -u here.
    set +u
    _rc_require_manifest || return 1
    local underlay layer layer_dir rc
    underlay="$(_rc_underlay)" || return 1
    unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
    # shellcheck source=/dev/null
    source "$underlay"
    while IFS= read -r layer; do
        layer_dir="$(_rc_layer_dir "$layer")"
        if [ ! -d "$layer_dir/src" ]; then
            echo "Skipping layer $layer (no src directory)"
            continue
        fi
        echo "----------------------------------------"
        echo "Building layer: $layer"
        echo "----------------------------------------"
        rc=0
        (cd "$layer_dir" \
            && colcon build --symlink-install \
                --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON "$@") || rc=$?
        if [ "$rc" -ne 0 ]; then
            echo "ERROR: build failed for layer: $layer" >&2
            return "$rc"
        fi
        if [ -f "$layer_dir/install/local_setup.bash" ]; then
            # shellcheck source=/dev/null
            source "$layer_dir/install/local_setup.bash"
        fi
    done < <(_rc_layers)
    echo "All layers built successfully."
}

adapter_test() {
    # Test every layer that has sources; unlike build, a failing layer does
    # not stop the run — all failures are reported at the end.
    set +u
    _rc_require_manifest || return 1
    local underlay layer layer_dir rc failed=""
    underlay="$(_rc_underlay)" || return 1
    unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
    # shellcheck source=/dev/null
    source "$underlay"
    while IFS= read -r layer; do
        layer_dir="$(_rc_layer_dir "$layer")"
        if [ -f "$layer_dir/install/local_setup.bash" ]; then
            # shellcheck source=/dev/null
            source "$layer_dir/install/local_setup.bash"
        fi
        if [ ! -d "$layer_dir/src" ]; then
            echo "Skipping layer $layer (no src directory)"
            continue
        fi
        echo "----------------------------------------"
        echo "Testing layer: $layer"
        echo "----------------------------------------"
        rc=0
        (cd "$layer_dir" \
            && colcon test --event-handlers console_direct+ \
                --return-code-on-test-failure "$@") || rc=$?
        if [ "$rc" -ne 0 ]; then
            echo "ERROR: tests failed for layer: $layer" >&2
            failed="$failed $layer"
        fi
    done < <(_rc_layers)
    if [ -n "$failed" ]; then
        echo "Tests failed in layers:$failed" >&2
        return 1
    fi
    echo "All layer tests passed."
}

adapter_sync() {
    # Per package repo: pull --rebase when clean and on its .repos-pinned
    # branch; fetch otherwise. Never touches dirty or detached checkouts.
    _rc_require_manifest || return 1
    local mdir layer layer_dir repos_file entry name version repo_dir branch
    mdir="$(_rc_manifest_dir)"
    while IFS= read -r layer; do
        layer_dir="$(_rc_layer_dir "$layer")"
        repos_file="$mdir/repos/${layer}.repos"
        [ -d "$layer_dir/src" ] || continue
        while IFS= read -r entry; do
            [ -z "$entry" ] && continue
            name="${entry%%$'\t'*}"
            version="${entry#*$'\t'}"
            repo_dir="$layer_dir/src/$name"
            git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1 || continue
            if [ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]; then
                echo "  $layer/$name: skipped (uncommitted changes)"
                continue
            fi
            branch="$(git -C "$repo_dir" branch --show-current 2>/dev/null)"
            if [ "$branch" = "$version" ]; then
                echo "  $layer/$name: on '$branch' — pulling..."
                if ! git -C "$repo_dir" pull --rebase 2>/dev/null; then
                    # Abort a wedged rebase so the checkout stays usable.
                    git -C "$repo_dir" rebase --abort >/dev/null 2>&1 || true
                    echo "  $layer/$name: pull failed (continuing)" >&2
                fi
            else
                echo "  $layer/$name: on '${branch:-detached}' (pinned: $version) — fetching..."
                git -C "$repo_dir" fetch 2>/dev/null \
                    || echo "  $layer/$name: fetch failed (continuing)" >&2
            fi
        done < <(_rc_repos_entries "$repos_file")
    done < <(_rc_layers)
    echo "Sync complete."
}

adapter_validate() {
    # Checkout shape vs manifest: every non-optional layer has a repos file
    # and every repo pinned in it is checked out. Distro must resolve.
    local mdir layer layer_dir repos_file entry name issues=0
    if ! _rc_require_manifest; then
        return 1
    fi
    mdir="$(_rc_manifest_dir)"
    if ! _rc_distro >/dev/null; then
        issues=$((issues + 1))
    fi
    while IFS= read -r layer; do
        repos_file="$mdir/repos/${layer}.repos"
        layer_dir="$(_rc_layer_dir "$layer")"
        if [ ! -f "$repos_file" ]; then
            if _rc_is_optional_layer "$layer"; then
                continue
            fi
            echo "❌ layer '$layer': missing $repos_file" >&2
            issues=$((issues + 1))
            continue
        fi
        if [ ! -d "$layer_dir/src" ]; then
            if _rc_is_optional_layer "$layer"; then
                continue
            fi
            echo "❌ layer '$layer': not set up (no $layer_dir/src — run: adapter setup)" >&2
            issues=$((issues + 1))
            continue
        fi
        while IFS= read -r entry; do
            [ -z "$entry" ] && continue
            name="${entry%%$'\t'*}"
            if [ ! -d "$layer_dir/src/$name" ]; then
                echo "❌ layer '$layer': repo '$name' pinned in ${layer}.repos but not checked out" >&2
                issues=$((issues + 1))
            fi
        done < <(_rc_repos_entries "$repos_file")
    done < <(_rc_layers)
    if [ "$issues" -gt 0 ]; then
        echo "Validation failed: $issues issue(s)." >&2
        return 1
    fi
    echo "✅ ros2_colcon checkout matches the manifest."
}

adapter_install() {
    # colcon installs during build; a separate deploy step is optional and
    # config-driven, matching single_project's INSTALL_CMD semantics.
    local config
    config="$(_rc_config_file)"
    if [ -f "$config" ]; then
        # shellcheck source=/dev/null
        source "$config"
    fi
    if [ -z "${INSTALL_CMD:-}" ]; then
        echo "INSTALL_CMD not set — nothing to install (colcon installs during build)."
        return 0
    fi
    echo "Running: $INSTALL_CMD $*"
    echo ""
    cd "$(_rc_root)" || return 1
    # shellcheck disable=SC2086
    exec $INSTALL_CMD "$@"
}

adapter_repos() {
    # Every package repo across every layer, as name:path lines.
    _rc_require_manifest || return 1
    local layer layer_dir pkg_dir found=0
    while IFS= read -r layer; do
        layer_dir="$(_rc_layer_dir "$layer")"
        [ -d "$layer_dir/src" ] || continue
        for pkg_dir in "$layer_dir/src"/*; do
            [ -d "$pkg_dir" ] || continue
            git -C "$pkg_dir" rev-parse --git-dir >/dev/null 2>&1 || continue
            echo "$(basename "$pkg_dir"):$pkg_dir"
            found=1
        done
    done < <(_rc_layers)
    if [ "$found" -eq 0 ]; then
        echo "ERROR: no package repos found (run: adapter setup)" >&2
        return 1
    fi
}

adapter_scope_for_pr() {
    # Walk up from a path to the owning package repo's origin owner/repo.
    # Same URL parsing as single_project (proven by its adapter tests).
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
        echo "${BASH_REMATCH[1]}"
    elif [[ "$url" =~ ^[^@/]+@[^:/]+:(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "ERROR: cannot parse owner/repo from origin URL: $url" >&2
        return 1
    fi
}
