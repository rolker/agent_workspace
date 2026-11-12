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

## Checkpoint
**Status**: complete
**When**: 2026-11-10 13:30 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review ran both versions of the rule in a sandbox and found the plan's rule broader than the harm; two must-fixes, both mechanism; first host revise on this plan)
**After**: plan
**Decision**: revise

Host read the Plan Review (needs-work, 2 must-fix, 8 suggestions) and directs, taking every item as the review words it:
- The smaller rule: a committing write is allowed when the target checkout's branch is `feature/issue-N` (never the default branch) or, for a detached HEAD or a custom branch name, its folder is `issue-*-N`; when the branch names an issue the branch decides. The linked-worktree condition is dropped: whether a main checkout on a feature branch should be refused is a separate convention question, not this issue's harm, and is listed for the owner as such. The issue 20 folder on an issue 21 branch case is refused and tested.
- The caller's flag stays opt-in and is named `--write`; the check that no writer forgets it is a static test over every script under `.agent/scripts` that commits a work-plans path, not a list of subcommands.
- The four skills that describe compatibility mode as "commit after the notice" are corrected. The plan says plainly, for the owner's veto, that compatibility mode becomes strict except when `WORKTREE_ISSUE` names another issue or the override is set, so the notices issue 269's parked strict-mode item waits for will stop because those cases now refuse; strict mode is not flipped here.
- One shared helper for the branch-and-folder match, used by the resolver's existing rule too. Only `test_progress_append` needs a new fixture. Serves names the README goal. The line the plan meant to edit in docs/design.md does not exist; drop that edit.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 13:31 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-437/plan.md` at `e1ce8571`

Revision 2 after the needs-work plan review and the host checkpoint. The rule is smaller: a write that changes a timeline (`--write`) is allowed when the target's branch is `feature/issue-N` (never the default branch), or, for a detached HEAD or a custom branch, its folder is `issue-*-N`; the branch decides when it names an issue. No linked-worktree condition. One shared helper, also used by resolver rule 2b. A static test fails when a script commits a work-plans path without the flag. Four skill texts and issue 269's parked item are corrected; strict mode is not flipped. The main-checkout-on-a-feature-branch question is listed for the owner as separate.

## Plan Review
**Status**: complete
**When**: 2026-11-10 13:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready
**Dispatch**: resumed (agent abff219562205b052, resume 1 of 3)

**Issue**: #437 — A records write from outside any issue worktree commits onto that checkout's main branch, silently
**Plan**: `.agent/work-plans/issue-437/plan.md` at `e1ce8571`
**Branch**: `feature/issue-437`
**Serves**: Goal "Trust, control and information" (README, workspace goals); design `docs/design.md#worktrees` (the Records bullet) and `docs/design.md#rules`

Second review of the plan (revision 2), narrow: whether the first review's items are resolved as worded, and whether the revision introduced anything wrong.

### What was run

