---
issue: 502
---

# Issue #502 — repos-manifest: status shows what differs from the manifest

## Issue Review
**Status**: complete
**When**: 2026-11-20 11:25 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #502

### Scope Assessment

**Well-scoped?** Yes, with one gap — one PR can hold it, and it should: `status` reads what `sync` already knows (per-repo `HEAD`, `state.yaml` records, the rule ladder in `update.py`: `find_version`, `same_version`, `commit_on_origin`, `tracked_changes`, `ancestor`, `count`) and changes nothing on disk. The gap is that the issue's "What to build" lists states and facts (commits not on `origin`, where it was fetched from, the several-distro default) that `tools/repos-manifest/docs/design.md#status` (three sentences) does not yet describe, and the script-readable form is unsettled (below).
**Right repo?** Yes — the code and design are under `tools/repos-manifest/` in the workspace repo. The issue still says `tools/ros-manifest/`; the tool is now `tools/repos-manifest/` and `cli.py` has `resolve`, `validate`, `init`, `sync`, `build` but no `status`.
**Serves**: Easy to use (and Trust, control and information) — `tools/repos-manifest/docs/design.md#status`, within `docs/manifest/design.md` ("What the tool has to give")
**Design picture?** Changes `tools/repos-manifest/docs/design.md#status`. The section is too thin to build from: it lacks the extra states, where each repo was fetched from, the several-distro default, and a script-readable form with an exit status. #495 (closed) settled the distro layout, not these, so the issue's own condition for building the script form here is not met. The same change must update that section (ADR-0017) and tick the roadmap row.
**Dependencies**: none open. Builds on #500 / PR #535 (`sync` over existing clones). `docs/manifest/design.md` and the workspace `validate` row depend on this: the adapter cannot become thin until a script-readable status exists.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | `tools/repos-manifest/docs/design.md#status` does not cover what the issue asks (states, origin-fetched-from, script form, exit status). Owner decision needed: build the script-readable form and exit status in this issue, or only the human form now and a follow-up for the script form. The plan should state the answer and the design update lands in the same change. |
| Verify before claiming / tests | OK | Acceptance asks for tests with local git repos per state; the existing `sync` tests show how to build them. |
| Only what's needed | Watch | `status` should reuse the `update.py` rule ladder read-only rather than a second classifier, so `status` and `sync` cannot disagree on what "expected version" means. Do not copy the rules. |
| Put each thing at the level it applies to | OK | Tool-level work; the workspace `validate` change stays with the thin-adapter step. |
| Ask about what matters | Watch | Accepted by hand on project11 is on the owner's machine; the owner has an agent working in ~/project11, so that check is not run by agents. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0017 design is the current picture | Yes | Update `tools/repos-manifest/docs/design.md#status` in the same change. |
| ADR-0022 a part owns its inside | Yes | The design change stays in the part's design; the root's `docs/manifest/design.md` changes only where what crosses the boundary changes (the script form it asks for). |
| ADR-0013 progress entries | Yes | This entry. |

### Consequences

- Tool design `#status` section, `tools/repos-manifest/docs/roadmap.md` row "`status` shows what differs from the manifest", `tools/repos-manifest/README.md` command list, and `docs/manifest/roadmap.md` / `docs/manifest/design.md` lines that say "there is no `repos-manifest status` yet" or "not built yet" once it lands.
- The issue text's `ros-manifest` paths are stale; the plan uses `repos-manifest`.

### Recommendations

- Settle with the owner whether the script-readable form (including role and distros the directory was set up for) and the exit status for a missing repo are built here; if yes, the plan writes them into the design first.
- Build `status` read-only on the `update.py` helpers and `state.yaml`, adding no write path; test that nothing on disk changes.
- Cover each state with local git repos: expected, different version, local changes, commits not on `origin`, missing, skipped optional, no longer in manifest, and fetched-from; plus a several-distro system directory and `--distro`.
- Leave the by-hand project11 check to the owner; do not run anything in ~/project11.

### Actions
- [ ] `tools/repos-manifest/docs/design.md#status` does not cover what the issue asks (states, origin-fetched-from, script form, exit status). Owner decision needed: build the script-readable form and exit status in this issue, or only the human form now and a follow-up for the script form. The plan should state the answer and the design update lands in the same change.
- [ ] Settle with the owner whether the script-readable form (including role and distros the directory was set up for) and the exit status for a missing repo are built here; if yes, the plan writes them into the design first.
- [ ] Build `status` read-only on the `update.py` helpers and `state.yaml`, adding no write path; test that nothing on disk changes.
- [ ] Cover each state with local git repos: expected, different version, local changes, commits not on `origin`, missing, skipped optional, no longer in manifest, and fetched-from; plus a several-distro system directory and `--distro`.
- [ ] Leave the by-hand project11 check to the owner; do not run anything in ~/project11.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 11:27 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

"Build both here (Recommended)"

