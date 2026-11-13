---
issue: 459
---

# Issue #459 — dispatch_phase: multi-PR issue routing

## Issue Review
**Status**: complete
**When**: 2026-11-13 09:12 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #459

### Scope Assessment

**Well-scoped?** Yes, with one Watch. The two dispatcher symptoms (round count carries over; `next` answers `merge` after a merge) share one root cause: the timeline has no "a pull request ended here" boundary. Both are fixed by one rule, so they belong in one PR. `restart_start()` in `dispatch_phase.sh` and the matching Python in `review_progress.sh cmd_round` already implement "count only entries after the newest `Decision: restart` checkpoint" and say they must be kept in step; the fix extends that start-of-new-work rule rather than adding a second mechanism. The `review_progress.sh findings` gap and the stale-box listing are in the same script and the same timeline logic; keeping them in this PR is reasonable if each is its own atomic commit, otherwise split them (the issue allows it).
**Right repo?** Yes. `dispatch_phase.sh`, `review_progress.sh`, `run-issue/SKILL.md` and `docs/design.md` are workspace files; the evidence comes from a package-repository drive, but nothing here is project-specific.
**Serves**: Keep work moving without the owner (the review loop driven by `/run-issue`) — `docs/design.md#review-loop-and-timeline`
**Design picture?** Changes "Review loop and timeline" — the table row for `review-code` ("after 3 rounds (`MAX_ROUNDS`) without approval") and the `merge` row describe one pull request per issue. Round counting per reviewed diff and a defined route after a merge on an open issue change how those parts fit (see the Principle Alignment row).
**Dependencies**: Pull request 461 (open) edits `dispatch_phase.sh` (pre-push task line gains `origin/<base>` for a package issue), `run-issue/SKILL.md`, `docs/design.md`, `test_package_issue_loop.sh` and `merge_pr.sh`; the plan must expect a merge with it, and should land after 461 or name the touched regions. Issue 429's remaining parts depend on this being fixed to stop hand-routing.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | The change alters the round rule and the post-merge route described in `docs/design.md#review-loop-and-timeline`. The issue leaves the post-merge step ("straight to `implement` when the plan covers the part and its plan checkpoint was `proceed`; a plan refresh otherwise") to the plan, so the owner has not decided it. Bring the post-merge route and the per-pull-request round rule to the owner as their own question; the plan then names the design section it edits. |
| Enforce what matters, as simply as possible | Watch | The boundary signal needs a simple yes/no definition. A successful merge writes no entry (`merge_pr.sh` records only a gap); the only trace is the `Decision: merge` checkpoint, and that checkpoint also precedes a merge that is refused or fails. The simplest sound rule is likely "a `merge`-decision checkpoint that is not the newest entry", or "newest entry is that checkpoint and `--pr none`"; the plan must pick one and test the refused-merge path so a failed merge is not read as a boundary. |
| Test what breaks | Watch | The acceptance asks for synthetic-timeline tests in `test_dispatch_phase.sh`. `review_progress.sh round` and `findings` share the boundary rule and have their own callers; cover them too (a test per script that fails without the fix), and a restart-plus-merge timeline so the two boundaries compose. Issue 429's `progress.md` is a ready real-world fixture to model on. |
| A change includes its consequences | Watch | Docs naming the single-PR assumption: `docs/design.md` (Review loop and timeline, Merge gate), `run-issue/SKILL.md` (multi-PR drive: `Part of #N`, worktree and branch recreated after each merge, last PR closes), `.agent/knowledge/review_loop_lifecycle.md`, `script_reference.md`, and the header comments of both scripts that say "keep in step". |
| Small steps; step back when they stop converging | Watch | Four items (round count, post-merge route, `findings` reading `## Local Review`, stale boxes from merged pull requests) plus a skill doc. Sequence them as separate commits; the first two are the core. |
| Only what's needed | OK | Reuses the existing restart-boundary pattern; no new entry type is required if the boundary is derived from the existing merge checkpoint (ADR-0013 forbids a new type without a superseding ADR). |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0013 — entry-type vocabulary | Yes | No new entry type for a "merged" marker; derive from `## Checkpoint` (`After: merge`, `Decision: merge`) or write an existing type. A new type would need a superseding ADR. |
| 0014 — In-process phase handoff | Yes | Touches `dispatch_phase.sh` task lines and `run-issue`; exit checks stay mechanical and the handoff contract still prints from `dispatch_phase.sh`. |
| 0017 — Design document is the current picture | Yes | Update `docs/design.md` in the same change; no ADR needed (detail stays in the script header). |
| 0004 / 0005 — Enforcement | Marginal | The merge gate (`merge_pr.sh`) is unchanged; do not weaken its head-vs-review check when scoping reviews to a pull request. |

### Consequences

- Update `docs/design.md#review-loop-and-timeline` and the Merge gate text, `run-issue/SKILL.md`, `review_loop_lifecycle.md`, `script_reference.md`, and the script header comments.
- `review_progress.sh` `round`, `findings`, and the stale-coverage listing must use the same boundary as `dispatch_phase.sh next`; the "keep in step" comments already name this coupling.
- Rebase onto or sequence behind pull request 461.

### Recommendations

- Define the boundary once (a merge-decision checkpoint followed by later entries, or newest with `--pr none`) and share it between `dispatch_phase.sh` and `review_progress.sh` instead of a third copy of the entry scan; test the refused-merge and restart-plus-merge cases.
- Decide the post-merge route in the plan from the timeline: `implement` when the newest `Plan Review`/`plan` checkpoint was `proceed` and the plan names a part not yet delivered, `plan-task` otherwise; if the plan cannot tell, route to a checkpoint rather than guess.
- Fold in the `findings` post-publish `## Local Review` reading and the merged-pull-request stale-box filtering as separate commits (same script, same boundary); split them off only if the plan review finds the PR too large.
- Add a multi-pull-request section to `run-issue/SKILL.md` (`Part of #N` in the body, worktree and branch recreated after each merge, only the last pull request says `Closes #N`).
- Sequence behind or rebase onto pull request 461 and name the shared regions of `dispatch_phase.sh` and its tests in the plan.

### Actions
- [ ] The change alters the round rule and the post-merge route described in `docs/design.md#review-loop-and-timeline`. The issue leaves the post-merge step ("straight to `implement` when the plan covers the part and its plan checkpoint was `proceed`; a plan refresh otherwise") to the plan, so the owner has not decided it. Bring the post-merge route and the per-pull-request round rule to the owner as their own question; the plan then names the design section it edits.
- [ ] Define the boundary once (a merge-decision checkpoint followed by later entries, or newest with `--pr none`) and share it between `dispatch_phase.sh` and `review_progress.sh` instead of a third copy of the entry scan; test the refused-merge and restart-plus-merge cases.
- [ ] Decide the post-merge route in the plan from the timeline: `implement` when the newest `Plan Review`/`plan` checkpoint was `proceed` and the plan names a part not yet delivered, `plan-task` otherwise; if the plan cannot tell, route to a checkpoint rather than guess.
- [ ] Fold in the `findings` post-publish `## Local Review` reading and the merged-pull-request stale-box filtering as separate commits (same script, same boundary); split them off only if the plan review finds the PR too large.
- [ ] Add a multi-pull-request section to `run-issue/SKILL.md` (`Part of #N` in the body, worktree and branch recreated after each merge, only the last pull request says `Closes #N`).
- [ ] Sequence behind or rebase onto pull request 461 and name the shared regions of `dispatch_phase.sh` and its tests in the plan.
