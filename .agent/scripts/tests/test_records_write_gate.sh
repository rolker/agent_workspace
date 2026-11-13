#!/usr/bin/env bash
# .agent/scripts/tests/test_records_write_gate.sh
# The records gate's write rule (issue 437): a call that changes a timeline
# (records_path --write <file> in _resolve_work_plans_dir.sh) goes through
# only when the file, every symlink resolved, sits at the place its path
# names in the issue's own checkout: not on its default branch; on
# feature/issue-<N>, where the branch alone decides; or, for a detached
# HEAD or another branch name, in a folder issue-*-<N>. Reads are never
# refused by it.
#
# Synthetic and offline: a workspace repository made from this tree's
# scripts with linked worktrees made by `git worktree add`, a package
# repository cloned under a project folder outside any worktree, and a
# single-repository project with one issue worktree. Every refusal asserts
# exit 4, the message, and that no checkout's HEAD, status or timeline
# files changed.
#
# The last part is a static test over .agent/scripts/*.sh: every script
# that commits a work-plans path calls records_path --write, and those
# scripts are exactly progress_append.sh
# and review_progress.sh. How it finds a committing writer is pinned in
# the comment above find_writers, and a planted writer proves it.
#
# scans: .agent/scripts/
#
# Run: bash .agent/scripts/tests/test_records_write_gate.sh

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

SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$SANDBOX"' EXIT

unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT
export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig" GIT_CONFIG_NOSYSTEM=1
printf '[init]\n\tdefaultBranch = main\n[user]\n\tname = t\n\temail = t@t\n' > "$GIT_CONFIG_GLOBAL"
export AGENT_NAME="Test Agent" AGENT_EMAIL="t@example.com"
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# The workspace: this tree's scripts, committed on main, with issue 7's
# timeline on main (an open review finding, so a `check` that got through
# would tick it) and the plan it cites.
WS="$SANDBOX/ws"
S="$WS/.agent/scripts"
mkdir -p "$WS/.agent"
cp -r "$REAL_AGENT/scripts" "$S"
rm -rf "$S/tests"
printf 'worktrees/\n' > "$WS/.gitignore"
entry() {  # <type> [extra field lines...]
    local t="$1"; shift
    printf '## %s\n**Status**: complete\n**When**: 2026-11-10 10:00 -05:00\n**By**: t (m)\n' "$t"
    local l
    for l in "$@"; do printf '%s\n' "$l"; done
}
review_entry() {
    entry 'Local Review (Pre-Push)' '**Verdict**: changes-requested' '**Branch**: feature/issue-7 at `1234567`' '' '### Findings' \
        '- [ ] (must-fix) open finding — `x.sh:1`'
}
mkdir -p "$WS/.agent/work-plans/issue-7"
{ printf -- '---\nissue: 7\n---\n\n# Issue #7 — seven\n\n'; review_entry; } > "$WS/.agent/work-plans/issue-7/progress.md"
printf '# plan\n' > "$WS/.agent/work-plans/issue-7/plan.md"
git -C "$WS" init -q
git -C "$WS" add -A
git -C "$WS" commit -q -m init

wt() {  # <folder> <start point, or ""> <git worktree add options...>: a linked worktree of WS
    local d="$WS/worktrees/workspace/$1" start="$2"; shift 2
    git -C "$WS" worktree add -q "$@" "$d" ${start:+"$start"} >/dev/null 2>&1 \
        || { echo "setup failed: worktree $d ($*)"; exit 1; }
}
wt issue-workspace-7 "" -b feature/issue-7
wt issue-workspace-17 "" -b feature/issue-17
wt issue-workspace-8 feature/issue-7 -b feature/issue-8     # a sub-issue of 7 (--parent-issue)
wt issue-workspace-20 "" -b feature/issue-21                    # folder and branch disagree
wt issue-workspace-30 "" --detach                               # detached, folder names 30
wt other-30 "" --detach                                         # detached, folder names nothing
wt issue-workspace-40 "" -b wip/fortyish                        # custom branch, folder names 40
wt skill-research "" -b skill/research-20261110-000000          # a skill worktree
W7="$WS/worktrees/workspace/issue-workspace-7"
W17="$WS/worktrees/workspace/issue-workspace-17"
W8="$WS/worktrees/workspace/issue-workspace-8"
W20="$WS/worktrees/workspace/issue-workspace-20"
W30="$WS/worktrees/workspace/issue-workspace-30"
O30="$WS/worktrees/workspace/other-30"
W40="$WS/worktrees/workspace/issue-workspace-40"
WSK="$WS/worktrees/workspace/skill-research"

