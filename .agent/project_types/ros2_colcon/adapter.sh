# shellcheck shell=bash
# .agent/project_types/ros2_colcon/adapter.sh
# ros2_colcon adapter — layered colcon workspaces (#172 step 6, issue #235).
#
# Hosts a project shaped like rolker/ros2_agent_workspace: ordered colcon
# layers under layers/main/<layer>_ws/, driven by an in-tree manifest at
# configs/manifest/ (layers.txt, optional_layers.txt, repos/<layer>.repos,
# bootstrap.yaml). Manifest-repo formalization is #172 step 4. Two
# routes, the tool route (below) checked first: the adapter reads the
# manifest from the hosting dir on the bootstrap route and from the tool's
# resolved files on the tool route.
#
# The bootstrap route (below) is today's bootstrap.yaml flow. The settings
# keys source, source_ref and source_path are still accepted by
# project_setting.sh but read by no route (the manifest route that read
# them was removed, issue #569; removing the keys is a line of the
# workspace roadmap): a root without .repos-manifest/ whose settings file
# sets source is refused at use, naming the manifest tool's init and the
# `unset` (_rc_refuse_removed_source), and on the tool route validate names
# them as a second record. The manifest tool is the workspace-installed
# repos-manifest (<main checkout>/.venv/bin/repos-manifest, from `make
# install-repos-manifest`; called by CLI only).
# Package worktrees' env.sh is written once at create time.
#
# The tool route (issue 503 part 1), checked first: a root that holds
# .repos-manifest/ is a system directory the manifest tool set up
# (`repos-manifest init --distro-dirs`), and every verb takes this route,
# whatever the settings file sets. The order is _rc_route's: the tool route,
# else the bootstrap route. A
# .repos-manifest/ the adapter cannot use is an error, never another route
# (the bootstrap route would curl a URL). One helper, _rc_tool_unusable,
# says what is wrong as far as the adapter can tell (it is not a
# directory, or a link to nothing; it cannot be read; nothing is resolved
# yet, no directory under .repos-manifest/resolved/; the layout is flat,
# resolved/layers.txt from a set-up without --distro-dirs) and names the
# way out: the tool's sync for nothing resolved; fixing or removing the
# path, then the tool's init --distro-dirs in an empty directory,
# otherwise. Every next step on this route that is the tool's sync is
# written by one helper, _rc_tool_sync_step (`cd <root> && <tool> sync
# [--distro <d>]`), never an adapter verb: registration refuses such a
# root and rolls the project back before anyone could run one, and from
# the root of a system with several distros the adapter's sync refuses.
# Every key line of a resolved .repos file that the adapter's reader
# (_rc_repos_entries) cannot read is refused by name; it reads a key of
# letters, digits, '.', '_' and '-', bare or in the single quotes the tool
# writes around a key YAML would read as a number or a boolean ('123',
# 'on'). A key with a directory in it (grp/repo) is not read (a worktree
# names a repo by the last part of its path; reading such keys is a later
# part): every verb that reads the resolved .repos files refuses it, build
# alone does not, since the tool's build reads them itself.
# The adapter reads only the tool's resolved files, its stated output, for
# one distro: .repos-manifest/resolved/<distro>/ holds layers.txt (in build
# order; the unnamed layer is "_unnamed"), <layer>.repos and optional.txt
# (the optional repos, by key). It never reads config.yaml or state.yaml;
# what they and the manifest say reaches it through the tool's commands
# (status for validate, build). A layer's directory is
# <root>/<distro>/<layer>, the unnamed layer's <root>/<distro>; its repos
# are in its src/. A repo's pin is the version of its entry in
# <layer>.repos. No layer is optional; an optional repo is status's to
# report (validate does not fail on it).
#
# The distro on the tool route (owner, 2026-11-18: "the directory the
# session is started in decides"), chosen by _rc_tool_distro_select alone:
#   1. the directory the call comes from (ACTIVE_PROJECT_FROM: --from, else
#      the cwd, taken as a physical path) is <root>/<x> or below it, where
#      <x> is a real directory (not a link) directly under the physical
#      root, other than
#      worktrees and names starting with a dot: x, and only x. The adapter
#      does not read the tool's settings, so a directory there that is not
#      a distro is taken as one and refused below: a wrong distro chosen
#      silently is worse than a refusal (one with nothing under resolved/
#      is refused as not a distro the tool resolved).
#   2. otherwise (the root itself, <root>/worktrees/..., outside the root):
#      the one distro under resolved/ (a directory resolved/<d>/, or one
#      the tool set aside while replacing it, .<d>.new-* or .<d>.old-*,
#      which counts as d with no usable resolve), when there is exactly one;
#   3. otherwise refuse, listing them; except `validate`, which then checks
#      every one, one after another, and fails if any fails, naming it (so
#      registration's gate, run from the workspace, passes on a root with
#      several distros).
# The chosen distro's resolved/<d>/layers.txt is read once per call
# (_rc_tool_read_layers), and every layer loop of the call goes over that
# read; a missing file or one that lists no layer is refused, naming the
# tool's sync for d, never answered from another distro. `setup` and
# `sync` choose by the same steps without reading it (they make it).
# Which distros a call covers is decided there too (its --every).
# Every verb follows it; nothing in the registry or the settings file holds
# the distro, and validate refuses a role=, distro=, source, source_ref,
# source_path or bootstrap_url there (a second record beside the tool's).
# The distro's name is the ROS distribution's (/opt/ros/<distro>).
#
# On the tool route `setup` and `sync` run the tool's sync in the root
# (<main checkout>/.venv/bin/repos-manifest sync --distro <d>: --distro <x>
# from inside <root>/<x>/, from elsewhere the one resolved distro's name;
# with no --distro only from outside every distro's directory when nothing
# is resolved yet) and pass its output and exit
# status through. The adapter itself pulls, fetches and moves no clone
# here; the tool's sync clones what is missing and updates a clean clone
# by the rules of its own design, and leaves one with local work.
# `build` runs the tool's build (<tool> build --distro <d> -- <the
# adapter's colcon flags> <the caller's arguments>) in the root, with the
# distro's environment sourced first (_rc_tool_build); the tool builds the
# layers in order over the repos on disk and writes
# <root>/<distro>/setup.bash. It takes no layer argument: one layer is
# built with the tool directly. `test` stays the adapter's colcon loop
# (the tool has no test), each layer given the resolved repos on disk as
# --base-paths, as the tool's build gives them. `validate` reads the
# tool's `status --json` (_rc_tool_status). `env` sources each built
# layer's install/local_setup.bash, which the tool's colcon writes there.
#
# A new root from a manifest (issue 503 part 2): `setup --manifest <file>
# --distro <d> [--role <r>] [--with <group>]... [--fetch-from <prefix>]`
# runs the tool's init --distro-dirs --yes in a root that is not set up
# yet, making the root when missing (_rc_setup_from_manifest);
# registration with --manifest calls it. Nothing about the manifest is
# kept outside the tool's .repos-manifest/.
#
# Fresh hosting dir (#237, step 6 phase 2): `setup` bootstraps the manifest
# when configs/manifest is absent, porting ros2's setup_layers.sh flow
# non-interactively. The bootstrap URL (a remote bootstrap.yaml) resolves
# from BOOTSTRAP_URL in the environment, the project's bootstrap_url
# setting (.agent/projects.d/<name>, issue #332), or
# configs/project_bootstrap.url in the hosting dir (see _rc_bootstrap_url).
# bootstrap.yaml fields: git_url, branch (required); layer (Pattern B —
# clone into layers/main/<layer>_ws/src/<repo>; absent = Pattern A —
# configs/manifest_repo/<repo>); config_path (default "config").
#
# The settings file is the project's only source of commands and URLs:
# issue #265 part 4 retired the legacy .agent/projects.d/<name>.sh and the
# shared .agent/project_config.sh, which nothing here reads. An install=
# command runs without a shell, so nothing a config file exported (an SDK
# path, PATH) reaches it: environment setup belongs in the script the key
# points at.
#
# Distro handling on the bootstrap route (new capability —
# the ros2 scripts hardcoded jazzy; the tool route's rule is above):
#   1. distro=<name> on the project's registry line
#   2. `distro:` field in configs/manifest/bootstrap.yaml (the two must
#      agree when both are set)
#   3. otherwise: error. No silent default.
# ROS_ROOT_DIR in the process environment (default /opt/ros) locates the
# distro underlay: the one value this adapter reads from the environment,
# set only by tests and non-standard installs.
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

_rc_root() {
    # The registry hosting dir the dispatcher resolved; no default (issue
    # #265 part 4 retired project/).
    if [ -z "${ACTIVE_PROJECT_ROOT:-}" ]; then
        echo "ERROR: no project selected (select one: --project <name>)" >&2
        return 1
    fi
    echo "$ACTIVE_PROJECT_ROOT"
}

# The manifest directory every verb reads: configs/manifest on the
# bootstrap route; on the tool route .repos-manifest/resolved/<distro>,
# for the distro _rc_tool_distro_select chose (_rc_require_manifest runs
# it).
_rc_manifest_dir() {
    if [ "$(_rc_route)" = tool ]; then
        if [ -z "${_RC_TOOL_DISTRO:-}" ]; then
            echo "ERROR: internal: the tool route's distro was not chosen before its resolved files were read" >&2
            return 1
        fi
        echo "$(_rc_root)/.repos-manifest/resolved/$_RC_TOOL_DISTRO"
        return 0
    fi
    echo "$(_rc_root)/configs/manifest"
}

