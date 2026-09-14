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
# Fresh hosting dir (#237, step 6 phase 2): `setup` bootstraps the manifest
# when configs/manifest is absent, porting ros2's setup_layers.sh flow
# non-interactively. The bootstrap URL (a remote bootstrap.yaml) resolves
# from BOOTSTRAP_URL in the environment, MANIFEST_BOOTSTRAP_URL in the
# per-project config, or configs/project_bootstrap.url in the hosting dir.
# bootstrap.yaml fields: git_url, branch (required); layer (Pattern B —
# clone into layers/main/<layer>_ws/src/<repo>; absent = Pattern A —
# configs/manifest_repo/<repo>); config_path (default "config").
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

# Read one scalar from the per-project config (sourced in a subshell, stdout
# suppressed so eval'd `env` output stays clean). A failing config is a
# hard error — same semantics as _rc_distro / _rc_ros_root.
_rc_config_var() {
    local var="$1" config value
    config="$(_rc_config_file)"
    [ -f "$config" ] || { echo ""; return 0; }
    if ! value="$(
        eval "$var="
        # shellcheck source=/dev/null
        source "$config" >/dev/null || exit 1
        eval "echo \"\${$var:-}\""
    )"; then
        echo "ERROR: failed to source $config" >&2
        return 1
    fi
    echo "$value"
}

# Resolve the bootstrap URL (remote bootstrap.yaml). Priority: BOOTSTRAP_URL
# env, MANIFEST_BOOTSTRAP_URL in the per-project config, then the hosting
# dir's configs/project_bootstrap.url. Never prompts — the adapter runs
# under make and in CI.
_rc_bootstrap_url() {
    local url="" url_file
    url="$(printf '%s' "${BOOTSTRAP_URL:-}" | tr -d '[:space:]')"
    if [ -z "$url" ]; then
        url="$(_rc_config_var MANIFEST_BOOTSTRAP_URL)" || return 1
        url="$(printf '%s' "$url" | tr -d '[:space:]')"
    fi
    if [ -z "$url" ]; then
        url_file="$(_rc_root)/configs/project_bootstrap.url"
        [ -f "$url_file" ] && url="$(tr -d '[:space:]' < "$url_file")"
    fi
    echo "$url"
}

# One scalar from a bootstrap.yaml (flat "key: value" lines; inline comments
# stripped). Same parsing as _rc_distro and ros2's setup_layers.sh.
_rc_yaml_scalar() {
    grep "^${2}:" "$1" 2>/dev/null | head -1 | cut -d '#' -f 1 | awk '{print $2}'
}

