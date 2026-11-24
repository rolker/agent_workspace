---
issue: 569
---

# Issue #569 — repos-manifest: remove the prototype's reader

## Issue Review
**Status**: complete
**When**: 2026-11-24 08:58 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #569

### Scope Assessment

**Well-scoped?** Yes, with a Watch. It is one removal across the tool, its docs and a few outside references; step 1 can land alone. Step 2 is the large part (code path, `--layout manifest-dir`, parent-manifest cache, `prototype.md`, tests and fixtures) and may be better as its own PR after step 1, but it is still one coherent change.
**Right repo?** Yes. The tool (`tools/repos-manifest`), the `ros2_colcon` adapter and the outside docs are all in the workspace repo.
**Serves**: Light touch on projects and Quality of the work (less to keep working; no document describing something that is gone) — `docs/design.md#registry-and-adapters`, and the part's own `tools/repos-manifest/docs/design.md#where-the-manifest-comes-from`.
**Design picture?** No change to how the parts fit. The tool's design and spec mention the prototype and get brought up to date (step 3); the issue says the format and spec do not change. The owner's decision (no old-format manifest exists) is recorded in the issue.
**Dependencies**: Step 2 depends on the adapter's older route being cut. Checked at this commit: `.agent/project_types/ros2_colcon/adapter.sh` still calls `resolve --layout manifest-dir` (line 1639) and tests for the flag (line 1644), so the reader still has a caller today. The workspace-side roadmap lines "The adapter's own manifest fetch and generated directories are removed" and "The bootstrap route is removed" are both not yet true (`docs/manifest/roadmap.md`). Issue #498 (open) is touched by step 4.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | Removes a reader with no user; the owner confirmed nothing on the old format exists on either machine. |
| Keep one current design | OK | Documents are updated in the same change (step 3). |
| Fail loudly / no silent failure (Quality Standard) | OK | The issue requires a named-reason error for an old-format manifest instead of a fall-through. |
| Keep one current design (adapter ordering) | Action needed | The plan must state whether the adapter's older route is cut in this issue or whether step 2 waits for it. As written, removing the reader first breaks `adapter.sh`, which still passes `--layout manifest-dir`. |
| Consequences checked | Watch | `.github/workflows/validate.yml:67` names the job "(#267 prototype)" and `tools/repos-manifest/tests/test_documents.py` mentions the prototype; neither is in the issue's step 3 list. `adapter.sh:751` cites `prototype.md` in a comment. `docs/roadmap.md:273` says "The resolver prototype landed on PR #268", which is history and may stay. `host_standing_rules.md` matches only on the unrelated word "prototypes", so it may need no change. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0017 (design document is the current picture) | Yes | Tool design and spec are updated in step 3. |
| ADR-0022 (a part owns its inside) | Yes | The tool has its own design; its roadmap and design are the part's, the root's design changes only where the boundary does (it does not). |
| ADR-0013 (progress entry vocabulary) | Yes | The review is recorded as an Issue Review entry. |

### Consequences

- Tests that read `tools/repos-manifest/tests/fixtures/p11/manifest.yaml` (the only old-format manifest) and the adapter's tests that exercise `--layout manifest-dir` go with the reader or must be re-pointed.
- The CI job name in `.github/workflows/validate.yml` and the pre-commit/doc checks in `test_documents.py` that refer to `prototype.md` need updating when the file goes (changing CI config is an Ask-First item for the owner; the job name is a label only).

### Recommendations

- State in the plan whether the adapter's older route is cut here, or land step 1 now and hold step 2 until the route is cut; cutting the route in the same PR is cleaner than leaving the reader with a caller.
- Add `.github/workflows/validate.yml` (job name), `tools/repos-manifest/tests/test_documents.py` and the `adapter.sh:751` comment to the step 3 list, and re-grep for `prototype` and `manifest-dir` before closing.
- Make the acceptance test for the error concrete: a manifest with no `repositories:` or `base:` key exits non-zero with a message naming the unread format, covered by a test.

### Actions
- [ ] The plan must state whether the adapter's older route is cut in this issue or whether step 2 waits for it. As written, removing the reader first breaks `adapter.sh`, which still passes `--layout manifest-dir`.
- [ ] State in the plan whether the adapter's older route is cut here, or land step 1 now and hold step 2 until the route is cut; cutting the route in the same PR is cleaner than leaving the reader with a caller.
- [ ] Add `.github/workflows/validate.yml` (job name), `tools/repos-manifest/tests/test_documents.py` and the `adapter.sh:751` comment to the step 3 list, and re-grep for `prototype` and `manifest-dir` before closing.
- [ ] Make the acceptance test for the error concrete: a manifest with no `repositories:` or `base:` key exits non-zero with a message naming the unread format, covered by a test.
