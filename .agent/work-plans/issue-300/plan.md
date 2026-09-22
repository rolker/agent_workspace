# Plan: merge_pr.sh: Copilot's review check-run ("changes recommended", no findings) is counted as a CI failure and blocks the merge

## Issue

https://github.com/rolker/agent_workspace/issues/300

## Context

`_ci_poll_state()` in `.agent/scripts/merge_pr.sh` (lines 978-1021) fetches
all check-runs and commit statuses for the CI target SHA and classifies the
result as `failed` if *any* check-run has a terminal non-success conclusion
(`failure`, `cancelled`, `timed_out`, `action_required`, `startup_failure`,
`stale`; line 1007). GitHub's `copilot-pull-request-reviewer` check-run sets
`conclusion: failure` both when its review says "Changes recommended" and —
observed today on PR #308 (issue #307) — when Copilot's quota is exhausted.
Neither case is a real CI failure: the review verdict is already consumed by
`triage-reviews` → `## Integrated Review`, and quota exhaustion isn't CI at
all. The fix must exclude this one check-run **by name, for any conclusion**,
not by parsing its review text (owner's review note; a text-based exclusion
would have missed the quota-exhaustion recurrence).

`_ci_poll_state` is covered today by `.agent/scripts/tests/test_merge_pr_gate.sh`
(not `test_merge_pr.sh` — confirmed by inspection: the `CHECKRUNS_*` fixtures,
`write_checkruns`/`checkruns_path` helpers, and tests `ci-4` through `ci-12b`
at lines 187-721 all live in `test_merge_pr_gate.sh`; `test_merge_pr.sh` has
no check-run fixtures at all). Fixtures go there.

## Approach

1. **Add a named exclusion constant near the top of `_ci_poll_state`** (or
   just above it, alongside the existing `MERGE_PR_CI_*` env-var block at
   lines 974-976) — a single read-only value, not a list:
   ```bash
   # Copilot's review check-run reports `conclusion: failure` for two
   # non-CI reasons: a "Changes recommended" verdict (already consumed by
   # triage-reviews -> ## Integrated Review) and quota exhaustion (issue
   # #300; recurred on PR #308/#307). Excluded by name, for any
   # conclusion, from CI classification below.
   readonly MERGE_PR_CI_EXCLUDE_CHECK_RUN="copilot-pull-request-reviewer"
   ```

2. **Filter `runs_json`'s `check_runs` by name before every classification
   step** in `_ci_poll_state` (the `registered`, `failed`, and `pending`
   jq computations at lines 1000-1019) — one added `jq` filter
   `select(.name != $exclude)` (passed via `--arg exclude
   "$MERGE_PR_CI_EXCLUDE_CHECK_RUN"`), applied once to build a filtered
   `check_runs` array, then reuse that filtered array in the three
   existing jq expressions instead of `$r.check_runs`. Commit statuses
   (`$s.statuses`) are untouched — the exclusion is scoped to this one
   named check-run, not a general allow/deny list. This is a pure filter
   over `runs_json`/`status_json`, both already fetched by the two `gh api`
   calls at lines 987-989 — no new wait, poll, or `gh api` round trip.

3. **Diagnostic output** — inside `_ci_poll_state`, write to stderr (so it
   doesn't corrupt the function's stdout return value, which callers
   capture via `$(...)`):
   - When the excluded check-run is present in the raw (unfiltered)
     `check_runs`, print its conclusion and state clearly that it was
     **not** used to block the merge, e.g.:
     `  (check-run 'copilot-pull-request-reviewer' conclusion=failure — excluded from CI status, not used to block the merge)`
   - When the classification resolves to `failed`, print the name(s) of
     the (non-excluded) check-run(s) / status context(s) that caused it,
     e.g.: `  CI failed: <name1>, <name2>`. This satisfies the issue's
     request to make a failed verdict diagnosable from the script's own
     output.
   Both lines are additive to the existing `echo "failed"` /
   `echo "success"` return-value lines — they must go to `>&2`, not
   stdout, since `_ci_state=$(_ci_poll_state "$CI_TARGET_SHA")` (line 1075)
   only wants the bare state word on stdout.

