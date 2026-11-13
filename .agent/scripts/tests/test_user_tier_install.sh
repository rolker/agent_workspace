#!/usr/bin/env bash
# .agent/scripts/tests/test_user_tier_install.sh
# Tests for .agent/scripts/user_tier_install.sh (#317, #265 PR 3; #345):
# idempotent install, the not-installed / --require split, drift detection
# (foreign entry, missing entry, stale symlink, retired hook entry, legacy
# skill symlink, a hook left by a deleted checkout), hook commands
# recognised by path after the claude CLI rewrites settings.json (#394),
# mixed entries, skill selection from session_scope frontmatter, the
# plugin manifest generator, the plugin enabled once at user scope and the
# migration of per-root entries (ADR-0018, #446), and uninstall.
#
# Hermetic: HOME is redirected to a sandbox for every invocation, so the
# real ~/.claude is never read or written. The installer is run against a
# COPY of the workspace checkout -- with the machine's own registry
# (.agent/projects.local) removed from the copy -- so the test can add and
# remove skills and registered roots without touching the real ones. The
# claude CLI is NEVER run: every invocation points AGENT_WORKSPACE_CLAUDE_BIN
# at a stub that records its argv and edits the sandbox user settings or a
# root's settings.local.json the way the real CLI does, and a `claude` on
# the test's PATH is the same stub. No network, no gh.
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

# The claude stub. Records "<cwd>|<argv>" per call, then edits settings as
# `claude plugin ... --scope <scope>` would: with `--scope user`, the CLI's
# user settings (${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json); otherwise
# the cwd's .claude/settings.local.json. `install` and `uninstall` also
# keep the CLI's record of installs (plugins/installed_plugins.json: the
# plugin's array of {scope, projectPath} objects, projectPath for local
# scope only; a second install of the same scope and path replaces its
# object), and `marketplace add` records its source in
# plugins/known_marketplaces.json, the CLI's machine-level record keyed by
# name (left alone when it is not JSON).
# STUB_FAIL=1 makes it exit 1; STUB_NOOP=1 makes it exit 0 having written
# nothing (a CLI that claims success but did not enable anything);
# STUB_STDIN_LOG=<file> makes it append any line it can read from stdin there
# (a CLI that stops for a prompt would read exactly that); STUB_NO_KM=1
# makes `marketplace add` skip the machine-level record (a CLI that does
# not repoint it); STUB_ADD_FAIL=1 makes `marketplace add` alone exit 1
# having written nothing; STUB_REMOVE_DROPS_KM=1 makes a local `marketplace
# remove` also delete the machine-level entry, and STUB_LOCAL_DROPS_USER=1
# makes a local `uninstall` also drop the user-scope enable (a CLI whose
# local calls reach further than their scope); STUB_LOCAL_NOOP=1 makes
# every local-scope call exit 0 having written nothing. STUB_ADD_SLEEP=<s>
# makes `marketplace add` sleep first (time to interrupt the installer).
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
scope=local prev=""
for a in "$@"; do [[ "$prev" == --scope ]] && scope="$a"; prev="$a"; done
[[ "$scope" == local && -n "${STUB_LOCAL_NOOP:-}" ]] && exit 0
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [[ "$scope" == user ]]; then
    f="$cfg/settings.json"
    mkdir -p "$cfg"
else
    f=.claude/settings.local.json
    mkdir -p .claude
fi
[[ -f "$f" ]] || echo '{}' > "$f"
case "$1 $2 ${3:-}" in
    "plugin marketplace add")    filter='.extraKnownMarketplaces["agent-workspace"] = {source: {source: "directory", path: $a}}'; arg="$4" ;;
    "plugin marketplace remove") filter='del(.extraKnownMarketplaces["agent-workspace"])'; arg="" ;;
    "plugin install "*)          filter='.enabledPlugins[$a] = true'; arg="$3" ;;
    "plugin uninstall "*)        filter='del(.enabledPlugins[$a])'; arg="$3" ;;
    *) exit 0 ;;
esac
jq --arg a "$arg" "$filter" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
ip="$cfg/plugins/installed_plugins.json"
case "$2" in
    install|uninstall)
        mkdir -p "$(dirname "$ip")"
        [[ -f "$ip" ]] || echo '{"version": 2, "plugins": {}}' > "$ip"
        pp=""; [[ "$scope" == local ]] && pp="$PWD"
        if [[ "$2" == install ]]; then
            jq --arg id "$3" --arg s "$scope" --arg p "$pp" \
                '.plugins[$id] = ([(.plugins[$id] // [])[] | select((.scope == $s and ($p == "" or .projectPath == $p)) | not)]
                    + [{scope: $s} + (if $p == "" then {} else {projectPath: $p} end)])' \
                "$ip" > "$ip.tmp" && mv "$ip.tmp" "$ip"
        else
            jq --arg id "$3" --arg s "$scope" --arg p "$pp" \
                '.plugins[$id] = [(.plugins[$id] // [])[] | select((.scope == $s and ($p == "" or .projectPath == $p)) | not)]' \
                "$ip" > "$ip.tmp" && mv "$ip.tmp" "$ip"
        fi ;;
esac
if [[ "$scope" == local && "$2" == uninstall && -n "${STUB_LOCAL_DROPS_USER:-}" ]]; then
    jq 'del(.enabledPlugins["agent-workspace@agent-workspace"])' "$cfg/settings.json" > "$cfg/settings.json.tmp" \
        && mv "$cfg/settings.json.tmp" "$cfg/settings.json"
fi
km="$cfg/plugins/known_marketplaces.json"
if [[ "$2 $3" == "marketplace remove" && "$scope" == local && -n "${STUB_REMOVE_DROPS_KM:-}" ]]; then
    [[ -f "$km" ]] && jq 'del(.["agent-workspace"])' "$km" > "$km.tmp" 2>/dev/null && mv "$km.tmp" "$km"
fi
if [[ "$2 $3" == "marketplace remove" && "$scope" == user && -f "$km" ]]; then
    jq 'del(.["agent-workspace"])' "$km" > "$km.tmp" 2>/dev/null && mv "$km.tmp" "$km"
fi
if [[ "$2 $3" == "marketplace add" && -z "${STUB_NO_KM:-}" ]]; then
    mkdir -p "$(dirname "$km")"
    [[ -f "$km" ]] || echo '{}' > "$km"
    jq --arg a "$arg" '.["agent-workspace"] = {source: {source: "directory", path: $a}}' "$km" > "$km.tmp" 2>/dev/null \
        && mv "$km.tmp" "$km" || rm -f "$km.tmp"
