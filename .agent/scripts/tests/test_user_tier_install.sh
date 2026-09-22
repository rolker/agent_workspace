#!/usr/bin/env bash
# .agent/scripts/tests/test_user_tier_install.sh
# Tests for .agent/scripts/user_tier_install.sh (#317, #265 PR 3):
# idempotent install, the not-installed / --require split, drift detection
# (foreign entry, missing entry, stale symlink), skill selection from
# session_scope frontmatter, and uninstall.
#
# Hermetic: HOME is redirected to a sandbox for every invocation, so the
# real ~/.claude is never read or written. The installer is run against a
# COPY of the workspace checkout, so the test can add and remove skills
# without touching the real ones. No network, no gh.
#
# Run: bash .agent/scripts/tests/test_user_tier_install.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required" >&2; exit 1; }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# A workspace copy: the installer writes absolute paths into it, and the
# test mutates its skills, so it must not be the real checkout.
WSC="$SANDBOX/ws"
mkdir -p "$WSC"
cp -r "$WS_ROOT/.agent" "$WSC/.agent"
cp -r "$WS_ROOT/.claude" "$WSC/.claude"
INSTALL="$WSC/.agent/scripts/user_tier_install.sh"

HOMEDIR="$SANDBOX/home"
mkdir -p "$HOMEDIR"

run() {  # run the installer with the sandbox HOME
    HOME="$HOMEDIR" bash "$INSTALL" "$@" 2>&1
}

SETTINGS="$HOMEDIR/.claude/settings.json"
ROOT_FILE="$HOMEDIR/.claude/agent-workspace-root"
SKILLS_DIR="$HOMEDIR/.claude/skills"
HOOK_LINK="$HOMEDIR/.claude/hooks/agent-workspace-session-start.sh"

# ------------------------------------------------- skill scope selection ---
# Give the copy two scoped skills and one unscoped, so selection is checked
# against known input rather than whatever the checkout happens to carry.
mk_skill() {  # <name> [scope]
    local n="$1" scope="${2:-}"
    mkdir -p "$WSC/.claude/skills/$n"
    {
        echo "---"
        echo "name: $n"
        echo "description: fixture"
        [[ -n "$scope" ]] && echo "session_scope: $scope"
        echo "---"
        echo ""
        echo "# $n"
    } > "$WSC/.claude/skills/$n/SKILL.md"
}
mk_skill zz-fixture-both project
mk_skill zz-fixture-proj project
mk_skill zz-fixture-ws

listed="$(run --list-skills)"
[[ "$listed" == *"zz-fixture-both"* && "$listed" == *"zz-fixture-proj"* ]] \
    && pass "--list-skills includes session_scope project/both skills" \
    || fail "--list-skills missed a scoped skill (got: $(tr '\n' ' ' <<< "$listed"))"
[[ "$listed" != *"zz-fixture-ws"* ]] \
    && pass "--list-skills excludes a skill with no session_scope (workspace is the default)" \
    || fail "--list-skills included an unscoped skill"

# ------------------------------------------------------- not installed ---
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"not installed"* ]] \
    && pass "--check on a machine with no user tier: exits 0 with a note (make validate stays green)" \
    || fail "--check when not installed (rc=$rc out=$out)"

out="$(run --check --require)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"NOT INSTALLED"* ]] \
    && pass "--check --require when not installed: exits 1" \
    || fail "--check --require when not installed (rc=$rc out=$out)"

# ------------------------------------------------------------- install ---
out="$(run)"; rc=$?
[[ "$rc" -eq 0 ]] && pass "install exits 0" || fail "install failed (rc=$rc out=$out)"

[[ -f "$ROOT_FILE" && "$(cat "$ROOT_FILE")" == "$WSC" ]] \
    && pass "wrote ~/.claude/agent-workspace-root with the workspace path" \
    || fail "agent-workspace-root missing or wrong ($(cat "$ROOT_FILE" 2>/dev/null))"

