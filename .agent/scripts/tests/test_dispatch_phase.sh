#!/usr/bin/env bash
# .agent/scripts/tests/test_dispatch_phase.sh
# Tests for dispatch_phase.sh (issue #276 PR 2): the handoff block, the
# --check-exit exit-outcome check, and the `next` decision table (28 rows,
# one fixture per row plus five end-to-end timelines; row 3a and the
# pr_start.py boundary of issue 459 with their own fixtures and timelines). Hermetic: mktemp -d
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
    for f in dispatch_phase.sh progress_read.py pr_start.py review_progress.sh _worktree_helpers.sh _project_registry.sh _resolve_default_branch.sh _resolve_work_plans_dir.sh; do
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

# step <file> <pr> <want-action> [want-pattern...] -- one step of a growing
# timeline file; append <file> <entry> adds the next entry to it.
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
integrated_review_n() {  # <number> -- a clean Integrated Review of pull request #<number>
    printf '## Integrated Review\n**Status**: complete\n**When**: %s\n**By**: t (m)\n**PR**: #%s at `5555555`\n\n### Findings\n- [x] (must-fix) fixed\n' "$NOW" "$1"
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
[[ "$out" == *"this run is over"*"run /run-issue 42 to start the next part, or nothing if the issue is closed"* ]] \
    && pass "next: no worktree with --pr none (a run asking again after its own merge) says what to do: /run-issue <N> for the next part (issue 459)" \
    || fail "next no worktree hint (out=$out)"
out=$(cd "$SB0" && bash .agent/scripts/dispatch_phase.sh next --pr open --issue 42 2>&1); rc=$?
[[ "$rc" -eq 2 && "$out" == *"no workspace worktree found"* && "$out" != *"this run is over"* ]] \
    && pass "next: no worktree with --pr open is the plain rc-2 error (no merge hint)" || fail "next no worktree --pr open (rc=$rc out=$out)"
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
FAILED_PLUS_TWO="$(local_review_prepush complete changes-requested feature/issue-9 aaa1111)
$(local_review_prepush failed changes-requested feature/issue-9 zzz0000)
$(local_review_prepush complete changes-requested feature/issue-9 bbb2222)"
assert_next "round_count: a failed Pre-Push review between two complete ones does not count -- round=2, address-findings" none \
    "$FAILED_PLUS_TWO" address-findings "round=2"

RESTART_THEN_ONE="$THREE_ROUNDS
$(checkpoint rounds restart)
$(issue_review complete 0)
$(plan_authored complete)
$(plan_review complete)
$(checkpoint plan proceed)
$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9 ddd4444)"
assert_next "round_count: a restart checkpoint starts the rounds over -- three reviews, restart, one review of the new work: round=1, address-findings (not checkpoint:rounds)" none \
    "$RESTART_THEN_ONE" address-findings "round=1"
assert_next "round_count: after a restart, the new work reaches MAX_ROUNDS only on its own third review" none \
    "$RESTART_THEN_ONE
$(local_review_prepush complete changes-requested feature/issue-9 eee5555)
$(local_review_prepush complete changes-requested feature/issue-9 fff6666)" checkpoint:rounds "round=3"

echo "TEST: next -- skill_for after a restart (a failed first implement of the new work)"
RESTART_THEN_FAILED_IMPL="$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9 aaa1111)
$(implementation complete addressed)
$(checkpoint rounds restart)
$(issue_review complete 0)
$(plan_authored complete)
$(plan_review complete)
$(checkpoint plan proceed)
$(implementation failed "")"
assert_next "skill_for: after a restart, a failed implement with no **Addressed** maps to implement -- the complete Implementations before the restart do not count" none \
    "$RESTART_THEN_FAILED_IMPL" checkpoint:phase-failed "phase=implement"
# The retry checkpoint's **Phase** is what `next` printed for the failed
# pass, as the real loop records it (run-issue step 6), never a hard-coded
# value: on the pre-fix script `next` printed phase=address-findings, so
# the retry dispatched address-findings and this case fails there.
RETRY_PHASE="$(run_next none "$RESTART_THEN_FAILED_IMPL" | sed -n 's/^phase=//p')"
if [[ -z "$RETRY_PHASE" ]]; then
    fail "skill_for: next printed no phase= for the failed implement after a restart, so its retry cannot be recorded"
else
    assert_next "skill_for: the retry answer to that checkpoint (Phase: $RETRY_PHASE, from next) dispatches implement, not address-findings" none \
        "$RESTART_THEN_FAILED_IMPL
$(checkpoint phase-failed retry "$RETRY_PHASE")" implement
fi
assert_next "skill_for: after a restart and a complete implement of the new work, a failed pass with no **Addressed** still maps to address-findings" none \
    "$RESTART_THEN_FAILED_IMPL
$(checkpoint phase-failed retry "${RETRY_PHASE:-implement}")
$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9 bbb2222)
$(implementation failed "")" checkpoint:phase-failed "phase=address-findings"

