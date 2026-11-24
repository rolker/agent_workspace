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

## Checkpoint
**When**: 2026-11-23 14:12 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review's actions are directions for the plan and change no scope; the owner asked for this start: "as soon as practical, do Y2 and Y3")
**After**: issue-actions
**Decision**: proceed

Proceed to planning. The owner's words this serves (2026-11-23): "the roadmap was done with an expected sequence, and any deviation from that sequence might trip up the tracking of actual progress."

Instructions for the plan (host decisions, listed for the owner's veto):
- One pull request, in two commit groups: the checker with its tests, then the skill text with the Direction row of docs/design.md.
- Row format: a separate `path` row ahead of each path's lines, not a sixth field, so saved rows keep five fields.
- The "Across the paths" table is a group of its own, reported under that name and never counted as behind. A path with no table (no design yet) says so and is not behind.
- A Direction section with no Path paragraph (a project's roadmap, or the workspace's before the five-path section lands) is read as today: one group. The plan states this as the compatibility rule and tests it.
- A `gh-issue N closed` line whose fact is true while the issue stays open is out of scope for the checker: the roadmap uses another existing check kind where one fits, else an empty cell. The plan says so.
- Tests: fixtures for the path-attribution cases the review lists, plus one run against the real five-path Direction text (branch feature/issue-560 until it is on main); the plan says which roadmap each test reads.
- The plan names every consequence the review lists (checker header grammar, the summary options and the run-record line, both test files, check_design_anchors.sh, sub-roadmap reading, skill steps 3, 5 and 8 and the closing question).

## Plan Authored
**Status**: complete
**When**: 2026-11-23 14:14 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-563/plan.md` at `26296dba`

One PR in two commit groups: the checker emits a `path` row per Path paragraph (five fields kept), with per-path summary suffix and next steps, plus `named_path` in sitrep_root.sh; then skill text and the Direction row. A roadmap with no Path paragraph reads as today.

Owner direction recorded (2026-11-23): "To keep things simple, it's ok if something breaks with the sit-rep skill if one lands before the other". The plan adds no work for the interval between #560 and this change landing and plans no split into two pull requests for it; the no-Path-paragraph compatibility rule stays, for other roots.

## Plan Review
**Status**: complete
**When**: 2026-11-23 14:18 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #563 — sit-rep: report each path on its own, as the roadmap's Direction section writes them
**Plan**: `.agent/work-plans/issue-563/plan.md` at `26296dba`
**Branch**: `feature/issue-563`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One pull request, two commit groups, as the host checkpoint ordered; checker, root helper, skill, design row and tests change together. It is large mainly because existing skill tests must be rewritten (finding 3), which the plan does not count. No hidden second pull request, except the roadmap edit if this merges before #560 (suggestion 4) |
| Issue alignment | Needs work | Covers every "What should be true" bullet and every host checkpoint instruction (one PR, `path` row, Across a group never behind, the no-Path compatibility rule, `gh-issue` out of scope, fixtures plus a real-text run, named consequences). Serves, as checked: "Easy to use (the sit-rep is the user's view of what is next), and A safeguard has to earn its cost; `docs/design.md#documentation-layers` (the Direction row)": goals exist in README, anchor exists. Gaps: the plain mark for work no line names is not defined (finding 4); lines that come before the first path paragraph have no next step (finding 1) |
| File targeting | Needs work | Missing: `.agent/knowledge/script_reference.md` (finding 6). Existing tests in sections 13 and 14 of `test_sitrep_checks.sh` are not listed for change (finding 3) |
| Consequences | Needs work | Misses SKILL.md step 1 and step 5's per-line lookup (finding 2), the #560 wording of the Direction row (finding 5) and the Measures row. Every reader of the rows was checked: `sitrep_root.sh` (named in the plan); SKILL.md steps 1, 3, 5, 8 (step 1 missed); `script_reference.md` (missed); `design-discussion` SKILL.md runs the checker on drafts and reads only the `part` result (not affected); `check_design_anchors.sh` reads `--list-pointers` only (confirmed at line 435). Run-record readers: SKILL.md steps 2 and 8 only (cut -f4 and -f5- keep working, since the suffix holds no TAB) |
| Principle alignment | Needs work | "Test what breaks": new cases are well chosen, but tests that will break are not named. "Keep one current design": the row to edit is the one #560 rewrites. "Enforce what matters, as simply as possible": deriving paths from the section is right; the position rule needs its edges written down (suggestion 1) |
| ADR compliance | Good | ADR-0022: part/subline rows and next steps per part unchanged, a part's own paths left for later. ADR-0016: a root with no Path paragraph reads as today. ADR-0013: entries in order. ADR-0017 is covered by finding 5 |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Issue alignment] must-fix**: Lines before the first path paragraph are left with no next step when paths exist. Item 4 keeps a `line` table above the first `**Path` paragraph ungrouped, and the tests check that case. Item 6, however, replaces the single `(root)` next-steps line with one line per path whenever `path` rows exist. Those ungrouped lines then appear in no next step and in no suffix count. `named_path` would be "" for work they name, so the mark falls through to "serves <goal>" and loses that a line names the work. Say what happens (for example, keep a `(root)` line for the ungrouped lines when there are any) and test it.
2. **[Consequences] must-fix**: SKILL.md step 1 is missing from the plan. Its text lists the row kinds and describes `--- next steps` as "one line for the root, `(root)`" (lines 147-168), and both become wrong. Step 5's lookup block pastes the `item` and `check` of the first line not true, then finds its issues, branch and pull request. With several paths it must run once per path, but the new next-steps lines carry no check cell. Say where each path's check comes from (its row in step 1's output) and that the lookup repeats per path. Step 8's rule for a pull request with no worktree (lines 1199-1206: "`Path 1` when a Direction line names its issue") is another hardcoded Path 1 mark. `named_path` cannot cover it, since `sitrep_root.sh` sees only worktrees. Give that rule a path name taken from the rows.
3. **[Principle alignment: Test what breaks] must-fix**: Existing tests that will break are not named. Section 13 (step 1 fixture at line 819: `**Path 1, One.**`, `**Path 2, Two.**`, then a Line table) expects `(root)\tnone open` (line 836). Under the new rule that table belongs to Path 2 and the next-steps lines change. Tests around lines 1176-1262 and 1286-1296 assert `Path 1`, `Path 2`, `Path 3` and `no path` marks and the step 8 wording. Section 14 calls `proj_roadmap paths` by default, which writes `**Path 1, Ship.**`, and lines 1610-1620 assert `Path 1` and `no path (serves a project goal)`. The plan says section 14's fixtures "give output identical to current expected strings", which is untrue for that default fixture. List these rewrites in the Tests section.
4. **[Issue alignment] must-fix**: The plain mark for work no line names, "serves <goal>", is not defined. A Serves line is free text (this issue's runs to two goals plus a design anchor), so say what is printed: for example, the README goal names it cites, or the text up to the first `;` or `—`. Also say what each of today's cases becomes: Serves `none` (today `no path`, which "is itself worth seeing"), no complete Issue Review, a review with no Serves line, and step 1 with no rows (`path unknown (steps not checked)`). Today a root with no Paths paragraph prints no path word (section 14 test at line 1626). Say whether that stays, since the new rule would print "serves ..." in such a project session.
5. **[Consequences / Keep one current design] must-fix**: #560 already rewrites the same Direction row (commit 1bbf7bc6 on `feature/issue-560`). Item 10 quotes main's wording ("names the first line not yet true", "A Paths paragraph names the two paths"), and that wording will be gone once #560 lands. The sentences that this change makes untrue are #560's: "reads the paths' line tables as one list and names the first line not yet true as the next step (reporting each path on its own is a line of the section, not built)" and "Its marks still follow the three paths of before #560 ... so Path 2 is not a true mark until the sit-rep follows the section as written". Name them, and write the edit against #560's row (whichever lands second rebases). The Measures row ("the counts of lines true and deferrals due") should also mention the per-path counts the record gains.
6. **[File targeting] must-fix**: `.agent/knowledge/script_reference.md` is not in the plan. Lines 55-56 describe `sitrep_root.sh --worktrees --rows` fields (`named`, `named_part`) and `sitrep_checks.sh` row kinds and `--next-steps-from` ("root, then each followed part"). Add `named_path`, `path` rows and next steps per path.
7. **[Approach] suggestion**: The position rule silently assigns a Line table placed after the `**Format.**` paragraph, a deferral table or the Across paragraph to the last group above it. Main's roadmap today has `**Path 1..3**` paragraphs and its one table after Format, so until #560 lands it reads as Path 3 holding all four lines and Paths 1 and 2 as "no design yet". The owner accepted breakage in that interval, but the plan should say this plainly instead of "the rule is about other roots". State the rule as "the nearest `**Path`/`**Across` paragraph above" in the checker header and in the roadmap's Format bullet, and add a fixture with a table after the Format paragraph.
8. **[Approach] suggestion**: Define "opens" exactly. A `**Path <n>` at the start of a wrapped continuation line (`prev_para` true) is not a path paragraph. Bold text that wraps onto a second line must be joined first, or required to sit on one line. Pin the pattern so `**Paths.**` never matches (the skill uses `^\*\*Path [0-9]+`). Test each case.
9. **[Approach] suggestion**: `path` rows must not count toward `SCAN_ROWS`. Otherwise a section with path paragraphs and empty Line tables loses its `(no rows in the Line or Deferral tables)` section row. A `path` row's result is known only after its table, so it is patched back as `follow_pointer` patches `ROWS[idx]`. State whether Across's result is `true` or `unchecked`; item 2 gives only its check, `group`.
10. **[Consequences] suggestion**: "Tick the Across-the-paths line … via the repo's roadmap-update path" does not fit a `| Line | Check |` row. The section holds no status, and `update_roadmap.sh` ticks checklist items, which the Format rules forbid here. Give the line a check that can be true (for example `file-contains .agent/scripts/sitrep_checks.sh <header phrase>`), or drop it. If this pull request merges before #560, that edit and the "Until that is built" sentence belong in #560's branch, not in a later third pull request.
11. **[Consequences] suggestion**: Step 8's report shape needs a sentence. The top part is meant to fit in about 20 lines, but a block per path listing every line not true can exceed that with five paths plus Across. "What the next step is for" (`acceptance_first`) is now the test of Path 1 only. The rule "the next step's branch is always among the five shown" is singular. Say how each of these reads per path.
12. **[Consequences] suggestion**: Run record. The prefix stays comparable. The suffix example lists `across` before `P5`, which is not roadmap order, so fix one or the other. "What moved" should compare per path only when both records carry the suffix and the same labels, because a renumbered path would otherwise compare unlike things. The comparison lives in step 8, not step 4 (step 2 reads the record, step 4 writes it).
13. **[Prior art] suggestion**: `part`/`subline` rows attribute by item prefix (`<path>: <item>`), not by position (`sitrep_root.sh` line 458 matches on the prefix), so they are only partly the model. Say in the header that rows are read in order and that a `path` row governs the `line` rows up to the next `path` row.

### Summary

The design choices are sound and follow the host checkpoint: a separate `path` row, Across as a group never behind, compatibility by the absence of Path paragraphs, the prefix kept, and `named_path` beside `named`. The plan needs one revision before implementation. It leaves the next step undefined for lines above the first path. It misses SKILL.md step 1, step 5's per-path lookup and the pull-request-only mark. It does not name the existing skill tests that will break, and wrongly claims section 14 is unchanged. It leaves the "serves <goal>" mark undefined and edits the Direction row by main's wording instead of #560's. It also misses `script_reference.md`.

### Recommended Actions

- [ ] Define the next step, suffix count and mark for lines above the first path paragraph when paths exist; test it.
- [ ] Add SKILL.md step 1 (row kinds, next-steps description), step 5's lookup per path (where each path's check cell comes from) and step 8's pull-request-only mark to the plan.
- [ ] List the existing tests to rewrite: section 13 (lines 819-836, 1176-1262, 1286-1296) and section 14 (lines 1539, 1610-1634); correct the claim that section 14 output is unchanged.
- [ ] Define the plain mark text and what Serves `none`, no complete review, no Serves line, steps not checked and a no-Paths root each print.
- [ ] Write the Direction row edit against #560's wording (name its two sentences) and touch the Measures row.
- [ ] Add `.agent/knowledge/script_reference.md` (lines 55-56) to Files to Change.

## Checkpoint
**When**: 2026-11-23 14:20 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is revise; its findings are missed consequences and undefined edges, none changes what the work is for)
**After**: plan
**Decision**: revise

Revise the plan to close M1 to M6 and S1 to S7 of the Plan Review. Host decisions for the revision (listed for the owner's veto):
- M1: lines in a table above the first path paragraph are a group of their own, reported as "no path", with its own count and unmet lines like any path.
- M2: the plan names every part of the skill text it changes, including step 1's row kinds and next-steps text, step 5's lookup (which reads what it needs from the saved rows, per path), and step 8's mark for a pull request with no worktree: the path whose line names its issue, read from the saved rows.
- M3: the plan names each existing test that changes, by section and line, and what it will assert after.
- M4: marks for work in flight. A line names it: that path's name as the roadmap writes it. No line names it: "no path line", then in brackets one of: serves a goal; serves no goal; no complete issue review; its issue review has no Serves line. Rows not saved: "path unknown (steps not checked)". A root with no Path paragraph: no path word, as today. The Path 2 and Path 3 rules in the skill text are removed.
- M5: the plan assumes the five-path roadmap (issue 560) is on main first, which is the host's order, and edits the Direction row as that change leaves it; the Measures row gains the per-path counts.
- M6: `.agent/knowledge/script_reference.md` is in the change.
- S1, S2: a table belongs to the nearest path or Across paragraph above it; the rule goes in the roadmap's Format block and the checker header. A paragraph opens a path when its first line starts with `**Path <n>` once a bold span wrapped over two lines is joined; `**Paths.**` never matches. The plan says plainly that main's roadmap reads wrongly until the five-path section lands, which the owner accepted: "it's ok if something breaks with the sit-rep skill if one lands before the other".
- S3: path rows do not count as rows of a table; the Across group's label is "across the paths".
- S4: the roadmap's Across line gets a real check (a `file-contains` on the checker for text this change adds; the plan names the text), not a tick.
- S5: the top of the report gives one line per path: its name, how many of its lines are true, and its first line not yet true as written. The full lists stay in the Steps section. The line after the heading names the acceptance case as Path 1's test. Branches that match any path's unmet line come first in In flight.
- S6: the run-record suffix lists paths in roadmap order; two records are compared per path only when both carry the same labels.
- S7: correct the three claims the review found untrue.

## Plan Authored
**Status**: complete
**When**: 2026-11-23 14:21 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-563/plan.md` at `2a3c82bc`

Revision 2, closing the Plan Review (M1 to M6, S1 to S7) per the host's checkpoint. Ungrouped lines form a `no path` group; the skill's steps 1, 3, 5, 8, the design rows, script_reference.md and the roadmap's Across line (a file-contains check) are all named; existing tests to rewrite are listed; marks have exact texts. Read #560's roadmap at b4b8b8af. Owner direction kept: "To keep things simple, it's ok if something breaks with the sit-rep skill if one lands before the other".

## Plan Review
**Status**: complete
**When**: 2026-11-23 14:23 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #563 — sit-rep: report each path on its own, as the roadmap's Direction section writes them
**Plan**: `.agent/work-plans/issue-563/plan.md` at `2a3c82bc`
**Branch**: `feature/issue-563`

Round 2: a convergence check of revision 2 against the round-1 findings and the host's Checkpoint (After: plan, Decision: revise). Not a full review.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one pull request, two commit groups; no hidden second pull request now that #560 is assumed on main first (host order) |
| Issue alignment | Good | Every host decision M1 to S7 is followed. Serves, as checked: "Easy to use (the sit-rep is the user's view of what is next), and A safeguard has to earn its cost; `docs/design.md#documentation-layers` (the Direction row)" |
| File targeting | Good | `script_reference.md`, `docs/roadmap.md` and the existing tests are now listed |
| Consequences | Needs work | One new gap: steps 5 and 8 read the rows file after step 4 has deleted it (finding 1) |
| Principle alignment | Good | The tests to rewrite are named; the design rows are edited against #560's wording, which was checked on `feature/issue-560` (both quoted sentences are present) |
| ADR compliance | Good | ADR-0017 added; ADR-0022, 0016 and 0013 unchanged |
| ROS conventions | N/A | Workspace plan |

Round-1 findings:
- M1 (lines above the first path): closed. A `no path` group with its own count, next step, suffix label `nopath` and `named_path`, and a test, as the host decided.
- M2 (SKILL.md steps 1, 5, 8): partly closed. All three are named, but steps 5 and 8 read a file that no longer exists (finding 1).
- M3 (existing tests): closed. Sections 13 and 14 are named with what they will assert; the section 14 claim is corrected.
- M4 (mark texts): closed. Exact texts as the host decided; a root with no Path paragraph prints no path word.
- M5 (#560's Direction row): closed. Both of #560's sentences are named and are present on `feature/issue-560`; the Measures row is included.
- M6 (`script_reference.md`): closed.
- S1 (nearest paragraph rule, main's interval said plainly): closed.
- S2 (what "opens" a path): closed.
- S3 (path rows not counted, Across result): closed. Across is `true`/`group` or `unchecked`/`no lines`.
- S4 (a real check for the Across line): closed, with finding 4.
- S5 (report length): partly closed. One line per group at the top, the acceptance case as Path 1's test, and in-flight order per group are set; where `Next:` and `Running:` go is not (finding 3).
- S6 (suffix in roadmap order, compare only on the same labels): closed.
- S7 (the three untrue claims): closed.

### Findings

1. **[Consequences] must-fix**: Steps 5 and 8 read a rows file that step 4 has already deleted. Item 13 has step 5 "take its check cell from the saved rows file", and item 14 marks a pull request with no worktree "read from the saved rows". But step 4 ends with `[ -z "$rows" ] || rm -f -- "$rows"` (SKILL.md line 644, "The rows file is removed either way"), and steps 5 and 8 run after it. As written, step 5's lookup and step 8's mark would find no file. Say which: read from step 1's printed rows, as step 5 does today ("as step 1 printed them"), or move the removal to the end of step 8 (and say so in step 4's text).
2. **[Consequences] suggestion**: The closing question's path list is to be "read from the `path` rows". When step 1 printed no rows (checks failed), it would then have no paths. Step 1's text (lines 182-185) says the Paths "still come from the section's prose" in that case. Keep the awk block as the source of the names, or say what the question offers when there are no rows.
3. **[Consequences] suggestion**: Item 14 gives one line per group at the top and renames "Running: nothing advances it" to "Running: nothing on this machine", but does not say where `Next:` and `Running:` now go. Options are: per group, at the end of each group's line; or only for the focus the owner picks. Say the same for the rule "only when every line is true does Suggested next come from elsewhere".
4. **[Approach] suggestion**: The Across check works under the existing grammar. `file-contains` takes the rest of the check as one fixed string (`^file-contains\s+(\S+)\s+(.*\S)$`, then `grep -qF`), so a multi-word text is fine. But `grep` matches within one line, so the header sentence "a path row governs the line rows up to the next path row" must sit unwrapped on one comment line. Say so in item 2 or 10; section 16's test of the check will catch a wrap.
5. **[Approach] suggestion**: An `**Across the paths` paragraph in a section with no `**Path` paragraph is decided both ways. Item 1 says it opens a group; items 3 and 5 say no `**Path` paragraph means no `path` rows. Pick one, for example "Across opens a group only when a path paragraph exists".
6. **[Consequences] suggestion**: The cost of step 5 per path is acceptable but should be stated. On the five-path text, about five groups have an issue in their first unmet line, so about ten `gh` calls instead of two. Step 3's `gh pr list` already holds the open pull requests and could be reused instead of one `gh pr list` per issue.

### Summary

The revision closes 11 of the 13 round-1 findings and follows each host decision. One new defect blocks: steps 5 and 8 are told to read the rows file after step 4 has deleted it. It is a one-sentence fix (read step 1's printed rows, or move the removal), which the host can give as an instruction at the plan checkpoint instead of another plan round.

### Recommended Actions

- [ ] Steps 5 and 8: read step 1's printed rows, or move the rows file's removal from step 4 to the end of step 8; say which.

## Checkpoint
**When**: 2026-11-23 14:29 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 2 of the plan review closed every earlier finding; its one new must-fix is a one-sentence fix the reviewer said could be given here, and a third plan round would add a wait without a decision in it)
**After**: plan
**Decision**: proceed

Implement the plan at 2a3c82bc with these instructions, which answer N1 to N6 of the round 2 Plan Review and bind the implementer (host decisions, listed for the owner's veto):
- N1: steps 5 and 8 of the skill read the rows step 1 printed, as step 5 does today, never the rows file, which step 4 removes. When the file is removed does not change.
- N2: the closing question's path list keeps its own block that reads the roadmap's prose, so it still works when step 1 printed no rows.
- N3: with path groups there is no single "Next:" line. Each group's line at the top carries its first line not yet true. "Running:" stays in In flight; one line there names the groups with no work on this machine ("No work on this machine for: ..."). When every line of every group is true, Suggested next comes from elsewhere, as today.
- N4: the checker-header sentence the roadmap's Across check looks for stays on one comment line; the planned test covers it.
- N5: in a section with no Path paragraph, an "Across the paths" paragraph opens no group: no path rows at all (the compatibility rule wins).
- N6: step 5 reuses the pull request list step 3 already fetched; the per-issue title lookups are accepted, and the plan's cost note says so in the pull request.
- Re-read docs/roadmap.md and the Direction row of docs/design.md as they are on main (or on feature/issue-560 if pull request 564 has not merged) before editing them.

The owner's words: "the roadmap was done with an expected sequence, and any deviation from that sequence might trip up the tracking of actual progress."; "To keep things simple, it's ok if something breaks with the sit-rep skill if one lands before the other".

## Implementation
**Status**: partial
**When**: 2026-11-23 14:56 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-563 at 66f0a01d

Stopped at 14:55 for the owner's 15:00 shutdown. Nothing pushed.

### Done (commits in order)
- db7d84c8 sitrep_checks: path rows, no path group, Across group, summary suffix (paths P<n> t/n), per-path --next-steps-from, header (the Across sentence on one comment line); suite section 16, plus rewritten step 1 and step 4 assertions.
- d0e61f15 sitrep_root: named_path field, header; test_sitrep_root named_path cases.
- 66f0a01d SKILL.md steps 1, 3 (marks per the checkpoint's M4 texts; closing-question block keeps reading prose and adds an across line, N2), 5 (per path, item and check from step 1's printed rows, N1; pull requests from step 3's pasted list, N6), 8 (one line per group, no single Next:, "No work on this machine for:", N3; "nothing on this machine"); description; tests in sections 13 and 14 rewritten.

### Suites
- test_sitrep_checks.sh: "test_sitrep_checks: 281 passed, 0 failed"
- test_sitrep_root.sh: "test_sitrep_root: 69 passed, 0 failed"
- test_skill_paths.sh: "test_skill_paths: 197 passed, 1 failed": the failing case is "Path 3 marker: .claude/skills/sitrep/SKILL.md no longer carries 'A safeguard has to earn its cost'". It guards the old Path 3 rule this change removes on purpose; it must be removed or rewritten (first item below).
- Full pass left to the host.

### Live run
Frozen five-path text (feature/issue-560 at f3fe8604, now merged as 9a8c1eaf): P1 1/4, P2 0/4, P3 0/3, P4 0/3, P5 none (no design yet), Across 0/1; summary "lines 1/15 deferrals 3/10 paths P1 1/4 P2 0/4 P3 0/3 P4 0/3 P5 none across 0/1". Suite section 16 keeps an anonymised frozen copy (text main will change, including this issue's Across edit), not main's live file.

### Remains, in plan order
1. test_skill_paths.sh: drop or rewrite the "Path 3 marker" case for the sit-rep skill, then rerun that suite.
2. Coordinator update: pull request 564 merged (9a8c1eaf). git fetch origin, merge origin/main into feature/issue-563 (merge commit), then:
   - docs/roadmap.md Format bullet: after "A path's lines sit in a ... table of their own under the path's paragraph." add "A table belongs to the nearest path or Across paragraph above it."
   - docs/roadmap.md Across paragraph in present tense: "**Across the paths.** The sit-rep reports each path on its own, with its lines in no fixed order, and marks work in flight by the path whose line names it." Its line's check: file-contains .agent/scripts/sitrep_checks.sh a path row governs the line rows up to the next path row
   - docs/design.md Direction row: replace "reads the paths' line tables as one list and names the first line not yet true as the next step (reporting each path on its own is not built, #563)" with per-path reporting (each path's name, count and unmet lines in no fixed order; Across a group; a path with no table is "no design yet"; a root with no Path paragraph is one group), and the "Until the sit-rep reports each path on its own (#563) ... Paths 4 and 5 are never marked" sentence with the marks of plan item 12; Measures row: the per-path counts the run record gains; a history row.
3. .agent/knowledge/script_reference.md lines 55-56: named_path, the path row, per-path next steps, the summary suffix.
4. Live run on main's docs/roadmap.md after the merge, recorded in the pull request.

### Deviations
- Path rows are inserted in one pass after the scan (group_rows), not patched back by index; same output.
- Step 3 decides "written as paths" from step 1's rows when given (a path row present), else from the prose; the plan did not say.
- Mark for a pull request with no worktree: path name read from step 1's printed rows (N1).

## Checkpoint
**Status**: complete
**When**: 2026-11-24 08:22 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (first retry of this phase; the pass did not fail, it stopped at 14:55 for the owner's 15:00 shutdown with its remaining items listed)
**After**: phase-failed
**Decision**: retry
**Phase**: implement

The owner asked for this drive today: "/orchestrator 563 and 428". The newest Implementation entry is partial because of the shutdown, not a defect. The retry finishes its "Remains, in plan order" list (items 1 to 4), under the same instructions as the plan checkpoint of 2026-11-23 14:29 (N1 to N6, M4, M5).

## Implementation
**Status**: complete
**When**: 2026-11-24 08:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-563 at `52e05356`

Retry that finishes the 2026-11-23 14:56 partial pass; its "Remains" items 1 to 4 are done, in order.

### Done (commits in order)
- 06230cc8 test_skill_paths: the "Path 3 marker" case is rewritten, not dropped. It now checks only README.md and review-issue's SKILL.md for "A safeguard has to earn its cost" (review-issue's Serves rule tells reviews to write that README line word for word, so the two must still agree); the sit-rep's SKILL.md is no longer in it. review-issue's SKILL.md drops its parenthesis "(the sit-rep marks such work by that phrase)", which this change makes untrue.
- 545ee328 merge of origin/main (164 commits, pull request 564 among them) with a merge commit. No conflicts. Main changed none of the sit-rep's skill or scripts, nor their test files, since the branch point e8cd279d (`git log` over `.claude/skills/sitrep`, `sitrep_checks.sh`, `sitrep_root.sh` and their tests is empty); `test_skill_paths.sh` merged automatically (main added its five-paths reading case, f304d0ab). Nothing needed reconciling.
- 8443b1db docs/roadmap.md: the Across paragraph in present tense ("The sit-rep reports each path on its own, with its lines in no fixed order, and marks work in flight by the path whose line names it."); its line's check `file-contains .agent/scripts/sitrep_checks.sh a path row governs the line rows up to the next path row`; the Format bullet gains "A table belongs to the nearest path or Across paragraph above it." No other wording there changed. docs/design.md: the Direction row's one-list sentence becomes per-path reporting (name, lines true, lines not yet true, no fixed order; Across a group never behind; no table = "no design yet"; lines above the first path = "no path"; no Path paragraph = one group as before), and the "Until the sit-rep reports each path on its own (#563) ... Paths 4 and 5 are never marked" sentence becomes the item 12 marks (including the pull-request-only mark); the Measures row gains the per-path counts and the same-paths comparison; a change-log row (2026-11-24, 1254 lines).
- 52e05356 .agent/knowledge/script_reference.md: `named_path` on the `sitrep_root.sh` row; on the `sitrep_checks.sh` row the `path` row, the nearest-paragraph rule, per-path next steps (else `(root)`) and the ` paths ...` summary suffix.

### Suites (each run on its own from the worktree)
- After the merge: test_sitrep_checks.sh "test_sitrep_checks: 281 passed, 0 failed"; test_sitrep_root.sh "test_sitrep_root: 69 passed, 0 failed"; test_skill_paths.sh "test_skill_paths: 199 passed, 0 failed".
- test_skill_paths.sh again after the script_reference.md edit: "test_skill_paths: 199 passed, 0 failed" (before the merge, after item 1: "197 passed, 0 failed").
- No changed script this pass; no suite names `script_reference.md`. The full pass is left to the host.

### Live run
`sitrep_checks.sh --root . --roadmap docs/roadmap.md` on the merged main text (this branch at 52e05356, exit 0, 81 rows):
- summary: `lines 2/15 deferrals 3/10 paths P1 1/4 P2 0/4 P3 0/3 P4 0/3 P5 none across 1/1`
- path rows: Path 1, ROS 2 projects / Path 2, modular workflows / Path 3, less waiting for the same care / Path 4, kinds of projects and knowledge (each `true lines`); Path 5, top-level work organisation (`unchecked`, `no lines (no design yet)`); Across the paths (`true group`).
- next steps: Path 1 "The workspace installs on the second machine from a clean clone, user tier included (#430)" false; Path 2 "A project chooses where its records live, and a session finds them through one lookup (#393)" false; Path 3 "A merge does not wait on CI that the change cannot affect (#550)" false; Path 4 "A project says where it keeps its goals, design and roadmap (#551)" false; Path 5 no lines (no design yet); Across the paths none open (its new check is true); the two parts' next steps unchanged (`tools/repos-manifest/docs/roadmap.md`, `docs/manifest/roadmap.md`, both unchecked).

### Deviations
- Item 1 rewritten rather than dropped, and review-issue's SKILL.md edited (one parenthesis removed): the plan did not name that file, but its sentence was made untrue by this change.
- The plan's cost note (N6) is for the host to carry into the pull request; not written here.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 08:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-563 at `14471097`
**Base**: main
**Depth**: Deep (reason: 1346 changed lines in 12 files, skill and knowledge files among them)
**Must-fix**: 1 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

Specialists: static analysis (shellcheck not installed, not run; the touched suites pass: test_sitrep_checks 281/0, test_sitrep_root 69/0, test_skill_paths 199/0, test_design_anchors 82/0), governance, plan drift, Claude adversarial (no must-fix), Gemini (ran, 8 findings, 3 kept), Codex (ran, 2 findings, both kept). Dropped as false positives: Gemini's jq dependency (step 3 already uses jq) and its step 3 field-list worry (`isCrossRepository` is in the list); the GMARKS reset (safe, group_rows runs before any sub-roadmap scan).

### Findings
- [x] (must-fix) The closing question's paths (step 3's last block) and the `haspaths` fallback parse the roadmap's prose with a grammar other than the checker's: a fenced `**Path` is offered, a bold span wrapped over two lines gives `paths=none`, a trailing comma stays in the name, a continuation line starting `**Path` restarts the paragraph; plan item 12 took the names from the `path` rows. Take the names from the rows when present and use the checker's grammar for the fallback (Codex, Gemini) — `.claude/skills/sitrep/SKILL.md:584-609, 336-342`
- [x] (suggestion) In flight shows at most five branches, yet every branch matched to any group's first unmet line must be among the five, and six groups (or a line naming two issues) can match more; the template says "no branch advances" where the rule says "no branch or pull request". Give an overflow rule and one wording (Codex, Gemini) — `.claude/skills/sitrep/SKILL.md:1125, 1238-1245`
- [x] (suggestion) Step 8 says the acceptance case is the test of the path whose paragraph sits above it, but no block prints that path; step 5's acceptance block could print it (Gemini) — `.claude/skills/sitrep/SKILL.md:1183-1188`
- [x] (suggestion) A pull request with no worktree gets its path from a line row whose item has `(#<N>`, which misses the second issue of a list such as `(#208, #209)` (in the roadmap today) and does not say that the `no path` group reads `no path (a line names it)` (Gemini) — `.claude/skills/sitrep/SKILL.md:1274-1284`
- [x] (suggestion) Each group's "<t> of <n> done" is said to come from step 1's `--- next steps`, whose lines carry no counts; name the summary's ` paths` suffix or the rows as the source — `.claude/skills/sitrep/SKILL.md:1203-1207`
- [x] (suggestion) Path grammar edges: two paragraphs with the same path number get the same summary label (`P1 none P1 none`), so the per-path comparison of two records mis-pairs them; `**Across the paths<anything>**` keeps the suffix as the group's name; a `**Path` span that never closes drops the path with no row saying so (Claude adversarial, Gemini) — `.agent/scripts/sitrep_checks.sh:330-337, 973-983`

## Implementation
**Status**: complete
**When**: 2026-11-24 08:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-563 at `5bf94c05`
**Addressed**: Local Review (Pre-Push) at `14471097` (2026-11-24 08:34 -05:00)
**Commits**: 8eaa6175, ce1daa2b, 5bf94c05

### Actions
- [x] (must-fix) Closing question's paths read with the checker's rules: step 3's last block takes the names from step 1's `path` rows, or with no rows from the new `sitrep_checks.sh --list-paths` (same scanner, no check run, no pointer followed); only each paragraph's first sentence is read from the prose, keyed by those names (fence-aware, a paragraph opens only after a blank, table or heading line). The `haspaths` fallback asks `--list-paths` too. A failed `--list-paths` prints `paths=unknown`, which step 8 treats like `paths=none` and says under Problems (host N2 kept: the question still works with no rows) — `.claude/skills/sitrep/SKILL.md` step 3, `.agent/scripts/sitrep_checks.sh` (8eaa6175)
- [x] (suggestion) Five-branch limit: overflow rule (more than five matched: the first five in step 3's order, the rest under "And <k> more:"), template wording now "matched no branch or pull request for" — `.claude/skills/sitrep/SKILL.md` step 8 (5bf94c05)
- [x] (suggestion) Acceptance case's path: printed as `acceptance_path=` by step 3's last block (not step 5's, as the review proposed), because that block already holds the checker's names, so the path named is one the report shows; step 8's first line uses it, and with none it is `acceptance_first` alone — `.claude/skills/sitrep/SKILL.md` steps 3 and 8 (8eaa6175)
- [x] (suggestion) Pull request with no worktree: its issue is found in any number of a bracketed list such as `(#208, #209)`, as step 5 reads an item, and it is marked as step 3 marks a group, `no path (a line names it)` included — `.claude/skills/sitrep/SKILL.md` step 8 (5bf94c05)
- [x] (suggestion) "<t> of <n> done" source: the summary's ` paths` part, one count per group in next-steps order — `.claude/skills/sitrep/SKILL.md` step 8 (5bf94c05)
- [x] (suggestion) Checker edges made visible, no recovery logic (owner direction 2026-11-20): a bold `Path`/`Across` span that never closes, words after `Across the paths` (the group keeps the name `Across the paths`, as the header already said), and a path number used twice each print an `unchecked` `format` row, reported under Problems; step 8 compares per path only when no label repeats — `.agent/scripts/sitrep_checks.sh` path_mark, bold_unclosed, group_rows (ce1daa2b)

### Host directions (for the owner's veto)
- Must-fix fixed per plan item 12 and the review; fallback by asking the checker (one reader); N2 kept.
- Four skill-text suggestions fixed with the smallest text edits.
- Checker edge cases made visible as `format` rows, not handled; mechanism text names no project.

### Decided beyond the directions
- New checker mode `--list-paths` (the fallback's "ask the checker"), documented in the script header and `.agent/knowledge/script_reference.md`.
- Step 3's path lines now print the name as the checker gives it (`Path 1, Alpha`) in one field, not number and name split; step 8's question text follows.
- `paths=unknown` added for a checker that cannot list the paths.

### Suites (each run on its own from the worktree, on the final state)
- test_sitrep_checks.sh: "test_sitrep_checks: 286 passed, 0 failed" (also run at each intermediate commit: 285/0 after 8eaa6175, 286/0 after ce1daa2b)
- test_sitrep_root.sh: "test_sitrep_root: 69 passed, 0 failed"
- test_design_anchors.sh: "test_design_anchors: 82 passed, 0 failed"
- test_update_roadmap.sh: "test_update_roadmap:16 passed, 0 failed"
- test_skill_paths.sh: "test_skill_paths: 199 passed, 0 failed"
- The full pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 08:56 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent aca953caa507aacb5, resume 1 of 3)
**Verdict**: changes-requested

**Branch**: feature/issue-563 at `a1e42449`
**Base**: main
**Depth**: Deep (reason: whole branch diff 1571 changed lines in 12 files, skill and knowledge files among them; fix round classified on the whole diff)
**Must-fix**: 2 | **Suggestions**: 4
**Round**: 2 | **Ship**: continue — round 2: must-fix rising (1 -> 2)

Round 1's findings are all closed: the closing question's names now come from the `path` rows or `--list-paths`; the five-branch overflow rule, `acceptance_path=`, bracketed issue lists, the count source and the checker edge cases (format rows) are all in. Both new must-fix items are in code the fix round added or touched, and both are mechanical. On the real roadmap: no `format` row, `--list-paths` prints the six groups, step 3's last block gives each path's first sentence and `acceptance_path=Path 1, ROS 2 projects`.

Specialists: static analysis (shellcheck not installed, not run; test_sitrep_checks 286/0 run by the fresh Claude adversarial reviewer), governance, plan drift (the fix round's `--list-paths` mode follows plan item 12's intent), Claude adversarial (fresh; no must-fix, 2 suggestions), Gemini (ran, 6 findings: 1 dropped as a false positive, jq is already used in step 3; the rest kept, two downgraded), Codex (ran, 1 finding, kept; its claim that the checker reads a path after `---` is wrong, but its case holds for `***` and `___`, and `---` exposes a checker defect).

### Findings
- [x] (must-fix) A `---` thematic break directly above a path paragraph (blank line before the break, none after) opens no group: the open test uses THEMATIC_RE, which has only `*` and `_`, so `**Path 2` is not read and its lines are counted under Path 1, with no row saying so (header says a thematic break allows an opening). Reproduced: `--no-follow` prints only `Path 1` with both lines under it — `.agent/scripts/sitrep_checks.sh:980-985`
- [x] (must-fix) Step 3's last block splits paragraphs by rules other than the checker's: a thematic break (`***`, `___`) or a fence directly above a path paragraph is not a boundary, so the checker reads the path but the block gives it an empty first sentence and a wrong `acceptance_path=` (reproduced: `acceptance_path=Path 1, One` for an Acceptance case under Path 2); fences also toggle without char or length, and `/^## Direction/` matches `## Directions` (Codex, Gemini, Claude adversarial) — `.claude/skills/sitrep/SKILL.md:604-614`
- [x] (suggestion) The `haspaths` fallback drops a failed `--list-paths` (`2>/dev/null`, empty output) as "no paths", so worktrees get no path word instead of `path unknown (steps not checked)`, while the last block of the same step says `paths=unknown` (Gemini) — `.claude/skills/sitrep/SKILL.md:338-343, 456-464`
- [x] (suggestion) "No work on this machine for: <group>" is decided by step 5's match on the group's first unmet line only, and a pull request with no worktree here also suppresses it; a worktree advancing another line of the group sits in In flight marked with that group just above. Word the bullet as what it checks (Gemini) — `.claude/skills/sitrep/SKILL.md:1159, 1286-1288`
- [x] (suggestion) Across edges: in a section with no path paragraph, bold `Across the paths, …` (or an unclosed one) still emits a `format` row, against "rows exactly as before"; a second Across paragraph gives two `across` labels with no `format` row, which step 8's "no label repeats" rule relies on (Gemini) — `.agent/scripts/sitrep_checks.sh:1005-1025, 1061-1068`
- [x] (suggestion) `acceptance_path=` is "the nearest path or Across paragraph above it" in step 3 but "the nearest path paragraph above it" in step 8; say what step 8 prints when it is `Across the paths` (Claude adversarial) — `.claude/skills/sitrep/SKILL.md:590, 1220-1226`

## Implementation
**Status**: complete
**When**: 2026-11-24 09:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a4c066f54a5215d26, resume 1 of 3)

**Branch**: feature/issue-563 at `75e958ee`
**Addressed**: Local Review (Pre-Push) at `a1e42449` (2026-11-24 08:56 -05:00)
**Commits**: e1a6502f, 5ab759b6, d6b4f9af, 75e958ee

### Actions
- [x] (must-fix) A `---` rule above a path paragraph: `THEMATIC_RE` now takes `---`, `***` and `___` (one character each), so the path after it opens and its lines are its own; a test for each of the three — `.agent/scripts/sitrep_checks.sh` (e1a6502f)
- [x] (must-fix) Second reader removed: `--list-paths` now prints `group<TAB><name><TAB><first sentence>` per group and `acceptance<TAB><group>` for the first Acceptance case paragraph, read by the scanner's own paragraph, fence and section rules (path_mark gathers the opening paragraph's text; first_sentence cuts it). Step 3's last block only formats that output (an awk over `--list-paths`, no read of the roadmap), so rules, fences and `## Directions` read as the checker reads them; test covers `***`/fence above paths, `## Directions`, the acceptance case under Across — `.agent/scripts/sitrep_checks.sh`, `.claude/skills/sitrep/SKILL.md` step 3 (5ab759b6)
- [x] (suggestion) A failed `--list-paths` in the worktree block sets `haspaths=unknown` and prints "paths: could not be listed (reason above)"; work is then `path unknown (steps not checked)`, agreeing with `paths=unknown`; tested with a failing checker stub — `.claude/skills/sitrep/SKILL.md` step 3 (5ab759b6)
- [x] (suggestion) Bullet reworded to "No branch or pull request for the next step of:", and the rule says it covers only each group's first unmet line (other lines' work can be in flight above) — `.claude/skills/sitrep/SKILL.md` step 8 (75e958ee)
- [x] (suggestion) Across edges: in a section with no path paragraph, an odd or unclosed Across bold adds no row (shown only beside a path, as earlier instruction N5 requires); a second Across paragraph is a `format` row like a repeated path number; no recovery logic — `.agent/scripts/sitrep_checks.sh` group_rows, bold_unclosed (d6b4f9af)
- [x] (suggestion) `acceptance_path=` described the same way in steps 3 and 8 (nearest path or Across paragraph above it); step 8 gives the Across example ("The test of Across the paths: ...") and says the line is `acceptance_first` alone with no `acceptance_path=` line or with `paths=none`/`paths=unknown` — `.claude/skills/sitrep/SKILL.md` step 8 (5ab759b6)

### Host directions (for the owner's veto)
- Must-fix 1 fixed in the checker with a test per rule form; must-fix 2 fixed by removing the skill's reader, not patching it; the haspaths, wording, acceptance-text and Across suggestions fixed as directed; no project named.

### Decided beyond the directions
- Step 3's last block always asks `--list-paths`, even when step 1 saved rows (the rows carry no sentences, and one source avoids joining two); the rows file placeholder is gone from that block. Both come from the same scanner on the same roadmap.
- An unclosed bold `**Path` still gives a `format` row in a section with no other path (it is a path paragraph, so the no-path promise does not cover it); only the Across rows are held back there.
- `THEMATIC_RE` no longer matches a mixed rule such as `*_*` (not a thematic break in CommonMark).
- The gh-failing sandbox in test_sitrep_checks.sh (`ws5`) now gets a copy of `sitrep_checks.sh`: the worktree block's fallback calls it, and the old `2>/dev/null` had hidden that it was missing.
- Commits split through the index from scratch snapshots, each snapshot's checker suite run in a scratch copy of the tree: e1a6502f 289/0, 5ab759b6 294/0, d6b4f9af 295/0.

### Suites (each run on its own from the worktree, on the final content)
- test_sitrep_checks.sh: "test_sitrep_checks: 295 passed, 0 failed"
- test_sitrep_root.sh: "test_sitrep_root: 69 passed, 0 failed"
- test_design_anchors.sh: "test_design_anchors: 82 passed, 0 failed"
- test_update_roadmap.sh: "test_update_roadmap:16 passed, 0 failed"
- test_skill_paths.sh: "test_skill_paths: 199 passed, 0 failed"
- The full pass is left to the host.