I re-ran the sandbox from the first review (a clone of issue 429's branch at e8205e67 in the session scratchpad) with the revised rule sketched as the plan words it. A write is refused on the default branch. When the branch is `feature/issue-M`, the branch decides (M must equal N). Otherwise the folder decides (`issue-*-N`). The helper has no linked-worktree condition and no manifest shortcut. Resolver rule 2b goes through the same helper, and `check` takes the flag.

- **Edge cases:** 25 of the 26 come out as wanted. The case the first review found open, folder 20 on branch `feature/issue-21` writing issue 20, is now refused. The 26th case is the main checkout on a feature branch, which is allowed. That matches the plan, which lists it for the owner as a separate convention question.
- **The plan's ten suites:** the only failures are the ones step 7(c) names: `test_progress_append`'s fixture (20 assertions, from one fixture on `main`), and four flips (the compatibility mismatch case in plan_correlation, review_code_convergence and triage_reviews_integration, and package_issue_loop's "check from WS ticks its own box"). `test_resolve_work_plans_dir` stays at 21 of 21 with rule 2b through the helper. dispatch_phase, merge_pr_gate and issue_review_entry are unchanged.
- **The manifest shortcut:** an earlier sketch put a manifest pass-through inside the helper. Rule 2b then accepted a package sibling, and the refusal came from the 429 guard with a different message. The plan's helper as worded (no shortcut) does not do that.

### Items from the first review

| Item | Resolved as worded? |
|---|---|
| Must-fix 1: drop the linked-worktree condition | Yes (steps 3, Prior Art) |
| Must-fix 2: static test for a committing writer without the flag | Yes (step 7b) |
| Four skill texts on compatibility mode | Yes (step 8) |
| B2 note to issue 269, not design.md; compatibility now equals strict except two cases | Yes in substance; see finding 1 on who posts it |
| Branch decides over folder; 20/21 case tested | Yes (steps 3, 7a) |
| Flag named `--write`; `check` under it | Yes (steps 2, 5) |
| One helper shared with rule 2b | Yes (step 3) |
| Serves names the README goal | Yes |
| Line ranges, unaffected suites, renumbering 42 and 55 | Yes (steps 1, 7c) |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One pull request: three scripts, one new suite, one fixture, four flips, four skill passages, docs |
| Issue alignment | Good | Every listed case is tested; the legitimate root writer is a must-succeed case |
| File targeting | Good | Skill passages added |
| Consequences | Good | Issue 269 item, skills, flipped tests all listed |
| Principle alignment | Good | Smaller rule; static enforcement for the opt-in flag |
| ADR compliance | Good | 0013, 0012, 0016 as before |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Consequences]** Step 8's "a comment on issue 269's parked strict-mode item" reads as the implementer posting it. A comment on another issue is the owner's to allow. Say that the implementer drafts the comment's text (in the PR description or the Implementation entry) for the host to put to the owner, and does not post it.
2. **[Approach]** Dependency on issue 429's fix pass, now uncommitted in that worktree. It changes `records_path` to judge two locations: the path as named and its physical resolution, each through `_wpd_existing_dir`, with the issue number taken from both. The plan's step 4 ("the toplevel of the nearest existing ancestor of the path") depends on that path-matching part, not on the fallback to the current folder; the plan never uses `$PWD`. At implementation, the write rule judges the checkout where the commit runs (the named location's toplevel, which is where `progress_append.sh` runs `git commit`), and the physical one too if it differs. Step 1 already says to re-check.
3. **[Approach]** Step 7(b) asks for a pathspec "through a variable such as `$file_rel`". Grep cannot follow that in general, and several read-only scripts contain both "commit" and "work-plans" (`merge_pr.sh`, `dispatch_phase.sh`). The implementer pins the detection rule down: a `git … commit … -- "$VAR"` whose variable is assigned a string containing `.agent/work-plans`. A test-fixture case proves that the detector catches a planted writer.
4. **[Approach]** The helper carries no manifest shortcut: the manifest guard runs before it in `records_path`, and rule 2b calls it bare (sandbox above).

### Summary

Both must-fixes and all eight suggestions are resolved as worded. The revised rule, run in the sandbox, closes every reproduced case and the folder/branch hole, with only the planned test edits. The plan is ready to implement once issue 429's first pull request has merged. The four findings are notes the implementer can simply be told.

### Recommended Actions

- [ ] (suggestion) Draft the issue 269 comment for the host to put to the owner; do not post it
- [ ] (suggestion) Re-anchor step 4's target on 429's final two-location `records_path`: judge the checkout where the commit runs, and the physical one if it differs
- [ ] (suggestion) Pin down the static test's detection rule and prove it catches a planted writer
- [ ] (suggestion) Keep the manifest shortcut out of the shared helper

## Checkpoint
**Status**: complete
**When**: 2026-11-10 13:41 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second plan review: ready, nothing open that needs another plan round)
**After**: plan
**Decision**: proceed

Host read the second Plan Review (ready). Carried to the implementer: the comment on issue 269's parked strict-mode item is drafted as text for the host to put to the owner, not posted; the rule judges the checkout where the commit runs, plus the physical one when a symlink makes them differ; the static test says exactly how it finds a committing writer; the package-manifest shortcut stays out of the shared helper. Implementation is NOT dispatched yet: it starts only after issue 429's first pull request has merged and main is merged into this branch, as the plan's step 1 says.

## Implementation
**Status**: complete
**When**: 2026-11-12 11:45 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-437 at `d9c473a5`

This pass finished the implementation stopped on 2026-11-10. It checked the three earlier commits against the plan step by step and found nothing missing or wrong, so it added no code:
- Step 1: issue 429's first pull request (PR 445) is merged and main is merged into this branch (`3dafaec6`).
- Steps 2 to 6 (`cf199ef2`): `records_path` and `records_dir` take `--write`. The shared helper `_wpd_checkout_is_issue` refuses the default branch. On `feature/issue-M` the branch decides; for a detached HEAD or another branch name the folder `issue-*-N` decides. It has no manifest shortcut, and resolver rule 2b calls it. The write rule judges the checkout where the commit runs, and also the physical one when a symlink makes them differ. A refusal names the issue's worktree or the `worktree_create.sh` command that creates it. `progress_append.sh`, compatibility `persist` and `check` pass `--write`. Strict `persist` keeps `progress_append.sh`'s exit 4. The notice and the headers are updated.
- Step 7 (`a06e79c0`, plus the test edits in `cf199ef2`): new suite `test_records_write_gate.sh` (45 assertions) with every refusal and allowed case the plan lists, including issue 20 in a folder on branch `feature/issue-21` and a symlinked records folder. Its static test is pinned down in the suite's comment, and planted scripts prove that it catches a writer without the flag. `test_progress_append` now uses a `feature/issue-7` fixture, and its other-issue cases switch branch. The four intended flips are made.
- Step 8 (`d9c473a5`): the design.md Records bullet and a change-log row (cited line numbers checked against the current tree), the three script_reference rows, and the four skill passages.

Checks: the main checkout's venv `pre-commit run --files $(git diff --name-only main...HEAD)`, with no SKIP, ran all 46 suites (the branch touches the shared helper `_resolve_work_plans_dir.sh`). The first run failed one assertion in `test_sitrep_checks` ("(skill 1) TERM: rc=143 took=0s alive=yes"), a kill-timing case. That suite references none of the changed files, and it passed 210 of 210 twice when run alone. The same command run again on the unchanged tree passed every hook.

Draft for the host to put to the owner, not posted: a comment on issue 269's parked strict-mode item (B2):
> Issue 437 makes compatibility mode refuse exactly like strict mode whenever the checkout is not the issue's own (a main checkout on its default branch, or another issue's worktree). The "would have aborted" notice is now left for two cases only: `WORKTREE_ISSUE` names another issue while the checkout is right, or `WORK_PLANS_DIR_OVERRIDE` is set. So when the notices stop, the reason is that these cases now refuse, not that runs got cleaner. Strict mode is not flipped by 437, and B2 stays the owner's call. To undo: drop `--write` from the compatibility branch of `review_progress.sh` `_persist_impl`.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 11:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-437 at `46d8f462`
**Base**: main
**Depth**: Deep (reason: 1118 changed lines across 17 files, including the enforcement scripts `_resolve_work_plans_dir.sh`, `progress_append.sh` and `review_progress.sh` and four skill files)
**Must-fix**: 1 | **Suggestions**: 1
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) The write rule misses two symlink cases and writes into the main checkout (reproduced in a sandbox): a `progress.md` that is itself a symlink to the main checkout's (`progress_append.sh` exits 0, edits main's file, commits a mode change in the worktree; compatibility `persist` is not refused either), and a records folder linked to a main-checkout directory whose path does not name the issue (`rn` empty, so the physical check is skipped; file written, then git fails with exit 3). Judge the physical checkout with `${rn:-$gn}` whenever it differs, gate the file path itself (`records_path --write "$RECORDS/progress.md"`) in `progress_append.sh` and compatibility `persist`, and add both cases to `test_records_write_gate.sh` — `.agent/scripts/_resolve_work_plans_dir.sh:420`, `.agent/scripts/progress_append.sh:94`, `.agent/scripts/review_progress.sh:341`
- [x] (suggestion) The static detector reads a pathspec only after ` -- `, so `git add "$REL"` / `git commit -m x "$REL"` without `--` is not caught; take the words after the subcommand's options too, or say so in the "Out of reach" comment, and plant such a writer — `.agent/scripts/tests/test_records_write_gate.sh:313`

