---
issue: 314
---

# Issue #314 — run-issue: dispatch implement, triage before CI, reuse running agents for repeat phases (wall-clock fixes)

## Issue Review
**Status**: complete
**When**: 2026-09-22 11:38 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #314

### Scope Assessment

**Well-scoped?** Mostly. All three items touch the same two files
(`.claude/skills/run-issue/SKILL.md`, `.agent/scripts/dispatch_phase.sh`)
plus `test_dispatch_phase.sh` fixtures, so bundling them is reasonable
under "improve incrementally." Items 1 and 2 are narrow (decision-table
`mode=` wording, a wait-condition change in step 9) and verified against
the current script/skill text — both match what's actually in
`dispatch_phase.sh` (rows 10/26/27, lines 492/515) and `SKILL.md` step 9
today. Item 3 (resume a running sub-agent for repeat phases) is a
materially different kind of change: a new host-side mechanism with no
decision-table hook and no described test coverage, versus items 1-2's
mechanical script edits. Worth treating as separable if it turns out
slower to land than the other two.

**Right repo?** Yes — pure workspace tooling (`run-issue` loop internals).

**Dependencies**: `feature/issue-300` (open, not yet merged; local
worktree `worktrees/workspace/issue-workspace-300`) edits the same
`SKILL.md` sections this issue's step 9/11 neighborhood touches — the
deferred-suggestion-boxes paragraph in step 6 and the merge-gate wording
in step 11 (the issue text says "steps 10 and 11"; the actual overlap is
step 6's merge-refused paragraph and step 11, confirmed via `git diff
main..feature/issue-300 -- .claude/skills/run-issue/SKILL.md`). Not a
blocker, but a real textual-overlap risk: merge or rebase onto #300
before #314's final review-code/merge so the diff being reviewed isn't
stale against #300's landed wording.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| A change includes its consequences | Action needed | `.agent/knowledge/review_loop_lifecycle.md` documents `implement (inline)` in its overview line and in the phase/entry-type table (`implement (inline, or a dispatched address-findings)` -> `## Implementation`). Item 1 makes both stale once `implement` is dispatched like every other phase, but the issue's "Fixtures" note only lists `test_dispatch_phase.sh`, not this doc — and the review guide's own consequences map lists this file under "A phase's entry type... -> also update." |
| Capture decisions, not just implementations | Watch | Item 3 introduces a new dispatch-reuse policy (when to resume vs. always dispatch fresh) that isn't captured anywhere but `SKILL.md` prose. ADR-0014 ("In-process phase handoff") already governs "one dispatch path... one driver per issue" for this exact area; ADR-0008 permits addendums without a full supersede. A short ADR-0014 addendum recording the reuse policy (and its "never" list) would let the rationale survive outside step-by-step skill text. |
| Enforcement over documentation | Watch | Item 3's guardrails ("never round 1, across issues, after ~3 resumes, or after a merge from main") are prose-only; nothing in `dispatch_phase.sh` mechanically prevents the host from over-reusing an agent. May be acceptable given the host is the only actor here, but flagging since "enforcement over documentation" is a named principle. |
| The workspace serves the product | Watch | Framed and justified as wall-clock savings (5-8 min reorientation per phase) rather than product delivery, consistent with the owner's stated priority in the issue. Item 3 is the more speculative piece of the three (new mechanism, unproven savings) — fine as an experiment but worth watching if it doesn't pay off. |
| Only what's needed / Improve incrementally | OK | Small, targeted edits to existing files; no new files beyond fixture updates. |
| Workspace vs. project separation | OK | No project-specific content introduced. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0014 — In-process phase handoff | Yes | Directly triggered (touches `dispatch_phase.sh`, `run-issue` SKILL.md, a phase's task-line/entry-type/model tier). Key requirement ("one dispatch path... one driver per issue") is respected by item 3's stated exclusions, but the ADR itself isn't proposed for an addendum despite this being exactly the kind of decision ADR-0001/0008 ask to capture in the record, not just in skill prose. |
| 0013 — progress.md entry-type vocabulary | Touched, not violated | No new entry types introduced; `## Implementation` keeps its shape whether dispatched or inline. OK. |
| 0008 — Cross-reference addendums | Available mechanism | Would be the right vehicle for the ADR-0014 note above (status-line + References addition, no supersede needed). |

### Consequences

- `.agent/knowledge/review_loop_lifecycle.md` (overview line and phase/entry-type table) needs updating alongside `SKILL.md` and `dispatch_phase.sh` for item 1 — currently missing from the issue's file list.
- Confirmed accurate: `merge_pr.sh` does grep the literal string `## Decision summary` (line 760-761), so the "Also in scope" item's fix (host copies the sub-agent's decision-summary heading at level 2, not renested at level 3) is correctly scoped.

### Recommendations

- Update `review_loop_lifecycle.md`'s `implement (inline)` references in the same PR as item 1, not as a follow-up.
- Sequence #314's final review/merge after #300 lands (or rebase early) since both edit the same `SKILL.md` neighborhood (step 6/11).
- Consider a short ADR-0014 addendum (ADR-0008 mechanism) recording the sub-agent-reuse policy, including the "never" list, so it isn't only recoverable from `SKILL.md` prose.
- If item 3 (agent reuse) proves harder to land than items 1-2, split it into a follow-up issue/PR rather than holding the two mechanical fixes hostage to it.

### Actions
- [ ] `.agent/knowledge/review_loop_lifecycle.md` documents `implement (inline)` in its overview line and in the phase/entry-type table (`implement (inline, or a dispatched address-findings)` -> `## Implementation`). Item 1 makes both stale once `implement` is dispatched like every other phase, but the issue's "Fixtures" note only lists `test_dispatch_phase.sh`, not this doc — and the review guide's own consequences map lists this file under "A phase's entry type... -> also update."
- [ ] Update `review_loop_lifecycle.md`'s `implement (inline)` references in the same PR as item 1, not as a follow-up.
- [ ] Sequence #314's final review/merge after #300 lands (or rebase early) since both edit the same `SKILL.md` neighborhood (step 6/11).
- [ ] Consider a short ADR-0014 addendum (ADR-0008 mechanism) recording the sub-agent-reuse policy, including the "never" list, so it isn't only recoverable from `SKILL.md` prose.
- [ ] If item 3 (agent reuse) proves harder to land than items 1-2, split it into a follow-up issue/PR rather than holding the two mechanical fixes hostage to it.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 11:47 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed to plan-task with the review notes carried in: update review_loop_lifecycle.md's "implement (inline)" references in the same PR; sequence the final review/merge after #300 (merge from main first; overlap is step 6's merge-refused paragraph); a short ADR-0014 addendum for the agent-reuse policy incl. the never-list; keep agent reuse as its own plan step so it can be split off if it drags.
