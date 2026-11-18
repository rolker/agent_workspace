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
   such as where the manifest is. The owner's example of 2026-11-18 is in the design.

| Line | Check |
|---|---|
| The tool has its own goals, format and design, written down (#486) | `gh-issue 486 closed` |
| The workspace's design for using the tool is written down (#487) | `file-exists docs/manifest/design.md` |
| The tool has the commands the adapter calls: `init`, `sync`, `build` and `status` | |
| Registration passes the manifest's location, role, distro and fetch settings to `init`, and the workspace keeps no second copy | |
| The tool's design covers starting with one distro in a directory of its own and adding a distro later (#495) | `gh-issue 495 closed` |
| A session started in an empty directory sets up and onboards a project from the repo that holds its manifest (#473) | |
| The adapter's `setup`, `sync`, `build` and `validate` call the tool, and its own manifest fetch and generated directories are removed | |
| A worktree of a package repo builds against an instance in the tool's layout | |
| Project11 has a manifest in the new format, with its layers, groups, roles and distros | |
| The Rolling instance on the second machine is registered from that manifest and `adapter validate` passes (#436) | `gh-issue 436 closed` |
| The Jazzy instance is moved to the manifest | |
| The bootstrap route is removed | |

| Deferral | Revisit check |
|---|---|
| Recording which distro runs on the host and which in a container | |
| Checking package dependencies when a manifest is changed | |
| A review workflow for changes made on field machines | |
| Re-triage of the resolver's error messages that can echo manifest values (#447), once the adapter's fetch code is cut | |
| Re-triage of the leftovers from reviewing the adapter's manifest route (#481), once the adapter's fetch code is cut | |
