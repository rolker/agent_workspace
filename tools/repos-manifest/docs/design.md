# Design

Status: draft. This is the design we are working towards. What exists today is listed under
"What is built" at the end.

The format of a manifest is in [spec.md](spec.md). This document is about the tools.

## The parts

- The specification of the manifest format.
- A resolver: given a manifest, a role, a distro and any extra groups, it works out which
  repos a machine gets, at which version, in which layer. It reads and writes files and
  fetches manifests. It does not clone the system's repos or build anything.
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
    state.yaml       the version and commit sync last put each repo on
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
small project the tools then do little more than `vcs` and `colcon` do.

That workspace is the unnamed first layer. When a project adds layers later, the repos that
name no layer stay where they are, and the named layers get their own directories beside
`src/`. `build` builds the unnamed layer first.

A repo is cloned at the path its key in the manifest gives, under `src/`. A key may contain
directories, so a repo can be several levels down. The tools find repos from the resolved
files, not by looking through `src/`.

The commands find the system directory by walking up from the current directory until they
find `.repos-manifest/`, so they can be run from anywhere inside it.

The system directory is not a repo. Nothing in `.repos-manifest/` is ever committed.

### config.yaml

```yaml
manifest: https://raw.githubusercontent.com/CCOMJHC/unh_marine_autonomy/jazzy/project11.manifest.yaml
local_manifest: core/src/unh_marine_autonomy/project11.manifest.yaml
role: developer
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
| `distros` | In place of `distro`, when the system directory holds more than one. See "More than one distro". |
| `fetch_from` | Optional. Another place to clone the repos from. See "Where repos are fetched from". |
| `remotes` | Optional. Extra remotes to add to every clone. See "Extra remotes". |

`role`, `groups` and `distro` are facts about the machine, which is why they are recorded
here and not in the manifest.

### More than one distro

A development machine often carries two distros of the same system at once, for example the
current release and the next one. The system directory can then have one directory per
distro, each holding its own layers and its own setup file:

```
my_system/
  .repos-manifest/
    config.yaml
    state.yaml
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
    --manifest-ref jazzy --manifest-path project11.manifest.yaml --role robot --distro jazzy
```

A URL is taken as a git repo when `--manifest-path` is given, and as the file itself
otherwise. In `config.yaml` the git form is a mapping, as in the specification:

```yaml
manifest:
  url: git@git.example.org:field/unh_marine_autonomy.git
  version: jazzy
  path: project11.manifest.yaml
```

The git form is read by making a shallow clone of the branch or tag and taking the file out
of it, with `git` as it is set up on the machine. Whatever lets a person clone that repo by hand lets the tools
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

`init` sets `local_manifest` itself when the manifest is given in the git form and that
repo is one the manifest lists: the local copy is the same file in that repo's clone.
Otherwise it is given with `--local-manifest`, or left out.

A manifest that is not in any of the system's repos needs no `local_manifest`. It stays where
it is, on a disk or at a URL.

`manifest` and `local_manifest` can be changed after `init`, by editing `config.yaml`. A
project that has no manifest yet can be set up from one written in a scratch directory. When
the manifest is later added to one of the project's repos, `local_manifest` is set to its
place in the checkout.

Only the checkout in the system directory counts as the local copy. A copy in another clone
or another branch of the same repo is not looked at.

The same rule applies to `base`. Each parent is a location of one of the three kinds, and
a relative path is taken from the manifest that names it. A local manifest that builds on a
parent next to it in the same repo reads the parent from the local disk too.

## Commands

| Command | What it does |
|---|---|
| `init` | Records the manifest, role and distro in a new system directory, then syncs. |
| `show` | Prints what a manifest comes to for a role and distro, without cloning the system's repos or writing anything. |
| `resolve` | Writes the `.repos` files for the role and distro. |
| `sync` | Resolves, then fetches and updates the repos of each layer. |
| `build` | Builds each layer in order. |
| `status` | Shows what the system directory holds against what the manifest says. |
| `freeze` | Writes a manifest with the exact commit of every repo the machine has. |
| `validate` | Checks a manifest against the specification and resolves it for every role and distro it lists, writing nothing. |

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

`show`, `resolve` and `validate` also work outside a system directory, with the manifest,
role and distro given as arguments. That is the form a CI job or another tool uses, and the
way to look at a manifest before setting anything up.

### show

A manifest can build on others, and what a machine gets depends on the role, the distro, the
extra groups and where repos are fetched from. `show` prints the result of all of that for
a person to read, before any of the system's repos is cloned:

```
$ repos-manifest show project11.manifest.yaml --role robot --with echoboat-hardware --distro jazzy

