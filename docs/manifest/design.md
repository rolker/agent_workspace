# Manifest support in the workspace

How this workspace uses the manifest tool, repos-manifest, to set up, update and check a
project made of many repos. The tool's own documents do not mention the workspace and are
not repeated here:

- the format: [`tools/ros-manifest/docs/spec.md`](../../tools/ros-manifest/docs/spec.md)
- the tools: [`tools/ros-manifest/docs/design.md`](../../tools/ros-manifest/docs/design.md)

The order of work is in [roadmap.md](roadmap.md). The tool's code and command still carry its
earlier name, `ros-manifest`.

## Goals

A registered project of many repos is set up, updated and checked from a manifest, on any
machine: the owner's development machine, a field machine, a collaborator's machine.

- The workspace records which manifest a project instance uses, and for which role and
  distro. It does not hold a copy of the list of repos.
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
  repo), `source_ref` (required for a URL) and `source_path` (the file in the repo,
  `manifest.yaml` if left out).
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
   `ros-manifest resolve --manifest <file> --role <role> --distro <distro> --out <dir> --layout manifest-dir`.
5. Write the result into a new directory, `configs/manifest-resolved.gen-XXXXXX`, record
   where it came from in `.resolved-from`, and move the link `configs/manifest-resolved` to
   point at it.

After that:

- `setup` runs `vcs import --skip-existing` for each layer into
  `layers/main/<layer>_ws/src`.
- `sync` goes through the repos one at a time: `git pull --rebase` for a repo that is clean
  and on its branch, `git fetch` otherwise.
- `build` runs `colcon build` in each layer in order, with `/opt/ros/<distro>` and the
  layers before it sourced.
- `validate` compares `.resolved-from` with what is recorded now, warns when a manifest at a
  path has changed since it was resolved, and names checkouts the manifest no longer lists.
  It fetches nothing and removes nothing.

### Worktrees

For issue work in a package repo, the adapter makes a worktree of that repo and writes an
environment script for it. The script sources the ROS distro, then each lower layer of the
main checkout, then the main checkout's copy of the same layer, then the worktree's own
build. `layers/main` holds the default checkouts, and no issue work is done there.

### Installing the resolver

`make install-ros-manifest`, which `make setup` includes, installs `tools/ros-manifest`
editable into the workspace's shared `.venv` in the main checkout. The adapter runs
`.venv/bin/ros-manifest` from there and does not look on `PATH`.

## The design we are working towards

Nothing in this section is built. It depends on tool commands that are themselves not built
yet (`init`, `show`, `sync`, `build`, `status`); the tool's roadmap has them.

### A project instance is a system directory

The tool sets a system up in one directory, with a `.repos-manifest/` folder that records
the manifest, the role, the distro and where repos are fetched from. A project instance of
type `ros2_colcon` is such a directory. The adapter becomes thin: each of its verbs calls
one of the tool's commands in the instance's directory.

| Adapter verb | Today | Target |
|---|---|---|
| `setup` | Fetch the manifest, resolve, `vcs import` per layer | `repos-manifest init`, with what was given at registration |
| `sync` | Fetch the manifest, resolve, update each repo with git | `repos-manifest sync` |
| `build` | `colcon build` per layer | `repos-manifest build`, with the distro's environment sourced first |
| `validate` | Compare `.resolved-from` with the settings | Read `repos-manifest status` |

A person can run the same commands by hand in the instance's directory and get the same
result as an agent going through the adapter.

### What the workspace records

The registry line keeps what the workspace needs to find an instance and start a session in
it: its name, its type and its path.

Everything about the manifest is given once, at registration, and passed to `init`: the
manifest's location, the role, the distro, extra groups, where to fetch from and extra
remotes. After that the tool's `.repos-manifest/config.yaml` is the one record. The
workspace reads the role and the distro from it when it needs them, and does not keep a
second copy that could disagree.

Today's settings keys map onto the manifest's location in its git form:

| Today | Target, as given to `init` |
|---|---|
| `source` (a URL) with `source_ref` and `source_path` | The manifest as a file in a git repo: its URL, `--manifest-ref` and `--manifest-path` |
| `source` (a path) | The manifest as a path on the local disk |
| `role=` and `distro=` on the registry line | `--role` and `--distro` |
| nothing | `--with`, `--fetch-from`, `--remote` |

Starting a project that has no manifest yet needs nothing more: the instance is registered
with a manifest at a scratch path, and when the manifest is later added to one of the
project's repos, `local_manifest` in `config.yaml` is set to its place in the checkout.

### What the adapter stops doing

- Fetching the manifest with its own git code, afresh on every `setup` and `sync`.
- Keeping generated directories, the `configs/manifest-resolved` link and its lock, and
  `.resolved-from`. The tool's `.repos-manifest/` folder takes their place.
- Reading `.repos` files with its own parser, and updating repos one at a time.
- The `layers/main/<layer>_ws` layout. The tool's layout is `<layer>/` in the instance's
  directory.

### What stays in the workspace

- **Worktrees.** Issue work in a package repo is done in a worktree of that repo, never in
  the instance's own checkouts. The environment script for a worktree keeps its order: the
  distro, the layers below, the instance's copy of the same layer, then the worktree's own
  build. It changes to read the layers from the tool's layout and layer order.
- **The distro's environment.** The tool builds in the environment it is run in. The adapter
  sources the distro's setup file before it calls `build`, as it does today.
- **Sessions, issues and reviews.** Nothing about them changes.

### Installing the tool

`make install-ros-manifest`, part of `make setup`, installs the tool from
`tools/ros-manifest` into the workspace's shared `.venv`. That stays until the tool lives in
its own repo and is published as a package; the workspace then installs it as it installs
its other tools.

### Retiring the bootstrap route

The bootstrap route reads a directory of hand-written layer lists from a clone. Once a
project has a manifest in the new format and its instances are set up from it, the route has
no user and is removed, with `bootstrap_url` and `configs/manifest`.

## Not decided

- Whether one instance holds one distro or several. The tool can keep several distros side
  by side in one system directory. The workspace registers one instance per distro today.
- Which distro runs on the host and which in a container. That is a fact about a machine. It
  would be recorded with the instance, and the adapter would use it to decide where `build`
  runs.
- Help with package dependencies. The tool does not check that a role's repos include what
  their packages depend on. The workspace could, when a manifest is changed.
- Work on field machines. The tool fits fixes made directly on a field machine and pushed to
  a private server. Bringing those changes back for review is a workflow of its own, which
  this workspace does not have.
