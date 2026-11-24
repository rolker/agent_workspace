#!/usr/bin/env bash
# Tests for the ros2_colcon adapter (#172 step 6 phase 1, issue #235).
#
# Everything runs against sandbox workspaces (mktemp) with the real
# dispatcher, registry lib, and adapters copied in. The colcon/vcs
# toolchain and the ROS underlay are stubs — no ROS installation, no
# network, and no dependency on any real project checkout (workspace
# gates verify with synthetic sandboxes only).
#
# Run: bash .agent/scripts/tests/test_ros2_colcon.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

PASS=0

# The adapter (and the build.sh/test.sh shims that exec it) carries the
# user-tier guard added in #317: it refuses when the cwd is neither inside
# its own workspace checkout nor under a registered project root. These
# fixtures drive a SANDBOX workspace, so every invocation runs from inside
# that sandbox -- which is what a real `make build` does too.
run_in_ws() {  # <sandbox> <command> [args...]
    local sb="$1"; shift
    (cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && "$@")
}
FAIL=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    needle:   ${needle}"
        echo "    haystack: ${haystack}"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    unexpected needle: ${needle}"
        echo "    haystack:          ${haystack}"
        FAIL=$((FAIL + 1))
    fi
}

# ---- Sandbox helpers ----

# One sandbox for the whole run, created at top level (not inside $()) so
# the trap actually fires — see issue #297. Helpers carve per-test
# directories out of it with `mktemp -d -p "$SANDBOX"`, which needs no
# shared state and so survives being called as `sb="$(make_sandbox)"`.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# git@github.com:<owner>/<repo>.git is served from the fake_remotes/github.com
# folder of the per-test sandbox git runs in (found upward from git's own
# working directory); outside one, it fails as an unreachable host does.
# No test reaches the network.
cat > "$SANDBOX/fakessh" <<'SSH_EOF'
#!/usr/bin/env bash
d="$PWD"
while [ "$d" != / ] && [ ! -d "$d/fake_remotes/github.com" ]; do d="$(dirname "$d")"; done
if [ ! -d "$d/fake_remotes/github.com" ]; then
    echo "ssh: Could not resolve hostname github.com: Name or service not known" >&2
    exit 255
fi
cd "$d/fake_remotes/github.com" && eval "exec ${@: -1}"
SSH_EOF
chmod +x "$SANDBOX/fakessh"
export GIT_SSH_COMMAND="$SANDBOX/fakessh"

# Base sandbox: dispatcher + registry lib + both adapter types.
make_sandbox() {
    local sb
    sb="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$sb/.agent/scripts" "$sb/.agent/project_types" "$sb/.agent/projects.d"
    cp "$REAL_ROOT/.agent/scripts/adapter" "$sb/.agent/scripts/adapter"
    cp "$REAL_ROOT/.agent/scripts/_project_registry.sh" "$sb/.agent/scripts/_project_registry.sh"
    cp "$REAL_ROOT/.agent/scripts/validate_adapter.sh" "$sb/.agent/scripts/validate_adapter.sh"
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$sb/.agent/project_types/"
    cp -r "$REAL_ROOT/.agent/project_types/ros2_colcon" "$sb/.agent/project_types/"
    echo "$sb"
}

# Stub toolchain: colcon records invocations (cwd, subcommand, the layers
# already sourced into its environment) and fabricates install/local_setup
# on build; vcs records imports and simulates per-layer failures.
make_toolchain_stubs() {
    local sb="$1"
    mkdir -p "$sb/bin"
    cat > "$sb/bin/colcon" <<'EOF'
#!/usr/bin/env bash
here="$(pwd -P)"
echo "COLCON_RAN_IN:$here CMD:$1 SOURCED:${SOURCED_LAYERS:-none}" >> "${COLCON_LOG:?}"
if [ -f "$here/.colcon_fail" ]; then
    exit 3
fi
if [ "$1" = "build" ]; then
    mkdir -p "$here/install"
    layer="$(basename "$here")"
    printf 'export SOURCED_LAYERS="${SOURCED_LAYERS:-}+%s"\n' "$layer" \
        > "$here/install/local_setup.bash"
fi
exit 0
EOF
    cat > "$sb/bin/vcs" <<'EOF'
#!/usr/bin/env bash
# Usage seen from the adapter: vcs import --skip-existing <src_dir> < repos
target="${@: -1}"
cat > "$target/.vcs_input"
echo "VCS_IMPORT:$target" >> "${VCS_LOG:?}"
layer_ws="$(basename "$(dirname "$target")")"
case " ${VCS_FAIL_LAYERS:-} " in
    *" ${layer_ws%_ws} "*) exit 1 ;;
esac
# VCS_MKDIRS=1: a directory per repository, as a real import leaves.
if [ -n "${VCS_MKDIRS:-}" ]; then
    sed -n 's/^  \([A-Za-z0-9_.-]*\):[[:space:]]*$/\1/p' "$target/.vcs_input" \
        | while IFS= read -r n; do mkdir -p "$target/$n"; done
fi
exit 0
EOF
    chmod +x "$sb/bin/colcon" "$sb/bin/vcs"
}

# Fake ROS underlay for distro "fakefox" under $sb/rosroot.
make_underlay() {
    local sb="$1" distro="${2:-fakefox}"
    mkdir -p "$sb/rosroot/$distro"
    echo 'export SOURCED_LAYERS="base"' > "$sb/rosroot/$distro/setup.bash"
}

# Write a .repos file with the given repo names, all pinned to $version.
write_repos_file() {
    local file="$1" version="$2"
    shift 2
    {
        echo "repositories:"
        local name
        for name in "$@"; do
            echo "  $name:"
            echo "    type: git"
            echo "    url: file:///nonexistent/${name}.git"
            echo "    version: $version"
        done
    } > "$file"
}

# Synthetic layered project "tiered": layers l1, l2, l3 (l3 optional),
# distro fakefox declared in bootstrap.yaml, registered in the registry,
# ROS_ROOT_DIR pointed at the sandbox underlay.
make_colcon_project() {
    local sb="$1"
    local proj="$sb/projects/tiered"
    local mdir="$proj/configs/manifest"
    mkdir -p "$mdir/repos"
    printf 'l1\nl2\nl3\n' > "$mdir/layers.txt"
    printf 'l3\n' > "$mdir/optional_layers.txt"
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\ndistro: fakefox\n' \
        > "$mdir/bootstrap.yaml"
    write_repos_file "$mdir/repos/l1.repos" fakefox pkg_a pkg_b
    write_repos_file "$mdir/repos/l2.repos" fakefox pkg_c
    write_repos_file "$mdir/repos/l3.repos" fakefox pkg_priv
    echo "tiered ros2_colcon projects/tiered" >> "$sb/.agent/projects.local"
    make_underlay "$sb"
    echo "$proj"
}

# Full environment for adapter runs: stub toolchain on PATH, log paths set.
# Usage: run_adapter <sb> <verb-and-args...>
run_adapter() {
    local sb="$1"
    shift
    (cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" \
        COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered "$@")
}

# Create src/ checkouts matching the manifest (as if setup had run with
# real tools): plain dirs by default, git repos with origin when asked.
# Usage: populate_layer <proj> <layer> [--git] <name...>
populate_layer() {
    local proj="$1" layer="$2" as_git=false
    shift 2
    if [ "${1:-}" = "--git" ]; then
        as_git=true
        shift
    fi
    local name dir
    for name in "$@"; do
        dir="$proj/layers/main/${layer}_ws/src/$name"
        mkdir -p "$dir"
        if [ "$as_git" = true ]; then
            git -C "$dir" init --quiet
            git -C "$dir" remote add origin "git@github.com:owner/${name}.git"
        fi
    done
}

# ---- worktree_create.sh / worktree_remove.sh / worktree_list.sh
#      package-worktree integration (ADR-0012, plan step 9) ----

# A sandbox with the worktree scripts added, plus a real (committed) git
# repo standing in for the workspace so worktree_create.sh's own git
# operations (fetch/show-ref against ROOT_DIR) have something to work
# with. A failing gh/git-bug stub keeps issue lookups offline.
make_worktree_sandbox() {
    local sb
    sb="$(make_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_create.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_enter.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_list.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_worktree_helpers.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_resolve_default_branch.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_issue_helpers.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_pr_base.sh" "$sb/.agent/scripts/"
    mkdir -p "$sb/stubbin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/gh"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"
    chmod +x "$sb/stubbin/gh" "$sb/stubbin/git-bug"
    # `-b main`: new worktree branches start from the default branch (#323).
    git -C "$sb" init --quiet -b main
    git -C "$sb" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
    echo "$sb"
}

# A real (committed) git repo for a package under a layer's src/, standing
# in for a real package checkout post-`adapter setup`. Its origin is
# git@github.com:owner/<name>.git, which the adapter reads as owner/<name>,
# served offline by the GIT_SSH_COMMAND stub below from the sandbox's
# fake_remotes/github.com/owner/<name>.git: a package worktree's owning
# branch starts from its base as origin has it (issue 429), and the base is
# the manifest's pin, fakefox, which origin holds as a branch beside main.
make_committed_pkg_repo() {
    local proj="$1" layer="$2" name="$3"
    local dir="$proj/layers/main/${layer}_ws/src/$name"
    local bare
    bare="$(dirname "$(dirname "$proj")")/fake_remotes/github.com/owner/${name}.git"
    mkdir -p "$dir" "$(dirname "$bare")"
    git -C "$dir" init --quiet
    echo "$name" > "$dir/README.md"
    git -C "$dir" add README.md
    git -C "$dir" -c user.name=t -c user.email=t@t commit --quiet -m init
    git -C "$dir" branch -m main 2>/dev/null || true
    git init --quiet --bare -b main "$bare"
    git -C "$dir" remote add origin "git@github.com:owner/${name}.git"
    git -C "$dir" push --quiet origin main main:fakefox
    git -C "$dir" fetch --quiet origin
    git -C "$dir" remote set-head origin main >/dev/null
}

# These tests are about the manifest and layout, not the branch lookup.
# make_committed_pkg_repo's origins answer (the GIT_SSH_COMMAND stub), so
# there the lookup decides as it would online; --allow-unverified-branch
# (#323) is kept for an origin that cannot be reached, which then starts a
# sibling's branch anyway. It never applies to a base (issue 429).
run_worktree_create() {
    local sb="$1"
    shift
    (cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch "$@")
}

run_worktree_remove() {
    local sb="$1"
    shift
    (cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_remove.sh" "$@")
}

test_worktree_create_package_success() {
    echo "TEST: worktree_create makes a real package worktree; sibling untouched; env.sh generated"
    local sb out rc=0 proj wt
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    make_committed_pkg_repo "$proj" l1 pkg_b
    mkdir -p "$proj/layers/main/l1_ws/install"
    touch "$proj/layers/main/l1_ws/install/local_setup.bash"
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#111 --type project --project tiered \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-111"
    assert_eq "aggregate dir created" "true" "$([ -d "$wt" ] && echo true || echo false)"
    assert_eq "named package is a real worktree (not a symlink)" \
        "false" "$([ -L "$wt/l1_ws/src/pkg_a" ] && echo true || echo false)"
    assert_eq "worktree checked out on feature/issue-111" \
        "feature/issue-111" "$(git -C "$wt/l1_ws/src/pkg_a" branch --show-current)"
    assert_eq "sibling package untouched in the hosted instance" \
        "false" "$([ -L "$proj/layers/main/l1_ws/src/pkg_b" ] && echo true || echo false)"
    assert_eq "sibling still on its original branch in the hosted instance" \
        "main" "$(git -C "$proj/layers/main/l1_ws/src/pkg_b" branch --show-current)"
    assert_eq "env.sh generated" "true" "$([ -f "$wt/env.sh" ] && echo true || echo false)"
    assert_eq "env.sh scrubs, then runtime-guards underlay+l1 install, in order" \
        "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
source $sb/rosroot/fakefox/setup.bash
if [ -f $proj/layers/main/l1_ws/install/local_setup.bash ]; then source $proj/layers/main/l1_ws/install/local_setup.bash; fi
if [ -f $wt/l1_ws/install/local_setup.bash ]; then source $wt/l1_ws/install/local_setup.bash; fi" \
        "$(< "$wt/env.sh")"
    assert_eq "build.sh generated and executable" "true" "$([ -x "$wt/build.sh" ] && echo true || echo false)"
    assert_eq "test.sh generated and executable" "true" "$([ -x "$wt/test.sh" ] && echo true || echo false)"
    local build_sh test_sh
    build_sh="$(< "$wt/build.sh")"
    test_sh="$(< "$wt/test.sh")"
    assert_contains "build.sh opts in with --allow-overriding" "--allow-overriding" "$build_sh"
    assert_contains "test.sh opts in with --allow-overriding" "--allow-overriding" "$test_sh"
    assert_contains "build.sh computes the override list at run time (colcon list)" \
        "OVERRIDES=\"\$(colcon list --names-only --base-paths src" "$build_sh"
    assert_contains "test.sh computes the override list at run time (colcon list)" \
        "OVERRIDES=\"\$(colcon list --names-only --base-paths src" "$test_sh"
    assert_not_contains "build.sh never hard-codes a package name for --allow-overriding" \
        "--allow-overriding pkg_a" "$build_sh"
    assert_eq "build.sh is syntactically valid bash" "0" "$(bash -n "$wt/build.sh" >/dev/null 2>&1; echo $?)"
    assert_eq "test.sh is syntactically valid bash" "0" "$(bash -n "$wt/test.sh" >/dev/null 2>&1; echo $?)"
    assert_eq "manifest written" "true" "$([ -f "$wt/.worktree-repos" ] && echo true || echo false)"
    # No --base: the base is the manifest's pin of pkg_a, fakefox, a branch
    # on origin (issue 429), never origin's default branch by omission.
    assert_eq "no --base: the header records the pin as base=" \
        "# project=tiered issue=owner/pkg_a#111 layer=l1 base=fakefox" "$(head -n1 "$wt/.worktree-repos")"
    assert_contains "the banner names the base and where it came from" \
        "Base:       fakefox (from the project's pin of pkg_a;" "$out"
    assert_eq "the owning branch starts at origin's fakefox" \
        "$(git -C "$proj/layers/main/l1_ws/src/pkg_a" rev-parse refs/remotes/origin/fakefox)" \
        "$(git -C "$wt/l1_ws/src/pkg_a" rev-parse HEAD)"
    assert_eq "sourcing env.sh under set -e with no install present still exits 0" \
        "ok" "$(bash -c "set -e; source '$wt/env.sh'; echo ok" 2>&1)"
    assert_contains "enter banner uses the qualified issue and --project" \
        "worktree_enter.sh --issue owner/pkg_a#111 --type project --project tiered" "$out"
    assert_contains "remove banner uses the qualified issue and --project" \
        "worktree_remove.sh --issue owner/pkg_a#111 --type project --project tiered" "$out"
    assert_not_contains "banner never prints the bare number for a package worktree" \
        "--issue 111 --type project" "$out"
}

test_worktree_create_package_base_from_pin_or_refused() {
    echo "TEST: a package worktree without --base takes the pin; a pin that is no branch refuses before anything is made (issue 429)"
    local sb out rc=0 proj wt a
    sb="$(make_worktree_sandbox)"
    proj="$(make_lookup_project "$sb")"
    a="$proj/layers/main/l1_ws/src/pkg_a"
    # A tag pin: origin answers, so the kind is known, and it is no branch.
    git -C "$a" tag v9
    git -C "$a" push --quiet origin v9
    write_repos_file "$proj/configs/manifest/repos/l1.repos" v9 pkg_a pkg_b
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#120 --type project --project tiered \
        --layer l1 --package-repos pkg_b,pkg_a 2>&1)" || rc=$?
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-120"
    assert_eq "a tag pin, no --base: exits 1" "1" "$rc"
    assert_contains "the pin's own refusal" "pkg_a is pinned at v9 (tag); only a branch can be a base" "$out"
    assert_contains "creation says it needs a base and asks for --base" \
        "is not started from origin's default branch by omission; pass --base <branch>. Nothing was made." "$out"
    assert_eq "no aggregate dir" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "no owning branch made" "false" \
        "$(git -C "$a" show-ref --verify --quiet refs/heads/feature/issue-120 && echo true || echo false)"
    assert_eq "no sibling branch made" "false" \
        "$(git -C "$proj/layers/main/l1_ws/src/pkg_b" show-ref --verify --quiet refs/heads/feature/pkg_a-issue-120 && echo true || echo false)"
    # The same with --base: the override is the base.
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#120 --type project --project tiered \
        --layer l1 --package-repos pkg_b,pkg_a --base main 2>&1)" || rc=$?
    assert_eq "with --base main: exit 0" "0" "$rc"
    assert_eq "with --base main: base=main recorded" \
        "# project=tiered issue=owner/pkg_a#120 layer=l1 base=main" "$(head -n1 "$wt/.worktree-repos")"
    assert_contains "the banner says the base came from --base" "Base:       main (from --base;" "$out"
    # A worktree with no owning entry (only a sibling) has no base to resolve.
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#121 --type project --project tiered \
        --layer l1 --package-repos pkg_b 2>&1)" || rc=$?
    assert_eq "siblings only: exit 0 with the tag pin (no owning branch to start)" "0" "$rc"
    assert_eq "siblings only: no base= in the header" \
        "# project=tiered issue=owner/pkg_a#121 layer=l1" \
        "$(head -n1 "$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-121/.worktree-repos")"
}

test_worktree_create_package_existing_branch_needs_named_base() {
    echo "TEST: an owning branch that already exists gets base= only from a named --base, checked (issue 429)"
    local sb out rc=0 proj a b wt hosted_main
    sb="$(make_worktree_sandbox)"
    proj="$(make_lookup_project "$sb")"
    a="$proj/layers/main/l1_ws/src/pkg_a"
    b="$proj/layers/main/l1_ws/src/pkg_b"
    # origin's main moves one commit past the pin fakefox.
    git -C "$a" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m "main only"
    git -C "$a" push --quiet origin main
    hosted_main="$(git -C "$a" rev-parse main)"

    # A local branch started from fakefox, with work of its own, no --base:
    # the pin is not taken for it. Refused, the sibling added first (pkg_b,
    # listed first) rolled back, the existing branch kept.
    git -C "$a" branch feature/issue-130 origin/fakefox
    git -C "$a" checkout --quiet feature/issue-130
    git -C "$a" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m "own work"
    git -C "$a" checkout --quiet main
    local own130; own130="$(git -C "$a" rev-parse feature/issue-130)"
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#130 --type project --project tiered \
        --layer l1 --package-repos pkg_b,pkg_a 2>&1)" || rc=$?
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-130"
    assert_eq "existing branch, no --base: exits 1" "1" "$rc"
    assert_contains "says why: it already existed, the pin is not taken, name the base" \
        "'feature/issue-130' already existed (locally or on origin), so this workspace cannot know which branch it started from, and does not take the pin (fakefox) for it." "$out"
    assert_contains "and how to go on" "Pass --base naming the branch it was started from, or start 'feature/issue-130' anew" "$out"
    assert_contains "the sibling added first is rolled back" "rolling back 2 already-created worktree(s)" "$out"
    assert_eq "no aggregate dir" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "the sibling's new branch is removed" "false" \
        "$(git -C "$b" show-ref --verify --quiet refs/heads/feature/pkg_a-issue-130 && echo true || echo false)"
    assert_eq "the sibling's worktree is removed" "1" "$(git -C "$b" worktree list --porcelain | grep -c '^worktree ')"
    assert_eq "the existing owning branch is kept as it was" "$own130" "$(git -C "$a" rev-parse feature/issue-130)"
    # ... with the --base it was started from: recorded.
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#130 --type project --project tiered \
        --layer l1 --package-repos pkg_b,pkg_a --base fakefox 2>&1)" || rc=$?
    assert_eq "with --base fakefox: exit 0" "0" "$rc"
    assert_eq "with --base fakefox: recorded" \
        "# project=tiered issue=owner/pkg_a#130 layer=l1 base=fakefox" "$(head -n1 "$wt/.worktree-repos")"

    # Started from main, named main: recorded (where it started is the
    # owner's word; the check is that origin has it and history is shared).
    git -C "$a" branch feature/issue-131 main
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#131 --type project --project tiered \
        --layer l1 --package-repos pkg_a --base main 2>&1)" || rc=$?
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-131"
    assert_eq "existing branch from main, --base main: exit 0" "0" "$rc"
    assert_eq "existing branch from main, --base main: recorded" \
        "# project=tiered issue=owner/pkg_a#131 layer=l1 base=main" "$(head -n1 "$wt/.worktree-repos")"
    assert_eq "the branch is not moved" "$hosted_main" "$(git -C "$a" rev-parse feature/issue-131)"

    # A named base origin lacks: refused, rolled back.
    git -C "$a" branch feature/issue-133 main
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#133 --type project --project tiered \
        --layer l1 --package-repos pkg_a --base nosuch 2>&1)" || rc=$?
    assert_eq "existing branch, --base origin lacks: exits 1" "1" "$rc"
    assert_contains "says so" "'feature/issue-133' already existed, and --base nosuch cannot be its base: origin has no branch 'nosuch'." "$out"
    assert_eq "no aggregate dir" "false" "$([ -e "$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-133" ] && echo true || echo false)"

    # An orphan owning branch: no history in common with the named base.
    git -C "$a" checkout --quiet --orphan feature/issue-134
    git -C "$a" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m "orphan"
    git -C "$a" checkout --quiet main
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#134 --type project --project tiered \
        --layer l1 --package-repos pkg_a --base fakefox 2>&1)" || rc=$?
    assert_eq "orphan existing branch: exits 1" "1" "$rc"
    assert_contains "says there is no history in common" "'feature/issue-134' has no commit in common with origin's 'fakefox'" "$out"

    # A branch on origin only: checked out from origin, then the same rule.
    git -C "$a" push --quiet origin origin/fakefox:refs/heads/feature/issue-132
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#132 --type project --project tiered \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "branch on origin only, no --base: exits 1" "1" "$rc"
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#132 --type project --project tiered \
        --layer l1 --package-repos pkg_a --base fakefox 2>&1)" || rc=$?
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-132"
    assert_eq "branch on origin only, --base fakefox: exit 0" "0" "$rc"
    assert_eq "branch on origin only, --base fakefox: recorded" \
        "# project=tiered issue=owner/pkg_a#132 layer=l1 base=fakefox" "$(head -n1 "$wt/.worktree-repos")"
}

test_worktree_create_package_parent_issue_starts_from_parent() {
    echo "TEST: --parent-issue on a package worktree: the pin is not read; the branch starts from the parent's, which base= records (issue 429)"
    local sb out rc=0 proj a wt parent_tip
    sb="$(make_worktree_sandbox)"
    proj="$(make_lookup_project "$sb")"
    a="$proj/layers/main/l1_ws/src/pkg_a"
    # The parent's branch on origin, one commit past main; the pin is a tag,
    # which would refuse if it were read.
    git -C "$a" checkout --quiet -b feature/issue-10
    git -C "$a" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m "parent work"
    git -C "$a" push --quiet origin feature/issue-10
    git -C "$a" checkout --quiet main
    git -C "$a" branch --quiet -D feature/issue-10
    parent_tip="$(git -C "$a" rev-parse refs/remotes/origin/feature/issue-10)"
    git -C "$a" tag v9
    git -C "$a" push --quiet origin v9
    write_repos_file "$proj/configs/manifest/repos/l1.repos" v9 pkg_a pkg_b
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#12 --type project --project tiered \
        --layer l1 --package-repos pkg_a --parent-issue 10 2>&1)" || rc=$?
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-12"
    assert_eq "exit 0 (the tag pin is not read)" "0" "$rc"
    assert_eq "the branch starts at the parent's tip" "$parent_tip" "$(git -C "$wt/l1_ws/src/pkg_a" rev-parse HEAD)"
    assert_contains "the banner names the parent" "Parent:     #10 (feature/issue-10)" "$out"
    assert_contains "the banner names the parent's branch as the base" "Base:       feature/issue-10 (the parent's branch:" "$out"
    assert_not_contains "no pin-sourced base in the banner" "from the project's pin" "$out"
    assert_eq "base= records the parent's branch" \
        "# project=tiered issue=owner/pkg_a#12 layer=l1 base=feature/issue-10" "$(head -n1 "$wt/.worktree-repos")"
    # --base with --parent-issue stays refused.
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#13 --type project --project tiered \
        --layer l1 --package-repos pkg_a --parent-issue 10 --base main 2>&1)" || rc=$?
    assert_eq "--base with --parent-issue: exits 1" "1" "$rc"
    assert_contains "says so" "--base cannot be used with --parent-issue" "$out"
}

test_worktree_create_package_refuses_branch_and_empty_base() {
    echo "TEST: --branch and an empty or invalid --base are refused for a package worktree, before anything is made (issue 429)"
    local sb out rc=0 proj a
    sb="$(make_worktree_sandbox)"
    proj="$(make_lookup_project "$sb")"
    a="$proj/layers/main/l1_ws/src/pkg_a"
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#140 --type project --project tiered \
        --layer l1 --package-repos pkg_a --branch foo 2>&1)" || rc=$?
    assert_eq "--branch with --layer: exits 1" "1" "$rc"
    assert_contains "says why" "--branch is not valid for a package worktree (--layer): the adapter names each repository's branch" "$out"
    assert_eq "no branch foo made" "false" "$(git -C "$a" show-ref --verify --quiet refs/heads/foo && echo true || echo false)"
    assert_eq "no feature/issue-140 made" "false" \
        "$(git -C "$a" show-ref --verify --quiet refs/heads/feature/issue-140 && echo true || echo false)"
    local v
    for v in "" "-foo" "HEAD"; do
        rc=0
        out="$(run_worktree_create "$sb" --issue owner/pkg_a#140 --type project --project tiered \
            --layer l1 --package-repos pkg_a --base "$v" 2>&1)" || rc=$?
        assert_eq "--base '$v': exits 1" "1" "$rc"
        if [ -z "$v" ]; then
            assert_contains "--base '': refused, not ignored" "Error: --base requires a branch name" "$out"
        else
            assert_contains "--base '$v': refused" "Error: --base '$v' is not a valid branch name" "$out"
        fi
    done
    assert_eq "nothing made" "false" "$([ -e "$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-140" ] && echo true || echo false)"
}

test_worktree_create_package_hook_preflight_checks_package_repos() {
    echo "TEST: package worktree hook preflight checks the package repos that commit, not the enclosing project tree"
    local sb out rc=0 proj
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    make_committed_pkg_repo "$proj" l1 pkg_b
    mkdir -p "$proj/layers/main/l1_ws/install"
    touch "$proj/layers/main/l1_ws/install/local_setup.bash"
    # The enclosing workspace repo's hook is broken; the package repo's is
    # healthy. Only the package repo runs hooks for commits in this worktree.
    mkdir -p "$sb/.git/hooks" "$sb/.venv/bin"
    printf '#!/bin/sh\n' > "$sb/.venv/bin/python3"; chmod +x "$sb/.venv/bin/python3"
    printf '#!/usr/bin/env bash\n# start templated\nINSTALL_PYTHON=%s\n# end templated\nexit 0\n' \
        "$sb/gone/.venv/bin/python3" > "$sb/.git/hooks/pre-commit"
    chmod +x "$sb/.git/hooks/pre-commit"
    printf '#!/usr/bin/env bash\n# start templated\nINSTALL_PYTHON=%s\n# end templated\nexit 0\n' \
        "$sb/.venv/bin/python3" > "$proj/layers/main/l1_ws/src/pkg_a/.git/hooks/pre-commit"
    chmod +x "$proj/layers/main/l1_ws/src/pkg_a/.git/hooks/pre-commit"
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#112 --type project --project tiered \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_not_contains "healthy package hook: no warning about the enclosing repo's broken hook" \
        "no longer exists" "$out"
    # Now break the package repo's hook: the warning names that repo.
    printf '#!/usr/bin/env bash\n# start templated\nINSTALL_PYTHON=%s\n# end templated\nexit 0\n' \
        "$sb/gone/.venv/bin/python3" > "$proj/layers/main/l1_ws/src/pkg_a/.git/hooks/pre-commit"
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#113 --type project --project tiered \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "exit 0 (warning is advisory)" "0" "$rc"
    assert_contains "broken package hook: warning names the package repo" \
        "no longer exists ($proj/layers/main/l1_ws/src/pkg_a)" "$out"
    assert_contains "broken package hook: repair root is the package repo" \
        "make -C \"$proj/layers/main/l1_ws/src/pkg_a\" repair" "$out"
}

test_worktree_create_rolls_back_on_second_repo_failure() {
    echo "TEST: a failure on the second repo rolls back the first and leaves no aggregate dir"
    local sb out rc=0 proj wt
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    # pkg_b exists but is NOT a git repo — worktree_repos still lists it
    # (validated by adapter_worktree_repos only checking existence + git-ness
    # at read time, both present-but-non-git here), so its `git worktree add`
    # must fail and trigger rollback of pkg_a.
    mkdir -p "$proj/layers/main/l1_ws/src/pkg_b"
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#222 --type project --project tiered \
        --layer l1 --package-repos pkg_a,pkg_b 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-222"
    assert_eq "no aggregate dir left behind" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "pkg_a's worktree removed from the origin repo" \
        "" "$(git -C "$proj/layers/main/l1_ws/src/pkg_a" worktree list --porcelain \
            | grep -A2 "worktree $wt" || true)"
    assert_contains "captured stderr surfaced" "not a git repository" "$out"
}