# A package repository cloned under a project folder, outside any worktree
# (no .worktree-repos manifest): its clone has origin/HEAD -> main.
git init -q --bare "$SANDBOX/remotes/pkg_a.git"
seed="$SANDBOX/seed"
git init -q "$seed"
echo pkg_a > "$seed/README.md"
git -C "$seed" add -A && git -C "$seed" commit -q -m init
git -C "$seed" push -q "$SANDBOX/remotes/pkg_a.git" main
PKG="$SANDBOX/proj/layers/main/l1_ws/src/pkg_a"
git clone -q "$SANDBOX/remotes/pkg_a.git" "$PKG"

# A single-repository project with an issue 5 worktree.
PJ="$SANDBOX/pj"
git init -q "$PJ"
echo pj > "$PJ/README.md"
git -C "$PJ" add -A && git -C "$PJ" commit -q -m init
PJW="$SANDBOX/pj-worktrees/issue-pj-5"
git -C "$PJ" worktree add -q -b feature/issue-5 "$PJW" >/dev/null 2>&1 || { echo "setup failed: $PJW"; exit 1; }

ALL_CHECKOUTS=("$WS" "$W7" "$W17" "$W8" "$W20" "$W30" "$O30" "$W40" "$WSK" "$PKG" "$PJ" "$PJW")
EXTRA_WATCH=()  # more files whose content state() reports (a symlink's target)
state() {  # every checkout's HEAD, status, and the content of every timeline file
    local d f
    for d in "${ALL_CHECKOUTS[@]}"; do
        printf '%s %s [%s]\n' "$d" "$(git -C "$d" rev-parse HEAD)" "$(git -C "$d" status --porcelain | tr '\n' ' ')"
        if [[ -d "$d/.agent/work-plans" ]]; then
            while IFS= read -r f; do
                printf '  %s %s\n' "$f" "$(md5sum < "$f")"
            done < <(find "$d/.agent/work-plans" -type f | sort)
        fi
    done
    for f in "${EXTRA_WATCH[@]}"; do
        printf '  %s %s\n' "$f" "$(md5sum < "$f" 2>/dev/null || echo absent)"
    done
}
ckpt() {  # a Checkpoint entry, different on every call (an identical tail is a no-op)
    entry Checkpoint '**Decided-by**: owner' '**After**: plan' '**Decision**: proceed' '' "call $BASHPID-$RANDOM"
}

