# Plan: repos-manifest design: start with one distro and add more later, without moving the first

## Issue

https://github.com/rolker/agent_workspace/issues/495

## Context

The tool's design (`tools/repos-manifest/docs/design.md`) says "The layout is chosen at `init`.
A system directory set up for one distro has no distro directories." A system that starts with
one distro therefore has to be moved when a second one is added. The issue asks for a system
that starts with one distro and gains others later, without moving the first. This issue
changes the tool's documents (and one set of sentences in `docs/manifest/design.md`) to say
how. It is documents only, no code.

The owner answered the three design questions on 2026-11-18 (quoted under "Owner's decisions").
This revision is written around those answers. In short:

- Flat is the default. A system with one distro (or none) has `src/` and the rest directly in
  the system directory. `init --distro-dirs` asks for a directory per distro.
- `repos-manifest add-distro <name>` adds a distro, and only to a system set up with
  `--distro-dirs`. On a flat system it refuses and changes nothing.
- A distro may read its own manifest, or the one manifest of the system.

## Names chosen (the owner may veto)

- `--distro-dirs`: the flag on `init` that gives one directory per distro. It names what the
  person gets (directories for distros), and reads the same in the design text, in the
  `init` description and in a refusal message. `--per-distro` was rejected because it also
  sounds like per-distro settings; `--layout distro-dirs` was rejected as longer for a choice
  with two values. The recorded key is `layout: distro-dirs` or `layout: flat`.
- `add-distro`: the command that adds a distro, as `repos-manifest add-distro rolling`.
  Chosen over `distro add` because the tool's commands are all one word and there is no
  other `distro` command to group it with.

## What issue 500 waits for

Issue 500 (`init` and `sync`) can start once these are written in
`tools/repos-manifest/docs/design.md`. They are the first commit of the implementation.

1. Layout rule.
   - Flat is the default. A system set up flat holds one distro, or none when the manifest has
     no `distros:`. Its layers (or `src/`, `build/`, `install/`, `log/` when the manifest has
     no layers) and `setup.bash` are directly in the system directory.
   - A system set up with `init --distro-dirs` has one directory per distro directly in the
     system directory. Each is an ordinary colcon workspace, or holds one directory per layer
     when the manifest has layers, and holds its own `setup.bash`.
   - The choice is made at `init` and cannot be changed afterwards. A flat system can never
     gain a second distro in place, because the first distro's directories would have to
     move. To have several distros, set up a new directory with `--distro-dirs` and a fresh
     clone. A manifest with no `distros:` is flat and has nothing to add.
2. `config.yaml`.
   - `manifest`: as today (a path, a URL, or the mapping `url`, `version`, `path`). The
     manifest of every distro that has none of its own.
   - `local_manifest`: optional, one path, as today. In a per-distro system it is read inside
     each distro's directory, the same path in every distro. There is no per-distro form.
   - `role`, `groups`, `fetch_from`, `remotes`: as today, shared by every distro.
   - `layout`: `flat` or `distro-dirs`. Always recorded.
   - `distros`: a mapping from each distro's name to its settings, one shape for one distro
     or several. Absent only when the manifest has no `distros:`. The only setting an entry
     may carry is `manifest` (same forms as the top-level key); an empty entry is `{}`. A flat
     system has exactly one entry. The key `distro` is removed.
3. `init`.
   - `init <manifest> --distro <d> [--distro-dirs]` sets up a directory. Without
     `--distro-dirs`, exactly one `--distro` (or none, when the manifest has no `distros:`).
     With it, one or more `--distro`, and it is refused when the manifest has no `distros:`.
   - `init` has one job, setting up a new directory. It refuses a directory that already has
     `.repos-manifest/`, changing nothing, and says to use `sync`, or `add-distro` for a
     per-distro system. (What `init` does for a directory whose first `init` failed early is
     the re-runnable `init` ask in the workspace design's list, not this issue; until it is
     designed `init` refuses there too and points to `sync`.)
   - What `init` prints: what it prints today, plus one line when the system is flat and has a
     named distro: "Layout: one directory for the system, with no directory per distro. A
     distro cannot be added to this system later. To be able to add one, set up with
     `--distro-dirs`." It is part of the text printed before the question `init` already asks,
     so it is no new question; `--yes` skips the question and still prints the line. A
     manifest with no distros prints nothing about layout, since there is nothing to add.
