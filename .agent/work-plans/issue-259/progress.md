---
issue: 259
---

# Issue #259 — Trim AGENTS.md to policy + pointers; move reference tables to .agent/knowledge/

## Issue Review
**Status**: complete
**When**: 2026-11-02 12:15 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #259

### Scope Assessment

**Well-scoped?** Yes, with a caveat. One PR is feasible (doc moves plus pointers), but the body's numbers are stale: AGENTS.md is 448 lines / 33,047 bytes today, not 418 / 18.5 KB, and the Script Reference table has grown (about 50 rows, several very long). The ~150-line target now needs roughly 300 lines out; docs/design.md OQ-4 (budget "under 200 lines per file") is the recorded open question this answers, so the target should be restated as a number the owner sets.
**Right repo?** Yes. Workspace repo (AGENTS.md, .agent/knowledge/).
**Serves**: Know whether it works / keep instructions lean, per the README workspace goals; `docs/design.md#instruction-layers` (answers OQ-4).
**Design picture?** Changes `docs/design.md#instruction-layers`: the "AGENTS.md is 442 lines" figure and the Change log row must be updated in the same change (ADR-0017), and OQ-4 closed or reworded once the owner picks a budget. The owner's go-ahead for this drive counts as approval in principle for the instruction-file change; the budget number itself is his call.
**Dependencies**: "After #252's plan lands" no longer holds: #252 is CLOSED. Sibling #258 (skill carving) is independent. Parallel #323 adds a Script Reference row to AGENTS.md on its own branch; whichever merges second rebases, and if this lands first #323's row belongs in the new script_reference file. Fork-side rolker/ros2_agent_workspace#564 coordination still applies.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | Always-loaded layer should hold rules only; reference tables load on demand |
| Keep one current design | Action needed | Update `docs/design.md#instruction-layers` (line/byte counts, OQ-4, Change log row) in the same PR |
| Verify before claiming | Action needed | Re-measure the current sizes and section list; the body's counts (418 lines, ~45 rows, 150 target) are stale, and the "Documentation Accuracy" section it says to keep is now "Verify Before Claiming" |
| Put each thing at the level it applies to | OK | Moves reference material to .agent/knowledge/ with pointers |
| Ask-First for instruction files | Watch | Owner go-ahead in principle recorded; final merge remains his |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0010 (git-bug optional) | Yes | Stays the decision record; its text and `_issue_helpers.sh` line 15 cite AGENTS.md "git-bug-first Pattern" and must be repointed |
| ADR-0017 (design doc current) | Yes | Design change, see above |
| ADR-0013 | No | |

### Consequences

- The SessionStart hook pins nine AGENTS.md headings (`.claude/hooks/session_start_project_layer.sh`, checked by `test_session_start_layer.sh`). None of the sections to move (GitHub CLI Patterns, Build & Test, Script Reference, Worktree Workflow) is pinned, so project sessions lose nothing. The pinned ones must be kept verbatim, including "Verify Before Claiming". Boundaries must keep the three hard CLI rules, since Boundaries is the pinned section that reaches project sessions.
- Repoint references: `_issue_helpers.sh` line 15, ADR-0010 line 69, and links in CLAUDE.md, CODEX.md, copilot and gemini instruction files; grep for "Script Reference", "GitHub CLI Patterns", "git-bug-first Pattern".
- `test_issue_review_entry.sh` mentions the AGENTS.md script row only as fixture text; no change needed. The pre-commit hook scoping (`run_script_tests.sh`) treats AGENTS.md as in-scope, so run the full hooks once.
- CLAUDE.md and AGENTS.md instruction text that tells agents to add Script Reference rows (e.g. review-issue/plan-task consequences maps in principles_review_guide.md) should point at the new file.

### Recommendations

- Re-baseline the body: record 448 lines / 33,047 bytes as "before" and have the owner confirm the target (150 as written, or under 200 per OQ-4).
- Treat the Script Reference as a moved file with a generation or drift check if cheap; otherwise move verbatim and leave generation as follow-up.
- Land before or coordinate with #323: if this merges first, #323 rebases its row into `.agent/knowledge/script_reference.md`.
- Add a size ratchet (line count of AGENTS.md) only if the owner wants it; otherwise leave to #258's pattern.

### Actions
- [ ] Update `docs/design.md#instruction-layers` (line/byte counts, OQ-4, Change log row) in the same PR
- [ ] Re-measure the current sizes and section list; the body's counts (418 lines, ~45 rows, 150 target) are stale, and the "Documentation Accuracy" section it says to keep is now "Verify Before Claiming"
- [ ] Re-baseline the body: record 448 lines / 33,047 bytes as "before" and have the owner confirm the target (150 as written, or under 200 per OQ-4).
- [ ] Treat the Script Reference as a moved file with a generation or drift check if cheap; otherwise move verbatim and leave generation as follow-up.
- [ ] Land before or coordinate with #323: if this merges first, #323 rebases its row into `.agent/knowledge/script_reference.md`.
- [ ] Add a size ratchet (line count of AGENTS.md) only if the owner wants it; otherwise leave to #258's pattern.

## Checkpoint
**Status**: complete
**When**: 2026-11-02 12:16 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the review's open actions are mechanism: design-doc update, re-measuring, verbatim move, coordination with issue 323; the two it routed to the owner, line target and size ratchet, are decided below from the recorded design and listed for veto; none changes the issue's scope)
**After**: issue-actions
**Decision**: proceed

The issue review (ebfb8718) found the issue well scoped; its dependency on issue 252 no longer holds (closed), the body's sizes are stale (AGENTS.md is 448 lines, 33,047 bytes), and "Documentation Accuracy" is now "Verify Before Claiming". Plan-task takes the six actions as plan inputs.

### Decisions made (owner may veto)
- Line target: under 200 lines, the reference point docs/design.md OQ-4 records; aim for the issue's 150 where it comes naturally — undoing it: a number in the plan.
- A size check on AGENTS.md (fails when it passes the budget) is added only if it is one short hook or an existing validator's line; otherwise no ratchet — undoing it: drop the check.
- The Script Reference table moves verbatim; a drift check against the scripts' own --help is out of scope — undoing it: a follow-up issue.
- Coordination with issue 323: whichever merges second rebases; 323's new row goes into the moved file if 259 lands first — undoing it: none.
