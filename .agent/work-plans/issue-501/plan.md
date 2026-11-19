# Plan: repos-manifest: build

## Issue

https://github.com/rolker/agent_workspace/issues/501 (the issue body's `tools/ros-manifest/` paths read `tools/repos-manifest/`).

## Context

`init` and `sync` set up a system directory and write a stub `setup.bash` that fails when sourced. `build` is the next command: it builds the layers in the manifest's order with colcon and writes the one `setup.bash`. The tool's design section "build" (`tools/repos-manifest/docs/design.md`) already states most of it; this plan fills the gaps the Issue Review listed. There is no `build` module yet; `cli.py` has no `build` subcommand.

What was run against the installed colcon (colcon-core 0.21.3, colcon 0.20.0, `/usr/bin/colcon`; three tiny CMake packages `good`, `good2`, `bad` where `bad` has `message(FATAL_ERROR)`; script kept at the session scratchpad):

| Run | Exit | `install/` afterwards |
|---|---|---|
| `colcon build --base-paths good bad good2` | 1 | `setup.bash` and friends exist; no package installed (the build stopped at `bad`) |
| the same with `--continue-on-error` | 1 | `setup.bash` exists; `good` and `good2` installed |
| `--base-paths bad` only | 1 | `setup.bash` exists, no package |
| `--base-paths <nonexistent>` | 0 | `setup.bash` exists, no package |

So colcon exits non-zero when any package fails, also with `--continue-on-error`, and it writes `install/setup.bash` after a failed, partial and even empty build. The existence of `install/setup.bash` therefore says nothing about success.

## Approach

