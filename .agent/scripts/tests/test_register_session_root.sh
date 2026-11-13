#!/usr/bin/env bash
# Tests for .agent/scripts/register_session_root.sh (#466, ADR-0021): a
# session started in a folder that is not registered registers that
# folder, and only that folder, through register_project.sh --skip-run.
# Covered: the registration itself (registry line, settings file, nothing
# in the folder, no build or test run, ~/.claude untouched), the dry run,
# each refusal (already registered, with --set; inside a registered root;
# over a registered root; inside or over the workspace; not the top of
# its repository; a linked worktree; a name already registered; usage),
# a folder with no build command (refused until --set), a folder in no git
# repository (the named gap: refused and rolled back), a copy of the
# script in a linked worktree of the workspace (it registers in the main
# checkout), and that the script is not promoted to the user tier.
#
# Every fixture is synthetic: a sandbox workspace (a git repository with
# copies of the real scripts and project types), sandbox folders built
# here, and HOME redirected to the sandbox. No real checkout, registry or
# ~/.claude is touched.
#
# Run: bash .agent/scripts/tests/test_register_session_root.sh

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

SANDBOX="$(mktemp -d)"
SANDBOX="$(cd "$SANDBOX" && pwd -P)"
trap 'rm -rf "$SANDBOX"' EXIT

gitq() { git -c user.name=t -c user.email=t@example.invalid -c init.defaultBranch=main "$@"; }

HOMEDIR="$SANDBOX/home"
mkdir -p "$HOMEDIR"
# A claude stub that records any call: registration from a project
# session must never run the installer.
STUB_BIN="$SANDBOX/bin"
STUB_LOG="$SANDBOX/claude-stub.log"
mkdir -p "$STUB_BIN"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\n' "$STUB_LOG" > "$STUB_BIN/claude"
chmod +x "$STUB_BIN/claude"
# The fixtures' build and test targets append here; none may run.
REG_LOG="$SANDBOX/reg.log"
: > "$REG_LOG"

# A sandbox workspace: a git repository (its own main checkout) holding
# copies of the real scripts, project types and user-tier files.
WS="$SANDBOX/wsbox/ws"
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
REGISTRY="$WS/.agent/projects.local"
pfile() { echo "$WS/.agent/projects.d/$1"; }
line_of() { grep -E "^$1[[:space:]]" "$REGISTRY" 2>/dev/null; }
status_of() { sed -n 's/^STATUS=//p' <<< "$1" | tail -1; }
reg_snapshot() { # the registry, then each settings file's name and content
    local f
    cat "$REGISTRY" 2>/dev/null
    for f in "$WS/.agent/projects.d"/*; do
        [ -f "$f" ] && { echo "-- ${f##*/}"; cat "$f"; }
    done
}

# A git folder with a Makefile whose build and test append to $REG_LOG.
# make_proj <parent dir> <name> [with Makefile? 1|0] → its path.
make_proj() {
    local dir="$1/$2" with_mk="${3:-1}"
    mkdir -p "$dir"
    if [ "$with_mk" -eq 1 ]; then
        printf 'all:\n\t@echo BUILD_RAN:%s >> "$(REG_LOG)"\ntest:\n\t@echo TEST_RAN:%s >> "$(REG_LOG)"\n' "$2" "$2" > "$dir/Makefile"
    else
        echo "notes" > "$dir/README"
    fi
    gitq -C "$dir" init --quiet
    gitq -C "$dir" add -A
    gitq -C "$dir" commit --quiet -m init
    gitq -C "$dir" remote add origin "git@example.invalid:someone/$2.git"
    echo "$dir"
}

# Run the script (default: the sandbox workspace's copy) from <dir>, as a
# session started there would.
rsr() { # <dir> [args...]
    local dir="$1"
    shift
    (
        unset CLAUDE_CONFIG_DIR
        cd "$dir" && HOME="$HOMEDIR" PATH="$STUB_BIN:$PATH" REG_LOG="$REG_LOG" \
            AGENT_WORKSPACE_CLAUDE_BIN="$STUB_BIN/claude" \
            "${RSR_SCRIPT:-$WS/.agent/scripts/register_session_root.sh}" "$@" 2>&1
    )
}

P="$SANDBOX/src"
mkdir -p "$P"

# ------------------------------------------------------------ not promoted ---
echo "TEST: the script is not promoted to the user tier"
if grep -v '^[[:space:]]*#' "$REAL_ROOT/.agent/user_tier_scripts.txt" | grep -qF 'register_session_root.sh'; then
    fail "register_session_root.sh is listed in .agent/user_tier_scripts.txt (each call must ask for permission)"
else
    pass "no manifest line, so no allow-rule: each call asks for permission"
fi
check "the manifest's never-promoted comment names it" \
    grep -q '^#.*register_session_root\.sh' "$REAL_ROOT/.agent/user_tier_scripts.txt"
check "the script has no user-tier marker" \
    bash -c '! grep -q "user-tier: \(inert\|guarded-by\)" "$1"' _ "$REAL_ROOT/.agent/scripts/register_session_root.sh"

