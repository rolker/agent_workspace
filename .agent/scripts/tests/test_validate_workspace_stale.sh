#!/usr/bin/env bash
# Tests for the retired-shape report (issue #265 part 4): registry_stale_report
# and registry_stale_settings_lines in _project_registry.sh, shown by
# validate_workspace.py after its results and by dashboard.sh as warnings.
# Nothing reads <ws>/project, an unregistered <ws>/projects/<dir>, the
# worktree fallbacks, a projects.d/<name>.sh or the shared
# .agent/project_config.sh any more; the report names what is still on disk
# and what to do, and never changes an exit status.
#
# Every fixture is a synthetic sandbox workspace (mktemp) with copies of the
# real scripts; no test touches the real workspace or its registry.
#
# Run: bash .agent/scripts/tests/test_validate_workspace_stale.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
has() {  # <label> <needle> <haystack>
    if [[ "$3" == *"$2"* ]]; then pass "$1"; else fail "$1"; echo "    needle:   $2"; echo "    haystack: $3"; fi
}
hasnt() {  # <label> <needle> <haystack>
    if [[ "$3" != *"$2"* ]]; then pass "$1"; else fail "$1"; echo "    unexpected: $2"; echo "    haystack:   $3"; fi
}

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# A sandbox workspace with the registry helper, the validator, the
# dashboard's dependencies and both project types.
make_ws() {
    local sb
    sb="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$sb/.agent/scripts/lib" "$sb/.agent/project_types" "$sb/.agent/projects.d"
    cp "$REAL_ROOT/.agent/scripts/_project_registry.sh" "$REAL_ROOT/.agent/scripts/validate_workspace.py" \
        "$REAL_ROOT/.agent/scripts/adapter" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/lib/"*.py "$sb/.agent/scripts/lib/"
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$REAL_ROOT/.agent/project_types/ros2_colcon" \
        "$sb/.agent/project_types/"
    : > "$sb/.agent/projects.local"
    echo "$sb"
}
git_repo() { mkdir -p "$1" && git -C "$1" init -q; }
report() { bash -c 'source "$1/.agent/scripts/_project_registry.sh" && registry_stale_report "$1"' _ "$1"; }
validate() { python3 "$1/.agent/scripts/validate_workspace.py" 2>&1; }

echo "TEST: a clean machine reports nothing"
sb="$(make_ws)"
git_repo "$sb/roots/alpha"
echo "alpha single_project $sb/roots/alpha" > "$sb/.agent/projects.local"
out="$(report "$sb")"
[[ -z "$out" ]] && pass "no retired shape: empty report" || fail "unexpected report: $out"
out="$(validate "$sb")"; rc=$?
[[ "$rc" -eq 0 ]] && pass "validate exit 0" || fail "validate rc=$rc"
hasnt "validate prints no retired-shape block" "Retired shapes" "$out"

echo "TEST: project/ — a link to a registered root, an unregistered checkout, a registered root at that path"
sb="$(make_ws)"
git_repo "$sb/roots/alpha"
echo "alpha single_project $sb/roots/alpha" > "$sb/.agent/projects.local"
ln -s "$sb/roots/alpha" "$sb/project"
out="$(report "$sb")"
has "a link to a registered root: says so and how to remove it" \
    "project is a link to registered project 'alpha'; nothing reads the link any more: remove it (rm $sb/project)" "$out"
rm "$sb/project"
git_repo "$sb/project"
out="$(report "$sb")"
has "an unregistered checkout: register it or remove it" \
    "project exists and is not registered; nothing reads it any more: register it with .agent/scripts/register_project.sh <path>, or remove it" "$out"
echo "proj single_project $sb/project" >> "$sb/.agent/projects.local"
out="$(report "$sb")"
hasnt "a root registered at <ws>/project itself is silent (never 'remove it')" "project" "$out"

