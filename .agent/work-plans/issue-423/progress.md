---
issue: 423
---

# Issue #423 — Promote ADR-0016 to Accepted

## Issue Review
**Status**: complete
**When**: 2026-11-09 18:10 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #423

### Scope Assessment

**Well-scoped?** Yes — one ADR status line, three roadmap lines, four design.md spots plus a change-log row, two comments. One small PR. Verified the record: rolker/geozui4d#9 closed 2026-11-09T16:43Z (PR 14 merged) and #7 closed 2026-11-09T17:40Z (PR 15 merged); #332 closed 2026-10-30; #265 and #295 are open.
**Right repo?** Yes — workspace docs; the two deferral comments go on workspace issues.
**Serves**: "The long view" — `docs/design.md#sessions-and-roots`, `docs/design.md#open-questions`
**Design picture?** Changes Sessions and roots (Status block `decided, not proven`, the paragraph at ~186), the Decision register row for 0016, the Open questions OQ-2 and the status-vocabulary glossary row — the owner decided the promotion ("promote adr 0016", 2026-11-09), and the issue names the design update, so no re-ask.
**Dependencies**: none blocking. Unblocks #265 PR 4 and #295.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | Beyond the four sentences the issue lists, design.md has more that must move with the flip: the Sessions and roots `Status: decided, not proven` line (~181) becomes `decided`; the Decision register row for 0016 (~723, Status cell Provisional) becomes Accepted; the line ~732 "ADR-0016 stays `Provisional`" in the C1-c paragraph; and the glossary row (~70) defines `decided, not proven` BY ADR-0016 (ADR-0018 is still Provisional), so it needs rewording to a general definition, not just a tense change. The acceptance criterion "no sentence ... still says ADR-0016 is Provisional" needs a grep to confirm. |
| Verify before claiming | Action needed | The roadmap check for the onboarding line should be tied to the run's real record. `gh-issue 332 closed` shows the issue closed, not that the run passed; the plan should check the record (e.g. geozui4d#10 onboarding PR merged 2026-11-02, or 332 closed after parts 3 and 4) and say in the PR which was chosen and why. Cite the merged PRs (geozui4d PRs 14 and 15) in the ADR sentence. |
| Only what's needed | OK | Status flip plus the dependent doc lines; no Decision change; deferred work stays out. |
| Workspace is project-agnostic | Watch | The ADR Status sentence naming GeoZui4D is a record (allowed), but keep it to the issue and PR references, not mechanism. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0008 (cross-reference addendums) | Yes | ADR-0016's own Status text says the flip is a status-line edit permitted without a superseding ADR. Keep the diff to the Status section; leave Decision, Consequences and Alternatives untouched, and keep the ADR-0018 paragraph. |
| ADR-0016 | Yes | Subject of the change. |
| ADR-0017 (design doc is the current picture) | Yes | design.md update plus Change log row in the same PR. |
| ADR-0018 | Watch | Stays Provisional; the glossary row and "none of this is marked decided" wording must not imply otherwise. |

### Consequences

- The sit-rep reads the roadmap acceptance-case paragraph (first sentence printed as written; `acceptance_rest`); after rewording, check the sit-rep dry-run still renders sensibly and `adr-status` reads Accepted (it takes the first word after `## Status`, so write `**Accepted.**`).
- `check_design_anchors.sh` passes now (exit 0); rerun after edits. Line references in design.md may shift; the Change log row carries a line count.
- The roadmap's own Direction line "ADR-0016 is promoted" turns true; the other two empty-check lines get their checks.
- #265 and #295 bodies do not mention ADR-0016 being a blocker in a form that says "now unblocked" (grep found nothing), so a signed comment on each is needed.

### Recommendations

- Add to the plan the design.md spots beyond the issue's list: Status line ~181, register row ~723, ~732, and the generalised `decided, not proven` glossary definition.
- Choose the onboarding-line check from the actual record of the run and state the choice and reason in the PR description; cite geozui4d PRs 14 and 15 for the loop line evidence.
- Post one signed comment each on #265 and #295 saying ADR-0016 is Accepted and the deferral is now unblocked.
- Verify with grep that no "Provisional" claim about ADR-0016 remains in docs/design.md or docs/roadmap.md, and run check_design_anchors.sh and a sit-rep dry-run before publishing.

