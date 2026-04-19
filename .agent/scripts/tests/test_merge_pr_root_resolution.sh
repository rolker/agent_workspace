#!/usr/bin/env bash
# Tests for merge_pr.sh's ROOT_DIR resolution (issue #146).
#
# Instead of driving the full script (which would require mocking gh
# pr view / pr merge, the roadmap updater, worktree_remove.sh, etc.),
# these tests exercise the exact shell pipeline the script uses to
# resolve the main tree's absolute path, proving it returns the main
# tree from both the main tree itself and from a linked worktree.
#
# Run: bash .agent/scripts/tests/test_merge_pr_root_resolution.sh

set -euo pipefail

PASS=0
FAIL=0
TMPDIR_BASE=""
MAIN_REPO=""
WORKTREE=""

setup_main_and_worktree() {
    local initial_branch

    TMPDIR_BASE=$(mktemp -d /tmp/test_mpr.XXXXXX)
    MAIN_REPO="${TMPDIR_BASE}/main"
    git init -q "${MAIN_REPO}"
    git -C "${MAIN_REPO}" -c user.name="Test" -c user.email="t@t" commit --allow-empty -m "init" -q
    # Capture the user's init default branch (main/master/trunk/etc.)
    # so we can return to it after the feature branch is created.
    # Hardcoding main/master breaks on init.defaultBranch=trunk setups.
    initial_branch=$(git -C "${MAIN_REPO}" symbolic-ref --short HEAD)
    git -C "${MAIN_REPO}" checkout -q -b feature/issue-999 2>/dev/null
    git -C "${MAIN_REPO}" -c user.name="Test" -c user.email="t@t" commit --allow-empty -m "feature" -q
    git -C "${MAIN_REPO}" checkout -q "${initial_branch}"
    # Create a linked worktree on the feature branch
    WORKTREE="${MAIN_REPO}/worktrees/issue-999"
    git -C "${MAIN_REPO}" worktree add -q "${WORKTREE}" feature/issue-999
    # Simulate the .agent/scripts layout inside the worktree
    mkdir -p "${WORKTREE}/.agent/scripts"
}

teardown() {
    if [[ -n "$TMPDIR_BASE" && -d "$TMPDIR_BASE" ]]; then
        # Clean up worktree registration before removing dirs
        git -C "${MAIN_REPO}" worktree remove -f "${WORKTREE}" 2>/dev/null || true
        rm -rf "$TMPDIR_BASE"
    fi
}
trap teardown EXIT

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

# Extract ROOT_DIR the same way merge_pr.sh does. Keep this in sync
# with merge_pr.sh:69-83 — if that changes, update here.
# `|| true` so an outside-repo call returns empty instead of tripping
# the caller's pipefail.
resolve_root() {
    local script_dir="$1"
    { git -C "$script_dir" worktree list --porcelain 2>/dev/null \
        | head -n1 | sed 's/^worktree //'; } || true
}

# ---- Test: resolution from main tree returns main tree ----
test_resolution_from_main_tree() {
    echo "TEST: ROOT_DIR resolution from main tree"
    setup_main_and_worktree

    # Simulate invocation from the main tree's .agent/scripts dir.
    mkdir -p "${MAIN_REPO}/.agent/scripts"
    local script_dir="${MAIN_REPO}/.agent/scripts"
    local root
    root=$(resolve_root "$script_dir")
    assert_eq "from main tree -> main tree" "${MAIN_REPO}" "$root"

    teardown
}

# ---- Test: resolution from linked worktree returns main tree (#146) ----
test_resolution_from_worktree() {
    echo "TEST: ROOT_DIR resolution from inside a worktree (#146)"
    setup_main_and_worktree

    # Simulate invocation from the worktree's .agent/scripts dir — the
    # exact bug case: old `$SCRIPT_DIR/../..` would give WORKTREE here.
    local script_dir="${WORKTREE}/.agent/scripts"
    local root
    root=$(resolve_root "$script_dir")
    assert_eq "from worktree -> main tree (bug fix)" "${MAIN_REPO}" "$root"

    # And explicitly: the old relative approach would have returned
    # the worktree root — assert our fix doesn't regress to that.
    local old_approach
    old_approach=$(cd "$script_dir/../.." && pwd)
    if [[ "$old_approach" == "$WORKTREE" ]]; then
        echo "  PASS: old \$SCRIPT_DIR/../.. approach indeed resolves to worktree"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: old-approach control assertion unexpectedly passed"
        echo "    old_approach: $old_approach"
        echo "    WORKTREE:     $WORKTREE"
        FAIL=$((FAIL + 1))
    fi
    assert_eq "new approach differs from old" "$MAIN_REPO" "$root"

    teardown
}

# ---- Test: resolution outside any git repo returns empty ----
test_resolution_outside_repo() {
    echo "TEST: ROOT_DIR resolution outside any git repo"
    local tmp
    tmp=$(mktemp -d /tmp/test_mpr_norepo.XXXXXX)
    local root
    root=$(resolve_root "$tmp")
    assert_eq "outside repo -> empty string" "" "$root"
    rm -rf "$tmp"
}

# ---- Run all tests ----
echo "=== merge_pr.sh ROOT_DIR resolution tests ==="
echo ""

test_resolution_from_main_tree
test_resolution_from_worktree
test_resolution_outside_repo

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
