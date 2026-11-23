---
issue: 563
---

# Issue #563 — sit-rep: report each path on its own, as the roadmap's Direction section writes them

## Issue Review
**Status**: complete
**When**: 2026-11-23 14:12 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #563

### Scope Assessment

**Well-scoped?** Mostly, as one pull request in two commits-groups (checker and its tests, then skill text and the design row), because the checker output and the skill must change together. It touches `sitrep_checks.sh` (977 lines, parser at lines ~700-830), `sitrep_root.sh` (the `named` field), `.claude/skills/sitrep/SKILL.md` (path marks in steps 3, 5, 8; closing question) and two test files (about 2500 lines). If review shows the skill rewrite is large, split after the checker: PR A (checker emits per-path rows, `--summary-from` and `--next-steps-from` understand them, tests, old single-table roadmaps still read), PR B (skill text, `docs/design.md` Direction row). A is safe to merge alone only if the old output stays readable; say so in the plan.
**Right repo?** Yes — workspace scripts, skill and design doc.
**Serves**: Easy to use (the sit-rep is the user's view of what is next; the owner says it reads stale) and A safeguard has to earn its cost (a next step that is wrong for the path he is pushing wastes his attention) — `docs/design.md#documentation-layers` (the Direction row).
**Design picture?** Changes `docs/design.md#documentation-layers`: the Direction row describes one chain, "the first line not yet true", and a Paths paragraph naming two paths. The issue already names the update and the owner's direction (2026-11-23, "consider the path to start C"), so recorded as OK; no re-ask.
**Dependencies**: Needs the roadmap Direction text of #560 (branch `feature/issue-560`, five paths, one `| Line | Check |` table per path, an "Across the paths" table). Read there, the owner means to merge it first. If it is not on main at implementation: the code can still be built and tested against fixtures with per-path tables, but the real roadmap would still print as one group, the first acceptance run is impossible, and the roadmap line "The sit-rep reports each path on its own" (the Across-the-paths row) cannot be ticked. In that case implement behind the fixtures and hold the merge, or fall back to a single-path reading when no path paragraph precedes a table. Other: a `gh-issue N closed` line that reads "not yet done" when the fact is true and the issue stays open (bullet 4 of "What is wrong") is not in "What should be true"; the issue says the roadmap uses an existing check kind where one fits, so that part is a roadmap edit, not checker work.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | OK | `docs/design.md` Direction row is named for update in the same change; the row also still says "two paths" and "first line not yet true", both to be replaced. |
| A change includes its consequences | Action needed | Name the consequences in the plan: `sitrep_checks.sh` header grammar; `--summary`, `--summary-from`, `--next-steps-from` and the run-record summary line (comparability across old and new records); `test_sitrep_checks.sh` and `test_sitrep_root.sh`; `check_design_anchors.sh` if it reads Direction tables; sub-roadmap reading (a part's Paths paragraphs are "not read" today); SKILL.md steps 3, 5, 8 and the closing question. |
| Test what breaks | Action needed | The path-attribution rule is the new logic and has edge cases: a table with no preceding path paragraph, a path paragraph with no table ("no design yet", Path 5), the Across-the-paths table, two tables under one path, a deferral table between paths, a sub-roadmap. Each needs a fixture test, plus one run against the real #560 roadmap text. |
| Enforce what matters, as simply as possible | Watch | Prefer deriving the path from the section as written (a bold `**Path N, name.**` paragraph, then the next Line table) over a configuration; keep one parser (the `check_design_anchors.sh` sharing note shows why). |
| Ask about what matters, and show how much | Watch | Two questions from the issue are mechanism, not goal-level: row format and whether "Across the paths" is a group. Decide them in the plan from the principles and list for veto; do not send to the owner as questions. |
| Know whether it works | Watch | Say how it will be judged: the sit-rep run on the merged roadmap shows five paths with their own counts, and the old "Running: nothing advances it" wording becomes "nothing on this machine". |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0022 (parts with their own design/roadmap) | Yes | Sub-roadmap rows (`part`, `subline`) and `--next-steps-from` per part must keep working; decide whether a part's own path paragraphs are read (today they are not) or left for later. |
| ADR-0016 (user tier, session root) | Possibly | The sit-rep runs from a project root too; a project roadmap with one unnamed table must still be reported (as one unnamed path or as today). |
| ADR-0013 (progress.md entries) | Yes | This review is the entry. |

### Consequences

- Row format: adding a sixth field breaks the "five TAB-separated fields" rule that `--summary-from` enforces on saved rows. A separate `path` row emitted before each path's `line` rows (kind plus the path's name, no change to line rows) keeps old rows files valid and is the smaller change; decide this in the plan.
- The summary line stored in the run record (`lines <true>/<total> deferrals ...`): keep that prefix unchanged and append per-path counts so older records stay comparable (the issue requires this).
- `docs/design.md` Direction row: rewrite to per-path reporting and the marks that follow the paths as written.
- A path with no table at all (Path 5, "no design yet") is a paragraph with no rows; the parser needs a way to see it, or the reported list of paths would silently omit it. This is the one place the "from the section as written" rule needs the paragraph, not only the tables.
- Work marks: `named` in `sitrep_root.sh --worktrees --rows` becomes the path's name instead of yes/no; Path 2 and Path 3 goal-based fallbacks (SKILL.md around lines 414-450) are removed in favor of a plain "serves <goal>" or "unknown" mark.

### Recommendations

- Deliver as one pull request unless the SKILL.md rewrite proves large at plan time; if split, checker first and backward compatible with the old single-table roadmap.
- In the plan, decide and list for veto: row format (separate `path` row recommended over a sixth field), and the Across-the-paths table (report as a group of its own, named as the roadmap names it, not counted as behind).
- Add to the issue's "What should be true" (or the plan) what happens with the `gh-issue N closed` line whose fact is true while the issue stays open: either a roadmap edit using another existing check kind, or state it as out of scope; today the bullet describes a defect with no stated fix.
- Test against both the real #560 Direction text and a fixture set covering the edge cases above, and state which roadmap the checker was run on.
- State in the plan what changes if the #560 branch is not on main at implementation time (see Dependencies).

### Actions
- [ ] Name the consequences in the plan: `sitrep_checks.sh` header grammar; `--summary`, `--summary-from`, `--next-steps-from` and the run-record summary line (comparability across old and new records); `test_sitrep_checks.sh` and `test_sitrep_root.sh`; `check_design_anchors.sh` if it reads Direction tables; sub-roadmap reading; SKILL.md steps 3, 5, 8 and the closing question.
- [ ] The path-attribution rule is the new logic and has edge cases: a table with no preceding path paragraph, a path paragraph with no table ("no design yet", Path 5), the Across-the-paths table, two tables under one path, a deferral table between paths, a sub-roadmap. Each needs a fixture test, plus one run against the real #560 roadmap text.
- [ ] Deliver as one pull request unless the SKILL.md rewrite proves large at plan time; if split, checker first and backward compatible with the old single-table roadmap.
- [ ] In the plan, decide and list for veto: row format (separate `path` row recommended over a sixth field), and the Across-the-paths table (report as a group of its own, named as the roadmap names it, not counted as behind).
- [ ] Add to the issue's "What should be true" (or the plan) what happens with the `gh-issue N closed` line whose fact is true while the issue stays open: either a roadmap edit using another existing check kind, or state it as out of scope; today the bullet describes a defect with no stated fix.
- [ ] Test against both the real #560 Direction text and a fixture set covering the edge cases above, and state which roadmap the checker was run on.
- [ ] State in the plan what changes if the #560 branch is not on main at implementation time (see Dependencies).
