# Plan: ros2_colcon adapter: call the manifest tool's commands, and register a project from a manifest

## Issue

https://github.com/rolker/agent_workspace/issues/503 (part 1 of 4: the first cut; the pull
request says "Part of #503")

## Context

The issue's text predates the owner's decisions of 2026-11-18. The Issue Review in
`progress.md` replaces its "What to build" and "Acceptance" for part 1, and the Checkpoints
after it bind this plan. Part 1 is the owner's first cut: a directory the tool set up
(`repos-manifest init --distro-dirs`) is registered as one `ros2_colcon` project; its
`setup` and `sync` call the tool's `sync`; building stays colcon per layer until the tool's
`build` lands; and `/run-issue` on a package repository's issue, from a session at that
directory, makes a package worktree that builds against the layers built by hand and goes
on to a merged pull request.

Today every verb finds its files through a few helpers in
`.agent/project_types/ros2_colcon/adapter.sh`: `_rc_manifest_dir` (the directory holding
`layers.txt`), `$mdir/repos/<layer>.repos` (spelled out in `adapter_setup`, `adapter_sync`,
`adapter_validate`, `adapter_repo_pin`), and `_rc_layer_dir` (`layers/main/<layer>_ws`). The
tool's layout (`system.py` on `feature/issue-500`) is `<root>/<distro>/<layer>/src/<key>`,
the unnamed layer's repos in `<root>/<distro>/src/`, and the resolved output in
`<root>/.repos-manifest/resolved/<distro>/` as `layers.txt`, `<layer>.repos` and
`optional.txt` (optional repos by key). Part 1 is a third answer from those helpers.

The owner's root (`~/project11`) is a plain directory holding clones, in no git repository.
Two generic refusals stop `/run-issue` there before a worktree exists (Plan Review finding
1); part 1 relaxes them, which widens the first Checkpoint's "kept to the adapter's few path
helpers" (the second Checkpoint decided it). Every other place on the path was read; the
table below says what each does.

## Approach (part 1)

1. **Calling directory.** `.agent/scripts/adapter` sets one more variable before it sources
   the type: `ACTIVE_PROJECT_FROM="$(cd "${FROM_DIR:-$PWD}" && pwd -P)"`, in both the
   `--project` and the discovery branch (today `_FROM` exists only in discovery). The
   header's list of `ACTIVE_PROJECT_*` gains it. No type knowledge.
2. **The route.** `_rc_route` prints `tool` when `[ -e "$(_rc_root)/.repos-manifest" ]`,
   else `manifest` when `source` is set, else `bootstrap`. The helpers that test
   `ACTIVE_PROJECT_SOURCE` themselves (`_rc_manifest_dir`, `_rc_pin_manifest_dir`,
   `_rc_require_manifest`, `_rc_distro`) ask `_rc_route` instead, so a tool root with a stray
   `source` is on the tool route (and `validate` names the `source`). A `.repos-manifest/`
   the adapter cannot use is an error naming the next step, never another route.
