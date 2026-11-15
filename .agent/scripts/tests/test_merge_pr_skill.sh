#!/usr/bin/env bash
# .agent/scripts/tests/test_merge_pr_skill.sh
# Tests for merge_pr.sh on skill-branch pull requests (issue 478) and for
# the remote-branch delete every PR now shares (delete_remote_branch):
#   - a workspace skill PR (research) merges with a report-only gate (owner's
#     G1): roadmap no-op line, `## Merge (report-only)` record posted on the
#     PR with "skill pull request: no issue timeline", nothing committed or
#     pushed on the skill branch, no progress.md written; a second run with
#     the record on the PR records nothing new; worktree, local and remote
#     branch removed, main synced
#   - a decision summary on the PR still leaves condition (a) unmet
#   - --force-unreviewed on a skill PR records `## Merge (unreviewed)`
#   - two worktrees of the same skill: only the PR's branch worktree goes
#   - a project-repo skill PR (onboard-project): project worktree removed,
#     project synced
#   - a branch that is neither an issue nor a skill branch is refused
#   - remote delete: a refused delete names the branch and ends "cleanup
#     incomplete" (exit 0, merged); an already-gone branch is no warning
#   - a project checkout with no `origin` is refused early
#   - worktree_remove.sh --path refuses a main checkout, a sub-folder, a
#     package worktree's entry and a worktree of another repository than
#     --type names
# Everything runs in sandboxes (mktemp) with the real scripts copied in; gh
# is a fixture stub (no network): `pr view` answers from files, `pr comment`
# appends to comments_posted.md, every call is logged.
# Run: bash .agent/scripts/tests/test_merge_pr_skill.sh

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
# One sandbox for the whole run, created at top level so the trap fires
# (issue #297); helpers carve per-test directories out of it.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export AGENT_NAME="Test Agent"
export AGENT_EMAIL="test+agent@example.com"
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT

HEAD_SHA="abc1234abc1234abc1234abc1234abc1234abc12"
PR=81
SKILL_BR="skill/research-20261115-101010-123456789"

write_gh_stub() {
    cat > "$1/stubbin/gh" <<'EOF'
#!/usr/bin/env bash
: "${GH_FIXTURES_DIR:?}"
printf '%s\n' "$*" >> "${GH_CALL_LOG:-/dev/null}"
sanitize() { printf '%s' "$1" | tr '/' '_'; }
if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    num="$3"; shift 3; repo=""; jf=""
    while [ $# -gt 0 ]; do
        case "$1" in -R) repo="$2"; shift 2 ;; --json) jf="$2"; shift 2 ;; *) shift ;; esac
    done
    if [ "$jf" = "mergeable,mergeStateStatus" ]; then
        echo '{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN"}'; exit 0
    fi
    f="$GH_FIXTURES_DIR/pr_view_$(sanitize "$repo")_${num}.json"
    [ -f "$f" ] && { cat "$f"; exit 0; }
    echo "GraphQL: Could not resolve to a PullRequest with the number of '$num'." >&2
    exit 1
elif [ "$1" = "pr" ] && [ "$2" = "merge" ]; then
    exit "${GH_MERGE_EXIT:-0}"
elif [ "$1" = "pr" ] && [ "$2" = "comment" ]; then
    shift 3; body=""
    while [ $# -gt 0 ]; do case "$1" in --body-file) body="$2"; shift 2 ;; *) shift ;; esac; done
    [ -n "$body" ] && cat "$body" >> "$GH_FIXTURES_DIR/comments_posted.md"
    exit 0
elif [ "$1" = "pr" ] && [ "$2" = "list" ]; then echo 0; exit 0
else exit 1; fi
EOF
    chmod +x "$1/stubbin/gh"
}

# <dir> <name>: a repo at <dir> on main with a bare origin "<dir>.<name>.git"
make_repo_with_origin() {
    local dir="$1" bare="$1.$2.git"
    mkdir -p "$dir"
    git -C "$dir" init --quiet -b main
    git -C "$dir" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
    git init --bare --quiet "$bare"; git -C "$bare" symbolic-ref HEAD refs/heads/main
    git -C "$dir" remote add origin "$bare"
    git -C "$dir" push --quiet -u origin main
}

