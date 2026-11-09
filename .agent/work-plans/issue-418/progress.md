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
