#!/usr/bin/env bash
# .agent/scripts/tests/run_script_tests.sh
# Runner for every .agent/scripts/tests/test_*.sh suite (issue #269 PR A).
#
# Before this script, .github/workflows/validate.yml explicitly named only
# three of this repo's ten existing test_*.sh scripts by individual `run:`
# steps; the other seven ran nowhere in CI. This runner globs and executes
# every test_*.sh in its directory (auto-discovery for future suites) and
# additionally, separately, asserts by exact filename that
# test_checkpoint_269.sh is present and was executed — see "Protecting the
# checkpoint test from edit/deletion" in .agent/work-plans/issue-269/plan.md:
# if test_checkpoint_269.sh is ever deleted, this runner fails loudly (the
# whole pre-commit hook goes red) rather than the glob silently running one
# fewer suite.
#
# Fail-fast: the first suite to exit non-zero stops the run immediately —
# remaining suites are not executed. This keeps a broken suite's failure
# unambiguous (no unrelated failures interleaved in the same run) and keeps
# runtime bounded by the first failure, not the whole suite list.
#
# Usage: run_script_tests.sh [tests-dir]
#   tests-dir defaults to this script's own directory. The parameter exists
#   so test_run_script_tests.sh can point the runner at a scratch copy of the
#   tests directory without touching the real one.
#
# Exit codes:
#   0  all suites passed
#   1  a suite failed, or a preflight check failed — test_checkpoint_269.sh
#      missing from the discovered set, a required tool missing, or the
#      absolute-/tmp mktemp lint found a violation (the message says which)
#   2  a suite left files behind in TMPDIR after it ran (leak detected; the
#      message names the suite that leaked and the leftover paths)
#
# Wired into .pre-commit-config.yaml as the `validate-script-tests` local
# hook (always_run: true) inside the existing Lint (pre-commit) job — no
# .github/workflows/validate.yml edit. SKIP=validate-script-tests is the
# sanctioned escape for work-in-progress commits (same SKIP= mechanism this
# repo's other local hooks already support).
#
# Git-hook environment sanitization (found while wiring this into
# .pre-commit-config.yaml for the first time — none of these suites had
# previously run from a `git commit`-triggered hook, only from a bare
# `pre-commit run` or directly in CI): `git commit` sets GIT_DIR /
# GIT_WORK_TREE / GIT_INDEX_FILE (and friends) in the environment it passes
# to pre-commit's hook process and everything that process spawns. Several
# suites build their own sandbox git repos with `git -C <sandbox-dir> ...`;
# with GIT_DIR etc. still set from the outer `git commit`, git prioritizes
# those env vars over `-C`'s directory-based discovery, so `-C <sandbox>`
# operations silently hit the REAL repo's .git instead (reproduced: a
# sandbox `git remote add origin` failed with "remote origin already
# exists" because it had added the remote to the real repo, which already
# has one). Unset the whole GIT_* hook-context family before running any
# suite so every suite's own `-C`/`cd` based git usage resolves the repo it
# actually names.

set -uo pipefail

# See "Git-hook environment sanitization" above.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR \
      GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_PREFIX

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="${1:-$SCRIPT_DIR}"
REQUIRED_SUITE="test_checkpoint_269.sh"

if [[ ! -d "$TESTS_DIR" ]]; then
    echo "error: tests directory not found: $TESTS_DIR" >&2
    exit 1
fi

shopt -s nullglob
suites=("$TESTS_DIR"/test_*.sh)
shopt -u nullglob

