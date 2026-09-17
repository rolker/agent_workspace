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
# Exit codes: 0 all suites passed; 1 a suite failed, or test_checkpoint_269.sh
# is missing from the discovered set.
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
done

end_ts=$(date +%s)
elapsed=$((end_ts - start_ts))
echo ""
echo "run_script_tests: all $total suites passed in ${elapsed}s"
exit 0
