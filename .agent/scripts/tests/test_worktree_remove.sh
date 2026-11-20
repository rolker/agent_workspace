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
#   - an aggregate (package) worktree: read-only leftovers in the container
#     outside its entry, and a directory with no search permission over a
#     read-only one, are cleared by the aggregate step
#   - an aggregate entry that is itself a symlink to a checkout outside the
#     tree is refused before anything is removed, plain and --force
#   - a read-only container directory holding the entries does not stop
#     the removal part way
#   - an aggregate entry that cannot be entered (no search permission) is
#     refused as such, never as a link
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
# (issue #297). The read-only and no-search directories a failed case
# leaves behind get u+rwx first (u+w alone cannot enter a mode 600
# directory), or the cleanup itself would fail on them.
SANDBOX="$(mktemp -d)"
trap 'chmod -R u+rwx "$SANDBOX" 2>/dev/null; rm -rf "$SANDBOX"' EXIT
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

# <sb>: a second repository (a package's), outside the worktree tree, with
# one commit on main. Prints its path.
make_pkg_repo() {
    local repo
    repo="$(mktemp -d -p "$SANDBOX")"
    git -C "$repo" init --quiet -b main
    printf 'pkg\n' > "$repo/package.xml"
    git -C "$repo" add package.xml
    git -C "$repo" -c user.name=t -c user.email=t@t commit --quiet -m init
    echo "$repo"
}

# <sb> <rel> <origin>: turn issue 7's worktree into an aggregate (package)
# worktree: a plain container directory (not a git checkout) holding a
# .worktree-repos manifest and one entry, a linked worktree of <origin> at
# <rel>, on feature/issue-7.
make_aggregate() {
    local sb="$1" rel="$2" origin="$3" c
    c="$sb/worktrees/workspace/issue-workspace-7"
    git -C "$sb" worktree remove --force "$c" >/dev/null 2>&1
    git -C "$sb" worktree prune
    mkdir -p "$c/$(dirname "$rel")"
    git -C "$origin" worktree add --quiet -b feature/issue-7 "$c/$rel" main >/dev/null 2>&1
    printf '# project=demo issue=owner/pkg_a#7 layer=l1 base=main\n%s\t%s\tfeature/issue-7\n' "$origin" "$rel" > "$c/.worktree-repos"
}

echo "TEST: an aggregate (package) worktree with read-only leftovers outside its entry is removed"
sb="$(make_sandbox)"; c="$sb/worktrees/workspace/issue-workspace-7"
pkg="$(make_pkg_repo)"
make_aggregate "$sb" layer_ws/src/pkg_a "$pkg"
check "aggregate fixture: the entry is a linked worktree" test -f "$c/layer_ws/src/pkg_a/.git"
# Left at the container level, outside every entry, so only the aggregate
# step (_make_dirs_writable on the container, then rm -rf) can clear it:
# a read-only install tree, and a directory with no search (x) permission
# that holds a further read-only directory, which find can reach only if
# the outer one is repaired before find reads it.
make_readonly_install "$c/layer_ws"
mkdir -p "$c/layer_ws/build/noexec/inner"
printf 'obj\n' > "$c/layer_ws/build/noexec/inner/a.o"
chmod a-w "$c/layer_ws/build/noexec/inner"
chmod 600 "$c/layer_ws/build/noexec"
check "aggregate fixture: the no-search directory cannot be listed into" bash -c '! ls "$1" >/dev/null 2>&1' _ "$c/layer_ws/build/noexec/inner"
rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
check "aggregate: exit 0" test "$rc" -eq 0
check "aggregate: the container is gone" test ! -e "$c"
check "aggregate: says it was removed" grep -q "Worktree removed successfully" <<<"$out"
check "aggregate: the package repository no longer lists the entry" bash -c '! git -C "$1" worktree list | grep -qF "$2"' _ "$pkg" "$c/layer_ws/src/pkg_a"
check "aggregate: the package repository itself is untouched" test -f "$pkg/package.xml"