Asked with the issue review's scope finding in the dialog: the issue lists "a form a script can read, and an exit status for a missing repo" as not in scope unless issue 495 had settled them, and issue 495 did not. The question was whether issue 502 builds the script-readable form and the exit status too, with the plan writing them into the tool's design first. His answer puts both in scope. The other choices offered were the human-readable form only with a follow-up issue, or holding the drive.

## Plan Authored
**Status**: complete
**When**: 2026-11-20 11:31 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-502/plan.md` at `768ed207`

Design text for `status` (states, facts, `--json` form, exit status) is written into the plan to land first in the tool's design; then `update.py` gets an `ask` parameter and shared `standing` and `blocked` helpers so `status` reads the sync ladder offline, then `status.py`, the CLI block, tests and the ADR-0017 doc updates. Ten decisions are listed for veto.

## Plan Review
**Status**: complete
**When**: 2026-11-20 11:33 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #502 — repos-manifest: `status` shows what differs from the manifest
**Plan**: `.agent/work-plans/issue-502/plan.md` at `768ed207`
**Branch**: `feature/issue-502`

Checked against `tools/repos-manifest/src/repos_manifest/update.py`, `sync.py`, `system.py`, `tests/test_update.py`, `tests/test_update_safety.py`, the tool's `docs/design.md` (sync rules 1 to 12, "What is built"), `docs/manifest/design.md` and `docs/manifest/roadmap.md`, the adapter's `validate`, and #499's plan. The script form and exit status are in scope by the owner's checkpoint answer and are not flagged. Nothing in `~/project11` was read or run.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR; design first, then a refactor guarded by tests, then the command. |
| Issue alignment | Good | Every state, fact and the several-distro default of the issue is covered; the issue review's actions (design first, reuse the ladder read-only, test each state, no project11) are taken up. Serves: "Easy to use, and Trust, control and information (README "Workspace goals"); `tools/repos-manifest/docs/design.md#status`, within `docs/manifest/design.md` ("What the tool has to give")." Goals and anchor exist. |
| File targeting | Needs work | `docs/manifest/design.md`'s command table row for `validate` ("or cannot say") is not in the edits; `docs/manifest/roadmap.md` row 27 is a compound row this issue cannot tick; `tests/test_update_safety.py` needs `ask` in its scan. |
| Consequences | Needs work | The refactor's guard has gaps the plan treats as covered (finding 1). |
| Principle alignment | Needs work | "Verify before claiming": the design text says the fetch is the only way `status` and `sync` can differ, which the code contradicts (finding 3). Otherwise good: extract rather than copy, decisions listed with costs, prior art named. |
| ADR compliance | Good | ADR-0017 (design in the same change), ADR-0022 (tool's design owns the inside, root files only at the boundary), ADR-0013. |
| ROS conventions | N/A | Workspace tool. |

### Findings

1. **[Consequences] high** — Extracting `blocked()` can change `sync` without a failing test. In `update_repo` (lines 886-920) the order is: not its own repo, no commit checked out (`head is None`, missing from the plan's list), then the write that drops a stale `moving` line, then in-progress / `index.lock` / sparse / origin, with the stopped-move text (`also`) appended to the in-progress and `index.lock` messages. A `blocked()` run before the moving-line write would stop dropping it; one that does not take the stopped-move text would lose the suffix. Today `test_update.py:429` guards the dropping for `index.lock` and a merge, but nothing tests the suffix on an in-progress or `index.lock` message (only on uncommitted changes, line 395), nor "has no commit checked out". Resolution: add those characterization tests to the existing suites as the first commit of Part 2, before moving code, and say in the plan that `blocked()` takes `stopped` and runs after the moving-line write.
2. **[Approach] medium** — `standing()` is not specified for the sub-cases inside rules 10 and 11, which `sync` reaches only after rule 9 (commits not on `origin`) returns early. `status` calls it with unpushed commits too, so it must answer for: on the manifest's branch but not an ancestor of `origin`'s (rewritten upstream, reachable with zero unpushed when `HEAD` is on another `origin` branch's history), a branch held by another work tree, and in rule 11 a local branch of the new version with commits not on `origin`. The plan should say which state each gets, and the agreement test should list the pairs that legitimately differ (an expected repo with changes or unpushed commits that `sync` leaves; an expected branch held by another work tree that `sync` leaves).
3. **[Design text] medium** — The proposed `### status` says the fetch "is the only way the two can differ". It is not: `sync` prunes nothing, so a remote-tracking ref left from a branch `origin` deleted stays after every `sync`, and `status` reading `refs/remotes/origin/*` calls that branch expected while `sync` reports "not on origin" forever; a local tag `origin` lacks counts as `origin`'s in both `find_version` and `commit_on_origin` with `ask_local` (decision 9 covers tags, not stale branches); and when the manifest's url changed and the record matches `origin`, `sync` repoints and fetches from the new url while `status` answers from the old one's refs. Resolution: replace the sentence with the real list of differences, and add a fixture for the deleted-branch case.
4. **[Design text / exit status] medium** — Places under sync's rule 2 (the destination check fails, or the place is not a directory) are an error with exit 1 in `sync` ("as for a missing repo"), and rule 1 (the manifest moved the repo to another layer, the old place is there) is exit 1 too. The design table puts a link under `unknown` but says nothing of a file at the place or a failed destination check, and has no word for rule 1; with `unknown` giving exit 0, `status` would pass `validate` on a repo `sync` and `build` treat as missing. Resolution: state these as `missing` (with the text saying what is there, and for rule 1 where the repo is), or give them exit 1 explicitly.
5. **[Exit status vs root design] medium** — `docs/manifest/design.md`'s command table says `validate` should "fail when `repos-manifest status` says a repo the manifest calls for is missing, or cannot say". The plan gives `unknown` (status cannot tell) exit 0. That is defensible (a rebase in progress is a person's state, not a broken instance), but the plan does not edit that row, so the two designs would disagree. Resolution: either reword the row in this change (validate fails on exit 1; `unknown` is reported and read from `state`) or make `unknown` exit 1. Owner question below.
6. **[Root design] low** — "What the tool has to give" asks for "the role and the distros the system directory was set up for". The JSON's `distros` lists only the distros acted on, so inside one distro's directory or with `--distro` a script cannot read the full set. Add the recorded list (from `config.yaml`'s `distros`) as its own key.
7. **[File targeting] medium** — `docs/manifest/roadmap.md` row 27 covers five things (status, a lock, fetch time limits, a resolve that changes nothing on failure, a manifest named by a commit); this issue cannot give it a check. Leave it open, or split the row (a roadmap change worth naming in the PR); #499's plan reads row 28 the same way.
8. **[Tests] low** — `tests/test_update_safety.py` scans calls named `run`, `out`, `ok`, `count`, `ask_origin`; a call through a parameter named `ask` escapes it. Add `ask` (and `ask_local`) to `GIT_CALLS`. Consider the same scan, with a read-only allowlist of git subcommands, over `status.py`: it is the simplest check that fails when the "changes nothing" promise is broken.
9. **[Tests] low** — A default argument `ask=ask_origin` binds the function when `find_version` is defined, so `monkeypatch.setattr(update, "ask_origin", ...)` does not reach a call that forgot to pass `ask_local`. Use `ask=None` resolved inside the function to `ask_origin`, or patch `Git.run` to refuse `ls-remote`, so the no-network test can fail.
10. **[Precision] low** — `--no-optional-locks` is already in `update.GIT_OPTIONS`; the plan presents `GIT_OPTIONAL_LOCKS=0` as what makes the index stay unwritten. Say `status` runs git through `update.Git` and keeps that option, and keep the mtime-touched snapshot test.
11. **[File targeting] low** — `tools/repos-manifest/README.md` has no command list; "What works today" is prose (line 98 on). The edit is a paragraph there, as #499 plans.
12. **[Parallel drive #499] low** — `cli.py` is apart (`show` before `init`, `status` beside `sync`). Both plans edit the same "Not built yet" line in the tool's `design.md`, the same not-built line (~234) in `docs/manifest/design.md`, and both append a paragraph to "What is built" and "What works today"; those are one-line or adjacent-block conflicts, resolved by the second to land. Not a blocker.

### Summary

The approach is sound: one ladder shared with `sync`, offline, facts beside the state, and the design written first. Before implementation the plan needs characterization tests in front of the `update.py` extraction (the existing suites do not cover the moving-line suffix or "no commit checked out"), states for the rule 10/11 sub-cases and rule 1/2 places, and a design text that names the real ways `status` and `sync` can disagree.

### Recommended Actions

- [ ] Add characterization tests for in-progress and `index.lock` with a matching `moving` line, and for "has no commit checked out", as the first commit of Part 2; specify `blocked()` runs after the moving-line write and takes the stopped-move text.
- [ ] Specify the state `standing()` gives for rewritten upstream, branch held by another work tree, and a local branch with commits not on `origin` in rule 11; list the expected/left pairs in the agreement test.
- [ ] Replace "that is the only way the two can differ" with the stale remote-tracking ref, local-tag and changed-url cases; add a deleted-branch fixture.
- [ ] Give rule 1 and rule 2 places a state and exit status consistent with `sync` (missing, exit 1, or stated otherwise).
- [ ] Reconcile the `validate` row in `docs/manifest/design.md` ("or cannot say") with the exit rule, after the owner's answer.
- [ ] Add the recorded distro list to the JSON.
- [ ] Leave `docs/manifest/roadmap.md` row 27 open (or propose a split).
- [ ] Add `ask`/`ask_local` to the safety scan's `GIT_CALLS`; avoid a bound default for `ask` so the no-network test can fail.
- [ ] Owner: should `unknown` (status cannot tell) fail `validate`?
