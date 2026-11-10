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