## Implementation
**Status**: complete
**When**: 2026-11-12 12:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-437 at `fbe60ca5`
**Addressed**: Local Review (Pre-Push) at `46d8f462` (2026-11-12 11:50 -05:00)
**Commits**: `1bb30442`, `fbe60ca5`

### Actions
- [x] (must-fix) The write rule is now one statement in `records_path --write`: the file that will be written, every symlink in its path and the file itself resolved (a dangling one refuses), sits at the place its path names in the issue's own checkout. Every writer passes the file itself (`progress_append.sh`, compatibility `persist`; `records_dir` loses `--write`). Tested for both writers: file symlink, folder symlink to a folder named for the issue, folder symlink to one not named, a chain of two, a link inside the issue's own records folder, a dangling link, and the plain case still commits; the new cases fail on the pre-fix scripts (11 failures) — `.agent/scripts/_resolve_work_plans_dir.sh:412`, `.agent/scripts/progress_append.sh:94`, `.agent/scripts/review_progress.sh:341`, `.agent/scripts/tests/test_records_write_gate.sh:241`
- [x] (suggestion) The static detector reads a pathspec with no ` -- ` as every word after the subcommand up to the end of the command; planted `rogue_nodash.sh` (`git add "$REL"` / `git commit -m x "$REL"`) is caught — `.agent/scripts/tests/test_records_write_gate.sh:313`

