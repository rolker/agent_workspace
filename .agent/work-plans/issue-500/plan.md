# Plan: repos-manifest: `init` and `sync` set up and update a system directory

## Issue

https://github.com/rolker/agent_workspace/issues/500

The issue's own text is stale in the places the `## Issue Review` entry in `progress.md`
lists; that table stands in for it. Design basis: pull request 508 (issue 495, branch
`origin/feature/issue-495`), not yet merged. This plan names what it relies on from that text
(see "Design basis" below) so a change to 508 can be traced to a change here.

## Context

`tools/repos-manifest` on this branch has the resolver: `manifest.load_manifest`,
`selection.resolve` and `selection.check_role_and_distro`, and `output.write_output` (the
whole-or-nothing directory writer). It has no command that clones or updates anything and
no system directory. This issue builds `init` and `sync`.

The owner wants first, in his words, to "test the tool to build the project directory tree"
for his project on this machine, on ROS Rolling. So the work is in parts, one pull request
each:

| Part | What | Risk |
|---|---|---|
| 1 | `init`, and `sync` that clones what is missing and touches nothing that exists | Low: creates directories and clones; never changes an existing clone |
| 2 | `sync` against clones that exist: follow, leave alone, rebase, repo removed, per-distro reports | High: a person's work is at risk; own PR, own tests |
| (3) | `add-distro`: its own issue, proposed by the host; not in this plan | Reuses part 1's per-distro function |

Part 1 can land and be used before part 2 exists.

### Design basis (what this plan reads from pull request 508)

- "The system directory", `config.yaml` keys (`manifest`, `local_manifest`, `role`, `groups`,
  `layout`, `distros`), "More than one distro" with its two example trees, "Setting up with
  init", the Refusals table (rows for `init`), "Where the resolved files and state go",
  "Which distro a command uses", "Which manifest a distro reads", the `sync` section, "What
  the tools rely on", "What is built", "Open questions".
- The workspace side: `docs/manifest/design.md`, "What the tool has to give" (only the
  "failed resolve changes nothing" ask is in this issue).