# An entry that is itself a symlink to a linked worktree outside the tree
# (holding a read-only install tree) is refused before anything is
# removed, plain and --force: `git worktree remove` given the link would
# delete the outside checkout's files, and the chmod must never follow it.
for mode in plain --force; do
    echo "TEST: an aggregate entry that is itself a symlink is refused, nothing removed ($mode)"
    sb="$(make_sandbox)"; c="$sb/worktrees/workspace/issue-workspace-7"
    pkg="$(make_pkg_repo)"
    make_aggregate "$sb" layer_ws/src/pkg_a "$pkg"
    pkg_b="$(make_pkg_repo)"
    outside_wt="$(mktemp -d -p "$SANDBOX")/outside_wt"
    git -C "$pkg_b" worktree add --quiet -b feature/issue-7 "$outside_wt" main >/dev/null 2>&1
    make_readonly_install "$outside_wt"
    ln -s "$outside_wt" "$c/layer_ws/src/pkg_b"
    printf '%s\t%s\tfeature/issue-7\n' "$pkg_b" layer_ws/src/pkg_b >> "$c/.worktree-repos"
    modes_before="$(stat -c %a "$outside_wt/install" "$outside_wt/install/lib" "$outside_wt/install/lib/sub" | tr '\n' ' ')"
    if [ "$mode" = plain ]; then set --; else set -- --force; fi
    rc=0; out="$(run_remove "$sb" "$@" 2>&1)" || rc=$?
    modes_after="$(stat -c %a "$outside_wt/install" "$outside_wt/install/lib" "$outside_wt/install/lib/sub" 2>/dev/null | tr '\n' ' ')"
    check "symlink entry ($mode): exit 1" test "$rc" -eq 1
    check "symlink entry ($mode): says the entry leads outside through a link" grep -q "leads outside this worktree" <<<"$out"
    check "symlink entry ($mode): the other entry is still there" test -f "$c/layer_ws/src/pkg_a/package.xml"
    check "symlink entry ($mode): the outside directories keep their mode ($modes_before)" test "$modes_before" = "$modes_after"
    check "symlink entry ($mode): the outside read-only file is still there" test -f "$outside_wt/install/lib/sub/libfoo.so"
    check "symlink entry ($mode): the outside checkout's files are still there" test -f "$outside_wt/package.xml"
    check "symlink entry ($mode): the outside package repository still lists its worktree" bash -c 'git -C "$1" worktree list | grep -qF "$2"' _ "$pkg_b" "$outside_wt"
done
set --

echo "TEST: a read-only container directory between the worktree and its entries does not stop the removal part way"
sb="$(make_sandbox)"; c="$sb/worktrees/workspace/issue-workspace-7"
pkg="$(make_pkg_repo)"
make_aggregate "$sb" layer_ws/src/pkg_a "$pkg"
pkg_b="$(make_pkg_repo)"
git -C "$pkg_b" worktree add --quiet -b feature/issue-7 "$c/layer_ws/src/pkg_b" main >/dev/null 2>&1
printf '%s\t%s\tfeature/issue-7\n' "$pkg_b" layer_ws/src/pkg_b >> "$c/.worktree-repos"
# layer_ws/src holds both entries; without write permission on it no entry
# can be unlinked from it.
chmod a-w "$c/layer_ws/src"
check "container fixture: the directory holding the entries is read-only" test ! -w "$c/layer_ws/src"
rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
check "container: exit 0" test "$rc" -eq 0
check "container: the container is gone" test ! -e "$c"
check "container: neither package repository lists its entry any more" bash -c '! git -C "$1" worktree list | grep -qF "$3" && ! git -C "$2" worktree list | grep -qF "$3"' _ "$pkg" "$pkg_b" "$c/layer_ws/src"

echo "TEST: an aggregate entry that cannot be entered is refused as such, not as a link"
sb="$(make_sandbox)"; c="$sb/worktrees/workspace/issue-workspace-7"
pkg="$(make_pkg_repo)"
make_aggregate "$sb" layer_ws/src/pkg_a "$pkg"
chmod 600 "$c/layer_ws/src/pkg_a"
rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
chmod 700 "$c/layer_ws/src/pkg_a"
check "no search: exit 1" test "$rc" -eq 1
check "no search: says the entry cannot be entered" grep -q "cannot enter .*pkg_a: no search permission" <<<"$out"
check "no search: does not speak of a symbolic link" bash -c '! grep -q "symbolic link" <<<"$1"' _ "$out"
check "no search: the entry is still there" test -f "$c/layer_ws/src/pkg_a/package.xml"
check "no search: the package repository still lists the entry" bash -c 'git -C "$1" worktree list | grep -qF "$2"' _ "$pkg" "$c/layer_ws/src/pkg_a"