### Checks
- `test_records_write_gate.sh`: 58 passed, 0 failed
- `pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: exit 0, every hook passed or skipped, the script suite included

### Notes
- Beyond the two findings' text, the one-statement rule also refuses a symlink inside the issue's own checkout (progress.md linked to another file in its records folder) and the dangling case: without the "at the place its path names" clause such a write exits 0 with the entry left uncommitted, because git commits the unchanged link.
- `docs/design.md`: the Records sentence states the rule, the `progress_append.sh` gate lines are refreshed (93-94), and a change-log row is added (903 lines).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 12:15 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a9583ba7b1d7c0446, resume 1 of 3)

**Branch**: feature/issue-437 at `0ea9b4c4`
**Base**: main
**Depth**: Deep (reason: whole-branch diff over 200 lines across 17 files, enforcement scripts and four skill files; fix round 2 classified on the whole diff)
**Must-fix**: 1 | **Suggestions**: 2
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 1), not rising — fix and ship rather than another full round

Round 1's two findings are resolved: the symlink rule is one statement in `records_path --write` on the file itself, and the static detector reads a pathspec without ` -- `. The "at the place its path names" clause is kept: it turns a silent exit-0 write that never reaches a commit into a clear refusal, and the adversarial pass found no false refusal for a worktree reached through a symlinked ancestor, a relative or `..` path, a first entry, or `-C` through a link.

### Findings
- [x] (must-fix) The place comparison is textual, so a harmless spelling refuses a valid write in the issue's own checkout (reproduced: `records_path --write .agent/work-plans/issue-437/./progress.md` and `.../issue-437//progress.md` return 1, the plain spelling 0; `review_progress.sh check --progress "$dir/progress.md"` with a trailing slash on `$dir` would exit 4). Normalise `//` and `/./` in the named tail before comparing, keeping real symlink redirection refused, and add both spellings to `test_records_write_gate.sh` — `.agent/scripts/_resolve_work_plans_dir.sh:425`
- [x] (suggestion) The place clause runs only when the path names `.agent/work-plans/issue-<N>` (`gn` set): `check --progress progress.md` run inside the records folder, with `progress.md` linked to another file there, passes. Either refuse `--write` on a path that does not name the records folder, or judge the place from the resolved folder; add the case — `.agent/scripts/_resolve_work_plans_dir.sh:424`
- [x] (suggestion) The exit-code comment still says "records_dir in _resolve_work_plans_dir.sh names the right one"; the script now calls `records_path --write` — `.agent/scripts/progress_append.sh:39`