# refused <label> <cwd> <want-text> <command...>: runs the command (stdin
# from ckpt) in <cwd>; asserts exit 4, <want-text> in the output and no
# change to any checkout.
refused() {
    local label="$1" cwd="$2" want="$3"; shift 3
    local before after out rc
    before=$(state)
    out=$(cd "$cwd" && ckpt | "$@" 2>&1); rc=$?
    after=$(state)
    check "$label: refused (exit 4) naming the way out, nothing written or committed anywhere" \
        "$([[ "$rc" -eq 4 && "$out" == *"refusing to write issue #"*"Reads are not refused"* && "$out" == *"$want"* && "$before" == "$after" ]]; echo $?)" \
        "rc=$rc out=$out$(diff <(echo "$before") <(echo "$after"))"
}
# allowed <label> <checkout> <issue> <cwd> <command...>: asserts exit 0 and
# exactly one new commit, in <checkout>, touching only issue <issue>'s
# timeline; no other checkout's HEAD moves.
allowed() {
    local label="$1" co="$2" n="$3" cwd="$4"; shift 4
    local before out rc others_before others_after d
    before=$(git -C "$co" rev-parse HEAD)
    others_before=$(for d in "${ALL_CHECKOUTS[@]}"; do [[ "$d" == "$co" ]] || git -C "$d" rev-parse HEAD; done)
    out=$(cd "$cwd" && ckpt | "$@" 2>&1); rc=$?
    others_after=$(for d in "${ALL_CHECKOUTS[@]}"; do [[ "$d" == "$co" ]] || git -C "$d" rev-parse HEAD; done)
    check "$label: committed in its own checkout only" \
        "$([[ "$rc" -eq 0 && "$(git -C "$co" rev-list --count "$before"..HEAD)" == 1 \
              && "$(git -C "$co" show --name-only --format= HEAD)" == ".agent/work-plans/issue-$n/progress.md" \
              && "$others_before" == "$others_after" ]]; echo $?)" "rc=$rc out=$out"
}

# ------------------------------------------------------------------ case 1
echo "TEST: the workspace main checkout (on main) is refused for every writer"
refused "progress_append.sh 7 from the main checkout" "$WS" "The issue's worktree is $W7" \
    "$S/progress_append.sh" 7
refused "persist (compatibility mode) from the main checkout" "$WS" "cd $W7" \
    "$S/review_progress.sh" persist --issue 7
out=$(cd "$WS" && ckpt | "$S/review_progress.sh" persist --issue 7 --strict 2>&1); rc=$?
check "persist --strict from the main checkout: refused by the resolver (exit 4)" \
    "$([[ "$rc" -eq 4 && "$out" == *"outside its worktree"* ]]; echo $?)" "rc=$rc out=$out"
# With WORKTREE_ISSUE=7 the resolver lets the main checkout through (rule 2
# trusts the variable); progress_append.sh's refusal then stays exit 4.
refused "persist --strict with WORKTREE_ISSUE=7 from the main checkout" "$WS" "progress_append.sh refused" \
    env WORKTREE_ISSUE=7 "$S/review_progress.sh" persist --issue 7 --strict
refused "progress_append.sh -C <main checkout> from inside the issue's worktree" "$W7" "it is on its default branch 'main'" \
    "$S/progress_append.sh" -C "$WS" 7
# A first entry for an issue with no worktree names the creating command.
refused "progress_append.sh 99 from the main checkout (no worktree for 99)" "$WS" \
    "worktree_create.sh --issue 99 --type workspace" "$S/progress_append.sh" 99
check "no issue-99 records folder was made" "$([[ ! -e "$WS/.agent/work-plans/issue-99" ]]; echo $?)"
before=$(state)
out=$(cd "$WS" && "$S/review_progress.sh" check --progress "$WS/.agent/work-plans/issue-7/progress.md" --index 0 2>&1); rc=$?
check "check from the main checkout on its own timeline: refused (exit 4), the box stays open" \
    "$([[ "$rc" -eq 4 && "$out" == *"refusing to write issue #7"* && "$before" == "$(state)" ]]; echo $?)" "rc=$rc out=$out"
out=$(cd "$W7" && "$S/review_progress.sh" check --progress "$WS/.agent/work-plans/issue-7/progress.md" --index 0 2>&1); rc=$?
check "check on the main checkout's timeline from inside the issue's worktree: refused (the target decides)" \
    "$([[ "$rc" -eq 4 && "$before" == "$(state)" ]]; echo $?)" "rc=$rc out=$out"

# ------------------------------------------------------------------ case 2
echo "TEST: a package checkout cloned under a project folder, outside any worktree, is refused"
refused "progress_append.sh 7 from the package clone (on main)" "$PKG" "--type project" \
    "$S/progress_append.sh" 7
