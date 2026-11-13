---
issue: 477
---

# Issue #477 — Path 3, less waiting for the same care

## Issue Review
**Status**: complete
**When**: 2026-11-13 14:10 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #477

### Scope Assessment

**Well-scoped?** Yes, as a home issue, with a fixed first pull request (two texts) and a list of later items that each become their own pull request.
**Right repo?** Yes: `docs/roadmap.md`, `README.md`, and skills are workspace files.
**Serves**: the README's "Quality of the work" goals (economical, never at the cost of quality) and the new line this issue adds under them; `docs/design.md#review-loop-and-timeline`
**Design picture?** No change for the first pull request. Later items (a change-log rule, a merge-gate rule, review-round limits) do change `docs/design.md` sections.
**Dependencies**: #465 (when the suites run) and #444 (test run time) are driven separately; #472 holds limits and safeguards. None block the first pull request.

**How the sit-rep decides a path today** (read, not assumed): `.claude/skills/sitrep/SKILL.md` step 3 prints Path 1 when a Direction line names the work, Path 2 when the newest complete Issue Review's `**Serves**:` names a goal (any goal, no README line is singled out), "no path" for `none`. Work serving the new README line would therefore read as Path 2 until a mechanism is added. `.agent/scripts/tests/test_skill_paths.sh` (line 815) requires only a Path 1 and a Path 2 paragraph in `## Direction`, with no table row between them; a Path 3 paragraph placed after Path 2 passes it unchanged. `sitrep_checks.sh` lists the Paths paragraphs generically (its test at line 1230).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Economical, never at the cost of quality | OK | The path is the owner's own reading of the day's evidence; it keeps the plan review and first code review, which found the defects |
| A change includes its consequences | Watch | The roadmap's Paths intro says "Two paths run in parallel" and Path 2 is "any other work that serves a goal in the README"; both need the matching edit in the first pull request |
| Improve incrementally | OK | Marking Path 3 in the sit-rep is a separate, later change |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (progress timeline) | Yes | This entry |
| Instruction-file rule | No | First pull request touches no instruction file; later items (c) and (d) may |

### Consequences

