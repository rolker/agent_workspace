# Plan: repos-manifest: `status` shows what differs from the manifest

## Issue

https://github.com/rolker/agent_workspace/issues/502

## Context

`repos-manifest` has `resolve`, `validate`, `init`, `sync` and `build`; `status` is a three-sentence
section in `tools/repos-manifest/docs/design.md` and no code. The issue text says `tools/ros-manifest/`;
the tool was renamed by #497 (the rename of the tool's directory, command and package), so every path
here is `tools/repos-manifest/`.

At the checkpoint after the issue review the owner chose "Build both here (Recommended)": this issue builds
the script-readable form and the exit status as well, so the issue's "not in scope" lines for them no longer
hold. The plan writes both into the design first (Part 1, text below), then builds.

The workspace's `validate` and the thin adapter (#503, the adapter that calls the tool's commands) need
"a status a script can read with an exit status" (`docs/manifest/design.md`, "What the tool has to give").

Another drive, #499 (`show` prints what a manifest comes to for a machine), edits `cli.py`, the tool's
`docs/design.md`, README and roadmap at the same time. Edits to shared files stay small and inside
`status`'s own places (listed under Files to Change).

## Approach

Parts, in this order, as separate commits.

1. **Design first** — write the `### status` section (text below), the "What is built" paragraph and the
   Commands-table wording into `tools/repos-manifest/docs/design.md`; the owner reads this at the plan
   checkpoint. No code before it is accepted.
