#!/usr/bin/env bash
# .agent/scripts/tests/test_run_script_tests.sh
# Tests for run_script_tests.sh (issue #269 PR A) — the runner that wires
# every .agent/scripts/tests/test_*.sh suite into the validate-script-tests
# pre-commit hook.
#
# All three cases run against a scratch copy of a tests directory
# (run_script_tests.sh's optional [tests-dir] argument), never the real
# .agent/scripts/tests/ — so this suite's own pass/fail never depends on
# which suites currently live in this repo.
#
# Run: bash .agent/scripts/tests/test_run_script_tests.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run_script_tests.sh"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

# A trivial always-passing stand-in for the real test_checkpoint_269.sh —
# this suite tests the runner's discovery/fail-fast mechanics, not the
# checkpoint gate's own logic (that is test_checkpoint_269.sh's own job).
write_checkpoint_stub() {
    local dir="$1"
    cat > "$dir/test_checkpoint_269.sh" <<'EOF'
#!/usr/bin/env bash
echo "checkpoint stub: pass"
exit 0
EOF
    chmod +x "$dir/test_checkpoint_269.sh"
}

# --- Case (a): discovers and runs a synthetic test_*.sh fixture (glob coverage) ---
CASE_A="$TMPD/case_a"
mkdir -p "$CASE_A"
write_checkpoint_stub "$CASE_A"
MARKER_A="$TMPD/case_a_marker"
cat > "$CASE_A/test_synthetic.sh" <<EOF
#!/usr/bin/env bash
touch "$MARKER_A"
exit 0
EOF
chmod +x "$CASE_A/test_synthetic.sh"

out=$("$RUNNER" "$CASE_A" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$MARKER_A" ] && printf '%s' "$out" | grep -q "all 2 suites passed"; then
    pass "(a) discovers and runs a synthetic test_*.sh fixture via glob"
else
    fail "(a) discovers and runs a synthetic test_*.sh fixture via glob (rc=$rc, out=$out)"
fi

# --- Case (b): fails loudly when test_checkpoint_269.sh is absent ---
CASE_B="$TMPD/case_b"
mkdir -p "$CASE_B"
cat > "$CASE_B/test_other.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$CASE_B/test_other.sh"

out=$("$RUNNER" "$CASE_B" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'test_checkpoint_269.sh'; then
    pass "(b) fails loudly when test_checkpoint_269.sh is absent from the discovered set"
else
    fail "(b) fails loudly when test_checkpoint_269.sh is absent (rc=$rc, out=$out)"
fi

# --- Case (c): exits non-zero as soon as one suite fails, without running later suites ---
CASE_C="$TMPD/case_c"
mkdir -p "$CASE_C"
MARKER_C_LATER="$TMPD/case_c_later_marker"
# Alphabetical order: test_a_pass.sh, test_b_fail.sh, test_checkpoint_269.sh,
# test_z_never.sh — the runner must stop at test_b_fail.sh and never reach
# test_z_never.sh (which would create the "later" marker if it ran).
cat > "$CASE_C/test_a_pass.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$CASE_C/test_b_fail.sh" <<'EOF'
#!/usr/bin/env bash
echo "intentional failure"
exit 1
EOF
write_checkpoint_stub "$CASE_C"
cat > "$CASE_C/test_z_never.sh" <<EOF
#!/usr/bin/env bash
touch "$MARKER_C_LATER"
exit 0
EOF
chmod +x "$CASE_C"/test_*.sh

out=$("$RUNNER" "$CASE_C" 2>&1); rc=$?
if [ "$rc" -ne 0 ] && [ ! -f "$MARKER_C_LATER" ] \
    && printf '%s' "$out" | grep -q 'FAILED at test_b_fail.sh' \
    && ! printf '%s' "$out" | grep -q 'test_z_never'; then
    pass "(c) exits non-zero at the first failing suite, later suites never run"
else
    fail "(c) exits non-zero at the first failing suite, later suites never run (rc=$rc, marker_exists=$([ -f "$MARKER_C_LATER" ] && echo yes || echo no), out=$out)"
fi

# --- Extra: elapsed time is printed on both success and failure paths, per
#     the plan's "runner's own output states the elapsed time" requirement.
if printf '%s' "$out" | grep -Eq '[0-9]+s'; then
    pass "elapsed time is printed on the failure path"
else
    fail "elapsed time is printed on the failure path (out=$out)"
fi

echo ""
echo "test_run_script_tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
