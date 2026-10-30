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
# project root it writes only that project's settings file. And --facts
# (#332 PR 4): github, issues, prs, windows and multi_component read from
# the remote, a stub gh and a stub uname, at a parent root from the chosen
# instance's repository; gh is never called without a GitHub remote. Its
# edge cases: gh or jq missing, the list calls failing after repo view
# answered, a JSON answer that is not a list, a credential in a remote URL
# or a secret anywhere in it, in any form: user part, query, fragment,
# https, ssh, scp, file://, a secret holding "?", "#", "@", "/", ":" or
# "://" in each part of each form, an "@" in a query or fragment with no
# user part, on origin or another remote (never printed, never passed
# to gh; GitHub read as GitHub, or unknown when the URL cannot be cut
# safely), a remote-helper <transport>::<address>, a host or path holding
# a space, a quote or a letter outside ASCII (the same output under
# en_US.UTF-8 and C.UTF-8), gh's text in any shape, failed or not
# parsing (none of it printed: a fixed phrase, the exit code and at most
# a first word from a fixed list), an "@" in a local remote's path or a
# manifest directory (printed as it is), local and file:/// paths
# keeping their "?" and "#", github.com with no path (unknown), a host
# not github.com by name (no, saying so), a github.com path that is not
# owner/repo (unknown), GH_HOST naming another server, an ssh host alias or
# GitHub on a remote other than the one checked (unknown), no commits, a
# remote not named origin, and a root nested inside another repository.
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

echo "TEST: category 2, build commands compared one command at a time, on word boundaries"
P2="$SANDBOX/projects/p2"
mkdir -p "$P2/.agents"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$P2/Makefile"
printf '# guide\n' > "$P2/.agents/README.md"
printf 'worktrees/\n' > "$P2/.gitignore"
cat > "$P2/CLAUDE.md" <<'EOF'
# p2

- Build with `cmake --build build`.
- Build with `make -j4`.
- Then `make && ninja -C out`.
- Run `make test` before pushing.
- $ make test  # the suite
- make sure `make test` passes.
1. ninja -C out
+ cargo build
2) make test
EOF
gitq -C "$P2" init --quiet
commit_all "$P2"
gitq -C "$P2" remote add origin "git@example.invalid:someone/p2.git"
register p2 "$P2" "build=make" "test=make test"
install_ut
audit "$P2"
p2_lines() { awk -F'\t' '$2 == "process-build-command" { print $4 }' <<< "$AUDIT_OUT" | paste -sd' ' -; }
check "build=make does not hide cmake --build (line 3), nor ninja after make (line 5); numbered and + list items are read (9, 10; 11 is its own); its own commands with arguments are its own (got: $(p2_lines))" \
    [ "$(p2_lines)" = "CLAUDE.md:3 CLAUDE.md:5 CLAUDE.md:9 CLAUDE.md:10" ]
printf 'build=cmake --build build\ntest=make test\n' > "$WS/.agent/projects.d/p2"
audit "$P2"
check "build=cmake --build build: make -j4 and a bare make are not its own; the prose before a code span (make sure, line 8) is no command (got: $(p2_lines))" \
    [ "$(p2_lines)" = "CLAUDE.md:4 CLAUDE.md:5 CLAUDE.md:9 CLAUDE.md:10" ]

echo "TEST: category 2, at most 10 candidate lines per file and id, then the count"
P5="$SANDBOX/projects/p5"
mkdir -p "$P5/.agents"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$P5/Makefile"
printf '# guide\n' > "$P5/.agents/README.md"
printf 'worktrees/\n' > "$P5/.gitignore"
{
    echo "# p5"
    for i in 1 2 3; do echo "- Use a feature branch in a worktree ($i)."; done
    for i in $(seq 1 12); do echo "- Push the feature branch ($i)."; done
    for i in $(seq 1 12); do echo "- \`cargo build -p crate$i\`"; done
} > "$P5/CLAUDE.md"
gitq -C "$P5" init --quiet
commit_all "$P5"
gitq -C "$P5" remote add origin "git@example.invalid:someone/p5.git"
register p5 "$P5" "build=make" "test=make test"
install_ut
audit "$P5"
check "10 process-branch lines with a line number" \
    [ "$(grep -cE $'^2\tprocess-branch\twarn\tCLAUDE.md:[0-9]+\t' <<< "$AUDIT_OUT")" -eq 10 ]
check "then one line counting the 12 kept, not the 3 the worktree skip drops" \
    grep -qxE $'2\tprocess-branch\twarn\tCLAUDE.md\tand more lines like these \\(12 in all\\)' <<< "$AUDIT_OUT"
check "no skipped line among them" bash -c '! grep -q "worktree (" <<< "$1"' _ "$AUDIT_OUT"
check "10 build-command lines" \
    [ "$(grep -cE $'^2\tprocess-build-command\tinfo\tCLAUDE.md:[0-9]+\t' <<< "$AUDIT_OUT")" -eq 10 ]
check "then one more-line" \
    grep -qxE $'2\tprocess-build-command\tinfo\tCLAUDE.md\tand more build or test command lines' <<< "$AUDIT_OUT"

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

echo "TEST: category 4, ignored agent files grouped per rule; Claude Code's own worktrees not reported"
mkdir -p "$P4/.claude/worktrees/wt1" "$P4/.claude/notes"
echo x > "$P4/.claude/worktrees/wt1/file"
for i in 1 2 3 4 5; do echo n > "$P4/.claude/notes/n$i.md"; done
printf 'worktrees/\ndocs/\n.claude/worktrees/\n.claude/notes/\n' > "$P4/.gitignore"
audit "$P4"
check "one ignored-agent-file line for the five files (got: $(grep -c $'\tignored-agent-file\t' <<< "$AUDIT_OUT"))" \
    [ "$(grep -c $'\tignored-agent-file\t' <<< "$AUDIT_OUT")" -eq 1 ]
check "it names three, the count and the rule (got: ${AUDIT_OUT//$'\t'/ | })" \
    grep -qxE $'4\tignored-agent-file\twarn\t.claude/notes/n[0-9].md, .claude/notes/n[0-9].md, .claude/notes/n[0-9].md and 2 more\t5 files present but ignored by one rule, .*the rule: \\.gitignore:4:\\.claude/notes/' <<< "$AUDIT_OUT"
check ".claude/worktrees/ is not reported" bash -c '! grep -qF ".claude/worktrees" <<< "$1"' _ "$AUDIT_OUT"
rm -rf "$P4/.claude"
printf 'worktrees/\ndocs/\n' > "$P4/.gitignore"

echo "TEST: category 3, a root registered through a symlink, its worktrees directory not created yet"
PL="$SANDBOX/projects/plink"
mkdir -p "$PL/.agents"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$PL/Makefile"
printf '# guide\n' > "$PL/.agents/README.md"
gitq -C "$PL" init --quiet
commit_all "$PL"
gitq -C "$PL" remote add origin "git@example.invalid:someone/plink.git"
ln -s "$PL" "$SANDBOX/plink-link"
register plink "$SANDBOX/plink-link" "build=make" "test=make test"
install_ut
audit "$PL"
check "no worktrees/ yet" [ ! -e "$PL/worktrees" ]
check "worktrees-not-ignored is still reported (got: ${AUDIT_OUT//$'\t'/ | })" \
    grep -qE $'^3\tworktrees-not-ignored\twarn\tworktrees/\t' <<< "$AUDIT_OUT"

echo "TEST: category 6, the user tier not installed"
EMPTY_HOME="$SANDBOX/emptyhome"
mkdir -p "$EMPTY_HOME"
AUDIT_RC=0
AUDIT_OUT="$(cd "$CLEAN" && HOME="$EMPTY_HOME" PATH="$STUB_BIN:$PATH" AGENT_WORKSPACE_CLAUDE_BIN="$STUB" \
    "$WS/.agent/scripts/project_integration_audit.sh" 2>/dev/null)" || AUDIT_RC=$?
check "exit 0" [ "$AUDIT_RC" -eq 0 ]
check "user-tier error" grep -qE $'^6\tuser-tier\terror\tuser tier\tuser_tier_install.sh --check --require failed' <<< "$AUDIT_OUT"

