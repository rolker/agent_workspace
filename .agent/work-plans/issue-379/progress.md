---
issue: 379
---

# Issue #379 — merge_pr.sh review gate looks up a project PR's timeline at the legacy project/ path, not the registry root

## Issue Review
**Status**: complete
**When**: 2026-10-12 12:00 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #379

### Scope Assessment

**Well-scoped?** Yes — one resolver change at the gate's worktree lookup plus a test; fits one PR.
**Right repo?** Yes — `merge_pr.sh` and its test are workspace infrastructure.
**Serves**: Quality of the work (a merge gate whose review check actually sees the timeline) — `docs/design.md#merge-gate` (and `docs/design.md#worktrees`, whose Records Now text cites this issue)
**Design picture?** No change to how the parts fit — the fix aligns the gate with the registry-aware root the design already describes. Two design-doc paragraphs cite line numbers and "tracked as #379" and must be edited in the same change (design.md says so itself).
**Dependencies**: none blocking. The Records Target (C3 resolver) is later and does not gate this.

Verified against current `merge_pr.sh` (issue line numbers are slightly stale):
- Cleanup lookup is line 555: `_WT_REPO="${PJ_REPO_ROOT:-$ROOT_DIR/project}"`. Gate lookup is lines 669-671: `_gate_wt_repo="$ROOT_DIR/project"` — the bug is confirmed (line ~670 in the issue is right to within one).
- Report-only for project PRs: line 929 (the `_gate_mode_note` text), not 916-929 as one range.
- "Would have refused" path (line 930): affected. Because the lookup misses a registered project's worktree, `_gate_progress` is empty, so condition (b) reports "no progress.md ... in an open worktree" and the note is misleading. After the fix the note reflects the real timeline. It stays report-only by design.
- Step 1.5 record path (lines 801-843): affected too, beyond what the issue says. `_gate_wt` is also what `progress_append.sh -C` and the push use. With the wrong lookup, a registered project's record falls to the PR-comment path ("no open worktree for the PR's repo") instead of the timeline commit. The main-tree guard at ~line 816 loops over `"$ROOT_DIR" "$ROOT_DIR/project"` only; it should also cover `${PJ_REPO_ROOT}` or the registered project's main checkout could take a feature commit if it has the PR branch checked out.
- Package worktrees (`PKG_WT_DIR`, lines 666-667 and the 843 "package worktrees carry no issue timeline" branch): not affected; they bypass `_gate_wt_repo`. The test must not regress this path.
- `docs/design.md` Records bullet (Worktrees section, ~lines 336-343, plus the Merge gate section ~lines 377-380 and 502, and the `merge_pr.sh` consequences row at ~266 with its line list "555, 670, 916 and 929"): all name the legacy lookup and #379 and need rewriting when this lands, including the line-number citations.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | The fix edits docs/design.md in the same change: the Worktrees Records bullet (~336-343), the Merge gate text (~377-380, ~502), the merge_pr.sh row (~266), and the decision-register/changelog line citing #379. The issue already says the user decided the fix; this is a recorded update, not a new question. |
| Fix it completely | Action needed | Issue names only the lookup at ~670. The same legacy root also guards the Step 1.5 timeline commit (main-tree guard loop at ~816 lists `$ROOT_DIR/project` only). Fix both or state why not; otherwise a registered project's record still misses the timeline path. |
| Tests with the change | Watch | Test is requested. It must build a registered project root that is not `$ROOT_DIR/project` (existing project-scope test at test_merge_pr_gate.sh ~525 uses the legacy `project/` checkout, so it would pass before and after) and assert the gate finds the timeline, and that the Step 1.5 record lands in it. |
| Put each thing at the level it applies to | OK | Registry-aware resolution reuses `PJ_REPO_ROOT`; no hard-coded project names. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (progress timeline) | Yes | The gate reads/writes `.agent/work-plans/issue-N/progress.md`; the fix makes it look in the right repo. |
| ADR-0011 (adapters/registry) | Yes | Uses the registry-resolved root (`wt_resolve_project_repo_root`). |
| ADR-0017 (design doc updated with change) | Yes | See the Keep one current design row. |

### Consequences

- Edit docs/design.md paragraphs listed above (and refresh the line numbers they cite).
- Update the stale header comment at merge_pr.sh ~627-628 only if the report-only wording changes (it should not).

### Recommendations

- Replace the gate's `_gate_wt_repo="$ROOT_DIR/project"` with `${PJ_REPO_ROOT:-$ROOT_DIR/project}`, ideally through one shared variable used by both the cleanup lookup (line 555) and the gate (669-671), as the issue proposes.
- Extend the main-tree guard at merge_pr.sh ~816 to include `PJ_REPO_ROOT` so the Step 1.5 timeline commit never lands in a registered project's main checkout.
- Add a test_merge_pr_gate.sh case with the project registered at a non-`project/` root: the gate finds the timeline (no "no progress.md" reason), the covering-review check passes, the PR stays report-only, and the Step 1.5 record is committed to the worktree timeline; keep the package-worktree case green.
- Update docs/design.md (Worktrees Records bullet, Merge gate text, merge_pr.sh consequences row) in the same PR.

