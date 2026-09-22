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

## Implementation
**Status**: complete
**When**: 2026-09-22 12:18 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Plan**: `.agent/work-plans/issue-314/plan.md` at `8c4c92a`
**Branch**: feature/issue-314 at 8c4c92a
**Commits**: 1e2c647, 4ee80c6, 101df72, e13fcdc, 8c4c92a

The post-plan implement pass, dispatched (host stays orchestrator). All
seven `## Plan Review` findings folded in per the owner's plan checkpoint,
plus item 4 added to the issue by owner decision mid-pass.

- `1e2c647` — plan addendum: the seven findings, superseding the Approach
  where they disagree.
- `4ee80c6` — `dispatch_phase.sh`: rows 10/26 drop `mode=inline` (row 27
  keeps it); `skill_task_line()` gains an `implement` case and the
  unknown-skill error string lists it; the `implement` exit contract names
  `progress_append.sh`, the `**PR**`/`**Branch**` correlation line, and
  that the agent commits while the host pushes; `skill_for()` keys on
  `**Addressed**` with a "no prior COMPLETE `## Implementation`" fallback.
  Fixtures: first-vs-later, double-failure retry, takeover marker,
  `implement` handoff.
- `101df72` — `run-issue` SKILL.md: step 4 dispatchable list + the
  dispatched implement pass's entry template; step 5 takeover-only and
  "no dispatcher reads `**Mode**`"; step 7 pins `## Decision summary` at
  level 2; step 9 waits for review sources not CI, records `**CI**:
  pending`, and re-checks CI before the merge checkpoint (step 11 points
  back at it); new step 4a for agent reuse, its never-list, and the
  `**Dispatch**: resumed (agent <id>, resume <n> of 3)` record.
  `triage-reviews` SKILL.md gains `pending` in its `**CI**` vocabulary.
- `e13fcdc` — `review_loop_lifecycle.md` diagram, "who writes what" table
  (one row per `## Implementation` writer) and the `/run-issue` paragraph;
  ADR-0014 References-only addendum pointing at step 4a.
- `8c4c92a` — item 4: `next --head <sha>`; an approving pre-push review
  whose SHA still covers the PR head routes to `triage-reviews` instead of
  a `review-code <M>` on an unchanged diff (merge_pr.sh's #286 bookkeeping
  rule, run in bash so the table sees only 1/0/unknown). Host side in
  SKILL.md steps 2/3; plan Addendum 2 records the `--head`-vs-`gh` design
  decision.