# ---- The named-branch lookup's stop on the package path (#323) ----
# These run worktree_create.sh WITHOUT --allow-unverified-branch. Their
# origin URLs no longer name owner/pkg_a, so worktree_repos treats no repo
# as the issue's own and names every branch feature/pkg_a-issue-<N>.

run_worktree_create_strict() {
    local sb="$1"
    shift
    (cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_create.sh" "$@")
}

# Give a package repo a reachable bare origin holding its main.
give_bare_origin() {  # <repo> <bare>
    local repo="$1" bare="$2"
    git init --quiet --bare -b main "$bare"
    git -C "$repo" remote set-url origin "$bare"
    git -C "$repo" push --quiet origin main
    git -C "$repo" fetch --quiet origin
    git -C "$repo" remote set-head origin main >/dev/null
}

# A package-worktree project with pkg_a and pkg_b, ready for a successful run.
make_lookup_project() {  # <sb>; prints the project dir
    local sb="$1" proj
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    make_committed_pkg_repo "$proj" l1 pkg_b
    mkdir -p "$proj/layers/main/l1_ws/install"
    touch "$proj/layers/main/l1_ws/install/local_setup.bash"
    echo "$proj"
}

lookup_stop_message() {  # <repo> <branch> <git's line>
    printf "ERROR: cannot tell whether origin has '%s' (in %s): fetching '%s' failed (%s), and origin could not be asked whether it has '%s'; a new '%s' is not started, since it would diverge from one origin may have. Retry when origin answers (for a slow origin, raise WT_FETCH_TIMEOUT, now 60s), or pass --allow-unverified-branch to start it anyway." \
        "$2" "$1" "$2" "$3" "$2" "$2"
}

test_worktree_create_lookup_unknown_first_repo() {
    echo "TEST: origin cannot tell on the first repo: stop, nothing made, the whole reason given"
    local sb out rc=0 proj a wt line
    sb="$(make_worktree_sandbox)"
    proj="$(make_lookup_project "$sb")"
    a="$proj/layers/main/l1_ws/src/pkg_a"
    git -C "$a" remote set-url origin "file:///nonexistent/pkg_a.git"
    line="$(git -C "$a" fetch --quiet origin 2>&1 | head -n1)" || true
    out="$(run_worktree_create_strict "$sb" --issue owner/pkg_a#444 --type project --project tiered \
        --layer l1 --package-repos pkg_a,pkg_b 2>&1)" || rc=$?
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-444"
    assert_eq "exits 1" "1" "$rc"
    assert_contains "the stop names the branch, the repo and the whole reason" \
        "$(lookup_stop_message "$a" feature/pkg_a-issue-444 "$line")" "$out"
    assert_eq "no aggregate dir" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "no branch made in pkg_a" "false" \
        "$(git -C "$a" show-ref --verify --quiet refs/heads/feature/pkg_a-issue-444 && echo true || echo false)"
}

test_worktree_create_lookup_unknown_second_repo() {
    echo "TEST: origin cannot tell on the second repo: stop, the first repo's worktree and branch rolled back"
    local sb out rc=0 proj a b wt line
    sb="$(make_worktree_sandbox)"
    proj="$(make_lookup_project "$sb")"
    a="$proj/layers/main/l1_ws/src/pkg_a"
    b="$proj/layers/main/l1_ws/src/pkg_b"
    give_bare_origin "$a" "$sb/pkg_a-origin.git"
    git -C "$b" remote set-url origin "file:///nonexistent/pkg_b.git"
    line="$(git -C "$b" fetch --quiet origin 2>&1 | head -n1)" || true
    out="$(run_worktree_create_strict "$sb" --issue owner/pkg_a#445 --type project --project tiered \
        --layer l1 --package-repos pkg_a,pkg_b 2>&1)" || rc=$?
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-445"
    assert_eq "exits 1" "1" "$rc"
    assert_contains "the stop names pkg_b's branch and the whole reason" \
        "$(lookup_stop_message "$b" feature/pkg_a-issue-445 "$line")" "$out"
    assert_contains "the rollback is reported" "rolling back 1 already-created worktree(s)" "$out"
    assert_eq "no aggregate dir" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "pkg_a's worktree removed" "1" "$(git -C "$a" worktree list --porcelain | grep -c '^worktree ')"
    assert_eq "pkg_a's new branch removed" "false" \
        "$(git -C "$a" show-ref --verify --quiet refs/heads/feature/pkg_a-issue-445 && echo true || echo false)"
    assert_eq "no branch made in pkg_b" "false" \
        "$(git -C "$b" show-ref --verify --quiet refs/heads/feature/pkg_a-issue-445 && echo true || echo false)"
}

test_worktree_create_lookup_found_branch_fails_checkout() {
    echo "TEST: a branch found on origin that fails to check out: stop, no branch or worktree left"
    local sb out rc=0 proj a wt
    sb="$(make_worktree_sandbox)"
    proj="$(make_lookup_project "$sb")"
    a="$proj/layers/main/l1_ws/src/pkg_a"
    give_bare_origin "$a" "$sb/pkg_a-origin.git"
    # feature/pkg_a-issue-446 on origin only.
    git -C "$a" checkout --quiet -b feature/pkg_a-issue-446
    git -C "$a" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m "446 on origin"
    git -C "$a" push --quiet origin feature/pkg_a-issue-446
    git -C "$a" checkout --quiet main
    git -C "$a" branch --quiet -D feature/pkg_a-issue-446
    git -C "$a" update-ref -d refs/remotes/origin/feature/pkg_a-issue-446
    printf '#!/bin/sh\nexit 1\n' > "$a/.git/hooks/post-checkout"
    chmod +x "$a/.git/hooks/post-checkout"
    out="$(run_worktree_create_strict "$sb" --issue owner/pkg_a#446 --type project --project tiered \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    rm -f "$a/.git/hooks/post-checkout"
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-446"
    assert_eq "exits 1" "1" "$rc"
    assert_contains "the failure names the repo, the destination and the branch" \
        "ERROR: could not create a worktree for $a at $wt/l1_ws/src/pkg_a (branch 'feature/pkg_a-issue-446')" "$out"
    assert_contains "the branch it made is removed again" \
        "The branch 'feature/pkg_a-issue-446' made for it was removed again." "$out"
    assert_not_contains "never started from the default instead" "Creating new branch" "$out"
    assert_eq "no aggregate dir" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "no local branch left" "false" \
        "$(git -C "$a" show-ref --verify --quiet refs/heads/feature/pkg_a-issue-446 && echo true || echo false)"
    assert_eq "no worktree left registered" "1" "$(git -C "$a" worktree list --porcelain | grep -c '^worktree ')"
}

test_worktree_create_rollback_on_worktree_env_failure() {
    echo "TEST: worktree_env failing after a successful add rolls back the add, dir, and branch"
    local sb out rc=0 proj wt
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    # Break distro resolution (an environment problem unrelated to the add
    # itself, discovered only after the package worktree already exists —
    # worktree_env runs after every add has succeeded).
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\n' \
        > "$proj/configs/manifest/bootstrap.yaml"
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#333 --type project --project tiered \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-333"
    assert_eq "no aggregate dir left behind" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "package repo's worktree list shows only the main checkout" \
        "1" "$(git -C "$proj/layers/main/l1_ws/src/pkg_a" worktree list --porcelain | grep -c '^worktree ')"
    assert_eq "the branch created for the (rolled-back) add does not exist" \
        "false" "$(git -C "$proj/layers/main/l1_ws/src/pkg_a" show-ref --verify --quiet refs/heads/feature/issue-333 \
            && echo true || echo false)"
    assert_contains "reports the rollback" "rolling back" "$out"
    assert_contains "names the underlying failure" "cannot resolve the ROS distro" "$out"
}

test_worktree_remove_multi_package_dirty_refuses_all() {
    echo "TEST: dirty entry anywhere refuses the whole removal before touching anything"
    local sb out rc=0 proj wt
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    make_committed_pkg_repo "$proj" l1 pkg_b
    run_worktree_create "$sb" --issue owner/pkg_a#333 --type project --project tiered \
        --layer l1 --package-repos pkg_a,pkg_b >/dev/null 2>&1
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-333"
    echo dirty >> "$wt/l1_ws/src/pkg_b/README.md"
    out="$(run_worktree_remove "$sb" --issue owner/pkg_a#333 --type project --project tiered 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the dirty entry" "l1_ws/src/pkg_b" "$out"
    assert_eq "nothing removed: pkg_a worktree still present" \
        "true" "$([ -d "$wt/l1_ws/src/pkg_a" ] && echo true || echo false)"
    assert_eq "nothing removed: pkg_b worktree still present" \
        "true" "$([ -d "$wt/l1_ws/src/pkg_b" ] && echo true || echo false)"
    rc=0
    out="$(run_worktree_remove "$sb" --issue owner/pkg_a#333 --type project --project tiered --force 2>&1)" || rc=$?
    assert_eq "--force removes it" "0" "$rc"
    assert_eq "aggregate dir gone" "false" "$([ -e "$wt" ] && echo true || echo false)"
}

test_worktree_list_json_reports_package_worktree() {
    echo "TEST: worktree_list.sh --json reports issue/project/branches/dirty for a nested worktree"
    local sb out rc=0 proj wt
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    make_committed_pkg_repo "$proj" l1 pkg_b
    run_worktree_create "$sb" --issue owner/pkg_a#444 --type project --project tiered \
        --layer l1 --package-repos pkg_a,pkg_b >/dev/null 2>&1
    wt="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-444"
    echo dirty >> "$wt/l1_ws/src/pkg_b/README.md"
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && "$sb/.agent/scripts/worktree_list.sh" --json)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "issue 444 reported" '"issue":444' "$out"
    assert_contains "project tiered reported as repo" '"repo":"tiered"' "$out"
    assert_contains "owning branch reported" "feature/issue-444" "$out"
    assert_contains "sibling branch reported" "feature/pkg_a-issue-444" "$out"
    assert_contains "dirty status reported" '"status":"dirty"' "$out"
}

run_worktree_enter_print_path() {
    local sb="$1"
    shift
    (cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_enter.sh" --print-path "$@")
}

test_worktree_enter_disambiguates_by_qualified_issue() {
    echo "TEST: qualified --issue resolves each of two same-N package worktrees; bare N errors with the hint"
    local sb out rc=0 proj wt_a wt_c
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    make_committed_pkg_repo "$proj" l2 pkg_c
    run_worktree_create "$sb" --issue owner/pkg_a#555 --type project --project tiered \
        --layer l1 --package-repos pkg_a >/dev/null 2>&1
    run_worktree_create "$sb" --issue owner/pkg_c#555 --type project --project tiered \
        --layer l2 --package-repos pkg_c >/dev/null 2>&1
    wt_a="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_a-555"
    wt_c="$sb/projects/tiered/worktrees/issue-tiered-owner-pkg_c-555"
    assert_eq "pkg_a worktree exists" "true" "$([ -d "$wt_a" ] && echo true || echo false)"
    assert_eq "pkg_c worktree exists" "true" "$([ -d "$wt_c" ] && echo true || echo false)"

    out="$(run_worktree_enter_print_path "$sb" --issue owner/pkg_a#555 --type project --project tiered 2>&1)" || rc=$?
    assert_eq "qualified issue for pkg_a resolves to pkg_a's worktree" "0" "$rc"
    assert_eq "resolved path is pkg_a's" "$wt_a" "$out"

    rc=0
    out="$(run_worktree_enter_print_path "$sb" --issue owner/pkg_c#555 --type project --project tiered 2>&1)" || rc=$?
    assert_eq "qualified issue for pkg_c resolves to pkg_c's worktree" "0" "$rc"
    assert_eq "resolved path is pkg_c's" "$wt_c" "$out"

    rc=0
    out="$(run_worktree_enter_print_path "$sb" --issue 555 --type project --project tiered 2>&1)" || rc=$?
    assert_eq "bare number is ambiguous: exits nonzero" "1" "$rc"
    assert_contains "names both candidates" "issue-tiered-owner-pkg_a-555" "$out"
    assert_contains "names both candidates (2)" "issue-tiered-owner-pkg_c-555" "$out"
    assert_contains "points at the qualified form, not --repo-slug" \
        "--repo-slug cannot" "$out"
    assert_contains "gives the qualified ref for pkg_a" "--issue owner/pkg_a#555" "$out"
    assert_contains "gives the qualified ref for pkg_c" "--issue owner/pkg_c#555" "$out"
}

# Replace the sandbox's _issue_helpers.sh with a stub that records the
# --repo it's called with (issue_lookup) to $ISSUE_LOOKUP_LOG, instead of
# doing any real lookup. extract_gh_slug (still needed by
# worktree_create.sh's own remote-URL parsing) is the real one: the stub
# sources the real _issue_helpers.sh (it only defines functions), then
# replaces issue_lookup, so no copy can fall behind (issue 428).
stub_issue_lookup_recorder() {
    local sb="$1"
    printf 'source %q\n' "$REAL_ROOT/.agent/scripts/_issue_helpers.sh" > "$sb/.agent/scripts/_issue_helpers.sh"
    cat >> "$sb/.agent/scripts/_issue_helpers.sh" << 'STUBEOF'
issue_lookup() {
    local issue_num="" repo_slug="" root_dir=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo) repo_slug="$2"; shift 2 ;;
            --root) root_dir="$2"; shift 2 ;;
            *) issue_num="$1"; shift ;;
        esac
    done
    printf '%s\n' "$repo_slug" >> "${ISSUE_LOOKUP_LOG:?}"
    ISSUE_TITLE="stub title"
    ISSUE_STATE="OPEN"
    ISSUE_BODY=""
    return 0
}
STUBEOF
}

test_worktree_create_issue_lookup_uses_qualified_repo() {
    echo "TEST: a qualified --issue looks up its own repo, not the project/workspace remote"
    local sb out rc=0 proj log
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    # The workspace stand-in has its OWN remote — pre-#252 code would have
    # resolved the lookup repo from this (or the registered project's own
    # remote, which for ros2_colcon is the hosting dir and isn't a git repo
    # at all) instead of the issue's qualified owner/repo.
    git -C "$sb" remote add origin "git@github.com:rolker/agent_workspace.git"
    stub_issue_lookup_recorder "$sb"
    # The stub's extract_gh_slug is the real one: an scp-form origin on
    # another host gives no slug (the old copy gave "git@gitlab.com:o/r").
    assert_eq "stub's extract_gh_slug is the real one (non-GitHub origin: no slug)" "" \
        "$(source "$sb/.agent/scripts/_issue_helpers.sh" && extract_gh_slug "git@gitlab.com:o/r.git")"
    assert_eq "stub's extract_gh_slug is the real one (GitHub origin)" "o/r" \
        "$(source "$sb/.agent/scripts/_issue_helpers.sh" && extract_gh_slug "git@github.com:o/r.git")"
    log="$sb/issue_lookup.log"
    : > "$log"
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/stubbin:$PATH" ISSUE_LOOKUP_LOG="$log" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue rolker/ros2_network_monitor#27 \
        --type project --project tiered --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "issue_lookup called with exactly the qualified repo" \
        "rolker/ros2_network_monitor" "$(< "$log")"
    assert_contains "printed issue line names the qualified ref" \
        "Issue rolker/ros2_network_monitor#27:" "$out"
    assert_not_contains "workspace remote's repo never used" "rolker/agent_workspace" "$(< "$log")"
}

# ---- Contract & validator ----

test_validator_accepts_ros2_colcon() {
    echo "TEST: validate_adapter passes with the ros2_colcon type present"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "ros2_colcon complete" "ros2_colcon: all 13 verbs implemented" "$out"
    assert_contains "single_project still complete" "single_project: all 13 verbs implemented" "$out"
}

# ---- Distro resolution ----

test_distro_from_bootstrap_yaml() {
    echo "TEST: distro resolves from bootstrap.yaml and locates the underlay"
    local sb out
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_colcon_project "$sb" >/dev/null
    out="$(run_adapter "$sb" env)" || true
    assert_contains "underlay sourced from declared distro" "rosroot/fakefox/setup.bash" "$out"
}

test_distro_from_project_config() {
    echo "TEST: a ROS_DISTRO in a retired projects.d/<name>.sh or the shared project_config.sh is not read (issue #265 part 4)"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    # The manifest declares no distro; only the retired files do.
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\n' \
        > "$proj/configs/manifest/bootstrap.yaml"
    echo 'ROS_DISTRO="fakefox"' > "$sb/.agent/projects.d/tiered.sh"
    echo 'ROS_DISTRO="fakefox"' > "$sb/.agent/project_config.sh"
    out="$(run_adapter "$sb" env 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "cannot resolve the distro" "cannot resolve the ROS distro" "$out"
    assert_contains "names the registry line" "distro=<name> on the project's line" "$out"
    assert_not_contains "never offers the retired files" "ROS_DISTRO=<name>" "$out"
    assert_not_contains "no underlay from a retired file" "rosroot/fakefox/setup.bash" "$out"
}


test_distro_from_registry() {
    echo "TEST: distro= on the registry line wins; mismatch with the manifest fails loud (#265)"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    # Manifest silent on distro; registry declares it.
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\n' \
        > "$proj/configs/manifest/bootstrap.yaml"
    make_underlay "$sb" regfox
    sed -i'' -e "s|^tiered ros2_colcon.*|tiered ros2_colcon $proj distro=regfox|" "$sb/.agent/projects.local"
    out="$(run_adapter "$sb" env)" || true
    assert_contains "underlay from registry distro" "rosroot/regfox/setup.bash" "$out"
    # Registry and manifest agree: fine.
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\ndistro: regfox\n' \
        > "$proj/configs/manifest/bootstrap.yaml"
    out="$(run_adapter "$sb" env)" || true
    assert_contains "agreeing sources resolve" "rosroot/regfox/setup.bash" "$out"
    # Registry says regfox, manifest says fakefox: hard error.
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\ndistro: fakefox\n' \
        > "$proj/configs/manifest/bootstrap.yaml"
    out="$(run_adapter "$sb" env 2>&1)" || rc=$?
    assert_eq "mismatch exits nonzero" "1" "$rc"
    assert_contains "names both values" "registry says distro 'regfox'" "$out"
    assert_contains "names the manifest value" "says 'fakefox'" "$out"
}

test_distro_unresolvable_fails() {
    echo "TEST: undeclared distro fails loudly (no silent default)"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\n' \
        > "$proj/configs/manifest/bootstrap.yaml"
    out="$(run_adapter "$sb" env 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "explains how to declare" "cannot resolve the ROS distro" "$out"
}

test_missing_underlay_fails() {
    echo "TEST: missing distro underlay fails naming the expected path"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_colcon_project "$sb" >/dev/null
    rm -rf "$sb/rosroot/fakefox"
    out="$(run_adapter "$sb" env 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing underlay" "rosroot/fakefox/setup.bash" "$out"
}

test_missing_manifest_fails() {
    echo "TEST: hosting dir without a manifest fails with guidance"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    mkdir -p "$sb/projects/tiered"
    echo "tiered ros2_colcon projects/tiered" >> "$sb/.agent/projects.local"
    out="$(run_adapter "$sb" env 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "points at the expected manifest" "configs/manifest" "$out"
}

test_empty_layers_fails() {
    echo "TEST: an empty/comment-only layers.txt fails loudly instead of no-op success"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    printf '# no layers yet\n\n' > "$proj/configs/manifest/layers.txt"
    out="$(run_adapter "$sb" build 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the empty manifest" "defines no layers" "$out"
    assert_not_contains "no phantom success" "All layers built successfully" "$out"
}

test_traversal_layer_name_fails() {
    echo "TEST: a path-traversal layer name in layers.txt is rejected"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    printf 'l1\n../../escape\n' > "$proj/configs/manifest/layers.txt"
    out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the offending entry" "invalid layer name '../../escape'" "$out"
    assert_eq "nothing imported before the check" \
        "no" "$([ -f "$sb/vcs.log" ] && echo yes || echo no)"
}

test_broken_config_fails() {
    echo "TEST: ROS_ROOT_DIR comes from the environment (default /opt/ros); a retired config file is never sourced (issue #265 part 4)"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    # A retired config that would fail if sourced, and would point
    # ROS_ROOT_DIR elsewhere: neither happens.
    {
        echo "ROS_ROOT_DIR=\"$sb/elsewhere\""
        echo "false"
    } > "$sb/.agent/projects.d/tiered.sh"
    cp "$sb/.agent/projects.d/tiered.sh" "$sb/.agent/project_config.sh"
    out="$(run_adapter "$sb" env 2>&1)" || rc=$?
    assert_eq "exit 0: the config is not sourced" "0" "$rc"
    assert_contains "the underlay from the environment's ROS_ROOT_DIR" "$sb/rosroot/fakefox/setup.bash" "$out"
    assert_not_contains "no 'failed to source'" "failed to source" "$out"
    # Unset: the default /opt/ros (a fakefox underlay there never exists).
    rc=0
    out="$(cd "$sb" && unset ROS_ROOT_DIR && PATH="$sb/bin:$PATH" "$sb/.agent/scripts/adapter" --project tiered env 2>&1)" || rc=$?
    assert_eq "unset: exits nonzero" "1" "$rc"
    assert_contains "unset: names the default underlay" "/opt/ros/fakefox/setup.bash" "$out"
    assert_contains "unset: says how to point it elsewhere" "set ROS_ROOT_DIR in the environment" "$out"
}

# ---- env verb ----

test_env_chain_order() {
    echo "TEST: env emits scrub + underlay + built layers in layers.txt order"
    local sb out proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    # l1 and l2 are built; l3 is not (no install/).
    mkdir -p "$proj/layers/main/l1_ws/install" "$proj/layers/main/l2_ws/install"
    touch "$proj/layers/main/l1_ws/install/local_setup.bash"
    touch "$proj/layers/main/l2_ws/install/local_setup.bash"
    out="$(run_adapter "$sb" env)" || true
    assert_contains "prefix-path scrub first" "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH" "$out"
    local expected
    expected="unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
source $sb/rosroot/fakefox/setup.bash
source $proj/layers/main/l1_ws/install/local_setup.bash
source $proj/layers/main/l2_ws/install/local_setup.bash"
    assert_eq "exact chain, in order, unbuilt layer omitted" "$expected" "$out"
}

# ---- setup verb ----

test_setup_imports_each_layer() {
    echo "TEST: setup imports every layer's repos via vcs into src/"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "three imports logged in layer order" \
        "VCS_IMPORT:$proj/layers/main/l1_ws/src
VCS_IMPORT:$proj/layers/main/l2_ws/src
VCS_IMPORT:$proj/layers/main/l3_ws/src" "$(cat "$sb/vcs.log")"
    assert_contains "l1 got its own repos file" "pkg_a" "$(cat "$proj/layers/main/l1_ws/src/.vcs_input")"
    assert_contains "l2 got its own repos file" "pkg_c" "$(cat "$proj/layers/main/l2_ws/src/.vcs_input")"
}

test_setup_optional_layer_failure_tolerated() {
    echo "TEST: optional layer import failure warns and continues"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_colcon_project "$sb" >/dev/null
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" VCS_FAIL_LAYERS="l3" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "setup still exits 0" "0" "$rc"
    assert_contains "warns about the optional layer" "optional layer 'l3'" "$out"
}

test_setup_required_layer_failure_aborts() {
    echo "TEST: non-optional layer import failure aborts setup"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_colcon_project "$sb" >/dev/null
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" VCS_FAIL_LAYERS="l2" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the failing layer" "vcs import failed for layer 'l2'" "$out"
}

test_setup_requires_vcs() {
    echo "TEST: setup without vcstool fails loudly"
    local sb out rc=0 tool
    sb="$(make_sandbox)"
    make_colcon_project "$sb" >/dev/null
    # The host may have real vcstool installed, so an isolated PATH with
    # only the tools the dispatcher/adapter need — and no vcs — is the
    # only deterministic way to exercise the not-found branch.
    mkdir -p "$sb/isolatedbin"
    for tool in bash sh git grep sed awk cut head tail cat mkdir rm mv ln \
        basename dirname printf env ls sort wc; do
        command -v "$tool" >/dev/null 2>&1 \
            && ln -s "$(command -v "$tool")" "$sb/isolatedbin/$tool"
    done
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/isolatedbin" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing tool" "'vcs' (vcstool) not found" "$out"
}

# The real-tool test with no vcs on PATH: a loud skip, counted, when
# ROS2_COLCON_TESTS_REQUIRE_VCS is unset; a failure when it is set. Each
# case runs in a subshell with an empty PATH (the function returns before
# it needs any external tool) and sets or unsets the variable there, as this
# suite itself runs in CI with the variable set. The subshell prints its
# counters, so the suite's own PASS, FAIL and TOOL_SKIPPED stay untouched.
test_real_tool_case_without_vcs() {
    echo "TEST: the real-tool test without vcs skips, or fails where vcs is required"
    local emptybin out
    emptybin="$(mktemp -d -p "$SANDBOX")"
    out="$(unset ROS2_COLCON_TESTS_REQUIRE_VCS; PATH="$emptybin"; TOOL_SKIPPED=0; FAIL=0
        test_tool_real_init_and_sync
        echo "counters: TOOL_SKIPPED=$TOOL_SKIPPED FAIL=$FAIL")"
    assert_contains "variable unset: skips, saying so" "SKIPPED: vcs is not on PATH" "$out"
    assert_contains "variable unset: the skip is counted, no failure" \
        "counters: TOOL_SKIPPED=1 FAIL=0" "$out"
    out="$(export ROS2_COLCON_TESTS_REQUIRE_VCS=1; PATH="$emptybin"; TOOL_SKIPPED=0; FAIL=0
        test_tool_real_init_and_sync
        echo "counters: TOOL_SKIPPED=$TOOL_SKIPPED FAIL=$FAIL")"
    assert_contains "variable set: fails, naming vcs" \
        "FAIL: vcs is not on PATH, though ROS2_COLCON_TESTS_REQUIRE_VCS" "$out"
    assert_contains "variable set: counted as a failure, not a skip" \
        "counters: TOOL_SKIPPED=0 FAIL=1" "$out"
}

# ---- setup: manifest bootstrap (#237) ----

# A local "remote" manifest repo (git, branch fakefox) whose config dir holds
# a one-layer manifest, plus a bootstrap.yaml served via file:// (curl
# handles file URLs, so no network and no stub). Pattern B when a layer is
# given, Pattern A otherwise. Prints the bootstrap.yaml URL.
make_manifest_remote() {
    local sb="$1" layer="${2:-}" config_path="${3:-config}"
    local repo="$sb/remote/manifest_repo"
    mkdir -p "$repo/$config_path/repos"
    printf 'l1\n' > "$repo/$config_path/layers.txt"
    printf 'distro: fakefox\n' > "$repo/$config_path/bootstrap.yaml"
    write_repos_file "$repo/$config_path/repos/l1.repos" fakefox pkg_a
    git -C "$repo" init --quiet -b fakefox
    git -C "$repo" -c user.name=t -c user.email=t@t add -A
    git -C "$repo" -c user.name=t -c user.email=t@t commit --quiet -m init
    {
        echo "git_url: file://$repo"
        echo "branch: fakefox"
        [ -n "$layer" ] && echo "layer: $layer"
        [ "$config_path" != "config" ] && echo "config_path: $config_path"
        true
    } > "$sb/remote/bootstrap.yaml"
    echo "file://$sb/remote/bootstrap.yaml"
}

# Fresh (empty) hosting dir registered as tiered with the sandbox underlay.
make_fresh_project() {
    local sb="$1"
    mkdir -p "$sb/projects/tiered"
    echo "tiered ros2_colcon projects/tiered" >> "$sb/.agent/projects.local"
    make_underlay "$sb"
    echo "$sb/projects/tiered"
}

test_setup_bootstraps_manifest_pattern_b() {
    echo "TEST: setup on a fresh hosting dir bootstraps a Pattern B manifest from the settings file's bootstrap_url"
    local sb out rc=0 proj url
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_fresh_project "$sb")"
    url="$(make_manifest_remote "$sb" l1)"
    printf 'bootstrap_url=%s\n' "$url" > "$sb/.agent/projects.d/tiered"
    out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "reports Pattern B" "Pattern B: layer=l1" "$out"
    assert_eq "manifest repo cloned into the layer's src" \
        "true" "$([ -d "$proj/layers/main/l1_ws/src/manifest_repo/.git" ] && echo true || echo false)"
    assert_eq "configs/manifest is a relative symlink into the clone" \
        "../layers/main/l1_ws/src/manifest_repo/config" "$(readlink "$proj/configs/manifest")"
    assert_eq "layer import ran after bootstrap" \
        "VCS_IMPORT:$proj/layers/main/l1_ws/src" "$(cat "$sb/vcs.log")"
    # Idempotent: a second setup must not re-fetch or re-clone.
    rc=0
    out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "second setup exits 0" "0" "$rc"
    assert_not_contains "second setup does not fetch again" "Fetching bootstrap" "$out"
}

test_setup_bootstraps_pattern_a_from_url_file() {
    echo "TEST: bootstrap falls back to configs/project_bootstrap.url; Pattern A clones standalone"
    local sb out rc=0 proj url
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_fresh_project "$sb")"
    url="$(make_manifest_remote "$sb" "" manifests/site)"
    mkdir -p "$proj/configs"
    printf '  %s \n' "$url" > "$proj/configs/project_bootstrap.url"
    out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "reports Pattern A" "Pattern A" "$out"
    assert_eq "clone lands under configs/manifest_repo" \
        "true" "$([ -d "$proj/configs/manifest_repo/manifest_repo/.git" ] && echo true || echo false)"
    assert_eq "symlink honours config_path" \
        "manifest_repo/manifest_repo/manifests/site" "$(readlink "$proj/configs/manifest")"
}

