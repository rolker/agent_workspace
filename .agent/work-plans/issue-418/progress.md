---
issue: 418
---

# Issue #418 — sitrep: report the session's own root, so a project session gets the project's sit-rep

## Issue Review
**Status**: complete
**When**: 2026-11-09 09:49 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #418

### Scope Assessment

**Well-scoped?** Yes, with one Watch -- eight parts (S1-S8) in one PR is large but they are one change (the skill's root) and share tests; if the plan finds S7's deferral rewording or the S4 inbox ordering pulling apart, split them out. The scope matches the owner's 2026-11-09 narrowing (session root only; the combined view is a later "personal" skill, not here).
**Right repo?** Yes -- skill, check runner, tests, design and roadmap all live in the workspace repo; the project is only read.
**Serves**: "Easy to use" and "The long view" -- `docs/design.md#documentation-layers`, `docs/design.md#sessions-and-roots`
**Design picture?** Changes Documentation layers -- the "reads only the workspace root so far" sentence (docs/design.md line 133). The issue already records the owner's decision and names the update (S7), so no new question.
**Dependencies**: #388 (inbox under one lock) touches S4 -- land first or rebase; #408 (distance to done) is independent. Verified both are open.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | OK | Owner decision recorded in the body; S7 updates design.md and the roadmap row in the same change (ADR-0017). |
| A change includes its consequences | Watch | S7 covers the design and roadmap. Also check the skill's frontmatter description ("in a workspace session it may start a due read-only check"), the Problems rule at SKILL.md "In a project session ... the Problems section is the workspace's only" (S3 replaces it), step 2's `awk '$2 == "workspace"'` and step 4's `printf ... workspace` (S5), and the worktree filter `type == "workspace"` in the issue-timeline step. |
| Leave in a project only what it chose to carry | OK | No-Direction case reports and invents nothing; onboarding is only mentioned, not required (D3). |
| Test what breaks | Watch | S8 names a sandbox root. The acceptance bullets should each map to a test: project with section, project without section, workspace unchanged (run-record column stays `workspace`), and the `docs/roadmap.md` then `ROADMAP.md` order. |
| Only what's needed | OK | Combined view explicitly excluded; no new script is proposed. |
| Verify before claiming | OK | The "4 of 7 true" figure is the issue's own run; `sitrep_checks.sh --root/--roadmap` exists and its checks are a fixed vocabulary (no eval, header line 74), so reading a project's roadmap runs no project-authored shell. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0003 project-agnostic | Yes | S8 uses a synthetic sandbox root, as required; keep project names out of skill text and tests. |
| 0013 progress.md vocabulary | No | Only the Issue Review entry itself. |
| 0016 session roots | Yes | S1 must resolve through `session_root.sh` (root/type/project) and never a nested package repo; the registered name for S5 comes from its `project=` line. |
| 0017 design doc is current picture | Yes | Covered by S7. |

### Consequences

- Skill-paths test (`test_skill_paths.sh`) and `test_sitrep_checks.sh` need the project-root case.
- The skill description line must drop the workspace-only wording.
- Existing run-record lines have `workspace` in column 2: S5 keeps that value for the workspace, so old records stay valid; a project name colliding with `workspace` should be refused or noted.

### Recommendations

- Settle in the plan how S2 finds the root's remote for `gh pr list -R` when the root is a multi-repo hosting directory with no remote of its own (ADR-0016: the registered hosting directory is the root, not a nested package repo); say "no pull-request source" rather than guessing.
- Decide S3's "where the root has those files" test as a file-exists check per workspace-shaped check, so the skip line names which check and why.
- In the plan, decide the S7 deferral fate (revisit check or Decided Against) and order the work after #388 or state the rebase.

### Actions
- [ ] Settle in the plan how S2 finds the root's remote for `gh pr list -R` when the root is a multi-repo hosting directory with no remote of its own (ADR-0016: the registered hosting directory is the root, not a nested package repo); say "no pull-request source" rather than guessing.
- [ ] Decide S3's "where the root has those files" test as a file-exists check per workspace-shaped check, so the skip line names which check and why.
- [ ] In the plan, decide the S7 deferral fate (revisit check or Decided Against) and order the work after #388 or state the rebase.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 09:49 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the three open actions are mechanism: how the pull-request source is found for a root with no single remote, a per-check skip line in Problems, and the deferral row's fate plus ordering against #388; none adds or drops a behaviour the owner asked for)
**After**: issue-actions
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. The owner's scope (2026-11-09, quoted in the issue) stands: the session root only. The three actions go to plan-task as plan inputs.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 09:51 -0500
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-418/plan.md` at `8e866811`

One PR: a small read-only helper (sitrep_root.sh) decides the session's root, roadmap, pull-request source (none for a hosting root without its own repository), record name and per-check skips; the skill uses it. Deferral row becomes Decided Against; work lands after #388.

## Plan Review
**Status**: complete
**When**: 2026-11-09 09:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #418 — sitrep: report the session's own root, so a project session gets the project's sit-rep
**Plan**: `.agent/work-plans/issue-418/plan.md` at `8e866811`
**Branch**: `feature/issue-418`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, ~8 files, session root only, as the owner narrowed it (2026-11-09). No combined view. |
| Issue alignment | Needs work | Serves, as checked: Goals "Easy to use" and "The long view"; `docs/design.md#documentation-layers`, `docs/design.md#sessions-and-roots` (both README goals and both anchors exist). All three issue-review actions are answered (pull-request source, per-check skips, deferral fate and ordering). S2's "path marking reads the session root" is not planned (finding 2), and the acceptance bullet "a sit-rep test covers the project-root case" is met only for the helper (finding 4). |
| File targeting | Needs work | `docs/design.md` Change log row missing (finding 5); otherwise the right files. |
| Consequences | Needs work | Several workspace-only sentences in the skill are not in the plan (finding 5); git facts in step 6 for a root that is not its own repository (finding 3). |
| Principle alignment | Needs work | "Test what breaks": the helper's rationale ("skill prose cannot be tested") is false; `test_sitrep_checks.sh` section 13 already runs the skill's blocks with `skill_step` (finding 4). "Only what's needed": the helper is still justified, by de-duplication (every step block re-derives the root, since shell state does not persist). "Keep one current design": the Documentation layers change is named; the Change log row is not. |
| ADR compliance | Good | 0003 (sandbox only), 0016 (root from `session_root.sh`, hosting directory never a nested package), 0017 (design in the same PR). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Approach: ordering] must-fix** — Drop the gate on #388. #388 has no branch, worktree or pull request, so "start after #388 merges" blocks this issue on a whole loop that has not started, and "rebase onto it if still open" has nothing to rebase onto. Land #418 first; #388 (a small, fully specified snapshot change to steps 2 and 4 plus one test) is planned against the post-#418 steps. To keep #388 the same size, S4's project-first ordering must reuse the existing listing pass in step 2, not add a fifth unlocked read of the inbox.
2. **[Issue alignment: path marking] must-fix** — Step 3's path logic (SKILL.md lines 355-363) is workspace-shaped and the plan does not touch it: Path 1 by a `(#N` number matches only `type = workspace` worktrees; a project worktree is "never Path 2" and reads "no path (serves a project goal)". In a project session a project worktree named in that project's own Direction line would never be Path 1. Step 5's issue-title lookup also uses `$WS_REPO` and `_issue_lookup_gitbug "$WS_ROOT"`. The plan must say how path words work for a project root (Path 1 by this root's Direction lines for this root's worktrees; what Path 2 means there or that it is not said; no path words when `paths=none`) and that step 5's title lookup uses `pr_source`.
3. **[Consequences: step 6 git facts] must-fix** — The plan runs local-main-behind "for any root", but a registered root may sit inside the workspace tree (`session_root.sh`: "a root inside the workspace tree is its own root"); for one with no repository of its own, `git -C <root>` resolves upward and reports the workspace's main. Apply the same top-level test as `pr_source` to step 6's git facts, and say what happens when the project's default branch is not `main` (report "cannot tell", not a wrong count).
4. **[Test what breaks] must-fix** — The tests listed exercise the helper and the runner only. Add project-sandbox cases that run the skill's own steps through `skill_step` (test_sitrep_checks.sh section 13): step 2's last-record filter by `record_name`, step 4's record column, step 3's worktree filter and path words. Correct the plan's rationale: skill blocks are tested today; the helper earns its place by removing duplicated root logic from six blocks.
5. **[Consequences: missed text] must-fix** — Not in the plan: the report template's paragraph "Workspace root only: registered project roots are not read in this mode, so Path 1 work that lives in a project root does not show here" (SKILL.md line 890); step 3's "`-R` names the workspace repository ... so a project session does not list the project's pull requests by mistake" (line 193); step 8's "A project worktree's pull requests are not looked up" (lines 967-969); and a `docs/design.md` Change log row (the section's decided rule: one row per change, with the line count).
6. **[File targeting: worktree filter] suggestion** — `type == "project" and repo == <project>` misses a parent root's instances (a parent-root session owns them; `wt_registry_worktree_dirs` lists instances under their own names) and can miss package worktrees whose `repo` comes from the manifest header. Filter by membership in the root's worktree directories instead.
7. **[Approach: helper edge] suggestion** — `session_root.sh` exits 1 outside the workspace and every registered root; say what `sitrep_root.sh` and the skill do then (stop and say so, never fall back to the workspace silently) and test it.
8. **[Approach: deferral] suggestion** — Decided Against is the right home: the owner put the combined view outside `/sitrep`, and a revisit check has nothing to test until a personal-root skill exists. Its Reason should quote the owner and name where the idea went, because the inbox line that captured it is machine-local and not tracked. The design's Measures row ("one machine-local line per run") could add "per root".
9. **[Consequences: Problems] suggestion** — The Documentation fact (days since `docs/design.md` changed, commits since touching `.agent .claude docs`) is workspace-shaped too; list it among the per-check skips by name, not only the anchor check.

