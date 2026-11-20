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
`.agent/project_types/ros2_colcon/adapter.sh`, `.agent/scripts/adapter`,
`.agent/scripts/register_project.sh`, `.agent/scripts/_project_registry.sh` and the `Makefile`.

### What is recorded for a project instance

- The registry, `.agent/projects.local`, is per machine and not committed. A line names the
  instance, its type and its path, and may carry `role=` and `distro=`.
- The settings file, `.agent/projects.d/<name>`, holds one `key=value` per line. Three keys
  name a manifest: `source` (an absolute path, or an `https://` or `file:///` URL of a git
  repo; plain `http://` and a URL that carries credentials are refused), `source_ref`
  (required for a URL) and `source_path` (the file in the repo, `manifest.yaml` if left
  out). Work on a manifest that is on the local disk uses the path form.
- `register_project.sh` writes both, with `--role`, `--distro` and `--set source=...`.

### Three routes

The `ros2_colcon` adapter has three routes to the list of repos, taken in this order:

- **The tool route** (the root holds `.repos-manifest/`). The root is a system directory the
  manifest tool set up, and the adapter reads the tool's resolved files. It is taken whatever
  the settings file sets. Its own section is below.
- **The manifest route** (no `.repos-manifest/`, and `source` set).
- **The bootstrap route** (neither).

The last two:

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

### The tool route

The first cut of the design below (issue 503 part 1): a directory set up by hand with
`repos-manifest init <manifest> --distro-dirs --distro <distro> [--role <role>]` is registered
as one `ros2_colcon` project, from the workspace (`register_project.sh <root>`, the type
detected from `.repos-manifest/`) or from a session at the root (`register_session_root.sh`).
The root need not be a git repository. The registry line holds its name, type and path only.

- **What it reads.** Only the tool's resolved files for one distro,
  `.repos-manifest/resolved/<distro>/`: `layers.txt` (the layers in order, the unnamed layer
  as `_unnamed`), `<layer>.repos` and `optional.txt` (the optional repos, by key). It does not
  read `config.yaml` or `state.yaml`. A layer is built in `<root>/<distro>/<layer>`, the
  unnamed layer in `<root>/<distro>`, its repos in `src/` below it. A repo's pin, and so the
  base of a package worktree's branch, is the `version` of its entry in `<layer>.repos`.
