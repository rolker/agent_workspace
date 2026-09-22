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
