#!/usr/bin/env bash
# .agent/scripts/tests/test_worktree_remove.sh
# Tests for worktree_remove.sh on a tree with read-only directories
# (issue 428, item 3). A build's install step can leave directories
# without write permission in a worktree; a file in such a directory
# cannot be unlinked, so `git worktree remove` failed and the tree had to
# be made writable and deleted by hand. The script now makes the tree's
# directories writable first:
#   - a read-only install/ tree (gitignored) is removed, plain and --force
#   - a dirty tracked file is still refused without --force, and nothing
#     is removed
#   - a symlink in the tree to a read-only directory outside it is never
#     followed: the outside directory keeps its mode and its contents
# Root ignores mode bits, so as root the tests would pass without the fix:
# the suite then skips with the reason.
# Everything runs in sandboxes (mktemp) with the real scripts copied in.
# Run: bash .agent/scripts/tests/test_worktree_remove.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check() {  # <label> <command...>: pass when the command succeeds
    local label="$1"; shift
    if "$@"; then pass "$label"; else fail "$label"; fi
}

if [ "$(id -u)" -eq 0 ]; then
    echo "SKIP: test_worktree_remove: running as root, which ignores directory mode bits, so a read-only tree would be removed with or without the fix"
    echo ""
    echo "test_worktree_remove: 0 passed, 0 failed (skipped as root)"
    exit 0
fi

# One sandbox for the whole run, created at top level so the trap fires
# (issue #297). The read-only directories a failed case leaves behind are
# made writable first, or the cleanup itself would fail on them.
SANDBOX="$(mktemp -d)"
trap 'chmod -R u+w "$SANDBOX" 2>/dev/null; rm -rf "$SANDBOX"' EXIT
export AGENT_NAME="Test Agent"
export AGENT_EMAIL="test+agent@example.com"
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT

# A workspace sandbox ($sb is ROOT_DIR) with the real scripts, and the
# worktree of issue 7 on feature/issue-7 with one tracked file. install/
# is gitignored, as a build's install tree is, so a plain (non --force)
# removal is not refused for untracked files and reaches the code under
# test.
make_sandbox() {
    local sb f wt
    sb="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$sb/.agent/scripts"
    for f in worktree_remove.sh worktree_list.sh _worktree_helpers.sh _issue_helpers.sh _project_registry.sh _resolve_default_branch.sh _real_case_path.sh; do
        cp "$REAL_ROOT/.agent/scripts/$f" "$sb/.agent/scripts/"
    done
    git -C "$sb" init --quiet -b main
    printf '.agent/\nworktrees/\n' > "$sb/.git/info/exclude"
    printf 'install/\n' > "$sb/.gitignore"
    printf 'tracked\n' > "$sb/tracked.txt"
    git -C "$sb" add .gitignore tracked.txt
    git -C "$sb" -c user.name=t -c user.email=t@t commit --quiet -m init
    wt="$sb/worktrees/workspace/issue-workspace-7"
    mkdir -p "$(dirname "$wt")"
    git -C "$sb" worktree add --quiet -b feature/issue-7 "$wt" main >/dev/null 2>&1
    echo "$sb"
}

# <wt>: install/lib/sub with a read-only file, every directory read-only
make_readonly_install() {
    mkdir -p "$1/install/lib/sub"
    printf 'built\n' > "$1/install/lib/sub/libfoo.so"
    chmod a-w "$1/install/lib/sub/libfoo.so"
    chmod a-w "$1/install/lib/sub" "$1/install/lib" "$1/install"
}

run_remove() {  # <sb> [args...]
    local sb="$1"; shift
    (cd "$sb" && "$sb/.agent/scripts/worktree_remove.sh" --issue 7 --type workspace "$@")
}

echo "TEST: a worktree with a read-only install tree is removed (plain removal)"
sb="$(make_sandbox)"; wt="$sb/worktrees/workspace/issue-workspace-7"
make_readonly_install "$wt"
# The fixture really is read-only: a plain unlink in it fails.
check "fixture: a file in the read-only directory cannot be unlinked" bash -c '! rm -f "$1" 2>/dev/null' _ "$wt/install/lib/sub/libfoo.so"
rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
check "plain: exit 0" test "$rc" -eq 0
check "plain: the worktree directory is gone" test ! -e "$wt"
check "plain: says it was removed" grep -q "Worktree removed successfully" <<<"$out"
check "plain: git no longer lists the worktree" bash -c '! git -C "$1" worktree list | grep -qF "$2"' _ "$sb" "$wt"

echo "TEST: the same with --force"
sb="$(make_sandbox)"; wt="$sb/worktrees/workspace/issue-workspace-7"
make_readonly_install "$wt"
rc=0; out="$(run_remove "$sb" --force 2>&1)" || rc=$?
check "--force: exit 0" test "$rc" -eq 0
check "--force: the worktree directory is gone" test ! -e "$wt"

echo "TEST: a dirty tracked file is still refused without --force"
sb="$(make_sandbox)"; wt="$sb/worktrees/workspace/issue-workspace-7"
make_readonly_install "$wt"
printf 'changed\n' > "$wt/tracked.txt"
rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
check "dirty: exit 1" test "$rc" -eq 1
check "dirty: names the uncommitted change" grep -q "uncommitted changes" <<<"$out"
check "dirty: the worktree is still there" test -f "$wt/tracked.txt"
check "dirty: the change is kept" grep -q changed "$wt/tracked.txt"
# The refusal comes before any chmod: the tree is left exactly as found.
check "dirty: the read-only directory is left read-only" test ! -w "$wt/install/lib"

echo "TEST: a symlink in the tree to a read-only directory outside it is never followed"
sb="$(make_sandbox)"; wt="$sb/worktrees/workspace/issue-workspace-7"
outside="$sb/outside_ro"
mkdir -p "$outside/inner"
printf 'keep\n' > "$outside/inner/keep.txt"
chmod a-w "$outside/inner" "$outside"
mode_before="$(stat -c %a "$outside") $(stat -c %a "$outside/inner")"
mkdir -p "$wt/install"
ln -s "$outside" "$wt/install/link"
rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
mode_after="$(stat -c %a "$outside") $(stat -c %a "$outside/inner")"
check "symlink: exit 0" test "$rc" -eq 0
check "symlink: the worktree directory is gone" test ! -e "$wt"
check "symlink: the outside directories keep their mode ($mode_before)" test "$mode_before" = "$mode_after"
check "symlink: the outside directory's contents are untouched" test -f "$outside/inner/keep.txt"

echo ""
echo "test_worktree_remove: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
