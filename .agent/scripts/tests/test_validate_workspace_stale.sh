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
# CASE TABLE. Every check follows it, and each row has a test below (the
# test labels carry the row ids). "Registered" counts every registry line,
# parent roots and their instances included.
#
# R  Any check, a registry with errors: the whole report is one line,
#    ".agent/projects.local has errors ...", and nothing else.
#
# P  <ws>/project, and each entry of <ws>/projects/ (labelled
#    "projects/<entry>"), by one rule (_stale_folder_line):
#    P1  absent ............................................ silent
#    P2  the path that names it is a registered root ....... silent
#    P3  a registered root lies under it (by that path) .... silent
#    P4  it lies inside a registered root .................. silent
#    P5  a folder, unregistered (nothing registered too) ... "<label> is not registered ...: register it ..., or remove it"
#    P6  a link to a registered root ....................... "... a link to registered project '<n>' ...: remove it"
#    P7  a link to a folder inside a registered root ....... "... a link to <t>, inside registered project '<n>' ...: remove it"
#    P8  a link to a folder holding a registered root ...... "... which holds registered project '<n>' ...: remove it"
#    P9  a link to an unregistered folder .................. "... which is not registered ...: register <t> ... if it is a project, and remove the link"
#    P10 a dangling link ................................... "... which does not exist ...: remove it" (never "register")
#    P11 a link to a file .................................. "... which is not a folder ...: remove it"
#    P12 a parent root and its instances ................... as any root (P2 to P4, P6 to P8)
#
# W  worktrees/project/ and .workspace-worktrees/:
#    W1  absent, empty, or only empty folders ............. silent
#    W2  a checkout (a folder holding .git), depth 1 to 5,
#        in no registered root or worktrees= dir ......... "<loc>/ holds worktrees that are no longer found ..."
#    W3  a checkout in a registered worktrees= dir ........ silent
#    W4  a checkout in a registered root .................. silent
#    W5  nothing registered ............................... as W2
#    W6  the walk never enters a checkout and stops at depth 6
#
# S  .agent/projects.d/<name>.sh:
#    S1  registered, a key its settings file lacks ........ per key, with project_setting.sh set
#    S2  registered, ROS_* and its type reads it ......... distro= on the line / the environment
#    S3  registered, ROS_* and its type does not ......... nothing for it
#    S4  registered, nothing left to move ................. "holds nothing left to move: delete it"
#    S5  registered, cannot be sourced .................... "cannot be sourced ...: read it by hand"
#    S6  registered, its settings file is invalid ......... "... is invalid ... cannot be told"
#    S7  a parent root, sets something .................... "belongs to parent root ... still sets ...: move what an instance needs ..."
#    S8  a parent root, sets nothing ...................... "... sets nothing ...: delete it"
#    S9  unregistered (nothing registered too), sets something .. "belongs to no registered project and still sets ...: ... register it first ...; otherwise delete it"
#    S10 unregistered, sets nothing ....................... "... sets nothing ...: delete it"
#    S11 unregistered, cannot be sourced .................. "... cannot be sourced: read it by hand ..."
#
# C  .agent/project_config.sh, the shared file (it applied to each
#    registered non-parent project without a .sh of its own):
#    C1  applies to some; a key one lacks ................. per project and key
#    C2  applies to some; all moved; no unregistered folder named .. "delete it"
#    C3  applies to some; an unregistered folder named (P5, P9); it sets something .. "still sets ..., and an unregistered folder named above may have used it ..." (never "delete it")
#    C4  applies to none (nothing registered, every project has a .sh, only parent roots); it sets something .. "still sets ..., and it applies to no registered project ..." (never "delete it")
#    C5  applies to none; it sets nothing ................. "delete it"
#    C6  cannot be sourced ................................ "cannot be sourced ..."
#    C7  ROS_DISTRO per project whose type reads it; ROS_ROOT_DIR once when one does
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
    "project is not registered; nothing reads it any more: register it with .agent/scripts/register_project.sh <path>, or remove it" "$out"
echo "proj single_project $sb/project" >> "$sb/.agent/projects.local"
out="$(report "$sb")"
hasnt "a root registered at <ws>/project itself is silent (never 'remove it')" "project" "$out"

