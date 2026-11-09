---
issue: 425
---

# Issue #425 — Promote ADR-0018 to Accepted

## Issue Review
**Status**: complete
**When**: 2026-11-09 14:06 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #425

### Scope Assessment

**Well-scoped?** Yes — a status-line flip plus four dependent text spots; same shape as #423 / PR 424.
**Right repo?** Yes — workspace (ADR, design.md, review guide).
**Serves**: "The long view" (what is proven is recorded as proven) — `docs/design.md#sessions-and-roots`
**Design picture?** Changes Sessions and roots (Now block, register row) — status text only; the owner's decision is recorded in the issue, so no re-ask.
**Dependencies**: none (follow-up to #423, merged as PR 424; #351 separate).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | The design.md spots checked: Sessions and roots Now block (lines ~188-190, "is still Provisional; ... promoting it is the owner's call"); register row 0018 (line 727, Status cell Provisional -> `in force`); Status key `decided, not proven` (line 70) names no ADR, no 0018 example, so no change needed; change-log row for 2026-11-09 with section names and the new `wc -l`. Change-log lines 799 and 813 are dated history and stay as written. Anchor check will confirm. |
| Verify before claiming | Watch | Evidence sentence must cite only what the issue records (GeoZui4D #9 and #7 drives, #423, owner decision 2026-11-09); the "found every prefixed skill" claim is the session's report, so word it as reported. |
| Only what's needed | OK | No Decision of ADR-0018 changes. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0008 | Yes | Status-line edit only; keep the original condition as history. |
| 0016 | Checked | Its Status paragraph (lines 22-27) describes the supersession of decision 3 and the settings.local.json exception, and names no status for 0018; no edit needed. |
| 0017 | Yes | design.md change in the same PR, with Change log row. |
| 0018 | Yes | Status first paragraph (line 5) and the "Promote to Accepted when..." paragraph (lines 11-13) both need rewording so none says it waits on a run. The Acceptance section (line 337) is a decision-time description of how the run counts; leave it. |

### Consequences

- `.agent/knowledge/principles_review_guide.md:53`: row ends "Status **Provisional**; its own promotion condition, the same GeoZui4D run, is met, and promoting it is the owner's call" -> Accepted with date.
- Repo-wide grep (outside work-plans) finds no other live Provisional claim about ADR-0018; hits on design.md 799/813 are dated change-log history.

### Recommendations

- ADR-0018: replace the first Status paragraph's `**Provisional.**` with `**Accepted** (2026-11-09)`, keep the supersession text, and fold the "Promote to Accepted when..." paragraph into history (original condition plus one evidence sentence naming the two GeoZui4D drives, #423 and the owner decision), as ADR-0016's Status does.
- design.md: rewrite the Now-block clause (~188-190) to say ADR-0018 is Accepted too, set register row 0018 to `in force`, and add a 2026-11-09 Change log row (Sessions and roots, Decision register) with the correct `wc -l`.
- Review guide row 0018: replace the Provisional sentence with Accepted (2026-11-09, #425).
- Leave ADR-0016 untouched (it names no status for 0018); verify with `adr-status` for 0018, `check_design_anchors.sh`, and `sitrep_checks.sh --root <worktree>`.

### Actions
- [ ] The design.md spots checked: Sessions and roots Now block (lines ~188-190, "is still Provisional; ... promoting it is the owner's call"); register row 0018 (line 727, Status cell Provisional -> `in force`); Status key `decided, not proven` (line 70) names no ADR, no 0018 example, so no change needed; change-log row for 2026-11-09 with section names and the new `wc -l`. Change-log lines 799 and 813 are dated history and stay as written. Anchor check will confirm.
- [ ] ADR-0018: replace the first Status paragraph's `**Provisional.**` with `**Accepted** (2026-11-09)`, keep the supersession text, and fold the "Promote to Accepted when..." paragraph into history (original condition plus one evidence sentence naming the two GeoZui4D drives, #423 and the owner decision), as ADR-0016's Status does.
- [ ] design.md: rewrite the Now-block clause (~188-190) to say ADR-0018 is Accepted too, set register row 0018 to `in force`, and add a 2026-11-09 Change log row (Sessions and roots, Decision register) with the correct `wc -l`.
- [ ] Review guide row 0018: replace the Provisional sentence with Accepted (2026-11-09, #425).
- [ ] Leave ADR-0016 untouched (it names no status for 0018); verify with `adr-status` for 0018, `check_design_anchors.sh`, and `sitrep_checks.sh --root <worktree>`.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 14:06 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the five open actions are mechanism: which design.md spots change, the ADR Status wording with the condition kept as history, the review-guide row, leaving ADR-0016 alone, and the verification commands; the owner decided the promotion)
**After**: issue-actions
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. The actions go to plan-task as plan inputs.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 14:07 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-425/plan.md` at `a014caf1`

Status-line promotion of ADR-0018 (condition folded into history with one evidence sentence), plus the design.md Now clause, register row and Change log row, and the review-guide row; ADR-0016 needs no edit. Single docs-only PR, no owner questions.
