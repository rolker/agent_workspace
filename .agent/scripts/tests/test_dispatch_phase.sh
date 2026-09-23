#!/usr/bin/env bash
# .agent/scripts/tests/test_dispatch_phase.sh
# Tests for dispatch_phase.sh (issue #276 PR 2): the handoff block, the
# --check-exit exit-outcome check, and the `next` decision table (28 rows,
# one fixture per row plus five end-to-end timelines). Hermetic: mktemp -d
# sandboxes and --progress fixture files only; no `gh` involved (`next`
# never calls it).
# Run: bash .agent/scripts/tests/test_dispatch_phase.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DP="$SCRIPT_DIR/../dispatch_phase.sh"
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
# One sandbox for the whole run, created at top level (not inside $()) so
# the trap actually fires — see issue #297. mk_sandbox() carves per-test
# directories out of it with `mktemp -d -p "$SANDBOX"`, which needs no
# shared state and so survives being called as `sb="$(mk_sandbox 1)"`.
# $TMPD (the fixture scratch dir) is just a subdirectory of it.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
TMPD="$SANDBOX/fixtures"
mkdir -p "$TMPD"
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT AGENT_NAME AGENT_EMAIL

NOW="2026-09-17 10:00 -04:00"

# ---------------------------------------------------------------- sandbox ---
# A workspace sandbox: the sandbox root is the main tree (ROOT_DIR resolves
# to it via `git worktree list`), with worktrees/workspace/issue-workspace-<N>
# as the issue's worktree — same shape merge_pr_gate's tests use.
mk_sandbox() {  # <issue-num>
    local n="$1" sb
    sb="$(mktemp -d -p "$SANDBOX")"
    git -C "$sb" init -q -b main
    git -C "$sb" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    mkdir -p "$sb/.agent/scripts" "$sb/worktrees/workspace"
    for f in dispatch_phase.sh progress_read.py _worktree_helpers.sh _project_registry.sh; do
        cp "$SCRIPT_DIR/../$f" "$sb/.agent/scripts/"
    done
    git -C "$sb" worktree add -q "$sb/worktrees/workspace/issue-workspace-$n" -b "feature/issue-$n" >/dev/null 2>&1
    echo "$sb"
}

# ------------------------------------------------------------- next runner ---
# run_next <pr-state> <fixture-content> -- writes the fixture to a fresh file
# each call (hermetic) and runs `next --progress <file>`.
run_next() {
    local pr="$1" content="$2" f
    f="$TMPD/fixture_$$_$RANDOM.md"
    printf '%s\n' "$content" > "$f"
    bash "$DP" next --pr "$pr" --progress "$f" 2>&1
}

# assert_next <label> <pr> <fixture> <want-action> [must-contain...]
assert_next() {
    local label="$1" pr="$2" content="$3" want="$4"; shift 4
    local out rc ok=1 pat
    out=$(run_next "$pr" "$content"); rc=$?
    if [[ "$rc" -ne 0 || "$out" != "action=$want"* ]]; then
        fail "$label (rc=$rc out=${out:0:200})"
        return
    fi
    for pat in "$@"; do
        [[ "$out" == *"$pat"* ]] || ok=0
    done
    [[ "$ok" -eq 1 ]] && pass "$label" || fail "$label (missing pattern in: $out)"
}

# ----------------------------------------------------------- entry builders ---
issue_review() {  # <status> <actions-open 0|1>
    local box="- [x] fix the thing"
    [[ "$2" == 1 ]] && box="- [ ] fix the thing"
    printf '## Issue Review\n**Status**: %s\n**When**: %s\n**By**: t (m)\n**Issue**: #9\n\n### Actions\n%s\n### Consequences\n- [ ] distractor box outside Actions (must never count, PR1 review requirement)\n' \
        "$1" "$NOW" "$box"
}
plan_authored() {
    printf '## Plan Authored\n**Status**: %s\n**When**: %s\n**By**: t (m)\n**Plan**: `.agent/work-plans/issue-9/plan.md` at `1111111`\n' "$1" "$NOW"
}
plan_review() {
    printf '## Plan Review\n**Status**: %s\n**When**: %s\n**By**: t (m)\n**Verdict**: ready\n**Plan**: `.agent/work-plans/issue-9/plan.md` at `1111111`\n' "$1" "$NOW"
}
implementation() {  # <status> <kind: ""|addressed|takeover>
    # "" -- a dispatched post-plan implement pass; "addressed" -- an
    # address-findings pass (its required **Addressed** field is what
    # skill_for() discriminates on, issue #314); "takeover" -- an implement
    # pass the host took over (row 27 still stamps **Mode**: inline as an
    # informational marker, which no dispatcher reads any more).
    local extra=""
    case "${2:-}" in
        addressed) extra=$'**Addressed**: Local Review (Pre-Push) at `3333333` (2026-09-17 09:00 -04:00)\n' ;;
        empty-addressed) extra=$'**Addressed**:\n' ;;
        takeover)  extra=$'**Mode**: inline\n' ;;
    esac
    printf '## Implementation\n**Status**: %s\n**When**: %s\n**By**: t (m)\n%s**Branch**: feature/issue-9 at `2222222`\n' "$1" "$NOW" "$extra"
}
local_review_prepush() {  # <status> <verdict> <branch> <round-suffix-sha>
    printf '## Local Review (Pre-Push)\n**Status**: %s\n**When**: %s\n**By**: t (m)\n**Verdict**: %s\n**Branch**: %s at `%s`\n\n### Findings\n- [ ] No issues found. LGTM.\n' \
        "$1" "$NOW" "$2" "$3" "${4:-3333333}"
}
local_review_pr() {  # <status> <verdict> <box: open|clean|lgtm>
    local box="- [x] (must-fix) fixed already"
    case "$3" in
        open) box="- [ ] (must-fix) still open" ;;
        lgtm) box="- [ ] No issues found. LGTM." ;;
    esac
    printf '## Local Review\n**Status**: %s\n**When**: %s\n**By**: t (m)\n**Verdict**: %s\n**PR**: #9 at `4444444`\n\n### Findings\n%s\n' \
        "$1" "$NOW" "$2" "$box"
}
integrated_review() {  # <status> <box: open|clean>
    local box="- [x] (must-fix) fixed — \`x.sh\`"
    [[ "$2" == open ]] && box="- [ ] (must-fix) still open — \`x.sh\`"
    printf '## Integrated Review\n**Status**: %s\n**When**: %s\n**By**: t (m)\n**PR**: #9 at `5555555`\n\n### Findings\n%s\n' "$1" "$NOW" "$box"
}
merge_record() {  # <report-only|unreviewed>
    printf '## Merge (%s)\n**Status**: complete\n**When**: %s\n**By**: t (m)\n**PR**: #9 at `6666666`\n' "$1" "$NOW"
}
external_review() {  # <status>
    printf '## External Review\n**Status**: %s\n**When**: %s\n**By**: t (m)\n**PR**: #9 at `7777777`\n' "$1" "$NOW"
}
checkpoint() {  # <after> <decision> [phase]
    local phase_line=""
    [[ -n "${3:-}" ]] && phase_line=$'**Phase**: '"$3"$'\n'
    printf '## Checkpoint\n**Status**: complete\n**When**: %s\n**By**: t (m)\n**Decided-by**: owner\n**After**: %s\n%s**Decision**: %s\n' \
        "$NOW" "$1" "$phase_line" "$2"
}

