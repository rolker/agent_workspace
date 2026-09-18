---
issue: 286
---

# Issue #286 — merge_pr.sh gate: a review entry's own progress commit makes every review look stale

## Plan Authored
**Status**: complete
**When**: 2026-09-18 10:35 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-286/plan.md` at `313c126`

Extract the #284 ancestry + paths-only exemption into one helper and use it for gate condition (a), so a review followed only by its own progress.md commit (plus the run's roadmap commit) counts as at head.

## Plan Review
**Status**: complete
**When**: 2026-09-18 10:38 -04:00
**By**: Independent plan reviewer (claude-sonnet-5)
**Verdict**: needs-work

**Issue**: #286 — merge_pr.sh gate: a review entry's own progress commit makes every review look stale
**Plan**: `.agent/work-plans/issue-286/plan.md` at `313c126`
**Branch**: `feature/issue-286`

### Evaluation
| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two files, one helper reused by two call sites |
| Issue alignment | Good | Targets the observed #273/#282/#285 failure shape |
| File targeting | Good | merge_pr.sh + test_merge_pr_gate.sh |
| Consequences | Needs work | Test-harness mechanics for g1–g3 unaddressed |
| Principle alignment | Good | g1/g2 are the exact live failure shape |
| ADR compliance | Needs work | Rule now used by two consumers lives only in script comments |

### Findings
1. **[Correctness]** (must-fix) — The gate compares against `HEAD_REVIEWED`, captured before Step 1, so `_STEP1_COMMITTED_PATHS` can never be in the `R → HEAD_REVIEWED` range; drop it or state which head the gate compares against.
2. **[Correctness]** (suggestion) — An ambiguous 7-char SHA after a fetch must fold into "not resolvable" explicitly.
3. **[Test coverage]** (must-fix) — g1–g3 need a real two-commit history with the review SHA interpolated, like `make_ci_sandbox`, not the static `abc1234` fixtures.
4. **[ADR-0013]** (suggestion) — Record the ancestry-equivalence reading of the SHA key once as an ADR-0008 addendum instead of two script comments.

### Summary
Approach is sound; the plan needs to name the comparison endpoint and the dynamic-SHA test harness before implementation.

### Recommended Actions
- [x] Gate compares against `HEAD_REVIEWED`; allowed set is progress.md + the two roadmap files; `_STEP1_COMMITTED_PATHS` dropped from the gate call
- [x] `make_gate_sandbox` builder with interpolated real SHAs; five cases
- [x] Ambiguous short SHA folds into "not resolvable"
- [x] ADR-0013 addendum added to scope

## Plan Authored
**Status**: complete
**When**: 2026-09-18 10:41 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-286/plan.md` at `847a170`

Revision 2: gate compares R against HEAD_REVIEWED with allowed paths progress.md + ROADMAP.md + docs/ROADMAP.md; ambiguous short SHA = unresolvable; make_gate_sandbox with real SHAs, five cases; ADR-0013 addendum.

## Implementation
**Status**: complete
**When**: 2026-09-18 10:51 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-286/plan.md` at `847a170`

**Branch**: `feature/issue-286` at `34dfcb6`

c6d5b72 helper `_only_bookkeeping_between` + gate condition (a) ancestry rule + Step 2 call site; 2ca3c13 five gate cases (g1–g5) on real histories, ci-3 assertion updated to the helper's message; 34dfcb6 ADR-0013 references addendum. Gate suite 53/53, full suite 20/20, shellcheck clean. No deviations from the plan.

## Local Review
**Status**: complete
**When**: 2026-09-18 10:56 -04:00
**By**: Claude Code Agent (lead: claude-fable-5-1; specialists: claude-sonnet-5 governance + adversarial; shellcheck; gemini unavailable — headless permission denial)
**Verdict**: approved

**PR**: #287 at `db6c8ed`
**Depth**: Deep (reason: 395 lines changed; enforcement script)
**Must-fix**: 0 | **Suggestions**: 2

### Findings
- [x] (suggestion, adversarial) empty-diff head after the reviewed head now exempt rather than re-targeted; documented in a comment and covered by test ci-11 — `.agent/scripts/merge_pr.sh`
- [ ] (suggestion, governance) the ADR-0013 References bullet states an interpretive rule; borderline addendum vs. supersede under ADR-0008, for the owner to confirm — `docs/decisions/0013-progress-md-entry-type-vocabulary.md:206`
- [ ] Gemini cross-model review produced no output: headless agy was auto-denied a command permission (tooling gap, filed separately)

## Merge (report-only)
**Status**: complete
**When**: 2026-09-18 11:04 -04:00
**By**: merge_pr.sh (Claude Code Agent)

**PR**: #287 at `43e3003`
**Mode**: report-only
**Scope**: workspace
**Conditions**: latest Local Review entry is at `db6c8ed`, not the PR head `43e3003` (stale review)

## Local Review
**Status**: complete
**When**: 2026-09-18 11:11 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**PR**: #287 at `5d3658e`
**Depth**: Light (reason: delta since the approved review at db6c8ed is one test renumber and the one-line #289 fix with its stub method check; verified live that -X GET returns the runs and the bare form 404s)
**Must-fix**: 0 | **Suggestions**: 0

### Findings
- [ ] No issues found. LGTM. Gate suite 54/54 with the method check; 38/54 without the fix.
