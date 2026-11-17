# Manifest format

Status: draft. This describes the format we are moving to. The prototype in `src/` still
reads an earlier shape, and sections marked "Open" are not settled.

## What a manifest is

A system manifest (from here on, a manifest) is a YAML file that describes the repos of a
system and its variants. Given a role and a ROS distro, a manifest resolves to plain `.repos`
files, one per layer, that `vcs import` can fetch.

A manifest is a superset of a `.repos` file. It keeps the `repositories:` list that `vcs`
reads and adds keys that `vcs` ignores. Two things follow from that:

- A `.repos` file is already a valid manifest. It describes a system with one variant and
  one layer.
- `vcs import` on a manifest still works. It fetches every repo at its default version into
  one directory, with no role, distro or layer applied.

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
| `distros` | no | The ROS distros this manifest covers. |
| `layers` | no | The ordered list of layers. |
| `groups` | no | The groups repos can belong to, and whether each is on by default. |
| `roles` | no | Named variants, each a choice of groups. |

A tool refuses a manifest whose `version` is higher than it knows. It warns about a
top-level key it does not know and carries on.

## Repos

Each entry under `repositories:` is a repo. The key is the directory the repo is fetched
into, as in a `.repos` file. It is usually just the repo's name, and it is unique in the
manifest.

| Key | Required | Meaning |
|---|---|---|
| `type` | yes | As in a `.repos` file. The tools here support `git`. |
| `url` | yes | Where to fetch from. |
| `version` | yes | The default branch, tag or commit. |
| `layer` | see Layers | The layer the repo belongs to. |
| `groups` | no | The groups the repo belongs to. |
| `distros` | no | Per-distro differences from the default. |
| `optional` | no | `true` if the system is still usable without this repo. |

`vcs` allows an entry without `version`. A manifest does not, so that what a machine gets
never depends on what a remote's default branch happens to be.

### Per-distro versions

Under `distros:`, each key is a distro name and its value is one of:

- `version: <name>`: use this branch, tag or commit for that distro.
- `absent: true`: the repo is not part of the system on that distro.

A distro that is not named gets the default `version`.

### Optional repos

A repo marked `optional: true` may fail to fetch without stopping the rest. The tool reports
that it was skipped. For example, marking a private repo optional allows the same manifest to
be used to set up a public version of a project.

## Distros

`distros:` lists the ROS distros the manifest covers. Resolving for a distro that is not in
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

If `layers:` is absent, the manifest has one unnamed layer and no repo may have a `layer:`
key. If `layers:` is present, every repo must name a layer from the list.

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

`extends:` names one or more other manifests, each by path or URL. A relative path is taken
from the directory of the manifest that names it.

```yaml
extends: https://raw.githubusercontent.com/CCOMJHC/unh_marine_autonomy/jazzy/project11.manifest.yaml
```

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

A parent may itself extend other manifests. A chain that comes back to a manifest it has
already read is an error.

vcs2l has the same "later wins" rule for `extends` in `.repos` files (on its main branch at
the time of writing, for local files only). It differs in one way: vcs2l replaces a repo
entry as a whole, where a manifest merges its keys. A later entry that gives `type`, `url`
and `version` behaves the same in both.

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

- Package dependencies. They stay in each package's `package.xml` and with `rosdep`.
- System packages, udev rules and other machine setup.
- The exact commits a machine has checked out. `vcs export --exact` records those.

## Open questions

- Whether a manifest that extends another can remove a repo outright, as opposed to leaving
  it out through a group.