### Summary

The approach is sound and the scope matches the owner's narrowing. Revise before implementing: drop the #388 gate (this issue lands first), plan the project-root path marking and step 6 git facts, test the skill's own steps in a project sandbox, and add the missed sentences and the Change log row.

### Recommended Actions

- [ ] Remove the #388 gate; land #418 first; keep S4 inside the existing inbox listing pass (no new read)
- [ ] Plan step 3's path words and step 5's issue-title lookup for a project root
- [ ] Guard step 6's git facts with the top-level test; handle a default branch other than `main`
- [ ] Add project-sandbox tests that run the skill's steps via `skill_step`; correct the helper's rationale
- [ ] Add the missed consequences: SKILL.md lines 193, 890, 967-969; `docs/design.md` Change log row

## Checkpoint
**Status**: complete
**When**: 2026-11-09 09:55 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the plan review's five must-fix findings are mechanism gaps in how the project root is handled: the 388 ordering, path words for a project root, the local-main check on a root with no repository, tests through the skill's own bash blocks, and skill text the plan missed; none touches the owner's scope)
**After**: plan
**Decision**: revise

Host answer under /orchestrator's checkpoint table, first host revise on this issue. The plan goes back to plan-task with the review's findings 1-9 as inputs; the owner's scope (session root only) is unchanged.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 09:56 -0500
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-418/plan.md` at `203069df`

Revision after plan review: no #388 gate (418 lands first, S4 reuses the existing inbox pass); project-root path words and pr_source title lookup; git facts guarded by own_repo and default branch; project-sandbox tests through skill_step; missed SKILL.md and design.md text covered; worktrees filtered by the root's directories; exit 1 outside every root stops. Still one PR.

## Plan Review
**Status**: complete
**When**: 2026-11-09 09:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #418 — sitrep: report the session's own root, so a project session gets the project's sit-rep
**Plan**: `.agent/work-plans/issue-418/plan.md` at `203069df`
**Branch**: `feature/issue-418`

Second review, of the revised plan. Round-1 must-fix findings 1-5 are resolved in the plan text: (1) no #388 gate, 418 lands first, S4 inside step 2's existing listing pass; (2) Approach 4 gives project-root path words (Path 1 from this root's Direction, Path 2 not said, none with `paths=none`) and step 5's title lookup through `pr_source` and git-bug at `$ROOT`; (3) step 6 git facts gated by `own_repo`, `default_branch` with "cannot tell"; (4) project-sandbox cases through `skill_step` for steps 2-5, rationale corrected (`skill_step` exists at test_sitrep_checks.sh line 782); (5) SKILL.md lines 193, 890, 965-969 and a `docs/design.md` Change log row (section at line 751) are in Approach 7. Suggestions 6-9 are all answered (filter by worktree directories, exit 1 outside every root with a test, Decided Against quoting the owner plus Measures "per root", Documentation fact skipped by name). One new gap comes from adopting suggestion 6.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, ~8 files, session root only, as the owner narrowed it (2026-11-09). No combined view. |
| Issue alignment | Needs work | Serves, as checked: Goals "Easy to use" and "The long view"; `docs/design.md#documentation-layers`, `docs/design.md#sessions-and-roots`. Acceptance "From the workspace root the report is unchanged from today" is put at risk by the workspace's worktree filter (finding 1). |
| File targeting | Good | Right files; the helper, its test, the skill, the two tests, design, roadmap and script reference. |
| Consequences | Needs work | Finding 1; smaller items in findings 2-4. |
| Principle alignment | Good | "Test what breaks": one case per acceptance bullet plus skill blocks through `skill_step`. "Only what's needed": helper justified by de-duplication. "Keep one current design": Documentation layers, Measures and Change log in the same PR. |
| ADR compliance | Good | 0003 (sandbox only), 0016 (root from `session_root.sh`, no nested-package fallback), 0017 (design in the same PR). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences: workspace worktree list] must-fix** — The plan's premise "replaces the `type == "workspace"` filters in steps 3 and 5" is wrong for step 3: its filter is `select(.type != "main" and .issue)` (SKILL.md line 223), so today's workspace sit-rep lists every worktree, project ones included, and marks them Path 1 through `project:$repo` (an `adapter --project <name>` check) or `<slug>#N`. The workspace roadmap's own Paths paragraph defines Path 1 as including "work in the project a line's check names", and the current acceptance case is a project (GeoZui4D) run. `sitrep_root.sh --worktrees` keeping "for the workspace, its own worktrees" would drop that project work from the workspace report, breaking the acceptance bullet "From the workspace root the report is unchanged from today" and the workspace's Path 1. Say what the workspace session lists: keep today's step 3 set there (filter only in a project session), or keep the workspace's own worktrees plus those of the projects its Direction lines name; then add a `--worktrees` test case for the workspace root holding a project worktree named by an `adapter --project` check. Step 5's filter (`type == "workspace"`, line 619) is the one that does need replacing.
2. **[Consequences: ADR titles] suggestion** — Step 5's render block looks up ADR titles in `os.environ["WS_ROOT"]/docs/decisions` (lines 623-630). The plan says step 5 takes `ROOT` while "`$WS_ROOT` stays for scripts"; this lookup is not a script, so name it, or a project's "ADR-0003" prints the workspace's ADR-0003 title, a workspace fact in a project report.
3. **[Consequences: Problems words in a project root] suggestion** — When a project root has its own `docs/design.md` with a Decision register, the audit fact runs and step 7 offers "/audit-workspace from the workspace", which audits the wrong root; and the report template's "<c> commits since changed the workspace's scripts, skills or docs" (SKILL.md ~line 873) would name the workspace. Say what step 7 offers for a project root's facts (audit-project, or nothing) and that the Documentation words name the root.
4. **[Approach: helper output] suggestion** — Say that `sitrep_root.sh --worktrees` prints the same JSON shape as `worktree_list.sh --json` (`{"worktrees": [...]}`), so step 3's `jq '.worktrees[]?'` and step 5's python read it unchanged, and that an error from `worktree_list.sh` is passed through rather than read as "no worktrees".