test_setup_bootstrap_env_url_wins() {
    echo "TEST: BOOTSTRAP_URL in the environment overrides the settings file and the url file"
    local sb out rc=0 proj url
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_fresh_project "$sb")"
    url="$(make_manifest_remote "$sb" l1)"
    printf 'bootstrap_url=file:///nonexistent/config.yaml\n' > "$sb/.agent/projects.d/tiered"
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "fetched the env URL" "Fetching bootstrap config from $url" "$out"
    assert_eq "manifest present" "true" "$([ -f "$proj/configs/manifest/layers.txt" ] && echo true || echo false)"
}

test_setup_bootstrap_shared_url_is_reported() {
    echo "TEST: a MANIFEST_BOOTSTRAP_URL in the shared project_config.sh or a legacy .sh is not read; the settings file's is (issue #265 part 4)"
    local sb out rc url

    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_fresh_project "$sb" >/dev/null
    url="$(make_manifest_remote "$sb" l1)"
    printf 'MANIFEST_BOOTSTRAP_URL="%s"\n' "$url" > "$sb/.agent/project_config.sh"
    printf 'MANIFEST_BOOTSTRAP_URL="%s"\n' "$url" > "$sb/.agent/projects.d/tiered.sh"
    rc=0; out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "retired files only: exit 1" "1" "$rc"
    assert_contains "retired files only: no bootstrap URL" "no bootstrap URL to fetch one" "$out"
    assert_not_contains "retired files only: not fetched" "Fetching bootstrap config" "$out"
    assert_contains "retired files only: the settings command is offered" "project_setting.sh set tiered bootstrap_url=<url>" "$out"

    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_fresh_project "$sb" >/dev/null
    url="$(make_manifest_remote "$sb" l1)"
    printf 'MANIFEST_BOOTSTRAP_URL="file:///nonexistent/shared.yaml"\n' > "$sb/.agent/project_config.sh"
    printf 'bootstrap_url=%s\n' "$url" > "$sb/.agent/projects.d/tiered"
    rc=0; out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "settings-file URL: exit 0" "0" "$rc"
    assert_contains "settings-file URL: fetched" "Fetching bootstrap config from $url" "$out"
}

test_setup_fresh_dir_without_url_fails() {
    echo "TEST: fresh hosting dir with no bootstrap URL fails with guidance"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_fresh_project "$sb" >/dev/null
    out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing URL" "no bootstrap URL" "$out"
    assert_contains "names the settings command" "project_setting.sh set tiered bootstrap_url=<url>" "$out"
    assert_not_contains "never offers a retired config file" "MANIFEST_BOOTSTRAP_URL" "$out"
}

test_setup_bootstrap_rejects_unsafe_fields() {
    echo "TEST: bootstrap rejects traversal in config_path and invalid layer names"
    local sb out rc=0 proj url
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_fresh_project "$sb")"
    url="$(make_manifest_remote "$sb" l1)"
    printf 'git_url: file://%s/remote/manifest_repo\nbranch: fakefox\nconfig_path: ../../etc\n' "$sb" \
        > "$sb/remote/bootstrap.yaml"
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "traversal config_path exits nonzero" "1" "$rc"
    assert_contains "names config_path" "invalid 'config_path'" "$out"
    assert_eq "nothing cloned" "false" "$([ -e "$proj/configs/manifest_repo" ] && echo true || echo false)"
    printf 'git_url: file://%s/remote/manifest_repo\nbranch: fakefox\nlayer: ../x\n' "$sb" \
        > "$sb/remote/bootstrap.yaml"
    rc=0
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "bad layer exits nonzero" "1" "$rc"
    assert_contains "names layer" "invalid 'layer'" "$out"
}

test_setup_bootstrap_missing_fields_fails() {
    echo "TEST: bootstrap.yaml without git_url/branch fails before cloning"
    local sb out rc=0 url
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_fresh_project "$sb" >/dev/null
    url="$(make_manifest_remote "$sb" l1)"
    printf 'branch: fakefox\n' > "$sb/remote/bootstrap.yaml"
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the fields" "must define 'git_url' and 'branch'" "$out"
}

test_setup_bootstrap_config_path_dotdot_component_only() {
    echo "TEST: config_path rejects '..' only as a path component ('config..d' is accepted)"
    local sb out rc=0 proj url
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_fresh_project "$sb")"
    url="$(make_manifest_remote "$sb" "" config..d)"
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "config..d exits 0" "0" "$rc"
    assert_eq "symlink targets config..d" \
        "manifest_repo/manifest_repo/config..d" "$(readlink "$proj/configs/manifest")"
    # A real '..' component nested inside the path is still rejected.
    printf 'git_url: file://%s/remote/manifest_repo\nbranch: fakefox\nconfig_path: config/../../etc\n' "$sb" \
        > "$sb/remote/bootstrap.yaml"
    rm -rf "$proj/configs"
    rc=0
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "nested .. component exits nonzero" "1" "$rc"
    assert_contains "names config_path" "invalid 'config_path'" "$out"
}

test_setup_bootstrap_reuse_requires_matching_origin() {
    echo "TEST: an existing clone dir is reused only when its origin matches git_url"
    local sb out rc=0 proj url clone_dir
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_fresh_project "$sb")"
    url="$(make_manifest_remote "$sb" l1)"
    clone_dir="$proj/layers/main/l1_ws/src/manifest_repo"
    # Leftover from a bootstrap that pointed at a different repo.
    mkdir -p "$clone_dir"
    git -C "$clone_dir" init --quiet
    git -C "$clone_dir" remote add origin "file:///elsewhere/other_manifest.git"
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "mismatched origin exits nonzero" "1" "$rc"
    assert_contains "names both repos" "is a checkout of file:///elsewhere/other_manifest.git, not file://$sb/remote/manifest_repo" "$out"
    assert_eq "no symlink created" "false" "$([ -e "$proj/configs/manifest" ] && echo true || echo false)"
    # A non-git directory at the clone path is refused too.
    rm -rf "$clone_dir" && mkdir -p "$clone_dir"
    rc=0
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "non-git dir exits nonzero" "1" "$rc"
    assert_contains "says it is not a checkout" "not a git checkout" "$out"
}

test_setup_bootstrap_reuse_warns_on_branch_mismatch() {
    echo "TEST: a matching checkout on another branch is reused with a warning"
    local sb out rc=0 proj url clone_dir
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_fresh_project "$sb")"
    url="$(make_manifest_remote "$sb" l1)"
    clone_dir="$proj/layers/main/l1_ws/src/manifest_repo"
    mkdir -p "$(dirname "$clone_dir")"
    git clone -q -b fakefox "file://$sb/remote/manifest_repo" "$clone_dir"
    git -C "$clone_dir" checkout -q -b feature/work
    out="$(cd "$sb" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project tiered setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "warns with both branches" "on 'feature/work', bootstrap pins 'fakefox'" "$out"
    assert_eq "checkout left on its branch" "feature/work" "$(git -C "$clone_dir" branch --show-current)"
    assert_eq "manifest linked" "true" "$([ -f "$proj/configs/manifest/layers.txt" ] && echo true || echo false)"
}

test_setup_existing_manifest_skips_bootstrap() {
    echo "TEST: a hand-placed configs/manifest dir is used as-is (no fetch)"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_colcon_project "$sb" >/dev/null
    printf 'bootstrap_url=file:///nonexistent/config.yaml\n' > "$sb/.agent/projects.d/tiered"
    out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_not_contains "no fetch attempted" "Fetching bootstrap" "$out"
}

# ---- build verb ----

test_build_layer_order_and_cascade() {
    echo "TEST: build runs layers in order with cascading overlay environment"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 pkg_a pkg_b
    populate_layer "$proj" l2 pkg_c
    populate_layer "$proj" l3 pkg_priv
    out="$(run_adapter "$sb" build 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "each layer built once, in order, seeing the layers below it" \
        "COLCON_RAN_IN:$proj/layers/main/l1_ws CMD:build SOURCED:base
COLCON_RAN_IN:$proj/layers/main/l2_ws CMD:build SOURCED:base+l1_ws
COLCON_RAN_IN:$proj/layers/main/l3_ws CMD:build SOURCED:base+l1_ws+l2_ws" \
        "$(cat "$sb/colcon.log")"
}

test_build_skips_layer_without_src() {
    echo "TEST: build skips layers with no src directory"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 pkg_a
    populate_layer "$proj" l3 pkg_priv
    out="$(run_adapter "$sb" build 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "l2 skipped" "Skipping layer l2 (no src directory)" "$out"
    assert_not_contains "l2 never built" "l2_ws CMD:build" "$(cat "$sb/colcon.log")"
}

test_build_stops_on_failure() {
    echo "TEST: build stops at the failing layer and propagates its exit code"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 pkg_a
    populate_layer "$proj" l2 pkg_c
    populate_layer "$proj" l3 pkg_priv
    mkdir -p "$proj/layers/main/l2_ws"
    touch "$proj/layers/main/l2_ws/.colcon_fail"
    out="$(run_adapter "$sb" build 2>&1)" || rc=$?
    assert_eq "colcon's exit code propagated" "3" "$rc"
    assert_contains "names the failing layer" "build failed for layer: l2" "$out"
    assert_not_contains "l3 never attempted" "l3_ws CMD:build" "$(cat "$sb/colcon.log")"
}

# ---- test verb ----

test_test_continues_past_failures() {
    echo "TEST: test verb runs every layer and reports all failures at the end"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 pkg_a
    populate_layer "$proj" l2 pkg_c
    populate_layer "$proj" l3 pkg_priv
    mkdir -p "$proj/layers/main/l1_ws"
    touch "$proj/layers/main/l1_ws/.colcon_fail"
    out="$(run_adapter "$sb" test 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "l1 failure reported" "tests failed for layer: l1" "$out"
    assert_contains "later layers still tested" "l3_ws CMD:test" "$(cat "$sb/colcon.log")"
    assert_contains "summary lists the failed layer" "Tests failed in layers: l1" "$out"
}

# ---- repos / scope_for_pr ----

test_repos_lists_packages_across_layers() {
    echo "TEST: repos emits name:path for every package repo in every layer"
    local sb out proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 --git pkg_a pkg_b
    populate_layer "$proj" l2 --git pkg_c
    # A non-git dir in src must not be listed.
    mkdir -p "$proj/layers/main/l2_ws/src/scratch"
    out="$(run_adapter "$sb" repos)" || true
    assert_eq "all package repos, layer order" \
        "pkg_a:$proj/layers/main/l1_ws/src/pkg_a
pkg_b:$proj/layers/main/l1_ws/src/pkg_b
pkg_c:$proj/layers/main/l2_ws/src/pkg_c" "$out"
}

test_repos_unconfigured_fails() {
    echo "TEST: repos fails before setup has run"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_colcon_project "$sb" >/dev/null
    out="$(run_adapter "$sb" repos 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "points at setup" "run: adapter setup" "$out"
}

test_scope_for_pr_nested_package() {
    echo "TEST: scope_for_pr resolves the owning package repo from a nested path"
    local sb out proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 --git pkg_a
    mkdir -p "$proj/layers/main/l1_ws/src/pkg_a/src/deep"
    out="$(run_adapter "$sb" scope_for_pr "$proj/layers/main/l1_ws/src/pkg_a/src/deep")" || true
    assert_eq "owner/repo of the package, not the layer" "owner/pkg_a" "$out"
    # A file path (package.xml) must resolve from its directory (#237).
    touch "$proj/layers/main/l1_ws/src/pkg_a/package.xml"
    out="$(run_adapter "$sb" scope_for_pr "$proj/layers/main/l1_ws/src/pkg_a/package.xml")" || true
    assert_eq "file path resolves via its parent dir" "owner/pkg_a" "$out"
}

# ---- worktree_repos / worktree_env (ADR-0012) ----

test_worktree_repos_requires_qualified_issue() {
    echo "TEST: ros2_colcon worktree_repos rejects a bare issue number"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 --git pkg_a
    out="$(run_adapter "$sb" worktree_repos --issue 111 --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the qualified form" "requires a qualified --issue owner/repo#N" "$out"
}

test_worktree_repos_requires_layer_and_packages() {
    echo "TEST: ros2_colcon worktree_repos requires both --layer and --package-repos"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 --git pkg_a
    out="$(run_adapter "$sb" worktree_repos --issue owner/repo#111 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names both flags" "requires both --layer" "$out"
}

test_worktree_repos_owning_and_sibling_branches() {
    echo "TEST: worktree_repos names the issue's own repo feature/issue-N, siblings qualified"
    local sb out proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 --git pkg_a pkg_b
    out="$(run_adapter "$sb" worktree_repos --issue owner/pkg_a#111 --layer l1 --package-repos pkg_a,pkg_b)" || true
    assert_eq "owning repo plain, sibling qualified" \
        "$proj/layers/main/l1_ws/src/pkg_a	l1_ws/src/pkg_a	feature/issue-111
$proj/layers/main/l1_ws/src/pkg_b	l1_ws/src/pkg_b	feature/pkg_a-issue-111" "$out"
}

test_worktree_repos_unknown_package_fails() {
    echo "TEST: worktree_repos names an unknown package repo"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 --git pkg_a
    out="$(run_adapter "$sb" worktree_repos --issue owner/pkg_a#111 --layer l1 --package-repos pkg_a,pkg_ghost 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing package" "package repo 'pkg_ghost' not found under layer 'l1'" "$out"
}

test_worktree_repos_wrong_layer_fails() {
    echo "TEST: worktree_repos names the layer a package actually lives in"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 --git pkg_a
    populate_layer "$proj" l2 --git pkg_c
    out="$(run_adapter "$sb" worktree_repos --issue owner/pkg_a#111 --layer l1 --package-repos pkg_c 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the real layer" "'pkg_c' is in layer 'l2', not 'l1'" "$out"
}

test_worktree_env_for_package_worktree() {
    echo "TEST: worktree_env sources below-layer installs, same-layer install, then the worktree's own"
    local sb out proj wt
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    mkdir -p "$proj/layers/main/l1_ws/install"
    touch "$proj/layers/main/l1_ws/install/local_setup.bash"
    wt="$sb/wt"
    mkdir -p "$wt/l2_ws/install"
    touch "$wt/l2_ws/install/local_setup.bash"
    out="$(run_adapter "$sb" worktree_env --worktree "$wt")" || true
    local expected
    expected="unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
source $sb/rosroot/fakefox/setup.bash
if [ -f $proj/layers/main/l1_ws/install/local_setup.bash ]; then source $proj/layers/main/l1_ws/install/local_setup.bash; fi
if [ -f $proj/layers/main/l2_ws/install/local_setup.bash ]; then source $proj/layers/main/l2_ws/install/local_setup.bash; fi
if [ -f $wt/l2_ws/install/local_setup.bash ]; then source $wt/l2_ws/install/local_setup.bash; fi"
    assert_eq "below-layer, same-layer (hosted, not built), worktree's own — all runtime-guarded" "$expected" "$out"
    # ADR-0012: the colcon-specific COLCON_IGNORE marker for the worktrees dir
    # is written here by the adapter, not by the generic worktree helpers.
    assert_eq "worktree_env writes an empty COLCON_IGNORE in the worktree's parent dir" \
        "yes" "$([ -f "$sb/COLCON_IGNORE" ] && [ ! -s "$sb/COLCON_IGNORE" ] && echo yes || echo no)"
    out="$(run_adapter "$sb" worktree_env --worktree "$wt")" || true
    assert_eq "second worktree_env call is idempotent (marker still present, output unchanged)" "$expected" "$out"

    local wt_env="$sb/wt_env.sh"
    printf '%s\n' "$out" > "$wt_env"
    assert_eq "sourcing under set -e with no missing-file install exits 0 (l2's own is built here)" \
        "ok" "$(bash -c "set -e; source '$wt_env'; echo ok" 2>&1)"
}

test_worktree_env_last_line_never_fails_under_set_e() {
    echo "TEST: env.sh's last line is always a zero-exit guard, even when no install exists at all"
    local sb out proj wt
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    # No installs anywhere — the worst case: every conditional line's
    # [ -f ] test is false, including whichever one is last.
    wt="$sb/wt"
    mkdir -p "$wt/l1_ws"
    out="$(run_adapter "$sb" worktree_env --worktree "$wt")" || true
    local env_file="$sb/env.sh"
    printf '%s\n' "$out" > "$env_file"
    local result
    result="$(bash -c "set -e; source '$env_file'; echo ok" 2>&1)"
    assert_eq "'source env.sh' under set -e still reaches 'echo ok'" "ok" "$result"
}

test_worktree_env_runtime_guard_picks_up_install_built_after_generation() {
    echo "TEST: env.sh's own-install line is a runtime guard, not a generation-time snapshot"
    local sb out proj wt
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    wt="$sb/wt"
    mkdir -p "$wt/l1_ws"
    # Generate env.sh before the worktree's own install exists at all —
    # this is exactly worktree_create.sh's ordering (env.sh is written once,
    # before any build.sh/test.sh run).
    out="$(run_adapter "$sb" worktree_env --worktree "$wt")" || true
    local env_file="$sb/env.sh"
    printf '%s\n' "$out" > "$env_file"
    assert_not_contains "no install exists yet: nothing marks itself built" \
        "MARKER_SET" "$(bash -c "MARKER=unset; source '$env_file' >/dev/null 2>&1; echo \$MARKER")"

    # Now "build": create the worktree's own install with a stub
    # local_setup.bash that sets a marker. Re-sourcing the SAME env.sh
    # (never regenerated) must now pick it up.
    mkdir -p "$wt/l1_ws/install"
    echo 'export MARKER=MARKER_SET' > "$wt/l1_ws/install/local_setup.bash"
    local after
    after="$(bash -c "MARKER=unset; source '$env_file' >/dev/null 2>&1; echo \$MARKER")"
    assert_eq "the pre-generated env.sh now sources the freshly built install" "MARKER_SET" "$after"
}

test_worktree_env_no_layer_ws_fails() {
    echo "TEST: worktree_env fails when no <layer>_ws directory exists under the worktree"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_colcon_project "$sb" >/dev/null
    out="$(run_adapter "$sb" worktree_env --worktree "$sb/empty_wt" 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing dir" "no <layer>_ws directory found" "$out"
}

# ---- sync verb ----

test_sync_pull_skip_fetch() {
    echo "TEST: sync pulls on the pinned branch, skips dirty, fetches elsewhere"
    local sb out rc=0 proj mdir
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    mdir="$proj/configs/manifest"
    write_repos_file "$mdir/repos/l1.repos" fakefox pkg_pull pkg_dirty pkg_feature
    printf 'l1\n' > "$mdir/layers.txt"
    : > "$mdir/optional_layers.txt"

    # Local origin with a 'fakefox' branch and one extra upstream commit.
    local origin="$sb/origin_pkg_pull"
    git -C "$(mkdir -p "$origin" && echo "$origin")" init --quiet -b fakefox
    (cd "$origin" && echo v1 > f.txt && git add f.txt \
        && git -c user.name=t -c user.email=t@t commit -qm v1)
    local src="$proj/layers/main/l1_ws/src"
    mkdir -p "$src"
    git clone --quiet "$origin" "$src/pkg_pull" 2>/dev/null
    git -C "$src/pkg_pull" config user.name t
    git -C "$src/pkg_pull" config user.email t@t
    (cd "$origin" && echo v2 > f.txt \
        && git -c user.name=t -c user.email=t@t commit -qam v2)

    # Dirty checkout on the pinned branch.
    git clone --quiet "$origin" "$src/pkg_dirty" 2>/dev/null
    echo local-edit >> "$src/pkg_dirty/f.txt"

    # Clean checkout on a feature branch.
    git clone --quiet "$origin" "$src/pkg_feature" 2>/dev/null
    git -C "$src/pkg_feature" checkout --quiet -b feature/x

    out="$(run_adapter "$sb" sync 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "pinned-branch repo pulled the upstream commit" \
        "v2" "$(cat "$src/pkg_pull/f.txt")"
    assert_contains "dirty repo skipped" "pkg_dirty: skipped (uncommitted changes)" "$out"
    assert_eq "dirty repo untouched" \
        "yes" "$(grep -q local-edit "$src/pkg_dirty/f.txt" && echo yes || echo no)"
    assert_contains "feature-branch repo fetched, not pulled" \
        "pkg_feature: on 'feature/x' (pinned: fakefox) — fetching" "$out"
}

# ---- validate verb ----

test_validate_passes_matching_checkout() {
    echo "TEST: validate passes when the checkout matches the manifest"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 pkg_a pkg_b
    populate_layer "$proj" l2 pkg_c
    # l3 is optional and absent — allowed.
    out="$(run_adapter "$sb" validate 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "reports success" "matches the manifest" "$out"
}

test_validate_flags_missing_repo() {
    echo "TEST: validate flags a pinned repo that is not checked out"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 pkg_a
    populate_layer "$proj" l2 pkg_c
    out="$(run_adapter "$sb" validate 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing repo" "repo 'pkg_b' pinned in l1.repos but not checked out" "$out"
}

test_validate_flags_unsetup_layer() {
    echo "TEST: validate flags a required layer that was never set up"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 pkg_a pkg_b
    out="$(run_adapter "$sb" validate 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "points at setup" "layer 'l2': not set up" "$out"
}

# ---- install / dispatcher integration ----

test_install_noop_by_default() {
    echo "TEST: install no-ops without INSTALL_CMD (colcon installs during build)"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_colcon_project "$sb" >/dev/null
    out="$(run_adapter "$sb" install 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "explains the no-op" "nothing to install" "$out"
}

test_cwd_discovery_resolves_colcon_project() {
    echo "TEST: cwd inside the hosting dir resolves the ros2_colcon project"
    local sb out proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    populate_layer "$proj" l1 pkg_a
    out="$(cd "$proj/layers/main/l1_ws" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "resolved from deep inside a layer" "$proj" "$out"
}

# ---- repo_pin (ADR-0019) ----

# Write a .repos file from name=version pairs; the version is written as
# given, so a test can quote it.
write_pin_repos() {  # <file> <name=version>...
    local file="$1" pair
    shift
    {
        echo "repositories:"
        for pair in "$@"; do
            echo "  ${pair%%=*}:"
            echo "    type: git"
            echo "    url: file:///nonexistent/${pair%%=*}.git"
            echo "    version: ${pair#*=}"
        done
    } > "$file"
}

# A committed package checkout under <layer>/src/<name> whose origin is a
# local bare repo holding main, a branch "pinned" and a tag "v1.0". Prints
# the full sha of main's commit.
make_pin_pkg() {  # <sb> <proj> <layer> <name>
    local sb="$1" proj="$2" layer="$3" name="$4" dir
    dir="$proj/layers/main/${layer}_ws/src/$name"
    make_committed_pkg_repo "$proj" "$layer" "$name"
    git init --quiet --bare -b main "$sb/${name}_origin.git"
    git -C "$dir" remote set-url origin "$sb/${name}_origin.git"
    git -C "$dir" branch --quiet pinned
    git -C "$dir" tag v1.0
    git -C "$dir" push --quiet origin main pinned v1.0
    git -C "$dir" fetch --quiet origin
    git -C "$dir" rev-parse HEAD
}

test_repo_pin_kinds_online() {
    echo "TEST: repo_pin prints the pinned ref and its kind, judged by origin"
    local sb out rc proj sha
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    sha="$(make_pin_pkg "$sb" "$proj" l1 pkg_a)"
    local kind ref pair
    # An uppercase sha is a commit too: git reads object names in either case.
    for pair in "pinned=branch" "v1.0=tag" "$sha=commit" "${sha^^}=commit" "nowhere=unknown"; do
        ref="${pair%%=*}"
        kind="${pair#*=}"
        write_pin_repos "$proj/configs/manifest/repos/l1.repos" "pkg_a=$ref" "pkg_b=fakefox"
        rc=0
        out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
        assert_eq "$kind: exit 0" "0" "$rc"
        assert_eq "$kind: ref and kind" "$ref	$kind" "$out"
    done
}

test_repo_pin_branch_before_tag() {
    echo "TEST: repo_pin calls a ref that is both a branch and a tag on origin a branch"
    local sb out proj dir
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_pin_pkg "$sb" "$proj" l1 pkg_a >/dev/null
    dir="$proj/layers/main/l1_ws/src/pkg_a"
    git -C "$dir" tag pinned main
    git -C "$dir" push --quiet origin refs/tags/pinned
    write_pin_repos "$proj/configs/manifest/repos/l1.repos" "pkg_a=pinned"
    out="$(run_adapter "$sb" repo_pin pkg_a 2>/dev/null)" || true
    assert_eq "branch wins" "pinned	branch" "$out"
}

test_repo_pin_strips_quotes() {
    echo "TEST: repo_pin strips YAML quoting around the ref"
    local sb out proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_pin_pkg "$sb" "$proj" l1 pkg_a >/dev/null
    make_pin_pkg "$sb" "$proj" l1 pkg_b >/dev/null
    write_pin_repos "$proj/configs/manifest/repos/l1.repos" 'pkg_a="pinned"' "pkg_b='v1.0'"
    out="$(run_adapter "$sb" repo_pin pkg_a 2>/dev/null)" || true
    assert_eq "double quotes stripped" "pinned	branch" "$out"
    out="$(run_adapter "$sb" repo_pin pkg_b 2>/dev/null)" || true
    assert_eq "single quotes stripped" "v1.0	tag" "$out"
}

test_repo_pin_reads_version_as_yaml() {
    echo "TEST: repo_pin keeps a '#' inside a ref, drops a comment and a CRLF, refuses a stray quote"
    local sb out rc proj dir f
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_pin_pkg "$sb" "$proj" l1 pkg_a >/dev/null
    dir="$proj/layers/main/l1_ws/src/pkg_a"
    # Both "fix" and "fix#12" are branches on origin: cutting at the "#"
    # would answer with the wrong, existing branch.
    git -C "$dir" branch --quiet fix
    git -C "$dir" branch --quiet 'fix#12'
    git -C "$dir" push --quiet origin fix 'fix#12'
    f="$proj/configs/manifest/repos/l1.repos"
    local pair want
    for pair in 'fix#12|fix#12	branch' '"fix#12"|fix#12	branch' \
        '"fix#12" # pinned for #12|fix#12	branch' 'fix # a comment|fix	branch'; do
        write_pin_repos "$f" "pkg_a=${pair%%|*}"
        want="${pair#*|}"
        rc=0
        out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
        assert_eq "[${pair%%|*}]: exit 0" "0" "$rc"
        assert_eq "[${pair%%|*}]: ref and kind" "$want" "$out"
    done
    # A CRLF file: the CR is a line end, not part of the ref.
    printf 'repositories:\r\n  pkg_a:\r\n    type: git\r\n    version: pinned\r\n' > "$f"
    rc=0
    out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
    assert_eq "CRLF: exit 0" "0" "$rc"
    assert_eq "CRLF: no CR in the ref" "pinned	branch" "$out"
    # A comment right after the key is no ref: the value is empty, refused.
    for pair in ' # TODO pin' '#main'; do
        write_pin_repos "$f" "pkg_a=$pair"
        rc=0
        out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
        assert_eq "[$pair]: exit 1" "1" "$rc"
        assert_contains "[$pair]: empty version" "has an empty version: in layer 'l1'" "$out"
    done
    # A quote that does not close the value cleanly, or a backslash escape
    # the parser does not decode ("a\" #b" is YAML's 'a" #b', "v\x31.0"
    # its 'v1.0'), is refused, not cut to a ref nobody pinned.
    for pair in '"fix' "fix'" 'fi"x' "'stable''next'" '"main" extra' '"x\"y"' '"main"#c' \
        '"a\" #b"' '"v\x31.0"' "'a\\b'"; do
        write_pin_repos "$f" "pkg_a=$pair"
        rc=0
        out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
        assert_eq "[$pair]: exit 1" "1" "$rc"
        assert_contains "[$pair]: says why" \
            "cannot be read as a ref (a stray quote, a backslash escape or a carriage return)" "$out"
    done
}

