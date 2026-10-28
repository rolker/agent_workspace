#!/usr/bin/env bash
# Tests for .agent/scripts/project_integration_audit.sh (issue #332, PR 3):
# the integration audit /onboard-project runs at a project's root.
#
# Covers: every category (1 to 6) with at least one finding and a clean
# project that yields none; the hand-registered fixture shaped like the
# project the plan names (2026-09-23: CMake, four skills sharing workspace
# skill names, an instruction file saying feature branches and "issue when
# one exists", an unanchored build/ rule hiding a project skill, no ignore
# rule for the worktrees directory, docs/work-plans/, no .agents/ and no
# settings file) reproducing one finding id per category; instructions=none
# turning offer findings into info; the records settings against
# .agent/work-plans/; the TSV shape and the text format; read-only (no
# file in the project, the registry, the settings or HOME changes); run
# from a project root outside the workspace; refusal from an unregistered
# directory. Also project_setting.sh's write guard (#332 PR 3): from a
# project root it writes only that project's settings file.
#
# Every fixture is synthetic: a sandbox workspace (a git repository with
# copies of the real scripts, project types, skills and user-tier files),
# sandbox projects built here, HOME redirected to the sandbox, and a stub
# `claude` that edits settings.local.json the way the real CLI does. No
# real checkout, registry, ~/.claude or network is touched.
#
# Run: bash .agent/scripts/tests/test_project_integration_audit.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check() { # <label> <command...>
    local label="$1"
    shift
    if "$@"; then pass "$label"; else fail "$label"; fi
}

command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required" >&2; exit 1; }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
SANDBOX="$(cd "$SANDBOX" && pwd -P)"

# No global git configuration or ignore file of the machine running the
# tests may change what the audit sees.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
unset XDG_CONFIG_HOME CLAUDE_CONFIG_DIR

gitq() { git -c user.name=t -c user.email=t@example.invalid -c init.defaultBranch=main "$@"; }

# ------------------------------------------------------------ fixtures ---
STUB_BIN="$SANDBOX/bin"
STUB="$STUB_BIN/claude"
mkdir -p "$STUB_BIN"
cat > "$STUB" <<'STUBEOF'
#!/usr/bin/env bash
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
if [[ "$2 $3" == "marketplace add" ]]; then
    km="$HOME/.claude/plugins/known_marketplaces.json"
    mkdir -p "$(dirname "$km")"
    [[ -f "$km" ]] || echo '{}' > "$km"
    jq --arg a "$arg" '.["agent-workspace"] = {source: {source: "directory", path: $a}}' "$km" > "$km.tmp" && mv "$km.tmp" "$km"
fi
STUBEOF
chmod +x "$STUB"

HOMEDIR="$SANDBOX/home"
mkdir -p "$HOMEDIR"

# The sandbox workspace: its own main checkout.
WS="$SANDBOX/ws"
mkdir -p "$WS/.agent"
cp -r "$REAL_ROOT/.agent/scripts" "$WS/.agent/scripts"
rm -rf "$WS/.agent/scripts/tests"
cp -r "$REAL_ROOT/.agent/project_types" "$WS/.agent/project_types"
cp "$REAL_ROOT/.agent/user_tier_scripts.txt" "$WS/.agent/"
cp -r "$REAL_ROOT/.claude" "$WS/.claude"
cp -r "$REAL_ROOT/.claude-plugin" "$WS/.claude-plugin"
rm -f "$WS/.claude/settings.local.json"
printf '.agent/projects.local\n.agent/projects.d/\n.agent/project_config.sh\n.agent/scratchpad/\n.claude/settings.local.json\n' > "$WS/.gitignore"
gitq -C "$WS" init --quiet
gitq -C "$WS" add -A
gitq -C "$WS" commit --quiet -m sandbox
mkdir -p "$WS/.agent/projects.d"
: > "$WS/.agent/projects.local"