fi
STUBEOF
chmod +x "$STUB"
: > "$STUB_LOG"
# The stub is the only `claude` this test can reach: first on PATH for
# every command below, so an installer call that forgets
# AGENT_WORKSPACE_CLAUDE_BIN still never runs the real CLI.
PATH="$STUB_BIN:$PATH"
export PATH

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
[[ "$(grep -c -- '--scope user$' "$STUB_LOG")" -eq 2 && "$(grep -c -v -- '--scope user$' "$STUB_LOG")" -eq 0 ]] \
    && pass "install enables the plugin with two claude CLI calls, both at user scope" \
    || fail "install's claude CLI calls ($(cat "$STUB_LOG"))"

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

# (i2) a dead command in an entry marked with its own checkout: attributable
# to this installer, so a plain install removes it and says so.
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

# (i3) a dead command in an entry marked with ANOTHER checkout: the marker
# says nothing about the command's own directory, so it is handled like an
# unmarked dead command -- reported with the --force remedy, named and kept
# by a plain install, removed by --force.
OTHER_MARKER="$SANDBOX/marker-of-another-ws"
GONE_OTHER_HOOK="$SANDBOX/gone-under-other-marker/.claude/hooks/log-tool-use.sh"
jq --arg t "$OTHER_MARKER" --arg c "$GONE_OTHER_HOOK" '
    .hooks.PreToolUse += [{_agent_workspace: $t, hooks: [{type: "command", command: $c}]}]' \
    "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"not on disk: $GONE_OTHER_HOOK"*"remove it with: $FORCE_REMEDY"* \
   && "$out" != *"$GONE_OTHER_HOOK (re-run the installer to remove it)"* ]] \
    && pass "--check reports a dead command marked with another checkout like an unmarked one (--force remedy)" \
    || fail "dead command under another checkout's marker (rc=$rc out=$out)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(n_holding PreToolUse "$GONE_OTHER_HOOK")" -eq 1 \
   && "$out" == *"left in place: hook command $GONE_OTHER_HOOK"*"remove it with: $FORCE_REMEDY"* ]] \
    && pass "a plain install keeps a dead command marked with another checkout and names it" \
    || fail "a plain install over a dead command under another checkout's marker (rc=$rc held=$(n_holding PreToolUse "$GONE_OTHER_HOOK") out=${out:0:600})"
out="$(run --force)"; rc=$?
[[ "$rc" -eq 0 && "$(n_holding PreToolUse "$GONE_OTHER_HOOK")" -eq 0 \
   && "$out" == *"removed hook command $GONE_OTHER_HOOK"*"kept at "* ]] \
    && pass "--force removes it and names it" \
    || fail "--force over a dead command under another checkout's marker (rc=$rc held=$(n_holding PreToolUse "$GONE_OTHER_HOOK") out=${out:0:600})"
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

# (s) a PreToolUse or SessionStart value that is not an array: install
# would have to replace it (and drop what it holds) to add its entry, so it
# refuses with nothing changed, and --check says so.
for shape in '.hooks.PreToolUse = {"a": 1}' '.hooks.SessionStart = "not-an-array"' '.hooks = [1]'; do
    cp "$SETTINGS" "$SANDBOX/shape-clean.json"
    jq "$shape" "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    cp "$SETTINGS" "$SANDBOX/shape-before.json"
    rm -f "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*
    out="$(run)"; rc=$?
    [[ "$rc" -eq 1 && "$out" == *"refusing to rewrite"*"nothing changed"*"not an "* ]] \
        && cmp -s "$SETTINGS" "$SANDBOX/shape-before.json" && [[ "$(n_backups)" -eq 0 ]] \
        && pass "install refuses ($shape), settings.json unchanged and no backup" \
        || fail "install over ($shape) (rc=$rc backups=$(n_backups) out=${out:0:300})"
    out="$(run --check)"; rc=$?
    [[ "$rc" -eq 1 && "$out" == *"not an "*"the installer refuses to rewrite it"* ]] \
        && pass "--check reports ($shape)" \
        || fail "--check over ($shape) (rc=$rc out=$out)"
    cp "$SANDBOX/shape-clean.json" "$SETTINGS"
done
rm -f "$SANDBOX/shape-clean.json" "$SANDBOX/shape-before.json"

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
run2() { HOME="$HOMEDIR" CLAUDE_CONFIG_DIR='' PATH="$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" TMPDIR="$INST_TMP" \
    AGENT_WORKSPACE_CLAUDE_BIN="$STUB" bash "$WSC2/.agent/scripts/user_tier_install.sh" "$@" 2>&1; }

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

# A failed rename onto the dotfiles file is a failed write: install and
# --uninstall exit 1 saying nothing changed in it, the dotfiles file and the
# link stay as they were, and neither the staging file beside the dotfiles
# file nor the mktemp file in ~/.claude is left behind. An `mv` shim fails
# only the rename onto the dotfiles file.
mk_fail_shim "$SANDBOX/dotfiles-mv-shim" mv '*/dotfiles/claude-settings.json'
no_strays() {
    ! compgen -G "$DOTFILES/claude-settings.json.agent-workspace.*" >/dev/null \
        && ! compgen -G "$HOMEDIR/.claude/.settings.json.*" >/dev/null
}
drop_a_rule
cp "$DOTFILES/claude-settings.json" "$SANDBOX/dotfiles-before.json"
for mode in install --uninstall; do
    if [[ "$mode" == install ]]; then
        out="$(RUN_PATH_PREFIX="$SANDBOX/dotfiles-mv-shim" run)"; rc=$?
    else
        out="$(RUN_PATH_PREFIX="$SANDBOX/dotfiles-mv-shim" run --uninstall)"; rc=$?
    fi
    [[ "$rc" -eq 1 && "$out" == *"failed to write $SETTINGS -- nothing changed"* && "$out" != *"user tier removed"* ]] \
        && pass "$mode over a symlinked settings.json whose rename fails exits 1, saying nothing changed" \
        || fail "$mode with a failed rename onto the dotfiles file (rc=$rc out=${out:0:400})"
    cmp -s "$DOTFILES/claude-settings.json" "$SANDBOX/dotfiles-before.json" \
        && [[ -L "$SETTINGS" && "$(readlink "$SETTINGS")" == "$link_target_before" ]] \
        && pass "...the dotfiles file and the link unchanged" \
        || fail "$mode with a failed rename changed the dotfiles file or the link ($(readlink "$SETTINGS"))"
    no_strays \
        && pass "...and no staging or temporary file left behind" \
        || fail "$mode with a failed rename left: $(ls -a "$DOTFILES" "$HOMEDIR/.claude" | tr '\n' ' ')"
done
[[ "$(cat "$ROOT_FILE" 2>/dev/null)" == "$WSC" && -L "$HOOK_LINK" ]] \
    && pass "the failed --uninstall left the root file and the SessionStart link" \
    || fail "the failed --uninstall removed the root file or the link"
