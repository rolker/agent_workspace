---
issue: 437
---

# Issue #437 — A records write from outside any issue worktree commits onto that checkout's main branch, silently

## Issue Review
**Status**: complete
**When**: 2026-11-10 13:07 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #437

### Scope Assessment

**Well-scoped?** Yes, one small pull request. The gap is two unguarded writers (below) plus tests; no second mechanism is needed.
**Right repo?** Yes, workspace (`.agent/scripts/`).
**Serves**: leave a trail that is where the loop reads it; start limits strict (`docs/design.md#rules`, the progress-entry row).
**Design picture?** Changes the records-gate description #429 adds to `docs/design.md` (a one-line extension of that same paragraph); no new design question.
**Dependencies**: #429 pull request 1 (not merged). Branch from it with `--parent-issue 429`; do not start from main.

**Where the gap is (read from this tree, not run: the sandbox reproduction was denied to this phase; the issue records two reproductions)**
- `progress_append.sh` derives ROOT from `git -C $DIR rev-parse --show-toplevel` and commits there. No resolver call, no check of the checkout: it commits on whatever branch is checked out.
- `review_progress.sh persist` in compatibility mode (the default, `PROGRESS_PERSISTENCE_STRICT=0`) evaluates `resolve_work_plans_dir`, prints a notice that it "would have aborted", then does the inline append and commit anyway.
- Strict mode (`--strict`) already refuses from a main checkout (resolver rule 3, exit 4). Of the skills, only review-issue and review-plan pass `--strict` unconditionally; plan-task, review-code, triage-reviews and address-findings show it as optional `[--strict]`.
- #429's guard (`records_path`, `issue_checkout_guard`) is a no-op when no `.worktree-repos` manifest encloses the path, so it does not cover a main checkout.

**Writers and readers that run from outside an issue worktree (the target is what matters, not the cwd)**
- `merge_pr.sh` gate record (line ~837): WRITES, `progress_append.sh -C <the PR's worktree>`, run from the root; already skips a worktree that is a main tree. Falls back to a PR comment. Must keep working: the guard has to judge the `-C` target, not $PWD.
- `merge_pr.sh` gate lookup (line ~682) and `_bookkeeping.sh`: READ the worktree's progress.md and run git in the worktree, from the root.
- `dispatch_phase.sh`: READS (`next --progress`, `review_progress.sh round --progress`); finds the worktree through `resolve_worktree` from the main-tree root, so it runs from the root by design. Writes nothing.
- run-issue host: WRITES, `progress_append.sh <N>` for inline phases and every `## Checkpoint`; the skill has the host sit inside the issue worktree (it refuses to run elsewhere), so these are in-worktree.
- `review_progress.sh` subcommands with `--progress <path>` (`round`, `sources`, `findings`, `check`, `plan-sha`): READ, except `check`, which WRITES the file (flips a box) without committing. Take explicit paths, so they work from the root.
- `sitrep` (skill, `progress_read.py`): READS timelines across worktrees from the root.
- `cross_model_review.sh --work-plans-dir`: writes review artifacts into an explicit dir; its resolver already refuses without the override or a matching worktree.
- `update_roadmap.sh`, `capture.sh`: do not touch progress.md (roadmap file / inbox); `update_roadmap.sh` is committed by `merge_pr.sh` in the PR worktree, not on main. Out of scope.

**Reads: no refusal.** The sit-rep and dispatcher read from the root on purpose, and a read cannot move a commit onto main. The guard belongs on writes that commit (`progress_append.sh`, `persist` both modes). `check` writes without committing: leave it, or have it follow the same write rule; the plan should decide and say why. (#429's guard refuses reads too, but only inside a package worktree, where reading the wrong sibling's timeline is the harm.)

**Dependency on #429.** An extension, not a second mechanism. #429 has one choke point (`records_path` / `records_dir`, in `_resolve_work_plans_dir.sh`) that `progress_append.sh` and every `review_progress.sh` records path already call; this issue adds a second rule to that same function (the write target is a linked issue worktree on a non-default branch, not a main checkout) and the same callers get it. Branching from #429's branch with `--parent-issue 429` is the workspace's pattern and avoids a merge conflict in `progress_append.sh`, `review_progress.sh` and `_resolve_work_plans_dir.sh`, which #429 rewrites heavily (+200 lines in the resolver). The pull request base must be retargeted to main after #429 merges.

**Stray commits.** None found. `git log main --first-parent` has 188 commits; the only non-merge commits are the initial one and the ADR cleanup, neither touching work-plans. No stray `progress:` commit on main. The registered project checkouts (gz4d, p11-jazzy, p11-rolling) show none either. Local feature-branch commits not yet merged were not searched (they are not on main).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Leave a trail / records where the loop reads them | Action needed | Refuse a committing records write whose target checkout is a main checkout or on the default branch, in `records_path`'s file (the one place), judged on the target (`-C`), not on cwd. Cover `progress_append.sh` and `persist` in compatibility mode, not only `--strict`. |
| Only what's needed | Action needed | Extend #429's gate with a second rule; do not add a new script or a second path-resolution mechanism. |
| Test what you ship | Action needed | Script tests for the cases the issue lists, plus the legitimate outside-worktree writer: `merge_pr.sh`'s `-C <worktree>` record from the root must still commit on the feature branch. |
| Keep one current design | Watch | One-line edit to the records-gate paragraph #429 adds to `docs/design.md`; also `script_reference.md` and the exit-code comments. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0013 progress.md entry types | Yes | Writers stay the only appenders; the fixed commit message and validation are unchanged. |
| 0012 package worktrees | Yes | #429's manifest guard; the new rule must not break the package-checkout case it allows. |
| 0016 user tier | Watch | `_resolve_work_plans_dir.sh` is "inert"; keep the new function inert (no repo-affecting action). |

### Consequences

- `docs/design.md` records-gate paragraph, `script_reference.md`, header exit-code lists of `progress_append.sh` and `review_progress.sh` (exit 4 meaning).
- Skills that show `[--strict]` as optional (plan-task, review-code, triage-reviews, address-findings) stay valid because compatibility mode now refuses too.
- `run-issue`'s statement that persistence "refuses outside the worktree" becomes true for every mode.

### Recommendations

- Make this one small pull request, branched from #429's branch with `--parent-issue 429`; retarget to main after #429 merges.
- Put the rule in `_resolve_work_plans_dir.sh` beside `records_path`: refuse a committing write when the target's toplevel is a main checkout (git dir equals the common dir) or its branch is the default branch; name the issue's worktree if one exists, else the `worktree_create.sh` command.
- Judge the `-C` target, so `merge_pr.sh`'s gate record (progress_append -C <worktree>) keeps working; add that case to the tests.
- Leave reads unguarded; decide in the plan whether `review_progress.sh check` (writes, no commit) follows the write rule.
- Tests: main checkout, package checkout under a project root, another issue's worktree, a workspace and a project issue, and compatibility mode (not just `--strict`).
- Decide in the plan what a detached HEAD or a skill worktree (`skill/*`, no issue) does; persist already skips an empty issue.
