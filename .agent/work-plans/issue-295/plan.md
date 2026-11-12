# Plan: Treat the workspace as a registered project (pinned registry entry + workspace adapter) instead of a --type special case

## Issue

https://github.com/rolker/agent_workspace/issues/295 (done together with the fourth pull request of issue 265, "retire hosting", by the owner's 2026-11-12 direction).

This plan covers three pull requests. Pull request 1 is planned in full (it can be built from this text alone); pull requests 2 and 3 are an outline with the questions they leave open. Pull request 1 is "Part of #295" and "Closes #265" (it is #265's part 4, item 4 of its "PR sequence"); #295 stays open for 2 and 3.

## Context

Fresh clone on a second machine: `make validate` hard-fails because `project/` is absent, and `make setup` prompts for a repository. The cause is that the legacy single-repo shape (`project/` symlink, `projects/<name>` default hosting dir, shared `.agent/project_config.sh`, `.agent/projects.d/<name>.sh`, `worktrees/project/<name>/`) is still read as a fallback beside the registry. The owner's directions: no symlink to the main project and the two ROS clones can go, "so no migration necessary" (2026-11-12); the second-machine move is to "help us make sure we keep up with the loose ends"; #265 part 4 removes the special cases "at the same time as the `project/` / `projects/` fallbacks" (2026-09-18).

Verified against `main` at 3486edba (this branch is 6552b707, nothing in `.agent/scripts` differs). Corrections to the Issue Review: README.md and `.agent/AGENT_ONBOARDING.md` contain no `project/` or `project_config` text (grep), so they need no edit; CLAUDE.md has no such line either; `AGENTS.md` is 199 lines.

## Approach

### Pull request 1: a workspace with no project works, and the legacy fallbacks are gone

Rule for every site: what is read from the registry stays; what was a silent fallback becomes a refusal whose text names `.agent/scripts/register_project.sh <path>`. Commit order is one logical change each (atomic), tests in the same commit as the code.

1. **`validate_workspace.py` and `lib/workspace.py`** — drop the `project/` exists / git / remote-origin checks (lines 159-198) and the `get_project_path`, `is_project_configured`, `get_project_remote_url` helpers (nothing else imports them; `single_project/sync.py` does, see step 4). No registry entries is valid: print "no project registered (register one with .agent/scripts/register_project.sh <path>)" in verbose mode only. A registry line with no path no longer defaults to `projects/<name>` (lib/workspace.py:174, `_project_registry.sh:225`): it is a parse error saying the path is required. The registry-entry, venv-shebang and pre-commit checks stay. Update the module docstring. Test: new `test_validate_workspace_no_project.sh`: sandbox with no `project/`, no registry, exit 0; with a registry line missing its path, exit 1 and the message names `register_project.sh`.
2. **`make setup`** — Makefile: `setup` depends on `setup-dev.done` and `git-bug.done` only; delete the `project.done` rule (192-198), the stamp from the header comment, the `/project/worktrees/` and `.workspace-worktrees/` MAIN_ROOT cases (lines 22-27: worktrees live at `worktrees/workspace/<name>`, where `MAIN_ROOT := $(CURDIR)` already applies and `WS_ROOT` comes from git's common dir), and rewrite `help` (lines 67-84: build/test commands come from the project's settings file; `PROJECT=<name>` selects a registered project; no "legacy project/ symlink"). After "Setup complete." print: `No project is registered. Register one: .agent/scripts/register_project.sh <path>. Optional: enable the workspace in project sessions: .agent/scripts/user_tier_install.sh`. No prompt (host decision D, 2026-11-12: yes, a pointer). Delete `setup_project.sh` and its row in `script_reference.md` (nothing else calls it; verified by grep). Test: step 9.
3. **`single_project` type** — `setup.sh` and `sync.py` lose the default-to-`project/` shape: `--project-root` is required (refuse naming `register_project.sh` when absent); `adapter_setup`/`adapter_sync` in `adapter.sh` stop branching on `ACTIVE_PROJECT_NAME`; `adapter_project_root` loses its `$WORKSPACE_ROOT/project` default; `adapter_repos` loses the "project/ is not configured (run: make setup)" message. `sync.py` drops the legacy helpers it imports (`get_project_path`, `is_project_configured` become a local `is_git_checkout`). Tests: `test_adapter.sh` (53 legacy lines): the `repos fails when project/ is not configured`, `setup removes a broken symlink at project/`, `setup does NOT delete a non-empty project/` cases are rewritten to `--project-root` fixtures or deleted where the behaviour no longer exists; one case asserts `setup` with no `--project-root` refuses naming `register_project.sh`.
4. **`adapter` dispatcher** — delete `_resolve_project_type` and the `PROJECT_TYPE` read (lines 76-96), delete discovery step 3 and the `projects/` special error (lines 211-225), the `ACTIVE_PROJECT_ROOT="$WORKSPACE_ROOT/project"` default, and the header text (lines 14-20, 40-46). When no project resolves (no `--project`, cwd inside no registered root): exit 1 with "no registered project here (cwd <dir>). Registered: <names>. Pass --project <name> or register one: .agent/scripts/register_project.sh <path>". Keep the `--project` unknown-name text, replacing "see .agent/projects.local.example" with the registration script. Tests: `test_adapter.sh` (`PROJECT_TYPE from project_config.sh selects the type dir` cases go; add "no project resolves: refusal names register_project.sh and lists registered names", "cwd under the workspace root but not in a registered root: refusal").
5. **`.sh` and shared-config reading go (item 4 of #265's plan)** — a registered project's build, test, install and bootstrap URL come only from its settings file `.agent/projects.d/<name>` (written by `register_project.sh --set` and `project_setting.sh set`; keys `build test install bootstrap_url`, `ACTIVE_PROJECT_BUILD/_TEST/_INSTALL/_BOOTSTRAP_URL`); `none` records "no such step". Delete: `ACTIVE_PROJECT_CONFIG`, `active_project_fallback_note` and the shared-file branches in `single_project/adapter.sh` (`_single_project_resolve_cmd`, `_single_project_load_cmd`'s "No project_config.sh found" text) and `ros2_colcon/adapter.sh` (`_rc_config_file`, `_rc_config_var`, install, bootstrap URL, distro); `project_command_source` in `_project_registry.sh` returns only `file` or `missing`; `_PROJECT_CONFIG_READ_VARS`, `_project_config_value`, `project_config_extra_vars` and `_project_command_var` go if nothing else uses them (grep first). `registration_verify.sh` loses its `legacy` and `shared` arms (lines 153-155). `register_project.sh` loses the copy of values out of `<name>.sh` (lines 702-747), `EXTRA_WARN` (812-826), the header text (62-65, 105-107) and the line-526 note, which becomes the stale-file report (step 7). `dashboard.sh` and `bootstrap.sh` line 110 stop mentioning `project_config.sh`. Missing command: the existing error "project 'X' has no build command; set it with project_setting.sh set X build=<command>" stays; the "legacy config" sentence goes. ROS settings that lived in the `.sh`: `ROS_DISTRO` stays in the registry `distro=` field or the manifest `distro:` (the error text drops the `.sh` option); `ROS_ROOT_DIR` has no settings-file key, so `_rc_ros_root` reads it from the process environment (default `/opt/ros`), documented in the adapter header and `projects.local.example`; the tests that wrote it into a config file export it instead. Tests: `test_adapter.sh`, `test_ros2_colcon.sh` (17), `test_project_file.sh` (the legacy-precedence cases around lines 1300-1370 become "a `<name>.sh` beside the settings file is not read"), `test_project_registry.sh` (`project_command_source`), `test_register_project.sh` (12), `test_package_issue_loop.sh` (fixture writes `demo.sh`; change to the environment variable).
6. **Worktree location** — `registry_worktree_dir` returns 1 with "project '<name>' is not registered; register it: .agent/scripts/register_project.sh <path>" for an unregistered name (no `<root>/worktrees/project/<name>`); `_worktree_helpers.sh` deletes `wt_legacy_worktree_dirs`, `wt_legacy_workspace_base`, `wt_legacy_project_base`, `wt_project_base_glob`, `wt_transition_project_base`, and the `project/` step of `wt_resolve_project_repo_root` (the registry-only part, including "exactly one registered project is used", stays); its "no project configured" error (line 183) names `register_project.sh`. Callers: `worktree_create.sh` (the `project/` branch 475, the "project/ is not configured" error 491, the legacy `WORKTREE_DIR` branch 689-696, usage text 178-179), `worktree_enter.sh` (192, 216, 237-241, 293, 346), `worktree_remove.sh` (170, 192, 211-215), `worktree_list.sh` (254, 359, 370, 425), `dispatch_phase.sh` (234-257), `sitrep_root.sh` (363), `dashboard.sh` (counts at 397), `merge_pr.sh` 483. `.workspace-worktrees/` and `project/worktrees/` go with the helpers. On this machine none of `worktrees/project/`, `.workspace-worktrees/` or `project/worktrees/` exist (checked), so there is nothing to migrate. Tests: `test_worktree_create.sh` (11), `test_dispatch_phase.sh` (the "falls back to the deprecated project/worktrees/ shape" case becomes "refuses naming register_project.sh"), `test_project_registry.sh` (40), `test_sitrep_root.sh`, `test_session_start_layer.sh`.
7. **`merge_pr.sh`** — `wt_resolve_project_repo_root` without a name: single registered non-parent project, else refuse. `PJ_ROOT_EFFECTIVE` is deleted; its three uses (lines 577, 694, 721/858 mains list, with `$ROOT_DIR/project`) use `PJ_REPO_ROOT`, which is set whenever `WORKTREE_TYPE=project` (the existing fail-fast block already exits otherwise); the `$ROOT_DIR/project` entry in the main-tree guard list goes. Header text (47, 245, 285, 361, 467, 1730) updated. Tests: `test_merge_pr.sh` (31) and `test_merge_pr_gate.sh` (14): fixtures that make a `project/` checkout move to a registered sandbox project; add "`--type project` with nothing registered exits 1 and names `register_project.sh`" and "workspace PR merges with no project registered".
8. **Remaining single sites** — `gh_create_pr.sh` repo-safety check (lines 144-150): the accepted slugs become the workspace remote plus the `origin` slug of every registered non-parent root (a loop over `registry_entries`); message line "Project repo:" lists those. `discover_governance.sh` (127-133): scan each registered root with scope `project` instead of `$ROOT_DIR/project`. `configure_git_identity.sh` (56, 135-158): configure the workspace repo and each registered root's repositories (via `registry_entries`), not `find project`. `session_root.sh` (header 41-45, 191-196, 201): drop the legacy branch; "names no project here" says "no registered project and `<n>` registered; pass --project <name> or register one". `dashboard.sh` (144-163, 343): no `PROJECT_DIR` block; "no projects registered: .agent/scripts/register_project.sh <path>". Tests: `test_discover_governance.sh` (13, fixtures `project/` -> registered root), `test_session_root.sh` (12), a `gh_create_pr` repo-safety test (find the existing one with `grep -l "Repo-safety\|scratchpad clone" tests/`; add the registered-root slug accepted and an unrelated slug refused), `test_dashboard`-type suite if one exists (grep), `test_precommit_hook_path.sh` (the `project/.git/hooks` fixture is a project hook check: keep the intent, rename the fixture to a registered root).
9. **Stale-file report** — a machine with `.agent/projects.d/<name>.sh` or `.agent/project_config.sh` is told, never silently ignored: `validate_workspace.py` prints a warning line per file ("`.agent/projects.d/p.sh` is no longer read; move its settings with project_setting.sh set, then delete it"), `dashboard.sh` prints the same as `check_warn` (replacing the orphan-file loop's `.sh` stripping at lines 207-217), `adapter` prints one stderr NOTE when the active project has a `<name>.sh`, and `register_project.sh` replaces the line-526 note with the same text. It warns rather than fails: failing `make validate` for a stray file would repeat the loose end this pull request removes; the command-missing error already stops a verb that needed the value. The registry name rule "a name may not end in `.sh`" stays (a file `x.sh` would be this report's stale file). Test in `test_validate_workspace_no_project.sh` and `test_project_file.sh`.
10. **Fresh-clone acceptance test** — new `.agent/scripts/tests/test_fresh_clone_no_project.sh` (chmod +x; no project name in it, a synthetic `demo` project if one is needed): scratch `HOME`, `git clone` of the worktree into a scratch directory, `CI=1` so git-bug setup is skipped (`git_bug_setup.sh` step 1 skips when `CI` is set); assert (a) `python3 .agent/scripts/validate_workspace.py` exits 0 with no `project/`, no registry; (b) `make setup` exits 0 with no stdin (`</dev/null`), prints the two pointers, and writes no `project/` or `projects/`; (c) `make validate` exits 0 (this also runs `user_tier_install.sh --check`; if `--check` fails when the tier is absent, that is a defect in this pull request's scope, not a skip); (d) `make build` and `adapter build` refuse naming `register_project.sh`; (e) after `register_project.sh <demo path> --set build=true --set test=true --skip-run` in the clone, `adapter --project demo build` runs. `make setup` creates the venv with network; if the sandbox cannot reach pip, the test uses a stamp pre-seeded `.make/setup-dev.done` and says so in its output (reported as skipped part, not passed). The suite is auto-discovered by `run_script_tests.sh`; check `test_script_tests_hook_scope.sh` drift checks pass, add a `# covers:` header if it asks. Any parallel use of the runner names its job count.
11. **Documentation (same change, ADR-0017)** — `docs/design.md`: Sessions and roots Target "Discovery becomes registry-only" (277-291) moves to Now; Registry and adapters (355 "then the legacy `project/` checkout", 336-339 the legacy `.sh` layer, 364-405 inventory rows for `adapter` step 3, `gh_create_pr`, `merge_pr` `PJ_ROOT_EFFECTIVE`, the `setup` row's `project` stamp, 415, 431, 464-465) updated to the registry-only text; Table 1/2 inventory stays (it is evidence for pull request 2/3) with the rows this change removes struck out; Change log row; line counts. `.agent/WORKTREE_GUIDE.md`: 27, 87-90, 101-111, 135, 143, 216-217, 300, 382-383 (transition fallback, legacy `project/` shape, "Found worktree in legacy location"). `.agent/projects.local.example`: delete the `.sh` layer paragraphs (99-118) and discovery step 3 (132); path is required; add `ROS_ROOT_DIR` environment note. `.agent/knowledge/build_and_test.md`, `knowledge/README.md` (5, 15), `script_reference.md` (28-30, 39), `.agent/templates/project_agents_guide.md` (42), `.agent/AGENT_ONBOARDING.md` and `README.md` (no legacy text; no edit), `.gitignore`: remove `project/`, `project`, `projects/` and `.agent/project_config.sh` (the last: keep nothing ignoring a file nothing reads; the stale-file report covers a leftover). Skills: `gather-project-knowledge` line 48 (scan registered roots), `start-task` line 134, `onboard-project` line 367, `test-engineering` 180-192 (`cd project/<component>` becomes "cd <project root>/<component>"). `docs/roadmap.md`: delete the deferral row for 265 part 4 (line 86), reword line 48, and reword line 89 so #295 reads "the workspace as a registered project (#295), planned after part 4 of #265".
12. **Instruction files, own commit last** — `AGENTS.md` only (CLAUDE.md has nothing to change). Exact wording below. Ask First: not committed until the owner approves; the commit is separate so it can be dropped without touching the rest.

### Proposed AGENTS.md wording (for the owner to approve)

Terminology, first bullet and the repo-ownership paragraph and table row. Current text on the left of each "becomes".

> - **Project**: a product registered with the workspace (`register_project.sh`),
>   kept in its own checkout wherever it lives — what's actually being built.
>   Product features, deployment, and user-facing behavior are project scope.

> **Repo ownership**: A workspace session works in the workspace checkout; a
> project session works in the project's own checkout. Don't assume which
> GitHub repo you're in — use `gh repo view` or `git remote -v` to confirm.
> Issues and PRs must target the repo that owns the code being changed:

> | Project | project repo (e.g. `my_project`) | The product being built (its registered checkout) |

Build & Test, replacing the `.agent/project_config.sh` sentence:

> Set a registered project's build and test commands in its settings file
> (`project_setting.sh set <name> build=<cmd> test=<cmd>`); then `make build PROJECT=<name>`,
> `make test PROJECT=<name>`, `make lint` (pre-commit on all files) and `make validate`
> (workspace config). See [`.agent/knowledge/build_and_test.md`](.agent/knowledge/build_and_test.md).

Net line count: bullet +1, paragraph -1, Build & Test 0, so 199 stays 199 (budget 200; the commit runs the `agents-md-line-budget` hook, which decides). CLAUDE.md: unchanged (its `--type workspace|project` lines stay true until pull request 3). The Terminology bullet "Workspace" and the "When scope is ambiguous" paragraph are unchanged.

### Pull request 2 (outline): the pinned workspace entry and the `workspace` adapter type

`.agent/project_types/workspace/` (`adapter.sh` with the 12 verbs per design Table 2, `registration.conf`, `unused_settings`), a pinned entry `registry_entries_full` returns first that `register_project.sh` refuses to add or remove, `validate_workspace.py` not recursing through the workspace `validate` verb, `validate_adapter.sh` passing, no branch site changed. Open before it is planned: owner question C (what the pinned entry means for the session-root rule in `session_root.sh` and for the user tier, which enables the plugin per registered root, ADR-0018 and #446, so the workspace root must not be enabled twice); whether the pinned entry shows in `dashboard.sh`/listings; whether ADR-0011 gets a superseding note (ADR-0008 says a change to its resolution is substantive). Sequencing: after #446's second pull request (shared: `user_tier_install.sh`, `register_project.sh`, `skill_prefix.sh`).

### Pull request 3 (outline): collapse the special cases

Replace each `--type workspace` branch site in design Table 1 with the registry lookup, one script per commit, with tests; recount the sites by reading the code at that time (the review's grep counts are loose). Sequencing: after #429 part 2 (`worktree_create.sh`, `merge_pr.sh`, `dispatch_phase.sh`), never in parallel with it.

**Decision on `--type` (for the owner's veto; his 2026-09-18 comment delegated it to the plan): it survives as a deprecated alias for one release, then goes.** Reason: eight skills, `dispatch_phase.sh` (four modes) and every dispatched phase pass `--type`; retiring it in the same change that moves the branch sites would break running loops, while an alias costs one line per script (accept the value, warn on stderr "`--type` is derived from the registry; drop it", and refuse a value that contradicts the derived type, as `merge_pr.sh` already does for `--repo`). `registry_derive_type_from_dir` already derives it from the cwd. The removal is a later small pull request that edits the skill texts, listed on the roadmap as a deferral with a `gh-issue` revisit check. Not decided here for pull request 1: it touches no `--type` handling except removing the `project/` default behind `--type project`.

## Files to Change (pull request 1)

About 55 files, rough size +1,000 / -1,700 lines (tests are most of both columns).

| Group | Files |
|---|---|
| Validate and setup | `.agent/scripts/validate_workspace.py`, `.agent/scripts/lib/workspace.py`, `Makefile`, `.agent/scripts/setup_project.sh` (deleted), `.agent/scripts/bootstrap.sh` |
| Types and dispatcher | `.agent/scripts/adapter`, `.agent/project_types/single_project/{adapter.sh,setup.sh,sync.py,registration.conf}`, `.agent/project_types/ros2_colcon/adapter.sh` |
| Registry and worktrees | `.agent/scripts/_project_registry.sh`, `_worktree_helpers.sh`, `worktree_create.sh`, `worktree_enter.sh`, `worktree_remove.sh`, `worktree_list.sh`, `dispatch_phase.sh`, `sitrep_root.sh`, `session_root.sh`, `dashboard.sh`, `merge_pr.sh`, `gh_create_pr.sh`, `discover_governance.sh`, `configure_git_identity.sh`, `register_project.sh`, `registration_verify.sh`, `project_setting.sh` (header only if it mentions the legacy layer) |
| Tests changed | `test_adapter.sh`, `test_ros2_colcon.sh`, `test_project_file.sh`, `test_project_registry.sh`, `test_register_project.sh`, `test_package_issue_loop.sh`, `test_worktree_create.sh`, `test_dispatch_phase.sh`, `test_merge_pr.sh`, `test_merge_pr_gate.sh`, `test_discover_governance.sh`, `test_session_root.sh`, `test_sitrep_root.sh`, `test_session_start_layer.sh`, `test_precommit_hook_path.sh`, `test_skill_prefix.sh` (comment names a real project: reword), `test_project_integration_audit.sh` |
| Tests new | `test_fresh_clone_no_project.sh`, `test_validate_workspace_no_project.sh` (both `chmod +x`) |
| Docs | `docs/design.md`, `docs/roadmap.md`, `.agent/WORKTREE_GUIDE.md`, `.agent/projects.local.example`, `.agent/knowledge/{build_and_test,README,script_reference}.md`, `.agent/templates/project_agents_guide.md`, `.gitignore`, four skill texts |
| Last commit, Ask First | `AGENTS.md` |

## Machine steps (not code; the host runs them on the owner's first machine)

88 repositories under the two ROS clones were checked clean and in sync on 2026-11-12.

1. `.agent/scripts/register_project.sh --remove p11-jazzy` and `--remove p11-rolling` (refuses with live worktrees; none under `worktrees/project/`).
2. `rm -r projects/` (the clones) and `rm project` (the symlink to the main project; the owner said it is not needed).
3. `rm .agent/projects.d/p11-jazzy.sh .agent/projects.d/p11-rolling.sh`; the main project's file `.agent/projects.d/<main>` is the settings file and stays. `.agent/project_config.sh`, if present, is deleted too.
4. Order: after pull request 1 merges (the stale-file report then shows nothing), `make validate` and `make dashboard` as the check.

## Overlap with other branches (`git diff --stat main...<branch>`, read-only)

| Branch | Files it changes that this pull request also changes | Consequence |
|---|---|---|
| `feature/issue-437` (pull request 448) | `.agent/scripts/tests/test_package_issue_loop.sh` (12 lines), `.agent/knowledge/script_reference.md` (6), `docs/design.md` (21) | This branch merges main after 448; conflicts are line-level (the `demo.sh` fixture, one table row, design change log). |
| `feature/issue-429` | work-plan files only so far; its part 2 will touch `worktree_create.sh`, `merge_pr.sh`, `dispatch_phase.sh` (per plan) | Part 2 rebases onto this; those three scripts change here (steps 6, 7). |
| `feature/issue-446` | work-plan files only so far; its second pull request touches `user_tier_install.sh`, `register_project.sh`, `skill_prefix.sh` | `register_project.sh` changes here (step 5, 9); `user_tier_install.sh` and `skill_prefix.sh` do not (only its test comment). |
| `feature/issue-444` | `run_script_tests.sh`, `test_run_script_tests.sh`, `test_script_tests_hook_scope.sh`, `.pre-commit-config.yaml`, `script_reference.md` (2) | No shared file but `script_reference.md`; the new suites are auto-discovered, so no runner edit here. |
| `feature/issue-394` | `user_tier_install.sh` and its test, `.gitignore` (3 lines), `docs/design.md` (7) | `.gitignore` and `docs/design.md` overlap; `user_tier_install.sh` is not edited here, only run by `make validate`. |

## Prior Art

Nothing new is built; this removes code. The replacement shapes are the registry lookups already used by `worktree_create.sh` (the "single registered project" rule) and the refusal text of `adapter --project`. The settings file and `register_project.sh --set` (issue 332) already carry what the `.sh` carried, except `ROS_ROOT_DIR` (step 5). The fresh-clone test follows the sandbox-clone pattern of the existing `test_*.sh` suites.

## Serves

Workspace goal "The workspace is project-agnostic and usable on any project" (README, Workspace goals) and machine independence of a fresh clone; `docs/design.md#sessions-and-roots` (registry-only discovery, Target to Now) and `docs/design.md#registry-and-adapters`.

## Design Picture

Changes it: `docs/design.md#sessions-and-roots` (discovery registry-only becomes current) and `docs/design.md#registry-and-adapters` (resolution without the legacy step, settings from the file only, inventory rows struck), in pull request 1 (step 11). Pull requests 2 and 3 change the same two sections again.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Fresh-clone loose ends (validate, setup, help, docs, `.gitignore`, a test of the no-project state) are in this pull request; each removed fallback has a test of the new refusal; machine steps listed. |
| Keep one current design | Design sections updated in the same change (step 11); the `--type` decision is recorded for veto, not left implicit. |
| Workspace vs project separation | No test or mechanism text names a real project (fixtures use `demo`); `test_skill_prefix.sh` comment naming one is reworded. |
| Only what's needed | The one-registered-project convenience stays (a registry lookup); nothing new is added except the pointer lines and the stale-file report. |
| Improve incrementally | Three pull requests; the first is large because it is mostly deletion plus test moves, and cannot be split without leaving a half-legacy state that fails validate. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0011 (adapter contract) | Yes | Dispatcher discovery step 3 removed; no verb changes; `validate_adapter.sh` still passes. |
| ADR-0016 (session roots, Accepted) | Yes | Decision 2 (the tree hosts no project) is what this builds. |
| ADR-0012 (worktree composition) | Yes | `registry_worktree_dir` refuses unregistered names; `.worktree-repos` untouched. |
| ADR-0017 (design kept current) | Yes | Step 11. |
| ADR-0018 (plugin skill delivery) | Watch | `make setup` only prints a pointer to `user_tier_install.sh`; nothing installs. |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `adapter` discovery | every caller of `build.sh`, `test.sh`, `sync_project.py`, `adapter` without `--project` (grep `adapter ` and the shims before editing; `make sync` with no `PROJECT=` and no resolvable cwd now refuses) | Yes (step 4; implement greps) |
| Settings read only from the file | ROS `ROS_ROOT_DIR` (environment), `projects.local.example`, ros tests | Yes (step 5) |
| `.gitignore` entries removed | a stray `project/` shows in `git status` on a machine not yet cleaned | Yes, machine steps 2-3 |
| `AGENTS.md` wording | `agents-md-line-budget` hook | Yes (step 12) |

## Open Questions

- `ROS_ROOT_DIR` from the process environment (step 5) instead of a new settings-file key: a mechanism choice, listed for veto. Alternative: a `ros_root` registry field.
- Removing the copy-from-`.sh` adoption in `register_project.sh` (step 5): follows "no migration necessary"; alternative is to keep it one more release.
- Stale `.sh` files warn rather than fail validate (step 9): veto if he prefers a failure.
- `make sync` with no `PROJECT=` and no project resolvable from the cwd refuses; the old legacy path synced the workspace repo plus `project/`. Veto if a workspace-only sync is wanted (small addition).
- `--type` as a deprecated alias (above), for pull request 3.
- Owner question C goes to him when pull request 2 is planned.

## Estimated Scope

Pull request 1: one large pull request, 12 commits as listed, about 55 files. Pull requests 2 and 3: one each, planned after 1 and after 446 / 429 part 2 land.
