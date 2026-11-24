---
issue: 605
---

# Issue #605 — Host standing rules: a lighter review level for the manifest work until the Rolling test passes

## Issue Review
**Status**: complete
**When**: 2026-11-24 13:56 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #605

### Scope Assessment

**Well-scoped?** Yes. One table row, a short "how each checkpoint is answered" note in the same file, and pointer lines in two skills. It fits one pull request.
**Right repo?** Yes. The rules file, the orchestrator skill and the run-issue skill are all workspace files.
**Serves**: "A safeguard has to earn its cost" and Less waiting for the same care (README goals) - `docs/design.md#rules` (the owner-decides-every-merge and review rows it relaxes) and `docs/design.md#review-loop-and-timeline`.
**Design picture?** No change. It is a dated exception to existing rows, and the owner's decision is quoted in the issue, so no new question is raised. Whether the design's Review-loop section should mention the exception is for the plan to check.
**Dependencies**: none blocking. The rule ends when the Rolling test of #436 (the end-to-end acceptance test) passes; #498 and #503 (manifest implementation issues, in progress) are the first to run under it.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Verify before claiming / document from source | Action needed | The loop as built does not give the host every answer the rule needs. Verified in `orchestrator/SKILL.md`: `findings` allows the host only `address`, and `merge` (deferring open findings) is owner-only. A new issue is outside the outward boundary (owner-only). So "suggestions go into a single follow-up issue" needs one stated answer: either the owner's 2026-11-24 yes counts as standing authorization for exactly one follow-up issue per pull request (like the issue 398 comment row), or the host asks per pull request. The text must say which, and which token is recorded at a suggestions-only review (`publish` at `rounds`/`publish`, not `findings`). |
| Keep one current design / earlier rules | Action needed | The new row must name which existing rows it relaxes and say they return when the Rolling test passes: the review-depth row (second round on a must-fix), "merge only when everything is clean", the open-findings row, and the one Copilot request plus cold read. It must also say the 2026-11-24 rule is read together with the review-depth row, which today allows a second round on a must-fix, and that it removes that round for manifest work. |
| Ask about what matters | Watch | "One code review round, must-fix fixed" leaves unstated whether the fix pass is re-reviewed. The issue's cost paragraph implies it is not. Write that explicitly so a host does not guess. |
| Put each thing at the level it applies to | Watch | The file says rules apply in every root, but this one is scoped to manifest work. Give it a scope cell that cannot be read as global, and keep project names out of mechanism text (the file's own rule): refer to `tools/repos-manifest` and the issue #436 test by path and number only. |
| Only what's needed | OK | No script or skill-step change; pointers only. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (progress timeline) | Yes | The rule says what the host records at skipped rounds; entries stay in the existing `## Checkpoint` shape with `**Decided-by**: host (<reason>)`. |
| ADR-0014 (model tiers) | No | Phases and tiers are unchanged. |
| Merge-gate ADR/design (`docs/design.md#merge-gate`) | Watch | `merge_pr.sh` still checks for a current review; the rule must not suggest bypassing its flags. Say the gate is untouched. |

### Consequences

- `test_skill_paths.sh` must pass (non-empty reason cell, which the issue already requires).
- Pointer lines in `orchestrator/SKILL.md` (checkpoint table) and `run-issue/SKILL.md` (steps for `rounds`, 9a cold read, Copilot wait) where a reader would otherwise read the unrelaxed rule as current.
- Roadmap Path 3: the two lines named in the issue stay unchecked. If the plan wants a pointer in `docs/roadmap.md`, it goes under the Direction text, not in the Check column.

### Recommendations

- State in the rule which existing rows it relaxes and that the date-bound exception ends when the Rolling test (#436) passes, after which those rows apply again with no further edit.
- Write one answer-per-checkpoint list in the rules file (`plan`, `rounds`/`publish`, `findings`, `merge`, `merge-refused`), saying `merge` stays owner-only and a must-fix is never merged past.
- Resolve the follow-up-issue authorization (see Principle Alignment) in the rule text, quoting the owner's "yes" of 2026-11-24 as the source.
- Say the reviewer-skip line names each skipped reviewer at every checkpoint, and that the skip lasts for that calendar day only, so the next day starts with all reviewers again.
- Make the roadmap fit explicit: the roadmap's trial line says "low-stakes project", while this is the workspace's own tool; note the difference in the rule's scope so the result is read as input to Path 3, not as that line being true.

### Actions
- [ ] The loop as built does not give the host every answer the rule needs. Verified in `orchestrator/SKILL.md`: `findings` allows the host only `address`, and `merge` (deferring open findings) is owner-only. A new issue is outside the outward boundary (owner-only). So "suggestions go into a single follow-up issue" needs one stated answer: either the owner's 2026-11-24 yes counts as standing authorization for exactly one follow-up issue per pull request, or the host asks per pull request. The text must say which, and which token is recorded at a suggestions-only review.
- [ ] The new row must name which existing rows it relaxes and say they return when the Rolling test passes: the review-depth row, "merge only when everything is clean", the open-findings row, and the one Copilot request plus cold read; and say it removes the second round on a must-fix for manifest work.
- [ ] State in the rule which existing rows it relaxes and that the date-bound exception ends when the Rolling test (#436) passes, after which those rows apply again with no further edit.
- [ ] Write one answer-per-checkpoint list in the rules file (`plan`, `rounds`/`publish`, `findings`, `merge`, `merge-refused`), saying `merge` stays owner-only and a must-fix is never merged past.
- [ ] Resolve the follow-up-issue authorization (see Principle Alignment) in the rule text, quoting the owner's "yes" of 2026-11-24 as the source.
- [ ] Say the reviewer-skip line names each skipped reviewer at every checkpoint, and that the skip lasts for that calendar day only, so the next day starts with all reviewers again.
- [ ] Make the roadmap fit explicit: the roadmap's trial line says "low-stakes project", while this is the workspace's own tool; note the difference in the rule's scope so the result is read as input to Path 3, not as that line being true.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:56 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the Issue Review at 1124d80b finds the issue well scoped with seven actions for the plan and no question for the owner, provided the plan settles the follow-up issue from his quoted words)
**After**: issue-actions
**Decision**: proceed

The review's actions go to the plan. Host decisions on how the rule sits in the loop as built, for the owner's veto, each read from what he approved on 2026-11-24 ("One plan review and one code review round per pull request. Must-fix findings get fixed; suggestions go into a single follow-up issue instead of another round."; "Skip a reviewer for the day after its first failure, and say so."; his answer "yes"):

- At a pre-push review with suggestions only, the host answers `publish`, not `address`. The suggestions stay open through triage and reach him at the `findings` checkpoint, which is asked together with the merge question; `merge` there stays his answer alone, as today.
- On his `merge` answer the host opens one follow-up issue holding that pull request's deferred suggestions and ticks them as deferred. His "yes" to "suggestions go into a single follow-up issue" is the standing authorization for that one issue per pull request, within the rule's scope and until it ends; no other new issue is covered.
- A must-fix is fixed by one fix pass. The fix is not sent to a second full review round; the cold read of the final diff and CI are what read it. A must-fix found by the cold read is fixed and then goes to him with the merge question.
- A reviewer that fails once is not asked again that calendar day, and every checkpoint and hand-back that day names it as skipped with its first failure's reason.
- The rule's scope is the manifest work only and it ends when the Rolling test of issue 436 passes; the rows it relaxes apply again from then.

## Plan Authored
**Status**: complete
**When**: 2026-11-24 14:05 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-605/plan.md` at `00c110a7`

Two rules rows (the lighter level; the one follow-up issue authorization), a per-checkpoint section in the rules file, and prose pointers in the orchestrator and run-issue skills; no script or step change. Answers the Issue Review's seven actions.

## Plan Review
**Status**: complete
**When**: 2026-11-24 14:01 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #605 — Host standing rules: a lighter review level for the manifest work until the Rolling test passes
**Plan**: `.agent/work-plans/issue-605/plan.md` at `00c110a7`
**Branch**: `feature/issue-605`
**Serves**: Less waiting for the same care (README workspace goals), `docs/design.md#rules` and `docs/design.md#review-loop-and-timeline`.

Ready with directions: every gap below is closed by the replacement wording given; no decision is left open for the host or the owner beyond the host readings already listed for his veto.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two rows, one section, three pointers; one pull request. |
| Issue alignment | Needs work | All seven Issue Review actions are answered, and every quoted sentence in the two reason cells is verbatim from the issue body. But the per-checkpoint list promises checkpoints `dispatch_phase.sh next` does not raise (F1, F2), has no 9a item (F3), and Row A turns the owner's "(That day: ...)" example into a general rule (F4). |
| File targeting | Good | The three files are the right ones; no script or step change is needed once the host-written checkpoint is stated (F1). |
| Consequences | Good | The three suites assert nothing the planned text removes: the rules-table parser splits cells outside backticks and Row A/B have no bare pipe; `has` checks in `test_skill_paths.sh` only require text that stays; `test_package_issue_loop.sh` counts bash blocks using `where` (still 4, pointers are prose). |
| Principle alignment | Needs work | "Verify before claiming": the router walk below. "Keep one current design": the four relaxed rows are named by their real opening words, but one of them is not relaxed (F5). |
| ADR compliance | Good | ADR-0013: entries stay in the `## Checkpoint` shape, within the vocabulary, so nothing routes to row 28. |
| ROS conventions | N/A | Workspace plan. |

### What the router does (dispatch_phase.sh next, read at the worktree head)

- Pre-push review `approved`, with suggestions: `checkpoint:publish` (rows 13-15). Host answers `publish` after the full pass. Plan is right.
- Pre-push review `changes-requested`, suggestions only, round 1 or 2: `action=address-findings`, no checkpoint (only `approved` or round >= 3 raise one). There is nothing to "answer `publish`" at.
- Must-fix, one fix pass: the fix's `## Implementation` routes to `action=review-code` (round 2, a full round with cross-model reviewers; the narrow convergence scope is put on the task line only at round 3), never to `publish`. No checkpoint the router raises sits between the fix and round 2.
- Post-push cold read (a PR-mode `## Local Review`) with any non-`approved` verdict: `action=address-findings`, then a PR-mode re-review round, then `triage-reviews`. The plan's "a cold read's must-fix is fixed and then goes to him with the merge question" skips that re-review, which the router does not.
- What does work with no script change: a `## Checkpoint` the host appends itself with `**After**: publish`, `**Decision**: publish` routes to `publish` with no pull request and to `triage-reviews` with one open (the `after in ("publish", "rounds")` block); `**After**: plan`, `**Decision**: proceed` routes to `implement`. These are host-written checkpoints the router did not raise, so the text must say so, and the orchestrator and run-issue pointers must say it is the one place the "run-issue raises every checkpoint" text does not hold.

### Findings

1. **[Issue alignment] must-fix** — The `publish` and `rounds` line says a suggestions-only pre-push review "is answered `publish`" and that after a must-fix fix pass "the host raises `publish`". Neither checkpoint is raised. Replace the `publish` and `rounds` bullet with:
   > - Where `next` would start a second review round, the host does not dispatch it. This is the one place under this rule where the host writes a checkpoint `next` did not raise: it runs the full pre-commit pass first (`run-issue` step 7; a failure is recorded as the host's `address`, as there), then appends a `## Checkpoint` with `**After**: publish`, `**Decision**: publish` and `**Decided-by**: host (manifest-work rule: <reason>)`, the review's open suggestions listed in its body, and calls `next`, which routes it to `publish` (no pull request yet) or `triage-reviews` (pull request open). The two cases: a pre-push review with no must-fix that `next` sends to `address-findings` (the host checks with `review_progress.sh verdict`: round 1 with no must-fix gives `ship=recommended`), reason "suggestions only"; and the `## Implementation` of the one fix pass for a must-fix, which `next` sends to `review-code`, reason "fix pass, no second round". A pre-push review that is `approved` raises `checkpoint:publish` itself and is answered `publish` as today. The suggestions stay open through triage.
2. **[Issue alignment] must-fix** — The cold read's findings route to a fix round and a PR-mode re-review. Add to the `findings` bullet (or a new bullet after it):
   > - A cold read (step 9a) that is not `approved` goes to `address-findings` by `next`. With a must-fix, that fix pass runs; with suggestions only, it is not dispatched. In either case the host then appends the `publish` checkpoint of the bullet above (pull request open, so `next` routes it to `triage-reviews`) instead of dispatching the PR-mode re-review, and triage brings the result to the owner with the merge question.
   And change Row A's "(the cold read of the final diff and CI read the fix)" to "(the pull request's one outside read at `run-issue` step 9a, Copilot's review or the cold read, and CI read the fix)": on the first pull request of a day Copilot, not a cold read, is that read.
3. **[Issue alignment] suggestion** — No item says what the host does at 9a or how a skipped pre-push reviewer is left out. Add two bullets:
   > - Step 9a: until Copilot fails on a given day, 9a runs as written (one request per pull request). After its first failure that day (any 9a "not available" outcome), later pull requests that day skip item 2's request and go to item 3, and the outside-reviewer line says "Copilot: skipped, failed earlier today (<first failure's reason>)". The cold read's agent is Codex, or Gemini when Codex has failed that day; with both failed that day, item 3's "With neither agent available" applies. A cold read whose agent fails goes to `phase-failed` as today; the retry names the other agent if it has not failed that day. That day, a pull request that changes no code gets no cold read (the owner's "one Codex cold read on pull requests that change code"), and the outside-reviewer line says so.
   > - Pre-push `review-code` and its handoff: the host adds the reviewers skipped that day, with their first failure's reason, and "omit them from `--agents`" (review-code: "Omit an agent from the list when its CLI is known to be unavailable").
   And replace the `phase-failed` bullet with: "`phase-failed`: `retry` as today for a phase that failed to run. A reviewer's failure inside a phase that completed (an agent named unavailable in a review entry, or a 9a 'not available') is not a `phase-failed`; it is what starts that reviewer's skip for the day."
4. **[Issue alignment] suggestion** — Row A's "that day Copilot and Gemini are not asked after a failure, and the cold read is one Codex read on a pull request that changes code" makes the 2026-11-24 example general (Codex fixed even if Codex is the one that failed). Replace with: "a reviewer that fails once is not asked again that calendar day, and the next day starts with every reviewer again (on 2026-11-24 that meant no Copilot and no Gemini, with one Codex cold read on a pull request that changes code);".
5. **[Principle alignment] suggestion** — Row A lists "At each checkpoint and hand-back, one line per outside reviewer" as relaxed, but the rule keeps it whole (a skipped reviewer is named with its reason, exactly what that row asks). Drop it from the list and add it to "Unchanged". Keep the other three by opening words (they match the file: "Review depth:", "A merge happens only when everything is clean", "A review that comes back with open findings") plus `run-issue` step 9a's one Copilot request; also name "The review-plan phase runs before any implementation" under "Unchanged" (the one plan review always runs).
6. **[Issue alignment] suggestion** — The `plan` bullet's "not to a second full review of unchanged text" cannot happen (a `revise` changes the text, and `next` sends the new `## Plan Authored` to `review-plan`). Replace with: "`plan`: one plan review per pull request. `proceed` when it leaves directions only (they go into the implement handoff). On `revise`, after the revised plan's `## Plan Authored` the host appends a `plan` checkpoint answered `proceed`, `**Decided-by**: host (manifest-work rule: one plan review)`, instead of dispatching a second `review-plan`; `next` routes it to `implement`."
7. **[Issue alignment] suggestion** — The end condition is checkable only through the issue. Change both "until the Rolling test of issue 436 passes" in Row A's first sentence and the section's first sentence to "until the Rolling test of issue 436 (the second-machine test on the new manifest) passes, which a host checks as issue 436 closed as completed (`gh issue view 436 --json state,stateReason`)". Add to the scope sentence: "An issue whose changes reach outside these parts is not manifest work, and its pull request follows the rows unrelaxed."
8. **[Consequences] suggestion** — Row B: say how the boxes are ticked, with the existing mechanism: "…and ticks them as deferred with `review_progress.sh check --deferred` (`run-issue` step 6, 'Deferred suggestion-only boxes')". The follow-up issue carries the AI signature like any issue.
9. **[File targeting] suggestion** — Pointers. Orchestrator paragraph: append "; under it the host also appends a `publish` or `plan` checkpoint that `next` did not raise, in the cases that section names." run-issue Overview pointer: append "Under it the host appends a `publish` or `plan` checkpoint that `next` did not raise, in the cases that file names, instead of dispatching a second review round." The 9a pointer stands.
10. **[Plan text] suggestion** — Step 1's muddled first sentence becomes: "Append two rows at the end of the Rules table, after the issue 398 standing-authorization row."

### Summary

The owner's words are quoted verbatim and the scope matches what he approved, but the checkpoint list promises answers at checkpoints the router does not raise. The honest mechanism with no script change is a host-written `publish` (or `plan`) checkpoint in place of the second round, said openly; with the replacement wording above the plan is ready for implementation.

### Recommended Actions

- [ ] Replace the `publish`/`rounds` bullet with F1's text and add F2's cold-read bullet and Row A wording.
- [ ] Add F3's 9a and pre-push `--agents` bullets; replace the `phase-failed` bullet.
- [ ] Apply F4 and F5 to Row A's rule cell (general skip wording; the outside-reviewer row moved to "Unchanged"; the plan-review row named as unchanged).
- [ ] Apply F6 to the `plan` bullet and F7's checkable end condition and mixed-scope sentence.
- [ ] Apply F8 to Row B and F9 to both skill pointers; fix step 1's sentence (F10).
- [ ] Run `test_skill_paths.sh`, `test_package_issue_loop.sh`, `test_dispatch_phase.sh` and the hooks on the changed files.

### Decisions made (owner may veto)
- A host-written `publish` or `plan` checkpoint, in place of the second round the router would start, is how the rule runs with no script change — undoing it: the second rounds run as the router routes them, and the rule's "one round" holds only where a review is `approved`.
- On a day Copilot is skipped, a pull request that changes no code gets no cold read, read from his "one Codex cold read on pull requests that change code" — undoing it: drop that sentence and the cold read runs on every pull request.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 14:02 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the Plan Review at e89874c4 finds the plan ready with directions F1 to F10, each given as exact wording, and leaves no decision that must come first)
**After**: plan
**Decision**: proceed

The implementer applies F1 to F10 word for word from the Plan Review entry, in place of the plan's text where they differ. Two readings the review lists for the owner's veto are accepted by the host and go into the rule as the review words them: where `next` would start a second review round, the host writes a `publish` checkpoint that `next` did not raise (after its full pre-commit pass), which is how the rule runs with no script change; and on a day Copilot is skipped, a pull request that changes no code gets no cold read, read from his words "one Codex cold read on pull requests that change code". The end of the rule is checked as issue 436 closed as completed.
