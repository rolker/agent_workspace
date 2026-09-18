# Plan: merge_pr.sh: --no-wait also skips the mergeability settle, so the script's own push makes the merge refuse

## Issue

https://github.com/rolker/agent_workspace/issues/290

## Context

In `.agent/scripts/merge_pr.sh` Step 2 (~lines 1045–1158), a single
`if [[ "$NO_WAIT" == false ]]; then ... else echo "CI wait skipped"; fi`
block wraps three things: the CI poll (`_ci_poll_state` loop), the
mergeability settle poll (`_wait_for_mergeable`, ~1130–1155), and gates the
one merge retry in Step 3 (line 1183, `[[ "$NO_WAIT" == false ]]`). Step 1.5's
own push always makes GitHub recompute `mergeable`, so `--no-wait` runs
straight into `gh pr merge` while it's still `UNKNOWN`, and there is no
retry to recover — exactly the #287 failure. The mergeability settle and
retry guard against the script's own push, not against CI, so they must run
even under `--no-wait`.

## Approach

1. **Split Step 2 into two independent gates.** Keep the CI-poll block
   (workflow-count check, `_ci_poll_state` loop, lines ~1053–1128) inside
   `if [[ "$NO_WAIT" == false ]]`, printing "CI wait skipped (--no-wait)" in
   the else branch as today. Move the mergeability settle block (currently
   1130–1155) to run unconditionally, right after the CI `if/else`, replacing
   the old placement inside the `then` branch.
2. **Un-gate the Step 3 merge retry.** Drop `[[ "$NO_WAIT" == false ]]` from
   the condition at line 1183 so a "not mergeable" refusal always triggers
   one re-poll + retry, matching the settle poll now always running.
3. **Fix the comment sites** that describe the old (buggy) semantics —
   confirmed against the current tree, so line numbers below are exact:
   - Header comment (lines 29–34): "Then wait for CI on that target SHA and
     let mergeability settle — --no-wait skips only the polling/waiting, not
     the CI-target computation" → state plainly that `--no-wait` skips only
     the CI poll; settle and retry always run.
   - Step 2 inline comment (lines 968–970): "--no-wait skips this whole step
     (and Step 5's mergeability settle below)" → correct to "--no-wait skips
     only the CI poll; the mergeability settle below always runs" (also
     fixes the stale "Step 5" reference — the settle lives in Step 2).
   - Step 3 inline comment (lines 1164–1168): line 1165 reads "...even after
     Step 5 settled `mergeable`" (stale — same Step-2 fix as above) and line
     1168 reads "--no-wait skips the retry too — there's nothing to
     re-poll" (now false) → correct both: settle is Step 2's; the retry
     always runs.
   `grep -n "Step 5" .agent/scripts/merge_pr.sh` after editing must return
   nothing.
