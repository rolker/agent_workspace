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

## Plan Authored
**Status**: complete
**When**: 2026-11-10 10:06 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-432/plan.md` at `6219805f`

Second revision: the Line table holds only the project11 chain; the five follow-ups (323, 415, 428, 265 part 4, 431) are Deferral rows with `gh-issue <N> open` (a deferral row does not make `named` yes, checked with sitrep_root.sh on a scratch roadmap). Project11 worktrees are not labelled through an adapter check, with reasons; the empty cell, the repository form and the acceptance-case sentence fixes are in. Left open: whether the tracking issue for the combined line exists before merge, and the owner's veto on five always-due deferrals.

## Plan Review
**Status**: complete
**When**: 2026-11-10 10:09 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #432 — Roadmap Direction: next acceptance case is project11 on a second machine against ROS 2 Rolling, with the workspace follow-ups alongside
**Plan**: `.agent/work-plans/issue-432/plan.md` at `6219805f`
**Branch**: `feature/issue-432`

Third review, a narrow convergence check after the host's second revise. Scope: the second review's open must-fix and its three suggestions, and this revision's own changes (the Line table holds only the project11 chain; the five follow-ups are Deferral rows checked `gh-issue <N> open`). Points earlier reviews accepted are not reopened.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one doc PR on `docs/roadmap.md`. |
| Issue alignment | Good | Serves, as checked: "README workspace goal 'The long view'; `docs/design.md#documentation-layers`" (accepted in the second review). The five follow-ups the owner asked not to lose are kept, as Deferral rows. |
| File targeting | Good | Sit-rep unchanged; no file it reads needs to change. |
| Consequences | Needs work | The section's opening sentence, kept unchanged by step 1, calls the Deferral table "what was set aside on purpose"; five of its eight rows would not be (finding 1). |
| Principle alignment | Good | The choice, why and the labels are stated, and listed for veto (Open Question 2) with its cost. |
| ADR compliance | Good | Unchanged. |
| ROS conventions | N/A | Workspace doc plan. |

### Evidence checked this run (scratch copy of `docs/roadmap.md` with the planned acceptance case and tables)

- `sitrep_checks.sh --root . --roadmap <copy>`, exit 0: the three filled lines `false`, the combined line `unchecked` with check `none`, the five `gh-issue <N> open` deferrals `true`, the three old deferrals `false`; `--summary-from` gives `lines 0/4 deferrals 5/8`, as step 6 expects.
- `sitrep_root.sh --worktrees --rows <rows>`: `feature/issue-429` `named: yes`; `feature/issue-323`, `feature/issue-432` and `main` `named: no`. The script reads only `f[0] == "line"` rows, both for the (b) keep rule and for `named` (read in the source).
- Issue 323's worktree has a complete Issue Review whose `**Serves**:` names "Quality of the work ... and Trust, control and information", so the sit-rep labels its work `Path 2` (SKILL.md step 3 code: `named` no, `serves` goal, workspace type).
- The acceptance case's first sentence, split by step 5's block: "Project11 is developed on a second machine against ROS 2 Rolling through this workspace." No quote is cut.
- `update_roadmap.sh --issue N` for 323, 265, 429 and 430 on the copy: "No roadmap entries found", file unchanged; merges will not alter the rows.
- What the owner will see (SKILL.md step 8): under **Problems**, five lines "Deferral due: Follow-up still open: ..." on every run until each issue closes, and "**Deferrals**: 5 of 8 due (under Problems)". "Next:" is the first line that is not `true`, now the #429 line; a due deferral becomes "Next:" only when every line is `true`, which the empty cell prevents until a check is filled in and reads `true`.

### Resolution of the second review

