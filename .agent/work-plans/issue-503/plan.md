# Plan: ros2_colcon adapter: call the manifest tool's commands, and register a project from a manifest

## Issue

https://github.com/rolker/agent_workspace/issues/503 (part 1 of 4: the first cut; the pull
request says "Part of #503")

## Context

The issue's text predates the owner's decisions of 2026-11-18. The Issue Review in
`progress.md` replaces its "What to build" and "Acceptance" for part 1, and the Checkpoint
after it binds this plan. Part 1 is the owner's first cut: a directory the tool set up
(`repos-manifest init --distro-dirs`) is registered as one `ros2_colcon` project; its
`setup` and `sync` call the tool's `sync`; building stays colcon per layer until the tool's
`build` lands; and a package worktree builds against the layers the owner built by hand.

Today every verb finds its files through a few helpers in
`.agent/project_types/ros2_colcon/adapter.sh`: `_rc_manifest_dir` (the directory holding
`layers.txt`), `$mdir/repos/<layer>.repos` (spelled out in `adapter_setup`, `adapter_sync`,
`adapter_validate`, `adapter_repo_pin`), and `_rc_layer_dir` (`layers/main/<layer>_ws`). The
tool's layout (`system.py` on `feature/issue-500`) is `<root>/<distro>/<layer>/src/<key>`,
the unnamed layer's repos in `<root>/<distro>/src/`, and the resolved output in
`<root>/.repos-manifest/resolved/<distro>/` as `layers.txt`, `<layer>.repos` and
`optional.txt` (optional repos by key). Part 1 is a third answer from those helpers; the
verbs above them stay as they are.

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
   again"). Then: (1) `ACTIVE_PROJECT_FROM` is `<root>/<d>` or below it: `d`; (2) else exactly
   one distro: that one; (3) else refuse, listing them; none at all: "nothing resolved yet:
   run `.agent/scripts/adapter --project <name> setup`". The name must match today's
   `^[a-z0-9_]+$` (it is `/opt/ros/<d>`). `_rc_require_manifest` runs it (every verb but
   `setup`/`sync` calls that first, outside a subshell); `_rc_distro`'s tool branch prints
   `_RC_TOOL_DISTRO`. Every verb follows the rule, `validate` included, so a root with
   several distros is registered in part 3.
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
   nothing is resolved yet (an `init` cut short: the tool's own "run `repos-manifest sync` to
   finish"), refusing for several distros and no choice as in step 3. The tool's output and
   exit status pass through (0; 1 for a failed non-optional repo or any refusal; 128+n on a
   signal). The tool reports "present, not touched (N); updating a repo that is there is not
   built yet"; the adapter adds no pull, fetch or `vcs`. When `layers.txt` differs before and
   after, `sync` prints today's "existing package worktrees keep their old env.sh; recreate
   them". A root with no `.repos-manifest/`, no `source` and no bootstrap URL is today's
   bootstrap refusal; its message gains one line: "Or set the root up with the manifest
   tool: in <root>, run `<bin> init <manifest> --distro-dirs --distro <distro> [--role <role>]`,
   then register it".
6. **`build` and `test`.** Unchanged loops over the routed layers. On the tool route colcon
   also gets `--base-paths src`, placed before `--cmake-args` (which takes the rest), so the
   unnamed layer, built in `<root>/<d>`, does not take in the named layers below it. The
   header says `build` is interim until `repos-manifest build`.
7. **`validate` on the tool route.** `_rc_require_manifest` and the distro rule; then per
   layer: its `.repos` file must exist; every key in it that `optional.txt` does not name must
   be a directory `<layer dir>/src/<key>` (a layer with no `src/` counts its repos, not
   itself). It fails, naming the fix, on a second record: `role=` or `distro=` on the
   registry line ("remove it from the line in `.agent/projects.local`"), or `source`,
   `source_ref`, `source_path` or `bootstrap_url` in the settings file
   (`project_setting.sh unset <name> <keys>`). Success: "✅ ros2_colcon checkout matches the
   tool's last resolve for distro <d> (.repos-manifest/resolved/<d>); the manifest itself was
   not read again (there is no `repos-manifest status` yet)".
8. **`env`, `repos`, `repo_pin`, `worktree_repos`, `worktree_env`:** no code change; they
   read the routed helpers. The pin is the `version` in `resolved/<d>/<layer>.repos`, never
   `state.yaml`.
9. **Registration.** `register_project.sh` line 623 becomes
   `elif [ -d "$PROJECT_ROOT/configs/manifest" ] || [ -e "$PROJECT_ROOT/.repos-manifest" ] || set_value bootstrap_url ...`,
   and its header (lines 32–36) says so. `registration.conf` keeps its values; its comment
   says a tool root exists already, so registration runs no `setup`, and the gate's
   `adapter validate` is the check.
10. **Headers.** `adapter.sh`'s header: three routes in order, the tool route's layout, the
    distro rule (stated there once; the design documents point at it), interim `build`.

## Verbs

| Verb | Today | Tool route, part 1 | Later |
|---|---|---|---|
| `setup` | bootstrap or fetch and resolve, then `vcs import` per layer | `repos-manifest sync --distro <d>` in the root; no `--distro` when nothing is resolved yet | part 2: `init` from what registration recorded; part 3: `add-distro` |
| `sync` | fetch and resolve (manifest route), then pull or fetch each clone | as `setup`; never pulls | part 4: the tool updates existing clones |
| `build` | `colcon build` per layer, in order | the same loop over `resolved/<d>/layers.txt`, `--base-paths src`; interim | part 4: `repos-manifest build`, distro's environment sourced first |
| `test` | `colcon test` per layer | the same loop, `--base-paths src` | stays in the adapter |
| `validate` | checkouts against the manifest; route checks | checkouts against the last resolve; refuses a second record | part 4: `repos-manifest status` |
| `env` | underlay, then each built layer | the same, from `<root>/<d>/<layer>/install` | part 4: may source the tool's `setup.bash` once it is real |
| `repos` | `src/*` per layer | the same paths | unchanged |
| `repo_pin` | `version:` in `repos/<l>.repos` | `version:` in `resolved/<d>/<l>.repos` | unchanged |
| `worktree_repos`, `worktree_env` | from the layer dirs | the same, routed | part 3: the worktree's distro in its header |
| `install`, `project_root`, `scope_for_pr` | | unchanged | |

## Layers and the unnamed layer

`layers.txt` lists the layers in build order, the unnamed one as `_unnamed` (first when
present; `manifest.py` `UNNAMED_LAYER`). The adapter's "layer directory" is the directory
holding the layer's `src/`, where colcon runs and `install/` lands: `<root>/<d>/<layer>`, and
`<root>/<d>` for `_unnamed`. The worktree's own layout stays `<wt>/<layer>_ws/src/<key>`
(`_unnamed_ws` for the unnamed layer). Optional: the tool marks repos, not layers, so on the
tool route no layer is optional, and `validate` passes over a missing repo that `optional.txt`
names. A key with a directory in it (`grp/repo`, allowed by the tool): refused by name in
part 1, because `_rc_repos_entries` would skip it silently, `repos` lists `src/*` one level
down, and `worktree_create.sh` names the owning repo to `_pr_base.sh` by `basename` of its
path (`grp/repo` → `repo`), a generic script this part does not change. The owner's
manifest has none (and no unnamed layer).

## The package worktree on the tool route

`worktree_create.sh --type project --project <name> --issue owner/repo#N --layer <l> --package-repos <a>`:
`adapter worktree_repos` checks `<l>` against `resolved/<d>/layers.txt` and `<root>/<d>/<l>/src/<a>`
as a repo's top; `_pr_base.sh pr_base_for` → `adapter repo_pin <a> --layer <l>` reads
`resolved/<d>/<l>.repos` and asks the clone's origin for the kind. The worktree is made in
`registry_worktree_dir` (`<root>/worktrees/issue-…-<N>/`, outside every distro directory);
`worktree_env` writes `COLCON_IGNORE` there. `env.sh` sources, in order: `/opt/ros/<d>/setup.bash`;
`<root>/<d>/<lower>/install/local_setup.bash` for each layer before `<l>` (each guarded by
`if [ -f ]`); `<root>/<d>/<l>/install/local_setup.bash`; `<wt>/<l>_ws/install/local_setup.bash`.
`build.sh` builds `<wt>/<l>_ws/src` with `--allow-overriding` of its own packages. Built by hand
first: every layer below `<l>`, and `<l>` itself for sibling packages. When one is not, `env.sh`
skips it silently (runtime guard, unchanged) and the failure is CMake's
"Could not find a package configuration file provided by <pkg>" in `build.sh`; part 1 adds no
message of its own.

## A session started in `<root>/<distro>/`

Decided (owner, 2026-11-18, below): part 1 works with a session at the root; one distro is
set up, so rule 2 gives it. Allowing `<root>/<d>/` is part 3, and will change: `session_root.sh`'s second refusal
(`[[ -z "$S_REPO" && "$DIR_PHYS" != "$S_ROOT" ]]`), which exists because a session started
outside git reads only its own directory's `.claude/settings*.json`, so the root's hooks and
permission rules do not reach it (ADR-0020 decision 6, `docs/design.md#sessions-and-roots`);
a new ADR superseding that sentence of decision 6 (accept any subdirectory of a root in no git
repository, saying settings then follow the directory); the header and the design sentence;
`test_session_root.sh` line 100's refusal assertion changes (named in the PR) and one test
accepts `<root>/<d>`. The adapter needs nothing more: rule 1 already gives `d` there.

## Tests (no network)

Fixtures follow `test_ros2_colcon.sh`'s manifest-route ones (`make_sandbox`, toolchain
stubs, `make_underlay`, `mr_test` skipping loudly without PyYAML): a new-format manifest
(`format: 1`, distros `[fakefox, fakefox2]`, layers `core`, `extra`, one unnamed-layer repo,
one optional repo) resolved with this checkout's `repos-manifest resolve --role dev --distro
fakefox --out <root>/.repos-manifest/resolved/fakefox`; clones made as `make_committed_pkg_repo`
does, origins under `fake_remotes/`. `setup`/`sync` use a stub `.venv/bin/repos-manifest`
recording cwd, arguments and exit status. New `test_tool_*` functions in `test_ros2_colcon.sh`:
- route: `.repos-manifest/` beats `source` and bootstrap; a curl stub records any call, and a
  root with `.repos-manifest/` but no `resolved/` (and a flat one) errors naming the step,
  with no curl call and no `configs/` made, for `setup`, `validate`, `env` and `build`;
- distro rule: `--from <root>/fakefox/core/src` → fakefox; one distro from the workspace →
  it; two from the root → refused listing both; from `<root>/fakefox2` → fakefox2;
- one per verb: `env` (order), `setup` and `sync` (cwd = root, `sync --distro fakefox`,
  status 0/1/130 passed through, no `vcs` call, a clone behind origin left where it was,
  the layers-changed line), `build` and `test` (colcon in `<root>/fakefox/core` then `extra`,
  unnamed in `<root>/fakefox`, `--base-paths src` before `--cmake-args`, via a tool-route colcon
  stub that also logs arguments), `validate` (pass line; a missing repo fails; a missing
  optional one passes; each second record named), `repos`, `repo_pin` (pin and kind from the
  resolved file), a key with `/` refused by name;
- the package worktree through `worktree_create.sh`: base from the resolved pin, `env.sh` lines
  in the order above. Existing suites stub colcon and never build a real package, so no real
  build test is added;
- after #500 merges, one test running the real `init --yes` and `sync` on local `file://`
  repositories, then `adapter validate`, skipped loudly when `vcs` is absent.