# Bootstrap the manifest into a fresh hosting dir: fetch bootstrap.yaml,
# clone the manifest repo at its branch, symlink configs/manifest to the
# repo's config dir. No-op when configs/manifest already resolves; refuses
# to replace a non-symlink at that path.
_rc_bootstrap_manifest() {
    local root mdir url tmp git_url branch layer config_path repo_name
    local clone_dir config_dir target
    root="$(_rc_root)"
    mdir="$root/configs/manifest"
    if [ -L "$mdir" ] && [ -e "$mdir" ]; then
        return 0
    fi
    if [ -e "$mdir" ] && [ ! -L "$mdir" ]; then
        # A real directory is a hand-placed manifest — leave it alone.
        return 0
    fi
    url="$(_rc_bootstrap_url)" || return 1
    if [ -z "$url" ]; then
        echo "ERROR: no manifest at $mdir and no bootstrap URL to fetch one." >&2
        echo "Provide the URL of the project's bootstrap.yaml via one of:" >&2
        echo "  BOOTSTRAP_URL=<url> (environment)" >&2
        echo "  MANIFEST_BOOTSTRAP_URL=<url> in $(_rc_config_file)" >&2
        echo "  $root/configs/project_bootstrap.url" >&2
        return 1
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "ERROR: 'curl' not found — required to fetch $url" >&2
        return 1
    fi
    echo "Fetching bootstrap config from $url..."
    tmp="$(mktemp)"
    if ! curl -sSLf "$url" -o "$tmp"; then
        rm -f "$tmp"
        echo "ERROR: failed to download bootstrap config from $url" >&2
        return 1
    fi
    git_url="$(_rc_yaml_scalar "$tmp" git_url)"
    branch="$(_rc_yaml_scalar "$tmp" branch)"
    layer="$(_rc_yaml_scalar "$tmp" layer)"
    config_path="$(_rc_yaml_scalar "$tmp" config_path)"
    rm -f "$tmp"
    if [ -z "$git_url" ] || [ -z "$branch" ]; then
        echo "ERROR: bootstrap config at $url must define 'git_url' and 'branch'." >&2
        return 1
    fi
    config_path="${config_path:-config}"
    if [ -n "$layer" ] && ! [[ "$layer" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "ERROR: invalid 'layer' value in bootstrap config: $layer" >&2
        echo "Layer names must contain only letters, numbers, hyphens, and underscores." >&2
        return 1
    fi
    if [[ "$config_path" == /* || "$config_path" == *..* ]]; then
        echo "ERROR: invalid 'config_path' value in bootstrap config: $config_path" >&2
        echo "config_path must be a relative path without '..' components." >&2
        return 1
    fi
    repo_name="$(basename "$git_url" .git)"
    if ! [[ "$repo_name" =~ ^[A-Za-z0-9_.-]+$ ]] || [[ "$repo_name" == .* ]]; then
        echo "ERROR: cannot derive a safe repository name from git_url: $git_url" >&2
        return 1
    fi
    if [ -n "$layer" ]; then
        clone_dir="$root/layers/main/${layer}_ws/src/$repo_name"
        echo "Cloning manifest repo (Pattern B: layer=$layer)..."
    else
        clone_dir="$root/configs/manifest_repo/$repo_name"
        echo "Cloning manifest repo (Pattern A: standalone config)..."
    fi
    echo "  From: $git_url (branch: $branch)"
    echo "  To:   $clone_dir"
    mkdir -p "$(dirname "$clone_dir")"
    if [ -e "$clone_dir" ]; then
        echo "  (already present — reusing existing checkout)"
    elif ! git clone -b "$branch" "$git_url" "$clone_dir"; then
        echo "ERROR: failed to clone $git_url (branch: $branch)" >&2
        return 1
    fi
    config_dir="$clone_dir/$config_path"
    if [ ! -d "$config_dir" ]; then
        echo "ERROR: config directory not found at $config_dir" >&2
        echo "Check the 'config_path' value in bootstrap.yaml (current: $config_path)." >&2
        return 1
    fi
    mkdir -p "$root/configs"
    # Relative link so the hosting dir can be moved as a unit.
    target="$(realpath --relative-to="$root/configs" "$config_dir")"
    ln -sfn "$target" "$mdir"
    echo "Created symlink: $mdir -> $target"
}

# Source a ROS setup script with nounset relaxed — ROS setup files
# reference unbound variables — then restore it so the adapter's own logic
# keeps full set -euo pipefail protection. A failing setup script is a
# loud error at the call site, never a silent continue.
_rc_source_setup() {
    local setup_file="$1" rc=0
    set +u
    # shellcheck disable=SC1090
    source "$setup_file" || rc=$?
    set -u
    if [ "$rc" -ne 0 ]; then
        echo "ERROR: failed to source $setup_file" >&2
        return "$rc"
    fi
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
    # Bootstrap the manifest into a fresh hosting dir when needed, then
    # import each layer's repos with vcs. Optional layers
    # (optional_layers.txt) may fail — e.g. private repos; everything else
    # aborts loudly.
    _rc_bootstrap_manifest || return 1
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
    _rc_require_manifest || return 1
    local underlay layer layer_dir rc
    underlay="$(_rc_underlay)" || return 1
    unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
    _rc_source_setup "$underlay" || return 1
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
            _rc_source_setup "$layer_dir/install/local_setup.bash" || return 1
        fi
    done < <(_rc_layers)
    echo "All layers built successfully."
}

adapter_test() {
    # Test every layer that has sources; unlike build, a failing layer does
    # not stop the run — all failures are reported at the end.
    _rc_require_manifest || return 1
    local underlay layer layer_dir rc failed=""
    underlay="$(_rc_underlay)" || return 1
    unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
    _rc_source_setup "$underlay" || return 1
    while IFS= read -r layer; do
        layer_dir="$(_rc_layer_dir "$layer")"
        if [ -f "$layer_dir/install/local_setup.bash" ]; then
            _rc_source_setup "$layer_dir/install/local_setup.bash" || return 1
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
