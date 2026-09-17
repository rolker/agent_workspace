#!/usr/bin/env bash
# .agent/scripts/tests/test_merge_pr_gate.sh
# Tests for merge_pr.sh's review-loop merge gate (issue #269 PR F, Layer 1):
#   report-only (default) — each gap fixture proceeds to `gh pr merge`, prints
#     the "would have refused" line naming the failing condition(s), and
#     records a `## Merge (report-only)` entry; the all-good fixture prints
#     nothing and records nothing
#   --enforce, workspace scope — each gap fixture refuses (exit 1, no merge
#     call, worktree untouched); the all-good fixture merges
#   --enforce, project scope — stays report-only (asserted explicitly)
#   --force-unreviewed — bypasses with the banner and a `## Merge (unreviewed)`
#     entry, in both modes
#   no open worktree — the record is posted as a PR comment
# The gh stub answers `pr view` from fixture files, logs every call, and
# `pr merge` exits GH_MERGE_EXIT (set to 1 so a report-only run stops right
# after reaching Step 3 and the worktree survives for assertions).
# Run: bash .agent/scripts/tests/test_merge_pr_gate.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
SANDBOXES=()
cleanup() { local s; for s in ${SANDBOXES[@]+"${SANDBOXES[@]}"}; do rm -rf "$s"; done; }
trap cleanup EXIT
export AGENT_NAME="Test Agent"
export AGENT_EMAIL="test+agent@example.com"
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT

HEAD_SHA="abc1234abc1234abc1234abc1234abc1234abc12"
PR=70

write_gh_stub() {
    cat > "$1/stubbin/gh" <<'EOF'
#!/usr/bin/env bash
: "${GH_FIXTURES_DIR:?}"
log="${GH_CALL_LOG:-/dev/null}"
printf '%s\n' "$*" >> "$log"
sanitize() { printf '%s' "$1" | tr '/' '_'; }
if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    num="$3"; shift 3; repo=""
    while [ $# -gt 0 ]; do case "$1" in -R) repo="$2"; shift 2 ;; *) shift ;; esac; done
    f="$GH_FIXTURES_DIR/pr_view_$(sanitize "$repo")_${num}.json"
    [ -f "$f" ] && { cat "$f"; exit 0; }
    echo "GraphQL: Could not resolve to a PullRequest with the number of '$num'." >&2; exit 1
elif [ "$1" = "pr" ] && [ "$2" = "merge" ]; then exit "${GH_MERGE_EXIT:-0}"
elif [ "$1" = "pr" ] && [ "$2" = "checks" ]; then exit 0
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

# A workspace sandbox: the sandbox itself is the workspace repo (ROOT_DIR),
# with a bare origin, a feature/issue-7 worktree, and a progress.md fixture.
make_sandbox() {  # <progress-body|""> [with_summary]
    local sb bare
    sb="$(mktemp -d)"; SANDBOXES+=("$sb")
    mkdir -p "$sb/.agent/scripts" "$sb/stubbin" "$sb/gh_fixtures"
    for f in merge_pr.sh worktree_remove.sh worktree_list.sh _worktree_helpers.sh _issue_helpers.sh _project_registry.sh progress_read.py progress_append.sh _progress_entry.sh; do
        cp "$REAL_ROOT/.agent/scripts/$f" "$sb/.agent/scripts/"
    done
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"; chmod +x "$sb/stubbin/git-bug"
    write_gh_stub "$sb"
    git -C "$sb" init --quiet -b main
    git -C "$sb" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
    bare="${sb}.remote.git"; git init --bare --quiet "$bare"; git -C "$bare" symbolic-ref HEAD refs/heads/main; SANDBOXES+=("$bare")
    git -C "$sb" remote add origin "$bare"
    git -C "$sb" push --quiet -u origin main
    # the PR's worktree with its timeline
    mkdir -p "$sb/worktrees/workspace"
    git -C "$sb" worktree add --quiet "$sb/worktrees/workspace/issue-workspace-7" -b feature/issue-7 >/dev/null 2>&1
    if [[ -n "$1" ]]; then
        mkdir -p "$sb/worktrees/workspace/issue-workspace-7/.agent/work-plans/issue-7"
        printf -- '---\nissue: 7\n---\n\n# Issue #7\n\n%s\n' "$1" > "$sb/worktrees/workspace/issue-workspace-7/.agent/work-plans/issue-7/progress.md"
        git -C "$sb/worktrees/workspace/issue-workspace-7" add -A
        git -C "$sb/worktrees/workspace/issue-workspace-7" -c user.name=t -c user.email=t@t commit --quiet -m "progress"
    fi
    git -C "$sb/worktrees/workspace/issue-workspace-7" push --quiet -u origin feature/issue-7
    # PR fixture keyed on the workspace remote. with_summary puts the section
    # in a comment; body_summary puts it in the PR body (the template's place).
    local comments='[]' body='"## Summary\n\nplain body"'
    [[ "${2:-}" == with_summary ]] && comments='[{"body":"## Decision summary\n\n**What changed**: x\n\n**Recommendation**: merge"}]'
    [[ "${2:-}" == body_summary ]] && body='"## Summary\n\nx\n\n## Decision summary\n\n**What changed**: in the body\n\n**Recommendation**: merge"'
    printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":%s,"body":%s}\n' "$HEAD_SHA" "$comments" "$body" \
        > "$sb/gh_fixtures/pr_view_$(printf '%s' "$bare" | tr '/' '_')_${PR}.json"
    echo "$sb"
}

run_merge() {  # <sb> [args...]
    local sb="$1"; shift
    (cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" GH_MERGE_EXIT="${GH_MERGE_EXIT:-1}" \
        "$sb/.agent/scripts/merge_pr.sh" --pr "$PR" --type workspace --no-wait --no-roadmap-update "$@")
}
progress_of() { cat "$1/worktrees/workspace/issue-workspace-7/.agent/work-plans/issue-7/progress.md" 2>/dev/null; }
merged_called() { grep -q "^pr merge" "$1/gh_calls.log" 2>/dev/null; }

APPROVED_AT_HEAD="## Local Review
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)
**Verdict**: approved

**PR**: #70 at \`abc1234\`

### Findings
- [ ] No issues found. LGTM."
STALE="## Local Review
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)
**Verdict**: approved

**PR**: #70 at \`0000000\`

### Findings
- [ ] No issues found. LGTM."
CHANGES_REQUESTED="${APPROVED_AT_HEAD/approved/changes-requested}"
IR_OPEN="## Integrated Review
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)

