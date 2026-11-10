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

Three pull requests on this one issue. Pull request 1 is in implementable detail; 2 and 3 are in outline.

### Pull request 1: the adapter route (workspace)

Vocabulary: **bootstrap route** = today's `bootstrap.yaml` flow, unchanged. **Manifest route** = the new one. The route is chosen by one fact: the project's settings file sets `manifest`. A project that sets none of the new keys runs the bootstrap route exactly as today.

Settings (decision 1 below): three new keys in `.agent/projects.d/<name>`, role and distro stay on the registry line where they already are.

| Where | Key | Meaning | Rule |
|---|---|---|---|
| settings file | `manifest` | Where the manifest lives | an absolute path to a manifest file, or an `http(s)://` / `file://` git URL of a repository that holds it |
| settings file | `manifest_ref` | Branch, tag or commit of that repository | required with a URL, refused with a path |
| settings file | `manifest_path` | Path of the manifest inside the repository | default `manifest.yaml`; refused with a path; relative, no `..`, no leading `/` |
| registry line | `role=` | Passed to `ros-manifest resolve --role` | required on the manifest route |
| registry line | `distro=` | Passed to `--distro` and used by `_rc_distro` | required on the manifest route (already `[a-z0-9_]+`) |

The mirrored shape is `extends` in the schema (`path`, `url`, `ref`), so a manifest is located the same way inside and outside. `manifest` together with `bootstrap_url` is an error (one source of truth; checked in the adapter and in `project_setting.sh check`).

Steps, in order, each a commit:

1. **Resolver emits the adapter's files** (inside `tools/ros-manifest/`, no workspace imports; its README and `pyproject.toml` stay self-contained).
   - `schema.py`: new top-level key `optional_layers` (list of strings, each must be in the same manifest's `layers`; add to `_TOP_LEVEL_KEYS`). `merge.py`: the composed `MergedManifest` gets `optional_layers`, the union over the chain in chain order; a name not in the merged layers is a `ManifestError`.
   - `emit.py`: `emit_manifest` also writes `layers.txt` (the layers that were written, in order, one per line) and `optional_layers.txt` (the written layers that are optional; the file is always written, possibly empty). A layer with zero selected repos for the pair is in neither (it is not a build unit for that role and distro; the adapter's "missing repos file" error therefore cannot fire on an empty layer). Both files start with a `#` provenance line. New option `--repos-subdir <name>` (default none, so existing flat output and tests are unchanged) places the `.repos` files in `<out>/<name>/`; the adapter passes `repos`.
   - `cli.py`: `--repos-subdir` on `resolve`; `resolve` exits 1 with the existing message when the result has no layer at all (today it only warns on zero repos; the adapter must not get an empty `layers.txt` silently, so make it an error under the new option only: exit 1 `role/distro selected zero repos`).
   - Tests (`tools/ros-manifest/tests`): `layers.txt` order and omission of an empty layer; `optional_layers` parsing, union across `extends`, unknown-layer error; `--repos-subdir`; flat output unchanged without it; the p11 acceptance test still byte-equal modulo header.
2. **Install the resolver** (ADR-0009 tier 1). `Makefile`: target `install-ros-manifest`, depending on `$(STAMP)/setup-dev.done`, running under `$(LOCKED)` `$(VENV_BIN)/python3 -m pip install --quiet -e $(WS_ROOT)/tools/ros-manifest`, with a stamp that depends on `tools/ros-manifest/pyproject.toml`; `make setup` includes it. Add the target to `.PHONY` and `help`. CI: the adapter-test job installs the resolver with `pip install -e tools/ros-manifest` before `bash .agent/scripts/tests/test_ros2_colcon.sh` (`.github/workflows`, job beside "Run ros2_colcon adapter tests"). `tools/ros-manifest/README.md`: replace "adapter wiring is a follow-up", state the make target.
3. **Settings keys**: `_project_registry.sh` (`_PROJECT_FILE_KEYS`, `_project_file_value_error` cases for the three keys including the cross-field rules that can be seen from one file: ref with URL only, path with URL only, `manifest` with `bootstrap_url`; header grammar and the keys list; the "Today ros2_colcon lists build and test" sentence); dispatcher `adapter` exports `ACTIVE_PROJECT_MANIFEST`, `_MANIFEST_REF`, `_MANIFEST_PATH` beside `ACTIVE_PROJECT_BOOTSTRAP_URL` (:277-298); `single_project/unused_settings` lists the three keys with the reason (`validate_adapter.sh` checks the entries); `register_project.sh` type detection at :625 treats `manifest` like `bootstrap_url`, and its `--set` loop picks the keys up from `_PROJECT_FILE_KEYS` (:602); `registration.conf` comment on `setup=when-missing` names the manifest. A registry line `role=` or `distro=` missing on the manifest route is reported by the adapter (step 4), not by the registry, because the registry does not know the type's route.
4. **Adapter manifest route** (`.agent/project_types/ros2_colcon/adapter.sh`).
   - `_rc_manifest_route` returns `manifest` when `ACTIVE_PROJECT_MANIFEST` is non-empty, else `bootstrap`.
   - `_rc_manifest_dir`: on the manifest route returns `$(_rc_root)/configs/manifest-resolved`, a generated directory (safe to delete; `sync` rebuilds it), else `configs/manifest` as today. Every other verb keeps reading `layers.txt`, `optional_layers.txt` and `repos/<layer>.repos` from `_rc_manifest_dir`, so `env`, `build`, `test`, `repos`, `worktree_repos`, `worktree_env` need no change (ADR-0012 stays an adapter concern with the same directory contract).
   - `_rc_resolver_bin`: `<main checkout>/.venv/bin/ros-manifest`, where the main checkout is `git rev-parse --path-format=absolute --git-common-dir` of `$WORKSPACE_ROOT` with `/.git` removed, falling back to `$WORKSPACE_ROOT` (same idea as the Makefile's WS_ROOT; a worktree has no venv). Absent or not executable: one message, `ERROR: the manifest resolver is not installed at <path>; run: make install-ros-manifest (from the workspace main checkout)`, exit 1. Nothing else is tried (no `PATH` lookup, no `pip`).
   - `_rc_manifest_fetch` (setup and sync only): a path is used in place; a URL is cloned into `configs/manifest-src/` at `manifest_ref` on first use and, when present, `git fetch` plus checkout of the ref on later runs (a clone whose `origin` differs from `manifest` is refused, as `_rc_bootstrap_manifest` refuses a mismatch). Ref can be a branch, tag or commit.
   - `_rc_manifest_resolve`: requires `role` (`ACTIVE_PROJECT_ROLE`) and the distro (`_rc_distro`), each with an error naming the registry field; runs `"$bin" resolve --manifest <file> --role <role> --distro <distro> --out <tmp> --repos-subdir repos --cache-dir <root>/configs/manifest-cache`, into a temporary sibling directory, writes `<tmp>/.resolved-from` (route, manifest location, manifest source commit when it is a clone, role, distro), then replaces `configs/manifest-resolved` by rename. A failed resolve leaves the previous generated directory untouched. The resolver's own stderr is passed through.
   - `adapter_setup`: when the route is `manifest`, call fetch, then resolve, in place of `_rc_bootstrap_manifest`; then the existing `_rc_require_manifest` and the existing `vcs import --skip-existing` loop run unchanged. The route is `bootstrap` otherwise and the function body is untouched.
   - `adapter_sync`: on the manifest route, fetch and resolve before the existing loop, so a manifest change reaches the checkouts; the loop is unchanged.
   - `adapter_validate`: on the manifest route, additionally fail when `configs/manifest-resolved` is missing (message names `adapter setup`) or when `.resolved-from` disagrees with the current `manifest`, role or distro settings (message names `adapter sync`); the rest is unchanged.
   - `_rc_distro`: unchanged (registry distro first; no `bootstrap.yaml` exists in the generated directory). Header comment of the adapter gains a "Manifest route" paragraph.
5. **`repo_pin` verb.** `adapter repo_pin <repo>` prints one line, `<ref><TAB><kind>`, for the repository named `<repo>` (its key under `repositories:` in the generated `.repos`, as `adapter repos` prints before the colon), read with the existing `_rc_repos_entries` (adapter.sh:215) from `_rc_manifest_dir`, so it works on both routes. `<ref>` is the `version:` value, whatever it is. `<kind>` says what the ref is, decided locally with no network: `commit` when `<ref>` is a 40 or 64 hex string; `branch` when the repository is checked out and `refs/remotes/origin/<ref>` exists; `tag` when `refs/tags/<ref>` exists; `unknown` when the repository is not checked out or neither ref exists. Issue 429's base-branch use is therefore: kind `branch` means use the ref; any other kind means the caller decides (it must not pass a tag or a commit as `--base`). Exit 1 with `ERROR: no repository '<repo>' in the manifest (known: ...)` when absent. Dispatcher: new `OPTIONAL_VERBS=(repo_pin)` beside `REQUIRED_VERBS`; the unknown-verb check accepts either; a type that does not implement an optional verb gets the existing "does not implement verb" error (:345); `validate_adapter.sh` checks that an optional verb, when defined, is a function and silent; ADR-0011 stays at 12 required verbs. `single_project` does not implement it.
6. **Synthetic tests** (`test_ros2_colcon.sh`, a new section "manifest route"). Fixtures are built in the sandbox: three invented repositories in two layers made as bare `file://` remotes (`git init --bare`, one commit, a branch, a tag), a manifest with an `optional_layers` entry, one per-distro override, one repository absent for one distro, two roles; the resolver is `<sandbox>/.venv/bin/ros-manifest`, a wrapper that runs the real `ros_manifest.cli` under the repo's python when PyYAML imports (else the real-resolver tests print `SKIPPED` with the reason, and CI installs the resolver so they run there), and a stub for the failure cases. No network, no real project. Cases: setup from a local-path manifest imports each layer from the right `.repos`; setup from a git-URL manifest (bare remote) at a branch, a tag and a commit; sync after a manifest edit changes the generated `.repos` and the imports; validate passes, fails when the generated directory is missing, fails when role or distro changed; per-distro override and absent repository honoured; optional layer failure tolerated, required layer failure aborts; a resolver failure leaves the earlier generated directory; resolver absent gives the one message naming `make install-ros-manifest`; missing `role=` and missing `distro=` each name their field; `manifest` with `bootstrap_url` refused; a project that sets no new key runs all existing tests unchanged (the whole existing suite is the proof) and `adapter env/build/test/repos/worktree_repos` on a manifest-route project work from the generated directory; `repo_pin` prints branch, tag, commit and unknown cases, and the not-found error. Settings tests in `test_project_file.sh` / `test_project_registry.sh` (the three keys, the cross-field rules, `single_project` refusal) and `test_register_project.sh` (type detection). Add `ros-manifest` sources to the file-to-suite map in `suites_for_files.sh` if the adapter suite is not already reached from `tools/ros-manifest/` changes.
7. **Documents.** `docs/design.md` "Registry and adapters": the settings-file bullet (keys), a manifest-route bullet in Now (what is built: route, generated directory, resolver by venv path, `repo_pin`), the Target/inventory wording that says "the adapter reads configs/manifest" corrected, and a change-log row with the section's new line count (the section is already past the 60-line prompt; the new bullet is short and points at the adapter header, which holds the detail). `.agent/knowledge/script_reference.md`: the `project_setting.sh` row (three keys), an `adapter` row for `repo_pin`, the Makefile target, the resolver row if one exists. `_project_registry.sh` header (the project settings documentation). `tools/ros-manifest/README.md`. ADR-0011 is not changed (12 required verbs); design.md's verb text gains one sentence on optional verbs.
8. **Final search for stale references, repo-wide**: `rg -n -j 1` for `bootstrap_url`, `bootstrap.yaml`, `Not built yet`, `adapter wiring`, `follow-up milestones`, `REQUIRED_VERBS`, `unused_settings`, `layers.txt`, `ros-manifest` over the whole repository (not just the files above), and fix every statement the change made false.

### Pull request 2: the records (outline; can run alongside 1)

- `docs/roadmap.md` Direction table: one Line in the owner's words, "I want the new manifest to be used for the pickerel test." (2026-11-10), as: `| The Rolling instance is registered and fetched from a manifest in the new format on the second machine, and `adapter validate` passes (#436) | `gh-issue 436 closed` |` (valid in `sitrep_checks.sh`: kind `gh-issue`, `<N> <open|closed>`, no bare number). Listed for the owner's veto with the quote.
- "Manifest support (step 4)" row (roadmap.md:203) and step 4 row (:180): say what is done (resolver, p11 acceptance fixture, adapter route and `repo_pin` once pull request 1 merges) and what is left (the manifest in the project's own repository, the second-machine run, the tool's name and repository, vcs2l versus vcstool); drop "dual prototype ... decides the tool" and "west variant ... next milestone".
- "Decided Against" row: west-based variant, 2026-11-10, the owner's words ("Q4, decide against"), reason from `west-variant.md` (no per-distro refs, no layers, does not write `.repos`, so this workspace's format, pre-processing and a converter are needed either way), revisit only if maintaining the resolver's composition code becomes a burden.
- `tools/ros-manifest/docs/west-variant.md`: replace the "Status: specification only ... next milestone" paragraph with a decided-against status and date; keep the body as the record. Also the README's pointers to it.
- Check: `check_design_anchors.sh`, `validate_workspace.py` Direction checks, `test_sitrep_checks.sh` against the new row.

### Pull request 3: manifest text and drafted issue (outline; records only)

- `.agent/work-plans/issue-436/records/` gets `manifest-rolling.yaml` (the manifest for the Rolling branch of the project's manifest repository: the fixture `tools/ros-manifest/tests/fixtures/p11/manifest.yaml` as base, `rolling` per-distro ref for the core repository, the optional `site` layer marked in `optional_layers`, one role) and `manifest-issue-draft.md` (the issue for that repository, written per the outward-writes rule: says what agent_workspace is, links it, says use is optional). Nothing is opened or written in any project repository.
- Verified by a local, offline equivalence check recorded in the draft: resolve the manifest for the Rolling pair into a temporary directory and compare repository names and refs with the hosted Rolling instance's `.repos` files read in place (read-only); differences listed.
- The second-machine run (register, setup, validate on a clean machine) is issue 433's.

## Files to Change

| File | Change |
|------|--------|
| `tools/ros-manifest/src/ros_manifest/{schema,merge,emit,cli}.py` | `optional_layers`, `layers.txt`, `optional_layers.txt`, `--repos-subdir` |
| `tools/ros-manifest/tests/*`, `tools/ros-manifest/README.md` | tests for the above; README states the install target |
| `Makefile`, `.github/workflows/*` | `install-ros-manifest` target; CI installs the resolver before the adapter tests |
| `.agent/scripts/_project_registry.sh` | keys `manifest`, `manifest_ref`, `manifest_path`: list, validation, header |
| `.agent/scripts/adapter` | export the keys; `OPTIONAL_VERBS`; accept `repo_pin` |
| `.agent/scripts/validate_adapter.sh` | optional verbs checked when defined |
| `.agent/scripts/register_project.sh` | type detection and `setup` for a `manifest` project |
| `.agent/project_types/single_project/unused_settings`, `ros2_colcon/registration.conf` | refuse the keys for `single_project`; comment |
| `.agent/project_types/ros2_colcon/adapter.sh` | manifest route, `repo_pin`, header |
| `.agent/scripts/tests/test_ros2_colcon.sh`, `test_project_file.sh`, `test_project_registry.sh`, `test_register_project.sh`, `suites_for_files.sh` | tests and suite mapping |
| `docs/design.md`, `.agent/knowledge/script_reference.md` | design section, change log, script reference (pull request 1) |
| `docs/roadmap.md`, `tools/ros-manifest/docs/west-variant.md` | records (pull request 2) |
| `.agent/work-plans/issue-436/records/*` | manifest text and drafted issue (pull request 3) |

## Prior Art

- The bootstrap route (`_rc_bootstrap_manifest`, `_rc_bootstrap_url`) is the model for URL handling, the origin-mismatch refusal and the settings-then-legacy precedence; nothing in it changes.
- `extends` in `schema.py` (`path`, `url`, `ref`) is the model for how the adapter locates a manifest, so one vocabulary covers both.
- The Makefile's `WS_ROOT` and `cross_model_review.sh` (`${…%/.git}/.venv/bin/python3`) are the prior art for finding the main checkout's venv from a worktree.
- west and vcs2l were considered and set aside by the owner (west: decided against; vcs2l: independent, still pending, `vcs` stays the fetch command).
- Nothing new is built beyond the small resolver additions and the adapter route.

## Serves

Workspace goal "Multiple projects" (README, Workspace goals), under `docs/design.md#registry-and-adapters`; the roadmap Direction acceptance case (project11 on a second machine against ROS 2 Rolling).

## Design Picture

Alters `docs/design.md#registry-and-adapters`: the `ros2_colcon` adapter gains a second manifest route, the settings file gains three keys, the contract gains one optional verb, and the resolver becomes a workspace-installed tool called by CLI. Updated in pull request 1 (ADR-0017), with its change-log row. Pull request 2 changes `docs/roadmap.md` only.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | The design section and its change log move with the code in pull request 1; decisions 3, 4 and 7 of issue 267 are quoted, not re-decided. |
| Ask about what matters | Only the role model reaches the owner, and the plan does not depend on it. Mechanism choices are listed for veto below. |
| Only what's needed | One new resolver feature pair (`optional_layers`, `layers.txt`) because `setup`/`validate` read them; no vcs2l, no rename, no role-model work, no closure walking. `repo_pin` is one verb. |
| Put each thing at the level it applies to | The resolver stays self-contained and extractable (no workspace imports); the project's manifest and issue are drafted here and opened nowhere (ADR-0016). |
| Workspace is project-agnostic | Adapter, resolver and tests name no project; the p11 fixture stays inside `tools/ros-manifest/tests`; names appear only in the records of pull requests 2 and 3. |
| Verify before claiming | Every route is exercised by sandbox tests; the second-machine run stays the owner's (433). Claims in this plan cite file and function. |
| Nothing required of a project | No key is required; a project with none behaves as today; the existing suite is the regression proof. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 project-agnostic | Yes | Synthetic fixtures only. |
| 0009 Python package management | Yes | Resolver in the workspace `.venv` from a make target, no bare pip. |
| 0011 adapter contract | Yes | 12 required verbs unchanged; one optional verb added through a separate list. |
| 0012 worktree composition | Yes | `worktree_repos` and `worktree_env` untouched; same directory contract. |
| 0013 progress timeline | Yes | This entry; later phases append. |
| 0016 session roots | Yes | Project manifest and issue are records here only. |
| 0017 design is current | Yes | `docs/design.md` updated in pull request 1. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `_PROJECT_FILE_KEYS` | header, `_project_file_value_error`, dispatcher exports, `unused_settings`, `register_project.sh`, `project_setting.sh` tests, script reference | Yes (PR 1 step 3) |
| Resolver output files | resolver tests, README, p11 acceptance test | Yes (step 1) |
| Dispatcher verb list | `validate_adapter.sh`, ADR-0011 text unaffected, design verb sentence | Yes (step 5) |
| Makefile | `.PHONY`, help, CI, README | Yes (step 2) |
| Adapter header comment | consequences for `docs/design.md` | Yes (step 7) |
| Roadmap rows | Direction check grammar, `check_design_anchors.sh` | Yes (PR 2) |
| Issue 429's base-branch use | `repo_pin` output contract stated above | Out of scope; contract stated |

## Open Questions

- For the owner (asked by the host, does not block this plan): the role model, groups or dependency closure. The plan passes a role name to `--role`.
- Nothing else needs him; see Decisions for the owner's veto.

## Decisions for the owner's veto

1. **Role and distro stay on the registry line; only the manifest location goes in the settings file.** The registry already has `role=` and `distro=` fields, the dispatcher already reads them, and issue 267 says "registry/instance names a role and a distro". Three new settings keys (`manifest`, `manifest_ref`, `manifest_path`) hold the location. Undo cost: small (add two keys to `_PROJECT_FILE_KEYS` and read them ahead of the registry fields; tests move with them).
2. **The route is implied by `manifest` being set, with no separate route key; `manifest` plus `bootstrap_url` is an error.** Undo: small (add a key).
3. **The adapter, not the resolver, clones a git-hosted manifest**, into `configs/manifest-src/`, because the resolver's leaf manifest is a local file (`cli.py`, `--manifest`). Undo: moderate (would be a resolver change plus a cache contract).
4. **The generated directory is `configs/manifest-resolved/`, rebuilt by `setup` and `sync` only and replaced atomically; `validate` checks it against the current role, distro and manifest.** Undo: small.
5. **A layer with no repository for the role and distro is left out of `layers.txt`**, so it cannot raise a missing-file error. Undo: small (resolver emit).
6. **`optional_layers` is a top-level manifest key** (a list, union across `extends`), not a flag on the layer entry, because `layers` is a plain list of names in `schema.py`. Undo: moderate (schema change in the manifest format once a manifest uses it).
7. **`repo_pin <repo>` takes the repository's name as in the `.repos` file and prints `<ref><TAB><kind>`** (`branch`, `tag`, `commit`, `unknown`); it does not take `owner/repo`, because the caller (issue 429) gets names from `adapter repos`. It is an optional verb so the contract stays at 12 required verbs. Undo: small.
8. **`--repos-subdir` on the resolver rather than changing its default layout**, so the existing flat output and the p11 acceptance test stay. Undo: small.
9. **Pull request 1 includes the resolver additions** (steps 1-2) rather than a separate pull request, because the adapter cannot be tested without them. Undo: none needed; it only changes review size.
10. **The Direction line's check is `gh-issue 436 closed`**, because the real proof (a clean second-machine run) is issue 433's and cannot be checked from this repository. Undo: trivial.

## Estimated Scope

Three pull requests. Pull request 1 is large (about 10 files plus tests and docs); pull requests 2 and 3 are documentation and records.
