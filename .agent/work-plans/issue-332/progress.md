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