echo "TEST: pr_start.py -- where the current pull request's work starts (issue 459)"
# The one boundary rule, read by next and review_progress.sh. Each case is
# a synthetic timeline (0-based entry indexes) with the start and the armed
# state at its end; the replay table in the issue-459 plan's Tests section.
implementation_pr() {  # <status> [number, default 9] -- an Implementation correlated to a pull request
    printf '## Implementation\n**Status**: %s\n**When**: %s\n**By**: t (m)\n**PR**: #%s at `2222222`\n' "$1" "$NOW" "${2:-9}"
}
implementation_nocorr() {  # <status> -- a pass that never wrote a correlation line (nor **Addressed**)
    printf '## Implementation\n**Status**: %s\n**When**: %s\n**By**: t (m)\n\nstopped early\n' "$1" "$NOW"
}
implementation_nocorr_failed() { implementation_nocorr failed; }
PR_START_PY="$SCRIPT_DIR/../pr_start.py"
# assert_start <label> <fixture> <want "start armed">
assert_start() {
    local label="$1" content="$2" want="$3" f got
    f="$TMPD/start_$$_$RANDOM.md"
    printf '%s\n' "$content" > "$f"
    got=$(python3 "$SCRIPT_DIR/../progress_read.py" "$f" | PR_START_DIR="$(dirname "$PR_START_PY")" python3 -B -c '
import json, os, sys
sys.path.insert(0, os.environ["PR_START_DIR"])
from pr_start import scan
r = scan(json.load(sys.stdin)["entries"])
print(r.round_start, "yes" if r.armed else "no")' 2>&1)
    [[ "$got" == "$want" ]] && pass "pr_start: $label -> $want" || fail "pr_start: $label (want '$want', got '$got')"
}
M="$(checkpoint merge merge)"
assert_start "no merge answer: start 0, not armed" \
    "$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9)" "0 no"
assert_start "a single pull request ends armed with no boundary (451, 455, 354, 307 shape)" \
    "$(implementation complete "")
$(integrated_review complete clean)
$M" "0 yes"
assert_start "merge, stop, merge, Plan Authored: the Plan Authored" \
    "$M
$(checkpoint merge stop)
$M
$(plan_authored complete)" "3 no"
assert_start "merge, stop: the stop disarms (nothing landed)" \
    "$M
$(checkpoint merge stop)" "0 no"
assert_start "merge, Merge record, landed, Plan Authored: a Merge record neither arms nor disarms" \
    "$M
$(merge_record report-only)
$(plan_authored complete)" "2 no"
assert_start "merge, Merge record (newest): still armed" \
    "$M
$(merge_record report-only)" "0 yes"
assert_start "merge, record, merge-refused/retriage, review, merge, Plan Authored: the Plan Authored" \
    "$M
$(merge_record report-only)
$(checkpoint merge-refused retriage)
$(integrated_review complete clean)
$M
$(plan_authored complete)" "5 no"
assert_start "merge, record, merge-refused/address, Branch fix: no boundary (refused)" \
    "$M
$(merge_record report-only)
$(checkpoint merge-refused address)
$(implementation complete "")" "0 no"
assert_start "merge, refusal, address checkpoint, Branch Implementation (merge-from-main): no boundary" \
    "$M
$(checkpoint merge address)
$(implementation complete "")" "0 no"
assert_start "merge, Branch Implementation with no checkpoint between (the other order): the Implementation" \
    "$M
$(implementation complete "")" "1 no"
assert_start "merge, PR-correlated fix: still armed (a PR-correlated entry never disarms)" \
    "$M
$(implementation_pr complete)" "0 yes"
assert_start "merge, PR-correlated fix, merge, Plan Authored: the Plan Authored" \
    "$M
$(implementation_pr complete)
$M
$(plan_authored complete)" "3 no"
assert_start "merge, Addressed Branch fix: not a start entry, still armed" \
    "$M
$(implementation complete addressed)" "0 yes"
assert_start "merge, restart, Plan Authored, merge, Plan Authored: the last Plan Authored" \
    "$M
$(checkpoint rounds restart)
$(plan_authored complete)
$M
$(plan_authored complete)" "4 no"
assert_start "merge, restart: the restart moves the round start and leaves the merge answer armed" \
    "$M
$(checkpoint rounds restart)" "2 yes"
assert_start "hand merge: review, Branch Implementation, no merge answer: no boundary (known limitation)" \
    "$(local_review_prepush complete changes-requested feature/issue-9)
$(implementation complete "")" "0 no"
assert_start "issue-307 shape then a part: merge, record, merge-refused answered merge, Plan Authored: the Plan Authored" \
    "$M
$(merge_record report-only)
$(checkpoint merge-refused merge)
$(plan_authored complete)" "3 no"
assert_start "issue-307 shape: a merge answer at merge-refused neither arms nor disarms (the earlier arm stands)" \
    "$M
$(merge_record report-only)
$(checkpoint merge-refused merge)" "0 yes"
assert_start "a merge answer at merge-refused with no earlier arm does not arm" \
    "$(merge_record report-only)
$(checkpoint merge-refused merge)" "0 no"
assert_start "a failed start entry while armed is the boundary (whatever its Status)" \
    "$(implementation complete "")
$M
$(checkpoint plan proceed)
$(implementation failed "")" "3 no"
assert_start "a failed Implementation with no correlation line while armed is the boundary" \
    "$M
$(implementation_nocorr_failed)" "1 no"
# Start entries told apart by pull-request number (issue 459 pre-push
# review, must-fix 1). The merged pull request's number is the newest
# PR-correlated entry's before the merge answer: integrated_review is #9.
IR9="$(integrated_review complete clean)"
assert_start "merged #9, plan proceed, Implementation on another pull request's draft (#6): the Implementation" \
    "$IR9
$M
$(checkpoint plan proceed)
$(implementation_pr complete 6)" "3 no"
assert_start "merged #9, a failed Implementation on #6: the boundary too (whatever its Status)" \
    "$IR9
$M
$(implementation_pr failed 6)" "2 no"
assert_start "issue 332 entry 64 shape: merged #9, an Addressed-less fix on #9 itself: no boundary, still armed" \
    "$IR9
$M
$(implementation_pr complete 9)" "0 yes"
assert_start "merged number unknown (no PR-correlated entry before the merge answer), Implementation on #6: no boundary (the safe side)" \
    "$(local_review_prepush complete approved feature/issue-9)
$M
$(implementation_pr complete 6)" "0 yes"
assert_start "the number is taken at each merge answer: part 2 on #6 merged, a fix on #6 after it is no boundary" \
    "$IR9
$M
$(implementation_pr complete 6)
$(integrated_review_n 6)
$M
$(implementation_pr complete 6)" "2 yes"
assert_start "merged #9, a complete Implementation with no correlation line (a fix pass that lost **Addressed** and its line): no boundary" \
    "$IR9
$M
$(implementation_nocorr complete)" "0 yes"
assert_start "merged #9, a partial Implementation with no correlation line: the boundary" \
    "$IR9
$M
$(implementation_nocorr partial)" "2 no"
assert_start "merged #9, a complete Branch Implementation (no **Addressed**): the boundary" \
    "$IR9
$M
$(implementation complete "")" "2 no"
# Two starts: the round start moves at a restart, the pull-request start
# does not (sources keeps an open pull request's reviews across a restart).
assert_starts() {  # <label> <fixture> <want "round_start pr_start armed">
    local label="$1" content="$2" want="$3" f got
    f="$TMPD/starts_$$_$RANDOM.md"
    printf '%s\n' "$content" > "$f"
    got=$(python3 "$SCRIPT_DIR/../progress_read.py" "$f" | PR_START_DIR="$(dirname "$PR_START_PY")" python3 -B -c '
import json, os, sys
sys.path.insert(0, os.environ["PR_START_DIR"])
from pr_start import scan, round_start, pr_start, merge_armed
e = json.load(sys.stdin)["entries"]
r = scan(e)
assert (r.round_start, r.pr_start, r.armed) == (round_start(e), pr_start(e), merge_armed(e))
print(r.round_start, r.pr_start, "yes" if r.armed else "no")' 2>&1)
    [[ "$got" == "$want" ]] && pass "pr_start: $label -> $want" || fail "pr_start: $label (want '$want', got '$got')"
}
# A restart moves only the round start (issue 459, second fix round, host
# decision). The pre-push review's timelines, with their new values:
# merge answer, restart, the next part's plan -> both starts at the plan.
assert_starts "merge answer, restart, Plan Authored, Implementation, review: both starts at the Plan Authored (was Scan(12, 0)-shaped: pull-request start 0)" \
    "$(plan_authored complete)
$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9 aaa1111)
$IR9
$M
$(checkpoint rounds restart)
$(plan_authored complete)
$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9 bbb2222)" "6 6 no"
# A hand merge (no merge answer) then a restart: the restart is no boundary
# (the remedy is a merge checkpoint by the owner), so the pull-request
# start stays 0 and only the rounds start over.
assert_starts "hand merge with no merge answer, restart, Plan Authored: round start after the restart, pull-request start 0 (Scan(7, 0)-shaped; unchanged, by design)" \
    "$(plan_authored complete)
