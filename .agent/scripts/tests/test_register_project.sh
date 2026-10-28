#!/usr/bin/env bash
# Tests for .agent/scripts/register_project.sh and registration_verify.sh
# (issue #332, PR 2): registering a project in one call, adoption of a
# hand-registered one, idempotence, --dry-run, the static gate (a missing
# or shared-fallback command refused), rollback of a failed registration
# (validate, build, test, the installer, an interrupt), the ros2_colcon
# setup that keeps the directory it created, --remove, --detect, and the
# refusals (a linked worktree, a type without registration.conf, a
# rewrite of a registered line).
#
# Every fixture is synthetic: a sandbox workspace (a git repository with
# copies of the real scripts, project types and user-tier files), sandbox
# projects built here, HOME redirected to the sandbox, and a stub `claude`
# that records its argv and edits settings.local.json the way the real CLI
# does. No real checkout, registry, ~/.claude or network is touched.
#
# Run: bash .agent/scripts/tests/test_register_project.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check() { # <label> <condition as a command...>
    local label="$1"
    shift
    if "$@"; then pass "$label"; else fail "$label"; fi
}
has() { [[ "$1" == *"$2"* ]]; }

command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required" >&2; exit 1; }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

gitq() { git -c user.name=t -c user.email=t@example.invalid -c init.defaultBranch=main "$@"; }

# ------------------------------------------------------------ fixtures ---

# The claude stub: records "<cwd>|<argv>" and edits the cwd's
# .claude/settings.local.json as `claude plugin ... --scope local` would,
# and the machine-level record as `marketplace add` does.
STUB_BIN="$SANDBOX/bin"
STUB="$STUB_BIN/claude"
STUB_LOG="$SANDBOX/claude-stub.log"
mkdir -p "$STUB_BIN"
cat > "$STUB" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s|%s\n' "$PWD" "$*" >> "$STUB_LOG"
[[ -n "${STUB_FAIL:-}" ]] && exit 1
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
# vcs stub for ros2_colcon setup: imports nothing.
cat > "$STUB_BIN/vcs" <<'EOF'
#!/usr/bin/env bash
cat > /dev/null
exit 0
EOF
chmod +x "$STUB_BIN/vcs"

HOMEDIR="$SANDBOX/home"
mkdir -p "$HOMEDIR"
# The build and test commands of the fixture projects append here.
REG_LOG="$SANDBOX/reg.log"
: > "$REG_LOG"

# A sandbox workspace: a git repository (its own main checkout) holding
# copies of the real scripts, project types and user-tier files.
make_ws() {
    local ws
    ws="$(mktemp -d -p "$SANDBOX")/ws"
    mkdir -p "$ws/.agent"
    cp -r "$REAL_ROOT/.agent/scripts" "$ws/.agent/scripts"
    rm -rf "$ws/.agent/scripts/tests"
    cp -r "$REAL_ROOT/.agent/project_types" "$ws/.agent/project_types"
    cp "$REAL_ROOT/.agent/user_tier_scripts.txt" "$ws/.agent/"
    cp -r "$REAL_ROOT/.claude" "$ws/.claude"
    cp -r "$REAL_ROOT/.claude-plugin" "$ws/.claude-plugin"
    rm -f "$ws/.claude/settings.local.json"
    printf '.agent/projects.local\n.agent/projects.d/\n.agent/project_config.sh\n.agent/scratchpad/\n.claude/settings.local.json\n' > "$ws/.gitignore"
    gitq -C "$ws" init --quiet
    gitq -C "$ws" add -A
    gitq -C "$ws" commit --quiet -m sandbox
    echo "$ws"
}

# A single_project fixture: a git repository with a Makefile whose build
# and test targets append to $REG_LOG. make_proj <name> [test-target? 1|0]
# [fail-build? 0|1] [fail-test? 0|1] → its path.
make_proj() {
    local name="$1" with_test="${2:-1}" fail_build="${3:-0}" fail_test="${4:-0}" dir
    dir="$(mktemp -d -p "$SANDBOX")/$name"
    mkdir -p "$dir"
    {
        printf 'all:\n\t@echo BUILD_RAN:%s >> "$(REG_LOG)"\n' "$name"
        [ "$fail_build" -eq 1 ] && printf '\t@exit 3\n'
        if [ "$with_test" -eq 1 ]; then
            printf 'test:\n\t@echo TEST_RAN:%s >> "$(REG_LOG)"\n' "$name"
            [ "$fail_test" -eq 1 ] && printf '\t@exit 4\n'
        fi
    } > "$dir/Makefile"
    gitq -C "$dir" init --quiet
    gitq -C "$dir" add -A
    gitq -C "$dir" commit --quiet -m init
    gitq -C "$dir" remote add origin "git@example.invalid:someone/$name.git"
    echo "$dir"
}

# The hand-registered fixture, shaped like the project the plan names
# (2026-09-23): a CMake layout with a build script, no remote, and only a
# one-line registry entry (no settings file, no legacy .sh).
make_cmake_proj() {
    local name="$1" dir
    dir="$(mktemp -d -p "$SANDBOX")/$name"
    mkdir -p "$dir/scripts" "$dir/src"
    printf 'cmake_minimum_required(VERSION 3.16)\nproject(%s)\n' "$name" > "$dir/CMakeLists.txt"
    printf '#!/usr/bin/env bash\necho BUILD_SCRIPT_RAN:%s >> "$REG_LOG"\n' "$name" > "$dir/scripts/build.sh"
    chmod +x "$dir/scripts/build.sh"
    gitq -C "$dir" init --quiet
    gitq -C "$dir" add -A
    gitq -C "$dir" commit --quiet -m init
    echo "$dir"
}