- First pull request: `docs/roadmap.md` Paths paragraph ("Two paths" becomes three; Path 2's "any other work" gets "that no other path names", so the three do not overlap) and the Path 3 paragraph after Path 2; `README.md` one line. `docs/design.md` is not touched. The roadmap text the sit-rep reads is the only mechanism needed.
- The sit-rep answer for the first pull request: no mechanism change. Path 3 is named in the roadmap and the sit-rep reads the paragraph. Work serving the new line reads "Path 2" in the per-issue mark until the later marking item; say so in the pull request description so the mark is not read as an error.

### Recommendations

- First pull request, exactly: write the two approved texts verbatim into `docs/roadmap.md` (Path 3 paragraph after Path 2, "Two paths" changed to three, one clause added to Path 2 so the paths do not overlap) and `README.md` (one line under "Quality of the work"). No other file. No sit-rep, test or design change.
- Later items, ranked by time saved against risk. Decides: O = owner (changes a decision right, the design document's rules, or an instruction file), H = host (mechanism).
  1. (b) Push records once, with the merge, not per record-only commit: saves two 11 to 13 min CI runs per record push, the largest recurring wait; edit `run-issue` SKILL.md. Low risk. H.
  2. (a) Design change log: drop the line-count column so git unions the rows; edit the table in `docs/design.md` and its rule. Removed three conflicts, each a merge commit, a re-review and a CI run, on one day. Low risk, but it edits a design-document rule. O (one yes/no, smallest option first).
  3. (d) A CI failure at the merge checkpoint with a single answer is fixed and re-run, not asked: edit `run-issue` SKILL.md merge-checkpoint step. Saves a round trip to the owner. Low risk. H, though if it changes what reaches him at a checkpoint, record it as a standing rule on this issue.
  4. (e) `review_progress.sh findings` and `check` select a pull-request-mode Local Review: script plus a test in `.agent/scripts/tests`. Removes hand work after review. Low risk. H.
  5. (f) After a merge from main following the last review, `next` prints the dispatch it needs (merge, review, CI) so nothing is dispatched outside it: `run-issue` SKILL.md and `review_progress.sh`. Moderate risk. H.
  6. Sit-rep marks Path 3 (a Serves line naming the new README line): `.claude/skills/sitrep/SKILL.md` step 3 plus `test_sitrep_checks.sh`. Saves no wait; orientation only. Low value, do last. H.
  7. (c) Limit on fix-and-re-review cycles after publishing: stop after two rounds unless data loss or security is at stake, then the owner. Saves the long tail (rounds 3 to 6 found only shrinking points). Changes a decision right and the loop's rules. O; it is his own 2026-11-12 proposal, so one yes/no with his words quoted.
  - Already homed: test timing is #465 and #444; limits and safeguards that cover for something else are #472; the offline merge path stays undecided and unfiled by his choice.

## Checkpoint
**Status**: complete
**When**: 2026-11-13 14:42 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review keeps the issue's goal and the first pull request the owner fixed: his two approved texts into docs/roadmap.md and README.md, two files, no mechanism change; its ranked list of later pull requests is advice for after this one, and marks which are the owner's to decide)
**After**: issue-actions
**Decision**: proceed

Read: the Issue Review at ab84c2ad and its report. The owner's words that started the drive (2026-11-13): "start working on path 3. act as orchestrator and open an issue if it hasn't happened, then oversee it. Keep in mind the lessons about what waists time and modify the skills as needed to be efficient".

### Decisions made (owner may veto)
- The first pull request is the two approved texts only, plus "Two paths" becoming three and one clause in Path 2's "any other work" so the paths do not overlap; work serving the new README line reads "Path 2" in the sit-rep's per-issue mark until a later pull request teaches it Path 3 — undoing it: add the sit-rep change to this pull request.
- Later pull requests in the review's order, the host's first: records pushed once with the merge; a CI failure at the merge checkpoint fixed and re-run, not asked; review_progress.sh reading a pull-request-mode review. The owner's, each asked by name at its own merge: dropping the change log's line-count column in docs/design.md; a stop after two fix rounds after publishing.

## Plan Authored
**Status**: complete
**When**: 2026-11-13 14:43 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-477/plan.md` at `160b7adf`

Part 1 is two text edits (roadmap: "Three paths", one clause in Path 2, the approved Path 3 paragraph; README: one bullet after the first Quality bullet), verified safe against test_skill_paths.sh and the sit-rep; part 2 outlines the review's seven later PRs with who decides. Open: design.md line 105 says "the two paths".

## Plan Review
**Status**: complete
**When**: 2026-11-13 14:45 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #477 — Path 3, less waiting for the same care: the roadmap path, the README goal line, and what sits under it
**Plan**: `.agent/work-plans/issue-477/plan.md` at `160b7adf`
**Branch**: `feature/issue-477`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Part 1 is two files, text only, with a stop condition. Part 2 is an outline matching the Issue Review's ranked list. |
| Issue alignment | Good | Both approved texts are carried character for character (checked against the issue body's "The texts he approved"). Serves: README "Quality of the work" (economical, never at the cost of quality) and the new line; `docs/design.md#review-loop-and-timeline` (anchor exists, line 622). |
| File targeting | Good | `docs/roadmap.md` and `README.md` only. Read the whole `## Direction` section: the intro, the Format paragraph, both tables and the deferral wording count no paths; "When he asks for a sit-rep, he decides which to focus on" reads correctly with three. |
| Consequences | Good | `docs/design.md` line 105 ("names the two paths") is left out on purpose (host decision, below). The sit-rep gaps are disclosed, and two more are named in notes 1 and 2. |
| Principle alignment | Good | Docs-only change; the plan names the two suites to run and their baseline counts. Path 2's clause is the smallest wording that resolves the overlap. Path 2's quoted words are untouched. |
| ADR compliance | Good | ADR-0013 entries in place. Neither file is an instruction file. |
| ROS conventions | N/A | Workspace plan |

### Scratch run of the sit-rep's step 3 paths block

On a scratch copy of the roadmap with the three edits applied, the block printed:

```
path	Path 1	project11 on a second machine	In the owner's words (2026-11-10): "I also want to move project11 to this workspace".
path	Path 2	the workspace reflects the goals	Implementing the missing pieces to make this workspace reflect the goals we set.
path	Path 3	less waiting for the same care	<the whole paragraph>
```

Path 3 is listed. Its "first sentence" is the whole paragraph, because the first-sentence pattern needs a period followed by a space and both quotes end `."`. The output is long but not wrong.

### Findings

No must-fix. Notes for the implementer, applied without a re-plan:

1. **[Consequences]** The sit-rep's closing-question rule (`.claude/skills/sitrep/SKILL.md`, report rules: "By default it is the focus: Path 1, Path 2 or both") is hard-wired to two paths. With a third paragraph, the question may still offer "Path 1, Path 2 or both". The paths block lists all three, so the owner can still answer "Path 3". Also, `no path` is glossed "serves neither path". Add both to the PR description's sit-rep sentence, and to part 2 item 6's scope (`test_sitrep_checks.sh` line 1260 greps that rule's text, so the fix goes with its test).
2. **[Consequences]** Once Path 2 says "other than Path 3 work", the sit-rep's "Path 2" mark on Path 3 work goes against the roadmap's definition. That makes it wrong, not merely incomplete. The PR description should say "wrong until item 6", not just that the mark "reads Path 2". Every Path 3 pull request merged before item 6 will show as Path 2. The host may want to move item 6 earlier in part 2. That is a host ordering call, not a blocker.
3. **[Principle alignment]** `.agent/knowledge/host_standing_rules.md` line 41 says Paths text is "listed for his veto with the quote". The ", other than Path 3 work" clause is a host edit that the owner did not approve by name, so the PR description lists it for his veto.
4. **[File targeting]** `test_skill_paths.sh` lines 7 and 815 have comments that say "two Paths paragraphs". The test still passes (it checks only Path 1 and Path 2 with no table row between them). Leave the comments for item 6. The stop condition holds.
5. **[Scope]** The approved Path 3 text goes in verbatim. Wrap it at the file's width only, as the plan says. Do not change the `."` endings to fix the sit-rep's first-sentence output.

