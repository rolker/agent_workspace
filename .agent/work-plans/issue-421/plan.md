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
   block byte-for-byte; after it add a `**Dialog layout.**` paragraph and one
   code block with real line breaks: line 1 the header, blank line, one short
   labelled line per item with a bold ID, blank line, the one-sentence
   question. Rules stated in two or three lines: the verbatim finding text goes
   in the labelled items; IDs are bold, stable, never a numbered list, and run
   continuously across a multi-question dialog (`**F1**`..`**F4**`, then
   `**Q1**`) so his reply can name one; each `options[].description` is one
   sentence of consequence.
2. **Orchestrator pointer** — one sentence in `orchestrator/SKILL.md` "What it
   is" (or beside the dialog-orientation mention): dialogs to the owner follow
   the layout in `/run-issue` step 6, "Dialog layout"; the six-item hand-back
   shape is untouched.
3. **Standing-rules row** — in `host_standing_rules.md` line 59 (the
   orientation-line pointer) and the dialog rule row at line 36's Source
   column neighbours: name "Dialog layout" in `run-issue/SKILL.md` step 6 as
   the template. A pointer only; no layout restated.
4. **Tests in `test_skill_paths.sh`** — three `has` assertions after the
   orchestrator block: run-issue step 6 holds `**Dialog layout.**`, `**F1**`,
   `**F4**`, `**Q1**`; orchestrator names `Dialog layout`; the standing rules
   file names `Dialog layout`. Removing any one fails. Existing header
   assertions stay green because the header is unchanged.
5. **Acceptance stated honestly** — the PR says the tests prove the template
   and pointers are present, not that a host follows them; real acceptance is
   the owner's judgment on the next dialogs, recorded at the issue 398
   orchestrator log.

### Proposed template text

```
<repo>#<N> (PR #M): <title> — phase X of Y (<phase>); <state>

**F1** <label>: <finding text, verbatim, one line>
**F2** <label>: <finding text, verbatim, one line>
**Q1** <label>: <what he is deciding>

<the one-sentence question>
```

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/run-issue/SKILL.md` | Step 6: add Dialog layout paragraph and template block |
| `.claude/skills/orchestrator/SKILL.md` | One-sentence pointer for dialogs |
| `.agent/knowledge/host_standing_rules.md` | Source column / pointer line names the template |
| `.agent/scripts/tests/test_skill_paths.sh` | Three `has` assertions |

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
| Enforcement over documentation | Tests prove presence only; stated in the PR, acceptance stays the owner's judgment at issue 398 |
| Ask about what matters, and show how much | Labelled items, one closing question |
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
| Step 6 "every message ending a turn" clause | Orchestrator six-item hand-back shape | Left unchanged, pointer says dialogs only |

## Open Questions

None.

## Estimated Scope

Single PR.
