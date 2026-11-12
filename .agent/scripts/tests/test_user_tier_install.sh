#!/usr/bin/env bash
# .agent/scripts/tests/test_user_tier_install.sh
# Tests for .agent/scripts/user_tier_install.sh (#317, #265 PR 3; #345):
# idempotent install, the not-installed / --require split, drift detection
# (foreign entry, missing entry, stale symlink, retired hook entry, legacy
# skill symlink, a hook left by a deleted checkout), hook commands
# recognised by path after the claude CLI rewrites settings.json (#394),
# mixed entries, skill selection from session_scope frontmatter, the
# plugin manifest generator, per-registered-root plugin enable / --check /
# --uninstall (ADR-0018), --disable-root <name> (#332), and uninstall.
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
# nothing (a CLI that claims success but did not enable anything);
# STUB_STDIN_LOG=<file> makes it append any line it can read from stdin there
# (a CLI that stops for a prompt would read exactly that). `marketplace add`
# also records its source in ~/.claude/plugins/known_marketplaces.json, the
# CLI's machine-level record keyed by name (left alone when it is not JSON);
# STUB_NO_KM=1 makes it skip that (a CLI that does not repoint the record),
# and STUB_ADD_FAIL=1 makes `marketplace add` alone exit 1 having written
# nothing (a CLI that refuses to repoint a name another source holds), and
# STUB_REMOVE_DROPS_KM=1 makes a local `marketplace remove` also delete the
# machine-level entry (a CLI whose local remove drops the record).
STUB_BIN="$SANDBOX/bin"
STUB="$STUB_BIN/claude"
STUB_LOG="$SANDBOX/claude-stub.log"
mkdir -p "$STUB_BIN"
cat > "$STUB" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s|%s\n' "$PWD" "$*" >> "$STUB_LOG"
if [[ -n "${STUB_STDIN_LOG:-}" ]] && IFS= read -r -t 2 line; then
    printf '%s|%s\n' "$*" "$line" >> "$STUB_STDIN_LOG"
fi
[[ -n "${STUB_ADD_SLEEP:-}" && "$2 ${3:-}" == "marketplace add" ]] && sleep "$STUB_ADD_SLEEP"
[[ -n "${STUB_FAIL:-}" ]] && exit 1
[[ -n "${STUB_ADD_FAIL:-}" && "$2 ${3:-}" == "marketplace add" ]] && exit 1
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
if [[ "$2 $3" == "marketplace remove" && -n "${STUB_REMOVE_DROPS_KM:-}" ]]; then
    km="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/known_marketplaces.json"
    [[ -f "$km" ]] && jq 'del(.["agent-workspace"])' "$km" > "$km.tmp" 2>/dev/null && mv "$km.tmp" "$km"
fi
if [[ "$2 $3" == "marketplace add" && -z "${STUB_NO_KM:-}" ]]; then
    km="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/known_marketplaces.json"
    mkdir -p "$(dirname "$km")"
    [[ -f "$km" ]] || echo '{}' > "$km"
    jq --arg a "$arg" '.["agent-workspace"] = {source: {source: "directory", path: $a}}' "$km" > "$km.tmp" 2>/dev/null \
        && mv "$km.tmp" "$km" || rm -f "$km.tmp"
fi
STUBEOF
chmod +x "$STUB"
: > "$STUB_LOG"

# The installer's own TMPDIR (its machine-level takeover makes a scratch
# directory there), so a test can check that nothing is left behind.
# RUN_TMPDIR=<dir> overrides it for one call.
INST_TMP="$SANDBOX/tmp"
mkdir -p "$INST_TMP"
# CLAUDE_CONFIG_DIR is never inherited from the caller; RUN_CFG=<dir> sets
# it for one call. Like the real CLI (2.1.282), the stub then keeps its
# machine-level record there instead of in ~/.claude. RUN_PATH_PREFIX=<dir>
# puts <dir> first on PATH for one call (a shim for one command).
run() {  # run the installer with the sandbox HOME and the claude stub
    (
        unset CLAUDE_CONFIG_DIR
        [[ -n "${RUN_CFG:-}" ]] && export CLAUDE_CONFIG_DIR="$RUN_CFG"
        HOME="$HOMEDIR" PATH="${RUN_PATH_PREFIX:+$RUN_PATH_PREFIX:}$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" TMPDIR="${RUN_TMPDIR:-$INST_TMP}" \
            AGENT_WORKSPACE_CLAUDE_BIN="$STUB" bash "$INSTALL" "$@" 2>&1
    )
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
jq -e --arg p "$WSC/.claude/hooks/" --arg c "$WSC/.claude/hooks/log-tool-use.sh" '
    [.hooks.PreToolUse[].hooks[]?.command | select(startswith($p))] == [$c]
' "$SETTINGS" >/dev/null \
    && pass "PreToolUse carries log-tool-use.sh and no other hook of this checkout" \
    || fail "PreToolUse carries more than log-tool-use.sh ($(jq -c '[.hooks.PreToolUse[].hooks[]?.command]' "$SETTINGS"))"

# The marker is no longer written: the claude CLI drops it (#394), so
# entries are recognised by command path instead.
jq -e '[.hooks | to_entries[] | .value[] | has("_agent_workspace")] | any | not' \
    "$SETTINGS" >/dev/null \
    && pass "no hook entry carries the _agent_workspace marker" || fail "install wrote the _agent_workspace marker"

jq -e --arg c "$WSC/.agent/scripts/worktree_create.sh" \
    '[.permissions.allow[]] | index("Bash(" + $c + ":*)") != null' "$SETTINGS" >/dev/null \
    && pass "absolute-path allow-rule generated from the manifest" \
    || fail "no allow-rule for a manifest script"

# ADR-0018: skills are no longer delivered as ~/.claude/skills/ symlinks.
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
# (a) a missing hook entry: ours removed by command path
jq --arg p "$WSC/" '.hooks.PreToolUse |= map(select(any(.hooks[]?; .command | startswith($p)) | not))' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
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

# (e) a legacy skill symlink into this checkout (pre-ADR-0018 delivery),
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

# (f) a hook entry marked with this checkout (an earlier generation wrote
# the marker), in-checkout, that the current generation no longer produces
# -- the hook retired from the user tier (#328), by its real name: only the
# names the installer writes or has retired are classified. Marked with
# this checkout and pointing inside it, so (a)-(c) do not fire for it. The
# marker is still read where present.
RETIRED_HOOK="$WSC/.claude/hooks/block-bash-tool-mapping.sh"
jq --arg t "$WSC" --arg c "$RETIRED_HOOK" '
    .hooks.PreToolUse += [{_agent_workspace: $t, hooks: [{type: "command", command: $c, timeout: 5}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"no longer generated: $RETIRED_HOOK"* ]] \
    && pass "--check detects a marked hook entry the current generation no longer produces" \
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

# ------------------------------- the claude CLI rewrites settings.json ---
# #394: every `claude plugin` command rewrites ~/.claude/settings.json,
# dropping keys it does not know (the _agent_workspace marker earlier
# generations wrote) and emitting the keys in its own order. This stub does
# both on every call -- deletes every marker and reverses the key order of
# every object -- and the cases below call it between installer runs.
CLI_REWRITE="$STUB_BIN/claude-rewrite"
cat > "$CLI_REWRITE" <<'REWRITEEOF'
#!/usr/bin/env bash
f="$HOME/.claude/settings.json"
[[ -f "$f" ]] || exit 0
jq 'def rev: if type == "object" then to_entries | reverse | map(.value |= rev) | from_entries
             elif type == "array" then map(rev) else . end;
    walk(if type == "object" then del(._agent_workspace) else . end) | rev' "$f" > "$f.tmp" \
    && cat "$f.tmp" > "$f" && rm -f "$f.tmp"
REWRITEEOF
chmod +x "$CLI_REWRITE"
cli_rewrite() { HOME="$HOMEDIR" "$CLI_REWRITE"; }
n_backups() { ls -1 "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.* 2>/dev/null | wc -l; }
# How many entries of <event> hold <command>.
n_holding() {  # <event> <command>
    jq --arg e "$1" --arg c "$2" '[.hooks[$e][]? | select(any(.hooks[]?; .command == $c))] | length' "$SETTINGS"
}
LOG_HOOK="$WSC/.claude/hooks/log-tool-use.sh"

# (g) as an earlier generation left it (marked), then rewritten by the CLI:
# --check is clean, and a re-install neither duplicates the hooks nor
# rewrites the file (byte-identical, no new backup).
jq --arg t "$WSC" --arg l "$LOG_HOOK" --arg s "$HOOK_LINK" '
    .hooks |= with_entries(.value |= map(
        if any(.hooks[]?; .command == $l or .command == $s) then ._agent_workspace = $t else . end))' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
cli_rewrite
jq -e '[.. | objects | has("_agent_workspace")] | any | not' "$SETTINGS" >/dev/null \
    && pass "the rewriting stub strips every marker (fixture check)" \
    || fail "fixture: the rewriting stub left a marker"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean after the claude CLI strips the markers and reorders the keys" \
    || fail "--check after a CLI rewrite (rc=$rc out=$out)"
cp "$SETTINGS" "$SANDBOX/settings-before.json"
rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*
out="$(run)"; rc=$?
cmp -s "$SETTINGS" "$SANDBOX/settings-before.json" \
    && pass "a re-install after a CLI rewrite leaves settings.json byte-identical" \
    || fail "a re-install after a CLI rewrite changed settings.json (rc=$rc out=${out:0:300})"
[[ "$(n_backups)" -eq 0 ]] \
    && pass "...and writes no backup" || fail "a no-op re-install wrote $(n_backups) backup(s)"
[[ "$(n_holding PreToolUse "$LOG_HOOK")" -eq 1 && "$(n_holding SessionStart "$HOOK_LINK")" -eq 1 ]] \
    && pass "after a CLI rewrite and a re-install, PreToolUse and SessionStart each hold our hook once" \
    || fail "hooks duplicated: PreToolUse $(n_holding PreToolUse "$LOG_HOOK"), SessionStart $(n_holding SessionStart "$HOOK_LINK")"
rm -f "$SANDBOX/settings-before.json"

# (h) the unmarked variant of (f): a retired hook's command under this
# checkout's .claude/hooks/, with no marker at all.
jq --arg c "$RETIRED_HOOK" '.hooks.PreToolUse += [{hooks: [{type: "command", command: $c, timeout: 5}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"no longer generated: $RETIRED_HOOK"* ]] \
    && pass "--check detects an unmarked retired hook command of this checkout" \
    || fail "unmarked retired hook not detected (rc=$rc out=$out)"
run >/dev/null
[[ "$(n_holding PreToolUse "$RETIRED_HOOK")" -eq 0 ]] \
    && pass "install drops the unmarked retired hook command" \
    || fail "install left the unmarked retired hook command"

# Two of the user's own hooks that the rules below must never touch: a dead
# one with a name this installer never wrote, and one named like ours under
# a directory that is not a workspace checkout (no .agent/user_tier_scripts.txt).
USER_DEAD_HOOK="$SANDBOX/gone-dir/.claude/hooks/my-own-hook.sh"
NOT_WS="$SANDBOX/not-a-workspace"
mkdir -p "$NOT_WS/.claude/hooks"
printf '#!/bin/sh\n' > "$NOT_WS/.claude/hooks/log-tool-use.sh"
USER_SAME_NAME="$NOT_WS/.claude/hooks/log-tool-use.sh"
jq --arg a "$USER_DEAD_HOOK" --arg b "$USER_SAME_NAME" '
    .hooks.PreToolUse += [{hooks: [{type: "command", command: $a}]},
                          {hooks: [{type: "command", command: $b}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" != *"$USER_DEAD_HOOK"* && "$out" != *"$NOT_WS"* ]] \
    && pass "--check reports neither a user's own dead hook nor a same-named hook outside any checkout" \
    || fail "--check reported a user's own hook (rc=$rc out=$out)"

# (i) a checkout moved or deleted after the install, the CLI having
# stripped the marker: its PreToolUse command names a path no longer on disk.
# Nothing attributes it to this installer (a drive not mounted looks the
# same), so --check reports it with the remedy, a plain install names it and
# leaves it, and only --force removes it, printing the command and the
# backup path.
DEAD_WS="$SANDBOX/deleted-ws"
mkdir -p "$DEAD_WS/.agent" "$DEAD_WS/.claude/hooks"
: > "$DEAD_WS/.agent/user_tier_scripts.txt"
DEAD_HOOK="$DEAD_WS/.claude/hooks/log-tool-use.sh"
jq --arg c "$DEAD_HOOK" '.hooks.PreToolUse += [{hooks: [{type: "command", command: $c, timeout: 5}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
rm -rf "$DEAD_WS"
FORCE_REMEDY="$WSC/.agent/scripts/user_tier_install.sh --force"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"not on disk"*"$DEAD_HOOK"*"remove it with: $FORCE_REMEDY"* ]] \
    && pass "--check reports an unmarked hook command left by a deleted checkout, naming --force as the remedy" \
    || fail "dead-checkout hook not reported (rc=$rc out=$out)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(n_holding PreToolUse "$DEAD_HOOK")" -eq 1 \
   && "$out" == *"left in place: hook command $DEAD_HOOK"*"remove it with: $FORCE_REMEDY"* ]] \
    && pass "a plain install leaves an unmarked dead hook command in place and names it with the remedy" \
    || fail "a plain install over an unmarked dead hook (rc=$rc held=$(n_holding PreToolUse "$DEAD_HOOK") out=${out:0:600})"
rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*
out="$(run --force)"; rc=$?
dead_backup="$(ls -1 "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.* 2>/dev/null | head -1)"
[[ "$rc" -eq 0 && "$(n_holding PreToolUse "$DEAD_HOOK")" -eq 0 && -n "$dead_backup" \
   && "$out" == *"removed hook command $DEAD_HOOK"* && "$out" == *"kept at $dead_backup"* ]] \
    && pass "--force removes it, printing the command and the backup path" \
    || fail "--force over an unmarked dead hook (rc=$rc held=$(n_holding PreToolUse "$DEAD_HOOK") out=${out:0:600})"
jq -e --arg c "$DEAD_HOOK" '[.hooks.PreToolUse[].hooks[]?.command] | index($c) != null' "$dead_backup" >/dev/null \
    && pass "...and the backup it names still holds the command" \
    || fail "the backup --force named does not hold the removed command"
rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*

# (i2) a dead command in an entry carrying the marker: attributable to this
# installer, so a plain install removes it and says so.
GONE_MARKED="$SANDBOX/gone-marked-ws"
GONE_MARKED_HOOK="$GONE_MARKED/.claude/hooks/log-tool-use.sh"
jq --arg t "$GONE_MARKED" --arg c "$GONE_MARKED_HOOK" '
    .hooks.PreToolUse += [{_agent_workspace: $t, hooks: [{type: "command", command: $c}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"checkout that is not on disk"*"$GONE_MARKED_HOOK (re-run the installer to remove it)"* ]] \
    && pass "--check reports a marked dead hook command, naming a plain install as the remedy" \
    || fail "marked dead hook not reported (rc=$rc out=$out)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(n_holding PreToolUse "$GONE_MARKED_HOOK")" -eq 0 \
   && "$out" == *"removed hook command $GONE_MARKED_HOOK"*"kept at "* ]] \
    && pass "a plain install removes a marked dead hook command and names it" \
    || fail "a plain install over a marked dead hook (rc=$rc held=$(n_holding PreToolUse "$GONE_MARKED_HOOK") out=${out:0:600})"
rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*

# (j) the marked variant: an entry an earlier generation marked with a
# checkout since moved, the CLI not run since. Its directory still exists
# but without the manifest beside it, so the path alone would leave the
# command to the user; the marker attributes it to that checkout.
MOVED_WS="$SANDBOX/moved-ws"
mkdir -p "$MOVED_WS"
MOVED_HOOK="$MOVED_WS/.claude/hooks/log-tool-use.sh"
jq --arg t "$MOVED_WS" --arg c "$MOVED_HOOK" '
    .hooks.PreToolUse += [{_agent_workspace: $t, hooks: [{type: "command", command: $c}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"another workspace checkout: $MOVED_WS"* ]] \
    && pass "--check reports a marked entry of a moved checkout" \
    || fail "marked moved-checkout entry not reported (rc=$rc out=$out)"
run --force >/dev/null
[[ "$(n_holding PreToolUse "$MOVED_HOOK")" -eq 0 ]] \
    && pass "--force removes the marked entry of a moved checkout" \
    || fail "--force left the marked moved-checkout entry"

# (k) another checkout's hook, unmarked: recognised by the
# .agent/user_tier_scripts.txt beside it. --check reports it, a plain
# install leaves it (it is that checkout's), --force removes it.
OTHER_WS="$SANDBOX/other-ws"
mkdir -p "$OTHER_WS/.agent" "$OTHER_WS/.claude/hooks"
: > "$OTHER_WS/.agent/user_tier_scripts.txt"
printf '#!/bin/sh\n' > "$OTHER_WS/.claude/hooks/log-tool-use.sh"
OTHER_HOOK="$OTHER_WS/.claude/hooks/log-tool-use.sh"
jq --arg c "$OTHER_HOOK" '.hooks.PreToolUse += [{hooks: [{type: "command", command: $c, timeout: 5}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"another workspace checkout: $OTHER_WS"* ]] \
    && pass "--check reports an unmarked hook entry of another checkout" \
    || fail "unmarked foreign entry not reported (rc=$rc out=$out)"
run >/dev/null
[[ "$(n_holding PreToolUse "$OTHER_HOOK")" -eq 1 ]] \
    && pass "a plain install leaves another checkout's unmarked hook entry alone" \
    || fail "a plain install removed another checkout's hook entry"

# (l) mixed entries: the user's own command in the same entry as one of
# ours, or of another checkout's (marked or not). Only the installer's
# command goes; the user's stays, in the same entry, with its other keys.
jq --arg l "$LOG_HOOK" --arg o "$OTHER_HOOK" --arg t "$MOVED_WS" --arg m "$MOVED_HOOK" '
    .hooks.PreToolUse += [
        {matcher: "Bash", hooks: [{type: "command", command: $l}, {type: "command", command: "/opt/mine-a.sh"}]},
        {matcher: "Edit", hooks: [{type: "command", command: $o}, {type: "command", command: "/opt/mine-b.sh"}]},
        {_agent_workspace: $t, matcher: "Read",
         hooks: [{type: "command", command: $m}, {type: "command", command: "/opt/mine-c.sh"}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
# The entry holding <command>, as compact JSON with sorted keys.
entry_of() { jq -cS --arg c "$1" '[.hooks.PreToolUse[] | select(any(.hooks[]?; .command == $c))]' "$SETTINGS"; }
run >/dev/null
[[ "$(entry_of /opt/mine-a.sh)" == '[{"hooks":[{"command":"/opt/mine-a.sh","type":"command"}],"matcher":"Bash"}]' \
   && "$(n_holding PreToolUse "$LOG_HOOK")" -eq 1 ]] \
    && pass "re-install removes only our command from a mixed entry; the user's command and matcher stay" \
    || fail "re-install over a mixed entry (entry: $(entry_of /opt/mine-a.sh); ours held $(n_holding PreToolUse "$LOG_HOOK")x)"
[[ "$(n_holding PreToolUse "$OTHER_HOOK")" -eq 2 && "$(n_holding PreToolUse /opt/mine-b.sh)" -eq 1 ]] \
    && pass "a plain install leaves another checkout's command in a mixed entry" \
    || fail "a plain install touched another checkout's mixed entry ($(entry_of /opt/mine-b.sh))"
run --force >/dev/null
[[ "$(n_holding PreToolUse "$OTHER_HOOK")" -eq 0 ]] \
    && pass "--force removes another checkout's unmarked hook command" \
    || fail "--force left another checkout's hook command"
[[ "$(entry_of /opt/mine-b.sh)" == '[{"hooks":[{"command":"/opt/mine-b.sh","type":"command"}],"matcher":"Edit"}]' ]] \
    && pass "--force removes only another checkout's command from a mixed entry" \
    || fail "--force over a mixed entry (entry: $(entry_of /opt/mine-b.sh))"
[[ "$(entry_of /opt/mine-c.sh)" == '[{"hooks":[{"command":"/opt/mine-c.sh","type":"command"}],"matcher":"Read"}]' ]] \
    && pass "--force removes only the marked checkout's command from a marked mixed entry, and drops the marker" \
    || fail "--force over a marked mixed entry (entry: $(entry_of /opt/mine-c.sh))"
[[ "$(n_holding PreToolUse "$USER_DEAD_HOOK")" -eq 1 && "$(n_holding PreToolUse "$USER_SAME_NAME")" -eq 1 ]] \
    && pass "install and --force leave the user's dead hook and the same-named hook outside any checkout" \
    || fail "a user's own hook was removed (dead: $(n_holding PreToolUse "$USER_DEAD_HOOK"), same name: $(n_holding PreToolUse "$USER_SAME_NAME"))"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean after --force with the user's commands kept" \
    || fail "--check after --force over mixed entries (rc=$rc out=$out)"

# (m) a hook command written through a symlinked alias of this checkout is
# this checkout's (compared by physical path), not another checkout's.
ln -s "$WSC" "$SANDBOX/ws-alias"
ALIAS_HOOK="$SANDBOX/ws-alias/.claude/hooks/log-tool-use.sh"
jq --arg c "$ALIAS_HOOK" '.hooks.PreToolUse += [{hooks: [{type: "command", command: $c, timeout: 5}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$out" != *"another workspace checkout"* && "$out" == *"no longer generated: $ALIAS_HOOK"* ]] \
    && pass "--check treats a symlinked alias of this checkout as this checkout, not another" \
    || fail "alias reported wrongly (rc=$rc out=$out)"
run >/dev/null
[[ "$(n_holding PreToolUse "$ALIAS_HOOK")" -eq 0 && "$(n_holding PreToolUse "$LOG_HOOK")" -eq 1 ]] \
    && pass "install replaces the alias-path hook command with ours (no second copy)" \
    || fail "install over an alias-path command (alias: $(n_holding PreToolUse "$ALIAS_HOOK"), ours: $(n_holding PreToolUse "$LOG_HOOK"))"
rm -f "$SANDBOX/ws-alias"

# (n) the user's own hooks that only look like ours. A command is classified
# only when the whole string is a literal absolute path with a hook name the
# installer writes or has retired, so none of these is ever reported or
# removed: a quoted variable, an interpreter prefix, a tilde, a relative
# path (run from inside this checkout and from inside another one, where
# it used to resolve against the installer's cwd), our own hook with a
# trailing argument, a same-named hook in an existing project that lacks
# only the file (not a dead checkout: its directory is on disk), and a
# hook wired directly to another file in this checkout's .claude/hooks/
# (not a name the installer writes or has retired).
NO_HOOK_PROJ="$SANDBOX/project-without-hook"
mkdir -p "$NO_HOOK_PROJ/.claude"
# shellcheck disable=SC2016,SC2088 # literal strings, never expanded
USER_FORMS=(
    '"$CLAUDE_PROJECT_DIR"/.claude/hooks/log-tool-use.sh'
    "bash $SANDBOX/deleted-ws/.claude/hooks/log-tool-use.sh"
    '~/gone/.claude/hooks/log-tool-use.sh'
    './.claude/hooks/log-tool-use.sh'
    "$LOG_HOOK --verbose"
    "$NO_HOOK_PROJ/.claude/hooks/log-tool-use.sh"
    "$WSC/.claude/hooks/session_start_project_layer.sh"
)
USER_FORMS_JSON="$(printf '%s\n' "${USER_FORMS[@]}" | jq -R . | jq -sc .)"
jq --argjson f "$USER_FORMS_JSON" '.hooks.PreToolUse += [$f[] | {hooks: [{type: "command", command: .}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
# Each user form held exactly once; else prints every one that is not.
forms_kept() {
    local f rc=0
    for f in "${USER_FORMS[@]}"; do
        [[ "$(n_holding PreToolUse "$f")" -eq 1 ]] || { printf '[%s] ' "$f"; rc=1; }
    done
    return "$rc"
}
out="$( cd "$WSC" && run --check )"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check (run in this checkout) reports none of the user's look-alike hook commands" \
    || fail "--check reported a user's look-alike hook (rc=$rc out=$out)"
out="$( cd "$OTHER_WS" && run --check )"; rc=$?
[[ "$rc" -eq 0 && "$out" != *"another workspace checkout"* ]] \
    && pass "--check run inside another checkout does not resolve a relative hook path against its cwd" \
    || fail "--check from another checkout's cwd (rc=$rc out=$out)"
( cd "$WSC" && run ) >/dev/null
missing="$(forms_kept)" \
    && pass "install (run in this checkout) keeps every user look-alike hook command" \
    || fail "install removed the user's hook command: $missing"
( cd "$WSC" && run --force ) >/dev/null
missing="$(forms_kept)" \
    && pass "--force keeps every user look-alike hook command" \
    || fail "--force removed the user's hook command: $missing"

# (o) a hook event whose value is not an array: skipped by every
# classification, not an error that empties the lists. A dead checkout's
# command elsewhere in the file is still reported, named by a plain install
# and removed by --force, and the odd event is left exactly as it is.
DEAD2_WS="$SANDBOX/deleted-ws-2"
DEAD2_HOOK="$DEAD2_WS/.claude/hooks/log-tool-use.sh"
jq --arg c "$DEAD2_HOOK" '.hooks.ZzOdd = {a: 1} | .hooks.PreToolUse += [{hooks: [{type: "command", command: $c}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"not on disk"*"$DEAD2_HOOK"* ]] \
    && pass "--check with a non-array event value still reports a dead checkout's hook" \
    || fail "--check with a non-array event value (rc=$rc out=$out)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"left in place: hook command $DEAD2_HOOK"* ]] \
    && pass "install with a non-array event value still names a dead checkout's hook" \
    || fail "install with a non-array event value (rc=$rc out=${out:0:300})"
out="$(run --force)"; rc=$?
[[ "$rc" -eq 0 && "$(n_holding PreToolUse "$DEAD2_HOOK")" -eq 0 ]] \
    && pass "--force with a non-array event value still removes a dead checkout's hook" \
    || fail "--force with a non-array event value (rc=$rc held=$(n_holding PreToolUse "$DEAD2_HOOK") out=${out:0:300})"
jq -e '.hooks.ZzOdd == {a: 1}' "$SETTINGS" >/dev/null \
    && pass "...and leaves the non-array event value as it was" \
    || fail "install or --force changed the non-array event value ($(jq -c '.hooks.ZzOdd' "$SETTINGS"))"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean with a non-array event value once the dead hook is gone" \
    || fail "--check after the non-array case (rc=$rc out=$out)"
jq 'del(.hooks.ZzOdd)' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

# (p) a marked entry from which nothing is removed: its marker still goes,
# so --check does not stay red for good. Marked with this checkout: a plain
# install drops it. Marked with another checkout: a plain install leaves it
# (that checkout's), --force drops it. The user's command stays either way.
OTHER_MARK="$SANDBOX/some-other-checkout"
jq --arg t "$WSC" --arg o "$OTHER_MARK" '.hooks.PreToolUse += [
        {_agent_workspace: $t, hooks: [{type: "command", command: "/opt/mine-m.sh"}]},
        {_agent_workspace: $o, hooks: [{type: "command", command: "/opt/mine-f.sh"}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"marked with this checkout holds a command outside it: /opt/mine-m.sh"* \
   && "$out" == *"another workspace checkout: $OTHER_MARK"* ]] \
    && pass "--check reports both marked entries" \
    || fail "marked entries not reported (rc=$rc out=$out)"
run >/dev/null
[[ "$(entry_of /opt/mine-m.sh)" == '[{"hooks":[{"command":"/opt/mine-m.sh","type":"command"}]}]' ]] \
    && pass "install drops this checkout's marker from an entry it removes nothing from; the command stays" \
    || fail "install over a marked user-only entry (entry: $(entry_of /opt/mine-m.sh))"
jq -e --arg o "$OTHER_MARK" '[.hooks.PreToolUse[] | select(._agent_workspace == $o)] | length == 1' "$SETTINGS" >/dev/null \
    && pass "a plain install leaves another checkout's marker" \
    || fail "a plain install changed another checkout's marked entry ($(entry_of /opt/mine-f.sh))"
run --force >/dev/null
[[ "$(entry_of /opt/mine-f.sh)" == '[{"hooks":[{"command":"/opt/mine-f.sh","type":"command"}]}]' ]] \
    && pass "--force drops another checkout's marker from an entry it removes nothing from; the command stays" \
    || fail "--force over another checkout's marked user-only entry (entry: $(entry_of /opt/mine-f.sh))"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean once install and --force have dropped the markers" \
    || fail "--check after dropping the markers (rc=$rc out=$out)"

# (q) a checkout path the literal rule rejects (a space in it). The exact
# match covers every command this script writes or wrote under this
# checkout, a retired hook included, and, inside an entry marked with a
# checkout, that checkout's commands; the same string in an unmarked entry
# stays the user's.
WSS="$SANDBOX/ws with space"
mkdir -p "$WSS"
cp -r "$WSC/.agent" "$WSC/.claude" "$WSC/.claude-plugin" "$WSS/"
rm -f "$WSS/.agent/projects.local"
HOMES="$SANDBOX/home-space"
mkdir -p "$HOMES"
run_space() {
    HOME="$HOMES" PATH="$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" TMPDIR="$INST_TMP" CLAUDE_CONFIG_DIR='' \
        AGENT_WORKSPACE_CLAUDE_BIN="$STUB" bash "$WSS/.agent/scripts/user_tier_install.sh" "$@" 2>&1
}
SPACE_SETTINGS="$HOMES/.claude/settings.json"
SPACE_RETIRED="$WSS/.claude/hooks/block-bash-tool-mapping.sh"
run_space >/dev/null
jq --arg c "$SPACE_RETIRED" '.hooks.PreToolUse += [{hooks: [{type: "command", command: $c}]}]' \
    "$SPACE_SETTINGS" > "$tmp" && mv "$tmp" "$SPACE_SETTINGS"
out="$(run_space --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"no longer generated: $SPACE_RETIRED"* ]] \
    && pass "--check reports this checkout's retired hook when the checkout path holds a space" \
    || fail "retired hook under a spaced checkout path not reported (rc=$rc out=$out)"
run_space >/dev/null
jq -e --arg c "$SPACE_RETIRED" --arg l "$WSS/.claude/hooks/log-tool-use.sh" '
    [.hooks.PreToolUse[].hooks[]?.command] | (index($c) == null) and (map(select(. == $l)) | length == 1)' \
    "$SPACE_SETTINGS" >/dev/null \
    && pass "install removes it, and holds our own spaced hook command once" \
    || fail "install over a spaced checkout path ($(jq -c '.hooks.PreToolUse' "$SPACE_SETTINGS"))"
out="$(run_space --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean for a spaced checkout path after the re-install" \
    || fail "--check for a spaced checkout path (rc=$rc out=$out)"
rm -rf "$WSS" "$HOMES"

SPACE_OTHER="$SANDBOX/other ws"
mkdir -p "$SPACE_OTHER/.agent"
: > "$SPACE_OTHER/.agent/user_tier_scripts.txt"
SPACE_OTHER_HOOK="$SPACE_OTHER/.claude/hooks/log-tool-use.sh"
jq --arg t "$SPACE_OTHER" --arg c "$SPACE_OTHER_HOOK" '.hooks.PreToolUse += [
        {_agent_workspace: $t, hooks: [{type: "command", command: $c}]},
        {matcher: "Unmarked", hooks: [{type: "command", command: $c}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"another workspace checkout: $SPACE_OTHER"* ]] \
    && pass "--check reports another checkout's marked entry under a spaced path" \
    || fail "spaced marked entry not reported (rc=$rc out=$out)"
run >/dev/null
[[ "$(n_holding PreToolUse "$SPACE_OTHER_HOOK")" -eq 2 ]] \
    && pass "a plain install leaves another checkout's marked command under a spaced path" \
    || fail "a plain install changed the spaced marked entry ($(n_holding PreToolUse "$SPACE_OTHER_HOOK"))"
run --force >/dev/null
[[ "$(entry_of "$SPACE_OTHER_HOOK")" == "$(jq -cnS --arg c "$SPACE_OTHER_HOOK" '[{matcher: "Unmarked", hooks: [{type: "command", command: $c}]}]')" ]] \
    && pass "--force removes the marked entry's command, and leaves the same string in an unmarked entry (the user's)" \
    || fail "--force over a spaced marked entry (entries: $(entry_of "$SPACE_OTHER_HOOK"))"
jq --arg c "$SPACE_OTHER_HOOK" '.hooks.PreToolUse |= map(select(any(.hooks[]?; .command == $c) | not))' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
rm -rf "$SPACE_OTHER"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean after the spaced-path cases" \
    || fail "--check after the spaced-path cases (rc=$rc out=$out)"

# (r) --check judges our commands under their own event and counts them,
# so it agrees with what install would change: a second copy (the state
# #394's bug left) and a copy only under another event are drift, and
# install leaves one, where it belongs.
jq --arg l "$LOG_HOOK" --arg s "$HOOK_LINK" '
    .hooks.PreToolUse += [{hooks: [{type: "command", command: $l, timeout: 5}]}]
    | .hooks.SessionStart += [{hooks: [{type: "command", command: $s, timeout: 10}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"$LOG_HOOK is registered 2 times under PreToolUse"* \
   && "$out" == *"$HOOK_LINK is registered 2 times under SessionStart"* ]] \
    && pass "--check reports our hook command held twice under its event" \
    || fail "duplicate hook entries not reported (rc=$rc out=$out)"
run >/dev/null
[[ "$(n_holding PreToolUse "$LOG_HOOK")" -eq 1 && "$(n_holding SessionStart "$HOOK_LINK")" -eq 1 ]] \
    && pass "install leaves one copy of each" \
    || fail "install left duplicates (PreToolUse $(n_holding PreToolUse "$LOG_HOOK"), SessionStart $(n_holding SessionStart "$HOOK_LINK"))"
jq --arg l "$LOG_HOOK" '
    .hooks.PreToolUse |= map(select(any(.hooks[]?; .command == $l) | not))
    | .hooks.PostToolUse = [{hooks: [{type: "command", command: $l}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"missing hook entry for $LOG_HOOK (under PreToolUse)"* \
   && "$out" == *"$LOG_HOOK is registered under PostToolUse"* ]] \
    && pass "--check reports our hook command held only under another event" \
    || fail "hook under the wrong event not reported (rc=$rc out=$out)"
run >/dev/null
[[ "$(n_holding PreToolUse "$LOG_HOOK")" -eq 1 && "$(n_holding PostToolUse "$LOG_HOOK")" -eq 0 ]] \
    && pass "install moves it under its own event" \
    || fail "install over the wrong event (PreToolUse $(n_holding PreToolUse "$LOG_HOOK"), PostToolUse $(n_holding PostToolUse "$LOG_HOOK"))"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean once install has fixed both" \
    || fail "--check after the event cases (rc=$rc out=$out)"

# --------------------------------------------------------------- safety ---
# A skill directory the user owns is never replaced.
mkdir -p "$SKILLS_DIR/zz-fixture-both-real"
mk_skill zz-fixture-both-real both
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && -d "$SKILLS_DIR/zz-fixture-both-real" && ! -L "$SKILLS_DIR/zz-fixture-both-real" ]] \
    && pass "an existing non-symlink skill directory is left alone" \
    || fail "the installer overwrote a user-owned skill directory"
rm -rf "$SKILLS_DIR/zz-fixture-both-real"

# ------------------------------------------------ uninstall that fails ---
# --uninstall reads, classifies, builds and backs up settings.json, and
# writes it, before it removes anything else. Each failure up to that write
# exits 1 with everything as it was: the root file, the rules record, the
# SessionStart link, the plugin (here enabled in this checkout itself, so a
# removal would show in the stub log) and settings.json, and no "removed".
mk_fail_shim() {  # <dir> <command> <glob an argument must match to fail>
    mkdir -p "$1"
    cat > "$1/$2" <<SHIMEOF
#!/usr/bin/env bash
for a in "\$@"; do [[ "\$a" == $3 ]] && exit 1; done
exec $(command -v "$2") "\$@"
SHIMEOF
    chmod +x "$1/$2"
}
U_LOCAL="$WSC/.claude/settings.local.json"
jq -n --arg p "$WSC" '{enabledPlugins: {"agent-workspace@agent-workspace": true},
    extraKnownMarketplaces: {"agent-workspace": {source: {source: "directory", path: $p}}}}' > "$U_LOCAL"
U_RULES="$HOMEDIR/.claude/agent-workspace-rules.json"
uninstall_refuses() {  # <what> <shim dir or ""> <text the output must hold>
    local log_n local_before
    cp "$SETTINGS" "$SANDBOX/u-before.json"
    log_n="$(wc -l < "$STUB_LOG")"
    local_before="$(cat "$U_LOCAL")"
    out="$(RUN_PATH_PREFIX="$2" run --uninstall)"; rc=$?
    [[ "$rc" -eq 1 && "$out" == *"$3"* && "$out" != *"user tier removed"* ]] \
        && pass "--uninstall with $1 exits 1 and says why" \
        || fail "--uninstall with $1 (rc=$rc out=${out:0:400})"
    [[ "$(cat "$ROOT_FILE" 2>/dev/null)" == "$WSC" && -f "$U_RULES" && -L "$HOOK_LINK" ]] \
        && pass "...leaving the root file, the rules record and the SessionStart link" \
        || fail "--uninstall with $1 removed files (root: $([[ -e "$ROOT_FILE" ]] && echo yes || echo no), rules: $([[ -e "$U_RULES" ]] && echo yes || echo no), link: $([[ -L "$HOOK_LINK" ]] && echo yes || echo no))"
    [[ "$(wc -l < "$STUB_LOG")" -eq "$log_n" && "$(cat "$U_LOCAL")" == "$local_before" ]] \
        && pass "...and the plugin (no claude CLI call)" \
        || fail "--uninstall with $1 touched the plugin ($(tail -n +"$((log_n + 1))" "$STUB_LOG"))"
    cmp -s "$SETTINGS" "$SANDBOX/u-before.json" \
        && ! compgen -G "$HOMEDIR/.claude/.settings.json.*" >/dev/null \
        && pass "...and settings.json unchanged, no temporary file left" \
        || fail "--uninstall with $1 changed settings.json or left a temporary file"
    cp "$SANDBOX/u-before.json" "$SETTINGS"
    rm -f "$SANDBOX/u-before.json"
}
u_with() {  # <jq filter>: settings.json as the next case reads it
    jq "$1" "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
}
cp "$SETTINGS" "$SANDBOX/u-clean.json"
u_with '.hooks.ZzBool = true'
uninstall_refuses "a boolean hook event value" "" "could not build the rewrite"
cp "$SANDBOX/u-clean.json" "$SETTINGS"
u_with '.permissions.allow = "not-an-array"'
uninstall_refuses "a permissions.allow that is not an array" "" "could not build the rewrite"
cp "$SANDBOX/u-clean.json" "$SETTINGS"
u_with '.hooks.PreToolUse += ["not-an-object"]'
uninstall_refuses "a hooks array holding a non-object entry" "" "could not build the rewrite"
cp "$SANDBOX/u-clean.json" "$SETTINGS"
mk_fail_shim "$SANDBOX/u-jq-shim" jq '*@base64*'
uninstall_refuses "a failed classification" "$SANDBOX/u-jq-shim" "could not read the hook commands"
mk_fail_shim "$SANDBOX/u-cp-shim" cp '*agent-workspace-backup*'
uninstall_refuses "a failed backup" "$SANDBOX/u-cp-shim" "could not back up"
mk_fail_shim "$SANDBOX/u-mv-shim" mv '*/.claude/settings.json'
uninstall_refuses "a refused settings.json write" "$SANDBOX/u-mv-shim" "failed to write"
rm -f "$U_LOCAL" "$SANDBOX/u-clean.json" "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*

# ----------------------------------------------------------- uninstall ---
# As the CLI leaves it (no markers), with our PreToolUse command sharing an
# entry with the user's own: uninstall removes ours and keeps theirs.
jq --arg l "$LOG_HOOK" '.hooks.PreToolUse |= map(
        if any(.hooks[]?; .command == $l)
        then .matcher = "Bash" | .hooks += [{type: "command", command: "/opt/mine-u.sh"}] else . end)' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
