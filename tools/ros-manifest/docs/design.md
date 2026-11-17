# Design

Status: draft. This is the design we are working towards. What exists today is listed under
"What is built" at the end. The prototype's command is still called `ros-manifest`, the
tool's earlier name.

The format of a manifest is in [spec.md](spec.md). This document is about the tools.

## The parts

- The specification of the manifest format.
- A resolver: given a manifest, a role, a distro and any extra groups, it works out which
  repos a machine gets, at which version, in which layer. It reads and writes files and
  fetches manifests. It does not clone repos or build anything.
- A set of commands on top of the resolver that fetch, update and build a system by calling
  `vcs` and `colcon`.

Someone who only wants `.repos` files uses the resolver and stops there. The other commands
are one way to use what it produces.

## The system directory

A system is set up in one directory. Each layer is a colcon workspace inside it.

```
my_system/
  .repos-manifest/
    config.yaml      what init recorded
    resolved/        the .repos files from the last resolve, and the layer order
  underlay/
    src/             the repos of the layer
    build/ install/ log/
  core/
    src/
    ...
  setup.bash         sources the layers that are built
```

A manifest without layers gives an ordinary colcon workspace: `src/`, `build/`, `install/`
and `log/` directly in the system directory, with `.repos-manifest/` beside them. For a
small project the tools then do little more than `vcs` and `colcon` do, and the project can
add layers later.

The commands find the system directory by walking up from the current directory until they
find `.repos-manifest/`, so they can be run from anywhere inside it.

The system directory is not a repo. Nothing in `.repos-manifest/` is ever committed.

### config.yaml

```yaml
manifest: https://raw.githubusercontent.com/CCOMJHC/unh_marine_autonomy/jazzy/project11.manifest.yaml
local_manifest: core/src/unh_marine_autonomy/project11.manifest.yaml
role: robot
groups: [ben-hardware]
distro: jazzy
fetch_from:
  prefix: https://github.com/rolker/
  fallback: true
remotes:
  field: git@git.example.org:field/
```

| Key | Meaning |
|---|---|
| `manifest` | Where the manifest is. See "Where the manifest comes from". |
| `local_manifest` | Optional. A path inside the system directory that is used instead, once that file exists. |
| `role` | The role of this machine, if the manifest has roles. |
| `groups` | Optional. Extra groups to switch on, on top of the role. |
| `distro` | The distro of this system, if the manifest has distros. |
| `fetch_from` | Optional. Another place to clone the repos from. See "Where repos are fetched from". |
| `remotes` | Optional. Extra remotes to add to every clone. See "Extra remotes". |

`role`, `groups` and `distro` are facts about the machine, which is why they are recorded here and not
in the manifest.

### More than one distro

A development machine often carries two distros of the same system at once, for example the
current release and the next one. The system directory can then have one directory per
distro, each holding its own layers and its own setup file:

```
my_system/
  .repos-manifest/
    config.yaml
    resolved/
      jazzy/
      rolling/
  jazzy/
    underlay/
    core/
    setup.bash
  rolling/
    underlay/
    core/
    setup.bash
```

`config.yaml` lists the distros in place of naming one:

```yaml
distros: [jazzy, rolling]
```

Everything else in `config.yaml` applies to each distro. `local_manifest` is then a path
inside the distro's directory, so each distro uses the copy of the manifest in its own
checkout once it exists. The copies may differ, as the copies on a project's distro branches
may.

A command run inside a distro's directory acts on that distro. Run at the top of the system
directory, `sync` and `status` act on every distro in turn, or on the ones named with
`--distro`.

`build` acts on one distro at a time: the one whose directory it is run in, or the one named
with `--distro`. Each distro is built in its own environment, which the person sets up
before building, for example by sourcing that distro's setup file, so one shell can build
only one of them.

The layout is chosen at `init`. A system directory set up for one distro has no distro
directories, as in the first diagram. A manifest without layers gives each distro directory
an ordinary colcon workspace.

## Where the manifest comes from

A manifest is a file, so `manifest` points at a file. The tools read the three kinds of
location the specification names:

- a path on the local disk;
- an `http` or `https` URL;
- a file in a git repo, given by the repo's URL, a branch or tag, and the path in the repo.

```
repos-manifest init https://example.org/project11.manifest.yaml --role robot --distro jazzy
repos-manifest init git@git.example.org:field/unh_marine_autonomy.git \
    --manifest-version jazzy --manifest-path project11.manifest.yaml --role robot --distro jazzy
```