cp "$SANDBOX/dotfiles-before.json" "$DOTFILES/claude-settings.json"
rm -f "$SANDBOX/dotfiles-before.json" "$HOMEDIR"/.claude/settings.json.agent-workspace-backup.*
run >/dev/null

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

# ------------------------------------------------ plugin, at user scope ---
# ADR-0018 as amended by #446: the plugin is enabled once, at user scope,
# and nothing is written into a project root; the per-root generation's
# entries are migrated. Fresh HOME, so earlier sections' state cannot
# leak in. Every root here is a sandbox directory; the claude stub stands
# in for the CLI.
rm -rf "$HOMEDIR"
mkdir -p "$HOMEDIR"
: > "$STUB_LOG"
rm -rf "$INST_TMP" && mkdir -p "$INST_TMP"
PID="agent-workspace@agent-workspace"
SLJ=.claude/settings.local.json
git -C "$WSC" init -q 2>/dev/null
WSC_PHYS="$(cd "$WSC" && pwd -P)"
KM_FILE="$HOMEDIR/.claude/plugins/known_marketplaces.json"
IP_FILE="$HOMEDIR/.claude/plugins/installed_plugins.json"
ROOTS="$SANDBOX/roots"
mkdir -p "$ROOTS/a" "$ROOTS/nogit"
git -C "$ROOTS/a" init -q
# A root's own local settings, unrelated to the plugin: must stay as it is.
mkdir -p "$ROOTS/a/.claude"
echo '{"permissions": {"allow": ["Bash(make *)"]}}' > "$ROOTS/a/$SLJ"
cat > "$WSC/.agent/projects.local" <<REG
a        single_project  $ROOTS/a
nogit    single_project  $ROOTS/nogit
REG
user_on() {  # the plugin enabled at user scope from this checkout?
    jq -e --arg id "$PID" --arg p "$WSC_PHYS" '.enabledPlugins[$id] == true
        and .extraKnownMarketplaces["agent-workspace"].source.path == $p' "$SETTINGS" >/dev/null 2>&1
}
km_ours() {
    jq -e --arg p "$WSC_PHYS" '.["agent-workspace"].source.path == $p' "$KM_FILE" >/dev/null 2>&1
}
legacy_enable() {  # <root> [<marketplace source>]: a per-root entry as the old installer left it
    mkdir -p "$1/.claude"
    [[ -f "$1/$SLJ" ]] && jq -e . "$1/$SLJ" >/dev/null 2>&1 || echo '{}' > "$1/$SLJ"
    jq --arg p "${2:-$WSC_PHYS}" --arg id "$PID" '.enabledPlugins[$id] = true
        | .extraKnownMarketplaces["agent-workspace"] = {source: {source: "directory", path: $p}}' \
        "$1/$SLJ" > "$1/$SLJ.tmp" && mv "$1/$SLJ.tmp" "$1/$SLJ"
}
has_entry() {  # <root>: does its settings.local.json name the plugin at all?
    jq -e --arg id "$PID" '(.enabledPlugins // {} | has($id)) or (.extraKnownMarketplaces // {} | has("agent-workspace"))' \
        "$1/$SLJ" >/dev/null 2>&1
}
roots_sum() { find "$ROOTS" -path '*/.git' -prune -o -type f -print0 | sort -z | xargs -0 cksum 2>/dev/null; }
log_since() { tail -n +"$(( $1 + 1 ))" "$STUB_LOG"; }
n_log() { wc -l < "$STUB_LOG"; }

# A clean HOME: exactly two CLI calls, both at user scope, from a throwaway
# directory under TMPDIR (removed after), and no root's files touched.
before_roots="$(roots_sum)"
out="$(run)"; rc=$?
calls="$(cut -d'|' -f2 "$STUB_LOG" | tr '\n' ';')"
[[ "$rc" -eq 0 && "$calls" == "plugin marketplace add $WSC_PHYS --scope user;plugin install $PID --scope user;" ]] \
    && pass "a clean install runs the CLI exactly twice: marketplace add and install, both --scope user" \
    || fail "clean install CLI calls (rc=$rc calls=$calls out=${out:0:400})"
bad_cwd="$(cut -d'|' -f1 "$STUB_LOG" | grep -v "^$INST_TMP/agent-workspace-plugin\." || true)"
[[ -z "$bad_cwd" && -z "$(ls -A "$INST_TMP")" ]] \
    && pass "...each from a throwaway directory under TMPDIR, removed afterwards" \
    || fail "...CLI cwd not a scratch directory, or one left behind (cwd: $bad_cwd; left: $(ls -A "$INST_TMP"))"
user_on && km_ours \
    && pass "...and the user settings and the machine-level record name this checkout" \
    || fail "...the user-scope entries or the machine record are wrong ($(jq -c '{enabledPlugins, extraKnownMarketplaces}' "$SETTINGS"); km: $(cat "$KM_FILE" 2>/dev/null))"
[[ "$(roots_sum)" == "$before_roots" && ! -e "$ROOTS/nogit/.claude" ]] \
    && pass "...and no registered root's files are written or changed" \
    || fail "...a registered root changed"
[[ "$out" == *"enabled the agent-workspace plugin at user scope"* ]] \
    && pass "...and it says so" || fail "...install did not say it enabled the plugin (out=${out:0:300})"

# A re-run: no CLI call, nothing changed; --check --require clean, before
# and after the CLI's own rewrite of settings.json (#394).
cp "$SETTINGS" "$SANDBOX/us-before.json"
n0="$(n_log)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(n_log)" -eq "$n0" ]] && cmp -s "$SETTINGS" "$SANDBOX/us-before.json" \
    && pass "a re-run makes no CLI call and leaves settings.json byte-identical" \
    || fail "re-run (rc=$rc calls: $(log_since "$n0"); out=${out:0:300})"
[[ "$out" == *"already enabled at user scope from this checkout -- no claude CLI call"* ]] \
    && pass "...and says the plugin is already enabled" || fail "...re-run message (out=${out:0:300})"
out="$(run --check --require)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check --require after install: clean" || fail "--check --require after install (rc=$rc out=$out)"
cli_rewrite
n0="$(n_log)"
out="$(run --check --require)"; rc=$?
[[ "$rc" -eq 0 && "$(n_log)" -eq "$n0" ]] \
    && pass "--check --require stays clean after the CLI rewrites settings.json, and runs no CLI" \
    || fail "--check after a CLI rewrite (rc=$rc out=$out calls: $(log_since "$n0"))"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(n_log)" -eq "$n0" ]] \
    && pass "a re-run after the CLI's rewrite makes no CLI call" \
    || fail "re-run after a CLI rewrite (rc=$rc calls: $(log_since "$n0"))"
rm -f "$SANDBOX/us-before.json"

