# Plan: repos-manifest: `init` and `sync` set up and update a system directory

## Issue

https://github.com/rolker/agent_workspace/issues/500

The issue's own text is stale in the places the `## Issue Review` entry in `progress.md` lists;
that table stands in for it. Design basis: pull request 508 (issue 495, branch
`origin/feature/issue-495`, still open when this plan was revised; its design text was read
from that branch). A change to 508 changes only the part of this plan that cites it.

This is the second version of the plan. It answers the `## Plan Review` entry (eleven findings)
and the `## Checkpoint` after it. Part 1 is much smaller than the first version; what was cut is
listed under "Cut from part 1 and where it went".

## Context

`tools/repos-manifest` on this branch has the resolver (`manifest.load_manifest`,
`selection.resolve`, `selection.check_role_and_distro`) and `output.write_output`, the
whole-or-nothing directory writer. Nothing clones or updates anything, and there is no system
directory. This issue builds `init` and `sync`.

The owner wants first, in his words, to "test the tool to build the project directory tree" for
his project on this machine, on ROS Rolling. So the work is in parts, one pull request each:

| Part | What | Risk |
|---|---|---|
| 1 | `init`, and a first `sync` that clones what is missing and touches nothing that exists | Low: it makes directories and clones; it never changes an existing clone |
| 2 | `sync` against clones that exist: follow, leave alone, rebase, repo removed, per-distro reports, optional repos | High: a person's work is at risk; own PR, own tests |
| (3) | `add-distro`: its own issue, proposed by the host | Reuses part 1's one-distro function |

Part 1 can land and be used before part 2 exists.

### What part 1 reads from 508's design text

"The system directory" and `config.yaml`; "More than one distro" and its trees; "Setting up
with init"; "Refusals"; "Where the resolved files and state go"; "Which distro a command
uses"; the `sync` section; "What the tools rely on"; "What is built"; "Open questions". From the
specification, "Reading a manifest before using it": the check on the real destination. The
workspace's ask "a failed resolve changes nothing" (`docs/manifest/design.md`, "What the tool
has to give") is in this issue; its other asks are not.

### What part 1 builds on (on this branch)

| Module under `tools/repos-manifest/src/repos_manifest/` | Used |
|---|---|
| `manifest.py` | `load_manifest(path, source)`: a file path only, refuses `base`; `Manifest.distros` |
| `selection.py` | `resolve(...) -> Resolved` (layers in order; each repo's `key`, `type`, `url`, `version`, `optional`); `check_role_and_distro` is called by `resolve` and not again |
| `output.py` | `write_output(out, files, on_replaced)` for each distro's resolved files; `output_files(resolved)`; `_process_has_ended(pid)` (imported for the dead-process test). Not changed |
| `yamlload.py` | `ManifestError` |
| `cli.py` | `Stopped` and `_signals_end_the_run`, moved to `signals.py` |

The existing `resolve` command is unchanged. Run inside a system directory it still needs
`--manifest` and `--out` and does not write to `.repos-manifest/resolved/`; the design's "What
is built" says so.

## Approach

### Mechanism decisions (one line of reason each)

| Question | Decision | Why |
|---|---|---|
| Where a manifest comes from | A local file path, `init`'s first argument. A value containing `://` that is not a file gets a message saying only a file path is read in this version. Later the git and URL forms come with issue 498 part 2's fetcher: only `system.read_manifest` grows (the mapping form of `manifest`, `manifest_version`) and `init` gains `--manifest-ref` and `--manifest-path`. | The checkpoint: no second fetcher. One function reads a manifest. |
| What `init` prints | A summary built from `Resolved`: the manifest, role, groups, layout, and per layer each repo's key, version, url and whether optional. With several distros, one block per distro in the order of `--distro`. Replaced by what `show` prints when issue 499 lands. | `show` does not exist. |
| The question | `--yes` skips it. Without `--yes`, `init` reads one line; stdin not a terminal is a refusal that says to give `--yes`. Any reply but `y` or `yes` ends with "nothing was created", exit 1. | A script without `--yes` must not hang or go on. |
| A role or group a distro's manifest lacks | In part 1 every distro reads the one file, so `resolve` refuses it at `init`, as for the `resolve` command. In part 2 `sync` reports it for that distro like "the manifest no longer lists the distro". | One rule. |
| `sync` exit status when one distro is reported and the others go on | 1 when any distro was reported and skipped or any non-optional repo failed; 0 otherwise. Repos left alone and optional repos skipped are listed and exit 0. | A script must see a distro that did not sync. |
| Removing a distro | Out of scope; stays an open question in the design. | #495 deferred it. |
| `vcs` and `git` required | Refusal before anything is created: both found by `shutil.which`, and `vcs --version` exits 0 (its output is not read). Checked after the table's rows, so those tests do not need `vcs`. | `vcs 0.3.0` prints a warning on every call; no output of `vcs` is parsed. |
| Two runs at once | No lock in part 1 (out of scope). Two runs each clone into their own temporary directory; the one that finds the destination already there when it comes to rename reports "appeared meanwhile, left as it is", and removes only its own temporary directory. Neither run removes the other's temporary directory (its process is running). `state.yaml` can lose one of two simultaneous updates; the design says so next to its "two runs" sentence. | Nothing either run deletes is the other's. |
| Errors on disk | `run_init` and `run_sync` turn an `OSError` into an error naming its path and reason (`<filename>: <strerror>`), exit 1. `cli.main`'s catch-all shows only the type. | A read-only or full disk must say where. |
| A layer change of a cloned repo; a repo in the middle of a rebase, merge, cherry-pick, revert or bisect | Part 2. The first is an owner question there; the second is left alone and reported, like uncommitted changes. | Needs existing-clone rules. |

### Cloning one missing repo: exactly how

Notation: `S` is the layer's `src/` directory (`src/` for the unnamed layer, `<layer>/src/` for
a named one, under `<distro>/` with `--distro-dirs`). `K` is the repo's key; it may contain
`/`. `P = S/K` is the repo's place. `T` is a temporary directory.