$(implementation complete "")
$(local_review_pr complete changes-requested open)
$IR9
$(checkpoint rounds restart)
$(plan_authored complete)
$(implementation complete "")" "5 0 no"
assert_starts "the same with the owner's merge recorded as a merge checkpoint before the restart: both starts at the Plan Authored" \
    "$(plan_authored complete)
$(implementation complete "")
$(local_review_pr complete changes-requested open)
$IR9
$M
$(checkpoint rounds restart)
$(plan_authored complete)
$(implementation complete "")" "6 6 no"
# The newest pull-request number is forgotten at a boundary (second fix
# round, must-fix 2): a part whose Integrated Review line carries no
# number never takes the previous part's.
assert_starts "part 2's Integrated Review has no readable number: its post-merge fix on #11 is no boundary (pull-request start 4, was 10)" \
    "$(plan_authored complete)
$(implementation complete "")
$IR9
$M
$(plan_authored complete)
$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9 aaa1111)
$(checkpoint rounds publish)
$(printf '## Integrated Review\n**Status**: complete\n**When**: %s\n**By**: t (m)\n**PR**: see the pull request\n\n### Findings\n- [x] (must-fix) fixed\n' "$NOW")
$M
$(implementation_pr complete 11)" "4 4 yes"
# A legacy "**PR**: #11 -- 1 review(s), ..." line parses to no correlation
# in progress_read.py; pr_start.py reads its leading #11 itself.
LEGACY_IR11="$(printf '## Integrated Review\n**Status**: complete\n**When**: %s\n**By**: t (m)\n**PR**: #11 — 1 review(s), 1 valid, 0 false positives\n\n### Findings\n- [x] (must-fix) fixed\n' "$NOW")"
assert_starts "a legacy '**PR**: #11 — 1 review(s)' line gives the merged number: a fix on #11 is no boundary, the next part on #12 is" \
    "$LEGACY_IR11
$M
$(implementation_pr complete 11)
$(implementation_pr complete 12)" "3 3 no"
assert_starts "the legacy line read as #11 at the merge answer: an Implementation on #12 first is the boundary" \
    "$LEGACY_IR11
$M
$(implementation_pr complete 12)" "2 2 no"
assert_starts "a restart while the pull request is open: round start after it, pull-request start unmoved" \
    "$(implementation complete "")
$IR9
$(checkpoint rounds restart)
$(implementation complete addressed)" "3 0 no"
assert_starts "a merge boundary moves both starts" \
    "$IR9
$M
$(plan_authored complete)" "2 2 no"
assert_starts "merge boundary, then a restart: the round start is the restart, the pull-request start the boundary" \
    "$IR9
$M
$(plan_authored complete)
$(local_review_prepush complete changes-requested feature/issue-9)
$(checkpoint rounds restart)
$(implementation complete addressed)" "5 2 no"
assert_start "the post-merge plan checkpoint (revise, proceed or stop) keeps the armed state" \
    "$M
$(checkpoint plan revise)" "0 yes"
assert_start "After findings, Decision merge arms too" \
    "$(checkpoint findings merge)
$(plan_authored complete)" "1 no"
# Real timelines in this repository (issue 459 replay): 429 (several pull
# requests; every boundary is a Plan Authored, the first two at 25 and 50;
# pull request 461 adds a fourth part at 71), 332 (four pull requests, one merged by hand
# with no merge answer: boundaries 67 and 81 only), single-pull-request
# issues (no boundary, armed at the end).
real_boundaries() {  # <progress.md> -- every start the scan moves to (P Plan Authored, I Implementation), then "armed=<yes|no>"
    python3 "$SCRIPT_DIR/../progress_read.py" "$1" | PR_START_DIR="$(dirname "$PR_START_PY")" python3 -B -c '
import json, os, sys
sys.path.insert(0, os.environ["PR_START_DIR"])
from pr_start import scan
e = json.load(sys.stdin)["entries"]
seen, prev = [], 0
for k in range(1, len(e) + 1):
    s = scan(e[:k]).round_start
    if s != prev:
        seen.append("%d%s" % (s, {"Plan Authored": "P", "Implementation": "I"}.get(e[s]["base_type"], "?")))
        prev = s
print(" ".join(seen), "armed=" + ("yes" if scan(e).armed else "no"))'
}
WP="$SCRIPT_DIR/../../work-plans"
got=$(real_boundaries "$WP/issue-429/progress.md")
[[ "$got" == "25P 50P"* && "$got" != *[I?]* ]] \
    && pass "pr_start: issue 429's real timeline -- boundaries at 25 and 50 first, each a Plan Authored ($got)" \
    || fail "pr_start: issue 429 real timeline (got '$got')"
got=$(real_boundaries "$WP/issue-332/progress.md")
[[ "$got" == "67I 81I armed=yes" ]] \
    && pass "pr_start: issue 332's real timeline -- the Branch Implementations at 67 and 81 (63's merge answer is followed by a PR-correlated fix first); the hand-merged part has none" \
    || fail "pr_start: issue 332 real timeline (got '$got')"
for n in 451 455 354 307; do
    got=$(real_boundaries "$WP/issue-$n/progress.md")
    [[ "$got" == " armed=yes" ]] \
        && pass "pr_start: issue $n's real timeline (one pull request) -- no boundary, armed at the end" \
        || fail "pr_start: issue $n real timeline (got '$got')"
done