echo "TEST: category 6, a session at the root that does not resolve to the project"
# No registry the parser accepts makes a registered root resolve to another
# project (duplicate paths are refused), so the sandbox's session_root.sh is
# swapped for a stub for these two cases, then restored.
SR="$WS/.agent/scripts/session_root.sh"
cp -p "$SR" "$SANDBOX/session_root.real"
printf '#!/usr/bin/env bash\necho "session_root: stub refusal" >&2\nexit 1\n' > "$SR"
audit "$CLEAN"
check "session_root.sh exit 1: a session-root error naming the exit and the reason" \
    grep -qE $'^6\tsession-root\terror\t'"$CLEAN"$'\ta session started here does not resolve to .clean. \\(session_root.sh exit 1\\): session_root: stub refusal' <<< "$AUDIT_OUT"
printf '#!/usr/bin/env bash\nprintf "root=/elsewhere\\ntype=project\\nproject=other\\n"\n' > "$SR"
audit "$CLEAN"
check "resolving to another project: a session-root error (got: ${AUDIT_OUT//$'\t'/ | })" \
    grep -qE $'^6\tsession-root\terror\t'"$CLEAN"$'\t.*exit 0.*project=other' <<< "$AUDIT_OUT"
cp -p "$SANDBOX/session_root.real" "$SR"
audit "$CLEAN"
check "restored: no finding again" [ -z "$AUDIT_OUT" ]

echo "TEST: a root that is not a git repository"
NG="$SANDBOX/projects/nogit"
mkdir -p "$NG"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$NG/Makefile"
register nogit "$NG" "build=make" "test=make test"
audit "$NG"
check "exit 0" [ "$AUDIT_RC" -eq 0 ]
check "not-git info, no ignore-rule findings" bash -c 'grep -qE $'"'"'^3\tnot-git\tinfo\t'"'"' <<< "$1" && ! grep -qE $'"'"'^4\t'"'"' <<< "$1"' _ "$AUDIT_OUT"

echo "TEST: a parent root: the audit reads the chosen instance's settings and repository, not the parent's"
PAR="$SANDBOX/projects/fam"
mkdir -p "$PAR/a/.agents" "$PAR/b/.agents"
# The parent's own files say feature branch and ignore worktrees/: neither
# is the instance's, so neither may decide a finding (round 2's fixture had
# the parent's worktrees/ rule hide the instance's missing one).
printf '# fam\n\n- Work on a feature branch.\n' > "$PAR/CLAUDE.md"
printf 'worktrees/\na/\nb/\n' > "$PAR/.gitignore"
gitq -C "$PAR" init --quiet
commit_all "$PAR"
for i in a b; do
    printf 'all:\n\t@true\ntest:\n\t@true\n' > "$PAR/$i/Makefile"
    printf '# %s guide\n' "$i" > "$PAR/$i/.agents/README.md"
    gitq -C "$PAR/$i" init --quiet
    commit_all "$PAR/$i"
    gitq -C "$PAR/$i" remote add origin "git@example.invalid:someone/fam-$i.git"
done
# Instance a: no ignore rule for its worktrees directory, and an
# instruction line of its own; instance b: clean.
printf '# a\n\n- Push the feature branch for review.\n' > "$PAR/a/CLAUDE.md"
commit_all "$PAR/a"
printf 'worktrees/\n' > "$PAR/b/.gitignore"
commit_all "$PAR/b"
printf 'fam project %s default_instance=fam_a\n' "$PAR" >> "$WS/.agent/projects.local"
printf 'fam_a single_project %s parent=fam\n' "$PAR/a" >> "$WS/.agent/projects.local"
printf 'fam_b single_project %s parent=fam\n' "$PAR/b" >> "$WS/.agent/projects.local"
printf 'build=make\ntest=make test\ninstructions=none\n' > "$WS/.agent/projects.d/fam_a"
printf 'build=make\ntest=make test\ninstructions=tracked\n' > "$WS/.agent/projects.d/fam_b"
install_ut
audit "$PAR"
check "exit 0" [ "$AUDIT_RC" -eq 0 ]
check "the instance's line is a candidate, the parent's is not (got: $(awk -F'\t' '$2 == "process-branch" { print $4 }' <<< "$AUDIT_OUT" | paste -sd' ' -))" \
    [ "$(awk -F'\t' '$2 == "process-branch" { print $4 }' <<< "$AUDIT_OUT" | paste -sd' ' -)" = "CLAUDE.md:3" ]
check "the parent's CLAUDE.md is not read" bash -c '! grep -qF "Work on a feature branch" <<< "$1"' _ "$AUDIT_OUT"
check "the default instance's instructions=none applies (got $(sev_of process-branch))" [ "$(sev_of process-branch)" = "info" ]
check "the instance's worktrees directory is checked in its own repository, not hidden by the parent's rule" \
    grep -qE $'^3\tworktrees-not-ignored\twarn\tworktrees/\t' <<< "$AUDIT_OUT"
check "no finding about the parent's own files (got: ${AUDIT_OUT//$'\t'/ | })" \
    bash -c '! grep -qE $'"'"'\t(a|b)/'"'"' <<< "$1"' _ "$AUDIT_OUT"
check "the root resolves: no session-root or registration error (got: ${AUDIT_OUT//$'\t'/ | })" \
    bash -c '! grep -qE $'"'"'^6\t'"'"' <<< "$1"' _ "$AUDIT_OUT"
audit "$PAR" --format text
check "the text names the parent root" grep -qF "Integration audit: fam (project) at $PAR" <<< "$AUDIT_OUT"
check "and the instance audited" grep -qxF "audited: instance fam_a at $PAR/a, its settings and its repository (a parent root has no settings of its own, and its own files are not audited)" <<< "$AUDIT_OUT"
audit "$PAR" --instance fam_b
check "--instance fam_b: its repository, which ignores worktrees/ and has no candidate line: no finding (got: ${AUDIT_OUT//$'\t'/ | })" \
    [ -z "$AUDIT_OUT" ]
# The instance's registration is verified, not only the parent's (whose
# check reads no settings, commands or adapter).
cp "$WS/.agent/projects.d/fam_b" "$SANDBOX/fam_b.settings"
printf 'build=make\nthis line is no setting\n' > "$WS/.agent/projects.d/fam_b"
audit "$PAR" --instance fam_b
check "an instance with malformed settings: a registration error naming it (got: ${AUDIT_OUT//$'\t'/ | })" \
    grep -qE $'^6\tregistration\terror\tfam_b\t' <<< "$AUDIT_OUT"
check "and none for the parent" bash -c '! grep -qE $'"'"'^6\tregistration\terror\tfam\t'"'"' <<< "$1"' _ "$AUDIT_OUT"
printf 'build=make\ninstructions=tracked\n' > "$WS/.agent/projects.d/fam_b"
audit "$PAR" --instance fam_b
check "an instance with no test command: a registration error naming it (got: ${AUDIT_OUT//$'\t'/ | })" \
    grep -qE $'^6\tregistration\terror\tfam_b\tno test command' <<< "$AUDIT_OUT"
audit "$PAR"
check "the default instance (fam_a) is verified, not fam_b: no registration error (got: ${AUDIT_OUT//$'\t'/ | })" \
    bash -c '! grep -qE $'"'"'^6\tregistration\t'"'"' <<< "$1"' _ "$AUDIT_OUT"
cp "$SANDBOX/fam_b.settings" "$WS/.agent/projects.d/fam_b"
audit "$PAR" --instance clean
check "--instance of another project: exit 2" [ "$AUDIT_RC" -eq 2 ]
check "it names the parent's instances" grep -qF "its instances: fam_a fam_b" <<< "$AUDIT_ERR"
audit "$CLEAN" --instance fam_a
check "--instance at a root that is no parent: exit 2" [ "$AUDIT_RC" -eq 2 ]
PS_RC=0
PS_OUT="$(cd "$PAR" && HOME="$HOMEDIR" "$WS/.agent/scripts/project_setting.sh" set fam_b instructions=none 2>&1)" || PS_RC=$?
check "from the parent root, an instance's setting is written (exit $PS_RC: $PS_OUT)" [ "$PS_RC" -eq 0 ]
check "the instance's file has it" grep -qx "instructions=none" "$WS/.agent/projects.d/fam_b"
PS_RC=0
PS_OUT="$(cd "$PAR" && HOME="$HOMEDIR" "$WS/.agent/scripts/project_setting.sh" set fam instructions=none 2>&1)" || PS_RC=$?
check "and the parent's own name is refused" [ "$PS_RC" -ne 0 ]
check "no settings file under the parent's name" [ ! -e "$WS/.agent/projects.d/fam" ]
sed -i 's/ default_instance=fam_a$//' "$WS/.agent/projects.local"
audit "$PAR" --format text
check "several instances, no default: says no instance was audited" grep -qF "audited: no instance (several instances and no default_instance" <<< "$AUDIT_OUT"
check "and instructions are not set" grep -qxF "instructions: not set" <<< "$AUDIT_OUT"
audit "$PAR"
check "several instances, no default: a parent-instance info finding naming them (got: ${AUDIT_OUT//$'\t'/ | })" \
    grep -qE $'^6\tparent-instance\tinfo\tfam\tseveral instances \\(fam_a fam_b\\)' <<< "$AUDIT_OUT"
