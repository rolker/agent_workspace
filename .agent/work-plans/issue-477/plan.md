# Plan: Path 3, less waiting for the same care: the roadmap path, the README goal line, and what sits under it

## Issue

https://github.com/rolker/agent_workspace/issues/477

## Context

The owner approved a third roadmap path and one README goal line (2026-11-13, "yes on path 3"). This issue is the home for later items too. Part 1 is the first pull request: two files, text only. Part 2 outlines the later pull requests.

## Approach

### Part 1: the first pull request (detailed)

1. **`docs/roadmap.md`, `## Direction`, line 28** — old: `**Paths.** Two paths run in parallel.` new: `**Paths.** Three paths run in parallel.` The owner's quote after it ("We can do stuff in parallel") is untouched.
2. **`docs/roadmap.md`, Path 2 paragraph, line 40** — old: `any other work that serves a goal in the README.` new: `any other work that serves a goal in the README, other than Path 3 work.` Chosen over the review's "that no other path names" because it is the shortest wording that names the one overlap (Path 1 is already excluded by "other"). Path 2's other text is not touched.
3. **`docs/roadmap.md`, new paragraph after Path 2's paragraph** (after the line ending "(#398)." and a blank line, before `**Format.**`), exactly the approved text:
   `**Path 3, less waiting for the same care.** In the owner's words (2026-11-13): "We have a lot of safeguards to make sure we don't produce slop, but I fear we may be over cautious." and "We need to re-think the workflow to not depend on github and to be efficient with how we run tests and ci." Path 3 work removes a wait or a review round that does not find problems, and keeps the steps that do.`
   (wrapped at the file's width). Its last sentence is the defining sentence; none is added.
4. **`README.md`, under `### Quality of the work`** — add after the first bullet ("Agents take the time and resources a quality result needs, within practical limits: economical, but never at the cost of quality."), because it qualifies that line: `- A safeguard has to earn its cost: one that finds no problems, or makes the user wait for nothing, is lightened or removed.` No heading changes, so no anchor moves (the only README anchor cited anywhere is `README.md#workspace-goals`, 3 uses).
5. **PR description** says: the sit-rep's per-issue mark reads "Path 2" for work serving the new README line until a later pull request teaches it Path 3 (the sit-rep reads a Serves line naming any goal as Path 2).

### Verified by reading (safe)

- `test_skill_paths.sh` line 815: requires a `**Path 1,` and a `**Path 2,` paragraph in `## Direction` with no table row between; Path 3 after Path 2 and its blank line passes unchanged.
- `.claude/skills/sitrep/SKILL.md` lines 529-550: step 3 prints every paragraph opening `**Path <n>`; Path 3 is listed with no change.
- `sitrep_checks.sh` reads the two Direction tables, not the Paths prose; the Paths-listing test is generic (line 1230).
- `grep -rn "Path 2\|Two paths"`: only the files above plus `docs/design.md` line 105 ("A Paths paragraph names the two paths the owner runs in parallel"). That sentence becomes stale (see Open Questions).

### Verification for the implement pass

Baseline on the unchanged tree: `bash .agent/scripts/tests/test_skill_paths.sh` 146 passed, 0 failed; `bash .agent/scripts/tests/test_sitrep_checks.sh` 210 passed, 0 failed. The implement pass runs both, each on its own, and expects the same counts.

### Stop condition (part 1)

Anything beyond `docs/roadmap.md` and `README.md` (the design document, the sit-rep skill, a test, any script) means stop and report.

### Part 2: later pull requests (outline only; each detailed when its turn comes, after the owner merges part 1; order from the Issue Review)

1. Push records once, with the merge, not per record-only commit (`run-issue` SKILL.md). Decides: host.
2. Design change log: drop the line-count column so git unions the rows (`docs/design.md` table and its rule). Decides: owner, one yes/no at its merge, smallest option first.
3. A CI failure at the merge checkpoint with a single answer is fixed and re-run, not asked (`run-issue` merge-checkpoint step). Decides: host; recorded as a standing rule on this issue if it changes what reaches the owner.
4. `review_progress.sh findings` and `check` select a pull-request-mode Local Review (script plus test). Decides: host.
5. After a merge from main following the last review, `next` prints the dispatch it needs (`run-issue` SKILL.md, `review_progress.sh`). Decides: host.
6. Sit-rep marks Path 3 (a Serves line naming the new README line): sitrep SKILL.md step 3 plus `test_sitrep_checks.sh`. Decides: host; last.
7. Stop after two fix rounds after publishing unless data loss or security is at stake (his 2026-11-12 proposal). Decides: owner, one yes/no with his words quoted, at its merge.

Already homed, not duplicated: #465, #444, #472; the offline merge path stays undecided and unfiled.

## Files to Change

| File | Change |
|------|--------|
| `docs/roadmap.md` | "Two" to "Three"; one clause in Path 2; Path 3 paragraph after Path 2 |
| `README.md` | one bullet under "Quality of the work" |

## Prior Art

Nothing new is being built; the Path 3 paragraph follows the shape of Paths 1 and 2 and uses the owner's approved text.

## Serves

README "Quality of the work" (economical, never at the cost of quality) and the new line; `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to how the parts fit. `docs/design.md` line 105 says "the two paths"; see Open Questions.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Paths intro and Path 2 edited with the new path; the design-document sentence is flagged |
| Verify before claiming | Suites run on the baseline; claims about the sit-rep read from its source |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | Yes | Plan Authored entry |
| Instruction-file rule | No | Neither file is an instruction file |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Paths paragraphs | `docs/design.md` line 105 "the two paths" | No: outside the two files; owner/host to decide |
| README goals | sit-rep per-issue mark | No: later PR (part 2, item 6); said in the PR description |

## Open Questions

- `docs/design.md` line 105 will say "the two paths" while the roadmap has three. Changing one word means touching the design document (and its change-log table, the table that conflicted three times). The issue and the stop condition say two files only. Host to decide: leave it for the sit-rep marking PR (item 6, which touches the same sentence's subject), or add it to part 1.

## Estimated Scope

Part 1: single small PR. Part 2: six or seven further small PRs.