# Run a program without the variables that tell git which repository to
# use (_rc_git_local_vars): git sets GIT_DIR, GIT_INDEX_FILE and the like
# for every hook, and a `git -C <dir>` would still act on the repository
# they name.
_rc_nofd() {
    _rc_git_local_vars
    ( unset $_RC_GIT_LOCAL_VARS; "$@" )
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
    more="$( unset $floor; git rev-parse --local-env-vars 2>/dev/null )" || more=""
    _RC_GIT_LOCAL_VARS="$(printf '%s\n' $floor $more | grep -vx -e GIT_CONFIG_PARAMETERS -e GIT_CONFIG_COUNT | LC_ALL=C sort -u | tr '\n' ' ')"
}

# Require the manifest dir (dir or resolving symlink) with at least one
# layer defined. Errors with guidance — an empty layers.txt must not let
# the layer loops run zero times and report success. A `source` set off
# the tool route is refused first (_rc_refuse_removed_source).
_rc_require_manifest() {
    _rc_refuse_removed_source || return 1
    # The tool route: the distro rule first (it refuses a root the adapter
    # cannot use, naming the next step).
    if [ "$(_rc_route)" = tool ]; then
        _rc_tool_distro_select || return 1
    fi
    _rc_check_manifest
}

# _rc_require_manifest's checks once the distro is chosen (validate runs
# them for each distro it covers). A repo key the reader cannot read is
# refused at the end, once the layer names are checked.
_rc_check_manifest() {
    local mdir
    mdir="$(_rc_manifest_dir)"
    # The tool route: the chosen distro's layers.txt, read here once for
    # the call, an empty read refused (the file is not looked at again).
    if [ "$(_rc_route)" = tool ]; then
        _rc_tool_read_layers || return 1
    elif [ ! -d "$mdir" ] || [ ! -f "$mdir/layers.txt" ]; then
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
    if [ "$(_rc_route)" = tool ]; then
        _rc_tool_refuse_unread_keys || return 1
    fi
}