check "and nothing in categories 1 to 5 (got: $(cats))" bash -c '! grep -qE $'"'"'^[1-5]\t'"'"' <<< "$1"' _ "$AUDIT_OUT"

echo "TEST: a parent root with no instances registered"
P0="$SANDBOX/projects/lone"
mkdir -p "$P0"
gitq -C "$P0" init --quiet
printf '# lone\n' > "$P0/README.md"
commit_all "$P0"
printf 'lone project %s\n' "$P0" >> "$WS/.agent/projects.local"
install_ut
audit "$P0"
check "exit 0" [ "$AUDIT_RC" -eq 0 ]
check "a parent-instance error saying to register an instance first (got: ${AUDIT_OUT//$'\t'/ | })" \
    grep -qE $'^6\tparent-instance\terror\tlone\ta parent root with no instances registered: .*register_project.sh <path> --parent lone' <<< "$AUDIT_OUT"
audit "$P0" --format text
check "the text says none are registered, not several" grep -qxF "audited: no instance (none registered; register one first)" <<< "$AUDIT_OUT"
sed -i '/^lone project /d' "$WS/.agent/projects.local"
install_ut

echo "TEST: --facts, with stub gh and uname (never the real ones, never the network)"
FACT_BIN="$SANDBOX/factbin"
mkdir -p "$FACT_BIN"
GH_LOG="$SANDBOX/gh.log"
# gh: logs its arguments and answers from the STUB_GH_* variables.
cat > "$FACT_BIN/gh" <<'GHEOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_GH_LOG"
if [ "${STUB_GH_RC:-0}" -ne 0 ]; then echo "${STUB_GH_ERR:-gh: not logged in}" >&2; exit "$STUB_GH_RC"; fi
# Like the real gh: a repository named without its host goes to $GH_HOST.
if [ -n "${GH_HOST:-}" ] && ! grep -qE '(^| )github\.com/[^ ]+/[^ ]+( |$)' <<< "$*"; then
    echo "HTTP 404: Not Found (https://$GH_HOST/api/v3/...)" >&2; exit 1
fi
case "$1 $2" in
    "issue list"|"pr list")
        if [ "${STUB_GH_LIST_RC:-0}" -ne 0 ]; then echo "HTTP 502: Bad Gateway" >&2; exit "$STUB_GH_LIST_RC"; fi ;;
esac
case "$1 $2" in
    "repo view")  printf '%s\n' "$STUB_GH_VIEW" ;;
    "issue list") printf '%s\n' "${STUB_GH_ISSUES:-[]}" ;;
    "pr list")    printf '%s\n' "${STUB_GH_PRS:-[]}" ;;
    *) echo "stub gh: unexpected call: $*" >&2; exit 9 ;;
esac
GHEOF
printf '#!/usr/bin/env bash\n[ "$1" = "-s" ] || exit 9\necho "${STUB_UNAME:-Linux}"\n' > "$FACT_BIN/uname"
chmod +x "$FACT_BIN/gh" "$FACT_BIN/uname"
facts() { # <cwd> <args...>: like audit, with --facts and the fact stubs first on PATH
    # (FACT_PATH, when set, is the whole PATH instead)
    local cwd="$1"
    shift
    : > "$GH_LOG"
    AUDIT_RC=0
    AUDIT_OUT="$(cd "$cwd" && HOME="$HOMEDIR" PATH="${FACT_PATH:-$FACT_BIN:$STUB_BIN:$PATH}" STUB_GH_LOG="$GH_LOG" \
        "$WS/.agent/scripts/project_integration_audit.sh" --facts "$@" 2>"$SANDBOX/audit.err")" || AUDIT_RC=$?
    AUDIT_ERR="$(cat "$SANDBOX/audit.err")"
}
fval() { awk -F'\t' -v n="$1" '$1 == n { print $2 }' <<< "$AUDIT_OUT"; }
fev() { awk -F'\t' -v n="$1" '$1 == n { print $3 }' <<< "$AUDIT_OUT"; }

FG="$SANDBOX/projects/factgh"
mkdir -p "$FG/pkgs/a" "$FG/pkgs/b" "$FG/node_modules/dep"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$FG/Makefile"
printf '<package/>\n' > "$FG/pkgs/a/package.xml"
printf '<package/>\n' > "$FG/pkgs/b/package.xml"
printf '{}\n' > "$FG/node_modules/dep/package.json"
gitq -C "$FG" init --quiet
gitq -C "$FG" add -A
gitq -C "$FG" add -f node_modules
gitq -C "$FG" commit --quiet -m init
gitq -C "$FG" remote add origin "git@github.com:Someone/FactGH.git"
register factgh "$FG" "build=make" "test=make test"
install_ut

export STUB_GH_VIEW='{"hasIssuesEnabled":true,"issues":{"totalCount":3},"pullRequests":{"totalCount":0}}'
export STUB_GH_PRS='[{"number":7}]'
facts "$FG/pkgs"
check "exit 0" [ "$AUDIT_RC" -eq 0 ]
check "five facts in order: github issues prs windows multi_component (got: $(cut -f1 <<< "$AUDIT_OUT" | paste -sd' ' -))" \
    [ "$(cut -f1 <<< "$AUDIT_OUT" | paste -sd' ' -)" = "github issues prs windows multi_component" ]
check "every line has three tab-separated fields and a yes/no/unknown value" \
    awk -F'\t' 'NF != 3 || $2 !~ /^(yes|no|unknown)$/ { bad = 1 } END { exit bad }' <<< "$AUDIT_OUT"
check "github yes, naming the repository (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "yes/remote 'origin' is github.com/someone/factgh" ]
check "issues yes from the open count (got: $(fev issues))" [ "$(fval issues)" = "yes" ]
check "prs yes from a closed one when none is open (got: $(fev prs))" \
    [ "$(fval prs)/$(fev prs)" = "yes/none open on github.com/someone/factgh, but some were opened before" ]
check "gh was asked only to read: repo view, then pr list over every state (got: $(paste -sd'|' "$GH_LOG"))" \
    [ "$(paste -sd'|' "$GH_LOG")" = "repo view github.com/someone/factgh --json hasIssuesEnabled,issues,pullRequests|pr list -R github.com/someone/factgh --state all --limit 1 --json number" ]
check "windows no on Linux (got: $(fev windows))" [ "$(fval windows)/$(fev windows)" = "no/this machine: uname -s is Linux" ]
check "multi_component yes: two package.xml directories, the tracked node_modules one left out (got: $(fev multi_component))" \
    [ "$(fval multi_component)/$(fev multi_component)" = "yes/component manifests in 2 directories: pkgs/a, pkgs/b" ]

export STUB_GH_VIEW='{"hasIssuesEnabled":true,"issues":{"totalCount":0},"pullRequests":{"totalCount":0}}'
export STUB_GH_ISSUES='[]' STUB_GH_PRS='[]'
facts "$FG"
check "issues enabled but none ever opened: issues no (got: $(fev issues))" \
    [ "$(fval issues)/$(fev issues)" = "no/enabled on github.com/someone/factgh, but none was ever opened" ]