echo "TEST: next -- exit codes and usage"
out=$(bash "$DP" next --pr bogus --issue 9 2>&1); rc=$?
[[ "$rc" -eq 2 ]] && pass "next: an out-of-vocabulary --pr value is a usage error (rc 2)" || fail "next bad --pr (rc=$rc out=$out)"
out=$(bash "$DP" next --issue 9 2>&1); rc=$?
[[ "$rc" -eq 2 ]] && pass "next: --pr is required (rc 2)" || fail "next missing --pr (rc=$rc)"
out=$(bash "$DP" next --pr none --progress "$TMPD/does_not_exist.md" 2>&1); rc=$?
[[ "$rc" -eq 2 && "$out" == *"not found"* ]] && pass "next: a named --progress path that is missing is rc 2 (not an empty timeline)" || fail "next missing --progress (rc=$rc out=$out)"
SB0="$(mk_sandbox 9)"
out=$(cd "$SB0" && bash .agent/scripts/dispatch_phase.sh next --pr none --issue 42 2>&1); rc=$?
[[ "$rc" -eq 2 && "$out" == *"no workspace worktree found"* ]] && pass "next: no worktree for --issue is rc 2" || fail "next no worktree (rc=$rc out=$out)"
out=$(cd "$SB0" && bash .agent/scripts/dispatch_phase.sh next --pr none --issue 9 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "action=review-issue"* ]] && pass "next: a missing progress.md in an EXISTING worktree is an empty timeline (row 4), not an error" || fail "next missing file in worktree (rc=$rc out=$out)"
out=$(run_next none $'## Implementation\n```\nunterminated fence'); rc=$?
[[ "$rc" -eq 3 && "$out" == *"malformed"* ]] && pass "next: an unparseable fixture is rc 3 (progress_read.py's exit 2 propagated)" || fail "next malformed (rc=$rc out=$out)"

echo "TEST: next -- row 1 (pr merged, checked before any file read)"
out=$(bash "$DP" next --pr merged --progress "$TMPD/never_read.md" 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "action=done"* ]] && pass "row 1: --pr merged short-circuits to done without touching the file" || fail "row1 (rc=$rc out=$out)"

echo "TEST: next -- row 2 (stop is absorbing)"
assert_next "row 2: Checkpoint stop with a phase -> done, names the phase" none \
    "$(checkpoint rounds stop)" "done" "reason=" "resume"
assert_next "row 2: Checkpoint stop after phase-failed carries **Phase** into the reason" none \
    "$(checkpoint phase-failed stop review-code)" "done" "phase=review-code"

echo "TEST: next -- row 3 (partial/failed newest entry is always a checkpoint)"
assert_next "row 3: a partial Plan Review maps to review-plan" none \
    "$(plan_review partial)" checkpoint:phase-failed "phase=review-plan"
assert_next "row 3: a failed Implementation carrying **Addressed** maps to address-findings" none \
    "$(implementation failed addressed)" checkpoint:phase-failed "phase=address-findings"
assert_next "row 3: a failed Implementation with no **Addressed** and no prior Implementation maps to implement (the dispatched post-plan pass)" none \
    "$(implementation failed "")" checkpoint:phase-failed "phase=implement"
assert_next "row 3: a failed Implementation with no **Addressed** but a prior COMPLETE Implementation maps to address-findings" none \
    "$(implementation complete "")
$(implementation failed "")" checkpoint:phase-failed "phase=address-findings"
DOUBLE_FAIL="$(implementation failed "")
$(checkpoint phase-failed retry implement)
$(implementation failed "")"
assert_next "skill_for: a SECOND consecutive failed implement still maps to implement -- a prior FAILED Implementation is not a completed one (ordinal position alone would misroute the retry)" none \
    "$DOUBLE_FAIL" checkpoint:phase-failed "phase=implement"
assert_next "skill_for: a taken-over implement pass (**Mode**: inline, no **Addressed**) still maps to implement" none \
    "$(implementation failed takeover)" checkpoint:phase-failed "phase=implement"
assert_next "skill_for: a present-but-EMPTY **Addressed** is not the signal -- it falls through to the prior-complete-Implementation test, same as an omitted field" none \
    "$(implementation failed empty-addressed)" checkpoint:phase-failed "phase=implement"
out=$(run_next none "$(external_review partial)")
if [[ "$out" == "action=checkpoint:phase-failed"* ]] && [[ "$out" != *"phase="* ]]; then
    pass "row 3: a partial External Review has no skill mapping -- checkpoint:phase-failed with no phase= line"
else
    fail "row 3 no-mapping type (out=$out)"