If 508 changes one of these, the part of the plan that cites it is redone; nothing else moves.
Code review of part 1 starts after 508 has merged (the design edits in this plan are written
on top of 508's text; see "Design documents").

### What is on this branch that part 1 builds on

| Module (`tools/repos-manifest/src/repos_manifest/`) | What part 1 takes from it |
|---|---|
| `manifest.py` | `load_manifest(path, source)` (a file path only; refuses `base`), `Manifest.distros`, `.roles`, `.groups`; the url rules (see "Test remotes") |
| `selection.py` | `resolve(manifest, role, distro, extra_groups) -> Resolved` (layers in order, each repo's `key`, `url`, `version`, `optional`), `check_role_and_distro` (the role, distro and group errors) |
| `output.py` | `write_output(out, files, on_replaced)`: replaces a directory whole or not at all, sweeps leftovers, holds signals during the swap; `output_files(resolved)`: names and text of the resolved files |
| `yamlload.py` | `ManifestError`; the safe YAML loader |
| `cli.py` | `build_parser`, `main`, `run`; `Stopped` and `_signals_end_the_run`, which `sync` reuses (moved, see step 1) |

The user-visible `resolve` subcommand stays as it is.

## Approach

### Decisions that are mechanism (decided here, one line of reason each)

| Question | Decision | Why |
|---|---|---|
| Where does a manifest come from in part 1? | A local file path only, as `init`'s first argument. A value with `://` that is not a file gets a message saying only a path is read in this version. No `--manifest-ref` or `--manifest-path` flag yet. | The checkpoint: no second fetcher. |
| How `init` takes up the git and URL forms later | `init` and `sync` read a manifest only through `read_manifest(system, config, distro)` in `locations.py`, which today calls `load_manifest` on a path. When part 2 of issue 498 lands its fetcher, only that function grows to read the mapping form and `manifest_version`; `init` then gains `--manifest-ref` and `--manifest-path`, which fill the same `manifest` mapping `config.yaml` already allows. | One place reads a manifest, so there is one fetcher. |
| What `init` prints | A summary built from `Resolved` (manifest, role, groups on, the layout, and per layer each repo's key, version, url and `optional`). With several distros, one block per distro in the order of `--distro`, each headed by the distro. Replaced by what `show` prints when issue 499 lands. | `show` does not exist; the summary says the same things. |
| The question | `--yes` skips it. Without `--yes`, `init` reads one line from stdin; if stdin is not a terminal it refuses (before anything is created) and says to give `--yes`. A reply other than `y` or `yes` ends with "nothing was created" and exit status 1. | A script that forgot `--yes` must not hang or proceed. |
| A role or group a distro's manifest lacks | In part 1 every distro reads the one manifest file, so `check_role_and_distro` refuses it for `init`, as it does for `resolve`. In part 2, `sync` treats it like "the manifest no longer lists the distro": reported for that distro, nothing of it changed, the other distros go on. | The same class of case, one rule. |
| `sync` exit status when one distro is reported and the others go on | 1 when any distro was reported and skipped, or any non-optional repo failed. 0 otherwise. Repos left alone and optional repos skipped are listed and still exit 0. | A script must see a distro that did not sync; "left alone" is the tool working. `status` (issue 502) is the script-readable record. |
| Removing a distro | Out of scope here and for `add-distro`; stays an open question in the design. | #495 deferred it. |
| `vcs` and `git` required | Refusal before anything is created: `shutil.which("vcs")` and `shutil.which("git")` found, and `vcs --version` exits 0 (its output is not read). It is the last refusal checked, after the table's rows, so the table tests do not depend on `vcs`. | The review's rule; `vcs 0.3.0` prints a `pkg_resources` warning on every call, so no output of it is parsed. |
| Two runs at once | Part 1 has no lock. Two `sync` runs on one system can both try to clone the same missing repo; the second `vcs import` fails because the path exists, and is reported as a failed repo. Stated in the design's `sync` section. | The lock is out of scope (named below). |
| A layer change of a repo that is already cloned (design open question) | Part 2: left where it is, reported. | Moving a directory is the riskier choice; reporting loses nothing. |
| A repo in the middle of a rebase, merge, cherry-pick, revert or bisect | Part 2: left alone and reported, like uncommitted changes. Found with `git rev-parse --git-path` on `rebase-merge`, `rebase-apply`, `MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `BISECT_LOG`. | Nobody would want `sync` to move a repo a person is in the middle of editing. |
| Untracked files | Owner question 1 (changes what the clone ends up as). | |
| Debris of a failed clone | `vcs import` leaves a path behind when it fails (see "vcs on this machine"). `sync` removes that path, and only when it did not exist before the call. | Otherwise the next `sync` sees an existing path and never retries. |

### vcs on this machine (vcstool 0.3.0, tested 2026-11-18 on local repos)

This machine has `/usr/bin/vcs` 0.3.0 and no vcs2l. Results of running the behaviours:

- A `.repos` file read on stdin or with `--input`; a repo key with slashes (`grp/b`,
  `deep/er/c`) is cloned into nested directories; `url` as an absolute path and as
  `file://<path>` both clone; a `version` that is a branch checks out the branch, a tag or
  a commit leaves `HEAD` detached, no `version` leaves the default branch.
- One repo that fails does not stop the others in the same call; the call's exit status is 1.
  The output names the failure only in text, so it is not read.
- A failed repo leaves something behind: an unreachable url leaves an empty directory; a
  `version` that does not exist leaves a complete clone with that version not checked out
  (exit status 1).
- A second call with `--skip-existing` over those leftovers exits 0: the half-done repos
  would count as present. Hence the per-repo call and the removal of debris below.
- Flags before the path (`--recursive --shallow`) are accepted. A flag it does not know
  exits 2 and creates nothing.
- Existing repos, which part 1 never passes to it: a clean repo on another branch is
  switched to the manifest's branch by a plain `vcs import` (as the design says for vcs2l
  1.1.7) and is left alone by `--skip-existing`; a repo whose `origin` url differs is refused
  by a plain call (exit 1) and ignored by `--skip-existing` (exit 0). So the design's reason
  for using `git` on existing repos holds on 0.3.0, and `--skip-existing` is not a safe
  replacement.

### The `vcs import` invocation (part 1)

One call per missing repo, in layer order, repo order:

```
vcs import [<arguments after -- >...] <layer src directory>      stdin: one-repo .repos text
```

- `<layer src directory>` is `src/` for the unnamed layer, `<layer>/src/` for a named one,
  under the distro's directory when `layout` is `distro-dirs`. It is created first
  (`mkdir -p`).
- stdin is `repositories: {<key>: {type, url[, version]}}`, made by `output.repositories_yaml`
  (new; `output_files` is changed to call it, so the entry's shape is written once).
- No `--input`, no `--skip-existing`: the call is only made for a path that does not exist.
- Run with `subprocess.run(..., stdout=PIPE, stderr=STDOUT, stdin=<text>)`. Success is the exit
  status 0 and nothing else. The captured text is shown only for a repo whose call failed.
  It is never parsed. A password prompt of git or ssh goes to the terminal, which capture does
  not block.
- Failure of one repo is then known by which call failed. A failed repo's path is removed if it
  did not exist before the call (a `finally`, so a stop signal removes it too). The call is
  repeated on the next `sync` because the path is gone.
- An optional repo (from `Resolved.optional`) that fails is listed as skipped and does not
  change the exit status; a non-optional one is an error listed at the end, the other repos
  still being cloned, exit status 1.
- Cost: one `vcs` process per repo and no parallel clones. An 18-repo system (the owner's
  `simulator` role on `rolling`) is the size to expect. Parallel calls are a possible
  follow-up; not done, because prompts and output would interleave.
- After a successful call, the commit is read with `git -C <path> rev-parse HEAD` (exit status
  only, output is one sha).

### Module layout (new files under `src/repos_manifest/`)

1. `signals.py`: `Stopped` and the signals context manager, moved out of `cli.py` unchanged
   (not copied; `cli.py` imports them), plus `stop_exit(exc, message) -> int` holding the
   re-raise tail of `cli._stopped`, which `cli._stopped` also calls. A small first commit,
   covered by the existing resolve-signal tests.
2. `config.py`: `Refusal(ManifestError)` (a refusal carries its next step in its message);
   `Config` dataclass (`manifest`, `local_manifest`, `role`, `groups`, `layout`,
   `distros: dict[str, dict]`); `find_system(start) -> Path | None` (walks up for
   `.repos-manifest`, the same walk every command uses); `read_config(system) -> Config`
   (a `config.yaml` that is missing, is not a mapping, or lacks `manifest` or has a `layout`
   other than `flat` / `distro-dirs` is an error naming the file); `config_text(config)`;
   `NO_DISTRO = "_unnamed"` (the key that stands for "no distro"; starts with `_`, which no
   name can, as for the unnamed layer).
3. `layout.py`: pure functions of `(system, config, distro, layer)`, no disk access:
   `distro_dir`, `layer_src_dir`, `repo_path`, `resolved_dir`, `setup_file`,
   `paths_init_creates(...)`, and `distros_for(system, config, cwd, requested)`: the "which
   distro a command uses" rule (the named ones, else the distro whose directory `cwd` is
   inside, else all in the order of `distros`; a name the system does not record is an
   error).
4. `state.py`: `read_state(system) -> dict`, `put_distro_state(system, distro, repos)`: reads
   the whole file, replaces that distro's entry, writes the file with `atomic_replace`
   (a temporary file in the same directory, then `os.replace`). One distro's write leaves
   every other entry as it was; tested.
5. `tools.py`: `require_tools()`: the vcs and git check above; `import_repo(...)`; `head_commit(path)`.
   (Named `tools.py`, not `vcs.py`, since it holds git calls too.)
6. `locations.py`: `read_manifest(system, config, distro) -> Manifest`: the first of the
   distro's local copy (`local_manifest` inside the distro directory, when the file exists)
   and `config.manifest` taken from the system directory when relative. Warnings of the
   manifest are printed to stderr as `_load_new` does today (that function moves here, `cli`
   calls it).
7. `sync.py`: `sync_distro(system, config, distro, manifest, vcs_args) -> DistroResult`: the
   one function a distro's sync is made of, taking one distro so `add-distro` reuses it.
   Steps, in this order, and why:
   1. `resolve(...)`, then `write_output(resolved_dir, output_files(resolved))`. If resolving
      raised, nothing was written (that is `write_output`'s own guarantee, and nothing before
      it has changed anything). The error message begins "the manifest is what failed;
      nothing was changed".
   2. Create the distro directory, each layer's `src/`.
   3. For each repo in layer order: path exists: count it as present (and if
      `git rev-parse --verify -q HEAD` fails there, list it as "not a complete clone: remove
      it and run sync"; nothing is done to it). Path missing: `import_repo`.
   4. `finally`: `put_distro_state` with the old records of the distro plus the repos cloned
      in this call.
   5. If `setup.bash` of the distro does not exist, write the placeholder (below).
   6. Return which repos were cloned, present, failed, skipped (optional).
   Phase order for several distros: `sync` first reads and resolves every selected distro in
   memory (`read_manifest`, `resolve`) and only then calls `sync_distro` for each. In part 1 a
   failure in the first phase ends the run with exit status 1 and nothing changed for any
   distro; part 2 turns it into "reported for that distro, the others go on".
8. `init.py`: `run_init(args) -> int`: the refusals, the summary and question, the config
   step, then `sync_distro` per distro.
9. `cli.py`: parsers for `init` and `sync`, and two small `cmd_` functions that call
   `init.run_init` and `sync.run_sync`; the `--` arguments are what `argparse.REMAINDER`
   gives after `--`. `output.py`: `repositories_yaml` extracted; `write_output` takes an
   optional `marker_text` (default today's) so `init` can write `.repos-manifest/`'s marker
   in words that are true for it; `Selected` entries are used as they are.

### What `config.yaml` and `state.yaml` hold

`config.yaml` (written once by `init`; only the keys that apply):

```yaml
manifest: ../project11.manifest.yaml     # as given, taken from the system directory
role: simulator
groups: [ui]                             # only when --with was given
layout: distro-dirs                      # or flat
distros:                                 # absent when the manifest has no distros:
  rolling: {}
```

`local_manifest` is written when `--local-manifest <path>` is given (see "Could be cut").
`init` sets up the current directory, so `manifest` as given is relative to the system
directory, as the design says. `fetch_from` and `remotes` are not written (not built).

`state.yaml` (decided here, per distro):

```yaml
format: 1
distros:
  rolling:                  # _unnamed when the manifest has no distros
    repos:
      project11/core:       # the repo's key in the manifest
        layer: core         # _unnamed for the unnamed layer; the layer it was cloned into
        version: rolling    # the manifest's version when it was cloned; null when it named none
        commit: 3f2a9c...   # HEAD after the clone
```

Why this shape: the key is the manifest's own key, so part 2 matches a repo to its record
without a path; `version` is what part 2's rules compare against (the design: "The version is
what the rules compare against"); `commit` lets `status` show what changed since; `layer`
lets part 2 notice a repo given another layer (reported, not moved) without resolving the
previous manifest again. The distro is a key so one write replaces one entry and no other.
A missing `state.yaml` means no records; `state.yaml` that does not parse is an error naming
the file. Nothing else is read from it in part 1: present repos keep whatever record they have.

### The trees `init` creates

Flat, with layers `underlay` and `core` (unnamed layer empty), distro `jazzy`:

```
my_system/
  .repos-manifest/
    config.yaml  state.yaml
    resolved/  underlay.repos  core.repos  layers.txt  optional.txt  .repos-manifest-output
  setup.bash                 placeholder
  underlay/src/<repo keys>
  core/src/<repo keys>
```

Flat, no layers, no distro: `.repos-manifest/{config.yaml,state.yaml,resolved/_unnamed.repos,...}`,
`setup.bash`, `src/<keys>`.

`--distro-dirs`, with layers, `--distro jazzy --distro rolling`:

```
my_system/
  .repos-manifest/
    config.yaml  state.yaml
    resolved/jazzy/   <the resolved files>
    resolved/rolling/ <the resolved files>
  jazzy/    setup.bash   underlay/src/...   core/src/...
  rolling/  setup.bash   underlay/src/...   core/src/...
```

`--distro-dirs`, no layers: `<distro>/setup.bash` and `<distro>/src/<keys>`, a bare colcon
workspace. A layer with no repos for a distro gets no directory and no file (the resolver
already drops it). `build/ install/ log/` are made by `build` (issue 501), not here.
`resolved/` in `--distro-dirs` is `resolved/<distro>/`, one `write_output` per distro, which
the existing writer already allows (its parent is created, the other distro's directory is
not touched).

### `setup.bash` (placeholder in part 1)

The design makes `build` write `setup.bash`, sourcing the last built layer's setup file; the
Refusals table has `init` refuse when `setup.bash` exists. So `init` creates it, as a file that
does not claim a build exists:

```
# Written by repos-manifest init. Nothing is built here yet; `repos-manifest build` replaces this file.
echo "repos-manifest: nothing is built here yet" >&2
return 1 2>/dev/null || exit 1
```

It is created by `sync_distro` when it does not exist, never overwritten, so a `sync` that
finishes an interrupted `init` makes it too. `build` (issue 501) overwrites it. Owner
question 2 asks whether to write it at all.

### `init` step by step (part 1)

`repos-manifest init <manifest> [--role R] [--distro D]... [--distro-dirs] [--with G]...
[--local-manifest P] [--yes] [-- <vcs import arguments>]`

1. `find_system(cwd)`. Not found: go on. Found, `config.yaml` unreadable: the error that
   names that file (the design: `init` gives it, not the refusal). Found, readable: refusal 1.
2. Refusal 2 (several `--distro` without `--distro-dirs`): no manifest needed.
3. `load_manifest(path)`; its errors stand (a path that does not exist gets the "only a path
   is read in this version" hint when it contains `://`). Refusals 3 to 7 against
   `manifest.distros` and the flags, in the table's order, then `check_role_and_distro` for
   each distro (role, group and distro errors, as `resolve` gives them).
4. `resolve` each distro in memory (an error ends here; nothing is written).
5. Refusal 8: compute `paths_init_creates` for every distro (distro directories, layer
   directories, the unnamed `src/`, `setup.bash`, `.repos-manifest`), refuse on the first that
   `os.path.lexists`. A `.repos-manifest` that exists is refusal 1 or the config error, found
   in step 1.
6. Tools check (vcs, git): refusal if missing.
7. Print the summary, then for a flat system with a distro the `Layout:` line (not skipped by
   `--yes`), then ask (or `--yes`).
8. Write `.repos-manifest/` with `config.yaml` by `write_output(system/".repos-manifest",
   {"config.yaml": text}, marker_text=...)`. This is the point from which the system
   exists. `write_output` replaces it whole or not at all, so before this step nothing exists
   and `init` can be run again.
9. For each distro in the order given: `sync_distro(..., first=True)`.
10. Print, per distro, what was cloned, what failed, what was skipped (optional); if anything
    failed, "run `repos-manifest sync` to finish"; exit status 0 or 1 as decided above. A
    stop signal during step 9 prints "stopped; run `repos-manifest sync` to finish" and exits
    128+n (through `signals.stop_exit`).

Steps 1 to 7 change nothing on disk. Step 8 is one rename.

### What happens when `init` is interrupted

| Interrupted | State on disk | What the next command does |
|---|---|---|
| Steps 1 to 7, or the question declined | Nothing | `init` again |
| In step 8 | `write_output`'s guarantee: the previous state (none) or the new one, never neither; its leftovers are swept by the next run | `init` again, or (if the swap finished) `sync` |
| After step 8, before any directory | `.repos-manifest/config.yaml` only | `init` gives refusal 1 ("`sync`"); `sync` resolves, makes the directories and `setup.bash`, clones everything |
| In step 9 on a stop signal | Repos before the one in flight are cloned; the one in flight has its path removed by the `finally`; state holds the finished ones | `sync` clones the rest |
| In step 9 by `SIGKILL` | The one in flight may be a partial directory; state may lack finished repos | `sync` lists the partial one as "not a complete clone: remove it and run sync", clones the others; repos without a record keep none in part 1 and are handled by part 2's no-record rule |
| After step 9 | Complete | `sync` changes nothing |

### `sync` in part 1

`repos-manifest sync [--distro D]... [-- <vcs import arguments>]`, run anywhere in the system
(`find_system`; no system: an error that names where it looked and says `init`). Distro
selection by `distros_for`. Phase one, for every selected distro: `read_manifest`, `resolve`
(an error ends the run, nothing changed). Phase two, `sync_distro` per distro. On a system
whose repos all exist it rewrites the resolved files with the same content (swapped in whole),
creates nothing, clones nothing, changes no clone, adds no state, and prints "N repos are
present and were not touched; updating them is not built yet". Part 2 replaces that sentence
with the update rules. Step 1 of the design's `sync` (update the clone the local manifest is
in) is part 2.

### Refusals of `init`: the table rows built and the test for each

All tests: run `init` in an empty directory (or one with one unrelated file), assert the exit
status 1, the message holds the row's next step, and `snapshot(dir)` taken before equals the
one after (relative path, file type, content hash, mode; no mtimes).

| # | Condition | Test |
|---|---|---|
| 1 | A system is set up here or above | `init` twice; and from a subdirectory of a set-up system; the message names `sync`, and for a `distro-dirs` system also `add-distro <name>`, as the design's table says (the design's "What is built" says `add-distro` is not built yet) |
| 1b | `.repos-manifest/` with no readable `config.yaml` | The error names the file, not the refusal |
| 2 | Two `--distro`, no `--distro-dirs` | |
| 3 | `--distro-dirs`, manifest without `distros:` | |
| 4 | No `--distro`, manifest with `distros:` | |
| 5 | `--distro`, no `--distro-dirs`, manifest without `distros:` | |
| 6 | `--distro` not listed, flat | message holds the resolver's error text |
| 7 | `--distro` not listed, `--distro-dirs` (second distro unlisted too) | |
| 8 | A path `init` would create exists: `src`, a layer directory, a distro directory, `setup.bash` (one test each, over flat and `distro-dirs`) | |
| 9 | No `vcs` on `PATH` (the test gives `PATH` an empty directory) | |
| 10 | stdin not a terminal and no `--yes` | |
| 11 | Question answered `n` | nothing was created |
| 12 | Order: a case that triggers two rows gets the earlier (1 before 2; 4 before 8) | |

### Tests

Files under `tools/repos-manifest/tests/`: `helpers.py` (not collected; imported), then
`test_system_layout.py` (pure, no disk), `test_config.py`, `test_state.py`,
`test_vcs_behaviours.py`, `test_init_refusals.py`, `test_init.py`, `test_sync_first.py`,
`test_interrupted.py`, `test_signals.py` (the moved code keeps its existing tests).

`helpers.py`: `make_remote(tmp, name, branches={"main": [...], "dev": [...]}, tags=...)` builds
a real git repository with `git init -b main` and commits (identity from the
`GIT_AUTHOR_*`/`GIT_COMMITTER_*` environment variables set in a fixture, so no global git
config is read or written), `write_manifest(tmp, ...)`, `snapshot(path)`. A test that needs a
failing remote points a `url` at a directory that is not a repository.

**Remotes**: local git repositories in `tmp_path`, never the network. The manifest's `url`
is the absolute path of the remote directory (for example `/tmp/pytest-.../remotes/core`).
`manifest.py`'s `url()` accepts "an absolute path on the local disk" (the `url.startswith("/")`
branch) and `file://` (in `_URL_SCHEMES`); vcstool 0.3.0 clones both (tested). Tests use the
plain absolute path, and one test uses `file://` to prove both.

**No `os` patching**: failure injection is a stub `vcs` executable (a shell script in a
`tmp_path/bin` placed first on `PATH`, which exits 1 for a url the test names and otherwise
runs the real `/usr/bin/vcs`), or a url that is not a repository. A stop is simulated by
`monkeypatch.setattr(repos_manifest.sync, "import_repo", ...)` raising `Stopped` (our own
function, not an `os` function reached through `pathlib`). `SIGKILL` cannot be tested in
process; its state is built by hand (a directory with `git init` and no commit) and `sync`
is run on it.

**vcs in CI**: the tests that need `vcs` carry `needs_vcs = pytest.mark.skipif(shutil.which("vcs") is None, ...)`. The `validate-repos-manifest` job does not install `vcs`, so
they would be skipped there; fixing that is a CI change (owner question 4). A skip in CI
would be reported, not hidden, in the PR description.

Tests of part 1 (names are the behaviour):

- `test_vcs_behaviours.py`: the "vcs on this machine" list above, one test each, on the
  installed `vcs` (these are what the design relies on, run on whatever tool is installed, so
  they pass on vcstool 0.3.0 and vcs2l): one failing repo gives exit 1 and the others are
  cloned; unreachable url leaves an empty directory; missing version leaves a clone; nested
  keys; branch vs tag vs commit; passthrough flags; the existing-repo cases (branch switch
  by a plain call, url refusal) that justify `git` in part 2.
- `test_system_layout.py`: the five trees above as `paths_init_creates` results for flat/no
  layers, flat/layers, distro-dirs/no layers, distro-dirs/layers, two distros;
  `distros_for` from the top, from inside a distro directory, with `--distro`, with a name
  not recorded.
- `test_config.py`: round trip; each unreadable `config.yaml` error names the file; relative
  `manifest` taken from the system directory when a command runs from a subdirectory.
- `test_state.py`: `put_distro_state` leaves the other distro's entry byte-identical; a
  missing file is empty; one that does not parse names the file.
- `test_init.py`: first `init` of each of the five trees (against real local remotes), with
  the repos at the right paths, on the right branch/tag/commit, `state.yaml` per distro
  holding key, layer, version and commit equal to `git rev-parse HEAD`, `config.yaml`,
  `resolved/` equal to what `resolve` writes, placeholder `setup.bash` that exits non-zero
  when sourced and prints nothing on stdout; `--with` and `--role`; `--` argument
  (`--shallow` gives a shallow clone, checked with `git rev-parse --is-shallow-repository`);
  an optional repo whose url is not a repository is skipped, listed, exit 0, and not in
  state; a non-optional one is listed as an error, the others are cloned, exit 1;
  a failed repo leaves no path behind (and a second `sync` after the remote is fixed clones
  it); the summary for one and for two distros; the `Layout:` line is printed with `--yes`.
- `test_sync_first.py`: `sync` after `init` changes nothing (`snapshot` equal); `sync` adds a
  repo added to the manifest (cloned, state gains it, the others' records are untouched);
  `sync` from a subdirectory and from inside a distro directory; `--distro` for one of two
  distros leaves the other's tree and state byte-identical; a `--distro` the system does not
  record is an error, flat system included; **a failed resolve changes nothing** (manifest
  changed to name a missing role, then to be unparsable: exit 1, message says the manifest is
  what failed, `snapshot` equal); a repo that exists and is on another branch with a local
  commit and a dirty file is unchanged (`snapshot_repo` equal) after `sync`; the local copy of
  the manifest wins once it exists (if `--local-manifest` is kept).
- `test_interrupted.py`: the interruption table: stop raised after the config step (config
  only, then `init` refuses, `sync` finishes: equals an uninterrupted `init`'s tree); stop
  during a clone (path removed, earlier repos cloned and recorded, `sync` finishes); a partial
  directory (`git init`, no commit) is listed and untouched, other repos cloned.
- The existing `resolve` tests stay green; a test that `repos-manifest --help` lists `init`
  and `sync`.

Python: nothing newer than 3.10 (no `Path.walk`, `shutil.rmtree(onexc=)`, `tomllib`,
`datetime.UTC`; use `os.walk`, `onerror`); CI runs 3.10 and 3.14. No hardening against inputs
nobody writes: `config.yaml` and `state.yaml` are checked only for what the code reads; no
check for a hostile `state.yaml`.

### By-hand acceptance for the owner (on this machine)

His draft manifest has no `base` (checked: no top-level `base` key), so a file path serves.
For `--role simulator --distro rolling` it resolves to 18 repos in six layers (underlay,
core, platforms, sensors, simulation, ui), none of them optional for that role. Its urls are
GitHub urls, so this step uses the network and the ssh key where a url is an ssh url. A
copy is made so the scratch file stays where it is:

```
cd /home/roland/agent_workspace/worktrees/workspace/issue-workspace-500
python3 -m venv ~/p11-venv && ~/p11-venv/bin/pip install -e tools/repos-manifest
mkdir -p ~/p11-test && cd ~/p11-test
cp /home/roland/agent_workspace/.agent/scratchpad/project11-manifest-draft/project11.manifest.draft.yaml ./project11.manifest.yaml
~/p11-venv/bin/repos-manifest init ./project11.manifest.yaml --distro-dirs --distro rolling --role simulator
find . -maxdepth 3 -not -path './.git*' | sort | head -60
cat .repos-manifest/config.yaml .repos-manifest/state.yaml | head -40
source rolling/setup.bash; echo "exit status $? (expected 1: nothing is built yet)"
```

Then the second-run and local-work check:

```
~/p11-venv/bin/repos-manifest sync                 # prints the repos as present and untouched; changes nothing
cd rolling/core/src && ls                          # pick any repo, say <repo>
cd <repo> && echo local > local-note.txt && git commit --allow-empty -qm "local commit" && echo dirty >> README.md
git status --short; git log --oneline -2 > /tmp/p11-before.txt
cd ~/p11-test && ~/p11-venv/bin/repos-manifest sync
cd rolling/core/src/<repo> && git status --short && git log --oneline -2 | diff - /tmp/p11-before.txt && echo "unchanged"
```

(The venv install is at `~/p11-venv`; the commands are pasted into the pull request with their
output.) A failed-first-sync check: `chmod -w` is not used; instead run
`repos-manifest init` from a directory whose manifest copy names a repo url that does not
exist, then fix the url and run `sync`.

### Could be cut from part 1 if it is too large

In this order: (a) `--local-manifest` and the local-copy read in `locations.py` (set up by
hand instead; part 2 needs it for step 1); (b) the placeholder `setup.bash` (owner question
2; then `setup.bash` is neither written nor refused); (c) the `-- <vcs import arguments>`
pass-through; (d) the "not a complete clone" listing. Not cut: the refusals, state, the
per-repo import with debris removal, the failed-resolve test, the interrupted-init tests,
`--distro-dirs`.

### Part 2: `sync` against clones that exist (a separate pull request)

New `update.py` (the git operations; every one a `git` call, whose exit status is the
result), and `sync.py` changed to call it for a present repo and to do step 1 and the
manifest-against-config check. One rule per row, each with the test that proves it (real
local repos; the helper `snapshot_repo` compares `HEAD`, the branch, `git write-tree`, `git
status --porcelain=v2` and the hash of every file; no test accepts a deleted file or a reset
branch):

| Rule (design) | Test |
|---|---|
| Re-run on the installed `vcs`: a plain call switches a clean repo to the manifest's branch, a changed url is refused, `--skip-existing` neither (done in part 1's `test_vcs_behaviours.py`) | already in part 1 |
| A repo on its recorded version, nothing local: fetched and fast-forwarded; moved to a new version when the manifest names one (branch, tag, commit) | a commit added on the remote follows; `version` changed in the manifest moves; state updated |
| A repo a person moved to another branch: left alone, reported | `snapshot_repo` equal; message names the repo and the branch it is on |
| Uncommitted changes (tracked): left alone, reported | edited tracked file survives, byte-identical |
| Untracked files: owner question 1; with the recommendation: they do not stop an update and are never touched; if git would overwrite one the update stops for that repo and the repo is reported as it was | an untracked file survives an update; one that collides with an incoming file leaves the repo unchanged |
| Mid-rebase, merge, cherry-pick, revert, bisect: left alone, reported | one test per state, built with `git` on a conflict |
| Commits not on `origin`, manifest changes the version: never switched, reported | local commit still on the branch; `HEAD` unchanged |
| Commits not on `origin`, still on the manifest's branch: fetched, commits put back on top (`git rebase`) | remote gains a commit, local commit is on top of it afterwards |
| The rebase does not go on cleanly: repo put back as it was, reported | conflicting remote and local commit: `snapshot_repo` equal before and after, including the index |
| A repo no longer in the manifest: left on disk, reported | directory and files survive; state keeps the record |
| A repo with no record: recorded and followed if on the manifest's version, moved by a person if not | delete `state.yaml`, run `sync`: one repo followed, one reported |
| A repo's url changed in the manifest: owner question 3; with the recommendation: `origin` is set to the manifest's url, then the repo is updated by the rules above | `git remote get-url origin` after |
| A repo given another layer: left where it is, reported (decided above) | directory not moved |
| Step 1: the clone the local manifest is in is updated by these rules; a developer editing the manifest gets the edited manifest | dirty manifest clone: left, its edited text is what is resolved |
| The manifest read no longer lists the distro, or lists none; a flat system whose manifest gained `distros:`; the manifest lacks the role or a group: reported for that distro, nothing of it moved, the others go on, exit 1 | two-distro `--distro-dirs` system; the other distro's tree and state byte-identical |
| The manifest lists a distro the system does not record: nothing happens | no new directory |
| An optional repo that cannot be fetched is skipped and listed every time; another repo that cannot be fetched is an error | in part 1 for missing repos; part 2 adds it for a present repo whose `fetch` fails |
| Writing one distro's state leaves the other's as it was | in part 1; repeated with updates |

Part 2's design edits: the `sync` section is made to say exactly what the code does (the
decisions above), the "Open questions" lose the entries decided here.

## Files to Change

Part 1:

| File | Change |
|---|---|
| `tools/repos-manifest/src/repos_manifest/signals.py` | New: `Stopped`, the signals context manager, `stop_exit` (moved from `cli.py`) |
| `tools/repos-manifest/src/repos_manifest/config.py` | New: `Refusal`, `Config`, `find_system`, `read_config`, `config_text`, `NO_DISTRO` |
| `.../layout.py` | New: paths, `paths_init_creates`, `distros_for` |
| `.../state.py` | New: `read_state`, `put_distro_state`, `atomic_replace` |
| `.../tools.py` | New: `require_tools`, `import_repo`, `head_commit` |
| `.../locations.py` | New: `read_manifest` (the one place a manifest is read from its location) |
| `.../sync.py` | New: `sync_distro`, `run_sync` |
| `.../init.py` | New: `run_init`, the refusals, the summary |
| `.../cli.py` | `init` and `sync` parsers and dispatch; imports from `signals.py` and `locations.py` |
| `.../output.py` | `repositories_yaml` extracted and used by `output_files`; `write_output(marker_text=)` |
| `tools/repos-manifest/tests/*` | The files listed under "Tests" |
| `tools/repos-manifest/docs/design.md` | See "Design documents" |
| `tools/repos-manifest/README.md` | Usage of `init` and `sync`; requires `vcs` and `git`; says what is not built |
| `tools/repos-manifest/docs/roadmap.md`, `docs/manifest/roadmap.md` | The `init and sync` line says part 1 is done, part 2 is not; the issue for part 2 and for `add-distro` named |
| `.agent/knowledge/build_and_test.md` | The line that says nothing fetches yet; the tests' need for `git` and `vcs` |
| `.github/workflows/validate.yml` | Only with owner approval (question 4) |

Part 2: `update.py` (new), `sync.py`, tests listed above, `design.md` (`sync`, "Open questions", "What is built"), `README.md`, the roadmaps.

## Prior Art

- The workspace's own adapter (`.agent/project_types/ros2_colcon/adapter.sh`, around line
  1340): `vcs import --skip-existing "$layer_dir/src" < "$repos_file"` per layer, failing the
  layer on a non-zero status. Taken: the stdin form, `vcs` only for missing repos, a status
  check and a check for the tool before any remote is touched. Rejected: one call per layer
  with `--skip-existing`: on this machine's vcstool, a failed repo leaves a path that
  `--skip-existing` then counts as present, and a failure cannot be traced to a repo without
  reading text.
- `output.write_output`: reused for `.repos-manifest/` (config step) and for each distro's
  resolved files; no second directory writer. `state.yaml` is one file replaced in place,
  which `write_output` (a directory writer) does not do; `atomic_replace` is eight lines.
- `git pull --rebase` (the design's wording for the rebase rule), part 2: `git fetch` then
  `git rebase`, with the repo restored by `git rebase --abort` and a reset to the recorded
  `HEAD` when the rebase stops; not `git pull`, whose merge behaviour depends on the user's config.
- vcs2l is a maintained fork of vcstool with the same command line; the tool accepts either.

## Serves

Goal: "one system directory set up and kept in line from one manifest" (the project-setup
path of the workspace's manifest design), under `tools/repos-manifest/docs/design.md#the-system-directory`,
`#setting-up-with-init`, `#refusals` and `#sync`, and root `docs/manifest/design.md` (the
project-setup path; the "failed resolve changes nothing" ask under "What the tool has to give").
Anchors are 508's.

## Design Picture

The design of the tool changes, in the same pull request as the code (ADR-0017), on top of
508's text. The root design `docs/manifest/design.md` does not change: what crosses the
boundary (the tool sets up a directory from a manifest) is as it says.

### Design documents: what each part changes

Part 1, `tools/repos-manifest/docs/design.md`:

- "The system directory" and "More than one distro": the `setup.bash` that `init` makes
  (placeholder, replaced by `build`); `.repos-manifest/` gets `state.yaml` when the first state
  is written, not at `init`.
- "Setting up with init": what the summary holds and prints for several distros; the question
  and its rule for a non-terminal; the order of the steps; what an interruption leaves
  (the table above in prose).
- "Refusals": a row for `vcs` or `git` not found (for `init` and `sync`); a sentence that the
  `--manifest-ref` hint of rows 6 and 7 is part of the message once the git form is read.
- "Where the resolved files and state go": the `state.yaml` shape above.
- "sync": the per-repo `vcs import` call, the debris rule, the two-phase order, the exit
  status rule, the result of the tests on vcstool 0.3.0 next to the vcs2l 1.1.7 ones, and a
  sentence that until part 2 a present repo is not touched (in the status of the part, not in
  the rules).
- "What the tools rely on": `vcs` from vcstool or vcs2l; no Python dependency.
- "Open questions": remove "What `init` prints for several distros", "What a distro's
  manifest that lacks the system's role or one of its groups gives" (init), "`sync`'s exit
  status when one distro is reported and the others go on". "How a distro is removed" stays.
- "What is built": `init` and `sync` for a manifest given as a path, clone only;
  not built: updating existing clones, `add-distro`, the git and URL forms.
- The tool's documents do not mention the workspace or its adapter. The one exception today
  is none: no sentence is added that does.

Part 2: "sync" (rules as decided, untracked files and mid-rebase states included), "Open
questions", "What is built".

**How the branch gets 508's text**: 508 is merged first, then `feature/issue-500` merges
`main` (`git merge origin/main`), and the edits above are made on that. The plan, progress
file and the code of part 1 do not touch 508's files except `design.md`, so the merge has
nothing to conflict with before the design edits; the design edits are the last commit of the
part. 508's edits are never copied by hand.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Design edited in the same change, on top of 508; "What is built" says what is |
| Only what's needed | Parts: the owner's aim (clone) first; `add-distro` separate; lock, time limits, commit-named manifest, `build`, `status`, `freeze` out |
| A change is only done when its consequences are done | README, roadmaps, build_and_test, design, CI question |
| Verify before claiming | vcs behaviours were run on vcstool 0.3.0 and are re-run by tests on whatever `vcs` is installed; each claim in the PR names the command |
| Ask about what matters | Only what changes a person's directories or clones is asked |
| Never discard work | Part 1 changes no existing clone and deletes only a path its own failed call made; part 2's tests compare repos byte for byte |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0017 | Yes | Design edits in the same change |
| ADR-0022 | Yes | The work is inside the part; Serves cites the part's design |
| ADR-0009 | Yes | No bare `pip install`; the by-hand venv is in the home directory; tests use `.venv` |
| ADR-0013 | Yes | `## Plan Authored` entry |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `cli.py` moves `Stopped` and the signal context | existing resolve signal tests | Yes (they must pass unchanged) |
| `output_files` calls `repositories_yaml` | `test_output.py` expectations | Yes (output unchanged) |
| `write_output(marker_text=)` | a test for the new keyword; default unchanged | Yes |
| The tool's README, design, roadmaps | `docs/manifest/roadmap.md` | Yes |
| The tests need `vcs` | CI job installs it | Owner question 4 |
| `repos-manifest --help` | the workspace's `validate.yml` runs it | Yes, still passes |

## Out of Scope

- `add-distro` (own issue; shares `sync_distro`, which takes one distro).
- The git and URL forms of the manifest location and of `base`: they arrive with part 2 of
  issue 498. Once its fetcher exists, `locations.read_manifest` reads the mapping form and a
  distro's `manifest_version`, and `init` gains `--manifest-ref` and `--manifest-path`; the
  rest of `init` and `sync` is unchanged.
- The lock against two runs; time limits on fetches (`vcs import --retry` is left at its
  default, no limit is set); a manifest named by a commit; `build`, `status`, `show`,
  `freeze`; `fetch_from` and `remotes`; removing a distro.

## Open questions for the owner

Each changes what ends up in a directory or clone. Reply with a number and a letter.

1. **Untracked files in a repo when `sync` updates it (part 2).**
   a. They do not stop an update and are never touched; if git would overwrite one, that repo
      stays as it was and is reported. Cost: a repo with scratch files still updates.
      Recommended.
   b. Treat them like uncommitted changes: the repo is left alone and reported. Cost: build
      leftovers in a repo stop it updating until removed.
2. **`setup.bash` right after `init`, before anything is built.**
   a. `init` writes a stub that prints "nothing is built here yet" and fails when sourced;
      `build` replaces it. Cost: one file you did not build. Recommended: the design has
      `init` refuse a directory with a `setup.bash`, and sourcing gets a clear message.
   b. `init` writes none; `build` writes it. Cost: sourcing it says "no such file".
3. **A repo's `url` changed in the manifest (part 2).**
   a. `sync` sets the clone's `origin` to the new url, then updates it by the usual rules.
      Recommended. Cost: a mistaken url in the manifest repoints clones.
   b. It reports the difference and leaves the clone alone. Cost: you change `origin` by hand.
4. **CI.** The repos-manifest test job has no `vcs`, so the clone tests would be skipped
   there. Add `pip install vcs2l` (or `vcstool`) to that job in `validate.yml`? This is a CI
   change, so it needs your yes. Recommended: yes.

## Estimated Scope

Part 1: about 650 lines of code in the nine modules above (`init.py` and `sync.py` about 150
each, the rest under 100), about 900 lines of tests, about 150 lines of documentation: one
pull request, the largest of the three; the cut list above is how to shrink it. Part 2:
about 350 lines of code (`update.py` 250), about 700 lines of tests, 80 lines of
documentation. `add-distro`: its own issue, small once `sync_distro` exists.
