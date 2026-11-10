# Plan: Use the new manifest format for the second-machine test: the ROS adapter calls the manifest resolver

## Issue

https://github.com/rolker/agent_workspace/issues/436

## Context

The owner, 2026-11-10: "I want the new manifest to be used for the pickerel test."; on the resolver, "Built in for Q2"; on the west variant, "Q4, decide against". Nothing in `.agent/` calls the resolver today (`tools/ros-manifest/README.md`, "Not built yet"). The `ros2_colcon` adapter fetches from `bootstrap.yaml` and `.repos` files: `_rc_bootstrap_manifest` (adapter.sh:288) then the `vcs import --skip-existing` loop in `adapter_setup` (adapter.sh:445). Every other verb reads `layers.txt`, `optional_layers.txt` and `repos/<layer>.repos` through `_rc_manifest_dir` (adapter.sh:65; reads at 101, 110, 459, 559, 601).

Facts checked in the code that shape the plan:

- The resolver CLI (`tools/ros-manifest/src/ros_manifest/cli.py`, `cmd_resolve`) takes `--manifest <local file> --role --distro --out [--cache-dir]` and `emit_manifest` (`emit.py`) writes flat `<out>/<layer>.repos` only, skipping a layer with no selected repo. It writes no `layers.txt` and the schema (`schema.py`, `_TOP_LEVEL_KEYS`) has no optional-layer concept. `extends` with `url`+`ref`+`path` is resolved by the resolver (`extends.py`); the leaf manifest must be a local file, so a manifest kept in a git repository needs a clone the adapter owns.
- `role=` and `distro=` already exist as trailing fields of the registry line (`_project_registry.sh` header lines 28-43). The dispatcher already reads both into `ACTIVE_PROJECT_ROLE` and `ACTIVE_PROJECT_DISTRO` (`.agent/scripts/adapter:245-255`). `_rc_distro` (adapter.sh:129) already uses `ACTIVE_PROJECT_DISTRO` first. `ACTIVE_PROJECT_ROLE` is read by nothing yet.
- Settings-file keys live in `_PROJECT_FILE_KEYS` (`_project_registry.sh:629`), validated in `_project_file_value_error` (:696), exported by the dispatcher as `ACTIVE_PROJECT_*` (`adapter:277-298`), and refused per type through `.agent/project_types/<type>/unused_settings`.
- The dispatcher dispatches only verbs in `REQUIRED_VERBS` (`adapter:68`, check at :164); ADR-0011 fixes that list at 12.
- The workspace venv belongs to the main checkout (`Makefile` WS_ROOT, lines 31-46); a worktree has no `.venv`.
- Existing adapter tests (`.agent/scripts/tests/test_ros2_colcon.sh`) run in `mktemp` sandboxes with stub `vcs` and `colcon` (`make_toolchain_stubs`).

Issue 267's owner decisions this plan relies on (issue 267 body, "Design decisions (owner, 2026-09-16)"): 1 "One source of truth per manifest; manifests compose" and 2 "Layers stay a fixed, single list per manifest ... Roles only subtract from a layer's list"; 3 "Distro is a selector, not a branch ... a repo may be **absent** from a distro"; 5 "Generated, not hand-maintained, per-distro/per-role vcstool `.repos` files, with provenance"; and the Constraints "No imports from workspace scripts; the adapter calls the CLI only." Decision 4 (the role model) is open and the plan does not depend on it: a role is a name passed through to `--role`.

## Approach

Five pull requests on this issue, in order (a) to (e). (a) and (b) are in implementable detail; (c), (d) and (e) are outlines. The review of the first version (`needs-work`) and the host's checkpoint (Decision: revise) are taken as worded; the first version's pull request 1 is now (a), (b) and (c).

| PR | What | Depends on | Parallel |
|---|---|---|---|
| (a) | Resolver additions, `install-ros-manifest`, CI | none | with (d) |
| (b) | Settings keys, adapter manifest route, tests, design section | (a) merged (the adapter calls the installed resolver) | with (c) and (d) |
| (c) | `repo_pin` as a required verb, ADR-0011 amended | none for the verb itself; its ros2_colcon answer reads the generated or hand-authored `.repos` and so is tested on both routes once (b) is merged | with (b), (d) |
| (d) | Records: Direction line, step 4 row, Decided Against entries (west, six fork-audit lines), west design note | none (its Direction check names this issue) | with (a), (b), (c) |
| (e) | Manifest text and drafted project issue, records only, provisional on the role model | (a) merged (the offline equivalence check runs the resolver with `optional_layers`) | after (a) |

