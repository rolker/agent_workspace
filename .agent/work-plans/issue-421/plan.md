# Plan: run-issue dialogs: step 6 gives a one-line header and no layout, so checkpoint dialogs are one dense string

## Issue

https://github.com/rolker/agent_workspace/issues/421

## Context

`run-issue/SKILL.md` step 6 ("Every dialog is self-contained") gives one
orientation header and says to embed the finding text verbatim, but no layout.
Hosts write the header, the findings and the question as one string. The
owner's rules: "next time make the question easier to read, not just an
unformatted block of text" (2026-09-21); a list he refers back to uses bold
stable IDs, never a numbered list (2026-09-25). Only run-issue uses
`AskUserQuestion` today (re-grep at implementation).

## Approach

1. **Dialog layout template in run-issue step 6** — keep the existing header
   block byte-for-byte; after it add a `**Dialog layout.**` paragraph, scoped
   to the `question` field of `AskUserQuestion` (end-of-turn messages follow
   `/orchestrator`'s hand-back shape, so step 6's "(and every message ending a
   turn)" clause does not give hand-backs a second shape), and one code block
   with real line breaks. Rules, in a few lines:
   - Every `questions[i].question` opens with the header line (the dialog
     shows one question at a time, so each must stand alone).
   - Finding IDs `F1`, `F2`... keep counting across the dialog's questions
     (F1-F4 in the first question, F5 onward in the next) and never restart.
     `Qn` names each question itself, one per `questions[]` entry, so a reply
     such as "F3 no, Q2 yes" is unambiguous. `Qn` is the closing question's
     name, not an item.
   - Items are bullets with a bold ID (`- **F1** ...`), as the standing-rules
     row for stable IDs writes them; never a numbered list. The verbatim
     finding text may wrap; one item per line start, never two items on one
     line.
   - Each `options[].description` says what that answer changes and how hard
     it is to undo; the recommended option comes first (principle "Ask about
     what matters, and show how much").
   - Whether the dialog renders `**...**` as bold is unverified. The
     implementer opens one test dialog to check; if it shows literal
     asterisks, the layout stays (still readable) or falls back to bare
     `F1` labels, and the PR says which.
2. **Orchestrator pointer** — one sentence in `orchestrator/SKILL.md` placed
   after the six-item hand-back list in "Hand-back shape" (not a seventh
   item): dialogs to the owner follow `/run-issue` step 6, "Dialog layout".
3. **Standing-rules row** — in `host_standing_rules.md` edit only the dialog
   row's Source column (the "never one dense paragraph" row): add
   "`run-issue/SKILL.md` step 6, Dialog layout". The "Already enforced" list
   is left alone. A pointer only; no layout restated.
4. **Tests in `test_skill_paths.sh`** — `has` assertions: the run-issue file
   holds `**Dialog layout.**`, the header text (`phase X of Y (<phase>);
   <state>`, which makes the standing-rules file's "Already enforced" claim
   about the header true; no test checked the header before) and the example's
   `**F1**`, `**Q1**`; the orchestrator file names `Dialog layout`; the
   standing-rules file names `Dialog layout`. `has` reads the whole file, so
   labels do not claim "step 6". Removing any one fails.
5. **Other skills that ask the owner questions** (grep done at plan review):
   only run-issue names `AskUserQuestion`; onboard-project step 3 (footprint
   questions), audit-project's final step, audit-workspace (~line 69) and
   inspiration-tracker (~line 249) also ask. They are covered through the
   standing-rules row and its new pointer, with no edit to those skills: they
   do not name the dialog tool, and the row already binds every host. Not
   opening a follow-up issue now; if the owner sees a dense dialog from one of
   them, that is the trigger for one (recommended over pre-emptive edits,
   principle "Only what's needed").
6. **Acceptance stated honestly** — the PR says the tests prove the template
   and pointers are present, not that a host follows them; real acceptance is
   the owner's judgment on the next dialogs, recorded at the issue 398
   orchestrator log.

### Proposed template text

A question after the first continues the F numbers and opens with the same
header.

```
<repo>#<N> (PR #M): <title> — phase X of Y (<phase>); <state>

- **F1** <label>: <finding text, verbatim; may wrap onto further lines>
- **F2** <label>: <finding text, verbatim>

**Q1** <the one-sentence question>
```

### Worked example (made-up repository)

```
acme-widgets#57 (PR #61): Retry failed uploads — phase 4 of 8 (review-code); round 1 found 3 issues

- **F1** upload.py:88 (must-fix): "the retry loop never stops when the server answers 413"
- **F2** upload.py:121 (suggestion): "the backoff delay is not capped, so the tenth retry waits 17 minutes"
- **F3** tests/test_upload.py (suggestion): "no test covers a retry that succeeds on the second try"

**Q1** Fix F1 now and leave F2 and F3 for a later pull request?
```

Its options, recommended first: "Fix F1 now (recommended)": adds one fix
commit and a second review round, undone by reverting that commit; "Fix F1,
F2 and F3": the same plus two small changes, undone the same way; "Publish
as is": F1 ships, which fails on a 413 and needs a new pull request to undo.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/run-issue/SKILL.md` | Step 6: add Dialog layout paragraph (scoped to dialogs), template and worked example |
| `.claude/skills/orchestrator/SKILL.md` | One-sentence pointer after the hand-back list |
| `.agent/knowledge/host_standing_rules.md` | Dialog row's Source column only |
| `.agent/scripts/tests/test_skill_paths.sh` | `has` assertions (header text, layout marker, example IDs, two pointers) |

## Prior Art

The existing `has` helper and header assertions; the owner's recorded
dialog-readability rules in host_standing_rules.md. Nothing new is being built.

## Serves

Easy to use (README workspace goals); `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to the design picture; the layout is a rule of the loop's checkpoints.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforce what matters, as simply as possible | Tests prove presence only; stated in the PR, acceptance stays the owner's judgment at issue 398 |
| Ask about what matters, and show how much | Labelled items, one closing question; option descriptions state the change and how hard to undo, recommended first |
| Only what's needed | One block, one example, pointers elsewhere |
| Put each thing at the level it applies to | Layout once in run-issue; others point |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | No | Dialog text is not a timeline entry |
| ADR-0014 | No | No dispatch change |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| run-issue step 6 | orchestrator pointer, standing-rules row, tests | Yes |
| Step 6 "every message ending a turn" clause | Orchestrator six-item hand-back shape | Left unchanged; the new paragraph is scoped to dialogs |
| Other skills that ask the owner questions | Covered by the standing-rules row and pointer; no edits | Yes (Approach 5) |

## Open Questions

None.

## Estimated Scope

Single PR.
