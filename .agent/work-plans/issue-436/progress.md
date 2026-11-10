---
issue: 436
---

# Issue #436 — Use the new manifest format for the second-machine test: the ROS adapter calls the manifest resolver

## Issue Review
**Status**: complete
**When**: 2026-11-10 13:10 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #436

### Scope Assessment

**Well-scoped?** Needs a split. Need 1 (adapter route), need 2 (settings) and need 5 (base-branch pin) are one adapter change; need 3 (manifest text and drafted project issue) lands in another repository's records; need 4 (roadmap and west-variant doc) is workspace documentation. Proposed order below.
**Right repo?** Yes for 1, 2, 4, 5 (workspace: `.agent/project_types/ros2_colcon/`, `tools/ros-manifest/`, `docs/roadmap.md`). Need 3 is project work: the manifest text belongs in the project's manifest repository, and this issue drafts it into this workspace's records and opens nothing there (session-root rule, ADR-0016: a session changes only the root it was launched in; a cross-root change is an issue).
**Serves**: Workspace goal "Multiple projects" (second-machine acceptance case in the roadmap Direction section) — `docs/design.md#registry-and-adapters`
**Design picture?** Changes `docs/design.md#registry-and-adapters`: the adapter gains a second manifest route and the per-project settings file gains keys. The owner's decisions are recorded in the issue body and in issue 267, so this is `OK`, not a new question; the design section update belongs in the same pull request as the adapter change (ADR-0017).
**Dependencies**: 429 (consumes the pin); 435 (fork parity audit, source of the base-branch finding, open on `feature/issue-253`); the project-side manifest landing is a separate repository's issue. No blocker for the adapter work.

**What the records already settle (issue 267 body, six owner decisions of 2026-09-16; plan, README, design, ADRs)**

- Need 1, call by CLI only: settled. 267 "the `ros2_colcon` adapter becomes a thin caller of it"; README "integration is CLI-only (subprocess)"; plan.md "Adapter integration": resolve into a temporary or cache directory, then run the existing `vcs import --skip-existing` loop unchanged against the generated files; legacy `layers.txt`/`repos/*.repos` stays supported. Marker file `manifest.yaml` versus `layers.txt` is proposed there for detecting the route.
- Need 2, the project says its route: partly settled. 267 "registry/instance names a role and a distro" (a role and a distro are named; the settings key names and the route switch are not). Today's keys (`_PROJECT_FILE_KEYS` in `_project_registry.sh`): build, test, install, bootstrap_url, location, location_path, tracking, instructions. Distro today comes from `distro:` in `bootstrap.yaml` or `ROS_DISTRO` in the legacy `projects.d/<name>.sh` (`_rc_distro`).
- Need 3: nothing recorded on the text itself. The fixture `tools/ros-manifest/tests/fixtures/p11/manifest.yaml` is a re-expression of the Jazzy manifest with per-distro override for the core repository (`rolling`) and a single role `dev` with empty subtract/add.
- Need 4: the roadmap row "Manifest support (step 4)" still says "planned" and "west variant ... next milestone"; the owner's decision (Q4) supersedes that. `docs/roadmap.md` "Decided Against" has no west entry yet. Roadmap and `docs/west-variant.md` edits are documentation only.
- Need 5: 267 decision 3 ("distro is a selector, not a branch", per-distro ref, rolling pins the core repo to `rolling`). The resolver already gives that ref per distro (`resolve_distro_ref`) and writes it as `version:` in each generated `.repos`. What is not settled is how a consumer asks for it.
- Installing the tool, vcs2l and the tool's name/home are not settled: ADR-0009 tier 1 covers only workspace automation tools listed in `requirements.txt`; the README says nothing in `.agent/` imports the tool; 267 left vcs2l "owner decision pending" and the issue body says name and repository are placeholders.
- Role model: left open by 267 decision 4 ("decide on the prototype's evidence"). Not decided by any record found. Both models are implemented in `selectors.py`. The fixture has one role and no groups, so there is no evidence from it.

