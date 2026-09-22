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
**Plan**: `.agent/work-plans/issue-320/plan.md` at `535ee62`

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

## Plan Review
**Status**: complete
**When**: 2026-09-22 13:08 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: ready

**Issue**: #320 — cross_model_review: run Gemini/Codex at the Standard tier and pass the plan's Approach as context
**Plan**: `.agent/work-plans/issue-320/plan.md` at `535ee62`
**Branch**: `feature/issue-320`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Five files, two coupled behaviours, one PR — matches the owner's checkpoint decision; the split line is pre-recorded if review gets unwieldy. |
| Issue alignment | Good | Both issue items covered; Light stays static-only; "context, not the subject" framing carried into the prompt heading; out-of-scope (Gemini/Codex reviewing plans) respected. |
| File targeting | Needs work | Files listed are right, but two in-file surfaces are unnamed: the tier **Report format** rows in `review_depth_classification.md` (finding 1) and the gemini `## Tool Use` paragraph in `cross_model_review.sh` (finding 3). |
| Consequences | Needs work | The "179 existing assertions, unaffected" claim is not safe — an existing test writes the exact `plan.md` the new code reads (finding 2). AGENTS.md's script-reference row for `cross_model_review.sh` also becomes incomplete (finding 6). |
| Principle alignment | Good | Only what's needed (Light untouched, cost stated in the PR); consequences travel in the same PR; ADR addendum keeps the decision record accurate. |
| ADR compliance | Good | The ADR-0008 addendum shape fits — see finding 4 for the wording. |
| ROS conventions | N/A | Workspace-only plan. |

### Findings

1. **[File targeting / Consequences]** — Moving 5e to Standard without moving the report section leaves the findings nowhere to land. `review_depth_classification.md` gives Standard "**Report format**: Full report with all sections" and Deep "plus a Cross-Model Reviews section with per-agent findings"; `review-code/SKILL.md` carries the same split (Cross-Model Reviews is a body section, omitted only in the Light condensed format). The plan's step 1 says the opposite — "Deep differs only in the report's Cross-Model Reviews section" — which would dispatch Gemini/Codex at Standard and then drop their output. Fix: Standard's Report-format row gains the Cross-Model Reviews section too, and the plan states plainly what still distinguishes Deep (currently: nothing but the classification thresholds — worth saying so explicitly rather than inventing a difference).

2. **[Consequences / Tests]** — Behaviour when `plan.md` exists but has no `## Approach` (or an empty one) is unspecified, and it is not hypothetical: `test_branch_mode_filter_survives_noprefix` (test_cross_model_review.sh:1249) writes `BRANCH BOOKKEEPING` to `${MOCK_REPO}/.agent/work-plans/issue-42/plan.md` — exactly the path the new code reads — and then asserts that string is absent from the whole prompt file. Any implementation that falls back to the whole plan, or emits the heading with empty content, breaks that #312 test. Specify: no `## Approach`, or an empty extraction → omit the `## Plan Context` section entirely; add that as a fifth test case. Same rule answers "first 200 lines when the section is shorter": shorter → emit what there is; longer → truncate and **mark the truncation in the prompt** (e.g. `_(Approach truncated at 200 lines.)_`) so a reviewer does not read a cut-off Approach as the complete one and file a false divergence.

3. **[File targeting]** — The gemini-only `## Tool Use` footer currently tells the agent "files under `.agent/work-plans/` (plan and progress bookkeeping) are deliberately excluded". After this change a work-plans file's content *is* in the prompt, so that paragraph contradicts the new section. Reword in the same commit: excluded *from the diff*; the plan's Approach appears above as context only, not for review.

