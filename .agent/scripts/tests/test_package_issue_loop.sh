#!/usr/bin/env bash
# .agent/scripts/tests/test_package_issue_loop.sh
# The run-issue loop for an issue of a package repository in a
# multi-repository project (issue 429, ADR-0012 package worktrees).
#
# Synthetic and offline: a workspace repository made from this tree's
# scripts, one registered ros2_colcon project "demo" whose hosting folder
# lies inside the workspace tree (so a package worktree's top folder has
# the workspace's main checkout as its git toplevel), two package
# repositories pkg_a and pkg_b with scp-form origins served from local bare
# repositories through a GIT_SSH_COMMAND stub, and a stub `gh` that logs
# every call and resolves a checkout's repository the way real gh does: a
# remote marked by `gh repo set-default` first, then upstream, github,
# origin. pkg_b carries its own, merged, issue 7 records, so the sibling
# has the same issue number as the issue being driven.
#
# Directories: H the project's hosting folder (the session root); C the
# package worktree for owner/pkg_a#7; A its pkg_a checkout (the owning
# repository); B its pkg_b checkout (a sibling); C2 and A2/B2 the same for
# owner/pkg_b#7, where pkg_b owns.
#
# Run: bash .agent/scripts/tests/test_package_issue_loop.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_AGENT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check() {  # <label> <condition-exit-status> [detail]
    if [[ "$2" -eq 0 ]]; then pass "$1"; else fail "$1${3:+ ($3)}"; fi
}

# One sandbox for the whole run, created at top level so the trap fires.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT
export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig" GIT_CONFIG_NOSYSTEM=1
printf '[init]\n\tdefaultBranch = main\n[user]\n\tname = t\n\temail = t@t\n' > "$GIT_CONFIG_GLOBAL"
export AGENT_NAME="Test Agent" AGENT_EMAIL="t@example.com"
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

WS="$SANDBOX/ws"
S="$WS/.agent/scripts"
STUB="$SANDBOX/stubbin"
REM="$SANDBOX/remotes/github.com"
mkdir -p "$WS/.agent/projects.d" "$WS/.agent/project_types" "$STUB" "$REM/owner" "$SANDBOX/rosroot/fakefox"

# git@github.com:<owner>/<repo>.git is served from $REM/<owner>/<repo>.git.
printf '#!/usr/bin/env bash\ncd "%s" && eval "exec ${@: -1}"\n' "$REM" > "$STUB/fakessh"
export GIT_SSH_COMMAND="$STUB/fakessh"

cat > "$STUB/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s | cwd=%s\n' "$*" "$PWD" >> "${GH_LOG:?}"
case "$1 $2" in
    "issue view") echo '{"title":"Fix the thing","body":"b","comments":[]}'; exit 0 ;;
    "repo view") ;;
    *) exit 1 ;;
esac
pick=""
for r in $(git remote 2>/dev/null); do
    [ "$(git config --get "remote.$r.gh-resolved")" = base ] && pick="$r"
done
if [ -z "$pick" ]; then
    for r in upstream github origin; do
        git remote get-url "$r" >/dev/null 2>&1 && { pick="$r"; break; }
    done
fi
[ -n "$pick" ] || { echo "no git remotes found" >&2; exit 1; }
url=$(git remote get-url "$pick"); nwo="${url#*github.com[:/]}"; nwo="${nwo%.git}"
if [[ " $* " == *" --jq "* ]]; then echo "$nwo"; else printf '{"nameWithOwner":"%s"}\n' "$nwo"; fi
EOF
printf '#!/usr/bin/env bash\nexit 1\n' > "$STUB/git-bug"
for t in colcon vcs; do printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/$t"; done
chmod +x "$STUB/"*
export PATH="$STUB:$PATH" GH_LOG="$SANDBOX/gh.log"
: > "$GH_LOG"

# The workspace: this tree's scripts and two project types, committed.
cp -r "$REAL_AGENT/scripts" "$S"
rm -rf "$S/tests"
cp -r "$REAL_AGENT/project_types/ros2_colcon" "$REAL_AGENT/project_types/single_project" "$WS/.agent/project_types/"
mkdir -p "$WS/.claude/skills/run-issue"
cp "$REAL_AGENT/../.claude/skills/run-issue/SKILL.md" "$WS/.claude/skills/run-issue/"
git -C "$WS" init -q
git -C "$WS" add -A
git -C "$WS" commit -q -m init