# Run register_project.sh (or another sandbox script) with the sandbox HOME
# and the claude stub, from a neutral directory.
reg() { # <ws> <args...>
    local ws="$1"
    shift
    (
        unset CLAUDE_CONFIG_DIR
        cd "$SANDBOX" && HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" REG_LOG="$REG_LOG" \
            AGENT_WORKSPACE_CLAUDE_BIN="$STUB" "$ws/.agent/scripts/register_project.sh" "$@" 2>&1
    )
}
verify() { # <ws> <args...>
    local ws="$1"
    shift
    (
        unset CLAUDE_CONFIG_DIR
        cd "$SANDBOX" && HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" REG_LOG="$REG_LOG" \
            AGENT_WORKSPACE_CLAUDE_BIN="$STUB" "$ws/.agent/scripts/registration_verify.sh" "$@" 2>&1
    )
}
detect() { # <ws> <dir>: --detect's proposals (stdout only)
    (cd "$SANDBOX" && "$1/.agent/scripts/register_project.sh" --detect "$2" 2>/dev/null)
}
install_ut() { # <ws>: install the user tier from this sandbox workspace
    (
        unset CLAUDE_CONFIG_DIR
        cd "$SANDBOX" && HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" \
            AGENT_WORKSPACE_CLAUDE_BIN="$STUB" "$1/.agent/scripts/user_tier_install.sh" "${@:2}" 2>&1
    )
}
uninstall_ut() { install_ut "$1" --uninstall >/dev/null; rm -rf "${HOMEDIR:?}/.claude"; }

line_of() { grep -E "^$2[[:space:]]" "$1/.agent/projects.local" 2>/dev/null; }
pfile() { echo "$1/.agent/projects.d/$2"; }
status_of() { sed -n 's/^STATUS=//p' <<< "$1" | tail -1; }
SLJ=.claude/settings.local.json
enabled_in() { jq -e '.enabledPlugins["agent-workspace@agent-workspace"] == true' "$1/$SLJ" >/dev/null 2>&1; }

# ---------------------------------------------------------------- detect ---
echo "TEST: --detect proposes only a single correct command"
WS="$(make_ws)"
D="$SANDBOX/detect"
mkdir -p "$D/mk" "$D/cargo" "$D/go" "$D/npm" "$D/py" "$D/cmake" "$D/both" "$D/npmdefault"
printf 'all:\n\techo\ntest:\n\techo\n' > "$D/mk/Makefile"
touch "$D/cargo/Cargo.toml" "$D/go/go.mod" "$D/py/pytest.ini" "$D/both/Cargo.toml"
printf 'all:\n\techo\n' > "$D/both/Makefile"
printf '{"scripts": {"build": "tsc", "test": "jest"}}\n' > "$D/npm/package.json"
touch "$D/npm/pnpm-lock.yaml"
printf '{"scripts": {"test": "echo \\"Error: no test specified\\" && exit 1"}}\n' > "$D/npmdefault/package.json"
touch "$D/cmake/CMakeLists.txt"
out="$(detect "$WS" "$D/mk")"
check "Makefile: build=make, test=make test" [ "$out" = $'build=make\ntest=make test' ]
out="$(detect "$WS" "$D/cargo")"
check "Cargo.toml: cargo build, cargo test" [ "$out" = $'build=cargo build\ntest=cargo test' ]
out="$(detect "$WS" "$D/go")"
check "go.mod: go build ./..., go test ./..." [ "$out" = $'build=go build ./...\ntest=go test ./...' ]
out="$(detect "$WS" "$D/npm")"
check "package.json scripts with a pnpm lock: pnpm run build, pnpm test" [ "$out" = $'build=pnpm run build\ntest=pnpm test' ]
out="$(detect "$WS" "$D/npmdefault")"
check "npm init's placeholder test script is not proposed" [ -z "$out" ]
out="$(detect "$WS" "$D/py")"
check "a pytest config: test=pytest only" [ "$out" = "test=pytest" ]
out="$(reg "$WS" --detect "$D/cmake")"
check "CMake alone: nothing proposed, and the note says why" bash -c '! grep -q "^build=" <<< "$1" && [[ "$1" == *"configure then build, which is not one command"* ]]' _ "$out"
out="$(reg "$WS" --detect "$D/both")"
check "two build systems that disagree: no build proposed, the conflict named" \
    bash -c '! grep -q "^build=" <<< "$1" && [[ "$1" == *"several build systems propose different build commands"* && "$1" == *"test=cargo test"* ]]' _ "$out"
out="$(reg "$WS" --detect "$D/nowhere")"; rc=$?
check "--detect on a missing directory exits 1" [ "$rc" -eq 1 ]

# ------------------------------------------------- register, one call ---
echo "TEST: one call registers a single_project: registry line and settings file, no hand edits"
WS="$(make_ws)"
P="$(make_proj alpha)"
: > "$REG_LOG"; : > "$STUB_LOG"
out="$(reg "$WS" "$P")"; rc=$?
check "exit 0" [ "$rc" -eq 0 ]
check "STATUS=registered" [ "$(status_of "$out")" = registered ]
check "NAME and ROOT lines" bash -c '[[ "$1" == *$'"'"'\nNAME=alpha\nROOT='"'"'"$2"* ]]' _ "$out" "$P"
check "the registry line holds the absolute path and the type" \
    bash -c '[[ "$(line_of() { grep -E "^alpha[[:space:]]" "$1/.agent/projects.local"; }; line_of "$2")" == "alpha  single_project  $3" ]]' _ "$WS" "$WS" "$P"
check "the settings file holds the detected commands" \
    [ "$(cat "$(pfile "$WS" alpha)")" = $'build=make\ntest=make test' ]
