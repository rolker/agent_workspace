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

## Checkpoint
**Status**: complete
**When**: 2026-11-20 11:35 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work; its twelve findings are fixes to the plan, and the one question it raised is already answered by the workspace's design)
**After**: plan
**Decision**: revise

Read the Plan Review at b5216657 (verdict needs-work). All twelve findings go back to plan-task. Host decisions, listed for the owner's veto:

1. The review asked whether `unknown` (the state where `status` cannot tell) should fail `validate`. `docs/manifest/design.md`, the `validate` row, already says: "Fail when `repos-manifest status` says a repo the manifest calls for is missing, or cannot say". So the plan follows that row and does not change it: `status` exits 1 when a repo the manifest calls for (not optional) is missing, is not at its place, or is `unknown`; `different`, local changes and unpushed commits exit 0; the JSON says which state each repo is in. This replaces the plan's decision 6. Undoing it is a change to one exit rule and its tests, and to the adapter's `validate` once issue 503 (the adapter calls the tool's commands) builds on it.
2. Finding 4: a file at a repo's place, a place that fails the destination check, and a repo the manifest moved to another layer whose old place is still there each get a state of their own in the design table and count as not at its place (exit 1 for a repo that is not optional), since `sync` and `build` treat them as errors.
3. Finding 6: the row of `docs/manifest/roadmap.md` that covers five things stays open and is not split in this pull request; the plan says which of the five this issue delivers.
4. Finding 1 first: the tests for the stopped-move text on the in-progress and `index.lock` messages and for "has no commit checked out" are written and passing against today's `update.py` before any of it is refactored.

## Plan Authored
**Status**: complete
**When**: 2026-11-20 11:37 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-502/plan.md` at `3dd5164d`

Revision after the plan review (needs-work, twelve findings, all checked against the code and held). Characterisation tests for today's update.py come first, then the extraction; the exit rule follows the validate row (exit 1 for a non-optional repo missing, not at its place or unknown); three place states added; the five-part roadmap row stays open.

## Plan Review
**Status**: complete
**When**: 2026-11-20 11:40 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #502 — repos-manifest: `status` shows what differs from the manifest
**Plan**: `.agent/work-plans/issue-502/plan.md` at `3dd5164d`
**Branch**: `feature/issue-502`

Second review, of the revision after the first review's twelve findings and the host's four checkpoint decisions. Checked against `tools/repos-manifest/src/repos_manifest/update.py` (`update_repo` lines 871-1095, `find_version`, `commit_on_origin`, `_move`, `_change`), `sync.py` (`present_repo`, `layer_moved`, `left_the_manifest`), `system.py` (`place_problem`, `distros_for`, `Config`), `manifest.py` (non-git types are refused at read), `tests/test_update.py` (lines 380-460), `tests/test_update_safety.py`, the tool's design (sync rules 1 to 12, `### status`), `docs/manifest/design.md` (the adapter's `validate`, the `validate` row, "What the tool has to give"), both roadmaps, and where the adapter's `validate` runs (`.agent/scripts/registration_verify.sh:159`, the sitrep roadmap checks). The script form and exit status are in scope (owner); the exit rule, the three place states, the open roadmap row and the characterisation-tests-first order are host decisions and are not re-argued. Nothing in `~/project11` was read or run.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR in six commits: design, characterisation tests, extraction, command, tests, docs. |
| Issue alignment | Good | All states, facts and the several-distro default are covered; all twelve first-review findings are answered in the plan text (checked one by one below). Serves: "Easy to use, and Trust, control and information (README "Workspace goals"); `tools/repos-manifest/docs/design.md#status`, within `docs/manifest/design.md` ("What the tool has to give")." Both goals are sections of `README.md#workspace-goals`; the `#status` anchor exists. |
| File targeting | Good | The files match the work; `docs/manifest/design.md` lines 313-316 keep a condition that becomes false (finding 7). |
| Consequences | Needs work | `standing` gives answers `sync` does not give in two sub-cases the plan does not list (findings 1, 2); a stopped move is `unknown` (exit 1) where `sync` goes on (finding 3). |
| Principle alignment | Needs work | "Verify before claiming": three sentences of the proposed design text are not true of the code (findings 2, 4, 6). "Ask about what matters": the exit rule's everyday effect on the adapter's `validate` is not said plainly (finding 5). |
| ADR compliance | Good | ADR-0017 (design first and in the same change), ADR-0022 (inside in the tool's design, root files only at the boundary), ADR-0013. |
| ROS conventions | N/A | Workspace tool. |

### First review's findings, as the revision answers them

1. Answered. 2a's tests (suffix on in-progress and `index.lock` when `moving` names `HEAD`; no-commit before the `moving` line is touched; the order of early answers) fail if the halves are reordered around the write or a message changes. The existing `test_update.py:395` keeps the suffix on "has uncommitted changes", which `blocked_late` must therefore hand back to `update_repo` (`also` is used again at line 962). The plan's "now also for an in-progress operation, not only `index.lock` as `test_update.py:429` has" is slightly off: line 429 already covers "a merge in progress"; harmless.
2. Partly answered: sub-cases specified and pairs listed, but two sub-cases are answered wrongly (findings 1, 2 below).
3. Answered: the three cases are true of the code (`find_version` lines 603-625, `commit_on_origin`, the url rule at 930-955); deleted-branch fixture added. The list is not the whole list (findings 1-3).
4. Answered (decision 7); one wording point (finding 4).
5. Answered (decision 6); its plain statement is finding 5.
6. Answered: `recorded_distros` in the JSON, from `Config.distros`.
7. Answered: row 27 of `docs/manifest/roadmap.md` stays open, no edit.
8. Answered; the scan's reach is finding 8.
9. Answered: `ask=None` resolved inside, and a `Git.run` patch refusing `ls-remote` and `fetch`.
10. Answered.
11. Answered.
12. Answered (listed under Consequences).

### Findings

1. **[Consequences] medium** — `standing` calls "on the manifest's branch, `origin`'s branch an ancestor of `HEAD`" expected regardless of `unpushed`. With `unpushed == 0` and `HEAD` strictly ahead of `origin/<branch>` (a person fast-forwarded the branch to another `origin` branch's commits), `sync` reaches line 1044, finds `HEAD` not an ancestor of `origin`'s branch, and leaves it as "rewritten upstream". `status` says expected. Either make that sub-case `different` with `sync`'s wording, or keep it expected and add it to the agreement test's listed pairs and to the design text's list of differences.
2. **[Consequences / design text] medium** — Rule 11 in `standing` says `different`, "`sync` would move it", unless the new branch is local with commits not on `origin` or held. `sync` reaches rule 11 only with no tracked changes (line 961) and no commits not on `origin` on the current branch (rule 9, line 1022); with either, it leaves the repo ("has uncommitted changes", "has N commits not on origin; the manifest names X; it is not switched"). `status` calls `standing` with both facts, so the detail and the design table's "(`sync` moves it, or leaves it when ...)" would say "moves" for a repo `sync` leaves. `_change` can also leave it (submodules or paths in the way). The detail should say `sync` moves it only when the repo has no changes and no commits only here, or say "`sync` would try to move it"; the table sentence should list those conditions, and the agreement test should cover rule 11 with unpushed commits and with changes.
3. **[Consequences / exit status] medium** — The state table puts "a `sync` stopped while moving it" under `unknown`, so exit 1 for a repo that is not optional. In `sync` a `moving` line that names `HEAD` is only a suffix: with no operation in progress and no `index.lock`, `sync` goes on, and a clean repo on the version is "up to date" with the line removed (`test_a_moving_line_is_removed_when_the_repo_is_found_on_the_version`). A `sync` killed between its `moving` write and its final record (power loss on a field machine), or a `status` run beside a `sync` (decision 11), then fails `validate` though the next `sync` answers it. Also, the plan's `blocked_late` returns nothing for a stopped move alone in `sync`'s path, so `status` needs a separate rule for it that the plan does not name. Make the stopped move a fact (or a detail) beside the version state, with `unknown` only when an operation or `index.lock` is there too, or keep it `unknown` and list it among the pairs and in the design text.
4. **[Design text] low** — `blocked-place` is described as "a link on the way leads outside the system directory". `place_problem` (system.py:316) fails for any link on the way whose real path is not the expected one, inside the system directory too; its own message is "leads outside its place". Say "a link on the way to the place", as rule 2 does. The test list in Approach 5 puts "a file on the way" under `blocked-place`, while the table puts it under `not-a-directory` (and `place_problem` says "is on the way and is not a directory"); make the test list match the table.
5. **[Design text / exit status] medium** — The exit rule (host decision 6, not re-argued) makes `status` exit 1 for every `unknown` repo that is not optional. The design text says so only by combining the table with "or is `unknown`"; it does not say plainly what a developer will meet. The adapter's `validate` runs at registration (`registration_verify.sh:159`) and in sitrep's roadmap checks, and on #503 it will fail while a rebase, merge or bisect is in progress in any repo, while an editor's or a crashed git's `index.lock` is there, and for as long as a repo is a sparse checkout or a link at its place. The last two are lasting setups that `sync` leaves with exit 0 (`present_repo` returns LEFT for a link, line 439; rule 4 for sparse), so `validate` would fail for as long as a person keeps them. Add one plain sentence to the design text after the exit rule, naming these cases, so the owner can judge the rule with them in view. Owner question below.
6. **[Design text] low** — `unpushed` is "counted as `sync` counts them", but `sync` counts only on a branch (line 1018); the plan's step 3 counts for every repo. A repo pinned detached at a tag whose commit no `origin` branch holds (a release tag on a commit off every branch) would show unpushed commits that are on `origin` as a tag. Count only on a branch (null when detached), or exclude tags `origin` has, and say which in the text.
7. **[File targeting] low** — `docs/manifest/design.md` line 313, "Until `status` is built, the test is the folder being there", becomes false when this lands. Reword it to "Until the adapter calls `status` (#503)" in the same change, as the plan does for line 185.
8. **[Tests] low** — The read-only scan over `status.py` sees only git calls written in `status.py`. Calls it makes into `update.py` helpers are scanned only by `update.py`'s own NEVER list, which allows writing calls (`update-ref -d`, `switch`, `merge`). Add to the scan a list of the `update` functions `status.py` may call (`blocked_early`, `blocked_late`, `tracked_changes`, `count`, `find_version`, `commit_on_origin`, `ask_local`, `standing`, `worktree_holding`, `recorded_kind`, ...) and fail on any other, so a call to `_move`, `_change`, `delete_probe_refs` or `_repoint` from `status.py` fails it.

The proposed `### status` text is otherwise true on the points checked (offline answers and the three listed differences, which distros, the config fields, the place states against `layer_moved`, `present_repo` and `place_problem`, `fetched_from` and the record's url, not-in-manifest against `left_the_manifest`), is written in plain sentences, and has no bold lead-ins.

### Summary

The revision answers all twelve first-review findings, and the characterisation tests in 2a would catch a reorder around the `moving` write or a changed message. Before code, `standing` needs the two sub-cases where it would contradict `sync` fixed or listed. A stopped move needs a rule that matches `sync`. The design text needs three small corrections and one plain sentence on what the exit rule means for `validate` day to day. All of these are edits to the plan's text, small enough to do in one pass.

### Recommended Actions

- [ ] `standing`: on the manifest's branch with `HEAD` ahead of `origin`'s and `unpushed == 0`, answer as `sync` does (rewritten upstream, `different`) or list the pair.
- [ ] Rule 11 detail and design-table sentence: "`sync` moves it" only with no changes and no commits only here; add agreement-test cases for rule 11 with unpushed commits and with changes.
- [ ] A stopped move: a fact beside the version state, `unknown` only with an operation or `index.lock`; or list it as a difference. Name the rule in `status.py`'s steps.
- [ ] Design text: "a link on the way to the place" for `blocked-place`; test list matching the table; `unpushed` counted on a branch only, or tags excluded.
- [ ] Design text: one plain sentence after the exit rule naming a rebase or merge in progress, `index.lock`, a sparse checkout and a link at the place as cases that fail `validate`.
- [ ] `docs/manifest/design.md` line 313 reworded in the same change.
- [ ] Safety scan: allowlist of `update` functions `status.py` may call.
- [ ] Owner: with those cases in view, should a sparse checkout and a link at the place (lasting setups `sync` leaves with exit 0) fail `validate` as `unknown`, or be states that exit 0?

## Checkpoint
**Status**: complete
**When**: 2026-11-20 11:42 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: revise

"Only unusable repos (Recommended)"

Asked after the second Plan Review at 564013ce (verdict needs-work, eight new findings). The dialog quoted the workspace design's `validate` row ("says a repo the manifest calls for is missing, or cannot say"), said the host had the plan follow it, and gave what that means day to day: `validate` failing while a rebase, merge or bisect is in progress or an `index.lock` is there; failing for as long as a required repo is a sparse checkout or a link sits at its place, both of which `sync` leaves alone with exit 0; and `validate` running at registration and in the sit-rep's roadmap checks. The question was which states of a required repo make `status` exit 1.

The option he chose, as worded in the dialog: exit 1 when the repo is missing, not at its place, not a git repo of its own, has no commit checked out, or its version cannot be found. A repo that is there with work in progress (a rebase, merge or bisect in progress, an `index.lock`) or a lasting setup `sync` leaves alone (a sparse checkout, a link at its place) is reported with its own state and exits 0. The design's `validate` row is reworded to match. This replaces the host's exit rule in the previous checkpoint. The other choices offered were to keep everything `status` cannot tell as exit 1, or to fail only a missing or misplaced repo.

The eight findings of the review go back to plan-task with this.

## Plan Authored
**Status**: complete
**When**: 2026-11-20 11:45 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-502/plan.md` at `bed304e4`

Third version, after the second plan review (needs-work, eight findings, all checked against the code and held) and the owner's answer "Only unusable repos (Recommended)". The old unknown state is split into unusable (exit 1) and left-alone (exit 0); a stopped move is a fact beside the state; the validate row and line 313 of docs/manifest/design.md are reworded in the same change.

## Plan Review
**Status**: complete
**When**: 2026-11-20 11:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #502 — repos-manifest: `status` shows what differs from the manifest
**Plan**: `.agent/work-plans/issue-502/plan.md` at `bed304e4`
**Branch**: `feature/issue-502`

Third review, of the revision after the second review's eight findings and the owner's exit rule ("Only unusable repos (Recommended)"). Checked against `tools/repos-manifest/src/repos_manifest/update.py` (`update_repo` 871-1095, `find_version` 539-626, `commit_on_origin`), `sync.py` (`clone_repo` 241-255, `layer_moved` 376-401, `present_repo` 404-461, `closing` 680), `system.py` (`place_problem` 308-324), `tests/test_update_safety.py` (`GIT_CALLS`), the tool's design (sync rules 1 to 8, `### status`), `docs/manifest/design.md` (lines 185, 211, 234, 300, 313-316, 335-338, 381) and `merge_pr.sh`'s fast-forward of the owning checkout (`pull --ff-only origin <base>`, which updates `origin/<base>`, so the adapter's case reads expected). The owner's two answers are not re-argued. Nothing in `~/project11` was read or run.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, six commits: design, characterisation tests, extraction, command, tests, docs. |
| Issue alignment | Good | Serves: "Easy to use, and Trust, control and information (README "Workspace goals"); `tools/repos-manifest/docs/design.md#status`, within `docs/manifest/design.md` ("What the tool has to give")." Unchanged from the second review, goals and anchor exist. The owner's exit rule is decision 6 in his words. |
| File targeting | Good | All root-design lines that become false are listed (185, 211, 234, 300, 313, 335). |
| Consequences | Good | The second review's two `standing` sub-cases and the stopped move now match `sync`; one wrong premise in decision 16 (finding 1) changes no code. |
| Principle alignment | Good | "Verify before claiming": a few sentences of the design text still overstate (findings 2-5), each a wording fix. "Ask about what matters": decision 16 is listed for veto, but on a false comparison with `sync` (finding 1). |
| ADR compliance | Good | ADR-0017, ADR-0022, ADR-0013 as before. |
| ROS conventions | N/A | Workspace tool. |

### Second review's findings, as the revision answers them

1. Answered: not an ancestor of `origin`'s branch with `unpushed == 0` is `different` in `sync`'s words, which matches line 1044 for `HEAD` ahead too; fixture added.
2. Answered in the table and the detail ("tries", with the conditions); agreement cases added. `standing`'s signature has no `changes` argument, which the rule 11 detail needs (finding 6).
3. Answered: decision 15, `stopped_move(record, head)` extracted. See finding 7 for a doubled text.
4. Partly: the test list now matches the table, and `place_problem_kind` is added, but the table row for `blocked-place` still says "a link on the way leads outside the system directory" (finding 2).
5. Answered: the plain closing paragraph, rewritten for the owner's rule; it omits two `unusable` causes (finding 3).
6. Answered: counted on a branch only, null when detached, as line 1018.
7. Answered: line 313 reworded.
8. Answered: allowlist of `update` functions in the scan.

### The `unknown` split

Every cause the owner named is on his side: `unusable` = not a git repo of its own, no commit checked out, version not found; `left-alone` = rebase, merge, bisect (and cherry-pick, revert, per `IN_PROGRESS`), `index.lock`, sparse, link at the place; not at its place (`missing`, `not-a-directory`, `blocked-place`, `in-other-layer`) exits 1. The unnamed causes: `git status` failing and the count failing as `unusable` is defensible (the clone's state cannot be read, the same test as "cannot be found"). "Not exactly one `origin`" as `left-alone` is defensible for two urls (a deliberate setup `sync` leaves); for no `origin` url at all it is closer to the owner's "its version cannot be found", since `ask_local` then has no `refs/remotes/origin/*` to look in (finding 8, owner's veto).

### Optional repos

The plan's premise is wrong, so there is no difference to defend. `sync` never fails the exit status for an optional repo: `present_repo` turns any `FAILED` from `update_repo` into `SKIPPED` for an optional repo (sync.py 459-460), including a version that cannot be found and a failed fetch; `clone_repo` (253) and `layer_moved` (400) and the place checks (417) do the same, and `closing` counts only `FAILED`. So `status`'s "an optional repo never fails the exit status" is the same rule as `sync`'s, and the design sentence "A repo that is optional is listed in any state and does not fail the exit status" is true. Decision 16's last bullet and its open question should be corrected (finding 1).

### Findings

1. **[Decisions] low** — Decision 16's last bullet says `sync` "fails an optional repo whose version cannot be found"; it does not (sync.py 459-460: `FAILED` becomes `SKIPPED` for any optional repo). Reword: `status` follows `sync`, which skips an optional repo whatever stops it; drop it from the owner's veto list as a difference. The agreement test's pairing must accept `skipped` from `sync` for every optional fixture (`unusable`, `not-a-directory`, `blocked-place`, `in-other-layer` with `optional: true`), or it will fail on correct code.
2. **[Design text] low** — The `blocked-place` row still says "a link on the way leads outside the system directory". `place_problem` (system.py 316) fails for any link on the way whose real path is not the expected one, inside the system directory too. Write "a link on the way to the place (a layer directory or a directory of the repo's key) leads somewhere else", as rule 2 does.
3. **[Design text] low** — The `unusable` row says the version cause is "not among the refs `origin` had when last fetched"; with `ask_local`, `find_version` also gives nothing for a version that is both a branch and a tag, a tag of a tree or blob, a commit missing from a shallow clone, and no version with no `refs/remotes/origin/HEAD` (lines 547-616). Say "the manifest's version cannot be found among the refs `origin` had when last fetched, or names no single commit there; the text says why". The closing paragraph ("A repo that fails the exit status is ...") and the `validate` row's parenthetical also omit `git status` or the count failing; add "or whose state git cannot read", or mark the list as examples.
4. **[Design text] low** — "`missing`, `not-a-directory`, `blocked-place` and `in-other-layer` ... `sync` reports each as an error for a repo that is not optional" is not true of `missing`: `sync` clones it, and reports an error only when the clone fails. Likewise `skipped`, "listed every time, as `sync` lists it": `sync` clones a missing optional repo when it can and lists it as skipped only when it cannot. Say so.
5. **[Root design] low** — The reworded `validate` row names only repo states. `status` also exits 1 when a distro's manifest cannot be read or resolved, or the system directory cannot be found; the current row's "or cannot say" covered that. Write the row as "Fail when `repos-manifest status` exits 1: a repo the manifest calls for is missing, not at its place or unusable, or a distro cannot be resolved; work in progress and lasting setups are reported and do not fail it", so #503 builds on the exit status, not on a list of states. The same applies to the design text's "This is the rule the workspace's `validate` follows" sentence.
6. **[Approach] low** — `standing(git, repo, record, found, head, branch, unpushed)` has no `changes`, but its rule 11 detail ("tries to move it only when the repo has no changes and no commits only here") needs it. Add the argument, or have `status.py` add that clause.
7. **[Approach] low** — For an in-progress operation or `index.lock`, `blocked_late`'s text already carries the stopped-move suffix, and step 3 adds the `stopped_move` text to the detail again for any state. Add it once (take `blocked_late`'s text as is and only set the fact there).
8. **[Exit status] low, owner's veto** — "Not exactly one `origin`" is `left-alone` (decision 16). For two urls that fits; for no `origin` url at all, the version cannot be looked up offline or by `sync`, which is the owner's "its version cannot be found". Either split it (no url: `unusable`; several: `left-alone`) or keep it and say in decision 16 that a repo with no `origin` passes `validate`.
9. **[Design text] low** — "the distros the system directory was set up for (`config.yaml`'s `distros`, whichever are acted on)" reads as both "all" and "the acted-on ones"; the JSON has both (`recorded_distros`, `distros`). Say the human form prints the recorded list and marks which are acted on, or whatever the implementation does. The JSON note also leaves `unpushed` for `left-alone` and `unusable` unsaid; say null, as for `changes` and `behind`.

The rest of the proposed `### status` text is true on the points checked: no network and no write with `ask_local` and `--no-optional-locks`; the three listed differences with `sync`; which distros; the `expected`, `different`, `left-alone` and `not-in-manifest` rows against `update_repo`, `present_repo` and `left_the_manifest`; the merge_pr.sh case; `unpushed` on a branch only; the stopped move as a fact; the exit rule against the owner's words. It is in plain sentences with no bold lead-ins.

### Summary

The plan answers the second review and puts every cause the owner named on the side his words give it; the unnamed causes are placed defensibly, with one (no `origin` at all) left for his veto. The optional-repo "difference" from `sync` does not exist: both skip an optional repo whatever stops it, and the design sentence is true. What remains is wording in the design text and two small implementation notes, all fixable from this entry during implementation.

### Recommended Actions

- [ ] Decision 16: correct the `sync` comparison for optional repos; agreement test accepts `skipped` for optional fixtures.
- [ ] Design text: `blocked-place` row; `unusable` row's version causes; closing paragraph and `validate` row include "state git cannot read"; `missing`/`skipped` rows say `sync` clones when it can.
- [ ] `validate` row and the "rule `validate` follows" sentence: fail when `status` exits 1, including an unresolvable distro.
- [ ] `standing` takes `changes` (or `status.py` adds the clause); the stopped-move text appears once.
- [ ] Owner (veto): a repo with no `origin` url at all — `left-alone` (exit 0) as planned, or `unusable` (exit 1)?
- [ ] Design text: the recorded/acted-on distros sentence; `unpushed` null for `left-alone` and `unusable`.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 11:48 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the third plan review's verdict is ready, with nine low findings the implementer can fix from the entry)
**After**: plan
**Decision**: proceed

Read the Plan Review at a0da9ddd: the split of the old `unknown` state puts every cause the owner named where his words put it, and nothing found would make the code wrong. Its nine low findings go to the implementer in the handoff rather than a fourth plan round. Host decisions, listed for the owner's veto:

1. Finding 8, which the review raised as a question: a required repo with no `origin` url at all is `unusable` (exit 1), because the owner's words put "its version cannot be found" on that side and with no `origin` there is nothing to find it in. A repo whose `origin` has more than one url stays `left-alone`. Undoing it is one line of the mapping and its test.
2. Finding 5: the `validate` row of `docs/manifest/design.md` is worded as failing when `status` exits 1, with what that covers said in plain words, so an unreadable distro is covered too.
3. Finding 1: the plan's decision 16 compared optional repos with `sync` wrongly. `sync` turns any failure of an optional repo into "skipped", so `status` and `sync` follow the same rule; the plan's sentence is corrected in the design text and the agreement test accepts "skipped" from `sync` for optional fixtures.

## Implementation
**Status**: complete
**When**: 2026-11-20 12:42 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-502 at `d3f358f1`

`repos-manifest status [--distro <name>] [--json]` is built, in eight commits after the checkpoint:

1. `58e273ef` characterisation tests (`tests/test_update_characterisation.py`, 13 tests) for `sync`'s first checks: the order of the early answers, the stopped-move text on the in-progress and `index.lock` messages, a `moving` line not naming `HEAD` dropped with no suffix (a rebase and a bisect), and the no-commit answer coming before the `moving` line is touched. All 13 passed against the unchanged `update.py`; none had to be corrected to the code.
2. `de71f9c9` the refactor, alone: `blocked_early`, `blocked_late` (returning `Blocked(kind, text)`), `stopped_move`, an `ask` parameter (default `None`, resolved to `ask_origin` at the call) on `find_version` and `commit_on_origin`, and `ask_local`. `sync`'s behaviour and messages are unchanged. `test_update_safety.py`'s `GIT_CALLS` gains `ask` and `ask_local`.
3. `0f66c0d5` `status.py`; `system.place_problem_kind` (`place_problem` wraps it and returns the same text); `update.standing` with its `Standing` result.
4. `a05702cd` the `status` subcommand in `cli.py` (one function and one parser block next to `sync`'s).
5. `5490d4dd` tests: `tests/status_cases.py` (34 cases shared by two suites), `test_status.py`, `test_status_distros.py`, `test_status_agrees_with_sync.py`, and the read-only scan of `status.py` in `test_update_safety.py`.
6. `1d53f2c8` `behind` counted on the manifest's branch in every case, not only when `HEAD` is behind or equal.
7. `23196235` documents (ADR-0017): the tool's `docs/design.md` (`### status` rewritten, "What is built", the not-built list, and the sentence on what the recorded commit is for), `docs/roadmap.md` (the `status` row checked by `file-exists src/repos_manifest/status.py`), `README.md` ("What works today"), and `docs/manifest/design.md` (the `validate` row, "What the tool has to give", and lines 185, 211, 234 and 313).
8. `d3f358f1` `_url_note` renamed `_remote_note`: `test_url_messages.py` flagged the name, though its text was already masked.

The host checkpoint's three decisions are built in. A required repo with no `origin` url is `unusable` (exit 1), and one with several urls is `left-alone`. The `validate` row fails when `status` exits 1, with what that covers said in plain words, an unreadable distro and an unreadable system directory included. The design sentence on optional repos now says `sync` skips whatever stops an optional repo, and the agreement test accepts "skipped" from `sync` for every optional fixture.

All nine findings of the third plan review are built in, each checked against the code first:
1. Optional repos: the design text is corrected, and the agreement test maps `failed` to `skipped` for optional fixtures.
2. `blocked-place`: "a link on the way to the place (a layer directory or a directory of the repo's key) leads somewhere else".
3. `unusable` lists every version cause and "git cannot read its state"; so do the closing paragraph and the `validate` row.
4. `missing` and `skipped` say `sync` clones the repo when it can.
5. The `validate` row is worded on exit 1.
6. `standing` takes `changes`.
7. The stopped-move text is added once: it is not added again to `blocked_late`'s in-progress and `index.lock` texts. A test checks the count.
8. No `origin` url is `unusable`.
9. The human form prints the recorded distros with the ones shown marked `(shown)`, and the JSON note says `unpushed` is null for `left-alone` and `unusable`.

Where this departs from the plan, and why:
- `standing` is not called by `update_repo`. It lives in `update.py`, reuses `_on_recorded`, `recorded_kind`, `same_version`, `ancestor`, `worktree_holding` and `sync`'s wording, and answers the sub-cases rule 9 cuts off in `sync`. `update_repo` keeps its own ladder, because its actions are interleaved with the checks. Making `sync` go through `standing` would have changed `update_repo`'s control flow beyond what the characterisation tests pin. The agreement test (68 cases) guards the two against drift. It went into the `status.py` commit, not the refactor commit, which stays a pure behaviour-preserving extraction.
- `blocked_early(git)` takes no `place`: it reads `git.place`.
- `sync.resolve_all` is reused for resolving, and `sync.layer_moved` for rule 1. `sync.require_tools` is reused for the environment, so `status` needs `vcs` on `PATH`, as the design's "What the tools rely on" table already said.
- The check order follows `sync`'s actual code: rule 1 (a layer the manifest changed) before the place checks. The plan text gave rule 2 first.
- With `--json`, a system directory that cannot be found or read, or an unrecorded `--distro`, prints no document: the error goes to standard error and the exit status is 1. The design says so. A manifest that cannot be read is reported as every distro's problem, in the document.
- `layer` in the JSON is `_unnamed` for the unnamed first layer, as the resolved files name it; the design says so.
- The design text was written into the docs commit at the end, not first: the handoff ordered characterisation tests first.
- `.agent/work-plans/issue-502/plan.md` was not edited. Decision 16's last bullet there is still wrong about `sync` and optional repos; the design text is the corrected one.

Tests run:
- Whole tool suite (pytest from `tools/repos-manifest`, the repository's `.venv` with `PYTHONPATH=src`, so the worktree's code is the one tested; the `.venv`'s editable install points at the main checkout):
  - before any change: `1757 passed in 551.60s`
  - after the characterisation tests and the refactor: `1770 passed in 556.51s`. After that run, one docstring line in `test_update_safety.py` was re-wrapped for flake8 before the commit.
  - after `status`: `1 failed, 1946 passed` (the `test_url_messages` name scan on `status.py`, fixed in `d3f358f1`); then `1947 passed in 653.03s`.
- Workspace suites under `.agent/scripts/tests/`: none apply. No script under `.agent/scripts/`, no skill and no knowledge text was changed. The full pre-commit pass is left to the host.

Nothing in `~/project11` was read, written or run. The sample runs below are on a fixture system made from local git repos in the session scratchpad (shown as `<demo>`). `core_lib` has a commit only here, `driver` is switched to `dev`, `sim` was removed, and `private_tools` is optional and removed.

```
$ repos-manifest status
system <demo>/sys
manifest ../sys.manifest.yaml
role (none)
groups (none)
distro (no distro):
  core/src/core_lib  expected: on main, with 1 commit not on origin; origin's main has nothing this clone lacks, so the commits are only here; to publish them (sync never pushes): git -C <demo>/sys/core/src/core_lib push origin main [1 commit not on origin]
  core/src/driver  different: it is on branch dev; the manifest names main; sync leaves it as it is
  extra/src/sim  missing: is not there; sync clones it
  extra/src/private_tools  skipped (optional): is not there; sync clones it
exit status: 1
```

```
$ repos-manifest status --json
{
  "format": 1,
  "ok": false,
  "system": "<demo>/sys",
  "manifest": "../sys.manifest.yaml",
  "role": null,
  "groups": [],
  "layout": "flat",
  "recorded_distros": null,
  "distros": [
    {
      "distro": null,
      "ok": true,
      "problem": null,
      "repos": [
        {
          "key": "core_lib",
          "path": "core/src/core_lib",
          "layer": "core",
          "optional": false,
          "state": "expected",
          "detail": "on main, with 1 commit not on origin; origin's main has nothing this clone lacks, so the commits are only here; to publish them (sync never pushes): git -C <demo>/sys/core/src/core_lib push origin main",
          "version": "main",
          "head": "0a92b63af1a5bc769a78e275f423212d89205e11",
          "changes": 0,
          "unpushed": 1,
          "behind": 0,
          "stopped_move": false,
          "url": "<demo>/remotes/core_lib",
          "fetched_from": "<demo>/remotes/core_lib"
        },
        {
          "key": "driver",
          "path": "core/src/driver",
          "layer": "core",
          "optional": false,
          "state": "different",
          "detail": "it is on branch dev; the manifest names main; sync leaves it as it is",
          "version": "main",
          "head": "6c384eea659e72afb525ad14a887a782c1b6dd73",
          "changes": 0,
          "unpushed": 0,
          "behind": null,
          "stopped_move": false,
          "url": "<demo>/remotes/driver",
          "fetched_from": "<demo>/remotes/driver"
        },
        {
          "key": "sim",
          "path": "extra/src/sim",
          "layer": "extra",
          "optional": false,
          "state": "missing",
          "detail": "is not there; sync clones it",
          "version": "main",
          "head": null,
          "changes": null,
          "unpushed": null,
          "behind": null,
          "stopped_move": false,
          "url": "<demo>/remotes/sim",
          "fetched_from": null
        },
        {
          "key": "private_tools",
          "path": "extra/src/private_tools",
          "layer": "extra",
          "optional": true,
          "state": "skipped",
          "detail": "is not there; sync clones it",
          "version": "main",
          "head": null,
          "changes": null,
          "unpushed": null,
          "behind": null,
          "stopped_move": false,
          "url": "<demo>/remotes/private_tools",
          "fetched_from": null
        }
      ],
      "not_in_manifest": []
    }
  ]
}
exit status: 1
```

The agreement test saw these pairs (state from `status`, then `sync`'s outcome), all within the allowed pairs or the listed differences: expected with up to date (6 cases), updated (behind) or left alone (commits only here, branch held by a work tree); a branch origin deleted is expected, then failed (listed); different with updated (the manifest changed version) or left alone (7 cases); a local tag origin lacks is different, then failed (listed); left-alone with left alone (8 cases); unusable with left alone (4 cases); a version not fetched is unusable, then updated (listed: the fetch brings it); missing with cloned; not-a-directory with failed.

Left undone: none of the plan's items. The by-hand acceptance on project11 is the owner's. The adapter's use of `status` is #503 (the adapter calls the tool's commands).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 12:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-502 at `a437f64d`
**Base**: main
**Depth**: Deep (reason: about 2900 lines over 16 files; it changes `update.py`, which protects local work during `sync`)
**Must-fix**: 2 | **Suggestions**: 8
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; the first round always re-reviews after fixes

Checked: the refactor de71f9c9 does the same checks, in the same order, with the same text, and drops the `moving` line under the same condition as the code before it; the 13 characterisation tests plus test_update.py:407 pin each branch. The only untested branches are a stopped move together with a sparse checkout or no single origin: no suffix before or after the change. 310 tests passed in the status, agreement, characterisation, safety and url suites. Pre-commit was clean on the changed .py files. The behind-plus-changes and probe cases were reproduced by hand: status says one thing and sync does another. A repo-configured clean filter runs under status's `git status`; this was shown with a marker file. Outside reviewers: gemini and codex both completed; the Claude adversarial reviewer completed.

### Findings
- [x] (must-fix) A repo behind origin on the manifest's branch with uncommitted changes is reported as "sync fast-forwards it", but sync leaves it alone ("has uncommitted changes"). Check `changes` as `_would_move` does, and add the same caveat to the design's expected row (design.md:1545) — `tools/repos-manifest/src/repos_manifest/update.py:1234`
- [x] (must-fix) The per-distro JSON `ok` stays true when a required repo in that distro fails. Only the top-level `ok` follows the exit status, so a script cannot tell which distro failed. Either compute it from `fails()` or document `ok` as "resolved". Also say that `repos` and `not_in_manifest` are absent, not empty, for an unresolved distro — `tools/repos-manifest/src/repos_manifest/status.py:144` (design.md:1599)
- [x] (suggestion) `_remote_note` says "sync repoints origin to it" when a `repos-manifest-probe` remote exists, but then sync leaves the repo alone. Check `update.probe_taken` (a local read), and say "tries to", since `_repoint` can still decline — `tools/repos-manifest/src/repos_manifest/status.py:280`
- [x] (suggestion) status calls `sync.require_tools()` and exits 1 with no document when `vcs` is missing, although it never runs vcs. `validate` would then fail, and the design does not list this cause — `tools/repos-manifest/src/repos_manifest/status.py:118`
- [x] (suggestion) "changes nothing on disk and makes no network call" depends on the clone's own config. A repo `core.fsmonitor` hook and clean filters such as LFS run under `git status`; this was verified. Nothing stops a lazy fetch in a partial clone. Pass `-c core.fsmonitor=false` and `GIT_NO_LAZY_FETCH=1`, and qualify the text — `tools/repos-manifest/docs/design.md:1515`
- [x] (suggestion) The agreement test is weak. GOES_WITH accepts expected→updated and different→updated whatever the text claims, so it would not catch a wrong "sync leaves it" or "would try to move it". There are no cases for uncommitted changes on expected or behind repos (the must-fix above slipped through), a missing version (default branch), url changed, probe taken, a moved tag, or blocked-place and in-other-layer (listed in GOES_WITH but with no case) — `tools/repos-manifest/tests/test_status_agrees_with_sync.py:15`
- [x] (suggestion) The read-only scan allows `config` with any arguments. It checks only keyword arguments, not the git subcommands, in the `update` functions status reaches, and it does not walk the `sync` functions status calls — `tools/repos-manifest/tests/test_update_safety.py:396`
- [x] (suggestion) "shares its checks with sync's, so the two read a repo the same way" overstates: rules 9-12 are a second implementation (`standing`), held in step only by the agreement test. Reword this sentence and the status.py docstring — `tools/repos-manifest/docs/design.md:1960`
- [x] (suggestion) `ask_local` differs from `ls-remote` in edge cases. `%(*objectname)` peels a tag of a tag only one level, while `ls-remote` peels fully. `splitlines()` also splits ref names that contain U+2028 or similar characters — `tools/repos-manifest/src/repos_manifest/update.py:551`
- [x] (suggestion) status never calls `remember_url` for origin, the manifest url or the recorded url, as `update_repo` does. Masking of free text then falls back to the pattern for urls the tool read — `tools/repos-manifest/src/repos_manifest/status.py:241`

## Implementation
**Status**: complete
**When**: 2026-11-20 13:23 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-502 at `448401c4`
**Addressed**: Local Review (Pre-Push) at `a437f64d` (2026-11-20 12:50 -05:00)
**Commits**: 187ef6a0, fb4612b2, 4a5e137a, 71e03f6c, 59ad3876, c04f3c97, ee44383f, ddf1e844, 448401c4

The host's decisions 1 to 9 on the findings were followed as given (the owner may veto them later). Each finding was checked against the code first and each held.

### Actions
- [x] (must-fix) Behind with uncommitted changes said "sync fast-forwards it". Fixed in 187ef6a0 (host decision 1): `standing` and `_would_move` take `held`, what stops `sync` before its rules (a remote named repos-manifest-probe with the url changed, then uncommitted changes), read in `status._version`; the state stays expected. Fast-forwards and moves are said as what `sync` tries, and AS_FETCHED now says "a fetch may find it". The final standing text is now "sync does not move it". The design's expected and different rows and its url text were updated. — `tools/repos-manifest/src/repos_manifest/update.py`, `status.py`
- [x] (must-fix) Per-distro `ok` — fb4612b2 (host decision 2): a distro's `ok` is false when one of its required repos is in a failing state; the top `ok` stays the exit status. The design defines `ok` at both levels and says `repos` and `not_in_manifest` are left out for a distro that cannot be resolved. Tested with one good and one failing distro. — `status.py`, `docs/design.md`, `tests/test_status_distros.py`
- [x] (suggestion) `_remote_note` with the probe remote taken — 187ef6a0 (host decision 1): reads `update.probe_taken` for a url to repoint; says that `sync` leaves origin and the repo as they are when it is taken, and otherwise that it "tries to repoint", leaving them when the probe fetch fails or a local commit is not on the new url. — `status.py`
- [x] (suggestion) `require_tools` called by status — 4a5e137a (host decision 3): `sync.require_git()` split out (require_tools runs the same checks in the same order, then calls it), and status calls only that. The design's "What the tools rely on" table now gives status its own row, the README says it, and a test runs status with only git on PATH. — `sync.py`, `status.py`
- [x] (suggestion) Writes nothing and no network — 71e03f6c (host decision 4): `update.Git` takes extra `options` (sync passes none). Status's calls pass `-c core.fsmonitor=false`, run with `GIT_NO_LAZY_FETCH=1`, and empty `clean`/`smudge`/`process` and set `required=false` for every filter driver the clone's config names (`GIT_CONFIG_COUNT` for a name holding `=`). The design says plainly that turning a filter off can change the answer (a stat-dirty file under a filter may count as changed), that git before 2.45 ignores the variable, and that a driver configured only in a submodule's own config is not turned off. Marker-file tests show no filter or hook runs, and turning off either override makes them fail. — `status.py`, `update.py`, `docs/design.md`
- [x] (suggestion) Agreement test too weak — 59ad3876 (host decision 5): every sentence of status's text that says what sync does is matched against sync's outcome and output, and a sentence naming sync the test does not know fails it. New cases: changes on expected and on behind, no version (also behind), url changed, probe taken (also behind), moved tag, link on the way (blocked-place), another layer. Reverting the must-fix makes four cases fail. — `tests/test_status_agrees_with_sync.py`, `tests/status_cases.py`
- [x] (suggestion) Read-only scan — c04f3c97 (host decision 6): `config` only in reading forms and `worktree` only as `list`. The git subcommands of every reached update function are checked (cat-file, status, ls-files and ls-tree added as reads), the sync functions status calls are walked for writes and for the commands they run, and status's `find_version`/`commit_on_origin` calls must pass `ask=update.ask_local`. — `tests/test_update_safety.py`
- [x] (suggestion) "shares its checks" overstated — ee44383f (host decision 7): the design and the status.py docstring list the functions both call and name `standing` and status's place and order checks as a second copy held in step by the agreement test; sync is not routed through `standing`. — `docs/design.md`, `status.py`
- [x] (suggestion) `ask_local` edge cases — ddf1e844 (host decision 8): reads `%(*objecttype)` and peels a still-tagged peel with `rev-parse <ref>^{}`. Git 2.53 here already peels fully; the test also simulates one-level peeling. Lines are split at `\n` only, and a test covers a ref name holding U+2028. — `update.py`, `tests/test_status.py`
- [x] (suggestion) `remember_url` — 448401c4 (host decision 9): status registers each manifest url, each recorded url and each origin before masking, and masks the manifest location too. A test puts a credential with a space (which the pattern misses) in origin, the record, the manifest and a failing manifest, and finds it in neither output form nor in stderr. — `status.py`, `tests/test_status.py`

### Checks
- `PYTHONPATH=src .venv/bin/python -m pytest tests` (whole repos-manifest suite) at 448401c4: `2004 passed in 653.08s (0:10:53)`.
- Run per fix: test_status.py, test_status_agrees_with_sync.py, test_status_distros.py, test_update_safety.py, test_init.py, test_documents.py, test_url_messages.py, test_masking.py, all passing.
- The `.agent/scripts/tests/` suites: none apply (no workspace script changed). Every commit used `SKIP=validate-script-tests`; the full pre-commit pass is left to the host.
- What sync does and prints is unchanged: `update_repo` and `_sync` were not edited. The shared changes are `Git`'s optional `options` (empty for sync), the `require_git` split (same checks, same order) and `ask_local` (status only). No edit to cli.py or docs/manifest/design.md. Nothing in ~/project11 was read or run.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 13:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-502 at `fd86341d`
**Base**: origin/main
**Depth**: Deep (reason: about 3600 lines over 17 files; changes update.py, which protects local work during sync)
**Must-fix**: 2 | **Suggestions**: 9
**Round**: 2 | **Ship**: continue — round 2: 2 must-fix include a design/correctness concern (not mechanical)

Checked: round 1's ten findings are in the code. `sync` is unchanged: `Git(place, env, lock)` passes no options so its argv is the same as on main, `find_version`/`commit_on_origin` still default to `ask_origin`, and `require_tools` runs the same checks in the same order with the same messages before `require_git`. Every sentence `status` prints about `sync` was traced against `update_repo`, `_move` and `_repoint`: each holds, except the filter case below. Merge: `show.py` and its tests are byte for byte as on main; status/update/sync are unchanged by the merge; `cli.py` has both imports and both parsers; the three conflicted documents read correctly, apart from design.md:1678 below. The JSON fields match the design. Masking: five credential forms in origin, none leaked (adversarial reviewer). The git-2.45 statement for GIT_NO_LAZY_FETCH matches git's 2.45.0 release notes. Tests: 349 passed (test_status, test_status_agrees_with_sync, test_status_distros, test_update_safety, test_update_characterisation, test_show, test_cli). Pre-commit was clean on the changed files (validate-script-tests skipped). Outside reviewers: gemini and codex completed; the Claude adversarial reviewer completed.

LFS-like filter evidence (clean `base64 -w0`, smudge `base64 -d`, required): in a fresh clone, `git status --porcelain` printed nothing, but `tracked_changes` under `_reading_git` counted 2 and under sync's `Git` counted 0. In the test harness, after sync, the remote moved ahead, the clone was fetched, and `a.bin` was touched: `git status` was clean. `status` said `expected 1 ... behind origin's as last fetched; sync leaves it while it has uncommitted changes (1 file)`, and then `sync` printed `src/a: fast-forwarded 1 commit`.

### Findings
- [x] (must-fix) With filters turned off, a file under a clean/smudge filter (Git LFS) that is stat-dirty counts as changed while `git status` and `sync` see it as clean. This covers racily clean entries straight after a clone or sync, and any file that was touched. `status` then says "sync leaves it while it has uncommitted changes", but `sync` fast-forwards. The agreement test has no filtered case. Either run the clone's filters, or treat changed files that carry a filter attribute as unknown and make no claim about sync for them — `tools/repos-manifest/src/repos_manifest/status.py:312` (FILTER_OFF at :84; design.md:1561)
- [x] (must-fix) "The workspace's `validate` fails when `status` exits 1." is not built: `make validate` does not run status, and the adapter does not call it yet (#503) — `tools/repos-manifest/docs/design.md:1678`
- [x] (suggestion) `ask_local` peels every nested tag before it filters by pattern, so one unrelated tag that cannot be peeled makes a healthy repo `unusable` (exit 1). Filter first. Raised by three reviewers — `tools/repos-manifest/src/repos_manifest/update.py:568`
- [x] (suggestion) The design gives the move-blocking order as "local new branch ..., or the new branch held by another work tree ... in that order". The code and `_move` check the work tree first — `tools/repos-manifest/docs/design.md:1600`
- [x] (suggestion) A commit pin held only by a branch origin deleted: `status` says expected/pinned (exit 0), `sync` leaves it "not followed". This is not in the design's list of cases that differ, nor in DIFFER/CASES — `tools/repos-manifest/docs/design.md:1565`, `tools/repos-manifest/tests/status_cases.py`
- [x] (suggestion) `fetched_from` is null for in-progress, index.lock and sparse repos, which have one origin, because `blocked_late` reads the url last. The design's null list does not say so — `tools/repos-manifest/src/repos_manifest/status.py:257`
- [x] (suggestion) A filter name holding `=` is turned off through GIT_CONFIG_COUNT, which git only reads from 2.31 (the tool allows 2.23). A negative inherited count is advanced to a valid one, which leaves the filter on. Neither limit is in the design — `tools/repos-manifest/src/repos_manifest/status.py:289`
- [x] (suggestion) Two stated limits could be closed rather than documented: a filter set only in a submodule's own config still runs, and on git before 2.45 a partial clone may still lazy-fetch (refuse or flag a partial clone there) — `tools/repos-manifest/src/repos_manifest/status.py:81`
- [x] (suggestion) The adapter's validate line still says "(there is no repos-manifest status yet)", which is now false. Reword it with its test, or leave it to #503 and say so — `.agent/project_types/ros2_colcon/adapter.sh:1087`
- [x] (suggestion) An origin url set to an empty value passes as one url. `status` then answers from stale refs (possibly expected, exit 0), while `sync`'s fetch fails. Found by reading the code, not run — `tools/repos-manifest/src/repos_manifest/update.py:999`
- [x] (suggestion) A duplicate assert (line 83 repeats line 82) — `tools/repos-manifest/tests/test_status.py:83`

## Implementation
**Status**: complete
**When**: 2026-11-20 14:28 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-502 at `0ee41b71`
**Addressed**: Local Review (Pre-Push) at `fd86341d` (2026-11-20 13:47 -05:00)
**Commits**: 93a2f49a, 4958af37, eb1c036a, 626d0cef, 13f54e08, 4f99421a, 81c069fc, c7b81b51, 8b610c68, d74faec8, 19225610, 0ee41b71

### Actions
- [x] (must-fix) Filters: per the host's decision, `status` now runs git with the clone's own filter drivers on, as `sync`'s git and `git status` do; FILTER_OFF and the GIT_CONFIG_COUNT handling are gone. The design says `status` writes nothing in the system directory, makes no network call of its own, and runs the clean filters a clone's config names, so a filter that writes or fetches is outside its promise. The marker test's filter half is replaced by a test that the filter runs and `status` agrees with `git status`; the agreement test gains "a filtered fresh clone" (expected, sync up to date) and "a filtered file touched, behind" (status predicts the fast-forward, sync does it), both with a required clean filter that changes the stored form — `status.py`, `design.md` "status", `status_cases.py`, `test_status.py` (93a2f49a)
- [x] (must-fix) The design no longer claims `validate` fails on `status`: it says the workspace's `validate` does not run `status` yet and is to call it under issue 503. docs/manifest/design.md's `validate` row is the Target column and says no more — `design.md:1686` (4958af37; reworded in 0ee41b71 because the tool's documents may not name the adapter, `tests/test_documents.py`)
- [x] (suggestion) `ask_local` filters by pattern first and peels only the tags asked for; tested with an unpeelable tag of a tag that is not asked for — `update.py:546` (eb1c036a)
- [x] (suggestion) The design's order for what stops a move now matches `_would_move` and `_move`: the work tree first — `design.md` (626d0cef)
- [x] (suggestion) A commit pin held only by a branch origin deleted is in the design's list of cases that differ and in DIFFER/CASES; the agreement test runs both (status expected, sync left alone, not followed) — `status_cases.py`, `test_status_agrees_with_sync.py` (13f54e08)
- [x] (suggestion) `fetched_from` is filled in for in-progress, index.lock and sparse repos by a config read; the design says when it is null (no single origin url, not a git clone with a commit, a link at the place); tested — `status.py` (4f99421a)
- [x] (suggestion) GIT_CONFIG_COUNT limits: disposed of with the filter code removed in 93a2f49a
- [x] (suggestion) Stated limits: the submodule-filter limit no longer applies (filters run). The partial-clone limit on git before 2.45 is closed: with such a git, or one whose version cannot be read, `status` calls a partial clone `unusable` and says why; `sync.git_version` is split out of `require_git_version` with unchanged behaviour and messages; tested with the version patched — `status.py`, `sync.py` (81c069fc, wording 19225610)
- [x] (suggestion) The adapter's validate line says the adapter does not call repos-manifest status yet and that issue 503 makes it do so; its test changed with it, nothing else in the adapter — `adapter.sh:1087`, `test_ros2_colcon.sh:4494` (d74faec8)
- [x] (suggestion) An origin url set to an empty value is `unusable` in `status` only: moving it into the shared check would change what `sync` prints (it now says "origin is , ... left as set" and its fetch fails, checked by a run). Added as an agreement case — `status.py`, `status_cases.py` (c7b81b51)
- [x] (suggestion) Duplicate assert removed — `test_status.py` (8b610c68)

### Host decisions recorded (the owner may veto)
- Filters run under `status` (the earlier decision to turn them off is withdrawn); fsmonitor and lazy fetch stay off.
- How it is known they cannot change the answer: an fsmonitor hook only tells git which files it need not look at again, and with none git looks at every file (what a working hook stands in for). For lazy fetch, the objects `status`'s git reads are the refs' commits and tags, what those tags name, and the checked-out trees and blobs; a blob:none partial clone has each (checked by hand: a tag of a blob is fetched with the clone), and `test_no_lazy_fetch_does_not_change_the_answer` shows a partial clone, with its remote gone, gives the same answer with lazy fetch allowed as with it off, and the expected state.
- A partial clone with git older than 2.45 is `unusable` (exit 1). Ubuntu 24.04 ships git 2.43, so such clones fail `status` there; that is the price of the promise and is for the host to weigh.

### Tests
- Whole tool suite, `tools/repos-manifest`: `2103 passed in 675.77s (0:11:15)` (a first run had 1 failure, the design sentence naming the adapter, fixed in 0ee41b71 before this run).
- `bash .agent/scripts/tests/test_ros2_colcon.sh` (the suite that names the changed message): `=== Results: 1375 passed, 0 failed, 0 skipped ===`.
- The full pre-commit pass was left to the host. Nothing in ~/project11 was read, written or run.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 14:42 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-502 at `cee31314`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 1
**Round**: 3 | **Ship**: continue — round 3: 1 must-fix with a design choice in it (not mechanical); down from 2

Checked: all eleven round-2 findings are in the code (filters on, FILTER_OFF and GIT_CONFIG_COUNT handling gone; design no longer says `validate` runs status; `ask_local` filters by pattern before it peels, and is otherwise the same as before, error text included; move order matches `_would_move`/`_move`; the deleted-branch commit pin is in the design, CASES and DIFFER; `fetched_from` is filled in for operation/index.lock/sparse and registered before masking; empty origin url is unusable; adapter line and its test reworded; duplicate assert gone). `sync.git_version` split: `require_git_version` runs the same `git --version` (LC_ALL=C), raises the same Refusal when it does not run, skips an unreadable version, and raises the same "older than 2.23" message; `require_git` calls it at the same point. The design's four cases that differ are each true and each in the agreement test ("a branch origin deleted", "a commit on a branch origin deleted", "a local tag origin lacks" in DIFFER; "a url changed" in CASES). Cross-model: skipped (round-3 convergence check, per handoff).

By hand, filter `b64` (clean `base64 -w0`, smudge `base64 -d`, required; stored form differs from the checkout): fresh clone, `git status --porcelain` empty, `status --json` expected, changes 0, exit 0. Origin moved ahead, clone fetched, `a.bin` touched: `git status` empty, `status` said "on main, behind origin's as last fetched (sync tries to fast-forward it)", changes 0, behind 1; `sync` printed `src/a: fast-forwarded 1 commit`, and `status` after it said expected, behind 0.

By hand, partial clone (blob:none, file:// origin with allowFilter): branch `later` renames a.txt to b.txt with a small edit; clone at main, fetch `later`, `git reset --soft FETCH_HEAD`. status's exact `git status` argv with `GIT_NO_LAZY_FETCH=1` fails (exit 128, "could not fetch ... from promisor remote"); without the variable (as on git before 2.45) it exits 0 and a third pack appears, trace2 shows a child `git fetch origin --filter=blob:none --stdin`. Cause: `status --porcelain=v2` detects renames between HEAD and the index by default, and reads a HEAD blob that was never checked out.

Tests: 349 passed (test_status, test_status_agrees_with_sync, test_status_distros, test_update_safety, test_cli). Nothing in ~/project11 was read, written or run.

### Findings
- [x] (must-fix) A partial clone with git before 2.45 (or an unreadable version) is `unusable`, exit 1, which is outside the owner's exit rule (missing, not at its place, not a git repo of its own, no commit, version not found) and fails every partial clone on Ubuntu 24.04's git 2.43. The host's reversal (report it in its ordinary state, state the limit in the design) is sound on the exit rule, but its stated ground is false: `status` reads only held objects except when HEAD was moved without a checkout (reset --soft, update-ref), where `git status`'s rename detection lazy-fetches on old git, and on 2.45+ makes `git status` fail so the repo is `unusable` "git status fails". Reverse it, and either have status's git skip rename detection (e.g. `-c status.renames=false`; a staged rename then counts 2 files where `sync` says 1, so say so) or state this case in the design; the test `test_no_lazy_fetch_does_not_change_the_answer` should gain the reset --soft case — `tools/repos-manifest/src/repos_manifest/status.py:287`, `tools/repos-manifest/docs/design.md:1569`, `:1607`, `:1690`, `tools/repos-manifest/README.md:152`
- [x] (suggestion) "a url changed" copies the remote, so the new url's refs equal the old ones and the case agrees trivially; the design's fourth difference (status answers from the old url's refs) is listed but not exercised. A copy that moves ahead before the sync would show it, as a DIFFER or CLAIMS_DIFFER entry — `tools/repos-manifest/tests/status_cases.py:94`

## Checkpoint
**Status**: complete
**When**: 2026-11-20 14:32 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 left one must-fix that breaks the owner's exit rule and came from a host instruction; it cannot be published as it is)
**After**: rounds
**Decision**: address

Read the Local Review (Pre-Push) at c1eca0fe (round 3, changes-requested, one must-fix, one suggestion; all eleven round 2 findings fixed). This is the first host `address` at the rounds checkpoint. Host decisions, listed for the owner's veto:

1. A partial clone is reported in its ordinary state whatever the git version. Calling it `unusable` on git before 2.45 breaks the owner's exit rule ("Only unusable repos"): a partial clone is a usable repo, and Ubuntu 24.04 ships git 2.43. That behaviour followed a host instruction in the previous handoff, which is withdrawn.
2. The review showed `status`'s own `git status` can fetch in a partial clone: rename detection between HEAD and the index reads a file that was never checked out, when HEAD was moved without a checkout. So in a partial clone, and only there, `status` counts changes with rename detection off. No object the clone lacks is then read, on any git version, and `status` neither fetches nor fails for want of one. The cost, stated in the design: in a partial clone a staged rename counts as two files where `sync` and `git status` say one. `GIT_NO_LAZY_FETCH=1` stays as a second guard where git honours it. Undoing it is one option and its tests.
3. The suggestion is taken: the "a url changed" agreement case uses a copy that moves ahead before the sync, so the design's fourth difference is exercised.

## Implementation
**Status**: complete
**When**: 2026-11-20 14:54 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-502 at `37bfe91a`
**Addressed**: Local Review (Pre-Push) at `cee31314` (2026-11-20 14:42 -05:00), as the Checkpoint of 2026-11-20 14:32 -05:00 decides
**Commits**: 783239df, 883e8dd1, fe9a84e2, 37bfe91a

### Actions
- [x] (must-fix, checkpoint 1) A partial clone is read in its ordinary state whatever the git version: the `unusable` rule for git before 2.45 or an unreadable version, `LAZY_FETCH_KNOWN`, `lazy_off` and its test are gone, with the design (states table, plain-words exit paragraph, the bullet) and README text. `sync.git_version` then had no caller but `require_git_version`, so it is folded back and `sync.py`'s version check is as on main (the safety test's allowed `sync` names drop `git_version`) — 783239df, `tools/repos-manifest/src/repos_manifest/status.py`, `sync.py`
- [x] (must-fix, checkpoint 2) In a partial clone, told by reading its configuration (promisor remote or `extensions.partialClone`), `status`'s git runs with `-c status.renames=false`; a clone that is not partial keeps rename detection. New tests: `test_a_partial_clone_with_a_staged_rename_reads_no_missing_object` (blob:none clone, fetch a branch that renames a 200-line file with a one-line edit, `reset --soft FETCH_HEAD`; run with `GIT_NO_LAZY_FETCH` honoured and with it removed; asserts no file below the system directory changed, packs included, exit 0, changes 2) and `test_a_clone_that_is_not_partial_keeps_rename_detection` (a staged `git mv` counts 1); `test_status_asks_git_for_no_lazy_fetch` now checks the whole option list. With `NO_RENAMES` emptied by hand the new test fails both ways (honoured: exit 1, `git status` fails; removed: a pack is fetched) — 883e8dd1
- [x] (must-fix, checkpoint 3) Design and README say: `status` makes no network call of its own; in a partial clone it counts changes without rename detection so it never needs a file the clone lacks, and a staged rename there counts two files where `sync` and `git status` say one; the sentence that said a partial clone holds every object `status` reads is corrected. The agreement test needs no listed exception (no case is a partial clone and the claim patterns match any count); a comment there says so — fe9a84e2
- [x] (suggestion, checkpoint 4) "a url changed" now uses a copy with a commit the old url lacks, and DIFFER lists it as "updated" with its reason; with the copy not moved ahead the case fails, so the difference is exercised — 37bfe91a, `tools/repos-manifest/tests/status_cases.py:94`

### Notes
- Reproduction by hand (git 2.53.0), status's exact `git status` argv, fresh blob:none clone per run, trace2 child count and packs: rename detection on, variable set: exit 128 "could not fetch"; variable removed: exit 0, one child `git fetch`, a pack added, `R` entry. With `-c status.renames=false` (and, checked too, `--no-renames`): exit 0, no child fetch, no new pack, with the variable set and removed; output `A` a.txt and `D` b.txt.
- Found beyond the checkpoint: a clone filtered on trees (`--filter=tree:0`) after `reset --soft` onto a fetched commit lacks `HEAD`'s trees, so `status`'s `git status` still needs a missing object even with rename detection off: "bad tree object HEAD" with the variable set, a fetch without it. The design states this case (unusable with git 2.45+, a fetch with older git); no code was added for it. A host decision.
- Whole tool suite, `tools/repos-manifest`: `2102 passed in 670.84s (0:11:10)`. The full pre-commit pass was left to the host. Nothing in ~/project11 was read, written or run.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 14:57 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-502 at `4e91a564`
**Base**: origin/main
**Depth**: Deep (reason: round 4 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 4 | **Ship**: recommended — no must-fix findings; down from 1

Checked (commits 783239df, 883e8dd1, fe9a84e2, 37bfe91a): the partial-clone `unusable` rule, `LAZY_FETCH_KNOWN`, `lazy_off`, `sync.git_version` and its test are gone (no leftover in src, tests, docs, README). `git diff origin/main -- sync.py` shows only the `require_git` split: `require_tools` returns `require_git()`, which holds the git half unchanged. Detection (`_partial`, status.py:296) reads `extensions.partialClone` or any `remote.*.promisor` true, the two settings git itself uses to decide a repo has a promisor remote, so a clone git would lazy-fetch for is always detected; a promisor set without a filter is detected but only costs the rename count; a non-boolean promisor makes git itself fail, so `unusable` either way. A fresh `--filter=blob:none` clone on git 2.53 sets only `remote.origin.promisor`, which is matched. `NO_RENAMES` is added only on the partial path (status.py:262, :291), and `tracked_changes` (the one `git status`) runs after it; `blocked_early` runs no command that reads blobs. With `NO_RENAMES` emptied in-process, both `test_a_partial_clone_with_a_staged_rename_reads_no_missing_object` cases fail (honoured: exit 1; removed: the snapshot changes, a pack fetched); `test_a_clone_that_is_not_partial_keeps_rename_detection` passes with it, as it should. With the old `url_changed` (copy not moved ahead) patched in, both "a url changed" agreement cases fail, so the difference is exercised. By hand, `--filter=tree:0` clone, fetch a branch, `reset --soft FETCH_HEAD`, status's exact argv with `GIT_NO_LAZY_FETCH=1` and `status.renames=false`: "error: bad tree object HEAD", exit 128, as the design says; the result is `unusable` ("`git status` fails here"), inside the host's earlier placement of a failing `git status`, for a repo that cannot be read offline. The design's and README's partial-clone sentences are each true as checked. Cross-model: skipped (round-4 convergence check, per handoff).

Tests: 342 passed (test_status, test_status_agrees_with_sync, test_update_safety, test_cli). Nothing in ~/project11 was read, written or run.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 15:01 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 4 approved with no findings; the host's full pass passed on this head)
**After**: publish
**Decision**: publish

Read the Local Review (Pre-Push) at 4ab1fe43 (round 4, approved, ship recommended, no findings). The full pass (`pre-commit run --files` over the branch's files, no SKIP, branch even with origin/main, 2m50s) passed: every hook Passed or Skipped for no files, including the adapter contract check, the `.agent/scripts/tests/` suite, shellcheck, black and flake8; the tree was clean after it.

## Integrated Review
**Status**: complete
**When**: 2026-11-23 09:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #546 at `93abb9cb`
**Sources**: 2 (Local Review (Pre-Push) @ `4e91a564` (covers `93abb9cb` via bookkeeping: the only change since is progress.md), CI rollup @ `93abb9cb`)
**Cross-source confirmations**: 0
**CI**: all-pass

GitHub: no reviews, no inline comments, no conversation comments on the PR as of this triage. `review_progress.sh sources` returned no open local findings and no dropped entries: the round-1 to round-3 pre-push findings are all ticked with their fixing commits, and round 4 at `4e91a564` approved with none. CI on `93abb9cb`: 10 check runs, all success (Lint (pre-commit), Validate Documentation, Validate Adapter Contract, repos-manifest tests on Python 3.10 and 3.14, each from two triggers).

Main drift: the branch is 173 commits behind origin/main and `git merge-tree` merges it cleanly. `git diff feature/issue-502...origin/main` touches 18 files, none of them under `tools/repos-manifest`, `.agent/project_types`, `.agent/scripts/tests/test_ros2_colcon.sh`, `docs/manifest`, `.github` or `.pre-commit-config.yaml`. Main's changes are the research, brainstorm and design-discussion skills, `test_skill_paths.sh`, other issues' work plans, and two rows of `docs/design.md` (skill count, Decisions row) that this PR does not touch or depend on. No change on main makes the clean text merge wrong in substance for this PR's files.

PR body has its `## Decision summary` (level 2).

### Findings
- [x] No open findings from any source.

### False positives
- None.