`test_register_project.sh`: type detected from `.repos-manifest/`, gate passes, registry line
has no `role=`/`distro=` (its fixture resolved by the same resolver, skipped loudly without it).
At the end, run unchanged: `test_ros2_colcon.sh`, `test_adapter.sh`, `validate_adapter.sh`,
`test_register_project.sh`, `test_worktree_create.sh`, `test_dispatch_phase.sh`,
`test_session_root.sh`, `test_user_tier_guard.sh`, and check `git diff main -- .agent/scripts/tests`
removes or changes no line.

## Documents in the same pull request

- `docs/manifest/design.md`, "Two routes": "The `ros2_colcon` adapter has two routes to the list
  of repos, chosen by one fact: whether `source` is set." → "…three routes, chosen in this
  order: a `.repos-manifest/` folder at the root, `source` set, else bootstrap", with a bullet
  "**The tool route**" and a short "The tool route" subsection (what it reads, the distro rule
  by reference to the adapter header, `setup`/`sync` run `repos-manifest sync`, interim
  `build`, what `validate` checks and says, `<root>/<d>/setup.bash` being the tool's stub until
  its `build`, so the environment is `adapter env`; flat and `/` keys refused).
- Same file, "Worktrees": adds that on the tool route the layers are `<root>/<d>/<layer>/`.
- Same file, route order: "The test is the tool answering, not the `.repos-manifest/` folder
  being there: … That error counts as the tool not answering, so the instance is not treated as
  set up." → "Until `status` is built, the test is the folder being there; then it is the tool
  answering. Either way a folder the adapter or the tool cannot use is an error naming the next
  step, never another route: the older routes fetch." "Nothing in this section is built." →
  "…except the first cut, under What exists today."