check "no pull request ever: prs no" [ "$(fval prs)" = "no" ]
check "and gh issue list was asked over every state" grep -qxF "issue list -R github.com/someone/factgh --state all --limit 1 --json number" "$GH_LOG"
export STUB_GH_ISSUES='[{"number":1}]'
facts "$FG"
check "none open, one closed: issues yes" [ "$(fval issues)" = "yes" ]
export STUB_GH_VIEW='{"hasIssuesEnabled":false,"issues":{"totalCount":0},"pullRequests":{"totalCount":2}}'
facts "$FG"
check "issues disabled: issues no, and no issue list call (got: $(fev issues))" \
    bash -c '[ "$1" = "no/issues are disabled on github.com/someone/factgh" ] && ! grep -q "^issue list" "$2"' _ "$(fval issues)/$(fev issues)" "$GH_LOG"
check "2 open pull requests: prs yes" [ "$(fval prs)/$(fev prs)" = "yes/2 open on github.com/someone/factgh" ]
export STUB_GH_RC=1
facts "$FG"
check "gh fails (not signed in): issues and prs unknown, saying why (got: $(fev issues))" \
    bash -c '[ "$1" = unknown ] && [ "$2" = unknown ] && [ "$3" = "gh failed, exit 1: gh repo view github.com/someone/factgh (its message is not printed; its first word: gh)" ]' \
    _ "$(fval issues)" "$(fval prs)" "$(fev issues)"
check "the audit still exits 0" [ "$AUDIT_RC" -eq 0 ]
unset STUB_GH_RC
export STUB_GH_VIEW='{"hasIssuesEnabled":true,"issues":{"totalCount":0},"pullRequests":{"totalCount":0}}'
export STUB_GH_ISSUES='[{"number":1}]' STUB_GH_PRS='[{"number":2}]'
GH_HOST=ghe.example.invalid facts "$FG"
check "with GH_HOST naming another server, every gh call still names github.com/<owner>/<repo> (got: $(paste -sd'|' "$GH_LOG"))" \
    bash -c '[ "$(wc -l < "$1")" -eq 3 ] && ! grep -vqE "(^| )github\.com/someone/factgh( |$)" "$1"' _ "$GH_LOG"
check "and its answers are github.com's: issues yes, prs yes (got: $(fval issues)/$(fval prs))" \
    [ "$(fval issues)/$(fval prs)" = "yes/yes" ]
unset STUB_GH_ISSUES STUB_GH_PRS
export STUB_GH_VIEW='{"message":"Not Found"}'
facts "$FG"
check "an answer without the counts: unknown, not no (got: $(fval issues))" [ "$(fval issues)" = "unknown" ]
export STUB_GH_VIEW='{"hasIssuesEnabled":true,"issues":{"totalCount":0},"pullRequests":{"totalCount":1}}'
export STUB_GH_ISSUES='garbage'
facts "$FG"
check "a list answer that is not JSON: issues unknown, naming the call, not printing the answer (got: $(fev issues))" \
    bash -c '[ "$1" = unknown ] && [ "$2" = "gh issue list -R github.com/someone/factgh gave no JSON list (its answer is not printed)" ]' _ "$(fval issues)" "$(fev issues)"
for _notlist in '{"number":1}' '"x"' '1'; do
    export STUB_GH_ISSUES="$_notlist"
    facts "$FG"
    check "a list answer that is JSON but not a list ($_notlist): issues unknown, never yes (got: $(fval issues))" \
        bash -c '[ "$1" = unknown ] && grep -qF "gave no JSON list" <<< "$2"' _ "$(fval issues)" "$(fev issues)"
done
unset STUB_GH_ISSUES STUB_GH_PRS
STUB_UNAME=MINGW64_NT-10.0-19045 facts "$FG"
check "uname -s MINGW64: windows yes" [ "$(fval windows)/$(fev windows)" = "yes/this machine: uname -s is MINGW64_NT-10.0-19045" ]
STUB_UNAME=Darwin facts "$FG"
check "uname -s Darwin: windows no" [ "$(fval windows)" = "no" ]
facts "$FG" --format text
check "--format text: a heading and fact: value -- evidence lines" \
    bash -c 'grep -qxF "Facts: factgh at $2" <<< "$1" && grep -qxF "github: yes -- remote '"'"'origin'"'"' is github.com/someone/factgh" <<< "$1" && [ "$(grep -c -- " -- " <<< "$1")" -eq 5 ]' \
    _ "$AUDIT_OUT" "$FG"

echo "TEST: --facts without GitHub: no gh call at all"
facts "$CLEAN"
check "a remote on another host: github no, naming the host (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "no/remote 'origin' is example.invalid/someone/clean, not github.com by name" ]
check "issues and prs no" [ "$(fval issues)/$(fval prs)" = "no/no" ]
check "gh was not called" [ ! -s "$GH_LOG" ]
check "one Makefile and no manifest: multi_component no (got: $(fev multi_component))" \
    [ "$(fval multi_component)" = "no" ]
# A remote URL carrying a credential: only host and path may be printed.
for _cred_url in "https://someone:s3cr3tTOKEN@gitlab.example.invalid/someone/clean.git" \
        "https://s3cr3tTOKEN@gitlab.example.invalid/someone/clean" \
        "https://someone:s3cr3tTOKEN@gitlab.example.invalid"; do
    gitq -C "$CLEAN" remote set-url origin "$_cred_url"
    facts "$CLEAN"
    _tsv="$AUDIT_OUT$AUDIT_ERR"
    facts "$CLEAN" --format text
    check "a credential in the remote URL never reaches the output, tsv or text ($_cred_url)" \
        bash -c '! grep -qF s3cr3tTOKEN <<< "$1"' _ "$_tsv$AUDIT_OUT$AUDIT_ERR"
done
gitq -C "$CLEAN" remote set-url origin "https://someone:s3cr3tTOKEN@gitlab.example.invalid/someone/clean.git"
facts "$CLEAN"
check "the evidence names host and path only (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "no/remote 'origin' is gitlab.example.invalid/someone/clean, not github.com by name" ]
# Every URL form that can carry a secret, on origin and on a second
# remote, GitHub or not: the secret never reaches the output (tsv or text)
# or a gh call.
no_secret() { # <label>: run --facts in tsv and text; the secret is in neither, nor in gh's arguments
    facts "$CLEAN"
    local all
    all="$AUDIT_OUT$AUDIT_ERR$(cat "$GH_LOG")"
    facts "$CLEAN" --format text
    all+="$AUDIT_OUT$AUDIT_ERR$(cat "$GH_LOG")"
    check "$1: the secret never reaches the output or a gh call" bash -c '! grep -qiF s3cr3tTOKEN <<< "$1"' _ "$all"
}
export STUB_GH_VIEW='{"hasIssuesEnabled":true,"issues":{"totalCount":1},"pullRequests":{"totalCount":1}}'
for _cred_url in "https://github.com/someone/clean?token=s3cr3tTOKEN" \
        "https://github.com/someone/clean.git#s3cr3tTOKEN" \
        "https://someone:s3cr3tTOKEN@github.com/someone/clean.git" \
        "ssh://git:s3cr3tTOKEN@ssh.github.com:443/someone/clean.git"; do
    gitq -C "$CLEAN" remote set-url origin "$_cred_url"
    facts "$CLEAN"
    check "a secret in a GitHub remote ($_cred_url): github yes, github.com/someone/clean, gh asked about that alone (got: $(fval github)/$(fev github) | $(head -n1 "$GH_LOG"))" \
        bash -c '[ "$1" = "yes/remote '"'"'origin'"'"' is github.com/someone/clean" ] && [ "$2" = "repo view github.com/someone/clean --json hasIssuesEnabled,issues,pullRequests" ]' \
        _ "$(fval github)/$(fev github)" "$(head -n1 "$GH_LOG")"
    no_secret "GitHub remote $_cred_url"
done
for _cred_url in "https://gitlab.example.invalid/someone/clean?private_token=s3cr3tTOKEN" \
        "ssh://someone:s3cr3tTOKEN@gitlab.example.invalid:2222/someone/clean.git"; do
    gitq -C "$CLEAN" remote set-url origin "$_cred_url"
    facts "$CLEAN"
    check "a secret in another host's remote ($_cred_url): github no, host and path only (got: $(fev github))" \
        [ "$(fval github)/$(fev github)" = "no/remote 'origin' is gitlab.example.invalid/someone/clean, not github.com by name" ]
    no_secret "remote $_cred_url"
