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

SANDBOXES=()
cleanup() {
    local sb
    for sb in ${SANDBOXES[@]+"${SANDBOXES[@]}"}; do
        rm -rf "$sb"
    done
}
trap cleanup EXIT

# Base sandbox: dispatcher + registry lib + both adapter types.
make_sandbox() {
    local sb
    sb="$(mktemp -d)"
    SANDBOXES+=("$sb")
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
        "$sb/.agent/scripts/adapter" --project p11 "$@")
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
    cp "$REAL_ROOT/.agent/scripts/_issue_helpers.sh" "$sb/.agent/scripts/"
    mkdir -p "$sb/stubbin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/gh"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"
    chmod +x "$sb/stubbin/gh" "$sb/stubbin/git-bug"
    git -C "$sb" init --quiet
    git -C "$sb" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
    echo "$sb"
}

# A real (committed, no origin fetch needed since it's all local) git repo
# for a package under a layer's src/, standing in for a real package
# checkout post-`adapter setup`.
make_committed_pkg_repo() {
    local proj="$1" layer="$2" name="$3"
    local dir="$proj/layers/main/${layer}_ws/src/$name"
    mkdir -p "$dir"
    git -C "$dir" init --quiet
    echo "$name" > "$dir/README.md"
    git -C "$dir" add README.md
    git -C "$dir" -c user.name=t -c user.email=t@t commit --quiet -m init
    git -C "$dir" remote add origin "git@github.com:owner/${name}.git"
    git -C "$dir" branch -m main 2>/dev/null || true
}

run_worktree_create() {
    local sb="$1"
    shift
    (cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_create.sh" "$@")
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
    wt="$sb/worktrees/project/p11/issue-p11-owner-pkg_a-111"
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
    assert_eq "sourcing env.sh under set -e with no install present still exits 0" \
        "ok" "$(bash -c "set -e; source '$wt/env.sh'; echo ok" 2>&1)"
    assert_contains "enter banner uses the qualified issue and --project" \
        "worktree_enter.sh --issue owner/pkg_a#111 --type project --project p11" "$out"
    assert_contains "remove banner uses the qualified issue and --project" \
        "worktree_remove.sh --issue owner/pkg_a#111 --type project --project p11" "$out"
    assert_not_contains "banner never prints the bare number for a package worktree" \
        "--issue 111 --type project" "$out"
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
    wt="$sb/worktrees/project/p11/issue-p11-owner-pkg_a-222"
    assert_eq "no aggregate dir left behind" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "pkg_a's worktree removed from the origin repo" \
        "" "$(git -C "$proj/layers/main/l1_ws/src/pkg_a" worktree list --porcelain \
            | grep -A2 "worktree $wt" || true)"
    assert_contains "captured stderr surfaced" "not a git repository" "$out"
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
    wt="$sb/worktrees/project/p11/issue-p11-owner-pkg_a-333"
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
    wt="$sb/worktrees/project/p11/issue-p11-owner-pkg_a-333"
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
    wt="$sb/worktrees/project/p11/issue-p11-owner-pkg_a-444"
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
    wt_a="$sb/worktrees/project/p11/issue-p11-owner-pkg_a-555"
    wt_c="$sb/worktrees/project/p11/issue-p11-owner-pkg_c-555"
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
        "$sb/.agent/scripts/worktree_create.sh" --issue rolker/ros2_network_monitor#27 \
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
    assert_contains "ros2_colcon complete" "ros2_colcon: all 12 verbs implemented" "$out"
    assert_contains "single_project still complete" "single_project: all 12 verbs implemented" "$out"
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
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "fetched the env URL" "Fetching bootstrap config from $url" "$out"
    assert_eq "manifest present" "true" "$([ -f "$proj/configs/manifest/layers.txt" ] && echo true || echo false)"
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
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "traversal config_path exits nonzero" "1" "$rc"
    assert_contains "names config_path" "invalid 'config_path'" "$out"
    assert_eq "nothing cloned" "false" "$([ -e "$proj/configs/manifest_repo" ] && echo true || echo false)"
    printf 'git_url: file://%s/remote/manifest_repo\nbranch: fakefox\nlayer: ../x\n' "$sb" \
        > "$sb/remote/bootstrap.yaml"
    rc=0
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "config..d exits 0" "0" "$rc"
    assert_eq "symlink targets config..d" \
        "manifest_repo/manifest_repo/config..d" "$(readlink "$proj/configs/manifest")"
    # A real '..' component nested inside the path is still rejected.
    printf 'git_url: file://%s/remote/manifest_repo\nbranch: fakefox\nconfig_path: config/../../etc\n' "$sb" \
        > "$sb/remote/bootstrap.yaml"
    rm -rf "$proj/configs"
    rc=0
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
    assert_eq "mismatched origin exits nonzero" "1" "$rc"
    assert_contains "names both repos" "is a checkout of file:///elsewhere/other_manifest.git, not file://$sb/remote/manifest_repo" "$out"
    assert_eq "no symlink created" "false" "$([ -e "$proj/configs/manifest" ] && echo true || echo false)"
    # A non-git directory at the clone path is refused too.
    rm -rf "$clone_dir" && mkdir -p "$clone_dir"
    rc=0
    out="$(cd "$sb" && PATH="$sb/bin:$PATH" VCS_LOG="$sb/vcs.log" BOOTSTRAP_URL="$url" \
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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
        "$sb/.agent/scripts/adapter" --project p11 setup 2>&1)" || rc=$?
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

# ---- Run all tests ----
echo "=== ros2_colcon adapter tests ==="
echo ""

test_validator_accepts_ros2_colcon
test_worktree_create_package_success
test_worktree_create_rolls_back_on_second_repo_failure
test_worktree_create_rollback_on_worktree_env_failure
test_worktree_remove_multi_package_dirty_refuses_all
test_worktree_list_json_reports_package_worktree
test_worktree_enter_disambiguates_by_qualified_issue
test_worktree_create_issue_lookup_uses_qualified_repo
test_distro_from_bootstrap_yaml
test_distro_from_project_config
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

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
