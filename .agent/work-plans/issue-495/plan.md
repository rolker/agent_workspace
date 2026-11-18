# Plan: repos-manifest design: start with one distro and add more later, without moving the first

## Issue

https://github.com/rolker/agent_workspace/issues/495

## Context

The tool's design (`tools/repos-manifest/docs/design.md`) says "The layout is chosen at `init`.
A system directory set up for one distro has no distro directories." A system that starts with
one distro therefore has to be moved when a second one is added. The workspace's design
(`docs/manifest/design.md#a-project-instance-is-a-system-directory`) already states the target:
each distro in its own directory "from the first distro on, so that adding a distro later moves
nothing". This issue changes the tool's documents to match. It is documents only, no code.

The owner's requirements, checked at the end of this plan: several distros in one project root,
"starting with one, adding more"; the first distro's directories never move; layers optional so
a small project is "little more than vcs and colcon" and can grow; one distro is built at a
time, with that distro's environment sourced.

## What issue 500 waits for

Issue 500 (`init` and `sync`) can start once these four things are written in
`tools/repos-manifest/docs/design.md`. They are drafted here as the plan's recommendations for
the open questions below, and will be written in the first commit of the implementation.

1. **Layout rule.** When a system has a distro, each distro has its own directory directly in
   the system directory, from the first distro on. That directory is an ordinary colcon
   workspace (`src/`, `build/`, `install/`, `log/`, `setup.bash`), or holds one directory per
   layer when the manifest has layers. A manifest with no `distros:` has no distro to name and
   gets the flat layout (`src/` and the rest directly in the system directory); such a system
   has nothing to add.
2. **`config.yaml`.**
   - `manifest`: as today (a path, a URL, or the mapping `url`, `version`, `path`).
   - `local_manifest`: optional, one string, a path relative to the distro's directory. The
     same path is used inside each distro's directory. It is not a per-distro map.
   - `role`, `groups`, `fetch_from`, `remotes`: as today, shared by every distro.
   - `distros`: a list of names, always a list, even for one distro. The key `distro` is
     removed. A flat system has no `distros` key.
   - `per_distro`: optional mapping from a distro name to settings that differ for that
     distro. The only key for now is `manifest`, which replaces the top-level `manifest` for
     that distro's reads before its first sync (same shapes as `manifest`). Anything else a
     distro might need (a role, say) is not defined and stays an open question.
3. **`init`.**
   - `init <manifest> --distro <d> [--distro <d2> ...]` in a directory with no
     `.repos-manifest/` sets up a new system with those distros.
   - `init --distro <d>` in a directory that has a complete `.repos-manifest/` adds `<d>`:
     shows what `show` shows for that distro, asks (`--yes` skips), appends `<d>` to
     `distros`, then syncs that distro only. It moves nothing of the distros already there. It
     takes no `<manifest>` argument, and takes `--manifest-ref` and `--manifest-path` to say
     where this distro's manifest is read from when that differs (recorded under
     `per_distro`). It refuses `--role`, `--with`, `--fetch-from` and `--remote`: those are
     changed by editing `config.yaml`.
   - It refuses, changing nothing, when a named distro is already in `distros`, when the
     directory is flat (message: nothing is moved; set up a new directory), when the
     manifest does not list the distro, and when no `--distro` is given for a directory that
     already exists (message: use `sync`).
   - What `init` does in a directory whose record is incomplete (a first `init` that failed
     early) is the re-runnable `init` ask. Until that is designed, `init` there refuses and
     points to `sync`.
4. **Where state goes.** `.repos-manifest/state.yaml` stays one file and records the version
   and commit for each repo of each distro. `.repos-manifest/resolved/<distro>/` holds a
   distro's `.repos` files and layer order. A flat system keeps `resolved/` files directly in
   `resolved/`. The exact shape of `state.yaml` is left to issue 500.

Not blocking 500: the text for the commands to add a distro (500 can ship first-distro `init`
and `sync` and add "add a distro" next), `build` and `freeze` wording, the roadmap line, and
the rest of the sections.

