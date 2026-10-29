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
# recursive listing in the leak message. (l)–(p) cover the --files mode
# added for issue #410: (l) suites_for_files.sh's selection rules, (m) a
# scoped run, (n) the full runs (no --files, the runner in the list, no
# files, over 200 files), (o) deletions and renames through a real git
# hook (`git commit -a`, a pathspec commit, a rename out of the hook's
# scope, and an edit-only control), (p) the branch run.
#
# Every case runs against a scratch copy of a tests directory
# (run_script_tests.sh's optional [tests-dir] argument), never the real
# .agent/scripts/tests/ — so this suite's own pass/fail never depends on
# which suites currently live in this repo. The real-tree checks of the
# suite map live in test_script_tests_hook_scope.sh.
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
#     literal template — `-p`, `-p<root>` (attached argument), `-dp<root>`
#     (attached argument on a short-flag cluster), `--tmpdir=`,
#     `--tmpdir `. Each one
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
run_lint_spelling_case "p_flag_attached" \
    '#!/usr/bin/env bash\nd=$(mktemp -d -p%s leakfixture.XXXXXX)\nrm -rf "$d"\nexit 0\n'
run_lint_spelling_case "dp_cluster_attached" \
    '#!/usr/bin/env bash\nd=$(mktemp -dp%s leakfixture.XXXXXX)\nrm -rf "$d"\nexit 0\n'
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

# --- Case (j2): the other half of the anchor claim — the *trailing* boundary.
#     `/tmp` only counts when the next character ends the path component, so
#     `/tmpfile.XXXXXX` (a sibling of /tmp, not a child) is not a hit, whether
#     it follows a real boundary character in prose or sits under $TMPDIR.
#
#     Assembled via printf from $ABS_TMP_ROOT like cases (h) and (i): the
#     prose line puts a whitespace boundary directly before the root, which
#     is exactly the shape the trailing anchor has to reject, so writing it
#     literally here would trip the lint on this very file. ---
CASE_J2="$TMPD/case_j2"
mkdir -p "$CASE_J2"
write_checkpoint_stub "$CASE_J2"
printf '#!/usr/bin/env bash\n# mktemp is never handed %sfile.XXXXXX as a template here\nd=$(mktemp -d "${TMPDIR:?}%sfile.XXXXXX")\n[ -d "$d" ] || exit 1\nrm -rf "$d"\nexit 0\n' \
    "$ABS_TMP_ROOT" "$ABS_TMP_ROOT" > "$CASE_J2/test_tmpfile_sibling.sh"
chmod +x "$CASE_J2/test_tmpfile_sibling.sh"

