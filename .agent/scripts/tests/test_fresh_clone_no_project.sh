#!/usr/bin/env bash
# .agent/scripts/tests/test_fresh_clone_no_project.sh
# Acceptance test for issue #295, pull request A ("a fresh clone works with
# no project"): a fresh copy of the workspace on a machine where nothing is
# registered and no project/ exists validates, sets up, shows its dashboard
# and syncs, and after a project is registered, gh_create_pr.sh run in that
# project's own checkout passes its repo-safety check.
#
# What it tests is the COMMITTED content of this checkout (HEAD, exported
# with `git archive`): uncommitted changes in the worktree are not tested.
# The copy is a new repository with one commit, so a shallow or detached CI
# checkout works the same as a local one.
#
# Offline and hermetic: a scratch HOME (so the real ~/.claude and the real
# registry are never read or written), CI=1 and a pre-seeded
# .make/setup-dev.done (so make never runs pip and git-bug setup skips), the
# copy's `origin` is a local bare repository, and `gh` is a stub on PATH
# that records `gh pr create` and fails every other call. No real project
# is named; the registered project is a synthetic `demo` checkout whose
# github.com origin is never contacted.
#
# Run: bash .agent/scripts/tests/test_fresh_clone_no_project.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# One sandbox for the whole run, created at top level so the trap fires
# (issue #297).
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

SCRATCH_HOME="$SANDBOX/home"
WS="$SANDBOX/ws"
BARE="$SANDBOX/ws-origin.git"
DEMO="$SANDBOX/demo"
STUB_BIN="$SANDBOX/bin"
GH_LOG="$SANDBOX/gh-pr-create.log"
mkdir -p "$SCRATCH_HOME" "$WS" "$STUB_BIN"

# git identity for the fixture commits only (the scratch HOME has none).
fixture_git() {
    git -c user.name=fixture -c user.email=fixture@example.invalid \
        -c init.defaultBranch=main -c core.hooksPath=/dev/null "$@"
}

# --- The fresh copy -----------------------------------------------------------
if ! git -C "$REAL_ROOT" archive --format=tar HEAD | tar -x -C "$WS"; then
    fail "could not export HEAD of $REAL_ROOT"
    echo "=== Results: $PASS passed, $FAIL failed ==="
    exit 1
fi
fixture_git -C "$WS" init -q
fixture_git -C "$WS" add -A
fixture_git -C "$WS" commit -q -m "fresh copy"
fixture_git clone -q --bare "$WS" "$BARE"
fixture_git -C "$WS" remote add origin "$BARE"
fixture_git -C "$WS" fetch -q origin
fixture_git -C "$WS" branch -q --set-upstream-to=origin/main main
mkdir -p "$WS/.make"
touch "$WS/.make/setup-dev.done"

# --- The gh stub -------------------------------------------------------------
cat > "$STUB_BIN/gh" <<EOF
#!/bin/bash
if [[ "\$1" = "pr" && "\$2" = "create" ]]; then
    printf '%s\n' "\$@" > "$GH_LOG"
    exit 0
fi
echo "gh stub: offline test, refusing: \$*" >&2
exit 1
EOF
chmod +x "$STUB_BIN/gh"

# Run a command with a clean environment: scratch HOME, CI=1, the stub
# first on PATH. Sets OUT and RC.
OUT=""
RC=0
run_clean() {  # <dir> <command> [args...]
    local dir="$1"; shift
    OUT="$(cd "$dir" && env -i PATH="$STUB_BIN:$PATH" HOME="$SCRATCH_HOME" CI=1 \
        TMPDIR="${TMPDIR:-/tmp}" LANG=C.UTF-8 "$@" 2>&1 </dev/null)"
    RC=$?
}

no_project_dirs() {  # <label>
    if [[ ! -e "$WS/project" && ! -e "$WS/projects" ]]; then
        pass "$1: no project/ or projects/ written"
    else
        fail "$1: project/ or projects/ appeared"
    fi
}

echo "=== Fresh copy, nothing registered ==="

# (a) make validate
run_clean "$WS" make --no-print-directory validate
if [[ "$RC" -eq 0 && "$OUT" == *"Workspace validation PASSED"* ]]; then
    pass "(a) make validate exits 0"
else
    fail "(a) make validate: rc=$RC out=${OUT:0:600}"
fi
if [[ "$OUT" == *"no project registered (register one with .agent/scripts/register_project.sh <path>)"* ]]; then
    pass "(a) make validate says no project is registered and names register_project.sh"
else
    fail "(a) no 'no project registered' line: ${OUT:0:600}"
fi
no_project_dirs "(a)"

# (b) make setup, no input
run_clean "$WS" make --no-print-directory setup
if [[ "$RC" -eq 0 && "$OUT" == *"Setup complete."* ]]; then
    pass "(b) make setup </dev/null exits 0 without a prompt"
else
    fail "(b) make setup: rc=$RC out=${OUT:0:600}"