## The smallest system, and the same system with a second distro

One repo, one distro, no layers, no roles. The manifest names `distros: [jazzy]`.

```
my_system/
  .repos-manifest/
    config.yaml              manifest: ./system.manifest.yaml, distros: [jazzy]
    state.yaml
    resolved/
      jazzy/
        _unnamed.repos
  jazzy/
    src/
      my_repo/
    build/ install/ log/
    setup.bash
```

After `repos-manifest init --distro rolling` (the manifest already lists rolling):

```
my_system/
  .repos-manifest/
    config.yaml              distros: [jazzy, rolling]
    state.yaml               gains rolling's entries; jazzy's are not touched
    resolved/
      jazzy/                 unchanged
        _unnamed.repos
      rolling/               new
        _unnamed.repos
  jazzy/                     unchanged, not moved or rewritten
    src/  build/  install/  log/  setup.bash
  rolling/                   new
    src/
      my_repo/
    build/  install/  log/  setup.bash
```

What this costs a small project against today's one-distro layout: one directory level
(`jazzy/`) and `resolved/jazzy/`. Nothing else is added: no layers, no `core/` or `underlay/`,
no role. When the project later adds layers, the unnamed layer's `src/` stays where it is and
named layers get directories beside it, as the design already says. A project with no distro
at all stays as light as before: `src/` directly in the system directory.

## Places in the tool's documents that the rule touches

All paths are under `tools/repos-manifest/`. Present text is quoted; the new text follows the
owner's style (plain sentences, no mention of the workspace or its adapter).

| Where | Present text | Will say |
|---|---|---|
| `docs/design.md`, "The system directory", first diagram | `underlay/ src/ ...` and `setup.bash` directly in `my_system/`, with only `.repos-manifest/` beside them | The diagram shows `jazzy/` holding `underlay/`, `core/` and `setup.bash`, and `resolved/jazzy/`. One sentence under it: a system with no distro has no `jazzy/` level and the layers sit directly in the system directory |
| same, paragraph "A manifest without layers gives an ordinary colcon workspace: `src/`, `build/`, `install/` and `log/` directly in the system directory" | as quoted | "A manifest without layers gives each distro directory an ordinary colcon workspace. A manifest without distros gives the system directory itself one." The small-project sentence ("little more than `vcs` and `colcon`") stays |
| same, "That workspace is the unnamed first layer..." | as quoted, "stay where they are" | Unchanged in meaning; says "in the distro's directory" |
| "config.yaml" example | `local_manifest: core/src/unh_marine_autonomy/project11.manifest.yaml` and `distro: jazzy` | `distros: [jazzy]`; `local_manifest` unchanged in value, now read relative to a distro's directory |
| "config.yaml" table, `local_manifest` | "A path inside the system directory that is used instead, once that file exists." | "A path inside a distro's directory..., the same in each distro" |
| table, `distro` and `distros` rows | `distro`: "The distro of this system, if the manifest has distros." `distros`: "In place of `distro`, when the system directory holds more than one." | One row: `distros`: "The distros of this system, as a list, one name or more. Absent when the manifest has no distros." New row: `per_distro` |
| after the table | "`role`, `groups` and `distro` are facts about the machine" | `distros` |
| "More than one distro" (heading kept so links to it hold; the section opens with the layout rule) | "A development machine often carries two distros of the same system at once... The system directory can then have one directory per distro" ... "`config.yaml` lists the distros in place of naming one" ... "The layout is chosen at `init`. A system directory set up for one distro has no distro directories, as in the first diagram." | Opens with "Each distro has its own directory from the first one on, so that a second distro is added without moving the first." Drops "in place of naming one" and the last paragraph's sentence. Adds "Adding a distro" (the `init` rules above) and the flat case. Keeps the `build` one-distro-at-a-time text; adds that with one distro `build` run at the top acts on it |
| "Commands" table, `init` | "Records the manifest, role and distro in a new system directory, then syncs." | Adds: "In a system directory that is already set up, adds a distro." |
| "sync" | "...in `.repos-manifest/state.yaml`, for each distro when there is more than one" | "for each distro" |
| "build" | "in the distro's directory when the system directory holds more than one distro" | "in the distro's directory, or in the system directory when there is no distro" |
| "freeze" | "With more than one distro in the system directory it acts on one at a time, as `build` does." | "It acts on one distro at a time" |
| "Three machines", development machine | "Each distro has its own directory." and `distros: [jazzy, rolling]` | Unchanged apart from naming the directories `jazzy/` and `rolling/` |
| "Three machines", field machine | `distro: jazzy` in `config.yaml` | `distros: [jazzy]`, and a line that its system directory has one `jazzy/` directory |
| "What is built" | "`show`, `init`, `sync`, `build`, `status`, `freeze`, the system directory... are not built." | Read in full: this stays true as written, so no edit. (The issue review listed it; nothing in it mentions the layout.) |
| "Open questions", third bullet | "With more than one distro, whether a distro needs its own settings, such as a different `manifest` URL for its first sync or a different role." | Reworded to what is settled (a per-distro `manifest`) and what is not (a per-distro role) |
| `README.md` | "A development machine can hold more than one distro of the same system side by side." | "A system can start with one distro and gain others later. Each distro has its own directory, so the first is not moved." |
| `docs/roadmap.md` | "A system directory can hold more than one distro, each in its own directory" | "A system starts with one distro in a directory of its own and gains others later without moving the first" |
| `docs/spec.md`, `docs/prototype.md` | Checked by grep: neither says anything about directory layout for distros (`--layout` in the prototype is the output shape of `resolve`) | No change |

