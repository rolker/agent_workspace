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
- The workspace adds what the tool leaves out on purpose: worktrees for issue work, help
  with package dependencies when a manifest is updated, and the review workflow for changes
  made on field machines.

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