### Summary

The revision resolves every round-1 must-fix and answers every suggestion. One new must-fix: the worktree filter adopted from suggestion 6 would drop project worktrees that the workspace's own Path 1 counts, changing the workspace report the acceptance says stays unchanged. A one-paragraph plan fix plus one test case; the rest are suggestions.

### Recommended Actions

- [ ] Say what the workspace session's worktree list holds (today's set, or its own plus projects its Direction names) so the workspace report stays unchanged; add the `--worktrees` workspace-root test case
- [ ] Name step 5's ADR-title lookup as reading `$ROOT/docs/decisions`
- [ ] Say what step 7 offers, and how the Documentation fact is worded, for a project root with its own design document
- [ ] Fix `--worktrees` output to `worktree_list.sh --json`'s shape and pass its errors through

## Checkpoint
**Status**: complete
**When**: 2026-11-09 09:59 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (one must-fix on which worktrees a root lists; the roadmap's Path 1 text already answers it: "work in the project a line's check names" is Path 1 work, so a root lists its own worktrees plus any worktree its own Direction lines name, which keeps the workspace report unchanged as the acceptance bullet requires; second host revise in a row, so a third revise would be the owner's)
**After**: plan
**Decision**: revise

Host answer under /orchestrator's checkpoint table. Rule for the revision: a root lists its own worktrees plus the worktrees its own Direction lines name (adapter --project <name> checks, <owner/repo>#N checks); the same rule for both root types. Suggestions 2-4 (ADR titles from the root's docs/decisions, step 7 offer and Documentation wording name the root, --worktrees output pinned to worktree_list.sh's JSON shape with errors passed through) to be answered too.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 09:59 -0500
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-418/plan.md` at `27b4bf65`

Second revision: a root lists its own worktrees plus those its Direction lines name (workspace set unchanged, with a project-worktree test); step 5 ADR titles from the root; step 7 offers audit-project and Documentation wording names the root; --worktrees pinned to worktree_list.sh's JSON shape with errors passed through. Still one PR.

## Plan Review
**Status**: complete
**When**: 2026-11-09 10:01 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #418 — sitrep: report the session's own root, so a project session gets the project's sit-rep
**Plan**: `.agent/work-plans/issue-418/plan.md` at `27b4bf65`
**Branch**: `feature/issue-418`

Third review, a convergence check scoped to the round-2 items and the text the revision changed. Suggestions 2-4 are resolved: step 5's ADR titles read `$ROOT/docs/decisions` (bare number when absent); step 7 offers `/audit-project`, never `/audit-workspace`, for a project root, and the Documentation words name the root by `type`; `--worktrees` prints `{"worktrees": [...]}` and passes `worktree_list.sh` errors through. The must-fix (what a workspace session lists) is answered with the host's rule, but the plan's claim that the rule gives today's workspace set is not true, and replacing step 5's filter with the rule's output adds a wrong match.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one PR, ~8 files, session root only, as the owner narrowed it (2026-11-09). |
| Issue alignment | Needs work | Serves, as checked: Goals "Easy to use" and "The long view"; `docs/design.md#documentation-layers`, `docs/design.md#sessions-and-roots`. Acceptance "From the workspace root the report is unchanged from today" does not hold for project worktrees no Direction line names (finding 1). |
| File targeting | Good | Unchanged. |
| Consequences | Needs work | Findings 1 and 2. |
| Principle alignment | Good | "Test what breaks": new cases for the workspace-root `--worktrees` set, the JSON shape, error pass-through and ADR titles; finding 1 asks for one more. |
| ADR compliance | Good | 0003, 0016, 0017 as in round 2. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment: workspace worktree list] must-fix** — "For the workspace this is today's step 3 set" is not true. `worktree_list.sh --json` lists every root's worktrees (it walks `wt_registry_worktree_dirs` and `wt_legacy_worktree_dirs`, worktree_list.sh line 359), and step 3's filter `.type != "main" and .issue` (SKILL.md line 223) keeps them all, so today's workspace sit-rep shows every project worktree with an issue, including ones no Direction line names (they read "no path (serves a project goal)", SKILL.md line 361; step 8's `myproject/feature/issue-12` example). Under the rule, the workspace keeps (a) its own worktrees plus (b) Direction-named ones, so a project worktree no workspace Direction line names drops out of the workspace report. The planned test only places Direction-named project worktrees in the workspace sandbox, so it cannot see this. The rule's result matches the owner's words ("one in the workspace is just for the workspace"); the plan's claim and the acceptance bullet "unchanged from today" do not. Resolution: keep the rule, correct the claim to say un-named project worktrees no longer show in the workspace report, add that case to the workspace-root `--worktrees` test (expected: dropped), say in Approach 7 that step 3's and step 8's text about project worktrees in the workspace report now covers only Direction-named ones, and record this one narrowing of the acceptance bullet at the checkpoint for veto. Also say what (a) is for the workspace root (`worktrees/workspace/`, from `wt_workspace_base`), since `wt_registry_worktree_dirs` lists only project roots' directories.
2. **[Consequences: step 5 issue match] must-fix** — Approach 4 replaces step 5's `type == "workspace"` filter (SKILL.md line 579, not ~619) with the `--worktrees` output. Step 5's numbers come from `(#N)` and `gh-issue N`, which are this root's own repository's issues; the `--worktrees` set also holds the (b) worktrees of other repositories. In a workspace session, a Direction-named project worktree for its issue 12 would then match a workspace line naming `(#12)` and print as the next step's in-flight branch; in a project session, a workspace worktree named by an `<owner/repo>#N` line can match the project's `(#N)`. Step 5 must match only part (a), the root's own worktrees (for a package worktree, its header slug equal to `pr_source`), and a skill_step case should cover it.
3. **[Consequences: step 7 offer] suggestion** — `/audit-project` does not re-examine a Decision register (its SKILL.md never mentions the register or the Re-examined column), so offering it when a project's "last design-decision review" is due offers a skill that does not do that review. Report the fact and offer nothing for it, or name what audit-project would actually check. Also say what step 7 offers when a project root has its own research digest that is due (the plan covers only the Decision register and absent files).

