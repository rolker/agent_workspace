---
issue: 432
---

# Issue #432 — Roadmap Direction: next acceptance case is project11 on a second machine

## Issue Review
**Status**: complete
**When**: 2026-11-10 09:49 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #432

### Scope Assessment

**Well-scoped?** Yes — one section of `docs/roadmap.md` plus the Cutover-sequence section; a single doc PR. The lines it names are separate issues.
**Right repo?** Yes — workspace (roadmap). Two lines check a project repo (`rolker/unh_marine_autonomy#396`), which `sitrep_checks.sh` reads as `gh-issue <owner/repo>#<N>`.
**Serves**: the acceptance-case and "Keep one current design" goals — `docs/design.md#documentation-layers`
**Design picture?** No change to how the parts fit. The Cutover-sequence section (roadmap, step 5 and rows 2, 7, 8) describes `~/project11-ng` instances and a "ROS machine" cutover; it must be reconciled or pointed here.
**Dependencies**: lines point at #429, #430, #323, #415, #428, #265, #431 (all open); deferral points at #338, #295, #398, #260-#262.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Owner's words, smallest edit | Action needed | The Direction text (acceptance case, paths) must be drafted from his quoted words of 2026-11-10; the issue's proposed text is a paraphrase in places ("three paths", Path 3 "home as a root" is not in his quotes). Quote him and keep paraphrase minimal. |
| Keep one current design | Watch | The Cutover-sequence section already says the cutover/acceptance for project11 differently (`~/project11-ng`, row 7 on `p11-rolling`); two places must not disagree. |
| Machine-checkable lines | Action needed | Three lines are "to be named at plan time". An empty or vague check renders `unchecked`, so the sit-rep's "first unmet line" would stall on them; the plan must name a grammar-valid check for each (the grammar has no way to test another machine, so these are likely `gh-issue` on issues filed for the purpose). |
| Project-agnostic workspace (ADR-0003) | Watch | The hostname may appear only in records; keep it out of checks, scripts, tests. Acceptance already says so. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0016 (roots, user tier) | Yes | Project-root sessions on the second machine and the home root rest on it; Accepted 2026-11-09. |
| ADR-0003 | Yes | Hostname/project names in records only. |
| ADR-0017 | Yes | Design doc unchanged unless the cutover section counts as design; roadmap is not the design doc. |
| ADR-0013 | No | |

### Consequences

