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

# ---- Contract & validator ----

test_validator_accepts_ros2_colcon() {
    echo "TEST: validate_adapter passes with the ros2_colcon type present"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "ros2_colcon complete" "ros2_colcon: all 10 verbs implemented" "$out"
    assert_contains "single_project still complete" "single_project: all 10 verbs implemented" "$out"
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
test_distro_from_bootstrap_yaml
test_distro_from_project_config
test_distro_unresolvable_fails
test_missing_underlay_fails
test_missing_manifest_fails
test_env_chain_order
test_setup_imports_each_layer
test_setup_optional_layer_failure_tolerated
test_setup_required_layer_failure_aborts
test_setup_requires_vcs
test_build_layer_order_and_cascade
test_build_skips_layer_without_src
test_build_stops_on_failure
test_test_continues_past_failures
test_repos_lists_packages_across_layers
test_repos_unconfigured_fails
test_scope_for_pr_nested_package
test_sync_pull_skip_fetch
test_validate_passes_matching_checkout
test_validate_flags_missing_repo
test_validate_flags_unsetup_layer
test_install_noop_by_default
test_cwd_discovery_resolves_colcon_project

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
