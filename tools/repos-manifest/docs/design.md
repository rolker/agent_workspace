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
    built-<distro>.yaml  the layers build built for the distro, and each one's chain
    build-<distro>.lock  held by a build or a sync of the distro while it runs
  underlay/
    src/             the repos of the layer
    build/ install/ log/
  core/
    src/
    ...
  setup.bash         sources the last layer of the built run
```

This is the layout of a flat system, the default. A system set up with a directory per
distro puts each distro's layers and setup file in a directory of its own; see "More than one
distro".

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
layout: flat
distros:
  jazzy: {}
fetch_from:
  prefix: https://github.com/rolker/
  fallback: true
remotes:
  field: git@git.example.org:field/
```

| Key | Meaning |
|---|---|
| `manifest` | Where the manifest is, for every distro. A distro with its own `manifest_version` reads it at that version. A relative path is taken from the system directory. See "Where the manifest comes from". Not read in this part: the git form, a URL, and a distro's own `manifest_version`. |
| `local_manifest` | Optional. A path that is used instead, once that file exists: inside the system directory, or inside each distro's directory when there is one per distro, the same path in each. Not read in this part. |
| `role` | The role of this machine, if the manifest has roles. |
| `groups` | Optional. Extra groups to switch on, on top of the role. |
| `layout` | `flat`, or `distro-dirs` for a directory per distro: the system directory's layout, unrelated to `resolve --layout`. Chosen at `init` and not changed afterwards. See "More than one distro". |
| `distros` | The distros of this system, each with its settings. The same shape for one distro or several. Absent when the manifest has no distros. See "More than one distro". Not read in this part: a distro's settings; each distro's entry is empty. |
| `fetch_from` | Optional. Another place to clone the repos from. See "Where repos are fetched from". Not read in this part. |
| `remotes` | Optional. Extra remotes to add to every clone. See "Extra remotes". Not read in this part. |

`role`, `groups`, `layout` and `distros` are facts about the machine, which is why they are
recorded here and not in the manifest.

### More than one distro

A distro is a build environment the system is built in, apart from the others, such as a ROS
distribution or an operating system release (see "Distros" in the specification). A
development machine often carries two distros of the same system at once, for example the
current release and the next one.

The layout is chosen at `init` and cannot be changed afterwards. By default a system is flat:
it holds one distro, or none when the manifest has no `distros:`, laid out as in the first
diagram. A flat system cannot gain a second distro in place, because the first distro's
directories would have to move; several distros need a new directory set up with
`init --distro-dirs` and a fresh clone of the repos.

With `init --distro-dirs` each distro has a directory of its own from the first distro on,
holding that distro's layers, or an ordinary colcon workspace when the manifest has no
layers, and its own `setup.bash`. A distro is added later with `add-distro`, and nothing of
the distros already there is moved. The cost is one more level of directories, so a person
who may want a second distro later sets up with `--distro-dirs` from the start. A manifest
with no `distros:` always gives a flat system.

The smallest system is one repo on one distro with no layers and no roles, set up flat. The
tools do little more here than `vcs` and `colcon`. The two trees below are abridged and show
only what the layout changes:

```
my_system/
  .repos-manifest/
    config.yaml        manifest: ./system.manifest.yaml, layout: flat, distros: {jazzy: {}}
    state.yaml
    resolved/
      _unnamed.repos
  src/
    my_repo/
  build/  install/  log/
  setup.bash
```

The same system set up with `--distro-dirs`, after `repos-manifest add-distro rolling`.
`rolling/` and `resolved/rolling/` are new; nothing of `jazzy/` or `resolved/jazzy/` is
touched:

```
my_system/
  .repos-manifest/
    config.yaml        layout: distro-dirs, distros: {jazzy: {}, rolling: {}}
    state.yaml
    resolved/
      jazzy/
        _unnamed.repos
      rolling/
        _unnamed.repos
  jazzy/
    src/
      my_repo/
    build/  install/  log/
    setup.bash
  rolling/
    src/  build/  install/  log/  setup.bash
```

`distros` in `config.yaml` maps each distro's name to its settings, with the same shape for
one distro or several, so adding a distro adds an entry and changes nothing else. A flat
system has one entry, and the key is absent when the manifest has no distros. The only setting an entry may carry is `manifest_version`, the
branch or tag that distro reads the manifest at, in place of the one `manifest` gives; it is
what `add-distro --manifest-ref` records. A system on a manifest kept on a branch per distro
looks like this; with one manifest for all, `rolling` is `{}` too:

```yaml
manifest:
  url: git@git.example.org:team/system.git
  version: jazzy
  path: system.manifest.yaml
local_manifest: core/src/system/system.manifest.yaml
role: developer
layout: distro-dirs
distros:
  jazzy: {}
  rolling:
    manifest_version: rolling
```

Everything else in `config.yaml` applies to every distro. `local_manifest` is then a path
inside each distro's directory, the same path in each; the copies there may differ, as the
copies on a project's distro branches may. Each distro is built in its own environment, which
the person sets up before building, for example by sourcing that distro's setup file, so one
shell can build only one of them.

#### Setting up with init

`init` sets up the current directory. Without `--distro-dirs` it takes one `--distro`, or
none when the manifest has no `distros:`; with it, one or more. It refuses as listed under
"Refusals", before anything is created. Before anything is created it also resolves every
distro and builds the text of each distro's resolved files, so a manifest that does not resolve,
or whose resolved files cannot be written out (their head comment would hold a control or
invisible character), is an error with nothing created.

`init` makes `.repos-manifest/` with its `config.yaml` in one step, written aside and moved
into place, so the folder and its record appear together. The aside is a directory
`.repos-manifest-tmp-<pid>-<random>` in the directory being set up. A later `init` removes such
a directory, not a link, whose process has ended when it is empty or holds only `config.yaml`;
any other entry of that name, a link among them, it leaves and names in a warning, which for
a directory whose process is still running says so (another `init` may be setting up there). Before that step nothing of the system exists, and `init` can be
run again. If the first sync after it fails or is interrupted, `sync` finishes it. Every
command finds `.repos-manifest/` by walking up from the current directory, and one without a
readable `config.yaml` is an error that names the file. `init` gives that error too, not the
refusal for a system that is set up, and its next step is to repair the file, or, to set up
again, to move the system directory aside and run `init` in an empty directory. A `config.yaml` without exactly the shape this version writes
(`manifest` as a path, `layout`, and `role`, `groups` and `distros` when set, each of its type,
with an empty entry for each distro) is the same error, naming the key and what is wrong; any
other key is named with the words that this version does not read it.

`init` writes a `setup.bash` that says nothing is built yet and fails when sourced, and `sync`
writes it for a distro whose `setup.bash` is missing; `build` replaces it (see "build"). It is created in one step only where no file is, so one made meanwhile is left
as it is, and one that cannot be written whole is removed, never left empty or partial. One
that cannot be created is reported for that distro, with its path and the
reason, after that distro's report; the other distros go on, and the exit status is 1.
Something at its place that is not a file or a link to one, such as a directory or a dangling
link, is left as it is and named in a warning after that distro's report; the exit status is
not changed by it.

Before its question, `init` prints what `show` prints (see "show"): the `manifest`, `base`
and `role` lines once, then for each distro, in the order given, a `distro` line (none when
the manifest has no `distros:`), its layers with their repos and the repos left out, and a
`will create` list of each layer's `src/` directory. A `Layout:` line comes last. It asks
before it goes on, which `--yes` skips; when its input is not a terminal it refuses without
`--yes`. For a flat system with a distro
the `Layout:` line is this one, which `--yes` does not skip:

```
Layout: one directory for the system, with no directory per distro. A distro cannot be added to this system later. To be able to add one, set up with --distro-dirs.
```

#### Adding a distro

```
repos-manifest add-distro <name> [--manifest-ref <ref>] [--yes] [-- <vcs import arguments>]
```

`add-distro` adds a distro to a system set up with `--distro-dirs`. It reads the new distro's
manifest, prints what `show` prints for it and asks before it goes on, which `--yes` skips.
It then adds the distro's entry to `distros`, with `manifest_version` when `--manifest-ref`
was given, and syncs that distro only; a sync that fails part way is finished with `sync`.
The role, the groups, `fetch_from`, `remotes` and `local_manifest` are shared by every distro
and changed by editing `config.yaml`. `add-distro` replaces `config.yaml` whole, written aside and moved into
place, as `init` writes it.

A system on a manifest kept on a branch per distro is set up and grown like this, which gives
the `config.yaml` example above:

```
repos-manifest init git@git.example.org:team/system.git --manifest-ref jazzy \
    --manifest-path system.manifest.yaml --role developer --distro jazzy --distro-dirs
repos-manifest add-distro rolling --manifest-ref rolling
```

#### Refusals

A refusal changes nothing. Each command checks the conditions below in the order listed and
gives the first that applies, with its next step. The checks that need no fetch come first.

Two kinds of row are not built in this part, and no command makes their check: the `init`
row for `--manifest-ref` or `--manifest-path`, which `init` does not take yet, and every
`add-distro` row, since `add-distro` is not built. Every other row is built.

| Command | Condition | Next step the message gives |
|---|---|---|
| `init` | A system is set up in this directory or one above it. | `sync`, or `add-distro <name>` for a system set up with `--distro-dirs`. |
| `init` | More than one `--distro` without `--distro-dirs`. | Add `--distro-dirs`. |
| `init` | Two `--distro` that differ only in case, with `--distro-dirs`, since a distro's name is a directory name. | Name one of them. |
| `init` | `--manifest-ref` or `--manifest-path` is given and the manifest is not given in the git form: a local path, or a URL with `--manifest-ref` and no `--manifest-path`. | Give the manifest in the git form, or leave the option out. |
| `init` | `--distro-dirs` with a manifest that has no `distros:`. | Set up without `--distro-dirs` and without `--distro`. |
| `init` | No `--distro`, with a manifest that has `distros:`. | Name one with `--distro`. |
| `init` | A `--distro` without `--distro-dirs`, with a manifest that has no `distros:`. | Set up without `--distro`. |
| `init` | A `--distro` the manifest's `distros:` does not list, without `--distro-dirs`, which is the resolver's error (see "Distros" in the specification). | Name a distro it lists; or, when the manifest is given in the git form, give with `--manifest-ref` a version of it that lists the distro; or, when it is not, add the distro to its `distros:`. |
| `init` | A `--distro` the manifest's `distros:` does not list, with `--distro-dirs`. | Name distros it lists; or set up with the ones it lists and add each other one afterwards: with `add-distro <name> --manifest-ref <ref>` when `manifest` is given in the git form, or, when it is not, by adding the distro to its `distros:` and then `add-distro <name>`. |
| `init` | A directory or file it would create already exists, checked after the manifest is read. | Move it out of the way, or set up in another directory. |
| `init`, `sync` | No `vcs` or no `git` on `PATH`, `vcs --version` fails, or `git rev-parse --local-env-vars` fails. | Install, repair or reinstall vcs2l or vcstool, or git. |
| `init` | Its input is not a terminal and `--yes` is not given. | Give `--yes`. |
| `add-distro` | `<name>` is not a name by the rule for names in "Reading a manifest before using it" in the specification, or differs only in case from a recorded distro, since a distro's name is a directory name. | Use another name. |
| `add-distro` | The system is flat. | Set up a new directory with `init --distro-dirs`. |
| `add-distro` | The distro is already recorded. | `sync --distro <name>`. |
| `add-distro` | `<name>/` exists in the system directory. | Move it out of the way. |
| `add-distro` | `--manifest-ref` is given and `manifest` is not given in the git form. | Leave `--manifest-ref` out. |
| `add-distro` | The manifest read has no `distros:`. | None: there is no distro to add. |
| `add-distro` | The manifest read has `distros:` and does not list the distro. | When `manifest` is given in the git form, `--manifest-ref` for a version that lists it; when it is not, add the distro to its `distros:`. |

A next step that names a command or option that is not built yet, `add-distro` or
`--manifest-ref`, is left out of the message until it is built.

#### Where the resolved files and state go

In a flat system the resolved files are in `.repos-manifest/resolved/`. With a directory per
distro, each distro's are in `.repos-manifest/resolved/<distro>/`.

The version and commit `sync` last put each repo on are kept in `.repos-manifest/state.yaml`,
for each distro. What the design needs of it is that writing one distro's state leaves every
other distro's as it was. Its shape:

```yaml
format: 1
distros:
  rolling:              # _unnamed when the manifest has no distros
    repos:
      project11/core:   # the repo's key in the manifest
        layer: core     # _unnamed for the unnamed layer
        version: rolling  # the manifest's version; null when it names none
        commit: 3f2a9c...
        url: https://github.com/CCOMJHC/project11.git  # the manifest's url, when recorded
        moving: {from: 3f2a9c..., to: 81bd04...}  # only while sync moves the repo
```

