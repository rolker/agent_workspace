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

## Plan Authored
**Status**: complete
**When**: 2026-11-10 13:22 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-436/plan.md` at `6206a900`

Three pull requests. PR 1 (detailed): the resolver emits `layers.txt`, `optional_layers.txt` and `--repos-subdir`; `make install-ros-manifest`; keys `manifest`, `manifest_ref`, `manifest_path` (role and distro stay on the registry line, where the dispatcher already reads them); a manifest route in the `ros2_colcon` adapter reading one generated directory; optional verb `repo_pin`; synthetic tests; design section. PR 2: roadmap and west-variant records. PR 3: manifest text and drafted issue as records. Ten decisions listed for the owner's veto in the plan.

## Plan Review
**Status**: complete
**When**: 2026-11-10 13:26 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #436 — Use the new manifest format for the second-machine test: the ROS adapter calls the manifest resolver
**Plan**: `.agent/work-plans/issue-436/plan.md` at `6206a900`
**Branch**: `feature/issue-436`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | Pull request 1 touches the resolver (4 modules and tests), Makefile and CI, the settings keys in 5 scripts, the adapter route, a new optional-verb mechanism in the dispatcher and `validate_adapter.sh`, 4 test suites and 2 documents: well past one reviewable change. See finding 4. |
| Issue alignment | Good | All five needs of the issue are covered, and the Issue Review's actions are taken (three pull requests, resolver writes `layers.txt`, venv install, keys named, bootstrap route untouched). Serves, as written: "Workspace goal "Multiple projects" (README, Workspace goals), under `docs/design.md#registry-and-adapters`". The anchor exists; "Multiple projects" is not a section of README "Workspace goals" (sections: Quality of the work, Trust..., Flexibility, Modular, Light touch on projects, Easy to use, The long view). See finding 10. |
| File targeting | Good | Files match the code paths checked below. The `.gitignore` question for the generated directories is unanswered (finding 7). |
| Consequences | Needs work | The ADR-0011 rule change is not in the table (finding 3); refresh of the manifest clone and of the extends cache is not covered (findings 1, 2). |
| Principle alignment | Needs work | "Keep one current design": optional verbs change ADR-0011's rule while the plan says ADR-0011 is unchanged. "Test what breaks": the sync test as written (edit, then sync) would not catch findings 1 and 2. |
| ADR compliance | Needs work | ADR-0011 (finding 3). ADR-0009 tier 1 says a persistent tool goes in `requirements.txt`; a make target is defensible but the plan should say why (finding 5). Others as the plan states. |
| ROS conventions | N/A | Workspace plan; no ROS node or interface changes. |

### Claims checked against the code

