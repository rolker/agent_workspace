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

## Checkpoint
**Status**: complete
**When**: 2026-09-21 14:29 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed — reuse the existing convention (Recommended): item 6 becomes "when the owner defers suggestions at a checkpoint (publish/findings answered with them left open), the host marks those boxes via `review_progress.sh check --deferred "<reason>"` before the next `next` call, so the dispatcher's open_findings() no longer sees them"; no new `[~]` marker, no changes to review_progress.sh findings/check or the lifecycle note beyond documenting the host step in run-issue SKILL.md §6.

## Plan Authored
**Status**: complete
**When**: 2026-09-21 14:32 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-307/plan.md` at `165e1d1`

Text edits to `.claude/skills/run-issue/SKILL.md` (identity-sourcing note in step 1, exact `entry_type=` string in step 4, Copilot check-run wait in step 9, a new deferred-suggestion host sub-step in step 6) and `.claude/skills/plan-task/SKILL.md` (test-file exec-bit guidance), plus a new `conventions=` line printed by `dispatch_phase.sh`'s handoff block (When-format + scratch hygiene) with one extended assertion in `test_dispatch_phase.sh`. Item 6's checkpoint decision is followed as-is: reuse the existing `review_progress.sh check --deferred` convention — `dispatch_phase.sh`'s `next` decision-table routing is unchanged, so no new fixture row is added.

## Plan Review
**Status**: complete
**When**: 2026-09-21 14:37 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: ready

**Issue**: #307 — run-issue: fold in the live-exercise fixes (identity env, BEFORE type string, Copilot wait, scratch hygiene, deferred-suggestion checkpoint)
**Plan**: `.agent/work-plans/issue-307/plan.md` at `165e1d1`
**Branch**: `feature/issue-307`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four files, seven small text/one-line edits; one `/run-issue` drive is a realistic acceptance test. |
| Issue alignment | Good | All seven issue items are carried; the Issue Review's three open Actions are all resolved by the owner's Checkpoint and followed as decided (reuse `check --deferred`, no `[~]` marker, no `review_progress.sh` / `review_loop_lifecycle.md` change). |
| File targeting | Needs work | The one file the plan misses is `dispatch_phase.sh`'s own header comment — see finding 1. |
| Consequences | Needs work | Same omission; everything else in the table checks out. |
| Principle alignment | Good | "Only what's needed" and "Enforcement over documentation" are both argued correctly; the deferred-box reuse is the minimal mechanism. |
| ADR compliance | Good | ADR-0014 triggered and satisfied; ADR-0013 correctly not triggered (no new checkbox state). |
| ROS conventions | N/A | Workspace plan. |

Claims verified against source (this is the part the plan rests on):

- **The central claim holds.** `open_findings()` (`dispatch_phase.sh:421-426`) filters on `f.get("section") == section and not f.get("checked")` — annotation text is never inspected. Verified end to end on a scratch fixture: an `## Integrated Review` with one open `(suggestion)` box routed `next --pr open` → `action=checkpoint:findings`; after `review_progress.sh check --progress <f> --index 0 --deferred "<reason>"` rewrote the line to `- [x] (suggestion) … (deferred: <reason>)`, the same `next` call returned `action=checkpoint:merge`, `reason=Integrated Review has no open findings`. The plan is right that no decision-table fixture row is needed.
- **Existing test coverage already pins both halves**, so declining a new fixture is well-founded, not a gap: `test_dispatch_phase.sh:220-221` (row 20) pins "a checked box is not an open finding" using a plain `- [x]` box, and `test_address_findings.sh:129-140` pins the deferred form itself — that `check --deferred` produces `- [x] … (deferred: …)` and that `progress_read.py` still parses such boxes as checked (including the CRLF case at :175-180).
- **The deferral is load-bearing beyond the immediate routing hop.** `triage-reviews` sources only *unchecked* prior findings at the head SHA (`triage-reviews/SKILL.md:107-111`), so flipping the boxes is what stops a deferred suggestion being carried forward into the next `## Integrated Review` and re-asking the owner — the #303 symptom the issue cites.
- Identity hard-fail is at `dispatch_phase.sh:228-231` as cited; `cmd_handoff` prints `exit_contract=` at `:239` inside `:233-242`; `run-issue/SKILL.md` step 1 (`:74-83`) has no identity note today; step 4's `--type "<entry-type>"` is at `:132` and the printed-field list at `:142-143`; step 6's `## Checkpoint` template is at `:211-222`; step 9 (`:284-296`) says only "until no checks are pending"; `fetch_pr_reviews.sh:134-143` does fetch check-runs, so item 3 is indeed a text clarification; `plan-task/SKILL.md` has "Concrete, not generic" at `:344` and no exec-bit guidance anywhere; `test_dispatch_phase.sh:356-395` is the handoff block and `:362-365` is the `review-issue` assertion that already checks `Never push`; `:373`/`:376` do show branch-mode vs PR-mode `entry_type=` differing.

