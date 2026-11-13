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

## Checkpoint
**Status**: complete
**When**: 2026-11-13 09:13 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review's actions are inputs to the plan; none changes the issue's scope by proceeding. The design question, action 1, is held for the owner and put to him at the plan checkpoint, with the plan's concrete proposal in front of him)
**After**: issue-actions
**Decision**: proceed

Proceed to the plan. For the plan: (2) define the "a pull request ended here" boundary once, shared by dispatch_phase.sh and review_progress.sh, never reading a refused merge as a boundary, with tests for the refused-merge path and a restart-plus-merge timeline; ADR-0013 rules out a new entry type without a superseding ADR, so prefer a boundary derivable from existing entries, and say plainly if none is sound. (3) propose the post-merge route from the timeline and state it as the design question for the owner, with what it changes in docs/design.md#review-loop-and-timeline, how hard it is to undo, and a recommendation. (4) host decision: the findings reading of a post-publish Local Review rides along as its own atomic commit, since the issue names it; the stale-box filtering rides along only if it falls out of the same boundary with no extra mechanism, otherwise it is left out and noted. (5) a multi-pull-request section in run-issue's SKILL.md. (6) expect pull request 461 to merge first: plan against main plus 461's changes to dispatch_phase.sh and its tests.

## Plan Authored
**Status**: complete
**When**: 2026-11-13 09:40 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-459/plan.md` at `f6b9c537`

One shared boundary: a merge-decision checkpoint, then the first Plan Authored or Branch-correlated Implementation after it; used by dispatch_phase.sh and review_progress.sh. After a merge with no PR, next answers plan-task; the host writes a plan/proceed checkpoint to go straight to implement. The design question (i)/(ii) goes to the owner at the plan checkpoint.

## Plan Review
**Status**: complete
**When**: 2026-11-13 09:22 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #459 — dispatch_phase: multi-PR issue routing
**Plan**: `.agent/work-plans/issue-459/plan.md` at `f6b9c537`
**Branch**: `feature/issue-459`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One root cause, five atomic commits; 3 and 4 separable. |
| Issue alignment | Needs work | Serves: "Keep work moving without the owner (the review loop driven by `/run-issue`) — `docs/design.md#review-loop-and-timeline`" (checked). Both acceptance items are covered; the post-merge route (ii) and its probe rule break the end of every single-pull-request issue (finding 1). |
| File targeting | Good | Right files. `cmd_sources` must switch from a `--type`-filtered read to the whole timeline to slice (the plan says so). |
| Consequences | Needs work | Missing: what decides `done` once `--pr merged` no longer fires; the hand-merge limitation; the package-issue close path. |
| Principle alignment | Needs work | "Enforce what matters, as simply as possible": the boundary depends on correlation discipline that real timelines break (findings 2, 3). "Test what breaks": add the real 332 sequence and a handoff test for the acceptance's "with outside reviewers". |
| ADR compliance | Good | 0013: no new type or field; deriving meaning from order has precedent (the restart rule lives in script headers and `docs/design.md`, not in ADR-0013), so no ADR edit is needed, but the plan should cite the invariant it relies on: ADR-0013's correlation table, `**Branch**` only "if no PR exists yet". 0014, 0017 fine. |
| ROS conventions | N/A | Workspace plan. |

### Replay of the boundary rule (throwaway Python over `progress_read.py`)

