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

## Plan Authored
**Status**: complete
**When**: 2026-09-22 13:17 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-320/plan.md` at `b248f3c`

Revision folding in all six round-1 `## Plan Review` findings (owner
checkpoint: revise): Cross-Model Reviews report section now moves to
Standard+Deep together with dispatch, not left Deep-only; plan-context
section is omitted (not emptied) when plan.md or its `## Approach` is
absent/empty, with `test_branch_mode_filter_survives_noprefix`'s existing
no-Approach fixture confirmed to still pass; truncation past 200 lines
now carries a visible in-prompt marker; gemini's Tool Use footer reworded
to "excluded from the diff"; ADR-0015 addendum reworded as a navigational
pointer rather than "scoped exception"; five named test functions with
fixtures in the resolved WORK_PLANS_DIR, added to the suite's run list;
AGENTS.md's cross_model_review.sh row update added (owner-approved).
#313-merge-first gate unchanged.

## Plan Review
**Status**: complete
**When**: 2026-09-22 13:20 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: ready

**Issue**: #320 — cross_model_review: run Gemini/Codex at the Standard tier and pass the plan's Approach as context
**Plan**: `.agent/work-plans/issue-320/plan.md` at `b248f3c`
**Branch**: `feature/issue-320`
**Round**: 2 (round 1 reviewed `535ee62`; owner checkpoint decision: revise)

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Six steps, six files, one PR; split line still pre-recorded. |
| Issue alignment | Good | Both issue items covered; Light untouched; "context, not the subject" carried in the heading text; plan/issue review by Gemini/Codex still out of scope. |
| File targeting | Good | All six files named, each mapped to a numbered step. `AGENTS.md` now present with the owner's approval recorded inline. |
| Consequences | Good | Report-format row travels with the dispatch change; the noprefix test's fixture is reasoned about explicitly rather than asserted away; AGENTS.md row no longer left stale. |
| Principle alignment | Good | Only what's needed; consequences in the same PR; ADR addendum keeps the record accurate. |
| ADR compliance | Good | ADR-0008: navigational Status-line pointer + References entry, no Decision/Consequences edit — permitted, no supersession. |
| ROS conventions | N/A | Workspace-only plan. |

### Round-1 items

| # | Round-1 finding | Status in `b248f3c` |
|---|---|---|
| 1 | Report section left Deep-only while dispatch moved to Standard | Resolved — step 1 moves Standard's Report-format row with the dispatch and states plainly that nothing but the classification thresholds distinguishes Deep afterwards. |
| 2 | Absent/empty `## Approach` unspecified; truncation unmarked; noprefix test fixture | Resolved — omit entirely (never a fallback to the whole plan, never an empty heading); truncation carries `_[truncated: N more lines]_`; the line-1237 test's no-`## Approach` fixture is named and the pass reasoning stated. |
| 3 | Gemini `## Tool Use` footer contradicts the new section | Resolved — reworded to "excluded **from the diff**" in step 2, and the file is in Files to Change for it. |
| 4 | "Scoped exception" wording on the ADR-0015 addendum | Resolved — replaced with the navigational pointer sentence. |
| 5 | Tests unnamed; fixture placement; run-list omission risk | Resolved — five named functions, fixtures in the resolved `WORK_PLANS_DIR`, explicit instruction to add each to the run list; the `--no-progress` case correctly identifies `--no-progress` + `--work-plans-dir` as the only combination that can exercise it. |
| 6 | `AGENTS.md` script-reference row goes stale | Resolved — step 6, owner-approved, in Files to Change. |

### Findings

No blocking findings. Three notes for the implementer, none of which need another planning round:

1. **[File targeting — suggestion]** Step 1 says "step 5e's activation" and "the tier summaries"; in `review-code/SKILL.md` that is three separate strings, not two: the specialist-list parenthetical at line 61 (`… run in parallel by cross_model_review.sh (Deep only)`), the Deep-tier dispatch bullet at line 212, and `**Activates at**: Deep only` at line 309. Line 554's Light condensed-format note (skip Cross-Model) stays as-is and is correct. Grep `Deep only` before opening the PR.
2. **[Approach — suggestion]** The `awk` extraction to "the next `## ` heading" is not fence-aware, so a fenced block inside a plan's Approach containing a line that begins `## ` would end the section early. The failure mode is benign (a shorter context block, never a longer one) and `progress_read.py` is the only fence-aware parser in the workspace; not worth solving here, but worth a one-line comment at the awk so a future reader does not treat it as a bug.
3. **[Scope — follow-up, not this PR]** Once this lands, Deep and Standard dispatch the same specialists and produce the same report sections; the tiers differ only in the thresholds that select them. Recording that in the doc (as step 1 does) is the right move for this PR, but it leaves an open governance question — does Deep still earn a separate tier, or should it gain something? Worth a follow-up issue after the PR merges, not a change here.

