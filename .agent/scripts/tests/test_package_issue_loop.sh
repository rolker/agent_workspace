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
    "pr create") echo "https://github.com/owner/x/pull/1"; exit 0 ;;
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
# Creation without --base takes the pin of the owning repository (main for
# both here) as the base and records it (issue 429); a worktree with no
# owning entry (C9: pkg_b only, for an issue of pkg_a) has none.
check "setup: creation without --base records the owning repository's pin as base=" \
    "$([[ "$(head -n1 "$C/.worktree-repos")" == "# project=demo issue=owner/pkg_a#7 layer=l1 base=main" \
          && "$(head -n1 "$C2/.worktree-repos")" == "# project=demo issue=owner/pkg_b#7 layer=l1 base=main" \
          && "$(head -n1 "$C9/.worktree-repos")" == "# project=demo issue=owner/pkg_a#9 layer=l1" ]]; echo $?)" \
    "$(head -qn1 "$C/.worktree-repos" "$C2/.worktree-repos" "$C9/.worktree-repos")"
# C stands in for a worktree made before base= existed (pull request 445's
# worktrees): its header loses the field, and case 13 records it on resume.
strip_base() {  # <worktree>: the header without base=
    local m="$1/.worktree-repos"
    { head -n1 "$m" | sed 's/ base=[^ ]*//'; tail -n +2 "$m"; } > "$m.new" && mv "$m.new" "$m"
}
strip_base "$C"

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
# Every gh call (not only `repo view`) the dispatcher makes in this case,
# counted around each dispatcher call alone, so a gh call by setup
# (worktree_create.sh) is not mixed in.
# dp3 runs in a command substitution, so it records each call's count in
# a file rather than a variable.
: > "$SANDBOX/gh_by_dp"
dp3() {  # as dp, also appending the number of gh lines this call logged
    local n0 res
    n0=$(wc -l < "$GH_LOG")
    res=$(dp "$@")
    echo $(( $(wc -l < "$GH_LOG") - n0 )) >> "$SANDBOX/gh_by_dp"
    printf '%s\n' "$res"
}
out=$(dp3 "$WS" where --issue 7 --type workspace)
check "workspace issue: where prints its worktree" "$([[ "$out" == "$WW"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(dp3 "$WS" --issue 7 --skill implement --type workspace)
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
# worktree_create.sh asks origin whether the branch exists before it starts
# one (issue 323), so origin must answer: serve it like pkg_a and pkg_b.
git init -q --bare "$REM/owner/solo.git"
git -C "$SOLO" push -q origin main
echo "solo single_project $SOLO" >> "$WS/.agent/projects.local"
(cd "$SOLO" && "$S/worktree_create.sh" --issue 7 --type project --project solo) > "$SANDBOX/create.log" 2>&1 \
    || { cat "$SANDBOX/create.log"; fail "setup: single-repository project worktree"; }
SW="$SOLO/worktrees/issue-solo-7"
check "single-repository project worktree: no .worktree-repos written" "$([[ -d "$SW" && ! -e "$SW/.worktree-repos" ]]; echo $?)"
out=$(dp3 "$SOLO" where --issue 7 --type project --project solo)
check "single-repository project issue: where prints its worktree" "$([[ "$out" == "$SW"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(cd "$SW" && checkpoint_entry | "$S/progress_append.sh" 7 2>&1); rc=$?
check "single-repository project issue: progress_append.sh commits in its worktree" \
    "$([[ "$rc" -eq 0 && "$(git -C "$SW" log -1 --format=%s)" == "progress: checkpoint for #7" ]]; echo $?)" "$out"
# A legacy one-entry "." manifest still means the worktree itself.
printf '# project=solo issue=7 layer=\n%s\t.\tfeature/issue-7\n' "$SOLO" > "$SW/.worktree-repos"
out=$(dp3 "$SOLO" where --issue 7 --type project --project solo)
check "a legacy one-entry '.' manifest maps to the worktree itself" "$([[ "$out" == "$SW"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(cd "$SW" && entry Checkpoint '**Decided-by**: owner' '**After**: plan' '**Decision**: revise' | "$S/progress_append.sh" 7 2>&1); rc=$?
check "... and the guard lets that worktree commit" "$([[ "$rc" -eq 0 ]]; echo $?)" "$out"
rm -f "$SW/.worktree-repos"
ndp=$(wc -l < "$SANDBOX/gh_by_dp")
ngh=$(awk '{ n += $1 } END { print n + 0 }' "$SANDBOX/gh_by_dp")
check "workspace and single-repository issues: the $ndp dispatcher calls asked gh nothing at all" \
    "$([[ "$ndp" -eq 4 && "$ngh" -eq 0 ]]; echo $?)" "calls=$ndp gh_lines=$ngh"

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
printf '#!/usr/bin/env bash\nexit 0\n' > "$STUB/gh"
out=$(dp "$H" where --issue 'owner/pkg_a#7' --type project)
check "a gh that succeeds with no answer refuses too" \
    "$([[ "$out" == *"could not ask gh"*"gh gave no answer"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