# The project "demo": hosting folder inside the workspace tree, no git of
# its own, one layer l1 holding pkg_a and pkg_b.
H="$WS/projects/demo"
M="$H/configs/manifest"
mkdir -p "$M/repos"
printf 'l1\n' > "$M/layers.txt"
printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\ndistro: fakefox\n' > "$M/bootstrap.yaml"
printf 'repositories:\n  pkg_a:\n    type: git\n    url: file:///x/pkg_a.git\n    version: main\n  pkg_b:\n    type: git\n    url: file:///x/pkg_b.git\n    version: main\n' > "$M/repos/l1.repos"
echo 'export SOURCED_LAYERS="base"' > "$SANDBOX/rosroot/fakefox/setup.bash"
echo "demo ros2_colcon $H" >> "$WS/.agent/projects.local"
echo "ROS_ROOT_DIR=\"$SANDBOX/rosroot\"" > "$WS/.agent/projects.d/demo.sh"
for r in pkg_a pkg_b; do
    git init -q --bare "$REM/owner/$r.git"
    seed="$SANDBOX/seed_$r"
    git init -q "$seed"
    echo "$r" > "$seed/README.md"
    if [[ "$r" == pkg_b ]]; then
        mkdir -p "$seed/.agent/work-plans/issue-7"
        printf -- '---\nissue: 7\n---\n\n# Issue #7 — pkg_b own issue 7\n\n## Plan Authored\n**Status**: complete\n**When**: 2026-11-01 10:00 -05:00\n**By**: x (y)\n**Plan**: `p` at `abc1234`\n' \
            > "$seed/.agent/work-plans/issue-7/progress.md"
    fi
    git -C "$seed" add -A
    git -C "$seed" commit -q -m init
    git -C "$seed" push -q "$REM/owner/$r.git" main
    rm -rf "$seed"
    git clone -q "git@github.com:owner/$r.git" "$H/layers/main/l1_ws/src/$r"
done

create() {  # worktree_create.sh from the session root H
    (cd "$H" && "$S/worktree_create.sh" "$@") > "$SANDBOX/create.log" 2>&1
}
create --issue owner/pkg_a#7 --type project --project demo --layer l1 --package-repos pkg_a,pkg_b \
    || { cat "$SANDBOX/create.log"; echo "setup failed: package worktree owner/pkg_a#7"; exit 1; }
create --issue owner/pkg_b#7 --type project --project demo --layer l1 --package-repos pkg_a,pkg_b \
    || { cat "$SANDBOX/create.log"; echo "setup failed: package worktree owner/pkg_b#7"; exit 1; }
create --issue owner/pkg_a#9 --type project --project demo --layer l1 --package-repos pkg_b \
    || { cat "$SANDBOX/create.log"; echo "setup failed: package worktree owner/pkg_a#9"; exit 1; }

C="$H/worktrees/issue-demo-owner-pkg_a-7"
A="$C/l1_ws/src/pkg_a"
B="$C/l1_ws/src/pkg_b"
C2="$H/worktrees/issue-demo-owner-pkg_b-7"
A2="$C2/l1_ws/src/pkg_b"
C9="$H/worktrees/issue-demo-owner-pkg_a-9"
B9="$C9/l1_ws/src/pkg_b"
PKG_B_HOSTED="$H/layers/main/l1_ws/src/pkg_b"

dp() {  # <cwd> <args...> -- dispatch_phase.sh; stdout+stderr, then rc= on the last line
    local cwd="$1"; shift
    local out rc
    out=$(cd "$cwd" && "$S/dispatch_phase.sh" "$@" 2>&1); rc=$?
    printf '%s\nrc=%s\n' "$out" "$rc"
}
heads() {  # every repository a misplaced write could land in
    local d
    for d in "$WS" "$A" "$B" "$PKG_B_HOSTED" "$A2" "$C2/l1_ws/src/pkg_a"; do
        printf '%s %s %s\n' "$d" "$(git -C "$d" rev-parse HEAD)" "$(git -C "$d" status --porcelain | tr '\n' ' ')"
    done
}
entry() {  # <type> [extra field lines...]
    local t="$1"; shift
    printf '## %s\n**Status**: complete\n**When**: 2026-11-10 10:00 -05:00\n**By**: t (m)\n' "$t"
    local l
    for l in "$@"; do printf '%s\n' "$l"; done
}
checkpoint_entry() {
    entry Checkpoint '**Decided-by**: owner' '**After**: plan' '**Decision**: proceed'
}

check "setup: a package worktree records a manifest; the owning entry is on feature/issue-7" \
    "$([[ -f "$C/.worktree-repos" && "$(git -C "$A" branch --show-current)" == feature/issue-7 \
          && "$(git -C "$B" branch --show-current)" == feature/pkg_a-issue-7 ]]; echo $?)"

