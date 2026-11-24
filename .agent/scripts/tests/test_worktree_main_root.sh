#!/usr/bin/env bash
# .agent/scripts/tests/test_worktree_main_root.sh
# Tests for the workspace root of the four worktree scripts (issue 585):
# worktree_create.sh, worktree_enter.sh, worktree_list.sh and
# worktree_remove.sh take the workspace's main checkout as their root,
# found from their own location by wt_main_root (_worktree_helpers.sh),
# also when they run as the copy inside a linked worktree. Before the fix
# such a copy took the worktree itself as the root: new worktrees were
# made nested under it, and the registry (gitignored, so only in the main
# checkout) read empty.
#   - wt_main_root, one case per row of its contract: the main checkout,
#     a linked worktree (under worktrees/ and elsewhere), a symlinked
#     scripts directory, a symlinked checkout path, a project worktree
#     whose main checkout is not a workspace, a project that carries its
#     own scripts, the cwd in a project worktree, the user-tier file
#     absent, present and naming another workspace, and the refusals (not
#     a git checkout, git's own error, a plain directory inside another
#     repository, a linked worktree of a --separate-git-dir clone)
#   - the copy inside a linked worktree makes, finds, lists and removes
#     workspace and project worktrees where the main checkout keeps them,
#     and removes the very worktree it runs from (cwd in the main checkout)
#   - each of the four scripts refuses, as the copy in each refusal
#     fixture: exit non-zero, ERROR: on stderr, nothing on stdout; for
#     worktree_remove.sh a real worktree sits on the path it would act on
#     and survives (directory, branch and git's entry); worktree_enter.sh
#     sourced returns 1 and the caller's shell survives
# Everything runs in one sandbox (mktemp) with the real scripts copied in
# and committed, HOME set inside it, gh and git-bug stubbed to fail.
# Run: bash .agent/scripts/tests/test_worktree_main_root.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check() {  # <label> <command...>: pass when the command succeeds
    local label="$1"; shift
    if "$@"; then pass "$label"; else fail "$label"; fi
}
check_eq() {  # <label> <want> <got>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1: want [$2], got [$3]"; fi
}
check_has() {  # <label> <needle> <haystack>
    if [[ "$3" == *"$2"* ]]; then pass "$1"; else fail "$1: want [$2] in [${3:0:600}]"; fi
}

# One sandbox for the whole run, made at top level so the trap fires
# (issue #297), physical so the paths the scripts print compare equal.
SANDBOX_RAW="$(mktemp -d)"
if [ -z "$SANDBOX_RAW" ] || [ ! -d "$SANDBOX_RAW" ]; then
    echo "FATAL: mktemp -d failed"
    exit 1
fi
trap 'rm -rf "${SANDBOX_RAW:?}"' EXIT
SANDBOX="$(cd "$SANDBOX_RAW" && pwd -P)"
if [ -z "$SANDBOX" ] || [ ! -d "$SANDBOX" ]; then
    echo "FATAL: the sandbox path could not be resolved"
    exit 1
fi

# Hermetic git and HOME: no global config, no user-tier file unless a case
# writes one, a fake identity.
export HOME="$SANDBOX/home"
mkdir -p "$HOME/.claude"
# The user-tier file, always spelled from $SANDBOX, never from $HOME.
UT_FILE="$SANDBOX/home/.claude/agent-workspace-root"
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset WS_ROOT WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT

gitq() { git "$@" >/dev/null 2>&1; }

SCRIPTS=(worktree_create.sh worktree_enter.sh worktree_list.sh worktree_remove.sh
         _worktree_helpers.sh _project_registry.sh _issue_helpers.sh
         _resolve_default_branch.sh _real_case_path.sh adapter)

copy_scripts() {  # <dir>: the real scripts into <dir>/.agent/scripts
    local f
    mkdir -p "$1/.agent/scripts" "$1/.agent/project_types"
    for f in "${SCRIPTS[@]}"; do
        cp "$REAL_ROOT/.agent/scripts/$f" "$1/.agent/scripts/"
    done
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$1/.agent/project_types/"
}

# A workspace repository at <dir> on main with the scripts committed (so a
# linked worktree holds its own copy, as a real one does), gh and git-bug
# stubs (untracked), and an empty registry file (gitignored, as the real
# .agent/projects.local is: only the main checkout has it).
make_ws() {
    local ws="$1"
    copy_scripts "$ws"
    mkdir -p "$ws/stubbin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$ws/stubbin/gh"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$ws/stubbin/git-bug"
    chmod +x "$ws/stubbin/gh" "$ws/stubbin/git-bug"
    printf 'worktrees/\nstubbin/\nplain/\n.agent/projects.local\n' > "$ws/.gitignore"
    gitq -C "$ws" init -q -b main
    gitq -C "$ws" add -A
    gitq -C "$ws" commit -q -m "workspace scripts"
    : > "$ws/.agent/projects.local"
}