echo "TEST: project/ — a registered link, a dangling link, a link to an unregistered folder (review suggestion)"
sb="$(make_ws)"
git_repo "$sb/roots/alpha"
ln -s "$sb/roots/alpha" "$sb/project"
echo "proj single_project $sb/project" > "$sb/.agent/projects.local"
out="$(report "$sb")"
hasnt "a registry line naming <ws>/project, a link: never 'remove it' (that breaks the entry)" "project is a link" "$out"
[[ -z "$out" ]] && pass "a registered <ws>/project link: silent" || fail "unexpected: $out"
: > "$sb/.agent/projects.local"
rm "$sb/project"
ln -s "$sb/roots/gone" "$sb/project"
out="$(report "$sb")"
has "a dangling link: remove it" "project is a link to $sb/roots/gone, which does not exist; nothing reads the link any more: remove it (rm $sb/project)" "$out"
hasnt "a dangling link: never 'register it'" "register" "$out"
rm "$sb/project"
ln -s "$sb/roots/alpha" "$sb/project"
out="$(report "$sb")"
has "a link to an unregistered folder: register the target, remove the link" "project is a link to $sb/roots/alpha, which is not registered; nothing reads the link any more: register $(cd "$sb/roots/alpha" && pwd -P) with .agent/scripts/register_project.sh <path> if it is a project, and remove the link (rm $sb/project)" "$out"

echo "TEST: worktrees under the retired locations are named; empty ones are not"
sb="$(make_ws)"
mkdir -p "$sb/worktrees/project" "$sb/.workspace-worktrees"
out="$(report "$sb")"
[[ -z "$out" ]] && pass "empty retired directories: silent" || fail "unexpected: $out"
git_repo "$sb/origin"
git -C "$sb/origin" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m seed
mkdir -p "$sb/worktrees/project/alpha"
git -C "$sb/origin" worktree add -q "$sb/worktrees/project/alpha/issue-alpha-1" -b wt1 2>/dev/null
git -C "$sb/origin" worktree add -q "$sb/.workspace-worktrees/issue-workspace-2" -b wt2 2>/dev/null
out="$(report "$sb")"
has "worktrees/project/ named (a worktree two levels down)" "worktrees/project/ holds worktrees that are no longer found: remove each with git -C <its repository> worktree remove <path>" "$out"
has ".workspace-worktrees/ named" ".workspace-worktrees/ holds worktrees that are no longer found" "$out"
git -C "$sb/origin" worktree remove "$sb/worktrees/project/alpha/issue-alpha-1"
git -C "$sb/origin" worktree remove "$sb/.workspace-worktrees/issue-workspace-2"
out="$(report "$sb")"
[[ -d "$sb/worktrees/project/alpha" ]] && pass "the advised removal leaves the <name>/ folder" || fail "fixture: alpha/ is gone"
[[ -z "$out" ]] && pass "after the advised removals: silent (an empty <name>/ folder is not a worktree)" || fail "still reported after removal: $out"

echo "TEST: a worktrees= directory registered under worktrees/project/ is not reported"
sb="$(make_ws)"
git_repo "$sb/roots/alpha"
git -C "$sb/roots/alpha" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m seed
mkdir -p "$sb/worktrees/project/alpha-wt"
echo "alpha single_project $sb/roots/alpha worktrees=worktrees/project/alpha-wt" > "$sb/.agent/projects.local"
git -C "$sb/roots/alpha" worktree add -q "$sb/worktrees/project/alpha-wt/issue-alpha-3" -b wt3 2>/dev/null
out="$(report "$sb")"
hasnt "a registered worktrees= location is not a retired one" "worktrees/project/ holds" "$out"
mkdir -p "$sb/worktrees/project/other"
git -C "$sb/roots/alpha" worktree add -q "$sb/worktrees/project/other/issue-x-4" -b wt4 2>/dev/null
out="$(report "$sb")"
has "a worktree beside it that nothing registers is still named" "worktrees/project/ holds worktrees that are no longer found" "$out"

