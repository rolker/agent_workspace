#!/usr/bin/env bash
# .agent/scripts/tests/test_session_root.sh
# Tests for .agent/scripts/session_root.sh (ADR-0018 decision 6, #345): a
# session's root is the directory it was launched in -- the workspace
# checkout or a registered project root -- and an issue of another root is
# refused, naming the directory to start in.
#
# Hermetic: runs a COPY of the checkout's .agent/ (a fresh git repository)
# with a sandboxed registry; no HOME, CLI or network use.
#
# Run: bash .agent/scripts/tests/test_session_root.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOX="$(mktemp -d)"
SANDBOX="$(cd "$SANDBOX" && pwd -P)"
trap 'rm -rf "$SANDBOX"' EXIT
g() { git -c user.name=t -c user.email=t@t "$@"; }

WSC="$SANDBOX/ws"
mkdir -p "$WSC"
cp -r "$WS_ROOT/.agent" "$WSC/.agent"
rm -f "$WSC/.agent/projects.local"
rm -rf "$WSC/project"
g -C "$WSC" init -q
g -C "$WSC" commit -q --allow-empty -m init
SR="$WSC/.agent/scripts/session_root.sh"

R="$SANDBOX/roots"
mkdir -p "$WSC/projects/p11/sub" "$WSC/docs" "$WSC/worktrees/workspace/issue-workspace-1" "$WSC/worktrees/project/wtroot/issue-wtroot-1"
mkdir -p "$R/gitroot/src/deeper" "$R/gitroot/worktrees/issue-gitroot-1" "$R/wtroot" \
    "$R/par/inst1/sub" "$R/par/inst2" "$R/other" "$R/unreg"
g -C "$R/gitroot" init -q
mkdir -p "$R/gitroot/src/pkg" && g -C "$R/gitroot/src/pkg" init -q   # nested package repo
REGFILE="$WSC/.agent/projects.local"
# The instances are listed before their parent, so only a longest match
# (not the last or first match) resolves a directory inside one of them.
cat > "$REGFILE" <<REG
p11      single_project  $WSC/projects/p11
gitroot  single_project  $R/gitroot
wtroot   single_project  $R/wtroot  worktrees=$WSC/worktrees/project/wtroot
inst1    single_project  $R/par/inst1  parent=par
inst2    single_project  $R/par/inst2  parent=par
par      project         $R/par     default_instance=inst1
other    single_project  $R/other
REG

# root <label> <dir> <root> <type> <project>
root() {
    local label="$1" dir="$2" want
    want="$(printf 'root=%s\ntype=%s\nproject=%s' "$3" "$4" "$5")"
    local out rc
    out="$(bash "$SR" --dir "$dir" 2>"$SANDBOX/err")"; rc=$?
    [[ "$rc" -eq 0 && "$out" == "$want" ]] && pass "$label" \
        || fail "$label (rc=$rc out='$out' err='$(cat "$SANDBOX/err")')"
}

# check <label> <dir> <want: ok|refuse|err> <stderr substring> -- <session_root.sh args>
check() {
    local label="$1" dir="$2" want="$3" why="$4" out err rc ok=1
    shift 5
    out="$(bash "$SR" --dir "$dir" "$@" 2>"$SANDBOX/err")"; rc=$?
    err="$(cat "$SANDBOX/err")"
    case "$want" in
        ok)     [[ "$rc" -eq 0 && "$out" == root=* ]] || ok=0 ;;
        refuse) [[ "$rc" -eq 1 && -z "$out" && "$err" == *"$why"* ]] || ok=0 ;;
        err)    [[ "$rc" -eq 2 && -z "$out" ]] || ok=0 ;;
    esac
    [[ "$ok" -eq 1 ]] && pass "$label" || fail "$label (rc=$rc out='$out' err='$err')"
}

echo "== a directory's session root =="
root "the workspace checkout" "$WSC" "$WSC" workspace ""
root "a directory of the workspace checkout" "$WSC/docs" "$WSC" workspace ""
root "a workspace worktree directory" "$WSC/worktrees/workspace/issue-workspace-1" "$WSC" workspace ""
root "a registered root inside the workspace tree is its own root" "$WSC/projects/p11/sub" "$WSC/projects/p11" project p11
root "a registered git root" "$R/gitroot" "$R/gitroot" project gitroot
root "a package repo nested in a root: the hosting dir, not the nested repo" "$R/gitroot/src/pkg" "$R/gitroot" project gitroot
root "a worktree under a root's own worktrees/" "$R/gitroot/worktrees/issue-gitroot-1" "$R/gitroot" project gitroot
root "a worktree in a root's worktrees= directory inside the workspace tree: that root, not the workspace" \
    "$WSC/worktrees/project/wtroot/issue-wtroot-1" "$R/wtroot" project wtroot
root "an instance inside its parent: the instance" "$R/par/inst1/sub" "$R/par/inst1" project inst1
root "a parent root itself" "$R/par" "$R/par" project par
root "a symlinked path resolves to the physical root" "$(ln -s "$R/gitroot" "$SANDBOX/gr-link" && echo "$SANDBOX/gr-link/src")" "$R/gitroot" project gitroot
check "an unregistered directory is no session's root" "$R/unreg" refuse \
    "is neither in the workspace checkout ($WSC) nor under a registered project root" --
