# Plan: Use the new manifest format for the second-machine test: the ROS adapter calls the manifest resolver

## Issue

https://github.com/rolker/agent_workspace/issues/436

## Context

The owner, 2026-11-10: "I want the new manifest to be used for the pickerel test."; on the resolver, "Built in for Q2"; on the west variant, "Q4, decide against". On 2026-11-13 he said "yes, start 436 and adopt the type neutral names" (issue comment of that date): the settings keys planned as `manifest`, `manifest_ref`, `manifest_path` are built as `source`, `source_ref`, `source_path`, same meaning and rules; renaming `bootstrap_url` and the registry field `distro` is left to issue 473; `role=` and `distro=` stay on the registry line. He tests on the second machine himself (a manifest in the new format, Rolling first, Lyrical as the follow-up; `make setup` is done there and `.venv/bin/ros-manifest` runs).

**State of the five pull requests (checked 2026-11-13 against `main` at `56a9a913`, which this branch contains):** (a) merged (pull request 449): `optional_layers`, `resolve --layout manifest-dir` (`cli.py:82`, `--cache-dir` at :90), `make install-ros-manifest` (`Makefile:120`, stamp rule :202), CI install (`validate.yml:39`), README "The `extends` cache" (README:141). (c) delivered under issue 429 (pull requests 456, 460): `repo_pin` is the 13th verb (`adapter:71`), `adapter_repo_pin` and `_rc_pin_kind` in `ros2_colcon/adapter.sh:1032,1082`, ADR-0019; and `_rc_repos_entries` already strips quotes from `version` (`adapter.sh:228`), so the old step "strip quotes" is done. Not delivered: (b), (d), (e). This revision plans (b) in full and keeps (d) and (e) as outlines.

What the code looks like now, for (b) (every line number below was read in this worktree on 2026-11-13; none carried from the earlier plan):