# The workspace checkout's tracked .claude/settings.json sets the plugin to
# false (so a session at its root lists each skill once, bare). The real
# file is pinned here, so removing the entry fails CI; --check calls a
# copy without it drift, and the installer never writes it.
jq -e --arg id "$PID" '.enabledPlugins[$id] == false' "$WS_ROOT/.claude/settings.json" >/dev/null \
    && pass "the checkout's tracked .claude/settings.json sets enabledPlugins[\"$PID\"] to false" \
    || fail "the checkout's tracked .claude/settings.json lacks the plugin's false entry"
cp "$WSC/.claude/settings.json" "$SANDBOX/ws-settings.json"
jq --arg id "$PID" 'del(.enabledPlugins[$id])' "$SANDBOX/ws-settings.json" > "$WSC/.claude/settings.json"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"DRIFT: the workspace checkout's tracked $WSC/.claude/settings.json does not set enabledPlugins"* ]] \
    && pass "--check reports a missing false entry in the checkout's tracked settings (drift)" \
    || fail "--check without the tracked false entry (rc=$rc out=$out)"
cp "$WSC/.claude/settings.json" "$SANDBOX/ws-settings-off.json"
run >/dev/null
cmp -s "$WSC/.claude/settings.json" "$SANDBOX/ws-settings-off.json" \
    && pass "...and install does not write the tracked file" \
    || fail "...install changed the checkout's tracked .claude/settings.json"
cp "$SANDBOX/ws-settings.json" "$WSC/.claude/settings.json"
rm -f "$SANDBOX/ws-settings.json" "$SANDBOX/ws-settings-off.json"

# --check reports: not enabled at user scope; declared from another
# checkout; the machine-level record lost. Install repairs each with only
# the calls it needs.
cp "$SETTINGS" "$SANDBOX/us-good.json"
jq --arg id "$PID" 'del(.enabledPlugins[$id])' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"plugin is not enabled at user scope from this checkout"* ]] \
    && pass "--check reports the plugin not enabled at user scope (drift)" \
    || fail "--check, user-scope enable gone (rc=$rc out=$out)"
n0="$(n_log)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(log_since "$n0" | cut -d'|' -f2)" == "plugin install $PID --scope user" ]] && user_on \
    && pass "...and install repairs it with the one install call" \
    || fail "...install over a missing enable (rc=$rc calls: $(log_since "$n0"))"
OTHER_WS="$SANDBOX/other-ws"
mkdir -p "$OTHER_WS/.agent" && : > "$OTHER_WS/.agent/user_tier_scripts.txt"
jq --arg p "$OTHER_WS" '.extraKnownMarketplaces["agent-workspace"].source.path = $p' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"declared at user scope"*"from another checkout, $OTHER_WS"* ]] \
    && pass "--check reports a user-scope declaration from another checkout (drift)" \
    || fail "--check, foreign user-scope declaration (rc=$rc out=$out)"
n0="$(n_log)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"repointing it here"* \
   && "$(log_since "$n0" | cut -d'|' -f2 | tr '\n' ';')" == "plugin marketplace add $WSC_PHYS --scope user;plugin install $PID --scope user;" ]] \
    && user_on && km_ours \
    && pass "...and install repoints it with marketplace add (no separate takeover), then re-runs install (the install record was the other checkout's)" \
    || fail "...install over a foreign declaration (rc=$rc calls: $(log_since "$n0") out=${out:0:300})"
n0="$(n_log)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(n_log)" -eq "$n0" ]] \
    && pass "...and the run after the repoint makes no CLI call" \
    || fail "...run after a repoint (rc=$rc calls: $(log_since "$n0"))"
# The enable and the declaration are this checkout's, but the CLI's record
# lists no user-scope install: --check calls it drift, and install runs the
# install call alone.
jq --arg id "$PID" '.plugins[$id] |= map(select(.scope != "user"))' "$IP_FILE" > "$tmp" && mv "$tmp" "$IP_FILE"
n0="$(n_log)"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"DRIFT: the claude CLI's record of plugin installs ($IP_FILE) lists no user-scope install of $PID"* && "$(n_log)" -eq "$n0" ]] \
    && pass "--check reports an enable with no user-scope install in the CLI's record (drift)" \
    || fail "--check, user-scope install record gone (rc=$rc out=$out)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(log_since "$n0" | cut -d'|' -f2)" == "plugin install $PID --scope user" ]] \
    && jq -e --arg id "$PID" '[.plugins[$id][] | select(.scope == "user")] | length == 1' "$IP_FILE" >/dev/null \
    && pass "...and install runs the one install call, which records it" \
    || fail "...install over a missing user-scope install record (rc=$rc calls: $(log_since "$n0") record: $(cat "$IP_FILE"))"
jq 'del(.["agent-workspace"])' "$KM_FILE" > "$tmp" && mv "$tmp" "$KM_FILE"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"machine-level record"*"has no entry for it"* ]] \
    && pass "--check reports a machine-level record with no entry (drift)" \
    || fail "--check, machine record gone (rc=$rc out=$out)"
n0="$(n_log)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(log_since "$n0" | cut -d'|' -f2)" == "plugin marketplace add $WSC_PHYS --scope user" ]] && km_ours \
    && pass "...and a re-run with the settings right calls marketplace add alone and repairs it" \
    || fail "...repair of the machine record (rc=$rc calls: $(log_since "$n0"))"

# A CLI that claims success but writes nothing: install fails, naming it,
# and touches no project root.
jq --arg id "$PID" 'del(.enabledPlugins[$id]) | del(.extraKnownMarketplaces["agent-workspace"])' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
legacy_enable "$ROOTS/a"
n0="$(n_log)"
out="$(STUB_NOOP=1 run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"reported success, but"*"does not show $PID enabled"* && "$out" == *"nothing in any project root was changed"* ]] \
    && has_entry "$ROOTS/a" && ! log_since "$n0" | grep -q -- '--scope local' \
    && pass "a CLI that claims success but enables nothing fails the install, before any root is touched" \
    || fail "no-op CLI (rc=$rc out=${out:0:400})"
out="$(STUB_FAIL=1 run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"failed"* ]] && has_entry "$ROOTS/a" \
    && pass "a failing CLI fails the install, and the per-root entry stays" \
    || fail "failing CLI (rc=$rc out=${out:0:400})"
# stdin is closed for every call: a CLI that stops for a prompt fails
# instead of hanging the installer.
: > "$SANDBOX/stdin.log"
out="$(STUB_STDIN_LOG="$SANDBOX/stdin.log" run < <(yes))"; rc=$?
[[ ! -s "$SANDBOX/stdin.log" ]] \
    && pass "every claude plugin call runs with stdin closed" \
    || fail "a claude plugin call read stdin: $(head -n3 "$SANDBOX/stdin.log")"