# A workspace sandbox ($sb is ROOT_DIR) with the real scripts and gh stub.
make_sandbox() {
    local sb f
    sb="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$sb/.agent/scripts" "$sb/stubbin" "$sb/gh_fixtures"
    for f in _bookkeeping.sh merge_pr.sh worktree_remove.sh worktree_list.sh _worktree_helpers.sh _issue_helpers.sh _project_registry.sh _resolve_default_branch.sh progress_read.py progress_append.sh _progress_entry.sh _resolve_work_plans_dir.sh update_roadmap.sh _real_case_path.sh; do
        cp "$REAL_ROOT/.agent/scripts/$f" "$sb/.agent/scripts/"
    done
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"; chmod +x "$sb/stubbin/git-bug"
    write_gh_stub "$sb"
    make_repo_with_origin "$sb" remote
    # The sandbox's own fixtures and logs stay out of its git status.
    printf 'gh_fixtures/\ngh_calls.log\nstubbin/\nworktrees/\n.agent/\nproject/\n' > "$sb/.git/info/exclude"
    echo "$sb"
}

# <sb> <remote> <branch> [comments-json]
write_pr_fixture() {
    printf '{"state":"OPEN","headRefName":"%s","title":"Skill PR","headRefOid":"%s","comments":%s,"body":"## Summary\\n\\nplain","baseRefName":"main"}\n' \
        "$3" "$HEAD_SHA" "${4:-[]}" > "$1/gh_fixtures/pr_view_$(printf '%s' "$2" | tr '/' '_')_${PR}.json"
}

# <repo> <worktree> <branch> [push]: a worktree on a new branch at main
# (same commit as main, so the safe `branch -d` after the stubbed merge works)
add_worktree() {
    mkdir -p "$(dirname "$2")"
    git -C "$1" worktree add --quiet -b "$3" "$2" main >/dev/null 2>&1
    [[ "${4:-}" == push ]] && git -C "$2" push --quiet -u origin "$3"
    return 0
}