check "build and test ran, in that order" [ "$(cat "$REG_LOG")" = $'BUILD_RAN:alpha\nTEST_RAN:alpha' ]
check "no user tier: a warning and the install step in NEXT, no CLI call" \
    bash -c '[[ "$1" == *"the user tier is not installed"* && "$1" == *"NEXT=install the user tier"* ]] && [ ! -s "$2" ]' _ "$out" "$STUB_LOG"
check "nothing written into the project" [ -z "$(git -C "$P" status --porcelain)" ]

echo "TEST: a second identical run changes no byte and says so"
cp "$WS/.agent/projects.local" "$SANDBOX/reg.before"
cp "$(pfile "$WS" alpha)" "$SANDBOX/pf.before"
out="$(reg "$WS" "$P")"; rc=$?
check "exit 0, STATUS=registered" [ "$rc" -eq 0 -a "$(status_of "$out")" = registered ]
check "registry unchanged" cmp -s "$WS/.agent/projects.local" "$SANDBOX/reg.before"
check "settings file unchanged" cmp -s "$(pfile "$WS" alpha)" "$SANDBOX/pf.before"
check "says nothing changed" has "$out" "nothing changed"
out="$(reg "$WS" alpha)"; rc=$?
check "the same by name: exit 0, nothing changed" bash -c '[ "$1" -eq 0 ] && [[ "$2" == *"nothing changed"* ]]' _ "$rc" "$out"
check "registry still unchanged" cmp -s "$WS/.agent/projects.local" "$SANDBOX/reg.before"

echo "TEST: registration_verify.sh passes a registered project and is read-only"
: > "$REG_LOG"
out="$(verify "$WS" alpha)"; rc=$?
check "exit 0, VERIFY=pass" bash -c '[ "$1" -eq 0 ] && [[ "$2" == *"VERIFY=pass"* ]]' _ "$rc" "$out"
check "names where each command comes from" has "$out" "OK: test: make test (settings file)"
check "the project's build and test did not run" [ ! -s "$REG_LOG" ]
out="$(verify "$WS" nosuch)"; rc=$?
check "an unregistered name exits 2" [ "$rc" -eq 2 ]

echo "TEST: --skip-run registers without running build and test, and says so"
PSK="$(make_proj upsilon)"
: > "$REG_LOG"
out="$(reg "$WS" "$PSK" --skip-run)"; rc=$?
check "exit 0, STATUS=registered, build and test not run" [ "$rc" -eq 0 -a "$(status_of "$out")" = "registered, build and test not run" ]
check "neither verb ran" [ ! -s "$REG_LOG" ]
reg "$WS" --remove upsilon >/dev/null

# ------------------------------------------------------------ dry run ---
echo "TEST: --dry-run writes nothing, for register and for remove"
P2="$(make_proj beta)"
cp "$WS/.agent/projects.local" "$SANDBOX/reg.before"
: > "$REG_LOG"; : > "$STUB_LOG"
out="$(reg "$WS" "$P2" --dry-run)"; rc=$?
check "exit 0, STATUS=dry-run" [ "$rc" -eq 0 -a "$(status_of "$out")" = dry-run ]
check "lists the line, the settings, the gate and the verbs" \
    bash -c '[[ "$1" == *"would add the registry line: beta  single_project"* && "$1" == *"build=make    (detected"* && "$1" == *"would run: registration_verify.sh beta"* && "$1" == *"would run: adapter --project beta test"* ]]' _ "$out"
check "registry unchanged" cmp -s "$WS/.agent/projects.local" "$SANDBOX/reg.before"
check "no settings file" [ ! -e "$(pfile "$WS" beta)" ]
check "nothing ran: no build, no CLI, no ~/.claude" bash -c '[ ! -s "$1" ] && [ ! -s "$2" ] && [ ! -e "$3/.claude" ]' _ "$REG_LOG" "$STUB_LOG" "$HOMEDIR"
out="$(reg "$WS" --remove alpha --dry-run)"; rc=$?
check "remove --dry-run: exit 0, STATUS=dry-run, shows the settings" \
    bash -c '[ "$1" -eq 0 ] && [[ "$2" == *"STATUS=dry-run"* && "$2" == *"would remove the settings file"* && "$2" == *"    test=make test"* ]]' _ "$rc" "$out"
check "remove --dry-run: registry and settings file unchanged" \
    bash -c 'cmp -s "$1" "$2" && [ -f "$3" ] && [ ! -s "$4" ]' _ "$WS/.agent/projects.local" "$SANDBOX/reg.before" "$(pfile "$WS" alpha)" "$STUB_LOG"

# ------------------------------------------------- the gate refuses ---
echo "TEST: no test command is refused; test=none is accepted"
P3="$(make_proj gamma 0)"
out="$(reg "$WS" "$P3")"; rc=$?
check "exit 1, STATUS=refused" [ "$rc" -eq 1 -a "$(status_of "$out")" = refused ]
check "the gate names the missing test command" has "$out" "FAIL: no test command"
check "no registry line, no settings file" bash -c '! grep -q "^gamma " "$1" && [ ! -e "$2" ]' _ "$WS/.agent/projects.local" "$(pfile "$WS" gamma)"
out="$(reg "$WS" "$P3" --set test=none)"; rc=$?
check "with --set test=none: registered" [ "$rc" -eq 0 -a "$(status_of "$out")" = registered ]
check "test=none stored beside the detected build" [ "$(cat "$(pfile "$WS" gamma)")" = $'test=none\nbuild=make' ]