### Actions
- [ ] Beyond the four sentences the issue lists, design.md has more that must move with the flip: the Sessions and roots `Status: decided, not proven` line (~181) becomes `decided`; the Decision register row for 0016 (~723, Status cell Provisional) becomes Accepted; the line ~732 "ADR-0016 stays `Provisional`" in the C1-c paragraph; and the glossary row (~70) defines `decided, not proven` BY ADR-0016 (ADR-0018 is still Provisional), so it needs rewording to a general definition, not just a tense change. The acceptance criterion "no sentence ... still says ADR-0016 is Provisional" needs a grep to confirm.
- [ ] The roadmap check for the onboarding line should be tied to the run's real record. `gh-issue 332 closed` shows the issue closed, not that the run passed; the plan should check the record (e.g. geozui4d#10 onboarding PR merged 2026-11-02, or 332 closed after parts 3 and 4) and say in the PR which was chosen and why. Cite the merged PRs (geozui4d PRs 14 and 15) in the ADR sentence.
- [ ] Add to the plan the design.md spots beyond the issue's list: Status line ~181, register row ~723, ~732, and the generalised `decided, not proven` glossary definition.
- [ ] Choose the onboarding-line check from the actual record of the run and state the choice and reason in the PR description; cite geozui4d PRs 14 and 15 for the loop line evidence.
- [ ] Post one signed comment each on #265 and #295 saying ADR-0016 is Accepted and the deferral is now unblocked.
- [ ] Verify with grep that no "Provisional" claim about ADR-0016 remains in docs/design.md or docs/roadmap.md, and run check_design_anchors.sh and a sit-rep dry-run before publishing.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 13:18 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the five open actions are mechanism: more design.md spots to update, which check records the onboarding run, citing the GeoZui4D pull requests, signed comments on #265 and #295, and a final grep plus anchor check; the owner decided the promotion itself)
**After**: issue-actions
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. The actions go to plan-task as plan inputs.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 13:20 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-423/plan.md` at `9c6c9830`

Flip ADR-0016 Status to Accepted (evidence: GeoZui4D PRs 14 and 15), update every dependent design.md and roadmap line (including the four extra design.md spots and a name-free glossary definition), give the two Direction lines checks (geozui4d#8 plus #332 for onboarding, geozui4d#9 for the loop), draft signed comments for #265 and #295 for the host to post, then grep, anchor check and sit-rep check. Open question: ADR-0018's promotion condition is now met too.

## Plan Review
**Status**: complete
**When**: 2026-11-09 13:23 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #423 — Promote ADR-0016 to Accepted: the GeoZui4D acceptance run passed the merge checkpoint (2026-11-09)
**Plan**: `.agent/work-plans/issue-423/plan.md` at `9c6c9830`
**Branch**: `feature/issue-423`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three docs files plus two drafted comments; one PR. |
| Issue alignment | Good | Covers every issue bullet and all six Issue Review actions (extra design.md spots at 181, 723, 732 and the Status-key row; onboarding check from the run's record; PRs 14 and 15 cited; #265/#295 comments; grep plus anchor check). Serves (as checked): "The long view (README Workspace goals) ... `docs/design.md#sessions-and-roots`, `docs/design.md#open-questions`"; both anchors are real headings. |
| File targeting | Good | ADR-0016, roadmap, design.md. Repo-wide grep (excluding work plans) finds no other ADR-0016 Provisional claim outside these three files. ADR-0018 not touched (file not listed; its paragraph in ADR-0016 and its register row stay Provisional). |
| Consequences | Good | `adr-status` strips leading `*`/`_` and reads the first word (`check_adr_status`, sitrep_checks.sh:380-410), so `**Accepted.**` reads `accepted`; the two deferral rows share that check and turn due. `combine` needs every ` ; ` part true, so the onboarding cell reads true only with both issues closed (verified: #332 CLOSED; geozui4d#8 CLOSED COMPLETED 2026-11-02T17:47:42Z by PR 10, merged 17:47:40Z). geozui4d#9 CLOSED COMPLETED 16:43:47Z by PR 14; #7 by PR 15; #265 and #295 OPEN. Baseline sitrep_checks on the worktree: the three target lines read unchecked/unchecked/false today. |
| Principle alignment | Good | Keep one current design, Verify before claiming, Only what's needed, project-agnostic: addressed. Docs-only, no test planned, which is correct. Small accuracy points below. |
| ADR compliance | Good | ADR-0008: first Status paragraph only; ADR-0017: design.md and Change log in the same PR; ADR-0018 left Provisional and raised as an owner question. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences]** (suggestion) — Change log row section names are off. The `decided, not proven` row at design.md:70 is in the Status key under `# The design` (line 46), not `## Glossary` (line 813); the line-362 tense edit is in `## Registry and adapters` (line 291), which the row omits. Name "The design (Status key), Sessions and roots, Registry and adapters, Decision register, Open questions".
2. **[Principle alignment]** (suggestion) — Status-key wording "(that ADR is `Provisional` until it does)" reads as Provisional implies not run, which ADR-0018 now contradicts (its condition, "when ADR-0016's own acceptance run passes", is met, yet it stays Provisional pending the owner). Drop the parenthetical or say "stays Provisional at least until then".
3. **[Consequences]** (suggestion) — Decision register row 0016: `in force` is right (definition at design.md:696), but the row says nothing of ADR-0018 superseding decision 3 for skills, which ADR-0016's own Status records. Follow the 0001 pattern ("Its trigger is scoped by ADR-0017") in the Decision cell, e.g. "Decision 3 is superseded for skills by ADR-0018".
4. **[Principle alignment]** (suggestion) — ADR-0016 Status: keep the original promotion condition visible as history (ADR-0001: accepted ADRs are history), e.g. "**Accepted** (2026-11-09). The promotion condition, the acceptance test named in #317 ..., was met by ...", rather than replacing it with evidence alone. Still within ADR-0008's status-note allowance.
5. **[Issue alignment]** (suggestion) — OQ-2 asks two things, "where is the acceptance run tracked, and who runs it?"; the planned answer covers only where. Add who ran it (the owner, through `/orchestrator` and `/run-issue` from the registered gz4d root).
6. **[Consequences]** (suggestion) — Drafted #265 comment calls PR 4 "the registration script, retiring `project/` and `projects/`". `register_project.sh` already exists (built by #332 PR 2, per design.md); #265's plan describes PR 4 as removal plus migration (the legacy fallback, project11 registration). Reword so the comment does not imply the script is unbuilt.
7. **[Consequences]** (suggestion) — Final pass: `sitrep_checks.sh` does not read the acceptance paragraph; the sit-rep skill's step-5 awk/python block does (`.claude/skills/sitrep/SKILL.md` ~728-756). Run that block on the worktree roadmap to confirm `acceptance_first` is unchanged. Widen the grep beyond `provisional` to `not proven`, `acceptance run` and `OQ-2` so line 362-style future-tense claims are caught. Expect the adapter and user-tier lines to stay unknown/false in a worktree (baseline today); they are not this PR's.