test_repo_pin_refuses_yaml_typed_plain_pins() {
    echo "TEST: repo_pin refuses an unquoted pin only when YAML's reading changes the text"
    local sb out rc proj dir f row val what got
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_pin_pkg "$sb" "$proj" l1 pkg_a >/dev/null
    dir="$proj/layers/main/l1_ws/src/pkg_a"
    git -C "$dir" tag 1.10
    git -C "$dir" branch --quiet 2.0
    git -C "$dir" branch --quiet True
    git -C "$dir" push --quiet origin refs/tags/1.10 2.0 True
    f="$proj/configs/manifest/repos/l1.repos"
    # value|what YAML reads it as|what vcstool (str() of it) checks out;
    # an empty "checks out" means the shell cannot work it out exactly.
    local -a refused=(
        '1.10|the number 1.1|1.1'
        '1.50|the number 1.5|1.5'
        '017|the number 15|15'
        '+5|the number 5|5'
        '1_000|the number 1000|1000'
        '0x1F|the number 31|31'
        'yes|the bool True|True'
        'true|the bool True|True'
        'TRUE|the bool True|True'
        'Off|the bool False|False'
        'false|the bool False|False'
        'FALSE|the bool False|False'
        '~|null|None'
        'Null|null|None'
        '.inf|the float inf|inf'
        '1.5e+3|a float|'
        '0.00001|a float|'
        "!tag|YAML syntax, not text ('!' starts it)|"
        "&anchor|YAML syntax, not text ('&' starts it)|"
        "@x|YAML syntax, not text ('@' starts it)|"
    )
    for row in "${refused[@]}"; do
        val="${row%%|*}"
        what="${row#*|}"
        got="${what#*|}"
        what="${what%|*}"
        write_pin_repos "$f" "pkg_a=$val"
        rc=0
        out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
        assert_eq "[$val]: exit 1" "1" "$rc"
        assert_contains "[$val]: says what YAML reads" "unquoted, which YAML reads as $what," "$out"
        if [ -n "$got" ]; then
            assert_contains "[$val]: says what vcstool checks out" \
                "so vcstool would check out '$got', not '$val'" "$out"
        fi
        assert_contains "[$val]: asks for quotes" "quote it: version: \"$val\"" "$out"
    done
    # str() gives these back as written, so vcstool checks out the text:
    # accepted unquoted. 1e+5 has no dot, so PyYAML keeps it a string;
    # True and False are bools whose str() is the same text.
    local -a kept=(2.0 1.0 1.5 0.3 2024 0 -5 1e+5 True False
        1234567890123456789012345678901234567890)
    for val in "${kept[@]}"; do
        write_pin_repos "$f" "pkg_a=$val"
        rc=0
        out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
        assert_eq "[$val]: exit 0" "0" "$rc"
        assert_eq "[$val]: the ref as written" "$val" "${out%%$'\t'*}"
    done
    write_pin_repos "$f" "pkg_a=2.0"
    out="$(run_adapter "$sb" repo_pin pkg_a 2>/dev/null)" || true
    assert_eq "an unquoted release branch 2.0 is that branch" "2.0	branch" "$out"
    write_pin_repos "$f" "pkg_a=True"
    out="$(run_adapter "$sb" repo_pin pkg_a 2>/dev/null)" || true
    assert_eq "an unquoted branch True is that branch" "True	branch" "$out"
    for val in '"1.10"' "'1.10'"; do
        write_pin_repos "$f" "pkg_a=$val"
        rc=0
        out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
        assert_eq "[$val]: exit 0" "0" "$rc"
        assert_eq "[$val]: the tag as written" "1.10	tag" "$out"
    done
    # The same ref, quoted in one layer and plain in another: the plain
    # one is still read as 1.1 there, so it is refused, naming that layer.
    write_pin_repos "$f" 'pkg_a="1.10"'
    write_pin_repos "$proj/configs/manifest/repos/l2.repos" "pkg_a=1.10"
    rc=0
    out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
    assert_eq "plain in l2 only: exit 1" "1" "$rc"
    assert_contains "plain in l2 only: names l2" "in layer 'l2' unquoted" "$out"
}

# The full input table for the .repos parser that repo_pin, sync and
# validate share: each "version:" text (after "    version:"), the value
# _rc_repos_entries emits for it, and the form --detail adds (quoted or
# plain; repo_pin refuses a plain value YAML types as a non-string). sync
# reads the plain "<name>\t<value>" output, which must not change for any
# row (an unquoted 1.10 stays "1.10" there); validate reads only the
# names, so every row must still emit its name.
test_repos_entries_parser_table() {
    echo "TEST: _rc_repos_entries reads each version: form as the table says"
    local sb f i=0 row input want form got
    sb="$(make_sandbox)"
    f="$sb/table.repos"
    local -a rows=(
        ' pinned|pinned|plain'
        ' fix#12|fix#12|plain'
        ' fix # a comment|fix|plain'
        ' "fix#12"|fix#12|quoted'
        " 'v1.0'|v1.0|quoted"
        ' "fix#12" # pinned for #12|fix#12|quoted'
        "  'v1.0'   |v1.0|quoted"
        '  # TODO pin||plain'
        ' #main||plain'
        '||plain'
        ' ""||quoted'
        $' dev\r|dev|plain'
        $' "dev"\r|dev|quoted'
        $' dev # c\r|dev|plain'
        ' "fix|"fix|plain'
        " fix'|fix'|plain"
        ' fi"x|fi"x|plain'
        " 'stable''next'|'stable''next'|plain"
        ' "main" extra|"main" extra|plain'
        ' "x\"y"|"x\"y"|plain'
        ' "main"#c|"main"#c|plain'
        ' "a\" #b"|"a\"|plain'
        ' "v\x31.0"|"v\x31.0"|plain'
        " 'a\\b'|a\\b|quoted"
        ' 1.10|1.10|plain'
        ' "1.10"|1.10|quoted'
        " '1.10'|1.10|quoted"
        ' yes|yes|plain'
        ' True|True|plain'
        ' false|false|plain'
        ' ~|~|plain'
        ' 0x1F|0x1F|plain'
        ' .inf|.inf|plain'
        ' !tag|!tag|plain'
        ' 2024-01-01|2024-01-01|plain'
        ' 2.0|2.0|plain'
        ' 2024|2024|plain'
        ' 1.50|1.50|plain'
        ' 017|017|plain'
    )
    {
        echo "repositories:"
        for row in "${rows[@]}"; do
            i=$((i + 1))
            printf '  r%d:\n    type: git\n    version:%s\n' "$i" "${row%%|*}"
        done
        printf '  noversion:\n    type: git\n'
    } > "$f"
    local parsed detailed
    parsed="$(bash -c 'source "$1/.agent/project_types/ros2_colcon/adapter.sh"; _rc_repos_entries "$2"' \
        _ "$sb" "$f")"
    detailed="$(bash -c 'source "$1/.agent/project_types/ros2_colcon/adapter.sh"; _rc_repos_entries "$2" --detail' \
        _ "$sb" "$f")"
    i=0
    for row in "${rows[@]}"; do
        i=$((i + 1))
        input="${row%%|*}"
        want="${row#*|}"
        form="${want#*|}"
        want="${want%|*}"
        got="$(awk -F'\t' -v n="r$i" '$1 == n { print; f = 1 } END { if (!f) print "<missing>" }' <<< "$parsed")"
        assert_eq "version:${input//$'\r'/\\r} -> [$want]" "r$i	$want" "$got"
        got="$(awk -F'\t' -v n="r$i" '$1 == n { print; f = 1 } END { if (!f) print "<missing>" }' <<< "$detailed")"
        assert_eq "version:${input//$'\r'/\\r} --detail -> [$want] $form" "r$i	$want	$form" "$got"
    done
    assert_not_contains "no version: key: left out without --detail" "noversion" "$parsed"
    assert_contains "no version: key: form none with --detail" $'\nnoversion\t\tnone' $'\n'"$detailed"
}

test_sync_reads_quoted_and_commented_pins() {
    echo "TEST: sync sees a quoted, commented pin as the branch, and a comment-only pin as none"
    local sb out rc=0 proj mdir origin src
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    mdir="$proj/configs/manifest"
    printf 'l1\n' > "$mdir/layers.txt"
    : > "$mdir/optional_layers.txt"
    printf 'repositories:\n  pkg_q:\n    type: git\n    version: "fakefox" # pinned\n  pkg_c:\n    type: git\n    version:  # TODO pin\n' \
        > "$mdir/repos/l1.repos"
    origin="$sb/origin_q"
    git -C "$(mkdir -p "$origin" && echo "$origin")" init --quiet -b fakefox
    (cd "$origin" && echo v1 > f.txt && git add f.txt \
        && git -c user.name=t -c user.email=t@t commit -qm v1)
    src="$proj/layers/main/l1_ws/src"
    mkdir -p "$src"
    git clone --quiet "$origin" "$src/pkg_q" 2>/dev/null
    git clone --quiet "$origin" "$src/pkg_c" 2>/dev/null
    out="$(run_adapter "$sb" sync 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "quoted pin with a comment: on its branch, pulled" "pkg_q: on 'fakefox' — pulling" "$out"
    assert_contains "comment-only pin: no branch, fetched" "pkg_c: on 'fakefox' (pinned: ) — fetching" "$out"
    rc=0
    out="$(run_adapter "$sb" validate 2>&1)" || rc=$?
    assert_contains "validate sees both repos checked out" "checkout matches the manifest" "$out"

    # A detached checkout has no branch: an empty pin (comment-only, or
    # "") must not match it. Sync fetches, so origin's new commit arrives.
    local pin new
    for pin in '  # TODO pin' ' ""'; do
        rm -rf "$src/pkg_d"
        git clone --quiet "$origin" "$src/pkg_d" 2>/dev/null
        git -C "$src/pkg_d" checkout --quiet --detach
        (cd "$origin" && echo "$pin" >> f.txt \
            && git -c user.name=t -c user.email=t@t commit -qam more)
        new="$(git -C "$origin" rev-parse HEAD)"
        printf 'repositories:\n  pkg_d:\n    type: git\n    version:%s\n' "$pin" > "$mdir/repos/l1.repos"
        rc=0
        out="$(run_adapter "$sb" sync 2>&1)" || rc=$?
        assert_eq "detached, pin [$pin]: exit 0" "0" "$rc"
        assert_contains "detached, pin [$pin]: fetched" "pkg_d: on 'detached' (pinned: ) — fetching" "$out"
        assert_not_contains "detached, pin [$pin]: not pulled" "pull failed" "$out"
        assert_eq "detached, pin [$pin]: origin's new commit fetched" "$new" \
            "$(git -C "$src/pkg_d" rev-parse refs/remotes/origin/fakefox)"
    done
}

test_repo_pin_deleted_upstream_branch_is_not_a_branch() {
    echo "TEST: repo_pin does not call a branch deleted on origin a branch, though a stale remote ref is left"
    local sb out err proj dir
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_pin_pkg "$sb" "$proj" l1 pkg_a >/dev/null
    dir="$proj/layers/main/l1_ws/src/pkg_a"
    git --git-dir="$sb/pkg_a_origin.git" branch --quiet -D pinned
    # Not pruned: refs/remotes/origin/pinned is still there.
    git -C "$dir" show-ref --verify --quiet refs/remotes/origin/pinned
    write_pin_repos "$proj/configs/manifest/repos/l1.repos" "pkg_a=pinned"
    err="$sb/err"
    out="$(run_adapter "$sb" repo_pin pkg_a 2>"$err")" || true
    assert_eq "unknown, not branch" "pinned	unknown" "$out"
    assert_not_contains "online: no unverified note" "unverified" "$(< "$err")"
}

test_repo_pin_offline_uses_local_refs() {
    echo "TEST: repo_pin falls back to local refs when origin cannot be reached, and says so"
    local sb out err proj dir
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_pin_pkg "$sb" "$proj" l1 pkg_a >/dev/null
    dir="$proj/layers/main/l1_ws/src/pkg_a"
    git -C "$dir" remote set-url origin "$sb/gone.git"
    err="$sb/err"
    local pair ref kind
    for pair in "pinned=branch" "v1.0=tag" "nowhere=unknown"; do
        ref="${pair%%=*}"
        kind="${pair#*=}"
        write_pin_repos "$proj/configs/manifest/repos/l1.repos" "pkg_a=$ref"
        out="$(run_adapter "$sb" repo_pin pkg_a 2>"$err")" || true
        assert_eq "offline $kind" "$ref	$kind" "$out"
        assert_contains "offline $kind: says unverified" "could not be reached" "$(< "$err")"
    done
    # A local branch of that name is not origin's: not enough offline either.
    git -C "$dir" branch --quiet localonly
    write_pin_repos "$proj/configs/manifest/repos/l1.repos" "pkg_a=localonly"
    out="$(run_adapter "$sb" repo_pin pkg_a 2>/dev/null)" || true
    assert_eq "a local-only branch is unknown" "localonly	unknown" "$out"
}

test_repo_pin_hanging_origin_is_bounded() {
    echo "TEST: repo_pin bounds its origin query and falls back to local refs when origin hangs"
    if ! command -v timeout >/dev/null 2>&1; then
        echo "  SKIP: no timeout command"
        return 0
    fi
    local sb out err proj dir shim pidfile started elapsed
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_pin_pkg "$sb" "$proj" l1 pkg_a >/dev/null
    dir="$proj/layers/main/l1_ws/src/pkg_a"
    # An ssh origin whose "ssh" blocks, as a passphrase or host-key prompt
    # or a stalled host would. Only WT_FETCH_TIMEOUT can end it; the
    # ceiling below is far above the 2s limit and far below the block.
    shim="$sb/hang-ssh"
    pidfile="$sb/hang-ssh.pid"
    printf '#!/usr/bin/env bash\necho $$ > "%s"\nexec sleep 300\n' "$pidfile" > "$shim"
    chmod +x "$shim"
    git -C "$dir" remote set-url origin "ssh://git@example.invalid/pkg_a.git"
    write_pin_repos "$proj/configs/manifest/repos/l1.repos" "pkg_a=pinned"
    err="$sb/err"
    started=$SECONDS
    out="$(GIT_SSH_COMMAND="$shim" WT_FETCH_TIMEOUT=2 run_adapter "$sb" repo_pin pkg_a 2>"$err")" || true
    elapsed=$((SECONDS - started))
    local reached=no
    if [ -s "$pidfile" ]; then
        reached=yes
        kill "$(< "$pidfile")" 2>/dev/null || true
    fi
    assert_eq "the hanging ssh was reached" "yes" "$reached"
    assert_eq "local answer: branch" "pinned	branch" "$out"
    assert_contains "names the timeout" "did not answer within 2s" "$(< "$err")"
    assert_contains "says unverified" "(unverified)" "$(< "$err")"
    assert_eq "ended by WT_FETCH_TIMEOUT, not by the block (${elapsed}s < 60s)" "yes" \
        "$([ "$elapsed" -lt 60 ] && echo yes || echo no)"
}

test_repo_pin_not_cloned() {
    echo "TEST: repo_pin for a repo not cloned yet: unknown (or commit for a full sha), unverified"
    local sb out err proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    err="$sb/err"
    write_pin_repos "$proj/configs/manifest/repos/l1.repos" "pkg_a=pinned" \
        "pkg_b=0123456789abcdef0123456789abcdef01234567"
    out="$(run_adapter "$sb" repo_pin pkg_a 2>"$err")" || true
    assert_eq "unknown" "pinned	unknown" "$out"
    assert_contains "says not cloned" "not a cloned repository" "$(< "$err")"
    out="$(run_adapter "$sb" repo_pin pkg_b 2>/dev/null)" || true
    assert_eq "full sha is a commit" "0123456789abcdef0123456789abcdef01234567	commit" "$out"
    write_pin_repos "$proj/configs/manifest/repos/l1.repos" \
        "pkg_b=0123456789ABCDEF0123456789ABCDEF01234567"
    out="$(run_adapter "$sb" repo_pin pkg_b 2>/dev/null)" || true
    assert_eq "uppercase full sha is a commit" "0123456789ABCDEF0123456789ABCDEF01234567	commit" "$out"
}

test_repo_pin_not_found() {
    echo "TEST: repo_pin names the known repos when the name is not pinned"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_colcon_project "$sb" >/dev/null
    out="$(run_adapter "$sb" repo_pin pkg_ghost 2>&1)" || rc=$?
    assert_eq "exits 1" "1" "$rc"
    assert_contains "names the known repos" \
        "no repository 'pkg_ghost' pinned in the manifest (known: pkg_a pkg_b pkg_c pkg_priv)" "$out"
    rc=0
    out="$(run_adapter "$sb" repo_pin 2>&1)" || rc=$?
    assert_eq "no name exits 1" "1" "$rc"
    assert_contains "names the usage" "repo_pin requires a repository name" "$out"
}

test_repo_pin_entry_without_version() {
    echo "TEST: repo_pin names an entry with no version: key, rather than calling it not pinned"
    local sb out rc proj f
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    f="$proj/configs/manifest/repos/l1.repos"
    printf 'repositories:\n  pkg_a:\n    type: git\n    url: file:///nonexistent/pkg_a.git\n  pkg_b:\n    type: git\n    version: main\n' > "$f"
    rc=0
    out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
    assert_eq "no version: exit 1" "1" "$rc"
    assert_contains "no version: its own message" "'pkg_a' has no version: key in layer 'l1'" "$out"
    assert_not_contains "no version: not 'not pinned'" "no repository 'pkg_a'" "$out"
    rc=0
    out="$(run_adapter "$sb" repo_pin pkg_ghost 2>&1)" || rc=$?
    assert_eq "unknown name: exit 1" "1" "$rc"
    assert_contains "the versionless entry is a known repo" "known: pkg_a pkg_b" "$out"
    # Pinned in one layer, unpinned in another: the refs differ.
    write_pin_repos "$proj/configs/manifest/repos/l2.repos" "pkg_a=main"
    rc=0
    out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
    assert_eq "pinned in one layer only: exit 1" "1" "$rc"
    assert_contains "names both" "l1 (no version:), l2 (main); pass --layer <l>" "$out"
}

test_repo_pin_two_layers() {
    echo "TEST: repo_pin for a repo pinned in two layers: same ref answers, different refs need --layer"
    local sb out rc proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_pin_pkg "$sb" "$proj" l1 pkg_a >/dev/null
    write_pin_repos "$proj/configs/manifest/repos/l1.repos" "pkg_a=pinned"
    write_pin_repos "$proj/configs/manifest/repos/l2.repos" "pkg_a=pinned" "pkg_c=fakefox"
    rc=0
    out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
    assert_eq "same ref: exit 0" "0" "$rc"
    assert_eq "same ref: one answer" "pinned	branch" "$out"
    write_pin_repos "$proj/configs/manifest/repos/l2.repos" "pkg_a=v1.0" "pkg_c=fakefox"
    rc=0
    out="$(run_adapter "$sb" repo_pin pkg_a 2>&1)" || rc=$?
    assert_eq "different refs: exit 1" "1" "$rc"
    assert_contains "names both layers and refs" "l1 (pinned), l2 (v1.0); pass --layer <l>" "$out"
    out="$(run_adapter "$sb" repo_pin pkg_a --layer l1 2>/dev/null)" || true
    assert_eq "--layer l1 answers" "pinned	branch" "$out"
    rc=0
    out="$(run_adapter "$sb" repo_pin pkg_c --layer l1 2>&1)" || rc=$?
    assert_eq "not in that layer: exit 1" "1" "$rc"
    assert_contains "names the layer" "no repository 'pkg_c' pinned in layer 'l1' of the manifest" "$out"
    rc=0
    out="$(run_adapter "$sb" repo_pin pkg_a --layer nolayer 2>&1)" || rc=$?
    assert_eq "unknown layer: exit 1" "1" "$rc"
    assert_contains "names the bad layer" "layer 'nolayer' is not defined" "$out"
    # The same ref in two layers, cloned only in the later one: the kind is
    # judged where it is cloned, as --layer l2 would judge it.
    make_pin_pkg "$sb" "$proj" l2 pkg_b >/dev/null
    [ ! -e "$proj/layers/main/l1_ws/src/pkg_b" ] || rm -rf "$proj/layers/main/l1_ws/src/pkg_b"
    write_pin_repos "$proj/configs/manifest/repos/l1.repos" "pkg_a=pinned" "pkg_b=pinned"
    write_pin_repos "$proj/configs/manifest/repos/l2.repos" "pkg_b=pinned"
    local err="$sb/err"
    rc=0
    out="$(run_adapter "$sb" repo_pin pkg_b 2>"$err")" || rc=$?
    assert_eq "cloned in l2 only: exit 0" "0" "$rc"
    assert_eq "cloned in l2 only: judged there" "pinned	branch" "$out"
    assert_not_contains "cloned in l2 only: verified" "unverified" "$(< "$err")"
    out="$(run_adapter "$sb" repo_pin pkg_b --layer l2 2>/dev/null)" || true
    assert_eq "--layer l2 agrees" "pinned	branch" "$out"
}

# ---- toolchain for the tool-route tests ----
#
# The resolver these tests run is THIS checkout's source
# (tools/repos-manifest/src on PYTHONPATH), never a copy installed elsewhere
# (the main checkout's venv holds main's code; a worktree and CI have no
# venv of their own). The interpreter is the first that imports both yaml
# and that source: the python of a repos-manifest on PATH (CI installs one),
# the main checkout's .venv python, then python3. When none can, the tests
# are SKIPPED loudly, and that is a FAILURE where the resolver is meant to
# be present: a repos-manifest on PATH, a main-checkout .venv/bin/repos-manifest,
# or CI set (the adapter-contract job installs the resolver, so a quiet
# skip there would pass the job without running these tests).

MR_SRC="$REAL_ROOT/tools/repos-manifest/src"
MR_PY=""
MR_SKIPPED=0
mr_pick_python() {
    local c onpath shebang common
    local -a cands=()
    onpath="$(command -v repos-manifest 2>/dev/null || true)"
    if [ -n "$onpath" ] && IFS= read -r shebang < "$onpath" && [[ "$shebang" == '#!'* ]]; then
        shebang="${shebang#\#!}"
        case "$shebang" in
            "/usr/bin/env "*) cands+=("$(command -v "${shebang#/usr/bin/env }" 2>/dev/null || true)") ;;
            *) cands+=("$shebang") ;;
        esac
    fi
    common="$(git -C "$REAL_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    [ -n "$common" ] && cands+=("${common%/.git}/.venv/bin/python3")
    cands+=("$(command -v python3 2>/dev/null || true)")
    for c in "${cands[@]}"; do
        [ -n "$c" ] && [ -x "$c" ] || continue
        if PYTHONPATH="$MR_SRC" "$c" -c '
import sys, yaml, repos_manifest
sys.exit(0 if repos_manifest.__file__.startswith(sys.argv[1] + "/") else 3)' "$MR_SRC" 2>/dev/null; then
            MR_PY="$c"
            return 0
        fi
    done
    return 1
}
if ! mr_pick_python; then
    _mr_common="$(git -C "$REAL_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if command -v repos-manifest >/dev/null 2>&1 || [ -n "${CI:-}" ] \
        || { [ -n "$_mr_common" ] && [ -x "${_mr_common%/.git}/.venv/bin/repos-manifest" ]; }; then
        echo "  FAIL: tool-route tests: no python imports both yaml and $MR_SRC, though the resolver is meant to be present here (a repos-manifest on PATH, a main-checkout .venv/bin/repos-manifest, or CI)"
        FAIL=$((FAIL + 1))
    fi
fi

# Run a tool-route test function, or skip it loudly.
mr_test() {
    if [ -z "$MR_PY" ]; then
        echo "TEST: $1"
        echo "  SKIPPED: PyYAML not importable with this checkout's resolver source ($MR_SRC); install it (make install-repos-manifest, or a python3 with PyYAML)"
        MR_SKIPPED=$((MR_SKIPPED + 1))
        return 0
    fi
    "$1"
}

# ---- A project root in no git repository (issue 503 part 1A) ----

# The "tiered" project of make_colcon_project, in today's layout, but with
# its root outside every git repository: <outer>/projects/tiered, where
# <outer> is a sibling of the git-initialised workspace sandbox (both under
# $SANDBOX, which is no repository), registered by its absolute path. Its
# clones' origins are served from <outer>/fake_remotes (make_committed_pkg_repo).
make_outside_git_colcon_project() {  # <sb>; prints the project dir
    local sb="$1" outer proj mdir
    outer="$(mktemp -d -p "$SANDBOX")"
    proj="$outer/projects/tiered"
    mdir="$proj/configs/manifest"
    mkdir -p "$mdir/repos"
    printf 'l1\nl2\nl3\n' > "$mdir/layers.txt"
    printf 'l3\n' > "$mdir/optional_layers.txt"
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\ndistro: fakefox\n' \
        > "$mdir/bootstrap.yaml"
    write_repos_file "$mdir/repos/l1.repos" fakefox pkg_a pkg_b
    write_repos_file "$mdir/repos/l2.repos" fakefox pkg_c
    write_repos_file "$mdir/repos/l3.repos" fakefox pkg_priv
    echo "tiered ros2_colcon $proj" >> "$sb/.agent/projects.local"
    make_underlay "$sb"
    echo "$proj"
}

test_worktree_create_package_root_outside_git() {
    echo "TEST: a package worktree on a multi-repo root in no git repository is made (issue 503)"
    local sb out rc=0 proj wt
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_outside_git_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    make_committed_pkg_repo "$proj" l1 pkg_b
    mkdir -p "$proj/layers/main/l1_ws/install"
    touch "$proj/layers/main/l1_ws/install/local_setup.bash"
    assert_eq "precondition: the root is in no git repository" "outside" \
        "$(git -C "$proj" rev-parse --git-dir >/dev/null 2>&1 && echo inside || echo outside)"
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#503 --type project --project tiered \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    wt="$proj/worktrees/issue-tiered-owner-pkg_a-503"
    assert_eq "exit 0" "0" "$rc"
    assert_not_contains "no refusal of the root" "project checkout is not a git repository" "$out"
    assert_eq "worktree checked out on feature/issue-503" \
        "feature/issue-503" "$(git -C "$wt/l1_ws/src/pkg_a" branch --show-current 2>/dev/null)"
    assert_eq "the header records the pin as base=" \
        "# project=tiered issue=owner/pkg_a#503 layer=l1 base=fakefox" "$(head -n1 "$wt/.worktree-repos" 2>/dev/null)"
    assert_eq "the owning branch starts at origin's fakefox" \
        "$(git -C "$proj/layers/main/l1_ws/src/pkg_a" rev-parse refs/remotes/origin/fakefox)" \
        "$(git -C "$wt/l1_ws/src/pkg_a" rev-parse HEAD 2>/dev/null)"
    assert_eq "env.sh sources the underlay, the root's l1 install, then the worktree's" \
        "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
source $sb/rosroot/fakefox/setup.bash
if [ -f $proj/layers/main/l1_ws/install/local_setup.bash ]; then source $proj/layers/main/l1_ws/install/local_setup.bash; fi
if [ -f $wt/l1_ws/install/local_setup.bash ]; then source $wt/l1_ws/install/local_setup.bash; fi" \
        "$(cat "$wt/env.sh" 2>/dev/null)"
    assert_eq "build.sh generated and executable" "true" "$([ -x "$wt/build.sh" ] && echo true || echo false)"
    assert_eq "test.sh generated and executable" "true" "$([ -x "$wt/test.sh" ] && echo true || echo false)"
    assert_eq "COLCON_IGNORE written in the root's worktrees/" "true" \
        "$([ -f "$proj/worktrees/COLCON_IGNORE" ] && echo true || echo false)"
}

test_worktree_create_package_root_outside_git_repo_not_git_refused() {
    echo "TEST: on a root in no git repository, a named repo that is no git repository is refused before anything is made (issue 503)"
    local sb out rc=0 proj
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_outside_git_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    populate_layer "$proj" l1 pkg_b
    assert_eq "precondition: the root is in no git repository" "outside" \
        "$(git -C "$proj" rev-parse --git-dir >/dev/null 2>&1 && echo inside || echo outside)"
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#504 --type project --project tiered \
        --layer l1 --package-repos pkg_a,pkg_b 2>&1)" || rc=$?
    assert_eq "exits 1" "1" "$rc"
    assert_contains "names the repo that is no git repository" "pkg_b" "$out"
    assert_eq "no worktrees/ made under the root" "false" \
        "$([ -e "$proj/worktrees" ] && echo true || echo false)"
    assert_eq "no owning branch made" "false" \
        "$(git -C "$proj/layers/main/l1_ws/src/pkg_a" show-ref --verify --quiet refs/heads/feature/issue-504 && echo true || echo false)"
    assert_eq "no worktree added to pkg_a" "1" \
        "$(git -C "$proj/layers/main/l1_ws/src/pkg_a" worktree list --porcelain | grep -c '^worktree ')"
}

TOOL_SKIPPED=0
LOCALE_SKIPPED=0

# ---- A root the manifest tool set up (issue 503 part 1B) ----

