#!/usr/bin/env bash
# .agent/scripts/tests/test_skill_prefix.sh
# Tests for .agent/scripts/skill_prefix.sh (ADR-0017 decision 6, #345): the
# location rule that says whether workspace skills are bare or
# agent-workspace:-prefixed in a session started in a given directory, and
# that fails, rather than guesses, where neither holds.
#
# Hermetic: runs a COPY of the checkout's .agent/ (a fresh git repository)
# with a sandboxed registry; no HOME, CLI or network use.
#
# Run: bash .agent/scripts/tests/test_skill_prefix.sh

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
g -C "$WSC" init -q
g -C "$WSC" commit -q --allow-empty -m init
SP="$WSC/.agent/scripts/skill_prefix.sh"

# Fixtures, one per shape.
mkdir -p "$WSC/projects/p11" "$WSC/docs/deep"            # p11 shape; a plain workspace subdir
g -C "$WSC" worktree add -q "$SANDBOX/ws-wt" 2>/dev/null   # a worktree of the workspace
mkdir -p "$WSC/project" && g -C "$WSC/project" init -q     # a separate repo inside the workspace dir
R="$SANDBOX/roots"
mkdir -p "$R/gitroot/src/deeper" "$R/plain/sub" "$R/other"
g -C "$R/gitroot" init -q
g -C "$R/gitroot" commit -q --allow-empty -m init
g -C "$R/gitroot" worktree add -q "$R/gitroot-wt" 2>/dev/null
mkdir -p "$R/gitroot/src/pkg" && g -C "$R/gitroot/src/pkg" init -q   # nested package repo
ln -s "$WSC" "$SANDBOX/ws-link"
cat > "$WSC/.agent/projects.local" <<REG
p11      single_project  $WSC/projects/p11
nested   single_project  $WSC/project
gitroot  single_project  $R/gitroot
plain    project         $R/plain
REG

# expect <label> <dir> <want: bare|prefix|fail> [<stderr substring>]
expect() {
    local label="$1" dir="$2" want="$3" why="${4:-}" out err rc
    out="$(bash "$SP" --dir "$dir" 2>"$SANDBOX/err")"; rc=$?
    err="$(cat "$SANDBOX/err")"
    case "$want" in
        bare)   [[ "$rc" -eq 0 && "$out" == "skill_prefix=" ]] ;;
        prefix) [[ "$rc" -eq 0 && "$out" == "skill_prefix=agent-workspace:" ]] ;;
        fail)   [[ "$rc" -eq 1 && -z "$out" && "$err" == *"$why"* ]] ;;
    esac && pass "$label" || fail "$label (rc=$rc out='$out' err='$err')"
}

expect "the workspace checkout itself: bare" "$WSC" bare
expect "a plain directory in the workspace checkout: bare" "$WSC/docs/deep" bare
expect "a worktree of the workspace checkout: bare" "$SANDBOX/ws-wt" bare
expect "a registered root inside the workspace tree with no .git (p11 shape): bare" "$WSC/projects/p11" bare
expect "the workspace reached through a symlinked path: bare" "$SANDBOX/ws-link/docs" bare
expect "a registered git root: prefix" "$R/gitroot" prefix
expect "a plain directory of a registered git root: prefix" "$R/gitroot/src/deeper" prefix
expect "a worktree of a registered git root, outside it: prefix" "$R/gitroot-wt" prefix
expect "a separate registered repo inside the workspace directory: prefix" "$WSC/project" prefix
expect "a registered root in no git repository, at the root: prefix" "$R/plain" prefix
expect "a subdirectory of a no-git root (its own project root): fails, naming the root" "$R/plain/sub" fail \
    "lies under the registered root plain ($R/plain), but a session there does not read that root's local settings"
expect "a git repo nested in a registered root (a package repo): fails, naming the root" "$R/gitroot/src/pkg" fail \
    "lies under the registered root gitroot ($R/gitroot)"
expect "an unregistered directory: fails, saying there is no rule" "$R/other" fail \
    "is neither in the workspace checkout ($WSC) nor in any registered project root"
expect "a path that is not a directory: fails" "$R/no-such-dir" fail "is not a directory"

# The default is the current directory.
out="$(cd "$R/gitroot" && bash "$SP")"; rc=$?
[[ "$rc" -eq 0 && "$out" == "skill_prefix=agent-workspace:" ]] \
    && pass "without --dir, the current directory is used" \
    || fail "default directory (rc=$rc out=$out)"

# Usage errors are 2, not a verdict.
bash "$SP" --dir >/dev/null 2>&1; rc=$?
[[ "$rc" -eq 2 ]] && pass "--dir with no value is a usage error (exit 2)" || fail "--dir with no value exited $rc"
bash "$SP" --bogus >/dev/null 2>&1; rc=$?
[[ "$rc" -eq 2 ]] && pass "an unknown option is a usage error (exit 2)" || fail "unknown option exited $rc"

# An empty or missing registry leaves only the workspace rule.
rm -f "$WSC/.agent/projects.local"
expect "with no registry, the workspace is still bare" "$WSC" bare
expect "with no registry, a former root fails" "$R/gitroot" fail "nor in any registered project root"

echo ""
echo "test_skill_prefix: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