check "a path that is not a directory" "$R/no-such" refuse "is not a directory" --
out="$(cd "$R/other" && bash "$SR")"; rc=$?
[[ "$rc" -eq 0 && "$out" == "root=$R/other"* ]] && pass "without --dir, the current directory is used" \
    || fail "default directory (rc=$rc out=$out)"

echo "== a copy in a worktree of the workspace reads the main checkout's registry =="
g -C "$WSC" worktree add -q "$SANDBOX/ws-wt" 2>/dev/null
mkdir -p "$SANDBOX/ws-wt/.agent" && cp -r "$WSC/.agent/scripts" "$SANDBOX/ws-wt/.agent/"
WTSR="$SANDBOX/ws-wt/.agent/scripts/session_root.sh"
out="$(bash "$WTSR" --dir "$R/gitroot" 2>&1)"; rc=$?
[[ "$rc" -eq 0 && "$out" == "root=$R/gitroot"$'\n'"type=project"$'\n'"project=gitroot" ]] \
    && pass "the worktree copy finds a registered root through the main checkout's registry" \
    || fail "worktree copy, registered root (rc=$rc out=$out)"
out="$(bash "$WTSR" --dir "$SANDBOX/ws-wt" --type project --project gitroot 2>&1)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"start a session in $R/gitroot"* && "$out" != *"not registered"* ]] \
    && pass "the worktree copy refuses another root's issue, naming it, not 'not registered'" \
    || fail "worktree copy, cross-root refusal (rc=$rc out=$out)"
out="$(bash "$WTSR" --dir "$SANDBOX/ws-wt" 2>&1)"; rc=$?
[[ "$rc" -eq 0 && "$out" == "root=$WSC"$'\n'"type=workspace"* ]] \
    && pass "a linked worktree of the workspace outside its tree is the workspace's" \
    || fail "worktree of the workspace outside its tree (rc=$rc out=$out)"

echo "== an issue of the session's own root passes =="
check "workspace session, workspace issue" "$WSC/docs" ok "" -- --type workspace
check "project session, its own project" "$R/gitroot" ok "" -- --type project --project gitroot
check "nested package repo, the hosting root's project" "$R/gitroot/src/pkg" ok "" -- --type project --project gitroot
check "p11-shape root, its own project" "$WSC/projects/p11" ok "" -- --type project --project p11
check "parent root, the parent's default instance" "$R/par" ok "" -- --type project --project par
check "parent root, another instance it owns" "$R/par" ok "" -- --type project --project inst2

echo "== an issue of another root is refused, naming where to start =="
check "workspace session, a project outside the tree" "$WSC" refuse \
    "start a session in $R/gitroot for this issue" -- --type project --project gitroot
check "workspace session, a registered root inside the workspace tree" "$WSC/docs" refuse \
    "start a session in $WSC/projects/p11" -- --type project --project p11
check "project session, a workspace issue" "$R/gitroot/src/deeper" refuse \
    "start a session in $WSC for this issue" -- --type workspace
check "project session, another project" "$R/gitroot" refuse \
    "start a session in $R/other" -- --type project --project other
check "an instance session, its sibling instance" "$R/par/inst1" refuse \
    "start a session in $R/par/inst2" -- --type project --project inst2
check "the refusal names this session's root too" "$R/gitroot" refuse \
    "this session's root is $R/gitroot" -- --type workspace
check "an unregistered --project is refused" "$WSC" refuse "project 'nope' is not registered" \
    -- --type project --project nope
check "a workspace session: --type project with several registered and no legacy project/ asks for --project" "$WSC" refuse \
    "pass --project <name>" -- --type project
check "a project session: --type project alone means its own project" "$R/gitroot/src/deeper" ok "" -- --type project
check "a parent-root session: --type project alone means the parent's default instance" "$R/par" ok "" -- --type project

echo "== --type project without --project =="
cp "$REGFILE" "$SANDBOX/reg.full"
printf 'gitroot  single_project  %s\n' "$R/gitroot" > "$REGFILE"
check "the single registered project: its own session passes" "$R/gitroot" ok "" -- --type project
check "the single registered project: a session in its nested package repo passes" "$R/gitroot/src/pkg" ok "" -- --type project
check "the single registered project: a workspace session is refused" "$WSC" refuse \
    "start a session in $R/gitroot" -- --type project
mkdir -p "$R/legacy-src" && g -C "$R/legacy-src" init -q
ln -s "$R/legacy-src" "$WSC/project"
check "a legacy project/ symlink is hosted by the workspace: workspace session passes" "$WSC" ok "" -- --type project
check "a legacy project/: a registered project's session is refused for a workspace issue" "$R/gitroot" refuse \
    "start a session in $WSC for this issue" -- --type workspace
check "a legacy project/: a registered project's session still means its own project" "$R/gitroot" ok "" -- --type project
check "a legacy project/: a workspace session's other registered project is still refused" "$WSC" refuse \
    "start a session in $R/gitroot" -- --type project --project gitroot
rm -f "$WSC/project"
cp "$SANDBOX/reg.full" "$REGFILE"

echo "== usage and registry errors are exit 2 =="
check "--project without --type" "$WSC" err "" -- --project gitroot
check "an unknown --type" "$WSC" err "" -- --type layer
check "an unknown option" "$WSC" err "" -- --bogus
printf 'bad name!  single_project  /x\n' >> "$REGFILE"
check "a registry that does not parse" "$WSC" err "" --
cp "$SANDBOX/reg.full" "$REGFILE"

echo ""
echo "test_session_root: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