# A system directory of the manifest tool, outside every git repository:
# <outer>/toolsys, where <outer> is a sibling of the workspace sandbox
# (both under $SANDBOX, which is no repository), registered as toolsys by
# its absolute path. Its manifest, in the format of
# tools/repos-manifest/docs/spec.md, has distros fakefox and fakefox2 and
# layers core and extra: pkg_u in the unnamed layer, pkg_a in core (pinned
# at the branch fakefox for fakefox, main otherwise), pkg_b in core and
# optional, pkg_c in extra. Each distro given is resolved by THIS
# checkout's resolver into .repos-manifest/resolved/<distro>/ (the tool's
# own output), and each repo is cloned at <outer>/toolsys/<distro>/<layer>/src
# (the unnamed layer's at <distro>/src) from a bare remote in
# <outer>/fake_remotes, with origin git@github.com:owner/<name>.git, which
# the fakessh stub serves. The colcon stub is replaced by one that also
# records its arguments; curl, when reached, records the call; and
# <sb>/.venv/bin/repos-manifest is a stub tool recording its directory,
# arguments and exit status.
# Usage: make_tool_root <sb> [distro...]; prints the root.
make_tool_root() {
    local sb="$1" outer root name bare work d layer dir pin
    shift
    outer="$(mktemp -d -p "$SANDBOX")"
    root="$outer/toolsys"
    mkdir -p "$root/.repos-manifest/resolved"
    cat > "$outer/m.manifest.yaml" <<'EOF'
format: 1
distros: [fakefox, fakefox2]
layers: [core, extra]
repositories:
  pkg_u:
    type: git
    url: git@github.com:owner/pkg_u.git
    version: main
  pkg_a:
    type: git
    url: git@github.com:owner/pkg_a.git
    version: main
    layer: core
    distros:
      fakefox: {version: fakefox}
  pkg_b:
    type: git
    url: git@github.com:owner/pkg_b.git
    version: main
    layer: core
    optional: true
  pkg_c:
    type: git
    url: git@github.com:owner/pkg_c.git
    version: main
    layer: extra
EOF
    printf 'manifest: ../m.manifest.yaml\nlayout: distro-dirs\n' > "$root/.repos-manifest/config.yaml"
    for name in pkg_u pkg_a pkg_b pkg_c; do
        work="$outer/work/$name"
        bare="$outer/fake_remotes/github.com/owner/$name.git"
        mkdir -p "$work" "$(dirname "$bare")"
        git -C "$work" init --quiet -b main
        echo "$name" > "$work/README.md"
        git -C "$work" add README.md
        git -C "$work" -c user.name=t -c user.email=t@t commit --quiet -m init
        git init --quiet --bare -b main "$bare"
        git -C "$work" push --quiet "$bare" main main:fakefox
    done
    for d in "$@"; do
        (cd "$outer" && PYTHONPATH="$MR_SRC" "$MR_PY" -m repos_manifest.cli resolve \
            --manifest m.manifest.yaml --distro "$d" --out "$root/.repos-manifest/resolved/$d" >/dev/null)
        for name in pkg_u pkg_a pkg_b pkg_c; do
            case "$name" in
                pkg_u) layer="" ;;
                pkg_c) layer=extra ;;
                *) layer=core ;;
            esac
            dir="$root/$d${layer:+/$layer}/src/$name"
            pin=main
            [ "$name/$d" = pkg_a/fakefox ] && pin=fakefox
            mkdir -p "$(dirname "$dir")"
            git clone --quiet --branch "$pin" "$outer/fake_remotes/github.com/owner/$name.git" "$dir"
            git -C "$dir" remote set-url origin "git@github.com:owner/$name.git"
            git -C "$dir" fetch --quiet origin
            git -C "$dir" remote set-head origin main >/dev/null
        done
        make_underlay "$sb" "$d"
    done
    echo "toolsys ros2_colcon $root" >> "$sb/.agent/projects.local"
    mkdir -p "$sb/bin" "$sb/.venv/bin"
    cat > "$sb/bin/colcon" <<'EOF'
#!/usr/bin/env bash
here="$(pwd -P)"
echo "COLCON_RAN_IN:$here CMD:$1 SOURCED:${SOURCED_LAYERS:-none}" >> "${COLCON_LOG:?}"
echo "COLCON_ARGS:$here $*" >> "${COLCON_LOG:?}.args"
if [ "$1" = "build" ]; then
    mkdir -p "$here/install"
    layer="$(basename "$here")"
    printf 'export SOURCED_LAYERS="${SOURCED_LAYERS:-}+%s"\n' "$layer" \
        > "$here/install/local_setup.bash"
fi
exit 0
EOF
    printf '#!/usr/bin/env bash\necho "CURL_RAN:$*" >> "%s"\nexit 1\n' "$sb/curl.log" > "$sb/bin/curl"
    cat > "$sb/.venv/bin/repos-manifest" <<EOF
#!/usr/bin/env bash
# A stub of the manifest tool: records where it ran, its arguments and the
# exit status it gives (TOOL_EXIT, default 0); TOOL_NEW_LAYER adds a layer
# to every resolved layers.txt, as a sync of a changed manifest would.
# status: prints the file TOOL_STATUS_FILE names and exits TOOL_EXIT; with
# no TOOL_STATUS_FILE, a format 1 document made from the last resolve and
# what is on disk (status_stub.py) and its exit status. build: records the
# underlay's SOURCED_LAYERS, COLCON_PREFIX_PATH and GIT_DIR as well, and
# prints TOOL_STDERR on stderr; with TOOL_HOLD (a file's path), writes
# what is in TMPDIR to tool.started (written whole, then moved into place)
# and waits for that file to exist, at most 10 seconds, before going on.
case "\${1:-}" in
    status)
        echo "STATUS_RAN_IN:\$(pwd -P) ARGS:\$*" >> "$sb/status.log"
        if [ -n "\${TOOL_STATUS_FILE:-}" ]; then
            cat "\$TOOL_STATUS_FILE"
            exit "\${TOOL_EXIT:-0}"
        fi
        exec "$MR_PY" -I "$sb/status_stub.py" "\$@"
        ;;
    build)
        echo "build stub: ran"
        [ -n "\${TOOL_STDERR:-}" ] && echo "\$TOOL_STDERR" >&2
        if [ -n "\${TOOL_HOLD:-}" ]; then
            ls -A "\${TMPDIR:-/tmp}" > "$sb/tool.started.part"
            mv "$sb/tool.started.part" "$sb/tool.started"
            n=0
            while [ ! -e "\$TOOL_HOLD" ] && [ "\$n" -lt 200 ]; do sleep 0.05; n=\$((n + 1)); done
        fi
        echo "TOOL_RAN_IN:\$(pwd -P) ARGS:\$* EXIT:\${TOOL_EXIT:-0} SOURCED:\${SOURCED_LAYERS:-none} PREFIX:\${COLCON_PREFIX_PATH:-unset} GIT_DIR:\${GIT_DIR:-unset}" >> "$sb/tool.log"
        exit "\${TOOL_EXIT:-0}"
        ;;