echo "TEST: a registry with errors gives one line and no remove, delete or register advice (review M1)"
sb="$(make_ws)"
git_repo "$sb/projects/inner"
printf 'inner single_project projects/inner\nbroken single_project\n' > "$sb/.agent/projects.local"
printf 'BUILD_CMD="make"\nTEST_CMD="make test"\n' > "$sb/.agent/projects.d/inner.sh"
ln -s "$sb/projects/inner" "$sb/project"
out="$(report "$sb")"
has "says the registry has errors" ".agent/projects.local has errors, so which retired shapes are still in use cannot be told: fix the registry (make validate names each bad line), then read this report again" "$out"
hasnt "a registered projects/<name> is not called unregistered" "projects/inner is not registered" "$out"
hasnt "a registered project's .sh is not called ownerless" "belongs to no registered project" "$out"
hasnt "no delete advice" "delete it" "$out"
hasnt "no register-or-remove advice" "register it" "$out"
[[ "$(wc -l <<< "$out")" -eq 1 ]] && pass "one line only" || fail "more than one line: $out"
printf 'inner single_project projects/inner\nghost single_project /nonexistent/x bogus=1\n' > "$sb/.agent/projects.local"
out="$(report "$sb")"
has "an unknown field is an error too" ".agent/projects.local has errors" "$out"

echo "TEST: an invalid settings file: what is left cannot be told, never 'lacks' (review M1)"
sb="$(make_ws)"
git_repo "$sb/roots/alpha"
echo "alpha single_project $sb/roots/alpha" > "$sb/.agent/projects.local"
printf 'build=make\nnot a setting line\n' > "$sb/.agent/projects.d/alpha"
printf 'BUILD_CMD="make"\n' > "$sb/.agent/projects.d/alpha.sh"
out="$(report "$sb")"
has "S6: says the settings file is invalid" "the settings file of 'alpha', .agent/projects.d/alpha, is invalid, so what is left in .agent/projects.d/alpha.sh to move cannot be told: fix it (.agent/scripts/project_setting.sh check alpha)" "$out"
hasnt "never 'lacks'" "lacks" "$out"
hasnt "never 'delete it'" "delete it" "$out"

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
has "S9: a .sh of no registered project that sets something: register first, else delete" ".agent/projects.d/ghost.sh belongs to no registered project and still sets BUILD_CMD: if 'ghost' is a project not registered yet, register it first (.agent/scripts/register_project.sh <path>) and this report names what to move; otherwise delete it" "$out"

echo "TEST: ROS_DISTRO and ROS_ROOT_DIR only for a type that reads them (review suggestion)"
sb="$(make_ws)"
git_repo "$sb/roots/alpha"
mkdir -p "$sb/roots/inst"
printf 'alpha single_project %s\ninst ros2_colcon %s\n' "$sb/roots/alpha" "$sb/roots/inst" > "$sb/.agent/projects.local"
printf 'build=make\ntest=make test\ninstall=none\n' > "$sb/.agent/projects.d/alpha"
printf 'ROS_DISTRO="fakefox"\nROS_ROOT_DIR="/srv/ros"\n' > "$sb/.agent/projects.d/alpha.sh"
out="$(report "$sb")"
hasnt "a single_project's .sh: no ROS_DISTRO line" "alpha.sh sets ROS_DISTRO" "$out"
hasnt "a single_project's .sh: no ROS_ROOT_DIR line" "alpha.sh sets ROS_ROOT_DIR" "$out"
has "a single_project's .sh with only ROS_* left: delete it" ".agent/projects.d/alpha.sh is no longer read and holds nothing left to move: delete it" "$out"
rm "$sb/.agent/projects.d/alpha.sh"
printf 'ROS_DISTRO="fakefox"\nROS_ROOT_DIR="/srv/ros"\n' > "$sb/.agent/project_config.sh"
printf 'BUILD_CMD="colcon build"\n' > "$sb/.agent/projects.d/inst.sh"
out="$(report "$sb")"
hasnt "shared file applying to a single_project only: no ROS_DISTRO line" "sets ROS_DISTRO" "$out"
hasnt "shared file applying to a single_project only: no ROS_ROOT_DIR line" "sets ROS_ROOT_DIR" "$out"
has "shared file with nothing a reader needs: delete it is reached" ".agent/project_config.sh is no longer read and holds nothing left to move: delete it" "$out"
rm "$sb/.agent/projects.d/inst.sh"
out="$(report "$sb")"
has "shared file applying to a ros2_colcon project: ROS_DISTRO per project" ".agent/project_config.sh sets ROS_DISTRO=\"fakefox\", which nothing reads any more: if inst's manifest declares no distro, add distro=fakefox to its line in .agent/projects.local by hand" "$out"
hasnt "and not for the single_project" "if alpha's manifest" "$out"
has "shared file applying to a ros2_colcon project: ROS_ROOT_DIR once" ".agent/project_config.sh sets ROS_ROOT_DIR=\"/srv/ros\", which is no longer read from a file: export ROS_ROOT_DIR=/srv/ros in the environment that runs the adapter" "$out"
[[ "$(grep -c 'sets ROS_ROOT_DIR' <<< "$out")" -eq 1 ]] && pass "ROS_ROOT_DIR said once" || fail "ROS_ROOT_DIR count: $out"
hasnt "no delete advice while it still holds something" "project_config.sh is no longer read and holds nothing" "$out"

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

