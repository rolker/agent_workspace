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