done
gitq -C "$CLEAN" remote set-url origin "file://someone:s3cr3tTOKEN@localhost$SANDBOX/projects/factgh?s3cr3tTOKEN"
facts "$CLEAN"
check "a file:// remote with a user part and a query: a local path, printed without either (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "no/remote 'origin' is a local path: file://localhost$SANDBOX/projects/factgh" ]
no_secret "a file:// remote"
# The class behind those, as a table: a secret holding "?", "#", "@",
# "/", ":" or "://", in the user part, the query or the fragment of each
# form (https, ssh, scp, file:// with a host). The secret marker sits on
# both sides of the character, so a kept prefix or a kept suffix both
# show. The secret never appears, in either output format or in gh's
# arguments, and the github fact is either read (GitHub, gh asked about
# github.com/someone/clean alone) or unknown (the URL could not be cut
# safely, gh not called): never a wrong host.
gh_read() { # <label>: github yes, github.com/someone/clean, gh asked about that alone
    check "$1: github yes, github.com/someone/clean, gh asked about that alone (got: $(fval github)/$(fev github) | $(head -n1 "$GH_LOG"))" \
        bash -c '[ "$1" = "yes/remote '"'"'origin'"'"' is github.com/someone/clean" ] && [ "$2" = "repo view github.com/someone/clean --json hasIssuesEnabled,issues,pullRequests" ]' \
        _ "$(fval github)/$(fev github)" "$(head -n1 "$GH_LOG")"
}
gh_unread() { # <label>: github unknown, the URL not printed, gh not called
    check "$1: github unknown, its URL not printed, gh not called (got: $(fval github)/$(fev github))" \
        bash -c '[ "$1" = unknown ] && grep -qF "has a URL that could not be printed safely" <<< "$2" && [ ! -s "$3" ]' \
        _ "$(fval github)" "$(fev github)" "$GH_LOG"
}
for _c in '?' '#' '@' '/' ':' '://'; do
    _pw="s3cr3tTOKEN${_c}s3cr3tTOKEN"
    # A password holding "?" or "#" cannot be told from a query holding
    # "@", nor one holding "/" (or "://") from a path holding "@", so that
    # URL is not read; any other is read past its user part. The scp form
    # never is: git takes its host from the text before the first ":", so
    # a ":" in its user part makes git contact another host.
    case "$_c" in '?'|'#'|'/'|'://') _user_read=0 ;; *) _user_read=1 ;; esac
    for _form in https ssh scp; do
        _form_read="$_user_read"
        [ "$_form" = scp ] && _form_read=0
        case "$_form" in
            https) _base="https://github.com/someone/clean.git"; _cred="https://someone:${_pw}@github.com/someone/clean.git" ;;
            ssh)   _base="ssh://git@ssh.github.com:443/someone/clean.git"; _cred="ssh://git:${_pw}@ssh.github.com:443/someone/clean.git" ;;
            scp)   _base="git@github.com:someone/clean.git"; _cred="someone:${_pw}@github.com:someone/clean.git" ;;
        esac
        gitq -C "$CLEAN" remote set-url origin "$_cred"
        facts "$CLEAN"
        if [ "$_form_read" -eq 1 ]; then
            gh_read "a password holding '$_c' ($_cred)"
        else
            gh_unread "a password holding '$_c' ($_cred)"
        fi
        no_secret "a password holding '$_c' ($_cred)"
        for _cred in "$_base?token=${_pw}" "$_base#${_pw}"; do
            gitq -C "$CLEAN" remote set-url origin "$_cred"
            facts "$CLEAN"
            # An "@" after an scp remote's ":" is never cut (a password
            # cannot be told from a query holding one).
            if [ "$_form" = scp ] && [ "$_c" = '@' ]; then
                gh_unread "a query or fragment holding '$_c' ($_cred)"
            else
                gh_read "a query or fragment holding '$_c' ($_cred)"
            fi
            no_secret "a query or fragment holding '$_c' ($_cred)"
        done
    done
    gitq -C "$CLEAN" remote set-url origin "file://someone:${_pw}@localhost$SANDBOX/projects/factgh"
    facts "$CLEAN"
    if [ "$_user_read" -eq 1 ]; then
        _want="file://localhost$SANDBOX/projects/factgh"
    else
        _want="file://<redacted>"
    fi
    check "a password holding '$_c' in a file:// remote: a local path, printed as $_want (got: $(fev github))" \
        [ "$(fval github)/$(fev github)" = "no/remote 'origin' is a local path: $_want" ]
    no_secret "a password holding '$_c' in a file:// remote"
    for _cred in "file://localhost$SANDBOX/projects/factgh?token=${_pw}" "file://localhost$SANDBOX/projects/factgh#${_pw}"; do
        gitq -C "$CLEAN" remote set-url origin "$_cred"
        facts "$CLEAN"
        check "a query or fragment holding '$_c' in a file:// remote with a host: cut (got: $(fev github))" \
            [ "$(fval github)/$(fev github)" = "no/remote 'origin' is a local path: file://localhost$SANDBOX/projects/factgh" ]
        no_secret "a query or fragment holding '$_c' in a file:// remote with a host"
    done
done
# No user part, but an "@" in the query, fragment or path: it is not
# read as one. In a query or fragment with a path before it the remote is
# read; with none, or when the text before the "@" holds a "/" (an "@" in
# a path would otherwise print another host: gitlab.com/x@github.com/...
# as GitHub), the URL is not read and gh is not called. In the scp form
# an "@" anywhere after the host's ":" is not read either: git takes it
# as part of the path, and someone:pw?pw@github.com:o/r holds a password.
for _cred_url in "https://github.com/someone/clean?user=me@x.com&token=s3cr3tTOKEN" \
        "https://github.com/someone/clean#frag@s3cr3tTOKEN" \
        "https://github.com/someone/clean.git#user=me@x.com"; do
    gitq -C "$CLEAN" remote set-url origin "$_cred_url"
    facts "$CLEAN"
    gh_read "an '@' in the query or fragment of a remote with no user part ($_cred_url)"
    no_secret "an '@' in the query or fragment of a remote with no user part ($_cred_url)"
done
for _cred_url in "https://github.com?user=me@x.com&token=s3cr3tTOKEN" \
        "https://s3cr3tTOKEN?s3cr3tTOKEN@github.com" \
        "https://github.com/someone/clean?next=a@b/c&token=s3cr3tTOKEN" \
        "git@github.com:someone/clean.git?user=me@x.com&token=s3cr3tTOKEN" \
        "git@github.com:someone/clean?x=a@b:c&token=s3cr3tTOKEN" \
        "https://github.com/someone/clean/x@y/z" \
        "https://example.invalid/repos/foo@v2/bar.git" \
        "https://gitlab.com/x@github.com/someone/clean" \
        "git@gitlab.com:x@github.com:someone/clean.git"; do
    gitq -C "$CLEAN" remote set-url origin "$_cred_url"
    facts "$CLEAN"
    gh_unread "an '@' that may end a user part or sit in a query or path ($_cred_url)"
    no_secret "an '@' that may end a user part or sit in a query or path ($_cred_url)"
done
# Not a plain cut URL: a remote-helper address <transport>::<address>
# (ext:: runs a command, which can hold a token), an IPv6 host, or a host
# or path holding a space or a quote (https://local /x would otherwise
# read as a local path). Not printed, gh not called.
for _cred_url in 'ext::sh -c "curl -H X-Token:s3cr3tTOKEN https://github.com/someone/clean"' \
        "ext::s3cr3tTOKEN" \
        "https://local /someone/clean" \
        "https://github.com/someone/clean s3cr3tTOKEN" \
        "https://github.com/someone/\"s3cr3tTOKEN\"" \
        "git@github.com:some one/clean.git" \
        "ssh://[::1]/someone/clean.git"; do
    gitq -C "$CLEAN" remote set-url origin "$_cred_url"
    facts "$CLEAN"
    gh_unread "not a plain cut URL ($_cred_url)"
    no_secret "not a plain cut URL ($_cred_url)"
