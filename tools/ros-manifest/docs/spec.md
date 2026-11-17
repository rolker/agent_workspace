# Manifest format

Status: draft. This describes the format we are moving to. The prototype in `src/` still
reads an earlier shape, and sections marked "Open" are not settled.

## What a manifest is

A system manifest (from here on, a manifest) is a YAML file that describes the repos of a
system and its variants. Given a role and a distro, a manifest resolves to plain `.repos`
files, one per layer, that `vcs import` can fetch.

A manifest is a superset of a `.repos` file. It keeps the `repositories:` list that `vcs`
reads and adds keys that `vcs` ignores. Two things follow from that:

- A `.repos` file is already a valid manifest. It describes a system with one variant and
  one layer.
- `vcs import` on a manifest that stands on its own still fetches its repos, each at its
  default version into one directory. It knows nothing of roles, distros or layers, so it
  also fetches repos that a role or a distro would leave out. It is not a way to use a
  manifest that builds on another: `vcs` does not read a manifest's `base`, and skips an
  entry that leaves out `type` or `url`.

We checked that `vcs` ignores keys it does not know, at the top level and inside a repo
entry, with vcs2l 1.1.7 and vcstool 0.3.0.

The suggested file name is `<name>.manifest.yaml`.

## Example

```yaml
format: 1

distros: [jazzy, rolling]

layers:
  - underlay
  - core
  - simulation

repositories:
  geographic_info:
    type: git
    url: https://github.com/ros-geographic-info/geographic_info.git
    version: ros2
    layer: underlay
  unh_marine_autonomy:
    type: git
    url: https://github.com/CCOMJHC/unh_marine_autonomy.git
    version: jazzy
    layer: core
    distros:
      rolling:
        version: rolling
  site_config:
    type: git
    url: git@github.com:example/site_config.git
    version: jazzy
    layer: core
    optional: true
  vrx:
    type: git
    url: https://github.com/CCOMJHC/vrx.git
    version: jazzy
    layer: simulation
    groups: [simulation]
    distros:
      rolling:
        absent: true

groups: [simulation]

roles:
  robot: []
  developer: [simulation]
```

## Top-level keys

| Key | Required | Meaning |
|---|---|---|
| `repositories` | yes, in the first manifest of a chain | The repos of the system, by name. |
| `format` | no | Version of this format. `1` if absent. |
| `base` | no | One or more other manifests this one builds on. |
| `distros` | no | The distros this manifest covers. |
| `layers` | no | The ordered list of layers. |
| `groups` | no | The names of the groups repos can belong to. |
| `roles` | no | Named variants, each a list of the groups it switches on. |

A tool refuses a manifest whose `format` is higher than it knows. It warns about a
top-level key it does not know and carries on.

Everywhere in a manifest, `version` means a branch, a tag or a commit, as in a `.repos`
file.

## Repos

Each entry under `repositories:` is a repo. The key is the path the repo is fetched into, as
in a `.repos` file, and it is unique in the manifest. It may be the repo's name or a path
with directories in it:

```yaml
repositories:
  marine_ais:
    type: git
    url: https://github.com/CCOMJHC/marine_ais.git
  drivers/sonar/imagenex_deltat:
    type: git
    url: https://github.com/CCOMJHC/imagenex_deltat.git
```

Two things follow from the key being a path:

- With layers, the path is inside the repo's layer. A key that starts with the name of its
  own layer repeats that name on disk.
- `base` matches repos by their whole key. A later manifest that changes a repo uses the
  key the earlier manifest gave it.

| Key | Required | Meaning |
|---|---|---|
| `type` | yes | As in a `.repos` file. The tools here support `git`. |
| `url` | yes | Where to fetch from. |
| `version` | no | The default branch, tag or commit. The remote's default branch if left out. |
| `absent` | no | `true` if the repo is not part of the system unless a distro says so. |
| `layer` | no | The layer the repo belongs to. The unnamed first layer if left out. |
| `groups` | no | The groups the repo belongs to. |
| `distros` | no | Per-distro differences from the default. |
| `optional` | no | `true` if the system is still usable without this repo. |

### Versions and distros

A repo's `version` is its default: a branch, a tag or a commit. A repo with no `version`
follows the default branch of its remote, as in a `.repos` file. That suits a repo whose one
branch works for every distro. What a machine gets then depends on a setting at the remote,
so a manifest for a deployed system names its versions.

Under `distros:`, each key is a distro name and its entry says what is different on that
distro:

- `version: <name>`: use this branch, tag or commit on that distro.
- `absent: true`: the repo is not part of the system on that distro.

`absent: true` on the repo itself turns the default around: the repo is part of the system
only on the distros that have an entry for it. Any entry counts, an empty one included,
unless the entry itself says `absent: true`.

