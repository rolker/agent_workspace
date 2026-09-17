#!/usr/bin/env bash
# .agent/scripts/tests/test_review_code_convergence.sh
# Tests for .agent/scripts/review_progress.sh (issue #269 PR B): the
# review-code skill's convergence round-counting, ship verdict, and the
# PROGRESS_PERSISTENCE_STRICT-switched step-8 persistence path.
#
# Every case runs in throwaway git repos under mktemp -d — never this repo.
# WORKTREE_ISSUE / WORK_PLANS_DIR_OVERRIDE / PROGRESS_PERSISTENCE_STRICT are
# cleared up front so the host session's worktree state cannot leak in.
#
# Run: bash .agent/scripts/tests/test_review_code_convergence.sh

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

prepush_entry() {  # <branch> <must-fix-count>
    local n=$2 i
    printf '## Local Review (Pre-Push)\n**Status**: complete\n**When**: 2026-09-17 10:00 -04:00\n**By**: t (m)\n**Verdict**: changes-requested\n\n**Branch**: %s at `abc1234`\n**Base**: main\n**Must-fix**: %s | **Suggestions**: 0\n\n### Findings\n' "$1" "$n"
    for ((i = 1; i <= n; i++)); do printf -- '- [ ] (must-fix) thing %s — `f:%s`\n' "$i" "$i"; done
    printf -- '- [ ] (suggestion) nit — `f:9`\n'
}

# ============================================================ round =====
FIX="$TMPD/fixtures"; mkdir -p "$FIX"

# 0 prior entries (file absent) -> round 1
out=$("$RP" round --branch feature/issue-7 --progress "$FIX/absent.md")
[[ "$out" == $'round=1\nprev_must_fix=-' ]] && pass "round: no progress file -> round 1, no prev" || fail "round: no progress file (out=$out)"

# 1 prior entry for this branch (3 must-fix) -> round 2, prev 3
{ printf -- '---\nissue: 7\n---\n\n# Issue #7\n\n'; prepush_entry feature/issue-7 3; } > "$FIX/one.md"
out=$("$RP" round --branch feature/issue-7 --progress "$FIX/one.md")
[[ "$out" == $'round=2\nprev_must_fix=3' ]] && pass "round: one prior pre-push entry -> round 2, prev must-fix 3" || fail "round: one prior (out=$out)"

# 2 prior entries (3 then 1 must-fix), plus a PR-mode entry and an entry for
# ANOTHER branch, which must not count -> round 3, prev 1 (the newest)
{ printf -- '---\nissue: 7\n---\n\n# Issue #7\n\n'
  prepush_entry feature/issue-7 3; printf '\n'
  printf '## Local Review\n**Status**: complete\n**When**: 2026-09-17 11:00 -04:00\n**By**: t\n**PR**: #70 at `beef`\n\n### Findings\n- [ ] (must-fix) pr-mode — `x:1`\n\n'
  prepush_entry feature/issue-8 5; printf '\n'
  prepush_entry feature/issue-7 1; } > "$FIX/two.md"
out=$("$RP" round --branch feature/issue-7 --progress "$FIX/two.md")
[[ "$out" == $'round=3\nprev_must_fix=1' ]] && pass "round: two prior entries for this branch -> round 3; PR-mode and other-branch entries ignored; prev is the newest" || fail "round: two prior (out=$out)"

# malformed file (unterminated fence) -> non-zero, not a silent round 1
printf '## Implementation\n```\nopen\n' > "$FIX/bad.md"
"$RP" round --branch feature/issue-7 --progress "$FIX/bad.md" >/dev/null 2>&1; rc=$?
[[ "$rc" -ne 0 ]] && pass "round: malformed progress.md fails loudly (rc=$rc), never a silent round 1" || fail "round: malformed progress.md fails (rc=$rc)"