### Findings

1. **[Consequences]** — `dispatch_phase.sh`'s own header comment enumerates the handoff block's fields in order: "Output is `key=value` lines, one per line, in this order: worktree, task, agent_name, agent_email, model, entry_type, exit_contract, and prompt_file" (`dispatch_phase.sh:14-17`). Adding `conventions=` makes that comment wrong, and the workspace rule is that documentation is verified against source. Add the header comment to the plan's Files to Change / Consequences rows for `dispatch_phase.sh` (one-line edit, fold into the same commit).
2. **[Approach — item 5]** — The plan describes the trigger as "a `publish`/`merge`-style decision over a `checkpoint:findings` state" (plan.md:74-76). That combination does not exist in the dispatcher's vocabulary: `**After**: findings` (and `merge`) accepts only `merge` / `address`; `publish` is a decision for `**After**: publish` / `rounds` (`dispatch_phase.sh:493-505`), and those rows route on the pre-push review's `**Verdict**`, never on open boxes. The new SKILL.md sub-step must name the reachable case — an `**After**: findings` checkpoint answered `merge` with suggestion-only boxes left open — or it will document a state the loop cannot be in.
3. **[Approach — item 5]** — The plan does not say the host must commit the flipped `progress.md`. `check` rewrites the one line in place and prints it; it does not commit (`review_progress.sh:444-491`), unlike `progress_append.sh`. `address-findings` covers this by folding the flip into "the same commit as the fix, or a trailing progress commit" (`address-findings/SKILL.md:115`); the host has no fix commit, so the new sub-step should say to commit `progress.md` itself — otherwise the annotation rides into whatever the next phase's persistence step commits, or is lost.
4. **[File targeting — placement]** — The plan says to add the sub-step "immediately after the `## Checkpoint` entry template" (plan.md:83-85). The template at `run-issue/SKILL.md:211-222` is followed by its own field explanations (`:224-232`) before the next topic at `:234`. Inserting between the template and its explanation splits them; place the sub-step after `:232`, before "Every dialog is self-contained."
5. **[ADR compliance — optional]** — ADR-0014's handoff-contract bullet list (`docs/decisions/0014-in-process-phase-handoff.md:55-72`) enumerates what the host provides on every dispatch; `conventions=` becomes a sixth item not in that list. The repo has no ADR-amendment convention, so leaving the ADR as a point-in-time record is defensible — noting it here so the choice is deliberate rather than overlooked.

### Summary

The plan's shape is right and its one load-bearing technical claim is verified by both code reading and an end-to-end run: a checked (deferred) box already disappears from `open_findings()`, existing suites already pin both halves of that behaviour, and no new fixture row is needed. Findings 1–3 are additions to fold into implementation, not reasons to re-plan: one missed consequence (the script's own header comment), one imprecise state description that would otherwise be written into `SKILL.md` verbatim, and one missing "commit the flip" step.

### Recommended Actions

- [ ] (must-fix) Update `dispatch_phase.sh`'s header comment field list (`:14-17`) in the same commit that adds the `conventions=` line.
- [ ] (must-fix) Write item 5's sub-step against the reachable checkpoint state — `**After**: findings` answered `merge` with suggestion-only boxes open — not "publish/merge-style over checkpoint:findings".
- [ ] (suggestion) Say in the new sub-step that the host commits the flipped `progress.md` (`check` does not commit).
- [ ] (suggestion) Place the new sub-step after `run-issue/SKILL.md:232`, not immediately after the entry template at `:222`.
- [ ] (suggestion) Decide explicitly whether ADR-0014's handoff-contract list gets the `conventions=` bullet, or record that it stays as written.