The git form is read by cloning the one commit and taking the file out of it, with `git` as
it is set up on the machine. Whatever lets a person clone that repo by hand lets the tools
read the manifest: ssh keys, an ssh agent, entries in `~/.ssh/config`, a credential helper.
When a command is run at a terminal and git or ssh needs a password or passphrase, it asks.
When there is no terminal, as in CI, it fails with a message and does not wait.

The git form is also the one `fetch_from` can act on, because the tools know which repo the
manifest is in. A field machine can be given the published location of the manifest and a
`fetch_from` prefix, and reads the manifest from the private server.

Other kinds of location, such as copying a file from a machine over ssh without git, are not
supported. A person can copy the file by hand and give its path.

Often the manifest lives in one of the repos it lists. Before the first sync that repo is not
on the machine, so the manifest is read from its URL. After the first sync there is a copy in
the system directory, and `local_manifest` says where. From then on the local copy is the one
that counts: a developer can edit it, try it, and send the change through the repo's normal
review.

A manifest that is not in any of the system's repos needs no `local_manifest`. It stays where
it is, on a disk or at a URL.

`manifest` and `local_manifest` can be changed after `init`, by editing `config.yaml`. A
project that has no manifest yet can be set up from one written in a scratch directory. When
the manifest is later added to one of the project's repos, `local_manifest` is set to its
place in the checkout.

Only the checkout in the system directory counts as the local copy. A copy in another clone
or another branch of the same repo is not looked at.

The same rule applies to `extends`. Each parent is a location of one of the three kinds, and
a relative path is taken from the manifest that names it. A local manifest that extends a
parent next to it in the same repo reads the parent from the local disk too.

## Commands

| Command | What it does |
|---|---|
| `init` | Records the manifest, role and distro in a new system directory, then syncs. |
| `resolve` | Writes the `.repos` files for the role and distro. |
| `sync` | Resolves, then fetches and updates the repos of each layer. |
| `build` | Builds each layer in order. |
| `status` | Shows what the system directory holds against what the manifest says. |
| `validate` | Checks a manifest against the specification without resolving it for a machine. |

After `init`, the other commands take no arguments in the common case. A person setting up a
machine types:

```
repos-manifest init <manifest> --role robot --with ben-hardware --distro jazzy
repos-manifest build
source setup.bash
```

and later, to update:

```
repos-manifest sync
repos-manifest build
```

`resolve` and `validate` also work outside a system directory, with the manifest, role and
distro given as arguments. That is the form a CI job or another tool uses.

### resolve

Reads the manifest and everything it extends, applies the role and the distro, and writes
into `.repos-manifest/resolved/`:

- one `.repos` file per layer, with `type`, `url` and `version` for each repo;
- the order of the layers;
- which repos are optional.

Each file starts with a comment that says which manifest, role and distro it came from.

### sync

1. Resolve, using the manifest as it is on the machine now.
2. For each layer in order, run `vcs import` on the layer's `.repos` file into the layer's
   `src/`.
3. Look at the manifest again. If its content changed during step 2, because the repo that
   holds it was updated, resolve and do step 2 once more.

Step 3 happens at most once per sync. If the manifest changes again during the second pass,
`sync` says so and stops; the next `sync` picks it up.

Sync does not discard work. A repo with uncommitted changes, or on a branch other than the
one the manifest names, is left as it is and reported. A repo that is no longer in the
manifest is left on disk and reported; `sync` does not delete it.

An optional repo that cannot be fetched is skipped and reported. Any other repo that cannot
be fetched is an error. A skipped repo is listed every time, by `sync` and by `status`, so
that a repo missing because the network was down is not mistaken for one the machine has no
access to.

### build

For each layer in order, run `colcon build` in the layer's directory with the layers before
it sourced. Then write `setup.bash` in the system directory, which sources the last layer
that was built.

The first layer is built in the environment `build` is run in. The person sets that up
first, for example by sourcing the setup file of the ROS distro. `build` does not do it for
them.

Sourcing the one `setup.bash` is enough to use the system. The setup file `colcon` writes for
a layer also sets up every environment that was sourced when the layer was built, so the
last layer brings in the layers under it and the environment the first layer was built in.

`build` with layer names builds only those layers.

How the code is built, such as a debug or a release build, is not a distro and not part of
the manifest. It stays with `colcon`:

- Arguments after `--` are passed to `colcon` for every layer built.
- `colcon` reads a `colcon_defaults.yaml` file from the directory it is run in. A person
  who wants a layer always built a certain way puts that file in the layer's directory.
  `build` does nothing special for it. (Checked with colcon-defaults 0.2.9.)

A layer that has no repos on this machine, because all of them were left out by the role or
skipped as optional, is skipped.