fi
assert_next "row 3: a phase-failed checkpoint with no **Phase** (from the no-mapping case above) routes to row 28 on its own next call" none \
    "$(checkpoint phase-failed retry)" checkpoint:unexpected

echo "TEST: next -- rows 4-6 (Issue Review)"
assert_next "row 4: no entries -> review-issue" none "" review-issue
assert_next "row 5: Issue Review with an open Actions box -> checkpoint:issue-actions (distractor under Consequences ignored)" none \
    "$(issue_review complete 1)" checkpoint:issue-actions
assert_next "row 6: Issue Review with no open Actions -> plan-task" none \
    "$(issue_review complete 0)" plan-task

echo "TEST: next -- row 7 (checkpoint issue-actions / proceed)"
assert_next "row 7: checkpoint issue-actions answered proceed -> plan-task" none \
    "$(checkpoint issue-actions proceed)" plan-task

echo "TEST: next -- rows 8-9 (Plan Authored / Plan Review)"
assert_next "row 8: Plan Authored -> review-plan" none "$(plan_authored complete)" review-plan
assert_next "row 9: Plan Review (any verdict) -> checkpoint:plan" none "$(plan_review complete)" checkpoint:plan

echo "TEST: next -- rows 10-11 (checkpoint plan)"
assert_next "row 10: checkpoint plan answered proceed -> implement (dispatched like every other phase, no mode=)" none \
    "$(checkpoint plan proceed)" implement
out=$(run_next none "$(checkpoint plan proceed)")
[[ "$out" != *"mode="* ]] && pass "row 10: implement carries no mode= line (issue #314: the implement pass is dispatched, not inline)" || fail "row 10 mode leak (out=$out)"
assert_next "row 11: checkpoint plan answered revise -> plan-task" none \
    "$(checkpoint plan revise)" plan-task

echo "TEST: next -- row 12 (Implementation -> review-code, mode note follows --pr)"
assert_next "row 12: Implementation with --pr none -> review-code (pre-push note)" none \
    "$(implementation complete "")" review-code "pre-push"
assert_next "row 12: Implementation with --pr open -> review-code (PR mode note)" open \
    "$(implementation complete addressed)" review-code "PR mode"

echo "TEST: next -- rows 13-15 (Local Review Pre-Push: Verdict routes, never open findings)"
assert_next "row 13: approved pre-push review -> checkpoint:publish, round=1 (LGTM box left unchecked, PR1 review requirement 2)" none \
    "$(local_review_prepush complete approved feature/issue-9)" checkpoint:publish "round=1"
THREE_ROUNDS="$(local_review_prepush complete changes-requested feature/issue-9 aaa1111)
$(local_review_prepush complete changes-requested feature/issue-9 bbb2222)
$(local_review_prepush complete changes-requested feature/issue-9 ccc3333)"
assert_next "row 14: the 3rd changes-requested round hits MAX_ROUNDS -> checkpoint:rounds, round=3" none \
    "$THREE_ROUNDS" checkpoint:rounds "round=3"
TWO_ROUNDS="$(local_review_prepush complete changes-requested feature/issue-9 aaa1111)
$(local_review_prepush complete changes-requested feature/issue-9 bbb2222)"
assert_next "row 15: round 2 of 3, not approved -> address-findings, round=2" none \
    "$TWO_ROUNDS" address-findings "round=2"
PARTIAL_PLUS_TWO="$(local_review_prepush partial changes-requested feature/issue-9 zzz0000)
$(local_review_prepush complete changes-requested feature/issue-9 aaa1111)
$(local_review_prepush complete changes-requested feature/issue-9 bbb2222)"
assert_next "round_count: a partial Pre-Push review on the branch does not count as a round -- 2 complete rounds, round=2, address-findings (not checkpoint:rounds at MAX_ROUNDS=3)" none \
    "$PARTIAL_PLUS_TWO" address-findings "round=2"

echo "TEST: next -- rows 16-18 (checkpoint publish/rounds)"
assert_next "row 16: checkpoint publish answered publish, --pr none -> publish" none \
    "$(checkpoint publish publish)" publish
assert_next "row 17: checkpoint publish answered publish, --pr draft -> triage-reviews" draft \
    "$(checkpoint publish publish)" triage-reviews
assert_next "row 17: checkpoint rounds answered publish, --pr open -> triage-reviews" open \
    "$(checkpoint rounds publish)" triage-reviews
assert_next "row 18: checkpoint rounds answered address -> address-findings" none \
    "$(checkpoint rounds address)" address-findings

echo "TEST: next -- rows 19-20 (Integrated Review)"
assert_next "row 19: Integrated Review with an open finding -> checkpoint:findings" open \
    "$(integrated_review complete open)" checkpoint:findings
assert_next "row 20: Integrated Review with no open finding -> checkpoint:merge" open \
    "$(integrated_review complete clean)" checkpoint:merge

echo "TEST: next -- rows 21-22 (checkpoint findings/merge)"
assert_next "row 21: checkpoint findings answered merge -> merge" open \
    "$(checkpoint findings merge)" merge
assert_next "row 22: checkpoint merge answered address -> address-findings" open \
    "$(checkpoint merge address)" address-findings

echo "TEST: next -- rows 22a-22b (Local Review, PR-mode re-review: routes on Verdict, not open boxes -- plan defect fixed post-review)"
assert_next "row 22a: PR-mode Local Review changes-requested with an open finding -> address-findings" open \
    "$(local_review_pr complete changes-requested open)" address-findings
assert_next "row 22b: PR-mode Local Review approved with the unchecked LGTM placeholder -> triage-reviews (verdict overrides the open box)" open \
    "$(local_review_pr complete approved lgtm)" triage-reviews

echo "TEST: next -- row 23 (a merge that did not end merged)"
assert_next "row 23: Merge (report-only) -> checkpoint:merge-refused" open \
    "$(merge_record report-only)" checkpoint:merge-refused
assert_next "row 23: Merge (unreviewed) -> checkpoint:merge-refused" open \
    "$(merge_record unreviewed)" checkpoint:merge-refused

