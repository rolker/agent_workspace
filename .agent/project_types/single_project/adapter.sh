# shellcheck shell=bash
# .agent/project_types/single_project/adapter.sh
# single_project adapter — one registered repository: the checkout at the
# registry line's path (issue #265 part 4 retired the project/ symlink).
#
# Facade over the pre-adapter workspace scripts (ADR-0011, #210). A
# project's build, test and install commands come from its settings file
# .agent/projects.d/<name> alone (issue #332; issue #265 part 4 retired the
# legacy .agent/projects.d/<name>.sh and the shared .agent/project_config.sh,
# which nothing here reads). A command runs without a shell, so nothing a
# config file exported (an SDK path, PATH) reaches it: environment setup
# belongs in the script the key points at.
#
# Sourced by .agent/scripts/adapter with WORKSPACE_ROOT and ADAPTER_TYPE_DIR
# set as shell variables (not exported). Not executable on its own; must be
# silent at source time.

# The project's command setting <key> (build, test or install) from its
# settings file (the dispatcher's ACTIVE_PROJECT_BUILD/_TEST/_INSTALL).
# Sets SP_CMD (the value, 'none' included; empty when the file does not set
# it).
_single_project_resolve_cmd() {
    SP_CMD=""
    case "$1" in
        build) SP_CMD="${ACTIVE_PROJECT_BUILD:-}" ;;
        test) SP_CMD="${ACTIVE_PROJECT_TEST:-}" ;;
        install) SP_CMD="${ACTIVE_PROJECT_INSTALL:-}" ;;
    esac
    return 0
}

# Load a required command (build or test) into SP_CMD, or print guidance
# and return 1.
_single_project_load_cmd() {
    local key="$1"
    _single_project_resolve_cmd "$key"
    [ -n "$SP_CMD" ] && return 0
    echo "❌ project '${ACTIVE_PROJECT_NAME:-}' has no $key command."
    echo ""
    echo "Set it in its settings file ($ACTIVE_PROJECT_FILE):"
    echo ""
    echo "  .agent/scripts/project_setting.sh set ${ACTIVE_PROJECT_NAME:-<name>} $key=<command>"
    echo ""
    echo "  (a plain command run from the project root, or a script path;"
    echo "   $key=none records that the project has none)"
    echo ""
    return 1
}

# Run the resolved command (SP_CMD) from the project root: split into argv
# and run without a shell.
_single_project_exec_cmd() {
    echo "Running: $SP_CMD $*"
    echo ""
    cd "$(adapter_project_root)" || return 1
    active_project_exec "$SP_CMD" "$@"
}

adapter_setup() {
    local root
    root="$(adapter_project_root)" || return 1
    exec "$ADAPTER_TYPE_DIR/setup.sh" --project-root "$root" "$@"
}

adapter_sync() {
    # No project resolved: the dispatcher sends `sync` here alone, to sync
    # the workspace by itself (sync.py with no --project-root).
    if [ -z "${ACTIVE_PROJECT_ROOT:-}" ]; then
        exec python3 "$ADAPTER_TYPE_DIR/sync.py" "$@"
    fi
    exec python3 "$ADAPTER_TYPE_DIR/sync.py" --project-root "$ACTIVE_PROJECT_ROOT" "$@"
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
    _single_project_load_cmd build
    if [ "$SP_CMD" = "none" ]; then
        echo "build=none: project '$ACTIVE_PROJECT_NAME' records that it has no build step — nothing to build."
        return 0
    fi
    _single_project_exec_cmd "$@"
}

adapter_test() {
    _single_project_load_cmd test
    if [ "$SP_CMD" = "none" ]; then
        echo "test=none: project '$ACTIVE_PROJECT_NAME' records that it has no tests — nothing to run."
        return 0
    fi
    _single_project_exec_cmd "$@"
}

adapter_install() {
    _single_project_resolve_cmd install
    if [ "$SP_CMD" = "none" ]; then
        echo "install=none: project '$ACTIVE_PROJECT_NAME' records that it has no install step — nothing to install."
        return 0
    fi
    if [ -z "$SP_CMD" ]; then
        echo "install not set for project '${ACTIVE_PROJECT_NAME:-}' — nothing to install (this is fine for most projects)."
        return 0
    fi
    _single_project_exec_cmd "$@"
}

adapter_env() {
    # single_project exposes no project environment.
    :
}

adapter_project_root() {
    # ACTIVE_PROJECT_ROOT is set by the dispatcher: the registry hosting dir.
    # There is no default (issue #265 part 4 retired project/).
    if [ -z "${ACTIVE_PROJECT_ROOT:-}" ]; then
        echo "ERROR: no project selected (select one: --project <name>)" >&2
        return 1
    fi
    echo "$ACTIVE_PROJECT_ROOT"
}

adapter_repos() {
    local root
    root="$(adapter_project_root)" || return 1
    if [ ! -d "$root" ] || ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
        echo "ERROR: project '${ACTIVE_PROJECT_NAME:-}' is not checked out at $root" >&2
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

adapter_repo_pin() {
    # <repo>: a single repository pins nothing, so its base is its default
    # branch: "<branch>\tbranch" (ADR-0019). <repo> must be the name
    # adapter_repos prints. The default branch is origin/HEAD as git
    # recorded it, else what origin says HEAD points at; never a guess.
    local repo=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --layer) echo "ERROR: single_project does not support --layer (no layers)" >&2; return 1 ;;
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
        echo "ERROR: repo_pin requires a repository name: repo_pin <repo>" >&2
        return 1
    fi
    local line name root
    line="$(adapter_repos)" || return 1
    name="${line%%:*}"
    root="${line#*:}"
    if [ "$repo" != "$name" ]; then
        echo "ERROR: repo_pin: no repository '$repo' in this project (known: $name)" >&2
        return 1
    fi
    local branch="" symref rc=0 why="origin did not name its HEAD"
    if symref="$(git -C "$root" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)"; then
        branch="${symref#refs/remotes/origin/}"
    else
        # Bounded (#323): a prompt or a stalled host must not hang the caller.
        symref="$(_adapter_bounded_git -C "$root" ls-remote --symref origin HEAD 2>/dev/null)" || rc=$?
        if [ "$rc" -eq 0 ]; then
            branch="$(awk -F'\t' '$1 ~ /^ref: refs\/heads\// && $2 == "HEAD" { sub(/^ref: refs\/heads\//, "", $1); print $1; exit }' <<< "$symref")"
        elif [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
            why="origin did not answer within $(_adapter_git_limit)s"
        else
            why="origin could not be asked (git ls-remote exited $rc)"
        fi
    fi
    if [ -z "$branch" ]; then
        echo "ERROR: repo_pin: cannot determine the default branch of $root: origin/HEAD is not set and $why" >&2
        return 1
    fi
    printf '%s\tbranch\n' "$branch"
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
