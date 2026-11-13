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
    (cd "$sb" && "$@")
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

# Synthetic layered project "p11": layers l1, l2, l3 (l3 optional),
# distro fakefox declared in bootstrap.yaml, registered in the registry,
# ROS_ROOT_DIR pointed at the sandbox underlay.
make_colcon_project() {
    local sb="$1"
    local proj="$sb/projects/p11"
    local mdir="$proj/configs/manifest"
    mkdir -p "$mdir/repos"
    printf 'l1\nl2\nl3\n' > "$mdir/layers.txt"
    printf 'l3\n' > "$mdir/optional_layers.txt"
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\ndistro: fakefox\n' \
        > "$mdir/bootstrap.yaml"
    write_repos_file "$mdir/repos/l1.repos" fakefox pkg_a pkg_b
    write_repos_file "$mdir/repos/l2.repos" fakefox pkg_c
    write_repos_file "$mdir/repos/l3.repos" fakefox pkg_priv
    echo "p11 ros2_colcon" >> "$sb/.agent/projects.local"
    echo "ROS_ROOT_DIR=\"$sb/rosroot\"" > "$sb/.agent/projects.d/p11.sh"
    make_underlay "$sb"
    echo "$proj"
}

# Full environment for adapter runs: stub toolchain on PATH, log paths set.
# Usage: run_adapter <sb> <verb-and-args...>
run_adapter() {
    local sb="$1"
    shift
    (cd "$sb" && PATH="$sb/bin:$PATH" \
        COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 "$@")
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
    (cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch "$@")
}

run_worktree_remove() {
    local sb="$1"
    shift
    (cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_remove.sh" "$@")
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
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#111 --type project --project p11 \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-111"
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
        "# project=p11 issue=owner/pkg_a#111 layer=l1 base=fakefox" "$(head -n1 "$wt/.worktree-repos")"
    assert_contains "the banner names the base and where it came from" \
        "Base:       fakefox (from the project's pin of pkg_a;" "$out"
    assert_eq "the owning branch starts at origin's fakefox" \
        "$(git -C "$proj/layers/main/l1_ws/src/pkg_a" rev-parse refs/remotes/origin/fakefox)" \
        "$(git -C "$wt/l1_ws/src/pkg_a" rev-parse HEAD)"
    assert_eq "sourcing env.sh under set -e with no install present still exits 0" \
        "ok" "$(bash -c "set -e; source '$wt/env.sh'; echo ok" 2>&1)"
    assert_contains "enter banner uses the qualified issue and --project" \
        "worktree_enter.sh --issue owner/pkg_a#111 --type project --project p11" "$out"
    assert_contains "remove banner uses the qualified issue and --project" \
        "worktree_remove.sh --issue owner/pkg_a#111 --type project --project p11" "$out"
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
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#120 --type project --project p11 \
        --layer l1 --package-repos pkg_b,pkg_a 2>&1)" || rc=$?
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-120"
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
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#120 --type project --project p11 \
        --layer l1 --package-repos pkg_b,pkg_a --base main 2>&1)" || rc=$?
    assert_eq "with --base main: exit 0" "0" "$rc"
    assert_eq "with --base main: base=main recorded" \
        "# project=p11 issue=owner/pkg_a#120 layer=l1 base=main" "$(head -n1 "$wt/.worktree-repos")"
    assert_contains "the banner says the base came from --base" "Base:       main (from --base;" "$out"
    # A worktree with no owning entry (only a sibling) has no base to resolve.
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#121 --type project --project p11 \
        --layer l1 --package-repos pkg_b 2>&1)" || rc=$?
    assert_eq "siblings only: exit 0 with the tag pin (no owning branch to start)" "0" "$rc"
    assert_eq "siblings only: no base= in the header" \
        "# project=p11 issue=owner/pkg_a#121 layer=l1" \
        "$(head -n1 "$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-121/.worktree-repos")"
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
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#130 --type project --project p11 \
        --layer l1 --package-repos pkg_b,pkg_a 2>&1)" || rc=$?
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-130"
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
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#130 --type project --project p11 \
        --layer l1 --package-repos pkg_b,pkg_a --base fakefox 2>&1)" || rc=$?
    assert_eq "with --base fakefox: exit 0" "0" "$rc"
    assert_eq "with --base fakefox: recorded" \
        "# project=p11 issue=owner/pkg_a#130 layer=l1 base=fakefox" "$(head -n1 "$wt/.worktree-repos")"

    # Started from main, named main: recorded (where it started is the
    # owner's word; the check is that origin has it and history is shared).
    git -C "$a" branch feature/issue-131 main
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#131 --type project --project p11 \
        --layer l1 --package-repos pkg_a --base main 2>&1)" || rc=$?
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-131"
    assert_eq "existing branch from main, --base main: exit 0" "0" "$rc"
    assert_eq "existing branch from main, --base main: recorded" \
        "# project=p11 issue=owner/pkg_a#131 layer=l1 base=main" "$(head -n1 "$wt/.worktree-repos")"
    assert_eq "the branch is not moved" "$hosted_main" "$(git -C "$a" rev-parse feature/issue-131)"

    # A named base origin lacks: refused, rolled back.
    git -C "$a" branch feature/issue-133 main
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#133 --type project --project p11 \
        --layer l1 --package-repos pkg_a --base nosuch 2>&1)" || rc=$?
    assert_eq "existing branch, --base origin lacks: exits 1" "1" "$rc"
    assert_contains "says so" "'feature/issue-133' already existed, and --base nosuch cannot be its base: origin has no branch 'nosuch'." "$out"
    assert_eq "no aggregate dir" "false" "$([ -e "$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-133" ] && echo true || echo false)"

    # An orphan owning branch: no history in common with the named base.
    git -C "$a" checkout --quiet --orphan feature/issue-134
    git -C "$a" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m "orphan"
    git -C "$a" checkout --quiet main
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#134 --type project --project p11 \
        --layer l1 --package-repos pkg_a --base fakefox 2>&1)" || rc=$?
    assert_eq "orphan existing branch: exits 1" "1" "$rc"
    assert_contains "says there is no history in common" "'feature/issue-134' has no commit in common with origin's 'fakefox'" "$out"

    # A branch on origin only: checked out from origin, then the same rule.
    git -C "$a" push --quiet origin origin/fakefox:refs/heads/feature/issue-132
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#132 --type project --project p11 \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "branch on origin only, no --base: exits 1" "1" "$rc"
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#132 --type project --project p11 \
        --layer l1 --package-repos pkg_a --base fakefox 2>&1)" || rc=$?
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-132"
    assert_eq "branch on origin only, --base fakefox: exit 0" "0" "$rc"
    assert_eq "branch on origin only, --base fakefox: recorded" \
        "# project=p11 issue=owner/pkg_a#132 layer=l1 base=fakefox" "$(head -n1 "$wt/.worktree-repos")"
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
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#12 --type project --project p11 \
        --layer l1 --package-repos pkg_a --parent-issue 10 2>&1)" || rc=$?
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-12"
    assert_eq "exit 0 (the tag pin is not read)" "0" "$rc"
    assert_eq "the branch starts at the parent's tip" "$parent_tip" "$(git -C "$wt/l1_ws/src/pkg_a" rev-parse HEAD)"
    assert_contains "the banner names the parent" "Parent:     #10 (feature/issue-10)" "$out"
    assert_contains "the banner names the parent's branch as the base" "Base:       feature/issue-10 (the parent's branch:" "$out"
    assert_not_contains "no pin-sourced base in the banner" "from the project's pin" "$out"
    assert_eq "base= records the parent's branch" \
        "# project=p11 issue=owner/pkg_a#12 layer=l1 base=feature/issue-10" "$(head -n1 "$wt/.worktree-repos")"
    # --base with --parent-issue stays refused.
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#13 --type project --project p11 \
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
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#140 --type project --project p11 \
        --layer l1 --package-repos pkg_a --branch foo 2>&1)" || rc=$?
    assert_eq "--branch with --layer: exits 1" "1" "$rc"
    assert_contains "says why" "--branch is not valid for a package worktree (--layer): the adapter names each repository's branch" "$out"
    assert_eq "no branch foo made" "false" "$(git -C "$a" show-ref --verify --quiet refs/heads/foo && echo true || echo false)"
    assert_eq "no feature/issue-140 made" "false" \
        "$(git -C "$a" show-ref --verify --quiet refs/heads/feature/issue-140 && echo true || echo false)"
    local v
    for v in "" "-foo" "HEAD"; do
        rc=0
        out="$(run_worktree_create "$sb" --issue owner/pkg_a#140 --type project --project p11 \
            --layer l1 --package-repos pkg_a --base "$v" 2>&1)" || rc=$?
        assert_eq "--base '$v': exits 1" "1" "$rc"
        if [ -z "$v" ]; then
            assert_contains "--base '': refused, not ignored" "Error: --base requires a branch name" "$out"
        else
            assert_contains "--base '$v': refused" "Error: --base '$v' is not a valid branch name" "$out"
        fi
    done
    assert_eq "nothing made" "false" "$([ -e "$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-140" ] && echo true || echo false)"
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
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#112 --type project --project p11 \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_not_contains "healthy package hook: no warning about the enclosing repo's broken hook" \
        "no longer exists" "$out"
    # Now break the package repo's hook: the warning names that repo.
    printf '#!/usr/bin/env bash\n# start templated\nINSTALL_PYTHON=%s\n# end templated\nexit 0\n' \
        "$sb/gone/.venv/bin/python3" > "$proj/layers/main/l1_ws/src/pkg_a/.git/hooks/pre-commit"
    rc=0
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#113 --type project --project p11 \
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
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#222 --type project --project p11 \
        --layer l1 --package-repos pkg_a,pkg_b 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-222"
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
    (cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_create.sh" "$@")
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
    out="$(run_worktree_create_strict "$sb" --issue owner/pkg_a#444 --type project --project p11 \
        --layer l1 --package-repos pkg_a,pkg_b 2>&1)" || rc=$?
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-444"
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
    out="$(run_worktree_create_strict "$sb" --issue owner/pkg_a#445 --type project --project p11 \
        --layer l1 --package-repos pkg_a,pkg_b 2>&1)" || rc=$?
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-445"
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
    out="$(run_worktree_create_strict "$sb" --issue owner/pkg_a#446 --type project --project p11 \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    rm -f "$a/.git/hooks/post-checkout"
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-446"
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
    out="$(run_worktree_create "$sb" --issue owner/pkg_a#333 --type project --project p11 \
        --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-333"
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
    run_worktree_create "$sb" --issue owner/pkg_a#333 --type project --project p11 \
        --layer l1 --package-repos pkg_a,pkg_b >/dev/null 2>&1
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-333"
    echo dirty >> "$wt/l1_ws/src/pkg_b/README.md"
    out="$(run_worktree_remove "$sb" --issue owner/pkg_a#333 --type project --project p11 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the dirty entry" "l1_ws/src/pkg_b" "$out"
    assert_eq "nothing removed: pkg_a worktree still present" \
        "true" "$([ -d "$wt/l1_ws/src/pkg_a" ] && echo true || echo false)"
    assert_eq "nothing removed: pkg_b worktree still present" \
        "true" "$([ -d "$wt/l1_ws/src/pkg_b" ] && echo true || echo false)"
    rc=0
    out="$(run_worktree_remove "$sb" --issue owner/pkg_a#333 --type project --project p11 --force 2>&1)" || rc=$?
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
    run_worktree_create "$sb" --issue owner/pkg_a#444 --type project --project p11 \
        --layer l1 --package-repos pkg_a,pkg_b >/dev/null 2>&1
    wt="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-444"
    echo dirty >> "$wt/l1_ws/src/pkg_b/README.md"
    out="$(cd "$sb" && "$sb/.agent/scripts/worktree_list.sh" --json)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "issue 444 reported" '"issue":444' "$out"
    assert_contains "project p11 reported as repo" '"repo":"p11"' "$out"
    assert_contains "owning branch reported" "feature/issue-444" "$out"
    assert_contains "sibling branch reported" "feature/pkg_a-issue-444" "$out"
    assert_contains "dirty status reported" '"status":"dirty"' "$out"
}