3. **The distro rule, in one place.** `_rc_tool_distro_select` (new, tool route only) sets
   `_RC_TOOL_DISTRO`. The distros are the directories `resolved/<d>/` holding `layers.txt`
   (the tool's stated output; `config.yaml` is not read). Refused first: `resolved/layers.txt`
   directly (a flat system: "set up with `--distro-dirs`; move this one aside and run `init`
   again"). Then: (1) `ACTIVE_PROJECT_FROM` is `$(cd <root>/<d> && pwd -P)` or below it: `d`
   (both sides physical, so a registered path through a link still matches; finding 7);
   (2) else exactly one distro: that one; (3) else refuse, listing them; none at all:
   "nothing resolved yet: run `.agent/scripts/adapter --project <name> setup`". The name must
   match today's `^[a-z0-9_]+$` (it is `/opt/ros/<d>`). `_rc_require_manifest` runs it (every
   verb but `setup`/`sync` calls that first, outside a subshell); `_rc_distro`'s tool branch
   prints `_RC_TOOL_DISTRO`. Every verb follows the rule, `validate` included.
4. **Path helpers on the tool route.** `_rc_manifest_dir` → `<root>/.repos-manifest/resolved/<d>`.
   New `_rc_repos_file <layer>` → `$mdir/<layer>.repos` (tool) or `$mdir/repos/<layer>.repos`
   (both older routes); it replaces the spelled-out path in `adapter_setup`, `adapter_sync`,
   `adapter_validate`, `adapter_repo_pin` and `_rc_validate_manifest_route`.
   `_rc_layer_dir <layer>` → `<root>/<d>/<layer>`, and `<root>/<d>` for `_unnamed`.
   `_rc_is_optional_layer` → false (the tool has no optional layers); new
   `_rc_is_optional_repo <key>` reads `optional.txt`. `_rc_pin_manifest_dir` → nothing to pin
   (the tool replaces `resolved/<d>/` whole by rename; no lock, see Risks).
   `_rc_require_manifest` → its messages name the tool: no `resolved/` distro → `adapter setup`
   (which runs `repos-manifest sync`). It also refuses, by name, a repo key with `/` in any
   resolved `.repos` file (see "Layers").
5. **`setup` and `sync`.** On the tool route both run `_rc_tool_sync` and nothing else: the
   resolver binary check (`_rc_resolver_bin`, "run `make install-repos-manifest`"), then
   `(cd <root> && _rc_nofd <bin> sync --distro <d>)`, or `sync` with no `--distro` when
   nothing is resolved yet (an `init` cut short), refusing for several distros and no choice
   as in step 3. The tool's output and exit status pass through (0; 1 for a failed
   non-optional repo or any refusal; 128+n on a signal). The adapter adds no pull, fetch or
   `vcs`. When `layers.txt` differs before and after, `sync` prints today's "existing package
   worktrees keep their old env.sh; recreate them". A root with no `.repos-manifest/`, no
   `source` and no bootstrap URL is today's bootstrap refusal; its message gains one line:
   "Or set the root up with the manifest tool: in <root>, run `<bin> init <manifest>
   --distro-dirs --distro <distro> [--role <role>]`, then register it".
6. **`build` and `test`.** Unchanged loops over the routed layers. On the tool route colcon
   also gets `--base-paths src`, placed before `--cmake-args` (which takes the rest), so the
   unnamed layer, built in `<root>/<d>`, does not take in the named layers below it. The
   header says `build` is interim until `repos-manifest build`, and that it stops at the
   first failing layer (finding 8; the by-hand steps below use `--continue-on-error`).
7. **`validate` on the tool route.** `_rc_require_manifest` and the distro rule; then per
   layer: its `.repos` file must exist; every key in it that `optional.txt` does not name must
   be a directory `<layer dir>/src/<key>`. It fails, naming the fix, on a second record:
   `role=` or `distro=` on the registry line, or `source`, `source_ref`, `source_path` or
   `bootstrap_url` in the settings file (`project_setting.sh unset <name> <keys>`). Success:
   "✅ ros2_colcon checkout matches the tool's last resolve for distro <d>
   (.repos-manifest/resolved/<d>); the manifest itself was not read again (there is no
   `repos-manifest status` yet)".
8. **`env`, `repos`, `repo_pin`, `worktree_repos`:** no code change; they read the routed
   helpers. The pin is the `version` in `resolved/<d>/<layer>.repos`, never `state.yaml`.
9. **`worktree_env` names a lower layer that is not built** (finding 5, every route): in its
   loop over the layers below the target, a layer whose `install/` directory is missing gets
   one line on stderr, "NOTE: layer <l> is not built (<dir>/install missing); this worktree's
   build will not find its packages until it is". stdout, which `worktree_create.sh` writes
   into `env.sh`, is unchanged, so every `assert_eq` on it holds.
10. **Registration.** `register_project.sh` line 623 becomes
    `elif [ -d "$PROJECT_ROOT/configs/manifest" ] || [ -e "$PROJECT_ROOT/.repos-manifest" ] || set_value bootstrap_url ...`,
    and its header (lines 32–36) says so. `registration.conf` keeps its values; its comment
    says a tool root exists already, so registration runs no `setup`.
11. **`worktree_create.sh`: a project root need not be a git repository** (finding 1,
    generic). Lines 545–549 refuse only a root that is not a directory. After the manifest
    is resolved (`REPO_LINES`, before line 755 and so before any directory is made), each
    origin it names must be a git repository: for a `.` entry (the root itself: every
    single-repository project; a skill worktree is refused earlier, at line 698, with its own message) today's message, "Error: project
    checkout is not a git repository: <root>" and its second line; for any other entry
    today's line-868 message "manifest entry is not a git repository: <origin>". Line 868
    stays. A single-repository project is guarded as before: its one entry is its root.
12. **`/start-task` step 1 accepts a root in no git repository** (finding 1, generic). When
    `git rev-parse --git-dir` fails, the step runs `$WS_ROOT/.agent/scripts/session_root.sh`
    (no arguments) and goes on as "the main tree" when it exits 0; otherwise it stops with
    "Not in a git repository, and not a registered project root (above). /start-task runs
    from the workspace checkout or a registered project root." `session_root.sh` accepts a
    directory in no git repository only when it is a registered root itself, and refuses a
    subdirectory of one (`test_session_root.sh` covers both), so a package worktree's top
    folder under such a root is refused with the rest of its subdirectories. A directory in a
    git repository takes today's branch unchanged. The step's heading and "Manual verification"
    gain the case (check 6: a session at a registered root in no git repository).
13. **Headers.** `adapter.sh`'s header: three routes in order, the tool route's layout, the
    distro rule (stated there once; the design documents point at it), interim `build`.

## A project root in no git repository: every place on the path

From `/run-issue owner/repo#N --layer L --package-repos R` in a session at the root to the
merged pull request. "Works" means read in the code and, where noted, run here.

| Place | What it does today for a root in no git repository | Part 1 |
|---|---|---|
| run-issue "This session's root": `session_root.sh` | accepts the root itself (`[[ -z $S_REPO && $DIR != $S_ROOT ]]` refuses only a subdirectory) | none |
| run-issue: `skill_prefix.sh` | `agent-workspace:` (dir not in the workspace's repository) | none |
| run-issue step 1: `dispatch_phase.sh base` | `ROOT_DIR` from the script's own checkout; project from the cwd by registry prefix; `adapter worktree_repos`, `_pr_base.sh` → `adapter repo_pin` | none (the adapter routes) |
| start-task step 1 | `git rev-parse --git-dir` fails: stops, "Not in a git repository" | relaxed (step 12) |
| start-task step 2a: `session_root.sh --type project` | works, as above | none |
| start-task step 3: `worktree_enter.sh --print-path` | refuses the creation flags, so creation runs; on re-entry finds the worktree by its `.worktree-repos` header (the `git rev-parse --show-toplevel` fallback at line 268 fails quietly) | none |
| `worktree_create.sh` 545–549 | refuses: "project checkout is not a git repository" | relaxed (step 11) |
| `worktree_create.sh` 553–605 (slug) | `git -C <root> remote get-url` fails quietly: the slug is the registry name; `PROJECT_GH_SLUG` empty, used only by `--plan-file`, which a package worktree refuses (1145) | none |
| `worktree_create.sh` 698 (skill worktree) | refuses, "not the top of one": a skill worktree is of the root's own repository | none (stays refused) |
| `wt_ensure_exclusion` | skips the git exclude when the root is no repository (line 171 guard) | none |
| `worktree_create.sh` 861–913, hook preflight 1333–1352 | per entry: each clone is a repository, checked at 868 | none |
| `worktree_create.sh` 788 `cd "$ROOT_DIR"` before `worktree_env` | `ROOT_DIR` is the workspace; one distro, so rule 2 (finding 6 for several) | none in part 1 |
| `dispatch_phase.sh` `where`, `next`, handoff | `ROOT_DIR` from the script's checkout; `resolve_worktree` by registry; `issue_checkout_of` reads `.worktree-repos`; `gh repo view` in the owning checkout | none |
| `_resolve_work_plans_dir.sh`, `progress_append.sh`, `review_progress.sh persist` | resolve from the cwd's `git rev-parse --show-toplevel`, which is the owning checkout because every phase starts its chains with `cd <worktree>` (`progress_append.sh` alone also takes `-C`); the timeline is `<wt>/<L>_ws/src/<R>/.agent/work-plans/issue-<N>/`; `records_path` finds the enclosing `.worktree-repos`. A chain that lost its `cd` runs at the root and fails loudly, outside git | none |
| `set_git_identity_env.sh` | `git config user.email` in the cwd; outside a repository it reads the global and system files (run here in a directory outside git: the global address, `+claude-code` added). Sourced in the owning checkout for every dispatch, entry and commit; at the root only for step 11 or `gh_create_issue.sh`, where no clone-level address could apply | none |
| run-issue step 2 PR probe, step 8 `check_branch_updates.sh`, step 7 `git push` | run in `<dir>`, the owning checkout | none |
| `gh_create_pr.sh -R owner/repo --base <b>` | `REPO_ROOT` is the owning checkout; `registry_require_root` passes (cwd under the registered root by path); `-R` skips the repo-safety check | none |
| step 11: `cd <root>`, `merge_pr.sh --pr owner/repo#M` | `ROOT_DIR` from the script's checkout; `registry_require_root` passes at the root; a qualified `--pr` skips the project-root lookup (the `PJ_REPO_ROOT/.git` guards are not reached); the package path finds the worktree in the registry's worktree dirs, fast-forwards the owning clone (below), then `cd "$ROOT_DIR"` and `worktree_remove.sh`; the generic Step 6 `git pull` in the cwd is on the other branch | none |
| `worktree_remove.sh` | owners from each entry's own git dir; removes the container with `rm -rf` | none |
| Hooks on a session's tool calls | user tier: `PreToolUse` `log-tool-use.sh` (no git), `SessionStart` `session_start_project_layer.sh` (`git rev-parse` only on the workspace branch; prints the plugin names here). `.agent/hooks/*` are the workspace repository's pre-commit hooks, not run in a package repository's commits | none |

Found beyond the Plan Review: `merge_pr.sh`'s package path already updates the root's clone
after a merge. It fast-forwards `<root>/<d>/<L>/src/<R>` from `origin/<base>` when that clone
is clean and on the pull request's base branch (where `vcs import` leaves a clone whose pin is
a branch), and otherwise fetches only and says why in its last line. So finding 3's by-hand
step is the rebuild of that layer, plus a `git pull` only when the merge said "fetched only".