if [[ ${#suites[@]} -eq 0 ]]; then
    echo "error: no test_*.sh suites found in $TESTS_DIR" >&2
    exit 1
fi

found_required=0
for s in "${suites[@]}"; do
    if [[ "$(basename "$s")" == "$REQUIRED_SUITE" ]]; then
        found_required=1
        break
    fi
done
if [[ "$found_required" -ne 1 ]]; then
    echo "error: required suite '$REQUIRED_SUITE' not found in $TESTS_DIR — the checkpoint gate would silently stop running" >&2
    exit 1
fi

# Tool preflight: several suites shell out to these; name the missing tool
# up front instead of letting a suite fail opaquely. jq is installed by
# bootstrap.sh and present on GitHub's runners.
for tool in jq python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: '$tool' not found on PATH — required by the script test suites (see .agent/scripts/bootstrap.sh)" >&2
        exit 1
    fi
done

# Preflight lint: no absolute-/tmp mktemp destinations in the suites under
# $TESTS_DIR (issue #304, #297 PR 2). A suite that writes to a hardcoded
# /tmp path bypasses TMPDIR entirely, so the per-run guard below can
# neither contain nor see what it leaves behind. Issue #297 PR 1 normalised
# every such site in this directory; this lint is the regression guard that
# keeps it that way. It scans $TESTS_DIR (the caller-supplied [tests-dir]),
# not a hardcoded path, so test_run_script_tests.sh can exercise it against
# a scratch fixture directory.
#
# Scope is "$TESTS_DIR"/test_*.sh — the suites the runner actually executes.
# That glob is also what exempts this file: the runner's own guard mktemp
# below legitimately hardcodes /tmp (see below) and is excluded because
# run_script_tests.sh is not a test_*.sh suite, not because of any pattern
# contortion. test_run_script_tests.sh *is* in scope, so its lint fixtures
# assemble their templates at runtime rather than spelling them inline.
#
# The pattern covers every mktemp spelling that escapes TMPDIR:
#   mktemp [-d] /tmp/<template>      bare absolute template
#   mktemp -d -p /tmp <template>     -p / --tmpdir root
#   mktemp -d --tmpdir=/tmp <t>      (and the space-separated --tmpdir /tmp)
# `/tmp` must be preceded by a whitespace/quote/`=`/`(` boundary, so a path
# that merely ends in .../tmp/... (e.g. "$HOME/local/tmp/x.XXXXXX") is not a
# hit, and must be followed by `/`, whitespace, a quote, `)` or end of line
# so `/tmpfile.XXXXXX` is not one either. `[^|]*` keeps the match inside one
# command rather than spanning a pipeline. This is a heuristic over file
# text, not a shell parse: it reads literals only, so a /tmp root that
# arrives through a variable is invisible to it.
lint_hits=$(grep -rnE 'mktemp[^|]*[[:space:]"'"'"'=(]/tmp(/|$|[[:space:]"'"'"')])' "$TESTS_DIR"/test_*.sh 2>/dev/null) || true
if [[ -n "$lint_hits" ]]; then
    echo "error: absolute /tmp mktemp destination(s) found in $TESTS_DIR — suites must honor TMPDIR (use \`mktemp -d\` or \`mktemp -d -p \"\$SANDBOX\"\`, never a /tmp template, \`-p /tmp\` or \`--tmpdir=/tmp\`) so the per-run leak guard can see their temp files:" >&2
    echo "$lint_hits" >&2
    exit 1
fi

# --- Per-run TMPDIR guard (issue #304, #297 PR 2) ---
#
# Give the whole run one private temp root and point every suite at it via
# TMPDIR/TMP/TEMP. After each suite returns successfully the loop below
# sweeps this directory: anything still in it means that suite leaked, and
# the run fails with exit 2 naming that suite. Attribution is why the sweep
# sits inside the loop rather than at the end — a leak is charged to the
# suite that caused it, not to whichever suite happened to run last.
#
# The sweep sees *everything* left in TMPDIR, not just a suite's own
# sandbox — including residue from tools a suite shells out to (git, gh,
# pre-commit, python3). That is deliberate: such residue is a leak too. The
# full real-suite run is the empirical check that no false positive exists
# today; if this ever fires on tool residue, investigate the attribution
# rather than assuming the guard is broken.
#
# The guard directory hardcodes /tmp and deliberately ignores the caller's
# own TMPDIR: a nested run — this repo's test_run_script_tests.sh drives
# this runner against scratch tests directories — must not have its guard
# redirected into the outer run's temp root or into the scratch tests
# directory itself. The preflight lint above does not object, because it
# scans "$TESTS_DIR"/test_*.sh and this file is the runner, not a suite.
#
# Coverage boundary: the sweep only sees what lands in TMPDIR while a suite
# runs, and the lint only covers "$TESTS_DIR"/test_*.sh. Eight absolute-/tmp
# mktemp sites remain in production scripts that suites may invoke —
# worktree_create.sh:933,974, pr_status.sh:321,336, gh_create_pr.sh:237,306,
# fetch_pr_reviews.sh:148, gh_create_issue.sh:205 (cited as file:line only;
# reproducing one of those templates here would trip the lint above).
# Temp files those calls create bypass both TMPDIR and this sweep. Fixing
# them is out of scope for #304.
#
# One-time cleanup of the historical leak (#297 measured 320 dirs/run before
# PR 1): this is a manual step for a human, not something this script does.
# Review the dry run first —
#   find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +1 \
#       -exec sh -c '[ -d "$1/.git" ] && echo "$1"' _ {} \;
# and only then the deleting form —
#   find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +1 \
#       -exec sh -c '[ -d "$1/.git" ] && rm -rf "$1"' _ {} \;
# Caveat: the .git filter only matches when .git sits directly at depth 1 of
# the sandbox root (the root itself was `git init`'d). Suites that nest their
# fixture repos deeper are not matched, and test_adapter.sh,
# test_project_registry.sh and test_dispatch_phase.sh create no git repos at
# all — none of their leftovers match. Measured 2026-09-21: 16,679 /tmp/tmp.*
# directories, 5,934 with a depth-1 .git. For the rest, an age-based sweep a
# human eyeballs first: find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +7
RUN_TMPDIR=$(mktemp -d --tmpdir=/tmp run-script-tests.XXXXXX) || {
    echo "error: could not create the per-run TMPDIR guard directory under /tmp" >&2
    exit 1
}
# Unconditional cleanup on every exit path after this point — all suites
# passed, a suite failed, a leak was detected, or an interrupt.
trap 'rm -rf "$RUN_TMPDIR"' EXIT
export TMPDIR="$RUN_TMPDIR" TMP="$RUN_TMPDIR" TEMP="$RUN_TMPDIR"

start_ts=$(date +%s)
total=0
for s in "${suites[@]}"; do
    name="$(basename "$s")"
    total=$((total + 1))
    echo "=== run_script_tests: running $name ==="
    if ! bash "$s"; then
        end_ts=$(date +%s)
        elapsed=$((end_ts - start_ts))
        echo "" >&2
        echo "run_script_tests: FAILED at $name (suite $total of ${#suites[@]}) after ${elapsed}s — stopping, remaining suites not run" >&2
        exit 1
    fi

    # Leak sweep — see "Per-run TMPDIR guard" above. Runs only on the path
    # that would otherwise advance to the next suite, so the leak is
    # attributed to the suite that just finished.
    leaked=$(find "$RUN_TMPDIR" -mindepth 1 -maxdepth 1 2>/dev/null)
    if [[ -n "$leaked" ]]; then
        end_ts=$(date +%s)
        elapsed=$((end_ts - start_ts))
        echo "" >&2
        echo "run_script_tests: FAILED at $name (suite $total of ${#suites[@]}) after ${elapsed}s — it left files behind in TMPDIR ($RUN_TMPDIR):" >&2
        echo "$leaked" >&2
        echo "Every suite must clean up what it creates — one top-level sandbox plus an EXIT trap (see issue #297)." >&2
        exit 2
    fi
done

end_ts=$(date +%s)
elapsed=$((end_ts - start_ts))
echo ""
echo "run_script_tests: all $total suites passed in ${elapsed}s"
exit 0
