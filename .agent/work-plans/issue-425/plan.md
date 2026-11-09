# Plan: Promote ADR-0018 to Accepted: its condition (ADR-0016's acceptance run) passed on 2026-11-09

## Issue

https://github.com/rolker/agent_workspace/issues/425

## Context

ADR-0018 is `Provisional` until ADR-0016's own acceptance run passes. That run passed on 2026-11-09 (GeoZui4D
rolker/geozui4d#9 PR 14 and #7 PR 15, both from the project root) and ADR-0016 was promoted by #423 (PR 424).
Owner decision, 2026-11-09: promote ADR-0018 too. A status-line edit under ADR-0008; no Decision changes.
Same shape as the plan for #423 (`.agent/work-plans/issue-423/plan.md`).

## Approach

1. **ADR-0018 Status** (`docs/decisions/0018-plugin-based-skill-delivery.md`, lines 5-13). `**Provisional.**`
   becomes `**Accepted** (2026-11-09).`; the supersession text of the first paragraph stays. The "Promote to
   Accepted when ..." paragraph is folded into history, as ADR-0016's Status does: the original condition
   (ADR-0016's acceptance run) kept, plus one evidence sentence: the full loop ran from the GeoZui4D root for
   rolker/geozui4d#9 (PR 14) and rolker/geozui4d#7 (PR 15), the GeoZui4D session reported that every
   dispatched phase found the prefixed skills (its own report, 2026-11-09), ADR-0016 was promoted by #423
   (PR 424), and the owner promoted this ADR the same day (#425). Keep the ADR-0008 sentence (flipping is a
   status-line edit) in past/present-correct form. The Acceptance section (~337) stays as the decision-time
   description. Decision, Consequences, Alternatives untouched.
2. **`docs/design.md`**.
   - Sessions and roots Now block (~188-190): the clause "is still Provisional; its own promotion condition,
     the same run, is met, and promoting it is the owner's call" becomes "is Accepted too (2026-11-09,
     #425)". Re-read the paragraph so it still flows.
   - Decision register row 0018 (~727): Status cell `Provisional` becomes `in force`.
   - Change log: one 2026-11-09 row (Sessions and roots, Decision register) citing #425, with `wc -l` taken
     after all edits. Status key row (~70) needs no change (names no ADR). Dated history rows (799, 813) stay.
3. **`.agent/knowledge/principles_review_guide.md`** row 0018 (~53): "Status **Provisional**; its own
   promotion condition ... owner's call" becomes "Status **Accepted** (2026-11-09, #425)".
4. **ADR-0016**: no edit; its Status names no status for 0018 (checked: it only describes the supersession).
5. **Final pass**: first Status line of ADR-0018 starts `**Accepted` (`sitrep_checks.sh adr-status
   docs/decisions/0018-plugin-based-skill-delivery.md accepted`); `.agent/scripts/check_design_anchors.sh`
   exits 0; repo-wide `grep -rniE provisional` (not only `docs/`; exclude `.agent/work-plans/` and dated
   history rows) read for any remaining claim about ADR-0018; `sitrep_checks.sh --root <worktree>` still
   parses cleanly.

## Files to Change

| File | Change |
|------|--------|
| `docs/decisions/0018-plugin-based-skill-delivery.md` | Status: Accepted (2026-11-09); condition folded into history with one evidence sentence |
| `docs/design.md` | Sessions and roots Now clause, register row 0018, Change log row |
| `.agent/knowledge/principles_review_guide.md` | Row 0018 status sentence |

## Prior Art

Nothing new is built. Follows the #423 plan and ADR-0016's Status wording (condition kept as history beside
one evidence sentence).

## Serves

The long view (README Workspace goals): what is proven is recorded as proven.
`docs/design.md#sessions-and-roots`.

## Design Picture

Yes, status text only: `docs/design.md#sessions-and-roots` (Now block) and the Decision register change in
this PR (ADR-0017). No change to how the parts fit.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Every live Provisional claim about ADR-0018 moves in this PR; the repo-wide grep proves it |
| Verify before claiming | Evidence names only what the issue records; "found the prefixed skills" is worded as the GeoZui4D session's own report; the sit-rep check and a direct read confirm the status word |
| Only what's needed | Status text only; no Decision or mechanism changes |
| Workspace is project-agnostic | GeoZui4D appears only as record (ADR Status), as issue and PR references |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0008 | Yes | Status-line edit only; original condition kept as history |
| ADR-0016 | Checked | Needs no edit (names no status for 0018) |
| ADR-0017 | Yes | design.md and Change log row updated in the same PR |
| ADR-0018 | Yes | Subject |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| ADR-0018 Status word | design.md Now clause, register row, review guide row | Yes |
| design.md line count | Change log `wc -l` | Yes |
| ADR Status | `adr-status` check, sit-rep | Yes (step 5) |

## Open Questions

None for the owner. Mechanism choice (register word `in force`, per the other Accepted rows) is made above.

## Estimated Scope

Single PR, docs only.
