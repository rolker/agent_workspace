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
3. **Fix the three comment sites** that describe the old (buggy) semantics:
   - Header comment (~lines 29–34): "Then wait for CI on that target SHA and
     let mergeability settle — --no-wait skips only the polling/waiting, not
     the CI-target computation" → state plainly that `--no-wait` skips only
     the CI poll; settle and retry always run.
   - Step 2 inline comment (~lines 968–970): "--no-wait skips this whole step
     (and Step 5's mergeability settle below)" → correct to "--no-wait skips
     only the CI poll; the mergeability settle below always runs".
   - Step 3 inline comment (~line 1168): "--no-wait skips the retry too —
     there's nothing to re-poll" → correct to state the retry always runs.
4. **Update `AGENTS.md`'s `merge_pr.sh` script-reference row** so it doesn't
   re-describe skipped-mergeability-settle behavior once fixed (current
   wording — "`--no-wait` to skip the CI wait" — already reads correctly
   post-fix; confirm no edit needed, or tighten if it implies more is
   skipped).
5. **Add the regression test** to `test_merge_pr_gate.sh`: `--no-wait` +
   `write_mergeable_fixture ... UNKNOWN` (seq 1) then `MERGEABLE`, via
   `run_merge` (which always passes `--no-wait`) with `GH_MERGE_EXIT=0` and
   zero-sleep env (`MERGE_PR_CI_POLL_SECONDS=0`) — assert it merges. Add a
   second case: `UNKNOWN` fixture for the whole grace window with
   `MERGE_PR_CI_GRACE_SECONDS=0` under `--no-wait` — assert it errors
   ("mergeability ... never settled") and does not merge. Verify both fail
   against the current code (settle skipped under `--no-wait`, so case 1
   would try to merge while still `UNKNOWN`) before applying the fix.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Split Step 2's `NO_WAIT` gate: CI poll stays conditional; mergeability settle runs unconditionally; un-gate the Step 3 retry; fix 3 comment sites |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Add 2 cases: `--no-wait` + UNKNOWN→MERGEABLE merges; `--no-wait` + UNKNOWN for whole grace window errors |
| `AGENTS.md` | Confirm/tighten the `merge_pr.sh` reference row wording |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Regression tests target exactly the `--no-wait` + settle-poll gap the issue names, not a general coverage pass |
| A change includes its consequences | Both doc/comment sites the review flagged are corrected alongside the code |
| Only what's needed | No restructuring beyond splitting the one gate and un-gating the one retry condition |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0013 — progress.md entry vocabulary | Yes | This plan's own persistence uses `## Plan Authored`; no new entry type introduced by the fix |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Step 2's `NO_WAIT` gating | Step 3's retry gating (same bug pattern) | Yes |
| Step 2/3 behavior | Header + inline comments describing old behavior | Yes |
| `--no-wait` semantics | `AGENTS.md` script-reference row | Yes (verify wording) |

## Open Questions

None.

## Estimated Scope

Single PR.
