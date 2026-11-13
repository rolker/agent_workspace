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

## Plan Authored
**Status**: complete
**When**: 2026-11-13 10:05 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-459/plan.md` at `58b39d0d`

Second revision applying the six decisions: a merged pull request on an open issue is an earlier part (probe takes an open or draft PR, else none; stop if the old worktree survived); a Merge record neither arms nor disarms and the post-merge route keys on the armed state with no PR (row 23 unchanged for an open PR); issue-state check stops on gh failure and asks the package repository; proceed offered only for an unchanged reviewed plan; corrected merge-from-main test; replay table in the Tests section; owner section corrected.

## Plan Review
**Status**: complete
**When**: 2026-11-13 09:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #459 — dispatch_phase: an issue delivered in several pull requests is routed wrongly after the first merge (round count carries over; next answers merge)
**Plan**: `.agent/work-plans/issue-459/plan.md` at `58b39d0d`
**Branch**: `feature/issue-459`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: five commits, 3 and 4 separable. |
| Issue alignment | Needs work | Serves: "Keep work moving without the owner (the review loop driven by `/run-issue`) — `docs/design.md#review-loop-and-timeline`" (checked). Rule 1 is right on every real and synthetic timeline. Rule 2's row has no guard on the newest entry and shadows rows 7/8 and 26/27 (finding 1). |
| File targeting | Good | Unchanged. |
| Consequences | Good | Issue-state failure path, `-R owner/repo`, row 1 reachable only by an explicit `--pr merged`, all stated. |
| Principle alignment | Good | One shared rule; tests for each shape. |
| ADR compliance | Good | 0013 (no new type; relies on `**Branch**` only before a PR), 0014, 0017. |
| ROS conventions | N/A | Workspace plan. |

### The six checkpoint decisions in plan.md

1. Merged pull request on an open issue is an earlier part; probe takes open/draft else `none`; stop when the old worktree survived: applied (Approach 5, third bullet). Consistent with run-issue step 2 (`SKILL.md:300-312`, `--head <branch> --state all`), which is the text being changed; row 1 (`dispatch_phase.sh:896-901`) is left for an explicit `--pr merged` (Approach 5 lead-in).
2. Merge record neither arms nor disarms; Rule 2 keys on armed state and `--pr none`; row 23 unchanged for an open PR: applied (Approach 1, 2). Matches `merge_pr.sh:997`/`:1013` (record written at the gate, before `gh pr merge`) and row 23 at `dispatch_phase.sh:1164-1166`. The row's placement is the problem (finding 1).
3. Issue-state check stops on a `gh` failure; package issue asks `-R owner/repo`: applied (Approach 5, first bullet; owner's Rule 2).
4. `proceed` only for an unchanged reviewed plan naming an undelivered part; the dialog's contents: applied (Approach 5, fourth bullet; owner's Rule 2).
5. Merge-from-main test with an `address` checkpoint between: applied (Tests row 8), and the other order stated as a boundary (row 9).
6. Owner's section: merged PR as an earlier part, what a Merge record does, "fewer rounds, which is the point", the stop on an unreadable state, what `proceed` relies on: all present.

Not regressed: one rule replacing `restart_start()` (`dispatch_phase.sh:974-984`) and the `cmd_round` loop (`review_progress.sh:151-161`); PR-correlated entries never disarm; `skill_for()` and `round_count()` both read from it; placeholder predicate shared by `findings` and `sources`; the 461 merge notes.

### Rule 1 replay (throwaway Python over `progress_read.py` output, timelines from `origin/main` at `03d0bbfa`)

- 429: boundaries 25, 50; armed at end. 332: 67, 81; armed. 307, 354, 451: none; armed. All match the Tests table.
- Every synthetic row of the Tests table gives the table's result (rows 4-12).
- The 307 shape followed by a next part (arm, `## Merge (report-only)`, `merge-refused`/`merge` checkpoint, Plan Authored) is **not** a row of the table; the author's "was wrong" row (row 5) is the report-only-landed shape, the other one. Replayed: boundary at the Plan Authored, not armed at the end. Correct under the final rule (a `merge` answer at `merge-refused` neither arms nor disarms; the earlier arm stands). Add it as a test row.
- Post-merge `checkpoint:plan` answered `revise`, `proceed` or `stop`: still armed (After `plan` disarms nothing) until the Plan Authored / Branch Implementation, which is the boundary. A start entry must count whatever its **Status**: if a failed part-2 Implementation were not the boundary, `skill_for()` would find part 1's complete Implementations and name `address-findings` for its retry (the issue 321 shape). The plan's wording has no status filter; keep it so and test it.

### Rule 2 walk (assuming the row is guarded as in finding 1)

| State | Row that answers |
|---|---|
| Armed, newest the `merge` checkpoint, `--pr none` | new row: `checkpoint:plan` (today row 21 would re-dispatch `merge`) |
| Armed, newest a Merge record, `--pr none` (landed) | new row: `checkpoint:plan` |
| Armed, newest a Merge record, `--pr open` (refused) | row 23: `checkpoint:merge-refused` |
| Not armed, newest a Merge record, `--pr none` | row 23 (unchanged) |
| Armed, `--pr merged` given | row 1: `done` (before any read) |
| `stop` newest after a merge checkpoint | row 2: `done` (After `merge` stop disarms; After `plan` stop stays armed but row 2 precedes) |
| Armed, then next part's Plan Authored newest | disarmed by the boundary; row 9: `review-plan` |

### Findings

1. **[Issue alignment]** must-fix: the new row's predicate ("armed at the end of the timeline and `--pr none`") does not name the newest entry, and the timeline stays armed from the merge through the post-merge checkpoint until the first start entry. As a guard checked ahead of the base-type blocks, it shadows rows 7/8 and 26/27. Sequence: `merge` checkpoint → merge lands → `next --pr none` → `checkpoint:plan` → host records After `plan`/`revise` → `next --pr none`: still armed → `checkpoint:plan` again, forever; same for `proceed`. And: `revise` → plan-task writes no entry (`--check-exit` MISSING, `SKILL.md:400-404`) → phase-failed checkpoint `retry`/`takeover`, `Phase: plan-task` → `next --pr none`: armed → `checkpoint:plan` instead of row 26/27. Fix in Approach 2: the row fires only when, in addition, the newest entry is a Checkpoint with `Decision: merge` (any After, which also covers 307's `merge-refused`/`merge`, otherwise row 28) or a `## Merge (...)` record; it is checked after rows 2-3. Add tests: armed + plan `revise` → `plan-task`; armed + phase-failed `retry` → the phase.
2. **[Test what breaks]** suggestion: add the 307-shape-plus-part row and a failed-start-entry row (armed, plan `proceed`, failed Branch Implementation → boundary; retry names `implement`) to the Tests table.