# A plain project repository at <dir> on main with one commit and an
# origin that fails fast (never the network).
make_project() {
    mkdir -p "$1"
    gitq -C "$1" init -q -b main
    printf 'project\n' > "$1/README.md"
    gitq -C "$1" add README.md
    gitq -C "$1" commit -q -m init
    gitq -C "$1" remote add origin "file:///nonexistent/$(basename "$1").git"
}

# Runs <script> with args, cwd <cwd>, the stubs first on PATH; sets
# OUT (stdout), ERR (stderr), RC.
run_script() {  # <cwd> <script> <args...>
    local cwd="$1" script="$2" ef
    shift 2
    ef="$SANDBOX/stderr.$$"
    RC=0
    OUT="$(cd "$cwd" && PATH="$WS/stubbin:$PATH" "$script" "$@" 2>"$ef")" || RC=$?
    ERR="$(cat "$ef")"
}

# wt_main_root from the copy in <scripts_dir>, cwd <cwd>; sets OUT, ERR, RC.
run_helper() {  # <cwd> <scripts_dir>
    local ef="$SANDBOX/stderr.$$"
    RC=0
    OUT="$(cd "$1" && bash -c 'source "$1/_worktree_helpers.sh" && wt_main_root "$1" test.sh' _ "$2" 2>"$ef")" || RC=$?
    ERR="$(cat "$ef")"
}

check_refused() {  # <label>: the last run refused cleanly
    check_eq "$1: exit 1" 1 "$RC"
    check_eq "$1: nothing on stdout" "" "$OUT"
    check_has "$1: ERROR on stderr" "ERROR:" "$ERR"
}

has_branch() { git -C "$1" rev-parse --verify --quiet "refs/heads/$2" >/dev/null; }
git_lists() { git -C "$1" worktree list --porcelain | grep -qxF "worktree $2"; }

# ------------------------------------------------------------- fixture ---
WS="$SANDBOX/ws"
make_ws "$WS"
PROJ="$SANDBOX/projects/demo"
make_project "$PROJ"
echo "demo single_project $PROJ" > "$WS/.agent/projects.local"
W3="$WS/worktrees/workspace/issue-workspace-3"
mkdir -p "$WS/worktrees/workspace"
gitq -C "$WS" worktree add -q -b feature/issue-3 "$W3" main
W3S="$W3/.agent/scripts"
if [ ! -x "$W3S/worktree_create.sh" ] || [ -e "$W3/.agent/projects.local" ]; then
    echo "FATAL: sandbox setup failed (the worktree must carry the scripts and no registry)"
    exit 1
fi

# ======================================================= the helper ===
echo "TEST: wt_main_root, by case"

run_helper "$WS" "$WS/.agent/scripts"
check_eq "main checkout copy: prints the main checkout" "$WS" "$OUT"
check_eq "main checkout copy: exit 0, stderr empty" "0:" "$RC:$ERR"

run_helper "$W3" "$W3S"
check_eq "linked worktree copy under worktrees/: prints the main checkout" "$WS" "$OUT"
check_eq "linked worktree copy: exit 0" 0 "$RC"

ELSEWHERE="$SANDBOX/elsewhere-wt"
gitq -C "$WS" worktree add -q -b feature/elsewhere "$ELSEWHERE" main
run_helper "$ELSEWHERE" "$ELSEWHERE/.agent/scripts"
check_eq "linked worktree outside the main checkout: prints the main checkout" "$WS" "$OUT"

run_helper "$SANDBOX" "$W3S"
check_eq "cwd plays no part (cwd outside every checkout)" "$WS" "$OUT"

# The script reached by an absolute path while the cwd is in a project
# worktree (the user-tier call): only its location counts.
PWT="$SANDBOX/projects/demo-side-wt"
gitq -C "$PROJ" worktree add -q -b side "$PWT" main
run_helper "$PWT" "$WS/.agent/scripts"
check_eq "cwd in a project worktree: prints the workspace main checkout" "$WS" "$OUT"