## Checkpoint
**Status**: complete
**When**: 2026-09-21 14:49 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed (Recommended) — implement the plan at `165e1d1` with the five Plan Review additions applied: dispatch_phase.sh header comment lists `conventions=`; the new run-issue §6 sub-step names the reachable case (an `After: findings` checkpoint answered `merge` with suggestion-only boxes open) and says the host commits the flipped progress.md itself; placed after the checkpoint template's field notes (after SKILL.md:232); ADR-0014's handoff list left as a point-in-time record with a one-line note. Implementer: Opus sub-agent under the host. Owner also decided (same checkpoint) NOT to open the run-issue package-worktree issue yet — revisit after #265 PR 3.

## Implementation
**Status**: complete
**When**: 2026-09-21 14:57 -04:00
**By**: Claude Code Agent (implementer: claude-opus-5; lead: claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-307/plan.md` at `165e1d1`

**Branch**: `feature/issue-307` at `ab0f5c8`
**Mode**: inline

Four commits, one per logical change. `dispatch_phase.sh` (d24fbb0, with
`test_dispatch_phase.sh`): `cmd_handoff` prints a new `conventions=` line after
`exit_contract=` carrying the `**When**` local-time-with-offset format and the
scratch-hygiene rule, and the header comment's ordered field enumeration now
lists `conventions` between `exit_contract` and `prompt_file` (addition 1,
same commit as the field); the existing `review-issue` handoff assertion gained
`conventions=`/`local time with offset`/`scratchpad` substring checks rather
than a new fixture, per plan item 7. `.claude/skills/run-issue/SKILL.md`
(f96f80e): step 1 gained an identity paragraph with a sourced-in-the-same-chain
example (`dispatch_phase.sh:228-231` hard-fails on unset `AGENT_NAME`/
`AGENT_EMAIL`); step 4 states `$BEFORE`'s `--type` must be the exact
`entry_type=` string the handoff printed (`Local Review (Pre-Push)` vs `Local
Review` are distinct in `skill_entry_type()`) and adds `conventions=` to the
printed-field list with an instruction to relay it; step 9 extends "no checks
pending" to the `copilot-pull-request-reviewer` check-run (`fetch_pr_reviews.sh`
already emits every check-run's `name`/`conclusion`) and names the
quota-exhausted comment-only non-source; §6 gained the deferred-box sub-step,
placed after the `## Checkpoint` field explanations and immediately before
"Every dialog is self-contained" (addition 4), naming only the reachable case —
an `**After**: findings` checkpoint answered `merge` with suggestion-only boxes
still open in the latest `## Integrated Review`'s `### Findings` section
(addition 2; `open_findings(E, "Findings")` at `dispatch_phase.sh:560` is the
router, and `f.get("checked")` its only test) — and stating that
`review_progress.sh check` rewrites `progress.md` in place and does not commit,
so the host commits the flipped file itself before the next `next` call
(addition 3). `.claude/skills/plan-task/SKILL.md` (e15be78): a Guidelines bullet
requiring a plan step that creates a new `test_*.sh` to include `chmod +x`,
because the `check-shebang-scripts-are-executable` hook fails the commit
otherwise. `docs/decisions/0014-in-process-phase-handoff.md` (ab0f5c8):
addition 5 applied as a **References bullet**, not the Status line — ADR-0008
permits both, but its Status-line clause is scoped to pointers at related ADRs
while its References clause covers issue cross-references, and the section
already lists #269/#276 the same way; the bullet says the Decision section's
handoff-contract list is a point-in-time record and that `dispatch_phase.sh`'s
header comment is the current field enumeration. Verification:
`run_script_tests.sh` 23/23 suites, exit 0; `test_dispatch_phase.sh` 76 passed,
0 failed with the extended assertion; `dispatch_phase.sh --issue 307 --skill
review-code --type workspace` prints the `conventions=` line; pre-commit's full
suite ran green on all four commits. One deviation from a draft claim, caught
before commit: the plan-task bullet initially also said `run_script_tests.sh`
only picks up executable suites — false, it invokes `bash "$s"` (line 220) — so
the bullet now cites only the pre-commit hook.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 08:22 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: `feature/issue-307` at `bfe8d35`
**Base**: main
**Depth**: Standard (reason: governance-touching — two skill docs, an ADR, and `dispatch_phase.sh`'s printed handoff contract)
**Must-fix**: 2 | **Suggestions**: 2
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) Deferred-box section's stated consequence is wrong: `**After**: findings` + `**Decision**: merge` routes to `merge` unconditionally (`dispatch_phase.sh:503-505`, fixture "row 21"), so the following `next` never re-routes to `checkpoint:findings`; the real re-route is only reachable after a refused merge -> retriage writes a fresh `## Integrated Review` — `.claude/skills/run-issue/SKILL.md:255-261`
- [x] (must-fix) The `check --index <i>` snippet never says where `<i>` comes from (`review_progress.sh findings --progress <f>`; 0-based across ALL of the entry's checkboxes, not section-filtered), so a hand-counted index silently defers the wrong finding — `check` only verifies the line is an unchecked box — `.claude/skills/run-issue/SKILL.md:263`
- [x] (suggestion) `$PF` is reused from step 4's snippet even though this same skill states shell state does not persist between tool calls; inline the path or re-assign `PF=` in the same chain — `.claude/skills/run-issue/SKILL.md:263`
- [x] (suggestion) The ADR's handoff-contract list gains no `conventions=` bullet and no in-place pointer; the "this list is point-in-time" disclaimer sits ~110 lines below in References — `docs/decisions/0014-in-process-phase-handoff.md:55-72`

## Implementation
**Status**: complete
**When**: 2026-09-22 08:28 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-307 at `6e36658`
**Addressed**: Local Review (Pre-Push) at `bfe8d35` (2026-09-22 08:22 -04:00)
**Commits**: 0442a63, 473182a, 6e36658

### Actions
- [x] (must-fix) Deferred-box section's stated consequence corrected — `.claude/skills/run-issue/SKILL.md:255`. Verified against `dispatch_phase.sh` (the `if after in ("findings", "merge")` block emits `merge` unconditionally) and fixture `"row 21: checkpoint findings answered merge -> merge"`. The section now says the deferral does not gate the merge, and names the reachable re-route: a merge that does not land records `## Merge (report-only)`/`## Merge (unreviewed)` -> `checkpoint:merge-refused` (row 23) -> `retriage` -> a fresh `## Integrated Review` -> row 19 `checkpoint:findings`. Kept the write as the durable record of the owner's deferral.
- [x] (must-fix) `<i>` provenance pinned — `.claude/skills/run-issue/SKILL.md:263`. The snippet now runs `review_progress.sh findings --progress "$PF"` first and states that `<i>` is that output's `index` field, 0-based over every checkbox line in the entry (verified: `cmd_findings` enumerates `src["findings"]` with no section filter), never a hand-count, because `check` only verifies the line is an unchecked box.
- [x] (suggestion) `$PF` re-assigned in the snippet's own chain — `.claude/skills/run-issue/SKILL.md:263` — with the reason stated inline (shell state does not persist between tool calls, so step 4's assignment is gone).
- [x] (suggestion) ADR-0014 handoff-contract list gained a `conventions=` bullet and an in-place currency pointer to `dispatch_phase.sh`'s header comment — `docs/decisions/0014-in-process-phase-handoff.md:69`; the disclaimer no longer lives only in References.

### Verification
- pre-commit hooks ran on all three commits (no `--no-verify`); all passed.
- `.agent/scripts/tests/run_script_tests.sh`: 23 suites, all passed (43s). No script files changed in this round — the changes are skill and ADR prose only.

Next: `/review-code --branch` to re-review the fixes cold.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 08:32 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-307 at `3527104`
**Base**: main
**Depth**: Standard, scoped to the fix diff (round-2 re-review of commits 0442a63, 473182a)
**Must-fix**: 1 | **Suggestions**: 1
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

### Findings
- [x] (must-fix) `_corr_pr_or_branch` captures the branch as `(\S+)` while tolerating `` `? `` on the sha, so an entry writing ``**Branch**: `feature/issue-307` `` yields a backticked correlation and `review_progress.sh round` silently restarts at 1 (MAX_ROUNDS never trips; this very review counted as round 1) — `.agent/scripts/progress_read.py:192`
- [x] (suggestion) "a refused or non-merging attempt records `## Merge (report-only)` / `## Merge (unreviewed)`" — those entries record a gate-precondition failure or bypass and are written even when the merge succeeds; step 11 (line 398) states it precisely — `.claude/skills/run-issue/SKILL.md:265`

Round-1's four findings all verified resolved against source: routing prose matches `dispatch_phase.sh:503-505/559-566` and the row 19/21/23 fixtures; index provenance matches `review_progress.sh:430` + `progress_read.py:213-245`; `PF` re-assigned in-chain; ADR bullet matches `dispatch_phase.sh:241` verbatim. Pre-commit (incl. the script test suite) green on all changed files.

## Implementation
**Status**: complete
**When**: 2026-09-22 08:39 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-307 at `bf067c5`
**Addressed**: Local Review (Pre-Push) at `3527104` (2026-09-22 08:32 -04:00)
**Commits**: b3a5949, bf067c5

### Actions
- [x] (must-fix) `_corr_pr_or_branch` now matches `` `?([^`\s]+)`? `` for the branch, so a backticked `**Branch**` correlates with a bare one and `round` / `dispatch_phase.sh next` no longer restart at 1 — `.agent/scripts/progress_read.py:192`; fixtures added in `test_progress_read.py` (backticked == bare correlation) and `test_review_code_convergence.sh` (a backticked prior entry counts: round=3)
- [x] (suggestion) Step 10's note now says the gate records `## Merge (report-only)` (or `## Merge (unreviewed)` under `--force-unreviewed`) on a gate-precondition failure or bypass, written whether or not the merge then succeeds, matching step 11 — `.claude/skills/run-issue/SKILL.md:265`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 08:55 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-307 at `4ea250b`
**Base**: main
**Depth**: Standard, scoped to the fix diff (round-3 re-review of 3527104..4ea250b — commits b3a5949, bf067c5; +31/-3 across 4 code files)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — no must-fix findings; the one suggestion is a doc-precision nit, apply or track

