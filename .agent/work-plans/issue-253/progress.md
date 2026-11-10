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