# Migration. That run moved root a's per-root entry: the CLI ran from the
# root at local scope (asserted by argv and cwd, not a file edit), the entry
# is gone, the root's own keys stay, and the user scope is on.
user_on && ! has_entry "$ROOTS/a" \
    && jq -e '.permissions.allow == ["Bash(make *)"]' "$ROOTS/a/$SLJ" >/dev/null \
    && pass "migration: a root's legacy entry ends with none; the root's own settings stay" \
    || fail "migration of root a ($(cat "$ROOTS/a/$SLJ"))"
grep -qxF "$ROOTS/a|plugin uninstall $PID --scope local" "$STUB_LOG" \
    && grep -qxF "$ROOTS/a|plugin marketplace remove agent-workspace --scope local" "$STUB_LOG" \
    && pass "...through the CLI: uninstall and marketplace remove at --scope local, run from the root" \
    || fail "...migration CLI calls ($(grep -F "$ROOTS/a|" "$STUB_LOG"))"
# The order: user scope first, then the local removes.
first_local="$(grep -n -- '--scope local' "$STUB_LOG" | head -n1 | cut -d: -f1)"
last_user="$(grep -n -- '--scope user' "$STUB_LOG" | tail -n1 | cut -d: -f1)"
[[ -n "$first_local" && -n "$last_user" && "$last_user" -lt "$first_local" ]] \
    && pass "...after the user-scope enable, never before" \
    || fail "...order of the user-scope and local calls (user last at $last_user, local first at $first_local)"
n0="$(n_log)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(n_log)" -eq "$n0" && "$out" != *"per-root"* && "$out" != *"moved the"* ]] \
    && pass "the next run finds nothing to migrate, says nothing about it, and runs no CLI" \
    || fail "second run after a migration (rc=$rc calls: $(log_since "$n0") out=${out:0:400})"

# A root with a local false: never touched, never drift.
mkdir -p "$ROOTS/nogit/.claude"
jq -n --arg id "$PID" '{enabledPlugins: {($id): false}}' > "$ROOTS/nogit/$SLJ"
cp "$ROOTS/nogit/$SLJ" "$SANDBOX/off-before.json"
n0="$(n_log)"
out="$(run)"; rc=$?
cmp -s "$ROOTS/nogit/$SLJ" "$SANDBOX/off-before.json" && [[ "$rc" -eq 0 && "$(n_log)" -eq "$n0" ]] \
    && pass "a root whose local entry is false is left exactly as it is, with no CLI call" \
    || fail "local false (rc=$rc calls: $(log_since "$n0"))"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" != *"nogit"* ]] \
    && pass "...and --check neither reports it nor calls it drift" \
    || fail "...--check over a local false (rc=$rc out=$out)"
rm -f "$ROOTS/nogit/$SLJ" "$SANDBOX/off-before.json"

# A root whose entry names another checkout: left, with a note.
legacy_enable "$ROOTS/a" "$OTHER_WS"
n0="$(n_log)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"$ROOTS/a/$SLJ declares the agent-workspace marketplace from another checkout, $OTHER_WS"* ]] \
    && has_entry "$ROOTS/a" && [[ "$(n_log)" -eq "$n0" ]] \
    && pass "a root whose entry names another checkout is left, with a note" \
    || fail "foreign per-root entry (rc=$rc out=${out:0:400} calls: $(log_since "$n0"))"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"note:"*"another checkout"* ]] \
    && pass "...and --check notes it without calling it drift" \
    || fail "...--check over a foreign per-root entry (rc=$rc out=$out)"
rm -f "$ROOTS/a/$SLJ"

# A legacy true entry: --check notes it (not drift) and says to re-run.
legacy_enable "$ROOTS/a"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"note: $ROOTS/a/$SLJ (registered root a) still holds a per-root agent-workspace entry"*"re-run the installer"* ]] \
    && pass "--check notes a legacy per-root entry, not as drift" \
    || fail "--check over a legacy entry (rc=$rc out=$out)"
run >/dev/null
! has_entry "$ROOTS/a" && pass "...and the installer then moves it" || fail "...legacy entry not moved"

# A registered root not on disk: a note, the run succeeds; once it
# appears, a later run migrates it.
echo "late     single_project  $ROOTS/late" >> "$WSC/.agent/projects.local"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"registered root late is not on disk ($ROOTS/late)"* ]] \
    && pass "a registered root not on disk is noted and does not fail the run" \
    || fail "missing root (rc=$rc out=${out:0:400})"
mkdir -p "$ROOTS/late"
git -C "$ROOTS/late" init -q
legacy_enable "$ROOTS/late"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 ]] && ! has_entry "$ROOTS/late" \
    && pass "...and once it is on disk, a later run migrates it" \
    || fail "...late root not migrated (rc=$rc out=${out:0:400})"

# A root that is a linked git worktree: reported with the hand removal, no
# CLI call, and the main repository's local false untouched.
git -C "$ROOTS/a" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$ROOTS/a" worktree add -q "$ROOTS/a-wt" 2>/dev/null
echo "awt      single_project  $ROOTS/a-wt" >> "$WSC/.agent/projects.local"
legacy_enable "$ROOTS/a-wt"
jq -n --arg id "$PID" '{enabledPlugins: {($id): false}}' > "$ROOTS/a/$SLJ"
cp "$ROOTS/a/$SLJ" "$SANDBOX/main-before.json"
n0="$(n_log)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(n_log)" -eq "$n0" && "$out" == *"NOTE: $ROOTS/a-wt/$SLJ (registered root awt) holds a per-root agent-workspace entry"*"linked git worktree"*"remove it by hand: delete \"$PID\" from enabledPlugins"* ]] \
    && has_entry "$ROOTS/a-wt" && cmp -s "$ROOTS/a/$SLJ" "$SANDBOX/main-before.json" \
    && pass "a legacy entry in a linked worktree is reported with the hand removal; no CLI call; the main repository's false stays" \
    || fail "linked-worktree root (rc=$rc calls: $(log_since "$n0") out=${out:0:500})"
out="$(run)"
[[ "$out" == *"$ROOTS/a-wt/$SLJ"*"remove it by hand"* ]] \
    && pass "...and it is reported again on every run" || fail "...not reported on the next run"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"note: $ROOTS/a-wt/$SLJ"*"linked git worktree"* ]] \
    && pass "...--check notes it, not as drift" || fail "...--check over a worktree entry (rc=$rc out=$out)"
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"ERROR: $ROOTS/a-wt/$SLJ"*"remove it by hand"* ]] && has_entry "$ROOTS/a-wt" \
    && pass "...and --uninstall, which cannot remove it, exits 1 naming the hand removal" \
    || fail "...--uninstall over a worktree entry (rc=$rc out=${out:0:500})"
