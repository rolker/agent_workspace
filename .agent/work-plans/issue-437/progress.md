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

## Checkpoint
**Status**: complete
**When**: 2026-11-10 13:07 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review keeps the issue's scope: one small pull request that guards committing writes; its two open details are mechanism for the plan)
**After**: issue-actions
**Decision**: proceed

Host read the Issue Review. Accepted as plan inputs: the guard goes on committing writes only, never on reads (the sit-rep and the dispatcher read from the root on purpose); it judges the target checkout (the `-C` directory), not the current directory, so the merge script's gate record keeps working; it is a second rule in the one place issue 429's first pull request resolves records paths, not a second mechanism. The plan settles what a detached HEAD and a skill worktree do, and whether `review_progress.sh check` follows the write rule. Sequencing, a host decision listed for the owner's veto: this worktree stays on main; the plan and its review are done now against issue 429's branch as read, and implementation starts only after issue 429's first pull request merges and main is merged into this branch, so no branch is stacked on an unmerged one.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 13:20 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-437/plan.md` at `4424c221`

Written against issue 429's branch, not this tree; implementation waits for its first pull request to merge. A second rule in `records_path`/`records_dir`, switched on by a caller-stated `--commit` option, refuses a committing write whose target checkout is not the issue's worktree (linked worktree on `feature/issue-N`, or the manifest's entry for package issues); reads never refused.

Settled with evidence (read from the 429 branch, not run):
- Detached HEAD: allowed only in a worktree whose folder is `issue-*-N`; refused elsewhere.
- `skill/*` worktrees: refused when given an issue; none writes a timeline (`persist --issue ""` skips; research and inspiration-tracker call no progress script).
- `review_progress.sh check`: edits without committing, but a tick left in a main checkout is stranded; it follows the write rule (`records_path --commit`).
- Compatibility `persist`: the new refusal precedes the "would have aborted" notice; the notice survives only for a set `$WORKTREE_ISSUE` that differs while cwd is right. Issue 269's parked item (docs/design.md: "B2: flip `PROGRESS_PERSISTENCE_STRICT` to 1 once the compatibility-mode 'would have aborted' notices stop showing up on real runs") is not decided here; its signal narrows, noted in design.md.
- `merge_pr.sh` gate record (`progress_append.sh -C <PR worktree>` from the root) judges the target and passes; tested.
- `cross_model_review.sh --work-plans-dir`: no `--commit`, writes uncommitted artifacts, unchanged.

Details for the owner's veto (undo cost):
- Option `--commit` as the intent signal (swap for another signal: edit 4 call sites).
- Non-package targets must be a linked worktree (drop one condition; a main checkout on a feature branch then passes).
- `check` follows the write rule (remove one flag).
- About ten suites' plain-main fixtures move to linked worktrees (the largest cost; not undoable cheaply once written).

## Plan Review
**Status**: complete
**When**: 2026-11-10 13:29 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #437 — A records write from outside any issue worktree commits onto that checkout's main branch, silently
**Plan**: `.agent/work-plans/issue-437/plan.md` at `4424c221`
**Branch**: `feature/issue-437`

### What was run

A clone of issue 429's branch (`feature/issue-429` at e8205e67) in the session scratchpad, with the rule sketched in `_resolve_work_plans_dir.sh` (about 30 lines: `--commit` on `records_path`/`records_dir`, called from `progress_append.sh`, the compatibility `persist` branch and `check`; the strict branch propagates exit 4). Two variants: **plan** (the plan's rule 3b: linked worktree, not the default branch, branch `feature/issue-N` or folder `issue-*-N`) and **smaller** (the same without the linked-worktree condition). Baseline: the plan's ten suites pass on the 429 copy (548 assertions).

