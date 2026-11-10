# Plan: Roadmap Direction: next acceptance case is project11 on a second machine

## Issue

https://github.com/rolker/agent_workspace/issues/432

## Context

The GeoZui4D acceptance case was met on 2026-11-09. The owner set the next direction on 2026-11-10 (quotes in the proposed text below). One PR rewrites `docs/roadmap.md`'s `## Direction` section and brings the "Cutover sequence" section in line. No script, skill or test changes. Facts checked today: `rolker/unh_marine_autonomy` is PUBLIC; #396 there is OPEN with no milestone; GeoZui4D's `docs/roadmap.md` has a `## Direction` section and `rolker/geozui4d#8` (onboarding) is CLOSED; `register_project.sh` exists, so #265's part 4 is only retiring `project/` and `projects/`, the worktree fallback, and registering the project11 instances (comment of 2026-11-09). Issues 429, 430, 323, 415, 428, 265, 431, 338, 295, 398, 260-262 are all OPEN.

## Approach

1. **Replace the Direction prose** (acceptance case, Paths) with the text under "Proposed section text" below. Keep the `Format` bullets and the "no status, no dates" sentence unchanged.
2. **Replace the Line table** with the rows below, project11 chain first. Every check is in the `sitrep_checks.sh` grammar; no cell is empty; no cell is a bare number.
3. **Replace the Deferral table** (rows below). Remove the three old deferrals: #265 PR 4 becomes a line; #295 moves into the install-line deferral; the GeoZui4D Direction-section deferral is removed because the onboarding run settled it (`rolker/geozui4d#8` closed and that repository's `docs/roadmap.md` has `## Direction`; verified by `gh api` today, re-verify when editing).
4. **Cutover sequence section**: add one sentence under its heading pointing at Direction as the current acceptance case; in row 7 change "Acceptance test" wording to "see Direction" and keep the porting note; in step-5 row 5 of the Redesign table drop "real `gz4d` issues +" (met) and keep "project11 under `~/project11-ng`"; row 8 "ROS machine" stays (record text, still true). Rows 1-6 and 9 are untouched.
5. **Stale-reference search, repo-wide** (not only `docs/`, work-plans history excluded as records): `grep -rnI "GeoZui4D acceptance\|acceptance case\|project11-ng\|p11-rolling\|ROS machine\|Path 1\|Path 2\|geozui" --exclude-dir=.git --exclude-dir=worktrees .` and read each hit outside `.agent/work-plans/`; known hits to read: `.claude/skills/sitrep/SKILL.md`, `docs/design.md` lines 105-110, `docs/decisions/0016*.md` line 216, `.agent/knowledge/host_standing_rules.md`, `tools/ros-manifest/tests/test_acceptance_p11.py`. Fix only a claim that is now false.
6. **Verify**: `.agent/scripts/sitrep_checks.sh --root . ` shows every row with a result (none `unchecked`/`format`); `--summary` reads; run `/sitrep` and confirm the next step is the first line (#429). Run `grep -rn "<hostname>"` over `.agent/scripts .claude tests` (hostname must be absent); pre-commit.

## Proposed section text (each sentence with its source)

**Acceptance case.** "Project11 is developed on a second machine against ROS 2 Rolling through this workspace, which is the move he named: 'I also want to move project11 to this workspace ... test on pickerel, the new desktop machine I have, and set it up to develop project11 against ROS2 rolling.' The machine is assumed to have a fresh Ubuntu 26.04, ROS and Claude Code, with agents running locally: 'It got a fresh OS install with 26.04 and will have ROS installed as well as Claude Code so agents can run locally on pickerel ... just assume that will be the state the workspace can expect when we are ready to clone it there.' It is done when the simulator works in Rolling: 'a working simulator in Rolling' (2026-09-21)."
- Only joins of his words plus "through this workspace" and "It is done when" (from his 2026-09-21 criterion). The issue's added "an issue ... runs through the loop from a session at the project root" is not his; it stays as a Line, not in the case.

**Paths.** "Three paths run in parallel; 'We can do stuff in parallel', and 'let's not wait on other stuff' for project11. When he asks for a sit-rep, he decides which to focus on."
- Path 1, project11 on a second machine: "'I think project11 on pickerel is not too far off.'"
- Path 2, the workspace is what we designed: "'I think path 2 is important' ... 'follow up on the findings during the gz4d tests and Path 2 mentioned earlier to make sure the work we put it to design the workspace is fully implemented.'" Contents (from the old Path 2 text and the issue's deferral list): audit trials, instruction-file trim, backlog sweep.
- Path 3, the orchestrator and his work managers: "'What about things like the orchestrator skill which we are trialing and the use of the workspace for the agents I run in ~ as my overall work managers?'" plus "'we might be due for a round of orchestrator updates ... and we can keep on evaluating it as we work on other stuff.'" Recorded as not done: a permissions baseline for sessions started in `~` (`user_tier_install.sh` covers the promoted workspace scripts only; found not done in the issue review); not a blocker for Path 1.

**Line table** (project11 first):

| Line | Check |
|---|---|
| `/run-issue` drives an issue in a package repository of a multi-repository project (#429) | `gh-issue 429 closed` |
| The workspace installs on the second machine from a clean clone, user tier included, and the Rolling instance is registered and builds there (#430) | `gh-issue 430 closed` |
| A `/run-issue` run on a project11 package issue, started at the project root there, reaches the merge checkpoint | `gh-issue 430 closed` until a tracking issue exists (see Open Questions) |
| The simulator comes up from the Rolling manifest and a basic mission runs (rolker/unh_marine_autonomy#396) | `gh-issue rolker/unh_marine_autonomy#396 closed` |
| The small tooling fixes land (#323) | `gh-issue 323 closed` |
| The fixes from the first GeoZui4D onboarding run land (#415) | `gh-issue 415 closed` |
| The loop defects seen on the GeoZui4D drives are fixed (#428) | `gh-issue 428 closed` |
| `project/` and `projects/` and the worktree fallback are retired, and the project11 instances are registered (#265, part 4; the registration script exists) | `gh-issue 265 closed` |
| The orchestrator skill has its first round of updates from the dogfooding log (#431) | `gh-issue 431 closed` |

**Deferral table** (revisit check = when to raise it again; as the issue lays out):

| Deferral | Revisit check |
|---|---|
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

Goal "Keep one current design" / the acceptance-case goal in `README.md` workspace goals; `docs/design.md#documentation-layers`.

## Design Picture

No change to the design picture. The roadmap holds plans, not the design (ADR-0017); the Cutover section gets a pointer, not new design.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Owner's words, smallest edit | Every goal sentence above is his quote or a join of quotes; paraphrase listed for veto |
| Machine-checkable lines | All cells in grammar; the hostname appears only in quoted record text, not in any check |
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
| Acceptance case wording | Sit-rep reads its first sentence (`test_sitrep_checks.sh` uses fixtures, not this file) | Yes, step 6 |
| Cutover section | Row 7/8, Redesign step 5 | Yes (step 4) |

## Open Questions

For the owner (veto, or his call):
1. **Numbering**: Path 1 is now project11 and Path 2 keeps his "path 2" (the workspace); old Path 1 (GeoZui4D) is met and dropped. Say if he meant a different numbering.
2. **No issue yet for "a `/run-issue` run on a project11 package issue reaches the merge checkpoint"**: opening a tracking issue (like `rolker/geozui4d#9`) is his call. Until then the line uses `gh-issue 430 closed` and #430's acceptance should gain "a `/run-issue` run reaches the merge checkpoint there" (an issue-body edit, also his call). The same edit would add "the Rolling instance builds" to #430, whose current steps register and validate but do not say build.
3. **Simulator line is stricter than "a basic mission runs"**: #396 closes only after the whole Rolling port (size, builds, simulator, switch trunk). A closer check needs a milestone-level issue, which the grammar cannot test anyway.
4. Pickerel appears by name in the acceptance-case quote (record text only).

## Estimated Scope

Single doc PR.
