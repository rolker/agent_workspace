# Plan: run-issue: dispatch implement, triage before CI, reuse running agents for repeat phases (wall-clock fixes)

## Issue

https://github.com/rolker/agent_workspace/issues/314

## Context

Three wall-clock fixes to `/run-issue`, all landing in
`.claude/skills/run-issue/SKILL.md` and `.agent/scripts/dispatch_phase.sh`
(plus `test_dispatch_phase.sh` fixtures): (1) dispatch `implement` instead of
running it inline, (2) let `triage-reviews` start once review sources are in
even while CI is still running, (3) resume a running sub-agent for repeat
phases on the same issue. The owner's issue-actions checkpoint (`proceed`,
recorded in `## Checkpoint` above) added four constraints: update
`review_loop_lifecycle.md`'s `implement (inline)` references in the same PR;
sequence the final review/merge after #300 lands (merge from main first);
add a short ADR-0014 addendum (ADR-0008 mechanism) for the agent-reuse
policy including its never-list; keep agent reuse as its own step so it can
split off if it drags.

Verified against current source: `dispatch_phase.sh`'s `skill_entry_type()`
and `skill_model()` already have an `implement` case (`Implementation`,
`opus`) but `skill_task_line()` does not — dispatching `implement` today
would hit the `unknown --skill` error path. Also, `skill_for()` (used by row
3 to name the failed phase at a `checkpoint:phase-failed`) currently
classifies a failed `## Implementation` entry as `implement` vs.
`address-findings` purely by `**Mode**: inline` — a field only the inline
path writes. Once `implement` is dispatched, its entries won't carry that
field, so this classifier needs a different signal or row 3 will
misclassify every failed initial-implement dispatch as `address-findings`.

## Approach