### Summary

The plan is complete and correctly targeted: the `adr-status` read, the ` ; ` combine rule and every external record it relies on check out, and ADR-0018 is left alone. The findings are wording and bookkeeping accuracy the implementer can fold in; none blocks implementation.

### Recommended Actions

- [ ] Change log row names The design (Status key) and Registry and adapters instead of Glossary.
- [ ] Status-key row: drop or soften "(that ADR is `Provisional` until it does)".
- [ ] Register row 0016: note ADR-0018's supersession of decision 3 for skills in the Decision cell.
- [ ] ADR-0016 Status: keep the promotion condition as history alongside the evidence.
- [ ] OQ-2 answer: say who ran the run, as well as where it was tracked.
- [ ] #265 comment: do not describe the registration script as pending PR 4 work.
- [ ] Final pass: run the sit-rep step-5 acceptance block and widen the grep.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 13:24 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (plan review approved with no must-fix; its seven suggestions are wording and verification details carried into the implement handoff)
**After**: plan
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. Suggestions carried to implementation: correct change-log section names; soften the Status-key parenthetical so it does not claim a Provisional ADR has had no test; note ADR-0018's supersession in the 0016 register row; keep the original promotion condition visible as history in the ADR Status; OQ-2's answer also says who ran the acceptance run; reword the #265 comment since register_project.sh already exists; final pass runs the sit-rep's step-5 block and widens the grep.

