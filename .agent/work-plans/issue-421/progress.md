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
