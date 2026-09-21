#!/usr/bin/env bash
# .agent/scripts/tests/test_run_script_tests.sh
# Tests for run_script_tests.sh (issue #269 PR A) — the runner that wires
# every .agent/scripts/tests/test_*.sh suite into the validate-script-tests
# pre-commit hook.
#
# Cases (a)–(d) cover discovery, fail-fast and the tool preflight; (e)–(k)
# cover the per-run TMPDIR leak guard and the absolute-/tmp mktemp lint
# added for issue #304 — (h)–(i) one case per mktemp spelling that escapes
# TMPDIR, (j) the anchoring that keeps a nested .../tmp/ path green, (k) the
# recursive listing in the leak message.
#
# Every case runs against a scratch copy of a tests directory
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

# --- Case (d): tool preflight — with jq missing from PATH the runner names
#     the missing tool and exits 1 before running any suite (round-1 review
#     suggestion: an opaque per-suite failure otherwise). A minimal PATH with
#     only the tools the runner itself needs, minus jq. ---
CASE_D="$TMPD/case_d"
mkdir -p "$CASE_D" "$TMPD/bin_nojq"
write_checkpoint_stub "$CASE_D"
MARKER_D="$TMPD/case_d_marker"
cat > "$CASE_D/test_synthetic.sh" <<EOF
#!/usr/bin/env bash
touch "$MARKER_D"
exit 0
EOF
chmod +x "$CASE_D/test_synthetic.sh"
for t in bash date basename dirname env python3; do
    p=$(command -v "$t") && ln -s "$p" "$TMPD/bin_nojq/$t"
