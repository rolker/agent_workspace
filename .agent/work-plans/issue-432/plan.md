# Plan: Roadmap Direction: next acceptance case is project11 on a second machine

## Issue

https://github.com/rolker/agent_workspace/issues/432

## Context

The GeoZui4D acceptance case was met on 2026-11-09. The owner set the next direction on 2026-11-10 (quotes in the proposed text below). One PR rewrites `docs/roadmap.md`'s `## Direction` section and brings the "Cutover sequence" section in line. No script, skill or test changes. Facts checked today: `rolker/unh_marine_autonomy` is PUBLIC; #396 there is OPEN with no milestone; GeoZui4D's `docs/roadmap.md` has a `## Direction` section and `rolker/geozui4d#8` (onboarding) is CLOSED; `register_project.sh` exists, so #265's part 4 is only retiring `project/` and `projects/`, the worktree fallback, and registering the project11 instances (comment of 2026-11-09). Issues 429, 430, 323, 415, 428, 265, 431, 338, 295, 398, 260-262 are all OPEN. Revision 3 (after the second plan review and the host's second revise): the Line table holds only the project11 chain; the five follow-ups move to the Deferral table (evidence under "Where the follow-ups go").

## Approach

1. **Replace the Direction prose** (acceptance case, Paths) with the text under "Proposed section text" below. Keep the `Format` bullets and the "no status, no dates" sentence unchanged.
2. **Replace the Line table** with the four rows below (the project11 chain only). Every filled cell is the bare check in the `sitrep_checks.sh` grammar; no cell is a bare number. The combined build-and-run line's cell is **truly empty** (nothing between the pipes but spaces; no placeholder text). The implementer fills it only if the host supplies the tracking issue: `gh-issue <N> closed` if the issue is in this repository, and `gh-issue <owner/repo>#<N> closed` if it is in a project repository (the model, `rolker/geozui4d#9`, is one; the tracking issue for project11 may well be in `rolker/unh_marine_autonomy` or a package repository). Otherwise leave it empty, which the sit-rep reads as `unchecked`, "not yet done, no automatic check". Do not open an issue.
3. **Replace the Deferral table** with the rows below: the three old deferrals reworded (see table), and five follow-up rows with the revisit check `gh-issue <N> open`. Remove the three old deferrals as they stand: #265 PR 4 becomes a follow-up row; #295 moves into the install-line deferral; the GeoZui4D Direction-section deferral is removed because the onboarding run settled it (`rolker/geozui4d#8` closed and that repository's `docs/roadmap.md` has `## Direction`; verified by `gh api` today, re-verify when editing).
4. **Cutover sequence section**: add one sentence under its heading pointing at Direction as the current acceptance case; in row 7 change "Acceptance test" wording to "see Direction" and keep the porting note; in step-5 row 5 of the Redesign table drop "real `gz4d` issues +" (met) and keep "project11 under `~/project11-ng`"; row 8 "ROS machine" stays (record text, still true). Rows 1-6 and 9 are untouched.
5. **Stale-reference search, repo-wide** (not only `docs/`, work-plans history excluded as records): `grep -rnI "GeoZui4D acceptance\|acceptance case\|project11-ng\|p11-rolling\|ROS machine\|Path 1\|Path 2\|geozui" --exclude-dir=.git --exclude-dir=worktrees .` and read each hit outside `.agent/work-plans/`; known hits to read: `.claude/skills/sitrep/SKILL.md`, `docs/design.md` lines 105-110, `docs/decisions/0016*.md` line 216, `.agent/knowledge/host_standing_rules.md`, `tools/ros-manifest/tests/test_acceptance_p11.py`. Fix only a claim that is now false.
6. **Verify** (scratch copy first, then the real file):
   - `.agent/scripts/sitrep_checks.sh --root .` shows every row with a result except one: the combined build-and-run line is `unchecked` (check `none`) while its cell is empty, and that is the only allowed `unchecked`; no `format` row. If the host supplied the number, that line also has a result. `--summary` reads (`lines 0/4 deferrals 5/8` expected today: the five follow-ups are due, the three old rows are not).
   - `.agent/scripts/sitrep_root.sh --worktrees --rows <rows saved from the run above>`: `named` is `yes` for the worktree of #429 and `no` for the worktrees of #323 and #432 (no follow-up is `named`).
   - The acceptance case's first sentence, split as the sit-rep splits it (first period followed by a space), is "Project11 is developed on a second machine against ROS 2 Rolling through this workspace." with no quote cut in it: print it with the awk block of `.claude/skills/sitrep/SKILL.md` step 5 and read it.
   - Run `/sitrep` and confirm the next step is the first line (#429) and the five follow-ups appear as "Deferral due".
   - `grep -rnI "<hostname>" .agent .claude tools docs scripts --exclude-dir=work-plans` finds the hostname only in `docs/roadmap.md`, in quoted record text; pre-commit passes.

## Proposed section text (each sentence with its source)

**Acceptance case.** "Project11 is developed on a second machine against ROS 2 Rolling through this workspace. It is the move he named: 'I also want to move project11 to this workspace ... test on pickerel, the new desktop machine I have, and set it up to develop project11 against ROS2 rolling.' The machine is assumed to have a fresh Ubuntu 26.04, ROS and Claude Code, with agents running locally: 'It got a fresh OS install with 26.04 and will have ROS installed as well as Claude Code so agents can run locally on pickerel ... just assume that will be the state the workspace can expect when we are ready to clone it there.' It is done when the simulator works in Rolling: 'a working simulator in Rolling' (2026-09-21)."
- Only joins of his words plus "through this workspace" and "It is done when" (from his 2026-09-21 criterion). The first sentence ends before the quote because the sit-rep prints the text up to the first period followed by a space, and the quote contains "...". The issue's added "an issue ... runs through the loop from a session at the project root" is not his; it stays as a Line, not in the case.

**Paths.** "Two paths run in parallel; 'We can do stuff in parallel', and 'let's not wait on other stuff' for project11. When he asks for a sit-rep, he decides which to focus on." The sit-rep knows two paths and is not changed. The old definition sentences stay, reworded to match the tables:
- **Path 1, project11 on a second machine.** Path 1 work is an issue named in a Direction line (in the line itself or its check). That is exactly the four lines of the Line table: #429, #430, the combined build-and-run line (named once the host supplies its tracking issue) and #396. Work in a project11 package repository outside those issues is not named by any line (see "Project11 worktrees" below).
- **Path 2, the workspace reflects the goals** (existing name kept). Path 2 work is any other work that serves a goal in the README. His 2026-11-10 words: "'the orchestrator skill which we are trialing and the use of the workspace for the agents I run in ~ as my overall work managers'", and "'follow up on the findings during the gz4d tests and Path 2 mentioned earlier to make sure the work we put it to design the workspace is fully implemented.'" The follow-ups he asked not to lose are named in the Deferral table, not the Line table: small tooling fixes (#323), the fixes from the first GeoZui4D onboarding run (#415), the loop defects seen on the GeoZui4D drives (#428), retiring `project/` and `projects/` (#265, part 4) and the orchestrator skill's first updates from the dogfooding log (#431). Also under this path: audit trials, the instruction-file trim, the backlog sweep, the orchestrator trial, the work managers in his home directory, and the home-directory permissions baseline for sessions started in `~`. No status words.
- The old Path 1 (GeoZui4D) is met and dropped; project11 takes the number 1.

### Where the follow-ups go (the choice and its evidence)

**Choice: Deferral table rows, revisit check `gh-issue <N> open`.** Evidence, all read or run today in this worktree:
- `.agent/scripts/sitrep_root.sh` computes `named` (and the (b) keep rule) only from rows of kind `line` (the Python block reads `f[0] == "line"`; its header says "this root's own Direction lines"). A deferral row is never read for `named`. On a scratch copy of the roadmap with the planned tables, `sitrep_root.sh --worktrees --rows <rows>` gave `named: yes` for the worktree of #429 and `named: no` for the worktrees of #323 and #432.
- `sitrep_checks.sh` on that copy gave `true` for all five `open` checks (all five issues are open), `false` for the three filled lines, and `deferrals 5/5` in the summary.
- The sit-rep lists a deferral whose result is `true` as "Deferral due: <the deferral, as written>" in Problems and as "k of n due" in the Deferrals counts (`.claude/skills/sitrep/SKILL.md`, "Deferral due" and the Deferrals bullets), on every run, until the issue closes and the check goes `false`. A deferral becomes the Suggested next only when every Direction line is `true`; while the project11 chain is open, "Next" is the first line, #429. The empty cell keeps the chain from reading all-true, so the deferrals cannot take over "Next" before the simulator line is closed by an issue.
- Wording: the row text is written as what is still open ("Follow-up still open: ..."), so "Deferral due: Follow-up still open: small tooling fixes (#323)" does not read as a promise to start now. That the five rows are due from the first run is intended: it is how they are not lost (his words above).

**What each follow-up's in-flight work is labelled.** A worktree for #323, #415, #428, #265 or #431 is not `named`, so the sit-rep never labels it Path 1. It is `Path 2` when its newest complete Issue Review has a `**Serves**:` line naming a goal (issue 323's does: "Quality of the work ... and Trust, control and information", read today), `no path` when that line is `none`, and "path unknown" when there is no complete Issue Review. So the label is Path 2 for follow-up work whose issue review names a goal, which is the intended state; the implementer does not change any issue. The Path 1 and Path 2 text above agrees with this.

**Not chosen: naming them with `(#N)` in the Path 2 paragraph only.** That would also leave them unlabelled Path 1, but the sit-rep would not list them as due, and he asked that they not be lost. Fallback if the owner dislikes five permanent "due" lines: move the rows to the paragraph; the labels would not change.

### Project11 worktrees

No line has a `script adapter --project <name> validate` check for the Rolling instance, so a worktree in a project11 package repository is not labelled Path 1 through the project; the sit-rep labels it only if a line's `gh-issue <owner/repo>#N` check names its issue (today only #396 in `rolker/unh_marine_autonomy`, and the tracking issue for the combined line once it exists). This is acceptable because (1) the sit-rep reports on the session's own root only (owner, 2026-11-09), and the Direction section is the workspace's, so the sit-rep that matters here reports workspace sessions; (2) the Rolling instance is not registered yet (registering the project11 instances is #265 part 4, one of the follow-ups), and an `adapter --project` check for an unregistered name would fail as `false`/`unknown`, which would say nothing true; (3) a project worktree is never `Path 2` (SKILL.md step 3), so unlabelled project11 work reads "path unknown/no path", which is accurate until a line names it. Left open: once #265 part 4 registers the instance, a line `script adapter --project <name> validate` would label every worktree of that instance Path 1. It is not added now because the registered name does not exist and the issue, not this plan, decides it; a later Direction edit adds it.

**Line table** (the project11 chain only; the third cell is empty on purpose):

| Line | Check |
|---|---|
| `/run-issue` drives an issue in a package repository of a multi-repository project (#429) | `gh-issue 429 closed` |
| The workspace installs on the second machine from a clean clone, user tier included (#430) | `gh-issue 430 closed` |
| The Rolling instance builds on the second machine, and a `/run-issue` run on a project11 package issue, started at the project root there, reaches the merge checkpoint | |
| The simulator comes up from the Rolling manifest and a basic mission runs (rolker/unh_marine_autonomy#396) | `gh-issue rolker/unh_marine_autonomy#396 closed` |

**Deferral table:**

| Deferral | Revisit check |
|---|---|
| Follow-up still open: small tooling fixes (#323) | `gh-issue 323 open` |
| Follow-up still open: fixes from the first GeoZui4D onboarding run (#415) | `gh-issue 415 open` |
| Follow-up still open: loop defects seen on the GeoZui4D drives (#428) | `gh-issue 428 open` |
| Follow-up still open: retire `project/` and `projects/` and the worktree fallback, and register the project11 instances (#265, part 4) | `gh-issue 265 open` |
| Follow-up still open: the orchestrator skill's first updates from the dogfooding log (#431) | `gh-issue 431 open` |
| Audit trials (escape-rate count, review-round rule) | `gh-issue 429 closed` |
| Instruction-file trim (#338), the backlog sweep, the workspace as a registered project (#295) | `gh-issue 430 closed` |
| The orchestrator design session with the design for the home-directory work managers (#398); the fork cutover (#260 to #262) | `gh-issue rolker/unh_marine_autonomy#396 closed` |

## Files to Change

| File | Change |
|---|---|
| `docs/roadmap.md` | Direction section (steps 1-3); Cutover sequence pointer, row 7 and Redesign step 5 note (step 4) |
| Others | Only if step 5's search finds a now-false claim |

## Prior Art

The previous Direction section (GeoZui4D case): same table grammar, same Format bullets; reused. `rolker/geozui4d#9` is the model for a "run reaches the merge checkpoint" tracking issue.

## Serves

README workspace goal "The long view"; `docs/design.md#documentation-layers`.

## Design Picture

No change to the design picture. The roadmap holds plans, not the design (ADR-0017); the Cutover section gets a pointer, not new design.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Owner's words, smallest edit | Every goal sentence above is his quote or a join of quotes; paraphrase listed for veto |
| Machine-checkable lines | All filled cells in grammar, bare; the one empty cell is reported `unchecked`, which is true; the hostname appears only in quoted record text, not in any check |
| Owner's follow-ups not lost | His quote is kept in Path 2; the five follow-ups are due on every sit-rep until closed |
| Project-agnostic mechanism (ADR-0003) | Hostname and project names only in roadmap prose/checks, which are records |
| One current design | Cutover section pointed at Direction so two places do not disagree |
| Verify before claiming | Step 6 runs the checks; claims above were read from `gh` today |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0016 | Yes | Project-root sessions and `~` sessions rest on it; no change |
| ADR-0003 | Yes | See above |
| ADR-0017 | Yes | Design doc unchanged; step 5 checks `docs/design.md` mentions |
| ADR-0013 | No | |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Direction lines and deferrals | `update_roadmap.sh` ticks on merge: no bare numbers, no checklists | Yes (step 2-3) |
| Acceptance case wording | Sit-rep reads its first sentence (`test_sitrep_checks.sh` uses fixtures, not this file) | Yes, step 6 (first sentence ends before the quote) |
| Which table a follow-up is in | The sit-rep's path labels and its Deferral lines (`sitrep_root.sh`, SKILL.md steps 3 and 5) | Yes, "Where the follow-ups go"; sit-rep unchanged |
| Cutover section | Row 7/8, Redesign step 5 | Yes (step 4) |

## Open Questions

For the owner (veto, or his call):
1. **Two paths** (veto): Path 1 is project11 (the four-line chain); Path 2 keeps its name and takes the orchestrator trial, his work managers in `~`, and the follow-ups on the GeoZui4D findings, in his words quoted above. The sit-rep is not changed. Old Path 1 (GeoZui4D) is met and dropped. A third path would need a sit-rep change and test first.
2. **The five follow-ups are Deferral rows, always due until closed** (veto): chosen with the evidence above (a deferral row does not label work Path 1; the sit-rep lists it as due each run). Cost: five "Deferral due" lines on every sit-rep for as long as they are open. Alternative: names in the Path 2 paragraph only.
3. **The combined build-and-run line has an empty check cell.** It needs a tracking issue (like `rolker/geozui4d#9`), which only he may open; the host has asked him. Until the number is supplied the cell stays empty and the sit-rep reads "not yet done (no automatic check)"; the form is `gh-issue <owner/repo>#<N> closed` if the issue is in a project repository. Left open: whether that issue exists before merge. The install line says only what #430's acceptance says.
4. **Simulator check lags the milestone**: `gh-issue rolker/unh_marine_autonomy#396 closed` is true only after the whole Rolling port (trunk switch included), later than the simulator working. A "not yet" after the simulator runs is expected.
5. **No `adapter --project` check for the Rolling instance** (see "Project11 worktrees"): project11 package work is unlabelled Path 1 until a line names its issue or the instance is registered and a line is added.
6. Pickerel appears by name in the acceptance-case quote (record text only).

## Estimated Scope

Single doc PR.