fi
if [[ "$OUT" == *"No project is registered. Register one: .agent/scripts/register_project.sh <path>"* \
      && "$OUT" == *"Optional, enable the workspace in project sessions: .agent/scripts/user_tier_install.sh"* ]]; then
    pass "(b) make setup prints both pointer lines"
else
    fail "(b) pointer lines missing: ${OUT:0:600}"
fi
no_project_dirs "(b)"

# (c) make dashboard
run_clean "$WS" make --no-print-directory dashboard
if [[ "$RC" -eq 0 ]]; then
    pass "(c) make dashboard exits 0"
else
    fail "(c) make dashboard: rc=$RC out=${OUT:0:600}"
fi
if [[ "$OUT" == *"register_project.sh"* && "$OUT" != *"Run: make setup"* && "$OUT" != *"run: make setup"* ]]; then
    pass "(c) make dashboard names register_project.sh and does not say to run make setup"
else
    fail "(c) dashboard pointers: ${OUT:0:1200}"
fi
no_project_dirs "(c)"

# (d) make sync (no dry run; origin is the local bare repository)
run_clean "$WS" make --no-print-directory sync
if [[ "$RC" -eq 0 && "$OUT" == *"Sync complete."* ]]; then
    pass "(d) make sync exits 0"
else
    fail "(d) make sync: rc=$RC out=${OUT:0:600}"
fi
if [[ "$OUT" == *"Checking agent_workspace (workspace)"* && "$OUT" == *"No project was synced"* ]]; then
    pass "(d) make sync syncs the workspace and says no project was synced"
else
    fail "(d) sync output: ${OUT:0:600}"
fi
no_project_dirs "(d)"

echo "=== After registering a demo project ==="

# (e) register the demo checkout, then gh_create_pr.sh from inside it
fixture_git init -q "$DEMO"
fixture_git -C "$DEMO" commit -q --allow-empty -m "demo"
fixture_git -C "$DEMO" remote add origin https://github.com/demo-owner/demo.git
run_clean "$WS" "$WS/.agent/scripts/register_project.sh" "$DEMO" \
    --set build=none --set test=none --skip-run
if [[ "$RC" -eq 0 && "$OUT" == *"STATUS="* && "$OUT" != *"STATUS=refused"* ]]; then
    pass "(e) register_project.sh registers the demo checkout"
else
    fail "(e) register_project.sh: rc=$RC out=${OUT:0:800}"
fi
rm -f "$GH_LOG"
run_clean "$DEMO" "$WS/.agent/scripts/gh_create_pr.sh" --title t --body b --no-signature
if [[ "$RC" -eq 0 && -f "$GH_LOG" ]]; then
    pass "(e) gh_create_pr.sh in the demo checkout passes the repo-safety check (gh pr create reached)"
else
    fail "(e) gh_create_pr.sh: rc=$RC out=${OUT:0:600}"
fi
no_project_dirs "(e)"

echo "=== A worktree of the copy, with the demo project registered in the main checkout ==="

# (f) The registry is gitignored, so a worktree has none of its own. Every
# "is a project registered?" message reads the main checkout's registry,
# found through git's common dir, so none of them says that no project is
# registered here. The worktree lives outside worktrees/workspace/, where
# the dashboard's path-based main-checkout guess does not reach.
WT="$SANDBOX/ws-wt"
fixture_git -C "$WS" worktree add -q -b wt-check "$WT" main
if [[ -f "$WS/.agent/projects.local" && ! -e "$WT/.agent/projects.local" ]]; then
    pass "(f) the worktree has no registry of its own; the main checkout has one"
else
    fail "(f) fixture: registry files not as expected"
fi
NONE_PATTERNS=("no project registered" "No project is registered" "none registered")
says_none() {
    local p
    for p in "${NONE_PATTERNS[@]}"; do
        [[ "$OUT" == *"$p"* ]] && return 0
    done
    return 1
}
run_clean "$WT" make --no-print-directory validate
if [[ "$RC" -eq 0 ]] && ! says_none; then
    pass "(f) make validate in the worktree does not say no project is registered"
else
    fail "(f) make validate in the worktree: rc=$RC out=${OUT:0:800}"
fi
run_clean "$WT" make --no-print-directory sync
if [[ "$RC" -eq 0 && "$OUT" == *"Sync complete."* ]] && ! says_none; then
    pass "(f) make sync in the worktree does not say no project is registered"
else
    fail "(f) make sync in the worktree: rc=$RC out=${OUT:0:800}"
fi
run_clean "$WT" make --no-print-directory setup
if [[ "$RC" -eq 0 ]] && ! says_none; then
    pass "(f) make setup in the worktree does not say no project is registered"
else
    fail "(f) make setup in the worktree: rc=$RC out=${OUT:0:800}"
fi
run_clean "$WT" make --no-print-directory dashboard
if [[ "$RC" -eq 0 ]] && ! says_none; then
    pass "(f) make dashboard in the worktree does not say no project is registered"
else
    fail "(f) make dashboard in the worktree: rc=$RC out=${OUT:0:1200}"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
