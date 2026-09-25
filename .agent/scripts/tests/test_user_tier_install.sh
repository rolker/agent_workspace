#!/usr/bin/env bash
# .agent/scripts/tests/test_user_tier_install.sh
# Tests for .agent/scripts/user_tier_install.sh (#317, #265 PR 3; #345):
# idempotent install, the not-installed / --require split, drift detection
# (foreign entry, missing entry, stale symlink, retired hook entry, legacy
# skill symlink), skill selection from session_scope frontmatter, the
# plugin manifest generator, per-registered-root plugin enable / --check /
# --uninstall (ADR-0017), and uninstall.
#
# Hermetic: HOME is redirected to a sandbox for every invocation, so the
# real ~/.claude is never read or written. The installer is run against a
# COPY of the workspace checkout -- with the machine's own registry
# (.agent/projects.local) removed from the copy -- so the test can add and
# remove skills and registered roots without touching the real ones. The
# claude CLI is NEVER run: every invocation points AGENT_WORKSPACE_CLAUDE_BIN
# at a stub that records its argv and edits the root's settings.local.json
# the way the real CLI does, and a `claude` on the test's PATH is the same
# stub. No network, no gh.
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
cp -r "$WS_ROOT/.claude-plugin" "$WSC/.claude-plugin"
# The machine's own registry must never reach the copy: the installer would
# otherwise enable the plugin in the owner's real project roots.
rm -f "$WSC/.agent/projects.local"
INSTALL="$WSC/.agent/scripts/user_tier_install.sh"

HOMEDIR="$SANDBOX/home"
mkdir -p "$HOMEDIR"

# The claude stub. Records "<cwd>|<argv>" per call, then edits the cwd's
# .claude/settings.local.json as `claude plugin ... --scope local` would.
# STUB_FAIL=1 makes it exit 1; STUB_NOOP=1 makes it exit 0 having written
# nothing (a CLI that claims success but did not enable anything).
STUB_BIN="$SANDBOX/bin"
STUB="$STUB_BIN/claude"
STUB_LOG="$SANDBOX/claude-stub.log"
mkdir -p "$STUB_BIN"
cat > "$STUB" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s|%s\n' "$PWD" "$*" >> "$STUB_LOG"
[[ -n "${STUB_FAIL:-}" ]] && exit 1
[[ -n "${STUB_NOOP:-}" ]] && exit 0
f=.claude/settings.local.json
mkdir -p .claude
[[ -f "$f" ]] || echo '{}' > "$f"
case "$1 $2 ${3:-}" in
    "plugin marketplace add")    filter='.extraKnownMarketplaces["agent-workspace"] = {source: {source: "directory", path: $a}}'; arg="$4" ;;
    "plugin marketplace remove") filter='del(.extraKnownMarketplaces["agent-workspace"])'; arg="" ;;
    "plugin install "*)          filter='.enabledPlugins[$a] = true'; arg="$3" ;;
    "plugin uninstall "*)        filter='del(.enabledPlugins[$a])'; arg="$3" ;;
    *) exit 0 ;;
esac
jq --arg a "$arg" "$filter" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
STUBEOF
chmod +x "$STUB"
: > "$STUB_LOG"

run() {  # run the installer with the sandbox HOME and the claude stub
    HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" \
        AGENT_WORKSPACE_CLAUDE_BIN="$STUB" bash "$INSTALL" "$@" 2>&1
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

if jq -e --arg c "$WSC/.claude/hooks/log-tool-use.sh" \
    '[.hooks.PreToolUse[].hooks[]?.command] | index($c) != null' "$SETTINGS" >/dev/null; then
    pass "PreToolUse entry written by absolute path: log-tool-use.sh"
else
    fail "no absolute-path PreToolUse entry for log-tool-use.sh"
fi

# Exactly that one: a hook retired from the user tier (the tool-mapping
# hook, #328) must not be written by a fresh install.
jq -e --arg t "$WSC" --arg c "$WSC/.claude/hooks/log-tool-use.sh" '
    [.hooks.PreToolUse[] | select((._agent_workspace // "") == $t) | .hooks[]?.command] == [$c]
' "$SETTINGS" >/dev/null \
    && pass "the tagged PreToolUse entry carries log-tool-use.sh and nothing else" \
    || fail "the tagged PreToolUse entry carries more than log-tool-use.sh ($(jq -c '[.hooks.PreToolUse[].hooks[]?.command]' "$SETTINGS"))"

jq -e --arg t "$WSC" '[.hooks | to_entries[] | .value[] | ._agent_workspace] | all(. == $t)' \
    "$SETTINGS" >/dev/null \
    && pass "every hook entry is tagged with this checkout" || fail "hook entries are not all tagged"

jq -e --arg c "$WSC/.agent/scripts/worktree_create.sh" \
    '[.permissions.allow[]] | index("Bash(" + $c + ":*)") != null' "$SETTINGS" >/dev/null \
    && pass "absolute-path allow-rule generated from the manifest" \
    || fail "no allow-rule for a manifest script"

# ADR-0017: skills are no longer delivered as ~/.claude/skills/ symlinks.
n_links=$(find "$SKILLS_DIR" -maxdepth 1 -type l 2>/dev/null | wc -l)
[[ "$n_links" -eq 0 ]] \
    && pass "install creates no ~/.claude/skills/ symlinks (the plugin delivers skills)" \
    || fail "install created $n_links skill symlink(s)"
[[ ! -s "$STUB_LOG" ]] \
    && pass "with no registered roots, install never runs the claude CLI" \
    || fail "install ran the claude CLI with no registered roots ($(cat "$STUB_LOG"))"

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

# (e) a legacy skill symlink into this checkout (pre-ADR-0017 delivery),
# including a dangling one whose skill was since deleted
mkdir -p "$SKILLS_DIR"
ln -s "$WSC/.claude/skills/zz-fixture-proj" "$SKILLS_DIR/zz-fixture-proj"
ln -s "$WSC/.claude/skills/zz-since-deleted" "$SKILLS_DIR/zz-since-deleted"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"legacy skill symlink"*"zz-fixture-proj"* && "$out" == *"legacy skill symlink"*"zz-since-deleted"* ]] \
    && pass "--check reports legacy skill symlinks into this checkout, dangling included" \
    || fail "legacy-symlink drift not detected (rc=$rc out=$out)"
out="$(run)"
[[ ! -e "$SKILLS_DIR/zz-fixture-proj" && ! -L "$SKILLS_DIR/zz-fixture-proj" && ! -L "$SKILLS_DIR/zz-since-deleted" \
   && "$out" == *"removed legacy skill symlink: zz-fixture-proj"* ]] \
    && pass "install removes legacy skill symlinks" \
    || fail "install left a legacy skill symlink (out=${out:0:300})"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 ]] && pass "--check is clean once the legacy symlinks are gone" \
    || fail "--check after legacy removal (rc=$rc out=$out)"

