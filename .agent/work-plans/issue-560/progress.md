---
issue: 560
---

# Issue #560 — Workspace design review, November 2026: sharpen the direction and update the roadmap

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 14:16 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-560 at `1bbf7bc6`
**Base**: origin/main
**Depth**: Standard (reason: 184 changed lines in two docs files)
**Must-fix**: 3 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes (all three are mechanical)

Plan drift: no plan.md; the 2026-11-23 design discussion with the owner was the plan, so there was nothing to compare against.
Checks run: sitrep_checks.sh --root/--roadmap on the worktree exit 0, 15 line rows, no format rows; check_design_anchors.sh exit 0; update_roadmap.sh --dry-run for every issue the section cites changes nothing; test_sitrep_checks.sh 252 passed 0 failed; test_skill_paths.sh 197 passed 1 failed (finding 2); pre-commit on both files clean (validate-script-tests skipped).
Every check cell follows the grammar (gh-issue, owner/repo#N, ' ; ' joins, empty cells read unchecked). Owner quotes are each marked as quotes with a date.

### Findings
- [x] (must-fix) Format block cut off mid-bullet at an open backtick; the grammar bullets (table headers, Sub-roadmap/Root and citation rules, check kinds, never-just-an-issue-number, deferral due rule) were deleted; restore them and keep the new bullet — `docs/roadmap.md:118`
- [x] (must-fix) test_skill_paths.sh fails on the new layout ("table row between the Paths paragraphs: | Line | Check |"); allow a Line table under each path, require Paths 1 to 5, update the header's "three Paths" — `.agent/scripts/tests/test_skill_paths.sh:895`
- [ ] (must-fix) Direction row says only Path 2 is not a true mark; the sit-rep tests "a line names it" first (sitrep SKILL.md:447), so work on a line of Paths 2 to 4 (#393, #208, #209, #550, #551, #295) is marked Path 1 too, and Paths 4 and 5 are never marked — `docs/design.md:105`
- [ ] (suggestion) Format bullet says a part still to be designed has an empty check, but the Design later row for Path 5 keeps the #396 check and will turn due; say why or empty it (design.md:105 also says every deferral has a revisit check) — `docs/roadmap.md:120`
- [ ] (suggestion) Path 2's lighter level ("keeps the organisation ... only the user lowers it") and Path 5's behaviour ("reads ... does not direct them") are unattributed prose beside "no design yet"; quote the owner with the date or mark them as what was said so far — `docs/roadmap.md:55`
- [ ] (suggestion) "Across the paths" opens in the present tense as if the sit-rep reported each path now, and the roadmap never says its marks still follow the three old paths (only design.md does); lead with the not-built state — `docs/roadmap.md:107`
- [ ] (suggestion) The design-discussion line has no check, although design-discussion SKILL.md:288,334 already keeps its records out of progress.md; give it a check or say what remains (#544), otherwise an unchecked line reads as work to do — `docs/roadmap.md:64`
- [ ] (suggestion) "five paths, each with the lines that must be true on it": Path 5 has no lines and the 15th line sits under "Across the paths" — `docs/design.md:105`