It is made at the first clone and written whole, by one rename, after each repo is cloned,
followed or moved, and when the url of a repo left as it is is recorded. A write that fails ends
the run with a message that the clone is in place, or that the repo may have been changed, and
is not recorded, naming the file and the reason. `url` and `moving` are optional: a record
without `url` (one written before urls were recorded) reads as no url recorded. One without
exactly this shape (`format: 1`, each repo with `layer`, `version` and `commit`, optionally
`url` and `moving` with `from` and `to`, and no other key) is an error that names it and says
what is wrong. A `sync` holds the distro's lock (the one `build` holds, see "build") while it
writes the distro's resolved files and updates and records its repos, so two runs on the same
distro do not meet; two runs on different distros can still each lose the other's update to
`state.yaml`.

#### Which distro a command uses

A flat system has one distro, or none, and every command uses it.

In a system with a directory per distro, a command uses the distro named with `--distro`,
which wins over the current directory. When none is named, it uses the distro whose directory
the current directory is inside; anywhere else in the system directory counts as the top:

| Command | At the top of a system with a directory per distro |
|---|---|
| `sync`, `status` | Every distro, in the order of `distros`. `--distro`, given once or more, names some of them. |
| `show`, `resolve`, `build`, `freeze` | The system's only distro, when it has one. With several, an error that lists them. |
| `validate` | Every distro the system records, in the order of `distros`; it writes nothing, so checking them all does no harm. `--distro` names one. |
| `add-distro` | The distro named as its argument. |

A `--distro` that the system does not record is an error for every command, a flat system
included. Outside a system directory, `show`, `resolve` and `validate` take the distro as an
argument.

#### Which manifest a distro reads

Every time a distro reads its manifest, it reads the first of these that exists:

1. its local copy: the file at `local_manifest` inside that distro's directory (the system
   directory when it is flat);
2. the location in `manifest`, at the distro's own `manifest_version` when its entry has one.

The local copy is in the clone of the manifest's repo that the distro syncs, at the version
the manifest gives that repo on that distro. So where the manifest gives its own repo a
branch per distro, each distro reads the copy on its own branch from its second sync on.

A distro can have its own version of the manifest and nothing else of its own: a distro whose
manifest is at another URL or path is not supported. A manifest that is not given in the git
form has no version, and every distro reads the same file until its local copy exists.

`build` reads no manifest; it uses the distro's resolved files. `init` reads the location on
its command line, and `add-distro` the location in `manifest` at `--manifest-ref` when it is
given, since a new distro has no local copy yet.

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
the system directory, or in each distro's directory when there is one per distro, and
`local_manifest` says where. From then on the local copy is the one
that counts: a developer can edit it, try it, and send the change through the repo's normal
review.

`init` sets `local_manifest` itself when the manifest is given in the git form and that
repo is one the manifest lists: the local copy is the same file in that repo's clone.
Otherwise it is given with `--local-manifest`, or left out.

`init` takes the manifest's repo as listed when the manifest has a repo whose `url` names the
same repo once the scheme, any `user@`, a trailing `.git` and a trailing `/` are set aside,
and in the scp form `host:path`, such as `git@host:team/system.git`, the `:` is read as `/`.
A distro on which that repo is absent has no local copy, and reads the recorded location.

A manifest that is not in any of the system's repos needs no `local_manifest`. It stays where
it is, on a disk or at a URL.

`manifest` and `local_manifest` can be changed after `init`, by editing `config.yaml`. A
project that has no manifest yet can be set up from one written in a scratch directory. When
the manifest is later added to one of the project's repos, `local_manifest` is set to its
place in the checkout. A change to `manifest` reaches every distro, except that a distro with
its own `manifest_version` keeps reading that version.

Only the checkout in the system directory counts as the local copy, and with a directory per
distro only the checkout in that distro's own directory. A distro never reads another
distro's copy. A copy in another clone or another branch of the same repo is not looked at.

The same rule applies to `base`. Each parent is a location of one of the three kinds, and
a relative path is taken from the manifest that names it. A local manifest that builds on a
parent next to it in the same repo reads the parent from the local disk too.

## Commands

| Command | What it does |
|---|---|
| `init` | Records the manifest, role and distros in a new system directory, then syncs. With `--distro-dirs` each distro gets a directory of its own, and distros can be added later. Without it the system holds one distro, or none, and cannot gain another. Refuses a directory that is already set up, or one inside a system. |
| `add-distro` | Adds a distro to a system set up with `--distro-dirs`, then syncs it. |
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

A person who may want a second distro later sets up with a directory per distro, and adds
the distro when it is wanted:

```
repos-manifest init <manifest> --role robot --distro jazzy --distro-dirs
repos-manifest build
source jazzy/setup.bash
```

and later, in a new shell with the other distro's environment:

```
repos-manifest add-distro rolling
cd rolling
repos-manifest build
source setup.bash
```

`show`, `resolve` and `validate` also work outside a system directory, with the manifest,
role and distro given as arguments. That is the form a CI job or another tool uses, and the
way to look at a manifest before setting anything up. Inside a system directory the distro is
chosen as under "Which distro a command uses": `validate` at the top checks every distro the
system records, or the one `--distro` names.

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

For each repo it shows the layer, the version and the URL it will be fetched from, the URL's
user name and password masked as "sync" describes. A repo with no version shows
`(its default branch)`. It says which manifest an entry came from when that is not the first
in the chain, the manifest the chain's reading starts from. The manifest an entry came from is
the one that gave the URL printed: the one where its key first appears, or the last manifest in
the order of reading that changed its `url`, as one that points a repo at a fork does. A later
manifest that changes the entry's other keys, its `version` or its `type`, or that repeats its
`url` unchanged, does not change that, so the version printed may come from a later manifest
than the one named.

Each manifest is printed by its path, the same way on every line that names it, so that it
opens from the directory `show` is run in. A manifest given on the command line is printed as
it was given. Every other one is printed as an absolute path with links followed: the
manifests it builds on, and, with no manifest given, the one `config.yaml` records, whose
recorded path is taken from the system directory and not from the current one. That recorded
path is opened as `sync` opens it, so the two read the same manifest or refuse the same path.
Until the manifest has been read and resolved, `show` names it as `sync` does, by the path as
recorded: every refusal and warning about it does, whether the path is missing, is a
directory, cannot be read or does not parse. A path is
printed on one line: a control or invisible character in it (a newline, a tab, a
bidirectional override) is written as an escape, `\xXX` below 0x80, `\uXXXX` up to U+FFFF
and `\UXXXXXXXX` above, so that the escape's end is never in doubt. A byte that is not UTF-8 is
written `\xXX`; it is always 0x80 or above, so it never prints as a character of the same value
does: byte 0x85 is `\x85`, the character U+0085 `\u0085`. A backslash is doubled. `init` prints the system directory in
its question the same way.

It lists the repos that are left out with the reason, in the manifest's order: "group X is
off" for a repo in one group that is off, "none of its groups (X, Y) is on" for a repo in
several, "not on D" for a repo that distro D's
entry or the repo's own `absent: true` leaves out, and "absent, and no distro adds it" for a
repo with `absent: true` in a manifest with no `distros:`. A repo that a group and a distro
would both leave out is listed with the group. A manifest with no roles prints `(none)` as
the role, and the unnamed first layer prints as `(unnamed layer)`.

With no manifest given, `show` must be run inside a system directory: it uses what
`config.yaml` records and that distro's manifest. Showing the effect of `fetch_from` there is
planned, not built: today it prints the manifest's own URLs.
`--role` and `--with` are refused there, since the system records them; giving the manifest
tries another role. Outside a system directory, a manifest is given; without one, `show`
refuses and names the current directory, printed on one line as a path is above.

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
it came from. The manifest is named as it was given, not as a resolved path. After it comes
one `# base:` line for each manifest it builds on, in the order they were read, each named by
its path after links are followed. A reader of the two lists skips lines that start with `#`.

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
reported. The new output keeps the mode of the one it replaces. A directory is only replaced when it is empty or holds
the marker file `.repos-manifest-output` that `resolve` writes, so it cannot delete a person's
files. `--out` is made absolute, and the directory it is in is passed through Python's
`os.path.realpath`, which resolves the links that exist and folds `..` parts; that directory is then made as
`mkdir -p` would, and the paths `resolve` prints are the ones it wrote. The current directory and its parents are refused, since replacing one would leave
the shell in a deleted directory. A SIGINT, SIGTERM or SIGHUP while resolving ends the run, removes the hidden
directory, says whether the output had been replaced, and then ends the process by that signal, so a shell loop over `resolve` stops on a Ctrl-C. The three are held during the two moves and delivered after them,
and an interrupt that still comes between them puts the previous output back, so the output is
the previous one or the new one, never neither. The one exception is a failure to move the
previous output back: the run then says that the output is missing, names the hidden directory
the previous one is kept in, and the next `resolve` to the same place moves it back if the
output is still missing. A run killed outright can leave one behind; the
next `resolve` to the same place removes the hidden directories beside it that a process that
has ended made, when they hold the marker or are empty, and warns about one it cannot remove; a
run still going keeps its own, and an output named like them is refused. Every directory in a
copy being removed is made writable first, so a read-only one inside it does not stop the
removal. A run killed between the two moves leaves no output and the
previous one aside (`.<name>.old-<pid>-<random>`, marked): the next `resolve` moves it back
into place before it does anything else.

Two runs writing to the same output at once are not supported. Each still leaves a whole
output, the one or the other, but one of them may fail with a message about the directory
that does not say another run was the cause. `resolve` takes no lock; a lock on the system
directory belongs with `init` and `sync`, and is not built yet.

`resolve` makes the checks of "Reading a manifest before using it" in the specification that
can be made on the text. The check on the real destination, that a link on the disk or two
names the disk treats as one cannot send a repo elsewhere, is made by `init` and `sync`, which
clone the repos there.

Beyond the specification, `resolve` refuses a distro entry that gives both a `version` and
`absent: true`, and an output directory that is a symbolic link. It reads at most 64
manifests for one run, the one it was given included, and refuses a manifest of a chain that
is in the prototype's earlier shape (one with `repos:`, `extends:`, `optional_layers:` or
`packages:` and no `repositories:`), before any check on its keys.

In a system with a directory per distro, a distro's files go in
`.repos-manifest/resolved/<distro>/`, and resolving one distro never touches another's; see
"Where the resolved files and state go".

### sync

For each distro it acts on:

1. Update the clone that the distro's `local_manifest` points into, by the same rules as any
   other repo (below).
2. Resolve.
3. For each layer in order, bring the layer's `src/` in line with its `.repos` file: clone
   the repos that are missing, and update the ones that are there.

Repos are only ever brought in line with the current manifest. On the first `sync` there is
no clone yet, and the manifest is read from the location recorded for that distro (see
"Which manifest a distro reads"). A manifest on a local disk or at a URL has no clone to
update, and step 1 does nothing for it.

Step 1 follows the same rules as every other update: a clone that a person has moved to
another branch, or that has local work, is left as it is. A developer who is editing the
manifest in its checkout gets that edited manifest.

After step 1, the manifest read for a distro is checked against what `config.yaml` records.
Where they disagree, `sync` reports it for that distro and goes on with the other distros. By
then step 1 has updated the manifest's own clone; nothing else of that distro is changed: it
is not resolved, and none of its repos is touched.

- The manifest this distro reads no longer lists it, or lists no distros at all. The
  message names the distro and says that nothing has been moved or removed. Nothing is
  deleted, and the distro stays recorded until the manifest lists it again or a person edits
  `config.yaml`.
- A flat system records no distro, because its manifest had none, and the manifest now has
  `distros:`. Resolving for no distro is then an error, since a distro is given where the
  manifest has them (see "What resolving produces" in the specification).
  The message says that the manifest now has distros, that this system directory was set up
  without one and nothing in it has been moved or changed, and that a system with distros is
  set up in a new directory with `init`, with `--distro-dirs` to hold more than one distro.
- The manifest lists a distro the system does not record. Nothing happens: a distro is added
  only with `add-distro`.
- The manifest this distro reads lacks the system's role or one of its groups. At `init`,
  where every distro reads the one location given, that is the resolver's error and nothing
  is created.

