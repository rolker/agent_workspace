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
- [x] (must-fix) Direction row says only Path 2 is not a true mark; the sit-rep tests "a line names it" first (sitrep SKILL.md:447), so work on a line of Paths 2 to 4 (#393, #208, #209, #550, #551, #295) is marked Path 1 too, and Paths 4 and 5 are never marked — `docs/design.md:105`
- [x] (suggestion) Format bullet says a part still to be designed has an empty check, but the Design later row for Path 5 keeps the #396 check and will turn due; say why or empty it (design.md:105 also says every deferral has a revisit check) — `docs/roadmap.md:120`
- [x] (suggestion) Path 2's lighter level ("keeps the organisation ... only the user lowers it") and Path 5's behaviour ("reads ... does not direct them") are unattributed prose beside "no design yet"; quote the owner with the date or mark them as what was said so far — `docs/roadmap.md:55`
- [x] (suggestion) "Across the paths" opens in the present tense as if the sit-rep reported each path now, and the roadmap never says its marks still follow the three old paths (only design.md does); lead with the not-built state — `docs/roadmap.md:107`
- [x] (suggestion) The design-discussion line has no check, although design-discussion SKILL.md:288,334 already keeps its records out of progress.md; give it a check or say what remains (#544), otherwise an unchecked line reads as work to do — `docs/roadmap.md:64`
- [x] (suggestion) "five paths, each with the lines that must be true on it": Path 5 has no lines and the 15th line sits under "Across the paths" — `docs/design.md:105`

## Implementation
**Status**: complete
**When**: 2026-11-23 14:22 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-560 at `8b4dc95f`
**Addressed**: Local Review (Pre-Push) at `1bbf7bc6` (2026-11-23 14:16 -05:00)
**Commits**: a2fe45b7, f304d0ab, 9ca37d57, 986e49f3, ecce34c0, b4b8b8af, 8b4dc95f

### Actions
- [x] (must-fix) Format block restored from origin/main word for word (diffed: identical), the branch's Line-table bullet kept after it — `docs/roadmap.md` (a2fe45b7)
- [x] (must-fix) test_skill_paths.sh reads Path 1 to Path 5 in order, each as the sit-rep's step 3 parses it, allows a `| Line | Check |` table after a path's paragraph, and still fails on any other table among the paths or a table row inside a paragraph (each case tried on a changed copy); header says five Paths — `.agent/scripts/tests/test_skill_paths.sh:7,895` (f304d0ab)
- [x] (must-fix) Direction row says the sit-rep checks first whether a Direction line names the work (any path's line gives Path 1), Path 3 for the safeguard goal, Path 2 for other goal work, Paths 4 and 5 never marked, until #563; change-log row for #560 reworded, line count 1217 unchanged — `docs/design.md:105,1163` (9ca37d57)
- [x] (suggestion) Design later row for the home level (Path 5) split from the orchestrator design session (#398): the first has an empty check, the second keeps `gh-issue rolker/unh_marine_autonomy#396 closed`; design.md says a part still to be designed has an empty revisit check — `docs/roadmap.md`, `docs/design.md:105` (986e49f3)
- [x] (suggestion) Path 2's lighter level and Path 5 now in the owner's words (2026-11-23) as the host gave them; the principle is quoted verbatim from docs/principles.md:10 ("Limits on what agents do on their own start strict, and only the user relaxes them") — `docs/roadmap.md` (ecce34c0)
- [x] (suggestion) Across the paths leads with "To be built (#563)" and says the marks still follow the three earlier paths — `docs/roadmap.md` (b4b8b8af)
- [x] (suggestion) The design-discussion line now says what remains: the issue loop ignores timeline entries of another kind of work (#544), check left empty — `docs/roadmap.md` (8b4dc95f)
- [x] (suggestion) Direction row: Paths 1 to 4 have line tables, Path 5 none yet, one line under Across the paths — `docs/design.md:105` (9ca37d57)

Checks: sitrep_checks.sh --root/--roadmap on the worktree exit 0: 15 line, 10 deferral, 2 part, 37 subline, 10 subdeferral rows, 0 format rows. check_design_anchors.sh exit 0. update_roadmap.sh --issue N --dry-run for 544, 563, 398 finds no entries. Suites: test_skill_paths.sh 198 passed, 0 failed; test_sitrep_checks.sh 252 passed, 0 failed. Every commit used SKIP=validate-script-tests; the full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 14:23 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-560 at `e1d515f5`
**Base**: origin/main
**Depth**: Standard (reason: round 2 convergence check per handoff, on the round 1 findings and the fix diff since 711f23d5)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round 1 findings, all closed: the Format block matches origin/main byte for byte plus the new bullet; test_skill_paths.sh now passes and fails on a missing, misnumbered or unreadable Path paragraph, a non-Line table among the paths, a table row inside a paragraph, and a three-column header (mutations run by hand); the design.md Direction row matches sitrep SKILL.md:444-450 (named line first gives Path 1, project-goal override, Path 3, Path 2; Paths 4 and 5 never marked); the Path 5 Design later row is empty and the orchestrator session has its own row; Path 2 and Path 5 now quote the owner with dates, and the principle is quoted as docs/principles.md:10 has it; Across the paths leads with "To be built (#563)"; the shared-issue line names #544; the design row says Path 5 has no lines and one line sits under Across the paths.
Host decision recorded, not a finding: the acceptance-case paragraph drops the sentence about the fresh OS install on the second machine; it is listed for the owner's veto at the merge.
Checks: test_skill_paths.sh 198 passed 0 failed; test_sitrep_checks.sh 252 passed 0 failed; sitrep_checks.sh exit 0 (15 lines, 10 deferrals, no format rows); check_design_anchors.sh exit 0; pre-commit on the three changed files clean (validate-script-tests skipped). Cross-model skipped: the fix commits restore reviewed text or change a test and wording the local checks cover.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**When**: 2026-11-23 14:29 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 2 pre-push review approved with nothing open; the full pre-commit pass with no SKIP exited 0 at ab0073e7; the owner asked for this: "review the Y1 with the goal of merging it")
**After**: publish
**Decision**: publish

Push the branch and open the pull request. The merge is the owner's.

## Integrated Review
**Status**: complete
**When**: 2026-11-23 14:45 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Reviews-read**: none

**PR**: #564 at `f3fe8604`
**Sources**: 2 (Local Review (Pre-Push) R1 @ `1bbf7bc6` and R2 @ `e1d515f5` via `review_progress.sh sources`, CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

Hosted review (Copilot): did not arrive. No `copilot-pull-request-reviewer` check-run and no review on the head from the pull request's opening (14:29:34) to 14:44:50, the about-900 s bound of run-issue's hosted-review wait; the pull request has no review requests and no conversation comments. A review that lands later is caught by the re-fetch before the merge checkpoint.
Local timeline: `sources` at head `f3fe8604` returned no open local findings and no dropped entries. Round 1 (pre-push, `1bbf7bc6`) had 3 must-fix and 5 suggestions, all ticked in the Implementation entry (`8b4dc95f`); round 2 (pre-push, `e1d515f5`, approved) found nothing. The commits since `e1d515f5` touch only this issue's progress.md (bookkeeping). Which outside models ran in round 1 is not recorded in progress.md; the host reports Gemini, Codex and a Claude adversarial reviewer ran there.
Known and accepted, not a finding: until issue 563 lands, the sit-rep reads the new section's line tables as one list and marks work any line names as Path 1; the roadmap and the design.md Direction row say so. The owner: "To keep things simple, it's ok if something breaks with the sit-rep skill if one lands before the other".
CI at 14:44: 9 of 10 check runs success (Lint, Validate Documentation, Validate Adapter Contract, repos-manifest tests 3.10 both runs, 3.14 one run); one repos-manifest tests (Python 3.14) run still in progress. Not waited on.

### Findings
No open findings. (Host correction: the triage wrote this sentence as an unchecked box, which the dispatcher counted as an open finding.)

### False positives
- none

## Checkpoint
**When**: 2026-11-23 14:48 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

The owner's words: "Don't wait for copilot on github anymore, I've disabled auto running it since we run out of quota each month within days. merge when ci is green". Merge pull request 564 once CI is green; no relaxing flag is passed.