# Ordered layer names from layers.txt (comments/blanks stripped, whitespace
# trimmed — a stray trailing space must not produce a "<layer> _ws" path).
_rc_layers() {
    local mdir
    # The tool route: the one read of the call (_rc_tool_read_layers).
    if [ "$(_rc_route)" = tool ]; then
        [ -n "${_RC_TOOL_LAYERS:-}" ] && printf '%s\n' "$_RC_TOOL_LAYERS"
        return 0
    fi
    mdir="$(_rc_manifest_dir)"
    grep -v '^[[:space:]]*#' "$mdir/layers.txt" 2>/dev/null \
        | grep -v '^[[:space:]]*$' \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

# True if the layer is listed in optional_layers.txt. The tool route has
# no optional layers (its optional repos are _rc_is_optional_repo's).
_rc_is_optional_layer() {
    local layer="$1" mdir
    [ "$(_rc_route)" = tool ] && return 1
    mdir="$(_rc_manifest_dir)"
    [ -f "$mdir/optional_layers.txt" ] || return 1
    grep -v '^[[:space:]]*#' "$mdir/optional_layers.txt" 2>/dev/null \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
        | grep -qx "$layer"
}

# Tool route only: true if the resolved optional.txt names the repo key.
_rc_is_optional_repo() {
    local key="$1" mdir
    mdir="$(_rc_manifest_dir)" || return 1
    [ -f "$mdir/optional.txt" ] || return 1
    grep -v '^[[:space:]]*#' "$mdir/optional.txt" 2>/dev/null \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
        | grep -qxF -- "$key"
}

# The directory a layer is built in, its repos in src/ below it:
# layers/main/<layer>_ws on the bootstrap route;
# <root>/<distro>/<layer> on the tool route, and <root>/<distro> for the
# unnamed layer, "_unnamed" in the tool's layers.txt.
_rc_layer_dir() {
    if [ "$(_rc_route)" = tool ]; then
        if [ "$1" = _unnamed ]; then
            echo "$(_rc_root)/${_RC_TOOL_DISTRO:?}"
        else
            echo "$(_rc_root)/${_RC_TOOL_DISTRO:?}/$1"
        fi
        return 0
    fi
    echo "$(_rc_root)/layers/main/${1}_ws"
}

# A layer's .repos file: <layer>.repos in the tool's resolved directory,
# repos/<layer>.repos in the manifest directory on the bootstrap route.
_rc_repos_file() {
    local mdir
    mdir="$(_rc_manifest_dir)" || return 1
    if [ "$(_rc_route)" = tool ]; then
        echo "$mdir/${1}.repos"
    else
        echo "$mdir/repos/${1}.repos"
    fi
}

# Resolve the ROS distro: the registry's distro= field first (#265), then
# the manifest, then config. A registry distro that contradicts the
# manifest is a hard error — two sources of truth must never disagree
# silently. ROS_DISTRO in the per-project config is a pure fallback: it is
# not consulted (and not compared) once the registry or manifest resolved
# the distro. Errors loudly.
_rc_distro() {
    local mdir distro="" manifest_distro=""
    # The tool route: the distro _rc_tool_distro_select chose (run here
    # when no verb has run it yet; within $(...) its choice is not kept).
    if [ "$(_rc_route)" = tool ]; then
        if [ -z "${_RC_TOOL_DISTRO:-}" ]; then
            _rc_tool_distro_select || return 1
        fi
        echo "$_RC_TOOL_DISTRO"
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
        echo "ERROR: cannot resolve the ROS distro for this project." >&2
        echo "Declare it in one of:" >&2
        echo "  .agent/projects.local            distro=<name> on the project's line" >&2
        echo "  $mdir/bootstrap.yaml            distro: <name>" >&2
        return 1
    fi
    if ! [[ "$distro" =~ ^[a-z0-9_]+$ ]]; then
        echo "ERROR: invalid ROS distro name '$distro'" >&2
        return 1
    fi
    echo "$distro"
}

# Root under which distro underlays live: ROS_ROOT_DIR from the process
# environment, default /opt/ros (issue #265 part 4: it has no settings key,
# and the config file that used to set it is no longer read). Only tests
# and non-standard installs set it.
_rc_ros_root() {
    echo "${ROS_ROOT_DIR:-/opt/ros}"
}

# Path to the distro's setup.bash; errors if missing.
_rc_underlay() {
    local distro ros_root underlay
    distro="$(_rc_distro)" || return 1
    ros_root="$(_rc_ros_root)" || return 1
    underlay="$ros_root/$distro/setup.bash"
    if [ ! -f "$underlay" ]; then
        echo "ERROR: ROS underlay not found: $underlay" >&2
        echo "Install ROS 2 '$distro' (or set ROS_ROOT_DIR in the environment to the directory that holds it)." >&2
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
# On the tool route a key in single quotes is read too, unquoted: the tool
# writes a key YAML would read as a number or a boolean so ('123', 'on').
_rc_repos_entries() {
    local repos_file="$1" detail=0 quoted=0
    [ "${2:-}" = "--detail" ] && detail=1
    [ "$(_rc_route)" = tool ] && quoted=1
    [ -f "$repos_file" ] || return 0
    awk -v detail="$detail" -v quoted="$quoted" '
        function flush() {
            if (name != "" && detail) printf "%s\t\tnone\n", name
            name = ""
        }
        /^[[:space:]]*#/ { next }
        /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ || (quoted && /^  \047[A-Za-z0-9_.-]+\047:[[:space:]]*$/) {
            flush()
            name = $1; sub(/\r$/, "", name); sub(/:$/, "", name)
            gsub(/\047/, "", name)
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

# Resolve the bootstrap URL (remote bootstrap.yaml). Priority: BOOTSTRAP_URL
# env (a per-invocation override), bootstrap_url in the per-project
# settings file .agent/projects.d/<name> (the dispatcher's
# ACTIVE_PROJECT_BOOTSTRAP_URL, issue #332), then the hosting dir's
# configs/project_bootstrap.url. MANIFEST_BOOTSTRAP_URL in a retired config
# file is not read (issue #265 part 4).
# Never prompts — the adapter runs under make and in CI.
_rc_bootstrap_url() {
    local url="" url_file
    url="$(printf '%s' "${BOOTSTRAP_URL:-}" | tr -d '[:space:]')"
    [ -z "$url" ] && url="${ACTIVE_PROJECT_BOOTSTRAP_URL:-}"
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
        echo "  $root/configs/project_bootstrap.url" >&2
        echo "Or set the root up with the manifest tool: in $root, run $(_rc_resolver_bin) init <manifest> --distro-dirs --distro <distro> [--role <role>]; the adapter then takes it as a root the tool set up" >&2
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

# The route, chosen here alone (see the header): "tool" when the root holds
# .repos-manifest/ (a link included, even a dangling one, as the tool
# itself finds it), else "bootstrap". The settings file's source keys
# choose no route (_rc_refuse_removed_source). Pure: it prints the route
# and nothing else, as it is called inside $(...).
_rc_route() {
    if [ -n "${ACTIVE_PROJECT_ROOT:-}" ] \
        && { [ -e "$ACTIVE_PROJECT_ROOT/.repos-manifest" ] || [ -L "$ACTIVE_PROJECT_ROOT/.repos-manifest" ]; }; then
        echo tool
        return 0
    fi
    echo bootstrap
}

# A settings file that sets `source` on a root without .repos-manifest/ is
# refused, never taken down the bootstrap route: the route `source`
# selected (a manifest resolved from it by the adapter) is removed (issue
# #569). The message names the way on: the manifest tool's
# init --distro-dirs in the root (it needs a manifest that lists distros:,
# and reads a local file only, so a URL source is cloned at source_ref
# first and init given the file at source_path, manifest.yaml when unset,
# inside the clone, which the tool never fetches: the message says it is
# updated by hand), that init leaves the removed route's checkouts
# (layers/main/<layer>_ws/src) and generated directories
# (configs/manifest-resolved*) unread when the root holds them, then the
# `unset` of the old keys, and the design's section that holds the
# detail (docs/manifest/design.md, "A root that sets source"). Run first by every
# verb that reads the manifest (_rc_require_manifest) and by setup and
# sync, before anything is fetched. On the tool route the keys are
# validate's to name (_rc_tool_validate: a second record). setup and sync
# pass the route they read once ($1), so the refusal and the branch they
# take answer from one reading (issue 599); with none, it is read here.
_rc_refuse_removed_source() {
    local name root init line="" route="${1:-}"
    [ -n "${ACTIVE_PROJECT_SOURCE:-}" ] || return 0
    [ -n "$route" ] || route="$(_rc_route)"
    [ "$route" = tool ] && return 0
    name="$(_rc_name)"
    root="$(_rc_root)" || return 1
    # The registry line's distro and role, when it has them, else
    # placeholders; the line's fields are then a second record to remove.
    init="$(_rc_resolver_bin) init <manifest> --distro-dirs --distro ${ACTIVE_PROJECT_DISTRO:-<distro>}"
    if [ -n "${ACTIVE_PROJECT_ROLE:-}" ]; then
        init="$init --role $ACTIVE_PROJECT_ROLE"
    else
        init="$init [--role <role>]"
    fi
    [ -n "${ACTIVE_PROJECT_ROLE:-}" ] && line="role="
    [ -n "${ACTIVE_PROJECT_DISTRO:-}" ] && line="${line:+$line and }distro="
    echo "ERROR: project '$name' sets source in ${ACTIVE_PROJECT_FILE:-its settings file}, and $root holds no .repos-manifest/: source no longer selects a route (the route it selected is removed); a manifest in the new format is read only from a root the manifest tool set up" >&2
    echo "Set the root up with the manifest tool, from a manifest that lists its distros (the adapter refuses a root set up without --distro-dirs): in $root, run $init" >&2
    if [[ "$ACTIVE_PROJECT_SOURCE" =~ ^(https?|file):// ]]; then
        # The git form: the tool reads the file from its repo at every sync.
        local git_form="$ACTIVE_PROJECT_SOURCE"
        [ -n "${ACTIVE_PROJECT_SOURCE_REF:-}" ] && git_form="$git_form --manifest-ref $ACTIVE_PROJECT_SOURCE_REF"
        git_form="$git_form --manifest-path ${ACTIVE_PROJECT_SOURCE_PATH:-manifest.yaml}"
        echo "For this URL source, init reads the manifest from its repo, afresh at every sync, so no clone is kept by hand: in $root, run ${init/"<manifest>"/"$git_form"}" >&2
        if [[ "${ACTIVE_PROJECT_SOURCE_REF:-}" =~ ^[0-9a-fA-F]{40}$ ]]; then
            echo "source_ref is a commit, and the tool reads a manifest at a branch or a tag only, not yet at a commit: give --manifest-ref a branch or tag that holds it" >&2
        fi
    fi
    if [ -d "$root/layers/main" ] || [ -e "$root/configs/manifest-resolved" ] || [ -L "$root/configs/manifest-resolved" ]; then
        echo "init does not read the old checkouts under $root/layers/main/<layer>_ws/src or $root/configs/manifest-resolved*: it clones again under $root/<distro>/, so push work in them first" >&2
    fi
    echo "Then remove the old keys: .agent/scripts/project_setting.sh unset $name source source_ref source_path${line:+, and $line from its line in .agent/projects.local}" >&2
    echo "Or set the instance up in a new, empty directory and register it in one step, registering <dir> with --manifest <file> --distro ${ACTIVE_PROJECT_DISTRO:-<distro>}${ACTIVE_PROJECT_ROLE:+ --role $ACTIVE_PROJECT_ROLE}" >&2
    echo "More in docs/manifest/design.md, under \"A root that sets source\"" >&2
    return 1
}

# --- Tool route (issue 503 part 1; see the header) -------------------------

# The distros under the tool's resolved/: each directory resolved/<d>/,
# and each the tool has set aside while replacing it, named as the tool's
# output.py names them (_TEMP_NAME: .<d>.new-<pid>-<8 of [a-z0-9_]> or
# .<d>.old-...), counted as d; other dot names left out. In name order,
# one per line. Whether one is usable is _rc_tool_read_layers's question,
# not this list's (a set-aside one with no resolved/<d>/ is not).
_rc_tool_distros() {
    local d res restore
    local -a names
    res="$(_rc_root)/.repos-manifest/resolved"
    # Set-aside names first, and every name a glob returned counts even if gone since: a sync's
    # swap of <d> during the call lists <d>, unless the first glob ran before the sync wrote its new copy.
    restore="$(shopt -p nullglob)" || true  # exit 1 when unset
    shopt -s nullglob
    names=("$res"/.*/ "$res"/*/)
    eval "$restore"
    for d in ${names[@]+"${names[@]}"}; do
        d="${d%/}"
        d="${d##*/}"
        if [[ "$d" == .* ]]; then
            [[ "$d" =~ ^\.(.+)\.(new|old)-[0-9]+-[a-z0-9_]{8}$ ]] || continue
            d="${BASH_REMATCH[1]}"
        fi
        echo "$d"
    done | sort -u
}

# The next step when it is the manifest tool's sync, written here alone
# for every message on the tool route: the command as it can be run from
# anywhere, `cd <root> && <tool> sync`, with --distro <d> when $1 names
# the distro. The tool is the workspace's installed one.
_rc_tool_sync_step() {
    printf 'cd %q && %q sync' "$(_rc_root)" "$(_rc_resolver_bin)"
    [ -n "${1:-}" ] && printf ' --distro %q' "$1"
    return 0
}

# A .repos-manifest/ the adapter cannot use (see the header), refused in
# one place: what is wrong ($1), and the way out ($2): sync, the tool's
# sync (nothing resolved yet); init, a new set-up with the tool's init
# --distro-dirs in an empty directory (a flat layout); repair, the
# default, fixing the path or removing it and setting up again so (it is
# not a directory, a link to nothing, or cannot be read: the tool's sync
# would refuse it too). Returns 1.
_rc_tool_unusable() {
    local root bin what="$1" step="${2:-repair}" init
    root="$(_rc_root)" || return 1
    bin="$(_rc_resolver_bin)"
    init="set it up again in an empty directory: cd <dir> && $bin init <manifest> --distro-dirs --distro <distro> [--role <role>]; then register that directory"
    echo "ERROR: $root/.repos-manifest $what, so the adapter cannot read what the manifest tool set up there" >&2
    case "$step" in
        sync) echo "Run the manifest tool in the root: $(_rc_tool_sync_step) (then register it, or run the call again)" >&2 ;;
        init) echo "Move $root aside and $init" >&2 ;;
        *) echo "Fix $root/.repos-manifest, the directory the manifest tool made there; or remove it, move $root aside and $init" >&2 ;;
    esac
    return 1
}

# The chosen distro's layers.txt, read once for the call into
# _RC_TOOL_LAYERS (what _rc_layers gives on the tool route). A file that
# is missing or lists no layer is refused, naming the tool's sync for the
# distro: the call never moves on to another distro. Returns 1 then.
_rc_tool_read_layers() {
    local file
    file="$(_rc_manifest_dir)/layers.txt" || return 1
    _RC_TOOL_LAYERS="$(_rc_layer_lines "$file" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$_RC_TOOL_LAYERS" ] && return 0
    if ! _rc_tool_distros | grep -qxF "$_RC_TOOL_DISTRO"; then
        local root d list=""
        root="$(_rc_root)"
        while IFS= read -r d; do
            list="${list:+$list, }$root/$d"
        done < <(_rc_tool_distros)
        echo "ERROR: $_RC_TOOL_DISTRO is not a distro the manifest tool has resolved in $root (nothing under $root/.repos-manifest/resolved/ for it)" >&2
        echo "Run the command from $root or from inside a distro's directory (${list:-none resolved yet}); if $_RC_TOOL_DISTRO is a distro being added, run: $(_rc_tool_sync_step "$_RC_TOOL_DISTRO")" >&2
        return 1
    fi
    echo "ERROR: the manifest tool's last resolve for distro $_RC_TOOL_DISTRO cannot be used: $file is missing or lists no layer (a sync cut short, or one running now)" >&2
    echo "Run: $(_rc_tool_sync_step "$_RC_TOOL_DISTRO")" >&2
    return 1
}

# The distro rule (the header's three steps), in one place: sets
# _RC_TOOL_DISTRO, or refuses, naming the next step. Run outside a
# subshell so the choice holds for the rest of the run. Which distros a
# call covers is decided here too: with --every (validate), when steps 1
# and 2 choose none, _RC_TOOL_DISTROS is every distro under resolved/ and
# _RC_TOOL_DISTRO is left empty for the caller to set to each in turn;
# with --sync (setup and sync), nothing under resolved/ chooses none (the
# tool's sync then syncs every distro it recorded); otherwise
# _RC_TOOL_DISTROS is the one chosen. Nothing here reads a layers.txt
# (_rc_check_manifest does, through _rc_tool_read_layers).
_rc_tool_distro_select() {
    local root resolved d x real from list mode="${1:-}"
    local -a distros=()
    _RC_TOOL_DISTRO=""
    _RC_TOOL_DISTROS=()
    root="$(_rc_root)" || return 1
    resolved="$root/.repos-manifest/resolved"
    if [ -L "$root/.repos-manifest" ] && [ ! -e "$root/.repos-manifest" ]; then
        _rc_tool_unusable "is a link to nothing"
        return 1
    fi
    if [ ! -d "$root/.repos-manifest" ]; then
        _rc_tool_unusable "is not a directory"
        return 1
    fi
    if [ ! -r "$root/.repos-manifest" ] || [ ! -x "$root/.repos-manifest" ] \
        || { [ -e "$resolved" ] && { [ ! -d "$resolved" ] || [ ! -r "$resolved" ] || [ ! -x "$resolved" ]; }; }; then
        _rc_tool_unusable "cannot be read (it or its resolved/ is not a readable directory)"
        return 1
    fi
    if [ -f "$resolved/layers.txt" ]; then
        _rc_tool_unusable "has a flat layout (it was set up without --distro-dirs: $resolved/layers.txt); the adapter reads a system with a directory per distro only" init
        return 1
    fi
    # 1. The calling directory, both sides physical, inside a real
    # directory <root>/<x>/ (not a link): x and only x.
    from="${ACTIVE_PROJECT_FROM:-}"
    real="$(cd "$root" 2>/dev/null && pwd -P)" || real=""
    if [ -n "$from" ] && [ -n "$real" ]; then
        for x in "$real"/*/; do
            x="${x%/}"
            [ "${x##*/}" = worktrees ] || [ -L "$x" ] && continue
            if [ "$from" = "$x" ] || [[ "$from" == "$x"/* ]]; then
                _RC_TOOL_DISTRO="${x##*/}"
                break
            fi
        done
    fi
    if [ -z "$_RC_TOOL_DISTRO" ]; then
        while IFS= read -r d; do
            [ -n "$d" ] && distros+=("$d")
        done < <(_rc_tool_distros)
        # 2. The one distro under resolved/.
        if [ "${#distros[@]}" -eq 1 ]; then
            _RC_TOOL_DISTRO="${distros[0]}"
        elif [ "${#distros[@]}" -eq 0 ]; then
            [ "$mode" = --sync ] && return 0
            _rc_tool_unusable "holds nothing resolved for any distro yet (no directory under $resolved/)" sync
            return 1
        fi
    fi
    # 3. Several, and the calling directory in none of them: validate
    # covers every one; any other call is refused.
    if [ -z "$_RC_TOOL_DISTRO" ]; then
        if [ "$mode" = --every ]; then
            for d in "${distros[@]}"; do
                if ! [[ "$d" =~ ^[a-z0-9_]+$ ]]; then
                    echo "ERROR: invalid ROS distro name '$d' (from $resolved/$d)" >&2
                    _RC_TOOL_DISTROS=()
                    return 1
                fi
            done
            _RC_TOOL_DISTROS=("${distros[@]}")
            return 0
        fi
        list="$(printf '%s, ' "${distros[@]}")"
        echo "ERROR: $root holds several distros (${list%, }), and the call comes from ${from:-an unknown directory}, which is in none of them; the directory a call comes from chooses the distro" >&2
        echo "Run the command from inside $root/<distro>/ (a call to .agent/scripts/adapter itself may instead give its own --from $root/<distro> before the verb)" >&2
        return 1
    fi
    if ! [[ "$_RC_TOOL_DISTRO" =~ ^[a-z0-9_]+$ ]]; then
        echo "ERROR: invalid ROS distro name '$_RC_TOOL_DISTRO' (the directory $root/$_RC_TOOL_DISTRO, or $resolved/$_RC_TOOL_DISTRO)" >&2
        _RC_TOOL_DISTRO=""
        return 1
    fi
    _RC_TOOL_DISTROS=("$_RC_TOOL_DISTRO")
}

# Every key line (two spaces in, under repositories:) of a resolved .repos
# file of the chosen distro that the adapter's reader, _rc_repos_entries,
# cannot read is refused by name, so none is passed over without a word.
# A key with a directory in it (grp/repo) is one such line: the adapter's
# own reading of .repos files, `repos` and worktree_create.sh take a repo
# by one directory name. The pattern is the reader's.
_rc_tool_refuse_unread_keys() {
    local layer file keys found=""
    while IFS= read -r layer; do
        file="$(_rc_repos_file "$layer")" || return 1
        [ -f "$file" ] || continue
        keys="$(awk '
            /^[[:space:]]*#/ { next }
            /^  [^ ]/ {
                k = $0
                sub(/\r$/, "", k)
                if (k ~ /^  [A-Za-z0-9_.-]+:[[:space:]]*$/) next
                if (k ~ /^  \047[A-Za-z0-9_.-]+\047:[[:space:]]*$/) next
                sub(/^  /, "", k)
                sub(/[[:space:]]+$/, "", k)
                sub(/:$/, "", k)
                print k
            }' "$file")"
        [ -n "$keys" ] && found="${found:+$found; }$layer: $(tr '\n' ' ' <<< "$keys" | sed 's/ $//')"
    done < <(_rc_layers)
    [ -z "$found" ] && return 0
    echo "ERROR: a repo key line the adapter does not read ($found, in $(_rc_manifest_dir)); it reads a key of letters, digits, '.', '_' and '-', bare or in single quotes (a key with a directory in it, such as grp/repo, is not read yet)" >&2
    echo "Name each such repo so in the manifest and run: $(_rc_tool_sync_step "$_RC_TOOL_DISTRO"); or work in this system with repos-manifest by hand" >&2
    return 1
}

# `setup` and `sync` on the tool route: the tool's sync in the root, its
# output and exit status passed through (0; 1 when a repo that is not
# optional failed, or on a refusal; 128+n on a signal). Nothing else: no
# pull, fetch or vcs of the adapter's own. The distro is the rule's (its
# --sync: no resolve needed); with nothing resolved (a resolve the tool set
# aside counts as resolved) and the call from no distro's directory (an
# init cut short), sync runs with no --distro and
# the tool syncs every distro it recorded.
_rc_tool_sync() {
    local root bin before="" after="" rc=0
    local -a args=()
    root="$(_rc_root)" || return 1
    bin="$(_rc_resolver_bin)"
    if [ ! -x "$bin" ]; then
        echo "ERROR: the manifest tool is not installed at $bin; run: make install-repos-manifest (from the workspace main checkout)" >&2
        return 1
    fi
    _rc_tool_distro_select --sync || return 1
    if [ -n "$_RC_TOOL_DISTRO" ]; then
        args=(--distro "$_RC_TOOL_DISTRO")
        before="$(_rc_layer_lines "$(_rc_manifest_dir)/layers.txt")"
    fi
    echo "Running: $bin sync ${args[*]} (in $root)"
    (cd "$root" && _rc_nofd "$bin" sync ${args[@]+"${args[@]}"}) || rc=$?
    if [ -n "$_RC_TOOL_DISTRO" ]; then
        after="$(_rc_layer_lines "$(_rc_manifest_dir)/layers.txt")"
        if [ "$after" != "$before" ]; then
            echo "repos-manifest: the layers of distro $_RC_TOOL_DISTRO changed; existing package worktrees keep their old env.sh; recreate them"
        fi
    fi
    return "$rc"
}

# The reader of `repos-manifest status --json` (format 1), run by the
# tool's own interpreter (_rc_tool_status), standard library only. Its
# argument is the distro asked for; it prints one line per item, fields
# separated by \x1f (a tab, a newline, a carriage return or \x1f inside a
# value becomes a space; a byte that is not UTF-8, which the tool writes as
# a lone surrogate, becomes \xXX as the tool's own show prints it, and any
# other lone surrogate \uXXXX, so no line is lost to an encoding error):
#   bad  <why>                     no document, or not one the adapter reads
#   head <document ok 0|1> <distro ok 0|1> <the distro's problem, or empty>
#   repo <layer> <key> <state> <optional 0|1> <path> <changed files>
#        <unpushed commits> <detail>
#   gone <key> <path>              a not_in_manifest entry
_RC_STATUS_READER='
import json, sys
SEP = "\x1f"
sys.stdout.reconfigure(errors="backslashreplace")
def unpaired(ch):
    c = ord(ch)
    if 0xDC80 <= c <= 0xDCFF:
        return "\\x%02x" % (c - 0xDC00)
    if 0xD800 <= c <= 0xDFFF:
        return "\\u%04x" % c
    return ch
def text(v):
    if v is None:
        return ""
    s = "".join(unpaired(ch) for ch in str(v))
    for ch in ("\t", "\n", "\r", SEP):
        s = s.replace(ch, " ")
    return s
def count(v):
    return str(v) if isinstance(v, int) and not isinstance(v, bool) and v > 0 else "0"
def out(*fields):
    print(SEP.join(fields))
def flag(v):
    return "1" if v is True else "0"
want = sys.argv[1]
raw = sys.stdin.read()
if not raw.strip():
    out("bad", "gave no document")
    sys.exit(0)
try:
    doc = json.loads(raw)
except ValueError as exc:
    out("bad", "printed something that is not one JSON document (" + text(exc) + ")")
    sys.exit(0)
if not isinstance(doc, dict):
    out("bad", "printed JSON that is not one object")
    sys.exit(0)
fmt = doc.get("format")
if not isinstance(fmt, int) or isinstance(fmt, bool) or fmt != 1:
    out("bad", "printed a document of format " + text(fmt) + "; the adapter reads format 1")
    sys.exit(0)
distros = doc.get("distros")
mine = [d for d in distros if isinstance(d, dict) and d.get("distro") == want] if isinstance(distros, list) else []
if len(mine) != 1:
    out("bad", "printed a document without one entry for distro " + text(want))
    sys.exit(0)
entry = mine[0]
repos = entry.get("repos")
gone = entry.get("not_in_manifest")
if entry.get("problem") in (None, "") and (repos is None or gone is None):
    missing = [n for n, v in (("repos", repos), ("not_in_manifest", gone)) if v is None]
    out("bad", "printed a malformed document: the entry for distro " + text(want) + " has no problem and no "
        + " or ".join(missing) + " list")
    sys.exit(0)
if repos is None:
    repos = []
if gone is None:
    gone = []
if not isinstance(repos, list) or not isinstance(gone, list) or not all(isinstance(r, dict) for r in repos + gone):
    out("bad", "printed a document whose repos or not_in_manifest for distro " + text(want) + " is not a list of objects")
    sys.exit(0)
out("head", flag(doc.get("ok")), flag(entry.get("ok")), text(entry.get("problem")))
for r in repos:
    out("repo", text(r.get("layer")), text(r.get("key")), text(r.get("state")), flag(r.get("optional")),
        text(r.get("path")), count(r.get("changes")), count(r.get("unpushed")), text(r.get("detail")))
for g in gone:
    out("gone", text(g.get("key")), text(g.get("path")))
'

# One distro ($1) read against the manifest by the tool's `status --json`,
# in the root, through _rc_nofd (no network call: status makes none), its
# stderr passed through and its stdout kept in a variable. The document is
# read by the tool's own interpreter, python3 beside the tool's executable
# (the venv `make install-repos-manifest` makes), with _RC_STATUS_READER.
# The exit status decides and the document explains (the mapping is the
# table in docs/manifest/design.md, "The tool route"):
#   - a repo that is not optional and is missing, not-a-directory,
#     blocked-place, in-other-layer or unusable: a ❌ line, the tool's
#     detail unchanged (a missing one names the tool's sync);
#   - the same states for an optional repo, and different or left-alone for
#     any: a ⚠️ line, no failure; skipped (optional, not there): counted;
#   - local changes and unpushed commits: a NOTE line, no failure (status
#     exits 0 for them);
#   - a not_in_manifest path: a ⚠️ line;
#   - the distro's problem (its manifest cannot be read or resolved): ❌;
#   - exit 1 with no document, an exit status other than 0 and 1, a
#     document not of format 1, a distro entry with no problem and a
#     missing or null repos or not_in_manifest (malformed, not zero repos),
#     a state the adapter does not know, and a
#     document whose verdict and the exit status disagree: ❌, so a change
#     in the tool's contract is seen.
# Then the keys status names, by layer, against the last resolve's .repos
# files: a difference is a ⚠️ (the last resolve is out of date with the
# manifest), with the tool's sync step. Sets _RC_STATUS_ISSUES (the number
# of ❌ lines) and, when it is 0, _RC_STATUS_PASS (the pass line). Its
# counts are of the manifest's repos and add up (as expected, with a
# warning, optional and skipped); a not_in_manifest path and the
# out-of-date warning are named after them, apart.
_rc_tool_status() {
    local d="$1" root bin py doc lines rc=0 prc=0 kind a b c e f g h i
    local doc_ok="" dist_ok="" problem="" failing=0 unknown=0 expected=0 warned=0 skipped=0 total=0 gone=0 outdated=""
    local from_status="" from_resolve="" layer file only_status only_resolve resolve_ok=1
    _RC_STATUS_ISSUES=0
    _RC_STATUS_PASS=""
    root="$(_rc_root)" || return 1
    bin="$(_rc_resolver_bin)"
    py="$(dirname "$bin")/python3"
    if [ ! -x "$bin" ]; then
        echo "❌ distro $d: the manifest tool is not installed at $bin, so status cannot be read; run: make install-repos-manifest (from the workspace main checkout)" >&2
        _RC_STATUS_ISSUES=1
        return 0
    fi
    if [ ! -x "$py" ]; then
        local why="is missing"
        if [ -L "$py" ] && [ ! -e "$py" ]; then
            why="is a link to nothing ($(readlink "$py"))"
        elif [ -e "$py" ]; then
            why="is not executable"
        fi
        local main="${bin%/.venv/bin/repos-manifest}"
        echo "❌ distro $d: the manifest tool is at $bin, but $py, the venv's Python that runs it and reads status's document, $why (the Python the venv was made from was moved or removed); make the venv again: remove the directory $main/.venv and the two stamp files $main/.make/setup-dev.done and $main/.make/repos-manifest.done, then run make install-repos-manifest from $main" >&2
        _RC_STATUS_ISSUES=1
        return 0
    fi
    doc="$(cd "$root" && _rc_nofd "$bin" status --distro "$d" --json)" || rc=$?
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
        echo "❌ distro $d: repos-manifest status exited $rc (it exits 0 or 1; 2 is a bad option, 128+n a signal); its own message, if any, is above" >&2
        _RC_STATUS_ISSUES=1
        return 0
    fi
    lines="$(printf '%s' "$doc" | _rc_nofd "$py" -I -c "$_RC_STATUS_READER" "$d")" || prc=$?
    if [ "$prc" -ne 0 ]; then
        echo "❌ distro $d: $py could not read the document repos-manifest status printed ($py exited $prc; repos-manifest status exited $rc); a message from either, if any, is above" >&2
        _RC_STATUS_ISSUES=1
        return 0
    fi
    kind="$(head -n1 <<< "$lines")"
    if [ "${kind%%$'\x1f'*}" = bad ]; then
        echo "❌ distro $d: repos-manifest status ${kind#bad$'\x1f'} (exit $rc); its own message, if any, is above" >&2
        _RC_STATUS_ISSUES=1
        return 0
    fi
    while IFS=$'\x1f' read -r kind a b c e f g h i; do
        case "$kind" in
            head)
                doc_ok="$a"
                dist_ok="$b"
                problem="$c"
                ;;
            repo)
                total=$((total + 1))
                from_status="$from_status$a/$b"$'\n'
                case "$c" in
                    expected) expected=$((expected + 1)) ;;
                    skipped) skipped=$((skipped + 1)) ;;
                    different|left-alone)
                        echo "⚠️ distro $d: $root/$f $c: $i" >&2
                        warned=$((warned + 1))
                        ;;
                    missing|not-a-directory|blocked-place|in-other-layer|unusable)
                        if [ "$e" = 1 ]; then
                            echo "⚠️ distro $d: $root/$f $c (optional, so it does not fail validate): $i" >&2
                            warned=$((warned + 1))
                        elif [ "$c" = missing ]; then
                            echo "❌ distro $d: $root/$f missing: $i (run: $(_rc_tool_sync_step "$d"))" >&2
                            failing=$((failing + 1))
                        else
                            echo "❌ distro $d: $root/$f $c: $i" >&2
                            failing=$((failing + 1))
                        fi
                        ;;
                    *)
                        echo "❌ distro $d: $root/$f is in a state the adapter does not know, '$c' (the tool's status format may have changed): $i" >&2
                        unknown=$((unknown + 1))
                        ;;
                esac
                if [ "$g" != 0 ] || [ "$h" != 0 ]; then
                    echo "NOTE: distro $d: $root/$f has local work ($g changed file(s), $h commit(s) not on origin); it does not fail validate" >&2
                fi
                ;;
            gone)
                echo "⚠️ distro $d: $root/$b is still on disk and no longer in the manifest (recorded by an earlier sync, which does not remove it); remove it if nothing needs it" >&2
                gone=$((gone + 1))
                ;;
        esac
    done <<< "$lines"
    if [ -n "$problem" ]; then
        echo "❌ distro $d cannot be read or resolved: $problem" >&2
        _RC_STATUS_ISSUES=$((_RC_STATUS_ISSUES + 1))
    fi
    _RC_STATUS_ISSUES=$((_RC_STATUS_ISSUES + failing + unknown))
    # The exit status decides; the document must say the same.
    local want=0
    { [ "$failing" -gt 0 ] || [ -n "$problem" ]; } && want=1
    if [ "$rc" -ne "$want" ] || [ "$doc_ok" != "$((1 - want))" ] || [ "$dist_ok" != "$((1 - want))" ]; then
        echo "❌ distro $d: repos-manifest status's document and its exit status disagree (exit $rc; the document says ok=$doc_ok, distro ok=$dist_ok, $failing failing repo(s)${problem:+, a problem}); the adapter reads status as the tool's design states it" >&2
        _RC_STATUS_ISSUES=$((_RC_STATUS_ISSUES + 1))
    fi
    # The keys status names against the last resolve's (a distro with a
    # problem has no repos to compare).
    if [ -z "$problem" ]; then
        while IFS= read -r layer; do
            file="$(_rc_repos_file "$layer")" || return 1
            [ -f "$file" ] || { resolve_ok=0; continue; }
            while IFS= read -r a; do
                [ -n "$a" ] && from_resolve="$from_resolve$layer/$a"$'\n'
            done < <(_rc_repos_entries "$file" --detail | cut -f1)
        done < <(_rc_layers)
        if [ "$resolve_ok" -eq 1 ]; then
            # Sorted and compared in C order alike: in a UTF-8 locale GNU
            # comm collates "_unnamed" after "core" and misreads the lists.
            only_status="$(LC_ALL=C comm -23 <(printf '%s' "$from_status" | LC_ALL=C sort -u) <(printf '%s' "$from_resolve" | LC_ALL=C sort -u) | tr '\n' ' ' | sed 's/ $//')"
            only_resolve="$(LC_ALL=C comm -13 <(printf '%s' "$from_status" | LC_ALL=C sort -u) <(printf '%s' "$from_resolve" | LC_ALL=C sort -u) | tr '\n' ' ' | sed 's/ $//')"
            if [ -n "$only_status" ] || [ -n "$only_resolve" ]; then
                echo "⚠️ distro $d: the last resolve ($(_rc_manifest_dir)) is out of date with the manifest (${only_status:+in the manifest only: $only_status}${only_status:+${only_resolve:+; }}${only_resolve:+in the last resolve only: $only_resolve}); the adapter's other verbs read the last resolve; run: $(_rc_tool_sync_step "$d")" >&2
                outdated="; the last resolve out of date with the manifest, warned above"
            fi
        fi
    fi
    [ "$_RC_STATUS_ISSUES" -eq 0 ] && \
        _RC_STATUS_PASS="✅ ros2_colcon checkout read against the manifest for distro $d (repos-manifest status: $total repo(s), $expected as expected, $warned with a warning above, $skipped optional and skipped$([ "$gone" -gt 0 ] && echo "; besides them, $gone path(s) on disk no longer in the manifest, warned above")$outdated; clones read as last fetched, nothing fetched)"
    return 0
}

