---
issue: 421
---

# Issue #421 — run-issue dialogs: step 6 gives a one-line header and no layout

## Issue Review
**Status**: complete
**When**: 2026-11-09 14:03 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #421

### Scope Assessment

**Well-scoped?** Yes — one template in run-issue step 6, one pointer line in the orchestrator skill, one Source-column edit, one test block; fits a single PR.
**Right repo?** Yes — all four files are workspace infrastructure (`.claude/skills/`, `.agent/knowledge/`, `.agent/scripts/tests/`).
**Serves**: Easy to use (README "Easy to use"); principle "Ask about what matters, and show how much" — `docs/design.md#review-loop-and-timeline`
**Design picture?** No change — the dialog format is a rule of the loop's checkpoints, not a change to how the parts fit.
**Dependencies**: none identified (the acceptance judgment rides on the issue 398 orchestrator log, not a blocker).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | Watch | A skill-text test only proves the template and pointer exist, not that a host follows them; the issue says so by making the real acceptance the owner's judgment at the issue 398 log. Keep that acceptance line. |
| Ask about what matters, and show how much | OK | Directly served: labelled items, one closing question. |
| Only what's needed | Watch | Keep the template to one short block plus the five-line example; the Source-column edit should be a pointer, not a restatement of the layout. |
| Put each thing at the level it applies to | OK | The layout lives once in run-issue step 6; orchestrator and the rules row point at it. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (progress timeline) | No | Dialog text is not a timeline entry. |
| ADR-0014 (model tiers) | No | No dispatch change. |

### Consequences

- `test_skill_paths.sh` uses a whitespace-flattening `has` helper, so asserting tokens (e.g. a bold-ID item like `**F1**`, the template heading, and a `run-issue` pointer string in the orchestrator skill) works despite line breaks inside a code block.
- Step 6's existing "(and every message ending a turn)" clause means the template also governs hand-backs; the orchestrator hand-back shape (six items) must stay unchanged, as the issue says, so the pointer must say "dialogs" and not rewrite that list.
- Any other skill that raises `AskUserQuestion` (grep shows only run-issue today) needs no change; re-grep when implementing.

### Recommendations

- Make the template's `question` example show real line breaks and state that bold stable IDs are reused across the dialog's questions (a multi-question dialog numbers IDs continuously, e.g. `**F1**`..`**F4**`, then `**Q1**`, so his reply can name an ID), since the failure included multi-question dialogs with no IDs.
- Add the test assertions for three things: the template marker in run-issue step 6, the orchestrator pointer to it, and the standing-rules row naming it, so removing any one fails.
- Keep the `options[].description` guidance to one sentence of consequence per option, and leave the existing orientation header format byte-for-byte so existing tests on it stay green.