One thing outside the tool's documents that becomes false: `docs/manifest/design.md` (the
paragraph after "Nothing in this section is built") says "a change to the tool's design that
is not made yet: a directory per distro from the first distro on... The tool's design today
gives a system set up for one distro no distro directories". It is reworded in the same PR to
say the tool's design now gives that, and what is not built. Its target statements stay.
The roadmap line in `docs/manifest/roadmap.md` (`gh-issue 495 closed`) is satisfied by
closing the issue. Issue 500's bullet "A directory per distro" and the `tools/ros-manifest`
paths in issues 495 and 500 are issue text: the host or the owner edits them (a comment on
500 when this lands).

## Open questions for the owner

Each has options, what each costs, and one recommendation. The plan above follows the
recommendations. If the answer differs, the change is named.

1. **Distro directories always, or only when asked at `init`?**
   - A: always, whenever a distro is named. Costs one directory level for a one-distro
     project. Adding a distro never moves anything. This is the workspace design's rule.
   - B: only with an option at `init` (say `--distro-dirs`). A one-distro system without it
     has `src/` at the top, lighter. Costs: a system made without the option cannot gain a
     distro without moving its `src/`, `build/` and `install/` (so `init --distro` refuses
     there, or a separate move command is needed), and `init` asks the user a question they
     cannot answer yet.
   - Recommend A. If B: "Adding a distro" refuses on a system without distro directories, a
     flag is added to the init flags in the section issue 500 waits for, and the minimal
     tree loses `jazzy/`.