echo "TEST: the CMake layout is refused until build= names a script"
PC="$(make_cmake_proj delta)"
out="$(reg "$WS" "$PC")"; rc=$?
check "refused, naming the missing build command and why CMake has none" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"FAIL: no build command"* && "$2" == *"configure then build"* ]]' _ "$rc" "$out"
check "nothing left" bash -c '! grep -q "^delta " "$1" && [ ! -e "$2" ]' _ "$WS/.agent/projects.local" "$(pfile "$WS" delta)"
: > "$REG_LOG"
out="$(reg "$WS" "$PC" --set build=./scripts/build.sh --set test=none)"; rc=$?
check "with build=./scripts/build.sh and test=none: registered, the script ran" \
    bash -c '[ "$1" -eq 0 ] && [[ "$2" == *"STATUS=registered"* ]] && grep -q BUILD_SCRIPT_RAN:delta "$3"' _ "$rc" "$out" "$REG_LOG"
check "no remote: a warning, not a failure" has "$out" "has no git remote: supported"

echo "TEST: a command falling through to the shared project_config.sh is refused"
printf 'BUILD_CMD="make"\nTEST_CMD="make test"\n' > "$WS/.agent/project_config.sh"
PS="$(make_cmake_proj epsilon)"
out="$(reg "$WS" "$PS")"; rc=$?
check "refused, naming the shared fallback" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"build falls through to the shared .agent/project_config.sh"* ]]' _ "$rc" "$out"
rm -f "$WS/.agent/project_config.sh"

echo "TEST: an invalid --set value is refused before anything is written"
P4="$(make_proj zeta)"
out="$(reg "$WS" "$P4" --set 'build=make && make install')"; rc=$?
check "refused naming the shell operator" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"point the key at a script"* ]]' _ "$rc" "$out"
check "no line, no file" bash -c '! grep -q "^zeta " "$1" && [ ! -e "$2" ]' _ "$WS/.agent/projects.local" "$(pfile "$WS" zeta)"
out="$(reg "$WS" "$P4" --set location=outside --set tracking=untracked)"; rc=$?
check "a records combination other than the default is refused (not yet honoured)" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"not stored until the records lookup lands"* ]]' _ "$rc" "$out"
out="$(reg "$WS" "$P4" --set buld=make)"; rc=$?
check "an unknown key is a usage error" [ "$rc" -eq 2 ]

echo "TEST: a '#' in the path or a field value is refused, never registered as something shorter"
# The registry strips from '#' to the end of a line, so phi#2 would read
# back as phi: a different directory, and a valid project too.
PHASH="$(make_proj phi)"
cp -r "$PHASH" "$PHASH#2"
cp "$WS/.agent/projects.local" "$SANDBOX/reg.before"
ls -A "$WS/.agent/projects.d" > "$SANDBOX/pd.before"
: > "$REG_LOG"
out="$(reg "$WS" "$PHASH#2" --name phi2)"; rc=$?
check "a path with '#': exit 1, STATUS=refused, naming the '#'" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"STATUS=refused"* && "$2" == *"cannot hold a path with a blank, '"'"'='"'"' or '"'"'#'"'"'"* ]]' _ "$rc" "$out"
check "a path with '#': nothing written, nothing run" \
    bash -c 'cmp -s "$1" "$2" && [ "$(ls -A "$3")" = "$(cat "$4")" ] && [ ! -s "$5" ]' _ "$WS/.agent/projects.local" "$SANDBOX/reg.before" "$WS/.agent/projects.d" "$SANDBOX/pd.before" "$REG_LOG"
for fv in "--role sim#x" "--distro foxy#2" "--parent fam#x" "--role 'a b'" "--distro a=b"; do
    eval "set -- $fv"
    out="$(reg "$WS" "$PHASH" "$@")"; rc=$?
    check "$fv: exit 1, refused naming the value" \
        bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"STATUS=refused"* && "$2" == *"cannot hold a value with a blank, '"'"'='"'"' or '"'"'#'"'"'"* ]]' _ "$rc" "$out"
    check "$fv: nothing written" \
        bash -c 'cmp -s "$1" "$2" && [ "$(ls -A "$3")" = "$(cat "$4")" ]' _ "$WS/.agent/projects.local" "$SANDBOX/reg.before" "$WS/.agent/projects.d" "$SANDBOX/pd.before"
done
out="$(reg "$WS" "$PHASH" --worktrees "$PHASH/wt#x")"; rc=$?
check "--worktrees with '#': refused, nothing written" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"cannot hold a value with a blank"* ]] && cmp -s "$3" "$4"' _ "$rc" "$out" "$WS/.agent/projects.local" "$SANDBOX/reg.before"
set --

echo "TEST: a settings file that existed before: a failed backup refuses, and a rollback restores it by rename"
# Fault injection: wrappers that fail mktemp, cp or mv on one argument
# pattern and run the real tool otherwise.
FAULT_BIN="$SANDBOX/faultbin"
mkdir -p "$FAULT_BIN"
for tool in mktemp cp mv; do
    real="$(command -v "$tool")"
    cat > "$FAULT_BIN/$tool" <<EOF
#!/usr/bin/env bash
if [ "\${FAULT_TOOL:-}" = "$tool" ]; then
    for a in "\$@"; do [[ "\$a" == *"\$FAULT_ON"* ]] && { echo "$tool: injected failure" >&2; exit 1; }; done
fi
exec "$real" "\$@"
EOF
    chmod +x "$FAULT_BIN/$tool"
