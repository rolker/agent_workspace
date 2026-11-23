# Manifest support: roadmap

The order of work for how the workspace uses the manifest tool. The design is in
[design.md](design.md). This is a part of the workspace's main roadmap,
[`docs/roadmap.md`](../roadmap.md), with its own Direction section.

## Direction

What must be true for the acceptance case, each line with a check that says whether it is
true today, where one exists yet. This section holds no status and no dates. Paths in the
checks are relative to the workspace's root.

**Acceptance cases.** Two things work:

1. Project11's Rolling instance on the second machine is registered from a manifest in the
   new format, set up and built through the adapter, and `adapter validate` passes. This is
   the acceptance of the issue that started the adapter's manifest route (#436).
2. An interactive session started in a new, empty directory sets project11 up and onboards
   it for several distros, starting with rolling, asking for what it needs along the way,
   such as where the manifest is. The owner's example is in the design.

| Line | Check |
|---|---|
| The tool has its own goals, format and design, written down (#486) | `gh-issue 486 closed` |
| The workspace's design for using the tool is written down (#487) | `file-exists docs/manifest/design.md` |
| The tool's design covers starting with one distro in a directory of its own and adding a distro later (#495) | `gh-issue 495 closed` |
| The tool's design gives what the adapter relies on today: a status a script can read with an exit status, protection against two runs at once, time limits on fetches, a resolve that changes nothing when it fails, and a manifest named by a commit | |
| The tool has the commands the adapter calls: `show`, `init`, `add-distro`, `sync`, `build` and `status` | |
| The adapter reads a root the tool set up with a directory per distro, its distro from the directory the call comes from, and its `setup` and `sync` run the tool's `sync` (#503 part 1) | `file-contains .agent/project_types/ros2_colcon/adapter.sh .repos-manifest/resolved` |
| Project11 has a manifest in the new format, with its layers, groups, roles and distros | |
| Registration passes the manifest's location, role, distro and fetch settings to `init` | |
| The adapter's `setup`, `sync`, `build` and `validate` call the tool's `sync`, `build` and `status` on the tool route (#503 parts 1 and 4) | `file-contains .agent/project_types/ros2_colcon/adapter.sh _rc_nofd "$bin" status --distro` ; `file-contains .agent/project_types/ros2_colcon/adapter.sh _rc_nofd "$bin" build --distro` |
| The adapter's own manifest fetch and generated directories are removed | |
| A worktree of a package repo builds against an instance in the tool's layout | |
| A session says which distro of its root it is working on | |
| The workspace keeps no copy of what the instance records: the registry line's `role=` and `distro=` and the settings file's `source`, `source_ref` and `source_path` are gone | |
| Project11's root on the second machine is set up and built for Rolling from that manifest and `adapter validate` passes; the result is recorded on the issue before it is closed (#436) | `gh-issue 436 closed` |
| A session started in an empty directory sets up and onboards a project from the repo that holds its manifest (#473) | `gh-issue 473 closed` |
| Jazzy is set up from the manifest too, as a second distro of the same root or by moving today's Jazzy instance | |
| The bootstrap route is removed | |

| Deferral | Revisit check |
|---|---|
| Recording which distro runs on the host and which in a container | |
| Checking package dependencies when a manifest is changed | |
| A review workflow for changes made on field machines | |
| Re-triage of the resolver's error messages that can echo manifest values (#447), once the adapter's fetch code is cut | |
| Re-triage of the leftovers from reviewing the adapter's manifest route (#481), once the adapter's fetch code is cut | |