run_worktree_enter_print_path() {
    local sb="$1"
    shift
    (cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_enter.sh" --print-path "$@")
}

test_worktree_enter_disambiguates_by_qualified_issue() {
    echo "TEST: qualified --issue resolves each of two same-N package worktrees; bare N errors with the hint"
    local sb out rc=0 proj wt_a wt_c
    sb="$(make_worktree_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    make_committed_pkg_repo "$proj" l1 pkg_a
    make_committed_pkg_repo "$proj" l2 pkg_c
    run_worktree_create "$sb" --issue owner/pkg_a#555 --type project --project p11 \
        --layer l1 --package-repos pkg_a >/dev/null 2>&1
    run_worktree_create "$sb" --issue owner/pkg_c#555 --type project --project p11 \
        --layer l2 --package-repos pkg_c >/dev/null 2>&1
    wt_a="$sb/projects/p11/worktrees/issue-p11-owner-pkg_a-555"
    wt_c="$sb/projects/p11/worktrees/issue-p11-owner-pkg_c-555"
    assert_eq "pkg_a worktree exists" "true" "$([ -d "$wt_a" ] && echo true || echo false)"
    assert_eq "pkg_c worktree exists" "true" "$([ -d "$wt_c" ] && echo true || echo false)"

    out="$(run_worktree_enter_print_path "$sb" --issue owner/pkg_a#555 --type project --project p11 2>&1)" || rc=$?
    assert_eq "qualified issue for pkg_a resolves to pkg_a's worktree" "0" "$rc"
    assert_eq "resolved path is pkg_a's" "$wt_a" "$out"

    rc=0
    out="$(run_worktree_enter_print_path "$sb" --issue owner/pkg_c#555 --type project --project p11 2>&1)" || rc=$?
    assert_eq "qualified issue for pkg_c resolves to pkg_c's worktree" "0" "$rc"
    assert_eq "resolved path is pkg_c's" "$wt_c" "$out"

    rc=0
    out="$(run_worktree_enter_print_path "$sb" --issue 555 --type project --project p11 2>&1)" || rc=$?
    assert_eq "bare number is ambiguous: exits nonzero" "1" "$rc"
    assert_contains "names both candidates" "issue-p11-owner-pkg_a-555" "$out"
    assert_contains "names both candidates (2)" "issue-p11-owner-pkg_c-555" "$out"
    assert_contains "points at the qualified form, not --repo-slug" \
        "--repo-slug cannot" "$out"
    assert_contains "gives the qualified ref for pkg_a" "--issue owner/pkg_a#555" "$out"
    assert_contains "gives the qualified ref for pkg_c" "--issue owner/pkg_c#555" "$out"
}

# Replace the sandbox's _issue_helpers.sh with a stub that records the
# --repo it's called with (issue_lookup) to $ISSUE_LOOKUP_LOG, instead of
# doing any real lookup. extract_gh_slug is the real implementation (still
# needed by worktree_create.sh's own remote-URL parsing).
stub_issue_lookup_recorder() {
    local sb="$1"
    cat > "$sb/.agent/scripts/_issue_helpers.sh" << 'STUBEOF'
extract_gh_slug() {
    local url="$1" slug
    slug=$(echo "$url" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')
    if [[ "$slug" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
        echo "$slug"
    fi
}
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
    log="$sb/issue_lookup.log"
    : > "$log"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" ISSUE_LOOKUP_LOG="$log" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue rolker/ros2_network_monitor#27 \
        --type project --project p11 --layer l1 --package-repos pkg_a 2>&1)" || rc=$?
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
    echo "TEST: distro falls back to ROS_DISTRO in the per-project config"
    local sb out proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    # Remove the manifest declaration; declare via config instead.
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\n' \
        > "$proj/configs/manifest/bootstrap.yaml"
    {
        echo "ROS_ROOT_DIR=\"$sb/rosroot\""
        echo 'ROS_DISTRO="fakefox"'
    } > "$sb/.agent/projects.d/p11.sh"
    out="$(run_adapter "$sb" env)" || true
    assert_contains "underlay from config distro" "rosroot/fakefox/setup.bash" "$out"
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
    sed -i'' -e "s|^p11 ros2_colcon.*|p11 ros2_colcon $proj distro=regfox|" "$sb/.agent/projects.local"
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
    echo "ROS_ROOT_DIR=\"$sb/rosroot\"" > "$sb/.agent/projects.d/p11.sh"
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
    mkdir -p "$sb/projects/p11"
    echo "p11 ros2_colcon" >> "$sb/.agent/projects.local"
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
    echo "TEST: a failing per-project config is a hard error, not a silent fallback"
    local sb out rc=0 proj
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_colcon_project "$sb")"
    # Config declares the override, then fails — the override must not be
    # silently dropped in favor of /opt/ros.
    {
        echo "ROS_ROOT_DIR=\"$sb/rosroot\""
        echo "false"
    } > "$sb/.agent/projects.d/p11.sh"
    out="$(run_adapter "$sb" env 2>&1)" || rc=$?
    assert_eq "exits nonzero (_rc_ros_root path)" "1" "$rc"
    assert_contains "names the config" "failed to source $sb/.agent/projects.d/p11.sh" "$out"

    # Same failure via the distro-resolution path (no distro in manifest).
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\n' \
        > "$proj/configs/manifest/bootstrap.yaml"
    rc=0
    out="$(run_adapter "$sb" env 2>&1)" || rc=$?
    assert_eq "exits nonzero (_rc_distro path)" "1" "$rc"
    assert_contains "still names the config" "failed to source" "$out"
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
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" VCS_FAIL_LAYERS="l3" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "setup still exits 0" "0" "$rc"
    assert_contains "warns about the optional layer" "optional layer 'l3'" "$out"
}

test_setup_required_layer_failure_aborts() {
    echo "TEST: non-optional layer import failure aborts setup"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_colcon_project "$sb" >/dev/null
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" VCS_FAIL_LAYERS="l2" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
    out="$(cd "$sb" && PATH="$sb/isolatedbin" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing tool" "'vcs' (vcstool) not found" "$out"
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

# Fresh (empty) hosting dir registered as p11 with the sandbox underlay.
make_fresh_project() {
    local sb="$1"
    mkdir -p "$sb/projects/p11"
    echo "p11 ros2_colcon" >> "$sb/.agent/projects.local"
    echo "ROS_ROOT_DIR=\"$sb/rosroot\"" > "$sb/.agent/projects.d/p11.sh"
    make_underlay "$sb"
    echo "$sb/projects/p11"
}

test_setup_bootstraps_manifest_pattern_b() {
    echo "TEST: setup on a fresh hosting dir bootstraps a Pattern B manifest from the config URL"
    local sb out rc=0 proj url
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_fresh_project "$sb")"
    url="$(make_manifest_remote "$sb" l1)"
    echo "MANIFEST_BOOTSTRAP_URL=\"$url\"" >> "$sb/.agent/projects.d/p11.sh"
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
    echo "TEST: BOOTSTRAP_URL in the environment overrides the config and file"
    local sb out rc=0 proj url
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    proj="$(make_fresh_project "$sb")"
    url="$(make_manifest_remote "$sb" l1)"
    echo 'MANIFEST_BOOTSTRAP_URL="file:///nonexistent/config.yaml"' >> "$sb/.agent/projects.d/p11.sh"
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "fetched the env URL" "Fetching bootstrap config from $url" "$out"
    assert_eq "manifest present" "true" "$([ -f "$proj/configs/manifest/layers.txt" ] && echo true || echo false)"
}

test_setup_bootstrap_shared_url_is_reported() {
    echo "TEST: a bootstrap URL from the shared project_config.sh is reported on stderr; one from the settings file or the legacy .sh is not (#332)"
    local sb out rc url note
    note="NOTE: project 'p11' has no bootstrap URL of its own; using MANIFEST_BOOTSTRAP_URL from the shared .agent/project_config.sh"

    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_fresh_project "$sb" >/dev/null
    url="$(make_manifest_remote "$sb" l1)"
    rm -f "$sb/.agent/projects.d/p11.sh"
    printf 'ROS_ROOT_DIR="%s"\nMANIFEST_BOOTSTRAP_URL="%s"\n' "$sb/rosroot" "$url" > "$sb/.agent/project_config.sh"
    rc=0; out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "shared URL: exit 0" "0" "$rc"
    assert_contains "shared URL: fetched" "Fetching bootstrap config from $url" "$out"
    assert_contains "shared URL: the fall-through is reported" "$note" "$out"
    assert_contains "shared URL: the note names the setting" "project_setting.sh set p11 bootstrap_url=<url>" "$out"

    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_fresh_project "$sb" >/dev/null
    url="$(make_manifest_remote "$sb" l1)"
    rm -f "$sb/.agent/projects.d/p11.sh"
    printf 'ROS_ROOT_DIR="%s"\nMANIFEST_BOOTSTRAP_URL="file:///nonexistent/shared.yaml"\n' "$sb/rosroot" > "$sb/.agent/project_config.sh"
    printf 'bootstrap_url=%s\n' "$url" > "$sb/.agent/projects.d/p11"
    rc=0; out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "settings-file URL: exit 0" "0" "$rc"
    assert_contains "settings-file URL: fetched" "Fetching bootstrap config from $url" "$out"
    assert_not_contains "settings-file URL: no note" "NOTE:" "$out"

    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_fresh_project "$sb" >/dev/null
    url="$(make_manifest_remote "$sb" l1)"
    echo "MANIFEST_BOOTSTRAP_URL=\"$url\"" >> "$sb/.agent/projects.d/p11.sh"
    rc=0; out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "legacy URL: exit 0" "0" "$rc"
    assert_not_contains "legacy URL: no note" "NOTE:" "$out"
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
    assert_contains "lists MANIFEST_BOOTSTRAP_URL" "MANIFEST_BOOTSTRAP_URL" "$out"
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
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "traversal config_path exits nonzero" "1" "$rc"
    assert_contains "names config_path" "invalid 'config_path'" "$out"
    assert_eq "nothing cloned" "false" "$([ -e "$proj/configs/manifest_repo" ] && echo true || echo false)"
    printf 'git_url: file://%s/remote/manifest_repo\nbranch: fakefox\nlayer: ../x\n' "$sb" \
        > "$sb/remote/bootstrap.yaml"
    rc=0
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "config..d exits 0" "0" "$rc"
    assert_eq "symlink targets config..d" \
        "manifest_repo/manifest_repo/config..d" "$(readlink "$proj/configs/manifest")"
    # A real '..' component nested inside the path is still rejected.
    printf 'git_url: file://%s/remote/manifest_repo\nbranch: fakefox\nconfig_path: config/../../etc\n' "$sb" \
        > "$sb/remote/bootstrap.yaml"
    rm -rf "$proj/configs"
    rc=0
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "mismatched origin exits nonzero" "1" "$rc"
    assert_contains "names both repos" "is a checkout of file:///elsewhere/other_manifest.git, not file://$sb/remote/manifest_repo" "$out"
    assert_eq "no symlink created" "false" "$([ -e "$proj/configs/manifest" ] && echo true || echo false)"
    # A non-git directory at the clone path is refused too.
    rm -rf "$clone_dir" && mkdir -p "$clone_dir"
    rc=0
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
    echo 'MANIFEST_BOOTSTRAP_URL="file:///nonexistent/config.yaml"' >> "$sb/.agent/projects.d/p11.sh"
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

# ---- manifest route (issue #436) ----
#
# The resolver these tests run is THIS checkout's source
# (tools/ros-manifest/src on PYTHONPATH), never a copy installed elsewhere
# (the main checkout's venv holds main's code; a worktree and CI have no
# venv of their own). The interpreter is the first that imports both yaml
# and that source: the python of a ros-manifest on PATH (CI installs one),
# the main checkout's .venv python, then python3. When none can, the tests
# are SKIPPED loudly, and that is a FAILURE where the resolver is meant to
# be present: a ros-manifest on PATH, a main-checkout .venv/bin/ros-manifest,
# or CI set (the adapter-contract job installs the resolver, so a quiet
# skip there would pass the job without running these tests).

MR_SRC="$REAL_ROOT/tools/ros-manifest/src"
MR_PY=""
MR_SKIPPED=0
mr_pick_python() {
    local c onpath shebang common
    local -a cands=()
    onpath="$(command -v ros-manifest 2>/dev/null || true)"
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
import sys, yaml, ros_manifest
sys.exit(0 if ros_manifest.__file__.startswith(sys.argv[1] + "/") else 3)' "$MR_SRC" 2>/dev/null; then
            MR_PY="$c"
            return 0
        fi
    done
    return 1
}
if ! mr_pick_python; then
    _mr_common="$(git -C "$REAL_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if command -v ros-manifest >/dev/null 2>&1 || [ -n "${CI:-}" ] \
        || { [ -n "$_mr_common" ] && [ -x "${_mr_common%/.git}/.venv/bin/ros-manifest" ]; }; then
        echo "  FAIL: manifest-route tests: no python imports both yaml and $MR_SRC, though the resolver is meant to be present here (a ros-manifest on PATH, a main-checkout .venv/bin/ros-manifest, or CI)"
        FAIL=$((FAIL + 1))
    fi
fi

# Run a manifest-route test function, or skip it loudly.
mr_test() {
    if [ -z "$MR_PY" ]; then
        echo "TEST: $1"
        echo "  SKIPPED: PyYAML not importable with this checkout's resolver source ($MR_SRC); install it (make install-ros-manifest, or a python3 with PyYAML)"
        MR_SKIPPED=$((MR_SKIPPED + 1))
        return 0
    fi
    "$1"
}

# The resolver wrapper at <sb>/.venv/bin/ros-manifest, where the adapter
# looks (the sandbox is not a git checkout, so it is its own main checkout).
make_mr_resolver() {
    local sb="$1"
    mkdir -p "$sb/.venv/bin"
    cat > "$sb/.venv/bin/ros-manifest" <<EOF
#!/usr/bin/env bash
echo "RESOLVER_RAN:\$*" >> "$sb/resolver.log"
PYTHONPATH="$MR_SRC" exec "$MR_PY" -m ros_manifest.cli "\$@"
EOF
    chmod +x "$sb/.venv/bin/ros-manifest"
}

# A manifest in the new format. Layers core and extra (extra optional);
# pkg_a has a per-distro ref for fakefox (a quoted number), pkg_b is absent
# for fakefox, pkg_c (layer extra) is in a group the role "lite"
# subtracts. <marker>, when given, is one more core repository, so a test
# can tell which commit of the manifest was resolved. With <extends_url>
# and <extends_ref>, the manifest extends base.yaml there.
write_mr_manifest() {  # <file> [marker] [extends_url extends_ref]
    local file="$1" marker="${2:-}" eurl="${3:-}" eref="${4:-}"
    mkdir -p "$(dirname "$file")"
    {
        if [ -n "$eurl" ]; then
            printf 'extends:\n  url: %s\n  ref: %s\n  path: base.yaml\n' "$eurl" "$eref"
        fi
        cat <<'EOF'
layers:
  - core
  - extra
optional_layers:
  - extra
repos:
  core:
    pkg_a:
      url: file:///nonexistent/pkg_a.git
      ref: main
      distros:
        fakefox:
          ref: "2.0"
    pkg_b:
      url: file:///nonexistent/pkg_b.git
      ref: main
      distros:
        fakefox:
          absent: true
EOF
        if [ -n "$marker" ]; then
            printf '    %s:\n      url: file:///nonexistent/%s.git\n      ref: main\n' "$marker" "$marker"
        fi
        cat <<'EOF'
  extra:
    pkg_c:
      url: file:///nonexistent/pkg_c.git
      ref: v1
groups:
  extras:
    default: include
    repos: [pkg_c]
roles:
  dev: {}
  lite:
    subtract: [extras]
EOF
    } > "$file"
}

# A base manifest (for extends) with one core repository named <marker>.
write_mr_base() {  # <file> <marker>
    mkdir -p "$(dirname "$1")"
    printf 'layers:\n  - core\nrepos:\n  core:\n    %s:\n      url: file:///nonexistent/%s.git\n      ref: main\nroles:\n  dev: {}\n  lite: {}\n' "$2" "$2" > "$1"
}

# A manifest repository: a work clone at <sb>/mwork/<name> pushing to the
# bare remote <sb>/mremote/<name>.git (branch main). Prints the remote's
# file:// URL.
make_mr_remote() {  # <sb> <name>
    local sb="$1" name="$2" work bare
    work="$sb/mwork/$name"
    bare="$sb/mremote/$name.git"
    mkdir -p "$work" "$(dirname "$bare")"
    git init --quiet --bare -b main "$bare"
    git -C "$work" init --quiet -b main
    git -C "$work" remote add origin "file://$bare"
    echo "file://$bare"
}

# Commit and push the work clone's current files; prints the commit.
mr_push() {  # <sb> <name> [extra push refspecs...]
    local work="$1/mwork/$2"
    shift 2
    git -C "$work" add -A
    git -C "$work" -c user.name=t -c user.email=t@t commit --quiet -m "change" --allow-empty
    git -C "$work" push --quiet --force origin main "$@"
    git -C "$work" rev-parse HEAD
}

# A sandbox for the manifest route: toolchain stubs, underlay, resolver
# wrapper, and p11 registered (not created: setup creates it) with
# role=<role> distro=fakefox and the given settings lines.
make_mr_sandbox() {  # <role-or-empty> <settings lines...>
    local role="$1" sb fields=""
    shift
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_underlay "$sb"
    make_mr_resolver "$sb"
    [ -n "$role" ] && fields=" role=$role"
    echo "p11 ros2_colcon projects/p11$fields distro=fakefox" > "$sb/.agent/projects.local"
    echo "ROS_ROOT_DIR=\"$sb/rosroot\"" > "$sb/.agent/projects.d/p11.sh"
    [ $# -gt 0 ] && printf '%s\n' "$@" > "$sb/.agent/projects.d/p11"
    echo "$sb"
}

mr_settings() {  # <sb> <settings lines...>
    local sb="$1"
    shift
    printf '%s\n' "$@" > "$sb/.agent/projects.d/p11"
}

# The adapter on p11, with vcs creating a directory per imported repo.
run_mr() {
    local sb="$1"
    shift
    (cd "$sb" && PATH="$sb/bin:$PATH" COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" \
        VCS_MKDIRS=1 "$sb/.agent/scripts/adapter" --project p11 "$@")
}

mr_gen() { echo "$1/projects/p11/configs/manifest-resolved"; }

test_mr_wrapper_runs_this_checkouts_resolver() {
    echo "TEST: manifest route: the test resolver is this checkout's tools/ros-manifest/src"
    local out
    out="$(PYTHONPATH="$MR_SRC" "$MR_PY" -c 'import ros_manifest; print(ros_manifest.__file__)')"
    assert_contains "ros_manifest imported from this checkout" "$MR_SRC/ros_manifest/" "$out"
}

test_mr_setup_from_path_source() {
    echo "TEST: manifest route: setup from a path source resolves, imports and validates; every verb reads the generated dir"
    local sb out rc=0 gen
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml"
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    out="$(run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "setup: exit 0" "0" "$rc"
    gen="$(mr_gen "$sb")"
    assert_eq "configs/manifest-resolved is a link" "yes" "$([ -L "$gen" ] && echo yes || echo no)"
    assert_contains "the link points at a generated dir" "manifest-resolved.gen-" "$(readlink "$gen")"
    assert_eq "layers.txt: core and extra" $'core\nextra' "$(grep -v '^#' "$gen/layers.txt")"
    assert_eq "optional_layers.txt: extra" "extra" "$(grep -v '^#' "$gen/optional_layers.txt")"
    assert_contains "per-distro ref honoured (quoted number)" "version: '2.0'" "$(cat "$gen/repos/core.repos")"
    assert_not_contains "a repository absent for the distro is left out" "pkg_b" "$(cat "$gen/repos/core.repos")"
    assert_contains "the resolver got role, distro and the layout" "--role dev --distro fakefox --out" "$(cat "$sb/resolver.log")"
    assert_contains "the cache is a sibling of the generated dir" "--layout manifest-dir --cache-dir $sb/projects/p11/configs/manifest-resolved.gen-" "$(cat "$sb/resolver.log")"
    assert_eq "no cache left behind" "" "$(cd "$sb/projects/p11/configs" && ls -d -- *.cache 2>/dev/null || true)"
    assert_contains "core imported" "core_ws/src" "$(cat "$sb/vcs.log")"
    assert_contains "extra imported" "extra_ws/src" "$(cat "$sb/vcs.log")"
    assert_contains "says it edits no ignore file" "edits no ignore file" "$out"
    assert_contains ".resolved-from records the source" "source=$sb/m/manifest.yaml" "$(cat "$gen/.resolved-from")"
    assert_contains ".resolved-from records role and distro" $'role=dev\ndistro=fakefox' "$(cat "$gen/.resolved-from")"
    assert_contains ".resolved-from records the file's stamp" "file-stamp=" "$(cat "$gen/.resolved-from")"
    rc=0; out="$(run_mr "$sb" validate 2>&1)" || rc=$?
    assert_eq "validate: exit 0" "0" "$rc"
    assert_not_contains "validate: no warning" "WARNING" "$out"
    # env, build, test, repos, worktree_repos and repo_pin read the generated dir.
    out="$(run_mr "$sb" env 2>&1)"
    assert_contains "env: the distro underlay" "rosroot/fakefox/setup.bash" "$out"
    rc=0; run_mr "$sb" build >/dev/null 2>&1 || rc=$?
    assert_eq "build: exit 0" "0" "$rc"
    assert_contains "build ran colcon in core" "core_ws CMD:build" "$(cat "$sb/colcon.log")"
    assert_contains "build ran colcon in extra" "extra_ws CMD:build" "$(cat "$sb/colcon.log")"
    out="$(run_mr "$sb" env 2>&1)"
    assert_contains "env: the built core layer" "core_ws/install/local_setup.bash" "$out"
    rc=0; run_mr "$sb" test >/dev/null 2>&1 || rc=$?
    assert_eq "test: exit 0" "0" "$rc"
    out="$(run_mr "$sb" repo_pin pkg_a 2>/dev/null)"
    assert_eq "repo_pin reads the generated .repos" "2.0" "${out%%$'\t'*}"
    local d
    for d in pkg_a pkg_c; do
        git -C "$sb/projects/p11/layers/main/$([ "$d" = pkg_c ] && echo extra || echo core)_ws/src/$d" init --quiet
    done
    out="$(run_mr "$sb" repos 2>&1)"
    assert_contains "repos lists pkg_a" "pkg_a:$sb/projects/p11/layers/main/core_ws/src/pkg_a" "$out"
    assert_contains "repos lists pkg_c" "pkg_c:" "$out"
    rc=0; out="$(run_mr "$sb" worktree_repos --issue owner/pkg_a#5 --layer core --package-repos pkg_a 2>&1)" || rc=$?
    assert_eq "worktree_repos: exit 0" "0" "$rc"
    assert_contains "worktree_repos reads layers.txt" "core_ws/src/pkg_a" "$out"
}

test_mr_url_source_branch_tag_commit() {
    echo "TEST: manifest route: a URL source at a branch, a tag and a commit"
    local sb url out rc c1 gen
    sb="$(make_mr_sandbox dev)"
    url="$(make_mr_remote "$sb" leaf)"
    write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_one
    c1="$(mr_push "$sb" leaf)"
    git -C "$sb/mwork/leaf" tag v1
    git -C "$sb/mwork/leaf" push --quiet origin v1
    write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_two
    mr_push "$sb" leaf >/dev/null
    gen="$(mr_gen "$sb")"

    mr_settings "$sb" "source=$url" "source_ref=main"
    rc=0; out="$(run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "branch: setup exit 0" "0" "$rc"
    assert_contains "branch: checked out" "source: branch main at " "$out"
    assert_contains "branch: the tip resolved" "mark_two" "$(cat "$gen/repos/core.repos")"

    mr_settings "$sb" "source=$url" "source_ref=v1"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "tag: sync exit 0" "0" "$rc"
    assert_contains "tag: says the commit" "source: tag v1 " "$out"
    assert_contains "tag: the commit named" "-> ${c1:0:12}" "$out"
    assert_contains "tag: its commit resolved" "mark_one" "$(cat "$gen/repos/core.repos")"

    mr_settings "$sb" "source=$url" "source_ref=$c1"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "commit: sync exit 0" "0" "$rc"
    assert_contains "commit: named" "source: commit $c1 at ${c1:0:12}" "$out"
    assert_contains "commit: recorded" "commit=$c1" "$(cat "$gen/.resolved-from")"
    # sync never imports a repository the new result adds; setup does.
    rc=0; run_mr "$sb" validate >/dev/null 2>&1 || rc=$?
    assert_eq "commit: validate fails until the new repository is imported" "1" "$rc"
    run_mr "$sb" setup >/dev/null 2>&1
    rc=0; run_mr "$sb" validate >/dev/null 2>&1 || rc=$?
    assert_eq "commit: validate exit 0" "0" "$rc"

    mr_settings "$sb" "source=$url" "source_ref=nosuchref"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "unknown ref: exit 1" "1" "$rc"
    assert_contains "unknown ref: named" "source_ref 'nosuchref' is not a branch or tag" "$out"
    assert_contains "unknown ref: the previous result kept" "mark_one" "$(cat "$gen/repos/core.repos")"

    # source_path: the file inside the repository.
    mkdir -p "$sb/mwork/leaf/sub"
    write_mr_manifest "$sb/mwork/leaf/sub/other.yaml" mark_sub
    mr_push "$sb" leaf >/dev/null
    mr_settings "$sb" "source=$url" "source_ref=main" "source_path=sub/other.yaml"
    rc=0; run_mr "$sb" sync >/dev/null 2>&1 || rc=$?
    assert_eq "source_path: exit 0" "0" "$rc"
    assert_contains "source_path: that file resolved" "mark_sub" "$(cat "$gen/repos/core.repos")"
    mr_settings "$sb" "source=$url" "source_ref=main" "source_path=nope.yaml"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "missing source_path: exit 1" "1" "$rc"
    assert_contains "missing source_path: named" "source_path 'nope.yaml' is not a file" "$out"

    # A committed symbolic link out of the repository is never followed,
    # as the file or as a directory on the way to it.
    write_mr_manifest "$sb/outside/secret.yaml" mark_secret
    ln -s "$sb/outside/secret.yaml" "$sb/mwork/leaf/evil.yaml"
    ln -s "$sb/outside" "$sb/mwork/leaf/evildir"
    mr_push "$sb" leaf >/dev/null
    local spath
    for spath in evil.yaml evildir/secret.yaml; do
        mr_settings "$sb" "source=$url" "source_ref=main" "source_path=$spath"
        rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
        assert_eq "symlink source_path $spath: exit 1" "1" "$rc"
        assert_contains "symlink source_path $spath: named" "source_path '$spath' goes through the symbolic link '${spath%%/*}'" "$out"
        assert_not_contains "symlink source_path $spath: not resolved" "mark_secret" "$(cat "$gen/repos/core.repos")"
    done

    # A clone of another repository is refused.
    local other
    other="$(make_mr_remote "$sb" other)"
    write_mr_manifest "$sb/mwork/other/manifest.yaml"
    mr_push "$sb" other >/dev/null
    mr_settings "$sb" "source=$other" "source_ref=main"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "origin mismatch: exit 1" "1" "$rc"
    assert_contains "origin mismatch: named" "its origin is 'file://$sb/mremote/leaf.git', not source $other" "$out"
}

# A fingerprint of everything under <dir>: paths, link targets, file
# modes, modification times and contents, so "untouched" means byte for
# byte (and not even re-written with the same bytes).
mr_tree_hash() {
    (cd "$1" && find . -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' f; do
        if [ -L "$f" ]; then
            printf 'L %s %s\n' "$f" "$(readlink "$f")"
        elif [ -f "$f" ]; then
            printf 'F %s %s %s\n' "$f" "$(stat -c '%a %Y' "$f")" "$(sha256sum < "$f" | cut -c1-64)"
        else
            printf 'D %s\n' "$f"
        fi
    done) | sha256sum | cut -c1-64
}

# A sandbox whose p11 was set up from a URL source at main (two commits,
# so HEAD~1 exists). Prints the sandbox; the remote's URL is
# file://<sb>/mremote/leaf.git.
make_mr_url_project() {
    local sb url
    sb="$(make_mr_sandbox dev)"
    url="$(make_mr_remote "$sb" leaf)"
    write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_one
    mr_push "$sb" leaf >/dev/null
    write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_two
    mr_push "$sb" leaf >/dev/null
    mr_settings "$sb" "source=$url" "source_ref=main"
    run_mr "$sb" setup >/dev/null 2>&1
    echo "$sb"
}

test_mr_clone_follows_remote() {
    echo "TEST: manifest route: an untouched clone follows a moved branch, a force-pushed branch, a moved tag and a commit ref; a deleted tag is an error that changes nothing"
    local sb url out rc gen clone work c y mark
    sb="$(make_mr_url_project)"
    url="file://$sb/mremote/leaf.git"
    work="$sb/mwork/leaf"
    gen="$(mr_gen "$sb")"
    clone="$sb/projects/p11/configs/source-clone"
    mark="$clone/.git/ros2-colcon-adapter-commit"
    assert_contains "setup: the tip resolved" "mark_two" "$(cat "$gen/repos/core.repos")"
    assert_eq "setup: the clone is detached" "" "$(git -C "$clone" branch --show-current)"
    assert_eq "setup: the record is HEAD" "$(git -C "$clone" rev-parse HEAD)" "$(cat "$mark")"
    assert_not_contains "setup: no source-state recorded" "source-state" "$(cat "$gen/.resolved-from")"
    # A moved branch.
    write_mr_manifest "$work/manifest.yaml" mark_three
    c="$(mr_push "$sb" leaf)"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "moved branch: exit 0" "0" "$rc"
    assert_contains "moved branch: said" "-> ${c:0:12}" "$out"
    assert_contains "moved branch: the new tip resolved" "mark_three" "$(cat "$gen/repos/core.repos")"
    assert_eq "moved branch: the record follows" "$c" "$(cat "$mark")"
    # A force-pushed branch (the last commit rewritten).
    write_mr_manifest "$work/manifest.yaml" mark_rewritten
    git -C "$work" -c user.name=t -c user.email=t@t commit --quiet --amend -am rewritten
    git -C "$work" push --quiet --force origin main
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "force-pushed branch: exit 0" "0" "$rc"
    assert_not_contains "force-pushed branch: no warning" "WARNING" "$out"
    assert_eq "force-pushed branch: at the remote's tip" "$(git -C "$work" rev-parse HEAD)" "$(git -C "$clone" rev-parse HEAD)"
    assert_contains "force-pushed branch: resolved" "mark_rewritten" "$(cat "$gen/repos/core.repos")"
    # A tag on a commit no branch holds, then moved to another such commit.
    git -C "$work" checkout --quiet --detach
    write_mr_manifest "$work/manifest.yaml" mark_x
    git -C "$work" -c user.name=t -c user.email=t@t commit --quiet -am x
    git -C "$work" tag t
    git -C "$work" push --quiet origin t
    mr_settings "$sb" "source=$url" "source_ref=t"
    rc=0; run_mr "$sb" sync >/dev/null 2>&1 || rc=$?
    assert_eq "tag: exit 0" "0" "$rc"
    assert_contains "tag: resolved" "mark_x" "$(cat "$gen/repos/core.repos")"
    git -C "$work" checkout --quiet --detach main
    write_mr_manifest "$work/manifest.yaml" mark_y
    git -C "$work" -c user.name=t -c user.email=t@t commit --quiet -am y
    y="$(git -C "$work" rev-parse HEAD)"
    git -C "$work" tag -f t >/dev/null
    git -C "$work" push --quiet --force origin t
    git -C "$work" checkout --quiet main
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "moved tag: exit 0" "0" "$rc"
    assert_not_contains "moved tag: no warning" "WARNING" "$out"
    assert_contains "moved tag: followed" "-> ${y:0:12}" "$out"
    assert_contains "moved tag: resolved" "mark_y" "$(cat "$gen/repos/core.repos")"
    # A commit ref: a push changes nothing until source_ref changes.
    c="$(git -C "$work" rev-parse main)"
    mr_settings "$sb" "source=$url" "source_ref=$c"
    rc=0; run_mr "$sb" sync >/dev/null 2>&1 || rc=$?
    assert_eq "commit: exit 0" "0" "$rc"
    assert_contains "commit: resolved" "mark_rewritten" "$(cat "$gen/repos/core.repos")"
    write_mr_manifest "$work/manifest.yaml" mark_later
    mr_push "$sb" leaf >/dev/null
    run_mr "$sb" sync >/dev/null 2>&1
    assert_contains "commit: a push changes nothing" "mark_rewritten" "$(cat "$gen/repos/core.repos")"
    # A commit only a local object holds (not on any remote ref) is no ref.
    local dangling
    dangling="$(git -C "$clone" commit-tree -m dangling "$(git -C "$clone" rev-parse "HEAD^{tree}")")"
    mr_settings "$sb" "source=$url" "source_ref=$dangling"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "a commit origin does not hold: exit 1" "1" "$rc"
    assert_contains "a commit origin does not hold: named" "is not a branch or tag of $url, nor a commit it holds" "$out"
    # A tag deleted on the remote: an error, nothing changed.
    mr_settings "$sb" "source=$url" "source_ref=t"
    run_mr "$sb" sync >/dev/null 2>&1
    git -C "$work" push --quiet origin :refs/tags/t
    local head_before
    head_before="$(git -C "$clone" rev-parse HEAD)"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "deleted tag: exit 1" "1" "$rc"
    assert_contains "deleted tag: named" "source_ref 't' is not a branch or tag" "$out"
    assert_eq "deleted tag: pruned from the clone" "" "$(git -C "$clone" tag -l t)"
    assert_eq "deleted tag: the clone's checkout unchanged" "$head_before" "$(git -C "$clone" rev-parse HEAD)"
    assert_contains "deleted tag: the previous result kept" "mark_y" "$(cat "$gen/repos/core.repos")"
    # source_ref=HEAD is refused by the settings file's rules.
    mr_settings "$sb" "source=$url" "source_ref=HEAD"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "source_ref=HEAD: refused" "yes" "$([ "$rc" -ne 0 ] && echo yes || echo no)"
    assert_contains "source_ref=HEAD: names the rule" "source_ref must be a branch, tag or commit, not HEAD" "$out"
}

test_mr_clone_with_insteadof_rule() {
    echo "TEST: manifest route: a url.<base>.insteadOf rule does not make the adapter's own clone read as another origin"
    local sb out rc gen i
    sb="$(make_mr_sandbox dev)"
    make_mr_remote "$sb" leaf >/dev/null
    write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_one
    mr_push "$sb" leaf >/dev/null
    # source names an alias that the rule rewrites to the real remote.
    mr_settings "$sb" "source=file://$sb/alias/leaf.git" "source_ref=main"
    gen="$(mr_gen "$sb")"
    for i in setup sync sync; do
        rc=0; out="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.file://$sb/mremote/.insteadOf" \
            GIT_CONFIG_VALUE_0="file://$sb/alias/" run_mr "$sb" "$i" 2>&1)" || rc=$?
        assert_eq "insteadOf, $i: exit 0" "0" "$rc"
        assert_not_contains "insteadOf, $i: not refused" "not as the adapter left it" "$out"
    done
    assert_contains "insteadOf: resolved" "mark_one" "$(cat "$gen/repos/core.repos")"
}

test_mr_clone_refused_when_modified() {
    echo "TEST: manifest route: a clone in any state but as the adapter left it is refused, byte for byte untouched, the live result unchanged"
    local state sb clone gen before_link before_repos before_hash out rc expect
    for state in uncommitted untracked ignored head_moved local_branch origin no_index no_record not_git; do
        sb="$(make_mr_url_project)"
        clone="$sb/projects/p11/configs/source-clone"
        gen="$(mr_gen "$sb")"
        write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_remote_new
        mr_push "$sb" leaf >/dev/null
        case "$state" in
            uncommitted)
                write_mr_manifest "$clone/manifest.yaml" mark_local
                expect="it has uncommitted changes or untracked files" ;;
            untracked)
                git -C "$clone" config status.showUntrackedFiles no
                echo note > "$clone/notes.txt"
                expect="it has uncommitted changes or untracked files (?? notes.txt" ;;
            ignored)
                echo '*.bak' >> "$clone/.git/info/exclude"
                echo note > "$clone/manifest.bak"
                expect="it has uncommitted changes or untracked files (!! manifest.bak" ;;
            head_moved)
                expect="$(git -C "$clone" rev-parse HEAD | cut -c1-12)"
                git -C "$clone" -c advice.detachedHead=false checkout --quiet --detach HEAD~1
                expect="HEAD is at $(git -C "$clone" rev-parse HEAD | cut -c1-12), not at $expect where the adapter left it" ;;
            local_branch)
                git -C "$clone" checkout --quiet -b mine
                git -C "$clone" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m local
                expect="HEAD is on the branch 'mine', not detached" ;;
            origin)
                git -C "$clone" remote set-url origin "file://$sb/mremote/elsewhere.git"
                expect="its origin is 'file://$sb/mremote/elsewhere.git', not source file://$sb/mremote/leaf.git" ;;
            no_index)
                rm -f "$clone/.git/index"
                expect="it has no index (never checked out: half-made by an interrupted run)" ;;
            no_record)
                rm -f "$clone/.git/ros2-colcon-adapter-commit"
                expect="it has no record of the commit the adapter left it at" ;;
            not_git)
                rm -rf "$clone"
                mkdir -p "$clone"
                echo mine > "$clone/file.txt"
                expect="it is not a git clone (a file or directory the adapter did not make)" ;;
        esac
        before_link="$(readlink "$gen")"
        before_repos="$(cat "$gen/repos/core.repos")"
        before_hash="$(mr_tree_hash "$clone")"
        local verb
        for verb in sync setup; do
            rc=0; out="$(run_mr "$sb" "$verb" 2>&1)" || rc=$?
            assert_eq "$state, $verb: refused (exit 1)" "1" "$rc"
            assert_contains "$state, $verb: names the clone and the state" "the manifest clone $clone is not as the adapter left it: $expect" "$out"
            assert_contains "$state, $verb: does not use it" "The adapter does not use a modified clone; nothing was changed" "$out"
            assert_contains "$state, $verb: how to recover" "To recover: move or remove $clone and run setup or sync again" "$out"
            assert_contains "$state, $verb: names the path form" "To work on a manifest locally, use the path form" "$out"
            assert_eq "$state, $verb: the clone byte for byte untouched" "$before_hash" "$(mr_tree_hash "$clone")"
            assert_eq "$state, $verb: the link unchanged" "$before_link" "$(readlink "$gen")"
            assert_eq "$state, $verb: the live result unchanged" "$before_repos" "$(cat "$gen/repos/core.repos")"
        done
        rc=0; out="$(run_mr "$sb" validate 2>&1)" || rc=$?
        assert_eq "$state, validate: fails" "1" "$rc"
        assert_contains "$state, validate: the same message" "❌ ERROR: source: the manifest clone $clone is not as the adapter left it: $expect" "$out"
        assert_eq "$state, validate: the clone untouched" "$before_hash" "$(mr_tree_hash "$clone")"
        # Removing the clone is the recovery: the next sync clones afresh.
        rm -rf "$clone"
        rc=0; run_mr "$sb" sync >/dev/null 2>&1 || rc=$?
        assert_eq "$state, after removing the clone: sync exit 0" "0" "$rc"
        assert_contains "$state, after removing the clone: the remote's tip resolved" "mark_remote_new" "$(cat "$gen/repos/core.repos")"
    done
}