echo "TEST: next -- rows 24-25 (checkpoint merge-refused)"
assert_next "row 24: checkpoint merge-refused answered retriage -> triage-reviews" open \
    "$(checkpoint merge-refused retriage)" triage-reviews
assert_next "row 25: checkpoint merge-refused answered address -> address-findings" open \
    "$(checkpoint merge-refused address)" address-findings

echo "TEST: next -- rows 26-27 (checkpoint phase-failed retry/takeover)"
assert_next "row 26: retry on a non-implement phase -> that skill token, no mode=" none \
    "$(checkpoint phase-failed retry review-code)" review-code
out=$(run_next none "$(checkpoint phase-failed retry review-code)")
[[ "$out" != *"mode="* ]] && pass "row 26: retry on review-code carries no mode= line" || fail "row 26 mode leak (out=$out)"
assert_next "row 26: retry on the implement phase -> implement, no mode= (issue #314: re-dispatched, not run inline)" none \
    "$(checkpoint phase-failed retry implement)" implement
out=$(run_next none "$(checkpoint phase-failed retry implement)")
[[ "$out" != *"mode="* ]] && pass "row 26: retry on implement carries no mode= line" || fail "row 26 implement mode leak (out=$out)"
assert_next "row 27: takeover always carries mode=inline (the host runs the phase itself)" none \
    "$(checkpoint phase-failed takeover review-plan)" review-plan "mode=inline"

echo "TEST: next -- row 28 (no row matches)"
assert_next "row 28: a clean External Review is a read-only predecessor for --type filtering only -- next itself has no row for it" open \
    "$(external_review complete)" checkpoint:unexpected
assert_next "row 28: a Checkpoint with an out-of-vocabulary Decision for its After" none \
    "$(checkpoint plan bogus-decision)" checkpoint:unexpected
assert_next "row 28: a Checkpoint whose After no row names" none \
    "$(checkpoint totally-unknown proceed)" checkpoint:unexpected

echo ""
echo "TEST: next -- five end-to-end timelines (must never hit row 28)"

# (A) clean run to merge
TL="$TMPD/timeline_a.md"
step() {  # <file> <pr> <want-action> [want-pattern...]
    local f="$1" pr="$2" want="$3"; shift 3
    local out rc ok=1 pat
    out=$(bash "$DP" next --pr "$pr" --progress "$f" 2>&1); rc=$?
    if [[ "$rc" -ne 0 || "$out" != "action=$want"* ]]; then
        fail "timeline step expected action=$want (rc=$rc out=${out:0:200})"; TIMELINE_OK=0; return
    fi
    for pat in "$@"; do [[ "$out" == *"$pat"* ]] || ok=0; done
    [[ "$ok" -eq 1 ]] || { fail "timeline step action=$want missing pattern (out=$out)"; TIMELINE_OK=0; }
}
append() { local f="$1"; shift; printf '%s\n\n' "$*" >> "$f"; }

: > "$TL"
TIMELINE_OK=1
step "$TL" none review-issue
append "$TL" "$(issue_review complete 0)"
step "$TL" none plan-task
append "$TL" "$(plan_authored complete)"
step "$TL" none review-plan
append "$TL" "$(plan_review complete)"
step "$TL" none checkpoint:plan
append "$TL" "$(checkpoint plan proceed)"
step "$TL" none implement
append "$TL" "$(implementation complete "")"
step "$TL" none review-code pre-push
append "$TL" "$(local_review_prepush complete approved feature/issue-9)"
step "$TL" none checkpoint:publish
append "$TL" "$(checkpoint publish publish)"
step "$TL" none publish
step "$TL" open triage-reviews
append "$TL" "$(integrated_review complete clean)"
step "$TL" open checkpoint:merge
append "$TL" "$(checkpoint merge merge)"
step "$TL" open merge
step "$TL" merged "done"
[[ "$TIMELINE_OK" -eq 1 ]] && pass "timeline A: clean run to merge, every step matched, never hit row 28" || fail "timeline A had a mismatch (see above)"

# (B) needs-work plan then revise
TL="$TMPD/timeline_b.md"; TIMELINE_OK=1
printf '%s\n\n' "$(plan_review complete)" > "$TL"
step "$TL" none checkpoint:plan
append "$TL" "$(checkpoint plan revise)"
step "$TL" none plan-task
[[ "$TIMELINE_OK" -eq 1 ]] && pass "timeline B: needs-work plan then revise routes back to plan-task" || fail "timeline B had a mismatch"

# (C) three pre-push rounds then stop
TL="$TMPD/timeline_c.md"; TIMELINE_OK=1
: > "$TL"
append "$TL" "$(local_review_prepush complete changes-requested feature/issue-9 aaa1111)"
step "$TL" none address-findings round=1
append "$TL" "$(local_review_prepush complete changes-requested feature/issue-9 bbb2222)"
step "$TL" none address-findings round=2
append "$TL" "$(local_review_prepush complete changes-requested feature/issue-9 ccc3333)"
step "$TL" none checkpoint:rounds round=3
append "$TL" "$(checkpoint rounds stop)"
step "$TL" none "done"
[[ "$TIMELINE_OK" -eq 1 ]] && pass "timeline C: three pre-push rounds without approval end at checkpoint:rounds, then stop" || fail "timeline C had a mismatch"

# (D) stop then --resume: a fresh Checkpoint with the same After but a new
# Decision routes normally -- the absorbing stop is not sticky once replaced.
TL="$TMPD/timeline_d.md"; TIMELINE_OK=1
cp "$TMPD/timeline_c.md" "$TL"
step "$TL" none "done"
append "$TL" "$(checkpoint rounds address)"
step "$TL" none address-findings
[[ "$TIMELINE_OK" -eq 1 ]] && pass "timeline D: --resume records a fresh Checkpoint under the same After; routes normally again" || fail "timeline D had a mismatch"