```yaml
repositories:
  # on every distro, following the remote's default branch
  marine_tools:
    type: git
    url: https://github.com/CCOMJHC/marine_tools.git

  # on every distro, with a different branch on rolling
  unh_marine_autonomy:
    type: git
    url: https://github.com/CCOMJHC/unh_marine_autonomy.git
    version: jazzy
    distros:
      rolling:
        version: rolling

  # on every distro except rolling
  vrx:
    type: git
    url: https://github.com/CCOMJHC/vrx.git
    version: jazzy
    distros:
      rolling:
        absent: true

  # on jazzy only
  BehaviorTree.CPP:
    type: git
    url: https://github.com/BehaviorTree/BehaviorTree.CPP.git
    absent: true
    distros:
      jazzy:
        version: 7119df95a17086f55e3690cf8d7b7663b59319d0
```

The last form is for a dependency that has to be built from source on some distros and is
installed as a package on the others.

### Optional repos

A repo marked `optional: true` may fail to fetch without stopping the rest. The tool reports
that it was skipped. For example, marking a private repo optional allows the same manifest to
be used to set up a public version of a project.

## Distros

A distro is a major version of the project that goes with a version of something underneath
it: a ROS distro, an operating system release, a firmware release. What marks a distro is
that it is built in its own environment, apart from the others. A choice that only changes
how the same code is built, such as debug or release, is not a distro and is not in the
manifest.

`distros:` lists the distros the manifest covers. Resolving for a distro that is not in
the list is an error. An entry under a repo's `distros:` for a distro that is not in the
list is ignored, so a copy of a manifest that lists fewer distros stays valid.

If `distros:` is absent, the manifest covers one unnamed variant: no repo may have a
`distros:` key, and no distro is given when resolving. This is the plain `.repos` case.

Copies of a manifest on different branches may list different distros. A copy on a `jazzy`
branch can list only `jazzy` while the copy on `rolling` lists them all.

## Layers

`layers:` is an ordered list of layer names. Each repo names its layer with `layer:`.
Resolving writes one `.repos` file per layer, in that order.

The suggested layout, and the one the tools here use, makes each layer its own colcon
workspace built on top of the ones before it. The format only says that layers are ordered
groups of repos; it does not say what a tool does with them.

Layers are optional. A repo that names no layer is in the unnamed first layer, which comes
before every named one. A manifest with no `layers:` at all has only that layer. A small
project can start this way, down to a single repo, and add layers when build times call for
them, without touching the repos it already has. A `layer:` that is not in the `layers:`
list is an error.

A manifest that builds on another can give a layer to a repo the earlier one left without one,
like any other key:

```yaml
base: small_project.manifest.yaml
layers: [drivers, my_robot]
repositories:
  sonar_driver:
    layer: drivers
```

The unnamed layer is always first, so this moves a repo up, not down. To put a new layer
under the existing repos, each of them is given a layer.

## Groups and roles

A group is a named set of repos that is switched on or off together. Every group is off
unless something switches it on. A repo in no group is always part of the system, so a
group is only needed for repos that some machines should not have.

The top-level `groups:` list names the groups. A repo lists the groups it belongs to under
its own `groups:` key. Every group that is named anywhere, on a repo, in a role or as an
extra group when resolving, must be in the top-level list, so that a misspelt name is
caught. A repo may be in several groups, and is part of the system if any of them is on.

A role is a named variant: a list of the groups it switches on.

```yaml
groups: [simulation, ui, ben-hardware, echoboat-hardware]

roles:
  robot: []
  developer: [simulation, ui]
```

Resolving can also be given extra groups to switch on, on top of what the role selects. This
keeps roles about how a machine is used and leaves things like its hardware to groups. A
robot role on two hardware platforms is one role and two groups, not two roles. A machine
resolves the manifest above for the role `robot` with the extra group `ben-hardware`.

If `roles:` is absent, the manifest has one unnamed role that switches on no group, and no
role is given when resolving. If `roles:` is present, a role is given when resolving.

Open: whether a role should also be able to name single repos, or pick layers.

## Building on another manifest

`base:` names one or more other manifests that this one builds on, each by its location.

```yaml
base: https://raw.githubusercontent.com/CCOMJHC/unh_marine_autonomy/jazzy/project11.manifest.yaml
```

### Locations

A location says where a manifest file is. The format leaves this open: a location is either
a string or a mapping, and a tool may accept any form it knows how to read. A tool that meets
a location it cannot read says so and stops.

These three forms are the ones every tool is expected to read:

- A path on the local disk. A relative path is taken from the directory of the manifest that
  names it.
- An `http` or `https` URL of the file. Plain `http` gives no protection against the file
  being changed on the way, so it is for networks the person trusts.
- A file in a git repo, given as a mapping with the repo's `url`, a `version` (a branch or
  tag; the repo's default branch if left out) and the `path` of the file in the repo. Any URL
  git can clone works, so a repo on a private server reached over ssh is named this way.

```yaml
base:
  url: git@git.example.org:field/unh_marine_autonomy.git
  version: jazzy
  path: project11.manifest.yaml
```

### How manifests combine

The parents are read first, in the order given, then the manifest itself. Where the same
name appears more than once, the later one wins:

- A repo entry is merged with the earlier entry of the same name, key by key. A key the later
  entry gives replaces the earlier value of that key as a whole; a key it does not give keeps
  the earlier value. An entry that gives only `url` changes where the repo is fetched from
  and nothing else.
- A role replaces the earlier one of the same name.
- `groups:` adds to the earlier list.
- `layers:` adds to the earlier list. A layer already in the list keeps its place, and new
  layers go on the end in the order given.
- `distros:`, when present, replaces the earlier list.

A later manifest cannot put a layer below an earlier one or reorder the earlier layers. It
does not need to for the build to be correct: the earlier manifest's repos cannot depend on
repos it does not know about. A later manifest that needs a new repo low in the stack adds
it to an existing layer.

A repo's `distros:` block is one key, so it is kept or replaced as a whole. A later entry
that gives a new `version` and no `distros:` changes the default and keeps the earlier
per-distro entries. To have the new version on every distro, the later entry also gives an
empty `distros:` block:

```yaml
base: released.manifest.yaml
repositories:
  autoware_core:
    version: main
    distros: {}
```

An empty block also drops any `absent: true` the earlier entry had under a distro. A later
entry that changes one distro gives the whole block, with the other distros repeated.

A parent may itself build on other manifests. A chain that comes back to a manifest it has
already read is an error.

vcs2l is adding an `extends` key to `.repos` files (on its main branch at the time of
writing) that does part of this: a file builds on other local files, and a later entry
replaces an earlier one as a whole. A manifest's key has a different name because it behaves
differently. A parent can be at a URL or in a git repo, the keys of an entry are merged, and
layers, groups and roles combine too. With a different name, `vcs` never mistakes one for
the other.

Pointing a repo at a fork is done with `base`: a developer's manifest builds on the
published one and gives the repo a different `url`.

```yaml
base: project11.manifest.yaml
repositories:
  unh_marine_navigation:
    url: https://github.com/rolker/unh_marine_navigation.git
```

Only the first manifest in a chain has to be complete. An entry in a later one may leave out
the required keys when an earlier manifest gives them, and a later manifest that adds no
repo needs no `repositories:` at all. An entry whose key matches nothing earlier is a new
repo and has to be complete; this catches a misspelt key.

Adding a repo to a group of the published manifest works the same way as adding it to a
layer: the new repo names the group.

```yaml
base: project11.manifest.yaml
layers: [my_robot]
repositories:
  my_robot_sim:
    type: git
    url: https://github.com/example/my_robot_sim.git
    version: jazzy
    layer: my_robot
    groups: [simulation]
```

## What resolving produces

Given a manifest, a role and a distro where the manifest has them, and any extra groups,
resolving produces:

- one plain `.repos` file per layer, holding only `type`, `url` and `version` for the repos
  that the role and distro select;
- the order of the layers;
- which repos are optional.

How these are laid out on disk belongs to the tools, not to the format. See the design
document.

## Reading a manifest before using it

A manifest names repos whose code is about to be built and run, so it deserves the same care
as any code taken from somewhere else: read it before using it. A manifest is as trusted as
the code it points at, and a tool does not try to protect a person from repos they chose.

A tool does make sure that a manifest does what it appears to say, and that nothing happens
outside the place the person chose before anything is built. It checks these things and
refuses a manifest that fails one:

- The file is loaded as data. Loading a manifest never runs code.
- Everything lands inside the directory the system is set up in, at a place of its own.
  - A repo's key is a relative path. No part of it is `..` or `.git`, and no key is the
    start of another key's path, so one repo is never cloned inside another.
  - The name of a layer, a distro, a group or a role is a single word: letters, digits, `_`
    and `-`, starting with a letter.
  - A layer is not named `src`, `build`, `install` or `log`. Those names are used for the
    directories of the unnamed layer.
- `git` is not handed anything that makes it run a program.
  - A `url`, a `version` and the `path` of a location do not start with `-`, so `git` cannot
    read one as an option. The `path` of a location has no `..` in it.
  - A `url` uses a transport that only fetches: `https`, `http`, `ssh`, the `user@host:path`
    form, or a path on the local disk. Others are refused; `git` has transports that run a
    command.
  - These apply to a repo and to a location named under `base:` alike.
- The file has no invisible characters and none that change the direction of text. They can
  make a file read differently from what it does.

A manifest that builds on others is only as readable as the whole chain. A tool can show the
combined result for a machine; see `show` in the design document.

## Not in the format

- Package dependencies. For ROS projects they stay in each package's `package.xml` and with
  `rosdep`.
- System packages, udev rules and other machine setup.
- Build arguments. They are given to the build tool.
- Which packages of a repo are built. Groups and roles select whole repos.
- Content that is not in a repo, such as models or data downloaded at build time.
- The exact commits a machine has checked out. A tool can record them as a manifest in which
  each repo's `version` is a commit.

## Open questions

- Whether a manifest that builds on another can remove a repo outright, as opposed to leaving
  it out through a group.