test_mr_clone_removed_only_when_created_here() {
    echo "TEST: manifest route: a failure removes only a clone this run created; an existing clone is never removed"
    local sb url out rc clone gen hash
    sb="$(make_mr_sandbox dev)"
    url="$(make_mr_remote "$sb" leaf)"
    write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_one
    mr_push "$sb" leaf >/dev/null
    clone="$sb/projects/p11/configs/source-clone"
    gen="$(mr_gen "$sb")"
    # First setup with a ref the remote lacks: the clone it made is removed.
    mr_settings "$sb" "source=$url" "source_ref=nosuchref"
    rc=0; out="$(run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "new clone, bad ref: exit 1" "1" "$rc"
    assert_eq "new clone, bad ref: the clone this run made removed" "no" "$([ -e "$clone" ] && echo yes || echo no)"
    # An existing untouched clone and a bad ref: kept, checkout unchanged.
    mr_settings "$sb" "source=$url" "source_ref=main"
    run_mr "$sb" setup >/dev/null 2>&1
    hash="$(git -C "$clone" rev-parse HEAD)"
    mr_settings "$sb" "source=$url" "source_ref=nosuchref"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "existing clone, bad ref: exit 1" "1" "$rc"
    assert_eq "existing clone, bad ref: kept" "yes" "$([ -d "$clone/.git" ] && echo yes || echo no)"
    assert_eq "existing clone, bad ref: checkout unchanged" "$hash" "$(git -C "$clone" rev-parse HEAD)"
    # An existing clone and the remote gone (offline): kept, says nothing changed.
    mr_settings "$sb" "source=$url" "source_ref=main"
    mv "$sb/mremote/leaf.git" "$sb/mremote/leaf.away"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "existing clone, offline: exit 1" "1" "$rc"
    assert_contains "existing clone, offline: says so" "cannot fetch source $url into $clone (offline?); nothing changed" "$out"
    assert_eq "existing clone, offline: kept" "yes" "$([ -d "$clone/.git" ] && echo yes || echo no)"
    assert_contains "existing clone, offline: the result kept" "mark_one" "$(cat "$gen/repos/core.repos")"
    mv "$sb/mremote/leaf.away" "$sb/mremote/leaf.git"
    # A no-index clone that this run did not make, with a bad ref: refused, never removed.
    rm -f "$clone/.git/index"
    mr_settings "$sb" "source=$url" "source_ref=nosuchref"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "no-index clone, bad ref: exit 1" "1" "$rc"
    assert_contains "no-index clone, bad ref: refused as modified" "it has no index" "$out"
    assert_eq "no-index clone, bad ref: not removed" "yes" "$([ -d "$clone/.git" ] && echo yes || echo no)"
}

