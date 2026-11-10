# Fork parity

What `ros2_agent_workspace` (the fork) does that this workspace does not do
yet, item by item, so the fork's duties can move here and the fork can be
retired. A record for issue #253; it opens no issues.

Read on 2026-11-10 from the fork checkout `/home/roland/project11` at
`323306a8` (2026-09-25). `git ls-remote` showed the fork's `main` at the same
commit; the checkout was not fetched. Inventory: 454 tracked files and 355
untracked entries (`git ls-files -o --directory`, 7 `__pycache__` entries left
out), taken at 12:13.

The fork is still in daily use: between 12:23 and 12:29 that day an agent in
the fork opened a worktree for cube_bathymetry issue 173 and committed a work
plan there. Its scratchpad folder (`.agent/scratchpad/cube173/`) appeared
after the inventory and is not counted.

What this serves, from `docs/roadmap.md`:

> | 4 | Parity audit of the fork | #253 | planned | Feature by feature against the fork's tree, including its `.agent/knowledge`, work plans and work artifacts, not just scripts. Closed-since-fork issues are accounted for here, as features |

> **Acceptance case.** Project11 is developed on a second machine against
> ROS 2 Rolling through this workspace. [...] It is done when the simulator
> works in Rolling: "a working simulator in Rolling" (2026-09-21).

## Blocks developing project11 here

Test for each line: "Yes if a normal project11 change on pickerel would need
the fork, or redoing by hand something the fork automates, within the first
week, or the Rolling simulator acceptance case can't be reached."

- On pickerel, the project11 repositories can be checked out, synced and validated today only from the old `.repos` files, not from the new manifest the owner wants there. What works: the registered Rolling instance (`p11-rolling`) checks out from the `.repos` files on unh_marine_autonomy's rolling branch (`distro: rolling`). What is missing: the project's manifest in the new format exists only as a test fixture in this repository (`tools/ros-manifest/tests/fixtures/p11/manifest.yaml`, written from the jazzy manifest) and in no project11 repository, and the ros2_colcon adapter calls nothing in `tools/ros-manifest/`. Needs the manifest placed in a project11 repository and the adapter wired to the resolver. No issue yet: #267 closed with the adapter wiring left for a later milestone; proposed issue 1 (row 1).
- On pickerel, `/run-issue` cannot take a project11 package issue to a merged pull request until it finds the package repository and its worktree, opens the pull request there, and takes the base branch from the package's manifest pin (`rolling`, not GitHub's default branch). #429, which does not name the base branch yet (row 2).
- On pickerel, installing the ROS development tools (`ros-dev-tools`: colcon, vcstool, rosdep), `sudo rosdep init`, `rosdep update` and installing the packages' system dependencies are hand steps until the setup guide or the adapter covers them; `adapter setup` stops without `vcs`. The fork's `bootstrap.sh` installed `ros-dev-tools` and did init and update, for Jazzy only; ours installs none of them; `rosdep install` was a hand step in the fork too. #430 (row 3).

Watch: if the unh_marine_autonomy change for its issue 397 (repo-local rosdep
keys for pystac and snakemake, on its feature branch only) reaches the Rolling
branch, installing dependencies also needs the local-key source list the fork
generates. No issue yet (row 6).

## Blocks only retiring the fork

- Before the fork checkout is deleted, 15 package worktrees hold work found nowhere else: 14 with commits on no remote branch (the largest, udp_bridge issue 75, 24 commits) and 1 with 6 modified files. Each needs a push or a drop. No issue yet, part of #262 (row 32).
- Before the checkout is deleted, 324 untracked scratchpad files (field-data analysis scripts and results, handoff and review logs) are lost unless the wanted ones are copied to project11 repositories. No issue yet, part of #262 (row 33).
- In the field, boats cannot work against a non-GitHub remote from this workspace until field mode is ported. #208, #209 (row 10).
- Deployment mode (the urgency contract, start and wrap-up deployment skills) has no home here and needs field mode first. No issue yet (row 11).
- Ten package repositories' `AGENTS.md` send agents to the fork for the shared rules; they need repointing at cutover. No issue yet; the change is in those repositories (row 36).
- The project11 rules and knowledge kept in the fork (no change to raw bags or field hosts, bag analysis, field-failure diagnosis) must move to project11's own `AGENTS.md` or `.agents/`. No issue yet (rows 34, 35).
- ROS 2 knowledge (conventions, CLI, launch and Gazebo, the ament lint profile, test recipes, package documentation, troubleshooting) has no home here until it moves into the ros2_colcon type. No issue yet (row 4).
- Cross-repository status (`pr_status.sh --all-repos`, the dashboard, governance discovery) does not see package repositories here. No issue yet (row 5).
- Build and test reports (JSON and CSV, `colcon test-result` summary) and a make chain for a registered ROS project (stamp re-run when a `.repos` changes, clean of build, install and log) exist only in the fork. No issue yet (rows 21, 22).

## Table