cli_rewrite
# ...and, after the rewrite, an entry an earlier generation marked with this
# checkout that holds only the user's command: uninstall drops the marker.
jq --arg t "$WSC" '.hooks.PreToolUse += [{_agent_workspace: $t, hooks: [{type: "command", command: "/opt/mine-um.sh"}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 0 ]] && pass "uninstall exits 0" || fail "uninstall failed (rc=$rc out=$out)"
[[ ! -e "$ROOT_FILE" ]] && pass "uninstall removes agent-workspace-root" || fail "root file survived uninstall"
[[ ! -e "$HOOK_LINK" ]] && pass "uninstall removes the SessionStart symlink" || fail "hook symlink survived uninstall"
[[ -z "$(jq -r --arg p "$WSC/" --arg l "$HOOK_LINK" --argjson keep "$USER_FORMS_JSON" '[.hooks // {} | to_entries[] | .value[] | .hooks[]? | .command
         | select(startswith($p) or . == $l) | select(. as $c | $keep | index($c) == null)] | .[]' "$SETTINGS")" ]] \
    && pass "uninstall removes our hook commands" || fail "our hook commands survived uninstall"
missing="$(forms_kept)" \
    && pass "uninstall keeps every user look-alike hook command" \
    || fail "uninstall removed the user's hook command: $missing"
[[ "$(entry_of /opt/mine-um.sh)" == '[{"hooks":[{"command":"/opt/mine-um.sh","type":"command"}]}]' ]] \
    && pass "uninstall drops this checkout's marker from an entry it removes nothing from; the command stays" \
    || fail "uninstall over a marked user-only entry (entry: $(entry_of /opt/mine-um.sh))"
jq -e '[.hooks.PreToolUse[]?.hooks[]?.command] | index("/opt/mine.sh") != null' "$SETTINGS" >/dev/null \
    && pass "uninstall leaves the user's own hook entry alone" \
    || fail "uninstall removed the user's own hook entry"
[[ "$(entry_of /opt/mine-u.sh)" == '[{"hooks":[{"command":"/opt/mine-u.sh","type":"command"}],"matcher":"Bash"}]' ]] \
    && pass "uninstall removes only our command from a mixed entry; the user's command and matcher stay" \
    || fail "uninstall over a mixed entry (entry: $(entry_of /opt/mine-u.sh))"
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
# A run that changes settings.json backs it up first; one with nothing to
# change neither rewrites it nor backs it up (#394).
rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*
out="$(run)"
ls "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.* >/dev/null 2>&1 \
    && fail "a run with nothing to change wrote a backup (out=${out:0:160})" \
    || pass "a run with nothing to change writes no backup"
[[ "$out" == *"not rewritten"* ]] \
    && pass "a run with nothing to change says settings.json was not rewritten" \
    || fail "no-op run did not say so (out=${out:0:300})"
drop_a_rule() {  # make the next install a real change
    jq '.permissions.allow |= map(select(contains("worktree_create.sh") | not))' "$SETTINGS" > "$tmp" \
        && cat "$tmp" > "$SETTINGS" && rm -f "$tmp"
}
drop_a_rule
out="$(run)"
ls "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.* >/dev/null 2>&1 \
    && pass "a timestamped backup is written before the rewrite" \
    || fail "no backup written (out=${out:0:160})"
rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*

# The backup is taken before anything in ~/.claude is written: a failed
# backup leaves the root file, the allow-rule record, the SessionStart link
# and settings.json exactly as they were. A `cp` shim fails the backup copy
# alone.
CP_SHIM="$SANDBOX/cp-shim"
mkdir -p "$CP_SHIM"
cat > "$CP_SHIM/cp" <<SHIMEOF
#!/usr/bin/env bash
for a in "\$@"; do [[ "\$a" == *agent-workspace-backup* ]] && exit 1; done
exec $(command -v cp) "\$@"
SHIMEOF
chmod +x "$CP_SHIM/cp"
RULES_FILE="$HOMEDIR/.claude/agent-workspace-rules.json"
rm -f "$ROOT_FILE" "$HOOK_LINK" "$RULES_FILE"
drop_a_rule
cp "$SETTINGS" "$SANDBOX/settings-before.json"
out="$(RUN_PATH_PREFIX="$CP_SHIM" run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"could not back up"* ]] \
    && pass "a failed backup stops the install (exit 1)" \
    || fail "a failed backup did not stop the install (rc=$rc out=${out:0:300})"
[[ ! -e "$ROOT_FILE" && ! -e "$RULES_FILE" && ! -L "$HOOK_LINK" ]] \
    && pass "...before the root file, the allow-rule record or the SessionStart link is written" \
    || fail "a failed backup left writes behind (root file: $([[ -e "$ROOT_FILE" ]] && echo yes || echo no), rules: $([[ -e "$RULES_FILE" ]] && echo yes || echo no), link: $([[ -L "$HOOK_LINK" ]] && echo yes || echo no))"
cmp -s "$SETTINGS" "$SANDBOX/settings-before.json" && [[ "$(n_backups)" -eq 0 ]] \
    && pass "...and with settings.json unchanged and no backup file" \
    || fail "a failed backup changed settings.json or left a backup ($(n_backups))"
rm -f "$SANDBOX/settings-before.json"
run >/dev/null
rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*

# --------------------------------------------- a second workspace checkout ---
# Round 1 must-fix: the root file was overwritten unconditionally, and the
# losing checkout's --check then said "not installed (optional)" and exited 0.
WSC2="$SANDBOX/ws2"
mkdir -p "$WSC2"
cp -r "$WS_ROOT/.agent" "$WSC2/.agent"
cp -r "$WS_ROOT/.claude" "$WSC2/.claude"
# As for the first copy: the machine's own registry must never reach it, or
# --force and --check would walk the owner's real project roots.
rm -f "$WSC2/.agent/projects.local"
run2() { HOME="$HOMEDIR" CLAUDE_CONFIG_DIR='' bash "$WSC2/.agent/scripts/user_tier_install.sh" "$@" 2>&1; }

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

leftover=$(jq -r --arg old "$WSC/.claude/hooks/" '
    [.hooks // {} | to_entries[] | .value[] | .hooks[]? | .command
     | select(startswith($old))] | length' "$SETTINGS")
[[ "$leftover" -eq 0 ]] \
    && pass "--force removes every hook command of the old checkout" \
    || fail "--force left $leftover hook command(s) under $WSC/.claude/hooks/"

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
# A real change, so the install writes (a no-op run writes nothing).
drop_a_rule
run >/dev/null
[[ -L "$SETTINGS" ]] \
    && pass "a symlinked settings.json is still a symlink after install" \
    || fail "install replaced the symlinked settings.json with a regular file"
jq -e --arg c "$WSC/.agent/scripts/worktree_create.sh" \
    '[.permissions.allow[]] | index("Bash(" + $c + ":*)") != null' "$real" >/dev/null \
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
# Each run must write, so each must have something to change.
for _ in 1 2 3 4 5 6 7; do drop_a_rule; run >/dev/null; done
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
# A real change, so the install writes (a no-op run writes nothing).
drop_a_rule
inode_before="$(stat -c %i "$DOTFILES/claude-settings.json")"

out="$(run)"; rc=$?
[[ "$rc" -eq 0 ]] || fail "install over a symlinked settings.json exited $rc (out=${out:0:200})"

[[ -L "$SETTINGS" ]] \
    && pass "settings.json is still a symlink after install" \
    || fail "install replaced the settings.json symlink with a regular file"
[[ "$(readlink "$SETTINGS")" == "$link_target_before" ]] \
    && pass "the symlink still points at the same dotfiles path" \
    || fail "the symlink was repointed ($(readlink "$SETTINGS") != $link_target_before)"

jq -e --arg c "$WSC/.agent/scripts/worktree_create.sh" --arg h "$WSC/.claude/hooks/log-tool-use.sh" '
    ([.permissions.allow[]] | index("Bash(" + $c + ":*)") != null)
    and ([.hooks.PreToolUse[].hooks[]?.command] | index($h) != null)
' "$DOTFILES/claude-settings.json" >/dev/null \
    && pass "the dotfiles file itself received the install" \
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
# ADR-0018. A sandboxed registry with one root of every verdict: a git repo
# (enable), a directory in no git repo (enable), a root inside the
# workspace copy's own git tree (skip -- it sees the bare skills), the same
# reached through a symlinked path (still skip: pwd -P on both sides), a
# parent root with instances, and a root not on disk (a note). The claude
# stub stands in for the CLI.
#
# Instances follow what the live suite observed (case G): a session reads
# the local settings of its git toplevel -- the main repository's, for a
# worktree. So the parent `fam` is a git repo; `fam/inst` (a worktree of
# it) and `fam/sub` (a plain directory in it) are skipped; `fam-stray` (a
# sibling in no git repo) and `pp/inst` (under a plain-directory parent)
# are enabled as roots of their own.
ROOTS="$SANDBOX/roots"
mkdir -p "$ROOTS/a" "$ROOTS/nogit" "$ROOTS/fam/sub" "$ROOTS/fam-stray" "$ROOTS/pp/inst" "$ROOTS/pp/repo"
git -C "$ROOTS/pp/repo" init -q
git -C "$ROOTS/a" init -q
git -C "$ROOTS/fam" init -q
git -C "$ROOTS/fam" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$ROOTS/fam" worktree add -q "$ROOTS/fam/inst" 2>/dev/null
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
fam-s    single_project  $ROOTS/fam-stray  parent=fam
fam-d    single_project  $ROOTS/fam/sub  parent=fam
pp       project         $ROOTS/pp
pp-i     single_project  $ROOTS/pp/inst  parent=pp
pp-r     single_project  $ROOTS/pp/repo  parent=pp
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
enabled_in "$ROOTS/fam" && [[ ! -e "$ROOTS/fam/inst/$SLJ" && ! -e "$ROOTS/fam/sub/$SLJ" \
      && "$out" == *"skipped fam-i: a parent= instance"* && "$out" == *"skipped fam-d: a parent= instance"* ]] \
    && pass "a git-repo parent is enabled; its worktree instance and plain-directory instance are skipped" \
    || fail "parent/instance handling is wrong (out=${out:0:400})"
# An instance whose sessions do not read the parent's local settings would
# have no plugin if skipped: it is enabled as a root of its own, with a
# note saying why -- a sibling in no git repo, and an instance under a
# plain-directory parent (the case the live suite showed skip-instance
# got wrong).
enabled_in "$ROOTS/fam-stray" && [[ "$out" == *"fam-s is a parent= instance that is in no git repository"* \
      && "$out" != *"skipped fam-s"* ]] \
    && pass "a parent= instance in no git repository is enabled directly, with a note" \
    || fail "no-git instance handling is wrong (out=${out:0:600})"
enabled_in "$ROOTS/pp/inst" && enabled_in "$ROOTS/pp" && [[ "$out" == *"pp-i is a parent= instance that is in no git repository"* ]] \
    && pass "an instance under a plain-directory parent is enabled as a root of its own" \
    || fail "plain-parent instance handling is wrong (out=${out:0:600})"
enabled_in "$ROOTS/pp/repo" && [[ "$out" == *"pp-r is a parent= instance that has a parent ($ROOTS/pp) in no git repository"* ]] \
    && pass "a git-repo instance under a plain-directory parent is enabled as a root of its own, naming why" \
    || fail "git instance under a plain parent (out=${out:0:600})"
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
[[ "$out" == *"note: fam-s is a parent= instance that is in no git repository"* ]] \
    && pass "--check notes a parent= instance enabled as a root of its own" \
    || fail "--check did not note the mis-nested instance (out=${out:0:400})"
rm -f "${ROOTS:?}/fam-stray/.claude/settings.local.json"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"plugin not enabled from this checkout in registered root fam-s"* ]] \
    && pass "--check reports a mis-nested instance without the plugin as drift" \
    || fail "mis-nested instance without the plugin not flagged (rc=$rc out=${out:0:400})"