test_mr_stale_extends_base() {
    echo "TEST: manifest route: every sync clones the extends base afresh; a commit as extends.ref is the resolver's error"
    local sb burl out rc gen bc
    sb="$(make_mr_sandbox dev)"
    burl="$(make_mr_remote "$sb" base)"
    write_mr_base "$sb/mwork/base/base.yaml" base_one
    bc="$(mr_push "$sb" base)"
    write_mr_manifest "$sb/m/manifest.yaml" "" "$burl" main
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    rc=0; run_mr "$sb" setup >/dev/null 2>&1 || rc=$?
    assert_eq "setup with a git extends: exit 0" "0" "$rc"
    gen="$(mr_gen "$sb")"
    assert_contains "the base's repository resolved" "base_one" "$(cat "$gen/repos/core.repos")"
    write_mr_base "$sb/mwork/base/base.yaml" base_two
    mr_push "$sb" base >/dev/null
    run_mr "$sb" sync >/dev/null 2>&1
    assert_contains "base branch moved: followed" "base_two" "$(cat "$gen/repos/core.repos")"
    assert_eq "no cache left in or beside the generated dir" "" \
        "$(cd "$sb/projects/p11/configs" && { ls -d -- *.cache 2>/dev/null; ls -d -- manifest-resolved/*cache* 2>/dev/null; } || true)"
    write_mr_manifest "$sb/m/manifest.yaml" "" "$burl" "$bc"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "commit as extends.ref: exit 1" "1" "$rc"
    assert_contains "the resolver's clone error passed through" "failed to clone its extends base" "$out"
    assert_contains "the previous result kept" "base_two" "$(cat "$gen/repos/core.repos")"
    assert_eq "one generated dir left, no cache" "1" "$(cd "$sb/projects/p11/configs" && ls -d -- manifest-resolved.gen-* | wc -l | tr -d ' ')"
}