done
faulty() { # <tool> <pattern> <ws> <args...>: reg with one injected failure
    (
        export FAULT_TOOL="$1" FAULT_ON="$2"
        PATH="$FAULT_BIN:$PATH"
        shift 2
        reg "$@"
    )
}
leftovers() { # the backup and restore files left in projects.d, by name
    find "$WS/.agent/projects.d" -maxdepth 1 \( -name '.settings-backup.*' -o -name '.settings-restore.*' \) | sed 's|.*/||'
}
PSI="$(make_proj psi 1 1 0)"   # its build fails
printf 'build=make\ntest=make test\n' > "$(pfile "$WS" psi)"
chmod 640 "$(pfile "$WS" psi)"
cp -p "$(pfile "$WS" psi)" "$SANDBOX/psi.before"
cp "$WS/.agent/projects.local" "$SANDBOX/reg.before"
for t in mktemp cp; do
    : > "$REG_LOG"
    out="$(faulty "$t" .settings-backup. "$WS" "$PSI" --set test=none)"; rc=$?
    check "$t of the backup fails: exit 1, STATUS=refused, naming the backup" \
        bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"STATUS=refused"* && "$2" == *"could not back up the settings file"* ]]' _ "$rc" "$out"
    check "$t of the backup fails: the settings file and the registry are unchanged, nothing ran" \
        bash -c 'cmp -s "$1" "$2" && cmp -s "$3" "$4" && [ ! -s "$5" ]' _ "$(pfile "$WS" psi)" "$SANDBOX/psi.before" "$WS/.agent/projects.local" "$SANDBOX/reg.before" "$REG_LOG"
    check "$t of the backup fails: no backup file left" [ -z "$(leftovers)" ]
done
out="$(reg "$WS" "$PSI" --set test=none)"; rc=$?
check "the build fails after the file was changed: refused, and the restore is reported" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"restored the settings file"* ]]' _ "$rc" "$out"
check "the settings file is back byte for byte, its mode kept" \
    bash -c 'cmp -s "$1" "$2" && [ "$(stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1")" = 640 ]' _ "$(pfile "$WS" psi)" "$SANDBOX/psi.before"
check "no line, no backup or restore file left" bash -c '! grep -q "^psi " "$1" && [ -z "$2" ]' _ "$WS/.agent/projects.local" "$(leftovers)"
out="$(faulty mv .settings-restore. "$WS" "$PSI" --set test=none)"; rc=$?
BK="$(leftovers | grep '^\.settings-backup\.' | head -1)"
check "the restore fails: a warning names the kept backup" \
    bash -c '[ "$1" -eq 1 ] && [ -n "$3" ] && [[ "$2" == *"could not restore the settings file"* && "$2" == *"kept in $4/$3"* ]]' _ "$rc" "$out" "$BK" "$WS/.agent/projects.d"
check "the restore fails: the backup holds the content from before the run, no restore temp left" \
    bash -c 'cmp -s "$1" "$2" && [ -z "$(find "$3" -maxdepth 1 -name ".settings-restore.*")" ]' _ "$WS/.agent/projects.d/$BK" "$SANDBOX/psi.before" "$WS/.agent/projects.d"
rm -f "$WS/.agent/projects.d/$BK" "$(pfile "$WS" psi)"

# ---------------------------------------------- failures roll back ---
echo "TEST: a failing validate, build or test leaves no line, no file and no plugin enable"
install_ut "$WS" >/dev/null || fail "installing the sandbox user tier"
PV="$SANDBOX/notgit/eta"
mkdir -p "$PV"
printf 'all:\n\techo\ntest:\n\techo\n' > "$PV/Makefile"
for case in "validate:$PV" "build:$(make_proj theta 1 1 0)" "test:$(make_proj iota 1 0 1)"; do
    what="${case%%:*}"; dir="${case#*:}"; nm="$(basename "$dir")"
    : > "$STUB_LOG"
    out="$(reg "$WS" "$dir")"; rc=$?
    check "$what fails: exit 1, STATUS=refused" [ "$rc" -eq 1 -a "$(status_of "$out")" = refused ]
    check "$what fails: no registry line, no settings file" \
        bash -c '! grep -q "^$3 " "$1" && [ ! -e "$2" ]' _ "$WS/.agent/projects.local" "$(pfile "$WS" "$nm")" "$nm"
    check "$what fails: the installer never ran (no CLI call, no enable)" \
        bash -c '[ ! -s "$1" ] && [ ! -e "$2/.claude/settings.local.json" ]' _ "$STUB_LOG" "$dir"
done

echo "TEST: an installer failure after a passing build disables the root and rolls back"
# Another registered root whose settings.local.json is not JSON makes the
# installer fail after it has enabled the new root.
PBAD="$(make_proj broken)"
printf 'broken  single_project  %s\n' "$PBAD" >> "$WS/.agent/projects.local"
printf 'build=make\ntest=make test\n' > "$(pfile "$WS" broken)"
mkdir -p "$PBAD/.claude" && printf '{not json' > "$PBAD/$SLJ"
PK="$(make_proj kappa)"
: > "$STUB_LOG"
out="$(reg "$WS" "$PK")"; rc=$?
check "exit 1, STATUS=refused" [ "$rc" -eq 1 -a "$(status_of "$out")" = refused ]
check "the root was enabled, then disabled by --disable-root" \
    bash -c 'grep -qxF "$1|plugin install agent-workspace@agent-workspace --scope local" "$2" && grep -qxF "$1|plugin uninstall agent-workspace@agent-workspace --scope local" "$2"' _ "$PK" "$STUB_LOG"
check "no enable left in the root" bash -c '! jq -e ".enabledPlugins[\"agent-workspace@agent-workspace\"] == true" "$1" >/dev/null 2>&1' _ "$PK/$SLJ"
check "no registry line, no settings file; the other root's line kept" \
    bash -c '! grep -q "^kappa " "$1" && [ ! -e "$2" ] && grep -q "^broken " "$1"' _ "$WS/.agent/projects.local" "$(pfile "$WS" kappa)"
rm -f "$PBAD/$SLJ"
reg "$WS" --remove broken >/dev/null

echo "TEST: with the user tier installed, registration enables the plugin and verifies it"
PL="$(make_proj lambda)"
: > "$STUB_LOG"
out="$(reg "$WS" "$PL")"; rc=$?
check "exit 0, STATUS=registered" [ "$rc" -eq 0 -a "$(status_of "$out")" = registered ]
check "the plugin is enabled at the root" enabled_in "$PL"
check "the user-tier check ran and passed" bash -c '[[ "$1" == *"registration_verify.sh lambda --user-tier"* && "$1" == *"a session started at $2 has root '"'"'lambda'"'"'"* ]]' _ "$out" "$PL"
check "NEXT names the onboarding step" has "$out" "NEXT=start a Claude Code session at $PL and run /agent-workspace:onboard-project"

