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

## Plan Review
**Status**: complete
**When**: 2026-11-10 10:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #432 — Roadmap Direction: next acceptance case is project11 on a second machine against ROS 2 Rolling, with the workspace follow-ups alongside
**Plan**: `.agent/work-plans/issue-432/plan.md` at `bab6be65`
**Branch**: `feature/issue-432`

Second review, after the host's revise checkpoint. Scope: the first review's two must-fixes and five suggestions, and anything the revision broke. Points the first review accepted are not reopened.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one doc PR on `docs/roadmap.md`. |
| Issue alignment | Good | Serves, as checked: "README workspace goal 'The long view'; `docs/design.md#documentation-layers`". The README section exists (`### The long view`) and the anchor exists. Suggestion 5 resolved. |
| File targeting | Good | Sit-rep not changed, as the host directed; two paths fit its mechanism. |
| Consequences | Needs work | Five follow-up lines still labelled Path 1 by the sit-rep while the Path 2 text claims them (finding 1). Step 6 contradicts the deliberately empty cell (finding 2). |
| Principle alignment | Needs work | Status words gone ("not too far off", "the registration script exists"); Path 2 keeps its name. Two paths listed for veto with his quote (Open Question 1). Finding 1 remains. |
| ADR compliance | Good | Unchanged from the first review. |
| ROS conventions | N/A | Workspace doc plan. |

### Resolution of the first review

- Must-fix 1 (three paths vs the sit-rep): partly resolved. Two paths, sit-rep unchanged, listed for veto with his words. Not resolved: which path the five follow-up lines sit in (finding 1 below).
- Must-fix 2 (shared `gh-issue 430 closed` check): resolved. The install line now says only what issue 430's acceptance says (clean-clone install, `user_tier_install.sh --check --require`; checked against the issue body today). Build and the `/run-issue` run are one line with its own tracking issue; Approach step 2 and Open Question 2 say clearly that the cell stays empty unless the host supplies the number, that the sit-rep reads it as "not yet done (no automatic check)" (confirmed in the sit-rep's result-words table), and that the implementer must not open an issue.
- Suggestion 3 (simulator check lags): resolved, Open Question 3.
- Suggestion 4 (status words, Path 2 name): resolved.
- Suggestion 5 (Serves): resolved.
- Suggestion 6a (bare check cells): resolved. All eight filled line cells and three deferral cells parse and return `false` today; the empty cell returns `unchecked` / `none` (`sitrep_checks.sh --root . --roadmap <scratch copy>`, exit 0).
- Suggestion 6b (hostname grep): resolved. `grep -rnIl <hostname> .agent .claude tools docs scripts --exclude-dir=work-plans` finds nothing today, so step 6's "absent outside `docs/roadmap.md`" is a working check.

### Findings