- 26-case edge matrix, both variants: all reproduced cases refuse (main checkout on `main` via `progress_append`, compatibility `persist` and `--strict`; `-C <main>` from inside the issue's worktree; a package clone under a project root on `main`), and nothing is committed. Allowed in both: the issue's worktree, the merge script's `-C <worktree>` write from the root, a `--parent-issue` sub-issue worktree for its own number (its parent's number refused), a single-repository project worktree, a custom `--branch` in an `issue-*-N` folder, a detached HEAD in an `issue-*-N` folder, the owning checkout of a package worktree (full clone; sibling refused by 429's guard). Refused in both: issue 7 from the issue-17 worktree, 17 from issue-7's, 1 from issue-17's (no suffix match), a detached HEAD in a folder of another name, `check` on the main checkout's timeline. Reads from the root still pass.
- They differ on one case only: a plain checkout on `feature/issue-7` that is not a linked worktree (a main checkout on a feature branch). The plan refuses it; the smaller rule allows it.
- One hole in both: a folder `issue-workspace-20` on branch `feature/issue-21` lets issue 20's entry commit onto issue 21's branch (the folder alone passes).
- Suites under the plan's rule: 6 of the 10 fail, 43 assertions (address_findings 7, plan_correlation 6, progress_append 20, review_code_convergence 6, triage_reviews_integration 3, package_issue_loop 1); dispatch_phase, merge_pr_gate, resolve_work_plans_dir and issue_review_entry pass unchanged. Under the smaller rule: test_progress_append (its `main` fixture; with `init -b feature/issue-7` 5 cases remain, all using another issue number: 8, 9, 42, 55) plus 4 deliberate flips: the "persist compat in a mismatched worktree commits with a notice" case in plan_correlation, review_code_convergence and triage_reviews_integration, and package_issue_loop's "check from WS ticks its own box".

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | One pull request is right. The fixture moves in step 6 come from the linked-worktree condition, not from the issue; without it the test churn is one suite plus four intended assertion flips |
| Issue alignment | Good | Every case the issue lists is covered and refuses (run). Serves as checked: "Leave a trail that is where the loop reads it (README workspace goals); `docs/design.md#rules` (start limits strict) and the Records bullet of `docs/design.md#worktrees`". "Leave a trail" is a principle, not a README goal section; the goal is "Trust, control and information" |
| File targeting | Needs work | Four skills describe compatibility mode as "inline commit in the current worktree after the notice", which stops being true: plan-task SKILL.md 284-292, review-code 725-736, triage-reviews 372-381, address-findings around 202 (line numbers on the 429 branch). Not in the plan |
| Consequences | Needs work | The "B2 line in design.md" does not exist: `grep` finds neither "B2", "PERSISTENCE_STRICT" nor "compatibility" in `docs/design.md` on main or on the 429 branch. B2 is in issue 269's comment ("flip `PROGRESS_PERSISTENCE_STRICT` to 1 once the compatibility-mode 'would have aborted' notices stop showing up on real runs") |
| Principle alignment | Needs work | Only what's needed: the linked-worktree condition goes past the issue's harm. Enforce what matters: the opt-in flag needs a check that fails when a committing writer is added without it; case 8's table enumerates only `review_progress.sh` subcommands |
| ADR compliance | Good | 0013 (writers unchanged), 0012 (manifest case: the owning checkout is on `feature/issue-N`, so the smaller rule needs no package carve-out at all), 0016 (file stays inert) |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Principle alignment, must-fix]** Drop the linked-worktree condition from rule 3b. Allow when the target is not on its default branch and its branch is `feature/issue-N[-desc]`, or its folder is `issue-*-N` (detached HEAD or a custom branch). It closes every reproduced case (run) and removes the fixture moves (43 failing assertions in 6 suites become one fixture plus 4 intended flips). It also keeps the commit gate in agreement with the resolver: rule 2b accepts a main checkout on `feature/issue-N` today, so strict `persist` would pass the resolver and then be refused by `progress_append.sh`. Refusing a main checkout on a feature branch is a convention (AGENTS.md "never edit files in the main tree"), not this issue's harm (the commit lands on the issue's branch), and for projects it forces a workflow the owner wants only encouraged. If wanted, it is a separate question for the owner.
2. **[Principle alignment, must-fix]** Make the flag's enforcement concrete. Keep the opt-in `--commit` and don't default to refusing. Only two places in `.agent/scripts` commit a timeline (`progress_append.sh`, and `review_progress.sh` line 355 in the compatibility branch; grep of every script that commits and names work-plans). ADR-0013 sends new writers through `progress_append.sh`, which carries the flag. Defaulting to refusal would need about a dozen read call sites flagged, and a missed one breaks the dispatcher and the sit-rep from the root. A writer that skips `records_*` is unguarded under either default. The plan's "add the `--commit` enumeration to case 8" does not catch a new script. Add a static test: every `git … commit` in `.agent/scripts/*.sh` whose pathspec is under `.agent/work-plans/` sits in a script that calls `records_dir --commit` or `records_path --commit`, and the set is exactly the known two. It fails when a third committing writer appears without the flag.
3. **[Consequences]** Update the four skill texts named under File targeting. Replace the design.md B2 target with a comment on issue 269's parked item. After this change, compatibility mode differs from strict only when `$WORKTREE_ISSUE` names another issue while the cwd is right, and under `WORK_PLANS_DIR_OVERRIDE`. So the notices B2 waits for stop because those cases now refuse, not because runs got cleaner. Say that plainly for the owner's veto; do not flip here.
4. **[Approach]** Folder and branch disagreeing: when the branch is `feature/issue-M`, the branch decides and the folder is not consulted. The folder decides only for a detached HEAD or a branch not of that shape. Run: `issue-workspace-20` on `feature/issue-21` currently lets issue 20 commit onto 21's branch.
5. **[Approach]** `check` following the write rule is right: no caller ticks from the root (address-findings runs in the worktree; run-issue's host passes `dispatch_phase.sh where`'s worktree), and a tick left in a main checkout is a stranded, dirty edit. It flips 429's "check from WS ticks its own box". Call the flag `--write` (the call changes the timeline), not `--commit`, since `check` commits nothing.
6. **[Approach]** Rule 2b's branch and folder match and the new rule are the same test, judged on cwd and on the target. Put it in one helper both call, so they cannot drift.
7. **[File targeting]** Step 1's line ranges are already off at e8205e67 (`records_path` is 193-212, `records_dir` 214-225, `issue_checkout_guard` 159-191). Step 6's list names four suites that need nothing even under the plan's rule. The commit gate runs before entry validation, so test_progress_append's validation cases on issues 42 and 55 return 4, not 2; renumber them.

