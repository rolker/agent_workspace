#!/usr/bin/env bash
# .agent/scripts/tests/test_triage_reviews_integration.sh
# Tests for the triage-reviews integrator mechanics (issue #269 PR C):
#   - review_progress.sh sources: local review findings at the PR head +
#     GitHub inline comments -> candidate cross-source confirmations (one row
#     for a finding both sources raise on the same file at the same head SHA,
#     not two), with stale-head comments and other-head local entries excluded
#   - review_progress.sh persist for an `## Integrated Review` entry through
#     triage-reviews' own call site: strict abort on a mismatched worktree,
#     compatibility notice + inline commit, matching worktree no-notice,
#     degradation (skill worktree / no linked issue) skips without aborting
#
# All cases run in mktemp -d sandboxes; host worktree state is cleared first.
# Run: bash .agent/scripts/tests/test_triage_reviews_integration.sh

set -u
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RP="$SCRIPT_DIR/../review_progress.sh"
PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export AGENT_NAME="Test Agent"
export AGENT_EMAIL="test+agent@example.com"

# ========================================================== sources =====
HEAD=abc1234def5678
PROG="$TMPD/progress.md"
cat > "$PROG" <<'EOF'
---
issue: 7
---

# Issue #7 — Fixture

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)
**Verdict**: changes-requested

**Branch**: feature/issue-7 at `0ld0000`
**Base**: main
**Must-fix**: 1 | **Suggestions**: 0

### Findings
- [x] (must-fix) stale finding fixed since — `.agent/scripts/old.sh:3`

## Local Review
**Status**: complete
**When**: 2026-09-17 11:00 -04:00
**By**: t (m)
**Verdict**: changes-requested

**PR**: #70 at `abc1234`
**Depth**: Standard
**Must-fix**: 2 | **Suggestions**: 1

### Findings
- [ ] (must-fix) unchecked append redirect exits 0 on failure — `.agent/scripts/progress_append.sh:142`
- [ ] (must-fix) gate pools fields across adjacent blocks — `.agent/scripts/tests/test_checkpoint_269.sh:72-76`
- [ ] (suggestion) doc nit — `AGENTS.md`

### False positives
- (Copilot) jq missing breaks suites — bootstrap installs jq
EOF
REVIEWS="$TMPD/reviews.json"
cat > "$REVIEWS" <<EOF
{
  "pr": 70, "repo": "o/r", "head_sha": "$HEAD",
  "reviews": [
    {"review_id": 1, "state": "COMMENTED", "body": "", "commit_id": "$HEAD", "user_login": "copilot-pull-request-reviewer", "user_type": "Bot",
     "comments": [
       {"path": ".agent/scripts/progress_append.sh", "line": 143, "body": "The append redirection is not checked; a failed write reports success."},
       {"path": ".pre-commit-config.yaml", "line": 62, "body": "jq is not provisioned."}
     ]},
    {"review_id": 2, "state": "COMMENTED", "body": "", "commit_id": "0ld00001111", "user_login": "copilot-pull-request-reviewer", "user_type": "Bot",
     "comments": [
       {"path": ".agent/scripts/tests/test_checkpoint_269.sh", "line": 76, "body": "stale-head comment on the gate"}
     ]}
  ],
  "ci_checks": [], "conversation_comments": []
}
EOF
out=$("$RP" sources --progress "$PROG" --head "$HEAD" --reviews "$REVIEWS"); rc=$?
n_local=$(printf '%s' "$out" | jq '.local_findings | length')
n_cand=$(printf '%s' "$out" | jq '.candidates | length')
cand_file=$(printf '%s' "$out" | jq -r '.candidates[0].file')
if [[ "$rc" -eq 0 && "$n_local" -eq 3 && "$n_cand" -eq 1 && "$cand_file" == ".agent/scripts/progress_append.sh" ]]; then
    pass "sources: one Local Review finding + one Copilot comment on the same file at the same head -> exactly one candidate row"
else
    fail "sources: single cross-source candidate (rc=$rc local=$n_local cand=$n_cand file=$cand_file)"