- 429 (main, PRs 445/456/460) and 429 at pull request 461's head (fourth PR): boundaries at entries 25, 50, 71, each the `## Plan Authored` right after the `merge` checkpoint. Correct. Every pre-push and PR-mode fix entry carries `**Addressed**`; PR-mode fixes carry `**PR**`. Part 4's first pre-push review (entry 78) counts as round 1.
- 455, 451, 437, 425 (single PR): no boundary; each ends on an armed `merge` checkpoint with nothing after. Harmless for counting.
- 332 (four PRs): boundaries at 67 and 81, correct, including entry 63 (`merge`) → 64 a host merge-from-main `## Implementation` with no `**Addressed**` (PR-correlated) → re-review → merged with no second checkpoint → 67. But PR 403's merge has no `merge` checkpoint at all: part 2 starts at entry 42 with no boundary (finding 2). 276 and 335 are multi-PR with no merge checkpoints either.
- 354: `After: findings`, `Decision: merge` arms (correct, single PR). Its entry 12 is a `**Branch**`-correlated, `**Addressed**`-less `## Implementation` written while PR 355 was open (finding 3).
- Adversarial sequences: refused merge (no entry) → `merge`/`address` checkpoint → PR-correlated address → second `merge` → landed → Plan Authored: one boundary, at Plan Authored. Correct. Restart after merge, merge after restart: compose. `stop`/`--resume`: a `stop` is not a merge decision, no arm. Takeover `**Mode**: inline` Implementation: either it is the start (correct) or a failed implement before it already was.

### Findings

