# Plan: repos-manifest: `show` prints what a manifest comes to for a machine

## Issue

https://github.com/rolker/agent_workspace/issues/499

## Context

`tools/repos-manifest` resolves a manifest (`selection.resolve`) but cannot print what the
result comes to. `init.summary` prints a plain list before its question; `validate` prints a
table of counts. The design's sketch for `show` (`tools/repos-manifest/docs/design.md#show`)
needs two things the resolved data does not carry: the manifest each entry came from, and the
repos left out with the reason. `combine.merge_parts` knows both (`_Given` holds the source of
each key) but `Repo` drops them, and `selection.resolve` skips left-out repos without noting
them. The issue text predates the code (it says `tools/ros-manifest/`, and asks for URL and
git-ref locations); the issue review corrected that and left five decisions to this plan.

## Approach

1. **Resolver carries provenance and left-out reasons, with tests first.**
   `manifest.Repo` gets `source: str` (the manifest where the key first appears, which is the
   one that gave `type` and `url`; `combine._repo` fills it from `first[key]`). `selection.Selected`
   gets the same `source`. Both new `source` fields go last in their dataclasses with a default
   (`""`), because `Repo` and `Selected` are built positionally (`tests/test_update.py:511`
   builds `Selected` with five positional arguments); no existing construction changes. `selection.Resolved` gets `left_out: List[LeftOut]` (key, layer,
   reason) in manifest order, and `chain: List[str]` (the bases then the manifest, reading
   order; `bases` and `source` already exist, so this is a property, not new storage). The
   reason is a small value, not prose: `group_off(groups)` when the repo has groups and none
   is on, and `not_on_distro(distro)` when the distro's own entry removes it, or the repo's `absent: true`
   does and the manifest has distros; and `absent_no_distro` when the repo has `absent: true` and
   the manifest has no `distros:`, so it is always left out and "not on None" would be wrong. When both apply the group reason wins, since a group that is off hides the repo before
   the distro is asked. The printer turns the value into the sketch's words ("group
   simulation is off", "none of its groups (a, b) is on", "not on jazzy", "absent, and no distro adds it"). New tests in
   `tests/test_selection.py` and `tests/test_base_merge.py` (the module that covers `base` chains
   through `base.load_manifest` and `selection.resolve`; `test_extends.py` tests the prototype's
   reader and is not used): source
   of a repo defined in the base, in the leaf, and re-versioned by the leaf (source stays the
   first); left-out by group, by distro entry, by repo-level `absent` with distros, by `absent` with no
   distros (its own words), group and distro at once; a repo
   present is not listed; `emit`/`output` results unchanged (existing `test_output.py` passes
   untouched).
2. **`show.py`: a pure renderer.** Three functions
   following the sketch, with no file or system lookup in them: `render_head(resolved)` (the
   `manifest` line, a `base` line per parent, the `role ... groups on` line),
   `render_body(resolved)` (the layers and `left out`), and `render(resolved)` for `show`, which
   is the head with `distro: X` added to the role line, then the body. `init` calls
   `render_head` once and `render_body` per distro (step 4). The body lists each layer with key, version (`(its default branch)` when none, as `init` prints it),
   masked URL (`masking.mask_url`), `optional` mark, and `from <manifest>` on its own line
   when the entry's source is not the first in the chain (the base-most manifest, as in the
   sketch). Then `left out`. The groups-on line needs the groups on, which `check_role_and_distro`
   computes; `Resolved` gains `groups_on`. Layers are named as the manifest names them; the
   unnamed layer prints under `(unnamed layer)`. Tests in `tests/test_show.py` against a
   built manifest with layers, groups, roles, distros, a base, an optional repo and a repo
   left out for each reason; a URL with a password prints masked; the output of the sketch
   is pinned as a whole-string test; and a manifest with no roles/distros prints `(none)`.