### Actions
- [ ] Make the template's `question` example show real line breaks and state that bold stable IDs are reused across the dialog's questions (a multi-question dialog numbers IDs continuously, e.g. `**F1**`..`**F4**`, then `**Q1**`, so his reply can name an ID), since the failure included multi-question dialogs with no IDs.
- [ ] Add the test assertions for three things: the template marker in run-issue step 6, the orchestrator pointer to it, and the standing-rules row naming it, so removing any one fails.
- [ ] Keep the `options[].description` guidance to one sentence of consequence per option, and leave the existing orientation header format byte-for-byte so existing tests on it stay green.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 14:04 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the three open actions are mechanism: the template example's shape and continuous stable IDs across multi-question dialogs, three text assertions, and one consequence sentence per option description; none changes what the owner asked for)
**After**: issue-actions
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. The actions go to plan-task as plan inputs.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 14:05 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-421/plan.md` at `c695ece8`

Add a Dialog layout template (header, labelled bold-ID items continuous across questions, one-sentence question) to run-issue step 6, point to it from the orchestrator skill and the standing-rules row, and add three presence tests; acceptance stays the owner's judgment at issue 398.

## Plan Review
**Status**: complete
**When**: 2026-11-09 14:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #421 — run-issue dialogs: step 6 gives a one-line header and no layout, so checkpoint dialogs are one dense string
**Plan**: `.agent/work-plans/issue-421/plan.md` at `c695ece8`
**Branch**: `feature/issue-421`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four files, one PR; matches the issue's "What to change" list. |
| Issue alignment | Needs work | Serves (as checked): "Easy to use (README workspace goals); `docs/design.md#review-loop-and-timeline`" (both exist). The issue's acceptance asks for the template *and* a worked five-line example; the plan has only a placeholder template. The multi-question ID scheme (issue review Action 1) is stated in one clause but the template contradicts it (`**Q1**` is both an item and, implicitly, the closing question). |
| File targeting | Needs work | Right four files. Approach 3 names two places in `host_standing_rules.md` (the line 59 "Already enforced" pointer and the row 36 Source column); the issue asks for the row's Source column only. Approach 2 places the orchestrator pointer under "What it is"; the issue asks for it under "Hand-back shape". |
| Consequences | Needs work | The plan says "existing header assertions stay green"; `grep` of `.agent/scripts/tests/` finds no assertion on the orientation header at all, while `host_standing_rules.md` lines 59–60 list that line as "Already enforced". The other-skills check was left to implementation (see finding 8). |
| Principle alignment | Good | Tests prove presence only and the plan says so (acceptance stays the owner's judgment at issue 398). The self-check names "Enforcement over documentation", which is not a current principle; the current one is "Enforce what matters, as simply as possible". Design picture: no change, agreed (`docs/design.md#review-loop-and-timeline` describes checkpoint kinds, not dialog text). |
| ADR compliance | Good | ADR-0013 and ADR-0014 not triggered, agreed. |
| ROS conventions | N/A | Workspace plan. |

Tests: the three `has` assertions each read a different file, and none of `**Dialog layout.**`, `**F1**`, `**F4**`, `**Q1**`, `Dialog layout` appears in run-issue, orchestrator or the standing-rules file today (grep; row 37's `- **Q1** ...` is in the standing-rules file but the plan asserts `Dialog layout` there), so each fails alone. `has` reads the whole file, not step 6 only; the label should not claim "step 6".

### Findings

1. **[Issue alignment]** must-fix — The issue's acceptance requires "the template with line breaks and a worked example" ("A five-line good example"); the plan's Approach 1 is "one code block" of placeholders. Add a filled-in example next to the template. Per standing-rules row 42 (mechanism text names no project), use a generic repo name, not the gz4d dialog the issue quotes.
2. **[Issue alignment]** must-fix — The multi-question ID scheme is ambiguous. The template lists `**Q1** <label>: <what he is deciding>` as an item and then a separate closing question, so it is unclear what Q1 names. `AskUserQuestion` shows one question at a time, so the plan should say: (a) every `questions[i].question` opens with the header line (step 6's "open every AskUserQuestion" read per question); (b) finding IDs continue across the dialog's questions and never restart (F1–F4 in the first, F5… in the second); (c) `Qn` names the question itself, one per `questions[]` entry, so a reply like "F3 no, Q2 yes" is unambiguous. Show this in the template or the example.
3. **[Issue alignment]** suggestion — "verbatim, one line" conflicts for any finding longer than a line. Say instead: one item per line start, the item may wrap, never two items joined on one line. Standing-rules row 37 writes the IDs as bullets (`- **Q1** ...`); use `- **F1** ...` or say why not. Whether the dialog renders `**…**` as bold or as literal asterisks is unverified; one test dialog during implementation settles it, and bare `F1` labels are the fallback.
4. **[Principle alignment]** suggestion — "each `options[].description` is one sentence of consequence": per "Ask about what matters, and show how much" and standing-rules row 40, make it what the answer changes and how hard it is to undo, with the recommended option first.
5. **[Consequences]** suggestion — Drop the "existing header assertions stay green" claim (none exist), or better, add the header text (for example `phase X of Y (<phase>); <state>`) to the run-issue `has` assertion, which makes the standing-rules "Already enforced" claim at lines 59–60 true at no extra cost.
6. **[File targeting]** suggestion — Edit only row 36's Source column (add "`run-issue/SKILL.md` step 6, Dialog layout"); leave the "Already enforced" list alone, since the layout is not enforced by a check beyond presence. The row stays a pointer.
7. **[File targeting]** suggestion — Put the orchestrator pointer where the issue asks: one sentence after the six-item hand-back list, not a seventh item. In run-issue, scope the Dialog layout paragraph to the `AskUserQuestion` `question` field and say end-of-turn messages follow `/orchestrator`'s hand-back shape, so step 6's "(and every message ending a turn)" clause does not set two shapes for hand-backs.
8. **[Consequences]** suggestion — Do the other-skills check now, not at implementation. Done here: only run-issue names `AskUserQuestion` among the skills, but onboard-project step 3 (footprint questions), audit-project's final step (fix now / open issue / queue / skip per finding), audit-workspace (line 69) and inspiration-tracker (line 249) ask the owner questions. Record in the plan that they are reached through standing-rules row 36 and its new pointer (no edit), or name a follow-up issue; a "put each thing at the level it applies to" reader may otherwise ask why the layout lives in run-issue only.

### Summary

The approach is the right size and the tests are sound, but the plan misses the issue's worked example and leaves the multi-question ID scheme (the failure the issue names) ambiguous in its own template. Fix those two in the plan; the rest can be settled during implementation.

### Recommended Actions

- [ ] Add a filled-in five-line worked example (generic repo name) beside the placeholder template in Approach 1.
- [ ] State the multi-question scheme: header on every question, finding IDs continue across questions, `Qn` names each question; make the template match.
- [ ] Allow a verbatim item to wrap (one item per line start); align with row 37's bullet form or say why not; check bold rendering in one test dialog.
- [ ] Option descriptions: what the answer changes and how hard to undo; recommended option first.
- [ ] Replace the "existing header assertions" claim by adding the header text to the run-issue assertion.
- [ ] Standing rules: row 36 Source column only. Orchestrator: one sentence after the six-item hand-back list; run-issue's paragraph scoped to dialogs.
- [ ] Record the other-skills grep result in the plan and how those questions are covered (row 36 pointer, or a follow-up issue).

## Checkpoint
**Status**: complete
**When**: 2026-11-09 14:08 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (two must-fix plan edits, both mechanism: a worked example with a made-up repository name, and the ID scheme across a multi-question dialog; six suggestions on wording, option descriptions, the header assertion, the standing-rules edit scope, the orchestrator pointer placement and the four other skills that ask questions; first host revise on this issue)
**After**: plan
**Decision**: revise

Host answer under /orchestrator's checkpoint table. Findings F1-F2 and S1-S6 of the Plan Review at e7ce085e go to plan-task.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 14:20 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-421/plan.md` at `8d70f2fa`

Revision after the plan review: added a worked example with a made-up repository, stated the multi-question ID scheme (header on every question, F numbers continue, Qn names each question), bullets that may wrap, option descriptions with consequence and undo cost, a header assertion in the run-issue test, narrower standing-rules and orchestrator edits, and recorded how the four other question-asking skills are covered (standing-rules row and pointer, no follow-up issue now).
