# repos-manifest

Status: prototype. The format and the tools are still being designed; see
[docs/spec.md](docs/spec.md), [docs/design.md](docs/design.md) and
[docs/roadmap.md](docs/roadmap.md). The tool was called
`ros-manifest` until #497, which renamed its directory, command and Python package.

## Goals

The main goal is to manage a large project made up of multiple git repositories, which can be
grouped as layers to help manage build times.

Roles let different subsets of the repos be used on different target systems. For example,
roles can distinguish between deployments of the project on headless machines and on machines
with a GUI.

Groups are sets of repos that can be switched on and off together. A role is a choice of
groups, and a machine can switch on more of them on top of its role. Cross-platform projects
can use this, for example to include the drivers for a target hardware platform, a common
case in robotics.

Distros describe major versions of the project, typically targeting different versions of an
underlying framework it depends on.

It was built for ROS 2 systems, but nothing in it requires ROS. `vcs` and `colcon` both work
on other kinds of projects. `colcon` is needed only by the `build` command; the format and
the other tools do not depend on how a project is built.

| Concept | What it is | What it is for |
|---|---|---|
| Layer | An ordered set of repos that is built as one unit, on top of the layers before it | Keeping build times down: a layer that rarely changes is built once |
| Group | A set of repos that is switched on or off together | Parts of the project that only some machines need, such as a simulator or the drivers for one hardware platform |
| Role | A named choice of groups | The different uses of the project: a robot, an operator station, a development machine |
| Distro | A major version of the project, built in its own environment | Picking the branch or tag of each repo that goes with a version of the underlying framework |

This repo holds the specification of the manifest format and a set of tools that work with
it. The tools are one way to use a manifest. Anyone can pick the ones they want, or write
their own against the specification.

- A manifest lists the repos of a system once. A role (robot, operator, developer) and a
  distro select which of them a machine gets, and at which branch or tag.
- A manifest groups its repos into ordered layers. The suggested layout, and the one the tools
  here use, makes each layer its own colcon workspace built on top of the ones before it. A
  layer that rarely changes is built once, and a problem in one layer does not force a rebuild
  of the ones under it. The format does not require that layout.
- A manifest can build on another one. A group with its own robot can start from a published
  manifest and add its own packages, without forking that manifest and without cloning the
  system first.
- The published manifest can point at the released repos while a machine fetches them from
  somewhere else: a developer's forks, or a private server for machines in the field. The
  published manifest is not edited for either.
- A development machine can hold more than one distro of the same system side by side. A
  system set up with a directory per distro can gain a distro later, without moving the
  first. A system set up without one holds one distro, or none.
- Some repos can be optional. For example, marking a private repo optional allows the same
  manifest to be used to set up a public version of a project.
- A manifest is a file, and it can live anywhere: in one of the system's repos, in a repo of
  its own, or on a local disk. A project does not have to adopt it to be described by one.
- The tools cover the whole path at a command line: resolve a manifest for a machine, fetch
  and update the repos, and build the layers in order. They can be run by hand, from an
  install script, in CI, or by a coding agent.

The tools are not meant to replace `vcs` or `colcon`; they are designed to call them. For ROS
2 projects, package dependencies stay with `rosdep`.

## Why another tool

The output is `.repos` files, the format the `vcs` command reads, so `vcs import` can fetch
what a manifest resolves to. The tools are designed around vcs2l, the maintained successor of
vcstool, which provides that command. The files are plain enough that the older vcstool reads
them too, and nothing stops someone from feeding the resolved list to a different tool.

`vcs` on its own gets part of the way. vcs2l is adding an `extends` key (on its main branch,
not in release 1.1.7) that lets a `.repos` file build on other local files and replace entries
in them, the later file winning. A manifest's `base` key does the same job. It is named
differently because it differs: a parent can be at a URL or in a git repo, and the keys of an
entry are merged where vcs2l replaces the entry. A `.repos` file is still one list for one
variant: it has no roles, no per-distro versions, no optional repos and no layers. A system
with three roles and two distros needs six of them kept in step by hand.

We looked at tools that do compose manifests before writing this one (survey of 2026-09):