### Actions
- [ ] The fix edits docs/design.md in the same change: the Worktrees Records bullet (~336-343), the Merge gate text (~377-380, ~502), the merge_pr.sh row (~266), and the decision-register/changelog line citing #379. The issue already says the user decided the fix; this is a recorded update, not a new question.
- [ ] Issue names only the lookup at ~670. The same legacy root also guards the Step 1.5 timeline commit (main-tree guard loop at ~816 lists `$ROOT_DIR/project` only). Fix both or state why not; otherwise a registered project's record still misses the timeline path.
- [ ] Replace the gate's `_gate_wt_repo="$ROOT_DIR/project"` with `${PJ_REPO_ROOT:-$ROOT_DIR/project}`, ideally through one shared variable used by both the cleanup lookup (line 555) and the gate (669-671), as the issue proposes.
- [ ] Extend the main-tree guard at merge_pr.sh ~816 to include `PJ_REPO_ROOT` so the Step 1.5 timeline commit never lands in a registered project's main checkout.
- [ ] Add a test_merge_pr_gate.sh case with the project registered at a non-`project/` root: the gate finds the timeline (no "no progress.md" reason), the covering-review check passes, the PR stays report-only, and the Step 1.5 record is committed to the worktree timeline; keep the package-worktree case green.
- [ ] Update docs/design.md (Worktrees Records bullet, Merge gate text, merge_pr.sh consequences row) in the same PR.

## Checkpoint
**Status**: complete
**When**: 2026-10-12 13:00 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Issue Review (48b1052) recorded six actions: one registry-aware root for the gate lookup and cleanup; the same root in the main-tree guard (~816); a test with the project registered outside project/ (gate finds the timeline, PR stays report-only, merge record lands in the worktree timeline); design.md Records, Merge gate text and the cited line numbers updated in the same PR; the two principle rows that point at these. Host recommendation: proceed, all six go into the plan.

> yes

## Plan Authored
**Status**: complete
**When**: 2026-10-12 13:01 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-379/plan.md` at `9a5833a2`

One shared registry-aware project root (PJ_REPO_ROOT with the legacy fallback) for the gate lookup, cleanup and the Step 1.5 main-tree guards, a sandbox test with the project registered outside project/, and design.md updated in the same PR.

## Plan Review
**Status**: complete
**When**: 2026-10-12 13:03 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #379 — merge_pr.sh review gate looks up a project PR's timeline at the legacy project/ path, not the registry root
**Plan**: `.agent/work-plans/issue-379/plan.md` at `9a5833a2`
**Branch**: `feature/issue-379`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three files, one variable, one test case, design text. One PR. |
| Issue alignment | Good | All six checkpoint actions are in the plan. Serves, as checked: "Quality of the work (a merge gate whose review check sees the timeline) under `docs/design.md#merge-gate`, with `docs/design.md#worktrees` (Records text cites this issue)". "Quality of the work" is a README goal section; both anchors exist (design.md lines 308, 472). No rule in `docs/design.md#rules` is broken; the A2 guard supports the "Work happens in a worktree, not the main tree" row. |
| File targeting | Good | Verified against the current `merge_pr.sh` (1648 lines): 555 (cleanup `${PJ_REPO_ROOT:-$ROOT_DIR/project}`), 669-671 (gate hard-codes `$ROOT_DIR/project`), 685 and 819 (main-tree guards), 929/931 (report-only note and record). These are the only `$ROOT_DIR/project` uses besides the comment at 251. design.md 266, 334-343, 376-377, 380, 501-502, 636, 648/650 match. |
| Consequences | Needs work | Inserting the variable after line ~270 shifts every later line, so more design.md citations go stale than the plan lists (finding 2). |
| Principle alignment | Needs work | "Test what breaks": the planned case asserts both a passing gate and a report-only refusal on the same fixture (finding 1). "A change includes its consequences": the mapping holds (see finding 4). |
| ADR compliance | Good | ADR-0011 (registry root), ADR-0013 (timeline path), ADR-0017 (design.md in the same change) addressed. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment — Test what breaks] must-fix** — Step 3's single scenario cannot pass after the fix. It sets up a covering approved review and a decision summary, then asserts "would have refused" / report-only output and a committed `## Merge (report-only)` entry. With both conditions met, `_gate_reasons` is empty, the script prints "Review gate: approved review at head ... are present" (line 910) and writes no record: `_gate_record` runs only at lines 915 and 931, inside the gap branch. Split into two scenarios. (a) All good: assert the approved line, no "no progress.md" reason, `pr merge` called, and no record. (b) A gap that is not about the timeline, for example `$APPROVED_AT_HEAD` with no summary or `$STALE`: assert "would have refused" names that reason and not "no progress.md", that `## Merge (report-only)` is committed in the registered worktree's `progress.md` and pushed, and that nothing is posted as a PR comment. Both fail on the current script, because the lookup in the missing `$sb/project` finds no worktree.
2. **[Consequences] should-fix** — design.md line citations that the edit will make stale but the plan does not list: Target item 1 (line 373) cites `merge_pr.sh` "674-675, 829-837", which is already wrong (the gate lookup is 669-671, `_gate_record` is 784-843); and the consequences row's "379-418" and "1612-1628" also move once the variable is inserted near line 270. Refresh every `merge_pr.sh` line number in design.md from the edited file, not only 555/670/916/929/685/819.
3. **[Principle alignment — Test what breaks] should-fix** — The guard scenario (registered main checkout on the PR branch) must assert the reason text "checked out in the main tree" and that the registered checkout's HEAD is unchanged, not only "PR-comment fallback". The current script also falls back to a PR comment there (with "no open worktree for the PR's repo"), so a fallback-only assertion would pass without A2 and catch nothing.
4. **[Principle alignment] note** — "Fix it completely" in the Issue Review is the AGENTS.md Quality Standard bullet ("When fixing a bug, fix it completely"), not a `docs/principles.md` principle; the review's "Tests with the change" is also not a principle name ("Test what breaks" is). The plan's mapping to "A change includes its consequences" holds for A2: once A1 lets `find_worktree_for_branch` return the registered main checkout, the old guard list (`$ROOT_DIR`, `$ROOT_DIR/project`) would let the Step 1.5 record commit there. The guard is a consequence of the fix itself, not only a sibling bug.
5. **[Prior art] minor** — `test_merge_pr.sh` (lines 694, 718) already builds registered-project sandboxes with a one-line `echo "<name> single_project <path>" >> "$sb/.agent/projects.local"`. Reuse that pattern; a dedicated helper beside `make_sandbox` is only worth adding if more than one case uses it.
6. **[Consequences] minor** — The comment at `merge_pr.sh` 250-251 ("later code default to $ROOT_DIR/project (line ~485)") points at a stale line. The new `PJ_ROOT_EFFECTIVE` line is now where that default lives, so the comment should point there.

