---
issue: 300
---

# Issue #300 — merge_pr.sh: Copilot's review check-run ('changes recommended', no findings) is counted as a CI failure and blocks the merge

## Issue Review
**Status**: complete
**When**: 2026-09-22 10:09 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #300

### Scope Assessment

**Well-scoped?** Yes — one script (`.agent/scripts/merge_pr.sh`, `_ci_poll_state` around lines 978–1021) plus a test-fixture addition to `test_merge_pr_gate.sh`/`test_merge_pr.sh`. Fits a single PR.
**Right repo?** Yes — `merge_pr.sh` is workspace infrastructure.
**Dependencies**: None open. #276, #299, #286, #290 (all referenced as prior context) are closed/merged; nothing blocks starting this.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | OK | Fix belongs in the script's own classification logic, not a doc note; issue already asks for regression fixtures. |
| A change includes its consequences | Action needed | Issue only names `test_merge_pr_gate.sh` (or `test_merge_pr.sh`) as the target — confirm which suite actually owns `_ci_poll_state` coverage today and add fixtures there, not a new file. |
| Test what breaks | OK | Issue proposes exact fixtures (copilot failure + Lint success → success; copilot failure + Lint in_progress → pending) — targets the real regression. |
| Human control and transparency | OK | "Print which check-run(s) caused a failed verdict" directly serves this; keep it in scope. |
| Only what's needed | Watch | "Better, a small allow/deny list" is presented as an upgrade over a single hardcoded name — scope the allowlist to the one confirmed case (`copilot-pull-request-reviewer`) unless a second offending check-run is already known, rather than speculatively generalizing. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0013 — progress.md entry-type vocabulary | No | No new entry type; this is a script bugfix. |
| 0011 — Project-type adapter contract | No | `merge_pr.sh` classification logic is generic, not project-shape-dependent. |
| 0004/0005 — Enforcement hierarchy | Watch | The fix is itself an enforcement mechanism (merge gate); regression must be caught by the test suite, not left to manual verification — issue already covers this via fixtures. |

### Consequences

- No documentation elsewhere describes the current "every check-run counts as CI" behavior, so no doc updates are needed beyond the script comment the issue already requests ("a comment naming the Copilot case").

### Recommendations

- The fix must exclude the check-run **by name/app-slug, for any conclusion** (`failure`, `cancelled`, `timed_out`, `action_required`, `startup_failure`, `stale` — all currently checked at line 1007), not by matching the "Changes recommended" / "Findings: None" message text. The bug recurred on PR #308 (issue #307) today with `copilot-pull-request-reviewer` reporting conclusion `failure` for a *different* reason (Copilot quota exhaustion, not a review verdict) — a message-text-based exclusion would have missed that case. The issue's own proposed fix (exclude by check-run name near the top of the script) already gets this right; flagging so implementation doesn't regress toward a message-based heuristic.
- The fix must not add any new wait, poll, or extra `gh api` round trip — it's a pure classification/filter change over data `_ci_poll_state` already fetches. Confirm the implementation only adds a name-based `jq select(... | not)` filter, not a second lookup.
- Since Copilot's review is already consumed by `triage-reviews` → `## Integrated Review`, the diagnostic print (recommendation 3 in the issue) should make clear in its output that the excluded check-run was *not* used to block the merge, to avoid an operator assuming it was silently ignored entirely.

### Actions
- [ ] Issue only names `test_merge_pr_gate.sh` (or `test_merge_pr.sh`) as the target — confirm which suite actually owns `_ci_poll_state` coverage today and add fixtures there, not a new file.
- [ ] The fix must exclude the check-run by name/app-slug, for any conclusion (`failure`, `cancelled`, `timed_out`, `action_required`, `startup_failure`, `stale` — all currently checked at line 1007), not by matching the "Changes recommended" / "Findings: None" message text. The bug recurred on PR #308 (issue #307) today with `copilot-pull-request-reviewer` reporting conclusion `failure` for a different reason (Copilot quota exhaustion, not a review verdict) — a message-text-based exclusion would have missed that case. The issue's own proposed fix (exclude by check-run name near the top of the script) already gets this right; flagging so implementation doesn't regress toward a message-based heuristic.
- [ ] The fix must not add any new wait, poll, or extra `gh api` round trip — it's a pure classification/filter change over data `_ci_poll_state` already fetches. Confirm the implementation only adds a name-based `jq select(... | not)` filter, not a second lookup.
- [ ] Since Copilot's review is already consumed by `triage-reviews` → `## Integrated Review`, the diagnostic print (recommendation 3 in the issue) should make clear in its output that the excluded check-run was not used to block the merge, to avoid an operator assuming it was silently ignored entirely.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 10:12 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed to plan-task with the four review notes carried into the plan (test suite location, exclude by check-run name for any conclusion, no new waits or API calls, diagnostic says "not used to block"). Exclusion scoped to the Copilot check-run only.