Vocabulary: **bootstrap route** = today's `bootstrap.yaml` flow, unchanged. **Manifest route** = the new one. The route is chosen by one fact: the project's settings file sets `manifest`. A project that sets none of the new keys runs the bootstrap route exactly as today.

### One concern: a stale manifest (applies to (a) and (b))

Rule: after `adapter sync`, what is resolved is what the remotes hold now, for the leaf manifest and for every `extends` base, or the adapter says on stderr that it is not and why. Never silently stale.

**Leaf manifest, git form** (`manifest` is a URL). The adapter owns the clone (`configs/manifest-src/`, a full clone, not shallow, so a commit is reachable; `git clone --no-checkout -- <url> <dir>` on first use; a clone whose `origin` differs from `manifest` is refused, as `_rc_bootstrap_manifest` refuses a mismatch). `setup` and `sync` then run `git fetch --tags --force origin` and decide the kind of `manifest_ref` locally: a branch if `refs/remotes/origin/<ref>` exists, else a tag if `refs/tags/<ref>` exists, else a commit if `git rev-parse --verify <ref>^{commit}` succeeds and `<ref>` is 7 to 64 hex characters, else an error naming the ref. Result per case:

| Case | What is resolved | Message |
|---|---|---|
| Branch that moved, clone clean and on that branch | `git merge --ff-only origin/<ref>`; the new tip | `manifest: updated <ref> <old>..<new>` |
| Branch, ff-only impossible (local commits) | the clone as it is | stderr warning: local commits not on `origin/<ref>`, resolved what is checked out |
| Branch, clone dirty | the working tree as it is, no checkout | stderr warning: uncommitted changes in the manifest clone, resolved those, not what the remote holds |
| Branch, clone on another branch (or detached) and clean | `git checkout <ref>` then ff-only as above | `manifest: switched to <ref>` |
| Branch, clone on another branch and dirty | the working tree as it is | the dirty warning |
| Tag | detached checkout of the tag as the fetch left it (a tag moved on the remote is followed, `--force`) | `manifest: <tag> -> <sha>` |
| Commit | detached checkout of that commit; immutable, so a push to the remote changes nothing until `manifest_ref` is changed | `manifest: pinned <sha>` |
| Tag or commit, clone dirty | working tree as it is | the dirty warning |

A dirty clone is never forced. `.resolved-from` records `manifest-state=local` for every warning case, and `validate` prints it as a warning (the owner editing the manifest in the clone is a supported working style, not an error). A fetch failure (offline) leaves the clone and the previous generated directory as they are and exits 1 on `sync` (exit 1 on `setup` of a fresh dir).

**Leaf manifest, path form**: used in place; nothing to refresh; `.resolved-from` records its modification time and size so `validate` can say `sync` is due when the file changed.