# No trailing newline: skills do a bare `cat` and interpolate the result
# straight into a path.
[[ "$(wc -c < "$ROOT_FILE")" -eq "${#WSC}" ]] \
    && pass "agent-workspace-root has no trailing newline" \
    || fail "agent-workspace-root has a trailing newline ($(wc -c < "$ROOT_FILE") bytes vs ${#WSC})"

[[ -L "$HOOK_LINK" && "$(readlink "$HOOK_LINK")" == "$WSC/.claude/hooks/session_start_project_layer.sh" ]] \
    && pass "SessionStart hook symlink points at the checkout's hook" \
    || fail "SessionStart hook symlink wrong ($(readlink "$HOOK_LINK" 2>/dev/null))"

jq -e '.hooks.SessionStart | length > 0' "$SETTINGS" >/dev/null \
    && pass "settings.json has a SessionStart entry" || fail "no SessionStart entry"

for h in log-tool-use.sh block-bash-tool-mapping.sh; do
    if jq -e --arg c "$WSC/.claude/hooks/$h" \
        '[.hooks.PreToolUse[].hooks[]?.command] | index($c) != null' "$SETTINGS" >/dev/null; then
        pass "PreToolUse entry written by absolute path: $h"
    else
        fail "no absolute-path PreToolUse entry for $h"
    fi
done

jq -e --arg t "$WSC" '[.hooks | to_entries[] | .value[] | ._agent_workspace] | all(. == $t)' \
    "$SETTINGS" >/dev/null \
    && pass "every hook entry is tagged with this checkout" || fail "hook entries are not all tagged"

jq -e --arg c "$WSC/.agent/scripts/worktree_create.sh" \
    '[.permissions.allow[]] | index("Bash(" + $c + ":*)") != null' "$SETTINGS" >/dev/null \
    && pass "absolute-path allow-rule generated from the manifest" \
    || fail "no allow-rule for a manifest script"

[[ -L "$SKILLS_DIR/zz-fixture-proj" ]] \
    && pass "scoped skill symlinked into ~/.claude/skills/" || fail "scoped skill not symlinked"
[[ ! -e "$SKILLS_DIR/zz-fixture-ws" ]] \
    && pass "unscoped skill not symlinked" || fail "unscoped skill was symlinked"

out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check after install: clean" || fail "--check after install (rc=$rc out=$out)"

# ----------------------------------------------------------- idempotent ---
before="$(jq -S . "$SETTINGS")"
run >/dev/null
after="$(jq -S . "$SETTINGS")"
[[ "$before" == "$after" ]] \
    && pass "re-running the installer changes nothing (idempotent)" \
    || fail "a second install mutated settings.json"

n_pre=$(jq '.hooks.PreToolUse | length' "$SETTINGS")
[[ "$n_pre" -eq 1 ]] \
    && pass "re-install does not duplicate the PreToolUse entry" \
    || fail "PreToolUse has $n_pre entries after two installs"

# A user's own, untagged entries must survive.
tmp="$SANDBOX/s.json"
jq '.permissions.allow += ["Bash(mine *)"] |
    .hooks.PreToolUse += [{hooks: [{type: "command", command: "/opt/mine.sh"}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
run >/dev/null
if jq -e '([.permissions.allow[]] | index("Bash(mine *)") != null) and
          ([.hooks.PreToolUse[].hooks[]?.command] | index("/opt/mine.sh") != null)' \
   "$SETTINGS" >/dev/null; then
    pass "the user's own settings entries survive a re-install"
else
    fail "a re-install dropped the user's own entries"
fi

# --------------------------------------------------------------- drift ---
# (a) a missing hook entry
jq '.hooks.PreToolUse |= map(select((._agent_workspace // "") == ""))' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"missing hook entry"* ]] \
    && pass "--check detects a missing hook entry" || fail "missing-entry drift not detected (rc=$rc out=$out)"
run >/dev/null

# (b) a foreign entry from another checkout
jq '.hooks.PreToolUse += [{_agent_workspace: "/some/other/agent_workspace",
     hooks: [{type: "command", command: "/some/other/agent_workspace/.claude/hooks/x.sh"}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"another workspace checkout"* ]] \
    && pass "--check detects hook entries from another checkout" \
    || fail "foreign-entry drift not detected (rc=$rc out=$out)"