### Summary

The revision resolves round-2 suggestions 2-4. The host's worktree rule is sound and matches the owner's words, but it does change the workspace report (un-named project worktrees drop out), which the plan denies and does not test, and feeding the rule's output into step 5's issue match introduces a cross-repository number collision. Both are short plan fixes; the first also needs the acceptance bullet's narrowing recorded at the checkpoint.

### Recommended Actions

- [ ] Correct the "today's set" claim: un-named project worktrees drop out of the workspace report; add that workspace-root test case; name `worktrees/workspace/` as the workspace's part (a); update step 3/step 8 text in Approach 7; record the acceptance-bullet narrowing for veto
- [ ] Restrict step 5's issue match to the root's own worktrees (part (a)) and add a skill_step case for a same-number worktree from another repository
- [ ] Decide step 7's offer for a due project Decision register and a due project research digest so it names a skill that does that check, or nothing

## Checkpoint
**Status**: complete
**When**: 2026-11-09 10:24 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Owner's answer to the AskUserQuestion dialog: "Revise (Recommended)". The dialog offered: revise with the two must-fixes (the workspace list is not today's set, so the acceptance bullet "unchanged from today" is narrowed to "the workspace's own worktrees plus project work its Direction lines name", with a test for the dropped case; step 5 matches issue numbers only against the root's own worktrees, with a test for a same-numbered worktree from another repository) and the suggestion (step 7 offers nothing, or names what audit-project checks, for a due design-decision review; say what is offered when a project's research digest is due). The owner accepted the narrowing of the acceptance bullet.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 10:35 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-418/plan.md` at `185449db`

Third revision: the workspace report narrows to its own worktrees plus Direction-named project worktrees (acceptance bullet narrowed by the owner, dropped-worktree test added); step 5 matches issue numbers only against the root's own worktrees (same-number test added); step 7 offers nothing for a due project design-decision review or research digest. Still one PR.

## Plan Review
**Status**: complete
**When**: 2026-11-09 10:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #418 — sitrep: report the session's own root, so a project session gets the project's sit-rep
**Plan**: `.agent/work-plans/issue-418/plan.md` at `185449db`
**Branch**: `feature/issue-418`

Fourth review, a convergence check scoped to the three round-3 items and the text the revision changed (diff `27b4bf65..185449db`). All three are resolved. Round-3 finding 1: the plan now says the workspace report narrows (un-named project worktrees drop out), names `worktrees/workspace/` from `wt_workspace_base` as the workspace's part (a), records the owner's narrowing of the acceptance bullet (Checkpoint 10:24, "Revise", narrowing accepted), adds the dropped-worktree test, and updates step 3/step 8 text in Approach 7. Round-3 finding 2: step 5 matches only `own=yes` worktrees, with a same-number skill_step case in both sandboxes; for the workspace root `own=yes` is exactly today's `type == "workspace"` set (SKILL.md line 579), so the workspace's step 5 is unchanged. Round-3 finding 3: step 7 offers nothing in a project session for a due design-decision review or research digest, with the reason stated. Adding an `own` field to the `{"worktrees": [...]}` entries breaks neither consumer: step 3 reads fields by name with `jq` (SKILL.md lines 222-231) and step 5 reads `.get("worktrees", [])` in python. The remaining items are wording gaps to settle during implementation, not a further plan round.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one PR, ~8 files, session root only, per the owner (2026-11-09). |
| Issue alignment | Good | Serves, as checked: Goals "Easy to use" and "The long view"; `docs/design.md#documentation-layers`, `docs/design.md#sessions-and-roots`. Workspace acceptance bullet narrowed by the owner and recorded in Approach 1 and Open Questions; suggestion 4 on the edit's wording. |
| File targeting | Good | Unchanged. |
| Consequences | Good | Step 5's own-only match and the step 3/step 8 text are in the Consequences table; suggestions 1-2 pin how step 3 and the helper compute `own`. |
| Principle alignment | Good | "Test what breaks": the dropped-worktree case and the same-number case would each fail without their change; suggestion 3 on how the step 7 case is tested. |
| ADR compliance | Good | 0003, 0016, 0017 as in rounds 2 and 3. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences: step 3 uses `own`] suggestion** — Approach 4 states the rule for step 3 ("a Direction-named worktree of another repository is matched by its `<slug>#N` or `adapter --project` line only, never by a bare `(#N)`") but not the mechanism. Today the bare-number Path 1 test is `[ "$type" = workspace ] && [[ "$p1" == *" $issue "* ]]` (SKILL.md line 352). Say that condition becomes `own == yes`, placed before the "no path (serves a project goal)" branch, so a project root's own type=project worktrees reach Path 1 from a bare `(#N)`. Also pin `own`'s JSON form (string `"yes"`/`"no"`), since both step 3's `jq` and step 5's python compare it.
2. **[Consequences: `own` for a bare-header package worktree] suggestion** — `own=yes` "when its manifest-header slug equals `pr_source`" leaves a package worktree whose header is a bare `issue=<N>` undefined; `worktree_create.sh` (line 311, header written at line 756 via `wt_write_manifest`) writes a bare number when `--issue` is unqualified and the adapter returns several repositories. Step 3 already resolves that case to the slug every listed checkout agrees on (SKILL.md lines 253-256). Use the same derivation for `own` (header slug, else the agreed checkouts' slug, else `own=no`), so such a worktree in the root's own folder does not silently lose its Path 1 and step 5 branch.
3. **[Principle alignment: step 7 test] suggestion** — Step 7 is prose with no block, so "step 7 states the facts and offers nothing, and does not offer `/audit-workspace`" cannot run through the helper/runner list it sits in. Name the check: a text guard in `test_skill_paths.sh` on step 7's project-session sentence (no `/audit-workspace` offer there). Also say the "Offer it otherwise" branch stays for a workspace session with no Agent tool (Codex, agy); the plan's "offers nothing" applies to project sessions only, and `session_type` unknown can no longer occur once `sitrep_root.sh` exits 1 outside every root.
4. **[Issue alignment: the acceptance-bullet edit] suggestion** — The issue's bullet reads "From the workspace root the report is unchanged from today, and the run record's second column stays `workspace`". The host's edit should keep the run-record clause. Bullet 1's "nothing in the report is the workspace's" can also say "except workspace work the project's own Direction lines name", so the same rule for both root types does not contradict it.

### Summary

The third revision resolves all three round-3 findings, and the new `own` field fits both consumers of `--worktrees` without breaking either. The four suggestions are wording and mechanism details the implementer can settle in the PR. The plan is ready for implementation.

### Recommended Actions

- [ ] In step 3, replace the `type = workspace` bare-number condition with `own == yes` (before the project-goal branch); pin `own` as the string `"yes"`/`"no"`
- [ ] Compute `own` for a bare-header package worktree from the slug its checkouts agree on, as step 3 does
- [ ] Test step 7's project-session wording with a text guard in `test_skill_paths.sh`; keep the offer branch for a workspace session with no Agent tool
- [ ] Host: in the issue edit, keep the run-record clause and reconcile bullet 1's "nothing is the workspace's" with Direction-named work

## Checkpoint
**Status**: complete
**When**: 2026-11-09 10:28 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (plan review round 4 approved with no must-fix; the four suggestions are implementation-level and go into the implement handoff; the owner's narrowed acceptance bullet from the previous checkpoint stands)
**After**: plan
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. Suggestions carried to implementation: step 3's bare-number test becomes own == yes before the "serves a project goal" branch, own is the string yes/no; own for a package worktree with a bare issue=<N> header uses the slug its checkouts agree on, else no; step 7's project-session test is a text check in test_skill_paths.sh and the "offer it" branch stays for a workspace session with no Agent tool. The host edits the issue's acceptance bullets when the PR opens: keep "the run record's second column stays workspace", and reconcile "nothing in the report is the workspace's" with workspace work the project's Direction lines name.

## Implementation
**Status**: complete
**When**: 2026-11-09 10:59 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-418 at `278b6ec1`

- New `.agent/scripts/sitrep_root.sh` (read-only): the session's own root from `session_root.sh` (exit non-zero, nothing on stdout, outside every root), `record_name` (`project:workspace` for a project of that name), `roadmap` (`docs/roadmap.md`, else `ROADMAP.md`), `own_repo`, `default_branch`, `pr_source`, and a `check_<name>=run|skipped (<why>)` line per Problems check; `--worktrees [--rows <file>]` keeps the root's own worktrees plus those its Direction lines name, each with `"own": "yes"|"no"` (a bare-header package worktree uses the slug its checkouts agree on), and passes `worktree_list.sh` errors through.
- `.claude/skills/sitrep/SKILL.md`: every step takes its root from the helper; step 3's bare-number Path 1 test is `own == yes`, before the project-goal branch; no Path 2 in a project session; no path word when the Direction section has no Paths paragraph; step 5 matches own worktrees only, titles from `pr_source`, ADR titles from the root; step 6 reads the root's default branch and skips checks its files do not allow; step 7 starts or offers only in a workspace session (offer kept for a workspace session with no Agent tool); run record column 2 is `record_name`; the four "workspace only" sentences replaced.
- Deviation, for veto: step 2 lists a project session's own inbox lines first (matched on the project's registered name, as `capture.sh` writes it), and keeps file order in a workspace session.
- `docs/design.md` (Documentation layers, Measures row, Change log), `docs/roadmap.md` (deferral removed, Decided Against entry quoting the owner, row for #418), `script_reference.md`.
- Tests: new `test_sitrep_root.sh` (31 cases); `test_sitrep_checks.sh` skill-step tests run from their sandbox root, plus project-session section 14; `test_skill_paths.sh` guards. Final `pre-commit run --files` (no SKIP) passed, every suite selected (ALL).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-09 11:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-418 at `f8334fa1`
**Base**: main
**Depth**: Deep (reason: 1687 changed lines, 10 files)
**Must-fix**: 2 | **Suggestions**: 7
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Specialists: static analysis (shellcheck --severity=warning, clean), governance, plan drift, Claude adversarial, cross-model (gemini: complete, 4 findings; codex: complete, 2 findings). Suites re-run: test_sitrep_root 31/31, test_sitrep_checks 205/205, test_skill_paths 130/130.

### Findings
- [x] (must-fix) A non-GitHub scp-style origin (`git@gitlab.com:acme/proj.git`) gives `pr_source=git@gitlab.com:acme/proj` (extract_gh_slug strips nothing without github.com, then the slug regex passes), so step 3/5 run `gh -R` on it, contradicting "not on GitHub: no pull-request source, never a guess"; accept only github.com URLs with an owner/repo slug (helper and its Python gh_slug mirror) and add a non-GitHub-remote test — `.agent/scripts/sitrep_root.sh:154`
- [x] (must-fix) An own=yes package worktree's `branch` is its checkouts' branches comma-joined (worktree_list.sh:301), so step 3's join (`branch` equals `headRefName`) never matches its pull request: it gets a separate line and a false "no pull request yet"; match on the branch of the checkouts belonging to `pr_source` (or any comma element) and test it — `.claude/skills/sitrep/SKILL.md:521`
- [x] (suggestion) With own_repo=yes, docs/design.md present and no default branch, the audit/research/documentation checks report `run` and step 6 prints wrong reasons ("no Decision register ... on the default branch", "docs/design.md has no commit on the default branch"); skip them with "no default branch" in the helper and add a test — `.agent/scripts/sitrep_root.sh:186`
- [x] (suggestion) origin/HEAD is trusted when its target has no local branch, so a dangling origin/HEAD gives a default branch every step-6 read fails on, even when exactly one of main/master exists; require refs/heads/<name> or fall through — `.agent/scripts/sitrep_root.sh:143`
- [x] (suggestion) (b) references are found by substring over the check text, not by the runner's check grammar (a `file-contains ... gh-issue acme/other#12` argument keeps that worktree); same approach as step 3's existing Path-1 extraction, so fix both together or anchor to a check boundary — `.agent/scripts/sitrep_root.sh:250`
- [x] (suggestion) Slug comparisons are case-sensitive (`Acme/Proj` vs `acme/proj`) in (b) matching, `own`, and step 3's Path 1; GitHub names are not — `.agent/scripts/sitrep_root.sh:304`
- [x] (suggestion) Project-first inbox listing: the `--- other lines` divider counts toward `head -n 20`, and with exactly 19 own lines it is printed with nothing under it — `.claude/skills/sitrep/SKILL.md:207`
- [x] (suggestion) session_root.sh exit 2 (malformed registry) is passed through but every skill block says "outside every root"; the header's exit list omits it — `.agent/scripts/sitrep_root.sh:124`
- [x] (suggestion) Header says the helper writes nothing, but `--worktrees` creates and removes a mktemp file; reword or capture stderr without a file, and no test asserts read-only behaviour — `.agent/scripts/sitrep_root.sh:211`

## Implementation
**Status**: complete
**When**: 2026-11-09 11:28 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-418 at `7b7a0dbd`
**Addressed**: Local Review (Pre-Push) at `f8334fa1` (2026-11-09 11:03 -05:00)
**Commits**: 5fb57961, 7b7a0dbd

### Actions
- [x] (must-fix) Non-GitHub origin gave a bogus pull-request source: the helper's one Python definition (used for pr_source and every worktree) accepts only a github.com URL in git's forms (https, ssh://, git://, scp-like; optional user, port, .git), read through `git ls-remote --get-url` so insteadOf applies; anything else (another host, a lookalike host, a path, an ssh alias) is none. No gh call added: the helper runs once per skill block and must work offline, and the gh-decides route would add a network call to each. Tests: a gitlab.com root, 18 URL forms, an insteadOf shorthand, a package worktree with gitlab checkouts. Step 3 no longer parses remotes itself; it reads the helper's `repository` — `.agent/scripts/sitrep_root.sh`
- [x] (must-fix) A package worktree never joined its pull request: the helper adds `pr_branch` (a plain worktree's branch; a package worktree's branch of its repository's checkouts, from its manifest, when they name one), and step 3's join rule uses it; tested on plain, package and not-own entries — `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion) No default branch with docs/design.md present: the three checks that read it say `skipped (no default branch)`; tested — `.agent/scripts/sitrep_root.sh`
- [x] (suggestion) origin/HEAD counts only when its branch exists locally, else the main/master rule; tested with a remote-only develop — `.agent/scripts/sitrep_root.sh`
- [x] (suggestion) Direction checks read by the runner's grammar (cell split at ` ; `, backticks unwrapped, whole three-word gh-issue with open/closed, five-word adapter form): in the helper's (b) and its new `named` field, which replaces step 3's substring Path 1 extraction; step 5's bare gh-issue numbers use the same split. Tests in both suites — `.agent/scripts/sitrep_root.sh`, `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion) Repository names compare without regard to case in (b), `own`, `named`, and step 5's closing-reference match; tested — `.agent/scripts/sitrep_root.sh`, `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion) Inbox listing: 20 lines not counting the `--- other lines` marker, printed only with a line under it; tests for 19 and 20 own lines — `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion) session_root.sh exit 2: the helper says "could not be decided (exit 2)" rather than "in no root", the header lists exit 2, and the skill's blocks say "no root could be decided for this directory"; tested with a malformed registry — `.agent/scripts/sitrep_root.sh`
- [x] (suggestion) No temporary file: worktree_list.sh's stderr goes straight through; a test runs both modes with an empty TMPDIR and checks it stays empty and git status is unchanged (the old file was removed on exit too, so the test guards the property; it did not catch the old code) — `.agent/scripts/sitrep_root.sh`

### Verification
- `pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: every hook passed, the script suite (validate-script-tests) included.
- Run directly before committing: test_sitrep_root.sh 46 passed (13 of the new checks fail on the pre-fix helper), test_sitrep_checks.sh 209 passed, test_skill_paths.sh 130 passed.
- Two commits rather than one per finding: the helper rewrite carries several findings at once, and the skill commit depends on its new fields.
- Not changed: `extract_gh_slug` in _issue_helpers.sh still accepts any host. sitrep_checks.sh's `gh-issue N` (and other scripts) use it, so a bare gh-issue check in a non-GitHub root makes a gh call that fails and reads `unknown`, not a wrong answer. Widening the fix to the shared helper is outside this finding.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-09 11:33 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent af2d5f3d256c954bd, resume 1 of 3)

**Branch**: feature/issue-418 at `7f198a74`
**Base**: main
**Depth**: Deep (reason: whole-branch diff over 200 lines and 10 files; fix round re-classified on the whole diff)
**Must-fix**: 0 | **Suggestions**: 7
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round-1 must-fixes verified closed: non-GitHub origin gives pr_source=none (gitlab root and 18-form URL table in test_sitrep_root.sh; regex probed by hand, lookalike hosts rejected); package worktrees join on pr_branch (test_sitrep_root.sh:329). All 7 round-1 suggestions checked as addressed.

Host-test vs gh (owner rule of 2026-10-30): a bounded, tested allowlist, not the smell. Its input is git's own resolved URL (`ls-remote --get-url`, insteadOf applied, no network), it accepts four of git's URL forms for one host, and every miss fails closed to "none", never a wrong repository; it replaces the looser shared extract_gh_slug rather than adding a parser, and per-worktree lookups need it offline. Residual cost: a GitHub origin behind an ssh host alias, www., or an https port reads "no pull-request source" (see suggestion). Listed for veto.

Specialists: static analysis (shellcheck --severity=warning, clean), governance, plan drift, Claude adversarial (fresh, no must-fix), cross-model (gemini: complete, no issues; codex: complete, 2 must-fix claims downgraded to suggestions after verification, 1 suggestion). Suites re-run: test_sitrep_root 46/46, test_sitrep_checks 209/209, test_skill_paths 130/130.

### Findings
- [x] (suggestion) The helper decides the root from the main checkout's registry but runs its own copy's worktree_list.sh, whose registry is script-relative; from a feature-worktree copy (no user tier, $WS_ROOT = cwd) Direction-named project worktrees drop out silently. Same fallback lost them on main, and the user-tier path is unaffected; pass the resolved workspace root through or call the main checkout's lister (Codex, verified worktree_list.sh:21) — `.agent/scripts/sitrep_root.sh:327`
- [x] (suggestion) History checks gate on the file in the working tree, not on the default branch: a root checkout on an older branch (common in projects that do not use worktrees) reports "docs/design.md not in this root" while main has it; test with `git cat-file -e "$DB:<file>"` (Codex) — `.agent/scripts/sitrep_root.sh:281`
- [x] (suggestion) A pull-request-only branch still gets "Path 1" / "path unknown" when the root's Direction section has no Paths paragraph; apply the no-Paths rule there too (Codex) — `.claude/skills/sitrep/SKILL.md:1116`
- [x] (suggestion) An origin that exists but is not a recognised github.com URL (ssh host alias, www., https port) reads "no pull-request source for this root"; say the origin was not recognised as GitHub so the reason is visible — `.agent/scripts/sitrep_root.sh:201`
- [x] (suggestion) Header says repository_dirs is empty when repository is "", but a plain worktree with no GitHub remote gets [path]; fix the header or the code (Claude adversarial) — `.agent/scripts/sitrep_root.sh:375`
- [x] (suggestion) Step 5's branch row prints the comma-joined `branch` for an own package worktree; print `pr_branch` (Claude adversarial) — `.claude/skills/sitrep/SKILL.md:666`
- [x] (suggestion) No test feeds the same cells to names_of and sitrep_checks.sh, so grammar drift goes unnoticed (Python strip/split also treat NBSP and \r as spaces, bash does not); add a parity case and a disagreeing-branch package fixture (Claude adversarial) — `.agent/scripts/tests/test_sitrep_root.sh:215`

## Checkpoint
**Status**: complete
**When**: 2026-11-09 11:34 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (round 2 approved with 7 suggestions; two of them are failure modes the quality standard says not to dismiss: project work named by Direction lines drops out silently when the helper's worktree_list.sh copy reads a different registry than the root decision, and the history checks report a file "not in this root" from the working tree of an older branch when the default branch has it; both have one-line fixes, so one fix pass and a narrow round-3 convergence check cost less than publishing them)
**After**: publish
**Decision**: address

Host answer under /orchestrator's checkpoint table. Fix pass to take the 7 suggestions of the round-2 Local Review (Pre-Push) at 4fff0169; round 3 is a narrow convergence check with no cross-model reviewers.

## Implementation
**Status**: complete
**When**: 2026-11-09 11:52 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a9e55aba568895538, resume 1 of 3)

**Branch**: feature/issue-418 at `f1208634`
**Addressed**: Local Review (Pre-Push) at `7f198a74` (2026-11-09 11:33 -05:00)
**Commits**: 4746ce3e, f1208634

### Actions
- [x] (suggestion) Two registries: --worktrees now runs the main checkout's worktree_list.sh (the copy next to the registry the root was decided from), falling back to its own copy only when the main checkout has none; test runs a worktree copy of the helper and gets the same Direction-named project worktrees (fails on the old code) — `.agent/scripts/sitrep_root.sh`
- [x] (suggestion) History checks go by `git cat-file -e "<default branch>:<file>"`: a root on an older branch is still checked; a file only in the working tree reads "not on the default branch <name>"; tests for both — `.agent/scripts/sitrep_root.sh`
- [x] (suggestion) A pull-request-only branch gets no path word when the Direction section has no Paths paragraph, like every other line; the text test updated — `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion) New `pr_source_why`: "this root is not a git repository of its own", "no origin remote" or "origin not recognised as GitHub" (the URL is never printed, since it can hold a credential); step 3 prints it after "no pull-request source for this root"; tests in both suites — `.agent/scripts/sitrep_root.sh`, `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion) Header fixed to match the code: a plain worktree's `repository_dirs` is always its own path (its timeline is read there with no GitHub remote too) — `.agent/scripts/sitrep_root.sh`
- [x] (suggestion) Step 5's branch row prints `pr_branch` (the joined `branch` only when that is empty); skill test with an own package worktree — `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion) Parity test: 15 cells (NBSP inside and after a check, backticks, ` ; `, case, leading zeros, extra words, malformed states, adapter forms) go through sitrep_checks.sh (stub gh and adapter record what is asked) and through names_of; the two lists must match. It found the drift: names_of now trims ASCII space only and splits on space/tab/newline, as bash's trim and read -ra do, and the item regex is ASCII-only. A package fixture whose checkouts disagree on the branch gives an empty pr_branch — `.agent/scripts/tests/test_sitrep_root.sh`

### Verification
- `pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: exit 0, every hook passed or skipped (none failed), the script suite included.
- Run directly: test_sitrep_root.sh 52 passed (the registry and parity tests fail when the old code is put back), test_sitrep_checks.sh 210 passed, test_skill_paths.sh 130 passed.
- Two commits (helper, then skill), as in round 1: the helper commit carries several findings at once.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-09 11:55 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent af2d5f3d256c954bd, resume 2 of 3)

**Branch**: feature/issue-418 at `248bb076`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: the round-2 entry's 7 suggestions and the fix diff 4746ce3e (helper) and f1208634 (skill). Each closes its finding: one registry for root and listing (main checkout's worktree_list.sh, own copy only as fallback; worktree-copy test); history checks by `git cat-file -e` on the default branch (older-branch and working-tree-only tests); no path word for a pull-request-only branch without Paths; `pr_source_why` names the reason without printing the URL; header for repository_dirs matches the code; step 5 prints pr_branch; parity test of names_of against sitrep_checks.sh (NBSP drift fixed: ASCII trim and space/tab/newline split) plus a disagreeing-branch package fixture. No new defect found. Specialists: static analysis (shellcheck --severity=warning, clean), governance and plan drift inline; cross-model skipped (round-3 convergence check, per handoff); Claude adversarial not spawned (optional this round; fix diff small and read in full). Suites re-run: test_sitrep_root 52/52, test_sitrep_checks 210/210, test_skill_paths 130/130.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 11:55 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (round 3 convergence check approved with 0 must-fix and 0 suggestions; Ship recommended)
**After**: publish
**Decision**: publish

Host answer under /orchestrator's checkpoint table. Push and open the pull request; the host edits the issue's acceptance bullets to the owner's narrowed wording (checkpoint of the third plan review).

## Integrated Review
**Status**: complete
**When**: 2026-11-09 12:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #420 at `e9fa0ef5`
**Sources**: 3 (Copilot R1 @ `e9fa0ef5` (1 review, 2 inline comments); Local Review (Pre-Push) round 3 @ `248bb076` (covers `e9fa0ef5` via bookkeeping), no open findings (its "No issues found" box is a placeholder, not a finding); CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

Prior timeline: round 1 (2 must-fix) and round 2 (7 suggestions) were closed by their Implementation entries and confirmed by round 3; nothing carried forward. Neither Copilot finding was raised locally (Gemini and Codex ran in rounds 1 and 2): both sit in paths the local rounds did not exercise (a parent-root selector; a `section` row other than missing roadmap / no Direction section). CI: Lint (pre-commit) still running at triage time; Validate Adapter Contract, Validate Documentation, ros-manifest tests and the Copilot run pass.

### Findings
- [x] (should-fix, Copilot) A Direction check `script adapter --project <parent> validate` names nothing: `adapter` resolves a parent root to its default or only instance (`.agent/scripts/adapter`, parent block after discovery; `registry_default_instance`), but worktree_list.sh scans only non-parent roots, so every project worktree's `repo` is the instance name and the parent never matches, neither in part (b) keeping (line 473) nor in `named` (line 497). Work the check actually names is dropped from the sit-rep or marked un-named. Fix: before the Python pass, map each named project through the registry as `registry_resolve_project_arg` does (parent -> default/only instance; a parent with several instances and no default names nothing, since `adapter` fails on it), use the resolved names in both places, update the header (`adapter --project <name>` lines in the --worktrees description) and SKILL.md step 3's wording at line 234, and add a test with the existing `host`/`inst` fixture: rows naming `script adapter --project host validate` keep an `inst` worktree from the workspace root with `named` yes (fails on the current code) — `.agent/scripts/sitrep_root.sh`
- [x] (should-fix, Copilot) The project-session rule for `section` rows reads as blanket: the parenthetical "(no roadmap, or a roadmap with no Direction section)" looks explanatory, and the paragraph above lists four `section` reasons. Applied to `(roadmap not readable: ...)` it reports "no Direction section; onboarding offers one", which is false; applied to `(no Line or Deferral table)` / `(no rows in the Line or Deferral tables)` it suppresses the acceptance case and Paths, which come from the Direction section's prose that does exist (SKILL.md steps 3 and 5). Fix: name the rows the rule applies to (`(roadmap not found: ...)` and `(no Direction section)`) explicitly; for the unreadable roadmap report the reason as printed, with no onboarding offer; for a section with no tables or no rows say so and still report the acceptance case and Paths from the section prose, with no next step; add a skill-text assertion in test_skill_paths.sh pinning the restriction — `.claude/skills/sitrep/SKILL.md`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-09 12:05 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (two valid Copilot findings, both should-fix with a known fix: a parent root named by an adapter check resolves to no worktree, and the project-session rule for section rows misreports an unreadable roadmap; a review with open findings is never merged past without the owner, and the fixes are small, so address)
**After**: findings
**Decision**: address

Host answer under /orchestrator's checkpoint table. The two open boxes of the Integrated Review at 5a362625 go to address-findings; then a PR-mode review-code and a re-triage.

## Implementation
**Status**: complete
**When**: 2026-11-09 12:22 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a9e55aba568895538, resume 2 of 3)

**PR**: #420 at `423f644d`
**Addressed**: Integrated Review at `e9fa0ef5` (2026-11-09 12:05 -05:00)
**Commits**: c5664111, 423f644d

### Actions
- [x] (should-fix, Copilot) An adapter check naming a parent root named nothing: before the Python pass, each project an `adapter --project <name>` check names goes through `registry_resolve_project_arg` (a parent becomes its default or only instance, the name worktree_list.sh gives its worktrees; a parent with several instances and no default is dropped, as the adapter fails on it), and both the keep rule (b) and `named` use the resolved names. Header and skill step 3 updated. Test with the host/inst fixture (one instance: kept, named yes; fails on the previous code) and a new two-instance parent with no default (names nothing) — `.agent/scripts/sitrep_root.sh`
- [x] (should-fix, Copilot) Step 1's project-session rule now names the two section rows it covers, `(roadmap not found: ...)` and `(no Direction section)`. `(roadmap not readable: ...)` gives its reason as printed with no onboarding offer. `(no Line or Deferral table)` and `(no rows in the Line or Deferral tables)` have no next step but still report the acceptance case and Paths from the section's prose. test_skill_paths.sh pins the restriction and fails if the blanket wording comes back — `.claude/skills/sitrep/SKILL.md`

### Verification
- `pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: exit 0, no hook failed; the script suite hook passed.
- Run directly: test_sitrep_root.sh 54 passed, test_sitrep_checks.sh 210 passed, test_skill_paths.sh 131 passed.

## Local Review
**Status**: complete
**When**: 2026-11-09 12:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent af2d5f3d256c954bd, resume 3 of 3)