esac
if [ -n "\${TOOL_NEW_LAYER:-}" ]; then
    for f in "\$PWD"/.repos-manifest/resolved/*/layers.txt; do echo "\$TOOL_NEW_LAYER" >> "\$f"; done
fi
echo "distro stub: present, not touched"
echo "TOOL_RAN_IN:\$(pwd -P) ARGS:\$* EXIT:\${TOOL_EXIT:-0}" >> "$sb/tool.log"
exit "\${TOOL_EXIT:-0}"
EOF
    # The stub status: each repo of the last resolve, by layer, as the real
    # status names it (path relative to the root, the unnamed layer
    # "_unnamed"): missing or skipped (optional) when its place is not
    # there, not-a-directory, unusable when it has no .git, else expected.
    cat > "$sb/status_stub.py" <<'EOF'
import json, os, re, sys
args = sys.argv[1:]
distro = args[args.index("--distro") + 1]
res = os.path.join(".repos-manifest", "resolved", distro)
if not os.path.isfile(os.path.join(res, "layers.txt")):
    print("repos-manifest: error: distro %s: this system does not record it" % distro, file=sys.stderr)
    sys.exit(1)
def lines(path):
    if not os.path.isfile(path):
        return []
    with open(path) as fh:
        return [l.strip() for l in fh if l.strip() and not l.strip().startswith("#")]
optional = set(lines(os.path.join(res, "optional.txt")))
repos, ok = [], True
for layer in lines(os.path.join(res, "layers.txt")):
    path = os.path.join(res, layer + ".repos")
    keys = []
    if os.path.isfile(path):
        with open(path) as fh:
            for l in fh:
                m = re.match(r"^  ('?)([^ '#][^']*?)\1:\s*$", l)
                if m:
                    keys.append(m.group(2))
    for key in keys:
        place = "/".join([distro] + ([] if layer == "_unnamed" else [layer]) + ["src", key])
        opt = key in optional
        if not os.path.lexists(place):
            state, detail = ("skipped" if opt else "missing"), "is not there; sync clones it"
        elif not os.path.isdir(place):
            state, detail = "not-a-directory", "is there and is not a directory"
        elif not os.path.exists(os.path.join(place, ".git")):
            state, detail = "unusable", "is not a git repository of its own"
        else:
            state, detail = "expected", "on the manifest's version"
        if not opt and state in ("missing", "not-a-directory", "unusable"):
            ok = False
        repos.append({"key": key, "path": place, "layer": layer, "optional": opt, "state": state,
                      "detail": detail, "changes": 0, "unpushed": 0})
doc = {"format": 1, "ok": ok, "distros": [{"distro": distro, "ok": ok, "problem": None,
                                            "repos": repos, "not_in_manifest": []}]}
print(json.dumps(doc, indent=2))
sys.exit(0 if ok else 1)
EOF
    ln -sf "$MR_PY" "$sb/.venv/bin/python3"
    chmod +x "$sb/bin/colcon" "$sb/bin/curl" "$sb/.venv/bin/repos-manifest"
    echo "$root"
}

# The adapter on toolsys, called from <dir> (its cwd, and so the directory
# the call comes from), with the stub toolchain first on PATH.
run_tool() {  # <sb> <dir> <verb and args...>
    local sb="$1" dir="$2"
    shift 2
    (cd "$dir" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/bin:$PATH" COLCON_LOG="$sb/colcon.log" \
        VCS_LOG="$sb/vcs.log" "$sb/.agent/scripts/adapter" --project toolsys "$@")
}

# The adapter's build with selection on toolsys from <root>, TMPDIR
# <sb>/tmp, the stub tool held until <sb>/tool.release exists; TERM goes
# to the dispatcher (the background job itself, through exec) once the
# stub has started, waited for at most 5 seconds, and only then is the
# stub released, so the signal is always sent while the tool runs. Prints
# the run's exit status.
tool_build_interrupted() {  # <sb> <root>
    local sb="$1" root="$2" pid n=0 rc=0
    rm -f "$sb/tool.started" "$sb/tool.release"
    (cd "$root" && export ROS_ROOT_DIR="$sb/rosroot" TMPDIR="$sb/tmp" TOOL_HOLD="$sb/tool.release" PATH="$sb/bin:$PATH" \
        COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" \
        && exec "$sb/.agent/scripts/adapter" --project toolsys build --packages-select pkg_a) >/dev/null 2>&1 &
    pid=$!
    while [ ! -e "$sb/tool.started" ] && [ "$n" -lt 100 ]; do sleep 0.05; n=$((n + 1)); done
    kill -TERM "$pid" 2>/dev/null || true
    : > "$sb/tool.release"
    wait "$pid" || rc=$?
    echo "$rc"
}

# The tool's sync step a message printed (`cd <root> && <tool> sync
# [--distro <d>]`), to run literally.
tool_step_of() {  # <output>
    { grep -oE 'cd [^ ]+ && [^ ]+ sync( --distro [a-z0-9_]+)?' <<< "$1" || true; } | head -n1
}

tool_outside_git() {  # <root>: "outside" when no git repository holds it
    git -C "$1" rev-parse --git-dir >/dev/null 2>&1 && echo inside || echo outside
}

test_tool_route_order() {
    echo "TEST: tool route: .repos-manifest/ at the root is taken before source and the bootstrap route; validate names each second record"
    local sb root out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    assert_eq "precondition: the root is in no git repository" "outside" "$(tool_outside_git "$root")"
    printf 'source=%s\n' "$root/m.yaml" > "$sb/.agent/projects.d/toolsys"
    sed -i "s|^toolsys ros2_colcon $root\$|toolsys ros2_colcon $root role=dev distro=fakefox|" "$sb/.agent/projects.local"
    out="$(run_tool "$sb" "$sb" env 2>&1)" || rc=$?
    assert_eq "env: exit 0 with source set" "0" "$rc"
    assert_contains "env: the tool route's underlay" "rosroot/fakefox/setup.bash" "$out"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "validate: exit 1" "1" "$rc"
    assert_contains "validate names role= and distro= on the registry line" "carries role=dev distro=fakefox" "$out"
    assert_contains "validate names source and how to remove it" "project_setting.sh unset toolsys source" "$out"
    local verb
    for verb in setup sync; do
        rc=0; out="$(run_tool "$sb" "$sb" "$verb" 2>&1)" || rc=$?
        assert_eq "$verb with source set: exit 0" "0" "$rc"
        assert_not_contains "$verb with source set: not refused" "source no longer selects a route" "$out"
        assert_eq "$verb with source set: the tool's sync ran in the root" \
            "TOOL_RAN_IN:$root ARGS:sync --distro fakefox EXIT:0" "$(cat "$sb/tool.log" 2>/dev/null)"
        rm -f "$sb/tool.log"
    done
    printf 'bootstrap_url=file:///nonexistent/bootstrap.yaml\n' > "$sb/.agent/projects.d/toolsys"
    rc=0; out="$(run_tool "$sb" "$sb" setup 2>&1)" || rc=$?
    assert_eq "setup with bootstrap_url set: the tool's sync, exit 0" "0" "$rc"
    assert_eq "setup with bootstrap_url set: the tool ran in the root" \
        "TOOL_RAN_IN:$root ARGS:sync --distro fakefox EXIT:0" "$(cat "$sb/tool.log" 2>/dev/null)"
    rm -f "$sb/tool.log"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_contains "validate names bootstrap_url and how to remove it" "project_setting.sh unset toolsys bootstrap_url" "$out"
    assert_eq "no fetch: curl not reached" "false" "$([ -e "$sb/curl.log" ] && echo true || echo false)"
    assert_eq "no configs/ made in the root" "false" "$([ -e "$root/configs" ] && echo true || echo false)"
    assert_eq "the tool was not run" "false" "$([ -e "$sb/tool.log" ] && echo true || echo false)"
}

# The control is test_tool_route_order: the same source setting on a root
# with .repos-manifest/ takes the tool route.
test_source_without_tool_root_refused() {
    echo "TEST: source set on a root without .repos-manifest/: setup, sync and every verb that reads the manifest are refused, nothing fetched or imported (issue 569)"
    local sb fresh proj out rc verb label
    local -a verbs=(setup sync build test validate env repos
        "worktree_repos --issue owner/repo#1 --layer l1 --package-repos pkg_a"
        "worktree_env --worktree WT" "repo_pin pkg_a")
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    printf '#!/usr/bin/env bash\necho "CURL_RAN:$*" >> "%s"\nexit 1\n' "$sb/curl.log" > "$sb/bin/curl"; chmod +x "$sb/bin/curl"
    proj="$(make_colcon_project "$sb")"
    printf 'source=%s\n' "$sb/m.yaml" > "$sb/.agent/projects.d/tiered"
    # A root with a manifest the bootstrap route would read: each verb would
    # otherwise import, build or test.
    for verb in "${verbs[@]}"; do
        label="${verb%% *}"
        rc=0
        # shellcheck disable=SC2086  # the verb and its arguments, split on purpose
        out="$(run_adapter "$sb" ${verb//WT/$sb/wt} 2>&1)" || rc=$?
        assert_eq "$label: exit 1" "1" "$rc"
        assert_contains "$label: says source selects no route" "source no longer selects a route" "$out"
        assert_contains "$label: names the manifest tool's init" "init <manifest> --distro-dirs --distro <distro>" "$out"
        assert_contains "$label: names the unset" "project_setting.sh unset tiered source source_ref source_path" "$out"
        assert_contains "$label: says the manifest must list distros" "The manifest must list its distros (a distros: key)" "$out"
        assert_not_contains "$label: a path source gets no clone step" "init reads a file on this machine only" "$out"
    done
    assert_eq "nothing imported: vcs not run" "" "$(cat "$sb/vcs.log" 2>/dev/null)"
    assert_eq "nothing built or tested: colcon not run" "false" "$([ -e "$sb/colcon.log" ] && echo true || echo false)"
    # The same project, its root emptied, with a bootstrap URL in the
    # environment: setup would otherwise curl it.
    rm -rf "$proj"
    mkdir -p "$proj"
    fresh="$proj"
    for verb in setup sync; do
        rc=0
        out="$(BOOTSTRAP_URL=file:///nonexistent/bootstrap.yaml run_adapter "$sb" "$verb" 2>&1)" || rc=$?
        assert_eq "fresh root, $verb: exit 1" "1" "$rc"
        assert_contains "fresh root, $verb: refused" "source no longer selects a route" "$out"
    done
    # A URL source: init reads a local file only, so the message names the
    # clone at source_ref and the file at source_path inside it.
    printf 'source=https://example.invalid/m.git\nsource_ref=v1\nsource_path=sys/m.yaml\n' > "$sb/.agent/projects.d/tiered"
    rc=0; out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "URL source, setup: exit 1" "1" "$rc"
    assert_contains "URL source: names the clone and the file" \
        "init reads a file on this machine only: clone https://example.invalid/m.git at v1 and give init the file sys/m.yaml inside the clone" "$out"
    printf 'source=https://example.invalid/m.git\nsource_ref=v1\n' > "$sb/.agent/projects.d/tiered"
    out="$(run_adapter "$sb" setup 2>&1)" || true
    assert_contains "URL source without source_path: the file is manifest.yaml" \
        "give init the file manifest.yaml inside the clone" "$out"
    printf 'source=%s\n' "$sb/m.yaml" > "$sb/.agent/projects.d/tiered"
    assert_eq "nothing fetched: curl not run" "false" "$([ -e "$sb/curl.log" ] && echo true || echo false)"
    assert_eq "fresh root: no configs/ made" "false" "$([ -e "$fresh/configs" ] && echo true || echo false)"
    # Verbs that never read the manifest are not refused.
    for verb in install project_root "scope_for_pr $fresh"; do
        # shellcheck disable=SC2086  # the verb and its argument
        out="$(run_adapter "$sb" $verb 2>&1)" || true
        assert_not_contains "${verb%% *}: not refused" "source no longer selects a route" "$out"
    done
    rc=0; out="$(run_adapter "$sb" project_root 2>&1)" || rc=$?
    assert_eq "project_root: exit 0" "0" "$rc"
    rc=0; out="$(run_adapter "$sb" install 2>&1)" || rc=$?
    assert_eq "install: exit 0" "0" "$rc"
}

test_tool_unusable_root_is_an_error_never_a_fetch() {
    echo "TEST: tool route: a .repos-manifest/ the adapter cannot use is an error naming the next step, never the bootstrap route"
    local sb root out rc verb
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb")"
    printf 'bootstrap_url=file:///nonexistent/bootstrap.yaml\n' > "$sb/.agent/projects.d/toolsys"
    # Nothing resolved yet.
    for verb in validate env build test repos "repo_pin pkg_a" "worktree_repos --issue owner/pkg_a#1 --layer core --package-repos pkg_a"; do
        rc=0
        # shellcheck disable=SC2086
        out="$(run_tool "$sb" "$root" $verb 2>&1)" || rc=$?
        assert_eq "nothing resolved: $verb exits 1" "1" "$rc"
        assert_contains "nothing resolved: $verb says what is wrong" "holds nothing resolved for any distro yet" "$out"
        assert_contains "nothing resolved: $verb names the tool's own sync in the root" \
            "cd $root && $sb/.venv/bin/repos-manifest sync" "$out"
        assert_not_contains "nothing resolved: $verb names no adapter verb" "--project toolsys sync" "$out"
    done
    # The printed next step, run literally from elsewhere: the tool's sync in the root.
    out="$(run_tool "$sb" "$root" validate 2>&1)" || true
    rm -f "$sb/tool.log"
    (cd / && bash -c "$(tool_step_of "$out")") >/dev/null 2>&1
    assert_eq "nothing resolved: the printed step, run literally, runs the tool's sync in the root" \
        "TOOL_RAN_IN:$root ARGS:sync EXIT:0" "$(cat "$sb/tool.log" 2>/dev/null)"
    rm -f "$sb/tool.log"
    # Not a directory, a link to nothing, unreadable: said so; the way out
    # is fixing or removing it and setting up again, not a sync (the tool's
    # sync would refuse such a path too).
    mv "$root/.repos-manifest" "$root/.rm.aside"
    for kind in file dangling unreadable; do
        rm -rf "$root/.repos-manifest"
        case "$kind" in
            file) echo x > "$root/.repos-manifest"; want="is not a directory" ;;
            dangling) ln -s "$root/nowhere" "$root/.repos-manifest"; want="is a link to nothing" ;;
            unreadable) mkdir -p "$root/.repos-manifest/resolved"; chmod 000 "$root/.repos-manifest"; want="cannot be read" ;;
        esac
        if [ "$kind" = unreadable ] && [ -r "$root/.repos-manifest" ]; then
            chmod 755 "$root/.repos-manifest"
            echo "  SKIPPED: an unreadable directory is readable here (running as root)"
            continue
        fi
        for verb in validate env; do
            rc=0
            out="$(run_tool "$sb" "$root" "$verb" 2>&1)" || rc=$?
            assert_eq "$kind: $verb exits 1" "1" "$rc"
            assert_contains "$kind: $verb says what is wrong" "$root/.repos-manifest $want" "$out"
            assert_contains "$kind: $verb names fixing or removing it" "Fix $root/.repos-manifest" "$out"
            assert_contains "$kind: $verb names setting up again with init --distro-dirs" \
                "$sb/.venv/bin/repos-manifest init <manifest> --distro-dirs" "$out"
            assert_not_contains "$kind: $verb names no sync" "repos-manifest sync" "$out"
        done
        [ "$kind" = unreadable ] && chmod 755 "$root/.repos-manifest"
    done
    rm -rf "$root/.repos-manifest"
    mv "$root/.rm.aside" "$root/.repos-manifest"
    # A flat system: setup and sync refuse before running the tool.
    mkdir -p "$root/.repos-manifest/resolved"
    printf 'core\n' > "$root/.repos-manifest/resolved/layers.txt"
    for verb in setup sync validate env; do
        rc=0
        out="$(run_tool "$sb" "$root" "$verb" 2>&1)" || rc=$?
        assert_eq "flat: $verb exits 1" "1" "$rc"
        assert_contains "flat: $verb names the layout and the way out" "without --distro-dirs" "$out"
        assert_contains "flat: $verb names init --distro-dirs" "init <manifest> --distro-dirs" "$out"
    done
    assert_eq "the tool was not run on a flat system" "false" "$([ -e "$sb/tool.log" ] && echo true || echo false)"
    assert_eq "no fetch: curl not reached" "false" "$([ -e "$sb/curl.log" ] && echo true || echo false)"
    assert_eq "no vcs import" "false" "$([ -e "$sb/vcs.log" ] && echo true || echo false)"
    assert_eq "no configs/ made in the root" "false" "$([ -e "$root/configs" ] && echo true || echo false)"
}

test_tool_nested_key_refused_by_name() {
    echo "TEST: tool route: a repo key with a directory in it is refused by name in validate and the worktree verbs"
    local sb root out rc verb key
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    # Every key line the reader cannot read is refused by name, not only
    # one with a directory in it: a quoted key with a space, a key with
    # another character.
    for key in "'pkg q'" 'pkg+x'; do
        cp "$root/.repos-manifest/resolved/fakefox/extra.repos" "$sb/extra.repos.aside"
        printf '  %s:\n    type: git\n    url: git@github.com:owner/pkg_q.git\n    version: main\n' "$key" \
            >> "$root/.repos-manifest/resolved/fakefox/extra.repos"
        for verb in validate repos "repo_pin pkg_a"; do
            rc=0
            # shellcheck disable=SC2086
            out="$(run_tool "$sb" "$root" $verb 2>&1)" || rc=$?
            assert_eq "key $key: $verb exits 1" "1" "$rc"
            assert_contains "key $key: $verb names it and its layer" "extra: $key" "$out"
        done
        mv "$sb/extra.repos.aside" "$root/.repos-manifest/resolved/fakefox/extra.repos"
    done
    printf '  grp/pkg_n:\n    type: git\n    url: git@github.com:owner/pkg_n.git\n    version: main\n' \
        >> "$root/.repos-manifest/resolved/fakefox/core.repos"
    for verb in validate repos "repo_pin pkg_a" "worktree_repos --issue owner/pkg_a#1 --layer core --package-repos pkg_a" "worktree_env --worktree $root/worktrees/x"; do
        rc=0
        # shellcheck disable=SC2086
        out="$(run_tool "$sb" "$root" $verb 2>&1)" || rc=$?
        assert_eq "$verb exits 1" "1" "$rc"
        assert_contains "$verb names the key and its layer" "core: grp/pkg_n" "$out"
    done
}

test_tool_distro_rule() {
    echo "TEST: tool route: the calling directory chooses the distro; one distro is that one; several from elsewhere are refused, listed"
    local sb root out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox fakefox2)"
    out="$(run_tool "$sb" "$root" env 2>&1)" || rc=$?
    assert_eq "from the root, two distros: env exit 1" "1" "$rc"
    assert_contains "the refusal lists both" "several distros (fakefox, fakefox2)" "$out"
    assert_contains "the refusal says how to choose" "Run the command from inside $root/<distro>/" "$out"
    assert_contains "--from named as the adapter's own option" "a call to .agent/scripts/adapter itself may instead give its own --from" "$out"
    # validate with no distro chosen covers every one, one after another.
    rc=0; out="$(run_tool "$sb" "$root" validate 2>&1)" || rc=$?
    assert_eq "from the root, two distros: validate exit 0" "0" "$rc"
    assert_contains "validate checked fakefox" "for distro fakefox (" "$out"
    assert_contains "validate checked fakefox2" "for distro fakefox2 (" "$out"
    mv "$root/fakefox2/extra/src/pkg_c" "$(dirname "$root")/pkg_c.aside"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "from the workspace, fakefox2 broken: validate exit 1" "1" "$rc"
    assert_contains "the failing distro named" "(failing distro: fakefox2)" "$out"
    assert_contains "fakefox still checked and passed" "for distro fakefox (" "$out"
    assert_not_contains "no success line for fakefox2" "for distro fakefox2 (" "$out"
    rc=0; out="$(run_tool "$sb" "$root/fakefox" validate 2>&1)" || rc=$?
    assert_eq "from inside <root>/fakefox: validate covers fakefox alone, exit 0" "0" "$rc"
    assert_not_contains "from inside <root>/fakefox: fakefox2 not checked" "fakefox2" "$out"
    mv "$(dirname "$root")/pkg_c.aside" "$root/fakefox2/extra/src/pkg_c"
    for verb in build test sync repos "repo_pin pkg_a"; do
        rc=0
        # shellcheck disable=SC2086
        out="$(run_tool "$sb" "$root" $verb 2>&1)" || rc=$?
        assert_eq "from the root, two distros: $verb refused" "1" "$rc"
        assert_contains "from the root: $verb lists the distros" "several distros (fakefox, fakefox2)" "$out"
    done
    rc=0; out="$(run_tool "$sb" "$sb" env 2>&1)" || rc=$?
    assert_eq "from the workspace, two distros: refused" "1" "$rc"
    rc=0; out="$(run_tool "$sb" "$root/fakefox2" validate 2>&1)" || rc=$?
    assert_eq "from <root>/fakefox2: validate exit 0" "0" "$rc"
    assert_contains "from <root>/fakefox2: checked fakefox2" "for distro fakefox2" "$out"
    rc=0; out="$(run_tool "$sb" "$root/fakefox/core/src/pkg_a" env 2>&1)" || rc=$?
    assert_eq "from inside <root>/fakefox: env exit 0" "0" "$rc"
    assert_contains "from inside <root>/fakefox: fakefox's underlay" "rosroot/fakefox/setup.bash" "$out"
    rc=0; out="$(run_tool "$sb" "$sb" --from "$root/fakefox2/extra" repo_pin pkg_a 2>/dev/null)" || rc=$?
    assert_eq "--from <root>/fakefox2/extra: repo_pin reads fakefox2's pin" "main" "${out%%$'\t'*}"
    rc=0; out="$(run_tool "$sb" "$root/fakefox" repo_pin pkg_a 2>/dev/null)" || rc=$?
    assert_eq "from <root>/fakefox: repo_pin reads fakefox's pin" $'fakefox\tbranch' "$out"
    # A registered path through a link: the calling directory is physical,
    # and so is the distro's directory it is compared with.
    ln -s "$root" "$(dirname "$root")/linked"
    sed -i "s|^toolsys ros2_colcon $root\$|toolsys ros2_colcon $(dirname "$root")/linked|" "$sb/.agent/projects.local"
    rc=0; out="$(run_tool "$sb" "$root/fakefox2" validate 2>&1)" || rc=$?
    assert_eq "registered through a link, called from the physical fakefox2: exit 0" "0" "$rc"
    assert_contains "registered through a link: fakefox2 chosen" "for distro fakefox2" "$out"
    rc=0; out="$(run_tool "$sb" "$(dirname "$root")/linked/fakefox" validate 2>&1)" || rc=$?
    assert_contains "called through the link's fakefox: fakefox chosen" "for distro fakefox " "$out"
}

test_tool_setup_and_sync_run_the_tool() {
    echo "TEST: tool route: setup and sync run the tool's sync in the root and pass its status through; nothing else"
    local sb root out rc=0 before
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    # A clone behind its origin: the adapter must leave it where it is.
    git -C "$(dirname "$root")/work/pkg_c" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m later
    git -C "$(dirname "$root")/work/pkg_c" push --quiet "$(dirname "$root")/fake_remotes/github.com/owner/pkg_c.git" main
    before="$(git -C "$root/fakefox/extra/src/pkg_c" rev-parse HEAD)"
    out="$(run_tool "$sb" "$sb" setup 2>&1)" || rc=$?
    assert_eq "setup: exit 0" "0" "$rc"
    assert_eq "setup: the tool's sync for the distro, run in the root" \
        "TOOL_RAN_IN:$root ARGS:sync --distro fakefox EXIT:0" "$(cat "$sb/tool.log")"
    assert_contains "setup: the tool's output passed through" "distro stub: present, not touched" "$out"
    : > "$sb/tool.log"
    rc=0; out="$(TOOL_EXIT=1 run_tool "$sb" "$root" sync 2>&1)" || rc=$?
    assert_eq "sync: the tool's exit status 1 passed through" "1" "$rc"
    assert_eq "sync: run in the root" "TOOL_RAN_IN:$root ARGS:sync --distro fakefox EXIT:1" "$(cat "$sb/tool.log")"
    rc=0; out="$(TOOL_EXIT=130 run_tool "$sb" "$root" sync 2>&1)" || rc=$?
    assert_eq "sync: a signal's status 130 passed through" "130" "$rc"
    assert_eq "no vcs import on the tool route" "false" "$([ -e "$sb/vcs.log" ] && echo true || echo false)"
    assert_eq "the clone behind origin is where it was" "$before" "$(git -C "$root/fakefox/extra/src/pkg_c" rev-parse HEAD)"
    assert_eq "nothing fetched into it either" "" \
        "$(git -C "$root/fakefox/extra/src/pkg_c" rev-list HEAD..origin/main 2>/dev/null)"
    rc=0; out="$(TOOL_NEW_LAYER=late run_tool "$sb" "$root" sync 2>&1)" || rc=$?
    assert_contains "sync: a change in the layers is said, with what to do" \
        "the layers of distro fakefox changed; existing package worktrees keep their old env.sh; recreate them" "$out"
    rc=0; out="$(run_tool "$sb" "$root" sync 2>&1)" || rc=$?
    assert_not_contains "sync: no such line when the layers are the same" "layers of distro" "$out"
    # Nothing resolved yet (an init cut short): sync with no --distro.
    rm -rf "$root/.repos-manifest/resolved/fakefox"
    : > "$sb/tool.log"
    rc=0; out="$(run_tool "$sb" "$root" sync 2>&1)" || rc=$?
    assert_eq "nothing resolved: sync exit 0" "0" "$rc"
    assert_eq "nothing resolved: the tool's sync with no --distro" "TOOL_RAN_IN:$root ARGS:sync EXIT:0" "$(cat "$sb/tool.log")"
    rm -f "$sb/.venv/bin/repos-manifest"
    rc=0; out="$(run_tool "$sb" "$root" setup 2>&1)" || rc=$?
    assert_eq "tool not installed: exit 1" "1" "$rc"
    assert_contains "tool not installed: says how to install it" "make install-repos-manifest" "$out"
    assert_eq "no fetch: curl not reached" "false" "$([ -e "$sb/curl.log" ] && echo true || echo false)"
}

test_tool_build_runs_the_tool() {
    echo "TEST: tool route: build runs the manifest tool's build in the root, the distro's environment sourced first, its status passed through"
    local sb root out rc=0 flags
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    flags="--symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
    out="$(export COLCON_PREFIX_PATH=/stale GIT_DIR=/elsewhere/.git; run_tool "$sb" "$root/fakefox/core" build 2>&1)" || rc=$?
    assert_eq "build: exit 0" "0" "$rc"
    assert_eq "build: the tool's build for the distro, in the root, after the underlay; the prefix paths and GIT_DIR not passed on" \
        "TOOL_RAN_IN:$root ARGS:build --distro fakefox -- $flags EXIT:0 SOURCED:base PREFIX:unset GIT_DIR:unset" "$(cat "$sb/tool.log")"
    assert_contains "build: the tool's output passed through" "build stub: ran" "$out"
    assert_eq "build: the adapter runs no colcon of its own" "false" "$([ -e "$sb/colcon.log" ] && echo true || echo false)"
    : > "$sb/tool.log"
    rc=0; out="$(run_tool "$sb" "$root" build --packages-select pkg_a 2>&1)" || rc=$?
    assert_eq "build with extra arguments: exit 0" "0" "$rc"
    assert_eq "build: the caller's arguments after the adapter's colcon flags" \
        "TOOL_RAN_IN:$root ARGS:build --distro fakefox -- $flags --packages-select pkg_a EXIT:0 SOURCED:base PREFIX:unset GIT_DIR:unset" "$(cat "$sb/tool.log")"
    assert_not_contains "a selection that worked: no note" "NOTE:" "$out"
    # The note comes only on the tool's selection refusal (its two texts in
    # build.py), only for arguments the tool counts as selection.
    local up_to_refusal="ERROR: --packages-up-to names packages colcon must find in each layer it builds, and a layer without them fails; this run would build 3 layers (_unnamed, core, extra); nothing was run. Name the one layer that has those packages: \`repos-manifest build <layer> -- ...\`"
    local not_built_refusal="ERROR: a run with package selection builds only part of a layer, so it only rebuilds layers that are built, with the repos their record has; not built: extra (never built); nothing was run. Build it without package selection first: \`repos-manifest build extra\`"
    local target_refusal="ERROR: a run with \`--cmake-target\` builds only part of a layer, so it only rebuilds layers that are built, with the repos their record has; not built: core (never built); nothing was run. Build it without \`--cmake-target\` first: \`repos-manifest build core extra\`"
    local note_text="the adapter builds every layer, so build without selection first, or run the tool's step yourself with the distro's environment sourced, from a shell with no other workspace's prefix paths: unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX && source $sb/rosroot/fakefox/setup.bash && cd $root && $sb/.venv/bin/repos-manifest build --distro fakefox <layer> -- <colcon arguments>"
    rc=0; out="$(TOOL_EXIT=1 TOOL_STDERR="$up_to_refusal" run_tool "$sb" "$root" build --packages-up-to pkg_a 2>&1)" || rc=$?
    assert_eq "a selection the tool refuses: its exit status 1" "1" "$rc"
    assert_contains "a selection the tool refuses: the tool's message passed through" "$up_to_refusal" "$out"
    assert_contains "a selection the tool refuses: its stdout passed through" "build stub: ran" "$out"
    assert_contains "a selection the tool refuses: the step with the environment sourced" "$note_text" "$out"
    rc=0; out="$(TOOL_EXIT=1 TOOL_STDERR="$not_built_refusal" run_tool "$sb" "$root" build --packages-select=pkg_a 2>&1)" || rc=$?
    assert_eq "a selection on a layer not built: exit 1" "1" "$rc"
    assert_contains "a selection on a layer not built: the note" "$note_text" "$out"
    rc=0; out="$(TOOL_EXIT=1 TOOL_STDERR="$target_refusal" run_tool "$sb" "$root" build --cmake-target install_x 2>&1)" || rc=$?
    assert_eq "--cmake-target on a layer not built: exit 1" "1" "$rc"
    assert_contains "--cmake-target on a layer not built: the note" "$note_text" "$out"
    rc=0; out="$(TOOL_EXIT=1 TOOL_STDERR="ERROR: colcon failed in layer core; setup.bash ..." run_tool "$sb" "$root" build --packages-select pkg_a 2>&1)" || rc=$?
    assert_eq "selection, another failure: exit 1" "1" "$rc"
    assert_contains "selection, another failure: the tool's message passed through" "ERROR: colcon failed in layer core" "$out"
    assert_not_contains "selection, another failure: no note" "NOTE:" "$out"
    for arg in "--packages-skip pkg_a" "--packages-skip-regex pkg_.*" "--packages-ignore=pkg_a" "--packages-ignore-regex pkg_.*" "--packages-skip-build-finished"; do
        rc=0
        # shellcheck disable=SC2086
        out="$(TOOL_EXIT=1 TOOL_STDERR="$not_built_refusal" run_tool "$sb" "$root" build $arg 2>&1)" || rc=$?
        assert_eq "$arg, a failure: exit 1" "1" "$rc"
        assert_not_contains "$arg is not selection to the tool: no note" "NOTE:" "$out"
    done
    rc=0; out="$(TOOL_EXIT=1 run_tool "$sb" "$root" build 2>&1)" || rc=$?
    assert_eq "a failed build: exit 1" "1" "$rc"
    assert_not_contains "a failed build with no selection: no note" "NOTE:" "$out"
    rc=0; out="$(TOOL_EXIT=130 run_tool "$sb" "$root" build --packages-select pkg_a 2>&1)" || rc=$?
    assert_eq "selection, a signal's status 130 passed through" "130" "$rc"
    assert_not_contains "selection, a signal: no note" "NOTE:" "$out"
    # The status is the tool's whatever the caller's pipefail: the
    # dispatcher's set -o pipefail taken out in this sandbox's copy.
    sed -i 's/^set -euo pipefail$/set -eu/' "$sb/.agent/scripts/adapter"
    assert_eq "the sandbox's dispatcher runs without pipefail" "0" \
        "$(grep -c pipefail "$sb/.agent/scripts/adapter" || true)"
    rc=0; out="$(TOOL_EXIT=3 TOOL_STDERR="ERROR: colcon failed in layer core" run_tool "$sb" "$root" build --packages-select pkg_a 2>&1)" || rc=$?
    assert_eq "selection without pipefail: the tool's status 3 passed through" "3" "$rc"
    rc=0; out="$(TOOL_EXIT=1 TOOL_STDERR="$not_built_refusal" run_tool "$sb" "$root" build --packages-select pkg_a 2>&1)" || rc=$?
    assert_eq "selection without pipefail, refused: exit 1" "1" "$rc"
    assert_contains "selection without pipefail, refused: the note" "$note_text" "$out"
    cp "$REAL_ROOT/.agent/scripts/adapter" "$sb/.agent/scripts/adapter"
    # With stderr closed the tool runs to the end, its status passed through.
    : > "$sb/tool.log"
    rc=0; out="$(TOOL_STDERR="a line on stderr" run_tool "$sb" "$root" build --packages-select pkg_a 2>&-)" || rc=$?
    assert_eq "selection, stderr closed: a successful build exits 0" "0" "$rc"
    assert_contains "selection, stderr closed: the tool ran to the end" \
        "ARGS:build --distro fakefox -- $flags --packages-select pkg_a EXIT:0" "$(cat "$sb/tool.log")"
    assert_contains "selection, stderr closed: its stdout passed through" "build stub: ran" "$out"
    rc=0; out="$(TOOL_EXIT=1 TOOL_STDERR="$not_built_refusal" run_tool "$sb" "$root" build --packages-select pkg_a 2>&-)" || rc=$?
    assert_eq "selection, stderr closed, refused: exit 1" "1" "$rc"
    # A stderr that cannot take the writes (a full device): the same.
    mkdir -p "$sb/tmp"
    rc=0; out="$(TMPDIR="$sb/tmp" TOOL_STDERR="a line on stderr" run_tool "$sb" "$root" build --packages-select pkg_a 2>/dev/full)" || rc=$?
    assert_eq "selection, stderr on /dev/full: a successful build exits 0" "0" "$rc"
    assert_eq "selection: no temporary file left behind" "" "$(ls -A "$sb/tmp")"
    # Interrupted: TERM to the dispatcher while the tool builds. The
    # temporary file goes and the run ends with TERM's status, 143.
    rc="$(tool_build_interrupted "$sb" "$root")"
    assert_contains "selection, TERM: the temporary file was there while the tool ran" "tmp." "$(cat "$sb/tool.started")"
    assert_eq "selection, TERM: exit 143" "143" "$rc"
    assert_eq "selection, TERM: no temporary file left behind" "" "$(ls -A "$sb/tmp")"
    # A caller with its own TERM handler (one put at the top of the
    # sandbox's dispatcher): the file goes, then that handler runs.
    sed -i "s|^set -euo pipefail\$|&\ntrap 'echo caller TERM handler ran >> \"$sb/caller.log\"; exit 7' TERM|" "$sb/.agent/scripts/adapter"
    assert_eq "the sandbox's dispatcher has its own TERM handler" "1" "$(grep -c 'caller TERM handler' "$sb/.agent/scripts/adapter")"
    rc="$(tool_build_interrupted "$sb" "$root")"
    assert_eq "selection, TERM, a caller's handler: its status, 7" "7" "$rc"
    assert_eq "selection, TERM, a caller's handler: it ran" "caller TERM handler ran" "$(cat "$sb/caller.log" 2>/dev/null)"
    assert_eq "selection, TERM, a caller's handler: no temporary file left behind" "" "$(ls -A "$sb/tmp")"
    cp "$REAL_ROOT/.agent/scripts/adapter" "$sb/.agent/scripts/adapter"
    rc=0; out="$(TOOL_EXIT=130 run_tool "$sb" "$root" build 2>&1)" || rc=$?
    assert_eq "a signal's status 130 passed through" "130" "$rc"
    # A nested key: the tool reads it, so build runs; env and test still refuse it.
    printf '  grp/pkg_n:\n    type: git\n    url: git@github.com:owner/pkg_n.git\n    version: main\n' \
        >> "$root/.repos-manifest/resolved/fakefox/core.repos"
    : > "$sb/tool.log"
    rc=0; out="$(run_tool "$sb" "$root" build 2>&1)" || rc=$?
    assert_eq "a nested key: build runs the tool, exit 0" "0" "$rc"
    assert_contains "a nested key: the tool ran" "ARGS:build --distro fakefox" "$(cat "$sb/tool.log")"
    for verb in env test; do
        rc=0; out="$(run_tool "$sb" "$root" "$verb" 2>&1)" || rc=$?
        assert_eq "a nested key: $verb still refuses" "1" "$rc"
        assert_contains "a nested key: $verb names it" "core: grp/pkg_n" "$out"
    done
    sed -i '/grp\/pkg_n/,$d' "$root/.repos-manifest/resolved/fakefox/core.repos"
    # No underlay, no tool: refused before anything runs.
    : > "$sb/tool.log"
    mv "$sb/rosroot/fakefox/setup.bash" "$sb/setup.bash.aside"
    rc=0; out="$(run_tool "$sb" "$root" build 2>&1)" || rc=$?
    assert_eq "no underlay: exit 1" "1" "$rc"
    assert_contains "no underlay: said" "ROS underlay not found: $sb/rosroot/fakefox/setup.bash" "$out"
    assert_eq "no underlay: the tool not run" "" "$(cat "$sb/tool.log")"
    mv "$sb/setup.bash.aside" "$sb/rosroot/fakefox/setup.bash"
    rm "$sb/.venv/bin/repos-manifest"
    rc=0; out="$(run_tool "$sb" "$root" build 2>&1)" || rc=$?
    assert_eq "tool not installed: exit 1" "1" "$rc"
    assert_contains "tool not installed: says how to install it" "make install-repos-manifest" "$out"
}

test_tool_test_over_the_resolved_layers() {
    echo "TEST: tool route: test runs colcon per resolved layer, in order, over the resolved repos on disk; env sources each built layer"
    local sb root out rc=0 layer
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    # A built tree, as the tool's colcon leaves it.
    for layer in "" core extra; do
        mkdir -p "$root/fakefox${layer:+/$layer}/install"
        printf 'export SOURCED_LAYERS="${SOURCED_LAYERS:-}+%s"\n' "${layer:-fakefox}" \
            > "$root/fakefox${layer:+/$layer}/install/local_setup.bash"
    done
    rc=0; out="$(run_tool "$sb" "$root" test 2>&1)" || rc=$?
    assert_eq "test: exit 0" "0" "$rc"
    assert_eq "test: every layer, in order, each over the layers built" \
        "COLCON_RAN_IN:$root/fakefox CMD:test SOURCED:base+fakefox
COLCON_RAN_IN:$root/fakefox/core CMD:test SOURCED:base+fakefox+core
COLCON_RAN_IN:$root/fakefox/extra CMD:test SOURCED:base+fakefox+core+extra" "$(cat "$sb/colcon.log")"
    assert_contains "test: the unnamed layer's resolved repo on disk as its base path" \
        "COLCON_ARGS:$root/fakefox test --base-paths src/pkg_u --event-handlers console_direct+ --return-code-on-test-failure" "$(cat "$sb/colcon.log.args")"
    assert_contains "test: each resolved repo on disk as a base path" \
        "COLCON_ARGS:$root/fakefox/core test --base-paths src/pkg_a src/pkg_b --event-handlers" "$(cat "$sb/colcon.log.args")"
    # The tool's build rule: a required repo (pkg_c) not on disk fails the
    # run before colcon runs, naming it and the tool's sync.
    assert_eq "precondition: optional.txt names pkg_b alone" "pkg_b" \
        "$(grep -v '^#' "$root/.repos-manifest/resolved/fakefox/optional.txt")"
    mv "$root/fakefox/extra/src/pkg_c" "$(dirname "$root")/pkg_c.aside"
    : > "$sb/colcon.log"
    rc=0; out="$(run_tool "$sb" "$root" test 2>&1)" || rc=$?
    assert_eq "test, a required repo missing: exit 1" "1" "$rc"
    assert_contains "test, a required repo missing: named" \
        "ERROR: not on disk, and not optional: pkg_c (layer extra); nothing was run" "$out"
    assert_contains "test, a required repo missing: the tool's sync named" \
        "Run: cd $root && $sb/.venv/bin/repos-manifest sync --distro fakefox (it clones what is missing)" "$out"
    assert_not_contains "test, a required repo missing: no layer skipped" "Skipping layer" "$out"
    assert_eq "test, a required repo missing: colcon not run" "" "$(cat "$sb/colcon.log")"
    mv "$(dirname "$root")/pkg_c.aside" "$root/fakefox/extra/src/pkg_c"
    # An optional repo (pkg_b) not on disk is left out; the tests run.
    mv "$root/fakefox/core/src/pkg_b" "$(dirname "$root")/pkg_b.aside"
    : > "$sb/colcon.log"
    : > "$sb/colcon.log.args"
    rc=0; out="$(run_tool "$sb" "$root" test 2>&1)" || rc=$?
    assert_eq "test, an optional repo missing: exit 0" "0" "$rc"
    assert_contains "test, an optional repo missing: left out" \
        "COLCON_ARGS:$root/fakefox/core test --base-paths src/pkg_a --event-handlers" "$(cat "$sb/colcon.log.args")"
    assert_eq "test, an optional repo missing: every layer tested" "3" "$(wc -l < "$sb/colcon.log")"
    mv "$(dirname "$root")/pkg_b.aside" "$root/fakefox/core/src/pkg_b"
    # A repo dropped from the resolve but left on disk is not tested; a
    # layer whose repos are all optional (pkg_c made so here) and none on
    # disk is skipped with a line.
    sed -i '/^  pkg_b:/,/^    version:/d' "$root/.repos-manifest/resolved/fakefox/core.repos"
    cp "$root/.repos-manifest/resolved/fakefox/optional.txt" "$sb/optional.txt.aside"
    echo pkg_c >> "$root/.repos-manifest/resolved/fakefox/optional.txt"
    mv "$root/fakefox/extra/src/pkg_c" "$(dirname "$root")/pkg_c.aside"
    : > "$sb/colcon.log"
    : > "$sb/colcon.log.args"
    rc=0; out="$(run_tool "$sb" "$root" test --packages-select pkg_a 2>&1)" || rc=$?
    assert_eq "test, a repo dropped and an optional-only layer emptied: exit 0" "0" "$rc"
    assert_contains "test: the dropped repo left out, the caller's arguments last" \
        "COLCON_ARGS:$root/fakefox/core test --base-paths src/pkg_a --event-handlers console_direct+ --return-code-on-test-failure --packages-select pkg_a" "$(cat "$sb/colcon.log.args")"
    assert_contains "test: the optional-only layer skipped, said" \
        "Skipping layer extra (every repo extra.repos lists is optional, and none is on disk in $root/fakefox/extra/src)" "$out"
    assert_not_contains "test: no colcon run in the emptied layer" "$root/fakefox/extra " "$(cat "$sb/colcon.log.args")"
    mv "$(dirname "$root")/pkg_c.aside" "$root/fakefox/extra/src/pkg_c"
    mv "$sb/optional.txt.aside" "$root/.repos-manifest/resolved/fakefox/optional.txt"
    # A layer's resolved .repos file missing is not "none on disk": test
    # fails before colcon runs, naming the file and the tool's sync.
    mv "$root/.repos-manifest/resolved/fakefox/core.repos" "$sb/core.repos.aside"
    : > "$sb/colcon.log"
    rc=0; out="$(run_tool "$sb" "$root" test 2>&1)" || rc=$?
    assert_eq "test, a layer's .repos file missing: exit 1" "1" "$rc"
    assert_contains "test, a layer's .repos file missing: the file named" \
        "ERROR: $root/.repos-manifest/resolved/fakefox/core.repos is missing, and the last resolve's layers.txt lists layer 'core'" "$out"
    assert_contains "test, a layer's .repos file missing: the tool's sync named" \
        "Run: cd $root && $sb/.venv/bin/repos-manifest sync --distro fakefox" "$out"
    assert_not_contains "test, a layer's .repos file missing: no layer skipped as if empty" "Skipping layer core" "$out"
    assert_not_contains "test, a layer's .repos file missing: no success said" "passed" "$out"
    assert_eq "test, a layer's .repos file missing: colcon not run" "" "$(cat "$sb/colcon.log")"
    mv "$sb/core.repos.aside" "$root/.repos-manifest/resolved/fakefox/core.repos"
    # A layer's resolved .repos file that cannot be read is not "none on
    # disk" either: test fails before colcon runs, naming the file.
    chmod 000 "$root/.repos-manifest/resolved/fakefox/core.repos"
    if [ -r "$root/.repos-manifest/resolved/fakefox/core.repos" ]; then
        echo "  SKIPPED: an unreadable file is readable here (running as root)"
    else
        : > "$sb/colcon.log"
        rc=0; out="$(run_tool "$sb" "$root" test 2>&1)" || rc=$?
        assert_eq "test, a layer's .repos file unreadable: exit 1" "1" "$rc"
        assert_contains "test, a layer's .repos file unreadable: the file named" \
            "ERROR: $root/.repos-manifest/resolved/fakefox/core.repos could not be read, and the last resolve's layers.txt lists layer 'core'" "$out"
        assert_not_contains "test, a layer's .repos file unreadable: no layer skipped as if empty" "Skipping layer core" "$out"
        assert_not_contains "test, a layer's .repos file unreadable: no success said" "passed" "$out"
        assert_eq "test, a layer's .repos file unreadable: colcon not run" "" "$(cat "$sb/colcon.log")"
    fi
    chmod 644 "$root/.repos-manifest/resolved/fakefox/core.repos"
    rc=0; out="$(run_tool "$sb" "$root" env 2>&1)" || rc=$?
    assert_eq "env: the underlay, then each built layer in order" \
        "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
source $sb/rosroot/fakefox/setup.bash
source $root/fakefox/install/local_setup.bash
source $root/fakefox/core/install/local_setup.bash
source $root/fakefox/extra/install/local_setup.bash" "$out"
}

# A canned status document for fakefox in <out>: the stub's own document
# for the root as it is, then <python> run on it (doc, d: the distro's
# entry, r: its repos by key).
tool_status_doc() {  # <sb> <root> <out> <python>
    (cd "$2" && "$MR_PY" -I "$1/status_stub.py" --distro fakefox) > "$3.base" || true
    "$MR_PY" -I -c '
import json, sys
doc = json.load(open(sys.argv[1]))
d = doc["distros"][0]
r = {x["key"]: x for x in d["repos"]}
exec(sys.argv[3])
with open(sys.argv[2], "w") as fh:
    json.dump(doc, fh)' "$3.base" "$3" "$4"
}

test_tool_validate() {
    echo "TEST: tool route: validate reads repos-manifest status: its exit status decides, its document names what failed"
    local sb root out rc=0 doc step
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    doc="$sb/status.json"
    step="cd $root && $sb/.venv/bin/repos-manifest sync --distro fakefox"
    out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "validate: exit 0" "0" "$rc"
    assert_eq "validate: the success line names the distro, what read it and the counts" \
        "✅ ros2_colcon checkout read against the manifest for distro fakefox (repos-manifest status: 4 repo(s), 4 as expected, 0 with a warning above, 0 optional and skipped; clones read as last fetched, nothing fetched)" "$out"
    assert_eq "validate: status ran in the root for the distro, as JSON" \
        "STATUS_RAN_IN:$root ARGS:status --distro fakefox --json" "$(cat "$sb/status.log")"
    assert_eq "validate: no sync, no build" "false" "$([ -e "$sb/tool.log" ] && echo true || echo false)"
    # Each state the tool reports, from canned documents.
    tool_status_doc "$sb" "$root" "$doc" '
r["pkg_a"]["state"] = "different"; r["pkg_a"]["detail"] = "is on branch other, not fakefox"
r["pkg_c"]["state"] = "left-alone"; r["pkg_c"]["detail"] = "has a rebase in progress"'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "different and left-alone: exit 0" "0" "$rc"
    assert_contains "different: a warning with the tool's detail" \
        "⚠️ distro fakefox: $root/fakefox/core/src/pkg_a different: is on branch other, not fakefox" "$out"
    assert_contains "left-alone: a warning with the tool's detail" \
        "⚠️ distro fakefox: $root/fakefox/extra/src/pkg_c left-alone: has a rebase in progress" "$out"
    assert_contains "different and left-alone: counted in the pass line" "2 as expected, 2 with a warning above" "$out"
    # Git output that is not UTF-8: the tool writes the byte as a lone
    # surrogate (JSON \udcXX). The reader prints it as \xXX, any other lone
    # surrogate as \uXXXX; no traceback, no line lost.
    tool_status_doc "$sb" "$root" "$doc" '
r["pkg_a"]["state"] = "different"; r["pkg_a"]["detail"] = "is on branch caf\udce9, not \ud800fakefox"'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "a lone surrogate: exit 0" "0" "$rc"
    assert_not_contains "a lone surrogate: no traceback" "Traceback" "$out"
    assert_contains "a lone surrogate: the byte as \\xXX, another surrogate as \\uXXXX" \
        "⚠️ distro fakefox: $root/fakefox/core/src/pkg_a different: is on branch caf\\xe9, not \\ud800fakefox" "$out"
    assert_contains "a lone surrogate: every repo still counted" "4 repo(s), 3 as expected, 1 with a warning above" "$out"
    # The reader itself failing: the message gives its exit status, and status's.
    mv "$sb/.venv/bin/python3" "$sb/python3.aside"
    printf '#!/usr/bin/env bash\ncat >/dev/null\nexit 3\n' > "$sb/.venv/bin/python3"
    chmod +x "$sb/.venv/bin/python3"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "the reader failing: exit 1" "1" "$rc"
    assert_contains "the reader failing: its exit status and status's named" \
        "❌ distro fakefox: $sb/.venv/bin/python3 could not read the document repos-manifest status printed ($sb/.venv/bin/python3 exited 3; repos-manifest status exited 0)" "$out"
    rm "$sb/.venv/bin/python3"
    mv "$sb/python3.aside" "$sb/.venv/bin/python3"
    tool_status_doc "$sb" "$root" "$doc" 'r["pkg_u"]["changes"] = 3; r["pkg_u"]["unpushed"] = 1'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "local changes and unpushed commits: exit 0" "0" "$rc"
    assert_contains "local changes and unpushed commits: a note" \
        "NOTE: distro fakefox: $root/fakefox/src/pkg_u has local work (3 changed file(s), 1 commit(s) not on origin); it does not fail validate" "$out"
    tool_status_doc "$sb" "$root" "$doc" 'd["not_in_manifest"] = [{"key": "pkg_old", "path": "fakefox/core/src/pkg_old"}]'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "not_in_manifest: exit 0" "0" "$rc"
    assert_contains "not_in_manifest: a warning naming the path" \
        "⚠️ distro fakefox: $root/fakefox/core/src/pkg_old is still on disk and no longer in the manifest" "$out"
    assert_contains "not_in_manifest: the pass line counts the manifest's repos, the path apart" \
        "(repos-manifest status: 4 repo(s), 4 as expected, 0 with a warning above, 0 optional and skipped; besides them, 1 path(s) on disk no longer in the manifest, warned above; clones read as last fetched, nothing fetched)" "$out"
    tool_status_doc "$sb" "$root" "$doc" 'r["pkg_b"]["state"] = "unusable"; r["pkg_b"]["detail"] = "has no commit checked out"'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "an optional repo unusable: exit 0" "0" "$rc"
    assert_contains "an optional repo unusable: a warning" \
        "⚠️ distro fakefox: $root/fakefox/core/src/pkg_b unusable (optional, so it does not fail validate): has no commit checked out" "$out"
    tool_status_doc "$sb" "$root" "$doc" '
r["pkg_a"]["state"] = "blocked-place"; r["pkg_a"]["detail"] = "fakefox/core is a link"
doc["ok"] = d["ok"] = False'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" TOOL_EXIT=1 run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "blocked-place: exit 1" "1" "$rc"
    assert_contains "blocked-place: named with the tool's detail" \
        "❌ distro fakefox: $root/fakefox/core/src/pkg_a blocked-place: fakefox/core is a link" "$out"
    assert_contains "blocked-place: the failing distro named" "Validation failed: 1 issue(s) (failing distro: fakefox)." "$out"
    assert_not_contains "blocked-place: no pass line" "✅" "$out"
    tool_status_doc "$sb" "$root" "$doc" '
del d["repos"], d["not_in_manifest"]
d["problem"] = "the manifest ../m.manifest.yaml cannot be read"
doc["ok"] = d["ok"] = False'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" TOOL_EXIT=1 run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "a distro's problem: exit 1" "1" "$rc"
    assert_contains "a distro's problem: said" \
        "❌ distro fakefox cannot be read or resolved: the manifest ../m.manifest.yaml cannot be read" "$out"
    : > "$doc"
    rc=0; out="$(TOOL_STATUS_FILE="$doc" TOOL_EXIT=1 run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "no document: exit 1" "1" "$rc"
    assert_contains "no document: said, with the exit status" "❌ distro fakefox: repos-manifest status gave no document (exit 1)" "$out"
    rc=0; out="$(TOOL_STATUS_FILE="$doc" TOOL_EXIT=2 run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "exit 2: exit 1" "1" "$rc"
    assert_contains "exit 2: named" "❌ distro fakefox: repos-manifest status exited 2" "$out"
    echo 'not json' > "$doc"
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "not JSON: exit 1" "1" "$rc"
    assert_contains "not JSON: said" "repos-manifest status printed something that is not one JSON document" "$out"
    tool_status_doc "$sb" "$root" "$doc" 'doc["format"] = 2'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "format 2: exit 1" "1" "$rc"
    assert_contains "format 2: named" "printed a document of format 2; the adapter reads format 1" "$out"
    # No problem, but a list missing or null: malformed, not zero repos.
    tool_status_doc "$sb" "$root" "$doc" 'del d["repos"]'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "no problem, repos missing: exit 1" "1" "$rc"
    assert_contains "no problem, repos missing: malformed, said" \
        "❌ distro fakefox: repos-manifest status printed a malformed document: the entry for distro fakefox has no problem and no repos list" "$out"
    assert_not_contains "no problem, repos missing: not passed as zero repos" "✅" "$out"
    tool_status_doc "$sb" "$root" "$doc" 'd["not_in_manifest"] = None'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "no problem, not_in_manifest null: exit 1" "1" "$rc"
    assert_contains "no problem, not_in_manifest null: malformed, said" \
        "has no problem and no not_in_manifest list" "$out"
    tool_status_doc "$sb" "$root" "$doc" 'd["repos"] = None; d["problem"] = ""'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "an empty problem, repos null: exit 1" "1" "$rc"
    assert_contains "an empty problem, repos null: malformed, said" "has no problem and no repos list" "$out"
    tool_status_doc "$sb" "$root" "$doc" 'r["pkg_c"]["state"] = "missing"'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" TOOL_EXIT=0 run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "exit 0 with a failing repo: exit 1" "1" "$rc"
    assert_contains "exit 0 with a failing repo: the disagreement said" "document and its exit status disagree" "$out"
    tool_status_doc "$sb" "$root" "$doc" 'pass'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" TOOL_EXIT=1 run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "exit 1 with nothing failing: exit 1" "1" "$rc"
    assert_contains "exit 1 with nothing failing: the disagreement said" "document and its exit status disagree (exit 1" "$out"
    tool_status_doc "$sb" "$root" "$doc" 'r["pkg_c"]["state"] = "sideways"'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "a state the adapter does not know: exit 1" "1" "$rc"
    assert_contains "a state the adapter does not know: named" "is in a state the adapter does not know, 'sideways'" "$out"
    # The last resolve against status's repos: out of date is a warning.
    tool_status_doc "$sb" "$root" "$doc" '
d["repos"] = [x for x in d["repos"] if x["key"] != "pkg_c"]
d["repos"].append(dict(r["pkg_a"], key="pkg_new", path="fakefox/core/src/pkg_new"))'
    rc=0; out="$(TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "a resolve out of date: exit 0" "0" "$rc"
    assert_contains "a resolve out of date: a warning naming both sides and the sync" \
        "is out of date with the manifest (in the manifest only: core/pkg_new; in the last resolve only: extra/pkg_c); the adapter's other verbs read the last resolve; run: $step" "$out"
    assert_contains "a resolve out of date: the pass line names the warning apart from the counts" \
        "(repos-manifest status: 4 repo(s), 4 as expected, 0 with a warning above, 0 optional and skipped; the last resolve out of date with the manifest, warned above; clones read as last fetched, nothing fetched)" "$out"
    # The same comparison under a UTF-8 locale whose collation puts
    # "_unnamed" after "core" (C order puts it first): the lists are sorted
    # in C order, so comm must compare in C order too. GNU comm (CI's) says
    # "not in sorted order" and gives a wrong difference otherwise; a comm
    # that compares bytes in every locale (uutils) hides it, so GNU comm is
    # put first on PATH when it is here under another name (gnucomm).
    local utf8 gnu=""
    utf8="$(locale -a 2>/dev/null | grep -ixE 'en_US\.utf-?8' | head -n1 || true)"
    if comm --version 2>/dev/null | head -n1 | grep -q GNU; then
        gnu="comm"
    elif command -v gnucomm >/dev/null 2>&1; then
        ln -s "$(command -v gnucomm)" "$sb/bin/comm"
        gnu=gnucomm
    fi
    if [ -z "$utf8" ] || [ -z "$gnu" ]; then
        echo "  SKIPPED (locale part): needs the en_US.UTF-8 locale and GNU comm (locale: ${utf8:-none}; GNU comm: ${gnu:-none})"
        LOCALE_SKIPPED=$((LOCALE_SKIPPED + 1))
    else
        tool_status_doc "$sb" "$root" "$doc" 'd["repos"] = [x for x in d["repos"] if x["layer"] != "_unnamed"]'
        rc=0; out="$(LC_ALL="$utf8" TOOL_STATUS_FILE="$doc" run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
        assert_eq "under $utf8 with $gnu: exit 0" "0" "$rc"
        assert_contains "under $utf8 with $gnu: the unnamed layer's repo alone, in the last resolve only" \
            "is out of date with the manifest (in the last resolve only: _unnamed/pkg_u); the adapter's other verbs" "$out"
        assert_not_contains "under $utf8 with $gnu: comm did not see unsorted input" "sorted order" "$out"
    fi
    # The gnucomm link goes whichever branch ran, so no later part sees it.
    rm -f "$sb/bin/comm"
    # The tool's interpreter missing, or a link to nothing: named as that,
    # not as the tool not installed, with the step that makes the venv again.
    local venv_step="make the venv again: remove the directory $sb/.venv and the two stamp files $sb/.make/setup-dev.done and $sb/.make/repos-manifest.done, then run make install-repos-manifest from $sb"
    mv "$sb/.venv/bin/python3" "$sb/python3.aside"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "no python3 beside the tool: exit 1" "1" "$rc"
    assert_contains "no python3 beside the tool: named, with the venv step" \
        "❌ distro fakefox: the manifest tool is at $sb/.venv/bin/repos-manifest, but $sb/.venv/bin/python3, the venv's Python that runs it and reads status's document, is missing" "$out"
    assert_contains "no python3 beside the tool: the step" "$venv_step" "$out"
    assert_not_contains "no python3 beside the tool: the tool not called uninstalled" "is not installed" "$out"
    assert_not_contains "no python3 beside the tool: no rm command printed" "rm -rf" "$out"
    ln -s "$sb/nowhere/python3" "$sb/.venv/bin/python3"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "python3 a link to nothing: exit 1" "1" "$rc"
    assert_contains "python3 a link to nothing: named, with its target" \
        "$sb/.venv/bin/python3, the venv's Python that runs it and reads status's document, is a link to nothing ($sb/nowhere/python3)" "$out"
    assert_contains "python3 a link to nothing: the step" "$venv_step" "$out"
    rm "$sb/.venv/bin/python3"
    mv "$sb/python3.aside" "$sb/.venv/bin/python3"
    # The tool itself missing: not installed, the install step.
    mv "$sb/.venv/bin/repos-manifest" "$sb/repos-manifest.aside"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "the tool missing: exit 1" "1" "$rc"
    assert_contains "the tool missing: not installed, the install step" \
        "the manifest tool is not installed at $sb/.venv/bin/repos-manifest, so status cannot be read; run: make install-repos-manifest" "$out"
    mv "$sb/repos-manifest.aside" "$sb/.venv/bin/repos-manifest"
    # A leftover of another route is noted, without failing.
    mkdir -p "$root/configs/manifest"
    echo "file:///x/bootstrap.yaml" > "$root/configs/project_bootstrap.url"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "leftover configs/: still exit 0" "0" "$rc"
    assert_contains "leftover configs/: noted, both named" \
        "NOTE: $root/configs/manifest and $root/configs/project_bootstrap.url, left from another route, is not read on the tool route" "$out"
    rm -rf "$root/configs"
    mv "$root/fakefox/core/src/pkg_b" "$(dirname "$root")/pkg_b.aside"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "a missing optional repo: still exit 0" "0" "$rc"
    assert_contains "a missing optional repo: counted as skipped" "1 optional and skipped" "$out"
    mv "$root/fakefox/src/pkg_u" "$(dirname "$root")/pkg_u.aside"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "a missing repo of the unnamed layer: exit 1" "1" "$rc"
    assert_contains "it is named, with its place and the tool's sync" \
        "❌ distro fakefox: $root/fakefox/src/pkg_u missing: is not there; sync clones it (run: $step)" "$out"
    mv "$(dirname "$root")/pkg_u.aside" "$root/fakefox/src/pkg_u"
    # An emptied clone (issue 517, item 2): unusable, a failure.
    mv "$root/fakefox/extra/src/pkg_c" "$(dirname "$root")/pkg_c.aside"
    mkdir "$root/fakefox/extra/src/pkg_c"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "an emptied clone: exit 1" "1" "$rc"
    assert_contains "an emptied clone: unusable, named" \
        "❌ distro fakefox: $root/fakefox/extra/src/pkg_c unusable: is not a git repository of its own" "$out"
    rmdir "$root/fakefox/extra/src/pkg_c"
    mv "$(dirname "$root")/pkg_c.aside" "$root/fakefox/extra/src/pkg_c"
    rm "$root/.repos-manifest/resolved/fakefox/extra.repos"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "a layer's .repos file missing: exit 1" "1" "$rc"
    assert_contains "it is named" "layer 'extra': missing $root/.repos-manifest/resolved/fakefox/extra.repos" "$out"
}

test_tool_repos_pin_and_worktree_verbs() {
    echo "TEST: tool route: repos, repo_pin, worktree_repos and worktree_env read the tool's layout"
    local sb root out rc=0 wt
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    out="$(run_tool "$sb" "$sb" repos 2>&1)" || rc=$?
    assert_eq "repos: every clone, by layer" \
        "pkg_u:$root/fakefox/src/pkg_u
pkg_a:$root/fakefox/core/src/pkg_a
pkg_b:$root/fakefox/core/src/pkg_b
pkg_c:$root/fakefox/extra/src/pkg_c" "$out"
    out="$(run_tool "$sb" "$sb" repo_pin pkg_a 2>/dev/null)"
    assert_eq "repo_pin: the version in core.repos, a branch on origin" $'fakefox\tbranch' "$out"
    out="$(run_tool "$sb" "$sb" repo_pin pkg_u 2>/dev/null)"
    assert_eq "repo_pin: a repo of the unnamed layer" $'main\tbranch' "$out"
    rc=0; out="$(run_tool "$sb" "$sb" worktree_repos --issue owner/pkg_a#9 --layer core --package-repos pkg_a,pkg_b 2>&1)" || rc=$?
    assert_eq "worktree_repos: exit 0" "0" "$rc"
    assert_eq "worktree_repos: the clones in <root>/fakefox/core/src, the worktree's own layout" \
        "$root/fakefox/core/src/pkg_a	core_ws/src/pkg_a	feature/issue-9
$root/fakefox/core/src/pkg_b	core_ws/src/pkg_b	feature/pkg_a-issue-9" "$out"
    rc=0; out="$(run_tool "$sb" "$sb" worktree_repos --issue owner/pkg_c#9 --layer core --package-repos pkg_c 2>&1)" || rc=$?
    assert_contains "worktree_repos: a repo of another layer is named" "package repo 'pkg_c' is in layer 'extra', not 'core'" "$out"
    wt="$root/worktrees/issue-toolsys-owner-pkg_c-9"
    mkdir -p "$wt/extra_ws/src"
    rc=0; out="$(run_tool "$sb" "$sb" worktree_env --worktree "$wt" 2>/dev/null)" || rc=$?
    assert_eq "worktree_env: exit 0" "0" "$rc"
    assert_eq "worktree_env: underlay, each lower layer, the root's same layer, the worktree's" \
        "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
source $sb/rosroot/fakefox/setup.bash
if [ -f $root/fakefox/install/local_setup.bash ]; then source $root/fakefox/install/local_setup.bash; fi
if [ -f $root/fakefox/core/install/local_setup.bash ]; then source $root/fakefox/core/install/local_setup.bash; fi
if [ -f $root/fakefox/extra/install/local_setup.bash ]; then source $root/fakefox/extra/install/local_setup.bash; fi
if [ -f $wt/extra_ws/install/local_setup.bash ]; then source $wt/extra_ws/install/local_setup.bash; fi" "$out"
    assert_eq "worktree_env: COLCON_IGNORE in <root>/worktrees" "true" "$([ -f "$root/worktrees/COLCON_IGNORE" ] && echo true || echo false)"
}

test_worktree_env_names_unbuilt_lower_layers() {
    echo "TEST: worktree_env names on stderr each lower layer with no install/, on every route; stdout unchanged"
    local sb proj root wt out err
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    wt="$sb/wt"
    mkdir -p "$wt/l3_ws/src"
    mkdir -p "$proj/layers/main/l1_ws/install"
    : > "$proj/layers/main/l1_ws/install/local_setup.bash"
    out="$(run_adapter "$sb" worktree_env --worktree "$wt" 2>"$sb/err")"
    err="$(cat "$sb/err")"
    assert_eq "bootstrap route: stdout as it was" \
        "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
source $sb/rosroot/fakefox/setup.bash
if [ -f $proj/layers/main/l1_ws/install/local_setup.bash ]; then source $proj/layers/main/l1_ws/install/local_setup.bash; fi
if [ -f $proj/layers/main/l2_ws/install/local_setup.bash ]; then source $proj/layers/main/l2_ws/install/local_setup.bash; fi
if [ -f $proj/layers/main/l3_ws/install/local_setup.bash ]; then source $proj/layers/main/l3_ws/install/local_setup.bash; fi
if [ -f $wt/l3_ws/install/local_setup.bash ]; then source $wt/l3_ws/install/local_setup.bash; fi" "$out"
    assert_eq "bootstrap route: the one unbuilt lower layer named, the built one not" \
        "NOTE: layer l2 is not built ($proj/layers/main/l2_ws/install/local_setup.bash missing); this worktree's build will not find its packages until it is" "$err"
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    wt="$root/worktrees/issue-toolsys-owner-pkg_c-2"
    mkdir -p "$wt/extra_ws/src" "$root/fakefox/install" "$root/fakefox/core/install"
    : > "$root/fakefox/install/local_setup.bash"
    run_tool "$sb" "$sb" worktree_env --worktree "$wt" >/dev/null 2>"$sb/err"
    assert_eq "tool route: core named (an install/ without local_setup.bash, which env.sh sources), the built unnamed layer not" \
        "NOTE: layer core is not built ($root/fakefox/core/install/local_setup.bash missing); this worktree's build will not find its packages until it is" "$(cat "$sb/err")"
}

test_tool_package_worktree() {
    echo "TEST: tool route: a package worktree made from a session at the root (outside git), its base the resolved pin"
    local sb root out rc=0 wt
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    assert_eq "precondition: the root is in no git repository" "outside" "$(tool_outside_git "$root")"
    out="$(cd "$root" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue owner/pkg_a#503 --type project --project toolsys \
        --layer core --package-repos pkg_a 2>&1)" || rc=$?
    wt="$root/worktrees/issue-toolsys-owner-pkg_a-503"
    assert_eq "exit 0" "0" "$rc"
    assert_contains "creation names the unnamed layer, not built yet" \
        "NOTE: layer _unnamed is not built ($root/fakefox/install/local_setup.bash missing)" "$out"
    assert_eq "the header records the resolved pin as base=" \
        "# project=toolsys issue=owner/pkg_a#503 layer=core base=fakefox" "$(head -n1 "$wt/.worktree-repos" 2>/dev/null)"
    assert_eq "on feature/issue-503" "feature/issue-503" "$(git -C "$wt/core_ws/src/pkg_a" branch --show-current 2>/dev/null)"
    assert_eq "the branch starts at origin's fakefox" \
        "$(git -C "$root/fakefox/core/src/pkg_a" rev-parse refs/remotes/origin/fakefox)" \
        "$(git -C "$wt/core_ws/src/pkg_a" rev-parse HEAD 2>/dev/null)"
    assert_eq "env.sh: the underlay, the unnamed layer, the root's core, the worktree's" \
        "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
source $sb/rosroot/fakefox/setup.bash
if [ -f $root/fakefox/install/local_setup.bash ]; then source $root/fakefox/install/local_setup.bash; fi
if [ -f $root/fakefox/core/install/local_setup.bash ]; then source $root/fakefox/core/install/local_setup.bash; fi
if [ -f $wt/core_ws/install/local_setup.bash ]; then source $wt/core_ws/install/local_setup.bash; fi" \
        "$(cat "$wt/env.sh" 2>/dev/null)"
    assert_eq "build.sh generated and executable" "true" "$([ -x "$wt/build.sh" ] && echo true || echo false)"
    assert_eq "COLCON_IGNORE in <root>/worktrees" "true" "$([ -f "$root/worktrees/COLCON_IGNORE" ] && echo true || echo false)"
    assert_eq "no worktree inside a distro's directory" "" "$(find "$root/fakefox" -name '*_ws' -print 2>/dev/null)"
}

test_tool_layers_read_once_per_call() {
    echo "TEST: tool route: layers.txt is read once per call; a sync's rename during the loop changes nothing, and an empty read is refused naming the tool's sync"
    local sb root out rc verb
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    # The underlay, sourced after the read and before the loop, moves the
    # resolved directory aside, as the tool's first rename would. (build
    # runs the tool's build, which reads the resolved files itself.)
    printf 'export SOURCED_LAYERS=base\nmv %q %q 2>/dev/null || true\n' \
        "$root/.repos-manifest/resolved/fakefox" "$root/.repos-manifest/resolved/.aside" > "$sb/rosroot/fakefox/setup.bash"
    : > "$sb/colcon.log"
    rc=0
    out="$(run_tool "$sb" "$root" test 2>&1)" || rc=$?
    assert_eq "test, resolve moved aside mid-run: exit 0" "0" "$rc"
    assert_eq "test, resolve moved aside mid-run: every layer of the one read, in order" \
        "$root/fakefox $root/fakefox/core $root/fakefox/extra" \
        "$(sed -n 's/^COLCON_RAN_IN:\([^ ]*\) .*/\1/p' "$sb/colcon.log" | tr '\n' ' ' | sed 's/ $//')"
    mv "$root/.repos-manifest/resolved/.aside" "$root/.repos-manifest/resolved/fakefox"
    printf 'export SOURCED_LAYERS=base\n' > "$sb/rosroot/fakefox/setup.bash"
    # A layers.txt that lists no layer (the head comment alone).
    printf '# Generated by repos-manifest resolve\n' > "$root/.repos-manifest/resolved/fakefox/layers.txt"
    for verb in build test env validate repos; do
        rc=0
        out="$(run_tool "$sb" "$root" "$verb" 2>&1)" || rc=$?
        assert_eq "empty layers.txt: $verb exits 1" "1" "$rc"
        assert_contains "empty layers.txt: $verb says the resolve cannot be used" \
            "last resolve for distro fakefox cannot be used" "$out"
        assert_contains "empty layers.txt: $verb names the tool's sync for it" \
            "cd $root && $sb/.venv/bin/repos-manifest sync --distro fakefox" "$out"
    done
}

