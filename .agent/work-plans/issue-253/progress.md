---
issue: 253
---

# Issue #253 — ros2_agent_workspace parity audit: classify remaining ADRs, skills, scripts for port/adapter/decline

## Issue Review
**Status**: complete
**When**: 2026-11-10 12:04 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #253

### Scope Assessment

**Well-scoped?** No, not as one pass — the issue was written 2026-09-15 and its snapshot is stale in both directions (see Recommendations). The task itself (a finite, classified list) is right; it should be split into three parallel passes and given a different output shape.
**Right repo?** Yes — the audit is a workspace record. It may name the fork and project11 (a record, not mechanism: `docs/principles.md#put-each-thing-at-the-level-it-applies-to`, ADR-0003 applies to scripts, skills and tests, not to this document).
**Serves**: Flexibility and Trust, control and information (README `#workspace-goals`) — `docs/design.md#registry-and-adapters` and `docs/roadmap.md` "Cutover sequence" row 4 (this issue, "planned"). Direction (`docs/roadmap.md`, Path 1) does not name #253, so the sit-rep does not list it today; the audit changes that only if the owner adds a line.
**Design picture?** No change to `docs/design.md` expected. The result is a record. One open point: design.md names no home for a parity record; the roadmap row 4 and this issue's own deliverable (the existing fork digest) do.
**Dependencies**: Reads against the fork checkout `/home/roland/project11` (remote `rolker/ros2_agent_workspace`; last commit 2026-09-25, `323306a8`, the same SHA the 2026-09-29 digest recorded). Read only; the checkout was not fetched, so anything the fork gained after 2026-09-25 on origin is unseen. Feeds #260, #261, #262 (all gated on this row); touches #208/#209, #172, #429, #430. Does not wait for any of them.

### What is stale in the issue's snapshot (checked against this tree and the fork checkout, 2026-11-10)