- Must-fix 1 (five follow-ups labelled Path 1 while Path 2 claims them): resolved. They are no longer Line rows; a deferral row never makes `named` yes (verified above); their in-flight work is `Path 2` when its issue review names a goal. The `adapter --project` note is answered ("Project11 worktrees"; Open Question 5).
- Suggestion 2 (step 6 and the empty cell): resolved. Step 6 allows the one `unchecked` row; step 2 says the cell is truly empty, no placeholder.
- Suggestion 3 (repository form): resolved. Step 2 and Open Question 3 give `gh-issue <owner/repo>#<N> closed`.
- Suggestion 4 (acceptance case's first sentence): resolved and verified above.

### Findings

1. **[Consequences]** (must-fix, one clause) The section's opening sentence, which step 1 keeps unchanged, says the section holds "what was set aside on purpose", and the Format bullet says a deferral's check "says when to look at it again". The five new rows are the reverse: work he asked to go on in parallel ("We can do stuff in parallel"), due from the first run. Merged as planned, the roadmap describes five of its eight deferrals wrongly, and he could read them as parked. The sit-rep output itself is acceptable: the "Follow-up still open:" prefix makes "Deferral due: Follow-up still open: small tooling fixes (#323)" read as open work, and Open Question 2 states the cost. Fix: in step 1, change the opening sentence to cover both kinds of row, e.g. "... and what was set aside on purpose or is kept in view until it closes". Optionally add the same to the Format deferral bullet. The implementer can apply this; it needs no further plan review.
2. **[Consequences]** (suggestion) "Project11 worktrees" point (3) and Open Question 5 say unnamed project11 package work in a workspace session "reads path unknown/no path". In fact `sitrep_root.sh` keeps a workspace session's worktrees only by rule (a) (workspace or main) or rule (b) (named by a line), so such a worktree is not listed at all. Write "is not shown in the workspace's sit-rep until a line names it" so his veto rests on the right fact.
3. **[Verification]** (suggestion) "Where the follow-ups go" says the deferrals cannot take over "Next" "before the simulator line is closed by an issue". It is the empty cell that blocks it, until a check is filled in and reads `true`. That text is plan-only; correct it if it goes into the PR description. Also, Path 1's "(see 'Project11 worktrees' below)" refers to the plan; leave it out of the roadmap.

### Summary

The second review's must-fix and its three suggestions are resolved, and the revision's evidence holds: deferral rows do not make `named` yes, the five `open` checks parse and read `true`, and the counts match step 6. One must-fix remains, a one-clause wording fix: the section's own opening sentence would call five active follow-ups "set aside on purpose". It can be fixed during implementation without another plan round.

### Recommended Actions

- [ ] Step 1: reword the section's opening sentence (and optionally the Format deferral bullet) so it covers follow-ups kept in view until they close.
- [ ] Say in point (3) and Open Question 5 that unnamed project11 worktrees are not shown in the workspace's sit-rep.
- [ ] Keep the plan's cross-references ("see ... below") and the "simulator line" wording out of the roadmap and the PR description.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 11:50 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

The dialog showed the third review's one must-fix (the section's opening sentence calls the deferral table "what was set aside on purpose", which is wrong for the five follow-up rows; reword it to also cover rows kept in view until their issue closes), the acceptance case as it would read, the two paths, and what every sit-rep would show (Next is issue 429; five "Follow-up still open" lines). Asked "Go ahead and implement the roadmap rewrite with F1 fixed along the way?", the owner answered: "Proceed (Recommended)".

Asked in the same dialog whether to open a tracking issue in the workspace repository for the combined build-and-run line, he answered: "Yes, in the workspace (Recommended)". The host opened issue 433; that line's check cell is `gh-issue 433 closed`.

Carried to the implementer: the must-fix above and the third review's two suggestions (unnamed project11 work is not listed at all in a workspace sit-rep; no "see ... below" references in the roadmap or the pull request text).

## Implementation
**Status**: complete
**When**: 2026-11-10 10:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-432 at `847e9002`