### Summary

The plan finds the right place, the right callers and every legitimate root writer, and the rule closes every reproduced case (run). Its linked-worktree condition is the one part that is too broad: it is the source of the large fixture move and it disagrees with the resolver's own rule. Drop it, make the flag's enforcement test concrete, and fix the consequence targets. Then it is one small pull request.

### Recommended Actions

- [ ] (must-fix) Drop the linked-worktree condition; allow on branch `feature/issue-N[-desc]` (never the default branch) or folder `issue-*-N`; shrink step 6 to test_progress_append plus the four intended flips
- [ ] (must-fix) Replace "add `--commit` to case 8" with a static test over `.agent/scripts` that fails when a script commits a work-plans path without `records_* --commit`
- [ ] (suggestion) Add the four skill texts on compatibility mode to the plan; move the B2 note from design.md (no such line) to issue 269's parked item, stating that compatibility now equals strict except for the `$WORKTREE_ISSUE` mismatch and the override
- [ ] (suggestion) Branch decides when it is `feature/issue-M`; folder only for detached HEAD or a custom branch; test the 20/21 case
- [ ] (suggestion) Name the flag `--write`; keep `check` under it
- [ ] (suggestion) One helper for the branch and folder match, shared with resolver rule 2b
- [ ] (suggestion) Serves: name the README goal section ("Trust, control and information"), not the principle
- [ ] (suggestion) Refresh step 1's line ranges; drop the four unaffected suites from step 6; renumber the issue 42 and 55 cases in test_progress_append