1. **Dispatch `implement` instead of inline** (script + fixtures + skill
   text + lifecycle doc)
   - `dispatch_phase.sh`: row 10 (`checkpoint plan / proceed`, line ~492)
     and row 26 (`checkpoint phase-failed / retry` when `**Phase**:
     implement`, lines ~513-517) drop `mode="inline"` — `implement` becomes
     a plain `emit("implement", ...)` like every other skill token. Row 27
     (takeover, line ~519) is untouched.
   - `skill_task_line()`: add an `implement` case — no `/implement` slash
     command exists, so the printed task line reads `"implement the plan at
     .agent/work-plans/issue-$issue/plan.md on this branch"`.
   - `skill_for()`: replace the `**Mode**: inline` check with "is this the
     first `Implementation`-base entry in the timeline?" — `address-findings`
     can only ever follow an existing `## Implementation` entry (it responds
     to a review that found something), so the first such entry on the
     timeline is always the post-plan `implement` pass, dispatched or not.
     This keeps row 3's `**Phase**` correct for a failed dispatched
     `implement` without inventing a new field.
   - `test_dispatch_phase.sh`: rows 10/26 lose their `mode=inline`
     assertions (row 10 becomes a plain `implement` action; row 26's
     "retry on the inline implementation pass" case becomes "retry on
     implement -> implement, no mode="). Row 27's takeover assertion is
     unchanged. Add a fixture for the `skill_for()` change: a failed
     `## Implementation` entry with no prior `## Implementation` entry on
     the timeline routes `checkpoint:phase-failed`'s `phase=` to
     `implement`; a failed one with a prior `## Implementation` entry
     routes to `address-findings`. Update the end-to-end timeline test
     (`step "$TL" none implement mode=inline`) to drop the `mode=inline`
     pattern.
   - `SKILL.md` step 4: add `implement` to the list of dispatchable skills
     (currently `review-issue, plan-task, review-plan, review-code,
     address-findings, triage-reviews`); the `mode=inline` check now only
     covers row 27 (takeover).
   - `SKILL.md` step 5: delete the `action=implement` bullet (rows 10/26 no
     longer produce `mode=inline`); keep only the takeover bullet, and note
     that a takeover of `implement` still writes `**Mode**: inline` (that
     part of the contract is unchanged).
   - `.agent/knowledge/review_loop_lifecycle.md`: phase-order diagram
     (`implement (inline)` -> `implement`) and the "who writes what" table
     row (`implement (inline, or a dispatched address-findings)` /
     `the host (**Mode**: inline) or address-findings` -> a plain
     `implement` row, dispatched like the others; keep a one-line note that
     a `checkpoint:phase-failed` takeover still runs any phase inline,
     `implement` included).

2. **Triage before CI finishes** (skill text only)
   - `SKILL.md` step 9: change the wait condition from "no checks pending"
     (CI + Copilot) to "review sources are in" — Copilot posted its review
     (or is confirmed absent from the check list) and any requested human
     reviews are in — with CI allowed to still be running. Keep the
     Copilot-quota-exhausted carve-out as is.
   - Add a line: `triage-reviews`'s `## Integrated Review` entry records
     `**CI**: pending` when CI hasn't settled; `merge_pr.sh` still gates the
     actual merge on CI regardless (unchanged, #300's job).
   - Consequence: `.claude/skills/triage-reviews/SKILL.md`'s `**CI**` field
     vocabulary (currently `all-pass | failures-noted`, step documenting the
     `### CI Status` section) needs a third value, `pending`, so the entry
     this step now produces is within the documented vocabulary. Small,
     same-neighborhood edit — included here rather than left as a gap.

3. **Decision summary heading level** (skill text only)
   - `SKILL.md` step 7 (publish): state explicitly that the PR body's
     decision-summary section must be `## Decision summary` (level 2, not
     re-nested under a sub-agent's own heading) — `merge_pr.sh` greps that
     literal string (confirmed at `merge_pr.sh` lines 760-761). This fixes
     the PR #308 regression noted in the issue.

4. **Agent reuse for repeat phases** (own step — split off if it drags)
   - `SKILL.md`: new subsection (after step 4, "Dispatching a phase") — the
     host keeps a per-issue phase -> agent-id map for this drive. Before
     dispatching `review-code` round >= 2, `address-findings` round >= 2, or
     a repeat `triage-reviews` on the same PR, check the map: if an agent
     for that phase is still live, resume it via `SendMessage` with the
     normal handoff block plus "you already hold this branch — read only
     progress.md entries newer than your last one"; if the agent is gone,
     fall back to a fresh dispatch as today.
   - Never reuse: round 1 of any review, across issues, after ~3 resumes of
     the same agent, or after a merge from main landed on the branch (the
     resumed agent's view of the diff would be stale).
   - Exit contract and `--check-exit` are unchanged — a resumed agent is
     held to the same contract as a fresh one.
   - `docs/decisions/0014-in-process-phase-handoff.md`: a short addendum
     (ADR-0008 mechanism — Status-line note + References entry, not a
     rewrite of the Decision or Consequences) pointing at the reuse policy
     and where it's authored (`SKILL.md`'s new subsection, which carries the
     never-list). Kept navigational per ADR-0008's own rule ("if someone
     reads only the edited ADR... will they get a misleading picture?" —
     no, since the substantive policy lives in `SKILL.md`, not restated
     here).

Sequencing: land steps 1-3 first (mechanical, low risk); step 4 is separable
and lands after, or splits into its own issue/PR if it slows the other three
down (owner's stated preference). Before the final pre-push `review-code`
and merge, merge `main` into this branch (step 8 of `SKILL.md`) — #300 is
expected to have landed by then and touches the same `SKILL.md`
neighborhood (step 6's merge-refused paragraph); if #300 is still open when
this branch is ready, wait for it rather than reviewing against a diff that
will immediately go stale.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/dispatch_phase.sh` | Rows 10/26 drop `mode=inline`; add `implement` to `skill_task_line()`; `skill_for()` reclassifies by "first Implementation entry" instead of `**Mode**` |
| `.agent/scripts/tests/test_dispatch_phase.sh` | Update rows 10/26/end-to-end fixtures; add `skill_for()` first-vs-later `## Implementation` fixture |
| `.claude/skills/run-issue/SKILL.md` | Step 4 (add `implement` to dispatchable list), step 5 (drop `action=implement` inline bullet), step 7 (`## Decision summary` heading level), step 9 (triage before CI), new agent-reuse subsection |
| `.agent/knowledge/review_loop_lifecycle.md` | Phase-order diagram and "who writes what" table: `implement (inline)` -> dispatched `implement` |
| `.claude/skills/triage-reviews/SKILL.md` | Add `pending` to the `**CI**` field vocabulary |
| `docs/decisions/0014-in-process-phase-handoff.md` | Addendum: Status-line note + References entry for the agent-reuse policy |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | `review_loop_lifecycle.md` and `triage-reviews` SKILL.md are included alongside the two files the issue named, closing the gap the Issue Review flagged |
| Capture decisions, not just implementations | Agent-reuse policy gets an ADR-0014 addendum, not just `SKILL.md` prose, per the owner's checkpoint decision |
| Enforcement over documentation | Reuse guardrails stay prose-only (host is the sole actor; no mechanical lock) — same posture the Issue Review flagged as a "Watch," accepted as-is per the owner's proceed decision |
| Only what's needed / Improve incrementally | Each of the four items is a small, targeted edit to existing files; no new scripts or entry types |
| Workspace vs. project separation | Pure workspace-tooling change; no project-repo content |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0014 — In-process phase handoff | Yes | Steps 1 and 4 both touch the handoff contract; step 4 adds the addendum this ADR was missing per the Issue Review |
| 0013 — progress.md entry-type vocabulary | Touched, not violated | No new entry type; `## Implementation` keeps its shape whether dispatched or inline (only the `**Mode**` field usage changes) |
| 0008 — Cross-reference addendums | Yes (mechanism used) | The ADR-0014 addendum is a Status-line note + References entry only — no rewording of ADR-0014's Decision or Consequences |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `dispatch_phase.sh` rows 10/26/`skill_for()` | `test_dispatch_phase.sh` fixtures | Yes — step 1 |
| `implement` dispatch path | `review_loop_lifecycle.md` phase order + table | Yes — step 1 |
| `triage-reviews`'s `**CI**` vocabulary (step 2) | `triage-reviews` SKILL.md's documented vocab | Yes — step 2 |
| ADR-0014 addendum | `docs/decisions/0014-*.md` Status line + References | Yes — step 4 |

## Open Questions

- None blocking. One judgment call made without a checkpoint: `skill_for()`'s
  reclassification (first-`Implementation`-entry heuristic) — not asked for
  literally in the issue text, but required for row 3 to still route a
  failed dispatched `implement` to `checkpoint:phase-failed` with the
  correct `**Phase**` once `**Mode**: inline` no longer marks it. Flagging
  here rather than silently patching a gap the issue didn't name.

## Estimated Scope

Single PR, four commits (one per approach step) on `feature/issue-314`.
Step 4 (agent reuse) splits into a follow-up issue/PR if it proves slower to
land than steps 1-3, per the owner's stated preference.