**How the adapter fetches today (`.agent/project_types/ros2_colcon/adapter.sh`)**

- `adapter_setup`: `_rc_bootstrap_manifest` resolves the URL (env `BOOTSTRAP_URL`, settings `bootstrap_url`, legacy `MANIFEST_BOOTSTRAP_URL`, `configs/project_bootstrap.url`), downloads `bootstrap.yaml`, clones the manifest repo (`git_url`, `branch`, optional `layer`, `config_path`) and symlinks `configs/manifest` to its config directory. Then `_rc_require_manifest` checks `layers.txt`, and for each layer `vcs import --skip-existing <layer>_ws/src < repos/<layer>.repos`; layers in `optional_layers.txt` may fail.
- Every other verb (`validate`, `sync`, `repos`, `worktree_repos`, `worktree_env`) reads `layers.txt` and `repos/*.repos` through `_rc_manifest_dir`. Least change: the new route leaves that directory contract alone and makes `_rc_manifest_dir` return a generated directory holding `layers.txt` and `repos/<layer>.repos`. Then only `setup` (and the point where `configs/manifest` is produced) differs between routes.
- Slot: in `adapter_setup`, replace `_rc_bootstrap_manifest` with a route switch: if the project's settings name a manifest, fetch/locate it and run `ros-manifest resolve --manifest <path> --role <role> --distro <distro> --out <generated dir>`, then proceed into the same loop. `sync` must re-run `resolve` so a manifest change reaches the checkouts.
- Gaps the resolver does not cover: it writes only `.repos` files, no `layers.txt` (layer order lives in the manifest and `resolve` skips empty layers), and the schema has no optional-layer concept (the real Rolling manifest marks `site` optional because it may be private). The adapter needs either a small resolver CLI addition (emit `layers.txt`, mark optional) or an adapter-side workaround. Fetching a manifest that lives in a git repository (not a local path) also needs a clone step the adapter owns; `extends` with url+ref+path is the resolver's.
- Settings needed per instance in `.agent/projects.d/<name>`: a manifest location (git URL + ref + path, or a local path), a role, a distro. Distro becomes explicit in the settings for this route (today Rolling gets it from `bootstrap.yaml`, Jazzy from `ROS_DISTRO` in the legacy `.sh`). The registered `p11-rolling.sh` and `p11-jazzy.sh` on this machine are legacy `.sh` files holding `MANIFEST_BOOTSTRAP_URL` (+ `ROS_DISTRO` for Jazzy); read, not changed.
- The new keys need the usual consequences: `_PROJECT_FILE_KEYS`, `_project_file_value_error`, the header grammar in `_project_registry.sh`, `unused_settings` for `single_project` (it must list them), `project_setting.sh`, `register_project.sh` flags, `docs/design.md#registry-and-adapters`, `knowledge/script_reference.md`.

**Installing the resolver where the adapter runs**

- Not recorded as a decision. ADR-0009: bare `pip install` is forbidden; tier 1 (workspace `.venv`, listed in `requirements.txt`) is for workspace automation not a ROS build dependency; tier 2 `pipx` is for user-facing CLIs not needed by workspace automation. The adapter is workspace automation that now depends on it, so tier 1 fits: `.venv/bin/pip install -e tools/ros-manifest` from a make target (the dev setup already creates `.venv`), and the adapter calls `$WORKSPACE_ROOT/.venv/bin/ros-manifest`, with a clear error naming that command when absent. PyYAML is its only dependency. A fresh machine needs `make` setup then `adapter setup`; also needs `vcs` (stale `vcstool` or vcs2l, owner decision still pending, independent of this issue; adapter already errors clearly if `vcs` is missing).
- The README's "nothing in `.agent/` imports it" stays true (subprocess only), but its "adapter wiring is a follow-up" text and the CI line (`pip install -e`) need updating.

**Base-branch pin for package pull requests (need 5)**

