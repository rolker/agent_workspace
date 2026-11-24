# Plan: Host standing rules: a lighter review level for the manifest work until the Rolling test passes

## Issue

Issue 605 in the workspace repo (rolker/agent_workspace).

## Context

On 2026-11-24 the owner approved a lighter review level for the manifest work (his words are quoted in the issue). It has to reach every host session, so it goes into `.agent/knowledge/host_standing_rules.md`. The loop as built does not give the host every answer the rule needs: at `findings` the host may answer only `address`, `merge` is owner-only, and a new issue is outside the outward boundary. `dispatch_phase.sh next` routes a pre-push review on its `**Verdict**`, so a suggestions-only round goes to address-findings. The rule is therefore a host practice read with the checkpoint table; no script or skill step changes. The host's decisions for how it sits in the loop are in progress.md `## Checkpoint` after the Issue Review, and this plan follows them.

## Approach

1. **Add two rows to the Rules table** of `host_standing_rules.md`, after the "Review depth" row's neighbours, directly before the "Wall-clock time" row is not required; append them at the end of the table, after the issue 398 authorization row. Exact text (cells are `Rule | Reason | Source`):

   Row A, Rule cell:

   > Manifest work only, from 2026-11-24 until the Rolling test of issue 436 passes: a lighter review level. Manifest work means the tool at `tools/repos-manifest`, the `ros2_colcon` adapter's use of it, and registration and onboarding from a manifest. It is a dated exception to the rows that open "Review depth:", "A merge happens only when everything is clean", "A review that comes back with open findings" and "At each checkpoint and hand-back, one line per outside reviewer", and to `run-issue` step 9a's one Copilot request; it applies to no other work in any root, whatever the file's intro says about roots. Under it: one plan review and one code review round per pull request; a must-fix is fixed by one fix pass that is not sent to a second review round (the cold read of the final diff and CI read the fix); suggestions are not fixed in another round but deferred to one follow-up issue per pull request; a reviewer that fails once is not asked again that calendar day, and the next day starts with every reviewer again; that day Copilot and Gemini are not asked after a failure, and the cold read is one Codex read on a pull request that changes code; a trivial part (a one-line change) is folded into the next real pull request, not given its own; independent issues keep running in parallel. This removes, for manifest work, the second round on a must-fix that "Review depth" allows. Unchanged: the owner decides every merge; a must-fix is never merged past, and a cold read's must-fix is fixed and then goes to him with the merge question; each skipped reviewer is named at every checkpoint and hand-back with its first failure's reason; the merge gate and `merge_pr.sh`'s flags are untouched (a relaxing flag is still his word for that merge). When the Rolling test of issue 436 passes, the rows it relaxes apply again with no further edit.

   Row A, Reason cell:

   > After the removal of the prototype's reader (issue 569) took about 4 hours 45 minutes across three pull requests, the owner said: "I'm surprised by how long this is taking." The host listed where the time went and proposed, for manifest work until the Rolling test passes: "One plan review and one code review round per pull request. Must-fix findings get fixed; suggestions go into a single follow-up issue instead of another round."; "Skip a reviewer for the day after its first failure, and say so. (That day: no Copilot and no Gemini, with one Codex cold read on pull requests that change code.)"; "No separate pull request for a trivial part. Fold a one-line change into the next real one."; "Keep running independent issues in parallel." The cost was stated with it: later rounds that day did catch defects, including a must-fix in a second round, and under these rules such a defect would surface after merge or not at all. Asked "Should I apply this to issues 498 and 503, which are in implementation now? If yes, I'll also put it in the standing rules file by pull request so it holds across sessions", he answered: "yes".

   Row A, Source cell:

   > Owner, 2026-11-24; issue 605 body; `## Manifest work: the lighter review level` below

   Row B, Rule cell:

   > Standing authorization, within the manifest-work rule above and until it ends: when the owner answers `merge` on a pull request that has deferred suggestions, the host opens one follow-up issue holding them and ticks them as deferred in the integrated review. One issue per pull request; no other new issue is covered.

   Row B, Reason cell:

   > The owner's "yes" to "suggestions go into a single follow-up issue instead of another round" (2026-11-24). Opening an issue is otherwise owner-only (`/orchestrator`, The outward boundary), so the yes is written as the one standing exception, like the issue 398 comment row.

   Row B, Source cell:

   > Owner, 2026-11-24; issue 605 body

