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
| `manifest` | Where the manifest is: a path or a URL. |
| `local_manifest` | Optional. A path inside the system directory that is used instead, once that file exists. |
| `role` | The role of this machine, if the manifest has roles. |
| `groups` | Optional. Extra groups to switch on, on top of the role. |
| `distro` | The ROS distro of this system, if the manifest has distros. |
| `fetch_from` | Optional. Another place to clone the repos from. See "Where repos are fetched from". |
| `remotes` | Optional. Extra remotes to add to every clone. See "Extra remotes". |

`role`, `groups` and `distro` are facts about the machine, which is why they are recorded here and not
in the manifest.

## Where the manifest comes from

A manifest is a file, so `manifest` points at a file: on a local disk or at a URL.

Often the manifest lives in one of the repos it lists. Before the first sync that repo is not
on the machine, so the manifest is read from its URL. After the first sync there is a copy in
the system directory, and `local_manifest` says where. From then on the local copy is the one
that counts: a developer can edit it, try it, and send the change through the repo's normal
review.

A manifest that is not in any of the system's repos needs no `local_manifest`. It stays where
it is, on a disk or at a URL.

Only the checkout in the system directory counts as the local copy. A copy in another clone
or another branch of the same repo is not looked at.

The same rule applies to `extends`. Each parent is a path or a URL, and a relative path is
taken from the manifest that names it. A local manifest that extends a parent next to it in
the same repo reads the parent from the local disk too.

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
be fetched is an error.

### build

For each layer in order, run `colcon build` in the layer's directory with the layers before
it sourced. Then write `setup.bash` in the system directory, which sources the last layer
that was built.

`build` with layer names builds only those layers. Arguments after `--` are passed to
`colcon`.

A layer that has no repos on this machine, because all of them were left out by the role or
skipped as optional, is skipped.

### status

Shows the manifest in use, the role and the distro, and for each repo whether it matches the
manifest: on the expected version, on a different one, with local changes, missing, or
present but no longer in the manifest. It also says whether each layer has been built since
its repos last changed.

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
version the manifest names, and from the published URL otherwise. Creating a fork changes
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
- Keeping more than one distro in one system directory. A machine with two distros has two
  system directories.

## What is built

A prototype has `resolve` and `validate` for an earlier shape of the format, where repos are
nested under their layer and the version key is `ref`. It also has three things this design
drops: a `packages:` section with package dependencies, roles defined by starting packages,
and a cache of fetched parent manifests that is kept between runs.

`init`, `sync`, `build`, `status`, the system directory, fetching from another place and
extra remotes are not built.

## Open questions

- How a URL names a manifest in a private repo. A field machine reads its manifest from the
  private server, so this is needed. A plain https URL does not carry ssh credentials. One
  answer is a form that names a git repo, a version and a path in it.
- How `sync` updates a repo that is already cloned without touching local work, using `vcs`.
  `vcs import` and `vcs pull` each do part of it, and what they do to a repo with local
  changes needs testing.
- With `fallback: true`, how often to ask whether a repo exists at the other place. Asking
  for every repo on every sync costs a network call per repo.
- Whether `build` should stop at the first layer that fails or carry on with layers that do
  not depend on it. The manifest does not say which layers depend on which, only their
  order, so stopping is the safe rule.
