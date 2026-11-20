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

This is the third version of the plan. The first was reviewed (verdict needs-work, twelve findings) and
the checkpoint after it answered `revise` with four decisions of the host. The second was reviewed (verdict
needs-work, eight findings) and the owner answered the checkpoint after that review: which states of a
required repo make `status` exit 1. His answer, "Only unusable repos (Recommended)", is decision 6 below and
replaces the host's exit rule; it splits the old `unknown` state in two (decision 14). The answers to both
reviews are under "Review findings answered".

Another drive, #499 (`show` prints what a manifest comes to for a machine), edits `cli.py`, the tool's
`docs/design.md`, README and roadmap at the same time. Edits to shared files stay small and inside
`status`'s own places (listed under Files to Change).

## Approach

Parts, in this order, as separate commits.

1. **Design first** — write the `### status` section (text below), the "What is built" paragraph and the
   Commands-table wording into `tools/repos-manifest/docs/design.md`; the owner reads this at the plan
   checkpoint. No code before it is accepted.
2. **Characterisation tests first, then make the sync ladder readable without acting.** Two commits.
   - Commit 2a, tests only, written and passing against today's `update.py` before any code moves
     (`tests/test_update_characterisation.py`, using `helpers.make_remote`, `make_system`, `commit_file`):
     the stopped-move text (`; a sync was stopped while moving this repo from <a> to <b>`) appended to the
     "is in progress" message (a merge, a rebase) and to the "index.lock exists" message, when the record's
     `moving` names `HEAD`; the same fixture with a `moving` line that does not name `HEAD` drops the line
     and gives no suffix (now also for an in-progress operation, not only `index.lock` as `test_update.py:429`
     has); "has no commit checked out" (a remote with no commits), and that this answer comes before the
     `moving` line is touched; the order of the early answers (not a git repo of its own, no commit, then
     in progress, `index.lock`, sparse, no single `origin`). If one of these fails on today's code, the
     test is corrected to what the code does and the difference is named in the commit, since 2b must not
     change `sync`.
   - Commit 2b, the extraction, `sync` unchanged in behaviour:
     - `find_version(git, version, record, ask=None)` and `commit_on_origin(git, commit, ask=None)` gain
       an `ask` parameter whose default is `None`, resolved inside the function to `ask_origin` at call
       time (a default of `ask=ask_origin` binds the function when `find_version` is defined and cannot be
       patched). `sync` passes nothing. `status` passes `ask_local`, a new function with the same return
       shape that lists `refs/remotes/origin/*` and `refs/tags/*` with `git for-each-ref` (peeled tags
       from `%(*objectname)`), filtered by the same patterns. The `heads/` and `tags/` reading, tag clashes,
       the hex commit and the stale remote-tracking ref message are shared.
     - `stopped_move(record, head)` returns the stopped-move text or `None`; `update_repo` keeps using it for
       the `also` suffix on "has uncommitted changes" (`test_update.py:395`) as well as on the in-progress and
       `index.lock` messages, and `status` uses it for its own detail (decision 15).
     - `blocked_early(git, place)` and `blocked_late(git, git_dir, record, head)` for the early "left as it
       is" answers, in the order `update_repo` has them. Early: not a git repo of its own, no commit checked
       out (the type test is not needed in `status`: `manifest.py` refuses any type but `git` when it reads
       the manifest, line 551). Late: the in-progress operation, `index.lock`, sparse checkout, not exactly
       one `origin`. Each returns `None` or `Blocked(kind, text)`, `kind` one of `not-git`, `no-commit`,
       `in-progress`, `index-lock`, `sparse`, `no-origin`, so `status` maps the kind to a state (decision 14)
       without reading the text. The in-progress and `index.lock` texts carry the stopped-move suffix as now.
       The write that drops a `moving` line that no longer describes the repo stays in `update_repo`,
       between the two calls (after the no-commit check, before the in-progress checks). `status` calls them
       in a row, never writes, and ignores a `moving` line that does not name `HEAD` (`sync` would drop it).
     - `standing(git, repo, record, found, head, branch, unpushed)` returning a state and a text, with the
       wording `sync` uses (rules 10 to 12). Because `sync` reaches rules 10 to 12 only after rule 9 (commits
       not on `origin`) returned early and `status` calls it with unpushed commits too, `standing` answers
       these sub-cases itself, and `update_repo` keeps its own order for acting:
       on the manifest's branch: `HEAD` equal to `origin`'s branch, or an ancestor of it: expected (`behind`
       counted); otherwise (`HEAD` is not an ancestor of it) with `unpushed > 0` (a person's own commits,
       rule 9): expected, the commits are the fact; otherwise with `unpushed == 0`: different, in `sync`'s
       words "origin's <branch> no longer contains this commit (rewritten upstream)". That last case includes
       `HEAD` strictly ahead of `origin`'s branch while on another `origin` branch's history: `sync` reaches
       its rewritten-upstream line for it too (review finding 1). The branch held by another work tree
       (rule 10), when `HEAD` is behind: expected, the detail names the work tree, since `sync` leaves it and
       `status` moves nothing. On the recorded version that the manifest changed (rule 11): different; the
       detail says `sync` would try to move it only when the repo has no changes and no commits only here,
       and otherwise says `sync` leaves it while it has them (`sync` checks changes and rule 9 first);
       `_change` can also stop a move (a path in the way), so even then the words are "would try". When the
       manifest's branch is already a local branch with commits not on `origin`, or held by another work
       tree, still different, the detail saying `sync` would leave it. Anything else (rule 12): different.
     - The existing `test_update*.py`, `test_sync*.py` suites and 2a's tests pass unchanged after 2b, and
       `tests/test_update_safety.py`'s `GIT_CALLS` gains `ask` and `ask_local` so a call through the
       parameter is scanned.