# A folder above the entry with no search permission makes the entry look
# absent ([ -d ] fails on EACCES as on ENOENT). It must be refused as
# unreachable before anything is removed or any mode changed, plain and
# --force: taken as gone, the entry got no dirty check, and the chmod and
# rm -rf of the container then deleted it with its uncommitted work.
for mode in plain --force; do
    echo "TEST: an entry under a folder that cannot be entered is refused, not taken as gone ($mode)"
    sb="$(make_sandbox)"; c="$sb/worktrees/workspace/issue-workspace-7"
    pkg="$(make_pkg_repo)"
    make_aggregate "$sb" layer_ws/src/pkg_a "$pkg"
    printf 'uncommitted\n' > "$c/layer_ws/src/pkg_a/package.xml"
    chmod 600 "$c/layer_ws/src"
    check "unreachable fixture ($mode): the entry looks absent" test ! -d "$c/layer_ws/src/pkg_a"
    if [ "$mode" = plain ]; then set --; else set -- --force; fi
    rc=0; out="$(run_remove "$sb" "$@" 2>&1)" || rc=$?
    mode_after="$(stat -c %a "$c/layer_ws/src" 2>/dev/null || echo gone)"
    chmod 700 "$c/layer_ws/src" 2>/dev/null || true
    check "unreachable ($mode): exit 1" test "$rc" -eq 1
    check "unreachable ($mode): names the folder that cannot be entered" grep -qF "cannot enter $c/layer_ws/src:" <<<"$out"
    check "unreachable ($mode): says how to fix it" grep -q "chmod u+rwx" <<<"$out"
    check "unreachable ($mode): does not say it was removed" bash -c '! grep -q "Worktree removed successfully" <<<"$1"' _ "$out"
    check "unreachable ($mode): the folder keeps its mode (600)" test "$mode_after" = 600
    check "unreachable ($mode): the uncommitted change is kept" grep -q uncommitted "$c/layer_ws/src/pkg_a/package.xml"
    check "unreachable ($mode): the package repository still lists the entry" bash -c 'git -C "$1" worktree list | grep -F "$2" | grep -vq prunable' _ "$pkg" "$c/layer_ws/src/pkg_a"
done
set --

# The dirty check itself must not read "cannot look" as "clean": git status
# skips a folder it cannot open with a warning and exit 0, so untracked work
# in it went unseen and the folder was opened by the chmod before git's own
# check refused. Refused before any mode is changed, as a dirty entry is.
echo "TEST: a folder git status cannot open is refused without --force, mode and contents kept"
sb="$(make_sandbox)"; wt="$sb/worktrees/workspace/issue-workspace-7"
mkdir -p "$wt/notes"
printf 'draft\n' > "$wt/notes/draft.txt"
chmod 000 "$wt/notes"
rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
mode_after="$(stat -c %a "$wt/notes" 2>/dev/null || echo gone)"
chmod 700 "$wt/notes" 2>/dev/null || true
check "unreadable: exit 1" test "$rc" -eq 1
check "unreadable: says what it cannot read" grep -qF "cannot read all of $wt" <<<"$out"
check "unreadable: the folder keeps its mode (000)" test "$mode_after" = 0
check "unreadable: the untracked file is kept" test -f "$wt/notes/draft.txt"

echo "TEST: the same folder with --force is removed"
sb="$(make_sandbox)"; wt="$sb/worktrees/workspace/issue-workspace-7"
mkdir -p "$wt/notes"
printf 'draft\n' > "$wt/notes/draft.txt"
chmod 000 "$wt/notes"
rc=0; out="$(run_remove "$sb" --force 2>&1)" || rc=$?
check "unreadable --force: exit 0" test "$rc" -eq 0
check "unreadable --force: the worktree directory is gone" test ! -e "$wt"

echo "TEST: an entry that is genuinely absent is skipped, the rest removed"
sb="$(make_sandbox)"; c="$sb/worktrees/workspace/issue-workspace-7"
pkg="$(make_pkg_repo)"
make_aggregate "$sb" layer_ws/src/pkg_a "$pkg"
pkg_b="$(make_pkg_repo)"
# pkg_b's entry is gone, and so is gone_ws, the folder above pkg_c's entry.
printf '%s\t%s\tfeature/issue-7\n' "$pkg_b" layer_ws/src/pkg_b >> "$c/.worktree-repos"
printf '%s\t%s\tfeature/issue-7\n' "$pkg_b" gone_ws/src/pkg_c >> "$c/.worktree-repos"
rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
check "absent: exit 0" test "$rc" -eq 0
check "absent: the container is gone" test ! -e "$c"
check "absent: says it was removed" grep -q "Worktree removed successfully" <<<"$out"
check "absent: the present entry's repository no longer lists it" bash -c '! git -C "$1" worktree list | grep -qF "$2"' _ "$pkg" "$c/layer_ws/src/pkg_a"

