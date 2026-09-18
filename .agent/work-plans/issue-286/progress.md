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