- `docs/roadmap.md` Direction: acceptance case and Paths from the plan's text (owner quotes in double quotes, first sentence ends before any quote); Path 1 project11 on a second machine, Path 2 keeps its name and takes the orchestrator trial, the work managers in `~` and the five follow-ups; Line table the four-line project11 chain, the combined build-and-run line checked `gh-issue 433 closed` and named (#433); Deferral table five "Follow-up still open" rows (`gh-issue <N> open`) and the three reworded rows.
- Third review's must-fix: the opening sentence now reads "set aside on purpose or is kept in view until its issue closes"; the Format deferral bullet says the same. Suggestions: Path 1 says unnamed project11 package work "is not listed in this workspace's sit-rep"; no plan cross-references in the roadmap.
- Old deferrals: #265 PR 4 is a follow-up row, #295 moved into the install-line deferral, the GeoZui4D Direction-section deferral removed (rolker/geozui4d#8 closed and its roadmap has `## Direction`, re-verified). The OQ-2 paragraph about the GeoZui4D run removed with that case.
- Cutover sequence: one sentence pointing at Direction; row 7 "Acceptance case, see Direction"; Redesign step 5 drops "real `gz4d` issues +".
- Stale-reference search: one now-false claim, `docs/design.md` Documentation layers "(ADR-0016's)", dropped with a change-log row (869 lines). Other hits are records or still true.
- Verified: `sitrep_checks.sh --root .` gives the four lines `false` (first is the #429 line), five follow-ups `true`, three old rows `false`, no `unchecked` or `format`; summary `lines 0/4 deferrals 5/8`. `sitrep_root.sh --worktrees --rows`: named yes for #429, no for #323 and #432. acceptance_first prints "Project11 is developed on a second machine against ROS 2 Rolling through this workspace." `update_roadmap.sh --dry-run` finds no entries for any issue the section names. This machine's hostname is in no script, skill, test or doc; the second machine's name only in the roadmap's quoted text. pre-commit on the changed files passed (script-test hook reached no suite), so test_skill_paths.sh, test_sitrep_checks.sh and test_design_anchors.sh were run directly: all pass. The full `/sitrep` skill was not run; the rows above are its inputs.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-10 11:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-432 at `85d199fc`
**Base**: main
**Depth**: Deep (reason: 542 changed lines, mostly plan/progress records; docs change 108 lines)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Verified: sitrep_checks.sh parses every cell, no unchecked/format, first false line is the issue 429 line, five follow-ups true, summary lines 0/4 deferrals 5/8; sitrep_root.sh named yes only for 429; acceptance_first and both Path paragraphs parse; check_design_anchors.sh exit 0; test_skill_paths 136/136, test_design_anchors 47/47; pre-commit passes; hostname only in quoted roadmap text. Gemini: complete, one plan-drift note (explained by the third plan review). Codex: complete, no issues.

### Findings
- [x] (must-fix) Direction defers the fork cutover (#260 to #262) until unh_marine_autonomy#396 closes, but the Cutover sequence orders rows 5-6 (#260, #261) before row 7 and says they "land as we go"; reconcile (e.g. the Cutover pointer says Direction defers rows 5, 6 and 8 until the simulator line is true) — `docs/roadmap.md:89,186-204`
- [x] (must-fix) "Follow-up still open:" is a status word the section's no-status rule forbids and goes stale when the issue closes; write "Follow-up:" and update the Path 2 sentence quoting it — `docs/roadmap.md:44,82-86`
- [x] (suggestion) Both Path paragraphs' first sentences (printed in the sit-rep's closing question) are classification rules ("…a Direction line below…"), not his goal; lead with a clause in his words — `docs/roadmap.md:33,38`
- [x] (suggestion) Acceptance case: "the move he named" has no antecedent (acceptance_rest prints alone), the 2026-11-10 quotes are undated, and "The machine is assumed to have…" restates the quote that follows — `docs/roadmap.md:19-27`
- [x] (suggestion) "Also under this path" lists the home-directory permissions baseline (not his words) and the work managers, whose design a deferral sets aside until #396 closes; list for veto or reconcile — `docs/roadmap.md:49-51`

## Implementation
**Status**: complete
**When**: 2026-11-10 11:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-432 at `4f995757`
**Addressed**: Local Review (Pre-Push) at `85d199fc` (2026-11-10 11:08 -05:00)
**Commits**: 3bedeb58, c64b2abd, 68dab9ce, 95e84ceb, 4f995757

Checks on the final tree: `sitrep_checks.sh --root . --summary` prints `lines 0/4 deferrals 5/8` (exit 0); step-5 rendering prints acceptance_first whole ("Project11 is developed on a second machine against ROS 2 Rolling through this workspace."); step-3 rendering prints each Path's first sentence whole, neither containing "..."; `check_design_anchors.sh .` exit 0; full pre-commit over `main...HEAD` with no SKIP exit 0 (validate-script-tests had no in-scope files: the branch changes only docs and work plans).

### Actions
- [x] Cutover pointer says Direction defers rows 5, 6 and 8 (#260 to #262) until its simulator line is true; row 7 now says it does not reorder or skip rows 2–4 — `docs/roadmap.md:192-193,210`
- [x] Five follow-up deferral rows open "Follow-up:"; the Path 2 sentence quoting the prefix matches — `docs/roadmap.md:49,87-91`
- [x] Path 1 opens with the owner's goal in his words (2026-11-10), full quote after the classification rule; Path 2 opens with its pre-change first sentence cut to his 2026-10-15 goal, dated — `docs/roadmap.md:32-45`
- [x] Acceptance case: first sentence and the 2026-09-21 ending kept; "It is the move he named" and the restating "The machine is assumed to have..." sentence removed; quotes introduced "In the owner's words (2026-11-10):" — `docs/roadmap.md:18-26`
- [x] Path 2 list: home-directory permissions baseline removed (stays recorded on issue 432); his "overall work managers" named with their design waiting on the orchestrator design session deferral (#398) — `docs/roadmap.md:54-56`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-10 11:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a6b92f9107365416d, resume 1 of 3)
**Verdict**: approved

**Branch**: feature/issue-432 at `b3bbdf95`
**Base**: main
**Depth**: Deep (reason: whole-diff classification per the fix-round rule, 583 changed lines mostly plan/progress records; round 2, so all specialists and cross-model ran)
**Must-fix**: 0 | **Suggestions**: 3
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Both round-1 must-fixes are resolved. The Cutover pointer states that Direction defers rows 5, 6 and 8, and row 7 now says rows 2–4. The deferral rows read "Follow-up:" with no status word. Round-1 suggestions 2 and 3 are resolved, and suggestion 1 is resolved in part (see below). Re-run: sitrep_checks.sh gives 4 lines false and 5 deferrals true, 3 false, with no unchecked or format row (summary lines 0/4 deferrals 5/8); sitrep_root.sh gives named yes only for issue 429. acceptance_first prints whole. Step 3 prints Path 1 as 'In the owner's words (2026-11-10): "I also want to move project11 to this workspace", to "develop project11 against ROS2 rolling".' and Path 2 as 'Implementing the missing pieces to make this workspace reflect the goals we set (the owner, 2026-10-15).' Both read as his goal. The 2026-10-15 date is right: main quotes him that day as "implementing the missing pieces to making this workspace reflect the goals we set in the other", so the new text corrects "making" to "make" and leaves it unquoted, the same form as main's old Path 2 first sentence. Claude adversarial raised that attribution as a must-fix; it is held as a suggestion because the date is right and the wording is his apart from that one grammar fix. Gemini: complete, no issues. Codex: complete, one suggestion (folded into the third below).

### Findings
- [x] (suggestion) Path 1's first sentence joins two fragments with ", to", which reads awkwardly alone in the sit-rep, and the paragraph repeats the full quote ("His full words: ..."), which the acceptance case already carries; open with the full quote and drop the repeat — `docs/roadmap.md:33-39`
- [x] (suggestion) Path 2's first sentence is his 2026-10-15 words with "making" changed to "make", unquoted; quote it verbatim if he is to read it as his exact words — `docs/roadmap.md:41-43`
- [x] (suggestion) The Cutover ordering rule "each row starts when the rows above it are done" still reads against row 7 running before the deferred rows 5–6; add "row 7 does not wait for them" to the pointer (Codex, Claude adversarial) — `docs/roadmap.md:192-195,210`

## Checkpoint
**Status**: complete
**When**: 2026-11-10 12:45 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 2 approved with three wording suggestions; two of them are things the owner would meet: a sentence the sit-rep prints to him on every run, and a rule in the Cutover section that still reads against the new order; small, docs only)
**After**: publish
**Decision**: address

Host read the round-2 review of 2026-11-10 (approved, Ship recommended, 3 suggestions) and directs all three be taken before the pull request opens: Path 1's first sentence is one whole quote of the owner's that stands alone when the sit-rep prints it, with the repeat of the full quote dropped; Path 2's first sentence is his words exactly or plainly not presented as a quote; the Cutover rule says row 7 does not wait for the deferred rows.

## Implementation
**Status**: complete
**When**: 2026-11-10 11:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent ab41365b85fe97750, resume 1 of 3)

**Branch**: feature/issue-432 at `b4b6acb6`
**Addressed**: Local Review (Pre-Push) at `b3bbdf95` (2026-11-10 11:13 -05:00)
**Commits**: cab6b989, c9756bc5, b4b6acb6

Checks on the final tree: `sitrep_checks.sh --root . --summary` prints `lines 0/4 deferrals 5/8` (exit 0); step-5 rendering prints acceptance_first whole; step-3 rendering prints Path 1 as `In the owner's words (2026-11-10): "I also want to move project11 to this workspace".` and Path 2 as `Implementing the missing pieces to make this workspace reflect the goals we set.`, each whole; `check_design_anchors.sh .` exit 0; full pre-commit over `main...HEAD` with no SKIP exit 0. The Path 1 quote ends with the period outside the closing quote: the sit-rep cuts at a period followed by a space, so a period inside the quote would run the first sentence on into the classification rule.

### Actions
- [x] Path 1 opens with one unbroken quote of the owner's (2026-11-10), then the classification rule; the repeat of his long quote is dropped (the acceptance case carries it) — `docs/roadmap.md:32-36`
- [x] Path 2's first sentence is main's unquoted prose up to "we set", without the added "(the owner, 2026-10-15)" attribution — `docs/roadmap.md:38-40`
- [x] Cutover pointer adds that row 7 does not wait for the deferred rows 5 and 6 — `docs/roadmap.md:188-190`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-10 11:15 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a6b92f9107365416d, resume 2 of 3)
**Verdict**: approved

