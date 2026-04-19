#!/usr/bin/env bash
# Tests for .agent/scripts/_resolve_work_plans_dir.sh
#
# Run: bash .agent/scripts/tests/test_resolve_work_plans_dir.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${SCRIPT_DIR}/../_resolve_work_plans_dir.sh"

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

# ---- Test: rule-3 error output is clean (issue #151 bug 1) ----
#
# Before the fix, line 59 had two echo statements concatenated:
#   echo "ERROR: ..."        echo ""
# …which parses as one echo command with multiple arguments and leaks
# the literal word "echo" into the error output. Regression test pins
# the error message shape.
test_rule3_output_is_clean() {
    echo "TEST: rule-3 output has no literal 'echo' leaked"

    local out
    out=$(
        unset WORK_PLANS_DIR_OVERRIDE WORKTREE_ISSUE
        # shellcheck source=../_resolve_work_plans_dir.sh
        source "${HELPER}"
        resolve_work_plans_dir 999 2>&1 || true
    )

    assert_contains "error header present" \
        "ERROR: refusing to resolve work-plans dir for issue #999 outside its worktree." \
        "$out"
    assert_not_contains "no literal 'echo' leaked into output" \
        "worktree. echo" "$out"
    # First line should end at "worktree." followed by newline, not " echo".
    local first_line
    first_line=$(printf '%s\n' "$out" | head -n1)
    assert_eq "first line ends cleanly at 'worktree.'" \
        "ERROR: refusing to resolve work-plans dir for issue #999 outside its worktree." \
        "$first_line"
}

# ---- Test: no-args call under set -u returns 1 cleanly (issue #151 bug 2) ----
#
# cross_model_review.sh runs under `set -euo pipefail`. Before the fix,
# `local issue="$1"` triggered bash's unbound-variable error before the
# explicit check on line 35 could run. Regression test exercises the
# same set-u context as the real caller.
test_no_args_under_set_u() {
    echo "TEST: resolve_work_plans_dir with no args under set -u"

    local out rc
    out=$(
        set -u
        # shellcheck source=../_resolve_work_plans_dir.sh
        source "${HELPER}"
        resolve_work_plans_dir 2>&1 || echo "__RC__=$?"
    )
    rc=$(printf '%s\n' "$out" | grep -oE '__RC__=[0-9]+$' | tail -n1 | cut -d= -f2)

    assert_eq "returns 1" "1" "$rc"
    assert_contains "intended error surfaced" \
        "issue number required" "$out"
    assert_not_contains "no bash unbound-variable leak" \
        "unbound variable" "$out"
}

# ---- Test: rule-1 override returned verbatim ----
test_rule1_override() {
    echo "TEST: WORK_PLANS_DIR_OVERRIDE returned verbatim"

    local out
    out=$(
        WORK_PLANS_DIR_OVERRIDE=/tmp/custom/path
        # shellcheck source=../_resolve_work_plans_dir.sh
        source "${HELPER}"
        resolve_work_plans_dir 42
    )
    assert_eq "override echoed as-is" "/tmp/custom/path" "$out"

    # Even a relative path is returned verbatim — that's the documented
    # contract post-#148.
    out=$(
        export WORK_PLANS_DIR_OVERRIDE=./relative/path
        # shellcheck source=../_resolve_work_plans_dir.sh
        source "${HELPER}"
        resolve_work_plans_dir 42
    )
    assert_eq "relative override echoed verbatim" "./relative/path" "$out"
}

# ---- Test: rule-2 WORKTREE_ISSUE match returns toplevel-anchored path ----
test_rule2_worktree_match() {
    echo "TEST: WORKTREE_ISSUE match returns toplevel-anchored path"

    local out toplevel
    toplevel=$(git rev-parse --show-toplevel 2>/dev/null || true)
    [[ -z "$toplevel" ]] && { echo "  SKIP: not in a git repo"; return; }

    out=$(
        unset WORK_PLANS_DIR_OVERRIDE
        WORKTREE_ISSUE=42
        # shellcheck source=../_resolve_work_plans_dir.sh
        source "${HELPER}"
        resolve_work_plans_dir 42
    )
    assert_eq "path under toplevel" \
        "${toplevel}/.agent/work-plans/issue-42" "$out"
}

# ---- Test: rule-3 mismatch message names both issues ----
test_rule3_mismatch_message() {
    echo "TEST: mismatch message names both WORKTREE_ISSUE and requested issue"

    local out
    out=$(
        unset WORK_PLANS_DIR_OVERRIDE
        export WORKTREE_ISSUE=100
        # shellcheck source=../_resolve_work_plans_dir.sh
        source "${HELPER}"
        resolve_work_plans_dir 42 2>&1 || true
    )
    assert_contains "mentions current WORKTREE_ISSUE" "'100', not '42'" "$out"
}

# ---- Test: direct execution errors out ----
test_direct_execution_refused() {
    echo "TEST: running the helper directly errors out"

    local rc=0
    local stderr
    stderr=$(bash "${HELPER}" 2>&1) || rc=$?
    assert_eq "exits 1" "1" "$rc"
    assert_contains "error mentions 'must be sourced'" "must be sourced" "$stderr"
}

# ---- Run all tests ----
echo "=== _resolve_work_plans_dir.sh tests ==="
echo ""

test_rule3_output_is_clean
test_no_args_under_set_u
test_rule1_override
test_rule2_worktree_match
test_rule3_mismatch_message
test_direct_execution_refused

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