# (E) publish with the --pr flip none -> open into row 17, then a fix round
# through rows 22, 12, 22b, 20.
TL="$TMPD/timeline_e.md"; TIMELINE_OK=1
printf '%s\n\n' "$(checkpoint publish publish)" > "$TL"
step "$TL" none publish
step "$TL" open triage-reviews
append "$TL" "$(integrated_review complete open)"
step "$TL" open checkpoint:findings
append "$TL" "$(checkpoint findings address)"
step "$TL" open address-findings
append "$TL" "$(implementation complete addressed)"
step "$TL" open review-code "PR mode"
append "$TL" "$(local_review_pr complete approved clean)"
step "$TL" open triage-reviews
append "$TL" "$(integrated_review complete clean)"
step "$TL" open checkpoint:merge
[[ "$TIMELINE_OK" -eq 1 ]] && pass "timeline E: publish PR-flip into row 17, fix round through rows 22/12/22b/20" || fail "timeline E had a mismatch"

echo ""
echo "TEST: handoff -- literal task line, identity, model, entry type per skill"
SB="$(mk_sandbox 9)"
run_handoff() {  # [args...]
    (cd "$SB" && AGENT_NAME="Claude Code Agent" AGENT_EMAIL="roland+claude-code@rolker.net" bash .agent/scripts/dispatch_phase.sh "$@" 2>&1)
}
out=$(run_handoff --issue 9 --skill review-issue)
[[ "$out" == *"task=/review-issue 9"* && "$out" == *"model=sonnet"* && "$out" == *"entry_type=Issue Review"* \
    && "$out" == *"agent_name=Claude Code Agent"* && "$out" == *"agent_email=roland+claude-code@rolker.net"* \
    && "$out" == *"worktree=$SB/worktrees/workspace/issue-workspace-9"* \
    && "$out" == *"Never push"* \
    && "$out" == *"conventions="*"local time with offset"*"scratchpad"* ]] \
    && pass "handoff: review-issue -- task line, sonnet, Issue Review, identity, worktree, exit contract, conventions" || fail "handoff review-issue (out=$out)"
out=$(run_handoff --issue 9 --skill plan-task)
[[ "$out" == *"task=/plan-task 9 --no-pr"* && "$out" == *"model=sonnet"* && "$out" == *"entry_type=Plan Authored"* ]] \
    && pass "handoff: plan-task -- --no-pr is pinned, sonnet, Plan Authored" || fail "handoff plan-task (out=$out)"
out=$(run_handoff --issue 9 --skill review-plan)
[[ "$out" == *"task=/review-plan --issue 9"* && "$out" == *"model=opus"* && "$out" == *"entry_type=Plan Review"* ]] \
    && pass "handoff: review-plan -- opus, Plan Review" || fail "handoff review-plan (out=$out)"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *"task=/review-code --branch --issue 9"* && "$out" == *"entry_type=Local Review (Pre-Push)"* ]] \
    && pass "handoff: review-code without --pr -- branch mode task line, Local Review (Pre-Push)" || fail "handoff review-code branch (out=$out)"
out=$(run_handoff --issue 9 --skill review-code --pr 42)
[[ "$out" == *"task=/review-code 42"* && "$out" == *"entry_type=Local Review"$'\n'* ]] \
    && pass "handoff: review-code with --pr -- PR-mode task line, Local Review (not Pre-Push)" || fail "handoff review-code pr (out=$out)"
out=$(run_handoff --issue 9 --skill triage-reviews --pr 42)
[[ "$out" == *"task=/triage-reviews 42"* && "$out" == *"model=opus"* && "$out" == *"entry_type=Integrated Review"* ]] \
    && pass "handoff: triage-reviews -- opus, Integrated Review" || fail "handoff triage-reviews (out=$out)"
out=$(run_handoff --issue 9 --skill triage-reviews); rc=$?
[[ "$rc" -eq 2 && "$out" == *"requires --pr"* ]] && pass "handoff: triage-reviews without --pr is a usage error (rc 2)" || fail "handoff triage-reviews no pr (rc=$rc out=$out)"
out=$(run_handoff --issue 9 --skill address-findings)
[[ "$out" == *"task=/address-findings --issue 9"* && "$out" == *"model=opus"* && "$out" == *"entry_type=Implementation"* ]] \
    && pass "handoff: address-findings -- opus, Implementation" || fail "handoff address-findings (out=$out)"

out=$(run_handoff --issue 9 --skill implement)
[[ "$out" == *"task=implement the plan at .agent/work-plans/issue-9/plan.md on this branch"* \
    && "$out" == *"model=opus"* && "$out" == *"entry_type=Implementation"* ]] \
    && pass "handoff: implement -- literal task line (no /implement slash command), opus, Implementation" || fail "handoff implement (out=$out)"
[[ "$out" == *"progress_append.sh 9"* && "$out" == *'**Branch**: <name> at <sha>'* && "$out" == *"Commit your work"* ]] \
    && pass "handoff: implement's exit contract names progress_append.sh, the correlation line, and that the agent commits (plan review finding 1)" || fail "handoff implement exit contract (out=$out)"

out=$(run_handoff --issue 9 --skill review-issue --entry-type "Custom Type" --model haiku)
[[ "$out" == *"entry_type=Custom Type"* && "$out" == *"model=haiku"* ]] \
    && pass "handoff: --entry-type / --model override the table" || fail "handoff overrides (out=$out)"
out=$(cd "$SB" && bash .agent/scripts/dispatch_phase.sh --issue 9 --skill review-issue 2>&1); rc=$?
[[ "$rc" -eq 2 && "$out" == *"AGENT_NAME"* ]] && pass "handoff: no fallback to the human git config -- AGENT_NAME/AGENT_EMAIL unset is a usage error" || fail "handoff no identity (rc=$rc out=$out)"
out=$(run_handoff --issue 9 --skill not-a-real-skill); rc=$?
[[ "$rc" -eq 2 && "$out" == *"unknown --skill"* ]] && pass "handoff: an unknown --skill is a usage error" || fail "handoff unknown skill (rc=$rc out=$out)"
out=$(run_handoff --issue 999 --skill review-issue); rc=$?
[[ "$rc" -eq 2 && "$out" == *"no workspace worktree found"* ]] && pass "handoff: no worktree for --issue is a usage error" || fail "handoff no worktree (rc=$rc out=$out)"