refused "persist from the package clone" "$PKG" "<owner>/<repo>#7" \
    "$S/review_progress.sh" persist --issue 7
check "the clone has no records folder" "$([[ ! -e "$PKG/.agent" ]]; echo $?)"

# ------------------------------------------------------------------ case 3
echo "TEST: another issue's worktree is refused; the branch decides over the folder"
refused "issue 7 from issue 17's worktree" "$W17" "is issue #17's" "$S/progress_append.sh" 7
refused "issue 17 from issue 7's worktree" "$W7" "is issue #7's" "$S/progress_append.sh" 17
refused "issue 1 from issue 17's worktree (no suffix match)" "$W17" "is issue #17's" "$S/progress_append.sh" 1
refused "issue 20 from folder issue-workspace-20 on branch feature/issue-21" "$W20" "is issue #21's" \
    "$S/progress_append.sh" 20
refused "persist issue 20 in the same folder" "$W20" "is issue #21's" "$S/review_progress.sh" persist --issue 20
out=$(cd "$W20" && source "$S/_resolve_work_plans_dir.sh" && resolve_work_plans_dir 20 2>&1); rc=$?
check "the resolver's rule 2b agrees: issue 20 in that folder is refused" "$([[ "$rc" -eq 1 ]]; echo $?)" "$out"
refused "issue 7 from the sub-issue worktree of 8 (its parent's number)" "$W8" "is issue #8's" \
    "$S/progress_append.sh" 7
refused "a skill worktree given an issue number" "$WSK" "skill/research-20261110-000000" \
    "$S/progress_append.sh" 50
refused "a detached HEAD in a folder not named for the issue" "$O30" "detached HEAD" \
    "$S/progress_append.sh" 30

# ------------------------------------------------------------------ case 4
echo "TEST: the issue's own checkout, wherever the command runs from, is allowed"
allowed "progress_append.sh 7 in issue 7's worktree" "$W7" 7 "$W7" "$S/progress_append.sh" 7
allowed "the merge script's write: progress_append.sh -C <the issue's worktree> from the main checkout" \
    "$W7" 7 "$WS" "$S/progress_append.sh" -C "$W7" 7
allowed "persist (compatibility mode) in issue 7's worktree" "$W7" 7 "$W7" "$S/review_progress.sh" persist --issue 7
allowed "persist --strict in issue 7's worktree" "$W7" 7 "$W7" "$S/review_progress.sh" persist --issue 7 --strict
allowed "a sub-issue worktree for its own number" "$W8" 8 "$W8" "$S/progress_append.sh" 8
allowed "a detached HEAD in folder issue-workspace-30" "$W30" 30 "$W30" "$S/progress_append.sh" 30
allowed "a custom branch in folder issue-workspace-40" "$W40" 40 "$W40" "$S/progress_append.sh" 40
out=$(cd "$W7" && "$S/review_progress.sh" check --progress "$W7/.agent/work-plans/issue-7/progress.md" --index 0 2>&1); rc=$?
check "check in issue 7's worktree ticks its box" "$([[ "$rc" -eq 0 && "$out" == "- [x] (must-fix) open finding"* ]]; echo $?)" "$out"
git -C "$W7" checkout -q -- .agent/work-plans/issue-7/progress.md
# The "would have aborted" notice survives only where the resolver refuses
# and the checkout is the issue's: here WORKTREE_ISSUE names another issue.
before=$(git -C "$W7" rev-parse HEAD)
out=$(cd "$W7" && ckpt | WORKTREE_ISSUE=99 "$S/review_progress.sh" persist --issue 7 2>&1); rc=$?
check "persist (compatibility) in issue 7's worktree with WORKTREE_ISSUE=99: the notice, then the commit" \
    "$([[ "$rc" -eq 0 && "$out" == *"would have aborted"* && "$(git -C "$W7" rev-list --count "$before"..HEAD)" == 1 ]]; echo $?)" "rc=$rc out=$out"