### Findings
- [ ] (suggestion) The corrected sentence still omits the third gate path the same file names at line 400: under `--enforce` on a workspace PR a failed gate exits 1 and writes no entry at all (`merge_pr.sh:896-903`), so "written whether or not the merge itself then succeeds" overclaims — add the same `--enforce` caveat used at line 400 — `.claude/skills/run-issue/SKILL.md:265`

### Verification
Round-2's must-fix is resolved at the source: `_corr_pr_or_branch` now matches `` `?([^`\s]+)`? `` for the branch (`progress_read.py:192`). Ran both regexes side by side over eight `**Branch**` forms — every bare form extracts identically to before, only the backticked forms change, and neither over-matches past the ` at ` separator or across a trailing parenthetical. The fix is live-verified on this very timeline: `review_progress.sh round --issue 307 --branch feature/issue-307` now returns `round=3 prev_must_fix=1`, correlating the backticked round-1 entry (line 204) with the bare round-2 entry (line 243); the same key drives `dispatch_phase.sh:437 round_count()` and hence MAX_ROUNDS. `progress_read.py` is the only parser of the field — no divergent reader to keep in step; `merge_pr.sh` reads only `.correlation.pr` / `.sha`.

Both fixtures are genuine regression guards, not restatements: patching the old regex into a throwaway copy makes `test_review_code_convergence.sh`'s new case fail (`round=2`, the silent restart), and the python case asserts ticked-vs-bare correlation equality. Full suite green — `run_script_tests.sh`: 23/23 suites; `test_progress_read.py`: 39 tests.