### Host decision recorded: `docs/design.md` line 105

Accepted, with the host's reason. The design document's change-log rows collided with main three times on 2026-11-13, and another machine's session is editing that file for issue 436. The fix belongs in the later pull request that changes the design document anyway (part 2 item 2 or 6). I see no concrete harm in the gap. Nothing reads that sentence mechanically: `sitrep_checks.sh` reads only the roadmap's tables, and the sit-rep reads the roadmap's paragraphs. The cost is a design reader seeing "two" for a while.

### Summary

The plan is ready. Both approved texts are exact, the three roadmap edits sit in the right places, and the only checked tests that read the Paths text (`test_skill_paths.sh` line 815 and the generic Paths-listing test) still pass. The sit-rep gaps are disclosure items for the PR description and item 6. None is a blocker.

### Recommended Actions

- [ ] In the PR description, say the sit-rep's Path 2 mark on Path 3 work is wrong until part 2 item 6, and that its closing question is worded for two paths.
- [ ] List the ", other than Path 3 work" clause for the owner's veto.
- [ ] Run `test_skill_paths.sh` and `test_sitrep_checks.sh` separately and expect the baseline counts (146 and 210 passed).

## Checkpoint
**Status**: complete
**When**: 2026-11-13 14:46 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is ready, but its notes 1 and 2 show the two-file plan leaves the sit-rep wrong, not just incomplete: once Path 2 says "other than Path 3 work", the per-issue mark "Path 2" on Path 3 work contradicts the roadmap, and the closing question still offers "Path 1, Path 2 or both"; the owner reads the sit-rep every day, and a second pull request for it could only start after he merges this one; so the sit-rep's Path 3 marking, part 2's item 6, moves into this pull request; first host revise at this checkpoint)
**After**: plan
**Decision**: revise

Read: the Plan Review at 12bf95f0 and its report. Direction for the revised plan: part 1 becomes the two approved texts plus the sit-rep's part: step 3 marks work Path 3 when the newest complete Issue Review's Serves line names the new README line (say exactly how it is recognised), the closing question and the "no path" wording stop assuming two paths, the first-sentence extraction copes with a sentence that ends in a quotation mark, and the tests and comments that say "two" follow (test_sitrep_checks.sh, test_skill_paths.sh). docs/design.md stays out, as the review accepted. The owner's instruction for the drive: "modify the skills as needed to be efficient".

