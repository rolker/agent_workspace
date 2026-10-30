---
issue: 332
---

# Issue #332 — onboard-project registers projects and audits workspace integration

## Issue Review
**Status**: complete
**When**: 2026-10-13 13:50 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**Issue**: #332

### Scope Assessment

**Well-scoped?** No, as a single PR; yes as one issue with a split. The 2026-10-13 re-scope (D1 to D5) is clear and I treat it as settled. It now holds four separable deliverables: (1) the per-project file and its validated keys, (2) `register_project.sh`, (3) the `onboard-project` rewrite with the seven-category integration audit, (4) the hygiene checklist moving into `audit-project`. They share a design but not a review: (1) is a parser change with tests, (2) writes the registry and runs the user-tier install, (3) and (4) are skill text plus whatever mechanical checks are pulled into a script.
**Right repo?** Yes. Registry, scripts, skills and design doc are all workspace. The footprint the onboarding offers lands in projects (their repos, their PRs), which the skill already handles by running from the project root.
**Serves**: Light touch on projects (the footprint question, `records=` and `instructions=`, nothing required of a project) and Easy to use (one way to register and onboard) — `docs/design.md#registry-and-adapters`, with `docs/design.md#sessions-and-roots` and `docs/design.md#worktrees` (records) also touched.
**Design picture?** Changes it. The issue names "Registry and adapters" and "Sessions and roots". It does not name the Worktrees Target, which proposes `location` and `tracking` settings "in its registry entry"; D2 replaces that with one `records=` key in the project file, and the registry line stays an index. The owner's decisions are recorded, so I do not re-ask them; the gap is the third section (Action 1).
**Dependencies**: #330 (scoped `validate`): CLOSED, so the "registration works" check can mean something. #345 (plugin tier, PR #392): CLOSED, and `user_tier_install.sh` already enables the plugin per registered root, which ADR-0018 says registration reuses by re-running the installer. #335 (design doc): CLOSED. #265 (hosted projects anywhere): OPEN, PRs 1 to 3 merged, PR 4 not; PR 4's plan scopes `register_project.sh` and a `/register-project` bootstrap command, which overlaps this issue (Action 6). #331 (research skill in project sessions): OPEN; it blocks category 7 of the audit and gz4d's `research` only, not this work. #310 (mixed-flavour projects) and #295 (workspace as a registered project): OPEN, related to the Target text and not blocking.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | The change must update four places in `docs/design.md` in the same PR: "Registry and adapters" Now ("Registration is by hand") and its Target ("Proposed: `onboard-project` is the one way a project is registered"), "Sessions and roots" Target (`register_project.sh` listed as PR 4), and the Worktrees Target, whose `location`/`tracking` pair in the registry entry is replaced by D2's `records=` key in `.agent/projects.d/<name>`. Open question C4 is answered yes by D1 and is closed in the same change. The issue names the first two sections only. |
| Leave in a project only what it chose to carry / A change includes its consequences (records) | Action needed | `records=workspace` and `records=local` cannot be honoured by the code as it is: `progress_append.sh` (line 87), `review_progress.sh` (112, 268, 290), `dispatch_phase.sh` (362, 364, 407, 499) and `merge_pr.sh` (682, 839) each build `<worktree>/.agent/work-plans/issue-N/progress.md` themselves, and `_resolve_work_plans_dir.sh` assumes the owning repo's worktree. The design doc already lists this as "mechanism 1: one lookup" and none of it is built. Specific failures: `records=local` puts the path under `.git/info/exclude`, so `progress_append.sh`'s `git add` of it fails, and the file lives in the issue worktree, which `merge_pr.sh` removes, so the history is lost at merge; `records=workspace` needs a per-project key (workspace issue 5 and project issue 5 would both be `issue-5`) and the project-rooted session writing the records is outside its root, against "a session works only under its root" (Sessions and roots) and the rule that every change to the workspace goes through a branch and PR. Until the lookup exists, a stored `records=workspace\|local` would be a setting nothing reads. Build the lookup as its own issue; this issue may validate all three values but must refuse to write (or must flag as not yet honoured) any value other than `project`. |
| Ask about what matters, and show how much (records=workspace) | Action needed | One owner question remains inside decision D2 and is not a reopening of it. D2: "`records=workspace\|local\|project` (the loop's work plans and progress timelines: kept in the workspace keyed by project / in the project under `.git/info/exclude` / committed)". It does not say whether "kept in the workspace" means tracked in the workspace repository or untracked on this machine. Tracked puts a project's plans and reviews into the workspace's remote, which matters for a private project and sits badly with "workspace is project-agnostic"; untracked is the same cost as `local` (one machine, lost with the directory). The answer decides the lookup's design, so ask it first, alone. |
| Enforce what matters, as simply as possible / Only what's needed (command keys) | Action needed | The re-scope drops `projects.d/<name>.sh` and says commands are "keys in the same file, or a pointer to a script", but the named first keys are only `records` and `instructions`, and the adapters still read the `.sh` file: `_single_project_config_file` in `single_project/adapter.sh` sources `ACTIVE_PROJECT_CONFIG` (`adapter` line 243), and `ros2_colcon` reads `MANIFEST_BOOTSTRAP_URL` and `ROS_DISTRO` from it. The registry grammar, which D2 reuses, forbids spaces in values, so `BUILD_CMD="cmake -S . -B build && cmake --build build"` cannot be a key as it stands. Without a decision, the acceptance items "a missing test command is refused" and "reproduce the gz4d fallback finding" cannot be built or tested. The plan must settle: the build/test/install key names, the quoting or script-pointer form, the precedence and migration against an existing `projects.d/<name>.sh` (the owner's p11 files use it), and which adapter code reads the new file. |
| Small steps; step back when they stop converging | Action needed | Split into PRs that can each be reviewed and merged on their own; see the first Recommendation for the split. A single PR would carry a parser change, a new script that writes the registry, two skill rewrites and a design edit. |
| Put each thing at the level it applies to | Action needed | `register_project.sh` is scoped twice. This issue's D1 has `register_project.sh <path> <type>` write the index line and run the user-tier install. The #265 plan (decision 6, files table) and ADR-0016 decision 5 give PR 4 a `register_project.sh --name --type --path [--parent --distro --role]`, a `--remove` that refuses while the root is in use, and a `/register-project` bootstrap command; the design Target repeats "also PR 4". D1 makes the bootstrap command unnecessary (registration runs in a workspace session). Settle which issue owns the script, its flags (parent roots and `ros2_colcon` `setup` must still be reachable) and unregister, and edit the #265 plan so the two do not both build it. |
| Verify before claiming / Test what breaks | Watch | The acceptance line "reproduces every gz4d finding as it was on 2026-09-23" cannot be run against gz4d today in a repeatable way (gz4d is hand-registered and will change under rolker/geozui4d#7). Per the workspace gate rule, script tests use synthetic sandbox projects; the gz4d run is the separate first real use the owner named. |
| Leave a trail | Watch | `.gitignore` already ignores `.agent/projects.d/` (line 12), so the extension-less project file is covered. `projects.local.example` and the `_project_registry.sh` header need the new file's documentation, and `validate_workspace.py` / `dashboard.sh` should report a malformed project file the way they report a malformed registry (fail loud, no silent resolve). |
| Look for prior art before building | OK | The D2 prior-art check (git config, direnv, EditorConfig, systemd conf.d and others) is recorded in the owner's comment. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0011 (adapter contract) | Yes | New project-file keys feed the adapters; `validate_adapter.sh` must still pass. The `single_project` command fallback to `.agent/project_config.sh` is what the register gate is meant to stop relying on. |
| ADR-0013 (progress.md vocabulary) | Yes | `records=` changes where the file is, not its shape; the entry validator and the merge gate's timeline lookup must follow the lookup. |
| ADR-0016 (session roots, user tier) | Yes | Decision 5 (registration is a workspace script) is built here; decision 2 (workspace writes nothing into a project beyond the exclude line and `COLCON_IGNORE`) bounds what onboarding may write; decision 6 (user-tier entries inert outside registered roots) applies to any new promoted script. |
| ADR-0017 (design document) | Yes | Four sections in one change (see Principle Alignment). |
| ADR-0018 (plugin delivery) | Yes | Registration reuses `user_tier_install.sh` rather than a second enable path; the session-root rule (decision 6) is why onboarding runs at the project root. |

### Consequences

- `docs/design.md`: "Registry and adapters", "Sessions and roots", Worktrees Target, Open questions C4, and the Change log row.
- `.agent/projects.local.example`, the `_project_registry.sh` header, and `AGENTS.md` Script Reference (the new script; Ask First applies to `AGENTS.md`).
- `.claude/skills/onboard-project/SKILL.md` (rewrite) and `.claude/skills/audit-project/SKILL.md` (absorbs the checklist). Both still locate the repo as `project/<repo-name>` (step 1 of each), which the registry-only change in #265 PR 4 removes.
- `make generate-user-tier-skills` and `test_plugin_manifest.sh` if a skill's `session_scope` changes.
- Tests: `test_project_registry.sh` (keys, unknown-key refusal), a new `register_project` suite (idempotent re-run, `--dry-run` writes nothing, missing test command refused, failing `validate` blocks "registered"), and the user-tier suites if the installer call changes.
- `.agent/work-plans/issue-265/plan.md` (PR 4 scope) and ADR-0016 decision 5's pointer to PR 4.
- Roadmap: the deferral "a Direction section in the acceptance project's own repository waits until onboarding asks" is resolved by D3 and is edited when the offers list lands.

### Recommendations

- Plan this as four PRs, in this order: (1) the project file reader/validator in `_project_registry.sh` and its tests, with the example file and header documented, and the command-key decision made; (2) `register_project.sh` with `--dry-run`, idempotent adoption of an already-registered project that has no project file (gz4d is hand-registered), unknown keys refused, the user-tier install and the scoped `adapter validate`/`build`/`test` gate; (3) the `onboard-project` rewrite (registry-resolved via `session_root.sh`, footprint question, offers, re-run behaviour from D5); (4) `audit-project` taking the hygiene checklist and skipping items a project's style makes moot. Put the design-doc edits with the PR that makes each statement true.
- Make the integration audit's mechanical categories (ignore rules via `git check-ignore`, paths the workspace writes into the project, same-named skill diffs, adapter verbs succeeding) a script the skill calls, so they are testable and `audit-project` can reuse them report-only; keep only the judgement (instruction-file conflicts, what to port) in the skill text. The re-scope says the existing scope stands, which includes `audit-project` sharing these checks.
- Open a separate issue for the one records lookup (`records=` for every reader and writer, including the merge gate and `_bookkeeping.sh`) and cite it from the design Target; until it lands, onboarding offers and records only `records=project` and says so rather than writing a value nothing reads.
- Treat audit category 7 (skills with no `session_scope`; 9 of the 22 skills have none today, several by intent) as a test or `--check` item that rides with #331, not a per-project audit line, as the original issue already suggests.
- Test with synthetic sandbox projects registered in a temporary workspace root; do not depend on gz4d or any real project checkout. The gz4d onboarding run stays the separate first real use.

### Actions
- [ ] The change must update four places in `docs/design.md` in the same PR: "Registry and adapters" Now ("Registration is by hand") and its Target ("Proposed: `onboard-project` is the one way a project is registered"), "Sessions and roots" Target (`register_project.sh` listed as PR 4), and the Worktrees Target, whose `location`/`tracking` pair in the registry entry is replaced by D2's `records=` key in `.agent/projects.d/<name>`. Open question C4 is answered yes by D1 and is closed in the same change. The issue names the first two sections only.
- [ ] `records=workspace` and `records=local` cannot be honoured by the code as it is: `progress_append.sh` (line 87), `review_progress.sh` (112, 268, 290), `dispatch_phase.sh` (362, 364, 407, 499) and `merge_pr.sh` (682, 839) each build `<worktree>/.agent/work-plans/issue-N/progress.md` themselves, and `_resolve_work_plans_dir.sh` assumes the owning repo's worktree. The design doc already lists this as "mechanism 1: one lookup" and none of it is built. Specific failures: `records=local` puts the path under `.git/info/exclude`, so `progress_append.sh`'s `git add` of it fails, and the file lives in the issue worktree, which `merge_pr.sh` removes, so the history is lost at merge; `records=workspace` needs a per-project key (workspace issue 5 and project issue 5 would both be `issue-5`) and the project-rooted session writing the records is outside its root, against "a session works only under its root" (Sessions and roots) and the rule that every change to the workspace goes through a branch and PR. Until the lookup exists, a stored `records=workspace|local` would be a setting nothing reads. Build the lookup as its own issue; this issue may validate all three values but must refuse to write (or must flag as not yet honoured) any value other than `project`.
- [ ] One owner question remains inside decision D2 and is not a reopening of it. D2: "`records=workspace|local|project` (the loop's work plans and progress timelines: kept in the workspace keyed by project / in the project under `.git/info/exclude` / committed)". It does not say whether "kept in the workspace" means tracked in the workspace repository or untracked on this machine. Tracked puts a project's plans and reviews into the workspace's remote, which matters for a private project and sits badly with "workspace is project-agnostic"; untracked is the same cost as `local` (one machine, lost with the directory). The answer decides the lookup's design, so ask it first, alone.
- [ ] The re-scope drops `projects.d/<name>.sh` and says commands are "keys in the same file, or a pointer to a script", but the named first keys are only `records` and `instructions`, and the adapters still read the `.sh` file: `_single_project_config_file` in `single_project/adapter.sh` sources `ACTIVE_PROJECT_CONFIG` (`adapter` line 243), and `ros2_colcon` reads `MANIFEST_BOOTSTRAP_URL` and `ROS_DISTRO` from it. The registry grammar, which D2 reuses, forbids spaces in values, so `BUILD_CMD="cmake -S . -B build && cmake --build build"` cannot be a key as it stands. Without a decision, the acceptance items "a missing test command is refused" and "reproduce the gz4d fallback finding" cannot be built or tested. The plan must settle: the build/test/install key names, the quoting or script-pointer form, the precedence and migration against an existing `projects.d/<name>.sh` (the owner's p11 files use it), and which adapter code reads the new file.
- [ ] Split into PRs that can each be reviewed and merged on their own; see the first Recommendation for the split. A single PR would carry a parser change, a new script that writes the registry, two skill rewrites and a design edit.
- [ ] `register_project.sh` is scoped twice. This issue's D1 has `register_project.sh <path> <type>` write the index line and run the user-tier install. The #265 plan (decision 6, files table) and ADR-0016 decision 5 give PR 4 a `register_project.sh --name --type --path [--parent --distro --role]`, a `--remove` that refuses while the root is in use, and a `/register-project` bootstrap command; the design Target repeats "also PR 4". D1 makes the bootstrap command unnecessary (registration runs in a workspace session). Settle which issue owns the script, its flags (parent roots and `ros2_colcon` `setup` must still be reachable) and unregister, and edit the #265 plan so the two do not both build it.
- [ ] Plan this as four PRs, in this order: (1) the project file reader/validator in `_project_registry.sh` and its tests, with the example file and header documented, and the command-key decision made; (2) `register_project.sh` with `--dry-run`, idempotent adoption of an already-registered project that has no project file (gz4d is hand-registered), unknown keys refused, the user-tier install and the scoped `adapter validate`/`build`/`test` gate; (3) the `onboard-project` rewrite (registry-resolved via `session_root.sh`, footprint question, offers, re-run behaviour from D5); (4) `audit-project` taking the hygiene checklist and skipping items a project's style makes moot. Put the design-doc edits with the PR that makes each statement true.
- [ ] Make the integration audit's mechanical categories (ignore rules via `git check-ignore`, paths the workspace writes into the project, same-named skill diffs, adapter verbs succeeding) a script the skill calls, so they are testable and `audit-project` can reuse them report-only; keep only the judgement (instruction-file conflicts, what to port) in the skill text. The re-scope says the existing scope stands, which includes `audit-project` sharing these checks.
- [ ] Open a separate issue for the one records lookup (`records=` for every reader and writer, including the merge gate and `_bookkeeping.sh`) and cite it from the design Target; until it lands, onboarding offers and records only `records=project` and says so rather than writing a value nothing reads.
- [ ] Treat audit category 7 (skills with no `session_scope`; 9 of the 22 skills have none today, several by intent) as a test or `--check` item that rides with #331, not a per-project audit line, as the original issue already suggests.
- [ ] Test with synthetic sandbox projects registered in a temporary workspace root; do not depend on gz4d or any real project checkout. The gz4d onboarding run stays the separate first real use.

## Checkpoint
**Status**: complete
**When**: 2026-10-13 13:49 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

"Proceed" with the Issue Review (20cbbd3c) actions A1 (four PRs: project file + keys; register_project.sh; onboard-project rewrite; audit-project takes the hygiene checklist; design-doc edits travel with the PR that makes each true), A2 (the records lookup becomes its own issue; this issue validates every records= value but writes only `project` until it lands), A3 (the plan settles command keys: names, quoting or script pointer, precedence over existing projects.d/<name>.sh), A4 (#332 owns register_project.sh incl. unregister and adopting a hand-registered project; #265 PR 4 shrinks to retiring project/ and projects/), and the recommendations (audit categories in a script both skills call; category 7 folds into #331; tests on synthetic projects only; both skills stop looking under project/<name>).

Action 3 answered alone (D2a), owner verbatim: "I'm leaning 2. It makes no sense to commit with the workspace. I think I had discussed the possibility of a separate repo as well. This would allow tracking for a zero footprint repo. It could be setup so the project dir holds the clone as a child dir, and the clone of the repo for records as a sibling for instance. All of this should be flexible at onboard time, but provide reasonable defaults." Recorded as: records never go into the workspace repository. Places: committed in the project; in the project but ignored; a separate records repository (tracked; default layout a hosting directory holding the project clone and the records clone as sibling children); untracked on this machine. Chosen at onboarding with defaults: `project` when the project accepts footprint, machine-local for zero footprint, the records repo as the opt-in that adds tracking. The plan proposes the exact key values and the layout.

## Plan Authored
**Status**: complete
**When**: 2026-10-13 13:55 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-332/plan.md` at `8b6d7a41`

Four-PR plan: (1) per-project file `.agent/projects.d/<name>` with a validated key list (build/test/install/bootstrap_url, location/location_path/tracking, instructions); (2) register_project.sh with registration_verify.sh, unregister and adoption; (3) onboard-project rewrite with a shared integration-audit script; (4) audit-project takes the hygiene checklist. Builds on the Worktrees Target in docs/design.md (location/tracking, moved to the per-project file); the records lookup is a separate follow-up issue and category 7 rides with #331.

## Plan Review
**Status**: complete
**When**: 2026-10-13 13:59 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: needs-work

**Issue**: #332 — onboard-project registers projects and audits workspace integration
**Plan**: `.agent/work-plans/issue-332/plan.md` at `8b6d7a41`
**Branch**: `feature/issue-332`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four PRs in the owner's order (A1), lookup as a separate issue (A2). PR 2 and PR 3 are large but each is one job; the owner fixed the split, not reopened here |
| Issue alignment | Needs work | Serves, as checked: "Light touch on projects and Easy to use (`README.md#workspace-goals`); `docs/design.md#registry-and-adapters`, with `docs/design.md#sessions-and-roots` and `docs/design.md#worktrees`" (both goal headings exist in README.md). Issue Review actions A1 to A4 are each answered. Gaps: the default records place and layout are written as decided (finding 1, owner note 2026-10-13: "where the defaults should be is not settled even in my mind"); the plan supersedes a recorded owner stance on its own (finding 2); the issue's gz4d acceptance item has no test mapping (finding 9) |
| File targeting | Good | Every cited helper exists (`uninstall_plugin_from` line 826, `registry_require_root` 542, `registry_entries_full` 71, `wt_ensure_exclusion`, `_settings.sh`, `check_design_anchors.sh`, the four test suites, `make generate-user-tier-skills`, `.agent/work-plans/issue-265/plan.md`). PR 1's new `project_setting.sh` has no AGENTS.md row planned (finding 8) |
| Consequences | Needs work | The gate's rollback leaves the plugin enabled in the root (finding 4); `registration_verify.sh --run` breaks the inert marker's contract (finding 5) |
| Principle alignment | Needs work | Name the rule before bending it: the session-root rule is bent twice without being named (finding 3); Keep one current design: defaults recorded as decided (finding 1) |
| ADR compliance | Good | ADR-0011 (verbs unchanged), 0013, 0016 decision 5 and 6, 0017, 0018 addressed; 0016 decision 6 needs finding 5 |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Issue alignment / Keep one current design] (must-fix)** — The plan writes the default records layout and the zero-footprint default as decided: the `location_path` row ("default the sibling `<project clone>-records` in the clone's parent directory (D2a layout: ...)"), Approach 4 ("(outside, untracked), the default for zero footprint"), PR 1 step 8 ("the D2a layout sentence" in the Target) and Q1 ("Confirm the first"). Owner, 2026-10-13: the defaults are not settled. Also the parenthetical misattributes: D2a's words describe a hosting directory holding both clones, not the clone's parent. Resolution: keep the mechanism (two settings, four combinations, `location_path` any absolute path) and hold the derived default in one function in `_project_registry.sh` that the validator, the audit and the later lookup all call; tests assert through that function, not a literal path; the design text and onboarding wording mark the default place and layout as provisional and overridable. Keep the registered root the project clone (no reason found that forces a change; see finding 3 for the one pressure toward the hosting directory).
2. **[Issue alignment] (must-fix, owner decides)** — Approach 4 refuses a `location_path` inside the workspace checkout and says this "supersedes the Target's 'don't prohibit' sentence". A plan cannot supersede a recorded owner stance; the owner's D2a words ("It makes no sense to commit with the workspace") are about committing, and the checkpoint recorded "records never go into the workspace repository". A directory check is a proxy for that and misses both ways: it refuses an untracked records directory under the workspace's ignored area (not a commit), and it passes `tracking=repo` with a separate clone of the workspace repository elsewhere (a commit into the workspace repository). Put to the owner: hard refusal of tracking in the workspace repository (checked by the remote, not the directory), or default plus warning.
3. **[Principle alignment: Name the rule before bending it] (must-fix)** — "A session works only under its root" (Sessions and roots Now; `session_root.sh` header) is bent in two places the plan does not name: `project_setting.sh set` from a project session writes `.agent/projects.d/<name>` in the workspace checkout (PR 3's onboarding answers), and any `location=outside` records path is outside the project-clone root by definition. Resolution: PR 3's design edit states the first as a named exception (per-machine, gitignored workspace config the project session owns); the follow-up issue text states that the records location counts as the root's own, as a `worktrees=` override already does (`registry_worktree_dir`, `session_root.sh`), or names the alternative.
4. **[Consequences] (must-fix)** — PR 2's gate runs `user_tier_install.sh` (which enables the plugin in the root's `.claude/settings.local.json`) and then, with `--run`, build and test; a newly added entry that fails is rolled back "line and file" only, leaving the plugin enabled in an unregistered directory. Resolution: run the installer only after build and test pass, or have the rollback call the new `--disable-root`; add the case to `test_register_project.sh`.
5. **[ADR compliance: ADR-0016 decision 6] (must-fix)** — `registration_verify.sh` is planned as `# user-tier: inert` and promoted in PR 3, but `--run` executes the project's build and test, which is not "only reads and prints" (`user_tier_scripts.txt` header). Resolution: keep `registration_verify.sh` read-only (no `--run`) and let `register_project.sh` run `adapter build`/`test` itself, or give it a real `registry_require_root` guard and drop the inert marker.
6. **[Consequences] (suggestion)** — The follow-up issue text carries mechanisms 1 to 3 and the acceptance test by shape, but drops the Target's second half ("which a project with pull requests has to exercise"), the one rule, and two unsettled points: for `tracking=repo`, who commits to the records repository, on which branch and when it is pushed; and `cross_model_review.sh --work-plans-dir` and package-repo issues as existing override and no-timeline cases. Add them, and open the issue before PR 1 so `project_setting.sh`'s refusal and the Target edit cite its number.
7. **[Principle alignment: Put each thing at the level it applies to] (suggestion)** — `registration.conf` is consistent with "workflow scripts do not branch on the project type" (Q2 confirmed), but nothing checks it exists: say `register_project.sh` refuses a type without one, add the check to `validate_adapter.sh` or a test, and name the file in the Registry and adapters Now bullet beside the verb contract.
8. **[File targeting] (suggestion)** — PR 1 adds `project_setting.sh` but the AGENTS.md Script Reference rows are planned only in PR 2 and PR 3; add PR 1's row in its own commit (Ask First), or say why it waits.
9. **[Issue alignment: Test what breaks] (suggestion)** — Add a table mapping each issue acceptance item to its test, and make `test_integration_audit.sh`'s fixture a synthetic project shaped like gz4d on 2026-09-23 (same-named skills, branch-not-worktree instruction, unignored `worktrees/`, unanchored `build/` hiding `.claude/skills/build/SKILL.md`, no `.agents/`, a `docs/work-plans/`), so "reproduces every finding" is a test, not the first real run.
10. **[Issue alignment: Q4] (suggestion)** — Q4's default (an existing `docs/roadmap.md` or `ROADMAP.md`, else create `docs/roadmap.md`) fits design.md line 127 ("A project's roadmap may carry a `## Direction` section ... by its own choice"). State that the agent-guide and Direction offers are made only when `instructions=tracked` (Approach says only audit findings become `info`), and note in the sit-rep follow-up row that a project's roadmap may be `ROADMAP.md`.

Q3 confirmed: `audit-project` is report-only today and D5 says nothing changes without a yes, so report-only with the fix flow offered at the end keeps the hygiene fixes owned.

### Summary

The plan builds on the Worktrees Target as required, honours A2 without building the lookup (the dispatcher reads only command and URL keys; only (project, project) is written), and its line numbers and helpers check out. Five must-fixes before implementation: defaults written as decided, a recorded owner stance superseded by the plan, the session-root rule bent without being named, an incomplete rollback, and a promoted script that is not inert.

### Recommended Actions

- [ ] Hold the default records place and layout in one function, mark them provisional in the design text and onboarding wording, and describe D2a's layout accurately (finding 1)
- [ ] Put the workspace-location question to the owner: refusal checked by the remote, or default plus warning; drop "supersedes" until he answers (finding 2)
- [ ] Name both session-root exceptions in the design edits and the follow-up text (finding 3)
- [ ] Order the installer after build/test or roll back the plugin enable; test it (finding 4)
- [ ] Make `registration_verify.sh` truly read-only or guard it (finding 5)
- [ ] Complete the follow-up issue text and open it before PR 1 (finding 6)
- [ ] Check `registration.conf` exists per type (finding 7); add PR 1's AGENTS.md row (finding 8); add the acceptance-to-test table and the gz4d-shaped fixture (finding 9); gate the offers on `instructions` (finding 10)

## Checkpoint
**Status**: complete
**When**: 2026-10-13 14:03 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

"Revise and re-review": the plan author fixes Plan Review (dc77392d) must-fix M1–M5 and the five suggestions, then a fresh plan review.
Owner answers folded in:
- Defaults are OPEN (owner, during the review: "where the defaults should be is not settled even in my mind"): the mechanism (design.md Worktrees Target: `location`/`tracking`, four combinations, one lookup) is settled; the default combination and the outside-path layout are provisional — one function in the registry helper, overridable at onboarding, marked provisional in design text and onboarding wording (M1).
- Records in the workspace repository: REFUSE (owner answer "Refuse" to the question "May a project's loop records be committed to the agent_workspace repository (any clone of it)?", with the fork/PR scenario: records would ride along with every fork and come back in PRs past the merge gate's bookkeeping exemption). The check is by the named repository's remote URL, not by path; untracked records under the workspace's ignored scratchpad stay allowed. This supersedes the Target's "I don't want to prohibit it, but I also don't want to encourage it" — the PR 1 design edit rewrites that sentence and says why (M2).

## Plan Authored
**Status**: complete
**When**: 2026-10-13 14:06 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Dispatch**: resumed (agent a0a1c30f33fc0db7c, resume 1 of 3)
**Plan**: `.agent/work-plans/issue-332/plan.md` at `754f8675`

Revision 1, after plan review round 1 (dc77392d) and the owner's checkpoint (b9ab8403). Still builds on the Worktrees Target (location/tracking). Records defaults are provisional and held in one function (project_records_default); tracking in the workspace repository is refused by remote URL; both session-root bends are named; the installer runs only after build and test pass; registration_verify.sh is read-only; follow-up issue text is complete; an acceptance-to-test table with a synthetic fixture shaped like the hand-registered gz4d is added. Every finding and its resolution is in the plan's "Plan Review Resolution" section.

## Plan Review
**Status**: complete
**When**: 2026-10-13 14:07 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Dispatch**: resumed (agent a98d6c53c11e1c1af, resume 1 of 3)
**Verdict**: ready

**Issue**: #332 — onboard-project registers projects and audits workspace integration
**Plan**: `.agent/work-plans/issue-332/plan.md` at `754f8675`
**Branch**: `feature/issue-332`

Round 2, after the owner's Checkpoint (b9ab8403) and the revised plan's "Plan Review Resolution" table. Each round-1 finding was checked against the plan text, not the table.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: four PRs in the owner's order; the follow-up issue is now opened as PR 1's first step |
| Issue alignment | Good | Serves, as checked: "Light touch on projects and Easy to use (`README.md#workspace-goals`); `docs/design.md#registry-and-adapters`, with `docs/design.md#sessions-and-roots` and `docs/design.md#worktrees`". Owner decisions of b9ab8403 folded in: defaults open (one function, provisional), workspace repository refused by remote URL, scratchpad untracked allowed, Target sentence rewritten with the fork and PR reason. "Acceptance to test" table added (finding 4 is a gap in it) |
| File targeting | Good | `validate_adapter.sh` and its suite, `--disable-root` in `test_user_tier_install.sh`, AGENTS.md rows in each of PR 1 to PR 3 added |
| Consequences | Good | Registration order now leaves no plugin enable on failure; one open case for `ros2_colcon` `setup` (finding 3) |
| Principle alignment | Good | Both session-root bends named (PR 3 design edit; follow-up text); defaults no longer written as decided |
| ADR compliance | Good | ADR-0016 decision 6: `registration_verify.sh` has no build/test mode, so its inert marker is true |
| ROS conventions | N/A | Workspace plan |

### Round-1 findings, checked in the plan text

- M1 defaults: resolved. `project_records_default` is the one place (PR 1 item 4, Files table); the `location_path` row names both layouts as undecided candidates; Q1 withdrawn with the root kept as the clone; tests assert through the function. See finding 1 for one ambiguity it introduced.
- M2 workspace repository: resolved as the owner decided. `project_records_check` compares remotes, no path rule, scratchpad untracked validates, PR 1 item 9 rewrites the Target sentence with the reason.
- M3 session-root bends: resolved. PR 3 item 3 names the projects.d write; the follow-up's "Rules carried" names the outside-records bend.
- M4 rollback: resolved. Installer is step 4, after the static gate, build and test; an installer failure calls `--disable-root`; the "failing check" acceptance row asserts an empty stub-claude log.
- M5 inert marker: resolved. `registration_verify.sh` is read-only (`--user-tier` only reads); `register_project.sh` runs build and test.
- S6 to S10: resolved (follow-up text has both acceptance halves, the one rule, the unsettled points; `registration.conf` checked by `validate_adapter.sh`; PR 1 AGENTS.md row; acceptance table and fixture; offers gated on `instructions=tracked`).

### Findings

1. **[Issue alignment] (suggestion)** — `project_records_default` takes `accepts-footprint|zero-footprint`, and item 4 says the validator calls it "to fill omitted keys", but nothing stored says which mode a project is in. Then a project file with no records keys means different things depending on an input that is not in the file. State that an absent pair always resolves with the accepts-footprint mode, (project, project) (the Target's default and what every reader does today), and that the zero-footprint mode only feeds onboarding's proposal. Add a `test_project_file.sh` case for it.
2. **[Principle alignment: Enforce what matters] (suggestion)** — Normalising URLs to host and `owner/repo` misses two cases. (a) A remote that is a local path or `file://` URL to the workspace checkout or one of its worktrees, such as `git clone ~/agent_workspace records`. Resolve such a remote and compare it with the workspace's git common dir. (b) The Q5 fork case: facts below; the owner decides.
3. **[Consequences] (suggestion)** — For `ros2_colcon`, `setup` creates the hosting directory when it is missing. The plan does not say where `setup` falls in the four-step order, or whether a directory it created is removed or kept and reported when a later step fails. Say which, and add the case to `test_register_project.sh`.
4. **[Issue alignment: Test what breaks] (suggestion)** — The fixture omits pre-commit and CI, and the table asserts seven audit finding ids. Three of the issue's listed gz4d findings are not reproduced by the script, so name where each is covered:
   - no pre-commit or CI: the `audit-project` checklist in PR 4, which is skill text and not script-tested;
   - `validate` failing because of unrelated projects: fixed by #330;
   - `research` missing in project sessions: category 7 on #331.

   Then "reproduces every finding" claims only what is tested.

### Q5 facts (owner decides)

- A fork keeps the workspace's history, so a clone of any fork shares the workspace's root commit (`git rev-list --max-parents=0 HEAD` gives `c286e7ba` here). Comparing root commits catches forks offline, on any host, with no `gh` call. It misses only a fork whose history was rewritten, and a records repository started fresh never matches. `gh repo view --json parent` sees only GitHub forks and needs network and auth.
- The no-project-names rule is `review only` (design.md Rules) and covers what is committed to the workspace repository. It would catch fork-carried records only when a PR comes back, which is the very path the owner gave as the reason to refuse. It is weak cover for that case, and nothing covers the fork itself.

### Summary

All five round-1 must-fixes and the five suggestions are resolved in the plan text, and the revision follows the owner's checkpoint without reopening it. Four suggestions remain, none blocking. The plan is ready for implementation once the owner answers Q5.

### Recommended Actions

- [ ] State that omitted records keys resolve in accepts-footprint mode, and test it (finding 1)
- [ ] Match local-path and `file://` remotes against the workspace's git dir; put Q5 (root-commit comparison, `gh` parent check, or neither) to the owner (finding 2)
- [ ] Place `ros2_colcon` `setup` in the registration order and state what happens on rollback (finding 3)
- [ ] Name in the acceptance table the gz4d findings not reproduced by the script, and where each is covered (finding 4)

## Checkpoint
**Status**: complete
**When**: 2026-10-13 14:12 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

"Proceed; fold D6, Q5 and the suggestions into the plan first" after Plan Review round 2 (2bf12b40, ready, 0 must-fix, 4 suggestions): implementation of PR 1 starts; its first commit amends the plan with (a) D6 — owner: onboarding work is queued in the project's roadmap when the user approves, "so that it can get tackled maybe as other issues are resolved": the audit's findings and the accepted offers become rows of an "Onboarding" section in the project's roadmap table (docs/roadmap.md or ROADMAP.md; kept with the records for a zero-footprint project), an issue per row when the project uses issues, picked up like any other open row; a pace rule is a later item; PR 3's offers and PR 4's audit outcome gain "queue in the roadmap" beside fix / issue / skip; (b) the four round-2 suggestions (absent records pair resolves to project/project with a test; a local-path or file:// remote pointing at the workspace checkout or a worktree is refused too; where ros2_colcon setup sits in the registration order and what a failure keeps; the acceptance table says where the three gz4d findings are covered); (c) Q5 (fork detection for the records-repo refusal): the owner's answer is being taken separately and the host supplies it in the implement handoff. No third plan review; the pre-push code review sees both.

## Implementation
**Status**: complete
**When**: 2026-10-13 14:49 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Branch**: feature/issue-332 at `4df7317b`

PR 1 of four (the per-project settings file and its keys), after the owner's checkpoint `21c8e15f`.

- `15005ad8` plan amended first: D6 (queue in the roadmap, `## Onboarding` section, issue per row; PR 3 offers and PR 4 audit outcome), Q5 (a records repository must not be a workspace, recognised by its contents beside the remote URL; no lineage check), round-2 suggestions (absent pair is (project, project); local-path and `file://` remotes refused; `ros2_colcon` `setup` between registration steps 1 and 2 with a created hosting directory kept and reported on `KEPT=`; acceptance table names where the three unreproduced gz4d findings are covered).
- Follow-up issue for the records lookup opened first: #393, cited in the refusal message, the design Target and `PROJECT_RECORDS_LOOKUP_ISSUE`.
- `b1612865` `.agent/projects.d/<name>`: parser, validator, one writer and `project_records_default` / `project_records_check` in `_project_registry.sh`; new `project_setting.sh get|set|unset|list|check`; the dispatcher parses the file once and stops on a malformed or refused one; `single_project` and `ros2_colcon` read the keys first and note a fall-through to the shared config; dashboard and `make validate` report a bad file; registry names ending in `.sh` refused; `projects.local.example` documents it; new `test_project_file.sh` (157 assertions, synthetic sandbox projects only).
- `24b14c06` design: Registry and adapters Now bullet; Worktrees Target rewritten (settings in the project file, built in #332 versus #393, defaults provisional, refused combinations, the workspace refusal with its reason, line numbers refreshed); change-log row.
- `4df7317b` AGENTS.md Script Reference row for `project_setting.sh`, its own commit (Ask First, owner approval on the PR).
- Deviations from the plan text, for review: `bootstrap_url` also accepts `file://` (the legacy variable and the tests use it); the legacy `projects.d/<name>.sh`, when present, stays the whole legacy layer (the shared config is consulted only when it is absent), as before #332, rather than falling through per variable.
- Tests: `run_script_tests.sh` all 38 suites passed; shellcheck clean on the changed scripts; design-anchor hook passed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-21 08:29 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `5c68e36e`
**Base**: main
**Depth**: Deep (reason: 1930 changed lines outside work plans, 200+ threshold; AGENTS.md governance file)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Specialists: static analysis (shellcheck clean on 8 scripts; test_project_file.sh 157 passed; run_script_tests.sh 38 suites passed; check_design_anchors.sh passed), governance, plan drift, Claude adversarial, cross-model (gemini complete, codex complete). Merge resolution 5c68e36e checked: both change-log rows kept, no conflict markers, 779 lines matches the file.

### Findings
- [x] (must-fix) Key check matches substrings of the space-separated key list, so `build test=foo` or `location location_path=/x` passes `check` (exit 0) and is then ignored by `get`; `set` writes it too. Compare the whole key exactly in parser and writer, and add a test (codex + Claude adversarial, confirmed by execution) — `.agent/scripts/_project_registry.sh:788`, `:1055`
- [x] (must-fix) Docs say precedence is "the settings file, then the legacy .sh, then the shared config", but the code treats an existing legacy .sh as the whole legacy layer (shared config never consulted, e.g. a legacy file with only BUILD_CMD gets no shared TEST_CMD). The implementation keeps main's behaviour as a declared deviation; state that rule in the docs (or implement per-variable fall-through as the plan said) — `.agent/projects.local.example:86`, `docs/design.md:275`
- [x] (suggestion) Orphan-settings check uses `grep -qx "$_pfname"` (regex, no `--`): `.` matches any character and a leading `-` is read as an option; use `grep -qxF --` (gemini + Claude adversarial) — `.agent/scripts/dashboard.sh:199`
- [x] (suggestion) The writer forces mode 644 on every rewrite and replaces a symlinked settings file with a regular file; keep the original file's mode (confirmed: 600 became 644 after `set`) — `.agent/scripts/_project_registry.sh:1143`
- [x] (suggestion) After the merge the #332 change-log row (dated 2026-10-13) sits below the #395 row (2026-10-15); re-date it to the day this lands so the log's dates run in order — `docs/design.md:726`

## Implementation
**Status**: complete
**When**: 2026-10-21 09:27 -04:00
**By**: Claude Code Agent (claude-opus-4-6)

**Branch**: feature/issue-332 at `c5380cf1`
**Addressed**: Local Review (Pre-Push) at `5c68e36e` (2026-10-21 08:29 -04:00)
**Commits**: `3b9169fc`, `8b047605`, `d714184a`, `7d7507fb`, `c5380cf1`

### Actions
- [x] (must-fix) Composite keys such as `build test` or `location location_path` passed the substring key check: new `_project_file_key_in` compares each listed word exactly; the parser, the writer and the records-key test use it; new `test_composite_keys_refused` (four composite keys, parser and writer; fails on the old code) — `3b9169fc`, `.agent/scripts/_project_registry.sh`
- [x] (must-fix) Precedence docs vs code: the documentation edit, not a code change (host's choice, owner may veto at the publish checkpoint: the whole-layer rule is main's behaviour, the `.sh` reading goes with #265 PR 4, a per-variable fall-through would change legacy behaviour here). `projects.local.example`, `docs/design.md` Registry and adapters, the `adapter` dispatcher header and the `_project_registry.sh` header now say an existing legacy `.sh` is the whole legacy layer; the plan sentence in step 6 is amended to match. Also refreshed the stale `adapter:73` citation of the `single_project` default to `adapter:80` (the PR had moved it) — `8b047605`
- [x] (suggestion) Orphan check now `grep -qxF --`; dashboard test adds an orphan `web.app` beside a registered `webXapp` (missed before), a `-x` file (was a grep usage error) and a dotted registered name's own file (not an orphan) — `d714184a`, `.agent/scripts/dashboard.sh`
- [x] (suggestion) Writer keeps the existing file's mode (GNU or BSD stat; a new file is still 644) and renames onto a symlink's resolved target, so the link stays; with nothing left a symlinked file's target is emptied rather than the link removed; an unresolvable link or a link to a non-regular file is refused; new `test_set_keeps_mode_and_symlink` (fails on the old code) — `7d7507fb`, `.agent/scripts/_project_registry.sh`
- [x] (suggestion) #332 change-log row re-dated 2026-10-21 (now in date order after the #395 row), names the whole-legacy-layer rule and the citation refresh; line count 781, the file's length — `c5380cf1`, `docs/design.md`

Checks: `run_script_tests.sh` all 38 suites passed (472 s); `test_project_file.sh` 206 passed, 0 failed; shellcheck `--severity=warning` (the pre-commit level) clean on `_project_registry.sh`, `dashboard.sh`, `adapter`, `test_project_file.sh`; pre-commit hooks passed on every commit, design-anchor hook included.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-21 09:36 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Dispatch**: resumed (agent a0bc444961900f34f, resume 1 of 3)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `3cf5f537`
**Base**: main
**Depth**: Deep (reason: whole-branch diff ~1,990 changed lines outside work plans, 200+ threshold; AGENTS.md governance file)
**Must-fix**: 2 | **Suggestions**: 6
**Round**: 2 | **Ship**: recommended — round 2: 2 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

Round-1 findings (5c68e36e) all resolved at c5380cf1, checked in the code: whole-key match `_project_file_key_in` with a test; precedence docs state the whole-legacy-layer rule in five places; dashboard `grep -qxF --` with tests; writer keeps mode and symlink with a test; change-log row re-dated, 781 lines matches the file, `adapter:80` citation correct.
Specialists: static analysis (shellcheck --severity=warning clean on 8 scripts; test_project_file.sh 206 passed; run_script_tests.sh 38 suites passed; check_design_anchors.sh passed), governance, plan drift (step 6 amended to the whole-layer rule; no new drift), Claude adversarial (fresh), cross-model (gemini complete, codex complete).

### Findings
- [x] (must-fix) Writer treats an existing path that is not a readable regular file as absent: an unreadable file (mode 000) is overwritten with only the new keys and its settings lost, rc 0 "updated"; a directory at `projects.d/<name>` gets the temp file moved inside it, rc 0 "updated". Refuse when the path (or symlink target) exists and is not a readable regular file, with a test for each (Claude adversarial + codex, both confirmed by execution) — `.agent/scripts/_project_registry.sh:1110`, `:1188`
- [x] (must-fix) `project_setting.sh` resolves `SCRIPT_DIR` and `ROOT` with logical `pwd`, so run through the documented `scripts/` symlink it finds the wrong workspace (from this worktree it read `worktrees/workspace/.agent/projects.local`); use `pwd -P` for both (gemini, confirmed by running both paths) — `.agent/scripts/project_setting.sh:37`, `:47`
- [x] (suggestion) A dangling symlink at `projects.d/<name>` reads as "no file": `check` prints OK, the adapter ignores it, while `set` would create the target; report it as an error, and add tests for the symlink cases the comments claim (dangling, unresolvable, link to link, relative target) — `.agent/scripts/_project_registry.sh:788`
- [x] (suggestion) The writer's read-modify-rename has no lock and no interrupt cleanup: two concurrent `set` calls on one project lose one update, and SIGINT leaves a hidden `.name.XXXXXX` file the dashboard glob skips; serialize with a per-project lock and remove the temp file on exit (codex rated must-fix; Claude adversarial suggestion) — `.agent/scripts/_project_registry.sh:1110`
- [x] (suggestion) `IFS=$'\t' read -r _ _ layout _` collapses an empty layout field, so an unregistered name with `location=outside` gets layout "provisional" and skips the "not registered" error; unreachable today (callers are registered-only); use a non-whitespace delimiter or print the layout last (Claude adversarial, confirmed by execution) — `.agent/scripts/_project_registry.sh:989`
- [x] (suggestion) A command whose first word starts with `-` reaches `exec` as an option (`build=-c make` runs make with an empty environment); use `exec --` or refuse a leading `-` in the value check (Claude adversarial, confirmed by execution) — `.agent/scripts/adapter:307`
- [x] (suggestion) The orphan settings-file check sits inside `if [ -n "$REGISTRY_ENTRIES" ]`, so with no registered project no orphan is reported; move the loop out (gemini) — `.agent/scripts/dashboard.sh:163`
- [x] (suggestion) A file with an unknown or misspelled key cannot be repaired by `set`/`unset` (lines are copied through, `-key` refuses an unknown key); allow `-key` to remove an unknown key or name the hand edit in the error (Claude adversarial) — `.agent/scripts/_project_registry.sh:1075`

## Implementation
**Status**: complete
**When**: 2026-10-21 09:55 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Dispatch**: resumed (agent a8f73bec5a88b2c19, resume 1 of 3)

**Branch**: feature/issue-332 at `cf393f33`
**Addressed**: Local Review (Pre-Push) at `3cf5f537` (2026-10-21 09:36 -04:00)
**Commits**: `fa135945`, `57ad0825`, `664aa88d`, `f70b1cf0`, `bbf97f18`, `80989c7f`, `d5d05a7c`, `1cc8395c`, `cf393f33`

### Actions
- [x] (must-fix) Writer treated an unreadable or non-regular path as absent: new `_project_file_path_error`; the writer refuses (exit 1, file left as it was) when the path or a symlink's target exists but is not a readable regular file; new `test_set_refuses_unusable_path` (a directory, a symlink to one, a mode 000 file, a symlink to one; mode 000 cases skip as root) — `57ad0825`, `.agent/scripts/_project_registry.sh`
- [x] (must-fix) `project_setting.sh` `SCRIPT_DIR` and `ROOT` use `pwd -P`; new `test_run_through_scripts_symlink` runs set and get through a root `scripts` symlink — `fa135945`, `.agent/scripts/project_setting.sh`
- [x] (suggestion) A dangling or unresolvable symlink is an error: the parser reports it (exit 2, so check, the adapter, dashboard and validate stop on it) and the writer refuses it; new `test_symlink_cases` covers dangling, a loop, link to link (final target rewritten, both links kept) and a relative target (kept relative) — `664aa88d`
- [x] (suggestion) Writer body runs in a subshell holding an exclusive flock on the sidecar `projects.d/.lock.<name>` (a lock on the file itself would not exclude the next writer, since the rename replaces its inode), waiting `PROJECT_FILE_LOCK_WAIT` s (default 10) then refusing; unlocked without flock, as `capture.sh`; EXIT/HUP/INT/TERM traps remove the temporary file; new `test_set_lock_and_interrupt_cleanup` (five concurrent writers over three rounds keep every update, a held lock refuses, TERM removes the temporary file; fails on the old code) — `bbf97f18`
- [x] (suggestion) The default layout field is read with `cut -f3`, not a tab `read`; new `test_outside_without_layout_unregistered` — `80989c7f`
- [x] (suggestion) `active_project_exec` uses `exec --`; new `test_command_leading_dash_is_the_command` (a `-dashcmd` command runs; `-c <stub>` fails without running the stub). The legacy/shared path `exec $SP_CMD` is main's code and is unchanged — `d5d05a7c`, `.agent/scripts/adapter`
- [x] (suggestion) Dashboard orphan loop moved out of the registered-entries branch; it runs whenever the registry parsed and is skipped when the registry is malformed (names unknown); new `test_dashboard_orphans_without_registered_projects` — `1cc8395c`, `.agent/scripts/dashboard.sh`
- [x] (suggestion) `unset`/`-key` removes an unknown key the file holds (an unknown key it lacks, and any unknown key on `set`, are still refused); the parser's unknown-key error names `project_setting.sh unset <name> '<key>'` or a hand edit, a duplicate names the hand edit, and the writer's replayed error names the project, not its temporary file; usage text updated; new `test_unknown_key_repair` — `f70b1cf0`

Also, not a finding: `cf393f33` fixes the one precedence comment round 1 missed (the dispatcher's settings-file section in `adapter` still read as a per-variable fall-through); comment only.

Checks: `run_script_tests.sh` all 38 suites passed (289 s); `test_project_file.sh` 278 passed, 0 failed (206 before this round); every new test was run against the code before its fix and failed there; shellcheck `--severity=warning` clean on `_project_registry.sh`, `project_setting.sh`, `dashboard.sh`, `adapter`, `test_project_file.sh`. Intermediate commits used `SKIP=validate-script-tests` as the host allowed; all other hooks ran on each commit.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-21 10:03 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Dispatch**: resumed (agent a0bc444961900f34f, resume 2 of 3)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `8062f779`
**Base**: main
**Depth**: Deep (reason: whole-branch diff past the 200-line threshold; AGENTS.md governance file)
**Must-fix**: 1 | **Suggestions**: 4
**Round**: 3 | **Ship**: recommended — round 3: 1 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

Round-2 findings (3cf5f537) all resolved at cf393f33, checked in the code: writer refuses a path that is not a readable regular file; `pwd -P` (confirmed: through `scripts/` it now reads the main registry); dangling and looping links are errors; flock on a sidecar `.lock.<name>` with subshell-local traps (adversarial confirmed a caller's EXIT trap survives and the temp file goes on SIGTERM); `cut -f3`; `exec --`; orphan check with nothing registered; `unset` repairs an unknown key.
Specialists: static analysis (shellcheck --severity=warning clean on 8 scripts; test_project_file.sh 278 passed; run_script_tests.sh 38 suites passed; check_design_anchors.sh passed), governance, plan drift, Claude adversarial (fresh), cross-model (gemini complete, codex complete).

### Findings
- [x] (must-fix) `ros2_colcon` does not follow the settings contract the docs state for "build/test/install/bootstrap_url": `build=` and `test=` are stored by `set` and never read (colcon builds; silent no-op), and a `MANIFEST_BOOTSTRAP_URL` taken from the shared `project_config.sh` prints no fall-through note. Say in `projects.local.example`, `docs/design.md` Registry and adapters and the registry header that `build`/`test` apply to `single_project` only (or refuse them for a `ros2_colcon` project), print the fall-through note for a shared bootstrap URL, and test both plus `adapter_install` from the settings file (Claude adversarial + codex) — `.agent/project_types/ros2_colcon/adapter.sh:255`, `.agent/projects.local.example:86`
- [x] (suggestion) A settings path that cannot be looked up reads as absent: when `projects.d` is a regular file, a dangling link, or not searchable, `[ -e ]` and `[ -L ]` are both false and the parser returns no settings, so the adapter falls through to the shared config (with the note on single_project); fail closed when the parent exists but is not a searchable directory (codex rated must-fix, confirmed by its probes; the legacy `.sh` lookup has the same pre-existing gap) — `.agent/scripts/_project_registry.sh:835`
- [x] (suggestion) A command whose first word is an environment assignment (`build=CC=gcc make`) validates and is stored, then fails at run time with `exec: CC=gcc: not found` (127); refuse a first word containing `=` with the "point the key at a script" message (Claude adversarial, confirmed by execution) — `.agent/scripts/_project_registry.sh:667`
- [x] (suggestion) The unlocked path the writer's header documents for a machine without `flock` has no test; cover it with a `PATH` lacking `flock` (Claude adversarial) — `.agent/scripts/tests/test_project_file.sh`
- [x] (suggestion) The exit-code header says 2 means the settings file is invalid, but 2 is also returned for a malformed registry; add that case (Claude adversarial) — `.agent/scripts/project_setting.sh:32`

## Checkpoint
**Status**: complete
**When**: 2026-10-21 10:08 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Pre-push round 3 (8370f82b) reached MAX_ROUNDS with 1 must-fix (ros2_colcon stores build/test it never reads; silent bootstrap_url fall-through) and 4 suggestions; ship signal "fix and ship". Owner's answer: "Fix then publish (Recommended)": address all five, one more review on the fixed branch, then publish. Host's mechanism choice, open to veto: refuse build/test for a ros2_colcon project at set time rather than document them as ignored.

## Implementation
**Status**: complete
**When**: 2026-10-21 10:29 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Dispatch**: resumed (agent a8f73bec5a88b2c19, resume 2 of 3)

**Branch**: feature/issue-332 at `050d22a7`
**Addressed**: Local Review (Pre-Push) at `8062f779` (2026-10-21 10:03 -04:00)
**Commits**: `f14d1d52`, `6d0d16f9`, `03196b80`, `8e366331`, `d067f944`, `050d22a7`

### Actions
- [x] (must-fix) ros2_colcon stored build/test it never read, and a shared bootstrap URL was silent. Refusal, not documentation (host's choice, open to the owner's veto): each type lists the keys it never reads, with the reason, in its own data file `.agent/project_types/<type>/unused_settings`, so no script names a type. `set` refuses such a key (exit 1, "colcon owns the build" for ros2_colcon), and the parser, given the type from the registry, reports a hand-written one with file:line and the unset repair, so `check` fails and the adapter stops. Deviation from the host's direction: `install` is NOT refused for ros2_colcon, because `adapter_install` reads it (an optional deploy step after colcon) and the direction also asked to test that read; only `build` and `test` are listed. Same mechanism, not asked for: single_project lists `bootstrap_url` (it never reads it). `_rc_bootstrap_url` now calls `active_project_fallback_note bootstrap_url` for a URL from the shared config. Documented in `projects.local.example`, the registry header and the Registry and adapters bullet (change-log row text and line count 784 refreshed). Tests: `test_type_unused_settings_refused` (refusals, hand edit, repair, ros2_colcon `install` and `install=none` from the settings file) and `test_setup_bootstrap_shared_url_is_reported` in `test_ros2_colcon.sh` (shared URL reported; settings-file and legacy URLs not) — `f14d1d52`, `6d0d16f9`
- [x] (suggestion) A `projects.d` that exists but is not a searchable directory (regular file, dangling link, no search permission) now fails closed: check exits 2, the adapter stops, set refuses with the reason (path checked before the lock); an absent `projects.d` is still "no file"; new `test_unsearchable_settings_dir_fails_closed` — `03196b80`
- [x] (suggestion) A command whose first word contains `=` is refused with the "point the key at a script" message; a later `VAR=value` stays an argument; documented; new `test_command_env_assignment_refused` — `8e366331`
- [x] (suggestion) New `test_set_without_flock_writes_unlocked`: set and unset with a PATH holding every system command except flock succeed and leave no lock or temporary file; it fails against a writer that always takes the lock — `d067f944`
- [x] (suggestion) `project_setting.sh` header: exit 2 also covers a malformed registry; new `test_malformed_registry_exits_2` covers all five commands — `050d22a7`

Checks: `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed every hook, including the full script suite, the adapter contract and the design-anchor check; `test_project_file.sh` 338 passed, 0 failed; `test_ros2_colcon.sh` 200 passed, 0 failed; each new test was run against the code before its fix and failed there; shellcheck `--severity=warning` clean on `_project_registry.sh`, `project_setting.sh`, `adapter`, `ros2_colcon/adapter.sh`, `test_project_file.sh`, `test_ros2_colcon.sh`. Intermediate commits used `SKIP=validate-script-tests` as allowed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-21 10:39 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Dispatch**: resumed (agent a0bc444961900f34f, resume 3 of 3)
**Verdict**: approved

**Branch**: feature/issue-332 at `4a937d4a`
**Base**: main
**Depth**: Deep (reason: whole-branch diff ~2,730 changed lines outside work plans, 200+ threshold; AGENTS.md governance file)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 4 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round-3 findings (8062f779) all resolved at 050d22a7, checked in the code: per-type `unused_settings` data file read by `_project_type_unused_setting` (no script names a type), applied by every reader through `project_file_entries` (adversarial confirmed a hand-written `bootstrap_url` stops a single_project's `build` and `validate`); shared bootstrap URL fall-through note; `projects.d` that is not a searchable directory fails closed; first word `VAR=value` refused; no-flock path tested; exit-code header. Change-log row 784 matches `wc -l`.
For the owner (not findings): `install` stays allowed for ros2_colcon because its `adapter_install` reads it; `bootstrap_url` is now refused for single_project, so a hand-written one stops that project's verbs; `unused_settings` is a second per-type data file beside PR 2's planned `registration.conf` (PR 2 may fold one into the other).
Specialists: static analysis (shellcheck --severity=warning clean on 8 scripts; test_project_file.sh 338 passed; test_ros2_colcon.sh 200 passed; run_script_tests.sh 38 suites passed; validate_adapter.sh passed; check_design_anchors.sh passed), governance, plan drift, Claude adversarial (fresh), cross-model (gemini complete, codex complete).

### Findings
- [x] (suggestion) `unused_settings` fails open when present but unusable: unreadable (mode 000) gives `check` OK and the adapter runs; a CRLF `test\r` line never matches; treat a present-but-unreadable file as an error and strip `\r`, with tests (Claude adversarial, confirmed by execution) — `.agent/scripts/_project_registry.sh:855`
- [x] (suggestion) Nothing validates `unused_settings`: a misspelt key is inert and a line with no reason prints an empty reason; have `validate_adapter.sh` check each line names a known key and has a reason, with a test (Claude adversarial, confirmed by execution) — `.agent/scripts/validate_adapter.sh`
- [x] (suggestion) The AGENTS.md Script Reference row for `project_setting.sh` omits that `set` refuses, and `check` fails, a key the project's type never reads (`unused_settings`), which the design, example file and header all state (Claude adversarial) — `AGENTS.md:408`
- [x] (suggestion) Legacy compatibility: the adapters now clear `BUILD_CMD`/`TEST_CMD`/`INSTALL_CMD` before sourcing the legacy or shared config, so a value inherited from the environment (or a config using `${BUILD_CMD:-make}`) is no longer honoured as on main; no local config relies on it (checked), so name the change in the PR body or keep the inherited value (codex rated must-fix) — `.agent/project_types/single_project/adapter.sh:44`, `.agent/project_types/ros2_colcon/adapter.sh:645`

## Checkpoint
**Status**: complete
**When**: 2026-10-21 10:47 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: publish
**Decision**: address

Pre-push round 4 (7b09bc7e): approved, ship recommended, 0 must-fix, 4 suggestions (unused_settings fails open when unreadable or CRLF; nothing validates unused_settings; the AGENTS.md project_setting.sh row omits the per-type refusal; adapters clear env-inherited BUILD_CMD/TEST_CMD/INSTALL_CMD). Owner's answers: "Fix suggestions, then publish"; the three host choices stand (legacy .sh is the whole legacy layer; per-type unused keys refused, install allowed for ros2_colcon; env-inherited commands cleared); and the AGENTS.md Script Reference row for project_setting.sh (Ask First): "Yes, approve the row".

## Implementation
**Status**: complete
**When**: 2026-10-21 11:02 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Dispatch**: resumed (agent a8f73bec5a88b2c19, resume 3 of 3)

**Branch**: feature/issue-332 at `c00db0c6`
**Addressed**: Local Review (Pre-Push) at `4a937d4a` (2026-10-21 10:39 -04:00)
**Commits**: `8fa23a3f`, `be7878c7`, `fb250aae`, `c00db0c6`

### Actions
- [x] (suggestion) `unused_settings` failing open: `_project_type_unused_setting` returns 2 with the reason when the list exists but is not a readable file, so the parser reports it on the key's line (check fails, the adapter stops) and `set` refuses; CRs are stripped from key and reason; new `test_unused_settings_list_unreadable_or_crlf` (CRLF list still refuses, also a key alone on its line, with a clean message; unreadable list fails check, stops the adapter, refuses set; skips as root) — `8fa23a3f`, `.agent/scripts/_project_registry.sh`
- [x] (suggestion) `validate_adapter.sh` now checks every type's `unused_settings` through the new `project_type_unused_settings_problems` (readable; each entry a known key, once, with a reason; CRLF, comments, blanks allowed), so the adapter-contract hook and CI catch a bad list; new `test_validator_checks_unused_settings` in `test_adapter.sh` — `be7878c7`
- [x] (suggestion) AGENTS.md Script Reference row for `project_setting.sh` names the per-type refusal; its own commit, owner-approved at the 2026-10-21 checkpoint. Not changed (no approval asked): the `validate_adapter.sh` row still reads "verify every project type implements the full adapter contract" and does not mention the `unused_settings` check — `fb250aae`
- [x] (suggestion) Env-inherited `BUILD_CMD`/`TEST_CMD`/`INSTALL_CMD` stay cleared (owner let it stand at the checkpoint); the change is named in one sentence each in the single_project and ros2_colcon adapter headers and `projects.local.example`, for the PR body to cite; a new `test_env_inherited_commands_ignored` pins it; no behaviour change — `c00db0c6`

Checks: `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed every hook, including the full script suite, the adapter contract and the design-anchor check; `test_project_file.sh` 353 passed, `test_adapter.sh` 96 passed, `test_ros2_colcon.sh` 200 passed, all 0 failed; each new code test was run against the code before its fix and failed there; shellcheck `--severity=warning` clean on `_project_registry.sh`, `validate_adapter.sh`, both adapters, `test_project_file.sh`, `test_adapter.sh`. Intermediate commits used `SKIP=validate-script-tests` as allowed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-21 11:12 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `c064fead`
**Base**: main
**Depth**: Deep (reason: whole-branch diff 2,916 changed lines outside work plans, 16 files; AGENTS.md governance file)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 5 | **Ship**: continue — must-fix rising (0 -> 1); the one must-fix is a mechanical four-number doc edit caused by the origin/main merge

Round-4 findings (7b09bc7e) all resolved at c00db0c6, checked in the code: unreadable or CRLF `unused_settings` is an error at set, check and the adapter (return 2); `validate_adapter.sh` checks each list through `project_type_unused_settings_problems`; AGENTS.md `project_setting.sh` row names the per-type refusal; env-inherited commands documented and pinned by a test. The merge c064fead brings only main's #399 content (no conflicts); its `dispatch_phase.sh` edits made the design doc's line citations stale (must-fix below).
For the owner (not a finding): the AGENTS.md `validate_adapter.sh` row still reads "verify every project type implements the full adapter contract" and does not mention the new `unused_settings` list check; changing it is Ask First.
Specialists: static analysis (shellcheck --severity=warning clean on 11 changed shell files; run_script_tests.sh 38 suites passed at c064fead; validate_adapter.sh passed; check_design_anchors.sh passed), governance, plan drift, Claude adversarial (fresh), cross-model (gemini complete, codex complete).
Dropped: gemini "bare repo gives empty --show-toplevel" (git 2.43 exits 128, so the check returns 3 as designed; checked by execution); gemini local-remote vs shared upstream (outside the owner-set three checks); gemini `set -foo=bar` parsed as removal (refused as unknown key, not silent); adversarial empty reason at runtime (validate_adapter.sh, a pre-commit hook and CI, already catches it).

### Findings
- [x] (must-fix) docs/design.md Worktrees Target, mechanism 1, cites `dispatch_phase.sh` lines 362, 364, 407, 499; after the origin/main merge (#399 edits to dispatch_phase.sh) the work-plans path lines are 368, 370, 428, 520; refresh them (the change-log row says they were refreshed; line count 784 is unchanged by the edit) (Claude adversarial + lead, confirmed by grep) — `docs/design.md:430`
- [x] (suggestion) A command set in the settings file runs without sourcing the legacy `.sh` or shared `project_config.sh`, so anything those files export (SDK paths, PATH) no longer reaches it once a command is moved into the settings file; no local config exports anything today (checked); document it in both adapter headers, `projects.local.example` and the design bullet (environment setup goes in the script the key points at), and note it for PR 2's adoption step (codex rated must-fix; reproduced by codex, confirmed by reading) — `.agent/project_types/single_project/adapter.sh:43`, `.agent/project_types/ros2_colcon/adapter.sh:640`
- [x] (suggestion) A leading `~` in a command value (`test=~/x`) is accepted and stored, then fails at run time (127) because nothing expands it; refuse a `~` word with the "point the key at a script or absolute path" hint, or state in the grammar header and `projects.local.example` that `~` and globs are literal (Claude adversarial, confirmed by execution) — `.agent/scripts/_project_registry.sh:675`
- [x] (suggestion) The writer's lock is keyed by project name (`.lock.<name>`), but two projects whose settings files are symlinks to one target take different locks, so concurrent writes can lose an update; lock on the resolved destination or refuse a shared target, with a test (codex) — `.agent/scripts/_project_registry.sh:1289`

## Checkpoint
**Status**: complete
**When**: 2026-10-21 11:13 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Pre-push round 5 (489cd883, cold review at the merge commit c064fead): 1 mechanical must-fix caused by the host's merge of origin/main (four dispatch_phase.sh line citations in docs/design.md went stale) and 3 suggestions (settings-file commands no longer see variables exported by the legacy or shared config: reviewer's choice is to document; a leading '~' stored literally fails at run time; two symlinked settings files sharing a target take different locks). The owner's answer at the round-4 publish checkpoint was "Fix suggestions, then publish"; the host applies it here, since the must-fix is a consequence of the publish path's own merge-from-main, and the owner may veto the S1 documentation choice at publish.

## Implementation
**Status**: complete
**When**: 2026-10-21 11:34 -04:00
**By**: Claude Code Agent (claude-opus-4-6)

**Branch**: feature/issue-332 at `c9ad44df`
**Addressed**: Local Review (Pre-Push) at `c064fead` (2026-10-21 11:12 -04:00)
**Commits**: `5596be9a`, `8eb91cd3`, `aa1a9c12`, `c9ad44df`

### Actions
- [x] (must-fix) `docs/design.md` Worktrees Target mechanism 1 now cites `dispatch_phase.sh` lines 368, 370, 428, 520 (checked by grep at HEAD: the two exit contracts, `cmd_check_exit`, `cmd_next`); the other citations in that paragraph (`merge_pr.sh`, `review_progress.sh`, `progress_append.sh`) were checked and still hold, since the merge did not touch those files; the change-log row's "line numbers are refreshed" is true again — `5596be9a`, `docs/design.md:431`
- [x] (suggestion) Documented, not changed: a command set in the settings file runs without sourcing the legacy `.sh` or the shared `project_config.sh`, so their exports do not reach it; environment setup belongs in the script the key points at. One sentence each in both adapter headers, `projects.local.example` and the design's Registry and adapters bullet; the plan's PR 2 adoption step now warns, naming each, when a legacy `.sh` (or the shared config) sets anything beyond `PROJECT_TYPE`, `BUILD_CMD`, `TEST_CMD`, `INSTALL_CMD`, `MANIFEST_BOOTSTRAP_URL`, `ROS_DISTRO`, `ROS_ROOT_DIR`, with a test named for PR 2. New `test_settings_command_gets_no_config_environment` pins the behaviour. The #332 change-log row names the change; its section count "98 lines" had been stale since round 2 and now reads 105, and the file is 786 lines — `8eb91cd3`, `.agent/project_types/single_project/adapter.sh:15`, `.agent/project_types/ros2_colcon/adapter.sh:22`
- [x] (suggestion) The value check refuses any command word starting with `~` with the "point the key at a script or an absolute path" hint, at `set`, at `check` and in the adapter; a `~` inside a word (`HEAD~1`) is accepted; the grammar header and `projects.local.example` say `* ? [` are literal. New `test_command_tilde_word_refused` (fails 15 checks on the code before the fix) — `aa1a9c12`, `.agent/scripts/_project_registry.sh:686`
- [x] (suggestion) The writer resolves the destination before taking the lock and puts the sidecar beside it, `<dir>/.lock.<basename>` (still `projects.d/.lock.<name>` for an ordinary file), so two names linking to one target take one lock; a sidecar file rather than a directory lock, since an exclusive flock needs a writable descriptor on NFS; once the lock is held the link is re-resolved, and a link repointed while waiting is refused. New `test_set_lock_follows_shared_symlink_target` (held lock refuses through either name; three rounds of mixed concurrent writers through both links keep every update; repointed-while-waiting refused, neither target changed; fails 12 checks on the code before the fix, a lost update among them) — `c9ad44df`, `.agent/scripts/_project_registry.sh:1318`

Checks: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed every hook, including the full script suite (`validate-script-tests`), the adapter contract and the design-anchor check; `test_project_file.sh` 397 passed, 0 failed; each new code test was run against the code before its fix and failed there; shellcheck `-S warning` clean on `_project_registry.sh`, `test_project_file.sh` and both adapters. Intermediate commits used `SKIP=validate-script-tests` as allowed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-21 11:44 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Dispatch**: resumed (agent a1794adcd75b020c6, resume 1 of 3)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `dcbddea6`
**Base**: main
**Depth**: Deep (reason: whole-branch diff 3,095 changed lines outside work plans, 16 files; AGENTS.md governance file; fix-round re-review keeps the whole-diff tier)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 6 | **Ship**: recommended — 1 mechanical must-fix (prev 1), not rising; fix and ship rather than another full round

Round-5 findings (489cd883) all resolved at c9ad44df, checked in the code: dispatch_phase.sh citations 368, 370, 428, 520 match (grep); Registry and adapters 105 lines and design.md 786 lines match; S1 documented in both adapter headers, the example file and the design bullet, plus the PR 2 adoption warning in the plan; a `~` word refused at set, check and adapter (`HEAD~1` accepted); the lock is taken beside the resolved destination and a link repointed while waiting is refused. No merge from main since round 5; 0 behind origin/main.
Still open for the owner (not a finding): the AGENTS.md `validate_adapter.sh` row does not mention the `unused_settings` list check (Ask First).
Specialists: static analysis (shellcheck --severity=warning clean on 11 changed shell files; run_script_tests.sh 38 suites passed at dcbddea6; validate_adapter.sh passed; check_design_anchors.sh passed), governance, plan drift, Claude adversarial (fresh), cross-model (gemini complete, codex complete).
Dropped: gemini local/file:// remote vs a shared upstream (outside the owner-set three checks, dropped in round 5 too); gemini `set` not running the workspace-repo check on an already hand-written records combination (the file was already failing check; a write of such a combination is refused either way); gemini `-key=value` and untrimmed `set` arguments (refused with a clear error, not silent).

### Findings
- [x] (must-fix) The Python registry parser that `validate_workspace.py` uses, which says it mirrors `_project_registry.sh`, does not refuse a project name ending in `.sh`: `read_projects_registry` returns `tools.sh` as a valid entry with no error while `registry_entries` exits 2 (both run); add the rule with the same message and a `.sh` case to `test_validate_python_parser_matches_shell` (gemini, confirmed by execution) — `.agent/scripts/lib/workspace.py:121`
- [x] (suggestion) The writer re-checks after taking the lock only that the destination path is unchanged, not that it is still a readable regular file; a settings file replaced by a directory while the writer waits makes `mv -f` put the temporary file inside that directory and report success; re-run `_project_file_path_error` beside the destination re-check, with a test (codex rated must-fix; confirmed by reading; needs a hand replacement inside the lock wait, and the gap predates this round) — `.agent/scripts/_project_registry.sh:1340`
- [x] (suggestion) A settings file for a parent root (`type=project`) is read by nothing (the adapter resolves the parent to its instance first, dashboard skips parents and counts the name as registered), yet `project_setting.sh check` and `list` on a parent exit 0 as if it had settings; make `check` fail for a parent that has a file, and have the dashboard warn, as `set` already refuses (gemini, confirmed by reading) — `.agent/scripts/project_setting.sh:73`, `.agent/scripts/dashboard.sh:168`
- [x] (suggestion) For a symlinked settings file whose target is in another directory, the lock sidecar `.lock.<basename>` is created beside the target and never removed (removing it would be unsafe); say so in the writer's header and the design bullet so a user who keeps settings in a git checkout knows where the untracked file comes from (Claude adversarial, confirmed by execution) — `.agent/scripts/_project_registry.sh:1328`

## Checkpoint
**Status**: complete
**When**: 2026-10-21 11:51 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Pre-push round 6 (b9a1cf11, at dcbddea6): 1 mechanical must-fix (the Python registry parser in lib/workspace.py does not refuse a name ending in .sh, unlike the shell parser) and 3 suggestions (re-check the destination is still a regular file after the lock; check fails and the dashboard warns for a parent root's settings file; document the lock file left beside a symlink target). Ship signal "fix and ship". Owner's answer: "Fix, re-review, publish (Recommended)"; if round 7 finds another small must-fix the host asks again rather than loop.

## Implementation
**Status**: complete
**When**: 2026-10-21 12:13 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Dispatch**: resumed (agent a44f63a2874f8018e, resume 1 of 3)

**Branch**: feature/issue-332 at `4405f1d2`
**Addressed**: Local Review (Pre-Push) at `dcbddea6` (2026-10-21 11:44 -04:00)
**Commits**: `cc82f3c7`, `a7b00b6d`, `f1074424`, `4405f1d2`

### Actions
- [x] (must-fix) `read_projects_registry` refuses a project name ending in `.sh` with the shell parser's message; `test_validate_python_parser_matches_shell` gains a `tools.sh` line and asserts both the error and that neither parser keeps the entry (the parity check fails on the old parser) — `cc82f3c7`, `.agent/scripts/lib/workspace.py:126`
- [x] (suggestion) Once the lock is held the writer re-runs `_project_file_path_error` beside the destination re-check and refuses with the reason; header updated. New `test_set_rechecks_the_file_after_the_lock_wait` (a flock stub marks the wait, the file is replaced by a directory, the write is refused, nothing lands inside, no temporary file left); on the old code the write reported "updated" and left its temporary file inside the directory (checked by execution) — `a7b00b6d`, `.agent/scripts/_project_registry.sh:1350`
- [x] (suggestion) `project_setting.sh check` and `list` on a parent root exit 2 when it has a settings file, naming its instances, and print "is a parent root and has no settings file" (exit 0) when not; the dashboard warns about a parent's file. New `test_parent_root_settings_file_is_flagged` (fails 7 checks on the old scripts). Not changed: the AGENTS.md `project_setting.sh` row's exit-code summary does not mention the parent case (Ask First) — `f1074424`, `.agent/scripts/project_setting.sh:85`, `.agent/scripts/dashboard.sh:180`
- [x] (suggestion) The lock file is never removed, by design; said in the writer's header (with why: removing it would let a third writer lock a new file of the same name) and in the design's Registry and adapters bullet (a linked file leaves an untracked `.lock.<basename>` beside its target); the #332 change-log row names it, with 107 section lines and 788 file lines; no behaviour change — `4405f1d2`, `.agent/scripts/_project_registry.sh:1215`, `docs/design.md:276`

Checks: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed every hook, including the full script suite, the adapter contract, the design-anchor check, shellcheck, black, flake8 and pylint; `test_project_file.sh` 413 passed and `test_project_registry.sh` 260 passed, 0 failed; each new code test was run against the code before its fix and failed there; shellcheck `-S warning` clean on `_project_registry.sh`, `project_setting.sh`, `dashboard.sh`, `test_project_file.sh`, `test_project_registry.sh`. Intermediate commits used `SKIP=validate-script-tests` as allowed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-21 12:32 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Dispatch**: resumed (agent a1794adcd75b020c6, resume 2 of 3)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `56a273a9`
**Base**: main
**Depth**: Deep (reason: whole-branch diff 3,228 changed lines outside work plans, 18 files; AGENTS.md governance file; fix-round re-review keeps the whole-diff tier)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 7 | **Ship**: recommended — 1 mechanical must-fix (prev 1), not rising; every remaining item is mechanical, fix and ship rather than another full round

Round-6 findings (b9a1cf11) all resolved at 4405f1d2, checked in the code: the Python parser refuses a `.sh` name with the shell's exact message, in the same check order; the writer re-runs `_project_file_path_error` after the lock, before any temp file; `check`/`list` exit 2 for a parent root that has a file and the dashboard warns; the lock file left beside a link target is documented. design.md counts verified: Registry and adapters 107 lines, file 788. 0 behind origin/main.
For the owner (not findings, Ask First): the AGENTS.md `validate_adapter.sh` row does not mention the `unused_settings` list check, and the `project_setting.sh` row's exit codes do not mention the parent-root exit 2.
Specialists: static analysis (shellcheck --severity=warning clean on the 5 touched scripts and suites; flake8 clean on workspace.py; run_script_tests.sh 38 suites passed at 56a273a9; validate_adapter.sh passed; check_design_anchors.sh passed), governance, plan drift, Claude adversarial (fresh), cross-model (gemini complete, codex complete).
Dropped: gemini local/file:// remote vs a shared upstream and push URLs (outside the owner-set three checks; dropped in rounds 5 and 6); gemini `-key=value` parsing (refused with a clear error; dropped twice before); gemini unquoted `$tmp` in the error-message substitution (affects message text only); gemini dashboard skipping a dangling orphan link (nothing reads it); adversarial dashboard warning vs `check` exit 2 for a parent's file (a deliberate split: `make validate` stays about what is read).

### Findings
- [x] (must-fix) docs/design.md Registry and adapters says "The registry has no such fallback, except in `capture.sh`"; this branch's `project_setting.sh` also reads the main checkout's registry and settings file from a linked worktree (and refuses to write there), so name it in that sentence (gemini, confirmed by reading `project_setting.sh:54-60`) — `docs/design.md:264`
- [x] (suggestion) The `.sh` name guard is case-sensitive: on a case-insensitive filesystem (macOS default) a project named `tools.SH` passes and its settings file `.agent/projects.d/tools.SH` is project `tools`'s legacy `tools.sh`; compare the suffix case-insensitively in both parsers, with a mixed-case parity case (codex rated must-fix; confirmed by reading) — `.agent/scripts/_project_registry.sh:154`, `.agent/scripts/lib/workspace.py:126`
- [x] (suggestion) `project_setting.sh get <parent> <key>` still reads a file under a parent root's name and prints a value nothing honours, while `check` and `list` now refuse it; give `get` the same parent handling (Claude adversarial, confirmed by reading) — `.agent/scripts/project_setting.sh:105`
- [x] (suggestion) For `tracking=repo`, a `location_path` that exists but is not yet a clone is resolved by `git rev-parse --show-toplevel` to whatever repository holds it (a home dotfiles repo, say) and checked as that repo, rather than reported "unverifiable until cloned"; require the toplevel to be `location_path` itself, or record it on the records-lookup issue (#393), where these combinations become honoured (gemini, confirmed by reading) — `.agent/scripts/_project_registry.sh:1099`

## Checkpoint
**Status**: complete
**When**: 2026-10-21 12:34 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Pre-push round 7 (bbe5fb20, at 56a273a9): 1 mechanical must-fix (design.md Registry and adapters sentence "no such fallback, except in capture.sh" must name project_setting.sh too) and 3 suggestions (case-insensitive .sh guard in both parsers; get gets the parent-root handling; records-repo check must not adopt an enclosing repository for a not-yet-cloned location_path, or record on #393). Ship recommended. Owner's answers: "Fix, then publish after round 8 regardless (Recommended)": one fix pass, one review, then the host answers the round-8 checkpoint publish whatever it finds, leftovers listed in the PR body for post-push triage; and the two stale AGENTS.md Script Reference rows (validate_adapter.sh: unused_settings check; project_setting.sh: parent-root exit 2), Ask First: "Yes, update both rows".

## Implementation
**Status**: complete
**When**: 2026-10-21 12:52 -04:00
**By**: Claude Code Agent (claude-opus-4-6)
**Dispatch**: resumed (agent a44f63a2874f8018e, resume 2 of 3)

**Branch**: feature/issue-332 at `b07050a5`
**Addressed**: Local Review (Pre-Push) at `56a273a9` (2026-10-21 12:32 -04:00)
**Commits**: `a06e523e`, `5fc35f35`, `46abd214`, `4f7ab94e`, `b07050a5`

### Actions
- [x] (must-fix) Registry and adapters now says the registry has no worktree fallback except in two scripts, `capture.sh` and `project_setting.sh` (which also reads the main checkout's settings files and refuses to write them from a worktree, checked against `project_setting.sh:54-60`); the #332 change-log row names it, with 109 section lines and 790 file lines — `a06e523e`, `docs/design.md:264`
- [x] (suggestion) Both parsers refuse a name ending in `.sh` in any letter case (`*.[sS][hH]` in bash, so no bash-4 `${,,}`; `name.lower()` in Python), with the same message saying "in any letter case"; `projects.local.example` says so; the parity test gains `kit.SH` and `box.sH` lines (their three checks fail on the old parsers) — `5fc35f35`, `.agent/scripts/_project_registry.sh:155`, `.agent/scripts/lib/workspace.py:127`
- [x] (suggestion) `get` on a parent root exits 2 with the INVALID message and prints no value when the parent has a file, and exits 1 saying the settings belong to its instances when not; the parent checks share helpers; `test_parent_root_settings_file_is_flagged` covers `get` (its four `get` checks fail on the old script) — `46abd214`, `.agent/scripts/project_setting.sh:115`
- [x] (suggestion) Not as literally suggested: when the toplevel is not `location_path` itself, the result is "unverifiable until cloned" (exit 3, the note naming why), as the plan's wording says (`location_path` is the records clone; an uncloned one is unverifiable); but the enclosing repository is still refused when it is a workspace (its own repository or a copy), because records there would be committed into it and `test_records_dir_inside_workspace_repo` pins that refusal. No conflict with the #393 plan wording, so nothing recorded there. New `test_records_path_inside_another_repo_is_unverifiable` (inside a dotfiles repo: unverifiable with the reason; once cloned there: verified; absent: unverifiable; inside a workspace copy: refused); its two note checks fail on the old code — `4f7ab94e`, `.agent/scripts/_project_registry.sh:1140`
- [x] (owner-approved, Ask First) AGENTS.md in its own commit: the `validate_adapter.sh` row names the `unused_settings` list check; the `project_setting.sh` row's exit codes name the parent-root exit 2 (for `check`, `get` and `list`) — `b07050a5`, `AGENTS.md:407-408`

Checks: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed every hook, including the full script suite, the adapter contract, the design-anchor check, shellcheck, black, flake8 and pylint (flake8 with the repo's `--max-line-length=100`); `test_project_file.sh` 426 passed and `test_project_registry.sh` 263 passed, 0 failed; each new code test was run against the code before its fix and failed there; shellcheck `-S warning` clean on `_project_registry.sh`, `project_setting.sh`, `test_project_file.sh`, `test_project_registry.sh`. Intermediate commits used `SKIP=validate-script-tests` as allowed.

## Local Review
**Status**: complete
**When**: 2026-10-27 13:48 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #403 at `91366fc3`
**Depth**: Deep (reason: 3,200+ changed lines outside work plans across 18 files; AGENTS.md governance file)
**Must-fix**: 0 | **Suggestions**: 2

Round-7 fixes (bbe5fb20) checked in the code at 91366fc3: design.md names `project_setting.sh` beside `capture.sh`; both parsers refuse `.sh` in any case (`*.[sS][hH]`, `name.lower()`); `get` on a parent root exits 2 / 1; a `location_path` inside another repository is unverifiable unless that repository is a workspace (workspace refusals run before the enclosed return 3); AGENTS.md rows owner-approved (Checkpoint 2026-10-21 12:34). Local HEAD equals PR head; 0 behind origin/main.
CI at review time: Validate Adapter Contract, Validate Documentation, ros-manifest tests pass on both runs; Lint (pre-commit) passed on one run and was still pending on the other; Copilot PR review failed (quota exhausted, no review).
Specialists: static analysis (shellcheck --severity=warning clean on the 12 changed shell files and `adapter`; flake8 clean on lib/workspace.py; validate_adapter.sh passed; test_project_file.sh 426, test_project_registry.sh 263, test_adapter.sh 96, test_ros2_colcon.sh 200 passed, 0 failed), governance, plan drift (no drift beyond the plan-review additions already recorded), Claude adversarial (fresh; its sandbox edge-case probes were denied, findings by reading), cross-model (gemini complete, codex complete).
Dropped: codex SIGTERM to the CLI PID alone lets the writer subshell finish (the write is atomic and validated, the requested change lands; Ctrl-C signals the whole group); gemini `set` of an unrelated key on a file whose records are already refused (dropped round 5); gemini local/file:// remote vs a shared upstream (dropped rounds 5-7); gemini validate_workspace.py not flagging a parent's file (deliberate split, round 7); gemini dashboard orphan glob on dangling links and `.SH` (round 7; nothing reads such a file); gemini `list` sending the refusal reason to `check` (deliberate); gemini `list` not marking a defaulted `location_path` provisional (only a hand-written, not-yet-honoured combination reaches it; `check` prints the NOTE); gemini untrimmed `set` arguments and unset-typo error order (refused with a clear error; dropped before).

### Findings
- [ ] (suggestion) `get` skips the records check: a file with `tracking=repo` at a workspace repository, which `check`, `list` and the adapter refuse, still returns any key with exit 0, against the header's exit-2 contract "records settings refused" and the round-7 parent-root parity; run `_project_records_check_entries` (exit 2 on refusal) or narrow the documented contract for `get` (codex and gemini, confirmed by reading `project_file_get`) — `.agent/scripts/project_setting.sh:125`
- [ ] (suggestion) `_records_norm_url` lowercases with `${1,,}` (bash 4 only) although the round-7 `.sh` guard in the same file avoided it for macOS bash 3.2; reached on every adapter verb for `tracking=repo` with a network remote; use `tr '[:upper:]' '[:lower:]'` (the workspace already uses `${,,}` elsewhere, e.g. `_resolve_work_plans_dir.sh:96`, so low impact) (Claude adversarial, confirmed by reading) — `.agent/scripts/_project_registry.sh:1054`

## Integrated Review
**Status**: complete
**When**: 2026-10-27 13:50 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #403 at `91366fc3`
**Sources**: 2 (Local Review @ `91366fc3`, its cross-model drop list re-examined; CI rollup). Copilot posted only "insufficient remaining quota" (no review, not a source); no human or conversation comments.
**Cross-source confirmations**: 0 (no GitHub comments to correlate; finding 1 was raised by codex and gemini inside the one local review)
**CI**: all-pass (8 workflow checks green on both runs: Lint (pre-commit), Validate Documentation, Validate Adapter Contract, ros-manifest tests; the copilot-pull-request-reviewer check-run fails for quota only)

Codex drop re-examined and reversed: the local review dropped "SIGTERM to the CLI PID alone lets the writer subshell finish" because the write is atomic and Ctrl-C signals the whole group. Atomicity and Ctrl-C hold (GNU `timeout` also signals the group), but the drop misses the lock-wait case. `project_file_set` runs `( _project_file_set_locked )` under a `project_setting.sh` that has no traps, so `kill <pid>` ends the parent at once (exit 143) and orphans the subshell, which carries on (reproduced with a minimal script: parent exit 143, the subshell's write still landed a second later). If the orphan is still in `flock -w` behind another writer, it takes the lock later, re-reads the file and writes its keys, possibly over a newer `set` of the same key the user made after "cancelling". Narrow, but a silent overwrite that can occur, so it is not dismissible under the Quality Standard.

### Findings
- [x] (suggestion, Local Review: codex + gemini) `get` skips the records check: a file whose records repository is a workspace, which `check`, `list` and the adapter refuse with exit 2, still answers `get` with exit 0, against the header's exit-2 contract ("records settings refused") and the parent-root parity. Fix: in `get`, take `project_file_entries` (exit 2 on failure), run `_project_records_check_entries` and exit 2 on its 2 (3 is fine for `get`), then print the value; add a test in `test_project_file.sh` beside the existing records-refusal cases — `.agent/scripts/project_setting.sh:125`
- [x] (suggestion, Local Review: Claude adversarial) `_records_norm_url` uses `${1,,}` (bash 4 only). On bash 3.2 it is a bad substitution, so `norm`/`wnorm` come back empty, and the "records remote is the workspace's remote" refusal is silently skipped (or the caller aborts under `set -e`). That makes it a silent failure in a safety check, not just a portability nit; it is reached only from a hand-written `tracking=repo` file. Fix: `u="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"`; the existing mixed-case case (`https://GitHub.com/Example/ws-sandbox.git/`, `test_project_file.sh:411`) covers the result — `.agent/scripts/_project_registry.sh:1054`
- [x] (suggestion, codex via Local Review drop list, reinstated) A writer whose parent `project_setting.sh` is killed by PID keeps running orphaned and can write after a later `set`, overwriting it. Fix: in `_project_file_set_locked`, capture the parent PID (`$$` in the subshell) and abort without writing (`return 1`, temp file removed by the EXIT trap) if `kill -0 "$$"` fails, both after the lock is taken and immediately before `mv`. Add a test: hold the lock, start `set`, kill the parent PID, release the lock, and assert the file is unchanged and no temp file is left — `.agent/scripts/_project_registry.sh:1366`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-10-27 13:59 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: findings
**Decision**: address

PR 403 Integrated Review (b086e468, at 91366fc3): 3 valid suggestions, no must-fix (get skips the records check; bash-4-only ${1,,} in _records_norm_url silently skips the remote-URL refusal on bash 3.2; an orphaned writer subshell can take the lock later and overwrite a newer set). Host recommended addressing all three before merging. Owner's answer: "A yes, fix first".

## Implementation
**Status**: complete
**When**: 2026-10-27 14:08 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #403 at `315c4763`
**Addressed**: Integrated Review at `91366fc3` (2026-10-27 13:50 -04:00)
**Commits**: 8364e2c0, 0e286cce, 315c4763

### Actions
- [x] `get` now parses the file, runs the records check and exits 2 (reason plus an INVALID line) when it refuses; not yet honoured (3) still answers; test `test_get_runs_the_records_check` — `.agent/scripts/project_setting.sh:125`
- [x] `_records_norm_url` lowercases with `tr '[:upper:]' '[:lower:]'` instead of bash-4 `${1,,}`; the mixed-case remote case in `test_records_repo_workspace_by_remote_url` covers the result, and the new `test_no_bash4_case_conversion` keeps `${x,,}`/`${x^^}` out of `_project_registry.sh` and `project_setting.sh` (this was the only one the branch added) — `.agent/scripts/_project_registry.sh:1054`
- [x] `_project_file_set_locked` checks the caller (`kill -0 "$$"`) once the lock is taken and again just before the rename (and before removing an emptied file), returning 1 without writing; test `test_set_writer_orphaned_by_a_killed_caller` covers both points (file unchanged, no temporary file) and fails on the unfixed writer — `.agent/scripts/_project_registry.sh:1366`

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: every hook passed, the script test suite (`validate-script-tests`) included.

## Local Review
**Status**: complete
**When**: 2026-10-27 14:13 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #403 at `b9bfcd61`
**Depth**: Deep (reason: whole-PR diff 4,600+ lines across 20 files incl. AGENTS.md; fix round re-classified on the whole diff per #320)
**Must-fix**: 0 | **Suggestions**: 2

Fix-round re-review of the Integrated Review (b086e468) fixes 8364e2c0, 0e286cce, 315c4763, checked in the code at b9bfcd61: `get` parses the file, runs `_project_records_check_entries` and exits 2 only on its 2 (it returns only 0/2/3; 3 still answers, NOTE/WARNING lines stay quiet unless refused; missing/malformed/absent-key exits unchanged); `_records_norm_url` lowercases with `tr`; `_project_file_caller_alive` (`kill -0 "$$"`, `$$` = the `project_setting.sh` PID, the only caller besides the `project_file_unset` wrapper) guards after the lock, before removal and before `mv`. No `${x,,}`/`${x^^}` remains in any non-test shell file this branch changes. Local HEAD equals PR head; 0 behind origin/main.
CI at review time: Validate Adapter Contract, Validate Documentation, ros-manifest tests pass on both runs; Lint (pre-commit) still running on both.
Specialists: static analysis (shellcheck --severity=warning clean on `_project_registry.sh`, `project_setting.sh`, `test_project_file.sh`; `test_project_file.sh` 449 passed, 0 failed, run once here and 4 times by the adversarial reviewer with no leftover processes), governance (fixes carry tests; header exit-2 contract and AGENTS.md row now true for `get`), plan drift (fixes match the Integrated Review's fix plan, nothing else changed), Claude adversarial (fresh), cross-model (gemini complete, codex complete).
Dropped: codex `set` not running the records check on a hand-written refused file (dropped round 5: `set` never stores a non-default combination, and refusing would block the `set location=project tracking=project` repair); gemini `readlink -f` on pre-12.3 macOS (fails loud with a clear error, symlinked settings files only); gemini dashboard orphan glob (round 7), untrimmed `set` arguments (dropped before), `validate_workspace.py` parent file (round 7); gemini `file://localhostname` / percent-encoded `file://` remotes (not a URL git clones locally; the contents check still catches a clone of the workspace).

### Findings
- [ ] (suggestion) The temporary-file writer relies on the caller's inherited errexit to stop on a failed `printf` (e.g. ENOSPC); safe for the one caller (`project_setting.sh`, `set -e`, plain call), but a future `if project_file_set ...` caller would validate and rename a truncated file; check each write (`|| exit 1` inside the group) or say so in the header (codex, confirmed by reading) — `.agent/scripts/_project_registry.sh:1395`
- [ ] (suggestion) `test_no_bash4_case_conversion` regex `\$\{[^}]*(,,?|\^\^?)\}` also matches legal bash 3.2 such as `${x:-,}` or `${x%^}`; anchor on the operator after the name, e.g. `\$\{[A-Za-z_0-9@*]+(,,?|\^\^?)[^}]*\}` (Claude adversarial) — `.agent/scripts/tests/test_project_file.sh:421`

## Integrated Review
**Status**: complete
**When**: 2026-10-27 14:17 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #403 at `99626d24`
**Sources**: 2 (Local Review @ `b9bfcd61`, carried forward: `sources` lists it as stale only because 99626d24 touches `AGENTS.md`, read here and covered below; CI rollup). Copilot posted only "insufficient remaining quota" on every push (no review, not a source); no human or conversation comments.
**Cross-source confirmations**: 0 (no GitHub comments to correlate)
**CI**: pending (Validate Adapter Contract, Validate Documentation, ros-manifest tests pass on both runs at `99626d24`; Lint (pre-commit) still pending on both; the copilot-pull-request-reviewer check-run fails for quota only, not a CI failure)

Covered here: 99626d24 (owner-approved AGENTS.md row edit, landed after the re-review) changes one phrase in the `project_setting.sh` row, "`get` and `list` exit 2 on that too" to "on all of those too", so the exit-2 list (malformed, records repository that is a workspace, parent-root file) now applies to `get` and `list`. True at this head: 8364e2c0 made `get` run the records check and exit 2 on its refusal; nothing else in the diff. The Local Review's fix-round checks (`get` records check, `tr` lowercasing, orphaned-writer guard) stand; the prior Integrated Review's three findings are closed by 8364e2c0, 0e286cce, 315c4763.

Finding 1 checked against the code: errexit does cover the one caller today (`project_setting.sh` has `set -euo pipefail` and calls `project_file_set` plainly; `( _project_file_set_locked )` inherits it, and a failed `printf` inside the `{ ... } > "$tmp"` group exits the subshell, whose EXIT trap removes the temporary file). But bash ignores errexit for anything run in a condition context, subshells included: reproduced with bash 5.2, a writer called as `w || ...` or `if w` whose middle `printf` hit ENOSPC (`/dev/full`) carried on and kept a two-of-three-line file. `_project_file_parse` would accept such a file if the lost line was a whole key, and the rename then silently drops a setting. The library is sourced, and this code base's own idiom is `fn ... || rc=$?`, so a condition-context caller is the likely next one. A silent loss that can occur, so valid; the explicit checks cost three `|| exit 1`.

### Findings
- [x] (suggestion, Local Review @ `b9bfcd61` (codex, confirmed by reproduction)) The temporary-file writer stops on a failed `printf` only through inherited errexit, which bash turns off when `project_file_set` is called from a condition (`|| rc=$?`, `if`): a cut-off file is then validated and renamed, silently dropping a setting. Fix: add `|| exit 1` to each of the three `printf` calls inside the `{ ... } > "$tmp"` group (the subshell's EXIT trap removes the temporary file); add a test in `test_project_file.sh` that calls `if project_file_set ...` with `printf` shadowed by a function failing on one line, and asserts a non-zero exit, the settings file unchanged and no temporary file left — `.agent/scripts/_project_registry.sh:1395`
- [x] (suggestion, Local Review @ `b9bfcd61` (Claude adversarial)) `test_no_bash4_case_conversion`'s regex `\$\{[^}]*(,,?|\^\^?)\}` matches legal bash 3.2 (`${x:-,}`, `${x%^}`) and, because it requires the operator right before `}`, misses the bash 4 pattern form `${x,,[A-Z]}`; a guard that both cries wolf and has a hole. Fix: match the operator right after a parameter name, subscript allowed: `\$\{([A-Za-z_][A-Za-z_0-9]*|[0-9]+|[@*])(\[[^]]*\])?(,,?|\^\^?)` (checked on samples here: matches `${1,,}`, `${x^^}`, `${arr[0],,}`, `${x,,[A-Z]}`, `${x,}`, `${@^^}`; not `${x:-,}` or `${x%^}`). The reviewer's suggested `[A-Za-z_0-9@*]+` would miss `${arr[0],,}` — `.agent/scripts/tests/test_project_file.sh:421`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-10-27 14:26 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: findings
**Decision**: address

PR 403 Integrated Review (ead948c6, at 99626d24): 2 valid suggestions, no must-fix (the temp-file writer's printf calls rely on the caller's set -e, so a caller inside a condition can save a cut-off file; the no-bash-4 test regex flags legal bash and misses the pattern form). Host recommended fixing both and proposed a standing rule for this PR: fix every valid finding until a round comes back clean, then bring the merge. Owner's answer: "fix 403". Host reads it as the rule accepted for this PR, stated in the hand-back for veto.

## Implementation
**Status**: complete
**When**: 2026-10-27 14:35 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #403 at `1adf7f20`
**Addressed**: Integrated Review at `99626d24` (2026-10-27 14:17 -04:00)
**Commits**: 8a130df3, 1adf7f20

### Actions
- [x] Each of the three `printf` calls writing the temporary settings file ends with `|| exit 1`, so a failed write stops the writer when it is called from a condition; new `test_set_stops_on_a_failed_write_inside_a_condition` shadows `printf` to fail on a kept, a replaced and an appended line and expects a non-zero exit, the file unchanged and no temporary file left (confirmed failing on the old code: 7 of 12 assertions) — `.agent/scripts/_project_registry.sh:1412`
- [x] The no-bash-4 guard uses `\$\{([A-Za-z_][A-Za-z_0-9]*|[0-9]+|[@*])(\[[^]]*\])?(,,?|\^\^?)`, with a self-check against six samples it must catch and four legal ones it must skip (the old pattern misses `${x,,[A-Z]}` and matches `${x:-,}`, `${x%^}`) — `.agent/scripts/tests/test_project_file.sh:421`

Hook run: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP, exit 0 (script test suite included, passed).

## Local Review
**Status**: complete
**When**: 2026-10-27 14:39 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #403 at `8798ed5d`
**Depth**: convergence check (round 3 of PR-mode review; rounds 1 at `91366fc3`, 2 at `b9bfcd61`), under the owner's round-3 exception from issue 320 as the host's handoff stated it; no cross-model reviewers, no fresh Claude adversarial. The "Round-3 convergence check" section named in the handoff was not found in `review_depth_classification.md` (worktree or main checkout); scope taken from the handoff.
**Must-fix**: 0 | **Suggestions**: 1

Scope: the Integrated Review's two findings (at `99626d24`) and the fix diff `ead948c6..8798ed5d` minus work plans (commits 8a130df3, 1adf7f20; 2 files, +48 -5). Local HEAD equals PR head; 0 behind origin/main.
Fix 1 closed: the three `printf` calls in the `{ ... } > "$tmp"` group end with `|| exit 1`; the group runs in the `( _project_file_set_locked )` subshell, so `exit 1` ends the writer, its EXIT trap removes the temporary file, and `project_file_set` returns 1. New `test_set_stops_on_a_failed_write_inside_a_condition` covers all three writes; confirmed here against the pre-fix writer (ead948c6's `_project_registry.sh` in a throwaway detached worktree): 7 failures, exactly the new test's (the appended-key case on old code yields an unchanged file, so only its exit-status assertion fails, which is still the writer's printf).
Fix 2 closed: the new regex catches `${x,,[A-Z]}`, `${arr[0],,}`, `${x[@],,}`, `${x[${i}],,}`, nested `${x:-${y,,}}`, and skips `${x:-,}`, `${x%^}`, `${x//,/ }`, `${x#^}`, `${x:+^}`, `${x[,]}`; ten-sample self-check runs in the test.
Verified: `bash .agent/scripts/tests/test_project_file.sh` 471 passed, 0 failed; shellcheck --severity=warning clean on both changed files (`.venv/bin/shellcheck`).
CI at review time (`gh pr checks 403`): Validate Adapter Contract, Validate Documentation, ros-manifest tests pass on both runs; Lint (pre-commit) pending on both.

### Findings
- [ ] (suggestion) The new no-bash-4 regex misses indirect expansion with case conversion, `${!y,,}` (valid bash 4, prints the lowercased value; bash 3.2 rejects it), which the old pattern did catch, so the fix narrows the guard on that one form; allow an optional `!` after `${`: `\$\{!?([A-Za-z_]...`, and add `${!x,,}` to the catch samples — `.agent/scripts/tests/test_project_file.sh:423`

## Integrated Review
**Status**: complete
**When**: 2026-10-27 14:42 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #403 at `8798ed5d`
**Sources**: 3 (Local Review @ `8798ed5` (covers local HEAD `994772c3` via bookkeeping), Copilot @ `8798ed5d` (quota message only, no comments), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

Previous Integrated Review (at `99626d24`, committed `ead948c6`): both findings fixed in 8a130df3 and 1adf7f20 and confirmed closed by the round-3 Local Review; not re-listed. Older Local Reviews at `91366fc` and `b9bfcd6` are stale (code changed since) and were closed by earlier triage.
Finding verified here: the regex at `.agent/scripts/tests/test_project_file.sh:423` reports `${!y,,}`, `${!y^^}` and `${!arr[0],,}` as missed; bash 5.2 evaluates `${!y,,}` (prints the lowercased value), and bash 3.2 rejects it. The guard exists to catch bash 4 case conversion, so a form it misses is a gap in the guard, and the old pattern did catch it: valid. No current hit in `_project_registry.sh` or `project_setting.sh`, so this is a regression-guard gap, not a live defect. Proposed fix checked: `\$\{!?(...)` catches all three indirect forms and still skips `${!x}`, `${!x@}`, `${!x*}`, `${#x}`, `${x:-,}`, `${x%^}`; no hits in the two real files.
CI at `8798ed5d`: Validate Adapter Contract, Validate Documentation, ros-manifest tests pass on both runs; Lint (pre-commit) passed on run 40561517367 and is still pending on run 40561528755. The `copilot-pull-request-reviewer` check fails on quota, not code.

### Findings
- [x] (suggestion, Local Review @ `8798ed5`) The no-bash-4 guard misses indirect expansion with case conversion (`${!y,,}`, `${!y^^}`); allow an optional `!` after `${` (`re='\$\{!?([A-Za-z_][A-Za-z_0-9]*|[0-9]+|[@*])(\[[^]]*\])?(,,?|\^\^?)'`), add `${!x,,}` and `${!x^^}` to the catch samples and `${!x}` to the skip samples, and update the comment above the pattern — `.agent/scripts/tests/test_project_file.sh:423`

### False positives
- (Copilot @ `8798ed5d`) Review body "unable to review ... insufficient remaining quota" — not a finding; no comments and no code claim to evaluate.

## Checkpoint
**Status**: complete
**When**: 2026-10-27 14:42 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: findings
**Decision**: address

PR 403 Integrated Review (18e54eb3, round 3): 1 valid suggestion, no must-fix (the no-bash-4 guard regex misses the indirect form ${!y,,}). Answered from the owner's standing rule for this PR, accepted 2026-10-27 ("fix 403": fix every valid finding until a round comes back clean, then bring the merge); no new question was put to him.

## Implementation
**Status**: complete
**When**: 2026-10-27 14:51 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #403 at `f21f3371`
**Addressed**: Integrated Review at `8798ed5d` (2026-10-27 14:42 -04:00)
**Commits**: f21f3371

### Actions
- [x] The no-bash-4 guard now allows an optional `!` after `${`, so indirect `${!x,,}` and `${!x^^}` are caught; both added to the self-check's catch samples, `${!x}` to its skip samples, comment updated. The old pattern misses both new catch samples; the new one passes the whole self-check, and the guard still finds nothing in `_project_registry.sh` or `project_setting.sh` — `.agent/scripts/tests/test_project_file.sh:420`

### Checks
- `.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: every hook passed, including the script test suite.
- `test_project_file.sh` alone: 474 passed, 0 failed.

## Local Review
**Status**: complete
**When**: 2026-10-27 14:55 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #403 at `8bc1d03`
**Depth**: convergence check (reason: PR-mode round 4; owner's standing exception for rounds three and later, issue 321 — narrow check, no cross-model reviewers)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 4 (PR mode) | **Scope**: commit `f21f3371` only — the prior round's one finding (no-bash-4 guard missed indirect `${!x,,}` / `${!x^^}`) and its fix diff in `.agent/scripts/tests/test_project_file.sh`

Verified: the new regex `\$\{!?(...)(\[[^]]*\])?(,,?|\^\^?)` run by hand against all committed samples plus extras — catches `${!x,,}`, `${!x^^}`, `${!x,}`, `${!1^}`, `${!arr[@],,}`; skips `${!x}`, `${!prefix@}`, `${!arr[@]}`, `${#x}`, `${!x:-,}` and the four prior legal samples. `bash .agent/scripts/tests/test_project_file.sh`: 474 passed, 0 failed. shellcheck --severity=warning on the file: clean. Comment above the pattern updated to match. Prior finding resolved.

CI at `8bc1d033`: Validate Documentation, Validate Adapter Contract, ros-manifest tests pass on both runs; Lint (pre-commit) pending on both runs (40563845046, 40563834709).

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-10-27 14:58 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #403 at `876133c4`
**Sources**: 3 (Local Review @ `8bc1d03` (covers head `876133c4` via bookkeeping), Copilot @ `8bc1d033` (quota message only, no comments), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

Previous Integrated Review (at `8798ed5d`, committed `18e54eb3`): its one finding (no-bash-4 guard missed indirect `${!x,,}` / `${!x^^}`) was fixed in f21f3371 and confirmed closed by the round-4 Local Review; checked here: the pattern at `.agent/scripts/tests/test_project_file.sh:424` carries `\$\{!?`, and `${!x,,}` / `${!x^^}` are in the catch samples at line 426. Not re-listed.
Round-4 Local Review @ `8bc1d03`: approved, 0 must-fix, 0 suggestions. Its one open box ("No issues found. LGTM.") is a placeholder, not a finding; nothing to triage. Older Local Reviews at `91366fc`, `b9bfcd6` and `8798ed5` are stale (code changed since) and were closed by earlier triage.
GitHub: 8 Copilot reviews, all the quota message, no inline comments; no conversation comments; no human reviews.
CI at `876133c4`: Validate Adapter Contract, Validate Documentation, ros-manifest tests pass on both runs (40564504213, 40564515660); Lint (pre-commit) still pending on both. The `copilot-pull-request-reviewer` check is still running and fails on quota, not code.

### Findings
None open.

### False positives
- (Copilot @ `8bc1d033`) Review body "unable to review ... insufficient remaining quota" — not a finding; no comments and no code claim to evaluate.

## Implementation
**Status**: complete
**When**: 2026-10-28 10:10 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-332 at `6cb9cef3`

PR 2 of 4 (`register_project.sh`), built on PR 1 as merged (#403). Commits 3e16db43..6cb9cef3.

### Actions
- [x] `registration.conf` per type (`required_commands`, `setup`, `run`): `single_project` build and test, never setup; `ros2_colcon` none required (its `unused_settings` refuses build/test), setup when missing, no verbs run. `validate_adapter.sh` requires one per type; `test_adapter.sh` case.
- [x] `user_tier_install.sh --disable-root <name>`: one root, treated as `--uninstall` treats each; takes the machine-level record back if the local remove dropped it while other roots stay enabled. Tests in `test_user_tier_install.sh`.
- [x] `register_project.sh`: register (registry line with an absolute path, parsed from a temp copy then renamed; settings from `--set`, else the legacy `.sh`, else `--detect`), setup when `registration.conf` says so and the directory is missing, `registration_verify.sh`, the `run=` verbs, then the user tier; rollback on any failure and on INT/TERM/HUP, with `--disable-root` once the installer ran; `KEPT=` for a directory setup created; adoption (line kept, `NOT READY` not rollback, warning on extra variables in the old config); `--remove`; `--detect`; `--dry-run`; main checkout only.
- [x] `registration_verify.sh`: read-only gate with the inert marker (not added to `user_tier_scripts.txt`; PR 3 promotes it).
- [x] `_project_registry.sh`: `project_command_source`, `project_config_extra_vars`, registration.conf readers, optional file argument to `registry_entries_full`.
- [x] `projects.local.example`, `user_tier_scripts.txt` comment; #265 plan edits and ADR-0016 decision 5 pointer; `docs/design.md` (Registry Now, Sessions and roots Target to Now, Registry Target, C4, change-log row); `AGENTS.md` rows in their own commit (18c4fb7b, Ask First).
- [x] `test_register_project.sh` (105 cases, synthetic sandbox projects only); `test_script_tests_hook_scope.sh` gains its ROOT_READERS row.

### Where the plan and merged PR 1 differ (code followed)
- `ros2_colcon` refuses `build`/`test` settings (PR 1's `unused_settings`), so its `required_commands=none` and adoption copies only keys the type reads.
- The records refusal lives in `project_file_set`; register prechecks the same rule so `--dry-run` reports it.
- Legacy `.sh` precedence is "whole legacy layer" (PR 1 amendment), so the gate accepts a command still read from the legacy `.sh` as the project's own.

### Decisions for veto
- Adoption may add a missing `default_instance` to a parent root's line (otherwise `--default-instance` could never be used: instances must exist first); every other field change is refused.
- `--set` on an adopted project with a settings file updates it; copying from the `.sh` and detection happen only when there is no file.
- `validate_adapter.sh` row in AGENTS.md also edited (one clause naming the registration.conf check), beside the two new rows.

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: every hook passed, including the script test suite. (The first run failed on `test_script_tests_hook_scope.sh` needing a ROOT_READERS row; fixed in 6cb9cef3 and re-run.)
- Run alone: `test_register_project.sh` 105/0, `test_user_tier_install.sh` 211/0, `test_adapter.sh` 113/0, `test_project_file.sh` 474/0, `test_project_registry.sh` 263/0, `test_ros2_colcon.sh` 200/0; `check_design_anchors.sh` clean.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-28 10:19 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `e9a5fc45`
**Base**: main
**Depth**: Deep (reason: 2291 changed lines across 18 files; enforcement and governance files touched)
**Must-fix**: 3 | **Suggestions**: 2
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

Round taken as 1, not the counter's 8: this is PR 2 of 4 on a reused branch name, and PR 1's seven pre-push entries (merged as PR 403) still sit on the timeline (round counter spans PRs, issue 384). Whole diff main...HEAD classified fresh.

Reviewers: static analysis (pre-commit on the 18 changed files: all hooks pass, shellcheck and the script test suites included); governance and plan drift (no drift from plan PR 2; the AGENTS.md commit 18c4fb7b is accurate against the scripts and awaits the owner at the merge checkpoint); Claude adversarial (completed, but it did not cover registration_verify.sh or the _project_registry.sh changes, which the lead reviewed instead); Gemini via agy (ran, EXIT=0; its CLAUDE_CONFIG_DIR must-fix is a false positive, since user_tier_install.sh also writes the root file to $HOME/.claude); Codex (ran, EXIT=0). Tests use synthetic sandboxes only (HOME redirected, stub claude); none reads a real checkout.

### Findings
- [x] (must-fix) A '#' in the project path or in a field value (--role, --distro, --parent, --worktrees, --default-instance) is cut off by the registry parser (comment strip at _project_registry.sh:138), so a different directory or value is registered silently. Reject '#' (and blanks/'=' in field values), check that the parsed entry matches what was asked, and add a test (Codex + Claude) — `.agent/scripts/register_project.sh:523`
- [x] (must-fix) The registry lock is taken after the name-free, adopt and SETTINGS_EXISTED decisions. With two concurrent registrations of one name, the loser's rollback deletes the winner's settings file. Take the lock before those checks (or re-check under it), and only remove a settings file this run wrote (Codex + Claude) — `.agent/scripts/register_project.sh:844`
- [x] (must-fix) A failed settings backup (mktemp or cat) is ignored and the write proceeds. Rollback then either leaves the changed file or restores an empty or partial backup, and the restore (`cat > "$SETTINGS"`) is neither atomic nor checked. Abort before writing when the backup fails, and restore by rename with a warning on failure (Codex + Claude) — `.agent/scripts/register_project.sh:869`
- [x] (suggestion) For an adopted project, an interrupt reports "nothing is registered" and a failure says "kept as it is", even though the project stays registered and --set may already have changed its settings file. Word both for adoption (Gemini) — `.agent/scripts/register_project.sh:798`
- [x] (suggestion) An empty ~/.claude/agent-workspace-root makes `phys ""` return the cwd, so UT_STATE can wrongly be "here". Treat an empty file as absent (Claude) — `.agent/scripts/register_project.sh:733`

## Checkpoint
**Status**: complete
**When**: 2026-10-28 10:20 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the rounds checkpoint fired on a false count: review_progress.sh round reports 8 because the seven pre-push reviews of PR 1 of 4, merged as pull request 403, are still on this issue's timeline (issue 384); this branch is PR 2 of 4 and its review at a658c114 is its first round; three must-fix and two suggestions open, all mechanism fixes)
**After**: rounds
**Decision**: address

PR 2 of 4 (register_project.sh and its gate), first pre-push review, recorded at a658c114 as round 1: 3 must-fix (a "#" in a path or field value is cut by the registry comment strip and a different directory registers silently; the registry lock is taken after the name and settings checks, so a losing concurrent run's rollback deletes the winner's settings file; a failed settings backup is ignored and the restore is neither atomic nor checked) and 2 suggestions (an interrupt on an already-registered project says "nothing is registered"; an empty ~/.claude/agent-workspace-root reads as this checkout). Host's call on must-fix 2: take the registry lock before the name and settings checks and hold it for the whole run. Sent to address-findings. The owner's direction for this run: "Let's have bg agents continue working on both."

## Implementation
**Status**: complete
**When**: 2026-10-28 10:44 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-332 at `9a58881c`
**Addressed**: Local Review (Pre-Push) at `e9a5fc45` (2026-10-28 10:19 -04:00)
**Commits**: ffda2e5e, 8ad4b990, 949d7408, 50aecdc7, 9a58881c

### Actions
- [x] A '#', blank or '=' in the path or a field value is refused before anything is written, and install_registry checks the entry the parser reads back is the one asked for (ffda2e5e) — `.agent/scripts/register_project.sh:523`
- [x] The registry lock and the registry parse check come before every check (register and --remove), held through the last step; a dry run takes no lock. Tests: a run against a held lock refuses and changes nothing; a run that waited for the lock adopts the winner and keeps its settings file (fails on the old script) (8ad4b990) — `.agent/scripts/register_project.sh:844`
- [x] A failed settings backup refuses the run before the file changes; the restore copies beside the destination, renames, compares, and on failure keeps and names the backup; the pre-write read of the settings file is checked; failed() now prints its reason for a new registration (949d7408) — `.agent/scripts/register_project.sh:869`
- [x] An interrupt on an adopted project is NOT READY, and both interrupt and failure say nothing is rolled back and what the run already changed (line, settings file) (50aecdc7) — `.agent/scripts/register_project.sh:798`
- [x] An empty or unreadable ~/.claude/agent-workspace-root is read as absent, with a warning naming it (9a58881c) — `.agent/scripts/register_project.sh:733`

### Checks
- test_register_project.sh: 142 passed, 0 failed; each new test was also run against the script before its fix and failed there
- main checkout's pre-commit run --files over main...HEAD, no SKIP: every hook passed, validate-script-tests included

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-28 10:48 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `74d60acd`
**Base**: main
**Depth**: Deep (reason: 2631 changed lines across 18 files; enforcement and governance files touched; fix round classified on the whole diff, never lowered)
**Must-fix**: 2 | **Suggestions**: 5
**Round**: 2 | **Ship**: recommended — round 2: 2 mechanical must-fix (prev 3), not rising — fix and ship rather than another full round

Round taken as 2, not the counter's 9: this is PR 2 of 4 on a reused branch name, and PR 1's seven pre-push entries (merged as PR 403) still sit on the timeline (issue 384); this branch's round 1 is the entry at `e9a5fc45` (recorded at a658c114). `verdict` run with `--round 2 --prev-must-fix 3 --mechanical`.

Round-1 findings, all confirmed fixed against the code and tests: '#', blank and '=' refused in path and field values, with a read-back check in install_registry (ffda2e5e); registry lock taken before every check and held to the end, held-lock and race tests (8ad4b990); failed backup refuses, restore by copy-beside, rename and cmp, fault-injection tests (949d7408); adopted interrupt/failure wording (50aecdc7); empty root file read as absent (9a58881c).

Reviewers: static analysis (shellcheck --severity=warning on the 8 changed scripts and suites: clean; test_register_project.sh 142/0, and per the Claude adversarial run test_user_tier_install.sh 211/0 and test_adapter.sh 113/0); governance (AGENTS.md rows from 18c4fb7b still accurate against the scripts after the fix round; they await the owner at the merge checkpoint); plan drift (fix round touched only register_project.sh and its tests: none); Claude adversarial (completed, no must-fix; it did not check the docs); Gemini via agy (ran, EXIT=0, 3 suggestions); Codex (ran, EXIT=0, 3 must-fix, of which one is kept as must-fix, one merged into must-fix 2 and one taken as a suggestion). Tests use synthetic sandboxes only.

The builder's reported gap (an interrupt still says "nothing is registered" when the rollback warned it could not remove the line) is taken as a finding: it is must-fix 2.

### Findings
- [x] (must-fix) Legacy migration copies a command with a glob ('*', '?', '[') into the settings file, where it runs without a shell and is passed literally, while the legacy `exec $SP_CMD` expanded it (TEST_CMD="pytest tests/test_*.py"); an adopted project keeps the changed file. Leave such a value in the legacy file with the existing "not copied" warning, and add a test (Codex) — `.agent/scripts/register_project.sh:688`
- [x] (must-fix) The last lines claim a clean result after a failed cleanup: an interrupt says "nothing is registered" when rollback could not remove the line or restore the settings file (builder's gap); a signal between the registry rename and `LINE_WRITTEN=1` skips the line removal (set the flag before install_registry); --remove prints "removed the settings file" and STATUS=removed when `rm -f` fails, and its line-removal failure does not say the plugin is already disabled. Have rollback record an incomplete cleanup and let the final NEXT/STATUS say what is left (Codex + Claude) — `.agent/scripts/register_project.sh:928`
- [x] (suggestion) A settings path that exists but is not a regular file (dangling symlink, directory) sets SETTINGS_EXISTED=1 yet is neither backed up nor checked, so the run writes the registry first and a rollback can leave a file created through the dangling link; refuse it up front (Claude + Gemini) — `.agent/scripts/register_project.sh:714`
- [x] (suggestion) Rollback restores or deletes the settings file without checking it is still what this run wrote, so a `project_setting.sh set` made during a long build is lost; compare before restoring and keep it with a warning when it changed (Codex) — `.agent/scripts/register_project.sh:901`
- [x] (suggestion) Rollback's `--disable-root` can disable a plugin the root had enabled before this run; record the root's plugin state before step 4 and disable only what this run added (Claude) — `.agent/scripts/register_project.sh:890`
- [x] (suggestion) With `set -u` on and only INT/TERM/HUP trapped, an unexpected abort after the rollback is armed leaves the line and settings file with no report; add an EXIT trap guarded by ROLLBACK_ARMED (Claude) — `.agent/scripts/register_project.sh:952`
- [x] (suggestion) The python3 fallback in detect_commands prints "None" for `"build": null` in package.json (jq's `// empty` gives nothing); use `(... or {}).get("build") or ""` (Gemini) — `.agent/scripts/register_project.sh:238`

## Checkpoint
**Status**: complete
**When**: 2026-10-28 10:49 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (second address in a row at this checkpoint, within the cap; the rounds checkpoint fires on the false count from PR 1's entries (issue 384), this branch's own round 2 is at 89ac5d5d; two mechanical must-fix and five suggestions open, every one a correctness or silent-failure item, so all seven are addressed rather than shipped past)
**After**: rounds
**Decision**: address

PR 2 of 4, round 2 (taken as 2, counter says 9) at 89ac5d5d: 2 must-fix (M1 a legacy command with a wildcard loses its expansion when copied into the settings file, which runs without a shell; M2 clean-result lines after a failed cleanup: "nothing is registered" after a rollback that could not remove the line, a signal between the registry rename and LINE_WRITTEN=1 skips the line removal, --remove reports removed when the settings rm fails) and 5 suggestions (S1 dangling-symlink or directory settings path not backed up or checked; S2 rollback overwrites a settings change made during a long build; S3 rollback's --disable-root can disable a plugin the root had enabled before the run; S4 no EXIT trap, so an abort under set -u leaves no report; S5 --detect's python fallback prints None for a null package.json script). All seven sent to address-findings.

## Implementation
**Status**: complete
**When**: 2026-10-28 11:27 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-332 at `b55dd0bc`
**Addressed**: Local Review (Pre-Push) at `74d60acd` (2026-10-28 10:48 -04:00)
**Commits**: c398b83c, 547e2716, 66518ff6, 744f3ada, 09712d2d, d440e915, 831aa840, b55dd0bc

### Actions
- [x] (must-fix) A legacy command with a glob character (* ? [) is not copied into the settings file; it stays in the legacy file with a warning naming the key — `.agent/scripts/register_project.sh` (c398b83c)
- [x] (must-fix) No clean-result line after a failed cleanup: rollback records what it could not undo and names it on NEXT (NOT READY while the line is left); LINE_WRITTEN set before the registry rename and the rollback looks for the line; --remove reports a settings file it could not remove (STATUS=removed, settings file left, exit 1) and a line-removal failure says the plugin is already disabled — `.agent/scripts/register_project.sh` (547e2716)
- [x] (suggestion) A settings path that is a dangling symlink or not a regular file is refused before anything is written — `.agent/scripts/register_project.sh` (66518ff6)
- [x] (suggestion) Rollback keeps a settings file changed after this run wrote it (checksum compare), naming the backup; a file this run never wrote is never touched — `.agent/scripts/register_project.sh` (744f3ada; design.md sentence in b55dd0bc)
- [x] (suggestion) Rollback's --disable-root is skipped when the plugin was enabled at the root from this checkout before step 4 — `.agent/scripts/register_project.sh` (09712d2d)
- [x] (suggestion) EXIT trap, inert once the last lines are printed, handles an unchosen exit as a failure (rollback, or NOT READY for an adopted project) — `.agent/scripts/register_project.sh` (d440e915)
- [x] (suggestion) The python3 fallback in --detect reads a null/false script as empty, matching jq — `.agent/scripts/register_project.sh` (831aa840)

### Verification
- test_register_project.sh: 180 passed, 0 failed (was 142). Each new test was run against the pre-fix script (a scratch copy of the tree with the old register_project.sh): 25 checks fail there, at least one per finding.
- Main checkout venv pre-commit run --files over main...HEAD, no SKIP: every hook passed, validate-script-tests included.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-28 11:34 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `1a2255eb`
**Base**: main
**Depth**: Deep (reason: whole-branch classification unchanged from round 2, 18 files, enforcement files touched); round-3 scope narrowed by the host to the round-2 findings and the fix diff 89ac5d5d..1a2255eb, no cross-model reviewers
**Must-fix**: 1 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — round 3: 1 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

Round taken as 3, not the counter's 10: PR 1 of 4's pre-push entries (merged as PR 403) are still on this timeline (issue 384); this branch's rounds are the entries at a658c114 (round 1) and 89ac5d5d (round 2). `verdict` run with `--round 3 --prev-must-fix 2 --mechanical`. The task line named a "Round-3 convergence check" rule; no such section exists in review-code/SKILL.md (main or worktree), so the narrow scope and the skipped cross-model reviewers come from the host's task line, not the skill.

Round-2 findings, each confirmed fixed against the code and its tests: M1 glob-bearing legacy command stays in the legacy file, warned and marked set so detection does not override it (c398b83c); M2 rollback_left/LINE_LEFT name what a rollback could not undo on NEXT=, NOT READY while the line is left, LINE_WRITTEN set before the rename with the rollback looking the line up, --remove reports a settings file it could not delete (STATUS=removed, settings file left, exit 1) and says the plugin is already disabled when the line cannot be written (547e2716); S1 dangling link / non-regular settings path refused before any write (66518ff6); S2 checksum taken after this run's write, a changed file kept and the backup named (744f3ada); S3 plugin state read just before step 4, same definition as user_tier_install.sh plugin_state "enabled" (09712d2d); S4 EXIT trap guarded by FINAL_DONE and RUN_STARTED (d440e915); S5 python3 fallback reads null/false as empty (831aa840). The design.md sentence (b55dd0bc) matches the code.

Status contract: `removed, settings file left` (exit 1) follows the existing comma-qualified form (`registered, <verbs> not run`); NOT READY for a rollback that left the line keeps its meaning (registered, unchecked); STATUS/NAME/ROOT/NEXT stay the last lines, as the plan's stable last-lines rule asks. No consumer outside the script and its tests parses STATUS. Consistent.

Checks: test_register_project.sh 180 passed, 0 failed; shellcheck --severity=warning (main checkout venv) clean on register_project.sh and its suite. A scratch probe in the session scratchpad (synthetic sandbox, the suite's fixtures and fault stubs) reproduced the must-fix below.

### Findings
- [x] (must-fix) A signal during a rollback cuts it short and the last lines still claim a clean result: on_signal (and, for a second signal, on_exit) calls rollback, which is already disarmed, then prints STATUS=refused "interrupted; nothing is registered". Reproduced: build fails, TERM right after the rollback's registry mv, the settings file is left and not named; a signal during --disable-root would leave the line too. Mark the rollback as running and have on_signal return (resume it) while it runs, and on_exit name "the rollback stopped part way" with NOT READY; add a test (fault stub signal-after on mv during the rollback) — `.agent/scripts/register_project.sh:1029`

## Checkpoint
**Status**: complete
**When**: 2026-10-28 11:55 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: rounds
**Decision**: address

The owner's answer, in his words: "C fix". The question: fix the one must-fix the round-3 review (e8652419, this branch's round 3; the counter says 10, issue 384) left open before publishing PR 2 of 4, or publish now. The must-fix: a signal arriving during the rollback cuts it short while the last lines still say "interrupted; nothing is registered"; the fix lets a running rollback finish on a signal, reports "the rollback stopped part way" with NOT READY when the EXIT trap fires mid-rollback, with a test using the signal-after fault stub. The host had answered address twice in a row at this checkpoint, the cap, so the third answer was his. (Recorded after the fix pass was dispatched: a first write of this entry landed on the wrong branch, unpushed.)

## Implementation
**Status**: complete
**When**: 2026-10-28 12:09 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-332 at `ab758292`
**Addressed**: Local Review (Pre-Push) at `1a2255eb` (2026-10-28 11:34 -04:00)
**Commits**: ab758292

Owner's decision on the one must-fix, in his words: "C fix" (fix it before the pull request opens).

### Actions
- [x] (must-fix) A signal during a rollback cut it short and the last lines still claimed a clean result. Fixed: a signal while a failure, an interrupt or an unexpected exit is being handled (its rollback included) now returns and lets it finish (`ENDING` / `ROLLBACK_RUNNING`; `on_signal` and `on_exit` no longer reset the traps); an exit inside the rollback reports STATUS=NOT READY, "the rollback stopped part way", naming each unfinished step found left (`rollback_unfinished`); script header's status contract updated — `.agent/scripts/register_project.sh:1029`

### Tests
- Three new cases in `.agent/scripts/tests/test_register_project.sh` (synthetic sandboxes, existing signal-after fault stub): TERM after the rollback's registry rename on a failed build; a second TERM during an interrupt's rollback; an unset variable read inside a sandbox copy's rollback. On the pre-fix script: 183 passed, 6 failed (exactly the new checks); after the fix: 189 passed, 0 failed.
- Branch-wide `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: every hook passed, the script suite included. The fix commit itself skipped only `validate-script-tests` (#399 rule).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-28 12:13 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-332 at `6a923041`
**Base**: main
**Depth**: Deep (reason: whole-branch classification unchanged, enforcement files touched); round-4 scope narrowed by the host's task line (owner's standing review-depth exception, issue 321) to the round-3 must-fix and the fix diff e8652419..6a923041 (ab758292), no cross-model reviewers
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 4 | **Ship**: recommended — no must-fix findings; the one suggestion can be applied or tracked

Round taken as 4, not the counter's 11: PR 1 of 4's pre-push entries (merged as PR 403) are still on this timeline (issue 384); this branch's rounds are a658c114 (1), 89ac5d5d (2), e8652419 (3). `verdict` run with `--round 4 --prev-must-fix 1`.

Round-3 must-fix confirmed fixed (ab758292): failed(), on_signal and on_exit set ENDING, rollback sets ROLLBACK_RUNNING; a signal then makes on_signal return, and bash resumes the handler after the running command, so the rollback finishes and the last lines come from the original handler (failure: STATUS=refused with the failure's NEXT; interrupt: "interrupted; nothing is registered" only after a full rollback). The traps are no longer reset, so a second signal can no longer kill the run silently mid-rollback. An exit inside the rollback reaches on_exit with ROLLBACK_RUNNING=1: rollback_unfinished checks each step not yet marked done (line looked up on disk, settings by checksum, plugin named "perhaps") and the last lines are NOT READY, "the rollback stopped part way", never a clean result. Header status contract matches the code.

Signal behaviour change, judged acceptable: once a run is ending, further INT/TERM/HUP to the script are deferred until the rollback and last lines finish; only SIGKILL stops it. The ending work is bounded local steps (installer --disable-root, a registry rewrite and rename, an rm or a restore); before, a second signal killed bash with no EXIT trap and no last lines, leaving debris unreported. A terminal Ctrl-C still reaches a hung child step (the process group gets it; the installer's own INT/TERM traps exit 130/143), and that step's failure is then reported by the rollback (rollback_left, NOT READY while the line is left), not hidden — by reading, not probed. A supervisor's TERM to the script alone was already deferred by bash until the running child returned, so that case is unchanged.

Checks: test_register_project.sh 189 passed, 0 failed (main checkout venv shellcheck --severity=warning clean on register_project.sh and its suite). The builder's claim that the six new checks fail on the pre-fix script was not re-run here (the scratch-copy run was denied by the permission prompt).

### Findings
- [ ] (suggestion) rollback_unfinished does not name a settings backup left when the exit came after the settings step began but the file no longer matches this run's write (inside restore_settings after the rename, or a file changed during the run): the hidden .settings-backup.* in projects.d stays unnamed on NEXT; name "$SETTINGS_BACKUP" whenever it still exists — `.agent/scripts/register_project.sh:1029`

## Checkpoint
**Status**: complete
**When**: 2026-10-28 12:14 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (pre-push review approved at 75bceb21, round 4 of this branch, ship recommended; the one open suggestion carries into the pull-request rounds; the orchestrator's checkpoint table lets the host answer publish)
**After**: publish
**Decision**: publish

PR 2 of 4 for issue 332 (register_project.sh, registration_verify.sh, per-type registration.conf, user_tier_install.sh --disable-root, tests, plan and design edits): four pre-push rounds on this branch (taken as 1 to 4; the counter says 8 to 11 because PR 1's entries remain, issue 384), 13 findings fixed, round 4 approved with 1 suggestion open (name the hidden settings backup file when an unexpected exit leaves it). The owner's direction for this run: "Let's have bg agents continue working on both."; his "C fix" answer at round 3 is in. Publishing.

## Integrated Review
**Status**: complete
**When**: 2026-10-28 12:17 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #409 at `7b28b6f1`
**Sources**: 3 (Local Review (Pre-Push) @ `6a923041` (covers head `7b28b6f1` via bookkeeping), Copilot @ `7b28b6f1` (quota message only, no comments), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

PR 2 of 4 for issue 332. This branch's rounds: pre-push 1 to 4 (a658c114, 89ac5d5d, e8652419, round 4 reviewed code at 6a923041, recorded at 75bceb21); every earlier round's findings were fixed and confirmed by the next round; round 4 approved with one suggestion open, triaged below.
Not re-listed: the Local Reviews at `91366fc`, `b9bfcd6`, `8798ed5`, `8bc1d03` belong to PR 1 of 4 (PR 403, merged 2026-10-28) and were ruled on by its Integrated Reviews; `sources` lists them stale.
GitHub: one Copilot comment-review, the quota message, no inline comments; no conversation comments; no human reviews.
CI at `7b28b6f1`: Validate Adapter Contract, Validate Documentation, ros-manifest tests pass on both runs (40723988708, 40723979858); Lint (pre-commit) still pending on both; the `copilot-pull-request-reviewer` check fails on quota, not code.

Round-4 suggestion checked in the code (`.agent/scripts/register_project.sh:1022-1040`), valid: `rollback_unfinished` names the backup only while the settings file still matches this run's write. Two exits leave it unnamed: (a) inside `restore_settings` after the `mv` restored the file but before `rm` of the backup (the file now holds the pre-run content, so the checksum guard fails); (b) the file was changed during the run by someone else and the exit lands before the rollback's settings step (the normal rollback names the backup in a WARNING here; the cut-short path says nothing). The hidden `.settings-backup.*` then stays in `projects.d` with nothing on NEXT pointing at it; in (b) it is the only copy of the pre-run content. Shell globs skip dotfiles, so no reader trips on it; the cost is unreported debris, which the Quality Standard does not let pass.

### Findings
- [x] (suggestion, Local Review (Pre-Push) @ `6a923041`) An exit inside the rollback leaves the hidden settings backup unnamed when the settings file no longer matches this run's write (exit in `restore_settings` after the rename, or a file changed during the run). Fix: in `rollback_unfinished`, when the settings step is not done and `$SETTINGS_BACKUP` still exists, always name it: keep the current message when the file matches this run's write; otherwise add "the backup of the settings file's content before this run, $SETTINGS_BACKUP (remove it once $SETTINGS is right)"; add a test case in `test_register_project.sh` (sandbox copy with an unset-variable fault after the rename in `restore_settings`, as the existing rollback cases do) asserting the backup path is on the last lines — `.agent/scripts/register_project.sh:1029`

### False positives
- (Copilot @ `7b28b6f1`) Review body "unable to review ... insufficient remaining quota" — not a finding; no comments and no code claim to evaluate.

## Checkpoint
**Status**: complete
**When**: 2026-10-28 12:17 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (first address at this pull request's findings checkpoint; one valid suggestion, a silent leftover file in a rare exit path; mechanism fix, no goal question, no outward change)
**After**: findings
**Decision**: address

The Integrated Review at 57319ac6 (pull request 409, PR 2 of 4) has one open finding, a suggestion: when an exit cuts the rollback short, the hidden .settings-backup.* file in projects.d is never named, whether the exit fell inside restore_settings after the rename or the settings file was changed during the run. The host read the triage's fix plan (rollback_unfinished always names the backup while it exists, with a "remove it once the settings file is right" line when the file no longer matches this run's write; one new test with an unset-variable fault after the rename) and sends it to address-findings.

## Implementation
**Status**: complete
**When**: 2026-10-28 12:30 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #409 at `d0c72a0f`
**Addressed**: Integrated Review at `7b28b6f1` (2026-10-28 12:17 -04:00)
**Commits**: d0c72a0f

### Actions
- [x] An exit inside the rollback left the hidden settings backup unnamed when the settings file no longer matched this run's write: `rollback_unfinished` now names `$SETTINGS_BACKUP` whenever it exists — the existing message while the file matches this run's write, otherwise "the backup of the settings file's content before this run, <path> (remove it once <settings> is right)"; header status contract updated; new sandbox case in `test_register_project.sh` (unset-variable fault after the rename in `restore_settings`) fails on the pre-fix script (192 passed, 1 failed) and passes after (193 passed, 0 failed); box checked with `review_progress.sh check` in the fix commit — `.agent/scripts/register_project.sh:1030`

### Checks
- Main checkout's `.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: every hook passed, `validate-script-tests` included.

## Local Review
**Status**: complete
**When**: 2026-10-28 12:34 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #409 at `56d11847`
**Depth**: Narrow convergence check (reason: round 5 of PR 2 of 4 under the owner's standing review-depth exception, issue 321; scope set by the host: the one finding left open by the round-4 review and the Integrated Review at `57319ac6`, plus the fix diff since `75bceb21`, i.e. commit `d0c72a0f`; no cross-model reviewers)
**Must-fix**: 0 | **Suggestions**: 0

Round count: this branch's pre-push rounds are `a658c114`, `89ac5d5d`, `e8652419`, `75bceb21`, so this is its round 5. The earlier `## Local Review` entries on this timeline belong to PR 1 of 4 (merged as pull request 403) and are not counted (issue 384).

Finding checked: a rollback cut short left the hidden `.settings-backup.*` unnamed when the settings file no longer matched this run's write. Confirmed fixed in `rollback_unfinished` (`.agent/scripts/register_project.sh:1031-1052`): while the settings step is unfinished and the backup exists it is always named, with the old wording when the file still matches this run's write and the new "remove it once ... is right" wording otherwise; the no-backup new-file branch keeps its old condition (`ours`). The new path also covers an exit after `backup_settings` and before `SETTINGS_WRITING=1` inside a rollback. Header status contract updated to match.

Verified: `test_register_project.sh` 193 passed, 0 failed on the head; the same suite against a scratch copy with the pre-fix `register_project.sh` (`d0c72a0f^`) gives 192 passed, 1 failed, the failure being the new case "the backup is named on NEXT, to remove once the settings file is right"; the test's sed fault lands after the restore's rename and before `rm` of the backup, as intended; shellcheck --severity=warning clean on both changed files.

Outside this review's scope, not a finding on the fix (for the host to judge): the ordinary rollback (not cut short) leaves the backup unnamed when it was made but `SETTINGS_WRITING` is still 0 — a signal between `backup_settings` and `SETTINGS_WRITING=1` (`register_project.sh:1182-1185`, an echo loop) takes the `:` branch at line 1000, and the run ends `refused` with the hidden backup left in `projects.d`. Pre-existing and a narrow window.

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-10-28 12:37 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #409 at `c0710b66`
**Sources**: 3 (Local Review @ `56d11847` (covers head `c0710b66` via bookkeeping), Copilot @ `56d11847` (quota message only, no comments), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

PR 2 of 4 for issue 332. Builds on the Integrated Review at `7b28b6f1` (one suggestion, fixed in `d0c72a0f`, confirmed by the round-5 Local Review at `56d11847`); not re-listed. The Local Reviews at `91366fc`, `b9bfcd6`, `8798ed5`, `8bc1d03` belong to PR 1 of 4 (PR 403, merged) and the Pre-Push at `6a92304` was ruled on by the Integrated Review at `7b28b6f1`; `sources` lists all five stale.
GitHub: three Copilot comment-reviews (at `7b28b6f1`, `2582cdda`, `56d11847`), each the quota message, no inline comments; no conversation comments; no human reviews.
CI at `c0710b66`: Validate Adapter Contract, Validate Documentation, ros-manifest tests pass on both runs (40727416331, 40727406353); Lint (pre-commit) still pending on both.

The round-5 review's out-of-scope note, judged as a finding and reproduced: a sandbox copy of `register_project.sh` with an unset-variable fault on the line before `SETTINGS_WRITING=1` (`.agent/scripts/register_project.sh:1185`), registering over an existing settings file with `--set test=none`, ends exit 1, `STATUS=refused`, "removed the registry line", NEXT names nothing else, and `projects.d/.settings-backup.*` is left. Cause: `backup_settings` (line 1182) sets `SETTINGS_BACKUP` and makes the copy, then the echo loop runs before `SETTINGS_WRITING=1`; `rollback`'s `SETTINGS_WRITING -eq 0` branch (line 1000) is a `:`, so the backup is neither removed nor named. An interrupt in the same window (on_signal) or after `mktemp` inside `backup_settings` takes the same branch. The plan's order rule ("so a failed registration leaves nothing behind") and the header's contract cover it, and the existing failed-backup case already asserts "no backup file left"; a silent leftover is what the Quality Standard does not let pass. Valid; the settings file itself is untouched in this window, so the backup is a redundant copy and removing it is safe.

### Findings
- [x] (suggestion, Local Review @ `56d11847` note outside its scope) A rollback after `backup_settings` but before `SETTINGS_WRITING=1` (an interrupt or unexpected exit in the echo loop, or inside `backup_settings` after its `mktemp`) leaves the hidden `.settings-backup.*` in `projects.d`, unnamed, and the run ends `refused` as if nothing were left. Fix: in `rollback`, replace the `:` of the `SETTINGS_WRITING -eq 0` branch with: when `$SETTINGS_BACKUP` is set and exists, `rm -f` it (this run never wrote the settings file, so the backup only duplicates it); if it is still there, warn and `rollback_left "the backup of the settings file's content before this run, $SETTINGS_BACKUP (remove it)"`. Add a sandbox case in `test_register_project.sh` like the existing rollback cases: fault `: "$REGISTER_TEST_UNSET_VARIABLE"` inserted before `    SETTINGS_WRITING=1`, an existing settings file, `--set test=none`; assert non-zero exit, `STATUS=refused`, the settings file byte-identical to its pre-run copy, no registry line, and no `.settings-backup.*` or `.settings-restore.*` left; show it fails on the current script — `.agent/scripts/register_project.sh:1000`

### False positives
- (Copilot @ `7b28b6f1`, `2582cdda`, `56d11847`) Review bodies "unable to review ... insufficient remaining quota" — not findings; no comments and no code claim to evaluate.
- (Local Review @ `56d11847`) The unchecked box "No issues found. LGTM." — not a finding: the review's verdict is approved with 0 must-fix and 0 suggestions; the box is how it wrote "no findings", and `sources` reads every open box as one.

## Checkpoint
**Status**: complete
**When**: 2026-10-28 12:37 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (second address in a row at this pull request's findings checkpoint, within the cap; one valid suggestion, reproduced, in the path the plan promises leaves nothing behind; mechanism fix, no goal question, no outward change)
**After**: findings
**Decision**: address

The Integrated Review at 2bfbb7f5 (pull request 409, PR 2 of 4) has one open finding, a suggestion: an interrupt or unexpected exit after backup_settings and before SETTINGS_WRITING=1 takes the rollback's do-nothing branch, so the run ends refused with the hidden .settings-backup.* file left in projects.d and NEXT naming nothing. The host read the triage's fix plan (that branch removes the backup when it exists, since the settings file was never written in that window; a failed removal warns and names the file through rollback_left; one sandbox test with the fault before SETTINGS_WRITING=1 and an existing settings file, asserting STATUS=refused, the settings file byte-identical, no registry line and no leftover files, failing on the current script) and sends it to address-findings.

## Implementation
**Status**: complete
**When**: 2026-10-28 12:54 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #409 at `6f0e6704`
**Addressed**: Integrated Review at `c0710b66` (2026-10-28 12:37 -04:00)
**Commits**: 6f0e6704

### Actions
- [x] A rollback after `backup_settings` and before `SETTINGS_WRITING=1` left the hidden `.settings-backup.*` unnamed with `STATUS=refused`: the `SETTINGS_WRITING -eq 0` branch of `rollback` now removes the backup (the settings file was never written, so it only duplicates it), and when the removal fails warns and names it through `rollback_left`; the header's rollback paragraph says so. New sandbox test (fault before `SETTINGS_WRITING=1`, existing settings file, `--set test=none`) asserts non-zero exit, `STATUS=refused`, the settings file byte-identical, no registry line, no backup or restore file left, plus the removal-failure path naming the backup on NEXT; it failed 2 checks on the script before the fix and passes after — `.agent/scripts/register_project.sh:1000`, `.agent/scripts/tests/test_register_project.sh:875`

### Checks
- `test_register_project.sh`: 196 passed, 2 failed before the fix (the new checks); 198 passed, 0 failed after.
- Fix commit made with every hook, the script suite included (no SKIP); box checked with `review_progress.sh check` (it points at this Integrated Review), in the same commit.
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: passed (exit 0).
- Not pushed; the host owns the push.

## Local Review
**Status**: complete
**When**: 2026-10-28 12:58 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #409 at `94a2c149`
**Depth**: Narrow convergence check (reason: round 6 of PR 2 of 4 under the owner's standing review-depth exception, issue 321; scope set by the host: the one finding the Integrated Review at `2bfbb7f5` opened, plus the fix diff since `c0710b66`, i.e. commit `6f0e6704`; no cross-model reviewers)
**Must-fix**: 0 | **Suggestions**: 0

Round count: this branch's rounds are the four pre-push ones (`a658c114`, `89ac5d5d`, `e8652419`, `75bceb21`) and the PR-mode round 5 at `56d11847` (recorded as `c0710b66`), so this is its round 6. The earlier `## Local Review` entries on this timeline belong to PR 1 of 4 (merged as pull request 403) and are not counted (issue 384).

Finding checked: an interrupt or unexpected exit after `backup_settings` and before `SETTINGS_WRITING=1` took the rollback's do-nothing branch and left the hidden `.settings-backup.*` unnamed. Confirmed fixed in `rollback` (`.agent/scripts/register_project.sh:1001-1009`): the `SETTINGS_WRITING -eq 0` branch now removes the backup when it is set and exists (the settings file was never written in that window, so it only duplicates it), and a failed removal warns and names it through `rollback_left`, which `rolled_back_final` puts on NEXT. The signal path (`on_signal` → `rollback`) and a partial `cp` inside `backup_settings` reach the same branch. Header rollback paragraph updated to match.

Verified: `test_register_project.sh` 198 passed, 0 failed on the head; the same suite in a scratch worktree with the pre-fix `register_project.sh` (`6f0e6704^`) gives 196 passed, 2 failed, the two being the new checks (no backup left; the failed removal named on NEXT); the test's sed fault lands on the line before `SETTINGS_WRITING=1`, after the backup; shellcheck --severity=warning clean on both changed files.

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-10-28 13:06 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #409 at `e3b8736f`
**Sources**: 3 (Local Review @ `94a2c149` (covers head `e3b8736f` via bookkeeping), Copilot @ `94a2c149` (quota message only, no comments), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

PR 2 of 4 for issue 332. Builds on the Integrated Reviews at `7b28b6f1` and `c0710b66` (one suggestion each, fixed in `d0c72a0f` and `6f0e6704`, each confirmed by the next Local Review); not re-listed. The round-6 Local Review at `94a2c149` is approved with 0 must-fix and 0 suggestions. The Local Reviews at `91366fc`, `b9bfcd6`, `8798ed5`, `8bc1d03` belong to PR 1 of 4 (PR 403, merged), and the Pre-Push at `6a92304` and the Local Review at `56d1184` were ruled on by the earlier Integrated Reviews; `sources` lists all six stale.
GitHub: six Copilot comment-reviews (at `7b28b6f1`, `2582cdda`, `56d11847`, `c0710b66`, `f086190e`, `94a2c149`), each the quota message, no inline comments; no conversation comments; no human reviews.
Fix spot-checked at the head: the `SETTINGS_WRITING -eq 0` branch of `rollback` (`.agent/scripts/register_project.sh:1001-1009`) removes the backup, and a failed removal warns and names it through `rollback_left`, as the round-6 review states.
CI at `e3b8736f`: Validate Adapter Contract, Validate Documentation, ros-manifest tests pass on both runs (40731261838 push, 40731269831 pull_request); Lint (pre-commit) passed on the push run and was still in progress on the pull_request run after a 7-minute wait, hence pending.

### Findings

### False positives
- (Copilot @ `7b28b6f1`, `2582cdda`, `56d11847`, `c0710b66`, `f086190e`, `94a2c149`) Review bodies "unable to review ... insufficient remaining quota" — not findings; no comments and no code claim to evaluate.
- (Local Review @ `94a2c149`) The unchecked box "No issues found. LGTM." — not a finding: the review's verdict is approved with 0 must-fix and 0 suggestions; the box is how it wrote "no findings", and `sources` reads every open box as one.

## Checkpoint
**Status**: complete
**When**: 2026-10-28 13:16 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: merge
**Decision**: merge

The owner's answer, in his words: "yes to both" (B: this pull request, AGENTS.md rows included). Presented: PR 2 of 4, 17 findings fixed across six rounds, round 6 approved with nothing open, the Integrated Review at 67758e99 clean, the AGENTS.md commit 18c4fb7b (two Script Reference rows and one clause on the validate_adapter.sh row) named as the Ask First item. Merge of pull request 409.

## Implementation
**Status**: complete
**When**: 2026-10-28 13:35 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #409 at `9d8c1281`
**Commits**: 9d8c1281

Merge of main (`cd60bc2a`, pull request 400, the orchestrator skill for issue 321) into feature/issue-332 at `62feab91`; no rebase, no squash, default merge message.

### Actions
- [x] One content conflict, `docs/design.md`, in the change-log table only: both sides appended a row after the 2026-10-21 row. Kept both rows, main's issue 321 row (2026-10-15, "Who answers a checkpoint", 800) first and this branch's issue 332 row (2026-10-28, "Registration is built") after it; no sentence dropped from either side.
- [x] Set this branch's row's line count from 807 to 819, the merged file's `wc -l docs/design.md`, so the last row's count equals the file length. Main's row keeps its own 800.
- [x] Every other file, and every other hunk of `docs/design.md` (main's How it works, Direction row, Rules row, Review loop and timeline, Glossary changes), auto-merged; nothing changed beyond the conflict resolution.

### Checks
- `.agent/scripts/check_design_anchors.sh .`: exit 0.
- `.agent/scripts/tests/run_script_tests.sh`: all 39 suites passed (511s).
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: exit 0, every hook passed or skipped (run before the merge commit, against this branch's changed files).
- The merge commit ran its hooks (pre-commit's merge mode checks conflicted files only): passed.
- Not pushed; the host owns the push.

## Local Review
**Status**: complete
**When**: 2026-10-28 13:44 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #409 at `db76490a`
**Depth**: Narrow convergence check (reason: round 7 of PR 2 of 4 under the owner's standing review-depth exception, issue 321; scope set by the host: only the merge of main (`cd60bc2a`, pull request 400, issue 321) into this branch at `62feab91`, merge commit `9d8c1281`; no cross-model reviewers)
**Must-fix**: 0 | **Suggestions**: 0

Round count: this branch's rounds are the four pre-push ones (`a658c114`, `89ac5d5d`, `e8652419`, `75bceb21`) and the PR-mode rounds 5 at `56d11847` and 6 at `94a2c149` (recorded as `e3b8736f`), so this is its round 7. The earlier `## Local Review` entries on this timeline belong to PR 1 of 4 (merged as pull request 403) and are not counted (issue 384).

Checked: `main` and `origin/main` are both `cd60bc2a`, the merge's second parent. `git diff main...HEAD` names the same files as the pre-merge branch diff (`git diff b120d541 62feab91`, `b120d541` being the old merge base), and every file's changed lines match, except `docs/design.md` (only this branch's change-log row count, 807 to 819) and this issue's `progress.md` (only the 22-line Implementation entry added in `db76490a`). `git diff main 9d8c1281` equals `git diff b120d541 62feab91` byte for byte outside `docs/design.md`, and for `docs/design.md` main's own changes (`git diff b120d541 cd60bc2a`) reappear unchanged in `git diff 62feab91 9d8c1281` apart from hunk offsets and the count row, so no text from either side was lost. The change-log ends with main's issue 321 row (count 800, equal to main's own file length) and then this branch's issue 332 row (819); `wc -l docs/design.md` is 819; no conflict markers. `check_design_anchors.sh` on the worktree: exit 0. `run_script_tests.sh`: all 39 suites passed (419s).

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-10-28 13:53 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #409 at `9e1f2720`
**Sources**: 3 (Local Review @ `db76490a` (covers head `9e1f2720` via bookkeeping), Copilot @ `db76490a` (quota message only, no comments), CI rollup)
**Cross-source confirmations**: 0
**CI**: all-pass

PR 2 of 4 for issue 332. Builds on the Integrated Review at `e3b8736f` (clean, no findings); not re-listed. Since then main (`cd60bc2a`, pull request 400) was merged in as `9d8c1281`, and the round-7 Local Review at `db76490a` confirmed the merge exact (approved, 0 must-fix, 0 suggestions). The Local Reviews at `91366fc`, `b9bfcd6`, `8798ed5`, `8bc1d03` belong to PR 1 of 4 (pull request 403, merged), and the Pre-Push at `6a92304` and the Local Reviews at `56d1184` and `94a2c14` were ruled on by earlier Integrated Reviews; `sources` lists all seven stale.
GitHub: ten Copilot comment-reviews (latest at `db76490a`), each the quota message, no inline comments; no conversation comments; no human reviews.
Merge spot-checked at the head: `9d8c1281` has parents `62feab91` and `cd60bc2a`; `docs/design.md` is 819 lines, its change log ends with the issue 321 row (2026-10-15) then this branch's issue 332 row (2026-10-28); no conflict markers in the tree.
CI at `9e1f2720`: Lint (pre-commit), Validate Adapter Contract, Validate Documentation and ros-manifest tests pass on both runs (40738607126 push, 40738616457 pull_request).

### Findings

### False positives
- (Copilot @ `7b28b6f1` through `db76490a`, ten reviews) Review bodies "unable to review ... insufficient remaining quota" — not findings; no comments and no code claim to evaluate.
- (Local Review @ `db76490a`) The unchecked box "No issues found. LGTM." — not a finding: the review's verdict is approved with 0 must-fix and 0 suggestions; the box is how it wrote "no findings", and `sources` reads every open box as one.

## Implementation
**Status**: complete
**When**: 2026-10-28 14:21 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-332 at `c5c481a6`

PR 3 of 4 (the `onboard-project` rewrite), on main `e0bab748`. No pull request yet.

### Actions
- [x] `9ecb7078` `project_integration_audit.sh` (new, read-only, inert marker): `[--dir D | --project N] [--format tsv|text]`, TSV `category<TAB>id<TAB>severity<TAB>subject<TAB>detail`, exit 0 whatever it finds, 2 on usage or a directory under no registered root. Categories 1 to 6 as the plan lists them, each with stable ids; a finding whose fix is a tracked file drops to info when `instructions=none`. `test_project_integration_audit.sh` (new): every category with a finding, a clean project with none, the hand-registered fixture reproducing one id per category, records settings against `.agent/work-plans/`, read-only snapshot, refusals; declared in `test_script_tests_hook_scope.sh`.
- [x] `8a070061` User tier: the audit, `registration_verify.sh` and `project_setting.sh` promoted. `project_setting.sh` set/unset now call `registry_require_root` and, from a project root, write only that project's file (or a parent root's instance); reads unchanged; the linked-worktree refusal still comes first. `test_user_tier_guard.sh`: probe for the guarded writer, read-only rows for the two inert scripts.
- [x] `ec194faa` `/onboard-project` rewritten per plan item 2 (`[--dry-run] [--reask <key>]`, no repo argument, session_root.sh resolution, footprint questions with the provisional default, the "until the records lookup (#393) lands" wording, offers only when `instructions=tracked`, the four answers and `## Onboarding` roadmap section with the owner's D6 words verbatim, every write waits for a yes, hygiene checklist in a labelled section until PR 4). `test_skill_paths.sh` holds the wording and parses the skill's bash blocks.
- [x] `2472f8e2` design.md (Sessions and roots exception and onboarding bullet, Registry Target, Documentation layers, change-log row 836), roadmap (the "waits until onboarding asks" deferral now names the offer with a true revisit check; sit-rep row notes `ROADMAP.md`), `skill_workflows.md` row.
- [x] `c5c481a6` AGENTS.md: one Script Reference row for the audit, its own commit, nothing else (Ask First).

### Plan vs merged code / plan text
- Test file named `test_project_integration_audit.sh` as the handoff said (the plan's table says `test_integration_audit.sh`).
- Category 6 runs `registration_verify.sh` without `--user-tier` and runs `user_tier_install.sh --check --require` and `session_root.sh --dir` itself, so each gets a stable id; same three checks the plan names.
- The old skill's `.agent/templates/pre-commit-config.yaml` and `ci_workflow.yml` never existed in this repository (no git history); the checklist rows now say no template exists.
- AGENTS.md's existing `project_setting.sh` row does not mention the new write guard (only new rows were allowed); the script header does.

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: exit 0, every hook passed or skipped, the script suite hook included.
- `.agent/scripts/check_design_anchors.sh .`: exit 0.
- Suites run directly: test_project_integration_audit (75 passed), test_user_tier_guard, test_skill_paths (98), test_project_file (474), test_register_project (198), test_user_tier_install (211), test_session_root (69), test_plugin_manifest (12), test_sitrep_checks (186), test_script_tests_hook_scope (149): all 0 failed.
- Not covered by a test: the `session-root` finding (no synthetic setup makes `session_root.sh` fail at an existing registered root). Not pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-28 14:25 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `4214aa7c`
**Base**: main
**Depth**: Deep (reason: 1544 changed lines over 13 files, with AGENTS.md and a SKILL.md)
**Must-fix**: 7 | **Suggestions**: 7
**Round**: 1 | **Ship**: continue — round 1: 7 must-fix; first round always re-reviews after fixes

Round taken as 1 on the host's instruction: this is PR 3 of 4, a new diff, and `review_progress.sh round` reported round=12 only because the eleven pre-push entries of PRs 403 and 409 (parts 1 and 2, merged from branches of the same name) are still on this issue's timeline (issue 384). Classified on the whole `main...HEAD` diff; cross-model dispatched as a first review; verdict computed with `--round 1`, no `--prev-must-fix`.

Reviewers: Claude adversarial ran (four suites green: audit 75, hook scope 149, skill paths 98, user-tier guard 63); Gemini (agy) ran, complete; Codex ran, complete. Static: shellcheck --severity=warning clean on the six changed shell files. Checked and holding: the audit exits 0 whatever it finds; the tests build synthetic sandboxes only (the real checkout is only the source the scripts are copied from, HOME redirected); the D6 quote is verbatim; every path the new skill names exists. Dropped: Gemini's logical-$PWD finding in project_setting.sh (false positive: the resolver canonicalizes, `_project_registry.sh:521`).

### Findings
- [x] (must-fix) `git check-ignore -v --no-index` exits 0 and prints the rule for a negated (`!`) pattern, so a path a project explicitly un-ignores (e.g. `*.md` then `!AGENTS.md`) is reported as `ignore-would-hide`; verified in a scratch repo — `.agent/scripts/project_integration_audit.sh:372`
- [x] (must-fix) Step 7 runs `worktree_create.sh --issue <N> --type project` without `--project <name>`; with `--type` given, the cwd is not used, so it picks a legacy `project/` checkout (wrong repository) or fails when several are registered (Codex; `worktree_create.sh:252,349-388`) — `.claude/skills/onboard-project/SKILL.md:292`
- [x] (must-fix) At a parent root, `session_root.sh` gives the parent's name, and every `project_setting.sh set <name>` the skill shows is refused (`_project_registry.sh:1550`, settings belong to instances); resolve the default/only instance as the audit does, or ask (Codex) — `.claude/skills/onboard-project/SKILL.md:91,143,183`
- [x] (must-fix) No path for a project that does not use issues: step 7 needs `<N>` for `worktree_create.sh`, which requires an issue or an allowlisted skill, yet the skill promises edits left on a branch for a project with no GitHub (Codex); needs a decision on how such a project's onboarding branch is made — `.claude/skills/onboard-project/SKILL.md:285-300`
- [x] (must-fix) PR and issue bodies use an unquoted heredoc around finding text (category 2 lines often carry backticked commands, which the shell would run) and `$AGENT_NAME`/`$AGENT_MODEL`, normally unset in a project session, so the signature renders empty; no identity step for the step 7 commits (Gemini, Claude) — `.claude/skills/onboard-project/SKILL.md:303-320,329-343`
- [x] (must-fix) "The writes this skill can make are ..." omits the hygiene checklist's remote writes (`gh api` branch protection and Copilot review, `gh label create`, `git bug bridge new`); name them and say each runs only after its own yes (Claude) — `.claude/skills/onboard-project/SKILL.md:69-73,379-401`
- [x] (must-fix) The `instructions=none` downgrade is claimed for every finding whose fix is a tracked file (script header, AGENTS.md row, SKILL.md:136-137), but only `emit_offer` downgrades; `skill-same-name`, `command-same-name`, `old-work-plans`, `records-two-places`, `work-plans-ignored`, `process-branch`, `process-issue` stay `warn`; route them through `emit_offer` or narrow the claim (Claude) — `.agent/scripts/project_integration_audit.sh:19-23,171-178`
- [x] (suggestion) `build_candidates` matches the project's own commands as substrings, so `build=make` hides `cmake --build build`; match on command boundaries, per command (Codex) — `.agent/scripts/project_integration_audit.sh:297-299`
- [x] (suggestion) The worktrees directory is canonicalized only when it exists, so for a root registered through a symlink (directory not yet created, the usual case after registration) `worktrees-not-ignored` is silently skipped (Gemini) — `.agent/scripts/project_integration_audit.sh:319-321`
- [x] (suggestion) `candidate()`'s overflow total counts lines the skip pattern drops; `indent_out` is unused (Gemini) — `.agent/scripts/project_integration_audit.sh:273,399`
- [x] (suggestion) `clean()` uses the GNU-only `sed ':a;N;$!ba;...'`; on BSD sed it errors and every field is emptied; `tr`/awk is portable (Claude) — `.agent/scripts/project_integration_audit.sh:156`
- [x] (suggestion) The category-6 fix text tells the user to `set <name> build=<command>`, which a `ros2_colcon` project refuses (`unused_settings`); say it applies to `single_project` (Claude) — `.claude/skills/onboard-project/SKILL.md:117-122`
- [x] (suggestion) Tests missing for: the `session-root` finding (builder's note), a parent-type root, a negated ignore rule, the remaining ids under `instructions=none`, the more-than-10 cap — `.agent/scripts/tests/test_project_integration_audit.sh`
- [x] (suggestion) AGENTS.md: the `project_setting.sh` row does not mention the new write guard (`registry_require_root`; from a project root only its own file), and the new audit row repeats the over-wide `instructions=none` claim; fix both in the AGENTS.md commit — `AGENTS.md:408-411`

## Checkpoint
**Status**: complete
**When**: 2026-10-28 14:26 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the rounds checkpoint fires on the false count from the merged parts' entries (issue 384); this branch, PR 3 of 4, had its round 1 at 10aef17f; seven must-fix and seven suggestions open, all mechanism; the one design point, M4, decided by the host and listed for the owner's veto)
**After**: rounds
**Decision**: address

PR 3 of 4 (the onboard-project rewrite), round 1 (taken as 1, counter says 12) at 10aef17f: 7 must-fix (M1 a deliberately un-ignored file reported as hidden; M2 the project worktree created without --project; M3 settings writes refused at a parent root; M4 no branch path for a project without issues; M5 unquoted heredocs run backticks from finding text, empty signature and no identity step in a project session; M6 remote writes missing from the every-write list; M7 seven ids stay warn under instructions=none) and 7 suggestions (S1 substring match on build commands; S2 symlinked root skips the worktrees check; S3 overflow count and an unused helper; S4 GNU-only sed; S5 category-6 fix text wrong for ros2_colcon; S6 missing tests; S7 the AGENTS.md rows). Host's decision on M4: a project with no issue tracker gets its onboarding branch through the skill-worktree path, onboard-project added to the worktree_create.sh skill allowlist (branch skill/onboard-project-<timestamp>, --type project --project <name>); a project that uses issues keeps the issue worktree with the issue the skill opens. All fourteen sent to address-findings.

## Implementation
**Status**: complete
**When**: 2026-10-29 10:20 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-332 at `fdf9cc9c`
**Addressed**: Local Review (Pre-Push) at `4214aa7c` (2026-10-28 14:25 -04:00)
**Commits**: 5514f5ff, 503b3afb, 2d68adb6, a1499311, e363dda6, af2d0f42, 559cdc6a, 65810920, b05b5ae3, 732929e8, b7d5d216, a580c161, 591ec23b, ce28b0e8, fdf9cc9c

The fixes were made in a fix pass on 2026-10-28 that checked each box in its fix commit but wrote no entry; this pass verified each against `git diff 4214aa7c..HEAD` and the files, found every one done, changed nothing, and writes the entry. No-SKIP pre-commit over `main...HEAD` (16 files) on `fdf9cc9c`: exit 0 in 522 s, the script suite hook passed.

### Actions
- [x] M1 negated ignore rule reported as hidden: `check-ignore -q` decides, `-v` only names the rule; test with `*.md` + `!AGENTS.md` (5514f5ff) — `.agent/scripts/project_integration_audit.sh:472`
- [x] M2 step 7 without `--project`: both worktree commands pass `--project <settings-name>`, with the reason (503b3afb, then a1499311) — `.claude/skills/onboard-project/SKILL.md:324-352`
- [x] M3 settings writes refused at a parent root: step 1 resolves `<settings-name>` (default or only instance, else ask); every `project_setting.sh` call uses it; the audit gains `--instance`; tests for the parent root, `--instance`, an instance write and the parent name refused (2d68adb6) — `.claude/skills/onboard-project/SKILL.md:115-136`, `.agent/scripts/project_integration_audit.sh:162-176`
- [x] M4 no branch for a project without issues (host decision): `onboard-project` on the `worktree_create.sh` skill allowlist; `--skill onboard-project --type project --project <name>` makes a worktree of the root's own repository on `skill/onboard-project-<timestamp>`, refusing a root that is not a repository top; skill, start-task, design.md updated; tests in test_project_registry.sh (a1499311; AGENTS.md allowlist in ce28b0e8) — `.agent/scripts/worktree_create.sh:90,555-565`
- [x] M5 unquoted heredocs and empty signature: quoted `<<'EOF'` bodies, signature appended by `printf` after sourcing the identity in the same shell and stopping when unset; identity sourced in the chain of every step 7 commit (e363dda6) — `.claude/skills/onboard-project/SKILL.md:356-424`
- [x] M6 remote writes missing from the write list: the list names branch protection and Copilot review, labels and the git-bug bridge, each on its own yes (af2d0f42) — `.claude/skills/onboard-project/SKILL.md:69-82`
- [x] M7 `instructions=none` claim wider than the code: all ten tracked-file ids go through `emit_offer`, the header lists them and why the rest keep severity; tests for each id (559cdc6a) — `.agent/scripts/project_integration_audit.sh:27-35`
- [x] S1 build commands matched as substrings: a line's commands split and compared one at a time on word boundaries; tests for `make` vs `cmake --build` (65810920) — `.agent/scripts/project_integration_audit.sh:322-397`
- [x] S2 symlinked root skips the worktrees check: the deepest existing ancestor is canonicalized and the rest appended; test with a symlinked root and no worktrees/ (b05b5ae3) — `.agent/scripts/project_integration_audit.sh:408-420`
- [x] S3 overflow count and unused `indent_out`: the count is of kept lines only, helper dropped; more-than-10 cap test (732929e8) — `.agent/scripts/project_integration_audit.sh:300-320`
- [x] S4 GNU-only sed in `clean()`: awk join (b7d5d216) — `.agent/scripts/project_integration_audit.sh:183`
- [x] S5 category-6 fix text wrong for ros2_colcon: the build/test setting applies to `single_project`; ros2_colcon refuses them, pointing to its `unused_settings` (a580c161) — `.claude/skills/onboard-project/SKILL.md:151-161`
- [x] S6 missing tests: session-root (591ec23b), parent root (2d68adb6), negated rule (5514f5ff), the ids under `instructions=none` (559cdc6a), the cap (732929e8); skill text checks (fdf9cc9c) — `.agent/scripts/tests/test_project_integration_audit.sh`
- [x] S7 AGENTS.md rows: `project_setting.sh` names the `registry_require_root` write guard; the audit row narrows the claim to the header's ids and adds `--instance` (ce28b0e8) — `AGENTS.md:408-411`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-29 10:30 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `377b4e29`
**Base**: main
**Depth**: Deep (reason: 1868 changed lines over 16 files, with AGENTS.md and a SKILL.md; fix-round re-review on the whole-diff tier)
**Must-fix**: 2 | **Suggestions**: 8
**Round**: 2 | **Ship**: continue — round 2: 2 must-fix include a design/correctness concern (not mechanical)

Round taken as 2 on the host's instruction: this is PR 3 of 4, whose round 1 was the `## Local Review (Pre-Push)` of 2026-10-28 14:25 at 4214aa7c; `review_progress.sh round` reported round=13 only because the eleven pre-push entries of PRs 403 and 409 (parts 1 and 2) are still on this issue's timeline (issue 384). Not a convergence check: full re-review of the fix diff 4214aa7c..fdf9cc9c (15 commits) with the cross-model reviewers, after a round with must-fixes. Verdict computed with `--round 2 --prev-must-fix 7`.

All 14 round-1 findings checked closed in the code and tests (M1 `check-ignore -q` gate with a `!` rule test; M2/M4 both worktree commands pass `--project <settings-name>`; M3 instance resolution, `--instance`, guarded writes; M5 quoted heredocs, printf signature, identity in each commit chain; M6 write list; M7 the ten ids through `emit_offer`; S1-S7). The host's M4 decision is implemented as recorded: `onboard-project` on the `worktree_create.sh` allowlist, branch `skill/onboard-project-<timestamp>`, `--skill onboard-project --type project --project <name>`, a worktree of the root's own repository, refused when the root is not a repository top; AGENTS.md, start-task and design.md say so.

Reviewers: Claude adversarial ran (complete; 3 must-fix reported, 1 kept as must-fix, 2 taken as suggestions); Gemini (agy) ran, EXIT=0, 1 suggestion (kept); Codex ran, EXIT=0, 1 must-fix (kept). Static: shellcheck --severity=warning clean on the five changed shell files. Suites under a private TMPDIR: test_project_integration_audit 114/0, test_project_registry 274/0, test_skill_paths 102/0, no files left behind. Open for the owner at the merge checkpoint (Ask First): AGENTS.md commit ce28b0e8 changes the Skill Worktree Exception rule (onboard-project on the allowlist) and the `project_setting.sh` row, beyond the one new row approved in round 1.

### Findings
- [x] (must-fix) At a parent root, category 6 runs `registration_verify.sh` on the parent name only, which skips settings, required commands and adapter validation, so the chosen instance's broken registration is never reported; verify `$SNAME` too, with tests for an instance with malformed settings and a missing command (Codex) — `.agent/scripts/project_integration_audit.sh:502`
- [x] (must-fix) At a parent root, category 3 takes the worktrees directory and the records ignore probes from the parent, which never gets worktrees (they go under the instance; `wt_ensure_exclusion` returns early for a parent): a false `worktrees-not-ignored` warn whose detail ("worktree_create.sh adds 'worktrees/'") is untrue there, and the instance's own directory unchecked; the test fixture hides it (its `.gitignore` already has `worktrees/`). Use the instance for both, and decide which root's files categories 1, 2, 4, 5 read at a parent root, since the fix batch can only change the instance's repository (Claude, reproduced) — `.agent/scripts/project_integration_audit.sh:407-445`
- [x] (suggestion) `commands()` takes the prose before a code span as a command, so `- make sure \`pytest\` passes` with `test=pytest` is flagged (round 1's substring match hid it); take the lead only when the line has no code span (Gemini, reproduced) — `.agent/scripts/project_integration_audit.sh:336`
- [x] (suggestion) `worktree_list.sh` misparses a project skill worktree whose project name holds `-` or `.` (slug is the raw registry name; its regex allows `[a-zA-Z0-9_]`); enter/remove unaffected; the same class already exists for issue worktrees of such names (Claude) — `.agent/scripts/worktree_list.sh:124`
- [x] (suggestion) Step 1 reads a parent root with no instances as "no parent root", so every later write is refused; decide on `session_root.sh`'s `type=` and stop with "register an instance first"; the audit's text says "several instances" for zero too (Claude) — `.claude/skills/onboard-project/SKILL.md:127`, `.agent/scripts/project_integration_audit.sh:537`
- [x] (suggestion) The allowlist is not tied to the type: `--skill research --type project` and `--skill onboard-project --type workspace` now both succeed; allow onboard-project only with `--type project` (Claude) — `.agent/scripts/worktree_create.sh:91,555`
- [x] (suggestion) Step 7's pull-request block has no `git push -u origin <branch>`, so a non-interactive `gh pr create` stops ("you must first push the current branch") (Claude) — `.claude/skills/onboard-project/SKILL.md:367-389`
- [x] (suggestion) `ignored-agent-file` emits one warn per file with no cap and flags Claude Code's own ignored `.claude/worktrees/`; cap or group per rule, treat `.claude/worktrees/` like `settings.local.json` (Claude) — `.agent/scripts/project_integration_audit.sh:461-467`
- [x] (suggestion) Category 2 misses numbered and `+` list items (`1. make install`, `+ cargo build`) in both the grep and the awk lead-stripping (Claude) — `.agent/scripts/project_integration_audit.sh:333,396`
- [x] (suggestion) Plain `"${arr[@]}"` on possibly empty arrays under `set -u` (bash 4.0-4.3 aborts); use the `${arr[@]+...}` form the new code uses (Claude) — `.agent/scripts/project_integration_audit.sh:398,482,488`

## Checkpoint
**Status**: complete
**When**: 2026-10-29 10:30 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the rounds checkpoint fires on the false count from the merged parts' entries (issue 384); this is round 2 of PR 3 of 4, with 2 must-fix and 8 suggestions, all mechanism; second host address in a row at rounds, so the next rounds answer is the owner's)
**After**: rounds
**Decision**: address

PR 3 of 4 (the onboard-project rewrite), round 2 at 377b4e29 (8c7b5e6d): M1 at a parent root category 6 verifies only the parent name, so the chosen instance's broken registration is never reported; M2 at a parent root category 3 probes the parent for worktrees and records ignores, which belong to the instance. Host decision on M2's open design point, listed for the owner's veto: at a parent root the audit reads, reports and fixes one repository, the chosen instance's (categories 1 to 6 alike), because the fix batch can only write there; the parent root's own files are not audited by this skill. Eight suggestions sent along (commands() lead text, worktree_list.sh name parse, zero-instance parent wording, allowlist tied to type, git push before gh pr create, ignored-agent-file cap and .claude/worktrees, numbered list items, empty arrays under set -u). Ask-First item for the owner, raised in the session: the AGENTS.md commit ce28b0e8 also changes the Skill Worktree Exception rule and the project_setting.sh row, beyond the one row approved yesterday.

## Implementation
**Status**: complete
**When**: 2026-10-29 10:52 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent aa8647374c5538f24, resume 1 of 3)

**Branch**: feature/issue-332 at `16d94083`
**Addressed**: Local Review (Pre-Push) at `377b4e29` (2026-10-29 10:30 -04:00)
**Commits**: 3c12d408, 0241da7e, 89ee14aa, 61df2c3e, 4d2c0537, 4dc559ee, 0c7573b7, b180073c, 412282dc, 5c7104f7, 16d94083

All ten fixed; none deferred. No-SKIP pre-commit over `main...HEAD` on `16d94083`: exit 0 in 456 s, the script suite hook passed. AGENTS.md was not touched (the owner is being asked about its earlier changes): its `project_integration_audit.sh` row still says "at a parent root it reads the settings of `--instance I`"; the right wording is "reads the settings and repository of `--instance I` (else the default or only instance), verifies its registration beside the parent's, and does not audit the parent root's own files". The Skill Worktree Exception could also say that each allowlisted skill has one worktree type. Both are left for the AGENTS.md decision.

### Actions
- [x] M1 the instance's registration never verified at a parent root: category 6 runs `registration_verify.sh` on the parent and on the audited instance, each finding's subject naming which; tests for an instance with malformed settings and one with no test command (0241da7e) — `.agent/scripts/project_integration_audit.sh` (verify_registration)
- [x] M2 category 3 read the parent at a parent root (host decision: one repository, the chosen instance's, for categories 1 to 5): the audited root, worktrees directory and records ignore probes are the instance's, and the parent's own files are not read; the session-root check stays on the parent. The fixture no longer lets the parent's `worktrees/` rule hide the instance's missing one, and puts a candidate line in the parent's CLAUDE.md that must not be reported. Skill step 1, 2 and 7 text (3c12d408); design.md onboarding bullet and changelog row (16d94083) — `.agent/scripts/project_integration_audit.sh` (SESSION_ABS / AUD_NAME)
- [x] S1 prose before a code span taken as a command: `commands()` uses the line itself only when it has no code span; test line `- make sure \`make test\` passes.` (89ee14aa) — `.agent/scripts/project_integration_audit.sh` (commands)
- [x] S2 `worktree_list.sh` misparsed a project named with `-` or `.`: the scan passes the registered name, and a skill or issue basename starting with it is split there first; test with `my-proj.x` (5c7104f7) — `.agent/scripts/worktree_list.sh` (extract_issue_repo)
- [x] S3 a parent root with no instances: the skill decides on the registered type (`registry_lookup ... | cut -f1`), because `session_root.sh`'s `type=` says only workspace or project, and stops saying to register an instance; the audit emits `parent-instance` (error with none, info with several and no default) and its text says "none registered" for zero; tests in both suites (0c7573b7) — `.claude/skills/onboard-project/SKILL.md` step 1
- [x] S4 allowlist not tied to the type: `skill_worktree_type` (onboard-project project, the rest workspace) refuses the other combinations; tests for `research --type project` and `onboard-project --type workspace` (412282dc) — `.agent/scripts/worktree_create.sh`
- [x] S5 no push before `gh pr create`: `git push -u origin "$(git branch --show-current)" || exit 1` first, with the reason; skill text test (b180073c) — `.claude/skills/onboard-project/SKILL.md` step 7
- [x] S6 `ignored-agent-file` uncapped and flagging `.claude/worktrees/`: one finding per ignoring rule naming up to three files and the count; `.claude/worktrees/` excluded like `settings.local.json`; test with five files under one rule (4dc559ee) — `.agent/scripts/project_integration_audit.sh` (category 4)
- [x] S7 numbered and `+` list items missed: list marker `-`, `*`, `+`, `1.`, `1)` in both the grep and the awk; test lines 9 to 11 (61df2c3e) — `.agent/scripts/project_integration_audit.sh`
- [x] S8 empty arrays under `set -u`: the instruction-file and rule-file expansions use `${arr[@]+...}`; the two remaining plain ones are guarded by a non-empty check. Not testable on this machine's bash 5 (4d2c0537) — `.agent/scripts/project_integration_audit.sh`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-29 10:57 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a4f6a454516d4c385, resume 1 of 3)
**Verdict**: approved

**Branch**: feature/issue-332 at `df3b8943`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round 3 of PR 3 of 4 (the onboard-project rewrite); `review_progress.sh round` says 14 only because of the merged parts' entries (issue 384). A narrow convergence check per the handoff: scope is the round-2 entry 8c7b5e6d's 10 findings and the fix diff 377b4e29..16d94083 (11 commits); cross-model skipped (round-3 convergence check, per handoff). Verdict computed with `--round 3 --prev-must-fix 2`.

All 10 round-2 findings checked closed. M1: category 6 verifies the parent and the audited instance (`verify_registration`), with tests for an instance with malformed settings and with no test command. M2: at a parent root categories 1 to 5 read only the chosen instance's settings and repository (host decision), the session-root check stays on the parent; the fixture's parent now ignores `worktrees/` while instance a does not, and the parent's CLAUDE.md line must not be reported; design.md bullet and changelog row (16d94083) say so. Suggestions: prose before a code span is no command; `+`, `1.`, `1)` list markers in grep and awk; `${arr[@]+...}` expansions; `ignored-agent-file` one per rule, `.claude/worktrees/` skipped; zero-instance parent stops (skill decides on the registered type; audit `parent-instance` error, text "none registered"); `skill_worktree_type` ties research and inspiration-tracker to workspace and onboard-project to project (no existing caller uses another combination: research's project scope uses `--issue`); `git push -u` before `gh pr create`; `worktree_list.sh` splits at the registered name (test with `my-proj.x`). AGENTS.md deliberately untouched (owner's call on two wording refreshes), not counted.

Checks: shellcheck --severity=warning clean on the six changed shell files; suites under a private TMPDIR: test_project_integration_audit 130/0, test_project_registry 281/0, test_skill_paths 104/0, no files left behind.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 11:01 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: publish
**Decision**: address

Owner's answer: "Yes, refresh both, then publish". Round 3 (ed1bcc04) approved with nothing open. Two AGENTS.md wording refreshes (Ask-First, approved now) go in before publish: the project_integration_audit.sh row says that at a parent root the audit reads the chosen instance's settings and repository, checks the instance's registration as well as the parent's, and skips the parent's own files; the Skill Worktree Exception says each allowlisted skill has one worktree type (research and inspiration-tracker workspace only, onboard-project project only). Then a round-4 convergence check and publish.

## Implementation
**Status**: complete
**When**: 2026-10-29 11:10 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent aa8647374c5538f24, resume 2 of 3)

**Branch**: feature/issue-332 at `4281cc40`
**Addressed**: Checkpoint (owner, 2026-10-29 11:01 -04:00) after the Local Review (Pre-Push) at `ed1bcc04`: the two AGENTS.md wording refreshes it approved ("Yes, refresh both, then publish")
**Commits**: 4281cc40

The round-3 review left nothing open; its LGTM placeholder box is left as it is. No test pins either passage. No-SKIP pre-commit over `main...HEAD` on `4281cc40`: exit 0 in 454 s, the script suite hook passed.

### Actions
- [x] The `project_integration_audit.sh` Script Reference row: at a parent root the audit reads the settings and repository of `--instance I` (else the default or only instance), checks that instance's registration as well as the parent's, and skips the parent's own files; checked against `SNAME`/`AUD_NAME` and `verify_registration` in the script (4281cc40) — `AGENTS.md` Script Reference
- [x] The Skill Worktree Exception: each allowlisted skill has one worktree type, `research` and `inspiration-tracker` workspace only, `onboard-project` project only; checked against `skill_worktree_type` in `worktree_create.sh` (4281cc40) — `AGENTS.md` Skill Worktree Exception

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-29 11:12 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a4f6a454516d4c385, resume 2 of 3)
**Verdict**: approved

**Branch**: feature/issue-332 at `680806ec`
**Base**: main
**Depth**: Deep (reason: round 4 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 4 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round 4 of PR 3 of 4 (the onboard-project rewrite); `review_progress.sh round` says 15 only because of the merged parts' entries (issue 384). A narrow convergence check per the handoff on the one code change since round 3 (ed1bcc04): the owner-approved AGENTS.md commit 4281cc40; cross-model skipped (round-4 convergence check, per handoff). Verdict computed with `--round 4 --prev-must-fix 0`.

`git diff ed1bcc04..HEAD`: only AGENTS.md (2 lines) and progress.md changed. Each claim checked against the code. The audit row: at a parent root the instance's settings and repository are read (`project_integration_audit.sh:196-198`, AUD_NAME/PROOT from the `--instance` or default/only instance), its registration is verified beside the parent's (`:582-584`), and the parent's own files are not read (PROOT replaced by the instance's). The Skill Worktree Exception: `skill_worktree_type` (`worktree_create.sh:96-101`) gives onboard-project `project` and the rest `workspace`, and `:300-301` refuses any other combination.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 11:11 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (round 4 of PR 3 of 4 approved with nothing open; the owner already answered the publish checkpoint once this drive with "refresh both, then publish", and the refreshes are in; the branch is not behind main)
**After**: publish
**Decision**: publish

PR 3 of 4 (the onboard-project rewrite and the project integration audit) at 680806ec, round 4 (b3b8c3c8) approved. Pushed and opened as a pull request by the host.

## Integrated Review
**Status**: complete
**When**: 2026-10-29 11:13 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #413 at `10448742`
**Sources**: 3 (Local Review (Pre-Push) round 4 @ `680806e` (covers 10448742 via bookkeeping: progress.md only); GitHub reviews and comments at the head: none; CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

PR 3 of 4 of issue 332 (the onboard-project rewrite and the project integration audit). `review_progress.sh sources` at the head: one local entry covers it, round 4 (b3b8c3c8, approved at 680806ec), whose only box is its LGTM placeholder; nine older entries with open boxes are stale (parts 1 and 2, PRs 403 and 409, merged, and this part's earlier rounds, all 24 of whose findings were fixed in rounds 1 to 3). GitHub: 0 reviews, 0 inline comments, 0 conversation comments. The copilot-pull-request-reviewer check run failed at the head (`HttpError: Not Found`, exit 1) and posted no review. CI at the head: Validate Adapter Contract, Validate Documentation and ros-manifest tests pass (both workflow runs); Lint (pre-commit) still in progress in both runs; triage did not wait for it.

### Findings
None open.

### False positives
- (Local Review (Pre-Push) @ `680806e`) "No issues found. LGTM." — a placeholder box, not a finding: the round-4 entry's verdict is approved with 0 must-fix and 0 suggestions, so there is nothing to act on.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 11:26 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: merge
**Decision**: merge

Owner's answer: "Merge". PR 413 (part 3 of 4) at 489a94d8, Integrated Review 489a94d8 with nothing open; CI lint still running at the time of the answer, so the host waits for it before merge_pr.sh.

## Implementation
**Status**: complete
**When**: 2026-10-29 14:11 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-332 at `03c7a4e6`
**Commits**: 9c99f086, 274d3423, 562886af, 03c7a4e6

Part 4 of 4 of issue 332 (plan section "PR 4 — `audit-project` takes the hygiene checklist (D4)"), on main at 4bd9ce77. No-SKIP pre-commit over `main...HEAD` on `03c7a4e6`: exit 0 in 618 s, the script suite hook passed (an earlier run on `562886af` failed in `test_user_tier_guard.sh`, which refused every gh call in the read-only audit; fixed in 03c7a4e6).

### Changes
- [x] `project_integration_audit.sh --facts`: `fact<TAB>value<TAB>evidence` (text: `fact: value -- evidence`), value yes/no/unknown, in the order `github` (origin, else first remote, on github.com), `issues` (enabled and at least one ever opened: `gh repo view`, then `gh issue list --state all` when none is open), `prs` (same with `gh pr list`), `windows` (`uname -s` MINGW/MSYS/CYGWIN), `multi_component` (tracked component manifests in two or more directories; node_modules/vendor/third_party left out; a CMakeLists.txt counts only with project()); at a parent root the chosen instance's repository; gh only reads and is never called without a GitHub remote (9c99f086)
- [x] Tests in `test_project_integration_audit.sh` (167 pass): synthetic repositories with a stub gh and stub uname; each value, gh failure, malformed answers, local-path and non-GitHub remotes, non-git root, parent-root instance, gh not called without GitHub (9c99f086)
- [x] `audit-project` SKILL.md rewritten: session_root.sh instead of `project/<repo-name>`; parent root reads, reports and fixes the chosen instance's repository only; step 2 reads `--facts`; the seven checklist items with fix approaches and read-only checks; a facts table of what each fact makes moot, each skipped item reported "skipped: <reason>", unknown makes nothing moot; the stale step 7 replaced by the integration script, report-only; optional step 10 with fix now / open issue / queue in the roadmap / skip, the D6 words, the shared `## Onboarding` section, each queued row a yes, an issue per row when `issues=yes` (274d3423)
- [x] `onboard-project`: checklist section and its GitHub writes removed; step 2 also runs `--facts`, steps 6 and 7 read `issues`/`github` (ask when unknown); new step 10 offers audit-project (D4) (274d3423)
- [x] `test_skill_paths.sh` (120 pass): audit-project pins (no `project/<repo-name>` or `project_knowledge`, facts command and table, seven items, the moot reasons, report-only, four answers, D6, cited onboard headings exist, heredocs quoted, bash blocks parse); onboard pins for the checklist's removal, step 10 and the facts; parse and heredoc checks made shared functions (274d3423)
- [x] `docs/design.md` Sessions and roots bullet for audit-project's job and change-log row (852 lines); `skill_workflows.md` rows; `user_tier_scripts.txt` comment (562886af)
- [x] `test_user_tier_guard.sh`: the read-only audit may call `gh repo view`, `gh issue list`, `gh pr list` and nothing else, a gh subcommand in a variable refused; the audit's list calls written out (03c7a4e6)

### Host decisions, listed for veto
- `issues=yes` means at least one issue ever opened, not just enabled (GitHub enables issues by default, so a project that never used them would read yes); this needs `gh issue list`/`gh pr list` beside `gh repo view`, whose counts are open only.
- The moot table is finer than the plan's line: `issues=no` skips the bridge, `prs=no` skips Copilot, both skip labels; with `prs=no`, branch protection is reported and asked about, not recommended.
- audit-project's fix-now batch follows onboard-project's steps 7 and 8 by heading (pinned by the test) instead of a second copy; for a project with no issues it uses the `onboard-project` skill worktree, since adding audit-project to the allowlist would need an AGENTS.md edit.

### AGENTS.md (Ask-First, not done)
- Script Reference row for `project_integration_audit.sh`: "run by `/onboard-project` at the project's root: `[--dir D \| --project N] [--instance I] [--format tsv\|text]`" becomes "run by `/onboard-project` and `/audit-project` at the project's root: `[--dir D \| --project N] [--instance I] [--facts] [--format tsv\|text]`", and before "exits 0 whatever it finds" add: "`--facts` prints instead `fact<TAB>value<TAB>evidence` for `github`, `issues`, `prs`, `windows`, `multi_component` (yes, no or unknown; from the remote, read-only `gh repo view`/`issue list`/`pr list` and `uname`), which `/audit-project` reads to skip the hygiene items they make moot;"

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-29 14:17 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `c0bcc8a9`
**Base**: main
**Depth**: Deep (reason: part 4 of 4 of #332 is a new diff: 10 files, +865/-139, a user-tier script, its read-only guard and two project skills; the dispatcher said round 16 because parts 1 to 3's pre-push entries, PRs 403, 409 and 413, all merged, are still on this timeline (#384); per the host's correction this is ROUND 1 for part 4, a full Deep review with cross-model reviewers, classified on the whole main...HEAD diff)
**Must-fix**: 2 | **Suggestions**: 7
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix (both mechanical); the first round always re-reviews after fixes (verdict run with --round 1, no --prev-must-fix)

Merge c0bcc8a9 (main at f90d8ffe, PR 411) is clean: its tree equals `git merge-tree` of its parents, and it is not part of the review target. Suites: test_project_integration_audit 167/0, test_user_tier_guard 63/0, test_skill_paths 120/0. shellcheck is clean on the four changed scripts. Cross-model: Gemini ran (1 suggestion), Codex ran (2 must-fix). Claude adversarial ran; it confirmed that `--facts` writes nothing and makes only the three allowed gh calls, that a project with no remote gives github/issues/prs no with evidence and no gh call, that an unknown fact keeps its item checked, and that the fix-batch `--project <settings-name>` resolves to the instance's repository at a parent root. Its AGENTS.md finding is dropped: that row edit is Ask-First and was left for the owner on purpose.

### Findings
- [x] (must-fix) Credential leak: the evidence for a non-GitHub remote prints the URL verbatim, so `https://user:TOKEN@gitlab.com/...` puts the secret into the audit report. Print the host and path only, and add a fixture with a credential-bearing remote that asserts the secret never appears — `.agent/scripts/project_integration_audit.sh:321`
- [x] (must-fix) Wrong host: the gh calls pass bare `owner/repo`, so with `GH_HOST` set they query another server while the evidence says github.com. Pass `github.com/<owner>/<repo>` to `gh repo view`, `gh issue list -R` and `gh pr list -R`, and test it with a conflicting GH_HOST — `.agent/scripts/project_integration_audit.sh:334,335,362`
- [x] (suggestion) `jq -er 'length'` also accepts an object or a string, so an exit-0 non-array answer reads as "yes". Require `type == "array"` (Gemini) — `.agent/scripts/project_integration_audit.sh:337`
- [x] (suggestion) The gh guard is weaker than its comment says. It exempts a whole line that holds one allowed call, and it misses a flag placed before the subcommand (`gh -R o/r issue close`) and `command gh` / `$GH`. Match every gh token not followed by exactly one of the three allowed subcommands — `.agent/scripts/tests/test_user_tier_guard.sh:289-294`
- [x] (suggestion) A GitHub SSH host alias (`git@github.com-work:o/r.git`), or a GitHub remote that is not the first one checked, gives `github=no`, and four hygiene items are then skipped as "no GitHub remote". Consider `unknown` when the host only looks like GitHub — `.agent/scripts/project_integration_audit.sh:304-321`
- [x] (suggestion) Test gaps in `--facts`: gh missing, jq missing, a repository with no commits, a remote not named origin, `ever_opened` failing after a successful `repo view`, and a root nested inside a larger repository — `.agent/scripts/tests/test_project_integration_audit.sh`
- [x] (suggestion) The skill blurs which facts go `unknown` for which cause: gh problems make only issues and prs unknown, and `github` is unknown only when the repository cannot be read. Say which facts — `.claude/skills/audit-project/SKILL.md:152`
- [x] (suggestion) The `windows=yes` row is a partial skip ("shell-script hooks in the pre-commit item"). Say how it is reported, since the pre-commit item keeps its in place / missing status — `.claude/skills/audit-project/SKILL.md:237`
- [x] (suggestion) Step 10 follows onboard-project step 7 "as written" but overrides only the title. Step 7's pull request body still reads "Onboarding with the workspace", so give the audit's body wording too — `.claude/skills/audit-project/SKILL.md:401-410`

## Checkpoint
**Status**: complete
**When**: 2026-10-29 14:20 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Owner's answer: "Address". Part 4 of 4, round 1 (15207a51, taken as round 1; the counter says 16 from parts 1 to 3, issue 384): 2 must-fix (a non-GitHub remote URL printed verbatim could leak a credential; gh calls pass bare owner/repo and would hit a configured GH_HOST) and 7 suggestions. The owner was asked only because the host had answered the rounds checkpoint twice in a row on this issue; logged as a loop defect for issue 398. The approved AGENTS.md row edit for project_integration_audit.sh (--facts) goes into this fix pass.

## Implementation
**Status**: complete
**When**: 2026-10-29 15:01 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-332 at `0526dd91`
**Addressed**: Local Review (Pre-Push) at `c0bcc8a9` (2026-10-29 14:17 -04:00); also the owner-approved AGENTS.md Script Reference row ("Yes, edit the row", 2026-10-29)
**Commits**: f7772a19, 5ce71257, 840e6941, 055d4417, f6525b48, 3dc8ede7, 0a7073e8, 27c73d6b, 2692f682, 3135e88d, 0526dd91

### Actions
- [x] (must-fix) Credential leak: the user part of a remote URL is stripped and the evidence names host/path only; a fixture with three credential-bearing remotes asserts the secret never appears, tsv or text (f7772a19) — `.agent/scripts/project_integration_audit.sh:321`
- [x] (must-fix) Wrong host: gh repo view, gh issue list -R and gh pr list -R get `github.com/<owner>/<repo>`; the stub gh answers a host-less repository from GH_HOST and a test with a conflicting GH_HOST checks every call; the skill's own gh calls name the host too (5ce71257) — `.agent/scripts/project_integration_audit.sh:334,335,362`
- [x] (suggestion) The list count requires `type == "array"`; an object, a string and a number each give unknown (840e6941) — `.agent/scripts/project_integration_audit.sh:337`
- [x] (suggestion) gh guard: `gh_calls_not_read_only` checks every gh word in command position on its own, refuses a flag before the subcommand, `command gh` and a gh named by a variable; a 15-line fixture tests the matcher (gawk and mawk) (055d4417) — `.agent/scripts/tests/test_user_tier_guard.sh:289-294`
- [x] (suggestion) github is unknown when the checked remote's host only looks like GitHub (ssh alias, GitHub Enterprise) or another remote is on GitHub; issues and prs follow; ssh.github.com counts as github.com; tested (f6525b48) — `.agent/scripts/project_integration_audit.sh:304-321`
- [x] (suggestion) --facts tests for gh missing, jq missing, list calls failing after repo view, no commits, a remote named upstream, a root nested in a larger repository (3dc8ede7) — `.agent/scripts/tests/test_project_integration_audit.sh`
- [x] (suggestion) The skill says which facts go unknown for which cause (0a7073e8; its test_skill_paths check updated in 0526dd91) — `.claude/skills/audit-project/SKILL.md:152`
- [x] (suggestion) windows=yes skips the git-bug bridge only; the pre-commit item keeps in place / missing with "(windows=yes: language-native hooks only)" (27c73d6b) — `.claude/skills/audit-project/SKILL.md:237`
- [x] (suggestion) Step 10 gives the audit's pull request body ("Fixes from the project audit:"), the issue body line it replaces, and the -R github.com/... the create calls take (2692f682) — `.claude/skills/audit-project/SKILL.md:401-410`
- [x] AGENTS.md Script Reference row for project_integration_audit.sh: run by /onboard-project and /audit-project, `[--facts]` in the usage, what --facts prints (3135e88d) — `AGENTS.md`

### Checks
- Full pass `pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: first run failed test_skill_paths (the old "unknown" sentence, fixed in 0526dd91); rerun on the final tree passed every hook, 693 s; the script-test hook ran all 40 suites (`.agent/knowledge/skill_workflows.md` on the branch maps to no suite).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-29 15:07 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af1efbe1213e3292e, resume 1 of 3)
**Verdict**: changes-requested

**Branch**: feature/issue-332 at `485e4628`
**Base**: main
**Depth**: Deep (reason: round 2 of part 4 of 4 of #332, classified on the whole main...HEAD diff as in round 1; a full re-review of the 11 fix commits since c0bcc8a9 with the cross-model reviewers, because round 1 had 2 must-fix. The counter reads 17 from parts 1 to 3 (#384); for this part it is round 2)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 2 | **Ship**: recommended — round 2: 2 mechanical must-fix (prev 2), not rising; fix and ship rather than another full round (verdict run with --round 2 --prev-must-fix 2 --mechanical)

Round-1 findings checked against the fixes. All nine are addressed:
- The credential test covers tsv and text.
- Every gh call names github.com/<owner>/<repo>, in the script (via $GH_FULL) and in the audit-project skill. The GH_HOST stub would fail a call that drops the host.
- The guard matcher gives identical results under gawk and mawk. It refuses fixture lines 1-9 and raises no false positives on the real scripts.
- For an alias host or a GitHub remote other than the one checked, github is unknown, and issues and prs follow with no gh call.
- All six --facts test gaps are covered.
- The AGENTS.md row matches the argument parser, the outputs and the exit codes.

Suites run under a private TMPDIR: test_project_integration_audit 191/0, test_user_tier_guard 64/0, test_skill_paths 121/0. shellcheck is clean. The branch is not behind main.

Reviewers:
- Gemini ran: 3 suggestions.
- Codex ran: 2 must-fix. One is kept as must-fix (branch protection); the other is reclassified as a suggestion: the unconditional `git push -u origin` sits in merged onboard-project step 7 and fails loudly.
- Claude adversarial ran: 2 must-fix, merged into one below, plus suggestions folded in.

### Findings
- [x] (must-fix) Credential redaction is still incomplete:
  - A query or fragment on the URL is kept. `https://github.com/o/r?token=abc` becomes github=yes with GH_REPO `o/r?token=abc`, which goes into the evidence and every `gh -R` call (reproduced).
  - A `file://user:tok@...` remote is classified local, and its raw URL is printed (reproduced).
  - The scp form `user:tok@host:path` is not redacted.
  - The comment's claim that the URL is never printed is false.
  - Fix: strip `[?#].*` and the user part in every form, require `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$` for owner/repo, and add fixtures for ssh://, file://, a query string and a credential on a GitHub remote — `.agent/scripts/project_integration_audit.sh:343-366`
- [x] (must-fix) The classic protection endpoint returns 404 "Branch not protected" when no protection exists, but the skill treats every failed call as `not checked`. A project with no rulesets and no classic protection is therefore never reported missing. Fix: check `.permissions.admin` first. With admin, a 404 means missing; without admin, the item is not checked. A pull-request rule found in the rulesets stands whatever the classic call returns (Codex) — `.claude/skills/audit-project/SKILL.md:272-276`
- [x] (suggestion) A github.com remote whose path is not owner/repo (e.g. `https://github.com/owner`) falls into the "host looks like GitHub but is not github.com" reason. The value unknown is safe, but the reason is wrong (Gemini) — `.agent/scripts/project_integration_audit.sh:369`
- [x] (suggestion) Step 10 says what to do with `github=no` but not with `github=unknown` (alias host, GitHub on another remote). Say to ask which repository and which remote before any issue, push or pull request (Gemini) — `.claude/skills/audit-project/SKILL.md:445`
- [x] (suggestion) onboard-project steps 7 and 8, which audit-project step 10 follows, still push to `origin` unconditionally and pass a bare `-R <owner>/<repo>` to `gh pr create` and `gh issue create`. A repository whose GitHub remote is `upstream` gets an issue and commits, and the push then fails. Its own create calls go to `$GH_HOST`. Carry the remote and host from the facts (Codex, plus lead) — `.claude/skills/onboard-project/SKILL.md:406,438`

## Checkpoint
**Status**: complete
**When**: 2026-10-30 10:14 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the rounds checkpoint fires on the false count from the merged parts' entries (issue 384): round 17 counts the pre-push reviews of PRs 1 to 3 of 4, all merged; this branch is PR 4 of 4 and the review at 485e4628 is its round 2; two must-fix (credential redaction still incomplete; the classic branch-protection endpoint's 404 read as "not protected") and three suggestions open, all mechanism; first host address in a row at rounds since the owner's answer of 2026-10-29 14:20, so one more host answer is allowed before the next rounds answer is the owner's)
**After**: rounds
**Decision**: address

Host-answered within the orchestrator's checkpoint table: all five open boxes are mechanism findings (credential redaction, an HTTP 404 misread, a remote-path edge case, the github=unknown branch of step 10, and a stale push in the onboarding steps), none touches a goal. The owner invoked /run-issue 332 at the start of this drive (2026-10-30) after the three merged parts; this answer is listed in the hand-back for his veto.