run_merge() {  # <sb> [args...]
    local sb="$1"; shift
    (cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" \
        GH_MERGE_EXIT="${GH_MERGE_EXIT:-0}" MERGE_PR_CI_POLL_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=5 \
        "$sb/.agent/scripts/merge_pr.sh" --pr "$PR" --no-wait "$@")
}
has_ref() { git -C "$1" show-ref --verify --quiet "refs/heads/$2"; }
record_count() { grep -c "^## Merge ($2)\$" "$1/gh_fixtures/comments_posted.md" 2>/dev/null || true; }

# ===================================================== workspace skill PR ===
echo "TEST: a workspace skill PR whose merge fails stops after a report-only gate: record on the PR, nothing on the branch"
sb="$(make_sandbox)"
remote="${sb}.remote.git"
wt="$sb/worktrees/workspace/skill-workspace-research-20261115-101010-123456789"
add_worktree "$sb" "$wt" "$SKILL_BR" push
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
before_local=$(git -C "$wt" rev-parse HEAD)
before_remote=$(git -C "$remote" rev-parse "refs/heads/$SKILL_BR")
rc=0; out="$(GH_MERGE_EXIT=1 run_merge "$sb" 2>&1)" || rc=$?
check "banner names the skill" grep -q "Merging PR #$PR (skill research)" <<<"$out"
check "roadmap step is a stated no-op" grep -q "Skill PR — no issue to mark done, skipping roadmap update" <<<"$out"
check "enforce default stays report-only for a skill PR" grep -q "Review gate (report-only: a skill pull request has no issue timeline" <<<"$out"
check "one Merge (report-only) comment posted" test "$(record_count "$sb" report-only)" -eq 1
check "its conditions name the skill reason first" grep -q '^\*\*Conditions\*\*: skill pull request: no issue timeline;no "## Decision summary"' "$sb/gh_fixtures/comments_posted.md"
check "the comment says why it is on the PR" grep -q "a skill pull request has no issue timeline, so its record goes on the PR — Merge (report-only) record posted as a comment" <<<"$out"
check "skill branch HEAD unchanged locally" test "$(git -C "$wt" rev-parse HEAD)" = "$before_local"
check "skill branch unchanged on origin" test "$(git -C "$remote" rev-parse "refs/heads/$SKILL_BR")" = "$before_remote"
check "no progress.md written anywhere" test -z "$(find "$sb" "$wt" -name progress.md 2>/dev/null)"
check "the merge was attempted (gate did not refuse)" grep -q '^pr merge' "$sb/gh_calls.log"

echo "TEST: a second run with the record already on the PR records nothing new"
cp "$sb/gh_fixtures/comments_posted.md" "$SANDBOX/prev_comment.md"
write_pr_fixture "$sb" "$remote" "$SKILL_BR" "$(jq -Rs '[{body: .}]' "$SANDBOX/prev_comment.md")"
: > "$sb/gh_fixtures/comments_posted.md"
rc=0; out="$(run_merge "$sb" 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "duplicate skipped" grep -q "already recorded (as a PR comment), same conditions" <<<"$out"
check "no second comment" test "$(record_count "$sb" report-only)" -eq 0
check "worktree removed" test ! -e "$wt"
check "local skill branch deleted" bash -c "! git -C '$sb' show-ref --verify --quiet 'refs/heads/$SKILL_BR'"
check "remote skill branch deleted" bash -c "! git -C '$remote' show-ref --verify --quiet 'refs/heads/$SKILL_BR'"
check "remote delete reported" grep -q "Remote branch deleted" <<<"$out"
check "main synced" grep -q "Workspace synced" <<<"$out"
check "banner: merged, cleaned up, and synced" grep -q "merged, cleaned up, and synced" <<<"$out"

echo "TEST: a decision summary does not satisfy a skill PR's gate: condition (a) stays unmet"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
add_worktree "$sb" "$sb/worktrees/workspace/skill-a" "$SKILL_BR" push
write_pr_fixture "$sb" "$remote" "$SKILL_BR" '[{"body":"## Decision summary\n\n**What changed**: x"}]'
rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "conditions are the skill reason alone" grep -qx '\*\*Conditions\*\*: skill pull request: no issue timeline' "$sb/gh_fixtures/comments_posted.md"
check "record posted" test "$(record_count "$sb" report-only)" -eq 1

echo "TEST: --force-unreviewed on a skill PR records Merge (unreviewed)"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
add_worktree "$sb" "$sb/worktrees/workspace/skill-a" "$SKILL_BR" push
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
rc=0; out="$(run_merge "$sb" --no-roadmap-update --force-unreviewed 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "bypass banner" grep -q "force-unreviewed: bypassing the review gate" <<<"$out"
check "one Merge (unreviewed) comment" test "$(record_count "$sb" unreviewed)" -eq 1
check "no report-only comment" test "$(record_count "$sb" report-only)" -eq 0

echo "TEST: two worktrees of the same skill: only the PR's branch worktree is removed"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
other_br="skill/research-20261115-121212-987654321"
wt1="$sb/worktrees/workspace/skill-workspace-research-20261115-101010-123456789"
wt2="$sb/worktrees/workspace/skill-workspace-research-20261115-121212-987654321"
add_worktree "$sb" "$wt1" "$SKILL_BR" push
add_worktree "$sb" "$wt2" "$other_br" push
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "the PR's worktree removed" test ! -e "$wt1"
check "the newer worktree of the same skill survives" test -d "$wt2"
check "its branch survives locally" has_ref "$sb" "$other_br"
check "its branch survives on origin" has_ref "$remote" "$other_br"

echo "TEST: a skill PR with no worktree open says so and still deletes its branches"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
add_worktree "$sb" "$sb/worktrees/workspace/skill-a" "$SKILL_BR" push
git -C "$sb" worktree remove "$sb/worktrees/workspace/skill-a"
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "says no worktree" grep -q "No worktree has '$SKILL_BR' checked out — nothing to remove" <<<"$out"
check "remote branch deleted" bash -c "! git -C '$remote' show-ref --verify --quiet 'refs/heads/$SKILL_BR'"

echo "TEST: a skill PR with no worktree, run from another checkout, syncs the workspace root, not the caller's checkout"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
add_worktree "$sb" "$sb/worktrees/workspace/skill-a" "$SKILL_BR" push
git -C "$sb" worktree remove "$sb/worktrees/workspace/skill-a"
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
# A new commit on origin's main, for the workspace root's pull to bring in.
upd="$(mktemp -d -p "$SANDBOX")"
git clone --quiet "$remote" "$upd/c"
git -C "$upd/c" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m upstream
git -C "$upd/c" push --quiet origin main
upstream_sha=$(git -C "$upd/c" rev-parse HEAD)
# The caller's directory: another (issue) worktree whose branch has no
# upstream, where a bare `git pull --ff-only` fails.
elsewhere="$sb/worktrees/workspace/issue-workspace-7"
add_worktree "$sb" "$elsewhere" feature/issue-7
elsewhere_sha=$(git -C "$elsewhere" rev-parse HEAD)
rc=0; out="$(cd "$elsewhere" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" \
    MERGE_PR_CI_POLL_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=5 \
    "$sb/.agent/scripts/merge_pr.sh" --pr "$PR" --no-wait --no-roadmap-update 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "workspace root's main fast-forwarded to origin" test "$(git -C "$sb" rev-parse main)" = "$upstream_sha"
check "the caller's checkout untouched" test "$(git -C "$elsewhere" rev-parse HEAD)" = "$elsewhere_sha"
check "main synced" grep -q "Workspace synced" <<<"$out"

echo "TEST: the main checkout on the skill branch is named as such, never removed, cleanup incomplete"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
git -C "$sb" switch --quiet -c "$SKILL_BR"
git -C "$sb" push --quiet -u origin "$SKILL_BR"
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
check "exit 0 (merged)" test "$rc" -eq 0
check "names the main checkout" grep -q "The main checkout .* has '$SKILL_BR' checked out — it is never removed" <<<"$out"
check "no pull on the merged branch" grep -q "Workspace not synced: its checkout is on '$SKILL_BR'" <<<"$out"
check "no uncommitted-changes hint" bash -c "! grep -q 'check for uncommitted changes' <<<\"\$1\"" _ "$out"
check "banner says cleanup incomplete" grep -q "merged, but cleanup incomplete" <<<"$out"
check "main checkout still there" test -d "$sb/.git"

# ======================================================= project skill PR ===
echo "TEST: a project-repo skill PR (onboard-project) is merged, its project worktree removed, the project synced"
sb="$(make_sandbox)"
make_repo_with_origin "$sb/project" premote
pj_remote="$sb/project.premote.git"
pbr="skill/onboard-project-20261115-090000-1"
pwt="$sb/worktrees/project/proj/skill-proj-onboard-project-20261115-090000-1"
add_worktree "$sb/project" "$pwt" "$pbr" push
write_pr_fixture "$sb" "$pj_remote" "$pbr"
rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "banner names the skill" grep -q "Merging PR #$PR (skill onboard-project)" <<<"$out"
check "record posted on the project PR" test "$(record_count "$sb" report-only)" -eq 1
check "project worktree removed" test ! -e "$pwt"
check "local branch deleted in the project repo" bash -c "! git -C '$sb/project' show-ref --verify --quiet 'refs/heads/$pbr'"
check "remote branch deleted in the project repo" bash -c "! git -C '$pj_remote' show-ref --verify --quiet 'refs/heads/$pbr'"
check "project synced" grep -q "Project synced" <<<"$out"

echo "TEST: a project checkout with no origin is refused early"
sb="$(make_sandbox)"
mkdir -p "$sb/project"; git -C "$sb/project" init --quiet -b main
git -C "$sb/project" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
rc=0; out="$(run_merge "$sb" --type project --no-roadmap-update 2>&1)" || rc=$?
check "exit 1" test "$rc" -eq 1
check "names the missing origin" grep -q "has no 'origin' remote configured" <<<"$out"
check "nothing merged" bash -c "! grep -q '^pr merge' '$sb/gh_calls.log' 2>/dev/null"

# ======================================================== other branches ===
echo "TEST: a branch that is neither an issue nor a skill branch is refused"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
for br in feature/something skill/research skill/research-2026-1010; do
    write_pr_fixture "$sb" "$remote" "$br"
    rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
    check "$br: exit 1" test "$rc" -eq 1
    check "$br: names the skill pattern" grep -q 'skill/<name>-<YYYYMMDD>-<HHMMSS>\[-<n>\] (skill worktree)' <<<"$out"
done
check "nothing merged" bash -c "! grep -q '^pr merge' '$sb/gh_calls.log' 2>/dev/null"

echo "TEST: a skill-shaped branch for a skill not on the allowlist is refused (it would skip the enforced gate)"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
for br in skill/handmade-20261115-101010 skill/research-x-20261115-101010-1; do
    write_pr_fixture "$sb" "$remote" "$br"
    rc=0; out="$(run_merge "$sb" --no-roadmap-update --report-only 2>&1)" || rc=$?
    check "$br: exit 1" test "$rc" -eq 1
    check "$br: not taken as a skill PR" bash -c "! grep -q 'Merging PR' <<<\"\$1\"" _ "$out"
    check "$br: names the allowlist" grep -q "one of the skill worktree allowlist: research inspiration-tracker onboard-project" <<<"$out"
done
check "nothing merged" bash -c "! grep -q '^pr merge' '$sb/gh_calls.log' 2>/dev/null"

echo "TEST: a skill branch in the other repository type, or from a fork, is not merged as a skill PR"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
make_repo_with_origin "$sb/project" premote
pj_remote="$sb/project.premote.git"
write_pr_fixture "$sb" "$remote" "skill/onboard-project-20261115-090000-1"
rc=0; out="$(run_merge "$sb" --type workspace --no-roadmap-update 2>&1)" || rc=$?
check "onboard-project on the workspace: exit 1" test "$rc" -eq 1
check "onboard-project on the workspace: says why" grep -q "'onboard-project' makes project worktrees only" <<<"$out"
write_pr_fixture "$sb" "$pj_remote" "$SKILL_BR"
rc=0; out="$(run_merge "$sb" --type project --no-roadmap-update 2>&1)" || rc=$?
check "research on the project: exit 1" test "$rc" -eq 1
check "research on the project: says why" grep -q "'research' makes workspace worktrees only" <<<"$out"
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
fx="$sb/gh_fixtures/pr_view_$(printf '%s' "$remote" | tr '/' '_')_${PR}.json"
jq -c '. + {isCrossRepository: true}' "$fx" > "$fx.new" && mv "$fx.new" "$fx"
rc=0; out="$(run_merge "$sb" --type workspace --no-roadmap-update 2>&1)" || rc=$?
check "fork skill PR: exit 1" test "$rc" -eq 1
check "fork skill PR: says why" grep -q "is from a fork; a skill pull request is merged only" <<<"$out"
check "nothing merged" bash -c "! grep -q '^pr merge' '$sb/gh_calls.log' 2>/dev/null"

# =================================================== remote branch delete ===
echo "TEST: a refused remote delete names the branch and ends 'cleanup incomplete', merged, exit 0"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
add_worktree "$sb" "$sb/worktrees/workspace/skill-a" "$SKILL_BR" push
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
printf '#!/bin/sh\nwhile read -r old new ref; do\n  case "$new" in 0000000000000000000000000000000000000000) echo "deletes are refused here" >&2; exit 1 ;; esac\ndone\n' > "$remote/hooks/pre-receive"
chmod +x "$remote/hooks/pre-receive"
rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
check "exit 0 (merged)" test "$rc" -eq 0
check "warning names the branch" grep -q "Could not delete remote branch '$SKILL_BR'" <<<"$out"
check "git's own stderr shown" grep -q "deletes are refused here" <<<"$out"
check "banner says cleanup incomplete" grep -q "merged, but cleanup incomplete" <<<"$out"
check "branch still on origin" has_ref "$remote" "$SKILL_BR"

echo "TEST: a remote branch that only tail-matches (x/<branch>) is not taken for the PR's branch"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
add_worktree "$sb" "$sb/worktrees/workspace/skill-a" "$SKILL_BR"
git -C "$sb" push --quiet origin "$SKILL_BR:refs/heads/x/$SKILL_BR"
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "already gone reported" grep -q "Remote branch already gone" <<<"$out"
check "no incomplete banner" bash -c "! grep -q 'cleanup incomplete' <<<\"\$1\"" _ "$out"
check "the other branch untouched" has_ref "$remote" "x/$SKILL_BR"

echo "TEST: a push --delete that finds the ref already gone (auto-delete race) counts as gone"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
add_worktree "$sb" "$sb/worktrees/workspace/skill-a" "$SKILL_BR"
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
# ls-remote answers "present" (rc 0), as it would just before GitHub's
# auto-delete lands; every other git call is the real git.
real_git="$(command -v git)"
printf '#!/usr/bin/env bash\nfor a in "$@"; do [ "$a" = ls-remote ] && exit 0; done\nexec %q "$@"\n' "$real_git" > "$sb/stubbin/git"
chmod +x "$sb/stubbin/git"
rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
rm -f "$sb/stubbin/git"
check "exit 0" test "$rc" -eq 0
check "already gone reported" grep -q "Remote branch already gone" <<<"$out"
check "no warning" bash -c "! grep -q 'Could not delete remote branch' <<<\"\$1\"" _ "$out"
check "no incomplete banner" bash -c "! grep -q 'cleanup incomplete' <<<\"\$1\"" _ "$out"

echo "TEST: a PR from a fork leaves origin's same-named branch alone"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
fork_br="feature/issue-9"
add_worktree "$sb" "$sb/worktrees/workspace/issue-workspace-9" "$fork_br" push
write_pr_fixture "$sb" "$remote" "$fork_br"
fx="$sb/gh_fixtures/pr_view_$(printf '%s' "$remote" | tr '/' '_')_${PR}.json"
jq -c '. + {isCrossRepository: true}' "$fx" > "$fx.new" && mv "$fx.new" "$fx"
rc=0; out="$(run_merge "$sb" --no-roadmap-update --report-only 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "says it is a fork PR" grep -q "Remote branch left alone: PR #$PR is from a fork" <<<"$out"
check "origin's branch survives" has_ref "$remote" "$fork_br"
check "no incomplete banner" bash -c "! grep -q 'cleanup incomplete' <<<\"\$1\"" _ "$out"

echo "TEST: a merged branch with its own commit and no upstream is deleted after main is synced"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
wt="$sb/worktrees/workspace/skill-a"
add_worktree "$sb" "$wt" "$SKILL_BR"
git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m "skill work"
# Pushed without -u, as worktree_create.sh's --no-track branch is: no upstream.
git -C "$wt" push --quiet origin "$SKILL_BR"
check "the branch has no upstream" bash -c "! git -C '$wt' rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1"
git -C "$sb" worktree remove "$wt"
# GitHub's merge (the gh stub merges nothing): a merge commit on origin's main.
upd="$(mktemp -d -p "$SANDBOX")"
git clone --quiet "$remote" "$upd/c"
git -C "$upd/c" -c user.name=t -c user.email=t@t merge --quiet --no-ff -m "Merge PR" "origin/$SKILL_BR"
git -C "$upd/c" push --quiet origin main
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "local branch deleted" bash -c "! git -C '$sb' show-ref --verify --quiet 'refs/heads/$SKILL_BR'"
check "no kept-branch warning" bash -c "! grep -q 'Kept local branch' <<<\"\$1\"" _ "$out"
check "banner: merged, cleaned up, and synced" grep -q "merged, cleaned up, and synced" <<<"$out"

echo "TEST: a local branch git will not delete is reported with git's stderr and ends 'cleanup incomplete'"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
add_worktree "$sb" "$sb/worktrees/workspace/skill-a" "$SKILL_BR" push
git -C "$sb/worktrees/workspace/skill-a" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m unpushed
git -C "$sb" worktree remove "$sb/worktrees/workspace/skill-a"
write_pr_fixture "$sb" "$remote" "$SKILL_BR"
rc=0; out="$(run_merge "$sb" --no-roadmap-update 2>&1)" || rc=$?
check "exit 0 (merged)" test "$rc" -eq 0
check "warning names the kept branch" grep -q "Kept local branch '$SKILL_BR'" <<<"$out"
check "git's own stderr shown" grep -q "not fully merged" <<<"$out"
check "banner says cleanup incomplete" grep -q "merged, but cleanup incomplete" <<<"$out"
check "local branch still there" has_ref "$sb" "$SKILL_BR"

echo "TEST: an issue branch's remote delete uses the same rule: an already-gone branch is no warning"
sb="$(make_sandbox)"; remote="${sb}.remote.git"
add_worktree "$sb" "$sb/worktrees/workspace/issue-workspace-9" feature/issue-9
write_pr_fixture "$sb" "$remote" feature/issue-9
rc=0; out="$(run_merge "$sb" --no-roadmap-update --report-only 2>&1)" || rc=$?
check "exit 0" test "$rc" -eq 0
check "already gone reported" grep -q "Remote branch already gone" <<<"$out"
check "no incomplete banner" bash -c "! grep -q 'cleanup incomplete' <<<\"\$1\"" _ "$out"
check "banner: cleaned up" grep -q "merged, cleaned up, and synced" <<<"$out"

# ================================================= worktree_remove --path ===
echo "TEST: worktree_remove.sh --path refuses a main checkout and a sub-folder of a worktree"
sb="$(make_sandbox)"
add_worktree "$sb" "$sb/worktrees/workspace/skill-a" "$SKILL_BR"
mkdir -p "$sb/worktrees/workspace/skill-a/sub"
rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/worktree_remove.sh" --path "$sb" --type workspace 2>&1)" || rc=$?
check "main checkout: exit 1" test "$rc" -eq 1
check "main checkout: says why" grep -q "is a main checkout, not a linked worktree" <<<"$out"
check "main checkout still there" test -d "$sb/.git"
rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/worktree_remove.sh" --path "$sb/worktrees/workspace/skill-a/sub" --type workspace 2>&1)" || rc=$?
check "sub-folder: exit 1" test "$rc" -eq 1
check "sub-folder: says why" grep -q "is not a git worktree's top folder" <<<"$out"
rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/worktree_remove.sh" --path "$sb/worktrees/workspace/skill-a" --skill research --type workspace 2>&1)" || rc=$?
check "--path with --skill: exit 1" test "$rc" -eq 1
check "--path with --skill: mutually exclusive" grep -q "mutually exclusive" <<<"$out"
check "worktree still there" test -d "$sb/worktrees/workspace/skill-a"

echo "TEST: worktree_remove.sh --path refuses a package worktree's entry and a worktree of another repository than --type names"
sb="$(make_sandbox)"
pkg="$sb/worktrees/workspace/issue-workspace-5"
mkdir -p "$pkg"
printf 'x\t.\tfeature/issue-5\nx\tsrc/a\tfeature/a-issue-5\n' > "$pkg/.worktree-repos"
add_worktree "$sb" "$pkg/src/a" feature/a-issue-5
rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/worktree_remove.sh" --path "$pkg/src/a" --type workspace 2>&1)" || rc=$?
check "package entry: exit 1" test "$rc" -eq 1
check "package entry: says why" grep -q "is an entry of the package worktree" <<<"$out"
check "package entry still there" test -d "$pkg/src/a"
make_repo_with_origin "$sb/project" premote
add_worktree "$sb/project" "$sb/worktrees/project/proj/skill-p" "skill/onboard-project-20261115-090000-1"
rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/worktree_remove.sh" --path "$sb/worktrees/project/proj/skill-p" --type workspace 2>&1)" || rc=$?
check "project worktree as --type workspace: exit 1" test "$rc" -eq 1
check "project worktree as --type workspace: says why" grep -q "is not a worktree of the workspace repository" <<<"$out"
check "project worktree still there" test -d "$sb/worktrees/project/proj/skill-p"
add_worktree "$sb" "$sb/worktrees/workspace/skill-w" "$SKILL_BR"
rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/worktree_remove.sh" --path "$sb/worktrees/workspace/skill-w" --type project 2>&1)" || rc=$?
check "workspace worktree as --type project: exit 1" test "$rc" -eq 1
check "workspace worktree as --type project: says why" grep -q "is not a worktree of the project repository" <<<"$out"
check "workspace worktree still there" test -d "$sb/worktrees/workspace/skill-w"
rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/worktree_remove.sh" --path "$sb/worktrees/project/proj/skill-p" --type project 2>&1)" || rc=$?
check "project worktree as --type project: removed" test "$rc" -eq 0 -a ! -e "$sb/worktrees/project/proj/skill-p"

echo ""
echo "test_merge_pr_skill: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