4. **[ADR compliance]** — The addendum *shape* is correct: ADR-0015's Decision is about dispatch mechanics and its Consequences never qualify the trigger by tier, so a status-line note plus a References entry adds no Consequence and rewords no Decision — squarely inside ADR-0008's permitted set, no supersession needed. The proposed *wording* is off: "Scoped exception in issue #320" borrows ADR-0008's exception phrasing for something that is not an exception to this ADR (and ADR-0008's example points at ADRs, not issues). Prefer a navigational note, e.g. "Trigger tier for cross-model dispatch is recorded in issue #320 (Standard + Deep); dispatch mechanics unchanged."

5. **[Approach / Tests]** — Two details in step 2 to pin down before implementing:
   - The `$NO_PROGRESS` guard is redundant in the normal case (under `--no-progress` `WORK_PLANS_DIR` is a fresh `mktemp -d`, so `plan.md` cannot exist) and only bites in the `--no-progress` + `--work-plans-dir` combination, where `CLI_WORK_PLANS_DIR` wins the precedence chain. Keeping it is defensible, but the planned test "`--no-progress` → absent even if a plan exists" can only be written by constructing that combination — say so in the plan, or drop the guard and let the existence check carry it.
   - The new tests must place `plan.md` in the *resolved* `WORK_PLANS_DIR` (the same directory the `review-<agent>-prompt.md` files land in), not merely in the mock repo's working tree; a plan written where the script never looks makes the "present" case fail and the "absent" case pass vacuously. Name the four/five functions (`test_plan_context_present`, `_absent`, `_truncated`, `_no_progress`, `_no_approach_section`) and remember to add each to the `# ---- Run all tests ----` list at the end of the suite — a function not listed there silently never runs.

6. **[Consequences]** — `AGENTS.md`'s script-reference row for `cross_model_review.sh` ends "the embedded diff excludes `.agent/work-plans/**`", which after this change tells only half the story. AGENTS.md is an Ask-First file, so either get the one-line amendment approved with the PR or note the deferral explicitly rather than leaving the row quietly stale.

### Summary

The plan is sound and correctly sequenced, and the bloat risk that motivated #312 is adequately bounded — only the `## Approach` section, capped at 200 lines, is re-admitted, and it is re-admitted as labelled context outside the diff fence rather than as diff content. Two specification gaps would produce broken output if implemented literally (Standard's report format, and the absent-`## Approach` case that an existing test walks straight into); both are small and resolvable inline. Ready for implementation with the actions below.

### Recommended Actions

- [ ] Add the Cross-Model Reviews section to Standard's report format in `review_depth_classification.md` and `review-code/SKILL.md`, and state what still distinguishes Deep (finding 1)
- [ ] Specify: no/empty `## Approach` → omit `## Plan Context` entirely; truncation at 200 lines is marked in the prompt; add both as test cases (finding 2)
- [ ] Reword the gemini `## Tool Use` paragraph so "work-plans excluded" reads as "excluded from the diff" (finding 3)
- [ ] Reword the ADR-0015 status-line note as a navigational pointer, not a "scoped exception" (finding 4)
- [ ] Name the new test functions, put the fixture `plan.md` in the resolved `WORK_PLANS_DIR`, and add every new function to the suite's run list (finding 5)
- [ ] Decide on the `AGENTS.md` script-reference row — amend with owner approval or note the deferral (finding 6)
- [ ] Procedural gate unchanged: confirm #313 has merged to `main` (still OPEN as of this review) and run `git merge origin/main` on this branch before the first implementation commit

## Checkpoint
**Status**: complete
**When**: 2026-09-22 13:13 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise with all six round-1 items folded in: the Cross-Model Reviews report section moves to Standard+Deep with the dispatch (not Deep-only); absent or empty ## Approach omits the plan-context section and a 200-line truncation is marked in the prompt (and the existing noprefix test's bookkeeping plan.md must still stay out); Gemini Tool Use footer reworded to "excluded from the diff"; ADR-0015 addendum as a navigational pointer; named test functions with the fixture plan.md in the resolved WORK_PLANS_DIR; the AGENTS.md cross_model_review.sh row update is approved as part of this PR. Implementation still gated on #313 merging.