mv "$STUB/gh.off" "$STUB/gh"
# A notice on stderr from a gh that answers is not part of the answer.
mv "$STUB/gh" "$STUB/gh.real"
printf '#!/usr/bin/env bash\necho "A new release of gh is available" >&2\nexec "%s" "$@"\n' "$STUB/gh.real" > "$STUB/gh"; chmod +x "$STUB/gh"
out=$(dp "$H" where --issue 'owner/pkg_a#7' --type project)
check "a stderr notice from a gh that answers: where still prints A" "$([[ "$out" == "$A"$'\n'"rc=0" ]]; echo $?)" "$out"
mv "$STUB/gh.real" "$STUB/gh"

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
# Every label between `case "$SUB" in` and its `esac` counts, however the
# row is written; the help and catch-all rows are the only ones that are no
# subcommand. The labels must also be exactly the subcommands the usage
# text names, so a row this parse misreads fails one of the two.
table=$(awk '/^case "\$SUB" in$/ { on = 1; next } on && /^esac$/ { exit } on' "$S/review_progress.sh")
subs=""
unparsed=""
while IFS= read -r row; do
    [[ -z "${row//[[:space:]]/}" ]] && continue
    if [[ "$row" =~ ^[[:space:]]*([^\)[:space:]]+)\) ]]; then
        label="${BASH_REMATCH[1]}"
        case "$label" in
            '-h|--help|help'|'*') ;;
            *) subs+="$label"$'\n' ;;
        esac
    else
        unparsed+="$row"$'\n'
    fi
done <<< "$table"
usage_subs=$("$S/review_progress.sh" 2>&1 | sed -n 's/^  review_progress\.sh \([a-z-]*\) .*/\1/p' | sort -u)
check "review_progress.sh's dispatch table: every row has a label" "$([[ -n "$table" && -z "$unparsed" ]]; echo $?)" "unparsed: $unparsed"
check "the table's labels are exactly the subcommands its usage text names" \
    "$([[ -n "$usage_subs" && "$(sort <<< "${subs%$'\n'}")" == "$usage_subs" ]]; echo $?)" "table: $subs usage: $usage_subs"
check "review_progress.sh's dispatch table lists the seven known subcommands" \
    "$([[ "$(sort <<< "${subs%$'\n'}" | tr '\n' ' ')" == "check findings persist plan-sha round sources verdict " ]]; echo $?)" "$subs"
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
# issue-7 timeline (no manifest there), go through as before. `check` is a
# write (issue 437): A, on feature/issue-7, ticks its box; the main checkout,
# on its default branch, is refused and its timeline left unchanged.
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
    sum_before=$(md5sum < "$P/progress.md")
    out=$(cd "$dir" && "$S/review_progress.sh" check --progress "$P/progress.md" --index 0 2>&1); rc=$?
    if [[ "$where_" == A ]]; then
        check "check from A ticks its own box" "$([[ "$rc" -eq 0 && "$out" == "- [x] (must-fix) open finding"* ]]; echo $?)" "$out"
    else
        check "check from WS (main checkout, default branch) is refused and ticks nothing" \
            "$([[ "$rc" -eq 4 && "$out" == *"refusing to write issue #7's records"* && "$(md5sum < "$P/progress.md")" == "$sum_before" ]]; echo $?)" "$out"
    fi
    git -C "$dir" checkout -q -- .agent/work-plans/issue-7/progress.md
done

# ------------------------------------------------------------------ case 9
# run-issue's own blocks that use `where` fail closed (pre-push review round
# 1, must-fix 2): each block is taken from the SKILL.md copied into the
# sandbox, its placeholders filled, and run from the session root H. When
# `where` refuses (a bare number that two repositories share) or gh fails,
# every block prints STOP, exits non-zero, and neither moves nor counts nor
# touches anything. A package issue with no timeline yet counts 0 and
# --check-exit reports MISSING, never OK.
echo "TEST: run-issue's where blocks stop when where refuses or gh fails; check-exit never OKs a missing timeline"
mkdir -p "$HOME/.claude"
printf '%s\n' "$WS" > "$HOME/.claude/agent-workspace-root"
create --issue owner/pkg_a#8 --type project --project demo --layer l1 --package-repos pkg_a \
    || { cat "$SANDBOX/create.log"; fail "setup: package worktree owner/pkg_a#8"; }
A8="$H/worktrees/issue-demo-owner-pkg_a-8/l1_ws/src/pkg_a"
BLOCKS="$SANDBOX/where_blocks"
mkdir -p "$BLOCKS"
python3 - "$WS/.claude/skills/run-issue/SKILL.md" "$BLOCKS" >/dev/null <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = [b for b in re.findall(r"```bash\n(.*?)```", text, re.S) if "dispatch_phase.sh where" in b]
for i, b in enumerate(blocks, 1):
    open("%s/%d.sh" % (sys.argv[2], i), "w", encoding="utf-8").write(b)
