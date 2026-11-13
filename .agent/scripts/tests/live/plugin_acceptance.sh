#!/usr/bin/env bash
# .agent/scripts/tests/live/plugin_acceptance.sh
# Live acceptance for the agent-workspace plugin (ADR-0018, #345, #446),
# ported from the 2026-09-24 plugin spike. OPT-IN: it starts real headless
# Claude Code sessions (`claude -p`, auth and a few cents each), so it lives
# outside tests/test_*.sh and run_script_tests.sh never collects it.
#
#   PLUGIN_ACCEPTANCE=1 bash .agent/scripts/tests/live/plugin_acceptance.sh
#   PLUGIN_ACCEPTANCE=1 PLUGIN_ACCEPTANCE_CASES=user bash .agent/scripts/tests/live/plugin_acceptance.sh
#   (PLUGIN_ACCEPTANCE_CASES picks the cases: `per-root`, the default, runs
#   A to D and F; `user` runs only the user-scope cases U0 to U8; `all` runs
#   A to D and F, then U0 to U8. LIVE_MODEL=<alias> picks the session model;
#   default haiku)
#
# What it touches. It never touches this checkout or the real registry. It
# works on a COPY of the checkout whose plugin and marketplace are renamed
# `aw-accept-<pid>` (per run, so two concurrent runs never share a name, a
# machine-level record or a plugin cache), so the records the CLI keeps
# under ~/.claude/plugins/ never gain or lose an `agent-workspace` entry,
# and the real `agent-workspace` entries in ~/.claude/settings.json are
# never named, read for a decision or written by the suite. Below,
# ~/.claude is $CLAUDE_CONFIG_DIR when that is set.
#   - The per-root cases (A to D, F) never touch ~/.claude/settings.json.
#   - The user-scope cases (U0 to U8) DO change ~/.claude/settings.json, for
#     the minutes they take: `claude plugin marketplace add <the copy>
#     --scope user` and `claude plugin install
#     aw-accept-<pid>@aw-accept-<pid> --scope user` add
#     `extraKnownMarketplaces["aw-accept-<pid>"]` and
#     `enabledPlugins["aw-accept-<pid>@aw-accept-<pid>"] = true` there (the
#     CLI rewrites the whole file to do it). Meanwhile every Claude Code
#     session started anywhere on the machine also gets the test plugin's
#     skills under `aw-accept-<pid>:`. Both entries are removed with
#     `claude plugin uninstall aw-accept-<pid>@aw-accept-<pid> --scope user`
#     and `claude plugin marketplace remove aw-accept-<pid> --scope user`,
#     at the end of the cases and again on exit (EXIT, INT, TERM, HUP) if
#     they are still there. The two commands are printed at the start, for a
#     run killed in a way no trap sees. The file is compared under `jq -S`
#     before and after: empty objects the removal leaves behind are
#     expected; any other difference is printed as a FACT, not counted as a
#     failure (the CLI's rewrite races other sessions' writes to the file).
# On exit it removes both records it adds, the copy of the plugin the CLI
# leaves in ~/.claude/plugins/cache/aw-accept-<pid>/ (which `plugin
# uninstall` does not delete; Claude Code only marks it orphaned), and the
# ~/.claude/projects/ directory (transcripts, memory) each session leaves for
# its cwd -- only those named from this run's own sandbox path. Cases, each
# asserting on what a real session reports:
#   A  collision: in a repo with its own plan-task, bare /plan-task is still
#      the project's, and /aw-accept-<pid>:<skill> reaches the plugin;
#   B  a git worktree of that repo, OUTSIDE the project's directory,
#      inherits the plugin (so it is worktree inheritance, not directory
#      walk-up, that reaches it);
#   C  an unrelated repo has no aw-accept-<pid>: skill (its own control skill
#      answering first, so the session is known to work);
#   D  a session at the workspace root has the skills bare, not also
#      under aw-accept-<pid>: (never doubled);
#   F  run-issue's prefix step: sessions at the workspace root and at a
#      project root run the real skill_prefix.sh through the Bash tool and
#      report bare and agent-workspace: respectively; an unregistered repo
#      gets agent-workspace: too (the plugin is at user scope; #446).
#   (Cases E and G to K, retired by #446, tested the per-root enable the
#   installer no longer does: the p11-shape skip, parent= instance shapes,
#   a second root, the machine-record takeover, removal from one root, and
#   local scope from a subdirectory. The user-scope cases below replace
#   them.)
# User-scope cases (#446 plan, pull request B step 1), run with this run's
# plugin enabled at user scope:
#   U0 setup: the copy gets the off entry
#      `"aw-accept-<pid>@aw-accept-<pid>": false` under `enabledPlugins` in
#      its .claude/settings.json, committed in the copy (what the plan's step
#      5 commits for the real plugin, under this run's name), and the plugin
#      is enabled at user scope from a directory in no git repository;
#   U1 a session at the committed-off repository's root lists the skill
#      bare, not also under aw-accept-<pid>:;
#   U2 a session in a plain subdirectory root of it lists it under both
#      names (accepted by the owner, 2026-11-12: both run the same skill);
#   U3 a session in a worktree of it, outside its directory, lists it once,
#      bare, as U1;
#   U4 a session in an in-tree root (the p11 shape: a root inside the
#      copy's tree, ignored by its git, with no .git of its own) lists both
#      names, as U2;
#   U5 a session in a repository nested in an ordinary root lists
#      /aw-accept-<pid>:<skill>;
#   U6 the same in an unregistered folder (in no git repository);
#   U7 local `true` plus user `true`: lists it, once;
#   U8 a root whose local entry is `false` under user `true` does not list
#      it (its own control skill answering first).
# Each of U1 to U8 prints one FACT line: the bare and the prefixed probe's
# outcome and the zz-probe entries of the session's init command list (the
# slash commands the session was given). Each case is judged from that
# list; the probes decide only when the CLI printed no list. (The
# 2026-11-12 run showed a probe's outcome to be weaker evidence: a
# prefixed call "not reached" in U4 with both names listed, and a bare call
# "reached" in U5 and U6 with only the prefixed name listed.) The run then
# prints one STOP-CHECK line per stop condition of the plan's step 1, as
# amended by the owner's acceptance of the doubling (clear, FIRES, or
# UNDECIDED when a session failed), computed the same way.
#
# Exit: 0 all pass (or not opted in); 1 a case failed; 2 bad
# PLUGIN_ACCEPTANCE_CASES; 3 missing dependency.