run >/dev/null
rm -f "$ROOTS/a-wt/$SLJ" "$ROOTS/a/$SLJ" "$SANDBOX/main-before.json"

# A root that is a plain subdirectory of a repository: reported, not
# migrated; the next run neither re-migrates it nor calls it drift.
mkdir -p "$ROOTS/a/sub"
echo "asub     single_project  $ROOTS/a/sub" >> "$WSC/.agent/projects.local"
legacy_enable "$ROOTS/a/sub"
n0="$(n_log)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$(n_log)" -eq "$n0" && "$out" == *"$ROOTS/a/sub/$SLJ"*"plain directory inside the git repository $ROOTS/a"*"remove it by hand"* ]] \
    && has_entry "$ROOTS/a/sub" && [[ ! -e "$ROOTS/a/$SLJ" ]] \
    && pass "a legacy entry in a plain subdirectory of a repository is reported, not migrated (the toplevel is not touched)" \
    || fail "subdirectory root (rc=$rc calls: $(log_since "$n0") out=${out:0:500})"
n0="$(n_log)"
run >/dev/null
out="$(run --check)"; rc=$?
[[ "$(n_log)" -eq "$n0" && "$rc" -eq 0 && "$out" == *"note: $ROOTS/a/sub/$SLJ"* ]] \
    && pass "...the next run does not re-migrate it, and --check does not call it drift" \
    || fail "...subdirectory root on the next run (rc=$rc calls: $(log_since "$n0"))"
rm -f "$ROOTS/a/sub/$SLJ"
sed -i '/^asub /d; /^awt /d' "$WSC/.agent/projects.local"

# An unparseable settings.local.json: a note, not an error.
mkdir -p "$ROOTS/nogit/.claude"
echo '{not json' > "$ROOTS/nogit/$SLJ"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"NOTE: $ROOTS/nogit/$SLJ is not valid JSON"* ]] \
    && pass "an unparseable settings.local.json is a note, not an error" \
    || fail "unparseable root (rc=$rc out=${out:0:400})"
rm -f "$ROOTS/nogit/$SLJ"

# A root found only in the CLI's own record (unregistered by hand, or
# moved): migrated; and one whose directory is gone is noted on every run
# with the hand removal.
mkdir -p "$ROOTS/byhand"
(cd "$ROOTS/byhand" && HOME="$HOMEDIR" STUB_LOG="$SANDBOX/byhand.log" "$STUB" plugin marketplace add "$WSC_PHYS" --scope local >/dev/null \
    && HOME="$HOMEDIR" STUB_LOG="$SANDBOX/byhand.log" "$STUB" plugin install "$PID" --scope local >/dev/null)
mkdir -p "$ROOTS/gone-later"
(cd "$ROOTS/gone-later" && HOME="$HOMEDIR" STUB_LOG="$SANDBOX/byhand.log" "$STUB" plugin install "$PID" --scope local >/dev/null)
rm -rf "$ROOTS/gone-later"
jq -e --arg id "$PID" --arg p "$ROOTS/byhand" '[.plugins[$id][] | select(.scope == "local" and .projectPath == $p)] | length == 1' "$IP_FILE" >/dev/null \
    && pass "the CLI's record lists the hand-made local install (fixture check)" \
    || fail "fixture: installed_plugins.json ($(cat "$IP_FILE"))"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 ]] && ! has_entry "$ROOTS/byhand" \
    && grep -qxF "$ROOTS/byhand|plugin uninstall $PID --scope local" "$STUB_LOG" \
    && pass "a root found only in the CLI's installed_plugins.json is migrated" \
    || fail "CLI-record root (rc=$rc out=${out:0:400})"
gone_note="the object with \"scope\": \"local\" and \"projectPath\": \"$ROOTS/gone-later\" from the \"$PID\" array in $IP_FILE"
[[ "$out" == *"$ROOTS/gone-later, which is not on disk"*"$gone_note"* ]] \
    && pass "a projectPath in the CLI's record that is not on disk is noted with the hand removal" \
    || fail "gone projectPath (out=${out:0:600})"
out="$(run)"
[[ "$out" == *"$gone_note"* ]] && pass "...on every run" || fail "...not noted on the next run"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"$gone_note"* ]] \
    && pass "...and --check notes it, not as drift" || fail "...--check over a gone projectPath (rc=$rc out=$out)"
jq --arg id "$PID" '.plugins[$id] |= map(select(.scope != "local"))' "$IP_FILE" > "$tmp" && mv "$tmp" "$IP_FILE"

# A CLI record that does not parse: the roots it would list are not looked
# at, so every mode says so; --uninstall does not report a clean removal.
cp "$IP_FILE" "$SANDBOX/ip-good.json"
echo '{not json' > "$IP_FILE"
ip_msg="$IP_FILE (the claude CLI's record of plugin installs) is not valid JSON"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"NOTE: $ip_msg"*"were not looked at"* ]] \
    && pass "an installed_plugins.json that does not parse is a note on install" \
    || fail "install over an unparseable CLI record (rc=$rc out=${out:0:500})"
out="$(run --check)"; rc=$?
[[ "$out" == *"note: $ip_msg"* ]] \
    && pass "...and on --check" || fail "...--check over an unparseable CLI record (rc=$rc out=$out)"
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"ERROR: $ip_msg"* && "$out" != *"agent_workspace user tier removed."* ]] \
    && pass "...and --uninstall exits 1 naming it, never reporting a clean removal" \
    || fail "...--uninstall over an unparseable CLI record (rc=$rc out=${out:0:500})"
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"ERROR: $ip_msg"* && "$out" != *"nothing installed"* ]] \
    && pass "...even once the rest is gone (not \"nothing installed\")" \
    || fail "...second --uninstall over an unparseable CLI record (rc=$rc out=${out:0:500})"
cp "$SANDBOX/ip-good.json" "$IP_FILE"
rm -f "$SANDBOX/ip-good.json"
run >/dev/null

# The read-back after migrating: a local call that costs the user-scope
# enable (or the machine-level record) fails the run, naming it; a re-run
# restores it.
legacy_enable "$ROOTS/a"
out="$(STUB_LOCAL_DROPS_USER=1 run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"after moving per-root entries to user scope, but"*"does not show $PID enabled"* ]] \
    && pass "the user-scope enable is read back after migrating; its loss fails the run" \
    || fail "read-back after migration, enable lost (rc=$rc out=${out:0:500})"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 ]] && user_on && pass "...and a re-run restores it" || fail "...re-run after a lost enable (rc=$rc)"
legacy_enable "$ROOTS/a"
out="$(STUB_REMOVE_DROPS_KM=1 run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"after moving per-root entries to user scope, but the claude CLI's machine-level record"* ]] \
    && pass "the machine-level record is read back after migrating; its loss fails the run" \
    || fail "read-back after migration, record lost (rc=$rc out=${out:0:500})"