# The user-tier file is never read: absent, naming another workspace, the
# same answer.
OTHER_WS="$SANDBOX/other-ws"
make_ws "$OTHER_WS"
run_helper "$W3" "$W3S"; no_file="$OUT"
echo "$OTHER_WS" > "$UT_FILE"
run_helper "$W3" "$W3S"; with_file="$OUT"
check_eq "user-tier file naming another workspace: same answer" "$no_file" "$with_file"
check_eq "user-tier file naming another workspace: still this main checkout" "$WS" "$with_file"
echo "$WS" > "$UT_FILE"
run_helper "$OTHER_WS" "$OTHER_WS/.agent/scripts"
check_eq "user-tier file naming this workspace, copy of the other: the other" "$OTHER_WS" "$OUT"
rm -f "$UT_FILE"

# A symlinked .agent/scripts: the checkout is the link's grandparent, not
# the target's.
LINKWS="$SANDBOX/linkws"
make_ws "$LINKWS"
mkdir -p "$SANDBOX/deep/elsewhere"
mv "$LINKWS/.agent/scripts" "$SANDBOX/deep/elsewhere/scripts"
ln -s "$SANDBOX/deep/elsewhere/scripts" "$LINKWS/.agent/scripts"
run_helper "$LINKWS" "$LINKWS/.agent/scripts"
check_eq "symlinked .agent/scripts: prints the checkout holding the link" "$LINKWS" "$OUT"

# A symlinked path to the checkout: printed physical.
ln -s "$WS" "$SANDBOX/ws-link"
run_helper "$SANDBOX" "$SANDBOX/ws-link/worktrees/workspace/issue-workspace-3/.agent/scripts"
check_eq "symlinked checkout path: prints the physical main checkout" "$WS" "$OUT"

# A worktree of a project repository that carries a copy of the scripts on
# a branch, whose main checkout holds none: not a workspace checkout.
NOTWS="$SANDBOX/projects/notws"
make_project "$NOTWS"
gitq -C "$NOTWS" checkout -q -b carries
copy_scripts "$NOTWS"
gitq -C "$NOTWS" add -A
gitq -C "$NOTWS" commit -q -m "a copy of the scripts on a branch"
gitq -C "$NOTWS" checkout -q main
NOTWS_WT="$SANDBOX/projects/notws-wt"
gitq -C "$NOTWS" worktree add -q "$NOTWS_WT" carries
run_helper "$NOTWS_WT" "$NOTWS_WT/.agent/scripts"
check_refused "project worktree, main checkout without the scripts"
check_has "project worktree: says it is not a workspace checkout" "not a workspace checkout" "$ERR"
check_has "project worktree: names the main checkout" "$NOTWS" "$ERR"

# A project that carries its own copy on main: its own main checkout (what
# git names and where the scripts are; the plan's open question).
CARRIES="$SANDBOX/projects/carries"
make_project "$CARRIES"
copy_scripts "$CARRIES"
gitq -C "$CARRIES" add -A
gitq -C "$CARRIES" commit -q -m "own copy of the scripts"
CARRIES_WT="$SANDBOX/projects/carries-wt"
gitq -C "$CARRIES" worktree add -q -b side "$CARRIES_WT" main
run_helper "$CARRIES_WT" "$CARRIES_WT/.agent/scripts"
check_eq "project carrying the scripts: its own main checkout" "$CARRIES" "$OUT"

# Refusal fixtures, shared with the script refusals below. Each has a real
# linked worktree on the path a script would act on from that copy.
# (a) not a git checkout
NOGIT="$SANDBOX/nogit"
copy_scripts "$NOGIT"
mkdir -p "$NOGIT/worktrees/workspace"
gitq -C "$WS" worktree add -q -b feature/nogit-3 "$NOGIT/worktrees/workspace/issue-workspace-3" main
# (b) a plain directory inside another repository (the workspace itself)
PLAIN="$WS/plain"
copy_scripts "$PLAIN"
mkdir -p "$PLAIN/worktrees/workspace"
gitq -C "$WS" worktree add -q -b feature/plain-3 "$PLAIN/worktrees/workspace/issue-workspace-3" main
# (c) a linked worktree of a --separate-git-dir clone (git names no main
# checkout for it), with a second linked worktree under it named issue 4
SEP="$SANDBOX/sepclone"
gitq clone -q --separate-git-dir="$SANDBOX/sep.git" "$WS" "$SEP"
mkdir -p "$SEP/worktrees/workspace"
SEP3="$SEP/worktrees/workspace/issue-workspace-3"
gitq -C "$SEP" worktree add -q -b feature/issue-3 "$SEP3" main
mkdir -p "$SEP3/worktrees/workspace"
SEP4="$SEP3/worktrees/workspace/issue-workspace-4"
gitq -C "$SEP" worktree add -q -b feature/issue-4 "$SEP4" main
# (d) a checkout whose .git names a missing git dir: git's own error
BROKEN="$SANDBOX/broken"
copy_scripts "$BROKEN"
echo "gitdir: $SANDBOX/no-such-gitdir" > "$BROKEN/.git"

