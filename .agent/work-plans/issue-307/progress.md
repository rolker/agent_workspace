---
issue: 307
---

# Issue #307 — run-issue: fold in the live-exercise fixes (identity env, BEFORE type string, Copilot wait, scratch hygiene, deferred-suggestion checkpoint)

## Issue Review
**Status**: complete
**When**: 2026-09-21 14:26 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #307

### Scope Assessment

**Well-scoped?** Yes — three files, seven small text/one-line edits, sized for a single `/run-issue` drive as the issue's own acceptance criterion states.
**Right repo?** Yes — `.claude/skills/run-issue/SKILL.md`, `.agent/scripts/dispatch_phase.sh`, `.claude/skills/plan-task/SKILL.md` are all workspace infrastructure.
**Dependencies**: none blocking. #300 (merge_pr.sh counting Copilot's check-run as a CI failure) is correctly excluded and tracked separately. The multi-PR routing gap (write-up item 9) is correctly excluded pending a shape decision.

Traceability against the 2026-09-21 #276 write-up (checked each item's numbered claim against current source):

| Issue item | Write-up source | Verified against current code |
|---|---|---|
| 1 (SKILL.md step 1: source identity before `dispatch_phase.sh`) | item 1 | Confirmed — step 1 ("Enter the worktree") has no identity-sourcing note today; `dispatch_phase.sh` hard-fails without `AGENT_NAME`/`AGENT_EMAIL`. |
| 2 (SKILL.md step 4: exact `--type` string) | item 2 | Confirmed — step 4's `BEFORE` count uses `--type "<entry-type>"` with no note that it must be the literal `entry_type=` value. |
| 3 (SKILL.md step 9: wait for `copilot-pull-request-reviewer`) | item 6 | Confirmed — step 9 today only says "wait ... until no checks are pending" via `fetch_pr_reviews.sh`, no Copilot-specific check-run named. |
| 4 (SKILL.md: `**When**` local time + scratch hygiene) | items 4 and 5 | Confirmed — combines two write-up items into one SKILL.md change; reasonable since both are handoff-text additions. |
| 5 (dispatch_phase.sh: add those two lines to the handoff block) | items 4 and 5 | Confirmed — `cmd_handoff` currently prints a single `exit_contract=` line (dispatch_phase.sh:239) with no `conventions=` line; this is the mechanical enforcement half of item 4. |
| 6 (dispatch_phase.sh: checkpoint:findings routing for deferred suggestions) | item 8 | See "Action needed" below — under-specified. |
| 7 (plan-task/SKILL.md: exec bit for new test files) | item 3 | Confirmed — write-up item 3 is exactly this. |
| excluded: merge script Copilot-as-CI-failure | item 7 | Correctly deferred to #300, as the task context states. |
| excluded: multi-PR routing | item 9 | Correctly deferred pending a shape decision. |
| not carried forward: hook-cost tuning, plan quality, usage cost | items 10–12 | Correct to omit — the write-up's own verdict calls these "tuning," not decided fixes, separate from the "items 1–8" fix set. |