**Branch**: feature/issue-432 at `ab8b05cf`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: the round-2 suggestions and the fix diff since 411ab2ca. Cross-model was skipped (round-3 convergence check, per handoff), and so was the Claude adversarial subagent, because the scope was narrow. All three round-2 suggestions are addressed. Path 1 now opens with one whole quote and the repeat is gone. Path 2's first sentence is main's prose, without the attribution. The Cutover pointer adds "so row 7 does not wait for rows 5 and 6". Path 1's period sits outside the closing quote, so the sit-rep's cut lands after the quote and prints it whole. That placement is correct: his words end at "workspace". Re-run results: sitrep_checks.sh lines 0/4 deferrals 5/8, with no unchecked or format row; named is yes only for issue 429; acceptance_first and both Path first sentences print whole and read as goals; check_design_anchors.sh exit 0; test_skill_paths 136/136.

### Findings
- [ ] (suggestion) The Paths paragraph says why the paths run in parallel (his 2026-11-10 words) and Path 1 cites its source, but Path 2's origin, his 2026-10-15 "two parallel paths" statement, is no longer quoted anywhere, so his "Path 2 mentioned earlier" has no antecedent; e.g. Path 2's first sentence could quote him verbatim with the date ("implementing the missing pieces to making this workspace reflect the goals we set", 2026-10-15) — `docs/roadmap.md:39-46`

## Checkpoint
**Status**: complete
**When**: 2026-11-10 13:00 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 approved, Ship recommended, no must-fix; the one suggestion is carried to the pull request for the owner to see with the merge decision)
**After**: publish
**Decision**: publish

Host read the round-3 review of 2026-11-10 (approved, no must-fix, one suggestion: Path 2's origin, the owner's 2026-10-15 "two parallel paths" quote, no longer appears in the section). It is listed in the pull request's decision summary rather than given a fourth round.