# Must-fix 1 of the second round: from inside <root>/<x>/ the distro is x
# and only x; a resolve of x that cannot be used is refused, never
# answered from another distro.
test_tool_distro_rule_never_moves_on() {
    echo "TEST: tool route: from inside a distro whose resolve cannot be used, every verb refuses naming it and the tool's sync for it; none answers for another distro"
    local sb root out rc verb
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox fakefox2)"
    mv "$root/.repos-manifest/resolved/fakefox" "$root/.repos-manifest/resolved/.fakefox.old-4242-abcd1234"
    for verb in validate repos "repo_pin pkg_a" env build; do
        rc=0
        # shellcheck disable=SC2086
        out="$(run_tool "$sb" "$root/fakefox/core" $verb 2>&1)" || rc=$?
        assert_eq "from <root>/fakefox/core, its resolve aside: $verb exits 1" "1" "$rc"
        assert_contains "$verb names fakefox" "last resolve for distro fakefox cannot be used" "$out"
        assert_contains "$verb names the tool's sync for fakefox" \
            "cd $root && $sb/.venv/bin/repos-manifest sync --distro fakefox" "$out"
        assert_not_contains "$verb answers nothing for fakefox2" "fakefox2" "$out"
    done
    rm -f "$sb/tool.log"
    rc=0; out="$(run_tool "$sb" "$root/fakefox/core" sync 2>&1)" || rc=$?
    assert_eq "sync from there: the tool's exit 0" "0" "$rc"
    assert_eq "sync from there: the tool's sync for fakefox, in the root, without the resolve" \
        "TOOL_RAN_IN:$root ARGS:sync --distro fakefox EXIT:0" "$(cat "$sb/tool.log" 2>/dev/null)"
    # From the root: validate covers every directory under resolved/ and
    # fails, by name, on one with no usable layers.txt.
    mkdir -p "$root/.repos-manifest/resolved/fakefox"
    rc=0; out="$(run_tool "$sb" "$root" validate 2>&1)" || rc=$?
    assert_eq "from the root, resolved/fakefox/ with no layers.txt: validate exit 1" "1" "$rc"
    assert_contains "it is named, with the tool's sync for it" \
        "cd $root && $sb/.venv/bin/repos-manifest sync --distro fakefox" "$out"
    assert_contains "the failing distro named" "(failing distro: fakefox)" "$out"
    assert_contains "fakefox2 still checked and passed" "for distro fakefox2 (" "$out"
    rm -r "$root/.repos-manifest/resolved/fakefox"
    mv "$root/.repos-manifest/resolved/.fakefox.old-4242-abcd1234" "$root/.repos-manifest/resolved/fakefox"
    # From <root>/worktrees/<anything>/ with one distro: that one.
    rm -r "$root/.repos-manifest/resolved/fakefox2"
    mkdir -p "$root/worktrees/anything"
    rc=0; out="$(run_tool "$sb" "$root/worktrees/anything" validate 2>&1)" || rc=$?
    assert_eq "from <root>/worktrees/anything, one distro: validate exit 0" "0" "$rc"
    assert_contains "from <root>/worktrees/anything: the one distro chosen" "for distro fakefox (" "$out"
}

# Round 3, suggestion 1: a resolve the tool has set aside while replacing
# it (.<d>.old-<pid>-<random> or .<d>.new-..., the names output.py's
# _TEMP_NAME gives) counts as distro d, with no usable resolve.
test_tool_set_aside_resolve_is_a_distro() {
    echo "TEST: tool route: a resolve set aside by the tool counts as its distro; nothing answers past it"
    local sb root out rc aside kind
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox fakefox2)"
    for kind in old new; do
        aside="$root/.repos-manifest/resolved/.fakefox.$kind-4242-ab_c1234"
        mv "$root/.repos-manifest/resolved/fakefox" "$aside"
        rc=0; out="$(run_tool "$sb" "$root" env 2>&1)" || rc=$?
        assert_eq "$kind: from the root, fakefox aside: env refused" "1" "$rc"
        assert_contains "$kind: the refusal lists both distros" "several distros (fakefox, fakefox2)" "$out"
        assert_not_contains "$kind: nothing answered for fakefox2" "rosroot/fakefox2" "$out"
        rc=0; out="$(run_tool "$sb" "$root" validate 2>&1)" || rc=$?
        assert_eq "$kind: from the root, fakefox aside: validate exit 1" "1" "$rc"
        assert_contains "$kind: validate names the failing distro" "(failing distro: fakefox)" "$out"
        assert_contains "$kind: with the tool's sync for it" \
            "cd $root && $sb/.venv/bin/repos-manifest sync --distro fakefox" "$out"
        mv "$aside" "$root/.repos-manifest/resolved/fakefox"
    done
    # One distro, set aside, and no other: refused, naming it.
    rm -r "$root/.repos-manifest/resolved/fakefox2"
    mv "$root/.repos-manifest/resolved/fakefox" "$root/.repos-manifest/resolved/.fakefox.old-4242-abcd1234"
    rc=0; out="$(run_tool "$sb" "$root" env 2>&1)" || rc=$?
    assert_eq "one distro aside: from the root, env refused" "1" "$rc"
    assert_contains "one distro aside: named, unusable" "last resolve for distro fakefox cannot be used" "$out"
    assert_contains "one distro aside: the tool's sync for it" \
        "cd $root && $sb/.venv/bin/repos-manifest sync --distro fakefox" "$out"
    # A dot name that is not the tool's is still left out.
    mv "$root/.repos-manifest/resolved/.fakefox.old-4242-abcd1234" "$root/.repos-manifest/resolved/fakefox"
    mkdir -p "$root/.repos-manifest/resolved/.fakefox2.old-x"
    rc=0; out="$(run_tool "$sb" "$root" validate 2>&1)" || rc=$?
    assert_eq "a dot name not the tool's: left out, validate exit 0" "0" "$rc"
    assert_not_contains "a dot name not the tool's: fakefox2 not counted" "fakefox2" "$out"
}

# Integrated review, finding 4: a distro whose plain and set-aside
# directories both exist is listed once, by _rc_tool_distros itself and
# in the refusal that lists the distros. (Listed when only the set-aside
# one exists: test_tool_set_aside_resolve_is_a_distro and
# test_tool_distros_counts_each_name_globbed.)
test_tool_distro_listed_once_beside_its_set_aside() {
    echo "TEST: tool route: a distro with both its resolve and a set-aside one is listed once"
    local sb root out rc res kind
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox fakefox2)"
    res="$root/.repos-manifest/resolved"
    for kind in old new; do
        cp -a "$res/fakefox" "$res/.fakefox.$kind-4242-abcd1234"
        out="$(tool_distros "$sb" "$root")"
        assert_eq "$kind beside fakefox, two distros: _rc_tool_distros lists each once" \
            "$(printf 'fakefox\nfakefox2')" "$out"
        rc=0; out="$(run_tool "$sb" "$root" env 2>&1)" || rc=$?
        assert_eq "$kind beside fakefox, two distros: from the root, env refused" "1" "$rc"
        assert_contains "$kind beside fakefox: the refusal lists each once" "several distros (fakefox, fakefox2)" "$out"
        rm -r "$res/.fakefox.$kind-4242-abcd1234"
    done
    rm -r "$res/fakefox2"
    cp -a "$res/fakefox" "$res/.fakefox.new-4242-abcd1234"
    out="$(tool_distros "$sb" "$root")"
    assert_eq "fakefox and its set-aside copy, no other: _rc_tool_distros lists fakefox once" "fakefox" "$out"
    rc=0; out="$(run_tool "$sb" "$root" validate 2>&1)" || rc=$?
    assert_eq "fakefox and its set-aside copy, no other: from the root, validate exit 0" "0" "$rc"
    assert_contains "fakefox and its set-aside copy, no other: fakefox chosen" "for distro fakefox (" "$out"
}

# _rc_tool_distros run on its own: <root> as the project root, its
# distros one per line.
tool_distros() {  # <sb> <root>
    ACTIVE_PROJECT_ROOT="$2" bash -c 'set -euo pipefail; source "$1/.agent/project_types/ros2_colcon/adapter.sh"; _rc_tool_distros' _ "$1"
}

