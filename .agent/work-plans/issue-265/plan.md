# Plan: Step 5, part 4 — retire `project/`, `projects/` and the worktree fallback

## Issue

https://github.com/rolker/agent_workspace/issues/265

Revision 3 (2026-11-16). Rewrites the 2026-09-16 revision 2, which described
the whole of step 5 against code that has since changed. This revision plans
**part 4 only**, against the code on this branch (current main). The earlier
text stays in git history.

## Context

Step 5 (hosted projects anywhere, project-rooted sessions via the user tier,
design B) was delivered in four pull requests. Parts 1 to 3 are merged and
are not re-planned: the registry fields, parent roots, worktree dirs and root
guard (PR 266), worktrees under each root (PR 273), and the user tier with
project-rooted sessions (PR 326, delivered under issue 317). Registering from
the project's own folder and one-step onboarding (issue 332), the plugin at
user scope (ADR-0018), the session-root rule (ADR-0016) and the fresh-clone
case (#295) landed around them.

What is left is the roadmap's deferral line: "retire `project/` and
`projects/` and the worktree fallback, and register the project11 instances
(#265, part 4)". `docs/design.md` (Sessions and roots, Target) already says
"PR 4 of #265 removes the legacy `project/` step".

**Owner direction, 2026-11-16** (verbatim): "265, pickerel does not have any
projects yet so it has nothing to retire. We can retire the old project
folders now. I did test the workspace at home as well with various project
types, all outside the workspace dir structure so we are ready for this
step."

Reading used here: nothing is migrated on the second machine; the old shapes
are retired in code now. Registering the project11 instances is being done by
a separate agent on pickerel under the project11 path, so it is **out of this
pull request's scope** (the code retirement does not depend on it: a registered
project resolves through the registry whatever its path, and the registry
already takes an absolute path).

### What still references the old shapes (verified by grep on this branch)

Three shapes are being retired:

- **A. the `project/` symlink or checkout** under the workspace root,
- **B. the `projects/<name>` default hosting directory** (registry default path),
- **C. the worktree fallback** `<ws>/worktrees/project/<name>/` for a project
  with no registry entry, and the pre-#25 `project/worktrees/`.

| Where | Shape | What it does today |
|---|---|---|
| `_worktree_helpers.sh` | A, C | `wt_legacy_project_base`, `wt_project_base_glob`, `wt_legacy_worktree_dirs`, `wt_transition_project_base`; `wt_resolve_project_repo_root` step 2 (`$root/project`); counts legacy dirs in `wt_count_project_worktrees` |
| `_project_registry.sh` | B, C | line 246 default `path="projects/$name"`; `registry_worktree_dir` falls back to `$root/worktrees/project/$name` for an unregistered name (line 529); header text |
| `scripts/adapter` | A, B | `ACTIVE_PROJECT_ROOT="$WORKSPACE_ROOT/project"`, the "under projects/ but unregistered" guard, the "Legacy: project/ symlink" branch and `_resolve_project_type` (legacy `PROJECT_TYPE` from `project_config.sh`) |
| `worktree_create.sh` | A, C | step 2 of project resolution (`$ROOT_DIR/project`), the unregistered `worktrees/project/<repo>` key (line 776), usage text |
| `worktree_enter.sh`, `worktree_remove.sh`, `worktree_list.sh` | A, C | search `wt_legacy_*`, transition base and `project/worktrees`; remove falls back to `$ROOT_DIR/project` as repo owner; enter's issue-title lookup reads `$ROOT_DIR/project/.git` |
| `merge_pr.sh` | A, C | `$ROOT_DIR/project` in the main-tree guards (lines 999, 1312), legacy worktree enumeration (603), comments |
| `dispatch_phase.sh`, `sitrep_root.sh` | A, C | resolve a worktree through `wt_legacy_*` and the transition base |
| `session_root.sh` | A | `--type project` with no `--project` accepts a `project/` checkout before the single-registered fallback |
| `gh_create_pr.sh`, `gh_create_issue.sh`, `pr_status.sh`, `discover_governance.sh`, `dashboard.sh`, `configure_git_identity.sh` | A | each reads `$ROOT/project` as a project repo; the registry already gives the same repos (`registry_repo_slugs`, #295) |
| `single_project/setup.sh`, `single_project/sync.py`, `lib/workspace.py` | A | default `--project-root` is `$ROOT/project`; `get_project_path()`; `is_project_configured()` default |
| `Makefile` | A, C | `MAIN_ROOT` detection for `/project/worktrees/`; the `PROJECT=` comment |
| `.gitignore` | A, B, C | `project/`, `project`, `projects/` |
| skills | A, C | `review-plan` (legacy glob and `wt_legacy_worktree_dirs`), `start-task`, `onboard-project` (line 499), `gather-project-knowledge` (`project/`), `test-engineering` (`cd project/<component>`) |
| docs | A, B, C | `design.md` (lines 120, 300 to 315, 428, 449, 490, 511, 562), `WORKTREE_GUIDE.md`, `WORKFORCE_PROTOCOL.md`, `AGENTS.md` Terminology, `README`/knowledge pages, `projects.local.example`, `vscode_setup.md`, `AI_IDENTITY_STRATEGY.md`, `build_and_test.md`, `script_reference.md`, `roadmap.md` |
| tests | A, B, C | 22 suites under `.agent/scripts/tests/` use or assert the old shapes (heaviest: `test_project_registry.sh`, `test_adapter.sh`, `test_ros2_colcon.sh`, `test_merge_pr.sh`) |

Not in scope, though it also says "legacy": the **legacy command config**
`.agent/projects.d/<name>.sh` (a per-project settings layer, ADR and issue 332
keep it on purpose) and `.workspace-worktrees/` (the pre-#25 *workspace*
worktree location, `wt_legacy_workspace_base`). Neither is `project/`,
`projects/` or the project worktree fallback.

### State on the owner's machines (read only, not touched)

On this machine `~/agent_workspace/project` is a symlink to a registered
project checkout, `~/agent_workspace/projects/` holds two registered project11
instances (explicit absolute paths in `.agent/projects.local`), and
`worktrees/` holds only `workspace/` (no `worktrees/project/`). Every project
here is registered with an absolute path, so removing the code paths changes
no resolution. This plan removes no directory on disk.

## Approach

One pull request, four commits of code plus tests, docs last-but-in-the-same-PR.

1. **Registry: no default hosting directory, no unregistered worktree dir.**
   In `_project_registry.sh`, an entry with no path is a parse error with a
   message saying to give an absolute path (`register_project.sh` already
   always writes one). `registry_worktree_dir` returns 1 with "project 'x' is
   not registered" for an unknown name instead of the `worktrees/project/<n>`
   fallback. Header and `lib/workspace.py` (line 248 `projects/{name}`) updated.
2. **Worktree scripts: registry-only.**
   Delete `wt_legacy_project_base`, `wt_project_base_glob`,
   `wt_legacy_worktree_dirs`, `wt_transition_project_base`; drop the `project/`
   step from `wt_resolve_project_repo_root` (then: a named project, or the one
   registered non-parent project, else an error that says to register one).
   Remove the matching branches in `worktree_create/enter/remove/list`,
   `merge_pr`, `dispatch_phase`, `sitrep_root` and `session_root`. In
   `worktree_remove`, derive the repo owner from the worktree's git common dir
   only, and fail loudly if that is empty (today it guesses `$ROOT/project`).
3. **Dispatcher and project-reading scripts: registry-only.**
   `adapter`: drop the `project/` default, the `projects/` guard and the legacy
   branch; with no `--project` and a cwd in no registered root, exit with a
   message that names `register_project.sh` and the `--project` flag, never a
   silent default. Drop `_resolve_project_type`'s `PROJECT_TYPE` read.
   `gh_create_pr`, `gh_create_issue`, `pr_status`, `discover_governance`,
   `dashboard`, `configure_git_identity`, `merge_pr`, `single_project/setup.sh`
   and `sync.py`: remove the `$ROOT/project` branch and use the registry (the
   repo-slug set from `registry_repo_slugs`, a registered root's checkout). The
   `single_project` default `--project-root` becomes required.
   `Makefile`: drop the `/project/worktrees/` `MAIN_ROOT` branch and reword the
   `PROJECT=` comment.
4. **Stale-shape warning, so retirement is not silent.**
   `validate_workspace.py` (what `make validate` runs) gains a warning, not a
   failure, when `<ws>/project` exists, when `<ws>/worktrees/project/` exists, or
   when a registered path lies under the workspace's `projects/`: it says the
   shape is no longer read, names what to do, and tells the owner nothing is
   deleted for him. This is the safety net for a machine that still has the old
   shape (nobody known, but the home machine was only tested with outside paths).
5. **Skills and docs, same pull request.**
   Skills: `review-plan` (loop over `wt_registry_worktree_dirs` only),
   `start-task`, `onboard-project`, `gather-project-knowledge`,
   `test-engineering` (use the registered project's root, no `project/`).
   Docs: `docs/design.md` (Sessions and roots: move the registry-only Target
   bullet to Now; Registry and adapters resolution order; the `gh_create_pr` and
   `merge_pr` rows; Worktrees bullet; discovery paragraph; change-log row, per
   ADR-0017), `WORKTREE_GUIDE.md` (drop the fallback tree and the legacy
   sections, keep one short "worktrees from before this change" note),
   `WORKFORCE_PROTOCOL.md`, `AGENTS.md` Terminology (the managed project is
   "a registered project", not `project/`; this is an instruction file, see
   Open Questions), `projects.local.example`, `vscode_setup.md`,
   `AI_IDENTITY_STRATEGY.md`, `build_and_test.md`, `script_reference.md`,
   `roadmap.md` (the step 5 row, the Direction line and the follow-up row:
   register part scoped out to the second-machine agent).
6. **Tests, with the code, not after it.** For each removed branch, delete or
   rewrite its test to assert the new refusal; add: an unregistered name is
   refused by `registry_worktree_dir` and by each of create/enter/remove; a
   pathless registry entry is a parse error; `adapter` with no project and a cwd
   outside every root errors and does not fall to a `project/` symlink even when
   one exists in the sandbox; `validate_workspace.py` warns on each stale shape.
   All use synthetic sandbox projects (no real checkout, no project name in the
   scripts or tests). The existing `test_fresh_clone_no_project.sh` stays.
7. **`.gitignore`.** Keep the three lines, relabelled "retired shapes; an
   existing checkout stays ignored on a machine that still has one". See
   Decisions.

Order: 1, 2, 3 in that order (each leaves the suites green); 4 and 6 with the
step they test; 5 last. Run only the touched suites per commit; the host runs
the full pass once before publishing (the standing one-full-run rule).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_project_registry.sh` | no default path; unregistered `registry_worktree_dir` refused; header |
| `.agent/scripts/_worktree_helpers.sh` | delete four `wt_*` legacy helpers; registry-only repo root; comments |
| `.agent/scripts/adapter` | registry-only discovery; loud no-project error |
| `.agent/scripts/worktree_create.sh`, `worktree_enter.sh`, `worktree_remove.sh`, `worktree_list.sh` | drop legacy and transition search; usage text |
| `.agent/scripts/merge_pr.sh`, `dispatch_phase.sh`, `sitrep_root.sh`, `session_root.sh` | drop `project/` and legacy enumeration |
| `.agent/scripts/gh_create_pr.sh`, `gh_create_issue.sh`, `pr_status.sh`, `discover_governance.sh`, `dashboard.sh`, `configure_git_identity.sh` | read the registry, not `$ROOT/project` |
| `.agent/scripts/lib/workspace.py`, `.agent/project_types/single_project/setup.sh`, `sync.py` | no `project/` default; `--project-root` required |
| `.agent/scripts/validate_workspace.py` | warn on the three stale shapes |
| `Makefile`, `.gitignore` | `MAIN_ROOT` branch, comments, relabel |
| `.claude/skills/{review-plan,start-task,onboard-project,gather-project-knowledge,test-engineering}/SKILL.md` | registry-only wording and commands |
| `docs/design.md`, `docs/roadmap.md`, `.agent/WORKTREE_GUIDE.md`, `.agent/WORKFORCE_PROTOCOL.md`, `AGENTS.md`, `.agent/projects.local.example`, `.agent/knowledge/{script_reference,build_and_test,vscode_setup,README}.md`, `.agent/AI_IDENTITY_STRATEGY.md` | text and design picture |
| `.agent/scripts/tests/*` (about 22 suites) | rewritten as above; new cases for the refusals and the warning |

## Prior Art

Nothing new is built. The retirement follows the shape the earlier parts
already made primary: `registry_repo_slugs` (#295) replaced the `project/` slug
check, `registry_worktree_dir` already serves registered roots, and
`test_fresh_clone_no_project.sh` already proves a workspace with no project
works. The warning in step 4 copies the report-only style of the existing
`validate_workspace.py` checks.

## Serves

Goals "Light touch on projects" and "Flexibility" (README Workspace goals); design sections
`docs/design.md#sessions-and-roots` with `docs/design.md#registry-and-adapters`
and `docs/design.md#worktrees`.

## Design Picture

Yes, it changes: the registry becomes the only link from a session to a
project. Same pull request (ADR-0017): `docs/design.md` Sessions and roots
(Target bullet moves to Now), Registry and adapters (resolution order loses the
`project/` step), Worktrees (fallback sentence), Merge gate and the
`gh_create_pr` row (the `project/` branch), discovery paragraph, plus a
change-log row.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Retirement is the point (standing rule) | Every old branch is removed in this pull request, not left as dead fallback |
| Fail loudly, never silently | An unregistered name or a no-project cwd errors with the remedy; a stale shape on a machine produces a warning |
| Workspace is project-agnostic (ADR-0003) | No project name in scripts, skills or tests; tests use synthetic sandboxes |
| Never delete the owner's data | No directory is removed or moved; only code, defaults, docs and fallbacks |
| Test with the change | Each removed path has a test asserting the new refusal |
| Verify before claiming | The table above is from grep and file reads on this branch |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 project-agnostic | Yes | no names in mechanism text; sandbox tests |
| 0011 adapter contract | Yes | its discovery order ends in the legacy `project/` step; ADR-0016 already records that the order is superseded. No edit planned (Open Questions) |
| 0016 session roots | Yes | this step finishes decision 2 (the workspace hosts no project); no edit planned |
| 0002 worktree isolation | Yes | text names `worktrees/project/<repo>/`; superseded in practice per the design register; no edit planned |
| 0017 design doc | Yes | design change in the same pull request |
| 0013 progress timeline | Yes | plan recorded via `review_progress.sh persist` |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `registry_worktree_dir` refuses unknown names | every caller that relied on the fallback (create, enter, remove, list, merge, dispatch, sitrep) | Yes, step 2 |
| `$ROOT/project` branches | the slug/repo checks in `gh_create_*`, `pr_status`, `discover_governance`, `dashboard` | Yes, step 3 |
| default hosting dir | `register_project.sh` (already absolute), `projects.local.example`, `lib/workspace.py` | Yes, steps 1 and 5 |
| design picture | `docs/design.md`, change log | Yes, step 5 |
| skills naming `project/` | `make generate-skills` if any `/make_*` text changes | Check at implementation |
| the pre-existing worktrees of a machine under `worktrees/project/` | none on known machines; a warning from step 4 | Yes, step 4 |
| registering the project11 instances | second-machine agent | No, out of scope (owner direction) |

## Decisions (mechanism; veto-able, with the cost of undoing)

- **Pathless registry entry is a parse error** (not a new default). Undo: restore
  one line in the parser; no entry on a known machine is pathless.
- **Warn, do not fail, on a stale `project/`, `worktrees/project/` or
  `projects/` path in `make validate`.** A hard fail would turn the owner's
  working machine red for a shape he is allowed to keep on disk. Undo: change a
  warn to a fail.
- **Keep the three `.gitignore` lines, relabelled.** Removing them would make the
  owner's existing `project` symlink and `projects/` show as untracked noise in
  his main checkout. Undo: delete three lines once he removes the directories.
- **Leave `.workspace-worktrees/` and the `projects.d/<name>.sh` command layer
  alone.** Neither is the named shape; the second is kept on purpose by #332.
  Undo: a follow-up pull request, small for the first, larger for the second.
- **One pull request** (the code is one connected removal; splitting would leave
  intermediate states with half the fallbacks). If review finds it too large the
  split point is after step 3.

## Open Questions

For the owner (goal level):

- None blocking. Two to note: (1) `AGENTS.md` Terminology ("the managed product
  in `project/`") names the retired shape; editing an instruction file is
  Ask First, so the edit is proposed in the pull request for his approval, not
  assumed. (2) ADR-0002 and ADR-0011 still describe the old shapes; the plan
  does not edit them (a new or substantively edited ADR is his decision). Say
  if he wants a status line added.
- Removing the actual `project` symlink and the `projects/` and
  `worktrees/project/` directories on his machines is his decision and is not
  in this plan; the warning will point at them.

## Estimated Scope

Single pull request, large (about 25 scripts, 22 test suites, 15 doc files).
Possible split after step 3 if review asks.