## Verbs

| Verb | Today | Tool route, part 1 | Later |
|---|---|---|---|
| `setup` | bootstrap or fetch and resolve, then `vcs import` per layer | `repos-manifest sync --distro <d>` in the root; no `--distro` when nothing is resolved yet | part 2: `init`; part 3: `add-distro` |
| `sync` | fetch and resolve (manifest route), then pull or fetch each clone | as `setup`; never pulls | part 4: the tool updates existing clones |
| `build` | `colcon build` per layer, in order | the same loop over `resolved/<d>/layers.txt`, `--base-paths src`; interim | part 4: `repos-manifest build` |
| `test` | `colcon test` per layer | the same loop, `--base-paths src` | stays in the adapter |
| `validate` | checkouts against the manifest; route checks | checkouts against the last resolve; refuses a second record | part 4: `repos-manifest status` |
| `env` | underlay, then each built layer | the same, from `<root>/<d>/<layer>/install` | part 4: may source the tool's `setup.bash` |
| `repos`, `repo_pin` | from `layers/main`, `repos/<l>.repos` | from `<root>/<d>`, `resolved/<d>/<l>.repos` | unchanged |
| `worktree_repos`, `worktree_env` | from the layer dirs | the same, routed; `worktree_env` names an unbuilt lower layer on stderr (all routes) | part 3: the worktree's distro in its header |

## Layers and the unnamed layer

`layers.txt` lists the layers in build order, the unnamed one as `_unnamed`. The adapter's
"layer directory" is where colcon runs and `install/` lands: `<root>/<d>/<layer>`, and
`<root>/<d>` for `_unnamed`. The worktree's own layout stays `<wt>/<layer>_ws/src/<key>`. On
the tool route no layer is optional; `validate` passes over a missing repo that
`optional.txt` names. A key with a directory in it (`grp/repo`) is refused by name in part 1:
`_rc_repos_entries` would skip it, `repos` lists one level down, and `worktree_create.sh`
names the owning repo by `basename`. The owner's manifest has none, and no unnamed layer.

## The package worktree on the tool route

`adapter worktree_repos` checks `<l>` against `resolved/<d>/layers.txt` and
`<root>/<d>/<l>/src/<a>`; `pr_base_for` → `repo_pin` reads `resolved/<d>/<l>.repos` and asks
the clone's origin for the kind. The worktree is `<root>/worktrees/issue-<name>-<owner>-<repo>-<N>/`,
outside every distro directory, with `COLCON_IGNORE` in `worktrees/`. `env.sh` sources
`/opt/ros/<d>/setup.bash`, each lower layer's `<root>/<d>/<lower>/install/local_setup.bash`
(guarded), `<root>/<d>/<l>/install/local_setup.bash`, then the worktree's own. A lower layer
not built is named at creation (step 9); its symptom later is CMake's "Could not find a
package configuration file provided by <pkg>". One worktree holds one layer and one owning
repository: a port across layers is one issue per repository (acceptance, below).

## Tests (no network)