1. **[Issue alignment / Consequences]** must-fix: the probe rule plus the new row turns a finished single-PR issue into `plan-task`. Sequence: issue 451 (merged, timeline ends at a `merge` checkpoint) → `/run-issue 451` (resume) → step 1 recreates `feature/issue-451` from main → today the `--state all` probe finds MERGED → `--pr merged` → `done`. With "MERGED counts only when `headRefOid` == HEAD" the probe gives `none` (a merge commit never equals the PR head) → new row → `plan-task` on a closed issue. The same for 455, 437, 425. The "is the issue still open" check is in the multi-PR section only; it has to be a general step before the probe (closed → `done`), and row 1 is then effectively dead (it fires only when the worktree survived at the PR head, which is also when an owner's hand-merge mid-issue would end the run with parts left). And issue-open is not a reliable "parts remain" signal for a package issue: `Closes #N` closes only on a merge into the default branch, so a package PR on a pinned non-default base never closes the workspace issue, and the last part would route to `plan-task`. Say what closes it (host `gh issue close` after the owner confirms the last part, or the owner).
2. **[Principle alignment]** should-fix: a merge done without a `merge` checkpoint leaves no boundary. Real: 332, PR 403's Integrated Review (entry 41) is followed directly by part 2's `**Branch**` Implementation (42); the rule keeps start=0, so part 2's first pre-push review (43) counts part 1's reviews and raises `checkpoint:rounds`, the bug this issue fixes. Name the limitation and the remedy in the multi-PR section (the host records the owner's merge as a `merge` checkpoint, `Decided-by: owner`, before the next part, or a `restart`), and add it as a test.
3. **[Principle alignment]** should-fix: the rule reads any `**Branch**`-correlated, `**Addressed**`-less Implementation after an armed checkpoint as a boundary, and that shape is written while a PR is still open (354 entry 12) and host fixes after a `merge` decision are written without `**Addressed**` (332 entry 64). Sequence: `merge` → merge blocked (no entry) → host merges main in and writes `## Implementation` with `**Branch**` (run-issue step 8's pre-push form) → false boundary: the round count resets and a later failed fix pass maps to `implement`. Harden: disarm on a `Merge (…)` record or on a later Checkpoint at `merge`/`findings`/`merge-refused` with a non-`merge` answer (re-armed by the next `merge`). Replayed, this keeps 332's real boundary at 67 (no checkpoint between 63 and 67). Do not disarm on PR-correlated entries: that loses 332's 67. Test 332's sequence and the false-boundary sequence.
4. **[Issue alignment]** should-fix: (ii) should answer `checkpoint:plan`, not `plan-task` plus a host-written plan checkpoint. The plan's shortcut has the host write an answer (`After: plan`, `proceed`) to a checkpoint `next` never raised; run-issue routes on the printed token and writes a checkpoint only when one was raised ("No auto-chaining"). `checkpoint:plan` is existing vocabulary: `proceed` → `implement`, `revise` → `plan-task`; `/orchestrator`'s table already lets the host answer both (and caps two host `revise` answers), so wall-clock is kept when the plan covers the next part; without `/orchestrator` the owner gets one question, where `plan-task` → `review-plan` would reach the same checkpoint after a plan cycle anyway.
5. **[Consequences]** suggestion: the LGTM placeholder. `findings` does not filter it for Pre-Push today, so "mirror Pre-Push" means no filter; an approved review is never an address source in practice (rows 22a/14 route on the verdict). The repeated noise on 429 (triage lines on the "No issues found. LGTM." box) comes from `sources` and the triage reading. `sitrep` already filters it (`startswith("No issues found")`). Put one predicate (approved verdict and that text) in the shared module, used by `sources` and `findings`, instead of a third or fourth copy; or leave it out and say so.
6. **[Scope]** suggestion: the plan is 207 lines against plan-task's 30 to 80. Move the alternatives-rejected list and the "For the owner" block into the owner's question (they are its content, not the implementer's), and shrink "Sequencing with 461" to the file list; keep the rule, the row, the commit list and the tests.
7. **[File targeting]** suggestion: in both inline `-c` scripts, pass the script directory through the environment (single-quoted `-c` cannot interpolate) and use a plain `from pr_start import pr_start`: `suites_for_files.sh` maps Python imports in shell `-c` text, so `pr_start.py` reaches `test_dispatch_phase.sh` and `test_review_code_convergence.sh` through the derived closure with no `# covers:` line; `importlib` or `__import__` would not be mapped. A short direct test of `pr_start` against the 429 and 332 timelines is cheap.
8. **[Principle alignment]** suggestion: add a handoff test (`dispatch_phase.sh --skill review-code`, part 2's first pre-push review) asserting the task line carries no "no cross-model reviewers": the acceptance says "with outside reviewers", and the plan tests only `next` and `round`.
9. **[Context]** nit: main holds three merged PRs of 429 (445, 456, 460); the fourth is pull request 461, which also appends 854 lines to 429's `progress.md` and adds 8 lines to `cmd_handoff` just above the round-3 block (lines 529-537). Model the four-PR fixture on 461's head.

### Summary

The boundary rule (i) is right on every real multi-PR timeline that has its merge checkpoints (429 at 461's head, 332's later parts), with two gaps to close before it goes to the owner: hand merges with no checkpoint, and a false boundary from `**Branch**`-correlated Addressed-less entries while the PR is open. The post-merge route (ii) is not ready: the probe rule sends every finished single-PR issue to `plan-task` on resume, the package close path is unaddressed, and `checkpoint:plan` is a better answer than `plan-task` plus an unraised host checkpoint.

### Recommended Actions

- [ ] Make "issue closed → `done`" a general step before the probe, say what closes a package issue on a non-default base, and test a finished single-PR issue on a recreated branch (finding 1).
- [ ] Name the hand-merge limitation and its host remedy; add 332's PR 403 shape as a test (finding 2).
- [ ] Disarm on a Merge record or a non-`merge` answer at `merge`/`findings`/`merge-refused`; test 332's real sequence and the merge-from-main false boundary (finding 3).
- [ ] Route merge-checkpoint-newest with `--pr none` to `checkpoint:plan`; drop the off-table host write (finding 4).
- [ ] Decide the placeholder predicate once, in the shared module, or leave it out explicitly (finding 5).
- [ ] Cut the plan to the guideline (finding 6); import mechanics, handoff test, 461 fixture (findings 7 to 9).

## Checkpoint
**Status**: complete
**When**: 2026-11-13 09:24 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (plan review verdict needs-work; the design proposal is not ready to put to the owner; first revise at this checkpoint)
**After**: plan
**Decision**: revise

Revise for all nine findings. Host decisions: (1) "the issue is closed" ends the run as a general step before the pull-request probe, so a finished one-pull-request issue never resumes into a plan; the plan says what closes the issue in each case, including a pull request whose base is not the default branch (where "Closes #N" does not fire), without the loop closing an issue on its own. (2) A merge that left no merge checkpoint leaves no boundary: name the limitation, the host's remedy using existing vocabulary, and test it. (3) The armed state is disarmed by a Merge record or by a later merge, findings or merge-refused checkpoint with a non-merge answer, as the review's replay showed; not by PR-correlated entries. (4) After a merge with the issue open and no pull request, next answers checkpoint:plan, not plan-task: proceed routes to implement, revise to plan-task, both already in the table. (5) One shared predicate for the "No issues found. LGTM." placeholder of an approved review, used by findings and sources. (6) Cut the plan to size: rejected alternatives and the owner block move into the owner's question. (7) A plain "from pr_start import pr_start" with the script directory passed through the environment. (8) A handoff test that the next part's first pre-push review task line has no "no cross-model reviewers". (9) Build the multi-pull-request test timeline from pull request 461's head.

## Plan Authored
**Status**: complete
**When**: 2026-11-13 09:50 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-459/plan.md` at `7afb7867`

Revision applying the nine checkpoint decisions: guarded boundary (arm on merge decision, disarm on Merge record or non-merge answer), checkpoint:plan after a merge with no PR, closed issue ends the run before the PR probe, hand-merge limitation, shared placeholder predicate, plain import, handoff and 461-based tests. The owner's question is the last section.

## Plan Review
**Status**: complete
**When**: 2026-11-13 09:29 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #459 — dispatch_phase: an issue delivered in several pull requests is routed wrongly after the first merge (round count carries over; next answers merge)
**Plan**: `.agent/work-plans/issue-459/plan.md` at `7afb7867`
**Branch**: `feature/issue-459`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Five commits, 161 lines with the owner's section; decision 6 applied. |
| Issue alignment | Needs work | Serves: "Keep work moving without the owner (the review loop driven by `/run-issue`) — `docs/design.md#review-loop-and-timeline`" (checked). Rule 2 is unreachable on a real multi-PR issue: the probe rule of the previous plan was dropped (finding 1). |
| File targeting | Good | Unchanged and right. |
| Consequences | Needs work | The probe change, the issue-state failure path and the package issue's repository are not stated (findings 1, 3). |
| Principle alignment | Needs work | "Enforce what matters, as simply as possible": disarming on a Merge record loses real boundaries (finding 2). |
| ADR compliance | Good | 0013 (no new type; relies on `**Branch**` only before a PR), 0014, 0017. |
| ROS conventions | N/A | Workspace plan. |

### The nine checkpoint decisions in plan.md

1. Closed issue ends the run before the probe; what closes it in each case; the loop never closes an issue: applied (Approach 5, owner's Rule 2). But see finding 1: the probe rule that made "no pull request" possible was cut.
2. Hand-merge limitation, remedy (`merge` checkpoint, `Decided-by: owner`, or `restart`), test: applied (Approach 1 tests, 5).
3. Disarm on a Merge record or a non-`merge` answer at `merge`/`findings`/`merge-refused`, not on PR-correlated entries: applied as decided. The Merge-record half is wrong (finding 2); it was my previous review's suggestion.
4. `checkpoint:plan` after a merge with no PR: applied (Approach 2); routes exist at `dispatch_phase.sh:1092-1096`. Keyed on "newest entry is a merge-decision checkpoint", which misses a newest Merge record (finding 2).
5. One placeholder predicate in `pr_start.py`, used by `findings` and `sources`: applied (Approach 3).
6. Cut to size, alternatives and owner block in the owner's question: applied.
7. Plain `from pr_start import pr_start`, script directory through the environment: applied (Approach 1).
8. Handoff test, no "no cross-model reviewers" on part 2's first pre-push review: applied.
9. Fixture from 461's head: applied ("429 at 461's head (four pull requests)").

Not regressed: one shared rule replacing `restart_start()` (`dispatch_phase.sh:974-984`) and the `cmd_round` loop (`review_progress.sh:151-161`); PR-correlated entries never disarm; refused-merge and restart-plus-merge tests; 332 fixture. Regressed: the probe rule (finding 1).

### Replay (throwaway Python, the rule as written vs. without the Merge-record disarm)

- 429 on main: boundaries 25, 50, end armed (entry 70). 332: 67, 81. 451 (single PR): none, ends armed. Same under both variants. Correct.
- `merge`/`stop` → `--resume` → `merge` → Plan Authored: the stop is a non-`merge` answer at `merge` (disarms, or never armed), the re-asked `merge` arms, boundary at the Plan Authored. Arm → entry-less failure → `stop` → resume → `merge` → Plan Authored: the same. Correct.
- Arm → `## Merge (report-only)` → merge lands → Plan Authored: as written, disarmed, no boundary (start 0); without the Merge-record disarm, boundary at the Plan Authored. 307's real shape (arm, record, `merge-refused`/`merge`) followed by a part: as written no boundary. Wrong as written (finding 2).
- Arm → record → refused → `merge-refused`/`retriage` → re-review → `merge` → Plan Authored: boundary at the Plan Authored under both. Arm → record → `merge-refused`/`address` → Branch fix: no boundary under both. Correct.
- Plan refresh on the old branch before the merge: boundary at that Plan Authored (start of the next part's work; correct). If that merge is then refused and fixed in PR mode, the re-armed `merge` puts a second boundary at part 2's first Branch Implementation; harmless (plan entries count no rounds).
- Arm → Branch-correlated Implementation with no checkpoint between: a boundary under both variants (finding 5).

### Findings

1. **[Issue alignment]** must-fix (regression): the previous plan's probe rule ("a MERGED pull request counts only when its `headRefOid` equals HEAD") is gone and nothing replaces it. Run-issue step 2 (`SKILL.md:300-312`) lists `--head <branch> --state all`; the recreated `feature/issue-<N>` has the same name, so it finds the earlier parts. Verified live: `gh pr list --head feature/issue-429 --state all` returns 461 OPEN and 460, 456, 445 MERGED; between 460's merge and 461's publish it returned only MERGED rows. Sequence: part 1 merged → worktree and branch recreated → issue open → probe MERGED → `--pr merged` → row 1 (`dispatch_phase.sh:896-901`) → `done`; the new `checkpoint:plan` row never fires. Fix: with the issue open (checked first), the probe takes an OPEN or draft pull request if any and otherwise answers `none`; a MERGED one is an earlier part. If the old worktree survived (local HEAD equals a MERGED pull request's `headRefOid`), stop and recreate from the base; never implement on it. Row 1 is then reached only by an explicit `--pr merged`; say so in the design and the owner's question.
2. **[Principle alignment]** must-fix: a `## Merge (...)` record must not disarm. `merge_pr.sh` writes it at the gate, before the merge (`merge_pr.sh:991-1014`), into the PR worktree's timeline (`:870-894`; a package PR takes the comment path instead), "whether or not the merge itself then succeeds" (`run-issue/SKILL.md:599-601`). Sequence: `merge` → `## Merge (report-only)` → merge lands → next part's Plan Authored: no boundary, rounds carry over (the bug). And Rule 2 misroutes: after that merge the newest entry is the record, so `next --pr none` hits row 23 (`dispatch_phase.sh:1164-1166`), `checkpoint:merge-refused`, whose answers dispatch `triage-reviews`/`address-findings` on a merged PR. It affects single-repository project PRs with any gate gap (the gate falls through to report-only, `:998-1013`) and workspace merges the owner allowed with `--report-only`/`--force-unreviewed`; not package PRs. Fix: a Merge record neither arms nor disarms (a refusal after it is disarmed by the `merge-refused` answer the loop records, `SKILL.md:881-886`), and Rule 2 keys on "armed at the end of the timeline and `--pr none`", which covers a newest record. Replayed: 429 and 332 unchanged; the report-only-landed and 307 shapes get their boundary; refused-retriage unchanged. This reverses half of my previous finding 3.
3. **[Consequences]** should-fix: the issue-state check is unspecified. A `gh` failure or offline must stop the run with the error, as `where` does (`SKILL.md:268-271`); never read it as open or closed. For `owner/repo#N`, ask that repository (`gh issue view <N> -R owner/repo`), not the workspace.
4. **[Issue alignment]** should-fix: `proceed` at the post-merge `checkpoint:plan` implements the plan as last reviewed, with no fresh review. That is sound only when `plan.md` is unchanged since its newest Plan Review (`review_progress.sh plan-sha` against that entry's `**Plan**`) and the plan names a part not yet delivered. The checkpoint (owner or `/orchestrator` host) shows: the pull request just merged, that the issue is still open (and why it can be: a non-default base, a `Part of` body by mistake; then the answer is `stop` and close), the plan's parts with those delivered, and the newest Plan Review's verdict and SHA against the current one. If the plan changed since, `proceed` is not offered; answer `revise`.
5. **[Test what breaks]** suggestion: "a merge-from-main `Implementation` while armed (no false boundary)" contradicts the rule. A Branch-correlated, Addressed-less Implementation right after an armed `merge` is a boundary, indistinguishable from part 2's first implement. Write the test as arm → entry-less refusal → `merge`/`address` checkpoint → Branch Implementation → no boundary, and state the other order as a boundary (ADR-0013: a fix while the PR is open carries `**PR**`).
6. **[Owner's question]** should-fix: "If it is open and no pull request exists" hides finding 1: merged pull requests on the branch stop ending the run, which is the owner's decision to make. Rule 1's text says nothing on Merge records (finding 2). "Old timelines read the same" is false: multi-PR timelines count fewer rounds, which is the point. Say "no entry format changes". Missing: the stop on a failed issue-state check, and what `proceed` after a merge relies on (finding 4). The other sentences match the steps.

### Summary

All nine decisions are in the plan, and the boundary is still right on 429, 332 and single-PR timelines. Two must-fix defects remain before the rules go to the owner. Rule 2 cannot fire because the probe still finds the earlier parts' merged pull requests. Rule 1 drops the boundary, and Rule 2 misroutes to `merge-refused`, whenever a `## Merge (...)` record precedes a landed merge. With findings 1 and 2 applied and the owner's section corrected (6), both rules are sound to put to the owner.

### Recommended Actions

- [ ] State the probe rule for an open issue (MERGED is an earlier part; open/draft or `none`) and the surviving-old-worktree stop (finding 1).
- [ ] Drop the Merge-record disarm; key Rule 2 on "armed at the end and `--pr none`"; test the report-only-landed shape (finding 2).
- [ ] Issue-state check: stop on failure; `-R owner/repo` for a package issue (finding 3).
- [ ] Post-merge `checkpoint:plan`: what it shows, and no `proceed` on a plan changed since its review (finding 4).
- [ ] Fix the merge-from-main test description (finding 5).
- [ ] Correct the owner's section (finding 6).

## Checkpoint
**Status**: complete
**When**: 2026-11-13 09:30 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second plan review verdict needs-work, two must-fix in the routing; second host revise in a row, so the next answer at this checkpoint is the owner's, which is also where the design question goes)
**After**: plan
**Decision**: revise

Revise for all six findings. (1) On an open issue a merged pull request counts as an earlier part: run-issue's probe takes an open or draft pull request if there is one, otherwise none; if the old worktree survived the merge (local HEAD equals a merged pull request's head), stop and say so instead of routing. (2) A Merge record neither arms nor disarms the boundary (it is written at the gate before the merge, whether or not the merge lands); the disarm stays for a later merge, findings or merge-refused checkpoint with a non-merge answer; the post-merge route keys on "armed at the end of the timeline and no pull request", so a Merge record as the newest entry after a landed merge does not raise merge-refused. (3) The issue-state check stops the run when gh fails or is offline, never reading that as open or closed; a package issue asks its own repository. (4) At the post-merge plan checkpoint, proceed is offered only when plan.md is unchanged since its newest Plan Review and the plan names a part not yet delivered; the dialog shows the pull request just merged, that the issue is still open and why it can be, which parts are delivered, and the reviewed plan's commit against the current one. (5) Correct the merge-from-main test so it has an address checkpoint between the refused merge and the Implementation. (6) Correct the owner's section: say plainly that a merged pull request on an open issue is treated as an earlier part; say what a Merge record does; drop "old timelines read the same" (multi-pull-request timelines count fewer rounds, which is the point); mention the stop when the issue state cannot be read and what proceed relies on.