# ------------------------------------------------------------------ case 5
echo "TEST: a single-repository project issue: refused on main, allowed in its worktree"
refused "progress_append.sh 5 from the project's main checkout" "$PJ" "The issue's worktree is $PJW" \
    "$S/progress_append.sh" 5
allowed "progress_append.sh 5 in the project's issue worktree" "$PJW" 5 "$PJW" "$S/progress_append.sh" 5
allowed "progress_append.sh -C <the project's issue worktree> from the workspace main checkout" \
    "$PJW" 5 "$WS" "$S/progress_append.sh" -C "$PJW" 5

# ------------------------------------------------------------------ case 6
echo "TEST: symlinks: the write gate judges the file's fully resolved physical path"
# One rule covers every shape: the file that will be written, every symlink
# in its path and the file itself resolved, must sit at the place its path
# names in the issue's own checkout. Each shape below is W17 writing issue
# 17's timeline from W17 (its own checkout), so only the link refuses it.
# Main-checkout targets: a records folder and a plain folder.
M17="$WS/.agent/work-plans/issue-17"
mkdir -p "$M17" "$WS/notes"
printf -- '---\nissue: 17\n---\n\n# Issue #17\n' > "$M17/progress.md"
cp "$M17/progress.md" "$WS/notes/progress.md"
mkdir -p "$W17/.agent/work-plans"
R17="$W17/.agent/work-plans/issue-17"
EXTRA_WATCH=("$M17/progress.md" "$WS/notes/progress.md")
unlink_all() { rm -rf "$R17" "$SANDBOX/hop.md"; }
# both writers, from W17, refused with <want> in the message
both_refused() {  # <shape> <want>
    refused "progress_append.sh 17, $1" "$W17" "$2" "$S/progress_append.sh" 17
    refused "persist (compatibility mode) 17, $1" "$W17" "$2" "$S/review_progress.sh" persist --issue 17
}
mkdir -p "$R17"
ln -s "$M17/progress.md" "$R17/progress.md"
both_refused "progress.md a symlink to the main checkout's" "in $WS: it is on its default branch"
unlink_all
ln -s "$M17" "$R17"
both_refused "the records folder a symlink to the main checkout's issue-17 folder" "in $WS: it is on its default branch"
unlink_all
ln -s "$WS/notes" "$R17"
both_refused "the records folder a symlink to a main-checkout folder not named for the issue" \
    "in $WS: it is on its default branch"
unlink_all
mkdir -p "$R17"
ln -s "$M17/progress.md" "$SANDBOX/hop.md"
ln -s "$SANDBOX/hop.md" "$R17/progress.md"
both_refused "progress.md a chain of two symlinks ending in the main checkout" "in $WS: it is on its default branch"
unlink_all
# Inside the issue's own checkout, a link still puts the write and the
# commit in different places (git would commit the link, not the entry).
mkdir -p "$R17"
printf -- '---\nissue: 17\n---\n\n# Issue #17\n' > "$R17/real.md"
EXTRA_WATCH+=("$R17/real.md")
ln -s real.md "$R17/progress.md"
both_refused "progress.md a symlink to another file in its own records folder" "not to the place it names"
EXTRA_WATCH=("$M17/progress.md" "$WS/notes/progress.md")
unlink_all
mkdir -p "$R17"
ln -s missing.md "$R17/progress.md"
before=$(state)
for cmd in "$S/progress_append.sh 17" "$S/review_progress.sh persist --issue 17"; do
    out=$(cd "$W17" && ckpt | $cmd 2>&1); rc=$?
    check "${cmd##*/}, progress.md a dangling symlink: refused as unresolvable, nothing created" \
        "$([[ "$rc" -eq 4 && "$out" == *"cannot be resolved"* && ! -e "$R17/missing.md" && "$before" == "$(state)" ]]; echo $?)" \
        "rc=$rc out=$out"