# ------------------------------------------------------------- dry run ---
echo "TEST: a dry run shows what registration would write and writes nothing"
ALPHA="$(make_proj "$P" alpha)"
out="$(rsr "$ALPHA" --dry-run)"; rc=$?
check "exit 0, STATUS=dry-run" [ "$rc" -eq 0 -a "$(status_of "$out")" = "dry-run" ]
check "names the registry line it would add, with the folder's absolute path" has "$out" "would add the registry line: alpha  single_project  $ALPHA"
check "names the detected build and test commands" bash -c '[[ "$1" == *"build=make"* && "$1" == *"test=make test"* ]]' _ "$out"
check "says the build and test are not run" has "$out" "would not run:"
check "no registry and no settings file written" [ ! -e "$REGISTRY" -a ! -e "$(pfile alpha)" ]

# ------------------------------------------------------------- register ---
echo "TEST: an unregistered git folder registers itself"
out="$(rsr "$ALPHA")"; rc=$?
check "exit 0, registered with the build and test not run" \
    bash -c '[ "$1" -eq 0 ] && [[ "$2" == registered,*"not run" ]]' _ "$rc" "$(status_of "$out")"
check "the registry holds its line, with its absolute path" bash -c '[[ "$1" == "alpha  single_project  $2" ]]' _ "$(line_of alpha)" "$ALPHA"
check "its settings file holds the detected commands" \
    bash -c 'grep -qx "build=make" "$1" && grep -qx "test=make test" "$1"' _ "$(pfile alpha)"
check "nothing was written into the folder" [ -z "$(git -C "$ALPHA" status --porcelain)" ]
check "neither the build nor the test ran" [ ! -s "$REG_LOG" ]
check "the installer never ran, and the sandbox ~/.claude was not created" [ ! -e "$STUB_LOG" -a ! -e "$HOMEDIR/.claude" ]

# ------------------------------------------------------------- refusals ---
echo "TEST: an already registered folder is refused before register_project.sh, --set included"
before="$(cat "$(pfile alpha)")"
snap="$(reg_snapshot)"
out="$(rsr "$ALPHA" --set build=x)"; rc=$?
check "exit 1, saying it is already registered" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"already registered as '"'"'alpha'"'"'"* ]]' _ "$rc" "$out"
check "its settings file is unchanged (no adoption writes --set)" [ "$(cat "$(pfile alpha)")" = "$before" ]
check "the registry is unchanged" [ "$(reg_snapshot)" = "$snap" ]
check "register_project.sh was never reached (no STATUS line)" bash -c '! grep -q "^STATUS=" <<< "$1"' _ "$out"

echo "TEST: a folder inside a registered root is refused"
mkdir -p "$ALPHA/sub"
out="$(rsr "$ALPHA/sub")"; rc=$?
check "a subdirectory: exit 1, naming the root" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"inside the registered root of '"'"'alpha'"'"'"* ]]' _ "$rc" "$out"
NESTED="$(make_proj "$ALPHA" nested)"
out="$(rsr "$NESTED")"; rc=$?
check "a git repository nested in the root: exit 1, the same refusal" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"inside the registered root of '"'"'alpha'"'"'"* ]]' _ "$rc" "$out"
check "the registry is unchanged" [ "$(reg_snapshot)" = "$snap" ]

echo "TEST: a folder over a registered root or the workspace is refused"
out="$(rsr "$P")"; rc=$?
check "the parent of a registered root: exit 1" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"registered root of '"'"'alpha'"'"' ($3) lies inside it"* ]]' _ "$rc" "$out" "$ALPHA"
out="$(rsr "$SANDBOX/wsbox")"; rc=$?
check "the parent of the workspace checkout: exit 1" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"workspace checkout"*"lies inside it"* ]]' _ "$rc" "$out"
out="$(rsr "$SANDBOX")"; rc=$?
check "a home-like folder holding both: exit 1" [ "$rc" -eq 1 ]
check "the registry is unchanged" [ "$(reg_snapshot)" = "$snap" ]

echo "TEST: the workspace checkout, a folder in it, and a worktree of it are refused"
out="$(rsr "$WS")"; rc=$?
check "the workspace: exit 1" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"in the workspace checkout"* ]]' _ "$rc" "$out"
out="$(rsr "$WS/.agent")"; rc=$?
check "a folder in the workspace: exit 1" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"in the workspace checkout"* ]]' _ "$rc" "$out"
gitq -C "$WS" worktree add --quiet "$SANDBOX/ws-linked" 2>/dev/null
out="$(rsr "$SANDBOX/ws-linked")"; rc=$?
check "a linked worktree of the workspace elsewhere: exit 1" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"in the workspace checkout"* ]]' _ "$rc" "$out"
check "the registry is unchanged" [ "$(reg_snapshot)" = "$snap" ]

