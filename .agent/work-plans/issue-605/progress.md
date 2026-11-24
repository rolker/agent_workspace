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
