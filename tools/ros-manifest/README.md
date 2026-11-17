# repos-manifest

Status: prototype. The format and the tools are still being designed; see
[docs/spec.md](docs/spec.md), [docs/design.md](docs/design.md) and
[docs/roadmap.md](docs/roadmap.md). The code here was written under the earlier name
`ros-manifest`, and its directory, command and Python package still carry that name.

## Goals

A ROS 2 system is usually many repositories, and the same system is installed in several
variants: a robot, an operator station, a development machine, one ROS distro or another.
repos-manifest lets one description cover all of them.

It was built for ROS 2 systems, and nothing in it requires ROS. `vcs` and `colcon` both work
on other kinds of projects, and a distro is to the format only a named variant that picks a
repo's version.

This repo holds the specification of the manifest format and a set of tools that work with
it. The tools are one way to use a manifest. Anyone can pick the ones they want, or write
their own against the specification.

- A manifest lists the repos of a system once. A role (robot, operator, developer) and a ROS
  distro select which of them a machine gets, and at which branch or tag.
- A manifest groups its repos into ordered layers. The suggested layout, and the one the tools
  here use, makes each layer its own colcon workspace built on top of the ones before it. A
  layer that rarely changes is built once, and a problem in one layer does not force a rebuild
  of the ones under it. The format does not require that layout.
- A manifest can extend another one. A group with its own robot can start from a published
  manifest and add its own packages, without forking that manifest and without cloning the
  system first.
- The published manifest can point at the released repos while a developer points some or all
  of them at forks, without editing the published manifest.
- Some repos can be optional. For example, marking a private repo optional allows the same
  manifest to be used to set up a public version of a project.
- A manifest is a file, and it can live anywhere: in one of the system's repos, in a repo of
  its own, or on a local disk. A project does not have to adopt it to be described by one.
- The tools cover the whole path at a command line: resolve a manifest for a machine, fetch
  and update the repos, and build the layers in order. They can be run by hand, from an
  install script, in CI, or by a coding agent.

The tools do not replace `vcs` or `colcon`; they call them. Package dependencies stay with
`rosdep`.

## Why another tool

The output is `.repos` files, the format the `vcs` command reads, so `vcs import` can fetch
what a manifest resolves to. The tools here use vcs2l, the maintained successor of vcstool,
which provides that command. The files are plain enough that the older vcstool reads them too,
and nothing stops someone from feeding the resolved list to a different tool.

`vcs` on its own gets part of the way. vcs2l is adding an `extends` key (on its main branch,
not in release 1.1.7) that lets a `.repos` file build on other local files and replace entries
in them, the later file winning. A manifest's `extends` follows the same rule. A `.repos` file
is still one list for one variant: it has no roles, no per-distro versions, no optional repos
and no layers. A system with three roles and two distros needs six of them kept in step by
hand.

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


## What works today

A prototype resolves and validates manifests in an earlier shape of the format. It does not
yet fetch, sync or build. [docs/prototype.md](docs/prototype.md) describes what it reads, its
commands, and the checks it applies to a manifest.

```bash
ros-manifest resolve --manifest path/to/manifest.yaml --role dev --distro jazzy --out ./out
ros-manifest validate --manifest path/to/manifest.yaml --role dev --distro jazzy
```

## Installing

The package is not published yet. Install it from this directory into a virtual environment:

```bash
python3 -m venv .venv
.venv/bin/pip install -e .
```

It needs Python 3.10 or later and PyYAML.

## Development

```bash
.venv/bin/pip install -e '.[test]'
.venv/bin/pytest tests
```