run >/dev/null

# An instance whose parent is not on disk is not "outside its parent's
# directory": it says the parent is missing. (An unregistered parent, or an
# instance at its parent's own path, is dropped by the registry parser.)
cp "$WSC/.agent/projects.local" "$SANDBOX/projects.local.saved"
mkdir -p "$ROOTS/lost-inst"
cat > "$WSC/.agent/projects.local" <<REG
lost     project         $ROOTS/lost-parent
lost-i   single_project  $ROOTS/lost-inst  parent=lost
REG
out="$(run)"; out_check="$(run --check)"
want="lost-i is a parent= instance whose parent's directory ($ROOTS/lost-parent) is not on disk"
[[ "$out" == *"NOTE: $want -- enabled as a session root of its own"* \
      && "$out_check" == *"note: $want -- checked as a session root of its own"* \
      && "$out$out_check" != *"in no git repository"* ]] \
    && pass "install and --check say an instance's parent is not on disk, not that it lies outside it" \
    || fail "missing-parent instance wording (out=${out:0:600} check=${out_check:0:600})"
mv "$SANDBOX/projects.local.saved" "$WSC/.agent/projects.local"
rm -rf "${ROOTS:?}/lost-inst"
run >/dev/null

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

# A parent= instance with a declaration of its own: its parent's enable is
# what reaches it, and a declaration there can shadow the parent's -- from
# another checkout, loading that checkout's skills while every root above
# looks right. --check flags it, whoever declared it, and install removes it.
foreign_enable() {  # <root>: an enable declared from $SANDBOX/elsewhere
    mkdir -p "$1/.claude" "$SANDBOX/elsewhere"
    jq -n --arg p "$SANDBOX/elsewhere" '{enabledPlugins: {"agent-workspace@agent-workspace": true},
        extraKnownMarketplaces: {"agent-workspace": {source: {source: "directory", path: $p}}}}' > "$1/$SLJ"
}
# stale_enable writes a COMPLETE enable from this checkout (state
# `enabled`); these two are the genuinely `stale` shapes.
enable_only() {  # <root>: enabled, with no marketplace declaration
    mkdir -p "$1/.claude"
    echo '{"enabledPlugins": {"agent-workspace@agent-workspace": true}}' > "$1/$SLJ"
}
declare_only() {  # <root>: declared from this checkout, not enabled
    mkdir -p "$1/.claude"
    jq -n --arg p "$WSC_PHYS" '{extraKnownMarketplaces: {"agent-workspace": {source: {source: "directory", path: $p}}}}' > "$1/$SLJ"
}
# It is reported, never removed: every skipped instance shares its
# parent's repository, where a local-scope remove could strip the parent's
# enable -- a plain directory of it (fam-d: local scope lands on the
# toplevel, live case K) or a linked worktree (fam-i: where local scope
# writes is not established). Install exits 1 naming the file to edit, runs
# no CLI from the instance, and leaves both files as they are.
for inst in "fam-i:$ROOTS/fam/inst:a git worktree of its parent's repository" \
            "fam-d:$ROOTS/fam/sub:a plain directory inside the git repository $ROOTS/fam"; do
    iname="${inst%%:*}"; rest="${inst#*:}"; ipath="${rest%%:*}"; why="${rest#*:}"
    for who in stale_enable enable_only declare_only foreign_enable; do
        "$who" "$ipath"
        before="$(cat "$ipath/$SLJ")"; parent_before="$(cat "$ROOTS/fam/$SLJ")"
        out="$(run --check)"; rc=$?
        [[ "$rc" -eq 1 && "$out" == *"DRIFT: agent-workspace plugin is declared in parent= instance $iname ($ipath) itself"*"remove it from $ipath/.claude/settings.local.json by hand"*"$why"* ]] \
            && pass "--check flags $iname's own declaration ($who), with by-hand advice" \
            || fail "instance declaration $iname ($who) in --check (rc=$rc out=${out:0:400})"
        : > "$STUB_LOG"
        out="$(run)"; rc=$?
        if [[ "$rc" -eq 1 && "$out" == *"declared in parent= instance $iname itself ($ipath)"*"does not run the claude CLI there"*"$why"* \
              && "$(cat "$ipath/$SLJ")" == "$before" && "$(cat "$ROOTS/fam/$SLJ")" == "$parent_before" ]] \
           && ! grep -q "^$ipath|" "$STUB_LOG" && enabled_in "$ROOTS/fam"; then
            pass "install reports $iname's own declaration ($who) and runs no CLI there, leaving both files"
        else
            fail "instance declaration $iname ($who) at install (rc=$rc log=$(grep "^$ipath|" "$STUB_LOG") out=${out:0:400})"
        fi
        rm -f "$ipath/.claude/settings.local.json"
    done