echo "TEST: next -- the next pull request of an issue counts its own rounds (issue 459)"
PART1="$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9 aaa1111)
$(implementation complete addressed)
$(local_review_prepush complete changes-requested feature/issue-9 bbb2222)
$(implementation complete addressed)
$(local_review_prepush complete changes-requested feature/issue-9 ccc3333)
$(checkpoint rounds publish)
$(integrated_review complete clean)
$(checkpoint merge merge)"
PART2="$PART1
$(plan_authored complete)
$(plan_review complete)
$(checkpoint plan proceed)
$(implementation complete "")"
assert_next "round_count: part 1 had three reviews and merged; part 2's first review is round 1 -> address-findings (not checkpoint:rounds)" none \
    "$PART2
$(local_review_prepush complete changes-requested feature/issue-9 ddd4444)" address-findings "round=1"
assert_next "round_count: part 2's second review is round 2 -> address-findings" none \
    "$PART2
$(local_review_prepush complete changes-requested feature/issue-9 ddd4444)
$(implementation complete addressed)
$(local_review_prepush complete changes-requested feature/issue-9 eee5555)" address-findings "round=2"
assert_next "round_count: part 2 reaches MAX_ROUNDS only on its own third review" none \
    "$PART2
$(local_review_prepush complete changes-requested feature/issue-9 ddd4444)
$(implementation complete addressed)
$(local_review_prepush complete changes-requested feature/issue-9 eee5555)
$(implementation complete addressed)
$(local_review_prepush complete changes-requested feature/issue-9 fff6666)" checkpoint:rounds "round=3"
assert_next "round_count: part 2 starts at its first Branch Implementation when no plan entry came between" none \
    "$PART1
$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9 ddd4444)" address-findings "round=1"
assert_next "round_count: a refused merge (merge-refused answered address) is no boundary -- the fix's review is round 4" none \
    "$PART1
$(checkpoint merge-refused address)
$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9 ddd4444)" checkpoint:rounds "round=4"
PART2_FAILED="$PART1
$(checkpoint plan proceed)
$(implementation failed "")"
assert_next "skill_for: a failed first implement of part 2 maps to implement -- part 1's complete Implementations do not count" none \
    "$PART2_FAILED" checkpoint:phase-failed "phase=implement"
RETRY_PHASE2="$(run_next none "$PART2_FAILED" | sed -n 's/^phase=//p')"
assert_next "skill_for: the retry answer to it (Phase: ${RETRY_PHASE2:-none printed}, from next) dispatches implement, not address-findings" none \
    "$PART2_FAILED
$(checkpoint phase-failed retry "${RETRY_PHASE2:-missing}")" implement
assert_next "skill_for: part 2's later failed pass with no **Addressed** after its own complete implement maps to address-findings" none \
    "$PART2_FAILED
$(checkpoint phase-failed retry implement)
$(implementation complete "")
$(local_review_prepush complete changes-requested feature/issue-9 ddd4444)
$(implementation failed "")" checkpoint:phase-failed "phase=address-findings"

echo "TEST: next -- row 3a, after a merge with no pull request open (issue 459)"
# The state walk from the issue-459 plan's third review: which row answers
# each state once row 3a is in.
MERGED="$PART1"   # ... Integrated Review, Checkpoint merge/merge (armed)
assert_next "walk 1: armed, newest the merge answer, --pr none -> checkpoint:plan (row 3a; was merge, issue 459 acceptance)" none \
    "$MERGED" checkpoint:plan "merged"
out=$(run_next none "$MERGED")
[[ "$out" != "action=merge"* ]] && pass "acceptance: next after a merge checkpoint with no pull request does not answer merge" || fail "acceptance: merge again (out=$out)"
assert_next "walk 2: armed, newest a Merge record (written at the gate, then the merge landed), --pr none -> checkpoint:plan (row 3a, not row 23)" none \
    "$MERGED
$(merge_record report-only)" checkpoint:plan
assert_next "walk 3: armed, newest a Merge record, --pr open (refused) -> checkpoint:merge-refused (row 23 unchanged)" open \
    "$MERGED
$(merge_record report-only)" checkpoint:merge-refused
assert_next "walk 4: not armed (merge-refused answered address), newest a Merge record, --pr none -> row 23 unchanged" none \
    "$MERGED
$(checkpoint merge-refused address)
$(merge_record unreviewed)" checkpoint:merge-refused
assert_next "walk 4b: no merge answer at all, newest a Merge record, --pr none -> row 23 unchanged" none \
    "$(merge_record report-only)" checkpoint:merge-refused
out=$(bash "$DP" next --pr merged --progress "$TMPD/never_read.md" 2>&1)
[[ "$out" == "action=done"* ]] && pass "walk 5: armed, --pr merged given -> row 1, done (before any read)" || fail "walk 5 (out=$out)"
assert_next "walk 6: a stop at the merge checkpoint after a merge answer -> row 2, done" none \
    "$MERGED
$(checkpoint merge stop)" "done"
assert_next "walk 6b: a stop at the post-merge plan checkpoint (still armed) -> row 2, done" none \
    "$MERGED
$(checkpoint plan stop)" "done"
assert_next "walk 7: armed, then the next part's Plan Authored newest -> row 8, review-plan" none \
    "$MERGED
$(plan_authored complete)" review-plan
assert_next "row 21 unchanged: armed, newest the merge answer, --pr open -> merge" open \
    "$MERGED" merge
assert_next "row 21 unchanged: armed, newest the merge answer, --pr draft -> merge" draft \
    "$MERGED" merge
assert_next "row 3a: After findings answered merge, merge landed, --pr none -> checkpoint:plan" none \
    "$(integrated_review complete open)
$(checkpoint findings merge)" checkpoint:plan
assert_next "row 3a: the issue-307 shape (merge, record, merge-refused answered merge), --pr none -> checkpoint:plan" none \
    "$MERGED
$(merge_record report-only)
$(checkpoint merge-refused merge)" checkpoint:plan
assert_next "row 28 unchanged: the issue-307 shape with the pull request still open -> checkpoint:unexpected" open \
    "$MERGED
$(merge_record report-only)
$(checkpoint merge-refused merge)" checkpoint:unexpected
assert_next "row 28 unchanged: merge-refused answered merge with no earlier merge answer (not armed), --pr none -> checkpoint:unexpected" none \
    "$(merge_record report-only)
$(checkpoint merge-refused merge)" checkpoint:unexpected
assert_next "row 3a needs the newest entry: armed, newest a PR-correlated fix, --pr none -> row 12, review-code" none \
    "$MERGED