4. Where state and resolved files go.
   - `.repos-manifest/resolved/<distro>/` in a per-distro system; `.repos-manifest/resolved/`
     directly in a flat one.
   - `.repos-manifest/state.yaml` records the version and commit last put on each repo. Its
     inner shape is issue 500's. The design needs one thing of it: writing one distro's entries
     must leave every other distro's as they were (one file per distro beside `resolved/` is
     one way to get that).

`add-distro`, its text and its tests are not needed to start. Issue 500 can build first-distro
`init` and `sync` from items 1 to 4 and add `add-distro` afterwards without redoing the layout:
everything `add-distro` writes (a `distros` entry, a directory, `resolved/<distro>/`, state)
has its place fixed above.

## Which distro and which manifest a command uses

One rule for the distro, one for the manifest. Both go in "More than one distro" and the
Commands section, stated once and pointed to.

### Distro, inside a system directory

- A flat system has one distro (or none); every command uses it.
- In a per-distro system: `--distro <d>` if given (it wins over the current directory);
  otherwise the distro whose directory the current directory is inside; otherwise (at the top,
  or in `.repos-manifest/`):

| Command | At the top of a per-distro system |
|---|---|
| `sync`, `status` | every distro, in the order of `distros`; `--distro` (repeatable) names a subset |
| `show`, `resolve`, `build`, `freeze` | the system's only distro if it has one; with several, an error that lists them |
| `add-distro` | takes the name as its argument; the current distro plays no part |
| `init` | not run in a system directory |

- Outside a system directory, `show`, `resolve` and `validate` take the distro as an argument,
  as today.

### Manifest

The manifest of a distro is the first of these that exists:

1. the local copy: `local_manifest`, read inside that distro's directory (the system
   directory when flat), once the file exists;
2. the distro's own `manifest` entry in `distros`;
3. the top-level `manifest`.

Items 2 and 3 are the locations to read from before a local copy exists. A distro's own entry
is not a first-sync-only setting: a distro with its own manifest and no `local_manifest` reads
that location on every read; one with a `local_manifest` reads its own clone from the second
read on. A distro never reads another distro's local copy. Per command, each distro acted on:

| Command | Reads |
|---|---|
| `sync` | step 1 updates the clone that distro's `local_manifest` is in; step 2 resolves from that distro's manifest, parents included |
| `show`, `resolve` | that distro's manifest (inside a system directory) |
| `status`, `freeze` | that distro's manifest |
| `build` | no manifest; it uses `resolved/<distro>/` from the last resolve |
| `add-distro` | the new distro's location: the arguments given, else the top-level `manifest`; no local copy exists yet. It refuses when the manifest does not list the distro |
| `init` | the location given on its command line, for every distro it sets up |

### What `sync` does when the manifest's `distros:` changes

The manifest read for a distro is checked against what the system recorded. Where it
disagrees, `sync` reports it for that distro, changes nothing for it, and goes on with the
other distros:

- the manifest no longer lists a recorded distro (or lists no distros at all): the message
  names the distro, says nothing has been moved or removed, and says the manifest or
  `config.yaml` has to be corrected. Nothing is deleted.
- a flat system recorded no distro (its manifest had none) and the manifest now has
  `distros:`: resolving for no distro is then an error (spec.md, "Distros"). The message says
  nothing is moved and that a system with distros is set up in a new directory with
  `--distro-dirs`.
- the manifest lists more distros than the system records: nothing happens. A distro is
  added only with `add-distro`.

## `config.yaml`, three cases

A flat system with one distro (the default):

```yaml
manifest: ./system.manifest.yaml
layout: flat
distros:
  jazzy: {}
```

A per-distro system, one manifest for all (`init <manifest> --distro jazzy --distro rolling
--distro-dirs`, or `add-distro rolling` afterwards):

```yaml
manifest:
  url: git@git.example.org:field/unh_marine_autonomy.git
  version: main
  path: project11.manifest.yaml
local_manifest: core/src/unh_marine_autonomy/project11.manifest.yaml
role: developer
layout: distro-dirs
distros:
  jazzy: {}
  rolling: {}
```

A per-distro system where `rolling` has its own manifest version (`init <manifest>
--manifest-ref jazzy --distro jazzy --distro-dirs`, then `add-distro rolling --manifest-ref
rolling`; the parts of the location that are not given come from the top-level `manifest`, and
the entry records all three):