**`extends` bases.** The resolver clones a base with `git clone --branch <ref> --depth 1` and reuses the cache entry forever (`extends.py`, `_clone_or_reuse`: `if dest.is_dir(): return dest`). The fix is in the adapter only and keeps `tools/ros-manifest/` untouched by it: `resolve` is run with `--cache-dir` inside the temporary sibling directory, which is new on every run and discarded after, so every `sync` clones every base afresh and a branch-pinned base follows its remote. The cost is one shallow clone per base per sync, accepted because sync already fetches. (The resolver's own default cache, `.ros-manifest-cache` in the cwd, still persists for people who run the CLI directly; (a) adds a README paragraph saying so and how to refresh: delete it or pass a fresh `--cache-dir`.) Difference stated: `extends` takes a branch or a tag (`git clone --branch` cannot take a commit), while the leaf can also be a commit; a commit in `extends.ref` is the resolver's clone error, which the adapter passes through, and a test asserts it. Aligning them is not done: not needed by the owner's manifests.

Tests (b) for the whole concern, each pushes to the bare remote(s) and then runs `adapter sync`, never edits a clone: leaf branch moved (clean); leaf branch with a dirty clone (warning, local edit resolved); leaf clone on another branch (clean, switched; dirty, warning); leaf commit pin (push does not change the result; changing `manifest_ref` to the new commit does); leaf tag moved with a forced tag update; base branch moved with the leaf's `extends` pointing at a bare base remote; base given as a commit (clone error passed through); offline fetch (bare remote removed) leaves the previous generated directory.

### Pull request (a): the resolver additions, the install target, CI

Inside `tools/ros-manifest/` (self-contained, no workspace imports), plus `Makefile` and the workflow.

1. `schema.py`: new top-level key `optional_layers` (list of strings, each must be in the same manifest's `layers`; add to `_TOP_LEVEL_KEYS`). `merge.py`: `MergedManifest` gets `optional_layers`, the union over the chain in chain order; a name not in the merged layers is a `ManifestError`.
2. `emit.py` and `cli.py`: one new `resolve` option `--layout flat|manifest-dir`, default `flat` (today's output byte for byte, no new files, so the existing tests and the p11 acceptance test are unchanged). `manifest-dir` writes `<out>/repos/<layer>.repos`, `<out>/layers.txt` (the layers written, in order, one per line) and `<out>/optional_layers.txt` (the written layers that are optional; always written, possibly empty), each text file starting with a `#` provenance line. A layer with zero selected repos is in neither file. The zero-repos case is not tied to the option: `resolve` keeps today's warning and exit 0; the adapter rejects an empty `layers.txt` (pull request (b)).
3. Tests (`tools/ros-manifest/tests`): `layers.txt` order and the omission of an empty layer; `optional_layers` parsing, union across `extends`, unknown layer error, optional layer empty for a distro; `--layout manifest-dir` file set; `--layout flat` writes none of the new files; quoted `version:` output for a numeric-looking ref (PyYAML writes `version: '2.0'`; assert what is written so (b)'s reader is tested against it).
4. `Makefile`: target `install-ros-manifest` (in `.PHONY` and `help`), depending on `$(STAMP)/setup-dev.done`, running under `$(LOCKED)` `$(VENV_BIN)/python3 -m pip install --quiet -e $(WS_ROOT)/tools/ros-manifest`, stamped on `tools/ros-manifest/pyproject.toml`; `make setup` includes it. Why a make target and not a line in `requirements.txt` (ADR-0009 tier 1 puts persistent workspace tools there): `Makefile` installs that file with `pip install -r` before it `cd`s to `WS_ROOT` (line 184), so a relative `-e tools/ros-manifest` would resolve against the caller's cwd, and `requirements.txt` is for PyPI tools wired into targets or imported by scripts; this one is a path inside the repository. Recorded in the target's comment and in the README.
5. CI: the job that runs `bash .agent/scripts/tests/test_ros2_colcon.sh` installs the resolver first (`pip install -e tools/ros-manifest`), so (b)'s real-resolver tests run there; the existing `validate-ros-manifest` job is unchanged.
6. `tools/ros-manifest/README.md`: replace the "Not built yet / adapter wiring is a follow-up" text, document `--layout`, `optional_layers`, the cache note, the install target.
7. Repo-wide search for stale references to the old README text and the resolver output description (`rg -n -j 1`).

### Pull request (b): settings keys, adapter route, tests, design

Settings (decision 1 below): three new keys in `.agent/projects.d/<name>`; role and distro stay on the registry line, confirmed by the review (issue 267 records "registry/instance names a role and a distro"; `role=` and `distro=` are trailing fields, `_project_registry.sh` header, and the dispatcher reads them at `adapter:245-255`).

| Where | Key | Meaning | Rule |
|---|---|---|---|
| settings file | `manifest` | Where the manifest lives | an absolute path to a manifest file, or an `http(s)://` / `file://` git URL of a repository that holds it |
| settings file | `manifest_ref` | Branch, tag or commit | required with a URL; refused with a path; refused when `manifest` is unset |
| settings file | `manifest_path` | Path of the manifest inside the repository | default `manifest.yaml`; relative, no `..`, no leading `/`; refused with a path; refused when `manifest` is unset |
| registry line | `role=` | `ros-manifest resolve --role` | required on the manifest route |
| registry line | `distro=` | `--distro`, and `_rc_distro` | required on the manifest route; the legacy `ROS_DISTRO` fallback in `_rc_distro` is not accepted on this route (one source; resolve needs it before any other config) |

Steps, each a commit:

1. **Settings keys.** `_project_registry.sh`: `_PROJECT_FILE_KEYS` (:629), `_project_file_value_error` cases (shape of each value), and the cross-key rules in `project_file_entries` (:1007), the whole-file validator: `manifest_ref`/`manifest_path` need `manifest`, URL needs `manifest_ref`, path form refuses both, `manifest` with `bootstrap_url` refused; header grammar and key list; the "Today ros2_colcon lists build and test" sentence. Dispatcher `adapter`: export `ACTIVE_PROJECT_MANIFEST`, `_MANIFEST_REF`, `_MANIFEST_PATH` beside `ACTIVE_PROJECT_BOOTSTRAP_URL` (:277-298). `single_project/unused_settings` lists the three keys with the reason. `register_project.sh`: type detection (:625) treats `manifest` like `bootstrap_url`; `--set` picks the keys up from `_PROJECT_FILE_KEYS` (:602); `registration.conf` comment on `setup=when-missing`. Tests in `test_project_file.sh`, `test_project_registry.sh`, `test_register_project.sh`.
2. **Route, directory, resolver call** in `.agent/project_types/ros2_colcon/adapter.sh`.
   - `_rc_manifest_route` is `manifest` when `ACTIVE_PROJECT_MANIFEST` is set, else `bootstrap`. On `manifest`, any other bootstrap source that resolves is a hard error naming it: `BOOTSTRAP_URL` in the environment, `bootstrap_url` in the settings file (already refused by step 1), `MANIFEST_BOOTSTRAP_URL` in the legacy `projects.d/<name>.sh` (the existing instances on this machine have one), `configs/project_bootstrap.url` (the four sources of `_rc_bootstrap_url`, adapter.sh:260). The message says to remove it, or to unset `manifest`. The bootstrap route's "no bootstrap URL" error (adapter.sh `_rc_bootstrap_manifest`) gains a line naming `manifest=<url-or-path>`. A `configs/manifest` link left from an earlier bootstrap is ignored on the manifest route.
   - `_rc_manifest_dir` returns `$(_rc_root)/configs/manifest-resolved` on the manifest route (a symlink to the current generated directory, see below), else `configs/manifest`. Every other verb keeps reading `layers.txt`, `optional_layers.txt`, `repos/<layer>.repos` from `_rc_manifest_dir`, so `env`, `build`, `test`, `repos`, `worktree_repos`, `worktree_env` are unchanged (ADR-0012's directory contract). `_rc_require_manifest`'s failure text on this route names `adapter --project <name> setup` instead of the ros2_agent_workspace shape.
   - `_rc_resolver_bin`: `<main checkout>/.venv/bin/ros-manifest`, main checkout = `git rev-parse --path-format=absolute --git-common-dir` of `$WORKSPACE_ROOT` without `/.git`, falling back to `$WORKSPACE_ROOT` (same idea as the Makefile's `WS_ROOT`; a worktree has no venv). Absent: `ERROR: the manifest resolver is not installed at <path>; run: make install-ros-manifest (from the workspace main checkout)`. No `PATH` lookup, no pip. If the resolver exits 2 with `unrecognized arguments: --layout`, the message says the installed resolver predates this adapter and to rerun the make target from a main checkout that has pull request (a).
   - `_rc_manifest_fetch`: the leaf table above. `_rc_manifest_resolve`: requires `ACTIVE_PROJECT_ROLE` and `ACTIVE_PROJECT_DISTRO`, each failure naming the registry line: `edit the line for '<name>' in .agent/projects.local to add role=<name> (register_project.sh does not change an existing line), then run: adapter --project <name> sync`; runs `"$bin" resolve --manifest <file> --role <role> --distro <distro> --out <tmp> --layout manifest-dir --cache-dir <tmp>.cache` into a new temporary directory under `configs/`; rejects an empty `layers.txt` (message: role/distro selected no repositories); writes `<tmp>/.resolved-from` (route, manifest location, source commit for a clone, `manifest-state`, role, distro, path-form mtime and size); swaps by symlink: the generated directory is `configs/manifest-resolved.<timestamp>/`, `ln -s` to a temporary link and `mv -T` over `configs/manifest-resolved` (`rename(2)` cannot replace a non-empty directory), then the previous directory is removed. A failed resolve leaves the previous directory and link. The resolver's stderr is passed through.
   - The three directories (`manifest-resolved*`, `manifest-src`) sit in `<root>/configs/`. Here the hosting root is under the ignored `projects/`; a hosting root that is its own git checkout would show them untracked. The adapter does not edit the project's ignore files (light touch on projects); setup prints one line saying so, and `onboard-project` is the place to offer an ignore line. Listed for veto (decision 4).
3. **Verbs.** `adapter_setup`: when the route is `manifest`, check `vcs` first, before any fetch or resolve (message: `'vcs' not found; install vcstool (Ubuntu: sudo apt install python3-vcstool; vcs2l is the maintained fork, choice pending in issue 267), then rerun setup`; the package name is to be verified by the implementer on a clean machine), then fetch, resolve, then the existing `_rc_require_manifest` and `vcs import --skip-existing` loop unchanged. The bootstrap route's body is untouched. `adapter_sync`: on the manifest route, fetch and resolve before the existing loop. `adapter_validate`: on the manifest route also fails when the link is missing (`run: adapter setup`) or `.resolved-from` disagrees with the current manifest, role or distro (`run: adapter sync`; for a role change: edit the registry line, then sync), warns for `manifest-state=local`, and warns for every checkout under `layers/main/*_ws/src/` that is not in the generated `.repos` (`vcs import --skip-existing` never removes checkouts and colcon still builds them after a role change; the warning names them, the adapter removes nothing). `_rc_repos_entries` (adapter.sh:215) strips surrounding single or double quotes from `version`, so a numeric-looking ref (`'2.0'`) compares correctly in `sync`'s branch comparison as well as in (c); tested.
4. **Package worktrees.** A package worktree's `env.sh` is written once at create time (adapter.sh:826 comment; `worktree_create.sh:759`), so after a `sync` that changes the layers or the role it is stale. Not fixed here; `sync` prints, on the manifest route when `layers.txt` changed, `existing package worktrees keep their old env.sh; recreate them`. Stated in the design bullet.
5. **Network needs, stated in the design bullet and the adapter header:** PyPI (PyYAML and setuptools, at `make install-ros-manifest`), the manifest host, every `extends` host, every package host. No network once everything is fetched, except `sync`.
6. **Synthetic tests** (`test_ros2_colcon.sh`, section "manifest route"). Sandbox fixtures: three invented repositories in two layers as bare `file://` remotes (a branch, a tag, a commit), a manifest with `optional_layers`, one per-distro override, one repository absent for a distro, two roles, a base manifest in its own bare remote; the resolver is `<sandbox>/.venv/bin/ros-manifest`, a wrapper running the real `ros_manifest.cli` under the repository venv python when PyYAML imports (else those tests print `SKIPPED: PyYAML not importable` and are counted as skipped; CI installs the resolver so they run there), and a stub for failure cases. No network, no real project. Cases: the stale-manifest tests above; setup from a path manifest and from a URL manifest at branch, tag and commit; validate passes, fails with the link missing, fails after a role or distro change (message names the registry line); a role change removes a repo from the generated `.repos` and validate warns about its checkout; per-distro override and absent repository honoured; optional layer failure tolerated, required layer failure aborts; resolver failure keeps the previous directory; resolver absent gives the one message naming the make target; a stale resolver (stub exiting 2 on `--layout`) gives the reinstall message; missing `vcs` is reported before any fetch (the remote is never contacted); missing `role=`, missing `distro=` each name their field and the edit-and-sync instruction; `manifest` with each other bootstrap source refused; `env`, `build`, `test`, `repos`, `worktree_repos` on a manifest-route project read the generated directory; quoted numeric ref; the entire existing suite unchanged is the proof the bootstrap route is untouched. Add `tools/ros-manifest/` to the file-to-suite map in `suites_for_files.sh` if the adapter suite is not already reached from there.
7. **Documents.** `docs/design.md` "Registry and adapters": settings-file bullet (keys), a manifest-route bullet in Now (route, generated directory, resolver by venv path, the stale-manifest rule, network needs, package-worktree `env.sh`), wording that says the adapter reads `configs/manifest` corrected, a change-log row with the section's new line count (the section is past the 60-line prompt: the new bullet is short and points at the adapter header). `.agent/knowledge/script_reference.md`: the `project_setting.sh` row (three keys), the Makefile target. `_project_registry.sh` header. Pull request (c) owns the verb text.
8. **Final search for stale references, repo-wide** (`rg -n -j 1` over the whole repository): `bootstrap_url`, `bootstrap.yaml`, `Not built yet`, `adapter wiring`, `unused_settings`, `layers.txt`, `ros-manifest`, `manifest-resolved`.

### Pull request (c): `repo_pin` (outline)

A required verb, the 13th, in `REQUIRED_VERBS` (`adapter:68`), implemented by every type; `validate_adapter.sh` then asserts it for every type (ADR-0011 rule unchanged). ADR-0011 is amended in the same pull request as ADR-0012 amended it (its Status paragraph: 12 to 13 verbs; its verb table gains the row; ADR-0012 pattern checked at `docs/decisions/0011-...md` Status); `docs/design.md` verb text and change log, the `adapter` header verb list and usage, `script_reference.md`.
- Contract: `adapter repo_pin <repo>` prints one line `<ref><TAB><kind>` and exits 0, or exits 1 with an error. `<repo>` is the repository's name as `adapter repos` prints it before the colon.
- `ros2_colcon` (both routes): `<ref>` is the `version:` of that repository in the `.repos` files of `_rc_manifest_dir` (via `_rc_repos_entries`, quotes stripped). `<kind>`: when online, `git ls-remote --heads origin <ref>` decides `branch`, `--tags` decides `tag`, a 40 or 64 hex string is `commit`; git is the authority and nothing about the kind is added to the manifest (an extra field per repository would drift). Offline or not checked out: local fallback (`refs/remotes/origin/<ref>`, `refs/tags/<ref>`), and `unknown` when neither exists. Branch is tried before tag, since a same-named tag does not stop a `--base`. A repository not in the files: exit 1 `no repository '<repo>' in the manifest (known: ...)`.
- `single_project`: one repository; `<repo>` must be the name `adapter_repos` prints (the root's basename); prints the repository's default branch from `git symbolic-ref --short refs/remotes/origin/HEAD` (prefix `origin/` removed; `git ls-remote --symref origin HEAD` when that ref is absent) with kind `branch`; exit 1 when undetermined or a different name.
- Issue 429's use: kind `branch` is the base for a package pull request; any other kind is the caller's decision (never pass a tag or a commit as `--base`).
- Tests: both types, all four kinds, offline fallback, a branch deleted upstream (local remote ref left behind: ls-remote says it is gone, so not `branch`), the quoted-ref case, the not-found error, `validate_adapter.sh` on a type missing the verb.

### Pull request (d): the records (outline)

- `docs/roadmap.md` Direction table: one Line in the owner's words, "I want the new manifest to be used for the pickerel test." (2026-11-10), as `| The Rolling instance is registered and fetched from a manifest in the new format on the second machine, and `adapter validate` passes (#436) | `gh-issue 436 closed` |` (valid in `sitrep_checks.sh`: kind `gh-issue`, `<N> <open|closed>`). Listed for the owner's veto with the quote.
- "Manifest support (step 4)" row (roadmap.md:203) and step 4 row (:180): done (resolver, p11 acceptance fixture, adapter route and `repo_pin` once merged); left (the manifest in the project's own repository, the second-machine run, the tool's name and repository, vcs2l versus vcstool); drop "dual prototype ... decides the tool" and "west variant ... next milestone".
- "Decided Against" rows: the west-based variant (2026-11-10, "Q4, decide against"; reason from `west-variant.md`: no per-distro refs, no layers, no `.repos` output, so this workspace's format, pre-processing and a converter are needed either way; revisit only if maintaining the resolver's composition code becomes a burden); and the six lines proposed in `docs/fork_parity.md` ("Proposed Decided Against lines", on main; the owner chose on 2026-11-10 to record them): container dispatch, agent image, `.devcontainer/` and the container `ci_local.sh` attestation (ADR-0014, ADR-0015; the CI part to be confirmed, as the file says); the fork's web dashboard; the local Ollama adversarial reviewer; the `agent launch` tmux launcher; the `post-checkout` layer symlink hook and the `scripts` symlink; the `.agent/.identity` file. Each row carries the reason text from the file. This worktree is behind main and lacks `docs/fork_parity.md`; (d) starts from an up-to-date branch.
- `tools/ros-manifest/docs/west-variant.md`: the "Status: specification only ... next milestone" paragraph becomes a decided-against status and date, body kept as the record; README pointers.
- Check: `check_design_anchors.sh`, `validate_workspace.py`, `test_sitrep_checks.sh` against the new row.

### Pull request (e): manifest text and drafted issue (outline; records only; provisional)

- `.agent/work-plans/issue-436/records/manifest-rolling.yaml` (the fixture `tools/ros-manifest/tests/fixtures/p11/manifest.yaml` as base, `rolling` per-distro ref for the core repository, the `site` layer in `optional_layers`, one role `dev` with no `roots`, which is the groups model in effect) and `manifest-issue-draft.md` (written per the outward-writes rule: says what agent_workspace is, links it, says use is optional). Both are marked **provisional**: the role model (issue 267 decision 4, groups or dependency closure) is with the owner. Nothing is opened or written in any project repository.
- An offline equivalence check recorded in the draft: resolve the manifest for the Rolling pair into a temporary directory and compare repository names and refs with the hosted Rolling instance's `.repos` files, read in place; differences listed.
- The second-machine run is issue 433's.

## Files to Change

| File | Change | PR |
|------|--------|----|
| `tools/ros-manifest/src/ros_manifest/{schema,merge,emit,cli}.py`, `tests/*`, `README.md` | `optional_layers`, `--layout`, tests, README | a |
| `Makefile`, `.github/workflows/*` | `install-ros-manifest`; CI installs the resolver before the adapter tests | a |
| `.agent/scripts/_project_registry.sh`, `adapter`, `register_project.sh` | keys `manifest`, `manifest_ref`, `manifest_path`; cross-key rules; exports; type detection | b |
| `.agent/project_types/single_project/unused_settings`, `ros2_colcon/registration.conf` | refuse the keys for `single_project`; comment | b |
| `.agent/project_types/ros2_colcon/adapter.sh` | manifest route, leaf refresh, resolve and swap, validate checks, quote stripping | b |
| `.agent/scripts/tests/test_ros2_colcon.sh`, `test_project_file.sh`, `test_project_registry.sh`, `test_register_project.sh`, `suites_for_files.sh` | tests and suite mapping | b |
| `docs/design.md`, `.agent/knowledge/script_reference.md` | design section, change log, script reference | b |
| `.agent/scripts/adapter`, `validate_adapter.sh`, both adapters, `docs/decisions/0011-*.md`, `docs/design.md`, `script_reference.md`, tests | `repo_pin` required verb, ADR-0011 amended | c |
| `docs/roadmap.md`, `tools/ros-manifest/docs/west-variant.md` | records | d |
| `.agent/work-plans/issue-436/records/*` | manifest text and drafted issue, provisional | e |

## Prior Art

- The bootstrap route (`_rc_bootstrap_manifest`, `_rc_bootstrap_url`) is the model for URL handling, the origin-mismatch refusal and "report and reuse" for a clone with local work; nothing in it changes.
- `extends` in `schema.py` (`path`, `url`, `ref`) is the model for how the adapter locates a manifest, so one vocabulary covers both.
- The Makefile's `WS_ROOT` and `cross_model_review.sh` (`${...%/.git}/.venv/bin/python3`) are the prior art for finding the main checkout's venv from a worktree.
- ADR-0012's amendment of ADR-0011 (10 to 12 verbs) is the model for amending it again (c).
- west and vcs2l were considered and set aside by the owner (west: decided against; vcs2l: independent, still pending, `vcs` stays the fetch command).
- Nothing new is built beyond the small resolver additions and the adapter route.

## Serves

Workspace goal "Modular" (README, Workspace goals: knowledge about a kind of project, like ROS, added as modules without changing the rest), under `docs/design.md#registry-and-adapters`; the roadmap Direction acceptance case (project11 on a second machine against ROS 2 Rolling).

## Design Picture

Alters `docs/design.md#registry-and-adapters`: the `ros2_colcon` adapter gains a second manifest route, the settings file gains three keys, and the resolver becomes a workspace-installed tool called by CLI (updated in (b), with its change-log row); the contract gains a 13th required verb (updated in (c), ADR-0011 amended). (d) changes `docs/roadmap.md` only.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Design section and change log move with the code in (b) and (c); ADR-0011 is amended in (c), not left stating 12. Decisions 3, 4 and 7 of issue 267 are quoted, not re-decided. |
| Test what breaks | Every staleness case is tested by pushing to a bare remote and syncing, not by editing the clone. |
| Ask about what matters | Only the role model reaches the owner, and the plan does not depend on it. Mechanism choices are listed for veto below. |
| Only what's needed | `optional_layers` and the layout because `setup` and `validate` read them; no vcs2l, no rename, no role-model work. The resolver's extends cache is not changed. |
| Put each thing at the level it applies to | The resolver stays self-contained and extractable (no workspace imports); the project's manifest and issue are drafted here and opened nowhere (ADR-0016). |
| Workspace is project-agnostic | Adapter, resolver and tests name no project; the p11 fixture stays inside `tools/ros-manifest/tests`; names appear only in the records of (d) and (e). |
| Verify before claiming | Every route is exercised by sandbox tests; the second-machine run stays the owner's (433). Claims cite file and function. |
| Light touch on projects / nothing required | No key is required; a project with none behaves as today; the adapter edits no project ignore file; a dirty manifest clone is never forced. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 project-agnostic | Yes | Synthetic fixtures only. |
| 0009 Python package management | Yes | Resolver in the workspace `.venv` from a make target, no bare pip; why not `requirements.txt` stated in (a). |
| 0011 adapter contract | Yes | (c) amends it: 13 required verbs, every type implements every verb. |
| 0012 worktree composition | Yes | `worktree_repos` and `worktree_env` untouched; same directory contract; stale `env.sh` after `sync` stated. |
| 0013 progress timeline | Yes | This entry; later phases append. |
| 0016 session roots | Yes | Project manifest and issue are records here only. |
| 0017 design is current | Yes | `docs/design.md` updated in (b) and (c). |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `_PROJECT_FILE_KEYS` | header, `_project_file_value_error`, `project_file_entries` cross-key rules, dispatcher exports, `unused_settings`, `register_project.sh`, tests, script reference | Yes (b step 1) |
| Resolver output | tests, README, p11 acceptance test (flat default unchanged) | Yes (a) |
| `REQUIRED_VERBS` | `validate_adapter.sh`, both adapters, ADR-0011 Status and table, design verb text, `adapter` header | Yes (c) |
| Makefile | `.PHONY`, help, CI, README | Yes (a) |
| `_rc_repos_entries` quote stripping | `sync`'s branch comparison, `validate`, `repo_pin` | Yes (b step 3), tested |
| Layers change at `sync` | existing package worktrees' `env.sh` | Stated and printed, not fixed (b step 4) |
| Roadmap rows | Direction check grammar, `check_design_anchors.sh` | Yes (d) |
| Issue 429's base-branch use | `repo_pin` output contract | Out of scope; contract stated in (c) |

## Open Questions

- For the owner (asked by the host, does not block this plan): the role model, groups or dependency closure. A role is a name passed to `--role`; an unknown name is the resolver's error. (e) is marked provisional on it.
- Nothing else needs him; see Decisions for the owner's veto.

## Decisions for the owner's veto

1. **Role and distro stay on the registry line; only the manifest location goes in the settings file.** (Confirmed by the plan review.) The adapter's messages say how to change a role: edit the line in `.agent/projects.local`, then `adapter sync`. Undo cost: small.
2. **The route is implied by `manifest` being set; any other bootstrap source resolving alongside it is a hard error.** Undo: small.
3. **The adapter, not the resolver, clones a git-hosted leaf manifest** (the resolver's leaf is a local file) and follows the table in "a stale manifest": fast-forward only when clean and on the branch, never forcing a dirty clone, with a warning. Undo: moderate.
4. **The generated and cloned directories sit in `<root>/configs/` and the adapter does not edit the project's ignore files**; `setup` prints a one-line note. Undo: small.
5. **Every `sync` clones every `extends` base afresh** (cache inside the temporary directory) instead of changing the resolver's cache; `extends` stays branch-or-tag only while the leaf may be a commit. Undo: small (a resolver refresh later).
6. **A layer with no repository for the role and distro is left out of `layers.txt`**; an empty result is rejected by the adapter. Undo: small.
7. **`optional_layers` is a top-level manifest key** (a list, union across `extends`). Undo: moderate once a manifest uses it.
8. **The resolver output is a named layout, `--layout manifest-dir`**, default `flat` unchanged. Undo: small.
9. **`repo_pin <repo>` is a required verb in its own pull request (c)**, printing `<ref><TAB><kind>`; `single_project` answers with the repository's default branch and kind `branch`; kind comes from git (`ls-remote` online, local refs offline), never from the manifest. ADR-0011 is amended to 13 verbs. Undo: moderate (verb removal needs another amendment).
10. **Five pull requests**, (a) and (d) first and in parallel. Undo: none; it only changes review size.
11. **The Direction line's check is `gh-issue 436 closed`**, because the real proof is issue 433's and cannot be checked from this repository. Undo: trivial.
12. **`make` target rather than a `requirements.txt` line** for the resolver install (reason in (a) step 4). Undo: small.

## Estimated Scope

Five pull requests: (a) small to medium, (b) large, (c) medium, (d) and (e) documentation and records.