## Implementation
**Status**: complete
**When**: 2026-11-12 12:30 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a71730de86d9f7a22, resume 1 of 3)

**Branch**: feature/issue-437 at `c0e92c0a`
**Addressed**: Local Review (Pre-Push) at `0ea9b4c4` (2026-11-12 12:15 -05:00)
**Commits**: `f7abbdda`, `c0e92c0a`

### Actions
- [x] (must-fix) The place clause now compares two paths computed the same way, not text: the named path made absolute and lexically normalised (`_wpd_lexical`, no symlink resolved) and the fully resolved path; below the checkout root they must be equal and the named part above must resolve to that root. `./`, `//`, a trailing slash on the folder (through `check --progress`) and a `..` landing on the same file are allowed; a worktree through a linked parent folder and `-C` through that link from the main checkout still pass — `.agent/scripts/_resolve_work_plans_dir.sh:444`, `.agent/scripts/tests/test_records_write_gate.sh` case 6b
- [x] (suggestion) The same comparison runs for every `--write`, whether or not the path's text names the records folder: a bare `progress.md` inside the folder is allowed plain and refused when linked to another file there (`check` exits 4, the target unchanged) — `.agent/scripts/_resolve_work_plans_dir.sh:444`, `.agent/scripts/tests/test_records_write_gate.sh` case 6b
- [x] (suggestion) The exit-code comment names `records_path --write` and the symlink refusal; line count kept so the design doc's cited lines 93-94 and 107-108 hold — `.agent/scripts/progress_append.sh:39`

### Checks
- `test_records_write_gate.sh`: 68 passed, 0 failed; against the round-2 scripts the same test fails 6 (the four spellings, the trailing slash, the linked bare `progress.md`)
- `pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: exit 0, every hook passed or skipped, the script suite included

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 12:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a9583ba7b1d7c0446, resume 2 of 3)

**Branch**: feature/issue-437 at `8d9c33bb`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Narrow check of round 2's three findings and the fix diff `39b6562e..8d9c33bb`; cross-model skipped (round-3 convergence check, per handoff). All three are closed: the place check now compares the named path (absolute, normalised by text) with the same path fully resolved, for every `--write`; `./`, `//`, a trailing slash, a `..` landing on the same file and a bare `progress.md` in the records folder pass, a link to another file there is refused; the exit-code comment names `records_path --write`. A fresh adversarial pass re-ran every round 2 allowed case (symlinked parent folder, cwd through a link, `-C` through a link from the main checkout, first entry) and every refusal; all hold. Nine suites pass (test_records_write_gate 68/68).

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 12:36 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 approved with no open finding; both earlier must-fixes are fixed and re-checked; nothing in the review needs the owner before the hosted reviews)
**After**: publish
**Decision**: publish

The host read the round 3 Local Review (Pre-Push) entry at f11fb65a: verdict approved, Ship recommended, no open findings. The merge stays the owner's.

## Integrated Review
**Status**: complete
**When**: 2026-11-12 12:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #448 at `917d7ef`
**Sources**: 2 (Local Review (Pre-Push) R3 @ `8d9c33b` (covers `917d7ef` via bookkeeping), CI rollup); Copilot: failed (quota, "insufficient remaining quota", no review content); no human review requested
**Cross-source confirmations**: 0
**CI**: pending

Round 3 (approved, Must-fix 0, Suggestions 0) is the only local review covering the head; the head differs from it only by this issue's `progress.md` (two progress commits). Rounds 1 (`46d8f46`) and 2 (`0ea9b4c`) are older code: their one must-fix and two suggestions each are ticked, and their Implementation entries (`fbe60ca`, `c0e92c0`) and round 3 re-checked every one; nothing from them is re-listed. The `sources` helper returns round 3's "- [ ] No issues found. LGTM." placeholder as an unchecked item; it is not a finding. GitHub carries no inline or conversation comments. CI at `917d7ef`: Validate Adapter Contract, Validate Documentation and ros-manifest tests pass (both runs); Lint (pre-commit) still pending in both runs at 12:38; the copilot-pull-request-reviewer check failed on the quota, not on the code.

### Findings
None open.

### False positives
None.