done
# The scp form: git contacts the host before the first ":", so that text
# must be a plain [user@]host. A ":" or "@" in the user part would print
# github.com while git contacts host x (or tok): not read, gh not called.
for _cred_url in "x:y@github.com:someone/clean" "tok:s3cr3tTOKEN@github.com:someone/clean" \
        "someone:s3cr3tTOKEN@gitlab.example.invalid:someone/clean.git" \
        "a@b@github.com:someone/clean" "\"x\"@github.com:someone/clean"; do
    gitq -C "$CLEAN" remote set-url origin "$_cred_url"
    facts "$CLEAN"
    gh_unread "an scp host that is not a plain name ($_cred_url)"
    no_secret "an scp host that is not a plain name ($_cred_url)"
done
for _cred_url in "user@github.com:someone/clean" "github.com:someone/clean"; do
    gitq -C "$CLEAN" remote set-url origin "$_cred_url"
    facts "$CLEAN"
    gh_read "an scp remote with a plain [user@]host ($_cred_url)"
done
# The plain-character rule is byte-based whatever the caller's locale:
# under en_US.UTF-8 a bracket range such as [A-Za-z] can match a letter
# outside ASCII, which printed this host there and redacted it under
# C.UTF-8. The script sets LC_ALL=C, so both give the same output.
gitq -C "$CLEAN" remote set-url origin "$(printf 'https://g\xc3\xaethub.com/someone/clean')"
_loc_out=()
for _loc in en_US.UTF-8 C.UTF-8; do
    if [ "$(LC_ALL="$_loc" locale charmap 2>/dev/null)" != "UTF-8" ]; then
        echo "  SKIP: locale $_loc is not installed here, so the en_US.UTF-8 / C.UTF-8 comparison is not run"
        continue
    fi
    LC_ALL="$_loc" LANG="$_loc" facts "$CLEAN"
    _loc_out+=("$AUDIT_OUT")
    gh_unread "a host outside ASCII under $_loc"
    check "and the host is not printed under $_loc (got: $(fev github))" bash -c '! grep -qF "$2" <<< "$1"' _ "$(fev github)" "$(printf 'g\xc3\xaethub')"
done
if [ "${#_loc_out[@]}" -eq 2 ]; then
    check "a host outside ASCII: the same output under en_US.UTF-8 and C.UTF-8" [ "${_loc_out[0]}" = "${_loc_out[1]}" ]
fi
# A second remote that could not be read may be on GitHub: unknown.
gitq -C "$CLEAN" remote set-url origin "git@example.invalid:someone/clean.git"
gitq -C "$CLEAN" remote add upstream "https://someone:s3cr3tTOKEN?s3cr3tTOKEN@github.com/someone/clean.git"
facts "$CLEAN"
check "a second remote whose URL could not be printed safely: github unknown, saying so (got: $(fval github)/$(fev github))" \
    bash -c '[ "$1" = unknown ] && grep -qF "but remote '"'"'upstream'"'"' has a URL that could not be printed safely and may be on GitHub" <<< "$2"' \
    _ "$(fval github)" "$(fev github)"
no_secret "a second remote whose URL could not be printed safely"
gitq -C "$CLEAN" remote remove upstream
# github is read by name: a GitHub Enterprise server or an ssh host
# alias with no "github" in its name reads as no, and says so.
for _named in "https://git.corp.example/someone/clean.git" "git@work:someone/clean.git"; do
    gitq -C "$CLEAN" remote set-url origin "$_named"
    facts "$CLEAN"
    check "a host that is not github.com by name ($_named): github no, saying 'not github.com by name', gh not called (got: $(fval github)/$(fev github) | $(fev issues))" \
        bash -c '[ "$1" = no ] && grep -qF ", not github.com by name" <<< "$2" && [ "$3" = "no remote is github.com by name, so gh was not asked about its issues" ] && [ ! -s "$4" ]' \
        _ "$(fval github)" "$(fev github)" "$(fev issues)" "$GH_LOG"
done
# Where git push sends the remote: a pushurl or pushInsteadOf that reads
# differently is named at the end of the github evidence, read the same
# way as the fetch URL; one that reads the same is not.
gitq -C "$CLEAN" remote set-url origin "https://github.com/someone/clean.git"
_gh_yes="remote 'origin' is github.com/someone/clean"
for _push in "https://gitlab.example.invalid/someone/clean.git|gitlab.example.invalid/someone/clean" \
        "https://someone:s3cr3tTOKEN@gitlab.example.invalid/someone/clean|gitlab.example.invalid/someone/clean" \
        "x:s3cr3tTOKEN@github.com:someone/clean|a URL that could not be printed safely" \
        "$SANDBOX/srv/mirror|a local path: $SANDBOX/srv/mirror" \
        "git@github.com:someone/clean.git|"; do
    gitq -C "$CLEAN" config remote.origin.pushurl "${_push%%|*}"
    facts "$CLEAN"
    _want="yes/$_gh_yes"
    [ -n "${_push#*|}" ] && _want+="; its push URL differs: ${_push#*|}"
    check "a pushurl ${_push%%|*}: github evidence $_want (got: $(fval github)/$(fev github))" \
        [ "$(fval github)/$(fev github)" = "$_want" ]
    no_secret "a pushurl ${_push%%|*}"
done
gitq -C "$CLEAN" config --add remote.origin.pushurl "https://gitlab.example.invalid/someone/clean.git"
facts "$CLEAN"
check "two push URLs, one the same: only the other is named (got: $(fev github))" \
    [ "$(fev github)" = "$_gh_yes; its push URL differs: gitlab.example.invalid/someone/clean" ]
gitq -C "$CLEAN" config --unset-all remote.origin.pushurl
gitq -C "$CLEAN" config url."https://gitlab.example.invalid/".pushInsteadOf "https://github.com/"
facts "$CLEAN"
check "pushInsteadOf sending the push elsewhere is named (got: $(fev github))" \
    [ "$(fev github)" = "$_gh_yes; its push URL differs: gitlab.example.invalid/someone/clean" ]
gitq -C "$CLEAN" config --remove-section url."https://gitlab.example.invalid/"
facts "$CLEAN"
check "no pushurl: no note (got: $(fev github))" [ "$(fev github)" = "$_gh_yes" ]
# Forms with no authority keep their "?" and "#": part of the path there.
for _local in "$SANDBOX/projects/factgh?x#1" "file://$SANDBOX/projects/factgh?x#1"; do
    gitq -C "$CLEAN" remote set-url origin "$_local"
    facts "$CLEAN"
    check "a local path or file:/// remote keeps its '?' and '#' ($_local) (got: $(fev github))" \
        [ "$(fval github)/$(fev github)" = "no/remote 'origin' is a local path: $_local" ]
done
gitq -C "$CLEAN" remote set-url origin "git@example.invalid:someone/clean.git"
gitq -C "$CLEAN" remote add upstream "https://someone:s3cr3tTOKEN@github.com/someone/clean?token=s3cr3tTOKEN"
facts "$CLEAN"
check "a secret in the second remote: named by host and path only (got: $(fev github))" \
    grep -qF "but remote 'upstream' is github.com/someone/clean: which one" <<< "$(fev github)"
no_secret "the second remote"
gitq -C "$CLEAN" remote remove upstream
# None of gh's own text reaches the evidence, whatever its shape: a URL
# with a secret, one run over several words by a password or query
# holding spaces, a remote-helper command, prose holding ":" and "@", or a
# first word that is itself a secret. A failure gives the fixed phrase,
# the exit code and at most gh's first word from the fixed list; an answer
# that does not parse gives a fixed phrase. The secret never appears.
gitq -C "$CLEAN" remote set-url origin "https://github.com/someone/clean.git"
_gh_fail_phrase='gh failed, exit 1: gh repo view github.com/someone/clean (its message is not printed'
for _err in "error connecting to https://someone:s3cr3tTOKEN@github.com/someone/clean?access_token=s3cr3tTOKEN and someone:s3cr3tTOKEN@github.com:someone/clean" \
        'Get "https://user:abc s3cr3tTOKEN@github.com/someone/clean": dial tcp' \
        'Get https://user:s3cr3tTOKEN s3cr3tTOKEN:s3cr3tTOKEN s3cr3tTOKEN@github.com/someone/clean failed' \
        'cannot reach user:s3cr3tTOKEN s3cr3tTOKEN@github.com:someone/clean now' \
        'error: https://user:abc s3cr3tTOKEN tail:xxx@github.com/someone/clean' \
        'error: https://github.com/someone/clean?tok=abc s3cr3tTOKEN' \
        'helper ext::sh -c "curl -H X-Token:s3cr3tTOKEN https://x/y" failed' \
        'failed (exit 1): user s3cr3tTOKEN@example.invalid could not sign in' \
        'https://someone:s3cr3tTOKEN@github.com/someone/clean refused' \
        's3cr3tTOKEN is not a valid token'; do
    STUB_GH_RC=1 STUB_GH_ERR="$_err" no_secret "gh's error text: $_err"
    STUB_GH_RC=1 STUB_GH_ERR="$_err" facts "$CLEAN"
    check "gh's error text is replaced by the fixed phrase ($_err) (got: $(fev issues))" \
        bash -c '[ "$1" = unknown/unknown ] && [ "$2" = "$3" ] && [[ "$2" == "$4"* ]]' \
        _ "$(fval issues)/$(fval prs)" "$(fev issues)" "$(fev prs)" "$_gh_fail_phrase"