echo ""
echo "TEST: resolve_worktree -- --type project (registry lookup, then the deprecated project/worktrees fallback)"
# (a) registry lookup: one registered project, resolved via registry_worktree_dir
# (default <path>/worktrees, no worktrees= override).
SBP1="$(mktemp -d -p "$SANDBOX")"
git -C "$SBP1" init -q -b main
git -C "$SBP1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
mkdir -p "$SBP1/.agent/scripts"
for f in dispatch_phase.sh progress_read.py _worktree_helpers.sh _project_registry.sh; do
    cp "$SCRIPT_DIR/../$f" "$SBP1/.agent/scripts/"
done
mkdir -p "$SBP1/myproj/worktrees/issue-9"
printf 'myproj\tsingle_project\t%s\n' "$SBP1/myproj" > "$SBP1/.agent/projects.local"
out=$(cd "$SBP1" && AGENT_NAME=t AGENT_EMAIL=t@t bash .agent/scripts/dispatch_phase.sh --issue 9 --skill review-issue --type project 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == *"worktree=$SBP1/myproj/worktrees/issue-9"* ]] \
    && pass "resolve_worktree --type project: a single registered project resolves via registry_worktree_dir" || fail "resolve_worktree project registry (rc=$rc out=$out)"

# (b) the deprecated project/worktrees fallback (wt_legacy_project_base): no
# registry entry at all, worktree living inside a project/ checkout's own
# worktrees/ dir (the pre-#265 shape).
SBP2="$(mktemp -d -p "$SANDBOX")"
git -C "$SBP2" init -q -b main
git -C "$SBP2" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
mkdir -p "$SBP2/.agent/scripts"
for f in dispatch_phase.sh progress_read.py _worktree_helpers.sh _project_registry.sh; do
    cp "$SCRIPT_DIR/../$f" "$SBP2/.agent/scripts/"
done
mkdir -p "$SBP2/project/worktrees/issue-9"
out=$(cd "$SBP2" && AGENT_NAME=t AGENT_EMAIL=t@t bash .agent/scripts/dispatch_phase.sh --issue 9 --skill review-issue --type project 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == *"worktree=$SBP2/project/worktrees/issue-9"* ]] \
    && pass "resolve_worktree --type project: no registry entry -- falls back to the deprecated project/worktrees/ shape" || fail "resolve_worktree project legacy fallback (rc=$rc out=$out)"

echo ""
echo "TEST: --check-exit -- OK/PARTIAL/FAILED/MISSING per expected type"
SBX="$(mk_sandbox 9)"
WT="$SBX/worktrees/workspace/issue-workspace-9"
mkdir -p "$WT/.agent/work-plans/issue-9"
write_progress_commit() {  # <content>
    printf '%s\n' "$1" > "$WT/.agent/work-plans/issue-9/progress.md"
    git -C "$WT" add -A && git -C "$WT" -c user.name=t -c user.email=t@t commit -q -m "progress"
}
out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill review-issue --before 0 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "status=MISSING" ]] && pass "check-exit: no progress.md at all -- MISSING" || fail "check-exit missing file (rc=$rc out=$out)"
write_progress_commit "$(issue_review complete 0)"
out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill review-issue --before 0 2>&1); rc=$?
sha=$(git -C "$WT" rev-parse --short HEAD)
[[ "$rc" -eq 0 && "$out" == "status=OK"$'\n'"sha=$sha" ]] && pass "check-exit: a complete entry of the expected type -- OK with the worktree HEAD sha" || fail "check-exit OK (rc=$rc out=$out want-sha=$sha)"
out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill review-issue --before 1 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "status=MISSING" ]] && pass "check-exit: --before equal to the current count -- MISSING (no new entry)" || fail "check-exit before=count (rc=$rc out=$out)"
write_progress_commit "$(issue_review complete 0)
$(plan_authored partial)"
out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill plan-task --before 0 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "status=PARTIAL" ]] && pass "check-exit: a partial Plan Authored entry -- PARTIAL" || fail "check-exit PARTIAL (rc=$rc out=$out)"
write_progress_commit "$(issue_review complete 0)
$(plan_authored failed)"
out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill plan-task --before 0 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "status=FAILED" ]] && pass "check-exit: a failed Plan Authored entry -- FAILED" || fail "check-exit FAILED (rc=$rc out=$out)"
write_progress_commit "$(issue_review complete 0)
$(local_review_pr complete approved clean)"
out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill review-code --pr 9 --before 0 2>&1); rc=$?
sha=$(git -C "$WT" rev-parse --short HEAD)
[[ "$rc" -eq 0 && "$out" == "status=OK"$'\n'"sha=$sha" ]] && pass "check-exit: review-code PR mode expects Local Review, not Local Review (Pre-Push)" || fail "check-exit review-code pr mode (rc=$rc out=$out)"
out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill review-code --before 0 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "status=MISSING" ]] && pass "check-exit: review-code without --pr expects Local Review (Pre-Push), which isn't present -- MISSING" || fail "check-exit review-code branch mode (rc=$rc out=$out)"
out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill triage-reviews --before 0 2>&1); rc=$?
[[ "$rc" -eq 2 && "$out" == *"requires --pr"* ]] && pass "check-exit: triage-reviews without --pr is a usage error" || fail "check-exit triage-reviews no pr (rc=$rc out=$out)"