done
# An explicit local disable (enabledPlugins[id] = false, no declaration)
# is not a declaration, but it can turn the parent's plugin off there:
# --check and install report it, and leave it (it may be deliberate).
mkdir -p "$ROOTS/fam/inst/.claude"
echo '{"enabledPlugins": {"agent-workspace@agent-workspace": false}}' > "$ROOTS/fam/inst/$SLJ"
out_check="$(run --check)"; rc_check=$?
out="$(run)"; rc=$?
want="parent= instance fam-i ($ROOTS/fam/inst) disables the agent-workspace plugin locally"
[[ "$rc_check" -eq 0 && "$out_check" == *"note: $want"* && "$rc" -eq 0 && "$out" == *"note: $want"* \
      && "$(cat "$ROOTS/fam/inst/$SLJ")" == '{"enabledPlugins": {"agent-workspace@agent-workspace": false}}' ]] \
    && pass "--check and install report a parent= instance's local disable, and leave it" \
    || fail "instance local disable (check rc=$rc_check out=${out_check:0:300}; install rc=$rc out=${out:0:300})"
rm -f "${ROOTS:?}/fam/inst/.claude/settings.local.json"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 ]] && pass "--check is clean once the instance's own declaration is gone" \
    || fail "--check after removing the instance declaration (rc=$rc out=${out:0:400})"

# An instance that is a plain directory inside a git repository -- here its
# parent -- is not acted on: the CLI's local scope from there may resolve to
# the parent's settings.local.json and strip the parent's working enable.
# Install refuses, names the file to edit, and exits 1; the parent's file is
# untouched and no CLI call runs from the instance. An instance that is a
# git repository of its own is a separate project (live case G): it is
# enabled as a root of its own, its declaration kept.
cp "$WSC/.agent/projects.local" "$SANDBOX/projects.local.saved"
mkdir -p "$ROOTS/famg/inst" "$ROOTS/famg/repo-inst"
git -C "$ROOTS/famg" init -q
git -C "$ROOTS/famg/repo-inst" init -q
cat > "$WSC/.agent/projects.local" <<REG
famg     project         $ROOTS/famg
famg-i   single_project  $ROOTS/famg/inst       parent=famg
famg-r   single_project  $ROOTS/famg/repo-inst  parent=famg
REG
run >/dev/null
parent_before="$(cat "$ROOTS/famg/$SLJ")"
stale_enable "$ROOTS/famg/inst"
stale_enable "$ROOTS/famg/repo-inst"
: > "$STUB_LOG"
out="$(run)"; rc=$?
if [[ "$rc" -eq 1 && "$out" == *"parent= instance famg-i itself ($ROOTS/famg/inst)"*"a plain directory inside the git repository $ROOTS/famg"* \
      && "$(cat "$ROOTS/famg/$SLJ")" == "$parent_before" ]] && enabled_in "$ROOTS/famg" && enabled_in "$ROOTS/famg/inst" \
   && ! grep -q "^$ROOTS/famg/inst|" "$STUB_LOG"; then
    pass "install does not run the CLI from an instance inside a git repository, leaving the parent's enable intact"
else
    fail "instance inside a git repo (rc=$rc log=$(cat "$STUB_LOG") out=${out:0:500})"
fi
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"instance famg-i ($ROOTS/famg/inst) itself"*"remove it from $ROOTS/famg/inst/.claude/settings.local.json by hand"* ]] \
    && pass "--check tells the user to remove that instance's declaration by hand, not to re-run the installer" \
    || fail "--check advice for an instance inside a git repo (rc=$rc out=${out:0:500})"
enabled_in "$ROOTS/famg/repo-inst" && [[ "$out" == *"famg-r is a parent= instance that is a git repository of its own ($ROOTS/famg/repo-inst), not a worktree of its parent's"* ]] \
    && pass "an instance that is its own git repository inside a git-repo parent is enabled as a root of its own" \
    || fail "the repo instance was not enabled as its own root ($(cat "$ROOTS/famg/repo-inst/$SLJ"); out=${out:0:400})"
# --uninstall refuses that instance the same way: it reports the
# declaration for removal by hand, exits 1, and runs no CLI there, while
# the parent and the repository instance are still uninstalled.
inst_before="$(cat "$ROOTS/famg/inst/$SLJ")"
: > "$STUB_LOG"
out="$(run --uninstall 2>&1)"; rc=$?
if [[ "$rc" -eq 1 && "$out" == *"declared in parent= instance famg-i itself ($ROOTS/famg/inst); --uninstall does not run the claude CLI there (it is a plain directory inside the git repository $ROOTS/famg"*"by hand"* \
      && "$(cat "$ROOTS/famg/inst/$SLJ")" == "$inst_before" ]] \
   && ! grep -q "^$ROOTS/famg/inst|" "$STUB_LOG" && ! enabled_in "$ROOTS/famg" && ! enabled_in "$ROOTS/famg/repo-inst"; then
    pass "--uninstall reports a skipped instance's own declaration, runs no CLI there, and still uninstalls the other roots"
else
    fail "--uninstall over a skipped instance's declaration (rc=$rc log=$(cat "$STUB_LOG") out=${out:0:500})"
fi
# A declaration from another checkout there is left alone with a note.
foreign_enable "$ROOTS/famg/inst"
: > "$STUB_LOG"
out="$(run --uninstall 2>&1)"; rc=$?
[[ "$out" == *"plugin in $ROOTS/famg/inst is declared from another checkout ($SANDBOX/elsewhere) -- left for that checkout's --uninstall"* ]] \
      && ! grep -q "^$ROOTS/famg/inst|" "$STUB_LOG" \
    && pass "--uninstall leaves another checkout's declaration in a skipped instance, running no CLI there" \
    || fail "--uninstall over a foreign declaration in a skipped instance (rc=$rc log=$(cat "$STUB_LOG") out=${out:0:500})"
rm -f "$ROOTS/famg/inst/$SLJ"
mv "$SANDBOX/projects.local.saved" "$WSC/.agent/projects.local"
rm -rf "${ROOTS:?}/famg"
run >/dev/null

# A registered root that is a plain directory inside some other git
# repository: its sessions read that repository's local settings, and the
# CLI's local scope from there writes them (live case K) -- outside every
# registered root. Install, --check and --uninstall refuse it, never
# running the CLI there; the other roots are unaffected.
cp "$WSC/.agent/projects.local" "$SANDBOX/projects.local.saved"
mkdir -p "$ROOTS/mono/sub"
git -C "$ROOTS/mono" init -q
printf 'encl single_project %s\na single_project %s\n' "$ROOTS/mono/sub" "$ROOTS/a" > "$WSC/.agent/projects.local"
: > "$STUB_LOG"
out="$(run 2>&1)"; rc=$?
if [[ "$rc" -eq 1 && "$out" == *"ERROR: not enabling the agent-workspace plugin in registered root encl ($ROOTS/mono/sub): it is a plain directory inside the git repository $ROOTS/mono"*"register the repository's toplevel ($ROOTS/mono) as the root instead"* \
      && ! -e "$ROOTS/mono/.claude/settings.local.json" && ! -e "$ROOTS/mono/sub/.claude/settings.local.json" ]] \
   && ! grep -q "^$ROOTS/mono" "$STUB_LOG" && enabled_in "$ROOTS/a"; then
    pass "install refuses a root inside an unrelated git repository, runs no CLI there, and still enables the other roots"
