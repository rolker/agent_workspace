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

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 18:29 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-503 at `510f24f1`
**Base**: origin/main
**Depth**: Deep (reason: 291+16 changed lines outside work-plans, over 200; skill and knowledge files are override triggers)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Scope: part 1A per the 18:09 Checkpoint. Verified: worktree_create.sh creates nothing before the new per-repo check; a package worktree made from a root outside git is created, re-entered (worktree_enter.sh) and removed (worktree_remove.sh, with --project and from the root cwd) in a sandboxed probe; merge_pr.sh's package path reads only the manifest entries and guards the root sync with `-e .git`; `-R x/y`, `--repo x/y`, `--repo=x/y`, `-Rx/y` all reach gh as `--repo x/y`; the new tests fail against origin/main's scripts (test_worktree_create 1, test_gh_create_issue 4, test_ros2_colcon 10). No ADR contradicted (0012, 0016 decision 2, 0018, 0020, 0021's "cannot be registered this way yet" all still true). Suites: test_worktree_create, test_ros2_colcon 1030/0, test_gh_create_issue, test_session_root 71/0, test_register_project 201/0, test_merge_pr 170/0, test_package_issue_loop 220/0, test_skill_paths 163/0; check_design_anchors exit 0; shellcheck clean.

### Findings
- [x] (must-fix) Outside git, labels for any `-R` target are validated against the workspace's own list: a label that exists in the target (a package repo) is refused with exit 1, and a workspace-only label passes then fails at gh; use the workspace list only when `-R` names the workspace's slug, else skip with the existing "validated by GitHub" warning (adversarial, gemini, codex; conflicts with the Checkpoint's wording, which said to read the workspace's list: owner call) — `.agent/scripts/gh_create_issue.sh:88`
- [x] (must-fix) Outside git with `WORKTREE_ISSUE` set (the ordinary case in a package worktree's container on a root outside git), the parent reference is injected as a bare `Part of #N` into the `-R` repository, linking that repo's #N; newly reachable (exited 3 before); qualify it when the parent's repo is known, else skip with a warning (adversarial, codex; reproduced) — `.agent/scripts/gh_create_issue.sh:221-233`
- [x] (suggestion) The per-repo check `git -C <origin> rev-parse --git-dir` passes a plain directory inside an enclosing repository (and the single-repo "." entry of a plain root nested in one), so a worktree of the enclosing repo is made; pre-existing in the old root check; compare `--show-toplevel` with the path as the skill branch does (gemini, codex, adversarial) — `.agent/scripts/worktree_create.sh:726-729`
- [x] (suggestion) A root that does not exist is refused as "project checkout is not a git repository"; say it is not a directory (gemini, adversarial) — `.agent/scripts/worktree_create.sh:549-550`
- [x] (suggestion) Step 3's recovery note says to run `git worktree list` and look under `worktrees/<type>/`; from a root outside git that fails, and project worktrees live under `<root>/worktrees/` (adversarial) — `.claude/skills/start-task/SKILL.md` step 3

## Implementation
**Status**: complete
**When**: 2026-11-18 18:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-503 at `c1bfb150`
**Addressed**: Local Review (Pre-Push) at `510f24f1` (2026-11-18 18:29 -05:00)
**Commits**: 9952a038, e02dc090, 0e799176, d7bc15be, 8ed2e2e2, c1bfb150

Decisions on each finding are the host's (listed for the owner's veto). The host corrects the 18:09 Checkpoint's wording "reads its label list from the workspace checkout": a label list describes one repository.

### Actions
- [x] (must-fix) Labels outside git: validated against a local list only when it is the target's own; outside git, the workspace checkout's list only when `-R` equals the workspace checkout's origin slug (derived with the sed the script and `gh_create_pr.sh` already use; the script had no `-R` comparison to reuse); any other `-R` target skips validation with "Labels will be validated by GitHub." Inside git unchanged. Tests: `-R pkg-owner/pkg --label nope` reaches gh (failed before: exit 1); `-R ws-owner/ws --label nope` refused as today. The branch's own earlier test asserting the workspace list for `-R pkg-owner/pkg` was replaced (it asserted the corrected wording; not in origin/main) — `9952a038` `.agent/scripts/gh_create_issue.sh`
- [x] (must-fix) Parent reference: bare `#N` only when the target (`-R`, else `gh repo view` as today) is the parent's repository; qualified `owner/repo#N` when the parent's repository is known and differs (inside git: the worktree's own origin, as today; anywhere: a `WORKTREE_ISSUE` of the form `owner/repo#N`); none, with a one-line warning, when it cannot be known (bare `WORKTREE_ISSUE` outside git, or inside git with `-R` and no GitHub origin). `worktree_enter.sh` exports `WORKTREE_ISSUE` as the bare number even for a package worktree (it strips `owner/repo#` into `ISSUE_NUM`, lines 127-130, and exports that), so outside git today the reference is left out with the warning. Five tests (same repo with `-R`, inside git other repo, outside git qualified differing, outside git qualified same, outside git bare); four failed before. Inside git without `-R` the existing parent-ref tests pass unchanged — `e02dc090` `.agent/scripts/gh_create_issue.sh`
- [x] (suggestion) The per-repo check compares `git rev-parse --show-toplevel` (resolved with `pwd -P`) with the entry's own path, as the skill branch does; today's message kept for the `.` entry. Two tests (single-repo root and a multi-repo plain entry, each inside an enclosing repository); both failed before (a worktree of the enclosing repository was made). No suite layout refused: test_ros2_colcon, test_package_issue_loop, test_merge_pr pass — `d7bc15be` `.agent/scripts/worktree_create.sh`
- [x] (suggestion) A project root that does not exist: "Error: project root does not exist: <path>". Test fails before — `0e799176` `.agent/scripts/worktree_create.sh`
- [x] (suggestion) start-task step 3's recovery note names `$WS_ROOT/.agent/scripts/worktree_list.sh` (it cds to the workspace and lists registered projects' worktrees, so it works from a root outside git) and says a project's worktrees are under its root's worktrees/ or its override — `8ed2e2e2` `.claude/skills/start-task/SKILL.md`
- [x] `.agent/knowledge/script_reference.md` rows for gh_create_issue.sh and worktree_create.sh updated where now untrue; gh_create_issue.sh header updated — `c1bfb150`

Suites, each run with `bash` on the final scripts: test_gh_create_issue 84 passed 0 failed; test_worktree_create 87/0; test_ros2_colcon 1030 passed 0 failed 0 skipped; test_session_root 71/0; test_register_project 201/0; test_merge_pr 170/0; test_package_issue_loop 220/0; test_skill_paths 163/0; test_gh_create_pr 113/0; `check_design_anchors.sh` exit 0. `git diff origin/main...HEAD -- .agent/scripts/tests | grep -c '^-[^-]'`: 0. shellcheck (hook) passed on each commit. Full pre-commit pass left to the host.

Open: `worktree_enter.sh` does not export the qualified form for a package worktree, so outside git the parent reference is skipped (with the warning) rather than qualified; exporting it would change every other `WORKTREE_ISSUE` reader and is not in this round's scope.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 18:44 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-503 at `e3178b5e`
**Base**: origin/main
**Depth**: Deep (reason: whole-branch diff 485+32 lines outside work-plans, over 200; skill and knowledge files are override triggers; fix-round rule, same tier as round 1)
**Must-fix**: 4 | **Suggestions**: 9
**Round**: 2 | **Ship**: continue — round 2: 4 must-fix, rising from 2, one (the parent's repository in a package worktree) is a design question

Round 1's two must-fix are answered as specified for the cases they named: outside git, `-R <ws slug>` (as `-R x/y`, `--repo x/y`, `--repo=x/y`, `-Rx/y`) validates against the workspace's list; any other spelling (other case, `.git`, https/ssh URL, `github.com/x/y`) and any other repo skips with "validated by GitHub" (the safe direction; no spelling validates against a wrong list); outside git, a bare `WORKTREE_ISSUE` is left out with the warning, a qualified one is bare in its own repo and qualified elsewhere. The top-level check: a symlinked root, a trailing slash, `.`/`..` segments, a linked worktree, a `.git`-file checkout, a submodule and a multi-repo plain root with a symlinked entry are all accepted (as on origin/main); a plain directory inside an enclosing repository and a missing root are refused with clear messages, nothing made (origin/main made a worktree of the enclosing repo); a bare repository is refused as "not a git repository" (not a usable root: its `worktrees/` is git's own). `worktree_list.sh` exists, runs from a registered root outside git (it cds to the workspace) and lists that root's `worktrees/issue-*` (sandboxed registry). Suites, each with `bash`: test_gh_create_issue 84/0, test_worktree_create 87/0, test_ros2_colcon 1030/0/0, test_session_root 71/0, test_register_project 201/0, test_merge_pr 170/0, test_package_issue_loop 220/0, test_skill_paths 163/0, test_gh_create_pr 113/0; check_design_anchors exit 0; removed test lines 0. Cross-model: gemini and codex completed.

### Findings
- [x] (must-fix) Parent reference aimed at the wrong repository inside git, a regression: the parent's repo is taken to be the current checkout's origin, but `worktree_enter.sh` exports a package issue as a bare number, so from a package worktree's container on a git root with `-R <owning repo>` the reference becomes `<root repo>#N` (origin/main: bare `#N`, right by accident), and from a sibling clone `<sibling>#N`; needs the qualified issue (export it, or read the `.worktree-repos` header `issue=`), a design question (adversarial, codex) — `.agent/scripts/gh_create_issue.sh:254-277`
- [x] (must-fix) A non-GitHub origin (an SSH host alias such as `git@gh-work:o/r.git`, GitLab, file://) passes through the sed whole, so with `-R` the reference is `Part of git@gh-work:o/r#N`, contradicting the comment that it is left out with a warning; accept the extracted slug only when it matches the owner/repo pattern (as `_SLUG_PATTERN` does), also for `_WS_OWN_SLUG` (adversarial, gemini; reproduced) — `.agent/scripts/gh_create_issue.sh:244-245,255-259,127`
- [x] (must-fix) The new header says labels are validated against a local list "only when it is the target's own: inside a git repository, that repository's", but inside git with `-R <another repo>` the checkout's own list is still used (unchanged from origin/main; reproduced: from the workspace checkout, `-R pkg-owner/pkg --label nope` is refused against the workspace's list); narrow the sentence to what the code does, or apply the rule inside git too (a behaviour change: owner call) (gemini, codex) — `.agent/scripts/gh_create_issue.sh:39-43`
- [x] (must-fix) Moving the git check after the issue lookup lets a plain root with no origin look a bare `--issue` up in the workspace's repository (the fallback to the workspace remote), so the single-repository guard case can print a workspace issue's title or refuse with the wrong reason ("#N is a pull request") before today's message; origin/main refused before any gh call; skip the workspace fallback for a project root that is not a git repository (adversarial) — `.agent/scripts/worktree_create.sh:636-640`
- [x] (suggestion) An exported `PARENT_REF` with `WORKTREE_ISSUE` unset crashes under `set -u` (`_PARENT_NUM: unbound variable`, exit 1, gh not called; reproduced); initialise `PARENT_REF=""` before the block, one line, worth doing (gemini) — `.agent/scripts/gh_create_issue.sh:283`
- [x] (suggestion) The duplicate check matches `#N` only, so for a qualified parent a body that mentions the target's own `#N` suppresses `Part of o/r#N` (a missing reference, not a wrong one; pre-existing) (gemini, codex) — `.agent/scripts/gh_create_issue.sh:288`
- [x] (suggestion) The warning's advice "set WORKTREE_ISSUE=<owner/repo>#N" would break `capture.sh` and `_resolve_work_plans_dir.sh` if exported for the session; word it as a per-command prefix (adversarial) — `.agent/scripts/gh_create_issue.sh:280`
- [x] (suggestion) Neither the header nor script_reference says that a package worktree's `WORKTREE_ISSUE` is bare, so from its container on a root outside git the reference is always left out and must be written by hand; say so (or resolve it with the first must-fix) (lead) — `.agent/scripts/gh_create_issue.sh:44-48`
- [x] (suggestion) `-R` is compared as a raw string (case, `.git`, URL and `HOST/OWNER/REPO` forms): outside git these skip the workspace list, and inside git give a qualified reference to the same repo, both safe; normalising is cheap but not needed (gemini, adversarial) — `.agent/scripts/gh_create_issue.sh:127-131,261-265`
- [x] (suggestion) design.md and WORKTREE_GUIDE say each repo "must be" a git repository; the code requires the top of its own repository (script_reference says so); match the wording (adversarial) — `.agent/WORKTREE_GUIDE.md:98-101`, `docs/design.md` (Worktrees)
- [x] (suggestion) The `.git/info/exclude` line is also written into an enclosing repository of a plain root (`wt_ensure_exclusion` tests `--git-dir`, e.g. a dotfiles repo at `$HOME`), while the docs say "a root that is a git repository"; pre-existing, low impact (codex, adversarial) — `.agent/scripts/_worktree_helpers.sh:171` (deferred: pre-existing on origin/main (wt_ensure_exclusion), not this pull request's; listed under found, not fixed here)
- [x] (suggestion) start-task step 1's `exit 0` ends a combined step-1-and-2 shell call early; an if/else would be safe either way; minor (gemini) — `.claude/skills/start-task/SKILL.md:70`
- [x] (suggestion) The `GITBUG_CREATE=1` path ignores `-R` (pre-existing; its own issue) (adversarial) — `.agent/scripts/gh_create_issue.sh:328-355` (deferred: pre-existing on origin/main (GITBUG_CREATE ignores -R), its own issue; listed under found, not fixed here)

## Implementation
**Status**: complete
**When**: 2026-11-18 19:01 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-503 at `c4102272`
**Addressed**: Local Review (Pre-Push) at `e3178b5e` (2026-11-18 18:44 -05:00)
**Commits**: e85cdf75, 22098265, c1ce5aae, c4102272

The two open human calls (the parent's repository inside git; labels inside git with `-R`) are decided by the host as mechanism, listed for the owner's veto: this pull request makes things work from a project root that is not a git repository and does not change what any script does inside one, so the change is made smaller. gh_create_issue.sh inside git is origin/main's code again (restored from `git show origin/main:`), not an adjusted rewrite.

### Actions
- [x] (must-fix) Parent reference inside git: origin/main's code restored for the in-git path (its `if` line gains `[ -n "$REPO_ROOT" ] &&`, the only changed line there); outside git a reference is added only for a `WORKTREE_ISSUE` of the form `owner/repo#N` (`#N` when it is the `-R` target, `owner/repo#N` otherwise), a bare number adds none with a one-line warning naming the body, unset adds nothing, nothing is taken from a remote. Checked: origin/main's script and this one, run side by side inside git over 1152 combinations (workspace checkout and a registered clone; `gh repo view` answering either repo; `WORKTREE_ISSUE` unset, `7`, `ws-owner/ws#7`, `abc`; `PARENT_REF` unset or exported; `-R` none, own, other; inline body, body naming `#7`, body file, no body; no label, valid, invalid): stdout, stderr, exit code, gh argv and body identical in all 1152. The branch's two in-git parent tests (same repo with `-R`, other repo with `-R`), which asserted the rewrite, are removed — `e85cdf75` `.agent/scripts/gh_create_issue.sh`
- [x] (must-fix) Non-GitHub origin: the parent path no longer reads any origin outside git, and inside git is origin/main's; the workspace's label slug outside git is used only when it matches `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`. Test: workspace origin `git@gh-work:ws-owner/ws.git`, `-R git@gh-work:ws-owner/ws --label nope` reaches gh, GitHub validates (failed before: exit 1, refused against the workspace's list) — `e85cdf75`
- [x] (must-fix) Labels: no change inside git (the checkout's own list, also with `-R`, as on origin/main); header sentence and script_reference row narrowed to say exactly that, and outside git the workspace's list only for `-R` naming the workspace's own repository, otherwise GitHub — `e85cdf75` `.agent/scripts/gh_create_issue.sh:38-43`, `.agent/knowledge/script_reference.md`
- [x] (must-fix) worktree_create.sh: for a project root that is not a git repository the repositories are resolved (adapter `worktree_repos`) and checked before the slug detection and issue lookup, so a single-repository root is refused with today's message as the first line, before any gh call; a bare `--issue` from such a root is not looked up in the workspace's repository nor with gh and no `--repo` ("not looked up: the project root is not a git repository"). Inside git the order is unchanged (the resolve-and-check moved into `resolve_worktree_repos`, called at the same place). Tests with a stub gh that records calls and would answer for the workspace: single-repository root, bare `--issue`: refusal first, gh not called; multi-repository root, bare `--issue`: gh not called, the not-looked-up line. Both failed before (gh called for `issue view` and `pr view` in the workspace's repository) — `22098265` `.agent/scripts/worktree_create.sh`
- [x] (suggestion) `PARENT_REF` exported with `WORKTREE_ISSUE` unset: the crash was introduced by this branch (origin/main reads `PARENT_REF` only inside the `WORKTREE_ISSUE` block; the 1152-case comparison includes `PARENT_REF='#9'` with it unset, no crash on either); gone with main's code restored. Test added (failed before: `_PARENT_NUM: unbound variable`, exit 1) — `e85cdf75`
- [x] (suggestion) Duplicate check matching `#N` only: inside git origin/main's check is kept (pre-existing, not changed); outside git a qualified reference is checked as `owner/repo#N`. Test: body "Fixes #7 here." with `ws-owner/ws#7` to another target still gets `Part of ws-owner/ws#7` (failed before) — `e85cdf75`
- [x] (suggestion) The warning no longer suggests setting a variable; it says to write "Part of owner/repo#N" in the body. Test asserts the text and that it names no `WORKTREE_ISSUE=` — `e85cdf75`
- [x] (suggestion) Header and script_reference row say that from a package worktree `WORKTREE_ISSUE` is a bare number, so outside git no parent reference is added and the person writes it in the body — `e85cdf75`
- [x] (suggestion) `-R` raw comparison: inside git there is no `-R` comparison any more (origin/main's code); outside git it is used only to choose `#N` over `owner/repo#N` and the workspace's label list, where a differently spelled `-R` takes the safe side (qualified reference; GitHub validates) — `e85cdf75`
- [x] (suggestion) docs/design.md (Worktrees) and WORKTREE_GUIDE say each repo must be the top of its own git repository, not a directory inside an enclosing one — `c1ce5aae`
- [x] (suggestion) start-task step 1 is an `if`/`else`: outside git it prints its line and does not `exit`; inside git the same check (indented). Exercised: outside git rc 0 with the line, the main checkout rc 0, this linked worktree rc 1 with the refusal — `c4102272` `.claude/skills/start-task/SKILL.md`
- [x] (suggestion) `.git/info/exclude` into an enclosing repository — `.agent/scripts/_worktree_helpers.sh:171` (deferred: pre-existing on origin/main)
- [x] (suggestion) `GITBUG_CREATE=1` ignores `-R` — `.agent/scripts/gh_create_issue.sh` (deferred: pre-existing on origin/main, its own issue)

### Found, not fixed here
- `wt_ensure_exclusion` writes the `worktrees/` exclude line into an enclosing repository of a plain root (it tests `--git-dir`), pre-existing on origin/main.
- The `GITBUG_CREATE=1` path of gh_create_issue.sh ignores `-R`, pre-existing on origin/main.

### Checks
`diff <(git show origin/main:.agent/scripts/gh_create_issue.sh) .agent/scripts/gh_create_issue.sh`: 84 lines differ (78 added, 6 removed). Every difference is in comments or on the outside-git path: the header bullets and exit-code line; `REPO_ROOT` falls back to empty instead of `exit 3` (outside git only); the outside-git `-R` requirement and label-list block (`if [ -z "$REPO_ROOT" ]`); the parent block's `if` line gaining `[ -n "$REPO_ROOT" ] &&` (identical inside git) and the outside-git `elif`; the empty-`METADATA_FILE` branch (reached only outside git). The 1152-case in-git comparison above found no difference. `git diff origin/main...HEAD -- .agent/scripts/tests | grep -c '^-[^-]'`: 0.

Suites, each run with `bash` on the final scripts: test_gh_create_issue 88 passed 0 failed; test_worktree_create 89/0; test_ros2_colcon 1030 passed 0 failed 0 skipped; test_session_root 71/0; test_register_project 201/0; test_merge_pr 170/0; test_package_issue_loop 220/0; test_skill_paths 163/0; test_gh_create_pr 113/0; also, as suites naming a changed script: test_precommit_hook_path 19/0, test_merge_pr_skill 132/0, test_project_registry 425/0, test_user_tier_guard 64/0, test_user_tier_install 276/0, test_validate_workspace_stale 126/0, test_records_write_gate 68/0. `check_design_anchors.sh` exit 0. shellcheck (hook) passed on each commit. Full pre-commit pass left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 19:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-503 at `e03b2d10`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff; whole-diff tier Deep)
**Must-fix**: 0 | **Suggestions**: 6
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: round 2's 4 must-fix and 9 suggestions, and the fix diff `4ce1b8a1..HEAD`. Cross-model: skipped (round-3 convergence check, per handoff). Static analysis (shellcheck --severity=warning on both scripts): clean. Claude adversarial (fresh subagent, fix diff): no must-fix.

Round 2's must-fix: all four fixed. (1) Inside git, gh_create_issue.sh's parent reference is origin/main's code; outside git it comes only from `owner/repo#N`. (2) Outside git nothing is read from a remote for the parent; the workspace's label slug is used only when it matches owner/repo. (3) The header and script_reference now say labels inside git use the checkout's list also with `-R`, which is what the code does. (4) For a root outside git, worktree_create.sh resolves and checks the repositories before slug detection and any gh call; a bare `--issue` is not looked up (tests 128-129 of test_worktree_create).

gh_create_issue.sh against origin/main: 84 changed lines, of which 24 are comment, 3 blank and 57 code. Outside-git only: the `-R`/label block, the `elif` parent block, the warning and the `METADATA_FILE` empty branch's body, and the removed `exit 3` block's echo/exit. Reachable inside git, each taking origin/main's path: `REPO_ROOT` fallback (:82, set inside git), the conditions at :123, :281 and :374 (false inside git) and the parent `if` at :241 (true inside git). 15 side-by-side runs of my own (stub gh; workspace checkout and a registered clone under it; `WORKTREE_ISSUE` bare, qualified, unset; `PARENT_REF` set and unset; `-R` none, own, other; `--body`, `--body-file`, none; label valid and invalid; `gh repo view` answering either repository): stdout, exit code, gh argv and body identical in all 15. Outside git (12 runs): `-R` required (exit 2, gh not called); `-R` the workspace's repository validates against its list, another repository leaves labels to GitHub; qualified to the `-R` target gives `#N`, to another gives `owner/repo#N` (in `--body` and `--body-file`); a bare number adds none and warns with no variable to export; unset adds nothing; a body already naming the parent is not added to twice; no body warns.

worktree_create.sh against origin/main: 87 changed lines (23 comment, 64 code). Inside git, `resolve_worktree_repos` runs once, at the place the inline block was (:775-777); the skill-worktree branch never calls it; workspace worktrees never reach it; `--parent-issue`, `--plan-file`, `--branch`, `--layer` are untouched; every variable it reads is set before its early call; the two gh conditions gain clauses that are always true inside git. The one in-git difference is the top-of-own-repository loop added in round 1 (suggestion 2 below).

start-task step 1: main checkout rc 0 and goes on; linked worktree rc 1 with the refusal; plain directory prints its line, rc 0, and the next command runs. Documents (design.md Worktrees bullet and change-log row, WORKTREE_GUIDE, script_reference rows, the gh_create_issue.sh header): true of the code. Tests: removed lines against origin/main 0.

Suites, each run with `bash`: test_gh_create_issue PASS 88 FAIL 0; test_worktree_create PASS 89 FAIL 0; test_ros2_colcon 1030 passed, 0 failed, 0 skipped; test_session_root 71 passed, 0 failed; test_register_project 201 passed, 0 failed; test_merge_pr 170 passed, 0 failed; test_package_issue_loop 220 passed, 0 failed; test_skill_paths 163 passed, 0 failed; test_gh_create_pr PASS 113 FAIL 0; `check_design_anchors.sh` exit 0.

### Findings
- [ ] (suggestion) `ROOT_NOT_GIT` tests `rev-parse --git-dir`, so a plain root nested in an enclosing repository (e.g. a git-tracked `$HOME`) takes the in-git path: a bare `--issue` is looked up in the enclosing repository's origin (or the workspace's), as on origin/main; a `--show-toplevel` equality test would match the docs' "top of its own repository" but changes behaviour against origin/main: owner call — `.agent/scripts/worktree_create.sh:604`
- [ ] (suggestion) The top-of-own-repository loop (round 1) is a behaviour change inside git: a nested root or nested entry is refused (origin/main made a worktree of the enclosing repository) and a manifest entry that is not a repository is refused before any worktree is made (origin/main refused later with the same message, after rollback); the Implementation entry says no script changes inside git, so name this exception in the PR description for the owner's veto — `.agent/scripts/worktree_create.sh:579-592`
- [ ] (suggestion) Run from inside a `.git` directory or a bare repository, origin/main exits 3 "Not in a git repository"; now it takes the outside-git path (needs `-R`); not an ordinary use — `.agent/scripts/gh_create_issue.sh:82`
- [ ] (suggestion) Outside git, the same-repository duplicate pattern `(^|[^0-9])#N` also matches `other/repo#N` in the body, so the reference is taken as present (the in-git pattern has the same weakness, pre-existing) — `.agent/scripts/gh_create_issue.sh:291`
- [ ] (suggestion) `-R` and the parent slug are compared case-sensitively: `-R Foo/Bar` with `foo/bar#5` gives a qualified reference rather than `#5` (still a correct link) — `.agent/scripts/gh_create_issue.sh:289`
- [ ] (suggestion) Outside git a `WORKTREE_ISSUE` that is neither a number nor `owner/repo#N` adds nothing and says nothing; an `else` warning would close it — `.agent/scripts/gh_create_issue.sh:315`

## Checkpoint
**When**: 2026-11-18 19:12 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 approved with no must-fix, and the full pre-commit pass, every script suite included, passed at 2912d5a6)
**After**: publish
**Decision**: publish

The full pass (every hook, no SKIP, over the files the branch changes) passed on 2912d5a6. Published as part 1A: the pull request says "Part of #503" and does not close the issue. Part 1B (the adapter's route for a directory the manifest tool set up, registration, the approved one-sentence edit to AGENTS.md) is built after issue 500 part 1 has merged. The owner's merge is asked for after an outside-model read of this pull request's final state.

## Local Review
**Status**: complete
**When**: 2026-11-18 19:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #513 at `32abb3cd`
**Depth**: Deep (reason: enforcement scripts worktree_create.sh and gh_create_issue.sh, a skill and docs/design.md; 11 files, +1631/-45)
**Must-fix**: 0 | **Suggestions**: 5

Round 1 of PR mode. Gemini and Codex both completed (EXIT=0) on the final state; Claude adversarial subagent completed. Every outside-model point checked against the code in a sandbox (copied suite fixture, stub gh; no real registry, no real gh issue create).

### Findings
- [ ] (suggestion) same-repository duplicate check `(^|[^0-9])#N` also matches another repository's `other/repo#N` in the body, so "Part of #N" is left out; same idiom as main's in-git path (line 259), worth changing only for both paths together, not here (Gemini, Codex; confirmed by regex) — `.agent/scripts/gh_create_issue.sh:291`
- [ ] (suggestion) workspace slug taken by the `.*github\.com[:/]` sed (matches notgithub.com) and compared case- and form-exactly with -R; only effect is which label list is used or a qualified "Part of"; the same sed is in six scripts on main; not worth doing here (Codex said must-fix, Gemini, Claude adversarial) — `.agent/scripts/gh_create_issue.sh:129`
- [ ] (suggestion) SB10's bare --issue case captures RC but does not assert exit 0 or that the worktree was made; two-line fix, worth doing (Gemini, Codex) — `.agent/scripts/tests/test_worktree_create.sh:1097`
- [ ] (suggestion) a root that is a file, not a directory, is reported "not a git repository" (main's text); not worth doing (Gemini) — `.agent/scripts/worktree_create.sh:553`
- [ ] (suggestion) an exported GH_REPO does not count as -R outside git (parser blanks it, as on main); clear refusal, not worth doing (Claude adversarial) — `.agent/scripts/gh_create_issue.sh:124`

Dropped as named in the PR body ("Found, not fixed here"): Gemini and Codex must-fix on `worktree_create.sh:603` (`rev-parse --git-dir` succeeds for a plain root nested in an enclosing repository, so ROOT_NOT_GIT stays false). Probe: a plain two-repo root registered under the workspace's ignored `projects/` (ADR-0016 decision 1) with a bare --issue 64 looked the issue up in the workspace's repository, accepted it and made the worktree; the `worktrees/` exclude went to the workspace's `.git/info/exclude`. As on main; the body's example (a home directory under version control) understates this case — open human call whether to fix now (both models propose the top-level check) or keep it named.

Checks: CI all 10 jobs pass (Lint x2, Validate Adapter Contract x2, Validate Documentation x2, repos-manifest 3.10/3.14 x2). Suites: test_gh_create_issue 88/0, test_worktree_create 89/0, test_ros2_colcon 1030/0, test_session_root 71/0, test_register_project 201/0, test_merge_pr 170/0, test_package_issue_loop 220/0, test_skill_paths 163/0, test_gh_create_pr 113/0; check_design_anchors exit 0; removed test lines 0; mergeable MERGEABLE.

## Integrated Review
**Status**: complete
**When**: 2026-11-18 19:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #513 at `4c58b157`
**Sources**: 3 (Local Review @ `32abb3cd` (covers 4c58b157 via bookkeeping; Gemini, Codex, Claude adversarial), Local Review (Pre-Push) @ `e03b2d10` (covers 4c58b157 via bookkeeping), CI rollup). Hosted reviews: none (0 reviews, 0 inline, 0 conversation comments).
**Cross-source confirmations**: 0 (no GitHub comments to correlate; the local review's own multi-model agreements are noted per finding)
**CI**: all-pass at the code head `32abb3cd` (10/10 jobs, both runs). At `4c58b157` (progress-only commit): 8 pass, Lint (pre-commit) x2 still pending after about 5 minutes.

Verdict: no must-fix; the code is ready for the owner's merge decision. One open item, a wording fix in the pull request body (no code). Mergeable: MERGEABLE.

### Findings
- [x] (suggestion, triage) PR body, "Behaviour that changes inside a git repository", first bullet says a project root that is a plain directory nested inside another git repository "is now refused". That holds only when the root itself is a worktree entry (`.`, a single-repository project: `resolve_worktree_repos` top check). A plain multi-repo root nested in a repository keeps `ROOT_NOT_GIT=false` (`rev-parse --git-dir` succeeds) and takes the in-git path, as the body's own "Found, not fixed here" third bullet says, so the two bullets read as contradictory. Reword bullet 1 to "a single-repository project's root (or a repo named for a package worktree) that is a plain directory nested inside another git repository" — `.agent/scripts/worktree_create.sh:566-606`
- [x] (suggestion, Local Review @ 32abb3cd; Gemini, Codex) `(^|[^0-9])#N` duplicate check matches `other/repo#N` — no action: same idiom as main's in-git path, change both together or not at all (host ruling) — `.agent/scripts/gh_create_issue.sh:291`
- [x] (suggestion, Local Review @ 32abb3cd; Codex said must-fix, Gemini, Claude) workspace slug sed / exact-case compare with -R — no action: same sed in six scripts on main, effect limited to label list choice or a qualified "Part of" (host ruling) — `.agent/scripts/gh_create_issue.sh:129`
- [x] (suggestion, Local Review @ 32abb3cd; Gemini, Codex) SB10 bare `--issue` captures RC without asserting it — deferred to part 1B, which extends the same suite; stated in the PR body's "Found, not fixed here" (host ruling) — `.agent/scripts/tests/test_worktree_create.sh:1097`
- [x] (suggestion, Local Review @ 32abb3cd; Gemini) a root that is a file reported "not a git repository" — no action: main's text, not worth doing (host ruling) — `.agent/scripts/worktree_create.sh:553`
- [x] (suggestion, Local Review @ 32abb3cd; Claude) exported GH_REPO not counted as -R outside git — no action: clear refusal, as on main (host ruling) — `.agent/scripts/gh_create_issue.sh:124`
- [x] (must-fix per Gemini and Codex; dropped by Local Review @ 32abb3cd) plain multi-repo root nested in an enclosing repository (e.g. under the workspace's ignored `projects/`) takes the in-git path: bare `--issue` looked up in the workspace's repository, `worktrees/` exclude written to the workspace's `.git/info/exclude`. Valid but pre-existing: same on origin/main; today's hosted layouts and fixtures are roots of this kind. Not changed here; named in the PR body's "Found, not fixed here" with the `projects/` case spelled out (verified); host to propose a separate issue to the owner — `.agent/scripts/worktree_create.sh:603`
- [x] (suggestions x6, Local Review (Pre-Push) round 3 @ e03b2d10) nested root via `--git-dir`; top-of-own-repository loop as an in-git behaviour change; `.git`-dir / bare-repo cwd takes the outside-git path; `#N` regex; case-sensitive slug compare; silent non-matching `WORKTREE_ISSUE` — no action, ruled by the host at the publish Checkpoint (the Checkpoint text itself records only "approved, no must-fix"; this entry records the ruling). The first two are named in the PR body (nested root under "Found, not fixed here", the loop under "Behaviour that changes"); the regex one duplicates PR-mode suggestion 1 — `.agent/scripts/worktree_create.sh`, `.agent/scripts/gh_create_issue.sh`

Earlier entries: Issue Review (lines 152-161) ruled by the Checkpoint at 17:38; Plan Review 1 (250-255) by the Checkpoint at 17:54; Plan Review 2 (357-362) by the Checkpoint at 18:09 (parts 1B to 4 are later pull requests). Pre-push rounds 1 and 2 closed by fix rounds. No open, unruled box remains.

PR body check against the host's account: Decision summary, Part of #503 (does not close), "Found, not fixed here" (nested plain root with the `projects/` case, SB10 deferred to 1B) all match. One inaccuracy: the first bullet under "Behaviour that changes", above.

### False positives
- None.

## Checkpoint
**When**: 2026-11-18 19:35 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

The owner chose "Merge (Recommended)" in a dialog (2026-11-18) for pull request 513 (part 1A: a project root need not be a git repository), with the nested-plain-root weakness left out of it as described to him: already so on main, not touching a root that is outside every repository, and a change of its own. The host proposes a separate issue for it afterwards. The issue stays open: part 1B and later parts remain.

## Checkpoint
**When**: 2026-11-18 20:13 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan file is unchanged since its last review, at 3f2dae10, and names a part not yet delivered; the owner chose "Merge and carry on" at the merge of pull request 512, naming part 1B)
**After**: plan
**Decision**: proceed

Pull request 513 (part 1A: a project root need not be a git repository) merged on 2026-11-18. The issue stays open. This pull request is part 1B ("Part of #503"): the adapter's route for a directory the manifest tool set up, and its registration. The tool's init and sync are on main since pull request 512 merged the same day, so the command line is checked against main.

Build the plan's part 1 except what part 1A delivered, with the second Plan Review's findings and the points below. Where this entry and the plan differ, this entry wins.

1. In scope: the dispatcher's calling-directory variable; the route chosen by .repos-manifest/ at the root, never falling back to a route that fetches; the distro rule in one place; the path helpers; setup and sync calling the tool's sync from the root; build and test with today's loop over the tool's layers (said to be interim); validate against the tool's last resolved files, refusing a second record; type detection in registration; the documents; tests with fixtures outside every git repository.
2. The owner's decisions, in his words (2026-11-18): one registration for the project, and "yes, the directory the session is started in decides" the distro; "yes, starting at ~/project11 is fine for the first cut" (a session started in <root>/<distro>/ is a later part); "yes to the AGENTS.md edit": the one sentence in Terminology becomes "A hosting service is optional; git is meant to be, and today only a single-repository project's own folder needs it." as its own commit, and nothing else in AGENTS.md changes.
3. The acceptance section and every document and test state the acceptance generically: a multi-repo project that the tool set up with a directory per distro is registered as one project; a session at its root runs the issue workflow on an issue of one of its package repos; the worktree's build script builds against the layers. No porting pattern, no order of work, and no project's repo names beyond the workspace's existing acceptance case. The owner (2026-11-18): how a project's port is handled is the project's, and he has not decided it: "Let me see once I get the project registered and have an agent working in it." The plan's example commands for a port are not carried into any tracked file.
4. From the second Plan Review: the two reworded rows of the table; the design says that a merge fast-forwards the root's clone of a package repo past the commit recorded in the tool's state.yaml, by the same move the tool's own sync would make, and that the tool's status should treat that as expected; the merge script's update of the clone stays as it is; the two-distro inconsistency between calls made from the caller's directory and the one made after a cd is named in the part 3 outline; the distro rule compares physical paths; worktree_env prints a note on stderr naming each lower layer with no install directory; the by-hand build steps use --continue-on-error per layer.
5. Carried from part 1A's reviews: the bare --issue test in test_worktree_create.sh for a root outside git asserts its exit status and that the worktree was made (a new assertion appended; no existing line changed). The sentences part 1A left because registration made them true only now: the header of register_session_root.sh, its row in script_reference.md, docs/design.md's "Registration needs a git repository today" and the onboarding bullet's known gap. Change each only if this part makes it untrue, and test what the new sentence claims.
6. A repo key with a directory in it (grp/repo): the tool supports it and part 1 of issue 500 tests it. The plan refused it by name because worktree_create.sh names a repo by the last part of its path. Keep that refusal for this part, by name, in validate and in the worktree verbs, and say so in the design; reading it is a later part.
7. Every assertion of today's suites stays as it is; today's routes are untouched; no project type's name in a general script; nothing under .github/.

## Implementation
**Status**: complete
**When**: 2026-11-18 20:41 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-503 at `a53288dc`

Part 1B (Checkpoint of 20:13): the ros2_colcon tool route for a root the manifest tool set up, and its registration. Commits, each "Part of #503":

- `87d3e633` adapter.sh and the dispatcher. `_rc_route` (the one route choice: `.repos-manifest/` at the root, else `source`, else bootstrap); `_rc_tool_distro_select` (the one distro rule: the calling directory, physical on both sides, else the one resolved distro, else refuse listing them); `_rc_layer_dir` (`<root>/<d>/<layer>`, `<root>/<d>` for `_unnamed`); `_rc_repos_file` (the one place a layer's `.repos` file is named, used by every caller); `_rc_is_optional_repo` (optional.txt); `_rc_tool_refuse_nested_keys`; `_rc_tool_sync` (setup and sync: the tool's `sync [--distro d]` in the root, status passed through, nothing pulled or fetched, the layers-changed line); `_rc_tool_validate` (checkouts against the last resolve, refuses role=/distro=/source/source_ref/source_path/bootstrap_url, says it did not read the manifest again); `_rc_colcon` (`--base-paths src` on the tool route). Tool branches added at the top of `_rc_manifest_dir`, `_rc_pin_manifest_dir`, `_rc_require_manifest`, `_rc_is_optional_layer`, `_rc_distro`, setup, sync, validate; the old branches unchanged. `worktree_env` notes each unbuilt lower layer on stderr (every route). The bootstrap no-URL refusal gains a line naming `init --distro-dirs`. Dispatcher: `ACTIVE_PROJECT_FROM`.
- `32b0f3b6` registration: type detected from `.repos-manifest/`; registration.conf comment; register_session_root.sh header and its script_reference row narrowed to a single-repository folder.
- `bfb30e84` test_worktree_create.sh: the SB10 bare --issue case asserts exit 0 and the worktree (part 1A review carry-over).
- `2028774d` docs: docs/manifest/design.md (three routes, "The tool route" section, the merge's fast-forward past state.yaml's commit, route order corrected, "Not decided" narrowed), roadmap (one new line, checked by `file-contains`, true), docs/design.md (three routes, ACTIVE_PROJECT_FROM, the registration/onboarding gap narrowed; change-log row), WORKTREE_GUIDE.
- `9fcccd91` AGENTS.md: the owner-approved sentence, nothing else (200 lines).
- `a53288dc` plan.md: the two table rows the second Plan Review reworded. It landed after the AGENTS.md commit; reordering (reset and cherry-pick) was denied by the permission system, so the host may reorder before the push.

New tests: test_ros2_colcon.sh test_tool_route_order, test_tool_unusable_root_is_an_error_never_a_fetch, test_tool_nested_key_refused_by_name, test_tool_distro_rule, test_tool_setup_and_sync_run_the_tool, test_tool_build_and_test_over_the_resolved_layers, test_tool_validate, test_tool_repos_pin_and_worktree_verbs, test_worktree_env_names_unbuilt_lower_layers, test_tool_package_worktree, test_bootstrap_no_url_names_the_tool, test_tool_real_init_and_sync (real tool and vcs; skipped with a message without vcs; ran here). Fixtures outside every git repository, resolved by this checkout's `repos-manifest resolve`. test_register_project.sh and test_register_session_root.sh: a tool root outside git registers (from the workspace, from its session); an unresolved one is refused and rolled back.

Suites, each with `bash` on the committed tree: test_ros2_colcon 1166 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 209/0; test_register_session_root 71/0; test_worktree_create 90/0; test_session_root 71/0; test_project_registry 425/0; test_package_issue_loop 220/0; test_merge_pr 170/0; test_skill_paths 163/0; validate_adapter.sh pass; check_design_anchors.sh exit 0; `git diff origin/main -- .agent/scripts/tests | grep -c '^-[^-]'`: 0. Hand run in a sandboxed workspace copy in the session scratchpad (its own registry): init, register, validate, sync, repos, repo_pin, env from the root and from rolling/, all exit 0. Full pre-commit pass left to the host.

Not built from the Checkpoint's points: none. Deviation: a nested repo key is refused by `_rc_require_manifest`, so by every verb except setup and sync, not only validate and the worktree verbs.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 20:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-503 at `a08e7ab3`
**Base**: origin/main
**Depth**: Deep (reason: enforcement scripts, the ros2_colcon adapter, AGENTS.md and design documents; ~1100 lines over 15 files)
**Must-fix**: 5 | **Suggestions**: 9
**Round**: 1 | **Ship**: continue — round 1: 5 must-fix; first round always re-reviews after fixes

Part 1B (after the Checkpoint of 20:13). Cross-model: Gemini and Codex both completed. Owner's use run by hand in the session scratchpad (sandboxed workspace copy, its own registry, local file remotes, real /opt/ros/rolling and colcon): a one-distro root registers from the workspace outside git, validate/sync/repos/repo_pin/env/worktree_repos pass from the root and from <root>/rolling/mid, build builds core, mid, top, worktree_create for a mid-layer repo starts its branch at origin/<pin> (base=dev recorded), env.sh sources distro, core, root's mid, the worktree's mid in that order, the NOTE for an unbuilt lower layer goes to stderr only, build.sh builds the package against the layers, enter and remove work. A root with two distros: registration refuses from the workspace and from its session; worktree_create from <root>/<d>/ fails at worktree_env (both deferred to part 3 by the plan's "Later parts", but no tracked document says so). All 10 suites, validate_adapter.sh and check_design_anchors.sh pass; tests diff removes 0 lines; AGENTS.md diff is exactly the approved sentence; --base-paths src only on the tool route; today's routes differ only by the two named changes.

### Findings
- [x] (must-fix) ADR-0021 still says "A folder in no git repository cannot be registered this way yet ... registration's gate (`adapter validate`) still requires a git repository"; a root the manifest tool set up now registers outside git from its session. The ADR is the owner's: add a dated note for him (or ask) — `docs/decisions/0021-a-project-session-may-register-its-own-folder.md:92`
- [x] (must-fix) onboard-project step 1 tells the agent a folder in no git repository is refused and "cannot be registered yet"; narrow to a single-repository folder, as register_session_root.sh, script_reference.md and docs/design.md were — `.claude/skills/onboard-project/SKILL.md:238`
- [x] (must-fix) "That is the move the tool's own `sync` makes to a clean repo" is untrue today: the tool's sync leaves a present repo untouched ("updating a repo that is there is not built yet", seen in the hand run); the Checkpoint said "would make" (Codex) — `docs/manifest/design.md:168`
- [x] (must-fix) A root with several distros: registration refuses it (gate runs validate from the workspace; the refusal advises "run from inside <root>/<distro>/ or pass --from", which registration cannot do), and worktree_create.sh from inside <root>/<d>/ picks d for worktree_repos/pr_base_for, then worktree_env after `cd "$ROOT_DIR"` refuses and rolls back. WORKTREE_GUIDE ("the distro the directory the call comes from chooses") and design.md's tool-route registration sentence claim more than is built. Either pass --from (the caller's directory) on worktree_create's later adapter call, or state the one-distro limit and the part 3 deferral in the documents and in the refusal (adversarial, Gemini, Codex) — `.agent/WORKTREE_GUIDE.md:302`, `docs/manifest/design.md:121`, `.agent/scripts/worktree_create.sh:1043`, `.agent/project_types/ros2_colcon/adapter.sh:795`
- [x] (must-fix) A root with nothing resolved (also a .repos-manifest that is a file, a dangling link or unreadable) is refused at registration with "Run: .agent/scripts/adapter --project <name> sync" for a project the rollback just removed; that command refuses ("not under a registered project root"). Name the tool's own `repos-manifest sync` in the root as the next step (adversarial; the new test asserts the wrong text) — `.agent/project_types/ros2_colcon/adapter.sh:773`, `.agent/scripts/tests/test_register_project.sh:1087`
- [x] (suggestion) One rule for repo keys on the tool route: refuse by name every key line `_rc_repos_entries` cannot read (a key with a directory in it is one case; a quoted key such as 'on', or one with other characters, is now silently passed over by validate, repos and repo_pin) (Codex) — `.agent/project_types/ros2_colcon/adapter.sh:809`
- [x] (suggestion) The comment "the tool replaces resolved/<distro>/ whole, by rename" implies an atomic swap; the tool renames twice, so a run during a sync can mix generations or see no layers (a build loop of zero layers then reports success). Correct the comment; optionally re-check layers.txt in the loops (Codex, adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:160`
- [x] (suggestion) Type detection tests `-e .repos-manifest` while `_rc_route` tests `-e || -L`: a dangling link is typed single_project at registration but routed to the tool by the adapter; use one test (Gemini, adversarial) — `.agent/scripts/register_project.sh:624`
- [x] (suggestion) validate on the tool route names a settings-file source as a second record but says nothing of a leftover configs/manifest or configs/project_bootstrap.url, which the route ignores silently — `.agent/project_types/ros2_colcon/adapter.sh:881`
- [x] (suggestion) A .repos-manifest that is a file, dangling or unreadable is reported as "nothing is resolved ... run sync"; only the tool's sync then says the record cannot be read. Say so directly (low value) — `.agent/project_types/ros2_colcon/adapter.sh:772`
- [x] (suggestion) The roadmap line's check is a string grep of adapter.sh; it is true but checks presence, not that the adapter reads a tool root. Prefer a check naming a behaviour (e.g. the tool-route tests) — `docs/manifest/roadmap.md:29` (deferred: host decision: no action; the check is a presence grep of adapter.sh, a limit the pull request body names)
- [x] (suggestion) worktree_env's NOTE tests the install/ directory while env.sh sources install/local_setup.bash; test the same file (Gemini) — `.agent/project_types/ros2_colcon/adapter.sh:2049`
- [x] (suggestion) A user's own --base-paths after the route's `--base-paths src` wins and on the unnamed layer brings back nested layers; not worth doing unless someone passes it (adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:1581` (deferred: host decision: no action; the review's own reason: not worth doing unless someone passes their own --base-paths)
- [x] (suggestion) ACTIVE_PROJECT_FROM's `cd` has no `--` and honours CDPATH (a relative --from with CDPATH set gives two lines); `CDPATH= cd --`; low value (adversarial, Gemini) — `.agent/scripts/adapter:273` (deferred: host decision: no action; the review's own reason: low value (a relative --from with CDPATH set))

## Implementation
**Status**: complete
**When**: 2026-11-18 21:09 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-503 at `34112d18`
**Addressed**: Local Review (Pre-Push) at `a08e7ab3` (2026-11-18 20:47 -05:00)
**Commits**: `4bd7a300` (code and tests), `ca45f435` (ADR-0021 note), `a7d09ef0` and `34112d18` (onboard-project), `7aab63af` (docs)

The fix round for part 1B. Each must-fix as the host decided it (listed for the owner's veto); each code fix stated as one rule, with a test that fails on the code before it (checked by running the new tests against the previous adapter.sh, worktree_create.sh and register_project.sh).

### Actions
- [x] (must-fix 1, host decision) ADR-0021: the owner's consequence is left as written; a dated note under it, in the commonest form of this repository's records ("Note (YYYY-MM-DD): ... (issue #N)"): "Note (2026-11-18): issue #503 narrowed this gap. A root the manifest tool set up (it holds `.repos-manifest/`) registers from its own session though it is in no git repository, since the gate's `adapter validate` checks its clones, not the root. A single-repository folder in no git repository is still refused." The pull request body names it for the owner — `docs/decisions/0021-a-project-session-may-register-its-own-folder.md:96`
- [x] (must-fix 2, host decision) onboard-project step 1 narrowed to a single-repository folder; the phrase test_skill_paths.sh checks ("registration needs a git repository today, a known gap") is kept. Grep for "no git repository", "cannot be registered", "needs a git repository" over skills, knowledge, WORKTREE_GUIDE and the design documents: no other sentence made untrue by this part (register_session_root.sh, script_reference.md and docs/design.md were narrowed in the implementation pass) — `.claude/skills/onboard-project/SKILL.md:238`
- [x] (must-fix 3, host decision) The merge's fast-forward is "the move the tool's `sync` is designed to make to a clean repo that is still on the manifest's version, and that part of `sync` is not built yet". Rest of the diff's documents checked: the NOTE's file and the "each act on one distro" sentence corrected — `docs/manifest/design.md:184`
- [x] (must-fix 4, host decision) Rule a: `validate` with no distro chosen checks every resolved distro, one after another, and fails naming each failing one ("failing distro: ..."); with a distro chosen, or one set up, that one; every other verb still refuses and lists the distros. The decision is `_rc_tool_distro_select --every`, where the distro rule lives; `_rc_require_manifest` is split into the selection and `_rc_check_manifest`. Rule b: `worktree_create.sh` makes every adapter call for one worktree from the directory it was called from (`CALLER_DIR`, passed with the dispatcher's `--from` on the `worktree_env` call after `cd "$ROOT_DIR"`). On today's routes this changes nothing: only the tool route's distro rule reads `ACTIVE_PROJECT_FROM` (grep), every project worktree's adapter calls carry `--project`, so discovery is not used, and the dispatcher's guard on `--from` sees the directory the earlier `worktree_repos` call was already guarded on. Tests: two-distro registration from the workspace and from its own session; validate from the root covers both and names the failing one; a package worktree from inside `<root>/fakefox/` succeeds with base=fakefox and env.sh naming only `<root>/fakefox/` layers; from the root refused before anything is made, listing the distros. WORKTREE_GUIDE and docs/manifest/design.md say which calls work from where, and that a session still starts at the root — `.agent/project_types/ros2_colcon/adapter.sh`, `.agent/scripts/worktree_create.sh:40,1046`, `.agent/WORKTREE_GUIDE.md:302`, `docs/manifest/design.md:132`
- [x] (must-fix 5, host decision) One helper, `_rc_tool_unusable`, refuses an unusable `.repos-manifest/`, saying what is wrong (not a directory; a link to nothing; cannot be read; nothing resolved yet; a flat layout) and naming the manifest tool's own command in the root by the workspace's installed path: "Run the manifest tool in the root: cd <root> && <main checkout>/.venv/bin/repos-manifest sync (then register it, or run the call again)"; for a flat layout its init --distro-dirs in an empty directory. The branch's register test assertion changed to it — `.agent/project_types/ros2_colcon/adapter.sh`, `.agent/scripts/tests/test_register_project.sh`
- [x] (suggestion 1) Every key line of a resolved .repos file that the reader cannot read is refused by name (`_rc_tool_refuse_unread_keys`, the reader's own pattern); a key with a directory in it is one case. Tested with 'on' and pkg+x — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] (suggestion 2) The comment says the tool replaces resolved/<distro>/ in two renames, not one atomic step; a build or test loop that goes over no layer on the tool route is an error (`_rc_tool_no_layers_seen`), tested by an underlay that moves the resolved directory aside between the check and the loop — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] (suggestion 3) Registration types a root by `.repos-manifest` with the adapter's route test (there, or a link, even a dangling one); a dangling link is now typed ros2_colcon and refused with "is a link to nothing" — `.agent/scripts/register_project.sh:624`
- [x] (suggestion 4) `validate` on the tool route notes, without failing, a leftover configs/manifest or configs/project_bootstrap.url — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] (suggestion 5) Covered by must-fix 5 — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] (suggestion 7) worktree_env's NOTE tests install/local_setup.bash, the file env.sh sources (its branch-added test assertions updated) — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] (suggestion 6) roadmap check — `docs/manifest/roadmap.md:29` (deferred: host decision, no action; the check is a presence grep of adapter.sh, a limit the pull request body is to name)
- [x] (suggestion 8) a user's own --base-paths — `.agent/project_types/ros2_colcon/adapter.sh` (deferred: host decision, no action; the review's reason: not worth doing unless someone passes it)
- [x] (suggestion 9) CDPATH in ACTIVE_PROJECT_FROM — `.agent/scripts/adapter:273` (deferred: host decision, no action; the review's reason: low value)

### Checks
Suites, each with `bash` on the committed tree: test_ros2_colcon 1241 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 213/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_session_root 71/0; test_project_registry 425/0; test_package_issue_loop 220/0; test_merge_pr 170/0; test_skill_paths 163/0 (it failed once on the first skill wording, which dropped a phrase it checks; fixed in `34112d18`). validate_adapter.sh: all 13 verbs for both types; check_design_anchors.sh exit 0; `git diff origin/main...HEAD -- .agent/scripts/tests | grep -c '^-[^-]'`: 0. shellcheck (the hook) passed on every changed script. Full pre-commit pass left to the host. AGENTS.md, CLAUDE.md and .github/ untouched; no project type's name added to a general script.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 21:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-503 at `a1a3a4a8`
**Base**: origin/main
**Depth**: Deep (reason: whole-branch classification: enforcement scripts, the ros2_colcon adapter, AGENTS.md, ADR and design documents; ~1500 lines over 18 files)
**Must-fix**: 2 | **Suggestions**: 7
**Round**: 2 | **Ship**: continue — round 2: 2 must-fix include a design/correctness concern (not mechanical)

Part 1B, fix-round re-review. Cross-model: Gemini and Codex both completed (EXIT=0); Claude adversarial completed. Round-1 findings: must-fix 1-5 fixed (ADR-0021 note true and in the repository's usual "Note (date): ... issue #N" form; onboard-project narrowed; "designed to make" matches design.md's sync section; several distros: validate covers all and names the failing one, worktree_create from inside <root>/<d>/ reads d throughout, refused from the root leaving nothing; _rc_tool_unusable names the tool's sync), suggestions 1-5 and 7 fixed; but the rule of must-fix 5 (name the tool, not an adapter verb) was applied to one helper only (must-fix 2 below). Hand run in the session scratchpad (sandboxed workspace copy, HOME and registry; two-distro root made by the installed `repos-manifest init --distro-dirs --distro rolling --distro jazzy --yes`, local remotes via a GIT_SSH_COMMAND stub): registers from the workspace and from its own session; validate from the root checks both, with a clone removed in jazzy fails "failing distro: jazzy", from inside rolling/ checks rolling only; setup, sync, build, test, repos, repo_pin, worktree_repos, env from the root refuse listing the distros (project_root and install answer); worktree_create from the root refused, no branch, no worktrees/ directory; from inside jazzy/ exit 0, base=jazzy, branch at origin/jazzy, env.sh names only jazzy paths; from rolling/ base=dev; --layer _unnamed works; enter works from jazzy/, rolling/ and the root; remove works from the root and from either distro directory. Unusable roots: the five messages are true; for nothing resolved the named sync fixes it; for a flat layout the init step is right. Tool-written keys my.pkg, pkg-x, 9pkg, MixedCase pass; setup still runs the tool on unread keys. A root with only the unnamed layer builds. Type detection and _rc_route use the same test. Today's routes: _rc_require_manifest split is identical on the old path (same body and messages); _rc_tool_no_layers_seen returns 0 off the tool route; --from "$CALLER_DIR" changes nothing there (guard already passed on the same directory at worktree_repos; ACTIVE_PROJECT_FROM read only by the tool route); output-only differences are the two named ones (worktree_env NOTE, bootstrap no-URL line). AGENTS.md diff is exactly the approved sentence. Suites (each with bash): test_ros2_colcon 1241/0/0 skipped; test_adapter 248/0; test_register_project 213/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_session_root 71/0; test_project_registry 425/0; test_package_issue_loop 220/0; test_merge_pr 170/0; test_skill_paths 163/0; validate_adapter.sh both types all 13 verbs; check_design_anchors.sh exit 0; tests diff removes 0 lines; no new project-type name in a general script beyond the in-scope detection line and a comment.

### Findings
- [x] (must-fix) The distro rule silently acts on another distro: step 1 matches only distros with resolved/<d>/layers.txt, so a call from inside <root>/<d2>/ whose resolve is missing, unreadable or mid-sync falls to step 2 and uses the one other distro (validate from rolling/core with resolved/rolling aside: "✅ ... for distro jazzy", rc 0; repo_pin answers jazzy; sync runs --distro jazzy). Also `validate --every` skips such a distro without a word and setup/sync never reach a distro the tool recorded but did not resolve. One rule: the distros the tool recorded (not only resolved) decide step 1, and a recorded distro without a usable resolve is refused naming the tool's sync for it (adversarial, Codex; reproduced) — `.agent/project_types/ros2_colcon/adapter.sh:826`
- [x] (must-fix) Next steps that fail when run literally: the unread-key refusal and validate's missing-.repos and not-checked-out lines say "run: .agent/scripts/adapter --project <name> sync"; at registration the project has just been rolled back ("not registered", reproduced), and on a root with several distros that sync refuses from the root or the workspace (reproduced). Apply must-fix 5's rule to every tool-route next step: `cd <root> && <bin> sync [--distro <d>]` from one helper (lead, adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:894,970,979`
- [x] (suggestion) Keys the tool writes quoted (yaml.safe_dump: '123', '1.5', 'on', 'yes', 'true', 'null') are refused, and the message says the adapter reads "letters, digits, '.', '_' and '-' alone", which these are; strip single quotes on the tool route (cheap) (adversarial; '123'/'on'/'yes' reproduced) — `.agent/project_types/ros2_colcon/adapter.sh:874`
- [x] (suggestion) For "not a directory", "a link to nothing" and "cannot be read", the named `repos-manifest sync` (then register) cannot repair it: the tool then refuses with its own reason (reproduced); name repairing it or the init step, keeping sync for "nothing resolved" (lead) — `.agent/project_types/ros2_colcon/adapter.sh:779`
- [x] (suggestion) validate's per-distro loop can pass having read no layer during a sync's two renames (the race build/test now guard); cases are piling up: one rule, read layers.txt once per distro on the tool route and refuse an empty read there, instead of a guard per loop (Gemini, Codex) — `.agent/project_types/ros2_colcon/adapter.sh:966`
- [x] (suggestion) The several-distros refusal says "or pass --from <root>/<distro>", which worktree_create.sh (worktree_repos, pr_base_for) and dispatch_phase.sh do not take; name only "from inside" when no --from can be passed, or both scripts' situation (adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:857`
- [x] (suggestion) The init steps named in the flat-layout and bootstrap no-URL messages omit --yes, which an agent without a terminal needs (adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:561,780` (deferred: host decision: no message names init for a run without a terminal (the flat-layout and bootstrap no-URL steps are for a person at a terminal, where the tool asks before fetching, as the owner intends), so no --yes added)
- [x] (suggestion) WORKTREE_GUIDE could say that /run-issue and /start-task, run from a session at the root, cannot make a package worktree on a root with several distros today (the worktree script is run from inside <root>/<distro>/) (adversarial) — `.agent/WORKTREE_GUIDE.md:302`
- [x] (suggestion) The pin reader leaves a YAML escape the resolver writes for a non-ASCII branch ("topic/\xE9", reproduced) undecoded; pre-existing reader, fails loudly; not worth doing now (Codex) — `.agent/project_types/ros2_colcon/adapter.sh:2396` (deferred: host decision: no action; the review's own reason: pre-existing reader, fails loudly, not worth doing now)

## Implementation
**Status**: complete
**When**: 2026-11-18 21:39 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-503 at `967995b7`
**Addressed**: Local Review (Pre-Push) at `a1a3a4a8` (2026-11-18 21:31 -05:00)
**Commits**: `dad3e40e` (adapter.sh and tests), `967995b7` (docs)

The second fix round for part 1B, each decision the host's (listed for the owner's veto). Fewer rules: the distro rule, the one read of layers.txt and the one sync step replace the per-loop guards and the per-message commands. Each code fix has a test that fails on the adapter.sh before it (run against HEAD's adapter.sh: 59+ failures in test_ros2_colcon, 5 in test_register_project).

### Actions
- [x] (must-fix 1, host decision) `_rc_tool_distro_select`: from inside `<root>/<x>/` (a top-level directory other than `worktrees` and dot names, both sides physical) the distro is x and only x; elsewhere the one directory under `resolved/` (dot names, the tool's temporary ones, left out), else validate checks each and every other call is refused, listed. `layers.txt` is read once per distro per call (`_rc_tool_read_layers`, from `_rc_check_manifest`; `_rc_layers` gives that read on the tool route), an empty or missing read refused naming `cd <root> && <tool> sync --distro <d>`, so validate fails by name on a half-written `resolved/<d>/`. setup/sync choose by the same steps without the read (`--sync`). The host's rule differs from the review's wording (the tool's recorded distros): the adapter does not read config.yaml, so a non-distro top-level directory is taken as one and refused; docs/manifest/design.md says so and why. Tests: test_tool_distro_rule_never_moves_on, test_tool_layers_read_once_per_call — `.agent/project_types/ros2_colcon/adapter.sh`, `docs/manifest/design.md`
- [x] (must-fix 2, host decision) One helper, `_rc_tool_sync_step [d]`, prints `cd <root> && <tool> sync [--distro d]` for: the unread-key refusal, validate's missing .repos and not-checked-out lines, nothing resolved, and the unusable-resolve refusal. No tool-route message names `adapter --project <name> sync` (the remaining ones are on the manifest route). Tests run each printed step literally: test_tool_sync_steps_run_literally (stub tool, two distros: not checked out, missing .repos, unread key), nothing resolved in test_tool_unusable_root_is_an_error_never_a_fetch, and in test_register_project the real tool after a refused, rolled-back registration (nothing resolved; a clone missing): the step exits 0 and registration then passes — `.agent/project_types/ros2_colcon/adapter.sh`, `.agent/scripts/tests/test_register_project.sh`
- [x] (suggestion 1) On the tool route the reader takes a key in single quotes, unquoted; the unread-key refusal says "bare or in single quotes". test_tool_quoted_keys_from_the_tool: keys '123', 'on', '1.5' written by this checkout's resolver; validate, repos and repo_pin read them — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] (suggestion 2) Inside `_rc_tool_unusable`: not a directory, a link to nothing, cannot be read name fixing or removing the path and setting up again with `init --distro-dirs`; only nothing resolved names sync — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] (suggestion 3) Covered by must-fix 1's single read; the build/test guard `_rc_tool_no_layers_seen` and its counters came out (adapter_build/adapter_test back to main's loop, but for `_rc_colcon`) — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] (suggestion 4) The several-distros refusal: "Run the command from inside <root>/<distro>/ (a call to .agent/scripts/adapter itself may instead give its own --from ...)" — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] (suggestion 5) No message is about a run without a terminal: no change — `.agent/project_types/ros2_colcon/adapter.sh` (deferred: host decision)
- [x] (suggestion 6) One sentence in WORKTREE_GUIDE — `.agent/WORKTREE_GUIDE.md`
- [x] (suggestion 7) pin reader escape — (deferred: host decision, the review's own reason)

### Checks
Suites, each with `bash` on the committed tree: test_ros2_colcon 1314 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 222/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_session_root 71/0; test_project_registry 425/0; test_package_issue_loop 220/0; test_merge_pr 170/0; test_skill_paths 163/0. validate_adapter.sh: all 13 verbs for both types; check_design_anchors.sh exit 0; `git diff origin/main...HEAD -- .agent/scripts/tests | grep -c '^-[^-]'`: 0. shellcheck (the hook) passed. Full pre-commit pass left to the host. AGENTS.md, CLAUDE.md, docs/decisions/ and .github/ untouched; no project type's name in a general script; config.yaml and state.yaml not read.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 21:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-503 at `a7975c41`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Part 1B, round-3 convergence check on the round-2 findings and the fix diff since ce15236c (dad3e40e, 967995b7). Cross-model: skipped (round-3 convergence check, per handoff). Specialists: static analysis (shellcheck --severity=warning on adapter.sh and the two suites: clean), governance, plan drift, a fresh Claude adversarial reviewer. Round-2 findings: must-fix 1 fixed (from inside <root>/<d>/ every verb answers d or refuses naming `cd <root> && <tool> sync --distro d`; validate from the root fails by name on a resolved/<d>/ with no usable layers.txt), must-fix 2 fixed (every tool-route sync step from _rc_tool_sync_step; the remaining `adapter --project` lines, 291, 1082, 1656-1694, 1948, are on the manifest and bootstrap routes only), suggestions 1-4 and 6 fixed, 5 and 7 no action (host). Hand run in the session scratchpad (sandboxed workspace copy, HOME and registry; one- and two-distro roots by the installed `repos-manifest init --distro-dirs --yes`, file:// remotes, gh/git-bug stubbed offline): two distros with resolved/rolling moved aside or its layers.txt emptied: validate, build, test, env, repos, repo_pin, worktree_repos, worktree_env from inside rolling/ refuse naming rolling and `sync --distro rolling`, none answers lyrical; setup and sync there run `sync --distro rolling`; validate from the root fails "failing distro: rolling" on the emptied file; the printed step run literally from / exits 0 and validate then passes; from <root>/worktrees/x one distro is chosen, two refused. After a rolled-back registration (nothing resolved; a clone missing in lyrical; rolling's layers.txt emptied) the printed step run literally exits 0 and registration then passes. One distro: register; validate/sync/repos/repo_pin/env from the root, rolling/ and rolling/mid/src/pkg_mid; build and test; a package worktree for pkg_mid from the root (env.sh: distro, _unnamed, core, mid, the worktree's mid_ws in that order; build.sh builds; enter; remove). Misfires: manifest file at the root, symlinked root (and a registry line through a link), trailing slash and `.`, a resolve whose <root>/<d>/ is missing: correct; a deleted cwd and a --from to a deleted directory are refused by the dispatcher. Single-quoted keys read; double-quoted and escaped keys refused by name. adapter_build/adapter_test equal main but for `_rc_colcon`; no tool-route build/test/validate can pass having read no layer. Today's routes: no changed line since ce15236c is reachable there (the _rc_check_manifest if/elif chain is equivalent; quoted=0 and the gsub is a no-op off the tool route); differences from main stay the two named. Tests diff removes 0 lines; AGENTS.md is exactly the approved sentence; CLAUDE.md and .github/ untouched; docs/decisions/ only the ADR-0021 note. Suites (each with bash): test_ros2_colcon 1314 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 222/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_session_root 71/0; test_project_registry 425/0; test_package_issue_loop 220/0; test_merge_pr 170/0; test_skill_paths 163/0; validate_adapter.sh all 13 verbs for both types; check_design_anchors.sh exit 0.

### Findings
- [x] (suggestion) From the root or the workspace, a distro whose resolve is aside (between the tool's two renames, `.<d>.old-*`, or left so by a kill until its next run; or resolved/<d>/ removed) is not counted: step 2 picks the other distro and validate passes for it alone (reproduced; registration's gate would pass). Inside the host's rule as written; cheap: count `.<d>.old-*`/`.<d>.new-*` as d, unusable (adversarial, lead) — `.agent/project_types/ros2_colcon/adapter.sh:793`
- [x] (suggestion) From a top-level directory that is not a distro (notes/, or a link such as current -> jazzy, which also sorts before the distro it points to), the refusal blames "a sync cut short" and names `sync --distro notes`, which the tool refuses ("does not record it"); when resolved/<x>/ does not exist, say so and name running from the root or a distro's directory too (lead, adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:842`
- [x] (suggestion) `sync` from inside <root>/<d>/ with no previous resolve prints "the layers of distro d changed; existing package worktrees keep their old env.sh" though none existed; print it only when there was a previous read; low value (lead) — `.agent/project_types/ros2_colcon/adapter.sh:991` (deferred: host decision (Checkpoint 2026-11-18 21:48): no action)
- [x] (suggestion) _rc_tool_unusable's repair line says "the directory the manifest tool made there" also when .repos-manifest is a file or a link to nothing; cosmetic, not worth doing alone (adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:827` (deferred: host decision (Checkpoint 2026-11-18 21:48): no action)

## Checkpoint
**When**: 2026-11-18 21:48 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the round-3 review approved with 0 must-fix; two of its suggestions are a wrong answer and an untrue message inside the host's own distro rule, cheap to fix before publishing)
**After**: publish
**Decision**: address

Fix suggestions 1 and 2 of the round-3 review before the push; 3 and 4 take no action.

1. A distro whose resolve the tool has set aside (a directory .<d>.old-* or .<d>.new-* under .repos-manifest/resolved/, between the tool's two renames or after a kill there) counts as distro <d> with an unusable resolve: a call from outside every distro's directory does not pick "the one other distro" past it, and validate over every distro fails on it by name with the tool's sync step. Read how the tool names those directories (tools/repos-manifest/src) and match exactly that; one rule in the function that lists the distros.
2. A call from inside a top-level directory <x> of the root for which the tool has no resolve at all (no resolved/<x>/ and nothing set aside for it) gets a true message: <x> is not a distro the tool has resolved here; run the command from the root or from inside a distro's directory (listing them), or, if <x> is a distro being added, run the tool's sync for it. It does not say a sync was cut short.

Each with a test that fails before it; the documents' sentence on the rule is updated to match. Nothing else changes.

## Implementation
**Status**: complete
**When**: 2026-11-18 21:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-503 at `f84bbd0a`
**Addressed**: Local Review (Pre-Push) at `a7975c41` (2026-11-18 21:47 -05:00)
**Commits**: `f84bbd0a` (adapter.sh, test_ros2_colcon.sh, docs/manifest/design.md; both fixes, one commit: they change the same distro list and step 1)

The third fix round for part 1B, per the host's Checkpoint (2026-11-18 21:48). Each fix has a test that failed on the adapter.sh before it (a filtered run of the four distro-rule tests: 23 failures before, 0 after).

### Actions
- [x] (suggestion 1) `_rc_tool_distros` counts a directory the tool set aside while replacing `resolved/<d>/` as d. Names matched to the tool's `_TEMP_NAME` in tools/repos-manifest/src/repos_manifest/output.py (`.<d>.new-<pid>-<random>` / `.<d>.old-...`, random = mkdtemp's 8 of `[a-z0-9_]`, made in resolved/ beside the out directory); other dot names still left out. Both the one-distro choice and validate's every-distro list see it; usability stays `_rc_tool_read_layers`'s. Test test_tool_set_aside_resolve_is_a_distro: two distros, fakefox set aside as `.old-` and as `.new-`: env from the root refused listing both, nothing for fakefox2; validate from the root exit 1, "(failing distro: fakefox)", `cd <root> && repos-manifest sync --distro fakefox`; one distro set aside and no other: refused naming it with that step; a dot name not the tool's is not counted — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] (suggestion 2) From `<root>/<x>/` with nothing under resolved/ for x (no resolved/<x>/, nothing set aside): "ERROR: <x> is not a distro the manifest tool has resolved in <root> (nothing under <root>/.repos-manifest/resolved/ for it)" / "Run the command from <root> or from inside a distro's directory (<root>/<d>, ...); if <x> is a distro being added, run: cd <root> && repos-manifest sync --distro <x>". The link case: the calling directory is physical, so before this a call from `<root>/current -> fakefox2` and from `<root>/fakefox2` itself both matched "current" first (name order) and were refused; step 1 now takes a resolved distro first where two names lead to the calling directory, so both are fakefox2 and answer. Test test_tool_not_a_distro_directory (notes/: env and validate; the link: validate from current/, env from fakefox2/core). test_tool_distro_rule_never_moves_on (this branch's) now sets fakefox aside under the tool's own name, as a resolve that cannot be used, and its notes/ lines moved to the new test — `.agent/project_types/ros2_colcon/adapter.sh`, `docs/manifest/design.md`
- [x] (suggestion 3) no action (deferred: host decision)
- [x] (suggestion 4) no action (deferred: host decision)

### Checks
Suites, each with `bash` on the committed tree: test_ros2_colcon 1340 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 222/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_package_issue_loop 220/0. validate_adapter.sh: all 13 verbs for both types; check_design_anchors.sh exit 0; `git diff origin/main...HEAD -- .agent/scripts/tests | grep -c '^-[^-]'`: 0. shellcheck (the hook) passed. Full pre-commit pass left to the host. AGENTS.md, CLAUDE.md, docs/decisions/ and .github/ untouched; config.yaml and state.yaml not read; today's routes untouched (every change is in the tool-route functions).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 22:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-503 at `e637161e`
**Base**: origin/main
**Depth**: Deep (reason: round 4 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 6
**Round**: 4 | **Ship**: continue — round 4: must-fix rising (0 -> 1); the one must-fix is a mechanical rewording of one design sentence

Part 1B, round-4 convergence check on the round-3 findings and the fix diff since a7975c41 (f84bbd0a: adapter.sh, test_ros2_colcon.sh, docs/manifest/design.md). Cross-model: skipped (round-4 convergence check, per handoff). Specialists: static analysis (shellcheck --severity=warning on adapter.sh and test_ros2_colcon.sh: clean), governance and plan drift (the diff is the Checkpoint's two fixes and nothing else; the link rule beyond its wording is the host's, accepted), a fresh Claude adversarial reviewer. Round-3 findings: suggestions 1 and 2 fixed; 3 and 4 no action (host). Hand run in the session scratchpad (sandboxed workspace copy, registry and HOME; roots by the installed `repos-manifest init --distro-dirs --yes`, file:// remotes, gh stubbed): the match is output.py's _TEMP_SUFFIX exactly, and the tool's distro names are `[a-z][a-z0-9_]*` (schema.py), so a dotted capture cannot come from the tool and a made-up one (.ro.lling.old-...) is refused by name, uppercase or 7-char randoms are not counted. Two distros, rolling set aside as .old- and as .new-: env, repos, repo_pin, build from the root refuse listing both (exit 1); validate from the root exit 1 "(failing distro: rolling)" with `cd <root> && repos-manifest sync --distro rolling`, which run literally from / exits 0, after which validate passes for both; from lyrical/ env answers lyrical. Mid-swap (resolved/rolling and .rolling.new-* together): listed once, validate passes, rolling/ answers. Registration's gate with one set aside: refused naming rolling and the step. From notes/: the new message, exit 1; from a link current -> lyrical: lyrical (env, validate); a link to outside the root and outside itself: the dispatcher's existing refusal; worktrees/x: several distros, refused. One distro: validate, sync, repos, repo_pin, env from the root and from rolling/ all correct; a package worktree for nav_core made from the root (env.sh: distro, underlay, core, the worktree's core_ws in order; removed). The three changed functions are called only on the tool route; tests diff vs origin/main removes 0 lines (7 lines removed vs a7975c41 are this branch's own test, moved). Suites (each with bash): test_ros2_colcon 1340 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 222/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_package_issue_loop 220/0; validate_adapter.sh all 13 verbs for both types; check_design_anchors.sh exit 0.

### Findings
- [x] (must-fix) "a link there to a distro's directory is that distro" is false where the target has nothing under resolved/ (reproduced: link aaa -> rolling, resolved/rolling gone: from rolling/ the call is taken as aaa and names `sync --distro aaa`, which the tool refuses) and where the link's own name is a resolved distro (link abc_x -> lyrical with resolved/abc_x: from lyrical/ abc_x answers); state it as the code has it, e.g. "a link there to a distro's directory is that distro when the target is under resolved/ and the link's name is not" (the header's "so a link is its target", adapter.sh:68 and 905, likewise) — `docs/manifest/design.md:141`
- [x] (suggestion) Two names under resolved/ both leading to the calling directory: the first by name wins without a word (pre-existing, contrived: a distro's directory replaced by a link); refusing then closes the only silent-wrong-distro case left; cheap (adversarial, reproduced) — `.agent/project_types/ros2_colcon/adapter.sh:910`
- [x] (suggestion) A set-aside .<d>.new-*/.old-* left after resolved/<d>/ was deleted by hand keeps d counted, and the refusal says "a sync cut short, or one running now"; naming the leftover directory would help; low value (adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:862` (deferred: host decision (Checkpoint 2026-11-18 22:00): no action)
- [x] (suggestion) The comment on the tool-route setup/sync ("nothing resolved ... sync runs with no --distro") does not say a set-aside resolve now counts as resolved (only .<d>.old-* runs `sync --distro d`); low value (adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:997`
- [x] (suggestion) "if <x> is a distro being added, run: ... sync --distro <x>" works only when config.yaml already records x; the installed tool has no add-distro and refuses it otherwise ("this system does not record it"); the host's wording, not worth changing alone (lead) — `.agent/project_types/ros2_colcon/adapter.sh:860` (deferred: host decision (Checkpoint 2026-11-18 22:00): no action)
- [x] (suggestion) validate from notes/ ends "(failing distro: notes)" right after "notes is not a distro"; cosmetic, not worth doing alone (lead) — `.agent/project_types/ros2_colcon/adapter.sh:1089` (deferred: host decision (Checkpoint 2026-11-18 22:00): no action)
- [x] (suggestion) Not worth doing: `sort -u` follows the caller's collation (line 251 uses LC_ALL=C; same order for [a-z0-9_] names), and a resolved/<x> that is a file gets "nothing under resolved/ for it" (the tool never makes one) (adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:811` (deferred: host decision (Checkpoint 2026-11-18 22:00): no action)

## Checkpoint
**When**: 2026-11-18 22:00 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (first host answer at rounds for this pull request; the one must-fix is a sentence that says more than the code does, and it comes from a link rule that has grown cases; one simpler rule removes them)
**After**: rounds
**Decision**: address

Replace the link handling in step 1 of the distro rule by one rule, and state exactly that rule in the design paragraph and the adapter's header:

Step 1 looks only at real directories directly under the root (the root taken as a physical path; entries that are links are not candidates; worktrees and dot names excluded as now). The calling directory, as a physical path, is inside at most one of them: that one is <x>. A call that arrives through a link to a distro's directory is therefore inside the directory the link points to, and no name-order or "which of two names is resolved" choice exists. A calling directory under the root but inside none of them (the root itself, worktrees/, a link's target outside the root) goes to step 2 as now.

This fixes the must-fix (docs/manifest/design.md:141 and the header's "so a link is its target", reworded to the rule above) and suggestion 1 (two names leading to one directory can no longer pick by name order). Remove the code the earlier preference needed. Suggestions 2 to 6 take no action, except 3: the comment on setup/sync says a set-aside resolve counts as resolved.

Tests: a link current -> <distro> with the distro resolved: a call from current/ and from the distro's own directory both answer for the distro; with the distro's resolve set aside or gone, both name the distro (never the link's name); a link whose own name has a directory under resolved/ does not make a call from its target answer for the link's name. Each fails before the change where the behaviour changes.

## Implementation
**Status**: complete
**When**: 2026-11-18 22:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-503 at `e18bdcc8`
**Addressed**: Local Review (Pre-Push) at `e637161e` (2026-11-18 22:08 -05:00)
**Commits**: `e18bdcc8` (adapter.sh, test_ros2_colcon.sh, docs/manifest/design.md: one rule, one commit)

The fourth fix round for part 1B, per the host's Checkpoint (2026-11-18 22:00). Step 1 of the distro rule now looks only at real directories directly under the physical root (a link there is never a candidate; worktrees and dot names excluded as before); the calling directory, physical, is inside at most one, which is <x>. The name-order and "prefer the name under resolved/" code is gone (adapter.sh: 19 added, 28 removed). The header and the design paragraph state the rule as "a real directory (not a link) directly under the physical root", and the design sentence "a link there to a distro's directory is that distro" is removed.

### Actions
- [x] (must-fix) The design sentence and the header's "so a link is its target" replaced by the rule itself — `docs/manifest/design.md:134`, `.agent/project_types/ros2_colcon/adapter.sh:58`
- [x] (suggestion 1) Two names leading to one directory cannot pick by name order: a link is no candidate. Test test_tool_links_are_not_candidates: link current -> fakefox2, from current/ and fakefox2/: resolved, both answer fakefox2; resolve set aside, both name fakefox2 unusable, never "current"; resolve gone, both "fakefox2 is not a distro ...", never "current"; link abc_x -> fakefox2 with resolved/abc_x, from fakefox2/ and abc_x/: fakefox2's underlay, not abc_x's. On the adapter before the change: 10 failures (the gone and abc_x cases; the set-aside case already named fakefox2); after: 0 — `.agent/project_types/ros2_colcon/adapter.sh:899`
- [x] (suggestion 3) The setup/sync comment says a resolve the tool set aside counts as resolved — `.agent/project_types/ros2_colcon/adapter.sh:991`
- [x] (suggestion 2) no action (deferred: host decision)
- [x] (suggestion 4) no action (deferred: host decision)
- [x] (suggestion 5) no action (deferred: host decision)
- [x] (suggestion 6) no action (deferred: host decision)

### Checks
Suites, each with `bash` on the working tree of e18bdcc8: test_ros2_colcon 1362 passed 0 failed 0 skipped; test_adapter 248 passed 0 failed; test_register_project 222/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_package_issue_loop 220/0. validate_adapter.sh: all 13 verbs for both types; check_design_anchors.sh exit 0; `git diff origin/main...HEAD -- .agent/scripts/tests | grep -c '^-[^-]'`: 0. shellcheck passed in the commit hook (not on PATH for a direct run). Full pre-commit pass left to the host. AGENTS.md, CLAUDE.md, docs/decisions/ and .github/ untouched; config.yaml and state.yaml not read; today's routes untouched (the change is inside _rc_tool_distro_select and its comments).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 22:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-503 at `93e2693b`
**Base**: origin/main
**Depth**: Deep (reason: round 5 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 5 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Part 1B, round-5 convergence check on the round-4 findings and the fix diff since 497427c5 (e18bdcc8: adapter.sh, test_ros2_colcon.sh, docs/manifest/design.md). Cross-model: skipped (round-5 convergence check, per handoff). Specialists: static analysis (shellcheck --severity=warning on adapter.sh and test_ros2_colcon.sh: clean), governance and plan drift (the diff is the Checkpoint's one rule and the setup/sync comment, nothing else; the rule is the host's), a fresh Claude adversarial reviewer (no must-fix; `(a || b) && continue` precedence, `"$x"/*` prefix match, no dotglob, `list` and `_rc_tool_distros` still used; the new test fails on the old code in the gone and abc_x cases). Round-4 must-fix and suggestions 1 and 3: fixed; 2, 4, 5, 6: no action (host). Hand run in the session scratchpad (sandboxed workspace copy, registry and HOME; roots by the installed `repos-manifest init --distro-dirs --yes`, file:// remotes, gh stubbed): link aaa -> rolling with resolved/rolling gone: env and validate from rolling/ and aaa/ refuse naming rolling and `sync --distro rolling`, never aaa; sync from aaa/ runs `sync --distro rolling`, after which both answer rolling. Link abc_x -> lyrical with resolved/abc_x: env and repos from lyrical/ and abc_x/ answer lyrical. Registry line through a link (lk -> <H>/lklink): env from the link root and its rolling/, with and without --project, and validate: correct. Session dir through a link to a two-distro root: from twolink/lyrical lyrical; from twolink refused listing both; validate checks both. A distro directory that is a link to outside the root (two and one distro): the dispatcher's existing refusal ("<target> is neither inside the workspace nor under a registered project root"), true. worktrees/x and the root on two distros: refused listing both; deep package dirs: the right distro. One distro: validate, sync, repos, repo_pin, env from the root and rolling/ correct; package worktree for nav_core from the root: env.sh distro, underlay, core, the worktree's core_ws in order; entered; env from it rolling; removed. Two distros: each from its own directory right; from the root validate checks both, env, repos, repo_pin, sync, build refuse listing both (exit 1). The change is inside _rc_tool_distro_select (tool route only); `git diff origin/main...HEAD -- .agent/scripts/tests | grep -c '^-[^-]'`: 0. Suites (each with bash): test_ros2_colcon 1362 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 222/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_package_issue_loop 220/0; validate_adapter.sh all 13 verbs for both types; check_design_anchors.sh exit 0.

### Findings
- [ ] (suggestion) The design paragraph says "the physical root" but not that the calling directory is taken as a physical path too, so a reader cannot tell that a call from a link <root>/aaa -> rolling is for rolling (the header says it); one phrase, and reflow the 24- and 131-character lines; not a false sentence (lead, adversarial) — `docs/manifest/design.md:133`
- [ ] (suggestion) Not worth doing: a root that can be entered but not listed makes the glob empty, so step 1 is skipped and a call from a non-distro directory on a one-distro root goes to that distro; the tool never makes such a root (adversarial, from the code) — `.agent/project_types/ros2_colcon/adapter.sh:902`

## Checkpoint
**When**: 2026-11-18 22:14 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the round-5 pre-push review approved with 0 must-fix; the full pre-commit pass over the branch's files passed)
**After**: publish
**Decision**: publish

Publish part 1B as its own pull request ("Part of #503"). Carried into the first round on the pull request: the round-5 suggestion that the design's distro paragraph also say the calling directory is taken as a physical path.

## Local Review
**Status**: complete
**When**: 2026-11-18 22:26 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #514 at `3dd61876`
**Depth**: Deep (reason: whole-diff classification: the ros2_colcon adapter, the dispatcher, registration and worktree scripts, AGENTS.md, an ADR note and design documents; 2162 lines over 20 files)
**Must-fix**: 0 | **Suggestions**: 5

PR mode, round 1. Cross-model: Gemini completed (EXIT=0), Codex completed (EXIT=0) (run with --issue 503: the body says "Part of", no closing keyword); a fresh Claude adversarial reviewer completed. Static analysis: shellcheck --severity=warning on the nine changed scripts: clean. Hand run in the session scratchpad (a clone of the branch as its own main checkout and registry, HOME sandboxed, gh and git-bug stubbed, remotes local over file:// and an ssh stub), following docs/manifest/design.md, WORKTREE_GUIDE and the onboarding skill: one distro, three layers (installed `repos-manifest init --distro-dirs --yes`): register_session_root.sh --dry-run then real, STATUS=registered outside git; validate, sync (the tool's "present, not touched"), build.sh and test.sh over core, mid, top with real colcon on /opt/ros/rolling: exit 0; package worktree for mid_a from the root: base=rolling, branch feature/issue-11 at origin/rolling, NOTE for the unbuilt core layer on stderr only; env.sh distro, core, mid, the worktree's mid in order; build.sh builds against the layers; enter; remove. Two distros (rolling, lyrical), registered from the workspace with register_project.sh: validate from the root checks both; sync and build from the root refused listing both; from lyrical/ validate, sync, build, test pass; worktree from the root refused, nothing made; from lyrical/ base=lyrical, env.sh lyrical only, build.sh and test.sh pass, entered from the root and rolling/, removed; from rolling/ base=rolling, no lyrical path, removed from lyrical/. Documents and behaviour agreed throughout. Today's routes: no unnamed difference (the old _rc_require_manifest checks and messages unchanged in _rc_check_manifest; _rc_repos_file gives the same path; quoted keys read only on the tool route; --from "$CALLER_DIR" passes the directory the dispatcher already guarded for worktree_repos and pr_base_for); tests diff removes 0 lines. AGENTS.md diff is exactly the approved sentence. Dead code: none (every new helper called; removed helpers referenced nowhere; every new test function run). Suites (each with bash): test_ros2_colcon 1362 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 222/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_session_root 71/0; test_project_registry 425/0; test_package_issue_loop 220/0; test_merge_pr 170/0; test_skill_paths 163/0; validate_adapter.sh all 13 verbs for both types; check_design_anchors.sh exit 0. CI: all five jobs pass on both runs. Not findings: Gemini 1 and the adversarial's "distro being added" step (round-3 s3 and round-4 s5, no action recorded); Codex 2 and 5 and Gemini 2 (the tool's schema: distros [a-z][a-z0-9_]*, repo names not starting with '.' or '-'); Gemini 4 (the dispatcher refuses a --from that is not a directory); Gemini 3, 5, 6, Codex 3, 4 (shapes the tool never writes, or the same -d and reader semantics as the other two routes): not worth doing. PR body: "Each reviewer set up systems with the installed tool ... and ran registration, every verb and a package worktree" is untrue of Gemini and Codex, which read the diff.

### Findings
- [ ] (suggestion) The distro paragraph does not say the calling directory is taken as a physical path too (carried from round 5); and "or `sync` with no `--distro` when nothing is resolved yet" (also the header) holds only from outside every distro's directory: from <root>/<x>/ it passes --distro x (lead, adversarial) — `docs/manifest/design.md:133,159`, `.agent/project_types/ros2_colcon/adapter.sh:72`
- [ ] (suggestion) The header's opening still says the adapter "reads the manifest from the hosting dir only" and "Two routes to that directory (issue #436)", while the tool route is checked first (line 22); say three routes (adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:5-11`
- [ ] (suggestion) "(else it says it fetched only: `git -C <clone> pull`)" reads as merge_pr.sh's output; it prints "fetched only: <reason>" and no command (adversarial, merge_pr.sh:2301) — `.agent/WORKTREE_GUIDE.md:318`
- [ ] (suggestion) _rc_tool_distros globs `*/` before `.*/`: a root-level call on a two-distro root whose first glob falls between the tool's two renames and second after the old directory's removal sees neither name and silently takes the other distro; a microsecond window during a concurrent sync; globbing `.*/` first closes it but for a descheduled shell; one line (Codex, checked against output.py) — `.agent/project_types/ros2_colcon/adapter.sh:797`
- [ ] (suggestion) Not worth doing now: a worktrees= override directly under the root (e.g. <root>/wt) is taken as a distro by step 1, so calls from inside a package worktree there are refused (truly); registry_worktree_dir would close it (adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:906`

## Integrated Review
**Status**: complete
**When**: 2026-11-18 22:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #514 at `7ac39c89`
**Sources**: 3 (Local Review @ `3dd61876` (covers 7ac39c89 via bookkeeping; Gemini, Codex and a fresh Claude reviewer completed), Local Review (Pre-Push) @ `93e2693b` (covers 7ac39c89 via bookkeeping), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

PR mode, round 1 triage. Hosted reviews: none (0 reviews, 0 inline comments, 0 conversation comments on the pull request). CI: code head e18bdcc8 has no run of its own; 3dd61876, whose tree differs from it only in progress.md, passed every job (Validate Adapter Contract, Lint (pre-commit), Validate Documentation, repos-manifest tests 3.10 and 3.14, on both the push and pull_request runs). At the record-only head 7ac39c89, after about 5 minutes: Validate Adapter Contract, Validate Documentation and both repos-manifest test jobs pass; Lint (pre-commit) still pending on both runs. Mergeable: MERGEABLE. Each finding below was checked against the cited lines (adapter.sh:1-25, 72, 797, 902-912; docs/manifest/design.md:133, 159; WORKTREE_GUIDE.md:318 against merge_pr.sh:2301). Pre-push round 5's first suggestion is the same as this round's first, and is recorded once; its second was not ruled by the Checkpoint and is ruled below. Four findings remain open, to be fixed in this pull request before the owner's merge decision.

### Findings
- [x] (suggestion, Local Review + Local Review (Pre-Push) round 5) The distro paragraph and the adapter header do not say the calling directory is taken as a physical path too; and "or `sync` with no `--distro` when nothing is resolved yet" holds only from outside every distro's directory (from <root>/<x>/ it passes --distro x). Say both — `docs/manifest/design.md:133,159`, `.agent/project_types/ros2_colcon/adapter.sh:72`
- [x] (suggestion, Local Review) The header's opening still says the adapter "reads the manifest from the hosting dir only" and "Two routes to that directory (issue #436)", while the tool route is checked first; say three routes — `.agent/project_types/ros2_colcon/adapter.sh:5-11`
- [x] (suggestion, Local Review) "(else it says it fetched only: `git -C <clone> pull`)" reads as merge_pr.sh's output; it prints "fetched only: <reason>" and no command. Reword so the command is the reader's next step, not the script's output — `.agent/WORKTREE_GUIDE.md:318`
- [x] (suggestion, Local Review (Codex)) `_rc_tool_distros` globs `*/` before `.*/`, so a call during the tool's swap can see neither name and silently take the other distro; glob the set-aside `.*/` names first — `.agent/project_types/ros2_colcon/adapter.sh:797`

### False positives
- (Local Review, suggestion 5: no action, host ruling) A `worktrees=` override placed directly under the root is taken as a distro by step 1 and calls from a package worktree there are refused — neither the tool nor the workspace places it there by default, and the refusal it gives is true, not a wrong answer.
- (Local Review (Pre-Push) round 5, suggestion 2: no action, triage ruling) A root that can be entered but not listed skips step 1 — then step 2 decides: on a one-distro root it answers the only distro, the same answer step 1 would give from that distro's directory and the same as any call from outside it; on a root with several it refuses. No call gets a wrong distro, and the tool never makes such a root.

## Checkpoint
**When**: 2026-11-18 22:34 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the four open findings are three sentences that say something other than the code and a one-line order change; fixing them is mechanism)
**After**: findings
**Decision**: address

Fix the four open findings of the Integrated Review, each as small as it can be: sentences only for 1 to 3 (state what the code does and nothing more); for 4, list the set-aside names before the plain names in the one function that lists the distros, with a comment giving the reason in one line. No other change.

## Implementation
**Status**: complete
**When**: 2026-11-18 22:40 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #514 at `d95cd89b`
**Addressed**: Integrated Review at `7ac39c89` (2026-11-18 22:35 -05:00)
**Commits**: 95f49169, d2be335f, a8edd315, 28057981, d95cd89b

Per the Checkpoint (After: findings, Decision: address): sentences only for 1 to 3, checked against _rc_tool_sync, _rc_tool_distro_select, the dispatcher's ACTIVE_PROJECT_FROM (pwd -P) and merge_pr.sh:2268-2301; the order change for 4 with a one-line comment and a test of the both-exist case (the only-set-aside case is test_tool_set_aside_resolve_is_a_distro's). Suites (each with bash): test_ros2_colcon 1368 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 222/0; test_worktree_create PASS 90 FAIL 0; validate_adapter.sh all 13 verbs for both types; check_design_anchors.sh exit 0; removed-or-changed lines in .agent/scripts/tests vs origin/main: 0. Full pre-commit pass left to the host.

### Actions
- [x] Distro paragraph and header: calling directory taken as a physical path; setup/sync pass --distro <x> from inside <root>/<x>/, the one resolved distro's name from elsewhere, no --distro only from outside every distro's directory when nothing is resolved — `docs/manifest/design.md:133,163`, `.agent/project_types/ros2_colcon/adapter.sh:61,90`
- [x] Header opening: three routes, tool route checked first; manifest read from the hosting dir on the two older routes, from the tool's resolved files on the tool route — `.agent/project_types/ros2_colcon/adapter.sh:8-13`
- [x] merge_pr.sh's "fetched only: <reason>" output separated from the reader's own `git -C <clone> pull` — `.agent/WORKTREE_GUIDE.md:318`
- [x] _rc_tool_distros globs the set-aside .*/ names before */, one-line comment; test_tool_distro_listed_once_beside_its_set_aside — `.agent/project_types/ros2_colcon/adapter.sh:803`, `.agent/scripts/tests/test_ros2_colcon.sh`

## Local Review
**Status**: complete
**When**: 2026-11-18 22:59 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #514 at `a1f50cbd`
**Depth**: Deep (reason: whole-diff classification, fix-round rule: the ros2_colcon adapter, the dispatcher, registration and worktree scripts, AGENTS.md, an ADR note and design documents; 2268 insertions over 20 files)
**Must-fix**: 1 | **Suggestions**: 3

PR mode, round 2 (fix-round re-review of 95f49169..d95cd89b). Cross-model: Gemini completed (EXIT=0), Codex completed (EXIT=0) (run with --pr 514 --issue 503); a fresh Claude adversarial reviewer completed. Static analysis: shellcheck --severity=warning on adapter.sh and test_ros2_colcon.sh: clean. Point 1, a stub tool in the session scratchpad (own dispatcher copy and registry): nothing resolved: from the root `sync` (no --distro), from <root>/fakefox/sub `sync` and `setup` --distro fakefox; one resolved: from the root and from inside --distro fakefox, through an outside link to fakefox --distro fakefox (physical); two resolved: from the root refused listing both, from inside fakefox2 --distro fakefox2. Each matches the reworded design.md bullet and header. The header's three routes match _rc_route (tool first, then source, then bootstrap). merge_pr.sh:2277-2301: the four fetched-only reasons are the guide's. Point 2: _rc_tool_distros ends in `sort -u`, so no answer changes in any state and each distro is listed once; the adversarial's run with `sort` instead of `sort -u` failed the new test. Point 3, a new sandbox (a clone of the head as its own main checkout and registry, HOME sandboxed, gh and git-bug stubbed, ssh served from local bare repos): the installed `repos-manifest init --distro-dirs --distro rolling --yes`, register_project.sh --dry-run then real (VERIFY=pass, STATUS=registered, the root in no git repository), and from both the root and rolling/core: validate, sync (the tool's "present, not touched"), repos, repo_pin (core_a rolling branch; top_a --layer top main branch) and env, all exit 0; a package worktree for core_a made from the root (base rolling, the branch at origin/rolling), entered, removed (also removed from rolling/). Point 4: tests diff removes 0 lines; AGENTS.md is the approved sentence; CLAUDE.md and .github/ untouched; docs/decisions/ only the ADR-0021 note. CI at a1f50cbd: all five jobs pass on both runs. Suites (each with bash): test_ros2_colcon 1368 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 222/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_package_issue_loop 220/0; validate_adapter.sh all 13 verbs for both types; check_design_anchors.sh exit 0. Not findings: Gemini 1 (CDPATH, --from: host no action and round 1), 3 (host no action 21:48), 2, 4, 5, 6 and Codex 4, 5 (shapes the tool never writes, the tool's schema, bash 4.3), Gemini 7 (build and test skip a layer with no src/); Codex 2 (a `heads/`/`tags/` version: _rc_pin_kind is unchanged by this PR and the same on every route: an issue of its own if wanted); Codex 3 (an emptied clone directory passes validate: the same -d check as before; not worth doing here).

### Findings
- [x] (must-fix) PR body untrue of the head: "test_ros2_colcon.sh 1362 passed" (now 1368) and "On the pull request, Gemini, Codex and a fresh Claude reviewer read the final state: approved, 0 must-fix, 5 suggestions" (that was 3dd61876; four suggestions were fixed since); update the body — PR #514 body
- [x] (suggestion) The order change narrows the race but does not close it: `[ -d "$d" ] || continue` runs after both globs, so a .<d>.new captured before the second rename is dropped while the plain glob landed between the renames; filter the unmatched pattern (nullglob) instead of re-testing each name (Codex, adversarial, lead) — `.agent/project_types/ros2_colcon/adapter.sh:802-804`
- [x] (suggestion) The new test's comment says the set-aside names are listed first and its last block is labelled "(one distro)", but neither is checked (it passes on the old order and, its last block, without the dedupe); reword or assert no "several" (adversarial) — `.agent/scripts/tests/test_ros2_colcon.sh:4738,4756-4759`
- [x] (suggestion) "otherwise it fetches only and prints \"fetched only: <reason>\"" leaves out a failed fetch ("Could not fetch origin ...", cleanup marked incomplete, merge_pr.sh:2303); optional "(or says the fetch failed)" (adversarial) — `.agent/WORKTREE_GUIDE.md:318` (deferred: host: no action, low value (the review's own grading))

## Implementation
**Status**: complete
**When**: 2026-11-18 23:09 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #514 at `45af2d11`
**Addressed**: Local Review at `a1f50cbd` (2026-11-18 22:59 -05:00)
**Commits**: 436dfeae, 45af2d11

Round 2 fix pass on the pull request; the decisions are the host's. `_rc_tool_distros` (tool route only: called from `_rc_tool_read_layers` and `_rc_tool_distro_select`, reached through `_rc_route` = tool) now globs once with nullglob set for the two globs and restored (`restore="$(shopt -p nullglob)" || true`, since `shopt -p` exits 1 when the option is off and the dispatcher runs `set -euo pipefail`; a first version without `|| true` failed 49 checks of test_ros2_colcon and 11 of test_register_project, found and fixed before commit) and no longer re-tests each name with `-d`. The test helper `tool_distros` runs the function under `set -euo pipefail` as the dispatcher does. The new test's disappearance case is staged by a `[` function that removes the set-aside directory when it is tested: run against the old loop it lists nothing, against the new one fakefox; `sort` in place of `sort -u` lists fakefox twice, which the one-distro block now fails on. Suites (each with bash, the worktree's copy): test_ros2_colcon 1375 passed 0 failed 0 skipped; test_adapter 248 passed 0 failed; test_register_project 222 passed 0 failed; test_worktree_create PASS 90 FAIL 0; test_project_file 701/0; test_project_registry 425/0; validate_adapter.sh all 13 verbs for both types; shellcheck --severity=warning on adapter.sh and test_ros2_colcon.sh clean. `git diff origin/main...HEAD -- .agent/scripts/tests | grep -c '^-[^-]'`: 0. Outside work-plans since ff93f570: adapter.sh and test_ros2_colcon.sh only. Full pre-commit pass left to the host.

### Actions
- [x] (must-fix) PR body: fixed by the host, who owns the body; verified with `gh pr view 514`: it says `test_ros2_colcon.sh` 1368 passed and that Gemini, Codex and a fresh Claude reviewer read the pull request twice (first read approved, 0 must-fix, 5 suggestions, four fixed; second read nothing wrong in the code). The count is now 1375 after this round's tests, for the host to update — PR #514 body
- [x] (suggestion 1) `_rc_tool_distros` counts every name its globs returned, skips only an unmatched pattern (nullglob scoped to the two globs, restored); its comment now says what is and is not guaranteed — `.agent/project_types/ros2_colcon/adapter.sh:801-821`
- [x] (suggestion 2) test_tool_distro_listed_once_beside_its_set_aside: comment and labels say only what it checks; `_rc_tool_distros` output asserted exactly (fails with `sort`); new test_tool_distros_counts_each_name_globbed: only a set-aside directory lists its distro; one gone once globbed still listed (fails on the old loop); empty and missing resolved/ list nothing, no literal pattern — `.agent/scripts/tests/test_ros2_colcon.sh` (in 436dfeae with suggestion 1, the same file's tests)
- [x] (suggestion 3) WORKTREE_GUIDE failed fetch — `.agent/WORKTREE_GUIDE.md:318` (deferred: host: no action, low value)

## Local Review
**Status**: complete
**When**: 2026-11-18 23:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #514 at `d5eead98`
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 2

PR mode, round 3: the round-2 review's findings and the fix diff since it (ff93f570..HEAD outside work-plans: `_rc_tool_distros` in adapter.sh and two tests in test_ros2_colcon.sh, commit 436dfeae). Cross-model: skipped (round-3 convergence check, per handoff). Static analysis: shellcheck --severity=warning on adapter.sh and test_ros2_colcon.sh clean; governance: only those two files changed, tests diff removes 0 lines. Point 1: nullglob is set only around the one array assignment and restored by `eval "$restore"`, whose string is `shopt -p nullglob`'s own output (`shopt -s|-u nullglob`), safe; run under `set -euo pipefail` with nullglob on before, it stays on, off before, it stays off, no early exit; empty and absent resolved/ list nothing; every globbed name is counted, `sort -u` lists each once; `.`/`..` fail the set-aside regex. The comment is true of output.py's order (mkdtemp .<d>.new, files written, mkdtemp .<d>.old, rename <d> to old, rename new to <d>): a first glob after the new copy exists sees .<d>.new or <d>; the gap left is a first glob before that and a second glob between the two renames, a microsecond race. Point 2: callers only on the tool route (`_rc_tool_read_layers`, `_rc_tool_distro_select`). Staged `.ghost.old-4242-abcd1234` with no plain directory, harness from the test file's own helpers: with one distro, validate from the root exit 1 naming ghost's missing layers.txt and the tool's `sync --distro ghost`, fakefox checked ✅; env and sync from the root refuse "several distros (fakefox, ghost)" (the counting rule from test_tool_set_aside_resolve_is_a_distro, unchanged by this round); validate from inside <root>/ghost names ghost and the tool's sync; with two distros the same, listing fakefox, fakefox2, ghost. Point 3: the tests' subshells (`bash -c`) keep the `[` override out of other tests; but at this head `_rc_tool_distros` never calls `[`, so the stage never fires (checked: the directory is still there afterwards), see suggestion 1. Point 4, a new sandbox (a clone of the head as its own checkout and registry, HOME and git config sandboxed, gh and git-bug stubbed, ssh served from local bare repos): installed `repos-manifest init --distro-dirs --distro rolling --yes` cloned top_a and core/core_a; register_project.sh --dry-run then real (STATUS=registered, root in no git repository); from the root and rolling/core: validate, sync ("present, not touched"), repos, env all exit 0; package worktree for core_a made from the root (base=rolling, feature/issue-7 at origin/rolling 1a04cd3), removed (git worktree list of the clone back to one entry). Point 5: no false sentence; see suggestion 2. CI at d5eead98, push and pull_request runs: Lint (pre-commit), Validate Adapter Contract, Validate Documentation, repos-manifest tests 3.10 and 3.14 all pass. Suites (each with bash): test_ros2_colcon 1375 passed 0 failed 0 skipped; test_adapter 248/0; test_register_project 222/0; test_register_session_root 72/0; test_worktree_create PASS 90 FAIL 0; test_package_issue_loop 220/0; validate_adapter.sh all 13 verbs for both types; check_design_anchors.sh exit 0; tests diff vs origin/main removed lines: 0.

### Findings
- [ ] (suggestion) The "gone once globbed" block stages nothing at this head: the `[` override never fires because `_rc_tool_distros` no longer calls `[`, so the label "a set-aside directory gone once globbed: its distro still listed" checks a directory that is still there; it guards only against a return to a `[ -d ]` re-test (not `test -d` or `[[ -d ]]`); reword the comment and label to say that. Low value — `.agent/scripts/tests/test_ros2_colcon.sh:4775-4793`
- [ ] (suggestion) PR body out of date, not false: "**Recommendation**: review on the pull request with the outside models, then the owner's merge decision." (that review has run twice; what remains is the merge decision), and "one of its suggestions (...) was done" (two were: the test comment and labels too). Optional — PR #514 body

## Integrated Review
**Status**: complete
**When**: 2026-11-18 23:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #514 at `ac032538`
**Sources**: 2 (Local Review @ `d5eead98` (covers ac032538 via bookkeeping; round 3, approved, 0 must-fix, 2 suggestions; reviewing the code at 436dfeae), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

PR mode, round 3 triage, final before the owner's merge decision. Hosted reviews: none (0 reviews, 0 inline comments, 0 conversation comments). CI at the code-and-record head d5eead98: every job passed on both the push and pull_request runs (Lint (pre-commit), Validate Adapter Contract, Validate Documentation, repos-manifest tests 3.10 and 3.14). At the record-only head ac032538 (436dfeae..ac032538 changes only progress.md), after about 5 minutes: Validate Adapter Contract, Validate Documentation and both repos-manifest test jobs pass on both runs; Lint (pre-commit) still pending on both. Mergeable: MERGEABLE. PR body checked with `gh pr view 514 --json body`: the Recommendation line says "ready for the owner's merge decision", the reviews paragraph says two of the second read's suggestions were done, and it names the test-label note for a later part; no sentence found untrue (the "full pre-commit pass over the branch's files passed" claim is the host's and was not re-run here). Open boxes after the `## Checkpoint` with After: merge (line 608): only the two below, both ruled here; the earlier open boxes at lines 893-894 and 918-922 were ruled by the round-1 Integrated Review. Carried from round 2, not part of this pull request: suggestion 3 (the worktree guide and a failed fetch) was ruled no action; Codex's two findings about code this pull request does not change (a `heads/` or `tags/` version and `_rc_pin_kind`; an emptied clone directory passing validate) are to be proposed to the owner as a separate issue. Nothing remains open before the owner's merge decision but Lint (pre-commit) at the record-only head, which `merge_pr.sh` gates on.

### Findings
- [x] (suggestion, Local Review @ `d5eead98`) The "a set-aside directory gone once globbed" block stages nothing at this head (the `[` override never fires; checked at `.agent/scripts/tests/test_ros2_colcon.sh:4787-4790`) — no action in this pull request (host ruling): the label overstates, the check is still a valid guard against a return of the old `[ -d ]` re-check, and the PR body names it for a later part of #503 — `.agent/scripts/tests/test_ros2_colcon.sh:4775-4793`
- [x] (suggestion, Local Review @ `d5eead98`) PR body out of date (Recommendation line; "one of its suggestions was done") — fixed by the host, who owns the body; verified: "ready for the owner's merge decision" and "two of its suggestions were done" — PR #514 body

### False positives

## Checkpoint
**When**: 2026-11-19 00:38 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

The owner chose "Merge (Recommended)" in a dialog for pull request 514 (part 1B: the adapter's route for a root the manifest tool set up, and its registration), which named the AGENTS.md sentence, the dated note under ADR-0021 and the rule that a folder of the user's own directly under the root is treated as a distro. The issue stays open: later parts are a session started inside a distro's directory, /run-issue from the root of a project with several distros, and the switch to the tool's build, status and show when they exist. Noted for a later part: the test block labelled "a set-aside directory gone once globbed" does not stage a real disappearance.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 11:00 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan changed since its last review and its later parts are four lines each, so proceed is not open to the host; run-issue step 13)
**After**: plan
**Decision**: revise

Read: parts 1A and 1B merged (pull requests 513 and 514); the issue is open for the plan's "Later parts" 2, 3 and 4; plan.md is at a53288dc against the last Plan Review's 3f2dae10. The owner started this drive on 2026-11-23 ("work on those as orchestrator") after the host proposed "the adapter's validate reading status (the rest of #503)". The revision details part 4 next: the adapter's build calls repos-manifest build, validate reads repos-manifest status, and sync relies on the tool updating clones. All three tool commands are on main now (build: pull request 518; sync updating clones: 535; status: 546, merged 2026-11-23). Parts 2 and 3 stay as later parts.

### Decisions made (owner may veto)
- Part 4 is planned before parts 2 and 3: it depends on nothing in them, the tool commands it calls are all merged, and it closes the hole where validate passes a clone that is on the wrong version or emptied — undoing it: replan in the plan's original order; nothing is built yet.

## Plan Authored
**Status**: complete
**When**: 2026-11-23 11:04 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-503/plan.md` at `a1be602a`

Revision: part 4 detailed as the next pull request (Part of #503): validate reads repos-manifest status (--json and exit status), build calls repos-manifest build with the distro underlay sourced first, test limited to the resolved repos, sync and setup need only text fixes; one pull request; parts 2 and 3 kept as later parts.

## Plan Review
**Status**: complete
**When**: 2026-11-23 11:09 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #503 — ros2_colcon adapter: call the manifest tool's commands, and register a project from a manifest
**Plan**: `.agent/work-plans/issue-503/plan.md` at `a1be602a`
**Branch**: `feature/issue-503`

Reviewed only "Part 4 (revised 2026-11-23)". Checked by running the installed tool (`/home/roland/agent_workspace/.venv/bin/repos-manifest`, from main) against a system directory of my own: `init --distro-dirs --distro rolling` of a manifest with three local `file://` repos (one in the unnamed layer, two in `core`, one of them optional), each a plain CMake package; real `colcon` and `/opt/ros/rolling`.

What the runs showed:
- `status --distro rolling --json`: all expected, exit 0. A repo on another branch: `different`, exit 0. A tracked file changed: `expected` with `changes: 1`, exit 0. A repo moved away: `missing`, exit 1. An emptied directory and a clone with `.git` removed: `unusable` ("is not a git repository of its own"), exit 1 (issue 517 item 2 is closed on this route, as the plan says). The optional repo missing: `skipped`, exit 0; emptied: `unusable` with `optional: true`, exit 0. `--distro nosuch`: no document, exit 1, stderr "this system does not record it". Run outside any system directory: no document, exit 1. From inside `rolling/core` with no `--distro`: that distro, exit 0. Manifest made unreadable, and the distro removed from it: a document with the distro's `problem` set, no `repos` key, `ok: false`, exit 1. A repo taken out of the manifest: `not_in_manifest` lists it, exit 0. A bad option: exit 2. Field names, states, `path` (relative to the system directory, e.g. `rolling/core/src/pkg_a`), `layer` (`_unnamed`) and `format: 1` match `status.py` and the plan's table.
- A `config.yaml` like `make_tool_root`'s (no `distros`): `status` refuses ("`layout` is distro-dirs and there is no `distros`"), so the plan is right that the real-tool test must start from a real `init`.
- `build --distro rolling -- --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` with the underlay sourced: exit 0, both layers built, `rolling/setup.bash` written, `install/` in `rolling/` and `rolling/core/` (where `adapter env` looks). The tool appends `--base-paths src/<key>...` (repos on disk, the optional one included) after the forwarded arguments, and colcon parsed it correctly after `--cmake-args`. A stub `colcon` first on `PATH` is the one used (closes the plan's "could not verify"). Built with no ROS environment too (plain CMake). With this system's `setup.bash` already sourced: two warnings, exit 0. `-- --base-paths src`: refused, exit 1.
- Package selection: `-- ... --packages-select pkg_a` before any build is refused, exit 1 ("a run with package selection builds only part of a layer ... Build them without package selection first: `repos-manifest build _unnamed core`"); after a build it is accepted ("rebuilt with selection"). `-- ... --packages-up-to pkg_a` on two layers is refused, exit 1 ("Name the one layer that has those packages: `repos-manifest build <layer> -- ...`").
- `colcon list --base-paths` with no values: exit 0, no packages, no message.
- The installed venv has `python`, `python3` (links to `/usr/bin/python3`); the Makefile creates it with `python3 -m venv` and itself calls `$(VENV_BIN)/python3`. CI's "Validate Adapter Contract" job has Python 3.10, `pip install -e tools/repos-manifest` and `vcs2l`, and no `colcon`: the planned real-tool test fits only because it puts a stub `colcon` first on `PATH`.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, three verbs on one route, shared helper and stub; the two other routes branch off before any changed code (`adapter_build`/`adapter_test`/`_rc_colcon` already branch on `_rc_route`). |
| Issue alignment | Good | Covers the issue's `build` (distro environment sourced first), `test` (colcon per layer over the resolved repos) and `validate` (from `status`). Serves (plan-wide line, applies to part 4): "Easy to use and Modular (`README.md#workspace-goals`); `docs/design.md#registry-and-adapters`, `docs/manifest/design.md#a-project-instance-is-a-system-directory`" — both anchors exist. |
| File targeting | Needs work | `docs/design.md` is missing from step 6 (finding 1). |
| Consequences | Needs work | Findings 1, 2, 4. |
| Principle alignment | Good | Reuses the tool rather than rebuilding checks; tests named per row; the design doc's target table (`docs/manifest/design.md` line 301) is what the mapping implements. |
| ADR compliance | Good | 0011 (no new verb), 0017 (design docs in the same PR, once finding 1 is added), 0022 (reads the tool's output and the resolved files only; the one-line `cli.py` help fix stays within the tool's own text). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences / Keep one current design]** (medium) `docs/design.md#registry-and-adapters` (lines 476-478) says the tool route's "`build` and `test` are the colcon loop over its layers, and `validate` checks the last resolve". Part 4 makes that false, and the issue's acceptance names `docs/design.md`. Add it to step 6.
2. **[Consequences]** (low-medium) Package selection through `adapter build` changes behaviour: `--packages-select` before the first build, and `--packages-up-to` (and the other options colcon must resolve per layer) on more than one layer, are now refused by the tool. Its next step is a bare `repos-manifest build <layers>` that does not source the underlay. With decision 2 (no layer argument), `--packages-up-to` cannot go through the adapter at all. Today's loop failed on these too, less clearly. Name this in the plan or the header text and in a stub test of passthrough. One sentence is enough: build by hand with the underlay sourced.
3. **[File targeting / tests]** (low) Step 4: when a layer has none of its resolved keys on disk, `--base-paths` gets an empty list. colcon then finds nothing and exits 0 without a word. The tool's `build` skips such a layer and says so. Say that `test` skips the layer with a line, and test it.
4. **[Consequences]** (low) Dropping `_rc_check_manifest` from `build` lets a nested key (`grp/repo`) build. `env` and `test` still run `_rc_require_manifest` and refuse it, so after a good build `adapter env` refuses too. The plan names only validate, repos and worktrees. Add `env` and `test`, or say it is accepted.
5. **[Approach]** (low) Step 1: the adapter has no "call's own temporary directory" (no `mktemp -d`/trap for a call outside the manifest-route resolve). Capture stdout in a variable (`doc="$(cd … && _rc_nofd … --json)" || rc=$?`), which needs no file and no cleanup, or say where the file is made and removed.
6. **[Approach]** (low) Step 1/decision 6: use `$(dirname <bin>)/python3`, the name the Makefile itself uses, rather than `python`. Both exist in a `python3 -m venv` venv, but `python3` is the one the workspace already relies on. The sandbox link must then be `.venv/bin/python3`, in `make_tool_root` and in the real-tool test's own `.venv/bin/repos-manifest` wrapper (that test writes its own wrapper, not `make_tool_root`'s).
7. **[Approach]** (low) Step 3: run the tool's `build` through `_rc_nofd` as `_rc_tool_sync` and the planned status helper do. That keeps the git-locating variables (set when the adapter runs from a git hook) and fd 8/9 out of the tool's git and colcon.
8. **[Tests]** (low) The plan's stub `build` records "`SOURCED_UNDERLAY` the underlay's stub `setup.bash` sets", but `make_underlay` sets `SOURCED_LAYERS="base"`. Either use that or change `make_underlay`, and keep the existing tests that assert `SOURCED:base`.
9. **[Approach]** (low) Local changes and unpushed commits (`changes`, `unpushed`) do not change the exit status, and the plan's table does not say whether validate mentions them. Say "not reported" (as today) or add one warning form, and pin whichever you choose in a test.
10. **[Roadmap]** (low) The planned checks `file-contains … status --distro` / `build --distro` would also be met by a comment. Acceptable, but put the literal text only in the code line, or check a string only the code holds.

On the questions asked:
- Dropping the per-repo directory loop from validate loses nothing: `status` reports `missing`/`skipped` for the same places and more. Nothing else calls validate except `registration_verify.sh` (with `--from <main checkout>`, so `--every`) and the sitrep `script adapter --project <name> validate` check, which has a 60 s timeout. `status` runs git per repo, so on a large instance it is slower. I did not measure that on a real instance. `worktree_create.sh`, `merge_pr.sh`, `env`, `repos` and `repo_pin` do not call validate. Dropping `_rc_check_manifest` from build affects only finding 4. Behaviour change to expect: validate now fails when the manifest cannot be read or a repo was added to the manifest and not synced. That is the target in `docs/manifest/design.md` line 301.
- The `source` manifest route and the bootstrap route are untouched by the steps as written. Every changed function already branches on `_rc_route` first.
- None of the seven decisions needs to go to the owner. Each is a mechanism choice inside the design `docs/manifest/design.md` already states (line 301's target for validate, the tool's `build` taking the colcon arguments). Decision 4 (an out-of-date resolve is a warning) and decision 2 (no layer argument, consequence in finding 2) are the ones worth naming in the PR for his veto. The roadmap line split is wording, not direction.

### Summary

The plan's reading of the tool is right: every state, field, exit status and the `build` argument form it relies on behaved as described when run. It is ready for implementation once finding 1 (`docs/design.md`) is added to the documents step. The other findings are small and can be settled during implementation.

### Recommended Actions

- [ ] Add `docs/design.md#registry-and-adapters` (lines 476-478) to step 6.
- [ ] State the package-selection consequences of moving `build` to the tool (finding 2) in the header or design text, and cover passthrough in a stub test.
- [ ] Skip, with a line, a layer in `test` whose resolved repos are none on disk (finding 3).
- [ ] Settle findings 4-9 in the implementation: nested-key text, capture without a temp file, `python3`, `_rc_nofd` for build, the underlay stub's variable, local changes in validate.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 11:10 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the Plan Review's verdict is ready; its ten findings are one missing document and wording or mechanism details, none changing what the work is for, and all go into the implement handoff)
**After**: plan
**Decision**: proceed

Read: the Plan Review at 0a72bbfc for plan a1be602a, verdict ready. The reviewer ran the installed tool on a throwaway system directory with real colcon: every status state, field name and exit status the plan relies on, and the build argument form, behaved as the plan says. This proceed covers part 4 only; parts 2 and 3 stay later parts and the pull request says Part of #503. Carried into the implement handoff, to be done in this part: finding 1 (docs/design.md#registry-and-adapters, lines 476-478, is updated too); 2 (the documents and the build refusal text say what package selection through adapter build does now); 3 (test skips a layer with none of its resolved repos on disk, with a message line); 4 (say that env and test still refuse a nested key); 5 (capture the status output in a variable); 6 (the interpreter is python3 beside the tool); 7 (the build call goes through _rc_nofd); 8 (the stub's variable is SOURCED_LAYERS); 9 (the mapping says local changes and unpushed commits are not reported by validate, or reports them as a note); 10 (the roadmap checks name text a comment cannot satisfy).

### Decisions made (owner may veto)
- The adapter's build takes no layer argument; one layer is built with the tool directly (repos-manifest build <layer>) — undoing it: add a pass-through argument to the adapter's build verb, a small change.
- A resolve that is out of date with the manifest is a validate warning, not a failure — undoing it: one branch in validate and its test.
- validate on the tool route fails when the manifest cannot be read or when a non-optional repo added to the manifest is not synced yet, as docs/manifest/design.md states as the target — undoing it: map those status results to warnings.
- Repos on another version, with local changes or with unpushed commits stay a pass for validate (the tool exits 0 for them, by the owner's "Only unusable repos"); they are shown as a note — undoing it: change the tool's exit rule, which is the tool's design.

## Implementation
**Status**: complete
**When**: 2026-11-23 11:28 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-503 at `b6c96b94`

Part 4 only (parts 2 and 3 not built). Commits:
- 891b7b70 validate on the tool route reads `repos-manifest status --distro <d> --json` (output kept in a variable, read by python3 beside the tool with a stdlib reader; exit status decides, document names what failed; F9 local changes / unpushed commits are a NOTE, no failure; out-of-date resolve is a warning; an emptied clone fails as unusable, issue 517 item 2 on this route). Own checks kept: second records, leftover note, _rc_check_manifest, .repos present.
- cccbbeee build on the tool route runs `repos-manifest build --distro <d> -- --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON <args>` in the root through _rc_nofd, underlay sourced first, no layer argument; a failed run with package selection gets a NOTE giving the tool's step with the underlay sourced (F2); a nested key builds, env/test still refuse it (F4).
- 80143e35 test gives colcon the resolved repos on disk as --base-paths (read before the underlay is sourced); a layer with none on disk is skipped with a line (F3).
- f100f63b new real-tool test test_tool_real_status_and_build (real init, stub colcon on PATH; same vcs skip/require rule).
- c73a4add stale text: adapter header and sync comment; `repos-manifest sync` help no longer says repos there are "not touched yet".
- d5223e7d documents: docs/manifest/design.md (build, test, validate with the status-to-validate table, nested key, package selection), docs/design.md#registry-and-adapters plus change-log row (F1), tools/repos-manifest/docs/design.md, roadmap Direction line split; its check is `file-contains` on the two call lines (`_rc_nofd "$bin" status --distro`, `_rc_nofd "$bin" build --distro`), held by no comment, and sitrep_checks.sh reports it true; "fetch and generated directories removed" left unchecked (F10).
- b6c96b94 test_register_project.sh and test_register_session_root.sh: their hand-made tool roots get a config.yaml of the tool's shape and real clones of local repos, and python3 beside the workspace's tool wrapper, since the gate's validate now runs the real status (between 891b7b70 and this commit those two suites fail).

Suites run (each on its own, from the worktree):
- test_ros2_colcon.sh: "=== Results: 1457 passed, 0 failed, 0 skipped ===" (vcs present, so both real-tool tests ran; the bootstrap- and manifest-route tests are unchanged and pass, which is how those routes were confirmed untouched; their code paths branch on _rc_route before any changed line)
- test_adapter.sh: "=== Results: 248 passed, 0 failed ==="
- validate_adapter.sh: exit 0, "ros2_colcon: all 13 verbs implemented"
- test_register_project.sh: "test_register_project: 222 passed, 0 failed"
- test_register_session_root.sh: "test_register_session_root: 72 passed, 0 failed"
- test_worktree_create.sh: "PASS: 109 FAIL: 0"; test_project_registry.sh: "425 passed, 0 failed"; test_project_file.sh: "701 passed, 0 failed"; test_design_anchors.sh: "82 passed, 0 failed"
- tools/repos-manifest tests/test_cli.py: "25 passed" (with the venv, and again with PYTHONPATH set to this worktree's src)
The full pre-commit pass and the remaining suites are left to the host.

Not verified: the real tool against a real ROS instance or real colcon (CI has no colcon; the test uses a stub colcon); how long status takes on a large instance (sitrep's validate check has a 60 s timeout). Gap: none against Part 4 and F1-F10 as handed off.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 11:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-503 at `4ce8c85d`
**Base**: origin/main
**Depth**: Deep (reason: 11 files, +1173/-134, the ros2_colcon adapter's build/test/validate and registration's gate)
**Must-fix**: 2 | **Suggestions**: 4
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Scope: part 4 only. Ran: test_ros2_colcon.sh (1457 passed, 0 failed, 0 skipped); the same with a PATH holding no vcs and no colcon (1432 passed, 2 counted skips) and with ROS2_COLCON_TESTS_REQUIRE_VCS=1 there (2 failed, as meant); test_register_project.sh 222/0; test_register_session_root.sh 72/0; test_adapter.sh 248/0; validate_adapter.sh (all 13 verbs); tools/repos-manifest tests/test_cli.py 25 passed; pre-commit shellcheck on the changed shell files: passed; sitrep_checks.sh reads the split roadmap line as true, and both strings occur only on the code lines (1141, 2078). A throwaway tool-route instance of 40 repos (local file:// remotes, real `repos-manifest init`, real colcon, /opt/ros/rolling): validate 0.6 s; adapter build (real tool build, real colcon) exit 0, rolling/setup.bash written; adapter test tested only each layer's own repos; env names both layers. Error paths run: python3 beside the tool missing or dangling, tool missing, tool killed by a signal (143), non-JSON, format 2, manifest unreadable (problem), a repo dropped from the manifest (not_in_manifest warning plus the out-of-date warning, exit 0): each named and exit 1 (or 0 for the last). A config.yaml with no `distros` (a root put together by hand before this part) now fails validate and so registration with the tool's own "`layout` is distro-dirs and there is no `distros`; repair the file" and "status gave no document"; a root made by `repos-manifest init` has `distros` and passes. Cross-model: gemini and codex completed; codex's clean-filter finding is dropped (filters are the user's own git config, as `git status` runs them) and its "validate does not read .repos as build does" is dropped (build's own error names sync).

### Findings
- [x] (must-fix) `comm -23`/`comm -13` run in the caller's locale on `LC_ALL=C`-sorted lists: with GNU coreutils (CI's Ubuntu) under en_US.UTF-8, `_unnamed/...` vs `core/...` gives "file 1 is not in sorted order" on stderr and a wrong difference (status {core/z} vs resolve {_unnamed/b, core/z} reports core/z on both sides; reproduced with gnucomm); prefix both with `LC_ALL=C` and add a stub case with `_unnamed` and a named layer under a UTF-8 locale (this machine's `comm` is uutils, which hides it) — `.agent/project_types/ros2_colcon/adapter.sh:1225`
- [x] (must-fix) `adapter test` on the tool route treats a missing `<layer>.repos` as "none of the repos ... is on disk": with core.repos moved away on the 40-repo instance, it printed "Skipping layer core" and "All layer tests passed.", exit 0 (build refuses the same state); fail naming the file and the tool's sync, and test it — `.agent/project_types/ros2_colcon/adapter.sh:2145`
- [x] (suggestion) the status reader crashes (UnicodeEncodeError, traceback, every repo's line lost) on a lone surrogate the tool writes for non-UTF-8 git output; reconfigure stdout with errors="backslashreplace" or clean surrogates in text(), and the failure message's "(exit $rc)" names status's exit, not the reader's — `.agent/project_types/ros2_colcon/adapter.sh:1059`
- [x] (suggestion) the package-selection NOTE fires for `--packages-skip*`/`--packages-ignore*` (which the tool does not count as selection) and on any failure, not only the tool's selection refusal — `.agent/project_types/ros2_colcon/adapter.sh:2081`
- [x] (suggestion) the pass line's counts do not add up: a not_in_manifest path is counted in "with a warning" against a total of manifest repos ("39 repo(s), 39 as expected, 1 with a warning above"), and the out-of-date warning is not counted — `.agent/project_types/ros2_colcon/adapter.sh:1198`
- [x] (suggestion) test_tool_real_status_and_build's clean validate does not assert the absence of ⚠️ lines, so a false out-of-date warning from the real tool would pass — `.agent/scripts/tests/test_ros2_colcon.sh:5428`

## Implementation
**Status**: complete
**When**: 2026-11-23 11:51 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-503 at `ca13f870`
**Addressed**: Local Review (Pre-Push) at `4ce8c85d` (2026-11-23 11:38 -05:00)
**Commits**: 84cc4c42, 149af071, dfb6777b, ba8f9b0c, df95be9f, 12c593ef, ca13f870

### Actions
- [x] (must-fix) comm in the caller's locale: both comm calls run with LC_ALL=C; test_tool_validate runs validate under en_US.UTF-8 with the unnamed layer's repo only in the last resolve, GNU comm first on PATH (the system comm when it is GNU, as on CI; here comm is uutils, so the test links /usr/bin/gnucomm as comm in the sandbox; with neither GNU comm nor en_US.UTF-8 it prints a SKIPPED line for that part). Without the fix it fails here (2 asserts: wrong difference, "not in sorted order") — 84cc4c42, `.agent/project_types/ros2_colcon/adapter.sh:1238`
- [x] (must-fix) `adapter test` with a missing `<layer>.repos`: fails before colcon runs, naming the file and the tool's sync step; test_tool_test_over_the_resolved_layers (6 asserts fail without the fix); docs/manifest/design.md test bullet — 149af071, `.agent/project_types/ros2_colcon/adapter.sh:2160`
- [x] (suggestion) lone surrogate in the status reader: a byte that is not UTF-8 printed as \xXX (as the tool's show), another lone surrogate as \uXXXX, stdout backslashreplace as backstop; the reader's failure names its own exit status and status's; test_tool_validate (5 asserts fail without the fix) — dfb6777b, `.agent/project_types/ros2_colcon/adapter.sh:1047`
- [x] (suggestion) package-selection NOTE: arguments read as build.py's package_selection reads them (not --packages-skip/-ignore and their -regex forms, not --packages-skip-build-finished; --cmake-target counts); only then the tool's stderr is passed through tee and kept, and the note comes only on exit 1 with one of build.py's two refusal texts; stub cases in test_tool_build_runs_the_tool (7 fail without the fix), and test_tool_real_status_and_build triggers both real refusals; design doc updated — ba8f9b0c, `.agent/project_types/ros2_colcon/adapter.sh:2080`
- [x] (suggestion) pass line counts: counts are of the manifest's repos and add up; a not_in_manifest path and the out-of-date warning named apart after them; two exact pass-line asserts in test_tool_validate (fail without the fix); design doc updated — df95be9f, `.agent/project_types/ros2_colcon/adapter.sh:1246`
- [x] (suggestion) real-tool clean validate: asserts no ⚠️ and no NOTE on the fresh init, no ⚠️ after sync, and the pass line through its counts; checked to fail with a false out-of-date warning injected into the adapter — 12c593ef, `.agent/scripts/tests/test_ros2_colcon.sh:5536`
- [x] (review note) python3 beside the tool missing or a dangling link: named as the venv's Python (missing / a link to nothing with its target / not executable) with the step that makes the venv again (`make install-repos-manifest` alone does not, its stamps hold); a missing tool keeps the install step; tested — ca13f870

Suites run (each on its own, from the worktree):
- test_ros2_colcon.sh: "=== Results: 1512 passed, 0 failed, 0 skipped ===" (vcs present; the locale part ran with gnucomm)
- test_adapter.sh: "=== Results: 248 passed, 0 failed ==="
- validate_adapter.sh: exit 0, "✅ ros2_colcon: all 13 verbs implemented"
- test_register_project.sh: "test_register_project: 222 passed, 0 failed"
- test_register_session_root.sh: "test_register_session_root: 72 passed, 0 failed"
- test_project_file.sh: "701 passed, 0 failed"; test_project_registry.sh: "425 passed, 0 failed"; test_worktree_create.sh: "PASS: 109 FAIL: 0"; test_design_anchors.sh: "82 passed, 0 failed"
The full pre-commit pass and the remaining suites are left to the host. The source manifest route and the bootstrap route were not touched.

Not verified: the venv-remake step was not run (it would remove the main checkout's .venv); it was checked against the Makefile's setup-dev.done and repos-manifest.done rules only.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 11:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-503 at `c0233251`
**Base**: origin/main
**Depth**: Deep (reason: whole-diff classification as round 1: 11 files, about +1414/-133, the ros2_colcon adapter's build/test/validate and registration's gate; fix-round rule, not lowered)
**Must-fix**: 1 | **Suggestions**: 4
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 2), not rising; fix and ship rather than another full round

Scope: part 4 only. The six round 1 findings and the python3 message are fixed as described; each fix was read against its test. Ran: test_ros2_colcon.sh at HEAD, "=== Results: 1512 passed, 0 failed, 0 skipped ===" (1 min 48 s); test_adapter.sh 248/0; validate_adapter.sh (all 13 verbs); test_register_project.sh 222/0; test_register_session_root.sh 72/0; pre-commit shellcheck on the four changed shell files: passed. In a throwaway detached worktree (removed), with only test_tool_validate enabled: the LC_ALL=C prefixes removed gives 2 failures (the wrong difference and "not in sorted order", with gnucomm), restored gives 66/0; with `locale` on PATH listing only C, C.utf8 and POSIX, the locale part prints "SKIPPED (locale part)" and the results line says "63 passed, 0 failed, 0 skipped". The tee construct, run alone: without pipefail rc is tee's (0 for a failing tool); with pipefail (the shim's `set -euo pipefail`) the tool's status comes through, 130 included, and the stub tests check this through the shim; stderr to /dev/full turns a tool exit 0 into rc 1; stderr closed gives rc 1 and the tool is killed by SIGPIPE at its first stderr write (before this change it ran to the end, rc 0). The rebuild step was read against the Makefile, not run: removing .venv and the two stamps makes install-repos-manifest rebuild setup-dev.done (python3 -m venv, requirements, pre-commit install) then reinstall the tool, so it is correct. The source manifest route and the bootstrap route: the only change in shared code is _rc_colcon, which now always runs `colcon "$@"` as those routes did; their tests pass unchanged. Cross-model: gemini and codex completed; codex's caller `--base-paths` override dropped (the caller's explicit choice), its "removed missing repo passes validate" dropped (the out-of-date warning names the sync); gemini's IFS, set -e, flag() and double "disagree" line findings dropped (speculative, or the outcome is already a failure). Claude adversarial: no must-fix, the PIPESTATUS suggestion below.

### Findings
- [x] (must-fix) the locale part of test_tool_validate skips without being counted: where en_US.UTF-8 (or GNU comm) is missing it prints SKIPPED and the results line still says 0 skipped, the uncounted skip issue 539 removed; whether CI's ubuntu-latest has en_US.UTF-8 was not checked by the fix pass or here. Count it in the summary's skipped number (and remove the gnucomm link in the skip branch too) — `.agent/scripts/tests/test_ros2_colcon.sh:4838`
- [x] (suggestion) the selection build's status is the pipeline's: it depends on the caller's pipefail, a tee failure (TMPDIR full, stderr on /dev/full) turns a tool exit 0 into 1, and with stderr closed the tool is killed by SIGPIPE where it used to run to the end; take ${PIPESTATUS[0]} and keep the pipe drained if tee cannot write; the mktemp file also has no trap on interrupt — `.agent/project_types/ros2_colcon/adapter.sh:2126`
- [x] (suggestion) the venv rebuild step is correct against the Makefile, but it is the only adapter message that prints an `rm -rf` (the others say "remove it"), and it removes the .venv every worktree's pre-commit hook runs from; give it a Makefile target (it would also be testable) or name what to remove in words — `.agent/project_types/ros2_colcon/adapter.sh:1162`
- [x] (suggestion) the status reader takes a missing or null repos / not_in_manifest as an empty list even on an entry with no problem, so a malformed ok document passes as zero repos; require both lists when there is no problem — `.agent/project_types/ros2_colcon/adapter.sh:1098`
- [x] (suggestion) the selection NOTE's manual step sources the underlay but does not clear COLCON_PREFIX_PATH, AMENT_PREFIX_PATH and CMAKE_PREFIX_PATH as the adapter's own build does, so run from a shell with another workspace sourced it builds against that — `.agent/project_types/ros2_colcon/adapter.sh:2133`

## Implementation
**Status**: complete
**When**: 2026-11-23 12:18 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-503 at `18c33dbf`
**Addressed**: Local Review (Pre-Push) at `c0233251` (2026-11-23 11:58 -05:00)
**Commits**: 0427cccc, 607e941e, a68832a7, bd3e4cdf, 18c33dbf

### Actions
- [x] (must-fix) the locale part of test_tool_validate now counts its skip: a LOCALE_SKIPPED counter, its own SKIPPED banner, added to the results line's skipped number; the gnucomm link is removed whichever branch ran (0427cccc) — `.agent/scripts/tests/test_ros2_colcon.sh:4838`. Checked by forcing the skip (locale pattern made unmatchable for one run): `SKIPPED (locale part)` printed and `=== Results: 1509 passed, 0 failed, 1 skipped ===`. With the adapter's `LC_ALL=C` taken off its two `comm` calls, the part fails: `FAIL: under en_US.utf8 with gnucomm: the unnamed layer's repo alone, in the last resolve only` and `FAIL: ... comm did not see unsorted input` (`1510 passed, 2 failed`). Locale on CI: `LC_ALL=C.utf8 gnucomm` on the test's lists gives the right difference with no "not in sorted order" (C.UTF-8 collates `_unnamed` before `core`, as C does), so C.UTF-8 cannot reproduce the misordering and en_US.UTF-8 stays. The runner image installs the `locales` package (runner-images toolsets), but nothing in its build scripts was found to generate en_US.UTF-8, so on CI this part may be a counted skip.
- [x] (suggestion) the selection build's status is the tool's own, `${PIPESTATUS[0]}`, whatever the caller's pipefail; the reader falls back to the file alone when stderr cannot be written and drains what is left; no temporary file to be had runs the build as without selection; the file is removed on INT, TERM and HUP too, the earlier traps restored (607e941e) — `.agent/project_types/ros2_colcon/adapter.sh:2126`. Tests in test_tool_build_runs_the_tool: without pipefail (the sandbox dispatcher's copy) the tool's status 3 and a refusal's exit 1 with the note pass through; stderr closed, a successful build exits 0 and the tool runs to the end; stderr on /dev/full exits 0 with no temporary file left. Against the old code the pipefail and /dev/full tests fail (4 failed); the stderr-closed test passes on old and new alike, since inside the dispatcher fd 2 is reused by the first file opened.
- [x] (suggestion) the venv rebuild message says in words what to remove (the .venv directory and the two stamp files) and the make target to run after; no rm command printed; no Makefile target added (a68832a7) — `.agent/project_types/ros2_colcon/adapter.sh:1162`. Test: the step text in test_tool_validate, and no `rm -rf` in the output.
- [x] (suggestion) a status entry with no problem and a missing or null repos or not_in_manifest is a failure saying the document is malformed, naming the missing list; the docs/manifest/design.md table names it (bd3e4cdf) — `.agent/project_types/ros2_colcon/adapter.sh:1098`. Tests in test_tool_validate: repos deleted, not_in_manifest null, and an empty problem with repos null, each exit 1 with the malformed line.
- [x] (suggestion) the selection NOTE's manual step unsets COLCON_PREFIX_PATH, AMENT_PREFIX_PATH, CMAKE_PREFIX_PATH and AMENT_CURRENT_PREFIX before sourcing the underlay, as the adapter's build does; the note_text test and docs/manifest/design.md quote it (18c33dbf) — `.agent/project_types/ros2_colcon/adapter.sh:2133`.

### Checks
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: `=== Results: 1530 passed, 0 failed, 0 skipped ===` (at 18c33dbf)
- `bash .agent/scripts/tests/test_adapter.sh`: `=== Results: 248 passed, 0 failed ===`
- `bash .agent/scripts/validate_adapter.sh`: `✅ ros2_colcon: all 13 verbs implemented`, `✅ single_project: all 13 verbs implemented`
- `bash .agent/scripts/tests/test_register_project.sh`: `test_register_project: 222 passed, 0 failed`
- `bash .agent/scripts/tests/test_register_session_root.sh`: `test_register_session_root: 72 passed, 0 failed`
- `bash .agent/scripts/tests/test_project_file.sh`: `=== Results: 701 passed, 0 failed ===`
- `bash .agent/scripts/tests/test_project_registry.sh`: `=== Results: 425 passed, 0 failed ===`
- `bash .agent/scripts/tests/test_worktree_create.sh`: `PASS: 109`, `FAIL: 0`
- Commits made with `SKIP=validate-script-tests`; every other hook ran (shellcheck passed). The full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 12:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-503 at `5bb1a596`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff; whole-diff tier Deep as rounds 1 and 2)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 3 | **Ship**: recommended — no must-fix findings; the two suggestions can be applied or tracked

Scope: the round 2 entry's five findings and the fix commits 0427cccc, 607e941e, a68832a7, bd3e4cdf, 18c33dbf only. Cross-model: skipped (round-3 convergence check, per handoff). All five round 2 findings are closed. Ran: test_ros2_colcon.sh at HEAD, "=== Results: 1530 passed, 0 failed, 0 skipped ===" (1 min 52 s). In a throwaway detached worktree (removed) with adapter.sh put back to 3217c81f and the HEAD tests: "1513 passed, 17 failed", the failures being exactly the new note-text, pipefail, /dev/full, malformed-document and venv-step assertions, so each adapter fix has a test that fails without it (the stderr-closed test passes on both, as the fix pass said). With the locale grep made unmatchable: "SKIPPED (locale part)", the "=== SKIPPED: the locale part ..." banner and "1527 passed, 0 failed, 1 skipped". pre-commit shellcheck on adapter.sh and test_ros2_colcon.sh: passed. The trap pattern, copied verbatim into a harness under bash 5.3.9: on a normal return the caller's INT/TERM traps are restored and none of the function's are left (with no caller traps, `trap -p` is empty after); `trap -p` inside `$(...)` does see the caller's traps; HUP ignored at entry (nohup) stays ignored; TERM to the shell mid-build waits for the build, removes the file and exits 143, but a caller's own TERM trap does not run (the handler resets to default before re-raising), see the first suggestion. The only caller today, .agent/scripts/adapter, sets no traps, so nothing is lost in practice, and the function runs in that script's own shell (not a subshell), so `kill $$` targets the right process. The PIPESTATUS read (`&& rc=${PIPESTATUS[0]} || rc=${PIPESTATUS[0]}`) is right on both branches and under set -e. CI locale: a counted, visible skip is acceptable for this part (issue 539's rule is that a skip is counted, which it now is); whether ubuntu-latest has en_US.UTF-8 was not checked, see the second suggestion.

### Findings
- [ ] (suggestion) the signal handler resets the signal to default and re-raises, so a caller's earlier INT/TERM/HUP trap is restored only on a normal return and never runs on an interrupt; restore the saved traps (`eval "$traps"`) in the handler before `kill -$sig $$`, and add the untested signal path to test_tool_build_runs_the_tool (a stub tool that sleeps, TERM to the dispatcher, the temporary file gone, exit 143) — `.agent/project_types/ros2_colcon/adapter.sh:2146`
- [ ] (suggestion) on CI the locale part may always be a counted skip, so the LC_ALL=C regression guard would never run there; a `sudo locale-gen en_US.UTF-8` step in validate.yml would settle it, but that is a CI change (Ask First), so it is the owner's call; until then read the CI log for the SKIPPED banner — `.agent/scripts/tests/test_ros2_colcon.sh:4880`

## Checkpoint
**Status**: complete
**When**: 2026-11-23 12:31 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 approved with no must-fix; the host's full pass passed on this head)
**After**: publish
**Decision**: publish

Read the Local Review (Pre-Push) at 75e7d1dd (round 3, a convergence check, approved, ship recommended, 0 must-fix, 2 suggestions left open for triage and the owner's merge decision: the build's signal handler does not run a caller's own handler and has no test; a locale-gen step in the CI workflow would make the locale part run on CI for certain, a CI change that is the owner's to approve). The full pass (pre-commit run --files over the branch's eleven files, no SKIP, branch even with origin/main) passed: every hook Passed or Skipped for no files, including the adapter contract check, the design-anchor check, the .agent/scripts/tests/ suite, shellcheck, black and flake8; the tree was clean after it.

### Decisions made (owner may veto)
- Published with the two round 3 suggestions open instead of a fourth fix round: no current caller sets a signal handler, and the other is a CI change only the owner approves; both are in the pull request's text and go through triage to the merge decision — undoing it: a fix pass on the open pull request before the merge.

## Integrated Review
**Status**: complete
**When**: 2026-11-23 12:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Reviews-read**: none

**PR**: #562 at `1db4680`
**Sources**: 2 (Local Review (Pre-Push) @ `5bb1a59` (covers `1db4680` via bookkeeping), CI rollup: 10 check runs)
**Cross-source confirmations**: 0
**CI**: all-pass

No GitHub reviews, inline comments, conversation comments or hosted-reviewer check run on the pull request. The two open suggestions of the pre-push review are the only findings to rule on.

CI facts read from the Validate Adapter Contract job's log (run 45228617141): Python 3.10.22; both real-tool tests ran (`tool route with the real tool and vcs: init by hand ...` and `... validate reads the real status, build runs the real build`); no SKIPPED line; `=== Results: 1530 passed, 0 failed, 0 skipped ===`. So the locale part of the suite ran on CI and the status reader works on Python 3.10: the two points the pull request body lists as not verified are settled.

CI cost: the job took 141 s and 174 s on main's two runs today and 216 s and 231 s on this pull request's two runs. The ros2_colcon test step alone went from 94 s (main, 1366 checks) to 173 s (this head, 1530 checks, a second real-tool test): the suite's growth costs about 80 s in that job.

### Findings
- [x] (suggestion, Local Review (Pre-Push) @ `5bb1a59`) the interrupt path of the build with selection is untested: nothing checks that INT, TERM or HUP during the tool's build removes the temporary stderr file and ends with the signal's status (143 for TERM). Its second half, that the handler resets the signal to default and re-raises so a caller's own INT/TERM/HUP trap is skipped on an interrupt, cannot occur with any caller on this branch: the only route in is `.agent/scripts/adapter` (and `build.sh`, which execs it), which sets no trap before calling `adapter_build`; the traps in `_project_registry.sh` live in `project_file_set`'s own subshell. Fix, about 20 lines: in the handler, `eval "$traps"` (the saved caller traps) before `kill -$sig $$` instead of `trap - $sig` (one line), and a case in `test_tool_build_runs_the_tool` with a stub tool that sleeps, TERM sent to the dispatcher, then the temporary file gone and exit 143 — `.agent/project_types/ros2_colcon/adapter.sh:2146`

### False positives
- (Local Review (Pre-Push) @ `5bb1a59`) on CI the locale part may always be a counted skip, so add a `sudo locale-gen en_US.UTF-8` step to validate.yml — the failure mode did not occur: the CI image has en_US.UTF-8 and GNU comm, and this head's Validate Adapter Contract log shows both real-tool tests running, no SKIPPED line and `1530 passed, 0 failed, 0 skipped`. Should a future image drop the locale, the skip is counted and printed in that Results line, not silent, so the CI change (Ask First) is not needed — `.agent/scripts/tests/test_ros2_colcon.sh:4880`

## Checkpoint
**Status**: complete
**When**: 2026-11-23 12:49 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (one open suggestion with a fix of about 20 lines; merging with a finding open is the owner's answer only, and sending it for the fix is the host's)
**After**: findings
**Decision**: address

Read: the Integrated Review at 4a465e73 for pull request 562: CI all-pass, no GitHub reviews or comments, one valid finding and one false positive. The valid finding (suggestion), .agent/project_types/ros2_colcon/adapter.sh:2146: when a build that selects packages is interrupted, nothing tests that the temporary stderr file is removed and the run ends with the signal's status, and the handler resets the signal instead of restoring a caller's own handlers; no caller on this branch sets one. The fix: in the handler, restore the saved traps before re-sending the signal, and a test with a stub tool that sleeps, TERM sent, the temporary file gone and exit 143. The false positive: the locale-gen step for the CI workflow; this pull request's CI run showed the locale part running (1530 passed, 0 failed, 0 skipped), so no CI change is needed.

## Implementation
**Status**: complete
**When**: 2026-11-23 12:55 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #562 at `2ca7a73`
**Addressed**: Integrated Review at `1db4680` (2026-11-23 12:48 -05:00)
**Commits**: 2ca7a73

### Actions
- [x] Interrupt of the build with selection: the handler now removes the temporary stderr file, resets INT/TERM/HUP, restores the caller's saved traps (`eval` of the `trap -p` taken at entry, embedded with `%q`) and then re-sends the signal, so a caller's own handler runs; a signal ignored at entry stays ignored and no trap is left after a normal return (checked with a standalone bash harness using the same handler string; the normal-return path is unchanged). Test in `test_tool_build_runs_the_tool`: the stub tool, given TOOL_SLEEP, records what is in TMPDIR and sleeps 1 s; TERM goes to the dispatcher (exec'd background job) after a bounded wait (at most 5 s) for the stub to start; then the temporary file existed during the build, is gone after, and the exit is 143; with a TERM handler added at the top of the sandbox's dispatcher, that handler runs and the status is its 7. On the old code the plain TERM case passes (143, file removed); the caller-handler case fails (status 143, handler not run): 1535 passed, 2 failed — `.agent/project_types/ros2_colcon/adapter.sh:2146`

### Checks
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: `=== Results: 1537 passed, 0 failed, 0 skipped ===`
- `bash .agent/scripts/tests/test_adapter.sh`: `=== Results: 248 passed, 0 failed ===`
- `bash .agent/scripts/validate_adapter.sh`: `✅ ros2_colcon: all 13 verbs implemented`, `✅ single_project: all 13 verbs implemented` (exit 0)
- Full pre-commit pass left to the host; CI checks the push.

## Local Review
**Status**: complete
**When**: 2026-11-23 13:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #562 at `d9cc234b`
**Depth**: Deep (reason: whole-diff classification per the fix-round rule, 11 files +1664/-134 including adapter.sh; the fix round itself is 2ca7a73f)
**Must-fix**: 1 | **Suggestions**: 5

Scope: the fix 2ca7a73f (handler restores the caller's traps before re-sending the signal; TERM test with a sleeping stub), with cross-model reviewers on the whole PR diff. The fix is correct: the `%q`-quoted saved traps survive `eval` inside the trap string (checked with multi-line traps, quotes, a path with a space), the normal-return path is unchanged, and `$$` is the dispatcher's own shell (`adapter_build` runs there, `.agent/scripts/adapter:422`). Ran: `test_tool_build_runs_the_tool` alone on `git archive` copies of HEAD: with the fix 61 passed, 0 failed (5.4 s); with the pre-fix adapter.sh 59 passed, 2 failed ("its status, 7", "it ran"), so the new test catches the bug. With a 1.5 s pause injected before the test's `kill`, 3 assertions fail (rc 0): a loud failure, never a false pass. shellcheck --severity=warning on both files: clean. Cross-model: Gemini and Codex both completed (EXIT=0). CI on d9cc234b was pending when read. The must-fix comes from Codex on the whole diff, not from the fix round; it was verified against `tools/repos-manifest/src/repos_manifest/build.py:85,157-175`.

### Findings
- [x] (must-fix) `adapter test` on the tool route silently leaves out a required repo that is missing from disk: it tests only the listed repos it finds on disk, and skips a layer with none of them, so the run can succeed. The tool's build, which the code comment and docs/manifest/design.md say test matches, refuses a non-optional missing repo (`missing_repos`, build.py:163). It skips a layer only when every repo it lists is optional (build.py:85). Read `optional.txt` and refuse missing required repos before colcon runs, naming them and the sync step; add a test; correct the design.md bullet (Codex) — `.agent/project_types/ros2_colcon/adapter.sh:2232`
- [x] (suggestion) If the caller's handler returns instead of exiting, or the caller ignores the signal, the build carries on after the handler has removed the temporary file. When the tool's status is 1, `grep` then prints "No such file or directory", and the refusal note is lost (reproduced in a probe). Use `grep -sqF` or `[ -e "$errlog" ] &&` (adversarial, Gemini, own probe) — `.agent/project_types/ros2_colcon/adapter.sh:2154`
- [x] (suggestion) A caller's `trap '' <sig>` is replaced by the adapter's handler for the length of the build. The tool therefore starts with the default action for that signal (confirmed: the child exits 130 on INT), so a process-group Ctrl-C kills the tool even though the caller ignored INT. The comment says the ignoring is "put back", which is true only after a signal arrives. No caller on this branch ignores these signals. Skip trapping a signal whose saved entry is `trap -- '' SIG<x>`, or reword the comment (adversarial, Gemini) — `.agent/project_types/ros2_colcon/adapter.sh:2147`
- [x] (suggestion) The test's timing margin is the stub's 1 s sleep. If more than about 1 s passes between `tool.started` appearing and the `kill` (a stalled CI runner), the build ends first, the run exits 0 and the test fails spuriously (reproduced with an injected 1.5 s pause). Have the stub wait on a release file the test creates after `kill`, or sleep longer — `.agent/scripts/tests/test_ros2_colcon.sh:4325`
- [x] (suggestion) A TERM sent to the adapter alone does not stop the tool. Bash runs the trap only after the foreground pipeline ends, so the build runs to completion and only then is the file removed and the signal re-sent. A process-group signal (Ctrl-C, `timeout`) reaches both. The test sends TERM to the dispatcher only, so it does not show the tool being stopped. Say this in the comment, or forward the signal to the build (Codex) — `.agent/project_types/ros2_colcon/adapter.sh:2149`
- [x] (suggestion) In `adapter test`, the `.repos` reader runs in a process substitution, so its failure is not seen. A file that passes `-f` but cannot be read yields no keys, and the layer is "skipped" with status 0, while the reader's own error goes to stderr. Check the reader's status before treating an empty list as no repos on disk (Codex) — `.agent/project_types/ros2_colcon/adapter.sh:2235`

## Implementation
**Status**: complete
**When**: 2026-11-23 13:17 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #562 at `1e4aec6e`
**Addressed**: Local Review at `d9cc234b` (2026-11-23 13:07 -05:00)
**Commits**: d913106a, 7e85348c, 1e4aec6e

### Actions
- [x] (must-fix) Tool-route `adapter test` follows the tool's build rule (build.py `missing_repos` / `Layer.empty`): a listed repo not on disk and not named in the resolved `optional.txt` fails before colcon runs, naming each repo and the tool's sync; a missing optional repo is left out; a layer is skipped with its line only when none of its repos is on disk and all are optional. Optional repos are learned through the existing `_rc_is_optional_repo` (reads the resolved `optional.txt`; no new parser, not the status document). Tests: required repo missing (exit 1, named, colcon not run), optional repo missing (left out, all layers tested), optional-only layer with none on disk (skipped with the line). Code comment and docs/manifest/design.md bullet corrected; docs/design.md does not repeat the claim — d913106a — `.agent/project_types/ros2_colcon/adapter.sh:2232`
- [x] (suggestion) `.repos` reader failure in `adapter test` is a failure: output taken in a command substitution, status checked, error names the file; test with a chmod 000 `core.repos` (skipped as root); comment and design bullet say so — 7e85348c — `.agent/project_types/ros2_colcon/adapter.sh:2235`
- [x] (suggestion) `grep -sqF` on the temporary file, so a returning caller handler leaves no "No such file or directory" — 1e4aec6e — `.agent/project_types/ros2_colcon/adapter.sh:2154`
- [x] (suggestion) Handler comment now says the adapter's handler replaces the caller's (an ignored signal included) while the build runs, and they are put back on return or on a signal; no change to trapping — 1e4aec6e — `.agent/project_types/ros2_colcon/adapter.sh:2147`
- [x] (suggestion) Interrupt test: stub waits on a release file (TOOL_HOLD, bounded at 10 s) that the test creates after `kill`, replacing the 1 s sleep — 1e4aec6e — `.agent/scripts/tests/test_ros2_colcon.sh:4325`
- [x] (suggestion) Comment says a TERM to the adapter alone does not stop the tool, which finishes first, while Ctrl-C and `timeout` signal the whole process group; no forwarding added — 1e4aec6e — `.agent/project_types/ros2_colcon/adapter.sh:2149`

### Checks
- `bash .agent/scripts/tests/test_ros2_colcon.sh` (after the last change): `=== Results: 1551 passed, 0 failed, 0 skipped ===`
- `bash .agent/scripts/tests/test_adapter.sh`: `=== Results: 248 passed, 0 failed ===`
- `bash .agent/scripts/validate_adapter.sh`: `✅ ros2_colcon: all 13 verbs implemented`, `✅ single_project: all 13 verbs implemented`
- Full pre-commit pass and the other suites left to the host and CI; commits made with `SKIP=validate-script-tests`.

## Local Review
**Status**: complete
**When**: 2026-11-23 13:21 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #562 at `d5e64448`
**Depth**: Deep (reason: round 3 convergence check per handoff; the depth and scope were set by the host's direction: the previous review's six findings and the fix commits d913106a, 7e85348c, 1e4aec6e only)
**Must-fix**: 0 | **Suggestions**: 1

Scope: the Local Review at b4c786d0 (1 must-fix, 5 suggestions) and the three fix commits. Cross-model: skipped (round-3 convergence check, per handoff). All six findings are closed and no fix introduced a defect. Must-fix: the adapter's rule matches build.py case by case (`missing` = listed, not on disk, not in optional.txt, build.py:157; refusal before anything runs naming each `key (layer L)` and sync, build.py:163-175; a layer skipped only when `not on_disk and not missing`, build.py:85). A key the reader cannot parse (`grp/x`, `pkg+x`) cannot slip past the check: `_rc_check_manifest` refuses it by name first (`_rc_tool_refuse_unread_keys`, adapter.sh:330). The difference the fix pass named, a missing optional.txt, is acceptable: the adapter then counts every repo as required, so a missing repo still fails (fails closed), and when nothing is missing the run is still correct; an unreadable optional.txt behaves the same. The tool's `chosen` filter has no counterpart because test runs every layer. Reader failure (7e85348c): checked in a command substitution; awk on an unreadable file exits 2 and is caught. Interrupt path (1e4aec6e): `grep -s` leaves the condition false when the file is gone; the release file is created right after `kill` with no return in between, and the stub waits at most 10 s, so a failed assertion cannot hang the run or leave the stub behind (pgrep found none after the runs). The comments match the behaviour.

Ran, on `git archive` copies of HEAD with every other test call commented out: `test_tool_test_over_the_resolved_layers` with HEAD's adapter.sh gave 29 passed, 0 failed. With the pre-fix adapter.sh (b4c786d0) it gave 18 passed, 11 failed: the required-missing case (5), the optional-only skip line (1, wording only) and the unreadable case (5). The optional-missing case passes on both, as it should, since it guards against refusing too much. `test_tool_build_runs_the_tool` gave 61 passed, 0 failed on four runs. `shellcheck --severity=warning` on both files: clean. CI on d5e64448 was pending when read. CI runs `test_ros2_colcon.sh` directly on `ubuntu-latest` with no container, so as a non-root user, and the chmod 000 case runs there.

### Findings
- [ ] (suggestion, deferrable) The chmod 000 case's root skip prints `SKIPPED:` but no counter counts it, so a root run's summary line says `0 skipped` (the same uncounted pattern as the existing root skip at line 4412, already on main). CI runs as non-root. Count it, like LOCALE_SKIPPED, when the suite's skip counters are next touched — `.agent/scripts/tests/test_ros2_colcon.sh:4782`

## Integrated Review
**Status**: complete
**When**: 2026-11-23 13:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Reviews-read**: none

**PR**: #562 at `d5e6444`
**Sources**: 2 (Local Review @ `d5e6444` (exact), CI rollup: 10 check runs)
**Cross-source confirmations**: 0
**CI**: all-pass

Repeat triage: read only the entries after the Integrated Review at `1db4680`. No GitHub reviews, inline comments, conversation comments or hosted-reviewer check run on the pull request (fetch_pr_reviews.sh: 0 reviews, 0 comments). Every finding between the two triages is closed: the Integrated Review's one suggestion (interrupt path, fixed in 2ca7a73), then the Local Review at `d9cc234b` (1 must-fix, 5 suggestions, all fixed in d913106a, 7e85348c, 1e4aec6e, each checked by the convergence Local Review at `d5e6444`). That last review's depth was set by the host: a round-3 convergence check of the six findings and three fix commits, with no cross-model or outside reviewers; recorded as it stands. The sources helper lists the pre-push review at `5bb1a59` as stale (adapter.sh changed since); its two findings were ruled on in the previous Integrated Review.

CI on `d5e6444`: all 10 check runs passed. The Validate Adapter Contract log for this head has `=== Results: 1551 passed, 0 failed, 0 skipped ===` for test_ros2_colcon.sh and no SKIPPED line at all, so the new chmod 000 case ran its assertions on CI.

Note for the host, not a code finding: the pull request body's `## Decision summary` was written at publish and does not describe the two fix passes since (the interrupt handler restoring the caller's traps; the tool-route `adapter test` refusing a required repo missing from disk and failing on an unreadable `.repos` file; `grep -s`, the comments, the release-file test). Update it before the merge decision.

### Findings
- [x] (suggestion, deferred, Local Review @ `d5e6444`) A root run prints `SKIPPED:` for the chmod 000 case but no counter counts it, so the summary says `0 skipped`. It cannot occur on CI: the job runs the suite directly on ubuntu-latest, no container, as the runner's non-root user, and this head's log shows no SKIPPED line. It can occur in a root shell or a root dev container, where the skip line is still printed but the Results line undercounts. The gap is suite-wide, not this pull request's: main already has eight uncounted skip sites (lines 3114, 3156, 3179, 3540, 3647, 3847, 3895 for missing SHA-256 git, timeout, timeout --foreground, flock, /proc; 4412 for the root skip), so counting only the new one would leave the summary wrong in the same way for the rest. Fix, about 20 lines, in a later part of #503 or its own issue: one counter (e.g. ENV_SKIPPED) incremented at all nine sites, added to the Results sum with a "=== SKIPPED: N environment-dependent case(s) ===" line like the existing three, and a counter test like the one at line 1150 — `.agent/scripts/tests/test_ros2_colcon.sh:4782` (deferred: deferred by the owner at the findings checkpoint 2026-11-23 ("Merge, defer F1") to a later part of issue 503)

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-23 13:39 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: findings
**Decision**: merge

The owner's answer in the dialog, to "Merge pull request #562 with F1 deferred to a later part of issue #503?": "Merge, defer F1 (Recommended)". The dialog showed: the Integrated Review at 98a3505a (no must-fix, CI all-pass on d5e64448, no GitHub reviews or comments, one suggestion classified as deferred); what the pull request does on the tool's route; six review rounds, four defects found and fixed, the adapter suite at 1551 passed, 0 failed, 0 skipped on CI with both real-tool tests run. F1, the open suggestion: when the suite runs as root the chmod 000 case prints SKIPPED without being counted, with eight more such uncounted skips already on main, none possible on CI, one counter for all nine about 20 lines; deferred to a later part of issue 503. F2, to know: a root assembled by hand without a distros mapping now fails validate, and package selection through the adapter's build is narrower. F3, to know: the last review round was a check of the fixes only, with no outside reviewers, by the host's direction; a full re-review was offered and not chosen. The pull request's text was brought up to date with the two fix passes before the question was asked.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:16 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan checkpoint after a merge; the plan names its remaining work only as "Later parts", with no reviewed steps, so proceed is not open)
**After**: plan
**Decision**: revise

Pull requests 513 and 514 (part 1) and 562 (part 4: validate, build and test call the tool) are merged; the issue is still open because registration from a manifest and the rest of the later parts remain. Since part 4, issue 569 part 2 (pull request 597, merged 2026-11-24) cut the adapter's manifest route: the adapter now has two routes, `register_project.sh` refuses `--set source=` for a `ros2_colcon` project through the new `registration_refused` list, and the settings keys `source`, `source_ref` and `source_path` are read by no route. The plan is revised to plan the next part against that code: registration passes the manifest's location, role, distro and fetch settings to the tool's `init` (the manifest roadmap's line), with the later parts named so a later run can tell which are delivered. The owner asked on 2026-11-24 for manifest work that can run in parallel; this issue's files (the registration scripts and the adapter) do not overlap the tool's, where issues 569 and 498 are working.

## Plan Authored
**Status**: complete
**When**: 2026-11-24 13:20 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-503/plan.md` at `f484a921`

Revision: part 2 (registration from a manifest) planned in full. register_project.sh takes --manifest (local file), --distro, --role, --with, --fetch-from and hands them to the adapter's setup, which runs init --distro-dirs --yes; nothing is recorded in the registry line or settings file. A URL or git location is refused before anything is written until issue 498. Findings 1 to 3 of #599 are folded in; part 3 stays a named later part. Three open questions for the owner.