Tests: `test_dispatch_phase.sh` 90 passed / 0 failed;
`run_script_tests.sh` all 23 suites passed in 54s. Not pushed — the host
owns every push.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 12:28 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-314 at `6fd4249`
**Base**: main
**Depth**: Deep (reason: 483 changed lines outside work-plans across 6 files, incl. the enforcement script `dispatch_phase.sh`)
**Must-fix**: 4 | **Suggestions**: 6
**Round**: 1 | **Ship**: continue — round 1: 4 must-fix, one of them a design question (item 4's routing state is unreachable in the documented flow)

### Findings
- [x] (must-fix) rows 13a/13b require an approved `## Local Review (Pre-Push)` as the *newest* entry while `--pr` is draft/open, a state the documented host flow never presents: the publish `## Checkpoint` is written before `publish` runs, so the post-publish `next` sees that Checkpoint and row 17 already routes to `triage-reviews` (pinned by timeline A, `test_dispatch_phase.sh:364-367`) — the redundant re-review item 4 removes was already skipped, and SKILL.md's "omitting `--head` ... the redundant re-review returns" describes a path the table does not take — `.agent/scripts/dispatch_phase.sh:634-646`, `.claude/skills/run-issue/SKILL.md:128-130` (deferred: dropped by owner decision 2026-09-22: item 4 removed (revert of 8c4c92a))
- [x] (must-fix) the claim that "`review_progress.sh sources` already correlates the two by head SHA, so nothing extra is needed" is false in exactly the bookkeeping-ancestor case row 13a newly admits: `review_progress.sh:364-366` drops any local entry whose short correlation SHA differs from the head, so `triage-reviews` would run with zero local sources after the PR-side review was skipped — `.claude/skills/run-issue/SKILL.md:130-133` (deferred: dropped by owner decision 2026-09-22: item 4 removed (revert of 8c4c92a))
- [x] (must-fix) `BOOKKEEPING_RE` is broader than the merge-gate rule it cites — every path under `.agent/work-plans/` vs merge_pr.sh's exact `issue-<N>/progress.md`, `ROADMAP.md`, `docs/ROADMAP.md` — so `next` can skip the PR-side re-review on a head the merge gate then calls stale — `.agent/scripts/dispatch_phase.sh:220`
- [x] (must-fix) the pre-merge CI re-check dispatches `address-findings` off the decision table and names no entry recording the CI failure, so a resume re-derives `checkpoint:merge` and walks back into the failing merge — `.claude/skills/run-issue/SKILL.md:462-472`
- [x] (suggestion) `HEAD_COVERED=0` conflates "code changed since" with "could not check" (no worktree, unresolvable SHA), but row 13b's reason line asserts the first unconditionally — `.agent/scripts/dispatch_phase.sh:643-645` (deferred: dropped by owner decision 2026-09-22: item 4 removed (revert of 8c4c92a))
- [x] (suggestion) the header still says "`--pr` is the only non-timeline input", contradicted by its own new `--head` paragraph and by the lifecycle doc's "its two non-timeline inputs" — `.agent/scripts/dispatch_phase.sh:46`
- [x] (suggestion) the SHA prefix-equality test runs before any git validation, so a short reviewed SHA that prefixes an unrelated head reports "covered" unverified; merge_pr.sh deliberately resolves short SHAs first and treats an ambiguous prefix as failure — `.agent/scripts/dispatch_phase.sh:235` (deferred: dropped by owner decision 2026-09-22: item 4 removed (revert of 8c4c92a))
- [x] (suggestion) the comment calls `**Addressed**` "a required field of address-findings own entry template", but that SKILL.md marks only the `**Branch**`/`**PR**` line required, nothing validates it, and a present-but-empty value silently takes the fallback path — `.agent/scripts/dispatch_phase.sh:497-499`
- [x] (suggestion) the dispatched implement pass's exit contract requires the `**PR**`/`**Branch**` correlation line, but `--check-exit` only counts entries and reads `**Status**`, so a missing correlation line still reports `status=OK` — `.agent/scripts/dispatch_phase.sh:306` vs `:365-385`
- [x] (suggestion) step 4a permits resuming the *reviewer* for `review-code` round >= 2, which trades away the cold independent read the pre-push loop is built on (not a re-opening of the settled prose-vs-enforcement question) — `.claude/skills/run-issue/SKILL.md:228-247`

## Implementation
**Status**: complete
**When**: 2026-09-22 12:44 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-314 at fc42fc3
**Addressed**: Local Review (Pre-Push) at `6fd4249`
**Dispatch**: resumed (implementer, resume 1 of 3)
**Commits**: 672866c, 7b986d9, fc42fc3

Round 1 of the pre-push review. Six of the ten boxes are addressed; the
four item-4 findings are held pending the owner's decision on whether
item 4 stays (see Deferred below) and are left unticked.

`672866c` commits the reviewer's own corrected entry unchanged — the
adversarial specialist returned late, the reviewer rewrote and staged the
entry, and this pass's in-flight edits had blocked its commit hook.

### Actions
- [x] (must-fix) `BOOKKEEPING_RE` wider than the gate rule it cites — now
  built per issue (`bookkeeping_re_for_issue`) as
  `.agent/work-plans/issue-<N>/` plus the two roadmaps, which is
  merge_pr.sh gate condition (a)'s own allow-list after #300 (`issue-<N>/*`,
  verified against the now-merged PR #319). The comment names that one rule
  and says why the CI-target walk-back list (`.agent/work-plans/*`, any
  issue) is deliberately not mirrored. Fixture: a commit under another
  issue's work-plans dir keeps the re-review — `.agent/scripts/dispatch_phase.sh`
- [x] (must-fix) the pre-merge CI re-check dispatched off the table — the
  host now raises the checkpoint the loop was about to raise anyway
  (`merge`, or `findings`) with the failing checks quoted, and records
  `**Decision**: address`, which row 22 routes to `address-findings`
  durably; a resume re-derives the same state instead of walking back into
  the failing merge — `.claude/skills/run-issue/SKILL.md` step 9
- [x] (suggestion) header claimed `--pr` was `next`'s only non-timeline
  input — now names `--pr` and the optional `--head` —
  `.agent/scripts/dispatch_phase.sh`
- [x] (suggestion) `**Addressed**` called "required" — comment corrected to
  what `address-findings`' SKILL.md actually guarantees, and the test
  tightened to a non-empty value so a present-but-empty field falls through
  to the prior-complete-Implementation test instead of misrouting a failed
  implement pass. Fixture added — `.agent/scripts/dispatch_phase.sh`
- [x] (suggestion) `--check-exit` reported OK for an `## Implementation`
  entry with no `**PR**`/`**Branch**` correlation line — now PARTIAL with a
  `reason=` line for `--skill implement` and `--skill address-findings`;
  fixtures cover both skills, the correlated case, and that other skills are
  unaffected — `.agent/scripts/dispatch_phase.sh`
- [x] (suggestion) step 4a's reviewer reuse — the trade-off is now stated
  (that round's lead no longer reads the diff cold) together with where
  independence is kept: `review-code` launches its adversarial specialist as
  a fresh subagent with no context on every round (its SKILL.md 5d), and
  round 1 is never reused — `.claude/skills/run-issue/SKILL.md`

### Deferred
- [ ] (must-fix) rows 13a/13b's routing state is unreachable in the
  documented flow — held: the owner is deciding whether item 4 stays
- [ ] (must-fix) `review_progress.sh sources` drops a local entry whose SHA
  differs from the head — held with item 4
- [ ] (suggestion) `HEAD_COVERED=0` conflates "code changed" with "could not
  check" — held with item 4
- [ ] (suggestion) SHA prefix-equality runs before any git validation —
  held with item 4

Tests: `test_dispatch_phase.sh` 96 passed / 0 failed; `run_script_tests.sh`
all 23 suites passed in 48s. `main` deliberately not merged (PR #319 landed
minutes ago and touches SKILL.md steps 10/11 — the host merges before the
next review); those paragraphs were left untouched. Not pushed.

## Implementation
**Status**: complete
**When**: 2026-09-22 12:53 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-314 at cf62f9b
**Addressed**: Local Review (Pre-Push) at `6fd4249`
**Dispatch**: resumed (implementer, resume 2 of 3)
**Commits**: cf62f9b

Item 4 dropped by owner decision (2026-09-22). `8c4c92a` reverted; the
review entry's four remaining boxes — all of them item-4 findings held at
round 1 — are closed as deferred against that decision. No open boxes
remain on the round-1 entry.

The reviewer's finding stands on inspection: the publish `## Checkpoint`
entry is written before `publish` runs, so the post-publish `next` sees
that Checkpoint and row 17 already routes `--pr draft|open` to
`triage-reviews` (pinned by timeline A). An approving
`## Local Review (Pre-Push)` is never the newest entry while a PR is open,
so rows 13a/13b could not fire — the redundant re-review item 4 set out to
remove was already skipped by the table.

### Actions
- [x] Revert `8c4c92a` — `--head`, `head_covers_review()`,
  `newest_correlation_sha()`, `HEAD_COVERED`, `bookkeeping_re_for_issue()`
  (used only by the coverage check), the fixtures, run-issue SKILL.md
  steps 2/3 and the Overview note, the lifecycle routing-rule line, and the
  plan's Addendum 2. Conflicts against the round-1 fix commits resolved in
  favour of those commits — `.agent/scripts/dispatch_phase.sh`,
  `.agent/scripts/tests/test_dispatch_phase.sh`,
  `.claude/skills/run-issue/SKILL.md`,
  `.agent/knowledge/review_loop_lifecycle.md`
- [x] Reverted with the flag: round 1's correction to the header line
  "`--pr` is the only non-timeline input" — accurate again now that
  `--head` is gone — `.agent/scripts/dispatch_phase.sh`
- [x] Addendum 3 records the decision, why the state was unreachable, and
  that a recurrence should be filed with the timeline that produced it
  rather than the symptom — `.agent/work-plans/issue-314/plan.md`
- [x] (must-fix, deferred) rows 13a/13b unreachable — the finding that
  produced the decision
- [x] (must-fix, deferred) `review_progress.sh sources` would have left a
  post-skip triage with zero local sources — a real defect in item 4's
  design, moot with the revert
- [x] (suggestion, deferred) `HEAD_COVERED=0` conflated "code changed" with
  "could not check"
- [x] (suggestion, deferred) SHA prefix-equality ran before any git
  validation

Kept, none of it dependent on item 4: the `**Addressed**` non-empty test,
the `--check-exit` correlation-line check, step 9's CI-failure routing
through a `## Checkpoint`, and step 4a's independence note.

Tests: `test_dispatch_phase.sh` 88 passed / 0 failed (96 before the
revert removed item 4's 8 fixtures); `run_script_tests.sh` all 23 suites
passed in 48s. `grep -rn -- '--head|HEAD_COVERED|head_covers_review'` over
`.agent/scripts`, `.claude/skills`, `.agent/knowledge` returns only
pre-existing unrelated matches (`gh pr create --head`,
`review_progress.sh sources --head`, `gh pr list --head`). `main`
deliberately not merged; not pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 13:00 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested
**Dispatch**: resumed (round-1 reviewer, resume 1 of 3)

**Branch**: feature/issue-314 at `39b772a`
**Base**: main
**Depth**: Standard (reason: 6 files outside work-plans; the round-1 delta is a revert plus targeted fixes, all covered by the suite)
**Must-fix**: 2 | **Suggestions**: 1
**Round**: 2 | **Ship**: recommended — round 2: 2 mechanical must-fix (prev 4), not rising — fix and ship rather than another full round

### Findings
- [x] (must-fix) the `## Decision summary` gate citation is stale after the merge from main: the grep is at `merge_pr.sh:785-786` now, and line 760 is inside the gate's ancestry check — `.claude/skills/run-issue/SKILL.md:396`
- [x] (must-fix) the "a gate that passed records no entry" citation is stale after the same merge: that branch is at `merge_pr.sh:914`, and 889-890 is now a jq block in a different helper — `.claude/skills/run-issue/SKILL.md:480`
- [x] (suggestion) step 11's cross-reference still says a CI failure "routes to `address-findings` (or a fresh `triage-reviews`)", which step 9's corrected text explicitly rules out (the `merge` checkpoint vocabulary has no `retriage`; a re-triage need is answered `address`) — `.claude/skills/run-issue/SKILL.md:544`

## Implementation
**Status**: complete
**When**: 2026-09-22 13:08 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-314 at 96c884d
**Addressed**: Local Review (Pre-Push) at `39b772a`
**Dispatch**: resumed (implementer, resume 3 of 3)
**Commits**: 96c884d

Round 2. Three boxes, all in `.claude/skills/run-issue/SKILL.md`, all
consequences of the host's merge from main moving `merge_pr.sh` under the
skill's citations. No open boxes remain.

Both stale citations are now anchored to text rather than to line numbers,
so the next merge cannot break them the same way. Verified against the
merged `merge_pr.sh` before editing.

### Actions
- [x] (must-fix) the `## Decision summary` gate citation — `merge_pr.sh:760-761`
  was stale (:760 is now inside the gate's ancestry check; the grep is at
  :785-786). Replaced with "the `# (b) decision summary on the PR` block
  under `--- Step 1.5: Review-loop merge gate ---`" — step 7
- [x] (must-fix) the "a gate that passed records no entry" citation —
  `merge_pr.sh:889-890` was stale (that is now a jq block in the idempotent-record
  helper; the branch is at :914). Replaced with "`merge_pr.sh`'s
  `if [[ \"${#_gate_reasons[@]}\" -eq 0 ]]` branch at the end of Step 1.5 — it
  prints its approval and records nothing" — step 9
- [x] (suggestion) step 11's cross-reference still offered "or a fresh
  `triage-reviews`", which step 9's corrected text rules out. It now says the
  CI failure is put to the owner at the checkpoint and recorded as
  `**Decision**: address`, never dispatched directly and never as a fresh
  triage — the `merge` checkpoint's vocabulary is merge | address | stop, so a
  re-triage need is answered `address` too — step 11

Also checked, nothing to fix: no other `merge_pr.sh:<line>` citation remains
anywhere in `.claude/skills/` or `.agent/knowledge/` — the #300 merge rewrote
step 6's and step 11's own paragraphs and those no longer carry line numbers.

Tests: `test_dispatch_phase.sh` 88 passed / 0 failed; `run_script_tests.sh`
all 23 suites passed in 71s. Skill text only — no script changed, so no
fixture changed. Not pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 13:11 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved
**Dispatch**: resumed (round-1 reviewer, resume 2 of 3)

**Branch**: feature/issue-314 at `8e1ffd1`
**Base**: main
**Depth**: Light (reason: one skill-text commit fixing the round-2 findings; no code change)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 13:16 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: publish
**Decision**: publish

Publish now: round 3 approved with no findings, main merged in (39b772a), item 4 dropped and reverted by owner decision.

## Integrated Review
**Status**: complete
**When**: 2026-09-22 13:42 -04:00
**By**: Claude Code Agent (claude-opus-5)

**PR**: #322 at `90460d4`
**Sources**: 2 (Local Review (Pre-Push) round 3 @ `8e1ffd1`, CI rollup @ `90460d4`; Copilot's COMMENTED placeholder at `90460d4` carries no review content — quota exhausted — and is not counted as a source)
**Cross-source confirmations**: 0
**CI**: all-pass

### Findings
- (none) No open findings. Round 3's local review approved with "No issues found. LGTM."; rounds 1 and 2 closed all 10 boxes (four of them dropped by the owner's decision to revert item 4). The only commit after the reviewed head `8e1ffd1` is the publish `## Checkpoint`, a progress.md-only bookkeeping commit (`git diff --stat 8e1ffd1..90460d4` = 1 file, +26 lines), so the round-3 approval still covers the code at the PR head.

### False positives
- (CI rollup) the `copilot-pull-request-reviewer` check-run reports conclusion `failure` at `90460d4` — this is the quota-exhausted placeholder ("Copilot was unable to review this pull request because the user who requested the review has reached their quota limit"), not a test or lint failure. All eight substantive checks (Lint (pre-commit), Validate Documentation, Validate Adapter Contract, ros-manifest tests, across both workflow runs) are `success`.
- (tooling note, not a review claim) `review_progress.sh sources` returned empty `local_findings` here: it correlates by exact head SHA and the round-3 entry is recorded at `8e1ffd1`, one bookkeeping commit behind the PR head. Known helper gap #309; the timeline was read directly instead.

**Merge recommendation**: merge. No open must-fix at the PR head, CI green on every substantive check, and the PR body already carries a `## Decision summary`, so `merge_pr.sh`'s review gate has both artefacts it looks for.