out=$("$RUNNER" "$CASE_J2" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "all 2 suites passed"; then
    pass "(j2) a /tmp-prefixed sibling name is not a lint hit"
else
    fail "(j2) a /tmp-prefixed sibling name is not a lint hit (rc=$rc, out=$out)"
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

# ===================================================================
# Issue #410: --files mode. Every case below builds a synthetic git
# repository (never the real tree: this file is itself one of the real
# suites, so running the real tree from here would recurse) with its own
# .pre-commit-config.yaml hook block, scripts and suites, and asks the real
# suites_for_files.sh / run_script_tests.sh about it. Suites record that
# they ran by touching "$SYN_MARKS/<own name>".
# ===================================================================
MAPPER="$SCRIPT_DIR/suites_for_files.sh"

# Synthetic git runs ignore the user's global and system config (hooks
# path, signing, default branch).
sgit() {
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
        git -c user.name=syn -c user.email=syn@example.invalid \
            -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}

# write_syn_suite <tests-dir> <name> <body>: a suite that runs <body> and
# then marks itself as run.
write_syn_suite() {
    local d="$1" name="$2" body="$3"
    {
        printf '#!/usr/bin/env bash\n'
        printf '%s\n' "$body"
        printf 'touch "${SYN_MARKS:?}/$(basename "${BASH_SOURCE[0]}")"\n'
    } > "$d/$name"
    chmod +x "$d/$name"
}

# make_syn_repo <dir>: the fixture repository, committed on main, with a
# `feature` branch checked out at the same commit.
make_syn_repo() {
    local r="$1" t="$1/.agent/scripts/tests" sd='SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
    mkdir -p "$t" "$r/.agent/docs" "$r/outside"
    cat > "$r/.pre-commit-config.yaml" <<'EOF'
repos:
  - repo: local
    hooks:
      - id: validate-script-tests
        name: synthetic
        entry: bash .agent/scripts/tests/run_script_tests.sh --files
        language: system
        pass_filenames: true
        require_serial: true
        files: ^(\.agent/|Makefile$|\.pre-commit-config\.yaml$)
        exclude: ^\.agent/work-plans/
      - id: unrelated
        name: unrelated
        entry: "true"
        language: system
        files: ^nothing$
EOF
    printf 'all:\n\ttrue\n' > "$r/Makefile"
    printf '#!/usr/bin/env bash\nbash "$(dirname "$0")/beta.sh"\n' > "$r/.agent/scripts/alpha.sh"
    printf '#!/usr/bin/env bash\necho beta\n' > "$r/.agent/scripts/beta.sh"
    printf '#!/usr/bin/env bash\necho gamma\n' > "$r/.agent/scripts/gamma.sh"
    printf '#!/usr/bin/env bash\nbash "$(dirname "$0")/gamma.sh"\ncat "$(dirname "$0")/../docs/scanned.md" >/dev/null\n' > "$r/.agent/scripts/other.sh"
    printf '#!/usr/bin/env bash\necho lone\n' > "$r/.agent/scripts/lone.sh"
    printf '#!/usr/bin/env bash\necho helper\n' > "$r/.agent/scripts/_helper.sh"
    printf '#!/usr/bin/env bash\necho identity\n' > "$r/.agent/scripts/set_git_identity_env.sh"
    printf 'X = 1\n' > "$r/.agent/scripts/mod_x.py"
    printf '# scanned\n' > "$r/.agent/docs/scanned.md"
    printf '# unmapped\n' > "$r/.agent/docs/unmapped.md"
    printf 'data\n' > "$t/fixture_data.txt"
    printf 'data\n' > "$t/helper_data.txt"
    write_syn_suite "$t" test_checkpoint_269.sh ':'
    write_syn_suite "$t" test_alpha.sh "# gamma.sh is named only in this comment line.
$sd
bash \"\$SCRIPT_DIR/../alpha.sh\" >/dev/null"
    write_syn_suite "$t" test_other.sh "$sd
bash \"\$SCRIPT_DIR/../other.sh\" >/dev/null"
    write_syn_suite "$t" test_pyimp.sh "$sd
PYTHONDONTWRITEBYTECODE=1 python3 - \"\$SCRIPT_DIR/..\" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import mod_x
PY"
    write_syn_suite "$t" test_noref.sh ':'
    write_syn_suite "$t" test_scanner.sh '# scans: .agent/docs/ .agent/scripts/tests/'
    write_syn_suite "$t" test_covered.sh '# covers: .agent/scripts/tests/fixture_data.txt'
    write_syn_suite "$t" test_always.sh '# covers: ALL'
    sgit init -q "$r" && sgit -C "$r" add -A && sgit -C "$r" commit -q -m base \
        && sgit -C "$r" checkout -q -b feature
}

SYN="$TMPD/syn"
make_syn_repo "$SYN" || fail "(l) could not build the synthetic repository"
SYN_T="$SYN/.agent/scripts/tests"
shopt -s nullglob
syn_suites=("$SYN_T"/test_*.sh)
shopt -u nullglob
SYN_N=${#syn_suites[@]}

# sfor <file>...: the mapper's stdout for the synthetic repo, as one line.
sfor() { bash "$MAPPER" --tests-dir "$SYN_T" "$@" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'; }

# --- Case (l): the mapper on the synthetic repo. ---
expect_sel() {  # <label> <expected one-line output> <mapper args>...
    local label="$1" want="$2" got
    shift 2
    got="$(sfor "$@")"
    if [[ "$got" == "$want" ]]; then
        pass "(l) $label"
    else
        fail "(l) $label: expected '$want', got '$got'"
    fi
}
BASE_ALWAYS="test_always.sh test_checkpoint_269.sh"
expect_sel "a script maps to a strict subset (its suite, the required suite, '# covers: ALL', and the suite with no references)" \
    "test_alpha.sh $BASE_ALWAYS test_noref.sh" -- .agent/scripts/beta.sh
expect_sel "a comment-only mention does not select a suite (gamma.sh: test_other.sh, not test_alpha.sh)" \
    "$BASE_ALWAYS test_noref.sh test_other.sh" -- .agent/scripts/gamma.sh
expect_sel "'import mod_x' selects the suite for mod_x.py" \
    "$BASE_ALWAYS test_noref.sh test_pyimp.sh" -- .agent/scripts/mod_x.py
expect_sel "a mapped file under a '# scans:' prefix adds the scanning suite" \
    "$BASE_ALWAYS test_noref.sh test_other.sh test_scanner.sh" -- .agent/docs/scanned.md
expect_sel "an exact-file '# covers:' file under tests/ selects its suite, not ALL" \
    "$BASE_ALWAYS test_covered.sh test_noref.sh test_scanner.sh" -- .agent/scripts/tests/fixture_data.txt
expect_sel "a changed suite selects itself" \
    "test_alpha.sh $BASE_ALWAYS test_noref.sh test_scanner.sh" -- .agent/scripts/tests/test_alpha.sh
# pre-commit passes only files its own files:/exclude: match, so a passed
# file the mapper's parse calls out of scope is a disagreement: run all.
expect_sel "a passed file outside the hook scope yields ALL" "ALL" -- README.md .agent/scripts/beta.sh
expect_sel "an absolute path (outside the scope as parsed) yields ALL" "ALL" -- "$SYN/.agent/scripts/beta.sh"
expect_sel "an out-of-scope deleted path does not force ALL" \
    "test_alpha.sh $BASE_ALWAYS test_noref.sh" --deleted outside/gone.sh -- .agent/scripts/beta.sh
expect_sel "an unmapped in-scope file yields ALL, even under a '# scans:' prefix" "ALL" -- .agent/docs/unmapped.md
expect_sel "no files yields ALL" "ALL" --
expect_sel "a deleted in-scope path yields ALL" "ALL" --deleted .agent/scripts/lone.sh -- .agent/scripts/beta.sh
for trig in .agent/scripts/tests/run_script_tests.sh .agent/scripts/tests/suites_for_files.sh \
        .agent/scripts/tests/helper_data.txt .pre-commit-config.yaml Makefile \
        .agent/scripts/set_git_identity_env.sh .agent/scripts/_helper.sh .agent/scripts/_not_yet_written.sh; do
    expect_sel "full-run trigger $trig yields ALL" "ALL" -- .agent/scripts/beta.sh "$trig"
done
# The hook's files:/exclude: values written as quoted YAML scalars (the
# same regexes to pre-commit) give the same selection as plain ones; a
# files: regex that matches no tracked file means the parse is wrong: ALL.
# yaml_case <label> <expected> <files: value> <exclude: value>
yaml_case() {
    local label="$1" want="$2" fval="$3" xval="$4" r="$TMPD/syn_yaml" got
    rm -rf "$r"
    make_syn_repo "$r" || { fail "(l) $label: could not build the repository"; return; }
    FVAL="$fval" XVAL="$xval" python3 - "$r/.pre-commit-config.yaml" <<'PY'
import os, sys
p = sys.argv[1]
lines = open(p).read().splitlines()
lines = ["        files: " + os.environ["FVAL"] if l.startswith("        files: ^(") else
         "        exclude: " + os.environ["XVAL"] if l.startswith("        exclude: ") else l
         for l in lines]
open(p, "w").write("\n".join(lines) + "\n")
PY
    got="$(bash "$MAPPER" --tests-dir "$r/.agent/scripts/tests" -- .agent/scripts/beta.sh 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
    if [[ "$got" == "$want" ]]; then
        pass "(l) $label"
    else
        fail "(l) $label: expected '$want', got '$got'"
    fi
    rm -rf "$r"
}
SYN_FILES='^(\.agent/|Makefile$|\.pre-commit-config\.yaml$)'
yaml_case "single-quoted files:/exclude: give the same selection as plain" \
    "test_alpha.sh $BASE_ALWAYS test_noref.sh" "'$SYN_FILES'" "'^\.agent/work-plans/'"
yaml_case "double-quoted files:/exclude: give the same selection as plain" \
    "test_alpha.sh $BASE_ALWAYS test_noref.sh" "\"${SYN_FILES//\\/\\\\}\"" '"^\\.agent/work-plans/"'
yaml_case "a plain files: value with a trailing comment gives the same selection" \
    "test_alpha.sh $BASE_ALWAYS test_noref.sh" "$SYN_FILES  # scope" '^\.agent/work-plans/'
yaml_case "a files: regex no tracked file matches yields ALL" "ALL" '^nothing-tracked/' '^\.agent/work-plans/'
yaml_case "a block-scalar files: value yields ALL" "ALL" '>' '^\.agent/work-plans/'

NOT_GIT="$TMPD/not_git_tests"
mkdir -p "$NOT_GIT"
if [[ "$(bash "$MAPPER" --tests-dir "$NOT_GIT" -- .agent/scripts/beta.sh 2>/dev/null)" == "ALL" ]]; then
    pass "(l) an error (tests dir outside any git repository) yields ALL"
else
    fail "(l) an error (tests dir outside any git repository) yields ALL"
fi

# run_syn <marks-dir> <runner args>...: run the runner from the synthetic
# repo root (as pre-commit would), recording which suites ran.
run_syn() {
    local marks="$1"
    shift
    rm -rf "$marks" && mkdir -p "$marks"
    (cd "$SYN" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 SYN_MARKS="$marks" "$RUNNER" "$@" 2>&1)
}
ran() { (cd "$1" && ls | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'); }

# --- Case (m): the runner in --files mode runs only the chosen suites. ---
M_MARKS="$TMPD/m_marks"
out=$(run_syn "$M_MARKS" "$SYN_T" --files .agent/scripts/beta.sh); rc=$?
if [[ $rc -eq 0 && "$(ran "$M_MARKS")" == "test_alpha.sh test_always.sh test_checkpoint_269.sh test_noref.sh" ]] \
        && printf '%s' "$out" | grep -q "scoped run, 4 of $SYN_N suites"; then
    pass "(m) --files runs only the selected suites and says so"
else
    fail "(m) --files runs only the selected suites (rc=$rc, ran=$(ran "$M_MARKS"), out=$out)"
fi

# --- Case (n): full runs. The count comes from the glob, not a literal. ---
check_full() {  # <label> <runner args>...
    local label="$1" out rc
    shift
    out=$(run_syn "$TMPD/n_marks" "$SYN_T" "$@"); rc=$?
    local n_ran
    n_ran=$(find "$TMPD/n_marks" -mindepth 1 | wc -l | tr -d ' ')
    if [[ $rc -eq 0 && "$n_ran" -eq $SYN_N ]] && printf '%s' "$out" | grep -q "all $SYN_N suites passed"; then
        pass "(n) $label runs all $SYN_N suites"
    else
        fail "(n) $label runs all $SYN_N suites (rc=$rc, ran=$n_ran, out=$out)"
    fi
}
check_full "no --files (make lint / --all-files without a list)"
check_full "--files naming the runner (what --all-files passes)" --files .agent/scripts/tests/run_script_tests.sh .agent/scripts/beta.sh
check_full "--files with no files" --files
many=()
for _ in $(seq 1 201); do many+=(".agent/scripts/beta.sh"); done
check_full "--files with more than 200 files" --files "${many[@]}"

# --- Case (o): deletions and renames through a real git hook. pre-commit
#     would pass only the edited file, so the hook passes just beta.sh; the
#     runner has to find the deletion itself, from the index the commit is
#     building (GIT_INDEX_FILE), before it unsets the GIT_* variables. ---
# hook_case <label> <want: full|scoped> <setup-and-commit commands>
hook_case() {
    local label="$1" want="$2" cmds="$3"
    local r="$TMPD/hook_$label" hooks="$TMPD/hooks_$label" log="$TMPD/hook_$label.log"
    rm -rf "$r" "$hooks" "$log"
    make_syn_repo "$r" || { fail "(o) $label: could not build the repository"; return; }
    mkdir -p "$hooks"
    printf '#!/usr/bin/env bash\nbash %q %q --files .agent/scripts/beta.sh > %q 2>&1\n' \
        "$RUNNER" "$r/.agent/scripts/tests" "$log" > "$hooks/pre-commit"
    chmod +x "$hooks/pre-commit"
    sgit -C "$r" config core.hooksPath "$hooks"
    mkdir -p "$TMPD/o_marks"
    local rc
    (cd "$r" && export SYN_MARKS="$TMPD/o_marks" && eval "$cmds") >/dev/null 2>&1; rc=$?
    local outl
    outl="$(cat "$log" 2>/dev/null)"
    if [[ $rc -ne 0 || -z "$outl" ]]; then
        fail "(o) $label: the commit or its hook did not run (rc=$rc, log=$outl)"
    elif [[ "$want" == full ]] && printf '%s' "$outl" | grep -q 'full run' \
            && printf '%s' "$outl" | grep -q 'deleted or renamed away'; then
        pass "(o) $label: full run, the deletion named"
    elif [[ "$want" == scoped ]] && printf '%s' "$outl" | grep -q 'scoped run'; then
        pass "(o) $label: scoped run"
    else
        fail "(o) $label: expected a $want run; hook log: $outl"
    fi
    rm -rf "$r" "$hooks" "$log" "$TMPD/o_marks"
}
EDIT_BETA='echo "echo edited" >> .agent/scripts/beta.sh'
hook_case commit_a full "rm .agent/scripts/other.sh && $EDIT_BETA && sgit commit -q -a -m d"
hook_case pathspec full "rm .agent/scripts/other.sh && $EDIT_BETA && sgit commit -q -m d -- .agent/scripts/other.sh .agent/scripts/beta.sh"
hook_case rename_out full "sgit mv .agent/scripts/other.sh outside/other.sh && $EDIT_BETA && sgit add .agent/scripts/beta.sh && sgit commit -q -m d"
hook_case edit_only scoped "$EDIT_BETA && sgit commit -q -a -m d"

# --- Case (p): a branch run (nothing staged) sees a deletion made earlier
#     on the branch; a commit with something staged does not. ---
P="$TMPD/syn_p"
make_syn_repo "$P" && sgit -C "$P" rm -q .agent/scripts/other.sh && sgit -C "$P" commit -q -m "delete other.sh"
p_run() {
    rm -rf "$TMPD/p_marks" && mkdir -p "$TMPD/p_marks"
    (cd "$P" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 SYN_MARKS="$TMPD/p_marks" \
        "$RUNNER" "$P/.agent/scripts/tests" --files .agent/scripts/beta.sh 2>&1)
}
out=$(p_run); rc=$?
if [[ $rc -eq 0 ]] && printf '%s' "$out" | grep -q 'full run' && printf '%s' "$out" | grep -q "other.sh' is deleted"; then
    pass "(p) branch run: an in-scope deletion earlier on the branch forces a full run"
else
    fail "(p) branch run: an in-scope deletion earlier on the branch forces a full run (rc=$rc, out=$out)"
fi
echo "echo edited" >> "$P/.agent/scripts/beta.sh"
sgit -C "$P" add .agent/scripts/beta.sh
out=$(p_run); rc=$?
if [[ $rc -eq 0 ]] && printf '%s' "$out" | grep -q 'scoped run'; then
    pass "(p) with an edit staged, an earlier branch deletion does not force a full run"
else
    fail "(p) with an edit staged, an earlier branch deletion does not force a full run (rc=$rc, out=$out)"
fi


echo ""
echo "test_run_script_tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