# `validate` on the tool route, for each distro the call covers
# (_rc_tool_distro_select --every: the chosen one, or every one under
# resolved/ when none is chosen; one whose layers.txt is missing or empty
# fails, named): the workspace's own records (no second record of what the
# tool records; a leftover of another route noted), the last resolve the
# adapter's other verbs read (_rc_check_manifest and each layer's .repos
# file), then the checkouts read against the manifest by the tool's status
# (_rc_tool_status). Fails if any distro fails, naming it.
_rc_tool_validate() {
    local name root layer repos_file d n issues=0 failed="" leftover=""
    local -a keys=() covered=() passed=()
    _rc_tool_distro_select --every || return 1
    covered=("${_RC_TOOL_DISTROS[@]}")
    name="$(_rc_name)"
    root="$(_rc_root)"
    if [ -n "${ACTIVE_PROJECT_ROLE:-}" ] || [ -n "${ACTIVE_PROJECT_DISTRO:-}" ]; then
        echo "❌ the registry line of '$name' carries${ACTIVE_PROJECT_ROLE:+ role=$ACTIVE_PROJECT_ROLE}${ACTIVE_PROJECT_DISTRO:+ distro=$ACTIVE_PROJECT_DISTRO}, a second record beside the manifest tool's .repos-manifest/ (the distro comes from the calling directory): remove it from the line in .agent/projects.local" >&2
        issues=$((issues + 1))
    fi
    [ -n "${ACTIVE_PROJECT_SOURCE:-}" ] && keys+=(source)
    [ -n "${ACTIVE_PROJECT_SOURCE_REF:-}" ] && keys+=(source_ref)
    [ -n "${ACTIVE_PROJECT_SOURCE_PATH:-}" ] && keys+=(source_path)
    [ -n "${ACTIVE_PROJECT_BOOTSTRAP_URL:-}" ] && keys+=(bootstrap_url)
    if [ "${#keys[@]}" -gt 0 ]; then
        echo "❌ the settings file ${ACTIVE_PROJECT_FILE:-of '$name'} sets ${keys[*]}, a second record of the manifest beside the manifest tool's .repos-manifest/: remove it with: .agent/scripts/project_setting.sh unset $name ${keys[*]}" >&2
        issues=$((issues + 1))
    fi
    [ -e "$root/configs/manifest" ] && leftover="$root/configs/manifest"
    [ -e "$root/configs/project_bootstrap.url" ] && leftover="${leftover:+$leftover and }$root/configs/project_bootstrap.url"
    [ -n "$leftover" ] && echo "NOTE: $leftover, left from another route, is not read on the tool route (.repos-manifest/ at the root); remove it if nothing else needs it" >&2
    for d in "${covered[@]}"; do
        _RC_TOOL_DISTRO="$d"
        if ! _rc_check_manifest; then
            failed="${failed:+$failed, }$d"
            issues=$((issues + 1))
            continue
        fi
        n=0
        while IFS= read -r layer; do
            repos_file="$(_rc_repos_file "$layer")"
            if [ ! -f "$repos_file" ]; then
                echo "❌ layer '$layer': missing $repos_file (run: $(_rc_tool_sync_step "$d"))" >&2
                n=$((n + 1))
            fi
        done < <(_rc_layers)
        _rc_tool_status "$d" || return 1
        n=$((n + _RC_STATUS_ISSUES))
        if [ "$n" -gt 0 ]; then
            failed="${failed:+$failed, }$d"
            issues=$((issues + n))
        else
            passed+=("$_RC_STATUS_PASS")
        fi
    done
    [ "${#passed[@]}" -gt 0 ] && printf '%s\n' "${passed[@]}"
    if [ "$issues" -gt 0 ]; then
        echo "Validation failed: $issues issue(s)${failed:+ (failing distro: $failed)}." >&2
        return 1
    fi
}

