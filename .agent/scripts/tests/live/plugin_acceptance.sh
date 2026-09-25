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
# `aw-accept-<pid>` (per run, so two concurrent runs never share a name, a
# machine-level record or a plugin cache), so the records the CLI keeps under
# ~/.claude/plugins/ never gain or lose an `agent-workspace` entry. On exit
# it removes both records it adds, the copy of the plugin the CLI leaves
# in ~/.claude/plugins/cache/aw-accept-<pid>/ (which `plugin uninstall` does not
# delete; Claude Code only marks it orphaned), and the ~/.claude/projects/
# directory (transcripts, memory) each session leaves for its cwd -- only
# those named from this run's own sandbox path. Cases, each asserting on
# what a real session reports:
#   A  collision: in a repo with its own plan-task, bare /plan-task is still
#      the project's, and /aw-accept-<pid>:<skill> reaches the plugin;
#   B  a git worktree of that repo, OUTSIDE the project's directory,
#      inherits the plugin (so it is worktree inheritance, not directory
#      walk-up, that reaches it);
#   C  an unrelated repo has no aw-accept-<pid>: skill (its own control skill
#      answering first, so the session is known to work);
#   D  a session at the workspace root has the skills bare, not also
#      under aw-accept-<pid>: (never doubled);
#   E  p11 shape: a registered root inside the workspace's git tree is
#      skipped by the installer (sandbox HOME; the CLI is a stub that fails
#      loudly if called) and its session has them bare, once;
#   F  run-issue's prefix step: sessions at the workspace root and at a
#      project root run the real skill_prefix.sh through the Bash tool and
#      report bare and agent-workspace: respectively; an unregistered repo
#      makes the script fail rather than guess;
#   G  parent= instances: which shapes see the plugin enabled at their
#      parent (a worktree or plain directory of a git-repo parent) and which
#      do not (a plain-directory parent's instance, a separate repo nested
#      in the parent), and that the installer's verdicts match;
#   H  a second root: the same marketplace added and installed from another
#      project root (the per-root path the installer and #332 take) works
#      there and leaves the first root working;
#   I  the installer's machine-level takeover: a `marketplace add` of a
#      second copy of the source, run from a scratch directory outside any
#      project and git repository, repoints the CLI's machine record, and
#      the record survives the scratch directory's removal and a later CLI
#      run; it is then taken back the same way;
#   J  removing the plugin from one root (uninstall + local `marketplace
#      remove`): what it does to the machine record and to another root is
#      printed as FACT lines, and re-taking a dropped record the way the
#      installer's step 6c does must restore the other root;
#   K  a local-scope add from a plain subdirectory of a git repo writes
#      the repo toplevel's settings (why the installer refuses to run the
#      CLI from such a directory).
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
# Per run: the CLI keys its machine-level records and plugin cache by this
# name, so a fixed one would let two concurrent runs remove each other's.
NAME="aw-accept-$$"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Every root the suite enables the plugin in, recorded BEFORE the CLI runs
# there, so a half-finished enable is still undone on exit.
ENABLED_ROOTS=()
# Every `claude plugin` call, stdin closed, so a prompt the CLI might show
# fails the call instead of hanging the suite.
cli_plugin() { claude plugin "$@" </dev/null; }