set -uo pipefail

if [[ "${PLUGIN_ACCEPTANCE:-}" != 1 ]]; then
    echo "plugin_acceptance: opt-in live suite (real claude sessions) -- set PLUGIN_ACCEPTANCE=1 to run"
    exit 0
fi
case "${PLUGIN_ACCEPTANCE_CASES:-per-root}" in
    per-root) RUN_PER_ROOT=1; RUN_USER=0 ;;
    user)     RUN_PER_ROOT=0; RUN_USER=1 ;;
    all)      RUN_PER_ROOT=1; RUN_USER=1 ;;
    *) echo "FATAL: PLUGIN_ACCEPTANCE_CASES must be per-root, user or all (got '${PLUGIN_ACCEPTANCE_CASES}')" >&2; exit 2 ;;
esac
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

# The real user settings the user-scope cases change, and the hand removal
# for a run killed in a way no trap sees, printed at the start, before
# anything is created.
REAL_SETTINGS="${CLAUDE_CONFIG_DIR:-${HOME:?}/.claude}/settings.json"
user_removal_lines() {
    local env_prefix=""
    [[ -n "${CLAUDE_CONFIG_DIR:-}" ]] && env_prefix="CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR "
    echo "    ${env_prefix}claude plugin uninstall $NAME@$NAME --scope user"
    echo "    ${env_prefix}claude plugin marketplace remove $NAME --scope user"
}
if [[ "$RUN_USER" == 1 ]]; then
    echo "plugin_acceptance: the user-scope cases enable a test plugin, $NAME, at user scope in $REAL_SETTINGS"
    echo "  for the minutes they take, and remove it at the end and on exit. If this run is killed before"
    echo "  it can remove it, remove it by hand with:"
    user_removal_lines
    echo "  (and its cached copy: rm -rf ${CLAUDE_CONFIG_DIR:-${HOME:?}/.claude}/plugins/cache/$NAME)"
    echo ""
fi

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