jq '.hooks.PreToolUse |= map(select((._agent_workspace // "") != "/some/other/agent_workspace"))' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

# (c) a stale symlink
ln -sfn "$SANDBOX/nowhere.sh" "$HOOK_LINK"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"stale SessionStart hook symlink"* ]] \
    && pass "--check detects a stale SessionStart symlink" \
    || fail "stale-symlink drift not detected (rc=$rc out=$out)"
run >/dev/null

# (d) a missing permission rule
jq '.permissions.allow |= map(select(contains("worktree_create.sh") | not))' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"permission allow-rule(s) missing"* ]] \
    && pass "--check detects missing permission rules" \
    || fail "missing-rule drift not detected (rc=$rc out=$out)"
run >/dev/null

# (e) a stale skill symlink after a scope change
rm -f "$SKILLS_DIR/zz-fixture-proj"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"skill not linked"* ]] \
    && pass "--check detects an unlinked skill" || fail "unlinked-skill drift not detected (rc=$rc out=$out)"
run >/dev/null

# A skill that loses its session_scope is unlinked on the next run.
mk_skill zz-fixture-proj
run >/dev/null
[[ ! -e "$SKILLS_DIR/zz-fixture-proj" ]] \
    && pass "a skill that drops session_scope is unlinked on re-install" \
    || fail "a de-scoped skill kept its symlink"

# --------------------------------------------------------------- safety ---
# A skill directory the user owns is never replaced.
mkdir -p "$SKILLS_DIR/zz-fixture-both-real"
mk_skill zz-fixture-both-real both
out="$(run)"
[[ "$out" == *"not ours to replace"* && -d "$SKILLS_DIR/zz-fixture-both-real" && ! -L "$SKILLS_DIR/zz-fixture-both-real" ]] \
    && pass "an existing non-symlink skill directory is left alone" \
    || fail "the installer overwrote a user-owned skill directory"
rm -rf "$SKILLS_DIR/zz-fixture-both-real"

# ----------------------------------------------------------- uninstall ---
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 0 ]] && pass "uninstall exits 0" || fail "uninstall failed (rc=$rc out=$out)"
[[ ! -e "$ROOT_FILE" ]] && pass "uninstall removes agent-workspace-root" || fail "root file survived uninstall"
[[ ! -e "$HOOK_LINK" ]] && pass "uninstall removes the SessionStart symlink" || fail "hook symlink survived uninstall"
[[ -z "$(jq -r --arg t "$WSC" '[.hooks // {} | to_entries[] | .value[] | select((._agent_workspace // "") == $t)] | .[]' "$SETTINGS")" ]] \
    && pass "uninstall removes our tagged hook entries" || fail "tagged hook entries survived uninstall"
jq -e '[.hooks.PreToolUse[]?.hooks[]?.command] | index("/opt/mine.sh") != null' "$SETTINGS" >/dev/null \
    && pass "uninstall leaves the user's own hook entry alone" \
    || fail "uninstall removed the user's own hook entry"
jq -e '[.permissions.allow[]] | index("Bash(mine *)") != null' "$SETTINGS" >/dev/null \
    && pass "uninstall leaves the user's own permission rule alone" \
    || fail "uninstall removed the user's own permission rule"

out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"not installed"* ]] \
    && pass "--check after uninstall: back to the not-installed note" \
    || fail "--check after uninstall (rc=$rc out=$out)"

echo ""
echo "test_user_tier_install: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