# ========================================================== verdict =====
v() { "$RP" verdict "$@" | sed -n 's/^ship=//p'; }
[[ "$(v --must-fix 0 --round 1)" == recommended ]] && pass "verdict: no must-fix -> recommended" || fail "verdict: no must-fix"
[[ "$(v --must-fix 2 --round 2 --prev-must-fix 3 --mechanical)" == recommended ]] && pass "verdict: round 2, 2 mechanical must-fix, not rising -> recommended" || fail "verdict: round 2 mechanical"
[[ "$(v --must-fix 3 --round 1)" == continue ]] && pass "verdict: round 1, 3 must-fix -> continue" || fail "verdict: round 1 three"
[[ "$(v --must-fix 2 --round 2 --prev-must-fix 3)" == continue ]] && pass "verdict: round 2, 2 must-fix but not mechanical -> continue" || fail "verdict: non-mechanical"
[[ "$(v --must-fix 2 --round 2 --prev-must-fix 1 --mechanical)" == continue ]] && pass "verdict: round 2, must-fix rising (1 -> 2) -> continue" || fail "verdict: rising"
[[ "$(v --must-fix 3 --round 3 --prev-must-fix 3 --mechanical)" == continue ]] && pass "verdict: round 3, 3 must-fix (> 2) -> continue even if mechanical" || fail "verdict: high count"
"$RP" verdict --round 2 >/dev/null 2>&1; rc=$?
[[ "$rc" -eq 2 ]] && pass "verdict: missing --must-fix is a usage error (rc 2)" || fail "verdict: usage error (rc=$rc)"

# ========================================================== persist =====
# A sandbox repo whose worktree basename and branch encode issue 7, so
# resolve_work_plans_dir() rule 2b resolves it without WORKTREE_ISSUE.
mk_repo() {  # <dir> <branch>
    mkdir -p "$1"; git -C "$1" init -q -b "$2"
    git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}
ENTRY=$'## Local Review (Pre-Push)\n**Status**: complete\n**When**: 2026-09-17 12:00 -04:00\n**By**: t (m)\n**Verdict**: approved\n\n**Branch**: feature/issue-7 at `abc1234`\n**Base**: main\n**Must-fix**: 0 | **Suggestions**: 0\n**Round**: 1 | **Ship**: recommended — clean\n\n### Findings\n- [ ] No issues found. LGTM.'

# --- (1) switch tests: MISMATCHED worktree (WORKTREE_ISSUE set to another issue)
MIS="$TMPD/issue-workspace-99"; mk_repo "$MIS" feature/issue-99
# strict -> abort (exit 4), remediation on stderr, nothing written
out=$(cd "$MIS" && printf '%s\n' "$ENTRY" | WORKTREE_ISSUE=99 "$RP" persist --issue 7 --strict 2>&1); rc=$?
if [[ "$rc" -eq 4 ]] && [[ "$out" == *"worktree_enter.sh"* ]] && [[ ! -e "$MIS/.agent/work-plans/issue-7/progress.md" ]]; then
    pass "persist strict: mismatched worktree aborts (rc 4) with remediation, nothing written"
else
    fail "persist strict: mismatched worktree aborts (rc=$rc out=$out)"
fi
# same via env var instead of the flag
out=$(cd "$MIS" && printf '%s\n' "$ENTRY" | WORKTREE_ISSUE=99 PROGRESS_PERSISTENCE_STRICT=1 "$RP" persist --issue 7 2>&1); rc=$?
[[ "$rc" -eq 4 ]] && pass "persist strict via PROGRESS_PERSISTENCE_STRICT=1: same abort" || fail "persist strict via env (rc=$rc)"
# compatibility (default) -> completes, notice line, committed via inline mechanism in the CURRENT worktree
head_before=$(git -C "$MIS" rev-parse HEAD)
out=$(cd "$MIS" && printf '%s\n' "$ENTRY" | WORKTREE_ISSUE=99 "$RP" persist --issue 7 --title "Seven" 2>&1); rc=$?
if [[ "$rc" -eq 0 ]] && [[ "$out" == *"Progress persistence notice: would have aborted (resolve_work_plans_dir:"*"compatibility mode (PROGRESS_PERSISTENCE_STRICT=0)"* ]] \
    && grep -q '^## Local Review (Pre-Push)$' "$MIS/.agent/work-plans/issue-7/progress.md" \
    && grep -q '^# Issue #7 — Seven$' "$MIS/.agent/work-plans/issue-7/progress.md" \
    && [[ "$(git -C "$MIS" rev-parse HEAD)" != "$head_before" ]] \
    && [[ "$(git -C "$MIS" log -1 --format=%s)" == "progress: local review (pre-push) for #7" ]]; then
    pass "persist compat: mismatched worktree completes with the 'would have aborted' notice; entry committed inline"
else
    fail "persist compat: mismatched worktree (rc=$rc out=$out)"
fi

