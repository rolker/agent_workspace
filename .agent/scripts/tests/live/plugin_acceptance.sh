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
# ~/.claude/plugins/ never gain or lose an `agent-workspace` entry. On exit
# it removes both records it adds and the copy of the plugin the CLI leaves
# in ~/.claude/plugins/cache/aw-accept/ (which `plugin uninstall` does not
# delete; Claude Code only marks it orphaned). Cases, each asserting on
# what a real session reports:
#   A  collision: in a repo with its own plan-task, bare /plan-task is still
#      the project's, and /aw-accept:<skill> reaches the plugin;
#   B  a git worktree of that repo inherits the plugin;
#   C  an unrelated repo has no aw-accept: skill (its own control skill
#      answering first, so the session is known to work);
#   D  a session at the workspace root has the skills bare, not also
#      under aw-accept: (never doubled);
#   E  p11 shape: a registered root inside the workspace's git tree is
#      skipped by the installer (sandbox HOME; the CLI is a stub that fails
#      loudly if called) and its session has them bare, once;
#   F  prefix detection (plan-review round-2 finding A): a probe skill
#      reports what ${CLAUDE_PLUGIN_ROOT} became. Loaded bare it must not
#      name the workspace; loaded through the plugin it must, and run-issue's
#      rule then yields `<plugin>:` in the plugin session and empty bare;
#   G  parent= instance: enabled at the parent only, sessions in the
#      instance (and a git repo inside it) still reach the plugin -- the
#      assumption behind the installer's skip-instance;
#   H  a second root: the same marketplace added and installed from another
#      project root (the per-root path the installer and #332 take) works
#      there and leaves the first root working.
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
FAM="$SANDBOX/fam"    # a parent= root: a plain directory grouping instances
P2="$SANDBOX/proj2"   # a second project root, enabled after the first

# Every `claude plugin` call, stdin closed, so a prompt the CLI might show
# fails the call instead of hanging the suite.
cli_plugin() { claude plugin "$@" </dev/null; }