- Adapter reads: `_rc_manifest_dir` (adapter.sh:65), `_rc_layers` (:101), `_rc_is_optional_layer` (:110), setup loop (:459), sync (:559), validate (:601); `_rc_bootstrap_manifest` at :288; `vcs import --skip-existing` at :471. Confirmed.
- Role and distro: `role=`, `distro=` documented as registry trailing fields (`_project_registry.sh`:31-33); read into `ACTIVE_PROJECT_ROLE`/`ACTIVE_PROJECT_DISTRO` at `adapter`:245-255; `_rc_distro` uses the registry distro first (:136). `ACTIVE_PROJECT_ROLE` has no reader today. Confirmed.
- Resolver: `resolve --manifest <file> --role --distro --out [--cache-dir]`; writes flat `<out>/<layer>.repos` only, skips a layer with no selected repo, warns and exits 0 on zero repos; `extends` with `url`+`ref` is cloned by `_clone_or_reuse` with `git clone --branch <ref> --depth 1` and a cache hit is reused forever (`extends.py`). Confirmed.
- `REQUIRED_VERBS` at `adapter`:68, check at :164, "does not implement verb" at :345. Confirmed.
- Downstream of `layers.txt`: only the `ros2_colcon` adapter reads it (`worktree_repos`, `worktree_env` and `--layer` validation go through `_rc_layers`); `register_project.sh`:625 tests `configs/manifest` for type detection. No script assumes the fixed seven-layer list; only `tools/ros-manifest/tests/test_acceptance_p11.py` has a `LAYERS` constant and it calls `emit_layer`, so it is unaffected. Leaving an empty layer out of the generated `layers.txt` is consistent with issue 267 decision 2 (the manifest's list stays fixed; the generated file is per role and distro).
- `register_project.sh` on an existing line refuses a new or changed `role=`/`distro=` ("no silent rewrite; edit ... by hand", :682-685). The two Rolling/Jazzy instances on this machine have no `role=` or `distro=` on their lines.

### Findings

Must-fix:

1. **[Approach: manifest clone refresh]** `_rc_manifest_fetch` says "`git fetch` plus checkout of the ref on later runs". For a branch ref, `git checkout <branch>` after a fetch does not move the local branch, so `sync` resolves the old manifest and the plan's goal "so a manifest change reaches the checkouts" fails silently. Nothing says what happens when the clone is dirty or on another branch (the owner editing the manifest there), where a forced checkout fails or moves him off his work; `_rc_bootstrap_manifest` reports and reuses in that case. Specify per kind: branch, fast-forward only when clean and on that branch, else report and resolve what is checked out; tag or commit, detached checkout. A commit needs clone then checkout (`git clone -b` takes no SHA). The sync test must push a manifest change to the bare remote and then sync, not edit the clone.
2. **[Approach: extends cache]** The resolver reuses a cached `extends` clone forever (`extends.py` `_clone_or_reuse`, keyed on url and ref, no fetch), and the plan makes the cache persistent (`--cache-dir <root>/configs/manifest-cache`). A git-hosted base on a branch (the chain issue 267 decision 1 expects: generic base, then platform manifest) never refreshes on `sync`, with no message. Fix in one place and test it: resolve with a cache directory inside the temporary sibling directory (fresh every run, discarded), or have the resolver refresh a branch ref. Note also that `extends` cannot take a commit (`--branch`), while the plan's leaf can; state the difference or align them.
3. **[ADR compliance: ADR-0011]** `OPTIONAL_VERBS` changes the contract rule "`validate_adapter.sh` asserts every type implements every verb" (ADR-0011, Rules) while the plan says ADR-0011 is unchanged, and callers must now handle "does not implement". Either amend ADR-0011 as ADR-0012 did (10 to 12 verbs), or make `repo_pin` a 13th required verb (`single_project` prints its checkout's branch), or move `repo_pin` to issue 429, its only consumer. Record the choice for the owner's veto.

Suggestions:

4. **[Scope]** Cut pull request 1 in three: (a) resolver additions, `install-ros-manifest` and CI (`tools/ros-manifest/`, `Makefile`, workflow), reviewable and testable alone; (b) settings keys, adapter route, tests, design section; (c) `repo_pin` with the ADR-0011 decision, or folded into issue 429. Decision 9's reason ("the adapter cannot be tested without them") is met by merging (a) first.
5. **[Fresh machine]** Walked through: `make setup` (venv, then git-bug and the legacy `project.done` before the new target), `make install-ros-manifest` (PyPI for PyYAML and setuptools build isolation), `register_project.sh <dir> ros2_colcon --distro rolling --role <r> --set manifest=<url> --set manifest_ref=<ref>`, which writes the line and file, runs `adapter setup` (directory missing), then the static gate with `adapter validate`. It works if every tool is there. Gaps: the `vcs` check runs after fetch and resolve and names no install; check it first and name the install. State the network needs (PyPI, the manifest host, extends hosts, package hosts). On the manifest route, `_rc_require_manifest`'s message describes the `configs/manifest/` ros2_agent_workspace shape; it should name `adapter --project <name> setup`. Say why a make target rather than `requirements.txt` (ADR-0009 tier 1). An adapter run from a worktree calls the main checkout's editable resolver, which may lack `--repos-subdir` until merged; catch the usage error and name the reinstall.
6. **[Route selection]** The implicit route is right (it is how `bootstrap_url` works today) and a misspelled key already stops every verb (unknown-key error). Add: refuse `manifest_ref`/`manifest_path` when `manifest` is unset; when `manifest` is set and any other bootstrap source resolves (`BOOTSTRAP_URL` env, legacy `MANIFEST_BOOTSTRAP_URL` in `projects.d/<name>.sh`, as the existing instances here have, `configs/project_bootstrap.url`), refuse or warn, not only for the `bootstrap_url` key; the bootstrap route's "no bootstrap URL" error should also name `manifest=`. Say whether the manifest route accepts the legacy `ROS_DISTRO` fallback that `_rc_distro` still has, since the plan says distro is required on the registry line.
7. **[Generated directory]** `configs/manifest-resolved`, `-src` and `-cache` sit in the hosting root; here that is under the ignored `projects/`, but a hosting root that is its own git checkout would show them untracked: say so or add an ignore. `rename(2)` cannot replace a non-empty directory (ENOTEMPTY); use a symlink swap (`ln -s` + `mv -T`), as `configs/manifest` already is a link. A package worktree's `env.sh` is written at create time and goes stale when a `sync` changes the layers. After a role change, `vcs import --skip-existing` never removes checkouts and colcon still builds them; `validate` should at least warn about checkouts not in the generated `.repos`.
8. **[repo_pin]** Branch first is right for a pull-request base (a same-named tag does not stop `--base`). Shallow or single-branch clones still have the pinned branch's remote ref. Local-only gives `unknown` for a pin not yet fetched and a false `branch` for a remote ref left after the branch was deleted upstream. Keep the kind out of the manifest (git is the authority, and an extra field per repo drifts); confirm with `git ls-remote --heads origin <ref>` when online, local fallback otherwise. `_rc_repos_entries` keeps YAML quotes, and PyYAML writes a numeric-looking tag as `version: '2.0'`; strip quotes and test it (sync's branch compare is affected too).
9. **[Resolver CLI]** Tying the zero-repos error to `--repos-subdir` hides one behaviour behind an unrelated flag; use its own flag or rely on `_rc_require_manifest`'s empty-`layers.txt` check before the swap. Write `layers.txt`/`optional_layers.txt` only under the new option, or the "flat output unchanged" claim is false.
10. **[Issue alignment: Serves]** Name a real README goal section; "Modular" (knowledge about a kind of project, such as ROS, added as modules) fits.
11. **[Role model]** Pull request 1 does not depend on it: a role is a name passed to `--role` and an unknown name is the resolver's error. Pull request 3's draft with a role with no `roots` is the groups model in effect; say it is provisional pending issue 267 decision 4.

### Role and distro: registry line or settings file

The registry line is the right home. Issue 267 records "registry/instance names a role and a distro"; `docs/design.md#registry-and-adapters` describes the registry as the name, directory and type "plus optional `key=value` fields"; the fields, their validation and the dispatcher's reading already exist. A project changes its role without re-registering by editing its line in `.agent/projects.local` and running `adapter sync`; `register_project.sh` refuses to add or change a field on an existing line and itself says "edit by hand". The adapter's missing-role, missing-distro and stale-`.resolved-from` messages should say exactly that.

### Summary

The route is the least change on the adapter side (one generated directory with the existing contract, every other verb untouched) and the plan's code claims hold. Three gaps would make `sync` silently stale or contradict ADR-0011: the manifest clone's branch refresh, the extends cache that never refreshes, and optional verbs without an ADR change. Fix those, split pull request 1, and it is ready.

### Recommended Actions

- [ ] Specify the manifest clone's update per ref kind, and the dirty or other-branch case; test with a push to the bare remote.
- [ ] Make extends refresh on `sync` (fresh cache per resolve, or resolver refresh) and test it with a branch-pinned base.
- [ ] Decide `repo_pin`'s place (amend ADR-0011, required 13th verb, or issue 429) and record it for veto.
- [ ] Split pull request 1 into resolver and install, adapter route, and `repo_pin`.
- [ ] Take suggestions 5 to 11 as the implementer sees fit.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 13:28 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review confirmed the plan's reading of the code and found three must-fixes in how it is built, none a change of what the owner asked for; first host revise on this plan)
**After**: plan
**Decision**: revise

Host read the Plan Review (needs-work, 3 must-fix, 6 groups of suggestions) and directs:
- Must-fix 1 and 2 are one concern, a stale manifest: `sync` must resolve what the remote holds now, for the leaf manifest and for every `extends` base. The leaf clone is refreshed so a moved branch is followed (and a commit pin, a dirty clone and a clone on another branch each have a defined result); the resolver's extends cache is fresh per resolve or refreshed. Tests push a change to the bare remote and then sync, for the leaf and for a base.
- Must-fix 3: `repo_pin` leaves pull request 1. It becomes its own small pull request on this issue, as a required verb every type implements (a single-repository type answers with its default branch), with ADR-0011's verb list updated in that pull request, so "every type implements every verb" stays true.
- Size: pull request 1 is split as the review proposes: (a) the resolver additions, the install target and CI; (b) the settings keys, the adapter route, tests and design; (c) `repo_pin`. The records pull request and the manifest-text pull request follow as planned.
- Role and distro stay on the registry line: the review confirms the planner was right and the host's direction wrong (issue 267 records "registry/instance names a role and a distro"). The adapter's messages say how to change a role: edit the line, run `adapter sync`.
- Take every suggestion as worded: check `vcs` first and name its install; state the network needs; refuse `manifest_ref` or `manifest_path` without `manifest`, and refuse or warn when `manifest` is set and another bootstrap source also resolves; swap a symlink for the generated directory; say what goes stale in an existing package worktree after `sync` and have `validate` warn about leftover checkouts after a role change; `repo_pin` confirms with `git ls-remote` when online and strips YAML quotes; the resolver writes `layers.txt` only under the new option; Serves names a README goal section; the drafted manifest in the last pull request is marked provisional on the role model, which is with the owner.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 13:31 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-436/plan.md` at `deca7bd8`

Revised after the plan review. Five pull requests: (a) resolver additions, install target, CI; (b) settings keys, adapter route, tests, design; (c) `repo_pin` as a required verb with ADR-0011 amended; (d) records; (e) manifest text and drafted issue, provisional on the role model. A stale manifest is one rule: after `sync` the leaf clone follows its remote per ref kind (never forcing a dirty clone) and every `extends` base is cloned afresh per resolve; each case is tested by pushing to a bare remote then syncing. All review suggestions taken.

## Plan Review
**Status**: complete
**When**: 2026-11-10 13:32 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent acaa509cb79937290, resume 1 of 3)
**Verdict**: needs-work

**Issue**: #436 — Use the new manifest format for the second-machine test: the ROS adapter calls the manifest resolver
**Plan**: `.agent/work-plans/issue-436/plan.md` at `deca7bd8`
**Branch**: `feature/issue-436`

Second review, narrow: are the first review's findings resolved as worded, and did the revision introduce anything wrong? Serves, as checked: "Workspace goal "Modular" (README, Workspace goals ...), under `docs/design.md#registry-and-adapters`" (the section and the anchor both exist).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Five pull requests; (a) is self-contained (resolver, make target, CI) and reviewable alone. |
| Issue alignment | Good | Serves now names a real README goal section (finding 10 resolved). |
| File targeting | Good | (a) is `tools/ros-manifest/`, `Makefile`, the workflow. |
| Consequences | Needs work | The temporary `extends` cache changes the resolver's provenance output (finding 1). |
| Principle alignment | Good | Stale-manifest rule stated once and tested by push-then-sync; ADR-0011 amended instead of bent. One gap in the rule (finding 2). |
| ADR compliance | Good | ADR-0011 amended in (c) as ADR-0012 did; ADR-0009 departure explained in (a) step 4. |
| ROS conventions | N/A | Workspace plan. |

### Earlier findings, checked

- Must-fix 1 (leaf refresh): resolved. Per-kind table, never forcing a dirty clone, full clone so a commit is reachable, push-then-sync tests. One hole, finding 2.
- Must-fix 2 (extends cache): resolved for staleness (fresh `--cache-dir` per resolve, test with a bare base remote, commit-in-extends error tested). It introduces finding 1.
- Must-fix 3 (ADR-0011): resolved. `repo_pin` is a 13th required verb in (c), `single_project` implements it, ADR-0011 amended.
- Suggestions 4 to 11: all taken as worded (split; `vcs` first with its install; network needs; `--layout` with flat unchanged and no zero-repos coupling; route refusals for all four bootstrap sources and for `manifest_ref`/`manifest_path` without `manifest`; legacy `ROS_DISTRO` refused on the route; symlink swap; the `env.sh` staleness printed; leftover-checkout warning; quote stripping; `ls-remote` for the kind; Serves; (e) provisional).

### Findings

Must-fix:

1. **[Consequences: provenance, issue 267 decision 5]** The resolver labels each manifest with its file path (`schema.py` `load_manifest_file`: `source=str(path)`), and that label is the provenance written into every generated `.repos` header (`emit.py` `_header`). With the cache inside a temporary directory, a base's provenance becomes a deleted path like `configs/<tmp>.cache/<hash>/manifest.yaml`, different on every `sync`. So decision 5's "with provenance (which manifest contributed each repo)" no longer says which manifest, and every sync rewrites every header. The fix is small and self-contained, so it belongs in (a): label a git-backed manifest `url#ref/path` (the label `schema.py`'s `Manifest.source` comment already promises), plus the clone's commit, so the header also records which base commit was resolved. Test it in (a) with a `file://` base.

Suggestions:

2. **[Stale rule, (b)]** A clean clone that is *ahead* of `origin/<ref>` (local commits, remote unmoved) passes `git merge --ff-only` as "Already up to date". It falls in no warning row, so it resolves local commits silently. State the rule as "clean and HEAD equals `origin/<ref>` (or the tag's or commit's object), otherwise `manifest-state=local` with the warning", and test the ahead case. Count only tracked changes as dirty (`--untracked-files=no`), so editor files do not raise the warning.
3. **[CI, (a) step 5]** The "Validate Adapter Contract" job (`runs-on: ubuntu-latest`) has no `actions/setup-python`. A plain `pip install -e` there hits PEP 668 on Ubuntu 24.04 runners. Add setup-python as the `validate-ros-manifest` job does. In (b), make the wrapper find that python (not only `<repo>/.venv`), and make CI fail rather than print `SKIPPED` when the real-resolver tests do not run (an env flag), or CI can go green with the route untested.
4. **[Offline, (b)]** Add an offline case for a base (path-form leaf with a git `extends`, base remote removed): the resolve fails, the previous link stays, exit 1. The adapter should add one line after the resolver's clone error: "previous generated directory kept; env/build still use it". Clean up `<tmp>` and `<tmp>.cache` on every exit path. Note that `setup` on an already-set-up hosting directory now needs the network on this route, where the bootstrap route did not.

### The two choices asked about

- **Dirty leaf clone resolved as it is, with a warning.** Enough, provided finding 2 is fixed. It is not silent: stderr on every `setup` and `sync`, `manifest-state=local` in `.resolved-from`, and a `validate` warning each run. Refusing would block a working style the owner uses (edit the manifest, resolve, test before pushing). A fresh machine never has a dirty clone, so the acceptance run is not affected. Make the warning list the changed files.
- **A fresh shallow clone of every `extends` base on every `sync`.** Cost is small: a shallow clone of a small manifest repository per base, next to `sync`'s fetch of every package repository. Offline, `sync` fails clearly: a leaf URL fails at the fetch first; a path leaf fails at the resolver's clone error, passed through. The previous generated directory and link stay, so `env`, `build` and `test` keep working. The real cost is finding 1, not time.

### Summary

The first review's three must-fixes and its suggestions are resolved as worded. The revision introduced one regression, finding 1: base provenance becomes a temporary path that is deleted after each resolve. That is a few lines in the resolver and belongs in (a). Pull request (a) is ready to implement with finding 1 and suggestion 3 added to its steps; (b) carries suggestions 2 and 4. No further plan review is needed for that.

### Recommended Actions

- [ ] (a): label git-backed manifests `url#ref/path@<commit>` in the provenance; test with a `file://` base.
- [ ] (a): setup-python in the adapter-contract CI job before installing the resolver.
- [ ] (b): stale rule is "clean and HEAD equals the remote object"; ahead-of-remote is `local`; tracked changes only; warning lists files.
- [ ] (b): wrapper finds the CI python; CI fails on skipped real-resolver tests; offline base case; temp cleanup; the "previous directory kept" line.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 13:40 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second plan review found every earlier finding resolved and one new must-fix that is a few lines inside pull request (a); the reviewer states (a) is ready to implement once that fix and one CI step are added to its steps, with no further plan review needed)
**After**: plan
**Decision**: proceed

Host read the second Plan Review and carries to the implementer of pull request (a): a git-backed manifest is labelled `url#ref/path@<commit>` in the provenance of every generated `.repos` header, never by a temporary file path, with a test using a `file://` base (issue 267, decision 5); the CI job that installs the resolver sets up Python first. Carried to pull request (b) when its turn comes: a clean clone that is ahead of the remote is not "what the remote holds" (define it as clean and HEAD equal to the remote object; only tracked changes count as dirty); the dirty-clone warning lists the changed files; an offline test for a base; temporary directories cleaned up; a line saying the previous generated directory is kept; CI fails rather than skips when the real-resolver tests do not run. Pull request (a) is implemented now; (d), the records, can run alongside once (a)'s branch is published, since one branch carries this issue's pull requests in turn.
