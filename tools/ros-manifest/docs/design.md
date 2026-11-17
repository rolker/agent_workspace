# Design

Status: draft. This is the design we are working towards. What exists today is listed under
"What is built" at the end. The prototype's command is still called `ros-manifest`, the
tool's earlier name.

The format of a manifest is in [spec.md](spec.md). This document is about the tools.

## The parts

- The specification of the manifest format.
- A resolver: given a manifest, a role and a distro, it works out which repos a machine gets,
  at which version, in which layer. It reads and writes files and fetches manifests. It does
  not clone repos or build anything.
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
role: developer
distro: jazzy
prefer_owner: rolker
```

| Key | Meaning |
|---|---|
| `manifest` | Where the manifest is: a path or a URL. |
| `local_manifest` | Optional. A path inside the system directory that is used instead, once that file exists. |
| `role` | The role of this machine, if the manifest has roles. |
| `distro` | The ROS distro of this system, if the manifest has distros. |
| `prefer_owner` | Optional. See "Preferred owner". |

`role` and `distro` are facts about the machine, which is why they are recorded here and not
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
repos-manifest init <manifest> --role robot --distro jazzy
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

## Preferred owner

A published manifest points at the released repos, for example under
`github.com/CCOMJHC`. A developer usually works in forks of some of them. Setting
`prefer_owner` to the developer's account means: for each repo, use my fork if I have one,
and the published repo otherwise.

For each repo, `resolve` builds the fork's URL by replacing the owner in the published URL
and keeping the repo's name. It uses the fork if both are true:

- the fork exists and can be read;
- the fork has the version the manifest names.

Otherwise it uses the published URL. When a fork is used, the published repo is added to the
clone as a remote named `upstream`.

Creating a fork changes what the next `sync` fetches. That is intended: a collaborator who
decides to work on a repo forks it, syncs, and is on their fork. `status` shows which repos
come from a fork.

The setting applies to the repo that holds the manifest like any other repo.

A machine that should run exactly what is published leaves `prefer_owner` unset.

A repo entry that a developer's own manifest points somewhere with `extends` is used as
written. The preferred owner only applies to URLs that come from the manifest unchanged.

## What the tools rely on

- `vcs`, from vcs2l, to fetch and update repos and to record exact commits.
- `colcon`, to build a layer.
- `git`, to check whether a fork exists.
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

`init`, `sync`, `build`, `status`, the system directory and the preferred owner are not
built.

## Open questions

- How a URL names a manifest in a private repo. A plain https URL does not carry ssh
  credentials. One answer is a form that names a git repo, a version and a path in it.
- How `sync` updates a repo that is already cloned without touching local work, using `vcs`.
  `vcs import` and `vcs pull` each do part of it, and what they do to a repo with local
  changes needs testing.
- How often to ask whether a fork exists. Asking for every repo on every sync costs a
  network call per repo.
- Whether `build` should stop at the first layer that fails or carry on with layers that do
  not depend on it. The manifest does not say which layers depend on which, only their
  order, so stopping is the safe rule.