### status

Shows the manifest in use, the role and the distro, and for each repo whether it matches the
manifest: on the expected version, on a different one, with local changes, missing, skipped
as optional, or present but no longer in the manifest. It also says whether each layer has
been built since its repos last changed.

`status --exact` writes the exact commit of every repo, by calling `vcs export --exact`. This
is the record of what a machine was running.

## Where repos are fetched from

A published manifest points at the released repos, for example under
`github.com/CCOMJHC`. Two kinds of machine fetch from somewhere else without the manifest
having to say so:

- A developer works in forks of some of the repos.
- A field machine has no access to the public host. It clones from a private git server and
  pushes its fixes back there.

`fetch_from` in `config.yaml` covers both. It names a place by a URL prefix. For each repo,
the tools build another URL from the prefix, the repo's name (the last part of its published
URL) and `.git`.

```yaml
# a field machine: everything comes from the private server
fetch_from:
  prefix: git@git.example.org:field/
  fallback: false
```

```yaml
# a developer: my fork where I have one, the published repo otherwise
fetch_from:
  prefix: https://github.com/rolker/
  fallback: true
```

With `fallback: false`, every repo is cloned from the other place, and a repo that is missing
there is an error. A field machine never reaches for the public host without being told to.

With `fallback: true`, a repo is cloned from the other place if it exists there and has the
version the manifest names, where it names one, and from the published URL otherwise. Creating a fork changes
what the next `sync` fetches. That is intended: a collaborator who decides to work on a repo
forks it, syncs, and is on their fork.

The repo is cloned with the place it came from as `origin`. When that is not the published
URL, and `fallback` is true, the published repo is added as a remote named `upstream`.

Because only the repo's name is kept, repos from different owners all land side by side at
the other place. Two repos in a manifest with the same name and different owners cannot both
be fetched this way, and `resolve` says so.

The rule applies to the repo that holds the manifest like any other repo. A repo entry that
the machine's own manifest points somewhere with `extends` is used as written; `fetch_from`
only applies to URLs that come from the published manifest unchanged. `status` shows where
each repo was fetched from.

A machine that should run exactly what is published leaves `fetch_from` unset.

When the place a repo comes from changes for a repo that is already cloned, because a fork
appeared or `fetch_from` was edited, `sync` changes the clone's remotes to match. It does
not clone again, and the working files and local branches stay as they are.

With `fallback: true`, the fork is where the repo is fetched from, so its branches have to
be kept up to date by their owner. That suits a fork that carries a developer's own line of
work. For a fork that exists only to send a change back, an extra remote is the better fit:
the clone keeps following the published repo, and the change is pushed to the fork by name.
See "Extra remotes".

## Extra remotes

A development machine that deploys to field machines keeps its clones on the public host and
also needs the private server on every clone: to push what is to be deployed, and to fetch
the fixes field machines made.

```yaml
remotes:
  field: git@git.example.org:field/
```

Each entry is a remote name and a URL prefix. `sync` adds the remote to every clone, with
the URL built the same way as for `fetch_from`. It does not fetch from it or push to it.
Pushing, and bringing field changes back for review, are done with `vcs`, with `git`, or by
whatever workflow the project has.

`sync` leaves alone any remote it did not add.

## Work done on a field machine

A field machine is where fixes are made under time pressure, directly on the branch the
manifest names, and pushed to the private server. The tools have to fit that:

- `sync` keeps local commits. On a repo that is on the manifest's branch, it fetches and
  moves the branch forward only if that loses nothing. A branch that has gone a different
  way from its remote is reported and left for a person.
- `status` shows repos with commits that are not on the remote yet, so nothing made in the
  field is forgotten there.
- A manifest that names exact commits or tags leaves each repo without a local branch. That
  is a good record of what ran, and a poor base for field fixes. A field machine that will be
  worked on is set up from a manifest that names branches.

### A branch for field work (considered, not decided)

Committing field fixes to the manifest's own branch is the quickest way to work, and it
means that branch on the private server drifts from the published one. An alternative is to
keep field fixes on a branch of their own, either one shared by all field machines or one per
machine.

One optional setting would support both:

```yaml
prefer_version: field
```

For each repo, `sync` would use that branch where it exists at the place the repo is fetched
from, and the manifest's version otherwise. This is the same shape as `fetch_from` with a
fallback. A shared branch and a per-machine branch differ only in the name a machine is
given.

- A repo nobody has fixed in the field has no such branch and stays on the manifest's
  version.
- The first fix in a repo is made by creating the branch and pushing it, by hand or by the
  project's own workflow. Other machines move to it on their next `sync`.