# Every root the suite enables the plugin in, recorded BEFORE the CLI runs
# there, so a half-finished enable is still undone on exit.
ENABLED_ROOTS=()
cleanup() {
    local r
    for r in ${ENABLED_ROOTS[@]+"${ENABLED_ROOTS[@]}"}; do
        [[ -d "$r" ]] || continue
        (cd "$r" && cli_plugin uninstall "$NAME@$NAME" --scope local >/dev/null 2>&1)
        (cd "$r" && cli_plugin marketplace remove "$NAME" --scope local >/dev/null 2>&1)
    done
    # The CLI's cached copy of the plugin, which uninstall leaves behind.
    # Only after an enable, and only the suite's own `aw-accept` name.
    if [[ ${#ENABLED_ROOTS[@]} -gt 0 ]]; then
        rm -rf "${CLAUDE_CONFIG_DIR:-${HOME:?}/.claude}/plugins/cache/${NAME:?}"
    fi
    rm -rf "${SANDBOX:?}"
}
trap cleanup EXIT

# enable_in <root>: the installer's two CLI calls, run from <root>.
enable_in() {
    ENABLED_ROOTS+=("$1")
    (cd "$1" && cli_plugin marketplace add "$W" --scope local >/dev/null \
        && cli_plugin install "$NAME@$NAME" --scope local >/dev/null)
}

# session <dir> <prompt>: one headless session, no tools. Leaves its output
# in SESSION_OUT and its exit status (124 = timed out) in SESSION_RC, and
# returns that status. Never call it in $(...): the two globals would be
# set in the subshell and lost.
SESSION_OUT=""
SESSION_RC=0
session() {
    # stdin closed: `claude -p` reads piped stdin into the prompt, and a
    # harness's stdin must never leak into (or stall) a session.
    SESSION_OUT="$(cd "$1" && timeout 300 claude -p "$2" --model "$MODEL" --tools "" 2>&1 </dev/null)"
    SESSION_RC=$?
    return "$SESSION_RC"
}
# One line of the last session's output, for a failure message.
session_said() {
    printf 'exit %s: %s' "$SESSION_RC" "$(tr '\n' ' ' <<< "$SESSION_OUT" | cut -c1-300)"
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
(cd "$W" && cli_plugin validate . >/dev/null 2>&1) \
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
mkdir -p "$U/.claude/skills/zz-control"
cat > "$U/.claude/skills/zz-control/SKILL.md" <<'EOF'
---
name: zz-control
description: Control skill for the unrelated repo.
---

Reply UNRELATED-CONTROL.
EOF

enable_in "$P" \
    || { echo "FATAL: could not enable the $NAME plugin in the sandbox project" >&2; exit 1; }
jq -e --arg id "$NAME@$NAME" '.enabledPlugins[$id] == true' "$P/.claude/settings.local.json" >/dev/null \
    && pass "local-scope install writes the project's settings.local.json" \
    || fail "the project's settings.local.json does not enable $NAME"

# Each case invokes a skill by slash command and looks for its marker:
# `/plan-task` in the project answers PROJECT-OWN-PLAN-TASK (its own skill),
# and the probe answers PROBE<<<...>>> under whichever name reached it. An
# unavailable name gets no marker. (Asking a tool-less session to LIST its
# skills does not work: without the Skill tool it is shown none.)
#
# A negative ("this name does NOT reach the probe") is only evidence when the
# session itself ran: a timeout, an auth failure or a CLI error also yields
# no marker. So probe() has three outcomes, and every negative case demands
# exactly "ran, not reached". Assumption, not yet observed: an unavailable
# slash command in `claude -p` is answered with exit 0. If a CLI version
# exits non-zero for it instead, the negative cases fail loudly, showing
# that exit status and output -- never pass silently.
PROBE_REACHED=0
PROBE_NOT_REACHED=1
PROBE_SESSION_FAILED=2
probe() {  # <dir> <slash command>
    session "$1" "$2"
    if [[ "$SESSION_RC" -ne 0 || -z "$SESSION_OUT" ]]; then
        return "$PROBE_SESSION_FAILED"
    fi
    [[ "$SESSION_OUT" == *"PROBE<<<"* ]] && return "$PROBE_REACHED"
    return "$PROBE_NOT_REACHED"
}
# What one probe() outcome was, for a failure message.
probe_said() {  # <probe status>
    case "$1" in
        "$PROBE_REACHED") echo "reached the probe" ;;
        "$PROBE_NOT_REACHED") echo "did not reach the probe" ;;
        *) echo "session failed ($(session_said))" ;;
    esac
}

# ------------------------------------------------------------ A: collision ---
session "$P" "/plan-task"
a_own="$(session_said)"
own=false
[[ "$SESSION_RC" -eq 0 && "$SESSION_OUT" == *"PROJECT-OWN-PLAN-TASK"* ]] && own=true
probe "$P" "/$NAME:zz-probe"; a_plug=$?
if [[ "$own" == true && "$a_plug" -eq "$PROBE_REACHED" ]]; then
    pass "A: bare /plan-task is still the project's own, and /$NAME:<skill> reaches the plugin"
else
    fail "A: collision case (/plan-task: $a_own; /$NAME:zz-probe $(probe_said "$a_plug"))"
fi

# -------------------------------------------------- B: worktree inherits ---
git -C "$P" worktree add -q "$P/worktrees/wt" 2>/dev/null
probe "$P/worktrees/wt" "/$NAME:zz-probe"; b=$?
[[ "$b" -eq "$PROBE_REACHED" ]] \
    && pass "B: a worktree of the project inherits the plugin" \
    || fail "B: in a worktree, /$NAME:zz-probe $(probe_said "$b")"

# ------------------------------------------------- C: unrelated repo ---
# A control first: the repo's own skill must answer, so a session there is
# known to work and to dispatch slash commands at all.
session "$U" "/zz-control"
c_ctl="$(session_said)"
ctl=false
[[ "$SESSION_RC" -eq 0 && "$SESSION_OUT" == *"UNRELATED-CONTROL"* ]] && ctl=true
probe "$U" "/$NAME:zz-probe"; c=$?
if [[ "$ctl" == true && "$c" -eq "$PROBE_NOT_REACHED" ]]; then
    pass "C: an unrelated repo has no $NAME: skill (its own control skill answered)"
elif [[ "$ctl" != true ]]; then
    fail "C: the unrelated repo's control skill did not answer, so the negative proves nothing ($c_ctl)"
else
    fail "C: in an unrelated repo, /$NAME:zz-probe $(probe_said "$c")"
fi

# ------------------------------------------------- D: workspace root ---
probe "$W" "/zz-probe"; d_bare=$?
d_bare_said="$(probe_said "$d_bare")"
probe "$W" "/$NAME:zz-probe"; d_plug=$?
if [[ "$d_bare" -eq "$PROBE_REACHED" && "$d_plug" -eq "$PROBE_NOT_REACHED" ]]; then
    pass "D: a workspace-root session has the skill bare and not under $NAME: (loaded once)"
else
    fail "D: workspace-root shape (bare /zz-probe $d_bare_said; /$NAME:zz-probe $(probe_said "$d_plug"))"
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
probe "$W/projects/inner" "/zz-probe"; e_bare=$?
e_bare_said="$(probe_said "$e_bare")"
probe "$W/projects/inner" "/$NAME:zz-probe"; e_plug=$?
if [[ "$e_bare" -eq "$PROBE_REACHED" && "$e_plug" -eq "$PROBE_NOT_REACHED" ]]; then
    pass "E: a session in that root has the skill bare and not under $NAME:"
else
    fail "E: p11-shape session (bare /zz-probe $e_bare_said; /$NAME:zz-probe $(probe_said "$e_plug"))"
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
probe "$W" "/zz-probe"; f=$?
bare_val="$(probe_value "$SESSION_OUT")"
if [[ "$f" -eq "$PROBE_REACHED" && -z "$(prefix_for "$bare_val")" ]]; then
    pass "F: loaded bare, \${CLAUDE_PLUGIN_ROOT} does not name the workspace (got '$bare_val') -- prefix empty"
else
    fail "F: bare-load probe (/zz-probe $(probe_said "$f"); value '$bare_val')"
fi
probe "$P" "/$NAME:zz-probe"; f=$?
plug_val="$(probe_value "$SESSION_OUT")"
if [[ "$f" -eq "$PROBE_REACHED" && "$(prefix_for "$plug_val")" == "$NAME:" ]]; then
    pass "F: loaded through the plugin, \${CLAUDE_PLUGIN_ROOT} is the workspace source -- prefix $NAME:"
else
    fail "F: plugin-load probe (/$NAME:zz-probe $(probe_said "$f"); value '$plug_val')"
fi
# ------------------------------------------- G: parent= instance ---
# The installer enables a parent= root and SKIPS each instance inside it,
# on the assumption that a session in the instance sees the parent's
# local-scope settings. This is that assumption, checked: the plugin is
# enabled at the parent only, and sessions in the instance directory and in
# a git repo inside it (a package of a colcon-style instance) must reach it.
# If this fails, skip-instance in user_tier_install.sh is wrong, and each
# instance must be enabled as a root of its own.
mkdir -p "$FAM/inst/src/pkg"
git -C "$FAM/inst/src/pkg" init -q
if enable_in "$FAM"; then
    probe "$FAM/inst" "/$NAME:zz-probe"; g_inst=$?
    g_inst_said="$(probe_said "$g_inst")"
    probe "$FAM/inst/src/pkg" "/$NAME:zz-probe"; g_pkg=$?
    if [[ "$g_inst" -eq "$PROBE_REACHED" && "$g_pkg" -eq "$PROBE_REACHED" ]]; then
        pass "G: sessions inside a parent= instance see the plugin enabled at the parent"
    else
        fail "G: parent= instance (instance dir: $g_inst_said; package repo: $(probe_said "$g_pkg"))"
    fi
else
    fail "G: could not enable the $NAME plugin in the parent root"
fi

# ------------------------------------------------- H: a second root ---
# The installer runs `marketplace add` of the same name and source once per
# registered root, and the registration flow (#332) does it again for each
# new one. The CLI keeps one machine-level record per marketplace name, so
# the second add must succeed and leave the first root working.
mkdir -p "$P2"
git -C "$P2" init -q
if enable_in "$P2"; then
    jq -e --arg id "$NAME@$NAME" --arg m "$NAME" --arg w "$W" \
        '.enabledPlugins[$id] == true and .extraKnownMarketplaces[$m].source.path == $w' \
        "$P2/.claude/settings.local.json" >/dev/null \
        && pass "H: a second root's marketplace add + install writes its own settings.local.json" \
        || fail "H: the second root's settings.local.json does not enable $NAME from $W"
    probe "$P2" "/$NAME:zz-probe"; h2=$?
    h2_said="$(probe_said "$h2")"
    probe "$P" "/$NAME:zz-probe"; h1=$?
    if [[ "$h2" -eq "$PROBE_REACHED" && "$h1" -eq "$PROBE_REACHED" ]]; then
        pass "H: the plugin reaches sessions in both roots after the second enable"
    else
        fail "H: two roots (second: $h2_said; first, re-checked: $(probe_said "$h1"))"
    fi
else
    fail "H: marketplace add + install of the same source failed in a second root"
fi

echo ""
echo "plugin_acceptance: $PASS passed, $FAIL failed (model: $MODEL)"
[ "$FAIL" -eq 0 ]