# (f) a tagged, in-checkout hook entry the current generation no longer
# produces -- a hook retired from the user tier (#328). Tagged with this
# checkout and pointing inside it, so (a)-(c) do not fire for it.
RETIRED_HOOK="$WSC/.claude/hooks/zz-retired-hook.sh"
jq --arg t "$WSC" --arg c "$RETIRED_HOOK" '
    .hooks.PreToolUse |= map(if (._agent_workspace // "") == $t
                             then .hooks += [{type: "command", command: $c, timeout: 5}]
                             else . end)' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"no longer generated: $RETIRED_HOOK"* ]] \
    && pass "--check detects a tagged hook entry the current generation no longer produces" \
    || fail "retired-hook drift not detected (rc=$rc out=$out)"
run >/dev/null
jq -e --arg c "$RETIRED_HOOK" '[.hooks.PreToolUse[].hooks[]?.command] | index($c) == null' \
    "$SETTINGS" >/dev/null \
    && pass "re-install drops the retired hook entry" \
    || fail "re-install left the retired hook entry in settings.json"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean after the re-install clears the retired entry" \
    || fail "--check after clearing the retired entry (rc=$rc out=$out)"

# --------------------------------------------------------------- safety ---
# A skill directory the user owns is never replaced.
mkdir -p "$SKILLS_DIR/zz-fixture-both-real"
mk_skill zz-fixture-both-real both
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && -d "$SKILLS_DIR/zz-fixture-both-real" && ! -L "$SKILLS_DIR/zz-fixture-both-real" ]] \
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

# ------------------------------------------- malformed settings.json ---
# Round 1 must-fix: read_settings used `jq . || echo {}`, so an unparseable
# settings.json was treated as empty and REPLACED -- every user key gone,
# exit 0, no backup. It must now refuse, untouched, in every writing mode,
# and --check must report it as its own state rather than as drift.
run >/dev/null   # start from a clean install
printf '{ "model": "opus", "permissions": { "allow": ["Bash(mine *)"] }' > "$SETTINGS"   # truncated: invalid
malformed_before="$(cat "$SETTINGS")"

out="$(run)"; rc=$?
[[ "$rc" -ne 0 && "$out" == *"not valid JSON"* ]] \
    && pass "install refuses an unparseable settings.json" \
    || fail "install did not refuse unparseable settings (rc=$rc out=${out:0:160})"
[[ "$(cat "$SETTINGS")" == "$malformed_before" ]] \
    && pass "the unparseable settings.json is left byte-for-byte untouched by install" \
    || fail "install rewrote the unparseable settings.json"

out="$(run --uninstall)"; rc=$?
[[ "$rc" -ne 0 && "$out" == *"not valid JSON"* ]] \
    && pass "uninstall refuses an unparseable settings.json" \
    || fail "uninstall did not refuse (rc=$rc out=${out:0:160})"
[[ "$(cat "$SETTINGS")" == "$malformed_before" ]] \
    && pass "the unparseable settings.json is left untouched by uninstall" \
    || fail "uninstall rewrote the unparseable settings.json"

out="$(run --check)"; rc=$?
[[ "$rc" -ne 0 && "$out" == *"not valid JSON"* && "$out" != *"DRIFT"* ]] \
    && pass "--check reports unparseable settings as its own state, not drift" \
    || fail "--check on unparseable settings (rc=$rc out=${out:0:200})"