**PR**: #420 at `3b19d5f4`
**Depth**: Deep (reason: convergence check of the Copilot fix round per handoff)
**Must-fix**: 0 | **Suggestions**: 0

Scope: the two should-fix boxes of the Integrated Review at 5a362625 and the fix diff since it, c5664111 (helper) and 423f644d (skill). (1) Adapter-check project names go through registry_resolve_project_arg before the Python pass (parent -> default or only instance; several instances and no default -> dropped; an unregistered name stays itself), and both the (b) keep rule and `named` use the resolved set; tests with the host/inst fixture and a two-instance parent pass. (2) Step 1's project-session rule names only `(roadmap not found: ...)` and `(no Direction section)`; an unreadable roadmap reports its reason with no offer; a section with no tables or rows keeps its acceptance case and Paths with no next step; test_skill_paths pins it and rejects the old blanket wording. No new defect found. Specialists: static analysis (shellcheck --severity=warning, clean), governance and plan drift inline; cross-model skipped (convergence round, per handoff); Claude adversarial not spawned (fix diff small, read in full). Suites re-run: test_sitrep_root 54/54, test_sitrep_checks 210/210, test_skill_paths 131/131.

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-11-09 12:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent abd723cbf6dcc08ad, resume 1 of 3)

**PR**: #420 at `4ca61ada`
**Sources**: 3 (Copilot R2 @ `3b19d5f4` (covers `4ca61ada` via bookkeeping; overview body, no inline comments, one "previously missed issue"); Local Review @ `3b19d5f4` (covers `4ca61ada` via bookkeeping), 0 findings (its "No issues found" box is a placeholder, not a finding); CI rollup). Copilot's 17:29 review at `4ca61ada` is a quota notice, not a source.
**Cross-source confirmations**: 0
**CI**: all-pass

