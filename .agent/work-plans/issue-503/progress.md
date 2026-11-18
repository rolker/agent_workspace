---
issue: 503
---

# Issue #503 — ros2_colcon adapter: call the manifest tool's commands, and register a project from a manifest

## Issue Review
**Status**: complete
**When**: 2026-11-18 17:37 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Issue**: #503

### Scope Assessment

**Well-scoped?** No, not as one PR. The issue asks for every verb on the tool, registration through `init`, and the distro question, and depends on four tool commands, two of which (`build`, `status`) are not built. The owner's route (2026-11-18) is a first cut right after the tool's `init` and `sync`: "it registers a directory the tool set up as one project, and its setup and sync call the tool. Building stays by hand (colcon per layer) until `build` lands." That first cut is one PR. It is described below, piece by piece.

**Right repo?** Yes. The adapter, registry, worktree and session scripts are workspace code. The porting work it enables (rolker/unh_marine_autonomy#415, "Port to ROS 2 Rolling: build failures from a first build of the simulator set") is project work in the package repos and is not part of this issue.

**Serves**: Easy to use ("start an agent in the project's own directory and the workspace is there") and Modular. Design: `docs/design.md#registry-and-adapters`; the part's own section is `docs/manifest/design.md#a-project-instance-is-a-system-directory`.

**Design picture?** Changes. A third route for `ros2_colcon` (an instance that is a tool system directory) is added beside the two in `docs/design.md#registry-and-adapters` and `docs/manifest/design.md#what-exists-today`. The "Not decided" question of how a session names its distro is answered by the owner's directory rule. The route order's wording needs a correction (below).

**Dependencies**: The tool's `init` and `sync` (#500 part 1, built on `feature/issue-500`, in a review fix round, not on main and with no PR open yet). Nothing else. `show`, `build`, `status`, `add-distro`, updating existing clones and reading a manifest from git or a URL are not needed for part 1.

#### The first cut (part 1), piece by piece

What the code does today, checked against `.agent/project_types/ros2_colcon/adapter.sh`: every verb finds its files through three helpers. `_rc_manifest_dir` gives the directory with `layers.txt`. The `.repos` file of a layer is `$mdir/repos/<layer>.repos`, written out in `setup`, `sync`, `validate` and `repo_pin`. `_rc_layer_dir` gives `layers/main/<layer>_ws`. The tool's layout (`feature/issue-500`, `system.py`: `layer_src_parts`, `resolved_parts`) is `<root>/<distro>/<layer>/src/<repo>`, with the unnamed layer's repos in `<root>/<distro>/src/`, and the resolved output in `.repos-manifest/resolved/<distro>/` as `layers.txt`, `<layer>.repos` (no `repos/` subdirectory) and `optional.txt` (optional *repos*, by key, not optional layers). So most of the first cut is a third answer from those helpers, plus a `_rc_repos_file` helper, and the verbs above them stay as they are.

**(a) Registering `~/project11` as one project.** `register_project.sh ~/project11 ros2_colcon --name project11`, run from the workspace's main checkout, with no `--role`, `--distro` or `--set source=`. Today this fails at the gate: `registration_verify.sh` runs `adapter validate`, which with no `source` is the bootstrap route and fails on the missing `configs/manifest`. With the tool route in `validate`, it passes. Changes: the route detection and `validate` in `adapter.sh`; `register_project.sh` line 623 detects the type from `.repos-manifest/` as it does from `configs/manifest` (one line, so the type need not be typed). `registration.conf` stays: `setup=when-missing` does nothing for a directory that exists, `run=none`. The registry line is `project11 ros2_colcon /home/<user>/project11`, with no `role=` or `distro=`. Registration from a session in the folder (`register_session_root.sh`) still refuses a folder in no git repository, a gap ADR-0021 already names. Part 1 registers from the workspace.

**(b) A session in it, and its distro.** A session started at `~/project11` already resolves to the project: `session_root.sh` and `registry_resolve_session_dir` match the longest registered prefix, and a root in no git repository is accepted when the session is at the root itself. A session started in `~/project11/rolling` is refused today by `session_root.sh`. The refusal is for a subdirectory of a root in no git repository, because the root's `.claude/settings.json` and `settings.local.json` do not reach a session there. ADR-0020 decision 6 keeps that refusal and `docs/design.md#sessions-and-roots` describes it. The owner's rule that a session in `rolling/` belongs to the project conflicts with that accepted decision. See question 1. The distro rule is carried in the adapter, in one function on the tool route, in this order:
  1. The directory the call is made from (`--from`, else the cwd, which the dispatcher would expose as one more `ACTIVE_PROJECT_*` variable) is inside `<root>/<d>/` for a distro `d` the tool resolved: then `d`.
  2. Otherwise, when one distro is set up, that one. This is `~/project11` today.
  3. Otherwise refuse, listing the distros. `validate` with no distro chosen checks every distro, as the tool's own `validate` does at the top of a system.
  
  Nothing in the registry or the settings file holds the distro. The distros are the directories under `.repos-manifest/resolved/` that hold a `layers.txt`, which is the tool's stated output (`docs/manifest/design.md`, "What the workspace records"). The adapter does not parse `config.yaml`. With one distro, rule 2 covers every call, including those made from the workspace checkout (`registration_verify.sh` runs the adapter `--from` the main checkout) and from a worktree. A worktree under `~/project11/worktrees/` is not inside a distro directory, so with several distros it falls to rule 3. Part 3 carries the session's distro into worktrees.

**(c) `/run-issue rolker/<package repo>#N` from that session.** The package-worktree path works unchanged above the adapter once the helpers route. Checked:
- `worktree_create.sh` gets the repos from `adapter worktree_repos` and the base from `_pr_base.sh pr_base_for`, which calls `adapter repo_pin`.
- `dispatch_phase.sh base` and `where` use the same two verbs, and the `.worktree-repos` header.
- The worktree's own layout `<worktree>/<layer>_ws/src/<repo>` is internal to the worktree. It is written by `worktree_repos`, read by `worktree_env` (it finds `*_ws`) and by the generated `build.sh` and `test.sh` (`cd "$SELF_DIR/${LAYER}_ws"`), and none of these depends on the instance's layout.
- `worktree_env` emits the distro's `/opt/ros/<d>/setup.bash`, each lower layer's `install/local_setup.bash`, then the instance's same layer, then the worktree's own. With `_rc_layer_dir` routed, those are `~/project11/rolling/<layer>/install/local_setup.bash`, the layers the owner built by hand.
- `worktree_repos` checks that `<layer dir>/src/<repo>` is a repo's top level, which holds for the tool's clones.

The owner still gives `--layer <l> --package-repos <repo>`, as for any package issue. ADR-0012: nothing is inferred. The worktrees go in `~/project11/worktrees/`, beside the distro directories and outside every layer, so colcon never sees them.

**(d) `setup` and `sync` call the tool.** On the tool route they `cd` to the root and run `<main checkout>/.venv/bin/repos-manifest sync --distro <d>`, the binary `_rc_resolver_bin` already finds. The tool's output and exit status are passed through: 0, 1 when a repo that is not optional failed or on any refusal, 128+n on a signal. `setup` on a root with no `.repos-manifest/` refuses and prints the `init` command to run by hand, for example `repos-manifest init <manifest path> --role <role> --distro <distro> --distro-dirs`. Calling `init` from registration is part 2. In this version `init` reads only a manifest given as a file path (`system.py` `read_manifest`), which fits the draft manifest. The tool's `sync` part 1 clones what is missing and does not touch a repo that is already there ("updating a repo that is there is not built yet"). The adapter's own pull loop is not run on the tool route: it would move repos behind the tool's `state.yaml`, which records what `sync` last put each repo on. Updating existing clones waits for the tool, and `sync` says so in one line.

**(e) `validate` and `build` without the tool's `status` and `build`.**
- `validate`: today's check, over the tool's resolved files. A layer's `.repos` file must be there, and every repo it lists that `optional.txt` does not name must be a directory at `<distro>/<layer>/src/<key>`. It also fails when the registry line carries `role=` or `distro=`, or the settings file carries `source` or `bootstrap_url`: those would be a second record that can disagree with the tool's. Its success line has to say what it did not check: "checked against the tool's last resolve; the manifest itself was not read again (no `repos-manifest status` yet)". That is the honest limit, and `status` lifts it in part 4.
- `build`: two choices. One is today's colcon-per-layer loop (`adapter_build`, unchanged) over the tool's layers for the session's distro. It is exactly what "colcon per layer by hand" is, in the right overlay order, and needs no new code. The other is a refusal that says to build by hand. Recommended: the loop, labelled interim in the header, and replaced by `repos-manifest build` when that lands. See question 2. `test` stays the adapter's loop in the design anyway, so it only needs routing. `env` needs only routing.

**What "the tool answers" means in part 1.** There is no `status`, so the test is that `.repos-manifest/` exists at the registered root. The route order is then: `.repos-manifest/` there, the tool route; otherwise `source` set; otherwise bootstrap. A `.repos-manifest/` the adapter cannot use is an error that names the next step, and never a fall-through. Such a folder has no `resolved/<d>/layers.txt` (the next step is `repos-manifest sync`), or has a flat layout, which part 1 refuses (`setup` always uses `--distro-dirs`, and a flat system's distro is not in its paths). Falling through would send a fresh root to the bootstrap route, which `curl`s a URL. The design's sentence "That error counts as the tool not answering, so the instance is not treated as set up" needs the same correction: an error from the tool is an error, not another route.

#### Every place today's layout or records are assumed

All in `.agent/project_types/ros2_colcon/adapter.sh` unless named:
- `_rc_layer_dir` (`layers/main/<layer>_ws`). It is read by `env`, `setup`, `build`, `test`, `sync`, `validate`, `repos`, `worktree_repos`, `worktree_env` and `repo_pin` (its `check_dir`). This needs the second route; nothing else in the workspace's scripts builds that path (searched `.agent/scripts`, the Makefile and the skills). `register_project.sh` line 623 reads `configs/manifest` for type detection only.
- `$mdir/repos/<layer>.repos`, written out in `adapter_setup`, `adapter_sync`, `adapter_validate` and `adapter_repo_pin`. These need a `_rc_repos_file` helper.
- `_rc_manifest_dir`, `_rc_pin_manifest_dir`, `_rc_require_manifest` (its messages), `_rc_route`, `_rc_check_single_source`, `_rc_validate_manifest_route`, `_rc_manifest_prepare` and the lock. These need a third route, and the tool route skips the generated-directory and lock machinery.
- `_rc_is_optional_layer` (`optional_layers.txt`). The tool's optional flag is per repo, in `optional.txt`, so `validate` needs a per-repo check on the tool route.
- `_rc_distro` reads the registry line's `distro=` (`ACTIVE_PROJECT_DISTRO`, set by `.agent/scripts/adapter` from `registry_field`) or `bootstrap.yaml`. The tool route uses the directory rule instead. `_rc_underlay` assumes the distro's name is the ROS distribution's (`/opt/ros/<d>`); see the risks.
- `role=` is read only by the manifest route (`_rc_manifest_resolve` and its checks). The tool route does not read it.
- `source`, `source_ref`, `source_path` and `bootstrap_url` (`ACTIVE_PROJECT_*` from the settings file) choose the older routes. They are not read on the tool route and are refused there by `validate`.
- Unchanged: `worktree_create.sh`, `_pr_base.sh`, `dispatch_phase.sh`, `_worktree_helpers.sh`, `skill_prefix.sh` (a root in no git repository answers `agent-workspace:`), the `.worktree-repos` header, and the generated `env.sh`, `build.sh` and `test.sh` scripts.
- `session_root.sh` is unchanged in part 1 unless question 1 is answered "now".

#### Where the pin comes from

From the resolved files: `.repos-manifest/resolved/<distro>/<layer>.repos`, the `version` of that repo. That is the version the manifest gives the repo for that distro, the one `sync` cloned it at, and the tool's stated output. It does not come from `state.yaml`. There the `commit` is a SHA, which is never a branch and so never a base. Its `version` is recorded only for repos `sync` cloned, and its inner shape is "not fixed" by the tool's design ("Where the resolved files and state go"). `repo_pin`'s kind check (`_rc_pin_kind`, asking the clone's origin) works as it is. Per #415, most package repos are at their `jazzy` branch in the Rolling set. If the Rolling manifest pins them so, a package worktree's branch starts from `jazzy` and its pull request targets `jazzy`. See question 3.

#### What merges first; testing offline

- #500 part 1 (`init`, `sync`) merges first. Part 1 can be built now, against main. The resolved output (`layers.txt`, `<layer>.repos`, `optional.txt`, head comments) is already main's `repos-manifest resolve` default layout. A fixture system directory needs only `.repos-manifest/resolved/rolling/` written by `resolve`, and local git repositories cloned to `rolling/<layer>/src/<repo>`. It needs no network and no `init`. `setup` and `sync` are tested with a stub tool that records its arguments and cwd. With `vcs` present, one more test runs the real `init` and `sync` on local repositories, as the tool's own tests do with the `vcs2l` from its test extra. The PR merges after #500, and checks the command line against #500 as merged: `init <manifest> [--role] [--with] [--distro]... [--distro-dirs] [--yes]` and `sync [--distro]...`. `init` refuses a non-terminal input without `--yes`.
- Workspace suites to extend: `test_ros2_colcon.sh`, which already runs the real resolver from `tools/repos-manifest/src`, offline. Cover the tool route for `env`, `setup`, `sync`, `build`, `test`, `validate`, `repos`, `worktree_repos`, `worktree_env` and `repo_pin`; the route order (tool before `source` before bootstrap); a broken `.repos-manifest/` that errors and never reaches bootstrap; and the distro rule (from a distro directory, one distro, several refused). `test_worktree_create.sh` gets one package worktree on a tool-layout fixture, with the base from the resolved pin and the generated `env.sh` order. `test_register_project.sh` gets type detection and a passing gate on a tool-layout root.

#### Risks, and the tests that guard today's projects

- Today's instances keep both older routes. Guarded by `test_ros2_colcon.sh` (bootstrap and manifest route verbs, worktree env, `repo_pin`, the sync pull and fetch, the validate failures), `test_adapter.sh` and `validate_adapter.sh` (the contract, with no new verb), `test_worktree_create.sh` (package worktree, base from the pin), `test_dispatch_phase.sh` (`base`, `where`), `test_register_project.sh` (type detection, gate, rollback), `test_session_root.sh` and `test_user_tier_guard.sh`. None of their existing assertions should change, and a change to one must be named in the PR.
- `_rc_repos_entries` matches only keys of `[A-Za-z0-9_.-]`. The tool allows a key with directories (`a/b`), and such a repo is silently skipped by `validate`, `sync`, `repo_pin`, and `repos` (which lists `src/*` one level down). On the tool route a key with `/` must be refused by name, or read, never skipped.
- The tool's distro name is used as the ROS distribution's name (`/opt/ros/<d>`). That holds for `rolling` and `jazzy`. A distro named otherwise needs the "which distro runs where" record the design defers.
- `<root>/<distro>/setup.bash` is the tool's stub: it prints "nothing is built here yet" and returns 1, even after the layers are built. Until the tool's `build` lands, the instance's environment is `eval "$(.agent/scripts/adapter env)"`, or the layers' own `install/local_setup.bash`. Part 1's documentation has to say so.
- A `sync` running while an adapter verb reads `resolved/<d>/` can swap the directory between two reads of one run. The tool replaces it whole, by rename. This is low risk, and the adapter's own lock does not cover the tool, which is one of the gaps in "What the tool has to give".
- The worktree records of a package issue go to the owning package repo's checkout, as for today's `ros2_colcon` instances. Unchanged, but it is project11's package repos that receive them.

#### Questions for the owner (three)

1. **A session started in `~/project11/rolling`.** Your rule conflicts with an accepted decision. ADR-0020 decision 6 has `session_root.sh` refuse a subdirectory of a root in no git repository, because `~/project11/.claude/settings*.json` would not reach a session started there. Recommendation: in part 1, start sessions at `~/project11`. With one distro set up, that session works on rolling by the same rule, and the porting work loses nothing. Allow `<root>/<distro>/` in part 3, with the superseding decision; for example, refuse only when the root has settings files that the distro directory would miss. Easy to undo either way.
2. **`adapter build` before the tool's `build`.** Recommendation: today's colcon-per-layer loop over the tool's layers for the session's distro, which is what you would run by hand, in the right overlay order, with no new code, replaced by `repos-manifest build` when it lands. The alternative is a refusal that says to build by hand. Either is a one-line change later.
3. **The base of a Rolling port's pull request.** The base is the pin the Rolling manifest gives each package repo. By #415 that is `jazzy` for most of them, so the branches start from, and the pull requests target, `jazzy`. #415 says the new forms build on Jazzy too, so recommendation: keep `jazzy` as the base. Pass `--base <branch>` on `/run-issue` for a repo that should differ. Nothing in the workspace changes either way.

Mechanism, decided in the plan and listed for veto:
- `.repos-manifest/` presence chooses the route, and a broken one is an error.
- The distros are read from `resolved/`, and the adapter does not parse `config.yaml`.
- A flat layout is refused.
- The adapter does not pull existing clones.
- `validate` refuses `role=`, `distro=`, `source` and `bootstrap_url` on a tool instance.
- `register_project.sh` detects the type from `.repos-manifest/`.
- No new adapter verb.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Small steps; step back when they stop converging | Action needed | Deliver in parts: part 1 is the first cut above, the tool route through the existing helpers, `setup`/`sync` calling the tool's `sync`, `validate` and `build` over the tool's layout, the directory rule for one distro; later parts as the tool's commands land |
| Keep one current design | Action needed | In the same PR: `docs/manifest/design.md` "What exists today" gains the tool route as built, the route-order paragraph says a `.repos-manifest/` the tool cannot use is an error (never a fall-through), "Not decided" records the owner's directory rule; `docs/design.md#registry-and-adapters` names the third route; `docs/manifest/roadmap.md` lines for the package worktree and the distro are given checks where they become true |
| Only what's needed | OK | Part 1 adds a route and a helper, no new verb, no `init` call, no distro record, no parsing of `config.yaml` |
| Look for prior art before building | OK | Today's `build`, `test`, `env` and worktree verbs are reused through `_rc_layer_dir`/`_rc_manifest_dir`. The registry's parent/instance lines (one instance per distro directory) would give the directory rule today, but the owner chose one registration, so they are not used |
| Test what breaks | Watch | Offline fixtures of local git repositories; the older routes' assertions stay unchanged; a silent skip of a key with `/` gets a test |
| Put each thing at the level it applies to | Watch | No project name in workspace code or tests (synthetic names in fixtures); `session_root.sh` stays free of type knowledge, which is one more reason the distro rule lives in the adapter |
| Verify before claiming | Watch | The acceptance on the owner's machine (register, `adapter validate`, a package worktree built against the hand-built layers) is recorded on the issue with the commands run |
| Ask about what matters, and show how much | OK | Three questions, each with a recommendation and its cost to undo; mechanism listed for veto |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0011 — adapter contract | Yes | The type's adapter changes; no verb is added or removed; `validate_adapter.sh` and `test_adapter.sh` must pass; generic scripts gain no type knowledge (the type detection in `register_project.sh` is already per-file there, as for `configs/manifest`) |
| 0012 — worktree composition | Yes | Composition stays in `worktree_repos`/`worktree_env`; the generic worktree scripts are untouched |
| 0019 — `repo_pin` | Yes | The pin comes from `repo_pin` reading the tool's resolved files; no generic script reads them |
| 0016, 0018, 0020 — session roots | Yes, for question 1 | Part 1 keeps `session_root.sh` as it is. Accepting `<root>/<distro>/` changes ADR-0020 decision 6's refusal and needs a superseding decision, not an edit |
| 0021 — registering a project's own folder | Watch | A folder in no git repository still cannot register itself from a session; part 1 registers from the workspace |
| 0017 — design is the current picture | Yes | The design updates above go in the same PR |
| 0022 — a part owns its inside | Yes | The adapter reads only the tool's stated output (`resolved/`); the tool's internals (`config.yaml`, `state.yaml`) stay the tool's |
| 0009 — Python packages | Watch | The tool stays the `.venv` editable install from `make install-repos-manifest`; `init`/`sync` reach it once main is updated |

### Consequences

- `.agent/project_types/ros2_colcon/adapter.sh` header (routes, distro rule, interim `build`), `registration.conf` comment (setup on a tool root), `register_project.sh` header line on type detection.
- `docs/design.md#registry-and-adapters`, `docs/manifest/design.md` ("What exists today", the route order, "Not decided"), `docs/manifest/roadmap.md` Direction checks.
- `.agent/WORKTREE_GUIDE.md` "Package Worktrees": a project in the tool's layout works the same way; the instance's environment is `adapter env`, not the tool's stub `setup.bash`.
- `.agent/knowledge/script_reference.md` only if a script's usage changes (none expected in part 1).

### Recommendations

- Correct the issue's text in a comment, or have the plan carry it. "Where this fits" names `tools/ros-manifest/docs/...`, which is now `tools/repos-manifest/docs/...`. The step order is now `init` and `sync`, then this first cut, then `show`, `build` and `status`. "Depends on" for part 1 is #500 part 1 only. "How a session says which distro" is decided: the directory the session starts in. Registration through `init` and `validate` through `status` move to later parts.
- Deliver #503 in parts. Part 1: the first cut, (a) to (e) above. Part 2: registration passes the manifest's location, role, first distro and groups to `init`, and `setup` runs `init` for a root not set up (with a manifest from git once the tool reads one). Part 3: sessions in `<root>/<distro>/` (question 1) and the session's distro carried into worktrees (`session_root.sh` output and the `.worktree-repos` header), together with the tool's `add-distro`. Part 4: `build` calls `repos-manifest build`, `validate` uses `status`, and `sync` relies on the tool updating existing clones, each as it lands. Removing the older routes stays with the later roadmap lines.
- Part 1's acceptance, on the owner's machine:
  1. `repos-manifest init <draft manifest> --role developer --distro rolling --distro-dirs` by hand in `~/project11`.
  2. `register_project.sh ~/project11 ros2_colcon` passes its gate.
  3. `adapter --project project11 validate` passes, and `sync` runs the tool's `sync`.
  4. The lower layers are built (by `adapter build` or by hand).
  5. `/run-issue rolker/<package repo>#N --layer <l> --package-repos <repo>` from a session at `~/project11` makes the package worktree with its base from the pin, and its `build.sh` builds against the instance's layers.
- Build part 1 now against main's `resolve` output and merge it after #500 part 1, checking the tool's command line against #500 as merged.
- Refuse or read a repo key with `/` on the tool route; never skip it silently.
- Make `validate`'s success line on the tool route say it checked the last resolve and did not read the manifest again.
- Say in the documentation that the tool's `<distro>/setup.bash` is a stub until its `build` lands, and that the instance's environment is `adapter env`.
- Bring questions 1 to 3 to the owner at the plan checkpoint, each with its recommendation.

### Actions
- [ ] Deliver in parts: part 1 is the first cut above, the tool route through the existing helpers, `setup`/`sync` calling the tool's `sync`, `validate` and `build` over the tool's layout, the directory rule for one distro; later parts as the tool's commands land
- [ ] In the same PR: `docs/manifest/design.md` "What exists today" gains the tool route as built, the route-order paragraph says a `.repos-manifest/` the tool cannot use is an error (never a fall-through), "Not decided" records the owner's directory rule; `docs/design.md#registry-and-adapters` names the third route; `docs/manifest/roadmap.md` lines for the package worktree and the distro are given checks where they become true
- [ ] Correct the issue's text in a comment, or have the plan carry it. "Where this fits" names `tools/ros-manifest/docs/...`, which is now `tools/repos-manifest/docs/...`. The step order is now `init` and `sync`, then this first cut, then `show`, `build` and `status`. "Depends on" for part 1 is #500 part 1 only. "How a session says which distro" is decided: the directory the session starts in. Registration through `init` and `validate` through `status` move to later parts.
- [ ] Deliver #503 in parts. Part 1: the first cut, (a) to (e) above. Part 2: registration passes the manifest's location, role, first distro and groups to `init`, and `setup` runs `init` for a root not set up (with a manifest from git once the tool reads one). Part 3: sessions in `<root>/<distro>/` (question 1) and the session's distro carried into worktrees (`session_root.sh` output and the `.worktree-repos` header), together with the tool's `add-distro`. Part 4: `build` calls `repos-manifest build`, `validate` uses `status`, and `sync` relies on the tool updating existing clones, each as it lands. Removing the older routes stays with the later roadmap lines.
- [ ] Part 1's acceptance, on the owner's machine: (1) `repos-manifest init <draft manifest> --role developer --distro rolling --distro-dirs` by hand in `~/project11`; (2) `register_project.sh ~/project11 ros2_colcon` passes its gate; (3) `adapter --project project11 validate` passes, and `sync` runs the tool's `sync`; (4) the lower layers are built (by `adapter build` or by hand); (5) `/run-issue rolker/<package repo>#N --layer <l> --package-repos <repo>` from a session at `~/project11` makes the package worktree with its base from the pin, and its `build.sh` builds against the instance's layers.
- [ ] Build part 1 now against main's `resolve` output and merge it after #500 part 1, checking the tool's command line against #500 as merged.
- [ ] Refuse or read a repo key with `/` on the tool route; never skip it silently.
- [ ] Make `validate`'s success line on the tool route say it checked the last resolve and did not read the manifest again.
- [ ] Say in the documentation that the tool's `<distro>/setup.bash` is a stub until its `build` lands, and that the instance's environment is `adapter env`.
- [ ] Bring questions 1 to 3 to the owner at the plan checkpoint, each with its recommendation.

## Checkpoint
**When**: 2026-11-18 17:38 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review's actions order the work and correct stale text; the owner chose this route and asked for it next: "Let's push to get 3 done so we can use the workflow to fix the rolling issues")
**After**: issue-actions
**Decision**: proceed

Proceed to planning part 1, the first cut, as the Issue Review lays it out in (a) to (e). One pull request, "Part of #503". Parts 2 to 4 stay in the plan as an outline only.

The owner's words that part 1 serves (2026-11-18): "what gets us to setting up ~/project11 with the structure, registering it, and working on the issues we identified so it can build. I think it's acceptable that some stuff gets done manually as we wait for everything to be built." One registration for the project, not one per distro; and on which distro a session works on: "yes, the directory the session is started in decides."

Instructions for the plan:
- The route is chosen by .repos-manifest/ existing at the root. Today's routes are untouched and every assertion in today's suites stays as it is. A root with .repos-manifest/ that cannot be used is an error that names the next step; it never falls back to a route that fetches.
- The change is kept to the adapter's few path helpers plus the route, as the review found, so the verbs built on them and the package-worktree machinery work unchanged. The plan lists each helper and each caller.
- The distro rule lives in one place and is the owner's rule: the directory the call comes from decides; with one distro set up, that one; otherwise refuse and list them. The plan says exactly how the calling directory reaches the adapter.
- A session started in <root>/<distro>/: the owner asked for it; ADR-0020 decision 6 refuses a subdirectory of a root that is not a git repository. This is a conflict between his stated rule and an accepted decision, and it is put to him. The plan is written so that part 1 works with a session started at the root (one distro set up, so the rule gives that distro), and names what changing ADR-0020's refusal would take, so that either answer is a small change to the plan.
- build before the tool's own build exists: the adapter's present colcon-per-layer loop, over the tool's layers, said plainly to be interim. validate checks the tool's last resolved files and says that is what it checked.
- setup and sync call the tool's sync; setup on a root not yet set up refuses and prints the init command. The adapter never pulls or moves a clone on this route.
- A repo key with a directory in it is read, not skipped; if it cannot be supported in part 1 it is refused by name.
- The pin and the base of a package worktree come from the resolved .repos files.
- Tests need no network: a fixture system directory made by the tool from local git repositories. The command line is checked against issue 500's branch (feature/issue-500, local) now and against main once it merges; this pull request merges after it.
- The design documents change in the same pull request (docs/manifest/design.md, its roadmap's checks, docs/design.md where the registry and adapters are described).
- The by-hand acceptance for the owner on this machine, with exact commands: init in ~/project11 by hand, register, validate, sync, build the layers, then /run-issue on a package repo's issue making a worktree whose build script builds against those layers.
- Lessons carried from the tool's issues: each rule stated once; documents say exactly what the code does; no hardening against inputs nobody writes.

## Plan Authored
**Status**: complete
**When**: 2026-11-18 17:46 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Plan**: `.agent/work-plans/issue-503/plan.md` at `3c2fdd0d`

Part 1, the first cut: a root holding `.repos-manifest/` takes a third route through the adapter's existing path helpers (`_rc_manifest_dir` to `resolved/<d>`, a new `_rc_repos_file`, `_rc_layer_dir` to `<root>/<d>/<layer>` or `<root>/<d>` for `_unnamed`, optional per repo), the distro by the owner's rule from `ACTIVE_PROJECT_FROM` set by the dispatcher, `setup`/`sync` running `repos-manifest sync --distro <d>`, `build`/`test` the interim colcon loop with `--base-paths src`, and `validate` checking the last resolve and refusing a second record; type detection in `register_project.sh`; no new verb. Owner's decisions recorded (2026-11-18): "yes, the directory the session is started in decides"; "yes, starting at ~/project11 is fine for the first cut", so sessions start at the root and `<root>/<distro>/` sessions are part 3 with a decision superseding that part of ADR-0020. No open questions remain. Merges after #500 part 1.

## Plan Review
**Status**: complete
**When**: 2026-11-18 17:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #503 — ros2_colcon adapter: call the manifest tool's commands, and register a project from a manifest
**Plan**: `.agent/work-plans/issue-503/plan.md` at `3c2fdd0d`
**Branch**: `feature/issue-503`
**Serves**: Easy to use and Modular (`README.md#workspace-goals`); `docs/design.md#registry-and-adapters`, `docs/manifest/design.md#a-project-instance-is-a-system-directory` (checked: present, and the work serves them)

### The owner's use, traced through the code as it would be after the plan

1. `repos-manifest init ./project11.manifest.yaml --distro-dirs --distro rolling --role simulator` (feature/issue-500): writes `.repos-manifest/{config.yaml,state.yaml}`, `.repos-manifest/resolved/rolling/{layers.txt,<layer>.repos,optional.txt}` (head `#` lines, `yaml.safe_dump` with two-space keys, which `_rc_repos_entries` and `_rc_layers` read), clones to `rolling/<layer>/src/<key>`, and the stub `rolling/setup.bash`. Works.
2. `register_project.sh ~/project11 --name project11` from the workspace: type from `.repos-manifest/` (plan step 9); `registration.conf` has `setup=when-missing` (the directory exists, so no setup) and `run=none`, so registration runs neither `build` nor `test` and `--skip-run` is not needed; the gate's `adapter --from <main checkout> --project project11 validate` gets rolling by rule 2 and passes when every non-optional repo cloned; line `project11 ros2_colcon /home/roland/project11`; the user-tier check runs `session_root.sh --dir ~/project11`, which accepts a root in no git repository when the directory is the root itself. Works.
3. A session at `~/project11`: `session_root.sh` accepts it (above); `skill_prefix.sh` answers `agent-workspace:`; the plugin is at user scope; the root has no `.claude/` of its own, so nothing is missing. Works.
4. `/run-issue rolker/unh_marine_autonomy#415 --layer core --package-repos unh_marine_autonomy`: `session_root.sh`, `skill_prefix.sh` and `dispatch_phase.sh base` work (`adapter worktree_repos` and `repo_pin` from the session's cwd, rule 2, the pin `rolling` from `resolved/rolling/core.repos`, its kind from the clone's origin). **Breaks next, at `/start-task` step 1**: `git rev-parse --git-dir` in `~/project11` fails and the skill stops with "Not in a git repository. /start-task must be invoked from the workspace root." Past that, **`worktree_create.sh` lines 545–549** refuse every project worktree whose root is no git repository ("project checkout is not a git repository: /home/roland/project11"), package worktrees included. Neither is in the plan; the issue review listed `worktree_create.sh` as unchanged.
5. Once 4 is fixed: `env.sh` sources `/opt/ros/rolling/setup.bash` (present on this machine), each lower layer's `install/local_setup.bash` guarded, `rolling/core/install`, then the worktree's own; `build.sh` builds `core_ws/src`. A lower layer with no install is skipped without a word and the build fails in CMake with "Could not find a package configuration file provided by <pkg>", which names the package but not the layer; a partly built layer exposes what did install. Acceptable for a first cut (finding 5).
6. PR and merge: `gh_create_pr.sh -R owner/repo --base <base>` skips the repo-safety check; `merge_pr.sh --pr owner/repo#M` skips the project-root lookup, and its "Syncing project" step is guarded by `-e $PJ_REPO_ROOT/.git`. Nothing found that reads the old layout or `distro=`. But nothing on this path updates the root's clone after a merge (finding 3).

### One issue across about ten repos in several layers

Not with one worktree. A package worktree holds one layer (`worktree_repos` refuses a repo of another layer by name), and its directory is named from the issue alone (`issue-<project>-<owner>-<repo>-<N>`), so a second worktree for the same issue in another layer is refused as already existing. Within one layer, the repos other than the issue's own are siblings: their branches start from origin's default branch, not from their pin, and `run-issue` opens only the owning repo's PR (siblings by hand). For the Rolling port with this first cut: one issue per repo in that repo's own tracker (`rolker/<repo>#M`), each run with `--layer <its layer> --package-repos <repo>`, its branch and PR base from its own pin, with #415 kept as the tracking issue that lists them; work bottom-up, and after a lower layer's PR merges, pull it into the root's clone and rebuild that layer before the upper worktrees build against it. That meets his aim; one #415 worktree spanning layers does not exist.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR; adapter helpers plus route, dispatcher variable, type detection; nothing in part 1 that his use does not need |
| Issue alignment | Needs work | Every Issue Review action and Checkpoint instruction is carried, but the owner's step 8 (`/run-issue` from `~/project11`) breaks at `/start-task` step 1 and `worktree_create.sh:545`, so part 1 does not reach "working on the issues so it can build" |
| File targeting | Needs work | Missing `.agent/scripts/worktree_create.sh` (root-is-git check) and `.claude/skills/start-task/SKILL.md` step 1; `AGENTS.md`'s "registration still needs it" becomes untrue (owner's approval needed to edit) |
| Consequences | Needs work | How a merged lower-layer fix reaches the root's clone is not said (tool-route `sync` never pulls by decision; `merge_pr.sh` syncs only a git root) |
| Principle alignment | Good | Each rule stated once (distro rule in the adapter header); no new verb; offline tests; but the worktree test fixture as described would hide finding 1 ("Test what breaks") |
| ADR compliance | Good | 0011 (no verb, no type name in generic scripts), 0012 (composition stays in the adapter; the fix to `worktree_create.sh` is generic), 0019, 0020/0021 (session at the root only; registration from the workspace), 0022 (only `resolved/` read) |
| ROS conventions | Good | Overlay order unchanged; `--base-paths src` only on the tool route, so today's routes build as before |

### Findings

1. **[Issue alignment, blocker]** A session at a root in no git repository cannot create a worktree: `/start-task` step 1 stops on `git rev-parse --git-dir` failing, and `worktree_create.sh` lines 545–549 require the project root to be a git repository for every project worktree. Resolution: in `worktree_create.sh`, require only that the root is a directory, since each entry's origin is already checked to be a repository at line 868 (a `.` entry is the root itself, so a single-repo project keeps its check there); in start-task step 1, treat "not in a git repository" as the main tree when `session_root.sh` accepts the cwd as a root (it already refuses a subdirectory of such a root). Both are generic (no type name). This goes beyond the Checkpoint's "kept to the adapter's few path helpers": a conflict between that instruction and the owner's aim, labelled as such; recommended in part 1 (about 10 lines and a test).
2. **[Principle alignment, high]** The planned package-worktree test would pass with finding 1 unfixed: `make_worktree_sandbox` makes `$sb` a git repository and the fixture root lives under it, so `git -C <root> rev-parse` succeeds. The tool-route root must be outside every git repository (an absolute path on its registry line), in the worktree test and in `test_register_project.sh`.
3. **[Consequences, medium]** After a lower layer's PR merges, nothing updates `~/project11/rolling/<lower>/src/<repo>`: the tool route's `sync` never pulls (decided), and `merge_pr.sh` pulls only a root that is a git repository. Upper-layer worktrees then build against a stale install. The acceptance steps and `WORKTREE_GUIDE.md` should say: `git -C <root>/<d>/<layer>/src/<repo> pull`, then rebuild that layer.
4. **[File targeting, medium]** `AGENTS.md` Terminology says "git is meant to be, but registration still needs it", which becomes untrue for a tool root. Editing an instruction file needs the owner's approval; list it in the PR as the one stale sentence, or ask.
5. **[Consequences, low]** A lower layer with no install is skipped silently in `env.sh`. Acceptable for the first cut. A cheap improvement that changes no assertion: `worktree_env` prints a NOTE on stderr at creation naming each lower layer with no `install/` (stderr is not written into `env.sh`). Otherwise say in the acceptance that the symptom is CMake's "Could not find a package configuration file provided by <pkg>".
6. **[Consequences, low]** The plan says a worktree under `<root>/worktrees/` falls to rule 3 with several distros. In fact `worktree_create.sh` calls `worktree_repos` and `pr_base_for` from the caller's cwd and `worktree_env` after `cd "$ROOT_DIR"` (the workspace), so with two distros and a session in `<root>/<d2>/` they would disagree (d2, then refused). Name this in part 3 (pass `--from` or carry the distro).
7. **[Scope, low]** Rule 1 compares `ACTIVE_PROJECT_FROM` (`pwd -P`) with `<root>/<d>`; compare with the physical root too, as a registered path may pass through a link.
8. **[Scope, info]** `adapter build` stops at the first failing layer and passes extra arguments after `--cmake-args`, so `--continue-on-error` cannot be passed through it. The acceptance's by-hand per-layer command is the right instruction for a tree that does not build yet; adding `--continue-on-error` there lets each layer install what does build.
9. **[Scope, info]** Checked and fine: the tool's output format and exit statuses (0, 1, 128+n) as on `feature/issue-500`; `sync` re-resolves and rewrites `resolved/<d>/` each run, so the layers-changed line works; the route order and never-fall-back rule; `validate` refusing a second record; appending tests leaves today's lines unchanged (the suites end in a run list); the quoted design sentences exist and the replacements are true after the change; `/` keys refused by name is acceptable as his manifest has none.

### Summary

The adapter side is right and confined to the helpers it lists, and steps 1 to 3 of the owner's use work after it. Step 4 breaks before the worktree exists, in two generic places the plan does not touch, and the planned fixture would not catch it. With findings 1 to 3 added the plan meets the owner's aim; the work across ten repos is one issue per repo with this first cut.

### Recommended Actions

- [ ] Add to part 1: `worktree_create.sh` accepts a project root in no git repository (entries are checked at line 868), and start-task step 1 accepts a cwd in no git repository that `session_root.sh` accepts as a root; a test with a tool-route root outside every git repository, through `worktree_create.sh`
- [ ] Put the tool-route fixture roots (worktree and registration tests) outside any git repository
- [ ] In the acceptance steps and `WORKTREE_GUIDE.md`: one issue per repo for the Rolling port, bottom-up; after a lower-layer merge, `git pull` in the root's clone and rebuild that layer
- [ ] Ask the owner about `AGENTS.md`'s "registration still needs it" sentence, or name it in the PR as stale
- [ ] Name in part 3 that `worktree_create.sh` calls the adapter from two different directories; compare physical paths in rule 1
- [ ] Optional: a stderr NOTE from `worktree_env` for lower layers with no install; `--continue-on-error` in the by-hand build command

## Checkpoint
**When**: 2026-11-18 17:54 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the Plan Review's verdict is needs-work; its findings are located and none changes what the owner asked for)
**After**: plan
**Decision**: revise

Revise the plan with every finding of the Plan Review. Host decisions (owner may veto):

- Finding 1 is in part 1. The owner's aim for the first cut is "working on the issues we identified so it can build", and without this the workflow stops before a worktree exists. The two refusals of a project root that is not a git repository are relaxed generically, with no type name: worktree_create.sh requires that the project root is a directory (each repo it makes a worktree of is still checked to be a git repository where it is today), and start-task's first step accepts a current directory outside git when session_root.sh accepts it as a session root. This widens the earlier Checkpoint's "kept to the adapter's few path helpers": said plainly, with its tests. Every other caller that assumes the root is a git repository on the path from /run-issue to a merged package pull request is found and listed (grep for git rev-parse and git -C on the root in start-task, run-issue's steps, dispatch_phase.sh, worktree_enter.sh, worktree_remove.sh, merge_pr.sh, progress_append.sh and the resolve-work-plans helper) with what each does for a non-git root.
- Finding 2: the fixtures for the tool route sit outside every git repository, with an absolute path on the registry line, so the tests would fail without finding 1's fix.
- Finding 3: no code. The acceptance steps and WORKTREE_GUIDE.md say that after a package pull request merges, the root's clone of that repo is updated by hand (git pull in the clone) and that layer rebuilt, until the tool's sync updates existing clones.
- Finding 4: the sentence in AGENTS.md is an instruction file and is the owner's to approve; the host asks him. The plan carries the one-line edit as a separate, last commit that is made only on his yes, and otherwise names the sentence as stale in the pull request.
- Finding 5: do it. worktree_env prints a note on stderr at creation naming each lower layer with no install directory.
- Findings 6 and 7: the plan's part 3 outline names the two-distro inconsistency between the calls made from the caller's directory and the one made after a cd; the distro rule compares physical paths.
- Finding 8: the by-hand build steps use --continue-on-error per layer, and say that adapter build stops at the first failing layer.
- How the Rolling port is worked with this first cut goes in the acceptance section as the recommended way, for the owner to confirm: one issue per repo in that repo's own tracker, each run with its own --layer and --package-repos, bottom-up by layer, with the summary issue as the tracker.

## Plan Authored
**Status**: complete
**When**: 2026-11-18 18:00 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Plan**: `.agent/work-plans/issue-503/plan.md` at `3f2dae10`

Revision applying the Plan Review's findings under the Checkpoint's decisions. Finding 1: the path from `/run-issue` to a merged package pull request was read and tabled for a root in no git repository; only `worktree_create.sh` 545–549 (now: root must be a directory, each worktree_repos origin checked to be a repository before anything is made, the `.` entry keeping today's message) and start-task step 1 (now: outside git, go on when `session_root.sh` accepts the cwd as a root) refuse, and both are relaxed generically; everything else works unchanged. Finding 2: tool roots are siblings of the sandbox under `mktemp -d` (outside git here and in CI), with an absolute registry path and a precondition assert; `test_tool_package_worktree` fails at line 545 without the fix. Finding 3 corrected: `merge_pr.sh`'s package path already fast-forwards the root's clone when clean and on the base, so by hand is the layer rebuild (and a pull only on "fetched only"). Findings 5–8 applied (stderr note in `worktree_env`, part 3 names the two-cwd inconsistency, physical paths in rule 1, `--continue-on-error` by hand). Finding 4: the `AGENTS.md` line 11 sentence as an approval-gated last commit, one line for one. The acceptance gives the port's pattern (one issue per repo, bottom-up, #415 as tracker) with `rolker/marine_control` and `rolker/manda_coverage` in `core` as the first two. Open for the owner: the `AGENTS.md` sentence, and confirming the port pattern.

## Plan Review
**Status**: complete
**When**: 2026-11-18 18:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #503 — ros2_colcon adapter: call the manifest tool's commands, and register a project from a manifest
**Plan**: `.agent/work-plans/issue-503/plan.md` at `3f2dae10`
**Branch**: `feature/issue-503`
**Serves**: Easy to use and Modular (`README.md#workspace-goals`); `docs/design.md#registry-and-adapters`, `docs/manifest/design.md#a-project-instance-is-a-system-directory` (checked: present, and the work serves them)

### The eight findings and the Checkpoint

All eight are answered, and the Checkpoint's decisions are carried out as written: the two refusals are relaxed with no type name (steps 11, 12); fixtures sit outside git with an absolute registry path and a precondition assert; the AGENTS.md line is a last commit gated on the owner's yes; the `worktree_env` stderr note; part 3 names the two-cwd inconsistency; rule 1 compares physical paths; `--continue-on-error` by hand; the port's pattern is put to the owner. Finding 3 departs from the Checkpoint's "no code, git pull by hand" on a fact, and the fact is right: `merge_pr.sh` lines 2267–2308 already fast-forward the owning clone when it is clean and on the PR's base, else fetch only and say why.

### The table of git-root assumptions, row by row

Read at the lines named; every row holds, with two wording corrections.
- `session_root.sh`: holds (171: only a subdirectory of a root in no repository is refused).
- `skill_prefix.sh`: holds (101: `agent-workspace:`); the plugin is enabled at user scope here (`~/.claude/settings.json`), so `/agent-workspace:run-issue` resolves.
- `dispatch_phase.sh base` from the root: holds (`ROOT_DIR` from the script's own checkout, 162; project by registry prefix of `$PWD`).
- start-task step 1: holds (refuses today).
- start-task 2a, 3; `worktree_enter.sh` 268 and 338: hold (338's title lookup is guarded by `rev-parse` on the root and skips quietly).
- `worktree_create.sh` 545–549: holds (refuses today). 553–605: holds (slug falls back to the registry name). 698: holds, with its own message, so step 11's text should not list a skill worktree among the `.` entries that get today's 545 message.
- `wt_ensure_exclusion` 171: holds (git exclude skipped; `COLCON_IGNORE` is written by the adapter's `worktree_env`, 1676–1683).
- 861–913 and hook preflight 1333–1352: hold (per entry).
- 788 `cd "$ROOT_DIR"`: holds.
- `dispatch_phase.sh` `where`/`next`/handoff: holds; handoff's identity check (574) only needs `AGENT_NAME`/`AGENT_EMAIL` exported.
- `_resolve_work_plans_dir.sh`, `progress_append.sh`, `review_progress.sh persist`: hold in effect, but the row's "all `git -C <owning checkout>`" is inexact: `persist` (351) and `resolve_work_plans_dir` (507, 528) use the cwd's `git rev-parse --show-toplevel`, which is the owning checkout because every phase starts its chains with `cd <worktree>`. A chain that lost its `cd` runs at `~/project11` and fails loudly ("not in a git repository"), which is safer than at a git root, where it would act on the root's repository. Same for `cross_model_review.sh` without `--work-dir` (resolves through `resolve_work_plans_dir`, exit 4 outside git).
- `set_git_identity_env.sh`: holds, run here in a fresh directory under `/tmp` (outside git): sources with exit 0, derives `<local>+claude-code@<domain>` from the global address, `git var GIT_AUTHOR_IDENT` succeeds. The host sources it in `cd <dir> &&` chains (the owning checkout) for every dispatch; at the root only for step 11, where `merge_pr.sh`'s gate commit (1342) needs it.
- run-issue step 2 probe, step 7 push, step 8 `check_branch_updates.sh`, `fetch_pr_reviews.sh`: hold (all in `<dir>`).
- `gh_create_pr.sh -R`: holds (73 `REPO_ROOT` is the owning checkout; `registry_require_root` passes by path; `-R` skips repo safety).
- step 11 `merge_pr.sh --pr owner/repo#M`: holds. Walked to the end: `ROOT_DIR` from the script's checkout (212); `registry_require_root` passes at the root; a qualified `--pr` sets `REPO_ARG`, so the `PJ_REPO_ROOT` block (327–358) is skipped and no `.git` guard is reached; the package worktree is found by scanning `.worktree-repos` under every registered worktree dir (581–688); roadmap step skipped for a package PR (721); gate reads the owning checkout's committed timeline; after the merge, the remote branch is deleted, the owning clone (`_OWN_ORIGIN`, the root's `<root>/<d>/<L>/src/<R>`) is fast-forwarded by `pull --ff-only origin <base>` only when it is on the base branch and `status --porcelain` is empty (2275–2296), else fetched with the reason printed (2297–2307) and repeated in the last line (2520); then `cd "$ROOT_DIR"`, `worktree_remove.sh`, and `branch -d` of the local feature branch in that clone. Step 6's cwd `git pull` is on the other branch of the `if`, never reached.
- `worktree_remove.sh`, hooks: hold.

**Missed rows.** On the `/run-issue` path: none found. On the port's working pattern, one: `gh_create_issue.sh` line 68 exits 3, "Not in a git repository", before anything else, so the plan's two example `gh_create_issue.sh -R ...` commands fail from a session at `~/project11` (finding 1).

### merge_pr.sh and the tool's state.yaml

The fast-forward is right to do, and should only be reported, not changed. It moves a clean clone along the same branch the manifest names, which is what the tool's own design says `sync` will do to such a repo ("A repo that is still on that version, with nothing local in it, follows the manifest: it is updated"; `tools/repos-manifest/docs/design.md` on `feature/issue-500`). The `version` in `state.yaml` stays true; only its `commit` lags, which is what `status` is meant to show ("the commit lets `status` show what has changed since the last sync"). It is the change the port needs in the clone before the layer is rebuilt. The plan's Risks line says this; the tool-route section of `docs/manifest/design.md` should say it too, and part 4 should note that `status` reads a clone ahead of its recorded commit on the recorded branch as expected (finding 5).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | 15 files (adapter, conf, dispatcher, register, worktree_create, start-task, 4 suites, 4 documents, AGENTS.md), past the skill's 10-file line; the generic non-git-root part is independent of #500 and splits cleanly (finding 4) |
| Issue alignment | Needs work | The `/run-issue` path is now complete; the working pattern's first commands fail (finding 1) |
| File targeting | Needs work | Missing `gh_create_issue.sh` (finding 1); `register_session_root.sh` header and `script_reference.md` become stale (finding 2) |
| Consequences | Good | merge_pr's fast-forward found and used; one documentation line for the tool route (finding 5) |
| Principle alignment | Good | Generic fixes with no type name; fixtures outside git; start-task's rule can live in one tested script at no cost (finding 3) |
| ADR compliance | Good | 0011, 0012, 0016/0018/0020 (sessions at the root only), 0021, 0017, 0022 as the plan says; ADR-0021's "named gap" (lines 92–96) is narrowed, not closed; the design text says so, the ADR stays as written |
| ROS conventions | Good | `--base-paths src` only on the tool route; overlay order unchanged |

### Findings

1. **[Issue alignment, medium]** `gh_create_issue.sh` refuses outside git at line 68 (`REPO_ROOT="$(git rev-parse --show-toplevel)" || exit 3`), before the `-R` check that would make the repository irrelevant. The plan's example commands (Acceptance, "The first two") fail from `~/project11`. Resolution: generic, about six lines: outside git, require `-R` (refuse without it, as today, naming `-R`), take `.agent/github_metadata.json` from the workspace checkout, and skip the repo-safety block (already skipped by `-R`); a test in its suite run from a directory outside git. `gh_create_pr.sh` line 73 has the same check but is only run from the owning checkout; leave it. The by-hand alternative, running the command from inside the root's clone of that repository, works today but is a workaround.
2. **[File targeting, low]** Two more texts become untrue for a `ros2_colcon` root and are not in Files to Change: `register_session_root.sh` header lines 54–57 ("A folder in no git repository: register_project.sh's gate ... refuses it ... registration needs a git repository today") and `.agent/knowledge/script_reference.md` line 29 (the same sentence). The Consequences row "`script_reference.md`: no usage changes, No" should become yes for that sentence. The reviser's claim holds: `register_session_root.sh` has no git check of its own for a folder outside git (only 159–170, for a folder inside one), and the gate it hands over to has none beyond `adapter validate` (`registration_verify.sh` 168 is guarded by `-e .git`; 76–77 and `register_project.sh` 313–314 read the workspace's own repository). So a tool root registers from its own session once the tool route's `validate` passes, and the planned `test_register_session_root.sh` case is the right check.
3. **[Principle alignment, low]** start-task step 1: no new script is needed to make the rule testable. Step 2a already runs `session_root.sh`, which refuses a directory outside git unless it is a registered root itself (171) and refuses a directory under no root (151); `test_session_root.sh` covers both. So step 1's new branch can be "outside git, there is no linked worktree to refuse; step 2a decides", with no second `session_root.sh` call and no message of its own. The rule then lives in one tested script; only the skip is untested skill text, and the Manual verification check 6 covers it.
4. **[Scope, medium]** Recommend splitting into two pull requests, both "Part of #503". A, first: a project root need not be a git repository: `worktree_create.sh` steps 11, start-task step 12 (as in finding 3), `gh_create_issue.sh` (finding 1), the `docs/design.md#worktrees` sentence, `WORKTREE_GUIDE.md`'s line, and tests: a package worktree through `worktree_create.sh` on a `ros2_colcon` root in today's manifest-route layout placed outside git (this fails without the fix at line 545, and needs no tool route), plus the `single_project` guard. About 40 lines of code and 80 of tests; it does not wait for #500 and can merge now. B: the tool route (adapter, dispatcher, registration, its documents, the AGENTS.md commit), merging after #500. The owner's aim needs both; A first loses nothing and makes B's review the adapter alone. `test_tool_package_worktree` stays in B.
5. **[Consequences, low]** Say in `docs/manifest/design.md`'s tool-route text that after a package pull request merges, `merge_pr.sh` fast-forwards the root's clone (clean and on the base) ahead of the commit `state.yaml` recorded, as the tool's own `sync` would; and in part 4's outline that `status` treats that as expected.
6. **[Accuracy, info]** Wording only: the table row for `_resolve_work_plans_dir.sh`/`progress_append.sh`/`review_progress.sh persist` should say they resolve from the cwd (the phase's `cd <worktree>`), `progress_append.sh` alone taking `-C`; and step 11 should not list a skill worktree among the `.` entries given today's 545 message (it is refused earlier, at 698, with its own).
7. **[Info]** Checked and fine: the sandbox layout (`SANDBOX="$(mktemp -d)"`; `TMPDIR` unset here and `/tmp` is a tmpfs outside every repository, `git rev-parse` stops at the filesystem boundary; CI `runs-on: ubuntu-latest` with no `TMPDIR` in `.github/workflows/validate.yml`); `make_worktree_sandbox` runs `git init` in `$sb`, so `$(mktemp -d -p "$SANDBOX")/p11` is a sibling outside it; `fakessh` walks up from git's cwd and finds `fake_remotes/` in `$(dirname "$root")`; `test_tool_package_worktree` fails without step 11 (line 545). Moving the origin check before line 755 is safe for today's package worktrees: `ros2_colcon`'s `worktree_repos` already requires each `src/<repo>` to be a repository top, no test asserts the 868 message, and refusing before the first `git worktree add` needs no rollback; `single_project`'s `worktree_repos` (184) makes no git check, so the root's own `.` entry gets today's message, with nothing made before it (`wt_ensure_exclusion` and `mkdir` come after).

### Owner's decisions

- Already with him: the AGENTS.md sentence; the port's working pattern.
- Mechanism, for the host to decide and list for veto: the split (finding 4); fixing `gh_create_issue.sh` rather than documenting a `cd` into the clone (finding 1); leaving `merge_pr.sh`'s fast-forward as it is.

### Summary

The `/run-issue` path from `~/project11` to a merged package pull request is now complete: every row of the table holds against the code, and none is missing. Outside that path, the plan's own example commands for opening the port's issues fail on `gh_create_issue.sh`'s git check, and two stale texts are not listed. With those added, and the generic part split off first, the plan meets the owner's aim.

### Recommended Actions

- [ ] Add `gh_create_issue.sh`: outside git, require `-R` and read the label metadata from the workspace checkout; a test outside git (finding 1)
- [ ] Add `register_session_root.sh` header 54–57 and `script_reference.md` line 29 to Files to Change; Consequences row for `script_reference.md` to yes (finding 2)
- [ ] start-task step 1 outside git: skip to step 2a, no second `session_root.sh` call (finding 3)
- [ ] Split: PR A, a project root need not be a git repository (now); PR B, the tool route (after #500) (finding 4)
- [ ] Tool-route text in `docs/manifest/design.md` and part 4's outline: the fast-forward after a merge, ahead of `state.yaml`'s commit (finding 5)
- [ ] Wording of the table row and step 11 (finding 6)

## Checkpoint
**When**: 2026-11-18 18:09 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second Plan Review confirms the path from /run-issue to a merged package pull request is complete and says its remaining fixes are small; the owner asked for this next: "Let's push to get 3 done so we can use the workflow to fix the rolling issues")
**After**: plan
**Decision**: proceed

Proceed, with the plan's part 1 delivered as two pull requests, as the second Plan Review recommends. Where this entry and the plan differ, this entry wins. Its findings are applied while building.

This pull request is part 1A ("Part of #503"): a project root need not be a git repository.
- In scope: worktree_create.sh requires only that a project's root is a directory, with the check that each repo a worktree is made of is a git repository moved to just after the manifest is resolved, before anything is created; start-task's first step, outside git, hands over to its step 2a, where session_root.sh decides (no second call, no new script); gh_create_issue.sh, outside git, requires -R and reads its label list from the workspace checkout; the sentences that become untrue (docs/design.md where worktrees and a folder outside git are described, WORKTREE_GUIDE.md, the header of register_session_root.sh, .agent/knowledge/script_reference.md) and only those; tests.
- The main test: a package worktree made on a multi-repo project root, in today's layout, placed outside every git repository; it fails without the change. It needs nothing of the manifest tool. The guard test: a single-repository project whose root is not a git repository is still refused with today's message and nothing is created. A test of gh_create_issue.sh run outside git, with -R and without.
- Everything generic: no project type's name in a script. Every assertion of today's suites stays as it is.
- Out of scope, for part 1B: the adapter's tool route, the dispatcher's calling-directory variable, type detection in registration, docs/manifest/design.md and its roadmap, the AGENTS.md sentence (the owner's to approve). Part 1B is built after issue 500 part 1 has merged, from a fresh run of this issue.

Recorded for part 1B, from the second Plan Review: the table's two rows reworded; the design says that a merge moves the root's clone ahead of the commit recorded in the tool's state.yaml, by the same move the tool's own sync would make, and that the tool's status should treat that as expected; the merge script's update of the clone stays as it is.

## Implementation
**Status**: complete
**When**: 2026-11-18 18:22 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-503 at `a1acb334`

Part 1A (Checkpoint of 18:09): a project root need not be a git repository. Three commits, each "Part of #503":

- `c1bce462` `worktree_create.sh`: the project-root check refuses only a root that is not a directory. Right after `adapter worktree_repos` returns the list (and its empty check), before the `--base` check, the pin lookup and anything made, each entry's origin must pass `git -C <origin> rev-parse --git-dir`: a `.` entry (the root itself) fails with today's "Error: project checkout is not a git repository: <root>" and its second line, any other with "ERROR: manifest entry is not a git repository: <origin>". Between the old check and the new one nothing is created (slug detection, issue lookup and `worktree_repos` only read). The later per-entry check at the add loop stays. No type name in the script; skill and workspace worktrees untouched. Docs: `docs/design.md#worktrees` (one sentence; the `.git/info/exclude` line said to apply to a root that is a git repository; change-log row, 1199 lines), `.agent/WORKTREE_GUIDE.md` (same), `.agent/knowledge/script_reference.md` (worktree_create.sh row).
- `521d0ba8` start-task step 1: outside git it prints "Not in a git repository: no linked worktree to refuse; step 2a decides whether this directory is a session's root." and exits 0, so step 2a's `session_root.sh` decides; the linked-worktree refusal is unchanged; heading drops "(or not in the workspace at all)"; Manual verification check 6. The step's old sentence has no other copy in the repository; `make generate-skills` reads only the Makefile and the plugin manifest only `session_scope`, so neither needs running.
- `a1acb334` `gh_create_issue.sh`: outside git `REPO_ROOT` is empty; after parsing, no `-R` exits 2 with "Not in a git repository: pass -R <owner/repo> to name the repository the issue is for"; labels come from the workspace checkout the script is in. Inside git unchanged. Header and script_reference row updated.

Tests, appended only (`git diff origin/main -- .agent/scripts/tests`: 236 lines added, 0 removed or changed):
- `test_ros2_colcon.sh` `test_worktree_create_package_root_outside_git`: today's layout, root at `$(mktemp -d -p "$SANDBOX")/projects/tiered`, absolute registry path, precondition asserts the root is outside git; exit 0, branch from the pin `fakefox`, `base=fakefox`, env.sh lines in order, build.sh/test.sh, `COLCON_IGNORE`. Run against the unchanged script it failed 10 assertions, refused at the old check ("Error: project checkout is not a git repository: <root>").
- `test_ros2_colcon.sh` `test_worktree_create_package_root_outside_git_repo_not_git_refused`: `pkg_b` a plain directory; exit 1 naming it, no `worktrees/`, no branch or worktree in `pkg_a`. Here the `ros2_colcon` adapter's own `worktree_repos` refuses first.
- `test_worktree_create.sh`: a `single_project` root outside git is refused with today's two-line message and nothing is made under it (passes before and after); a test-only type whose `worktree_repos` names a git repo and a plain directory is refused by the new check, naming the plain one, with no `worktrees/`, branch or worktree (fails on the unchanged script, which refused at the root check).
- `test_gh_create_issue.sh`: outside git with `-R` (gh reached with `-R`, label, signature), invalid label (checked against the workspace's list), no `-R` (exit 2, gh not called); inside git: workspace unchanged, a clone under the root without `-R` refused by the repo-safety check as before, with `-R` its own label list read. The four outside-git cases fail on the unchanged script (exit 3).

Suites, each run with `bash` on the final tree: test_worktree_create 84 passed 0 failed; test_session_root 71/0; test_ros2_colcon 1030 passed 0 failed 0 skipped; test_register_project 201/0; test_gh_create_issue 78/0; test_gh_create_pr 113/0; test_skill_paths 163/0; test_user_tier_guard 64/0; test_merge_pr 170/0; test_merge_pr_skill 132/0; test_package_issue_loop 220/0; test_precommit_hook_path 19/0; test_project_registry 425/0; test_records_write_gate 68/0; test_user_tier_install 276/0; test_validate_workspace_stale 126/0; `check_design_anchors.sh` exit 0. shellcheck (hook) passed. Full pre-commit pass left to the host.

Left for part 1B, unchanged here because 1A does not make them false: the `register_session_root.sh` header (lines 54-57) and `script_reference.md`'s register_session_root row (registration's gate still refuses a folder in no git repository), `docs/design.md`'s "Registration needs a git repository today" (Registry and adapters) and the onboarding bullet's "known gap" (Sessions and roots), and the AGENTS.md sentence.
