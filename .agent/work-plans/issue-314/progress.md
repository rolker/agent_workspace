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

## Plan Authored
**Status**: complete
**When**: 2026-09-22 11:53 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-314/plan.md` at `6716c8f`

Four steps: (1) dispatch `implement` instead of running it inline (dispatch_phase.sh rows 10/26 drop mode=inline, row 27 keeps it; skill_for() reclassifies by first-Implementation-entry instead of Mode; fixtures, SKILL.md steps 4/5, review_loop_lifecycle.md); (2) triage-reviews may start once review sources are in even while CI runs (SKILL.md step 9; triage-reviews' CI vocab gains "pending"); (3) PR body's decision summary heading must be exactly `## Decision summary` (SKILL.md step 7); (4) agent reuse for repeat phases as its own step, with a short ADR-0014 addendum (ADR-0008 mechanism) for the reuse policy and never-list.

## Plan Review
**Status**: complete
**When**: 2026-09-22 11:57 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #314 — run-issue: dispatch implement, triage before CI, reuse running agents for repeat phases (wall-clock fixes)
**Plan**: `.agent/work-plans/issue-314/plan.md` at `6716c8f`
**Branch**: `feature/issue-314`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four small edits across six files; step 4 already carved out as separable per the owner's checkpoint. Right size for one PR. |
| Issue alignment | Good | All three issue items plus the "also in scope" heading-level fix are covered, and the four checkpoint constraints (lifecycle doc, #300 sequencing, ADR-0014 addendum, reuse as its own step) are all carried into the approach. |
| File targeting | Needs work | Three stale in-repo references are outside the file list (finding 5); SKILL.md step 5's deletion removes the only documented `## Implementation` entry template with nothing named to replace it (finding 1). |
| Consequences | Needs work | Step 2 is correctly text-only at the dispatcher level, but creates an unrouted CI-fails-after-triage case (finding 4); `**Mode**` loses its only reader and the plan doesn't say what happens to the field (finding 3). |
| Principle alignment | Needs work | "Test what breaks": the `skill_for()` heuristic has an untested failure mode (finding 2). "Capture decisions": step 4's never-list is unauditable as written (finding 7). |
| ADR compliance | Good | ADR-0013 reasoning is right (`## Implementation` keeps its shape); ADR-0014 addendum is the right vehicle; one shape nit on the ADR-0008 letter (finding 6). |
| ROS conventions | N/A | Workspace-only change. |

### Findings

1. **[Approach — step 1, must-fix]** Deleting SKILL.md step 5's `action=implement` bullet removes the only place the post-plan `## Implementation` entry's shape is documented — including the `**PR**: #<M> at <sha>` / `**Branch**: <name> at <sha>` correlation line. That line is required: `## Implementation` is a PR/branch-correlated ADR-0013 type, and without it the entry's correlation parses null, which breaks `round_count()`'s branch correlation and `merge_pr.sh`'s head-vs-review correlation. A dispatched `implement` agent receives only `task=` and `exit_contract=`, and the exit contract names the heading and `**Status**` only — so nothing tells it to write the correlation line. The plan should name where the dispatched implement's entry template lives (keep the template in step 4/5 re-headed as "the dispatched implement pass", or add it to the handoff text), and should state that the dispatched agent commits its work while the host still owns the push (step 10).

2. **[Approach — `skill_for()`, must-fix]** "First `## Implementation` entry in the timeline" misroutes the retry-after-failure case that step 1 itself makes reachable: a failed dispatched `implement` writes a `## Implementation` entry with `**Status**: failed`; row 3 routes `phase=implement`; the owner answers `retry`; row 26 re-dispatches `implement`, which writes a *second* `## Implementation` entry. If that one also fails, a prior `## Implementation` entry now exists, so the ordinal heuristic classifies it as `address-findings` and the next retry dispatches `address-findings` — a phase with no review entry to address. Two fixes, either of which is more robust than ordinal position: (a) a positive signal — `address-findings`' entry template makes `**Addressed**: <source entry type> at <sha>` a required field (`.claude/skills/address-findings/SKILL.md:146`), so `**Addressed**` present → `address-findings`; (b) narrow the ordinal test to "no prior `## Implementation` entry with `**Status**: complete`" (a review, and therefore an `address-findings` pass, can only follow a completed implementation — row 3 absorbs every partial/failed entry into a checkpoint first). Best is (a) with (b) as the fallback for a failed entry that omitted `**Addressed**`. Add the double-failure fixture alongside the first-vs-later pair the plan already lists. On the alternative the review brief raises — keying on an immediately preceding `**After**: plan` / `**Decision**: proceed` checkpoint — it has the same retry flaw (on a retry the preceding entry is the `phase-failed` checkpoint), though that checkpoint's own `**Phase**: implement` would be a usable signal if a positional rule is kept.

3. **[Consequences — `**Mode**`, should-fix]** Row 27 (`dispatch_phase.sh:519`) emits `mode=inline` for *any* taken-over phase, not only `implement`, and SKILL.md step 5 already says so correctly — the plan's step-5 edit must not compress that into "takeover = implement". Separately, `skill_for()` was the only reader of `**Mode**` in the dispatcher (`:419`); after the reclassification nothing consumes it. The plan should say explicitly whether a takeover-of-implement entry still writes `**Mode**: inline` as an informational marker (fine, but then say "no dispatcher reads it") or whether the field is retired — otherwise step 5 documents a required field with no consumer.

4. **[Consequences — step 2, should-fix]** Confirmed text-only at the dispatcher level: `next`'s only external input is `--pr <state>` (`none|draft|open|merged`); no row keys on CI, so no fixture or table change is needed. But triaging with CI pending opens a path the loop cannot route: CI fails *after* an `## Integrated Review` recorded `**CI**: pending` and the owner answered `merge`. `merge_pr.sh` then fails its CI wait after a *passing* gate, which records no merge entry (`merge_pr.sh:889-890`, the entry-less caveat in SKILL.md step 11), so `next` has no newest entry to route on and there is no `checkpoint:merge-refused` re-route. Add a line to step 9 or step 11: before the merge checkpoint the host re-checks CI, and a failure routes to `address-findings` (or a fresh `triage-reviews`) rather than being discovered inside `merge_pr.sh`'s entry-less failure path.

5. **[File targeting, low]** Three stale references outside the plan's file list: `dispatch_phase.sh:215`'s unknown-skill error string ("expected one of review-issue, plan-task, review-plan, review-code, triage-reviews, address-findings" — `implement` missing once step 1 adds its `skill_task_line()` case); `dispatch_phase.sh:401`'s comment ("`Implementation` is mode-aware: `**Mode**: inline` names the inline implementation pass"); and `review_loop_lifecycle.md:90` ("it enters the worktree, calls `next`, dispatches or implements the…"), beyond the line-12 diagram and line-29 table row the plan names.

6. **[ADR compliance, low]** ADR-0008's permitted list is ADR→ADR: a Status-line note about a *related ADR*, or a References section *listing related ADRs*. A Status-line note pointing at `SKILL.md` is outside that letter. ADR-0014's own References already carries non-ADR entries (issues #269/#276/#307, the fork digest), and the #307 entry is the exact precedent for "a later change moved the authoritative text elsewhere". Recommend the References entry alone (issue #314 + the `SKILL.md` subsection that carries the never-list) and dropping the Status-line note, or keeping it strictly navigational.

7. **[Principle alignment — step 4, should-fix]** The agent-reuse step names no recorded fact, so its own never-list is unfalsifiable: "after ~3 resumes of the same agent" and "not after a merge from main landed" can only be checked against the host's in-session phase→agent map, and SKILL.md step 12 is explicit that nothing lives outside `progress.md` — after `/run-issue <N> --resume` (or any host restart) the map is gone and the resume count is unrecoverable, so the policy silently stops applying. A minimal testable contract would fix that without adding mechanical enforcement: the reused phase's own entry records how it was dispatched, e.g. `**Dispatch**: resumed (agent <id>, resume 2 of 3)` vs. its absence for a fresh dispatch, so a reader (and a later reviewer) can count resumes and see whether a reuse crossed the never-list. This is *recording*, not enforcement — it does not re-open the owner's settled decision that the guardrails stay prose-only.

### Summary

The plan is correctly scoped and its three mechanical items are verified against current source. Two items need work before implementation: the dispatched `implement` pass loses its documented entry shape (and with it the correlation line ADR-0013 requires), and the `skill_for()` ordinal heuristic misroutes a second consecutive implement failure — both are small edits to the plan, not a rethink. Step 4's reuse policy should name one recorded field so its never-list is auditable.

### Recommended Actions

- [ ] Step 1: name where the dispatched `implement` entry template lives (correlation line included) instead of only deleting step 5's bullet; state that the dispatched agent commits and the host pushes
- [ ] Step 1: discriminate `implement` vs. `address-findings` by `**Addressed**` (present → address-findings), with "no prior *complete* `## Implementation`" as the fallback; add a fixture for a second consecutive failed `implement`
- [ ] Step 1: say what happens to `**Mode**: inline` once `skill_for()` stops reading it; keep step 5's "row 27 fires for any phase" wording
- [ ] Step 2: add the CI-fails-after-a-pending-triage route (re-check CI before the merge checkpoint; route a failure to address-findings)
- [ ] Add `dispatch_phase.sh:215` (error string), `dispatch_phase.sh:401` (comment) and `review_loop_lifecycle.md:90` to the file list
- [ ] Step 4: name one recorded marker for a resumed dispatch so the never-list is auditable across a `--resume`
- [ ] Step 4: prefer a References-only ADR-0014 addendum (per the #307 precedent) over a Status-line note pointing at a skill file

## Checkpoint
**Status**: complete
**When**: 2026-09-22 12:01 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed, folding the seven plan-review findings into the implementation (keep the `## Implementation` template incl. the correlation line, re-headed as the dispatched pass; classify address-findings by the `**Addressed**` field with "no prior complete Implementation" fallback plus a double-failure fixture; say what happens to `**Mode**: inline` and keep "row 27 fires for any phase"; host re-checks CI before the merge checkpoint after a pending-CI triage; a resumed dispatch is recorded in the phase's entry; add dispatch_phase.sh:215/:401 and review_loop_lifecycle.md:90 to the file list; References-only ADR-0014 addendum). The plan is amended on the branch to match. Per the owner's orchestrator rule the implement pass is dispatched to a background agent, not run inline by the host.
