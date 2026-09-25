#!/usr/bin/env bash
# .agent/scripts/tests/live/plugin_acceptance.sh
# Live acceptance for the agent-workspace plugin (ADR-0017, #345), ported
# from the 2026-09-24 plugin spike. OPT-IN: it starts real headless Claude
# Code sessions (`claude -p`, auth and a few cents each), so it lives
# outside tests/test_*.sh and run_script_tests.sh never collects it.
#
#   PLUGIN_ACCEPTANCE=1 bash .agent/scripts/tests/live/plugin_acceptance.sh
#   (LIVE_MODEL=<alias> picks the session model; default haiku)
#
# It never touches this checkout, the real registry or ~/.claude/settings.json.
# It works on a COPY of the checkout whose plugin and marketplace are renamed
# `aw-accept`, so the machine-level plugin records the CLI keeps under
# ~/.claude/plugins/ never gain or lose an `agent-workspace` entry; both
# records it adds are removed on exit. Cases, each asserting on what a real
# session reports:
#   A  collision: in a repo with its own plan-task, bare /plan-task is still
#      the project's, and /aw-accept:<skill> reaches the plugin;
#   B  a git worktree of that repo inherits the plugin;
#   C  an unrelated repo has no aw-accept: skill;
#   D  a session at the workspace root has the skills bare, not also
#      under aw-accept: (never doubled);
#   E  p11 shape: a registered root inside the workspace's git tree is
#      skipped by the installer (sandbox HOME; the CLI is a stub that fails
#      loudly if called) and its session has them bare, once;
#   F  prefix detection (plan-review round-2 finding A): a probe skill
#      reports what ${CLAUDE_PLUGIN_ROOT} became. Loaded bare it must not
#      name the workspace; loaded through the plugin it must, and run-issue's
#      rule then yields `<plugin>:` in the plugin session and empty bare.
#
# Exit: 0 all pass (or not opted in); 1 a case failed; 3 missing dependency.

set -uo pipefail

if [[ "${PLUGIN_ACCEPTANCE:-}" != 1 ]]; then
    echo "plugin_acceptance: opt-in live suite (real claude sessions) -- set PLUGIN_ACCEPTANCE=1 to run"
    exit 0
fi
for dep in claude jq git; do
    command -v "$dep" >/dev/null 2>&1 || { echo "FATAL: $dep is required" >&2; exit 3; }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
MODEL="${LIVE_MODEL:-haiku}"
NAME="aw-accept"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOX="$(mktemp -d)"
SANDBOX="$(cd "$SANDBOX" && pwd -P)"
W="$SANDBOX/ws"       # the workspace copy (marketplace aw-accept)
P="$SANDBOX/proj"     # a project with its own plan-task
U="$SANDBOX/other"    # an unrelated repo

cleanup() {
    if [[ -d "$P" ]]; then
        (cd "$P" && claude plugin uninstall "$NAME@$NAME" --scope local >/dev/null 2>&1)
        (cd "$P" && claude plugin marketplace remove "$NAME" --scope local >/dev/null 2>&1)
    fi
    rm -rf "${SANDBOX:?}"
}
trap cleanup EXIT

session() {  # <dir> <prompt>: one headless session, no tools
    (cd "$1" && timeout 300 claude -p "$2" --model "$MODEL" --tools "" 2>&1)
}
# --------------------------------------------------------------- setup ---
mkdir -p "$W"
cp -r "$WS_ROOT/.agent" "$WS_ROOT/.claude" "$WS_ROOT/.claude-plugin" "$W/"
rm -f "$W/.agent/projects.local" "$W/.claude/settings.local.json"
jq --arg n "$NAME" '.name = $n | .plugins[0].name = $n' "$W/.claude-plugin/marketplace.json" > "$W/m.json" \
    && mv "$W/m.json" "$W/.claude-plugin/marketplace.json"
mkdir -p "$W/.claude/skills/zz-probe"
cat > "$W/.claude/skills/zz-probe/SKILL.md" <<'EOF'
---
name: zz-probe
description: Acceptance probe. Replies with one fixed line.
session_scope: both
---

Reply with exactly the following line, copied character for character, and nothing else:

PROBE<<<${CLAUDE_PLUGIN_ROOT}>>>
EOF
jq --arg n "$NAME" '.name = $n' "$W/.claude-plugin/plugin.json" > "$W/p.json" \
    && mv "$W/p.json" "$W/.claude-plugin/plugin.json"
HOME="$SANDBOX/home" bash "$W/.agent/scripts/user_tier_install.sh" --generate-plugin-manifest >/dev/null \
    || { echo "FATAL: could not regenerate the copy's manifest" >&2; exit 1; }
git -C "$W" init -q
(cd "$W" && claude plugin validate . >/dev/null 2>&1) \
    && pass "the workspace copy validates as a marketplace" \
    || fail "claude plugin validate failed on the workspace copy"

mkdir -p "$P/.claude/skills/plan-task" "$U"
cat > "$P/.claude/skills/plan-task/SKILL.md" <<'EOF'
---
name: plan-task
description: This project's own planning skill.
---

Reply PROJECT-OWN-PLAN-TASK.
EOF
git -C "$P" init -q
git -C "$P" -c user.name=t -c user.email=t@t add . && git -C "$P" -c user.name=t -c user.email=t@t commit -qm init
git -C "$U" init -q

