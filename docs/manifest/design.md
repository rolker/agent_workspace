# Manifest support in the workspace

How this workspace uses the manifest tool, repos-manifest, to set up, update and check a
project made of many repos. The tool's own documents do not mention the workspace and are
not repeated here:

- the format: [`tools/repos-manifest/docs/spec.md`](../../tools/repos-manifest/docs/spec.md)
- the tools: [`tools/repos-manifest/docs/design.md`](../../tools/repos-manifest/docs/design.md)

The order of work is in [roadmap.md](roadmap.md). The tool's code, command and directory
carry the name repos-manifest.

## Goals

A registered project of many repos is set up, updated and checked from a manifest, on any
machine: the owner's development machine, a field machine, a collaborator's machine.

- Which manifest a project instance uses, and for which role and distros, is recorded once,
  with the instance. The workspace does not hold a copy of the list of repos.
- An agent and a person use the same commands on a project. What an agent does through the
  adapter, a person can do by hand with the tool.
- A project that has no manifest yet can be set up from one written in a scratch place, and
  the manifest added to the project later through the usual workflow, or left where it is.
- The workspace adds what the tool leaves out on purpose: worktrees for issue work, and help
  with package dependencies when a manifest is updated.

## What exists today

This section describes the code as it is. It was checked against
`.agent/project_types/ros2_colcon/adapter.sh`, `.agent/scripts/_project_registry.sh` and the
`Makefile`.

### What is recorded for a project instance

- The registry, `.agent/projects.local`, is per machine and not committed. A line names the
  instance, its type and its path, and may carry `role=` and `distro=`.
- The settings file, `.agent/projects.d/<name>`, holds one `key=value` per line. Three keys
  name a manifest: `source` (an absolute path, or an `https://` or `file:///` URL of a git
  repo; plain `http://` and a URL that carries credentials are refused), `source_ref`
  (required for a URL) and `source_path` (the file in the repo, `manifest.yaml` if left
  out). Work on a manifest that is on the local disk uses the path form.
- `register_project.sh` writes both, with `--role`, `--distro` and `--set source=...`.

### Two routes

The `ros2_colcon` adapter has two routes to the list of repos, chosen by one fact: whether
`source` is set.

- **The bootstrap route** (no `source`). The adapter fetches a `bootstrap.yaml` with `curl`
  from a URL, clones the repo it names, and links `configs/manifest` to a directory in that
  clone. The directory holds `layers.txt`, `optional_layers.txt` and one `.repos` file per
  layer, written by hand.
- **The manifest route** (`source` set). The adapter fetches the manifest and has the
  resolver turn it into the same three kinds of file.

### The manifest route, step by step

`setup` and `sync` both start the same way:

1. Check that a role and a distro are recorded and that the resolver is installed.
2. Take a lock on `configs/.lock.source`.
3. Fetch the manifest. A path is read in place. A URL is fetched afresh every time with the
   adapter's own git code, into a directory that is removed afterwards; no clone is kept.
4. Run the resolver:
   `repos-manifest resolve --manifest <file> --role <role> --distro <distro> --out <dir> --layout manifest-dir --cache-dir <dir>.cache`.
   The cache directory is new each time and removed afterwards.
5. Write the result into a new directory, `configs/manifest-resolved.gen-XXXXXX`, record
   where it came from in `.resolved-from`, and move the link `configs/manifest-resolved` to
   point at it.

After that:

- `setup` runs `vcs import --skip-existing` for each layer into
  `layers/main/<layer>_ws/src`.
- `sync` goes through the repos one at a time. A repo with uncommitted changes is skipped
  and nothing is fetched for it. A clean repo on the branch the manifest names gets
  `git pull --rebase`. A clean repo on another branch, or on no branch, gets `git fetch`.
- `build` runs `colcon build` in each layer in order, with `/opt/ros/<distro>` and the
  layers before it sourced.
- `validate` fails, with a non-zero exit status, when `.resolved-from` is missing or does not
  match the source, ref, path, role or distro recorded now, when no role is recorded or the
  distro cannot be worked out, when a second source is set beside `source`, or when a checkout
  or a layer file the manifest calls for is missing. It warns when a manifest at a path has
  changed since it was resolved, and names checkouts the manifest no longer lists. It fetches
  nothing and removes nothing. Its check has two limits: a layer marked optional is passed
  over when its `.repos` file or its `src/` is absent, and a repo counts as checked out when
  a directory of its name exists, whatever is in it.

