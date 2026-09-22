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

## Addendum — plan review findings folded in (2026-09-22)

The `## Plan Review` at `1906dd0` returned **needs-work** with seven
findings. The owner's plan checkpoint answered `proceed`, folding all seven
in and amending this plan on the branch to match. Where this addendum and
the Approach above disagree, the addendum wins.

1. **Keep the `## Implementation` entry template (finding 1).** Step 1 no
   longer *deletes* `SKILL.md` step 5's `action=implement` bullet. The
   entry template — including the `**PR**: #<M> at <sha>` /
   `**Branch**: <name> at <sha>` correlation line ADR-0013 requires — stays
   in `SKILL.md`, re-headed as **the dispatched implement pass** and moved
   to step 4's neighbourhood, and step 4's dispatch text tells the
   dispatched agent to write that entry shape. The dispatched agent commits
   its own work; the host still owns every push (step 10, unchanged).

2. **`skill_for()` classifies by `**Addressed**`, not ordinal position
   (finding 2).** An `## Implementation` entry carrying `**Addressed**`
   (a required field of `address-findings`' template,
   `.claude/skills/address-findings/SKILL.md:146`) is `address-findings`.
   Fallback when the field is absent: `implement` when no prior
   `## Implementation` entry has `**Status**: complete`, otherwise
   `address-findings`. Fixtures: first-vs-later, plus a double-failure
   retry (failed `implement` → retry → failed again must still route
   `**Phase**: implement`).

3. **`**Mode**: inline` keeps its meaning on takeover only (finding 3).**
   The field is not retired: a takeover of the implement pass still writes
   it as an informational marker, and `SKILL.md` says explicitly that no
   dispatcher reads it any more. Step 5 keeps its "row 27 fires for *any*
   phase, not only `implement`" wording verbatim.

4. **CI re-check before the merge checkpoint (finding 4).** After a triage
   that recorded `**CI**: pending`, the host re-checks CI before the merge
   checkpoint; a failure routes to `address-findings` (or a fresh
   `triage-reviews`) rather than being discovered inside `merge_pr.sh`'s
   entry-less failure path. Recorded in `SKILL.md` step 9, cross-referenced
   from step 11.

5. **Three more locations in the file list (finding 5).**
   `dispatch_phase.sh:215` (the unknown-skill error string gains
   `implement`), `dispatch_phase.sh:401` (the comment describing
   `**Mode**`-aware `Implementation` mapping), and
   `review_loop_lifecycle.md:90` ("dispatches or implements the…").

6. **ADR-0014 addendum is References-only (finding 6).** No Status-line
   note: a References entry naming issue #314 and the `SKILL.md` subsection
   that carries the never-list, following the #307 precedent for "a later
   change moved the authoritative text elsewhere".

7. **A resumed dispatch is recorded (finding 7).** The resumed phase's own
   entry records `**Dispatch**: resumed (agent <id>, resume <n> of 3)`;
   absence of the field means a fresh dispatch. This makes the never-list
   checkable from `progress.md` alone, across a `--resume` that loses the
   host's in-session phase→agent map. Recording only — no mechanical
   enforcement, per the owner's settled decision.

### Files to Change (superseding table)

| File | Change |
|------|--------|
| `.agent/scripts/dispatch_phase.sh` | Rows 10/26 drop `mode=inline`; `implement` case in `skill_task_line()`; `skill_for()` keys on `**Addressed**` with the no-prior-complete fallback; `:215` error string; `:401` comment |
| `.agent/scripts/tests/test_dispatch_phase.sh` | Rows 10/26/end-to-end fixtures; `skill_for()` `**Addressed**` / first-vs-later / double-failure fixtures; `implement` handoff fixture |
| `.claude/skills/run-issue/SKILL.md` | Step 4 (dispatchable list + the dispatched implement pass's entry template), step 5 (takeover only; `**Mode**` has no reader), step 7 (`## Decision summary`), step 9 (triage before CI + the CI re-check), step 11 (cross-reference), the agent-reuse subsection with `**Dispatch**:` |
| `.agent/knowledge/review_loop_lifecycle.md` | Diagram (line 12), "who writes what" row (line 29), and line 90's "dispatches or implements" |
| `.claude/skills/triage-reviews/SKILL.md` | `pending` added to the `**CI**` vocabulary |
| `docs/decisions/0014-in-process-phase-handoff.md` | References entry only (issue #314 + the `SKILL.md` subsection) |

### Sequencing note

A sibling branch for #300 (open) edits `SKILL.md`'s step 6 merge-refused
paragraph and step 11. Those paragraphs are touched here only to the
minimum the CI re-check cross-reference needs, so the later merge from main
stays clean.

## Addendum 2 — item 4: skip the PR-side re-review of an unchanged diff

Owner decision on the issue (2026-09-22 16:02Z) added a fourth item after
the plan review. After a clean pre-push `## Local Review (Pre-Push)`,
`publish` pushes exactly the commits that review named and the loop then
runs a full PR-mode `review-code <M>` on them — 5–8 minutes re-reading an
unchanged diff (measured on the #206 drive).

**Rule.** With `--pr draft|open`, when the newest entry is an approving
`## Local Review (Pre-Push)` whose SHA is the PR head — or an ancestor of
it with only bookkeeping files changed between (`merge_pr.sh`'s
`_only_bookkeeping_between` rule, #286: the issue's work-plans dir,
`ROADMAP.md`, `docs/ROADMAP.md`) — route to `triage-reviews` instead of
`review-code <M>`. Any code change since that review keeps the PR-mode
review. The `## Integrated Review` cites the pre-push entry as its local
source; `review_progress.sh sources` already correlates by head SHA.

**Design decision — `--head <sha>`, not a `gh` call inside `next`.** The
rule needs the PR head SHA and a git ancestry/diff check, and `next` today
takes only `--pr <state>` plus the timeline. Settled in favour of an
optional `--head <sha>` flag that the host passes from its step-2 PR probe
(extended with `headRefOid`), for three reasons:

- `next` keeps its "no `gh` call inside `next`, ever" contract (the script
  header states it), which is what makes the decision table testable from
  `--progress` fixtures with no network and no repo.
- The host already has the head: step 2 runs `gh pr list` every loop, so
  `headRefOid` costs nothing extra.
- Absent `--head`, the state routes exactly as it did before, so the change
  is additive and a host that forgets the flag loses the saving without
  breaking the loop.

The ancestry/bookkeeping test runs in bash against the issue's worktree
(`head_covers_review()`), so the Python decision table sees only
`HEAD_COVERED=1|0|unknown`. Every answer it cannot establish — no
worktree, unresolvable SHA, a non-bookkeeping path in the diff — is `0`,
which keeps the re-review; the saving is never taken on a guess.

**Files**: `.agent/scripts/dispatch_phase.sh` (`--head`,
`newest_correlation_sha()`, `head_covers_review()`, rows 13a/13b, header
comment), `.agent/scripts/tests/test_dispatch_phase.sh` (fixtures: clean
pre-push at head → `triage-reviews`; clean pre-push + later code commit →
`review-code`; needs-work pre-push unchanged; no-`--head` fallback; plus
two over a real sandbox repo for the bookkeeping-ancestor rule),
`.claude/skills/run-issue/SKILL.md` (steps 2 and 3, Overview diagram),
`.agent/knowledge/review_loop_lifecycle.md` (routing-rules list).