Classes: port (generic mechanism to bring here), adapter (belongs in
`.agent/project_types/ros2_colcon/` or a project's `.agents/`), decline,
already covered, partly covered (the fork has behaviour this tree lacks; the
note names it), belongs to a project repository. "Already covered" means the
file here that does the job was opened, and where a file of the same name
exists in both trees a `diff` was read. Rows are grouped by duty and sorted by
class, then blocker. Fork paths are relative to the fork root; `x/** (N)` is
every inventory entry under `x/`, and `layers/` is one untracked entry.

| ID | Item | Fork paths | Class | Day-to-day blocker? | Covered by | Note |
|---|---|---|---|---|---|---|
| 1 | Repository sync, enumeration and validate from the manifest | `.agent/scripts/sync_repos.py`; `.agent/scripts/list_overlay_repos.py`; `.agent/scripts/manifest_fallback.sh`; `.agent/scripts/resolve_repo_checkout.sh`; `.agent/scripts/lib/workspace.py`; `.agent/scripts/validate_repos.py`; `.agent/scripts/validate_workspace.py`; `.agent/scripts/tests/test_sync_repos.py`; `.agent/scripts/tests/test_workspace_lib.py`; `.agent/scripts/tests/test_resolve_repo_checkout.sh`; `.agent/scripts/tests/test_validate_workspace.py`; `configs/manifest`; `configs/project_bootstrap.url`; `Makefile` | adapter | yes | `tools/ros-manifest/`; `.agent/project_types/ros2_colcon/adapter.sh`; #365 | Not yet covered: the resolver is a tested prototype nothing calls (#267, closed); the adapter sets up, syncs and validates the old layout from `configs/manifest`, a symlink into unh_marine_autonomy's `config/` on whatever branch the bootstrap names (rolling for `p11-rolling`, jazzy in the fork). The new-format manifest is only a test fixture here (`tools/ros-manifest/tests/fixtures/p11/manifest.yaml`); GitHub code search over rolker finds it in no project repository. Fork-only validate: orphan repos, branch drift, `--fix`. Owner wants the new manifest on pickerel |
| 2 | Loop on a package repository: find the repo and its worktree, open the PR there, PR base from the manifest pin | `.agent/scripts/get_repo_info.py`; `.claude/skills/run-issue/**`; `.claude/skills/review-issue/**`; `.claude/skills/review-plan/**`; `.claude/skills/plan-task/**`; `.claude/skills/review-code/**` | adapter | yes | #429; #433 | Fork skills resolve the package under `layers/main` and pass the `.repos` branch as `--base`. Here package worktrees open no draft PR ("Create PRs per package repo by hand") and nothing picks the base |
| 3 | ROS host bootstrap: ROS apt source, `ros-dev-tools` (colcon, vcstool, rosdep), `rosdep init` and `update` | `.agent/scripts/bootstrap.sh` | adapter | yes | `.agent/scripts/bootstrap.sh`; #430 | Diff read: ours installs git, python, gh, git-bug, no ROS and no `ros-dev-tools`; `adapter setup` stops without `vcs` (`adapter.sh`, "'vcs' (vcstool) not found"). The owner installs Rolling on pickerel; the development tools, rosdep init and update stay hand steps here; the fork's are hardcoded to Jazzy |
| 4 | ROS 2 knowledge and templates: conventions (fork ADR-0008), CLI, launch and Gazebo, ament lint profile, test recipes, package docs, CI and pre-commit templates, architecture and troubleshooting | `docs/decisions/0008-*.md (1)`; `.agent/knowledge/ros2_development_patterns.md`; `.agent/knowledge/ros2_cli_best_practices.md`; `.github/instructions/ros2.instructions.md`; `.agent/knowledge/launch_tooling.md`; `.agent/knowledge/gazebo_ros_launch_patterns.md`; `.agent/knowledge/review_static_analysis.md`; `.claude/skills/test-engineering/**`; `.claude/skills/document-package/**`; `.agent/knowledge/documentation_verification.md`; `.agent/templates/package_documentation.md`; `.agent/templates/ci_workflow.yml`; `.agent/templates/pre-commit-config.yaml`; `ARCHITECTURE.md`; `README.md` | adapter | retire-only | `.agent/knowledge/review_static_analysis.md`; `.claude/skills/test-engineering/SKILL.md`; `.claude/skills/document-project/SKILL.md` | Ours are generic. Not a week-one gate: unh_marine_autonomy carries its own `AGENTS.md` and `.agents/README.md`. `document-project` names `package_documentation.md` "if available"; it is absent here |
| 5 | Cross-repository status and governance discovery over package repos | `.agent/scripts/discover_governance.sh`; `.agent/scripts/pr_status.sh`; `.agent/scripts/PR_STATUS_README.md`; `.agent/scripts/tests/test_pr_status_all_repos.sh`; `.agent/scripts/dashboard.sh`; `.agent/scripts/tests/test_dashboard_repo_enumeration.sh`; `.agent/scripts/tests/test_dashboard_validate_status.sh` | adapter | retire-only | `.agent/scripts/discover_governance.sh`; `.agent/scripts/pr_status.sh`; `.agent/scripts/dashboard.sh` | Diffs read: ours scan `project/` only; `adapter repos` already lists package repos (tested) but none of the three call it |
| 6 | Local rosdep keys and the dependency policy | `.agent/scripts/rosdep_local_sources.sh`; `.agent/scripts/rosdep_local_staleness_check.sh`; `.agent/scripts/rosdep_yaml_validate.sh`; `.agent/scripts/tests/test_rosdep_local_sources.sh`; `.agent/knowledge/dependency_policy.md` | adapter | no | none | No rosdep handling in this tree (grep). Only the unh_marine_autonomy issue-397 branch carries a `rosdep.yaml`; becomes a blocker if that reaches the Rolling branch |
| 7 | Worktree guide for layer and package worktrees | `.agent/WORKTREE_GUIDE.md` | adapter | no | `.agent/WORKTREE_GUIDE.md`; #429 | Fork guide is `--type layer`; ours is workspace and project; package worktrees are #429 |
| 8 | Claude permissions allowlist for ROS commands | `.claude/settings.json`; `.claude/settings.local.json` | adapter | no | `.claude/settings.json` | Fork list is colcon, ros2 bag, `/opt/ros/jazzy`, `field_mode.sh`; ours is larger and generic. `settings.local.json` is machine-local |
| 9 | Editor config and ignore list | `.editorconfig`; `.gitignore` | adapter | no | `.gitignore` | Fork ignores `layers/`, `.rosdep/`, build trees; ours ignores `projects/`, `worktrees/`, `.ros-manifest-cache/`. No `.editorconfig` here |
| 10 | Field mode: non-GitHub origin, hotfix and import, live-ops log, secondary-remote sync | `.agent/scripts/field_mode.sh`; `.agent/scripts/tests/test_field_mode.sh`; `.agent/scripts/dlog.sh`; `.agent/scripts/tests/test_dlog.sh`; `.agent/scripts/add_remote.py`; `.agent/scripts/push_remote.py`; `.agent/scripts/pull_remote.py`; `.agent/scripts/lib/remote_utils.py`; `.agent/scripts/tests/test_pull_remote.py`; `.agent/scripts/tests/test_remote_probe.py`; `.agent/scripts/tests/test_net_retry.py`; `docs/decisions/0011-*.md (1)`; `.agent/knowledge/field_mode_hotfix.md`; `.claude/skills/import-field-changes/**`; `.agent/project_config.yaml`; `Makefile` | port | retire-only | #208; #209 | Nothing here (no `field_mode.sh`, no skill). Pickerel has GitHub, so no week-one use. Makefile remote targets go with it |
| 11 | Deployment mode: urgency contract, deployment lifecycle | `docs/decisions/0014-*.md (1)`; `.agent/knowledge/deployment_mode.md`; `.claude/skills/start-deployment/**`; `.claude/skills/wrap-up-deployment/**`; `.agent/templates/deployment_config.yaml` | port | retire-only | none | Needs field mode first; #208 and #209 name field mode only |
| 12 | Commit-identity hardening: strict mode on agent branches, shared patterns, PR-author CI job | `.agent/hooks/check-commit-identity.py`; `.agent/hooks/identity_patterns.py`; `.agent/hooks/check_pr_authors.py`; `.agent/hooks/verify-issue-branch.py`; `.agent/scripts/test_check_commit_identity.sh`; `.github/workflows/validate.yml`; `AGENTS.md` | port | no | `.agent/hooks/check-commit-identity.py`; `.pre-commit-config.yaml` | Diffs read: ours are the earlier hook versions; no strict mode, no CI author check, no identity test |
| 13 | AskUserQuestion re-orientation nudge hook | `.agent/hooks/check_question_context.py`; `.agent/scripts/tests/test_check_question_context.sh`; `.claude/settings.json` | port | no | `.claude/skills/run-issue/SKILL.md` | Warn-only PreToolUse hook; here the rule is text in run-issue, and the only hook is `.claude/hooks/log-tool-use.sh` |
| 14 | Hand rules in the fork's `AGENTS.md`: closing-keyword hazard, no squash, read reviews before merge, no lint suppression, no hand-typed timestamps or invented attribution | `AGENTS.md` | port | no | #261 | grep: none in our `AGENTS.md` (199 of 200 lines) or knowledge; belongs in knowledge, not `AGENTS.md` |
| 15 | Documentation seams: plan-task "Stale docs" and instruction candidates, checked by review-plan and review-code | `.claude/skills/plan-task/**`; `.claude/skills/review-plan/**`; `.claude/skills/review-code/**` | port | no | none | Not in our plan-task or review-code |
| 16 | Project `AGENTS.md` template and rollout (fork ADR-0017), Copilot review guidance | `docs/decisions/0017-*.md (1)`; `.agent/templates/project_agents_md.md`; `.agent/templates/project_agents_guide.md`; `.agent/templates/project_governance.md`; `.github/copilot-instructions.md`; `.github/instructions/work-plans.instructions.md` | port | no | `.agent/templates/project_agents_guide.md`; `.agent/templates/project_governance.md`; `.github/copilot-instructions.md` | No `project_agents_md.md` here, no offer in onboard-project; ours Copilot file is an identity stub. Offer only, never forced |
| 17 | Planning-document probe and roadmap template | `.agent/scripts/planning_doc_probe.sh`; `.agent/scripts/tests/test_planning_doc_probe.sh`; `.agent/templates/roadmap.md` | port | no | none | Digest P5/P6b; #335 closed without them |
| 18 | Feature Track issue status reader | `.agent/scripts/read_feature_status.py` | port | no | `.github/ISSUE_TEMPLATE/feature_track.md` | Template here, no reader; the fork's only references are READMEs, consumer unknown |
| 19 | Credential and path redaction helper | `.agent/scripts/redact.sh`; `.agent/scripts/tests/test_redact.sh` | port | no | none | Used by fork manifest scripts (row 1); only needed if reports leave the host |
| 20 | Dependabot and markdown link check | `.github/dependabot.yml`; `.github/markdown-link-check.json` | port | no | none | Neither here |
| 21 | Build and test through layers, with reports | `.agent/scripts/build.sh`; `.agent/scripts/test.sh`; `.agent/scripts/build_report_generator.py`; `.agent/scripts/tests/test_build_report_generator.py` | partly covered | retire-only | `.agent/scripts/build.sh`; `.agent/project_types/ros2_colcon/adapter.sh`; `.agent/scripts/tests/test_ros2_colcon.sh` | Diff read: ours shim to `adapter`; layer order, cascade, stop and continue are tested. Missing: JSON and CSV reports, `colcon test-result` summary, lock check |
| 22 | Makefile chains for a ROS instance: setup-all with stamps, build, test, clean, validate extras | `Makefile`; `.agent/scripts/tests/test_make_validate.sh` | partly covered | retire-only | `Makefile`; `.agent/project_types/ros2_colcon/adapter.sh` | A registered project is set up and built with `adapter setup` and `adapter build`. Missing: stamp re-run when a `.repos` changes, clean of build, install and log, rosdep staleness in validate |
| 23 | Merge a PR and clean up | `.agent/scripts/merge_pr.sh`; `.agent/scripts/tests/test_merge_pr.sh` | partly covered | no | `.agent/scripts/merge_pr.sh`; `.agent/scripts/tests/test_merge_pr.sh` | Diff read: ours is far ahead. Fork-only: exit 3 for "merged, a later step failed", so a caller does not retry a landed merge |
| 24 | Cross-model reviewer helpers | `.agent/scripts/_agy_review.sh`; `.agent/scripts/_cli_review.sh`; `.agent/scripts/cross_model_review.sh`; `.agent/scripts/_plan_approach.py`; `.agent/scripts/_resolve_default_branch.sh`; `.agent/scripts/_resolve_work_plans_dir.sh`; `.agent/scripts/tests/test_cross_model_review.sh` | partly covered | no | `.agent/scripts/cross_model_review.sh`; #363 | Diffs read: #363's fixes are here. Fork-only: full closing-keyword set (ours: closes, fixes, resolves), codex `env -i` allowlist, default-branch preference when local is behind |
| 25 | git-bug helpers and issue creation over every overlay repo | `.agent/scripts/git_bug_setup.sh`; `.agent/scripts/gitbug_helpers.sh`; `.agent/scripts/gh_create_issue.sh` | partly covered | no | `.agent/scripts/_issue_helpers.sh`; `.agent/scripts/git_bug_setup.sh`; `.agent/scripts/gh_create_issue.sh` | Diffs read: fork bridges every package repo, ours the workspace and `project/`; git-bug is optional here |
| 26 | Git identity in every package repo | `.agent/scripts/configure_git_identity.sh`; `.agent/scripts/set_git_identity_env.sh`; `.agent/scripts/detect_agent_identity.sh`; `.agent/scripts/detect_cli_env.sh`; `.agent/scripts/framework_config.sh`; `.agent/scripts/test_identity_introspection.sh`; `.agent/scripts/tests/test_detect_cli_env.sh` | partly covered | no | `.agent/scripts/set_git_identity_env.sh`; `.agent/scripts/configure_git_identity.sh` | Diffs read: our env script exports `GIT_AUTHOR_*`, so package commits still carry the agent; fork-only is the per-repo config loop |
| 27 | Review-loop skills of the same name | `.claude/skills/address-findings/**`; `.claude/skills/plan-task/**`; `.claude/skills/review-issue/**`; `.claude/skills/review-plan/**`; `.claude/skills/review-code/**`; `.claude/skills/triage-reviews/**`; `.claude/skills/run-issue/**` | partly covered | no | `.claude/skills/run-issue/SKILL.md`; `.claude/skills/triage-reviews/SKILL.md` | Diffs read: ours is ahead. Fork-only parts are rows 2, 4, 15 and declined container mode |
| 28 | Audit and maintenance skills of the same name | `.claude/skills/audit-project/**`; `.claude/skills/audit-workspace/**`; `.claude/skills/issue-triage/**`; `.claude/skills/inspiration-tracker/**`; `.claude/skills/onboard-project/**`; `.claude/skills/gather-project-knowledge/**`; `.claude/skills/research/**`; `.claude/skills/brainstorm/**`; `.claude/skills/brand-guidelines/**`; `.claude/skills/skill-importer/**` | partly covered | no | `.claude/skills/audit-workspace/SKILL.md`; `.claude/skills/audit-project/SKILL.md`; #366; #367 | Fork-only: audit-workspace coverage line per section, audit-project layer and colcon checks (adapter). #366 and #367 are open here too |
| 29 | Janitor sweep and its health report | `.claude/skills/janitor-sweep/**`; `docs/health.md` | partly covered | no | `.claude/skills/sitrep/SKILL.md`; `.agent/scripts/sitrep_checks.sh` | The sit-rep gives due audits and stale docs per root; no chained report, no published `health.md`, no run-over-run diff |
| 30 | Onboarding, identity strategy, AI rules and Gemini notes; multi-agent etiquette | `.agent/AGENT_ONBOARDING.md`; `.agent/AI_IDENTITY_STRATEGY.md`; `.agent/AI_RULES.md`; `.agent/instructions/gemini-cli.instructions.md`; `.agent/WORKFORCE_PROTOCOL.md` | partly covered | no | `.agent/AGENT_ONBOARDING.md`; `.agent/AI_IDENTITY_STRATEGY.md`; `.agent/WORKFORCE_PROTOCOL.md` | Diffs read. Fork-only: dirty-worktree-means-hands-off, shared-host etiquette (unique `ROS_DOMAIN_ID`), per-commit `-c` identity pattern |
| 31 | Label list for issue and PR scripts; planning-document vocabulary draft | `.agent/github_metadata.json`; `docs/design/planning_document_vocabulary.md` | partly covered | no | `.agent/scripts/gh_create_issue.sh`; `docs/design.md` | Our scripts read `.agent/github_metadata.json` but the file is absent here, so labels go unchecked with a warning. The vocabulary draft was read by its head only |
| 32 | Package worktrees holding work found nowhere else | `layers/` | belongs to a project repository | retire-only | none | Read with `--no-optional-locks` against the local remote refs (no fetch). 14 with commits on no remote ref (udp_bridge 75: 24, unh_marine_autonomy 304: 10, udp_bridge 64: 9, cube_bathymetry 44: 8, ten with 1 to 3), 1 (marine_tools 64) with 6 modified files; 3 more hold only untracked review files. Today's cube_bathymetry 173 worktree is not counted |
| 33 | Scratchpad of field-data work | `.agent/scratchpad/** (325)` | belongs to a project repository | retire-only | none | 324 untracked files (udp_bridge topic analysis, zigzag track, backscatter, handoff logs) plus the README; copy the wanted ones before deleting the checkout |
| 34 | Bag analysis and field-failure diagnosis knowledge | `.agent/knowledge/bag_analysis.md`; `.agent/knowledge/diagnosis_discipline.md` | belongs to a project repository | retire-only | none | project11 operations knowledge; goes to the project's `.agents/` |
| 35 | project11 data and host safety rules: no change to raw bags or `~/data/logs`, no administering field hosts | `AGENTS.md` | belongs to a project repository | retire-only | none | Goes to project11's own `AGENTS.md` |
| 36 | Package repos' `AGENTS.md` point at the fork for shared rules | `layers/` | belongs to a project repository | retire-only | none | 10 of 45 package repos in `layers/main` carry an `AGENTS.md`; all 10 name ros2_agent_workspace |
| 37 | Package checkouts of the instance | `layers/` | belongs to a project repository | no | `tools/ros-manifest/` | 7 layers, 45 package repos; pickerel makes its own from the manifest (row 1) |
| 38 | Package worktrees with nothing local | `layers/` | belongs to a project repository | no | none | 22 issue checkouts with no commit missing from the remotes and no changes; delete at cutover. Every other repo checkout in each worktree folder was on a clean branch with nothing ahead |
| 39 | Local CI runner in a container, attestation as merge gate (fork ADR-0018), per-package verify | `.agent/scripts/ci_local.sh`; `.agent/scripts/tests/test_ci_local.sh`; `.agent/scripts/verify_change.sh`; `docs/decisions/0018-*.md (1)` | decline | no | `.agent/project_types/ros2_colcon/adapter.sh` | Containers are declined; roadmap Deferred `local-ci-attestation-verb` keeps the idea. `adapter test` forwards package arguments |
| 40 | Container dispatch, agent image, devcontainer (fork ADR-0019) | `.agent/scripts/dispatch_subagent.sh`; `.agent/scripts/test_dispatch_subagent.sh`; `.agent/scripts/tests/test_dispatch_model.sh`; `.agent/scripts/tests/test_dispatch_worktree_resolution.sh`; `.agent/scripts/docker_run_agent.sh`; `.agent/scripts/tests/test_docker_run_mount_args.sh`; `.agent/scripts/tests/test_entrypoint_chown_coverage.sh`; `.agent/scripts/tests/test_agent_image_build_paths.sh`; `.agent/scripts/stage_rosdep_manifests.sh`; `.devcontainer/** (7)`; `docs/decisions/0019-*.md (1)` | decline | no | `docs/decisions/0014-in-process-phase-handoff.md`; `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md` | In-process dispatch here; Makefile `agent-*` targets go with it |
| 41 | tmux agent launcher | `.agent/scripts/agent`; `.agent/scripts/tmux_app.sh` | decline | no | `.agent/scripts/agent` | Diff read: fork adds `launch`; worktree entry here is `/start-task`; the tmux ATC protocol is already in Decided Against |
| 42 | Web dashboard | `.agent/tools/dashboard/** (20)` | decline | no | `.agent/scripts/dashboard.sh` | CLI first; the digest records not porting it |
| 43 | Local Ollama adversarial reviewer | `.agent/scripts/local_review.sh` | decline | no | none | Did not fit the hardware (fork issue 605) |
| 44 | Layer symlink and source-artifact hooks, `scripts` symlink | `.agent/hooks/check-source-artifacts.py`; `.agent/hooks/post-checkout`; `scripts` | decline | no | `docs/decisions/0012-worktree-composition-is-an-adapter-concern.md` | Worktrees are composed by the adapter, no `layers/` symlinks; package repos carry their own hooks |
| 45 | Identity files | `.agent/.identity.template`; `.agent/.identity` | decline | no | `.agent/scripts/set_git_identity_env.sh` | Identity is set from arguments each session |
| 46 | Fork's digest of this repository | `.agent/knowledge/inspiration_agent_workspace_digest.md` | decline | no | none | A record about this tree; nothing to carry |
| 47 | Fork workspace worktree and open pull requests | `.workspace-worktrees/` | decline | no | `.agent/scripts/merge_pr.sh` | `issue-workspace-610` pushed and clean; it is the branch of rolker/ros2_agent_workspace#657 (parked merge classification). rolker/ros2_agent_workspace#663 is a dependabot bump. Close both at cutover |
| 48 | Records: work plans, work artifact, presentation, code-workspace file | `.agent/work-plans/** (190)`; `.agent/work-artifacts/** (1)`; `presentations/** (5)`; `project11.code-workspace` | decline | no | none | Tracked, so the archived fork keeps them; the work plans were scanned by structure only |
| 49 | Machine-local state | `.rosdep/`; `.make/`; `.venv/`; `.pytest_cache/`; `.claude/worktrees/`; `.claude/.cc-writes/` | decline | no | none | Stamps, caches and two empty folders; pickerel makes its own |
| 50 | Shared decisions: fork ADR 0001 to 0007, 0009, 0010, 0012, 0013, 0015, 0016 | `docs/decisions/000[1-7]-*.md (7)`; `docs/decisions/0009-*.md (1)`; `docs/decisions/0010-*.md (1)`; `docs/decisions/0012-*.md (1)`; `docs/decisions/0013-*.md (1)`; `docs/decisions/0015-*.md (1)`; `docs/decisions/0016-*.md (1)` | already covered | no | `docs/decisions/0008-permit-cross-reference-addendums-in-adrs.md`; `docs/decisions/0010-git-bug-is-optional.md`; `docs/decisions/0013-progress-md-entry-type-vocabulary.md`; `docs/decisions/0014-in-process-phase-handoff.md`; `.agent/project_types/ros2_colcon/adapter.sh` | Read in pairs: fork 0012 is ours 0008; 0015 is replaced by ours 0014 and 0015; 0016 runtime layer chaining is the adapter (`test_env_chain_order`; the build-pollution case has no named test) |
| 51 | ROS layer setup and environment; `AGENTS.md` build rules | `.agent/scripts/setup_layers.sh`; `.agent/scripts/setup.sh`; `.agent/scripts/setup.bash`; `.agent/scripts/test_layer_sourcing.sh`; `AGENTS.md` | already covered | no | `.agent/project_types/ros2_colcon/adapter.sh`; `.agent/scripts/tests/test_ros2_colcon.sh` | Same flow, distro from the manifest; tests `test_setup_bootstrap_env_url_wins`, `test_env_chain_order`; per-layer `--symlink-install` |
| 52 | Workspace root from a layer worktree | `.agent/scripts/workspace_root.sh`; `.agent/scripts/tests/test_workspace_root.sh` | already covered | no | `.agent/scripts/session_root.sh`; `.agent/scripts/tests/test_session_root.sh` | The registry names every root (ADR-0016) |
| 53 | Package and layer worktrees: create, enter, list, remove | `.agent/scripts/worktree_create.sh`; `.agent/scripts/worktree_enter.sh`; `.agent/scripts/worktree_list.sh`; `.agent/scripts/worktree_remove.sh`; `.agent/scripts/_worktree_helpers.sh`; `.agent/scripts/tests/test_worktree_create.sh`; `.agent/scripts/tests/test_worktree_remove.sh` | already covered | no | `.agent/scripts/worktree_create.sh`; `.agent/scripts/tests/test_ros2_colcon.sh` | Diffs read: composed from adapter verbs (ADR-0012); the PR base is row 2 |
| 54 | Shared workflow scripts where this tree is ahead or identical | `.agent/scripts/lib/__init__.py`; `.agent/scripts/lib/git_helpers.sh`; `.agent/scripts/check_branch_updates.sh`; `.agent/hooks/check-branch-updates.py`; `.agent/scripts/lock.sh`; `.agent/scripts/unlock.sh`; `.agent/scripts/revert_feature.sh`; `.agent/scripts/tests/test_revert_feature.sh`; `.agent/scripts/progress_append.sh`; `.agent/scripts/progress_read.py`; `.agent/scripts/tests/test_progress_append.sh`; `.agent/scripts/tests/test_progress_read.py`; `.agent/scripts/fetch_pr_reviews.sh`; `.agent/scripts/generate_make_skills.sh`; `.agent/scripts/tests/test_generate_make_skills.sh`; `.agent/scripts/tests/run_script_tests.sh`; `.agent/scripts/README.md`; `.agent/hooks/README.md`; `.agent/hooks/.gitkeep`; `.agent/scripts/tests/.gitkeep` | already covered | no | `.agent/scripts/progress_append.sh`; `.agent/scripts/_progress_entry.sh`; `.agent/scripts/lock.sh`; `.agent/scripts/revert_feature.sh`; `.agent/scripts/generate_make_skills.sh` | Diffs read: fork-only lines are older code. No tests here for `revert_feature` or `generate_make_skills` |
| 55 | Generated `make_*` slash commands | `.claude/skills/make_* (17)` | already covered | no | `.agent/scripts/generate_make_skills.sh` | Ours generates its own from its Makefile |
| 56 | Issue, PR, plan, ADR and test templates | `.agent/templates/ISSUE_PLAN.md`; `.agent/templates/adr_template.md`; `.agent/templates/ai-review.yml`; `.agent/templates/improvement_issue.md`; `.agent/templates/knowledge_update_issue.md`; `.agent/templates/pr_template.md`; `.agent/templates/testing/** (3)`; `.github/ISSUE_TEMPLATE/feature_track.md`; `.github/PULL_REQUEST_TEMPLATE.md` | already covered | no | `.agent/templates/pr_template.md`; `.github/PULL_REQUEST_TEMPLATE.md` | Compared: identical or differing only by layer wording |
| 57 | Pre-commit configuration and CI jobs (lint, required docs, script tests) | `.pre-commit-config.yaml`; `.github/workflows/validate.yml` | already covered | no | `.pre-commit-config.yaml`; `.github/workflows/validate.yml` | Diffs read: ours has more hooks; fork-only jobs are the link check (row 20) and the author check (row 12) |
| 58 | Dev-tool requirements | `requirements.txt` | already covered | no | `requirements.txt` | Fork adds playwright for the declined web dashboard |
| 59 | Makefile targets in both | `Makefile` | already covered | no | `Makefile` | help, dashboard, lock, unlock, pr-triage, revert-feature, merge-pr, generate-skills, skip-git-bug |
| 60 | Generic knowledge files of the same name | `.agent/knowledge/README.md`; `.agent/knowledge/principles_review_guide.md`; `.agent/knowledge/review_depth_classification.md`; `.agent/knowledge/skill_workflows.md`; `.agent/knowledge/research_digest.md`; `.agent/knowledge/vscode_setup.md`; `.agent/knowledge/inspiration_registry.yml` | already covered | no | `.agent/knowledge/principles_review_guide.md`; `.agent/knowledge/skill_workflows.md` | Diffs read: fork-only lines are layer wording, container advice, janitor rows |
| 61 | Roadmap, `CLAUDE.md` steps, principles, scratchpad README | `ROADMAP.md`; `CLAUDE.md`; `docs/PRINCIPLES.md`; `.agent/scratchpad/README.md` | already covered | no | `docs/roadmap.md`; `CLAUDE.md`; `docs/principles.md`; `.agent/scratchpad/README.md`; #260 | The fork's open roadmap rows are its open issues, triaged by #260 |

## Closed-since-fork issues

The 34 fork issues closed since 2026-07-01, each against its row:

- Row 1: rolker/ros2_agent_workspace#582, rolker/ros2_agent_workspace#609
- Row 6: rolker/ros2_agent_workspace#654, rolker/ros2_agent_workspace#659
- Row 14: rolker/ros2_agent_workspace#586
- Row 15: rolker/ros2_agent_workspace#596
- Row 16: rolker/ros2_agent_workspace#563
- Row 27: rolker/ros2_agent_workspace#470, rolker/ros2_agent_workspace#570, rolker/ros2_agent_workspace#590, rolker/ros2_agent_workspace#592, rolker/ros2_agent_workspace#594, rolker/ros2_agent_workspace#605, rolker/ros2_agent_workspace#660
- Row 29: rolker/ros2_agent_workspace#569, rolker/ros2_agent_workspace#628, rolker/ros2_agent_workspace#634, rolker/ros2_agent_workspace#635, rolker/ros2_agent_workspace#649, rolker/ros2_agent_workspace#651, rolker/ros2_agent_workspace#652
- Row 39: rolker/ros2_agent_workspace#573, rolker/ros2_agent_workspace#575, rolker/ros2_agent_workspace#577
- Row 40: rolker/ros2_agent_workspace#566, rolker/ros2_agent_workspace#602, rolker/ros2_agent_workspace#604
- Row 50: rolker/ros2_agent_workspace#481, rolker/ros2_agent_workspace#559, rolker/ros2_agent_workspace#607, rolker/ros2_agent_workspace#620
- No row: rolker/ros2_agent_workspace#493 (deleted the fork's push gateway), rolker/ros2_agent_workspace#579 (a field-import run, bookkeeping), rolker/ros2_agent_workspace#632 (closed not planned into the open rolker/ros2_agent_workspace#631, which is #260's)

## Issues to open (owner's call)

None is opened by this audit. Blockers first.

1. **ros2_colcon adapter: set up, sync and validate from the manifest resolver.** Two issues. In this repository: wire `adapter setup`, `sync` and `validate` to `tools/ros-manifest/` so a Rolling instance comes from the new manifest; carries what #267 left open (adapter wiring, vcs2l) and #365. In the project11 repository that holds the manifest today (unh_marine_autonomy, `config/` on its rolling branch; the owner picks): add the project's manifest in the new format, with the Rolling pins (the fixture here was written from the jazzy manifest).
2. **Add to #429: package pull requests take their base branch from the manifest pin.** An edit to #429, not a new issue.
3. **Add to #430: ROS host steps on a fresh machine.** Installing `ros-dev-tools` (colcon, vcstool, rosdep), `rosdep init`, `rosdep update` and `rosdep install` for the instance, in the setup guide or done by the adapter.
4. **Fork cutover: salvage local-only work in the fork checkout.** The 15 package worktrees and 324 scratchpad files, each pushed, copied or dropped. Sub-issue of #262.
5. **Move project11 rules and knowledge out of the fork.** Safety rules, bag analysis and diagnosis into project11's own files, and repoint the ten package `AGENTS.md`. Project repositories; the owner picks which.
6. **ros2_colcon type: ROS 2 knowledge and templates.** Row 4's knowledge and templates, and local rosdep keys (row 6) once a package needs them.
7. **Cross-repository tools enumerate package repositories through `adapter repos`.** `pr_status.sh --all-repos`, `dashboard.sh`, `discover_governance.sh`.
8. **Make targets and build and test reports for a registered ROS project.** Rows 21 and 22.
9. **Port deployment mode.** After field mode (#208, #209).
10. **Small ports from the fork.** Commit-identity hardening (row 12), `merge_pr.sh` exit 3 (row 23), the full closing-keyword set (row 24), the plan-task stale-docs seam (row 15), the `AGENTS.md` hand rules into knowledge (row 14, with #261), the AskUserQuestion hook (row 13), Dependabot and the link check (row 20).

Proposed Decided Against lines (owner's call; not written to the roadmap):

- Container dispatch, the agent image, `.devcontainer/` and the container `ci_local.sh` attestation (fork ADR-0018, ADR-0019): dispatch is in-process here (ADR-0014, ADR-0015); hosted CI stays the merge gate for project repositories. Owner to confirm the CI part.
- The fork's web dashboard: CLI first.
- The local Ollama adversarial reviewer: did not fit the hardware.
- The `agent launch` tmux launcher: worktree entry is `/start-task`.
- The `post-checkout` layer symlink hook and the `scripts` symlink: the adapter composes worktrees (ADR-0012).
- The `.agent/.identity` file: identity is set from arguments each session.

## Counts

Each pass read the fork read only and returned rows with every inventory
entry mapped to one row; the merge grouped them into the 61 rows above.

| Pass | Scope | Inventoried | Classified | Pass rows |
|---|---|---|---|---|
| 1 | Scripts, hooks, templates, tools, tests, Makefile, CI, devcontainer | 174 | 174 | 46 |
| 2 | ADRs, skills, knowledge, instruction files, closed-since-fork issues | 86 | 86 | 32 |
| 3 | Configs, layers, worktrees, work plans, scratchpad, local state, docs | 531 | 531 | 16 |
| Catch-all | Onboarding and identity docs, settings, editor and GitHub templates | 18 | 18 | 10 |
| Total | 454 tracked + 355 untracked | 809 | 809 | 104 |

By class, merged rows: adapter 9, port 11, partly covered 11, belongs to a
project repository 7, decline 11, already covered 12. Day-to-day blockers 3,
retire-only 11, no 47.