```yaml
manifest:
  url: git@git.example.org:field/unh_marine_autonomy.git
  version: jazzy
  path: project11.manifest.yaml
local_manifest: core/src/unh_marine_autonomy/project11.manifest.yaml
role: developer
layout: distro-dirs
distros:
  jazzy: {}
  rolling:
    manifest:
      url: git@git.example.org:field/unh_marine_autonomy.git
      version: rolling
      path: project11.manifest.yaml
```

## `add-distro`

```
repos-manifest add-distro <name> [<manifest>] [--manifest-ref <ref>] [--manifest-path <path>] [--yes] [-- <vcs import args>]
```

Takes the same location arguments as `init` for the manifest, all optional, and no other
setting: no `--role`, `--with`, `--fetch-from`, `--remote` and no flag for `local_manifest`
(an unknown flag is an error). Those are shared by every distro and are changed by editing
`config.yaml`. Steps: read the manifest as above; refuse if it does not list `<name>`; print
what `show` prints for that distro and ask (`--yes` skips); add the entry (with `manifest` only
when a location was given); sync that distro only. A sync that fails part way is finished with
`sync`, as for `init`. Nothing of the distros already there is moved or rewritten.

It refuses, changing nothing, when:

- the system is flat. The message: "This system directory was set up without a directory per
  distro, so a distro cannot be added to it. Nothing has been moved. To have more than one
  distro, set up a new directory with `repos-manifest init <manifest> --distro <d> --distro
  <d2> --distro-dirs`."
- the distro is already in `distros`;
- the manifest does not list the distro;
- the manifest has no `distros:`.

## The directory trees

The smallest system: one repo, one distro, no layers, no roles. It is flat by default; the
tools do little more than `vcs` and `colcon`.

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

The same project set up with `--distro-dirs`. The cost against the flat one is one directory
level and `resolved/jazzy/`:

```
my_system/
  .repos-manifest/
    config.yaml        layout: distro-dirs, distros: {jazzy: {}}
    state.yaml
    resolved/
      jazzy/
        _unnamed.repos
  jazzy/
    src/
      my_repo/
    build/  install/  log/
    setup.bash
```

After `repos-manifest add-distro rolling`. Nothing of `jazzy/` or `resolved/jazzy/` is touched:

```
my_system/
  .repos-manifest/
    config.yaml        distros: {jazzy: {}, rolling: {}}
    state.yaml         rolling's entries added; jazzy's as they were
    resolved/
      jazzy/           unchanged
      rolling/         new
        _unnamed.repos
  jazzy/               unchanged, not moved or rewritten
    src/  build/  install/  log/  setup.bash
  rolling/             new
    src/
      my_repo/
    build/  install/  log/  setup.bash
```