Round-2's suggestion is resolved: the step-10 sentence now matches `merge_pr.sh:889-908` — the gate records `## Merge (report-only)` (or `## Merge (unreviewed)` under `--force-unreviewed`) on a precondition failure at step 1.5, before the CI wait and the merge itself, and records nothing on a pass. Row 23's routing claim checks out (`dispatch_phase.sh:564-566`), as does the `--pr merged` short-circuit ahead of it (`dispatch_phase.sh:339`). No contradiction with step 11. Round-1's four findings remain resolved; nothing in the fix range touches them.

Plan drift: `progress_read.py` is outside the plan's "Files to Change" — expected, since it is the fix for a bug the loop's own round-2 review found in the loop's own machinery. Static analysis: shellcheck, flake8 and pre-commit are not installed in this environment, so the test suites are the only executed check; both changed script files are covered by suites that passed.

### Decision summary
**What changed**: A bug in how the review loop reads its own timeline — a branch name written inside backticks did not match the same branch written plain, so the round counter silently restarted at 1 and the three-round safety stop could never trip. The parser now accepts both forms, with tests covering it. A sentence in the run-issue instructions that described merge-gate records as marking a failed merge was corrected to say what the merge script actually does.

**Reviews and outcomes**: Round 3 (scoped re-review of the round-2 fixes) — 0 must-fix, 1 suggestion; ship: recommended. Round 1 had 2 must-fix, round 2 had 1; all are verified resolved against source.

