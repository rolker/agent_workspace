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
# recursive listing in the leak message. (l)–(r) cover the --files mode
# added for issue #410: (l) suites_for_files.sh's selection rules, (m) a
# scoped run, (n) the full runs (no --files, the runner in the list, no
# files, over 200 files), (o) deletions and renames through a real git
# hook (`git commit -a`, a pathspec commit, a rename out of the hook's
# scope, and an edit-only control), (p) the branch run, (q) a non-ASCII
# deletion on the branch, (r) no default branch to diff against. (s1)–(s4)
# pin what a one-job run keeps (issue #444): exit codes, header and running
# lines, the stop at the first failure, leak attribution, live output.
# (t1) and (u5) cover the late leak caught by the second sweep; (u1)–(u8)
# and (v) the job pool: the job count and the argument order, hidden and
# shown output, unmixed failure output, every suite run and the exit code
# by list order, attribution while suites overlap, trappable SIGINT and
# SIGQUIT, the interrupt with its 5-second KILL backstop, a second signal
# cutting the stop short, processes a finished suite left running, and
# --shuffle.
#
# Every case runs against a scratch copy of a tests directory
# (run_script_tests.sh's optional [tests-dir] argument), never the real
# .agent/scripts/tests/ — so this suite's own pass/fail never depends on
# which suites currently live in this repo. The real-tree checks of the
# suite map live in test_script_tests_hook_scope.sh.
#
# Run: bash .agent/scripts/tests/test_run_script_tests.sh

set -u
# Every nested run below names its job count (-j 1 in the one-job cases),
# except the cases about the default and RUN_SCRIPT_TESTS_JOBS themselves;
# an outer run's setting is not inherited.
unset RUN_SCRIPT_TESTS_JOBS
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

out=$("$RUNNER" -j 1 "$CASE_A" 2>&1); rc=$?
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

out=$("$RUNNER" -j 1 "$CASE_B" 2>&1); rc=$?
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

out=$("$RUNNER" -j 1 "$CASE_C" 2>&1); rc=$?
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
out=$(PATH="$TMPD/bin_nojq" "$RUNNER" -j 1 "$CASE_D" 2>&1); rc=$?
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

out=$("$RUNNER" -j 1 "$CASE_E" 2>&1); rc=$?
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

out=$("$RUNNER" -j 1 "$CASE_F" 2>&1); rc=$?
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

out=$(TMPDIR="$CALLER_TMPDIR" "$RUNNER" -j 1 "$CASE_G" 2>&1); rc=$?
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

out=$("$RUNNER" -j 1 "$CASE_H" 2>&1); rc=$?
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
    out=$("$RUNNER" -j 1 "$dir" 2>&1); rc=$?
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

out=$("$RUNNER" -j 1 "$CASE_J" 2>&1); rc=$?
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

out=$("$RUNNER" -j 1 "$CASE_J2" 2>&1); rc=$?
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

out=$("$RUNNER" -j 1 "$CASE_K" 2>&1); rc=$?
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
    mkdir -p "$r/.agent/scripts/pkg"
    : > "$r/.agent/scripts/pkg/__init__.py"
    printf 'Y = 1\n' > "$r/.agent/scripts/pkg/mod_y.py"
    printf 'B = 1\n' > "$r/.agent/scripts/pkg/mod_b.py"
    printf 'C = 1\n' > "$r/.agent/scripts/pkg/mod_c.py"
    printf 'D = 1\n' > "$r/.agent/scripts/pkg/mod_d.py"
    printf 'E = 1\n' > "$r/.agent/scripts/pkg/mod_e.py"
    printf 'F = 1\n' > "$r/.agent/scripts/pkg/mod_f.py"
    printf 'G = 1\n' > "$r/.agent/scripts/mod_g.py"
    printf 'H = 1\n' > "$r/.agent/scripts/mod_h.py"
    printf 'anchor\n' > "$r/.agent/scripts/anchor.txt"
    printf '#!/usr/bin/env bash\necho tool\n' > "$r/.agent/scripts/tool"
    chmod +x "$r/.agent/scripts/tool"
    printf '# scanned\n' > "$r/.agent/docs/scanned.md"
    printf '# unmapped\n' > "$r/.agent/docs/unmapped.md"
    # A document no suite names and no '# scans:' prefix covers (issue #419).
    printf '# guide\n' > "$r/.agent/guide.md"
    printf 'data\n' > "$t/fixture_data.txt"
    mkdir -p "$r/.agent/work-plans/issue-1"
    printf '# plan\n' > "$r/.agent/work-plans/issue-1/plan.md"
    printf 'data\n' > "$t/helper_data.txt"
    write_syn_suite "$t" test_checkpoint_269.sh ':'
    write_syn_suite "$t" test_alpha.sh "# gamma.sh is named only in this comment line.
$sd
: .agent/work-plans/issue-1/plan.md  # maps only if the exclude: regex is lost
bash \"\$SCRIPT_DIR/../alpha.sh\" >/dev/null"
    write_syn_suite "$t" test_other.sh "$sd
bash \"\$SCRIPT_DIR/../other.sh\" >/dev/null"
    write_syn_suite "$t" test_pyimp.sh "$sd
PYTHONDONTWRITEBYTECODE=1 python3 - \"\$SCRIPT_DIR/..\" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import mod_x
PY"
    write_syn_suite "$t" test_dotslash.sh "$sd
