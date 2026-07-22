#!/usr/bin/env bash
# Tests for sync_gitbug() in .agent/project_types/single_project/sync.py
# (issue #221).
#
# The bug: bridge detection ran `git bug bridge list`, which is not a
# valid command in git-bug v0.10.1 (`git bug bridge` with NO subcommand
# lists bridges). The nonzero exit made sync_gitbug return early and
# silently, so `make sync` never actually synced git-bug issues.
#
# Pattern: a fake `git` (and `git-bug`, for shutil.which) is placed
# first in PATH; it records every argv line to a log file and simulates
# bridge listing via the GIT_SHIM_BRIDGES env var. The tests then call
# sync_gitbug() directly and assert on the recorded invocations.
#
# Run: bash .agent/scripts/tests/test_sync_gitbug.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SYNC_PY="${ROOT_DIR}/.agent/project_types/single_project/sync.py"

PASS=0
FAIL=0
TMPDIR_BASE=""

setup() {
    TMPDIR_BASE=$(mktemp -d /tmp/test_sync_gitbug.XXXXXX)
    mkdir -p "${TMPDIR_BASE}/bin" "${TMPDIR_BASE}/repo"
    git init -q "${TMPDIR_BASE}/repo"

    # Fake git: log argv, answer `bug bridge` with $GIT_SHIM_BRIDGES.
    cat > "${TMPDIR_BASE}/bin/git" <<'SHIM'
#!/usr/bin/env bash
echo "$*" >> "${GIT_SHIM_LOG}"
if [ "$#" -eq 2 ] && [ "$1" = "bug" ] && [ "$2" = "bridge" ]; then
    printf '%s' "${GIT_SHIM_BRIDGES:-}"
fi
exit 0
SHIM
    # Fake git-bug so shutil.which("git-bug") succeeds.
    printf '#!/usr/bin/env bash\nexit 0\n' > "${TMPDIR_BASE}/bin/git-bug"
    chmod +x "${TMPDIR_BASE}/bin/git" "${TMPDIR_BASE}/bin/git-bug"
}

teardown() {
    if [[ -n "$TMPDIR_BASE" && -d "$TMPDIR_BASE" ]]; then
        rm -rf "$TMPDIR_BASE"
    fi
}
trap teardown EXIT

assert_log_has() {
    local label="$1" needle="$2" log="$3"
    if grep -qxF "$needle" "$log"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected log line: $needle"
        echo "    log was:"
        sed 's/^/      /' "$log"
        FAIL=$((FAIL + 1))
    fi
}

assert_log_lacks() {
    local label="$1" needle="$2" log="$3"
    if grep -qF "$needle" "$log"; then
        echo "  FAIL: $label"
        echo "    log unexpectedly contains: $needle"
        sed 's/^/      /' "$log"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    fi
}

# Call sync_gitbug(repo, dry_run) with the shims first in PATH.
run_sync_gitbug() {
    local dry_run="$1"
    PATH="${TMPDIR_BASE}/bin:${PATH}" \
    GIT_SHIM_LOG="${GIT_SHIM_LOG}" \
    GIT_SHIM_BRIDGES="${GIT_SHIM_BRIDGES}" \
    python3 - "$SYNC_PY" "${TMPDIR_BASE}/repo" "$dry_run" <<'PY'
import importlib.util
import sys
from pathlib import Path

sync_path, repo, dry_run = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
spec = importlib.util.spec_from_file_location("sync_under_test", sync_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
mod.sync_gitbug(Path(repo), dry_run=dry_run)
PY
}

# ---- Test: bridge detection uses `git bug bridge` (no `list`) ----
test_detection_command() {
    echo "TEST: bridge detection uses 'git bug bridge' with no subcommand (#221)"
    setup
    GIT_SHIM_LOG="${TMPDIR_BASE}/argv.log"; : > "$GIT_SHIM_LOG"
    GIT_SHIM_BRIDGES="github"

    run_sync_gitbug 0 > /dev/null

    assert_log_has "detection is exactly 'bug bridge'" "bug bridge" "$GIT_SHIM_LOG"
    assert_log_lacks "invalid 'bridge list' is never invoked" "bridge list" "$GIT_SHIM_LOG"
    teardown
}

# ---- Test: configured bridge -> pull and push run ----
test_sync_runs_when_bridge_configured() {
    echo "TEST: pull/push run when a bridge is configured"
    setup
    GIT_SHIM_LOG="${TMPDIR_BASE}/argv.log"; : > "$GIT_SHIM_LOG"
    GIT_SHIM_BRIDGES="github"

    run_sync_gitbug 0 > /dev/null

    assert_log_has "bridge pull invoked" "bug bridge pull github" "$GIT_SHIM_LOG"
    assert_log_has "bridge push invoked" "bug bridge push github" "$GIT_SHIM_LOG"
    teardown
}

# ---- Test: no bridge configured -> no pull/push ----
test_skips_when_no_bridge() {
    echo "TEST: pull/push skipped when no bridge is configured"
    setup
    GIT_SHIM_LOG="${TMPDIR_BASE}/argv.log"; : > "$GIT_SHIM_LOG"
    GIT_SHIM_BRIDGES=""

    run_sync_gitbug 0 > /dev/null

    assert_log_has "detection still ran" "bug bridge" "$GIT_SHIM_LOG"
    assert_log_lacks "no pull without a bridge" "bug bridge pull" "$GIT_SHIM_LOG"
    assert_log_lacks "no push without a bridge" "bug bridge push" "$GIT_SHIM_LOG"
    teardown
}

# ---- Test: dry run detects but does not pull/push ----
test_dry_run_does_not_sync() {
    echo "TEST: dry run prints intent without invoking pull/push"
    setup
    GIT_SHIM_LOG="${TMPDIR_BASE}/argv.log"; : > "$GIT_SHIM_LOG"
    GIT_SHIM_BRIDGES="github"

    local out
    out=$(run_sync_gitbug 1)

    assert_log_lacks "dry run: no real pull" "bug bridge pull" "$GIT_SHIM_LOG"
    assert_log_lacks "dry run: no real push" "bug bridge push" "$GIT_SHIM_LOG"
    if [[ "$out" == *"[DRY-RUN]"*"bridge pull github"* ]]; then
        echo "  PASS: dry run announces the pull it would run"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: dry run output missing DRY-RUN pull line"
        echo "    output: $out"
        FAIL=$((FAIL + 1))
    fi
    teardown
}

# ---- Run all tests ----
echo "=== sync_gitbug bridge-detection tests (#221) ==="
echo ""

test_detection_command
test_sync_runs_when_bridge_configured
test_skips_when_no_bridge
test_dry_run_does_not_sync

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