echo "TEST: P3, P4 — a registered root under <ws>/project, or <ws>/project inside one, is silent (review round 2, M2)"
sb="$(make_ws)"
mkdir -p "$sb/project"
git_repo "$sb/project/sub"
echo "sub single_project $sb/project/sub" > "$sb/.agent/projects.local"
out="$(report "$sb")"
[[ -z "$out" ]] && pass "P3: <ws>/project holds a registered root: silent (never 'remove it')" || fail "P3 dir: $out"
rm -r "$sb/project"
git_repo "$sb/roots/elsewhere/sub"
ln -s "$sb/roots/elsewhere" "$sb/project"
echo "sub single_project $sb/project/sub" > "$sb/.agent/projects.local"
out="$(report "$sb")"
[[ -z "$out" ]] && pass "P3: a link a registry line names a root through: silent (removing it breaks the entry)" || fail "P3 link: $out"
rm "$sb/project"
mkdir -p "$sb/project"
echo "outer single_project $sb" > "$sb/.agent/projects.local"
out="$(report "$sb")"
hasnt "P4: <ws>/project inside a registered root: silent" "project is" "$out"

echo "TEST: P6 to P12 — links: into a root, holding a root, to a file; projects/<entry> follows the same rule (review round 2, M2)"
sb="$(make_ws)"
git_repo "$sb/roots/alpha"
mkdir -p "$sb/roots/alpha/sub"
echo "alpha single_project $sb/roots/alpha" > "$sb/.agent/projects.local"
rp="$(cd "$sb/roots" && pwd -P)"
ln -s "$sb/roots/alpha/sub" "$sb/project"
out="$(report "$sb")"
has "P7: a link into a registered root: remove it" "project is a link to $rp/alpha/sub, inside registered project 'alpha'; nothing reads the link any more: remove it (rm $sb/project)" "$out"
hasnt "P7: never 'register' a subfolder of a registered root" "register_project" "$out"
rm "$sb/project"
ln -s "$sb/roots" "$sb/project"
out="$(report "$sb")"
has "P8: a link to a folder holding a registered root: remove it" "project is a link to $rp, which holds registered project 'alpha'; nothing reads the link any more: remove it (rm $sb/project)" "$out"
rm "$sb/project"
printf 'x\n' > "$sb/roots/afile"
ln -s "$sb/roots/afile" "$sb/project"
out="$(report "$sb")"
has "P11: a link to a file: remove it" "project is a link to $sb/roots/afile, which is not a folder; nothing reads the link any more: remove it (rm $sb/project)" "$out"
rm "$sb/project"
mkdir -p "$sb/projects" "$sb/roots/loose"
ln -s "$sb/roots/alpha" "$sb/projects/lnk"
ln -s "$sb/roots/alpha/sub" "$sb/projects/into"
ln -s "$sb/roots/loose" "$sb/projects/loose"
ln -s "$sb/roots/gone" "$sb/projects/gone"
out="$(report "$sb")"
has "P6 (projects/): a link to a registered root: remove it" "projects/lnk is a link to registered project 'alpha'; nothing reads the link any more: remove it (rm $sb/projects/lnk)" "$out"
has "P7 (projects/): a link into a registered root: remove it" "projects/into is a link to $rp/alpha/sub, inside registered project 'alpha'" "$out"
has "P9 (projects/): a link to an unregistered folder: register the target, remove the link" "projects/loose is a link to $sb/roots/loose, which is not registered; nothing reads the link any more: register $rp/loose" "$out"
has "P10 (projects/): a dangling link: remove it" "projects/gone is a link to $sb/roots/gone, which does not exist; nothing reads the link any more: remove it (rm $sb/projects/gone)" "$out"
rm "$sb/projects/lnk" "$sb/projects/into" "$sb/projects/loose" "$sb/projects/gone"
mkdir -p "$sb/roots/grp"
git_repo "$sb/roots/grp/one"
printf 'alpha single_project %s\ngrp project %s\none single_project %s parent=grp\n' \
    "$sb/roots/alpha" "$sb/roots/grp" "$sb/roots/grp/one" > "$sb/.agent/projects.local"