3. **`status.py`** (new, about 250 lines) — `run_status(named_distros, as_json) -> int`:
   - find the system directory, `read_config`, `distros_for` (so the top of a system with several distros
     covers each, inside one distro's directory just that one, `--distro` names some), then the manifest
     read and `selection.resolve` per distro as `sync.resolve_all` does, in memory.
   - per distro, `read_state`; per repo in layer order: the place, in `present_repo`'s order (rule 2:
     `place_problem` failing, or not a directory; then rule 1, a repo recorded in another layer whose old
     place is there; then a link at the place, which is `left-alone`; missing). To tell a link on the way
     (`blocked-place`) from a file on the way (`not-a-directory`), `system.py` gains
     `place_problem_kind(system, parts)` returning `(kind, text)`, and `place_problem` becomes a wrapper
     returning the text, so `sync` is unchanged and its tests guard it. Then `blocked_early`, `blocked_late`,
     `tracked_changes` (None: `unusable`, "`git status` fails here"), `find_version` with `ask_local`
     (nothing found: `unusable`, the detail saying a fetch may bring it), `standing`. Commits not on `origin`
     are counted with `count(git, "HEAD", "--not", "--remotes=origin")` only on a branch, as `sync` counts
     (`update.py` line 1018): `unpushed` is null when `HEAD` is detached, and a count that fails makes the
     repo `unusable`. A stopped move (`stopped_move`) adds its text to the detail and sets the fact
     `stopped_move`, for any state; it never changes the state. All git runs through `update.Git`, which
     keeps `--no-optional-locks` from `update.GIT_OPTIONS`.
   - repos recorded in `state.yaml` that the manifest no longer lists and whose directory is there:
     `not-in-manifest` (the same test as `sync.left_the_manifest`, without its deleting of records).
   - output: human text, or one JSON document with `--json`; exit status as the design says.
4. **CLI** — a `status` subcommand with `--distro` (repeatable, like `sync`) and `--json`; exit status from `run_status`; one function
   `cmd_status` and one parser block placed next to `sync`'s.