1. **`src/repos_manifest/build.py`** with `run_build(layer_names, colcon_args)`, wired to a `build` subcommand in `cli.py`: `repos-manifest build [--distro D]... [LAYER ...] [-- COLCON_ARGS...]`. It finds the system and the distro(s) as `sync` does (`find_system`, `read_config`, `distros_for`) and holds stop signals over file writes as `sync` does.
2. **What it reads.** The order of layers and each layer's repos come from `.repos-manifest/resolved/<distro>/layers.txt` and `<layer>.repos` (the files `sync` wrote), not from re-resolving the manifest, so `build` needs no network and sees the same repos `sync` placed. Each repo's path is `layer_src_parts(layout, distro, layer) + key`. A repo whose directory is not on disk (skipped as optional) is dropped from the list; a layer left with no repo on disk is skipped as empty. If `resolved/` is missing, it is an error saying to run `sync`.
3. **Where colcon runs.** In the layer's directory: `<distro dir>/<layer>/` for a named layer. For the unnamed first layer, the distro's directory itself (the system directory for a flat system), which is also the parent of the named layers' directories, so its `build/ install/ log/` sit beside them. A named layer is not named `build`, `install`, `log` or `src` (spec), so nothing collides. The command is `colcon build --base-paths <repo paths> <args after -->`, with the layer directory as cwd, so a `colcon_defaults.yaml` there is read. For `base-paths` the first layer's `src/` is not given as a whole; only listed repos are. The unnamed layer's colcon sees only its own repos, never the named layers' `src/` (a test checks this).
4. **Environment.** Each colcon runs in a bash subshell that first sources the `install/setup.bash` of the nearest earlier layer that is recorded as built (see 5), then `exec colcon ...`. The first layer gets the environment `build` was run in (unchanged, as the design says).
5. **How "built" is decided.** A layer is built when its colcon exit status was 0 in a run, and this is recorded in a new file `.repos-manifest/built.yaml` (`format: 1`, per distro key, the list of built layers and the time), written whole by `replace_file`, read and shape-checked like `state.yaml` (a file that does not read is an error naming it). `install/setup.bash` on disk is not used (it exists after failures, shown above). `state.yaml` is not extended: its shape is checked strictly and holds repo records; a separate file keeps `sync`'s state unchanged. A layer that fails has its record removed, and so do all later layers, because they were built on a layer that has changed. A layer that builds successfully gets its record, and the records of the layers after it are removed too, since they were built on its old output. The effect: the built layers are always a prefix of the manifest's order.
6. **What `setup.bash` sources.** The last layer of that prefix (not skipped-empty layers, which have no install). It is the layer's `<layer dir>/install/setup.bash`, written as an absolute `source` of the path made from the system directory's real path (the stub's is a plain text file; the new one is a few lines and says it was written by repos-manifest, which layers it covers and when). A run that built no layer (the first layer failed) leaves `setup.bash` pointing at what the record says is built: if nothing is built, it is written back as the stub text, so sourcing it fails as it does today. It is rewritten at the end of every run that tried at least one layer, in one step (temporary file in `.repos-manifest/`, then rename, signals held), never partial.
7. **Replacing the stub.** `setup.bash` is replaced when it is missing, or is a regular file whose text is the stub (`SETUP_TEXT`) or a file `build` wrote (it carries a first-line marker `# Written by repos-manifest.`; the stub starts with the same marker). A file with other text is a person's own: left as it is, named in a warning, and the exit status is 1 (so the person is not left sourcing something stale unaware); a directory, a dangling link or any non-regular file is left as it is, warned, exit 1. A link to a regular file is treated by what it points at but replaced as a link is not (the link is left, warned): `build` never writes through a link. `sync` is unchanged: it still creates the stub where none exists; its message and the design sentence "Until `build` is built" are rewritten.
8. **Layers named and order.** `build <layer>...` builds only those layers, always in the manifest's order whatever the argument order (duplicates once); an unknown name is an error listing the layers, before anything runs. If an earlier layer (not skipped as empty) is not in the built record, the command refuses with the name of the layer and the command to build it first (`repos-manifest build <layer>`), before anything runs; it does not build on whatever is on disk. The refusal considers the layers named in the same run as built-before-it. Without names, every layer is tried in order.
9. **Stop at the first failure.** A layer fails when colcon exits non-zero, including with `--continue-on-error` after `--`. `build` then stops: the later layers are not tried. With several distros, the next distro is still built (a distro does not depend on another), and the exit status is 1 if any distro had a failure.
10. **The closing report**, per distro, after colcon's own output: one line each for layers built, the layer that failed (with the colcon exit code and the layer directory, where the log is), layers not tried because of the stop, layers skipped as empty, and layers not asked for that are still recorded built; then the line `setup.bash: sources <layer>` or `setup.bash: nothing is built`. Exit status 0 when every layer asked for built or was skipped as empty; 1 on a failure, a refusal, a `setup.bash` left alone, or a colcon that cannot be run (not found: an error before any layer, saying colcon is needed and where it is looked for on PATH; the `README` already says colcon is needed only by `build`). A stop signal ends the run with one line saying which layers finished; the child colcon gets the signal first (it is in the same process group) and the record and `setup.bash` are not changed for the interrupted layer.
11. **The `install/` note.** When a layer's directory has an `install/` and the layer's list has a repo on disk that is not in the resolved list, or the record of the layer's last build lists a repo no longer listed, `build` prints before building that layer: "<layer>/install/ may hold what an earlier build installed of <repo>; build it afresh to drop it." To detect it, `built.yaml` also records the repo keys each layer was built from, and the note names those that are no longer listed or are no longer on disk. (The check compares recorded keys with the current list; no colcon introspection.)
12. **Docs**, in the same change, below.

## Tests (no ROS)

All in `tests/test_build.py` plus a helper in `tests/helpers.py` to write a small CMake package (`package.xml` with `build_type cmake`, `CMakeLists.txt` with `project(x NONE)` and one `install(FILES)`; a "bad" one with `message(FATAL_ERROR)`) and a fixture that makes a system with `init --yes` from a local manifest and local git remotes, as `test_sync.py` does. Plain CMake needs `cmake` on PATH; no ROS and no ament.

Two kinds, so the tool's logic is covered where colcon is absent:

- **Stub colcon** (`tests/fixtures/stub_colcon`, a bash script put first on PATH by a fixture; `chmod +x` in the plan). It appends cwd, its arguments and whether `AMENT_PREFIX_PATH`/a marker variable from the sourced earlier layer is set to a log file, creates `install/setup.bash` (so the stub sourcing works), and exits with the code named in a per-package file or an environment variable. These always run, in CI too, and cover: the order and the `--base-paths` list; only repos on disk; cwd for the unnamed first layer (the distro directory, and not the named layers' directories), for a named layer, and for a distro-dirs system; `--` arguments forwarded to every layer; the previous built layer sourced; stop at the first failing layer, with `--continue-on-error` in the args and exit 1 from the stub; later layers not tried and reported; setup.bash content after success, after a failure at layer 2 (sources layer 1), a failure at layer 1 (the stub text again), and a rebuilt layer 1 that drops the records of 2 and 3; refusal of `build c` when `b` is not built and no refusal when `b` is named too; argument order ignored; unknown layer name; empty layer skipped; skipped-optional repo dropped; `setup.bash` that is another text, a directory, a dangling link and a link: left alone, warned, exit 1; the stub replaced; `built.yaml` unreadable -> error naming it; colcon not on PATH -> error; two distros with a failure in the first; the install note; the report lines and exit status; a stop signal during a layer (as `test_interrupted.py` does for sync) leaves `setup.bash` and `built.yaml` as they were, with no temporary left.
- **Real colcon** (marked `@pytest.mark.colcon`, skipped when `shutil.which("colcon")` or `cmake` is missing). They build real packages: two layers, the second needing the first's package (`find_package`), then source the written `setup.bash` in bash and check both packages are visible (`$CMAKE_PREFIX_PATH`/ `share/<pkg>`); a layer with one good and one bad package with and without `--continue-on-error` (exit 1 both; good package installed only with it; `setup.bash` still points to the previous layer), which also re-checks the colcon behaviour in the table above on the installed version. The skip says why in its reason, and the `conftest.py` report header prints the colcon line like the `vcs` one. If `REPOS_MANIFEST_REQUIRE_COLCON=1` is set, absence fails instead of skipping.

How colcon is found: on PATH, as `vcs` is, with the test python's directory appended (a `colcon` pip-installed in the `.venv` is found). Not verified here: this worktree has no `.venv`, and `colcon` is `/usr/bin/colcon` (apt, Python 3 system packages), not in a venv.

What CI runs: the job `validate-repos-manifest` (`.github/workflows/validate.yml`) has no colcon or cmake step today (`ubuntu-latest` has cmake; colcon is not preinstalled), so with no change every real-colcon test would skip silently. The plan adds `pip install colcon-common-extensions` to that job and sets `REPOS_MANIFEST_REQUIRE_COLCON=1`, so a missing colcon fails CI. That step has not been run here; the first CI run is its check, and if pip's colcon packages do not behave on 3.14 the fallback is to set the variable only on the 3.10 leg. Changing CI configuration is on the Ask First list: the owner's yes is needed for that one file edit; without it the plan keeps the stub tests (which always run) and the real-colcon tests run only on machines with colcon, and the pull request says so.

## Files to Change

| File | Change |
|---|---|
| `tools/repos-manifest/src/repos_manifest/build.py` | New: the command |
| `tools/repos-manifest/src/repos_manifest/system.py` | `built.yaml` read/write beside `state.yaml`; `SETUP_MARKER`; the stub text stays |
| `tools/repos-manifest/src/repos_manifest/cli.py` | `build` subcommand, module docstring |
| `tools/repos-manifest/src/repos_manifest/sync.py` | message/comment wording only, if it says "until build is built" |
| `tools/repos-manifest/tests/test_build.py`, `helpers.py`, `conftest.py`, `fixtures/stub_colcon` | New tests, packages helper, colcon header line, marker; `chmod +x` on the stub |
| `tools/repos-manifest/docs/design.md` | "build" section rewritten with the decisions above; the sentence at "Until `build` is built"; `.repos-manifest/` contents (`built.yaml`) |
| `tools/repos-manifest/docs/spec.md` | only if it describes `setup.bash` or `build`; checked at implementation |
| `tools/repos-manifest/docs/roadmap.md` | tick the row "`build` builds the layers in order and writes one setup file" (the table has no status column; the project's way of marking done is read at implementation) |
| `tools/repos-manifest/README.md` | command list; the line "nothing builds yet" |
| `docs/manifest/roadmap.md` | no row for `build` alone: the row "The tool has the commands the adapter calls" stays unticked until `status` and the adapter route exist |
| `.github/workflows/validate.yml` | colcon install step and the require variable (needs the owner's yes) |

## Out of scope

- The workspace adapter (`.agent/project_types/ros2_colcon/adapter.sh`) is not switched to the tool's `build` here; that is a later part of issue 503.
- `status`, `show`, `add-distro`.
- Keeping going after a failed layer (see the next section).

## If the owner wants a keep-going option

This is not planned in. If wanted, it adds: a flag `--keep-going` (name to be agreed) on `build`; with it, a failed layer does not stop the run, and the layers after it are still tried, each sourcing the nearest earlier layer that is built. A layer tried after a failure is recorded built only if its colcon exited 0, but the built record is no longer a prefix, so `setup.bash` would still source the last layer of the unbroken prefix (the last layer before the first failure), and the report would name the layers that built but are not in the prefix ("built, not used by setup.bash because layer X failed"). Exit status 1 whenever any layer failed. Tests added: failure in layer 2 of 3 with the flag (layer 3 tried, sourced layer 1 not 2, report lines, `setup.bash` -> layer 1, exit 1), and without the flag unchanged. design.md "build" gains one paragraph. About half a day on top of the rest, same pull request. The rule that a layer's earlier layers must be built for `build <layer>` would then be read against the prefix, not just the record.

## Prior Art

`sync.py` and `system.py` give the system lookup, the distro choice, `replace_file`, `signals_held`, the stub, and the refusal style; reused. `tests/test_sync.py` and `test_interrupted.py` give the fixtures and the interrupt test shape. The prototype (`docs/prototype.md`) and the workspace adapter's `build` route build layers in order with colcon; read for the order and the environment sourcing, not copied (the adapter works from `layers.txt` in the old layout). colcon's own `--packages-up-to` and `--merge-install` were considered and left to the person through `--`. A pickled/JSON record in `state.yaml` was rejected (strict shape, belongs to `sync`).

## Serves

The manifest-design goal of exercising the new design on a real project; `tools/repos-manifest/docs/design.md#build` (part's own design, ADR-0022).

## Design Picture

Changes only the part's design: `tools/repos-manifest/docs/design.md#build` and the system-directory section (`built.yaml`, the stub sentence). No change to the root `docs/design.md`.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | No keep-going flag, no `status`, no adapter switch. One new record file, because colcon's own files cannot say a layer succeeded. |
| Keep one current design | design.md is rewritten with the decisions in the same change, including the stub sentence. |
| Verify before claiming | colcon's exit status and `install/setup.bash` after a partial build were run (table above), and re-checked by the real-colcon tests. |
| Know whether it works | Failure, not-tried layers and what `setup.bash` sources are in the output and the exit status; tests check each. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0022 | Yes | Inside the tool; its own design, spec, roadmap. |
| ADR-0017 | Yes | design.md updated in the same change. |
| ADR-0009 | Yes | Tests run from the venv; colcon found on PATH, absence reported (and fails in CI). |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `build` exists | design.md stub sentence, README, tool roadmap | Yes |
| `setup.bash` is no longer only the stub | `sync`'s warning wording; `test_sync`/`test_init` tests that assert the stub text | Yes (checked at implementation) |
| New CI step | `validate.yml` | Yes, with the owner's yes |
| Adapter calls `build` | `adapter.sh`, `docs/manifest/roadmap.md` | No, issue 503 |

## Acceptance on the real project

The by-hand build of the registered multi-repo system at `~/project11` is the owner's to run or approve; another agent session works there, so the implementer does not run builds in it. The pull request says this step is still to be done, by the owner, with the command to run, and records afterwards how far it got and which packages failed (a failure there is the port's, with the command run). The tests above are what the implementer reports as run.

## Open Questions

- For the owner: the keep-going option (above).
- For the owner: yes or no to the CI change.
- `setup.bash` left alone when it holds other text makes the run exit 1; the alternative is to overwrite after a backup. Proposed: leave and warn.

## Estimated Scope

One pull request. The command, the record and the tests belong together (the tests are the proof of the decisions), and the docs must land with the command (ADR-0017). If review wants it split, the cut is: part 1 the command, the record and stub-colcon tests; part 2 the real-colcon tests, the CI step and the README; but the design text would then land in part 1.