echo "TEST: a user tier installed for another checkout is not touched"
cp "$HOMEDIR/.claude/agent-workspace-root" "$SANDBOX/root-file.saved"
printf '%s' "$SANDBOX/another-checkout" > "$HOMEDIR/.claude/agent-workspace-root"
PO="$(make_proj omega)"
: > "$STUB_LOG"
out="$(reg "$WS" "$PO")"; rc=$?
check "registered, with a warning naming the other checkout, and no CLI call" \
    bash -c '[ "$1" -eq 0 ] && [[ "$2" == *"STATUS=registered"* && "$2" == *"installed for another checkout ($4)"* ]] && [ ! -s "$3" ]' _ "$rc" "$out" "$STUB_LOG" "$SANDBOX/another-checkout"
cp "$SANDBOX/root-file.saved" "$HOMEDIR/.claude/agent-workspace-root"
reg "$WS" --remove omega >/dev/null

# ------------------------------------------------------------ adoption ---
echo "TEST: adopting a hand-registered project (a one-line entry, no settings file)"
PH="$(make_cmake_proj mu)"
printf 'mu single_project %s\n' "$PH" >> "$WS/.agent/projects.local"
cp "$WS/.agent/projects.local" "$SANDBOX/reg.before"
out="$(reg "$WS" mu)"; rc=$?
check "no build command: NOT READY, exit 1" [ "$rc" -eq 1 -a "$(status_of "$out")" = "NOT READY" ]
check "kept, never rolled back: the registry is byte for byte the same" cmp -s "$WS/.agent/projects.local" "$SANDBOX/reg.before"
out="$(reg "$WS" "$PH" --set build=./scripts/build.sh --set test=none)"; rc=$?
check "by path with the commands: registered" [ "$rc" -eq 0 -a "$(status_of "$out")" = registered ]
check "its line is kept as it was" cmp -s "$WS/.agent/projects.local" "$SANDBOX/reg.before"
check "it gets a settings file" [ "$(cat "$(pfile "$WS" mu)")" = $'build=./scripts/build.sh\ntest=none' ]

echo "TEST: adoption copies a legacy .sh and names the environment it no longer passes"
PN="$(make_proj nu)"
printf 'nu single_project %s\n' "$PN" >> "$WS/.agent/projects.local"
cat > "$WS/.agent/projects.d/nu.sh" <<'EOF'
export PATH="/opt/sdk/bin:$PATH"
export SDK_ROOT=/opt/sdk
BUILD_CMD="make"
TEST_CMD="make test"
EOF
out="$(reg "$WS" nu)"; rc=$?
check "registered" [ "$rc" -eq 0 -a "$(status_of "$out")" = registered ]
check "the commands are copied into the settings file" [ "$(cat "$(pfile "$WS" nu)")" = $'build=make\ntest=make test' ]
check "the warning names PATH and SDK_ROOT" has "$out" "sets or exports PATH, SDK_ROOT, which a command in the settings file no longer gets"
check "the warning does not name the variables the adapters read" bash -c '[[ "$1" != *"BUILD_CMD,"* && "$1" != *", BUILD_CMD"* ]]' _ "$out"
check "the legacy file is left alone" [ -f "$WS/.agent/projects.d/nu.sh" ]

echo "TEST: adoption refuses to rewrite a registered line"
out="$(reg "$WS" nu ros2_colcon)"; rc=$?
check "a different type is refused" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"no silent rewrite"* ]]' _ "$rc" "$out"
out="$(reg "$WS" "$(make_proj other)" --name nu)"; rc=$?
check "a different path for a registered name is refused" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"already registered, at"* ]]' _ "$rc" "$out"
out="$(reg "$WS" "$PN" --name xi)"; rc=$?
check "a registered path under another name is refused" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"already registered as '"'"'nu'"'"'"* ]]' _ "$rc" "$out"
out="$(reg "$WS" nu --role sim)"; rc=$?
check "a field the line lacks (role) is refused" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"no silent rewrite"* ]]' _ "$rc" "$out"

# -------------------------------------------------- parent roots ---
echo "TEST: a parent root, an instance, then the parent's default_instance"
PP="$SANDBOX/fam"
mkdir -p "$PP"
out="$(reg "$WS" "$PP" project)"; rc=$?
check "the parent registers" [ "$rc" -eq 0 -a "$(status_of "$out")" = registered ]
out="$(reg "$WS" "$PP" project --set build=make)"; rc=$?
check "a parent takes no settings" [ "$rc" -eq 2 ]
PI="$(make_proj fam-one)"
out="$(reg "$WS" "$PI" --parent fam)"; rc=$?
check "an instance with --parent registers" [ "$rc" -eq 0 -a "$(status_of "$out")" = registered ]
out="$(reg "$WS" fam --default-instance fam-one)"; rc=$?
check "adding a missing default_instance to the parent is allowed" \
    bash -c '[ "$1" -eq 0 ] && grep -qE "^fam .*default_instance=fam-one" "$2"' _ "$rc" "$WS/.agent/projects.local"
cp "$WS/.agent/projects.local" "$SANDBOX/reg.before"
: > "$STUB_LOG"
out="$(reg "$WS" --remove fam-one)"; rc=$?
check "removing the parent's default_instance is refused before anything changes" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"would not parse"* ]] && cmp -s "$3" "$4" && [ ! -s "$5" ]' _ "$rc" "$out" "$WS/.agent/projects.local" "$SANDBOX/reg.before" "$STUB_LOG"
out="$(reg "$WS" --remove fam)"; rc=$?
check "removing a parent with instances is refused, listing them" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"parent root with instances"* && "$2" == *"fam-one"* ]]' _ "$rc" "$out"

