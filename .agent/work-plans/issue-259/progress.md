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

## Plan Authored
**Status**: complete
**When**: 2026-11-02 12:18 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-259/plan.md` at `4d731111`

Move Script Reference, git-bug notes, GitHub CLI patterns, Build & Test and the worktree command blocks to knowledge files with pointers, one commit each, then a line-budget check and the design-doc update; expected size is near 205 lines before fallback trims reach under 200.

## Plan Review
**Status**: complete
**When**: 2026-11-02 12:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #259 — Trim AGENTS.md to policy + pointers; move reference tables to .agent/knowledge/
**Plan**: `.agent/work-plans/issue-259/plan.md` at `4d731111`
**Branch**: `feature/issue-259`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, doc moves plus one check; seven atomic commits is right-sized |
| Issue alignment | Good | Covers every move the issue lists, the three hard CLI rules in Boundaries, the adapter-file check and before/after measurement. Serves, as checked: "Goal "Know whether it works" (keeping the always-loaded instructions lean), `docs/design.md#instruction-layers`." — the README goal and the anchor exist. All six issue-review actions are taken up (re-baseline, design doc, verbatim move, 323 coordination, size check per the checkpoint) |
| File targeting | Needs work | Two references into moved text are not listed (finding 3) |
| Consequences | Needs work | The size estimate is about 20 lines low, so the plan as written ends at its own "stop and ask" branch (finding 1) |
| Principle alignment | Needs work | The line-budget check sits where no PR runs it (finding 2); the first fallback lever trims a pinned section (finding 5) |
| ADR compliance | Needs work | The ADR-0010 edit is permitted by ADR-0008; the plan should cite it instead of treating the edit as a departure (finding 4) |
| ROS conventions | N/A | Workspace plan |

Verified in the code, as asked:
- Pinned headings: the nine in the plan match `WORKSPACE_SECTIONS` in `.claude/hooks/session_start_project_layer.sh` exactly, and `test_session_start_layer.sh` asserts them; none of the moved sections is pinned.
- Readers of AGENTS.md (`git grep AGENTS.md` over `.agent/ .claude/ .github/ Makefile .pre-commit-config.yaml`, plus `docs/`): the plan's list is complete for tests and hooks. One further suite reads the path but not headings: `test_script_tests_hook_scope.sh` maps `AGENTS.md` to suites by path, so no change. The other hits (`merge_pr.sh` 687/826 and `cross_model_review.sh` 639 citing branch rules, `orchestrator/SKILL.md` 55 citing Ask First, `project_integration_audit.sh`, `discover_governance.sh`, test fixtures) refer to sections that stay or to the file as a whole. The two misses are prose pointers (finding 3).
- Size: measured section lengths (awk over `## ` headings) match the plan's Context. Applying the plan's own per-step targets: 448 − 47 (Script Reference 51 → 4) − 95 (GitHub CLI 101 → 6) + 2 (Boundaries lines) − 19 (Build & Test 28 → 9) − 60 (Worktree Workflow 80 → 20) = about 229, not 205-210. Step 6's levers (Skill Worktree Exception 12 → ~3, adapter table 7 → 1, References 10 → ~5) take off about 20 more, leaving about 209.

### Findings

1. **[Consequences]** (medium) After-size estimate is low by about 20 lines: the plan's per-step targets give ~229 after steps 1-5 and ~209 after all of step 6, so implementation would stop on an owner question. Which text to cut is mechanism, not the owner's budget question. Name more rule-free levers in the plan now and re-estimate. Examples: put the four new pointers in one pointer list (or the existing References section) instead of four `##` sections, which saves the heading and blank lines of each. Keep the four `make` targets the issue names, not six. Bring Worktree Workflow to ~12 lines. Keep the "stop and ask" only for cutting rule text.
2. **[Principle alignment]** (medium) "Enforce what matters, as simply as possible": `validate_workspace.py` runs only through `make validate` and `dashboard.sh`, not in CI and not as a hook. A PR that grows AGENTS.md past 200 lines would pass every gate. The dashboard would also report it as "Workspace configuration issue", and that validator otherwise checks only local setup. The `validate-documentation` job in `.github/workflows/validate.yml` already loops over `AGENTS.md`. One `wc -l` test there fails on the PR that breaks the budget, and it is the same size as the planned change. Put the check there, and add a `docs/design.md#rules` row for it (Enforced by `CI`) in step 8. If it stays in the validator, the plan needs a test case for it ("Test what breaks").
3. **[File targeting]** (low) Two missed references: `docs/design.md` line 427 cites `AGENTS.md`, "Worktree Entry", which step 5 moves to `WORKTREE_GUIDE.md`; repoint it in step 8. `.claude/skills/audit-workspace/SKILL.md` line 159 uses "AGENTS.md script table lists ..." as its example; repoint it with line 75 in step 1. `principles_review_guide.md` line 69 ("`AGENTS.md` worktree section") stays true for the trimmed section. It should name WORKTREE_GUIDE as the home of the command blocks.
4. **[ADR compliance]** (low) Answer to the planner's open question. Editing ADR-0010's pointer line is allowed. ADR-0017's Decision reads "Accepted ADRs are history: superseded, not edited, apart from ADR-0008 addendums". ADR-0008's Permitted list includes "Fixing broken links ... that don't change meaning". Once the section moves, "See `AGENTS.md` "git-bug-first Pattern"" is a broken pointer, so repointing it is an ADR-0008 fix and does not depart from the rule. `docs/design.md` line 684 ("none is edited here") is about the decision-register rewrite, not every edit. The design.md register row for 0008 says the same: "a references list or link and typo fixes". Precedent: 9ad62671 made ADR-0014's reference a pointer only. Add ADR-0008 to the ADR table as the authority, drop "at the host's instruction" from step 2, and remove the first Open Question.
5. **[Principle alignment]** (low) Step 6's first lever condenses "Skill Worktree Exception", which sits inside the pinned Issue-First Policy section. The SessionStart hook renders that section into project sessions, and `/onboard-project` runs there with `--type project --project <name>`. Use levers outside the nine pinned sections first. If this one is still needed, keep the onboard-project sentence.

### Summary

The plan is sound in shape: moves, pointers, pinned headings and repoints are correct, and the reader list it gives is complete for tests and hooks. Two things need fixing before implementation. It will not reach its 200-line target with the levers it names. Its size check sits in a validator no PR runs. Both are small plan edits.

### Recommended Actions

- [ ] Re-estimate the after-size from the per-step targets (~229, then ~209) and add rule-free levers (one pointer list instead of four sections, four `make` targets, tighter Worktree Workflow) so the plan reaches under 200 without an owner stop
- [ ] Move the line-budget check to the `validate-documentation` CI job (or add a test if it stays in `validate_workspace.py`), and add a `docs/design.md#rules` row for it in step 8
- [ ] Add `docs/design.md` line 427 ("Worktree Entry" citation) to step 8 and `audit-workspace/SKILL.md` line 159 to step 1
- [ ] Cite ADR-0008 for the ADR-0010 pointer fix and drop that Open Question
- [ ] Order step 6 levers so pinned sections are trimmed last, keeping the onboard-project sentence