else
    fail "install over a root inside an unrelated repo (rc=$rc log=$(cat "$STUB_LOG") out=${out:0:500})"
fi
: > "$STUB_LOG"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"DRIFT: agent-workspace plugin cannot be enabled in registered root encl ($ROOTS/mono/sub): it is a plain directory inside the git repository $ROOTS/mono"* && ! -s "$STUB_LOG" ]] \
    && pass "--check flags a root inside an unrelated git repository" \
    || fail "--check over a root inside an unrelated repo (rc=$rc out=${out:0:500})"
stale_enable "$ROOTS/mono/sub"
before="$(cat "$ROOTS/mono/sub/$SLJ")"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"plugin is declared in $ROOTS/mono/sub/.claude/settings.local.json itself -- remove it by hand"* ]] \
    && pass "--check also reports that root's own declaration for removal by hand" \
    || fail "--check over a declaration in an enclosed root (rc=$rc out=${out:0:500})"
: > "$STUB_LOG"
out="$(run --uninstall 2>&1)"; rc=$?
if [[ "$rc" -eq 1 && "$out" == *"declared in registered root encl itself ($ROOTS/mono/sub); --uninstall does not run the claude CLI there (it is a plain directory inside the git repository $ROOTS/mono"* \
      && "$(cat "$ROOTS/mono/sub/$SLJ")" == "$before" ]] \
   && ! grep -q "^$ROOTS/mono" "$STUB_LOG" && ! enabled_in "$ROOTS/a"; then
    pass "--uninstall refuses a root inside an unrelated git repository, and still uninstalls the other roots"
else
    fail "--uninstall over a root inside an unrelated repo (rc=$rc log=$(cat "$STUB_LOG") out=${out:0:500})"
fi
mv "$SANDBOX/projects.local.saved" "$WSC/.agent/projects.local"
rm -rf "${ROOTS:?}/mono"
run >/dev/null

# A registry line that does not parse stops install, --check and
# --uninstall before anything is read or changed, with the parser's ERROR
# and the installer's own visible: acting on the remaining roots would
# report success while the dropped root kept (or lacked) the plugin.
cp "$WSC/.agent/projects.local" "$SANDBOX/projects.local.saved"
printf 'a single_project %s\nbad!name single_project %s\n' "$ROOTS/a" "$ROOTS/b" > "$WSC/.agent/projects.local"
a_before="$(cat "$ROOTS/a/$SLJ")"
for mode in install --check --uninstall; do
    : > "$STUB_LOG"
    if [[ "$mode" == install ]]; then out="$(run 2>&1)"; else out="$(run "$mode" 2>&1)"; fi; rc=$?
    if [[ "$rc" -eq 1 && "$out" == *"invalid project name 'bad!name'"* && "$out" == *"ERROR: $WSC/.agent/projects.local does not parse"* \
          && "$out" != *"installed and current"* && "$out" != *"removed"* && "$(cat "$ROOTS/a/$SLJ")" == "$a_before" && -f "$ROOT_FILE" ]] \
       && [[ ! -s "$STUB_LOG" ]]; then
        pass "a malformed registry line fails $mode with the parser's ERROR shown, changing nothing"
    else
        fail "$mode over a malformed registry (rc=$rc log=$(cat "$STUB_LOG") out=${out:0:500})"
    fi
done
mv "$SANDBOX/projects.local.saved" "$WSC/.agent/projects.local"
run >/dev/null

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

# A declaration with no enable, where the plugin must not be, doubles
# nothing: --check calls it a leftover, not "every skill loads twice", and
# install still removes it.
for leftover in "$WSC/projects/inner" "$WSC"; do
    mkdir -p "$leftover/.claude"
    jq -n --arg p "$WSC_PHYS" '{extraKnownMarketplaces: {"agent-workspace": {source: {source: "directory", path: $p}}}}' \
        > "$leftover/$SLJ"
    out="$(run --check)"; rc=$?
    [[ "$rc" -eq 1 && "$out" == *"marketplace is declared, with the plugin not enabled, in "*"a leftover"* \
          && "$out" != *"loads twice"* ]] \
        && pass "--check calls a declaration with no enable in ${leftover#"$SANDBOX"/} a leftover, not a doubled root" \
        || fail "leftover declaration in ${leftover#"$SANDBOX"/} misreported (rc=$rc out=${out:0:400})"
    out="$(run)"; rc=$?
    [[ "$rc" -eq 0 && "$out" != *"every skill would load twice"* \
          && "$(jq -c '.extraKnownMarketplaces // {} | length' "$leftover/$SLJ")" == 0 ]] \
        && pass "install removes the leftover declaration from ${leftover#"$SANDBOX"/}" \
        || fail "leftover declaration in ${leftover#"$SANDBOX"/} not removed (rc=$rc out=${out:0:400})"
    rm -f "$leftover/$SLJ"
done

# A root whose declaration points at ANOTHER checkout: drift, and install
# replaces the marketplace declaration with this checkout.
mkdir -p "$SANDBOX/elsewhere"
jq --arg p "$SANDBOX/elsewhere" '.extraKnownMarketplaces["agent-workspace"].source.path = $p' \
    "$ROOTS/a/$SLJ" > "$ROOTS/a/$SLJ.new" && mv "$ROOTS/a/$SLJ.new" "$ROOTS/a/$SLJ"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"registered root a ($ROOTS/a) is declared from another checkout, $SANDBOX/elsewhere"* ]] \
    && pass "--check reports a root whose plugin comes from another checkout, naming it" \
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
run >/dev/null
# ...and so is one in a root the installer skips (a workspace-toplevel
# root, a parent= instance inside its parent) or the workspace checkout
# itself: whether the plugin is there is unknowable, so install and --check
# say so.
for broken in "$WSC/projects/inner" "$ROOTS/fam/inst" "$WSC"; do
    mkdir -p "$broken/.claude"
    printf '{not json' > "$broken/$SLJ"
    out="$(run)"; rc=$?
    [[ "$rc" -eq 1 && "$out" == *"$broken/.claude/settings.local.json is not valid JSON"* \
          && "$(cat "$broken/$SLJ")" == '{not json' ]] \
        && pass "install fails on an unparseable settings.local.json where the plugin must not be (${broken#"$SANDBOX"/}), leaving it alone" \
        || fail "unparseable settings.local.json in ${broken#"$SANDBOX"/} passed install (rc=$rc out=${out:0:400})"
    out="$(run --check)"; rc=$?
    [[ "$rc" -eq 1 && "$out" == *"DRIFT: $broken/.claude/settings.local.json is not valid JSON"* ]] \
        && pass "--check reports the unparseable settings.local.json in ${broken#"$SANDBOX"/}" \
        || fail "--check missed the unparseable file in ${broken#"$SANDBOX"/} (rc=$rc out=${out:0:400})"
    rm -f "$broken/$SLJ"
done
rm -f "${ROOTS:?}/a/.claude/settings.local.json"

# Every `claude plugin` call runs with stdin closed: a CLI that stopped for
# a prompt must fail, not hang the installer or read the caller's input.
# Here the caller's stdin holds answers; the stub records any it reads.
STDIN_LOG="$SANDBOX/claude-stdin.log"
: > "$STDIN_LOG"
: > "$STUB_LOG"
stale_enable "$WSC/projects/inner"          # forces an uninstall + remove too
out="$(printf 'y\ny\ny\ny\ny\ny\ny\ny\n' | STUB_STDIN_LOG="$STDIN_LOG" run)"; rc=$?
if [[ "$rc" -eq 0 && ! -s "$STDIN_LOG" ]] && enabled_in "$ROOTS/a" \
   && grep -q "^$ROOTS/a|plugin install" "$STUB_LOG" && grep -q "^$WSC/projects/inner|plugin uninstall" "$STUB_LOG"; then
    pass "every claude plugin call (enable and remove) runs with stdin closed"
else
    fail "a claude plugin call could read the caller's stdin (rc=$rc read=$(cat "$STDIN_LOG") out=${out:0:300})"
fi
rm -f "${ROOTS:?}/a/.claude/settings.local.json" "$STDIN_LOG"

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
    HOME="$HOMEDIR" PATH="$NOCLI_PATH" CLAUDE_CONFIG_DIR='' AGENT_WORKSPACE_CLAUDE_BIN="$SANDBOX/no-such-claude" \
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
# ...and the same for a parent= instance's own declaration.
stale_enable "$ROOTS/fam/inst"
out="$(run_nocli)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"declared in parent= instance fam-i itself"*"by hand"* ]] \
   && enabled_in "$ROOTS/fam/inst" \
    && pass "without the claude CLI, install over a parent= instance's own declaration exits 1 and leaves it" \
    || fail "no-CLI install over an instance declaration (rc=$rc out=${out:0:400})"
rm -f "${ROOTS:?}/fam/inst/.claude/settings.local.json"
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

# --uninstall with the user-tier files all gone (root file, hook link,
# settings.json) but the plugin still enabled in registered roots: it is
# not "nothing installed", and the roots are cleaned.
run >/dev/null
mv "$SETTINGS" "$SANDBOX/settings.saved"
rm -f "$ROOT_FILE" "$HOOK_LINK"
out="$(run --uninstall)"; rc=$?
if [[ "$rc" -eq 0 && "$out" != *"nothing installed"* && "$out" == *"removed the agent-workspace plugin from $ROOTS/a"* ]] \
   && ! enabled_in "$ROOTS/a" && ! enabled_in "$ROOTS/fam"; then
    pass "--uninstall removes plugin enables from registered roots even with the user-tier files gone"
else
    fail "--uninstall with only plugin enables left (rc=$rc out=${out:0:400})"
fi
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"nothing installed"* ]] \
    && pass "--uninstall then says nothing is installed" \
    || fail "--uninstall with nothing left (rc=$rc out=${out:0:400})"
mv "$SANDBOX/settings.saved" "$SETTINGS"

# The CLI's machine-level marketplace record is keyed by name: one source
# per machine. --check flags a record naming another checkout, and nothing
# else about the file (absent, another marketplace, no path field).
KM="$HOMEDIR/.claude/plugins/known_marketplaces.json"
mkdir -p "$(dirname "$KM")"
run >/dev/null
root_calls_all() {  # CLI calls the stub saw from inside any registered root
    awk -F'|' -v p="$ROOTS/" 'index($1, p) == 1' "$STUB_LOG" | wc -l
}
km() {  # <agent-workspace source path, or "" for none>
    jq -n --arg p "$1" '{"claude-plugins-official": {source: {source: "github", repo: "x/y"}}}
        + (if $p == "" then {} else {"agent-workspace": {source: {source: "directory", path: $p}}} end)' > "$KM"
}
km "$SANDBOX/elsewhere"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"machine-level record of the agent-workspace marketplace ($KM) names another checkout, $SANDBOX/elsewhere"* ]] \
    && pass "--check flags a machine-level marketplace record naming another checkout" \
    || fail "foreign machine-level marketplace record not flagged (rc=$rc out=${out:0:400})"
for src in "$WSC_PHYS" "$SANDBOX/ws-link"; do
    km "$src"
    out="$(run --check)"; rc=$?
    [[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
        && pass "--check accepts a machine-level record of '${src#"$SANDBOX"/}' (this checkout)" \
        || fail "machine-level record '${src#"$SANDBOX"/}' wrongly flagged (rc=$rc out=${out:0:400})"
done
# No entry for it -- no entry, no file, or a file with no readable entry --
# is drift while roots are enabled from here: live case J saw an absent
# record leave every enabled root without the plugin.
for shape in entry file json; do
    case "$shape" in
        entry) km "" ;;
        file)  rm -f "$KM" ;;
        json)  printf '{not json' > "$KM" ;;
    esac
    out="$(run --check)"; rc=$?
    [[ "$rc" -eq 1 && "$out" == *"DRIFT: the claude CLI's machine-level record of the agent-workspace marketplace ($KM) has no entry for it"* ]] \
        && pass "--check flags a machine-level record with no entry for it (no $shape) while roots are enabled from here" \
        || fail "absent machine record (no $shape) not flagged (rc=$rc out=${out:0:400})"
done
mkdir -p "$(dirname "$KM")"
km ""
: > "$STUB_LOG"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(jq -r '.["agent-workspace"].source.path' "$KM")" == "$WSC_PHYS" && "$(grep -c '|plugin marketplace add ' "$STUB_LOG")" -eq 1 && "$(root_calls_all)" -eq 0 \
      && "$out" == *"has no entry for it, not this checkout -- taking it over once, before any project root"* ]] \
    && pass "install takes an absent machine-level record over before any root, with every root already enabled" \
    || fail "install over an absent record (rc=$rc km=$(tr -d '\n' < "$KM") out=${out:0:400})"