5. **Tests** (`tests/test_status.py`, `tests/test_status_distros.py`, plus agreement tests) — local git
   repos built with `helpers.make_remote`, `make_system`, `push_commit`, `commit_file`. No `~/project11`.
   - one test per state: expected on a branch, expected pinned to a tag, expected pinned to a commit,
     expected but behind origin (`behind` counted), expected with a branch held by another work tree,
     expected with commits only here (rule 9), different (other branch, detached elsewhere, manifest
     changed version since the record and `sync` would move it, rewritten upstream with zero unpushed,
     a local branch of the new version with commits not on `origin`), local changes, commits not on
     `origin`, both on one repo, missing, skipped (optional), `not-a-directory` (a file at the place),
     `blocked-place` (a link on the way, to a place inside the system directory and to one outside it),
     `not-a-directory` (a file at the place, and a file on the way), `in-other-layer` (the manifest gave
     another layer and the old place is there), `left-alone` for each of: a link at the place, a rebase, a
     merge and a bisect in progress, `index.lock`, a sparse checkout, two `origin` urls; `unusable` for each
     of: a non-git directory, no commit checked out, a version `origin` lacks as last fetched, `git status`
     failing; a stopped move (the state unchanged, `stopped_move` true, the text in the detail; with an
     operation in progress the state is `left-alone`, as `sync`'s message), a repo pinned detached at a tag
     that no `origin` branch holds (`unpushed` null),
     no longer in the manifest, `origin` different from the manifest url (fetched-from shown, credentials
     masked). Each also with the repo optional, for the exit status.
   - the adapter's case: a clone fast-forwarded past the recorded commit by hand (what `merge_pr.sh`
     does) is `expected`.
   - several distros: top of a `--distro-dirs` system covers each in `distros` order; inside one distro's
     directory only that one; `--distro a --distro b`; an unrecorded `--distro` is the existing error; one
     distro whose manifest no longer resolves is reported with `ok: false` and exit 1 while the other is
     still listed.
   - nothing changes: `helpers.snapshot` of the whole system directory and `snapshot_repo` of each clone
     (index bytes included) before and after, on every state above, with a file's mtime touched first so
     that a plain `git status` would refresh and rewrite the index; `--no-optional-locks`, in
     `update.GIT_OPTIONS`, makes it not.
     No `.repos-manifest/*.lock`, no probe refs, no resolved files written.
   - no network: the remote directory is deleted or moved after `sync`, and `status` still answers; a
     test patches `update.Git.run` to refuse `ls-remote` and to refuse `fetch`, and shows `status` still
     answers (so it fails if a call forgot `ask_local`).
   - no write by construction: the scan of `test_update_safety.py` runs over `status.py` too, with an
     allowlist of read-only git subcommands (`rev-parse`, `config --get`, `for-each-ref`, `rev-list`,
     `merge-base`, `status`, `ls-files`, `worktree list`), so adding a writing call fails the scan. The scan
     also reads which `update` functions `status.py` calls and fails on any not in an allowlist
     (`blocked_early`, `blocked_late`, `stopped_move`, `tracked_changes`, `count`, `ancestor`,
     `find_version`, `commit_on_origin`, `ask_local`, `standing`, `worktree_holding`, `recorded_kind`,
     `same_version`, `version_ref`, `same_url`, `mask_url`, `Git`), so a call to `_move`, `_change`,
     `_repoint` or `delete_probe_refs` from `status.py` fails it (review finding 8: the scan reads only the
     git calls written in the file it is given).
   - agreement: a table-driven test that, for each fixture state, runs `status`, then `sync`, and checks
     the pairing: `expected` with an outcome of current or fast-forwarded, and `different` with left or
     moved, `left-alone` with left, `unusable` with left or failed. The pairs that legitimately differ are
     listed in the test, each with its reason: expected with changes or unpushed commits (sync leaves it);
     expected on a branch held by another work tree (sync leaves it); `different` that `sync` leaves because
     the new branch has commits not on `origin`, and rule 11 with unpushed commits and with changes (the
     detail says `sync` leaves it); and
     the three cases of the design text (a stale remote-tracking ref of a deleted branch, a local tag
     `origin` lacks, a manifest url changed with the record matching `origin`). `HEAD` strictly ahead of
     `origin`'s branch with no commits only here is a fixture too: both say rewritten upstream. The deleted-branch case
     has its own fixture: `sync` reports the branch not on `origin`, `status` says expected, and the
     detail says the answer is as of the last fetch.
   - `--json` shape test (keys, `format: 1`, `recorded_distros` inside one distro's directory), human
     output test, exit statuses 0, 1 and argparse's 2, for each state, optional and not.
6. **Consequences (ADR-0017), same change** — see Files to Change.

## Design text for part 1 (`### status` in `tools/repos-manifest/docs/design.md`)

```
### status

repos-manifest status [--distro <name>] [--json]

Shows, for each distro it acts on, what the system directory holds against what the manifest says.
It changes nothing on disk and makes no network call. It takes no lock, writes no resolved files,
no record and no setup file, and it does not fetch: every answer is about the clones as they are, with
what `origin` had when each was last fetched (by `sync`, or by hand). `sync` fetches first, so a repo
can read differently after a fetch. Three cases differ even after one:

- a remote-tracking ref left from a branch `origin` deleted: `sync` never prunes, so `status`, which
  reads the refs, calls the branch expected while `sync`, which asks `origin`, says it is not there;
- a tag here that `origin` lacks: offline it cannot be told from `origin`'s tag, so `status` counts it;
- a url that the manifest changed while the record still matches `origin`: `sync` repoints `origin` and
  fetches from the new url, `status` answers from the refs of the old one.

A `--remote` that asks `origin` itself is not built.

Which distros: as for `sync` (see "Which distro a command uses"): every distro at the top of a system
with a directory per distro, in the order of `distros`; the one whose directory the current directory
is inside; or the ones `--distro` names.

Per distro it prints the manifest in use (as `config.yaml` records it), the role, the groups that are on,
the distro, and the distros the system directory was set up for (`config.yaml`'s `distros`, whichever
are acted on). The manifest is read from where it is now: a manifest in a clone that `sync` has not
updated yet is read as it is.

For each repo of the manifest, in layer order, one state, and facts that go with it:

| State | Meaning |
|---|---|
| expected | on the manifest's version, by the rules `sync` follows: on the branch it names, or detached at its tag or commit. A branch behind `origin`'s is still expected; `behind` says how far (`sync` fast-forwards it). A branch with commits only here (`sync` leaves it as it is) and a branch another work tree holds are expected, with the commits or the work tree named. A clone `merge_pr.sh` fast-forwarded past the recorded commit is expected. |
| different | there, and on another branch, tag or commit; on the manifest's branch but not on `origin`'s (rewritten upstream); on the version it was recorded on while the manifest now names another (`sync` tries to move it when the repo has no changes and no commits only here; with either, or when the new branch is local with commits not on `origin`, or held by another work tree, it leaves it: the text says which); or the manifest's version is a commit no branch or tag of `origin` holds. The text says where it is and what the manifest names. |
| left-alone | there, and `sync` leaves it as it is, so `status` does not compare its version: a link at the place, a rebase, merge, bisect or other operation in progress, `index.lock`, a sparse checkout, or an `origin` that is not exactly one url. The text says which. |
| unusable | there, but `status` cannot use it as a clone of the manifest's version: not a git repo of its own, no commit checked out, the manifest's version is not among the refs `origin` had when last fetched, or `git` cannot read its state (`git status` or the count of commits not on `origin` fails). The text says which. |
| missing | not there. |
| skipped | not there and optional: listed every time, as `sync` lists it. |
| not-a-directory | a file or other non-directory is at the repo's place, or on the way to it (`sync`: "is there and is not a directory"). |
| blocked-place | the check on the real destination fails: a link on the way leads outside the system directory (`sync`'s rule 2). |
| in-other-layer | the manifest gives the repo another layer than the record and the old place is there; the text gives the old place and the commands that move it (`sync`'s rule 1). |
| not-in-manifest | recorded by `sync`, still on disk, and no longer in the manifest. Only repos in `state.yaml` can be found; a directory `sync` never recorded is not looked for. |

`missing`, `not-a-directory`, `blocked-place` and `in-other-layer` mean the repo is not at its place:
`sync` reports each as an error for a repo that is not optional, and `build` refuses the layer. A repo that
is optional is listed in any state and does not fail the exit status.

The two states for a repo that is there differ in what a script does: `unusable` exits 1, `left-alone`
exits 0. A `sync` stopped while moving a repo is not a state: when the record's `moving` line names the
commit the repo is on, the text and the `stopped_move` fact say so beside whichever state the repo has,
as `sync` adds it to another message and goes on.

Facts, for a repo that is there: `changes` (tracked files changed, counted as `sync` counts them),
`unpushed` (commits reachable from `HEAD` and from no remote-tracking ref of `origin`, counted as `sync`
counts them: on a branch only, null when `HEAD` is detached), `behind` (commits of `origin`'s branch the clone lacks, on the manifest's branch), and
`fetched_from`, the url of `origin`, with any user name and password masked. When it is not the manifest's
url the line says which: the record says `sync` would repoint it, or it was set by hand and is left. A
repo can be expected and have changes and unpushed commits at once, as `sync` leaves such a repo as it
is; the state is the version, the facts are separate.

A human line is `<path>  <state>` followed by the text and facts. With `--json` the one document on
standard output is the same information:

{ "format": 1, "ok": true, "system": "<absolute path>", "manifest": "...", "role": "...",
  "groups": [...], "layout": "flat|distro-dirs", "recorded_distros": ["jazzy", "rolling"] | null,
  "distros": [ {
    "distro": "jazzy" | null, "ok": true, "problem": null,
    "repos": [ { "key": "...", "path": "jazzy/core/src/a", "layer": "core", "optional": false,
                 "state": "expected", "detail": "...", "version": "...", "head": "<commit>",
                 "changes": 0, "unpushed": 0, "behind": 0, "stopped_move": false,
                 "url": "...", "fetched_from": "..." } ],
    "not_in_manifest": [ { "key": "...", "path": "..." } ] } ] }

`version` is what the manifest names; `path` is relative to the system directory; `changes`, `unpushed`
and `behind` are null where the repo is not there, `status` cannot count, or (`unpushed`) `HEAD` is
detached; `changes` and `behind` are also null for `left-alone` and `unusable`, which `status` does not
compare; `stopped_move` is false where it does not apply. `recorded_distros` is every
distro the system was set up for, null when the manifest has none. A distro that cannot be resolved has
`ok: false`, its `problem`, and no `repos`. The top `ok` is true exactly when the exit status is 0.
Nothing else is printed on standard output with `--json`; warnings go to standard error.

Exit status: 1 when a repo of a distro asked for that is not optional is missing or not at its place
(`missing`, `not-a-directory`, `blocked-place`, `in-other-layer`) or is `unusable`, when a distro's manifest
cannot be read or resolved, or when the system directory cannot be found or read; 0 otherwise. States
`expected`, `different`, `left-alone` and `not-in-manifest`, local changes and unpushed commits do not
change the exit status: `status` reports them, and a script reads `state`. (2 is the argument parser's,
for a bad option.) This is the rule the workspace's `validate` follows: it fails when a repo the manifest
calls for is missing, not at its place or unusable.

A repo that fails the exit status is one that is not there, or is there but is not a git clone with a
commit, or whose version `status` cannot find among the refs of its last fetch; a rebase, merge or bisect in
progress, an `index.lock`, a sparse checkout, a link at the place, a repo on another branch, local changes
and unpushed commits are reported and do not fail it.
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
   (the `merge_pr.sh` case, which `docs/manifest/design.md` asks for). A branch with commits only here, and a
   branch held by another work tree, are expected too, with the fact named; a branch rewritten upstream
   is `different`.
5. Default across several distros: every distro at the top, as the design's "Which distro a command uses"
   table already says for `status`; this plan adds nothing, it reuses `distros_for`.
6. Exit rule, the owner's answer at the checkpoint after the second plan review (replaces the host's rule
   of the second plan): "Only unusable repos (Recommended)". As the dialog worded it: exit 1 when the repo
   is missing, not at its place, not a git repo of its own, has no commit checked out, or its version cannot
   be found. A repo that is there with work in progress (a rebase, merge or bisect in progress, an
   `index.lock`) or a lasting setup `sync` leaves alone (a sparse checkout, a link at its place) is reported
   with its own state and exits 0. Also exit 1: a distro that cannot be read or resolved, an unreadable
   system directory. `different`, `not-in-manifest`, changes and unpushed commits exit 0. Optional repos
   never fail the exit status (see decision 16). The `validate` row of `docs/manifest/design.md` is reworded
   to match, in this change. Undo cost: one rule, the state mapping and its tests here, plus the adapter's
   `validate` once #503 (the thin adapter) builds on it, so change it before #503.
7. Three kinds of place get states of their own (host): `not-a-directory`, `blocked-place`,
   `in-other-layer`, all counted as not at its place (exit 1 for a repo that is not optional), because
   `sync` and `build` treat them as errors. Undo cost: names in the table, the JSON and the tests; cheapest
   before part 3.
8. The five-part row of `docs/manifest/roadmap.md` ("a status a script can read with an exit status,
   protection against two runs at once, time limits on fetches, a resolve that changes nothing when it
   fails, and a manifest named by a commit") stays open and is not split (host). This issue delivers the first
   part only. Undo cost: none; a later issue ticks or splits the row.
9. Characterisation tests for today's `update.py` (commit 2a) are written and passing before any refactor
   (host). Undo cost: none; they stay as tests.
10. Script form is JSON with `--json`, `format: 1`; a version number lets #503 notice a change. YAML or
    line-based forms were not chosen: the adapter is shell and Python, and Python and `jq` read JSON.
11. `status` takes no lock, so it can run beside a `sync` or `build` and see a repo mid-move (the
    `stopped_move` fact is then set, decision 15; an `index.lock` makes it `left-alone`). Taking the lock
    would create a lock file, which breaks "changes nothing".
12. Local tags and stale remote-tracking refs count as `origin`'s in `ask_local` (offline they cannot be
    told apart); the design lists the three cases where `status` and `sync` can differ.
13. Extract and share the `sync` ladder (part 2) instead of a second copy in `status.py`. Costs a refactor
    of `update.py`, guarded by decision 9's tests, the existing suites and the agreement test; the copy
    would drift. `ask` defaults to `None` and is resolved inside, so it can be patched.

14. The old `unknown` is split in two, because the exit rule needs a script to tell them apart. Names:
    `unusable` (exit 1; the repo is there but is no clone `status` can use) and `left-alone` (exit 0; the
    repo is there and `sync` leaves it as it is). `left-alone` uses `sync`'s own word "left" for exactly the
    answers `sync` gives as left-as-it-is for a lasting setup or work in progress; `unusable` says what a
    person would say of a directory that is not a git repo or a clone with no commit. Each repo keeps its
    cause in the text. The list stays at two new states (ten in all). Mapping, by the owner's answer and by
    the test of whether the repo is usable: `unusable` is not a git repo of its own, no commit checked out,
    version not found, `git status` failing, the count of commits not on `origin` failing; `left-alone` is a
    link at the place, an operation in progress, `index.lock`, sparse checkout, no single `origin`. Undo
    cost: the mapping is one table in `status.py` and its tests; renaming touches the design, JSON and
    tests, cheapest before part 3.
15. A stopped move (a `moving` line naming `HEAD`) is not a state (review finding 3): in `sync` it is only a
    suffix on another message, and with nothing else in the way `sync` carries on and clears it. `status`
    shows it as the fact `stopped_move` and as text in the detail, whichever state the repo has. A `status`
    run beside a `sync`, or after a crash between its `moving` write and its record, no longer fails
    `validate`. Undo cost: one JSON field and a test; promoting it to a state later is a mapping line.
16. Decisions for the causes the owner's answer does not name, by the same test (is the repo usable, does
    `sync` treat it as an error):
    - no single `origin` is `left-alone`: `sync` leaves it (rule 5) and the clone is a checkout a person set
      up on purpose with a second url; only the version comparison is missing. Undo: one mapping line.
    - `git status` failing, or the count of commits not on `origin` failing, is `unusable`: `sync` leaves
      the repo but `status` cannot read its state at all. Undo: one mapping line.
    - a version `origin` lacks as last fetched is `unusable`, as the owner's answer says ("its version
      cannot be found"); the detail says a fetch may bring it. `sync` fetches first and reports FAILED for
      it. A commit that exists here but no branch or tag of `origin` holds stays `different` (`sync` leaves it).
    - an optional repo never fails the exit status, whatever its state. This is wider than `sync`, which
      excuses optional only for a repo not at its place and fails an optional repo whose version cannot be
      found. Undo: one condition and its tests; say so if `validate` should follow `sync` here.

## Files to Change

| File | Change |
|------|--------|
| `tools/repos-manifest/docs/design.md` | `### status` rewritten (text above); "What is built" paragraph; `status` out of the not-built list |
| `tools/repos-manifest/src/repos_manifest/update.py` | `ask` parameter (default `None`) on `find_version` and `commit_on_origin`; `ask_local`; `standing`; `stopped_move`; `blocked_early`, `blocked_late` (returning `Blocked(kind, text)`); `update_repo` calls them, behaviour unchanged |
| `tools/repos-manifest/src/repos_manifest/system.py` | `place_problem_kind`; `place_problem` wraps it, same text |
| `tools/repos-manifest/src/repos_manifest/status.py` | new: `run_status`, text and JSON output |
| `tools/repos-manifest/src/repos_manifest/cli.py` | `cmd_status` and the `status` parser block next to `sync`'s, one import |
| `tools/repos-manifest/tests/test_update_characterisation.py` | new, first, passing on today's code (Approach 2a) |
| `tools/repos-manifest/tests/test_update_safety.py` | `GIT_CALLS` gains `ask`, `ask_local`; the scan also runs over `status.py` with a read-only allowlist of git subcommands and of `update` functions |
| `tools/repos-manifest/tests/test_status.py`, `test_status_distros.py`, `test_status_agrees_with_sync.py` | new, per Approach 5; helpers added to `tests/helpers.py` only if needed |
| `tools/repos-manifest/docs/roadmap.md` | the row "`status` shows what differs from the manifest" gets a check (`file-exists src/repos_manifest/status.py`, as the `build` row does) |
| `tools/repos-manifest/README.md` | no command list exists; a paragraph on `status` in "What works today" (from line 98), next to what the `sync` and `build` paragraphs say |
| `docs/manifest/design.md` | The `validate` row (line 300) reworded: "Fail when `repos-manifest status` says a repo the manifest calls for is missing, not at its place or unusable (not a git repo of its own, no commit checked out, its version not found); a repo with work in progress or a lasting setup is reported and does not fail it". "What the tool has to give" status bullet (near line 335) says the tool gives it, with an exit status for those states. Line 185 ("there is no `repos-manifest status` yet") says the adapter does not call it yet (#503). Line 211 ("when it is built, should treat") in present tense. `status` out of the not-built list (line 234). Line 313, "Until `status` is built, the test is the folder being there", becomes "Until the adapter calls `status` (#503), the test is the folder being there" (review finding 7); lines 314 to 316 describe the route test and stay. |
| `docs/manifest/roadmap.md` | no edit: the five-part row stays open (decision 8) and the next row waits for `show` (#499) and `add-distro` |

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
| Ask about what matters | Decision 6 is the owner's, in his words; decisions 1, 3, 7, 14 to 16 are the ones left for his veto |
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
| `status` built | tool roadmap row (check), README paragraph, "not built yet" lines in both designs | Yes |
| `status` built | `docs/manifest/roadmap.md` five-part row: one of five parts delivered, the row stays open | Decided, no edit |
| `update.py` extraction | characterisation tests (2a) first; `test_update*.py` and `test_sync*.py` pass unchanged; `test_update_safety.py` scans `ask` | Yes |
| Exit status rules | The `validate` row of `docs/manifest/design.md` is reworded to the owner's rule in this change; the thin adapter's `validate` (#503, the thin adapter issue) reads the contract | Row: Yes. Adapter: follow-up in #503 |
| Parallel drive #499 (`show`) | Both edit the "Not built yet" line of the tool's design, the not-built line of `docs/manifest/design.md`, "What is built" and "What works today"; whichever lands second resolves one-line conflicts | Noted |
| Acceptance "by hand on project11" | Owner runs it on his machine; no agent runs anything in `~/project11` | Left to the owner |

## Review findings answered

Second review (verdict needs-work, eight findings), each checked against the code in the worktree. All eight held.

1. `standing` and `HEAD` ahead of `origin`'s branch: confirmed at `update.py` (the `ancestor(git, head, found.target)` check gives "rewritten upstream" for `HEAD` ahead with nothing only here). `standing` now says different in `sync`'s words when `HEAD` is not an ancestor of `origin`'s branch and `unpushed == 0`; fixture added.
2. Rule 11 detail: confirmed (`sync` checks changes, then rule 9, before it moves a repo; `_change` can stop it). The detail and the table say `sync` "tries" to move only with no changes and no commits only here; agreement cases added for rule 11 with unpushed commits and with changes.
3. Stopped move: confirmed (only a suffix in `sync`). It is no state: the fact `stopped_move` and text beside any state (decision 15); `stopped_move(record, head)` is named in `update.py`.
4. `blocked-place` wording: confirmed at `place_problem` (system.py line 316 fails for any link on the way that does not resolve to the expected place). Now "a link on the way to the place"; the test list matches the table (file on the way is `not-a-directory`); `place_problem_kind` tells the two apart without reading text.
5. A plain sentence on what fails: added after the exit rule, rewritten for the owner's answer (decision 6).
6. `unpushed` only on a branch: confirmed (`update.py` counts inside `if branch is not None`). `status` counts on a branch only; null when detached; the design says so.
7. `docs/manifest/design.md` line 313: confirmed; reworded to "Until the adapter calls `status` (#503)" and listed in Files to Change with the `validate` row.
8. Safety scan reach: confirmed (`GIT_CALLS` scans calls written in the given file only). An allowlist of `update` functions `status.py` may call is added to the scan.

First review (twelve findings, all held; answered in the second plan and kept): the order around the `moving` write with characterisation tests first; `standing` sub-cases; the three listed differences between `status` and `sync`; the three place states; the `validate` row (now reworded, see 7 above and decision 6); `recorded_distros`; the open five-part roadmap row; `ask`/`ask_local` in the scan; `ask=None` resolved inside; `--no-optional-locks` in `GIT_OPTIONS`; the README paragraph; the overlap with #499 (the `show` command drive) under Consequences.

## Open Questions

- Only the owner can answer, if he wants to change them: decisions 1, 3 and 7 (offline-only, facts beside
  state, the three place states), and decisions 14 to 16 (the names `unusable` and `left-alone`, the stopped
  move as a fact, the placement of no single `origin`, `git status` failing and optional repos). Decision 6
  is his own answer. Decisions 8 and 9 were set by the host for his veto.
- The by-hand project11 acceptance is the owner's, on a machine and time he chooses.

## Estimated Scope

Single PR, in the commits above (design, characterisation tests, extraction, command, tests, docs). About
150 changed lines in `update.py`, 300 in `status.py`, 40 in `cli.py`, 700 to 900 in tests, 150 in docs. Medium.
