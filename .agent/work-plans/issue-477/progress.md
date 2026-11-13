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