2. **Is `distros` always a list in `config.yaml`?**
   - A: always a list, even for one. No key changes when a second distro is added.
   - B: `distro` for one, `distros` for several (today's rule). Costs: adding a distro
     rewrites the key, and every reader handles two keys.
   - Recommend A. If B: the config.yaml table keeps both rows and `init` rewrites the key
     when it adds.
3. **`local_manifest` per distro?**
   - A: one string, relative to the distro's directory, the same in each distro. Costs: a
     project whose manifest sits at different paths on different distro branches cannot
     express it.
   - B: a map from distro to path. Costs: more to write in `init`; no case needs it yet.
   - Recommend A. If B: the `local_manifest` entry in the section issue 500 waits for
     becomes a map.
4. **A manifest version per distro?** Project11 keeps its manifest on distro branches and
   the copy on `jazzy` may list only `jazzy`, so the first sync of `rolling` has to read
   the `rolling` branch.
   - A: `per_distro.<name>.manifest`, set by `init --distro rolling --manifest-ref rolling`.
     Costs: one more key.
   - B: no per-distro setting; the second distro reads the same manifest. Costs: project11
     must keep one branch that lists every distro, or the second distro cannot be added.
   - C: a `{distro}` placeholder in the manifest's version. Costs: a new rule in the
     format; works only when the branch is named like the distro.
   - Recommend A. If B or C: drop `per_distro` from `config.yaml` and the `init` flags.
5. **A non-ROS project with no distro at all: flat layout?**
   - A: yes. Manifest has no `distros:`, `src/` is directly in the system directory, there
     is nothing to add. Lightest for a small project; if it later adds distros it sets up a
     new directory.
   - B: always make a directory even then (an unnamed one). Costs a level for no reason,
     and invents a name.
   - Recommend A. If B: the flat paragraph goes, and every sentence about a system with no
     distro changes.

## Approach

1. **Write the section issue 500 waits for** into `docs/design.md`: "More than one distro"
   (the layout rule and "Adding a distro"), the `config.yaml` table and example, the
   `init` row. Commit on its own, so issue 500 can start from it.
2. **Update every other place** in the table above, one atomic commit for the rest of
   `design.md`, one for `README.md` and `docs/roadmap.md`.
3. **Fix the one sentence in `docs/manifest/design.md`** that says the tool's design has no
   distro directories for one distro.
4. **Check consistency**: grep the tool's documents for `distro:`, "more than one distro",
   "no distro directories", "in place of"; each remaining hit is checked by hand.
5. **Run `pre-commit`** on the changed files (the full suite is left to CI).

## Files to Change

| File | Change |
|---|---|
| `tools/repos-manifest/docs/design.md` | The rows marked in the table above |
| `tools/repos-manifest/docs/roadmap.md` | One line |
| `tools/repos-manifest/README.md` | One bullet |
| `docs/manifest/design.md` | One sentence in "Nothing in this section is built" |

## Prior Art

The tool's own earlier text and the workspace design were read. `west`, `repo` and `kas`
(design.md "Why another tool") have no per-distro layout to take. Colcon's own convention of
one workspace per directory is what a distro directory builds on.

## Serves

Workspace goals "Flexibility" and "Easy to use" (README); `tools/repos-manifest/docs/design.md#more-than-one-distro`
and `#the-system-directory`; workspace side `docs/manifest/design.md#a-project-instance-is-a-system-directory`.

## Design Picture

Yes. The tool's design changes (sections above); it is the document that holds the current
picture (ADR-0017, ADR-0022). The root design changes in one sentence only, where it describes
the tool's present text.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Every place the rule touches is listed above; issue 500's text is named as a follow-up edit |
| Keep one current design | Edited in place; no ADR |
| Only what's needed | `per_distro` holds one key; no per-distro role, no per-distro `local_manifest` map |
| Ask about what matters, and show how much | The five open questions, each with a cost and a default |
| Verify before claiming | Present text quoted from the files as read; "What is built" found to need no edit |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0017 | Yes | Design edited with the change |
| 0022 | Yes | The part's design changes; the root's changes by one sentence |
| 0001 | No | Owner decision is in the issue; no new ADR |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Layout rule | `README.md`, `docs/roadmap.md`, "Three machines", sync/build/freeze wording | Yes |
| The tool's design | `docs/manifest/design.md` sentence | Yes |
| `init` in an existing directory | Issue 500 text; the six asks (re-runnable `init`) | Follow-up: owner or host edits the issue; the six asks are a separate issue |
| Config keys | Resolver and `init` code | No, issue 500 |

## Not in scope

The six things the workspace asks of the tool (`docs/manifest/design.md`, "What the tool has
to give"), except what `init` does in an existing directory (above).

## Open Questions

The five above, for the owner at the plan checkpoint.

## Estimated Scope

Single PR, documents only.