4. **Fixtures in `test_merge_pr_gate.sh`** — add a `CHECKRUNS_COPILOT_FAILURE`
   fixture constant alongside the existing `CHECKRUNS_*` block (lines
   213-218):
   ```bash
   CHECKRUNS_COPILOT_FAILURE='{"check_runs":[{"name":"copilot-pull-request-reviewer","conclusion":"failure","status":"completed"}]}'
   ```
   and two new tests near the existing CI-wait tests (after `ci-12b`,
   around line 696), following the `make_ci_sandbox` / `write_checkruns` /
   `run_merge_wait` pattern used by `ci-4` through `ci-12b`:
   - **ci-19**: check-runs = `{copilot: failure, Lint: success}` (a
     two-element `check_runs` array combining the copilot fixture with a
     named `Lint` success run) → merge proceeds (`merged_called` true,
     output contains `CI checks passed`).
   - **ci-20**: check-runs = `{copilot: failure, Lint: in_progress}` →
     with a short grace/timeout window, state stays `pending`/times out
     without a real CI failure being reported — assert `merged_called`
     is false and the output does **not** contain `CI checks failed`
     (it should time out or report `never-registered`/timeout wording
     instead, since the only non-excluded run is still in progress).
   - Also add a regression test that a genuine CI failure still fails:
     check-runs = `{copilot: failure, Lint: failure}` → `merged_called`
     false and output contains `CI checks failed`, confirming the
     exclusion doesn't mask a real failure that happens to co-occur with
     a Copilot failure.
   Wire all three into the "Run all tests" list at the bottom of the file
   (mirroring lines 729-749).

5. **One-line script comment only — no doc/table changes.** The exclusion
   rationale lives in the code comment from step 1. Per the owner's
   Checkpoint decision, `AGENTS.md`'s script-reference table row for
   `merge_pr.sh` is only touched if its *wording* changes; this fix doesn't
   change the row's meaning ("waits for CI on the reviewed head" still
   holds — the fix changes what counts as CI, not the wait behavior), so
   leave the table alone and avoid triggering the Ask-First instruction-file
   gate.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Add `MERGE_PR_CI_EXCLUDE_CHECK_RUN` constant + comment; filter `check_runs` by name in `_ci_poll_state`'s `registered`/`failed`/`pending` jq computations; add stderr diagnostics (excluded-run note, failed-run names) |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Add `CHECKRUNS_COPILOT_FAILURE` fixture constant; add ci-19 (copilot failure + Lint success → success), ci-20 (copilot failure + Lint in_progress → pending/no false failure), and a genuine-failure regression test; wire into the test-run list |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Fix is in the classification logic itself (`_ci_poll_state`), not a doc note about the current behavior. |
| Test what breaks | Three new fixtures cover exactly the regression (masking a real bug) and the fix (not blocking on Copilot alone), per the owner's specified cases plus one added regression case. |
| Human control and transparency | Stderr diagnostics name the excluded check-run and state explicitly it wasn't used to block, and name whichever check-run(s) did cause a real `failed` verdict. |
| Only what's needed | Single named constant, not a list/allowlist mechanism — scoped to the one confirmed check-run (`copilot-pull-request-reviewer`), matching the owner's Checkpoint decision to not speculatively generalize. |
| A change includes its consequences | Verified which test file owns this coverage (`test_merge_pr_gate.sh`) before adding fixtures there rather than guessing or creating a new file. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0013 — progress.md entry-type vocabulary | No | No new entry type; standard `plan-task` → `## Plan Authored` entry. |
| 0011 — Project-type adapter contract | No | `merge_pr.sh` CI classification is generic, not project-shape-dependent. |
| 0004/0005 — Enforcement hierarchy | Yes | The fix is itself part of the merge gate; the regression is caught by the test suite (step 4), not left to manual verification. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `_ci_poll_state`'s classification of `check_runs` | `test_merge_pr_gate.sh` fixtures/tests that assert on CI state | Yes — step 4 |
| Diagnostic output text (new stderr lines) | Any test asserting exact/full output equality | No known test does full-output equality matching for `_ci_poll_state` callers (all existing tests use substring `[[ "$out" == *"..."* ]]` checks per lines 646/658/669/680/691/705/716), so no other test should need updating — verify during implementation that no test breaks on the added stderr lines |
| `AGENTS.md` script-reference table row for `merge_pr.sh` | N/A | No — row wording unaffected; owner flagged doc wording changes as Ask-First, so deliberately left alone (see Approach step 5) |

## Open Questions

- None blocking. One implementation-time check carried into step 4/the
  Consequences table: confirm no existing `test_merge_pr_gate.sh` test
  asserts on `_ci_poll_state` output via exact match (as opposed to
  substring match) that the new stderr diagnostic lines would break.

## Estimated Scope

Single PR — one script change (`merge_pr.sh`) plus fixtures/tests in the
one test file that already owns this coverage (`test_merge_pr_gate.sh`).