echo "TEST: worktrees under the retired locations are named; empty ones are not"
sb="$(make_ws)"
mkdir -p "$sb/worktrees/project" "$sb/.workspace-worktrees"
out="$(report "$sb")"
[[ -z "$out" ]] && pass "empty retired directories: silent" || fail "unexpected: $out"
mkdir -p "$sb/worktrees/project/alpha/issue-alpha-1" "$sb/.workspace-worktrees/issue-workspace-2"
out="$(report "$sb")"
has "worktrees/project/ named" "worktrees/project/ holds worktrees that are no longer found: remove each with git -C <its repository> worktree remove <path>" "$out"
has ".workspace-worktrees/ named" ".workspace-worktrees/ holds worktrees that are no longer found" "$out"

echo "TEST: projects/ — an unowned directory is named; a registered root and a parent of one are silent (ADR-0016 decision 1)"
sb="$(make_ws)"
git_repo "$sb/projects/inner"
mkdir -p "$sb/projects/group/one" "$sb/projects/orphan"
git -C "$sb/projects/group/one" init -q
printf 'inner single_project projects/inner\ngroup-one single_project projects/group/one\n' > "$sb/.agent/projects.local"
out="$(report "$sb")"
has "the unowned directory" "projects/orphan is not registered; nothing reads it any more: register it with .agent/scripts/register_project.sh <path>, or remove it" "$out"
hasnt "a registered root under projects/ is silent" "projects/inner" "$out"
hasnt "a directory holding a registered root is silent" "projects/group" "$out"
out="$(validate "$sb")"; rc=$?
[[ "$rc" -eq 0 ]] && pass "validate: exit 0 with warnings" || fail "validate rc=$rc out=${out:0:400}"
has "validate prints the warning after the results" "Retired shapes still on disk" "$out"
[[ "$out" == *"PASSED"*"Retired shapes"*"projects/orphan"* ]] && pass "the block follows the results" || fail "order: $out"

echo "TEST: a projects.d/<name>.sh — per key, with the right remedy (plan review N3, S8)"
sb="$(make_ws)"
git_repo "$sb/roots/alpha"
mkdir -p "$sb/roots/inst"
printf 'alpha single_project %s\ninst ros2_colcon %s\n' "$sb/roots/alpha" "$sb/roots/inst" > "$sb/.agent/projects.local"
cat > "$sb/.agent/projects.d/alpha.sh" <<'EOF'
BUILD_CMD="make"
TEST_CMD="make test"
INSTALL_CMD="make install"
export SDK_ROOT=/opt/sdk
EOF
printf 'build=make\n' > "$sb/.agent/projects.d/alpha"
cat > "$sb/.agent/projects.d/inst.sh" <<'EOF'
BUILD_CMD="colcon build"
ROS_DISTRO="fakefox"
ROS_ROOT_DIR="/srv/ros"
MANIFEST_BOOTSTRAP_URL="https://example.invalid/b.yaml"
EOF
out="$(report "$sb")"
hasnt "a key the settings file has is not reported" "sets BUILD_CMD=\"make\", which" "$out"
has "TEST_CMD: project_setting.sh set" ".agent/projects.d/alpha.sh sets TEST_CMD=\"make test\", which .agent/projects.d/alpha lacks and nothing reads any more: .agent/scripts/project_setting.sh set alpha test=<command> (or test=none)" "$out"
has "INSTALL_CMD: project_setting.sh set" ".agent/projects.d/alpha.sh sets INSTALL_CMD=\"make install\", which .agent/projects.d/alpha lacks" "$out"
has "an exported variable: move it into the script (S8)" ".agent/projects.d/alpha.sh sets or exports SDK_ROOT, which no command gets any more" "$out"
hasnt "ros2_colcon: BUILD_CMD is a key the type never reads, not reported" "inst.sh sets BUILD_CMD" "$out"
has "ROS_DISTRO: distro= on the registry line, by hand" ".agent/projects.d/inst.sh sets ROS_DISTRO=\"fakefox\", which nothing reads any more: if inst's manifest declares no distro, add distro=fakefox to its line in .agent/projects.local by hand" "$out"
hasnt "ROS_DISTRO: never project_setting.sh" "set inst distro" "$out"
has "ROS_ROOT_DIR: the environment" ".agent/projects.d/inst.sh sets ROS_ROOT_DIR=\"/srv/ros\", which is no longer read from a file: export ROS_ROOT_DIR=/srv/ros in the environment that runs the adapter" "$out"
has "MANIFEST_BOOTSTRAP_URL: bootstrap_url" ".agent/projects.d/inst.sh sets MANIFEST_BOOTSTRAP_URL=\"https://example.invalid/b.yaml\", which .agent/projects.d/inst lacks and nothing reads any more: .agent/scripts/project_setting.sh set inst bootstrap_url=<url>" "$out"
sed -i "s|^inst ros2_colcon .*|inst ros2_colcon $sb/roots/inst distro=fakefox|" "$sb/.agent/projects.local"
out="$(report "$sb")"
hasnt "ROS_DISTRO with distro= on the line: not reported" "sets ROS_DISTRO" "$out"
printf 'build=make\ntest=make test\ninstall=none\n' > "$sb/.agent/projects.d/alpha"
printf 'BUILD_CMD="make"\n' > "$sb/.agent/projects.d/alpha.sh"
out="$(report "$sb")"
has "nothing left to move: delete it" ".agent/projects.d/alpha.sh is no longer read and holds nothing left to move: delete it" "$out"
printf 'BUILD_CMD="x"\n' > "$sb/.agent/projects.d/ghost.sh"
out="$(report "$sb")"
has "a .sh of no registered project" ".agent/projects.d/ghost.sh belongs to no registered project and nothing reads it any more: delete it" "$out"