manifest  project11.manifest.yaml
base      https://github.com/example/system.git  jazzy  system.manifest.yaml
role      robot    groups on: echoboat-hardware    distro: jazzy

underlay
  geographic_info       ros2    https://github.com/ros-geographic-info/geographic_info.git
core
  unh_marine_autonomy   jazzy   https://github.com/example/unh_marine_autonomy.git
  site_config           jazzy   git@github.com:example/site_config.git    optional
platforms
  echoboat_bringup      jazzy   https://github.com/example/echoboat_bringup.git
                                from project11.manifest.yaml

left out
  vrx                   group simulation is off
  ben_bringup           group ben-hardware is off
  new_planner           not on jazzy
```

For each repo it shows the layer, the version and the URL it will be fetched from. It says
which manifest an entry came from when that is not the first in the chain, and it lists the
repos that are left out with the reason. Inside a system directory it uses what `config.yaml`
records, so it also shows the effect of `fetch_from`.

`show` does not clone the system's repos. It does read every manifest in the chain, which
for one in a git repo means fetching it, and with a `fetch_from` fallback it asks the other
place which repos exist there.

`init` prints the same thing and asks before it fetches. `--yes` skips the question, for
scripts.

### resolve

Reads the manifest and everything it builds on, applies the role, the distro and the extra
groups, and writes into `.repos-manifest/resolved/`:

- one `.repos` file per layer, with `type`, `url` and `version` for each repo (no `version`
  for a repo that names none). A named layer's file is `<layer>.repos`; the unnamed layer's
  is `_unnamed.repos`, a name no layer can have, since a name starts with a letter. A layer
  with no repos for this machine gets no file;
- `layers.txt`, the order of the layers: one name per line, `_unnamed` first when it has
  repos, only the layers that got a file;
- `optional.txt`, which repos are optional: the keys of the selected repos marked
  `optional: true`, one per line, in layer order and then in the order of the manifest. It is
  empty when there are none.

Each file starts with `#` comment lines that say which manifest, role, distro and extra groups
it came from. The manifest is named as it was given, not as a resolved path. A reader of the
two lists skips lines that start with `#`.

Outside a system directory the same files go to the directory given with `--out`:

```
repos-manifest resolve --manifest project11.manifest.yaml --role robot --distro jazzy \
    --with ben-hardware --out resolved
```

`--role` is given when the manifest has roles and `--distro` when it has distros, and not
otherwise. `--with` names an extra group and may be given more than once.

