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
