#!/usr/bin/env bash
# .agent/scripts/tests/test_user_tier_install.sh
# Tests for .agent/scripts/user_tier_install.sh (#317, #265 PR 3):
# idempotent install, the not-installed / --require split, drift detection
# (foreign entry, missing entry, stale symlink, retired hook entry), skill
# selection from session_scope frontmatter, and uninstall.
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

bad_links=0
while IFS= read -r l; do
    [[ -L "$l" ]] || continue
    [[ "$(readlink "$l")" == "$WSC2/.claude/skills/"* ]] || bad_links=$((bad_links + 1))
done < <(ls -1d "$SKILLS_DIR"/* 2>/dev/null)
[[ "$bad_links" -eq 0 ]] \
    && pass "--force repoints every skill symlink into the taking-over checkout" \
    || fail "$bad_links skill symlink(s) still point outside $WSC2"

out="$(run2 --check)"; rc=$?
[[ "$rc" -eq 0 && "$out" == *"installed and current"* ]] \
    && pass "--check is clean immediately after --force (the takeover is complete)" \
    || fail "--check after --force still reports drift (rc=$rc out=${out:0:300})"

# The user's own untagged entry must survive even a --force takeover.
jq -e '[.hooks.PreToolUse[]?.hooks[]?.command] | index("/opt/mine.sh") != null' "$SETTINGS" >/dev/null \
    && pass "--force leaves the user's own untagged hook entry alone" \
    || fail "--force removed the user's own hook entry"

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
# Round 3: --force repoints a skill symlink that points into ANOTHER
# agent_workspace checkout, recognised by the .agent/user_tier_scripts.txt
# three levels up. Nothing tested the other side of that probe: a link the
# USER made, into a directory that is not a checkout, must survive --force
# untouched. Without this, loosening the probe would go unnoticed.
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
    || fail "--force repointed a user symlink (now: $(readlink "$SKILLS_DIR/zz-fixture-userlink" 2>/dev/null))"
[[ "$out" == *"not ours to replace"* ]] \
    && pass "--force reports the user's symlink as not ours to replace" \
    || fail "--force did not report the user's symlink (out=${out:0:300})"

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

echo ""
echo "test_user_tier_install: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