1. **[Consequences / Principle alignment]** (must-fix, the unresolved half of the first review's must-fix 1) The sit-rep labels a worktree `Path 1` when any Direction line names its issue (`.claude/skills/sitrep/SKILL.md`, step 3 rules). The plan's Path 1 is "(the lines below whose check names an issue)", which is all eight filled lines, so the work on #323, #415, #428, #265 and #431 is labelled Path 1, project11. But the Path 2 paragraph quotes "follow up on the findings during the gz4d tests" (the #415 and #428 lines) and lists "the orchestrator trial" (the #431 line), and the issue itself calls these five "the Path 2 lines". When the owner answers the closing question with "Path 2", the sit-rep will show that work under Path 1. The first review named exactly these five lines; the revision does not say where they belong. Resolve one way and list it for veto in Open Question 1: either the five stay as Direction lines and the Paths text says every Direction line is Path 1 work (the acceptance case needs them), with the gz4d-findings quote and "the orchestrator trial" narrowed in Path 2 to what no line names; or they leave the Line table and become Path 2 prose, which the sit-rep then labels Path 2 through their issue reviews' Serves lines. The plan's "keep the existing definition sentences, reworded only to match the table" must say which. (The first review's related note, that no `adapter --project` check names the Rolling instance so project11 package worktrees other than #396 are not labelled Path 1, is also unanswered; one sentence saying whether that is intended is enough.)
2. **[Verification]** (suggestion, new in this revision) Approach step 6 still says the checks show "every row with a result (none `unchecked`/`format`)". With the deliberately empty cell, that row is `unchecked` (confirmed on the scratch copy), so step 6 fails as written unless the host supplies a number. Say "none `unchecked` except the combined line while its cell is empty". Also make sure the implementer leaves the cell truly empty, not the plan's placeholder "(empty cell; see below)".
3. **[Consequences]** (suggestion, new in this revision) Approach step 2 fills the cell with `gh-issue <N> closed`, which checks the workspace repository only. The model it names, `rolker/geozui4d#9`, is a project-repository issue; if the owner opens the tracking issue in `rolker/unh_marine_autonomy` or a package repository, the cell must be `gh-issue <owner/repo>#<N> closed`. Say "in the form for the repository the issue is in".
4. **[Consequences]** (suggestion; text unchanged since the first plan, faithfulness of the quotes not in question) The sit-rep prints the acceptance case's first sentence as its second line, split at the first period followed by a space (`.claude/skills/sitrep/SKILL.md` step 5). The ellipsis in the first quote ends that sentence early: run on the proposed text, `acceptance_first` is "Project11 is developed on a second machine against ROS 2 Rolling through this workspace, which is the move he named: 'I also want to move project11 to this workspace ...", cut mid-quote. Smallest fix: end the first sentence before the quote (for example a period after "through this workspace", then "It is the move he named: '...'"), and re-run step 5's block in verification.

### Summary

Must-fix 2 and all five suggestions are resolved, and every filled check parses. Must-fix 1 is half resolved: two paths now fit the sit-rep, but the five follow-up lines would be labelled Path 1 while the Path 2 text claims them. The revision also left step 6 contradicting the empty cell, and the fill form only fits a workspace-repository issue.

### Recommended Actions

- [ ] Say which path the five follow-up lines (#323, #415, #428, #265, #431) belong to, make the Path 1 and Path 2 text agree with how the sit-rep labels them, and list the choice for veto; answer the `adapter --project` note in one sentence.
- [ ] Step 6: allow `unchecked` for the combined line while its cell is empty; leave the cell truly empty.
- [ ] Step 2: fill the cell in the repository form if the tracking issue is not in this repository.
- [ ] End the acceptance case's first sentence before the quote that contains "...", and check `acceptance_first` in verification.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 11:05 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second plan review: one must-fix half open and three new suggestions, all about how the section's tables map to the sit-rep's path labels; mechanism, no change of scope; second host revise in a row, so the next answer at this checkpoint is the owner's)
**After**: plan
**Decision**: revise

Host read the second Plan Review of 2026-11-10 (needs-work) and directs:
- This is the second finding about path labels, so the question is whether the mechanism is right, not another wording fix. The sit-rep labels every issue a Direction line names as Path 1. So the Line table holds only the project11 chain (issue 429, issue 430, the combined build-and-run line, the simulator line), which is Path 1 in fact. The loop-defects issue 428 goes with the Path 2 follow-ups unless the plan shows it must be Path 1.
- The Path 2 follow-ups the owner asked not to lose (issues 323, 415, 428, 265 part 4, 431) leave the Line table. First choice: rows of the Deferral table with the revisit check `gh-issue <N> open`, so the sit-rep lists each as due on every run until it closes. Before choosing, read how `sitrep_root.sh --worktrees --rows` computes `named` and how the sit-rep skill words a due deferral; if a deferral row would also label the work Path 1, or the wording would mislead, name them in the Path 2 paragraph with `(#N)` instead and say what the sit-rep then shows for them. State the choice, why, and what each follow-up's in-flight work is labelled.
- Say in the plan that project11 worktrees are not labelled through an `adapter --project` check, and why that is acceptable or what check would do it.
- Take the three new suggestions: step 6 allows the one `unchecked` row and the cell is truly empty; the cell's form is `gh-issue <owner/repo>#<N> closed` when the tracking issue is in a project repository; the acceptance case's first sentence ends before any quote containing "...".
