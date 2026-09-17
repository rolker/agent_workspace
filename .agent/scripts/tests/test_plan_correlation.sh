#!/usr/bin/env bash
# .agent/scripts/tests/test_plan_correlation.sh
# Tests for issue #269 PR E — plan-task / review-plan entry headings:
#   review_progress.sh plan-sha   — the plan-commit SHA (last commit that
#     touched plan.md), NOT the branch head, in a two-commit fixture
#   `## Plan Authored` / `## Plan Review` entries parsed by progress_read.py
#     carry correlation.kind == "plan" and .sha == that plan-commit SHA
#   persist for `## Plan Authored` through plan-task's call site under the
#     PROGRESS_PERSISTENCE_STRICT switch (compat notice / strict abort /
#     matching worktree)
#   persist --soft (review-plan's non-fatal step 6): a resolver refusal
#     prints "Progress persistence failed: ..." and exits 0 with nothing
#     written; a matching worktree writes the entry
# Hermetic: mktemp -d sandboxes only.
# Run: bash .agent/scripts/tests/test_plan_correlation.sh

set -u
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RP="$SCRIPT_DIR/../review_progress.sh"
PR="$SCRIPT_DIR/../progress_read.py"
PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export AGENT_NAME="Test Agent"
export AGENT_EMAIL="test+agent@example.com"

mk_repo() { mkdir -p "$1"; git -C "$1" init -q -b "$2"; git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init; }

# ---- plan-sha: two-commit fixture (plan.md commit, then an unrelated commit) ----
REPO="$TMPD/issue-workspace-7"; mk_repo "$REPO" feature/issue-7
mkdir -p "$REPO/.agent/work-plans/issue-7"
printf '# Plan\n' > "$REPO/.agent/work-plans/issue-7/plan.md"
git -C "$REPO" add -A && git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m "plan"
PLAN_SHA=$(git -C "$REPO" rev-parse --short HEAD)
printf 'x\n' > "$REPO/other.txt"
git -C "$REPO" add -A && git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m "other"
HEAD_SHA=$(git -C "$REPO" rev-parse --short HEAD)
out=$(cd "$REPO" && "$RP" plan-sha --plan .agent/work-plans/issue-7/plan.md); rc=$?
[[ "$rc" -eq 0 && "$out" == "$PLAN_SHA" && "$out" != "$HEAD_SHA" ]] \
    && pass "plan-sha: the last commit touching plan.md ($PLAN_SHA), not HEAD ($HEAD_SHA)" || fail "plan-sha (rc=$rc out=$out plan=$PLAN_SHA head=$HEAD_SHA)"
"$RP" plan-sha --plan "$REPO/.agent/work-plans/issue-7/nope.md" >/dev/null 2>&1; rc=$?
[[ "$rc" -eq 2 ]] && pass "plan-sha: a missing plan file is a usage error (rc 2)" || fail "plan-sha missing (rc=$rc)"
# uncommitted plan.md -> error, never HEAD as a stand-in
printf 'edit\n' >> "$REPO/.agent/work-plans/issue-7/plan.md"
"$RP" plan-sha --plan "$REPO/.agent/work-plans/issue-7/plan.md" >/dev/null 2>&1; rc=$?
[[ "$rc" -eq 2 ]] && pass "plan-sha: an uncommitted plan.md is refused (commit it first)" || fail "plan-sha dirty (rc=$rc)"
git -C "$REPO" checkout -q -- .agent/work-plans/issue-7/plan.md

