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
- [ ] (suggestion) `unused_settings` fails open when present but unusable: unreadable (mode 000) gives `check` OK and the adapter runs; a CRLF `test\r` line never matches; treat a present-but-unreadable file as an error and strip `\r`, with tests (Claude adversarial, confirmed by execution) — `.agent/scripts/_project_registry.sh:855`
- [ ] (suggestion) Nothing validates `unused_settings`: a misspelt key is inert and a line with no reason prints an empty reason; have `validate_adapter.sh` check each line names a known key and has a reason, with a test (Claude adversarial, confirmed by execution) — `.agent/scripts/validate_adapter.sh`
- [ ] (suggestion) The AGENTS.md Script Reference row for `project_setting.sh` omits that `set` refuses, and `check` fails, a key the project's type never reads (`unused_settings`), which the design, example file and header all state (Claude adversarial) — `AGENTS.md:408`
- [ ] (suggestion) Legacy compatibility: the adapters now clear `BUILD_CMD`/`TEST_CMD`/`INSTALL_CMD` before sourcing the legacy or shared config, so a value inherited from the environment (or a config using `${BUILD_CMD:-make}`) is no longer honoured as on main; no local config relies on it (checked), so name the change in the PR body or keep the inherited value (codex rated must-fix) — `.agent/project_types/single_project/adapter.sh:44`, `.agent/project_types/ros2_colcon/adapter.sh:645`