Fixtures follow `test_ros2_colcon.sh`'s manifest-route ones (stub toolchain, `make_underlay`,
`mr_test` skipping loudly without PyYAML): a new-format manifest (distros `[fakefox,
fakefox2]`, layers `core`, `extra`, one unnamed-layer repo, one optional repo) resolved with
this checkout's `repos-manifest resolve --role dev --distro fakefox --out
<root>/.repos-manifest/resolved/fakefox`; `setup`/`sync` use a stub `.venv/bin/repos-manifest`
recording cwd, arguments and exit status.

**Where the tool root sits (finding 2).** Every suite makes one `SANDBOX="$(mktemp -d)"` at
top level and carves per-test directories from it with `mktemp -d -p "$SANDBOX"`. `mktemp -d`
uses `$TMPDIR`, else `/tmp`: here `TMPDIR` is unset and `/tmp` is a tmpfs in no repository
(checked: `git rev-parse` there stops at the filesystem boundary); in CI the job runs on
`ubuntu-latest` with no `TMPDIR` set and the checkout under the runner's work directory, so
`/tmp` is outside it too. `make_sandbox` makes no repository; `make_worktree_sandbox` runs
`git init` in `$sb`, and today's projects sit in `$sb/projects/<name>`, inside it. So the tool
root is a sibling of the sandbox, never under it: `root="$(mktemp -d -p "$SANDBOX")/p11"`,
registered as `p11 ros2_colcon <absolute root>` in `$sb/.agent/projects.local`, with its
clones' `fake_remotes/github.com/` in `$(dirname "$root")` (the `fakessh` stub looks upward
from git's cwd). Each tool-route test first asserts `! git -C "$root" rev-parse --git-dir`, so
a `TMPDIR` inside a repository fails the test instead of hiding the case. The same in
`test_register_project.sh` (`make_proj`-style `$(mktemp -d -p "$SANDBOX")/<name>`, no `git
init`).

New `test_tool_*` functions in `test_ros2_colcon.sh`:
- route: `.repos-manifest/` beats `source` and bootstrap; a root with `.repos-manifest/` but no
  `resolved/` (and a flat one) errors naming the step, with no curl call and no `configs/`
  made, for `setup`, `validate`, `env` and `build`;
- distro rule: `--from <root>/fakefox/core/src` → fakefox; the same through a symlinked
  registered path; one distro from the workspace → it; two from the root → refused listing
  both; from `<root>/fakefox2` → fakefox2;
- per verb: `env` (order); `setup`/`sync` (cwd = root, `sync --distro fakefox`, status 0/1/130
  passed through, no `vcs` call, a clone behind origin left where it was, the layers-changed
  line); `build`/`test` (colcon in `<root>/fakefox/core` then `extra`, unnamed in
  `<root>/fakefox`, `--base-paths src` before `--cmake-args`); `validate` (pass line; a missing
  repo fails; a missing optional one passes; each second record named); `repos`; `repo_pin`;
  a key with `/` refused by name;
- `worktree_env`'s note: a lower layer with no `install/` is named on stderr, a built one is
  not, stdout identical to today's;
- **`test_tool_package_worktree`**, through `worktree_create.sh` on the root outside git: exit
  0, base from the resolved pin, `env.sh` lines in order. Without step 11 it fails: line 545
  exits 1 with "Error: project checkout is not a git repository: <root>", because the root is
  in no repository (the sandbox's `git init` is not above it), so neither the exit status nor
  `env.sh` assertion holds;
- after #500 merges, one test running the real `init --yes` and `sync` on local `file://`
  repositories, then `adapter validate`, skipped loudly when `vcs` is absent.

`test_worktree_create.sh`: a registered `single_project` root outside git (sibling of the
sandbox workspace) still refuses with "project checkout is not a git repository: <root>" and
makes no `<root>/worktrees/`: passes before and after, and guards step 11's single-repository
case. `test_register_project.sh`: type detected from `.repos-manifest/`, gate passes, line has
no `role=`/`distro=`, root outside git. `test_register_session_root.sh`: a tool root outside
git registers from its own session (the design sentence below depends on it; today's
"not a git repository" case for a plain folder stays). At the end, run unchanged:
`test_ros2_colcon.sh`, `test_adapter.sh`, `validate_adapter.sh`, `test_register_project.sh`,
`test_register_session_root.sh`, `test_worktree_create.sh`, `test_dispatch_phase.sh`,
`test_session_root.sh`, `test_user_tier_guard.sh`, `test_skill_paths.sh` (start-task's new
lines use `$WS_ROOT`), and check `git diff main -- .agent/scripts/tests` removes or changes no
line.

## Documents in the same pull request

- `docs/manifest/design.md`: "two routes … chosen by one fact" → three routes in order, with a
  "The tool route" subsection (what it reads, the distro rule by reference to the adapter
  header, `setup`/`sync` run `repos-manifest sync`, interim `build`, what `validate` checks and
  says, `<root>/<d>/setup.bash` being the tool's stub so the environment is `adapter env`, flat
  and `/` keys refused); "Worktrees": layers at `<root>/<d>/<layer>/`; the route-order
  paragraph: until `status` is built the test is the folder being there, and a folder the
  adapter or the tool cannot use is an error naming the next step, never another route;
  "Nothing in this section is built" → "…except the first cut, under What exists today";
  "How a session says which is not decided yet" → the directory rule, sessions at the root
  until part 3; "What the workspace records": no `role=`, `distro=` or `source` on a tool
  instance, refused by `validate`.
- `docs/manifest/roadmap.md`: new line "The adapter reads an instance in the tool's layout,
  its distro from the calling directory (#503 part 1)" with check `file-contains
  .agent/project_types/ros2_colcon/adapter.sh .repos-manifest/resolved`; "A worktree of a
  package repo builds against an instance in the tool's layout" stays unchecked until the
  owner's acceptance is recorded on #503.
- `docs/design.md#registry-and-adapters`: three routes; `.repos-manifest/resolved/<distro>/`
  beside `configs/manifest`; the calling directory on the tool route; `ACTIVE_PROJECT_FROM`;
  "Registration needs a git repository today (`adapter validate`) … a folder in no git
  repository is refused and rolled back, a named gap" → "A `single_project` folder needs a git
  repository (`adapter validate`); a `ros2_colcon` root does not, from the workspace or from
  its own session"; the same correction in `docs/design.md#sessions-and-roots`, whose
  onboarding bullet says "a folder in no git repository is refused by registration's gate, a
  known gap". `docs/design.md#worktrees` gains one sentence: a project root need not be a git
  repository; each repository a worktree is made of must be. A change-log row with the line
  counts.
- `.agent/WORKTREE_GUIDE.md` "Package Worktrees": the same flags on a tool root; the
  environment is `adapter env`, not the tool's stub `setup.bash`; after a package pull request
  merges, `merge_pr.sh` fast-forwards the root's clone when it is clean and on the base (else
  it says "fetched only": then `git -C <clone> pull`), and the layer is rebuilt by hand until
  the tool builds; a port across several layers is one issue per repository, bottom-up.
- `.claude/skills/start-task/SKILL.md` step 1 (step 12 above).

## Acceptance (owner's machine, after #500 part 1 and this PR merge)

1. `cd ~/agent_workspace && git pull && make install-repos-manifest && vcs --version`.
2. `mkdir ~/project11 && cd ~/project11 && cp <his manifest> ./project11.manifest.yaml`.
3. `~/agent_workspace/.venv/bin/repos-manifest init ./project11.manifest.yaml --distro-dirs --distro rolling --role simulator`.
4. `cd ~/agent_workspace && .agent/scripts/register_project.sh ~/project11 --name project11`:
   type `ros2_colcon` detected, `VERIFY=pass`.