## Plan Authored
**Status**: complete
**When**: 2026-09-22 10:15 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-300/plan.md` at `cd009f8`

Excludes the `copilot-pull-request-reviewer` check-run by name (any conclusion) from `_ci_poll_state`'s CI classification in `merge_pr.sh`, with stderr diagnostics naming the excluded run and any real failing run, plus three new fixtures/tests in `test_merge_pr_gate.sh` (the file confirmed to own this coverage).

## Plan Review
**Status**: complete
**When**: 2026-09-22 10:18 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #300 — merge_pr.sh: Copilot's review check-run ('changes recommended', no findings) is counted as a CI failure and blocks the merge
**Plan**: `.agent/work-plans/issue-300/plan.md` at `cd009f8`
**Branch**: `feature/issue-300`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One script + one test file; correctly sized for a single PR, and correctly declines the allow/deny-list generalisation the issue floated. |
| Issue alignment | Good | Covers all three issue asks (exclude by name, fixtures, diagnose a `failed` verdict) and both Issue-Review recommendations (any conclusion, no new API round trip, diagnostic says "not used to block"). |
| File targeting | Needs work | `merge_pr.sh` / `test_merge_pr_gate.sh` are right (verified: `test_merge_pr.sh` has no check-run fixtures). But step 4's "Run all tests list at the bottom of the file (lines 729-749)" does not exist — see finding 2. |
| Consequences | Good | The stderr-vs-stdout consequence is identified correctly; the "no test does full-output equality" claim checks out, and existing `CHECKRUNS_*` fixtures carry no `name` key so `select(.name != $exclude)` leaves them untouched. |
| Principle alignment | Needs work | "Test what breaks" is not fully met: the one case where the filter changes classification (Copilot as the only check-run) is untested — finding 1. |
| ADR compliance | Good | No new entry type; 0004/0005 satisfied by putting the regression in the suite rather than a doc note. |
| ROS conventions | N/A | Workspace script. |

### Findings

1. **[Test adequacy / Principle: Test what breaks]** — No fixture covers the case the reviewer is asked to protect: Copilot's check-run as the **only** check-run, with no commit statuses. That is the single case where the filter changes the `registered` computation (line 1000-1005), and it is the one that decides whether the gate merges an unverified head. All three planned fixtures include a second, non-excluded run, so all three would still pass if the implementer applied the filter to only the `failed` and `pending` jq expressions and left `registered` on the raw `$r.check_runs` — and in that variant a Copilot-only head classifies as `registered=true, failed=false, pending=false` → **`success`**, merging a PR whose real CI never ran. Add a fourth fixture (`CHECKRUNS_COPILOT_ONLY`, workflows `total_count` ≥ 1, `MERGE_PR_CI_GRACE_SECONDS=0`): expect `merged_called` false and output containing `no checks registered for` (the `never-registered` branch, line 1120-1125), i.e. identical to an empty `check_runs` array. The plan's uniform application of the filter to all three computations is the correct call — this fixture is what pins it.

2. **[File targeting]** — Step 4's closing instruction, "Wire all three into the 'Run all tests' list at the bottom of the file (mirroring lines 729-749)", does not match `test_merge_pr_gate.sh`. The suite has no test-function registry: tests are straight-line inline blocks (`echo "TEST: …"` → fixtures → `if … pass/fail`), lines 722-749 are the body of the `--no-wait` mergeability test (#290), and the file ends at line 993 with the `$PASS passed, $FAIL failed` tally. New tests are added by appending an inline block in the CI-wait section (after ci-12b at line 695 is the right spot); there is nothing to wire. Highest existing id is ci-18, so ci-19/ci-20 are free.

3. **[Approach — diagnostics]** — The excluded-run stderr note is written inside `_ci_poll_state`, which is called once per iteration of the poll loop (line 1075) with `MERGE_PR_CI_POLL_SECONDS` defaulting to 10s and `MERGE_PR_CI_TIMEOUT_SECONDS` to 1800s — up to ~180 identical lines while waiting on a slow CI run. Emit it once (a `_ci_excl_noted` guard flag, or hoist the note to the caller after the loop breaks). The `CI failed: <names>` line needs no guard: `failed` breaks the loop on the first occurrence.

4. **[Test adequacy — ci-20 precision]** — "state stays pending/times out … it should time out or report `never-registered`/timeout wording" is under-specified. With `Lint` present-and-in-progress, `registered` is true regardless of the filter, so the only reachable outcome is `timeout`. Pin it: run with `MERGE_PR_CI_TIMEOUT_SECONDS=0` (as ci-11 does) and assert `merged_called` false **and** output contains `CI checks did not complete` (line 1129), in addition to the planned negative assertion on `CI checks failed`.

5. **[Verified — no action]** — The check-run name is exact: on PR #308's head `84d17a1`, `.name` is literally `copilot-pull-request-reviewer` (app slug `github-actions`, alongside `Lint (pre-commit)`, `Validate Adapter Contract`, `Validate Documentation`). Name-based matching hits; no `app.slug` fallback is needed, and the slug would be wrong to match on since it is shared with the real CI. Also confirmed: the exclusion cannot affect `_ci_wf_count`, which comes from the separate `actions/workflows` lookup, so the `no-ci` exit is unchanged.

### Summary

The approach is correct, minimal, and faithful to the owner's settled constraints — in particular, applying the filter uniformly to `registered`/`failed`/`pending` is the right choice and avoids the dangerous half-fix. One substantive gap: the plan tests three multi-run scenarios but not the Copilot-only scenario that the `registered` filter exists for, so the test suite would not catch the half-fix. Findings 2-4 are precision corrections to the plan's implementation notes; all five are minutes of work.

### Recommended Actions

- [ ] Add a Copilot-only fixture/test (finding 1): copilot failure as the sole check-run with workflows present → no merge, `no checks registered for` in output.
- [ ] Drop the "Run all tests list" step (finding 2); append inline test blocks after ci-12b instead, using ids ci-19 / ci-20 / ci-21.
- [ ] Emit the excluded-check-run stderr note once per run, not once per poll (finding 3).
- [ ] Tighten ci-20 to `MERGE_PR_CI_TIMEOUT_SECONDS=0` and assert the `CI checks did not complete` wording (finding 4).

## Checkpoint
**Status**: complete
**When**: 2026-09-22 10:22 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed, folding the four plan-review findings into the implementation (fourth Copilot-only fixture expecting the never-registered branch; inline test blocks ci-19/ci-20 appended after ci-12b, no registry to wire; emit the excluded-run diagnostic once; pin the in-progress test with MERGE_PR_CI_TIMEOUT_SECONDS=0 and the timeout wording). The plan file is amended in the same branch to match.

## Implementation
**Status**: complete
**When**: 2026-09-22 10:27 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-300/plan.md` at `6aaacdb`
**Branch**: feature/issue-300 at 6aaacdb
**Mode**: inline