# Round 2 on the pull request, suggestion 1: every name a glob of
# _rc_tool_distros returned counts, even if it is gone when examined (the
# tool's second rename moves a set-aside name away during the call); an
# unmatched pattern gives no name. The disappearance is staged by
# removing a set-aside directory the moment the function tests it with
# [ (a name gone between the glob and its use cannot be timed in a test).
test_tool_distros_counts_each_name_globbed() {
    echo "TEST: tool route: _rc_tool_distros counts each name its globs returned; an unmatched pattern is no distro"
    local sb root res out
    sb="$(make_sandbox)"
    root="$(mktemp -d -p "$SANDBOX")/toolsys"
    res="$root/.repos-manifest/resolved"
    mkdir -p "$res/.fakefox.old-4242-abcd1234"
    out="$(tool_distros "$sb" "$root")"
    assert_eq "only a set-aside directory: its distro listed" "fakefox" "$out"
    out="$(ACTIVE_PROJECT_ROOT="$root" bash -c 'set -euo pipefail
        [() { if [[ "$1" == -d && "$2" == */.fakefox.old-* ]]; then rm -rf "$2"; fi; builtin [ "$@"; }
        source "$1/.agent/project_types/ros2_colcon/adapter.sh"; _rc_tool_distros' _ "$sb")"
    assert_eq "a set-aside directory gone once globbed: its distro still listed" "fakefox" "$out"
    rm -rf "$res"/.fakefox.*
    out="$(tool_distros "$sb" "$root")"
    assert_eq "nothing under resolved/: no distro and no literal pattern" "" "$out"
    rmdir "$res"
    out="$(tool_distros "$sb" "$root")"
    assert_eq "no resolved/: no distro and no literal pattern" "" "$out"
}

# Round 3, suggestion 2: from a top-level directory the tool has no
# resolve for, the message says so; a link to a distro's directory is
# that distro (the calling directory is physical).
test_tool_not_a_distro_directory() {
    echo "TEST: tool route: from a top-level directory that is not a resolved distro, a true message; a link to a distro is that distro"
    local sb root out rc
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox fakefox2)"
    mkdir -p "$root/notes"
    rc=0; out="$(run_tool "$sb" "$root/notes" env 2>&1)" || rc=$?
    assert_eq "from <root>/notes: refused" "1" "$rc"
    assert_contains "from <root>/notes: not a resolved distro" \
        "notes is not a distro the manifest tool has resolved in $root" "$out"
    assert_contains "from <root>/notes: where to run from" \
        "Run the command from $root or from inside a distro's directory ($root/fakefox, $root/fakefox2)" "$out"
    assert_contains "from <root>/notes: the sync for a distro being added" \
        "if notes is a distro being added, run: cd $root && $sb/.venv/bin/repos-manifest sync --distro notes" "$out"
    assert_not_contains "from <root>/notes: no sync cut short" "cut short" "$out"
    rc=0; out="$(run_tool "$sb" "$root/notes" validate 2>&1)" || rc=$?
    assert_eq "from <root>/notes: validate refused" "1" "$rc"
    assert_contains "from <root>/notes: validate, the same message" "notes is not a distro" "$out"
    # A link that sorts before the distro it points to.
    ln -s fakefox2 "$root/current"
    rc=0; out="$(run_tool "$sb" "$root/current" validate 2>&1)" || rc=$?
    assert_eq "from <root>/current -> fakefox2: validate exit 0" "0" "$rc"
    assert_contains "from <root>/current: fakefox2 chosen" "for distro fakefox2 (" "$out"
    rc=0; out="$(run_tool "$sb" "$root/fakefox2/core" env 2>&1)" || rc=$?
    assert_eq "from <root>/fakefox2/core beside the link: env exit 0" "0" "$rc"
    assert_contains "from <root>/fakefox2/core: fakefox2's underlay" "rosroot/fakefox2/setup.bash" "$out"
}

# Round 4: step 1 takes only real directories directly under the physical
# root; a link there is never a candidate, so a call through a link is for
# the directory it points to, whatever is under resolved/.
test_tool_links_are_not_candidates() {
    echo "TEST: tool route: a link under the root is never the distro; a call through it is for its target"
    local sb root out rc res d
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox fakefox2)"
    res="$root/.repos-manifest/resolved"
    ln -s fakefox2 "$root/current"
    for d in current fakefox2; do
        rc=0; out="$(run_tool "$sb" "$root/$d" env 2>&1)" || rc=$?
        assert_eq "resolved, from <root>/$d: env exit 0" "0" "$rc"
        assert_contains "resolved, from <root>/$d: fakefox2's underlay" "rosroot/fakefox2/setup.bash" "$out"
    done
    cp -a "$res/fakefox2" "$sb/fakefox2.resolved"
    mv "$res/fakefox2" "$res/.fakefox2.old-4242-abcd1234"
    for d in current fakefox2; do
        rc=0; out="$(run_tool "$sb" "$root/$d" env 2>&1)" || rc=$?
        assert_eq "set aside, from <root>/$d: env refused" "1" "$rc"
        assert_contains "set aside, from <root>/$d: fakefox2 named" "last resolve for distro fakefox2 cannot be used" "$out"
        assert_not_contains "set aside, from <root>/$d: never the link's name" "current" "$out"
    done
    rm -r "$res/.fakefox2.old-4242-abcd1234"
    for d in current fakefox2; do
        rc=0; out="$(run_tool "$sb" "$root/$d" env 2>&1)" || rc=$?
        assert_eq "gone, from <root>/$d: env refused" "1" "$rc"
        assert_contains "gone, from <root>/$d: fakefox2 named" "fakefox2 is not a distro the manifest tool has resolved" "$out"
        assert_not_contains "gone, from <root>/$d: never the link's name" "current" "$out"
    done
    mv "$sb/fakefox2.resolved" "$res/fakefox2"
    # A link whose own name has a directory under resolved/.
    rm "$root/current"
    ln -s fakefox2 "$root/abc_x"
    cp -a "$res/fakefox" "$res/abc_x"
    for d in fakefox2 abc_x; do
        rc=0; out="$(run_tool "$sb" "$root/$d" env 2>&1)" || rc=$?
        assert_eq "abc_x -> fakefox2 resolved too, from <root>/$d: env exit 0" "0" "$rc"
        assert_contains "abc_x -> fakefox2, from <root>/$d: fakefox2's underlay" "rosroot/fakefox2/setup.bash" "$out"
        assert_not_contains "abc_x -> fakefox2, from <root>/$d: not for abc_x" "rosroot/abc_x" "$out"
    done
}

# Must-fix 2 of the second round: every next step on the tool route that
# is the tool's sync is a command that works when run literally, from
# anywhere, in the situation the message arises in.
test_tool_sync_steps_run_literally() {
    echo "TEST: tool route: each printed sync step, run literally from elsewhere, runs the tool's sync in the root for the right distro"
    local sb root out rc step
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox fakefox2)"
    # validate from the workspace, a clone missing in fakefox2.
    mv "$root/fakefox2/extra/src/pkg_c" "$(dirname "$root")/pkg_c.aside"
    rc=0; out="$(run_tool "$sb" "$sb" validate 2>&1)" || rc=$?
    assert_eq "not checked out: validate exit 1" "1" "$rc"
    assert_not_contains "not checked out: no adapter verb named" "--project toolsys sync" "$out"
    step="$(tool_step_of "$(grep " missing: " <<< "$out")")"
    rm -f "$sb/tool.log"
    (cd / && bash -c "$step") >/dev/null 2>&1
    assert_eq "not checked out: the step runs the tool's sync for fakefox2 in the root" \
        "TOOL_RAN_IN:$root ARGS:sync --distro fakefox2 EXIT:0" "$(cat "$sb/tool.log" 2>/dev/null)"
    mv "$(dirname "$root")/pkg_c.aside" "$root/fakefox2/extra/src/pkg_c"
    # validate from the root, a layer's .repos file missing in fakefox.
    mv "$root/.repos-manifest/resolved/fakefox/extra.repos" "$(dirname "$root")/extra.repos.aside"
    rc=0; out="$(run_tool "$sb" "$root" validate 2>&1)" || rc=$?
    step="$(tool_step_of "$(grep "missing" <<< "$out")")"
    rm -f "$sb/tool.log"
    (cd / && bash -c "$step") >/dev/null 2>&1
    assert_eq "missing .repos: the step runs the tool's sync for fakefox in the root" \
        "TOOL_RAN_IN:$root ARGS:sync --distro fakefox EXIT:0" "$(cat "$sb/tool.log" 2>/dev/null)"
    mv "$(dirname "$root")/extra.repos.aside" "$root/.repos-manifest/resolved/fakefox/extra.repos"
    # A key the reader does not read, from inside fakefox2.
    printf '  grp/pkg_n:\n    type: git\n    url: git@github.com:owner/pkg_n.git\n    version: main\n' \
        >> "$root/.repos-manifest/resolved/fakefox2/core.repos"
    rc=0; out="$(run_tool "$sb" "$root/fakefox2" repos 2>&1)" || rc=$?
    assert_eq "unread key: refused" "1" "$rc"
    assert_not_contains "unread key: no adapter verb named" "--project toolsys sync" "$out"
    step="$(tool_step_of "$out")"
    rm -f "$sb/tool.log"
    (cd / && bash -c "$step") >/dev/null 2>&1
    assert_eq "unread key: the step runs the tool's sync for fakefox2 in the root" \
        "TOOL_RAN_IN:$root ARGS:sync --distro fakefox2 EXIT:0" "$(cat "$sb/tool.log" 2>/dev/null)"
}

# Suggestion 1 of the second round: keys the tool writes in single quotes.
test_tool_quoted_keys_from_the_tool() {
    echo "TEST: tool route: keys the tool itself writes in single quotes ('123', 'on', '1.5') are read, unquoted"
    local sb root outer out out2 rc key
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox)"
    outer="$(dirname "$root")"
    cat >> "$outer/m.manifest.yaml" <<'EOF'
  '123':
    type: git
    url: git@github.com:owner/pkg_c.git
    version: main
    layer: extra
  'on':
    type: git
    url: git@github.com:owner/pkg_c.git
    version: main
    layer: extra
  '1.5':
    type: git
    url: git@github.com:owner/pkg_c.git
    version: main
    layer: extra
EOF
    rm -r "$root/.repos-manifest/resolved/fakefox"
    (cd "$outer" && PYTHONPATH="$MR_SRC" "$MR_PY" -m repos_manifest.cli resolve \
        --manifest m.manifest.yaml --distro fakefox --out "$root/.repos-manifest/resolved/fakefox" >/dev/null)
    assert_contains "precondition: the tool wrote the keys quoted" "  '123':" "$(cat "$root/.repos-manifest/resolved/fakefox/extra.repos")"
    for key in 123 on 1.5; do
        git clone --quiet --branch main "$outer/fake_remotes/github.com/owner/pkg_c.git" "$root/fakefox/extra/src/$key"
        git -C "$root/fakefox/extra/src/$key" remote set-url origin "git@github.com:owner/pkg_c.git"
        git -C "$root/fakefox/extra/src/$key" fetch --quiet origin
    done
    rc=0; out="$(run_tool "$sb" "$root" validate 2>&1)" || rc=$?
    assert_eq "validate: exit 0" "0" "$rc"
    rc=0; out="$(run_tool "$sb" "$root" repos 2>&1)" || rc=$?
    assert_eq "repos: exit 0" "0" "$rc"
    for key in 123 on 1.5; do
        assert_contains "repos lists $key unquoted" "$key:$root/fakefox/extra/src/$key" "$out"
        out2="$(run_tool "$sb" "$root" repo_pin "$key" 2>/dev/null)" || true
        assert_eq "repo_pin $key: its version" $'main\tbranch' "$out2"
    done
    rm -r "$root/fakefox/extra/src/on"
    rc=0; out="$(run_tool "$sb" "$root" validate 2>&1)" || rc=$?
    assert_eq "a quoted key's clone missing: validate exit 1" "1" "$rc"
    assert_contains "it is named unquoted" "$root/fakefox/extra/src/on missing:" "$out"
}

# A package worktree on a root with two distros: from inside <root>/<d>/
# every adapter call reads d; from the root it is refused before anything
# is made, listing the distros.
test_tool_package_worktree_two_distros() {
    echo "TEST: tool route, two distros: a package worktree from inside <root>/<d>/ reads d throughout; from the root it is refused"
    local sb root out rc=0 wt
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    root="$(make_tool_root "$sb" fakefox fakefox2)"
    wt="$root/worktrees/issue-toolsys-owner-pkg_a-504"
    out="$(cd "$root" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue owner/pkg_a#504 --type project --project toolsys \
        --layer core --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "from the root: exit 1" "1" "$rc"
    assert_contains "from the root: the distros listed" "several distros (fakefox, fakefox2)" "$out"
    assert_eq "from the root: nothing made" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "from the root: no branch made" "" \
        "$(git -C "$root/fakefox/core/src/pkg_a" branch --list feature/issue-504; git -C "$root/fakefox2/core/src/pkg_a" branch --list feature/issue-504)"
    rc=0
    out="$(cd "$root/fakefox" && export ROS_ROOT_DIR="$sb/rosroot" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue owner/pkg_a#504 --type project --project toolsys \
        --layer core --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "from inside <root>/fakefox: exit 0" "0" "$rc"
    assert_eq "base= is fakefox's pin" \
        "# project=toolsys issue=owner/pkg_a#504 layer=core base=fakefox" "$(head -n1 "$wt/.worktree-repos" 2>/dev/null)"
    assert_eq "the branch starts at origin's fakefox" \
        "$(git -C "$root/fakefox/core/src/pkg_a" rev-parse refs/remotes/origin/fakefox)" \
        "$(git -C "$wt/core_ws/src/pkg_a" rev-parse HEAD 2>/dev/null)"
    assert_eq "env.sh: fakefox's underlay, then layers under <root>/fakefox/ only, then the worktree's" \
        "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
source $sb/rosroot/fakefox/setup.bash
if [ -f $root/fakefox/install/local_setup.bash ]; then source $root/fakefox/install/local_setup.bash; fi
if [ -f $root/fakefox/core/install/local_setup.bash ]; then source $root/fakefox/core/install/local_setup.bash; fi
if [ -f $wt/core_ws/install/local_setup.bash ]; then source $wt/core_ws/install/local_setup.bash; fi" \
        "$(cat "$wt/env.sh" 2>/dev/null)"
    assert_not_contains "env.sh names nothing of fakefox2" "fakefox2" "$(cat "$wt/env.sh" 2>/dev/null)"
}

test_bootstrap_no_url_names_the_tool() {
    echo "TEST: bootstrap route: the no-URL error also names setting the root up with the manifest tool (issue 503)"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_fresh_project "$sb" >/dev/null
    out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names init --distro-dirs" "init <manifest> --distro-dirs --distro <distro>" "$out"
    assert_not_contains "does not advise source=" "source=" "$out"
}

# The real tool (this checkout's source) and vcs: init a system from local
# repositories, then setup, sync, validate and repo_pin through the
# adapter. Skipped, saying so, when either is missing. A missing vcs is a
# failure, not a skip, when ROS2_COLCON_TESTS_REQUIRE_VCS is set and
# non-empty: the "Run ros2_colcon adapter tests" step of CI's Validate
# Adapter Contract job sets it, as that job installs vcs.
test_tool_real_init_and_sync() {
    echo "TEST: tool route with the real tool and vcs: init by hand, then the adapter's sync, validate and repo_pin"
    local vcs_bin sb outer root out rc=0 name
    vcs_bin="$(command -v vcs 2>/dev/null || true)"
    if [ -z "$vcs_bin" ] && [ -n "${ROS2_COLCON_TESTS_REQUIRE_VCS:-}" ]; then
        echo "  FAIL: vcs is not on PATH, though ROS2_COLCON_TESTS_REQUIRE_VCS says it is meant to be present"
        FAIL=$((FAIL + 1))
        return 0
    fi
    if [ -z "$vcs_bin" ]; then
        echo "  SKIPPED: vcs is not on PATH; the real tool's sync needs it"
        TOOL_SKIPPED=$((TOOL_SKIPPED + 1))
        return 0
    fi
    sb="$(make_sandbox)"
    outer="$(mktemp -d -p "$SANDBOX")"
    root="$outer/toolsys"
    for name in pkg_u pkg_a; do
        mkdir -p "$outer/remotes/$name"
        git -C "$outer/remotes/$name" init --quiet -b main
        echo "$name" > "$outer/remotes/$name/README"
        git -C "$outer/remotes/$name" add README
        git -C "$outer/remotes/$name" -c user.name=t -c user.email=t@t commit --quiet -m first
        git -C "$outer/remotes/$name" branch fakefox
    done
    cat > "$outer/m.manifest.yaml" <<EOF
format: 1
distros: [fakefox]
layers: [core]
repositories:
  pkg_u:
    type: git
    url: file://$outer/remotes/pkg_u
    version: main
  pkg_a:
    type: git
    url: file://$outer/remotes/pkg_a
    version: fakefox
    layer: core
EOF
    mkdir -p "$sb/.venv/bin" "$root"
    printf '#!/usr/bin/env bash\nPYTHONPATH=%q exec %q -m repos_manifest.cli "$@"\n' "$MR_SRC" "$MR_PY" > "$sb/.venv/bin/repos-manifest"
    chmod +x "$sb/.venv/bin/repos-manifest"
    ln -s "$MR_PY" "$sb/.venv/bin/python3"
    out="$(cd "$root" && "$sb/.venv/bin/repos-manifest" init ../m.manifest.yaml --distro-dirs --distro fakefox --yes 2>&1)" || rc=$?
    assert_eq "init: exit 0" "0" "$rc"
    echo "toolsys ros2_colcon $root" >> "$sb/.agent/projects.local"
    make_underlay "$sb" fakefox
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$sb/.agent/scripts/adapter" --project toolsys sync 2>&1)" || rc=$?
    assert_eq "adapter sync: the tool's exit 0" "0" "$rc"
    assert_contains "adapter sync: the tool's own report" "up to date (2)" "$out"
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$sb/.agent/scripts/adapter" --project toolsys validate 2>&1)" || rc=$?
    assert_eq "adapter validate: exit 0" "0" "$rc"
    assert_contains "adapter validate: read by the real status for fakefox" "read against the manifest for distro fakefox (repos-manifest status: 2 repo(s), 2 as expected" "$out"
    out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$sb/.agent/scripts/adapter" --project toolsys repo_pin pkg_a 2>/dev/null)"
    assert_eq "adapter repo_pin: the resolved version, a branch" $'fakefox\tbranch' "$out"
    rm -rf "$root/fakefox/core/src/pkg_a"
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$sb/.agent/scripts/adapter" --project toolsys setup 2>&1)" || rc=$?
    assert_eq "adapter setup: exit 0" "0" "$rc"
    assert_contains "adapter setup: the tool cloned the missing repo" "cloned (1): fakefox/core/src/pkg_a" "$out"
    assert_eq "the clone is back, on its pin" "fakefox" "$(git -C "$root/fakefox/core/src/pkg_a" branch --show-current 2>/dev/null)"
}

# The real tool's status and build through the adapter: init and sync a
# system from local repositories, then validate (read by the real status)
# and build (the real build, with a stub colcon first on PATH: CI's
# adapter-contract job has no colcon). The same vcs rule as
# test_tool_real_init_and_sync: skipped, counted, without vcs; a failure
# when ROS2_COLCON_TESTS_REQUIRE_VCS is set.
test_tool_real_status_and_build() {
    echo "TEST: tool route with the real tool and vcs: validate reads the real status, build runs the real build"
    local vcs_bin sb outer root out rc=0 name adapter
    vcs_bin="$(command -v vcs 2>/dev/null || true)"
    if [ -z "$vcs_bin" ] && [ -n "${ROS2_COLCON_TESTS_REQUIRE_VCS:-}" ]; then
        echo "  FAIL: vcs is not on PATH, though ROS2_COLCON_TESTS_REQUIRE_VCS says it is meant to be present"
        FAIL=$((FAIL + 1))
        return 0
    fi
    if [ -z "$vcs_bin" ]; then
        echo "  SKIPPED: vcs is not on PATH; the real tool's sync needs it"
        TOOL_SKIPPED=$((TOOL_SKIPPED + 1))
        return 0
    fi
    sb="$(make_sandbox)"
    outer="$(mktemp -d -p "$SANDBOX")"
    root="$outer/toolsys"
    adapter="$sb/.agent/scripts/adapter"
    for name in pkg_u pkg_a; do
        mkdir -p "$outer/remotes/$name"
        git -C "$outer/remotes/$name" init --quiet -b main
        echo "$name" > "$outer/remotes/$name/README"
        git -C "$outer/remotes/$name" add README
        git -C "$outer/remotes/$name" -c user.name=t -c user.email=t@t commit --quiet -m first
        git -C "$outer/remotes/$name" branch fakefox
    done
    cat > "$outer/m.manifest.yaml" <<EOF
format: 1
distros: [fakefox]
layers: [core]
repositories:
  pkg_u:
    type: git
    url: file://$outer/remotes/pkg_u
    version: main
  pkg_a:
    type: git
    url: file://$outer/remotes/pkg_a
    version: fakefox
    layer: core
EOF
    mkdir -p "$sb/.venv/bin" "$sb/stubbin" "$root"
    printf '#!/usr/bin/env bash\nPYTHONPATH=%q exec %q -m repos_manifest.cli "$@"\n' "$MR_SRC" "$MR_PY" > "$sb/.venv/bin/repos-manifest"
    chmod +x "$sb/.venv/bin/repos-manifest"
    ln -s "$MR_PY" "$sb/.venv/bin/python3"
    # A stub colcon: records where it ran and its arguments, and writes the
    # setup files a build leaves.
    cat > "$sb/stubbin/colcon" <<EOF
#!/usr/bin/env bash
echo "\$(pwd -P) \$*" >> "$sb/colcon.log"
mkdir -p install
echo '# stub' > install/setup.bash
echo '# stub' > install/local_setup.bash
exit 0
EOF
    chmod +x "$sb/stubbin/colcon"
    out="$(cd "$root" && "$sb/.venv/bin/repos-manifest" init ../m.manifest.yaml --distro-dirs --distro fakefox --yes 2>&1)" || rc=$?
    assert_eq "init: exit 0" "0" "$rc"
    echo "toolsys ros2_colcon $root" >> "$sb/.agent/projects.local"
    make_underlay "$sb" fakefox
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$adapter" --project toolsys validate 2>&1)" || rc=$?
    assert_eq "validate: exit 0" "0" "$rc"
    assert_contains "validate: the pass line, from the real status" \
        "for distro fakefox (repos-manifest status: 2 repo(s), 2 as expected, 0 with a warning above, 0 optional and skipped; clones read" "$out"
    assert_not_contains "validate: no warning from the real status on a fresh init" "⚠️" "$out"
    assert_not_contains "validate: no note from the real status on a fresh init" "NOTE:" "$out"
    # An emptied clone (issue 517, item 2): unusable, named.
    find "$root/fakefox/src/pkg_u" -mindepth 1 -delete
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$adapter" --project toolsys validate 2>&1)" || rc=$?
    assert_eq "an emptied clone: validate exit 1" "1" "$rc"
    assert_contains "an emptied clone: unusable, named" "❌ distro fakefox: $root/fakefox/src/pkg_u unusable:" "$out"
    # Removed, then cloned again by the adapter's sync: validate passes.
    rm -rf "$root/fakefox/src/pkg_u"
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$adapter" --project toolsys validate 2>&1)" || rc=$?
    assert_eq "a clone removed: validate exit 1" "1" "$rc"
    assert_contains "a clone removed: missing, with the tool's sync" \
        "❌ distro fakefox: $root/fakefox/src/pkg_u missing:" "$out"
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$adapter" --project toolsys sync 2>&1)" || rc=$?
    assert_eq "sync: exit 0" "0" "$rc"
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$adapter" --project toolsys validate 2>&1)" || rc=$?
    assert_eq "after sync: validate exit 0" "0" "$rc"
    assert_not_contains "after sync: no warning from the real status" "⚠️" "$out"
    # On another branch, and with a local change: warned and noted, exit 0.
    git -C "$root/fakefox/core/src/pkg_a" checkout --quiet -b other
    echo changed >> "$root/fakefox/src/pkg_u/README"
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$adapter" --project toolsys validate 2>&1)" || rc=$?
    assert_eq "another branch, a local change: validate exit 0" "0" "$rc"
    assert_contains "another branch: a warning" "⚠️ distro fakefox: $root/fakefox/core/src/pkg_a different:" "$out"
    assert_contains "a local change: a note" "NOTE: distro fakefox: $root/fakefox/src/pkg_u has local work (1 changed file(s), 0 commit(s) not on origin)" "$out"
    git -C "$root/fakefox/core/src/pkg_a" checkout --quiet fakefox
    git -C "$root/fakefox/src/pkg_u" checkout --quiet -- README
    # The real tool's two selection refusals, before anything is built:
    # each brings the adapter's note; nothing runs colcon.
    for arg in "--packages-select pkg_a" "--packages-up-to pkg_a"; do
        rc=0
        # shellcheck disable=SC2086
        out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" PATH="$sb/stubbin:$PATH" "$adapter" --project toolsys build $arg 2>&1)" || rc=$?
        assert_eq "build $arg, nothing built: the tool's refusal, exit 1" "1" "$rc"
        assert_contains "build $arg, nothing built: the tool's own message" "nothing was run" "$out"
        assert_contains "build $arg, nothing built: the adapter's note" \
            "NOTE: with package selection the manifest tool builds only layers built before" "$out"
    done
    assert_eq "the refused selections ran no colcon" "false" "$([ -e "$sb/colcon.log" ] && echo true || echo false)"
    # build: the real tool's build, the stub colcon in each layer.
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" PATH="$sb/stubbin:$PATH" "$adapter" --project toolsys build 2>&1)" || rc=$?
    assert_eq "build: exit 0" "0" "$rc"
    assert_eq "build: colcon in the unnamed layer, then core, with the adapter's flags and the tool's base paths" \
        "$root/fakefox build --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON --base-paths src/pkg_u
$root/fakefox/core build --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON --base-paths src/pkg_a" \
        "$(cat "$sb/colcon.log" 2>/dev/null)"
    assert_contains "build: the distro's setup.bash sources the last layer built" \
        "$root/fakefox/core/install/setup.bash" "$(cat "$root/fakefox/setup.bash" 2>/dev/null)"
    rc=0; out="$(cd "$root" && ROS_ROOT_DIR="$sb/rosroot" "$adapter" --project toolsys env 2>&1)" || rc=$?
    assert_eq "env after the tool's build: each layer's local_setup.bash" \
        "unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX
source $sb/rosroot/fakefox/setup.bash
source $root/fakefox/install/local_setup.bash
source $root/fakefox/core/install/local_setup.bash" "$out"
}

# ---- Run all tests ----
echo "=== ros2_colcon adapter tests ==="
echo ""

test_validator_accepts_ros2_colcon
test_worktree_create_package_success
test_worktree_create_package_base_from_pin_or_refused
test_worktree_create_package_existing_branch_needs_named_base
test_worktree_create_package_parent_issue_starts_from_parent
test_worktree_create_package_refuses_branch_and_empty_base
test_worktree_create_package_hook_preflight_checks_package_repos
test_worktree_create_rolls_back_on_second_repo_failure
test_worktree_create_lookup_unknown_first_repo
test_worktree_create_lookup_unknown_second_repo
test_worktree_create_lookup_found_branch_fails_checkout
test_worktree_create_rollback_on_worktree_env_failure
test_worktree_remove_multi_package_dirty_refuses_all
test_worktree_list_json_reports_package_worktree
test_worktree_enter_disambiguates_by_qualified_issue
test_worktree_create_issue_lookup_uses_qualified_repo
test_distro_from_bootstrap_yaml
test_distro_from_project_config
test_distro_from_registry
test_distro_unresolvable_fails
test_missing_underlay_fails
test_missing_manifest_fails
test_empty_layers_fails
test_traversal_layer_name_fails
test_broken_config_fails
test_env_chain_order
test_setup_imports_each_layer
test_setup_optional_layer_failure_tolerated
test_setup_required_layer_failure_aborts
test_setup_requires_vcs
test_real_tool_case_without_vcs
test_setup_bootstraps_manifest_pattern_b
test_setup_bootstraps_pattern_a_from_url_file
test_setup_bootstrap_env_url_wins
test_setup_bootstrap_shared_url_is_reported
test_setup_fresh_dir_without_url_fails
test_setup_bootstrap_rejects_unsafe_fields
test_setup_bootstrap_missing_fields_fails
test_setup_bootstrap_config_path_dotdot_component_only
test_setup_bootstrap_reuse_requires_matching_origin
test_setup_bootstrap_reuse_warns_on_branch_mismatch
test_setup_existing_manifest_skips_bootstrap
test_build_layer_order_and_cascade
test_build_skips_layer_without_src
test_build_stops_on_failure
test_test_continues_past_failures
test_repos_lists_packages_across_layers
test_repos_unconfigured_fails
test_scope_for_pr_nested_package
test_worktree_repos_requires_qualified_issue
test_worktree_repos_requires_layer_and_packages
test_worktree_repos_owning_and_sibling_branches
test_worktree_repos_unknown_package_fails
test_worktree_repos_wrong_layer_fails
test_worktree_env_for_package_worktree
test_worktree_env_last_line_never_fails_under_set_e
test_worktree_env_runtime_guard_picks_up_install_built_after_generation
test_worktree_env_no_layer_ws_fails
test_sync_pull_skip_fetch
test_validate_passes_matching_checkout
test_validate_flags_missing_repo
test_validate_flags_unsetup_layer
test_install_noop_by_default
test_cwd_discovery_resolves_colcon_project
test_repo_pin_kinds_online
test_repo_pin_branch_before_tag
test_repo_pin_strips_quotes
test_repo_pin_reads_version_as_yaml
test_repos_entries_parser_table
test_repo_pin_refuses_yaml_typed_plain_pins
test_sync_reads_quoted_and_commented_pins
test_repo_pin_deleted_upstream_branch_is_not_a_branch
test_repo_pin_offline_uses_local_refs
test_repo_pin_hanging_origin_is_bounded
test_repo_pin_not_cloned
test_repo_pin_not_found
test_repo_pin_entry_without_version
test_repo_pin_two_layers
test_worktree_create_package_root_outside_git
test_worktree_create_package_root_outside_git_repo_not_git_refused
mr_test test_tool_route_order
test_source_without_tool_root_refused
mr_test test_tool_unusable_root_is_an_error_never_a_fetch
mr_test test_tool_nested_key_refused_by_name
mr_test test_tool_distro_rule
mr_test test_tool_setup_and_sync_run_the_tool
mr_test test_tool_build_runs_the_tool
mr_test test_tool_test_over_the_resolved_layers
mr_test test_tool_validate
mr_test test_tool_repos_pin_and_worktree_verbs
mr_test test_worktree_env_names_unbuilt_lower_layers
mr_test test_tool_package_worktree
mr_test test_tool_layers_read_once_per_call
mr_test test_tool_distro_rule_never_moves_on
mr_test test_tool_set_aside_resolve_is_a_distro
mr_test test_tool_distro_listed_once_beside_its_set_aside
mr_test test_tool_distros_counts_each_name_globbed
mr_test test_tool_not_a_distro_directory
mr_test test_tool_links_are_not_candidates
mr_test test_tool_sync_steps_run_literally
mr_test test_tool_quoted_keys_from_the_tool
mr_test test_tool_package_worktree_two_distros
test_bootstrap_no_url_names_the_tool
mr_test test_tool_real_init_and_sync
mr_test test_tool_real_status_and_build
if [ "$TOOL_SKIPPED" -gt 0 ]; then
    echo "=== SKIPPED: the real-tool test (vcs is not on PATH) ==="
fi

echo ""
if [ "$MR_SKIPPED" -gt 0 ]; then
    echo "=== SKIPPED: $MR_SKIPPED tool-route test(s): PyYAML not importable with $MR_SRC ==="
fi
if [ "$LOCALE_SKIPPED" -gt 0 ]; then
    echo "=== SKIPPED: the locale part of test_tool_validate (no en_US.UTF-8 locale or no GNU comm) ==="
fi
echo "=== Results: ${PASS} passed, ${FAIL} failed, $((MR_SKIPPED + TOOL_SKIPPED + LOCALE_SKIPPED)) skipped ==="
[[ $FAIL -eq 0 ]]