### Summary

All six round-1 findings are addressed substantively, not cosmetically — item 2 in particular now specifies the omit-don't-empty rule and reasons about the existing test fixture rather than asserting the suite is unaffected. The plan is ready for implementation once the #313 gate opens (#313 was still OPEN at the time of this review; the precondition is correctly retained in Open Questions).

### Recommended Actions

- [ ] Grep `Deep only` in `review-code/SKILL.md` — three strings to update (lines 61, 212, 309), not two (finding 1)
- [ ] Add a one-line comment at the `## Approach` awk noting it is not fence-aware (finding 2)
- [ ] Procedural gate unchanged: confirm #313 has merged to `main`, then `git merge origin/main` on this branch before the first implementation commit
- [ ] After merge, consider a follow-up issue on what (if anything) should still distinguish the Deep tier (finding 3)

## Checkpoint
**Status**: complete
**When**: 2026-09-22 13:23 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Plan approved at plan-review round 2 (75e7005, Plan b248f3c) with the three non-blocking notes folded into implementation (all three "Deep only" strings in review-code SKILL.md; a not-fence-aware comment on the Approach extractor; a post-merge follow-up on what still distinguishes Deep). HOLD: implementation does not start until #313 merges to main and origin/main is merged into this branch; the host dispatches it then.

## Implementation
**Status**: complete
**When**: 2026-09-22 14:05 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-320 at 9a69727
**Plan**: `.agent/work-plans/issue-320/plan.md` at `b248f3c`

Implemented on top of `feature/issue-313`, merged into this branch at
`6ed80f6` by owner decision in place of the plan's "wait for #313 to reach
`main`" gate. `_cli_review.sh`, `_agy_review.sh`, and `run_agent_sync` /
the availability precheck were left untouched; #320's script edits are
confined to the shared-prompt builder and the gemini Tool Use footer, and
its tests were added alongside #313's mocks rather than reworking them.

### What landed

| Commit | Change |
|---|---|
| `a50953c` | Tier change: `.claude/skills/review-code/SKILL.md` (tier list, step-5 dispatch list, 5e **Activates at**, specialist parenthetical, Cross-Model report-section note) and `.agent/knowledge/review_depth_classification.md` (Standard gains the cross-model specialist and the Cross-Model Reviews report row; a paragraph states plainly that nothing but the classification thresholds now distinguishes Deep). Light unchanged. No `Deep only` string survives in either file. |
| `ece0af3` | `cross_model_review.sh`: a `## Plan Context` section built once into the shared prompt, after the diff fence and before the output-format footer, from `${WORK_PLANS_DIR}/plan.md`'s `## Approach`; capped at 200 lines with a visible truncation marker; framed as context ("flag divergences between the diff and this plan, but do not review the plan itself"); omitted entirely when the file is absent, the section is absent or blank, or `--no-progress` is set. A comment records that the awk extractor is not fence-aware and that its failure mode is a shorter block, never a longer one. Gemini's `## Tool Use` footer now says work-plans files are excluded **from the diff** and points at the context block. Five new tests plus the `AGENTS.md` script-reference row (owner-approved). |
| `9a69727` | ADR-0015 addendum in ADR-0008 style — Status-line navigational pointer plus a References entry for #320, no Decision/Consequences edit — and plan.md synced inline (`## Implementation Notes` recording the branch-on-#313 decision; the superseded precondition and the stale pre-#313 assertion count corrected). |

### Tests

`test_plan_context_present`, `_absent_no_plan`,
`_absent_no_approach_section` (covers both no-heading and empty-section),
`_truncated`, `_no_progress` (the `--no-progress` + `--work-plans-dir`
combination, the only one where a plan.md can exist), each writing its
fixture into the resolved `WORK_PLANS_DIR` and each registered in the
suite's run list.

- `bash .agent/scripts/tests/test_cross_model_review.sh` — 327 passed, 0
  failed (24 of them new here; `test_branch_mode_filter_survives_noprefix`
  and `test_prompt_tool_use_guidance` still pass unchanged).
- `bash .agent/scripts/tests/run_script_tests.sh` — all 23 suites passed
  in 87s, no temp leaks.

No real agy/codex/claude/copilot prompt was run; all dispatch went through
the suite's mocks.

### Deviations

- The plan's #313 precondition was replaced by the owner's merge decision
  (recorded in plan.md and above).
