---
issue: 309
---

# Issue #309

## Issue Review
**Status**: complete
**When**: 2026-09-23 14:08-04:00
**By**: Codex CLI Agent (gpt-6)
**Issue**: #309

### Scope Assessment

**Well-scoped?** Yes — a shared coverage predicate and regression tests fit one PR.
**Right repo?** Yes — review-loop infrastructure belongs to agent_workspace.
**Dependencies**: None identified.

### Principle Alignment

| Principle | Status | Notes |
| --- | --- | --- |
| Only what's needed | OK | Reuse merge-gate equivalence without changing CI policy. |
| Test what breaks | OK | Real Git histories cover silent loss and stale-review rejection. |
| A change includes its consequences | OK | Update triage's sources contract and preserve merge callers. |

### ADR Applicability

| ADR | Triggered | Notes |
| --- | --- | --- |
| 0002 | Yes | Isolated feature/issue-309 worktree. |
| 0011 | Yes | Generic Git logic, no project-shape assumptions. |
| 0013 | Yes | Preserve entry vocabulary and original SHA provenance. |

### Consequences

- The gate now allows the issue's whole work-plan directory; use that current policy consistently.
- Regression tests belong in test_triage_reviews_integration.sh, which owns sources coverage.
- Codex observations remain work-plan evidence, not instruction or orchestrator changes.

### Recommendations

None beyond the implementation plan.

### Actions
- [x] No actions needed.

## Plan Authored
**Status**: complete
**When**: 2026-09-23 14:10-04:00
**By**: Codex CLI Agent (gpt-6)
**Plan**: `.agent/work-plans/issue-309/plan.md` at `bed79ef`

Share the existing merge-gate coverage rule with sources; preserve original review
SHAs and test real-history boundaries. Draft PR deferred until the fix is reviewable.
User authorized implementation and the workspace workflow in this session.

## Plan Review
**Status**: complete
**When**: 2026-09-23 14:10-04:00
**By**: Codex CLI Agent (gpt-6; independent plan_review subagent)
**Verdict**: ready
**Issue**: #309
**Plan**: `.agent/work-plans/issue-309/plan.md` at `bed79ef`

### Evaluation

Scope, issue alignment, file targeting, consequences, principle alignment, and
ADR compliance: Good. ROS conventions: not applicable.
Independent fresh-context reviewer read the committed plan and relevant source.
No blocking findings. Update all literal same-head descriptions in the triage
skill, including classification and report templates, as planned.

### Recommended Actions

- [x] No pre-implementation blockers.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 14:29 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Approve, as described (Recommended): Codex's plan (bed79ef; Codex plan review: ready) is approved. Driver handed over from Codex (quota exhausted) to a Claude drive. Implementer: commit Codex's staged, uncommitted implementation first as a labelled WIP snapshot (authored as found), merge main, then finish and verify the plan; coordinate with #334 (docs reorganisation), which adds docs/roadmap.md to merge_pr.sh's bookkeeping lists — whichever lands second carries docs/roadmap.md into the new shared helper; keep codex-workflow-notes.md in the work-plan folder.

## Implementation
**Status**: complete
**When**: 2026-09-23 14:54 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-309 at `40f4e7d`

Handover from Codex CLI (quota exhausted mid-implementation), per the checkpoint at `5ae7c73`.

**Handover commits.** Codex's staged, uncommitted work committed as found under its own identity: `544bde2` (8 files, +241/-59; full pre-commit suite passed, no SKIP needed) and its workflow notes `bc6979d`. Merged origin/main (`92c57ce`): no conflicts.

**Codex's snapshot contained:** `_bookkeeping.sh` (the gate's `_only_bookkeeping_between` moved out of `merge_pr.sh` verbatim, a `_review_bookkeeping_between` review policy, a bash bridge for Python); gate switched to it; `sources` coverage (exact / bookkeeping, per-SHA cache, cwd repository, issue from the canonical progress path, original `sha` kept, `covers_head` + `coverage` fields); real-history tests; fixture copies of the helper in both merge suites; triage-reviews contract text.

**Kept:** the extraction and gate wiring, the coverage model (endpoint tree diff, ancestor required, issue-scoped work-plan dir, cwd repository, exact-match fast path), the provenance fields, the fixture updates, most test cases, most of the skill text. The core logic held up against its own cases.