register() { # <name> <dir> [settings lines...]: a hand-written registry line
    local name="$1" dir="$2"
    shift 2
    printf '%s single_project %s\n' "$name" "$dir" >> "$WS/.agent/projects.local"
    if [ $# -gt 0 ]; then printf '%s\n' "$@" > "$WS/.agent/projects.d/$name"; fi
}
commit_all() { gitq -C "$1" add -A && gitq -C "$1" commit --quiet -m init; }

# The clean project: its own commands, an agent guide, the worktrees
# directory ignored, a remote, and an instruction file that names only
# its own commands.
CLEAN="$SANDBOX/projects/clean"
mkdir -p "$CLEAN/.agents"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$CLEAN/Makefile"
printf '# Clean\n\nRun `make test` before pushing. Always keep tests green.\nPlease make sure the docs build too.\n' > "$CLEAN/CLAUDE.md"
printf '# Clean agent guide\n' > "$CLEAN/.agents/README.md"
printf 'worktrees/\n' > "$CLEAN/.gitignore"
gitq -C "$CLEAN" init --quiet
commit_all "$CLEAN"
gitq -C "$CLEAN" remote add origin "git@example.invalid:someone/clean.git"
register clean "$CLEAN" "build=make" "test=make test" "instructions=tracked"

# The hand-registered fixture, shaped like the project the plan names.
HR="$SANDBOX/projects/handreg"
mkdir -p "$HR/src" "$HR/docs/work-plans/issue-3"
printf 'cmake_minimum_required(VERSION 3.16)\nproject(handreg)\n' > "$HR/CMakeLists.txt"
cat > "$HR/CLAUDE.md" <<'EOF'
# handreg

- Work on a feature branch for every change.
- Reference the issue number when one exists.
- Build with `cmake -S . -B build && cmake --build build`.
- Never push to main.
EOF
for sk in plan-task review-code start-task research; do
    mkdir -p "$HR/.claude/skills/$sk"
done
cp "$WS/.claude/skills/plan-task/SKILL.md" "$HR/.claude/skills/plan-task/SKILL.md"
printf -- '---\nname: review-code\n---\nYou must review it all.\n' > "$HR/.claude/skills/review-code/SKILL.md"
printf -- '---\nname: start-task\n---\nstart\n' > "$HR/.claude/skills/start-task/SKILL.md"
printf -- '---\nname: research\n---\nresearch\n' > "$HR/.claude/skills/research/SKILL.md"
printf 'build/\n' > "$HR/.gitignore"
echo "# plan" > "$HR/docs/work-plans/issue-3/plan.md"
gitq -C "$HR" init --quiet
commit_all "$HR"
# The project's own build skill, present but hidden by the unanchored rule.
mkdir -p "$HR/.claude/skills/build"
printf -- '---\nname: build\n---\nBuild it. Always.\n' > "$HR/.claude/skills/build/SKILL.md"
register handreg "$HR"

# Install the user tier from the sandbox workspace (enables the plugin in
# every registered root); re-run after each later registration, as
# register_project.sh does.
install_ut() {
    (cd "$SANDBOX" && HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" AGENT_WORKSPACE_CLAUDE_BIN="$STUB" \
        "$WS/.agent/scripts/user_tier_install.sh" >/dev/null 2>&1) \
        || { echo "FATAL: the sandbox user-tier install failed" >&2; exit 1; }
}
install_ut

audit() { # <cwd> <args...>: stdout only; exit code in $AUDIT_RC
    local cwd="$1"
    shift
    AUDIT_RC=0
    AUDIT_OUT="$(cd "$cwd" && HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" AGENT_WORKSPACE_CLAUDE_BIN="$STUB" \
        "$WS/.agent/scripts/project_integration_audit.sh" "$@" 2>"$SANDBOX/audit.err")" || AUDIT_RC=$?
    AUDIT_ERR="$(cat "$SANDBOX/audit.err")"
}
has_id() { awk -F'\t' -v c="$1" -v i="$2" '$1 == c && $2 == i { f = 1 } END { exit !f }' <<< "$AUDIT_OUT"; }
sev_of() { awk -F'\t' -v i="$1" '$2 == i { print $3; exit }' <<< "$AUDIT_OUT"; }
cats() { cut -f1 <<< "$AUDIT_OUT" | sort -u | paste -sd' ' -; }

# ------------------------------------------------------------- tests ---
echo "TEST: a clean project yields no findings"
audit "$CLEAN"
check "exit 0" [ "$AUDIT_RC" -eq 0 ]
check "no findings (got: ${AUDIT_OUT//$'\t'/ | })" [ -z "$AUDIT_OUT" ]

echo "TEST: --format text on the clean project"
audit "$CLEAN" --format text
check "names the project" grep -qF "Integration audit: clean (single_project) at $CLEAN" <<< "$AUDIT_OUT"
check "says no findings" grep -qx "No findings." <<< "$AUDIT_OUT"

echo "TEST: the hand-registered fixture reproduces a finding in every category"
audit "$HR/src"
check "exit 0 with findings" [ "$AUDIT_RC" -eq 0 ]
check "every line has five tab-separated fields" \
    awk -F'\t' 'NF != 5 { bad = 1 } END { exit bad }' <<< "$AUDIT_OUT"
check "severities are error, warn or info" \
    awk -F'\t' '$3 !~ /^(error|warn|info)$/ { bad = 1 } END { exit bad }' <<< "$AUDIT_OUT"
check "categories 1 to 6 all present (got: $(cats))" [ "$(cats)" = "1 2 3 4 5 6" ]
check "1: duplicate skills" has_id 1 skill-same-name
check "1: the identical copy is called identical" \
    grep -qE $'^1\tskill-same-name\twarn\t.claude/skills/plan-task\tidentical' <<< "$AUDIT_OUT"
check "1: the differing one is called differing, with line counts" \
    grep -qE $'^1\tskill-same-name\twarn\t.claude/skills/review-code\tdiffers .*\\(project 4 lines, workspace [0-9]+ lines\\)' <<< "$AUDIT_OUT"
check "1: four same-named skills" [ "$(grep -c $'^1\tskill-same-name\t' <<< "$AUDIT_OUT")" -eq 4 ]
check "2: feature branches" has_id 2 process-branch
check "2: an issue when one exists" has_id 2 process-issue
check "2: a build command that is not the project's own" has_id 2 process-build-command
check "2: the candidate names the file and line" grep -qE $'^2\tprocess-branch\twarn\tCLAUDE.md:3\t' <<< "$AUDIT_OUT"
check "3: the worktrees directory not ignored" has_id 3 worktrees-not-ignored
check "3: the older docs/work-plans/" has_id 3 old-work-plans
check "4: build/ hides the project's build skill" \
    grep -qE $'^4\tignored-agent-file\twarn\t.claude/skills/build/SKILL.md\t.*\\.gitignore:1:build/' <<< "$AUDIT_OUT"
check "5: rules with no .agents/ for the review skills" has_id 5 conventions-unread
check "6: no commands of its own" grep -qE $'^6\tregistration\terror\thandreg\tno (build|test) command' <<< "$AUDIT_OUT"
check "no user-tier or session-root finding (installed, resolves)" \
    bash -c '! grep -qE $'"'"'\t(user-tier|session-root)\t'"'"' <<< "$1"' _ "$AUDIT_OUT"

echo "TEST: --format text groups the fixture's findings under the category names"
audit "$HR" --format text
for h in "1. Project configuration" "2. Instruction lines" "3. Files the workspace writes" \
         "4. Ignore rules hiding agent files" "5. Conventions where" "6. Registration that does not work"; do
    check "heading: $h" grep -qF "$h" <<< "$AUDIT_OUT"
done
check "a count at the end" grep -qE '^[0-9]+ finding\(s\): [0-9]+ error, [0-9]+ warn, [0-9]+ info$' <<< "$AUDIT_OUT"

echo "TEST: --project from the workspace audits the same project"
audit "$WS" --project handreg
check "exit 0" [ "$AUDIT_RC" -eq 0 ]
check "same findings by name" has_id 3 old-work-plans

echo "TEST: instructions=none makes the offer findings info"
printf 'instructions=none\n' > "$WS/.agent/projects.d/handreg"
audit "$HR"
check "4: info (got $(sev_of ignored-agent-file))" [ "$(sev_of ignored-agent-file)" = "info" ]
check "5: info (got $(sev_of conventions-unread))" [ "$(sev_of conventions-unread)" = "info" ]
check "the detail says nothing is offered" grep -qF "(instructions=none: nothing is offered)" <<< "$AUDIT_OUT"
check "3: the worktrees finding stays warn (its fix is untracked)" [ "$(sev_of worktrees-not-ignored)" = "warn" ]
for id in skill-same-name process-branch process-issue old-work-plans; do
    check "$id: info (got $(sev_of "$id"))" [ "$(sev_of "$id")" = "info" ]
done
check "no warn in categories 1 to 5 but the worktrees finding (got: $(awk -F'\t' '$3 == "warn" { print $2 }' <<< "$AUDIT_OUT" | paste -sd' ' -))" \
    awk -F'\t' '$3 == "warn" && $1 < 6 && $2 != "worktrees-not-ignored" { bad = 1 } END { exit bad }' <<< "$AUDIT_OUT"
rm -f "$WS/.agent/projects.d/handreg"

echo "TEST: category 1, settings hooks and allow rules, .mcp.json, @ imports, same-named commands"
P1="$SANDBOX/projects/p1"
mkdir -p "$P1/.claude/commands" "$P1/.agents"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$P1/Makefile"
printf '# guide\n' > "$P1/.agents/README.md"
printf 'worktrees/\n' > "$P1/.gitignore"
printf 'See @AGENTS.md and @docs/style.md. Mail @someone.\n' > "$P1/CLAUDE.md"
printf '{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": []}]}, "permissions": {"allow": ["Bash(ls)", "Bash(make)"]}}\n' > "$P1/.claude/settings.json"
printf '{"mcpServers": {"db": {}, "docs": {}}}\n' > "$P1/.mcp.json"
printf 'run it\n' > "$P1/.claude/commands/sitrep.md"
gitq -C "$P1" init --quiet
commit_all "$P1"
gitq -C "$P1" remote add origin "git@example.invalid:someone/p1.git"
register p1 "$P1" "build=make" "test=make test"
install_ut
audit "$P1"
check "settings-hooks names the event" grep -qE $'^1\tsettings-hooks\twarn\t.claude/settings.json\thooks: PreToolUse \\(1\\)' <<< "$AUDIT_OUT"
check "settings-allow counts the rules" grep -qE $'^1\tsettings-allow\tinfo\t.claude/settings.json\t2 permission' <<< "$AUDIT_OUT"
check "mcp-servers names them" grep -qE $'^1\tmcp-servers\tinfo\t.mcp.json\tMCP servers: db, docs' <<< "$AUDIT_OUT"
check "claude-md-import names the imports, not a mention" \
    grep -qE $'^1\tclaude-md-import\tinfo\tCLAUDE.md\timports @AGENTS.md @docs/style.md into' <<< "$AUDIT_OUT"
check "command-same-name" grep -qE $'^1\tcommand-same-name\twarn\t.claude/commands/sitrep.md' <<< "$AUDIT_OUT"
check "nothing outside category 1 (got: $(cats))" [ "$(cats)" = "1" ]
printf 'build=make\ntest=make test\ninstructions=none\n' > "$WS/.agent/projects.d/p1"
audit "$P1"
check "instructions=none: command-same-name is info (got $(sev_of command-same-name))" [ "$(sev_of command-same-name)" = "info" ]
check "instructions=none: settings-hooks stays warn (what the project loads)" [ "$(sev_of settings-hooks)" = "warn" ]
printf 'build=make\ntest=make test\n' > "$WS/.agent/projects.d/p1"

echo "TEST: category 3, the records settings against .agent/work-plans/"
P3="$SANDBOX/projects/p3"
mkdir -p "$P3/.agents" "$P3/.agent/work-plans/issue-1"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$P3/Makefile"
printf '# guide\n' > "$P3/.agents/README.md"
printf 'worktrees/\n.agent/\n' > "$P3/.gitignore"
echo "# plan" > "$P3/.agent/work-plans/issue-1/plan.md"
gitq -C "$P3" init --quiet
commit_all "$P3"
gitq -C "$P3" remote add origin "git@example.invalid:someone/p3.git"
register p3 "$P3" "build=make" "test=make test"
install_ut
audit "$P3"
check "(project, project) with .agent/ ignored: work-plans-ignored" \
    grep -qE $'^3\twork-plans-ignored\twarn\t.agent/work-plans/\t.*\\.gitignore:2:\\.agent/' <<< "$AUDIT_OUT"
printf 'build=make\ntest=make test\ninstructions=none\n' > "$WS/.agent/projects.d/p3"
audit "$P3"
check "instructions=none: work-plans-ignored is info (got $(sev_of work-plans-ignored))" [ "$(sev_of work-plans-ignored)" = "info" ]
printf 'build=make\ntest=make test\n' > "$WS/.agent/projects.d/p3"
printf 'worktrees/\n' > "$P3/.gitignore"
printf 'build=make\ntest=make test\nlocation=project\ntracking=untracked\n' > "$WS/.agent/projects.d/p3"
audit "$P3"
check "(project, untracked) not ignored: work-plans-not-ignored" has_id 3 work-plans-not-ignored
check "and the registration note says not yet honoured" \
    grep -qE $'^6\tregistration-note\twarn\tp3\t.*not yet honoured' <<< "$AUDIT_OUT"
echo ".agent/work-plans/" >> "$P3/.git/info/exclude"
audit "$P3"
check "(project, untracked) ignored through .git/info/exclude: no work-plans finding" \
    bash -c '! grep -qE $'"'"'\twork-plans-'"'"' <<< "$1"' _ "$AUDIT_OUT"
printf 'build=make\ntest=make test\nlocation=outside\nlocation_path=%s\ntracking=untracked\n' "$SANDBOX/p3-records" > "$WS/.agent/projects.d/p3"
audit "$P3"
check "(outside, untracked) with records in the project: records-two-places" has_id 3 records-two-places
printf 'build=make\ntest=make test\n' > "$WS/.agent/projects.d/p3"
mkdir -p "$P3/docs/work-plans/issue-2"
echo "# old" > "$P3/docs/work-plans/issue-2/plan.md"
sed -i '/work-plans/d' "$P3/.git/info/exclude"
audit "$P3"
check "docs/work-plans/ beside .agent/work-plans/: old-work-plans" has_id 3 old-work-plans
check "and records-two-places" has_id 3 records-two-places
printf 'build=make\ntest=make test\ninstructions=none\n' > "$WS/.agent/projects.d/p3"
audit "$P3"
check "instructions=none: records-two-places is info (got $(sev_of records-two-places))" [ "$(sev_of records-two-places)" = "info" ]
printf 'build=make\ntest=make test\n' > "$WS/.agent/projects.d/p3"
rm -rf "$P3/docs"

echo "TEST: category 4, a path the workspace would add is ignored"
P4="$SANDBOX/projects/p4"
mkdir -p "$P4/.agents"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$P4/Makefile"
printf '# guide\n' > "$P4/.agents/README.md"
printf 'worktrees/\ndocs/\n' > "$P4/.gitignore"
gitq -C "$P4" init --quiet
commit_all "$P4"
gitq -C "$P4" remote add origin "git@example.invalid:someone/p4.git"
register p4 "$P4" "build=make" "test=make test"
install_ut
audit "$P4"
check "ignore-would-hide docs/roadmap.md with its rule" \
    grep -qE $'^4\tignore-would-hide\twarn\tdocs/roadmap.md\t.*\\.gitignore:2:docs/' <<< "$AUDIT_OUT"
check "nothing outside category 4 (got: $(cats))" [ "$(cats)" = "4" ]
# A path the project un-ignores with a "!" rule is not hidden: check-ignore
# -v prints the negated rule and exits 0 for it, so -v must not decide.
printf 'worktrees/\n*.md\n!AGENTS.md\n!CLAUDE.md\n!.agents/README.md\n!docs/roadmap.md\n' > "$P4/.gitignore"
audit "$P4"
check "a \"!\" rule un-ignores AGENTS.md, CLAUDE.md and docs/roadmap.md: no finding (got: ${AUDIT_OUT//$'\t'/ | })" \
    bash -c '! grep -qE $'"'"'^4\tignore-would-hide\t[^\t]*\t(AGENTS|CLAUDE|docs/roadmap)'"'"' <<< "$1"' _ "$AUDIT_OUT"
printf 'worktrees/\n*.md\n!AGENTS.md\n' > "$P4/.gitignore"
audit "$P4"
check "a path the \"!\" rule leaves ignored is still reported, with the ignoring rule" \
    grep -qE $'^4\tignore-would-hide\twarn\tCLAUDE.md\t.*\\.gitignore:2:\\*\\.md' <<< "$AUDIT_OUT"
printf 'worktrees/\ndocs/\n' > "$P4/.gitignore"

echo "TEST: category 6, the user tier not installed"
EMPTY_HOME="$SANDBOX/emptyhome"
mkdir -p "$EMPTY_HOME"
AUDIT_RC=0
AUDIT_OUT="$(cd "$CLEAN" && HOME="$EMPTY_HOME" PATH="$STUB_BIN:$PATH" AGENT_WORKSPACE_CLAUDE_BIN="$STUB" \
    "$WS/.agent/scripts/project_integration_audit.sh" 2>/dev/null)" || AUDIT_RC=$?
check "exit 0" [ "$AUDIT_RC" -eq 0 ]
check "user-tier error" grep -qE $'^6\tuser-tier\terror\tuser tier\tuser_tier_install.sh --check --require failed' <<< "$AUDIT_OUT"

echo "TEST: a root that is not a git repository"
NG="$SANDBOX/projects/nogit"
mkdir -p "$NG"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$NG/Makefile"
register nogit "$NG" "build=make" "test=make test"
audit "$NG"
check "exit 0" [ "$AUDIT_RC" -eq 0 ]
check "not-git info, no ignore-rule findings" bash -c 'grep -qE $'"'"'^3\tnot-git\tinfo\t'"'"' <<< "$1" && ! grep -qE $'"'"'^4\t'"'"' <<< "$1"' _ "$AUDIT_OUT"

echo "TEST: read-only: nothing in the project, the workspace or HOME changes"
snap() { # <dir>: every path with its content hash, .git included
    (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha1sum)
}
before_hr="$(snap "$HR")"; before_ws="$(snap "$WS/.agent")"; before_home="$(snap "$HOMEDIR")"
audit "$HR"
audit "$HR" --format text
check "the project is unchanged" [ "$before_hr" = "$(snap "$HR")" ]
check "the workspace's .agent (registry, settings) is unchanged" [ "$before_ws" = "$(snap "$WS/.agent")" ]
check "HOME is unchanged" [ "$before_home" = "$(snap "$HOMEDIR")" ]

echo "TEST: refusals"
OUT_REPO="$SANDBOX/unrelated"
mkdir -p "$OUT_REPO"
gitq -C "$OUT_REPO" init --quiet
audit "$OUT_REPO"
check "an unregistered directory: exit 2" [ "$AUDIT_RC" -eq 2 ]
check "it says to register first" grep -qF "is under no registered project root" <<< "$AUDIT_ERR"
check "and prints no findings" [ -z "$AUDIT_OUT" ]
audit "$WS"
check "the workspace checkout itself: exit 2" [ "$AUDIT_RC" -eq 2 ]
audit "$SANDBOX" --project nosuch
check "an unregistered name: exit 2" [ "$AUDIT_RC" -eq 2 ]
audit "$HR" --dir "$HR" --project handreg
check "--dir with --project: exit 2" [ "$AUDIT_RC" -eq 2 ]
audit "$HR" --format json
check "an unknown format: exit 2" [ "$AUDIT_RC" -eq 2 ]

echo "TEST: project_setting.sh from a project root writes only that project's settings"
ps() { # <cwd> <args...>
    PS_RC=0
    PS_OUT="$(cd "$1" && shift && HOME="$HOMEDIR" "$WS/.agent/scripts/project_setting.sh" "$@" 2>&1)" || PS_RC=$?
}
ps "$HR/src" set handreg instructions=tracked
check "its own project: exit 0" [ "$PS_RC" -eq 0 ]
check "the value is stored" [ "$(cat "$WS/.agent/projects.d/handreg")" = "instructions=tracked" ]
ps "$HR" set clean instructions=none
check "another project's: refused (exit 1)" [ "$PS_RC" -eq 1 ]
check "the refusal names the session's own project" grep -qF "writes only the settings of 'handreg'" <<< "$PS_OUT"
check "the other file is unchanged" grep -qx "instructions=tracked" "$WS/.agent/projects.d/clean"
ps "$HR" unset clean instructions
check "unset of another project's: refused" [ "$PS_RC" -eq 1 ]
ps "$HR" get clean build
check "reading another project's is allowed" [ "$PS_RC" -eq 0 ] && [ "$PS_OUT" = "make" ]
ps "$OUT_REPO" set handreg instructions=none
check "from an unregistered repository: refused" [ "$PS_RC" -ne 0 ]
check "by the root guard" grep -qF "refusing to run" <<< "$PS_OUT"
check "the file is unchanged" [ "$(cat "$WS/.agent/projects.d/handreg")" = "instructions=tracked" ]
ps "$WS" set clean instructions=none
check "from the workspace checkout, any project: exit 0" [ "$PS_RC" -eq 0 ]

echo ""
echo "test_project_integration_audit: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