done
unlink_all
rm -rf "$M17" "$WS/notes"
EXTRA_WATCH=()
allowed "the plain case: progress_append.sh 17 in W17, no symlink" "$W17" 17 "$W17" "$S/progress_append.sh" 17
allowed "the plain case: persist (compatibility mode) 17 in W17" "$W17" 17 "$W17" "$S/review_progress.sh" persist --issue 17

# ------------------------------------------------------------------ case 6b
echo "TEST: spellings: the named path and the resolved path are compared, not their text"
P7W="$W7/.agent/work-plans/issue-7"
gate() {  # <cwd> <path>: records_path --write, prints "rc=<n> <output>"
    local o r
    o=$(cd "$1" && source "$S/_resolve_work_plans_dir.sh" && records_path --write "$2" 2>&1); r=$?
    printf 'rc=%s %s' "$r" "$o"
}
for spelling in "$P7W/./progress.md" "$P7W//progress.md" "$P7W/../issue-7/progress.md" \
    "./.agent/work-plans/issue-7/./progress.md"; do
    out=$(gate "$W7" "$spelling")
    check "records_path --write $spelling (issue 7's own file): allowed" "$([[ "$out" == "rc=0 "* ]]; echo $?)" "$out"
done
out=$(gate "$P7W" progress.md)
check "a bare progress.md from inside issue 7's records folder: allowed" "$([[ "$out" == "rc=0 "* ]]; echo $?)" "$out"
out=$(gate "$P7W" ../issue-7/progress.md)
check "../issue-7/progress.md from inside the folder (a .. landing on the same file): allowed" \
    "$([[ "$out" == "rc=0 "* ]]; echo $?)" "$out"
before=$(git -C "$W7" rev-parse HEAD)
out=$(cd "$W7" && "$S/review_progress.sh" check --progress "$P7W/"/progress.md --index 0 2>&1); rc=$?
check "check --progress with a trailing slash on the folder ticks the box" \
    "$([[ "$rc" -eq 0 && "$out" == "- [x] (must-fix) open finding"* ]]; echo $?)" "rc=$rc out=$out"
git -C "$W7" checkout -q -- .agent/work-plans/issue-7/progress.md
# A worktree reached through a linked parent folder, and -C through that
# link from the main checkout (the shape merge_pr.sh uses), still pass.
ln -s "$WS/worktrees" "$SANDBOX/wtlink"
out=$(gate "$WS" "$SANDBOX/wtlink/workspace/issue-workspace-7/.agent/work-plans/issue-7/progress.md")
check "issue 7's file through a linked parent folder of its worktree: allowed" "$([[ "$out" == "rc=0 "* ]]; echo $?)" "$out"
allowed "progress_append.sh -C <the worktree through a linked parent> from the main checkout" \
    "$W7" 7 "$WS" "$S/progress_append.sh" -C "$SANDBOX/wtlink/workspace/issue-workspace-7" 7
rm "$SANDBOX/wtlink"
# A bare progress.md linked to another file in the same records folder is
# refused, though its path names no records folder. (W17's committed
# progress.md, from the plain case above, is set aside meanwhile.)
mv "$R17/progress.md" "$SANDBOX/progress17.keep"
{ printf -- '---\nissue: 17\n---\n\n# Issue #17\n\n'; review_entry; } > "$R17/real.md"
ln -s real.md "$R17/progress.md"
before=$(md5sum < "$R17/real.md")
out=$(cd "$R17" && "$S/review_progress.sh" check --progress progress.md --index 0 2>&1); rc=$?
check "check --progress progress.md inside the folder, linked to real.md there: refused, real.md unchanged" \
    "$([[ "$rc" -eq 4 && "$out" == *"not to the place it names"* && "$before" == "$(md5sum < "$R17/real.md")" ]]; echo $?)" \
    "rc=$rc out=$out"
rm "$R17/progress.md" "$R17/real.md"
mv "$SANDBOX/progress17.keep" "$R17/progress.md"