A distro whose manifest does not resolve is reported in the same way, and so is one whose
resolved files cannot be put on the disk (an error writing them, or something that is not
the tool's in their place), whose repos are then not touched; a repo that cannot be fetched is
reported for that repo; the other distros go on. `sync` exits with 1 when a distro
was reported or a repo was an error (below), and with 0 otherwise; a repo that is there and
left as it is does not change it. A stop signal at any point of `init` or `sync` ends it with
that signal and one line, which says when nothing was changed yet.

Before a missing repo is cloned, the check on the real destination is made: the directory
that will hold it is, with every link resolved, where its path says, and no file is where one
of the directories on its path belongs. Each missing repo is cloned by a `vcs import` of its
own, given that one repo, into a
temporary directory `.repos-manifest-tmp-<pid>-<random>` in `.repos-manifest/`. Only when
`vcs` exits with 0, and the check on the real destination still holds, is the clone renamed
into its place. The stop signals are held over that rename and the writing of the repo's
record in `state.yaml`. So a path under a layer's `src/` is a whole clone or something a person
put there; a repo whose clone failed leaves nothing there. A place that is there is not
written into, and one that is there and is not a directory stops that repo. The
temporaries make a limit: a system directory is on one filesystem. Where a distro or layer
directory is a separate mount, the rename fails, and the message says so and names both
places. Each run first removes the temporaries in `.repos-manifest/` whose process has ended.

`vcs` runs in the tool's own process group, so a Ctrl-C at a terminal reaches `git` and a
password prompt works. A stop signal removes the clone in progress, and the run says to run
`sync` to finish. A temporary that cannot be removed then, because a clone is still writing
into it, is a warning, and a second stop signal during that cleanup cuts it short; the next
run's sweep removes what is left. A run killed outright loses at most the repo in progress.
After failures, the run says to run `sync` again only when a repo could not be fetched or
its clone's `HEAD` cannot be read, as for a remote with no commits yet; for a repo in the way
it says that another sync will not change that.

Missing repos are cloned with `vcs import`. Repos that are already there are handled one at
a time with `git`, because `vcs import` does not do what is wanted for them. Tested with
vcs2l 1.1.7 and vcstool 0.3.0: it switches a clean repo that is on another branch to the
manifest's branch, and it refuses a repo whose URL has changed.

Parents are read from where their locations say, each time. A parent at a relative path
comes from the same place as the manifest that names it; when that is the local copy, step 1
has updated it. A parent in another git repo or at a URL is fetched afresh.

Sync does not discard work, and it tells a change in the manifest from a change a person
made. It records the version and the commit it last put each repo on, in
`.repos-manifest/state.yaml`, for each distro. The version is
what the rules below compare against; the commit tells `sync`, and `status`, whether a repo
detached at a tag or a commit is where `sync` last put it. A repo it has no
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
  reported. This rule is not built yet: until it is, such a repo is left as it is, and
  the report gives the next step: when `origin`'s branch has commits the clone lacks, the
  `git pull --rebase` command for a person to run; when it has none, a line saying the
  commits are only here, with the `git push` command that publishes them (`sync` itself
  never pushes).
- A repo that is no longer in the manifest is left on disk and reported; `sync` does not
  delete it.

The rules for a repo that is there are checked in this order, and the first that applies ends
the repo's turn. Before a fast-forward or a switch, the only changes in the repo are what the
fetch brings, and, under the url rule, `origin`'s url (its probe refs are removed again). The
fetch brings `origin`'s
remote-tracking refs for its branches, objects, the local tags that `origin` has and the clone
lacks (`--tags`; a local tag is never replaced or removed), and `FETCH_HEAD`. It removes no
ref: `sync` prunes nothing, so a remote-tracking ref a person fetched with a refspec of their
own (pull request heads) stays, and so does one left from a branch `origin` has deleted. No
local branch, `HEAD`, index or work-tree file changes before then.

1. The manifest gives the repo another layer than its record, and the old place is there:
   it is not moved, and nothing is cloned at the new place. The repo is reported with the
   commands that move it (`mkdir -p <new parent> && mv <old> <new>`), and, since it is not in
   its place and `build` refuses that layer, that is an error (exit status 1) for a repo that
   is not optional. Once the old place is gone, the repo is cloned at the new one, or, moved
   there by hand, it is handled there and its record names the new layer.
2. The check on the real destination fails, or the place is not a directory: an error, as for
   a missing repo. A place that is a link to a directory is left as it is: `sync` does not
   update a repo through a link.
3. A repo that is not a git repo of its own (its top level is not the place itself, or there
   is none), or whose type is not `git`, is left as it is.
4. A rebase, merge, cherry-pick, revert or bisect in progress, or an `index.lock` in the git
   directory, leaves the repo as it is. So does a sparse checkout (`core.sparseCheckout`): the
   report says it is one and that `sync` does not update one, rather than counting its
   skip-worktree files as changes.
5. A repo without exactly one `origin` url is left as it is.
6. The url rule (below), then the tracked changes: a file changed, staged or removed, a file
   flagged assume-unchanged or skip-worktree, or a submodule with changes to its own tracked
   files, leave the repo as it is. Untracked and ignored files are not local work and do not
   stop an update. A submodule whose checked-out commit differs from the one recorded, which
   is what a fast-forward that moves its pointer leaves, is not counted.
7. `git fetch --tags --no-prune --no-prune-tags --no-recurse-submodules --refmap= origin
   +refs/heads/*:refs/remotes/origin/*`: the refspec is `sync`'s own, and `--refmap=` keeps
   git from applying the person's `remote.origin.fetch` too, so a refspec there that writes
   into `refs/heads/` never moves a local branch; `--no-prune` and `--no-prune-tags` win over
   `fetch.prune`, `remote.origin.prune` and `fetch.pruneTags`; a submodule is never fetched
   into, whatever `fetch.recurseSubmodules` says. The fetch is given the distro's lock, as a
   call that changes the tree is, so a `sync` killed while git writes refs does not free the
   lock before git ends; its stop signals are not held, so a Ctrl-C still stops a fetch that
   hangs or asks for a password. A fetch that fails skips an optional repo and is an error
   for any other. A remote-tracking ref left from a branch `origin` no longer has that is in
   the way of a branch `origin` has now (`origin/release` here against `origin`'s
   `release/next`) makes git refuse the fetch without naming either: the error names both,
   says another sync will not change it, and gives the `git update-ref -d` command that
   removes the old ref by hand; before it, it says that ref may be the only one here to
   commits `origin` has since deleted, and gives the `git branch <a new name> <ref>` command
   that keeps them on a local branch. A tag here and `origin`'s tag of the same name that name other objects make
   git refuse that tag and exit 1, though it fetches the branches; `sync` then fetches the
   branches again without tags and goes on when that exits 0. A clash on a tag the manifest
   does not name is a note. For the manifest's own tag it is an error (rule 8) that gives both
   commits: when the record shows `sync` followed that tag at the commit it holds here, the
   message says `origin` moved it and that `git tag -d` and another sync take `origin`'s, and
   the next `sync` then follows it when the repo is still detached at the recorded commit (rule
   11); otherwise the tag is taken for a person's, and which to keep is left to a person, with
   no advice to delete it. `sync` never replaces a tag.
8. The manifest's version is looked up on `origin` itself (`git ls-remote origin` for the
   branch and the tag of that name, since a remote-tracking ref may be left from a branch
   `origin` deleted): a branch (`origin/<version>`, which must be at the commit `origin` lists), a tag that
   `origin` has (a local tag of the same name that `origin` lacks does not count, and nor does
   a local branch, whatever the version), or a commit
   named by 7 to 40 hex digits that is there; with no version, `origin`'s default branch. A
   version written `heads/<name>` is the branch `<name>` only, and `tags/<name>` the tag
   `<name>` only, as vcstool reads them (`version_ref` in `manifest.py`, which the reader's
   check uses too), everywhere in these rules: the lookup, "on the manifest's version", the
   move, and the comparison with the record. The record keeps the version as written, so
   what a version written without a prefix named when it was recorded is read from where
   the repo is: on the branch of that name, the branch; detached at the recorded commit, the
   tag when the tag of that name here is at that commit and the local branch is not, the
   branch when it is the other way round, and a commit for hex digits that commit starts
   with. A recorded branch `release` and a pin `tags/release` are then two versions, and a
   clean repo on the branch is moved to the tag (the report says "moved from branch release
   to tag release"); so is the other way round. When both the branch and the tag of that
   name are at the recorded commit (or, on the branch, the tag is), which one `sync` followed
   cannot be told: the repo is left as it is and the report says so. When neither is (a tag
   `origin` moved since), the record is read as the manifest's version when the names are
   the same, as before. A plain name that is both a branch and a tag on `origin` stays the
   error below; `heads/<name>` and `tags/<name>` are never refused for it. A tag that
   names a tree or a blob, not a commit, is an error. A
   commit counts only when it is reachable, in the history the clone has, from a branch of
   `origin` or from a tag `origin` has, as `origin` lists them now (a remote-tracking ref left
   from a deleted branch does not count); one that is in the clone and nowhere on `origin` (a
   person's own commit) is not followed, and the repo is left as it is and reported. In a
   shallow clone a commit beyond the shallow history is not there: the error says so and that
   `sync` never deepens a clone. A branch `origin` has deleted is an error that says so and
   names the remote-tracking ref left here. A version that is none of these, or both a branch and a tag on `origin`, is an error
   that another sync will not change; when `origin` was set by hand the message says so and gives the command
   that sets it to the manifest's url.
9. On a branch with commits not on `origin`: left as it is (above). The count is of the commits
   reachable from `HEAD` and from no remote-tracking ref of `origin`. After an upstream
   force-push the old upstream commits count, so such a repo is left as it is too. A
   remote-tracking ref left from a branch `origin` deleted, or one a person fetched with a
   refspec of their own, still counts as `origin`'s here: a commit only it holds reads as on
   `origin`. That is safe: it can only let a repo be moved, and a move never loses a commit (a
   fast-forward keeps them all, and a switch leaves the branch it leaves as it was). On the
   manifest's branch, the report gives the next step: when `origin`'s branch has commits the
   clone lacks, the `git pull --rebase` command for a person to run; when it has none, a line
   saying the commits are only here, with the `git push` command that publishes them (`sync`
   itself never pushes).
10. On the manifest's version (`HEAD` on the branch of that name; for a tag or a commit,
    detached at its commit): followed. A branch whose `HEAD` is behind `origin/<version>` is
    fast-forwarded (`git merge --ff-only`), whatever the branch's own upstream is; one that
    `origin/<version>` no longer contains, because the branch was rewritten upstream, is left as
    it is. A branch another work tree of the repo holds is not fast-forwarded: the repo is
    left as it is and the report names that work tree and why (below, "held"), since a
    fast-forward would move the branch under that work tree's files, and git would show the
    new commits there as staged changes, or under a rebase that sets the branch when it
    ends. A tag or a commit has
    nothing to follow: `sync` leaves it where it is. When the repo is already there and only
    its record is behind (the manifest changed to the version a person had already put it on,
    or a person fast-forwarded it), the record is brought up to date and one line names the
    repo and says so (`core/src/a: already on rolling; record updated (was jazzy)`); a record
    that gains only the manifest's url says nothing.
11. On the recorded version, which the manifest has changed (on the recorded branch, or
    detached at the recorded commit): moved to the new version. A branch not yet local is
    made with `git switch -c <version> --no-track <origin's commit>`, which does all of it or
    nothing, and its upstream (`origin/<version>`) is set after the switch, as a step of its
    own: when git refuses it, as it does in a `--single-branch` or `--depth` clone whose fetch
    settings do not cover that branch, the move stands and the report says the branch has no
    upstream, why, and the two `git config` commands that set one. A tag or a commit is checked
    out detached. A local branch of that name is used when `origin/<version>` contains it: it
    is switched to and then fast-forwarded. If another work tree holds that branch, or it has
    commits not on `origin`, the repo is left as it is. The branch left behind
    keeps every commit it had. A repo pinned to a tag the manifest still names, detached at the
    commit recorded for it, is moved the same way when origin's tag now names another commit.
12. Anything else (another branch, a detached `HEAD` elsewhere, or no record and not on the
    version) is a repo a person has moved: left as it is and reported.

A repo left as it is does not change the exit status, apart from the layer rule above; its
record is unchanged, except that the manifest's url is recorded when it is not yet, and a repo
moved by hand to the layer the manifest now gives it has that layer recorded, by whichever rule
its turn ends, and a `moving` line that no longer describes it is removed (below). `status`
is the check a script reads.

Before every fast-forward or switch, `sync` lists the paths the move adds and looks at each in
the work tree. Git refuses to overwrite an untracked file, but overwrites an ignored one
without a word (git 2.53.0), so `sync` makes the check itself: a path that is there and is not
tracked in `HEAD`, a directory on the way to it that is there and is not a directory (a link is
never taken for one), or a directory the move replaces with a file that holds anything not
tracked in `HEAD`, leaves the repo as it is, and the report names up to ten of the paths and
says which are ignored. Git's own refusal stays behind that check: every `git merge` and
`git switch` of `sync`, the undo included, is given `--no-overwrite-ignore` (both commands
accept it in git 2.53.0), so an ignored file written where an incoming file goes between the
check and the call (a build writing a log) makes git refuse, and the repo is left as it was.
Right before the first call, `HEAD`, its branch and the tracked files are read again: a
person who committed, switched branches or edited a tracked file while the checks ran keeps
that, and the repo is left as it is and reported.

Every `git` that changes a repo's tree is one call (a switch, or a fast-forward) that does
all of what it is for or nothing, except the switch to a local branch followed by its
fast-forward, whose first step is undone (a switch back) if the second does not get there and
the tree is clean, so a tracked change git or a hook made is never carried back onto the
branch the repo was on. An untracked or ignored file a hook wrote on the way stays in the work
tree, as git leaves such a file on a switch, and is not reported: the comparison that finds
the repo "left as it was" covers `HEAD`, the branch, the configuration, the index and the
tracked status, not untracked files. After each call,
whatever its exit status, `sync` reads the repo's state: success is `HEAD` where that call was
to put it (for the switch of a two-step move, the local branch) with no tracked changes (a
`post-checkout` hook that fails makes `git switch` exit non-zero after it has switched; that
is reported, and the step counts, so a two-step move goes on to its fast-forward; a hook that
exits 0 but changes tracked files stops the move there). A call that did not get there and
left the repo as it was (`HEAD`, the branch, the configuration, the index and the tracked
status compared) is reported and the repo left. One that left it otherwise is an error that
says what ran, in order (each call with its exit status and where it took `HEAD`, a
fast-forward naming the branch and both commits, and the switch back when it ran), where
`HEAD` is now, and the files that now differ from it, staged or not, which were made after the
check just before the first call found none, by git, a hook it ran, or a person (when there are
none, it says so instead);
`sync` does not put them back, and nothing after those calls runs in that repo. What git
printed follows on lines of its own; when it printed nothing, the line ends there. A branch such a move made is left without an upstream,
and the same report says so, with the two `git config` commands that set one. Its record loses
the `moving` line, so the next `sync` reports the uncommitted changes and does not take them
for a run that was stopped. The record keeps the version it had: if such a move left the repo
on the new branch and the manifest is then changed back, the next `sync` reports the repo as
moved by a person, since the record cannot tell sync's own unfinished move from a person's. `sync` never runs `reset`, `checkout -f`,
`clean`, `stash`, `rebase`, `pull`, `push`, `gc` or `prune`, never deletes a branch or a tag (the
one ref it deletes is its own probe refs, below, with `update-ref --no-deref -d`, which removes a
symbolic ref there and never what it points to), and passes
no `--force`, `--no-verify`, `--prune`, `-p`, `-P`, `--prune-tags` or `--discard-changes`, no
`switch -f` or `branch -f`, and no bundled short flag holding `p`, `P` or `f` (a test reads
`update.py` for each of these, in every git call and every list of arguments; the test also
holds the code to spreading only argument lists it reads). Each `git` runs with automatic `gc` and `maintenance` off and
with `submodule.recurse` off. A `git` whose output `sync` reads runs with `LC_ALL=C`, so git's
words are the ones the code looks for; a call whose output is only shown (a switch, a
fast-forward, setting an upstream or a url) keeps the person's language. `sync` and `init` read
`git --version` once per run and stop, with nothing changed, when it names a git older than
2.23, the release that brought `git switch`; the other commands and options they use are
older (a fetch that does not replace a tag without `--force` came in 2.20). Every command a
report or a refusal of `sync` prints, the lock refusals' `fuser -v` included, quotes paths,
branch names and refs for the shell (`shlex.quote`); the commands `build` prints name only
layers, whose names hold letters, digits, `_` and `-`, and process numbers.

A clone with submodules is followed like any other, and its submodules are not updated: the
report gives the `git submodule update` command. Before every fast-forward or switch, `sync`
compares each submodule of `HEAD` with the same path in the target, and leaves the repo as it
is, naming the submodule and saying it has to be dealt with by hand, when the move removes a
submodule whose directory holds anything (a `.git`, a file or a directory), or puts something
else in its place (a file, a link, a directory of the superproject's); and when the move
changes the commit a submodule points to while the submodule's own `HEAD` is not the commit
`HEAD` records, or its directory holds files and is not a repository of its own. `sync` never
judges whether a submodule's content could be lost. A submodule that is not checked out (an
empty directory) is no obstacle, and nor are untracked files in a submodule whose pointer a move
changes, since with `submodule.recurse` off git does not touch its work tree; a path the move
turns from a file or directory into a submodule goes through the paths check above. A
submodule left on its old commit by an earlier `sync` stops the next move of its pointer until
a person updates it. A shallow clone is followed on the history it
has and is never deepened or made whole; the fetch brings the history of every tag, so a
shallow clone of a repo with tags grows at its first `sync`. A linked work tree of a clone (the
workspace this tool is used from makes them, on feature branches) on another branch is
unaffected: `sync` moves only the branch of the clone's own work tree, and never touches
another work tree's files. A branch is held by another work tree when that work tree has it
checked out (`git worktree add -f` allows that), or is in the middle of an operation that
names it, as git itself counts it (`git branch -f` refuses such a branch): a rebase whose
`rebase-merge/head-name` or `rebase-apply/head-name` is that branch, which it sets when it
ends (git lists that work tree as detached meanwhile); a rebase with `--update-refs` whose
`update-refs` list names it; a bisect whose `BISECT_START` names it, where `bisect reset`
returns. When an operation is there and what it returns to cannot be read (a rebase with no
`head-name`, a file that cannot be read), every branch is held. A rebase of a detached `HEAD`
(`head-name` is `detached HEAD`), a bisect started detached (`BISECT_START` holds a commit),
and a `git am`, merge, cherry-pick or revert, which work on `HEAD` as it is, hold no branch
beyond the one checked out there. When another work tree holds the clone's branch, or the
branch a move would switch to (before the switch, so also before the fast-forward of an
existing local branch), the repo is left as it is and reported, naming that work tree and why.
When that work tree's directory no longer exists, the line says so and gives `git worktree
prune`, to run when the directory is gone for good (not on a drive that is not mounted). When
the work trees cannot be listed or their git directories read, the repo is left as it is too.
The url rule counts the `HEAD` of every work tree, a detached one included; one on a branch
with no commit yet (`git worktree add --orphan`) has none to count.

For a manifest that names no version, the branch followed is `origin`'s default branch as the
clone records it (`refs/remotes/origin/HEAD`, set when it was cloned); `sync`'s fetch does not
change that record. When `origin`'s default branch changes, the clone stays on the old branch
and is followed on it while `origin` still has it. Once a person runs `git remote set-head
origin --auto`, the clone, still on the old branch, is a repo a person has moved: left as it
is and reported, never switched. When `origin` deletes the old branch, the record names a
branch that is gone, and the repo is an error whose message gives that `set-head` command.

The url rule. `W` is the clone's `origin` url as written in its configuration (before any
`insteadOf` rewrite), `U` the manifest's url, and `R` the one recorded; urls are compared after
one trailing `/` and one trailing `.git` are taken off, as git hosting reads `x` and `x.git` as
one repository; so local paths `/srv/robot` and `/srv/robot.git` are read as one too.

- `W` is `U`: nothing to do.
- `W` is `R` and the manifest now names another `U`: the manifest moved the repo. `sync` fetches
  `U`, with `--no-tags --no-prune --no-recurse-submodules`, into refs of its own
  (`refs/remotes/repos-manifest-probe/`, removed afterwards, and at
  every later check if a run was killed) and repoints `origin` to `U` only when every local
  branch and the `HEAD` of every work tree of the repo, detached ones included, are on it.
  Otherwise `origin` stays, and the repo is left as it is with the number of commits and the
  branches and detached work trees that hold them. When the clone has a remote named
  `repos-manifest-probe`, the name `sync` keeps for this check, there is no check: `origin`
  stays, the repo is left as it is and reported with the command that renames that remote,
  and that remote's refs are never removed. The old url is not kept as another
  remote; the report prints it.
- Anything else, `R` missing included, is an `origin` a person set (ssh for pushing, a fork):
  it is left as set, the repo is updated from it, `U` is recorded, and a line on every run says
  so, with the command that sets the manifest's url. An `origin` a person set is never
  repointed. A record with no url yet (a system made before the record held urls) is given the
  manifest's url at the next sync when `W` is `U`; a later change of the url in the manifest
  then repoints a clone whose `origin` still has the url recorded.

In the first and last case `U` is recorded when the repo's record is next written, which, for
a repo that is recorded, is in the same run unless the fetch or the version lookup fails. After
a repoint `U` is recorded at once, before the fetch, so a fetch or a lookup that fails next does
not leave the new url read as one a person set.

The tool masks a url's user name and password in what it prints. This is a guard against
accidents, not a guarantee: a user name and password belong in a credential helper or an ssh
key, not in a manifest url, and the specification does not look for one there ("a credential
in a `url` is not looked for: the manifest is as trusted as the code it names",
[spec.md](spec.md#reading-a-manifest-before-using-it)).

The user information of a `scheme://user:password@host` url is shown as `***` (an ssh url's
user name alone is kept; any other user name is masked, since an https one is often a token).
Each url the tool reads (the manifest's, the clone's `origin`, the recorded one) is parsed
whole: its user information (a `file://` url's aside, below) is everything between `://` and
the last `@` in it, whatever
characters it holds (quotes, spaces, `@`, `:`, `/`, `%` escapes, any letter); an https url
whose path holds an `@` has more masked, never less. In a `file://` url, user information is
only in the authority, the text between `file://` and the first `/` after it: it is the text
before the last `@` there, when that text holds a `:` (`file://user:password@host/srv/w@x` is
shown as `file://***@host/srv/w@x`). A `file://` url's path is never masked
(`file:///srv/w@x/...` and `file://localhost/srv/a:b/w@x` are printed as they are). Nothing
that does not follow `://` is masked: a local path holding `@`, `git@github.com:...` and `origin/main@{upstream}` are printed as they are, so a password that
is a common word (`git`, `main`, `a`) cannot change a printed command.

It is masked at two places:
- Where a url is put into a message. A message that formats a value named as a url (the
  scan below holds the source to it), and every message of the manifest reader
  (`manifest.py`) that quotes a value from a manifest (a `base:` path, a version, a name, a
  repo key, an unknown key), does it through `mask_url` or `quoted_url`, which masks a url and
  then quotes it as `repr` would, so no quoting or escaping (a quote or a backslash) can hide
  the user information. A value of the wrong type (a list or a mapping given as a `url`, a
  `base`, a version or a name) is described by its kind (`must be a string, got a list`),
  never shown. The earlier format's reader (`schema.py`) refuses a url with a password without
  printing it, and shows a name that fails its rule, two names that differ only in case and
  an unknown top-level key the same way; its other messages that print a value from a
  manifest ([prototype.md](prototype.md) lists them) are masked only as they are printed.
- As some lines are printed. These lines pass through a filter: each line `sync` prints for a
  repo's outcome (what it says and what git says, `ERROR:`, `skipped`, `left alone` and the
  updated line, and a repo's notes), `sync`'s `ERROR:` line for a distro whose plan or run
  failed, and the `ERROR:` line any command ends with when it stops on the tool's own kind of
  error (a manifest that cannot be read or is refused, a system or a record in the wrong state;
  the handler in `cli.py`). The filter masks each url the tool read where it follows `://`, its
  `%`-decoded form too, and a url it did not read itself (git's message after an `insteadOf`
  rewrite, a value typed on the command line) by its shape, up to the first `@` that a host
  follows within one run of characters that are not white space. Two other lines `sync` prints
  for a repo are not filtered, `cloning <path>` and "<path>: holds the manifest, …": they show
  only the repo's path in the system directory, which is the distro's and the layer's
  directories where the system has them, then `src`, then the repo's key. That path cannot hold
  a `scheme://` url: a distro or layer name has only letters, digits, `_` and `-`, and a repo
  key has no `//`.
  Other lines are printed as given, among them: the "unknown role" error of `resolve` and
  `validate` on an earlier-format manifest, which echoes the role typed on the command line, the
  `ERROR:` line of a run stopped by a signal, `sync`'s line for a setup file it could not write,
  and every `WARNING:` line.

What is not masked, so a user name and password in a url can be printed:
- A `file://` url whose password holds a `/`: the password reaches past the authority and
  cannot be told from a path. git's file transport ignores user information.
- The scp-like form `user:password@host:path`, which does not follow `://`.
- A value the earlier format's reader (`schema.py`) prints from a manifest other than those
  named above (a layer name in `optional_layers` or `repos`, a list of layers or of unknown
  keys); [prototype.md](prototype.md) lists them. Such a line is masked only if the filter
  above covers it.
- A warning (`WARNING:`), including a manifest's warnings: the filter does not cover them,
  though `manifest.py` quotes the key in them through `quoted_url`.
- A message outside the manifest readers that echoes a value typed on the command line (a
  role or a distro) or read from the tool's own record files (`state.yaml`, the built file),
  unless it is one of the lines the filter covers.
- A url that reaches a message by a way the source scan below cannot see, on a line the filter
  does not cover, or with white space in its user information when the tool did not read it.

Tests check it. One walks the tool's source for values formatted into text whose names say
they are urls (holding "url", or `origin`) and fails on one that does not go through the
masking functions; another holds `manifest.py` and `schema.py` to quote no value with `!r` or
`repr`. The walk cannot see a url held under another name, passed to a helper, joined, or
formatted inside a list or a mapping, nor keyword arguments, `+=`, logging, or an exception
formatted whole; `tests/test_url_messages.py` lists what it misses. A message reached that way
is masked only on the lines the filter above covers. End to end, `resolve`, `validate`, `init` and `sync` are run over repo urls whose passwords hold
quotes, a backslash, a space, `%` escapes and letters beyond ASCII, in every url form the
tests name (a list and a mapping among them); `resolve`, `validate` and `init` over a `base:`
url, mapping and list; and `validate` over keys, names and values that hold a url. Their
output is searched for the user name and the password.

A `set-url` command whose url is masked says so, and that the url to give it is the repo's url
as the manifest gives it. The urls are written in full where they are kept: the resolved
files, `state.yaml` and the clone's configuration.

A person who fetches over https and pushes over ssh sets `remote.origin.pushurl`, or
`url.<base>.pushInsteadOf`, and keeps `origin`'s url the manifest's.

A distro's lock: `sync`, and `init` for its first sync, hold the distro's lock (the file `build`
holds, "build") from before the distro's resolved files are written to the end of its repos;
until a lock for every command is designed, this is that lock reused. A distro whose lock a
`build` or another `sync` holds is reported and the others go on. Every `git` that changes a
repo, its fetches included, is given the lock, so a `sync` killed while one runs does not
release it early. A fetch goes on after the `sync` that started it is killed, and holds the
lock until it ends: one waiting at a password prompt holds it until it is killed. A `sync` or
`build` refused meanwhile says that the `sync` has ended and that a git it started, such as a
fetch, may still hold the lock, gives the `fuser -v` command that names it, and says that it
ends on its own or, at a prompt, when it is killed. When the process the lock file names runs
but its open files cannot be read (no `/proc`, or a process of another user), the refusal
says it cannot tell whether that is the sync, names the process and the `ps` and `fuser`
commands that show what it is, and advises no kill; the lock
file names only the `sync`. A `sync` writes no build record; after a distro's repos, for each
layer `build` has built and some of whose repos this run cloned or moved, it says that the
layer is behind and that `build` brings it up to date. When the manifest's own file is in a
repo this run moved, the run has already read it; the report says the next sync reads its new
text.

A stop signal is held while a `git` that changes a repo runs (and `git` inherits it held), so
the call ends whole, and the run then ends. Before such a call `sync` records a `moving` line
in the repo's record and removes it with the record that follows; a run killed outright may
leave it. While `HEAD` is the line's `from` or `to` commit, the line is added to the reason a
repo is left as it is (uncommitted changes, an operation in progress, an `index.lock`), never
put in its place; a later `sync` that finds `HEAD` elsewhere removes the line, whatever then
happens to the repo. It only changes wording: no rule reads it to decide what to do.

| Where a run ends | What it leaves | The next `sync` |
|---|---|---|
| A stop signal or a kill during a fetch | At most remote-tracking refs, and a lock file git did not remove; the distro's lock stays held until the fetch ends | Fetches again; a lock file git left is named in git's message, and `sync` never removes one |
| A stop signal while a fast-forward or a switch runs | The call ends whole first | Records it |
| A kill during a fast-forward or a switch | Possibly a half-changed tree, an `index.lock`, and the `moving` line | A changed tree or an `index.lock` leaves the repo as it is, the report saying a sync was stopped while moving it and that `git status` shows what it left; a repo git had not changed yet is moved again |
| A kill after the call, before the record | The repo on the new version, the `moving` line | Records it |
| A kill during the url check | The probe refs | Removes them |

Arguments after `--` are passed to `vcs import`, for example `--recursive` for repos with
submodules. `init` and `add-distro` pass theirs to the `vcs import` of their first sync.

Whatever stops a repo from being put in place (it cannot be fetched, the clone's `HEAD` cannot be read, a link is on the way,
a file is where a directory on its path belongs,
its place is taken by something that is not a directory or is filled meanwhile, a directory
cannot be made, the rename fails) skips an optional repo, which is listed with the reason and
never makes the exit status non-zero; for any other repo it is an error, and the exit status
is 1. A skipped repo is listed every time, by `sync` and by `status`, so
that a repo missing because the network was down is not mistaken for one the machine has no
access to.

### build

```
repos-manifest build [--distro <name>] [--keep-going] [<layer> ...] [-- <colcon arguments>]
```

`build` acts on one distro, chosen as under "Which distro a command uses"; `--distro` is given at
most once, and an empty name (`--distro=`) is refused. It reads the layer order and each layer's
repos from the resolved files `sync` wrote, not from the manifest, so it needs no network; without
them it says to run `sync`.

For each layer in order, it runs `colcon build` in the layer's directory: the distro's
directory for the unnamed first layer, so that its `build/`, `install/` and `log/` sit beside
the named layers' directories, and `<layer>/` for a named one. `colcon` is given the paths of
the repos the resolved files list for the layer and that are on disk (`--base-paths`), not
the whole of `src/`, so the unnamed layer's colcon never sees the named layers' repos. The
resolved files list only the repos the role and groups keep for this machine, and name the
optional ones (`optional.txt`). Only an optional repo may be absent from disk: a layer left
with none of its repos on disk, all of them optional, is skipped as having no repos on this
machine. Any other repo the resolved files list for a layer this run would build that is not
on disk is an error before anything is built or any record touched: `build` refuses, names
each missing repo with its layer, and says to run `sync`. A repo that is still on
disk but no longer part of the system for this machine, because a group was switched off or
the manifest dropped it, is not built. What an earlier build of it installed stays in the
layer's `install/` until that layer is built afresh; before it builds a layer whose
`install/` is there, `build` names each repo the layer's last build had that the layer no
longer has, and each repo that is new since.

`colcon` writes `install/setup.bash` after a failed, a partial and
even an empty build, and exits non-zero when any package fails, `--continue-on-error`
included (checked with colcon-core 0.21.3). So whether a layer is built is kept in a record of
its own, one file per distro, `.repos-manifest/built-<distro>.yaml` (`built-_unnamed.yaml`
when the manifest has no distros), and the record is the only thing `build` trusts:

```yaml
format: 1
layers:
  core:
    time: '2026-11-19T14:40:00-05:00'
    repos: [project11/core, marine_msgs]   # the repos it was built from
    below: [_unnamed, underlay]   # the built run below it when it was built; [] when none
    without:                      # only when skip or ignore options were given
      --packages-skip: [core_demos, core_docs]
```

`below` is the chain the layer was built on: the layers of the built run below it at the time,
from the bottom up, the last of them the one that was sourced. A record in the form of an
unreleased draft, with only the layer that was sourced (`base`), is read as not built.

`without` holds the skip and ignore options given after `--` to the layer's `colcon` when it
was last built (`--packages-skip`, `--packages-ignore` and their `-regex` forms, see "Packages
left out" below), each named in full with its values as `colcon` read them, whether or not the
layer has packages they name: a run gives the same options to the `colcon` of every layer it
builds, and `build` does not ask which packages a layer has. It is written only when such an
option was given, so a record written before the field existed reads as before, with none. A
version of the tool from before the field refuses a record that has it, as it refuses any
key it does not read ("repair or remove it"); `format` stays 1, since this version reads every
record the earlier one wrote. A skip set in a file of `colcon` defaults or a mixin is not seen
by `build` and is not in `without`, so the list may be shorter than what `colcon` was given.

Before `colcon` starts on a layer, the layer's record is removed and the file written, and
`setup.bash` is brought into line with it, so it no longer sources that layer or one built on
it. Then the layer's `install/setup.bash` is removed, so that one there when `colcon` has
ended was written by that `colcon`: no file time is relied on, which a filesystem that keeps
times to the second would not move for a rewrite in the same second. A shell that sources that
file directly finds none until `colcon` writes it again; when `colcon` ends without writing it
(a failure before it, an argument `colcon` rejects, a stop signal), the failed line, the not
built line or the stop line says the earlier one was removed. When it cannot be removed (a
read-only `install/`, say), `colcon` is not started on the layer: the layer gets its record
back, untouched, `setup.bash` is brought into line with it, the later layers are not tried,
the report says why, and the exit status is 1. The record is written
again with the layer's record only when `colcon` exits with 0 and has written the layer's
`install/setup.bash` in this run; a `colcon` that exits with 0 and writes no
`install/setup.bash`, as with `-- --help`, leaves the layer not built, says so, and the exit
status is 1. A run with package selection writes back the record the layer had, unchanged, its
`without` included (see "Package selection" below). So a `colcon` or a `build` killed outright
leaves that layer not built, never a "built" over a half-written `install/`, and a `setup.bash`
that `build` may replace never sources a layer while its `colcon` runs. Other layers' records
are not touched by a build of one layer; records of layers the resolved files no longer list
are dropped at the next write. The file is written whole by one rename, and one without
exactly this shape, or with a control character (a newline, say) in any of its names or values,
is an error that names it. A system built by other means, such as another tool or by hand, has
no record, and a plain `build` builds it from the bottom.

A `build` holds a lock on `.repos-manifest/build-<distro>.lock` (`flock`) from before it reads
the record to its end. Each `colcon` it starts inherits the lock, so the lock is held while
`colcon` runs even when the tool itself is killed outright (a SIGKILL, or a CI job's whole
process group killed), and it is gone once the tool and its `colcon` have both ended, however
they end. `colcon` starts its own jobs with the lock closed (checked with colcon-core 0.21.3),
so a job, or a process a job leaves running on purpose, does not hold it. A second `build` of the
same distro meanwhile is refused before it reads the record or writes anything. The lock file
holds the numbers of the tool's process and of its `colcon`, but a number alone is not trusted,
since a process that ended may have had its number given to another one: the message names
the tool's process when that process has the lock file open (seen in `/proc/<pid>/fd`); when
the tool has ended and its `colcon`, which has it open, runs on, it names that `colcon`;
otherwise it says `fuser -v` on the lock file names what holds it, adding, where the open
files of a process the lock file names cannot be read, that the file names it and the tool
cannot check it. Builds of two distros at once take two locks and read and write two records, so
neither touches the other's. A `sync` of the distro takes the same lock (see "sync"), and the
lock file then names it: a build refused by a running `sync` says so, and a `sync` refused by a
running build is reported for that distro.

A layer counts as built when its record is there, its `install/setup.bash` is there (a person
may have deleted `install/`), and the chain it was built on, which its record holds, is the
built run below it as things stand now. The built run is the distro's layers from the bottom
up to the first layer with repos that is not built; layers with no repos are passed over. The
whole chain matters, not only the layer just below, because the setup file `colcon` writes for
a layer brings in only what was sourced when it was built: a layer built while a layer
anywhere below it was empty or not built stays blind to that layer, even after it is filled
or built, so it is not built until it is built again. So filling a layer that was empty, at
any depth, takes every layer above it out of the run until each is built again, while
rebuilding a layer in place, on the same chain, keeps the layers above it. A layer below
that leaves the manifest or has no repos now shortens the chain of every layer above it, which
are then built again on the shorter one; what that layer installed may still be in its
`install/`, and the report names it, as for `--keep-going` below. The record does not say that
a layer is up to date with `sync`.

Three things read the one built run, so they agree:

- A layer is built with the built run below it sourced: `bash` sources the run's last layer's
  `install/setup.bash`, which brings in the layers under it, and then runs `colcon`, the arguments
  passed as arguments, never put into the script's text. The setup file is sourced with no
  arguments; the command waits meanwhile in variables named `_repos_manifest_build_setup` and
  `_repos_manifest_build_command`, which no setup file or package hook sets. A layer with nothing
  built below it, normally the first, runs `colcon` directly, so the environment `build` is run in
  reaches it unchanged.
- `build` with layer names builds only those layers, in the manifest's order whatever the
  order they are named in. A name the distro does not have is an error that lists its
  layers. When a layer with repos below a named layer that has repos is outside the built
  run and not named too, `build` refuses before anything runs, names that layer, and says
  that a plain `repos-manifest build` fixes it. A named layer with no repos on this machine
  is skipped, not refused. Without names every layer is built.
- `setup.bash`, in the system directory or the distro's directory, sources the run's last
  layer's `install/setup.bash` by the real path of the layer's directory, every link on the
  way resolved, the system directory's and the layer directory's alike. That is how `colcon`
  names the layer itself: it takes the install prefix it gives each package from the
  directory it runs in, with links resolved (checked with colcon-core 0.21.3: a layer
  directory that is a link gets `CMAKE_INSTALL_PREFIX` under its target). The closing report
  names a layer's setup file the same way. When nothing is built it is the text `init`
  writes, which fails when sourced.

`build` stops at the first layer that fails; later layers are not tried, and the exit status
is 1. Records of layers above the failed one are kept, but they are outside the built run, so
`setup.bash` sources the layer below the failed one. Once the failed layer is built again
with `build <layer>`, the run reaches the layers above it again, and `setup.bash` sources the
last of them with no rebuild of theirs. A rebuild of a lower layer on its own chain keeps
the layers above it built in the same way, also when it was rebuilt with other skip or ignore
options than before (see "Packages left out" below); a layer whose chain no longer matches, such as
one anywhere above a layer that was empty and now has repos, is not built and is built again
by the next plain `build`.

`build --keep-going` tries the later layers after a failed one instead of stopping. Each is
built on the built run below it, so the failed layer is not sourced; a layer whose own
`colcon` then fails is a failed layer too. Not sourced is not the same as absent: what an
earlier build of the failed layer installed is still in its `install/`, and a package whose
build directory kept from an earlier build the path where it found a package of the failed
layer finds it there again (seen with colcon-core 0.21.3 and CMake, whose cache keeps a
package's `<name>_DIR`; a fresh build of the same package fails to find it). When its
`colcon` exits with 0, its record is written with that chain, but it is outside the built
run, since the failed layer below it is not built, so it is not used: `setup.bash` sources
the layer below the first failed one, as without the option, and the report says of such a
layer that it was built without sourcing the failed layer and is not used, adding, when the
failed layer's `install/` is there, that it may have used what is left there. When the failed
layer is fixed and built, such a layer's chain no longer matches and it is built again by
the next plain `build`; that is the check of the chain at work, not a rule of its own. The
exit status is 1 whenever a layer failed.

`setup.bash` is rewritten from the record, in one step, before and after each layer's `colcon`
and on every way a run ends once its checks have passed: at the end, after a failure, after a
`colcon` that cannot be started, after a stop signal, and when no layer was started at all
because every layer asked for has no repos. It is replaced only where nothing is or where the
file there is one this tool wrote (its first line says so). A file with other text, a link of
any kind, a directory or anything else that is not a file is left as it is and named in a
warning, and the exit status is 1: writing `setup.bash` is part of what `build` promises. A
rewrite that fails at any point of the run counts so, and is named in the closing report, even
when a later rewrite in the run works, since `setup.bash` was out of line with the record
meanwhile. A rewrite before a layer's `colcon` that fails on a `setup.bash` the tool would
replace (it cannot be written, or the record cannot be read) stops the run there, since that
`setup.bash` may still source the layer: `colcon` is not started on it, the layer gets its
record back, untouched, the later layers are not tried, and the report says so. A `setup.bash`
that cannot be read stops the run in the same way, since whether the tool wrote it cannot be
told. A `setup.bash` the tool leaves alone, one it can read and did not write, does not stop
the run: it is not the tool's to keep in line.
That differs from `sync`, which creates `setup.bash` only where nothing is and does not change
its exit status for what it finds there.

The closing report, after `colcon`'s own output, gives the layers built; the layers built with
skip or ignore options given to their `colcon`, with the options ("built with <options> given to
colcon:", whether or not a layer has packages they name, and worded apart from the "built
without sourcing" line below), a layer built under `--keep-going` and not used included; a layer
whose skip and ignore options differ from its record's, with both ("skip and ignore options given
to colcon changed:", `none` for no options), adding, when the options now name a package or a
pattern the old ones did not (a name counts once whether skipped or ignored; a pattern is
compared as text), that what an earlier build installed of a package they skip or ignore stays
in its `install/`; the skip and ignore options given with package selection, as not recorded,
when the run built a layer; a layer built on a shorter chain than before, because a layer
below it left the manifest or has no repos now, with that layer's `install/` when it is still there, since the build may have used what is left in it as the
`--keep-going` line below says; a layer built with `--keep-going` without sourcing a failed layer,
as not used; the layer that failed, with `colcon`'s exit status, where its log is and, when `colcon`
wrote `install/setup.bash` in this run, the command that sources what it did build, else that the
earlier one was removed; a layer whose `colcon` exited with 0 and wrote no `install/setup.bash`, as
not built; the layer the run stopped before, and why; the layers not tried; the layers skipped for
having no repos; the layers built before and in the run, saying when they were built on the earlier
output of a layer this run rebuilt; a layer with repos that is not built and why; the layers
recorded built but not used, because the chain below them changed (with the chain each was built on
and the run below it now) or because they are above a layer that is not built; and last which layer
`setup.bash` sources, or that nothing is built. The exit status is 0 when every layer asked for was
built or skipped, and 1 after a failure, a run stopped before a layer, a refusal, a `setup.bash`
left alone or not rewritten at some point of the run, or a `colcon` that cannot be found or started.
`colcon` is looked for on `PATH` and beside the Python running the tool, and `bash` on `PATH`, each
once, before any record is touched, and each is run by the absolute path found. Empty and relative
entries of `PATH` are passed over: `colcon` runs in each layer's directory, where such an entry
would name another directory than the one `build` was run in. A `colcon` that cannot be started ends
the run with an error; `setup.bash` is first brought into line with the record, in which that layer
is not built.

The first layer is built in the environment `build` is run in. The person sets that up
first. For a ROS project that means sourcing the setup file of the ROS distro. `build` does
not do it for them. If `COLCON_PREFIX_PATH`, `AMENT_PREFIX_PATH` or `CMAKE_PREFIX_PATH`
already holds one of this system's own `install/` directories, `build` warns that the layers
would be built with that output already on their path and says to build in a shell that has
not sourced `setup.bash`. It is a warning, not a refusal: the build still works.

Sourcing the one `setup.bash` is enough to use the system. The setup file `colcon` writes for
a layer also sets up every environment that was sourced when the layer was built, so the
last layer brings in the layers under it and the environment the first layer was built in.

`colcon` runs in a session of its own, and so in a process group of its own, which takes in every
job it starts (`cmake`, `make`, the compilers). A Ctrl-C at a terminal reaches only the tool, since
`colcon` is not in the terminal's foreground group; `colcon`'s output still goes to the terminal.
While `colcon` runs, the tool passes each stop signal it gets (SIGINT, SIGTERM, SIGHUP and SIGQUIT,
the Ctrl-\ of a terminal; one that was ignored when the tool started stays ignored) to `colcon`'s
whole group: the first as itself, so a SIGINT reaches `colcon` and its jobs as a Ctrl-C would, the
second as SIGTERM, and the third and every later one as SIGKILL. The tool waits for `colcon` to end.
However it ends, by itself, after a stop, or killed by something else such as the kernel's
out-of-memory killer, the tool then kills, with SIGKILL, whatever of the group is still running, and
waits up to 10 seconds for the group to be gone, so no job of the build goes on writing to `build/`
or `install/` after `colcon` has ended or the lock is released. A process a job means to leave
running has to leave the group, as a daemon does by starting a session of its own. A member of the
group that is the tool's own child, as when the tool runs as PID 1 or as a subreaper in a container,
is reaped while it waits; members still there after the 10 seconds are named in a warning, with the
command that lists them. The tool puts its handlers for the stop signals in place, and puts back the
ones that were there, with the stop signals held, and reads whether one came while still holding
them, so a stop signal that comes as `colcon` ends is either passed on or ends the run, never lost.
After a stop, only then does it write `setup.bash` from the record, in which the stopped layer is
not built, and print one line with the layers built in the run, the layer that was stopped, and what
`setup.bash` sources; the tool then ends by the first signal it got, even when its terminal is gone
and the line cannot be printed. The record and `setup.bash` are written with the stop signals held,
and the run's own account of which layers started and which were built changes in the same held step
as the record's write, so a signal that arrives during a write finds the line, the record and
`setup.bash` in agreement. A Ctrl-Z (SIGTSTP) stops `colcon`'s group and then the tool; when the
tool is continued (SIGCONT), so is `colcon`'s group. A terminal closed while the tool is stopped
sends it SIGHUP and SIGCONT, which end the build as above. A SIGKILL of the tool itself cannot be
caught: `colcon` then runs on, holding the distro's lock until it ends, and the layer it builds is
already out of the record and out of `setup.bash`.

Since `colcon` and its jobs are in a session of their own, they have no controlling terminal
and cannot open `/dev/tty`: a job that asks for a password or a passphrase there, such as `git`
or `ssh` fetching a dependency for CMake's `FetchContent`, or `sudo`, fails where a `colcon`
run by hand would ask. A build that fetches should get its credentials without a prompt: an
`ssh-agent` with the key added, or a git credential helper; or the sources are fetched first,
as `sync` does, and the build needs no network.

How the code is built, such as a debug or a release build, is not a distro and not part of
the manifest. It stays with `colcon`:

- Arguments after `--` are passed to `colcon` for every layer built, except those that move
  or replace what the record stands on, which are refused before anything runs, along with
  any abbreviation of them (`colcon` accepts abbreviated options): `--base-paths` and
  `--paths`, which would replace the repos `build` gives the layer's `colcon`, and
  `--install-base` and `--build-base`, which would move the output away from the layer's
  `install/` and `build/`. Also refused: a plain argument first after `--` (`colcon build`
  takes none, and `build` names layers before `--`), and a second `--`, after which `colcon`
  would read the options `build` adds as plain arguments. An abbreviation is named in the
  refusal as `colcon` would take it: as the one option it stands for, or, when it could
  stand for several, as one `colcon` would reject as ambiguous and the tool refuses first
  since it could be a refused option. The rest are passed as given, and `build` puts the
  layer's `--base-paths` after them, so an option with several values at the end of them
  (`--packages-select a b`) ends where `--base-paths` starts. `--merge-install` is passed:
  the layer's `install/setup.bash` is there with it and the layers chain as without it
  (checked with colcon-core 0.21.3).
- Package selection, any `--packages-` option but `--packages-skip-build-finished` and the four
  that leave named packages out of a whole layer (`--packages-skip`, `--packages-skip-regex`,
  `--packages-ignore`, `--packages-ignore-regex`; see "Packages left out" below), is passed too,
  and builds only part of a layer (`--packages-skip-by-dep`, `--packages-skip-up-to` and
  `--packages-skip-test-passed` are package selection: what they leave out follows from the
  dependency graph or from the test results `colcon` left in `build/`, not from a list a record
  could hold). So does `--cmake-target`, also in its `=value` form (every
  shorter spelling of it is also the start of `--cmake-target-skip-unavailable`, so `colcon` would
  reject it as ambiguous, and `build` refuses it first, as ambiguous, naming the options it could
  be): `colcon` builds that one target and skips the install step, yet exits with 0 and writes
  `install/setup.bash`, so a layer built with it would be recorded built with nothing installed
  (checked with colcon-core 0.21.3 and colcon-cmake 0.2.30, whose build step skips the install "if a
  specific target was requested"). It is the one option of `colcon build` that skips the install;
  `--cmake-target-skip-unavailable` acts only together with it and on its own is passed as any other
  option. A run with either only rebuilds layers that are built: it is refused before anything runs
  or any record is touched when it would build a layer that is not built, or one that is built but
  whose repos on disk differ from its record. The message says which of the two it found, names the
  two kinds of layer apart, each layer with why, and gives one step: build every layer it names
  without it first, in the manifest's order, which for the second kind also records the change. When
  `colcon` exits with 0 and has written the layer's `install/setup.bash`, the layer gets back the
  record it had, unchanged: its repos, its chain and its time, which so still says when the layer
  was last recorded built. The closing report names such layers as "rebuilt with selection", not as
  "built". A plain `build -- --packages-select c` on a system that is built rebuilds every layer
  with that selection: in a layer without `c`, `colcon` warns, builds nothing, exits with 0 and
  still writes `install/setup.bash`, so the layer keeps its record (checked with colcon-core
  0.21.3). A layer whose `colcon` fails is not built, as without selection; with `--keep-going` the
  layers above it are not tried, since they could only be built on another chain than their
  records'.
- `colcon` must find the packages named by `--packages-up-to`, `--packages-up-to-regex`,
  `--packages-above`, `--packages-above-and-dependencies`, `--packages-above-depth`,
  `--packages-start` and `--packages-end` among the layer's own packages, and fails a layer
  that does not have them; so `build` refuses those, before anything is touched, when the
  run would build more than one layer, and says to name the layer. A run that builds one
  layer (one layer named, or only one layer with repos) passes them. The other selection
  options (`--packages-select`, its `-regex` form and the rest), and the options that leave
  packages out (`--packages-skip`, `--packages-ignore` and their `-regex` forms), only warn about
  a name a layer does not have (checked with colcon-core 0.21.3).
- Packages left out: `--packages-skip`, `--packages-skip-regex`, `--packages-ignore` and
  `--packages-ignore-regex` build the whole layer but the packages their values name, and
  install the rest (checked with colcon-core 0.21.3 and colcon-package-selection 0.2.10;
  `--packages-ignore` also drops the package from discovery, as a `COLCON_IGNORE` file does). A
  run whose only `--packages-` options are these and `--packages-skip-build-finished` is not
  package selection: without `--cmake-target` it builds a layer that is not built yet, and a
  layer whose `colcon` exits with 0 is recorded built with the options in its record's
  `without`. A run gives them to the `colcon` of every layer it builds, so every such layer
  records them, also one that has no package they name (`colcon` only warns about a name it does
  not find); the field says what `colcon` was given, not that the layer lacks those packages.
  That is the way to build
  a layer one of whose packages does not build on a machine. An abbreviation counts when it
  stands for one of the four only (`--packages-skip-r` is `--packages-skip-regex`); one that
  could be several (`--packages-s`, `--packages-skip-`, `--packages-ig`), which `colcon`
  rejects as ambiguous, is read as package selection, so it is refused on a layer that is not
  built, before anything runs. Beside any other selection option the run is package selection,
  refused on a layer that is not built as before; on a built layer it gives back the record the
  layer had, its list unchanged, and the report names the skip and ignore options given as not
  recorded. The record holds them as `colcon` reads them: each option named in full, its values
  up to the next argument `colcon` reads as one of its options, one value in the `=value` form.
  `colcon` reads an argument that is none of its options as a value, even one starting with `-`
  (`-1`, `--foo`): the `-regex` forms take it as a pattern, and `--packages-skip` and
  `--packages-ignore` reject it, so the layer is not built (checked with colcon-core 0.21.3). So
  a list of package names ends at any argument starting with `-` (where `colcon` builds, that
  can only be an option of a `colcon` extension `build` does not list, such as `--meson-args`).
  A list of patterns ends only at an option `build` knows `colcon` to have (those of colcon-core
  and the usual extensions), since a pattern may start with `-`: an option of another extension
  after a `-regex` list, and its values, are recorded as patterns of the list, though `colcon`
  reads them as that option, so such an option is best given before the list. A package name is recorded with leading whitespace stripped,
  as `colcon` strips it (` a` is `a`); a pattern is recorded as given. Of an option given
  more than once only the last occurrence counts (`--packages-skip a --packages-skip b` leaves
  out only `b`), and one whose last occurrence has no values leaves nothing out and is not
  recorded. A regex is recorded as text, not as the names it matched. A value that holds a
  control or invisible character (a newline, a tab, a bidirectional override; the rule a
  manifest's names and values follow) or that is not UTF-8 is refused before anything runs,
  the record and `setup.bash` untouched, since the record could not hold it as one line of text;
  the message shows it with such characters escaped. The list says what the last run gave
  `colcon`, not what `install/` holds: `colcon` does not clean `install/`, so a package an
  earlier build installed stays there when a later run leaves it out (`--packages-skip b`,
  then `--packages-skip d`, left a, b, c and d installed). The layers above stay in the built
  run when a layer is rebuilt with another list, because that is an ordinary rebuild of the layer
  in place on the same chain. A package now left out may still be in the layer's `install/` from
  an earlier build, and one no longer left out was not built by the run that skipped it but may
  also have been there from before; so the layers above may or may not have used it, and `build`
  does not check. The report names the change. `build` does not check
  what depends on a package left out: `colcon` builds a dependent anyway, and it fails only in
  its own build step where it needs the package (a CMake `find_package`, say), so the layer is
  then not built, as without a list. With `--packages-skip-build-finished` beside the list the
  list is recorded as for any run that is not selection; an earlier run that did not leave a
  package out may have built it, as above.
- `--packages-skip-build-finished` is not package selection: `colcon` skips every package
  of the layer whose most recent build finished, in whichever run that was (it reads the
  result `colcon` left in the package's `build/` directory), and builds the others. A layer
  whose `colcon` exits with 0 on it is recorded built as by a plain build. That record then
  says that every package of the layer has been built at some point, not that the layer is
  up to date: a package whose sources changed since its last finished build is not rebuilt,
  nor is one that depends on a package rebuilt in this run. It is a quick way to finish a
  failed layer when nothing that already built has changed since; a plain build of the
  layer is the sure one. `--packages-select-build-failed` is package selection, since it
  builds only the packages whose last build failed (not those never tried, or aborted), so
  it is refused on a layer that is not built (checked with colcon-core 0.21.3 and
  colcon-package-selection).
- A mistake in the forwarded arguments that `colcon` rejects, such as an abbreviation it
  finds ambiguous, is found only when the first layer's `colcon` runs, after that layer's
  record has been removed, so the layer is then not built. Only a build of that layer
  without package selection brings it back (`repos-manifest build <that layer>`, with
  other arguments as wanted): a run with selection, even with the mistake corrected, is
  refused, since the layer is not built.
- `build` sees only the arguments after `--`. `colcon` also takes arguments from a global file of
  defaults and from a `colcon_defaults.yaml` in the directory it runs in, the layer's directory
  (checked in colcon-defaults 0.2.9 and with `colcon list`). The global file is the path
  `COLCON_DEFAULTS_FILE` holds whenever that variable is set, even to an empty value, and
  `$COLCON_HOME/defaults.yaml` (`~/.colcon/defaults.yaml`) only when it is not set; a relative path
  is read in the layer's directory. `colcon` reads each only when it is a file: with
  `COLCON_DEFAULTS_FILE` empty, or naming a missing path or a directory, it reads no global file,
  not even `$COLCON_HOME/defaults.yaml`, but still reads the layer's `colcon_defaults.yaml`. A mixin
  (`--mixin`) adds arguments `build` does not see either. Package selection set there, or a
  `--cmake-target`, builds only part of a layer, yet `build` does not see it: when `colcon` exits
  with 0 and writes `install/setup.bash`, the layer is recorded built as a whole. Packages left
  out there (`--packages-skip`, `--packages-ignore`) are not seen either, so they are not in the
  record's `without`, and the note below says so. Before it starts
  `colcon`, `build` prints a note naming each such file `colcon` will read, as `colcon` finds it:
  the global file once (before the layer when its path is relative), a layer's
  `colcon_defaults.yaml` before that layer. A file `colcon` will not read is not named; a mixin is
  never named. One that sets a refused option is not seen either; one that moves `install/` leaves
  the layer not built, since its `install/setup.bash` is not written. Nor does `build` see a CMake
  argument that drops the install rules: `colcon` then warns that the package has no `install`
  target and goes on (read in colcon-cmake 0.2.30).
- A person who wants a layer always built a certain way, such as a release build, can put
  that in the layer's `colcon_defaults.yaml`, as long as it selects no packages, leaves none out
  and skips no install: what is set there is not seen by `build`, and the record cannot tell a
  whole layer from part of one, nor say what was left out.

### status

```
repos-manifest status [--distro <name>] [--json]
```

Shows, for each distro it acts on, what the system directory holds against what the manifest says.
It changes nothing on disk and makes no network call of its own. It takes no lock, writes no resolved files,
no record and no setup file, and it does not fetch: every answer is about the clones as they are, with
what `origin` had when each was last fetched (by `sync`, or by hand). Every `git` it runs passes
`--no-optional-locks`, so even `git status` does not rewrite a clone's index.

`status` writes nothing in the system directory and makes no network call of its own. It runs
the clean filters a clone's own configuration names (a Git LFS filter is one), as `git status`
does, so `status`, `git status` and `sync`'s git count the same files as changed; a filter that
writes or fetches is outside what `status` can promise. Two other helpers a clone's configuration
could have git start are turned off for `status`'s own git calls, because neither can change the
answer (`sync` runs its git as before):

- an fsmonitor hook (`core.fsmonitor`) is not started: every call passes `-c core.fsmonitor=false`.
  The hook only tells git which files it need not look at again; with none, git looks at every
  file, which is what a working hook stands in for;
- a partial clone does not fetch a missing object: every call runs with `GIT_NO_LAZY_FETCH=1`.
  The objects `status`'s git reads are the commits and tags of the clone's refs, what those tags
  name, and the trees and files of what is checked out, and a partial clone has each of them.

Git runs no hook for the commands `status` runs. `sync` fetches first,
so a repo can read differently after a fetch: a version that was not fetched yet is `unusable`
until then, and a branch behind `origin`'s counts only the commits fetched. Three cases differ
even after a fetch:

- a remote-tracking ref left from a branch `origin` deleted: `sync` never prunes, so `status`, which
  reads the refs, calls the branch expected while `sync`, which asks `origin`, says it is not there;
- a tag here that `origin` lacks: offline it cannot be told from `origin`'s tag, so `status` counts it;
- a url that the manifest changed while the record still matches `origin`: `sync` tries to repoint
  `origin` and then fetches from the new url, `status` answers from the refs of the old one.

A `--remote` that asks `origin` itself is not built.

Which distros: as for `sync` (see "Which distro a command uses"): every distro at the top of a system
with a directory per distro, in the order of `distros`; the one whose directory the current directory
is inside; or the ones `--distro` names.

It prints the system directory, the manifest in use (as `config.yaml` records it), the role and the
groups that are on, and, for a manifest with distros, every distro the system directory was set up
for (`config.yaml`'s `distros`), with the ones shown marked. The manifest is read and resolved as
`sync` reads it, from where it is now: a manifest in a clone that `sync` has not updated yet is read
as it is.

For each repo of the manifest, in layer order, one state, and facts that go with it:

| State | Meaning |
|---|---|
| expected | on the manifest's version, by the rules `sync` follows: on the branch it names, or detached at its tag or commit. A branch behind `origin`'s is still expected; `behind` says how far, and the text says whether `sync` tries to fast-forward it or what stops it first: uncommitted changes, a remote of the name `sync` keeps for checking a new url (`repos-manifest-probe`) while the manifest changed the url, or another work tree holding the branch. A fast-forward `sync` tries can still be stopped by a path or a submodule in the way, which `status` does not check. A branch with commits only here (`sync` leaves it as it is) and a branch another work tree holds are expected, with the commits or the work tree named. A clone `merge_pr.sh` fast-forwarded past the recorded commit is expected. |
| different | there, and on another branch, tag or commit; on the manifest's branch but not contained in `origin`'s with no commits only here (rewritten upstream, as `sync` says); on the version it was recorded on while the manifest now names another (`sync` tries to move it when nothing stops it first; it leaves it for a remote of the probe's name with the url changed, uncommitted changes, commits only here, a local new branch with commits not on `origin`, or the new branch held by another work tree: the text says which, in that order); or the manifest's version is a commit no branch or tag of `origin` holds. The text says where it is and what the manifest names. |
| left-alone | there, and `sync` leaves it as it is, so `status` does not compare its version: a link at the place, a rebase, merge, bisect or other operation in progress, `index.lock`, a sparse checkout, or an `origin` with more than one url. The text says which. |
| unusable | there, but `status` cannot use it as a clone of the manifest's version: not a git repo of its own, no commit checked out, no `origin` url at all, the manifest's version cannot be found among the refs `origin` had when last fetched or names no single commit there (a branch and a tag of the same name, a tag of something that is not a commit, a commit missing from a shallow clone, no version and no recorded default branch), or `git` cannot read its state (`git status` or the count of commits not on `origin` fails). The text says which. |
| missing | not there. `sync` clones it, and reports an error only when the clone fails. |
| skipped | not there and optional: listed every time, as `sync` lists an optional repo it could not clone. `sync` clones it when it can. |
| not-a-directory | a file or other non-directory is at the repo's place, or on the way to it (`sync`: "is there and is not a directory", "is on the way and is not a directory"). |
| blocked-place | the check on the real destination fails: a link on the way to the place (a layer directory or a directory of the repo's key) leads somewhere else (`sync`'s rule 2). |
| in-other-layer | the manifest gives the repo another layer than the record and the old place is there; the text gives the old place and the commands that move it (`sync`'s rule 1). |
| not-in-manifest | recorded by `sync`, still on disk, and no longer in the manifest. Only repos in `state.yaml` can be found; a directory `sync` never recorded is not looked for. |

`not-a-directory`, `blocked-place` and `in-other-layer` mean the repo is not at its place: `sync`
reports each as an error for a repo that is not optional, and `build` refuses the layer. A
`missing` repo is not at its place either, until `sync` clones it. An optional repo is listed in
any state and does not fail the exit status; `sync` follows the same rule, as it turns whatever
stops an optional repo into "skipped".

The two states for a repo that is there and cannot be compared differ in what a script does:
`unusable` exits 1, `left-alone` exits 0. A `sync` stopped while moving a repo is not a state: when
the record's `moving` line names the commit the repo is on, the text and the `stopped_move` fact say
so beside whichever state the repo has, as `sync` adds it to another message and goes on. A `moving`
line that names another commit is not used (`sync` drops it; `status` leaves it).

Facts, for a repo that is there: `changes` (tracked files changed, counted as `sync` counts them),
`unpushed` (commits reachable from `HEAD` and from no remote-tracking ref of `origin`, counted as
`sync` counts them: on a branch only, null when `HEAD` is detached), `behind` (commits of `origin`'s
branch the clone lacks, on the manifest's branch), and `fetched_from`, the url of `origin`, with any
user name and password masked. As `sync` does, `status` registers every url it reads (each repo's url
in the manifest, each recorded url, each `origin`) before it prints anything, so the user name and
password of each is masked wherever it appears, in the JSON, in the lines a person reads and in error
texts, and the manifest's location is masked too. When it is not the manifest's url the text says which: it is the url recorded,
so `sync` tries to repoint it (fetching from the new url first, and leaving `origin` and the repo as
they are when that fetch fails or a local commit is not on the new url), or `sync` leaves it because a
remote named `repos-manifest-probe` is set here; or it was set by hand and is left. A repo can be expected and have
changes and unpushed commits at once, as `sync` leaves such a repo as it is; the state is the
version, the facts are separate.

A human line is `<path>  <state>: <text>`, with `(optional)` after the state for an optional repo,
and the facts that are not zero in brackets at the end. With `--json` the one document on standard
output is the same information:

```
{ "format": 1, "ok": true, "system": "<absolute path>", "manifest": "...", "role": "...",
  "groups": [...], "layout": "flat|distro-dirs", "recorded_distros": ["jazzy", "rolling"] | null,
  "distros": [ {
    "distro": "jazzy" | null, "ok": true, "problem": null,
    "repos": [ { "key": "...", "path": "jazzy/core/src/a", "layer": "core", "optional": false,
                 "state": "expected", "detail": "...", "version": "...", "head": "<commit>",
                 "changes": 0, "unpushed": 0, "behind": 0, "stopped_move": false,
                 "url": "...", "fetched_from": "..." } ],
    "not_in_manifest": [ { "key": "...", "path": "..." } ] } ] }
```

`version` is what the manifest names; `path` is relative to the system directory; `layer` is the
layer's name, `_unnamed` for the unnamed first layer, as the resolved files name it; `changes`,
`unpushed` and `behind` are null where the repo is not there, `status` cannot count, or
(`unpushed`) `HEAD` is detached, and all three are null for `left-alone` and `unusable`, which
`status` does not compare; `behind` is null off the manifest's branch; `stopped_move` is false where
it does not apply. `recorded_distros` is every distro the system was set up for, null when the
manifest has none; `distros` holds the ones acted on.

`ok` is given at two levels. A distro's `ok` is true exactly when that distro would not fail the
exit status on its own: it was read and resolved, and no repo of it that is not optional is in a
failing state (`missing`, `not-a-directory`, `blocked-place`, `in-other-layer` or `unusable`). A
distro's `problem` is null when it resolved, and otherwise says why it could not be read or
resolved; a manifest that cannot be read is the problem of every distro. A distro with a problem
has `ok: false`, and its `repos` and `not_in_manifest` are left out of its entry, not given as
empty lists, since nothing of it was compared. A distro that resolved and has a failing repo has
`ok: false`, a null `problem`, and its `repos` and `not_in_manifest` as usual. The top `ok` is true
exactly when the exit status is 0, that is when every distro's `ok` is true. Nothing else is printed on standard
output with `--json`; warnings go to standard error. When the system directory cannot be found or
read (or a `--distro` names one it does not record) there is no document: the error goes to
standard error and the exit status is 1.

Exit status: 1 when a repo of a distro asked for that is not optional is missing or not at its place
(`missing`, `not-a-directory`, `blocked-place`, `in-other-layer`) or is `unusable`, when a distro's
manifest cannot be read or resolved, or when the system directory cannot be found or read; 0
otherwise. States `expected`, `different`, `left-alone` and `not-in-manifest`, local changes and
unpushed commits do not change the exit status: `status` reports them, and a script reads `state`.
(2 is the argument parser's, for a bad option.) The workspace's `validate` does not run `status`
yet: the adapter will call it under issue 503, the issue where the adapter calls the tool's
commands, and `validate` is then to fail when `status` exits 1.

In plain words, a repo fails the exit status when it is not there, or is there but is not a git
clone with a commit and an `origin`, or its version cannot be found among the refs of its last
fetch, or git cannot read its state. A rebase, merge or bisect in progress, an `index.lock`, a
sparse checkout, a link at the place, an `origin` with two urls, a repo on another branch, local
changes and unpushed commits are reported and do not fail it.

### freeze

Writes a manifest that records the exact commit of every repo the machine has, for one
distro. It acts on one distro, chosen as for `build` (see "Which distro a command uses").

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

When the manifest itself gives a cloned repo another url, the url rule under "sync" applies:
`origin` is repointed only when it still has the url `sync` recorded and every local branch is
on the new one, and an `origin` a person set is left as set. To push over ssh while fetching
from the url the manifest names, set `remote.origin.pushurl`, or `url.<base>.pushInsteadOf`.

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
  together cleanly, the repo is put back as it was, reported, and left for a person. This is
  not built yet: `sync` now leaves a repo with commits not on `origin` as it is and prints the
  next step: the `git pull --rebase` command when `origin`'s branch has commits the clone
  lacks, and otherwise the `git push` command that publishes the clone's commits.
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
    --distro-dirs --fetch-from https://github.com/developer/ --fetch-fallback \
    --remote field=git@git.example.org:field/
```

Besides the manifest's location, `config.yaml` then holds:

```yaml
role: developer
layout: distro-dirs
distros:
  jazzy: {}
  rolling: {}
fetch_from:
  prefix: https://github.com/developer/
  fallback: true
remotes:
  field: git@git.example.org:field/
```

The developer role switches on `simulation` and `ui`. Each distro has its own directory, and
another can be added later with `add-distro`.
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
layout: flat
distros:
  jazzy: {}
fetch_from:
  prefix: git@git.example.org:field/
  fallback: false
```

The system directory is flat: it has no directory per distro, and the layers are directly in
it. The robot role leaves `simulation` and `ui` off. A layer that holds only such repos is empty
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

- `vcs`, from vcs2l or vcstool, found on `PATH`, to clone repos. The package's test extra
  installs vcs2l for the tests.
- `colcon`, to build a layer.
- `git` 2.23 or later, to update repos that are already cloned, to read their state, to check
  whether a repo exists at another place and to add remotes.
- Python with PyYAML.

The tools call `vcs` and `colcon` as commands. They do not import them as libraries. Every
`vcs` and `git` they run gets their environment without the variables that point git at a
particular repository or its parts, so a run from a git hook acts on its own clones and not on
the repo the hook runs in. Those are the names `git rev-parse --local-env-vars` prints, such as
`GIT_DIR`, except `GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT`, and `GIT_NAMESPACE`, which
that list does not name. The two kept carry configuration given by `git -c` or by
`GIT_CONFIG_COUNT` and its `GIT_CONFIG_KEY_<n>` and `GIT_CONFIG_VALUE_<n>`, such as a url
rewrite or a credential header, and git keeps the same two when it runs a command in another
repository.

Not every command needs all of these:

| Command | Needs |
|---|---|
| `show`, `resolve`, `validate` | Python with PyYAML; `git` when a manifest is read from a git repo, or when `fetch_from` has a fallback |
| `status` | `git` as well, 2.23 or later; not `vcs`, which it never runs |
| `init`, `sync`, `freeze` | `vcs` and `git` as well |
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
- Running a distro the host OS does not support, in a container or otherwise. The distros
  are recorded, and the commands assume the environment they run in can build the distro
  they act on.
- Leaving out some packages of a repo. Groups and roles select whole repos. A person can
  pass `colcon` its own options for skipping packages through `build`.
- Content that is not in a git repo, such as models or data downloaded at build time.

## What is built

`resolve` and `validate` read the format in the specification, given as a path on the local
disk. A manifest's `base` is read when it names paths on the local disk; a `base` given as a
URL or as a file in a git repo is refused with a message that says this version reads a path
only. `resolve` writes the files described under "resolve" into `--out`. `validate` checks the
manifest and everything it builds on, prints a `base:` line for each manifest it builds on, in
the order they were read, and resolves it for every role and distro it lists, writing nothing.
`--role` or `--distro` limits the check to that role or distro, and `--with` switches on extra
groups in each one.

A manifest without a top-level `repositories:` or `base:` key, or a file that does not read as
YAML, still goes to a prototype that reads an earlier shape of the format, where repos are
nested under their layer and the version key is `ref`. A caller that needs `repos/<layer>.repos`,
`layers.txt` and `optional_layers.txt` uses that reader, with `--layout manifest-dir`. The
prototype also has three things this design drops: a `packages:` section with package
dependencies, roles defined by starting packages, and a cache of fetched parent manifests that
is kept between runs.

Two things in the prototype differ from this design in smaller ways. It marks whole layers
as optional, where the design marks repos. And when it fetches a parent manifest from a git
repo it never lets git or ssh ask for a password, where the design lets them ask at a
terminal.

`init` and `sync` are built for a manifest given as a path on the local disk, flat or with
`--distro-dirs`: setting a system up, cloning the repos that are missing, and updating the
ones that are there by the rules under "sync", except the rebase of commits not on `origin`
(such a repo is left as it is). `sync` reads the manifest and resolves every distro it acts on,
and builds the text of each distro's resolved files, before it changes anything. A manifest
that cannot be read ends the run with nothing changed, since every distro reads the one
recorded location; a distro whose manifest does not resolve, whose resolved files cannot be
written out, or, on a flat system, whose manifest now has distros, is reported, and the others
go on. Each of those errors ends by saying that the manifest's path is the one recorded in
`config.yaml`, taken from the system directory. Two names that a disk which ignores case
treats as one are not checked yet on the real destination.

`status` is built as "status" describes, for a manifest given as a path on the local disk. It
reads only and makes no network call, with the limits "status" lists. Some of its checks are
`sync`'s own code, called by both: resolving the manifest, the record's layer and the check on the
real destination, the first checks on a repo (a git repository of its own, a commit checked out, no
operation in progress, no `index.lock`, not sparse, one `origin` url, a stopped move), counting
changes and commits not on `origin`, finding the manifest's version and whether a commit is on
`origin`, and whether a remote has the probe's name. The rest is a second copy: what `sync` does
once it has the version (its rules 9 to 12, `standing` in `update.py`), and, in `status.py`, the
checks on the place itself (not there, not a directory, a link) and the order in which `sync` stops
at the url and at uncommitted changes before its rules 9 to 12. The two copies are held in
step by a test that runs `status` and then `sync` on each case and checks both the state and every
sentence of `status`'s text that says what `sync` does against what `sync` then did. Routing `sync`
through `standing` would change the control flow of the code that protects local work, so it is not
done. The cases where the two read a repo differently, because `sync` fetches first, are listed in
"status".

`show` is built for a manifest given as a path on the local disk, and with no manifest inside
a system directory, as "show" describes. It prints a manifest's own URLs, since fetching from
another place is not built.

`build` is built as "build" describes, for one distro at a time, stopping at the first layer
that fails unless `--keep-going` is given. It reads the resolved files `sync` wrote and needs `colcon` on `PATH` or beside the
Python running it.

Not built yet: step 1 of "sync" (the manifest's own clone), the rebase of a repo with commits
not on `origin`, `local_manifest`, the git and URL forms of a manifest's location with `--manifest-ref` and
`--manifest-path`, arguments after `--` for `init` and `sync`, `add-distro`, `freeze`,
fetching from another place and extra remotes.

## Open questions

- With `fallback: true`, how often to ask whether a repo exists at the other place. Asking
  for every repo on every sync costs a network call per repo.
- With a directory per distro, whether a distro needs more settings of its own than a
  `manifest_version`: a different role or groups, or a `local_manifest` path that differs
  between distros. A distro's own manifest version is settled: it is used whenever the distro
  reads the recorded location.
- How a distro is removed from a system with a directory per distro.
- What a distro's manifest that lacks the system's role or one of its groups gives at
  `add-distro`.