### Decisions made (owner may veto)
- The first pull request grows from two files to the texts plus the sit-rep skill and its tests, so the sit-rep is right the day Path 3 exists — undoing it: split the sit-rep part back out into its own pull request.

## Plan Authored
**Status**: complete
**When**: 2026-11-13 14:47 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Dispatch**: resumed (agent ac19fcfa95aa96a31, resume 1 of 3)
**Plan**: `.agent/work-plans/issue-477/plan.md` at `ece64fd5`

Revised at the host's checkpoint: part 1 now also carries the sit-rep marking Path 3 (recognised by the README line's opening words, "A safeguard has to earn its cost", in the newest complete Issue Review's Serves line; review-issue's Serves rule says to write it), the closing question and "serves neither" wording for three paths, the first-sentence pattern accepting a closing quotation mark, and the two test files. Part 2 loses its item 6.

## Plan Review
**Status**: complete
**When**: 2026-11-13 14:49 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent ac07052333263a795, resume 1 of 3)
**Verdict**: ready

**Issue**: #477 — Path 3, less waiting for the same care: the roadmap path, the README goal line, and what sits under it
**Plan**: `.agent/work-plans/issue-477/plan.md` at `ece64fd5`
**Branch**: `feature/issue-477`

Second review. It covers only what the revision added: plan items 5 to 11, the stop condition, and "Entries already written". The two approved texts and their edits were checked in the first review and are not re-reviewed here.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One pull request: the texts plus the sit-rep part and its two test files. The stop condition names the files that stay untouched. |
| Issue alignment | Good | The issue asks what makes work Path 3 and for the smallest sit-rep change. Items 5 and 6 answer both. Serves line unchanged: README "Quality of the work" and the new line; `docs/design.md#review-loop-and-timeline`. |
| File targeting | Good | Reading `sitrep_checks.sh` and `sitrep_root.sh` confirms they do not need to change: step 3's own awk block is the only reader of the Serves text. |
| Consequences | Good | The first review's notes 1 and 2 are now covered: the closing question, "serves neither", and the path-word lists. `docs/design.md` line 105 stays accepted. |
| Principle alignment | Good | Each changed behaviour has a test that fails without it: case 32, the closing-question grep, and the `."` paths case. Cases 33 and 34 and the project row pass today; they guard the order of the checks, which is their job. |
| ADR compliance | Good | ADR-0013 entries. The two skill files are not instruction files. |
| ROS conventions | N/A | Workspace plan |

### Recognition by the README line's opening words