The output is replaced whole or not at all. The files are built and checked first, then written
into a new hidden directory beside the output (`.<name>.new-<pid>-<random>`), and that
directory is moved into place. An existing output directory is moved aside first and removed
after, and put back if the move fails; it is renamed to a `.new-` name before it is removed,
so that a removal cut short is never put back as the output, and a removal that fails is
reported. The new one keeps its mode. A directory is only replaced when it is empty or holds
the marker file `.repos-manifest-output` that `resolve` writes, so it cannot delete a person's
files. `--out` is found on the disk before it is checked, as the system finds it (a link
followed by `..` leads beside the link's target), and the paths `resolve` prints are the ones
it wrote. The current directory and its parents are refused, since replacing one would leave
the shell in a deleted directory. A SIGINT, SIGTERM or SIGHUP while resolving ends the run, removes the hidden
directory, says whether the output had been replaced, and then ends the process by that signal, so a shell loop over `resolve` stops on a Ctrl-C. The three are held during the two moves and delivered after them,
and an interrupt that still comes between them puts the previous output back, so the output is
the previous one or the new one, never neither. A run killed outright can leave one behind; the
next `resolve` to the same place removes the hidden directories beside it that a process that
has ended made, when they hold the marker or are empty; a run still going keeps its own, and an
output named like them is refused. A run killed between the two moves leaves no output and the
previous one aside (`.<name>.old-<pid>-<random>`, marked): the next `resolve` moves it back
into place before it does anything else.

Two runs writing to the same output at once are not supported. Each still leaves a whole
output, the one or the other, but one of them may fail with a message about the directory
that does not say another run was the cause. `resolve` takes no lock; a lock on the system
directory belongs with `init` and `sync` (issue 500).

`resolve` makes the checks of "Reading a manifest before using it" in the specification that
can be made on the text. The check on the real destination, that a link on the disk or two
names the disk treats as one cannot send a repo elsewhere, is made by `init` and `sync`, which
clone the repos there.

Beyond the specification, `resolve` refuses a distro entry that gives both a `version` and
`absent: true`, and an output directory that is a symbolic link.

### sync

1. Update the clone that `local_manifest` points into, by the same rules as any other repo
   (below).
2. Resolve.
3. For each layer in order, bring the layer's `src/` in line with its `.repos` file: clone
   the repos that are missing, and update the ones that are there.

Repos are only ever brought in line with the current manifest. On the first `sync` there is
no clone yet, and the manifest is read from the location given to `init`. A manifest on a
local disk or at a URL has no clone to update, and step 1 does nothing for it.

Step 1 follows the same rules as every other update: a clone that a person has moved to
another branch, or that has local work, is left as it is. A developer who is editing the
manifest in its checkout gets that edited manifest.

Missing repos are cloned with `vcs import`. Repos that are already there are handled one at
a time with `git`, because `vcs import` does not do what is wanted for them. Tested with
vcs2l 1.1.7: it switches a clean repo that is on another branch to the manifest's branch,
and it refuses a repo whose URL has changed.

Parents are read from where their locations say, each time. A parent at a relative path
comes from the same place as the manifest that names it; when that is the local copy, step 1
has updated it. A parent in another git repo or at a URL is fetched afresh.

Sync does not discard work, and it tells a change in the manifest from a change a person
made. It records the version and the commit it last put each repo on, in
`.repos-manifest/state.yaml`, for each distro when there is more than one. The version is
what the rules below compare against; the commit lets `status` show what has changed since
the last sync. A repo it has no
record for is recorded and followed if it is on the manifest's version, and treated as one a
person has moved if it is not.

- A repo that is still on that version, with nothing local in it, follows the manifest: it
  is updated, and moved to a new version when the manifest names one.
- A repo that a person has moved to another branch is left as it is and reported.
- A repo with uncommitted changes is left as it is and reported.
- A repo with commits that are not on `origin`, the place it was fetched from, is never
  switched to another version, so commits made on a machine are not left out of what is
  built without a person deciding. While it stays on the manifest's branch it is still
  updated: what was fetched comes first and the local commits are put back on top of it, as
  `git pull --rebase` does. If they do not go on cleanly, the repo is put back as it was and
  reported.
- A repo that is no longer in the manifest is left on disk and reported; `sync` does not
  delete it.

Arguments after `--` are passed to `vcs import`, for example `--recursive` for repos with
submodules.

An optional repo that cannot be fetched is skipped and reported. Any other repo that cannot
be fetched is an error. A skipped repo is listed every time, by `sync` and by `status`, so
that a repo missing because the network was down is not mistaken for one the machine has no
access to.

### build

For each layer in order, run `colcon build` in the layer's directory with the layers before
it sourced. `colcon` is given the paths of the repos the resolved files list for the layer
(`--base-paths`), not the whole of `src/`. A repo that is still on disk but no longer part
of the system for this machine, because a group was switched off or the manifest dropped it,
is not built. What an earlier build of it installed stays in the layer's `install/` until
that layer is built afresh, and `build` says so. Then write `setup.bash` in the system directory, or in the distro's directory
when the system directory holds more than one distro. It sources the setup file of
the last layer, in the manifest's order, that has been built, whichever layers this run
built.

The first layer is built in the environment `build` is run in. The person sets that up
first. For a ROS project that means sourcing the setup file of the ROS distro. `build` does
not do it for them.

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
as optional, or present but no longer in the manifest.

### freeze

Writes a manifest that records the exact commit of every repo the machine has, for one
distro. With more than one distro in the system directory it acts on one at a time, as
`build` does.

It is one complete manifest that builds on no other. Everything the manifest in use and its
parents say is merged in, and then:

- the `distros:` list names only this distro;
- each repo the machine has is given its commit as its `version`, and loses its `absent` key
  and its per-distro entries, so nothing overrides the commit;
- a repo that is not part of the system on this distro is left out;
- each `url` is the published one, not the place this machine fetched from.

It is a record of what a machine ran, and `init` and `sync` accept it like any manifest, so
the same state can be set up on another machine.

It is kept simple, and has limits it states in its output:

- Repos the machine does not have, because its role leaves them out or because they were
  skipped as optional, keep the versions the manifest named. A record that pins every repo
  is made on a machine that has them all. A machine set up from the record may therefore
  fetch an optional repo that the first machine skipped.
- A commit that was never pushed cannot be fetched elsewhere. `freeze` names the repos with
  uncommitted changes or unpushed commits.
- A machine set up from the record has each repo at a commit with no local branch. See
  "Work done on a field machine".

## Where repos are fetched from

A published manifest points at the released repos, for example under
`github.com/CCOMJHC`. Two kinds of machine fetch from somewhere else without the manifest
having to say so:

- A developer works in forks of some of the repos.
- A field machine has no access to the public host. It clones from a private git server and
  pushes its fixes back there.

`fetch_from` in `config.yaml` covers both. It names a place by a URL prefix. For each repo,
the tools build another URL from the prefix, the repo's name (the last part of its published
URL, without a `.git` ending) and `.git`.

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
version the manifest names, where it names one, and from the published URL otherwise.
Creating a fork changes what the next `sync` fetches. That is intended: a collaborator who
decides to work on a repo forks it, syncs, and is on their fork.