rm -f "$SETTINGS"
run >/dev/null

# ------------------------------------------------- backup before rewrite ---
rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*
out="$(run)"
ls "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.* >/dev/null 2>&1 \
    && pass "a timestamped backup is written before the rewrite" \
    || fail "no backup written (out=${out:0:160})"
rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*

# --------------------------------------------- a second workspace checkout ---
# Round 1 must-fix: the root file was overwritten unconditionally, and the
# losing checkout's --check then said "not installed (optional)" and exited 0.
WSC2="$SANDBOX/ws2"
mkdir -p "$WSC2"
cp -r "$WS_ROOT/.agent" "$WSC2/.agent"
cp -r "$WS_ROOT/.claude" "$WSC2/.claude"
run2() { HOME="$HOMEDIR" bash "$WSC2/.agent/scripts/user_tier_install.sh" "$@" 2>&1; }

out="$(run2)"; rc=$?
[[ "$rc" -ne 0 && "$out" == *"already installed for a different workspace checkout"* && "$out" == *"$WSC"* ]] \
    && pass "a second checkout refuses to take the user tier over, naming both paths" \
    || fail "second checkout did not refuse (rc=$rc out=${out:0:200})"
[[ "$(cat "$ROOT_FILE")" == "$WSC" ]] \
    && pass "the root file still points at the first checkout" \
    || fail "the root file was repointed despite the refusal"

out="$(run2 --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"installed for a different checkout"* && "$out" == *"$WSC"* ]] \
    && pass "--check from the second checkout reports the foreign owner and exits 1" \
    || fail "--check from a second checkout (rc=$rc out=${out:0:200})"

out="$(run2 --check --require)"; rc=$?
[[ "$rc" -eq 1 ]] \
    && pass "--check --require from the second checkout also exits 1" \
    || fail "--check --require from a second checkout (rc=$rc)"

out="$(run2 --force)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"taking the user tier over"* && "$(cat "$ROOT_FILE")" == "$WSC2" ]] \
    && pass "--force takes the user tier over and says so" \
    || fail "--force did not take over (rc=$rc out=${out:0:200})"

# A user-owned, untagged hook entry to prove the takeover stays surgical
# (the earlier fixture was dropped when the malformed-settings case rebuilt
# settings.json from scratch).
jq '.hooks.PreToolUse += [{hooks: [{type: "command", command: "/opt/mine.sh"}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
run2 --force >/dev/null

# Round 2 must-fix: --force is the remedy the refusal message prescribes, so
# it has to leave a COMPLETE takeover, not a half one that exits 0 claiming
# success. Previously the install jq pruned only entries tagged with the
# incoming checkout, and sync_skills treated a link into another checkout as
# "not ours to replace" -- so settings.json kept two SessionStart entries
# (both layers injected every session) plus the old checkout's PreToolUse
# entries, and every skill symlink still pointed into the old checkout: the
# root file moved but the skills did not.
n_session=$(jq '.hooks.SessionStart | length' "$SETTINGS")
[[ "$n_session" -eq 1 ]] \
    && pass "--force leaves exactly one SessionStart entry" \
    || fail "--force left $n_session SessionStart entries (both layers would inject)"