echo "TEST: a folder that is not the top of its git repository, or a linked worktree, is refused"
BETA="$(make_proj "$P" beta)"
mkdir -p "$BETA/docs"
out="$(rsr "$BETA/docs")"; rc=$?
check "a subdirectory of an unregistered repository: exit 1, naming its top" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"not at its top; start the session at $3"* ]]' _ "$rc" "$out" "$BETA"
gitq -C "$BETA" worktree add --quiet "$SANDBOX/beta-wt" 2>/dev/null
out="$(rsr "$SANDBOX/beta-wt")"; rc=$?
check "a linked worktree: exit 1, naming the main checkout" bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"linked worktree"*"$3"* ]]' _ "$rc" "$out" "$BETA"
check "the registry is unchanged" [ "$(reg_snapshot)" = "$snap" ]

echo "TEST: a name already registered is refused, pointing at registration from the workspace"
mkdir -p "$SANDBOX/other"
DUP="$(make_proj "$SANDBOX/other" alpha)"
out="$(rsr "$DUP")"; rc=$?
check "exit 1, naming the registered path and register_project.sh --name" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"the name '"'"'alpha'"'"' is already registered, at $3"* && "$2" == *"register_project.sh $4 --name <name>"* ]]' _ "$rc" "$out" "$ALPHA" "$DUP"
check "the registry is unchanged" [ "$(reg_snapshot)" = "$snap" ]

echo "TEST: usage errors write nothing"
for args in "$BETA" "--install-user-tier" "--name x" "--set install=x" "--set build=" "--set build=x --set build=y" "--set"; do
    # shellcheck disable=SC2086  # each case is a word list
    out="$(rsr "$BETA" $args)"; rc=$?
    check "'$args': exit 2" [ "$rc" -eq 2 ]
done
check "the registry is unchanged" [ "$(reg_snapshot)" = "$snap" ]

# ------------------------------------------------ build and test commands ---
echo "TEST: a folder with no detectable build is refused until --set gives one"
GAMMA="$(make_proj "$P" gamma 0)"
out="$(rsr "$GAMMA" --dry-run)"; rc=$?
check "the dry run says no build command was detected (on its output, 2>&1)" \
    bash -c '[ "$1" -eq 0 ] && [[ "$2" == *"no build command detected"* ]]' _ "$rc" "$out"
out="$(rsr "$GAMMA")"; rc=$?
check "the real run is refused by the gate and rolled back" \
    bash -c '[ "$1" -eq 1 ] && [ -z "$(grep -E "^gamma[[:space:]]" "$2")" ] && [ ! -e "$3" ]' _ "$rc" "$REGISTRY" "$(pfile gamma)"
out="$(rsr "$GAMMA" --set build=none --set "test=none")"; rc=$?
check "with --set build=none --set test=none it registers" \
    bash -c '[ "$1" -eq 0 ] && [ -n "$(grep -E "^gamma[[:space:]]" "$2")" ] && grep -qx "build=none" "$3" && grep -qx "test=none" "$3"' _ "$rc" "$REGISTRY" "$(pfile gamma)"

echo "TEST: a --set value with a blank reaches register_project.sh as one argument"
DELTA="$(make_proj "$P" delta 0)"
out="$(rsr "$DELTA" --set "build=make all" --set "test=make test")"; rc=$?
check "registered, the command kept whole" \
    bash -c '[ "$1" -eq 0 ] && grep -qx "build=make all" "$2"' _ "$rc" "$(pfile delta)"

# ------------------------------------------------------------- no git ---
echo "TEST: a folder in no git repository: the dry run looks clean, the real run is refused and rolled back (the named gap)"
PLAIN="$SANDBOX/plain/notes"
mkdir -p "$PLAIN"
printf 'all:\n\t@echo BUILD_RAN:plain >> "$(REG_LOG)"\ntest:\n\t@echo TEST_RAN:plain >> "$(REG_LOG)"\n' > "$PLAIN/Makefile"
out="$(rsr "$PLAIN" --dry-run)"; rc=$?
check "dry run: exit 0" [ "$rc" -eq 0 ]
out="$(rsr "$PLAIN")"; rc=$?
check "real run: exit 1, not a git repository" \
    bash -c '[ "$1" -eq 1 ] && [[ "$2" == *"not a git repository"* ]]' _ "$rc" "$out"
check "rolled back: no registry line, no settings file" \
    bash -c '[ -z "$(grep -E "^notes[[:space:]]" "$1")" ] && [ ! -e "$2" ]' _ "$REGISTRY" "$(pfile notes)"

# ------------------------------------------------ copy in a worktree ---
echo "TEST: the copy in a linked worktree of the workspace registers in the main checkout"
EPS="$(make_proj "$P" epsilon)"
out="$(RSR_SCRIPT="$SANDBOX/ws-linked/.agent/scripts/register_session_root.sh" rsr "$EPS")"; rc=$?
check "exit 0, the line in the main checkout's registry" \
    bash -c '[ "$1" -eq 0 ] && [ -n "$(grep -E "^epsilon[[:space:]]" "$2")" ]' _ "$rc" "$REGISTRY"
check "no registry in the linked worktree" [ ! -e "$SANDBOX/ws-linked/.agent/projects.local" ]

check "across every case, no build or test ran" [ ! -s "$REG_LOG" ]
check "across every case, the installer never ran and ~/.claude was not created" [ ! -e "$STUB_LOG" -a ! -e "$HOMEDIR/.claude" ]

echo ""
echo "test_register_session_root: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