# ------------------------------------------------- ros2_colcon setup ---
echo "TEST: ros2_colcon: setup's directory is kept, and named, when a later check fails"
if command -v curl >/dev/null 2>&1; then
    MR="$SANDBOX/remote/manifest_repo"
    mkdir -p "$MR/config/repos"
    printf 'l1\n' > "$MR/config/layers.txt"
    printf 'distro: fakefox\n' > "$MR/config/bootstrap.yaml"
    printf 'repositories:\n  pkg_a:\n    type: git\n    url: file:///nonexistent/pkg_a.git\n    version: fakefox\n' > "$MR/config/repos/l1.repos"
    gitq -C "$MR" init --quiet -b fakefox
    gitq -C "$MR" add -A
    gitq -C "$MR" commit --quiet -m init
    printf 'git_url: file://%s\nbranch: fakefox\n' "$MR" > "$SANDBOX/remote/bootstrap.yaml"
    RC_DIR="$SANDBOX/colcon/omicron"
    out="$(reg "$WS" "$RC_DIR" --set "bootstrap_url=file://$SANDBOX/remote/bootstrap.yaml")"; rc=$?
    check "the type is detected from the bootstrap_url, and setup ran" \
        bash -c '[[ "$1" == *"omicron  ros2_colcon"* && "$1" == *"== adapter --project omicron setup"* ]]' _ "$out"
    check "validate fails: exit 1, STATUS=refused" [ "$rc" -eq 1 -a "$(status_of "$out")" = refused ]
    check "no registry line, no settings file" \
        bash -c '! grep -q "^omicron " "$1" && [ ! -e "$2" ]' _ "$WS/.agent/projects.local" "$(pfile "$WS" omicron)"
    check "the directory setup created is kept and named on KEPT=" \
        bash -c '[ -d "$1/configs" ] && [[ "$2" == *$'"'"'\nKEPT='"'"'"$1"$'"'"'\n'"'"'* ]]' _ "$RC_DIR" "$out"
    mkdir -p "$SANDBOX/colcon/pi"
    out="$(reg "$WS" "$SANDBOX/colcon/pi" ros2_colcon --set "bootstrap_url=file://$SANDBOX/remote/bootstrap.yaml")"; rc=$?
    check "a directory that existed is never set up, and never kept or removed" \
        bash -c '[ "$1" -eq 1 ] && [[ "$2" != *"adapter --project pi setup"* && "$2" != *KEPT=* ]] && [ -d "$3" ]' _ "$rc" "$out" "$SANDBOX/colcon/pi"
else
    echo "  SKIP: curl is not available (the bootstrap fetch needs it)"
fi

# --------------------------------------------------- a missing type ---
echo "TEST: a type without registration.conf is refused"
mkdir -p "$WS/.agent/project_types/bare_type"
cp "$WS/.agent/project_types/single_project/adapter.sh" "$WS/.agent/project_types/bare_type/adapter.sh"
out="$(reg "$WS" "$(make_proj rho)" bare_type)"; rc=$?
check "refused, naming the missing file" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"registration.conf is missing or invalid"* ]]' _ "$rc" "$out"
rm -rf "$WS/.agent/project_types/bare_type"

# ------------------------------------------------------------ remove ---
echo "TEST: --remove refuses live worktrees, then removes the line and the file, not the project"
mkdir -p "$PL/worktrees/issue-lambda-7"
out="$(reg "$WS" --remove lambda)"; rc=$?
check "refused while a worktree is live, naming it" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"live worktrees"* && "$2" == *"issue-lambda-7"* ]] && grep -q "^lambda " "$3"' _ "$rc" "$out" "$WS/.agent/projects.local"
rmdir "$PL/worktrees/issue-lambda-7" "$PL/worktrees"
: > "$STUB_LOG"
out="$(reg "$WS" --remove lambda)"; rc=$?
check "exit 0, STATUS=removed" [ "$rc" -eq 0 -a "$(status_of "$out")" = removed ]
check "the plugin is disabled in the root first" \
    bash -c 'grep -qxF "$1|plugin uninstall agent-workspace@agent-workspace --scope local" "$2" && ! jq -e ".enabledPlugins[\"agent-workspace@agent-workspace\"] == true" "$1/$3" >/dev/null 2>&1' _ "$PL" "$STUB_LOG" "$SLJ"
check "the line and the settings file are gone; the content was printed" \
    bash -c '! grep -q "^lambda " "$1" && [ ! -e "$2" ] && [[ "$3" == *"    build=make"* ]]' _ "$WS/.agent/projects.local" "$(pfile "$WS" lambda)" "$out"
check "the project is left alone, and the output says so" \
    bash -c '[ -f "$1/Makefile" ] && [[ "$2" == *"left alone: the project at"* ]]' _ "$PL" "$out"
out="$(reg "$WS" --remove gamma --keep-settings)"; rc=$?
check "--keep-settings keeps the file" bash -c '[ "$1" -eq 0 ] && [ -f "$2" ] && ! grep -q "^gamma " "$3"' _ "$rc" "$(pfile "$WS" gamma)" "$WS/.agent/projects.local"
out="$(reg "$WS" --remove nosuch)"; rc=$?
check "removing an unregistered name exits 1" [ "$rc" -eq 1 ]