# --- (2) MATCHING worktree under compat: no notice line, and strict works for real
MATCH="$TMPD/issue-workspace-7"; mk_repo "$MATCH" feature/issue-7
out=$(cd "$MATCH" && printf '%s\n' "$ENTRY" | "$RP" persist --issue 7 --title "Seven" 2>&1); rc=$?
if [[ "$rc" -eq 0 ]] && [[ "$out" != *"notice"* ]] && [[ "$out" == *"compatibility mode"* ]] \
    && [[ "$(git -C "$MATCH" log -1 --format=%s)" == "progress: local review (pre-push) for #7" ]]; then
    pass "persist compat: matching worktree produces no notice (no false positive) and commits"
else
    fail "persist compat: matching worktree no-notice (rc=$rc out=$out)"
fi
# A distinct entry (new SHA): progress_append.sh's idempotency guard would
# otherwise correctly treat a byte-identical re-append as an already-written
# no-op.
ENTRY2=${ENTRY//abc1234/def5678}
out=$(cd "$MATCH" && printf '%s\n' "$ENTRY2" | "$RP" persist --issue 7 --strict 2>&1); rc=$?
if [[ "$rc" -eq 0 ]] && [[ "$out" == *"strict: resolve_work_plans_dir + progress_append.sh"* ]] \
    && [[ "$(git -C "$MATCH" log -1 --format='%s|%an')" == "progress: local review (pre-push) for #7|Test Agent" ]] \
    && [[ "$(grep -c '^## Local Review (Pre-Push)$' "$MATCH/.agent/work-plans/issue-7/progress.md")" -eq 2 ]]; then
    pass "persist strict: matching worktree commits through progress_append.sh with the agent identity"
else
    fail "persist strict: matching worktree (rc=$rc out=$out)"
fi
# strict + identity unset -> progress_append.sh's fail-loud abort surfaces as rc 3, nothing committed
head_before=$(git -C "$MATCH" rev-parse HEAD)
out=$(cd "$MATCH" && printf '%s\n' "${ENTRY//abc1234/0badf00}" | env -u AGENT_NAME -u AGENT_EMAIL "$RP" persist --issue 7 --strict 2>&1); rc=$?
[[ "$rc" -eq 3 && "$(git -C "$MATCH" rev-parse HEAD)" == "$head_before" && "$out" == *identity* ]] \
    && pass "persist strict: unset agent identity fails loud (rc 3), no commit" || fail "persist strict: identity unset (rc=$rc out=$out)"

# --- (3) degradation: no issue derivable -> skip, never call the resolver, exit 0
SK="$TMPD/skillwt"; mk_repo "$SK" skill/research-20260917-120000
out=$(cd "$SK" && "$RP" persist --issue "" < /dev/null 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "Progress persistence skipped (no linked issue — skill worktree)" ]] \
    && pass "persist degrade: skill/ branch -> skipped (skill worktree), exit 0" || fail "persist degrade: skill branch (rc=$rc out=$out)"
OB="$TMPD/oneoff"; mk_repo "$OB" hotfix/typo
out=$(cd "$OB" && "$RP" persist --issue "" < /dev/null 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "Progress persistence skipped (no linked issue)" ]] \
    && pass "persist degrade: ordinary branch, no issue -> skipped (no linked issue), exit 0" || fail "persist degrade: ordinary branch (rc=$rc out=$out)"
# --no-progress short-circuits before anything else (even with an issue)
out=$(cd "$MIS" && "$RP" persist --issue 7 --no-progress --strict < /dev/null 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "Progress persistence skipped (--no-progress)" ]] \
    && pass "persist: --no-progress skips even in strict mode with a mismatched worktree" || fail "persist: --no-progress (rc=$rc out=$out)"
# strict-mode degradation is not an abort either: no issue + strict -> skip
out=$(cd "$OB" && "$RP" persist --issue "" --strict < /dev/null 2>&1); rc=$?
[[ "$rc" -eq 0 ]] && pass "persist degrade: no issue under strict still skips (resolver never called)" || fail "persist degrade strict (rc=$rc)"