2. **Add a section `## Manifest work: the lighter review level`** between the Rules table and `## Already enforced, so no rule text here` (outside `## Rules`, so `test_skill_paths.sh`'s table parser is unaffected). Exact text:

   > Applies only to the manifest work named in the rule above, and only until the Rolling test of issue 436 passes. What a host answers at each checkpoint under it, within `/orchestrator`'s checkpoint table (no script or skill step changes; each answer is recorded `**Decided-by**: host (<reason>)` or `**Decided-by**: owner` as that table says):
   >
   > - `plan`: one plan review. `proceed` after an approved review; a plan that is not approved goes back through `revise` as today, not to a second full review of unchanged text.
   > - `publish` and `rounds`: a pre-push review that raises only suggestions is answered `publish`, not `address`; its suggestions stay open through triage. A review with a must-fix is answered `address`, and the fix pass is not followed by another review round: the host raises `publish` after it, with the full pre-commit pass once before the push as the standing rules already say.
   > - `findings`: the suggestions reach the owner here, asked together with the merge question. The host answers `address` only for a must-fix. `merge` with suggestions open stays his answer alone.
   > - `merge`: his answer alone, every answer. On his `merge` the host opens the one follow-up issue (second row above), links it from the merge hand-back, and then merges as he said.
   > - `merge-refused`: his answer alone, as today.
   > - `phase-failed`: `retry` as today for a phase that failed to run; a reviewer that failed is skipped for the rest of that calendar day and named in the next checkpoint and hand-back with its first failure's reason (a skipped reviewer is not a `retry`).
   >
   > This is a first trial, by hand, of two lines in the roadmap's Path 3: "A lighter level is tried by hand on a low-stakes project, and what it must keep is written down" and "A review round that raises only suggestions goes to the merge question, not to another round". It is run on the workspace's own tool, not on a low-stakes project, and by hand, not in the loop's routing. What it shows is input to those lines; it does not make either true.

3. **Pointer in `.claude/skills/orchestrator/SKILL.md`**, one sentence in a new paragraph directly after the checkpoint table (after the `unexpected` row, before "A host answer that repeats"): "While the manifest work's dated lighter review level is in force (until the Rolling test of issue 436 passes), what the host answers at these checkpoints is read with `host_standing_rules.md`, `## Manifest work: the lighter review level`; the table above is unchanged."

4. **Pointers in `.claude/skills/run-issue/SKILL.md`**, two sentences, prose only (not inside a bash block, so the block-extracting tests in `test_package_issue_loop.sh` still see one block each):
   - In `## Overview`, as a paragraph after the "Nine checkpoint kinds" paragraph, where the loop's rounds are drawn: "For the manifest work, a dated lighter review level (one code review round, suggestions deferred to one follow-up issue) is in force until the Rolling test of issue 436 passes; it is in `.agent/knowledge/host_standing_rules.md` and this overview describes the loop without it."
   - At the head of step 9a, after its first paragraph: "For the manifest work, the standing rules file (`## Manifest work: the lighter review level`) says when the Copilot request is not made and what the cold read is; read it before this step."

5. **No change** to `docs/roadmap.md` (Direction lines untouched), `docs/design.md` (a dated exception to existing rows is not a change to how the parts fit), `dispatch_phase.sh`, or any other skill step.

## Files to Change

| File | Change |
|------|--------|
| `.agent/knowledge/host_standing_rules.md` | Two rows at the end of the Rules table; new section `## Manifest work: the lighter review level` |
| `.claude/skills/orchestrator/SKILL.md` | One pointer paragraph after the checkpoint table |
| `.claude/skills/run-issue/SKILL.md` | Pointer paragraph in Overview; pointer sentence at the head of step 9a |

## Prior Art

The issue 398 comment row is the existing pattern for a narrow standing authorization with a dated source; the "Review depth" row is the pattern for naming which existing text a rule sits beside. Nothing new is built.

## Serves

Less waiting for the same care (README workspace goals), `docs/design.md#rules` and `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to the design picture: a dated exception to existing rows, with the merge gate and the owner's merge decision unchanged.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Verify before claiming | Checkpoint answers checked against the orchestrator table and `dispatch_phase.sh` routing (a suggestions-only round routes to address today, so `publish` is a host answer, not what `next` prints). |
| Keep one current design | The row names the four rows it relaxes by opening words and the end condition. |
| Put each thing at the level it applies to | The scope is stated in the row so the intro's "every root" cannot be read as general. |
| Only what's needed | Pointers only; no script or step change. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | Yes | Entries stay in the existing `## Checkpoint` shape. |
| ADR-0014 | No | Tiers unchanged. |

## Review actions answered

| Action | Where |
|---|---|
| Follow-up issue authorization and token | Row B; `publish` and `findings` lines |
| Rows relaxed, return on the Rolling test | Row A |
| End condition | Row A last sentence |
| Answer-per-checkpoint list | Step 2 |
| Owner's yes quoted | Row A reason, Row B reason |
| Reviewer skip: named, one calendar day | Row A rule; `phase-failed` line |
| Roadmap fit | Step 2 last paragraph |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Rules table | `test_skill_paths.sh` (reason cell non-empty; no text assertion near these places) | Yes, run it |
| Skill pointers | `test_package_issue_loop.sh` extracts bash blocks of run-issue; pointers are prose only | Yes, run it |

## Open Questions

None for the owner; the host's decisions in the Checkpoint entry are for his veto.

## Estimated Scope

Single PR. Suites the implementer runs: `test_skill_paths.sh`, `test_package_issue_loop.sh`, `test_dispatch_phase.sh` (the last two assert no text near the pointer places; run to confirm), and the pre-commit hooks on the changed files, with `SKIP=validate-script-tests` on commits.