test_mr_offline_keeps_previous() {
    echo "TEST: manifest route: a fetch failure exits 1 and keeps the previous resolved manifest"
    local sb url out rc gen before
    sb="$(make_mr_sandbox dev)"
    url="$(make_mr_remote "$sb" leaf)"
    write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_one
    mr_push "$sb" leaf >/dev/null
    mr_settings "$sb" "source=$url" "source_ref=main"
    run_mr "$sb" setup >/dev/null 2>&1
    gen="$(mr_gen "$sb")"
    before="$(readlink "$gen")"
    rm -rf "$sb/mremote/leaf.git"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "offline sync: exit 1" "1" "$rc"
    assert_contains "offline sync: says nothing changed" "cannot fetch source $url" "$out"
    assert_eq "offline sync: the link unchanged" "$before" "$(readlink "$gen")"
    assert_contains "offline sync: the old result kept" "mark_one" "$(cat "$gen/repos/core.repos")"
}

test_mr_role_and_distro_changes() {
    echo "TEST: manifest route: a role or distro change fails validate until sync; a checkout left behind is named"
    local sb out rc gen
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml"
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    run_mr "$sb" setup >/dev/null 2>&1
    gen="$(mr_gen "$sb")"
    assert_contains "role dev: pkg_c selected" "pkg_c" "$(cat "$gen/repos/extra.repos")"
    sed -i 's/role=dev/role=lite/' "$sb/.agent/projects.local"
    rc=0; out="$(run_mr "$sb" validate 2>&1)" || rc=$?
    assert_eq "role changed: validate exit 1" "1" "$rc"
    assert_contains "role changed: names the registry line and sync" "is for role 'dev' but the registry line says role=lite (run: .agent/scripts/adapter --project p11 sync" "$out"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "role changed: sync exit 0" "0" "$rc"
    assert_contains "role changed: the layers changed message" "existing package worktrees keep their old env.sh; recreate them" "$out"
    assert_eq "role lite: extra left out" "core" "$(grep -v '^#' "$gen/layers.txt")"
    rc=0; out="$(run_mr "$sb" validate 2>&1)" || rc=$?
    assert_eq "role lite: validate exit 0" "0" "$rc"
    assert_contains "role lite: pkg_c's checkout named" "layer 'extra': 'pkg_c' is checked out but not in the resolved manifest" "$out"
    assert_eq "role lite: nothing removed" "yes" "$([ -d "$sb/projects/p11/layers/main/extra_ws/src/pkg_c" ] && echo yes || echo no)"
    sed -i 's/distro=fakefox/distro=otherfox/' "$sb/.agent/projects.local"
    rc=0; out="$(run_mr "$sb" validate 2>&1)" || rc=$?
    assert_eq "distro changed: validate exit 1" "1" "$rc"
    assert_contains "distro changed: named" "is for distro 'fakefox' but the registry line says distro=otherfox" "$out"
    run_mr "$sb" sync >/dev/null 2>&1
    assert_contains "distro otherfox: pkg_b present there" "pkg_b" "$(cat "$gen/repos/core.repos")"
    assert_contains "distro otherfox: pkg_a at its default ref" "version: main" "$(cat "$gen/repos/core.repos")"
}

test_mr_sync_names_a_new_layer() {
    echo "TEST: manifest route: sync's run-setup notice counts a layer that is new (never set up)"
    local sb out rc
    sb="$(make_mr_sandbox lite)"
    write_mr_manifest "$sb/m/manifest.yaml"
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    run_mr "$sb" setup >/dev/null 2>&1
    assert_eq "role lite: extra never set up" "no" "$([ -d "$sb/projects/p11/layers/main/extra_ws/src" ] && echo yes || echo no)"
    sed -i 's/role=lite/role=dev/' "$sb/.agent/projects.local"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "role dev: sync exit 0" "0" "$rc"
    assert_contains "role dev: the new layer's repository counted" "source: 1 repository in the resolved manifest not checked out yet; run: .agent/scripts/adapter --project p11 setup" "$out"
    run_mr "$sb" setup >/dev/null 2>&1
    out="$(run_mr "$sb" sync 2>&1)"
    assert_not_contains "after setup: no notice" "not checked out yet" "$out"
}

test_mr_validate_link_missing_and_path_changed() {
    echo "TEST: manifest route: validate fails with no resolved manifest; warns when a path source changed"
    local sb out rc
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml"
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    mkdir -p "$sb/projects/p11"
    rc=0; out="$(run_mr "$sb" validate 2>&1)" || rc=$?
    assert_eq "no link: exit 1" "1" "$rc"
    assert_contains "no link: run setup" "Run: .agent/scripts/adapter --project p11 setup" "$out"
    run_mr "$sb" setup >/dev/null 2>&1
    echo "# edited" >> "$sb/m/manifest.yaml"
    rc=0; out="$(run_mr "$sb" validate 2>&1)" || rc=$?
    assert_eq "changed path source: validate still exit 0" "0" "$rc"
    assert_contains "changed path source: warned" "has changed (modification time or size) since it was resolved" "$out"
    run_mr "$sb" sync >/dev/null 2>&1
    rc=0; out="$(run_mr "$sb" validate 2>&1)" || rc=$?
    assert_eq "after sync: validate exit 0" "0" "$rc"
    assert_not_contains "after sync: no warning" "WARNING" "$out"
    rm -f "$sb/m/manifest.yaml"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "missing path source: exit 1" "1" "$rc"
    assert_contains "missing path source: named" "is not a readable file" "$out"
}

test_mr_layer_failures() {
    echo "TEST: manifest route: an optional layer's import failure is tolerated, a required one aborts"
    local sb out rc
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml"
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    rc=0; out="$(VCS_FAIL_LAYERS=extra run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "optional extra fails: exit 0" "0" "$rc"
    assert_contains "optional extra fails: warned" "import failed for optional layer 'extra'" "$out"
    rc=0; out="$(VCS_FAIL_LAYERS=core run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "required core fails: exit 1" "1" "$rc"
    assert_contains "required core fails: named" "vcs import failed for layer 'core'" "$out"
}

test_mr_resolver_failures() {
    echo "TEST: manifest route: a resolver failure keeps the previous result; absent or stale resolver; an empty result"
    local sb out rc gen before
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml" mark_one
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    run_mr "$sb" setup >/dev/null 2>&1
    gen="$(mr_gen "$sb")"
    before="$(readlink "$gen")"
    printf 'layers: [core\n' > "$sb/m/manifest.yaml"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "bad manifest: exit 1" "1" "$rc"
    assert_contains "bad manifest: the resolver's error passed through" "ERROR:" "$out"
    assert_contains "bad manifest: says the previous is kept" "the previously resolved manifest, if any, is kept" "$out"
    assert_eq "bad manifest: link unchanged" "$before" "$(readlink "$gen")"
    assert_eq "bad manifest: no stray generated dir" "1" "$(cd "$sb/projects/p11/configs" && ls -d -- manifest-resolved.gen-* | wc -l | tr -d ' ')"

    # A role and distro that select nothing.
    write_mr_manifest "$sb/m/manifest.yaml"
    sed -i 's/distro=fakefox/distro=emptyfox/' "$sb/.agent/projects.local"
    cat > "$sb/m/manifest.yaml" <<'EOF'
layers:
  - core
repos:
  core:
    pkg_a:
      url: file:///nonexistent/pkg_a.git
      ref: main
      distros:
        emptyfox:
          absent: true
roles:
  dev: {}
EOF
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "empty result: exit 1" "1" "$rc"
    assert_contains "empty result: says so" "select no repositories" "$out"
    assert_eq "empty result: link unchanged" "$before" "$(readlink "$gen")"
    sed -i 's/distro=emptyfox/distro=fakefox/' "$sb/.agent/projects.local"
    write_mr_manifest "$sb/m/manifest.yaml"

    # A stale resolver (no --layout): the reinstall message.
    cat > "$sb/.venv/bin/ros-manifest" <<'EOF'
#!/usr/bin/env bash
echo "ros-manifest: error: unrecognized arguments: --layout manifest-dir" >&2
exit 2
EOF
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "stale resolver: exit 1" "1" "$rc"
    assert_contains "stale resolver: reinstall" "predates this adapter (it does not know --layout manifest-dir); reinstall it: make install-ros-manifest" "$out"

    # No resolver: one message naming the make target, before any fetch.
    rm -f "$sb/.venv/bin/ros-manifest"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "no resolver: exit 1" "1" "$rc"
    assert_contains "no resolver: names the path and make target" "the manifest resolver is not installed at $sb/.venv/bin/ros-manifest; run: make install-ros-manifest" "$out"
}

