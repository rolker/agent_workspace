# Roadmap

Where repos-manifest is going, in the order we expect to do it. The format is in
[spec.md](spec.md) and the tools' design in [design.md](design.md).

## Direction

What must be true for the acceptance case, each line with a check that says whether it is
true today. This section holds no status and no dates. Paths in the checks are relative to
the tool's own directory.

**Acceptance case (proposed).** A person sets up a multi-repo ROS 2 system on a clean machine
from a published manifest with these tools alone: `init` with a role and a distro, `build`,
source the setup file, and the system runs. A collaborator does the same from their own
manifest that extends the published one and adds a layer for their robot.

| Line | Check |
|---|---|
| The format is written down | `file-exists docs/spec.md` |
| The tool and its code carry the name repos-manifest | `file-exists src/repos_manifest/cli.py` |
| The resolver reads the format in the spec: a superset of a `.repos` file, keys merged under `extends`, layers appended, groups named on the repo | |
| The resolver no longer has the package dependency section, roles defined by starting packages, or the cache of parents kept between runs | |
| `extends` and the manifest itself can be given as a URL | |
| `init` and `sync` set up and update a system directory, and `sync` leaves local work alone | |
| `build` builds the layers in order and writes one setup file | |
| `status` shows what differs from the manifest | |
| `status --exact` records exact commits as a manifest that `init` and `sync` accept | |
| A machine can fetch every repo from another place: a developer's forks where they exist, or a private server for a field machine | |
| A manifest can be read from a private git server | |
| `sync` adds the extra remotes a machine names to every clone | |
| A system directory can hold more than one distro, each in its own directory | |
| A real system is described by a published manifest and set up from it | |
| The tool lives in its own repo and can be installed as a package | |

| Deferral | Revisit check |
|---|---|
| A `ros2 manifest` command as a thin wrapper around the same code | |
| A per-user settings file, so where to fetch from is set once for all systems | |
| A preferred branch for field work, used where it exists | |
| A default layer for a repo that names none | |
| Running a distro the host OS does not support, in a container or otherwise | |
| Roles that name single repos or pick layers | |
