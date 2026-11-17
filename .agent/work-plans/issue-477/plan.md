# Plan: Path 3, less waiting for the same care: the roadmap path, the README goal line, and what sits under it

## Issue

https://github.com/rolker/agent_workspace/issues/477

## Context

The owner approved a third roadmap path and one README goal line (2026-11-13, "yes on path 3"). This issue is the home for later items too. Part 1 is the first pull request: the two approved texts plus the sit-rep marking Path 3 (revised at the host's checkpoint after the plan review). Part 2 outlines the later pull requests.

## Approach

### Part 1: the first pull request (detailed): two approved texts plus the sit-rep marking Path 3

1. **`docs/roadmap.md`, `## Direction`, line 28** — old: `**Paths.** Two paths run in parallel.` new: `**Paths.** Three paths run in parallel.` The owner's quote after it ("We can do stuff in parallel") is untouched.
2. **`docs/roadmap.md`, Path 2 paragraph, line 40** — old: `any other work that serves a goal in the README.` new: `any other work that serves a goal in the README, other than Path 3 work.` Chosen over the review's "that no other path names" because it is the shortest wording that names the one overlap (Path 1 is already excluded by "other"). Path 2's other text is not touched.
3. **`docs/roadmap.md`, new paragraph after Path 2's paragraph** (after the line ending "(#398)." and a blank line, before `**Format.**`), exactly the approved text:
   `**Path 3, less waiting for the same care.** In the owner's words (2026-11-13): "We have a lot of safeguards to make sure we don't produce slop, but I fear we may be over cautious." and "We need to re-think the workflow to not depend on github and to be efficient with how we run tests and ci." Path 3 work removes a wait or a review round that does not find problems, and keeps the steps that do.`
   (wrapped at the file's width). Its last sentence is the defining sentence; none is added.
4. **`README.md`, under `### Quality of the work`** — add after the first bullet ("Agents take the time and resources a quality result needs, within practical limits: economical, but never at the cost of quality."), because it qualifies that line: `- A safeguard has to earn its cost: one that finds no problems, or makes the user wait for nothing, is lightened or removed.` No heading changes, so no anchor moves (the only README anchor cited anywhere is `README.md#workspace-goals`, 3 uses).
5. **`.claude/skills/review-issue/SKILL.md`, the Serves rule (line 129)** — add one sentence: the README line "A safeguard has to earn its cost" has no heading of its own, so work serving it writes that phrase in its Serves line, beside any other goal's section name.
6. **`.claude/skills/sitrep/SKILL.md`, how Path 3 is recognised** — step 3's `serves=` awk prints `path3` instead of `goal` when the newest complete Issue Review's Serves line, lowercased, contains `a safeguard has to earn its cost` (after the `none` test, before the `goal` default). Why robust: it is the README line's own opening words, so the rule review-issue follows and the match are the same literal; the newest-complete-review, fence and `none` handling are reused unchanged; a test pins that the phrase is in `README.md`, so renaming the line fails a test. The `wpath` chain becomes: unnamed-rows unknown, then `Path 1` (a Direction line names it, still first), then `no path (serves a project goal)` for `goal` or `path3` in a project (Path 3 is a workspace README goal, so a project worktree is never Path 3), then `Path 3` for `path3`, then `Path 2` for `goal`, `no path`, the unknown labels. Comments at lines 395-400 and the "Rows are ..." paragraph (lines 435-455) gain Path 3 and its place in that order.
7. **Sentences of the sit-rep skill that assume two paths** — (a) line 443 "work that serves neither" becomes "work that serves no goal"; (b) line 452 "A project worktree is never `Path 2`" becomes "never `Path 2` or `Path 3`"; (c) lines 1135 and 1141 list `Path 1`, `Path 2`, `Path 3`; (d) line 1146 "serves neither path" becomes "serves none of the paths"; (e) line 1176 closing question "Path 1, Path 2 or both" becomes "By default it is the focus: one of the paths step 3 printed, or several, each named as step 3's last block printed it"; (f) the paths-block prose and line 1176 stop counting. The front-matter `description` does not count paths and stays.
8. **First-sentence extraction (paths block, line 546)** — the pattern `(.+?\.)(?:\s|$)` becomes `(.+?\.\x22?)(?:\s|$)` (a period, then an optional closing quotation mark, then white space). After the change it prints, for the roadmap with the approved text: Path 1 `In the owner's words (2026-11-10): "I also want to move project11 to this workspace".` (unchanged), Path 2 `Implementing the missing pieces to make this workspace reflect the goals we set.` (unchanged), Path 3 `In the owner's words (2026-11-13): "We have a lot of safeguards to make sure we don't produce slop, but I fear we may be over cautious."` The implement pass confirms by a scratch run, not by this prediction.
9. **`.agent/scripts/tests/test_sitrep_checks.sh`** — line 1260 asserts the new closing-question phrase (and `no path`); the Serves test (line 1190) gains issues 32 (Serves carries the token in any case, e.g. `A Safeguard has to earn its cost`, reads `Path 3`), 33 (token in the older review, a newer plain goal: `Path 2`), 34 (token plus a Direction line naming it: `Path 1`), and a project-worktree row with the token (`no path (serves a project goal)`); the paths test (line 1230) gains a Path 3 paragraph ending `."` with its expected first sentence; one assertion that `README.md` contains the phrase. Expected counts rise accordingly; the implement pass reports the new totals.
10. **`.agent/scripts/tests/test_skill_paths.sh`** — comments at lines 7 and 815 say "two"; they become "three", and the check at line 815 also requires a `**Path 3,` paragraph in `## Direction` with no table row between Path 1 and Path 3 (the awk's `last` moves to Path 3).
11. **PR description** says: (a) the ", other than Path 3 work" clause in Path 2 is host-written, not approved by the owner by name, and is listed for his veto; (b) how Path 3 is recognised (the phrase in the Serves line) and that issues reviewed before this merge, with Serves lines not carrying it, read Path 2 until re-reviewed; (c) `docs/design.md` line 105 ("the two paths") is left for the later pull request that changes that file.

### Entries already written

Issue 465's Serves line reads "Reviews that catch the real problems, cheaply (the loop's wall-clock cost) -- docs/design.md#rules; no design-section change." and issue 477's reads "the README's "Quality of the work" goals (economical, never at the cost of quality) and the new line this issue adds under them; ...". Neither carries the phrase, so under this rule both read Path 2. Plan: change nothing in them (the timeline is append-only, and the Serves lines were written before the phrase became the rule); the next Issue Review of either writes the phrase and flips its mark. No other script reads the Serves text (`sitrep_root.sh` and `sitrep_checks.sh` are not touched: the marking lives in the skill's step 3 block).

### Verified by reading (safe)

- `test_skill_paths.sh` line 815 pins the Paths paragraphs' shape (now updated, item 10).
- Step 3's paths awk prints every `**Path <n>` paragraph; only its sentence pattern changes (item 8).
- `sitrep_checks.sh` reads the Direction tables, not the Paths prose.
- Only `README.md#workspace-goals` is cited as a README anchor; a new bullet moves none.
- `docs/design.md` line 105 says "the two paths": accepted by the plan review, left for a later pull request that changes that file.

### Verification for the implement pass

Baseline on the unchanged tree: `test_skill_paths.sh` 146 passed, 0 failed; `test_sitrep_checks.sh` 210 passed, 0 failed. The implement pass runs both, each on its own, then `suites_for_files.sh -- <changed files>`, which printed `ALL` for this file set (so one full local run of the suites).

### Stop condition (part 1)

Anything beyond `docs/roadmap.md`, `README.md`, the sit-rep skill, review-issue's Serves rule, and `test_sitrep_checks.sh` / `test_skill_paths.sh` means stop and report. Not touched: `docs/design.md`, `sitrep_root.sh`, `sitrep_checks.sh`, AGENTS.md, CLAUDE.md.

### Part 2: later pull requests (outline only; each detailed when its turn comes, after the owner merges part 1; order from the Issue Review)

1. Push records once, with the merge, not per record-only commit (`run-issue` SKILL.md). Decides: host.
2. Design change log: drop the line-count column so git unions the rows (`docs/design.md` table and its rule). Decides: owner, one yes/no at its merge, smallest option first.
3. A CI failure at the merge checkpoint with a single answer is fixed and re-run, not asked (`run-issue` merge-checkpoint step). Decides: host; recorded as a standing rule on this issue if it changes what reaches the owner.
4. `review_progress.sh findings` and `check` select a pull-request-mode Local Review (script plus test). Decides: host.
5. After a merge from main following the last review, `next` prints the dispatch it needs (`run-issue` SKILL.md, `review_progress.sh`). Decides: host.
6. Stop after two fix rounds after publishing unless data loss or security is at stake (his 2026-11-12 proposal). Decides: owner, one yes/no with his words quoted, at its merge.

Already homed, not duplicated: #465, #444, #472; the offline merge path stays undecided and unfiled.

## Files to Change

| File | Change |
|------|--------|
| `docs/roadmap.md` | "Two" to "Three"; one clause in Path 2; Path 3 paragraph after Path 2 |
| `README.md` | one bullet under "Quality of the work" |
| `.claude/skills/sitrep/SKILL.md` | Path 3 marking, two-path sentences, first-sentence pattern |
| `.claude/skills/review-issue/SKILL.md` | one sentence in the Serves rule |
| `.agent/scripts/tests/test_sitrep_checks.sh`, `test_skill_paths.sh` | cases and comments for three paths |

## Prior Art

Nothing new is being built; the Path 3 paragraph follows the shape of Paths 1 and 2 and uses the owner's approved text.

## Serves

README "Quality of the work" (economical, never at the cost of quality) and the new line; `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to how the parts fit. `docs/design.md` line 105 says "the two paths"; left for a later pull request (accepted by the plan review).

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
| Paths paragraphs | `docs/design.md` line 105 "the two paths" | No: accepted by the plan review; left for a later PR that changes that file |
| README goals | sit-rep per-issue mark and closing question | Yes: part 1 items 5-10 |

## Open Questions

- None. `docs/design.md` line 105 ("the two paths") stays, accepted by the plan review and the host, and is fixed in a later pull request that changes that file anyway.

## Estimated Scope

Part 1: single PR, six files plus two tests. Part 2: six further small PRs.