- Surface the pin from the resolved `.repos`: the generated `version:` for the repository whose URL matches. Least change: an adapter verb (for example `repo_pin <owner/repo>`) that prints the pinned ref from the generated `.repos` via the existing `_rc_repos_entries` parser, working for both routes because bootstrap-route `.repos` files carry the same `version:`. Caveat for 429: a `version` can be a tag or SHA, not a branch; the verb should print the ref and say whether it is a branch name, and 429 decides what to do otherwise. Hosted branch default (`jazzy`) versus pin (`rolling`) is exactly the case this serves.

**Test and fixture hygiene**

- The adapter tests (`test_ros2_colcon.sh`) already run only against `mktemp` sandboxes with stub `vcs`/colcon. The new route's tests should use a synthetic manifest generated in the sandbox (two or three invented repositories, two layers, one per-distro override, one absent-for-distro repo, two roles) with `file://` repositories or stub `vcs`, plus a stub or the real `ros-manifest` from the venv. The `p11` fixture stays confined to `tools/ros-manifest/tests` (it is data for the resolver's own acceptance test and is not read by script tests).
- Acceptance "on a machine with no earlier checkout ... `adapter validate` passes" is a real-project run on the second machine, not part of the script tests: it is the owner's acceptance run, mechanism tests stay synthetic.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | OK | The owner's decisions are on record in the issue and in 267; design section update is part of the adapter pull request, not a new question. |
| Ask about what matters | Action needed | Role model (groups versus dependency closure) is open in 267 and nothing records a decision. The test needs one role per instance. The owner should decide, or say "start with groups, the fixture has no evidence yet". See Recommendations for what each choice changes. |
| Only what's needed | Watch | Do not add layers/optional-layer semantics, vcs2l or a resolver rename here; only what the second-machine test needs (a `layers.txt` and optional marking are needed because validate/setup read them). |
| Put each thing at the level it applies to | Watch | Manifest text and its issue belong to the project's own repository; this issue drafts them into this workspace's records and opens nothing there (ADR-0016). |
| Workspace is project-agnostic (ADR-0003) | Watch | Mechanism text and tests name no project; the p11 fixture stays within `tools/ros-manifest/tests`. |
| Verify before claiming | Watch | The adapter call must be exercised by a run (sandbox test, and the owner's real run), not only described. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0003 workspace is project-agnostic | Yes | Tests and scripts synthetic; names allowed in records only. |
| ADR-0009 python package management | Yes | Resolver install into workspace `.venv` through a make target; no bare pip. |
| ADR-0011 project-type adapter contract | Yes | New route is internal to `ros2_colcon`; verbs keep their contract; `repo_pin` would be a new optional verb, check the contract's verb list. |
| ADR-0012 worktree composition is an adapter concern | Yes | `worktree_repos`/`worktree_env` read `.repos` through `_rc_manifest_dir`; keeping that directory contract keeps them unchanged. |
| ADR-0016 session roots | Yes | This session changes only this root; the project manifest and its issue are drafted, not opened. |
| ADR-0017 design is the current picture | Yes | Update `docs/design.md#registry-and-adapters` in the same pull request. |

### Consequences

- `docs/design.md#registry-and-adapters`, `docs/roadmap.md` (Direction line, "Manifest support (step 4)" row, "Decided Against" west entry), `tools/ros-manifest/README.md` and `docs/west-variant.md`.
- Settings keys: `_project_registry.sh` header and key list, `unused_settings` for `single_project`, `project_setting.sh`, `register_project.sh`, `script_reference.md`, and the tests for them.
- Makefile/dev-setup target and `requirements.txt` or an editable install for the resolver; CI job unchanged.
- `validate_workspace.py` and the `Direction` checks if a Direction line adds a check.

### Recommendations

- Decide the role model for the test with the owner. Groups: roles subtract default-included groups and opt into default-excluded ones; it needs the manifest to tag repos in groups (annotation burden, maps to what `izzyboat = platform + hw:deltat` looks like); a repo missing from a role is a tagging mistake. Dependency closure: roles are root packages and `package.xml` dependencies select the rest; no tagging, but it needs `package.xml` files present before the closure can be walked, i.e. an already-fetched source tree, so a first fetch on a fresh machine cannot use it alone. Recommend starting with groups for the first run (the first fetch cannot walk package.xml of unfetched repositories) and recording that the role model remains open for closure. Owner confirms or overrides.
- Split into three pull requests in this order: (1) workspace: adapter route, settings keys, resolver install, `repo_pin` verb, synthetic tests, design section update; (2) roadmap and `docs/west-variant.md` documentation (Direction line in the owner's words, row 3 update, "Decided Against" west entry with its revisit condition), can run in parallel with 1; (3) the manifest text and drafted project-repository issue as workspace records (a plan or work-plan file under this issue), opening nothing in the project repository; the owner decides how it lands. The acceptance run on the second machine follows (1) and the owner's landing of (3).
- Decide in the plan the two resolver-side gaps: emit `layers.txt` (and mark optional layers) from `ros-manifest resolve`, or derive them in the adapter; recommend the resolver emits layer order since it owns the layer list.
- Name the settings keys and the route switch in the plan (a manifest location, role, distro), and state the legacy `bootstrap_url` route stays untouched when none is set.
- Install the resolver into the workspace `.venv` via the existing dev-setup target (ADR-0009 tier 1) and have the adapter call it by that path with an error naming the install command.

### Actions
- [ ] Role model (groups versus dependency closure) is open in 267 and nothing records a decision; the owner decides, or confirms starting with groups for the first run.
- [ ] Decide the role model for the test with the owner. Groups: roles subtract default-included groups and opt into default-excluded ones; it needs the manifest to tag repos in groups (annotation burden, maps to what `izzyboat = platform + hw:deltat` looks like); a repo missing from a role is a tagging mistake. Dependency closure: roles are root packages and `package.xml` dependencies select the rest; no tagging, but it needs `package.xml` files present before the closure can be walked, i.e. an already-fetched source tree, so a first fetch on a fresh machine cannot use it alone. Recommend starting with groups for the first run (the first fetch cannot walk package.xml of unfetched repositories) and recording that the role model remains open for closure. Owner confirms or overrides.
- [ ] Split into three pull requests in this order: (1) workspace: adapter route, settings keys, resolver install, `repo_pin` verb, synthetic tests, design section update; (2) roadmap and `docs/west-variant.md` documentation (Direction line in the owner's words, row 3 update, "Decided Against" west entry with its revisit condition), can run in parallel with 1; (3) the manifest text and drafted project-repository issue as workspace records (a plan or work-plan file under this issue), opening nothing in the project repository; the owner decides how it lands. The acceptance run on the second machine follows (1) and the owner's landing of (3).
- [ ] Decide in the plan the two resolver-side gaps: emit `layers.txt` (and mark optional layers) from `ros-manifest resolve`, or derive them in the adapter; recommend the resolver emits layer order since it owns the layer list.
- [ ] Name the settings keys and the route switch in the plan (a manifest location, role, distro), and state the legacy `bootstrap_url` route stays untouched when none is set.
- [ ] Install the resolver into the workspace `.venv` via the existing dev-setup target (ADR-0009 tier 1) and have the adapter call it by that path with an error naming the install command.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 13:18 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review keeps the issue's scope and splits it into three pull requests; its one open question about what the owner wants, the role model for the test, is put to him and does not hold the plan for the first two pull requests)
**After**: issue-actions
**Decision**: proceed

Host read the Issue Review. Accepted as plan inputs: three pull requests (1: the adapter route, settings keys, resolver install, a `repo_pin` verb, synthetic tests, the design section; 2: the roadmap Direction line, the step 4 row, the west entry under Decided Against, the west design note; 3: the manifest text and the drafted project issue as records here). Host decisions listed for the owner's veto: the resolver itself writes `layers.txt` and marks an optional layer, so the adapter reads one generated directory for both routes; the resolver is installed into the workspace venv from a make target (ADR-0009) and the adapter calls it by the venv path. The role model for the test (groups or dependency closure) is asked of the owner; the plan passes a role name through and does not depend on the answer.
