---
issue: 320
---

# Issue #320 — cross_model_review: run Gemini/Codex at the Standard tier and pass the plan's Approach as context

## Issue Review
**Status**: complete
**When**: 2026-09-22 12:52 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #320

### Scope Assessment

**Well-scoped?** Mostly yes. The issue bundles two distinct behavior changes — (1) moving cross-model dispatch from Deep-only to Standard+Deep, and (2) adding the plan's `## Approach` as context to the shared prompt. Both touch the same three files (`review-code/SKILL.md`, `review_depth_classification.md`, `cross_model_review.sh`), so bundling is defensible, but they are independently shippable and independently revertable. Worth noting as a split option during planning rather than treating it as a hard requirement.

**Right repo?** Yes — this is workspace review-loop infrastructure (`.claude/skills/`, `.agent/scripts/`), not project content.

**Dependencies**: Explicit and verified. #313 (result validation for the codex/claude/copilot arms) is open, unimplemented, and touches `cross_model_review.sh`'s per-agent invocation path — the same file this issue's item 2 edits (shared prompt construction). The issue correctly sequences itself after #313; ADR-0015's own Consequences section already names #313 as pending against this script, confirming the ordering is sound, not just asserted.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Capture decisions, not just implementations | Action needed | ADR-0015's Decision section describes cross-model dispatch mechanics (parallel-sync, timeouts, per-agent failure) but is silent on *when* it runs. Moving the trigger from Deep-only to Standard+Deep changes a fact ADR-0015's Consequences section states outright ("`review-code` dispatches all cross-model reviewers in one `--agents ...` call") without a tier qualifier. Per ADR-0008, a status-line/References addendum to 0015 (not a new ADR) can carry this without reopening the Decision. |
| The workspace serves the product | Watch | Cross-model dispatch (~2.5–3.5 min per run, per the issue) currently only taxes Deep-tier PRs; this moves it onto the common case (Standard). The issue's own rationale — real defects caught, otherwise-idle quota — is reasonable, but the cost tradeoff should be visible in the PR description, not just implied by the issue. |
| Only what's needed | Watch | Same cost point from the other side: confirm Light stays static-only (issue says so) so the smallest changes don't pick up the added latency. |
| A change includes its consequences | OK (if plan followed) | Issue already scopes updating both the skill's tier table and the classification doc's rationale, matching the consequences map row for `review-code` skill changes. Item 2 also explicitly requires a new test. |
| Workspace vs. project separation | OK | Workspace-only; no project coupling. |
| Enforcement over documentation | Watch | Tier selection is LLM-interpreted from markdown tables, not mechanically enforced — pre-existing pattern, not a new gap introduced by this issue. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Yes | Touches `cross_model_review.sh` and `review-code`'s dispatch step directly (per the ADR's own applicability trigger). The mechanics (parallel, per-agent timeout, `EXIT=` triplets) are unaffected — only the tier gate changes. Recommend an ADR-0008-style addendum noting the Standard+Deep trigger, per the Action-needed row above. |
| 0013 — progress.md entry-type vocabulary | No | No new entry type or shape implied by either change. |
| 0011 — Project-type adapter contract | No | No adapter-contract surface touched. |

### Consequences

- `review-code` SKILL.md tier table → `review_depth_classification.md` tier table and rationale (issue already scopes this).
- `cross_model_review.sh` prompt-building change → `test_cross_model_review.sh` (issue already requires a test for plan-context presence/absence).
- Not currently scoped: an ADR-0015 addendum recording the tier-scope change (see Action-needed row above) — should be added during implementation or flagged as explicit follow-up.

### Recommendations

- Add a one-line ADR-0008 addendum to ADR-0015 (status-line or References) noting cross-model dispatch now triggers at Standard+Deep rather than Deep only, so the ADR stays accurate without a supersession.
- Confirm in the work plan that implementation does not start until #313 merges, given both issues edit `cross_model_review.sh`'s prompt/dispatch path and #313 is being planned in parallel right now — rebase risk is real, not hypothetical.
- Consider noting in the PR description the expected added latency/quota cost of running cross-model review on every Standard-tier PR, so the tradeoff is visible to reviewers rather than only argued in the issue.

### Actions
- [ ] ADR-0015's Decision section describes cross-model dispatch mechanics (parallel-sync, timeouts, per-agent failure) but is silent on *when* it runs. Moving the trigger from Deep-only to Standard+Deep changes a fact ADR-0015's Consequences section states outright ("`review-code` dispatches all cross-model reviewers in one `--agents ...` call") without a tier qualifier. Per ADR-0008, a status-line/References addendum to 0015 (not a new ADR) can carry this without reopening the Decision.
- [ ] Add a one-line ADR-0008 addendum to ADR-0015 (status-line or References) noting cross-model dispatch now triggers at Standard+Deep rather than Deep only, so the ADR stays accurate without a supersession.
- [ ] Confirm in the work plan that implementation does not start until #313 merges, given both issues edit `cross_model_review.sh`'s prompt/dispatch path and #313 is being planned in parallel right now — rebase risk is real, not hypothetical.
- [ ] Consider noting in the PR description the expected added latency/quota cost of running cross-model review on every Standard-tier PR, so the tradeoff is visible to reviewers rather than only argued in the issue.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 12:55 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed to planning with the four review actions folded in: ADR-0015 addendum for the tier change (ADR-0008 style), implementation blocked on #313 merging (same script; merge main into this branch first), the added Standard-tier latency/quota cost stated in the PR description with Light staying static-only, and one PR unless review gets unwieldy.

## Plan Authored
**Status**: complete
**When**: 2026-09-22 13:00 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-320/plan.md` at `80ebb46`

Plan covers two changes to cross_model_review.sh's dispatch: (1) moving
cross-model adversarial dispatch from Deep-only to Standard+Deep in the
review-code skill and the depth-classification doc, Light unchanged; (2)
appending the work plan's `## Approach` section (capped at 200 lines) as
context in the shared prompt, after the diff and before the output-format
footer, absent when no plan exists or under `--no-progress`; plus tests,
an ADR-0015 addendum (ADR-0008 style: Status-line note + References entry,
no Decision/Consequences rewrite), and a PR description stating the added
Standard-tier latency/quota cost. Implementation is explicitly blocked on
issue #313 merging to main and this branch running `git merge origin/main`
first, per the owner's checkpoint decision.