- **west** (Zephyr) was the closest. It imports one manifest into another and has groups that
  can be switched on and off. It has one revision per repo, so no per-distro branches; it has
  no notion of ordered layers; and it writes its own format, not `.repos`. Using it would
  still have needed our own format on top, a step to pick the distro before west saw the
  manifest, and a converter after it.
- **Android's repo** and **kas** (Yocto) compose in part, but have no per-distro versions and
  do not write `.repos` files.
- **rosinstall_generator** works per distro, from the released ROS index. It answers what a
  released package needs, not which of a project's own repos a given machine should have.
- **vcspull** (looked at 2026-11) syncs git, hg and svn repos from a YAML or JSON file, and is
  not tied to ROS. Its file maps directories to repos, each with an optional revision and
  extra remotes. It is aimed at keeping one person's checkouts the same across machines. Its
  documentation describes no way for one file to build on another, no groups or roles, and
  one revision per repo, and it does not write `.repos` files.

## What works today

`resolve` and `validate` read the format in [docs/spec.md](docs/spec.md), with `base` given
as paths on the local disk; a `base` at a URL or in a git repo is not read yet.
[docs/design.md](docs/design.md#resolve) says what `resolve` writes.

`init` sets up a system directory from a manifest given as a path on the local disk and clones
its repos; `sync` clones the ones that are missing. Neither updates a repo that is already
there yet. Both need `git`, and `vcs` from vcs2l or vcstool, on `PATH`.
[docs/design.md](docs/design.md#what-is-built) says how far they go.

`build` builds one distro's layers in order with `colcon`, each on top of the ones below it,
stops at the first layer that fails (`--keep-going` tries the later ones), and writes the one
`setup.bash` to source. It keeps a record of what it built, one file per distro in
`.repos-manifest/`, and trusts nothing else: a layer counts as built only while the built
layers below it are the ones it was built on. It sees only the `colcon` arguments given after
`--`, not package selection set in a file of `colcon` defaults or a mixin, and names such a
file when one is there. A second `build` of the same distro while one
(or the `colcon` it started) runs is refused, and so is a build of a layer with a repo
missing from disk that is not optional; [docs/design.md](docs/design.md#build) says what it builds, what it
refuses and what `setup.bash` sources. It needs `bash`, and `colcon` on `PATH` (empty and
relative entries are not searched) or installed in the same virtual environment as
repos-manifest.

```bash
repos-manifest resolve --manifest project11.manifest.yaml --role robot --distro jazzy --out ./out
repos-manifest validate --manifest project11.manifest.yaml
repos-manifest init ../project11.manifest.yaml --role developer --distro rolling --distro-dirs
repos-manifest sync
repos-manifest build -- --symlink-install
source rolling/setup.bash
```

A manifest in the prototype's earlier shape still goes to the prototype's reader, which
[docs/prototype.md](docs/prototype.md) describes, with its commands and the checks it applies.

## Installing

The package is not published yet. Install it from this directory into a virtual environment:

```bash
python3 -m venv .venv
.venv/bin/pip install -e .
```

It needs Python 3.10 or later and PyYAML.

The settings under the old name are ignored since the rename: set
`REPOS_MANIFEST_GIT_TIMEOUT` in place of `ROS_MANIFEST_GIT_TIMEOUT`, and an old
`.ros-manifest-cache` directory can be deleted (the default cache is now
`.repos-manifest-cache`). A checkout that had the old tool installed can keep an
ignored `tools/ros-manifest/` directory after pulling (its egg-info and
`__pycache__`, which git does not remove); it can be deleted too.

## Development

```bash
.venv/bin/pip install -e '.[test]'
.venv/bin/pytest tests
```

The test extra installs vcs2l. The tests clone from local git repositories, need `git`, and
fail when no `vcs` is found; a `vcs` already on `PATH` is used first. Most tests of `build` use
a stand-in for `colcon`; the ones marked `colcon` build small CMake packages with the real one,
need `colcon` and `cmake` on `PATH`, and are skipped when either is missing, unless
`REPOS_MANIFEST_REQUIRE_COLCON=1` is set, which makes that a failure.