# The **PR**/**Branch** correlation line is required of `## Implementation`
# (both handoffs' exit contracts; merge_pr.sh's head-vs-review gate). A
# complete entry without it is PARTIAL, not OK.
implementation_nocorr() {  # <status>
    printf '## Implementation\n**Status**: %s\n**When**: %s\n**By**: t (m)\n\nwhat changed\n' "$1" "$NOW"
}
write_progress_commit "$(implementation_nocorr complete)"
for sk in implement address-findings; do
    out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill "$sk" --before 0 2>&1); rc=$?
    [[ "$rc" -eq 0 && "$out" == "status=PARTIAL"* && "$out" == *"correlation line"* ]] \
        && pass "check-exit: --skill $sk -- a complete ## Implementation with no **PR**/**Branch** correlation line is PARTIAL with a reason=" \
        || fail "check-exit $sk missing correlation (rc=$rc out=$out)"
done
write_progress_commit "$(implementation complete "")"
out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill implement --before 0 2>&1); rc=$?
sha=$(git -C "$WT" rev-parse --short HEAD)
[[ "$rc" -eq 0 && "$out" == "status=OK"$'\n'"sha=$sha" ]] \
    && pass "check-exit: --skill implement -- a complete ## Implementation WITH the **Branch** correlation line is OK" || fail "check-exit implement with correlation (rc=$rc out=$out)"
write_progress_commit "$(plan_authored complete)"
out=$(cd "$SBX" && bash .agent/scripts/dispatch_phase.sh --check-exit --issue 9 --skill plan-task --before 0 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "status=OK"* ]] \
    && pass "check-exit: the correlation check is scoped to the ## Implementation writers -- other skills are untouched" || fail "check-exit correlation scope (rc=$rc out=$out)"

# ------------------------------------------- --project / $PWD resolution ---
# #317 (#265 PR 3): `--type project` used to resolve a worktree only when
# exactly one project was registered. These cases cover the explicit
# --project name, the $PWD-derived name (1 and 3 registered projects), and
# the unresolvable-cwd fallback that preserves the historical behaviour.
# Hermetic: every registry path is inside $SANDBOX; HOME is redirected so
# nothing reads or writes the real ~/.claude.
mk_project_sandbox() {  # <issue-num> <project-name>... -- first name owns the issue worktree
    local n="$1"; shift
    local sb first="$1" name
    sb="$(mktemp -d -p "$SANDBOX")"
    git -C "$sb" init -q -b main
    git -C "$sb" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    mkdir -p "$sb/.agent/scripts" "$sb/worktrees/workspace" "$sb/.agent/project_types"
    cp -r "$SCRIPT_DIR/../../project_types/single_project" "$sb/.agent/project_types/"
    for f in dispatch_phase.sh progress_read.py _worktree_helpers.sh _project_registry.sh; do
        cp "$SCRIPT_DIR/../$f" "$sb/.agent/scripts/"
    done
    : > "$sb/.agent/projects.local"
    for name in "$@"; do
        mkdir -p "$sb/roots/$name"
        git -C "$sb/roots/$name" init -q -b main
        git -C "$sb/roots/$name" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
        echo "$name single_project $sb/roots/$name" >> "$sb/.agent/projects.local"
    done
    # The issue's worktree for the FIRST named project, at that project's
    # own registry-resolved worktree dir (<root>/worktrees).
    mkdir -p "$sb/roots/$first/worktrees"
    git -C "$sb/roots/$first" worktree add -q "$sb/roots/$first/worktrees/issue-$first-$n" -b "feature/issue-$n" >/dev/null 2>&1
    echo "$sb"
}

# dispatch_project <sandbox> <cwd> <issue> [--project <name>] -- prints the
# handoff's worktree= line (or the error), plus the exit code on the last line.
dispatch_project() {
    local sb="$1" cwd="$2" issue="$3"; shift 3
    local out rc
    out=$(cd "$cwd" && HOME="$sb/home" AGENT_NAME=t AGENT_EMAIL=t@t \
        bash "$sb/.agent/scripts/dispatch_phase.sh" --issue "$issue" --skill plan-task \
        --type project "$@" 2>&1); rc=$?
    printf '%s\n%s\n' "$out" "rc=$rc"
}

PSB=$(mk_project_sandbox 41 beta gamma delta)
mkdir -p "$PSB/home"
# Give gamma a worktree for the same issue too, so the enumeration the
# historical branch uses sees TWO candidate projects. That ambiguity is
# exactly the case that made `/run-issue <N> --type project` fail on a
# machine with several registered projects (#317, plan review finding 1).
mkdir -p "$PSB/roots/gamma/worktrees"
git -C "$PSB/roots/gamma" worktree add -q "$PSB/roots/gamma/worktrees/issue-gamma-41" -b "feature/issue-41" >/dev/null 2>&1

out=$(dispatch_project "$PSB" "$PSB" 41 --project beta)
[[ "$out" == *"worktree=$PSB/roots/beta/worktrees/issue-beta-41"* && "$out" == *"rc=0"* ]] \
    && pass "--project names the project with 3 registered" \
    || fail "--project named (out=$out)"

out=$(dispatch_project "$PSB" "$PSB/roots/beta" 41)
[[ "$out" == *"worktree=$PSB/roots/beta/worktrees/issue-beta-41"* && "$out" == *"rc=0"* ]] \
    && pass "\$PWD at a registered root derives the project (3 registered)" \
    || fail "\$PWD derived, 3 registered (out=$out)"

# A cwd deeper inside the root resolves the same way (ancestor match).
mkdir -p "$PSB/roots/beta/src/deep"
out=$(dispatch_project "$PSB" "$PSB/roots/beta/src/deep" 41)
[[ "$out" == *"worktree=$PSB/roots/beta/worktrees/issue-beta-41"* && "$out" == *"rc=0"* ]] \
    && pass "\$PWD deep inside a registered root derives the project" \
    || fail "\$PWD derived from a subdirectory (out=$out)"

# An unresolvable cwd with two candidate projects stays ambiguous -- the
# historical "exactly one registered" branch cannot pick one, so no
# worktree. This is the pre-#317 failure mode, preserved for callers that
# give neither a name nor a resolvable cwd.
out=$(dispatch_project "$PSB" "$SANDBOX" 41)
[[ "$out" == *"no project worktree found"* && "$out" == *"rc=2"* ]] \
    && pass "unresolvable cwd with two candidate projects: no worktree (unchanged)" \
    || fail "unresolvable cwd, ambiguous (out=$out)"