- **The distro.** The directory the call comes from decides (the owner, 2026-11-18). A call
  from inside `<root>/<x>/` (the calling directory taken as a physical path), where `<x>` is a
  real directory (not a link) directly under the physical root, other than `worktrees` and names starting with a dot, is for distro `<x>`,
  and only `<x>`: if the
  tool's last resolve for `<x>` cannot be used (no `resolved/<x>/layers.txt`, or it lists no
  layer), the call is refused, naming the tool's own `cd <root> && repos-manifest sync
  --distro <x>`; it never moves on to another distro. `setup` and `sync` from there run that
  sync without needing the resolve. The adapter does not read the tool's settings, so it
  cannot tell a distro's directory from another directory there: a directory under the root
  that is not a distro is taken as one and refused (as not a distro the tool resolved), since
  a wrong distro chosen without a word is worse than a refusal. A call from anywhere else (the root itself, `<root>/worktrees/...`,
  outside the root) is for the one distro under `resolved/` when there is exactly one, a
  resolve the tool has set aside while replacing it (`.<d>.old-*`, `.<d>.new-*`) counting as
  `<d>` with no usable resolve;
  otherwise `validate` checks every one, one after another, and fails naming each that fails
  (a `resolved/<d>/` with no usable `layers.txt` included, so a half-written resolve is not
  passed over), and every other call is refused and the distros listed. A call reads
  `layers.txt` once per distro, and every layer loop of the call goes over that read, so a
  `sync` that replaces `resolved/<distro>/` meanwhile (in two renames) cannot leave a loop with
  no layer. The rule, and which distros a call covers, is stated once, in the header of
  `adapter.sh`; the dispatcher passes the calling directory, `--from` or the current
  directory, as `ACTIVE_PROJECT_FROM`. On a root with several distros, then: registration passes from the
  workspace or a session at the root, since its gate runs `validate`; a package worktree is
  made with `worktree_create.sh --project <name>` called from inside `<root>/<distro>/`
  (every adapter call it makes comes from that directory, so all read that distro), and
  from the root it is refused before anything is made; any other verb is run from inside
  `<root>/<distro>/` (a call to the adapter itself may give its own `--from <root>/<distro>`
  instead). A session is still started at the
  root; a session started inside a distro's directory is a later part (ADR-0020 refuses a
  subdirectory of a root in no git repository).
- **`setup` and `sync`** run `repos-manifest sync --distro <distro>` in the root: `--distro
  <x>` from inside `<root>/<x>/`, from elsewhere the one resolved distro's name; `sync` with
  no `--distro` only from outside every distro's directory when nothing is resolved yet. They
  pass its output and exit status through
  (0; 1 when a repo that is not optional failed, a distro was reported, or on a refusal; 128+n
  on a signal). The adapter pulls, fetches and moves no clone on this route. The tool's `sync`
  clones what is missing and updates a clean clone that is there by the rules in the tool's
  design (under "sync"); a clone with local work is left as it is and reported. When the layers changed, `sync` says that
  package worktrees made before keep their old environment script.
- **`build` and `test`** are the colcon loops of the other routes, over the resolved layers,
  with `--base-paths src`. `build` is interim until the tool's own `build`, and stops at the
  first failing layer; a tree that does not build yet is built by hand, a layer at a time, with
  `colcon build --symlink-install --base-paths src --continue-on-error` in
  `<root>/<distro>/<layer>`. The tool's `<root>/<distro>/setup.bash` is its stub until its
  `build` lands and returns an error, so the instance's environment is `adapter env`.
- **`validate`** checks, for each distro it covers, that each layer's `.repos` file is there
  and that every repo it lists is a directory at `<layer dir>/src/<key>`, passing over a
  missing repo that `optional.txt` names. It fails when the registry line carries `role=` or
  `distro=`, or the settings file `source`, `source_ref`, `source_path` or `bootstrap_url`:
  each is a second record beside the tool's. A leftover `configs/manifest` or
  `configs/project_bootstrap.url`, which this route does not read, is noted without failing.
  Its success line, one per distro, says it checked the tool's last resolve and did not read
  the manifest again; there is no `repos-manifest status` yet.
- **`env`, `repos`, `repo_pin`, `worktree_repos` and `worktree_env`** read the same files and
  directories, so package worktrees work as on the other routes.
- **A `.repos-manifest/` the adapter cannot use** is an error, never another route, so a root
  the tool set up never reaches the bootstrap route's fetch. One message says what is wrong as
  far as the adapter can tell (it is not a directory, or a link to nothing; it cannot be read;
  nothing is resolved yet; the layout is flat, set up without `--distro-dirs`) and names the
  way out: the tool's `sync` in the root when nothing is resolved; otherwise fixing or
  removing that path and setting up again with the tool's `init --distro-dirs` in an empty
  directory (the tool's `sync` would refuse such a path too).
- **Every next step that is the tool's `sync`**, on this route, is written by one helper as
  `cd <root> && <tool> sync`, with `--distro <d>` when the distro is known, the tool by the
  workspace's installed path: never an adapter verb, because registration refuses such a root
  and rolls the project back before one could run, and from the root of a system with several
  distros the adapter's `sync` refuses.
- **A repo key line the adapter's reader cannot read** in a resolved `.repos` file is refused
  by name, so none is passed over without a word. It reads a key of letters, digits, `.`, `_`
  and `-`, bare or in the single quotes the tool writes around a key YAML would read as a
  number or a boolean (`'123'`, `'on'`). A key with a directory in it, such as
  `grp/repo`, which the tool allows, is one case: the adapter and `worktree_create.sh` do not
  read it yet (a later part reads it).

After a package pull request merges, `merge_pr.sh` fast-forwards the root's clone of that
repo, when it is clean and on the pull request's base, past the commit the tool recorded for
it in `state.yaml`. That is the move the tool's `sync` makes to a clean repo that is still
on the manifest's version: the next `sync` finds the clone on the manifest's branch and records
its commit, or fast-forwards it further. The tool's `status`, when it is built, should treat
such a clone as expected. The layer is then rebuilt by hand until the tool builds.

### Worktrees

For issue work in a package repo, the adapter makes a worktree of that repo and writes an
environment script for it. The script sources the ROS distro, then each lower layer of the
main checkout, then the main checkout's copy of the same layer, then the worktree's own
build. `layers/main` holds the default checkouts on the bootstrap and manifest routes, and
`<root>/<distro>/<layer>` on the tool route; no issue work is done there. A lower layer with no
`install/local_setup.bash` when the worktree is made is named in a note on its creation.

### Installing the resolver

`make install-repos-manifest`, which `make setup` includes, installs `tools/repos-manifest`
editable into the workspace's shared `.venv` in the main checkout. The adapter runs
`.venv/bin/repos-manifest` from there and does not look on `PATH`.

## The design we are working towards

Nothing in this section is built beyond its first cut, the tool route under "What exists
today". It depends on two things outside the workspace's own code:

- tool commands that are not built yet (`status`, `add-distro`; `show`, `init`, `sync` and
  `build` are), which the tool's roadmap has;
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
| `setup` | Fetch the manifest, resolve, `vcs import` per layer; run again, it imports what is missing | `repos-manifest init`, with `--distro-dirs` when the project has a distro, for a directory that is not set up yet; `repos-manifest add-distro` for a distro the instance does not have yet, with `--manifest-ref` when that distro's manifest is on a branch of its own (how that version is given is part of how a session names its distro, under "Not decided"); `repos-manifest sync` for a distro that is set up, which clones what is missing |
| `sync` | Fetch the manifest, resolve, update each repo with git | `repos-manifest sync` |
| `build` | `colcon build` per layer | `repos-manifest build`, with that distro's environment sourced first |
| `test` | `colcon test` per layer | Stays in the adapter: `colcon test` per layer, over the layers the tool resolved. The tool has no test command |
| `validate` | Fail when what is on disk was resolved from something else, or a checkout is missing | Fail when `repos-manifest status` says a repo the manifest calls for is missing, or cannot say |

`setup`, `sync`, `build`, `test` and `validate` each act on one distro of the instance: for
the adapter's commands, the one the directory the call comes from chooses, except that
`validate` from outside every distro's directory checks each distro in turn (under "The tool
route"). A session started inside a distro's directory is a later part.

Which route an instance is on is decided in this order, until the older routes are removed:

1. The instance's directory holds `.repos-manifest/`: the instance is on the tool.
2. Otherwise `source` is set: today's manifest route, reading `configs/manifest-resolved`.
3. Otherwise: the bootstrap route.

Until `status` is built, the test is the folder being there, as built today. A folder the
adapter or the tool cannot use, one whose record cannot be read included, is an error that
names the next step, not a sign that the instance is on another route: falling through would
send a root the tool set up to the bootstrap route's fetch. A `status` that reports a missing
repo has answered: the instance is on the tool, and `validate` fails. The tool's design has `init`
make the folder and its record in one step and then sync, so an interrupted `init` leaves
either nothing, and registration is run again, or a system whose first sync is finished
with `sync`.

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
  when a fetch or a resolve fails, and swaps the new one in whole. The tool's `resolve`
  replaces its output whole or not at all, which also keeps a reader from seeing half of it
  (the tool's design, under "resolve"). The tool's `sync` updates the manifest's own clone
  before it resolves, so a manifest that does not resolve can leave that clone moved
  forward; the resolved output and every other repo have to stay as they were, and `sync`
  has to say that the manifest is what failed.
- **A manifest named by a commit.** `source_ref` may be a commit today. The tool's git form
  takes a branch or a tag. An instance pinned to a commit stays on today's route until the
  tool takes a commit, or is registered again with a branch or tag.

Three of today's guarantees are covered by the tool's design as it is: it reads the manifest
again on every `sync`, its `sync` deletes nothing and leaves local work alone, and an
interrupted `init` leaves either nothing, in which case registration is run again, or a
system whose first sync `sync` finishes.

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
the resolved `.repos` files and layer order, which are the tool's stated output. On the tool
route none of the five records below is read, and `validate` refuses each one it finds. Until
every instance is on the tool, the older routes still read `role=` and `distro=` from the
registry line, so those stay until then, and so do `source`, `source_ref` and `source_path` in
the settings file. All five go together.

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

- How a session started inside a distro's directory is accepted (ADR-0020 refuses a
  subdirectory of a root in no git repository today), how the distro a worktree is for is
  carried into it, and how a session gives the version of the manifest for a distro it adds
  whose manifest is on a branch of its own (`add-distro --manifest-ref`). Which distro the
  adapter's commands act on is decided: the directory the call comes from (under "The tool
  route"). A worktree's environment script is written for one distro, the one its creation
  chose.
- Which distro runs on the host and which in a container. That is a fact about a machine. It
  would be recorded with the instance, and the adapter would use it to decide where `build`
  runs.
- Help with package dependencies. The tool does not check that a role's repos include what
  their packages depend on. The workspace could, when a manifest is changed.
- Work on field machines. The tool fits fixes made directly on a field machine and pushed to
  a private server. Bringing those changes back for review is a workflow of its own, which
  this workspace does not have.