The one-repo text is built from the layer's resolved `.repos` text that `output_files` already
makes (the entry's shape stays written in one place, `output.py`, and `output.py` is not
changed): load it with `yaml.safe_load`, take `repositories[K]`, dump
`{"repositories": {K: <that entry>}}`. It has `type`, `url` and `version` when the manifest gave
one, nothing else.

For each repo of the layer, in order:

1. If `os.path.lexists(P)`: present; nothing is done to it (a link, a file, a clone or a
   person's directory alike). Part 1 does not look inside.
2. Destination check (below). If it fails the repo is an error: nothing is made, the others go on.
3. `T = tempfile.mkdtemp(prefix=".repos-manifest-tmp-<pid>-", dir=S)`. `S` is made first
   (`os.makedirs`) after the check has passed for it.
4. Run `vcs import T` with the one-repo text on stdin, stdout and stderr captured together.
   `vcs` clones into `T/K`, making any directories of `K` inside `T`. Success is exit status 0
   and nothing else; the captured text is shown only for a repo whose call failed and is never
   read. A prompt of git or ssh goes to the terminal.
5. On exit status 0: the destination check again (the disk may have changed during the clone);
   if `os.path.lexists(P)` now, report "appeared meanwhile, left as it is" and go to 7;
   `os.makedirs(P's parent, exist_ok=True)` (this is where the directories of a key such as
   `grp/sub/c` are made, `S/grp/sub`); `os.rename(T/K, P)`. Only the repo's own directory is
   renamed; `T/grp` and the rest stay in `T`. The commit is then read with
   `git -C P rev-parse HEAD` (exit status and one sha) for `state.yaml`.
6. On any other exit status: the repo is a failure (optional: skipped and listed, exit status
   unchanged; any other: an error, exit status 1). Nothing but `T` is touched.
7. `finally`, whatever happened, including a stop signal: remove `T` (`shutil.rmtree`, after
   making its contents writable, as `output.py` does). `T` is the only path this call removes;
   it was made in step 3 by this call.

`os.rename` replaces an empty directory at `P`; step 5's `lexists` check is why it never does.
The window between the check and the rename is the one two runs at once can hit (see the table
above); it ends in "appeared meanwhile" or in a refused rename (a non-empty target), reported
by the `OSError` rule, never in a removal.

`subprocess.run` kills `vcs` when an exception, a stop signal's `Stopped` included, reaches it,
so `T` is not removed under a running clone.

**A temporary directory left by a killed run.** Name pattern, one for every temporary this tool
makes (directories and files alike): `^\.repos-manifest-tmp-(\d+)-[a-z0-9_]{8}$`, the form
`tempfile.mkdtemp` and `mkstemp` give for that prefix, the number being the process that made
it. `sweep_temporaries(directory)` lists the entries directly in `directory` and removes one
only when all three hold: its name matches the pattern; it is not a symbolic link; the process
number in its name has ended (the rule `output.py` has, `_process_has_ended`, which is also
true for this run's own number before this run has made any). It never looks at any other
entry and never descends into a directory it does not remove. A temporary of a running process
is left alone. `sync_distro` sweeps `.repos-manifest/`, the distro's directory (the system
directory when flat) and each layer's `src/` before it makes anything in them; `init` sweeps
the system directory after its refusals and before it makes `.repos-manifest/`.

**The destination check** (the spec's "checks this again on the real destination before it
writes"): `check_destination(system_dir, parts, key)`, where `parts` is the layer's `src/` path
below the system directory as the layout gives it. It holds when both
`os.path.realpath(S) == os.path.join(os.path.realpath(system_dir), *parts)` and
`os.path.realpath(parent of P) == os.path.join(os.path.realpath(S), *key.split("/")[:-1])`.
`realpath` works on a path whose tail does not exist yet, so the check is made before any
directory is made, and again at step 5. A link on the way (a layer directory, `src/`, or a
directory of the key that points elsewhere) therefore refuses the repo; two names the disk
treats as one cannot both pass, because the first clone makes the place and step 1 or the
`lexists` check of step 5 stops the second. An existing destination is never written into.
The message names the repo and the path.

### Modules (new files under `src/repos_manifest/`)

1. `signals.py`: `Stopped`, the signals context manager and a `stop_exit(exc, message)` holding
   the re-raise tail of `cli._stopped`, moved out of `cli.py`, not copied. Small first commit,
   covered by the existing resolve tests.
2. `system.py`: `Refusal(ManifestError)`; `Config` and `read_config`/`config_text`;
   `find_system(start)`; `NO_DISTRO = "_unnamed"`; the pure path functions (`distro_dir`,
   `layer_src_parts`, `resolved_dir`, `setup_file`, `paths_init_creates`) and `distros_for(...)`
   (the "which distro a command uses" rule: the named ones, else the distro whose directory `cwd`
   is inside, else all in the order of `distros`; an unrecorded name is an error);
   `read_state`/`put_distro_state`; `replace_file(path, text)` (a temporary file in the same
   directory, then `os.replace`, used for `state.yaml` and `setup.bash`); `read_manifest(system,
   config)`, which today calls `load_manifest` on the path and prints its warnings to stderr as
   `cli._load_new` does (that function moves here; `cli` calls it); `reporting_oserror()`, the
   context manager that turns an `OSError` into the error above. Under 250 lines.
3. `sync.py`: `require_tools()`, `sweep_temporaries`, `check_destination`, `clone_repo` (the seven
   steps above), `sync_distro(system, config, distro, manifest) -> DistroResult` (the one function
   a distro's sync is made of; it takes one distro so `add-distro` reuses it), `run_sync`.
4. `init.py`: `run_init`, the refusals, the summary and question, the config step, then
   `sync_distro` per distro.
5. `cli.py`: the `init` and `sync` parsers and two small `cmd_` functions; it imports from
   `signals.py` and `system.py`.

`sync_distro`, in this order:

1. `resolve(...)`, then `write_output(resolved_dir, output_files(resolved))`. If resolving raised,
   nothing was written (`write_output`'s own guarantee; nothing before it changed anything); the
   message begins "the manifest is what failed; nothing was changed".
2. Sweep (above); make the distro directory and each layer's `S` (after the destination check
   for `S`).
3. For each repo in layer order: `clone_repo`.
4. `finally`: `put_distro_state` with the distro's old records plus the repos cloned in this call.
5. If the distro's `setup.bash` does not exist, `replace_file` it (text below).
6. Return which repos were cloned, present, failed, skipped (optional).

For several distros `sync` first reads and resolves every selected distro in memory and only
then calls `sync_distro` for each: in part 1 a failure in that first phase ends the run, exit
status 1, with nothing changed for any distro (part 2 turns it into "reported for that distro,
the others go on").

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

`local_manifest`, `fetch_from` and `remotes` are not written (not built; see below). A
`config.yaml` that is missing, not a mapping, lacks `manifest` or has a `layout` other than
`flat` or `distro-dirs` is an error naming the file.

`state.yaml`, per distro (the inner shape is not fixed by the design; decided here):

```yaml
format: 1
distros:
  rolling:                  # _unnamed when the manifest has no distros
    repos:
      project11/core:       # the repo's key in the manifest
        layer: core         # _unnamed for the unnamed layer
        version: rolling    # the manifest's version when cloned; null when it named none
        commit: 3f2a9c...   # HEAD after the clone
```

`version` is what part 2's rules compare against; `commit` lets `status` show what changed since;
`layer` lets part 2 notice a repo given another layer without reading the previous manifest. One
write reads the whole file, replaces one distro's entry and swaps the file in with
`replace_file`; every other entry is as it was, so a run stopped between two distros leaves the
first distro's entry complete. A missing file means no records; one that does not parse is an
error naming it. `state.yaml` is made at the first state write, not at `init`.

### The trees `init` creates

Flat, layers `underlay` and `core`, distro `jazzy`: `.repos-manifest/{config.yaml, state.yaml,
resolved/{underlay.repos, core.repos, layers.txt, optional.txt, .repos-manifest-output}}`,
`setup.bash`, `underlay/src/<keys>`, `core/src/<keys>`. Flat with no layers and no distro:
`.repos-manifest/{config.yaml,state.yaml,resolved/...}`, `setup.bash`, `src/<keys>`.

`--distro-dirs`: `resolved/<distro>/` holds each distro's files (one `write_output` per distro);
each distro has its own `<distro>/setup.bash` and `<distro>/<layer>/src/<keys>`, or
`<distro>/src/<keys>` with no layers. A layer with no repos for a distro gets no directory.
`build/ install/ log/` are made by `build` (issue 501).

### `setup.bash` (written by part 1)

The design's refusals table has `init` refuse a directory holding `setup.bash`, and the system
directory section says it "sources the layers that are built", which is none right after `init`.
So `init` writes it, as a file that says so and fails when sourced:

```
# Written by repos-manifest init. Nothing is built here yet.
echo "repos-manifest: nothing is built here yet" >&2
return 1 2>/dev/null || exit 1
```

`sync_distro` writes it only when absent, so a `sync` finishing an interrupted `init` makes it
too. The text names no command that is not built. Not an owner question: the design answers it.

### `init` step by step

`repos-manifest init <manifest> [--role R] [--distro D]... [--distro-dirs] [--with G]... [--yes]`

1. `find_system(cwd)`. Not found: go on. Found, `config.yaml` unreadable: the error naming that
   file. Found, readable: refusal 1.
2. Refusal 2 (several `--distro` without `--distro-dirs`); needs no manifest.
3. `load_manifest(path)`, its errors standing. Refusals 3 to 7 against `manifest.distros` and the
   flags, in the table's order.
4. `resolve` each distro in memory (once; its role, group and distro errors stand).
5. Refusal 8: `paths_init_creates` for every distro; the first that `os.path.lexists` is refused.
6. Tools check (`vcs`, `git`).
7. Print the summary, then for a flat system with a distro the design's `Layout:` line (not
   skipped by `--yes`), then ask (or `--yes`).
8. `sweep_temporaries(system)`. Then `tmp = mkdtemp(prefix=".repos-manifest-tmp-<pid>-",
   dir=system)`, `chmod 0o755`, write `config.yaml` into it, confirm `.repos-manifest` does not
   exist, `os.rename(tmp, system/".repos-manifest")`; `finally` remove `tmp` if it still exists.
   One rename: this is the point from which the system exists; before it nothing of the system
   exists and `init` can be run again. `output.py` and its marker are not used for it.
9. For each distro in the order given, `sync_distro`.
10. Print, per distro, what was cloned, failed, skipped (optional); on a failure "run
    `repos-manifest sync` to finish". A stop signal in step 9 prints "stopped; run
    `repos-manifest sync` to finish" and exits 128+n (`signals.stop_exit`).

Steps 1 to 7 change nothing on disk.

### What happens when a run is interrupted

| Interrupted | On disk | Next command |
|---|---|---|
| Steps 1 to 7, or the question declined | Nothing | `init` again |
| In step 8 | At most a `.repos-manifest-tmp-<pid>-xxxxxxxx` directory in the system directory (removed by `finally` unless the run was killed); `.repos-manifest` does not exist | `init` again (it sweeps the dead one) |
| After step 8, before any repo | `.repos-manifest/config.yaml` only | `init`: refusal 1 (`sync`); `sync` makes everything |
| In step 9 by a stop signal | Repos before the one in flight are cloned and recorded; the one in flight has no path (its `T` removed by `finally`) | `sync` clones the rest |
| In step 9 by `SIGKILL` | Cloned repos are in place; the one in flight is a `T` directory `.repos-manifest-tmp-<pid>-xxxxxxxx` in its `src/`; `state.yaml` may lack finished repos | `sync` sweeps the dead `T`, clones the rest; a repo with no record is part 2's no-record rule |
| After step 9 | Complete | `sync` changes nothing |

A path that exists is always a complete clone or something a person put there, since a clone
reaches its place only by one rename after exit status 0.

### `sync` in part 1

`repos-manifest sync [--distro D]...`, run anywhere in the system (no system: an error naming
where it looked and saying `init`). Phase one: for every selected distro `read_manifest` and
`resolve`. Phase two: `sync_distro` per distro. On a system whose repos all exist it rewrites
the resolved files with the same content (swapped in whole), clones nothing, changes no clone,
adds no state, and prints "N repos are present and were not touched; updating them is not built
yet". Part 2 replaces that sentence with the update rules and adds step 1 of the design's `sync`
(updating the manifest's own clone).

### Refusal tests

Each runs `init` in an empty directory (or one with one unrelated file) and asserts exit status
1, that the message holds the row's next step, that no message names a command that is not built
(`add-distro`, `build`, `status`, `show`, `freeze`, `--manifest-ref`, `--local-manifest`: one
helper checks every refusal's text), and that `snapshot(dir)` (relative path, file type, content
hash, mode; no mtimes) is equal before and after.

| # | Condition | Message gives |
|---|---|---|
| 1 | A system is set up here or above (`init` twice; from a subdirectory; flat and `--distro-dirs`) | `sync`. Not `add-distro`: it is not built. The design's table gets a sentence that the `add-distro` step is given once it is built |
| 1b | `.repos-manifest/` with no readable `config.yaml` | The error names the file, not the refusal |
| 2 | Two `--distro`, no `--distro-dirs` | add `--distro-dirs` |
| 3 | `--distro-dirs`, manifest without `distros:` | |
| 4 | No `--distro`, manifest with `distros:` | |
| 5 | `--distro`, no `--distro-dirs`, manifest without `distros:` | |
| 6 | `--distro` not listed, flat | the resolver's error; name a listed distro, or add it to the manifest's `distros:` (no `--manifest-ref`: not built) |
| 7 | `--distro` not listed, `--distro-dirs` | set up with the distros the manifest lists, or add the distro to its `distros:` (no `add-distro`) |
| 8 | A path `init` would create exists: `src`, a layer directory, a distro directory, `setup.bash`, one test each, flat and `distro-dirs` | |
| 9 | No `vcs` on `PATH`; and `vcs` found but no `git` (a stub `vcs` that exits 0) | |
| 10 | stdin not a terminal, no `--yes` | |
| 11 | Question answered `n` | "nothing was created" |
| 12 | Order: a case that triggers two rows gets the earlier (1 before 2; 4 before 8) | |

### Tests

Files under `tools/repos-manifest/tests/`: `helpers.py` (imported, not collected),
`test_system.py` (pure paths, `distros_for`, config, state), `test_vcs_behaviours.py`,
`test_init_refusals.py`, `test_init.py`, `test_sync.py`, `test_clone.py` (the clone rule, the
destination check, the sweep), `test_interrupted.py`. The existing resolve signal tests cover
the moved `signals.py`.

`helpers.py`: `make_remote(tmp, name, branches, tags)` builds a real git repository (`git init
-b main`, commits; identity from `GIT_AUTHOR_*`/`GIT_COMMITTER_*` set by a fixture, so no global
git config is read or written); `write_manifest`; `snapshot(path)`; `remotes_for(manifest_path,
tmp)` rewrites every `url` of a manifest to a local remote it builds, with a branch of each
repo's `version`.

**Remotes**: local git repositories in `tmp_path`, never the network. `url` is the absolute path
of the remote directory (`manifest.py` accepts it); one test uses `file://` too.

**No `os` patching.** Failure is a url that is not a repository, or a stub `vcs` script in a
`tmp_path/bin` first on `PATH`. A stop is `monkeypatch.setattr(repos_manifest.sync,
"clone_repo", ...)` raising `Stopped` (our own function). A killed run's state is built by hand
(a `.repos-manifest-tmp-<dead pid>-xxxxxxxx` directory made with a process number from a child
that has already ended). The unwritable-directory test skips when run as root, as
`test_output.py` does; nothing else skips.

**`vcs` in tests fails, not skips.** `pyproject.toml` declares the extra as it declares `pytest`
today: `test = ["pytest>=7.0", "vcs2l>=1.1.7"]`; the validate job already runs
`pip install -e tools/repos-manifest[test]`, so `.github/` does not change. `conftest.py` has a
fixture, used by every test that clones, that asserts `shutil.which("vcs")` and fails with
"install vcs2l or vcstool (pip install -e tools/repos-manifest[test])" when it is missing, and a
session fixture that puts the directory of `sys.executable` first on `PATH`, so a `vcs` installed
with the extra is found when the venv is not activated. There is no `needs_vcs` skip.

vcs2l 1.1.7 on both CI Pythons, from its PyPI metadata (`pip index versions vcs2l`; wheel
downloaded without installing and read): the wheel is `py3-none-any`, `Requires-Python >=3.6`,
requires `PyYAML` (and `importlib-metadata`/`setuptools` only below 3.8). The one removed-module
import in its source is `from pkg_resources import load_entry_point` in `vcs2l/commands/help.py`
(`vcs help`), which `vcs import` and `vcs --version` do not load. Nothing was installed, so that
`vcs import` runs on 3.14 is first shown by CI's first run; if it does not, the extra needs a
different fix and the plan is revisited.

Tests of part 1 (names are the behaviour):

- `test_vcs_behaviours.py` (only what part 1 relies on, on the installed `vcs`): `vcs` is
  present and `--version` exits 0; `vcs import <T>` of a one-repo text exits 0 and the clone is at
  `T/<key>`, on the branch, or detached at a tag; a nested key lands at `T/grp/sub/c`; one
  repo whose url is not a repository gives a non-zero exit.
- `test_system.py`: the trees above as `paths_init_creates` results (flat/no layers, flat/layers,
  distro-dirs/no layers, distro-dirs/layers, two distros); `distros_for` from the top, from inside
  a distro directory, with `--distro`, with an unrecorded name; each unreadable `config.yaml` names
  the file; a relative `manifest` is taken from the system directory when a command runs from a
  subdirectory; `put_distro_state` leaves the other distro's entry byte-identical; a missing
  `state.yaml` is empty; one that does not parse names the file.
- `test_init_refusals.py`: the table above.
- `test_init.py`: a first `init` for each of the five trees against local remotes: repos at the
  right paths on the right branch, tag or commit; `state.yaml` per distro with key, layer, version
  and commit equal to `git rev-parse HEAD`; `config.yaml`; `resolved/` equal to what `resolve`
  writes; `setup.bash` exits non-zero when sourced and prints nothing on stdout; `--with` and
  `--role`; a non-optional repo whose url is not a repository is listed as an error, the others
  are cloned, exit 1, and the failed repo leaves no path or temporary directory, and a later
  `sync` after the remote is fixed clones it; an optional one is skipped, listed, exit 0, not in
  state; the summary for one and two distros; the `Layout:` line prints with `--yes`; an
  `OSError`: `init` in a directory with mode `0o500` exits 1 with the directory and "Permission
  denied" in the message and nothing made; **the owner's shape**: `--distro-dirs --distro rolling
  --role developer` from `tests/fixtures/project11/project11.manifest.yaml` (44 repos, seven
  layers) with every `url` rewritten to a local remote: every layer's repos at
  `rolling/<layer>/src/<key>`, and `resolved/rolling/` equal to resolving it.
  (The owner's `simulator` role, six layers and 18 repos, is only in his scratch draft, not a
  committed fixture; it is covered by the by-hand check.)
- `test_clone.py`: a nested key (`grp/sub/c`) arrives at `S/grp/sub/c`, with `S/grp/sub` made;
  a destination that exists (a directory, an empty directory, a file, a link to a directory) is
  present and untouched, and an empty directory is not replaced; **destination check**: a
  symbolic link `src/grp` pointing outside the system, with key `grp/c`, refuses the repo,
  nothing is created outside and the other repos are cloned, exit 1; the same with the layer
  directory itself a link; a key whose parent exists as a link inside `src/`; two runs: a
  stub `vcs` that, during the clone, creates `P`, gives "appeared meanwhile", leaves that `P`
  untouched, and no temporary directory remains; the sweep: a dead-pid temporary directory and
  file in `src/` are removed, one named for a running process (a sleeping child) is not, one named
  `.repos-manifest-tmp-foo`, one whose name only starts like it, and a symbolic link with a
  matching name are not, and no other entry of the directory changes.
- `test_sync.py`: `sync` after `init` changes nothing (`snapshot` equal); a repo added to the
  manifest is cloned, its state added, the others' records untouched; `sync` from a subdirectory
  and from inside a distro directory; `--distro` for one of two distros leaves the other's tree
  and state byte-identical; an unrecorded `--distro` is an error, flat included; **a failed
  resolve changes nothing** (manifest changed to name a missing role, then to be unparsable: exit
  1, the message says the manifest is what failed, `snapshot` equal); a present repo on another
  branch with a local commit and a dirty tracked file is unchanged after `sync`; **a two-distro
  `sync` stopped during the second distro** (`clone_repo` raises `Stopped` on the second distro's
  second repo): the first distro's state is complete, the second's holds the repos it finished,
  and a second `sync` completes both.
- `test_interrupted.py`: stop after the config step (config only; `init` gives refusal 1;
  `sync` finishes; the tree equals an uninterrupted `init`'s); stop during a clone (no path, no
  temporary directory, earlier repos cloned and recorded, `sync` finishes); a dead-pid temporary
  directory left in a `src/` by a killed run (built by hand) is removed by `sync`.
- `repos-manifest --help` lists `init` and `sync`; the existing tests stay green.

Python: nothing newer than 3.10 (no `Path.walk`, `shutil.rmtree(onexc=)`, `tomllib`,
`datetime.UTC`); CI runs 3.10 and 3.14. No hardening against inputs nobody writes: `config.yaml`
and `state.yaml` are checked only for what the code reads.

### By-hand acceptance for the owner (on this machine, after the merge)

His draft manifest has no `base` (checked). For `--role simulator --distro rolling` it resolves
to 18 repos in six layers (underlay 5, core 6, platforms 3, sensors 1, simulation 1, ui 2), all
public `https://` urls, so this step uses the network. The tool is installed from the main
checkout after the merge, not from this worktree (which is deleted at the merge), and not with
`-e`:

```
python3 -m venv ~/p11-venv && ~/p11-venv/bin/pip install /home/roland/agent_workspace/tools/repos-manifest
mkdir -p ~/p11-test && cd ~/p11-test
cp /home/roland/agent_workspace/.agent/scratchpad/project11-manifest-draft/project11.manifest.draft.yaml ./project11.manifest.yaml
~/p11-venv/bin/repos-manifest init ./project11.manifest.yaml --distro-dirs --distro rolling --role simulator
find . -maxdepth 3 -not -path './.git*' | sort | head -60
cat .repos-manifest/config.yaml .repos-manifest/state.yaml | head -40
( source rolling/setup.bash; echo "exit status $? (expected 1: nothing is built yet)" )
```

Then the second run and the local-work check (`<repo>` is any directory under
`rolling/core/src`; fill it in by hand):

```
~/p11-venv/bin/repos-manifest sync      # says the repos are present and untouched; changes nothing
cd ~/p11-test/rolling/core/src/<repo>
f=$(git ls-files | head -1); echo dirty >> "$f"     # a file the repo tracks
git commit --allow-empty -qm "local commit"
mkdir -p ~/p11-before && git status --short > ~/p11-before/status.txt && git log --oneline -3 > ~/p11-before/log.txt
cd ~/p11-test && ~/p11-venv/bin/repos-manifest sync
cd rolling/core/src/<repo>
git status --short | diff - ~/p11-before/status.txt && git log --oneline -3 | diff - ~/p11-before/log.txt && echo unchanged
```

The commands and their output go into the pull request. A failed-first-sync check: `init`
from a copy of the manifest with one repo url that does not exist, then fix the url and run `sync`.

## Cut from part 1 and where it went

| Cut | Where it goes |
|---|---|
| `--local-manifest` and the local-copy read of the manifest | Part 2 (`sync`'s step 1 needs the local copy); `init` sets `local_manifest` itself only for the git form, which arrives with issue 498 part 2's fetcher. Not dropped from the issue |
| `--` pass-through of `vcs import` arguments (and `--shallow`, `--recursive`) | Part 2 (the issue wants it; one call per repo takes the arguments unchanged) |
| The "not a complete clone" listing | Removed, not moved: a path that exists is a complete clone or a person's, by the rename rule. What part 2 does with a present path that is not a git repository is one of its rows |
| `vcs` tests of existing repos (switch of a clean repo, refusal of a changed url) | Part 2's `test_vcs_behaviours.py`; they justify its use of `git` for present repos |
| `write_output(marker_text=)`, `repositories_yaml` in `output.py` | Dropped: `output.py` is not changed |
| `layout.py`, `state.py`, `config.py`, `locations.py`, `tools.py` | Merged into `system.py` and `sync.py` |
| The CI change (first version's owner question 4) | Dropped: `vcs2l` in the test extra, nothing under `.github/` |
| Removal of a path "that did not exist before the call" | Replaced by the temporary-directory rule |

## Part 2: `sync` against clones that exist (a separate pull request, outline)

New `update.py` (the `git` operations; each a `git` call, its exit status the result);
`sync.py` calls it for a present repo and does step 1 and the manifest-against-config check.
It also takes the items moved from part 1: `--local-manifest` and the local-copy read,
the `--` pass-through, and the existing-repo `vcs` tests. One rule per row, each with a test on
real local repos (`snapshot_repo` compares `HEAD`, the branch, `git write-tree`, `git status
--porcelain=v2` and the hash of every file; no test accepts a deleted file or a reset branch):

| Rule (design) | Test |
|---|---|
| On its recorded version, nothing local: fetched and fast-forwarded; moved to a new version when the manifest names one | a new remote commit follows; changed `version` moves; state updated |
| Moved to another branch by a person: left alone, reported | `snapshot_repo` equal; the message names repo and branch |
| Uncommitted tracked changes: left alone, reported | byte-identical |
| Untracked files (owner question) | per the answer |
| Mid-rebase, merge, cherry-pick, revert, bisect: left alone, reported | one test per state |
| Commits not on `origin`, manifest changes the version: never switched, reported | `HEAD` unchanged |
| Commits not on `origin`, still on the manifest's branch: fetched, commits put back on top | local commit on top afterwards |
| The rebase does not go on cleanly: repo put back as it was, reported | conflicting commits; `snapshot_repo` equal, index included |
| Repo no longer in the manifest: left on disk, reported | directory and files survive |
| Repo with no record: followed if on the manifest's version, else moved by a person | delete `state.yaml`: one followed, one reported |
| A repo's url changed in the manifest (owner question) | per the answer |
| A repo given another layer (owner question) | per the answer |
| Step 1: the manifest's own clone updated by these rules; an edited manifest is what is resolved | dirty manifest clone |
| The manifest no longer lists the distro or lacks the role or a group; a flat system whose manifest gained `distros:`: reported for that distro, nothing moved, the others go on, exit 1 | two-distro system; the other distro byte-identical |
| The manifest lists a distro the system does not record: nothing happens | no new directory |
| An optional repo that cannot be fetched is skipped and listed; another is an error | for a present repo whose fetch fails |
| A present path that is not a git repository (the case the removed listing handled) | reported, left alone |
| The destination check runs before a repo is treated as present: a repo behind a link on the way is not present | a link on the way to a cloned repo; reported, nothing touched |

## Files to Change

Part 1:

| File | Change |
|---|---|
| `tools/repos-manifest/src/repos_manifest/signals.py` | New: moved from `cli.py` |
| `.../system.py` | New: refusal type, config, paths, `distros_for`, state, `replace_file`, `read_manifest`, `reporting_oserror` |
| `.../sync.py` | New: tools check, sweep, destination check, `clone_repo`, `sync_distro`, `run_sync` |
| `.../init.py` | New: `run_init` |
| `.../cli.py` | `init` and `sync` parsers and dispatch; imports `signals.py` and `system.py` |
| `tools/repos-manifest/pyproject.toml` | `vcs2l>=1.1.7` in the `test` extra |
| `tools/repos-manifest/tests/*` | Files listed under "Tests"; `conftest.py` gains the `vcs` fixture and the `PATH` fixture |
| `tools/repos-manifest/docs/design.md` | See "Design documents" |
| `tools/repos-manifest/README.md` | Usage of `init` and `sync`; needs `vcs` and `git`; says what is not built; says an ssh key without an agent prompts for its passphrase about twice per repo |
| `tools/repos-manifest/docs/roadmap.md`, `docs/manifest/roadmap.md` | Part 1 done, part 2 not; the issues for part 2 and `add-distro` named |
| `.agent/knowledge/build_and_test.md` | The line that says nothing fetches yet; the tests need `git` and `vcs` (from the extra) |

`output.py` and everything under `.github/` do not change. Part 2: `update.py`, `sync.py`, the
tests above, `design.md`, `README.md`, the roadmaps.

## Prior Art

- The workspace adapter's `vcs import --skip-existing "$layer_dir/src" < "$repos_file"` per layer
  (`.agent/project_types/ros2_colcon/adapter.sh`). Taken: the stdin form, a status check, the
  tool check before any remote is touched. Rejected: one call per layer, whose exit status says
  nothing per repo, and on vcstool 0.3.0 a failed repo leaves an empty directory or a clone on the
  wrong version that `--skip-existing` then counts as present (tried by the plan review on local
  repos).
- Cloning into a temporary directory and renaming into place: the same discipline `output.py` uses
  for its output directory (a sibling temporary, one swap, a sweep of the dead process's leftovers
  by process number). Reused: its dead-process test. Not reused: the writer itself, whose marker
  would say `.repos-manifest/` may be replaced whole.
- vcs2l is a maintained fork of vcstool with the same command line; the tool accepts either and
  depends on neither as a Python package.
- Tried on vcstool 0.3.0 (plan review, 2026-11-18): cloning into a fresh directory and renaming
  `<tmp>/grp/c` to `src/grp/c` gives a working clone; an unknown flag exits 2 and creates
  nothing; `GIT_TERMINAL_PROMPT=0` is set by vcstool for `ls-remote`, so a private https repo
  without a credential helper fails instead of asking.

## Serves

Goal: "one system directory set up and kept in line from one manifest" (the project-setup path of
the workspace's manifest design), under `tools/repos-manifest/docs/design.md#the-system-directory`,
`#setting-up-with-init`, `#refusals` and `#sync`, and root `docs/manifest/design.md` (the "failed
resolve changes nothing" ask under "What the tool has to give"). Anchors are 508's.

## Design Picture

The tool's design changes in the same pull request as the code (ADR-0017), on top of 508's text.
The root design `docs/manifest/design.md` does not change.

Part 1, `tools/repos-manifest/docs/design.md`:

- "The system directory": the `setup.bash` that `init` makes; `state.yaml` appears at the first
  state write.
- "Setting up with init": what the summary holds, for several distros; the question and its rule
  for a non-terminal; `.repos-manifest/` made aside by a temporary directory and one rename; what
  an interruption leaves.
- "Refusals": a row for `vcs` or `git` not found; the `--manifest-ref` hint of rows 6 and 7 and
  the `add-distro` step of rows 1 and 7 are part of the message once those are built (a
  sentence under the table).
- "Where the resolved files and state go": the `state.yaml` shape; no lock, so two runs can lose
  an update.
- "sync": each missing repo cloned with `vcs import` into a temporary directory beside its
  place and renamed in on exit status 0; the check on the real destination; the temporary
  directory name and its removal; the two-phase order; the exit status rule; results of the tests
  on vcstool 0.3.0 next to vcs2l 1.1.7; and in "What is built", not in the rules, that a present
  repo is not touched yet.
- "What the tools rely on": `vcs` from vcs2l or vcstool; no Python dependency; vcs2l in the test
  extra.
- "Open questions": remove "What `init` prints for several distros", the `init` half of "a
  distro's manifest that lacks the role or a group" and "`sync`'s exit status when one distro is
  reported". "How a distro is removed" stays.
- "What is built": `init` and `sync` for a manifest given as a file path, clone only; not built:
  updating clones, `add-distro`, the git and URL forms, the local copy of the manifest.
- The tool's own documents do not mention the workspace or its adapter.

Part 2: "sync" (the rules, untracked files and mid-rebase states included), "Open questions",
"What is built".

**How the branch gets 508's text**: 508 merges first, then `feature/issue-500` merges `main`
(`git merge origin/main`), and the edits above are made on that, as the last commit of the part.
508's edits are never copied by hand; nothing else in part 1 touches 508's files. Code review of
part 1 starts after 508 has merged.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Design edited in the same change, on top of 508; "What is built" says what is |
| Only what's needed | Part 1 is `init` and a clone-only first `sync`; four modules; the cuts above; `add-distro`, lock, time limits, commit-named manifest, `build`, `status`, `show`, `freeze` out |
| A change is only done when its consequences are done | README, roadmaps, `build_and_test.md`, design, `pyproject.toml` |
| Verify before claiming | `vcs` behaviours were run on vcstool 0.3.0 and are re-run by tests on the installed `vcs`; vcs2l on 3.14 is stated as not yet run |
| Never discard work | Part 1 changes no existing clone and removes only a directory it made in the same call, or a dead process's directory of its own name pattern; part 2's tests compare repos byte for byte |
| State a rule once | One temporary-name pattern and one sweep; one destination check; one `replace_file`; one place that reads a manifest |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0017 | Yes | Design edits in the same change |
| ADR-0022 | Yes | The work is inside the part; Serves cites the part's design |
| ADR-0009 | Yes | No bare `pip install`; the by-hand venv is in the home directory; tests use `.venv` |
| ADR-0013 | Yes | `## Plan Authored` entry |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `cli.py` moves `Stopped` and the signal context | existing resolve signal tests | Yes (pass unchanged) |
| The test extra gains `vcs2l` | CI picks it up through `pip install -e ...[test]`; the owner is told | Yes; no `.github/` change |
| The tool's README, design, roadmaps | `docs/manifest/roadmap.md` | Yes |
| `repos-manifest --help` | `validate.yml` runs it | Yes, still passes |

## Out of Scope

- `add-distro` (own issue; shares `sync_distro`).
- The git and URL forms of the manifest location and `base`, with issue 498 part 2.
- The lock against two runs; time limits on fetches; a manifest named by a commit; `build`,
  `status`, `show`, `freeze`; `fetch_from` and `remotes`; removing a distro; parallel clones.

## Open questions for the owner

None for part 1. Three are held for part 2's plan, where the owner sees them with the rules
around them: untracked files in a repo when `sync` updates it; a repo whose `url` changed in the
manifest; a cloned repo whose layer changed in the manifest.

## Estimated Scope

Part 1: about 480 lines of code in four new modules (`sync.py` about 190, `system.py` about
170, `init.py` about 90, `signals.py` and `cli.py` additions about 30), about 620 lines of tests,
about 130 lines of documentation: about 1,230 lines against about 1,700 in the first version.
One pull request. Part 2: about 350 lines of code, 700 of tests, 80 of documentation.
`add-distro`: its own issue, small once `sync_distro` exists.