# The project's name for messages.
_rc_name() {
    echo "${ACTIVE_PROJECT_NAME:-<name>}"
}

# Non-comment, non-blank lines of a layers.txt (the resolver always writes
# a '#' provenance line, so a file holding only that selects nothing).
_rc_layer_lines() {
    [ -f "$1" ] || return 0
    grep -v '^[[:space:]]*#' "$1" 2>/dev/null | grep -v '^[[:space:]]*$' || true
}

# The workspace-installed resolver: <main checkout>/.venv/bin/repos-manifest,
# the main checkout found from git's common dir (a worktree has no venv of
# its own; the Makefile's WS_ROOT), else WORKSPACE_ROOT. No PATH lookup, so
# a stray copy elsewhere is never used.
_rc_resolver_bin() {
    local common main="$WORKSPACE_ROOT"
    common="$(_rc_nofd git -C "$WORKSPACE_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || common=""
    [ -n "$common" ] && main="${common%/.git}"
    echo "$main/.venv/bin/repos-manifest"
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

# colcon <verb> [args...] in a layer directory, through _rc_nofd. (On the
# tool route only `test` runs colcon here, and it names the base paths
# itself: see adapter_test.)
_rc_colcon() {
    _rc_nofd colcon "$@"
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

# `setup --manifest <file> --distro <d> [--role <r>] [--with <group>]...
# [--fetch-from <prefix>]` (issue 503 part 2): a new root set up from a
# manifest file by the manifest tool's init, run in the root as
# `<tool> init <file> --distro-dirs --distro <d> [--role <r>] [--with
# <group>]... [--fetch-from <prefix>] --yes` (--yes: the question before
# fetching is the session's, asked with the tool's show first), its output
# and exit status passed through. Registration with --manifest calls it
# for a missing or empty root, after its own checks (a URL or git location
# refused there; the tool refuses one too). Refused here, before anything
# is made: a root that holds .repos-manifest/ (set up already: setup with
# no arguments is the tool's sync), and a project whose settings file or
# registry line holds what the tool's record replaces (source, source_ref,
# source_path, bootstrap_url, role=, distro=), which validate would refuse
# as a second record after the clones. The root, and each directory above
# it, made here when missing; when init fails having made nothing
# (.repos-manifest is not there), they are removed again, deepest first,
# with rmdir alone, so nothing that holds anything is removed. The adapter
# has no signal trap: a signal ends it before that removal, and
# registration's rollback removes the empty directories then.
_rc_setup_from_manifest() {
    local manifest="" distro="" role="" fetch="" root bin d rc=0 rec="" second=""
    local -a with=() args=() made=() shown=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --manifest|--distro|--role|--with|--fetch-from)
                if [ $# -lt 2 ] || [ -z "$2" ]; then
                    echo "ERROR: setup: $1 needs a value" >&2
                    return 2
                fi
                case "$1" in
                    --manifest) [ -z "$manifest" ] || { echo "ERROR: setup: --manifest given twice" >&2; return 2; }; manifest="$2" ;;
                    --distro) [ -z "$distro" ] || { echo "ERROR: setup: one --distro only (a second distro is the tool's add-distro)" >&2; return 2; }; distro="$2" ;;
                    --role) [ -z "$role" ] || { echo "ERROR: setup: --role given twice" >&2; return 2; }; role="$2" ;;
                    --with) with+=(--with "$2") ;;
                    --fetch-from) [ -z "$fetch" ] || { echo "ERROR: setup: --fetch-from given twice" >&2; return 2; }; fetch="$2" ;;
                esac
                shift 2 ;;
            *)
                echo "ERROR: setup takes no arguments, or --manifest <file> --distro <distro> [--role <role>] [--with <group>]... [--fetch-from <prefix>]; got '$1'" >&2
                return 2 ;;
        esac
    done
    if [ -z "$manifest" ] || [ -z "$distro" ]; then
        echo "ERROR: setup from a manifest needs --manifest <file> and --distro <distro>" >&2
        return 2
    fi
    root="$(_rc_root)" || return 1
    if [ "$(_rc_route)" = tool ]; then
        echo "ERROR: $root is set up already (it holds .repos-manifest/): the manifest tool's init is for a directory that is not set up yet. Setup with no arguments runs the tool's sync there: $(_rc_tool_sync_step "$distro")" >&2
        return 1
    fi
    [ -n "${ACTIVE_PROJECT_SOURCE:-}" ] && second="${second:+$second, }source"
    [ -n "${ACTIVE_PROJECT_SOURCE_REF:-}" ] && second="${second:+$second, }source_ref"
    [ -n "${ACTIVE_PROJECT_SOURCE_PATH:-}" ] && second="${second:+$second, }source_path"
    [ -n "${ACTIVE_PROJECT_BOOTSTRAP_URL:-}" ] && second="${second:+$second, }bootstrap_url"
    [ -n "$second" ] && rec="${ACTIVE_PROJECT_FILE:-its settings file} sets $second"
    if [ -n "${ACTIVE_PROJECT_ROLE:-}" ] || [ -n "${ACTIVE_PROJECT_DISTRO:-}" ]; then
        rec="${rec:+$rec, and }its line in .agent/projects.local carries${ACTIVE_PROJECT_ROLE:+ role=$ACTIVE_PROJECT_ROLE}${ACTIVE_PROJECT_DISTRO:+ distro=$ACTIVE_PROJECT_DISTRO}"
    fi
    if [ -n "$rec" ]; then
        echo "ERROR: project '$(_rc_name)': $rec; on a root the manifest tool sets up, the tool's record is the one record, so validate would refuse these as a second record. Remove them first, then run setup again" >&2
        return 1
    fi
    bin="$(_rc_resolver_bin)"
    if [ ! -x "$bin" ]; then
        echo "ERROR: the manifest tool is not installed at $bin; run: make install-repos-manifest (from the workspace main checkout)" >&2
        return 1
    fi
    # The tool records the location as given and reads a relative one from
    # where it runs (the root), so an existing file is passed absolute.
    # Anchored first, and -- before each path, so a name that starts with
    # '-' is not read as an option; no CDPATH for this cd.
    if [ -f "$manifest" ] && [[ "$manifest" != /* ]]; then
        manifest="$PWD/$manifest"
        manifest="$(CDPATH='' cd -- "$(dirname -- "$manifest")" && pwd -P)/$(basename -- "$manifest")"
    fi
    # The directories made here, the shallowest first.
    d="$root"
    while [ ! -e "$d" ] && [ ! -L "$d" ]; do
        made=("$d" ${made[@]+"${made[@]}"})
        d="$(dirname "$d")"
    done
    if [ "${#made[@]}" -gt 0 ]; then
        mkdir -p "$root" || return 1
    fi
    args=(init "$manifest" --distro-dirs --distro "$distro")
    [ -n "$role" ] && args+=(--role "$role")
    args+=(${with[@]+"${with[@]}"})
    [ -n "$fetch" ] && args+=(--fetch-from "$fetch")
    args+=(--yes)
    # Printed with the manifest's and a --fetch-from prefix's user name and
    # password masked (mask_url_userinfo, from the dispatcher's
    # _project_registry.sh); the tool is handed the values as given.
    shown=("${args[@]}")
    shown[1]="$(mask_url_userinfo "$manifest")"
    [ -n "$fetch" ] && shown[${#shown[@]}-2]="$(mask_url_userinfo "$fetch")"
    echo "Running: $bin ${shown[*]} (in $root)"
    (cd "$root" && _rc_nofd "$bin" "${args[@]}") || rc=$?
    if [ "$rc" -ne 0 ] && [ ! -e "$root/.repos-manifest" ] && [ ! -L "$root/.repos-manifest" ]; then
        local i
        for (( i=${#made[@]}-1; i>=0; i-- )); do
            rmdir -- "${made[$i]}" 2>/dev/null || break
        done
    fi
    return "$rc"
}

adapter_setup() {
    # Bootstrap the manifest into a fresh hosting dir when needed, then
    # import each layer's repos with vcs. Optional layers
    # (optional_layers.txt) may fail — e.g. private repos; everything else
    # aborts loudly. On the tool route: the tool's sync, nothing else.
    # With arguments (--manifest <file> ...): a new root set up from a
    # manifest by the tool's init (_rc_setup_from_manifest).
    local route
    if [ $# -gt 0 ]; then
        _rc_setup_from_manifest "$@"
        return
    fi
    # The route is read once, for the refusal and the branch (issue 599).
    route="$(_rc_route)"
    _rc_refuse_removed_source "$route" || return 1
    if [ "$route" = tool ]; then
        _rc_tool_sync
        return
    fi
    _rc_bootstrap_manifest || return 1
    _rc_require_manifest || return 1
    if ! command -v vcs >/dev/null 2>&1; then
        echo "ERROR: 'vcs' (vcstool) not found — required to import layer repos." >&2
        return 1
    fi
    local mdir layer layer_dir repos_file
    mdir="$(_rc_manifest_dir)"
    while IFS= read -r layer; do
        repos_file="$(_rc_repos_file "$layer")"
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

# `build` on the tool route: the manifest tool's build for the chosen
# distro, in the root, with the distro's environment sourced first in the
# adapter's shell (the inherited prefix paths scrubbed, then
# /opt/ros/<distro>/setup.bash), as the tool builds in the environment it
# is run in. The adapter's colcon flags go after `--`, the caller's
# arguments after them, so they reach every layer; the tool gives colcon
# the repos on disk as --base-paths, keeps its record and writes
# <root>/<distro>/setup.bash. Its output and exit status are passed
# through. No layer argument: one layer is built with the tool directly.
# The distro rule and the one read of layers.txt run first (a resolve
# that cannot be used is refused naming the tool's sync); the key check of
# _rc_check_manifest does not, since the tool reads the resolved files
# itself: a nested key (grp/repo) builds, while env, test, validate, repos
# and the worktree verbs still refuse it. The tool refuses package
# selection (--packages-select and the like) for a layer not built yet,
# and --packages-up-to (and the other selections colcon resolves in each
# layer) when the run builds two or more layers; when the tool refuses a
# run so (exit 1 and one of those two refusals on its stderr, which is
# kept for that only when the arguments hold a --packages option the tool
# counts as selection, not --packages-skip, --packages-ignore, their
# -regex forms or --packages-skip-build-finished, or --cmake-target), the
# adapter says how to run the tool's own step with the environment
# sourced, since the step the tool names sources nothing.
_rc_tool_build() {
    local root bin underlay rc=0 arg selecting=0 refused=0 errlog
    root="$(_rc_root)" || return 1
    _rc_tool_distro_select || return 1
    _rc_tool_read_layers || return 1
    bin="$(_rc_resolver_bin)"
    if [ ! -x "$bin" ]; then
        echo "ERROR: the manifest tool is not installed at $bin; run: make install-repos-manifest (from the workspace main checkout)" >&2
        return 1
    fi
    underlay="$(_rc_underlay)" || return 1
    unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
    _rc_source_setup "$underlay" || return 1
    echo "Running: $bin build --distro $_RC_TOOL_DISTRO -- --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON $* (in $root, $underlay sourced)"
    for arg in "$@"; do
        case "${arg%%=*}" in
            --packages-skip|--packages-skip-regex|--packages-ignore|--packages-ignore-regex|--packages-skip-build-finished) ;;
            --packages*|--cmake-target) selecting=1 ;;
        esac
    done
    if [ "$selecting" -eq 0 ]; then
        (cd "$root" && _rc_nofd "$bin" build --distro "$_RC_TOOL_DISTRO" -- --symlink-install \
            --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON "$@") || rc=$?
        return "$rc"
    fi
    # With selection, the tool's stderr is passed through and kept, to tell
    # its selection refusal from any other failure. The status is the
    # tool's own (PIPESTATUS, whatever the caller's pipefail). The reader
    # never stops the tool: a stderr it cannot write to (closed, full)
    # leaves the copy in the file, a file it cannot write leaves stderr,
    # and whatever is left is drained. With no temporary file to be had,
    # the build runs as without selection, with no note. The file goes on
    # every way out, an interrupt included. While the build runs, the
    # adapter's handler replaces the caller's handlers for INT, TERM and
    # HUP, a signal the caller ignores included (so the tool starts with
    # that signal's default action). The caller's handlers are put back
    # when the build returns, or when one of the three arrives: then the
    # file is removed, they are put back and the signal is sent again, so
    # the caller's handler runs, or the default ends the run with the
    # signal's status. Bash runs the handler only once the build pipeline
    # ends, so a TERM sent to the adapter alone does not stop the tool,
    # which finishes first; Ctrl-C and `timeout` signal the whole process
    # group, the tool included. If the caller's handler returns instead of
    # exiting, the run goes on with the file gone, so its grep is silent.
    if ! errlog="$(mktemp 2>/dev/null)"; then
        (cd "$root" && _rc_nofd "$bin" build --distro "$_RC_TOOL_DISTRO" -- --symlink-install \
            --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON "$@") || rc=$?
        return "$rc"
    fi
    local sig traps
    traps="$(trap -p INT TERM HUP)"
    for sig in INT TERM HUP; do
        # shellcheck disable=SC2064  # the file's name and the saved traps are fixed now
        trap "rm -f -- $(printf '%q' "$errlog"); trap - INT TERM HUP; eval $(printf '%q' "$traps"); kill -$sig \$\$" "$sig"
    done
    { (cd "$root" && _rc_nofd "$bin" build --distro "$_RC_TOOL_DISTRO" -- --symlink-install \
        --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON "$@") 2>&1 1>&7 7>&- \
        | { tee "$errlog" >&2 2>/dev/null || tee -a "$errlog" >/dev/null 2>&1 || :; cat >/dev/null 2>&1 || :; } \
        && rc="${PIPESTATUS[0]}" || rc="${PIPESTATUS[0]}"; } 7>&1
    if [ "$rc" -eq 1 ] && grep -sqF -e "builds only part of a layer, so it only rebuilds layers that are built" \
            -e "names packages colcon must find in each layer it builds" "$errlog"; then
        refused=1
    fi
    rm -f -- "$errlog"
    trap - INT TERM HUP
    eval "$traps"
    if [ "$refused" -eq 1 ]; then
        printf 'NOTE: with package selection the manifest tool builds only layers built before, and --packages-up-to only one layer at a time; the adapter builds every layer, so build without selection first, or run the tool'"'"'s step yourself with the distro'"'"'s environment sourced, from a shell with no other workspace'"'"'s prefix paths: unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX && source %q && cd %q && %q build --distro %q <layer> -- <colcon arguments>\n' \
            "$underlay" "$root" "$bin" "$_RC_TOOL_DISTRO" >&2
    fi
    return "$rc"
}

adapter_build() {
    # Build layers in layers.txt order, sourcing each successful layer's
    # local_setup.bash so later layers overlay it. Stop on first failure.
    # On the tool route: the manifest tool's build (_rc_tool_build).
    if [ "$(_rc_route)" = tool ]; then
        _rc_tool_build "$@"
        return
    fi
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
            && _rc_colcon build --symlink-install \
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
    # On the tool route colcon is given, as --base-paths, the src/<key>
    # directories of the repos the layer's resolved .repos file lists that
    # are on disk, as the tool's build gives them (so a clone left on disk
    # that the role or the groups no longer keep is not tested, and the
    # unnamed layer's run in <root>/<distro> does not take in the named
    # layers below it). They are read before the underlay is sourced, with
    # the call's one read of the layers. The tool's build rule holds: a
    # listed repo missing from disk that the resolved optional.txt does not
    # name (_rc_is_optional_repo) fails the run before anything runs,
    # naming each such repo and the tool's sync; an optional repo missing is
    # left out; a layer with none of its repos on disk (every one of them
    # optional) is skipped with a line. A layer whose resolved .repos file
    # is missing fails before anything runs too, naming the file and the
    # tool's sync, as the tool's build refuses it; one the reader cannot
    # read fails before anything runs as well.
    _rc_require_manifest || return 1
    local underlay layer layer_dir rc failed="" route key list file entries missing="" i=0
    local -a paths=() tool_paths=()
    route="$(_rc_route)"
    if [ "$route" = tool ]; then
        while IFS= read -r layer; do
            layer_dir="$(_rc_layer_dir "$layer")"
            file="$(_rc_repos_file "$layer")" || return 1
            if [ ! -f "$file" ]; then
                echo "ERROR: $file is missing, and the last resolve's layers.txt lists layer '$layer'; test reads from it which repos of the layer to test (the manifest tool's build refuses the same)" >&2
                echo "Run: $(_rc_tool_sync_step "$_RC_TOOL_DISTRO")" >&2
                return 1
            fi
            if ! entries="$(_rc_repos_entries "$file" --detail)"; then
                echo "ERROR: $file could not be read, and the last resolve's layers.txt lists layer '$layer'; test reads from it which repos of the layer to test" >&2
                return 1
            fi
            list=""
            while IFS= read -r key; do
                [ -n "$key" ] || continue
                if [ -d "$layer_dir/src/$key" ]; then
                    list="$list src/$key"
                elif ! _rc_is_optional_repo "$key"; then
                    missing="${missing:+$missing, }$key (layer $layer)"
                fi
            done < <(printf '%s\n' "$entries" | cut -f1)
            tool_paths+=("$list")
        done < <(_rc_layers)
        if [ -n "$missing" ]; then
            echo "ERROR: not on disk, and not optional: $missing; nothing was run (the manifest tool's build refuses the same)" >&2
            echo "Run: $(_rc_tool_sync_step "$_RC_TOOL_DISTRO") (it clones what is missing), then test again" >&2
            return 1
        fi
    fi
    underlay="$(_rc_underlay)" || return 1
    unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
    _rc_source_setup "$underlay" || return 1
    while IFS= read -r layer; do
        i=$((i + 1))
        layer_dir="$(_rc_layer_dir "$layer")"
        if [ -f "$layer_dir/install/local_setup.bash" ]; then
            _rc_source_setup "$layer_dir/install/local_setup.bash" || return 1
        fi
        if [ ! -d "$layer_dir/src" ]; then
            echo "Skipping layer $layer (no src directory)"
            continue
        fi
        paths=()
        if [ "$route" = tool ]; then
            read -r -a paths <<< "${tool_paths[$((i - 1))]}"
            if [ "${#paths[@]}" -eq 0 ]; then
                echo "Skipping layer $layer (every repo ${layer}.repos lists is optional, and none is on disk in $layer_dir/src)"
                continue
            fi
            paths=(--base-paths "${paths[@]}")
        fi
        echo "----------------------------------------"
        echo "Testing layer: $layer"
        echo "----------------------------------------"
        rc=0
        (cd "$layer_dir" \
            && _rc_colcon test ${paths[@]+"${paths[@]}"} --event-handlers console_direct+ \
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
    # On the tool route: the tool's sync, nothing else (the adapter pulls
    # and fetches nothing itself; the tool's sync clones and updates by its
    # own rules). The route is read once, for the refusal and the branch
    # (issue 599).
    local route
    route="$(_rc_route)"
    _rc_refuse_removed_source "$route" || return 1
    if [ "$route" = tool ]; then
        _rc_tool_sync
        return
    fi
    _rc_require_manifest || return 1
    local mdir layer layer_dir repos_file entry name version repo_dir branch
    mdir="$(_rc_manifest_dir)"
    while IFS= read -r layer; do
        layer_dir="$(_rc_layer_dir "$layer")"
        repos_file="$(_rc_repos_file "$layer")"
        # A layer never set up has nothing to pull or fetch.
        [ -d "$layer_dir/src" ] || continue
        while IFS= read -r entry; do
            [ -z "$entry" ] && continue
            name="${entry%%$'\t'*}"
            version="${entry#*$'\t'}"
            repo_dir="$layer_dir/src/$name"
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
    echo "Sync complete."
}

adapter_validate() {
    # Checkout shape vs manifest: every non-optional layer has a repos file
    # and every repo pinned in it is checked out. Distro must resolve. On
    # the tool route: _rc_tool_validate (the tool's status).
    if [ "$(_rc_route)" = tool ]; then
        _rc_tool_validate
        return
    fi
    local mdir layer layer_dir repos_file entry name issues=0
    if ! _rc_require_manifest; then
        return 1
    fi
    mdir="$(_rc_manifest_dir)"
    if ! _rc_distro >/dev/null; then
        issues=$((issues + 1))
    fi
    while IFS= read -r layer; do
        repos_file="$(_rc_repos_file "$layer")"
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
    # comes from install= in the project's settings file alone (issue #332;
    # the legacy and shared config files are not read, issue #265 part 4).
    if [ -z "${ACTIVE_PROJECT_INSTALL:-}" ]; then
        echo "install not set for project '${ACTIVE_PROJECT_NAME:-}' — nothing to install (colcon installs during build)."
        return 0
    fi
    if [ "$ACTIVE_PROJECT_INSTALL" = "none" ]; then
        echo "install=none: project '$ACTIVE_PROJECT_NAME' records that it has no install step — nothing to install (colcon installs during build)."
        return 0
    fi
    echo "Running: $ACTIVE_PROJECT_INSTALL $*"
    echo ""
    cd "$(_rc_root)" || return 1
    active_project_exec "$ACTIVE_PROJECT_INSTALL" "$@"
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
        # Said once, at creation, on stderr (stdout is env.sh): a lower
        # layer not built yet leaves this worktree's build without its
        # packages, which CMake reports only by package name.
        if [ ! -f "$layer_dir/install/local_setup.bash" ]; then
            echo "NOTE: layer $l is not built ($layer_dir/install/local_setup.bash missing); this worktree's build will not find its packages until it is" >&2
        fi
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
        done < <(_rc_repos_entries "$(_rc_repos_file "$l")" --detail)
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
