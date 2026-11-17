#!/usr/bin/env bash
# Tests for .agent/scripts/pr_status.sh --all-repos repository discovery
# (issue #265 part 4): the project repositories are the registered roots'
# github.com repositories, read from the registry; a project/ checkout in
# the workspace is not read.
#
# A sandbox workspace holds a copy of pr_status.sh and the registry helper;
# `gh` is a stub on PATH that records each `pr list --repo <slug>` and
# answers an empty list, so nothing touches the network.
#
# Run: bash .agent/scripts/tests/test_pr_status.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

WS="$SANDBOX/ws"
mkdir -p "$WS/.agent/scripts" "$SANDBOX/bin"
cp "$SCRIPT_DIR/../pr_status.sh" "$SCRIPT_DIR/../_project_registry.sh" "$WS/.agent/scripts/"
git -C "$WS" init -q -b main
git -C "$WS" remote add origin https://github.com/ws-owner/ws.git

GH_LOG="$SANDBOX/gh.log"
cat > "$SANDBOX/bin/gh" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == pr && "\$2" == list ]]; then
    while [[ \$# -gt 0 ]]; do
        [[ "\$1" == --repo ]] && echo "\$2" >> "$GH_LOG"
        shift
    done
    echo "[]"
    exit 0
fi
exit 1
EOF
chmod +x "$SANDBOX/bin/gh"

run_all_repos() {
    rm -f "$GH_LOG"
    (cd "$WS" && PATH="$SANDBOX/bin:$PATH" bash "$WS/.agent/scripts/pr_status.sh" --all-repos --simple >/dev/null 2>&1)
}

echo "TEST: --all-repos asks the workspace and every registered root's repository, never project/"
# A project/ checkout in the workspace (the retired shape) with its own
# github.com origin, and two registered roots outside the workspace.
git init -q -b main "$WS/project"
git -C "$WS/project" remote add origin https://github.com/legacy-owner/legacy.git
git init -q -b main "$SANDBOX/alpha"
git -C "$SANDBOX/alpha" remote add origin git@github.com:demo-owner/alpha.git
git init -q -b main "$SANDBOX/beta"
git -C "$SANDBOX/beta" remote add origin https://github.com/demo-owner/beta
printf 'alpha single_project %s\nbeta single_project %s\n' "$SANDBOX/alpha" "$SANDBOX/beta" > "$WS/.agent/projects.local"
run_all_repos
asked="$(sort "$GH_LOG" 2>/dev/null | tr '\n' ' ')"
[[ "$asked" == "demo-owner/alpha demo-owner/beta ws-owner/ws " ]] \
    && pass "the workspace and both registered roots are asked" || fail "asked: [$asked]"
[[ "$asked" != *legacy-owner* ]] && pass "the project/ checkout's repository is not asked" || fail "project/ was read: [$asked]"

echo "TEST: --all-repos with nothing registered asks the workspace alone"
: > "$WS/.agent/projects.local"
run_all_repos
asked="$(sort "$GH_LOG" 2>/dev/null | tr '\n' ' ')"
[[ "$asked" == "ws-owner/ws " ]] && pass "only the workspace is asked" || fail "asked: [$asked]"

echo ""
echo "test_pr_status: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