(cd \"\$SCRIPT_DIR/..\" && ./tool >/dev/null)"
    write_syn_suite "$t" test_fromimp.sh "$sd
PYTHONDONTWRITEBYTECODE=1 python3 - \"\$SCRIPT_DIR/..\" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from pkg import mod_y
from pkg import (
    mod_b,  # named only on this continuation line; see f() for why
    mod_c,
)
PY"
    # This file's own text must not hold the unreadable import, or this
    # suite would count every .py in the real repository as referenced.
    local kw_from=from kw_import=import
    write_syn_suite "$t" test_backslash.sh "$sd
PYTHONDONTWRITEBYTECODE=1 python3 - \"\$SCRIPT_DIR/..\" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
${kw_from} pkg ${kw_import} mod_d, \\
    mod_e
PY"
    # Imports that do not start their line, each module named only once:
    # inside a `python3 -c "..."`, after a `;`, after a `:`. The echo is
    # prose that starts a piece with `import `; it must not make this suite
    # fall back to every .py (mod_x.py's selection below shows it does not).
    # Both suites read anchor.txt so each has a reference a mapper that
    # misses the imports still sees: otherwise the "no derived references"
    # rule would select them everywhere and hide the miss.
    write_syn_suite "$t" test_pyc.sh "$sd
cat \"\$SCRIPT_DIR/../anchor.txt\" >/dev/null
echo \"import failed for optional layer\" >/dev/null
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=\"\$SCRIPT_DIR/..\" python3 -c \"from pkg import mod_f\"
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=\"\$SCRIPT_DIR/..\" python3 - <<'PY'
x = 1; import mod_g
try: import mod_h
except ImportError: raise
PY"
    # A mid-line import the parser cannot read (`*`), assembled here for
    # the same reason as test_backslash.sh's.
    write_syn_suite "$t" test_midstar.sh "$sd
cat \"\$SCRIPT_DIR/../anchor.txt\" >/dev/null
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=\"\$SCRIPT_DIR/..\" python3 -c \"${kw_from} pkg ${kw_import} *\""
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
# test_backslash.sh (a `\` continuation) and test_midstar.sh (a `*` inside
# a `python3 -c "..."`) each have an import the parser cannot fully read,
# so each counts every .py file as referenced: both join every .py file's
# selection below, though neither names the file. test_fromimp.sh and
# test_pyc.sh read fully, so they do not join mod_x.py's.
expect_sel "'import mod_x' selects the suite for mod_x.py (and both unreadable-import suites, not test_fromimp.sh or test_pyc.sh)" \
    "test_always.sh test_backslash.sh test_checkpoint_269.sh test_midstar.sh test_noref.sh test_pyimp.sh" -- .agent/scripts/mod_x.py
expect_sel "an extensionless script run as './tool' selects its suite" \
    "$BASE_ALWAYS test_dotslash.sh test_noref.sh" -- .agent/scripts/tool
expect_sel "'from pkg import mod_y' selects the suite for pkg/mod_y.py" \
    "test_always.sh test_backslash.sh test_checkpoint_269.sh test_fromimp.sh test_midstar.sh test_noref.sh" -- .agent/scripts/pkg/mod_y.py
expect_sel "a name on a continuation line of a parenthesised from-import list selects the suite for pkg/mod_b.py" \
    "test_always.sh test_backslash.sh test_checkpoint_269.sh test_fromimp.sh test_midstar.sh test_noref.sh" -- .agent/scripts/pkg/mod_b.py
expect_sel "a name after a ')' in an inline comment of a parenthesised from-import list selects the suite for pkg/mod_c.py" \
    "test_always.sh test_backslash.sh test_checkpoint_269.sh test_fromimp.sh test_midstar.sh test_noref.sh" -- .agent/scripts/pkg/mod_c.py
expect_sel "a name after a '\\' continuation selects the suite (fallback) for pkg/mod_e.py" \
    "test_always.sh test_backslash.sh test_checkpoint_269.sh test_midstar.sh test_noref.sh" -- .agent/scripts/pkg/mod_e.py
expect_sel "an import statement inside a python3 -c string selects the suite for pkg/mod_f.py" \
    "test_always.sh test_backslash.sh test_checkpoint_269.sh test_midstar.sh test_noref.sh test_pyc.sh" -- .agent/scripts/pkg/mod_f.py
expect_sel "an import statement after a semicolon selects the suite for mod_g.py" \
    "test_always.sh test_backslash.sh test_checkpoint_269.sh test_midstar.sh test_noref.sh test_pyc.sh" -- .agent/scripts/mod_g.py
expect_sel "an import statement after the colon of a try line selects the suite for mod_h.py" \
    "test_always.sh test_backslash.sh test_checkpoint_269.sh test_midstar.sh test_noref.sh test_pyc.sh" -- .agent/scripts/mod_h.py
# Each import shape below is written as the only import in a suite of its
# own (shape_case), which also reads anchor.txt so the "no derived
# references" rule cannot select it. A shape that hides a name must make
# the suite count every .py as referenced: it is selected for mod_x.py,
# which it never names. A shape that cannot be Python must not. Each is a
# printf format whose %s are the keywords, so this file's own text holds no
# import word the mapper cannot read.
# shape_case <label> <yes|no: selected for mod_x.py> <printf format> <arg>...
shape_case() {
    local label="$1" want="$2" fmt="$3" got sel=no
    shift 3
    # shellcheck disable=SC2059  # the format is the case
    write_syn_suite "$SYN_T" test_shape.sh "$(printf '%s\ncat "$SCRIPT_DIR/../anchor.txt" >/dev/null\n' \
        'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"')
$(printf "$fmt" "$@")"
    got="$(sfor -- .agent/scripts/mod_x.py)"
    rm -f "$SYN_T/test_shape.sh"
    [[ " $got " == *" test_shape.sh "* ]] && sel=yes
    if [[ "$sel" == "$want" ]]; then
        pass "(l) $label"
    else
        fail "(l) $label: expected selected=$want for mod_x.py, got '$got'"
    fi
}
KW_FROM=from KW_IMPORT=import
shape_case "a '\\' after 'from pkg' falls back (the suite runs)" yes '%s pkg \\\n    %s mod_d, mod_e\n' "$KW_FROM" "$KW_IMPORT"
shape_case "a '\\' after 'from pkg.sub' falls back (the suite runs)" yes '%s pkg.sub \\\n    %s mod_d\n' "$KW_FROM" "$KW_IMPORT"
shape_case "a '\\' right after 'from' falls back (the suite runs)" yes '%s \\\n pkg %s mod_d\n' "$KW_FROM" "$KW_IMPORT"
shape_case "a name list cut by a quote with a dangling comma falls back (the suite runs)" yes \
    'python3 -c "%s mod_d, "%smod_e%s\n' "$KW_IMPORT" "'" "'"
shape_case "a clean list with a string glued after it falls back (the suite runs)" yes \
    'python3 -c "%s mod_d"", mod_e"\n' "$KW_IMPORT"
shape_case "a 'from pkg' header with the rest in a glued string falls back (the suite runs)" yes \
    'python3 -c "%s pkg "%s%s mod_d%s\n' "$KW_FROM" "'" "$KW_IMPORT" "'"
shape_case "an import line no pattern reads falls back (the suite runs)" yes '%s !!mod_d\n' "$KW_IMPORT"
shape_case "an import after an escaped newline is read as a statement (no fallback)" no \
    'python3 -c $%sx = 1\\n%s mod_d%s\n' "'" "$KW_IMPORT" "'"
shape_case "prose 'import failed for layer' is not Python (no fallback)" no \
    'echo "WARNING: %s failed for optional layer"\n' "$KW_IMPORT"
shape_case "a command 'vcs import --skip-existing' is not Python (no fallback)" no \
    'vcs %s --skip-existing src < x.repos\n' "$KW_IMPORT"

# A .py file is read with `ast`, not the piece parser: every relative form
# maps exactly (rel/helper.py's imports resolve inside rel/, so the decoy
# decoy/rel_a.py and the unimported rel/rel_z.py do not select its suite),
# and a .py file `ast` cannot parse falls back. A shell `python3 -c` with a
# dots-only `from` is read by the piece parser and maps its name.
AST="$TMPD/syn_ast"
if make_syn_repo "$AST"; then
    A_S="$AST/.agent/scripts"
    mkdir -p "$A_S/rel/sub" "$A_S/decoy"
    for f in rel/__init__.py rel/sub/__init__.py; do : > "$A_S/$f"; done
    for f in rel/rel_a.py rel/rel_b.py rel/rel_c.py rel/rel_z.py rel/sub/rel_d.py rel/sub/rel_e.py \
            rel_p.py rel_q.py rel_y.py decoy/rel_a.py; do
        printf 'V = 1\n' > "$A_S/$f"
    done
    cat > "$A_S/rel/helper.py" <<'PYEOF'
from .import rel_a
from ..import rel_p, rel_q
from .import(rel_b)
try:
    from . import rel_c
except ImportError:
    rel_c = None
from .sub import (
    rel_d,  # a comment line inside the list
    rel_e,
)
PYEOF
    printf 'import rel_p\ndef broken(:\n    pass\n' > "$A_S/broken.py"
    # String literals in a .py file (a docstring, a subprocess's -c text,
    # an f-string's literal part, a bytes stdin) go through the piece
    # parser too; an absolute import of a package maps its init file.
    mkdir -p "$A_S/libpkg" "$A_S/libpkg2"
    for f in libpkg/__init__.py libpkg2/__init__.py; do : > "$A_S/$f"; done
    for f in str_a.py str_b.py str_d.py str_f.py libpkg/w_mod.py libpkg/other.py; do
        printf 'V = 1\n' > "$A_S/$f"
    done
    cat > "$A_S/runner.py" <<'PYEOF'
"import str_d"
import subprocess
import sys
import libpkg2
from libpkg import w_mod

subprocess.run([sys.executable, "-c", "import str_a"], check=False)
subprocess.run([sys.executable, "-"], input=b"import str_b\n", check=False)
X = 1
CMD = f"import str_f\n{X}"
PYEOF
    write_syn_suite "$A_S/tests" test_pyrun.sh "$(printf '%s\ncat "$SCRIPT_DIR/../runner.py" >/dev/null' \
        'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"')"
    write_syn_suite "$A_S/tests" test_relpkg.sh "$(printf '%s\ncat "$SCRIPT_DIR/../rel/helper.py" >/dev/null' \
        'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"')"
    write_syn_suite "$A_S/tests" test_pybroken.sh "$(printf '%s\ncat "$SCRIPT_DIR/../broken.py" >/dev/null' \
        'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"')"
    write_syn_suite "$A_S/tests" test_shrel.sh "$(printf '%s\ncat "$SCRIPT_DIR/../anchor.txt" >/dev/null\npython3 -c "%s .%s rel_y" 2>/dev/null || :' \
        'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"' "$KW_FROM" "$KW_IMPORT")"
    printf 'anchor\n' > "$A_S/anchor.txt"
    sgit -C "$AST" add -A && sgit -C "$AST" commit -q -m ast || fail "(l) ast: could not commit the fixture"
fi
# ast_sel <label> <file> <suite> <yes|no>: is <suite> selected for <file>?
ast_sel() {
    local label="$1" file="$2" suite="$3" want="$4" got sel=no
    got="$(bash "$MAPPER" --tests-dir "$AST/.agent/scripts/tests" -- "$file" 2>/dev/null | tr '\n' ' ')"
    [[ " $got " == *" $suite "* ]] && sel=yes
    if [[ "$sel" == "$want" && "$got" != "ALL " ]]; then
        pass "(l) $label"
    else
        fail "(l) $label: expected $suite selected=$want for $file, got '$got'"
    fi
}
ast_sel "ast: a dots-only module touching the keyword maps rel/rel_a.py" .agent/scripts/rel/rel_a.py test_relpkg.sh yes
ast_sel "ast: two dots touching the keyword map rel_p.py one level up" .agent/scripts/rel_p.py test_relpkg.sh yes
ast_sel "ast: two dots touching the keyword map rel_q.py, the second name" .agent/scripts/rel_q.py test_relpkg.sh yes
ast_sel "ast: a parenthesis touching the keyword maps rel/rel_b.py" .agent/scripts/rel/rel_b.py test_relpkg.sh yes
ast_sel "ast: an import inside a try block maps rel/rel_c.py" .agent/scripts/rel/rel_c.py test_relpkg.sh yes
ast_sel "ast: a parenthesised multi-line list maps rel/sub/rel_d.py" .agent/scripts/rel/sub/rel_d.py test_relpkg.sh yes
ast_sel "ast: a parenthesised multi-line list maps rel/sub/rel_e.py, after a comment line" .agent/scripts/rel/sub/rel_e.py test_relpkg.sh yes
ast_sel "ast: a relative import resolves in its own directory, not by basename (decoy/rel_a.py)" .agent/scripts/decoy/rel_a.py test_relpkg.sh no
ast_sel "ast: an unimported sibling (rel/rel_z.py) is not selected: no fallback" .agent/scripts/rel/rel_z.py test_relpkg.sh no
ast_sel "ast: a .py file with a syntax error falls back (selected for rel/rel_z.py, which it never names)" .agent/scripts/rel/rel_z.py test_pybroken.sh yes
ast_sel "a shell 'python3 -c' with a dots-only from maps its name (rel_y.py)" .agent/scripts/rel_y.py test_shrel.sh yes
ast_sel "ast: a subprocess's -c string in a .py file maps str_a.py" .agent/scripts/str_a.py test_pyrun.sh yes
ast_sel "ast: a bytes literal fed to a subprocess's stdin maps str_b.py" .agent/scripts/str_b.py test_pyrun.sh yes
ast_sel "ast: a docstring in a .py file is read too (str_d.py)" .agent/scripts/str_d.py test_pyrun.sh yes
ast_sel "ast: an f-string's literal part is read too (str_f.py)" .agent/scripts/str_f.py test_pyrun.sh yes
ast_sel "ast: an absolute from-import of a package maps the module in it (libpkg/w_mod.py)" .agent/scripts/libpkg/w_mod.py test_pyrun.sh yes
ast_sel "ast: an absolute from-import of a package maps its init file (libpkg)" .agent/scripts/libpkg/__init__.py test_pyrun.sh yes
ast_sel "ast: a plain import of a package maps its init file (libpkg2)" .agent/scripts/libpkg2/__init__.py test_pyrun.sh yes
ast_sel "ast: a package import does not map the package's other modules (libpkg/other.py)" .agent/scripts/libpkg/other.py test_pyrun.sh no
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
# Issue #419: a Markdown file that reaches no suite is documentation, not
# an undeclared file. It adds only its '# scans:' suites; every other
# unmapped in-scope file still yields ALL.
expect_sel "an unmapped .md is documentation: no ALL, only the scanning suite joins" \
    "$BASE_ALWAYS test_noref.sh test_scanner.sh" -- .agent/docs/unmapped.md
expect_sel "an unmapped .md outside every '# scans:' prefix selects no extra suite" \
    "$BASE_ALWAYS test_noref.sh" -- .agent/guide.md
BETA_ALONE="$(sfor -- .agent/scripts/beta.sh)"
expect_sel "an unmapped .md with a script selects what the script alone selects" \
    "$BETA_ALONE" -- .agent/guide.md .agent/scripts/beta.sh
expect_sel "an unmapped .md under a '# scans:' prefix with a script adds only the scanning suite" \
    "test_alpha.sh $BASE_ALWAYS test_noref.sh test_scanner.sh" -- .agent/docs/unmapped.md .agent/scripts/beta.sh
expect_sel "a deleted in-scope .md still yields ALL" "ALL" --deleted .agent/docs/gone.md -- .agent/scripts/beta.sh
expect_sel "an unmapped in-scope .json yields ALL, even under a '# scans:' prefix" "ALL" -- .agent/docs/unmapped.json
expect_sel "an undeclared script yields ALL" "ALL" -- .agent/scripts/lone.sh
expect_sel "an undeclared .md under tests/ yields ALL" "ALL" -- .agent/scripts/tests/notes.md
doc_err="$(bash "$MAPPER" --tests-dir "$SYN_T" -- .agent/guide.md 2>&1 >/dev/null)"
if [[ "$doc_err" == *"'.agent/guide.md' is documentation and reaches no suite"* ]]; then
    pass "(l) the mapper says an unmapped .md is documentation"
else
    fail "(l) the mapper says an unmapped .md is documentation: stderr was '$doc_err'"
fi
lone_err="$(bash "$MAPPER" --tests-dir "$SYN_T" -- .agent/scripts/lone.sh 2>&1 >/dev/null)"
if [[ "$lone_err" == *"'.agent/scripts/lone.sh' maps to no suite"* ]]; then
    pass "(l) the mapper says an undeclared script maps to no suite"
else
    fail "(l) the mapper says an undeclared script maps to no suite: stderr was '$lone_err'"
fi
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
# yaml_case <label> <expected> <files: value> <exclude: value> [<expected exclude probe, default ALL>]
yaml_case() {
    local label="$1" want="$2" fval="$3" xval="$4" xwant="${5:-ALL}" r="$TMPD/syn_yaml" got xgot
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
    # Exclude probe: test_alpha.sh names a tracked work-plans file, so a
    # lost exclude: regex would put it in scope and select test_alpha.sh;
    # parsed, it is out of scope and passing it gives ALL.
    xgot="$(bash "$MAPPER" --tests-dir "$r/.agent/scripts/tests" -- .agent/work-plans/issue-1/plan.md 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
    if [[ "$got" == "$want" && "$xgot" == "$xwant" ]]; then
        pass "(l) $label"
    else
        fail "(l) $label: expected '$want' and the exclude probe '$xwant', got '$got' and '$xgot'"
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
yaml_case "an exclude: regex that excludes nothing changes the exclude probe (the probe has teeth)" \
    "test_alpha.sh $BASE_ALWAYS test_noref.sh" "'$SYN_FILES'" "'^nothing-excluded/'" \
    "test_alpha.sh $BASE_ALWAYS test_noref.sh"
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
out=$(run_syn "$M_MARKS" -j 1 "$SYN_T" --files .agent/scripts/beta.sh); rc=$?
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
    out=$(run_syn "$TMPD/n_marks" -j 1 "$SYN_T" "$@"); rc=$?
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
    printf '#!/usr/bin/env bash\nbash %q -j 1 %q --files .agent/scripts/beta.sh > %q 2>&1\n' \
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
# A non-ASCII path: git C-quotes it in a plain --name-only list
# ("caf\303\251.sh"), which no scope regex matches; the runner reads -z.
# The first commit's hook log is overwritten by the deletion commit's.
CAFE='.agent/scripts/café.sh'
hook_case non_ascii full "echo 'echo cafe' > $CAFE && sgit add $CAFE && sgit commit -q -m add \
    && sgit rm -q $CAFE && $EDIT_BETA && sgit commit -q -a -m d"

# --- Case (p): a branch run sees a deletion made earlier on the branch,
#     with or without something staged; a commit (git sets GIT_INDEX_FILE
#     for its hooks) checks only its own staged deletions. ---
P="$TMPD/syn_p"
make_syn_repo "$P" && sgit -C "$P" rm -q .agent/scripts/other.sh && sgit -C "$P" commit -q -m "delete other.sh"
p_run() {
    rm -rf "$TMPD/p_marks" && mkdir -p "$TMPD/p_marks"
    (cd "$P" && unset GIT_INDEX_FILE && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 SYN_MARKS="$TMPD/p_marks" \
        "$RUNNER" -j 1 "$P/.agent/scripts/tests" --files .agent/scripts/beta.sh 2>&1)
}
out=$(p_run); rc=$?
if [[ $rc -eq 0 ]] && printf '%s' "$out" | grep -q 'full run' && printf '%s' "$out" | grep -q "other.sh' is deleted"; then
    pass "(p) branch run, nothing staged: an in-scope deletion earlier on the branch forces a full run"
else
    fail "(p) branch run, nothing staged: an in-scope deletion earlier on the branch forces a full run (rc=$rc, out=$out)"
fi
echo "echo edited" >> "$P/.agent/scripts/beta.sh"
sgit -C "$P" add .agent/scripts/beta.sh
out=$(p_run); rc=$?
if [[ $rc -eq 0 ]] && printf '%s' "$out" | grep -q 'full run' && printf '%s' "$out" | grep -q "other.sh' is deleted"; then
    pass "(p) branch run with an edit staged: the earlier branch deletion still forces a full run"
else
    fail "(p) branch run with an edit staged: the earlier branch deletion still forces a full run (rc=$rc, out=$out)"
fi
P_HOOKS="$TMPD/p_hooks" P_LOG="$TMPD/p_hook.log"
mkdir -p "$P_HOOKS" "$TMPD/p_marks"
printf '#!/usr/bin/env bash\nbash %q -j 1 %q --files .agent/scripts/beta.sh > %q 2>&1\n' \
    "$RUNNER" "$P/.agent/scripts/tests" "$P_LOG" > "$P_HOOKS/pre-commit"
chmod +x "$P_HOOKS/pre-commit"
sgit -C "$P" config core.hooksPath "$P_HOOKS"
(cd "$P" && export SYN_MARKS="$TMPD/p_marks" && sgit commit -q -m edit) >/dev/null 2>&1; rc=$?
out="$(cat "$P_LOG" 2>/dev/null)"
if [[ $rc -eq 0 ]] && printf '%s' "$out" | grep -q 'scoped run'; then
    pass "(p) a commit with an edit staged checks only its own deletions: scoped run"
else
    fail "(p) a commit with an edit staged checks only its own deletions: scoped run (rc=$rc, log=$out)"
fi
rm -rf "$P_HOOKS" "$P_LOG"

# --- Case (q): a branch run sees a non-ASCII deletion made earlier on the
#     branch (git -z output, not C-quoted). ---
Q="$TMPD/syn_q"
make_syn_repo "$Q" && sgit -C "$Q" checkout -q main \
    && echo 'echo cafe' > "$Q/$CAFE" && sgit -C "$Q" add "$CAFE" && sgit -C "$Q" commit -q -m "add café" \
    && sgit -C "$Q" checkout -q -B feature && sgit -C "$Q" rm -q "$CAFE" && sgit -C "$Q" commit -q -m "delete café"
rm -rf "$TMPD/q_marks" && mkdir -p "$TMPD/q_marks"
out=$(cd "$Q" && unset GIT_INDEX_FILE && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 SYN_MARKS="$TMPD/q_marks" \
    "$RUNNER" -j 1 "$Q/.agent/scripts/tests" --files .agent/scripts/beta.sh 2>&1); rc=$?
if [[ $rc -eq 0 ]] && printf '%s' "$out" | grep -q 'full run' && printf '%s' "$out" | grep -q "café.sh' is deleted"; then
    pass "(q) branch run: a non-ASCII in-scope deletion earlier on the branch forces a full run"
else
    fail "(q) branch run: a non-ASCII in-scope deletion earlier on the branch forces a full run (rc=$rc, out=$out)"
fi

# --- Case (r): no default branch to diff against (CI's shallow checkout
#     has no `main`): a branch run runs every suite, in one plain line
#     with no ERROR text. ---
R="$TMPD/syn_r"
make_syn_repo "$R" && sgit -C "$R" branch -q -D main
rm -rf "$TMPD/r_marks" && mkdir -p "$TMPD/r_marks"
out=$(cd "$R" && unset GIT_INDEX_FILE && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 SYN_MARKS="$TMPD/r_marks" \
    "$RUNNER" -j 1 "$R/.agent/scripts/tests" --files .agent/scripts/beta.sh 2>&1); rc=$?
r_ran=$(find "$TMPD/r_marks" -mindepth 1 | wc -l | tr -d ' ')
if [[ $rc -eq 0 && "$r_ran" -eq $SYN_N ]] && printf '%s' "$out" | grep -q 'full run.*no default branch available here' \
        && ! printf '%s' "$out" | grep -q 'ERROR'; then
    pass "(r) no default branch: a branch run runs all $SYN_N suites, with a plain reason line"
else
    fail "(r) no default branch: a branch run runs all $SYN_N suites, with a plain reason line (rc=$rc, ran=$r_ran, out=$out)"
fi

# ===================================================================
# Issue #444: the contract a one-job run keeps. Written against the
# serial runner before the job pool existed, so every later change is
# checked against this fixed point: the exit codes, the header and
# per-suite lines, the stop at the first failure, the leak charged to the
# suite that left it, and output streamed live in list order.
# ===================================================================

# make_stub <dir> <name> <body>: a suite with <body> as its text.
make_stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$3" > "$1/$2"
    chmod +x "$1/$2"
}
# running_lines <output>: the "=== running X ===" names, one line.
running_lines() {
    printf '%s\n' "$1" | sed -n 's/^=== run_script_tests: running \(.*\) ===$/\1/p' | tr '\n' ' ' | sed 's/ $//'
}

# --- Case (s1): all pass: exit 0, the header line, one running line per
#     suite in list order, each suite's output under its own running line,
#     and the closing line. ---
S1="$TMPD/case_s1"
mkdir -p "$S1"
write_checkpoint_stub "$S1"
make_stub "$S1" test_a_pass.sh 'echo "a-says-hi"'
make_stub "$S1" test_m_pass.sh 'echo "m-says-hi"'
out=$("$RUNNER" -j 1 "$S1" 2>&1); rc=$?
s1_first=$(printf '%s\n' "$out" | head -n 1)
s1_last=$(printf '%s\n' "$out" | tail -n 1)
s1_a_block=$(printf '%s\n' "$out" | sed -n '/^=== run_script_tests: running test_a_pass.sh ===$/,/^=== run_script_tests: running /p')
if [[ $rc -eq 0 && "$s1_first" == "run_script_tests: full run, all 3 suites: no --files given" \
        && "$(running_lines "$out")" == "test_a_pass.sh test_checkpoint_269.sh test_m_pass.sh" \
        && "$s1_a_block" == *"a-says-hi"* && "$s1_a_block" != *"m-says-hi"* ]] \
        && [[ "$s1_last" =~ ^run_script_tests:\ all\ 3\ suites\ passed\ in\ [0-9]+s$ ]]; then
    pass "(s1) one job, all pass: exit 0, header, running lines in list order, output in place, closing line"
else
    fail "(s1) one job, all pass: exit 0, header, running lines in list order, output in place, closing line (rc=$rc, out=$out)"
fi

# --- Case (s2): a failure stops the run with exit 1 and today's line. ---
S2="$TMPD/case_s2"
S2_LATER="$TMPD/case_s2_later"
mkdir -p "$S2"
write_checkpoint_stub "$S2"
make_stub "$S2" test_a_pass.sh 'exit 0'
make_stub "$S2" test_b_fail.sh 'echo "b-failing"; exit 3'
make_stub "$S2" test_z_later.sh "touch '$S2_LATER'"
out=$("$RUNNER" -j 1 "$S2" 2>&1); rc=$?
if [[ $rc -eq 1 && ! -e "$S2_LATER" && "$(running_lines "$out")" == "test_a_pass.sh test_b_fail.sh" ]] \
        && printf '%s\n' "$out" | grep -Eq '^run_script_tests: FAILED at test_b_fail\.sh \(suite 2 of 4\) after [0-9]+s — stopping, remaining suites not run$' \
        && printf '%s\n' "$out" | grep -q '^b-failing$'; then
    pass "(s2) one job: the first failure stops the run with exit 1 and names the suite and its position"
else
    fail "(s2) one job: the first failure stops the run with exit 1 (rc=$rc, later_ran=$([[ -e "$S2_LATER" ]] && echo yes || echo no), out=$out)"
fi

# --- Case (s3): a leak is charged to the suite that left it, not to the
#     suite before or after it, and stops the run with exit 2. ---
S3="$TMPD/case_s3"
S3_LATER="$TMPD/case_s3_later"
mkdir -p "$S3"
write_checkpoint_stub "$S3"
make_stub "$S3" test_a_clean.sh 'd=$(mktemp -d); rm -rf "$d"'
make_stub "$S3" test_b_leaks.sh ': > "${TMPDIR:?}/left_by_b"'
make_stub "$S3" test_z_later.sh "touch '$S3_LATER'"
out=$("$RUNNER" -j 1 "$S3" 2>&1); rc=$?
if [[ $rc -eq 2 && ! -e "$S3_LATER" ]] \
        && printf '%s\n' "$out" | grep -Eq '^run_script_tests: FAILED at test_b_leaks\.sh \(suite 2 of 4\) after [0-9]+s — it left 1 entry behind in TMPDIR \(' \
        && printf '%s\n' "$out" | grep -q '/left_by_b$' \
        && printf '%s\n' "$out" | grep -q '^Every suite must clean up what it creates' \
        && ! printf '%s\n' "$out" | grep -q 'FAILED at test_a_clean'; then
    pass "(s3) one job: a leak is charged to the suite that left it and stops the run with exit 2"
else
    fail "(s3) one job: a leak is charged to the suite that left it and stops the run with exit 2 (rc=$rc, out=$out)"
fi

# --- Case (s4): output streams live. The suite prints a line, then waits
#     for a go-file the test creates only once that line has reached the
#     runner's output; a runner that held the output until the suite ended
#     would never show it, and the suite would give up and fail. ---
S4="$TMPD/case_s4"
S4_GO="$TMPD/case_s4_go"
S4_LOG="$TMPD/case_s4.log"
mkdir -p "$S4"
write_checkpoint_stub "$S4"
make_stub "$S4" test_live.sh "echo 's4-live-line'
for _ in \$(seq 1 100); do [ -e '$S4_GO' ] && exit 0; sleep 0.1; done
echo 's4: never released'; exit 1"
"$RUNNER" -j 1 "$S4" > "$S4_LOG" 2>&1 &
s4_pid=$!
s4_seen=no
for _ in $(seq 1 100); do
    if grep -q '^s4-live-line$' "$S4_LOG" 2>/dev/null; then s4_seen=yes; touch "$S4_GO"; break; fi
    sleep 0.1
done
wait "$s4_pid"; rc=$?
if [[ $s4_seen == yes && $rc -eq 0 ]]; then
    pass "(s4) one job: a suite's output reaches the runner's output while the suite still runs"
else
    fail "(s4) one job: a suite's output reaches the runner's output while the suite still runs (seen=$s4_seen, rc=$rc, out=$(cat "$S4_LOG"))"
fi

# --- Case (t1): a late leak. Each suite has its own TMPDIR, kept until
#     every suite has finished and then swept again: a process a passing
#     suite left running that writes into its TMPDIR after the suite exited
#     is caught by that second sweep and charged to that suite, not to the
#     suite running when the write happened. ---
# late_leak_dir <dir>: the fixture, shared with the parallel case (u5).
late_leak_dir() {
    mkdir -p "$1"
    write_checkpoint_stub "$1"
    make_stub "$1" test_a_late.sh '( sleep 1; : > "${TMPDIR:?}/late_by_a" ) </dev/null >/dev/null 2>&1 &'
    make_stub "$1" test_b_slow.sh 'sleep 2'
}
# check_late_leak <label> <output> <rc>
check_late_leak() {
    if [[ $3 -eq 2 ]] \
            && printf '%s\n' "$2" | grep -Eq '^run_script_tests: FAILED at test_a_late\.sh \(suite 1 of 3\) — after every suite had finished, its TMPDIR \(.*/test_a_late\.sh\) held 1 entry' \
            && printf '%s\n' "$2" | grep -q '/late_by_a$' \
            && ! printf '%s\n' "$2" | grep -q 'FAILED at test_b_slow'; then
        pass "$1"
    else
        fail "$1 (rc=$3, out=$2)"
    fi
}
T1="$TMPD/case_t1"
late_leak_dir "$T1"
out=$("$RUNNER" -j 1 "$T1" 2>&1); rc=$?
check_late_leak "(t1) one job: a write after its suite exited is caught at the end, charged to that suite, exit 2" "$out" "$rc"

# ===================================================================
# Issue #444: more than one job. Every selected suite runs; each suite's
# output is captured and printed whole, failures first, in list order;
# the exit code is the one a one-job run gives for the first failing
# suite in list order.
# ===================================================================

# --- Case (u1): the job count and the argument order. ---
U1="$TMPD/case_u1"
mkdir -p "$U1"
write_checkpoint_stub "$U1"
make_stub "$U1" test_env.sh 'echo "inner-jobs=${RUN_SCRIPT_TESTS_JOBS-unset}"'
# jobs_case <label> <expected rc> <expected line or ''> <env assignment or ''> <runner args>...
jobs_case() {
    local label="$1" want_rc="$2" want_line="$3" envset="$4" out rc
    shift 4
    if [[ -n "$envset" ]]; then
        out=$(env "$envset" "$RUNNER" "$@" 2>&1); rc=$?
    else
        out=$("$RUNNER" "$@" 2>&1); rc=$?
    fi
    if [[ $rc -eq $want_rc ]] && { [[ -z "$want_line" ]] || printf '%s\n' "$out" | grep -qxF -- "$want_line"; } \
            && { [[ $want_rc -eq 0 ]] || ! printf '%s\n' "$out" | grep -q '^=== run_script_tests: running '; }; then
        pass "(u1) $label"
    else
        fail "(u1) $label (rc=$rc, out=$out)"
    fi
}
# The default is one job; its line names the count the machine suits, a
# quarter of its CPUs, at least 2, at most 6, never more than it has. A
# stub nproc first on PATH sets the CPU count.
U1_BIN="$TMPD/u1_bin"
mkdir -p "$U1_BIN"
for cpus_want in "16 4" "40 6" "4 2" "1 1"; do
    read -r u1_cpus u1_want <<<"$cpus_want"
    printf '#!/bin/sh\necho %s\n' "$u1_cpus" > "$U1_BIN/nproc"
    chmod +x "$U1_BIN/nproc"
    out=$(PATH="$U1_BIN:$PATH" "$RUNNER" "$U1" 2>&1); rc=$?
    if [[ $rc -eq 0 ]] && printf '%s\n' "$out" | grep -qxF "run_script_tests: running with 1 job (default; -j $u1_want suits this machine's $u1_cpus CPUs)"; then
        pass "(u1) the default is one job, and names -j $u1_want for $u1_cpus CPUs"
    else
        fail "(u1) the default is one job, and names -j $u1_want for $u1_cpus CPUs (rc=$rc, out=$out)"
    fi
done
jobs_case "-j 3 runs with 3 jobs" 0 "run_script_tests: running with 3 jobs (-j)" "" -j 3 "$U1"
jobs_case "-j3 runs with 3 jobs" 0 "run_script_tests: running with 3 jobs (-j)" "" -j3 "$U1"
jobs_case "--jobs 3 runs with 3 jobs" 0 "run_script_tests: running with 3 jobs (-j)" "" --jobs 3 "$U1"
jobs_case "--jobs=3 runs with 3 jobs" 0 "run_script_tests: running with 3 jobs (-j)" "" --jobs=3 "$U1"
jobs_case "RUN_SCRIPT_TESTS_JOBS=2 runs with 2 jobs" 0 "run_script_tests: running with 2 jobs (RUN_SCRIPT_TESTS_JOBS)" RUN_SCRIPT_TESTS_JOBS=2 "$U1"
jobs_case "-j beats RUN_SCRIPT_TESTS_JOBS" 0 "run_script_tests: running with 3 jobs (-j)" RUN_SCRIPT_TESTS_JOBS=2 -j 3 "$U1"
jobs_case "-j 99 runs with the cap of 8 and says what was asked" 0 "run_script_tests: running with 8 jobs (-j asked for 99; the cap is 8)" "" -j 99 "$U1"
jobs_case "-j 0 is refused before any suite runs" 1 "" "" -j 0 "$U1"
jobs_case "-j abc is refused before any suite runs" 1 "" "" -j abc "$U1"
jobs_case "-j with no count is refused" 1 "" "" -j
jobs_case "an empty -j \"\" is refused, not taken for no -j" 1 "" "" -j "" "$U1"
jobs_case "an empty --jobs= is refused, not taken for no -j" 1 "" "" --jobs= "$U1"
jobs_case "an empty --jobs= is refused also with RUN_SCRIPT_TESTS_JOBS set" 1 "" RUN_SCRIPT_TESTS_JOBS=2 --jobs= "$U1"
jobs_case "RUN_SCRIPT_TESTS_JOBS=abc is refused before any suite runs" 1 "" RUN_SCRIPT_TESTS_JOBS=abc "$U1"
jobs_case "an unknown option is refused" 1 "" "" --bogus "$U1"
jobs_case "an option after the tests directory is refused, naming the order" 1 "" "" "$U1" -j 2
out=$("$RUNNER" "$U1" -j 2 2>&1)
if printf '%s' "$out" | grep -q 'options go before the tests directory, --files last'; then
    pass "(u1) the refusal of an option after the tests directory names the order"
else
    fail "(u1) the refusal of an option after the tests directory names the order (out=$out)"
fi
out=$(RUN_SCRIPT_TESTS_JOBS=2 "$RUNNER" --show-passed "$U1" 2>&1)
if printf '%s\n' "$out" | grep -qx 'inner-jobs=unset'; then
    pass "(u1) a suite does not inherit RUN_SCRIPT_TESTS_JOBS"
else
    fail "(u1) a suite does not inherit RUN_SCRIPT_TESTS_JOBS (out=$out)"
fi
# Options, then the tests directory, then --files and the files: the
# order the hook's entry (which ends in --files) and a by-hand run share.
out=$(run_syn "$TMPD/u1_marks" -j 2 "$SYN_T" --files .agent/scripts/beta.sh); rc=$?
if [[ $rc -eq 0 && "$(ran "$TMPD/u1_marks")" == "test_alpha.sh test_always.sh test_checkpoint_269.sh test_noref.sh" ]] \
        && printf '%s\n' "$out" | grep -qx 'run_script_tests: running with 2 jobs (-j)' \
        && printf '%s' "$out" | grep -q "scoped run, 4 of $SYN_N suites"; then
    pass "(u1) '-j 2 <tests-dir> --files <file>' parses: a scoped run with 2 jobs"
else
    fail "(u1) '-j 2 <tests-dir> --files <file>' parses: a scoped run with 2 jobs (rc=$rc, ran=$(ran "$TMPD/u1_marks"), out=$out)"
fi

# --- Case (u2): all pass at -j 3: every suite runs once, the closing line
#     is the one-job run's, and a passing suite's output is not printed
#     unless --show-passed asks for it. ---
U2="$TMPD/case_u2"
U2_MARKS="$TMPD/case_u2_marks"
mkdir -p "$U2" "$U2_MARKS"
write_checkpoint_stub "$U2"
for n in a b c d e; do
    make_stub "$U2" "test_$n.sh" "echo 'u2-output-$n'; sleep 0.2; touch '$U2_MARKS/$n'"
done
out=$("$RUNNER" -j 3 "$U2" 2>&1); rc=$?
if [[ $rc -eq 0 && "$(ran "$U2_MARKS")" == "a b c d e" \
        && "$(running_lines "$out" | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')" == "test_a.sh test_b.sh test_c.sh test_checkpoint_269.sh test_d.sh test_e.sh" ]] \
        && ! printf '%s' "$out" | grep -q 'u2-output-' \
        && [[ "$(printf '%s\n' "$out" | tail -n 1)" =~ ^run_script_tests:\ all\ 6\ suites\ passed\ in\ [0-9]+s$ ]] \
        && printf '%s\n' "$out" | grep -q '^run_script_tests: suite times, slowest first:$'; then
    pass "(u2) -j 3, all pass: every suite runs once, passing output hidden, today's closing line"
else
    fail "(u2) -j 3, all pass: every suite runs once, passing output hidden, today's closing line (rc=$rc, ran=$(ran "$U2_MARKS"), out=$out)"
fi
u2_rows=$(printf '%s\n' "$out" | sed -n '/^run_script_tests: suite times, slowest first:$/,/^$/p' \
    | sed -n 's/^ *[0-9][0-9]*s  pass   \(test_[^ ]*\)$/\1/p' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')
if [[ "$u2_rows" == "test_a.sh test_b.sh test_c.sh test_checkpoint_269.sh test_d.sh test_e.sh" ]]; then
    pass "(u2) the suite times list every suite once, with its seconds and status"
else
    fail "(u2) the suite times list every suite once, with its seconds and status (rows=$u2_rows, out=$out)"
fi
out=$("$RUNNER" -j 3 --show-passed "$U2" 2>&1); rc=$?
if [[ $rc -eq 0 ]] && printf '%s\n' "$out" | grep -qx '===== passed: test_c.sh =====' \
        && printf '%s\n' "$out" | grep -A1 -x '===== passed: test_c.sh =====' | grep -qx 'u2-output-c'; then
    pass "(u2) --show-passed prints a passing suite's output under its name"
else
    fail "(u2) --show-passed prints a passing suite's output under its name (rc=$rc, out=$out)"
fi

# --- Case (u3): a failing suite's output is not interleaved with
#     another's. Two suites print 200 numbered lines each, slowly enough to
#     overlap, and both fail; each block must come out whole. Run five times. ---
U3="$TMPD/case_u3"
mkdir -p "$U3"
write_checkpoint_stub "$U3"
for tag in A B; do
    make_stub "$U3" "test_$tag.sh" "for i in \$(seq 1 200); do echo '$tag-'\$i; sleep 0.01; done; exit 1"
done
# contiguous <output> <tag>: the tag's 200 lines appear in order, together.
contiguous() {
    local want got
    want="$(seq 1 200 | sed "s/^/$2-/")"
    got="$(printf '%s\n' "$1" | grep -E '^[AB]-[0-9]+$' | sed -n "/^$2-1\$/,/^$2-200\$/p")"
    [[ "$got" == "$want" ]]
}
for round in 1 2 3 4 5; do
    out=$("$RUNNER" -j 2 "$U3" 2>&1); rc=$?
    if [[ $rc -eq 1 ]] && contiguous "$out" A && contiguous "$out" B \
            && printf '%s\n' "$out" | grep -qx '===== FAILED: test_A.sh =====' \
            && printf '%s\n' "$out" | grep -qx '===== FAILED: test_B.sh ====='; then
        pass "(u3) round $round: two failing suites' outputs are printed whole, not interleaved"
    else
        fail "(u3) round $round: two failing suites' outputs are printed whole, not interleaved (rc=$rc, out=$out)"
    fi
done

# --- Case (u4): every suite runs after a failure; failures are printed
#     first, in list order whatever order they finished in; the exit code is
#     the first failing suite's in list order (1 for a failure, 2 for a
#     leak), not the first to finish. Each run makes the two disagree: in
#     the first, a failure is listed first and a leak finishes first (1, not
#     2); in the second, a leak is listed first and a failure finishes first
#     (2, not 1). ---
U4="$TMPD/case_u4"
U4_MARK="$TMPD/case_u4_later"
mkdir -p "$U4"
write_checkpoint_stub "$U4"
# The finish order does not rest on sleeps racing each other: each suite
# records its pid, and the next one waits until that suite is gone (reaped
# by the runner: a zombie still answers kill -0), then one second more, so
# the runner has seen one finish before the next comes. 30 s caps each
# wait, so a broken chain fails the case rather than hanging it.
# u4_pid <name>: shell text recording this suite's pid as <name>.
u4_pid() { printf 'echo $$ > %q.tmp && mv %q.tmp %q' "$TMPD/u4_pid_$1" "$TMPD/u4_pid_$1" "$TMPD/u4_pid_$1"; }
# u4_after <name>: shell text waiting until suite <name> is gone, then 1 s.
u4_after() {
    printf 'f=%q; for _ in $(seq 1 300); do [[ -s "$f" ]] && break; sleep 0.1; done; p=$(cat "$f" 2>/dev/null); for _ in $(seq 1 300); do [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null || break; sleep 0.1; done; sleep 1' "$TMPD/u4_pid_$1"
}
make_stub "$U4" test_a_slowfail.sh "echo 'a-out'; $(u4_after c); exit 1"
make_stub "$U4" test_b_leak.sh "$(u4_pid b); echo 'b-out'; : > \"\${TMPDIR:?}/left_by_b\""
make_stub "$U4" test_c_fail.sh "$(u4_pid c); echo 'c-out'; $(u4_after b); exit 4"
make_stub "$U4" test_z_later.sh "sleep 0.2; touch '$U4_MARK'"
rm -f "$TMPD"/u4_pid_*
out=$("$RUNNER" -j 4 "$U4" 2>&1); rc=$?
u4_a=$(printf '%s\n' "$out" | grep -nx '===== FAILED: test_a_slowfail.sh =====' | cut -d: -f1)
u4_b=$(printf '%s\n' "$out" | grep -nx '===== FAILED: test_b_leak.sh =====' | cut -d: -f1)
u4_c=$(printf '%s\n' "$out" | grep -nx '===== FAILED: test_c_fail.sh =====' | cut -d: -f1)
u4_t=$(printf '%s\n' "$out" | grep -nx 'run_script_tests: suite times, slowest first:' | cut -d: -f1)
# The order the suites finished in, from the runner's "--- <suite> ..." lines.
u4_done=$(printf '%s\n' "$out" | sed -n 's/^--- run_script_tests: \(test_[abc]_[a-z]*\.sh\) .*/\1/p' | tr '\n' ' ' | sed 's/ $//')
if [[ $rc -eq 1 && -e "$U4_MARK" && -n "$u4_a" && -n "$u4_b" && -n "$u4_c" && -n "$u4_t" ]] \
        && [[ "$u4_done" == "test_b_leak.sh test_c_fail.sh test_a_slowfail.sh" ]] \
        && (( u4_a < u4_b && u4_b < u4_c && u4_c < u4_t )) \
        && printf '%s\n' "$out" | grep -Eq '^run_script_tests: FAILED at test_c_fail\.sh \(suite 3 of 5\) after [0-9]+s, exit 4$' \
        && printf '%s\n' "$out" | grep -Eq '^run_script_tests: FAILED at test_b_leak\.sh \(suite 2 of 5\) after [0-9]+s — it left 1 entry behind in TMPDIR \(.*/test_b_leak\.sh\):$' \
        && printf '%s\n' "$out" | grep -Eq '^run_script_tests: 3 of 5 suites failed in [0-9]+s: test_a_slowfail\.sh, test_b_leak\.sh, test_c_fail\.sh$' \
        && ! printf '%s' "$out" | grep -q 'remaining suites not run'; then
    pass "(u4) -j 4: every suite runs, failures first in list order, exit 1 from the failure listed first, though a leak finished first"
else
    fail "(u4) -j 4: every suite runs, failures first in list order, exit 1 from the failure listed first, though a leak finished first (rc=$rc, finished=$u4_done, later_ran=$([[ -e "$U4_MARK" ]] && echo yes || echo no), out=$out)"
fi
# The second run: the leak listed first now finishes last, the failure
# listed after it fails at once.
rm -f "$U4/test_a_slowfail.sh" "$U4_MARK"
make_stub "$U4" test_b_leak.sh 'echo "b-out"; sleep 0.5; : > "${TMPDIR:?}/left_by_b"'
make_stub "$U4" test_c_fail.sh 'echo "c-out"; exit 4'
out=$("$RUNNER" -j 4 "$U4" 2>&1); rc=$?
if [[ $rc -eq 2 && -e "$U4_MARK" ]]; then
    pass "(u4) -j 4: a leak listed before a failure gives exit 2, though the failure finished first"
else
    fail "(u4) -j 4: a leak listed before a failure gives exit 2, though the failure finished first (rc=$rc, out=$out)"
fi

# --- Case (v): --shuffle[=SEED]. The seed is printed; the same seed gives
#     the same start order, at one job and at two; another seed gives
#     another order; the exit code of a parallel run stays the first
#     failing suite's in list order whatever the shuffle. ---
V="$TMPD/case_v"
mkdir -p "$V"
write_checkpoint_stub "$V"
for n in a b c d e f g h; do make_stub "$V" "test_$n.sh" ':'; done
v7a=$("$RUNNER" -j 1 --shuffle=7 "$V" 2>&1); rc=$?
v7b=$("$RUNNER" -j 1 --shuffle=7 "$V" 2>&1)
v7j=$("$RUNNER" -j 2 --shuffle=7 "$V" 2>&1)
v8=$("$RUNNER" -j 1 --shuffle=8 "$V" 2>&1)
sorted_order="test_a.sh test_b.sh test_c.sh test_checkpoint_269.sh test_d.sh test_e.sh test_f.sh test_g.sh test_h.sh"
if [[ $rc -eq 0 ]] && printf '%s\n' "$v7a" | grep -qx 'run_script_tests: shuffle seed 7 (this order again: --shuffle=7)' \
        && [[ "$(running_lines "$v7a")" == "$(running_lines "$v7b")" && "$(running_lines "$v7a")" == "$(running_lines "$v7j")" ]] \
        && [[ "$(running_lines "$v7a")" != "$sorted_order" && "$(running_lines "$v7a")" != "$(running_lines "$v8")" ]] \
        && [[ "$(running_lines "$v7a" | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')" == "$sorted_order" ]]; then
    pass "(v) --shuffle=7 prints its seed and starts the same order twice and at -j 2; --shuffle=8 differs"
else
    fail "(v) --shuffle=7 prints its seed and starts the same order twice and at -j 2; --shuffle=8 differs (7: $(running_lines "$v7a") | 7 again: $(running_lines "$v7b") | 7 at -j 2: $(running_lines "$v7j") | 8: $(running_lines "$v8"))"
fi
out=$("$RUNNER" -j 1 --shuffle "$V" 2>&1); rc=$?
v_seed=$(printf '%s\n' "$out" | sed -n 's/^run_script_tests: shuffle seed \([0-9][0-9]*\) (this order again: --shuffle=[0-9]*)$/\1/p')
if [[ $rc -eq 0 && -n "$v_seed" ]] \
        && [[ "$(running_lines "$out")" == "$(running_lines "$("$RUNNER" -j 1 --shuffle="$v_seed" "$V" 2>&1)")" ]]; then
    pass "(v) --shuffle with no seed prints the seed it drew, and that seed repeats the order"
else
    fail "(v) --shuffle with no seed prints the seed it drew, and that seed repeats the order (seed=$v_seed, out=$out)"
fi
jobs_case "--shuffle=x is refused before any suite runs" 1 "" "" --shuffle=x "$V"
jobs_case "an empty --shuffle= is refused, not given a random seed" 1 "" "" --shuffle= "$V"
# U4 now holds test_b_leak.sh (listed first, finishes last) and
# test_c_fail.sh (fails at once).
v_codes=""
for seed in 1 2 3; do
    "$RUNNER" -j 4 --shuffle=$seed "$U4" >/dev/null 2>&1
    v_codes+="$? "
done
if [[ "$v_codes" == "2 2 2 " ]]; then
    pass "(v) -j 4 under three shuffles: the exit code is the first failing suite's in list order (2, the leak)"
else
    fail "(v) -j 4 under three shuffles: the exit code is the first failing suite's in list order (2, the leak): got $v_codes"
fi

# --- Case (u5): the late leak of (t1), at two jobs. ---
U5="$TMPD/case_u5"
late_leak_dir "$U5"
out=$("$RUNNER" -j 2 "$U5" 2>&1); rc=$?
check_late_leak "(u5) -j 2: a write after its suite exited is caught at the end, charged to that suite, exit 2" "$out" "$rc"

# --- Case (u6): leak attribution while suites overlap. X keeps a file in
#     its TMPDIR for a second while Y starts and finishes; neither is
#     charged. Z leaks, and only Z is named. ---
U6="$TMPD/case_u6"
mkdir -p "$U6"
write_checkpoint_stub "$U6"
make_stub "$U6" test_x_holds.sh 'f=$(mktemp); sleep 1; rm -f "$f"'
make_stub "$U6" test_y_quick.sh 'sleep 0.2'
make_stub "$U6" test_z_leaks.sh 'sleep 0.3; : > "${TMPDIR:?}/left_by_z"'
out=$("$RUNNER" -j 4 "$U6" 2>&1); rc=$?
if [[ $rc -eq 2 ]] && printf '%s\n' "$out" | grep -q '^run_script_tests: FAILED at test_z_leaks\.sh ' \
        && ! printf '%s\n' "$out" | grep -Eq '^run_script_tests: FAILED at test_(x_holds|y_quick)\.sh' \
        && printf '%s\n' "$out" | grep -Eq '^run_script_tests: 1 of 4 suites failed in [0-9]+s: test_z_leaks\.sh$'; then
    pass "(u6) -j 4: a live file in one suite's TMPDIR is not charged to another; only the leaking suite is named"
else
    fail "(u6) -j 4: a live file in one suite's TMPDIR is not charged to another; only the leaking suite is named (rc=$rc, out=$out)"
fi

# --- Case (u7): a suite can trap SIGINT and SIGQUIT at -j 2 as it can at
#     -j 1. Without job control bash starts a background job with both
#     ignored, and a signal ignored on entry cannot be trapped. The runner
#     is started with both at their defaults (python3 resets them; the
#     environment running this suite may ignore them), so a difference
#     between the job counts is the runner's own. ---
U7="$TMPD/case_u7"
mkdir -p "$U7"
write_checkpoint_stub "$U7"
make_stub "$U7" test_traps.sh 'got=""
trap "got+=I" INT
trap "got+=Q" QUIT
kill -INT $$
kill -QUIT $$
echo "traps-got=$got"
[[ "$got" == IQ ]]'
# with_default_signals <cmd>...: run <cmd> with SIGINT and SIGQUIT at their
# defaults. exec keeps one pid from the caller's `$!` to <cmd>, so a signal
# sent to that pid reaches <cmd> itself.
with_default_signals() {
    exec python3 -c 'import os, signal, sys
signal.signal(signal.SIGINT, signal.SIG_DFL)
signal.signal(signal.SIGQUIT, signal.SIG_DFL)
os.execvp(sys.argv[1], sys.argv[1:])' "$@"
}
for j in 1 2; do
    out=$(with_default_signals "$RUNNER" -j "$j" --show-passed "$U7" 2>&1); rc=$?
    if [[ $rc -eq 0 ]] && printf '%s\n' "$out" | grep -qx 'traps-got=IQ'; then
        pass "(u7) -j $j: a suite traps SIGINT and SIGQUIT"
    else
        fail "(u7) -j $j: a suite traps SIGINT and SIGQUIT (rc=$rc, out=$out)"
    fi
done

# --- Case (u8): an interrupt (SIGINT, as Ctrl-C, and SIGTERM) stops every
#     running suite's whole process group, the suite and what it started,
#     and leaves no directory of this run behind. Checked by the processes
#     and the directory this run recorded, never by name: other runs of
#     this runner on the machine have the same names. ---
U8="$TMPD/case_u8"
mkdir -p "$U8"
write_checkpoint_stub "$U8"
for n in p q; do
    make_stub "$U8" "test_$n.sh" "sleep 30 &
echo \"\$\$ \$! \$TMPDIR\" > '$TMPD/u8_info_$n.tmp' && mv '$TMPD/u8_info_$n.tmp' '$TMPD/u8_info_$n'
wait"
done
for sig in INT TERM; do
    rm -f "$TMPD"/u8_info_*
    # The runner gets a process group of its own (job control) and SIGINT
    # at its default, as at a terminal, also when this suite was started
    # with SIGINT ignored (python3 resets it; bash could not).
    set -m
    with_default_signals "$RUNNER" -j 2 "$U8" > "$TMPD/u8.log" 2>&1 &
    u8_runner=$!
    set +m
    for _ in $(seq 1 100); do
        [[ -e "$TMPD/u8_info_p" && -e "$TMPD/u8_info_q" ]] && break
        sleep 0.1
    done
    u8_pids=()
    u8_root=""
    for n in p q; do
        if read -r u8_suite u8_sleep u8_tmp < "$TMPD/u8_info_$n" 2>/dev/null; then
            u8_pids+=("$u8_suite" "$u8_sleep")
            u8_root="$(dirname "$(dirname "$u8_tmp")")"
        fi
    done
    u8_t0=$(date +%s)
    kill -s "$sig" "$u8_runner"
    wait "$u8_runner"; rc=$?
    # The runner's own bound is 5 seconds before KILL; the suites would
    # otherwise sleep for 30. At SIGINT the sleeps, started with `&`,
    # ignore it, so that run takes the 5 seconds.
    u8_secs=$(( $(date +%s) - u8_t0 ))
    u8_alive=""
    for _ in $(seq 1 50); do
        u8_alive=""
        for p in "${u8_pids[@]}"; do kill -0 "$p" 2>/dev/null && u8_alive+="$p "; done
        [[ -z "$u8_alive" ]] && break
        sleep 0.1
    done
    if [[ ${#u8_pids[@]} -eq 4 && -z "$u8_alive" && -n "$u8_root" && ! -e "$u8_root" && $u8_secs -le 10 ]] \
            && [[ "$u8_root" == */run-script-tests.* ]] \
            && { [[ $sig == INT && $rc -eq 130 ]] || [[ $sig == TERM && $rc -eq 143 ]]; }; then
        pass "(u8) SIG$sig at -j 2 stops both suites and the processes they started, and removes the run's directory (${u8_secs}s)"
    else
        fail "(u8) SIG$sig at -j 2 stops both suites and the processes they started, and removes the run's directory (rc=$rc, ${u8_secs}s to stop, recorded=${u8_pids[*]}, alive=$u8_alive, root=$u8_root, log=$(cat "$TMPD/u8.log"))"
    fi
    for p in "${u8_pids[@]}"; do kill -s KILL "$p" 2>/dev/null; done
done

# u8_start <dir> <info-file>: start the runner at -j 2 on <dir> in a group
# of its own with SIGINT at its default, as above, and wait up to 10
# seconds for the suite to write <info-file>. Sets u8_runner.
u8_start() {
    rm -f "$2"
    set -m
    with_default_signals "$RUNNER" -j 2 "$1" > "$TMPD/u8.log" 2>&1 &
    u8_runner=$!
    set +m
    for _ in $(seq 1 100); do
        [[ -e "$2" ]] && break
        sleep 0.1
    done
}
# u8_alive_of <pid>...: those of the pids still running, after up to 5
# seconds for them to go.
u8_alive_of() {
    local p alive=""
    for _ in $(seq 1 50); do
        alive=""
        for p in "$@"; do kill -0 "$p" 2>/dev/null && alive+="$p "; done
        [[ -z "$alive" ]] && break
        sleep 0.1
    done
    printf '%s' "$alive"
}
# ms_now: the time in milliseconds, from EPOCHREALTIME (whole seconds are
# too coarse to tell 1 s of cleanup from the 5 s backstop under load).
ms_now() { local us="${EPOCHREALTIME//[!0-9]/}"; printf '%s' "$(( 10#$us / 1000 ))"; }

# --- Case (u8), the KILL backstop: a suite that ignores SIGTERM, and the
#     sleep it waits on (which inherits the ignore), are KILLed 5 seconds
#     after the signal, not before, and the run still ends. ---
U8B="$TMPD/case_u8b"
mkdir -p "$U8B"
write_checkpoint_stub "$U8B"
make_stub "$U8B" test_deaf.sh "trap '' TERM
sleep 30 &
echo \"\$\$ \$! \$TMPDIR\" > '$TMPD/u8b_info.tmp' && mv '$TMPD/u8b_info.tmp' '$TMPD/u8b_info'
wait"
u8_start "$U8B" "$TMPD/u8b_info"
u8_pids=()
u8_root=""
if read -r u8_suite u8_sleep u8_tmp < "$TMPD/u8b_info" 2>/dev/null; then
    u8_pids=("$u8_suite" "$u8_sleep")
    u8_root="$(dirname "$(dirname "$u8_tmp")")"
fi
# Timed from before the signal is sent, so a runner that keeps the
# 5-second deadline measures at least 5000 ms.
u8_t0=$(ms_now)
kill -s TERM "$u8_runner"
wait "$u8_runner"; rc=$?
u8_ms=$(( $(ms_now) - u8_t0 ))
u8_alive=$(u8_alive_of "${u8_pids[@]}")
if [[ ${#u8_pids[@]} -eq 2 && -z "$u8_alive" && $rc -eq 143 && $u8_ms -ge 4900 && $u8_ms -le 10000 ]] \
        && [[ "$u8_root" == */run-script-tests.* && ! -e "$u8_root" ]]; then
    pass "(u8) a suite that ignores SIGTERM is KILLed with what it started after the 5 s backstop (${u8_ms} ms), and the run's directory is removed"
else
    fail "(u8) a suite that ignores SIGTERM is KILLed with what it started after the 5 s backstop (rc=$rc, ${u8_ms} ms to stop, recorded=${u8_pids[*]}, alive=$u8_alive, root=$u8_root, log=$(cat "$TMPD/u8.log"))"
fi
for p in "${u8_pids[@]}"; do kill -s KILL "$p" 2>/dev/null; done

# --- Case (u8), cleanup time: the suite exits on SIGTERM at once; a
#     process it started takes a second over its own cleanup. That process
#     is not KILLed when the suite exits: its cleanup finishes, and the run
#     ends without waiting out the full 5 seconds. ---
U8C="$TMPD/case_u8c"
U8C_DONE="$TMPD/u8c_cleaned"
mkdir -p "$U8C"
write_checkpoint_stub "$U8C"
make_stub "$U8C" test_slowclean.sh "trap 'exit 0' TERM
(
    trap 'sleep 1; touch \"$U8C_DONE\"; exit 0' TERM
    sleep 30 &
    echo \"\$\$ \$BASHPID \$! \$TMPDIR\" > '$TMPD/u8c_info.tmp' && mv '$TMPD/u8c_info.tmp' '$TMPD/u8c_info'
    wait
) &
wait"
rm -f "$U8C_DONE"
u8_start "$U8C" "$TMPD/u8c_info"
u8_pids=()
u8_root=""
if read -r u8_suite u8_child u8_sleep u8_tmp < "$TMPD/u8c_info" 2>/dev/null; then
    u8_pids=("$u8_suite" "$u8_child" "$u8_sleep")
    u8_root="$(dirname "$(dirname "$u8_tmp")")"
fi
# Bounded just below the backstop, in milliseconds: a runner that waited
# out the 5 s deadline measures at least 5000 ms, and the 1 s cleanup has
# 3.8 s of slack for a loaded machine.
u8_t0=$(ms_now)
kill -s TERM "$u8_runner"
wait "$u8_runner"; rc=$?
u8_ms=$(( $(ms_now) - u8_t0 ))
# Checked as the runner exits: the cleanup must have finished by then.
u8_cleaned=no
[[ -e "$U8C_DONE" ]] && u8_cleaned=yes
u8_alive=$(u8_alive_of "${u8_pids[@]}")
if [[ ${#u8_pids[@]} -eq 3 && $u8_cleaned == yes && -z "$u8_alive" && $rc -eq 143 && $u8_ms -lt 4800 ]] \
        && [[ "$u8_root" == */run-script-tests.* && ! -e "$u8_root" ]]; then
    pass "(u8) a process a suite started finishes its own cleanup after the suite exits, before the backstop (${u8_ms} ms)"
else
    fail "(u8) a process a suite started finishes its own cleanup after the suite exits, before the backstop (rc=$rc, cleaned=$u8_cleaned, ${u8_ms} ms to stop, recorded=${u8_pids[*]}, alive=$u8_alive, root=$u8_root, log=$(cat "$TMPD/u8.log"))"
fi
for p in "${u8_pids[@]}"; do kill -s KILL "$p" 2>/dev/null; done

# --- Case (u8), another exit: SIGUSR1, which the runner does not trap,
#     ends it while two suites run. The EXIT trap still stops both suites
#     and what they started before it removes the run's directory, as it
#     would after an internal error. (The suites of the first u8 case.) ---
rm -f "$TMPD"/u8_info_*
u8_start "$U8" "$TMPD/u8_info_q"
for _ in $(seq 1 50); do
    [[ -e "$TMPD/u8_info_p" ]] && break
    sleep 0.1
done
u8_pids=()
u8_root=""
for n in p q; do
    if read -r u8_suite u8_sleep u8_tmp < "$TMPD/u8_info_$n" 2>/dev/null; then
        u8_pids+=("$u8_suite" "$u8_sleep")
        u8_root="$(dirname "$(dirname "$u8_tmp")")"
    fi
done
u8_t0=$(date +%s)
kill -s USR1 "$u8_runner"
wait "$u8_runner"; rc=$?
u8_secs=$(( $(date +%s) - u8_t0 ))
u8_alive=$(u8_alive_of "${u8_pids[@]}")
if [[ ${#u8_pids[@]} -eq 4 && -z "$u8_alive" && $rc -ne 0 && $u8_secs -le 10 ]] \
        && [[ "$u8_root" == */run-script-tests.* && ! -e "$u8_root" ]]; then
    pass "(u8) an untrapped fatal signal (SIGUSR1) still stops both suites and what they started before the run's directory is removed (${u8_secs}s)"
else
    fail "(u8) an untrapped fatal signal (SIGUSR1) still stops both suites and what they started before the run's directory is removed (rc=$rc, ${u8_secs}s to stop, recorded=${u8_pids[*]}, alive=$u8_alive, root=$u8_root, log=$(cat "$TMPD/u8.log"))"
fi
for p in "${u8_pids[@]}"; do kill -s KILL "$p" 2>/dev/null; done

# --- Case (u8), a second signal: during the 5-second stop, a second
#     SIGTERM to the runner, or a second Ctrl-C to its process group, KILLs
#     what is left at once instead of starting another 5-second stop. The
#     suite of the backstop case ignores SIGTERM; at SIGINT its sleep
#     (started with `&`) ignores it. Either way the first stop would last
#     the 5 seconds. Timed from the second signal, sent 0.5 s after the
#     first: a runner that waits out a deadline measures 4500 ms or more. ---
for sig in TERM INT; do
    u8_start "$U8B" "$TMPD/u8b_info"
    u8_pids=()
    u8_root=""
    if read -r u8_suite u8_sleep u8_tmp < "$TMPD/u8b_info" 2>/dev/null; then
        u8_pids=("$u8_suite" "$u8_sleep")
        u8_root="$(dirname "$(dirname "$u8_tmp")")"
    fi
    if [[ $sig == TERM ]]; then
        kill -s TERM "$u8_runner"; sleep 0.5
        u8_t0=$(ms_now); kill -s TERM "$u8_runner"
    else
        kill -s INT -- "-$u8_runner"; sleep 0.5
        u8_t0=$(ms_now); kill -s INT -- "-$u8_runner"
    fi
    wait "$u8_runner"; rc=$?
    u8_ms=$(( $(ms_now) - u8_t0 ))
    u8_alive=$(u8_alive_of "${u8_pids[@]}")
    if [[ ${#u8_pids[@]} -eq 2 && -z "$u8_alive" && $rc -ne 0 && $u8_ms -lt 3000 ]] \
            && [[ "$u8_root" == */run-script-tests.* && ! -e "$u8_root" ]] \
            && grep -q '^run_script_tests: stop cut short; KILLing ' "$TMPD/u8.log"; then
        pass "(u8) a second SIG$sig during the stop KILLs what is left at once (${u8_ms} ms after it)"
    else
        fail "(u8) a second SIG$sig during the stop KILLs what is left at once (rc=$rc, ${u8_ms} ms after it, recorded=${u8_pids[*]}, alive=$u8_alive, root=$u8_root, log=$(cat "$TMPD/u8.log"))"
    fi
    for p in "${u8_pids[@]}"; do kill -s KILL "$p" 2>/dev/null; done
done

# --- Case (u8), a group left behind: test_leaves.sh exits at once and
#     leaves a sleep running in its process group. Once the runner has
#     reaped the suite, a SIGTERM to the runner still stops that sleep, as
#     it stops the suite that is still running. ---
U8L="$TMPD/case_u8l"
mkdir -p "$U8L"
write_checkpoint_stub "$U8L"
make_stub "$U8L" test_leaves.sh "sleep 30 &
echo \"\$!\" > '$TMPD/u8l_left.tmp' && mv '$TMPD/u8l_left.tmp' '$TMPD/u8l_left'"
make_stub "$U8L" test_holds.sh "sleep 30 &
echo \"\$\$ \$! \$TMPDIR\" > '$TMPD/u8l_info.tmp' && mv '$TMPD/u8l_info.tmp' '$TMPD/u8l_info'
wait"
rm -f "$TMPD/u8l_left"
u8_start "$U8L" "$TMPD/u8l_info"
# Until the runner has reaped test_leaves.sh (its "---" line).
for _ in $(seq 1 100); do
    grep -q '^--- run_script_tests: test_leaves\.sh passed' "$TMPD/u8.log" && break
    sleep 0.1
done
u8_reaped=no
grep -q '^--- run_script_tests: test_leaves\.sh passed' "$TMPD/u8.log" && u8_reaped=yes
u8_pids=()
u8_root=""
read -r u8_left < "$TMPD/u8l_left" 2>/dev/null && u8_pids+=("$u8_left")
if read -r u8_suite u8_sleep u8_tmp < "$TMPD/u8l_info" 2>/dev/null; then
    u8_pids+=("$u8_suite" "$u8_sleep")
    u8_root="$(dirname "$(dirname "$u8_tmp")")"
fi
kill -s TERM "$u8_runner"
wait "$u8_runner"; rc=$?
u8_alive=$(u8_alive_of "${u8_pids[@]}")
if [[ $u8_reaped == yes && ${#u8_pids[@]} -eq 3 && -z "$u8_alive" && $rc -eq 143 ]] \
        && [[ "$u8_root" == */run-script-tests.* && ! -e "$u8_root" ]]; then
    pass "(u8) SIGTERM also stops a process a finished suite left running in its group"
else
    fail "(u8) SIGTERM also stops a process a finished suite left running in its group (rc=$rc, reaped=$u8_reaped, recorded=${u8_pids[*]}, alive=$u8_alive, root=$u8_root, log=$(cat "$TMPD/u8.log"))"
fi
for p in "${u8_pids[@]}"; do kill -s KILL "$p" 2>/dev/null; done

# --- Case (u8), a group left behind at the end: the run ends normally
#     while test_leaves.sh's sleep still runs; the runner stops it before it
#     removes the run's directory, and says so. ---
U8N="$TMPD/case_u8n"
mkdir -p "$U8N"
write_checkpoint_stub "$U8N"
cp "$U8L/test_leaves.sh" "$U8N/"
rm -f "$TMPD/u8l_left"
out=$("$RUNNER" -j 2 "$U8N" 2>&1); rc=$?
u8_pids=()
read -r u8_left < "$TMPD/u8l_left" 2>/dev/null && u8_pids+=("$u8_left")
u8_alive=$(u8_alive_of "${u8_pids[@]}")
if [[ $rc -eq 0 && ${#u8_pids[@]} -eq 1 && -z "$u8_alive" ]] \
        && printf '%s\n' "$out" | grep -qx 'run_script_tests: stopping 1 process group(s) of this run still running at exit'; then
    pass "(u8) at the end of a run, a process a suite left running is stopped, and the runner says so"
else
    fail "(u8) at the end of a run, a process a suite left running is stopped, and the runner says so (rc=$rc, recorded=${u8_pids[*]}, alive=$u8_alive, out=$out)"
fi
for p in "${u8_pids[@]}"; do kill -s KILL "$p" 2>/dev/null; done

# --- Case (u8), a signal during that end-of-run stop: the process left
#     running ignores SIGTERM, so the stop would take the 5 seconds. A
#     SIGTERM to the runner, or a Ctrl-C to its process group, after the
#     "still running at exit" line KILLs it at once and still removes the
#     run's directory. Timed from the signal: a runner that waits out the
#     deadline measures 4500 ms or more. ---
U8E="$TMPD/case_u8e"
mkdir -p "$U8E"
write_checkpoint_stub "$U8E"
make_stub "$U8E" test_deaf_left.sh "trap '' TERM
sleep 30 &
echo \"\$! \$TMPDIR\" > '$TMPD/u8e_info.tmp' && mv '$TMPD/u8e_info.tmp' '$TMPD/u8e_info'"
for sig in TERM INT; do
    u8_start "$U8E" "$TMPD/u8e_info"
    u8_pids=()
    u8_root=""
    if read -r u8_left u8_tmp < "$TMPD/u8e_info" 2>/dev/null; then
        u8_pids=("$u8_left")
        u8_root="$(dirname "$(dirname "$u8_tmp")")"
    fi
    for _ in $(seq 1 100); do
        grep -q 'still running at exit$' "$TMPD/u8.log" && break
        sleep 0.1
    done
    u8_stopping=no
    grep -q 'still running at exit$' "$TMPD/u8.log" && u8_stopping=yes
    u8_t0=$(ms_now)
    if [[ $sig == TERM ]]; then
        kill -s TERM "$u8_runner"
    else
        kill -s INT -- "-$u8_runner"
    fi
    wait "$u8_runner"; rc=$?
    u8_ms=$(( $(ms_now) - u8_t0 ))
    u8_alive=$(u8_alive_of "${u8_pids[@]}")
    if [[ $u8_stopping == yes && ${#u8_pids[@]} -eq 1 && -z "$u8_alive" && $u8_ms -lt 3000 ]] \
            && { [[ $sig == INT && $rc -eq 130 ]] || [[ $sig == TERM && $rc -eq 143 ]]; } \
            && [[ "$u8_root" == */run-script-tests.* && ! -e "$u8_root" ]] \
            && grep -q '^run_script_tests: stop cut short; KILLing 1 ' "$TMPD/u8.log"; then
        pass "(u8) SIG$sig during the end-of-run stop KILLs what is left at once and removes the run's directory (${u8_ms} ms after it)"
    else
        fail "(u8) SIG$sig during the end-of-run stop KILLs what is left at once and removes the run's directory (rc=$rc, stopping=$u8_stopping, ${u8_ms} ms after it, recorded=${u8_pids[*]}, alive=$u8_alive, root=$u8_root, log=$(cat "$TMPD/u8.log"))"
    fi
    for p in "${u8_pids[@]}"; do kill -s KILL "$p" 2>/dev/null; done
    # A runner without the fix leaves the directory: do not leave it too.
    [[ "$u8_root" != */run-script-tests.* ]] || rm -rf "$u8_root"
done

echo ""
echo "test_run_script_tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