The rule is to match the phrase "A safeguard has to earn its cost", case-insensitive, in the newest complete Issue Review's Serves line. It is sound. Each risk I checked:
- **A Serves line of `none` that quotes the phrase.** The existing `none` test runs first, and the plan keeps that order, so the line reads `no path`.
- **A Serves line that quotes the phrase while saying the work does not serve it.** It would misfire as Path 3. Real Serves lines do carry commentary. Issue 253's says "Direction (`docs/roadmap.md`, Path 1) does not name #253", and issue 386's argues about anchors. But a review naming this line in order to deny it is unlikely, and the cost is one wrong path word. This is a note, not a must-fix.
- **review-issue paraphrasing the line.** The match silently never fires, and the work reads Path 2, which is what it read before this change. Serves lines already quote README wording verbatim in quotation marks ("Work is easy to come back to"). With item 5's sentence, paraphrase is the less likely outcome.
- **The phrase wrapped across two lines.** The `serves=` awk keeps only the `**Serves**:` line itself. A wrapped value is cut today, which is harmless for `goal` and `none` but would hide the phrase. review-issue's rule already says "in one line", and all 23 Serves lines I read across 19 progress files are single lines. Low risk.
- **The README side changes but review-issue does not.** The planned README assertion catches a change on the README side only. Nothing catches review-issue's sentence or the sit-rep's literal drifting from it. See note 1.
- **A fixed token such as `Path 3` instead.** This would be less robust. Serves lines already mention path numbers in commentary (issue 253's "Path 1 ... does not name"), so a number token would misfire on exactly that kind of text. It would also tie review-issue, which runs in project sessions too, to the workspace roadmap's numbering. The phrase ties the match to the goal, which is where the Serves rule already points.

### Precedence chain walk (`wpath`, step 3)

| Case | Result |
|---|---|
| No Paths paragraph | empty |
| `named` empty | path unknown (steps not checked) |
| `named` is `yes`, with or without the phrase | Path 1 (case 34) |
| `goal` or `path3`, and the worktree or the session is a project | no path (serves a project goal) |
| `path3` in a workspace worktree, workspace session | Path 3 (case 32) |
| `goal` | Path 2 (case 33: an older review has the phrase, the newest is plain) |
| `none` (the phrase may follow) | no path |
| `unstated` or `unreviewed` | their unknown labels |

Every branch is reachable, and none shadows another wrongly. In a project session the project test comes first, so a project roadmap's own Path 3, if it has one, is never claimed by the workspace's phrase.

### First-sentence pattern, scratch run (since deleted)

Run with `(.+?\.\x22?)(?:\s|$)` on the roadmap with the approved edits, plus three probe paragraphs:

```
Path 1  In the owner's words (2026-11-10): "I also want to move project11 to this workspace".      (unchanged)
Path 2  Implementing the missing pieces to make this workspace reflect the goals we set.            (unchanged)
Path 3  In the owner's words (2026-11-13): "We have a lot of safeguards to make sure we don't produce slop, but I fear we may be over cautious."
probe "See e.g. the list."          -> "See e.g."                    (same as the old pattern; an existing limit, not new)
probe 'He said "stop." and left.'   -> 'He said "stop."'             (new: the old pattern gave 'He said "stop." and left.')
probe "It is 'done.' Then."         -> "It is 'done.' Then."         (single quote not handled; same as old)
```

Path 1 and Path 2 print the same as before. The only output that changes is a quoted full stop in the middle of a sentence, which now ends the extract. For Path 3 that is the intended result.

### Findings

No must-fix. Notes for the implementer, applied without a re-plan:

1. **[Principle alignment]** Pin the phrase in all three places, not only the README: `README.md`, `.claude/skills/review-issue/SKILL.md` (item 5's sentence), and `.claude/skills/sitrep/SKILL.md` (the awk literal). Use one `grep -qiF` per file in `test_skill_paths.sh`, which already reads the real skill texts. Then rewording any one of them fails a test, and a silent never-fire cannot happen.
2. **[Approach]** In the awk, match with `index(tolower(s), "a safeguard has to earn its cost")` rather than `~`, so the phrase is matched as plain text.
3. **[Tests]** Add one case: a Serves line of `none` that also carries the phrase, expected `no path`. It pins the `none`-first order, the one order the chain walk depends on that no planned case covers.
4. **[Verification]** The implement pass runs only `test_sitrep_checks.sh` and `test_skill_paths.sh`, each on its own, and reports their new totals. Drop the plan's step that runs `suites_for_files.sh`, which printed `ALL`. Under the owner's interim rule, the host makes the one full local run before publishing. No other suite reads the real `README.md`, review-issue's skill or the sit-rep skill. The other suites that name `roadmap.md` or `README.md` (`test_sitrep_root.sh`, `test_update_roadmap.sh`, `test_real_case_path.sh`) build sandbox copies, so they are unaffected.
5. **[Generic]** `test_skill_paths.sh` requiring `**Path 3,` is acceptable: that check reads only the workspace's own `docs/roadmap.md`, never a project's, and the sit-rep skill hard-codes Path 3 the same way it already hard-codes Path 2. Keep the skill prose and `test_sitrep_checks.sh`'s sandboxes generic about how many paths a root has. The closing question's wording, "one of the paths step 3 printed, or several", already is.
6. **[Consequences]** "Entries already written": it is acceptable for issues 465 and 477 to read Path 2 until they are re-reviewed. The timeline is append-only, the mark was Path 2 before this change, and the PR description says so (item 11b). No other matching is worth adding for two lines.

### Summary

The revision is ready. The phrase is a sound marker, sounder than a path-number token. The precedence chain is correct for every case. The pattern change leaves Path 1 and Path 2 untouched. The planned tests fail without the change where they should. The notes tighten the tests and narrow the implement pass's suite runs to the two touched suites.

### Recommended Actions

- [ ] Assert the phrase in `README.md`, review-issue's skill and the sit-rep skill (note 1).
- [ ] Match the phrase with `index()` in the awk (note 2).
- [ ] Add the `none` plus phrase case (note 3).
- [ ] Run only the two touched suites in the implement pass; the host makes the full run (note 4).