run >/dev/null && km_ours && pass "...and a re-run restores it" || fail "...re-run after a lost record"
# A CLI that runs in the root but leaves the entry: an error naming it.
legacy_enable "$ROOTS/a"
out="$(STUB_LOCAL_NOOP=1 run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"ERROR: the claude CLI ran in $ROOTS/a, but $ROOTS/a/$SLJ still holds"* ]] \
    && pass "a local remove that leaves the entry is an error naming the hand removal" \
    || fail "local no-op (rc=$rc out=${out:0:500})"
run >/dev/null
# A local true the CLI did not write (no marketplace declaration, no local
# install in its record) that the CLI leaves: a note naming the hand
# removal, not an error on every install; --uninstall still cannot report
# a clean removal.
jq --arg id "$PID" '.enabledPlugins[$id] = true' "$ROOTS/a/$SLJ" > "$tmp" && mv "$tmp" "$ROOTS/a/$SLJ"
n0="$(n_log)"
out="$(STUB_LOCAL_NOOP=1 run)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"NOTE: $ROOTS/a/$SLJ (registered root a) enables the agent-workspace plugin with no marketplace declaration"*"did not remove it -- remove it by hand: delete \"$PID\" from enabledPlugins"* \
   && "$out" != *"ERROR"* ]] && has_entry "$ROOTS/a" \
    && grep -qxF "$ROOTS/a|plugin uninstall $PID --scope local" <(log_since "$n0") \
    && pass "a hand-written local true the CLI does not remove is a note with the hand removal, and install exits 0" \
    || fail "hand-written local true (rc=$rc out=${out:0:600} calls: $(log_since "$n0"))"
out="$(STUB_LOCAL_NOOP=1 run --uninstall)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"ERROR: $ROOTS/a/$SLJ (registered root a) enables the agent-workspace plugin with no marketplace declaration"* ]] \
    && has_entry "$ROOTS/a" \
    && pass "...and --uninstall, which leaves it, exits 1 naming it" \
    || fail "...--uninstall over a hand-written local true (rc=$rc out=${out:0:600})"
jq --arg id "$PID" 'del(.enabledPlugins[$id]) | if .enabledPlugins == {} then del(.enabledPlugins) else . end' "$ROOTS/a/$SLJ" > "$tmp" && mv "$tmp" "$ROOTS/a/$SLJ"
run >/dev/null

# The workspace checkout's own legacy enable: --check calls it drift (it
# overrides the tracked false entry, doubling every skill at the
# checkout's root); install removes it.
legacy_enable "$WSC"
out="$(run --check)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"DRIFT: $WSC/$SLJ enables the agent-workspace plugin in the workspace checkout itself"* ]] \
    && pass "--check calls a local enable in the workspace checkout itself drift" \
    || fail "--check over the checkout's own enable (rc=$rc out=$out)"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 ]] && ! has_entry "$WSC" \
    && grep -qxF "$WSC|plugin uninstall $PID --scope local" "$STUB_LOG" \
    && pass "...and install removes it through the CLI" \
    || fail "...checkout's own enable not removed (rc=$rc out=${out:0:400})"

# An old install moved over in one run: per-root entries in two roots and
# the checkout, nothing at user scope. One run ends with the plugin at user
# scope and no per-root entry; the next prints no migration line.
jq --arg id "$PID" 'del(.enabledPlugins[$id]) | del(.extraKnownMarketplaces["agent-workspace"])' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
legacy_enable "$ROOTS/a"
legacy_enable "$ROOTS/nogit"
out="$(run)"; rc=$?
[[ "$rc" -eq 0 ]] && user_on && km_ours && ! has_entry "$ROOTS/a" && ! has_entry "$ROOTS/nogit" \
    && pass "an old per-root install is moved to user scope in one run" \
    || fail "old install migration (rc=$rc out=${out:0:500})"
out="$(run)"
[[ "$out" != *"moved the"* && "$out" != *"per-root"* ]] \
    && pass "...and the next run prints no migration line" || fail "...next run mentions migration (out=${out:0:400})"

# Without the claude CLI: install notes it and succeeds; --check notes the
# missing enable without calling it drift.
NOCLI_HOME="$SANDBOX/home-nocli"
mkdir -p "$NOCLI_HOME"
run_nocli() {
    ( unset CLAUDE_CONFIG_DIR
      HOME="$NOCLI_HOME" TMPDIR="$INST_TMP" AGENT_WORKSPACE_CLAUDE_BIN="$SANDBOX/no-such-claude" bash "$INSTALL" "$@" 2>&1 )
}
legacy_enable "$ROOTS/a"
out="$(run_nocli)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"claude CLI is not on PATH -- not enabling the agent-workspace plugin"* \
   && "$out" == *"$ROOTS/a/$SLJ (registered root a) holds a per-root agent-workspace entry from this checkout; the claude CLI is not on PATH -- remove it by hand"* ]] \
    && pass "without the claude CLI, install notes the skipped enable and the per-root entry, and succeeds" \
    || fail "no-CLI install (rc=$rc out=${out:0:500})"
out="$(run_nocli --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"note: the agent-workspace plugin is not enabled at user scope"*"not on PATH"* ]] \
    && pass "...and --check notes the missing enable without calling it drift" \
    || fail "...no-CLI --check (rc=$rc out=$out)"
out="$(run_nocli --uninstall)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"ERROR: $ROOTS/a/$SLJ"*"not on PATH"* ]] && has_entry "$ROOTS/a" \
    && pass "...and --uninstall without the CLI exits 1, naming the per-root entry it cannot remove" \
    || fail "...no-CLI --uninstall (rc=$rc out=${out:0:400})"
run >/dev/null

# CLAUDE_CONFIG_DIR: the CLI keeps its user settings and records there, so
# the installer reads them there, and a run that finds them current makes
# no CLI call.
CFG="$SANDBOX/cfgdir"
mkdir -p "$CFG"
n0="$(n_log)"
out="$(RUN_CFG="$CFG" run)"; rc=$?
[[ "$rc" -eq 0 && "$(log_since "$n0" | wc -l)" -eq 2 ]] \
    && jq -e --arg id "$PID" '.enabledPlugins[$id] == true' "$CFG/settings.json" >/dev/null \
    && pass "with CLAUDE_CONFIG_DIR set, the enable is read from (and lands in) that directory" \
    || fail "CLAUDE_CONFIG_DIR install (rc=$rc calls: $(log_since "$n0") out=${out:0:400})"