When a project later adds layers, the repos that name no layer stay where they are (in the
system directory when flat, in the distro's directory otherwise) and named layers get
directories beside them, as the design already says.

## Places in the documents that the rule touches

Paths are under `tools/repos-manifest/` unless stated; line numbers are the present files'.
Text for the design follows the owner's style: plain sentences, no bold lead-ins, the tool's
documents say nothing of the workspace or its adapter.

| Where | Present text | Will say |
|---|---|---|
| `docs/design.md` L24-37, "The system directory", first diagram | layers and `setup.bash` directly in `my_system/` | Diagram kept: it is the flat layout. One sentence added under L39-41: "This is the layout of a system with one distro or none. A system set up with a directory per distro puts each distro's layers and setup file in a directory of its own; see 'More than one distro'." |
| L56-69, `config.yaml` example | `local_manifest: core/src/...` and `distro: jazzy` | `layout: flat` and `distros:` with `jazzy: {}` |
| L73-74, table | `manifest`: "Where the manifest is." `local_manifest`: "A path inside the system directory that is used instead, once that file exists." | `manifest`: "Where the manifest is, for every distro that has none of its own." `local_manifest`: "...inside the system directory, or inside each distro's directory when there is one per distro; the same path in each." |
| L77-78, table | `distro`: "The distro of this system, if the manifest has distros." `distros`: "In place of `distro`, when the system directory holds more than one." | `layout`: "`flat` or `distro-dirs`. Chosen at `init`, not changed afterwards." `distros`: "The distros of this system, each with its settings (`manifest`, if the distro has its own). One or several. Absent when the manifest has no distros." |
| L82-83 | "`role`, `groups` and `distro` are facts about the machine, which is why they are recorded here" | "`role`, `groups`, `layout` and `distros`" |
| L85-131, "More than one distro" | "A development machine often carries two distros... The system directory can then have one directory per distro" through "The layout is chosen at `init`. A system directory set up for one distro has no distro directories, as in the first diagram." | Rewritten; heading kept so links hold. Opens with the layout choice and its limit, drafted below. Keeps the example tree for two distros, the config example (now with the mapping), the `build` text. Adds "Adding a distro", "Which distro a command uses" and "Which manifest a distro reads", and the `sync` rule for a changed `distros:` goes under "sync" |
| L115-118 | "`local_manifest` is then a path inside the distro's directory, so each distro uses the copy of the manifest in its own checkout" | Kept in substance: same path in each distro's directory |
| L120-122 | "A command run inside a distro's directory acts on that distro. Run at the top of the system directory, `sync` and `status` act on every distro in turn, or on the ones named with `--distro`." | Replaced by the distro rule above |
| L129-131 | "A manifest without layers gives each distro directory an ordinary colcon workspace." | Kept as a sentence in the per-distro paragraph |
| L143-146, init examples | one `--distro jazzy` | Unchanged: flat and one distro. A third example added after them: `init <manifest> --distro jazzy --distro-dirs` |
| L196-208, Commands table, `init` | "Records the manifest, role and distro in a new system directory, then syncs." | "Records the manifest, role and distros in a new system directory, then syncs. With `--distro-dirs` each distro gets a directory of its own, and distros can be added later. Without it the system holds one distro and cannot gain another. Refuses a directory that is already set up." New row: `add-distro`: "Adds a distro to a system set up with `--distro-dirs`, then syncs it." |
| L209-216, walk-through | `init <manifest> --role robot --with ben-hardware --distro jazzy`, `build`, `source setup.bash` | Unchanged (flat, `setup.bash` at the top is right). A second walk-through added: `init ... --distro jazzy --distro-dirs`, `build`, `source jazzy/setup.bash`, and later `add-distro rolling` |
| L225-227 | "`show`, `resolve` and `validate` also work outside a system directory, with the manifest, role and distro given as arguments." | Adds: inside a system directory, the distro is chosen as under "More than one distro" |
| L259-260, show | "Inside a system directory it uses what `config.yaml` records" | adds "and that distro's manifest" |
| L266-267, `init` prints | "`init` prints the same thing and asks before it fetches." | Adds the layout line for a flat system with a named distro (text above) |
| L271-272, resolve | "writes into `.repos-manifest/resolved/`" | "...into `.repos-manifest/resolved/`, or `.repos-manifest/resolved/<distro>/` when there is a directory per distro" |
| L284-296, sync steps | "Update the clone that `local_manifest` points into"; "the manifest is read from the location given to `init`" | "for each distro acted on"; "from the location recorded for that distro (its own `manifest`, else the top-level one)". The three rules for a changed `distros:` added |
| L309 | "`.repos-manifest/state.yaml`, for each distro when there is more than one" | "for each distro" |
| L343-344, build | "in the system directory, or in the distro's directory when the system directory holds more than one distro" | "...or in the distro's directory when there is one per distro" |
| L371-373, status | "Shows the manifest in use, the role and the distro" | adds "for each distro it acts on" |
| L377-379, freeze | "With more than one distro in the system directory it acts on one at a time, as `build` does." | "It acts on one distro, chosen as for `build`." |
| L538-556, development machine | `init ... --distro jazzy --distro rolling` and `distros: [jazzy, rolling]` | the command gains `--distro-dirs`; config shows `layout: distro-dirs` and the `distros` mapping |
| L565-577, field machine | `distro: jazzy` | `layout: flat` and `distros: {jazzy: {}}`, with a line that its system directory has no directory per distro |
| L649-650, "Not covered" | "`distro` is recorded, and the commands assume the environment they run in can build it." | "The distros are recorded, ..." |
| L667-668, "What is built" | "`show`, `init`, `sync`, `build`, `status`, `freeze`, the system directory... are not built." | Add `add-distro` to the list. No other edit |
| L676-677, open questions | "With more than one distro, whether a distro needs its own settings, such as a different `manifest` URL for its first sync or a different role." | A per-distro `manifest` is settled and used on every read. Open: a per-distro role or groups, a `local_manifest` path that differs between distros, removing a distro from a system |
| `README.md` L52 | "A development machine can hold more than one distro of the same system side by side." | "A system set up with a directory per distro can gain a distro later, without moving the first. A system set up without one holds a single distro." |
| `docs/roadmap.md` L40 | "A system directory can hold more than one distro, each in its own directory" | "A system set up with a directory per distro gains another distro later, without moving the first" |
| `docs/spec.md`, `docs/prototype.md` | grep for "distro": spec.md uses it for the manifest format; prototype.md for the prototype's `resolve` | No change |

Draft of the opening of "More than one distro" (the limit where a person choosing at `init`
reads it):

> A system directory holds one distro, or one directory per distro. This is chosen when the
> system is set up and cannot be changed afterwards.
>
> By default a system directory holds one distro, and its layers, or `src/` when there are no
> layers, are directly in the system directory. A system set up this way can never gain a
> second distro in place: the first distro's directories would have to move. To have several
> distros, set up a new directory and clone again.
>
> With `init --distro-dirs` each distro has a directory of its own, from the first distro on,
> even when there is only one. A distro is added later with `add-distro`, and nothing of the
> distros already there is moved. The cost is one more level of directories. A person who
> may want a second distro later asks for `--distro-dirs` at the start.

## Changes in `docs/manifest/design.md`

Only these sentences. The workspace's `setup` verb must ask for the per-distro layout whenever
it sets a project up that has a distro, because under the owner's answer 1 that layout is the
only one that can gain a distro, and the owner's requirement is a project that starts with one
distro and adds more.

| Where | Present text | Will say |
|---|---|---|
| L132-134, "Nothing in this section is built" bullet | "a change to the tool's design that is not made yet: a directory per distro from the first distro on, and adding a distro later (#495). The tool's design today gives a system set up for one distro no distro directories;" | "a part of the tool's design that is not built: a system set up with a directory per distro (`init --distro-dirs`) gains a distro later with `add-distro`, without moving the first (#495). A system set up without the option holds one distro and cannot gain another;" The line "three things outside the workspace's own code" stays true |
| L165-168, steps 4 and 6 | "`repos-manifest init` sets the directory up with one directory per distro, holding the first distro only." and "Later, another distro is added to the same directory, without moving the first." | "`repos-manifest init --distro-dirs` sets the directory up with one directory per distro, holding the first distro only." and "Later, `repos-manifest add-distro` adds another distro to the same directory, without moving the first." |
| L173-176 | "It holds every distro of the project the machine has, each in its own directory from the first distro on, so that adding a distro later moves nothing:" | "It holds every distro of the project the machine has, each in its own directory from the first distro on. `setup` asks for that layout (`--distro-dirs`) whenever the project has a distro, even for the first one alone, so that adding a distro later moves nothing:" |
| L193, `setup` row | "`repos-manifest init` for a directory that is not set up yet, or for a distro the instance does not have yet (#495)" | "`repos-manifest init --distro-dirs` for a directory that is not set up yet; `repos-manifest add-distro` for a distro the instance does not have yet" |
| L217 and L302 | "the tool's is `<distro>/<layer>/`" and "The tool's layout is `<distro>/<layer>/` in the instance's directory." | unchanged in meaning; "the tool's, with a directory per distro, is `<distro>/<layer>/`" |

`docs/manifest/roadmap.md` L26 ("The tool's design covers starting with one distro in a
directory of its own and adding a distro later (#495)", checked by `gh-issue 495 closed`) stays
true and is not edited. A project with no distro is set up flat by `setup`.

## Approach

1. First commit, `tools/repos-manifest/docs/design.md`: "More than one distro" (layout rule,
   `config.yaml` table and example, `init` row and the layout line, the `add-distro` row and
   section, the distro and manifest rules, `sync` for a changed `distros:`). This is "What
   issue 500 waits for". It stands alone so issue 500 can start from it.
2. Second commit, the rest of the rows in `design.md` (walk-throughs, `resolve`, `build`,
   `freeze`, `status`, "Three machines", "Not covered", "What is built", open questions).
3. Third commit, `README.md` and `docs/roadmap.md`.
4. Fourth commit, the sentences in `docs/manifest/design.md`.
5. Consistency check: grep the tool's documents and `docs/manifest/` for `distro:`, `distros: [`,
   "more than one distro", "no distro directories", "in place of", "source setup.bash"; each
   remaining hit is read and judged by hand. Check each of the three `config.yaml` examples and
   the three trees against the text.
6. Run `pre-commit` on the changed files (the full suite is left to CI).
7. Comment on issue 500 once this lands (host or owner): the layout, `config.yaml` shapes and
   the `init` refusal it should build; paths `tools/ros-manifest` there are now
   `tools/repos-manifest`.

## Files to Change

| File | Change |
|---|---|
| `tools/repos-manifest/docs/design.md` | The rows marked above |
| `tools/repos-manifest/docs/roadmap.md` | One line |
| `tools/repos-manifest/README.md` | One bullet |
| `docs/manifest/design.md` | The sentences above only |

## Prior Art

The tool's own earlier text and the workspace design were read. `west`, `repo` and `kas`
(design.md "Why another tool") have no per-distro layout to take. Colcon's convention of one
workspace per directory is what a distro directory builds on. Git worktrees and Python
virtual environments are the usual shape for "several variants of one thing side by side, added
later with a command that touches only the new one"; `add-distro` follows that.

## Serves

Workspace goals "Flexibility" and "Easy to use" (README);
`tools/repos-manifest/docs/design.md#more-than-one-distro` and `#the-system-directory`;
workspace side `docs/manifest/design.md#a-project-instance-is-a-system-directory`.

## Design Picture

Yes. The tool's design changes (sections above) and is the document that holds the current
picture (ADR-0017, ADR-0022). The root's design does not change. `docs/manifest/design.md`,
which states what the workspace expects of the tool, changes in the five places above.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Every place found by grepping "distro" and `setup.bash` in the four documents is in the tables above; issue 500's text is a follow-up comment |
| Keep one current design | Edited in place; no ADR |
| Only what's needed | One new key per distro (`manifest`), no per-distro role or `local_manifest`, no flag on `add-distro` beyond the location; one `init` line, no new question |
| Ask about what matters, and show how much | The owner's three answers are recorded; the questions below are the ones left |
| Verify before claiming | Present text quoted from the files as read in this revision |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0017 | Yes | Design edited with the change |
| 0022 | Yes | The part's design changes; the root's does not |
| 0001 | No | The owner's decisions are recorded here; no new ADR |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Layout rule | `README.md`, `docs/roadmap.md`, "Three machines", walk-through, sync, build, freeze, status wording | Yes |
| The tool's design | The five sentences of `docs/manifest/design.md` | Yes |
| `init` refuses an existing directory; `add-distro` exists | Issue 500 text; the workspace design's "re-runnable `init`" ask | Follow-up: comment on 500; the six asks are a separate issue |
| Config keys | Resolver and `init` code | No, issue 500 |

## Not in scope

The six things the workspace asks of the tool (`docs/manifest/design.md`, "What the tool has
to give"), except that `init` refuses a directory already set up. Removing a distro.

## Owner's decisions

Recorded 2026-11-18, as chosen:

1. Distro directories: "Only when asked". A one-distro system is flat unless `init` is told
   to use a directory per distro. He accepted the stated cost: a system made flat can never
   gain a second distro in place; it needs a new directory and a fresh clone. This departs
   from the workspace design's earlier sentence ("from the first distro on") and from the
   Plan Review's recommendation; it is the issue's first bullet ("`init` can be told to use one
   directory per distro even when it is given a single distro").
2. Adding a distro: "Its own command", for example `repos-manifest add-distro rolling` (name
   open; `add-distro` proposed above). `init` has one job, setting up a new directory, and
   refuses a directory that is already set up.
3. Where a second distro reads its manifest: "Support both". One manifest that lists every
   distro, and a manifest per distro (the owner's project keeps its manifest on per-distro
   branches).

## Open Questions

New questions this revision raises. Each changes the design; mechanism is decided above and
the owner may veto it.

1. The workspace's `setup` verb always asks for `--distro-dirs` when the project has a distro
   (changes in `docs/manifest/design.md` above). Recommend yes: it is the only way for a
   project to start with one distro and add more, and the cost is one directory level. The
   alternative is that `setup` asks the person, which puts the question to someone who often
   cannot answer it yet.
2. At the top of a per-distro system with exactly one distro, `show`, `resolve`, `build` and
   `freeze` use that distro, and with two or more they refuse and list the distros. Recommend
   this: it saves typing in the common case and fails loudly, not silently, when a distro is
   added. The alternative is to require `--distro` or a distro directory always, which makes
   scripts the same before and after a second distro but costs typing for one.
3. `--distro` wins over the distro directory the person is standing in. Recommend: an explicit
   argument beats the current directory. The alternative is an error when they differ.
4. `init` prints one layout line for every flat system that has a distro, not only when the
   manifest lists several distros. Recommend: the tool cannot know a second distro is planned.
   The alternative is to print it only when the manifest lists more than one.

## Estimated Scope

Single PR, documents only, four commits.