# ------------------------------------------------- user-scope state ---
# The run's state about the real user settings (REAL_SETTINGS, above).
# USER_ENABLED is set BEFORE the enabling CLI call (as ENABLED_ROOTS is),
# so an interrupted call is still undone; it is cleared only when the
# settings read back without this run's entries. USER_TOUCHED stays set,
# so the plugin cache is removed on exit. REAL_BEFORE is the file's `jq -S`
# form taken just before the enable.
USER_ENABLED=0
USER_TOUCHED=0
REAL_BEFORE=""
REAL_COMPARED=0
# user_scope_entries: this run's two entries in the real user settings, as
# one line for a FACT. Names only this run's id and marketplace.
user_scope_entries() {
    [[ -e "$REAL_SETTINGS" ]] || { echo "<no settings file>"; return 0; }
    jq -r --arg id "$NAME@$NAME" --arg m "$NAME" '
        "enabledPlugins[\($id)]=" + ((.enabledPlugins // {}) | if has($id) then (.[$id] | tostring) else "<none>" end)
        + " extraKnownMarketplaces[\($m)].source.path=" + ((.extraKnownMarketplaces // {}) | if has($m) then (.[$m].source.path? // "<no path>" | tostring) else "<none>" end)
    ' "$REAL_SETTINGS" 2>/dev/null || echo "<settings file does not parse>"
}
# user_scope_gone: true when the real user settings hold neither entry.
user_scope_gone() {
    [[ -e "$REAL_SETTINGS" ]] || return 0
    jq -e --arg id "$NAME@$NAME" --arg m "$NAME" \
        '((.enabledPlugins // {}) | has($id) | not) and ((.extraKnownMarketplaces // {}) | has($m) | not)' \
        "$REAL_SETTINGS" >/dev/null 2>&1
}
# neutral_dir: a directory in no git repository to run the user-scope CLI
# calls from: the sandbox when it is safe and outside git, else /.
neutral_dir() {
    if sandbox_safe "${SANDBOX:-}" && ! git -C "$SANDBOX" rev-parse --show-toplevel >/dev/null 2>&1; then
        printf '%s\n' "$SANDBOX"
    else
        printf '/\n'
    fi
}
# user_scope_remove: undo this run's user-scope enable. Clears USER_ENABLED
# only when the settings read back without this run's entries, so cleanup()
# tries again otherwise.
user_scope_remove() {
    local d
    d="$(neutral_dir)"
    (cd "$d" && cli_plugin uninstall "$NAME@$NAME" --scope user >/dev/null 2>&1)
    (cd "$d" && cli_plugin marketplace remove "$NAME" --scope user >/dev/null 2>&1)
    user_scope_gone || return 1
    USER_ENABLED=0
}
# real_settings_snapshot <file>: its `jq -S` form, `<absent>` when there is
# no file; fails when it does not parse.
real_settings_snapshot() {
    [[ -e "$1" ]] || { echo "<absent>"; return 0; }
    jq -S . "$1"
}
# settings_pruned <snapshot>: the snapshot with every empty object removed
# (recursively), so entries the removal leaves as `{}` compare equal.
settings_pruned() {
    if [[ "$1" == "<absent>" ]]; then
        echo '{}'
        return 0
    fi
    jq -S 'def prune: if type == "object" then (with_entries(.value |= prune) | with_entries(select(.value != {}))) elif type == "array" then map(prune) else . end; prune' <<< "$1"
}
# real_settings_compare: once per run, after the user-scope removal: the
# real settings before and after, under `jq -S`. Prints FACT lines and the
# difference; never counts as a failure.
real_settings_compare() {
    [[ "$REAL_COMPARED" == 0 && -n "$REAL_BEFORE" ]] || return 0
    REAL_COMPARED=1
    local after pb pa
    if ! after="$(real_settings_snapshot "$REAL_SETTINGS" 2>/dev/null)"; then
        echo "  FACT: real settings: $REAL_SETTINGS no longer parses as JSON after the run (it did before)"
        return 0
    fi
    if [[ "$after" == "$REAL_BEFORE" ]]; then
        echo "  FACT: real settings: $REAL_SETTINGS is identical under jq -S before and after the run"
        return 0
    fi
    pb="$(settings_pruned "$REAL_BEFORE")"
    pa="$(settings_pruned "$after")"
    if [[ "$pb" == "$pa" ]]; then
        echo "  FACT: real settings: $REAL_SETTINGS differs only by empty objects left behind (expected)"
        return 0
    fi
    echo "  FACT: real settings: $REAL_SETTINGS changed beyond empty objects during the run (the CLI's rewrite, or another session's concurrent write); the difference, before -> after, empty objects removed:"
    diff -u <(printf '%s\n' "$pb") <(printf '%s\n' "$pa") | tail -n +3 | sed 's/^/    /'
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
# HOME, its CLI a stub that only fails (made in the setup below). The suite
# runs it only to regenerate the copy's plugin manifest, which calls no CLI.
# CLAUDE_CONFIG_DIR is dropped: the installer reads the CLI's records under
# it when set, so an inherited one would point the copy at the owner's real
# records.
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
    # Once in cleanup, a second signal must not cut it short.
    trap '' INT TERM HUP
    local r
    for r in ${ENABLED_ROOTS[@]+"${ENABLED_ROOTS[@]}"}; do
        [[ -d "$r" ]] || continue
        (cd "$r" && cli_plugin uninstall "$NAME@$NAME" --scope local >/dev/null 2>&1)
        (cd "$r" && cli_plugin marketplace remove "$NAME" --scope local >/dev/null 2>&1)
    done
    # The user-scope enable, if the cases' own removal did not run or did
    # not take; then the before/after comparison, if not yet printed.
    if [[ "$USER_ENABLED" == 1 ]] && ! user_scope_remove; then
        echo "plugin_acceptance: WARNING: $REAL_SETTINGS still has this run's entries ($(user_scope_entries)) -- remove them with:" >&2
        user_removal_lines >&2
    fi
    real_settings_compare
    # The machine record for this run's name, if the removes above left it
    # (a local remove dropped it in the 2026-10 per-root runs; whether every
    # remove does is not established): a best-effort remove at the CLI's
    # default scope, from the sandbox, for this run's name only.
    if [[ -n "$(km_source)" ]]; then
        (cd "${SANDBOX:-/nonexistent}" 2>/dev/null && cli_plugin marketplace remove "$NAME" >/dev/null 2>&1)
        [[ -n "$(km_source)" ]] && echo "plugin_acceptance: WARNING: $KM still has a $NAME entry -- remove it with: claude plugin marketplace remove $NAME" >&2
    fi
    # The CLI's cached copy of the plugin, which uninstall leaves behind.
    # Only after an enable, and only this run's own `aw-accept-<pid>` name.
    if [[ ${#ENABLED_ROOTS[@]} -gt 0 || "$USER_TOUCHED" == 1 ]]; then
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
# A signal exits, and the exit runs cleanup() once (EXIT is the one trap
# that cleans up; INT, TERM and HUP only turn the signal into an exit).
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
W="$SANDBOX/ws"       # the workspace copy (marketplace $NAME)
P="$SANDBOX/proj"     # a project with its own plan-task
U="$SANDBOX/other"    # an unrelated repo


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
mkdir -p "$SANDBOX/home" "$SANDBOX/bin"
printf '#!/bin/sh\necho "claude stub called: $*" >&2\nexit 1\n' > "$SANDBOX/bin/claude"
chmod +x "$SANDBOX/bin/claude"
sandbox_install --generate-plugin-manifest >/dev/null \
    || { echo "FATAL: could not regenerate the copy's manifest" >&2; exit 1; }
git -C "$W" init -q
(cd "$W" && cli_plugin validate . >/dev/null 2>&1) \
    && pass "the workspace copy validates as a marketplace" \
    || fail "claude plugin validate failed on the workspace copy"

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

# ==================================================== per-root cases ===
# A to D and F. Skipped with PLUGIN_ACCEPTANCE_CASES=user. Not
# re-indented: their heredocs write files whose first column matters (a
# SKILL.md's front matter). The block ends at the matching "end of the
# per-root cases" line.
if [[ "$RUN_PER_ROOT" == 1 ]]; then

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

# --------------------------------------------- F: prefix detection ---
# run-issue's prefix step as a session runs it: the real skill_prefix.sh,
# through the Bash tool, in a workspace-root session (bare, where D showed
# the skills load bare) and a project-root session (prefixed, where A showed
# them under the plugin). The session's answer must be the script's own
# line, which the suite also gets by running the script directly -- nothing
# the model has to copy or interpret decides the prefix. And an
# unregistered repo gets the plugin's names too: the script reads no
# registry, and the plugin is enabled once, at user scope (#446).
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
[[ "$frc" -eq 0 && "$fdirect" == "skill_prefix=agent-workspace:" ]] \
    && pass "F: in an unregistered repo the prefix step answers agent-workspace: (no registry read)" \
    || fail "F: unregistered repo (exit $frc: $fdirect)"
rm -f "$W/.agent/projects.local"

fi
# ============================================= end of the per-root cases ===

# ================================================== user-scope cases ===
# #446 plan, pull request B step 1: what sessions see with this run's
# plugin enabled at user scope in the real ~/.claude (see the header for
# what that changes and how it is removed). Skipped unless
# PLUGIN_ACCEPTANCE_CASES is user or all.

# us_session <dir> <prompt>: as session(), with --output-format stream-json
# (which needs --verbose with -p), so the session's init line also says
# which slash commands it was given. Sets SESSION_RC. SESSION_OUT is the
# result text when a result line was found (US_GOT_RESULT=1), else the raw
# output, so a failure message shows what the CLI said. SESSION_LISTED is
# the zz-probe entries of the init line's slash_commands, or a <...> note
# when the CLI printed no init line or no such list. That output shape is
# the CLI's stream-json init message as documented, not yet observed by
# this suite: a different shape is reported as such (a FAIL in U7, the one
# case that needs the list), never guessed. Never call it in $(...).
SESSION_LISTED=""
US_GOT_RESULT=0
us_session() {
    local raw res
    raw="$(cd "$1" && timeout 300 claude -p "$2" --model "$MODEL" --tools "" \
        --output-format stream-json --verbose 2>&1 </dev/null)"
    SESSION_RC=$?
    res="$(jq -Rr 'fromjson? | select(type == "object" and .type == "result") | (.result // empty) | tostring' <<< "$raw" 2>/dev/null)"
    if [[ -n "$res" ]]; then
        SESSION_OUT="$res"
        US_GOT_RESULT=1
    else
        SESSION_OUT="$raw"
        US_GOT_RESULT=0
    fi
    SESSION_LISTED="$(jq -Rr 'fromjson? | select(type == "object" and .type == "system" and .subtype == "init")
        | if (.slash_commands | type) == "array"
          then ([.slash_commands[] | tostring | select(endswith("zz-probe"))] | if length == 0 then "<none>" else join(",") end)
          else "<init line without slash_commands>" end' <<< "$raw" 2>/dev/null | head -n1)"
    [[ -n "$SESSION_LISTED" ]] || SESSION_LISTED="<no init line>"
    return "$SESSION_RC"
}
us_probe() {  # <dir> <slash command>: probe()'s three outcomes, through us_session()
    us_session "$1" "$2"
    if [[ "$SESSION_RC" -ne 0 || "$US_GOT_RESULT" -ne 1 ]]; then
        return "$PROBE_SESSION_FAILED"
    fi
    [[ "$SESSION_OUT" == *"PROBE<<<"* ]] && return "$PROBE_REACHED"
    return "$PROBE_NOT_REACHED"
}
probe_word() {  # <probe status>: one or two words, for a FACT line
    case "$1" in
        "$PROBE_REACHED") echo "reached" ;;
        "$PROBE_NOT_REACHED") echo "not reached" ;;
        *) echo "session failed" ;;
    esac
}
# Per case id: the two probe outcomes, what each session said (for a FAIL
# line), and the init command list's zz-probe entries.
declare -A U_BARE=() U_PLUG=() U_BARE_SAID=() U_PLUG_SAID=() U_LISTED=()
# us_case <id> <shape, in words> <dir> [extra FACT text]: the bare and the
# prefixed probe in <dir>, then the case's one FACT line.
us_case() {
    local b p
    us_probe "$3" "/zz-probe"; b=$?
    U_BARE_SAID[$1]="$(probe_said "$b")"
    U_LISTED[$1]="$SESSION_LISTED"
    us_probe "$3" "/$NAME:zz-probe"; p=$?
    U_PLUG_SAID[$1]="$(probe_said "$p")"
    # The first session's list, unless it had none and the second did.
    [[ "${U_LISTED[$1]}" == "<"* ]] && U_LISTED[$1]="$SESSION_LISTED"
    U_BARE[$1]=$b
    U_PLUG[$1]=$p
    echo "  FACT: $1 $2: bare /zz-probe $(probe_word "$b"); /$NAME:zz-probe $(probe_word "$p"); init command list: ${U_LISTED[$1]}${4:+; $4}"
}
# us_got <id> bare|plug: yes, no or unknown -- is that name in the case's
# init command list? From the list when the CLI printed one (an empty list
# is "<none>", which is evidence too); otherwise from the probe's outcome
# (reached = yes, not reached = no, a failed session = unknown).
us_got() {
    local id="$1" which="$2" l name probe
    l="${U_LISTED[$id]:-<no init line>}"
    if [[ "$which" == bare ]]; then name="zz-probe"; probe="${U_BARE[$id]:-$PROBE_SESSION_FAILED}"
    else name="$NAME:zz-probe"; probe="${U_PLUG[$id]:-$PROBE_SESSION_FAILED}"; fi
    if [[ "$l" == "<none>" ]]; then
        echo no
    elif [[ "$l" != "<"* ]]; then
        if tr ',' '\n' <<< "$l" | grep -qxF -e "$name" -e "/$name"; then echo yes; else echo no; fi
    elif [[ "$probe" -eq "$PROBE_REACHED" ]]; then
        echo yes
    elif [[ "$probe" -eq "$PROBE_NOT_REACHED" ]]; then
        echo no
    else
        echo unknown
    fi
}
# us_expect <id> <bare listed: yes|no|-> <prefixed listed: yes|no|-> <what a pass means>
us_expect() {
    local gb gp how="init command list: ${U_LISTED[$1]}"
    gb="$(us_got "$1" bare)"
    gp="$(us_got "$1" plug)"
    [[ "${U_LISTED[$1]}" == "<"* && "${U_LISTED[$1]}" != "<none>" ]] \
        && how="no init command list, judged by the probes: bare ${U_BARE_SAID[$1]}; prefixed ${U_PLUG_SAID[$1]}"
    if [[ ( "$2" == - || "$gb" == "$2" ) && ( "$3" == - || "$gp" == "$3" ) ]]; then
        pass "$1: $4"
    else
        fail "$1: wanted bare zz-probe listed $2 and $NAME:zz-probe listed $3; got $gb and $gp ($how)"
    fi
}
# us_verdict <got> <wanted> [<got> <wanted> ...], each got from us_got: one
# stop condition's verdict. FIRES when any definite answer differs from the
# wanted one (a definite answer beats an unknown elsewhere); UNDECIDED when
# none does but one is unknown; clear otherwise.
us_verdict() {
    local fires=0 undecided=0
    while [[ $# -ge 2 ]]; do
        if [[ "$1" == unknown ]]; then
            undecided=1
        elif [[ "$1" != "$2" ]]; then
            fires=1
        fi
        shift 2
    done
    if [[ "$fires" == 1 ]]; then echo "FIRES"
    elif [[ "$undecided" == 1 ]]; then echo "UNDECIDED (a session failed and printed no init command list; see the FAIL lines, then re-run)"
    else echo "clear"
    fi
}
# us_finish: remove the user-scope enable now (not only on exit), say what
# is left, and compare the real settings before and after.
us_finish() {
    local km
    if user_scope_remove; then
        pass "U-end: uninstall + marketplace remove at user scope leave neither of this run's entries in $REAL_SETTINGS"
    else
        fail "U-end: $REAL_SETTINGS still has this run's entries after the user-scope removal (cleanup tries again on exit)"
    fi
    km="$(km_source)"
    echo "  FACT: U-end after the user-scope uninstall + marketplace remove: $REAL_SETTINGS has $(user_scope_entries); machine record source: ${km:-<none>}"
    real_settings_compare
}

user_scope_cases() {
    local id="$NAME@$NAME" uout urc km n ctl_ok=0 ctl_code
    local us_wt="$SANDBOX/ws-wt" us_intree="$W/projects/intree" us_root="$SANDBOX/us-root" \
          us_loose="$SANDBOX/us-loose" us_both="$SANDBOX/us-both" us_off="$SANDBOX/us-off"
    echo ""
    echo "plugin_acceptance: user-scope cases ($NAME enabled at user scope in $REAL_SETTINGS until they end)"

    # ------------------------------------------- U0: setup and enable ---
    # The copy's off entry, committed before the committed-off and worktree
    # cases: the plan's step 5 commits the real plugin's entry, which would
    # not cover this run's renamed one, and without it a session at the
    # copy's root would list the probe twice (a test defect, not a finding).
    [[ -e "$W/.claude/settings.json" ]] || echo '{}' > "$W/.claude/settings.json"
    jq --arg id "$id" '.enabledPlugins = ((.enabledPlugins // {}) + {($id): false})' \
        "$W/.claude/settings.json" > "$W/s.json" && mv "$W/s.json" "$W/.claude/settings.json"
    # The two lines of the real checkout's .gitignore that bear on these
    # cases: in-tree roots live under projects/, local settings are never
    # committed.
    printf 'projects/\n.claude/settings.local.json\n' > "$W/.gitignore"
    mkdir -p "$W/subroot"
    printf 'A plain subdirectory of the workspace copy, a root in case U2.\n' > "$W/subroot/README"
    git -C "$W" add -A \
        && git -C "$W" -c user.name=t -c user.email=t@t commit -qm "workspace copy with the off entry"
    if git -C "$W" show HEAD:.claude/settings.json 2>/dev/null \
         | jq -e --arg id "$id" '.enabledPlugins[$id] == false' >/dev/null 2>&1; then
        pass "U0: the copy's committed .claude/settings.json has \"$id\": false under enabledPlugins"
    else
        fail "U0: could not commit the off entry in the copy; nothing enabled at user scope, the user-scope cases are not run"
        return 0
    fi
    # The shapes, each made before the enable so the sessions are all that
    # runs while it is on.
    git -C "$W" worktree add -q "$us_wt" 2>/dev/null \
        || fail "U0: could not add a worktree of the copy at $us_wt (U3 will show a failed session)"
    mkdir -p "$us_intree"
    { git -C "$W" check-ignore -q projects/intree && [[ ! -e "$us_intree/.git" ]]; } \
        || fail "U0: $us_intree is not an ignored, .git-less directory of the copy, so U4 is not the in-tree shape"
    mkdir -p "$us_root/src/pkg"
    printf 'An ordinary root.\n' > "$us_root/README"
    git -C "$us_root" init -q
    git -C "$us_root" -c user.name=t -c user.email=t@t add README \
        && git -C "$us_root" -c user.name=t -c user.email=t@t commit -qm init
    git -C "$us_root/src/pkg" init -q
    mkdir -p "$us_loose"
    ! git -C "$us_loose" rev-parse --show-toplevel >/dev/null 2>&1 \
        || fail "U0: $us_loose is inside a git repository, so U6 is not the unregistered-folder shape"
    mkdir -p "$us_both"
    git -C "$us_both" init -q
    # Local `true` first, as on a machine with a legacy per-root enable.
    enable_in "$us_both" \
        || fail "U0: could not enable $NAME at local scope in $us_both (U7 then has user scope only)"
    mkdir -p "$us_off/.claude/skills/zz-control"
    git -C "$us_off" init -q
    jq -n --arg id "$id" '{enabledPlugins: {($id): false}}' > "$us_off/.claude/settings.local.json"
    printf '%s\n' '---' 'name: zz-control' 'description: Control skill for the locally-off root.' '---' '' \
        'Reply with exactly the following line, copied character for character, and nothing else:' '' \
        'OFF-ROOT-CONTROL' > "$us_off/.claude/skills/zz-control/SKILL.md"

    # The enable: from a directory in no git repository, after the real
    # settings' snapshot, and recorded before the CLI runs.
    if git -C "$SANDBOX" rev-parse --show-toplevel >/dev/null 2>&1; then
        fail "U0: the sandbox $SANDBOX is inside a git repository; nothing enabled at user scope"
        return 0
    fi
    if ! REAL_BEFORE="$(real_settings_snapshot "$REAL_SETTINGS" 2>/dev/null)"; then
        REAL_BEFORE=""
        fail "U0: $REAL_SETTINGS does not parse as JSON; nothing enabled at user scope"
        return 0
    fi
    USER_ENABLED=1
    USER_TOUCHED=1
    uout="$(cd "$SANDBOX" && cli_plugin marketplace add "$W" --scope user 2>&1 \
        && cli_plugin install "$id" --scope user 2>&1)"
    urc=$?
    km="$(km_source)"
    echo "  FACT: U0 user-scope marketplace add + install, run from a directory in no git repository: exit $urc; $REAL_SETTINGS now has $(user_scope_entries); machine record source: ${km:-<none>}"
    if [[ "$urc" -ne 0 ]] || ! jq -e --arg id "$id" '.enabledPlugins[$id] == true' "$REAL_SETTINGS" >/dev/null 2>&1; then
        fail "U0: the user-scope enable did not take (exit $urc: $(tr '\n' ' ' <<< "$uout" | cut -c1-300)); the user-scope cases are not run"
        us_finish
        return 0
    fi
    jq -e --arg m "$NAME" --arg w "$W" '.extraKnownMarketplaces[$m].source.path == $w' "$REAL_SETTINGS" >/dev/null 2>&1 \
        && pass "U0: user scope enables $id and declares its marketplace from the copy in $REAL_SETTINGS" \
        || fail "U0: $id is enabled at user scope, but the marketplace declaration does not name the copy ($(user_scope_entries))"

    # --------------------------------------------- U1 to U8: sessions ---
    us_case U1 "committed-off repository, at its root" "$W"
    us_expect U1 yes no \
        "a session at the committed-off repository's root lists the skill bare and not under $NAME:"
    us_case U2 "committed-off repository, in a plain subdirectory root of it" "$W/subroot"
    us_expect U2 yes yes \
        "a session in a plain subdirectory root of it lists the skill under both names (accepted 2026-11-12)"
    us_case U3 "committed-off repository, in a worktree of it outside its directory" "$us_wt"
    us_expect U3 yes no \
        "a session in a worktree of it lists the skill bare and not under $NAME:"
    us_case U4 "in-tree root (inside the copy's tree, ignored by its git, no .git of its own)" "$us_intree"
    us_expect U4 yes yes \
        "a session in an in-tree root lists the skill under both names (accepted 2026-11-12)"
    us_case U5 "repository nested in an ordinary root" "$us_root/src/pkg"
    us_expect U5 - yes \
        "a session in a repository nested in an ordinary root lists $NAME:zz-probe"
    us_case U6 "unregistered folder in no git repository" "$us_loose"
    us_expect U6 - yes \
        "a session in an unregistered folder lists $NAME:zz-probe"
    us_case U7 "local true plus user true" "$us_both"
    us_expect U7 - yes \
        "a session in a root enabled at both local and user scope lists $NAME:zz-probe"
    if [[ "${U_LISTED[U7]}" == "<"* ]]; then
        n=""
        fail "U7: could not tell how many times $NAME:zz-probe is listed (${U_LISTED[U7]}): the suite's assumption about the stream-json init line does not hold on this CLI"
    else
        n="$(tr ',' '\n' <<< "${U_LISTED[U7]}" | grep -cE "^/?$NAME:zz-probe\$")"
        [[ "$n" -eq 1 ]] \
            && pass "U7: local true plus user true lists $NAME:zz-probe once" \
            || fail "U7: local true plus user true lists $NAME:zz-probe $n times (${U_LISTED[U7]})"
    fi
    # A negative is evidence only when the session dispatches slash commands
    # at all, so the root's own control skill must answer first.
    us_session "$us_off" "/zz-control"
    [[ "$SESSION_RC" -eq 0 && "$US_GOT_RESULT" -eq 1 && "$SESSION_OUT" == *"OFF-ROOT-CONTROL"* ]] && ctl_ok=1
    if [[ "$ctl_ok" == 1 ]]; then
        us_case U8 "root whose local entry is false under user true" "$us_off" "its own control skill answered"
        us_expect U8 - no \
            "a session in a root whose local entry is false has no $NAME: skill under user true"
        ctl_code=yes
    else
        ctl_code=unknown
        fail "U8: the locally-off root's control skill did not answer, so a negative there proves nothing ($(session_said))"
        us_case U8 "root whose local entry is false under user true" "$us_off" "its own control skill did NOT answer"
    fi

    # ------------------------------------------------------- U-end ---
    us_finish

    # ----------------------------------------------- stop conditions ---
    # Stop checks 1 and 2 as amended by the owner's acceptance of the
    # doubling (2026-11-12): what the change documents is what they hold
    # the sessions to.
    echo "  STOP-CHECK 1 (the committed false entry keeps the checkout's root and its worktrees to one bare name, U1 and U3; a plain subdirectory lists both names, as accepted 2026-11-12, U2): $(us_verdict \
        "$(us_got U1 bare)" yes "$(us_got U1 plug)" no \
        "$(us_got U2 bare)" yes "$(us_got U2 plug)" yes \
        "$(us_got U3 bare)" yes "$(us_got U3 plug)" no)"
    echo "  STOP-CHECK 2 (an in-tree root lists both names, as accepted 2026-11-12: U4): $(us_verdict \
        "$(us_got U4 bare)" yes "$(us_got U4 plug)" yes)"
    echo "  STOP-CHECK 3 (a session in a repository nested in an ordinary root lists the plugin's skills: U5): $(us_verdict \
        "$(us_got U5 plug)" yes)"
    echo "  STOP-CHECK 4 (a local false wins over user true: U8): $(us_verdict \
        "$ctl_code" yes "$(us_got U8 plug)" no)"
    if [[ -z "$n" ]]; then
        echo "  CHECK U7 (not a stop condition; the plan's step 2 migration rests on it -- local true plus user true lists the skill once): UNDECIDED (no init command list)"
    elif [[ "$n" -eq 1 ]]; then
        echo "  CHECK U7 (not a stop condition; the plan's step 2 migration rests on it -- local true plus user true lists the skill once): yes"
    else
        echo "  CHECK U7 (not a stop condition; the plan's step 2 migration rests on it -- local true plus user true lists the skill once): NO, $n times"
    fi
}
if [[ "$RUN_USER" == 1 ]]; then
    user_scope_cases
fi

echo ""
echo "plugin_acceptance: $PASS passed, $FAIL failed (model: $MODEL)"
[ "$FAIL" -eq 0 ]