- Same file, "`setup`, `sync` … How a session says which is not decided yet." → the directory
  rule (owner, 2026-11-18), sessions started at the root until part 3, and "Not decided"
  keeps only `add-distro --manifest-ref`.
- Same file, "What the workspace records": adds that a tool-route instance has no `role=`,
  `distro=` or `source` keys, and `validate` refuses them there.
- `docs/manifest/roadmap.md`: new line "The adapter reads an instance in the tool's layout, its
  distro from the calling directory (#503 part 1)" with check
  `file-contains .agent/project_types/ros2_colcon/adapter.sh .repos-manifest/resolved`; "A
  worktree of a package repo builds against an instance in the tool's layout" stays unchecked
  until the owner's acceptance is recorded on #503.
- `docs/design.md#registry-and-adapters`: "two routes to that directory (#436), chosen by one
  fact, the settings file setting `source`" → three routes in order; "driven by a manifest
  directory, `configs/manifest` or the generated `configs/manifest-resolved`" → adds
  `.repos-manifest/resolved/<distro>/`; "distro comes from `distro=` … or its manifest" →
  adds the calling directory on the tool route; "Registration needs a git repository today
  (`adapter validate`)" → a tool root in no git repository registers from the main checkout;
  `ACTIVE_PROJECT_FROM` in the resolution bullet; a change-log row with the line count.
- `.agent/WORKTREE_GUIDE.md` "Package Worktrees": same flags on a tool root; environment is
  `adapter env`, not the tool's stub `setup.bash`.

## By-hand acceptance (owner's machine, after #500 part 1 and this PR merge)

1. `cd ~/agent_workspace && git pull && make install-repos-manifest && vcs --version`.
2. `mkdir ~/project11 && cd ~/project11 && cp <his draft manifest> ./project11.manifest.yaml`.
3. `~/agent_workspace/.venv/bin/repos-manifest init ./project11.manifest.yaml --distro-dirs --distro rolling --role simulator`:
   a summary of `rolling/<layer>/src/` repos, `[y/N]`, `y`, clones, "The system is set up.".
4. `cd ~/agent_workspace && .agent/scripts/register_project.sh ~/project11 --name project11`:
   type `ros2_colcon` detected, "adapter validate passed", `VERIFY=pass`.
5. `.agent/scripts/adapter --project project11 validate`: the ✅ line for distro rolling.
6. `.agent/scripts/adapter --project project11 sync`: the tool's "present, not touched (N)".
7. Build (by hand while ports fail, #415): `rosdep` as he does today, then
   `.agent/scripts/adapter --project project11 build` (stops at the first failing layer), or
   per layer `source /opt/ros/rolling/setup.bash; cd ~/project11/rolling/underlay && colcon build --symlink-install --base-paths src && source install/local_setup.bash`, then `core`, and so on.
   Not `rolling/setup.bash`: the tool's stub until its `build` (part 4).
8. `cd ~/project11 && claude`, then `/run-issue rolker/unh_marine_autonomy#415 --layer core --package-repos unh_marine_autonomy`:
   a worktree under `~/project11/worktrees/`, its branch from the pin in
   `rolling/core.repos`; its `build.sh` builds against `~/project11/rolling/{underlay,core}/install`.
By hand because later parts are not built: step 3 (part 2), step 7's build (part 4). The
session starts at the root, not `rolling/`, until part 3.

## Files to Change

| File | Change |
|---|---|
| `.agent/project_types/ros2_colcon/adapter.sh` | route, distro rule, helpers, `setup`/`sync`/`validate` tool branches, `--base-paths src`, header |
| `.agent/project_types/ros2_colcon/registration.conf` | comment only |
| `.agent/scripts/adapter` | `ACTIVE_PROJECT_FROM`, header |
| `.agent/scripts/register_project.sh` | type detection line 623, header lines 32–36 |
| `.agent/scripts/tests/test_ros2_colcon.sh`, `test_register_project.sh` | new tests only |
| `docs/manifest/design.md`, `docs/manifest/roadmap.md`, `docs/design.md`, `.agent/WORKTREE_GUIDE.md` | as above |

## Prior Art

Reused: the adapter's own loops, `_rc_resolver_bin`, `_rc_nofd`, the manifest-route test
fixtures; the tool's stated output and its own cwd rule (`distros_for`), whose step 3 differs
(the tool takes every distro, the adapter refuses) because an adapter verb acts on one distro.
Rejected: one registry instance per distro directory (the owner chose one registration);
reading `config.yaml` or `state.yaml` (the tool's inside, ADR-0022).

## Serves

Easy to use and Modular (`README.md#workspace-goals`); `docs/design.md#registry-and-adapters`,
`docs/manifest/design.md#a-project-instance-is-a-system-directory`.

## Design Picture

Changes: a third route in `docs/design.md#registry-and-adapters` and
`docs/manifest/design.md#what-exists-today`, the distro rule out of "Not decided", in this PR.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Small steps | part 1 only; parts 2–4 outlined |
| Keep one current design | documents above change in the same PR |
| Only what's needed | no new verb, no `init` call, no distro record, no `config.yaml` |
| Test what breaks | offline fixtures from the real resolver; today's assertions untouched |
| Put each thing at its level | distro rule in the adapter; dispatcher passes a directory only |
| Verify before claiming | the owner's acceptance is recorded on #503 with the commands run |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0011 | Yes | no verb added; `validate_adapter.sh`, `test_adapter.sh` pass; no type name in generic scripts |
| 0012 | Yes | composition stays in `worktree_repos`/`worktree_env`; generic worktree scripts untouched |
| 0016, 0018, 0020 | Yes | `session_root.sh` unchanged in part 1 (owner, 2026-11-18); part 3 brings a superseding ADR |
| 0021 | Watch | a folder in no git repository registers from the workspace, not from its own session |
| 0017, 0022 | Yes | design updated in the PR; only `resolved/` is read |

## Consequences

| If we change… | Also update… | Included? |
|---|---|---|
| `_rc_layer_dir`, `_rc_manifest_dir` | every caller listed in step 4 | Yes |
| type detection | `register_project.sh` header | Yes |
| a new `ACTIVE_PROJECT_*` | dispatcher header | Yes |
| `script_reference.md` | no usage changes | No |

## Risks

- `resolved/<d>/` swapped by a concurrent `sync` between two reads of a run: low; no lock
  (one of "What the tool has to give").
- A distro not named as a ROS distribution has no `/opt/ros/<d>`: `_rc_underlay`'s error.
- The tool's `<root>/<d>/setup.bash` returns 1 until its `build`; documented.

## Owner's decisions

- 2026-11-18, on which distro a call uses: "yes, the directory the session is started in
  decides." The adapter's distro rule (step 3).
- 2026-11-18, on a session started in `<root>/<distro>/`: "yes, starting at ~/project11 is fine
  for the first cut". Part 1 works with sessions started at the root; a session started in
  `<root>/<d>/` is part 3, with a decision superseding that part of ADR-0020 decision 6.

## Open Questions for the owner

None. The Checkpoint and the owner's answers above settle every choice that changes what ends
up on his disk or in his registry.

## Later parts

- **Part 2:** registration passes the manifest's location, role, first distro and groups to
  `init`; `setup` runs `init` for a root not set up (a manifest from git once the tool reads one).
- **Part 3:** sessions in `<root>/<d>/` (a decision superseding that part of ADR-0020); the session's distro carried into
  worktrees (`.worktree-repos` header); `add-distro`; registering a root with several distros.
- **Part 4:** `build` → `repos-manifest build`, `validate` → `status`, `sync` relies on the tool
  updating clones, each as it lands. Removing the older routes stays with the roadmap.

## Dependencies, order, size

Merges after #500 part 1 (`init`, `sync`; local branch `feature/issue-500`, no PR yet); its
command line is checked against #500 as merged. Before that, all of part 1 can be built and
tested against main's `resolve`, with the stub tool; the real `init`/`sync` test and the
acceptance wait. Size: one PR, about +170/−20 in `adapter.sh`, +6 in the dispatcher, +3 in
`register_project.sh`, +450 test lines, +60 document lines.