for d in "$NOGIT/worktrees/workspace/issue-workspace-3" "$PLAIN/worktrees/workspace/issue-workspace-3" "$SEP3" "$SEP4"; do
    if [ ! -d "$d/.agent/scripts" ]; then
        echo "FATAL: refusal fixture $d was not made"
        exit 1
    fi
done
if ! (cd "$SEP" && git rev-parse --git-dir >/dev/null 2>&1) || [ -z "$(git -C "$SEP3" rev-parse --git-common-dir 2>/dev/null)" ]; then
    echo "FATAL: the --separate-git-dir clone was not made"
    exit 1
fi

run_helper "$NOGIT" "$NOGIT/.agent/scripts"
check_refused "not a git checkout"
check_has "not a git checkout: says so" "is not a git checkout" "$ERR"
check_has "not a git checkout: carries git's own line" "fatal: not a git repository" "$ERR"
check_has "not a git checkout: names the script" "test.sh" "$ERR"

run_helper "$BROKEN" "$BROKEN/.agent/scripts"
check_refused "git fails"
check_has "git fails: carries git's own line, naming the missing git dir" "$SANDBOX/no-such-gitdir" "$ERR"

run_helper "$PLAIN" "$PLAIN/.agent/scripts"
check_refused "plain directory inside another repository"
check_has "plain directory: says it is not the top level" "is not the top level of a git checkout" "$ERR"

run_helper "$SEP3" "$SEP3/.agent/scripts"
check_refused "linked worktree of a --separate-git-dir clone"
check_has "--separate-git-dir worktree: says git names no main checkout" "main checkout git does not name" "$ERR"

run_helper "$SEP" "$SEP/.agent/scripts"
check_eq "the --separate-git-dir main checkout itself is accepted" "$SEP" "$OUT"

# ============================== the copy inside a linked worktree ===
echo "TEST: the copy inside a linked worktree makes, finds, lists and removes where the main checkout keeps them"

run_script "$W3" "$W3S/worktree_create.sh" --issue 9 --type workspace --allow-unverified-branch
W9="$WS/worktrees/workspace/issue-workspace-9"
check_eq "create --type workspace from the copy: exit 0 ($(tail -n2 <<<"$ERR"))" 0 "$RC"
check "create: the new worktree is under the main checkout ($W9)" test -d "$W9"
check "create: nothing nested under the worktree the copy runs from" test ! -e "$W3/worktrees"
check "create: git lists it from the main checkout" git_lists "$WS" "$W9"

run_script "$W3" "$W3S/worktree_enter.sh" --issue 3 --type workspace --print-path
check_eq "enter --print-path finds the worktree the copy runs from" "$W3" "$OUT"
run_script "$W3" "$W3S/worktree_enter.sh" --issue 9 --type workspace --print-path
check_eq "enter --print-path finds a sibling worktree" "$W9" "$OUT"

# The registry is the main checkout's: a registered project is found.
run_script "$W3" "$W3S/worktree_create.sh" --issue 5 --type project --project demo --allow-unverified-branch
check_eq "create --type project from the copy: exit 0 ($(tail -n2 <<<"$ERR"))" 0 "$RC"
P5="$(find "$PROJ/worktrees" -maxdepth 1 -name 'issue-*-5' -type d 2>/dev/null | head -n1)"
check "create --type project: the worktree is under the registered project's base" test -n "$P5"
check "create --type project: git lists it in the project" git_lists "$PROJ" "$P5"

run_script "$W3" "$W3S/worktree_list.sh" --json
check_eq "list --json from the copy: exit 0" 0 "$RC"
check_has "list --json from the copy: holds the project worktree" "$P5" "$OUT"
check_has "list --json from the copy: holds the workspace worktree" "$W9" "$OUT"

run_script "$W3" "$W3S/worktree_enter.sh" --issue 5 --type project --project demo --print-path
check_eq "enter --type project from the copy finds it" "$P5" "$OUT"