**Open human calls**: None. The single suggestion is a one-clause wording caveat in run-issue's step 10; it can be applied before merge or tracked.

**Verified**: 23/23 script suites and 39 progress_read tests pass; the new fixtures were confirmed to fail under the old regex; the round counter now reports round 3 on this timeline; the corrected wording was checked line by line against `merge_pr.sh` and `dispatch_phase.sh`.

**Recommendation**: merge.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 08:50 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: publish
**Decision**: publish

Publish now. The one open suggestion (the `--enforce` wording caveat in run-issue step 10) gets applied in the PR review round or tracked. Earlier in the session the owner also decided the round-counter regex fix stays on this branch.

## Integrated Review
**Status**: complete
**When**: 2026-09-22 09:02 -04:00
**By**: Claude Code Agent (claude-opus-5)

**PR**: #308 at `8e9c0c8`
**Sources**: 1 (Local Review (Pre-Push) round 3 @ `4ea250b`, approved; Copilot @ `8e9c0c8` is a quota-exhausted comment-only review carrying no finding — not a source; CI rollup @ `8e9c0c8`)
**Cross-source confirmations**: 0
**CI**: all-pass — Lint (pre-commit), Validate Adapter Contract and Validate Documentation all green at `8e9c0c8`. The one `failure` check-run, `copilot-pull-request-reviewer`, is the quota exhaustion itself, not a repo gate.

### Findings
- [x] (suggestion, Local Review @ `4ea250b`) The step-10 sentence still omits the third gate path that the same file names at line 400: under `--enforce` on a workspace PR a failed gate exits 1 and writes no entry at all (`merge_pr.sh:896-903`), so "written whether or not the merge itself then succeeds" overclaims — and with no `## Merge (report-only)`/`## Merge (unreviewed)` entry written, `dispatch_phase.sh:564` never routes to `checkpoint:merge-refused`, so the re-route the paragraph calls reachable is not reachable on that path. Add the same `--enforce` caveat used at line 400 — `.claude/skills/run-issue/SKILL.md:265`
- [ ] (suggestion, integrator @ `8e9c0c8`) `review_progress.sh sources` returned `local_findings: []` on this very triage: the round-3 review correlates at `4ea250b` while the PR head is `8e9c0c8`, and the only commit between them is the loop's own `progress: checkpoint` commit — no code changed. A progress-only commit therefore ages out the prior round's still-open findings, and a triage that trusted the helper would have silently dropped the one open suggestion. Open a follow-up issue against the loop machinery (out of scope for this PR's diff) — `.agent/scripts/review_progress.sh`

Both findings were verified against source at this head. The step-10 wording was re-read at `.claude/skills/run-issue/SKILL.md:255-271` and checked against `merge_pr.sh:889-910` (the `--enforce` + workspace branch exits 1 before any `_gate_record` call) and `dispatch_phase.sh:559-566` (only a `Merge (report-only)` / `Merge (unreviewed)` base emits `checkpoint:merge-refused`). The correlation gap was reproduced by running the `sources` call this skill's step 3 prescribes and then reading the timeline directly; `git diff --stat 1fada0d..HEAD` shows progress.md as the only changed file, so the round-3 verdict still applies to the code at head.

Round 1 (2 must-fix) and round 2 (1 must-fix, 1 suggestion) are all recorded resolved and re-verified by round 3 against source; nothing here re-opens them.

### False positives
- (Copilot @ `8e9c0c8`) The only GitHub review on the PR states Copilot "was unable to review this pull request because the user who requested the review has reached their quota limit" — a COMMENTED review with zero inline comments and no claim about the code. Per the run-issue skill a quota-exhausted comment-only Copilot review is not a review source; it is recorded here so the absence of bot findings is not mistaken for bot approval.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 09:05 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: findings
**Decision**: address

Address: apply the one-clause `--enforce` wording fix in run-issue step 10 here, and open a follow-up issue for the sources-helper bug (a progress-only commit ages out prior open findings). Then re-review and back to triage.