- The deferral rows currently in Direction (#265 PR 4, #295, gz4d Direction section) change: #265 PR 4 becomes a line; #295 moves with the install-line deferral. `update_roadmap.sh` marks lines done on merge, so check cells must be pure checks, never a bare number.
- Check `sitrep_checks.sh` accepts `rolker/unh_marine_autonomy#396` (cross-repo form is in the grammar) and what "milestone" check is possible: `gh-issue` tests only open/closed, not a milestone.
- Plan inputs the host asked to flag. (a) Registration script: `.agent/scripts/register_project.sh` already exists (1244 lines, built by #332, with `--set`, `--default-instance`, `--install-user-tier`, `--remove`, `--dry-run`). The #265 comment of 2026-11-09 says the same. So the "registration script is finished" line is mis-worded: what remains of #265 PR 4 is retiring `project/` and `projects/` and the worktree fallback, and registering `~/project11-ng/<distro>`. The line text should say that. (b) Permissions baseline for home-directory sessions: no record found of one. `user_tier_install.sh` merges permission rules for the promoted scripts into `~/.claude` (ADR-0016, design.md Sessions and roots), which covers workspace scripts, not a baseline for a session started in `~`. #110 (permission prompt reduction) is marked done; `analyze-permissions` exists. Treat as not done; it belongs to Path 3 and is not a blocker for Path 1.

### Recommendations

- Draft the Direction section from the owner's quoted words (2026-11-10) with the smallest edit, and drop wording of the issue's proposal that he did not say; ask him only about the Path 3 wording (see question).
- Name a grammar-valid check for each "to be named at plan time" line before the PR, filing a tracking issue where needed (Rolling build on the second machine; `/run-issue` on a project11 package issue; simulator mission); do not leave a cell empty.
- Reword the #265 line to what remains (retire `project/` and `projects/`, register project11 instances), since `register_project.sh` already exists.
- Reconcile the Cutover-sequence section (rows 2, 7, 8 and step 5 notes, `~/project11-ng`) with the new case, or replace it with a pointer to Direction, in the same PR.
- Record the permissions baseline for home sessions as unknown/not done under Path 3 and the orchestrator-update line, not as a prerequisite for Path 1.
- Verify `/sitrep` reports the first unmet line (the #429 line) after the edit, and keep the hostname out of checks.

### Actions
- [ ] The Direction text (acceptance case, paths) must be drafted from his quoted words of 2026-11-10; the issue's proposed text is a paraphrase in places ("three paths", Path 3 "home as a root" is not in his quotes). Quote him and keep paraphrase minimal.
- [ ] Three lines are "to be named at plan time". An empty or vague check renders `unchecked`, so the sit-rep's "first unmet line" would stall on them; the plan must name a grammar-valid check for each (the grammar has no way to test another machine, so these are likely `gh-issue` on issues filed for the purpose).
- [ ] Draft the Direction section from the owner's quoted words (2026-11-10) with the smallest edit, and drop wording of the issue's proposal that he did not say; ask him only about the Path 3 wording (see question).
- [ ] Name a grammar-valid check for each "to be named at plan time" line before the PR, filing a tracking issue where needed (Rolling build on the second machine; `/run-issue` on a project11 package issue; simulator mission); do not leave a cell empty.
- [ ] Reword the #265 line to what remains (retire `project/` and `projects/`, register project11 instances), since `register_project.sh` already exists.
- [ ] Reconcile the Cutover-sequence section (rows 2, 7, 8 and step 5 notes, `~/project11-ng`) with the new case, or replace it with a pointer to Direction, in the same PR.
- [ ] Record the permissions baseline for home sessions as unknown/not done under Path 3 and the orchestrator-update line, not as a prerequisite for Path 1.
- [ ] Verify `/sitrep` reports the first unmet line (the #429 line) after the edit, and keep the hostname out of checks.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 10:05 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review's actions are all plan inputs and none changes scope: draft from his quoted words, name a grammar-valid check per line, reword the issue 265 line to what remains, reconcile the Cutover sequence section, treat the home permissions baseline as not done)
**After**: issue-actions
**Decision**: proceed

Host read the Issue Review of 2026-11-10 and its six actions. The one question it raised (is "home as a root" a third path) is covered by the owner's own words of 2026-11-10: "What about things like the orchestrator skill which we are trialing and the use of the workspace for the agents I run in ~ as my overall work managers?" The plan names that path from those words (recipe (c)), listed for his veto.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 09:51 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-432/plan.md` at `6e47b4a8`

One doc PR: rewrite the roadmap Direction section from the owner's quoted words of 2026-11-10 (project11 chain first, three parallel paths, grammar-valid checks, deferrals with revisit checks), point the Cutover sequence section at it, and search the repo for stale references.

## Plan Review
**Status**: complete
**When**: 2026-11-10 09:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #432 — Roadmap Direction: next acceptance case is project11 on a second machine against ROS 2 Rolling, with the workspace follow-ups alongside
**Plan**: `.agent/work-plans/issue-432/plan.md` at `6e47b4a8`
**Branch**: `feature/issue-432`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One doc PR (`docs/roadmap.md`), plus any now-false claim the stale-reference search finds. |
| Issue alignment | Needs work | Covers all four acceptance bullets and every issue-review action. Serves, as checked: "Goal 'Keep one current design' / the acceptance-case goal in `README.md` workspace goals; `docs/design.md#documentation-layers`". "Keep one current design" is a principle (`docs/principles.md`), and README has no acceptance-case goal; the anchor exists. Finding 5. |
| File targeting | Concern | `.claude/skills/sitrep/SKILL.md` is read only for false claims, but its path mechanism does not fit three paths (finding 1). |
| Consequences | Concern | Missing consequence: the sit-rep's path labels and its closing question (finding 1). Shared check on two lines (finding 2). |
| Principle alignment | Needs work | Owner's words: the 2026-11-10 quotes match his messages in the host transcript word for word, and the 2026-09-21 criterion matches the auto-memory record. "Three paths run in parallel" and Path 3 as its own path say more than his words, and the plan does not list them for veto (finding 1). Status words in a section that holds no status (finding 4). |
| ADR compliance | Good | ADR-0003: the hostname appears only in quoted record text and `rolker/unh_marine_autonomy` is PUBLIC (checked). ADR-0016 and ADR-0017 apply as the plan says. |
| ROS conventions | N/A | Workspace doc plan. |

### Findings

1. **[Consequences / Principle alignment]** (must-fix) Three paths do not fit the sit-rep's path mechanism. `.claude/skills/sitrep/SKILL.md` step 3 labels work `Path 1` when a Direction line names its issue and `Path 2` when the work otherwise serves a README goal; there is no Path 3. Its closing question offers "Path 1, Path 2 or both". Under the plan's table, the Path 2 and Path 3 lines (#323, #415, #428, #265, #431) would all be labelled Path 1, Path 3 would never be labelled or offered, and the sit-rep would contradict the Paths text. The plan also drops the old definition sentences ("Path 1 work is an issue named in a Direction line ...", "Path 2 work is any other work ..."), which describe how the sit-rep already works. "Three paths" is also not his wording ("We can do stuff in parallel"), and Open Questions lists only the numbering, not whether a third path exists at all. Resolve one of two ways. Either keep two paths, which is what the mechanism supports: the orchestrator and `~` work go under Path 2, from his "Path 2 ... make sure the work we put it to design the workspace is fully implemented", and the definition sentences are reworded to match the table. Or keep three, and bring the sit-rep change and its test into scope or a separate issue before merge. In both cases, list the choice for his veto with the quotes. (Related: no line has an `adapter --project` check for the Rolling instance, so project11 worktrees outside `unh_marine_autonomy` are not labelled Path 1.)
2. **[Consequences]** (must-fix) The install line and the `/run-issue` line both check `gh-issue 430 closed`. Closing issue 430 makes both lines true on that one event. Issue 430's acceptance names neither a Rolling build nor a `/run-issue` run reaching the merge checkpoint, so the sit-rep would report both as done with no evidence that either happened. That is a false true; the simulator check (finding 3) only lags. The plan's fallback asks the owner whether to edit 430 at the merge hand-back, and it does not say what the cell becomes if he declines. Before merge: open a tracking issue for the run, on the `rolker/geozui4d#9` model. That is a mechanism step: list it for veto rather than ask. Also make the install line's "and builds there" match its check: either 430's acceptance says build (edited before merge), or the build moves to the tracking issue's line.
3. **[Issue alignment]** (suggestion) Simulator line: `rolker/unh_marine_autonomy#396` closes only after milestone 4 (trunk switch and variant policy), not at milestone 3, where the simulator works. Its Acceptance was written by an agent; only its first sentence restates the owner's 2026-09-21 criterion. The check lags rather than misleads, so the host's answer is acceptable. Note the lag in Open Questions so a "not yet" after the simulator runs is expected.
4. **[Principle alignment]** (suggestion) Drop the status words. "'I think project11 on pickerel is not too far off.'" as Path 1's text, and "the registration script exists" in the line for issue 265 (#265), will go stale, and the section says it holds no status. Smallest edit: keep Path 2's existing name ("the workspace reflects the goals"), which he referred to as "path 2", and add his 2026-11-10 quote to it. "The workspace is what we designed" renames it.
5. **[Issue alignment]** (suggestion) In Serves, name a README workspace-goals section (for example "Trust, control and information" or "The long view") rather than a principle and a goal that does not exist.
6. **[Verification]** (suggestion) Write the line-3 cell as the bare check. Run as planned, "`gh-issue 430 closed` until a tracking issue exists ..." reads `unchecked`; the bare check cells all parse (`sitrep_checks.sh` run on a scratch copy). Step 6's hostname grep names a `tests` directory that does not exist; widen it to `.agent` (work plans excluded), `.claude`, `tools` and `docs` other than the roadmap.

### Summary

The quotes are faithful, every check parses, and the Cutover reconciliation is sound. Two findings must be fixed before implementation. The third path has no place in the sit-rep's mechanism and has not gone to the owner for veto. One check would mark two lines done when issue 430 closes, though neither event happened.

### Recommended Actions

- [ ] Choose two paths (mechanism as is) or three (with a sit-rep change in scope); keep the path-definition sentences true to the sit-rep; list the choice for veto with his quotes.
- [ ] Give the `/run-issue`-on-project11 line its own tracking issue before merge; make the install line's "builds" match issue 430 or move it.
- [ ] Remove the status words ("not too far off", "the registration script exists"); keep Path 2's existing name.
- [ ] Note the simulator check's lag; name a README goal in Serves; write bare check cells; widen the hostname grep.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 10:40 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review found two must-fixes, both in how the plan words and checks the lines, neither a change of scope; first host revise on this plan)
**After**: plan
**Decision**: revise

Host read the Plan Review of 2026-11-10 (needs-work, 2 must-fix, 5 suggestions) and directs:
- Two paths, not three. Path 1 is project11; Path 2 keeps its existing name and takes the orchestrator trial and the owner's work managers in his home directory, in his words. The sit-rep knows two paths and is not changed here. Listed for his veto.
- The install line (issue 430) says only what issue 430's acceptance says. "The Rolling instance builds there" and "a /run-issue run reaches the merge checkpoint" become one line, checked by a tracking issue of its own, which only the owner may open; the host asks him. Until he answers, that cell is empty and the sit-rep reads it as not yet done with no automatic check, which is true.
- All five suggestions are taken: no status words in the section, Serves names a README goals section, bare check cells, the simulator check's lag behind the milestone noted in Open Questions, the hostname search widened.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 10:00 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-432/plan.md` at `bab6be65`

Revision after plan review: two paths (Path 2 keeps its name and takes the orchestrator trial and the home-directory work managers, listed for veto), the install line limited to issue 430's acceptance, one combined build-and-run line with an empty check cell, and the five suggestions taken.