print(len(blocks))
PY
nblocks=$(find "$BLOCKS" -name '*.sh' | wc -l)
check "SKILL.md has three blocks that use where (step 1, step 4, step 6)" "$([[ "$nblocks" -eq 3 ]]; echo $?)" "n=$nblocks"
run_block() {  # <block-file> <ref> -- prints the block's output, then rc= and cwd=
    local body
    body=$(sed -e "s|<ref>|$2|g" -e 's| \[--project <project>\]||g' -e 's|<type>|project|g' -e 's|<N>|7|g' \
        -e 's|<entry-type>|Issue Review|g' -e 's|<i>|0|g' -e "s|<the owner's reason, from the checkpoint entry's own text>|why|g" "$1")
    (cd "$H" && bash -c "$body"$'\n''echo "cwd=$PWD"' 2>&1; echo "rc=$?")
}
before=$(heads)
for b in "$BLOCKS"/*.sh; do
    out=$(run_block "$b" 7)
    check "block $(basename "$b" .sh) with a refused where (bare 7): STOP, non-zero, nothing run after" \
        "$([[ "$out" == *"STOP: dispatch_phase.sh where refused"* && "$out" != *"rc=0" && "$out" != *"cwd="* \
              && "$out" != *"BEFORE="* && "$out" != *'"source"'* ]]; echo $?)" "$out"
done
mv "$STUB/gh" "$STUB/gh.off"
printf '#!/usr/bin/env bash\necho "gh: not logged in" >&2\nexit 4\n' > "$STUB/gh"; chmod +x "$STUB/gh"
for b in "$BLOCKS"/*.sh; do
    out=$(run_block "$b" 'owner/pkg_a#7')
    check "block $(basename "$b" .sh) with a failing gh: STOP, non-zero, nothing run after" \
        "$([[ "$out" == *"not logged in"* && "$out" == *"STOP: dispatch_phase.sh where refused"* && "$out" != *"rc=0" \
              && "$out" != *"cwd="* && "$out" != *"BEFORE="* && "$out" != *'"source"'* ]]; echo $?)" "$out"
done
mv "$STUB/gh.off" "$STUB/gh"
after=$(heads)
check "the stopped blocks changed nothing" "$([[ "$before" == "$after" ]]; echo $?)" "$(diff <(echo "$before") <(echo "$after"))"

out=$(run_block "$BLOCKS/1.sh" 'owner/pkg_a#7')
check "step 1's block with where answering: moves into A" "$([[ "$out" == *"cwd=$A"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(sed -e 's|<ref>|owner/pkg_a#8|g' -e 's| \[--project <project>\]||g' -e 's|<type>|project|g' -e 's|<N>|8|g' \
    -e 's|<entry-type>|Issue Review|g' "$BLOCKS/2.sh" | (cd "$H" && bash 2>&1); echo "rc=$?")
check "step 4's block for a package issue with no timeline yet: BEFORE=0" "$([[ "$out" == *"BEFORE=0"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(dp "$H" --check-exit --issue 'owner/pkg_a#8' --skill review-issue --type project --before 0)
check "check-exit on that missing timeline: MISSING, not OK" "$([[ "$out" == "status=MISSING"$'\n'"rc=0" ]]; echo $?)" "$out"
check "... and A8 has no timeline (so nothing was counted elsewhere)" "$([[ ! -e "$A8/.agent/work-plans/issue-8/progress.md" ]]; echo $?)"

# ----------------------------------------------------------------- case 10
# Pre-push review round 2. (1) The gate matches the records shape on the
# path as given as well as on where it resolves, so a sibling's records
# folder that is a symlink out of the records shape, and a relative path,
# are refused, with or without GNU `realpath -m`. (2) Only a current folder
# that shares the path's repository speaks for it: from inside a package
# checkout, a workspace issue's timeline reads and writes as before.
echo "TEST: symlinked and relative records paths are refused; a workspace timeline works from inside a package checkout"
OUT_DIR="$SANDBOX/outside_records"
mkdir -p "$OUT_DIR"
cp "$B/.agent/work-plans/issue-7/progress.md" "$OUT_DIR/progress.md"
{ echo; review_entry feature/pkg_a-issue-7; } >> "$OUT_DIR/progress.md"
b_before=$(git -C "$B" rev-parse HEAD)
mv "$B/.agent/work-plans/issue-7" "$SANDBOX/b_issue7_real"
ln -s "$OUT_DIR" "$B/.agent/work-plans/issue-7"
out_sum=$(md5sum < "$OUT_DIR/progress.md")
SL="$B/.agent/work-plans/issue-7/progress.md"
for where_ in B A; do
    dir="${!where_}"
    out=$(cd "$dir" && "$S/review_progress.sh" findings --progress "$SL" 2>&1); rc=$?
    check "symlinked records folder in B, findings from $where_: refused, naming A" "$([[ "$rc" -eq 4 && "$out" == *"records go in $A"* ]]; echo $?)" "$out"
    out=$(cd "$dir" && "$S/review_progress.sh" check --progress "$SL" --index 0 2>&1); rc=$?
    check "symlinked records folder in B, check from $where_: refused" "$([[ "$rc" -eq 4 && "$out" == *"records go in $A"* ]]; echo $?)" "$out"
done
out=$(cd "$B" && checkpoint_entry | "$S/progress_append.sh" 7 2>&1); rc=$?
check "symlinked records folder in B, progress_append.sh from B: refused" "$([[ "$rc" -eq 4 ]]; echo $?)" "$out"
check "the symlink's target and B are unchanged" \
    "$([[ "$(md5sum < "$OUT_DIR/progress.md")" == "$out_sum" && "$(git -C "$B" rev-parse HEAD)" == "$b_before" ]]; echo $?)"
rm "$B/.agent/work-plans/issue-7"
mv "$SANDBOX/b_issue7_real" "$B/.agent/work-plans/issue-7"
check "B restored (status clean)" "$([[ -z "$(git -C "$B" status --porcelain)" ]]; echo $?)" "$(git -C "$B" status --porcelain)"

# A realpath that refuses -m (BSD, macOS) changes nothing: the gate uses none.
mkdir -p "$SANDBOX/nogrealpath"
printf '#!/usr/bin/env bash\necho "realpath: illegal option" >&2\nexit 1\n' > "$SANDBOX/nogrealpath/realpath"
chmod +x "$SANDBOX/nogrealpath/realpath"
for rp in gnu stub; do
    pre=""
    [[ "$rp" == stub ]] && pre="$SANDBOX/nogrealpath:"
    out=$(cd "$B" && PATH="$pre$PATH" "$S/review_progress.sh" findings --progress .agent/work-plans/issue-7/progress.md 2>&1); rc=$?
    check "relative path from B ($rp realpath): findings refused" "$([[ "$rc" -eq 4 && "$out" == *"records go in $A"* ]]; echo $?)" "$out"
    out=$(cd "$B" && PATH="$pre$PATH" "$S/review_progress.sh" check --progress ./.agent/work-plans/issue-7/progress.md --index 0 2>&1); rc=$?
    check "relative path from B ($rp realpath): check refused" "$([[ "$rc" -eq 4 ]]; echo $?)" "$out"
    out=$(cd "$A" && PATH="$pre$PATH" "$S/review_progress.sh" findings --progress .agent/work-plans/issue-7/progress.md 2>&1); rc=$?
    check "relative path from A ($rp realpath): findings reads A's timeline" "$([[ "$rc" -eq 0 && "$out" == *'"source"'* ]]; echo $?)" "$out"
done
check "B unchanged by the relative-path attempts" "$([[ -z "$(git -C "$B" status --porcelain)" && "$(git -C "$B" rev-parse HEAD)" == "$b_before" ]]; echo $?)"

# A workspace issue's timeline, from inside the package checkout A, works
# exactly as from its own worktree WW.
{ echo; review_entry feature/issue-7; } >> "$WW/.agent/work-plans/issue-7/progress.md"
git -C "$WW" add .agent/work-plans/issue-7 && git -C "$WW" commit -q -m "workspace issue 7 review"
WP="$WW/.agent/work-plans/issue-7"
for c in "findings --progress $WP/progress.md" "round --progress $WP/progress.md --branch feature/issue-7" \
         "sources --progress $WP/progress.md --head 1234567 --reviews $SANDBOX/reviews.json"; do
    # shellcheck disable=SC2086
    own=$(cd "$WW" && "$S/review_progress.sh" $c 2>&1); rc_own=$?
    # shellcheck disable=SC2086
    out=$(cd "$A" && "$S/review_progress.sh" $c 2>&1); rc=$?
    check "workspace timeline from A: ${c%% *} gives what it gives from WW (rc $rc_own)" \
        "$([[ "$rc" -eq "$rc_own" && "$rc" -eq 0 && "$out" == "$own" ]]; echo $?)" "rc=$rc out=$out"
done
out=$(cd "$A" && "$S/review_progress.sh" check --progress "$WP/progress.md" --index 0 2>&1); rc=$?
check "workspace timeline from A: check ticks WW's box" "$([[ "$rc" -eq 0 && "$out" == "- [x]"* ]]; echo $?)" "$out"
git -C "$WW" checkout -q -- .agent/work-plans/issue-7/progress.md
ww_before=$(git -C "$WW" rev-parse HEAD)
out=$(cd "$A" && checkpoint_entry | "$S/progress_append.sh" -C "$WW" 7 2>&1); rc=$?
check "workspace timeline from A: progress_append.sh -C WW commits in WW" \
    "$([[ "$rc" -eq 0 && "$(git -C "$WW" rev-parse HEAD)" != "$ww_before" ]]; echo $?)" "$out"
out=$(cd "$A" && export WORK_PLANS_DIR_OVERRIDE="$WP" && source "$S/_resolve_work_plans_dir.sh" && resolve_work_plans_dir 7 2>&1); rc=$?
check "workspace timeline from A: the resolver's override passes" "$([[ "$rc" -eq 0 && "$out" == "$WP" ]]; echo $?)" "$out"
out=$(cd "$A" && "$S/dispatch_phase.sh" next --progress "$WP/progress.md" --pr none 2>&1); rc=$?
check "workspace timeline from A: next --progress reads it" "$([[ "$rc" -eq 0 && "$out" == "action="* ]]; echo $?)" "$out"

# ----------------------------------------------------------------- case 11
# The base branch (issue 429, pull request 2a): `dispatch_phase.sh base`
# before the worktree exists reads the owning repository's pin through
# the adapter's repo_pin, for every kind of pin the sandbox's real .repos
# file can hold. pkg_a's origin has main, a branch `pinned` one commit
# ahead of it, and a tag v1.
echo "TEST: base before creation: the pin of the owning repository, every kind"
PIN_SEED="$SANDBOX/pin_seed"
git clone -q "git@github.com:owner/pkg_a.git" "$PIN_SEED"
git -C "$PIN_SEED" checkout -q -b pinned
git -C "$PIN_SEED" commit -q --allow-empty -m "pinned work"
git -C "$PIN_SEED" push -q origin pinned
git -C "$PIN_SEED" tag v1
git -C "$PIN_SEED" push -q origin v1
PINNED_SHA=$(git -C "$PIN_SEED" rev-parse pinned)
PKG_A_HOSTED="$H/layers/main/l1_ws/src/pkg_a"
# The hosted checkout's own `pinned` carries a commit origin never got.
git -C "$PKG_A_HOSTED" branch pinned main
git -C "$PKG_A_HOSTED" checkout -q pinned
git -C "$PKG_A_HOSTED" commit -q --allow-empty -m "unpushed local work on pinned"
git -C "$PKG_A_HOSTED" checkout -q main
LOCAL_PINNED=$(git -C "$PKG_A_HOSTED" rev-parse pinned)
pin_a() {  # <version line value, or "" for no version: key>
    local v=""
    [[ -n "$1" ]] && v="    version: $1\n"
    printf "repositories:\n  pkg_a:\n    type: git\n    url: file:///x/pkg_a.git\n${v}  pkg_b:\n    type: git\n    url: file:///x/pkg_b.git\n    version: main\n" > "$M/repos/l1.repos"
}
PRE=(--type project --layer l1 --package-repos "pkg_a,pkg_b")
pin_a pinned
out=$(dp "$H" base --issue 'owner/pkg_a#11' "${PRE[@]}")
check "pin at a branch: base=pinned" "$([[ "$out" == "base=pinned"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(dp "$H" base --issue 'owner/pkg_a#11' "${PRE[@]}" --base main)
check "--base overrides the pin" "$([[ "$out" == "base=main"$'\n'"rc=0" ]]; echo $?)" "$out"
for kind in "v1 tag" "$PINNED_SHA commit"; do
    ref="${kind% *}"; k="${kind#* }"
    pin_a "$ref"
    out=$(dp "$H" base --issue 'owner/pkg_a#11' "${PRE[@]}")
    check "pin at a $k: refused, naming it and --base" \
        "$([[ "$out" == *"error: pkg_a is pinned at $ref ($k); only a branch can be a base. Pass --base <branch>."* \
              && "$out" != *"base="* && "$out" == *"rc=2" ]]; echo $?)" "$out"
done
# A pin of kind unknown says why the kind is not known, each cause as it is.
pin_a nosuch
out=$(dp "$H" base --issue 'owner/pkg_a#11' "${PRE[@]}")
check "pin unknown, origin answered: origin has no branch or tag of that name" \
    "$([[ "$out" == *"error: pkg_a is pinned at nosuch, and origin, asked, has no branch or tag of that name (and it is no commit id), so it is no base. Pass --base <branch>, or fix the pin."* \
          && "$out" != *"(unknown)"* && "$out" != *"base="* && "$out" == *"rc=2" ]]; echo $?)" "$out"
printf '#!/usr/bin/env bash\necho "ssh: connect to host github.com: Network is unreachable" >&2\nexit 255\n' > "$STUB/deadssh"
chmod +x "$STUB/deadssh"
out=$(GIT_SSH_COMMAND="$STUB/deadssh" dp "$H" base --issue 'owner/pkg_a#11' "${PRE[@]}")
check "pin unknown, origin not answering: the kind could not be established; retry or --base" \
    "$([[ "$out" == *"(unverified)"* && "$out" == *"error: pkg_a is pinned at nosuch, and whether that is a branch could not be established: origin was not asked or did not answer"*"Retry when origin answers, or pass --base <branch>."* \
          && "$out" != *"base="* && "$out" == *"rc=2" ]]; echo $?)" "$out"
pin_a "'bad..name'"
out=$(dp "$H" base --issue 'owner/pkg_a#11' "${PRE[@]}")
check "pin unknown, a name no branch can have: said so" \
    "$([[ "$out" == *"error: pkg_a is pinned at bad..name, which no branch can be named (and it is no commit id), so it is no base."* \
          && "$out" != *"base="* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" base --issue 'owner/pkg_a#11' "${PRE[@]}" --base pinned)
check "a pin that is no branch, with --base: the override is the base" "$([[ "$out" == "base=pinned"$'\n'"rc=0" ]]; echo $?)" "$out"
pin_a ""
out=$(dp "$H" base --issue 'owner/pkg_a#11' "${PRE[@]}")
check "no version: key: the adapter's own refusal, then no base guessed" \
    "$([[ "$out" == *"'pkg_a' has no version: key in layer 'l1'"* && "$out" == *"there is no base; none is guessed"* \
          && "$out" != *"base="* && "$out" == *"rc=2" ]]; echo $?)" "$out"
pin_a pinned
out=$(dp "$H" base --issue 'owner/pkg_a#11' --type project --layer l1 --package-repos pkg_b)
check "--package-repos without the owning repository: refused" \
    "$([[ "$out" == *"0 of --package-repos pkg_b would be on feature/issue-11"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" base --issue 'owner/pkg_a#11' --type project)
check "a qualified ref with no worktree and no --layer: refused, not 'no base'" \
    "$([[ "$out" == *"has no worktree yet, and without --layer and --package-repos"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" base --issue 'owner/pkg_a#11' "${PRE[@]}" --base 'bad..name')
check "an invalid --base: refused" "$([[ "$out" == *"--base 'bad..name' is not a valid branch name"* && "$out" == *"rc=2" ]]; echo $?)" "$out"

# The repository whose pin is read is the owning entry's directory, not the
# forge name: directory pkg_c, forge repository owner/forge_c.
git init -q --bare "$REM/owner/forge_c.git"
git clone -q "git@github.com:owner/forge_c.git" "$SANDBOX/seed_c" 2>/dev/null
git -C "$SANDBOX/seed_c" commit -q --allow-empty -m init
git -C "$SANDBOX/seed_c" push -q origin HEAD:main HEAD:cbranch
rm -rf "$SANDBOX/seed_c"
git clone -q "git@github.com:owner/forge_c.git" "$H/layers/main/l1_ws/src/pkg_c"
printf '  pkg_c:\n    type: git\n    url: file:///x/forge_c.git\n    version: cbranch\n' >> "$M/repos/l1.repos"
out=$(dp "$H" base --issue 'owner/forge_c#12' --type project --layer l1 --package-repos pkg_c)
check "the pin is read under the owning entry's directory name (pkg_c), not the forge name (forge_c)" \
    "$([[ "$out" == "base=cbranch"$'\n'"rc=0" ]]; echo $?)" "$out"

# ----------------------------------------------------------------- case 12
echo "TEST: creation with --base: the owning branch starts from origin's base, the header records it"
create --issue owner/pkg_a#11 --type project --project demo --layer l1 --package-repos pkg_a,pkg_b --base pinned \
    || { cat "$SANDBOX/create.log"; fail "setup: package worktree owner/pkg_a#11 with --base pinned"; }
C11="$H/worktrees/issue-demo-owner-pkg_a-11"
A11="$C11/l1_ws/src/pkg_a"
B11="$C11/l1_ws/src/pkg_b"
check "header: base=pinned after layer=" \
    "$([[ "$(head -n1 "$C11/.worktree-repos")" == "# project=demo issue=owner/pkg_a#11 layer=l1 base=pinned" ]]; echo $?)" "$(head -n1 "$C11/.worktree-repos")"
check "A's feature/issue-11 is origin's pinned, without the hosted checkout's unpushed commit, untracked" \
    "$([[ "$(git -C "$A11" rev-parse HEAD)" == "$PINNED_SHA" ]] && ! git -C "$A11" merge-base --is-ancestor "$LOCAL_PINNED" HEAD \
        && ! git -C "$A11" config branch.feature/issue-11.remote >/dev/null; echo $?)"
check "the sibling B starts from its own origin's main, as before" \
    "$([[ "$(git -C "$B11" rev-parse HEAD)" == "$(git -C "$REM/owner/pkg_b.git" rev-parse main)" ]]; echo $?)"
out=$(dp "$H" base --issue 'owner/pkg_a#11' --type project)
check "base after creation: the recorded base" "$([[ "$out" == "base=pinned"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(dp "$H" base --issue 11 --type project)
check "a bare number that resolves to the package worktree: its base, not 'no base'" \
    "$([[ "$out" == "base=pinned"$'\n'"rc=0" ]]; echo $?)" "$out"
pin_a main
out=$(dp "$H" base --issue 'owner/pkg_a#11' --type project)
check "the recorded base wins over a pin changed since" "$([[ "$out" == "base=pinned"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(dp "$H" base --issue 'owner/pkg_a#11' --type project --base main)
check "a --base that differs from the recorded base: refused" \
    "$([[ "$out" == *"records base=pinned for pkg_a"*"--base main differs"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" --issue 'owner/pkg_a#11' --skill implement --type project)
check "handoff: base= after package_worktree=" \
    "$([[ "$out" == *"worktree=$A11"$'\n'"package_worktree=$C11"$'\n'"base=pinned"$'\n'"task="* ]]; echo $?)" "$out"
out=$(dp "$H" --issue 'owner/pkg_a#7' --skill implement --type project)
check "handoff for a package worktree with no recorded base: no base= line" \
    "$([[ "$out" == *"package_worktree=$C"$'\n'"task="* && "$out" != *$'\n'"base="* ]]; echo $?)" "$out"

# Publish: run-issue step 7's own block, from the SKILL.md copy, in A.
PUB=$(python3 - "$WS/.claude/skills/run-issue/SKILL.md" <<'PY2'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = [b for b in re.findall(r"```bash\n(.*?)```", text, re.S) if "gh_create_pr.sh" in b and "git push" in b]
print(blocks[0] if len(blocks) == 1 else "")
PY2
)
check "SKILL.md has one publish block, and it passes --base <base> for a package issue" \
    "$([[ "$PUB" == *"[-R <owner/repo> --base <base>]"* ]]; echo $?)" "$PUB"
PUB="${PUB//\[-R <owner\/repo> --base <base>\]/-R owner/pkg_a --base pinned}"
PUB="${PUB//<title>/Fix the thing}"
gh_before=$(wc -l < "$GH_LOG")
out=$(cd "$A11" && AGENT_MODEL=m bash -c "$PUB" 2>&1); rc=$?
created=$(tail -n +"$((gh_before + 1))" "$GH_LOG" | grep '^pr create ')
check "publish: gh pr create --repo owner/pkg_a --base pinned (gh_create_pr.sh spells -R as --repo), from A" \
    "$([[ "$rc" -eq 0 && "$created" == "pr create --repo owner/pkg_a --base pinned "*"| cwd=$A11" ]]; echo $?)" "rc=$rc created=$created out=$out"

# A base origin lacks stops creation and rolls back the sibling already added.
create --issue owner/pkg_a#13 --type project --project demo --layer l1 --package-repos pkg_b,pkg_a --base nosuch; rc=$?
check "creation with a base origin lacks: refused, the sibling added first rolled back, no worktree" \
    "$([[ "$rc" -ne 0 && ! -e "$H/worktrees/issue-demo-owner-pkg_a-13" ]] \
        && ! git -C "$PKG_B_HOSTED" show-ref --verify --quiet refs/heads/feature/pkg_a-issue-13 \
        && ! git -C "$PKG_A_HOSTED" show-ref --verify --quiet refs/heads/feature/issue-13 \
        && grep -q "origin does not have it" "$SANDBOX/create.log"; echo $?)" "$(cat "$SANDBOX/create.log")"

# ----------------------------------------------------------------- case 13
# A worktree made before base= existed (C, owner/pkg_a#7, made in setup with
# no --base): `base` records the base on resume, only after origin confirms
# it, and writes nothing otherwise.
echo "TEST: resume of a worktree with no recorded base"
hdr_before=$(cat "$C/.worktree-repos")
out=$(dp "$H" base --issue 'owner/pkg_a#7' --type project --base nosuch)
check "--base origin lacks: refused, nothing recorded" \
    "$([[ "$out" == *"origin of $A has no branch 'nosuch'"*"nothing was recorded"* && "$out" == *"rc=2" \
          && "$(cat "$C/.worktree-repos")" == "$hdr_before" ]]; echo $?)" "$out"
pin_a v1
out=$(dp "$H" base --issue 'owner/pkg_a#7' --type project)
check "a pin that is a tag: refused, nothing recorded" \
    "$([[ "$out" == *"pkg_a is pinned at v1 (tag)"* && "$out" == *"rc=2" && "$(cat "$C/.worktree-repos")" == "$hdr_before" ]]; echo $?)" "$out"
pin_a pinned
GOOD_SSH="$GIT_SSH_COMMAND"
out=$(GIT_SSH_COMMAND="$STUB/deadssh" dp "$H" base --issue 'owner/pkg_a#7' --type project --base pinned)
check "origin unreachable: the origin check fails, nothing recorded" \
    "$([[ "$out" == *"could not check whether feature/issue-7 in $A started from origin's 'pinned'"*"Network is unreachable"* \
          && "$out" == *"nothing was recorded"* && "$out" == *"rc=2" && "$(cat "$C/.worktree-repos")" == "$hdr_before" ]]; echo $?)" "$out"
export GIT_SSH_COMMAND="$GOOD_SSH"
out=$(dp "$H" base --issue 'owner/pkg_a#7' --type project)
check "origin has the pinned branch: base=pinned, and the header now records it, entries unchanged" \
    "$([[ "$out" == *"recorded base=pinned in $C/.worktree-repos"* && "$out" == *"base=pinned"$'\n'"rc=0" \
          && "$(head -n1 "$C/.worktree-repos")" == "$(head -n1 <<< "$hdr_before") base=pinned" \
          && "$(tail -n +2 "$C/.worktree-repos")" == "$(tail -n +2 <<< "$hdr_before")" ]]; echo $?)" "$out"
out=$(dp "$H" base --issue 'owner/pkg_a#7' --type project --base main)
check "after that, a different --base is refused" "$([[ "$out" == *"records base=pinned"* && "$out" == *"rc=2" ]]; echo $?)" "$out"
# That record is right: A started from origin's main before pinned, and
# main is an ancestor of pinned, so A carries no commit pinned lacks that
# another origin branch has.

# The reported case: a worktree made from origin's main after main moved
# past the pin (one commit pinned lacks), header without base=, the pin a
# branch. The resume refuses, naming the commit's count and its branch,
# and writes nothing; with the --base it really started from, it records.
git -C "$PIN_SEED" checkout -q main
git -C "$PIN_SEED" pull -q origin main
git -C "$PIN_SEED" commit -q --allow-empty -m "main moves past pinned"
git -C "$PIN_SEED" push -q origin main
create --issue owner/pkg_a#14 --type project --project demo --layer l1 --package-repos pkg_a,pkg_b --base main \
    || { cat "$SANDBOX/create.log"; fail "setup: package worktree owner/pkg_a#14 with --base main"; }
C14="$H/worktrees/issue-demo-owner-pkg_a-14"
A14="$C14/l1_ws/src/pkg_a"
git -C "$A14" commit -q --allow-empty -m "own work on 14"
git -C "$A14" push -q origin feature/issue-14
# Its header as a legacy layout writes it (project=project, finding 3 of the
# review): base passes the adapter no unregistered project name.
{ printf '# project=project issue=owner/pkg_a#14 layer=l1\n'; tail -n +2 "$C14/.worktree-repos"; } > "$C14/hdr.new" && mv "$C14/hdr.new" "$C14/.worktree-repos"
hdr14=$(cat "$C14/.worktree-repos")
out=$(dp "$H" base --issue 'owner/pkg_a#14' --type project)
check "started from main, pin pinned: refused, naming 1 commit from origin's main and how to proceed; nothing recorded" \
    "$([[ "$out" == *"error: base: feature/issue-14 in $A14 carries 1 commit(s) that origin's 'pinned' does not have and origin's main (1) has: it did not start from 'pinned'"* \
          && "$out" == *"Recreate the worktree"*"or pass the --base it was started from."* \
          && "$out" != *"not registered"* && "$out" == *"rc=2" && "$(cat "$C14/.worktree-repos")" == "$hdr14" ]]; echo $?)" "$out"
check "the check leaves no refs behind in A14's repository" \
    "$([[ -z "$(git -C "$A14" for-each-ref refs/wt-base-check/)" ]]; echo $?)"
out=$(dp "$H" base --issue 'owner/pkg_a#14' --type project --base main)
check "the same with the --base it started from (its own commits pushed to origin): recorded" \
    "$([[ "$out" == *"base=main"$'\n'"rc=0" && "$(head -n1 "$C14/.worktree-repos")" == "# project=project issue=owner/pkg_a#14 layer=l1 base=main" ]]; echo $?)" "$out"

# --package-repos on an existing package worktree must be the set it was
# made with (C11: pkg_a,pkg_b); a --layer, the header's layer.
out=$(dp "$H" base --issue 'owner/pkg_a#11' --type project --layer l1 --package-repos pkg_b,pkg_a)
check "--package-repos naming the manifest's repositories, in another order: the recorded base" \
    "$([[ "$out" == "base=pinned"$'\n'"rc=0" ]]; echo $?)" "$out"
out=$(dp "$H" base --issue 'owner/pkg_a#11' --type project --layer l1 --package-repos pkg_a)
check "--package-repos that differs from the manifest: refused, naming both" \
    "$([[ "$out" == *"was made with the repositories pkg_a,pkg_b, not --package-repos pkg_a"* && "$out" != *"base="* && "$out" == *"rc=2" ]]; echo $?)" "$out"
out=$(dp "$H" where --issue 'owner/pkg_a#7' --type project)
check "where still prints A with base= in the header" "$([[ "$out" == "$A"$'\n'"rc=0" ]]; echo $?)" "$out"

# Workspace and single-repository issues have no package base.
out=$(dp "$WS" base --issue 7 --type workspace)
check "workspace issue: base prints nothing, exit 0" "$([[ "$out" == $'\n'"rc=0" ]]; echo $?)" "$out"
out=$(dp "$SOLO" base --issue 7 --type project --project solo)
check "single-repository project issue: base prints nothing, exit 0" "$([[ "$out" == $'\n'"rc=0" ]]; echo $?)" "$out"
out=$(dp "$SOLO" base --issue 7 --type project --project solo --base main)
check "single-repository project issue with --base: refused" \
    "$([[ "$out" == *"no package worktree"* && "$out" == *"rc=2" ]]; echo $?)" "$out"

echo
echo "test_package_issue_loop: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