## Implementation
**Status**: complete
**When**: 2026-11-09 13:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-423 at `0c9ad7e2`

- `docs/decisions/0016-session-roots-and-the-user-tier.md` (994f1f1a): first Status paragraph starts `**Accepted** (2026-11-09)`; the original promotion condition stays as history beside the evidence (rolker/geozui4d#9 PR 14, rolker/geozui4d#7 PR 15, owner decision, #423). ADR-0008 note, ADR-0018 paragraph and all other sections untouched.
- `docs/roadmap.md` (7bbcb981): acceptance-case sentence "That run passed the merge checkpoint on 2026-11-09, and ADR-0016 (...) is Accepted"; OQ-2 sentence to past tense; onboarding line checked by `gh-issue 332 closed ; gh-issue rolker/geozui4d#8 closed`, loop line by `gh-issue rolker/geozui4d#9 closed`.
- `docs/design.md` (565effc6): Status-key `decided, not proven` row names no ADR and is softened (plan review 2); Sessions and roots `decided`, Now sentence says ADR-0016 Accepted and ADR-0018 still Provisional; Registry inventory sentence dated; register row 0016 `in force` with ADR-0018's supersession of decision 3 noted (review 3); C1-c Provisional sentence dropped; OQ-2 answered in place with where and who (review 5); change-log row names The design (Status key), Sessions and roots, Registry and adapters, Decision register, Open questions (review 1), 866 lines.
- `.agent/work-plans/issue-423/plan.md` (0c9ad7e2): #265 comment no longer implies `register_project.sh` is unbuilt (review 6); #295 comment says the deferral is now due.
- Final pass (review 7): `check_design_anchors.sh` exit 0; `sitrep_checks.sh --root <worktree>` reads the onboarding, loop and promoted lines true and both ADR-0016 deferrals true (due); adapter line unknown and user-tier line false, as at baseline in a worktree; step-5 block: `acceptance_first` identical to main's. Widened grep (`provisional`, `not proven`, `acceptance run`, `OQ-2`): remaining hits are ADR-0018 (not touched), ADR-0016's kept history paragraphs, the vocabulary definitions, the records-default "provisional", the deferral rows and historical change-log rows. Pre-commit on the branch's changed files, no SKIP: passed (no script suite reached).
- Not done here, by design: the #265 and #295 comments (host posts); ADR-0018 untouched.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-09 13:30 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-423 at `7126b1f2`
**Base**: main
**Depth**: Deep (reason: 305 changed lines incl. plan/progress; docs/decisions ADR governance file)
**Must-fix**: 2 | **Suggestions**: 1
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

### Findings
- [ ] (must-fix) Purpose paragraph still says the user tier "is built and not yet proven", contradicting the now-`decided` Sessions and roots it links; fix the sentence and add Purpose to the #423 change-log row's section list (recheck the 866 line count) — `docs/design.md:31-33`
- [ ] (must-fix) Review guide ADR table still says ADR-0016 "Status **Provisional** until #317's acceptance run in a registered project passes", and ADR-0018's row says "Provisional, promoted with 0016", which no longer holds; reviewers apply this table — `.agent/knowledge/principles_review_guide.md:51,53`
- [ ] (suggestion) Now block says ADR-0018 "is still Provisional; promoting it is the owner's call" without saying its own promotion condition (ADR-0018 Status and Acceptance: the same run) is now met; one clause would keep a reader from thinking it waits on another run — `docs/design.md:188-189`

Verified: sitrep_checks.sh reads the onboarding, loop and promoted Direction lines true and both ADR-0016 deferrals due; adr-status reads `**Accepted** (2026-11-09).` as accepted; ADR diff is one hunk in Status (ADR-0008 and ADR-0018 paragraphs intact); roadmap acceptance first sentence unchanged; check_design_anchors.sh exit 0; design.md 865 -> 866; pre-commit (venv) passed on the three docs; gh confirms geozui4d#8 closed 11-02 by PR 10, #9 closed by PR 14 and #7 by PR 15 on 11-09. Cross-model: gemini and codex both completed, no issues.