done
STUB_GH_RC=1 STUB_GH_ERR='error connecting to https://someone:s3cr3tTOKEN@github.com/someone/clean' facts "$CLEAN"
check "a first word on the fixed list is named (got: $(fev issues))" \
    [ "$(fev issues)" = "$_gh_fail_phrase; its first word: error)" ]
STUB_GH_RC=1 STUB_GH_ERR='https://someone:s3cr3tTOKEN@github.com/someone/clean refused' facts "$CLEAN"
check "a first word not on the list is not (got: $(fev issues))" \
    [ "$(fev issues)" = "$_gh_fail_phrase)" ]
# gh exits 0 with an answer that is not the JSON asked for: a fixed
# phrase, never a cut of the answer (a cut inside a token printed its
# prefix).
for _ans in "https://s3cr3tTOKENs3cr3tTOKEN@github.com/someone/clean" "s3cr3tTOKEN"; do
    STUB_GH_VIEW="$_ans" no_secret "gh repo view answering $_ans"
    STUB_GH_VIEW="$_ans" facts "$CLEAN"
    check "gh repo view answering text, not the counts: a fixed phrase (got: $(fev issues))" \
        [ "$(fev issues)" = "gh repo view github.com/someone/clean gave no hasIssuesEnabled, issues and pullRequests counts (its answer is not printed)" ]
done
export STUB_GH_VIEW='{"hasIssuesEnabled":true,"issues":{"totalCount":0},"pullRequests":{"totalCount":0}}'
STUB_GH_ISSUES="https://s3cr3tTOKEN@github.com/someone/clean" no_secret "gh issue list answering a URL"
export STUB_GH_VIEW='{"hasIssuesEnabled":true,"issues":{"totalCount":1},"pullRequests":{"totalCount":1}}'
# On github.com, but the path is not <owner>/<repo>: unknown, for that reason.
# With no path at all it is the same: https://github.com reads as host
# github.com, never as a host named after the scheme.
for _bad in "https://github.com/someone" "https://github.com/someone/clean/extra" "git@github.com:some+one/clean.git" \
        "https://github.com" "https://github.com/" "ssh://git@github.com" "HTTPS://GitHub.com:443"; do
    gitq -C "$CLEAN" remote set-url origin "$_bad"
    facts "$CLEAN"
    check "github.com with a path that is not <owner>/<repo> ($_bad): unknown, saying so, gh not called (got: $(fev github))" \
        bash -c '[ "$1" = unknown ] && grep -qF "on github.com, but the path is not <owner>/<repo>" <<< "$2" && ! grep -qF "looks like GitHub" <<< "$2" && [ ! -s "$3" ]' \
        _ "$(fval github)" "$(fev github)" "$GH_LOG"
done
gitq -C "$CLEAN" remote set-url origin "git@example.invalid:someone/clean.git"
# A host that only looks like GitHub, and GitHub on a remote other than origin.
gitq -C "$CLEAN" remote set-url origin "git@github.com-work:Someone/Clean.git"
facts "$CLEAN"
check "an ssh host alias (github.com-work): github unknown, saying the host only looks like GitHub (got: $(fev github))" \
    bash -c '[ "$1" = unknown ] && grep -qF "remote '"'"'origin'"'"' is github.com-work/someone/clean: the host looks like GitHub" <<< "$2"' _ "$(fval github)" "$(fev github)"
check "and issues and prs unknown, not no, with the same reason (got: $(fev issues))" \
    bash -c '[ "$1/$2" = unknown/unknown ] && grep -qF "github is unknown: remote '"'"'origin'"'"' is github.com-work" <<< "$3"' _ "$(fval issues)" "$(fval prs)" "$(fev issues)"
check "gh was not called" [ ! -s "$GH_LOG" ]
gitq -C "$CLEAN" remote set-url origin "ssh://git@ssh.github.com:443/Someone/Clean.git"
facts "$CLEAN"
check "ssh.github.com (ssh over 443) is github.com: github yes (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "yes/remote 'origin' is github.com/someone/clean" ]
gitq -C "$CLEAN" remote set-url origin "git@example.invalid:someone/clean.git"
gitq -C "$CLEAN" remote add upstream "https://github.com/someone/clean.git"
facts "$CLEAN"
check "origin elsewhere but another remote on GitHub: github unknown, naming both (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "unknown/remote 'origin' is example.invalid/someone/clean, not github.com by name, but remote 'upstream' is github.com/someone/clean: which one holds the issues and pull requests was not read" ]
check "issues and prs unknown, gh not called" \
    bash -c '[ "$1" = unknown/unknown ] && [ ! -s "$2" ]' _ "$(fval issues)/$(fval prs)" "$GH_LOG"
gitq -C "$CLEAN" remote remove upstream
facts "$HR"
check "no remote: github no (got: $(fev github))" [ "$(fval github)/$(fev github)" = "no/the repository has no remote" ]
check "a root CMakeLists.txt with project(): one directory, multi_component no (got: $(fev multi_component))" \
    [ "$(fval multi_component)/$(fev multi_component)" = "no/component manifests in one directory: ." ]
FL="$SANDBOX/projects/factlocal"
mkdir -p "$FL/sub"
printf 'cmake_minimum_required(VERSION 3.16)\nproject(fl)\nadd_subdirectory(sub)\n' > "$FL/CMakeLists.txt"
printf 'add_library(sub sub.c)\n' > "$FL/sub/CMakeLists.txt"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$FL/Makefile"
gitq -C "$FL" init --quiet
commit_all "$FL"
mkdir -p "$FL/untracked"
printf '[package]\n' > "$FL/untracked/Cargo.toml"
gitq -C "$FL" remote add origin "$SANDBOX/projects/factgh"
register factlocal "$FL" "build=make" "test=make test"
install_ut
facts "$FL"
check "a local-path remote: github no (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "no/remote 'origin' is a local path: $SANDBOX/projects/factgh" ]
check "a sub-CMakeLists.txt with no project() and an untracked Cargo.toml do not count (got: $(fev multi_component))" \
    [ "$(fval multi_component)/$(fev multi_component)" = "no/component manifests in one directory: ." ]
check "gh was not called" [ ! -s "$GH_LOG" ]
# An "@" in a local remote's path or in a manifest directory (an npm
# scoped package) is printed as it is: a local path names no server and
# is never sent anywhere.
gitq -C "$FL" remote set-url origin "$SANDBOX/srv/repo@2"
mkdir -p "$FL/packages/@scope/pkg"
printf '{}\n' > "$FL/packages/@scope/pkg/package.json"
gitq -C "$FL" add packages
gitq -C "$FL" commit --quiet -m scoped
facts "$FL"
check "a local remote whose path holds '@': printed as it is (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "no/remote 'origin' is a local path: $SANDBOX/srv/repo@2" ]
check "a manifest directory holding '@': printed as it is (got: $(fev multi_component))" \
    [ "$(fval multi_component)/$(fev multi_component)" = "yes/component manifests in 2 directories: ., packages/@scope/pkg" ]