# The CLI's machine-level record of this run's marketplace, and its source.
KM="${CLAUDE_CONFIG_DIR:-${HOME:?}/.claude}/plugins/known_marketplaces.json"
km_source() {
    jq -r --arg m "$NAME" '.[$m].source.path? // empty' "$KM" 2>/dev/null || true
}
# session_dirs <projects dir> <sandbox>: the Claude Code project directories
# this run's sessions left. Claude Code names one per session cwd, from the
# path with every character but [A-Za-z0-9] turned into `-`. Matched
# strictly: exactly the sandbox's own encoded name, or it followed by `-`
# (a path below it) -- never a broader glob -- and only for a sandbox with
# this suite's mktemp name, whose random suffix makes the name this run's.
# A name Claude Code shortened (very long paths) does not match, and stays.
session_dirs() {
    local enc d
    [[ "$(basename "${2:?}")" == aw-plugin-accept.?* ]] || return 0
    enc="$(printf '%s' "$2" | sed 's/[^A-Za-z0-9]/-/g')"
    for d in "$1"/*; do
        [[ -d "$d" ]] || continue
        case "$(basename "$d")" in
            "$enc"|"$enc"-*) printf '%s\n' "$d" ;;
        esac
    done
}
# sandbox_install [args]: the workspace copy's installer against the sandbox
# HOME, its CLI a stub that only fails. CLAUDE_CONFIG_DIR is dropped: the
# installer reads the CLI's records under it when set, so an inherited one
# would point the copy at the owner's real records (a real `agent-workspace`
# entry reads as foreign, and the takeover calls the failing stub).
sandbox_install() {
    env -u CLAUDE_CONFIG_DIR HOME="$SANDBOX/home" AGENT_WORKSPACE_CLAUDE_BIN="$SANDBOX/bin/claude" \
        bash "$W/.agent/scripts/user_tier_install.sh" "$@"
}
# sandbox_safe <path>: may cleanup() `rm -rf` this as the sandbox? Only a
# directory with this suite's mktemp name, never the filesystem root, the
# directory the suite runs from, or one containing it. An empty path fails
# too: `cd ""` succeeds in bash, so an unchecked empty SANDBOX would turn
# into the current directory.
sandbox_safe() {
    local p="${1:-}" phys here
    [[ -n "$p" && -d "$p" ]] || return 1
    [[ "$(basename "$p")" == aw-plugin-accept.?* ]] || return 1
    phys="$(cd "$p" && pwd -P)" || return 1
    here="$(pwd -P)" || return 1
    [[ "$phys" != / && "$phys" != "$here" && "$here" != "$phys"/* ]]
}
# new_sandbox: print the pwd -P form of a fresh sandbox, or fail. The
# distinctive mktemp name is what cleanup() matches session directories by,
# so its random suffix keeps that match to this run.
new_sandbox() {
    local s
    s="$(mktemp -d -t aw-plugin-accept.XXXXXXXXXX)" || return 1
    [[ -n "$s" ]] || return 1
    s="$(cd "$s" && pwd -P)" || return 1
    sandbox_safe "$s" || return 1
    printf '%s\n' "$s"
}
cleanup() {
    local r
    for r in ${ENABLED_ROOTS[@]+"${ENABLED_ROOTS[@]}"}; do
        [[ -d "$r" ]] || continue
        (cd "$r" && cli_plugin uninstall "$NAME@$NAME" --scope local >/dev/null 2>&1)
        (cd "$r" && cli_plugin marketplace remove "$NAME" --scope local >/dev/null 2>&1)
    done
    # The machine record for this run's name, if the local removes above
    # left it (whether they do is case J's FACT): a best-effort remove at
    # the CLI's default scope, from the sandbox, for this run's name only.
    if [[ -n "$(km_source)" ]]; then
        (cd "${SANDBOX:-/nonexistent}" 2>/dev/null && cli_plugin marketplace remove "$NAME" >/dev/null 2>&1)
        [[ -n "$(km_source)" ]] && echo "plugin_acceptance: WARNING: $KM still has a $NAME entry -- remove it with: claude plugin marketplace remove $NAME" >&2
    fi
    # The CLI's cached copy of the plugin, which uninstall leaves behind.
    # Only after an enable, and only this run's own `aw-accept-<pid>` name.
    if [[ ${#ENABLED_ROOTS[@]} -gt 0 ]]; then
        rm -rf "${CLAUDE_CONFIG_DIR:-${HOME:?}/.claude}/plugins/cache/${NAME:?}"
    fi
    if ! sandbox_safe "${SANDBOX:-}"; then
        echo "plugin_acceptance: WARNING: not removing sandbox '${SANDBOX:-}' (not this suite's own directory)" >&2
        return 0
    fi
    # The CLI's configuration home: CLAUDE_CONFIG_DIR when set, else
    # ~/.claude. Observed for plugins/ (claude 2.1.282); for projects/ it
    # is assumed, and a wrong guess is harmless -- the strict match then
    # finds nothing to remove.
    local d
    while IFS= read -r d; do
        rm -rf "$d"
    done < <(session_dirs "${CLAUDE_CONFIG_DIR:-${HOME:?}/.claude}/projects" "$SANDBOX")
    rm -rf "${SANDBOX:?}"
}
# Created and checked BEFORE the trap is set: with no sandbox there is
# nothing to clean up, and nothing below may run.
SANDBOX="$(new_sandbox)" || { echo "FATAL: could not create the sandbox directory (mktemp or cd failed)" >&2; exit 1; }
trap cleanup EXIT
W="$SANDBOX/ws"       # the workspace copy (marketplace $NAME)
P="$SANDBOX/proj"     # a project with its own plan-task
U="$SANDBOX/other"    # an unrelated repo
FAM="$SANDBOX/fam"    # a parent= root: a plain directory grouping instances
FAMG="$SANDBOX/famg"  # a parent= root that is itself a git repo
P2="$SANDBOX/proj2"   # a second project root, enabled after the first


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
sandbox_install --generate-plugin-manifest >/dev/null \
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

Reply with exactly the following line, copied character for character, and nothing else:

PROJECT-OWN-PLAN-TASK
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

Reply with exactly the following line, copied character for character, and nothing else:

UNRELATED-CONTROL
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
# Outside $P on purpose: a worktree inside the project directory would also
# be reached by directory walk-up, so it could not show that the plugin
# follows the worktree itself.
git -C "$P" worktree add -q "$SANDBOX/proj-wt" 2>/dev/null
probe "$SANDBOX/proj-wt" "/$NAME:zz-probe"; b=$?
[[ "$b" -eq "$PROBE_REACHED" ]] \
    && pass "B: a worktree of the project outside its directory inherits the plugin" \
    || fail "B: in a worktree outside the project, /$NAME:zz-probe $(probe_said "$b")"

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
iout="$(sandbox_install 2>&1)"
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
# run-issue's prefix step as a session runs it: the real skill_prefix.sh,
# through the Bash tool, in a workspace-root session (bare, where D showed
# the skills load bare) and a project-root session (prefixed, where A showed
# them under the plugin). The session's answer must be the script's own
# line, which the suite also gets by running the script directly -- nothing
# the model has to copy or interpret decides the prefix. And a location
# the script has no rule for (the unrelated repo) makes it fail, not guess.
SPS="$W/.agent/scripts/skill_prefix.sh"
tool_session() {  # <dir> <prompt>: one headless session allowed to run only $SPS
    SESSION_OUT="$(cd "$1" && timeout 300 claude -p "$2" --model "$MODEL" \
        --allowedTools "Bash($SPS)" "Bash($SPS:*)" "Bash(bash $SPS)" 2>&1 </dev/null)"
    SESSION_RC=$?
    return "$SESSION_RC"
}
printf 'proj single_project %s\n' "$P" > "$W/.agent/projects.local"
# (skill_prefix.sh prints the installer's plugin name, agent-workspace:,
# whatever the copy's plugin is called.)
for fcase in "workspace root:$W:skill_prefix=" "project root:$P:skill_prefix=agent-workspace:"; do
    flabel="${fcase%%:*}"; frest="${fcase#*:}"; fdir="${frest%%:*}"; fwant="${frest#*:}"
    fdirect="$(cd "$fdir" && bash "$SPS" 2>&1)"
    tool_session "$fdir" "Run the command $SPS with the Bash tool, then reply with exactly the one line it printed, copied character for character, and nothing else."
    fgot="$(grep -Eo 'skill_prefix=[a-z-]*:?' <<< "$SESSION_OUT" | tail -n1)"
    if [[ "$fdirect" == "$fwant" && "$SESSION_RC" -eq 0 && "$fgot" == "$fwant" ]]; then
        pass "F: in a $flabel session, run-issue's prefix step (the real script, via the Bash tool) gives '$fwant'"
    else
        fail "F: $flabel (script run directly: '$fdirect', wanted '$fwant'; session $(session_said) -> '$fgot')"
    fi
done
fdirect="$(cd "$U" && bash "$SPS" 2>&1)"; frc=$?
[[ "$frc" -eq 1 && "$fdirect" == *"nor in any registered project root"* ]] \
    && pass "F: in an unregistered repo the prefix step fails with a reason instead of guessing" \
    || fail "F: unregistered repo (exit $frc: $fdirect)"
rm -f "$W/.agent/projects.local"
# ------------------------------------------- G: parent= instance ---
# Which instance shapes see the plugin enabled at their parent. Observed
# with claude 2.1.282: a session reads the local settings of its git
# toplevel (the main repository's, for a worktree). So a plain-directory
# parent reaches none of its instances, and a git-repo parent reaches a
# worktree of it and a plain directory in it, not a separate repository
# nested in it. user_tier_install.sh's same_project() encodes exactly this;
# the last check below runs the installer over these shapes and holds its
# verdicts to what the sessions showed. A change in either fails here.
mkdir -p "$FAM/inst/src/pkg"
git -C "$FAM/inst/src/pkg" init -q
if enable_in "$FAM"; then
    probe "$FAM/inst" "/$NAME:zz-probe"; g_inst=$?
    g_inst_said="$(probe_said "$g_inst")"
    probe "$FAM/inst/src/pkg" "/$NAME:zz-probe"; g_pkg=$?
    if [[ "$g_inst" -eq "$PROBE_NOT_REACHED" && "$g_pkg" -eq "$PROBE_NOT_REACHED" ]]; then
        pass "G: a plain-directory parent's enable reaches neither its instance nor a repo inside it (so the installer enables such instances)"
    else
        fail "G: plain-directory parent (instance dir: $g_inst_said; package repo: $(probe_said "$g_pkg")) -- wanted 'did not reach' for both"
    fi
else
    fail "G: could not enable the $NAME plugin in the parent root"
fi
mkdir -p "$FAMG/inst" "$FAMG/plain"
git -C "$FAMG" init -q
git -C "$FAMG" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$FAMG/inst" init -q
git -C "$FAMG" worktree add -q "$FAMG/wt" 2>/dev/null
if enable_in "$FAMG"; then
    probe "$FAMG/inst" "/$NAME:zz-probe"; g_repo=$?
    g_repo_said="$(probe_said "$g_repo")"
    probe "$FAMG/wt" "/$NAME:zz-probe"; g_wt=$?
    g_wt_said="$(probe_said "$g_wt")"
    probe "$FAMG/plain" "/$NAME:zz-probe"; g_plain=$?
    if [[ "$g_repo" -eq "$PROBE_NOT_REACHED" && "$g_wt" -eq "$PROBE_REACHED" && "$g_plain" -eq "$PROBE_REACHED" ]]; then
        pass "G: a git-repo parent's enable reaches a worktree and a plain directory of it, not a separate repo inside it"
    else
        fail "G: git-repo parent (separate repo: $g_repo_said, wanted not reached; worktree: $g_wt_said, plain dir: $(probe_said "$g_plain"), wanted reached)"
    fi
else
    fail "G: could not enable the $NAME plugin in the git-repo parent root"
fi
# The installer's verdicts on the same shapes (sandbox HOME; its CLI is a
# stub that only fails, so nothing is enabled -- only what it decides).
cat > "$W/.agent/projects.local" <<REG
fam       project         $FAM
fam-inst  single_project  $FAM/inst    parent=fam
famg      project         $FAMG
famg-inst single_project  $FAMG/inst   parent=famg
famg-wt   single_project  $FAMG/wt     parent=famg
famg-pl   single_project  $FAMG/plain  parent=famg
REG
gout="$(sandbox_install 2>&1)"
rm -f "$W/.agent/projects.local"
if [[ "$gout" == *"fam-inst is a parent= instance that is in no git repository"* \
      && "$gout" == *"famg-inst is a parent= instance that is a git repository of its own"* \
      && "$gout" == *"skipped famg-wt: a parent= instance"* && "$gout" == *"skipped famg-pl: a parent= instance"* ]]; then
    pass "G: the installer skips exactly the instances the sessions showed reached, and enables the rest"
else
    fail "G: installer verdicts differ from what the sessions showed ($(tr '\n' ' ' <<< "$gout" | cut -c1-600))"
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

# ------------------------------------------- I: machine-level takeover ---
# What user_tier_install.sh's claim_machine_record does, with this run's
# name: one `marketplace add` of another source from a scratch directory
# that is in no project and no git repository.
W2="$SANDBOX/ws2"
cp -r "$W" "$W2"
claim_from_scratch() {  # <source>: add it from a fresh scratch dir, then remove the dir
    local scr="$SANDBOX/claim-scratch" rc
    mkdir -p "$scr"
    if git -C "$scr" rev-parse --show-toplevel >/dev/null 2>&1; then
        rm -rf "$scr"; return 2
    fi
    (cd "$scr" && cli_plugin marketplace add "$1" --scope local >/dev/null 2>&1); rc=$?
    rm -rf "$scr"
    return "$rc"
}
i_before="$(km_source)"
echo "  FACT: machine record of $NAME before the takeover: ${i_before:-<none>}"
claim_from_scratch "$W2"; i_rc=$?
i_after="$(km_source)"
echo "  FACT: scratch-dir add of a second source: exit $i_rc; record now ${i_after:-<none>}"
if [[ "$i_rc" -eq 0 && "$i_after" == "$W2" ]]; then
    pass "I: a scratch-dir marketplace add repoints the machine record to the new source"
else
    fail "I: scratch-dir takeover (exit $i_rc; record '${i_after:-<none>}', wanted $W2)"
fi
# A later CLI run from an enabled root, which might reconcile the record
# against the declarations it can see (the scratch one is gone).
(cd "$P" && cli_plugin marketplace list >/dev/null 2>&1)
i_later="$(km_source)"
echo "  FACT: record after the scratch dir's removal and a CLI run in $P: ${i_later:-<none>}"
[[ "$i_later" == "$W2" ]] \
    && pass "I: the taken-over record survives the scratch directory's removal and a later CLI run" \
    || fail "I: the record did not survive (now '${i_later:-<none>}')"
claim_from_scratch "$W"; i_back=$?
[[ "$i_back" -eq 0 && "$(km_source)" == "$W" ]] \
    && pass "I: taken back the same way (last install wins)" \
    || fail "I: taking the record back failed (exit $i_back; record '$(km_source)')"

# --------------------------------------- J: removal from one root ---
# The installer removes the plugin from doubled roots and instances with
# uninstall + local `marketplace remove`, and then re-reads the machine
# record. What that remove does to the record, and that it leaves other
# roots working.
j_before="$(km_source)"
(cd "$P2" && cli_plugin uninstall "$NAME@$NAME" --scope local >/dev/null 2>&1)
(cd "$P2" && cli_plugin marketplace remove "$NAME" --scope local >/dev/null 2>&1); j_rc=$?
j_after="$(km_source)"
echo "  FACT: local marketplace remove in $P2 (exit $j_rc): record ${j_before:-<none>} -> ${j_after:-<none>}"
echo "  FACT: $P2 settings.local.json after uninstall + remove: $(tr -d '\n ' < "$P2/.claude/settings.local.json" 2>/dev/null || echo '<absent>')"
probe "$P" "/$NAME:zz-probe"; j=$?
echo "  FACT: right after that remove, /$NAME:zz-probe in $P $(probe_said "$j")"
# The installer's repair for this (its step 6c): take the record back with
# the same scratch-dir add, after which the other root must reach it again.
if [[ -z "$(km_source)" ]]; then
    claim_from_scratch "$W"; j_claim=$?
    probe "$P" "/$NAME:zz-probe"; j2=$?
    [[ "$j_claim" -eq 0 && "$j2" -eq "$PROBE_REACHED" ]] \
        && pass "J: re-taking the dropped record (installer step 6c) restores the plugin in the other root" \
        || fail "J: after re-taking the record (exit $j_claim), /$NAME:zz-probe in $P $(probe_said "$j2")"
else
    [[ "$j" -eq "$PROBE_REACHED" ]] \
        && pass "J: the record survived the remove, and the other root still reaches the plugin" \
        || fail "J: record kept, but /$NAME:zz-probe in $P $(probe_said "$j")"
fi

# ------------------------- K: local scope from a subdir of a git repo ---
# The installer refuses to run the CLI from a plain directory inside a git
# repository (enclosing_repo), on the ground that local scope from there
# lands on the repository's toplevel. Checked against a repository that
# declares nothing yet, so "wrote the toplevel's file" and "wrote nothing"
# cannot be confused: the declaration must appear at the toplevel, and not
# in the subdirectory.
KR="$SANDBOX/krepo"
mkdir -p "$KR/sub"
git -C "$KR" init -q
ENABLED_ROOTS+=("$KR")
(cd "$KR/sub" && cli_plugin marketplace add "$W" --scope local >/dev/null 2>&1); k_rc=$?
if [[ "$k_rc" -eq 0 && ! -e "$KR/sub/.claude/settings.local.json" ]] \
   && jq -e --arg m "$NAME" '.extraKnownMarketplaces[$m] != null' "$KR/.claude/settings.local.json" >/dev/null 2>&1; then
    pass "K: a local-scope add from a plain subdirectory of a git repo writes the repo toplevel's settings.local.json"
else
    fail "K: local scope from $KR/sub (exit $k_rc; toplevel file: $(tr -d '\n ' < "$KR/.claude/settings.local.json" 2>/dev/null || echo '<absent>'); sub file: $([[ -e "$KR/sub/.claude/settings.local.json" ]] && echo present || echo absent))"
fi

echo ""
echo "plugin_acceptance: $PASS passed, $FAIL failed (model: $MODEL)"
[ "$FAIL" -eq 0 ]