fi
# the other-head local entry and the stale-head GitHub comment are excluded from matching
stale_local=$(printf '%s' "$out" | jq '[.local_findings[] | select(.sha == "0ld0000")] | length')
stale_gh=$(printf '%s' "$out" | jq '[.github_comments[] | select(.at_head == false)] | length')
gate_cand=$(printf '%s' "$out" | jq '[.candidates[] | select(.file | test("checkpoint"))] | length')
if [[ "$stale_local" -eq 0 && "$stale_gh" -eq 1 && "$gate_cand" -eq 0 ]]; then
    pass "sources: local entries at another head are dropped; a stale-head GitHub comment is listed but never matched"
else
    fail "sources: head-SHA correlation (stale_local=$stale_local stale_gh=$stale_gh gate_cand=$gate_cand)"
fi
# false-positive bullets are not findings
fp=$(printf '%s' "$out" | jq '[.local_findings[] | select(.text | test("jq missing"))] | length')
[[ "$fp" -eq 0 ]] && pass "sources: a prior 'False positives' bullet is not a local finding" || fail "sources: false positives excluded (fp=$fp)"
# no progress file at all -> GitHub side only, still exit 0
out=$("$RP" sources --head "$HEAD" --reviews "$REVIEWS"); rc=$?
[[ "$rc" -eq 0 && "$(printf '%s' "$out" | jq '.local_findings | length')" -eq 0 && "$(printf '%s' "$out" | jq '.github_comments | length')" -eq 3 ]] \
    && pass "sources: no progress.md -> GitHub comments only, exit 0" || fail "sources: absent timeline (rc=$rc)"
# malformed progress.md -> loud failure, not a silent empty timeline
printf '## Implementation\n```\nopen\n' > "$TMPD/bad.md"
"$RP" sources --progress "$TMPD/bad.md" --head "$HEAD" --reviews "$REVIEWS" >/dev/null 2>&1; rc=$?
[[ "$rc" -ne 0 ]] && pass "sources: malformed progress.md fails loudly (rc=$rc)" || fail "sources: malformed progress.md should fail"
# --progress given a directory -> error, not "empty timeline"
err=$("$RP" sources --progress "$TMPD" --head "$HEAD" --reviews "$REVIEWS" 2>&1 >/dev/null); rc=$?
[[ "$rc" -eq 2 && "$err" == *"not a regular file"* ]] && pass "sources: --progress pointing at a directory is an error (rc 2)" || fail "sources: directory progress (rc=$rc err=$err)"
# malformed reviews JSON -> clean error, rc 2, no traceback
printf '{"reviews": [' > "$TMPD/trunc.json"
err=$("$RP" sources --head "$HEAD" --reviews "$TMPD/trunc.json" 2>&1 >/dev/null); rc=$?
[[ "$rc" -eq 2 && "$err" == error:*"not valid JSON"* && "$err" != *Traceback* ]] && pass "sources: truncated reviews JSON is a clean rc-2 error" || fail "sources: bad reviews json (rc=$rc err=$err)"
# matching rules: every cited file counts; exact path only; checked findings are not open
cat > "$TMPD/rules.md" <<'EOF2'
## Local Review
**Status**: complete
**When**: 2026-09-17 11:00 -04:00
**By**: t (m)

**PR**: #70 at `abc1234`

### Findings
- [ ] (must-fix) two files cited, first is the real one — `scripts/x.sh:3` and `docs/y.md`
- [ ] (must-fix) unrelated file whose path is a suffix of a comment path — `scripts/foo.sh:9`
- [x] (must-fix) already resolved on this head — `.pre-commit-config.yaml:62`
EOF2
cat > "$TMPD/rules.json" <<EOF2
{"head_sha": "$HEAD", "reviews": [{"review_id": 1, "commit_id": "$HEAD", "user_login": "c", "user_type": "Bot", "comments": [
  {"path": "scripts/x.sh", "line": 3, "body": "on the first cited file"},
  {"path": "vendor/scripts/foo.sh", "line": 9, "body": "different file, same tail"},
  {"path": ".pre-commit-config.yaml", "line": 62, "body": "matches only a resolved finding"}
]}], "ci_checks": [], "conversation_comments": []}
EOF2
out=$("$RP" sources --progress "$TMPD/rules.md" --head "$HEAD" --reviews "$TMPD/rules.json")
c_first=$(printf '%s' "$out" | jq '[.candidates[] | select(.file == "scripts/x.sh")] | length')
c_suffix=$(printf '%s' "$out" | jq '[.candidates[] | select(.file == "vendor/scripts/foo.sh")] | length')
c_checked=$(printf '%s' "$out" | jq '[.candidates[] | select(.file == ".pre-commit-config.yaml")] | length')
n_open=$(printf '%s' "$out" | jq '.local_findings | length')
if [[ "$c_first" -eq 1 && "$c_suffix" -eq 0 && "$c_checked" -eq 0 && "$n_open" -eq 2 ]]; then
    pass "sources: first-cited file matches; suffix-only path does not; checked findings are excluded"