ln -s "$sb/roots/grp" "$sb/project"
out="$(report "$sb")"
has "P12: a link to a parent root: the parent is a registered root" "project is a link to registered project 'grp'" "$out"
rm "$sb/project"
ln -s "$sb/roots/grp/one" "$sb/project"
out="$(report "$sb")"
has "P12: a link to an instance: that instance (self before inside)" "project is a link to registered project 'one'" "$out"
rm "$sb/project"
: > "$sb/.agent/projects.local"
mkdir -p "$sb/projects/orphan"
out="$(report "$sb")"
has "P5: nothing registered: a folder under projects/ is named" "projects/orphan is not registered; nothing reads it any more" "$out"

echo "TEST: W2 to W6 — a checkout deep in a retired location, one in a registered root, the depth bound"
sb="$(make_ws)"
git_repo "$sb/origin"
git -C "$sb/origin" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m seed
mkdir -p "$sb/worktrees/project/agg/issue-agg-5/l1_ws/src"
git -C "$sb/origin" worktree add -q "$sb/worktrees/project/agg/issue-agg-5/l1_ws/src/pkg" -b wt5 2>/dev/null
out="$(report "$sb")"
has "W2: a package-worktree entry five levels down is named" "worktrees/project/ holds worktrees that are no longer found" "$out"
git -C "$sb/origin" worktree remove "$sb/worktrees/project/agg/issue-agg-5/l1_ws/src/pkg"
mkdir -p "$sb/worktrees/project/a/b/c/d/e/f"
git -C "$sb/origin" worktree add -q "$sb/worktrees/project/a/b/c/d/e/f/deep" -b wt7 2>/dev/null
out="$(report "$sb")"
[[ -z "$out" ]] && pass "W6: a checkout seven levels down is past the bound (silent)" || fail "W6 depth: $out"
git -C "$sb/origin" worktree remove "$sb/worktrees/project/a/b/c/d/e/f/deep"
git_repo "$sb/worktrees/project/rootx"
echo "rootx single_project $sb/worktrees/project/rootx" > "$sb/.agent/projects.local"
out="$(report "$sb")"
hasnt "W4: a registered root under a retired location is silent" "worktrees/project/ holds" "$out"

echo "TEST: S5, S7, S8, S10, S11 — a .sh that cannot be sourced, of a parent root, of no registered project (review round 2)"
sb="$(make_ws)"
git_repo "$sb/roots/alpha"
mkdir -p "$sb/roots/grp"
git_repo "$sb/roots/grp/one"
printf 'alpha single_project %s\ngrp project %s\none single_project %s parent=grp\n' \
    "$sb/roots/alpha" "$sb/roots/grp" "$sb/roots/grp/one" > "$sb/.agent/projects.local"