# ...and the read-back demands the record name this checkout: a CLI that
# exits 0 and leaves no entry is a failure, not "no longer foreign".
km ""
out="$(STUB_NO_KM=1 run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"reported success, but its machine-level record ($KM) has no entry for it, not this checkout"* ]] \
    && pass "a takeover that leaves the record with no entry fails the read-back" \
    || fail "entry-less read-back passed (rc=$rc out=${out:0:400})"
run >/dev/null
# Last install wins, as ONE machine-level step before any project root:
# install over a record naming another checkout takes the name over with a
# single `marketplace add`, run from a throwaway directory outside every
# root, and every root already enabled from here is then left alone (no CLI
# call there at all). --check clears by following its own advice. Every root
# is already enabled here -- the case that used to short-circuit.
root_files() {  # every enable root's settings.local.json, verbatim
    local r
    for r in a nogit fam fam-stray; do
        printf '%s=%s\n' "$r" "$(cat "$ROOTS/$r/$SLJ" 2>/dev/null || echo ABSENT)"
    done
}
root_calls() {  # CLI calls the stub saw from inside any registered root
    awk -F'|' -v p="$ROOTS/" 'index($1, p) == 1' "$STUB_LOG" | wc -l
}
km "$SANDBOX/elsewhere"
before="$(root_files)"
: > "$STUB_LOG"
out="$(run)"; rc=$?
adds="$(grep -c '|plugin marketplace add ' "$STUB_LOG")"
if [[ "$rc" -eq 0 && "$out" == *"names $SANDBOX/elsewhere, not this checkout -- taking it over once, before any project root"* \
      && "$adds" -eq 1 && "$(root_calls)" -eq 0 && "$(root_files)" == "$before" ]] \
   && [[ "$(jq -r '.["agent-workspace"].source.path' "$KM")" == "$WSC_PHYS" ]]; then
    pass "install takes a foreign machine-level record over with one add outside every root, leaving enabled roots alone"
else
    fail "machine-level takeover (rc=$rc adds=$adds root_calls=$(root_calls) km=$(cat "$KM") out=${out:0:500})"
fi
if [[ -z "$(ls -A "$INST_TMP")" ]]; then
    pass "the takeover's scratch directory is removed afterwards"
else
    fail "the takeover left files in its TMPDIR: $(ls -A "$INST_TMP")"
fi
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean after install took the machine-level record over" \
    || fail "--check still flags the machine-level record after install (rc=$rc out=${out:0:400})"

# The round-3 must-fix: a takeover that fails -- the CLI refuses the add, or
# exits 0 without repointing the record -- stops install before any project
# root. Every root's declaration survives byte for byte, the CLI never runs
# in any root, and install exits 1. Root a is made to need enabling too, so
# a per-root path would have run there had install carried on.
for mode in STUB_ADD_FAIL STUB_NO_KM; do
    km "$SANDBOX/elsewhere"
    rm -f "${ROOTS:?}/a/.claude/settings.local.json"
    before="$(root_files)"
    : > "$STUB_LOG"
    out="$(export "$mode=1"; run)"; rc=$?
    case "$mode" in
        STUB_ADD_FAIL) why="exited non-zero, so the machine-level record still names $SANDBOX/elsewhere" ;;
        STUB_NO_KM)    why="reported success, but its machine-level record ($KM) names $SANDBOX/elsewhere, not this checkout" ;;
    esac
    if [[ "$rc" -eq 1 && "$out" == *"$why"* && "$out" == *"stopped before touching any project root"* \
          && "$(root_files)" == "$before" && "$(root_calls)" -eq 0 && -z "$(ls -A "$INST_TMP")" ]]; then
        pass "a failed machine-level takeover ($mode) exits 1 with every root's declaration intact and no CLI call in any root"
    else
        fail "failed takeover ($mode) touched roots or passed (rc=$rc root_calls=$(root_calls) out=${out:0:500} diff=$(diff <(echo "$before") <(root_files)))"
    fi
done
out="$(run)"; rc=$?
[[ "$rc" -eq 0 ]] && enabled_in "$ROOTS/a" \
    && pass "once the CLI takes the add, install repoints the record and enables the remaining root" \
    || fail "install after a failed takeover (rc=$rc out=${out:0:400})"

# An interrupt during the takeover's CLI call removes the scratch directory
# too: TERM the installer while a slow stub `marketplace add` runs.
km "$SANDBOX/elsewhere"
: > "$STUB_LOG"
(
    unset CLAUDE_CONFIG_DIR
    HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" TMPDIR="$INST_TMP" STUB_ADD_SLEEP=2 \
        AGENT_WORKSPACE_CLAUDE_BIN="$STUB" exec bash "$INSTALL" >/dev/null 2>&1
) &
inst_pid=$!
for _ in $(seq 1 100); do
    grep -q '|plugin marketplace add ' "$STUB_LOG" && break
    sleep 0.1
done
saw_scratch="$(ls -A "$INST_TMP")"
kill -TERM "$inst_pid" 2>/dev/null
wait "$inst_pid"; rc=$?
[[ "$rc" -eq 143 && -n "$saw_scratch" && -z "$(ls -A "$INST_TMP")" ]] \
    && pass "a TERM during the takeover removes its scratch directory (exit 143)" \
    || fail "interrupted takeover (rc=$rc scratch-before='$saw_scratch' left='$(ls -A "$INST_TMP")')"
run >/dev/null

# The scratch directory must not sit in a git repository, where the CLI's
# local scope could resolve to that repository instead: install refuses
# before running the CLI at all.
mkdir -p "$SANDBOX/gittmp"
git -C "$SANDBOX/gittmp" init -q
km "$SANDBOX/elsewhere"
before="$(root_files)"
: > "$STUB_LOG"
out="$(RUN_TMPDIR="$SANDBOX/gittmp" run)"; rc=$?
if [[ "$rc" -eq 1 && "$out" == *"inside the git repository $SANDBOX/gittmp"* && ! -s "$STUB_LOG" \
      && "$(root_files)" == "$before" && "$(ls -A "$SANDBOX/gittmp")" == ".git" ]]; then
    pass "a takeover scratch directory inside a git repository is refused before any CLI call"
else
    fail "scratch-in-git-repo guard (rc=$rc log=$(cat "$STUB_LOG") left=$(ls -A "$SANDBOX/gittmp") out=${out:0:400})"
fi
rm -rf "${SANDBOX:?}/gittmp"

# The per-root step still runs local `marketplace remove` (here: removing a
# doubled declaration from a workspace-toplevel root). A CLI whose local
# remove also drops the machine record would undo the takeover while install
# exits 0; the read-back after the per-root step catches that and takes the
# record back -- or, when it cannot, exits 1.
km "$WSC_PHYS"
stale_enable "$WSC/projects/inner"
out="$(STUB_REMOVE_DROPS_KM=1 run)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"after the per-root step the machine-level record of the agent-workspace marketplace has no entry for it"* && "$out" == *"taking it over again, after the per-root step"* \
      && "$(jq -r '.["agent-workspace"].source.path' "$KM")" == "$WSC_PHYS" ]] \
    && pass "a machine record dropped by the per-root step's CLI calls is caught and taken back" \
    || fail "record lost in the per-root step (rc=$rc km=$(cat "$KM") out=${out:0:500})"
stale_enable "$WSC/projects/inner"
out="$(STUB_REMOVE_DROPS_KM=1 STUB_ADD_FAIL=1 run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"lost the machine-level record"*"could not be taken back"* ]] \
    && pass "a machine record the per-root step lost and cannot take back makes install exit 1" \
    || fail "unrecoverable lost record passed install (rc=$rc out=${out:0:500})"
run >/dev/null
# The round-5 must-fix, as reproduced: the record starts ABSENT, the first
# root's add creates it in the per-root step, and a later local remove (a
# leftover declaration in the workspace checkout itself) drops it again.
# Nothing named this checkout going in, so a before/after gate missed it:
# install exited 0 with an empty record and --check said "current".
km ""
rm -f "${ROOTS:?}/a/.claude/settings.local.json"
mkdir -p "$WSC/.claude"
jq -n --arg p "$WSC_PHYS" '{extraKnownMarketplaces: {"agent-workspace": {source: {source: "directory", path: $p}}}}' > "$WSC/$SLJ"
out="$(STUB_REMOVE_DROPS_KM=1 run)"; rc=$?
[[ "$rc" -eq 0 && "$(jq -r '.["agent-workspace"].source.path' "$KM")" == "$WSC_PHYS" && "$out" == *"taking it over again, after the per-root step"* ]] \
    && pass "a record created in the per-root step and dropped later in it is taken back" \
    || fail "absent-then-dropped record (rc=$rc km=$(tr -d '\n' < "$KM") out=${out:0:500})"
rm -f "${WSC:?}/.claude/settings.local.json"
run >/dev/null
km "$SANDBOX/elsewhere"    # the state the cases below start from

# With no root to enable from this checkout, install does not take the name:
# that would only move the other checkout's sessions onto this one's skills.
cp "$WSC/.agent/projects.local" "$SANDBOX/projects.local.saved"
printf 'inner single_project %s\ngone single_project %s\n' "$WSC/projects/inner" "$ROOTS/gone" > "$WSC/.agent/projects.local"
: > "$STUB_LOG"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$out" != *"taking it over"* && ! -s "$STUB_LOG" \
      && "$(jq -r '.["agent-workspace"].source.path' "$KM")" == "$SANDBOX/elsewhere" ]] \
    && pass "with no root to enable, install leaves a foreign machine-level record alone" \
    || fail "install took the record with no root to enable (rc=$rc log=$(cat "$STUB_LOG") out=${out:0:400})"
mv "$SANDBOX/projects.local.saved" "$WSC/.agent/projects.local"
# Nor when every root to be enabled has an unparseable settings.local.json:
# each fails in the per-root step whatever happens, so the name would move
# for nothing. Install exits 1 on those roots and leaves the record.
cp "$WSC/.agent/projects.local" "$SANDBOX/projects.local.saved"
printf 'a single_project %s\n' "$ROOTS/a" > "$WSC/.agent/projects.local"
cp "$ROOTS/a/$SLJ" "$SANDBOX/a-slj.saved"
printf '{not json' > "$ROOTS/a/$SLJ"
: > "$STUB_LOG"
out="$(run)"; rc=$?
[[ "$rc" -eq 1 && "$out" != *"taking it over"* && ! -s "$STUB_LOG" \
      && "$(jq -r '.["agent-workspace"].source.path' "$KM")" == "$SANDBOX/elsewhere" ]] \
    && pass "with every root to enable unparseable, install leaves a foreign machine-level record alone" \
    || fail "install took the record for roots that cannot succeed (rc=$rc log=$(cat "$STUB_LOG") out=${out:0:400})"
mv "$SANDBOX/a-slj.saved" "$ROOTS/a/$SLJ"
mv "$SANDBOX/projects.local.saved" "$WSC/.agent/projects.local"

# No claude CLI: the takeover cannot run. Install says so and carries on
# (a no-CLI machine enables nothing either), and an already-enabled root is
# reported as what it is.
out="$(run_nocli)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"taking it over needs the claude CLI, which is not on PATH"* \
      && "$out" == *"plugin already enabled: $ROOTS/a"* && "$out" != *"not enabling the agent-workspace plugin in $ROOTS/a"* \
      && "$(jq -r '.["agent-workspace"].source.path' "$KM")" == "$SANDBOX/elsewhere" ]] \
    && pass "without the claude CLI, install notes that the takeover needs it, and calls enabled roots enabled" \
    || fail "no-CLI install over a foreign machine-level record (rc=$rc out=${out:0:500})"
# ...and --check, whose "re-run this installer" could not clear it there,
# says what is needed instead and stays green, as for an unenabled root.
out="$(run_nocli --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"note: the claude CLI's machine-level record"*"names another checkout, $SANDBOX/elsewhere"*"taking it over needs the claude CLI, which is not on PATH"* \
      && "$out" != *"DRIFT"* ]] \
    && pass "without the claude CLI, --check notes the foreign machine-level record with advice that says the CLI is needed" \
    || fail "no-CLI --check over a foreign machine-level record (rc=$rc out=${out:0:500})"