- **ADR numbers collide, they do not "lack".** Fork 0012 = our 0008 (cross-reference addenda); fork 0013 = our 0013 (progress entry vocabulary), done; fork 0015 (dispatch handoff) is replaced by our 0014 (in-process phase handoff) and 0015 (parallel sync review); fork 0019 (container contents) is replaced by declining containers. The snapshot also never listed fork 0008 (follow ROS 2 conventions), 0010 (adopt git-bug, ours 0010 makes it optional) and 0017 (extend AGENTS.md to project repos). Really open: fork 0011 field mode and 0014 deployment mode (#208/#209, not started: no `field_mode.sh` here), 0016 runtime-vs-baked layers (container/ROS), 0018 local-first CI (`ci_local.sh` absent; roadmap Deferred `local-ci-attestation-verb`).
- **Skills.** `address-findings` and `run-issue` are here (the review loop, #269, plus triage-reviews, review-plan, the merge gate). Still absent: `import-field-changes`, `start-deployment`, `wrap-up-deployment` (field mode), `janitor-sweep` (roadmapped 2026-09-14, not issued), `document-package` (ours is the generic `document-project`; the ROS parts are adapter content). Fork `make_*` slash commands are generated from `.PHONY` here by `generate_make_skills.sh`.
- **Scripts.** `progress_append.sh`, `progress_read.py`, `pr_status.sh`, `merge_pr.sh`, `dashboard.sh`, cross-model review scripts, `revert_feature.sh`, locks, worktree scripts exist here. Ours has things the fork lacks: `dispatch_phase.sh`, `review_progress.sh`, `session_root.sh`, `register_project.sh`, `sitrep_*`, `user_tier_install.sh`, `capture.sh`, adapter scripts. Still only in the fork: ROS layer/rosdep/build-report scripts (`setup*.sh`, `stage_rosdep_manifests.sh`, `rosdep_*`, `sync_repos.py`, `validate_repos.py`, `list_overlay_repos.py`, `build_report_generator.py`, `manifest_fallback.sh`, `resolve_repo_checkout.sh`); field mode (`field_mode.sh`, `add/pull/push_remote.py`, `dlog.sh`, `redact.sh`, tests); container dispatch (`dispatch_subagent.sh`, `docker_run_agent.sh`, `tmux_app.sh`); `local_review.sh`, `ci_local.sh`, `verify_change.sh`, `planning_doc_probe.sh`, `read_feature_status.py`, `gitbug_helpers.sh`, `get_repo_info.py`. About 35 stands, but the fork's 2026-09-29 digest round (`.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`, 923 lines) already classified part of it A/P/R/O and filed #363 to #367.
- **Categories the issue never looked at**: the fork's hooks (`check_pr_authors.py`, `check_question_context.py`, `check-source-artifacts.py`, `identity_patterns.py`, `post-checkout`; we have 3 of 8); templates (`ci_workflow.yml`, `pre-commit-config.yaml`, `deployment_config.yaml`, `roadmap.md`, `package_documentation.md`, `project_agents_md.md`); `.agent/tools/dashboard`; ROS and field knowledge files (`ros2_cli_best_practices.md`, `ros2_development_patterns.md`, `gazebo_ros_launch_patterns.md`, `launch_tooling.md`, `bag_analysis.md`, `diagnosis_discipline.md`, `dependency_policy.md`, `deployment_mode.md`, `field_mode_hotfix.md`); 145 work-plan folders and `work-artifacts`; `docs/health.md`; `presentations/`; and 39 entries under `layers/worktrees/` (in-flight issue worktrees, which need finishing or moving before #262). Also `configs/manifest` and `layers/main/*`, which belong to project11's manifest and package repositories, not to either workspace.
- **What this workspace built since the issue**: package worktrees (#252 closed), the review loop (#269), project-rooted sessions and the user tier (ADR-0016), hosted-project registry and `adapter` verbs (ADR-0011/0012), the orchestrator, onboarding (#332, closed), the sit-rep (#386, #418), the plugin delivery (ADR-0018), the manifest resolver prototype (#267). Items the issue lists as "adapter-scoped, link step 6" are now mostly the `ros2_colcon` adapter and #429/#430.
- **The fork's Divergence policy** ("inspiration-tracker every two weeks") is overtaken: the digest records upstream improvements are winding down and flows ran from here to the fork in the last round.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | Action needed | The deliverable must be a finite list the owner can use, not another long digest: one table, one row per item, each classified, with day-to-day blockers separated from retirement-only items. The fork digest is already 923 lines; the audit table must not be appended there. |
| Keep one current design | OK | No design change. Result is a record; if the owner accepts decisions (for example declining containers for good), record them in `docs/roadmap.md` "Decided Against", which already holds the pattern. |
| Verify before claiming | Action needed | Every row must cite the fork path and, for "already covered", the file or issue here that covers it, checked in this tree on the audit date (as the 2026-09-29 digest did). Mark the fork checkout's date and that origin was not fetched. |
| Put each thing at the level it applies to | Watch | Mechanism text names no project; this record may name the fork and project11. Fork project layers and manifests classify as "belongs to a project repository" (unh_marine_autonomy / project11 manifest), not as workspace work. |
| Ask about what matters, and show how much | Watch | Classification is made by the agent from the principles; the owner sees only the blocker list and the decline list for veto. |
| Leave a trail; start limits strict | OK | Per-row classification plus a parked section for items waiting on a condition. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0003 (workspace infrastructure is project-agnostic) | Yes | Applies to any port from the fork; the audit record may name projects. |
| ADR-0011 / ADR-0012 (adapter contract, worktree composition) | Yes | "Adapter" rows land under `.agent/project_types/ros2_colcon/` and in #429. |
| ADR-0016 (session roots, user tier) | Yes | Several fork items are obsolete under project-rooted sessions (`workspace_root.sh`, `layers/` guessing). |
| ADR-0013 (progress entry vocabulary) | Yes | This entry; the audit's own run appears as ordinary timeline entries. |
| ADR-0015 (parallel sync review) and 0014 (in-process handoff) | Yes | Basis for declining fork `dispatch_subagent.sh`, `docker_run_agent.sh`, ADR-0015/0019 (fork numbering). |
| ADR-0018 (plugin delivery) | Watch | Fork hooks have a home question under the plugin. |

### Consequences

- Cutover row 4 in `docs/roadmap.md` changes status when the audit lands; update through `update_roadmap.sh`.
- #260, #261, #262 start from the audit's list; #262's checklist ("Update inspiration-tracker…") should point at it.
- #253's old "ROADMAP.md updated so the #172 section lists what still stands" now means the Cutover sequence and Direction sections.

### Recommendations

- Rewrite the scope of #253 (by comment, body unchanged): audit against the fork checkout `/home/roland/project11` with the stale snapshot replaced by the counts and categories above; keep the old digest as input, not as the deliverable.
- Output: one document in this repository, `docs/fork_parity.md` (a record, named for what it is, linked from `docs/roadmap.md` row 4 and from `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`), holding a single table with columns Item, Fork path, Class, Day-to-day blocker?, Covered by / issue. Classes: port, adapter, decline, already covered, belongs to a project repository. Two lists on top, each at most about 10 lines: "Blocks developing project11 here day to day" and "Blocks only retiring the fork". No per-item prose beyond one line. Quote at the top, from `docs/roadmap.md`, the Cutover sequence row 4 and the Direction acceptance case, so the document shows what it serves.
- Proposed issues are listed in the document and in the owner's hand-back; the audit opens none. Opening them is the owner's call (accepted → one `gh` batch by the owner or on his say).
- Split into three passes that run in parallel (each reads the fork read only and writes its own table section; one agent merges): (1) scripts, hooks, templates, tools and tests; (2) ADRs, skills and the knowledge files; (3) the fork's project-specific layers (`configs/manifest`, `layers/`, `presentations/`, `docs/health.md`, work-plans and work-artifacts, in-flight `layers/worktrees/*`). Pass 3 is the one most likely to find retirement-only work (in-flight worktrees; unpushed branches).
- Split blockers from retire-only while classifying: probable day-to-day blockers to confirm in pass 1 and 2 are the ROS knowledge files (no home yet in this tree; agent sessions at the project root need them, via the adapter or the project's own `.agents`), the rosdep and layer-build scripts the `ros2_colcon` adapter lacks (R1/R2 in the digest), `sync_repos`/`validate_repos` equivalents (#267 resolver), `document-package` content, and anything #429 or #430 turns up on the second machine. Field mode (#208/#209), deployment skills and `janitor-sweep` are the probable retire-only items.
- Fold in, do not redo: #260 (fork open issues; reuses the audit's table to bucket issues), #261 (fork memories), #262 (cutover checklist), #208/#209 (field mode rows point at them), #172 (parent), #429 (run-issue on package repositories, in implementation) and #430 (second machine install) as the evidence source for the blocker list, #363 to #367 (already filed from the 2026-09-29 round, rows say "filed").
- Before the audit starts, ask the owner whether the fork checkout may be fetched read-only (`git fetch` writes into the checkout, so it was not done) or whether `git ls-remote` against origin is enough to learn whether it moved after 2026-09-25; the audit otherwise says "as of 2026-09-25".

### Actions
- [ ] The deliverable must be a finite list the owner can use, not another long digest: one table, one row per item, each classified, with day-to-day blockers separated from retirement-only items. The fork digest is already 923 lines; the audit table must not be appended there.
- [ ] Every row must cite the fork path and, for "already covered", the file or issue here that covers it, checked in this tree on the audit date (as the 2026-09-29 digest did). Mark the fork checkout's date and that origin was not fetched.
- [ ] Rewrite the scope of #253 (by comment, body unchanged): audit against the fork checkout `/home/roland/project11` with the stale snapshot replaced by the counts and categories above; keep the old digest as input, not as the deliverable.
- [ ] Output: one document in this repository, `docs/fork_parity.md` (a record, named for what it is, linked from `docs/roadmap.md` row 4 and from `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`), holding a single table with columns Item, Fork path, Class, Day-to-day blocker?, Covered by / issue. Classes: port, adapter, decline, already covered, belongs to a project repository. Two lists on top, each at most about 10 lines: "Blocks developing project11 here day to day" and "Blocks only retiring the fork". No per-item prose beyond one line. Quote at the top, from `docs/roadmap.md`, the Cutover sequence row 4 and the Direction acceptance case, so the document shows what it serves.
- [ ] Proposed issues are listed in the document and in the owner's hand-back; the audit opens none. Opening them is the owner's call (accepted → one `gh` batch by the owner or on his say).
- [ ] Split into three passes that run in parallel (each reads the fork read only and writes its own table section; one agent merges): (1) scripts, hooks, templates, tools and tests; (2) ADRs, skills and the knowledge files; (3) the fork's project-specific layers (`configs/manifest`, `layers/`, `presentations/`, `docs/health.md`, work-plans and work-artifacts, in-flight `layers/worktrees/*`). Pass 3 is the one most likely to find retirement-only work (in-flight worktrees; unpushed branches).
- [ ] Split blockers from retire-only while classifying: probable day-to-day blockers to confirm in pass 1 and 2 are the ROS knowledge files (no home yet in this tree; agent sessions at the project root need them, via the adapter or the project's own `.agents`), the rosdep and layer-build scripts the `ros2_colcon` adapter lacks (R1/R2 in the digest), `sync_repos`/`validate_repos` equivalents (#267 resolver), `document-package` content, and anything #429 or #430 turns up on the second machine. Field mode (#208/#209), deployment skills and `janitor-sweep` are the probable retire-only items.
- [ ] Fold in, do not redo: #260 (fork open issues; reuses the audit's table to bucket issues), #261 (fork memories), #262 (cutover checklist), #208/#209 (field mode rows point at them), #172 (parent), #429 (run-issue on package repositories, in implementation) and #430 (second machine install) as the evidence source for the blocker list, #363 to #367 (already filed from the 2026-09-29 round, rows say "filed").
- [ ] Before the audit starts, ask the owner whether the fork checkout may be fetched read-only (`git fetch` writes into the checkout, so it was not done) or whether `git ls-remote` against origin is enough to learn whether it moved after 2026-09-25; the audit otherwise says "as of 2026-09-25".

## Checkpoint
**Status**: complete
**When**: 2026-11-10 15:05 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review keeps the issue's aim and changes only how the audit is done and what it produces, which is mechanism; the owner asked for the audit on 2026-11-10 to answer "How ready is the workspace to take over the duties of ros_agent_workspace?")
**After**: issue-actions
**Decision**: proceed

Host read the Issue Review of 2026-11-10 and accepts its actions as plan inputs: one record, `docs/fork_parity.md`, with a classified table and two short lists on top (what blocks developing project11 here; what blocks only retiring the fork); three parallel read-only passes merged by one agent; the audit proposes issues and opens none; issues 260, 261, 262, 208, 209, 172 and 363 to 367 are folded in by reference. The review's two questions are answered by the host: the fork's remote `main` is checked with `git ls-remote` (read-only) against the checkout, never fetched into; the Direction section is not changed for this issue, since the sit-rep already lists its worktree as work in flight.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 12:06 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-253/plan.md` at `1b953c94`

One record, docs/fork_parity.md, from three parallel read-only passes over the fork checkout (inventory fixed from git ls-files first, "already covered" verified by opening the file here), merged by one agent, checked by a path and issue-number script; the audit proposes issues and opens none.

## Plan Review
**Status**: complete
**When**: 2026-11-10 12:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #253 — ros2_agent_workspace parity audit: classify remaining ADRs, skills, scripts for port/adapter/decline
**Plan**: `.agent/work-plans/issue-253/plan.md` at `1b953c94`
**Branch**: `feature/issue-253`

Fork checkout read for this review only with `ls`, `cat`, `git --no-optional-locks` (`ls-files`, `branch -vv`, `worktree list`, `stash list`) and read-only `gh` list calls against the fork's GitHub repository; nothing written, fetched or run there.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One record, three passes and a merge, no code; one PR. |
| Issue alignment | Needs work | Serves line, as checked: "Flexibility and Trust, control and information (README `#workspace-goals`); `docs/design.md#registry-and-adapters`; roadmap Cutover sequence row 4." Follows the Issue Review and Checkpoint. Missing: the roadmap row 4 requirement "Closed-since-fork issues are accounted for here, as features" (finding 2); the issue body's "decline ... recorded in Decided Against" is not mentioned (finding 8). |
| File targeting | Needs work | Output files right. The inventory (the audit's real "file targeting") leaves tracked and untracked fork paths in no pass and misses duties that are not files (finding 2). |
| Consequences | Needs work | Step 7 relies on `update_roadmap.sh` to set an "in review" status; the script only sets `done`, and `merge_pr.sh` already runs it at merge (finding 7). |
| Principle alignment | Needs work | "Verify before claiming": "already covered" from reading only this tree's file misses fork-only behaviour in same-name files (finding 3). "Ask about what matters": list A has no shared test, so passes will disagree (finding 4). |
| ADR compliance | Good | ADR-0003, 0011/0012, 0013, 0014/0015, 0016, 0018 named with how each is met; read-only rule for the other root stated in every pass. |
| ROS conventions | N/A | Workspace record; no ROS code. |

### Findings

1. **[Approach, must-fix]** Steps 1, 4 and 6 (and the overlap assignment in step 1) are given to "the host". In this loop no host does phase work: the one implementing agent builds the inventories, gathers the #429/#430 evidence, runs the three passes as its own sub-agents, merges, and runs the verification script. Reword every "host" to "the implementer" (passes may be sub-agents it starts; the merge and the verification are its own), or the implementer waits on a step nobody takes.
2. **[Inventory, must-fix]** The prefix split and `find -maxdepth 3` do not account for everything the fork does. Checked in `/home/roland/project11`:
   - Tracked paths in no pass: `.agent/AGENT_ONBOARDING.md`, `AI_IDENTITY_STRATEGY.md`, `AI_RULES.md`, `WORKFORCE_PROTOCOL.md`, `WORKTREE_GUIDE.md`, `.agent/instructions/gemini-cli.instructions.md`, `.agent/.identity.template`, `.agent/github_metadata.json`, `.claude/settings.json` (a PreToolUse hook running `check_question_context.py` on AskUserQuestion, plus a permissions allowlist), `.editorconfig`, `.gitignore`. Add a catch-all ("anything unmatched goes to pass 2") and have the split script print unassigned paths and fail if any.
   - Untracked/ignored, in no pass: `.workspace-worktrees/issue-workspace-610` (branch `feature/issue-610`, open fork PR 657 "[PARKED] merge_pr.sh: classify merge verification, read ci-local attestations" — a duty in flight that `main` does not show); 324 untracked files in `.agent/scratchpad/` (field-data analysis scripts and results, lost if the checkout is retired); `.agent/project_config.yaml` (`field_remote: gitcloud`); `.agent/.identity`; `.rosdep/` (local rosdep sources); `.make/` (bootstrap and layer stamps); `.claude/settings.local.json`; 17 generated `make_*` skills; `.claude/worktrees/`. Use `git --no-optional-locks -C /home/roland/project11 ls-files -o --directory` (read-only, 355 entries without `__pycache__`) as the untracked inventory instead of `find -maxdepth 3` (876 lines mixing tracked and untracked), and redefine the step-6 sum on it.
   - Duties that are not files: about 25 `Makefile` targets (`setup-all` with git-bug, `sync`, `add-remote`/`push-remote`/`pull-remote`, `lock`/`unlock`, `pr-triage`, `agent-build`/`agent-run`/`agent-shell`, `test-scripts`, `validate`, layer stamps) — one row per target or target group, not one row "Makefile"; the CI jobs in `.github/workflows/validate.yml` (pre-commit lint, required-docs check, markdown link check, script tests); the things the fork's `AGENTS.md`/`CLAUDE.md`/`.github/instructions/*` tell agents to do by hand (pass 2 extracts these as duty rows, not one row per instruction file).
   - Not in the plan at all: roadmap Cutover row 4 says "Closed-since-fork issues are accounted for here, as features". Add a read-only `gh issue list -R rolker/ros2_agent_workspace --state closed` step (34 closed since 2026-07-01, 16 since 2026-09-15) mapping each to a row or "no row: …", and list the fork's 2 open PRs (657 above; 663 dependabot) for list B.
3. **[Verify before claiming, must-fix]** "Already covered" from opening this tree's file is not enough where the fork has a file of the same name: 37 script names exist in both `.agent/scripts/` trees and 31 of them differ. For each same-name or same-purpose pair, the pass reads a read-only `diff` of fork against here and either finds no fork-only behaviour (already covered) or names it (class port or adapter, note "partly covered: <what is missing>"). For the ROS build path (`setup_layers.sh`, `stage_rosdep_manifests.sh`, `rosdep_*` against `.agent/project_types/ros2_colcon/adapter.sh`), "already covered" also names the test here that exercises the behaviour, or the row says "covered, no test" and counts as a day-to-day risk; running anything in the fork stays forbidden.
4. **[Classification, must-fix]** "Day-to-day blocker" is undefined, so three passes will classify it differently and list A will be inconsistent. Put one test in the plan and in each pass brief, for example: "Yes if, without it, a developer doing a normal project11 change on pickerel (fresh 26.04, Rolling, Claude Code, this workspace only) would have to fall back to the fork or redo by hand something the fork automates within the first week, or the Direction acceptance case (a working simulator in Rolling) cannot be reached; otherwise retire-only." The merge step re-applies the test to every "yes" before it goes into list A.
5. **[Manifest duties, must-fix]** Step 3 asks pass 1 to describe the resolver but leaves the class open. Fix it in the plan: `sync_repos.py`, `validate_repos.py` (and `list_overlay_repos.py`, `manifest_fallback.sh`, `resolve_repo_checkout.sh` where they serve the same duty) are **not yet covered**: `tools/ros-manifest/` is a tested prototype, but nothing in `.agent/`, `.claude/` or the `Makefile` calls it (grep, 2026-11-10), and the `ros2_colcon` adapter still reads vcstool `.repos` files from `configs/manifest/`. Class adapter, day-to-day blocker yes (owner, 2026-11-10: "I want the new manifest to be used for the pickerel test"), "Covered by" naming the resolver as the starting point and #267, never "already covered".
6. **[Readability, suggestion]** 120–180 per-file rows will not be read and will churn. Group rows by duty (for example "field mode: N scripts, 3 skills, fork ADR 0011 and 0014, 2 knowledge files, Makefile remote targets"), listing the fork paths in the row so the count check still maps every path; about 40–70 rows keeps the document inside 250–350 lines. Each list-A/B line reads as effect, need, issue ("On pickerel, X cannot be done until Y — #N / no issue yet") so the owner can act without the table.
7. **[Consequences, suggestion]** `update_roadmap.sh --issue N` only sets Status to `done` and `merge_pr.sh` already runs it on merge. Step 7 should edit only row 4's Notes (the link) by hand and leave Status to the merge.
8. **[Issue alignment, suggestion]** The issue body records declines in the roadmap's "Decided Against". Have the document list proposed Decided Against lines next to the proposed issues (owner's call), so the decline list has a home after the veto.
9. **[Safety, suggestion]** In each pass brief, besides "no make, no script run": every `git` call in the fork and its worktrees carries `--no-optional-locks`; unpushed work in `layers/worktrees/*` and `.workspace-worktrees/*` is read with `git --no-optional-locks -C <wt> log --oneline @{u}..` (or "no upstream"); `gh` against the fork repository is list/view only.

### Summary

The shape (one record, three read-only passes, a merge, a count check, no issues opened) is right and the read-only rule is sound. It is not ready: the "host" steps need an owner in this loop, the inventory misses tracked and untracked paths and non-file duties (including an in-flight fork PR and 324 scratchpad files), "already covered" ignores fork-only behaviour in 31 differing same-name scripts, the blocker test is undefined, and the manifest duties need their honest class fixed in the plan.

### Recommended Actions

- [ ] Reword steps 1, 4, 6 so the implementer (with its own sub-agents for the passes) does them.
- [ ] Extend the inventory: catch-all for unassigned tracked paths with a failing check; untracked list from `git --no-optional-locks ls-files -o --directory`; Makefile targets, CI jobs and instruction-file duties as rows; closed-since-fork issues and open fork PRs.
- [ ] Require a read-only diff for same-name files before "already covered"; name a test here for the ROS build path or say "no test".
- [ ] Add the one-sentence day-to-day blocker test to the plan and every pass brief.
- [ ] Fix sync/validate (and related manifest scripts) as adapter, not yet covered, day-to-day blocker yes.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 15:40 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review found five must-fixes in the audit's method, none a change of what the audit is for; the plan is the brief three passes will work from, so it is corrected before they start; first host revise on this plan)
**After**: plan
**Decision**: revise

Host read the Plan Review of 2026-11-10 (needs-work, 5 must-fix, suggestions) and directs that every must-fix and suggestion be taken as the review words them: every "host" step becomes the implementer's; the inventory gets a catch-all pass and a check that fails on any unassigned path, tracked or untracked, and also covers Makefile targets, CI jobs, hand steps in the instruction files and closed-since-fork issues; "already covered" needs a read-only diff for same-named scripts, with "partly covered" as a class, and a named test or "covered, no test"; the one-sentence day-to-day blocker test goes in the plan and every pass brief; the repository sync and validate scripts are classified adapter, not yet covered, day-to-day blocker; table rows are grouped by duty.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 12:11 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-253/plan.md` at `4d01e2cb`

Revision after the needs-work plan review: all phase work is the implementer's (with its own sub-agents); inventory split fails on unassigned tracked or untracked paths and adds a catch-all, Makefile/CI/hand-step/closed-issue/open-PR rows; read-only diff and "partly covered" for same-name scripts; the day-to-day test in every brief; sync/validate classed adapter, not yet covered, blocker; rows grouped by duty; only row 4 Notes edited; proposed Decided Against lines.

## Plan Review
**Status**: complete
**When**: 2026-11-10 12:20 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready
**Dispatch**: resumed (agent a0983777023b9b1c7, resume 1 of 3)

**Issue**: #253 — ros2_agent_workspace parity audit: classify remaining ADRs, skills, scripts for port/adapter/decline
**Plan**: `.agent/work-plans/issue-253/plan.md` at `4d01e2cb`
**Branch**: `feature/issue-253`
**Serves**: Flexibility and Trust, control and information (README `#workspace-goals`); `docs/design.md#registry-and-adapters`; roadmap Cutover sequence row 4.

Narrow re-review: whether the five must-fixes and four suggestions of the previous Plan Review (at `1b953c94`) are resolved as worded, and whether the revision introduced anything wrong. Nothing accepted before is reopened.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged; one PR, no code. |
| Issue alignment | Good | Closed-since-fork issues now in pass 2 (roadmap row 4); proposed Decided Against lines in step 6. |
| File targeting | Good | Inventory covers tracked, untracked, Makefile targets, CI jobs, hand steps, open fork PRs, with a catch-all. |
| Consequences | Good | Row 4 Notes only; Status left to `merge_pr.sh`. |
| Principle alignment | Good | Diff-based "already covered", "partly covered" class, named test or "covered, no test"; blocker test in every brief. Two stale step references (finding 3). |
| ADR compliance | Good | Unchanged. |
| ROS conventions | N/A | Workspace record. |

### Previous findings, checked

1. Host steps → implementer: **resolved** ("Who does what"; steps 1, 2, 3, 6, 7 name the implementer).
2. Inventory: **resolved** (step 1: `ls-files` and `ls-files -o --directory`, split script failing on unassigned or doubly assigned paths, catch-all to pass 2 naming the paths found; Makefile targets and `validate.yml` jobs as pass 1 duty rows; instruction-file hand steps and closed-since-fork issues in pass 2; `.workspace-worktrees/`, `.agent/scratchpad/`, `.rosdep/`, `.make/`, open fork PRs 657 and 663 in pass 3).
3. "Already covered": **resolved** (step 4: read-only diff for the 37 same-name scripts, "partly covered" class naming the gap, named test or "covered, no test" for the ROS build path).
4. Blocker test: **resolved** (word for word in the brief text; merge re-applies it to every "yes").
5. Manifest duties: **resolved** (step 5 fixes adapter, not yet covered, blocker yes; never "already covered").
6–9. Suggestions (group by duty; Notes-only roadmap edit; Decided Against lines; fork-access rules in each brief): **all taken** (steps 3, 6, 8 and the brief text).

### Findings (new, suggestions only)

1. **[Verification, suggestion]** Step 7(d) asks the paths listed in rows to equal each pass's inventory, and step 3 says each row lists its fork paths. With 324 untracked scratchpad files, 190 tracked work-plan files and 39 layer worktrees, listing every path would bloat the document. Let a row cite a prefix or glob with its count (for example `.agent/scratchpad/** (324)`), and have the check expand those against the inventory lists rather than compare literal strings. Also note `ls-files -o --directory` reports `layers/` as one entry, so sub-paths under it (`layers/worktrees/*`) must count against that entry, not as unknown paths.
2. **[Read-only rule, suggestion]** The Context's allowed list (`ls`, `find`, `cat`/Read, `grep`, `git --no-optional-locks ls-files` and `git log`) leaves out what the revision now uses: `diff`/`cmp` against fork files (step 4), `git --no-optional-locks branch`/`worktree list` and `gh issue list`/`gh pr list` (list/view only). Add them to the allowed list so a pass does not read the brief as contradicting itself.
3. **[Consistency, suggestion]** Two stale step numbers: Principles Self-Check says "step 6 checks every path and issue number" (now step 7), and Design Picture says the change-log row is decided in "step 8" (correct now, but the self-check row is not).

### Summary

All five must-fixes and the four suggestions are resolved as worded, and the revision introduced nothing that would make the document wrong. Ready to implement with the three suggestions above carried into the implementer's brief.

### Recommended Actions

- [ ] Carry into the implementer's brief: rows may cite a prefix or glob with a count, and the count check expands them (including `layers/` as one untracked entry).
- [ ] Add `diff`/`cmp`, `git --no-optional-locks branch`/`worktree list` and list/view `gh` to the Context's allowed list.
- [ ] Fix the stale "step 6" in the Principles Self-Check (now step 7).

## Checkpoint
**Status**: complete
**When**: 2026-11-10 15:55 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second plan review: ready, no must-fix, three suggestions to pass to the implementer)
**After**: plan
**Decision**: proceed

Host read the second Plan Review (ready). Carried to the implementer: a table row may cite a folder pattern with a count and the count check expands it; diff/cmp, `git --no-optional-locks branch` and `worktree list`, and list/view-only gh are allowed read-only commands; the self-check row's step number is corrected.

## Implementation
**Status**: complete
**When**: 2026-11-10 12:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-253 at `135e7063`

- `docs/fork_parity.md` (new, 183 lines): two lists on top (3 lines block developing project11 here, 9 block only retiring the fork), a 61-row table grouped by duty, the 34 closed-since-fork issues mapped to rows, 10 proposed issues and 6 proposed Decided Against lines (none opened, nothing written to the roadmap's Decided Against).
- Inventory from the fork checkout at `323306a8` (read only, not fetched; ls-remote unmoved): 454 tracked + 355 untracked entries (7 `__pycache__` left out), split into pass 1 (174), pass 2 (86), pass 3 (531) and catch-all (18) by a script that fails on any unassigned or doubly assigned path. Four read-only sub-agent passes ran in parallel (4 jobs); the merge re-applied the blocker test to every "yes" (make setup chain, layer checkouts and local rosdep keys downgraded, with reasons in their rows) and re-checked the layer worktrees itself against all remote refs (1793 repo checkouts read).
- Verification (scratchpad script, not committed): inventory split exits 0; every one of 809 entries is in a row and every stated glob count matches; 79 "Covered by" paths exist in this tree; 52 issue and PR references exist on GitHub; the closed-since-fork list equals the fork's 34.
- `docs/roadmap.md`: Cutover row 4 Notes link only (Status left to merge_pr.sh). Digest: one pointer line. `docs/design.md`: no change (the record changes no part of the design picture).
- Plan: carried the second plan review's two suggestions (allowed read-only commands, self-check step number).
- Found while auditing: the fork is in use today (an agent opened a cube_bathymetry issue-173 worktree there at 12:23 and committed a plan); #267 is closed while roadmap Cutover row 3 still says planned, so the adapter wiring for the new manifest has no open issue.
- Pre-commit on all branch files, no SKIP: passed (script-test suite included).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-10 12:39 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-253 at `4a67c635`
**Base**: main
**Depth**: Deep (reason: 645 changed lines across 5 files; same specialists as Standard)
**Must-fix**: 6 | **Suggestions**: 6
**Round**: 1 | **Ship**: continue — six must-fix in round 1, two of them change top-list lines the owner acts on

Checked against both trees (fork read only: ls, find, cat, grep, `git --no-optional-locks` log/branch/rev-list/status/ls-files only). Confirmed true: the adapter calls nothing in `tools/ros-manifest/` (grep); no package PR takes its base from the manifest pin, and #429's branch does not add it (its run-issue passes `-R` only, no `--base`); the fork's `bootstrap.sh` does `rosdep init` and `rosdep update` for Jazzy and no host `rosdep install` (that runs only in the declined container); 14 package worktrees with commits on no remote ref + 1 with 6 modified files + 3 with only untracked files, re-counted (remote refs were fetched by the fork itself at 11:17 today, so not stale); 10 of 45 package `AGENTS.md` name the fork; 34 closed-since-fork issues. Spot-checked rows 12, 20 (port), 23, 31 (partly covered), 41, 43 (decline), 52, 55 (already covered): class and Covered by hold. Outside reviewers: codex ran (`-s read-only` sandbox), gemini ran (told to call no tools); the fork read-only rule could not be added to their prompt, the sandbox and no-tools mode enforce it.

### Findings
- [x] (must-fix) Top list A line 1 and row 1 say the adapter "reads the jazzy `.repos` files"; it reads whatever the bootstrap branch carries, and the p11-rolling instance here already checks out from the rolling branch (`projects/p11-rolling/configs/manifest` -> rolling `config/`, `distro: rolling`). Say so, and add the missing step: the new-format project11 manifest exists only as a test fixture (`tools/ros-manifest/tests/fixtures/p11/manifest.yaml`); no project11 repository carries it, so issue item 1 must also place it — `docs/fork_parity.md:32,66,148`
- [x] (must-fix) Top list A line 3, row 3 and issue item 3 omit installing `ros-dev-tools` (colcon, vcstool, rosdep): the fork's `bootstrap.sh` installs it, ours installs none, and `adapter setup` refuses without `vcs` (`adapter.sh:452`) — `docs/fork_parity.md:34,68,150`
- [x] (must-fix) Top list B line 2, row 33 and issue item 4: "324 untracked scratchpad files" is 324 entries with folders collapsed (`ls-files -o --directory`); the folder holds about 66,800 untracked files, 39 GB, in 58 folders plus 269 loose files (`sonardyne_talk/` alone 36 GB, 62,527 files; also `m365_search/`, `outreach_web_camp/`), not only field data — `docs/fork_parity.md:44,98,151`
- [x] (must-fix) Issue item 10 duplicates open issues: the full closing-keyword set is #369 (P1f), commit-identity strict mode overlaps #356 and #359; rows 24 and 12 should cite them (row 24 cites closed #363) — `docs/fork_parity.md:77,89,157`
- [x] (must-fix) Row 51 "already covered" is untrue (codex, verified): the fork's `setup_layers.sh:349-356` removes a failed optional layer's `src`; `adapter_setup` keeps the partial checkout (`adapter.sh:471-474`) and `adapter_build` then builds it and stops (`adapter.sh:493-505`); `site` is optional and 4th of 7 layers. Class partly covered, note the gap — `docs/fork_parity.md:116`
- [x] (must-fix) The document has no list of what it did not determine; the gaps sit only in table rows the owner will not read (row 18 consumer unknown, 31 read by head only, 48 work plans by structure only, 50 no named build-pollution test) and the package-worktree check did not look for squash-merged work. Gather them under the top lists — `docs/fork_parity.md:41`
- [x] (suggestion) List B line 1: 10 of the 14 hold only 1 to 3 `progress:` record commits; the real work is udp_bridge 75 and 64, unh_marine_autonomy 304, cube_bathymetry 44, marine_perception_tools 4. Say so, and that the remote refs were fresh (fetched 11:17) — `docs/fork_parity.md:43`
- [x] (suggestion) The fork also moved after the inventory: unh_marine_autonomy 304 got a commit at 12:36 (now 11, not 10) and `appledore_backscatter/` got new files — `docs/fork_parity.md:13,97`
- [x] (suggestion) Seven package `.agents/README.md` also name the fork (one in marine_perception_tools, which has no `AGENTS.md`); include them in the repoint — `docs/fork_parity.md:47,101`
- [x] (suggestion) rolker/ros2_agent_workspace#605 is the Ollama reviewer issue: map it to row 43, not row 27 (gemini, verified) — `docs/fork_parity.md:137`
- [x] (suggestion) Ollama decline reason: give this workspace's own reason (the late-October local trial found no model that met the bar), not only the fork's hardware reason — `docs/fork_parity.md:108,163`
- [x] (suggestion) Row 8: `.claude/settings.json` here allows no `colcon` or adapter commands, so a background package build may prompt; add that to the note (Claude adversarial) — `docs/fork_parity.md:73`

## Implementation
**Status**: complete
**When**: 2026-11-10 12:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-253 at `32b8bcfa`
**Addressed**: Local Review (Pre-Push) at `4a67c635` (2026-11-10 12:39 -05:00)
**Commits**: 985ca97b 19e62987 c7ea622a db943402 0c8d52be e52b7bdb c0f36a44 8337d083 71655204 22d2644b 0a3e4bbf c9210344 32b8bcfa

### Actions
- [x] Manifest line: the adapter reads the `.repos` of the branch the bootstrap names (`p11-rolling` checks out from unh_marine_autonomy's rolling branch, `distro: rolling`); the new-format manifest is only the test fixture (written from the jazzy manifest; GitHub code search over rolker finds no other); proposed issue 1 now also places it in a project11 repository; #267 (closed) moved out of row 1's Covered by — `docs/fork_parity.md:34,80,163`
- [x] Fresh machine: `ros-dev-tools` (colcon, vcstool, rosdep) added to top line, row 3 and proposed issue 3; fork bootstrap installs it, ours does not, `adapter setup` stops without `vcs` — `docs/fork_parity.md:36,82,165`
- [x] Scratchpad real size (find, 12:41): about 67,900 files, 39 GB, 59 folders + 269 loose files; largest folders named with sizes; kinds listed; 57,400 files are Python venvs — `docs/fork_parity.md:46,112,166`
- [x] Item 10 drops the closing-keyword set (#369) and strict mode (#356, #359); row 12 cites #356/#359, row 24 cites #369 with #363 (closed) moved to the note; item 10 gains row 24's two uncovered parts — `docs/fork_parity.md:91,103,172`
- [x] Row 51 partly covered with the optional-layer gap; not a blocker: `site` is one private repo, so a failed import leaves an empty `src`, which colcon builds as 0 packages, exit 0 (run here); class counts 12/11; gap added to item 10 — `docs/fork_parity.md:130,172,196`
- [x] New "Not determined" section: rows 18, 31, 48, 50; squash merges (no merged PR from the six real-work branches; the rest not checked); default branch vs pin (37 of 44 equal, 7 differ, named; 38 still at `jazzy`); what moved in the fork after the inventory — `docs/fork_parity.md:55`
- [x] Worktrees named by kind (4 real work, 2 plans only, 8 progress records only); remote refs fetched 11:17 to 11:18 (FETCH_HEAD) — `docs/fork_parity.md:45,111`
- [x] Fork movement after the inventory recorded (uma 304 merge at 12:36, now 11; scratchpad additions) — `docs/fork_parity.md:13,65`
- [x] Seven package `.agents/README.md` name the fork (11 repos in all); top line, row 36 and item 5 — `docs/fork_parity.md:49,115,167`
- [x] fork#605 and the other two local-model issues (#570, #590) mapped to row 43, out of row 27 — `docs/fork_parity.md:151,155`
- [x] Ollama decline: this workspace's own reason (late-October trial, none of three models found the must-fix; #398 comment of 2026-10-30) in row 43 and the Decided Against line — `docs/fork_parity.md:122,178`
- [x] Row 8: no `colcon`, `make build`/`make test` or `adapter` command on the allowlist, so a background build may prompt — `docs/fork_parity.md:87`

Verification re-run: 61 rows, IDs 1 to 61; 81 Covered-by paths exist; 19 workspace issue refs and 37 fork refs exist (gh); the 34 closed-since-fork issues equal gh's list; class and blocker counts match the Counts section. Pre-commit over the branch files, no SKIP: passed (script-test suite included).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-10 12:51 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent ad975645f7706440c, resume 1 of 3)
**Verdict**: changes-requested

**Branch**: feature/issue-253 at `b3cd0e14`
**Base**: main
**Depth**: Deep (reason: whole-branch diff, 5 files and over 200 changed lines; fix round classified as a first review, round 2 so cross-model dispatched)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 6), not rising — fix and ship rather than another full round

All six round-1 must-fixes and six suggestions are resolved as worded (re-read in the document). Checked the fix pass's own additions: proposed issue 1 split in two (adapter here, manifest in a project repository) is sound; fork #570 and #590 are the local-model reviewer issues (gh), so row 43 is right; #267 out of row 1's Covered by is right (closed). Row 51 "partly covered, not a blocker" holds: `site` is the only optional layer and its `.repos` is one repository (CCOMJHC/ccomjhc_project11, PRIVATE per gh); an empty `src` builds and tests with colcon, exit 0 (run here in the scratchpad). New facts: the fixture's header says it was authored from the p11-jazzy manifest (with a per-distro override reproducing rolling); unh_marine_autonomy is pinned `rolling` in the Rolling core.repos and its GitHub default branch is `jazzy` (gh); rqt_marine_radar pinned `jazzy`, default `noetic` (gh). Outside reviewers: codex and gemini ran (read-only sandbox / no tools); a fresh Claude sub-reviewer checked the four owner-read sections with the fork rule word for word.

### Findings
- [x] (must-fix) The Watch line under the first list says "No issue yet" for the unh_marine_autonomy 397 pystac/snakemake dependency case, and proposed issue 6 folds those local rosdep keys in; open #310 (mixed-flavor projects, a dependency concern the adapter lacks) is exactly that case and may settle it differently (its boundary rule: contribute the rosdistro key or do not use it). Cite #310 on the Watch line, row 6 and issue 6 — `docs/fork_parity.md:41,168`
- [x] (suggestion) "Not determined" says no named test covers fork ADR-0016's build-pollution case; `test_build_layer_order_and_cascade` (`.agent/scripts/tests/test_ros2_colcon.sh:1050`) asserts each layer builds having sourced only the layers below it, which is that case's cause (stub colcon; real baked chains not tested). Cite it and narrow the line (codex) — `docs/fork_parity.md:63`
- [x] (suggestion) Fork #620 (Provisional ADR status, closed not planned) maps to row 50 "already covered"; here it is the roadmap Deferred line "ADR Provisional status" (`docs/roadmap.md:413`). Map it there or say so (codex) — `docs/fork_parity.md:156`
- [x] (suggestion) Roadmap Cutover row 3 still says #267 "planned" while the document says the adapter wiring has no issue; say the roadmap row is the only tracking entry until proposed issue 1 is opened (Claude sub-reviewer) — `docs/fork_parity.md:34`

## Implementation
**Status**: complete
**When**: 2026-11-10 12:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a4011409abd505895, resume 1 of 3)

**Branch**: feature/issue-253 at `387e7a7f`
**Addressed**: Local Review (Pre-Push) at `b3cd0e14` (2026-11-10 12:51 -05:00)
**Commits**: 5152dfa3 b5e77257 3e313402 387e7a7f

### Actions
- [x] Open #310 cited on the Watch line, row 6 (Covered by and note) and proposed issue 6; issue 6 now leaves the dependency mechanism for keys rosdep does not resolve to #310 instead of folding in local rosdep keys — `docs/fork_parity.md:38,85,168`
- [x] Build-pollution case: "Not determined" line narrowed to real colcon builds, citing `test_build_layer_order_and_cascade` (stub colcon); row 50's note corrected to match — `docs/fork_parity.md:65,132`
- [x] Fork #620 moved out of row 50 to its roadmap entry; the entry is under To Consider ("From ros2_agent_workspace"), not a Deferred section, and the document says so — `docs/fork_parity.md:157`
- [x] Manifest line names roadmap Cutover row 3 (Manifest support, still planned against closed #267) as the only tracking entry until proposed issue 1 is opened — `docs/fork_parity.md:34`

Verification re-run: 61 rows, IDs 1 to 61; 81 Covered-by paths exist; 20 workspace issue refs and 37 fork refs exist (gh); the 34 closed-since-fork issues equal gh's list; class and blocker counts match the Counts section. Pre-commit over main...HEAD, no SKIP: passed (script-test suite included).