**Changed, and why:**
- Silent fallback (Quality Standard, and the issue's own complaint that "the helper gave no signal"): Codex's bridge collapsed every failure (no repo, missing object, missing helper) to "not covered" with stderr discarded. Now the helper returns 1 stale / 3 unverifiable with a reason, and `sources` emits `dropped_entries` (entry, sha, open count, reason, why) plus a stderr warning for unverifiable ones.
- Roadmap set: one `BOOKKEEPING_ROADMAP_PATHS` in `_bookkeeping.sh`, including `docs/roadmap.md` (#334), used by the review policy and by the CI walk-back list in `merge_pr.sh`. #334 edits both lines, so whichever lands second resolves a trivial conflict by keeping the shared array.
- Hex-only SHA resolution in the review policy: Codex's resolved any revision, so a ref name such as `HEAD` counted as a recorded review.
- `set -e` safety: resolution rewritten as if-blocks (merge_pr.sh runs `set -eo pipefail`).
- Tests: added the lowercase roadmap, nested work-plan files, issue-70 prefix boundary, `dropped_entries` reasons, bridge usage and non-hex checks (h1-h15). The no-repository case is now pinned with `GIT_CEILING_DIRECTORIES` so it holds even if TMPDIR sits inside a checkout. Gate g7 (docs/roadmap.md), g8 (another issue's dir, pinning existing behaviour), CI walk-back ci-30b.
- triage-reviews skill: documented `dropped_entries` (unverifiable means read the entry by hand, never treat it as resolved). Also fixed the `sources` call's `--progress` path. #317 prefixed it with `$WS_ROOT` (the main checkout), which does not hold an in-flight branch's timeline. It now uses the worktree toplevel, which is where step 7 persists. Codex's comment in cmd_sources ("comment ... cover the current head") was corrected: a candidate needs the GitHub comment *at* the head.

**Verification:** run_script_tests.sh: all 26 suites green. test_triage_reviews_integration 36/36, test_merge_pr_gate 81/81. Fail-without-fix proof on scratch copies: pre-fix `review_progress.sh` (`5ae7c73`) fails 19 of the new cases, including h1, the #309 checkpoint regression. Codex's snapshot fails 13, from the lowercase roadmap onward plus the dropped-entry reporting. main's `merge_pr.sh` fails g7 and ci-30b.

**Not done (Ask First):** AGENTS.md's script table still describes `sources` as "correlated by head SHA" and does not list `_bookkeeping.sh`. That is an instruction file, so it is left for the owner.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-24 10:12 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-309 at `b4ca2ea`
**Base**: main
**Depth**: Deep (reason: 719 changed lines across 10 files; merge_pr.sh gate and a SKILL.md touched)
**Must-fix**: 3 | **Suggestions**: 1
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

Reviewers: static (shellcheck --severity=warning + bash -n: clean), governance, plan drift (no drift; all planned files changed), Claude adversarial (fresh; ran, 0 must-fix, 1 suggestion; gate suite 83/83, triage suite 36/36; merge-conflict resolution in merge_pr.sh and test_merge_pr_gate.sh verified equivalent to main, nothing lost or duplicated).
- Gemini (agy): failed — empty response; headless mode auto-denied a read_file (ViewFile) tool action.
- Codex: ran — 2 must-fix (both reproduced/confirmed below).
- Copilot: skipped — quota exhausted (September 2026).

### Findings
- [x] (must-fix) Rename detection hides the source path: `git diff --name-only` reports only the destination, so moving a code file into `.agent/work-plans/issue-<N>/` counts as bookkeeping-only (reproduced: helper rc 0). Use `--no-renames`; add a rename test to both the sources suite and the gate suite. Codex must-fix, Claude adversarial suggestion — `.agent/scripts/_bookkeeping.sh:42`
- [x] (must-fix) Git errors are classified as "stale" (rc 1), not "unverifiable" (rc 3): any non-zero `merge-base --is-ancestor` (including 128 on a missing object) and a failed `git diff` both return 1, so `sources` lists them as verified-stale with no stderr warning. That is the silent path this issue exists to remove. Return 3 for is-ancestor rc other than 0/1, for a diff failure, and for a non-ancestor in a shallow repository; add tests. Merge gate behaviour is unchanged (1 and 3 are both "not covered"). Codex — `.agent/scripts/_bookkeeping.sh:38-45`
- [x] (must-fix) Missing consequence: the AGENTS.md Script Reference still says `sources` is "correlated by head SHA" and has no row for the new `_bookkeeping.sh`. AGENTS.md is Ask First, so this needs the owner's go-ahead — `AGENTS.md:419`
- [x] (suggestion) ADR-0013 References says one helper applies the rule "for both the gate and the CI target". Add `review_progress.sh sources` (#309) and the helper's new home, `_bookkeeping.sh`, as a cross-reference addendum (ADR-0008) — `docs/decisions/0013-progress-md-entry-type-vocabulary.md:209-216`