gitq -C "$FL" reset --quiet --hard HEAD~1
# Control bytes (ESC, CR, DEL) in a manifest directory or a local remote
# path are dropped: no terminal escape reaches the evidence.
_ctl_dir="$(printf 'pk\033[31mg\rx\177y')"
gitq -C "$FL" remote set-url origin "$SANDBOX/srv/$_ctl_dir"
mkdir -p "$FL/$_ctl_dir"
printf '{}\n' > "$FL/$_ctl_dir/package.json"
gitq -C "$FL" add -- "$_ctl_dir"
gitq -C "$FL" commit --quiet -m ctl
facts "$FL"
check "control bytes in a local remote path are dropped (got: $(fev github | od -c | head -c 300))" \
    [ "$(fval github)/$(fev github)" = "no/remote 'origin' is a local path: $SANDBOX/srv/pk[31mgxy" ]
check "control bytes in a manifest directory are dropped (got: $(fev multi_component | od -c | head -c 300))" \
    [ "$(fval multi_component)/$(fev multi_component)" = "yes/component manifests in 2 directories: ., pk[31mgxy" ]
facts "$FL" --format text
check "and in the text format: no control byte but the line breaks" \
    bash -c '! LC_ALL=C grep -q "[[:cntrl:]]" <<< "$1"' _ "$AUDIT_OUT"
gitq -C "$FL" reset --quiet --hard HEAD~1
gitq -C "$FL" remote set-url origin "$SANDBOX/projects/factgh"
facts "$NG"
check "a root that is not a git repository: github no (got: $(fev github))" [ "$(fval github)" = "no" ]

echo "TEST: --facts edge cases: gh or jq missing, a list call failing, no commits, no origin, a nested root"
# PATHs without gh, and without jq: every other command on PATH linked
# into one directory, the stubs first.
fact_path_without() { # <dir> <command>
    local dir="$1" skip="$2" pd x b
    mkdir -p "$dir"
    IFS=: read -r -a _pdirs <<< "$FACT_BIN:$STUB_BIN:$PATH"
    for pd in "${_pdirs[@]}"; do
        [ -d "$pd" ] || continue
        for x in "$pd"/*; do
            b="${x##*/}"
            [ "$b" = "$skip" ] && continue
            [ -x "$x" ] && [ ! -e "$dir/$b" ] && ln -s "$x" "$dir/$b"
        done
    done
}
fact_path_without "$SANDBOX/nogh-bin" gh
fact_path_without "$SANDBOX/nojq-bin" jq
export STUB_GH_VIEW='{"hasIssuesEnabled":true,"issues":{"totalCount":0},"pullRequests":{"totalCount":0}}'
if PATH="$SANDBOX/nogh-bin" command -v gh >/dev/null 2>&1; then
    fail "the PATH without gh still finds gh"
else
    FACT_PATH="$SANDBOX/nogh-bin" facts "$FG"
    check "gh missing: github still yes, issues and prs unknown, saying gh is not installed (got: $(fev issues))" \
        [ "$(fval github)/$(fval issues)/$(fev issues)/$(fval prs)/$(fev prs)" = "yes/unknown/gh is not installed/unknown/gh is not installed" ]
fi
if PATH="$SANDBOX/nojq-bin" command -v jq >/dev/null 2>&1; then
    fail "the PATH without jq still finds jq"
else
    FACT_PATH="$SANDBOX/nojq-bin" facts "$FG"
    check "jq missing: issues and prs unknown, saying gh's answer was not read, and gh not called (got: $(fev issues))" \
        bash -c '[ "$1" = "yes/unknown/unknown" ] && grep -qF "jq is not installed" <<< "$2" && [ ! -s "$3" ]' \
        _ "$(fval github)/$(fval issues)/$(fval prs)" "$(fev issues)" "$GH_LOG"
fi
STUB_GH_LIST_RC=4 facts "$FG"
check "repo view answers but the list calls fail: issues and prs unknown, naming the list call (got: $(fev issues))" \
    bash -c '[ "$1" = unknown/unknown ] && [ "$2" = "gh failed, exit 4: gh issue list -R github.com/someone/factgh (its message is not printed; its first word: HTTP)" ] && [ "$3" = "gh failed, exit 4: gh pr list -R github.com/someone/factgh (its message is not printed; its first word: HTTP)" ]' \
    _ "$(fval issues)/$(fval prs)" "$(fev issues)" "$(fev prs)"

NC="$SANDBOX/projects/factnocommit"
mkdir -p "$NC"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$NC/Makefile"
printf '[package]\n' > "$NC/Cargo.toml"
gitq -C "$NC" init --quiet
gitq -C "$NC" remote add upstream "https://github.com/someone/nocommit.git"
register factnocommit "$NC" "build=make" "test=make test"
install_ut
facts "$NC"
check "a repository with no commits: exit 0 and five facts" \
    bash -c '[ "$1" -eq 0 ] && [ "$(cut -f1 <<< "$2" | paste -sd" " -)" = "github issues prs windows multi_component" ]' _ "$AUDIT_RC" "$AUDIT_OUT"
check "its one remote, named upstream, not origin: github yes, naming it (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "yes/remote 'upstream' is github.com/someone/nocommit" ]
check "nothing tracked yet, so the untracked Cargo.toml does not count: multi_component no (got: $(fev multi_component))" \
    [ "$(fval multi_component)" = "no" ]

OUTER="$SANDBOX/projects/outer"
NEST="$OUTER/inner"
mkdir -p "$NEST/a" "$NEST/b"
printf 'all:\n\t@true\ntest:\n\t@true\n' > "$NEST/Makefile"
printf '<package/>\n' > "$NEST/a/package.xml"
printf '<package/>\n' > "$NEST/b/package.xml"
gitq -C "$OUTER" init --quiet
commit_all "$OUTER"
gitq -C "$OUTER" remote add origin "git@github.com:someone/outer.git"
# Registered by hand only: the user-tier installer refuses a root inside
# another repository (skip-enclosed), so the line goes again below.
register factnested "$NEST" "build=make" "test=make test"
facts "$NEST"
check "a root nested inside a larger repository: github no, not the enclosing repository's remote (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "no/the root is not the top of a git repository, so it has no remote of its own" ]
check "and gh not called" [ ! -s "$GH_LOG" ]
check "its manifests read from disk: multi_component yes (got: $(fev multi_component))" \
    [ "$(fval multi_component)/$(fev multi_component)" = "yes/component manifests in 2 directories: a, b" ]
sed -i '/^factnested /d' "$WS/.agent/projects.local"
rm -f "$WS/.agent/projects.d/factnested"

echo "TEST: --facts at a parent root reads the chosen instance's repository"
facts "$PAR"
check "several instances, no default: the repository facts are unknown and say to pass --instance (got: $(fev github))" \
    bash -c '[ "$1" = unknown ] && grep -qF "pass --instance <name>" <<< "$2"' _ "$(fval github)" "$(fev github)"
check "windows is still read (got: $(fval windows))" [ "$(fval windows)" = "no" ]
facts "$PAR" --instance fam_a
check "--instance fam_a: its remote, not the parent's (got: $(fev github))" \
    [ "$(fval github)/$(fev github)" = "no/remote 'origin' is example.invalid/someone/fam-a, not github.com by name" ]
check "its one Makefile: multi_component no" [ "$(fval multi_component)" = "no" ]
facts "$SANDBOX"
check "a directory under no registered root: exit 2" [ "$AUDIT_RC" -eq 2 ]
unset STUB_GH_VIEW

echo "TEST: read-only: nothing in the project, the workspace or HOME changes"
snap() { # <dir>: every path with its content hash, .git included
    (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha1sum)
}
before_hr="$(snap "$HR")"; before_ws="$(snap "$WS/.agent")"; before_home="$(snap "$HOMEDIR")"
audit "$HR"
audit "$HR" --format text
audit "$HR" --facts
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
check "reading another project's is allowed" [ "$PS_RC" -eq 0 ]
check "and gives its value (got: $PS_OUT)" [ "$PS_OUT" = "make" ]
ps "$OUT_REPO" set handreg instructions=none
check "from an unregistered repository: refused" [ "$PS_RC" -ne 0 ]
check "by the root guard" grep -qF "refusing to run" <<< "$PS_OUT"
check "the file is unchanged" [ "$(cat "$WS/.agent/projects.d/handreg")" = "instructions=tracked" ]
ps "$WS" set clean instructions=none
check "from the workspace checkout, any project: exit 0" [ "$PS_RC" -eq 0 ]

echo ""
echo "test_project_integration_audit: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