- Settings keys: `_PROJECT_FILE_KEYS` is `_project_registry.sh:706` (build test install bootstrap_url location location_path tracking instructions); per-key value rules are `_project_file_value_error` (:749; `bootstrap_url` case :780); the whole-file parse is `_project_file_parse` (:1019; unknown key :1040, per-type refusal through `_project_type_unused_setting` :1057, the records cross-key check :1070); `_project_type_unused_setting` is :951; `project_type_unused_settings_problems` (:976) checks each `unused_settings` entry is a known key. `project_file_set` (:1575) validates a `set` and refuses an unused key at :1657. The header grammar and key list are `_project_registry.sh:20-95`, with the sentence "Today ros2_colcon lists build and test ... and single_project lists bootstrap_url" at :70-71.
- Dispatcher `.agent/scripts/adapter`: `ACTIVE_PROJECT_ROLE`/`_DISTRO` from the registry line at :268-278 (read by nothing for role); the settings-file variables are exported at :300-321 (`ACTIVE_PROJECT_BOOTSTRAP_URL` at :321); the header comment at :46 names them; `active_project_fallback_note` :341.
- `register_project.sh`: type detection :628 (`configs/manifest` exists, or `--set bootstrap_url`, else `single_project`); `--set` keys come from `_PROJECT_FILE_KEYS` (:602); `--distro` and `--role` exist (:181-193); the legacy `.sh` copy loop :728; `setup=when-missing` runs `adapter setup` only for a hosting path that does not exist (:833); the message at :1186 names `bootstrap_url`. `register_session_root.sh` (#466) takes only `--set build=`/`test=` and registers whatever type is detected (a folder with no `configs/manifest` is `single_project`); `project_setting.sh` and `registration_verify.sh` hold no key list (they read `_PROJECT_FILE_KEYS`), so they need no edit. `.agent/projects.local.example:50,72` and the `ros2_colcon/registration.conf` comment name `bootstrap_url` as the only fetch source.
- `ros2_colcon/adapter.sh`: `_rc_manifest_dir` :65 (read at :74, 103, 112, 131, 504, 603, 645, 1125); `_rc_require_manifest` :72; `_rc_distro` :129; `_rc_bootstrap_url` :307; `_rc_bootstrap_manifest` :335; `adapter_setup` :492; `adapter_sync` :598; `adapter_validate` :638; `adapter_worktree_repos` :744 and `adapter_worktree_env` :827 read the same directory through `_rc_layers`/`_rc_repos_entries`. `unused_settings` files: `ros2_colcon` lists build, test; `single_project` lists bootstrap_url.
- The resolver (merged): `ros-manifest resolve --manifest <file> --role --distro --out <dir> --layout manifest-dir [--cache-dir]` writes `<out>/repos/<layer>.repos`, `layers.txt`, `optional_layers.txt`. The leaf manifest must be a local file; `extends` with url+ref+path is cloned by the resolver.
- The workspace venv belongs to the main checkout (`Makefile` WS_ROOT); a worktree has no `.venv` (confirmed: this worktree has none). Existing adapter tests: `.agent/scripts/tests/test_ros2_colcon.sh` (2400 lines; `make_sandbox` :96, `make_toolchain_stubs` :111, `run_adapter` :190) run in `mktemp` sandboxes with stub `vcs` and `colcon`.

Issue 267's owner decisions this plan relies on (issue 267 body, "Design decisions (owner, 2026-09-16)"): 1 "One source of truth per manifest; manifests compose", 2 "Layers stay a fixed, single list per manifest ... Roles only subtract from a layer's list", 3 "Distro is a selector, not a branch ... a repo may be **absent** from a distro", 5 "Generated, not hand-maintained, per-distro/per-role vcstool `.repos` files, with provenance", and the Constraint "No imports from workspace scripts; the adapter calls the CLI only." Decision 4 (the role model) is open and the plan does not depend on it: a role is a name passed to `--role`.

## Approach

This revision plans one pull request in full: **(b)**. (d) and (e) stay outlines, updated.

| PR | What | Status |
|---|---|---|
| (a) | Resolver additions, install target, CI | merged (449) |
| (b) | Settings keys `source`, `source_ref`, `source_path`; the adapter's manifest route; tests; design section | this plan, in detail |
| (c) | `repo_pin` required verb | delivered under 429 (456, 460) |
| (d) | Records: Direction line, step 4 row, Decided Against entries, west note | outline; independent of (b) |
| (e) | Manifest text and drafted project issue, records only | outline; after (b) is merged so the offline check can run the adapter's resolve step |

Vocabulary: **bootstrap route** = today's `bootstrap.yaml` flow, unchanged. **Manifest route** = the new one, chosen by one fact: the project's settings file sets `source`. A project that sets none of the new keys runs the bootstrap route exactly as today.

What (b) delivers for the owner's test, said plainly: the mechanism. A ros2_colcon project registered with `source`, `role=` and `distro=` is fetched, resolved and validated from a manifest. (b) does **not** make "start a session in an empty folder and ask to onboard" work end to end: `register_session_root.sh` takes only `build=`/`test=` and registers the folder as `single_project`, and registering an existing empty folder as ros2_colcon would run the static gate's `adapter validate` against a project that was never set up. That path is issue 473's (onboarding fills an empty folder from a source). (b)'s tests cover the path that works now: `register_project.sh <not-yet-existing path> --type ros2_colcon --role R --distro D --set source=... --set source_ref=...`, where registration runs `adapter setup` itself (`setup=when-missing`), and the by-hand route `project_setting.sh set` plus `adapter setup`.

### One concern: a stale manifest (pull request (b))

Rule: after `adapter sync`, what is resolved is what the remotes hold now, for the leaf manifest and for every `extends` base, or the adapter says on stderr that it is not and why. Never silently stale.

**Leaf manifest, git form** (`source` is a URL). The adapter owns the clone (`configs/source-clone/`, a full clone, not shallow, so a commit is reachable; `git clone --no-checkout -- <url> <dir>` on first use; a clone whose `origin` differs from `source` is refused, as `_rc_bootstrap_manifest` refuses a mismatch). `setup` and `sync` then run `git fetch --tags --force origin` and decide the kind of `source_ref` locally: a branch if `refs/remotes/origin/<ref>` exists, else a tag if `refs/tags/<ref>` exists, else a commit if `git rev-parse --verify <ref>^{commit}` succeeds and `<ref>` is 7 to 64 hex characters, else an error naming the ref. Result per case:

| Case | What is resolved | Message |
|---|---|---|
| Branch that moved, clone clean and on that branch | `git merge --ff-only origin/<ref>`; the new tip | `source: updated <ref> <old>..<new>` |
| Branch, ff-only impossible (local commits) | the clone as it is | stderr warning: local commits not on `origin/<ref>`, resolved what is checked out |
| Branch, clone dirty | the working tree as it is, no checkout | stderr warning: uncommitted changes in the manifest clone, resolved those, not what the remote holds |
| Branch, clone on another branch (or detached) and clean | `git checkout <ref>` then ff-only as above | `source: switched to <ref>` |
| Branch, clone on another branch and dirty | the working tree as it is | the dirty warning |
| Tag | detached checkout of the tag as the fetch left it (a tag moved on the remote is followed, `--force`) | `source: <tag> -> <sha>` |
| Commit | detached checkout of that commit; immutable, so a push to the remote changes nothing until `source_ref` is changed | `source: pinned <sha>` |
| Tag or commit, clone dirty | working tree as it is | the dirty warning |

A dirty clone is never forced. `.resolved-from` records `source-state=local` for every warning case, and `validate` prints it as a warning (the owner editing the manifest in the clone is a supported working style, not an error). A fetch failure (offline) leaves the clone and the previous generated directory as they are and exits 1 on `sync` (exit 1 on `setup` of a fresh dir).

**Leaf manifest, path form**: used in place; nothing to refresh; `.resolved-from` records its modification time and size so `validate` can say `sync` is due when the file changed.

**`extends` bases.** The resolver clones a base with `git clone --branch <ref> --depth 1` and reuses the cache entry forever (`extends.py`, `_clone_or_reuse`: `if dest.is_dir(): return dest`). The fix is in the adapter only and keeps `tools/ros-manifest/` untouched by it: `resolve` is run with `--cache-dir` inside the temporary sibling directory, which is new on every run and discarded after, so every `sync` clones every base afresh and a branch-pinned base follows its remote. The cost is one shallow clone per base per sync, accepted because sync already fetches. (The resolver's own default cache, `.ros-manifest-cache` in the cwd, still persists for people who run the CLI directly; (a) adds a README paragraph saying so and how to refresh: delete it or pass a fresh `--cache-dir`.) Difference stated: `extends` takes a branch or a tag (`git clone --branch` cannot take a commit), while the leaf can also be a commit; a commit in `extends.ref` is the resolver's clone error, which the adapter passes through, and a test asserts it. Aligning them is not done: not needed by the owner's manifests.

Tests for the whole concern, each pushes to the bare remote(s) and then runs `adapter sync`, never edits a clone: leaf branch moved (clean); leaf branch with a dirty clone (warning, local edit resolved); leaf clone on another branch (clean, switched; dirty, warning); leaf commit pin (push does not change the result; changing `source_ref` to the new commit does); leaf tag moved with a forced tag update; base branch moved with the leaf's `extends` pointing at a bare base remote; base given as a commit (clone error passed through); offline fetch (bare remote removed) leaves the previous generated directory.


### Pull request (b): settings keys, adapter route, tests, design

Settings: three new keys in `.agent/projects.d/<name>`; role and distro stay on the registry line (`role=`, `distro=`, `_project_registry.sh` header :31-32, read by the dispatcher at `adapter:268-278`).

| Where | Key | Meaning | Rule |
|---|---|---|---|
| settings file | `source` | Where the project's source description lives (for `ros2_colcon`, the manifest) | an absolute path to a file, or an `http(s)://` / `file://` git URL of a repository that holds it |
| settings file | `source_ref` | Branch, tag or commit | required with a URL; refused with a path; refused when `source` is unset |
| settings file | `source_path` | Path of the file inside the repository | default `manifest.yaml`; relative, no `..`, no leading `/`; refused with a path; refused when `source` is unset |
| registry line | `role=` | `ros-manifest resolve --role` | required on the manifest route |
| registry line | `distro=` | `--distro`, and `_rc_distro` | required on the manifest route; the legacy `ROS_DISTRO` fallback in `_rc_distro` is not accepted on this route (one source; resolve needs it before any other config) |

**Settled by the owner's rename, per his issue comment:**

- **`source` on a type with no use for it is refused through that type's `unused_settings`, like `bootstrap_url`.** `single_project/unused_settings` gains three lines (`source`, `source_ref`, `source_path`), each with the reason text: a `single_project` checkout is cloned by hand and nothing resolves a source for it today, and a general source for every type is issue 473's. `ros2_colcon/unused_settings` does not list them. Why refuse rather than accept and ignore: the rule of issue 332 (a setting is never stored and silently ignored), and the refusal is cheap to lift in 473, one line each, when `single_project` gains a use. `validate_adapter.sh` (via `project_type_unused_settings_problems`) then checks the three are known keys with a reason, which is why step 1 comes first.
- **Type detection does not read `source`.** `register_project.sh:628` keeps choosing `ros2_colcon` from `configs/manifest` or `bootstrap_url` only; a type-neutral key must not decide a ROS type. So `--set source=...` needs `--type ros2_colcon` (else the type is detected as `single_project` and the unused-setting refusal names the reason, and the message there says to pass `--type ros2_colcon`). Listed for veto.
- **Message and document wording.** Every message the adapter and validators print names `source`, `source_ref`, `source_path`; the words "manifest" stay for the file and the route (`manifest route`, `manifest-resolved`, `manifest: ...`-style progress lines become `source: ...`). The old key names `manifest`, `manifest_ref`, `manifest_path` exist nowhere in code, tests, header, `docs/design.md` or `script_reference.md`; the final search (step 8) checks that, and checks the plan's own history is the only place left.

Steps, each a commit:

1. **Settings keys.** `_project_registry.sh`: add the three keys to `_PROJECT_FILE_KEYS` (:706); `_project_file_value_error` (:749) cases (shape of each value: path or URL form, ref charset via `git check-ref-format`-safe pattern or 7-64 hex, relative path without `..`); the cross-key rules after the per-line loop in `_project_file_parse` (beside the records combination, :1070): `source_ref`/`source_path` need `source`, a URL `source` needs `source_ref`, a path `source` refuses both, `source` with `bootstrap_url` refused (the file says which two); `project_file_set` (:1575) validates the whole resulting file, so `set source=...` is judged against what the file holds (check it calls the same cross-key function; if it does not, share one); header grammar and key list (:20-95 including the sentence at :70-71). Dispatcher `adapter`: `ACTIVE_PROJECT_SOURCE`, `_SOURCE_REF`, `_SOURCE_PATH` beside `ACTIVE_PROJECT_BOOTSTRAP_URL` (:300-321), and the header comment at :46. `single_project/unused_settings` gains the three lines. `register_project.sh`: nothing for detection (above); the `--set` key list follows `_PROJECT_FILE_KEYS`; the :1186 failure hint names `source` as well as `bootstrap_url`; `.agent/projects.local.example:50,72` and `ros2_colcon/registration.conf` comment gain the source route. Tests in `test_project_file.sh`, `test_project_registry.sh`, `test_register_project.sh`, `test_adapter.sh` (the `unused_settings` validation cases there use `bootstrap_url`; add one for the three keys): each key's accept and refuse cases, each cross-key refusal, `set` on a single_project refused with the reason, `--set source=...` without `--type` refused with the hint, the `unused_settings` file check.
2. **Route, directory, resolver call** in `.agent/project_types/ros2_colcon/adapter.sh`.
   - `_rc_manifest_route` is `manifest` when `ACTIVE_PROJECT_SOURCE` is set, else `bootstrap`. On `manifest`, any other bootstrap source that resolves is a hard error naming it: `BOOTSTRAP_URL` in the environment, `bootstrap_url` in the settings file (step 1 already refuses it), `MANIFEST_BOOTSTRAP_URL` in the legacy `projects.d/<name>.sh`, `configs/project_bootstrap.url` (the four sources of `_rc_bootstrap_url`, :307); the message says to remove it or to unset `source`. The bootstrap route's "no bootstrap URL" error (:349) gains a line naming `source=<url-or-path>`. A `configs/manifest` link left from an earlier bootstrap is ignored on the manifest route.
   - `_rc_manifest_dir` (:65) returns `$(_rc_root)/configs/manifest-resolved` on the manifest route (a symlink to the current generated directory), else `configs/manifest`. Every other verb keeps reading `layers.txt`, `optional_layers.txt`, `repos/<layer>.repos` through it, so `env`, `build`, `test`, `repos`, `worktree_repos`, `worktree_env`, `repo_pin` are unchanged (ADR-0012's directory contract). `_rc_require_manifest` (:72) failure text on this route says `adapter --project <name> setup` instead of the ros2_agent_workspace shape. `_rc_distro` (:129) on this route takes `ACTIVE_PROJECT_DISTRO` only (the generated directory has no `bootstrap.yaml`; its legacy fallbacks stay for the bootstrap route).
   - `_rc_resolver_bin`: `<main checkout>/.venv/bin/ros-manifest`, main checkout = `git rev-parse --path-format=absolute --git-common-dir` of `$WORKSPACE_ROOT` without `/.git`, falling back to `$WORKSPACE_ROOT` (the Makefile's `WS_ROOT` idea). Absent: `ERROR: the manifest resolver is not installed at <path>; run: make install-ros-manifest (from the workspace main checkout)`. No `PATH` lookup, no pip. If the resolver exits 2 with `unrecognized arguments: --layout`, the message says the installed resolver predates this adapter and to rerun the make target.
   - `_rc_source_fetch`: the leaf table above. `_rc_manifest_resolve`: requires `ACTIVE_PROJECT_ROLE` and `ACTIVE_PROJECT_DISTRO`, each failure naming the registry line: `edit the line for '<name>' in .agent/projects.local to add role=<name> (register_project.sh does not change an existing line), then run: adapter --project <name> sync`; runs `"$bin" resolve --manifest <file> --role <role> --distro <distro> --out <tmp> --layout manifest-dir --cache-dir <tmp>.cache` into a new temporary directory under `configs/`; rejects an empty `layers.txt` (message: role/distro selected no repositories); writes `<tmp>/.resolved-from` (route, source location, commit for a clone, `source-state`, role, distro, path-form mtime and size); swaps by symlink (`configs/manifest-resolved.<timestamp>/`, `ln -s` to a temporary link, `mv -T` over `configs/manifest-resolved`, then remove the previous directory). A failed resolve leaves the previous directory and link. The resolver's stderr is passed through.
   - `configs/manifest-resolved*` and `configs/source-clone` sit in `<root>/configs/`; the adapter does not edit the project's ignore files; setup prints one line saying so; `onboard-project` is the place to offer an ignore line. Listed for veto.
3. **Verbs.** `adapter_setup` (:492): when the route is `manifest`, check `vcs` first, before any fetch or resolve, then fetch, resolve, then the existing `_rc_require_manifest` and `vcs import --skip-existing` loop unchanged; the bootstrap route's body is untouched. `adapter_sync` (:598): on the manifest route, fetch and resolve before the existing loop. `adapter_validate` (:638): on the manifest route also fails when the link is missing (`run: adapter setup`) or `.resolved-from` disagrees with the current source, role or distro (`run: adapter sync`; for a role change: edit the registry line, then sync), warns for `source-state=local`, and warns for every checkout under `layers/main/*_ws/src/` that is not in the generated `.repos` (`vcs import --skip-existing` never removes checkouts; the warning names them; the adapter removes nothing).
4. **Package worktrees.** A package worktree's `env.sh` is written once at create time, so after a `sync` that changes the layers or role it is stale. Not fixed here; on the manifest route, when `layers.txt` changed, `sync` prints `existing package worktrees keep their old env.sh; recreate them`. Stated in the design bullet.
5. **Network needs**, stated in the design bullet and the adapter header: PyPI (at `make install-ros-manifest`), the source host, every `extends` host, every package host. No network once fetched, except `sync`.
6. **Synthetic tests** (`test_ros2_colcon.sh`, a section "manifest route"; no network, no real project, no `~/project11`). Fixtures: three invented repositories in two layers as bare `file://` remotes (a branch, a tag, a commit), a manifest with `optional_layers`, one per-distro override, one repository absent for a distro, two roles, a base manifest in its own bare remote. The resolver is `<sandbox>/.venv/bin/ros-manifest`, a wrapper running the real `ros_manifest.cli` under the repository's venv python when PyYAML imports (else those tests print `SKIPPED: PyYAML not importable` and count as skipped; CI installs the resolver so they run there), and a stub for failure cases. Cases: the stale-source tests above; setup from a path source and from a URL source at branch, tag and commit; **registration end to end** (`register_project.sh <missing path> --type ros2_colcon --role --distro --set source= --set source_ref=` runs `adapter setup` and the gate passes); validate passes, fails with the link missing, fails after a role or distro change (message names the registry line); a role change removes a repo from the generated `.repos` and validate warns about its checkout; per-distro override and absent repository honoured; optional layer failure tolerated, required layer failure aborts; resolver failure keeps the previous directory; resolver absent gives the one message naming the make target; a stale resolver (stub exiting 2 on `--layout`) gives the reinstall message; missing `vcs` is reported before any fetch (the remote is never contacted); missing `role=`, missing `distro=` each name their field and the edit-and-sync instruction; `source` with each other bootstrap source refused; `env`, `build`, `test`, `repos`, `worktree_repos`, `repo_pin` on a manifest-route project read the generated directory; quoted numeric ref; the unchanged existing suite is the proof the bootstrap route is untouched. Check `suites_for_files.sh` maps `tools/ros-manifest/` and the new files to this suite.
7. **Documents.** `docs/design.md` "Registry and adapters" (section starts :326): the settings-file bullet (:363-380) gains the three keys and the `unused_settings` sentence (:375-377) says `single_project`: `bootstrap_url`, `source`, `source_ref`, `source_path`; a manifest-route bullet in Now (route by `source`, generated directory, resolver by venv path, the stale-source rule, network needs, package-worktree `env.sh`, and the registration limits above); the two-types bullet (:395-397) says the adapter reads `configs/manifest` or the generated directory; one change-log row with the section's line count. **A late, small commit**: the design edit is the last commit of the pull request, made after a fresh merge of `main` (the Decision register and change log conflicted on merges on 2026-11-13), as one hunk in the section plus one change-log row, so a conflict is a one-line fix. `.agent/knowledge/script_reference.md` line 27 (`project_setting.sh` row: keys, and the `unused_settings` sentence); the Makefile has nothing to change. `_project_registry.sh` header is in step 1.
8. **Final search for stale references**, repo-wide (`rg -n -j 1`): `manifest_ref`, `manifest_path`, `ACTIVE_PROJECT_MANIFEST`, and `\`manifest\`` as a settings key (must remain only in this work plan's history and the 2026-11-13 issue comment), then `bootstrap_url`, `bootstrap.yaml`, `unused_settings`, `layers.txt`, `ros-manifest`, `manifest-resolved`, `configs/manifest`, `bootstrap URL` (each hit read: a sentence that says bootstrap is the only way to fetch a ROS manifest is updated).

### Prior delivery: (a) and (c) (merged, kept for the record)

(a) delivered what this plan's first revision listed (resolver `optional_layers`, `--layout manifest-dir`, `install-ros-manifest`, CI, README); (c) was delivered under issue 429 as `repo_pin`. Neither is replanned. (b)'s tests call the delivered `--layout manifest-dir` output; if that output differs from what step 2 reads, the fix is in (b)'s adapter reader, not a new resolver pull request, unless the difference is a resolver defect, which gets its own issue.


### Pull request (d): the records (outline; independent of (b))

- `docs/roadmap.md` Direction table (rows at :76-79 today): one Line in the owner's words, "I want the new manifest to be used for the pickerel test." (2026-11-10), as `| The Rolling instance is registered and fetched from a manifest in the new format on the second machine, and `adapter validate` passes (#436) | `gh-issue 436 closed` |` (valid in `sitrep_checks.sh`: kind `gh-issue`, `<N> <open|closed>`), placed before the #433 row it precedes. Listed for the owner's veto with the quote. Issue 436 closes when (b), (d), (e) are done; the second-machine run itself is issue 433's.
- Rows "Manifest support (step 4)" (`roadmap.md:203`) and step 4 (:180), both still `planned` with "west variant ... next milestone": done (resolver, p11 acceptance fixture, `--layout`, install target, `repo_pin`, and the adapter route once (b) merges); left (the manifest in the project's own repository, the second-machine run, the tool's name and repository, vcs2l versus vcstool); drop "dual prototype ... decides the tool" and "west variant ... next milestone".
- "Decided Against" (:357) rows: the west-based variant (2026-11-10, "Q4, decide against"; reason from `west-variant.md`: no per-distro refs, no layers, no `.repos` output, so this workspace's format, pre-processing and a converter are needed either way; revisit only if maintaining the resolver's composition code becomes a burden); and the six lines proposed in `docs/fork_parity.md` ("Proposed Decided Against lines"; the file is on main and in this branch now): container dispatch, agent image, `.devcontainer/` and the container `ci_local.sh` attestation (ADR-0014, ADR-0015; the CI part to be confirmed, as the file says); the fork's web dashboard; the local Ollama adversarial reviewer; the `agent launch` tmux launcher; the `post-checkout` layer symlink hook and the `scripts` symlink; the `.agent/.identity` file. Each row carries the reason text from the file; re-read the file's current wording at implementation time.
- `tools/ros-manifest/docs/west-variant.md`: the "Status: specification only ... next milestone" paragraph becomes a decided-against status and date, body kept as the record; README pointers.
- Check: `check_design_anchors.sh`, `validate_workspace.py`, `test_sitrep_checks.sh` against the new row.

### Pull request (e): manifest text and drafted issue (outline; records only; provisional)

- `.agent/work-plans/issue-436/records/manifest-rolling.yaml` (the fixture `tools/ros-manifest/tests/fixtures/p11/manifest.yaml` as base; the `site` layer in `optional_layers`; one role `dev` with no `roots`, which is the groups model in effect) and `manifest-issue-draft.md` (written per the outward-writes rule: says what agent_workspace is, links it, says use is optional). Provisional on the role model (issue 267 decision 4). Nothing is opened or written in any project repository.
- Refs per distro, from the owner's 2026-11-13 check on the second machine: of the 44 repositories, two have a `rolling` branch (`unh_marine_autonomy`, `ros2launch_gui`) and none has a `lyrical` branch (first 100 branches per repository). So Rolling needs per-distro `rolling` refs for those two, and **what ref Lyrical uses is an open question for the owner** (the default branch, as `distro` is a selector and not a branch, or a new branch created in the project's repositories, which is project work and an issue there). The draft records both and picks neither.
- An offline equivalence check recorded in the draft: resolve the manifest for the Rolling pair into a temporary directory and compare repository names and refs with the hosted Rolling instance's `.repos` files, read in place; differences listed.
- The second-machine run is issue 433's, done by the owner; no agent creates or uses `~/project11` or `~/project11-ng`.

## Files to Change

| File | Change | PR |
|------|--------|----|
| `.agent/scripts/_project_registry.sh` | keys `source`, `source_ref`, `source_path`: key list, value rules, cross-key rules, header | b |
| `.agent/scripts/adapter` | export `ACTIVE_PROJECT_SOURCE`, `_SOURCE_REF`, `_SOURCE_PATH`; header comment | b |
| `.agent/scripts/register_project.sh`, `.agent/projects.local.example`, `ros2_colcon/registration.conf` | hint text names `source`; example and comment; no detection change | b |
| `.agent/project_types/single_project/unused_settings` | refuse the three keys with the reason | b |
| `.agent/project_types/ros2_colcon/adapter.sh` | manifest route, source fetch and refresh, resolve and swap, validate checks, header | b |
| `.agent/scripts/tests/test_ros2_colcon.sh`, `test_project_file.sh`, `test_project_registry.sh`, `test_register_project.sh`, `test_adapter.sh`, `suites_for_files.sh` (if its map needs it) | tests and suite mapping | b |
| `docs/design.md`, `.agent/knowledge/script_reference.md` | design section and change-log row (late commit), script reference row | b |
| `docs/roadmap.md`, `tools/ros-manifest/docs/west-variant.md` | records | d |
| `.agent/work-plans/issue-436/records/*` | manifest text and drafted issue, provisional | e |

Not touched: `.agent/scripts/dispatch_phase.sh` and the run-issue skill (another session works there), `register_session_root.sh`, `project_setting.sh`, `registration_verify.sh` (they read the key list), `tools/ros-manifest/`.

## Prior Art

- The bootstrap route (`_rc_bootstrap_manifest`, `_rc_bootstrap_url`) is the model for URL handling, the origin-mismatch refusal and "report and reuse" for a clone with local work; nothing in it changes.
- `extends` in `schema.py` (`path`, `url`, `ref`) is the model for how the adapter locates a source, so one vocabulary covers both.
- `unused_settings` (issue 332) is the model for refusing `source` on a type with no use for it.
- The Makefile's `WS_ROOT` and `cross_model_review.sh` (`${...%/.git}/.venv/bin/python3`) are the prior art for finding the main checkout's venv from a worktree.
- The delivered `repo_pin` and `_rc_pin_kind` read the same `.repos` files through `_rc_manifest_dir`; (b) leaves that contract alone.
- Nothing new is built beyond the adapter route.

## Serves

Workspace goal "Modular" (README, Workspace goals: knowledge about a kind of project, like ROS, added as modules without changing the rest), under `docs/design.md#registry-and-adapters`; the roadmap Direction acceptance case (the Rolling instance on a second machine).

## Design Picture

Alters `docs/design.md#registry-and-adapters` in (b): the settings file gains three keys, the `ros2_colcon` adapter gains a second route that calls the workspace-installed resolver by CLI, and `unused_settings` for `single_project` grows. One change-log row, in a late small commit. (d) changes `docs/roadmap.md` only; (e) changes no design text.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Design section and change-log row move with the code in (b); the old key names are searched for and removed from every text. |
| Test what breaks | Every staleness case is tested by pushing to a bare remote and syncing, not by editing the clone; registration end to end is tested on the path that works. |
| Ask about what matters | The role model (not blocking), the Lyrical ref (for (e)) and the veto list below. |
| Only what's needed | No rename of `bootstrap_url` or `distro` (473); no detection by `source`; no onboarding path (473); the resolver is not changed. |
| Put each thing at the level it applies to | A type-neutral key name for a general idea; the manifest-specific words stay in the ROS adapter; the project's manifest and issue are drafted here and opened nowhere (ADR-0016). |
| Workspace is project-agnostic | Adapter, resolver and tests name no project; fixtures are invented; names appear only in the records of (d) and (e). |
| Verify before claiming | Every line cited here was read in this worktree on 2026-11-13; the second-machine run stays the owner's. |
| Light touch on projects / nothing required | No key is required; a project with none behaves as today; no ignore file edited; a dirty source clone is never forced. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 project-agnostic | Yes | Synthetic fixtures only. |
| 0009 Python package management | Yes | The adapter uses the resolver in the workspace `.venv` from the delivered make target; no bare pip. |
| 0011 / 0019 adapter contract | Yes | No verb added; verbs keep their contract; `repo_pin` reads the generated directory unchanged. |
| 0012 worktree composition | Yes | `worktree_repos` and `worktree_env` untouched; same directory contract; stale `env.sh` after `sync` stated and printed. |
| 0013 progress timeline | Yes | This entry; later phases append. |
| 0016 / 0021 session roots | Yes | (b) does not change the session-root registration; the project's manifest and issue are records here only. |
| 0017 design is current | Yes | `docs/design.md` updated in (b), late commit. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `_PROJECT_FILE_KEYS` | header, `_project_file_value_error`, the cross-key rules, dispatcher exports, `unused_settings` of both types, `register_project.sh` hints, example file, tests, script reference | Yes (b steps 1, 7) |
| `single_project/unused_settings` | `test_adapter.sh` cases, `validate_adapter.sh` run, the design sentence | Yes (b steps 1, 7) |
| `_rc_manifest_dir` | every verb that reads it (listed above); `repo_pin`, `worktree_*` | Yes, same directory contract (b step 2), tested |
| Layers change at `sync` | existing package worktrees' `env.sh` | Stated and printed, not fixed (b step 4) |
| Registry line `role=`/`distro=` required on the route | messages that tell the user how to edit it | Yes (b step 2) |
| Roadmap rows | Direction check grammar, `check_design_anchors.sh` | Yes (d) |
| Type-neutral `source` | issue 473 (renames `bootstrap_url`, `distro`, lifts the `single_project` refusal) | Not here; named in the refusal reason |

## Open Questions

- For the owner (does not block (b)): the role model, groups or dependency closure; a role is a name passed to `--role`.
- For the owner (blocks (e)'s text, not (b)): which ref Lyrical uses, since no repository has a `lyrical` branch.
- Issue 473 owns the empty-folder flow; (b) says in its design bullet and pull request what works until then.

## Decisions for the owner's veto

1. **Role and distro stay on the registry line; only the source goes in the settings file.** The adapter's messages say how to change a role: edit the line in `.agent/projects.local`, then `adapter sync`. Undo: small.
2. **The route is implied by `source` being set; any other bootstrap source resolving alongside it is a hard error.** Undo: small.
3. **`source` set on `single_project` is refused through its `unused_settings`, as `bootstrap_url` is;** 473 lifts it when `single_project` gains a use. Undo: one line per key.
4. **`source` does not select the type at registration:** `--set source=` needs `--type ros2_colcon`. Undo: one condition.
5. **The adapter, not the resolver, clones a git-hosted source** and follows the staleness table: fast-forward only when clean and on the branch, never forcing a dirty clone, with a warning. Undo: moderate.
6. **The generated and cloned directories (`configs/manifest-resolved*`, `configs/source-clone`) sit in the project root and the adapter edits no ignore file;** `setup` prints a note. Undo: small.
7. **Every `sync` clones every `extends` base afresh** (cache inside the temporary directory); `extends` stays branch-or-tag while the leaf may be a commit. Undo: small.
8. **A layer with no repository for the role and distro is left out of `layers.txt`; an empty result is rejected by the adapter.** Undo: small.
9. **(b) does not make the empty-folder onboarding flow work; that is 473's.** The owner's second-machine run uses `register_project.sh <new path> --type ros2_colcon ...` from the workspace until then. Undo: none; scope.
10. **The Direction line's check is `gh-issue 436 closed`** (d). Undo: trivial.

## Estimated Scope

(b) large (one pull request; the design edit last, small); (d) and (e) documentation and records, small. Issue 436 closes when all three are in.