# --- (4) compat path applies the SAME entry guards as progress_append.sh
#     (round-1 review: it had none). Each case: exit 2, nothing appended,
#     no commit.
CMP="$TMPD/issue-workspace-7-guards"; mk_repo "$CMP" feature/issue-7
guard_case() {  # <label> <title> <entry>
    local before after rc out
    before=$(git -C "$CMP" rev-parse HEAD)
    out=$(cd "$CMP" && printf '%s\n' "$3" | "$RP" persist --issue 7 --title "$2" 2>&1); rc=$?
    after=$(git -C "$CMP" rev-parse HEAD)
    if [[ "$rc" -eq 2 && "$before" == "$after" ]] && ! grep -qs '^## Checkpoint$' "$CMP/.agent/work-plans/issue-7/progress.md"; then
        pass "persist compat guard: $1 rejected (rc 2, no commit)"
    else
        fail "persist compat guard: $1 (rc=$rc out=$out)"
    fi
}
guard_case "newline in --title"        $'Real\n## Checkpoint\n**PR**: forged' "$ENTRY"
guard_case "second top-level heading"  "Seven" $'## Implementation\nbody\n\n## Checkpoint\n**PR**: forged'
guard_case "unterminated code fence"   "Seven" $'## Implementation\n```\nopen'
guard_case "non-writable entry type"   "Seven" $'## External Review\nbody'
guard_case "no heading at all"         "Seven" $'just text'

# --- (5) compat path is idempotent across a failed commit: a rejecting
#     pre-commit hook makes the first run exit 3 (appended + staged); the
#     retry after removing the hook commits ONCE, no duplicate entry.
IDEM="$TMPD/issue-workspace-7-idem"; mk_repo "$IDEM" feature/issue-7
printf '#!/bin/sh\nexit 1\n' > "$IDEM/.git/hooks/pre-commit"; chmod +x "$IDEM/.git/hooks/pre-commit"
out=$(cd "$IDEM" && printf '%s\n' "$ENTRY" | "$RP" persist --issue 7 2>&1); rc1=$?
rm -f "$IDEM/.git/hooks/pre-commit"
out2=$(cd "$IDEM" && printf '%s\n' "$ENTRY" | "$RP" persist --issue 7 2>&1); rc2=$?
n=$(grep -c '^## Local Review (Pre-Push)$' "$IDEM/.agent/work-plans/issue-7/progress.md")
if [[ "$rc1" -eq 3 && "$rc2" -eq 0 && "$n" -eq 1 ]] && [[ "$(git -C "$IDEM" log -1 --format=%s)" == "progress: local review (pre-push) for #7" ]]; then
    pass "persist compat: retry after a failed commit re-attempts the commit without double-appending"
else
    fail "persist compat idempotency (rc1=$rc1 rc2=$rc2 entries=$n out2=$out2)"
fi
# and a third identical run is a reported no-op, exit 0
out3=$(cd "$IDEM" && printf '%s\n' "$ENTRY" | "$RP" persist --issue 7 2>&1); rc3=$?
[[ "$rc3" -eq 0 && "$out3" == *"already persisted"* ]] && pass "persist compat: identical re-run after commit is a no-op (exit 0)" || fail "persist compat no-op (rc=$rc3 out=$out3)"

# --- (6) strict + WORK_PLANS_DIR_OVERRIDE: progress_append.sh can only write
#     <root>/.agent/work-plans/issue-<N>; an override elsewhere must abort
#     (rc 4), never write to the default path while claiming the override.
OV="$TMPD/override-target/not-yet-created"
out=$(cd "$MATCH" && printf '%s\n' "${ENTRY//abc1234/1111111}" | WORK_PLANS_DIR_OVERRIDE="$OV" "$RP" persist --issue 7 --strict 2>&1); rc=$?
if [[ "$rc" -eq 4 ]] && [[ ! -e "$OV" ]] && ! grep -q '1111111' "$MATCH/.agent/work-plans/issue-7/progress.md"; then
    pass "persist strict: non-standard WORK_PLANS_DIR_OVERRIDE aborts (rc 4); nothing written or created anywhere"
else
    fail "persist strict: non-standard override (rc=$rc out=$out)"
fi
# an override that IS another repo's standard issue dir works and lands there
OTHER="$TMPD/issue-workspace-7-other"; mk_repo "$OTHER" feature/issue-7
out=$(cd "$MIS" && printf '%s\n' "${ENTRY//abc1234/2222222}" | WORK_PLANS_DIR_OVERRIDE="$OTHER/.agent/work-plans/issue-7" "$RP" persist --issue 7 --strict 2>&1); rc=$?
if [[ "$rc" -eq 0 ]] && grep -q '2222222' "$OTHER/.agent/work-plans/issue-7/progress.md" \
    && [[ "$(git -C "$OTHER" log -1 --format=%s)" == "progress: local review (pre-push) for #7" ]]; then
    pass "persist strict: WORK_PLANS_DIR_OVERRIDE naming another repo's standard issue dir is honored there"
else
    fail "persist strict: standard override in another repo (rc=$rc out=$out)"
fi

echo ""
echo "test_review_code_convergence: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