$(implementation_pr complete)" review-code
assert_next "row 3a needs --pr none: a failed newest entry while armed is still row 3" none \
    "$MERGED
$(plan_authored failed)" checkpoint:phase-failed "phase=plan-task"

echo "TEST: next -- row 3a does not loop on the plan checkpoint it raises (issue 459)"
# Sequence 1: merge lands, checkpoint:plan, revise recorded -> plan-task;
# the plan checkpoint answer leaves the timeline armed, so a row 3a keyed
# on the armed state alone would raise checkpoint:plan again, forever.
TL="$TMPD/timeline_postmerge_revise.md"; TIMELINE_OK=1
printf '%s\n\n' "$MERGED" > "$TL"
step "$TL" none checkpoint:plan
append "$TL" "$(checkpoint plan revise)"
step "$TL" none plan-task
append "$TL" "$(plan_authored complete)"
step "$TL" none review-plan
append "$TL" "$(plan_review complete)"
step "$TL" none checkpoint:plan
append "$TL" "$(checkpoint plan proceed)"
step "$TL" none implement
append "$TL" "$(implementation complete "")"
step "$TL" none review-code pre-push
append "$TL" "$(local_review_prepush complete changes-requested feature/issue-9 ddd4444)"
step "$TL" none address-findings round=1
[[ "$TIMELINE_OK" -eq 1 ]] && pass "timeline F: merge, checkpoint:plan, revise -> plan-task, then the next part's own loop from round 1" || fail "timeline F had a mismatch (see above)"
# proceed straight to implement after the merge.
assert_next "row 3a: the post-merge checkpoint answered proceed -> implement (row 10)" none \
    "$MERGED
$(checkpoint plan proceed)" implement
# Sequence 2: revise, plan-task writes no entry (check-exit MISSING), the
# phase-failed checkpoint is answered retry or takeover: rows 26/27, not 3a.
assert_next "row 3a: revise, plan-task wrote nothing, phase-failed answered retry -> plan-task (row 26)" none \
    "$MERGED
$(checkpoint plan revise)
$(checkpoint phase-failed retry plan-task)" plan-task
assert_next "row 3a: the same answered takeover -> plan-task, mode=inline (row 27)" none \
    "$MERGED
$(checkpoint plan revise)
$(checkpoint phase-failed takeover plan-task)" plan-task "mode=inline"
assert_next "row 3a: proceed, implement wrote nothing, phase-failed answered retry -> implement (row 26)" none \
    "$MERGED
$(checkpoint plan proceed)
$(checkpoint phase-failed retry implement)" implement
# A failed first implement of the next part is its start entry: the retry
# dispatches implement, not address-findings (part 1's complete
# Implementations are before the boundary).
TL="$TMPD/timeline_postmerge_failed.md"; TIMELINE_OK=1
printf '%s\n\n' "$MERGED" > "$TL"
step "$TL" none checkpoint:plan
append "$TL" "$(checkpoint plan proceed)"
step "$TL" none implement
append "$TL" "$(implementation failed "")"
step "$TL" none checkpoint:phase-failed phase=implement
append "$TL" "$(checkpoint phase-failed retry implement)"
step "$TL" none implement
[[ "$TIMELINE_OK" -eq 1 ]] && pass "timeline G: merge, proceed, a failed first implement of the next part -> phase=implement, retry -> implement" || fail "timeline G had a mismatch (see above)"

echo "TEST: next -- a restart checkpoint as the newest entry (orchestrator recipe (a))"
assert_next "restart: a restart checkpoint with no entry after it routes to row 28, checkpoint:unexpected (the host then dispatches review-issue)" none \
    "$TWO_ROUNDS
$(checkpoint rounds restart)" checkpoint:unexpected
assert_next "restart: a restart recorded under **After**: unexpected also routes to checkpoint:unexpected" none \
    "$(checkpoint unexpected restart)" checkpoint:unexpected

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
    (cd "$SB" && AGENT_NAME="Claude Code Agent" AGENT_EMAIL="dev+claude-code@example.org" bash .agent/scripts/dispatch_phase.sh "$@" 2>&1)
}
out=$(run_handoff --issue 9 --skill review-issue)
[[ "$out" == *"task=/review-issue 9"* && "$out" == *"model=sonnet"* && "$out" == *"entry_type=Issue Review"* \
    && "$out" == *"agent_name=Claude Code Agent"* && "$out" == *"agent_email=dev+claude-code@example.org"* \
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
[[ "$out" == *"\`$SB/.agent/scripts/progress_append.sh 9"* && "$out" == *'**Branch**: <name> at <sha>'* && "$out" == *"Commit your work"* ]] \
    && pass "handoff: implement's exit contract names progress_append.sh, the correlation line, and that the agent commits (plan review finding 1)" || fail "handoff implement exit contract (out=$out)"
# By absolute path for every issue type, the run-issue skill too: a package
# issue's phase runs in a checkout with no .agent/ of its own (issue 429).
[[ "$out" == *"in the shape \`$SB/.claude/skills/run-issue/SKILL.md\` step 4"* ]] \
    && pass "handoff: implement's exit contract names the writer and the run-issue skill by absolute path (issue 429)" || fail "handoff implement exit contract absolute paths (out=$out)"

# The hook rule (issue #465, owner-decided 2026-11-13) rides on
# conventions=, only for the committing passes of a workspace handoff: a
# review phase is never told to skip a hook. SKIP covers every commit, the
# progress entry's included; --no-verify stays forbidden. The agent runs the
# suites that test what it changed, each on its own, and names them in its
# entry; the full pre-commit pass is the host's (run-issue step 7), so the
# agent's text prints no pre-commit command and names no runner (a full run
# per pass is what the rule removed). The old rule's scope word
# ("intermediate" commits) must not come back either (plan review note 7).
for sk in implement address-findings; do
    out=$(run_handoff --issue 9 --skill "$sk")
    conv=$(printf '%s\n' "$out" | grep '^conventions=')
    [[ "$conv" == *"owner-decided 2026-11-13, issue #465"* \
        && "$conv" == *"\`SKIP=validate-script-tests\` on every commit you make, your progress entry's commit included"* \
        && "$conv" == *"\`--no-verify\` is never allowed"* \
        && "$conv" == *"Run only the suites that test what you changed, each on its own with \`bash .agent/scripts/tests/<suite>\`"* \
        && "$conv" == *"its \`test_<name>.sh\` and any \`test_<name>_*.sh\`"* \
        && "$conv" == *"\`test_skill_paths.sh\` when you changed text under \`.claude/skills/\` or \`.agent/knowledge/\`"* \
        && "$conv" == *"A changed script with no such suite gets none: name it in your entry. Any other changed file (documentation, configuration) gets none either; the host's pass covers both."* \
        && "$conv" == *"In your entry, name each suite you ran with its result line, and say the full pass was left to the host."* \
        && "$conv" == *"the host runs the full pass once before the push, and CI checks every push"* \
        && "$conv" != *"pre-commit run --files"* && "$conv" != *".venv/bin/pre-commit"* \
        && "$conv" != *"run_script_tests.sh"* && "$conv" != *"suites_for_files.sh"* \
        && "$conv" != *"intermediate"* \
        && "$conv" == *"local time with offset"*"scratchpad"* ]] \
        && pass "handoff: $sk (workspace) conventions= carries the 2026-11-13 hook rule (SKIP on every commit, own suites only, host's full pass), no pre-commit command, and the existing conventions" \
        || fail "handoff $sk hook rule (conv=$conv)"
done

for sk in review-issue plan-task review-plan review-code triage-reviews; do
    out=$(run_handoff --issue 9 --skill "$sk" --pr 42)
    conv=$(printf '%s\n' "$out" | grep '^conventions=')
    [[ -n "$conv" && "$conv" != *"SKIP=validate-script-tests"* && "$conv" != *"pre-commit run --files"* && "$conv" != *"Hook rule"* \
        && "$conv" == *"local time with offset"*"scratchpad"* ]] \
        && pass "handoff: $sk conventions= carries no hook-skip rule, keeps the existing conventions" \
        || fail "handoff $sk must not carry the hook rule (conv=$conv)"
done

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
echo "TEST: handoff -- a pre-push review-code at round 3 or later is a narrow convergence check (issue 321)"
# Round = prior complete Local Review (Pre-Push) entries for the worktree's
# branch + 1 (review_progress.sh round). Rounds 1 and 2 keep the bare task line; round
# 3 and later name the scope and "no cross-model reviewers"; a PR-mode
# handoff is never changed; another branch's reviews do not count.
WT9="$SB/worktrees/workspace/issue-workspace-9"
P9="$WT9/.agent/work-plans/issue-9/progress.md"
mkdir -p "$(dirname "$P9")"
printf '# Issue 9\n\n' > "$P9"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *$'\ntask=/review-code --branch --issue 9\n'* ]] \
    && pass "handoff: round 1 (no prior review) -- bare review-code task line" || fail "handoff round 1 (out=$out)"
