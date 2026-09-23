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

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 14:31 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-320 at `ef59ceb`
**Base**: feature/issue-313 (reviewing #320's own commits only; #313 is in its own loop)
**Depth**: Standard (reason: governance + enforcement files plus the shared-prompt builder)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 2 | **Ship**: recommended — no must-fix findings; round-1 items all verified fixed at df3723b

### Findings
- [ ] No issues found. LGTM.

### Round-1 items verified (df3723b)
- [x] (must-fix) Pipe replaced by here-strings at `cross_model_review.sh:855-861` — `wc -l <<<` and `head -n <<<`; `test_plan_context_large_approach` drives a ~400 KB Approach and asserts exit 0, which the old `printf | head` could not survive under `pipefail`
- [x] (must-fix) Fence toggles counted over the already-cut body (`cross_model_review.sh:869-884`), matching closer emitted before the truncation marker; `test_plan_context_fence_balanced` covers a complete fence and one straddling the 200-line cut, asserting an even fence count and an unswallowed `## Output Format`
- [x] (suggestion) Extractor now stops at `^# `, `^## ` or `^---`; the comment states the one-sided guarantee it keeps (possibly shorter, never longer, never a later section) — `cross_model_review.sh:838-848`
- [x] (suggestion) Three new registered tests, including the H1 and thematic-break cases
- [x] (suggestion) plan.md assertion count corrected to 379 and marked a snapshot; both rules recorded in Implementation Notes

### Verified
- `test_cross_model_review.sh`: 379 passed, 0 failed
- `run_script_tests.sh`: all 23 suites passed in 90s
- Diff since round 1 touches only the script, its tests, plan.md and progress.md — no #313 files

## Checkpoint
**Status**: complete
**When**: 2026-09-23 10:43 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: publish
**Decision**: address

Owner, 2026-09-23: "yes, update 320 with same codex/gemini rules". Scope addition before publish (recorded on the issue): a fix-round re-review classifies the fix round's own delta (changes since the last reviewed SHA) with the same tier table as a first review, so a Standard-sized delta dispatches the cross-model reviewers (Gemini via agy, Codex) exactly as a first review does; the reviewer may raise the tier, never lower it; a Light delta stays Light. #313 has merged and origin/main is merged into this branch (8b55f02).

## Implementation
**Status**: complete
**When**: 2026-09-23 10:55 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-320 at `31704ec`
**Addressed**: Checkpoint (After: publish, Decision: address) at `cc26455` (2026-09-23 10:43 -04:00); latest review entry Local Review (Pre-Push) at `ef59ceb` had no open findings (its unchecked LGTM placeholder left as written)
**Commits**: bc16a62, 31704ec

Owner scope addition: a fix-round re-review is classified on the fix
round's own delta with the same tier table as a first review, so a
Standard/Deep delta dispatches Gemini/Codex (and every other available
non-caller agent) exactly as a first review does.

### Decisions
- **Last reviewed SHA**: the `**Addressed**` SHA of the newest `## Implementation`; else the correlation SHA of the newest `## Local Review` / `## Local Review (Pre-Push)` / `## Integrated Review`.
- **Delta measurement**: `git log --first-parent --no-merges --numstat --format= <last>..HEAD -- . ':(exclude).agent/work-plans/**'` — a base merge during the fix round is not counted; per-commit summing can only over-count (errs toward a higher tier); work-plans bookkeeping excluded because every fix round writes its own Implementation entry, and the same path is excluded from the cross-model diff. The exclusion applies to the delta only; first-review classification is unchanged.
- **Cross-model diff**: unchanged — the same `--pr <N>` / `--branch [<base>]` call as a first review, so agents read the whole PR/branch diff with the fixes in context. `cross_model_review.sh` has no delta mode and `gh pr diff` has no range; `--branch <last-sha>` would pull in base merges and has no PR-mode equivalent. The delta decides whether cross-model runs, not what it reads.
- **Recording**: the `**Depth**` reason names the delta (`fix-round delta <last>..<head>: N lines, F files`, plus triggers or "raised by reviewer: <why>").
- **Prose-only**: no script computes tiers (grep of `.agent/scripts` and hooks), so no script change or new test; the rule lives in the knowledge doc and the skill.
- Sanity check of the command on this branch: round 2's delta (`f26ca59..ef59ceb`) measures 221 lines / 2 files — Deep; `ef59ceb..HEAD` (a merge of main plus progress entries) measures empty, as intended.

### Actions
- [x] New *Fix-Round Re-Reviews* section — `.agent/knowledge/review_depth_classification.md`
- [x] Step 2 fix-round rule, 5e same-call note, `**Depth**` reason in the entry template, tier summary and Guidelines — `.claude/skills/review-code/SKILL.md`
- [x] Next-step note that the re-review tier follows the delta — `.claude/skills/address-findings/SKILL.md`
- [x] Status-line pointer extended — `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md`
- [x] Plan addendum naming the scope addition — `.agent/work-plans/issue-320/plan.md`

### Tests
- Pre-commit on bc16a62 passed, including the full `run_script_tests.sh` (all suites). A first attempt failed `test_skill_paths.sh` on a literal `.agent/work-plans/**` in review-code SKILL.md (read as a workspace-relative path); reworded, suite then 51 passed / 0 failed.
- No other text found saying the reviewer decides re-review depth (grepped review-code, run-issue, address-findings, triage-reviews, knowledge docs, ADRs, dispatch_phase.sh).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-23 11:05 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-320 at `21c49e0`
**Base**: origin/main
**Depth**: Standard (reason: fix-round delta ef59ceb..21c49e0: 118 lines, 4 files — override triggers: review-code + address-findings SKILL.md, knowledge doc, ADR-0015; same result from the rule's own last-reviewed SHA cc26455; merge 8b55f02 excluded as first-parent/no-merges, remerge-diff empty)
**Must-fix**: 4 | **Suggestions**: 3
**Round**: 3 | **Ship**: continue — round 3: 4 must-fix is high, one is a design question for the owner

### Findings
- [x] (must-fix) "Last reviewed SHA" is ambiguous and can pick a non-reviewed SHA: `**Addressed**` may name a Checkpoint (this branch's newest Implementation names `cc26455`), implement-phase Implementation entries have no `**Addressed**`, and the newest review can postdate the newest Implementation — use the correlation SHA of the newest `## Local Review` / `## Local Review (Pre-Push)` / `## Integrated Review` for this branch/PR — `.agent/knowledge/review_depth_classification.md:143-148`, `.claude/skills/address-findings/SKILL.md:207-210` (deferred: resolved by removal: owner chose whole-diff tier at checkpoint 266981f, fix-round delta counting deleted)
- [x] (must-fix, design — owner call) Classifying a fix round only on its delta lowers re-reviews that the previous whole-diff rule kept at Standard/Deep: a small fix to a large PR becomes Light (static only), so no governance or Claude adversarial pass checks the prior findings were resolved. Option: specialists 5a–5d keep the whole-diff tier; the delta tier gates only cross-model dispatch (raised independently by Gemini, the Claude adversarial reviewer and the lead reviewer) — `.agent/knowledge/review_depth_classification.md:130-141,178-179`, `.claude/skills/review-code/SKILL.md:181-190` (deferred: resolved by removal: owner chose whole-diff tier at checkpoint 266981f, fix-round delta counting deleted)
- [x] (must-fix) `--no-merges` hides conflict resolutions (evil merges) made during a fix round; add the numstat of `git show --remerge-diff` for each first-parent merge in the range (empty for clean merges like 8b55f02) — `.agent/knowledge/review_depth_classification.md:150-165` (deferred: resolved by removal: owner chose whole-diff tier at checkpoint 266981f, fix-round delta counting deleted)
- [x] (must-fix) Fence balancing treats any line starting with the opener's 3 chars as a closer: an in-fence ```` ```js ```` line (info string, so content) closes it, and 4-backtick fences are closed with 3 — footer can be swallowed. Track marker char + run length, closer = same char, length ≥ opener, whitespace only after; emit a closer of the opener's length; add tests (Codex + Gemini agree) — `.agent/scripts/cross_model_review.sh:985-996`
- [x] (suggestion) Pathspec `-- .` is cwd-relative; run from a subdirectory it undercounts silently — use `-- ':/' ':(top,exclude).agent/work-plans/**'` — `.agent/knowledge/review_depth_classification.md:154` (deferred: resolved by removal: owner chose whole-diff tier at checkpoint 266981f, fix-round delta counting deleted)
- [x] (suggestion) No guidance when the last reviewed SHA is not an ancestor of the head (rebase/force-push; PR mode fetching only `headRefOid` gives `bad object`): check `git merge-base --is-ancestor`, fetch via `pull/<N>/head`, fall back to whole-diff classification — `.agent/knowledge/review_depth_classification.md:158-159` (deferred: resolved by removal: owner chose whole-diff tier at checkpoint 266981f, fix-round delta counting deleted)
- [x] (suggestion) Numstat edge cases undefined: binary files report `-` (sum as 0 lines, still count the file) and renames depend on `diff.renames` — state both, or pass `--no-renames` — `.agent/knowledge/review_depth_classification.md:156-157` (deferred: resolved by removal: owner chose whole-diff tier at checkpoint 266981f, fix-round delta counting deleted)

## Checkpoint
**Status**: complete
**When**: 2026-09-23 11:11 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Owner chose "Same as whole PR (Recommended)": a fix-round re-review gets the same tier as a first review of the whole PR/branch; the reviewer may raise it, never lower it. Drop the fix-round delta counting entirely (resolves round-3 must-fix 1, 2, 3 and suggestions 1-3 by removal). Fix the plan-context fence-balancing bug (must-fix 4) with tests. One more review round follows.

## Implementation
**Status**: complete
**When**: 2026-09-23 11:24 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a25eabc1b068839e2, resume 1 of 3)

**Branch**: feature/issue-320 at `57994db`
**Addressed**: Local Review (Pre-Push) at `21c49e0` (2026-09-23 11:05 -04:00), with the owner's Checkpoint at `266981f` (After: rounds, Decision: address — "Same as whole PR")
**Commits**: 9f6b665, 57994db

### Actions
- [x] (must-fix 1) "Last reviewed SHA" ambiguity — `.agent/knowledge/review_depth_classification.md` (deferred: resolved by removal — delta counting deleted per owner decision; fixed in 9f6b665)
- [x] (must-fix 2, owner call) Delta tier could lower a re-review below the whole-PR tier — owner chose "Same as whole PR": re-reviews classify exactly as a first review on the whole diff; reviewer may raise, never lower — `.agent/knowledge/review_depth_classification.md`, `.claude/skills/review-code/SKILL.md` step 2 (9f6b665)
- [x] (must-fix 3) `--no-merges` hides evil merges — (deferred: resolved by removal; 9f6b665)
- [x] (must-fix 4) Fence balancing: opener char + run length tracked; closer = same char, run ≥ opener, whitespace only after; backtick info string may not contain a backtick; emitted closer repeats the opener — `.agent/scripts/cross_model_review.sh:979-1027` (57994db)
- [x] (suggestions 1-3) cwd-relative pathspec, non-ancestor last SHA, numstat edge cases — (deferred: resolved by removal; 9f6b665)

### What changed
- 9f6b665: the Fix-Round Re-Reviews section now states the simple rule (whole diff, same table, Standard/Deep dispatches cross-model, raise never lower, Depth line records tier and reason) and why the delta variant was dropped; review-code step 2 carries the rule and says the user override applies to fix rounds; review-code's Depth-reason delta wording, 5e same-call note and Guidelines addition removed (file restored from `cc26455` plus the step-2 paragraph); address-findings next-step note now says the re-review keeps the whole diff's tier; ADR-0015 status pointer reworded; plan addendum rewritten to describe this rule and the dropped delta variant.
- 57994db: CommonMark fence tracker in the plan-context block; 4 new tests plus an independent CommonMark fence-walking oracle (`footer_fence_state`) and a `write_straddling_plan` fixture helper, all registered.

### Tests
- `test_cross_model_review.sh`: 454 passed, 0 failed.
- Against the previous tracker (old `cross_model_review.sh` swapped in temporarily, then restored): 446 passed, 8 failed — every one of the four new tests fails (2 assertions each); the already-closed `~~~` sub-case passes on both, as expected.
- Pre-commit on both commits passed, including shellcheck and the full `run_script_tests.sh` suite; `test_skill_paths.sh` 51/51.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-23 11:36 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a190c0f8e5798f8b4, resume 1 of 3)

**Branch**: feature/issue-320 at `a86702c`
**Base**: origin/main
**Depth**: Deep (reason: whole-branch diff against merge-base bfb6803, work-plans excluded: 730 lines, 7 files — 200+ lines; override triggers: review-code + address-findings SKILL.md, knowledge doc, ADR-0015, AGENTS.md)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 4 | **Ship**: recommended — round 4: 2 mechanical must-fix (prev 4), not rising — fix and ship rather than another full round

### Findings
- [x] (must-fix) Emitted closer is always column 0: for a fence opened inside a list item (e.g. `  ```bash`) and cut by the 200-line cap, CommonMark ends the list item at the column-0 line and reads the closer as a new top-level opener, swallowing `## Output Format` (reproduced with markdown_it) — record the opener's leading whitespace and prefix the emitted closer with it; add a list-item test — `.agent/scripts/cross_model_review.sh:1000-1025` (deferred: resolved by removal: owner chose one outer fence at the round-4 checkpoint, fence-balancing tracker deleted)
- [x] (must-fix) All leading whitespace is stripped before fence matching, so a 4+-space- or tab-indented backtick run outside any fence (an indented code block) opens a phantom fence and the emitted closer then opens a real one that swallows the footer (reproduced with markdown_it; Gemini + Claude adversarial agree). The comment's "errs toward emitting a closer" is the unsafe direction — accept an opener only with indent ≤3 beyond its container (at minimum ≤3 spaces for unindented text) and correct the comment; add a test — `.agent/scripts/cross_model_review.sh:995-1003` (deferred: resolved by removal: owner chose one outer fence at the round-4 checkpoint, fence-balancing tracker deleted)
- [x] (suggestion) CRLF plan files: the closer check `rest ~ /^[ \t]*$/` fails on a trailing `\r`, so a closed fence reads as open and a spurious closer swallows the footer; the mixed-line-ending hook does not reject an all-CRLF file — strip `\r` first — `.agent/scripts/cross_model_review.sh:1014` (deferred: resolved by removal: owner chose one outer fence at the round-4 checkpoint, fence-balancing tracker deleted)
- [x] (suggestion) The Approach extractor still stops at a `# ` comment inside a fenced block with no truncation marker, so reviewers get a shorter Approach silently; now that a fence tracker exists, make the extractor skip boundaries while a fence is open, or mark an early stop — `.agent/scripts/cross_model_review.sh:958-962`
- [x] (suggestion) Thematic-break stop matches exactly `---`; `----` or longer rules do not end the section, so a later section can leak in — use `/^-{3,}[[:space:]]*$/` — `.agent/scripts/cross_model_review.sh:960`

## Checkpoint
**Status**: complete
**When**: 2026-09-23 11:40 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Owner chose "One outer fence (Recommended)": wrap the plan excerpt in a single outer fence longer than any backtick run inside it and delete the fence-balancing tracker (resolves round-4 must-fix 1-2 and the CRLF suggestion by removal); fix the two extractor suggestions (a '# ' line inside a fenced block ending the Approach early; '----' and longer rules not ending the section). One more review round.

## Implementation
**Status**: complete
**When**: 2026-09-23 11:50 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a25eabc1b068839e2, resume 2 of 3)

**Branch**: feature/issue-320 at `902026d`
**Addressed**: Local Review (Pre-Push) at `a86702c` (2026-09-23 11:36 -04:00), with the owner's Checkpoint at `0022942` (After: rounds, Decision: address — "One outer fence")
**Commits**: 902026d

### Actions
- [x] (must-fix 1) Column-0 closer for list-item fences — `.agent/scripts/cross_model_review.sh` (deferred: resolved by removal — tracker deleted; the outer fence's own column-0 closer is correct by construction)
- [x] (must-fix 2) Indented code read as a fence — (deferred: resolved by removal; the outer fence is longer than any backtick run, indented or not)
- [x] (suggestion) CRLF closer check — (deferred: resolved by removal; our closer carries no CR, and the extractor strips CR before its boundary fence check)
- [x] (suggestion) Extractor stops at `# ` inside a fence — boundaries ignored while a plan fence is open (0-3 space indent, same-char closer at least as long, whitespace only after, CR stripped; backtick run followed by a backtick is inline code) — `.agent/scripts/cross_model_review.sh:945-990`
- [x] (suggestion) `----` rules — stop now matches `^---+[[:space:]]*$` — `.agent/scripts/cross_model_review.sh`

### What changed (902026d)
- `cross_model_review.sh`: fence-balancing tracker deleted. The capped excerpt is wrapped in one backtick fence of max(3, longest inner run + 1), opener `<fence>markdown` at column 0, closer before the truncation marker; heading and framing text stay outside. Extractor gained boundary-only fence tracking and the 3+-dash rule.
- `test_cross_model_review.sh`: the six fence tests (round-1 balanced + four round-3 tracker tests) replaced by eight outer-fence tests (basic, no backticks, ```js inside, 4-backtick cut, list-item fence cut at the cap, 4-space-indented backtick run, CRLF, 5-backtick run → 6-backtick outer) and two extractor tests (`#`/`---`/`##` inside fences; `-----` rule). The independent oracle is now `fence_state_at` (any target line; trailing CR treated as a line ending), with a shared `assert_plan_context_well_formed` checking footer, framing text and truncation marker are outside every fence. Unused `count_fence_lines` removed.
- `plan.md` Implementation Notes: the fence-balancing note replaced by the outer-fence decision and the extractor-boundary rule. AGENTS.md's script row does not describe the tracker, so it is unchanged.

### Tests
- `test_cross_model_review.sh`: 479 passed, 0 failed. Pre-commit (shellcheck, full `run_script_tests.sh`) passed.
- Against the previous tracker code (swapped in temporarily, then restored): 465 passed, 14 failed — 8 of the 10 new tests fail. The ```js-inside and list-item-cut tests pass on the old code: the old tracker already handled info strings, and the list-item failure depends on CommonMark list containers, which the test oracle (fence rules only) does not model. A markdown_it cross-check of that case was not run (the ad hoc harness command was denied).

### Notes
- Pre-existing, outside this round's scope: the `## Diff` block uses a fixed 3-backtick fence (`cross_model_review.sh` ~891/925); a diff context line ` ````…` (1 space + 3 backticks) is a valid CommonMark closer, so a diff touching fenced markdown can end the diff fence early. The same longest-run technique would fix it.

## Implementation
**Status**: complete
**When**: 2026-09-23 12:04 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a25eabc1b068839e2, resume 3 of 3)

**Branch**: feature/issue-320 at `6893b68`
**Commits**: 6893b68

Owner scope addition, not addressing a review box. The owner answered the "found, not fixed" note in the previous entry with, verbatim: "Fold in now (Recommended)".

### What changed (6893b68)
- `cross_model_review.sh`: the `## Diff` block no longer uses a fixed ``` fence, which any diff context line of one space plus three backticks closes under CommonMark. The diff is staged in a temp file (`SHARED_DIFF`, removed after use and in the EXIT trap), then wrapped in a fence one backtick longer than its longest backtick run (minimum 3), at column 0, no CR on the closer — PR and branch mode alike. A diff whose last line lacks a newline still gets its closer on its own line. The fence length comes from one shared helper, `outer_fence_for`, now also used by the plan context (the inline awk there is gone). No other fixed fence around embedded content remains in the script. The empty-diff guard now counts the staged file's lines (same semantics as before).
- `test_cross_model_review.sh`: three new tests — PR mode with a ` ``` ` context line (fence of 4), PR mode with a 4-backtick run and an unterminated last line (fence of 5), branch mode with a real fenced-markdown commit (fence of 5) — each asserting that a diff line after the fence-shaped context line is still inside the diff fence and the footer is outside every fence, via `fence_state_at`, which now takes an optional start heading. An awk escape warning in the round-4 framing-text regex was fixed (`[.]`).
- `plan.md` Implementation Notes: the outer-fence note now records the fold-in. AGENTS.md's script row does not describe the diff fence, so it is unchanged.

### Tests
- `test_cross_model_review.sh`: 493 passed, 0 failed. Pre-commit (shellcheck, full `run_script_tests.sh`, no temp leaks) passed.
- Against the previous fixed-fence code (swapped in temporarily, then restored): 483 passed, 10 failed — all three new tests fail, including their well-formedness assertions, in both modes.