# ---- entries: correlation keys off the plan-commit SHA ----
ENTRY_PA="## Plan Authored
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)
**Plan**: \`.agent/work-plans/issue-7/plan.md\` at \`$PLAN_SHA\`

Summary of approach."
ENTRY_PR="## Plan Review
**Status**: complete
**When**: 2026-09-17 11:00 -04:00
**By**: t (m)
**Verdict**: ready
**Plan**: \`.agent/work-plans/issue-7/plan.md\` at \`$PLAN_SHA\`
**PR**: #70 — Fixture title moved into the body

### Findings
- [ ] (suggestion) tighten scope"
out=$(cd "$REPO" && printf '%s\n' "$ENTRY_PA" | "$RP" persist --issue 7 --branch feature/issue-7 --title "Seven" --strict 2>&1); rc=$?
[[ "$rc" -eq 0 && "$(git -C "$REPO" log -1 --format=%s)" == "progress: plan authored for #7" ]] \
    && pass "persist: Plan Authored written by the strict path with the entry-type commit subject" || fail "persist PA (rc=$rc out=$out)"
out=$(cd "$REPO" && printf '%s\n' "$ENTRY_PR" | "$RP" persist --issue 7 --branch feature/issue-7 --strict 2>&1); rc=$?
[[ "$rc" -eq 0 ]] && pass "persist: Plan Review written" || fail "persist PR (rc=$rc out=$out)"
corr=$(python3 "$PR" "$REPO/.agent/work-plans/issue-7/progress.md" --type "Plan Authored" --type "Plan Review" \
    | jq -c '[.entries[] | {t: .type, k: .correlation.kind, s: .correlation.sha}]')
if [[ "$corr" == "[{\"t\":\"Plan Authored\",\"k\":\"plan\",\"s\":\"$PLAN_SHA\"},{\"t\":\"Plan Review\",\"k\":\"plan\",\"s\":\"$PLAN_SHA\"}]" ]]; then
    pass "progress_read: both entries correlate by plan-commit SHA $PLAN_SHA (kind plan), not the head"
else
    fail "progress_read: plan correlation (got $corr)"
fi

# ---- switch tests at plan-task's call site (Plan Authored) ----
MIS="$TMPD/issue-workspace-99"; mk_repo "$MIS" feature/issue-99
out=$(cd "$MIS" && printf '%s\n' "$ENTRY_PA" | WORKTREE_ISSUE=99 "$RP" persist --issue 7 --strict 2>&1); rc=$?
[[ "$rc" -eq 4 ]] && pass "plan-task strict: mismatched worktree aborts (rc 4)" || fail "plan-task strict mismatched (rc=$rc)"
out=$(cd "$MIS" && printf '%s\n' "$ENTRY_PA" | WORKTREE_ISSUE=99 "$RP" persist --issue 7 --title "Seven" 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == *"would have aborted"*"PROGRESS_PERSISTENCE_STRICT=0"* && "$(git -C "$MIS" log -1 --format=%s)" == "progress: plan authored for #7" ]] \
    && pass "plan-task compat: mismatched worktree completes with the notice, entry committed inline" || fail "plan-task compat (rc=$rc out=$out)"
MATCH="$TMPD/issue-workspace-8"; mk_repo "$MATCH" feature/issue-8
out=$(cd "$MATCH" && printf '%s\n' "${ENTRY_PA//issue-7/issue-8}" | "$RP" persist --issue 8 --title "Eight" 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" != *notice* ]] && pass "plan-task compat: matching worktree produces no notice" || fail "plan-task compat matching (rc=$rc out=$out)"

# ---- review-plan's non-fatal step 6: persist --soft ----
out=$(cd "$MIS" && printf '%s\n' "$ENTRY_PR" | WORKTREE_ISSUE=99 "$RP" persist --issue 7 --strict --soft 2>&1); rc=$?
if [[ "$rc" -eq 0 && "$out" == *"Progress persistence failed:"*"the report above is unaffected"* ]] \
    && ! grep -qs '^## Plan Review$' "$MIS/.agent/work-plans/issue-7/progress.md"; then
    pass "persist --soft: a resolver refusal becomes a notice with exit 0 and nothing written"
else
    fail "persist --soft failure path (rc=$rc out=$out)"
fi
out=$(cd "$MATCH" && printf '%s\n' "${ENTRY_PR//issue-7/issue-8}" | "$RP" persist --issue 8 --strict --soft 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == *"Progress persisted"* ]] && grep -q '^## Plan Review$' "$MATCH/.agent/work-plans/issue-8/progress.md" \
    && pass "persist --soft: a matching worktree writes the Plan Review entry normally" || fail "persist --soft success path (rc=$rc out=$out)"
# --soft also softens an invalid entry (review-plan must never fail after its report)
out=$(cd "$MATCH" && printf 'not an entry\n' | "$RP" persist --issue 8 --soft 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == *"Progress persistence failed:"* ]] && pass "persist --soft: a validation error is also non-fatal" || fail "persist --soft validation (rc=$rc out=$out)"

echo ""
echo "test_plan_correlation: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