leftover=$(jq -r --arg old "$WSC" '
    [.hooks // {} | to_entries[] | .value[]
     | select((._agent_workspace // "") == $old)] | length' "$SETTINGS")
[[ "$leftover" -eq 0 ]] \
    && pass "--force removes every hook entry tagged with the old checkout" \
    || fail "--force left $leftover entry/entries tagged $WSC"

stale_cmds=$(jq -r --arg oldp "$WSC/" '
    [.hooks // {} | to_entries[] | .value[] | .hooks[]? | .command
     | select(startswith($oldp))] | length' "$SETTINGS")
[[ "$stale_cmds" -eq 0 ]] \
    && pass "--force leaves no hook command pointing into the old checkout" \
    || fail "--force left $stale_cmds hook command(s) pointing into $WSC"

n_links=$(find "$SKILLS_DIR" -maxdepth 1 -type l 2>/dev/null | wc -l)
[[ "$n_links" -eq 0 ]] \
    && pass "--force leaves no skill symlink into either checkout" \
    || fail "--force left $n_links skill symlink(s)"

out="$(run2 --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean immediately after --force (the takeover is complete)" \
    || fail "--check after --force still reports drift (rc=$rc out=${out:0:300})"

# The user's own untagged entry must survive even a --force takeover.
jq -e '[.hooks.PreToolUse[]?.hooks[]?.command] | index("/opt/mine.sh") != null' "$SETTINGS" >/dev/null \
    && pass "--force leaves the user's own untagged hook entry alone" \
    || fail "--force removed the user's own hook entry"

# A legacy link into the OTHER checkout (the one now owning the tier is
# WSC2; WSC is "another checkout" from its side): --check from WSC2 reports
# it, and install from WSC2 removes it -- the mechanism is retired
# everywhere, so there is nothing to preserve it for.
mkdir -p "$SKILLS_DIR"
ln -s "$WSC/.claude/skills/zz-fixture-proj" "$SKILLS_DIR/zz-fixture-proj"
out="$(run2 --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"legacy skill symlink"*"$WSC/.claude/skills/zz-fixture-proj"* ]] \
    && pass "--check reports a legacy skill symlink into ANOTHER checkout" \
    || fail "foreign legacy symlink not reported (rc=$rc out=${out:0:300})"
run2 >/dev/null
[[ ! -L "$SKILLS_DIR/zz-fixture-proj" ]] \
    && pass "install removes a legacy skill symlink into another checkout" \
    || fail "install left a legacy symlink into another checkout"
# ...but uninstall only removes links into its own checkout.
ln -s "$WSC/.claude/skills/zz-fixture-proj" "$SKILLS_DIR/zz-fixture-proj"
run2 --uninstall >/dev/null
[[ -L "$SKILLS_DIR/zz-fixture-proj" ]] \
    && pass "uninstall leaves another checkout's legacy symlink for that checkout" \
    || fail "uninstall removed another checkout's legacy symlink"
rm -f "$SKILLS_DIR/zz-fixture-proj"
run2 >/dev/null

# hand it back so the remaining cases run against the original checkout
run --force >/dev/null

# ------------------------------------------------------ flag validation ---
out="$(run --uninstall --check)"; rc=$?
[[ "$rc" -eq 2 && "$out" == *"mutually exclusive"* ]] \
    && pass "--uninstall --check is rejected rather than silently running one" \
    || fail "mode combination not validated (rc=$rc out=${out:0:160})"

out="$(run --require)"; rc=$?
[[ "$rc" -eq 2 && "$out" == *"only meaningful with --check"* ]] \
    && pass "--require without --check is rejected rather than ignored" \
    || fail "--require alone not validated (rc=$rc out=${out:0:160})"

# ------------------------------------------ settings.json as a symlink ---
# A dotfiles-managed settings.json must be written THROUGH, not replaced.
real="$SANDBOX/dotfiles-settings.json"
mv "$SETTINGS" "$real"
ln -s "$real" "$SETTINGS"
run >/dev/null
[[ -L "$SETTINGS" ]] \
    && pass "a symlinked settings.json is still a symlink after install" \
    || fail "install replaced the symlinked settings.json with a regular file"
jq -e '.hooks.SessionStart | length > 0' "$real" >/dev/null \
    && pass "the install was written through the symlink into the real file" \
    || fail "the symlink target did not receive the install"
rm -f "$SETTINGS"; mv "$real" "$SETTINGS"

# ------------------------------------ rules from an earlier generation ---
# Round 1 suggestion: uninstall matched the CURRENT manifest only, so a rule
# written by an earlier generation -- a script since dropped or renamed --
# stayed in settings.json with nothing able to name it.
run >/dev/null
RULES_FILE="$HOMEDIR/.claude/agent-workspace-rules.json"
[[ -f "$RULES_FILE" ]] && jq -e 'length > 0' "$RULES_FILE" >/dev/null \
    && pass "install records the generated allow-rules it wrote" \
    || fail "no recorded rules sidecar at $RULES_FILE"

# Simulate a manifest that has since lost an entry: the rule is in
# settings.json and in the recorded generation, but not in the manifest.
GONE_RULE="Bash($WSC/.agent/scripts/since_removed.sh:*)"
# A user-owned rule alongside it: the earlier fixture was dropped when the
# malformed-settings case rebuilt settings.json from scratch, and the point
# of this case is that orphan cleanup stays surgical.
jq --arg r "$GONE_RULE" '.permissions.allow += [$r, "Bash(mine *)"]' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
jq --arg r "$GONE_RULE" '. + [$r]' "$RULES_FILE" > "$tmp" && mv "$tmp" "$RULES_FILE"

out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"no longer in the manifest"* ]] \
    && pass "--check reports allow-rules left over from an earlier generation" \
    || fail "orphan rule not reported (rc=$rc out=${out:0:200})"

out="$(run --uninstall)"
if jq -e --arg r "$GONE_RULE" '[.permissions.allow[]] | index($r) == null' "$SETTINGS" >/dev/null; then
    pass "uninstall clears a rule from an earlier generation, not just the current manifest"
else
    fail "uninstall left the earlier generation's rule behind"
fi
jq -e '[.permissions.allow[]] | index("Bash(mine *)") != null' "$SETTINGS" >/dev/null \
    && pass "...while still leaving the user's own rule alone" \
    || fail "uninstall removed the user's own rule while clearing orphans"
[[ ! -f "$RULES_FILE" ]] \
    && pass "uninstall removes the recorded-rules sidecar" \
    || fail "the rules sidecar survived uninstall"

# ------------------------------------------------- backup rotation ---
# Round 2 suggestion: backups accumulated unbounded, and two runs in the same
# second collided on the same filename.
rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*
for _ in 1 2 3 4 5 6 7; do run >/dev/null; done
n_backups=$(ls -1 "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.* 2>/dev/null | wc -l)
[[ "$n_backups" -eq 5 ]] \
    && pass "seven back-to-back installs leave exactly 5 backups (rotation, no same-second collision)" \
    || fail "expected 5 backups after 7 installs, found $n_backups"

# --------------------------------- foreign_skill_link(): negative case ---
# Install removes a legacy skill symlink into ANOTHER agent_workspace
# checkout, recognised by the .agent/user_tier_scripts.txt three levels up.
# The other side of that probe: a link the USER made, into a directory that
# is not a checkout, must survive install --force untouched, and --check
# must not report it. Without this, loosening the probe would go unnoticed.
mk_skill zz-fixture-userlink project
run >/dev/null   # make sure the skill set is current for this checkout

USERDIR="$SANDBOX/my-own-skills/zz-fixture-userlink"
mkdir -p "$USERDIR"
printf -- '---\nname: zz-fixture-userlink\ndescription: the user own copy\n---\n' \
    > "$USERDIR/SKILL.md"
# Three levels up from the link target is $SANDBOX, which has no
# .agent/user_tier_scripts.txt -- so this is not a checkout.
[[ ! -f "$SANDBOX/.agent/user_tier_scripts.txt" ]] \
    && pass "the fixture's grandparent is deliberately not a workspace checkout" \
    || fail "fixture setup wrong: $SANDBOX looks like a checkout"

rm -rf "$SKILLS_DIR/zz-fixture-userlink"
ln -s "$USERDIR" "$SKILLS_DIR/zz-fixture-userlink"

out="$(run --force)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "install --force exited $rc (out=${out:0:160})"
[[ -L "$SKILLS_DIR/zz-fixture-userlink" \
   && "$(readlink "$SKILLS_DIR/zz-fixture-userlink")" == "$USERDIR" ]] \
    && pass "--force leaves a user symlink into a non-checkout directory untouched" \
    || fail "--force removed or repointed a user symlink (now: $(readlink "$SKILLS_DIR/zz-fixture-userlink" 2>/dev/null))"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" != *"zz-fixture-userlink"* ]] \
    && pass "--check does not report the user's own skill symlink" \
    || fail "--check reported the user's own symlink (rc=$rc out=${out:0:300})"

rm -f "$SKILLS_DIR/zz-fixture-userlink"
rm -rf "$WSC/.claude/skills/zz-fixture-userlink"
run >/dev/null

# ------------------------- settings.json symlinked into a dotfiles repo ---
# Round 3: the symlinked-settings write path (readlink -f, stage beside the
# real file, atomic mv) had no test of its own. A regression here silently
# detaches someone's dotfiles or leaves a truncated settings.json.
DOTFILES="$SANDBOX/dotfiles"
mkdir -p "$DOTFILES"
mv "$SETTINGS" "$DOTFILES/claude-settings.json"
ln -s "$DOTFILES/claude-settings.json" "$SETTINGS"
link_target_before="$(readlink "$SETTINGS")"
# The inode of the REAL file. A rename onto it (atomic) allocates a new
# inode; a `cat > "$SETTINGS"` truncates the existing one in place and keeps
# it. This is the assertion that actually distinguishes the two, and the
# reason the write path was changed: truncate-in-place leaves a half-written
# settings.json if the write is interrupted.
inode_before="$(stat -c %i "$DOTFILES/claude-settings.json")"

out="$(run)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "install over a symlinked settings.json exited $rc (out=${out:0:200})"

[[ -L "$SETTINGS" ]] \
    && pass "settings.json is still a symlink after install" \
    || fail "install replaced the settings.json symlink with a regular file"
[[ "$(readlink "$SETTINGS")" == "$link_target_before" ]] \
    && pass "the symlink still points at the same dotfiles path" \
    || fail "the symlink was repointed ($(readlink "$SETTINGS") != $link_target_before)"

jq -e --arg t "$WSC" '
    [.hooks // {} | to_entries[] | .value[] | select((._agent_workspace // "") == $t)] | length > 0
' "$DOTFILES/claude-settings.json" >/dev/null \
    && pass "the dotfiles file itself received the marker entries" \
    || fail "the install did not reach the symlink's target file"

inode_after="$(stat -c %i "$DOTFILES/claude-settings.json")"
[[ "$inode_before" != "$inode_after" ]] \
    && pass "the real file was replaced by a rename, not truncated in place" \
    || fail "the dotfiles file kept inode $inode_before -- it was truncated in place, not renamed onto"

# The staging file is named beside the real file; nothing may be left behind
# there or in ~/.claude.
strays=()
for f in "$DOTFILES"/* "$DOTFILES"/.*; do
    [[ -e "$f" ]] || continue
    case "$(basename "$f")" in
        claude-settings.json|.|..) continue ;;
        *) strays+=("$(basename "$f")") ;;
    esac
done
[[ "${#strays[@]}" -eq 0 ]] \
    && pass "no stray staging file left beside the dotfiles settings" \
    || fail "${#strays[@]} stray file(s) left in $DOTFILES: ${strays[*]}"

tmp_strays=()
for f in "$HOMEDIR/.claude"/.settings.json.*; do
    [[ -e "$f" ]] && tmp_strays+=("$(basename "$f")")
done
[[ "${#tmp_strays[@]}" -eq 0 ]] \
    && pass "no stray mktemp settings file left in ~/.claude" \
    || fail "${#tmp_strays[@]} stray temp file(s) left in $HOMEDIR/.claude: ${tmp_strays[*]}"

# And it is still valid JSON that --check accepts.
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean with settings.json symlinked into dotfiles" \
    || fail "--check over a symlinked settings.json (rc=$rc out=${out:0:200})"

rm -f "$SETTINGS"
mv "$DOTFILES/claude-settings.json" "$SETTINGS"

# ------------------------------------------- plugin manifest generator ---
# --generate-plugin-manifest rewrites only the `skills` array, from the same
# session_scope selection --list-skills prints, and keeps the tracked file's
# mode (mktemp's 0600 must not leak onto it).
chmod 644 "$WSC/.claude-plugin/plugin.json"
out="$(run --generate-plugin-manifest)"; rc=$?
want="$(run --list-skills | sed 's|^|./.claude/skills/|' | jq -R . | jq -sc .)"
got="$(jq -c '.skills' "$WSC/.claude-plugin/plugin.json")"
[[ "$rc" -eq 0 && "$got" == "$want" ]] \
    && pass "--generate-plugin-manifest writes exactly the session_scope project|both skills" \
    || fail "generated skills array differs (rc=$rc got=$got want=$want out=$out)"
[[ "$got" == *"zz-fixture-proj"* && "$got" != *"zz-fixture-ws"* ]] \
    && pass "the generated array includes a project skill and excludes a workspace one" \
    || fail "generated array selection is wrong ($got)"
[[ "$(jq -r .name "$WSC/.claude-plugin/plugin.json")" == "agent-workspace" ]] \
    && pass "the generator leaves the manifest's other keys alone" \
    || fail "the generator changed the manifest name"
[[ "$(stat -c %a "$WSC/.claude-plugin/plugin.json")" == 644 ]] \
    && pass "the generator keeps the manifest's file mode" \
    || fail "the generator changed the manifest mode to $(stat -c %a "$WSC/.claude-plugin/plugin.json")"
if ls "$WSC/.claude-plugin/"plugin.json.* >/dev/null 2>&1; then
    fail "the generator left a temp file beside the manifest"
else
    pass "the generator leaves no temp file behind"
fi

# ------------------------------------------- plugin, per registered root ---
# ADR-0017. A sandboxed registry with one root of every verdict: a git repo
# (enable), a directory in no git repo (enable), a root inside the
# workspace copy's own git tree (skip -- it sees the bare skills), the same
# reached through a symlinked path (still skip: pwd -P on both sides), a
# parent root with an instance (parent enabled, instance skipped), and a
# root not on disk (a note). The claude stub stands in for the CLI.
ROOTS="$SANDBOX/roots"
mkdir -p "$ROOTS/a" "$ROOTS/nogit" "$ROOTS/fam/inst"
git -C "$ROOTS/a" init -q
git -C "$WSC" init -q
mkdir -p "$WSC/projects/inner" "$WSC/projects/inner2"
ln -s "$WSC" "$SANDBOX/ws-link"
NOGIT_REAL=true
git -C "$ROOTS/nogit" rev-parse --show-toplevel >/dev/null 2>&1 && NOGIT_REAL=false
cat > "$WSC/.agent/projects.local" <<REG
a        single_project  $ROOTS/a
nogit    single_project  $ROOTS/nogit
inner    single_project  $WSC/projects/inner
inner2   single_project  $SANDBOX/ws-link/projects/inner2
fam      project         $ROOTS/fam
fam-i    single_project  $ROOTS/fam/inst  parent=fam
gone     single_project  $ROOTS/gone
REG
WSC_PHYS="$(cd "$WSC" && pwd -P)"
SLJ=.claude/settings.local.json
enabled_in() {  # <root>: the plugin enabled from this checkout there?
    jq -e --arg p "$WSC_PHYS" '.enabledPlugins["agent-workspace@agent-workspace"] == true
        and .extraKnownMarketplaces["agent-workspace"].source.path == $p' "$1/$SLJ" >/dev/null 2>&1
}
stale_enable() {  # <root>: write an enable from this checkout by hand
    mkdir -p "$1/.claude"
    jq -n --arg p "$WSC_PHYS" '{enabledPlugins: {"agent-workspace@agent-workspace": true},
        extraKnownMarketplaces: {"agent-workspace": {source: {source: "directory", path: $p}}}}' \
        > "$1/$SLJ"
}

: > "$STUB_LOG"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 ]] && pass "install with registered roots exits 0" \
    || fail "install with registered roots failed (rc=$rc out=${out:0:400})"
enabled_in "$ROOTS/a" \
    && pass "the plugin is enabled in a registered git root" \
    || fail "the plugin is not enabled in root a ($(cat "$ROOTS/a/$SLJ" 2>/dev/null))"
grep -qxF "$ROOTS/a|plugin marketplace add $WSC_PHYS --scope local" "$STUB_LOG" \
   && grep -qxF "$ROOTS/a|plugin install agent-workspace@agent-workspace --scope local" "$STUB_LOG" \
    && pass "enabling runs marketplace add (physical checkout path) and install, local scope, from the root" \
    || fail "unexpected CLI calls for root a ($(cat "$STUB_LOG"))"
if [[ "$NOGIT_REAL" == true ]]; then
    enabled_in "$ROOTS/nogit" \
        && pass "a root in no git repository is enabled, not skipped" \
        || fail "the no-git root was not enabled"
else
    echo "  SKIP: the sandbox sits inside a git repository; the no-git case cannot be set up here"
fi
[[ ! -e "$WSC/projects/inner/$SLJ" && "$out" == *"skipped inner: its git toplevel is this workspace checkout"* ]] \
    && pass "a root inside the workspace checkout's git tree is skipped" \
    || fail "the workspace-toplevel root was not skipped (out=${out:0:400})"
[[ ! -e "$WSC/projects/inner2/$SLJ" && "$out" == *"skipped inner2"* ]] \
    && pass "the same root reached through a symlinked path is still skipped (pwd -P)" \
    || fail "the symlinked workspace-toplevel root was not skipped"
enabled_in "$ROOTS/fam" && [[ ! -e "$ROOTS/fam/inst/$SLJ" && "$out" == *"skipped fam-i: a parent= instance"* ]] \
    && pass "a parent root is enabled and its parent= instance is skipped" \
    || fail "parent/instance handling is wrong (out=${out:0:400})"
[[ "$out" == *"registered root gone is not on disk"* ]] \
    && pass "a registered root not on disk is a note, not a failure" \
    || fail "missing root not noted (out=${out:0:400})"
if grep -q "^$WSC" "$STUB_LOG"; then
    fail "the CLI ran inside the workspace tree ($(grep "^$WSC" "$STUB_LOG"))"
else
    pass "the CLI is never run inside the workspace checkout's tree"
fi

out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean with the plugin enabled in every session root" \
    || fail "--check after plugin install (rc=$rc out=${out:0:400})"

: > "$STUB_LOG"
run >/dev/null
[[ ! -s "$STUB_LOG" ]] \
    && pass "re-install over enabled roots is a no-op for the CLI (idempotent)" \
    || fail "re-install ran the CLI again ($(cat "$STUB_LOG"))"

# --check reads JSON only: it must never run the CLI.
: > "$STUB_LOG"
rm -f "${ROOTS:?}/a/.claude/settings.local.json"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"plugin not enabled from this checkout in registered root a"* ]] \
    && pass "--check reports a registered root without the plugin" \
    || fail "missing-plugin drift not detected (rc=$rc out=${out:0:400})"
[[ ! -s "$STUB_LOG" ]] \
    && pass "--check never runs the claude CLI" \
    || fail "--check ran the CLI ($(cat "$STUB_LOG"))"
run >/dev/null
enabled_in "$ROOTS/a" && pass "re-install re-enables the plugin in that root" \
    || fail "re-install did not re-enable root a"

# A stale enable in a skipped (workspace-toplevel) root.
stale_enable "$WSC/projects/inner"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"enabled in inner"*"loads twice"* ]] \
    && pass "--check flags a stale plugin enable in a workspace-toplevel root" \
    || fail "stale enable in a skipped root not flagged (rc=$rc out=${out:0:400})"
run >/dev/null
out="$(run --check)"; rc=$?
if [[ "$rc" -eq 0 ]] && ! enabled_in "$WSC/projects/inner"; then
    pass "install removes the stale enable from the skipped root"
else
    fail "the stale enable survived install (rc=$rc out=${out:0:400})"
fi

# The plugin enabled at the workspace checkout itself.
stale_enable "$WSC"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"enabled in the workspace checkout itself"* ]] \
    && pass "--check flags the plugin enabled at the workspace checkout itself" \
    || fail "workspace-root enable not flagged (rc=$rc out=${out:0:400})"
run >/dev/null
out="$(run --check)"; rc=$?
if [[ "$rc" -eq 0 ]] && ! enabled_in "$WSC"; then
    pass "install removes the plugin from the workspace checkout itself"
else
    fail "the workspace-root enable survived install (rc=$rc out=${out:0:400})"
fi

# A root whose declaration points at ANOTHER checkout: drift, and install
# replaces the marketplace declaration with this checkout.
mkdir -p "$SANDBOX/elsewhere"
jq --arg p "$SANDBOX/elsewhere" '.extraKnownMarketplaces["agent-workspace"].source.path = $p' \
    "$ROOTS/a/$SLJ" > "$ROOTS/a/$SLJ.new" && mv "$ROOTS/a/$SLJ.new" "$ROOTS/a/$SLJ"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"not enabled from this checkout in registered root a"* ]] \
    && pass "--check reports a root whose plugin comes from another checkout" \
    || fail "foreign-source plugin not reported (rc=$rc out=${out:0:400})"
: > "$STUB_LOG"
run >/dev/null
enabled_in "$ROOTS/a" && grep -qxF "$ROOTS/a|plugin marketplace remove agent-workspace --scope local" "$STUB_LOG" \
    && pass "install drops the other checkout's declaration and enables from this one" \
    || fail "install did not repoint root a ($(cat "$STUB_LOG"))"

# An unparseable settings.local.json is refused, never overwritten.
printf '{not json' > "$ROOTS/a/$SLJ"
out="$(run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"not valid JSON -- not enabling"* && "$(cat "$ROOTS/a/$SLJ")" == '{not json' ]] \
    && pass "install refuses a root with an unparseable settings.local.json and leaves it alone" \
    || fail "unparseable settings.local.json handled wrong (rc=$rc out=${out:0:400})"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"settings.local.json is not valid JSON"* ]] \
    && pass "--check reports the unparseable settings.local.json" \
    || fail "--check missed the unparseable file (rc=$rc)"
rm -f "${ROOTS:?}/a/.claude/settings.local.json"

# CLI failure, and a CLI that claims success but enabled nothing.
out="$(STUB_FAIL=1 run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"enabling the agent-workspace plugin in $ROOTS/a failed"* ]] \
    && pass "a failing claude CLI makes install exit 1, naming the root" \
    || fail "CLI failure not surfaced (rc=$rc out=${out:0:400})"
out="$(STUB_NOOP=1 run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"reported success, but"* ]] \
    && pass "a CLI that exits 0 without enabling the plugin is caught" \
    || fail "silent CLI no-op not caught (rc=$rc out=${out:0:400})"
rm -f "${ROOTS:?}/a/.claude/settings.local.json"

# No claude CLI at all (a Codex-only machine): install notes and exits 0;
# --check notes and does not call it drift.
NOCLI_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vxF "$STUB_BIN" | paste -sd:)"
run_nocli() {
    HOME="$HOMEDIR" PATH="$NOCLI_PATH" AGENT_WORKSPACE_CLAUDE_BIN="$SANDBOX/no-such-claude" \
        bash "$INSTALL" "$@" 2>&1
}
out="$(run_nocli)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"claude CLI is not on PATH -- not enabling"* && ! -e "$ROOTS/a/$SLJ" ]] \
    && pass "without the claude CLI, install skips the plugin with a note and exits 0" \
    || fail "no-CLI install (rc=$rc out=${out:0:400})"
out="$(run_nocli --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"the claude CLI is not on PATH"* ]] \
    && pass "without the claude CLI, --check notes the unenabled root and stays green" \
    || fail "no-CLI --check (rc=$rc out=${out:0:400})"
# ...but a plugin that must be REMOVED cannot be without the CLI: install
# over a doubled (workspace-toplevel) root fails, and leaves it as it was.
stale_enable "$WSC/projects/inner"
out="$(run_nocli)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"not on PATH -- cannot remove the agent-workspace plugin from $WSC/projects/inner"* ]] \
   && enabled_in "$WSC/projects/inner" \
    && pass "without the claude CLI, install over a doubled root exits 1 instead of claiming success" \
    || fail "no-CLI install over a doubled root (rc=$rc out=${out:0:400})"
rm -f "${WSC:?}/projects/inner/.claude/settings.local.json"
run >/dev/null
out="$(run_nocli --uninstall)"; rc=$?
if [[ "$rc" -eq 1 && "$out" == *"cannot remove the agent-workspace plugin from $ROOTS/a"* \
      && "$out" != *"removed the agent-workspace plugin from $ROOTS/a"* ]] && enabled_in "$ROOTS/a"; then
    pass "without the claude CLI, --uninstall exits 1 for a root whose plugin it cannot remove"
else
    fail "no-CLI --uninstall (rc=$rc out=${out:0:400})"
fi
run >/dev/null

# --uninstall disables the plugin in every root that has it.
: > "$STUB_LOG"
out="$(run --uninstall)"; rc=$?
if [[ "$rc" -eq 0 ]] && ! enabled_in "$ROOTS/a" && ! enabled_in "$ROOTS/fam" \
   && [[ "$(jq -c '(.enabledPlugins // {} | length) + (.extraKnownMarketplaces // {} | length)' "$ROOTS/a/$SLJ")" == 0 ]]; then
    pass "--uninstall removes the plugin and its marketplace from every enabled root"
else
    fail "--uninstall left the plugin behind (rc=$rc out=${out:0:400})"
fi
[[ "$out" == *"$ROOTS/gone is not on disk"* ]] \
    && pass "--uninstall notes a registered root that is gone, without failing" \
    || fail "--uninstall did not note the missing root (out=${out:0:400})"
if grep -q "^$WSC" "$STUB_LOG"; then
    fail "--uninstall ran the CLI in a skipped workspace-toplevel root"
else
    pass "--uninstall does not run the CLI in the skipped workspace-toplevel roots"
fi

rm -f "${WSC:?}/.agent/projects.local" "${SANDBOX:?}/ws-link"
rm -rf "${WSC:?}/.git" "${WSC:?}/projects"
run >/dev/null

echo ""
echo "test_user_tier_install: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
