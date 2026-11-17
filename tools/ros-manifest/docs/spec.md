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
  manifest that extends another: `vcs` does not read a manifest's `extends`, and skips an
  entry that leaves out `type` or `url`.

We checked that `vcs` ignores keys it does not know, at the top level and inside a repo
entry, with vcs2l 1.1.7 and vcstool 0.3.0.

The suggested file name is `<name>.manifest.yaml`.

## Example

```yaml
version: 1

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
  ccomjhc_project11:
    type: git
    url: git@github.com:CCOMJHC/ccomjhc_project11.git
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

groups:
  simulation:
    default: exclude

roles:
  robot: {}
  developer:
    add: [simulation]
```

## Top-level keys

| Key | Required | Meaning |
|---|---|---|
| `repositories` | yes | The repos of the system, by name. |
| `version` | no | Version of this format. `1` if absent. |
| `extends` | no | One or more other manifests this one builds on. |
| `distros` | no | The distros this manifest covers. |
| `layers` | no | The ordered list of layers. |
| `groups` | no | The groups repos can belong to, and whether each is on by default. |
| `roles` | no | Named variants, each a choice of groups. |

A tool refuses a manifest whose `version` is higher than it knows. It warns about a
top-level key it does not know and carries on.

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
- `extends` matches repos by their whole key. A later manifest that changes a repo uses the
  key the earlier manifest gave it.

| Key | Required | Meaning |
|---|---|---|
| `type` | yes | As in a `.repos` file. The tools here support `git`. |
| `url` | yes | Where to fetch from. |
| `version` | no | The default branch, tag or commit. The remote's default branch if left out. |
| `absent` | no | `true` if the repo is not part of the system unless a distro says so. |
| `layer` | see Layers | The layer the repo belongs to. |
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
only on the distros that have an entry for it.

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
the list is an error. A distro named under a repo's `distros:` must be in the list.

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

Layers are optional. If `layers:` is absent, the manifest has one unnamed layer and no repo
may have a `layer:` key. A small project can start this way, down to a single repo, and add
layers when build times call for them. If `layers:` is present, every repo must name a layer
from the list.

Open: whether a repo with no `layer:` should go into a default layer instead of being an
error. The error is the current rule because it can be relaxed later without breaking a
manifest that is valid today.

## Groups and roles

A group is a named set of repos that can be switched on and off together. The top-level
`groups:` section names each group and gives its default, `include` or `exclude`. A repo
lists the groups it belongs to under its own `groups:` key, and each must be named in the
top-level section. A repo may be in several groups. A repo in no group is always part of the
system.

A role is a named variant. It starts from the group defaults and changes them:

- `add:` lists groups to switch on.
- `subtract:` lists groups to switch off.

A repo that is in several groups is part of the system if any of its groups is switched on.

If `roles:` is absent, the manifest has one unnamed role in which every group has its
default, and no role is given when resolving.

Resolving can also be given extra groups to switch on, on top of what the role selects. This
keeps roles about how a machine is used and leaves things like its hardware to groups. A
robot role on two hardware platforms is one role and two groups, not two roles.

```yaml
groups:
  simulation:
    default: exclude
  ben-hardware:
    default: exclude
  echoboat-hardware:
    default: exclude

roles:
  robot: {}
  developer:
    add: [simulation]
```

A machine resolves this for the role `robot` with the extra group `ben-hardware`.

Open: roles have not had a real design pass. The example above is the smallest thing that
separates a robot from a development machine. Whether a role should also be able to name
single repos, or pick layers, is undecided.

## Extends

`extends:` names one or more other manifests, each by its location.

```yaml
extends: https://raw.githubusercontent.com/CCOMJHC/unh_marine_autonomy/jazzy/project11.manifest.yaml
```

### Locations

A location says where a manifest file is. The format leaves this open: a location is either
a string or a mapping, and a tool may accept any form it knows how to read. A tool that meets
a location it cannot read says so and stops.

These three forms are the ones every tool is expected to read:

- A path on the local disk. A relative path is taken from the directory of the manifest that
  names it.
- An `http` or `https` URL of the file.
- A file in a git repo, given as a mapping with the repo's `url`, a `version` (a branch or
  tag; the repo's default branch if left out) and the `path` of the file in the repo. Any URL
  git can clone works, so a repo on a private server reached over ssh is named this way.

```yaml
extends:
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
- A group or a role replaces the earlier one of the same name as a whole.
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
extends: released.manifest.yaml
repositories:
  autoware_core:
    version: main
    distros: {}
```

An empty block also drops any `absent: true` the earlier entry had under a distro. A later
entry that changes one distro gives the whole block, with the other distros repeated.

A parent may itself extend other manifests. A chain that comes back to a manifest it has
already read is an error.

vcs2l has the same "later wins" rule for `extends` in `.repos` files (on its main branch at
the time of writing, for local files only). It differs in one way: vcs2l replaces a repo
entry as a whole, where a manifest merges its keys. For plain `.repos` entries, which have
only `type`, `url` and `version`, the result is the same when the later entry gives all
three.

Pointing a repo at a fork is done with `extends`: a developer's manifest extends the
published one and gives the repo a different `url`.

```yaml
extends: project11.manifest.yaml
repositories:
  unh_marine_navigation:
    url: https://github.com/rolker/unh_marine_navigation.git
```

Only the first manifest in a chain has to be complete. An entry in a later one may leave out
the required keys when an earlier manifest gives them.

Adding a repo to a group of the published manifest works the same way as adding it to a
layer: the new repo names the group.

```yaml
extends: project11.manifest.yaml
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

## Not in the format

- Package dependencies. For ROS projects they stay in each package's `package.xml` and with
  `rosdep`.
- System packages, udev rules and other machine setup.
- Build arguments. They are given to the build tool.
- Which packages of a repo are built. Groups and roles select whole repos.
- Content that is not in a repo, such as models or data downloaded at build time.
- The exact commits a machine has checked out. A tool can record them as a manifest that
  extends the one in use and gives each repo a commit as its `version`.

## Open questions

- Whether a manifest that extends another can remove a repo outright, as opposed to leaving
  it out through a group.
