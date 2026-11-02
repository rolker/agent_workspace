#!/usr/bin/env bash
# Tests for .agent/scripts/check_agents_md_budget.sh (issue #259).
#
# The checker fails a commit when AGENTS.md is over 200 lines. Every case
# writes a fixture file under a private temp dir and points the checker at
# it, or (cases e to g) runs a sandbox copy of the checker with no argument,
# the way the hook calls it, beside a fixture AGENTS.md; the suite reads no
# real AGENTS.md.
#
# Cases:
#   (a) 200 lines passes
#   (b) 201 lines fails, naming the count and the limit
#   (c) 201 lines with no final newline still fails
#   (d) a missing file is an error (exit 2), not a pass
#   (e) no argument, run from another directory: a 201-line AGENTS.md at
#       the root of the checker's repository fails, naming that file
#   (f) no argument, the same way: a 200-line AGENTS.md there passes
#   (g) no argument, run through the repo-root `scripts/` symlink: the
#       checker reads its repository's 201-line AGENTS.md and fails, not
#       the 1-line decoy in the repository's parent folder
#
# Run: bash .agent/scripts/tests/test_agents_md_budget.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="${SCRIPT_DIR}/../check_agents_md_budget.sh"

PASS=0
FAIL=0

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# run_checker <file> -- sets RC and OUT (stdout and stderr together).
run_checker() {
    RC=0
    OUT="$(bash "$CHECKER" "$1" 2>&1)" || RC=$?
}

expect() {  # <label> <want-rc> [<grep -F text that must appear in OUT>...]
    local label="$1" want="$2" text
    shift 2
    if [[ "$RC" != "$want" ]]; then
        fail "$label: exit $RC, want $want; output: $OUT"
        return
    fi
    for text in "$@"; do
        if ! grep -qF -- "$text" <<<"$OUT"; then
            fail "$label: output lacks '$text'; output: $OUT"
            return
        fi
    done
    pass "$label"
}

echo "check_agents_md_budget.sh"

seq 1 200 > "$SANDBOX/at_limit.md"
run_checker "$SANDBOX/at_limit.md"
expect "(a) 200 lines passes" 0

seq 1 201 > "$SANDBOX/over.md"
run_checker "$SANDBOX/over.md"
expect "(b) 201 lines fails with count and limit" 1 "201 lines" "budget of 200"

{ seq 1 200; printf '201'; } > "$SANDBOX/no_newline.md"
run_checker "$SANDBOX/no_newline.md"
expect "(c) 201 lines without final newline fails" 1 "201 lines"

run_checker "$SANDBOX/missing.md"
expect "(d) missing file is an error" 2 "cannot read"

# (e)/(f): the hook passes no argument, so the checker finds AGENTS.md from
# its own location. A sandbox copy at <repo>/.agent/scripts/ must read
# <repo>/AGENTS.md whatever the current directory is.
mkdir -p "$SANDBOX/repo/.agent/scripts" "$SANDBOX/elsewhere"
cp "$CHECKER" "$SANDBOX/repo/.agent/scripts/check_agents_md_budget.sh"
SANDBOX_REPO="$(cd "$SANDBOX/repo" && pwd -P)"

# run_checker_no_arg -- runs the sandbox copy from another directory.
run_checker_no_arg() {
    RC=0
    OUT="$(cd "$SANDBOX/elsewhere" && bash "$SANDBOX_REPO/.agent/scripts/check_agents_md_budget.sh" 2>&1)" || RC=$?
}

seq 1 201 > "$SANDBOX/repo/AGENTS.md"
run_checker_no_arg
expect "(e) no argument: 201-line AGENTS.md beside the checker fails" 1 \
    "201 lines" "$SANDBOX_REPO/AGENTS.md"

seq 1 200 > "$SANDBOX/repo/AGENTS.md"
run_checker_no_arg
expect "(f) no argument: 200-line AGENTS.md beside the checker passes" 0

# (g): a lexical `../..` from <repo>/scripts/ is the repository's parent,
# where a 1-line decoy AGENTS.md would make a wrong resolution pass.
ln -s .agent/scripts "$SANDBOX_REPO/scripts"
seq 1 201 > "$SANDBOX_REPO/AGENTS.md"
echo decoy > "$SANDBOX/AGENTS.md"
RC=0
OUT="$(cd "$SANDBOX/elsewhere" && bash "$SANDBOX_REPO/scripts/check_agents_md_budget.sh" 2>&1)" || RC=$?
expect "(g) no argument through the scripts/ symlink reads the repository's AGENTS.md" 1 \
    "201 lines" "$SANDBOX_REPO/AGENTS.md"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