done
out=$(PATH="$TMPD/bin_nojq" "$RUNNER" "$CASE_D" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && [ ! -f "$MARKER_D" ] && printf '%s' "$out" | grep -q "'jq' not found"; then
    pass "(d) missing jq is named by the preflight and no suite runs"
else
    fail "(d) missing jq is named by the preflight and no suite runs (rc=$rc, out=$out)"
fi

# --- Case (e): a suite that leaves a file in TMPDIR fails the run with exit
#     2, naming the suite that leaked (issue #304). The fixture writes
#     straight into $TMPDIR — which the runner points at its own per-run
#     guard directory — and exits 0, so only the post-suite sweep can catch
#     it. ---
CASE_E="$TMPD/case_e"
mkdir -p "$CASE_E"
write_checkpoint_stub "$CASE_E"
cat > "$CASE_E/test_aaa_leaker.sh" <<'EOF'
#!/usr/bin/env bash
: > "${TMPDIR:?TMPDIR must be set by the runner}/leaked_by_fixture"
exit 0
EOF
chmod +x "$CASE_E/test_aaa_leaker.sh"

out=$("$RUNNER" "$CASE_E" 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'test_aaa_leaker.sh' \
    && printf '%s' "$out" | grep -q 'leaked_by_fixture'; then
    pass "(e) a suite leaking into TMPDIR fails the run with exit 2, naming the suite"
else
    fail "(e) a suite leaking into TMPDIR fails the run with exit 2, naming the suite (rc=$rc, out=$out)"
fi

# --- Case (f): ordinary TMPDIR use that cleans up after itself still passes
#     — the guard must not false-positive on a suite that creates and
#     removes its own temp files. ---
CASE_F="$TMPD/case_f"
mkdir -p "$CASE_F"
write_checkpoint_stub "$CASE_F"
cat > "$CASE_F/test_tidy.sh" <<'EOF'
#!/usr/bin/env bash
d="$(mktemp -d)"       # honors TMPDIR, i.e. the runner's guard directory
f="$(mktemp)"
echo "work" > "$d/file"
rm -rf "$d" "$f"
exit 0
EOF
chmod +x "$CASE_F/test_tidy.sh"

out=$("$RUNNER" "$CASE_F" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "all 2 suites passed"; then
    pass "(f) a suite that cleans up its own TMPDIR files still passes"
else
    fail "(f) a suite that cleans up its own TMPDIR files still passes (rc=$rc, out=$out)"
fi

# --- Case (g): guard independence. The same leak fixture is run from a
#     tests-dir that is NOT under the TMPDIR handed to the runner, with that
#     caller TMPDIR pointing somewhere we control. The result must still be
#     exit 2, and the caller's TMPDIR must be untouched — a guard that keyed
#     off [tests-dir], or that reused the caller's TMPDIR, would behave
#     differently in one of those two respects. ---
CASE_G="$TMPD/case_g"
CALLER_TMPDIR="$TMPD/case_g_caller_tmpdir"
mkdir -p "$CASE_G" "$CALLER_TMPDIR"
write_checkpoint_stub "$CASE_G"
cp "$CASE_E/test_aaa_leaker.sh" "$CASE_G/test_aaa_leaker.sh"

out=$(TMPDIR="$CALLER_TMPDIR" "$RUNNER" "$CASE_G" 2>&1); rc=$?
caller_leftovers=$(find "$CALLER_TMPDIR" -mindepth 1 2>/dev/null)
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'test_aaa_leaker.sh' \
    && [ -z "$caller_leftovers" ]; then
    pass "(g) the guard is independent of [tests-dir] and of the caller's TMPDIR"
else
    fail "(g) the guard is independent of [tests-dir] and of the caller's TMPDIR (rc=$rc, caller_leftovers=$caller_leftovers, out=$out)"
fi

# --- Case (h): the preflight lint rejects an absolute-/tmp mktemp template
#     in a suite and exits 1, naming the file, before any suite runs.
#
#     The fixture's template is assembled from a variable so that no single
#     line of THIS file contains the lint's own pattern — the real run lints
#     "$TESTS_DIR"/test_*.sh, which includes this file, so a literal template
#     written inline here would make the whole suite fail its own lint. ---
CASE_H="$TMPD/case_h"
mkdir -p "$CASE_H"
write_checkpoint_stub "$CASE_H"
MARKER_H="$TMPD/case_h_marker"
ABS_TMP_ROOT=/tmp
printf '#!/usr/bin/env bash\nd=$(mktemp -d %s/leakfixture.XXXXXX)\nrm -rf "$d"\nexit 0\n' \
    "$ABS_TMP_ROOT" > "$CASE_H/test_absolute_template.sh"
cat > "$CASE_H/test_should_not_run.sh" <<EOF
#!/usr/bin/env bash
touch "$MARKER_H"
exit 0
EOF
chmod +x "$CASE_H"/test_*.sh

out=$("$RUNNER" "$CASE_H" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && [ ! -f "$MARKER_H" ] \
    && printf '%s' "$out" | grep -q 'test_absolute_template.sh'; then
    pass "(h) the preflight lint names an absolute-/tmp template and exits 1 before any suite runs"
else
    fail "(h) the preflight lint names an absolute-/tmp template and exits 1 before any suite runs (rc=$rc, marker_exists=$([ -f "$MARKER_H" ] && echo yes || echo no), out=$out)"
fi

# --- Case (i): the mktemp spellings that name an absolute root without a
#     literal template — `-p`, `--tmpdir=`, `--tmpdir `. Each one
#     creates its directory outside the runner's guard root, so the leak
#     sweep cannot see it and the run would otherwise exit 0 with a real
#     directory left in /tmp. The lint must reject all of them.
#
#     Same assembly trick as case (h): every fixture's /tmp root comes from
#     $ABS_TMP_ROOT via printf, so no line of THIS file matches the lint's
#     own pattern (the real run lints this file). ---
run_lint_spelling_case() {
    local label="$1" fmt="$2"
    local dir="$TMPD/case_i_$label" marker="$TMPD/case_i_${label}_marker"
    mkdir -p "$dir"
    write_checkpoint_stub "$dir"
    # shellcheck disable=SC2059  # $fmt is a caller-supplied format string
    printf "$fmt" "$ABS_TMP_ROOT" > "$dir/test_absolute_${label}.sh"
    cat > "$dir/test_should_not_run.sh" <<EOF
#!/usr/bin/env bash
touch "$marker"
exit 0
EOF
    chmod +x "$dir"/test_*.sh

    local out rc
    out=$("$RUNNER" "$dir" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && [ ! -f "$marker" ] \
        && printf '%s' "$out" | grep -q "test_absolute_${label}.sh"; then
        pass "(i) the lint rejects the $label spelling before any suite runs"
    else
        fail "(i) the lint rejects the $label spelling before any suite runs (rc=$rc, marker_exists=$([ -f "$marker" ] && echo yes || echo no), out=$out)"
    fi
}

run_lint_spelling_case "p_flag" \
    '#!/usr/bin/env bash\nd=$(mktemp -d -p %s leakfixture.XXXXXX)\nrm -rf "$d"\nexit 0\n'
run_lint_spelling_case "tmpdir_eq" \
    '#!/usr/bin/env bash\nd=$(mktemp -d --tmpdir=%s leakfixture.XXXXXX)\nrm -rf "$d"\nexit 0\n'
run_lint_spelling_case "tmpdir_space" \
    '#!/usr/bin/env bash\nd=$(mktemp -d --tmpdir %s leakfixture.XXXXXX)\nrm -rf "$d"\nexit 0\n'

# --- Case (j): the lint is anchored to a root /tmp, so a path that merely
#     contains a .../tmp/ segment is not a hit. The fixture below is written
#     literally (not assembled), which is the point: this very line is linted
#     by the real run, and it must stay green. ---
CASE_J="$TMPD/case_j"
mkdir -p "$CASE_J"
write_checkpoint_stub "$CASE_J"
cat > "$CASE_J/test_nested_tmp_path.sh" <<'EOF'
#!/usr/bin/env bash
base="${TMPDIR:?}/nest"
mkdir -p "$base/local/tmp"
d=$(mktemp -d "$base/local/tmp/fixture.XXXXXX")
[ -d "$d" ] || exit 1
rm -rf "$base"
exit 0
EOF
chmod +x "$CASE_J/test_nested_tmp_path.sh"

out=$("$RUNNER" "$CASE_J" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "all 2 suites passed"; then
    pass "(j) a non-root .../tmp/ path is not a lint hit"
else
    fail "(j) a non-root .../tmp/ path is not a lint hit (rc=$rc, out=$out)"
fi

# --- Case (k): the leak message lists the leaked tree recursively, not just
#     its top-level entries. The EXIT trap deletes the guard directory on the
#     way out, so whatever this message does not print is gone for good. ---
CASE_K="$TMPD/case_k"
mkdir -p "$CASE_K"
write_checkpoint_stub "$CASE_K"
cat > "$CASE_K/test_aaa_nested_leaker.sh" <<'EOF'
#!/usr/bin/env bash
mkdir -p "${TMPDIR:?TMPDIR must be set by the runner}/sandbox/deeper"
: > "${TMPDIR:?}/sandbox/deeper/telltale_file"
exit 0
EOF
chmod +x "$CASE_K/test_aaa_nested_leaker.sh"

out=$("$RUNNER" "$CASE_K" 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'test_aaa_nested_leaker.sh' \
    && printf '%s' "$out" | grep -q 'sandbox/deeper/telltale_file'; then
    pass "(k) the leak message lists the leaked tree recursively"
else
    fail "(k) the leak message lists the leaked tree recursively (rc=$rc, out=$out)"
fi

echo ""
echo "test_run_script_tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