The repo is cloned with the place it came from as `origin`. When that is not the published
URL, and `fallback` is true, the published repo is added as a remote named `upstream`.

Because only the repo's name is kept, repos from different owners all land side by side at
the other place. Two repos in a manifest with the same name and different owners cannot both
be fetched this way, and `resolve` says so.

The rule applies to every repo the manifest resolves to, whichever manifest in the chain its
URL came from, to the repo that holds the manifest, and to a parent manifest that is named
as a file in a git repo. `status` shows where each repo was
fetched from.

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

- `sync` keeps local commits. On a repo that is on the manifest's branch, it fetches, and
  puts commits that have not been pushed yet back on top of what it fetched. So a machine
  with a fix it has not pushed still gets the other machines' fixes. If the two do not fit
  together cleanly, the repo is put back as it was, reported, and left for a person.
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
repo of the system, with a `simulation` and a `ui` group, one hardware group per platform,
and a private repo marked optional.

### A development machine

```
repos-manifest init https://github.com/example/system.git --manifest-ref rolling \
    --manifest-path system.manifest.yaml --role developer --distro jazzy --distro rolling \
    --fetch-from https://github.com/developer/ --fetch-fallback \
    --remote field=git@git.example.org:field/
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

```
repos-manifest init https://github.com/example/system.git --manifest-ref jazzy \
    --manifest-path system.manifest.yaml --role robot --with echoboat-hardware \
    --distro jazzy --fetch-from git@git.example.org:field/
```

The manifest is named by its published location. Because `--fetch-from` is given with no
fallback, the manifest's repo is read from the private server like every other repo.
Besides the manifest's location, `config.yaml` holds:

```yaml
role: robot
groups: [echoboat-hardware]
distro: jazzy
fetch_from:
  prefix: git@git.example.org:field/
  fallback: false