echo "TEST: the shared project_config.sh — per project it applied to, per key (plan review N3)"
sb="$(make_ws)"
git_repo "$sb/roots/alpha"
git_repo "$sb/roots/beta"
mkdir -p "$sb/roots/inst"
printf 'alpha single_project %s\nbeta single_project %s\ninst ros2_colcon %s\n' \
    "$sb/roots/alpha" "$sb/roots/beta" "$sb/roots/inst" > "$sb/.agent/projects.local"
printf 'BUILD_CMD="make"\nINSTALL_CMD="cmake --install build"\n' > "$sb/.agent/project_config.sh"
printf 'build=make\ntest=make test\n' > "$sb/.agent/projects.d/alpha"
printf 'build=make\ntest=make test\ninstall=none\n' > "$sb/.agent/projects.d/beta"
printf 'BUILD_CMD="colcon build"\n' > "$sb/.agent/projects.d/inst.sh"
out="$(report "$sb")"
has "the project lacking install: named with its remedy" ".agent/project_config.sh sets INSTALL_CMD=\"cmake --install build\", which .agent/projects.d/alpha lacks and nothing reads any more: .agent/scripts/project_setting.sh set alpha install=<command> (or install=none)" "$out"
hasnt "a project with install set: nothing for the key" "projects.d/beta lacks" "$out"
hasnt "a project with its own .sh: nothing from the shared file (it never applied)" "project_config.sh sets INSTALL_CMD=\"cmake --install build\", which .agent/projects.d/inst" "$out"
hasnt "a key the settings file has: nothing" "sets BUILD_CMD=\"make\", which .agent/projects.d/alpha" "$out"
printf 'build=make\ntest=make test\ninstall=none\n' > "$sb/.agent/projects.d/alpha"
out="$(report "$sb")"
has "nothing left to move: delete it" ".agent/project_config.sh is no longer read and holds nothing left to move: delete it" "$out"

echo "TEST: warnings never change validate's exit status"
sb="$(make_ws)"
mkdir -p "$sb/projects/orphan"
echo "ghost single_project $sb/nowhere" > "$sb/.agent/projects.local"
out="$(validate "$sb")"; rc=$?
[[ "$rc" -eq 1 ]] && pass "a failing validate still exits 1" || fail "rc=$rc"
has "and still shows the warning" "projects/orphan is not registered" "$out"

echo ""
echo "test_validate_workspace_stale: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
