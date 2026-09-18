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
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT AGENT_NAME AGENT_EMAIL

NOW="2026-09-17 10:00 -04:00"

# ---------------------------------------------------------------- sandbox ---
# A workspace sandbox: the sandbox root is the main tree (ROOT_DIR resolves
# to it via `git worktree list`), with worktrees/workspace/issue-workspace-<N>
# as the issue's worktree — same shape merge_pr_gate's tests use.
mk_sandbox() {  # <issue-num>
    local n="$1" sb
    sb="$(mktemp -d)"
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
implementation() {  # <status> <mode: inline|"">
    local mode_line=""
    [[ -n "$2" ]] && mode_line=$'**Mode**: '"$2"$'\n'
    printf '## Implementation\n**Status**: %s\n**When**: %s\n**By**: t (m)\n%s**Branch**: feature/issue-9 at `2222222`\n' "$1" "$NOW" "$mode_line"
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
assert_next "row 3: a failed Implementation with Mode: inline maps to implement" none \
    "$(implementation failed inline)" checkpoint:phase-failed "phase=implement"
assert_next "row 3: a failed Implementation with no Mode maps to address-findings" none \
    "$(implementation failed "")" checkpoint:phase-failed "phase=address-findings"
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
assert_next "row 10: checkpoint plan answered proceed -> implement, mode=inline" none \
    "$(checkpoint plan proceed)" implement "mode=inline"
assert_next "row 11: checkpoint plan answered revise -> plan-task" none \
    "$(checkpoint plan revise)" plan-task

echo "TEST: next -- row 12 (Implementation -> review-code, mode note follows --pr)"
assert_next "row 12: Implementation with --pr none -> review-code (pre-push note)" none \
    "$(implementation complete inline)" review-code "pre-push"
assert_next "row 12: Implementation with --pr open -> review-code (PR mode note)" open \
    "$(implementation complete "")" review-code "PR mode"

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
assert_next "row 26: retry on the inline implementation pass -> implement, mode=inline" none \
    "$(checkpoint phase-failed retry implement)" implement "mode=inline"
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
step "$TL" none implement mode=inline
append "$TL" "$(implementation complete inline)"
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
append "$TL" "$(implementation complete "")"
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
    && "$out" == *"Never push"* ]] && pass "handoff: review-issue -- task line, sonnet, Issue Review, identity, worktree, exit contract" || fail "handoff review-issue (out=$out)"
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

echo ""
echo "test_dispatch_phase: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