- When the fixes have been reviewed and merged into the published branch, the field branch
  is deleted on the server. Machines whose copy of it holds nothing unmerged go back to the
  manifest's version on their next `sync`.

The manifest's branch on the private server then stays the same as the published one, and
the field branch holds exactly what has not been reviewed yet.

What the tools would not do is merge new published work into a field branch. A field branch
that has fallen behind is brought up to date by a person or by the project's workflow.

## Three machines, one manifest

These walk through the settings above for one system. The published manifest lists every
repo of the system, with a `simulation` and a `ui` group that are off by default, one
hardware group per platform, and a private repo marked optional.

### A development machine

```
repos-manifest init https://github.com/example/system.git --manifest-version rolling \
    --manifest-path system.manifest.yaml --role developer --distro jazzy --distro rolling
```

Besides the manifest's location, `config.yaml` then holds:

```yaml
role: developer
distros: [jazzy, rolling]
fetch_from:
  prefix: https://github.com/developer/
  fallback: true
remotes:
  field: git@git.example.org:field/
```

The developer role switches on `simulation` and `ui`. Each distro has its own directory.
Repos the developer has forked come from the fork, with the published repo as `upstream`;
the rest come from the published URL. The private repo is fetched because this developer has
access to it. Every clone has a `field` remote for deploying to and collecting from field
machines.

### A field machine

Besides the manifest's location, `config.yaml` holds:

```yaml
role: robot
groups: [echoboat-hardware]
distro: jazzy
fetch_from:
  prefix: git@git.example.org:field/
  fallback: false
```

The robot role leaves `simulation` and `ui` off, so those layers are empty and are not
built. The one hardware group brings in the drivers for this platform and no other. Every
repo, and the manifest itself, comes from the private server. Fixes made on the machine are
committed on the manifest's branches and pushed to the server, and `sync` keeps them.

Without roles, groups and `fetch_from`, this machine needs its own copy of the manifest:
the same repos at the same versions with every URL rewritten and half the entries deleted,
kept in step with the published one by hand.

### A collaborator with their own robot

The collaborator writes a manifest in their own repo:

```yaml
extends:
  url: https://github.com/example/system.git
  version: jazzy
  path: system.manifest.yaml
layers: [my_robot]
groups:
  my-robot-hardware:
    default: exclude
repositories:
  my_robot_bringup:
    type: git
    url: https://github.com/collaborator/my_robot_bringup.git
    version: jazzy
    layer: my_robot
    groups: [my-robot-hardware]
```

They do not clone the published system first, and they do not fork its manifest. Their
development machine sets `fetch_from` to their own account with `fallback: true`, so the
two repos of the published system they have forked to send changes come from their forks.
Their robot uses the role `robot` with the extra group `my-robot-hardware`.

## What the tools rely on

- `vcs`, from vcs2l, to fetch and update repos and to record exact commits.
- `colcon`, to build a layer.
- `git`, to check whether a repo exists at another place and to add remotes.
- Python with PyYAML.

The tools call `vcs` and `colcon` as commands. They do not import them as libraries.

Resolving `extends` is done by the resolver and not left to `vcs`, because a manifest can
extend one at a URL and because the manifest keys are merged.

## Not covered

- Package dependencies and system packages. `rosdep` covers these, run by the person or the
  script that sets up the machine.
- Running a distro the host OS does not support, in a container or otherwise. `distro` is
  recorded, and the commands assume the environment they run in can build it.

## What is built

A prototype has `resolve` and `validate` for an earlier shape of the format, where repos are
nested under their layer and the version key is `ref`. It also has three things this design
drops: a `packages:` section with package dependencies, roles defined by starting packages,
and a cache of fetched parent manifests that is kept between runs.

`init`, `sync`, `build`, `status`, the system directory, fetching from another place and
extra remotes are not built.

## Open questions

- What happens to a system directory when its manifest gains layers. The repos move from
  `src/` to `<layer>/src/`. `sync` could move them, or say what to move.
- How `sync` updates a repo that is already cloned without touching local work, using `vcs`.
  `vcs import` and `vcs pull` each do part of it, and what they do to a repo with local
  changes needs testing.
- With `fallback: true`, how often to ask whether a repo exists at the other place. Asking
  for every repo on every sync costs a network call per repo.
- With more than one distro, whether a distro needs its own settings, such as a different
  `manifest` URL for its first sync or a different role.
- Whether `build` should stop at the first layer that fails or carry on with layers that do
  not depend on it. The manifest does not say which layers depend on which, only their
  order, so stopping is the safe rule.