# A folder on an entry's path that is a symbolic link out of the worktree
# is refused as such, before any search-permission advice: a `chmod u+rwx`
# on the link would follow it and change a folder outside the worktree.
# Two shapes: the outside target cannot be entered; the outside target can,
# but the entry under it cannot.
for shape in target entry; do
    echo "TEST: an entry under a symbolic link out of the worktree is refused as a link, never with chmod advice ($shape cannot be entered)"
    sb="$(make_sandbox)"; c="$sb/worktrees/workspace/issue-workspace-7"
    pkg="$(make_pkg_repo)"
    make_aggregate "$sb" layer_ws/src/pkg_a "$pkg"
    out_dir="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$out_dir/pkg_x"
    printf 'keep\n' > "$out_dir/pkg_x/keep.txt"
    ln -s "$out_dir" "$c/ext"
    printf '%s\t%s\tfeature/issue-7\n' "$pkg" ext/pkg_x >> "$c/.worktree-repos"
    if [ "$shape" = target ]; then blocked="$out_dir"; else blocked="$out_dir/pkg_x"; fi
    chmod 600 "$blocked"
    rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
    mode_after="$(stat -c %a "$blocked")"
    chmod 700 "$blocked"
    check "outside link ($shape): exit 1" test "$rc" -eq 1
    check "outside link ($shape): says it leads outside through a link" grep -q "leads outside this worktree" <<<"$out"
    check "outside link ($shape): gives no chmod advice" bash -c '! grep -q "chmod" <<<"$1"' _ "$out"
    check "outside link ($shape): the outside folder keeps mode 600" test "$mode_after" = 600
    check "outside link ($shape): the outside contents are kept" test -f "$out_dir/pkg_x/keep.txt"
    check "outside link ($shape): the other entry is still there" test -f "$c/layer_ws/src/pkg_a/package.xml"
done

# A link that stays inside the worktree is walked through as before: the
# dirty check reaches the entry under it.
echo "TEST: an entry under a symbolic link inside the worktree is checked as before"
sb="$(make_sandbox)"; c="$sb/worktrees/workspace/issue-workspace-7"
pkg="$(make_pkg_repo)"
make_aggregate "$sb" layer_ws/src/pkg_a "$pkg"
ln -s layer_ws "$c/alias"
printf '# project=demo issue=owner/pkg_a#7 layer=l1 base=main\n%s\t%s\tfeature/issue-7\n' "$pkg" alias/src/pkg_a > "$c/.worktree-repos"
printf 'uncommitted\n' > "$c/layer_ws/src/pkg_a/package.xml"
rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
check "inside link: exit 1" test "$rc" -eq 1
check "inside link: refused for the uncommitted change" grep -q "uncommitted changes" <<<"$out"
check "inside link: the change is kept" grep -q uncommitted "$c/layer_ws/src/pkg_a/package.xml"

# The same inside link to a folder that cannot be entered: the advice
# names the folder the link leads to, inside the worktree, not the link.
echo "TEST: an inside link to a folder that cannot be entered names that folder"
sb="$(make_sandbox)"; c="$sb/worktrees/workspace/issue-workspace-7"
pkg="$(make_pkg_repo)"
make_aggregate "$sb" layer_ws/src/pkg_a "$pkg"
ln -s layer_ws/src "$c/alias"
printf '# project=demo issue=owner/pkg_a#7 layer=l1 base=main\n%s\t%s\tfeature/issue-7\n' "$pkg" alias/pkg_a > "$c/.worktree-repos"
chmod 600 "$c/layer_ws/src"
rc=0; out="$(run_remove "$sb" 2>&1)" || rc=$?
chmod 700 "$c/layer_ws/src"
check "inside link, no search: exit 1" test "$rc" -eq 1
check "inside link, no search: names the folder inside the worktree" grep -qF "cannot enter $c/layer_ws/src:" <<<"$out"
check "inside link, no search: the entry is still there" test -f "$c/layer_ws/src/pkg_a/package.xml"

# The chmod never opens the top folder of a mount of another filesystem
# (find -xdev alone still lists it). Mounting needs a user and mount
# namespace (unshare -rm); where that is not allowed the case is skipped
# and says so. The function is taken from the script as it stands.
echo "TEST: the chmod leaves a mount of another filesystem's top folder alone"
if unshare -rm true 2>/dev/null; then
    mt="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$mt/tree/a/mnt" "$mt/tree/a/ro"
    sed -n '/^_make_dirs_writable() {/,/^}/p' "$REAL_ROOT/.agent/scripts/worktree_remove.sh" > "$mt/fn.sh"
    modes="$(unshare -rm bash -c '
        source "$1/fn.sh"
        mount -t tmpfs -o mode=555 none "$1/tree/a/mnt" || exit 1
        chmod 555 "$1/tree/a/ro"
        _make_dirs_writable "$1/tree"
        stat -c %a "$1/tree/a/mnt" "$1/tree/a/ro" | tr "\n" " "
    ' _ "$mt" 2>/dev/null)" || modes="mount failed"
    check "mount: the function was found in the script" test -s "$mt/fn.sh"
    check "mount: its top folder keeps mode 555, a same-filesystem folder gets u+rwx (got: $modes)" test "$modes" = "555 755 "
else
    echo "  SKIP: unshare -rm is not allowed here, so no mount can be made"
fi

echo ""
echo "test_worktree_remove: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