append "$P9" "$(local_review_prepush complete changes-requested feature/issue-9)"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *$'\ntask=/review-code --branch --issue 9\n'* ]] \
    && pass "handoff: round 2 -- still the bare task line (the fix-round rule applies)" || fail "handoff round 2 (out=$out)"
append "$P9" "$(local_review_prepush failed changes-requested feature/issue-9)"
append "$P9" "$(local_review_prepush partial changes-requested feature/issue-9)"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *$'\ntask=/review-code --branch --issue 9\n'* ]] \
    && pass "handoff: a failed and a partial review are not rounds -- still round 2, the bare task line" || fail "handoff failed/partial reviews (out=$out)"
append "$P9" "$(local_review_prepush complete changes-requested feature/issue-other)"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *$'\ntask=/review-code --branch --issue 9\n'* ]] \
    && pass "handoff: another branch's review does not count toward the round" || fail "handoff other branch (out=$out)"
append "$P9" "$(local_review_prepush complete changes-requested feature/issue-9)"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *$'\ntask=/review-code --branch --issue 9 (round 3: a narrow convergence check on the round 2 review\'s findings and the fix diff since it; no cross-model reviewers)\n'* ]] \
    && pass "handoff: round 3 -- the task line names the scope and \"no cross-model reviewers\"" || fail "handoff round 3 (out=$out)"
append "$P9" "$(local_review_prepush complete changes-requested feature/issue-9)"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *"task=/review-code --branch --issue 9 (round 4: a narrow convergence check on the round 3 review's findings"*"; no cross-model reviewers)"$'\n'* ]] \
    && pass "handoff: round 4 -- still a convergence check, naming round 3 as the prior one" || fail "handoff round 4 (out=$out)"
out=$(run_handoff --issue 9 --skill review-code --pr 42)
[[ "$out" == *$'\ntask=/review-code 42\n'* && "$out" != *"no cross-model reviewers"* ]] \
    && pass "handoff: PR mode -- the pre-push round count never changes a PR-mode task line" || fail "handoff round PR mode (out=$out)"
append "$P9" "$(checkpoint rounds restart)"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *$'\ntask=/review-code --branch --issue 9\n'* ]] \
    && pass "handoff: a restart checkpoint starts the rounds over -- after four reviews, the next is round 1, the bare task line" || fail "handoff restart (out=$out)"
append "$P9" "$(local_review_prepush complete changes-requested feature/issue-9)"
append "$P9" "$(local_review_prepush complete changes-requested feature/issue-9)"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *"task=/review-code --branch --issue 9 (round 3: a narrow convergence check on the round 2 review's findings"* ]] \
    && pass "handoff: two reviews after the restart -- the next is round 3 of the new work" || fail "handoff restart round 3 (out=$out)"
# Issue 459 acceptance: the pull request merged; the first pre-push review
# of the next part's diff is round 1, a full review with outside reviewers.
append "$P9" "$(integrated_review complete clean)"
append "$P9" "$(checkpoint merge merge)"
append "$P9" "$(plan_authored complete)"
append "$P9" "$(plan_review complete)"
append "$P9" "$(checkpoint plan proceed)"
append "$P9" "$(implementation complete "")"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *$'\ntask=/review-code --branch --issue 9\n'* && "$out" != *"no cross-model reviewers"* ]] \
    && pass "handoff: after a merge, the next pull request's first pre-push review is round 1 -- the bare task line, no \"no cross-model reviewers\" (issue 459)" || fail "handoff next pull request round 1 (out=$out)"
append "$P9" "$(local_review_prepush complete changes-requested feature/issue-9)"
append "$P9" "$(local_review_prepush complete changes-requested feature/issue-9)"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *"task=/review-code --branch --issue 9 (round 3: a narrow convergence check on the round 2 review's findings"* ]] \
    && pass "handoff: two reviews of the next pull request -- the next is its own round 3" || fail "handoff next pull request round 3 (out=$out)"
