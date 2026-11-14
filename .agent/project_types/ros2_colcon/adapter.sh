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
# Two routes to that directory (issue #436). The bootstrap route (below) is
# today's bootstrap.yaml flow. The manifest route is taken when the
# project's settings file sets `source` (with source_ref and source_path for
# a git URL), and needs role= and distro= on the registry line: the
# manifest, in the new format, is resolved by the workspace-installed
# ros-manifest resolver (<main checkout>/.venv/bin/ros-manifest, from `make
# install-ros-manifest`; called by CLI only) into configs/manifest-resolved
# (see "Manifest route" below for the fetch, staleness and network rules).
# Package worktrees' env.sh is written once at create time: after a sync
# that changes the layers, sync says to recreate them.
#
# Fresh hosting dir (#237, step 6 phase 2): `setup` bootstraps the manifest
# when configs/manifest is absent, porting ros2's setup_layers.sh flow
# non-interactively. The bootstrap URL (a remote bootstrap.yaml) resolves
# from BOOTSTRAP_URL in the environment, MANIFEST_BOOTSTRAP_URL in the
# per-project config, or configs/project_bootstrap.url in the hosting dir;
# a registered project's bootstrap_url setting (.agent/projects.d/<name>,
# issue #332) comes before MANIFEST_BOOTSTRAP_URL (see _rc_bootstrap_url).
# bootstrap.yaml fields: git_url, branch (required); layer (Pattern B —
# clone into layers/main/<layer>_ws/src/<repo>; absent = Pattern A —
# configs/manifest_repo/<repo>); config_path (default "config").
#
# Changed from main (issue #332): an INSTALL_CMD inherited from the
# caller's environment is no longer honoured; adapter_install clears it
# before sourcing the legacy or shared config, so only a config file (or
# install= in the settings file) sets it. An install= command runs
# without sourcing the legacy or shared config, so nothing they export (an
# SDK path, PATH) reaches it: environment setup belongs in the script the
# key points at.
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

# The manifest directory every verb reads: configs/manifest on the
# bootstrap route, the link configs/manifest-resolved to the generated
# directory on the manifest route (issue #436; a configs/manifest left
# from an earlier bootstrap is then ignored). On the manifest route, once
# _rc_pin_manifest_dir has run (_rc_require_manifest runs it), it is the
# generated directory the link pointed at then, so a run reads one result
# throughout even when another run swaps the link meanwhile.
_rc_manifest_dir() {
    if [ -n "${ACTIVE_PROJECT_SOURCE:-}" ]; then
        if [ -n "${_RC_MDIR_PIN:-}" ]; then
            echo "$_RC_MDIR_PIN"
        else
            echo "$(_rc_root)/configs/manifest-resolved"
        fi
    else
        echo "$(_rc_root)/configs/manifest"
    fi
}

# Pin this run to the generated directory configs/manifest-resolved points
# at (manifest route; sets _RC_MDIR_PIN). With flock, a shared lock on that
# directory, held on fd 8 until the run ends, keeps it from being removed
# while this run reads it: a run that replaces the link removes the
# previous directory only when it can take an exclusive lock on it at
# once, and otherwise leaves it to the sweep. A directory removed between
# reading the link and taking the lock is noticed (no layers.txt) and the
# link read again. A link the adapter did not write (to another name) is
# read through, unpinned. The programs the adapter starts (git, vcs,
# colcon, the resolver) run through _rc_nofd, so none inherits fd 8.
_rc_pin_manifest_dir() {
    local configs link target i
    [ -n "${ACTIVE_PROJECT_SOURCE:-}" ] || return 0
    configs="$(_rc_root)/configs"
    link="$configs/manifest-resolved"
    for i in 1 2 3 4 5; do
        _rc_unpin_manifest_dir
        [ -L "$link" ] || return 0
        target="$(readlink -- "$link" 2>/dev/null)" || return 0
        [[ "$target" =~ ^manifest-resolved\.gen-[A-Za-z0-9]{6}$ ]] || return 0
        if command -v flock >/dev/null 2>&1; then
            { exec 8<"$configs/$target"; } 2>/dev/null || continue
            if ! flock -s 8 9>&-; then
                exec 8<&-
                echo "WARNING: cannot take a shared lock on $configs/$target (flock on a directory failed here); this run reads it unguarded, and a sync meanwhile may replace it" >&2
                _RC_MDIR_PIN="$configs/$target"
                return 0
            fi
            _RC_MDIR_FD=1
        fi
        if [ -f "$configs/$target/layers.txt" ]; then
            _RC_MDIR_PIN="$configs/$target"
            return 0
        fi
    done
    _rc_unpin_manifest_dir
}

_rc_unpin_manifest_dir() {
    if [ "${_RC_MDIR_FD:-0}" -eq 1 ]; then
        exec 8<&-
        _RC_MDIR_FD=0
    fi
    _RC_MDIR_PIN=""
}

# Run a program without the reader pin (fd 8) or the source lock (fd 9),
# so a child that outlives the adapter (git's auto gc, a ROS daemon a test
# starts) holds neither, and without the variables that tell git which
# repository to use (_rc_git_local_vars): git sets GIT_DIR, GIT_INDEX_FILE
# and the like for every hook, and a `git -C <dir>` would still act on the
# repository they name.
_rc_nofd() {
    _rc_git_local_vars
    ( unset $_RC_GIT_LOCAL_VARS; "$@" ) 8<&- 9>&-
}

# The repository-locating names `git rev-parse --local-env-vars` prints,
# with git's list as of 2.53 as a floor, less GIT_CONFIG_PARAMETERS and
# GIT_CONFIG_COUNT, which carry the user's own `-c` and environment
# configuration (credentials, url.*.insteadOf) and are kept. Computed once
# per run into _RC_GIT_LOCAL_VARS.
_rc_git_local_vars() {
    [ -n "${_RC_GIT_LOCAL_VARS:-}" ] && return 0
    local floor="GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG GIT_OBJECT_DIRECTORY GIT_DIR GIT_WORK_TREE GIT_IMPLICIT_WORK_TREE GIT_GRAFT_FILE GIT_INDEX_FILE GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE GIT_PREFIX GIT_SHALLOW_FILE GIT_COMMON_DIR" more
    # shellcheck disable=SC2086
    more="$( unset $floor; git rev-parse --local-env-vars 2>/dev/null 8<&- 9>&- )" || more=""
    _RC_GIT_LOCAL_VARS="$(printf '%s\n' $floor $more | grep -vx -e GIT_CONFIG_PARAMETERS -e GIT_CONFIG_COUNT | LC_ALL=C sort -u | tr '\n' ' ')"
}

# Remove a generated directory no run is reading (with flock only; the
# caller never removes one without it): only when an exclusive lock on it
# is free at once. A reader's shared lock keeps it for a later sweep. When
# a directory cannot be locked at all, nothing is removed and that is said
# once per run, so leftovers never pile up unsaid.
_rc_remove_generated() {
    local dir="$1" rc=0
    [ -d "$dir" ] || return 0
    flock -x -n -E 75 "$dir" rm -rf -- "$dir" 8<&- 9>&- 2>/dev/null || rc=$?
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 75 ] && [ "${_RC_WARNED_DIRLOCK:-0}" -eq 0 ]; then
        _RC_WARNED_DIRLOCK=1
        echo "WARNING: cannot lock or remove $dir (exit $rc); previous results under $(dirname "$dir")/manifest-resolved.gen-* are left: remove those the link manifest-resolved does not point at by hand" >&2
    fi
    return 0
}