**PR**: #70 at \`abc1234\`

### Findings
- [ ] (cross-confirmed) still open — \`x.sh\`"
IR_CLEAN="## Integrated Review
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)

**PR**: #70 at \`abc1234\`

### Findings
- [x] (must-fix) fixed — \`x.sh\`
- [ ] (suggestion) later — \`y.sh\`"

# ================================================= report-only (default) =====
echo "TEST: report-only mode — every gap proceeds to the merge call, names why, records an entry"
run_case() {  # <label> <progress body> <with_summary|""> <expected reason fragment>
    local sb out rc=0
    sb="$(make_sandbox "$2" "$3")"
    out="$(run_merge "$sb" 2>&1)" || rc=$?
    if merged_called "$sb" && [[ "$out" == *"would have refused"*"$4"* ]] \
        && progress_of "$sb" | grep -q '^## Merge (report-only)$' \
        && progress_of "$sb" | grep -q "^\*\*PR\*\*: #70 at \`abc1234\`" \
        && progress_of "$sb" | grep -q "^\*\*Conditions\*\*: .*$4"; then
        pass "$1"
    else
        fail "$1 (rc=$rc merged=$(merged_called "$sb" && echo y || echo n) out=${out:0:300})"
    fi
}
run_case "(a) no progress.md at all"                     ""                   ""            "no progress.md for issue #7"
run_case "(a2) progress.md without any review entry"     "## Plan Authored
**Status**: complete
**When**: 2026-09-17 09:00 -04:00
**By**: t (m)
**Plan**: \`p.md\` at \`1111111\`" ""            "no ## Local Review"
run_case "(b) review at a stale SHA"                     "$STALE"             with_summary  "not the PR head"
run_case "(c) changes-requested at the head"             "$CHANGES_REQUESTED" with_summary  "not approved"
run_case "(d) approved at head, no decision summary"     "$APPROVED_AT_HEAD"  ""            "no \"## Decision summary\" heading in the PR body or a PR comment"
run_case "(d2) Integrated Review with an open cross-confirmed finding" "$IR_OPEN" with_summary "open must-fix/cross-confirmed"
# record is pushed to origin (survives the worktree's later removal)
sb="$(make_sandbox "$STALE" with_summary)"; run_merge "$sb" >/dev/null 2>&1 || true
[[ "$(git -C "${sb}.remote.git" log -1 --format=%s feature/issue-7)" == "progress: merge (report-only) for #7" ]] \
    && pass "report-only record is committed by progress_append.sh and pushed to origin before the merge" || fail "record pushed (subj=$(git -C "${sb}.remote.git" log -1 --format=%s feature/issue-7))"
# all good: no line, no entry, merge reached
sb="$(make_sandbox "$APPROVED_AT_HEAD" with_summary)"
out="$(run_merge "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" != *"would have refused"* ]] && [[ "$out" == *"Review gate: approved review at head"* ]] \
    && ! progress_of "$sb" | grep -q '^## Merge'; then
    pass "(e) approved at head + decision summary: passes, records nothing"
else
    fail "(e) all-good (out=${out:0:300})"
fi
sb="$(make_sandbox "$IR_CLEAN" with_summary)"
out="$(run_merge "$sb" 2>&1)" || true
[[ "$out" == *"Review gate: approved review at head"* ]] && pass "(e2) Integrated Review at head with only a suggestion open passes" || fail "(e2) IR clean (out=${out:0:300})"
# the decision summary in the PR BODY (where the template puts it) satisfies (b)
sb="$(make_sandbox "$APPROVED_AT_HEAD" body_summary)"
out="$(run_merge "$sb" 2>&1)" || true
[[ "$out" == *"Review gate: approved review at head"* ]] && pass "(e3) decision summary in the PR body (no comment) satisfies condition (b)" || fail "(e3) body summary (out=${out:0:300})"
# a legacy External Review at the head is honoured as Integrated Review's predecessor
EXT_CLEAN="${IR_CLEAN/Integrated Review/External Review}"
sb="$(make_sandbox "$EXT_CLEAN" with_summary)"
out="$(run_merge "$sb" 2>&1)" || true
[[ "$out" == *"Review gate: approved review at head"* ]] && pass "(e4) a legacy External Review at head with no open must-fix passes (ADR-0013 predecessor)" || fail "(e4) External Review (out=${out:0:300})"
# a malformed progress.md is named as such, not as "no review entry"
sb="$(make_sandbox $'## Implementation\n```\nunterminated' with_summary)"
out="$(run_merge "$sb" 2>&1)" || true
[[ "$out" == *"could not be parsed"* && "$out" != *"no ## Local Review"* ]] && pass "(f) a malformed progress.md is reported as malformed, not as missing" || fail "(f) malformed (out=${out:0:300})"
# push refused after the record commit: the commit is undone and ONE PR comment posted
sb="$(make_sandbox "$STALE" with_summary)"
rm -rf "${sb}.remote.git"; mkdir -p "${sb}.remote.git"   # origin gone -> push fails
before=$(git -C "$sb/worktrees/workspace/issue-workspace-7" rev-parse HEAD)
out="$(run_merge "$sb" 2>&1)" || true
if [[ "$(git -C "$sb/worktrees/workspace/issue-workspace-7" rev-parse HEAD)" == "$before" ]] \
    && [[ -z "$(git -C "$sb/worktrees/workspace/issue-workspace-7" status --porcelain)" ]] \
    && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md" 2>/dev/null)" -eq 1 ]] \
    && [[ "$out" == *"could not be pushed"*"posted as a comment"* ]]; then
    pass "(g) push failure undoes the timeline commit and posts exactly one PR comment"