# ------------------------------------------------------------------ case 7
echo "TEST: reads from the main checkout are not refused"
P7="$W7/.agent/work-plans/issue-7"
before=$(state)
out=$(cd "$WS" && "$S/review_progress.sh" round --progress "$P7/progress.md" --branch feature/issue-7 2>&1); rc=$?
check "round --progress <the issue's timeline> from the main checkout" "$([[ "$rc" -eq 0 && "$out" == round=* ]]; echo $?)" "$out"
out=$(cd "$WS" && "$S/review_progress.sh" round --issue 7 --branch feature/issue-7 2>&1); rc=$?
check "round --issue 7 from the main checkout (its own timeline)" "$([[ "$rc" -eq 0 && "$out" == round=* ]]; echo $?)" "$out"
printf '{"reviews": [], "comments": []}\n' > "$SANDBOX/reviews.json"
out=$(cd "$WS" && "$S/review_progress.sh" sources --progress "$P7/progress.md" --head 1234567 --reviews "$SANDBOX/reviews.json" 2>&1); rc=$?
check "sources --progress from the main checkout" "$([[ "$rc" -eq 0 ]]; echo $?)" "$out"
out=$(cd "$WS" && "$S/review_progress.sh" findings --progress "$WS/.agent/work-plans/issue-7/progress.md" 2>&1); rc=$?
check "findings on the main checkout's own timeline" "$([[ "$rc" -eq 0 && "$out" == *'"index": 0'* ]]; echo $?)" "$out"
out=$(cd "$WS" && "$S/review_progress.sh" plan-sha --plan "$P7/plan.md" 2>&1); rc=$?
check "plan-sha --plan <the issue's plan> from the main checkout" "$([[ "$rc" -eq 0 && -n "$out" ]]; echo $?)" "$out"
out=$(cd "$WS" && "$S/dispatch_phase.sh" next --progress "$P7/progress.md" --pr none 2>&1); rc=$?
check "dispatch_phase.sh next --progress from the main checkout" "$([[ "$rc" -eq 0 && "$out" == action=* ]]; echo $?)" "$out"
out=$(cd "$WS" && source "$S/_resolve_work_plans_dir.sh" && records_path "$WS/.agent/work-plans/issue-7/progress.md" 2>&1); rc=$?
check "records_path without --write on the main checkout's timeline passes" "$([[ "$rc" -eq 0 ]]; echo $?)" "$out"
check "the reads changed nothing" "$([[ "$before" == "$(state)" ]]; echo $?)"