n0="$(n_log)"
out="$(RUN_CFG="$CFG" run)"; rc=$?
[[ "$rc" -eq 0 && "$(n_log)" -eq "$n0" ]] \
    && pass "...and a re-run there makes no CLI call" \
    || fail "...CLAUDE_CONFIG_DIR re-run (rc=$rc calls: $(log_since "$n0"))"
out="$(RUN_CFG="$CFG" run --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "...and --check reads it there" || fail "...CLAUDE_CONFIG_DIR --check (rc=$rc out=$out)"
RUN_CFG="$CFG" run --uninstall >/dev/null
run >/dev/null

# The scratch directory: a TMPDIR inside a git repository is refused
# before the CLI runs; an interrupt while the CLI runs leaves nothing.
jq --arg id "$PID" 'del(.enabledPlugins[$id]) | del(.extraKnownMarketplaces["agent-workspace"])' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
mkdir -p "$SANDBOX/gittmp"
git -C "$SANDBOX/gittmp" init -q
n0="$(n_log)"
out="$(RUN_TMPDIR="$SANDBOX/gittmp" run)"; rc=$?
[[ "$rc" -eq 1 && "$out" == *"is inside a git repository -- not running the claude CLI there"* && "$(n_log)" -eq "$n0" ]] \
    && [[ "$(find "$SANDBOX/gittmp" -mindepth 1 -maxdepth 1 ! -name .git | wc -l)" -eq 0 ]] \
    && pass "a TMPDIR inside a git repository is refused before the CLI runs, and nothing is left there" \
    || fail "TMPDIR in git (rc=$rc out=${out:0:400})"
(
    unset CLAUDE_CONFIG_DIR
    HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" TMPDIR="$INST_TMP" STUB_ADD_SLEEP=2 \
        AGENT_WORKSPACE_CLAUDE_BIN="$STUB" bash "$INSTALL" >/dev/null 2>&1 &
    pid=$!
    sleep 1
    ls -A "$INST_TMP" > "$SANDBOX/saw-scratch"
    kill -TERM "$pid"
    wait "$pid"
    echo "$?" > "$SANDBOX/term-rc"
)
[[ "$(cat "$SANDBOX/term-rc")" -eq 143 && -s "$SANDBOX/saw-scratch" && -z "$(ls -A "$INST_TMP")" ]] \
    && pass "an interrupt while the CLI runs leaves no scratch directory behind" \
    || fail "interrupted enable (rc=$(cat "$SANDBOX/term-rc") saw='$(cat "$SANDBOX/saw-scratch")' left='$(ls -A "$INST_TMP")')"
run >/dev/null

# --check reads JSON only: it never runs the CLI.
legacy_enable "$ROOTS/a"
n0="$(n_log)"
run --check >/dev/null
[[ "$(n_log)" -eq "$n0" ]] && pass "--check runs no claude CLI call" || fail "--check ran the CLI: $(log_since "$n0")"

# --uninstall after a migrated install: no --scope local entry anywhere and
# no user-scope entry; the next --uninstall finds nothing.
run >/dev/null
legacy_enable "$ROOTS/a"
legacy_enable "$WSC"
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 0 ]] && ! has_entry "$ROOTS/a" && ! has_entry "$WSC" \
    && jq -e --arg id "$PID" '((.enabledPlugins // {}) | has($id) | not) and ((.extraKnownMarketplaces // {}) | has("agent-workspace") | not)' "$SETTINGS" >/dev/null \
    && pass "--uninstall leaves no per-root entry and no user-scope entry" \
    || fail "--uninstall (rc=$rc out=${out:0:500} settings: $(jq -c '{enabledPlugins, extraKnownMarketplaces}' "$SETTINGS"))"
grep -qxF "plugin uninstall $PID --scope user" <(cut -d'|' -f2 "$STUB_LOG") \
    && grep -qxF "plugin marketplace remove agent-workspace --scope user" <(cut -d'|' -f2 "$STUB_LOG") \
    && pass "...through the CLI at --scope user" || fail "...uninstall CLI calls"
n0="$(n_log)"
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 0 && "$(n_log)" -eq "$n0" ]] \
    && pass "...and a second --uninstall runs no CLI call" || fail "...second --uninstall (rc=$rc out=$out calls: $(log_since "$n0"))"
# Another checkout's user-scope declaration is left alone by --uninstall.
run >/dev/null
jq --arg p "$OTHER_WS" '.extraKnownMarketplaces["agent-workspace"].source.path = $p' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"declared from another checkout ($OTHER_WS) -- left for that checkout's --uninstall"* ]] \
    && [[ "$(jq -r '.extraKnownMarketplaces["agent-workspace"].source.path' "$SETTINGS")" == "$OTHER_WS" ]] \
    && pass "--uninstall leaves another checkout's user-scope declaration alone" \
    || fail "--uninstall over a foreign user-scope declaration (rc=$rc out=${out:0:400})"
# A user-scope enable with no marketplace declaration names no checkout:
# --uninstall reports it with the removal by hand, runs no user-scope CLI
# call, and leaves it.
run >/dev/null
jq 'del(.extraKnownMarketplaces["agent-workspace"])' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
n0="$(n_log)"
out="$(run --uninstall)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"NOTE: $SETTINGS enables the agent-workspace plugin at user scope with no agent-workspace marketplace declaration, so nothing ties it to this checkout"*"delete \"$PID\" from enabledPlugins in $SETTINGS"* ]] \
    && ! log_since "$n0" | grep -q -- '--scope user' \
    && jq -e --arg id "$PID" '.enabledPlugins[$id] == true' "$SETTINGS" >/dev/null \
    && pass "--uninstall leaves a user-scope enable with no declaration, naming the hand removal, with no user-scope CLI call" \
    || fail "--uninstall over an undeclared user-scope enable (rc=$rc out=${out:0:500} calls: $(log_since "$n0"))"

# A registry that does not parse stops install, --check and --uninstall
# before anything changes.
run >/dev/null 2>&1
printf 'a single_project %s\nbad!name single_project %s\n' "$ROOTS/a" "$ROOTS/b" > "$WSC/.agent/projects.local"
legacy_enable "$ROOTS/a"
for mode in install --check --uninstall; do
    n0="$(n_log)"
    if [[ "$mode" == install ]]; then out="$(run)"; rc=$?; else out="$(run "$mode")"; rc=$?; fi
    [[ "$rc" -eq 1 && "$out" == *"invalid project name 'bad!name'"* && "$out" == *"ERROR: $WSC/.agent/projects.local does not parse"* \
       && "$(n_log)" -eq "$n0" ]] && has_entry "$ROOTS/a" \
        && pass "a registry that does not parse stops $mode before anything changes" \
        || fail "$mode over a bad registry (rc=$rc out=${out:0:400})"
done
rm -f "$WSC/.agent/projects.local" "$ROOTS/a/$SLJ"

echo ""
echo "test_user_tier_install: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