```

The robot role leaves `simulation` and `ui` off. A layer that holds only such repos is empty
and is not built. The one hardware group brings in the drivers for this platform and no other.
Every repo, and the manifest itself, comes from the private server. Fixes made on the machine
are committed on the manifest's branches and pushed to the server, and `sync` keeps them.

Without roles, groups and `fetch_from`, this machine needs its own copy of the manifest:
the same repos at the same versions with every URL rewritten and half the entries deleted,
kept in step with the published one by hand.

### A collaborator with their own robot

The collaborator writes a manifest in their own repo:

```yaml
base:
  url: https://github.com/example/system.git
  version: jazzy
  path: system.manifest.yaml
layers: [my_robot]
groups: [my-robot-hardware]
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

- `vcs`, from vcs2l, to clone repos.
- `colcon`, to build a layer.
- `git`, to update repos that are already cloned, to read their state, to check whether a
  repo exists at another place and to add remotes.
- Python with PyYAML.

The tools call `vcs` and `colcon` as commands. They do not import them as libraries.

Not every command needs all of these:

| Command | Needs |
|---|---|
| `show`, `resolve`, `validate` | Python with PyYAML; `git` when a manifest is read from a git repo, or when `fetch_from` has a fallback |
| `init`, `sync`, `status`, `freeze` | `vcs` and `git` as well |
| `build` | `colcon` as well |

`colcon` is the one build tool `build` supports. It was chosen because it builds a directory
of packages in dependency order, handles plain CMake and Python packages as well as ROS
ones, and writes setup files that chain one workspace onto another, which is what makes
layers work. Supporting other build tools is not planned.

Nothing else depends on `colcon`. A project that builds another way uses the format,
`resolve`, `sync` and `status`, and builds the layers itself in the order `resolve` gives.

A manifest's `base` is resolved by the resolver. `vcs` does not know the key.

## Not covered

- Package dependencies and system packages. For ROS projects `rosdep` covers these, run by
  the person or the script that sets up the machine.
- Running a distro the host OS does not support, in a container or otherwise. `distro` is
  recorded, and the commands assume the environment they run in can build it.
- Leaving out some packages of a repo. Groups and roles select whole repos. A person can
  pass `colcon` its own options for skipping packages through `build`.
- Content that is not in a git repo, such as models or data downloaded at build time.

## What is built

`resolve` and `validate` read the format in the specification for a manifest that stands on
its own, given as a path on the local disk. `resolve` writes the files described under
"resolve" into `--out`. `validate` checks the file and resolves it for every role and distro it
lists, and writes nothing. `--role` or `--distro` limits the check to that role or distro, and
`--with` switches on extra groups in each one. `base` is not read yet: a manifest with `base` is
refused.

A manifest without a top-level `repositories:` key, or a file that does not read as YAML,
still goes to a prototype that reads an earlier shape of the format, where repos are nested
under their layer and the version key is `ref`. A caller that needs `repos/<layer>.repos`,
`layers.txt` and `optional_layers.txt` uses that reader, with `--layout manifest-dir`. The
prototype also has three things this design drops: a `packages:` section with package
dependencies, roles defined by starting packages, and a cache of fetched parent manifests that
is kept between runs.

Two things in the prototype differ from this design in smaller ways. It marks whole layers
as optional, where the design marks repos. And when it fetches a parent manifest from a git
repo it never lets git or ssh ask for a password, where the design lets them ask at a
terminal.

`show`, `init`, `sync`, `build`, `status`, `freeze`, the system directory, fetching from
another place and extra remotes are not built.

## Open questions

- What `sync` does when a repo that is already cloned is given a different layer. Its
  directory has to move. `sync` could move it, or say what to move.
- With `fallback: true`, how often to ask whether a repo exists at the other place. Asking
  for every repo on every sync costs a network call per repo.
- With more than one distro, whether a distro needs its own settings, such as a different
  `manifest` URL for its first sync or a different role.
- Whether `build` should stop at the first layer that fails or carry on with layers that do
  not depend on it. The manifest does not say which layers depend on which, only their
  order, so stopping is the safe rule.