else
    fail "sources: matching rules (first=$c_first suffix=$c_suffix checked=$c_checked open=$n_open)"
fi

# Real histories: scripts live in the workspace, Git operations must use the
# target repository's cwd. Fixtures stay under this suite's TMPDIR allocation.
HIST="$TMPD/history"
mkdir -p "$HIST/.agent/work-plans/issue-7" "$HIST/docs" "$HIST/scripts"
git -C "$HIST" init -q -b feature/issue-7
hist_commit() {
    git -C "$HIST" add . &&
        git -C "$HIST" -c user.name=t -c user.email=t@t commit -q -m "$1"
}
printf 'original\n' > "$HIST/scripts/code.sh"
hist_commit reviewed
REVIEWED=$(git -C "$HIST" rev-parse HEAD)
HP="$HIST/.agent/work-plans/issue-7/progress.md"
cat > "$HP" <<EOF
## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 11:00 -04:00
**By**: t (m)
**Branch**: feature/issue-7 at \`${REVIEWED:0:7}\`

### Findings
- [ ] (must-fix) still open — \`scripts/code.sh:1\`
- [x] (must-fix) already fixed — \`scripts/code.sh:2\`

### False positives
- [ ] dismissed — \`scripts/code.sh:3\`
EOF
hist_commit checkpoint
BOOK_HEAD=$(git -C "$HIST" rev-parse HEAD)
hist_sources() {  # head [progress]
    (cd "$HIST" && "$RP" sources --progress "${2:-$HP}" --head "$1" --reviews "$REVIEWS")
}
out=$(hist_sources "$BOOK_HEAD"); rc=$?
if [[ "$rc" -eq 0 ]] && jq -e --arg sha "${REVIEWED:0:7}" '
    (.local_findings | length) == 1 and
    .local_findings[0].sha == $sha and .local_findings[0].covers_head == true and
    .local_findings[0].coverage == "bookkeeping" and
    (.local_findings[0].text | contains("still open"))' <<<"$out" >/dev/null; then
    pass "sources: checkpoint retains open finding and original SHA; checked/false positives excluded"
else
    fail "sources: checkpoint coverage (rc=$rc out=$out)"
fi
out=$(hist_sources "$REVIEWED")
jq -e '.local_findings[0].covers_head == true and .local_findings[0].coverage == "exact"' <<<"$out" >/dev/null \
    && pass "sources: short/full exact match retains provenance" || fail "sources: exact coverage metadata"

# Every allowed document class, including the whole issue-specific plan dir.
for doc in .agent/work-plans/issue-7/plan.md ROADMAP.md docs/ROADMAP.md; do
    printf 'bookkeeping\n' >> "$HIST/$doc"
    hist_commit "$doc"
    out=$(hist_sources "$(git -C "$HIST" rev-parse HEAD)")
    [[ "$(jq '.local_findings | length' <<<"$out")" == 1 ]] \
        && pass "sources: retains finding after $doc" || fail "sources: lost finding after $doc"
done
DOC_HEAD=$(git -C "$HIST" rev-parse HEAD)
OLD_REVIEWS="$REVIEWS"
REVIEWS="$TMPD/history-reviews.json"
jq -n --arg head "$DOC_HEAD" --arg old "$REVIEWED" '{reviews: [
    {commit_id: $head, comments: [{path: "scripts/code.sh", line: 1, body: "current"}]},
    {commit_id: $old, comments: [{path: "scripts/code.sh", line: 1, body: "stale"}]}
]}' > "$REVIEWS"
out=$(hist_sources "$DOC_HEAD")
jq -e '(.candidates | length) == 1 and .candidates[0].github == "current"' <<<"$out" >/dev/null \
    && pass "sources: covered finding matches current GitHub comment only" || fail "sources: covered cross-source candidate"
REVIEWS="$OLD_REVIEWS"

printf 'changed\n' >> "$HIST/scripts/code.sh"
hist_commit code
CODE_HEAD=$(git -C "$HIST" rev-parse HEAD)
out=$(hist_sources "$CODE_HEAD")
[[ "$(jq '.local_findings | length' <<<"$out")" == 0 ]] \
    && pass "sources: code plus bookkeeping is stale" || fail "sources: code change accepted"
printf 'later checkpoint\n' >> "$HP"
hist_commit later-checkpoint
out=$(hist_sources "$(git -C "$HIST" rev-parse HEAD)")
[[ "$(jq '.local_findings | length' <<<"$out")" == 0 ]] \
    && pass "sources: later checkpoint cannot hide earlier code change" || fail "sources: code hidden by checkpoint"

git -C "$HIST" checkout -q -b other-issue "$DOC_HEAD"
mkdir -p "$HIST/.agent/work-plans/issue-8"
printf 'other issue\n' > "$HIST/.agent/work-plans/issue-8/progress.md"
hist_commit other-issue
out=$(hist_sources "$(git -C "$HIST" rev-parse HEAD)")
[[ "$(jq '.local_findings | length' <<<"$out")" == 0 ]] \
    && pass "sources: another issue's timeline is not exempt" || fail "sources: other issue accepted"

# An identical tree is insufficient when the review is not an ancestor.
DIVERGED=$(printf 'unrelated root\n' | git -C "$HIST" -c user.name=t -c user.email=t@t commit-tree "${DOC_HEAD}^{tree}")
out=$(hist_sources "$DIVERGED")
[[ "$(jq '.local_findings | length' <<<"$out")" == 0 ]] \
    && pass "sources: non-ancestor with identical tree is stale" || fail "sources: divergent history accepted"
out=$(hist_sources 0000000000000000000000000000000000000000); rc=$?
[[ "$rc" == 0 && "$(jq '.local_findings | length' <<<"$out")" == 0 ]] \
    && pass "sources: unresolved head falls back without error" || fail "sources: unresolved head"
sed "s/${REVIEWED:0:7}/0000000/" "$HP" > "$TMPD/missing-review.md"
mkdir -p "$TMPD/external/.agent/work-plans/issue-7"
cp "$TMPD/missing-review.md" "$TMPD/external/.agent/work-plans/issue-7/progress.md"
out=$(hist_sources "$DOC_HEAD" "$TMPD/external/.agent/work-plans/issue-7/progress.md"); rc=$?
[[ "$rc" == 0 && "$(jq '.local_findings | length' <<<"$out")" == 0 ]] \
    && pass "sources: unresolved review falls back without error" || fail "sources: unresolved review"
cp "$HP" "$TMPD/noncanonical.md"
out=$(hist_sources "$DOC_HEAD" "$TMPD/noncanonical.md")
[[ "$(jq '.local_findings | length' <<<"$out")" == 0 ]] \
    && pass "sources: unknown issue path uses exact matching only" || fail "sources: noncanonical path grants coverage"
# Timeline storage can be in the workspace while cwd is a different project.
cp "$HP" "$TMPD/external/.agent/work-plans/issue-7/progress.md"
out=$(hist_sources "$DOC_HEAD" "$TMPD/external/.agent/work-plans/issue-7/progress.md")
[[ "$(jq '.local_findings | length' <<<"$out")" == 1 ]] \
    && pass "sources: uses target cwd even with externally stored timeline" || fail "sources: wrong repository resolution"
for head in "$REVIEWED" "$DOC_HEAD"; do
    out=$(cd "$TMPD" && "$RP" sources --progress "$HP" --head "$head" --reviews "$REVIEWS"); rc=$?
    expected=0; [[ "$head" == "$REVIEWED" ]] && expected=1
    [[ "$rc" == 0 && "$(jq '.local_findings | length' <<<"$out")" == "$expected" ]] \
        && pass "sources: no-repository fallback ($expected findings)" || fail "sources: no-repository fallback"
done

# ========================================================== persist =====
mk_repo() { mkdir -p "$1"; git -C "$1" init -q -b "$2"; git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init; }
ENTRY=$'## Integrated Review\n**Status**: complete\n**When**: 2026-09-17 12:00 -04:00\n**By**: t (m)\n\n**PR**: #70 at `abc1234`\n**Sources**: 2 (Copilot @ `abc1234`, Local Review @ `abc1234`)\n**Cross-source confirmations**: 1\n**CI**: all-pass\n\n### Findings\n- [ ] (cross-confirmed) unchecked append redirect — `.agent/scripts/progress_append.sh`\n\n### False positives\n- (Copilot) jq missing — bootstrap installs jq'

# strict + mismatched worktree -> abort rc 4, nothing written
MIS="$TMPD/issue-workspace-99"; mk_repo "$MIS" feature/issue-99
out=$(cd "$MIS" && printf '%s\n' "$ENTRY" | WORKTREE_ISSUE=99 "$RP" persist --issue 7 --strict 2>&1); rc=$?
[[ "$rc" -eq 4 && "$out" == *worktree_enter.sh* && ! -e "$MIS/.agent/work-plans/issue-7/progress.md" ]] \
    && pass "persist (Integrated Review) strict: mismatched worktree aborts rc 4 with remediation" || fail "persist strict mismatched (rc=$rc out=$out)"
# compat + mismatched -> notice + inline commit with the entry-type subject
out=$(cd "$MIS" && printf '%s\n' "$ENTRY" | WORKTREE_ISSUE=99 "$RP" persist --issue 7 --title "Seven" 2>&1); rc=$?
if [[ "$rc" -eq 0 && "$out" == *"would have aborted"*"PROGRESS_PERSISTENCE_STRICT=0"* ]] \
    && grep -q '^## Integrated Review$' "$MIS/.agent/work-plans/issue-7/progress.md" \
    && [[ "$(git -C "$MIS" log -1 --format=%s)" == "progress: integrated review for #7" ]]; then
    pass "persist (Integrated Review) compat: notice printed, entry committed inline with 'progress: integrated review for #7'"
else
    fail "persist compat mismatched (rc=$rc out=$out subj=$(git -C "$MIS" log -1 --format=%s))"
fi
# matching worktree, compat -> no notice; strict -> progress_append.sh commit
MATCH="$TMPD/issue-workspace-7"; mk_repo "$MATCH" feature/issue-7
out=$(cd "$MATCH" && printf '%s\n' "$ENTRY" | "$RP" persist --issue 7 --title "Seven" 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" != *notice* ]] && pass "persist compat: matching worktree produces no notice" || fail "persist compat matching (rc=$rc out=$out)"
out=$(cd "$MATCH" && printf '%s\n' "${ENTRY//abc1234/def5678}" | "$RP" persist --issue 7 --strict 2>&1); rc=$?
[[ "$rc" -eq 0 && "$(git -C "$MATCH" log -1 --format='%s|%an')" == "progress: integrated review for #7|Test Agent" ]] \
    && pass "persist strict: matching worktree commits via progress_append.sh with the agent identity" || fail "persist strict matching (rc=$rc out=$out)"
# degradation: no issue derivable -> skip, never abort
SK="$TMPD/skillwt"; mk_repo "$SK" skill/research-20260917-120000
out=$(cd "$SK" && "$RP" persist --issue "" --strict < /dev/null 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "Progress persistence skipped (no linked issue — skill worktree)" ]] \
    && pass "persist degrade: skill worktree skips (even under strict)" || fail "persist degrade skill (rc=$rc out=$out)"
OB="$TMPD/oneoff"; mk_repo "$OB" hotfix/typo
out=$(cd "$OB" && "$RP" persist --issue "" < /dev/null 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "Progress persistence skipped (no linked issue)" ]] \
    && pass "persist degrade: ordinary branch with no issue skips" || fail "persist degrade ordinary (rc=$rc out=$out)"

echo ""
echo "test_triage_reviews_integration: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