- The plan quoted 179 existing assertions; on top of #313 the suite is at
  327. Corrected in plan.md.
- The plan-review follow-up note ("what still distinguishes Deep") is left
  for the PR body, per the plan review's instruction that it is a
  post-merge follow-up and not a code change.

### Actions
- [ ] PR body must state the added Standard-tier cost (cross-model dispatch
      latency ~2.5-3.5 min bounded by `AGENT_TIMEOUT`/`AGY_PRINT_TIMEOUT`,
      plus Gemini/Codex/Copilot quota; Light unaffected) and raise the
      post-merge follow-up on what should still distinguish the Deep tier.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 14:15 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-320 at `f26ca59`
**Base**: feature/issue-313 (reviewing #320's own commits only; #313 is in its own loop)
**Depth**: Standard (reason: governance + enforcement files — skill, knowledge tier doc, ADR, AGENTS.md — plus a prompt-builder change)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) `printf | head` under `set -euo pipefail` aborts the whole script (exit 141) when the Approach section exceeds the pipe buffer (~64KB) — use a here-string or `awk 'NR<=n'` — `.agent/scripts/cross_model_review.sh:857`
- [x] (must-fix) Plan context is emitted raw: truncation at 200 lines (or the awk stop inside a fence) can leave a ``` fence open, swallowing the `## Output Format` footer into a code block — close an odd fence count before appending — `.agent/scripts/cross_model_review.sh:850-864`
- [x] (suggestion) Extractor stops only at `^## `; an H1 or `---` after Approach leaks later sections, and the comment's "never content from another section" guarantee is then inaccurate — `.agent/scripts/cross_model_review.sh:843`
- [x] (suggestion) No test fixture has a fenced code block in Approach, nor an H1/`---` after it — the two failure modes above are untested — `.agent/scripts/tests/test_cross_model_review.sh:1279`
- [x] (suggestion) Plan says the suite runs 327 assertions; it now runs 358 — `.agent/work-plans/issue-320/plan.md:59`

## Implementation
**Status**: complete
**When**: 2026-09-22 14:40 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-320 at df3723b
**Plan**: `.agent/work-plans/issue-320/plan.md` at `b248f3c`
**Round**: 1 (address-findings on the `## Local Review (Pre-Push)` at `f26ca59`)

All five findings from the round-1 pre-push review resolved in `df3723b`;
every box in that entry is now checked. Only `cross_model_review.sh`'s
plan-context block, the test suite and plan.md were touched — #313's
`_cli_review.sh`, `_agy_review.sh` and `run_agent_sync` were not.

### Findings resolved

| # | Finding | Resolution |
|---|---|---|
| 1 | must-fix — `printf \| head` under `pipefail` aborts with 141 on an Approach past the pipe buffer | Both the line count and the 200-line cap now use here-strings (`wc -l <<<`, `head -n N <<<`); no pipe, no SIGPIPE. Reproduced the old failure standalone (exit 141 on a 400 KB value) before fixing, so the regression is real and the new test covers it. |
| 2 | must-fix — an unclosed fence can swallow the `## Output Format` footer | The emitted body's fence toggles are counted (a closer must match the marker that opened it, so ``` inside a `~~~` block is content) and the matching closer is emitted before the truncation marker. Covers both causes: the cap landing mid-fence and the extractor stopping inside one. |
| 3 | suggestion — extractor stopped only at `^## `, leaking past an H1 or `---` | Stops at any H1/H2 heading or a thematic break. The comment now states the guarantee it actually keeps — possibly shorter, never longer, never content from a later section — and names fence balancing as what keeps the prompt well-formed after an early stop. |
| 4 | suggestion — no fence / H1 / `---` fixtures | Three new test functions, all registered: `test_plan_context_large_approach` (>400 KB Approach, asserts exit 0 — the SIGPIPE guard), `test_plan_context_fence_balanced` (a complete fence, and a fence straddling the cut: block fence count even, footer still a heading), `test_plan_context_stops_at_h1_or_rule` (H1 and `---` after Approach). |
| 5 | suggestion — plan.md's stale assertion count | Corrected to 379 at the time of writing, with a note that the figure moves with every #313 merge and is a snapshot, not a contract. |

### Tests

- `bash .agent/scripts/tests/test_cross_model_review.sh` — 379 passed, 0 failed.
- `bash .agent/scripts/tests/run_script_tests.sh` — all 23 suites passed in 97s, no temp leaks.

No real agy/codex/claude/copilot prompt was run.

### Notes

plan.md's `## Implementation Notes` now records both new rules — fence
balancing after the cut, and no `printf | head` under `pipefail` — so a
later reader sees them as decisions rather than incidental code.