else
    fail "(g) push failure (out=${out:0:300})"
fi
# the PR comment carries the workspace signature (Authored-By + Model)
grep -q '^\*\*Model\*\*: `' "$sb/gh_fixtures/comments_posted.md" && grep -q '^\*\*Authored-By\*\*: `Test Agent`' "$sb/gh_fixtures/comments_posted.md" \
    && pass "(h) PR comment record carries the AI signature (Authored-By + Model)" || fail "(h) signature"

# ================================================= --enforce, workspace =====
echo "TEST: --enforce on a workspace PR refuses every gap; passes the all-good fixture"
enforce_refuses() {  # <label> <progress> <with_summary|""> <reason fragment>
    local sb out rc=0
    sb="$(make_sandbox "$2" "$3")"
    out="$(run_merge "$sb" --enforce 2>&1)" || rc=$?
    if [[ "$rc" -ne 0 ]] && ! merged_called "$sb" && [[ "$out" == *"review gate refused"*"$4"* ]] \
        && [[ -d "$sb/worktrees/workspace/issue-workspace-7" ]] && ! progress_of "$sb" | grep -q '^## Merge'; then
        pass "$1"
    else
        fail "$1 (rc=$rc merged=$(merged_called "$sb" && echo y || echo n) out=${out:0:300})"
    fi
}
enforce_refuses "(a) no progress.md"                 "" "" "no progress.md for issue #7"
enforce_refuses "(b) stale SHA"                      "$STALE" with_summary "not the PR head"
enforce_refuses "(c) changes-requested"              "$CHANGES_REQUESTED" with_summary "not approved"
enforce_refuses "(d) no decision summary"            "$APPROVED_AT_HEAD" "" "Decision summary"
sb="$(make_sandbox "$APPROVED_AT_HEAD" body_summary)"
out="$(GH_MERGE_EXIT=0 run_merge "$sb" --enforce 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] && merged_called "$sb" && pass "(e-body) --enforce with the summary in the PR body merges" || fail "(e-body) (rc=$rc out=${out:0:200})"
sb="$(make_sandbox "$APPROVED_AT_HEAD" with_summary)"
out="$(GH_MERGE_EXIT=0 run_merge "$sb" --enforce 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] && merged_called "$sb" && pass "(e) --enforce with both conditions met merges (exit 0)" || fail "(e) enforce all-good (rc=$rc out=${out:0:300})"