test_mr_interrupt_cleans_up() {
    echo "TEST: manifest route: an interrupted or failed resolve removes its new directory and the cache beside it"
    local sb rc gen before apid i
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml"
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    run_mr "$sb" setup >/dev/null 2>&1
    gen="$(mr_gen "$sb")"
    before="$(readlink "$gen")"
    # A resolver that fills --out and --cache-dir, then fails (or, with
    # MR_WAIT, waits to be interrupted).
    cat > "$sb/.venv/bin/ros-manifest" <<EOF
#!/usr/bin/env bash
while [ \$# -gt 0 ]; do
    case "\$1" in --out) out="\$2"; shift ;; --cache-dir) cache="\$2"; shift ;; esac
    shift
done
mkdir -p "\$out/repos" "\$cache/clone"
printf 'core\n' > "\$out/layers.txt"
echo "\$out" > "$sb/resolve.out"
if [ -n "\${MR_WAIT:-}" ]; then
    touch "$sb/ready"
    while [ ! -e "$sb/go" ]; do sleep 0.1; done
    exit 0
fi
exit 1
EOF
    chmod +x "$sb/.venv/bin/ros-manifest"
    rc=0; run_mr "$sb" sync >/dev/null 2>&1 || rc=$?
    assert_eq "failed resolve: exit 1" "1" "$rc"
    assert_eq "failed resolve: its directory removed" "no" "$([ -e "$(cat "$sb/resolve.out")" ] && echo yes || echo no)"
    assert_eq "failed resolve: its cache removed" "no" "$([ -e "$(cat "$sb/resolve.out").cache" ] && echo yes || echo no)"
    assert_eq "failed resolve: link unchanged" "$before" "$(readlink "$gen")"
    # Interrupted (TERM) while the resolver runs.
    (cd "$sb" && PATH="$sb/bin:$PATH" COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" MR_WAIT=1 \
        exec "$sb/.agent/scripts/adapter" --project p11 sync >/dev/null 2>&1) &
    apid=$!
    for i in $(seq 1 100); do [ -e "$sb/ready" ] && break; sleep 0.1; done
    kill -TERM "$apid" 2>/dev/null || true
    touch "$sb/go"
    rc=0; wait "$apid" || rc=$?
    assert_eq "interrupted: exit 143" "143" "$rc"
    assert_eq "interrupted: its directory removed" "no" "$([ -e "$(cat "$sb/resolve.out")" ] && echo yes || echo no)"
    assert_eq "interrupted: its cache removed" "no" "$([ -e "$(cat "$sb/resolve.out").cache" ] && echo yes || echo no)"
    assert_eq "interrupted: link unchanged" "$before" "$(readlink "$gen")"
    assert_eq "interrupted: one generated dir left" "1" "$(cd "$sb/projects/p11/configs" && ls -d -- manifest-resolved.gen-* | wc -l | tr -d ' ')"
}

test_mr_source_lock() {
    echo "TEST: manifest route: setup and sync hold a lock on configs/; a second run waits, then refuses with nothing changed; without flock they run unlocked"
    local sb url out rc gen before hpid i tool
    if ! command -v flock >/dev/null 2>&1; then
        echo "  SKIPPED: flock not installed"
        return 0
    fi
    sb="$(make_mr_sandbox dev)"
    url="$(make_mr_remote "$sb" leaf)"
    write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_one
    mr_push "$sb" leaf >/dev/null
    mr_settings "$sb" "source=$url" "source_ref=main"
    # A first setup refused while another run holds the lock: no clone made.
    mkdir -p "$sb/projects/p11/configs"
    ( exec 9>>"$sb/projects/p11/configs/.lock.source"; flock -x 9; touch "$sb/held"
      while [ ! -e "$sb/release" ]; do sleep 0.1; done ) &
    hpid=$!
    for i in $(seq 1 100); do [ -e "$sb/held" ] && break; sleep 0.1; done
    rc=0; out="$(ROS2_COLCON_LOCK_WAIT=1 run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "held, first setup: exit 1" "1" "$rc"
    assert_contains "held, first setup: says so" "another setup or sync of project 'p11' holds its lock $sb/projects/p11/configs/.lock.source (waited 1 s); nothing changed" "$out"
    assert_eq "held, first setup: no clone made" "no" "$([ -e "$sb/projects/p11/configs/source-clone" ] && echo yes || echo no)"
    assert_eq "held, first setup: the resolver not run" "no" "$([ -e "$sb/resolver.log" ] && echo yes || echo no)"
    # A wait that is not a number is said to be one, not taken for a held lock.
    local badwait
    for badwait in abc -1 "1 2" 5s; do
        rc=0; out="$(ROS2_COLCON_LOCK_WAIT="$badwait" run_mr "$sb" setup 2>&1)" || rc=$?
        assert_eq "ROS2_COLCON_LOCK_WAIT='$badwait': exit 1" "1" "$rc"
        assert_contains "ROS2_COLCON_LOCK_WAIT='$badwait': named" "ROS2_COLCON_LOCK_WAIT='$badwait' is not a number of seconds" "$out"
        assert_not_contains "ROS2_COLCON_LOCK_WAIT='$badwait': not a held lock" "holds its lock" "$out"
    done
    touch "$sb/release"
    wait "$hpid" 2>/dev/null || true
    rc=0; run_mr "$sb" setup >/dev/null 2>&1 || rc=$?
    assert_eq "released: setup exit 0" "0" "$rc"
    gen="$(mr_gen "$sb")"
    before="$(readlink "$gen")"
    # A sync refused while held: the link and the clone unchanged.
    write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_two
    mr_push "$sb" leaf >/dev/null
    rm -f "$sb/held" "$sb/release"
    ( exec 9>>"$sb/projects/p11/configs/.lock.source"; flock -x 9; touch "$sb/held"
      while [ ! -e "$sb/release" ]; do sleep 0.1; done ) &
    hpid=$!
    for i in $(seq 1 100); do [ -e "$sb/held" ] && break; sleep 0.1; done
    rc=0; out="$(ROS2_COLCON_LOCK_WAIT=1 run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "held, sync: exit 1" "1" "$rc"
    assert_eq "held, sync: link unchanged" "$before" "$(readlink "$gen")"
    assert_contains "held, sync: the old result kept" "mark_one" "$(cat "$gen/repos/core.repos")"
    touch "$sb/release"
    wait "$hpid" 2>/dev/null || true
    # Two syncs at once, made deterministic: the first is held inside the
    # critical section (its resolver waits on a file); the second must
    # then be waiting in flock (a flock wrapper on its own PATH writes a
    # file as it starts waiting: no machine-wide process search) without
    # having reached the resolver, and proceeds once the first ends.
    local p1 p2 r1=0 r2=0 waiting=no realflock
    realflock="$(command -v flock)"
    mkdir -p "$sb/flockbin"
    printf '%s\n' '#!/usr/bin/env bash' \
        "case \" \$* \" in *\" -w \"*) touch \"$sb/flock-waiting\" ;; esac" \
        "exec \"$realflock\" \"\$@\"" > "$sb/flockbin/flock"
    chmod +x "$sb/flockbin/flock"
    mv "$sb/.venv/bin/ros-manifest" "$sb/.venv/bin/ros-manifest.real"
    printf '%s\n' '#!/usr/bin/env bash' \
        "echo START >> \"$sb/order.log\"" \
        "if [ -e \"$sb/hold\" ] && mkdir \"$sb/held.d\" 2>/dev/null; then" \
        "    touch \"$sb/ready\"" \
        "    while [ ! -e \"$sb/go\" ]; do sleep 0.1; done" \
        'fi' \
        "exec \"$sb/.venv/bin/ros-manifest.real\" \"\$@\"" > "$sb/.venv/bin/ros-manifest"
    chmod +x "$sb/.venv/bin/ros-manifest"
    touch "$sb/hold"
    run_mr "$sb" sync >"$sb/s1.out" 2>&1 & p1=$!
    for i in $(seq 1 100); do [ -e "$sb/ready" ] && break; sleep 0.1; done
    assert_eq "two syncs: the first is inside the critical section" "yes" "$([ -e "$sb/ready" ] && echo yes || echo no)"
    PATH="$sb/flockbin:$PATH" run_mr "$sb" sync >"$sb/s2.out" 2>&1 & p2=$!
    for i in $(seq 1 100); do
        if [ -e "$sb/flock-waiting" ]; then waiting=yes; break; fi
        sleep 0.1
    done
    # Its lock request is made; give it time to (wrongly) get past it.
    sleep 1
    assert_eq "two syncs: the second waits on the lock" "yes" "$waiting"
    assert_eq "two syncs: the second has not reached the resolver" "1" "$(grep -c START "$sb/order.log")"
    assert_eq "two syncs: the second still running" "yes" "$(kill -0 "$p2" 2>/dev/null && echo yes || echo no)"
    touch "$sb/go"
    wait "$p1" || r1=$?
    wait "$p2" || r2=$?
    assert_eq "two syncs: both exit 0" "0 0" "$r1 $r2"
    assert_eq "two syncs: the second resolved after the first" "2" "$(grep -c START "$sb/order.log")"
    assert_contains "two syncs: the second resolved" "source: resolved role 'dev'" "$(cat "$sb/s2.out")"
    assert_contains "two syncs: the new tip resolved" "mark_two" "$(cat "$gen/repos/core.repos")"
    assert_eq "two syncs: one generated dir left" "1" "$(cd "$sb/projects/p11/configs" && ls -d -- manifest-resolved.gen-* | wc -l | tr -d ' ')"
    rm -f "$sb/hold"
    # No flock on PATH: sync runs unlocked.
    mkdir -p "$sb/isolatedbin"
    for tool in bash sh git grep sed awk cut head tail cat mkdir rm mv ln \
        basename dirname printf env ls sort wc tr readlink mktemp stat date touch; do
        command -v "$tool" >/dev/null 2>&1 \
            && ln -sf "$(command -v "$tool")" "$sb/isolatedbin/$tool"
    done
    rc=0; out="$(cd "$sb" && PATH="$sb/bin:$sb/isolatedbin" COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" \
        VCS_MKDIRS=1 "$sb/.agent/scripts/adapter" --project p11 sync 2>&1)" || rc=$?
    assert_eq "no flock: sync exit 0" "0" "$rc"
    assert_contains "no flock: resolved" "source: resolved role 'dev'" "$out"
}