# ------------------------------------------------------------------ case 8
# The static test. find_writers <dir> prints "<script>\t<0|1>" for every
# committing writer of a work-plans path among <dir>/*.sh, 1 when the script
# calls records_path --write on a non-comment line.
# A script is a committing writer when, after joining backslash-continued
# lines and dropping comment lines (first non-blank character #):
#   - it runs `git [<options>] commit` (options: -C <arg>, -c <arg>, a
#     quoted "${array[@]}" expansion, --flag / -f[=value]; so a
#     `rev-parse "...^{commit}"` is no commit), and
#   - a `git [<options>] commit` or `git [<options>] add` in it names a
#     work-plans path in its pathspec (the words after ` -- `, or with no
#     ` -- ` every word after the subcommand, its options and their
#     arguments included, up to the end of the command): a literal
#     containing `.agent/work-plans`, or $VAR / ${VAR} where the script
#     assigns VAR (NAME=..., local or not) a value containing
#     `.agent/work-plans`.
# Out of reach, by design: a pathspec built at run time with no literal
# `.agent/work-plans` in the script (a new writer goes through
# progress_append.sh, ADR-0013).
echo "TEST: every script that commits a work-plans path states --write (static)"
find_writers() {
    python3 - "$1" <<'PY'
import glob, os, re, sys
WP = ".agent/work-plans"
GIT = re.compile(r'\bgit((?:\s+-[Cc]\s+\S+|\s+"\$\{[^}]*\}"|\s+--?[A-Za-z][\w-]*(?:=\S+)?)*)\s+(commit|add)\b(.*)')
ASSIGN = re.compile(r'(?:^|[\s;(])([A-Za-z_][A-Za-z0-9_]*)=("[^"]*"|\'[^\']*\'|\S*)')
VAR = re.compile(r'\$\{?([A-Za-z_][A-Za-z0-9_]*)')
WRITE = re.compile(r'\brecords_path\s+--write\b')
for path in sorted(glob.glob(os.path.join(sys.argv[1], "*.sh"))):
    text = open(path, encoding="utf-8", errors="replace").read().replace("\\\n", " ")
    lines = [l for l in text.split("\n") if not l.lstrip().startswith("#")]
    wpvars = {m.group(1) for l in lines for m in ASSIGN.finditer(l) if WP in m.group(2)}
    commits = names_wp = False
    for l in lines:
        for m in GIT.finditer(l):
            if m.group(2) == "commit":
                commits = True
            rest = m.group(3) + " "
            if " -- " in rest:
                rest = rest.split(" -- ", 1)[1]
            spec = re.split(r";|&&|\|\||\)|\bthen\b", rest)[0]
            if WP in spec or any(v in wpvars for v in VAR.findall(spec)):
                names_wp = True
    if commits and names_wp:
        write = any(WRITE.search(l) for l in lines)
        print("%s\t%d" % (os.path.basename(path), 1 if write else 0))
PY
}
real=$(find_writers "$REAL_AGENT/scripts")
check "the committing writers are exactly progress_append.sh and review_progress.sh" \
    "$([[ "$(cut -f1 <<< "$real" | tr '\n' ' ')" == "progress_append.sh review_progress.sh " ]]; echo $?)" "$real"
check "each of them states --write" "$([[ -n "$real" && "$(cut -f2 <<< "$real" | sort -u)" == 1 ]]; echo $?)" "$real"

# The detector on planted scripts: it must catch a writer without the flag
# (a variable pathspec on a continued line; a staged path committed without
# a pathspec; a pathspec with no ` -- `), count one with the flag, and pass
# by reads and ^{commit}.
PL="$SANDBOX/planted"
mkdir -p "$PL"
cat > "$PL/rogue.sh" <<'EOF'
#!/bin/bash
REL=".agent/work-plans/issue-$1/progress.md"
echo x >> "$REL"
git -C "$ROOT" -c user.name=x "${ident[@]}" \
    commit -q -m "progress: x" -- "$REL"
EOF
cat > "$PL/rogue_add.sh" <<'EOF'
#!/bin/bash
git add -- ".agent/work-plans/issue-$1/progress.md"
git commit -m "progress: x"
EOF
cat > "$PL/rogue_nodash.sh" <<'EOF'
#!/bin/bash
REL=".agent/work-plans/issue-$1/progress.md"
git add "$REL"
git commit -m x "$REL"
EOF
cat > "$PL/flagged.sh" <<'EOF'
#!/bin/bash
source _resolve_work_plans_dir.sh
file_rel=".agent/work-plans/issue-$1/progress.md"
records_path --write "$file_rel" >/dev/null || exit 4
git commit -m x -- "$file_rel"
EOF
cat > "$PL/reader.sh" <<'EOF'
#!/bin/bash
P=".agent/work-plans/issue-$1/progress.md"
git -C "$top" rev-parse --verify -q "${ref}^{commit}" -- "$P"
git log -1 --format=%h -- "$P"
# git commit -m x -- "$P"   (a comment is not a commit)
EOF
planted=$(find_writers "$PL")
check "the detector catches the planted writers and only them" \
    "$([[ "$planted" == $'flagged.sh\t1\nrogue.sh\t0\nrogue_add.sh\t0\nrogue_nodash.sh\t0' ]]; echo $?)" "$planted"

echo
echo "test_records_write_gate: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