# ------------------------------------------------------------ interrupt ---
echo "TEST: an interrupt during the build rolls the registration back"
PT="$(make_proj tau)"
printf 'all:\n\t@echo BUILD_START:tau >> "$(REG_LOG)"\n\t@sleep 2\ntest:\n\t@echo\n' > "$PT/Makefile"
: > "$REG_LOG"
(
    unset CLAUDE_CONFIG_DIR
    cd "$SANDBOX" && HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" REG_LOG="$REG_LOG" \
        AGENT_WORKSPACE_CLAUDE_BIN="$STUB" exec "$WS/.agent/scripts/register_project.sh" "$PT" > "$SANDBOX/int.out" 2>&1
) &
IPID=$!
for _ in $(seq 1 100); do grep -q BUILD_START:tau "$REG_LOG" && break; sleep 0.1; done
kill -TERM "$IPID" 2>/dev/null
wait "$IPID"; rc=$?
out="$(cat "$SANDBOX/int.out")"
check "exit 143, STATUS=refused, interrupted" bash -c '[ "$1" -eq 143 ] && [[ "$2" == *"STATUS=refused"* && "$2" == *"interrupted"* ]]' _ "$rc" "$out"
check "no registry line, no settings file" \
    bash -c '! grep -q "^tau " "$1" && [ ! -e "$2" ]' _ "$WS/.agent/projects.local" "$(pfile "$WS" tau)"

# ------------------------------------------------------- registry lock ---
LOCKF="$WS/.agent/projects.d/.registry.lock"
snap() { # <ws>: the registry and every file in projects.d, with checksums
    cksum < "$1/.agent/projects.local"
    (cd "$1/.agent/projects.d" && find . -type f -exec cksum {} + | sort)
}
if command -v flock >/dev/null 2>&1; then
    echo "TEST: a run against a held registry lock refuses, and neither writes nor removes anything"
    PLK="$(make_proj chi)"
    snap "$WS" > "$SANDBOX/snap.before"
    exec 7>>"$LOCKF"
    flock -x 7
    : > "$REG_LOG"; : > "$STUB_LOG"
    out="$(PROJECT_FILE_LOCK_WAIT=1 reg "$WS" "$PLK" 7>&-)"; rc=$?
    check "register: exit 1, STATUS=refused, naming the lock" \
        bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"STATUS=refused"* && "$2" == *"holds the registry lock"* ]]' _ "$rc" "$out"
    out="$(PROJECT_FILE_LOCK_WAIT=1 reg "$WS" --remove nu 7>&-)"; rc=$?
    check "remove: exit 1, STATUS=refused, naming the lock" \
        bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"STATUS=refused"* && "$2" == *"holds the registry lock"* ]]' _ "$rc" "$out"
    exec 7>&-
    snap "$WS" > "$SANDBOX/snap.after"
    check "the registry and projects.d are byte for byte the same" cmp -s "$SANDBOX/snap.before" "$SANDBOX/snap.after"
    check "nothing ran: no build, no CLI call" bash -c '[ ! -s "$1" ] && [ ! -s "$2" ]' _ "$REG_LOG" "$STUB_LOG"

    echo "TEST: a run that waited for the lock checks under it, so a concurrent winner's settings file is kept"
    # The run blocks on the lock; meanwhile this test, as the winning run,
    # registers the same project. Checked before the lock, the waiting run
    # would still think the name free and its settings file its own, and
    # its rollback would delete the winner's file.
    PRC="$(make_proj kai)"
    exec 7>>"$LOCKF"
    flock -x 7
    (
        unset CLAUDE_CONFIG_DIR
        cd "$SANDBOX" && HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" STUB_LOG="$STUB_LOG" REG_LOG="$REG_LOG" \
            AGENT_WORKSPACE_CLAUDE_BIN="$STUB" PROJECT_FILE_LOCK_WAIT=30 \
            exec "$WS/.agent/scripts/register_project.sh" "$PRC" > "$SANDBOX/race.out" 2>&1
    ) 7>&- &
    RPID=$!
    for _ in $(seq 1 100); do pgrep -P "$RPID" -x flock >/dev/null && break; sleep 0.1; done
    printf 'kai  single_project  %s\n' "$PRC" >> "$WS/.agent/projects.local"
    printf 'build=make\ntest=make test\n' > "$(pfile "$WS" kai)"
    exec 7>&-
    wait "$RPID"; rc=$?
    out="$(cat "$SANDBOX/race.out")"
    check "the waiting run adopts the winner's registration: exit 0, nothing changed" \
        bash -c '[ "$1" -eq 0 ] && [[ "$2" == *"STATUS=registered"* && "$2" == *"nothing changed"* ]]' _ "$rc" "$out"
    check "the winner's settings file is kept, byte for byte" [ "$(cat "$(pfile "$WS" kai)")" = $'build=make\ntest=make test' ]
    check "the winner's line is there once" [ "$(grep -c '^kai ' "$WS/.agent/projects.local")" -eq 1 ]
    reg "$WS" --remove kai >/dev/null
else
    echo "  SKIP: flock is not available (the registry lock needs it)"
fi

# ------------------------------------------------------- linked worktree ---
echo "TEST: refused from a linked worktree of the workspace"
gitq -C "$WS" worktree add --quiet "$SANDBOX/ws-linked" 2>/dev/null
out="$(reg "$SANDBOX/ws-linked" "$(make_proj sigma)")"; rc=$?
check "exit 1, naming the main checkout's copy" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"refusing to run from a linked worktree"* && "$2" == *"$3/.agent/scripts/register_project.sh"* ]]' _ "$rc" "$out" "$(cd "$WS" && pwd -P)"
out="$(detect "$SANDBOX/ws-linked" "$D/mk")"; rc=$?
check "--detect still works there (read-only)" [ "$rc" -eq 0 -a "$out" = $'build=make\ntest=make test' ]
gitq -C "$WS" worktree remove --force "$SANDBOX/ws-linked" 2>/dev/null

uninstall_ut "$WS"

echo ""
echo "test_register_project: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