test_mr_pin_fd_not_inherited() {
    echo "TEST: manifest route: vcs, colcon and git started after the pin do not inherit its descriptor (fd 8)"
    local sb rc realgit tool
    if ! command -v flock >/dev/null 2>&1 || [ ! -d /proc/self/fd ]; then
        echo "  SKIPPED: needs flock and /proc"
        return 0
    fi
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml"
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    realgit="$(command -v git)"
    mkdir -p "$sb/fdbin"
    for tool in vcs colcon; do
        printf '%s\n' '#!/usr/bin/env bash' \
            "echo $tool >> \"$sb/ran.log\"" \
            "[ -e /proc/self/fd/8 ] && echo $tool >> \"$sb/fd8.log\"" \
            "exec \"$sb/bin/$tool\" \"\$@\"" > "$sb/fdbin/$tool"
    done
    printf '%s\n' '#!/usr/bin/env bash' \
        "echo git >> \"$sb/ran.log\"" \
        "[ -e /proc/self/fd/8 ] && echo \"git \$*\" >> \"$sb/fd8.log\"" \
        "exec \"$realgit\" \"\$@\"" > "$sb/fdbin/git"
    chmod +x "$sb/fdbin/"*
    rc=0; (cd "$sb" && PATH="$sb/fdbin:$sb/bin:$PATH" COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" \
        VCS_MKDIRS=1 "$sb/.agent/scripts/adapter" --project p11 setup >/dev/null 2>&1) || rc=$?
    assert_eq "setup: exit 0" "0" "$rc"
    git -C "$sb/projects/p11/layers/main/core_ws/src/pkg_a" init --quiet
    rc=0; (cd "$sb" && PATH="$sb/fdbin:$sb/bin:$PATH" COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" \
        VCS_MKDIRS=1 "$sb/.agent/scripts/adapter" --project p11 sync >/dev/null 2>&1) || rc=$?
    assert_eq "sync: exit 0" "0" "$rc"
    rc=0; (cd "$sb" && PATH="$sb/fdbin:$sb/bin:$PATH" COLCON_LOG="$sb/colcon.log" \
        "$sb/.agent/scripts/adapter" --project p11 build >/dev/null 2>&1) || rc=$?
    assert_eq "build: exit 0" "0" "$rc"
    assert_contains "vcs ran" "vcs" "$(cat "$sb/ran.log")"
    assert_contains "colcon ran" "colcon" "$(cat "$sb/ran.log")"
    assert_contains "git ran" "git" "$(cat "$sb/ran.log")"
    assert_eq "none of them got fd 8" "" "$(cat "$sb/fd8.log" 2>/dev/null)"
}

test_mr_swap_failures_and_unguarded_leftovers() {
    echo "TEST: manifest route: a failed mv probe changes nothing; a failed swap without -T/-h says the link is gone; a directory that cannot be locked is said once; without flock at most two generated dirs remain and the replaced one is kept"
    local sb out rc gen cfg before realmv realmktemp realflock tool i prev
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml" mark_one
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    run_mr "$sb" setup >/dev/null 2>&1
    gen="$(mr_gen "$sb")"
    cfg="$sb/projects/p11/configs"
    mkdir -p "$sb/stub"
    # The probe's scratch directory cannot be made: an error, nothing changed.
    realmktemp="$(command -v mktemp)"
    printf '%s\n' '#!/usr/bin/env bash' \
        'case " $* " in *.mv-probe.*) echo "mktemp: simulated failure" >&2; exit 1 ;; esac' \
        "exec \"$realmktemp\" \"\$@\"" > "$sb/stub/mktemp"
    chmod +x "$sb/stub/mktemp"
    before="$(readlink "$gen")"
    write_mr_manifest "$sb/m/manifest.yaml" mark_two
    rc=0; out="$(PATH="$sb/stub:$PATH" run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "probe fails: exit 1" "1" "$rc"
    assert_contains "probe fails: said, nothing changed" "cannot probe how mv renames a link in $cfg (above); nothing changed" "$out"
    assert_eq "probe fails: the link unchanged" "$before" "$(readlink "$gen")"
    assert_contains "probe fails: the old result kept" "mark_one" "$(cat "$gen/repos/core.repos")"
    assert_eq "probe fails: no new generated dir" "1" "$(cd "$cfg" && ls -d -- manifest-resolved.gen-* | wc -l | tr -d ' ')"
    rm -f "$sb/stub/mktemp"
    # An mv with neither -T nor -h whose rename fails after the old link was removed.
    realmv="$(command -v mv)"
    printf '%s\n' '#!/usr/bin/env bash' \
        'case " $* " in *" -T "*|*" -fh "*) echo "mv: illegal option" >&2; exit 64 ;; esac' \
        'case " $* " in *"/manifest-resolved ") echo "mv: simulated failure" >&2; exit 1 ;; esac' \
        "exec \"$realmv\" \"\$@\"" > "$sb/stub/mv"
    chmod +x "$sb/stub/mv"
    rc=0; out="$(PATH="$sb/stub:$PATH" run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "no -T/-h, rename fails: exit 1" "1" "$rc"
    assert_contains "no -T/-h, rename fails: says the link is gone" "there is no resolved manifest link now; run sync again" "$out"
    assert_not_contains "no -T/-h, rename fails: never says nothing changed" "nothing changed" "$out"
    assert_eq "no -T/-h, rename fails: indeed no link" "no" "$([ -L "$gen" ] && echo yes || echo no)"
    rm -f "$sb/stub/mv"
    rc=0; run_mr "$sb" sync >/dev/null 2>&1 || rc=$?
    assert_eq "then: sync puts the link back" "0" "$rc"
    assert_contains "then: the new result live" "mark_two" "$(cat "$gen/repos/core.repos")"
    if command -v flock >/dev/null 2>&1; then
        # flock cannot lock a directory here: nothing removed, said once per run.
        realflock="$(command -v flock)"
        printf '%s\n' '#!/usr/bin/env bash' \
            'case " $* " in *" -E 75 "*) echo "flock: simulated failure" >&2; exit 66 ;; esac' \
            "exec \"$realflock\" \"\$@\"" > "$sb/stub/flock"
        chmod +x "$sb/stub/flock"
        mkdir -p "$cfg/manifest-resolved.gen-Old111" "$cfg/manifest-resolved.gen-Old222"
        rc=0; out="$(PATH="$sb/stub:$PATH" run_mr "$sb" sync 2>&1)" || rc=$?
        assert_eq "no directory lock: sync exit 0" "0" "$rc"
        assert_eq "no directory lock: said once" "1" "$(printf '%s\n' "$out" | grep -c 'WARNING: cannot lock or remove')"
        assert_contains "no directory lock: names the remedy" "remove those the link manifest-resolved does not point at by hand" "$out"
        assert_eq "no directory lock: nothing removed" "yes" "$([ -d "$cfg/manifest-resolved.gen-Old111" ] && [ -d "$cfg/manifest-resolved.gen-Old222" ] && echo yes || echo no)"
        rm -f "$sb/stub/flock"
        run_mr "$sb" sync >/dev/null 2>&1
        assert_eq "with a lock again: the sweep removes them" "1" "$(cd "$cfg" && ls -d -- manifest-resolved.gen-* | wc -l | tr -d ' ')"
    fi
    # No flock at all: the directory just replaced is kept, older ones removed.
    mkdir -p "$sb/isolatedbin"
    for tool in bash sh git grep sed awk cut head tail cat mkdir rm mv ln \
        basename dirname printf env ls sort wc tr readlink mktemp stat date touch; do
        command -v "$tool" >/dev/null 2>&1 \
            && ln -sf "$(command -v "$tool")" "$sb/isolatedbin/$tool"
    done
    for i in 1 2 3; do
        prev="$(readlink "$gen")"
        write_mr_manifest "$sb/m/manifest.yaml" "mark_unlocked_$i"
        rc=0; (cd "$sb" && PATH="$sb/bin:$sb/isolatedbin" COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" \
            VCS_MKDIRS=1 "$sb/.agent/scripts/adapter" --project p11 sync >/dev/null 2>&1) || rc=$?
        assert_eq "no flock, sync $i: exit 0" "0" "$rc"
        assert_eq "no flock, sync $i: the replaced directory kept" "yes" "$([ -f "$cfg/$prev/layers.txt" ] && echo yes || echo no)"
        assert_eq "no flock, sync $i: at most two generated dirs" "2" "$(cd "$cfg" && ls -d -- manifest-resolved.gen-* | wc -l | tr -d ' ')"
        assert_contains "no flock, sync $i: the new result live" "mark_unlocked_$i" "$(cat "$gen/repos/core.repos")"
    done
}

test_mr_swap_interrupt_and_sweep() {
    echo "TEST: manifest route: an interrupt just after the link swap keeps the new directory; BSD mv -h swaps; a killed run's leftovers are swept"
    local sb out rc gen realmv cfg live before
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml" mark_one
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    run_mr "$sb" setup >/dev/null 2>&1
    gen="$(mr_gen "$sb")"
    cfg="$sb/projects/p11/configs"
    realmv="$(command -v mv)"
    mkdir -p "$sb/mvbin"
    # An mv that does the swap, then has its caller sent TERM.
    printf '%s\n' '#!/usr/bin/env bash' \
        "\"$realmv\" \"\$@\"; rc=\$?" \
        'case " $* " in *" -T "*"/manifest-resolved ") kill -TERM "$PPID" ;; esac' \
        'exit $rc' > "$sb/mvbin/mv"
    chmod +x "$sb/mvbin/mv"
    write_mr_manifest "$sb/m/manifest.yaml" mark_two
    rc=0; (cd "$sb" && PATH="$sb/mvbin:$sb/bin:$PATH" "$sb/.agent/scripts/adapter" --project p11 sync >/dev/null 2>&1) || rc=$?
    assert_eq "TERM after the swap: exit 143" "143" "$rc"
    live="$(readlink "$gen")"
    assert_eq "TERM after the swap: the link's target kept" "yes" "$([ -d "$cfg/$live" ] && echo yes || echo no)"
    assert_contains "TERM after the swap: the new result is live" "mark_two" "$(cat "$gen/repos/core.repos")"
    # The previous directory is a leftover; the next sync sweeps it.
    rc=0; run_mr "$sb" sync >/dev/null 2>&1 || rc=$?
    assert_eq "after TERM: sync exit 0" "0" "$rc"
    assert_eq "after TERM: one generated dir left" "1" "$(cd "$cfg" && ls -d -- manifest-resolved.gen-* | wc -l | tr -d ' ')"
    # A BSD mv: no -T, but -h renames over the link.
    printf '%s\n' '#!/usr/bin/env bash' \
        'case " $* " in' \
        '    *" -T "*) echo "mv: illegal option -- T" >&2; exit 64 ;;' \
        "    *\" -fh \"*) shift; echo BSD_MV_H >> \"$sb/mv.log\"; exec \"$realmv\" -fT \"\$@\" ;;" \
        'esac' \
        "exec \"$realmv\" \"\$@\"" > "$sb/mvbin/mv"
    write_mr_manifest "$sb/m/manifest.yaml" mark_three
    rc=0; (cd "$sb" && PATH="$sb/mvbin:$sb/bin:$PATH" "$sb/.agent/scripts/adapter" --project p11 sync >/dev/null 2>&1) || rc=$?
    assert_eq "BSD mv: sync exit 0" "0" "$rc"
    assert_contains "BSD mv: mv -fh used" "BSD_MV_H" "$(cat "$sb/mv.log" 2>/dev/null)"
    assert_eq "BSD mv: still a link" "yes" "$([ -L "$gen" ] && echo yes || echo no)"
    assert_contains "BSD mv: the new result is live" "mark_three" "$(cat "$gen/repos/core.repos")"
    # GNU mv whose -T fails on the real swap (the probe succeeds): an
    # error, and the live link is never removed.
    printf '%s\n' '#!/usr/bin/env bash' \
        'case " $* " in *" -T "*"/manifest-resolved ") echo "mv: simulated failure" >&2; exit 1 ;; esac' \
        "exec \"$realmv\" \"\$@\"" > "$sb/mvbin/mv"
    before="$(readlink "$gen")"
    write_mr_manifest "$sb/m/manifest.yaml" mark_four
    rc=0; out="$(cd "$sb" && PATH="$sb/mvbin:$sb/bin:$PATH" "$sb/.agent/scripts/adapter" --project p11 sync 2>&1)" || rc=$?
    assert_eq "mv -T fails: exit 1" "1" "$rc"
    assert_contains "mv -T fails: said" "cannot rename the new link over $gen (mv -T failed, above); nothing changed" "$out"
    assert_eq "mv -T fails: the live link unchanged" "$before" "$(readlink "$gen")"
    assert_contains "mv -T fails: the previous result kept" "mark_three" "$(cat "$gen/repos/core.repos")"
    assert_eq "mv -T fails: no new generated dir left" "1" "$(cd "$cfg" && ls -d -- manifest-resolved.gen-* | wc -l | tr -d ' ')"
    assert_eq "mv -T fails: no probe dir left" "" "$(cd "$cfg" && ls -d -- .mv-probe.* 2>/dev/null || true)"
    write_mr_manifest "$sb/m/manifest.yaml" mark_three
    run_mr "$sb" sync >/dev/null 2>&1
    # What a SIGKILLed run leaves: a directory, a cache and a link.
    mkdir -p "$cfg/manifest-resolved.gen-Ab12Cd/repos" "$cfg/manifest-resolved.gen-Ab12Cd.cache/clone"
    ln -s manifest-resolved.gen-Ab12Cd "$cfg/manifest-resolved.gen-Ab12Cd.link"
    mkdir -p "$cfg/manifest-resolved.notmine-keep"
    # A directory a person moved aside, with six letters after the dot (the
    # adapter's own "move it aside" error invites this).
    mkdir -p "$cfg/manifest-resolved.backup"
    echo keep > "$cfg/manifest-resolved.backup/notes.txt"
    rc=0; run_mr "$sb" sync >/dev/null 2>&1 || rc=$?
    assert_eq "leftovers: sync exit 0" "0" "$rc"
    assert_eq "leftovers: swept" "" "$(cd "$cfg" && ls -d -- manifest-resolved.gen-Ab12Cd* 2>/dev/null || true)"
    assert_eq "leftovers: a name the adapter never makes is kept" "yes" "$([ -d "$cfg/manifest-resolved.notmine-keep" ] && echo yes || echo no)"
    assert_eq "leftovers: a moved-aside manifest-resolved.backup and its file kept" "keep" "$(cat "$cfg/manifest-resolved.backup/notes.txt" 2>/dev/null)"
    assert_contains "leftovers: the live result intact" "mark_three" "$(cat "$gen/repos/core.repos")"
    # A directory where the link belongs: the error suggests a name the
    # adapter never removes.
    rm -f "$gen"
    mkdir -p "$gen"
    rc=0; out="$(run_mr "$sb" sync 2>&1)" || rc=$?
    assert_eq "a directory at the link: exit 1" "1" "$rc"
    assert_contains "a directory at the link: suggests a safe name" "move it aside (to manifest-resolved.old, say: the adapter removes only the manifest-resolved.gen-* names it makes)" "$out"
}

test_mr_reader_pinned_to_one_result() {
    echo "TEST: manifest route: a run reads one generated directory throughout; a sync meanwhile never removes it under the run; a later sweep does"
    local sb out rc gen cfg pa dir_a dir_b
    if ! command -v flock >/dev/null 2>&1; then
        echo "  SKIPPED: flock not installed"
        return 0
    fi
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml"
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    gen="$(mr_gen "$sb")"
    cfg="$sb/projects/p11/configs"
    # A vcs that holds the first import (layer core) until released.
    mkdir -p "$sb/waitbin"
    printf '%s\n' '#!/usr/bin/env bash' \
        "if [ -e \"$sb/vhold\" ] && mkdir \"$sb/vheld.d\" 2>/dev/null; then" \
        "    touch \"$sb/vready\"" \
        "    while [ ! -e \"$sb/vgo\" ]; do sleep 0.1; done" \
        'fi' \
        "exec \"$sb/bin/vcs\" \"\$@\"" > "$sb/waitbin/vcs"
    chmod +x "$sb/waitbin/vcs"
    touch "$sb/vhold"
    (cd "$sb" && PATH="$sb/waitbin:$sb/bin:$PATH" COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" \
        VCS_MKDIRS=1 "$sb/.agent/scripts/adapter" --project p11 setup >"$sb/a.out" 2>&1) & pa=$!
    for i in $(seq 1 100); do [ -e "$sb/vready" ] && break; sleep 0.1; done
    assert_eq "setup A: held in its first import" "yes" "$([ -e "$sb/vready" ] && echo yes || echo no)"
    dir_a="$(readlink "$gen")"
    # Meanwhile the manifest changes (pkg_c, layer extra, v1 -> v2) and a sync swaps the link.
    sed -i 's/ref: v1/ref: v2/' "$sb/m/manifest.yaml"
    rc=0; run_mr "$sb" sync >/dev/null 2>&1 || rc=$?
    assert_eq "sync B: exit 0" "0" "$rc"
    dir_b="$(readlink "$gen")"
    assert_eq "sync B: the link swapped" "yes" "$([ "$dir_a" != "$dir_b" ] && echo yes || echo no)"
    assert_contains "sync B: the new result has v2" "version: v2" "$(cat "$gen/repos/extra.repos")"
    assert_eq "sync B: A's directory kept while A reads it" "yes" "$([ -f "$cfg/$dir_a/layers.txt" ] && echo yes || echo no)"
    touch "$sb/vgo"
    rc=0; wait "$pa" || rc=$?
    assert_eq "setup A: exit 0" "0" "$rc"
    assert_contains "setup A: layer extra imported from its own result (v1)" "version: v1" "$(cat "$sb/projects/p11/layers/main/extra_ws/src/.vcs_input")"
    assert_not_contains "setup A: not from the newer result (v2)" "version: v2" "$(cat "$sb/projects/p11/layers/main/extra_ws/src/.vcs_input")"
    # Once A has ended, the next sync sweeps A's directory.
    rc=0; run_mr "$sb" sync >/dev/null 2>&1 || rc=$?
    assert_eq "sync C: exit 0" "0" "$rc"
    assert_eq "sync C: A's directory swept" "no" "$([ -e "$cfg/$dir_a" ] && echo yes || echo no)"
    assert_eq "sync C: one generated dir left" "1" "$(cd "$cfg" && ls -d -- manifest-resolved.gen-* | wc -l | tr -d ' ')"
    assert_contains "sync C: the live result intact" "version: v2" "$(cat "$gen/repos/extra.repos")"
}

test_mr_lock_fd_not_inherited() {
    echo "TEST: manifest route: git and the resolver do not inherit the lock's descriptor, and the lock is held while they run"
    local sb url rc realgit lock
    if ! command -v flock >/dev/null 2>&1 || [ ! -d /proc/self/fd ]; then
        echo "  SKIPPED: needs flock and /proc"
        return 0
    fi
    sb="$(make_mr_sandbox dev)"
    url="$(make_mr_remote "$sb" leaf)"
    write_mr_manifest "$sb/mwork/leaf/manifest.yaml" mark_one
    mr_push "$sb" leaf >/dev/null
    mr_settings "$sb" "source=$url" "source_ref=main"
    lock="$sb/projects/p11/configs/.lock.source"
    realgit="$(command -v git)"
    mkdir -p "$sb/fdbin"
    printf '%s\n' '#!/usr/bin/env bash' \
        "echo \"git \$*\" >> \"$sb/git.log\"" \
        "[ -e /proc/self/fd/9 ] && echo \"git \$1 \$2 \$3\" >> \"$sb/fd9.log\"" \
        "exec \"$realgit\" \"\$@\"" > "$sb/fdbin/git"
    chmod +x "$sb/fdbin/git"
    # The resolver: says whether it got fd 9 and whether the lock is held.
    mv "$sb/.venv/bin/ros-manifest" "$sb/.venv/bin/ros-manifest.real"
    printf '%s\n' '#!/usr/bin/env bash' \
        "[ -e /proc/self/fd/9 ] && echo resolver >> \"$sb/fd9.log\"" \
        "flock -n \"$lock\" true && echo NOT_HELD >> \"$sb/held.log\"" \
        "exec \"$sb/.venv/bin/ros-manifest.real\" \"\$@\"" > "$sb/.venv/bin/ros-manifest"
    chmod +x "$sb/.venv/bin/ros-manifest"
    rc=0; (cd "$sb" && PATH="$sb/fdbin:$sb/bin:$PATH" COLCON_LOG="$sb/colcon.log" VCS_LOG="$sb/vcs.log" \
        VCS_MKDIRS=1 "$sb/.agent/scripts/adapter" --project p11 setup >/dev/null 2>&1) || rc=$?
    assert_eq "setup: exit 0" "0" "$rc"
    assert_contains "the git wrapper saw the fetch" "fetch --quiet --prune --prune-tags" "$(cat "$sb/git.log" 2>/dev/null)"
    assert_contains "the resolver ran" "RESOLVER_RAN:resolve" "$(cat "$sb/resolver.log" 2>/dev/null)"
    assert_eq "no git or resolver call got fd 9" "" "$(cat "$sb/fd9.log" 2>/dev/null)"
    assert_eq "the lock held while the resolver ran" "" "$(cat "$sb/held.log" 2>/dev/null)"
}

test_mr_preflight_before_any_fetch() {
    echo "TEST: manifest route: missing vcs, role= or distro= is reported before any remote is contacted"
    local sb out rc tool url
    sb="$(make_mr_sandbox dev)"
    url="file://$sb/mremote/never.git"
    mr_settings "$sb" "source=$url" "source_ref=main"
    mkdir -p "$sb/isolatedbin"
    for tool in bash sh git grep sed awk cut head tail cat mkdir rm mv ln \
        basename dirname printf env ls sort wc tr readlink mktemp stat; do
        command -v "$tool" >/dev/null 2>&1 \
            && ln -sf "$(command -v "$tool")" "$sb/isolatedbin/$tool"
    done
    rc=0; out="$(cd "$sb" && PATH="$sb/isolatedbin" "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "no vcs: exit 1" "1" "$rc"
    assert_contains "no vcs: named" "'vcs' (vcstool) not found" "$out"
    assert_not_contains "no vcs: the source was not contacted" "cloning" "$out"
    assert_eq "no vcs: no clone made" "no" "$([ -e "$sb/projects/p11/configs/source-clone" ] && echo yes || echo no)"

    sed -i 's/ role=dev//' "$sb/.agent/projects.local"
    rc=0; out="$(run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "no role=: exit 1" "1" "$rc"
    assert_contains "no role=: names the field" "which needs role=<name> on its registry line" "$out"
    assert_contains "no role=: edit and sync" "Edit the line for 'p11' in .agent/projects.local to add role=<name> (registration does not change an existing line), then run: .agent/scripts/adapter --project p11 sync" "$out"
    assert_not_contains "no role=: not contacted" "cloning" "$out"

    sed -i 's/ distro=fakefox/ role=dev/' "$sb/.agent/projects.local"
    rc=0; out="$(run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "no distro=: exit 1" "1" "$rc"
    assert_contains "no distro=: names the field" "which needs distro=<name> on its registry line" "$out"
    assert_not_contains "no distro=: not contacted" "cloning" "$out"
    # A legacy ROS_DISTRO is not accepted on this route.
    echo "ROS_DISTRO=fakefox" >> "$sb/.agent/projects.d/p11.sh"
    rc=0; out="$(run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "legacy ROS_DISTRO does not stand in for distro=: exit 1" "1" "$rc"
}

test_mr_one_source_only() {
    echo "TEST: manifest route: source beside any other bootstrap source is a hard error naming it"
    local sb out rc
    sb="$(make_mr_sandbox dev)"
    write_mr_manifest "$sb/m/manifest.yaml"
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    rc=0; out="$(BOOTSTRAP_URL=https://example.invalid/b.yaml run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "BOOTSTRAP_URL: exit 1" "1" "$rc"
    assert_contains "BOOTSTRAP_URL: one source only" "a project has one source only, never a silent choice" "$out"
    assert_contains "BOOTSTRAP_URL: named" "BOOTSTRAP_URL=https://example.invalid/b.yaml in the environment" "$out"
    assert_contains "names the way back" "unset p11 source source_ref source_path" "$out"

    echo 'MANIFEST_BOOTSTRAP_URL="https://example.invalid/legacy.yaml"' >> "$sb/.agent/projects.d/p11.sh"
    rc=0; out="$(run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "legacy MANIFEST_BOOTSTRAP_URL: exit 1" "1" "$rc"
    assert_contains "legacy MANIFEST_BOOTSTRAP_URL: names the file" "MANIFEST_BOOTSTRAP_URL=https://example.invalid/legacy.yaml in $sb/.agent/projects.d/p11.sh (the legacy per-project config): remove that line" "$out"
    sed -i '/MANIFEST_BOOTSTRAP_URL/d' "$sb/.agent/projects.d/p11.sh"

    # A good setup first, so validate reaches the single-source check.
    rc=0; run_mr "$sb" setup >/dev/null 2>&1 || rc=$?
    assert_eq "one source: setup exit 0" "0" "$rc"
    rc=0; out="$(run_mr "$sb" validate 2>&1)" || rc=$?
    assert_eq "one source: validate exit 0" "0" "$rc"
    echo "https://example.invalid/b.yaml" > "$sb/projects/p11/configs/project_bootstrap.url"
    rc=0; out="$(run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "project_bootstrap.url: exit 1" "1" "$rc"
    assert_contains "project_bootstrap.url: names the file and its path" "the file $sb/projects/p11/configs/project_bootstrap.url (in the project's root; it may be tracked in the project's own repository): remove it" "$out"
    rc=0; out="$(run_mr "$sb" validate 2>&1)" || rc=$?
    assert_eq "validate also refuses it: exit 1" "1" "$rc"
    assert_contains "validate also refuses it: the single-source check" "❌ ERROR: project 'p11' sets source=$sb/m/manifest.yaml (the manifest route), and another bootstrap source was found" "$out"
    assert_contains "validate also refuses it: names the file" "the file $sb/projects/p11/configs/project_bootstrap.url" "$out"
    rm -f "$sb/projects/p11/configs/project_bootstrap.url"

    mr_settings "$sb" "source=$sb/m/manifest.yaml" "bootstrap_url=https://example.invalid/b.yaml"
    rc=0; out="$(run_mr "$sb" setup 2>&1)" || rc=$?
    assert_eq "bootstrap_url in the settings file: exit 1" "1" "$rc"
    assert_contains "bootstrap_url in the settings file: refused by the parser" "source and bootstrap_url are both set" "$out"

    # A configs/manifest left from an earlier bootstrap is ignored.
    mr_settings "$sb" "source=$sb/m/manifest.yaml"
    mkdir -p "$sb/projects/p11/configs/manifest/repos"
    printf 'old\n' > "$sb/projects/p11/configs/manifest/layers.txt"
    rc=0; run_mr "$sb" setup >/dev/null 2>&1 || rc=$?
    assert_eq "an old configs/manifest: setup exit 0" "0" "$rc"
    assert_not_contains "an old configs/manifest: its layer not imported" "old_ws" "$(cat "$sb/vcs.log")"
}

test_bootstrap_no_url_names_source() {
    echo "TEST: bootstrap route: the no-URL error also names source= (#436)"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_toolchain_stubs "$sb"
    make_fresh_project "$sb" >/dev/null
    out="$(run_adapter "$sb" setup 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names source=" "project_setting.sh set p11 source=<git URL or absolute path>" "$out"
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
test_bootstrap_no_url_names_source
mr_test test_mr_wrapper_runs_this_checkouts_resolver
mr_test test_mr_setup_from_path_source
mr_test test_mr_url_source_branch_tag_commit
mr_test test_mr_clone_follows_remote
mr_test test_mr_clone_with_insteadof_rule
mr_test test_mr_clone_refused_when_modified
mr_test test_mr_clone_removed_only_when_created_here
mr_test test_mr_stale_extends_base
mr_test test_mr_offline_keeps_previous
mr_test test_mr_role_and_distro_changes
mr_test test_mr_sync_names_a_new_layer
mr_test test_mr_validate_link_missing_and_path_changed
mr_test test_mr_layer_failures
mr_test test_mr_resolver_failures
mr_test test_mr_interrupt_cleans_up
mr_test test_mr_swap_interrupt_and_sweep
mr_test test_mr_swap_failures_and_unguarded_leftovers
mr_test test_mr_pin_fd_not_inherited
mr_test test_mr_preflight_before_any_fetch
mr_test test_mr_source_lock
mr_test test_mr_lock_fd_not_inherited
mr_test test_mr_reader_pinned_to_one_result
mr_test test_mr_one_source_only

echo ""
if [ "$MR_SKIPPED" -gt 0 ]; then
    echo "=== SKIPPED: $MR_SKIPPED manifest-route test(s): PyYAML not importable with $MR_SRC ==="
fi
echo "=== Results: ${PASS} passed, ${FAIL} failed, ${MR_SKIPPED} skipped ==="
[[ $FAIL -eq 0 ]]