# The same without the CLI when the record has NO entry for it (no entry,
# or no file): install's 6a NOTE and --check's note name the absent entry,
# not another checkout, and both stay green like the foreign case.
for shape in entry file; do
    case "$shape" in
        entry) km "" ;;
        file)  rm -f "$KM" ;;
    esac
    out="$(run_nocli)"; rc=$?
    [[ "$rc" -eq 0 && "$out" == *"NOTE: the claude CLI's machine-level record of the agent-workspace marketplace has no entry for it, not this checkout -- taking it over needs the claude CLI, which is not on PATH"* \
          && "$out" != *"names another checkout"* && "$out" == *"plugin already enabled: $ROOTS/a"* ]] \
        && pass "without the claude CLI, install notes an absent machine-level record (no $shape) and that the takeover needs the CLI" \
        || fail "no-CLI install over an absent machine-level record, no $shape (rc=$rc out=${out:0:500})"
    out="$(run_nocli --check)"; rc=$?
    [[ "$rc" -eq 0 && "$out" == *"note: the claude CLI's machine-level record of the agent-workspace marketplace ($KM) has no entry for it"*"taking it over needs the claude CLI, which is not on PATH"* \
          && "$out" != *"DRIFT"* ]] \
        && pass "without the claude CLI, --check notes an absent machine-level record (no $shape) with advice that says the CLI is needed" \
        || fail "no-CLI --check over an absent machine-level record, no $shape (rc=$rc out=${out:0:500})"
done
mkdir -p "$(dirname "$KM")"
km "$SANDBOX/elsewhere"
run >/dev/null
# CLAUDE_CONFIG_DIR moves the CLI's records: with it set, the record read
# (and taken over) is the one under it, and a stale one in ~/.claude is
# irrelevant -- reading ~/.claude there made the takeover's read-back fail
# on every run. The rest of the user tier stays in ~/.claude, with a note.
CFG="$SANDBOX/cfg"
mkdir -p "$CFG/plugins"
jq -n --arg p "$SANDBOX/elsewhere" '{"agent-workspace": {source: {source: "directory", path: $p}}}' > "$CFG/plugins/known_marketplaces.json"
km "$WSC_PHYS"
out="$(RUN_CFG="$CFG" run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"($CFG/plugins/known_marketplaces.json) names another checkout, $SANDBOX/elsewhere"* \
      && "$out" == *"NOTE: CLAUDE_CONFIG_DIR is set ($CFG)"* ]] \
    && pass "with CLAUDE_CONFIG_DIR set, --check reads the CLI's record there (and notes the rest of the tier is in ~/.claude)" \
    || fail "--check with CLAUDE_CONFIG_DIR (rc=$rc out=${out:0:500})"
km "$SANDBOX/elsewhere"
out="$(RUN_CFG="$CFG" run)"; rc=$?
[[ "$rc" -eq 0 && "$(jq -r '.["agent-workspace"].source.path' "$CFG/plugins/known_marketplaces.json")" == "$WSC_PHYS" \
      && "$(jq -r '.["agent-workspace"].source.path' "$KM")" == "$SANDBOX/elsewhere" ]] \
    && pass "with CLAUDE_CONFIG_DIR set, install takes over the record there, and a stale ~/.claude one does not block it" \
    || fail "install with CLAUDE_CONFIG_DIR (rc=$rc out=${out:0:500})"
out="$(RUN_CFG="$CFG" run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" != *"DRIFT"* ]] \
    && pass "with CLAUDE_CONFIG_DIR set, --check is clean after the takeover there" \
    || fail "--check with CLAUDE_CONFIG_DIR after install (rc=$rc out=${out:0:500})"
rm -rf "${CFG:?}"
km "$WSC_PHYS"

# With no root enabled from this checkout, no session of this checkout's
# loads the record and install has no root to repoint it from: not drift.
saved_slj="$SANDBOX/saved-slj"
mkdir -p "$saved_slj"
for r in a nogit fam fam-stray; do
    [[ -f "$ROOTS/$r/$SLJ" ]] && mv "$ROOTS/$r/$SLJ" "$saved_slj/$r.json"
done
out="$(run --check)"
[[ "$out" != *"machine-level record"* ]] \
    && pass "--check does not flag the machine-level record while no root has the plugin from this checkout" \
    || fail "machine-level record flagged with no root enabled from this checkout (out=${out:0:400})"
for r in a nogit fam fam-stray; do
    [[ -f "$saved_slj/$r.json" ]] && mv "$saved_slj/$r.json" "$ROOTS/$r/$SLJ"
done
rm -rf "$saved_slj"
rm -f "$KM"

# --uninstall leaves another checkout's plugin alone: a second checkout's
# uninstall must not take away the first's. This checkout's go as usual.
run >/dev/null
foreign_enable "$ROOTS/a"
before="$(cat "$ROOTS/a/$SLJ")"
: > "$STUB_LOG"
out="$(run --uninstall)"; rc=$?
if [[ "$rc" -eq 0 && "$out" == *"plugin in $ROOTS/a is declared from another checkout ($SANDBOX/elsewhere) -- left"* \
      && "$(cat "$ROOTS/a/$SLJ")" == "$before" ]] && ! grep -q "^$ROOTS/a|" "$STUB_LOG" && ! enabled_in "$ROOTS/fam"; then
    pass "--uninstall leaves a root declared from another checkout untouched, and still removes its own"
else
    fail "--uninstall and another checkout's plugin (rc=$rc out=${out:0:400} log=$(cat "$STUB_LOG"))"
fi
rm -f "${ROOTS:?}/a/.claude/settings.local.json"

# A declaration whose source is no longer on disk is no checkout's to
# remove any more (its --uninstall cannot run): it is stale, not foreign,
# so --check calls it not enabled from here and --uninstall removes it.
run >/dev/null
mkdir -p "$ROOTS/a/.claude"
jq -n --arg p "$SANDBOX/deleted-checkout" '{enabledPlugins: {"agent-workspace@agent-workspace": true},
    extraKnownMarketplaces: {"agent-workspace": {source: {source: "directory", path: $p}}}}' > "$ROOTS/a/$SLJ"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"plugin not enabled from this checkout in registered root a"* \
      && "$out" != *"declared from another checkout"* ]] \
    && pass "--check treats a declaration whose source is gone as stale, not another checkout's" \
    || fail "orphaned declaration misreported (rc=$rc out=${out:0:400})"
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"removed the agent-workspace plugin from $ROOTS/a"* \
      && "$(jq -c '(.enabledPlugins // {} | length) + (.extraKnownMarketplaces // {} | length)' "$ROOTS/a/$SLJ")" == 0 ]] \
    && pass "--uninstall removes a declaration whose source is no longer on disk" \
    || fail "orphaned declaration left by --uninstall (rc=$rc out=${out:0:400})"
rm -f "${ROOTS:?}/a/.claude/settings.local.json"

# ...but another checkout's plugin in a root inside THIS checkout's tree
# still doubles every skill there: --check flags it and install removes it.
run >/dev/null
foreign_enable "$WSC/projects/inner"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"enabled in inner"*"loads twice"* ]] \
    && pass "--check flags another checkout's plugin in a workspace-toplevel root" \
    || fail "foreign enable in a skipped root not flagged (rc=$rc out=${out:0:400})"
run >/dev/null
[[ ! -e "$WSC/projects/inner/$SLJ" ]] || [[ "$(jq -c '(.enabledPlugins // {} | length) + (.extraKnownMarketplaces // {} | length)' "$WSC/projects/inner/$SLJ")" == 0 ]] \
    && pass "install removes another checkout's plugin from a workspace-toplevel root" \
    || fail "foreign enable in a skipped root survived install ($(cat "$WSC/projects/inner/$SLJ"))"
rm -f "${WSC:?}/projects/inner/.claude/settings.local.json"

# --uninstall over an unparseable settings.local.json: it cannot tell
# whether the plugin is there, so it says so, exits 1, and leaves the file.
run >/dev/null
printf '{not json' > "$ROOTS/a/$SLJ"
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"$ROOTS/a/.claude/settings.local.json is not valid JSON"* \
      && "$(cat "$ROOTS/a/$SLJ")" == '{not json' ]] \
    && pass "--uninstall reports an unparseable settings.local.json, exits 1 and leaves it alone" \
    || fail "--uninstall over an unparseable settings.local.json (rc=$rc out=${out:0:400})"
rm -f "${ROOTS:?}/a/.claude/settings.local.json"

# ------------------------------------------------- --disable-root <name> ---
# One registered root (#332: register_project.sh runs it before removing a
# registry line). It treats that root as --uninstall treats each: the
# plugin goes where this checkout declared it; another checkout's
# declaration, a parent= instance's parent and the rest of ~/.claude stay.
run >/dev/null
enabled_in "$ROOTS/a" && enabled_in "$ROOTS/fam" && enabled_in "$ROOTS/pp/inst" \
    || fail "--disable-root setup: roots not enabled before the cases"
cp "$SETTINGS" "$SANDBOX/settings.before-disable"
: > "$STUB_LOG"
out="$(run --disable-root a)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"removed the agent-workspace plugin from $ROOTS/a"* ]] && ! enabled_in "$ROOTS/a" \
      && [[ "$(jq -c '(.enabledPlugins // {} | length) + (.extraKnownMarketplaces // {} | length)' "$ROOTS/a/$SLJ")" == 0 ]] \
    && pass "--disable-root removes the plugin from that root" \
    || fail "--disable-root a (rc=$rc out=${out:0:400} slj=$(cat "$ROOTS/a/$SLJ" 2>/dev/null))"
enabled_in "$ROOTS/fam" && enabled_in "$ROOTS/pp/inst" && ! grep -qv "^$ROOTS/a|" "$STUB_LOG" \
    && pass "--disable-root leaves every other root alone (the CLI ran only in that root)" \
    || fail "--disable-root touched another root ($(cat "$STUB_LOG"))"
cmp -s "$SETTINGS" "$SANDBOX/settings.before-disable" && [[ -f "$ROOT_FILE" ]] \
    && pass "--disable-root leaves ~/.claude (settings.json, the root file) unchanged" \
    || fail "--disable-root changed ~/.claude"
: > "$STUB_LOG"
out="$(run --disable-root a)"; rc=$?
[[ "$rc" -eq 0 && ! -s "$STUB_LOG" ]] \
    && pass "--disable-root on a root without the plugin is a no-op, with no CLI call" \
    || fail "second --disable-root a (rc=$rc log=$(cat "$STUB_LOG") out=${out:0:300})"
foreign_enable "$ROOTS/a"
out="$(run --disable-root a)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"declared from another checkout"* \
      && "$(jq -r '.extraKnownMarketplaces["agent-workspace"].source.path' "$ROOTS/a/$SLJ")" == "$SANDBOX/elsewhere" ]] \
    && pass "--disable-root leaves another checkout's declaration alone, with a note" \
    || fail "--disable-root over a foreign declaration (rc=$rc out=${out:0:400})"
rm -f "${ROOTS:?}/a/.claude/settings.local.json"
# A CLI whose local remove drops the machine-level record: the other roots
# enabled from here would lose the plugin, so the record is taken back.
run >/dev/null
out="$(STUB_REMOVE_DROPS_KM=1 run --disable-root a)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"taking it over back, after removing the plugin from a"* \
      && "$(jq -r '.["agent-workspace"].source.path' "$KM")" == "$WSC_PHYS" ]] && ! enabled_in "$ROOTS/a" \
    && pass "--disable-root takes the machine-level record back when the local remove drops it" \
    || fail "--disable-root with a dropped record (rc=$rc km=$(tr -d '\n' < "$KM" 2>/dev/null) out=${out:0:500})"
: > "$STUB_LOG"
out="$(run --disable-root fam-i)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"parent root provides the plugin"* && ! -s "$STUB_LOG" ]] && enabled_in "$ROOTS/fam" \
    && pass "--disable-root on a parent= instance leaves its parent's plugin, and runs no CLI" \
    || fail "--disable-root fam-i (rc=$rc log=$(cat "$STUB_LOG") out=${out:0:400})"
out="$(run --disable-root gone)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"is not on disk"* ]] \
    && pass "--disable-root on a root not on disk is a note" \
    || fail "--disable-root gone (rc=$rc out=${out:0:300})"
out="$(run --disable-root nosuch)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"'nosuch' is not registered"* ]] \
    && pass "--disable-root on an unregistered name exits 1" \
    || fail "--disable-root nosuch (rc=$rc out=${out:0:300})"
out="$(run --disable-root)"; rc=$?
[[ "$rc" -eq 2 && "$out" == *"needs a registered project name"* ]] \
    && pass "--disable-root without a name is a usage error" \
    || fail "--disable-root without a name (rc=$rc out=${out:0:300})"
out="$(run --disable-root a --uninstall)"; rc=$?
[[ "$rc" -eq 2 && "$out" == *"mutually exclusive"* ]] \
    && pass "--disable-root and another mode are mutually exclusive" \
    || fail "--disable-root with --uninstall (rc=$rc out=${out:0:300})"
rm -f "$SANDBOX/settings.before-disable"
run >/dev/null

rm -f "${WSC:?}/.agent/projects.local" "${SANDBOX:?}/ws-link"
rm -rf "${WSC:?}/.git" "${WSC:?}/projects"
run >/dev/null

echo ""
echo "test_user_tier_install: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