### Host-side prose (issue-state check, merged-PR probe, surviving-worktree stop)

Acceptable as prose for this pull request: step 2's probe is prose today, and the rows that act on its answer are tested. But the previous round's must-fix was in exactly this prose, and nothing would catch a regression there. The smallest owner: a `dispatch_phase.sh probe --issue <ref>` subcommand that runs `gh issue view` and `gh pr list --head <branch> --state all` and prints `action=done` (closed), `action=stop reason=...` (gh failure, old worktree survived, closed-not-merged) or `pr=none|<M>`, tested with a stub `gh` on `PATH`. A follow-up, not a blocker.

### Owner's question

Every sentence matches the plan's steps. Rule 1 and Rule 2 can go to the owner as written; finding 1 is mechanism inside Approach 2 and changes nothing the owner reads. One small omission: the stop when the old worktree survived the merge is not mentioned; one clause would do.

### Summary

The six decisions are applied and consistent with the code; Rule 1 replays correctly on 429, 332, 307, 354, 451 and every Tests row. One must-fix remains: the post-merge row needs a guard on the newest entry (a `merge` answer or a Merge record), or it loops on the plan checkpoint it raises. That is a one-sentence change to Approach 2 plus two tests; the owner's rules can go forward unchanged.

### Recommended Actions

- [ ] Approach 2: the row fires only when armed, `--pr none`, and the newest entry is a `Decision: merge` checkpoint or a Merge record; after rows 2-3; tests for plan `revise` and phase-failed `retry` while armed (finding 1).
- [ ] Tests table: 307 shape plus a part; failed start entry while armed (finding 2).
- [ ] Owner's section: one clause on the surviving-worktree stop.

## Checkpoint
**Status**: complete
**When**: 2026-11-13 09:36 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Adopt, proceed (Recommended)

Put to him as a design question on its own: R1 where a pull request ends (after a merge answer, the next new work starts the next pull request and earlier reviews stop counting; a refused or failed merge does not count; a hand merge with no merge answer leaves no boundary and the host records it); R2 after a merge (the run ends when the issue is closed, stops when the state cannot be read, otherwise raises the plan checkpoint when no pull request is open: revise plans, proceed implements and is offered only when the plan is unchanged since its last review and names a part not yet delivered; the loop never closes an issue); R3 no new entry type; R4 the third review's must-fix, handed to the implementer as specified: the new routing row fires only when the newest entry is a checkpoint with Decision merge (any After) or a Merge record, and is checked after rows 2 and 3, with tests for both looping sequences; also the review's two extra table rows (the issue-307 shape followed by a next part; a failed start entry while armed, which counts whatever its Status) and one clause in the owner's section on the stop when the old worktree survived the merge.

## Implementation
**Status**: complete
**When**: 2026-11-13 10:09 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-459 at `180794da`