2. **Make the sync ladder readable without acting** (`update.py`, `sync.py` untouched in behaviour) — so
   `status` and `sync` cannot disagree on what "expected" is, extract instead of copying:
   - `find_version(git, version, record, ask=ask_origin)` and `commit_on_origin(git, commit, ask=ask_origin)`
     gain an `ask` parameter. `sync` passes nothing and behaves as now (`git ls-remote origin`). `status`
     passes `ask_local`, a new function with the same return shape that lists `refs/remotes/origin/*`
     and `refs/tags/*` with `git for-each-ref` (peeled tags from `%(*objectname)`), filtered by the same
     patterns. The rest of `find_version` (the `heads/` and `tags/` reading, tag clashes, the hex commit,
     the stale remote-tracking ref message) is shared.
   - A pure function `standing(git, repo, record, found, head, branch)` returning expected / different with
     the same wording `sync` uses (rules 10 to 12 of the design: on the branch, pinned, on the recorded
     version that the manifest has moved, moved by a person, the "record does not say whether the branch or
     the tag was followed" case). `update_repo` calls it to choose its action, keeping its actions and every
     message as they are; the existing `test_update*.py`, `test_sync*.py` suites are the guard and must pass
     unchanged before `status` is added.
   - A pure `blocked(git, git_dir, repo)` for the early "left as it is" checks (rules 3 to 5: not git, an
     operation in progress, `index.lock`, sparse checkout, not exactly one `origin`), reused by both. The
     one write in that stretch of `update_repo` (dropping a stale `moving` line) stays in `update_repo`.
3. **`status.py`** (new, about 250 lines) — `run_status(named_distros, as_json) -> int`:
   - find the system directory, `read_config`, `distros_for` (so the top of a system with several distros
     covers each, inside one distro's directory just that one, `--distro` names some), then the manifest
     read and `selection.resolve` per distro as `sync.resolve_all` does, in memory.
   - per distro, `read_state`; per repo in layer order: `place_problem`, a link or non-directory, then
     `blocked`, `tracked_changes`, `count(git, "HEAD", "--not", "--remotes=origin")` for commits not on
     `origin`, `find_version` with `ask_local`, `standing`.
   - repos recorded in `state.yaml` that the manifest no longer lists and whose directory is there:
     `not-in-manifest` (the same test as `sync.left_the_manifest`, without its deleting of records).
   - output: human text, or one JSON document with `--json`; exit status as the design says.
4. **CLI** — a `status` subcommand with `--distro` (repeatable, like `sync`) and `--json`; one function
   `cmd_status` and one parser block placed next to `sync`'s.
5. **Tests** (`tests/test_status.py`, `tests/test_status_distros.py`, plus agreement tests) — local git
   repos built with `helpers.make_remote`, `make_system`, `push_commit`, `commit_file`. No `~/project11`.
   - one test per state: expected on a branch, expected pinned to a tag, expected pinned to a commit,
     expected but behind origin (`behind` counted), different (other branch, detached elsewhere, manifest
     changed version since the record and `sync` would move it), local changes, commits not on `origin`,
     both changes and unpushed on one repo, missing, missing optional (skipped), a place that is a file or
     a link, a non-git directory, rebase in progress, `index.lock`, no longer in the manifest, `origin`
     different from the manifest url (fetched-from shown, credentials masked).
   - the adapter's case: a clone fast-forwarded past the recorded commit by hand (what `merge_pr.sh`
     does) is `expected`.
   - several distros: top of a `--distro-dirs` system covers each in `distros` order; inside one distro's
     directory only that one; `--distro a --distro b`; an unrecorded `--distro` is the existing error; one
     distro whose manifest no longer resolves is reported with `ok: false` and exit 1 while the other is
     still listed.
   - nothing changes: `helpers.snapshot` of the whole system directory and `snapshot_repo` of each clone
     (index bytes included) before and after, on every state above, with a file's mtime touched first so
     that a plain `git status` would refresh and rewrite the index; `GIT_OPTIONAL_LOCKS=0` makes it not.
     No `.repos-manifest/*.lock`, no probe refs, no resolved files written.
   - no network: the remote directory is deleted or moved after `sync`, and `status` still answers; a
     test also makes `update.ask_origin` raise and shows `status` never calls it.
   - agreement: a table-driven test that, for each fixture state, runs `status`, then `sync`, and checks
     that `expected` pairs with an outcome of current or fast-forwarded, and `different` with left or
     moved; this is the check that the two use one ladder.
   - `--json` shape test (keys, `format: 1`), human output test, exit statuses 0, 1 and argparse's 2.
6. **Consequences (ADR-0017), same change** — see Files to Change.

## Design text for part 1 (`### status` in `tools/repos-manifest/docs/design.md`)

```
### status

repos-manifest status [--distro <name>] [--json]

Shows, for each distro it acts on, what the system directory holds against what the manifest says.
It changes nothing on disk and makes no network call. It takes no lock, writes no resolved files,
no record and no setup file, and it does not fetch: every answer is about the clones as they are, with
what `origin` had when each was last fetched (by `sync`, or by hand). `sync` fetches first, so after a
fetch a repo can read differently; that is the only way the two can differ, and `status` says so in its
closing line. A `--remote` that asks `origin` itself is not built.

Which distros: as for `sync` (see "Which distro a command uses"): every distro at the top of a system
with a directory per distro, in the order of `distros`; the one whose directory the current directory
is inside; or the ones `--distro` names.

Per distro it prints the manifest in use (as `config.yaml` records it), the role, the groups that are on
and the distro. The manifest is read from where it is now: a manifest in a clone that `sync` has not
updated yet is read as it is.

For each repo of the manifest, in layer order, one state, and facts that go with it:

| State | Meaning |
|---|---|
| expected | on the manifest's version, by the rules `sync` follows: on the branch it names, or detached at its tag or commit. A branch behind `origin`'s is still expected; the facts say how far behind (`sync` fast-forwards it). A clone `merge_pr.sh` fast-forwarded past the recorded commit is expected. |
| different | there, and on another branch, tag or commit; or on the version it was recorded on while the manifest now names another (`sync` moves it); or the manifest's version is a commit no branch or tag of `origin` holds. The text says where it is and what the manifest names. |
| unknown | there, and `status` cannot tell: not a git repo of its own, a link, a rebase or other operation in progress, `index.lock`, a sparse checkout, no single `origin`, a version `origin` does not have as last fetched, a `sync` stopped while moving it, a type other than `git`. The text says why. |
| missing | not there. |
| skipped | not there and optional: listed every time, as `sync` lists it. |
| not-in-manifest | recorded by `sync`, still on disk, and no longer in the manifest. Only repos in `state.yaml` can be found; a directory `sync` never recorded is not looked for. |

Facts, for a repo that is there: `changes` (tracked files changed, counted as `sync` counts them),
`unpushed` (commits reachable from `HEAD` and from no remote-tracking ref of `origin`, counted as `sync`
counts them), `behind` (commits of `origin`'s branch the clone lacks, on the manifest's branch), and
`fetched_from`, the url of `origin`, with any user name and password masked. When it is not the manifest's
url the line says which: the record says `sync` would repoint it, or it was set by hand and is left. A
repo can be expected and have changes and unpushed commits at once, as `sync` leaves such a repo as it
is; the state is the version, the facts are separate.

A human line is `<path>  <state>` followed by the text and facts. With `--json` the one document on
standard output is the same information:

{ "format": 1, "ok": true, "system": "<absolute path>", "manifest": "...", "role": "...",
  "groups": [...], "layout": "flat|distro-dirs", "distros": [ {
    "distro": "jazzy" | null, "ok": true, "problem": null,
    "repos": [ { "key": "...", "path": "jazzy/core/src/a", "layer": "core", "optional": false,
                 "state": "expected", "detail": "...", "version": "...", "head": "<commit>",
                 "changes": 0, "unpushed": 0, "behind": 0, "url": "...", "fetched_from": "..." } ],
    "not_in_manifest": [ { "key": "...", "path": "..." } ] } ] }

`version` is what the manifest names; `path` is relative to the system directory; `changes`, `unpushed`
and `behind` are null where the repo is not there or `status` cannot count. A distro that cannot be
resolved has `ok: false`, its `problem`, and no `repos`. Nothing else is printed on standard output with
`--json`; warnings go to standard error.

Exit status: 0 when every distro asked for was read and every repo of the manifest that is not optional
is there; 1 when a repo that is not optional is missing, a distro's manifest cannot be read or
resolved, or the system directory cannot be found or read. States `different` and `unknown`, local
changes and unpushed commits do not change the exit status: `status` reports them; a script reads
`state`. (2 is the argument parser's, for a bad option.) This is what the workspace's `validate` calls.
```

Also in the same file: the Commands-table row for `status` keeps its words; "What is built" gains a
paragraph for `status` and loses `status` from the "Not built yet" list; the "Work done on a field
machine" bullet ("`status` shows repos with commits that are not on the remote yet") stays and is now true.

## Decisions made here (each can be vetoed; cost of undoing)

1. `status` makes no network call and does not fetch. Answers are as of each clone's last fetch. Costs
   little to undo: a `--remote` flag later passes `ask_origin` instead of `ask_local`, since part 2 makes
   the lookup a parameter. Why: an offline, fast, script-safe check; it satisfies "changes nothing on disk"
   without argument; `validate` should not hang on a network.
2. Where each repo was fetched from is `origin`'s url (masked), shown always in the JSON and in the human
   line only when it differs from the manifest's url. The record's `url` is used to say whether `sync` would
   repoint it. Cheap to change.
3. Commits not on `origin` and local changes are facts beside the version state, not states that hide it.
   Undoing means reshaping the JSON, so it is cheapest to veto before part 3.
4. Behind `origin` counts as expected, and so does a clone ahead of its record that `origin` contains
   (the `merge_pr.sh` case, which `docs/manifest/design.md` asks for).
5. Default across several distros: every distro at the top, as the design's "Which distro a command uses"
   table already says for `status`; this plan adds nothing, it reuses `distros_for`.
6. Exit status: 1 only for a missing repo that is not optional, a distro that cannot be read or resolved,
   or no readable system. `different`, `unknown`, changes and unpushed commits give 0. Alternative: a
   `--check` that gives 1 for any difference; not built (only what is needed). Undoing it (making them 1)
   changes what `validate` fails on, so decide before #503.
7. Script form is JSON with `--json`, `format: 1`; a version number lets #503 notice a change. YAML or
   line-based forms were not chosen: the adapter is shell and Python, and Python and `jq` read JSON.
8. `status` takes no lock, so it can run beside a `sync` or `build` and see a repo mid-move (the `moving`
   record then makes it `unknown`). Taking the lock would create a lock file, which breaks "changes
   nothing".
9. Local tags count as origin's tags in `ask_local` (a tag origin lacks cannot be told apart offline).
   The design states the limit.
10. Extract and share the `sync` ladder (part 2) instead of a second copy in `status.py`. Costs a refactor of
    `update.py`, guarded by the existing suites and the agreement test; the copy would drift.

## Files to Change

| File | Change |
|------|--------|
| `tools/repos-manifest/docs/design.md` | `### status` rewritten (text above); "What is built" paragraph; `status` out of the not-built list |
| `tools/repos-manifest/src/repos_manifest/update.py` | `ask` parameter on `find_version` and `commit_on_origin`; `ask_local`; `standing`; `blocked`; `update_repo` calls them, behaviour unchanged |
| `tools/repos-manifest/src/repos_manifest/status.py` | new: `run_status`, text and JSON output |
| `tools/repos-manifest/src/repos_manifest/cli.py` | `cmd_status` and the `status` parser block next to `sync`'s, one import |
| `tools/repos-manifest/tests/test_status.py`, `test_status_distros.py`, `test_status_agrees_with_sync.py` | new, per Approach 5; helpers added to `tests/helpers.py` only if needed |
| `tools/repos-manifest/docs/roadmap.md` | the row "`status` shows what differs from the manifest" gets a check (`file-exists src/repos_manifest/status.py`, as the `build` row does) |
| `tools/repos-manifest/README.md` | command list gains `status` (grep the file for the `sync` and `build` entries; add alongside) |
| `docs/manifest/design.md` | "What the tool has to give": the status bullet now says the tool gives it and how; line about "there is no `repos-manifest status` yet" reworded to say the adapter does not call it yet (#503); "The tool's `status`, when it is built, should treat..." becomes present tense; `status` removed from the "not built yet" command list (one word, so a merge with #499's edit of the same line is trivial) |
| `docs/manifest/roadmap.md` | the row asking for "a status a script can read with an exit status" gets a check in the file's own vocabulary; the "has the commands the adapter calls" row stays until `show` (#499) and `add-distro` land |

## Prior Art

- `sync`'s own ladder in `update.py` (`find_version`, `same_version`, `commit_on_origin`, `tracked_changes`,
  `ancestor`, `count`) and `state.yaml` records: reused, not copied.
- `git status --porcelain` and `--no-optional-locks`: the model for a read-only report and for the
  index-refresh problem (`GIT_OPTIONAL_LOCKS=0`). `vcs status` (vcstool) reports per repo with git's own
  words and has no manifest comparison: rejected as the engine, since it does not know the manifest's version.
- `sync`'s own result lines (`RepoResult`) for wording.

## Serves

Easy to use, and Trust, control and information (README "Workspace goals"); `tools/repos-manifest/docs/design.md#status`, within `docs/manifest/design.md` ("What the tool has to give").

## Design Picture

Changes `tools/repos-manifest/docs/design.md#status` and its "What is built" section (Part 1), plus the
roadmap row, README and the "not built yet" lines in `docs/manifest/design.md` and `docs/manifest/roadmap.md`
in the same change (ADR-0017). Across the boundary, only what `docs/manifest/design.md` asks of the tool
changes (a script-readable status with an exit status, now given); the root's `docs/design.md` does not.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Design text lands first and in the same PR as the code and the "not built" lines |
| Only what's needed | One ladder shared with `sync`; no `--remote`, no `--check`, no lock |
| Test what breaks / Know whether it works | Test per state, agreement with `sync`, no-change snapshot, no-network |
| Verify before claiming | Wording of rules taken from `update.py` and the design's sync section as read; design bullets checked against tests |
| Put each thing at the level it applies to | Tool design owns the inside; the root files change only where the boundary does |
| Ask about what matters | Decisions 1, 3 and 6 are the ones for the owner to look at |
| Look for prior art | Above |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0017 design is the current picture | Yes | Design, roadmap, README and the not-built lines in the same change |
| ADR-0022 a part owns its inside | Yes | Design change in the tool's `design.md`; the root's files only for the boundary |
| ADR-0013 progress entries | Yes | `## Plan Authored` entry |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `status` built | tool roadmap row, README, "not built yet" lines in both designs, `docs/manifest/roadmap.md` row | Yes |
| `update.py` extraction | `test_update*.py` and `test_sync*.py` must pass unchanged | Yes |
| Exit status rules | The thin adapter's `validate` (#503, the thin adapter issue) reads this contract | No, follow-up in #503 |
| Acceptance "by hand on project11" | Owner runs it on his machine; no agent runs anything in `~/project11` | Left to the owner |

## Open Questions

- Only the owner can answer: veto or accept decisions 1, 3 and 6 above (offline-only, facts beside state,
  exit 1 only for missing/unreadable). The rest follow from the design and principles.
- The by-hand project11 acceptance is the owner's, on a machine and time he chooses.

## Estimated Scope

Single PR, in the commits above. About 150 changed lines in `update.py`, 250 in `status.py`, 40 in
`cli.py`, 500 to 700 in tests, 150 in docs. Medium.