Network is needed at `setup` and `sync`, for the source, for the host of every `extends`
base and for the host of every package repo, and for installing the resolver.

What the route guarantees, and how far each guarantee goes:

- **Never silently stale.** A git `source` is fetched afresh by each `setup` and `sync`, and
  no clone is kept (the owner's decision of 2026-11-13). Every `extends` base is cloned
  afresh too.
- **A failed fetch or resolve changes nothing.** The previous generated directory stays the
  one in use. This covers the fetch and the resolve only: once the new directory is in use,
  an import that fails part way leaves it in use, with some repos checked out and some not.
- **One fetch and resolve at a time.** They hold a lock on `configs/.lock.source`, which is
  never removed. The lock is released before repos are imported or updated, so two runs can
  overlap there. Without `flock` on the machine, nothing is locked.
- **A reader is not cut off.** Every verb reads one generated directory from start to end,
  and a directory is not removed while a run reads it. Without `flock` the adapter cannot
  tell, and keeps the directory before the live one instead; two later runs can then remove
  a directory a long run is still reading.
- **Bounded and guarded fetches.** The adapter's fetch allows the https, ssh and file
  transports only and is bounded by `WT_FETCH_TIMEOUT`. The resolver's clone of an `extends`
  base runs no user hook or filter driver and is bounded by `REPOS_MANIFEST_GIT_TIMEOUT`.
- **Nothing is deleted.** The adapter removes no checkout and edits no ignore file.

### Worktrees

For issue work in a package repo, the adapter makes a worktree of that repo and writes an
environment script for it. The script sources the ROS distro, then each lower layer of the
main checkout, then the main checkout's copy of the same layer, then the worktree's own
build. `layers/main` holds the default checkouts, and no issue work is done there.

### Installing the resolver

`make install-repos-manifest`, which `make setup` includes, installs `tools/repos-manifest`
editable into the workspace's shared `.venv` in the main checkout. The adapter runs
`.venv/bin/repos-manifest` from there and does not look on `PATH`.

## The design we are working towards

Nothing in this section is built. It depends on two things outside the workspace's own
code:

- tool commands that are not built yet (`init`, `show`, `sync`, `build`, `status`,
  `add-distro`), which the tool's roadmap has;
- some of what the adapter relies on today, which the tool's design does not promise yet. It
  is listed under "What the tool has to give".

### The case it is designed for

The owner's example of how setting up a project could start (2026-11-18): make a directory,
start a session in it, and ask for the project to be set up and onboarded from the repo it
lives in, for more than one distro, starting with one. It is an interactive session, and the
agent asks for what the request leaves out.

```
mkdir ~/project11
cd ~/project11
claude
> set up and onboard project11, which lives at rolker/unh_marine_autonomy on GitHub,
  to work on several distros, starting with rolling
```

What has to happen behind that request:

1. The session is in a directory that is not registered. The workspace offers to register
   it as a project root.
2. The agent asks where the manifest is, if the request does not say. The owner
   (2026-11-18): "At first, it might be a local file or not even exist, then once it gets
   added, it would be from github probably." So the answer may be a file on the local disk,
   a file in the named repo, or that there is none yet, in which case one is written in a
   scratch place first.
3. The session shows what the manifest comes to for a role and that distro
   (`repos-manifest show`) and asks before fetching the project's repos. Reading the
   manifest and its parents, which `show` needs, happens before the question.
4. `repos-manifest init --distro-dirs` sets the directory up with one directory per distro,
   holding the first distro only.
5. The distro is built, and the project is onboarded as any other.
6. Later, `repos-manifest add-distro` adds another distro to the same directory, without
   moving the first.

### A project instance is a system directory

The tool sets a system up in one directory, with a `.repos-manifest/` folder that records
the manifest, the role, the distros and where repos are fetched from. A project instance of
type `ros2_colcon` is such a directory, and it is the root a session is started in. It holds
every distro of the project the machine has, each in its own directory from the first distro
on. `setup` passes `--distro-dirs` to `init` whenever the project has a distro, even for the
first one alone, so that adding a distro later moves nothing:

```
~/project11/
  .repos-manifest/
  rolling/
    underlay/  core/  ...
    setup.bash
  jazzy/
    ...
```

The adapter becomes thin: each of its verbs calls one of the tool's commands in the
instance's directory, for one distro.

| Adapter verb | Today | Target |
|---|---|---|
| `setup` | Fetch the manifest, resolve, `vcs import` per layer; run again, it imports what is missing | `repos-manifest init --distro-dirs` for a directory that is not set up yet; `repos-manifest add-distro` for a distro the instance does not have yet, with `--manifest-ref` when that distro's manifest is on a branch of its own (how that version is given is part of how a session names its distro, under "Not decided"); `repos-manifest sync` for a distro that is set up, which clones what is missing |
| `sync` | Fetch the manifest, resolve, update each repo with git | `repos-manifest sync` |
| `build` | `colcon build` per layer | `repos-manifest build`, with that distro's environment sourced first |
| `test` | `colcon test` per layer | Stays in the adapter: `colcon test` per layer, over the layers the tool resolved. The tool has no test command |
| `validate` | Fail when what is on disk was resolved from something else, or a checkout is missing | Fail when `repos-manifest status` says a repo the manifest calls for is missing, or cannot say |

`setup`, `sync`, `build`, `test` and `validate` each act on one distro of the instance: the
one the session is working on. How a session says which is not decided yet.

Which route an instance is on is decided in this order, until the older routes are removed:

1. The tool answers `repos-manifest status` in the instance's directory: the instance is on
   the tool.
2. Otherwise `source` is set: today's manifest route, reading `configs/manifest-resolved`.
3. Otherwise: the bootstrap route.

The test is the tool answering, not the `.repos-manifest/` folder being there, because an
`init` that was interrupted can leave the folder without a complete record. A `status` that
reports a missing repo has answered: the instance is on the tool, and `validate` fails. The tool's
design has `init` record what it was given and then sync, so a first sync that fails part
way is finished with `sync`. A directory whose record is not complete would be set up by
running registration again, which needs the ask "`init` can be run again" under "What the
tool has to give". The tool's design does not give that yet: its `init` refuses a directory
that has `.repos-manifest/`.

An existing instance is not converted in place. Its layout is `layers/main/<layer>_ws`, the
tool's, with a directory per distro, is `<distro>/<layer>/`, and its checkouts may hold work.
It is moved by setting up a new directory with the tool, after work in the old checkouts has
been pushed, and it keeps working on its current route until then.

A person can run the same commands by hand in the instance's directory and get the same
result as an agent going through the adapter.

### What the tool has to give

Some of what the adapter gives today is not in the tool's design yet. The adapter cannot
become thin without it, and it is asked of the tool, not rebuilt in the adapter:

- **A status a script can read.** `validate` fails with an exit status today. The tool's
  `status` is described as something a person reads. It needs a form a script can read,
  which also gives the role and the distros the system directory was set up for, and an exit
  status that says a repo the manifest calls for is missing.
- **Protection against two runs at once.** The adapter locks its fetch and resolve. The
  tool's design has no lock.
- **Time limits on fetches.** The adapter bounds its fetches, and the resolver bounds its
  clones of parent manifests. The tool's design sets no limit on `sync`.
- **A failed resolve changes nothing.** The adapter keeps the previous generated directory
  when a fetch or a resolve fails, and swaps the new one in whole. The tool's design says
  where `resolve` writes and not what a failure leaves behind. Its resolved output has to be
  replaced whole or not at all, which also keeps a reader from seeing half of it. The tool's
  `sync` updates the manifest's own clone before it resolves, so a manifest that does not
  resolve can leave that clone moved forward; the resolved output and every other repo have
  to stay as they were, and `sync` has to say that the manifest is what failed.
- **`init` can be run again.** Run over a directory it did not finish setting up, it
  completes the record instead of refusing.
- **A manifest named by a commit.** `source_ref` may be a commit today. The tool's git form
  takes a branch or a tag. An instance pinned to a commit stays on today's route until the
  tool takes a commit, or is registered again with a branch or tag.

Two of today's guarantees are covered by the tool's design as it is: it reads the manifest
again on every `sync`, and its `sync` deletes nothing and leaves local work alone.

One is given up on purpose. Today's route refuses plain `http` and a URL that carries
credentials, and clones a parent manifest's repo with none of the user's git configuration,
so that no hook or filter driver runs. The tool allows `http` for networks a person trusts,
does not look for credentials in a URL, and uses `git` as it is set up on the machine, by
the owner's decision on how far the tool's checks go (2026-11-17): a manifest is read like
any code about to be run. What the
tool does check is in its spec, under "Reading a manifest before using it".

`validate` no longer catches a directory that was set up from the wrong manifest, role or
distro. Today it can, because the workspace holds a second record to compare with. In the
target there is one record, in the instance, and nothing to compare it against; `show` and
`status` say what it holds. The order in which `sync` updates the manifest and the repos, and how it knows
what it last put each repo on, are the tool's and are in its design.

### What the workspace records

The registry line keeps what the workspace needs to find an instance and start a session in
it: its name, its type and its path.

Everything about the manifest is given once, at registration, and passed to `init`: the
manifest's location, the role, the first distro, extra groups, where to fetch from and extra
remotes. After that the tool's record in `.repos-manifest/` is the one record. The workspace
asks the tool for the role and the distros when it needs them, through `status`, and keeps no
second copy that could disagree. The one thing it reads from `.repos-manifest/` directly is
the resolved `.repos` files and layer order, which are the tool's stated output. Until the
adapter's verbs have moved to the tool, and a session can say which distro it works on, they
still read `role=` and `distro=` from the registry line, so those stay until then, and so do `source`, `source_ref` and `source_path` in the settings
file. All five go together.

Today's settings keys map onto the manifest's location in its git form:

| Today | Target, as given to `init` |
|---|---|
| `source` (a URL) with `source_ref` and `source_path` | The manifest as a file in a git repo: its URL, `--manifest-ref` (a branch or a tag; see "What the tool has to give" for a commit) and `--manifest-path`. The path is always passed, `manifest.yaml` when none was given, because the tool takes a URL with no path as the file itself |
| `source` (a path) | The manifest as a path on the local disk |
| `role=` and `distro=` on the registry line | `--role` and `--distro` |
| nothing | `--with`, `--fetch-from`, `--remote` |

Starting a project that has no manifest yet needs nothing more: the instance is registered
with a manifest at a scratch path. When the manifest is later added to one of the project's
repos, the recorded location is changed to the file in that repo and its place in the
checkout, in the way the tool's design gives for changing them after `init`.

### What the adapter stops doing

- Fetching the manifest with its own git code, afresh on every `setup` and `sync`.
- Keeping generated directories, the `configs/manifest-resolved` link and its lock, and
  `.resolved-from`. The tool's `.repos-manifest/` folder takes their place.
- Reading `.repos` files with its own parser to update repos one at a time.
- The `layers/main/<layer>_ws` layout. The tool's layout, with a directory per distro, is
  `<distro>/<layer>/` in the instance's directory.

### What stays in the workspace

- **Worktrees.** Issue work in a package repo is done in a worktree of that repo, never in
  the instance's own checkouts. The environment script for a worktree keeps its order: the
  distro, the layers below, the instance's copy of the same layer, then the worktree's own
  build. It changes to take the layers, their order and the repos in each from the tool's
  resolved output, for the distro the worktree is for. `sync` goes on saying when a
  worktree's environment script no longer matches the layers.
- **The distro's environment.** The tool builds in the environment it is run in. The adapter
  sources the distro's setup file before it calls `build`, as it does today.
- **Sessions, issues and reviews.** Nothing about them changes.

### Installing the tool

`make install-repos-manifest`, part of `make setup`, installs the tool from
`tools/repos-manifest` into the workspace's shared `.venv`. That stays until the tool lives in
its own repo and is published as a package; the workspace then installs it as it installs
its other tools.

### Retiring the bootstrap route

The bootstrap route reads a directory of hand-written layer lists from a clone. Once a
project has a manifest in the new format and its instances are set up from it, the route has
no user and is removed, with `bootstrap_url` and `configs/manifest`.

## Not decided

- How a session says which distro it is working on, when its root holds several, and how it
  gives the version of the manifest for a distro it adds whose manifest is on a branch of its
  own (`add-distro --manifest-ref`). Today a
  distro is recorded once per instance, on the registry line, and a worktree's environment
  script is written for that one distro.
- Which distro runs on the host and which in a container. That is a fact about a machine. It
  would be recorded with the instance, and the adapter would use it to decide where `build`
  runs.
- Help with package dependencies. The tool does not check that a role's repos include what
  their packages depend on. The workspace could, when a manifest is changed.
- Work on field machines. The tool fits fixes made directly on a field machine and pushed to
  a private server. Bringing those changes back for review is a workflow of its own, which
  this workspace does not have.