(cd "$P" && claude plugin marketplace add "$W" --scope local >/dev/null && claude plugin install "$NAME@$NAME" --scope local >/dev/null) \
    || { echo "FATAL: could not enable the $NAME plugin in the sandbox project" >&2; exit 1; }
jq -e --arg id "$NAME@$NAME" '.enabledPlugins[$id] == true' "$P/.claude/settings.local.json" >/dev/null \
    && pass "local-scope install writes the project's settings.local.json" \
    || fail "the project's settings.local.json does not enable $NAME"

# Each case invokes a skill by slash command and looks for its marker:
# `/plan-task` in the project answers PROJECT-OWN-PLAN-TASK (its own skill),
# and the probe answers PROBE<<<...>>> under whichever name reached it. An
# unavailable name gets no marker. (Asking a tool-less session to LIST its
# skills does not work: without the Skill tool it is shown none.)
has_probe() {  # <dir> <slash command>: did that command reach the probe?
    [[ "$(session "$1" "$2")" == *"PROBE<<<"* ]]
}

# ------------------------------------------------------------ A: collision ---
out="$(session "$P" "/plan-task")"
if [[ "$out" == *"PROJECT-OWN-PLAN-TASK"* ]] && has_probe "$P" "/$NAME:zz-probe"; then
    pass "A: bare /plan-task is still the project's own, and /$NAME:<skill> reaches the plugin"
else
    fail "A: collision case (/plan-task got: $(tr '\n' ' ' <<< "$out" | cut -c1-300))"
fi

# -------------------------------------------------- B: worktree inherits ---
git -C "$P" worktree add -q "$P/worktrees/wt" 2>/dev/null
has_probe "$P/worktrees/wt" "/$NAME:zz-probe" \
    && pass "B: a worktree of the project inherits the plugin" \
    || fail "B: /$NAME:zz-probe did not reach the plugin in a worktree"

# ------------------------------------------------- C: unrelated repo ---
has_probe "$U" "/$NAME:zz-probe" \
    && fail "C: the plugin leaked into an unrelated repo" \
    || pass "C: an unrelated repo has no $NAME: skill"

# ------------------------------------------------- D: workspace root ---
if has_probe "$W" "/zz-probe" && ! has_probe "$W" "/$NAME:zz-probe"; then
    pass "D: a workspace-root session has the skill bare and not under $NAME: (loaded once)"
else
    fail "D: workspace-root shape (bare and/or prefixed name wrong)"
fi

# ------------------------------------------------------ E: p11 shape ---
mkdir -p "$W/projects/inner" "$SANDBOX/home" "$SANDBOX/bin"
printf 'inner single_project %s\n' "$W/projects/inner" > "$W/.agent/projects.local"
printf '#!/bin/sh\necho "claude stub called: $*" >&2\nexit 1\n' > "$SANDBOX/bin/claude"
chmod +x "$SANDBOX/bin/claude"
iout="$(HOME="$SANDBOX/home" AGENT_WORKSPACE_CLAUDE_BIN="$SANDBOX/bin/claude" \
    bash "$W/.agent/scripts/user_tier_install.sh" 2>&1)"
if [[ "$iout" == *"skipped inner"* && "$iout" != *"claude stub called"* \
      && ! -e "$W/projects/inner/.claude/settings.local.json" && ! -e "$W/.claude/settings.local.json" ]]; then
    pass "E: the installer skips a root inside the workspace's git tree, without running the CLI"
else
    fail "E: p11-shape guard (installer said: $(tr '\n' ' ' <<< "$iout" | cut -c1-400))"
fi
if has_probe "$W/projects/inner" "/zz-probe" && ! has_probe "$W/projects/inner" "/$NAME:zz-probe"; then
    pass "E: a session in that root has the skill bare and not under $NAME:"
else
    fail "E: p11-shape session (bare and/or prefixed name wrong)"
fi

# --------------------------------------------- F: prefix detection ---
# run-issue's rule, verbatim in effect: prefix only when the substituted
# value is a directory whose pwd -P form is the workspace root's.
prefix_for() {  # <value>
    if [[ -d "$1" && "$(cd "$1" && pwd -P)" == "$W" ]]; then echo "$NAME:"; else echo ""; fi
}
probe_value() {  # <session output>
    sed -n 's/.*PROBE<<<\(.*\)>>>.*/\1/p' <<< "$1" | head -n1
}
out="$(session "$W" "/zz-probe")"
bare_val="$(probe_value "$out")"
if [[ "$out" == *"PROBE<<<"* && -z "$(prefix_for "$bare_val")" ]]; then
    pass "F: loaded bare, \${CLAUDE_PLUGIN_ROOT} does not name the workspace (got '$bare_val') -- prefix empty"
else
    fail "F: bare-load probe (got: $(tr '\n' ' ' <<< "$out"))"
fi
out="$(session "$P" "/$NAME:zz-probe")"
plug_val="$(probe_value "$out")"
if [[ "$(prefix_for "$plug_val")" == "$NAME:" ]]; then
    pass "F: loaded through the plugin, \${CLAUDE_PLUGIN_ROOT} is the workspace source -- prefix $NAME:"
else
    fail "F: plugin-load probe (got: $(tr '\n' ' ' <<< "$out"))"
fi
echo ""
echo "plugin_acceptance: $PASS passed, $FAIL failed (model: $MODEL)"
[ "$FAIL" -eq 0 ]