# The pre-push review's timeline (issue 459, must-fix 1): part 1 had three
# pre-push reviews and merged as #9; the next part's draft pull request #6
# existed, the post-merge plan checkpoint was answered proceed (no Plan
# Authored), and its first Implementation carries **PR**: #6.
printf '# Issue 9\n\n' > "$P9"
for sha in aaa1111 bbb2222 ccc3333; do
    append "$P9" "$(implementation complete addressed)"
    append "$P9" "$(local_review_prepush complete changes-requested feature/issue-9 $sha)"
done
append "$P9" "$(integrated_review complete clean)"
append "$P9" "$(checkpoint merge merge)"
append "$P9" "$(checkpoint plan proceed)"
append "$P9" "$(implementation_pr complete 6)"
out=$(run_handoff --issue 9 --skill review-code)
[[ "$out" == *$'\ntask=/review-code --branch --issue 9\n'* && "$out" != *"no cross-model reviewers"* ]] \
    && pass "handoff: the next part's first Implementation on its own draft pull request (#6, the merged one #9) -- round 1, the bare task line" || fail "handoff next part on a draft PR (out=$out)"
append "$P9" "$(local_review_prepush complete changes-requested feature/issue-9 ddd4444)"
out=$(bash "$DP" next --pr none --progress "$P9" 2>&1)
[[ "$out" == "action=address-findings"*"round=1"* ]] \
    && pass "next: the same timeline after the next part's first review -> address-findings round=1 (was checkpoint:rounds round=4)" || fail "next next part on a draft PR (out=$out)"
out=$(cd "$SB" && bash .agent/scripts/review_progress.sh round --progress "$P9" --branch feature/issue-9 2>&1)
[[ "$out" == "round=2"* ]] \
    && pass "review_progress round agrees: the next review is round 2 (was round=5)" || fail "round next part on a draft PR (out=$out)"
git -C "$WT9" checkout -q --detach
out=$(run_handoff --issue 9 --skill review-code); rc=$?
git -C "$WT9" checkout -q feature/issue-9
[[ "$rc" -eq 0 && "$out" == *$'\ntask=/review-code --branch --issue 9\n'* && "$out" == *"could not count the review rounds"* ]] \
    && pass "handoff: no branch to count rounds on -- a full fix-round review, with a warning" || fail "handoff round detached (rc=$rc out=$out)"
rm -rf "$WT9/.agent/work-plans"

echo ""
echo "TEST: resolve_worktree -- --type project (registry lookup, then the deprecated project/worktrees fallback)"
# (a) registry lookup: one registered project, resolved via registry_worktree_dir
# (default <path>/worktrees, no worktrees= override).
SBP1="$(mktemp -d -p "$SANDBOX")"
git -C "$SBP1" init -q -b main
git -C "$SBP1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
mkdir -p "$SBP1/.agent/scripts"
for f in dispatch_phase.sh progress_read.py pr_start.py _worktree_helpers.sh _project_registry.sh _resolve_default_branch.sh _resolve_work_plans_dir.sh; do
    cp "$SCRIPT_DIR/../$f" "$SBP1/.agent/scripts/"
done
mkdir -p "$SBP1/myproj/worktrees/issue-9"
printf 'myproj\tsingle_project\t%s\n' "$SBP1/myproj" > "$SBP1/.agent/projects.local"
out=$(cd "$SBP1" && AGENT_NAME=t AGENT_EMAIL=t@t bash .agent/scripts/dispatch_phase.sh --issue 9 --skill review-issue --type project 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == *"worktree=$SBP1/myproj/worktrees/issue-9"* ]] \
    && pass "resolve_worktree --type project: a single registered project resolves via registry_worktree_dir" || fail "resolve_worktree project registry (rc=$rc out=$out)"
# The hook rule names a workspace hook and workspace CI, so a --type
# project implement handoff carries none (issues #399, #465).
out=$(cd "$SBP1" && AGENT_NAME=t AGENT_EMAIL=t@t bash .agent/scripts/dispatch_phase.sh --issue 9 --skill implement --type project 2>&1); rc=$?
conv=$(printf '%s\n' "$out" | grep '^conventions=')
[[ "$rc" -eq 0 && -n "$conv" && "$conv" != *"SKIP=validate-script-tests"* && "$conv" != *"pre-commit run --files"* && "$conv" != *"Hook rule"* \
    && "$conv" == *"local time with offset"*"scratchpad"* ]] \
    && pass "handoff: --type project implement conventions= carries no workspace hook rule" \
    || fail "handoff project implement must not carry the hook rule (rc=$rc out=$out)"

# (b) the deprecated project/worktrees fallback (wt_legacy_project_base): no
# registry entry at all, worktree living inside a project/ checkout's own
# worktrees/ dir (the pre-#265 shape).
SBP2="$(mktemp -d -p "$SANDBOX")"
git -C "$SBP2" init -q -b main
git -C "$SBP2" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
mkdir -p "$SBP2/.agent/scripts"
for f in dispatch_phase.sh progress_read.py pr_start.py _worktree_helpers.sh _project_registry.sh _resolve_default_branch.sh _resolve_work_plans_dir.sh; do
    cp "$SCRIPT_DIR/../$f" "$SBP2/.agent/scripts/"
done
mkdir -p "$SBP2/project/worktrees/issue-9"
out=$(cd "$SBP2" && AGENT_NAME=t AGENT_EMAIL=t@t bash .agent/scripts/dispatch_phase.sh --issue 9 --skill review-issue --type project 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == *"worktree=$SBP2/project/worktrees/issue-9"* ]] \
    && pass "resolve_worktree --type project: no registry entry -- falls back to the deprecated project/worktrees/ shape" || fail "resolve_worktree project legacy fallback (rc=$rc out=$out)"

echo ""
echo "TEST: base -- an issue with no package base prints nothing, exit 0 (issue 429)"
# Decided by the worktree the ref resolves to: a workspace worktree, a
# single-repository project worktree (no manifest) and one whose manifest
# is a lone "." entry have no package base; the handoff has no base= line.
SBB="$(mk_sandbox 41)"
out=$(cd "$SBB" && bash .agent/scripts/dispatch_phase.sh base --issue 41 --type workspace 2>&1); rc=$?
[[ "$rc" -eq 0 && -z "$out" ]] && pass "base: workspace worktree -- nothing, exit 0" || fail "base workspace (rc=$rc out=$out)"
out=$(cd "$SBB" && AGENT_NAME=t AGENT_EMAIL=t@t bash .agent/scripts/dispatch_phase.sh --issue 41 --skill implement --type workspace 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "worktree="* && "$out" != *$'\nbase='* && "$out" != "base="* ]] \
    && pass "handoff: workspace issue -- no base= line" || fail "handoff workspace base= (rc=$rc out=$out)"
