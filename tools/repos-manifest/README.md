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

`show` prints what a manifest given as a path on the local disk comes to for a role and
distro: each layer with its repos, their versions and URLs, the manifest an entry came from
when it is not the first in the chain, and the repos left out with the reason. Run with no
manifest inside a system directory, it uses what the system records. It writes nothing, and
`init` prints the same before it asks. [docs/design.md](docs/design.md#show) shows the output.

`init` sets up a system directory from a manifest given as a path on the local disk and clones
its repos; `sync` clones the ones that are missing and updates the ones that are there, with
`git`. A clean clone on the manifest's branch is fast-forwarded, and one `sync` left on the
version the manifest named before is moved to the one it names now. A clone a person has changed
is left as it is and reported: one with uncommitted changes, commits not on `origin`, another
branch checked out, an operation in progress, or a file git does not track (untracked or
ignored) where an incoming file goes. Untracked files elsewhere do not stop an update. So is a
clone where the update would remove or replace a checked-out submodule, or move the commit of
one a person has moved; submodules are never updated, so a repo with submodules follows one
change of a submodule's commit and stops at the next, until that submodule is updated by hand
(the report gives the `git submodule update` command), and a sparse checkout is left as it is. A
version given as a commit is followed only when `origin` holds it. An `origin` a person set is
left as set; the manifest's new url replaces `origin` only when the clone still has the url
`sync` recorded and no local branch, and no work tree's `HEAD`, has commits it lacks. A branch
another work tree holds is not moved: one checked out there, or one a rebase or a bisect in
progress there will return to or set, as git itself counts it; a linked work tree on another
branch is unaffected. A version written `heads/<name>` or `tags/<name>` is the branch or the
tag of that name only, and a pin changed from the branch to the tag of the same name (or back)
moves the repo like any other pin change; when that branch and tag are both at the commit
`sync` recorded, which one it followed cannot be told, and the repo is left as it is and
reported. Where `sync`, `init`, `show`, `resolve` and `validate` put a url into a message, a
`scheme://` url's user name and password are masked as `***`, and a value of the wrong type is
described, not shown; the lines `sync` prints for a repo's outcome, and the error of a manifest
that cannot be read or is refused, are masked again as they are printed. Other lines are printed
as given: for example, the "unknown role" error of an earlier-format manifest, which echoes the
role typed on the command line (in the current format that error passes the filter). That is a
guard against accidents, not a guarantee: a user name and password belong in a credential helper
or an ssh key, not in a manifest url ([docs/design.md](docs/design.md#sync) says what is masked
and what is not). A repo the manifest moves to another layer is not moved: `sync` prints the
`mv` command. A clone with commits not on `origin` is not rebased yet: when `origin`'s branch
has commits the clone lacks, `sync` prints the `git pull --rebase` command for a person to run,
and when it has none, the `git push` command that publishes the clone's commits (`sync` never
pushes). Both need `git` 2.23 or later, and `vcs` from vcs2l or vcstool, on `PATH`.
[docs/design.md](docs/design.md#sync) gives the rules and
[docs/design.md](docs/design.md#what-is-built) says how far they go.

`status` shows, for each distro, what the system directory holds against what the manifest
says: for each repo one state (expected, different, left alone, unusable, missing, skipped, or
not at its place), with its uncommitted changes, its commits not on `origin`, how far it is
behind `origin`'s branch, and where it was fetched from; and the repos `sync` recorded that are
no longer in the manifest. It changes nothing on disk and makes no network call of its own: it
answers from what each clone had when it was last fetched, starts no fsmonitor hook and lets a
partial clone fetch no missing object. It runs a clone's clean filters (Git LFS's, for one) as
`git status` does, so it counts the same files as changed as `git status` and `sync`; a filter
that writes or fetches is outside what it can promise. `status --json` prints the same as one
document a script can read, and the exit status is 1 when a repo that is not optional is
missing, not at its place or unusable. It needs `git` 2.23 or later on `PATH`, and not `vcs`.
[docs/design.md](docs/design.md#status) gives the states
and the few cases where `status` and the next `sync` read a repo differently.

`build` builds one distro's layers in order with `colcon`, each on top of the ones below it,
stops at the first layer that fails (`--keep-going` tries the later ones), and writes the one
`setup.bash` to source. It keeps a record of what it built, one file per distro in
`.repos-manifest/`, and trusts nothing else: a layer counts as built only while the built
layers below it are the ones it was built on. It sees only the `colcon` arguments given after
`--`, not package selection set in a file of `colcon` defaults or a mixin; it names each
defaults file `colcon` will read, and no mixin. A run with package selection or
`--cmake-target` after `--` only rebuilds layers that are built (not `--packages-skip` or
`--packages-ignore`, which build a whole layer but the packages they name: each layer's record
keeps the skip and ignore options given to its `colcon` when it was last built, whether or not
the layer has such packages). A
second `build` of the same distro while one (or the `colcon` it started), or a `sync` of that
distro, runs is refused, and
so is a build of a layer with a repo missing from disk that is not optional; [docs/design.md](docs/design.md#build) says what it builds, what it
refuses and what `setup.bash` sources. It needs `bash`, and `colcon` on `PATH` (empty and
relative entries are not searched) or installed in the same virtual environment as
repos-manifest.

```bash
repos-manifest resolve --manifest project11.manifest.yaml --role robot --distro jazzy --out ./out
repos-manifest validate --manifest project11.manifest.yaml
repos-manifest show project11.manifest.yaml --role robot --distro jazzy
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