5. `.agent/scripts/adapter --project project11 validate` (the ✅ line for rolling), then
   `... sync` (the tool's "present, not touched (N)").
6. Build by hand while ports fail (#415), each layer in order, in one shell:
   `source /opt/ros/rolling/setup.bash`, then for `underlay`, `core`, … :
   `cd ~/project11/rolling/<layer> && colcon build --symlink-install --base-paths src --continue-on-error && source install/local_setup.bash`
   (plus any `--packages-skip` #415 names). `adapter build` stops at the first failing layer.
   Not `rolling/setup.bash`: the tool's stub until its `build`.
7. `cd ~/project11 && claude`, then the port, worked as below.

**The recommended way to work the Rolling port with this first cut** (for the owner to
confirm): one issue per repository, in that repository's own tracker, each saying "Part of
rolker/unh_marine_autonomy#415"; #415 stays the tracker and lists them. Each is run with its
own `--layer` and `--package-repos`, bottom-up by layer (`underlay`, `core`, `platforms`,
`site`, `sensors`, `simulation`, `ui`; within a layer, a repository others depend on first).
Each branch and pull request base is that repository's pin (`jazzy` for most). After a
lower-layer pull request merges, `merge_pr.sh` fast-forwards the root's clone (or says
"fetched only": `git -C <clone> pull`), and that layer is rebuilt as in step 6 before the
next upper-layer worktree builds against it. #415 lists no underlay repository as needing a
change, so the lowest layer to port is `core`. The first two, from the session at
`~/project11`:

```
WS="$(cat ~/.claude/agent-workspace-root)"
"$WS/.agent/scripts/gh_create_issue.sh" -R rolker/marine_control --title "Port to Rolling: replace ament_target_dependencies" --body-file <file saying "Part of rolker/unh_marine_autonomy#415">
"$WS/.agent/scripts/gh_create_issue.sh" -R rolker/manda_coverage --title "Port to Rolling: replace ament_target_dependencies" --body-file <same>
/agent-workspace:run-issue rolker/marine_control#<M1> --layer core --package-repos marine_control
/agent-workspace:run-issue rolker/manda_coverage#<M2> --layer core --package-repos manda_coverage
```

Each makes `~/project11/worktrees/issue-project11-rolker-<repo>-<M>/`, its branch from
`origin/jazzy`, its `build.sh` building `core_ws` against `~/project11/rolling/{underlay,core}/install`,
and its pull request against `jazzy`. By hand because later parts are not built: step 3
(part 2), step 6 (part 4), the rebuild after a merge (part 4). Sessions start at the root,
not `rolling/`, until part 3.

## Files to Change

| File | Change |
|---|---|
| `.agent/project_types/ros2_colcon/adapter.sh` | route, distro rule, helpers, `setup`/`sync`/`validate` tool branches, `--base-paths src`, `worktree_env` note, header |
| `.agent/project_types/ros2_colcon/registration.conf` | comment only |
| `.agent/scripts/adapter` | `ACTIVE_PROJECT_FROM`, header |
| `.agent/scripts/register_project.sh` | type detection line 623, header lines 32–36 |
| `.agent/scripts/worktree_create.sh` | lines 545–549 and the origin check before any directory is made (step 11) |
| `.claude/skills/start-task/SKILL.md` | step 1 and Manual verification (step 12) |
| `.agent/scripts/tests/test_ros2_colcon.sh`, `test_register_project.sh`, `test_worktree_create.sh`, `test_register_session_root.sh` | new tests only |
| `docs/manifest/design.md`, `docs/manifest/roadmap.md`, `docs/design.md`, `.agent/WORKTREE_GUIDE.md` | as above |
| `AGENTS.md` (separate last commit, only on the owner's yes) | line 11: "A hosting service is optional; git is meant to be, but registration still needs it." → "A hosting service is optional; git is meant to be, and today only a single-repository project's own folder needs it." One line replaced by one: the file stays at 200 lines, within `agents-md-line-budget`. Without his yes, the PR names the sentence as stale |

## Prior Art

Reused: the adapter's own loops, `_rc_resolver_bin`, `_rc_nofd`, the manifest-route fixtures;
`session_root.sh`'s existing acceptance of a root in no git repository (start-task asks it
rather than restating the rule); `worktree_create.sh`'s per-entry check at line 868 (the new
check runs the same test earlier); `merge_pr.sh`'s fast-forward of a package's clone; the
tool's stated output and its cwd rule (`distros_for`), whose step 3 differs because an adapter
verb acts on one distro. Rejected: one registry instance per distro directory (the owner chose
one registration); reading `config.yaml` or `state.yaml` (ADR-0022); making `~/project11` a git
repository (it would hold the clones as nested repositories and change nothing the scripts
need).

## Serves

Easy to use and Modular (`README.md#workspace-goals`); `docs/design.md#registry-and-adapters`,
`docs/manifest/design.md#a-project-instance-is-a-system-directory`.

## Design Picture

Changes: a third route in `docs/design.md#registry-and-adapters` and
`docs/manifest/design.md#what-exists-today`; the distro rule out of "Not decided"; a project
root need not be a git repository (registration of a `ros2_colcon` root, project worktrees),
in this PR.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Small steps | part 1 only; parts 2–4 outlined |
| Keep one current design | documents above change in the same PR |
| Only what's needed | no new verb, no `init` call, no distro record; two generic checks relaxed, each still refusing what it guards |
| Test what breaks | the tool root sits outside every repository, so the worktree test fails without step 11; today's assertions untouched |
| Put each thing at its level | distro rule in the adapter; no type name in `worktree_create.sh` or start-task |
| Verify before claiming | the owner's acceptance is recorded on #503 with the commands run |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0011 | Yes | no verb added; `validate_adapter.sh`, `test_adapter.sh` pass; no type name in generic scripts |
| 0012 | Yes | composition stays in `worktree_repos`/`worktree_env`; `worktree_create.sh` checks entries, not the root |
| 0016, 0018, 0020 | Yes | `session_root.sh` unchanged; start-task asks it; sessions at the root only (part 3 brings a superseding ADR for `<root>/<d>/`) |
| 0021 | Yes | a tool root outside git registers from the workspace or its own session; the named gap stays for a `single_project` folder |
| 0017, 0022 | Yes | design updated in the PR; only `resolved/` is read |

## Consequences

| If we change… | Also update… | Included? |
|---|---|---|
| `_rc_layer_dir`, `_rc_manifest_dir` | every caller listed in step 4 | Yes |
| type detection | `register_project.sh` header | Yes |
| a new `ACTIVE_PROJECT_*` | dispatcher header | Yes |
| `worktree_create.sh` root check | `docs/design.md` worktrees text, `WORKTREE_GUIDE.md` | Yes |
| start-task step 1 | its Manual verification list | Yes |
| `AGENTS.md` sentence | owner's approval | Asked; last commit only on yes |
| `script_reference.md` | no usage changes | No |

## Risks

- `resolved/<d>/` swapped by a concurrent `sync` between two reads of a run: low; no lock.
- A distro not named as a ROS distribution has no `/opt/ros/<d>`: `_rc_underlay`'s error.
- The tool's `<root>/<d>/setup.bash` returns 1 until its `build`; documented.
- `merge_pr.sh`'s fast-forward moves the clone past what the tool's `state.yaml` recorded, as
  a hand `git pull` does; the tool's `sync` part 1 does not touch a repo that is there.

## Owner's decisions

- 2026-11-18, which distro a call uses: "yes, the directory the session is started in decides."
- 2026-11-18, a session in `<root>/<distro>/`: "yes, starting at ~/project11 is fine for the
  first cut". Part 3 brings that, with a decision superseding that part of ADR-0020.

## Open Questions for the owner

- The `AGENTS.md` sentence (Files to Change): yes or no.
- The port's working pattern (Acceptance): confirm one issue per repository, bottom-up.

## Part 4 (revised 2026-11-23): the adapter calls the tool's `status` and `build`

Parts 1A and 1B are merged (pull requests 513 and 514). This part is the next pull request;
its body says `Part of #503`, because parts 2 and 3 remain. Everything below is the tool route
only: the `source` manifest route and the bootstrap route are not touched (their tests, in
`test_ros2_colcon.sh`, must pass unchanged), and the adapter's own fetch code is not removed
here (it serves those two routes; the Direction line for its removal stays false).

What is there now (read on this branch): `_rc_tool_sync` (adapter.sh:1004) already runs
`repos-manifest sync [--distro <d>]` in the root for both `setup` and `sync`, passing output and
exit status through, so those two verbs need no new code. `_rc_tool_validate` (:1035) compares
`<layer dir>/src/<key>` directories with `resolved/<d>/<layer>.repos` and its success line says
"the adapter does not call repos-manifest status yet". `adapter_build` (:1851) and
`adapter_test` (:1883) run the colcon loop over `layers.txt` with `--base-paths src` on the tool
route too. The tool side, verified in `tools/repos-manifest/src/repos_manifest/status.py`,
`build.py`, `cli.py` and its `docs/design.md` ("build", "status"):

- `status [--distro d]... [--json]` reads only, makes no network call, resolves the manifest in
  memory from where `config.yaml` points (so it also reads the manifest itself, which the old
  validate did not), exits 1 when a repo that is not optional is `missing`, `not-a-directory`,
  `blocked-place`, `in-other-layer` or `unusable`, or a distro `problem` is set, or the system
  directory cannot be found or read (then no document); `format` is 1.
- `build [--distro d] [--keep-going] [<layer> ...] [-- <colcon args>]` runs the layers in order
  in `<root>/<d>` (unnamed) and `<root>/<d>/<layer>`, gives colcon the repos on disk as
  `--base-paths`, refuses `--base-paths`, `--paths`, `--install-base`, `--build-base` after `--`,
  keeps a record `.repos-manifest/built-<d>.yaml`, writes `<root>/<d>/setup.bash`, builds in the
  environment it is run in, and exits 1 on any failure.

### Steps

1. **A status helper** (`adapter.sh`, tool-route section). `_rc_tool_status <distro>`: runs
   `(cd <root> && _rc_nofd <bin> status --distro <d> --json)` with stdout to a temporary file
   under the call's own temporary directory and stderr passed through, keeps the exit status, and
   parses the document with the tool's own interpreter (`$(dirname <bin>)/python`, the venv the
   tool is installed in; refused with the `make install-repos-manifest` hint when it is not
   executable). The parser is a short inline Python program (standard library only, `-I`) that
   prints one tab-separated line per item: a header (`ok`, `problem`), then per repo
   `layer key state optional path detail`, then each `not_in_manifest` path. Tabs and newlines in
   detail are replaced by a space in the parser. No `jq` is needed. A document with `format`
   other than 1, or that is not one JSON object, is a failure that says so.
