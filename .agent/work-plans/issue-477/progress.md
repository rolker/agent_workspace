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