printf 'build=make\ntest=make test\n' > "$sb/.agent/projects.d/alpha"
printf 'exit 3\n' > "$sb/.agent/projects.d/alpha.sh"
printf 'BUILD_CMD="make"\nROS_DISTRO="fakefox"\n' > "$sb/.agent/projects.d/grp.sh"
printf '# nothing\n' > "$sb/.agent/projects.d/ghost.sh"
printf 'exit 4\n' > "$sb/.agent/projects.d/broken.sh"
out="$(report "$sb")"
has "S5: a registered project's .sh that cannot be sourced: read it by hand" ".agent/projects.d/alpha.sh cannot be sourced, so what is left in it for 'alpha' is unknown: read it by hand" "$out"
has "S7: a parent root's .sh: names its instances, never project_setting.sh set grp" ".agent/projects.d/grp.sh belongs to parent root 'grp', which has no settings of its own (its instances have theirs: one), and still sets BUILD_CMD, ROS_DISTRO: move what an instance needs with .agent/scripts/project_setting.sh set <instance> <key>=<value>" "$out"
hasnt "S7: no 'set grp' remedy" "project_setting.sh set grp" "$out"
hasnt "S7: no distro= on the parent's line" "if grp's manifest" "$out"
has "S10: a .sh of no registered project that sets nothing: delete it" ".agent/projects.d/ghost.sh belongs to no registered project and sets nothing; nothing reads it any more: delete it" "$out"
has "S11: a .sh of no registered project that cannot be sourced: read it by hand" ".agent/projects.d/broken.sh belongs to no registered project and cannot be sourced: read it by hand" "$out"
printf '# nothing\n' > "$sb/.agent/projects.d/grp.sh"
out="$(report "$sb")"
has "S8: a parent root's .sh that sets nothing: delete it" ".agent/projects.d/grp.sh belongs to parent root 'grp', which has no settings of its own, and sets nothing; nothing reads it any more: delete it" "$out"
: > "$sb/.agent/projects.local"
printf 'INSTALL_CMD="make install"\n' > "$sb/.agent/projects.d/grp.sh"
out="$(report "$sb")"
has "S9: nothing registered: what a .sh sets is named, register first" ".agent/projects.d/grp.sh belongs to no registered project and still sets INSTALL_CMD" "$out"

echo "TEST: C3 to C6 — the shared file is never 'delete it' while it sets something nobody moved (review round 2, M1)"
sb="$(make_ws)"
printf 'BUILD_CMD="make"\nINSTALL_CMD="make install"\n' > "$sb/.agent/project_config.sh"
out="$(report "$sb")"
has "C4: nothing registered: says what it sets and to register first" ".agent/project_config.sh still sets BUILD_CMD, INSTALL_CMD, and it applies to no registered project (none is registered, or each has its own .agent/projects.d/<name>.sh): register that project first (.agent/scripts/register_project.sh <path>) and this report names what to move; delete the file only when no project needs it" "$out"
hasnt "C4: never 'holds nothing left to move'" "holds nothing left to move" "$out"
git_repo "$sb/roots/alpha"
echo "alpha single_project $sb/roots/alpha" > "$sb/.agent/projects.local"
printf 'BUILD_CMD="x"\n' > "$sb/.agent/projects.d/alpha.sh"
printf 'build=make\ntest=make test\ninstall=none\n' > "$sb/.agent/projects.d/alpha"
out="$(report "$sb")"
has "C4: every registered project has its own .sh: register first" ".agent/project_config.sh still sets BUILD_CMD, INSTALL_CMD, and it applies to no registered project" "$out"
rm "$sb/.agent/projects.d/alpha.sh"
mkdir -p "$sb/roots/grp"
printf 'grp project %s\n' "$sb/roots/grp" > "$sb/.agent/projects.local"
out="$(report "$sb")"
has "C4: only a parent root registered: register first" ".agent/project_config.sh still sets BUILD_CMD, INSTALL_CMD, and it applies to no registered project" "$out"
echo "alpha single_project $sb/roots/alpha" > "$sb/.agent/projects.local"
git_repo "$sb/project"
out="$(report "$sb")"
has "C3: applies to alpha (all moved), but the unregistered project/ is named: register first" ".agent/project_config.sh still sets BUILD_CMD, INSTALL_CMD, and an unregistered folder named above may have used it" "$out"
hasnt "C3: never 'delete it' for the shared file" "project_config.sh is no longer read and holds nothing left to move" "$out"
rm -r "$sb/project"
out="$(report "$sb")"
has "C2: applies to alpha, all moved, nothing unregistered: delete it" ".agent/project_config.sh is no longer read and holds nothing left to move: delete it" "$out"
: > "$sb/.agent/projects.local"
printf '# comments only\n' > "$sb/.agent/project_config.sh"
out="$(report "$sb")"
has "C5: applies to none and sets nothing: delete it" ".agent/project_config.sh is no longer read and holds nothing left to move: delete it" "$out"
printf 'exit 2\n' > "$sb/.agent/project_config.sh"
out="$(report "$sb")"
has "C6: cannot be sourced" ".agent/project_config.sh cannot be sourced, so what is left in it is unknown" "$out"

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