No item from the write-up's numbered 1–8 set is missing from this issue once #300's exclusion is accounted for.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Capture decisions, not just implementations | Watch | Item 6 is written as two alternative mechanisms ("route to checkpoint:merge ... — or introduce a ... `[~]` marker") without picking one. Fine for an issue if plan-task is expected to decide, but the decision and its rationale should land in the plan, not stay open through implementation. |
| A change includes its consequences | Action needed | See below — item 6 doesn't account for `review_progress.sh` or `review_loop_lifecycle.md`. |
| Enforcement over documentation | OK | Items 1, 2, 4, 5, 7 are handoff/skill text for a sub-agent to follow — consistent with how the rest of `SKILL.md`/`dispatch_phase.sh` already work (no separate hook expected). Item 6 correctly requires a `test_dispatch_phase.sh` fixture. |
| Only what's needed | OK | Scope stays to the seven items; no speculative additions. |
| Test what breaks | Watch | Items 1, 2, 4, 5, 7 are text-only and untested by convention (matches existing skill-doc changes in this repo). Item 6 needs the fixture called for — see below on whether it's specified precisely enough to write one. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0014 — In-process phase handoff | Yes | Touches `dispatch_phase.sh` and `run-issue`'s handoff contract directly (items 1, 4, 5). The added `**When**`/scratch-hygiene lines are exactly the kind of "handoff contract" content ADR-0014 requires to print from `dispatch_phase.sh`, not live only in the skill doc — the issue's split (skill text *and* the printed block) matches that. |
| 0013 — `progress.md` entry-type vocabulary | Conditionally | Only if item 6 is implemented via the `- [~]` marker option: a new checkbox state that `progress_read.py`/`review_progress.sh` must also recognize is the kind of shape change ADR-0013's consequences call out (readers and writers move together). Not triggered if item 6 is implemented via the routing-only option (no new progress.md syntax). |

### Consequences

- **Item 6 needs to reckon with an existing mechanism it doesn't mention.** `review_progress.sh` already has a "deferred but resolved" convention: `check --deferred "<reason>"` flips a finding's box to `[x]` with a `(deferred: <reason>)` annotation (`review_progress.sh:440-478`, used by `address-findings` per its `SKILL.md`). A *checked* box, deferred or not, is already excluded from `open_findings()` in `dispatch_phase.sh`, so it would never re-trigger `checkpoint:findings`. The write-up's #303 case (three already-deferred suggestions still showing as open boxes) suggests those suggestions were deferred by a `Checkpoint` **Decision**: `merge` answer, not by an `address-findings` `check --deferred` call — i.e. the box never got flipped. That's worth investigating before choosing item 6's mechanism: if the fix is "when a Checkpoint answers `merge`/`publish` over open suggestion-only findings, also check those boxes with a deferred annotation," it reuses existing state (`checked`, `(deferred: ...)`, and the `source_hint` field already used elsewhere to distinguish `must-fix` from suggestion findings at `review_progress.sh:127`) instead of adding new routing logic or a new box marker to `dispatch_phase.sh` and its readers.
- If item 6's plan nonetheless lands on a *new* `[~]` "deferred" marker (the issue's second option) rather than reusing the checked convention: the issue's scope should also cover `review_progress.sh`'s `open_findings`-equivalent logic and `cmd_findings`/`cmd_check` (so `address-findings` and `triage-reviews` see the same "not open" semantics dispatch_phase.sh applies), and `.agent/knowledge/review_loop_lifecycle.md` (which documents the `findings`/`merge` row at line 75 — "`## Integrated Review` has open findings"). Currently the issue's scope names only `dispatch_phase.sh` and its test file for item 6.

### Recommendations

- Before implementation, decide item 6's mechanism explicitly in the plan rather than leaving both options open: prefer investigating and reusing the existing `check --deferred` checked-box convention (see Consequences above) over adding new routing state, since it requires no new progress.md syntax and no reader changes elsewhere.
- If the `[~]` marker option is chosen instead, expand item 6's scope to include `review_progress.sh` (`findings`/`check`) and `.agent/knowledge/review_loop_lifecycle.md`, per the consequences map's rule that a `progress.md` entry shape change moves its writers and readers together.

### Actions
- [ ] See below — item 6 doesn't account for `review_progress.sh` or `review_loop_lifecycle.md`.
- [ ] Before implementation, decide item 6's mechanism explicitly in the plan rather than leaving both options open: prefer investigating and reusing the existing `check --deferred` checked-box convention (see Consequences above) over adding new routing state, since it requires no new progress.md syntax and no reader changes elsewhere.
- [ ] If the `[~]` marker option is chosen instead, expand item 6's scope to include `review_progress.sh` (`findings`/`check`) and `.agent/knowledge/review_loop_lifecycle.md`, per the consequences map's rule that a `progress.md` entry shape change moves its writers and readers together.
