---
issue: 290
---

# Issue #290 — merge_pr.sh: --no-wait also skips the mergeability settle, so the script's own push makes the merge refuse

## Issue Review
**Status**: complete
**When**: 2026-09-18 00:00 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #290

### Scope Assessment

**Well-scoped?** Yes — one script (`merge_pr.sh`), one flag's semantics, one test fixture gap. Fits a single PR.
**Right repo?** Yes — `merge_pr.sh` and its tests live in `.agent/scripts/`, workspace infra.
**Dependencies**: none identified. Direct follow-up to #284 (CI-target exemption / mergeability settle) and #289 (check-runs POST/404 fix), both merged. No open issue blocks this one.

Confirmed against source (`.agent/scripts/merge_pr.sh`, current `feature/issue-290` tree): the `if [[ "$NO_WAIT" == false ]]; then ... else echo "  CI wait skipped (--no-wait)"; fi` block at lines ~1045–1158 wraps both the CI poll *and* the `_wait_for_mergeable` settle-poll (lines 1130–1155), and the merge-retry re-poll at line 1183 is also gated on `[[ "$NO_WAIT" == false ]]`. So today `--no-wait` skips all three: CI wait, mergeability settle, and the one merge retry — exactly the bug the issue reports. The test harness confirms the coverage gap: `run_merge()` (the helper most gate tests use) always passes `--no-wait` and never writes a `write_mergeable_fixture` for it, so the mergeability path is untested under `--no-wait`; `write_mergeable_fixture`/settle-poll cases (ci-7, ci-8, ci-13) all go through `run_merge_wait()`, which omits `--no-wait` entirely.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | Action needed | Issue already specifies the exact regression fixture (`--no-wait` + `mergeable: UNKNOWN`→`MERGEABLE`); this is the right target, not a general coverage pass. |
| A change includes its consequences | Watch | The header comment (line ~968-970: "--no-wait skips this whole step (and Step 5's mergeability settle below)") and the `AGENTS.md` script-reference row ("`--no-wait` to skip the CI wait") both describe today's (buggy) behavior. Both need the one-line correction the issue already calls for ("--no-wait skips only the CI poll"), or a reader will re-derive the wrong mental model from the docs after the code is fixed. |
| Only what's needed | OK | Fix is a narrow scope split (CI poll vs. mergeability settle/retry), not a rewrite of Step 2/3. |
| Improve incrementally | OK | Builds on #284's existing structure without restructuring it. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0013 — progress.md entry vocabulary | Yes | This review's own persistence must use `## Issue Review`; the fix itself writes no new progress.md entry type. |
| Others | No | No worktree, adapter, or enforcement-hierarchy changes implicated. |

### Consequences

- `AGENTS.md`'s `.agent/scripts/merge_pr.sh` reference-table row currently reads "`--no-wait` to skip the CI wait" — accurate wording once fixed (it should say the settle/retry still run), but worth a one-line touch alongside the fix so the table doesn't quietly re-describe the old behavior.
- The script's own header comment (Step 2's block, "`--no-wait` skips this whole step (and Step 5's mergeability settle below)") is the same claim in a second place and needs the matching correction the issue asks for.
- No other reader of `merge_pr.sh` (dispatch_phase.sh, review_progress.sh, other skills) branches on `--no-wait` semantics, so no cascading update beyond the two doc spots above and the test fixture the issue names.

### Actions
- [ ] Issue already specifies the exact regression fixture (`--no-wait` + `mergeable: UNKNOWN`→`MERGEABLE`); this is the right target, not a general coverage pass.
- [ ] Split the single `if [[ "$NO_WAIT" == false ]]` block into two independent gates: one for the CI poll (skippable), one for the mergeability settle + merge-retry (not skippable) — rather than adding a second flag or an early exception inside the same block, to keep the "skips only CI" contract structurally obvious.
- [ ] Add the fixture-driven test case named in the issue (`--no-wait` + `mergeable: UNKNOWN`-then-`MERGEABLE`) using the existing `run_merge`/`write_mergeable_fixture` helpers, and verify it currently fails (merge attempted while still UNKNOWN, or the settle poll skipped) before the fix, then passes after.
- [ ] Update the two comment sites (script header, Step 2 inline comment) and the `AGENTS.md` script-reference row together with the code change, not as a follow-up.

## Checkpoint
**Status**: complete
**When**: 2026-09-18 13:40 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

proceed, but this question suffers from an issue I complained about in ros2 agent workspace where the question is a dense, hard to read paragraph.