Checked as the author asked: the new case fails on the current script (lookup in a non-existent `$sb/project` returns nothing, so the reason is "no progress.md"). The legacy-path case at line 526 cannot catch the bug, because `wt_resolve_project_repo_root` returns `$sb/project` there (legacy precedence, `_worktree_helpers.sh` 167-169), so both roots coincide, and that case has no feature worktree or timeline. The package path stays covered: `PKG_WT_DIR` sets `_gate_wt` directly (667), both guards skip when `PKG_WT_DIR` is set (681, 810), and a qualified `--pr owner/repo#N` leaves `PJ_REPO_ROOT` empty, so the effective root equals today's. The sandbox is synthetic (`make_sandbox`, `$sb/projects/proj_x`, fake remotes) and depends on no real hosted project.

### Summary

The fix itself is right and minimal. One test-design error blocks it: the planned case expects the gate to pass and report a refusal on the same fixture. With that split into two scenarios, the guard assertion tightened, and the line refresh widened, the plan is ready.

### Recommended Actions

- [ ] Split the step-3 case into an all-good scenario (approved line, no record) and a gap scenario (report-only record committed and pushed in the registered worktree's `progress.md`, no PR comment)
- [ ] In the guard scenario, assert the "checked out in the main tree" reason and an unchanged registered-checkout HEAD
- [ ] Refresh every `merge_pr.sh` line citation in design.md from the edited file, including Target item 1's "674-675, 829-837" and the row's "379-418" and "1612-1628"
- [ ] Reuse the `projects.local` one-line registration from `test_merge_pr.sh` instead of a new helper unless it is shared
- [ ] Point the `merge_pr.sh` 250-251 comment at the new `PJ_ROOT_EFFECTIVE` line

## Checkpoint
**Status**: complete
**When**: 2026-10-12 13:12 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Plan Review (4de93b8) verdict needs-work: must-fix 1 (split the test into an all-good scenario and a real-gap scenario), should-fix 2 (refresh every design.md merge_pr.sh line citation) and 3 (guard scenario asserts the specific reason and an unchanged HEAD), minor 5 (reuse the projects.local echo line) and 6 (comment at merge_pr.sh 250-251). Host recommendation: revise, then a quick second plan review.

> revise

## Plan Authored
**Status**: complete
**When**: 2026-10-12 13:12 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-379/plan.md` at `63b11d7f`

Revision 2: the test is split into an all-good, a real-gap and a main-checkout-guard scenario (each failing on the current script); every design.md merge_pr.sh line citation is refreshed after the edit; one-line project registration; stale comment at merge_pr.sh ~250 repointed.