out=$(cd "$SBB" && bash .agent/scripts/dispatch_phase.sh base --issue 41 --type workspace --base main 2>&1); rc=$?
[[ "$rc" -eq 2 && "$out" == *"no package worktree"* ]] && pass "base: --base on a workspace issue -- refused" || fail "base workspace --base (rc=$rc out=$out)"
out=$(cd "$SBB" && bash .agent/scripts/dispatch_phase.sh base --issue 42 --type workspace 2>&1); rc=$?
[[ "$rc" -eq 0 && -z "$out" ]] && pass "base: a bare number with no worktree and no --layer -- nothing, exit 0" || fail "base no worktree (rc=$rc out=$out)"
out=$(cd "$SBB" && bash .agent/scripts/dispatch_phase.sh base --issue 41 --type workspace --layer l1 --package-repos a 2>&1); rc=$?
[[ "$rc" -eq 2 && "$out" == *"only valid with --type project"* ]] && pass "base: --layer with --type workspace -- refused" || fail "base workspace --layer (rc=$rc out=$out)"
out=$(cd "$SBP1" && bash .agent/scripts/dispatch_phase.sh base --issue 9 --type project 2>&1); rc=$?
[[ "$rc" -eq 0 && -z "$out" ]] && pass "base: single-repository project worktree -- nothing, exit 0" || fail "base single project (rc=$rc out=$out)"
out=$(cd "$SBP1" && AGENT_NAME=t AGENT_EMAIL=t@t bash .agent/scripts/dispatch_phase.sh --issue 9 --skill implement --type project 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" != *$'\nbase='* ]] && pass "handoff: single-repository project issue -- no base= line" || fail "handoff single project base= (rc=$rc out=$out)"
printf '# project=myproj issue=9 layer=\n%s\t.\tfeature/issue-9\n' "$SBP1/myproj" > "$SBP1/myproj/worktrees/issue-9/.worktree-repos"
out=$(cd "$SBP1" && bash .agent/scripts/dispatch_phase.sh base --issue 9 --type project 2>&1); rc=$?
[[ "$rc" -eq 0 && -z "$out" ]] && pass "base: a lone '.' manifest -- nothing, exit 0" || fail "base lone dot (rc=$rc out=$out)"
rm -f "$SBP1/myproj/worktrees/issue-9/.worktree-repos"

echo ""
echo "TEST: --skill-prefix -- the host's skill set, independent of the issue's --type (#345)"
# The four host/issue combinations. The host is expressed ONLY by
# --skill-prefix (empty = a workspace-hosted or Codex session with bare
# skills; agent-workspace: = a project session whose workspace skills came
# from the plugin, ADR-0018); the issue by --type. Neither may leak into the
# other: round 1 of the #345 plan keyed the prefix on --type, which broke a
# workspace host driving a project issue.
run_prefixed() {  # <dir> [args...]
    local d="$1"; shift
    (cd "$d" && AGENT_NAME=t AGENT_EMAIL=t@t bash .agent/scripts/dispatch_phase.sh "$@" 2>&1)
}
out=$(run_prefixed "$SB" --issue 9 --skill review-code)
[[ "$out" == *$'\ntask=/review-code --branch --issue 9\n'* ]] \
    && pass "--skill-prefix: workspace host + workspace issue -- bare" || fail "prefix ws/ws (out=${out:0:200})"
out=$(run_prefixed "$SBP1" --issue 9 --skill review-code --type project)
[[ "$out" == *$'\ntask=/review-code --branch --issue 9\n'* ]] \
    && pass "--skill-prefix: workspace host + project issue -- bare (--type project must not prefix)" || fail "prefix ws/project (out=${out:0:200})"
out=$(run_prefixed "$SB" --issue 9 --skill review-code --skill-prefix agent-workspace:)
[[ "$out" == *$'\ntask=/agent-workspace:review-code --branch --issue 9\n'* ]] \
    && pass "--skill-prefix: plugin host + workspace issue -- prefixed" || fail "prefix plugin/ws (out=${out:0:200})"
out=$(run_prefixed "$SBP1" --issue 9 --skill review-code --type project --skill-prefix agent-workspace:)
[[ "$out" == *$'\ntask=/agent-workspace:review-code --branch --issue 9\n'* ]] \
    && pass "--skill-prefix: plugin host + project issue -- prefixed" || fail "prefix plugin/project (out=${out:0:200})"
# Every slash-command skill is prefixed; the literal implement instruction
# (not a slash command) is not.
ok=1
for args in "review-issue" "plan-task" "review-plan" "review-code --pr 42" "triage-reviews --pr 42" "address-findings"; do
    read -r sk rest <<< "$args"
    # shellcheck disable=SC2086
    out=$(run_prefixed "$SB" --issue 9 --skill $sk $rest --skill-prefix agent-workspace:)
    [[ "$out" == *$'\ntask=/agent-workspace:'"$sk "* ]] || { ok=0; echo "    not prefixed: $sk -> $(grep '^task=' <<< "$out")"; }
done
[[ "$ok" -eq 1 ]] && pass "--skill-prefix: every slash-command phase is prefixed" || fail "--skill-prefix: a phase was not prefixed"
out=$(run_prefixed "$SB" --issue 9 --skill implement --skill-prefix agent-workspace:)
[[ "$out" == *$'\ntask=implement the plan at'* ]] \
    && pass "--skill-prefix: the literal implement instruction is not prefixed" || fail "prefix implement (out=${out:0:200})"
for bad in "agent-workspace" "/agent-workspace:" "Agent:" "a b:"; do
    out=$(run_prefixed "$SB" --issue 9 --skill review-code --skill-prefix "$bad"); rc=$?
    [[ "$rc" -eq 2 && "$out" == *"--skill-prefix must be"* ]] \
        && pass "--skill-prefix: '$bad' is a usage error" || fail "--skill-prefix '$bad' accepted (rc=$rc out=${out:0:160})"
done

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
    for f in dispatch_phase.sh progress_read.py pr_start.py _worktree_helpers.sh _project_registry.sh _resolve_default_branch.sh _resolve_work_plans_dir.sh; do
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
for f in dispatch_phase.sh progress_read.py pr_start.py _worktree_helpers.sh _project_registry.sh _resolve_default_branch.sh _resolve_work_plans_dir.sh; do
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