### Commits
- `0ad48b9b` pr_start: one boundary rule (`.agent/scripts/pr_start.py`); `restart_start()` and the `cmd_round` loop removed; `round_count()`, `skill_for()` and `review_progress.sh round` read it through a plain `from pr_start import ...` (directory via `PR_START_DIR`)
- `da7a3093` dispatch_phase next row 3a (post-merge `checkpoint:plan`, with the newest-entry guard, after rows 2 and 3); plan text corrected (Approach 2, two Tests rows, the surviving-worktree clause in the owner's section)
- `5a9925b7` findings and check read a post-publish `## Local Review`; one LGTM-placeholder predicate (`is_lgtm_placeholder`) used by findings and sources; address-findings SKILL.md names the new source
- `6c4a5f5a` sources reads the whole timeline and keeps review entries from `pr_start` (stale boxes of a merged part no longer listed)
- `99b7e892` run-issue step 2 (issue state first; merged PR on an open issue is an earlier part; surviving-worktree stop) and new step 13; design.md, review_loop_lifecycle.md, script_reference.md; test_skill_paths pins the prose and runs the issue-state block against a stub gh
- `180794da` loaders set `sys.dont_write_bytecode` (the first full pre-commit run failed test_records_write_gate "the reads changed nothing": `__pycache__/` written beside the scripts)

### Deviations from the plan
- Start entry: an `## Implementation` with no `**Addressed**` that is **not PR-correlated** (plan said "with `**Branch**`"), so a failed first implement that never wrote a correlation line is still the boundary; plan.md updated in `0ad48b9b`, tested.
- Not rebased on pull request 461 (still open): built on main `03d0bbfa`.
- Not done: a one-line note in `/orchestrator`'s checkpoint table that a host `proceed` after a merge needs step 13's conditions (the edit was refused by the permission classifier as an instruction-file change outside the plan); run-issue step 13 states the condition.

### Decision table walk (row 3a in; every existing fixture in test_dispatch_phase.sh unchanged, 148 of them pass as before)
| State | --pr | Answer (row) |
|---|---|---|
| 1 armed, newest the merge answer | none | checkpoint:plan (3a; was merge) |
| 2 armed, newest a Merge record (landed) | none | checkpoint:plan (3a; was merge-refused) |
| 3 armed, newest a Merge record | open | checkpoint:merge-refused (23) |
| 4 not armed (merge-refused/address), newest a Merge record | none | checkpoint:merge-refused (23) |
| 5 armed | merged | done (1) |
| 6 stop at merge, or stop at the post-merge plan checkpoint | none | done (2) |
| 7 armed, then Plan Authored newest | none | review-plan (8) |
| armed, newest the merge answer | open / draft | merge (21) |
| issue-307 shape (merge, record, merge-refused/merge) | none / open | checkpoint:plan (3a) / checkpoint:unexpected (28) |
| merge-refused/merge with no earlier arm | none | checkpoint:unexpected (28) |
| armed, newest a PR-correlated fix | none | review-code (12) |
| armed, newest failed Plan Authored | none | checkpoint:phase-failed phase=plan-task (3) |
| armed, plan revise / proceed | none | plan-task (11) / implement (10) |
| armed, revise, phase-failed retry / takeover plan-task | none | plan-task (26) / plan-task mode=inline (27) |
| armed, proceed, failed first implement; its retry | none | phase-failed phase=implement (3); implement (26) |
Both looping sequences fail on an unguarded row 3a (checked: 9 failures) and on the code without row 3a (9 failures); the commit-1 tests fail on main's scripts (8 in test_dispatch_phase, 2 in test_review_code_convergence); commit-3/4 tests fail on the previous review_progress.sh (4 + 1, then 2).

### Boundary (pr_start) cases tested
All 12 rows of the plan's Tests table plus the issue-307-shape-plus-part, the failed start entry (with and without a correlation line), Merge record newest (armed), restart clearing the arm, After findings arming, plan answers keeping the arm; real timelines: 429 (25P 50P, armed), 332 (67I 81I, armed), 451/455/354/307 (none, armed).

### Acceptance
- Round 1 with outside reviewers for the next diff, no checkpoint:rounds before its own third round: test_dispatch_phase "round_count: part 1 had three reviews ..." (round=1), "part 2 reaches MAX_ROUNDS only on its own third review", handoff "after a merge, the next pull request's first pre-push review is round 1 -- ... no \"no cross-model reviewers\""; test_review_code_convergence round cases.
- next after a merge checkpoint, issue open, no PR, does not answer merge: test_dispatch_phase "acceptance: next after a merge checkpoint with no pull request does not answer merge" and walk 1/2.
- Synthetic-timeline tests in test_dispatch_phase.sh: yes (above).

### Verification
`/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: first run failed (test_records_write_gate 67/1, fixed in `180794da`); second run on the final tree passed every hook, validate-script-tests over all suites. Suites run directly: test_dispatch_phase 211/0, test_review_code_convergence 38/0, test_address_findings 21/0, test_triage_reviews_integration 64/0, test_skill_paths 142/0, test_records_write_gate 68/0, test_design_anchors 47/0.

### Pull request 461
`git merge-tree` of this head with 461's head `7ef2a6a2`: one conflict, docs/design.md change-log rows (both append a row at the table's end). dispatch_phase.sh, run-issue SKILL.md and script_reference.md merge cleanly (this change keeps out of `cmd_handoff`, `base`, step 11 and the script_reference rows 461 edits). After 461 merges, the 429 real-timeline test still holds (it checks the first two boundaries; 461's head adds 71P).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-13 10:36 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-459 at `96fedbc0`
**Base**: main
**Depth**: Deep (reason: ~1000 changed lines outside records; the dispatcher and review-loop enforcement scripts plus run-issue/design governance text)
**Must-fix**: 3 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) A next part whose first `## Implementation` carries `**PR**` (a pre-existing draft PR, probed as `--pr none`, then post-merge plan `proceed`, no Plan Authored) never starts a boundary: synthetic timeline part 1 (3 pre-push reviews, merge answer) + plan/proceed + Implementation `**PR**: #6` + one changes-requested pre-push review gives `next` checkpoint:rounds round=4 and `round` round=5 (so a "no cross-model reviewers" handoff); a failed such Implementation retries as address-findings. Same with `**Branch**`: round=1. Discriminate by PR number (332's entry 64 is PR 409 = the merged PR's own number; a new part's draft has a different one) and test it; codex and the Claude adversarial found it independently — `.agent/scripts/pr_start.py:53`
- [x] (must-fix) run-issue step 2 drops `--pr merged` as a probe answer, but step 11 (`SKILL.md:921-923`) still relies on it to end the run after `action=merge`: after a landed merge on an issue still open (any earlier part, a non-default base, or an auto-close not yet visible) the re-probe gives `--pr none` and `next` runs with the worktree gone: `dispatch_phase.sh next --issue 307 --pr none --type workspace` → `error: next: no workspace worktree found`, rc=2, instead of ending the run. Say in steps 11/13 that a landed merge ends this run (`done`; the next part is a fresh `/run-issue <N>`), and fix the step 11 sentence — `.claude/skills/run-issue/SKILL.md:921`
- [x] (must-fix) Missing consequence: the round rule is still written as "after the newest `**Decision**: restart`" in review-code step 2 (PR-mode hand count) and step 6, and in review_depth_classification.md's round-3 text; a host hand-counting part 2's PR-mode `## Local Review` entries by that text counts part 1's and can call part 2's first PR-mode re-review a round-3 convergence check with no cross-model reviewers — `.claude/skills/review-code/SKILL.md:198`, `:517`; `.agent/knowledge/review_depth_classification.md:171`
- [x] (suggestion) `is_lgtm_placeholder` matches the prefix "No issues found", not the placeholder: an approved review's open box `- [ ] No issues found in x but y breaks` is hidden from `findings` (`"open": []`); match the exact `No issues found. LGTM.` — `.agent/scripts/pr_start.py:97`
- [x] (suggestion) `sources` now also slices at a restart (main did not): a restart recorded while the PR is open drops that PR's earlier review entries (open must-fix boxes included) from triage input, neither listed nor "dropped"; confirm it is wanted and add a test — `.agent/scripts/review_progress.sh` cmd_sources
- [x] (suggestion) Implementer's deviation (an uncorrelated Addressed-less Implementation is a start entry): a failed fix pass written while armed (332 entry 64 shows fixes do get written after a merge answer) that lost both `**Addressed**` and its correlation line becomes the boundary, and `skill_for` retries it as `implement`; low reach (the dispatcher's own rows never dispatch a fix while armed), but count an uncorrelated entry only when it is not `complete`, or state the limit — `.agent/scripts/pr_start.py:49-55`
- [x] (suggestion) `/orchestrator`'s checkpoint table lets the host answer `proceed` at any `plan` checkpoint; run-issue step 13 restricts what is offered after a merge, which covers a host that follows run-issue, but a one-line pointer there removes the ambiguity (owner's call: the edit was refused as an instruction-file change) — `.claude/skills/orchestrator/SKILL.md:76` (deferred: owner's call, not edited: an /orchestrator instruction-file change needs his word; the host will ask (run-issue step 13 states the post-merge proceed condition))
- [x] (suggestion) Plan drift, justified: `test_skill_paths.sh`, `test_triage_reviews_integration.sh` and address-findings SKILL.md changed but are not in Files to Change; record it in the PR body — `.agent/work-plans/issue-459/plan.md:115`

## Implementation
**Status**: complete
**When**: 2026-11-13 10:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-459 at `094c99c8`
**Addressed**: Local Review (Pre-Push) at `96fedbc0` (2026-11-13 10:36 -05:00)
**Commits**: `8da9592c` `440c179d` `2ca15937` `b306742a` `ab420cef` `94e94284` `094c99c8`

### Actions
- [x] (must-fix 1) Start entries told apart by pull-request number. At each arming `merge` answer the merged number is taken as the newest PR-correlated entry's before it; while armed an Addressed-less `**PR**` Implementation is a start only when its number differs. Unknown number → not a start (safe side: a missed boundary over-counts rounds and the rounds checkpoint asks the owner early; a false one would reset the count and silently drop open boxes from `sources`). Tests: review's timeline (handoff bare round 1; `next` address-findings round=1, was checkpoint:rounds round=4; `round` round=2, was 5), 332 entry-64 shape, unknown number, failed #6 Implementation, number re-taken at a second merge — `.agent/scripts/pr_start.py` (`8da9592c`)
- [x] (must-fix 2) run-issue step 11: a landed merge ends the run, the host does not call `next` again; step 2 says so; step 13: the next part is a fresh `/run-issue <N>` (issue-state check, probe, `checkpoint:plan`). `next --pr none` with no worktree now also says "this run is over ... run /run-issue <N> to start the next part, or nothing if the issue is closed" (small, contained; tested, and `--pr open` keeps the plain error); prose pinned in test_skill_paths — `.claude/skills/run-issue/SKILL.md`, `.agent/scripts/dispatch_phase.sh` (`2ca15937`, `b306742a`)
- [x] (must-fix 3) Round rule restated as the current pull request's start (newer of a restart and the boundary) in review-code step 2 (PR-mode hand count) and step 6, and review_depth_classification.md; grep of skills, knowledge and design for the old wording finds no other instance (orchestrator's "the restart also starts the rounds over" stays true) — `.claude/skills/review-code/SKILL.md:198,517`, `.agent/knowledge/review_depth_classification.md:171` (`ab420cef`)
- [x] (suggestion) LGTM placeholder: exact `No issues found. LGTM.` with any annotation after it (7 approved reviews on main annotate it, so a strict equality would list them); `No issues found in x but y breaks` and a misspelt placeholder stay open; test fails on the prefix code — `.agent/scripts/pr_start.py` (`440c179d`)
- [x] (suggestion) `sources` and a restart, per host decision: `scan()` returns `Scan(round_start, pr_start, armed)`; `next` and `round` read `round_start`, `sources` reads `pr_start` (a restart does not move it). Tests: restart while the PR is open keeps the earlier review's open box; restart inside part 2 keeps part 2's reviews and still cuts part 1's; both fail on the previous code — `review_progress.sh` cmd_sources (`8da9592c`)
- [x] (suggestion) Deviation tightened: an Implementation with no correlation line is a start only when not `complete`; the lost-`**Addressed**` complete fix pass is no boundary (test) — `.agent/scripts/pr_start.py` (`8da9592c`)
- [x] (suggestion) `/orchestrator` checkpoint table — `.claude/skills/orchestrator/SKILL.md:76` (deferred: owner's call, not edited per host decision; the host will ask)
- [x] (suggestion) Plan drift: the three files plus this round's review-code SKILL.md and depth doc added to Files to Change; Approach 1 states the rule as built — `.agent/work-plans/issue-459/plan.md` (`94e94284`, `094c99c8`)

### Start-entry rule (while armed; anything else never disarms)
| Entry | Merged number | Start? |
|---|---|---|
| Plan Authored, any Status | any | yes |
| Implementation with **Addressed** | any | no |
| Implementation, **Branch**, any Status | any | yes |
| Implementation, **PR** #X, X ≠ merged | known | yes (any Status) |
| Implementation, **PR** #X, X = merged | known | no (fix to the merged PR) |
| Implementation, **PR**, or PR line without a number | unknown | no (safe side) |
| Implementation, no correlation, failed/partial/no Status | any | yes |
| Implementation, no correlation, complete | any | no |
| Checkpoint restart | - | round start only; clears the arm |
New tests that fail on the code before this pass: 7 in test_dispatch_phase (checked by restoring the old start predicate), 2 in test_triage_reviews_integration and 1 in test_address_findings (checked against the previous pr_start.py), 1 in test_skill_paths (text absent before).

### Replay on main's real timelines (round-start / pull-request-start moves; `next` vs `review_progress.sh round` on every complete pre-push review)
- 429: 25, 50 / 25, 50; armed; 9 of 9 agree
- 332: 67, 81 / 67, 81; armed; 20 of 20 agree
- 307, 354, 451, 455: none; armed; 3, 2, 1, 3 agree, none disagree

### Verification
The full `pre-commit run --files $(git diff --name-only main...HEAD)` pass was SKIPPED on the owner's direction ("have agent skip pre-commit and let ci handle it"); a run already started was stopped before its script suite finished. CI's lint job is the check for the remaining suites. Every commit ran the fast hooks (identity, branch, shellcheck, black, flake8, pylint) with `SKIP=validate-script-tests`. Suites run directly on the final tree: test_dispatch_phase 227/0, test_review_code_convergence 38/0, test_address_findings 22/0, test_triage_reviews_integration 66/0, test_skill_paths 143/0, test_records_write_gate 68/0, test_design_anchors 47/0. No `__pycache__` left; one `identity_base` cache written by a commit hook was removed (not from this change).

### Not done
`/orchestrator` pointer (owner's call). Not rebased on 461 (still open); this pass kept out of the design.md change-log rows.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-13 10:55 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a871696c56568ab82, resume 1 of 3)

**Branch**: feature/issue-459 at `7d11a8d9`
**Base**: main
**Depth**: Deep (reason: whole-diff classification, fix round 2; ~1000 changed lines in the dispatcher and review-loop scripts plus run-issue/design governance text; cross-model included at round 2)
**Must-fix**: 3 | **Suggestions**: 3
**Round**: 2 | **Ship**: continue — round 2: 3 must-fix is high; another independent read warranted

Round-1 findings verified fixed: draft-PR start by number (the round-1 timeline now gives `next` address-findings round=1, `round` round=2; failed variant retries as `implement`); run-issue steps 2/11/13 agree with each other and with `next` (`--pr none` with no worktree prints the run-is-over line, rc=2; `--pr open`/`draft` keep the plain error); round wording updated in review-code SKILL.md, review_depth_classification.md, design.md; exact LGTM marker; `sources` keeps a restart's earlier reviews of an open PR; uncorrelated complete Implementation no start; plan drift recorded. Replays: 429 25/50, 332 67/81, 307/354/451/455 none (both starts); `next` = `round` on all 38 real pre-push reviews; 1,084-combination comparison with main: the same 57 intended differences as round 1; every main fixture line of test_dispatch_phase.sh still present.

### Findings
- [x] (must-fix) Owner-directed (2026-11-13, his words: "yes, add it in 459's pull request"): add to `/orchestrator`'s checkpoint table (the `plan` row, or a sentence directly under the table) that at the plan checkpoint raised after a merge the host answers `proceed` only under run-issue step 13's conditions (plan unchanged since its last review, and naming a part not yet delivered), otherwise `revise`; a skill-file edit he has now approved — `.claude/skills/orchestrator/SKILL.md:76`
- [x] (must-fix) `last_pr` is not cleared at a boundary, so a part whose own PR-correlated entries before its merge answer do not parse takes the earlier merged PR's number: PA, Impl(Branch), IR `#10 at sha`, merge answer, PA (boundary 4), Impl(Branch), LRP, publish, IR `**PR**: #11 — 1 review(s), 1 valid, 0 false positives` (parses to no correlation; 34 such lines on main), merge answer, Implementation `**PR**: #11` with no Addressed (a post-merge fix, the 332 entry-64 shape) → `Scan(10, 10)`, a false boundary at the fix (expected pr_start 4): `sources` silently drops PR #11's reviews. Set `last_pr = None` where a boundary is drawn (unknown → not a start) and test it — `.agent/scripts/pr_start.py:146-151`
- [x] (must-fix) A restart never moves `pr_start`, yet run-issue step 13 offers "a `restart` when he restates the goal" as the hand-merge remedy: PA, Impl(Branch), LR/IR #10 with open boxes, restart, PA, Impl(Branch) → `Scan(round_start=7, pr_start=0)`; the same after a real merge answer followed by a restart before the next plan (`merge`, `restart`, PA, Impl, LRP → `Scan(12, 0)`): the next part's `sources` lists PR #10's/part 1's reviews (3 pre-push + the Integrated Review) as dropped entries again, the noise item 4 of the issue removes. Either keep the arm through a restart (a restart while armed leaves the next start entry to move both starts) and drop "or a `restart`" from the hand-merge remedy, or say what a restart does to `sources` there — `.claude/skills/run-issue/SKILL.md:1007-1011`, `.agent/scripts/pr_start.py:138-140`
- [x] (suggestion) The LGTM marker with "any annotation" hides `- [ ] No issues found. LGTM. except the race in x` on an approved review (`findings` open: []). Main's 7 annotated placeholders are verification notes (`Gate suite 54/54 ...`, `test_dispatch_phase 76/76 ...`, `(Four owner-approved AGENTS.md edits ...)`), one carrying held items ("suggestion 6 and the cube_bathymetry example stay with the owner"); also requiring the entry's `**Must-fix**: 0 | **Suggestions**: 0` catches a finding typed after the marker with a non-zero count — `.agent/scripts/pr_start.py:83`
- [x] (suggestion) The docs say rounds count "from the current pull request's start" while the code has a separate `pr_start` a restart does not move; the texts mean `round_start` (they define it in the next sentence, but the phrase invites a host to use `pr_start`): say "the round start" — `.claude/skills/review-code/SKILL.md:198`, `.agent/knowledge/review_depth_classification.md:171`, `.agent/scripts/review_progress.sh:161`
- [x] (suggestion) `__pycache__`: no command of this change leaves one (none present after the eight suites). The `identity_base.cpython-314.pyc` comes from the commit-identity hook (`.agent/hooks/check-commit-identity.py:28-29` imports `identity_base` without `sys.dont_write_bytecode`; issue 455, `f5a19d85`..`f61c1834`); it is gitignored (`.gitignore:57`), a stray only in the sense that every commit rewrites it. Out of scope here; a one-line follow-up for 455's hook — `.agent/hooks/check-commit-identity.py:29`

## Implementation
**Status**: partial
**When**: 2026-11-13 11:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent ad7bb2b25f9d3f046, resume 1 of 3)

**Branch**: feature/issue-459 at `7d31e57a`
**Addressed**: Local Review (Pre-Push) at `7d11a8d9` (2026-11-13 10:55 -05:00)
**Commits**: `4971bb6c` `6f1cd32d` `d9390180` `6efbf2c6` `7d31e57a`

Partial for one reason only: the owner-directed `/orchestrator` line (must-fix 1) was refused by the permission system (auto-mode classifier, "Undermining Oversight") on the single Edit to `.claude/skills/orchestrator/SKILL.md`. Per the handoff it was not worked around; its box stays open for the host to take to the owner. Everything else is done.

### Actions
- [ ] (must-fix 1, owner-directed) `/orchestrator` table `plan` row: post-merge `proceed` only under run-issue step 13's conditions, otherwise `revise` — NOT DONE: the edit was refused by the permission system; the intended cell text: "`proceed`, `revise`; at the plan checkpoint raised after a merge, `proceed` only under run-issue step 13's conditions (the plan unchanged since its last review, and naming a part not yet delivered), otherwise `revise`" — `.claude/skills/orchestrator/SKILL.md:76`
- [x] (must-fix 2) `last_pr` cleared where a boundary is drawn; an entry with no parsed correlation whose `**PR**` field opens with `#N` (the legacy `**PR**: #11 — 1 review(s), ...` shape: on main all such lines are External Reviews, plus one Implementation `#266 (round-2 fixes)` on issue 265; Checkpoints are never read for numbers) is read as #N in `pr_start.py` only; `progress_read.py` unchanged. Tests: the review's timeline with an unreadable part-2 Integrated Review gives pull-request start 4 (was 10); a legacy `#11` line gives the merged number (fix on #11 no start, #12 is) — `.agent/scripts/pr_start.py` (`4971bb6c`)
- [x] (must-fix 3) A restart moves only the round start and no longer ends the armed state; run-issue step 13 drops "or a `restart`" from the hand-merge remedy and says what a restart does (rounds over, no boundary, keeps an open PR's earlier reviews, leaves a standing merge answer armed); design, lifecycle, script reference and plan.md Approach/owner text follow. Tests: merge answer, restart, Plan Authored → `Scan(6, 6)` (both at the Plan Authored; the review's `Scan(12, 0)` shape now gives the plan's index for both); hand merge, restart, Plan Authored → `Scan(5, 0)` (the review's `Scan(7, 0)` shape: unchanged by design, the remedy is a merge checkpoint); the same with a merge checkpoint → `Scan(6, 6)`; `merge, restart` → `2 yes` (was `2 no`); restart inside an open PR unchanged (`3 0`); `sources` for merge answer, restart, plan lists only part 2 — `.agent/scripts/pr_start.py`, `.claude/skills/run-issue/SKILL.md` (`4971bb6c`, `d9390180`)
- [x] (suggestion) LGTM placeholder dropped only when approved AND the entry's summary line counts `0 | **Suggestions**: 0` (absent line: listed) AND the box opens with the marker. Tests: "except the race in x" with a suggestion counted stays listed; no summary line stays listed; `sources` the same — `.agent/scripts/pr_start.py` (`6f1cd32d`)
- [x] (suggestion) "the round start", defined once (the newer of a restart and the pull request's start) — `.claude/skills/review-code/SKILL.md:198,517`, `.agent/knowledge/review_depth_classification.md:171`, `.agent/scripts/review_progress.sh:161`, review_loop_lifecycle.md (`6efbf2c6`, `d9390180`)
- [x] (suggestion) `check-commit-identity.py` sets `sys.dont_write_bytecode`; test_commit_identity runs a copy of the hook in its sandbox and checks no `__pycache__` (fails on the old hook) — `.agent/hooks/check-commit-identity.py:28` (`7d31e57a`, own commit, follow-up to 455)

### The 7 real annotated placeholders on main (plus the 2 on Integrated Reviews)
- 276 Local Review "test_dispatch_phase 76/76 ...": approved, 0/0 → placeholder (dropped)
- 276 Local Review "All five round-1 items resolved ...": approved, 0/0 → dropped
- 284 Local Review "Verified locally with HOME ...": approved, 0/0 → dropped
- 286 Local Review "Gate suite 54/54 ...": approved, 0/0 → dropped
- 335 Local Review (Pre-Push) "(Round-2 must-fix and suggestions 1-5 verified resolved; suggestion 6 and the cube_bathymetry example stay with the owner ...)": approved, its entry counts `0 | **Suggestions**: 0` → dropped. It is the one carrying held items; it is not listed because its own count is zero (the held items are not counted as findings of that entry). It would be listed had the entry counted a suggestion.
- 335 Local Review "(Copilot's two PR findings are resolved ...)": approved, 0/0 → dropped
- 425 Local Review (Pre-Push) "The round 1 suggestion is closed by 58e8f94e ...": approved, 0/0, already checked → dropped
- 335 and 354 Integrated Reviews carrying the marker: no verdict → listed (unchanged).

### Start-entry rule (while armed; a restart moves only the round start and keeps the arm)
| Entry | Merged number | Start? |
|---|---|---|
| Plan Authored, any Status | any | yes |
| Implementation with **Addressed** | any | no |
| Implementation, **Branch**, any Status | any | yes |
| Implementation, **PR** #X (correlation, or legacy `#X — ...` field), X ≠ merged | known | yes |
| the same, X = merged | known | no |
| the same | unknown (no number since the previous boundary) | no |
| Implementation, no correlation and no `#N` field, not complete | any | yes |
| Implementation, no correlation, complete | any | no |
| Checkpoint restart | - | round start only |

### Replay on main (round start / pull-request start; `next` = `round` on every complete pre-push review)
429: 25, 50 / 25, 50 (9 of 9 agree); 332: 67, 81 / 67, 81 (20 of 20); 307, 354, 451, 455: none / none (3, 2, 1, 3 agree); all armed at the end.

### Verification
The full `pre-commit run --files ...` pass was SKIPPED on the owner's direction ("have agent skip pre-commit and let ci handle it"); CI's lint job is the check for the remaining suites. Each commit ran the fast hooks with `SKIP=validate-script-tests`. Suites run directly on the final tree: test_dispatch_phase 233/0, test_review_code_convergence 38/0, test_address_findings 24/0, test_triage_reviews_integration 69/0, test_skill_paths 143/0, test_records_write_gate 68/0, test_commit_identity 94/0, test_design_anchors 47/0. New behaviour tests fail on the code before this pass (6 in test_dispatch_phase, 1 in test_commit_identity checked by restoring the old files). No `__pycache__` left (one written while the hook edit was still unstaged, as pre-commit stashes it, was removed; a hook run on the committed hook writes none).

## Checkpoint
**Status**: complete
**When**: 2026-11-13 11:07 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: phase-failed
**Decision**: takeover
**Phase**: address-findings

You do it (takeover)

Put to him: the fix pass ended partial only because the permission system twice refused the sub-agent's edit of the one line he had approved ("yes, add it in 459's pull request") in .claude/skills/orchestrator/SKILL.md, the plan row of the checkpoint table. The host makes that one edit, commits it, and writes the pass's entry as complete; nothing else in the file changes.

## Implementation
**Status**: complete
**When**: 2026-11-13 11:08 -05:00
**By**: Claude Code Agent (claude-fable-5-2)

**Branch**: feature/issue-459 at `a437af53`
**Addressed**: Local Review (Pre-Push) at `7d11a8d9` (2026-11-13 10:55 -05:00)
**Commits**: `a437af53`

Written by the host on the owner's takeover answer (the phase-failed checkpoint above), finishing the fix pass whose previous entry was partial for one reason only.

- Must-fix 1, owner-directed ("yes, add it in 459's pull request"): `.claude/skills/orchestrator/SKILL.md`, the checkpoint table's `plan` row now reads: `proceed`, `revise`; at the plan checkpoint raised after a merge, `proceed` only under run-issue step 13's conditions (the plan unchanged since its last review, and naming a part not yet delivered), otherwise `revise`. One cell; nothing else in the file changed. The permission system had twice refused a dispatched agent's edit of this file; the owner then answered "You do it (takeover)".
- Everything else in this fix pass is in the previous (partial) entry: must-fix 2 and 3 and the three suggestions, commits `4971bb6c` `6f1cd32d` `d9390180` `6efbf2c6` `7d31e57a`.

Checks: `test_skill_paths.sh` 143 passed, 0 failed, run after the edit. The full pre-commit pass was not run, on the owner's direction (2026-11-13: one full run per pull request, by the host, before publishing).

## Implementation

**Status**: complete
**When**: 2026-11-13 11:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-459 at 6ecbcbd0
**Addressed**: Local Review (Pre-Push) at `7d11a8d9` (2026-11-13 10:55 -05:00)

The branch took main: merge commit `6ecbcbd0` merges main at `2809fcef` (pull request 458, issue 446, ADR-0020) into the branch head `8c9e5531`.

- **Conflict**: one, in `docs/design.md`, both sides appending a change-log row. Both rows kept in date order: #446's (2026-11-12) first, then #459's (2026-11-13). #459's Lines value moved from 963 to 981, the merged file's `wc -l`. No prose sentence was changed by both sides (#459's design hunks are lines 589-623 of the base, #446's are elsewhere), so no sentence needed rewriting.
- **Files both sides changed**: `docs/design.md` (above), `.claude/skills/run-issue/SKILL.md` and `.agent/knowledge/script_reference.md`, both auto-merged. Read the merged regions: SKILL.md's prefix/plugin text (main, lines 64-104) and this branch's steps 2, 11 and 13 touch separate regions and read correctly together; script_reference.md's rows (main: `validate_adapter.sh`, `register_project.sh`, `skill_prefix.sh`, `session_root.sh`; this branch: `dispatch_phase.sh`, the new `pr_start.py` row) are separate rows and consistent. No script or test was changed by both sides.
- **Citations**: main did not change `dispatch_phase.sh`, so no `dispatch_phase.sh` citation moved; `check_design_anchors.sh` exits 0.
- **Suites** (run directly): test_dispatch_phase 233/0, test_review_code_convergence 38/0, test_address_findings 24/0, test_triage_reviews_integration 69/0, test_skill_paths 143/0, test_records_write_gate 68/0, test_commit_identity 94/0, test_design_anchors 47/0 (passed/failed). `suites_for_files.sh` maps the three shared files to ALL, the full suite, which was not run.
- **Hooks**: the full pre-commit pass was skipped on the owner's direction (2026-11-13); every commit used `SKIP=validate-script-tests`.
- **Noticed, not touched**: main's #446 change-log row states 928 lines, but main's own `docs/design.md` was 967 lines after pull request 458 (the row's count predates #446's later merge of main and was not refreshed). Left as main has it.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-13 11:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-459 at `68cfc4e3`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings

Scope: round 2's three must-fix and three suggestions, fix commits 4971bb6c 6f1cd32d d9390180 6efbf2c6 7d31e57a, the host's a437af53, and the merge of main at 6ecbcbd0. Cross-model: skipped (round-3 convergence check, per handoff).

Checked: must-fix 2: the review's timeline gives Scan(4, 4) (legacy `**PR**: #11 — 1 review(s), 1 valid` part-2 Integrated Review, fix on #11 no start), a later Plan Authored moves both to 11; a part with no number of its own leaves the merged number unknown (no start); a `**PR**: #10` line inside a Checkpoint is not read (Checkpoints `continue` before the number read); `progress_read.py` unchanged. Must-fix 3: merge, restart, Plan Authored → Scan(6, 6); hand merge, restart, Plan Authored → Scan(5, 0) (documented, remedy a merge checkpoint); restart inside an open PR → Scan(4, 0); run-issue step 13 says a restart is no remedy. LGTM placeholder: 13 inputs through `progress_read.py` (10 or 0|10 kept, `·` separator and absent line kept, non-approved kept, prefixed box kept); dropping issue 335's annotated placeholder is right: its held item (suggestion 6) is an open box on the round-2 entry, which `sources` still lists. "The round start" defined in all four files. Hook: the old hook writes `__pycache__` in a sandbox copy, the new one does not; none in the worktree after the suites. Orchestrator `plan` cell matches run-issue step 13's two conditions. Merge: `git merge-tree` of 8c9e5531 and 2809fcef differs from 6ecbcbd0 only in design.md's change-log conflict, both rows present, 981 = `wc -l`; the three files both sides changed touch separate regions. Replays: 429 25/50, 332 67/81, 307/354/451/455 none, 446 none (one PR; merge answer at entry 22 with nothing after: armed, correct); `next` = `round` on all 41 pre-push reviews of the seven timelines. Main's test_dispatch_phase lines all present (4 differing lines are file-copy lists gaining pr_start.py and a header comment). Suites: test_dispatch_phase 233/0, test_review_code_convergence 38/0, test_address_findings 24/0, test_triage_reviews_integration 69/0, test_skill_paths 143/0, test_records_write_gate 68/0, test_commit_identity 94/0, test_design_anchors 47/0. Full pre-commit not run (host runs it, owner direction 2026-11-13).

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-13 11:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (pre-push review approved at round 3, no findings; the one full suite run before publishing passed)
**After**: publish
**Decision**: publish

Round 3 approved with no must-fix and no suggestions, on the tree that includes main at 2809fcef. The host then ran the full pre-commit pass once, with no SKIP, on head 5a9d7049 (the owner's rule of 2026-11-13: one full run per pull request, by the host, before publishing): every hook passed, "run_script_tests: all 48 suites passed in 564s".

## Integrated Review
**Status**: complete
**When**: 2026-11-13 11:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #467 at `be62d33`
**Sources**: 4 (Local Review (Pre-Push) @ `96fedbc0` round 1, @ `7d11a8d9` round 2, @ `68cfc4e3` round 3 (covers `be62d33` via bookkeeping), CI rollup); GitHub reviews: none (Copilot review disabled for quota: skipped)
**Cross-source confirmations**: 0
**CI**: pending (Lint (pre-commit): pending; Validate Adapter Contract: pending; Validate Documentation: pass; ros-manifest tests (#267 prototype): pass; each in two runs, 43462602591 and 43462596167)

Rounds 1 and 2: all 8 + 6 boxes ticked. Each is fixed in a later Implementation entry with commits (`8da9592c`..`094c99c8`; `4971bb6c` `6f1cd32d` `d9390180` `6efbf2c6` `7d31e57a`), except round-1 suggestion 7 (the `/orchestrator` line), deferred to the owner there and turned into round 2's owner-directed must-fix 1. The partial Implementation entry left that one box open; the timeline then shows the phase-failed Checkpoint (11:07, **Decided-by**: owner, **Decision**: takeover, **Phase**: address-findings) and the host's complete Implementation entry at `a437af53`. `git show a437af53` changes exactly one line of `.claude/skills/orchestrator/SKILL.md`, the `plan` row's answers cell, and `git diff origin/main...HEAD` touches nothing else in that file.

Helper output from this worktree: `review_progress.sh sources --head be62d33` gives `local_findings: []`, `dropped_entries: []`; `findings` gives the round-3 entry with `total_findings: 1`, `open: []`. The approved round-3 "No issues found. LGTM." placeholder (Verdict approved, counts 0 | 0) is not listed: correct.

Re-run here on `be62d33`: test_dispatch_phase 233/0, test_triage_reviews_integration 69/0, test_address_findings 24/0, test_review_code_convergence 38/0, test_skill_paths 143/0, test_commit_identity 94/0 (match the PR body).

PR body, two sentences the timeline does not support (not edited):
- "Gemini and Codex ran on rounds 1 and 2": the timeline names Codex once (round 1) and Gemini nowhere; round 2 says only "cross-model included".
- "Compared with main over 1,084 timeline states ... every difference is one of the intended ones": that comparison is recorded only in the round-2 review at `7d11a8d9`, before `4971bb6c` changed the restart and `last_pr` rules; round 3 re-checked the real-timeline replays and `next` = `round` (41 reviews), not the 1,084-state comparison.

Pull request 461 (`origin/feature/issue-429` at `0c6dc2d3`, already includes main): `git merge-tree` conflicts in `docs/design.md` only (both append change-log rows; also the Lines value). `dispatch_phase.sh`, run-issue and review-code SKILL.md, script_reference.md auto-merge. In the merged `cmd_handoff`, 461's `task=... --branch origin/$pkg_base` override runs first and this branch's round-3 block appends to `$task` after it, reading the per-pull-request `review_progress.sh round`: no semantic collision. No `dispatch_phase.sh:<line>` citations exist in design.md or the knowledge files.

### Findings
- [x] (suggestion, triage) PR body: reword or drop "Gemini and Codex ran on rounds 1 and 2" (unsupported for Gemini and for round 2's reviewers) and qualify the 1,084-state comparison as made at the round-2 head, or re-run it on the final head — PR #467 body

### False positives

## Implementation

**Status**: complete
**When**: 2026-11-13 11:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #467 at 91967144
**Addressed**: Integrated Review at `3f167a6b`

The branch took main: merge commit `91967144` merges main at `8161b57d` (pull request 461, issue 429's last part) into the branch head `b3fc6b97`.

- **Conflict**: one, in `docs/design.md`, both sides appending 2026-11-13 change-log rows. All rows kept: main's nine issue 429 rows (already landed, counts 959 to 1023) first, then #459's row (981, this branch's file at that point), then a new Change log row for this merge whose count, 1038, is the merged file's `wc -l`. No prose sentence was changed by both sides. The `dispatch_phase.sh` line citations main had written (Table 1's row `216, 277-326, 501, 643, 731, 763, 902`; the Target's mechanism 1 `549, 595, 597, 659, 920`) were false for the merged script, which this branch lengthened; refreshed to `222, 283-332, 507, 649, 737, 769, 908` and `555, 601, 603, 665, 940`, each re-derived by grep on the merged file, and the merge row says so. `merge_pr.sh` was changed only by main, so its citations stand. `check_design_anchors.sh` passes.
- **Files both sides changed**, auto-merged, merged regions read:
  - `dispatch_phase.sh` `cmd_handoff`: 461's package base form (`/review-code --branch origin/<base> --issue <N>`) is set first, then this branch's round block appends the round-3 words to whatever `task` holds; the round comes from `review_progress.sh round`, which counts from `pr_start.py`'s round start. They compose.
  - `run-issue/SKILL.md`: step 2 (issue state first, merged PR as an earlier part), step 8 (461: base for a package issue, `git merge origin/<base>`), step 10, step 11 (461's gate paragraph on the owning checkout, then this branch's "A landed merge ends the run"), step 13 (worktree recreated from the base) and Scope (461) read as one consistent text; no sentence contradicts another.
  - `review-code/SKILL.md`: main's cross-model `--branch "$BASE"` paragraph and this branch's round-start text are separate regions; consistent.
  - `script_reference.md`: main's `_resolve_work_plans_dir.sh`, `check_branch_updates.sh`, `merge_pr.sh`, `dispatch_phase.sh` rows and this branch's `review_progress.sh` and new `pr_start.py` rows; separate rows, consistent. No test file was changed by both sides.
- **Issue 429's lengthened timeline** (107 entries): `pr_start` boundaries at entries 25, 50 and 71, each a Plan Authored; the final scan gives round start and pull-request start 71, armed yes. The real-timeline test in `test_dispatch_phase.sh` passes.
- **Suites** (run directly): test_dispatch_phase 233/0, test_review_code_convergence 38/0, test_address_findings 24/0, test_triage_reviews_integration 69/0, test_skill_paths 143/0, test_records_write_gate 68/0, test_commit_identity 94/0, test_design_anchors 47/0, test_package_issue_loop 220/0, test_merge_pr_gate 200/0 (passed/failed).
- The full `pre-commit run --files` pass was skipped on the owner's direction (2026-11-13); commits carried `SKIP=validate-script-tests`, and the merge commit's own hooks passed. CI on the pull request checks the rest.
- Noticed, not touched: before this merge the branch's own `design.md` already carried `dispatch_phase.sh` citations its script changes had moved (Table 1 `216, 277-326, 501, 635, ...` against actual `222, 283-332, 507, ...`); the merge refresh above corrects them, and no test checks those numbers.

## Local Review
**Status**: complete
**When**: 2026-11-13 11:52 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #467 at `41b1ea7a`
**Depth**: Standard (reason: fix round scoped to the merge of main at 91967144; whole-diff tier unchanged); no cross-model reviewers per handoff: the merge's only hand-resolved file is `docs/design.md`
**Must-fix**: 0 | **Suggestions**: 0

Merge: an automatic re-merge of b3fc6b97 and 8161b57d (`git merge-tree`) conflicts only in `docs/design.md`; 91967144 differs from it only there: the change-log conflict (all 64 rows of the branch and 73 of main present, each side in order, plus the merge row; final count 1038 = `wc -l`) and the `dispatch_phase.sh` citations (Table 1: 222, 283-332, 507, 649, 737, 769, 908; mechanism 1: 555, 601, 603, 665, 940), each checked against the merged script. `check_design_anchors.sh` passes.
Merged regions: `cmd_handoff` puts the `origin/<base>` task line first and the per-pull-request round-3 words after it; a constructed combined case (package issue owner/pkg_a#17 with base `pinned`, merged as #31, second part's first pre-push review) gives `task=/review-code --branch origin/pinned --issue 17` with no convergence words, `next` gives checkpoint:plan then review-code, `round` gives 1, and its round 3 gives `origin/pinned` plus the round-3 words. run-issue steps 2, 8, 11, 13 and Scope read consistently.
Comparison (`next --progress` on every prefix, both scripts, main's extracted to scratch): 7 timelines, 338 prefixes x 4 PR states = 1352 pairs, 72 differences, all intended: 15 at `--pr none` after a merge answer or Merge record (main merge 12, merge-refused 2, unexpected 1; branch checkpoint:plan), 57 next-part round counts from 1 (429 and 332, none/open/draft). `pr_start` on 429: boundaries 25, 50, 71. `next` and `review_progress.sh round` agree on all 45 complete pre-push reviews.
Suites: test_dispatch_phase 233, test_review_code_convergence 38, test_address_findings 24, test_triage_reviews_integration 69, test_skill_paths 143, test_records_write_gate 68, test_commit_identity 94, test_design_anchors 47, test_package_issue_loop 220, test_merge_pr_gate 200; all passed, 0 failed. Full pre-commit pass not run (owner's direction; CI is the check).

### Findings
- [ ] No issues found. LGTM.