Two commits. c62d8e2 (`merge_pr.sh` + `test_merge_pr_gate.sh`): a `readonly MERGE_PR_CI_EXCLUDE_CHECK_RUN="copilot-pull-request-reviewer"` constant beside the `MERGE_PR_CI_*` block; `_ci_poll_state` filters that run out of `runs_json` by name, for any conclusion, before the `registered`/`failed`/`pending` classifications (one `jq select(.name != $x)` over data already fetched, no extra request); stderr diagnostics: the excluded run is named once per run (`_ci_excluded_noted` guard) as "not used to block the merge", and a failed verdict prints `CI failed: <name (conclusion)>, ...` from the non-excluded runs and statuses. Four inline tests appended after ci-12b: ci-19 (Copilot failure + Lint success → merges, excluded run reported), ci-20 (Copilot failure + Lint in_progress, `MERGE_PR_CI_TIMEOUT_SECONDS=0` → "CI checks did not complete", never "CI checks failed"), ci-21 (Copilot failure + Lint failure → fails, culprit line names only Lint), ci-22 (Copilot-only head, workflows=1, grace=0 → "no checks registered", not success). Gate suite 62/62; full script suites green via the commit hook. 6aaacdb amends the plan to match the four plan-review findings (all four addressed in the implementation). No AGENTS.md change (row wording unaffected).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 10:41 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-300 at `a0ee7ad`
**Base**: main
**Depth**: Standard (reason: 89 changed code lines across merge_pr.sh + its test suite; the other 297 diff lines are this loop's own plan.md/progress.md artifacts)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) `_ci_excluded_noted` guard is dead: `_ci_poll_state` runs in a command substitution, so the flag never persists and the excluded-run note prints on every poll (~180x over a 30-min wait), contradicting the code comment and the Implementation entry — `.agent/scripts/merge_pr.sh:984,1016-1020`
- [x] (suggestion) No test drives a second poll iteration, which is why the once-per-run bug shipped; add a multi-poll case asserting the note appears exactly once — `.agent/scripts/tests/test_merge_pr_gate.sh:703`
- [x] (suggestion) Note reads `conclusion=pending` for an in-progress excluded run (API returned null), and freezes the first-seen value once the guard works — `.agent/scripts/merge_pr.sh:1013`
- [x] (suggestion) No fixture for a Copilot-only head with `conclusion: null` (in-progress), which must also classify as `none` — `.agent/scripts/tests/test_merge_pr_gate.sh:219`

### Notes
Verified: gate suite 62/62; `bash -n` clean; jq exclusion/culprit expressions exercised by hand on in-progress, unnamed and empty inputs; every conclusion in the old `failed` set plus commit-status `error`/`failure` still counted; the filter applied uniformly to `registered`/`failed`/`pending`; `readonly` re-declaration impossible (merge_pr.sh is executed, never sourced); `failed=false; [[ ]] && failed=true` does not trip `set -e`. shellcheck/pre-commit unavailable here — the Lint job on push is the first real shellcheck pass. The must-fix was found independently by the governance read and a fresh adversarial subagent.

## Implementation
**Status**: complete
**When**: 2026-09-22 10:42 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-300 at 3b51678
**Addressed**: Local Review (Pre-Push) at `a0ee7ad` (2026-09-22 10:41 -04:00)
**Commits**: cf1cfda, 75387ee, 3b51678

**Mechanism** (correcting the earlier `## Implementation` claim): the
excluded-run note is printed **by the CI wait loop**, not by
`_ci_poll_state`. The loop reads the poller through `$(...)`, so no flag
set inside the poller survives. `_ci_poll_state` now prints
`<state>|<excluded>`; the loop splits on the first `|`, classifies on
field 1, and prints the note under `_ci_excluded_noted` in its own shell —
that is what makes it once per run rather than once per poll.

### Actions
- [x] (must-fix) `_ci_excluded_noted` guard was dead — the flag was set inside `_ci_poll_state`, which runs in a command substitution, so the note printed on every poll (~180x over a 30-minute wait). Moved the once-only state to the wait loop via the `<state>|<excluded>` stdout contract; updated the misleading code comment — `.agent/scripts/merge_pr.sh:986-1050,1102-1115`
- [x] (suggestion) Added `ci-24`: sequenced check-runs fixtures (Lint pending, then green) drive at least two poll iterations and assert the note appears exactly once (`grep -c`), plus a poll-count guard so "exactly once" cannot pass vacuously on a single poll — `.agent/scripts/tests/test_merge_pr_gate.sh:770-792`
- [x] (suggestion) The note now reports `status=in_progress` (from the run's `status`) for an excluded run with a null conclusion, instead of the `conclusion=pending` the API never returned — `.agent/scripts/merge_pr.sh:1012-1017`
- [x] (suggestion) Added `ci-23` with a Copilot-only head at `conclusion: null`: asserts it classifies as never-registered (`no checks registered for`), never pending-to-timeout, and that the note reads `status=in_progress` — `.agent/scripts/tests/test_merge_pr_gate.sh:756-768`

### Collateral
- `ci-21`'s "no CI-failure line names Copilot" assertion is now line-scoped (`grep`) instead of a whole-output glob: the note is printed after the `CI failed:` line, so `*"CI failed:"*"copilot"*` matched across two unrelated lines.

### Verification
- `bash .agent/scripts/tests/test_merge_pr_gate.sh` — 64 passed, 0 failed (was 61+1 fail mid-fix, then 62, then 64 with the two new cases)
- `.agent/scripts/tests/run_script_tests.sh` — all 23 suites passed
- pre-commit ran on every commit; no `--no-verify`. Not pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 10:47 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-300 at `4231b9b`
**Base**: main
**Depth**: Standard (reason: enforcement script merge_pr.sh; 86 changed code lines in the fix range a0ee7ad..4231b9b, re-review scoped to the fix)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

### Findings
- [x] (suggestion) ci-24's `poll_count=$(grep -c ... || echo 0)` yields "0\n0" when the call log is missing (grep -c prints 0 and exits 1), so the `-ge 2` test dies with a bash arithmetic error instead of the intended fail message; use `|| true` as the line above does — `.agent/scripts/tests/test_merge_pr_gate.sh:786`

### Notes
All four round-1 findings verified resolved against source: the once-only flag now lives in the wait loop's own shell (merge_pr.sh:1109-1115) and `_ci_poll_state` prints `<state>|<excluded>` on all five return paths (error/none/failed/pending/success), with `excluded` initialised to "" and captured before the copilot run is filtered out; the caller splits on the first `|` so the `case` still matches bare state words. The note now reports `status=<status>` for a null conclusion instead of an invented `conclusion=pending`. ci-23 (Copilot-only in-progress head -> never-registered) and ci-24 (two polls, note exactly once, with a poll-count guard against a vacuous pass) are both present and passing. ci-21's line-scoped `grep -q` is not weaker than the old glob — bash `==` globs match across newlines, so the old form could match `CI failed:` and `copilot-...` on unrelated lines; the grep enforces the actual intent. Verified: test_merge_pr_gate.sh 64/64; run_script_tests.sh all 23 suites green; `bash -n` clean on both files; no other caller of `_ci_poll_state` and no script parses merge_pr.sh stdout (Makefile `merge-pr` only), so the note's move from stderr to stdout is inert. Independent adversarial subagent found nothing. shellcheck/pre-commit still unavailable in this environment — the Lint job on push is the first real shellcheck pass.

## Implementation
**Status**: complete
**When**: 2026-09-22 10:55 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-300/plan.md` at `6f5aa43`
**Branch**: feature/issue-300 at 6f5aa43
**Mode**: inline

Owner-directed scope addition after the round-2 approval (plan addendum step 6, 6f5aa43): a merge must not go through automatically while a review check-run is still running; merging then is opt-in. 845460c (`merge_pr.sh` + `test_merge_pr_gate.sh`): new `--allow-pending-review` flag (parser, USAGE, header); in the wait loop, `_ci_review_pending` is true when the excluded run reports `status=...` and the flag is unset, and then a `success` result — or `none` on a repo with zero workflows — keeps polling instead of breaking, until the review completes or `MERGE_PR_CI_TIMEOUT_SECONDS`, at which point a new `review-pending` result exits 1 with "review check-run '...' still in progress ... pass --allow-pending-review". `failed` still breaks immediately; `never-registered` (CI configured but nothing registered) is unchanged. The excluded-run note is once per distinct state (`_ci_excluded_noted` now stores the last state string), so running→completed prints two lines with different wording. Tests ci-25..ci-28 as in the addendum; ci-24's `poll_count` guard switched to `|| true` (round-2 suggestion, box ticked in a234701). Gate suite 68/68; full script suites green via the commit hooks. The `AGENTS.md` `merge_pr.sh` row does not list the new flag: Ask-First, surfaced to the owner at the publish checkpoint.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 11:08 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-300 at `4d957b1`
**Base**: main
**Depth**: Standard (reason: enforcement script merge_pr.sh; re-review scoped to the owner-directed scope addition, 4231b9b..4d957b1, 121 changed code lines)
**Must-fix**: 1 | **Suggestions**: 0
**Round**: 3 | **Ship**: continue — round 3: must-fix rising (0 -> 1)

### Findings
- [x] (must-fix) `_ci_excluded` is a comma-joined list of every check-run named `copilot-pull-request-reviewer` on the SHA, but the hold tests it with the anchored glob `== status=*`; when a completed entry precedes a still-running one (a re-triggered review adds a second same-named run), the match fails, `_ci_review_pending` stays false and the merge proceeds under a running review — the exact case the owner rule blocks. Classify per entry in `_ci_poll_state`'s jq (any instance with `.conclusion == null`) or match `*status=*`, and add a two-entry fixture — `.agent/scripts/merge_pr.sh:1124` (with `.agent/scripts/merge_pr.sh:1030-1033`)

### Notes
Everything else in the range verified against source. The `success` arm's new nesting is correct: a review-pending `success` before the deadline sets no `_ci_result` and falls to the shared `sleep`/next poll — bash `case` matches one arm only, so there is no fallthrough into `*`, and no premature break. The `none` arm's `if`/`elif` is behaviour-preserving when no review is pending (the old second `if` was unreachable once the first broke), and the no-CI path still merges as soon as the review completes or `--allow-pending-review` is set; on a zero-workflow repo a pending review now waits to `MERGE_PR_CI_TIMEOUT_SECONDS` instead of the grace window, as the addendum specifies. `_ci_excluded_noted` is read and written only at merge_pr.sh:994/1127/1137; its initial `false` cannot collide with a real `status=`/`conclusion=` value and the `-n "$_ci_excluded"` guard keeps the empty case out, so the boolean-to-last-state-string change is consistent everywhere. `--no-wait` still bypasses the whole thing: the wait, the hold and the `review-pending` exit all live inside `if [[ "$NO_WAIT" == false ]]` (merge_pr.sh:1091-1221). `ALLOW_PENDING_REVIEW` is read in exactly one place. The note wording and the `review-pending` error both name the opt-in flag and read correctly for each state. Tests ci-25..ci-28 cover the four required states and are not vacuous (they assert `merged_called` plus exact stderr substrings that separate review-pending from no-ci/never-registered/timeout); the gap is the multi-entry case in the must-fix above. ci-24's `|| true` fix is correct (`grep -c` prints `0` and exits 1 on no match, so `|| echo 0` yielded "0\n0"). Verified: `test_merge_pr_gate.sh` 68/68; `run_script_tests.sh` all 23 suites green in 52s; `bash -n` clean on both changed files. An independent adversarial subagent, given no context from this read, reported the same single must-fix and nothing else. shellcheck/pre-commit are still unavailable in this environment — the Lint job on push is the first real shellcheck pass.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 11:10 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Address the open must-fix (re-triggered review: two same-named runs slip the pending-review hold) and, per the owner's standing merge rules stated 2026-09-22 ("a merge should only happen when everything is clean unless I say we can skip"; "the exception is merging after adding an updated progress or related doc"), fold two more merge_pr.sh changes into the same pass: enforce the review gate by default, and exempt bookkeeping-only commits from a fresh CI wait. Owner also approved (Ask-First) updating the merge_pr.sh row in AGENTS.md's script table. Then re-review.

## Implementation
**Status**: complete
**When**: 2026-09-22 11:24 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-300/plan.md` at `d7ab4a1`
**Branch**: feature/issue-300 at d7ab4a1
**Mode**: inline
**Addressed**: Local Review (Pre-Push) at 4d957b1

Host ran the address pass inline (owner-directed additions bundled with the round-3 must-fix; rounds checkpoint answered `address`). d4bd095 (`merge_pr.sh`, `test_merge_pr_gate.sh`, `test_merge_pr.sh`): (1) round-3 must-fix — `_ci_review_pending` now matches `*status=*` anywhere in the comma-joined excluded list, so a re-triggered review (completed + running runs of one name) still holds; test ci-29; box ticked. (2) Gate enforced by default on workspace PRs: `ENFORCE_MERGE_GATE=true`, new `--report-only` opt-out, `--enforce` kept as alias, refusal text names both opt-outs, project/package PRs unchanged (report-only); tests def-1/2/3; gate-gap tests that exercise the CI wait / cleanup / idempotency now pass `--report-only` (gate suite helper `run_merge_wait`, 25 direct calls, `test_merge_pr.sh`'s plain workspace-PR case). (3) Bookkeeping walk-back for the CI target: `_is_bookkeeping_path` (patterns `.agent/work-plans/*`, `ROADMAP.md`, `docs/ROADMAP.md`) and `_ci_walk_bookkeeping` (newest-first ancestors through single-parent bookkeeping-only commits, stops at main / a merge / 25 steps); in the wait loop, once, on the first poll: when the target is `none` or `pending`, probe candidates and switch to the newest with `success`/`failed`, then re-poll; tests ci-30 (walks back to the green head, merges) and ci-31 (a code commit stops the walk, never-registered on the new head). Gate suite 74/74; all 23 suites green via the commit hook. 6136abc (docs): `AGENTS.md` `merge_pr.sh` row (owner-approved Ask-First), Makefile help line, run-issue steps 10/11, `review_loop_lifecycle.md` gate row. d7ab4a1: plan addendum 2. Not in this PR: run-issue step 9 "triage may start before CI" (skill text; tracked separately).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 11:38 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-300 at `5710fd2`
**Base**: main
**Depth**: Standard (reason: enforcement script merge_pr.sh + governance docs; re-review scoped to 4d957b1..5710fd2, 284 changed lines)
**Must-fix**: 3 | **Suggestions**: 3
**Round**: 4 | **Ship**: continue — round 4: 3 must-fix is high; another independent read warranted

### Findings
- [x] (must-fix) The bookkeeping walk-back reassigns `CI_TARGET_SHA` to an ancestor, and the pending-review hold is then evaluated against that ancestor's check-runs — a `copilot-pull-request-reviewer` run still `in_progress` on the real PR head no longer holds the merge. Reproduced in the gate sandbox (ci-30 shape with `CHECKRUNS_COPILOT_ONLY_RUNNING` on the bookkeeping tip): `gh pr merge` was called, no "review still in progress" line. Carry the head's `_ci_excluded` across the switch, or refuse to walk while the head's review run is unfinished — `.agent/scripts/merge_pr.sh:1162-1181`
- [x] (must-fix) Two instruction docs still tell the reader the gate is report-only by default, which this branch makes false: "The gate is report-only by default and local-only" — `.claude/skills/review-code/SKILL.md:659`; "The gate is local to merge_pr.sh and report-only by default" — `.github/PULL_REQUEST_TEMPLATE.md:10` (the gate suite's own header comment, `test_merge_pr_gate.sh:4`, says "report-only (default)" too)
- [x] (must-fix) "Bookkeeping-only commits after the reviewed head (progress.md, work plans, roadmap) need no new review and no new CI wait: the gate and the CI target both walk back over them" — the gate's allow-list is only `.agent/work-plans/issue-<N>/progress.md`, `ROADMAP.md`, `docs/ROADMAP.md` (`merge_pr.sh:759-760`), so a work-plan commit after the review (e.g. this branch's own `d7ab4a1` plan addendum) makes the gate refuse, hard, under the new default — `.claude/skills/run-issue/SKILL.md:425-427`
- [x] (suggestion) On a root commit `git rev-list --parents -n 1 | cut -d' ' -f2-` prints the commit itself, so the walk treats a root as its own single parent, self-diffs to empty, and emits the same SHA 25 times (verified on a synthetic bookkeeping-only repo) — up to 50 redundant `gh api` probes. Count fields on the full `rev-list --parents` line instead — `.agent/scripts/merge_pr.sh:1093`
- [x] (suggestion) The walk's stop bound hardcodes `origin/main`; where the default branch differs or `origin/main` is absent the `merge-base` fails silently and only the single-parent / bookkeeping-path / 25-step bounds remain. `.agent/scripts/_resolve_default_branch.sh` exists — `.agent/scripts/merge_pr.sh:1090`
- [x] (suggestion) With enforce as the default, a project PR merged with no flags prints "report-only: --enforce applies to workspace PRs only ... (it is the default there)", naming a flag the caller never passed — `.agent/scripts/merge_pr.sh:924`

### Notes
Checked as asked. (a) `_is_bookkeeping_path`'s unquoted RHS is deliberate and safe — the pattern array is assigned unconditionally from literals, and `*` in a `[[ == ]]` glob spans `/`, so `.agent/work-plans/issue-300/progress.md` matches. `rev-list --parents` on a root commit is the one real hole (suggestion above); merges stop the walk correctly (two parents -> `wc -w` 2 -> return). With no `origin/main` the walk still terminates via the single-parent / bookkeeping / 25-step bounds; walking into the default branch's history needs a branch that is bookkeeping-only all the way down, in which case the candidate is bookkeeping-equivalent anyway. (b) No unbounded loop: `_ci_walked=true` is set before the walk, so the `continue` cannot re-enter it, and a switched target with no verdict falls back to the normal `case` and its grace/timeout deadlines. (c) `--report-only` and `--enforce` are plain assignments in one `case`, so the last flag wins; enforcement additionally requires `WORKTREE_TYPE == workspace`, and package PRs clear `WORKTREE_TYPE` (`merge_pr.sh:351`), so project/package scope is unchanged; the project-scope test's asserted substring "--enforce applies to workspace PRs only" is still present. Each test switched to `--report-only` was read against its label: they exercise cleanup, CI targeting, mergeability, idempotency and the PR-comment fallback, none of which depend on gate mode, and `run_merge_wait` places `--report-only` before `"$@"` so a later flag still wins. (d) AGENTS.md's row, the Makefile help line and `review_loop_lifecycle.md` check out against the script; run-issue steps 10/11 are accurate except the work-plans claim above, and dropping the `merge_pr.sh:NNN` line references is an improvement. (e) The walk's API cost is bounded at 25 candidates x 2 calls and stops at the first verdict. Verified: `test_merge_pr_gate.sh` 74/74, `test_merge_pr.sh` 91/91, shellcheck clean on both changed shell files via `.venv/bin/pre-commit` (available after all — earlier rounds reported it missing). An independent adversarial subagent, given no context from this read, reported the same must-fix #1 (with its own reproduction) and the same `origin/main` suggestion, and flagged the wider `.agent/work-plans/*` pattern as worth confirming; it judged the root-commit guard sound, which the reproduction above contradicts.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 11:43 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Address all six round-4 findings (three must-fix: the CI walk-back bypasses the running-review hold — evaluate the hold on the real head; two docs still say report-only by default; work plans missing from the gate's exempt list; three suggestions: root-commit walk, origin/main bound, project-scope wording) in a background address-findings agent, then re-review.

## Implementation
**Status**: complete
**When**: 2026-09-22 11:59 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-300 at eca522e
**Addressed**: Local Review (Pre-Push) at `5710fd2` (2026-09-22 11:38 -04:00)
**Commits**: 04ea5f1, f248d02, dd3032a, 4b86ead, eca522e

### Actions
- [x] (must-fix) Pending-review hold now reads the REAL PR head after the bookkeeping walk-back: `_ci_review_sha` holds the head, and each poll re-reads its excluded-run state (last known state retained across a failed read) so a running Copilot review still holds the merge; the review-pending error names the head, not the walked-back target — `.agent/scripts/merge_pr.sh:1162-1215`. New fixtures ci-32 (holds, "review still in progress") and ci-33 (`--allow-pending-review` merges on the green head's verdict) built on a shared `make_walkback_sandbox`; ci-30 still passes — `.agent/scripts/tests/test_merge_pr_gate.sh`
- [x] (must-fix) Three stale "report-only by default" statements corrected to "enforced by default on workspace PRs, `--report-only` opts out" — `.claude/skills/review-code/SKILL.md:659`, `.github/PULL_REQUEST_TEMPLATE.md:10`, `.agent/scripts/tests/test_merge_pr_gate.sh:4`
- [x] (must-fix) Gate allow-list widened to the issue's work-plans dir (`.agent/work-plans/issue-<N>/*`), so a plan addendum after the review keeps the review current, matching run-issue SKILL.md:425-427 and the owner's "related doc" rule; `_only_bookkeeping_between` now accepts glob entries (unquoted RHS, literal callers unaffected) — `.agent/scripts/merge_pr.sh:759-760`. New gate fixture g6 (`make_gate_sandbox plan-after`: review, then a plan.md-only commit → gate passes under the enforce default)
- [x] (suggestion) The walk now counts fields on the full `rev-list --parents` line (a root has one) and stops there, instead of `cut -d' ' -f2-` returning the line itself and making a root its own parent — `.agent/scripts/merge_pr.sh:1093`
- [x] (suggestion) The walk's stop bound comes from `resolve_default_branch "$wt"` (helper now sourced by merge_pr.sh) instead of a hardcoded `origin/main`; the helper was added to the sandbox copy lists in `test_merge_pr_gate.sh` and `test_merge_pr.sh` — `.agent/scripts/merge_pr.sh:1090`
- [x] (suggestion) Project-scope note reworded to "report-only: gate enforcement applies to workspace PRs only until #265 settles project timelines" — no flag named that the caller may not have passed; the scoping test drops its redundant `--enforce` and asserts the flag is absent — `.agent/scripts/merge_pr.sh:924`

### Verification
- `bash .agent/scripts/tests/test_merge_pr_gate.sh` — 77 passed, 0 failed (74 before, +2 CI walk-back fixtures, +1 gate plan-addendum fixture)
- `.agent/scripts/tests/run_script_tests.sh` — all 23 suites passed in 60s (`test_merge_pr.sh` 91/91)
- Pre-commit (incl. shellcheck) ran on every commit; nothing pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 12:06 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-300 at `8cb07c6`
**Base**: main
**Depth**: Standard (reason: enforcement script merge_pr.sh; re-review scoped to the fix range 5710fd2..8cb07c6, 186 changed lines)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 5 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked
**Dispatch**: resumed (round-4 reviewer, resume 1 of 3)

### Findings
- [ ] (suggestion) On the first poll after a walk-back, `_ci_head_excluded_last` is still empty: the pre-switch poll's excluded state is dropped by the `continue`, so if that first head re-read returns `error`, the hold falls back to "" and a `success` target merges past a review that is in fact running. Seed it with the pre-switch `_ci_excluded` before the `continue` — `.agent/scripts/merge_pr.sh:1204-1222`
- [ ] (suggestion) `_ci_review_sha` is captured from `CI_TARGET_SHA` after Step 2 has already decided it, so when Step 2's own-paths exemption applies it holds the reviewed head, not the real PR head the comment claims; the behaviour is defensible (a review re-triggered by this script's own bookkeeping push would otherwise deadlock every merge) but the comment should say which head it captures — `.agent/scripts/merge_pr.sh:1177-1181`

### Notes
All six round-4 findings verified fixed against source, not taken on report. (1) The hold now reads the head every poll while `_ci_review_sha != CI_TARGET_SHA`, and only `_ci_excluded` is overwritten — `_ci_state` still comes from the walked-back target, so a real CI failure there cannot be masked by the head read, and the head's own `CI failed:` line is correctly suppressed. Cost is two extra `gh api` calls per poll, only after a switch. ci-32 asserts both the hold and the head SHA in the error; ci-33 asserts `--allow-pending-review` merges; both build on one shared sandbox helper. (2) The three stale "report-only by default" statements now read correctly in `review-code/SKILL.md:659`, `PULL_REQUEST_TEMPLATE.md:10` and the gate suite header. (3) The gate's allow-list is `.agent/work-plans/issue-${ISSUE_NUM}/*`; the glob cannot widen the CI-target caller, whose paths are `_STEP1_COMMITTED_PATHS` (worktree-relative roadmap paths staged by Step 1) and the literal `.agent/work-plans/issue-<N>/progress.md` — none carry glob metacharacters, and `[[ ]]` does no word splitting on the unquoted RHS. g6 exercises a plan.md-only commit after the review under the enforce default and asserts the merge. (4) Field count on the whole `rev-list --parents` line: a root yields one field and the walk returns; a merge yields three and returns; an empty line (failed rev-list) yields zero and returns. (5) `resolve_default_branch "$wt"` matches the helper's documented signature (optional repo root, prints a local branch or `origin/<b>`, prints to stderr and returns 1 on failure); the failure path is contained by `2>/dev/null || echo ""`, and the resulting unset `base` is safe because merge_pr.sh runs `set -eo pipefail` without `-u` — the bound simply drops, as before, with the single-parent / bookkeeping / 25-step bounds still terminating the walk. Sourcing the helper at the top is side-effect-free and the copy lists in both sandboxes were updated. (6) The project-scope note names no flag and the scoping test now asserts `--enforce` is absent from the output. Verified: `test_merge_pr_gate.sh` 77/77, `test_merge_pr.sh` 91/91, `run_script_tests.sh` all 23 suites in 55s, shellcheck clean on both changed shell files via `.venv/bin/pre-commit`. Round 5 is past MAX_ROUNDS and nothing must-fix remains: ship.