# Require the manifest dir (dir or resolving symlink) with at least one
# layer defined. Errors with guidance — an empty layers.txt must not let
# the layer loops run zero times and report success.
_rc_require_manifest() {
    local mdir
    _rc_pin_manifest_dir
    mdir="$(_rc_manifest_dir)"
    if [ -n "${ACTIVE_PROJECT_SOURCE:-}" ] && { [ ! -d "$mdir" ] || [ ! -f "$mdir/layers.txt" ]; }; then
        echo "ERROR: no resolved manifest at $mdir (project '${ACTIVE_PROJECT_NAME:-?}' sets source, so the manifest is resolved from it)" >&2
        echo "Run: .agent/scripts/adapter --project ${ACTIVE_PROJECT_NAME:-<name>} setup" >&2
        return 1
    fi
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

# Resolve the ROS distro: the registry's distro= field first (#265), then
# the manifest, then config. A registry distro that contradicts the
# manifest is a hard error — two sources of truth must never disagree
# silently. ROS_DISTRO in the per-project config is a pure fallback: it is
# not consulted (and not compared) once the registry or manifest resolved
# the distro. Errors loudly.
_rc_distro() {
    local mdir distro="" config manifest_distro=""
    # The manifest route (issue #436) takes the registry's distro= only: the
    # generated directory has no bootstrap.yaml, and resolving needs the
    # distro before any other config (one source).
    if [ -n "${ACTIVE_PROJECT_SOURCE:-}" ]; then
        distro="${ACTIVE_PROJECT_DISTRO:-}"
        if [ -z "$distro" ]; then
            _rc_registry_field_missing distro
            return 1
        fi
        if ! [[ "$distro" =~ ^[a-z0-9_]+$ ]]; then
            echo "ERROR: invalid ROS distro name '$distro'" >&2
            return 1
        fi
        echo "$distro"
        return 0
    fi
    mdir="$(_rc_manifest_dir)"
    if [ -f "$mdir/bootstrap.yaml" ]; then
        manifest_distro="$(grep '^distro:' "$mdir/bootstrap.yaml" 2>/dev/null \
            | head -1 | cut -d '#' -f 1 | awk '{print $2}')"
    fi
    if [ -n "${ACTIVE_PROJECT_DISTRO:-}" ]; then
        distro="$ACTIVE_PROJECT_DISTRO"
        if [ -n "$manifest_distro" ] && [ "$manifest_distro" != "$distro" ]; then
            echo "ERROR: registry says distro '$distro' for '${ACTIVE_PROJECT_NAME:-?}' but $mdir/bootstrap.yaml says '$manifest_distro'" >&2
            return 1
        fi
    else
        distro="$manifest_distro"
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
        echo "  .agent/projects.local            distro=<name> on the project's line" >&2
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
# four-space-indented keys (type/url/version). The version is the rest of
# its line: a CRLF line end is dropped; a "#" starts a comment only right
# after the key or after whitespace, as in YAML ("fix#12" is a ref); a
# quoted scalar followed by nothing but a comment is emitted unquoted (a
# "#" inside it is part of the ref). Any other quoting ("main" extra,
# 'a''b', and a double-quoted value holding a backslash escape such as
# "x\"y" or "v\x31.0", which this parser does not decode) is emitted raw,
# quotes left in, so a caller can refuse a value that holds a quote rather
# than act on part of it.
# With --detail, each line is "<name>\t<version>\t<form>": form is
# "quoted" (a quoted scalar, unquoted above), "plain" (the text as
# written, which YAML may type as a number, bool or null) or "none" (no
# version: key, version empty: vcstool checks out the default branch, and
# such entries are emitted only with --detail).
_rc_repos_entries() {
    local repos_file="$1" detail=0
    [ "${2:-}" = "--detail" ] && detail=1
    [ -f "$repos_file" ] || return 0
    awk -v detail="$detail" '
        function flush() {
            if (name != "" && detail) printf "%s\t\tnone\n", name
            name = ""
        }
        /^[[:space:]]*#/ { next }
        /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ {
            flush()
            name = $1; sub(/\r$/, "", name); sub(/:$/, "", name)
            next
        }
        /^    version:/ && name != "" {
            v = $0
            sub(/\r$/, "", v)
            sub(/^    version:/, "", v)
            # A comment right after the key leaves the value empty
            # ("version:  # TODO", "version: #main").
            if (v ~ /^[ \t]*#/) v = ""
            sub(/^[ \t]+/, "", v)
            q = substr(v, 1, 1)
            e = 0
            if (q == "\"" || q == "\047") e = index(substr(v, 2), q)
            rest = (e > 0) ? substr(v, e + 2) : ""
            # A double-quoted scalar with a backslash holds an escape
            # ("a\" #b", "v\x31.0") this parser does not decode: raw.
            if (q == "\"" && index(substr(v, 1, e + 1), "\\") > 0) e = 0
            if (e > 0 && (rest ~ /^[ \t]*$/ || rest ~ /^[ \t]+#/)) {
                # A quoted scalar with nothing after it but a comment: its
                # content, unquoted.
                v = substr(v, 2, e - 1)
                form = "quoted"
            } else {
                form = "plain"
                # Plain, or a quote that does not close the value cleanly
                # ("main" extra, x"y, an escaped quote): the raw text,
                # quotes and all, for the caller to refuse.
                sub(/[ \t]+#.*$/, "", v)
                sub(/[ \t]+$/, "", v)
            }
            if (detail) printf "%s\t%s\t%s\n", name, v, form
            else printf "%s\t%s\n", name, v
            name = ""
        }
        END { flush() }
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
# env (a per-invocation override), bootstrap_url in the per-project
# settings file .agent/projects.d/<name> (the dispatcher's
# ACTIVE_PROJECT_BOOTSTRAP_URL, issue #332), MANIFEST_BOOTSTRAP_URL in the
# legacy per-project config (projects.d/<name>.sh, else the shared
# project_config.sh), then the hosting dir's configs/project_bootstrap.url.
# A URL taken from the shared project_config.sh is reported on stderr for a
# registered project, as single_project reports a shared command.
# Never prompts — the adapter runs under make and in CI.
_rc_bootstrap_url() {
    local url="" url_file
    url="$(printf '%s' "${BOOTSTRAP_URL:-}" | tr -d '[:space:]')"
    [ -z "$url" ] && url="${ACTIVE_PROJECT_BOOTSTRAP_URL:-}"
    if [ -z "$url" ]; then
        url="$(_rc_config_var MANIFEST_BOOTSTRAP_URL)" || return 1
        url="$(printf '%s' "$url" | tr -d '[:space:]')"
        if [ -n "$url" ] && [ "$(_rc_config_file)" = "$WORKSPACE_ROOT/.agent/project_config.sh" ]; then
            active_project_fallback_note bootstrap_url
        fi
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
        if [ -n "${ACTIVE_PROJECT_NAME:-}" ]; then
            echo "  .agent/scripts/project_setting.sh set $ACTIVE_PROJECT_NAME bootstrap_url=<url>" >&2
        fi
        echo "  MANIFEST_BOOTSTRAP_URL=<url> in $(_rc_config_file) (legacy)" >&2
        echo "  $root/configs/project_bootstrap.url" >&2
        if [ -n "${ACTIVE_PROJECT_NAME:-}" ]; then
            echo "Or use a manifest in the new format (issue #436): .agent/scripts/project_setting.sh set $ACTIVE_PROJECT_NAME source=<git URL or absolute path> [source_ref=<branch|tag|commit>] [source_path=<file in the repo>], with role= and distro= on its registry line" >&2
        fi
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
    # Reject an absolute path or any '..' path COMPONENT (not substring —
    # 'config..d' cannot escape the clone and must pass).
    local component invalid_path=false
    local -a _rc_components
    [[ "$config_path" == /* ]] && invalid_path=true
    IFS='/' read -r -a _rc_components <<< "$config_path"
    for component in "${_rc_components[@]}"; do
        [ "$component" = ".." ] && invalid_path=true
    done
    if [ "$invalid_path" = true ]; then
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
        # Reuse only a checkout of the SAME repo: a corrected bootstrap.yaml
        # after a partial bootstrap must not silently attach whatever was
        # cloned before. Branch is the developer's business (feature work
        # on a Pattern B manifest repo is normal) — report, don't refuse.
        local existing_url existing_branch
        if ! existing_url="$(_rc_nofd git -C "$clone_dir" remote get-url origin 2>/dev/null)"; then
            echo "ERROR: $clone_dir exists but is not a git checkout with an 'origin' remote." >&2
            echo "Remove it (or point bootstrap.yaml elsewhere) and rerun setup." >&2
            return 1
        fi
        if [ "${existing_url%.git}" != "${git_url%.git}" ]; then
            echo "ERROR: $clone_dir is a checkout of $existing_url, not $git_url." >&2
            echo "Remove it (or fix git_url in the bootstrap config) and rerun setup." >&2
            return 1
        fi
        existing_branch="$(_rc_nofd git -C "$clone_dir" branch --show-current 2>/dev/null)"
        if [ "$existing_branch" != "$branch" ]; then
            echo "  WARNING: existing checkout is on '${existing_branch:-detached}', bootstrap pins '$branch' — reusing as-is"
        else
            echo "  (already present — reusing existing checkout)"
        fi
    elif ! _rc_nofd git clone -b "$branch" "$git_url" "$clone_dir"; then
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

# --- Manifest route (issue #436) -------------------------------------------
# A project whose settings file sets `source` takes the manifest route: its
# manifest, in the new format (tools/ros-manifest), is fetched (a git URL
# source, afresh on each setup and sync; no clone is kept) or read in place
# (a path source), resolved for the registry line's role= and distro= by the
# workspace-installed resolver into a generated directory
# configs/manifest-resolved.gen-XXXXXX/ (a prefix no one types when moving
# a directory aside: only such names are ever removed), and
# configs/manifest-resolved is a link to the current one. Every other verb reads layers.txt,
# optional_layers.txt and repos/<layer>.repos through _rc_manifest_dir, so
# they are the same on both routes (ADR-0012's directory contract). A
# project with no `source` takes the bootstrap route, unchanged.
#
# Never silently stale: after `sync`, what is resolved is what the remotes
# hold now, or the run fails and says why. No clone is kept (owner's
# decision, 2026-11-13, round-5 checkpoint): setup and sync fetch a URL
# source into <gen>.src, a sibling of the new generated directory, removed
# after the resolve and on every exit path, signals included (a further
# INT, TERM or HUP during that removal is ignored); a SIGKILL's leftover
# is in the gen- family the sweep removes. A URL source is https:// or
# file:// (the registry refuses plain http and a user name or password in
# the URL), and the fetch names the transports git may use: https, ssh
# (for a user's url.*.insteadOf rule) and file. The fetch goes into a
# fresh `git init --template=` (SHA-1, or SHA-256 when the remote's object
# names are), so the source repository's config, hooks, replace refs and
# refspecs never apply, while the user's own git configuration
# (credentials, url.*.insteadOf) does; GIT_DIR and the other variables
# that name a repository are cleared for every program the adapter starts
# (_rc_nofd); no hook runs (a global core.hooksPath included), no
# attribute selects a filter or conversion (.git/info/attributes), no
# submodule is fetched, and nothing from the repository is run. ls-remote
# decides the kind of source_ref (a branch, then a tag, else a commit of
# 7 to 64 hex characters); a branch or tag is fetched one commit deep, a
# commit by its full name one commit deep, or, when the server will not
# serve that (or the name is abbreviated), by a full fetch of the remote's
# branches and tags. ls-remote and the fetches are bounded by
# WT_FETCH_TIMEOUT (default 60 s), as repo_pin's calls are. The commit is
# checked out detached; no symbolic link along source_path is followed.
# .resolved-from records source, source_ref, source_path and the commit
# (a path source: a checksum of its content, for validate), and the
# generated files' provenance lines name url#ref:path@commit. A fetch
# failure (offline, a ref the remote lacks, a refused transport, a host
# that does not answer) exits 1 and says the previous result is still in
# use, its link unchanged. setup and sync refuse a manifest-resolved link
# written other than as the bare generated name, before anything is swept
# or fetched. Local manifest work uses the path form. Every `extends` base
# is cloned afresh, the resolver's cache being a sibling of the new
# generated directory removed on every exit.
#
# Network: the source host and every `extends` host at setup and sync, and
# every package host at setup (vcs import) and sync (git pull/fetch); none
# once fetched for the other verbs. The resolver itself comes from PyPI
# when it is installed (make install-ros-manifest).
#
# Concurrency: setup and sync fetch and resolve holding an exclusive flock
# on configs/.lock.source (waits ROS2_COLCON_LOCK_WAIT seconds, default
# 120, then refuses with nothing changed), so two runs never fetch, sweep
# or swap the link at once. The lock file is never removed (the reason
# project_file_set gives in _project_registry.sh). Without flock (macOS by
# default) the fetch and resolve run unlocked, as project_file_set's
# write does, and leftovers of killed runs are not swept (they could be a
# concurrent run's). Every verb reads one generated directory throughout
# (_rc_pin_manifest_dir), holding a shared flock on it, and a directory a
# run still reads is never removed under it: the run that replaced it
# leaves it, and a later sweep removes it once no run reads it. Without
# flock no reader is guarded, so a swap never removes the directory it
# replaces: it removes only older generated directories, so at most two
# remain (the live one and the one before it), and a run reading one
# loses it only after two more syncs. Two unlocked setups or syncs at once
# may still remove each other's directory in progress (that run then
# fails). Where flock cannot lock a directory at all, nothing is removed
# and the run says so once. Programs the adapter starts (git, vcs,
# colcon, the resolver) run through _rc_nofd and inherit neither lock.

# "manifest" when the settings file sets source, else "bootstrap".
_rc_route() {
    if [ -n "${ACTIVE_PROJECT_SOURCE:-}" ]; then echo manifest; else echo bootstrap; fi
}

# Is the source a git URL (else an absolute path to the manifest file)?
_rc_source_is_url() {
    [[ "${ACTIVE_PROJECT_SOURCE:-}" =~ ^(https|file):// ]]
}

# The project's name for messages.
_rc_name() {
    echo "${ACTIVE_PROJECT_NAME:-<name>}"
}

# Report a registry-line field (role, distro) the manifest route needs.
_rc_registry_field_missing() {
    local field="$1" name
    name="$(_rc_name)"
    echo "ERROR: project '$name' sets source (the manifest route), which needs $field=<name> on its registry line." >&2
    echo "Edit the line for '$name' in .agent/projects.local to add $field=<name> (registration does not change an existing line), then run: .agent/scripts/adapter --project $name sync" >&2
}

# Non-comment, non-blank lines of a layers.txt (the resolver always writes
# a '#' provenance line, so a file holding only that selects nothing).
_rc_layer_lines() {
    [ -f "$1" ] || return 0
    grep -v '^[[:space:]]*#' "$1" 2>/dev/null | grep -v '^[[:space:]]*$' || true
}

# "<checksum> <size>" of a file's content (POSIX cksum), so any edit shows,
# one that keeps the size and the second included.
_rc_file_stamp() {
    { cksum < "$1"; } 2>/dev/null
}

# One source only, never a silent choice: on the manifest route every other
# bootstrap source that resolves is a hard error naming it and how to
# remove it. The four are those of _rc_bootstrap_url.
_rc_check_single_source() {
    local name v cfg url_file
    local -a lines=()
    name="$(_rc_name)"
    v="$(printf '%s' "${BOOTSTRAP_URL:-}" | tr -d '[:space:]')"
    [ -n "$v" ] && lines+=("BOOTSTRAP_URL=$v in the environment: unset it when running the adapter for this project")
    [ -n "${ACTIVE_PROJECT_BOOTSTRAP_URL:-}" ] && lines+=("bootstrap_url=${ACTIVE_PROJECT_BOOTSTRAP_URL} in ${ACTIVE_PROJECT_FILE:-the settings file}: remove it with: .agent/scripts/project_setting.sh unset $name bootstrap_url")
    cfg="$(_rc_config_file)"
    v="$(_rc_config_var MANIFEST_BOOTSTRAP_URL)" || return 1
    v="$(printf '%s' "$v" | tr -d '[:space:]')"
    if [ -n "$v" ]; then
        if [ "$cfg" = "$WORKSPACE_ROOT/.agent/project_config.sh" ]; then
            lines+=("MANIFEST_BOOTSTRAP_URL=$v in $cfg (the shared config, read by every project without a legacy file of its own): remove that line")
        else
            lines+=("MANIFEST_BOOTSTRAP_URL=$v in $cfg (the legacy per-project config): remove that line")
        fi
    fi
    url_file="$(_rc_root)/configs/project_bootstrap.url"
    [ -f "$url_file" ] && lines+=("the file $url_file (in the project's root; it may be tracked in the project's own repository): remove it")
    [ "${#lines[@]}" -eq 0 ] && return 0
    echo "ERROR: project '$name' sets source=${ACTIVE_PROJECT_SOURCE:-} (the manifest route), and another bootstrap source was found; a project has one source only, never a silent choice:" >&2
    for v in "${lines[@]}"; do
        echo "  $v" >&2
    done
    echo "Remove the old source above, or stop using source: .agent/scripts/project_setting.sh unset $name source source_ref source_path" >&2
    return 1
}

# The workspace-installed resolver: <main checkout>/.venv/bin/ros-manifest,
# the main checkout found from git's common dir (a worktree has no venv of
# its own; the Makefile's WS_ROOT), else WORKSPACE_ROOT. No PATH lookup, so
# a stray copy elsewhere is never used.
_rc_resolver_bin() {
    local common main="$WORKSPACE_ROOT"
    common="$(_rc_nofd git -C "$WORKSPACE_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || common=""
    [ -n "$common" ] && main="${common%/.git}"
    echo "$main/.venv/bin/ros-manifest"
}

# The transports the fetch may use, stated on its command line as the
# resolver's extends clone states them (tools/ros-manifest extends.py):
# https, ssh (a user's url.*.insteadOf rule may send https to an ssh
# mirror) and file, nothing else; GIT_ALLOW_PROTOCOL says the same in the
# environment, which a user's own protocol.<name>.allow=always cannot widen.
_RC_TRANSPORTS=(-c protocol.allow=never -c protocol.https.allow=always
    -c protocol.ssh.allow=always -c protocol.file.allow=always)

# git in the temporary repository <src> (a fresh `git init`, so only the
# user's own global and system configuration applies, never the source
# repository's): no prompt, no submodules, no hooks (a user's global
# core.hooksPath included), no fsmonitor, the transports above, the
# repository-locating variables cleared and fd 8 and 9 closed (_rc_nofd).
_rc_src_git() {  # <src> <git args...>
    local src="$1"
    shift
    GIT_TERMINAL_PROMPT=0 GIT_ALLOW_PROTOCOL=https:ssh:file _rc_nofd git "${_RC_TRANSPORTS[@]}" -c submodule.recurse=false \
        -c core.hooksPath=/dev/null -c core.fsmonitor=false -C "$src" "$@"
}

# The same, for a call that asks the source's host (ls-remote, fetch):
# bounded as repo_pin's calls are (_adapter_bounded_git, WT_FETCH_TIMEOUT,
# default 60 s), so a stalled host cannot hold the source lock. Exit 124
# or 137 when the limit ended it.
_rc_src_net() {  # <src> <git args...>
    local src="$1"
    shift
    GIT_ALLOW_PROTOCOL=https:ssh:file _rc_nofd _adapter_bounded_git "${_RC_TRANSPORTS[@]}" -c submodule.recurse=false \
        -c core.hooksPath=/dev/null -c core.fsmonitor=false -C "$src" "$@"
}

# What failed in a call to the source's host, for messages.
_rc_net_why() {  # <exit status>
    if [ "$1" -eq 124 ] || [ "$1" -eq 137 ]; then
        echo "it did not finish within $(_adapter_git_limit) s (the limit; WT_FETCH_TIMEOUT raises it): a host that does not answer, or a fetch larger than the limit allows"
    else
        echo "git's message above: offline, a wrong URL, or a transport this fetch does not allow (https, ssh and file only)"
    fi
}

# The commit the live resolved manifest was resolved from, when it came
# from the same source (for the "old -> new" line); empty otherwise.
_rc_live_commit() {
    local rf
    rf="$(_rc_root)/configs/manifest-resolved/.resolved-from"
    [ "$(_rc_resolved_from "$rf" source)" = "${ACTIVE_PROJECT_SOURCE:-}" ] || return 0
    _rc_resolved_from "$rf" commit
}

# Fetch the leaf manifest (see the header above). Sets _RC_SRC_FILE (the
# manifest file to resolve) and _RC_SRC_COMMIT (the fetched commit; empty
# for a path source). A URL source is fetched into <tmp>.src, a sibling of
# the new generated directory _rc_resolve_begin made, which the resolve
# cleanup removes on every exit. A failure returns 1, the previously
# resolved manifest and its link as they were.
_rc_source_fetch() {
    local url ref spath src kind sha old remote fetched=0 rc=0
    _RC_SRC_FILE=""
    _RC_SRC_COMMIT=""
    url="${ACTIVE_PROJECT_SOURCE:-}"
    if ! _rc_source_is_url; then
        if [ ! -f "$url" ] || [ ! -r "$url" ]; then
            echo "ERROR: source $url (project '$(_rc_name)') is not a readable file" >&2
            return 1
        fi
        _RC_SRC_FILE="$url"
        echo "source: $url (a file, read in place)"
        return 0
    fi
    ref="${ACTIVE_PROJECT_SOURCE_REF:-}"
    spath="${ACTIVE_PROJECT_SOURCE_PATH:-manifest.yaml}"
    src="${_RC_RESOLVE_TMP:?}.src"
    local kept="the previously resolved manifest, if any, is still in use (its link unchanged)"
    # --template= : no hooks or other files copied into the new repository.
    # The object format is stated (a user's init.defaultObjectFormat must
    # not decide it) and matched to the remote's below.
    if ! mkdir -- "$src" || ! _rc_src_git "$src" init --quiet --template= --object-format=sha1 >/dev/null; then
        echo "ERROR: cannot make the temporary repository $src for fetching source $url; $kept" >&2
        return 1
    fi
    echo "source: fetching '$ref' from $url"
    # The remote names the kind: a branch first, then a tag. All its refs
    # are listed, so the length of its object names is known even when its
    # HEAD is unborn and source_ref is a commit.
    remote="$(_rc_src_net "$src" ls-remote -- "$url")" || rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ERROR: cannot reach source $url ($(_rc_net_why "$rc")); $kept" >&2
        return 1
    fi
    # A SHA-256 remote: the temporary repository is made again to match.
    if grep -Eq '^[0-9a-f]{64}[[:space:]]' <<< "$remote"; then
        if ! rm -rf -- "${src:?}/.git" || ! _rc_src_git "$src" init --quiet --template= --object-format=sha256 >/dev/null; then
            echo "ERROR: cannot make the temporary SHA-256 repository $src for fetching source $url; $kept" >&2
            return 1
        fi
    fi
    if awk -F'\t' -v r="refs/heads/$ref" '$2 == r { f = 1 } END { exit !f }' <<< "$remote"; then
        kind=branch
    elif awk -F'\t' -v r="refs/tags/$ref" '$2 == r { f = 1 } END { exit !f }' <<< "$remote"; then
        kind=tag
    elif [[ "$ref" =~ ^[0-9a-fA-F]{7,64}$ ]]; then
        kind=commit
    else
        echo "ERROR: source_ref '$ref' is not a branch or tag of $url, nor a commit (a commit is 7 to 64 hex characters); $kept" >&2
        return 1
    fi
    if [ "$kind" != commit ]; then
        # One ref, one commit deep, into FETCH_HEAD only.
        _rc_src_net "$src" fetch --quiet --depth 1 --no-tags --no-recurse-submodules -- "$url" "refs/$([ "$kind" = branch ] && echo heads || echo tags)/$ref" || rc=$?
        if [ "$rc" -ne 0 ]; then
            echo "ERROR: cannot fetch $kind '$ref' of source $url ($(_rc_net_why "$rc")); $kept" >&2
            return 1
        fi
        sha="$(_rc_src_git "$src" rev-parse --verify --quiet "FETCH_HEAD^{commit}")" || sha=""
    else
        # A full commit name is asked for shallow first; a server that will
        # not serve it so, and an abbreviated name, take a full fetch of the
        # remote's branches and tags.
        if [[ "$ref" =~ ^([0-9a-fA-F]{40}|[0-9a-fA-F]{64})$ ]] \
            && _rc_src_net "$src" fetch --quiet --depth 1 --no-tags --no-recurse-submodules -- "$url" "$ref" 2>/dev/null; then
            fetched=1
        else
            _rc_src_net "$src" fetch --quiet --no-tags --no-recurse-submodules -- "$url" \
                '+refs/heads/*:refs/remotes/source/*' '+refs/tags/*:refs/tags/*' || rc=$?
            [ "$rc" -eq 0 ] && fetched=1
        fi
        if [ "$fetched" -eq 0 ]; then
            echo "ERROR: cannot fetch source $url to look for commit '$ref' ($(_rc_net_why "$rc")); $kept" >&2
            return 1
        fi
        sha="$(_rc_src_git "$src" rev-parse --verify --quiet "$ref^{commit}" 2>/dev/null)" || sha=""
        if [ -z "$sha" ]; then
            echo "ERROR: source_ref '$ref' is not a branch or tag of $url, nor a commit it holds; $kept" >&2
            return 1
        fi
    fi
    # No attribute of the fetched tree may select a filter, an encoding or a
    # line-ending conversion from the user's configuration (git-lfs's
    # filter would contact a host the repository names).
    if ! mkdir -p "$src/.git/info" \
        || ! printf '%s\n' '* -filter -text -ident -working-tree-encoding' > "$src/.git/info/attributes"; then
        echo "ERROR: cannot write $src/.git/info/attributes; $kept" >&2
        return 1
    fi
    if [ -z "$sha" ] || ! _rc_src_git "$src" -c advice.detachedHead=false checkout --quiet --detach "$sha"; then
        echo "ERROR: cannot check out $kind '$ref' of source $url in $src; $kept" >&2
        return 1
    fi
    old="$(_rc_live_commit)"
    if [ -n "$old" ] && [ "$old" != "$sha" ]; then
        echo "source: $kind $ref ${old:0:12} -> ${sha:0:12}"
    else
        echo "source: $kind $ref at ${sha:0:12}"
    fi
    _RC_SRC_COMMIT="$sha"
    _RC_SRC_FILE="$src/$spath"
    # The repository is not trusted to stay inside itself: a symbolic link
    # anywhere along source_path could lead the resolver to any file the
    # user can read, so none is followed.
    local part="" comp
    local -a comps=()
    IFS='/' read -r -a comps <<< "$spath"
    for comp in "${comps[@]}"; do
        [ -z "$comp" ] || [ "$comp" = . ] && continue
        part="${part:+$part/}$comp"
        if [ -L "$src/$part" ]; then
            echo "ERROR: source_path '$spath' goes through the symbolic link '$part' in $url at '$ref'; a symbolic link is never followed out of the source repository: name the file itself; $kept" >&2
            return 1
        fi
    done
    if [ ! -f "$_RC_SRC_FILE" ]; then
        echo "ERROR: source_path '$spath' is not a file in $url at '$ref'; $kept" >&2
        return 1
    fi
}

# Before the fetch (setup and sync): refuse anything but a link at
# configs/manifest-resolved; holding the source lock, sweep what a killed
# run (SIGKILL, a power cut) left: every generated directory, fetched
# source, cache and link the live link does not point at; then make the
# new generated directory configs/manifest-resolved.gen-XXXXXX. From here
# the cleanup (_rc_resolve_cleanup) removes it, its fetched source <tmp>.src,
# the resolver's cache <tmp>.cache and the new link <tmp>.link on every
# exit, an interrupt included, unless the link already points at the new
# directory (an interrupt just after the swap).
_rc_resolve_begin() {
    local configs link tmp
    configs="$(_rc_root)/configs"
    link="$configs/manifest-resolved"
    mkdir -p "$configs" || return 1
    if [ -e "$link" ] && [ ! -L "$link" ]; then
        echo "ERROR: $link is not the link the adapter writes (a directory or file is there); move it aside (to manifest-resolved.old, say: the adapter removes only the manifest-resolved.gen-* names it makes) and rerun" >&2
        return 1
    fi
    # The sweep keeps the directory the link names; a link written another
    # way (./name, an absolute path) would have its target swept, so it is
    # refused before anything is swept or fetched.
    local target
    if [ -L "$link" ]; then
        target="$(readlink -- "$link")"
        if ! [[ "$target" =~ ^manifest-resolved\.gen-[A-Za-z0-9]{6}$ ]]; then
            echo "ERROR: $link points at '$target', not at a manifest-resolved.gen-XXXXXX name beside it as the adapter writes it; nothing was removed or fetched. If it names a generated directory in $configs, write the link with the name alone (cd $configs && ln -sfn manifest-resolved.gen-XXXXXX manifest-resolved); otherwise remove the link and run setup" >&2
            return 1
        fi
    fi
    [ "${_RC_SOURCE_LOCKED:-0}" -eq 1 ] && _rc_resolve_sweep "$configs"
    _RC_RESOLVE_LINK="$link"
    tmp="$(mktemp -d "$configs/manifest-resolved.gen-XXXXXX")" || return 1
    _RC_RESOLVE_TMP="$tmp"
    trap '_rc_resolve_cleanup' EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
}

# Resolve _RC_SRC_FILE for the registry line's role and distro into the
# generated directory _rc_resolve_begin made, then point
# configs/manifest-resolved at it and remove the previous one. A failure
# (the resolver's, or a role and distro that select nothing) leaves the
# previous directory and link as they are. Sets _RC_LAYERS_CHANGED (1 when
# layers.txt or the distro changed).
_rc_manifest_resolve() {
    local configs link bin role distro tmp rc=0 err count prev old_layers new_layers
    _RC_LAYERS_CHANGED=0
    role="${ACTIVE_PROJECT_ROLE:-}"
    distro="$(_rc_distro)" || return 1
    bin="$(_rc_resolver_bin)"
    tmp="${_RC_RESOLVE_TMP:?}"
    link="${_RC_RESOLVE_LINK:?}"
    configs="$(dirname "$tmp")"
    # The path source's stamp is taken before the resolve, so an edit made
    # while it runs shows in validate as a changed file.
    local stamp=""
    _rc_source_is_url || stamp="$(_rc_file_stamp "$_RC_SRC_FILE")"
    err="$(_rc_nofd "$bin" resolve --manifest "$_RC_SRC_FILE" --role "$role" --distro "$distro" \
        --out "$tmp" --layout manifest-dir --cache-dir "$tmp.cache" 2>&1 >/dev/null)" || rc=$?
    rm -rf -- "$tmp.cache" "$tmp.src"
    [ -n "$err" ] && printf '%s\n' "$err" >&2
    if [ "$rc" -ne 0 ]; then
        if [ "$rc" -eq 2 ] && [[ "$err" == *--layout* ]]; then
            echo "ERROR: the resolver at $bin predates this adapter (it does not know --layout manifest-dir); reinstall it: make install-ros-manifest (from the workspace main checkout)" >&2
        else
            echo "ERROR: the manifest resolver failed (exit $rc, above); nothing changed: the previously resolved manifest, if any, is kept" >&2
        fi
        _rc_resolve_cleanup
        return 1
    fi
    count="$(_rc_layer_lines "$tmp/layers.txt" | wc -l | tr -d '[:space:]')"
    if [ "${count:-0}" -eq 0 ]; then
        echo "ERROR: role '$role' and distro '$distro' select no repositories from $_RC_SRC_FILE; nothing changed (check role= and distro= on the registry line, and the manifest's roles and distros)" >&2
        _rc_resolve_cleanup
        return 1
    fi
    {
        echo "# Written by the ros2_colcon adapter (issue #436): what this directory was resolved from. Read by adapter validate."
        echo "route=manifest"
        echo "source=${ACTIVE_PROJECT_SOURCE:-}"
        echo "source_ref=${ACTIVE_PROJECT_SOURCE_REF:-}"
        echo "source_path=${ACTIVE_PROJECT_SOURCE_PATH:-}"
        echo "commit=$_RC_SRC_COMMIT"
        echo "role=$role"
        echo "distro=$distro"
        if ! _rc_source_is_url; then
            echo "file-stamp=$stamp"
        fi
    } > "$tmp/.resolved-from" || { _rc_resolve_cleanup; return 1; }
    # The generated files' '#' provenance lines name the manifest the
    # resolver read, for a URL source a temporary path gone after this run:
    # name it as the resolver names an extends base, url#ref:path@commit.
    if _rc_source_is_url && ! _rc_relabel_provenance "$tmp" "$_RC_SRC_FILE" \
        "${ACTIVE_PROJECT_SOURCE}#${ACTIVE_PROJECT_SOURCE_REF:-}:${ACTIVE_PROJECT_SOURCE_PATH:-manifest.yaml}@$_RC_SRC_COMMIT"; then
        echo "ERROR: cannot rewrite the provenance lines in $tmp; the previously resolved manifest, if any, is kept" >&2
        _rc_resolve_cleanup
        return 1
    fi
    prev=""
    [ -L "$link" ] && prev="$(readlink -- "$link")"
    # A package worktree's env.sh embeds the layers and the distro's
    # underlay: either changing is announced.
    old_layers="$(_rc_layer_lines "$link/layers.txt")
distro=$(_rc_resolved_from "$link/.resolved-from" distro)"
    new_layers="$(_rc_layer_lines "$tmp/layers.txt")
distro=$distro"
    # Swap atomically: a new relative link renamed over the old one.
    if ! ln -s "$(basename "$tmp")" "$tmp.link"; then
        _rc_resolve_cleanup
        return 1
    fi
    # The form this mv supports, probed once: GNU mv -T or BSD mv -h, both
    # rename(2) the link over the old one, never into the directory it
    # points at. A failed probe, or a failure of that form, is an error
    # that leaves the live link in place. Only an mv with neither (the
    # probe says "none") removes the old link first, leaving a moment with
    # no link, and a failure then says the link is gone.
    local mvform rc_mv=0
    if ! mvform="$(_rc_mv_link_form "$configs")"; then
        echo "ERROR: cannot probe how mv renames a link in $configs (above); nothing changed: the previously resolved manifest, if any, is kept" >&2
        _rc_resolve_cleanup
        return 1
    fi
    case "$mvform" in
        T) mv -T "$tmp.link" "$link" || rc_mv=$? ;;
        h) mv -fh "$tmp.link" "$link" || rc_mv=$? ;;
        none)
            rm -f -- "$link"
            if ! mv "$tmp.link" "$link"; then
                echo "ERROR: this mv cannot rename a link over another, so the old link $link was removed first, and putting the new one in place failed (above): there is no resolved manifest link now; run sync again" >&2
                _rc_resolve_cleanup
                return 1
            fi ;;
    esac
    if [ "$rc_mv" -ne 0 ]; then
        echo "ERROR: cannot rename the new link over $link (mv -$mvform failed, above); nothing changed: the previously resolved manifest, if any, is kept" >&2
        _rc_resolve_cleanup
        return 1
    fi
    _RC_RESOLVE_TMP=""
    trap - EXIT HUP INT TERM
    if [ -n "$prev" ] && [ "$prev" != "$(basename "$tmp")" ] \
        && [[ "$prev" =~ ^manifest-resolved\.gen-[A-Za-z0-9]{6}$ ]] && [ -d "$configs/$prev" ]; then
        if [ "${_RC_SOURCE_LOCKED:-0}" -eq 1 ]; then
            _rc_remove_generated "${configs:?}/$prev"
        fi
    fi
    # Without flock no reader is guarded, so the directory just replaced is
    # kept (a run may still read it) and only older ones are removed: at
    # most the live directory and the one before it remain.
    [ "${_RC_SOURCE_LOCKED:-0}" -eq 1 ] || _rc_prune_unlocked "$configs" "$(basename "$tmp")" "$prev"
    [ -n "$prev" ] && [ "$old_layers" != "$new_layers" ] && _RC_LAYERS_CHANGED=1
    echo "source: resolved role '$role' distro '$distro': $count layer(s) in $link"
}

# In the '#' lines of every file under <dir>, replace the text <old> by
# <new> (taken from the environment, so no character is special).
_rc_relabel_provenance() {  # <dir> <old> <new>
    local f
    while IFS= read -r f; do
        RC_OLD="$2" RC_NEW="$3" awk '
            BEGIN { o = ENVIRON["RC_OLD"]; n = ENVIRON["RC_NEW"] }
            /^#/ { out = ""; rest = $0
                   while ((i = index(rest, o)) > 0) { out = out substr(rest, 1, i - 1) n; rest = substr(rest, i + length(o)) }
                   $0 = out rest }
            { print }' "$f" > "$f.relabel" && mv -- "$f.relabel" "$f" || return 1
    done < <(find "$1" -type f ! -name .resolved-from)
}

# Remove the new generated directory, its fetched source, its cache and
# its link, keeping the directory when the live link already points at it
# (the swap happened). A further INT, TERM or HUP while it runs is
# ignored (and so by rm, which inherits that), so a second Ctrl-C cannot
# leave a half-removed directory; the exit status stays the first one's.
_rc_resolve_cleanup() {
    local tmp="${_RC_RESOLVE_TMP:-}"
    trap '' INT TERM HUP
    if [ -n "$tmp" ]; then
        rm -rf -- "$tmp.src" "$tmp.cache" "$tmp.link"
        if [ "$(readlink -- "${_RC_RESOLVE_LINK:-/nonexistent}" 2>/dev/null)" != "$(basename "$tmp")" ]; then
            rm -rf -- "$tmp"
        fi
    fi
    _RC_RESOLVE_TMP=""
    trap - EXIT HUP INT TERM
}

# Which option of this mv renames a symbolic link to a directory over
# another such link rather than into the directory: T (GNU), h (BSD), or
# none; returns 1 when the probe itself cannot run. Probed once per resolve, in a scratch directory
# <configs>/.mv-probe.XXXXXX that is removed (and swept if a kill left it).
_rc_mv_link_form() {
    local configs="$1" d f form=none
    d="$(mktemp -d "$configs/.mv-probe.XXXXXX")" || return 1
    for f in T h; do
        rm -rf -- "${d:?}"/*
        if ! { mkdir "$d/t" && ln -s t "$d/old" && ln -s t "$d/new"; }; then
            rm -rf -- "$d"
            return 1
        fi
        if [ "$f" = T ]; then
            mv -T "$d/new" "$d/old" 2>/dev/null || continue
        else
            mv -fh "$d/new" "$d/old" 2>/dev/null || continue
        fi
        if [ -L "$d/old" ] && [ ! -e "$d/new" ] && [ ! -e "$d/t/new" ]; then
            form="$f"
            break
        fi
    done
    rm -rf -- "$d"
    echo "$form"
}

# Without flock: remove the generated directories (with their fetched
# sources, caches and links) other than <keep1> and <keep2>.
_rc_prune_unlocked() {
    local configs="$1" keep1="$2" keep2="$3" e n base
    for e in "$configs"/manifest-resolved.gen-*; do
        [ -e "$e" ] || [ -L "$e" ] || continue
        n="$(basename "$e")"
        [[ "$n" =~ ^manifest-resolved\.gen-[A-Za-z0-9]{6}(\.cache|\.link|\.src)?$ ]] || continue
        base="${n%.cache}"
        base="${base%.link}"
        base="${base%.src}"
        [ "$base" = "$keep1" ] || [ "$base" = "$keep2" ] && continue
        rm -rf -- "$e"
    done
    return 0
}

# Remove configs/manifest-resolved.gen-XXXXXX directories, fetched sources (.src),
# caches and links the live link does not point at: a killed run leaves them, and so does a
# swap whose previous directory a run was still reading (removed here once
# no run reads it, _rc_remove_generated). This runs only while the source
# lock is held, so a concurrent run's new directory is never taken for a
# leftover.
_rc_resolve_sweep() {
    local configs="$1" live="" e n
    [ -L "$configs/manifest-resolved" ] && live="$(readlink -- "$configs/manifest-resolved")"
    for e in "$configs"/manifest-resolved.gen-*; do
        [ -e "$e" ] || [ -L "$e" ] || continue
        n="$(basename "$e")"
        [[ "$n" =~ ^manifest-resolved\.gen-[A-Za-z0-9]{6}(\.cache|\.link|\.src)?$ ]] || continue
        [ -n "$live" ] && [ "$n" = "$live" ] && continue
        if [ -d "$e" ] && [ ! -L "$e" ] && [[ "$n" =~ ^manifest-resolved\.gen-[A-Za-z0-9]{6}$ ]]; then
            _rc_remove_generated "$e"
        else
            rm -rf -- "$e"
        fi
    done
    for e in "$configs"/.mv-probe.*; do
        [ -d "$e" ] && [[ "$(basename "$e")" =~ ^\.mv-probe\.[A-Za-z0-9]{6}$ ]] && rm -rf -- "$e"
    done
    return 0
}

# Everything the manifest route checks before it contacts any remote, then
# fetch and resolve (setup and sync).
_rc_manifest_prepare() {
    local bin
    _rc_check_single_source || return 1
    if [ -z "${ACTIVE_PROJECT_ROLE:-}" ]; then
        _rc_registry_field_missing role
        return 1
    fi
    _rc_distro >/dev/null || return 1
    bin="$(_rc_resolver_bin)"
    if [ ! -x "$bin" ]; then
        echo "ERROR: the manifest resolver is not installed at $bin; run: make install-ros-manifest (from the workspace main checkout)" >&2
        return 1
    fi
    local rc=0
    _rc_source_lock || return 1
    # 9>&- keeps the lock's descriptor from git, the resolver and every
    # other child (a detached one, git's auto gc say, would otherwise hold
    # the lock after the adapter ends): bash saves fd 9 for the group under
    # a close-on-exec copy, so this shell still holds the lock.
    { _rc_resolve_begin && _rc_source_fetch && _rc_manifest_resolve; } 9>&- || rc=$?
    [ "$rc" -eq 0 ] || _rc_resolve_cleanup
    _rc_source_unlock
    return "$rc"
}

# Take the project's source lock (see "Concurrency" above) on fd 9; sets
# _RC_SOURCE_LOCKED (1 when held). Returns 1, saying so, when another run
# holds it past the wait.
_rc_source_lock() {
    local configs lock wait="${ROS2_COLCON_LOCK_WAIT:-120}"
    _RC_SOURCE_LOCKED=0
    # Checked first, with or without flock, so a bad value is never taken
    # for another run holding the lock (flock's usage error).
    if ! [[ "$wait" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "ERROR: ROS2_COLCON_LOCK_WAIT='$wait' is not a number of seconds (digits, with an optional decimal part, such as 120 or 0.5); unset it for the default, 120" >&2
        return 1
    fi
    command -v flock >/dev/null 2>&1 || return 0
    configs="$(_rc_root)/configs"
    mkdir -p "$configs" || return 1
    lock="$configs/.lock.source"
    if ! exec 9>>"$lock"; then
        echo "ERROR: cannot open the lock file $lock" >&2
        return 1
    fi
    if ! flock -x -w "$wait" 9; then
        exec 9>&-
        echo "ERROR: another setup or sync of project '$(_rc_name)' holds its lock $lock (waited $wait s); nothing changed: try again when it has ended" >&2
        return 1
    fi
    _RC_SOURCE_LOCKED=1
}

_rc_source_unlock() {
    [ "${_RC_SOURCE_LOCKED:-0}" -eq 1 ] || return 0
    exec 9>&-
    _RC_SOURCE_LOCKED=0
}

# The value of <key> in a .resolved-from file (empty when absent).
_rc_resolved_from() {
    local file="$1" key="$2" line
    [ -f "$file" ] || return 0
    while IFS= read -r line; do
        [ "${line%%=*}" = "$key" ] && { printf '%s\n' "${line#*=}"; return 0; }
    done < "$file"
    return 0
}

# validate's checks for the manifest route, after the directory is known
# to exist: prints each problem (❌, counted) and each warning (⚠️, not
# counted) on stderr; prints the count of problems on stdout.
_rc_validate_manifest_route() {
    local mdir rf name issues=0 key want got stamp
    mdir="$(_rc_manifest_dir)"
    rf="$mdir/.resolved-from"
    name="$(_rc_name)"
    local msg
    if ! msg="$(_rc_check_single_source 2>&1)"; then
        printf '❌ %s\n' "$msg" >&2
        issues=$((issues + 1))
    fi
    if [ ! -f "$rf" ]; then
        echo "❌ $rf is missing: the resolved manifest's origin is unknown (run: .agent/scripts/adapter --project $name sync)" >&2
        echo $((issues + 1))
        return 0
    fi
    local source_changed=0
    for key in source source_ref source_path; do
        case "$key" in
            source) want="${ACTIVE_PROJECT_SOURCE:-}" ;;
            source_ref) want="${ACTIVE_PROJECT_SOURCE_REF:-}" ;;
            source_path) want="${ACTIVE_PROJECT_SOURCE_PATH:-}" ;;
        esac
        got="$(_rc_resolved_from "$rf" "$key")"
        if [ "$got" != "$want" ]; then
            echo "❌ the resolved manifest is from $key='$got' but the settings file says $key='$want' (run: .agent/scripts/adapter --project $name sync)" >&2
            issues=$((issues + 1))
            [ "$key" = source ] && source_changed=1
        fi
    done
    for key in role distro; do
        if [ "$key" = role ]; then want="${ACTIVE_PROJECT_ROLE:-}"; else want="${ACTIVE_PROJECT_DISTRO:-}"; fi
        got="$(_rc_resolved_from "$rf" "$key")"
        if [ -z "$want" ]; then
            [ "$key" = role ] && { _rc_registry_field_missing role 2>&1 | sed 's/^/❌ /' >&2; issues=$((issues + 1)); }
            continue
        fi
        if [ "$got" != "$want" ]; then
            echo "❌ the resolved manifest is for $key '$got' but the registry line says $key=$want (run: .agent/scripts/adapter --project $name sync; to change it back, edit the line in .agent/projects.local)" >&2
            issues=$((issues + 1))
        fi
    done
    # A path source still the one resolved: warn when the file changed
    # since (validate never fetches, so a URL source has no such check).
    if [ "$source_changed" -eq 0 ] && [ -n "${ACTIVE_PROJECT_SOURCE:-}" ] && ! _rc_source_is_url; then
        stamp="$(_rc_file_stamp "$ACTIVE_PROJECT_SOURCE" || true)"
        got="$(_rc_resolved_from "$rf" file-stamp)"
        if [ -z "$stamp" ]; then
            echo "⚠️  WARNING: the source file $ACTIVE_PROJECT_SOURCE is missing or unreadable; the resolved manifest is kept, and sync fails until source names a readable file" >&2
        elif [ "$stamp" != "$got" ]; then
            echo "⚠️  WARNING: the source file $ACTIVE_PROJECT_SOURCE has changed since it was resolved (its content differs; run: .agent/scripts/adapter --project $name sync)" >&2
        fi
    fi
    # vcs import never removes a checkout: one a role or distro change left
    # behind is named, and the adapter removes nothing.
    local ws layer d n
    for ws in "$(_rc_root)"/layers/main/*_ws; do
        [ -d "$ws/src" ] || continue
        layer="$(basename "$ws")"
        layer="${layer%_ws}"
        for d in "$ws/src"/*; do
            [ -d "$d" ] || continue
            n="$(basename "$d")"
            if ! _rc_repos_entries "$mdir/repos/${layer}.repos" | cut -f1 | grep -qxF -- "$n"; then
                echo "⚠️  WARNING: layer '$layer': '$n' is checked out but not in the resolved manifest (role '${ACTIVE_PROJECT_ROLE:-}', distro '${ACTIVE_PROJECT_DISTRO:-}'); nothing removes it: remove $d by hand if it is not needed" >&2
            fi
        done
    done
    echo "$issues"
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
    if [ "$(_rc_route)" = manifest ]; then
        # vcs first: a missing tool is reported before any remote is
        # contacted.
        if ! command -v vcs >/dev/null 2>&1; then
            echo "ERROR: 'vcs' (vcstool) not found — required to import layer repos." >&2
            return 1
        fi
        _rc_manifest_prepare || return 1
        echo "note: the adapter keeps configs/manifest-resolved* and configs/.lock.source in $(_rc_root) and edits no ignore file; if that root is a git checkout, ignore them there"
    else
        _rc_bootstrap_manifest || return 1
    fi
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
        if ! _rc_nofd vcs import --skip-existing "$layer_dir/src" < "$repos_file"; then
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
            && _rc_nofd colcon build --symlink-install \
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
            && _rc_nofd colcon test --event-handlers console_direct+ \
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
    # On the manifest route (issue #436) the source is fetched and resolved
    # first; a failure there stops sync with nothing changed.
    local route missing=0
    route="$(_rc_route)"
    if [ "$route" = manifest ]; then
        _rc_manifest_prepare || return 1
    fi
    _rc_require_manifest || return 1
    local mdir layer layer_dir repos_file entry name version repo_dir branch
    mdir="$(_rc_manifest_dir)"
    while IFS= read -r layer; do
        layer_dir="$(_rc_layer_dir "$layer")"
        repos_file="$mdir/repos/${layer}.repos"
        if [ ! -d "$layer_dir/src" ]; then
            # A layer never set up (new after a role or distro change):
            # every repository in it is still to be checked out.
            while IFS= read -r entry; do
                [ -n "$entry" ] && missing=$((missing + 1))
            done < <(_rc_repos_entries "$repos_file")
            continue
        fi
        while IFS= read -r entry; do
            [ -z "$entry" ] && continue
            name="${entry%%$'\t'*}"
            version="${entry#*$'\t'}"
            repo_dir="$layer_dir/src/$name"
            [ -d "$repo_dir" ] || missing=$((missing + 1))
            _rc_nofd git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1 || continue
            if [ -n "$(_rc_nofd git -C "$repo_dir" status --porcelain 2>/dev/null)" ]; then
                echo "  $layer/$name: skipped (uncommitted changes)"
                continue
            fi
            branch="$(_rc_nofd git -C "$repo_dir" branch --show-current 2>/dev/null)"
            # A detached checkout has no branch; an empty pin must not
            # match it and send it down the pull path.
            if [ -n "$branch" ] && [ "$branch" = "$version" ]; then
                echo "  $layer/$name: on '$branch' — pulling..."
                if ! _rc_nofd git -C "$repo_dir" pull --rebase 2>/dev/null; then
                    # Abort a wedged rebase so the checkout stays usable.
                    _rc_nofd git -C "$repo_dir" rebase --abort >/dev/null 2>&1 || true
                    echo "  $layer/$name: pull failed (continuing)" >&2
                fi
            else
                echo "  $layer/$name: on '${branch:-detached}' (pinned: $version) — fetching..."
                _rc_nofd git -C "$repo_dir" fetch 2>/dev/null \
                    || echo "  $layer/$name: fetch failed (continuing)" >&2
            fi
        done < <(_rc_repos_entries "$repos_file")
    done < <(_rc_layers)
    if [ "$route" = manifest ]; then
        if [ "$missing" -gt 0 ]; then
            echo "source: $missing repositor$([ "$missing" -eq 1 ] && echo y || echo ies) in the resolved manifest not checked out yet; run: .agent/scripts/adapter --project $(_rc_name) setup"
        fi
        if [ "${_RC_LAYERS_CHANGED:-0}" -eq 1 ]; then
            echo "source: the layers or the distro changed; existing package worktrees keep their old env.sh; recreate them"
        fi
    fi
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
    if [ "$(_rc_route)" = manifest ]; then
        local route_issues
        route_issues="$(_rc_validate_manifest_route)"
        issues=$((issues + ${route_issues:-1}))
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
    # config-driven, matching single_project's install semantics (issue
    # #332): install= in the per-project settings file, then INSTALL_CMD in
    # the legacy projects.d/<name>.sh when it exists, else in the shared
    # project_config.sh (reported on stderr for a registered project).
    local from="" shared
    shared="$WORKSPACE_ROOT/.agent/project_config.sh"
    if [ -n "${ACTIVE_PROJECT_INSTALL:-}" ]; then
        if [ "$ACTIVE_PROJECT_INSTALL" = "none" ]; then
            echo "install=none: project '$ACTIVE_PROJECT_NAME' records that it has no install step — nothing to install (colcon installs during build)."
            return 0
        fi
        echo "Running: $ACTIVE_PROJECT_INSTALL $*"
        echo ""
        cd "$(_rc_root)" || return 1
        active_project_exec "$ACTIVE_PROJECT_INSTALL" "$@"
    fi
    INSTALL_CMD=""
    if [ -n "${ACTIVE_PROJECT_CONFIG:-}" ] && [ -f "$ACTIVE_PROJECT_CONFIG" ]; then
        # shellcheck source=/dev/null
        source "$ACTIVE_PROJECT_CONFIG"
        from="legacy"
    elif [ -f "$shared" ]; then
        # shellcheck source=/dev/null
        source "$shared"
        [ -n "${INSTALL_CMD:-}" ] && from="shared"
    fi
    if [ -z "${INSTALL_CMD:-}" ]; then
        echo "INSTALL_CMD not set — nothing to install (colcon installs during build)."
        return 0
    fi
    [ "$from" = "shared" ] && active_project_fallback_note install
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
            _rc_nofd git -C "$pkg_dir" rev-parse --git-dir >/dev/null 2>&1 || continue
            echo "$(basename "$pkg_dir"):$pkg_dir"
            found=1
        done
    done < <(_rc_layers)
    if [ "$found" -eq 0 ]; then
        echo "ERROR: no package repos found (run: adapter setup)" >&2
        return 1
    fi
}

adapter_worktree_repos() {
    # One line per named package repo: <origin>\t<layer>_ws/src/<pkg>\t<branch>
    # (ADR-0012). --layer and --package-repos are both required — a package
    # worktree names its layer and its packages explicitly, nothing inferred.
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
        echo "ERROR: worktree_repos requires --issue owner/repo#N" >&2
        return 1
    fi
    local owner repo num
    if [[ "$issue" =~ ^([^/]+)/([^#]+)#([0-9]+)$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
        num="${BASH_REMATCH[3]}"
    else
        echo "ERROR: ros2_colcon requires a qualified --issue owner/repo#N (got '$issue')" >&2
        return 1
    fi
    if [ -z "$layer" ] || [ -z "$package_repos" ]; then
        echo "ERROR: ros2_colcon requires both --layer <l> and --package-repos <a,b>" >&2
        return 1
    fi
    _rc_require_manifest || return 1
    if ! [[ "$layer" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "ERROR: invalid layer name '$layer'" >&2
        return 1
    fi
    local l found=0
    while IFS= read -r l; do
        [ "$l" = "$layer" ] && found=1
    done < <(_rc_layers)
    if [ "$found" -ne 1 ]; then
        echo "ERROR: layer '$layer' is not defined in layers.txt" >&2
        return 1
    fi
    local layer_dir; layer_dir="$(_rc_layer_dir "$layer")"
    local -a pkgs
    IFS=',' read -r -a pkgs <<< "$package_repos"
    local pkg pkg_dir owner_repo branch
    for pkg in "${pkgs[@]}"; do
        [ -z "$pkg" ] && continue
        pkg_dir="$layer_dir/src/$pkg"
        if [ ! -d "$pkg_dir" ]; then
            local other_layer other_dir
            while IFS= read -r other_layer; do
                [ "$other_layer" = "$layer" ] && continue
                other_dir="$(_rc_layer_dir "$other_layer")/src/$pkg"
                if [ -d "$other_dir" ]; then
                    echo "ERROR: package repo '$pkg' is in layer '$other_layer', not '$layer'" >&2
                    return 1
                fi
            done < <(_rc_layers)
            echo "ERROR: package repo '$pkg' not found under layer '$layer' ($pkg_dir)" >&2
            return 1
        fi
        # rev-parse --git-dir alone would walk up to an ancestor's .git (the
        # workspace repo, say) when $pkg_dir has none of its own — compare
        # against --show-toplevel to require a repo rooted at $pkg_dir itself.
        local pkg_toplevel pkg_dir_real
        pkg_toplevel="$(_rc_nofd git -C "$pkg_dir" rev-parse --show-toplevel 2>/dev/null || true)"
        pkg_dir_real="$(cd "$pkg_dir" && pwd -P)"
        if [ -z "$pkg_toplevel" ] || [ "$pkg_toplevel" != "$pkg_dir_real" ]; then
            echo "ERROR: $pkg_dir (layer '$layer', package '$pkg') is not a git repository" >&2
            return 1
        fi
        owner_repo="$(adapter_scope_for_pr "$pkg_dir" 2>/dev/null || true)"
        if [ "$owner_repo" = "$owner/$repo" ]; then
            branch="feature/issue-$num"
        else
            branch="feature/${repo}-issue-${num}"
        fi
        printf '%s\t%s_ws/src/%s\t%s\n' "$pkg_dir" "$layer" "$pkg" "$branch"
    done
}

adapter_worktree_env() {
    # Sourceable bash for a package worktree: scrub, distro underlay, every
    # layer below the target layer's local_setup.bash (hosted instance,
    # ascending), the hosted instance's same-layer install, then the
    # worktree's own <layer>_ws/install/local_setup.bash if built (ADR-0012).
    # Canonical colcon overlay precedence — no force-prepend (cf. header note
    # on upstream #427).
    local worktree=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --worktree) worktree="${2:-}"; shift 2 ;;
            *) echo "ERROR: worktree_env: unknown argument '$1'" >&2; return 1 ;;
        esac
    done
    if [ -z "$worktree" ]; then
        echo "ERROR: worktree_env requires --worktree <dir>" >&2
        return 1
    fi
    _rc_require_manifest || return 1
    # The worktrees dir that holds this package worktree must be invisible
    # to colcon, or a build of the hosted instance descends into every
    # issue worktree's own <layer>_ws. An empty COLCON_IGNORE marker in the
    # parent does that. Type-specific, so it lives here, not in the generic
    # worktree helpers (ADR-0012). Idempotent.
    local wt_parent
    wt_parent="$(dirname "$worktree")"
    if [ -d "$wt_parent" ] && [ ! -f "$wt_parent/COLCON_IGNORE" ]; then
        : > "$wt_parent/COLCON_IGNORE" || {
            echo "ERROR: worktree_env: cannot write $wt_parent/COLCON_IGNORE" >&2
            return 1
        }
    fi
    local layer="" ws_dir base
    for ws_dir in "$worktree"/*_ws; do
        [ -d "$ws_dir" ] || continue
        base="$(basename "$ws_dir")"
        layer="${base%_ws}"
        break
    done
    if [ -z "$layer" ]; then
        echo "ERROR: no <layer>_ws directory found under $worktree" >&2
        return 1
    fi
    local underlay; underlay="$(_rc_underlay)" || return 1
    echo "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX"
    printf 'source %q\n' "$underlay"
    # Every conditional source below is emitted as a runtime-guarded line,
    # not skipped when the install doesn't exist yet at *generation* time.
    # env.sh is written once at worktree-create time (before any build); a
    # build-time-only check here would permanently omit the worktree's own
    # install line even after it's built, and test.sh's re-source-after-build
    # would never pick up the fresh overlay.
    #
    # The guard is `if [ -f X ]; then source X; fi`, never `[ -f X ] &&
    # source X`: an `&&` form's exit status is the `[ -f ]` test's own
    # (nonzero) status when the file doesn't exist, and `source env.sh`
    # inherits that as env.sh's *own* exit status when this happens to be
    # the last line generated. Under a caller's `set -e` (an issue shell,
    # or the generated build.sh/test.sh — see _wt_env_last_line_is_safe
    # below), that turns "install not built yet" into an immediate,
    # silent abort of the sourcing script itself. `if/then/fi` with no
    # `else` always exits 0, whichever branch is taken.
    local l layer_dir found_target=false
    while IFS= read -r l; do
        if [ "$l" = "$layer" ]; then
            found_target=true
            break
        fi
        layer_dir="$(_rc_layer_dir "$l")"
        printf 'if [ -f %q ]; then source %q; fi\n' \
            "$layer_dir/install/local_setup.bash" "$layer_dir/install/local_setup.bash"
    done < <(_rc_layers)
    if [ "$found_target" != true ]; then
        echo "ERROR: layer '$layer' (from $worktree) is not defined in layers.txt" >&2
        return 1
    fi
    layer_dir="$(_rc_layer_dir "$layer")"
    printf 'if [ -f %q ]; then source %q; fi\n' \
        "$layer_dir/install/local_setup.bash" "$layer_dir/install/local_setup.bash"
    printf 'if [ -f %q ]; then source %q; fi\n' \
        "$worktree/${layer}_ws/install/local_setup.bash" "$worktree/${layer}_ws/install/local_setup.bash"
    # No trailing `true` crutch: every line this function can ever emit —
    # unset, the underlay source (guaranteed to exist; _rc_underlay already
    # errored out above if not), and every if/then/fi guard — exits 0 on
    # its own regardless of which one ends up last. That is the actual
    # guarantee; test_worktree_env_last_line_never_fails_under_set_e below
    # exercises it end to end (source the real generated output under
    # `set -e` with no install present) rather than trusting this comment.
}

# How YAML's reading changes an unquoted (plain) version: value, or
# nothing when the import tool checks out the text as written. vcstool
# reads .repos with PyYAML's yaml.safe_load (YAML 1.1 implicit resolvers)
# and checks out str() of the value, so a value is refused only when
# YAML's reading changes the text. Prints "<phrase>\t<what str() gives>",
# the second field empty when the shell cannot work it out exactly:
# "the number 1.1\t1.1", "the bool True\tTrue", "a float\t" (a float of
# more digits than this check works out, which may or may not round-trip,
# is refused too, as the rule below keeps only what surely does).
# The patterns are PyYAML's resolvers, written out:
#   bool   yes/no/true/false/on/off, each lower, Capitalised or UPPER;
#          True and False are kept, as str() of the bool is the text
#   null   ~, null/Null/NULL (an empty value is refused before this)
#   int    [-+]0b binary, [-+]0 octal, [-+] decimal, [-+]0x hex and
#          [-+] sexagesimal (1:30), all allowing "_"
#   float  [-+]1.5 / 1. / 1.5e+3, .5, sexagesimal 1:30.5, [-+].inf, .nan
#   indicator  a first character YAML reads as syntax, not text:
#          ! & * | > % @ ` [ ] { } ,  (a tag, anchor, alias, block or flow
#          scalar, directive, reserved, or flow collection)
# Kept, because str() gives the text back: an int written
# ^(0|-?[1-9][0-9]*)$ (Python ints are exact: 2024, -5, an all-digit sha)
# and a float written ^-?(0|[1-9][0-9]*)\.([0-9]*[1-9]|0)$ with at most 15
# significant digits, an integer part of at most 16 digits and no
# "0.0000" start (repr's shortest form is then the text: 2.0, 1.5, 0.3;
# not 1.10, which is 1.1). Any other int or float is refused.
# A timestamp with a time part also changes under str(), but it holds a
# ":" no git ref can, so it is never a branch anyway; a date alone
# (2024-01-01) round-trips. No YAML library: the shell path stays plain.
_rc_yaml_plain_reading() {
    local v="$1" body ip fp digits n
    case "$v" in
        [\!\&\*\|\>%@\`\[\]\{\},]*) printf '%s\t\n' "YAML syntax, not text ('${v:0:1}' starts it)"; return 0 ;;
    esac
    if [[ "$v" =~ ^(yes|Yes|YES|true|TRUE|on|On|ON)$ ]]; then
        printf '%s\t%s\n' "the bool True" True
    elif [[ "$v" =~ ^(no|No|NO|false|FALSE|off|Off|OFF)$ ]]; then
        printf '%s\t%s\n' "the bool False" False
    elif [[ "$v" =~ ^(~|null|Null|NULL)$ ]]; then
        printf '%s\t%s\n' "null" None
    elif [[ "$v" =~ ^(0|-?[1-9][0-9]*)$ ]]; then
        :  # an int str() gives back unchanged
    elif [[ "$v" =~ ^[-+]?0b[01_]+$ ]] || [[ "$v" =~ ^[-+]?0[0-7_]+$ ]] \
        || [[ "$v" =~ ^[-+]?(0|[1-9][0-9_]*)$ ]] || [[ "$v" =~ ^[-+]?0x[0-9a-fA-F_]+$ ]] \
        || [[ "$v" =~ ^[-+]?[1-9][0-9_]*(:[0-5]?[0-9])+$ ]]; then
        # Its value, when bash can work it out exactly; else just "an int".
        body="${v//_/}"
        body="${body#+}"
        n=""
        if [[ "$body" =~ ^-?(0b[01]{1,62}|0x[0-9a-fA-F]{1,15}|0[0-7]{1,20}|[1-9][0-9]{0,17}|0)$ ]]; then
            local sign=""
            [ "${body:0:1}" = "-" ] && { sign="-"; body="${body#-}"; }
            case "$body" in
                0b*) n=$((2#${body#0b})) ;;
                0x*) n=$((16#${body#0x})) ;;
                0?*) n=$((8#${body#0})) ;;
                *) n=$((10#$body)) ;;
            esac
            [ "$n" = 0 ] && sign=""
            n="$sign$n"
        fi
        if [ -n "$n" ]; then
            printf '%s\t%s\n' "the number $n" "$n"
        else
            printf '%s\t\n' "an int"
        fi
    elif [[ "$v" =~ ^-?(0|[1-9][0-9]*)\.([0-9]*[1-9]|0)$ ]] \
        && ip="${v#-}" && ip="${ip%%.*}" && fp="${v#*.}" \
        && [ "${#ip}" -le 16 ] && [[ "$v" != 0.0000* && "$v" != -0.0000* ]] \
        && digits="$ip" && { [ "$fp" = 0 ] || digits="$ip$fp"; } \
        && digits="${digits#"${digits%%[!0]*}"}" && [ "${#digits}" -le 15 ]; then
        :  # a float whose shortest repr is the text
    elif [[ "$v" =~ ^[-+]?[0-9][0-9_]*\.[0-9_]*([eE][-+][0-9]+)?$ ]] \
        || [[ "$v" =~ ^\.[0-9_]+([eE][-+][0-9]+)?$ ]] \
        || [[ "$v" =~ ^[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+\.[0-9_]*$ ]] \
        || [[ "$v" =~ ^[-+]?\.(inf|Inf|INF)$ ]] || [[ "$v" =~ ^\.(nan|NaN|NAN)$ ]]; then
        # A plain decimal within the limits: its repr, trailing zeros off
        # and leading ones (1.10 -> 1.1, +01.50 -> 1.5); else "a float".
        if [[ "$v" =~ ^([-+]?)([0-9]+)\.([0-9]*)$ ]]; then
            local sg="${BASH_REMATCH[1]}"
            ip="${BASH_REMATCH[2]}"
            fp="${BASH_REMATCH[3]}"
            [ "$sg" = "+" ] && sg=""
            ip="${ip#"${ip%%[!0]*}"}"
            ip="${ip:-0}"
            fp="${fp%"${fp##*[!0]}"}"
            fp="${fp:-0}"
            body="$sg$ip.$fp"
            if [[ "$body" =~ ^-?(0|[1-9][0-9]*)\.([0-9]*[1-9]|0)$ ]] \
                && [ "${#ip}" -le 16 ] && [[ "$body" != 0.0000* && "$body" != -0.0000* ]]; then
                digits="$ip"
                [ "$fp" = 0 ] || digits="$ip$fp"
                digits="${digits#"${digits%%[!0]*}"}"
                if [ "${#digits}" -le 15 ]; then
                    printf '%s\t%s\n' "the number $body" "$body"
                    return 0
                fi
            fi
        fi
        case "$v" in
            .inf|.Inf|.INF|+.inf|+.Inf|+.INF) printf '%s\t%s\n' "the float inf" inf ;;
            -.inf|-.Inf|-.INF) printf '%s\t%s\n' "the float -inf" -inf ;;
            .nan|.NaN|.NAN) printf '%s\t%s\n' "the float nan" nan ;;
            *) printf '%s\t\n' "a float" ;;
        esac
    fi
    return 0
}

# The kind of a pinned ref, judged in the package checkout at $1 (which may
# not exist yet): branch, tag, commit or unknown. Online, origin decides:
# refs/heads/<ref> is a branch, refs/tags/<ref> a tag (branch first, since a
# same-named tag does not stop a branch being a base), and a stale
# remote-tracking ref is not enough. When origin cannot be asked (offline,
# or the repo is not cloned), the local refs decide and a NOTE on stderr says
# the answer is unverified. A 40- or 64-hex ref nobody names is a commit.
_rc_pin_kind() {
    local dir="$1" ref="$2" out kind="" toplevel dir_real
    local is_hex=false
    # Either case: git reads an object name case-insensitively.
    [[ "$ref" =~ ^([0-9a-fA-F]{40}|[0-9a-fA-F]{64})$ ]] && is_hex=true
    # A ref git cannot name as a branch or tag is never asked about.
    if ! _rc_nofd git check-ref-format "refs/heads/$ref" >/dev/null 2>&1; then
        if [ "$is_hex" = true ]; then echo commit; else echo unknown; fi
        return 0
    fi
    toplevel=""
    dir_real=""
    if [ -d "$dir" ]; then
        toplevel="$(_rc_nofd git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
        dir_real="$(cd "$dir" && pwd -P)"
    fi
    local cloned=false rc=1 why="could not be reached"
    [ -n "$toplevel" ] && [ "$toplevel" = "$dir_real" ] && cloned=true
    if [ "$cloned" = true ]; then
        # Bounded (#323): a prompt or a stalled host must not hang the
        # caller; a timeout falls to the local answer below.
        rc=0
        out="$(_rc_nofd _adapter_bounded_git -C "$dir" ls-remote origin \
            "refs/heads/$ref" "refs/tags/$ref" 2>/dev/null)" || rc=$?
        if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
            why="did not answer within $(_adapter_git_limit)s"
        fi
    fi
    if [ "$cloned" = true ] && [ "$rc" -eq 0 ]; then
        if awk -F'\t' -v r="refs/heads/$ref" '$2 == r { f = 1 } END { exit !f }' <<< "$out"; then
            kind=branch
        elif awk -F'\t' -v r="refs/tags/$ref" '$2 == r || $2 == r "^{}" { f = 1 } END { exit !f }' <<< "$out"; then
            kind=tag
        fi
    elif [ "$cloned" = true ]; then
        echo "NOTE: repo_pin: origin of $dir $why; the kind of '$ref' comes from local refs (unverified)" >&2
        if _rc_nofd git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$ref"; then
            kind=branch
        elif _rc_nofd git -C "$dir" show-ref --verify --quiet "refs/tags/$ref"; then
            kind=tag
        fi
    else
        echo "NOTE: repo_pin: $dir is not a cloned repository; the kind of '$ref' is not checked against origin (unverified)" >&2
    fi
    if [ -z "$kind" ]; then
        if [ "$is_hex" = true ]; then kind=commit; else kind=unknown; fi
    fi
    echo "$kind"
}

adapter_repo_pin() {
    # <repo> [--layer <l>]: the version: <repo> is pinned at in the
    # manifest's repos/<layer>.repos files, as "<ref>\t<kind>" (ADR-0019).
    # A repo pinned in more than one layer at different refs needs --layer;
    # the same ref in several layers is one answer.
    local repo="" layer=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --layer)
                if [ $# -lt 2 ] || [ -z "$2" ]; then
                    echo "ERROR: repo_pin: --layer requires a layer name" >&2
                    return 1
                fi
                layer="$2"; shift 2 ;;
            -*) echo "ERROR: repo_pin: unknown argument '$1'" >&2; return 1 ;;
            *)
                if [ -n "$repo" ]; then
                    echo "ERROR: repo_pin: one repository name only (got '$repo' and '$1')" >&2
                    return 1
                fi
                repo="$1"; shift ;;
        esac
    done
    if [ -z "$repo" ]; then
        echo "ERROR: repo_pin requires a repository name: repo_pin <repo> [--layer <l>]" >&2
        return 1
    fi
    _rc_require_manifest || return 1
    if [ -n "$layer" ]; then
        local l found=0
        while IFS= read -r l; do
            [ "$l" = "$layer" ] && found=1
        done < <(_rc_layers)
        if [ "$found" -ne 1 ]; then
            echo "ERROR: repo_pin: layer '$layer' is not defined in layers.txt" >&2
            return 1
        fi
    fi
    local mdir l entry name version form
    local -a hits=() known=() forms=()
    # Stands for an entry with no version: key (vcstool then checks out
    # origin's default branch); no ref can hold this byte.
    local nov=$'\x1f'
    mdir="$(_rc_manifest_dir)"
    while IFS= read -r l; do
        [ -n "$layer" ] && [ "$l" != "$layer" ] && continue
        while IFS= read -r entry; do
            [ -z "$entry" ] && continue
            name="${entry%%$'\t'*}"
            form="${entry##*$'\t'}"
            version="${entry#*$'\t'}"
            version="${version%$'\t'*}"
            [ "$form" = none ] && version="$nov"
            known+=("$name")
            if [ "$name" = "$repo" ]; then
                hits+=("$l"$'\t'"$version")
                forms+=("$form")
            fi
        done < <(_rc_repos_entries "$mdir/repos/${l}.repos" --detail)
    done < <(_rc_layers)
    local where="the manifest"
    [ -n "$layer" ] && where="layer '$layer' of the manifest"
    if [ "${#hits[@]}" -eq 0 ]; then
        local list
        list="$(printf '%s\n' ${known[@]+"${known[@]}"} | sort -u | tr '\n' ' ')"
        list="${list% }"
        echo "ERROR: repo_pin: no repository '$repo' pinned in $where (known: ${list:-none})" >&2
        return 1
    fi
    local hit ref="" hit_layer="" differ=false
    for hit in "${hits[@]}"; do
        if [ -z "$hit_layer" ]; then
            hit_layer="${hit%%$'\t'*}"
            ref="${hit#*$'\t'}"
        elif [ "${hit#*$'\t'}" != "$ref" ]; then
            differ=true
        fi
    done
    if [ "$differ" = true ]; then
        local named="" v
        for hit in "${hits[@]}"; do
            v="${hit#*$'\t'}"
            [ "$v" = "$nov" ] && v="no version:"
            named="${named:+$named, }${hit%%$'\t'*} ($v)"
        done
        echo "ERROR: repo_pin: '$repo' is pinned in more than one layer at different refs: $named; pass --layer <l>" >&2
        return 1
    fi
    if [ "$ref" = "$nov" ]; then
        echo "ERROR: repo_pin: '$repo' has no version: key in layer '$hit_layer', so vcstool checks out origin's default branch; repo_pin reports only a pinned ref (add a version: to pin one)" >&2
        return 1
    fi
    if [ -z "$ref" ]; then
        echo "ERROR: repo_pin: '$repo' has an empty version: in layer '$hit_layer'" >&2
        return 1
    fi
    # A quote, backslash or carriage return left in the ref means the line
    # was not read as YAML would read it (an unclosed quote, an escape the
    # parser does not decode, a stray CR): refuse it rather than print a
    # ref nobody pinned.
    if [[ "$ref" == *[\"\'\\$'\r']* ]]; then
        echo "ERROR: repo_pin: '$repo' has a version: in layer '$hit_layer' that cannot be read as a ref (a stray quote, a backslash escape or a carriage return): '$ref'" >&2
        return 1
    fi
    # vcstool checks out str() of the YAML value, so an unquoted pin YAML
    # types as something other than a string is not the ref written
    # (version: 1.10 is the float 1.1). Every layer pinning it is checked.
    local i ytype got
    for i in "${!hits[@]}"; do
        [ "${forms[$i]}" = plain ] || continue
        ytype="$(_rc_yaml_plain_reading "$ref")"
        if [ -n "$ytype" ]; then
            got="${ytype#*$'\t'}"
            ytype="${ytype%%$'\t'*}"
            if [ -n "$got" ]; then
                got="so vcstool would check out '$got', not '$ref'"
            elif [[ "$ytype" == "YAML syntax"* ]]; then
                got="so vcstool would not read '$ref' as a ref"
            else
                got="so vcstool would check out str() of that value, which this check cannot confirm is '$ref'"
            fi
            echo "ERROR: repo_pin: '$repo' has version: $ref in layer '${hits[$i]%%$'\t'*}' unquoted, which YAML reads as $ytype, $got; quote it: version: \"$ref\"" >&2
            return 1
        fi
    done
    # The same ref pinned in several layers: judge it in the first of them
    # whose checkout is cloned, not merely the first, so a layer not set up
    # yet does not turn a known branch into an unverified unknown.
    local kind check_dir d
    check_dir="$(_rc_layer_dir "$hit_layer")/src/$repo"
    for hit in "${hits[@]}"; do
        d="$(_rc_layer_dir "${hit%%$'\t'*}")/src/$repo"
        if [ -e "$d/.git" ]; then
            check_dir="$d"
            break
        fi
    done
    kind="$(_rc_pin_kind "$check_dir" "$ref")"
    printf '%s\t%s\n' "$ref" "$kind"
}

adapter_scope_for_pr() {
    # Walk up from a path to the owning package repo's origin owner/repo.
    # Same URL parsing as single_project (proven by its adapter tests).
    local path="${1:-}"
    if [ -z "$path" ]; then
        echo "ERROR: scope_for_pr requires a path argument" >&2
        return 1
    fi
    # `git -C` needs a directory; a file path (package.xml, a source file)
    # resolves from its parent — found on the real p11-jazzy checkout (#237).
    local dir="$path"
    [ -d "$dir" ] || dir="$(dirname "$dir")"
    local url
    if ! url="$(_rc_nofd git -C "$dir" remote get-url origin 2>/dev/null)"; then
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
