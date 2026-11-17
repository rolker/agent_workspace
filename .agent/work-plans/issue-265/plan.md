# Plan: Step 5, part 4 — the registry is the only link: `project/`, `projects/`, the worktree fallback and the `.sh` command layer go

## Issue

https://github.com/rolker/agent_workspace/issues/265

Revision 4 (2026-11-16). Revision 3 planned a narrower pull request without the
recorded design for it. This revision starts from that record: the issue 295 plan,
section "Pull request B and C (one pull request): the legacy fallbacks and the
`.sh` reading go" (`.agent/work-plans/issue-295/plan.md`, written 2026-11-12 by
the owner's direction "done together with the fourth pull request of issue 265";
"Planned as one pull request, closing issue 265"). Every line number below was
re-read on this branch (main `d06cce95` differs from the plan's base `319f437a`
only by a research digest). It keeps what revision 3 found that the 295 plan
lacks: the no-project refusal test that exercises new code, the unread-shape
warning, the `registry_resolve_project_arg` and Python-parser sites, and the
second-machine split. Plan review of revision 3 (progress.md, `## Plan Review`
at `a0460f10`, findings 1 to 8, suggestions S1 to S5) and the host Checkpoint
after it are binding and are answered in the table at the end.

## Context

Step 5 (hosted projects anywhere, project-rooted sessions, design B) was
delivered in parts 1 to 3 (registry fields and root guard PR 266, worktrees under
each root PR 273, user tier PR 326), with issue 332 (register from the project's
folder), ADR-0016 (session roots), ADR-0018 (plugin) and issue 295 part A (a
fresh clone works with no project) around them. What is left is the roadmap's
deferral line: "retire `project/` and `projects/` and the worktree fallback, and
register the project11 instances (#265, part 4)".

**Owner direction, 2026-11-16** (verbatim): "265, pickerel does not have any
projects yet so it has nothing to retire. We can retire the old project folders
now. I did test the workspace at home as well with various project types, all
outside the workspace dir structure so we are ready for this step."

**Scope (settled by the host Checkpoint; not re-opened):**

- One pull request that retires four shapes: A the `project/` symlink or
  checkout; B the `projects/<name>` default hosting directory; C the worktree
  fallbacks (`<ws>/worktrees/project/<name>/`, `project/worktrees/`,
  `.workspace-worktrees/`); D the per-project `.agent/projects.d/<name>.sh` files
  and the shared `.agent/project_config.sh`. A registered project's settings
  come only from its settings file `.agent/projects.d/<name>`.
- Body says `Closes #265` and `Part of #295` (the pinned workspace entry and the
  special-case collapse stay with #295's later pull requests).
- Registering the project11 instances is **not this pull request's**: a separate
  agent does it on the second machine (the code retirement does not depend on
  it: a registered project resolves through the registry whatever its path).
- The plan **deletes or moves nothing on any machine.** The 295 plan's "machine
  steps" are a separate after-merge section that the host runs only after the
  owner says yes at that time.
- `AGENTS.md` is Ask First: its new wording is the last commit, prepared and
  held (exact text below).

### What changes on a machine like this one (review finding 2, stated plainly)

On the owner's first machine `~/agent_workspace/project` is a symlink to a
registered single-repository checkout, three non-parent projects are registered
(that one and two ROS instances), and the two instances are registered under
`<workspace>/projects/` (allowed by ADR-0016 decision 1). Today every call that
names no project resolves to the symlink: `wt_resolve_project_repo_root` step 2
(`_worktree_helpers.sh:191`), `session_root.sh:204`, `worktree_create.sh:515`,
`adapter` step 3 (line 258, used by `make build`, `make test`, `make install`,
`make sync` from the workspace root with no `PROJECT=`), `merge_pr.sh:350`,
`gh_create_*`, `pr_status.sh`, `discover_governance.sh`, `configure_git_identity.sh`.
After this pull request **each of those refuses** with a message that says what to
do ("no registered project here (cwd `<dir>`). Registered: `<names>`. Pass
`--project <name>` or register one: `.agent/scripts/register_project.sh <path>`"),
except `make sync`, which syncs the workspace alone (next paragraph). Calls that
name a project, or run inside a registered root, resolve as before. Also on that
machine: `make install` for the single-repository project reads its install command
from the shared `.agent/project_config.sh` today (the project's settings file holds
only `build` and `test`), and `make build PROJECT=<p11 instance>` reads its
`ROS_DISTRO` from `projects.d/<name>.sh` for the instance whose manifest declares
no distro. After this pull request neither is read (loud for the distro; for the
install command a silent "nothing to install", the reason the first machine step
below comes before anything else). The pull request description and the design
change-log row say this in these words.

**`sync` with no project is the one exception** (finding 3): it syncs the
workspace alone and prints the existing "No project was synced (...)" line.
`make sync` reaches `adapter sync`, which dispatches to `single_project/sync.py`,
the code that holds the workspace-only branch and its three messages
(`test_fresh_clone_no_project.sh` assertions d and f, design.md Sessions and roots
"Now" bullet, line 300). Once `_resolve_project_type` is gone the dispatcher still
needs a type directory to dispatch `sync` to; it names `single_project` once, in
a commented constant used only when the verb is `sync` and no project resolved
(see Decisions). Every other verb refuses.

### What still references the old shapes (grep on this branch; the table is the work list)

Shapes: A `project/`, B `projects/<name>` default, C worktree fallbacks, D `.sh`
layer. Line numbers are on this branch.

| Where | Shape | What it does today |
|---|---|---|
| `_worktree_helpers.sh` | A, C | `wt_project_base_glob` 83, `wt_legacy_worktree_dirs` 118, `wt_transition_project_base` 145, `wt_legacy_workspace_base` 249, `wt_legacy_project_base` 253; `wt_count_project_worktrees` 168 counts legacy dirs; `wt_resolve_project_repo_root` step 2 `$root/project` 191 and "no project configured" 207; header 47-65; `wt_ensure_exclusion` comment ("the transition fallback") |
| `_project_registry.sh` | B, C, D | header 17-22 and 53, 109-114; default `path="projects/$name"` 246; `registry_resolve_project_arg` 481-500 prints an unregistered name back "so legacy callers keep working"; `registry_worktree_dir` 503-530 falls back to `<root>/worktrees/project/<name>`; `_project_config_value` 1273, `project_command_source` 1287-1325 (`legacy`/`shared` arms), `_PROJECT_CONFIG_READ_VARS` 1331, `project_config_extra_vars` 1342; name rule "may not end in `.sh`" 176-180 (stays) |
| `scripts/adapter` | A, B, D | header 14-62 (discovery step 3, `ACTIVE_PROJECT_CONFIG`, `project_config.sh`), `_resolve_project_type` 76-96, `ACTIVE_PROJECT_ROOT=$WORKSPACE_ROOT/project` 212, `ACTIVE_PROJECT_CONFIG` 214 and 284, the "under projects/ but unregistered" guard and legacy branch 253-260, `--project` unknown text "see .agent/projects.local.example" 197, `active_project_fallback_note` 362-372 |
| `project_types/single_project/` | A, D | `adapter.sh` header 3-29, `_single_project_resolve_cmd` 38-76, `_single_project_load_cmd` 79-110, install 199-208, `adapter_project_root` default 219-220 and refusal 236; `setup.sh` default `project/` 22-24, 39-42, cases 72-146; `sync.py` imports 28-29, default 167-179; `registration.conf` 7 comment |
| `project_types/ros2_colcon/adapter.sh` | A, D | header 43-44, `_rc_config_file` 64-70, `_rc_root` 72-74, distro fallback 280-301, `_rc_ros_root` 315-330 (clears then sources the config), 340, `_rc_config_var` 416, bootstrap URL 436-449 and 489, 722-726, install 1613-1641 |
| `worktree_create.sh` | A, C | usage 183-184, header 18-20, step 2 `$ROOT_DIR/project` 515, "project/ is not configured" 533, unregistered key `worktrees/project/<repo>` 561 and 771-776 |
| `worktree_enter.sh`, `worktree_remove.sh`, `worktree_list.sh` | A, C | `wt_legacy_*`, transition base, `LEGACY_BASE` (enter 192-241, 289-293, 346-347 reads `$ROOT_DIR/project/.git`; remove 196-241 and 429 `_owner="$ROOT_DIR/project"`; list 171 `.workspace-worktrees`, 254, 352-370, 425) |
| `merge_pr.sh` | A, C | `PJ_ROOT_EFFECTIVE="${PJ_REPO_ROOT:-$ROOT_DIR/project}"` 350 and its uses 728, 863, 999, 1312, 2400; `$ROOT_DIR/project` in the main-tree guard lists 999 and 1312; legacy enumeration 577-603; comments 61, 69, 76, 228-239, 296-321, 348, 430-447, 802, 2373-2381, 2449 |
| `dispatch_phase.sh`, `sitrep_root.sh` | A, C | `resolve_worktree` 276-325 (legacy and transition bases; "or a legacy project/ checkout exists"); `sitrep_root.sh` header 80-83 and 363 |
| `session_root.sh` | A | header 49-52, `--type project` accepts `project/` 204-214 |
| `gh_create_pr.sh`, `gh_create_issue.sh` | A | the `$_WORKSPACE_ROOT/project` slug branch added before #295 (144-145, 172-173); `registry_repo_slugs` already gives every registered slug |
| `pr_status.sh` 40, `discover_governance.sh` 126-133, `configure_git_identity.sh` 56-197 | A | each reads `$ROOT/project` as the project repo |
| `dashboard.sh` | A, C, D | header 56-70, `PROJECT_DIR` block 144-173, status text 353-359, enumeration comment 408-410, orphan loop that strips `.sh` 207-217 |
| `registration_verify.sh` 22 and 153-155, `project_integration_audit.sh` 738 (`file\|legacy` arm), `register_project.sh` header 62-65, 73-76, 105-120, copy-from-`.sh` 728-752, `EXTRA_WARN` 812-826, line 531 note, `bootstrap.sh` 110 | D | read or mention the `.sh` and shared layers |
| `lib/workspace.py` 5, 28, 112-130, 248, 328; `validate_workspace.py` (no `project/` read; gains the warnings) | A, B | `get_project_path`, `is_project_configured`, `get_project_remote_url`; Python parser default `projects/{name}`; `single_project/sync.py` imports them |
| `Makefile` 20-27, 107 | A, C | `MAIN_ROOT` cases for `/project/worktrees/` and `/.workspace-worktrees/`; `PROJECT=` comment "unset means legacy project/" |
| `.gitignore` 2-10, 18, 48 | A, B, C, D | `project/`, `project`, `projects/`, `.workspace-worktrees/`, `.agent/project_config.sh` |
| skills | A, C | `review-plan` 92-123 (calls `wt_legacy_worktree_dirs`), `start-task` 134 and 205, `onboard-project` 499, `gather-project-knowledge` 48, `test-engineering` 180-192, `review-code` 251 |
| docs | all | `docs/design.md` 120, 300-315, 340-346, 366-384, 428, 445-450, 490, 511, 562, register rows 920 and 929, Table 2 `sync` row 466, change log; `WORKTREE_GUIDE.md` 27, 87-111, 135, 143, 216-217, 273, 316, 398-399; `WORKFORCE_PROTOCOL.md` 27; `AI_IDENTITY_STRATEGY.md` 138, 164, 298; `projects.local.example` 13, 23, 99-153; `knowledge/{script_reference,build_and_test,vscode_setup,README,documentation_verification,review_static_analysis}.md`; `templates/project_agents_guide.md` 42; `roadmap.md` 48, 86, 181, 202 |
| tests (22 suites touch these shapes) | all | heaviest: `test_project_registry.sh` (108 lines), `test_ros2_colcon.sh` (90), `test_adapter.sh` (83), `test_merge_pr.sh` (39), `test_project_integration_audit.sh` (24), `test_project_file.sh` (20), `test_merge_pr_gate.sh` (18), `test_session_root.sh` (17), `test_merge_pr_skill.sh` (15), `test_register_project.sh` (14), `test_discover_governance.sh` (13), `test_sitrep_root.sh` (8), `test_session_start_layer.sh` (7), `test_commit_identity.sh` (7), `test_skill_prefix.sh`, `test_precommit_hook_path.sh`, `test_dispatch_phase.sh`, `test_gh_create_pr.sh`, `test_gh_create_issue.sh`, `test_package_issue_loop.sh`, `test_worktree_create.sh`, `test_register_session_root.sh`, `live/plugin_acceptance.sh` |

Not in scope: `projects.d/<name>` (the settings file), the registry name rule
"a name may not end in `.sh`" (kept: it keeps a stale `<name>.sh` from being
mistaken for a settings file), `.agent/projects.local`.

## Approach

One pull request, commits ordered by shape (S1, S4). Each commit carries its
code, tests, skill text and design text, so a split at any commit boundary is
possible: **if the owner or review wants two pull requests, the cut is by shape,
C1+C2 (registry and worktree fallbacks, with `review-plan`, `start-task`,
WORKTREE_GUIDE and design Worktrees) versus C3 to C6 (the `project/` readers and
the `.sh` layer), never "after step 3".** Every deleted helper's callers change in
the same commit as the helper. Each commit runs only the suites it touches (the
standing one-full-run rule: the host runs the full pass once before publishing).

Refusal messages that name the registration script use one helper
(`registry_no_project_message`, below) so the split-token idiom that keeps the
test selector from treating a message as a read of that script
(`register_project"".sh`, as `worktree_create.sh:540` does; hub guard in
`test_script_tests_hook_scope.sh`) is written once.

1. **C1 Registry: no default hosting directory, no unregistered name.**
   `_project_registry.sh`: an entry with no path is a parse error saying a path
   is required and naming the registration script (`:246`; header 17-22);
   `registry_worktree_dir` returns 1 with "project '<name>' is not registered;
   register it: ..." for an unknown name (`:529`; comment 503-508);
   `registry_resolve_project_arg` returns 1 with the same message for an
   unregistered name instead of printing it back (`:481-500`; parent roots still
   resolve to their default instance); new `registry_no_project_message <root>
   <cwd>` prints the refusal sentence with the registered names. `lib/workspace.py`
   `:248` raises the same parse error (parity with the shell parser) and the three
   helpers go with their last importer in C3. Tests: `test_project_registry.sh`
   (pathless entry, unknown name in `registry_worktree_dir` and
   `registry_resolve_project_arg`, the helper's text with zero, one and three
   names); `test_adapter.sh`'s pathless-entry fixtures get explicit paths.
2. **C2 Worktree fallbacks go (shape C).** `_worktree_helpers.sh`: delete
   `wt_project_base_glob`, `wt_legacy_worktree_dirs`, `wt_transition_project_base`,
   `wt_legacy_workspace_base`, `wt_legacy_project_base`; `wt_count_project_worktrees`
   counts registry dirs only; header and `wt_ensure_exclusion` comment. Callers in
   the same commit: `worktree_create.sh` (unregistered key 561 and 771-776, usage,
   header), `worktree_enter.sh` and `worktree_remove.sh` (lookup 192-241, 289-293),
   `worktree_list.sh` (171 loses `.workspace-worktrees`, 254, 352-370, 425),
   `merge_pr.sh` (577-603 enumeration), `dispatch_phase.sh` (`resolve_worktree`
   276-325: registry dir only; an unresolved name returns "not found"),
   `sitrep_root.sh` (363, header), `dashboard.sh` (408-410, 69). **S2:
   `worktree_remove.sh` resolves every entry's owner (`:429` `_owner` no longer
   defaults to `$ROOT_DIR/project`; an empty owner refuses naming the entry)
   before removing anything**, so an aggregate worktree is never half removed.
   Skills and docs of this shape: `review-plan/SKILL.md` 92-123 (loop over
   `wt_registry_worktree_dirs` only; drop the legacy sentence), `start-task/SKILL.md`
   134 and 205, `WORKTREE_GUIDE.md` (87-111 fallback tree and its sentence, 135,
   143, 398-399 "legacy location" paragraph), design.md Worktrees (511) and the
   `worktree_list.sh` row 450. Tests: `test_worktree_create.sh`,
   `test_dispatch_phase.sh` ("falls back to the deprecated project/worktrees/ shape"
   becomes "refuses: not found"), `test_sitrep_root.sh`, `test_merge_pr.sh`
   enumeration cases, `test_project_registry.sh` helper cases; new named refusal
   tests (Test plan below).
3. **C3 The `project/` readers go (shape A) and the dispatcher refuses.**
   - `adapter`: delete `_resolve_project_type` and the `PROJECT_TYPE` read (76-96),
     the `ACTIVE_PROJECT_ROOT=$WORKSPACE_ROOT/project` default (212), discovery step 3
     and the `projects/` special error (253-260), header 14-20 and 40-46. With no
     project resolved and a verb other than `sync`: exit 1 with
     `registry_no_project_message`. With verb `sync`: `PROJECT_TYPE_NAME` is the
     named workspace-only-sync constant, `ACTIVE_PROJECT_NAME` stays empty, no
     refusal. The unknown `--project` text points at the registration script
     instead of `projects.local.example` (197).
   - `single_project`: `setup.sh` requires `--project-root` (refuses naming the
     registration script; 22-24, 39-42 and the `project/` cases 72-146 go);
     `adapter.sh` `adapter_project_root` loses the default (220, 236) and
     `adapter_setup`/`adapter_sync` stop branching on `ACTIVE_PROJECT_NAME`;
     `sync.py` stops importing `get_project_path`/`is_project_configured` (28-29,
     167-179; a local `is_git_checkout`; no `--project-root` is the workspace-only
     sync); `lib/workspace.py` deletes `get_project_path`, `is_project_configured`,
     `get_project_remote_url` and the header text. `ros2_colcon/adapter.sh`
     `_rc_root` loses its default (72-74).
   - `_worktree_helpers.sh` `wt_resolve_project_repo_root`: step 2 goes; a named
     project, or the single registered non-parent project, else
     `registry_no_project_message` (replaces 207). `worktree_create.sh` 515-540
     likewise. `worktree_enter.sh` 346-347 reads the registry root, not
     `$ROOT_DIR/project/.git`. `session_root.sh` 204-214 and header: refuses with the
     message ("names no project here: no registered project and N registered; pass
     `--project <name>` or register one").
   - `merge_pr.sh`: delete `PJ_ROOT_EFFECTIVE` (350); its uses (728, 863, 2400, and
     the lists at 999 and 1312) take `PJ_REPO_ROOT`, set whenever
     `WORKTREE_TYPE=project` (the fail-fast block exits otherwise); `$ROOT_DIR/project`
     leaves both main-tree guard lists; header and comments (61, 69, 76, 296-321,
     430-447, 2373-2381, 2449).
   - `gh_create_pr.sh`, `gh_create_issue.sh`: delete the `$_WORKSPACE_ROOT/project`
     slug branch (the registry slugs are the whole project set). `pr_status.sh`:
     iterate registered roots. `discover_governance.sh`: scan each registered root
     with scope `project`. `configure_git_identity.sh`: the workspace repo and each
     registered root's repositories (via `registry_entries`), not `project/`.
     `dashboard.sh`: no `PROJECT_DIR` block (144-173), status text 353-359 says
     "no projects registered: ...". `Makefile`: delete the `/project/worktrees/` and
     `/.workspace-worktrees/` `MAIN_ROOT` cases (20-27) and reword the `PROJECT=`
     comment (107).
   - Skills and docs of this shape: `onboard-project/SKILL.md` 499, `test-engineering`
     180-192 (`cd <project root>/<component>`), `review-code/SKILL.md` 251 and
     `review_static_analysis.md` 24 (path classes "under a registered project
     root"), `documentation_verification.md` 82 (a registered root may be a
     symlink), `gather-project-knowledge/SKILL.md` 48 (reworded for registered
     roots only; keep-or-retire is the owner's, Q5), `vscode_setup.md` 65 and 88,
     `AI_IDENTITY_STRATEGY.md` 138, 164, 298, `WORKFORCE_PROTOCOL.md` 27,
     `README.md` in knowledge (5, 15), `script_reference.md` rows, design.md Sessions
     and roots (Now/Target 300-315: "Discovery becomes registry-only" moves to Now)
     and Registry and adapters (428, 445-449, 562-563, Table 2 rows 449 and 466).
   - Tests: see Test plan; `test_fresh_clone_no_project.sh` stays and gains (g).
4. **C4 The `.sh` and shared-config reading goes (shape D; the 295 plan's step 5).**
   A registered project's build, test, install and bootstrap URL come only from its
   settings file (keys `build test install bootstrap_url`; `none` records "no such
   step"). Delete `ACTIVE_PROJECT_CONFIG` (adapter 214, 284, header), `active_project_fallback_note`
   (362-372), the shared-file branches in `single_project/adapter.sh`
   (`_single_project_resolve_cmd`, the "No project_config.sh found" text 103-109) and
   `ros2_colcon/adapter.sh` (`_rc_config_file`, `_rc_config_var`, install 1613-1641,
   bootstrap URL 436-449/489/722-726, distro 280-301); `project_command_source`
   returns only `file` or `missing`; `_project_config_value`,
   `_PROJECT_CONFIG_READ_VARS`, `project_config_extra_vars`, `_project_command_var`
   go if a grep shows nothing else uses them. `registration_verify.sh` loses its
   `legacy` and `shared` arms (22, 153-155); `project_integration_audit.sh:738`
   loses `legacy`; `register_project.sh` loses the copy out of `<name>.sh`
   (728-752), `EXTRA_WARN` (812-826), the header text (62-65, 73-76, 105-120) and
   the 531 note (becomes the stale-file report, C5); `bootstrap.sh:110` stops
   naming `project_config.sh`; `dashboard.sh` orphan loop no longer strips `.sh`
   (a `<name>.sh` is reported by C5, not accepted as a settings file). The
   missing-command error stays ("project 'X' has no build command; set it with
   project_setting.sh set X build=<command>"); its "legacy config" sentence goes.
   `ROS_DISTRO` stays in the registry `distro=` field or the manifest `distro:`
   (the error text drops the `.sh` option). `ROS_ROOT_DIR` has no settings key, so
   `_rc_ros_root` reads it from the process environment (default `/opt/ros`); this
   reverses today's rule that only a config file sets it, and the adapter header
   and `projects.local.example` say in one sentence that it is the one value read
   from the environment (only tests and non-standard installs set it). Skills and
   docs of this shape: `projects.local.example` 99-153 (the `.sh` layer paragraphs,
   discovery step 3), `build_and_test.md` (the `project_config.sh` section becomes
   `project_setting.sh`), `project_agents_guide.md` 42, `script_reference.md` 32-33
   (`build.sh`/`test.sh` rows), design.md 340-346 and 366-384 (the legacy and shared
   layer text). Tests: `test_adapter.sh`, `test_ros2_colcon.sh` (the tests that
   wrote `ROS_ROOT_DIR` into a config now export it), `test_project_file.sh` (the
   legacy-precedence cases become "a `<name>.sh` beside the settings file is not
   read"), `test_project_registry.sh` (`project_command_source`),
   `test_register_project.sh`, `test_package_issue_loop.sh` (fixture writes a
   `.sh`; changes to the environment variable; issue 448's hunks of that file are
   line-level overlap), `test_project_integration_audit.sh`.
5. **C5 Retirement is not silent: the stale-shape report (findings 3 to 4; 295 plan step 9).**
   Warnings, never failures (a hard fail would turn a working machine red for files
   the owner is allowed to keep until the machine steps run), read from the main
   checkout (`get_main_checkout_root`), shown by `validate_workspace.py` after the
   results block and by `dashboard.sh` as `check_warn`, with exit status unchanged:
   - `<ws>/project` exists: if it resolves (symlink or not) to a registered root,
     "`project` is a link to registered project '<name>'; nothing reads the link any
     more: remove it (`rm project`)"; otherwise "`project` exists and is not
     registered; nothing reads it any more: register it with
     `register_project.sh <path>` or remove it".
   - `<ws>/worktrees/project/` contains a directory: "worktrees there are no longer
     found; ..." and `<ws>/.workspace-worktrees/` likewise.
   - a directory under `<ws>/projects/` that **no registry entry owns** (no entry's
     path equals it, lies under it, or contains it): "nothing reads it any more;
     register it or remove it". **A root registered under `<ws>/projects/` is silent**
     (ADR-0016 decision 1; two such roots exist on the first machine); tested.
   - `.agent/projects.d/<name>.sh` exists (any name, registered or not): "no longer
     read; move its settings with `project_setting.sh set`, then delete it".
   - `.agent/project_config.sh` exists: per registered project and key, one line
     for each of `BUILD_CMD`, `TEST_CMD`, `INSTALL_CMD`, `MANIFEST_BOOTSTRAP_URL`
     the file sets that the project's settings file lacks ("`.agent/project_config.sh`
     sets INSTALL_CMD, which `.agent/projects.d/<name>` lacks: `project_setting.sh
     set <name> install=<command>`"); with nothing missing, "no longer read; delete
     it". A ros2_colcon project needs no `build`/`test` key (its `unused_settings`),
     so those two are not reported for it.
   - `adapter` prints one stderr NOTE when the active project has a `<name>.sh`;
     `register_project.sh` replaces its 531 note with the same text.
   Tests in a new `test_validate_workspace_stale.sh` and `test_adapter.sh`: each
   case above, the registered in-tree root silent, exit 0 with warnings, and the
   per-key rule (a shared file with `INSTALL_CMD` and a settings file without
   `install` reports exactly that key; with `install` set, nothing for the key).
6. **C6 The two carried suggestions from pull request 454 (finding 6).** F1: reword
   the four comments that describe the old common-dir rule so they name
   `get_main_checkout_root` / `registry_main_checkout`
   (`single_project/sync.py:188`, `validate_workspace.py:154`, `dashboard.sh:156`,
   `test_fresh_clone_no_project.sh:187`) and fix the Makefile `WS_ROOT` rule
   (`Makefile:41`): `WS_ROOT` stays `common dir minus /.git` for the venv and stamps
   (it decides `STAMP` and `VENV_DIR`; changing where those live is not this part),
   its comment says so and says it is not where the registry is found, and the
   `setup` recipe's "No project is registered" check reads the registry through
   `registry_main_checkout` (one `bash -c` line), so a `--separate-git-dir` main
   checkout no longer says "No project is registered" with a registry present.
   F2: add the case to `test_main_checkout_helpers` in `test_project_registry.sh`: a
   linked worktree of a `--separate-git-dir` checkout, where git lists the git dir
   rather than a checkout, so both helpers fall back to the worktree; the fallback is
   recorded as the decision and the "none registered" text of `sync.py`,
   `validate_workspace.py` and `dashboard.sh` is replaced, for that fallback only
   (the helper reports it fell back from a linked worktree), by "no registry found
   from this linked worktree; run it from the main checkout". Same shell and Python
   helpers; both tested.
7. **C7 Remaining docs, roadmap, ignore file, grep check.** `.gitignore` keeps
   `project/`, `project`, `projects/`, `.workspace-worktrees/` and
   `.agent/project_config.sh` (plan review N1: removing them makes a machine that
   keeps the old shapes, or registers a root under `projects/` as ADR-0016 decision
   1 allows, show a dirty main checkout, and `make sync` skips a dirty checkout);
   their comment says they are retired shapes, still ignored so such a machine stays
   clean, and that the stale-shape report names them. `docs/design.md`:
   remaining Sessions and roots and Registry and adapters text, the ADR register
   rows 920 (0002) and 929 (0011) reworded to say the fallback and the legacy
   `project/` step are gone (a design-doc edit, not an ADR edit), the Table 1 and
   Table 2 inventory rows this removes struck out with the rest kept as evidence,
   line counts, and one change-log row that states the "what changes on a machine
   like this one" paragraph. `docs/roadmap.md` (record text; proposed minimal edit,
   listed for the owner's veto): delete the deferral row 86; drop
   "retiring `project/` and `projects/` (#265, part 4)" from the sentence at lines
   47-48; rows 181 and 202 status `in progress` becomes `done`, with row 181's tail
   adding "Part 4 (retire) merged; registering the project11 instances on the second
   machine is tracked by #433." (the acceptance sentence there, "project11
   port-to-rolling under `~/project11-ng` before cutover", is the owner's, so the
   edit leaves it and says it is not tracked here). **Grep check, run by the implement
   pass and quoted in its entry:**
   `cd <worktree> && grep -rIn "project/\|project_config\|worktrees/project\|wt_legacy\|wt_transition\|wt_project_base_glob\|projects/<name>\|projects/" .claude .agent docs Makefile AGENTS.md | grep -v "^.agent/work-plans/\|^docs/decisions/\|^docs/fork_parity\|research_digest\|^.agent/knowledge/\(research\|inspiration\)"`
   Expected: not empty (the pattern also matches ordinary prose such as a path under
   a registered root), so it is read, not counted: every remaining hit is a record
   (design change log and register rows, roadmap history) or listed in the entry as
   deliberate with its reason (the stale-shape warnings' text, the fixtures that
   build an ignored `project/` on purpose, `<root>/worktrees` of a registered
   project). A second, exact check: `grep -rIn "wt_legacy\|wt_transition\|wt_project_base_glob\|PJ_ROOT_EFFECTIVE\|ACTIVE_PROJECT_CONFIG\|active_project_fallback_note\|_rc_config_file\|project_config_extra_vars\|_PROJECT_CONFIG_READ_VARS\|_resolve_project_type\|get_project_path\|is_project_configured" .claude .agent docs Makefile` outside the records list returns nothing. Also: `make generate-skills` if a `/make_*` text changed; `docs/design.md` anchors check (`test_design_anchors.sh`).
8. **C8 `AGENTS.md` (Ask First): prepared, held, last.** Exact text below; the host shows
   it to the owner word for word at the merge checkpoint. If he declines the wording,
   the commit is dropped and the pull request ships without it (the other commits do
   not depend on it; AGENTS.md then still says `project/`, reported as a known gap).

### Test plan (finding 7: one named refusal test per changed script; synthetic sandboxes only)

The adapter test runs from **inside the sandbox workspace, in no registered root,
with a `project/` symlink to a git checkout present** and three non-parent projects
registered (the first machine's shape, with synthetic names). It asserts the
symlink is **not** used.

| Script | Named test (message names the registration script or `--project`) |
|---|---|
| `adapter` | from the sandbox workspace root and from `<ws>/docs`: `build`, `test`, `install` refuse and list the registered names; with zero registered and a `project/` checkout present: refuses; `sync` there syncs the workspace and prints "No project was synced"; `--project <unknown>` text; cwd under a registered root resolves; `<name>.sh` beside the settings file prints the NOTE |
| `worktree_create.sh` | `--type project` with no name: several registered refuses, none registered refuses, `project/` present is ignored; `--project <unregistered>` refuses |
| `worktree_enter.sh`, `worktree_list.sh` | `--project <unregistered>` refused; a directory `worktrees/project/<n>/issue-<n>` present in the sandbox is not found |
| `worktree_remove.sh` | same; **and S2**: an aggregate worktree whose second entry's owner cannot be resolved removes nothing |
| `merge_pr.sh` | no name and several registered refuses; `--type project` with nothing registered exits 1 naming the script; the main-tree guard no longer lists `$ROOT_DIR/project` (running from a `project/` checkout is not treated as a main tree); a workspace PR merges with no project registered |
| `dispatch_phase.sh`, `sitrep_root.sh` | `resolve_worktree` and the sit-rep lookup do not find `worktrees/project/<n>` |
| `session_root.sh` | `--type project` with no `--project`, `project/` present, several or none registered: refuses |
| `gh_create_pr.sh`, `gh_create_issue.sh` | an unregistered `project/` checkout's slug is refused |
| `single_project/setup.sh`, `sync.py` | `setup` without `--project-root` refuses; `sync` with `--project-root` naming a non-checkout says so; `sync` with none is workspace-only |
| `configure_git_identity.sh`, `discover_governance.sh`, `pr_status.sh` | a `project/` checkout is not read; a registered root is |
| `validate_workspace.py`, `dashboard.sh` | each stale shape; registered in-tree root silent; per-key report; warnings do not change the exit status |
| `_project_registry.sh`, `lib/workspace.py` | pathless entry; unknown name refused by `registry_worktree_dir` and `registry_resolve_project_arg`; `test_main_checkout_helpers` separate-git-dir linked worktree |

Fresh-clone suite (`test_fresh_clone_no_project.sh`, finding 3): assertions (d) and
(f) and the 20-case file pass **unchanged**; added: (g) `make build` and
`adapter build` refuse naming the registration script; (h) after
`register_project.sh <demo path> --set build=true --set test=true --skip-run` in the
clone, `adapter --project demo build` runs. Committed content, stamps pre-seeded, no
network. **S3:** while rewriting fixtures, the project-named shapes (`p11`) in
`test_merge_pr.sh` (`worktrees/project/p11/...`), `test_session_root.sh:182`,
`test_skill_prefix.sh:38-70`, `test_session_start_layer.sh` become neutral names
(`demo`, `inner`, `alpha`). Commit hashes are not asserted.

### AGENTS.md: the held last commit (exact old and new text)

The file is 199 lines and the pre-commit budget is 200 (`agents-md-line-budget`);
the new text adds exactly one line. Based on the 295 plan's proposed wording and
the owner's 2026-11-12 decision that a project is any registered folder with git
and a hosting service optional. Four edits (the review's Q4 listed the first three;
the fourth is the same retirement: line 157 names the file this pull request stops
reading, so leaving it would make AGENTS.md false the day it merges).

Lines 10-11, old:

```
- **Project**: the managed product in `project/` — what's actually being built.
  Product features, deployment, and user-facing behavior are project scope.
```

new (three lines):

```
- **Project**: the managed product, any folder registered with the workspace
  (`register_project.sh`), wherever it lives; git and a hosting service are
  optional. Features, deployment and user-facing behavior are project scope.
```

Lines 19-23, old:

```
**Repo ownership**: The working directory contains files from both repos
(workspace infrastructure is layered onto the project checkout). Don't assume
which GitHub repo you're in based on directory contents — use `gh repo view` or
`git remote -v` to confirm. Issues and PRs must target the repo that owns the
code being changed:
```

new:

```
**Repo ownership**: A workspace session works in the workspace checkout and a
project session in the project's own registered folder; the two are separate
folders. Don't assume which repo you're in based on directory contents — use
`gh repo view` or `git remote -v` to confirm. Issues and PRs must target the
repo that owns the code being changed:
```

Line 28, old:

```
| Project | project repo (e.g. `my_project`) | The product being built (`project/`) |
```

new:

```
| Project | project repo (e.g. `my_project`) | The product being built (its registered folder) |
```

Lines 157-159 (Build & Test), old:

```
Configure the project's build and test commands in `.agent/project_config.sh` (gitignored);
then `make build`, `make test`, `make lint` (pre-commit on all files) and `make validate`
(workspace config). See [`.agent/knowledge/build_and_test.md`](.agent/knowledge/build_and_test.md).
```

new:

```
Set a single-repository project's build and test commands with `project_setting.sh set <name> build=<command>`
(a `ros2_colcon` project's come from colcon); then `make build PROJECT=<name>`, `make test PROJECT=<name>`,
`make lint` (pre-commit on all files) and `make validate`. See [`.agent/knowledge/build_and_test.md`](.agent/knowledge/build_and_test.md).
```

Verify at implement time: the budget check, `test_agents_md_budget.sh`, and that
`project_setting.sh` is spelled as the real script (`.agent/scripts/project_setting.sh`).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_project_registry.sh` | C1 path required, refuse unknown names, `registry_no_project_message`; C4 `.sh` and shared helpers go; C6 helper fallback flag |
| `.agent/scripts/_worktree_helpers.sh` | C2 five legacy helpers deleted; C3 registry-only repo root |
| `.agent/scripts/adapter`, `.agent/project_types/{single_project,ros2_colcon}/*` | C3 registry-only discovery, refusal, `sync` exception, no `project/` default; C4 settings-file-only |
| `.agent/scripts/{worktree_create,worktree_enter,worktree_remove,worktree_list,merge_pr,dispatch_phase,sitrep_root,session_root,dashboard}.sh` | C2 and C3 as above |
| `.agent/scripts/{gh_create_pr,gh_create_issue,pr_status,discover_governance,configure_git_identity}.sh` | C3 read the registry |
| `.agent/scripts/{registration_verify,register_project,project_integration_audit,bootstrap}.sh` | C4 |
| `.agent/scripts/lib/workspace.py`, `.agent/scripts/validate_workspace.py`, `.agent/project_types/single_project/sync.py` | C1, C3, C5, C6 |
| `Makefile`, `.gitignore` | C3, C6, C7 |
| `.claude/skills/{review-plan,start-task,onboard-project,gather-project-knowledge,test-engineering,review-code}/SKILL.md` | registry-only wording and commands |
| `docs/design.md`, `docs/roadmap.md` | C2 to C7 (design picture, register rows, inventory, change log; roadmap proposed edit) |
| `.agent/WORKTREE_GUIDE.md`, `.agent/WORKFORCE_PROTOCOL.md`, `.agent/AI_IDENTITY_STRATEGY.md`, `.agent/projects.local.example`, `.agent/knowledge/{script_reference,build_and_test,vscode_setup,README,documentation_verification,review_static_analysis}.md`, `.agent/templates/project_agents_guide.md` | text |
| `.agent/scripts/tests/*` (22 suites listed above, plus new `test_validate_workspace_stale.sh`) | rewritten and added as in the test plan |
| `AGENTS.md` | C8, held, owner's yes |

## Overlap with open branches (`git diff --stat main...<branch>`, read only; S4)

| Branch | Shared files with this plan | Ordering |
|---|---|---|
| `feature/issue-465` | `dispatch_phase.sh` (its hunks are at `cmd_handoff` 605-619; ours at `resolve_worktree` 276-325, so a textual merge is clean), `test_dispatch_phase.sh` (78 lines changed: expect a real conflict in the fixture hunks), `test_skill_paths.sh`, `suites_for_files.sh`, `.pre-commit-config.yaml` | the `dispatch_phase.sh` and `test_dispatch_phase.sh` changes are their own small commit inside C2 so a rebase onto whichever merges first stays small; `script_reference.md` is not in 465's diff now |
| `feature/issue-477` (pull request 479) | `docs/roadmap.md` (its hunk at 80-85 is adjacent to row 86), `test_skill_paths.sh` | roadmap edits are one hunk in C7; if 479 merges first, C7 rebases onto it, otherwise 479 does |
| `feature/issue-429` (part 2) | none now (the 295 plan expected `worktree_create.sh`, `merge_pr.sh`, `dispatch_phase.sh`; its diff against main is empty today) | part 2 rebases onto this, never in parallel |

## Prior Art

The recorded design: the 295 plan's B and C section, taken whole and re-verified
(line numbers moved by up to 60 since; every site above is re-read). Outside it:
`registry_repo_slugs` (#295 part A) already replaced the `project/` slug check;
`registry_worktree_dir` already serves registered roots; `test_fresh_clone_no_project.sh`
already proves a workspace with no project works; the report-only style is that of the
existing `validate_workspace.py` checks and the dashboard's `check_warn`. Taken from
revision 3 (and not in the 295 plan): the unregistered-name refusal in
`registry_resolve_project_arg`, the Python parser default, the in-tree-root-silent
warning rule, the named refusal tests. Rejected: keeping the `.sh` layer "because
#332 keeps it" (#332's own text calls it legacy and it is load-bearing on the first
machine only because its settings were never moved, which the machine steps and the
report fix). Reversed by plan review N1: the 295 plan removed the `.gitignore` lines;
they stay, reworded (C7).

## Serves

Goals "Light touch on projects" and "Flexibility" (README Workspace goals); design
sections `docs/design.md#sessions-and-roots`, `docs/design.md#registry-and-adapters`
and `docs/design.md#worktrees`.

## Design Picture

Yes, it changes: the registry becomes the only link from a session to a project, and
the settings file the only source of a project's commands. Same pull request
(ADR-0017): design.md Sessions and roots (the Target bullet "Discovery becomes
registry-only" moves to Now; the line-300 bullet still true), Registry and adapters
(resolution order, legacy and shared layer text, inventory rows), Worktrees (the
fallback sentence), ADR register rows 0002 and 0011 (design.md only), Table 2 rows
`sync`, `gh_create_pr`, `merge_pr`, and a change-log row.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Retirement is the point (standing rule) | Every old branch is removed here, none left as dead fallback; the grep check and stale report close the loop (the `.gitignore` lines stay so a machine that keeps a retired shape stays clean, N1) |
| Fail loudly, never silently | Unregistered names, no-project cwd and a missing `install` are refused or reported with the remedy; stale files produce a report, never silent ignore |
| Project-agnostic (ADR-0003) | No project name in mechanism text, tests or this plan's mechanism sections; fixtures use synthetic names (S3) |
| Never delete the owner's data | The pull request removes no directory or file on any machine; the machine steps wait for his yes |
| Test what breaks | A named refusal test per changed script, exercising the new code, with a `project/` symlink present |
| Keep one current design | design.md changed in the same pull request, including the register rows and the `sync` row |
| Verify before claiming | Every site is a grep or file read on this branch; machine facts read from the main checkout read-only |
| Ask what, not how | Mechanism decisions below are made and listed for veto; only goal-level questions go to the owner |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 project-agnostic | Yes | no names in mechanism text; synthetic fixtures; plan quotes the machine's names only in the after-merge section, a record |
| 0011 adapter contract | Yes | its discovery order's legacy `project/` step goes; the `sync` default names one type in the dispatcher (Decisions); **no ADR edit** (owner question Q-ADR) |
| 0016 session roots | Yes | finishes decision 2 (the workspace hosts no project); decision 1 respected: a root registered in the workspace tree is silent in the warning |
| 0002 worktree isolation | Yes | its text names `worktrees/project/<repo>/`; superseded in practice; **no ADR edit** (Q-ADR) |
| 0017 design doc | Yes | design change in the same pull request |
| 0013 progress timeline | Yes | plan recorded via `review_progress.sh persist` |
| new-ADR rule | Checked | no ADR is added or edited; the owner decides a status line (Q-ADR) |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| names that name no project stop resolving to `project/` | adapter, worktree_create, session_root, merge_pr, gh_create_*, pr_status, discover_governance, configure_git_identity, dashboard, the install and sync verbs; the "what changes on a machine like this one" paragraph in the PR description and change log | Yes, C3, C7 |
| `registry_worktree_dir` and `registry_resolve_project_arg` refuse unknown names | create, enter, remove, list, merge, dispatch, sitrep callers | Yes, C1, C2 |
| the `.sh` and shared-config layers stop being read | the two type adapters, `register_project.sh`, `registration_verify.sh`, `project_integration_audit.sh`, `bootstrap.sh`, dashboard orphan loop, `projects.local.example`, `build_and_test.md`, `project_agents_guide.md`, tests, AGENTS.md line 157 | Yes, C4, C8 |
| `ROS_ROOT_DIR` read from the environment | adapter header, `projects.local.example`, `test_ros2_colcon.sh` | Yes, C4 |
| `sync` with no project stays a workspace-only sync | `test_fresh_clone_no_project.sh` (d), (f) unchanged; Sessions and roots Now bullet | Yes, C3 |
| `.gitignore` lines kept, comment reworded (N1) | the stale-shape report names the shapes they ignore | Yes, C5, C7 |
| deleted helper names | `review-plan` skill, `script_reference.md`, design.md inventory | Yes, C2, C7 |
| design picture | design.md and change log | Yes |
| roadmap deferral row 86 and rows 181, 202, line 48 | 479's roadmap hunk | Yes, C7, overlap table |
| skills that name `project/` | `make generate-skills` if a `/make_*` text changes | Check at C7 |
| registering the project11 instances | second-machine agent, tracked by #433 | No, out of scope (Checkpoint) |

## After-merge machine steps (NOT code; run by the host only after the owner says yes at that time)

The pull request deletes and moves nothing. 88 repositories under the two ROS
clones were checked clean and in sync on 2026-11-12; re-check before step 6 (the
deletion).
Facts read on 2026-11-16 (read only): registry `gz4d single_project /home/roland/src/gz4d`,
`p11-jazzy` and `p11-rolling` `ros2_colcon` under `~/agent_workspace/projects/`;
settings file `.agent/projects.d/gz4d` holds only `build` and `test`;
`.agent/project_config.sh` sets `PROJECT_TYPE`, `BUILD_CMD` and
`INSTALL_CMD="cmake --install build --prefix install"`; `projects.d/p11-jazzy.sh`
sets `ROS_DISTRO="jazzy"` and `MANIFEST_BOOTSTRAP_URL`, `projects.d/p11-rolling.sh`
sets `MANIFEST_BOOTSTRAP_URL`; `p11-rolling`'s manifest declares `distro: rolling`,
`p11-jazzy`'s manifest declares no distro; `project` is a symlink to
`/home/roland/src/gz4d`; `worktrees/` holds only `workspace/`; neither clone has a
`worktrees/` directory.

**Settings that must move first, so nothing load-bearing is lost** (safe before or
after the merge; the pull request's stale-file report names any still missing):

1. `project_setting.sh set gz4d install="cmake --install build --prefix install"`
   (the shared file's install command; without it `make install` for that project
   prints "INSTALL_CMD not set - nothing to install" and exits 0, a silent loss). If
   the owner says install is not wanted: `install=none`.
2. The distro of the instance whose manifest declares none: add `distro=jazzy` to
   `p11-jazzy`'s line in `.agent/projects.local` by hand (`register_project.sh`
   refuses to change a registered line's fields). Without it `adapter --project
   p11-jazzy ...` stops with "cannot resolve the ROS distro" (loud). Like step 3,
   pointless if step 5 removes the entries.
3. The bootstrap URLs: `project_setting.sh set p11-jazzy bootstrap_url=<URL from its
   .sh>` and the same for `p11-rolling`. Only needed if the clones are kept and could
   be re-bootstrapped; skipped if step 5 removes their entries.

Then, each on his yes, in order:

4. `make validate` and `make dashboard` show only the expected warnings (the report is
   the check).
5. `.agent/scripts/register_project.sh --remove p11-jazzy` and `--remove p11-rolling`
   (refuses with live worktrees; none exist), if the clones go.
6. `rm -r projects/` (the two clones) and `rm project` (the symlink; the owner said it
   is not needed on 2026-11-12). The project's own checkout and its in-tree
   `worktrees/` belong to its own repository and are untouched.
7. `rm .agent/projects.d/p11-jazzy.sh .agent/projects.d/p11-rolling.sh`, then
   `rm .agent/project_config.sh` once the report names no unset key. The settings file
   `.agent/projects.d/gz4d` stays.
8. `make validate` and `make dashboard` again: the report shows nothing.

## Decisions (mechanism; veto-able, with the cost of undoing)

- **One pull request, `Closes #265`, `Part of #295`**, cut by shape if split (above).
  Undo: split at the C2/C3 boundary; each commit has its own tests.
- **`sync` with no project dispatches to `single_project` through one named, commented
  constant in `adapter`.** ADR-0011 says workflow scripts never branch on a type; the old
  `_resolve_project_type` defaulted the same way. Undo (about 80 lines): move
  `sync_repo` and `sync_gitbug` to `lib/` and let `sync_project.py` call them.
- **A pathless registry entry is a parse error**, in the shell and Python parsers. Undo:
  restore one line each; no entry anywhere is pathless.
- **Stale shapes warn, never fail `make validate`.** Undo: change a warn to a fail.
- **`ROS_ROOT_DIR` comes from the environment** (295 plan, finding 9). Undo: a settings key.
- **`make setup` reads the registry through `registry_main_checkout`; `WS_ROOT` keeps its
  rule** (F1). Undo: one line.
- **The "none registered" text for a linked worktree whose main checkout git does not
  record says "no registry found from this linked worktree"** (F2). Undo: one text.
- **`.workspace-worktrees/` goes with the other fallbacks** (295 plan step 6). Undo: restore
  one helper and its callers.
- **`gather-project-knowledge` is only reworded** where it names `project/`; keep-or-retire
  is parked for the owner (Q5).

## Open Questions

For the owner (goal level). Q1 to Q5 of the plan review are settled by the host
Checkpoint (scope, closing, disk, AGENTS.md wording, skill); what remains:

- **Q-ADR** Add a status line to ADR-0002 and ADR-0011, which still describe the
  retired shapes? (No edit is in this pull request; a new or substantively edited ADR
  is his decision. Undo cost of adding later: one commit.)
- **Q-AGENTS** Approve the exact AGENTS.md text above (four edits, one of them the
  Build & Test sentence not on the review's list)? Asked at the merge checkpoint.
- **Q-ROADMAP** The roadmap edits above are record text: the deferral row goes, rows 181
  and 202 read "done", and the project11 acceptance sentence is left as his words. Veto?
- **Q5** (parked in the inbox) Is `gather-project-knowledge` still wanted?

## Estimated Scope

One pull request, large: about 55 files, 8 commits (7 code and docs, 1 held), roughly
+1,000 / -1,700 lines (tests are most of both columns), because it is mostly deletion
plus test moves. Review: the host runs the full test pass once; a split by shape is
available (C1+C2 versus C3 to C7) if review finds it too large.

## Plan review (revision 3) answered

| Item | Answer |
|---|---|
| 1 Scope | Restarted from the 295 plan's B and C; `.sh` and shared config included; `Closes #265` |
| 2 Machine consequence | Stated in Context; refusal test with `project/` present and three registered |
| 3 `sync` | Exception kept; code path named; fresh-clone suite unchanged, (g) and (h) added |
| 4 Warning | Only an unowned directory under `projects/` and the other unread shapes; in-tree registered root silent, tested |
| 5 Missed sites | All in the table, plus the exact grep check as C7 |
| 6 F1 and F2 | C6 |
| 7 Tests | Adapter test inside the workspace outside any root with `project/` present; one named test per changed script |
| 8 Closing | `Closes #265`; registering is the second-machine agent's; roadmap rows named for the owner's veto |
| S1 | One pull request; split by shape if offered |
| S2 | `worktree_remove.sh` resolves every owner first |
| S3 | Fixture names neutralised while rewriting |
| S4 | Overlap table; `dispatch_phase.sh` hunk and roadmap hunk each in their own commit or hunk |
| S5 | `gather-project-knowledge` reworded only |