# The same with the user-tier file naming another workspace: no change.
echo "$OTHER_WS" > "$UT_FILE"
run_script "$W3" "$W3S/worktree_enter.sh" --issue 5 --type project --project demo --print-path
check_eq "enter with the user-tier file naming another workspace: the same" "$P5" "$OUT"
rm -f "$UT_FILE"

run_script "$W3" "$W3S/worktree_remove.sh" --issue 5 --type project --project demo
check_eq "remove --type project from the copy: exit 0 ($(tail -n2 <<<"$OUT$ERR"))" 0 "$RC"
check "remove --type project: the worktree is gone" test ! -e "$P5"

run_script "$W3" "$W3S/worktree_remove.sh" --issue 9 --type workspace
check_eq "remove --type workspace from the copy: exit 0 ($(tail -n2 <<<"$OUT$ERR"))" 0 "$RC"
check "remove --type workspace: the sibling worktree is gone" test ! -e "$W9"

# The copy removes the worktree it runs from, cwd in the main checkout (as
# merge_pr.sh run as that copy does after its cd to the main checkout).
run_script "$WS" "$W3S/worktree_remove.sh" --issue 3 --type workspace
check_eq "remove its own worktree, cwd main checkout: exit 0 ($(tail -n2 <<<"$OUT$ERR"))" 0 "$RC"
check "remove its own worktree: the tree is gone" test ! -e "$W3"
check "remove its own worktree: git no longer lists it" bash -c '! git -C "$1" worktree list --porcelain | grep -qxF "worktree $2"' _ "$WS" "$W3"
check_has "remove its own worktree: the closing listing is printed" "Remaining worktrees:" "$OUT"
check "remove its own worktree: the main checkout is intact" test -f "$WS/.agent/scripts/worktree_remove.sh"

# ============================================== the four refusals ===
echo "TEST: each script refuses as the copy in each refusal fixture, and acts on nothing"

refusal_case() {  # <label> <own checkout> <repo holding the target> <target worktree> <target issue> <target branch>
    local label="$1" own="$2" repo="$3" target="$4" issue="$5" branch="$6" s="$2/.agent/scripts"
    run_script "$own" "$s/worktree_create.sh" --issue 11 --type workspace --allow-unverified-branch
    check_refused "$label, create"
    check "$label, create: no worktree made under the copy's checkout" bash -c '! compgen -G "$1/worktrees/workspace/*-11" >/dev/null' _ "$own"
    check "$label, create: no branch made" bash -c '! git -C "$1" rev-parse --verify --quiet refs/heads/feature/issue-11 >/dev/null' _ "$repo"

    run_script "$own" "$s/worktree_enter.sh" --issue "$issue" --type workspace --print-path
    check_refused "$label, enter --print-path"

    RC=0
    OUT="$(cd "$own" && PATH="$WS/stubbin:$PATH" bash -c 'source "$1" --issue "$2" --type workspace; echo "survived rc=$?"' _ "$s/worktree_enter.sh" "$issue" 2>/dev/null)" || RC=$?
    check_eq "$label, enter sourced: returns 1, the caller's shell survives" "survived rc=1" "$(tail -n1 <<<"$OUT")"

    run_script "$own" "$s/worktree_list.sh"
    check_refused "$label, list"

    run_script "$own" "$s/worktree_remove.sh" --issue "$issue" --type workspace
    check_refused "$label, remove"
    check "$label, remove: the worktree on its path is still there" test -d "$target/.agent/scripts"
    check "$label, remove: its branch is still there" has_branch "$repo" "$branch"
    check "$label, remove: git still lists it" git_lists "$repo" "$target"
    run_script "$own" "$s/worktree_remove.sh" --issue "$issue" --type workspace --force
    check_refused "$label, remove --force"
    check "$label, remove --force: the worktree is still there" test -d "$target/.agent/scripts"
    check "$label, remove --force: git still lists it" git_lists "$repo" "$target"
}

refusal_case "not a git checkout" "$NOGIT" "$WS" "$NOGIT/worktrees/workspace/issue-workspace-3" 3 feature/nogit-3
refusal_case "plain directory inside another repository" "$PLAIN" "$WS" "$PLAIN/worktrees/workspace/issue-workspace-3" 3 feature/plain-3
refusal_case "--separate-git-dir linked worktree" "$SEP3" "$SEP" "$SEP4" 4 feature/issue-4

# A project worktree is untouched by every refusal above.
check "a project worktree is untouched by the refusals" test -f "$PWT/README.md"
check "git still lists the project worktree" git_lists "$PROJ" "$PWT"

echo ""
echo "test_worktree_main_root: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