# ...and both disambiguators fix it, each selecting a different project.
out=$(dispatch_project "$PSB" "$SANDBOX" 41 --project gamma)
[[ "$out" == *"worktree=$PSB/roots/gamma/worktrees/issue-gamma-41"* && "$out" == *"rc=0"* ]] \
    && pass "--project disambiguates two candidate projects" \
    || fail "--project gamma (out=$out)"
out=$(dispatch_project "$PSB" "$PSB/roots/gamma" 41)
[[ "$out" == *"worktree=$PSB/roots/gamma/worktrees/issue-gamma-41"* && "$out" == *"rc=0"* ]] \
    && pass "\$PWD disambiguates two candidate projects" \
    || fail "\$PWD gamma (out=$out)"

# An explicit name that is not registered finds nothing -- same miss path.
out=$(dispatch_project "$PSB" "$PSB" 41 --project nosuch)
[[ "$out" == *"no project worktree found"* && "$out" == *"rc=2"* ]] \
    && pass "--project with an unregistered name: no worktree" \
    || fail "--project unregistered (out=$out)"

PSB1=$(mk_project_sandbox 42 solo)
mkdir -p "$PSB1/home"

out=$(dispatch_project "$PSB1" "$PSB1/roots/solo" 42)
[[ "$out" == *"worktree=$PSB1/roots/solo/worktrees/issue-solo-42"* && "$out" == *"rc=0"* ]] \
    && pass "\$PWD derives the project with 1 registered" \
    || fail "\$PWD derived, 1 registered (out=$out)"

# The pre-#317 behaviour: no --project, cwd outside every root, exactly one
# project registered -- still resolves via the "exactly one" branch.
out=$(dispatch_project "$PSB1" "$SANDBOX" 42)
[[ "$out" == *"worktree=$PSB1/roots/solo/worktrees/issue-solo-42"* && "$out" == *"rc=0"* ]] \
    && pass "unresolvable cwd with exactly 1 registered: historical fallback still resolves" \
    || fail "unresolvable cwd, 1 registered (out=$out)"

# --project is accepted (and inert) on check-exit and next as well.
out=$(cd "$PSB" && HOME="$PSB/home" bash "$PSB/.agent/scripts/dispatch_phase.sh" \
    --check-exit --issue 41 --skill plan-task --type project --project beta --before 0 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "status=MISSING" ]] \
    && pass "check-exit accepts --project" || fail "check-exit --project (rc=$rc out=$out)"
out=$(cd "$PSB" && HOME="$PSB/home" bash "$PSB/.agent/scripts/dispatch_phase.sh" \
    next --issue 41 --pr none --type project --project beta 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "action="* ]] \
    && pass "next accepts --project" || fail "next --project (rc=$rc out=$out)"

# --- a `worktrees=` override: the cwd is under no hosting dir ---------------
# Round 1 suggestion: registry_resolve_from_dir matches hosting dirs, so a
# session inside a worktree that a `worktrees=` override placed elsewhere
# (commonly back under the workspace root) derived nothing and, with several
# projects registered, reported "no project worktree found" while standing in
# the worktree.
PSBW="$(mktemp -d -p "$SANDBOX")"
git -C "$PSBW" init -q -b main
git -C "$PSBW" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
mkdir -p "$PSBW/.agent/scripts" "$PSBW/.agent/project_types" "$PSBW/home"
cp -r "$SCRIPT_DIR/../../project_types/single_project" "$PSBW/.agent/project_types/"
for f in dispatch_phase.sh progress_read.py _worktree_helpers.sh _project_registry.sh; do
    cp "$SCRIPT_DIR/../$f" "$PSBW/.agent/scripts/"
done
: > "$PSBW/.agent/projects.local"
for n in one two; do
    mkdir -p "$PSBW/roots/$n"
    git -C "$PSBW/roots/$n" init -q -b main
    git -C "$PSBW/roots/$n" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    # worktrees live under the WORKSPACE root, not under the project root
    mkdir -p "$PSBW/wt/$n"
    echo "$n single_project $PSBW/roots/$n worktrees=$PSBW/wt/$n" >> "$PSBW/.agent/projects.local"
done
git -C "$PSBW/roots/two" worktree add -q "$PSBW/wt/two/issue-two-55" -b "feature/issue-55" >/dev/null 2>&1

out=$(cd "$PSBW/wt/two/issue-two-55" && HOME="$PSBW/home" AGENT_NAME=t AGENT_EMAIL=t@t \
    bash "$PSBW/.agent/scripts/dispatch_phase.sh" --issue 55 --skill plan-task --type project 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == *"worktree=$PSBW/wt/two/issue-two-55"* ]] \
    && pass "a cwd inside a worktrees=-override worktree derives its project" \
    || fail "worktrees= override not derived (rc=$rc out=${out:0:200})"

# The hosting dir still wins when the cwd is there instead.
out=$(cd "$PSBW/roots/two" && HOME="$PSBW/home" AGENT_NAME=t AGENT_EMAIL=t@t \
    bash "$PSBW/.agent/scripts/dispatch_phase.sh" --issue 55 --skill plan-task --type project 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == *"worktree=$PSBW/wt/two/issue-two-55"* ]] \
    && pass "the hosting dir still resolves with a worktrees= override in play" \
    || fail "hosting dir with override (rc=$rc out=${out:0:200})"

# An explicit --project still wins over the derivation.
out=$(cd "$PSBW/wt/two/issue-two-55" && HOME="$PSBW/home" AGENT_NAME=t AGENT_EMAIL=t@t \
    bash "$PSBW/.agent/scripts/dispatch_phase.sh" --issue 55 --skill plan-task --type project --project one 2>&1); rc=$?
[[ "$rc" -eq 2 ]] \
    && pass "an explicit --project still overrides the worktree-derived name" \
    || fail "explicit --project did not override the derivation (rc=$rc out=${out:0:160})"

echo ""
echo "test_dispatch_phase: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