# ------------------------------------------------------------------ case 1
echo "TEST: from the session root, owner/pkg_a#7 names the owning checkout A everywhere"
out=$(dp "$H" where --issue 'owner/pkg_a#7' --type project)
check "where prints A" "$([[ "$out" == "$A"$'\n'"rc=0" ]]; echo $?)" "$out"

out=$(dp "$H" next --issue 'owner/pkg_a#7' --type project --pr none)
check "next on an empty timeline: review-issue" "$([[ "$out" == "action=review-issue"* && "$out" == *"rc=0" ]]; echo $?)" "$out"

out=$(dp "$H" --issue 'owner/pkg_a#7' --skill review-issue --type project)
check "handoff: worktree=A, package_worktree=C, task line takes the number" \
    "$([[ "$out" == *"worktree=$A"$'\n'"package_worktree=$C"$'\n'"task=/review-issue 7"$'\n'* ]]; echo $?)" "$out"
check "handoff: the exit contract is A's timeline" \
    "$([[ "$out" == *"exit_contract=Append exactly one \`## Issue Review\` entry to $A/.agent/work-plans/issue-7/progress.md"* ]]; echo $?)" "$out"
check "handoff: conventions= says to cd into A at the head of every command chain" \
    "$([[ "$out" == *"conventions="*"Start every command chain with \`cd $A &&\`"* ]]; echo $?)" "$out"

# The implement handoff's exit contract names the writer and the run-issue
# skill by absolute path, so the printed command runs from inside A, which
# has no .agent/scripts of its own.
out=$(dp "$H" --issue 'owner/pkg_a#7' --skill implement --type project)
contract=$(sed -n 's/^exit_contract=//p' <<< "$out")
cmd=$(sed -n 's/.* via `\([^`]*\)` (entry on stdin).*/\1/p' <<< "$contract")
skill_doc=$(sed -n 's/.* in the shape `\([^`]*\)` step 4.*/\1/p' <<< "$contract")
check "implement handoff: the exit contract's command and skill are absolute paths that exist" \
    "$([[ "$cmd" == "$S/progress_append.sh 7 --title \"<issue title>\"" && -f "$skill_doc" && "$skill_doc" == /* ]]; echo $?)" "$contract"
cmd="${cmd//<issue title>/Fix the thing}"
a_before=$(git -C "$A" rev-parse HEAD)
out=$(cd "$A" && [[ ! -e .agent/scripts ]] && entry 'Issue Review' '**Issue**: #7' | eval "$cmd" 2>&1); rc=$?
check "the printed exit-contract command, run inside A (no .agent/scripts there), commits the entry in A" \
    "$([[ "$rc" -eq 0 && "$(git -C "$A" rev-parse HEAD)" != "$a_before" \
          && "$(git -C "$A" log -1 --format=%s)" == "progress: issue review for #7" ]]; echo $?)" "$out"
out=$(dp "$H" next --issue 'owner/pkg_a#7' --type project --pr none)
check "next reads A's timeline: an Issue Review there routes to plan-task" "$([[ "$out" == "action=plan-task"* ]]; echo $?)" "$out"
out=$(dp "$H" --check-exit --issue 'owner/pkg_a#7' --skill review-issue --type project --before 0)
check "check-exit counts A's entry and reports A's head" \
    "$([[ "$out" == "status=OK"$'\n'"sha=$(git -C "$A" rev-parse --short HEAD)"$'\n'"rc=0" ]]; echo $?)" "$out"

for _ in 1 2; do
    (cd "$A" && entry 'Local Review (Pre-Push)' '**Verdict**: needs-work' "**Branch**: feature/issue-7 at \`$(git -C "$A" rev-parse --short HEAD)\`" \
        | "$S/progress_append.sh" 7 >/dev/null 2>&1)
done
out=$(dp "$H" --issue 'owner/pkg_a#7' --skill review-code --type project)
check "review-code handoff counts rounds on A's branch (round 3 after two reviews)" \
    "$([[ "$out" == *"task=/review-code --branch --issue 7 (round 3:"* ]]; echo $?)" "$out"

gh_before=$(wc -l < "$GH_LOG")
dp "$H" next --issue 'owner/pkg_a#7' --type project --pr none >/dev/null
dp "$H" --check-exit --issue 'owner/pkg_a#7' --skill review-issue --type project --before 0 >/dev/null
check "next and check-exit call no gh" "$([[ "$(wc -l < "$GH_LOG")" -eq "$gh_before" ]]; echo $?)"

# ------------------------------------------------------------------ case 2
echo "TEST: the same number in the second repository, and a bare number"
out=$(dp "$H" where --issue 'owner/pkg_b#7' --type project)
check "owner/pkg_b#7 names the second worktree's pkg_b checkout" "$([[ "$out" == "$A2"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(dp "$H" --issue 'owner/pkg_b#7' --skill plan-task --type project)
check "its handoff: worktree= that checkout, package_worktree= the second worktree" \
    "$([[ "$out" == *"worktree=$A2"$'\n'"package_worktree=$C2"$'\n'* ]]; echo $?)" "$out"
out=$(dp "$H" where --issue 7 --type project)
check "bare 7 is refused with both qualified refs listed, not as 'no worktree found'" \
    "$([[ "$out" == *"--issue owner/pkg_a#7"* && "$out" == *"--issue owner/pkg_b#7"* \
          && "$out" != *"no project worktree found"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" next --issue 7 --type project --pr none)
check "next with bare 7 is refused the same way" \
    "$([[ "$out" == *"--issue owner/pkg_a#7"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" where --issue 'owner/pkg_c#7' --type project)
check "a qualified ref with no worktree: no project worktree found" \
    "$([[ "$out" == *"no project worktree found for issue owner/pkg_c#7"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" where --issue 'pkg_a#7' --type project)
check "a malformed ref is a usage error" "$([[ "$out" == *"--issue <owner/repo#N>"* && "$out" == *"rc=2" ]]; echo $?)" "$out"

# ------------------------------------------------------------------ case 3
echo "TEST: workspace and single-repository project issues are unchanged"
git -C "$WS" worktree add -q "$WS/worktrees/workspace/issue-workspace-7" -b feature/issue-7 >/dev/null 2>&1
WW="$WS/worktrees/workspace/issue-workspace-7"
gh_before=$(grep -c "^repo view" "$GH_LOG")
out=$(dp "$WS" where --issue 7 --type workspace)
check "workspace issue: where prints its worktree" "$([[ "$out" == "$WW"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(dp "$WS" --issue 7 --skill implement --type workspace)
check "workspace issue: handoff worktree= its worktree, no package_worktree=" \
    "$([[ "$out" == *"worktree=$WW"$'\n'"task="* && "$out" != *"package_worktree="* ]]; echo $?)" "$out"
out=$(cd "$WW" && checkpoint_entry | "$S/progress_append.sh" 7 2>&1); rc=$?
check "workspace issue: progress_append.sh commits in its worktree" \
    "$([[ "$rc" -eq 0 && "$(git -C "$WW" log -1 --format=%s)" == "progress: checkpoint for #7" ]]; echo $?)" "$out"
out=$(cd "$WW" && source "$S/_resolve_work_plans_dir.sh" && resolve_work_plans_dir 7 2>&1); rc=$?
check "workspace issue: the resolver gives its worktree" \
    "$([[ "$rc" -eq 0 && "$out" == "$WW/.agent/work-plans/issue-7" ]]; echo $?)" "$out"

SOLO="$SANDBOX/solo"
git init -q "$SOLO"
git -C "$SOLO" commit -q --allow-empty -m init
git -C "$SOLO" remote add origin "git@github.com:owner/solo.git"
echo "solo single_project $SOLO" >> "$WS/.agent/projects.local"
(cd "$SOLO" && "$S/worktree_create.sh" --issue 7 --type project --project solo) > "$SANDBOX/create.log" 2>&1 \
    || { cat "$SANDBOX/create.log"; fail "setup: single-repository project worktree"; }
SW="$SOLO/worktrees/issue-solo-7"
check "single-repository project worktree: no .worktree-repos written" "$([[ -d "$SW" && ! -e "$SW/.worktree-repos" ]]; echo $?)"
out=$(dp "$SOLO" where --issue 7 --type project --project solo)
check "single-repository project issue: where prints its worktree" "$([[ "$out" == "$SW"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(cd "$SW" && checkpoint_entry | "$S/progress_append.sh" 7 2>&1); rc=$?
check "single-repository project issue: progress_append.sh commits in its worktree" \
    "$([[ "$rc" -eq 0 && "$(git -C "$SW" log -1 --format=%s)" == "progress: checkpoint for #7" ]]; echo $?)" "$out"
# A legacy one-entry "." manifest still means the worktree itself.
printf '# project=solo issue=7 layer=\n%s\t.\tfeature/issue-7\n' "$SOLO" > "$SW/.worktree-repos"
out=$(dp "$SOLO" where --issue 7 --type project --project solo)
check "a legacy one-entry '.' manifest maps to the worktree itself" "$([[ "$out" == "$SW"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(cd "$SW" && entry Checkpoint '**Decided-by**: owner' '**After**: plan' '**Decision**: revise' | "$S/progress_append.sh" 7 2>&1); rc=$?
check "... and the guard lets that worktree commit" "$([[ "$rc" -eq 0 ]]; echo $?)" "$out"
rm -f "$SW/.worktree-repos"
check "workspace and single-repository issues: the dispatcher asked gh nothing" "$([[ "$(grep -c "^repo view" "$GH_LOG")" -eq "$gh_before" ]]; echo $?)"

# ------------------------------------------------------------------ case 4
echo "TEST: records writers commit in A and refuse B and C, writing nothing anywhere"
a_before=$(git -C "$A" rev-parse HEAD)
out=$(cd "$A" && entry Checkpoint '**Decided-by**: owner' '**After**: publish' '**Decision**: publish' | "$S/progress_append.sh" 7 2>&1); rc=$?
check "progress_append.sh from A commits in A" "$([[ "$rc" -eq 0 && "$(git -C "$A" rev-parse HEAD)" != "$a_before" ]]; echo $?)" "$out"
a_before=$(git -C "$A" rev-parse HEAD)
out=$(cd "$A" && entry 'Local Review (Pre-Push)' '**Verdict**: approved' '**Branch**: feature/issue-7 at `1111111`' \
    | "$S/review_progress.sh" persist --issue 7 2>&1); rc=$?
check "persist (compatibility) from A commits in A" \
    "$([[ "$rc" -eq 0 && "$out" != *"would have aborted"* && "$(git -C "$A" rev-parse HEAD)" != "$a_before" ]]; echo $?)" "$out"
a_before=$(git -C "$A" rev-parse HEAD)
out=$(cd "$A" && entry 'Local Review (Pre-Push)' '**Verdict**: approved' '**Branch**: feature/issue-7 at `2222222`' \
    | "$S/review_progress.sh" persist --issue 7 --strict 2>&1); rc=$?
check "persist (strict) from A commits in A" "$([[ "$rc" -eq 0 && "$(git -C "$A" rev-parse HEAD)" != "$a_before" ]]; echo $?)" "$out"

before=$(heads)
for where_ in B C; do
    dir="${!where_}"
    out=$(cd "$dir" && checkpoint_entry | "$S/progress_append.sh" 7 2>&1); rc=$?
    check "progress_append.sh from $where_ refuses (exit 4), naming A" \
        "$([[ "$rc" -eq 4 && "$out" == *"records go in $A"* ]]; echo $?)" "$out"
    for wi in "" 7; do
        out=$(cd "$dir" && checkpoint_entry | WORKTREE_ISSUE="$wi" "$S/review_progress.sh" persist --issue 7 2>&1); rc=$?
        check "persist (compatibility, WORKTREE_ISSUE='$wi') from $where_ refuses (exit 4), naming A" \
            "$([[ "$rc" -eq 4 && "$out" == *"records go in $A"* && "$out" != *"Progress persisted"* ]]; echo $?)" "$out"
    done
    out=$(cd "$dir" && checkpoint_entry | WORKTREE_ISSUE=7 "$S/review_progress.sh" persist --issue 7 --strict 2>&1); rc=$?
    check "persist (strict) from $where_ refuses (exit 4), naming A" \
        "$([[ "$rc" -eq 4 && "$out" == *"records go in $A"* ]]; echo $?)" "$out"
    out=$(cd "$H" && checkpoint_entry | "$S/progress_append.sh" -C "$dir" 7 2>&1); rc=$?
    check "progress_append.sh -C $where_ from the session root refuses" "$([[ "$rc" -eq 4 ]]; echo $?)" "$out"
done
after=$(heads)
check "the refusals committed and wrote nothing: workspace main, A, B, pkg_b's own checkout, the second worktree" \
    "$([[ "$before" == "$after" ]]; echo $?)" "$(diff <(echo "$before") <(echo "$after"))"
check "pkg_b's own issue 7 timeline still holds only its own entry" \
    "$([[ "$(grep -c '^## ' "$B/.agent/work-plans/issue-7/progress.md")" -eq 1 ]]; echo $?)"

out=$(cd "$H" && checkpoint_entry | "$S/progress_append.sh" -C "$A" 7 2>&1); rc=$?
check "progress_append.sh -C A from the session root commits in A" "$([[ "$rc" -eq 0 ]]; echo $?)" "$out"
out=$(cd "$A2" && checkpoint_entry | "$S/progress_append.sh" 7 2>&1); rc=$?
check "in the second worktree, its owning pkg_b checkout commits issue 7" "$([[ "$rc" -eq 0 ]]; echo $?)" "$out"
out=$(cd "$C2/l1_ws/src/pkg_a" && checkpoint_entry | "$S/progress_append.sh" 7 2>&1); rc=$?
check "... and its pkg_a sibling is refused, naming that pkg_b checkout" \
    "$([[ "$rc" -eq 4 && "$out" == *"records go in $A2"* ]]; echo $?)" "$out"

# ------------------------------------------------------------------ case 5
echo "TEST: resolve_work_plans_dir refuses B and C even with WORKTREE_ISSUE set"
for where_ in B C; do
    dir="${!where_}"
    out=$(cd "$dir" && export WORKTREE_ISSUE=7 && source "$S/_resolve_work_plans_dir.sh" && resolve_work_plans_dir 7 2>&1); rc=$?
    check "from $where_ with WORKTREE_ISSUE=7: refused, naming A" \
        "$([[ "$rc" -ne 0 && "$out" == *"records go in $A"* && "$out" != *"/.agent/work-plans/issue-7" ]]; echo $?)" "$out"
done
for wi in "" 7; do
    out=$(cd "$A" && unset WORKTREE_ISSUE && { [[ -z "$wi" ]] || export WORKTREE_ISSUE="$wi"; } \
        && source "$S/_resolve_work_plans_dir.sh" && resolve_work_plans_dir 7 2>&1); rc=$?
    check "from A (WORKTREE_ISSUE='$wi'): A's directory" \
        "$([[ "$rc" -eq 0 && "$out" == "$A/.agent/work-plans/issue-7" ]]; echo $?)" "$out"
done

# ------------------------------------------------------------------ case 6
echo "TEST: a package worktree with no entry on feature/issue-N refuses"
out=$(dp "$H" where --issue 'owner/pkg_a#9' --type project)
check "where refuses, listing the entries" \
    "$([[ "$out" == *"0 entries on feature/issue-9"* && "$out" == *"l1_ws/src/pkg_b (feature/pkg_a-issue-9)"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" next --issue 'owner/pkg_a#9' --type project --pr none)
check "next refuses too" "$([[ "$out" == *"0 entries on feature/issue-9"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
b9_before=$(git -C "$B9" rev-parse HEAD)
out=$(cd "$B9" && checkpoint_entry | "$S/progress_append.sh" 9 2>&1); rc=$?
check "progress_append.sh from its only (sibling) checkout refuses, committing nothing" \
    "$([[ "$rc" -eq 4 && "$(git -C "$B9" rev-parse HEAD)" == "$b9_before" ]]; echo $?)" "$out"

# ------------------------------------------------------------------ case 7
echo "TEST: gh must resolve the issue's own repository in the owning checkout"
git -C "$A" remote add upstream "git@github.com:other/pkg_a.git"
out=$(dp "$H" where --issue 'owner/pkg_a#7' --type project)
check "with an upstream remote, where refuses naming both repositories and the remedy" \
    "$([[ "$out" == *"gh resolves other/pkg_a"* && "$out" == *"owner/pkg_a#7"* \
          && "$out" == *"gh repo set-default owner/pkg_a"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" --issue 'owner/pkg_a#7' --skill review-plan --type project)
check "the handoff refuses the same way, printing no handoff" \
    "$([[ "$out" == *"gh resolves other/pkg_a"* && "$out" != *"worktree="* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" next --issue 'owner/pkg_a#7' --type project --pr none)
check "next still reads the timeline (it calls no gh)" "$([[ "$out" == "action="* && "$out" == *"rc=0" ]]; echo $?)" "$out"
git -C "$A" config remote.origin.gh-resolved base
out=$(dp "$H" where --issue 'owner/pkg_a#7' --type project)
check "after gh repo set-default owner/pkg_a, where prints A" "$([[ "$out" == "$A"$'\n'"rc=0" ]]; echo $?)" "$out"
git -C "$A" config --unset remote.origin.gh-resolved
git -C "$A" remote remove upstream
mv "$STUB/gh" "$STUB/gh.off"
printf '#!/usr/bin/env bash\necho "gh: not logged in" >&2\nexit 4\n' > "$STUB/gh"; chmod +x "$STUB/gh"
out=$(dp "$H" where --issue 'owner/pkg_a#7' --type project)
check "a failing gh refuses with its message, not a silent pass" \
    "$([[ "$out" == *"could not ask gh"*"not logged in"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
mv "$STUB/gh.off" "$STUB/gh"

# ------------------------------------------------------------------ case 8
# The records gate, as a class (pre-push review round 1, must-fix 1): every
# records entry point, reads and writes alike, run from the top folder C and
# from the sibling B with the path the skills build
# ("$(git rev-parse --show-toplevel)/.agent/work-plans/issue-7/..."), is
# refused naming A and touches nothing. From C that path is the workspace
# main checkout's own issue-7 timeline; from B it is pkg_b's own. Both hold
# an open review finding, so a `check` that got through would tick it.
echo "TEST: every records entry point refuses B and C, reads and writes alike"
review_entry() {  # <branch>
    entry 'Local Review (Pre-Push)' '**Verdict**: changes-requested' "**Branch**: $1 at \`1234567\`" '' '### Findings' \
        '- [ ] (must-fix) open finding — `x.sh:1`'
}
mkdir -p "$WS/.agent/work-plans/issue-7"
printf -- '---\nissue: 7\n---\n\n# Issue #7 — workspace issue 7\n\n' > "$WS/.agent/work-plans/issue-7/progress.md"
review_entry feature/issue-7 >> "$WS/.agent/work-plans/issue-7/progress.md"
printf '# plan\n' > "$WS/.agent/work-plans/issue-7/plan.md"
git -C "$WS" add .agent/work-plans/issue-7 && git -C "$WS" commit -q -m "workspace issue 7 records"
{ echo; review_entry feature/pkg_a-issue-7; } >> "$B/.agent/work-plans/issue-7/progress.md"
printf '# pkg_b plan\n' > "$B/.agent/work-plans/issue-7/plan.md"
git -C "$B" add .agent/work-plans/issue-7 && git -C "$B" commit -q -m "pkg_b issue 7 review"
{ echo; review_entry feature/issue-7; } >> "$A/.agent/work-plans/issue-7/progress.md"
printf '# pkg_a plan\n' > "$A/.agent/work-plans/issue-7/plan.md"
git -C "$A" add .agent/work-plans/issue-7 && git -C "$A" commit -q -m "pkg_a issue 7 review"
printf '{"reviews": [], "comments": []}\n' > "$SANDBOX/reviews.json"

# One line per entry point: <name>%<command, run from the directory under
# test>[%<refusal text, when not the gate's>]. P is the literal path the
# skills build from that directory's toplevel. persist --strict with no
# WORKTREE_ISSUE is refused one step earlier, by the issue #147 rule (B's
# and C's toplevels encode no issue 7); the next row sets WORKTREE_ISSUE=7
# so the gate is what refuses.
# shellcheck disable=SC2016
EP_TABLE='
review_progress round%"$S/review_progress.sh" round --issue 7 --branch feature/issue-7
review_progress round --progress%"$S/review_progress.sh" round --progress "$P/progress.md" --branch feature/issue-7
review_progress persist%checkpoint_entry | "$S/review_progress.sh" persist --issue 7
review_progress persist --strict%checkpoint_entry | "$S/review_progress.sh" persist --issue 7 --strict%outside its worktree
review_progress persist (WORKTREE_ISSUE=7)%checkpoint_entry | WORKTREE_ISSUE=7 "$S/review_progress.sh" persist --issue 7 --strict
review_progress sources%"$S/review_progress.sh" sources --progress "$P/progress.md" --head 1234567 --reviews "$SANDBOX/reviews.json"
review_progress findings%"$S/review_progress.sh" findings --progress "$P/progress.md"
review_progress check%"$S/review_progress.sh" check --progress "$P/progress.md" --index 0
review_progress check --deferred%"$S/review_progress.sh" check --progress "$P/progress.md" --index 0 --deferred why
review_progress plan-sha%"$S/review_progress.sh" plan-sha --plan "$P/plan.md"
review_progress plan-sha --ref%"$S/review_progress.sh" plan-sha --plan ./.agent/work-plans/issue-7/plan.md --ref HEAD
progress_append%checkpoint_entry | "$S/progress_append.sh" 7
progress_append -C%checkpoint_entry | (cd "$H" && "$S/progress_append.sh" -C "$OLDPWD" 7)
resolve_work_plans_dir (WORKTREE_ISSUE=7)%(export WORKTREE_ISSUE=7; source "$S/_resolve_work_plans_dir.sh"; resolve_work_plans_dir 7)
resolve_work_plans_dir (override)%(export WORK_PLANS_DIR_OVERRIDE="$P"; source "$S/_resolve_work_plans_dir.sh"; resolve_work_plans_dir 7)
dispatch_phase next --progress%"$S/dispatch_phase.sh" next --progress "$P/progress.md" --pr none
'
# Every review_progress.sh subcommand has a row above, or is named here as
# taking no records path; a new subcommand fails this until it is placed.
NO_RECORDS_SUBS="verdict"
subs=$(sed -n 's/^    \([a-z-]*\)) *cmd_.*/\1/p' "$S/review_progress.sh")
check "review_progress.sh's dispatch table lists the seven known subcommands" \
    "$([[ "$(sort <<< "$subs" | tr '\n' ' ')" == "check findings persist plan-sha round sources verdict " ]]; echo $?)" "$subs"
for sub in $subs; do
    if [[ " $NO_RECORDS_SUBS " == *" $sub "* ]]; then
        out=$(cd "$B" && "$S/review_progress.sh" "$sub" --must-fix 0 --round 1 2>&1); rc=$?
        check "review_progress $sub takes no records path (runs from B)" "$([[ "$rc" -eq 0 ]]; echo $?)" "$out"
        continue
    fi
    check "review_progress $sub has an entry-point row" \
        "$(grep -q "^review_progress ${sub}[ %]" <<< "$EP_TABLE"; echo $?)"
done

before=$(heads)
sums_before=$(md5sum "$WS/.agent/work-plans/issue-7/"* "$B/.agent/work-plans/issue-7/"* "$PKG_B_HOSTED/.agent/work-plans/issue-7/"*)
n=0
while IFS='%' read -r name cmd why; do
    [[ -n "$name" ]] || continue
    n=$((n + 1))
    for where_ in B C; do
        dir="${!where_}"
        P="$(git -C "$dir" rev-parse --show-toplevel)/.agent/work-plans/issue-7"
        errf="$SANDBOX/ep.err"
        out=$(cd "$dir" && P="$P" eval "$cmd" 2>"$errf"); rc=$?
        err=$(cat "$errf")
        want_rc=4
        [[ "$name" == resolve_work_plans_dir* ]] && want_rc=1
        [[ "$name" == dispatch_phase* ]] && want_rc=2
        check "$name from $where_: refused (exit $want_rc), ${why:+by the #147 rule}${why:-naming A}, nothing on stdout" \
            "$([[ "$rc" -eq "$want_rc" && "$err" == *"${why:-records go in $A}"* && -z "$out" ]]; echo $?)" "rc=$rc out=$out err=$err"
    done
done <<< "$EP_TABLE"
after=$(heads)
sums_after=$(md5sum "$WS/.agent/work-plans/issue-7/"* "$B/.agent/work-plans/issue-7/"* "$PKG_B_HOSTED/.agent/work-plans/issue-7/"*)
check "the $n entry points refused from B and C wrote and committed nothing anywhere" \
    "$([[ "$before" == "$after" && "$sums_before" == "$sums_after" ]]; echo $?)" "$(diff <(echo "$before$sums_before") <(echo "$after$sums_after"))"
check "the table covers at least 16 entry points" "$([[ "$n" -ge 16 ]]; echo $?)" "n=$n"

out=$(cd "$B" && "$S/dispatch_phase.sh" where --issue 'owner/pkg_a#7' --type project 2>&1); rc=$?
check "the dispatcher derives A from B too (it never resolves from the current directory)" \
    "$([[ "$rc" -eq 0 && "$out" == "$A" ]]; echo $?)" "$out"

# The same reads from A, and from the workspace main checkout for its own
# issue-7 timeline (no manifest there), go through as before.
for where_ in A WS; do
    dir="${!where_}"
    P="$(git -C "$dir" rev-parse --show-toplevel)/.agent/work-plans/issue-7"
    out=$(cd "$dir" && "$S/review_progress.sh" round --issue 7 --branch feature/issue-7 2>&1); rc=$?
    check "round from $where_ reads its own timeline" "$([[ "$rc" -eq 0 && "$out" == "round="[2-9]* ]]; echo $?)" "$out"
    out=$(cd "$dir" && "$S/review_progress.sh" findings --progress "$P/progress.md" 2>&1); rc=$?
    check "findings from $where_ lists the open finding" "$([[ "$rc" -eq 0 && "$out" == *'"index": 0'* ]]; echo $?)" "$out"
    out=$(cd "$dir" && "$S/review_progress.sh" sources --progress "$P/progress.md" --head 1234567 --reviews "$SANDBOX/reviews.json" 2>&1); rc=$?
    check "sources from $where_ runs" "$([[ "$rc" -eq 0 ]]; echo $?)" "$out"
    out=$(cd "$dir" && "$S/review_progress.sh" plan-sha --plan "$P/plan.md" 2>&1); rc=$?
    check "plan-sha from $where_ prints the plan commit" "$([[ "$rc" -eq 0 && "$out" == "$(git -C "$dir" log -1 --format=%h -- .agent/work-plans/issue-7/plan.md)" ]]; echo $?)" "$out"
    out=$(cd "$dir" && "$S/review_progress.sh" check --progress "$P/progress.md" --index 0 2>&1); rc=$?
    check "check from $where_ ticks its own box" "$([[ "$rc" -eq 0 && "$out" == "- [x] (must-fix) open finding"* ]]; echo $?)" "$out"
    git -C "$dir" checkout -q -- .agent/work-plans/issue-7/progress.md
done

echo
echo "test_package_issue_loop: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