2. **validate on the tool route** (`_rc_tool_validate`), per covered distro. It keeps: the
   distro rule (`_rc_tool_distro_select --every`), the second-record failures (registry
   `role=`/`distro=`, settings `source`, `source_ref`, `source_path`, `bootstrap_url`) and the
   leftover-`configs/` note, because those are the workspace's own records, not the tool's;
   `_rc_check_manifest` (layers.txt non-empty, layer-name charset, unreadable key lines), because
   `env`, `repos`, `repo_pin` and the worktree verbs read the resolved files and must be able to
   read them; and, per layer, the `.repos` file being there. It drops the per-repo
   `[ -d <layer dir>/src/<key> ]` loop: `status` answers that, and more. Then it calls
   `_rc_tool_status` and maps (next section). One more check of its own: the set of
   `(layer, key)` pairs `status` names against the keys in `resolved/<d>/*.repos`; a difference
   means the last resolve is out of date (a manifest change `sync` has not resolved), reported
   as a warning with the tool's `sync` step, not a failure (decision 4).
3. **build on the tool route** (`adapter_build`): `_rc_tool_distro_select` (the distro rule; a
   refusal as today), `_rc_underlay`, `unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH
   CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX`, `_rc_source_setup <underlay>` (the distro's
   environment sourced first, in the adapter's shell, as the issue says and as
   `docs/manifest/design.md` "What stays in the workspace" says), then
   `cd <root> && <bin> build --distro <d> -- --symlink-install --cmake-args
   -DCMAKE_EXPORT_COMPILE_COMMANDS=ON "$@"`, output and exit status passed through, nothing
   printed by the adapter after it (the tool's report is the report). The adapter's own colcon
   flags are the same as today and move after `--`; the caller's extra arguments follow them as
   today, so they reach every layer. `_rc_check_manifest` is not run for build (the tool reads
   the resolved files itself), so a nested key (`grp/repo`) no longer stops a build; it still
   stops `validate`, `repos` and worktrees until a later part reads such keys. The adapter's
   per-layer sourcing and "Skipping layer" loop is not used on this route. Building one layer
   is the tool's own `cd <root> && <bin> build <layer>`; the adapter takes no layer argument
   (decision 2).
4. **test on the tool route**: stays the adapter's colcon loop (the tool has no `test`). One
   change so it agrees with `build`: the layer's `--base-paths` is the list of
   `src/<key>` directories of the keys in `resolved/<d>/<layer>.repos` that are on disk (what
   the tool gives colcon), not all of `src`, so a clone still on disk that the role or groups
   no longer keep is not tested. `_rc_colcon` takes the paths from `_rc_repos_entries`
   (decision 3). `env` is unchanged: it still sources each built layer's `install/local_setup.bash`,
   which the tool's colcon writes in the same directories.
5. **sync and setup**: no new code. Fix what became wrong: the comment at adapter.sh:1924 ("it
   pulls and fetches nothing") and the header's "moves no clone" paragraph (lines 85 to 98:
   the adapter moves none, the tool updates clean clones, and `build` now writes
   `<root>/<d>/setup.bash`); `docs/manifest/design.md` lines 168 to 177 and 207 to 213 ("rebuilt
   by hand until the tool builds", "interim until the tool's own build", "`setup.bash` is its
   stub"); the test for "never pulls" wording, if any, in `test_tool_setup_and_sync_run_the_tool`.
   One stale line is the tool's, not the adapter's: `cli.py:367` says sync leaves repos that are
   there "not touched yet", false since #535; corrected in this pull request, one line, with
   the tool's own suite untouched (decision 5).
6. **Documents** (same pull request): `docs/manifest/design.md`: "The tool route" verbs
   (`build`, `validate`, `sync`) and the lines that say the adapter does not call `status` (185,
   314, 340), the "What is built" and "not built yet" lines; the design-picture target table
   stays. `docs/manifest/roadmap.md` (below). `tools/repos-manifest/docs/design.md` line 1702
   ("The workspace's `validate` does not run `status` yet") now true: reworded. The adapter
   header comment. Knowledge files: `.agent/knowledge/build_and_test.md` names the adapter's
   verbs for a `ros2_colcon` project (line 16): checked, edited only if it describes `build`
   as a colcon loop. `script_reference.md` lists scripts, not adapter verbs: no change expected.

### Status to validate

Per distro, from the JSON and the exit status (the exit status decides; the document explains):

| Status says | validate says |
|---|---|
| exit 0, every repo `expected` | one pass line per distro: `✅ ros2_colcon distro <d>: <N> repos at their place, read against the manifest by repos-manifest status (E expected, S skipped optional)` |
| `different`, `left-alone` (a link, a rebase, an index.lock, a sparse checkout, several origin urls) | a warning on stderr per repo, `⚠️ distro <d>: <path> <state>: <detail>`; the exit status stays 0, as the tool's design says |
| `skipped` (optional, not there) | counted in the pass line, not listed |
| `not_in_manifest` entries | a warning per path: recorded by sync, still on disk, no longer in the manifest |
| exit 1, a repo that is not optional `missing` | `❌ distro <d>: <path> missing: <detail> (run: <sync step>)`; counts one issue |
| exit 1, `not-a-directory`, `blocked-place`, `in-other-layer`, `unusable` (not a git clone, no commit, no origin url, version not in the refs of the last fetch, `git status` fails) | `❌ distro <d>: <path> <state>: <detail>`, the tool's text unchanged |
| the same states for an optional repo | the warning form; no failure |
| a distro's `problem` (manifest unreadable or unresolvable) | `❌ distro <d> cannot be read or resolved: <problem>` |
| exit 1 and no document (no system directory, a `--distro` not recorded) | the tool's stderr passed through, then `❌ repos-manifest status gave no document (exit 1)` |
| exit 2 (bad option), exit 128+n, output that is not format 1 | `❌` naming the exit status or format, tool stderr passed through |
| exit 0 but the document has a failing non-optional repo or `ok: false`, or exit 1 and the document has none | `❌ status's document and its exit status disagree`; a failure, so a change in the tool's contract is seen |

Validate exits 1 when any distro fails (own checks included), naming each failing distro as now;
0 otherwise. It no longer says it did not read the manifest: `status` reads it from where
`config.yaml` points, so the success line says what was checked and that clones are read as last
fetched, with no fetch.

Issue 517 (heads/ and tags/ versions read as unknown; an emptied clone passes validate):
item 2 is closed for the tool route only: an emptied directory, or one with its `.git` removed,
is `unusable` ("is not a git repository of its own", verified in `update.blocked_early`), so
validate fails, named, and a test pins it. The manifest and bootstrap routes' validate keeps the
weakness. Item 1 is left: `_rc_pin_kind` (the adapter's own `repo_pin` lookup) is not touched
by this part; the tool itself understands `heads/` and `tags/` (`update.py`), so the way to close
it for the tool route is `repo_pin` asking the tool, a later part.

### Tests (no network)

Suites: `.agent/scripts/tests/test_ros2_colcon.sh` (the stub tool, and one real-tool test that
runs in CI's "Validate Adapter Contract" job, where `vcs2l` is installed and
`ROS2_COLCON_TESTS_REQUIRE_VCS=1`); `.agent/scripts/tests/test_adapter.sh` and
`validate_adapter.sh` run unchanged as regression; the tool's own suite is not run for this
part unless step 5's `cli.py` line is changed (then its help-text test, if one asserts the old
words).
- Stub tool (`make_tool_root`'s `repos-manifest` stub): add `status` (prints the file named by
  `TOOL_STATUS_FILE`, exits `TOOL_EXIT`) and `build` (records cwd, arguments, the environment
  variable `SOURCED_UNDERLAY` the underlay's stub `setup.bash` sets, and exits `TOOL_EXIT`);
  the sandbox gets `.venv/bin/python` linking to the suite's `$MR_PY`. New and rewritten tests:
  `test_tool_validate` (rewritten: canned documents for each row of the table above, including
  the optional-repo warning forms, the disagreement case, the no-document case, `format: 2`,
  one distro of two failing and named, the second-record failures and leftover note kept);
  `test_tool_build_runs_the_tool` (rewrites the build half of
  `test_tool_build_and_test_over_the_resolved_layers`: arguments `build --distro fakefox --
  --symlink-install --cmake-args ...`, the underlay sourced before the call, exit status passed
  through, the distro rule refusal from the root with two distros, no `_rc_check_manifest`
  refusal for a nested key); the test half keeps its colcon-loop assertions and gains the
  `--base-paths src/<key>` list with a repo dropped from the `.repos` file but left on disk.
- Real tool (new `test_tool_real_status_and_build`, after `test_tool_real_init_and_sync`,
  same vcs skip/require rule): `init` and `sync` from local `file://` remotes as that test
  does, then `adapter validate` (exit 0, pass line), a clone emptied (`rm -rf` its contents,
  keep the directory) fails validate naming the repo as `unusable` (issue 517 item 2), a clone
  removed passes again after the adapter's `sync` clones it, a clone put on another branch warns
  and exits 0; `adapter build` with a stub `colcon` first on `PATH` that writes
  `install/setup.bash` and `install/local_setup.bash`, then `<root>/<d>/setup.bash` exists and
  `adapter env` still names each layer. The hand-written `config.yaml` of `make_tool_root`
  is not enough for the real `status` (`read_config` needs `distros` for a `distro-dirs`
  layout), which is why this test starts from a real `init`.
- Manifest and bootstrap routes: no new test; their existing tests are the check that nothing
  moved (the suite's pass count for them is quoted in the pull request).

### Direction lines (`docs/manifest/roadmap.md`)

- "The adapter's `setup`, `sync`, `build` and `validate` call the tool, and its own manifest
  fetch and generated directories are removed": this part makes the first half true for the tool
  route, not the second. Split it into two lines: "The adapter's `setup`, `sync`, `build` and
  `validate` call the tool's `sync`, `build` and `status` on the tool route (#503 parts 1 and 4)"
  with the check `file-contains .agent/project_types/ros2_colcon/adapter.sh status --distro` ;
  `file-contains .agent/project_types/ros2_colcon/adapter.sh build --distro`; and "The adapter's
  own manifest fetch and generated directories are removed" with no check (no
  `file-not-contains` kind exists; a check would have to be one added to `update_roadmap.sh`,
  out of scope).
- "A worktree of a package repo builds against an instance in the tool's layout": made true by
  part 1B; its check is empty and stays so (needs a real instance).
- "The tool has the commands the adapter calls": `add-distro` is still missing; no change.

### Decisions made (open to the owner's veto)

1. `status` is called once per covered distro with `--distro <d>`, and the exit status decides
   pass or fail, with the JSON used to name what failed. Undo: one call for all distros.
2. The adapter's `build` takes no layer argument and passes its extra arguments to colcon (after
   `--`, as today); one layer is built with the tool by hand. Undo: a leading `--layer <name>`.
3. The tool route's `test` limits colcon to the repos the resolved files list, as the tool's
   `build` does. Undo: keep `--base-paths src` (a clone kept on disk after a group is
   switched off is then tested).
4. A resolve out of date against `status`'s repo set is a validate warning, not a failure.
5. The one-line stale help text of `repos-manifest sync` is fixed in this pull request.
6. The JSON is read with the tool's own Python, not `jq` or the system `python3`.
7. validate keeps `_rc_check_manifest` and the `.repos`-file-present check, because the
   adapter's other verbs read those files.

### Owner questions

None that change what the work is for. (If the owner wants validate to fail on `different`,
that changes the tool's contract, `different` exits 0 by design, and is a design question for
the tool's own design, not this part.)

### Size

One pull request. About +110/-60 in `adapter.sh` (helper and parser ~80, build ~25, validate
rewrite net ~0, test paths ~20, comments), +1/-1 in `cli.py`, +330/-90 in `test_ros2_colcon.sh`,
+50/-20 in the documents. No split: the verbs share one helper and one stub.

### Could not verify (at planning time)

That the real `status` and `build` run against the suite's fixtures as the plan expects (no code
was run; the order in which the tool finds `colcon`, "on `PATH` and beside the Python", decides
whether the stub `colcon` is the one used); that `.venv/bin/python` exists in every machine's
installed venv (it does for an editable install by `pip` into a venv, which `make
install-repos-manifest` is by its description, not re-read here); the sizes.

## Later parts

- **Part 2:** registration passes the manifest's location, role, first distro and groups to
  `init`; `setup` runs `init` for a root not set up.
- **Part 3:** sessions in `<root>/<d>/` (superseding ADR-0020's refusal of a subdirectory of a
  root in no git repository); the session's distro carried into worktrees (`.worktree-repos`
  header). It must also make `worktree_create.sh`'s three adapter calls agree: `worktree_repos`
  and `pr_base_for` run from the caller's cwd, `worktree_env` after `cd "$ROOT_DIR"`, so with
  two distros a session in `<root>/<d2>/` would get d2, then a refusal (finding 6): pass
  `--from` or the recorded distro. `add-distro`; registering a root with several distros.
- **Part 4:** planned in full below ("Part 4"), the next pull request: `build` →
  `repos-manifest build`, `validate` → `repos-manifest status`, `sync` relies on the tool
  updating clones. Written 2026-11-23, after the tool's `build` (#518), `sync` updating clones
  (#535) and `status` (#546) merged.

## Dependencies, order, size

Merges after #500 part 1 (`init`, `sync`; local branch `feature/issue-500`, no PR yet); its
command line is checked against #500 as merged. Before that, all of part 1 can be built and
tested against main's `resolve`, with the stub tool. Size: one PR, about +175/−20 in
`adapter.sh`, +6 in the dispatcher, +3 in `register_project.sh`, +15/−4 in
`worktree_create.sh`, +14/−4 in start-task, +560 test lines (`test_ros2_colcon.sh` +480,
`test_register_project.sh` +40, `test_worktree_create.sh` +20, `test_register_session_root.sh`
+25), +90 document lines, and the one-line `AGENTS.md` commit if approved.