3. **`show` command in `cli.py`.** The system-directory lookup (find the system, read its
   config, pick the one distro) is a function in `cli.py`, not in `show.py`, so `render` stays pure. `show [manifest] [--role R] [--distro D] [--with G]...`:
   the manifest is positional like `init`; it reads with `system.read_manifest` and prints.
   Writes nothing; reads no repo. With no manifest it must be inside a system directory
   (`find_system`, `read_config`): it takes the manifest, role and groups from `config.yaml`
   (a relative manifest path is taken from the system directory, as `sync` does) and the distro from
   `one_distro_for` (so `--distro` names one, the distro directory you are in wins, and several
   distros with none named is the design's error). Given with no manifest, `--role` or `--with`
   is refused: "in a system directory show uses what it records; give the manifest to try
   another role". Outside a system directory with no manifest: a refusal that says so. Tests
   in `tests/test_cli.py` (argument form, exit codes, nothing written) and `tests/test_show.py`
   or `test_show_system.py` for the no-argument form on a system built with the existing
   `tests/helpers.py`/`conftest.py` helpers.
4. **`init` prints `show`'s output, then the directories it will create.** `init.summary` prints
   `render_head` once (the manifest, base and role lines are not repeated per distro), then for
   each planned distro a `distro <name>` line, `render_body`, and a `will create` list with each
   layer's `src/` directory (`layer_src_parts`, which differs flat and with `--distro-dirs`), then
   the `Layout:` line as now. The `src/` paths stay, so nothing a person sees today is lost.
   `tests/test_init.py` lines 183-184 (`"Distro jazzy: 3 repos in 2 layers\n"` and the rolling
   one) and line 327 (`"  maybe  (its default branch)"`, which pins the old indentation) are
   rewritten to the new text; `test_init_refusals.py` pins no summary text (checked: it never
   mentions `summary`) and is not touched. The question and `--yes` are untouched.
5. **Acceptance run** on `tools/repos-manifest/tests/fixtures/project11/project11.manifest.yaml`
   for `robot`, `operator`, `developer` on `jazzy` and `rolling` (six runs through the CLI);
   one run goes in the PR description, with the note that the fixture, not `~/project11`, was
   used, and that the fixture has no `base`, so these runs show neither a `base` line nor `from <manifest>`; the built-manifest whole-string test of step 2 is the only cover for both. A test pins that all six runs succeed and that the three roles differ in what they
   list (`tests/test_project11.py` already iterates the pairs; add `show` there).
6. **Design and docs in the same change (ADR-0017), kept small and inside `show`'s own parts
   because #502 (`status` shows what differs from the manifest) edits the same files.** See the table below. The `show` paragraphs in "What is built" (design) and in the README go next to the `init`/`sync` paragraph, not at the end, where #502's `status` paragraphs will land; the shared list lines (design "Not built yet", `docs/manifest/design.md` line 234) are expected to conflict with #502, trivially, whichever lands second.

## Files to Change

| File | Change |
|---|---|
| `tools/repos-manifest/src/repos_manifest/manifest.py`, `combine.py` | `Repo.source`, filled by `_repo` |
| `tools/repos-manifest/src/repos_manifest/selection.py` | `Selected.source`, `Resolved.left_out`, `groups_on`, `chain` |
| `tools/repos-manifest/src/repos_manifest/show.py` (new) | the pure renderer (`render_head`, `render_body`, `render`) |
| `tools/repos-manifest/src/repos_manifest/cli.py` | `cmd_show`, the system-directory lookup and the `show` subparser only, placed before `init`'s so the diff with #502's `status` parser stays apart |
| `tools/repos-manifest/src/repos_manifest/init.py` | `summary` prints `render_head` once, then per distro `render_body` and the `src/` directories |
| `tools/repos-manifest/tests/test_selection.py`, `test_extends.py`, `test_show.py` (new), `test_cli.py`, `test_base_merge.py`, `test_init.py` (lines 183-184, 327), `test_project11.py` | as in the steps |
| `tools/repos-manifest/docs/design.md` | "show" section: say `init` now prints it and what the left-out words are; the "init" paragraph at lines ~213-216 is rewritten whole (it describes the old summary: "until `show` is built", each layer's `src/` with each repo, the per-distro head), to say `init` prints `show`'s head once, each distro's body, the directories it will create, then the `Layout:` line; "What is built" gains a `show` paragraph next to the `init`/`sync` one and `show` leaves the "Not built yet" list (one line edit in a list #502 also edits for `status`) |
| `tools/repos-manifest/docs/roadmap.md` | fill the check cell of the `show` row (line 33) with `file-exists src/repos_manifest/show.py` |
| `tools/repos-manifest/README.md` | one paragraph under "What works today" for `show`, next to the `init`/`sync` paragraph |
| `docs/manifest/design.md` | line ~234: drop `show` and also `build` from "not built yet" (`build.py` exists and the tool roadmap row is checked; the line was stale) |
| `docs/manifest/roadmap.md` | line 28: the row lists `show`, `init`, `add-distro`, `sync`, `build`, `status` together and stays open until all are built; no tick, and the plan notes it |

## What is not built

The URL and git-ref forms of the manifest's location, and `--manifest-ref` / `--manifest-path`,
are not built: the reader takes a path on the local disk only (`system.read_manifest` refuses
`scheme://`; `base.py` reads local paths). `show` takes a path now and gets the other forms
from whichever issue builds the reader (the roadmap row "`base` and the manifest itself can be
given as a path, a URL, or a file in a git repo"); the PR names it. `fetch_from` (#519, fetching
from another place) and its effect on the URLs shown are also not built; the output shows the
manifest's own URLs. Neither is a script form.

## Decisions for the owner to veto

| Decision | What undoing it costs |
|---|---|
| The manifest is a positional path, as in `init` (not `--manifest` as in `resolve`) | Rename an argument and its tests; small |
| URL and git-ref forms left out, said plainly in the PR and design | None; building them later is the other issue's work |
| The no-argument form is built here, using `find_system`, `read_config`, `one_distro_for` (all merged with `init`) | About a third of the command; removing it means a refusal and a follow-up issue |
| The resolver carries `source`, `left_out` (with a value for the reason) and `groups_on`, with its own tests, before the printer | Printer would have to recompute these; keeping them in the resolver lets `status` (#502) reuse them |
| Source is the manifest where the key first appears, shown only when it is not the chain's first (base-most) manifest, as in the sketch; a later re-versioning is not shown | Showing every override would be a second field on each repo; cheap to add later |
| When a repo is left out for both reasons, the group reason is the one shown | One line in `selection.resolve` and its test |
| `init` prints `show`'s output in this PR, as the design says | Revert step 4 and the test text; `show` stands alone |
| `init` keeps printing each layer's `src/` directory: `show`'s output first, then the directories it will create; the manifest, base and role lines print once, not once per distro; the design paragraph on `init`'s summary is rewritten whole (host decision at the checkpoint) | A change to `init`'s printed text, its tests and that paragraph |
| Repo-level `absent` with no `distros:` gets its own words, "absent, and no distro adds it" | One reason value, one line in the printer and its test |
| Acceptance on the in-repo fixture, not `~/project11` (the owner has asked that it not be touched; nothing in this plan reads, writes or runs there) | None |

## Prior Art

`init.summary` (a plain list) is replaced, not copied; `validate`'s counts table is left
alone. `merge.py` (the earlier format's reader) has per-entry `source`, the same idea as
`Repo.source`. `masking.mask_url` is reused for every URL. `vcs`/`git remote -v`-style output
was not taken: the sketch in the design is the form.

## Serves

Goal: "Trust, control and information" (`README.md#workspace-goals`): the person sees what a manifest comes to before anything is fetched (step 3 of the manifest design, `docs/manifest/design.md`); design section `tools/repos-manifest/docs/design.md#show`, roadmap row "`show` prints what a manifest comes to for a machine".

## Design Picture

The tool's own design changes in "show" (init now prints it), "init" (the "until `show` is built" clause), "What is built" and the not-built list, all inside the part (ADR-0022). The root's design changes only at `docs/manifest/design.md` line ~234 (the not-built list).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | design, roadmap, README and the root's list updated in the same change |
| A change includes its consequences | `init` and its pinned tests move with `show`; CLI help gets the `show` line |
| Only what's needed | no script form, no URL forms, no `fetch_from` |
| Test what breaks | resolver provenance and reasons tested before the printer; masking tested; the sketch pinned whole |
| Verify before claiming | acceptance run actually executed on the fixture, six pairs; the PR says which tests ran |
| Look for prior art | see above |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0022 (part owns its inside) | Yes | all code and design edits inside `tools/repos-manifest`, plus one list line at the root |
| ADR-0017 (design is the current picture) | Yes | step 6 |
| ADR-0013 (timeline) | Yes | this entry |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `init.summary` text | `tests/test_init.py` (lines 183-184, 327), design "init" (rewritten whole) | Yes |
| `Repo`/`Selected`/`Resolved` fields | `emit`, `output`, `validate`, `build` construct or read these; defaults keep them working; run the whole suite | Yes |
| CLI subcommands | help text, README, `test_cli.py` | Yes |
| shared files with #502 | `cli.py`, `docs/design.md`, README, roadmap: edits are local to `show`'s sections; whichever lands second rebases | Yes |

## Open Questions

None that only the owner can answer; the decisions above are open to his veto. One point to watch: the sketch's "first in the chain" is read here as the base-most manifest, since the sketch marks the leaf's entry and leaves the base's unmarked.

## Estimated Scope

Single pull request, about 400 lines of code and tests and 60 of documentation: step 1 about a quarter, steps 2 to 3 half, step 4 and the docs the rest. Four to five commits, one per step.