4. **Give the mergeability settle zero-sleep test defaults, so the 27
   existing `run_merge` cases don't stall.** `run_merge()` (test file line
   157) always passes `--no-wait` and sets no `MERGE_PR_CI_*` env, and
   `make_sandbox()` (line 123) writes no `.mergeable.json` fixture — once
   the settle runs unconditionally, the gh stub's `pr view
   ...--json mergeable,mergeStateStatus` answers `UNKNOWN` forever (stub
   fallback at line 64), so every one of those 27 assertions would poll the
   full 120 s default grace at 10 s intervals before erroring at "never
   settled" — roughly 54 minutes added to the suite, and none of those
   tests would still exercise what they're named for. Fix in `run_merge()`
   itself (not per-call-site): add `MERGE_PR_CI_POLL_SECONDS=0` (no real
   sleeps in the settle loop) to its exported env, and in `make_sandbox()`
   call `write_mergeable_fixture "$sb" "MERGEABLE"` right after
   `write_gh_stub "$sb"` so the default fixture resolves on the settle's
   first poll — the loop's grace/timeout deadlines never matter for these
   cases because they never see a second UNKNOWN. Any test that wants
   `--no-wait` + a non-default mergeability path writes its own
   `write_mergeable_fixture` calls (which already override the fixture file
   `make_sandbox` wrote) and, if it wants to force the grace window to
   expire, its own `MERGE_PR_CI_GRACE_SECONDS=0` override — same pattern
   `run_merge_wait()`'s callers already use.
5. **Add the regression test for the settle actually running under
   `--no-wait`.** The originally planned assertion ("`--no-wait` +
   UNKNOWN→MERGEABLE merges") is not a valid regression test: the stub's
   `pr merge` (test file line 69) exits `${GH_MERGE_EXIT:-0}`
   unconditionally and never reads the mergeable fixture, so the unfixed
   script — which skips the settle poll entirely under `--no-wait` — reaches
   `gh pr merge` immediately and that call still succeeds; the assertion
   would pass on both the buggy and fixed code. Assert the *mechanism*
   instead: with `write_mergeable_fixture "$sb" "UNKNOWN" 1` then
   `write_mergeable_fixture "$sb" "MERGEABLE"` (seq 1 then the static
   fallback) and `GH_MERGE_EXIT=0`, call `run_merge "$sb"` and check
   `gh_calls.log` (via `GH_CALL_LOG`, already wired into `run_merge`) for a
   `pr view <PR> ... --json mergeable,mergeStateStatus` line appearing
   *before* the `pr merge` line — `grep -n` both patterns and compare line
   numbers, or `awk`/`grep -B`/`grep -A` on the ordered log. On today's code
   that ordering assertion fails (no `pr view ...mergeable...` call appears
   at all under `--no-wait`, since the settle block is skipped), so it is a
   real regression test. Keep the existing second case too: an `UNKNOWN`
   fixture with `MERGE_PR_CI_GRACE_SECONDS=0` and no seq file (stays
   `UNKNOWN` forever) — assert `run_merge` errors ("mergeability ... never
   settled") and `merged_called` is false; this one already fails against
   the current code for a different reason (no settle poll → straight to
   merge → `merged_called` true), so it's a valid regression case as
   originally planned.
6. **Add a test for the Step 3 merge retry**, which the original plan left
   entirely uncovered. Today's stub gives `pr merge` a single fixed exit
   code and no stderr (test file line 69:
   `elif [ "$1" = "pr" ] && [ "$2" = "merge" ]; then exit "${GH_MERGE_EXIT:-0}"`),
   so there's no way to make the first attempt fail with "not mergeable"
   and the second succeed. Extend the stub with a sequenced merge fixture,
   mirroring the existing `.mergeable_<N>.json` / `_seq` pattern already in
   the file (lines 60–64, 104–105): keep a per-sandbox counter file (e.g.
   `$GH_FIXTURES_DIR/.merge_seq`), and on each `pr merge` call look for
   `$GH_FIXTURES_DIR/merge_exit_<N>` (exit code, defaulting to
   `${GH_MERGE_EXIT:-0}` when absent) and `$GH_FIXTURES_DIR/merge_stderr_<N>`
   (stderr text, written to fd 2 before exiting, defaulting to empty). Add
   `write_merge_fixture() { <sb> <exit_code> <stderr> [seq_n] }` alongside
   the other `write_*_fixture` helpers. Test case: `write_merge_fixture "$sb"
   1 "Pull Request is not mergeable" 1` (call 1 fails) and
   `write_merge_fixture "$sb" 0 "" 2` (call 2 succeeds), plus
   `write_mergeable_fixture "$sb" "MERGEABLE"` so the settle poll (which now
   always runs, per item 4 above) doesn't itself block; run under `--no-wait`
   via `run_merge "$sb"`; assert `merge_count "$sb"` equals 2, the output
   contains "re-polling mergeability once and retrying", and the run
   succeeds (exit 0). Because the retry is currently gated on
   `[[ "$NO_WAIT" == false ]]` (line 1183), this case fails against today's
   code (first "not mergeable" exit is fatal, no second `pr merge` call) and
   passes once the retry is un-gated — a genuine regression test for item 2
   above.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Split Step 2's `NO_WAIT` gate: CI poll stays conditional; mergeability settle runs unconditionally; un-gate the Step 3 retry; fix the header comment, the Step 2 inline comment, and the Step 3 inline comment (including both stale "Step 5" references) |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | `run_merge()`: add `MERGE_PR_CI_POLL_SECONDS=0`; `make_sandbox()`: write a default `MERGEABLE` fixture; extend the `gh` stub's `pr merge` branch with a sequenced exit/stderr fixture + `write_merge_fixture()` helper; add 3 cases: `--no-wait` settle-poll ordering (UNKNOWN→MERGEABLE, asserted via `gh_calls.log` ordering, not just "did it merge"), `--no-wait` UNKNOWN-for-whole-grace-window errors, `--no-wait` merge-retry (sequenced "not mergeable" then success) |
| `AGENTS.md` | Tighten the `merge_pr.sh` script-reference row wording so it doesn't imply the mergeability settle/retry are skippable — covered by the #269 standing rule that script-reference-table row edits don't need separate Ask-First sign-off (see Open Questions) |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Each new/changed test asserts the mechanism (settle-poll ordering, retry call count), not just an end state a no-op change could also produce — item 5's original case 1 was cut for exactly this reason |
| A change includes its consequences | All four comment/doc sites the review flagged are corrected alongside the code; the settle's unconditional run is paired with the test-harness default fixture change (item 4) so the 27 existing `run_merge` cases keep passing instead of stalling |
| Only what's needed | No restructuring beyond splitting the one gate, un-gating the one retry condition, and the minimal stub extension (sequenced merge exit/stderr) needed to test the retry at all |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0013 — progress.md entry vocabulary | Yes | This plan's own persistence uses `## Plan Authored`; no new entry type introduced by the fix |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Step 2's `NO_WAIT` gating | Step 3's retry gating (same bug pattern) | Yes |
| Step 2/3 behavior | Header comment, Step 2 inline comment, Step 3 inline comment (both stale "Step 5" spots) | Yes |
| `--no-wait` semantics | `AGENTS.md` script-reference row | Yes — no separate approval needed (see Open Questions) |
| Mergeability settle running unconditionally | All 27 existing `run_merge` test-suite assertions, which today hit an untested, unfixtured `UNKNOWN`-forever path | Yes — `run_merge()` zero-sleep env + `make_sandbox()` default `MERGEABLE` fixture |
| Un-gating the Step 3 retry | Test coverage for the retry itself (previously none) | Yes — sequenced merge-exit/stderr stub fixture + dedicated test |

## Open Questions

None. The `AGENTS.md` script-reference row edit (Files to Change) does not
need a separate Ask-First round: the #269 progress timeline already
establishes that script-reference-table row edits are exempt from the
"modifying instruction files" Ask-First boundary (`.agent/work-plans/issue-269/progress.md`
line 704 — "Ask-First beyond script rows; left for the owner" — draws the
line at everything *except* the script-row table itself). This plan treats
the row tightening as part of the normal PR, not a boundary crossing.

## Estimated Scope

Single PR.