Earlier boxes: both should-fix findings of the Integrated Review at `e9fa0ef5` are closed by c5664111 (adapter check names resolved through `registry_resolve_project_arg`, PROJECT_MAP used in keep rule (b) and `named`) and 423f644d (SKILL.md step 1 names only the two missing-section rows); Copilot R2 lists both as resolved; re-run here: test_sitrep_root 54/54, test_skill_paths 131/131. CI on `4ca61ada`: Lint (pre-commit), Validate Adapter Contract, Validate Documentation and ros-manifest tests pass; the `copilot-pull-request-reviewer` run reads failure because of the quota notice, which is not a code check.

### Findings
- [ ] (should-fix, Copilot) `--worktrees` runs the main checkout's worktree_list.sh from `$DIR` (`cd "$DIR" && bash "$WL" --json`). That lister's user-tier guard, `registry_require_root "$ROOT_DIR"`, checks `$PWD` and refuses anything neither inside the main checkout nor under a registered project root. A workspace session in a linked worktree outside the main checkout's tree is a supported session (session_root.sh decides it is the workspace's, test_session_root.sh "a linked worktree of the workspace outside its tree"), so sitrep_root decides the root and then `--worktrees` exits non-zero: the sit-rep cannot list work in flight there. Loud, not silent, but a real failure of a supported case. worktree_list.sh `cd`s to its own ROOT_DIR right after the guard, so `$PWD` matters only to the guard, and the validated `$ROOT` always passes it (the main checkout for a workspace root, a registered root for a project). Fix: run the lister from `$ROOT` (`cd "$ROOT" && bash "$WL" --json`), say why in the comment above it, and add a test in test_sitrep_root.sh: a linked worktree of the sandbox workspace created outside its tree, `--worktrees` from there exits 0 and lists the workspace's worktrees (fails on the current code) — `.agent/scripts/sitrep_root.sh`

### False positives
