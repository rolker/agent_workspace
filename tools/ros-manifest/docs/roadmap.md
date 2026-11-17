# Roadmap

Where repos-manifest is going, in the order we expect to do it. The format is in
[spec.md](spec.md) and the tools' design in [design.md](design.md).

## Direction

What must be true for the acceptance case, each line with a check that says whether it is
true today. This section holds no status and no dates. Paths in the checks are relative to
the tool's own directory.

**Acceptance case.** Four things work with these tools alone:

1. Project11, whose manifest is in one of its own repos, is set up on a clean machine: `init`
   with a role and a distro, `build`, source the setup file, and the system runs. A
   collaborator does the same from their own manifest that builds on the published one and
   adds a layer for their robot.
2. Someone who wants to try project11 follows a short set of instructions and has it running
   in the simulator, with a role that includes it, such as the developer role. The
   instructions include installing repos-manifest, in a virtual environment if that is
   needed.
3. Project11's CI uses the tools to fetch and build what it tests.
4. Nav2 is built locally by writing a manifest on the local disk and using it.

| Line | Check |
|---|---|
| The format is written down | `file-exists docs/spec.md` |
| The tool and its code carry the name repos-manifest | `file-exists src/repos_manifest/cli.py` |
| The resolver reads the format in the spec: a superset of a `.repos` file, keys merged under `base`, layers appended, groups named on the repo | |
| The resolver no longer has the package dependency section, roles defined by starting packages, or the cache of parents kept between runs | |
| `base` and the manifest itself can be given as a path, a URL, or a file in a git repo | |
| `show` prints what a manifest comes to for a machine, with what is left out and why | |
| `init` and `sync` set up and update a system directory, and `sync` leaves local work alone | |
| `build` builds the layers in order and writes one setup file | |
| `status` shows what differs from the manifest | |
| A machine can fetch every repo from another place: a developer's forks where they exist, or a private server for a field machine | |
| A manifest can be read from a private git server | |
| `sync` adds the extra remotes a machine names to every clone | |
| A system directory can hold more than one distro, each in its own directory | |
| Project11 is described by a manifest in one of its repos and set up from it | |
| A short set of instructions gets someone project11 running in the simulator, including installing the tool | |
| Project11's CI fetches and builds with the tools | |
| Nav2 is built locally from a manifest written on the local disk | |
| `freeze` records exact commits as a manifest that `init` and `sync` accept | |
| The tool lives in its own repo and can be installed as a package | |

| Deferral | Revisit check |
|---|---|
| A `ros2 manifest` command as a thin wrapper around the same code | |
| A per-user settings file, so where to fetch from is set once for all systems | |
| A preferred branch for field work, used where it exists | |
| Running a distro the host OS does not support, in a container or otherwise | |
| Roles that name single repos or pick layers | |