# ================================================= --force-unreviewed =====
echo "TEST: --force-unreviewed bypasses with a banner and a Merge (unreviewed) record"
sb="$(make_sandbox "" "")"
out="$(run_merge "$sb" --enforce --force-unreviewed 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"--force-unreviewed: bypassing the review gate"* ]] \
    && progress_of "$sb" | grep -q '^## Merge (unreviewed)$' \
    && progress_of "$sb" | grep -q '^\*\*Mode\*\*: enforce, --force-unreviewed'; then
    pass "under --enforce (workspace): merge reached, banner printed, Merge (unreviewed) recorded"
else
    fail "force under enforce (out=${out:0:300})"
fi
sb="$(make_sandbox "" "")"
out="$(run_merge "$sb" --force-unreviewed 2>&1)" || true
if [[ "$out" == *"bypassing the review gate"* ]] && [[ "$out" != *"would have refused"* ]] \
    && progress_of "$sb" | grep -q '^## Merge (unreviewed)$' && ! progress_of "$sb" | grep -q '^## Merge (report-only)$'; then
    pass "under report-only: banner instead of the would-have-refused line; Merge (unreviewed) not (report-only)"
else
    fail "force under report-only (out=${out:0:300})"
fi

# ================================================= no open worktree =====
echo "TEST: no open worktree for the PR's repo — the record is posted as a PR comment"
sb="$(make_sandbox "" "")"
git -C "$sb" worktree remove --force "$sb/worktrees/workspace/issue-workspace-7" >/dev/null 2>&1
out="$(run_merge "$sb" 2>&1)" || true
if [[ "$out" == *"would have refused"* ]] && [[ "$out" == *"posted as a comment"* ]] \
    && grep -q '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md" 2>/dev/null \
    && grep -q '^\*\*Conditions\*\*: ' "$sb/gh_fixtures/comments_posted.md"; then
    pass "record posted as a PR comment with the same fields"
else
    fail "PR comment fallback (out=${out:0:300})"
fi

# ================================================= --enforce, project scope =====
echo "TEST: --enforce on a project PR stays report-only"
sb="$(make_sandbox "" "")"
# a legacy project/ checkout with its own remote and a PR fixture there
mkdir -p "$sb/fake_remotes/github.com/owner"
git init --bare --quiet "$sb/fake_remotes/github.com/owner/proj.git"; git -C "$sb/fake_remotes/github.com/owner/proj.git" symbolic-ref HEAD refs/heads/main
git -C "$sb" init --quiet -b main project >/dev/null 2>&1 || { mkdir -p "$sb/project"; git -C "$sb/project" init --quiet -b main; }
git -C "$sb/project" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
git -C "$sb/project" remote add origin "$sb/fake_remotes/github.com/owner/proj.git"
git -C "$sb/project" push --quiet -u origin main
printf '{"state":"OPEN","headRefName":"feature/issue-9","title":"Proj PR","headRefOid":"%s","comments":[]}\n' "$HEAD_SHA" \
    > "$sb/gh_fixtures/pr_view_$(printf '%s' "$sb/fake_remotes/github.com/owner/proj.git" | tr '/' '_')_9.json"
out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" GH_MERGE_EXIT=1 \
    "$sb/.agent/scripts/merge_pr.sh" --pr 9 --type project --no-wait --no-roadmap-update --enforce 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"would have refused"* ]] && [[ "$out" == *"--enforce applies to workspace PRs only"* ]] && [[ "$out" != *"review gate refused"* ]]; then
    pass "project scope under --enforce: proceeds with the report-only line naming the scoping rule"
else
    fail "project scope enforce (out=${out:0:400})"
fi

echo ""
echo "test_merge_pr_gate: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
