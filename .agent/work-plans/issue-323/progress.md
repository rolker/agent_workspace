---
issue: 323
---

# Issue #323 — Small tooling fixes

## Issue Review
**Status**: complete
**When**: 2026-11-02 11:53 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #323

### Scope Assessment

**Well-scoped?** Yes — three independent small fixes, already specified as three atomic commits each with its test. Checked today against the tree: none has landed (`worktree_create.sh` still runs `git worktree add -b` from current HEAD in its no-parent branch; `gh_create_issue.sh` has no signature code; `_bookkeeping.sh` still prints "which is not a merge-time document file").
**Right repo?** Yes — all three are workspace scripts.
**Serves**: Quality of the work (worktree base, merge-line wording) and Trust, control and information (agent-created issues carry who wrote them) — `docs/design.md#worktrees`, `docs/design.md#merge-gate`, `docs/design.md#identity`
**Design picture?** No change — item 1 restores the intent of the Worktrees section; item 3 keeps the "one rule in `_bookkeeping.sh`" statement in Merge gate true. If item 3 is solved by folding patterns into Step 2, the design text stays as written.
**Dependencies**: none identified. Item 1 touches the `--parent-issue` path, so it should not disturb sub-issue worktrees.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | Action needed | The issue names `test_worktree_create*.sh`, but no such suite exists (tests mentioning `worktree_create` only use it as a fixture), and there is no `gh_create_issue` suite either. Create both, and make each new test fail without its fix. |
| Small steps; step back when they stop converging | Watch | Three commits in one PR is fine; keep them separable so a review round on one does not hold the others. |
| A change includes its consequences | Watch | Item 3 changes a printed line; check the existing `test_merge_pr_gate.sh` fixtures and any doc quoting the old wording. Item 1 changes where new branches start: `.agent/WORKTREE_GUIDE.md` should say so if it describes the base. |
| Leave a trail; start limits strict | Watch | Item 2 should follow `gh_create_pr.sh` exactly, including the hard-fail when identity is unset and a body is given, so no unsigned issue slips through. |
| Put each thing at the level it applies to | OK | Item 1 uses `_resolve_default_branch.sh`, with no project names. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0002 — Worktree isolation | Yes (item 1) | Worktree creation behaviour. |
| 0012 — Worktree composition is an adapter concern | Yes (item 1) | Keep the base-branch change in the generic path and loop over the `.worktree-repos` manifest, with no project-type checks. For project worktrees, resolve the default branch per repo. |
| 0013 — progress.md vocabulary | No | |

### Consequences

- `.agent/WORKTREE_GUIDE.md` and the AGENTS.md worktree text, if they state the base branch.
- Script table row for `gh_create_issue.sh` in AGENTS.md should mention the signature and `--no-signature`.
- Any callers that pass a body to `gh_create_issue.sh` without identity set will now hard-fail; grep skills and scripts for them.

### Recommendations

- Decide the item 3 variant before planning: folding the bookkeeping patterns into Step 2 is preferred, since it leaves one rule (matching the Merge gate design text) instead of a reworded message over two.
- For item 1, define the behaviour when `origin/<default>` is unreachable (offline): fall back to the local default branch with a printed warning, never silently to HEAD. For issue worktrees, state in the plan whether `--parent-issue` remains the only way to branch from a feature branch.
- Item 2 recently recurred (workspace issue 415, "onboard-project fixes from the first real onboarding run", was signed by hand with `gh issue edit`); consider doing it first.

## Plan Authored
**Status**: complete
**When**: 2026-11-02 11:55 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-323/plan.md` at `6e68df19`

Three atomic commits in the host order: issue wrapper signature (new suite), worktree start point from origin default with local-default fallback warning (new suite), Step 2 bookkeeping set folded in (gate fixture). Walk-back kept.

## Plan Review
**Status**: complete
**When**: 2026-11-02 12:01 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #323 — Small tooling fixes: skill worktrees branch from default, issue wrapper injects the AI signature, merge-script CI-target wording for host-pushed bookkeeping
**Plan**: `.agent/work-plans/issue-323/plan.md` at `6e68df19`
**Branch**: `feature/issue-323`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three separable commits, one PR; right size. |
| Issue alignment | Good | All three items and the issue review's recommendations (fold variant, offline fallback, `--parent-issue` stays the only feature-branch base, item 2 first) are addressed. Serves, as checked: "Quality of the work and Trust, control and information; `docs/design.md#worktrees`, `docs/design.md#merge-gate`, `docs/design.md#identity`" — both goals exist under README#workspace-goals, the three anchors exist. |
| File targeting | Needs work | Missing `docs/design.md` (finding 4) and three existing suites item 1 breaks (finding 5). |
| Consequences | Needs work | Review-hold SHA change from the fold not covered (finding 3); stale comments in `merge_pr.sh` (finding 8). |
| Principle alignment | Needs work | Test what breaks: the planned item-3 fixture passes against the pre-fix script (finding 1). |
| ADR compliance | Needs work | ADR-0017 is triggered (a Rules row and an Identity bullet become false) and not listed; 0002/0012 handled. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment, must-fix]** The step 6 fixture "on the ci-30 shape" does not fail without the fix. Checked by running a copy of the ci-30 fixture: its PR fixture's `headRefOid` is the post-push head, so `HEAD_REVIEWED` already includes the host's progress commit and Step 2 only sees the gate's own record push (`CI target: reviewed head 1b7cbc1 — new head 88ef8fc only touches paths this script committed itself`), then the walk-back fires. The PR 322 line appears only when gh's `headRefOid` lags origin (the host push lands after or around the read) AND the pushed path is not one this run committed. Reproduced with `headRefOid` = green plus a host `docs/roadmap.md` commit: `CI target: new head … — touches docs/roadmap.md, which is not a merge-time document file`, then the walk-back. A host progress.md push in issue 7's own dir does not reproduce under `--report-only`, because the gate's record commits the same path. Build the new fixture in the stale-`headRefOid` shape, with a path outside this run's commits (roadmap, another issue's work-plan dir, or a progress commit where the gate records nothing, e.g. the host's own approved `## Local Review` at green plus a decision summary).
2. **[Consequences, answer to the plan's open question]** The existing ci-30 fixtures (lines ~1031-1075) and ci-31d (~1124-1146) are unaffected by the fold. `HEAD_REVIEWED` is the host-pushed head there, not green, so they still go through the walk-back, and the walk-back case survives unchanged. No expectation updates are needed, so drop that part of step 6. ci-31/31b/31c also never reach Step 2's widened allowed set (Step 2 compares the head with head+gate record), so "confirm they still refuse" proves nothing about the fold. **(should-fix)** Add Step 2-level negatives in the stale shape: a code commit, code renamed into a work-plan dir, a submodule bump; each must still target the new head.
3. **[Consequences, should-fix]** The fold moves the review-hold SHA. `_ci_review_sha="$CI_TARGET_SHA"` (merge_pr.sh, CI wait) is taken from Step 2's decision. Today a host bookkeeping push makes Step 2 target `HEAD_NOW`, so the Copilot hold reads the real head (the #300 round 4 rule ci-32 pins). After the fold, Step 2 targets `HEAD_REVIEWED` and the hold reads the reviewed head, so a review still running on the real head is no longer seen in that shape. The code comment justifies the reviewed head only for this script's own push (deadlock). Decide it explicitly in the plan. Recommended: the review SHA stays `HEAD_NOW` whenever the diff holds paths this run did not commit. Add a ci-32 analogue in the stale shape.
4. **[Consequences / ADR-0017, must-fix]** `docs/design.md#rules` row "A pull request carries the AI signature" says "Issues and comments are signed by habit only: `gh_create_issue.sh` does not add one". Item 2 makes that false. The Identity bullet names only `gh_create_pr.sh` as exiting 2 for an unsigned body. Update both, add a Change log row, and list `docs/design.md` in Files to Change. The plan's "No change to the design picture" needs this exception.
5. **[File targeting, should-fix]** Item 1 breaks existing suites that the plan does not list. `test_project_registry.sh`, `test_precommit_hook_path.sh` and `test_ros2_colcon.sh` build sandboxes from a hand-picked script copy that omits `_resolve_default_branch.sh`, so sourcing it from `_worktree_helpers.sh` or `worktree_create.sh` fails there. Separately, `test_project_registry.sh`'s `make_git_repo` creates repos with `git init` and no `-b main`, which is `master` on this git 2.43 with no `init.defaultBranch`. They have origin `file:///nonexistent/…` and no `origin/HEAD`, so `resolve_default_branch` fails and the new hard-fail breaks `test_worktree_create_skill_project` (it expects exit 0). The same applies to a real project made with `git init` + `remote add` on `master`: worktree creation would now refuse. Keep the refusal, and make its message carry the `git remote set-head origin -a` hint.
6. **[Approach, suggestion]** `git worktree add -b X <dir> origin/<default>` sets the new branch's upstream to `origin/<default>` (`branch.autoSetupMerge` default). Pass `--no-track` so the branch stays untracked until the first `push -u`, as today. `resolve_default_branch` returns a ref (`main` or `origin/main`), not a name, so strip the prefix before `git fetch origin <name>`.
7. **[Approach, should-fix]** Item 2 details:
   - `gh_create_issue.sh` ends with `exec gh issue create` (line 314), which skips the EXIT trap, so the signed temp copy (and the existing parent-ref copy) leak. `gh_create_pr.sh` dropped `exec` for exactly this (its label-validation comment), and with a TMPDIR-honouring `mktemp` the runner's leak check will fail the new suite.
   - Mirror the PR wrapper's `--body=` / `--body-file=` normalisation, missing-value errors and body-source mutual exclusion. Without them, `--body=text` is unsigned and, with identity unset, not refused.
   - Keep the signing step after `registry_require_root`: `test_user_tier_guard.sh` probes with `--title t --body b`, `AGENT_MODEL` unset, and expects "refusing to run".
   - (suggestion) `-b` / `-F` short flags are parsed by neither wrapper and so go unsigned. Handle or refuse them.
8. **[Consequences, should-fix]** Comments that state Step 2's old semantics become untrue: the `merge_pr.sh` header Steps item 2 ("only diff since then is paths this run committed itself"), the Step 2 comment ("Allowed set here is exactly what THIS run committed — narrower than the gate's") and the #300 block ("The Step 2 exemption above covers only paths THIS run committed"). Update them in commit 3.
9. **[Principle alignment, note]** The `AGENTS.md` script-table row is an instruction-file edit (Ask First). Surface it at the checkpoint unless a standing approval covers script-table rows.

### Summary

The plan is well scoped and follows the review's decisions. Its central item-3 test would pass against the unfixed script, because the ci-30 shape never puts the host's commit between `HEAD_REVIEWED` and the head. The fold also silently moves the review-hold SHA. Item 1 will break three existing suites, and item 2 makes a design.md Rules row false. Fix these in the plan before implementation.

### Recommended Actions

- [ ] Rewrite step 6: stale-`headRefOid` fixture with a path outside this run's commits, verified to print the old line pre-fix; Step 2-level negatives (code, rename into a work-plan dir, submodule); leave the existing ci-30 / ci-31d expectations as they are
- [ ] Decide and test which SHA the review hold reads after the fold (ci-32 analogue in the stale shape)
- [ ] Add `docs/design.md` (Rules row, Identity bullet, Change log row) to Files to Change; cite ADR-0017
- [ ] List `test_project_registry.sh`, `test_precommit_hook_path.sh`, `test_ros2_colcon.sh` sandbox fixes (copy `_resolve_default_branch.sh`; `-b main` or `origin/HEAD` where a worktree is expected to succeed); refusal message carries the set-head hint
- [ ] Item 2: drop the final `exec`, normalise `=` forms, missing-value and mutual-exclusion checks, sign after the root guard
- [ ] Update the three stale Step 2 comments in `merge_pr.sh`
- [ ] Use `--no-track` for the default start point; strip `origin/` before fetching

## Checkpoint
**Status**: complete
**When**: 2026-11-02 12:02 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (plan review verdict needs-work with two must-fix findings; revising the plan is a mechanism answer within /orchestrator's checkpoint table)
**After**: plan
**Decision**: revise

The plan review (0385ae95) returned needs-work: two must-fix (the new ci-30-shape fixture passes against the unfixed script and needs the lagging-headRefOid shape; docs/design.md's Rules row and Identity bullet become false under item 2 and need a Change log row), six should-fix (review-hold SHA under the fold, Step 2 negative tests, three suites that copy scripts without _resolve_default_branch.sh and registry repos on master, the issue wrapper's exec skipping the cleanup trap and its flag forms, stale merge_pr.sh comments) and suggestions. Host decisions for the revision: the Copilot review-hold check keeps reading the real pushed head, the fold changes only the CI target and Step 2's allowed set; the AGENTS.md script-table row is deferred to the owner as an Ask First edit.

### Decisions made (owner may veto)
- The review-hold SHA (Copilot still-running check) stays on the real head, not the walked-back reviewed head — undoing it: one plan line and one fixture.
- The AGENTS.md script-table row for gh_create_issue.sh is not in the plan until the owner approves that instruction-file edit — undoing it: add the row.

## Plan Authored
**Status**: complete
**When**: 2026-11-02 12:03 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-323/plan.md` at `fe16772b`

Revision after the needs-work plan review: stale-headRefOid fixture that fails pre-fix, Step 2 negatives, review-hold SHA stays the real head (ci-32 analogue), design.md Rules row/Identity bullet/Change log (ADR-0017), existing suites fixed for the default-branch helper, issue wrapper details (no exec, = forms, order after root guard), stale merge_pr.sh comments. AGENTS.md row pending owner approval.

## Plan Review
**Status**: complete
**When**: 2026-11-02 12:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #323 — Small tooling fixes: skill worktrees branch from default, issue wrapper injects the AI signature, merge-script CI-target wording for host-pushed bookkeeping
**Plan**: `.agent/work-plans/issue-323/plan.md` at `fe16772b`
**Branch**: `feature/issue-323`

Second review, of the revision after the needs-work review at `6e68df19`. Each first-round finding was checked against the revised text; the two must-fix resolutions were checked in the code.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three separable commits, one PR. |
| Issue alignment | Good | All three items covered. Serves, as checked: "Quality of the work and Trust, control and information; `docs/design.md#worktrees`, `docs/design.md#merge-gate`, `docs/design.md#identity`". Both goals and all three anchors exist. |
| File targeting | Good | `docs/design.md` and the three hand-picked-copy suites are now listed (first-round 4, 5). Minor note in finding 3. |
| Consequences | Needs work | First-round 2, 8 resolved. First-round 3 was resolved by a rule that is wrong in the stale shape (finding 1). |
| Principle alignment | Good | Test what breaks: the step 10a fixture fails before the fix and passes after it. Verified by running it (below). |
| ADR compliance | Good | ADR-0017 is now cited. Step 3 names the right rows: `docs/design.md` line 169 (Rules, "A pull request carries the AI signature … `gh_create_issue.sh` does not add one"), line 639 (Identity, "`gh_create_pr.sh` exits 2 for an unsigned body"), and the Change log. 0002/0012 handled. |
| ROS conventions | N/A | Workspace plan. |

First-round resolution: 1 resolved (verified), 2 resolved, 3 resolved as a decision but the decided rule is flawed (finding 1 below), 4 resolved (verified), 5 resolved (see finding 2), 6 resolved (`--no-track`, strip `origin/`), 7 resolved (no `exec`, `=` forms, missing-value and mutual-exclusion checks, signing after the root guard, `-b`/`-F`), 8 resolved, 9 deferred to the owner (out of scope here by instruction).

Verification of must-fix 1: a copy of the suite's helpers with `make_ci_sandbox` (so `headRefOid` = green) plus a host `docs/roadmap.md` commit pushed on top. Against the unfixed `merge_pr.sh` it prints "CI target: new head `d3895bc` — touches `docs/roadmap.md`, which is not a merge-time document file", then the walk-back. The other-issue work-plan variant (`.agent/work-plans/issue-8/progress.md`) prints the same line. With the fold simulated (the bookkeeping patterns added to Step 2's `_only_bookkeeping_between` call), both variants print "CI target: reviewed head `<green>`" and no "not a merge-time" text. A code commit (`x.sh`) still targets the new head both ways. Note that both runs merge; the observable difference is the printed line and the first "Waiting for CI on" SHA, so 10a must assert those, not the merge.

### Findings

1. **[Consequences, should-fix]** Step 8's review-hold rule keeps `_ci_review_sha` = `HEAD_NOW` "whenever the head differs from the reviewed head by paths this run did not commit". In the stale shape `HEAD_NOW` is this run's own Step 1.5 record commit, on top of the host's commit. So the rule reads the SHA the existing code comment (merge_pr.sh ~1199-1206) says must not be read: a review re-triggered by this script's own push would hold every such merge (deadlock). It also misses a review running on the host's commit. Checked on the unfixed script: stale shape, host `docs/roadmap.md` commit `243ac74` carrying a running Copilot check-run, green code head. The hold read the gate's record commit `de1dc54` and merged past the running review. This happens today, and step 8 keeps it. In ci-32 the hold reads the host's head only because there `HEAD_REVIEWED` *is* the host's head. Resolution: define the review SHA as the head before this run's own pushes, i.e. the newest commit not made by this run. For example, walk back from `HEAD_NOW` over single-parent commits whose paths are all in `_ci_committed_paths`, or capture `origin/<branch>` before Step 1 / 1.5 push. Make the 10c fixture put the running review on the host's commit, not on `HEAD_NOW`. It fails today, as shown. This keeps the owner-visible decision ("stays on the real pushed head") and drops only the deadlock.
2. **[File targeting, suggestion]** `test_issue_review_entry.sh` and `test_dispatch_phase.sh` also copy `_worktree_helpers.sh` into sandboxes without `_resolve_default_branch.sh`. If the new helper sources it when `_worktree_helpers.sh` is sourced (not when it is called), those suites can break too. Prefer sourcing it inside `_wt_default_start_point` at call time, or add both suites to step 5. Either way, run the full suite set before commit 2, not only the three named. Editing a `_*.sh` helper makes the hook run every suite anyway.
3. **[Consequences, suggestion]** Step 11 says `.agent/WORKTREE_GUIDE.md` "says new worktrees start from the default branch regardless of cwd". It does not: no line in the guide states the base, and only the `--parent-issue` section (line ~296) mentions branching. The change there is an addition, a one-line statement of the base and the offline fallback warning, not a correction. Likewise the `docs/design.md#worktrees` section never states the base, so no design row changes for item 1 (consistent with the plan's Design Picture).
4. **[Approach, suggestion]** Step 7 rewords the success line. With the fold, the old "only touches paths this script committed itself (…progress.md)" wording printed even when the host's roadmap commit was in the diff (simulated run). The 10a post-fix assertion should match the new wording, which names that the diff holds bookkeeping as well as this run's paths. Consider renaming the Rules row title from "A pull request carries the AI signature" to cover issues, since its text will now name both wrappers.

### Summary

The revision resolves the first review's findings. Both must-fix resolutions hold in the code. The stale-`headRefOid` fixture prints the PR 322 line against the unfixed script and drops it once the fold is applied. The design.md step names the Rules row at line 169, the Identity bullet at line 639 and the Change log. One structural gap is left: step 8's review-hold SHA rule reads this run's own record commit in the stale shape. That is the deadlock the code comment warns against, and it misses a review running on the host's commit, which today's script already merges past (reproduced). It is a one-paragraph amendment to step 8 and 10c. A full re-review should not be needed if only those change.

### Recommended Actions

- [ ] Step 8: review-hold SHA = the head before this run's own pushes (the newest commit not made by this run), not `HEAD_NOW`; update the code comment at ~1199 to say so
- [ ] Step 10c: put the running Copilot check-run on the host's commit in the stale shape; confirm it merges past the review on the unfixed script and holds after the fix
- [ ] Step 10a: assert the printed CI-target line and the first "Waiting for CI on" SHA (both runs merge, so the merge itself proves nothing)
- [ ] Step 2/5: source `_resolve_default_branch.sh` at call time in the helper, or add `test_issue_review_entry.sh` / `test_dispatch_phase.sh`; run every suite before commit 2
- [ ] Step 11: WORKTREE_GUIDE gains a base statement (it has none today)

## Checkpoint
**Status**: complete
**When**: 2026-11-02 12:09 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (second plan review needs-work with one should-fix on the review-hold rule; the host's own earlier decision on that rule was wrong and is reversed; second host revise in a row, so the next plan answer is the owner's)
**After**: plan
**Decision**: revise

The second plan review (4c070fb2) resolved both must-fixes and left one should-fix: holding the Copilot review-hold on HEAD_NOW is wrong in the stale shape, where HEAD_NOW is this run's own record commit, so a review still running on the host's commit is merged past (reproduced by the reviewer). Revision: hold on the head before this run's own pushes, and the ci-32 analogue puts the running review on the host commit. Suggestions to take: test_issue_review_entry.sh and test_dispatch_phase.sh also copy _worktree_helpers.sh without _resolve_default_branch.sh; WORKTREE_GUIDE.md's change is an added sentence; match the post-fix assertion to the reworded line; retitle the design Rules row. The owner approved the AGENTS.md script-table row (2026-11-02, "Yes"); it enters the plan as its own commit.

### Decisions made (owner may veto)
- Reversed: the review-hold SHA is the head before this run's own pushes (the host-pushed head), not HEAD_NOW — undoing it: one plan line and one fixture.
- The AGENTS.md row is in the plan as a separate commit, on the owner's yes — undoing it: drop that commit.

## Plan Authored
**Status**: complete
**When**: 2026-11-02 12:10 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-323/plan.md` at `a81b3bd7`

Second revision: the Copilot review-hold is now on the host-pushed head (before this run's own pushes) with the ci-32 analogue placing the running review on the host commit; five suites get the default-branch helper and the helper is sourced at call time; WORKTREE_GUIDE change is an added sentence; assertions match the reworded CI-target line and the Rules row is retitled; the owner-approved AGENTS.md row is commit 4.

## Plan Review
**Status**: complete
**When**: 2026-11-02 12:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #323 — Small tooling fixes: skill worktrees branch from default, issue wrapper injects the AI signature, merge-script CI-target wording for host-pushed bookkeeping
**Plan**: `.agent/work-plans/issue-323/plan.md` at `a81b3bd7`
**Branch**: `feature/issue-323`

Third review, narrow: only the revision for the second review (`4c070fb2`): step 8 and fixture 10c, the step 5 suites, the step 11 WORKTREE_GUIDE wording, the 10a assertion, the retitled Rules row, and step 12. Findings resolved by the first two reviews are not reopened.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four commits: three fixes, then the docs-only `AGENTS.md` row. |
| Issue alignment | Good | Serves, as checked: "Quality of the work and Trust, control and information; `docs/design.md#worktrees`, `docs/design.md#merge-gate`, `docs/design.md#identity`". Unchanged since review 2. |
| File targeting | Good | Step 5 now names `test_issue_review_entry.sh` (line 35) and `test_dispatch_phase.sh` (line 40 and others). Both copy `_worktree_helpers.sh` without `_resolve_default_branch.sh`, as the plan says. The other suites that copy the helper either already copy `_resolve_default_branch.sh` (`test_merge_pr.sh`, `test_worktree_enter_stderr.sh`, `test_merge_pr_gate.sh`) or never reach worktree creation (`test_user_tier_guard.sh` stops at the root guard). The full-suite run before commit 2 covers them. |
| Consequences | Needs work | Step 8's goal is right. One of its two named mechanisms breaks ci-32 (finding 1). |
| Principle alignment | Good | 10a now asserts the CI-target line and the first "Waiting for CI on" SHA. 10c puts the running review on the host's commit, which review 2 showed the unfixed script merges past. |
| ADR compliance | Good | ADR-0017: no other file quotes the Rules row title "A pull request carries the AI signature" (grep), so retitling breaks no reference. The `AGENTS.md` row for `gh_create_issue.sh` (line 416) has no copy anywhere else in the repo. Step 12 is the owner-approved Ask First edit, in its own commit. |
| ROS conventions | N/A | Workspace plan. |

Resolution of the second review: finding 1 (review-hold SHA) is resolved in intent, but the mechanism is open (finding 1 below). Findings 2, 3 and 4 are resolved. Step 11 now says WORKTREE_GUIDE gets an added sentence. Confirmed: the guide states no base, and only line 296 (`--parent-issue`) mentions branching.

Checked in the code. Step 1 (merge_pr.sh ~604-612) and Step 1.5 (~837-839) commit locally and push without a rebase. `_ci_committed_paths` (~984-986) holds paths, not SHAs. `_ci_wt` is resolved at ~689, after Step 1 (~549). Nothing fetches `origin/<branch>` before Step 1: `HEAD_REVIEWED` is gh's `headRefOid` (~539).

Reproduced in a scratch copy: the ci-32 fixture, plus a variant of `merge_pr.sh` that sets `_ci_review_sha` by walking back from `HEAD_NOW` over single-parent commits whose paths are all in `_ci_committed_paths`. Unfixed script: ci-32 passes, and the hold reads `031163c` (the host's checkpoint commit). Path walk-back: ci-32 fails. The walk skips this run's record commit and also skips the host's checkpoint commit, because both touch only `.agent/work-plans/issue-7/progress.md`. So the hold reads an older commit and the PR merges past the running review.

### Findings

1. **[Consequences, should-fix]** Step 8 offers two mechanisms joined by "or", and they are not equivalent. (a) The path-based walk-back cannot tell this run's commits from host commits that touch the same paths. The issue's own `progress.md` is exactly the path a host checkpoint commit touches, and `docs/roadmap.md` is the path in 10a/10c. Reproduced above: it regresses ci-32, which the plan says stays unchanged. (b) Capturing `origin/<branch>` before Step 1 needs a fetch that does not exist today, and `_ci_wt` is resolved only after Step 1. It also misses a push that lands after this run's Step 1.5 push and before Step 2 reads `HEAD_NOW`: the hold would read the pre-run head, not that push. Resolution: identify this run's commits by SHA, not by path. After each successful own push, record that commit's SHA (`git rev-parse HEAD` in `_WT_ROOT` / `_gate_wt`). Set `_ci_review_sha` by walking back from `HEAD_NOW` while the commit is in that set. That gives the host-pushed head in ci-32 and 10c, follows a later concurrent push, never reads this run's own record commit (no deadlock), and needs no new fetch or reordering. Name this one mechanism in step 8 and in the ~1199 comment. The existing ci-32 then pins the same-path case.
2. **[Consequences, suggestion]** The retitled Rules row (step 3) drops "Issues and comments are signed by habit only". Comments still have no wrapper: there is no comment script in `.agent/scripts`. The new row should still say that comments are signed by habit only, so it does not claim a guard that does not exist.

### Summary

The revision handles the second review's suggestions and the owner-approved `AGENTS.md` commit cleanly, and the review-hold intent is now right. One gap is left. Step 8 lets the implementer pick a path-based walk-back that fails the existing ci-32 test (reproduced), or a pre-push capture that misses a concurrent push. Pinning it to "walk back over this run's own pushed SHAs" is a one-sentence amendment, and a further full review should not be needed.

### Recommended Actions

- [ ] Step 8: define the review-hold SHA by walking back from `HEAD_NOW` over the SHAs this run pushed (recorded after each successful Step 1 / 1.5 push), not by paths and not by a pre-Step-1 capture; say so in the ~1199 comment
- [ ] Step 3: the retitled Rules row keeps that comments are signed by habit only

## Checkpoint
**Status**: complete
**When**: 2026-11-02 12:22 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Owner, 2026-11-02: "revise 323". The third plan review (affb1bb3) left one should-fix: the two ways step 8 finds the review-hold SHA behave differently and the path-based walk-back breaks ci-32; fix by recording the SHA of each commit this run pushes and walking back from HEAD_NOW over those only. Suggestion: the retitled design Rules row still says comments are signed by habit only.

## Plan Authored
**Status**: complete
**When**: 2026-11-02 12:23 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-323/plan.md` at `885bf4e1`

Third revision: step 8's review-hold SHA is now one rule (merge_pr.sh records SHAs of its own pushed commits and walks back over exactly those; fixture 10c, ci-32 kept), and the retitled Rules row must still say comments are signed by habit only.

## Plan Review
**Status**: complete
**When**: 2026-11-02 12:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #323 — Small tooling fixes: skill worktrees branch from default, issue wrapper injects the AI signature, merge-script CI-target wording for host-pushed bookkeeping
**Plan**: `.agent/work-plans/issue-323/plan.md` at `885bf4e1`
**Branch**: `feature/issue-323`

Fourth review, narrow: only the revision for the third review (`885bf4e1`): step 8's review-hold SHA rule and the step 3 Rules-row wording. Findings resolved by the first three reviews are not reopened.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: three fixes plus the `AGENTS.md` row commit. |
| Issue alignment | Good | Serves unchanged since review 2: "Quality of the work and Trust, control and information; `docs/design.md#worktrees`, `docs/design.md#merge-gate`, `docs/design.md#identity`". |
| File targeting | Good | Unchanged. |
| Consequences | Good | Step 8 now names one mechanism, by SHA. Checked against merge_pr.sh below. |
| Principle alignment | Good | Fixture 10c pins step 8. ci-32 pins the same-path case. |
| ADR compliance | Good | Step 3 now keeps "comments are signed by habit only" in the retitled row (`docs/design.md` line 169). |
| ROS conventions | N/A | Workspace plan. |

Checked in the code:
- Each commit this run makes has a known point to read its SHA: Step 1's roadmap commit (`git -C "$_WT_ROOT" commit`, ~603) and Step 1.5's record commit (`progress_append.sh -C "$_gate_wt"`, ~837). The Step 1.5 commit is undone when its push is refused (~845), so it never reaches origin.
- `HEAD_NOW` is fetched fresh from origin (~958-959), so a host push that lands after this run's push is the head and is not in the list: the hold follows it.
- In ci-32 (test_merge_pr_gate.sh ~1192-1204), the host's checkpoint commit and this run's record commit touch the same `progress.md`. A walk by SHA stops at the host commit, so the hold reads `head_now` and ci-32 keeps passing. A walk by path would not stop there, as review 3 reproduced.
- In the stale shape, the hold reads the host commit, where 10c puts the running review. Today `_ci_review_sha` is `CI_TARGET_SHA` (~1207), which is this run's record commit before the fold and gh's lagging `headRefOid` after it. So 10c fails on the unfixed script and would also fail with the fold alone, which means 10c pins step 8 on its own.
- With no own commits on the head, the walk is empty and the hold is `HEAD_NOW`. That matches today's non-exempt case.

Step 3: no script in `.agent/scripts` signs comments (only `gh_create_pr.sh` carries `SIG_MARKER` today), so "comments are signed by habit only" is still true and the row must keep saying it.

### Findings

1. **[Consequences, suggestion]** Record a SHA when its commit succeeds, not when its own push succeeds. Step 1 commits even when its push fails (~603-612). Step 1.5's later push then carries that roadmap commit to origin. If the list were filled only on a successful own push, the walk would stop at that roadmap commit and read the hold from a commit no review runs on. The plan's wording ("each commit this run itself pushes") already covers this. The implementation should keep to that wording.
2. **[Consequences, suggestion]** Say what happens when `HEAD_NOW` is empty or came from the gh fallback with no local worktree (~961-967). The walk needs `git rev-parse <sha>^` in `_ci_wt`. With no local repo, the hold should be `HEAD_NOW`, or `CI_TARGET_SHA` when `HEAD_NOW` is empty, as today. This can be settled in implementation.

### Summary

Both changes are sound. Step 8's rule (walk back from `HEAD_NOW` over exactly the SHAs this run committed) gives the host-pushed head in ci-32 and in 10c. It follows a late concurrent push and never reads this run's own record commit. Step 3 keeps the comments caveat. Ready for implementation. The two suggestions are edge cases for the implementer.

### Recommended Actions

- [ ] Implementation: add a SHA to the list on a successful Step 1 / Step 1.5 commit, and drop it when Step 1.5's commit is undone
- [ ] Implementation: keep today's fallback for the hold SHA when `HEAD_NOW` is empty or there is no local worktree to walk in

## Checkpoint
**Status**: complete
**When**: 2026-11-02 12:25 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (fourth plan review verdict ready with two suggestions only; proceed is within the checkpoint table)
**After**: plan
**Decision**: proceed

The fourth plan review (035a1b93) approved the plan: step 8's review-hold rule finds the host-pushed head in ci-32 and fixture 10c, follows a late push and never reads this run's own record commit. Two suggestions go into the implement handoff: add a SHA to the pushed list when its commit succeeds (Step 1's push can fail and Step 1.5's push then carries it), and keep today's fallback for the hold SHA when HEAD_NOW is empty or there is no local worktree to walk.

## Implementation
**Status**: complete
**When**: 2026-11-02 13:16 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-323 at `300d51b1`

Four commits, as the plan sets out:

- `45f0f4ce` gh_create_issue.sh signs like gh_create_pr.sh: `--body`/`--body-file`, `-b`/`-F`, the `=` forms and `--body-file -`; `--no-signature` (stripped); exit 2 before any gh call when there is a body but no identity; one TMPDIR temp copy shared with the parent-ref injection, footer last, git-bug path signed; the final `exec` is dropped. New `test_gh_create_issue.sh`: 36 checks. Against the pre-fix script (swapped in, then restored), 27 of them fail. docs/design.md: the Rules row is retitled and still says comments are signed by habit only; the Identity bullet is updated; Change log row. The ROOT_READERS entry is in `test_script_tests_hook_scope.sh`.
- `e83792eb` worktree_create.sh: a new branch starts from `origin/<default>`, through `_wt_default_start_point` in `_worktree_helpers.sh`, which is used by the workspace path and `_wt_add_repo`, with `--no-track`. Origin unreachable: the local default, with a warning. Nothing resolves: an error with the set-head hint. A missing parent falls back to the same start point. New `test_worktree_create.sh`: 18 checks. Against the pre-fix scripts, 11 fail (the `--no-track` and `--parent-issue` checks pass either way). The five named suites copy `_resolve_default_branch.sh`, and their worktree sandboxes init on `main`. WORKTREE_GUIDE.md gains a section, "Where a New Branch Starts". A full run of `run_script_tests.sh` before this commit passed all 42 suites.
- `7cf0d9ca` merge_pr.sh: Step 2's allowed set adds `MERGE_PR_CI_BOOKKEEPING_PATTERNS`, now defined once above Step 2, and the success line is reworded. The review-hold SHA walks back from HEAD_NOW over `_RUN_COMMITTED_SHAS`. A SHA is added when its commit lands (review suggestion 1) and removed when a refused Step 1.5 push undoes it. With no HEAD_NOW or no local worktree, the hold is the CI target, as today (suggestion 2). Four comments are updated. New fixtures in `test_merge_pr_gate.sh`:
  - ci-35: roadmap and another issue's work plan. Fails before: the PR 322 "not a merge-time document file" line, and the first wait is on the new head.
  - ci-36: code, rename and submodule negatives.
  - ci-37: review on the host commit. Fails before: the merge went past it.
  - ci-38: no read of this run's own record commit.
  - ci-39: Step 1's push is refused. Fails when the SHA is recorded only on a successful push.
  ci-2b follows the new wording. The line citations in design.md and the runner comment are refreshed, with a Change log row. The suite has 114 checks, all passing; test_merge_pr.sh and test_merge_pr_root_resolution.sh also pass.
- `300d51b1` AGENTS.md: the Script Reference row for gh_create_issue.sh (owner-approved 2026-11-02).

Final `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP: every hook passed, `validate-script-tests` included.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-02 13:33 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-323 at `dac47ddf`
**Base**: main
**Depth**: Deep (reason: enforcement script merge_pr.sh changed; 1112 lines over 17 files excluding work plans)
**Must-fix**: 2 | **Suggestions**: 4
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Verified: full `run_script_tests.sh` (all 42 suites passed, 555 s); shellcheck --severity=warning clean on the changed scripts; the merge_pr.sh review-hold walk-back traced by hand (never reads this run's record commit, ci-38; stops at the first foreign commit so a late host push is the hold; ci-32 unchanged; empty HEAD_NOW or no local worktree keeps CI_TARGET_SHA as before); the issue wrapper's root guard (line 70) runs before any parse or signing, the EXIT trap is set before the first mktemp and no exec remains, `--body-file -` is signed; refreshed design.md line citations spot-checked. The three additions beyond the plan are justified: ROOT_READERS entries are required by the hook-scope suite for root-reading suites, the citation refresh is ADR-0017 upkeep, and stdin signing closes a hole that `--body-file -` would otherwise leave. Cross-model: gemini ran (no findings, short); codex ran (two findings, both kept below).

### Findings
- [x] (must-fix) A readable non-regular `--body-file` (process substitution `<(...)`, a FIFO) fails `-f`, so the issue is created unsigned with exit 0; the comment says gh then fails, which is false for these. Copy every given body file other than a missing path into the temp copy with `cat` and sign that (codex) — `.agent/scripts/gh_create_issue.sh:356` (also 223, 323, 336, 360)
- [x] (must-fix) Flag normalisation is value-blind and incomplete: `-b=X`, `-bX`, `-F=X`, `-FX` (accepted by gh) reach gh unsigned with exit 0, and values that look like flags (`--title -b`, `--body '--repo=x'`, a value `--no-signature`) are rewritten or stripped. One parse pass that consumes each value-taking flag's value (cross-confirmed: codex, Claude adversarial) — `.agent/scripts/gh_create_issue.sh:91`
- [x] (suggestion) `gh_create_pr.sh` has the same two gaps (same normalisation loop; `-f` check at line 310); fix both wrappers together or open a follow-up issue — `.agent/scripts/gh_create_pr.sh:97`
- [x] (suggestion) `printf | grep -q` under pipefail can SIGPIPE on a large body, miss the marker and add a second footer; use a here-string — `.agent/scripts/gh_create_issue.sh:222`
- [x] (suggestion) The default-branch fetch has no `GIT_TERMINAL_PROMPT=0` / SSH BatchMode or timeout and discards stderr, so a credential prompt can block and an auth failure shows only as "could not fetch"; include the first error line in the warning — `.agent/scripts/_worktree_helpers.sh:497`
- [x] (suggestion) No fixture pins the late concurrent push (a host commit landing on top of this run's record commit before Step 2's fetch: the hold must read that host commit); correct by reading, untested — `.agent/scripts/tests/test_merge_pr_gate.sh:1345`

## Implementation
**Status**: complete
**When**: 2026-11-02 13:56 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-323 at `7694fb15`
**Addressed**: Local Review (Pre-Push) at `dac47ddf` (2026-11-02 13:33 -05:00)
**Commits**: e6e0d5d4, c57f71f5, 487b1a04, 7694fb15

### Actions
- [x] (must-fix) A pipe, FIFO or process-substitution `--body-file` went out unsigned: any body file is now read once into the temp copy (stdin for `-`) and signed there; an unreadable one exits 2 — `.agent/scripts/_gh_create_args.sh` (`gh_body_copy`), `.agent/scripts/gh_create_issue.sh` (e6e0d5d4)
- [x] (must-fix) Value-blind flag normalisation: one pflag-shaped parse in the new sourced helper `_gh_create_args.sh` (each value-taking flag consumes its value; `-b=X`, `-bX`, `-F=X`, `-FX`, clusters such as `-wb X`; nothing after `--`), with tests for each form and for `--title -b`, `--body '--repo=x'`, a value `--no-signature`, `--label --body` — `.agent/scripts/gh_create_issue.sh`, `.agent/scripts/tests/test_gh_create_issue.sh` (e6e0d5d4)
- [x] (suggestion) `gh_create_pr.sh` moved onto the same helper (`--body-stdin` becomes `--body-file -`, one temp copy under TMPDIR via `mktemp -t`), its suite gains the same cases plus a per-run TMPDIR leak check; the runner's absolute-/tmp mktemp list and the design doc's repo-safety line citation updated (host decision, listed for the owner's veto) — `.agent/scripts/gh_create_pr.sh`, `.agent/scripts/tests/test_gh_create_pr.sh` (c57f71f5)
- [x] (suggestion) Marker and parent-reference checks no longer pipe into `grep -q`: a bash match on the inline value, grep on the copy; 100 KB body tests — `.agent/scripts/_gh_create_args.sh` (`gh_body_is_signed`), `.agent/scripts/gh_create_issue.sh` (e6e0d5d4)
- [x] (suggestion) The default-branch fetch runs with `GIT_TERMINAL_PROMPT=0` and `timeout` (`WT_FETCH_TIMEOUT`, default 60 s); the fallback warning names the timeout or git's first error line; tests for both, WORKTREE_GUIDE.md says so — `.agent/scripts/_worktree_helpers.sh` (`_wt_default_start_point`) (487b1a04)
- [x] (suggestion) Fixtures ci-40 / ci-40b: the remote's post-receive hook answers this run's record push with a host bookkeeping commit on top; the hold reads that commit (holds while its review runs, merges once it finished, never reads the record commit) — `.agent/scripts/tests/test_merge_pr_gate.sh` (7694fb15)

### Checks
- Intermediate commits used `SKIP=validate-script-tests` (dispatched-pass rule). Then `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP on the final tree (7694fb15): exit 0, every hook passed or had no files, `validate-script-tests` included (every suite: the branch touches shared helpers).
- Suites also run by hand while fixing: test_gh_create_issue.sh, test_gh_create_pr.sh, test_worktree_create.sh, test_merge_pr_gate.sh, all 0 failures.

### Not done
- The target-branch fetch in `_wt_add_repo` (pre-existing on main, not this finding's line) has the same unbounded-prompt shape; left as it is.
- AGENTS.md's script table has no row for the new `_gh_create_args.sh` helper (several `_*.sh` helpers have none either); AGENTS.md is Ask-First, so it is not edited here.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-02 14:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent ad0813040dd155e8e, resume 1 of 3)

**Branch**: feature/issue-323 at `ea6bfb03`
**Base**: main
**Depth**: Deep (reason: whole-branch diff still holds the enforcement script merge_pr.sh and ~1500 changed lines; fix round classified on the whole diff)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Both round-1 must-fixes are resolved. The new `_gh_create_args.sh` parser matches gh 2.103.3's value-taking flags and boolean shorthands for `issue create` and `pr create` (checked against `--help` by the Claude adversarial reviewer). Each value-taking flag takes its value whatever it looks like, and `-b=X`, `-bX`, `-F=X`, `-FX`, `-F -`, clusters and `--` all parse as pflag parses them. Every readable body file, a pipe or process substitution included, is read once into a TMPDIR copy and signed; one that cannot be read exits 2. `--no-signature` is consumed and never reaches gh.

The PR wrapper keeps every form its old tests covered. It changes in two ways: `--body-stdin` now goes through the TMPDIR copy, and a missing body file exits 2 instead of being handed to gh.

The fetch runs before `git worktree add`, so a timeout cannot leave a half-made worktree.

Verified:
- test_gh_create_issue 55/55, test_gh_create_pr 73/73, test_worktree_create 21/21 and test_user_tier_guard 64/64, run here.
- test_merge_pr_gate 116/116, run by the adversarial reviewer.
- shellcheck --severity=warning is clean on the fix diff.
- The implementer's final no-SKIP pre-commit run covered every suite.

Findings dropped:
- Gemini: `-w=` splits into `-w -=`. gh rejects both spellings.
- Adversarial, unverified: gh resolving paths relative to the body file's directory.
- No body flag means unsigned (`--fill`, `-e`, `--template`). This is the documented interactive rule and predates this change.
- `WT_FETCH_TIMEOUT=0` falls back to 60. This is minor.
- A BSD `mktemp` template. This workspace runs on Linux.

### Findings
- [ ] (suggestion) The two fetches that run before the bounded default-branch fetch have no timeout and no `GIT_TERMINAL_PROMPT=0`, so a hanging origin still hangs worktree creation before the new bound is reached. These are `fetch_remote_branch` in worktree_create.sh and the target-branch fetch in `_wt_add_repo`. Both predate this change and the implementer listed them as not done. Bound them the same way, or open a follow-up issue (codex rated it must-fix; downgraded because it is not a regression and the WORKTREE_GUIDE sentence names only the default-branch fetch) — `.agent/scripts/_worktree_helpers.sh:532`

## Checkpoint
**Status**: complete
**When**: 2026-11-02 14:06 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (pre-push round 2 approved, ship recommended, 0 must-fix; the one suggestion is a pre-existing gap on main, left open for triage)
**After**: publish
**Decision**: publish

Pre-push review round 2 (b7d4c216): approved, both round-1 must-fixes resolved, 0 must-fix, 1 suggestion (two other fetches, fetch_remote_branch in worktree_create.sh and the target-branch fetch in _wt_add_repo, are still unbounded; both on main before this branch; one already in the inbox). Gemini ran, one minor point dropped (gh rejects both spellings). Codex ran, the fetch suggestion. Publishing.

## Integrated Review
**Status**: complete
**When**: 2026-11-02 14:16 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #417 at `b84987a`
**Sources**: 4 (Copilot R1 @ `b84987a`, Local Review (Pre-Push) @ `ea6bfb0` (covers `b84987a` via bookkeeping), round-2 adversarial sub-reviewer notes relayed by the host, CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

### Findings
- [x] (must-fix, Copilot) The review hold fails open when its first read of the review SHA errors. Before #323 `_ci_review_sha` equalled `CI_TARGET_SHA` until the walk-back switch, which seeds `_ci_head_excluded_last`; now it can differ from the first poll (stale headRefOid + host bookkeeping commit, or this run's own commits walked over), so a failed first `_ci_poll_state "$_ci_review_sha"` restores the empty `_ci_head_excluded_last`, `_ci_review_pending` stays false, and a green CI target merges past a review that may be running. Related: the walk-back switch seeds `_ci_head_excluded_last` from the poll of the pre-switch `CI_TARGET_SHA`, which is no longer necessarily the review SHA, so a later failed read falls back to another commit's review state. Fix: track whether the review SHA was ever read; while it has not been (and `--allow-pending-review` is off), treat the hold as unresolved: keep polling and end at the grace deadline with a fail-closed result naming the unreadable review state; seed at the switch only when the polled SHA is `_ci_review_sha`. Add fixtures: stale headRefOid + host commit whose first review-SHA lookup fails once (holds, then merges or holds on the real state) and fails persistently (refuses at the grace deadline) — `.agent/scripts/merge_pr.sh:1301`
- [x] (minor, adversarial sub-reviewer, gh 2.103.3 help checked, not run against real gh) `gh_body_copy` moves the body file to TMPDIR, and gh resolves relative image references in a `--body-file` against that file's directory first, falling back to cwd ("Paths in a `--body-file` are relative to its directory"), so `--body-file docs/x.md --attach docs/img.png` with `![](./img.png)` in the body no longer gets its reference rewritten. New for the issue wrapper (main passed the caller's path through) and for the PR wrapper's no-sign / already-signed cases; main's PR wrapper already copied to /tmp when it signed. Fix: pass the caller's path unchanged when nothing is appended and the source is a regular file; when signing with `--attach` present, make the copy in the source file's directory (removed by the EXIT trap) or refuse with a message; add a test that the body path gh receives keeps the source directory when `--attach` is given — `.agent/scripts/_gh_create_args.sh:225`
- [x] (suggestion, pre-existing on main, follow-up-issue candidate; Local Review (Pre-Push) @ `ea6bfb0`) `fetch_remote_branch` in worktree_create.sh and the target/parent-branch fetches in `_wt_add_repo` still have no timeout and no `GIT_TERMINAL_PROMPT=0`, so a hanging origin hangs worktree creation before the new bounded default-branch fetch runs. The bound used by the new helper can be reused directly — `.agent/scripts/_worktree_helpers.sh:554`
- [x] (minor, pre-existing on main, follow-up-issue candidate; adversarial sub-reviewer) The PR wrapper signs only when a body flag is given, so `--fill` / `--fill-first` / `--fill-verbose` (non-interactive, body from commits), `--template` and `--recover` create an unsigned PR with exit 0 and no identity check; main's `needs_signature` has the same rule. Fix: treat those flags as a body source (refuse without identity unless `--no-signature`, and either refuse them or sign via `gh pr edit` after create) — `.agent/scripts/gh_create_pr.sh`

### False positives
- (adversarial sub-reviewer) `mktemp -t gh_pr_body.XXXXXX.md` breaks on BSD/macOS — GNU accepts the mid-template X's (implied suffix); BSD/macOS `-t` treats its argument as a prefix and appends its own random `.XXXXXXXX`, so the file is still created uniquely under TMPDIR (name ends in random characters rather than `.md`, which gh does not read). It is more portable than main's `mktemp /tmp/gh_pr_body.XXXXXX.md`, which on BSD substitutes nothing.

## Checkpoint
**Status**: complete
**When**: 2026-11-02 14:16 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (integrated review has one confirmed must-fix from Copilot in merge_pr.sh and three smaller valid findings; address is within the checkpoint table; the two follow-up-issue candidates are fixed on this branch instead, a mechanism decision listed for veto, so no issue is opened)
**After**: findings
**Decision**: address

Integrated Review (42516c6e): changes needed, 1 must-fix (merge_pr.sh ~1301: when the first review-hold lookup fails, the empty last-seen state lets a green CI target merge past a review still running; the walk-back switch also seeds that state from the CI-target poll, which may not be the review SHA), 3 minor/suggestion (relative attach paths after the body copy; the two other fetches still unbounded; --fill/--template/--recover create an unsigned PR with exit 0). False positive: the mktemp template (BSD -t treats it as a prefix). CI pending.

### Decisions made (owner may veto)
- The two other fetches get the same bound and prompt suppression on this branch rather than a follow-up issue: the bound exists now and reuse is cheap — undoing it: revert one commit.
- The PR wrapper refuses (exit 2) --fill, --template and --recover without a body when identity is set, naming --no-signature as the explicit opt-out, so an unsigned PR needs a deliberate flag — undoing it: one commit; the alternative is a warning only. (Corrected 2026-11-10 by the address pass, Local Review of 2026-11-02 14:48: what shipped refuses with or without an identity, in both wrappers (the issue wrapper for --template / -T and --recover), and --recover even with a body, since gh loads the recovered input over it.)
- The attach-path limit after the body copy is documented in the helper and warned on stderr when the body holds relative image links; the cwd is not changed because gh's repo targeting reads it — undoing it: one commit.

## Implementation
**Status**: complete
**When**: 2026-11-02 14:42 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent ada7d3d12ca2640fa, resume 1 of 3)

**PR**: #417 at `07720828`
**Addressed**: Integrated Review at `b84987a` (2026-11-02 14:16 -05:00)
**Commits**: 7d6d29ba, 7cec467a, d84c8e64, 07720828

### Actions
- [x] (must-fix, Copilot) The review hold failed open on an unread review SHA: `merge_pr.sh` now tracks whether the review SHA's check-runs were read once; until then the hold is unresolved (no merge) and the wait refuses at the CI grace deadline (`review-unreadable`, naming the review commit); the walk-back switch seeds the last-seen state only when it polled the review SHA. Fixtures ci-41 (one failed read, finished review: merges after reading), ci-42 (one failed read, running review: holds), ci-43 (never readable: refuses at the grace deadline), ci-44 (`--allow-pending-review` merges); ci-41 to ci-43 fail against the previous script. Design doc Merge gate bullet and line citations updated — `.agent/scripts/merge_pr.sh` (CI wait loop) (7d6d29ba)
- [x] (minor) Relative paths after the body copy: the limit is documented in `_gh_create_args.sh`'s header, and `gh_body_copy` warns on stderr, naming both directories, when the copy holds `](./` or `](../`; the cwd is not changed (host decision, listed for the owner's veto). One test plus a no-warning case — `.agent/scripts/_gh_create_args.sh` (`gh_body_copy`) (07720828)
- [x] (suggestion) `fetch_remote_branch` and `_wt_add_repo`'s target and parent fetches go through the new `wt_bounded_git` (`GIT_TERMINAL_PROMPT=0`, `WT_FETCH_TIMEOUT`), as the default-branch fetch now does; a fetch the limit ends warns. Tests: `worktree_create.sh` end to end against a hanging ssh origin, and `_wt_add_repo` directly. WORKTREE_GUIDE covers every fetch; `worktree_create.sh` line citations refreshed — `.agent/scripts/_worktree_helpers.sh`, `.agent/scripts/worktree_create.sh` (7cec467a)
- [x] (minor) `--fill` / `-f`, `--fill-first`, `--fill-verbose`, `--template` / `-T`, `--recover` (the PR wrapper; `--template` / `-T`, `--recover` the issue wrapper) with no body exit 2 without `--no-signature`, naming it as the opt-out; tests in both suites, including identity unset, `--no-signature` and a body alongside — `.agent/scripts/_gh_create_args.sh` (`gh_refuse_unsigned_fill`), both wrappers (d84c8e64)

### Checks
- Intermediate commits used `SKIP=validate-script-tests`. Then `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP on the final tree (07720828): exit 0, every hook passed or had no files, `validate-script-tests` included.
- Suites run by hand while fixing, 0 failures each: test_merge_pr_gate.sh, test_worktree_create.sh, test_gh_create_pr.sh, test_gh_create_issue.sh.

### Not done
- AGENTS.md's rows for `gh_create_pr.sh`, `gh_create_issue.sh` and `merge_pr.sh` do not mention the new refusals; AGENTS.md is Ask-First, so it is not edited here.

## Local Review
**Status**: complete
**When**: 2026-11-02 14:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ad0813040dd155e8e, resume 2 of 3)

**PR**: #417 at `fbf94d1`
**Depth**: Deep (reason: whole-PR diff holds the enforcement script merge_pr.sh, ~2970 changed lines over 22 files; fix round classified on the whole diff)
**Must-fix**: 1 | **Suggestions**: 2

Verified: the review hold no longer merges on an unread state. Traced by hand: `_ci_poll_state` returns `error|` on any failed read, a review SHA is marked read only on a non-error poll, the walk-back seeds the last-seen state only from a poll of the review SHA itself, and a review SHA with no check-runs counts as read, so a repo with no review check-run does not deadlock. The adversarial reviewer ran test_merge_pr_gate.sh: 120/120 at HEAD; against the previous merge_pr.sh (`7d6d29ba^`, in a `git archive` copy) ci-41, ci-42 and ci-43 fail, while ci-32, ci-40, ci-40b and ci-44 pass both ways (ci-44 pins the opt-out only). `wt_bounded_git` runs every fetch before any `git worktree add`, so it cannot leave a half-made worktree. The new refusal does not block the loop's publish path: `gh_create_pr.sh --title T --body-stdin` and `--body-file -` pass with identity set (fake-gh runs by the adversarial reviewer), as do `--fill --body`, `--draft --body` and `--web`. Shellcheck --severity=warning is clean on the changed scripts. Cross-model: gemini ran (no findings, short); codex ran (one finding, kept below as the must-fix, confirmed against gh 2.103.3's create.go).

### Findings
- [x] (must-fix) `--recover` with a body passes the new guard, but gh loads the recovered JSON over the body after reading `--body`/`--body-file`, so the signed body and the parent reference are replaced and the issue or PR goes out unsigned (interactive sessions only: gh refuses `--recover` without a prompt). Refuse `--recover` without `--no-signature` whether or not a body is given; add a regression in both suites (codex) — `.agent/scripts/_gh_create_args.sh:286`
- [x] (suggestion) A fetch the limit ends (124/137) for a branch that exists on origin is treated as "not on origin": `worktree_create.sh` and `_wt_add_repo` then create a new branch from the default with only a warning, so the existing remote work is not checked out and the first push is non-fast-forward. A timeout is unambiguous; stop with the error instead of falling back (Claude adversarial) — `.agent/scripts/worktree_create.sh:62`, `.agent/scripts/_worktree_helpers.sh:572`
- [x] (suggestion) The address checkpoint's owner-veto list says the wrappers refuse `--fill`/`--template`/`--recover` "when identity is set"; the code (d84c8e64) and its tests refuse them with or without identity. Correct the decision as listed for veto (the PR's Decision summary) so the owner judges the behaviour that shipped — `.agent/work-plans/issue-323/progress.md` (Checkpoint 73080c9f)

## Implementation
**Status**: complete
**When**: 2026-11-10 10:25 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed fix pass after a cut-off one

**PR**: #417 at `32776119`
**Addressed**: Local Review at `fbf94d1` (2026-11-02 14:48 -05:00)
**Commits**: 134003d4, 88cede95 (an earlier pass, cut off before its entry), 8ad83cc0 (merge from main), f1925181, 8ed8f908, 32776119

### Actions
- [x] (must-fix) `--recover` with a body went out unsigned: `gh_refuse_unsigned_fill` refuses `--recover` without `--no-signature` with or without a body, in both wrappers; regressions in both suites (`--body`, and `--body-file` in the issue suite), `--recover --no-signature` still runs — `.agent/scripts/_gh_create_args.sh` (134003d4, from the cut-off pass; read and checked here)
- [x] (suggestion) A timed-out fetch of an existing remote branch fell back to a new branch: `wt_fetch_named_branch` stops (status 3) on a timeout, or a failure while origin has the branch, in `worktree_create.sh` and `_wt_add_repo`, for the target and the parent branch — `.agent/scripts/_worktree_helpers.sh`, `.agent/scripts/worktree_create.sh` (88cede95, from the cut-off pass). Closed the rest of the class here (f1925181): an existing branch's parent lookup still swallowed status 3 and silently made a draft PR target the default; it now warns and names `gh pr edit --base`. Added the tests 88cede95 lacked for the parent-branch stop (worktree_create.sh and `_wt_add_repo`, origin unreachable with origin/<parent> known) and one for the warning
- [x] (suggestion) The address checkpoint's veto list said the refusal applies "when identity is set": the bullet carries a dated correction (refused with or without identity, both wrappers, `--recover` even with a body) — `.agent/work-plans/issue-323/progress.md` (32776119)

### Merge from main
- `main` (6f90ffa5, 197 commits) merged at 8ad83cc0. Conflicts: AGENTS.md (main moved the Script Reference to `.agent/knowledge/script_reference.md`; AGENTS.md taken from main, the branch's `gh_create_issue.sh` row carried into script_reference.md) and docs/design.md's change log (both sides' rows kept). main changed none of the branch's scripts (worktree scripts, merge_pr.sh, gh wrappers); its edits to run_script_tests.sh, test_script_tests_hook_scope.sh and WORKTREE_GUIDE.md merged cleanly beside the branch's.
- With the rows out of AGENTS.md, the previous round's "Not done" item is done (8ed8f908): the script_reference.md rows for both wrappers and merge_pr.sh name the new refusals.

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP, on 32776119's tree: exit 0, every hook passed or had no files, `validate-script-tests` included. The f1925181 commit also ran the script suites in its hook (SKIP was not set on it by mistake; it passed).
- test_worktree_create.sh by hand: 28 passed, 0 failed.

### Decisions (owner may veto)
- The signing refusal (corrected wording): `gh_create_pr.sh` and `gh_create_issue.sh` exit 2 on `--fill` and its variants or `--template` with no body, and on `--recover` with or without one, unless `--no-signature` is given, whether or not an identity is set — undoing it: revert d84c8e64 and 134003d4.
- An existing branch whose parent cannot be fetched gets a warning about the draft PR base rather than a stop: the branch is already there, so only the PR base is at stake — undoing it: revert f1925181.

## Local Review
**Status**: complete
**When**: 2026-11-10 11:00 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #417 at `4c54c306`
**Depth**: Deep (reason: the whole-PR diff holds the enforcement script merge_pr.sh, 2810+/361- over 22 files; fix-round rule, classified on the whole diff, not lowered for the small fix diff)
**Round**: 2 (PR mode: one earlier complete `## Local Review`, no restart checkpoint; the handoff has no "no cross-model reviewers", so the fix-round rule applied and cross-model ran)
**Must-fix**: 3 | **Suggestions**: 5

Scope: the fix diff since the last reviewed head `fbf94d1` (134003d4, 88cede95, f1925181, 8ed8f908, the progress commits) and the merge from main (8ad83cc0).

Verified:
- The merge loses nothing. `git show --remerge-diff 8ad83cc0`: AGENTS.md is main's, and the branch's only AGENTS.md change (the `gh_create_issue.sh` row) is in `.agent/knowledge/script_reference.md`; the design.md change log keeps both sides' rows. Of the branch's 22 files, every one main did not touch is byte-identical to 88cede95. For the three both sides touched (WORKTREE_GUIDE.md, run_script_tests.sh, test_script_tests_hook_scope.sh) the branch's added and removed lines match exactly before and after the merge. The branch's file set is the same apart from AGENTS.md → script_reference.md.
- The new citations hold: `worktree_create.sh:1014,1055` (run_script_tests.sh) and design.md `1049-1055`.
- `--recover` is refused with or without a body in both wrappers, including `--recover=x` (the parser normalises it).
- Shellcheck --severity=warning: clean on the 9 changed scripts. The Claude adversarial reviewer ran test_worktree_create.sh (28 pass), test_gh_create_pr.sh (99 pass) and test_gh_create_issue.sh (65 pass).
- Cross-model: gemini ran (no findings; a short reply). Codex ran (1 finding, kept as must-fix 2; reproduced with stubs). Copilot did not review this head (out of quota).

The fetch helper `wt_fetch_named_branch`, reviewed as a whole. It has three callers: `fetch_remote_branch` (issue branch at worktree_create.sh:840; parent at :848), `_wt_add_repo` (target at :612; parent at :626), and the existing-branch parent lookup (worktree_create.sh:876).

| Outcome | Caller behaviour | Right? | Tested? |
|---|---|---|---|
| Fetched | track origin/<b> | No, when the clone's refspec is narrowed (must-fix 1) | No test for a branch that exists only on origin |
| Absent (ls-remote 2) | fresh branch, or default | Yes | Yes |
| Fetch timed out | stop (for :876, warn) | Yes | Yes (13, 14, 18) |
| Fetch failed, ls-remote 0 | stop | Yes | No |
| Fetch failed, ls-remote timed out | as unreachable | No (must-fix 2) | No |
| Unreachable, stale origin/<b> | stop | Yes | Yes (15, 16, 17) |
| Unreachable, no evidence | warn, then fresh | Yes, except at :876, where it is silent (must-fix 3) | No |

The mechanism is right in shape: one helper classifies, and each caller acts on the status. The gaps come from two places:
- **Evidence.** Status 0 is decided by git's exit code, not by the ref the callers use. Only the first probe's timeout counts as a timeout.
- **Wording.** The helper writes its messages for the issue-branch caller. The parent callers therefore print a wrong message, and :876 has to discard stderr.

The proposed fix is one change, not three point fixes:
- Fetch with the explicit refspec `+refs/heads/<b>:refs/remotes/origin/<b>` and verify the ref, as `_wt_default_start_point` already does.
- Classify all three probes (fetch, ls-remote, tracking ref) through one table in which any timeout is status 3.
- Return the reason in a variable instead of printing it, so each caller words its own message.

### Findings
- [x] (must-fix) Status 0 does not guarantee origin/<branch>. In a clone with a narrowed fetch refspec (`--single-branch`, or any `--depth` clone), `git fetch origin -- <b>` exits 0 but writes only FETCH_HEAD. Reproduced: `wt_fetch_named_branch` returned 0 with origin/feature/issue-9 missing. `_wt_add_repo` then silently started feature/issue-9 from main (0cf75f5) while origin's branch was 8388b85: no upstream and no warning, which is the divergence the helper exists to stop. worktree_create.sh's workspace path dies at `git worktree add`. Fix: fetch with an explicit refspec and verify the ref. Add tests for a single-branch clone and for a branch that exists only on origin (both callers; neither has a test) — `.agent/scripts/_worktree_helpers.sh:516`
- [x] (must-fix) After a fetch that fails without a timeout (for example, connection refused), an `ls-remote` that times out (124/137) falls through to the stale-ref check. With no ref, the helper returns 1, so callers start a fresh branch although origin may have it. This contradicts the helper's own rule that a timeout stops. Treat an ls-remote timeout as status 3 and add a test (codex; reproduced with stubs, fetch=128 and ls-remote=124 gave 1) — `.agent/scripts/_worktree_helpers.sh:523`
- [x] (must-fix) Existing-branch parent lookup: only status 3 warns. With stderr sent to /dev/null, status 1 from an unreachable origin with no evidence (the helper's own WARNING is discarded), or from a parent that is not on origin, leaves the draft PR targeting the default branch with no word. The case is real when SSH to origin is blocked but the GitHub API works. Warn on every status other than found, and add a test (Claude adversarial) — `.agent/scripts/worktree_create.sh:876`
- [x] (suggestion) The helper's ERROR text ends "a new '<branch>' is not started in its place". For a parent branch this names the parent, but the branch that is refused is the sub-issue branch. The tests for issues 16 and 17 match only the prefix, so they pass with the wrong wording. Let each caller word its message (see the mechanism note above) (Claude adversarial) — `.agent/scripts/_worktree_helpers.sh:529`
- [x] (suggestion) A new branch whose parent fetch returned 1 falls back to the default branch. The block at :866 then fetches the same parent a second time: one more silent network round. Skip that block when the first attempt already ran (Claude adversarial) — `.agent/scripts/worktree_create.sh:866`
- [x] (suggestion) A fetch timeout stops creation even for a brand-new issue branch. Behind a black-holing network (captive proxy, dropped SSH), no new issue worktree can be made, and the only advice is to retry or raise WT_FETCH_TIMEOUT. Name an explicit opt-out, or say this in WORKTREE_GUIDE (Claude adversarial) — `.agent/scripts/_worktree_helpers.sh:519`
- [x] (suggestion) Untested paths: fetch failed with ls-remote 0 (the "origin has it" wording without the "as of the last fetch" suffix); an unreachable origin with no evidence for an issue or parent branch (the "treated as not on origin" warning); and the PR wrapper's `--recover` with `--body-file` and with `--body-stdin` (only `--body` is tested) (Claude adversarial) — `.agent/scripts/tests/test_worktree_create.sh`, `.agent/scripts/tests/test_gh_create_pr.sh`
- [x] (suggestion) A Copilot comment from 2026-11-02 is still open and untriaged: `--fill --fill=false` and `-f -f=false` are refused, although gh's final value turns fill off. The marker is never cleared. This fails closed, so it is an over-refusal, not an unsigned PR. Track each fill flag's last value — `.agent/scripts/_gh_create_args.sh:208` (deferred: fails closed, refusing a PR gh would not fill, never sending one unsigned; dropping the contradictory flag pair is the workaround, and tracking each fill flag's last value, including pflag's other false spellings such as `=0`, is more than a two-line change)

## Implementation
**Status**: complete
**When**: 2026-11-10 11:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: fix pass (host direction: one change to the named-branch lookup's contract, not three point fixes)

**PR**: #417 at `064cbd39`
**Addressed**: Local Review at `4c54c306` (2026-11-10 11:00 -05:00)
**Commits**: e0672051, af2c5d09, 39da2930, 064cbd39 (box ticks; `review_progress.sh findings` selected the older Integrated Review, issues 360 and 357, so the boxes were ticked by hand)

The named-branch lookup, redone as one change. `wt_fetch_named_branch` fetches `+refs/heads/<b>:refs/remotes/origin/<b>` and decides by that ref, not the fetch's exit code. Every result is one of present, absent or unknown, and any timeout or failure at any probe (fetch, ls-remote, the tracking ref) is unknown. It prints nothing and hands back `WT_FETCH_OUTCOME` and `WT_FETCH_REASON`; the outcome table (nine probe rows, and what each caller does) is a comment at the helper. Callers:
- New branch, and a new sub-issue branch's parent (`worktree_create.sh` workspace path and `_wt_add_repo`, both through `wt_lookup_for_new_branch`): present, track origin/<b>; absent, start afresh (from the default, with the reason, for a parent); unknown, stop before anything is made, naming the sub-issue branch when the parent is in doubt, unless `--allow-unverified-branch`.
- A present branch is tracked or fails: `wt_track_ready` adds it to a `--single-branch` or `--depth` clone's fetched branches (`git remote set-branches --add`, said on stderr), since git refuses `--track` from an unmapped ref. In `_wt_add_repo` a branch or parent found but failing to check out is now an error, not a fallback to the default.
- Existing branch's parent (`worktree_create.sh`): present, the draft PR targets it; absent or unknown, a warning with the reason and `gh pr edit --base`. No stderr is discarded.

### Actions
- [x] (must-fix) Status 0 did not guarantee origin/<branch>: explicit refspec plus a ref check, and `wt_track_ready` for narrowed clones. Tests: a branch only on origin, `worktree_create.sh` with a single-branch refspec (issue and parent), `_wt_add_repo` in a `--single-branch` and a `--depth` clone — `.agent/scripts/_worktree_helpers.sh` (`wt_fetch_named_branch`, `wt_track_ready`), `.agent/scripts/worktree_create.sh` (e0672051)
- [x] (must-fix) An ls-remote timeout after a fast fetch failure gave "absent": every timeout or failure at any probe is unknown. Tests with a git double: fetch fails then ls-remote times out (`worktree_create.sh` issue and parent, `_wt_add_repo`), fetch fails then ls-remote says found (`worktree_create.sh`, `_wt_add_repo` parent), ls-remote fails with an earlier origin/<parent> (both), fetch exits 0 without the ref — `.agent/scripts/_worktree_helpers.sh` (e0672051)
- [x] (must-fix) The existing-branch parent lookup was silent on status 1 with stderr discarded: it warns on absent and on unknown, each with its reason. Tests: parent missing from origin, unreachable origin with no tracking ref, timed-out fetch — `.agent/scripts/worktree_create.sh` (e0672051)
- [x] (suggestion) The parent caller named the parent as the branch not started: each caller words its own message, and the parent stop names the sub-issue branch. Every stop and warning test matches the whole message, reason included — `.agent/scripts/_worktree_helpers.sh` (`wt_lookup_for_new_branch`) (e0672051)
- [x] (suggestion) The parent was asked about twice after a fallback: `PARENT_LOOKED_UP` skips the second ask. Test: a git double's fetch log shows one parent fetch (two against the previous scripts) — `.agent/scripts/worktree_create.sh` (e0672051)
- [x] (suggestion) A timeout stopped a brand-new branch with no way through: `--allow-unverified-branch` starts it anyway, with a warning naming the reason and the risk. WORKTREE_GUIDE and the usage text say so. Tests in both callers — `.agent/scripts/worktree_create.sh`, `.agent/WORKTREE_GUIDE.md` (e0672051)
- [x] (suggestion) Untested paths: the worktree paths are covered above; the PR wrapper's `--recover` with `--body-file` and with `--body-stdin` now have tests (exit 2, gh not called, the reason named) — `.agent/scripts/tests/test_gh_create_pr.sh` (af2c5d09)
- [x] (suggestion) Copilot's `--fill --fill=false` over-refusal — `.agent/scripts/_gh_create_args.sh:208` (deferred: fails closed, refusing a PR gh would not fill, never sending one unsigned; dropping the contradictory pair is the workaround, and tracking each fill flag's last value, with pflag's other false spellings such as `=0`, is more than two lines)

### Consequences
- Three suites create worktrees in repos whose origin cannot be reached (test_project_registry.sh, test_ros2_colcon.sh, test_precommit_hook_path.sh); those now stop, so their fixtures pass `--allow-unverified-branch`, with a comment saying why (39da2930).
- docs/design.md: `worktree_create.sh` line citations refreshed, change-log row added (877 lines).

### Checks
- Intermediate commits used `SKIP=validate-script-tests`. Then `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP on 39da2930's tree: exit 0, `validate-script-tests` Passed. A first run on e0672051 failed in test_precommit_hook_path.sh (the unreachable-origin fixture), fixed in 39da2930.
- Run by hand, 0 failures: test_worktree_create.sh 47, test_gh_create_pr.sh 102, test_project_registry.sh 281, test_ros2_colcon.sh 200, test_precommit_hook_path.sh 19, test_merge_pr.sh 91, test_user_tier_install.sh 211. The new test_worktree_create.sh against the previous scripts (a `git archive` of 4c54c306): 26 of 47 fail, including every outcome case.
- shellcheck --severity=warning clean on the four changed scripts.

### Decisions (owner may veto)
- An unreachable origin is "unknown" and stops a new branch (the host's contract), and `--allow-unverified-branch` is the explicit way through, not a stop message alone. From the principles: "Leave a trail; start limits strict" (stopping is the strict default, and the user relaxes it with a flag visible in the command), and "A change includes its consequences": this change stops every offline creation, including skill worktrees, whose branch name is minted per run and cannot be made beforehand, so a message alone leaves no way through. Undoing it: remove the flag (its parse, usage line, the opt-out branch in `wt_lookup_for_new_branch`, two tests) and the fixtures' flag; offline creation then has no way through.
- A `--single-branch` or `--depth` clone gets the branch added to its fetched branches (`git remote set-branches --add origin <b>`, a config change said on stderr) so `--track` works. The alternative is to stop and print that command. Undoing it: replace `wt_track_ready`'s last two lines with a stop.
- In `_wt_add_repo`, a branch or parent found on origin that fails to check out is an error rather than a fallback to the default branch. Undoing it: revert e0672051's `_wt_add_repo` hunk.

### Not done
- A skill worktree's minted branch name is still looked up on origin, so offline it needs the flag. Skipping the lookup for a name minted in this run is a possible follow-up, left out to keep the pull request to this mechanism.
- Pre-existing, outside the three callers: a project worktree whose issue branch already exists sets the draft PR base from local refs alone (`worktree_create.sh`, the manifest loop's parent check), with no lookup and no warning.
- The old-scripts test copy in this session's scratchpad could not be removed (`rm -rf` was denied).

## Local Review
**Status**: complete
**When**: 2026-11-10 11:41 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a106668e02ad85d54, resume 1 of 3)

**PR**: #417 at `a378503a`
**Depth**: Deep (reason: the whole-PR diff still holds merge_pr.sh; fix-round rule, classified on the whole diff)
**Round**: 3 in PR mode (two earlier complete `## Local Review` entries, no restart checkpoint). The handoff does not say "no cross-model reviewers", so the round-3 convergence exception did not apply: the fix-round rule did, and cross-model ran.
**Must-fix**: 2 | **Suggestions**: 6

Scope: the fix diff since `54fd978d` (e0672051, af2c5d09, 39da2930 and the progress commits), checked against the 3 must-fixes and 5 suggestions of the 2026-11-10 11:00 review.

Verified:
- Every row of the outcome table in the `wt_fetch_named_branch` comment matches the code. I read both; the Claude adversarial reviewer did the same row by row. Any timeout or failure at any probe gives "unknown".
- No caller reads `WT_FETCH_OUTCOME` left over from an earlier call.
- `exit 1` inside the `elif` in `fetch_remote_branch` ends the script.
- test_worktree_create.sh passed 47 of 47 (adversarial reviewer's run).
- Shellcheck --severity=warning is clean on the 7 changed scripts.
- The three earlier must-fixes are resolved: the explicit refspec and ref check, an ls-remote timeout counted as unknown, and the existing-branch parent warning on absent and on unknown.
- Suggestions 1, 2, 3, 4 and 7 of that review are resolved. Number 8 (the `--fill --fill=false` refusal) is deferred, with its reason recorded in the Implementation entry.

The contract is now right; the remaining gaps are at its edges, not in the mechanism.

The three additions:
- **wt_track_ready.** It is in scope, since `--track` from a ref no refspec maps fails, but the way it works is wrong (must-fix 1).
- **_wt_add_repo errors on a failed checkout of a found branch.** This is right and in scope: it closes the same divergence. It leaves the local branch behind (suggestion 3).
- **--allow-unverified-branch.** With "unknown" stopping by default, a flag is the right answer, and the one stop message for "unknown" names it. With the flag, the three suites take the same path they took before (a fresh branch, with a warning), so they still test what they tested. But no suite now reaches the stop in the package path (must-fix 2). Skill worktrees regress when offline (suggestion 2).

Cross-model:
- gemini failed: agy returned an empty response after a RunCommand tool was auto-denied in headless mode.
- codex ran and gave one finding in merge_pr.sh, downgraded to suggestion 6.
- Copilot did not review `a378503a` (out of quota).

### Findings
- [x] (must-fix) `wt_track_ready` makes a lasting change to the clone's config. It adds a non-glob refspec with `git remote set-branches --add`, and nothing ever removes it. Once origin deletes the branch, which GitHub's auto-delete and `merge_pr.sh` both do after a merge, every plain `git fetch` and `git pull` in that clone fails with `fatal: couldn't find remote ref refs/heads/<b>` (exit 128). Reproduced in a single-branch clone through `_wt_add_repo`. Fix: leave origin's fetch config alone. Two ways: start from origin/<b> with `--no-track` and write `branch.<b>.remote` and `branch.<b>.merge` directly, or stop and print the command (the alternative already listed for veto). Add a test that a plain `git fetch` still works after origin deletes the branch — `.agent/scripts/_worktree_helpers.sh:649`
- [x] (must-fix) The new stop in the package (project) path is not tested through `worktree_create.sh`, and every project fixture now passes `--allow-unverified-branch`. Three cases are untested: an "unknown" on repo 1 (the worktree directory is removed), an "unknown" on repo 2 (repo 1's worktree and new branch are rolled back), and a found branch that fails to check out. Add them. Also correct "stops before anything is made", which is not true for repo 2 onward in `wt_lookup_for_new_branch` and the `_wt_add_repo` header (Claude adversarial) — `.agent/scripts/worktree_create.sh:744`, `.agent/scripts/tests/test_worktree_create.sh`
- [x] (suggestion) The restore `gitq -C "$SB" config remote.origin.fetch "+refs/heads/*:..."` fails without a word (git exits 5: "cannot overwrite multiple values", because `set-branches` added a second value), so every later case runs on the narrowed refspec. Use `--replace-all` and check the result — `.agent/scripts/tests/test_worktree_create.sh:297`
- [x] (suggestion) A skill worktree's branch name is minted this run with a timestamp, so origin cannot have it. Offline, it now stops unless given the flag; on main it was created. This is a regression from this pull request: skip the lookup (treat it as absent) for a name minted in this run — `.agent/scripts/worktree_create.sh:859`
- [x] (suggestion) When `worktree add --track -b` fails after "present" (for example, the destination is not empty), the local branch is left behind. The package rollback never records it, and the next run takes the existing-local path, which skips origin. Delete the branch made by the failed add (Claude adversarial) — `.agent/scripts/_worktree_helpers.sh:741`
- [x] (suggestion) An existing branch's parent never gets the absent or unknown warning in the package path, which checks local refs only. Either give it the workspace block's warning or say in WORKTREE_GUIDE that the warning is for the workspace type only. The Implementation entry lists this as pre-existing (Claude adversarial) — `.agent/scripts/worktree_create.sh:758`
- [x] (suggestion) The comment still cites `worktree_create.sh:1014,1055`; the two `/tmp` mktemp sites are now at 1042 and 1083 — `.agent/scripts/tests/run_script_tests.sh:348`
- [x] (suggestion) `_RUN_COMMITTED_SHAS` records HEAD even when `progress_append.sh` committed nothing (its no-op path for an entry that is already there). Downgraded from codex's must-fix: a no-op needs an identical entry (same minute, same PR head SHA), so HEAD is then the earlier `merge_pr.sh` record commit, which the hold's own rule skips. Recording the SHA only when HEAD changes is still the correct accounting, and costs two lines plus a test — `.agent/scripts/merge_pr.sh:853` (deferred, accepted as it is with the reviewer's reason: a no-op needs an identical entry, same minute and same PR head SHA, so the HEAD recorded is then the earlier merge_pr.sh record commit, which the hold's own rule skips; host direction 2026-11-10: record it, do not change it)

## Implementation
**Status**: complete
**When**: 2026-11-10 12:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af921bff50d4db2fe, resume 1 of 3)

**PR**: #417 at `5562c075`
**Addressed**: Local Review at `a378503a` (2026-11-10 11:41 -05:00)
**Commits**: 5990ef1f, 065d6639, 5562c075 (box ticks; `review_progress.sh findings` does not select this PR-mode review, so they were ticked by hand)

### Actions
- [x] (must-fix) `wt_track_ready` changed the clone's fetch config: removed. A branch found on origin is checked out with `--no-track` from `origin/<b>`, and `wt_set_upstream` writes only `branch.<b>.remote` and `branch.<b>.merge`, which is what `--track` writes. Origin's fetch refspecs stay as they were found. Tests: a `--single-branch` and a `--depth` clone through `_wt_add_repo`, and `worktree_create.sh` with a narrowed refspec, each checking the branch's sha, both settings and the unchanged refspec; then origin deletes the branch and a plain `git fetch` in each clone exits 0. Against the previous scripts these fail with `couldn't find remote ref` — `.agent/scripts/_worktree_helpers.sh` (`wt_set_upstream`, `_wt_add_repo`), `.agent/scripts/worktree_create.sh` (5990ef1f)
- [x] (must-fix) The package-path stop was untested without the flag: test_ros2_colcon.sh now runs `worktree_create.sh` without it in three cases. Unknown on the first repository: exit 1, the whole message, no aggregate directory, no branch. Unknown on the second: the whole message naming pkg_b, "rolling back 1 already-created worktree(s)", pkg_a's worktree and new branch gone, nothing in pkg_b. A branch found on origin that fails to check out (a failing post-checkout hook): exit 1, the error, the branch removed again, no worktree, never started from the default. The wording now says what a stop leaves: nothing in that repository, and in a project worktree the repositories already added are rolled back (helper comments, `_wt_add_repo` header, WORKTREE_GUIDE). `fetch_remote_branch` keeps "before anything is made": it serves the single-repository workspace path, where that is true — `.agent/scripts/tests/test_ros2_colcon.sh`, `.agent/scripts/_worktree_helpers.sh`, `.agent/WORKTREE_GUIDE.md` (5990ef1f)
- [x] (suggestion) The refspec restore failed silently: `set_refspec` uses `--replace-all` and ends the run if the value did not take — `.agent/scripts/tests/test_worktree_create.sh` (5990ef1f)
- [x] (suggestion) Offline skill worktrees regressed: a skill branch minted this run (`WT_MINTED_BRANCH`) is not looked up on origin in either path. Tests: a workspace skill worktree with an unreachable origin is created from local main without the flag (fails against the previous scripts), and test_project_registry.sh's `--skill` calls no longer pass the flag, so its onboard-project case covers the project path offline — `.agent/scripts/worktree_create.sh`, `.agent/scripts/_worktree_helpers.sh` (5990ef1f)
- [x] (suggestion) A failed checkout left its branch: `_wt_add_repo` removes a branch it made in that call (and a worktree on that branch) when the add fails, and says so. The workspace path does the same for a branch found on origin. Tests: a failing post-checkout hook in both callers. The `_wt_add_repo` cleanup sits in its one failure tail, so it also covers a failed add from a parent or the default branch, which take the same `-b` path — `.agent/scripts/_worktree_helpers.sh`, `.agent/scripts/worktree_create.sh` (5990ef1f)
- [x] (suggestion) The project path's existing-branch parent was silent: `check_existing_branch_parent` (moved out of the workspace block) is called on the project path too, unless `_wt_add_repo` already asked origin about the parent (`WT_ADD_PARENT_LOOKED_UP`). Tests on the legacy `project/` path: parent not on origin, and origin unreachable, each with the whole warning — `.agent/scripts/worktree_create.sh` (5990ef1f)
- [x] (suggestion) Stale citation: `worktree_create.sh:1068,1109` — `.agent/scripts/tests/run_script_tests.sh` (065d6639)
- [x] (suggestion) Codex's `_RUN_COMMITTED_SHAS` finding — `.agent/scripts/merge_pr.sh:853` (deferred, accepted as it is with the reviewer's reason: a no-op needs an identical entry, same minute and same PR head SHA, so the HEAD recorded is then the earlier `merge_pr.sh` record commit, which the hold's own rule skips; host direction 2026-11-10: record it, do not change it)

### Checks
- Intermediate commits used `SKIP=validate-script-tests`. Then `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP on 065d6639's tree: exit 0, `validate-script-tests` Passed.
- Run by hand, 0 failures: test_worktree_create.sh 54, test_ros2_colcon.sh 218, test_project_registry.sh 281.
- Against the previous scripts (a `git archive` of e779ecdc): 10 of test_worktree_create.sh's 54 fail (the refspec, fetch-after-delete, failed-checkout, offline-skill and project-parent cases) and 3 of test_ros2_colcon.sh's (the failed-checkout cleanup). The two package-path stop tests pass there too: they add coverage of behaviour that was already right.
- shellcheck --severity=warning clean on the changed scripts. docs/design.md: `worktree_create.sh` citations refreshed, change-log row added (878 lines).

### Not done
- In a `--single-branch` or `--depth` clone, `<b>@{upstream}` does not resolve, because no fetch refspec maps origin/<b>. So `git status` shows no ahead/behind count there, and a script that reads `@{u}` would fail in that clone. `git pull` and `git push` work from the two settings.
- A sub-issue branch started from `origin/<parent>` still relies on git's `autoSetupMerge`, so in a narrowed clone it gets no upstream (unchanged, outside the findings).
- Scratch copies in this session's scratchpad (two `git archive` copies and a probe directory) could not be removed: `rm -rf` was denied.

## Implementation
**Status**: complete
**When**: 2026-11-10 12:16 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af921bff50d4db2fe, resume 2 of 3)

**PR**: #417 at `ae50156c`
**Addressed**: Local Review at `a378503a` (2026-11-10 11:41 -05:00)
**Commits**: ae50156c (merge)

### Merge from main
- A merge from main landed at ae50156c (`GIT_EDITOR=true git merge origin/main`, no rebase), bringing in pull request 434 (the roadmap rewrite): docs/roadmap.md and `.agent/work-plans/issue-432/` merged cleanly.
- One file conflicted: docs/design.md, in the change log. The resolution keeps both sides' rows in date order: this branch's three 2026-11-10 `worktree_create.sh` citation rows, then main's 2026-11-10 Documentation layers row (the roadmap's acceptance case). Each row's Lines value is left as recorded. Nothing else changed.

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only origin/main...HEAD)` with no SKIP on ae50156c's tree: exit 0, `validate-script-tests` Passed.

## Local Review
**Status**: complete
**When**: 2026-11-10 12:26 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #417 at `5e526275`
**Depth**: Deep (reason: the whole-PR diff still holds the enforcement script merge_pr.sh, 3673+/409- over 22 files; fix-round rule, classified on the whole diff)
**Round**: 4 in PR mode (three earlier complete `## Local Review` entries, no restart checkpoint). The round-3 convergence exception applies only when the handoff says "no cross-model reviewers"; this handoff does not, so the fix-round rule applied and cross-model ran. Advisory ship check (`review_progress.sh verdict --must-fix 2 --round 4 --prev-must-fix 2 --mechanical`): recommended — 2 mechanical must-fix, not rising; fix and ship rather than another full round.
**Must-fix**: 2 | **Suggestions**: 5

Scope: the fix diff since `a378503a` (5990ef1f, 065d6639, the progress commits) and the merge from main (ae50156c).

Verified:
- Must-fix 1 of the 11:41 review is resolved. Origin's fetch refspecs are left unchanged. I reproduced this myself through `_wt_add_repo` in a `--single-branch` clone and in a `--depth 1` clone:
  - The refspec is unchanged.
  - `git pull --ff-only` in the worktree reaches origin's head, and `git push` works.
  - Once origin deletes the branch, a plain `git fetch` exits 0 both in the clone and in the worktree that is on the branch.
  - The suite's `check_tracks` also asserts that the refspec is unchanged.
- Must-fix 2 of the 11:41 review is resolved. The three new test_ros2_colcon.sh cases call `run_worktree_create_strict`, which passes no `--allow-unverified-branch`. Each asserts exit 1, the whole stop message built by `lookup_stop_message`, and no aggregate directory or branch left. The second-repo case asserts the rollback line and that pkg_a's worktree and branch are removed.
- Suites, run by me at 5e526275, all with 0 failures: test_worktree_create.sh 54, test_ros2_colcon.sh 218, test_project_registry.sh 281. Shellcheck --severity=warning (the .venv binary) is clean on the 6 changed scripts.
- The merge resolution is right. `git show --remerge-diff ae50156c` touches only the design.md change log, and both sides' rows are kept. origin/main is an ancestor of HEAD.
- run_script_tests.sh cites `worktree_create.sh:1068,1109`, and both lines are correct. No workspace script reads `@{u}`.

The fix agent's two "not done" items:
- **`@{upstream}` does not resolve in a narrowed clone.** This is an acceptable limit, not a defect:
  - pull, push and fetch all work, so the only loss is the ahead/behind count.
  - The only alternative is the refspec change this round removed.
  - It is documented at `wt_set_upstream`, but WORKTREE_GUIDE does not mention it (suggestion 4).
- **A sub-issue branch started from origin/<parent> gets no upstream in a narrowed clone.** Not a defect:
  - In a full clone, autoSetupMerge makes the sub-issue branch track origin/<parent>. That upstream is the wrong one: pull would bring in the parent, and the default `simple` push refuses it.
  - `worktree_create.sh:1046` sets the right upstream with `push -u`.
  - This behaviour predates this pull request (main:844).

Both must-fixes are mechanical edges of a right contract. Neither is a sign the mechanism is wrong. Both sit in lines this round rewrote, so fixing them here is cheaper than opening an issue.

Cross-model:
- codex ran and reported 1 finding, the concurrency race below. It is downgraded to suggestion 1 because main's project rollback already has the same race.
- gemini failed: agy returned an empty response after a RunCommand tool was auto-denied in headless mode.
- Copilot did not review 5e526275 (out of quota).

### Findings
- [x] (must-fix) Project path, new branch with `--parent-issue`: after `_wt_add_repo` has asked origin about the parent (`WT_ADD_PARENT_LOOKED_UP=true`), the loop decides again from a possibly stale `refs/remotes/origin/<parent>`. When origin has deleted the parent, `_wt_add_repo` warns "origin has no branch 'feature/issue-9'; starting … from the default branch", and then `--plan-file` runs `gh pr create … --base feature/issue-9`. The same happens with `--allow-unverified-branch` when the outcome is "unknown". The workspace path is right: no `--base`. Reproduced with gh stubs, both paths. This predates the pull request, but it is in lines this diff rewrote, and the new comment says the lookup's answer is used. Fix: when looked up, `PARENT_BRANCH_FOUND` is true only if `[ "$WT_FETCH_OUTCOME" = present ]`. Add a test, since the looked-up branch has none (Claude adversarial) — `.agent/scripts/worktree_create.sh:793`
- [x] (must-fix) 5990ef1f weakened a test without cause. "owning branch reported" now asserts `feature/pkg_a-issue-444`, the same string as the sibling assertion on the next line, so the owning repo's branch is no longer checked. pkg_a's origin still names owner/pkg_a, and the JSON reports `feature/issue-444,feature/pkg_a-issue-444`. The original assertion passes against the current scripts. Restore it (Claude adversarial; confirmed by probe) — `.agent/scripts/tests/test_ros2_colcon.sh:557`
- [x] (suggestion) The failed-checkout cleanup removes a worktree and branch without proving this run made them. If two runs create the same issue's worktree at once, the loser's failed `worktree add -b` can `worktree remove --force` the winner's worktree and delete its branch. main's project rollback (`rm -rf "$WORKTREE_DIR"`, the same `worktree remove --force`) already has this race. The right fix is a per-issue lock across worktree_create.sh: open a follow-up issue, not another round here (codex) — `.agent/scripts/_worktree_helpers.sh:790`, `.agent/scripts/worktree_create.sh:902` (deferred to a follow-up issue the host will propose to the owner: this predates the pull request; host direction 2026-11-10)
- [x] (suggestion) Workspace-path cleanup is not at parity with `_wt_add_repo`. Its `git branch -D` fails silently: `_wt_add_repo` warns and prints the command. Only the origin checkout cleans up: the parent and default `worktree add -b` calls do not (accurate as WORKTREE_GUIDE words it) (Claude adversarial) — `.agent/scripts/worktree_create.sh:905,911-933`
- [x] (suggestion) `check_existing_branch_parent` takes a stale `refs/remotes/origin/<parent>` as "on origin" without asking origin, so the draft PR can target a deleted parent. This predates the pull request, but it now also runs on the project path. Its comment says "found locally or on origin". Follow-up issue (Claude adversarial) — `.agent/scripts/worktree_create.sh:76-81` (deferred to a follow-up issue the host will propose to the owner: this predates the pull request; host direction 2026-11-10)
- [x] (suggestion) WORKTREE_GUIDE says a branch in a `--single-branch`/`--depth` clone gets "its upstream set to it". Add the limit stated at `wt_set_upstream`: `@{u}` does not resolve there, so `git status` shows no ahead/behind count — `.agent/WORKTREE_GUIDE.md:162`
- [x] (suggestion) The design.md inventory row for `worktree_create.sh` (`301-313, …, 1103-1109`) is off by about 23 lines. 301 is skill-ID generation; the `--type` derivation is at 324. main's values (248-260 against main's 271) were already off by the same amount, and each refresh kept the offset. Since the change-log rows say "refreshed", either correct the row or say it is a dated probe. Follow-up, since it predates the pull request — `docs/design.md:372` (deferred to a follow-up issue the host will propose to the owner: this predates the pull request; host direction 2026-11-10)

## Implementation
**Status**: complete
**When**: 2026-11-10 12:41 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af921bff50d4db2fe, resume 3 of 3)

**PR**: #417 at `8e085c49`
**Addressed**: Local Review at `5e526275` (2026-11-10 12:26 -05:00)
**Commits**: d09f44e8, 8a9d19ec, f78007f4, 8e085c49 (box ticks, by hand: the script does not select a PR-mode review)

### Actions
- [x] (must-fix) Project path, new sub-issue branch: once `_wt_add_repo` has asked origin about the parent, `PARENT_BRANCH_FOUND` is set only when `WT_FETCH_OUTCOME` is present, so a stale `origin/<parent>` no longer gives the draft PR `--base <parent>`. Test: on the legacy `project/` path the parent is deleted on origin and the stale ref kept; a gh stub logs `pr create`, which has no `--base feature/issue-9`. The test fails against the previous scripts (`--base feature/issue-9` is passed there) — `.agent/scripts/worktree_create.sh`, `.agent/scripts/tests/test_worktree_create.sh` (8a9d19ec)
- [x] (must-fix) The "owning branch reported" check asserts `feature/issue-444` again. 5990ef1f's rename of the new tests' branch names had reached this unrelated check — `.agent/scripts/tests/test_ros2_colcon.sh:557` (d09f44e8)
- [x] (suggestion) The concurrent-creation race in the failed-checkout cleanup — `.agent/scripts/_worktree_helpers.sh:790`, `.agent/scripts/worktree_create.sh:902` (deferred to a follow-up issue the host will propose to the owner: this predates the pull request; host direction 2026-11-10)
- [x] (suggestion) Workspace-path cleanup at parity: every new-branch `git worktree add -b` on the workspace path (from origin, a local or origin parent, or the default branch) goes through `undo_new_branch_checkout`. It removes the branch made and a worktree on that branch, as `_wt_add_repo` does, and reports a branch it cannot delete with the command to remove it. Tests: a failed checkout from origin (now also checks "removed again") and from the default branch. The second fails against the previous scripts (the branch was left) — `.agent/scripts/worktree_create.sh`, `.agent/scripts/tests/test_worktree_create.sh` (8a9d19ec)
- [x] (suggestion) `check_existing_branch_parent` trusting a stale local ref — `.agent/scripts/worktree_create.sh:76-81` (deferred to a follow-up issue the host will propose to the owner: this predates the pull request; host direction 2026-11-10)
- [x] (suggestion) WORKTREE_GUIDE now says that in a narrowed clone `@{u}` does not resolve, so `git status` shows no ahead/behind count, while pull and push work — `.agent/WORKTREE_GUIDE.md` (f78007f4)
- [x] (suggestion) The design.md inventory row's line numbers for `worktree_create.sh` — `docs/design.md:372` (deferred to a follow-up issue the host will propose to the owner: this predates the pull request; host direction 2026-11-10)

### Checks
- Intermediate commits used `SKIP=validate-script-tests`. Then `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP on f78007f4's tree: exit 0, `validate-script-tests` Passed. The call outran the Bash tool's 600 s limit and was moved to the background; it was waited for to its exit.
- Run by hand, 0 failures: test_worktree_create.sh 56, test_ros2_colcon.sh 218. Against HEAD's previous scripts (a `git archive` of 50e0b1d7), test_worktree_create.sh fails 3: the two workspace failed-checkout cases and the stale-parent draft PR case.
- shellcheck --severity=warning clean on the changed scripts.

### Not done
- run_script_tests.sh's citation of `worktree_create.sh`'s `/tmp` mktemp sites moved with these lines and was refreshed to 1088,1129 in 8a9d19ec. It is a consequence of this change, not a new item. The design.md inventory row (deferred above) is now further off for the same reason.
- A third scratch copy (`old3.*`) is in this session's scratchpad beside the earlier ones; `rm -rf` is denied.

## Local Review
**Status**: complete
**When**: 2026-11-10 12:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a852b1bb7dae4e0f6, resume 1 of 3)

**PR**: #417 at `40f56112`
**Depth**: Deep (reason: round 5 convergence check per handoff)
**Round**: 5 in PR mode. The handoff says "no cross-model reviewers", so this is the round-3+ convergence check: it reviews only the round-4 findings in scope (must-fix 1 and 2, suggestions 2 and 4) and the fix diff since `5e526275` (d09f44e8, 8a9d19ec, f78007f4).
**Must-fix**: 0 | **Suggestions**: 0

Verified:
- Must-fix 1 is resolved. Once `_wt_add_repo` has asked origin about the parent, the draft PR's base follows `WT_FETCH_OUTCOME = present`.
  - That value is the parent lookup's. `_wt_default_start_point`, which may run after it, never sets it.
  - "unknown" with `--allow-unverified-branch` therefore no longer targets the parent either, as on the workspace path.
  - The new test (stale `origin/feature/issue-9`, parent deleted on origin) fails against the previous scripts: a `git archive` of 50e0b1d7 with the new test file gives `pr create … --base feature/issue-9`.
- Must-fix 2 is resolved. The "owning branch reported" assertion is again `feature/issue-444`, the same string as on main (line 438) and at a378503a (line 443).
- Suggestion 2 is resolved. Every new-branch `worktree add -b` on the workspace path goes through `undo_new_branch_checkout`, which does the same as `_wt_add_repo`. A branch it cannot delete is reported with the command to remove it. The script runs `set -e` with cwd `$ROOT_DIR` (worktree_create.sh:32, :710), so `add || undo` is sound. The new failed-checkout case from the default branch fails against the previous scripts (the branch is left).
- Suggestion 4 is resolved. WORKTREE_GUIDE states the `@{u}` limit in a narrowed clone.
- Against the previous scripts, test_worktree_create.sh fails 3 cases: the two workspace failed-checkout cases and the stale-parent case.
- At 40f56112, 0 failures: test_worktree_create.sh 56, test_ros2_colcon.sh 218.
- Shellcheck --severity=warning is clean on the 3 changed scripts.
- run_script_tests.sh's citation `worktree_create.sh:1088,1129` matches the two `/tmp` mktemp lines.

Cross-model: skipped (round-5 convergence check, per handoff).

Deferred by the host to follow-up issues, not counted against this pull request:
- the round-4 suggestion 1 (concurrent-creation race);
- suggestion 3 (stale ref in `check_existing_branch_parent`);
- suggestion 5 (design.md inventory line numbers, now further off after 8a9d19ec moved lines).

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-11-10 12:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #417 at `2ba95e6`
**Sources**: 3 (Copilot, four real reviews on 2026-11-02 at older heads `b84987a`, `73080c9`, `fbf94d1`, `8318e77`; Local Review round 5 @ `40f5611` (covers `2ba95e6` via bookkeeping); CI rollup). Not sources: Copilot's five posts on today's heads (`4c54c30`, `a378503`, `71c0452`, `5e52627`, `40f5611`), each the notice "unable to review … insufficient remaining quota". No human review, no conversation comments.
**Cross-source confirmations**: 0
**CI**: pending

Round 5 (convergence check, approved, 0 must-fix) carries only the unticked "No issues found. LGTM." placeholder, which is not a finding (issue 362). Rounds 2 to 4 were each decided by their Implementation entries; their ticked boxes are not re-listed, except where re-ruled below. Outside reviewers on the local rounds: round 1 (pre-push) gemini and codex ran; round 2 (pre-push) gemini and codex ran; PR round 1 (2026-11-02 14:48) gemini and codex ran; round 2 gemini ran (short), codex ran; round 3 gemini failed (empty reply after a headless tool denial), codex ran; round 4 gemini failed (same), codex ran; round 5 none (convergence check). Copilot: real reviews only on 2026-11-02.

The four deferrals were checked against `origin/main`:
- The stale-ref trust in `check_existing_branch_parent` is inherited: main's `worktree_create.sh` 733-735 and 856-858 make the same `refs/remotes/origin/<parent>` check with no lookup.
- The design.md inventory offset is inherited: main's row (248-260 …) was off by the same amount. 8a9d19ec moved the lines further on this branch, but it is the same defect, and one follow-up fixes both.
- The concurrent-creation race is only partly inherited, so it stays open below. The project path's `rm -rf "$WORKTREE_DIR"` rollback is on main (lines 697, 711, 721). The workspace path on main ran `git worktree add -b` with no cleanup, so a run that lost the race just failed. This pull request added cleanup that deletes the other run's branch and worktree: `undo_new_branch_checkout` (5990ef1f, 8a9d19ec), and the per-repo `branch -D` in `_wt_add_repo`.

### Findings
- [x] (should-fix, Local Review @ `5e52627` round 4 suggestion 1 (codex), re-ruled here: partly introduced by this pull request) The failed-checkout cleanup can destroy another run's worktree. The "branch exists locally?" check runs before the origin lookup, which can take up to `WT_FETCH_TIMEOUT` (60 s): `_worktree_helpers.sh:730` sets `made_branch=true` there, and the workspace path checks at the same point. Suppose a second run for the same issue creates `<b>` and its worktree in that window. This run's `git worktree add -b` then fails because the branch already exists, and git makes nothing in that case. The cleanup still finds `refs/heads/<b>` and a worktree on it, so it runs `worktree remove --force` on the other run's worktree and `branch -D` on its branch (`worktree_create.sh:75-88`; `_wt_add_repo` 790-800). On main the workspace path only failed, and the project rollback never deleted another run's branch. Fix: check that `refs/heads/<b>` is absent immediately before each `worktree add -b`, not before the lookup. If it is present, stop and say another run created it, without undoing anything. The race is then confined to the add itself. The per-issue lock follow-up still covers the inherited `rm -rf` in the project rollback. Add a test: a git double creates the branch and worktree during the lookup, and the failed run leaves both in place — `.agent/scripts/worktree_create.sh`, `.agent/scripts/_worktree_helpers.sh`
- [x] (minor, Copilot @ `fbf94d1`, repeated @ `8318e77`; older heads; the only open Copilot thread) `--fill --fill=false` and `-f -f=false` are refused although gh's final value turns fill off: `_gh_note_body_from_gh` never removes a flag (`_gh_create_args.sh:208-210, 238, 242`). The same holds for pflag's other false spellings (`=0`, `=f`, `=F`, `=FALSE`, `=False`), which line 210 treats as true. The finding is valid, and it is this pull request's code (d84c8e64). Deferred. The reason holds on the facts: every misread errs towards refusing, never towards an unsigned issue or PR. The refusal is loud (exit 2) and names both ways through (`--body`/`--body-file`, `--no-signature`). The input is a self-contradicting flag pair. "More than two lines" is not a reason on its own (Quality Standard), but this is neither a silent failure nor missing validation. No follow-up issue carries it, so it goes into the Decision summary as a decision the owner may veto. Fixing it later: track each fill flag's last value with ParseBool's spellings, about 15 lines plus tests in both suites — `.agent/scripts/_gh_create_args.sh`
- [x] (must-fix, Copilot @ `b84987a` and `73080c9`; addressed) The review hold failed open when its first read of the review SHA failed. Fixed in 7d6d29ba: the hold is unresolved until the SHA is read, and the wait ends as `review-unreadable` at the grace deadline (`merge_pr.sh` 1270-1391, 1440). Fixtures ci-41 to ci-44 are present. Copilot itself listed both threads as "resolved since last review" at `fbf94d1` — `.agent/scripts/merge_pr.sh`
- [x] (high, Copilot @ `fbf94d1` "previously missed"; addressed) `--recover` with a body went out unsigned. 134003d4 refuses `--recover` without `--no-signature`, with or without a body (`_gh_create_args.sh` 289-297), with regressions in both suites — `.agent/scripts/_gh_create_args.sh`
- [x] (suggestion, Local Review @ `5e52627` round 4 suggestion 3) `check_existing_branch_parent` trusts a stale `refs/remotes/origin/<parent>` (deferred to a follow-up issue the host will propose to the owner: inherited, as main has the same check; host direction 2026-11-10) — `.agent/scripts/worktree_create.sh:95-101`
- [x] (suggestion, Local Review @ `5e52627` round 4 suggestion 5) design.md's inventory row cites `worktree_create.sh` lines about 23 off, and further off since 8a9d19ec (deferred to a follow-up issue the host will propose to the owner: the offset is inherited from main's row; host direction 2026-11-10) — `docs/design.md:372`

### False positives
- (Local Review @ `40f5611`) "No issues found. LGTM." is the clean review's placeholder line, not a finding (issue 362).

## Checkpoint
**Status**: complete
**When**: 2026-11-10 12:48 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the triage left one finding open and judged it partly this pull request's own doing: the new cleanup after a failed checkout can remove another run's worktree and branch; a destructive behaviour the pull request adds is fixed before the owner is asked to merge, not deferred)
**After**: findings
**Decision**: address

Host read the Integrated Review. One open finding, should-fix: both paths check that the branch is absent before the origin lookup, which can take up to 60 seconds; if a second run creates the branch in that window, this run's `worktree add -b` fails and the new cleanup then removes the other run's worktree and branch. Direction: check the branch is absent right before each `add -b`, and if it is present stop without undoing anything; test it with a git double that creates the branch during the lookup. The per-issue lock for the inherited `rm -rf` stays a follow-up issue for the owner to allow. Nothing else changes.

## Implementation
**Status**: complete
**When**: 2026-11-10 13:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #417 at `a6ead361`
**Addressed**: Integrated Review at `2ba95e6` (2026-11-10 12:47 -05:00)
**Commits**: a6ead361

### Actions
- [x] The failed-checkout cleanup could remove another run's branch and worktree when that run created the branch during this run's origin lookup. A new branch is now made by `wt_add_new_branch` (`_worktree_helpers.sh`): `git branch` right before the checkout, after the lookup, then `git worktree add <dest> <branch>`. `git branch` never takes over an existing branch, so its success is the proof the branch is this run's; status 1 (this run made it) is the only one the cleanup acts on, status 2 (made nothing) undoes nothing, and a branch present by then gets the message "another run created the branch ... this run made nothing and removes nothing". Both paths use it: the workspace path (`undo_new_branch_checkout <status> <start>`, `worktree_create.sh:70-92`, 920-956) and `_wt_add_repo` (`made_branch` set only from the helper's status). Tests: the git double's `STUB_RACE_BRANCH` creates the branch and a worktree at the same path during the lookup; one test per path asserts the run stops with the message and the other run's branch and worktree stay (`test_worktree_create.sh`, "A branch another run creates during the lookup is left alone"). Both tests fail on the previous scripts (branch gone) and pass now. Refreshed the `worktree_create.sh` mktemp citation in `run_script_tests.sh:348` (1088,1129 → 1091,1132) — `.agent/scripts/_worktree_helpers.sh`, `.agent/scripts/worktree_create.sh`

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP: exit 0, the script suites hook passed.
- `bash .agent/scripts/tests/test_worktree_create.sh`: 58 passed, 0 failed.

### Not done
- The project path's inherited `rm -rf "$WORKTREE_DIR"` after a failed first add (`worktree_create.sh` 788-799) still runs when `_wt_add_repo` refuses another run's branch; if that run's worktree is at the same `WORKTREE_DIR`, it is removed. Left to the per-issue lock follow-up, as directed; the `_wt_add_repo` test calls the helper directly and does not cover it.
- docs/design.md line citations (deferred by direction).

## Local Review
**Status**: complete
**When**: 2026-11-10 13:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a852b1bb7dae4e0f6, resume 2 of 3)

**PR**: #417 at `6458bb93`
**Depth**: Deep (reason: round 6 convergence check per handoff)
**Round**: 6 in PR mode. The handoff says "no cross-model reviewers", so this is the round-3+ convergence check. It covers the Integrated Review's one open finding, the race in the failed-checkout cleanup, and the fix diff since `2ba95e67` (a6ead361).
**Must-fix**: 0 | **Suggestions**: 1

Verified:
- The open finding is resolved for the window it named, the origin lookup of up to 60 s.
  - `wt_add_new_branch` makes the branch with `git branch` after the lookup. `git branch` refuses an existing branch, so status 2 (made nothing) undoes nothing on either path:
    - `undo_new_branch_checkout` exits before touching anything unless its status is 1;
    - `_wt_add_repo` sets `made_branch` only when the status is not 2.
  - `$?` on the right of `||` is the helper's status, and `set -e` does not cut it short.
- Both new tests fail against the previous scripts. A `git archive` of 2ba95e67 with the new test file gives "branch=gone" on both paths, and they pass now.
- An ordinary creation produces the same result as before. `git branch [--no-track] <b> <start>` followed by `git worktree add <dest> <b>` is equivalent to `git worktree add [--no-track] -b <b> <dest> <start>`:
  - the origin, parent and default start points are unchanged;
  - the parent paths still leave tracking to git's autoSetupMerge, as before;
  - the origin path still writes only the branch's own upstream settings.
  - The suite's narrowed-clone checks (refspec unchanged; `git fetch` works after origin deletes the branch) pass.
- At 6458bb93, with 0 failures: test_worktree_create.sh 58, test_ros2_colcon.sh 218.
- Shellcheck --severity=warning is clean on the 3 changed scripts.
- run_script_tests.sh cites `worktree_create.sh:1091,1132`; both lines are correct.
- The project path's `rm -rf "$WORKTREE_DIR"` after a refused first add is inherited. main does the same after any failed first add (main's worktree_create.sh 719-722), so it is not counted against this pull request. It belongs to the per-issue lock follow-up.

Cross-model: skipped (round-6 convergence check, per handoff).

Deferred by the host to follow-up issues, not counted against this pull request: the per-issue lock, which covers the inherited `rm -rf`; the stale ref in `check_existing_branch_parent`; the design.md inventory line numbers.

### Findings
- [ ] (suggestion) A small window remains between this run's `git branch` and its `git worktree add`, a few milliseconds. In it, a second run can see the new branch, take the existing-branch path and check it out at the same destination. This run's add then fails with status 1, and the cleanup removes that run's worktree and branch, because "a worktree on the branch this run made" does not prove the worktree is this run's. Reproduced with a git double on `_wt_add_repo`: the other run's worktree and branch were gone. This is the residual race the triage accepted ("confined to the add itself"), and the fix diff did not introduce it: the combined `add -b` had the same window. It is not a defect for this round; put it on the per-issue lock follow-up. If wanted, a cheaper tightening: in `wt_add_new_branch`, when `<dest>` already exists before `worktree add`, report "branch made, no worktree" so that the caller removes no worktree. `git branch -D` then refuses a branch that another worktree has checked out — `.agent/scripts/_worktree_helpers.sh:731-733`, `.agent/scripts/worktree_create.sh:80-82`

## Integrated Review
**Status**: complete
**When**: 2026-11-10 13:09 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a8a0228c7db7c496e, resume 1 of 3)

**PR**: #417 at `c396b75`
**Sources**: 3 (Local Review round 6 @ `6458bb9` (covers `c396b75` via bookkeeping); Copilot, whose only real reviews are the four of 2026-11-02 at older heads, ruled in the Integrated Review of 2026-11-10 12:47; CI rollup). Not sources: Copilot's posts on `2ba95e6` and `6458bb9`, like those on today's earlier heads, are each the notice "unable to review … insufficient remaining quota". No human review, no conversation comments.
**Cross-source confirmations**: 0
**CI**: pending

This triage builds on the Integrated Review at `2ba95e6` (2026-11-10 12:47). It covers the entries since then: the Checkpoint (address), the Implementation (a6ead361) and the round-6 Local Review (approved, 0 must-fix).

- **The previous triage's one open finding is resolved.** Another run's branch and worktree could be removed when that run created the branch during this run's origin lookup. Checked in the code at `c396b75`:
  - `wt_add_new_branch` (`_worktree_helpers.sh` 723-734) makes the branch with `git branch` after the lookup. That refuses an existing branch, so success proves this run made it.
  - Status 2 (made nothing) undoes nothing: `undo_new_branch_checkout` exits at `[ "$1" -eq 1 ] || exit 1` (`worktree_create.sh` 77-80), and `_wt_add_repo` sets `made_branch` only from the helper's status.
  - Round 6 reports that both new tests fail against `2ba95e67` ("branch=gone") and pass now: test_worktree_create.sh 58 and test_ros2_colcon.sh 218, 0 failures.
  - An ordinary creation is equivalent to the old `add -b`: same start points, same tracking.
- **The project path's `rm -rf "$WORKTREE_DIR"` is inherited.** Round 6 confirms main does the same after any failed first add (main's `worktree_create.sh` 719-722).

### Findings
- [x] (suggestion, Local Review @ `6458bb9` round 6) A gap of a few milliseconds remains between this run's `git branch` and its `git worktree add`. A second run can see the branch, check it out at the same destination, and this run's failed add then removes that worktree. The old single `add -b` had the same window, so the fix diff did not introduce it. Deferred to the per-issue lock follow-up the host will propose to the owner (host direction 2026-11-10), together with the inherited project-path `rm -rf`. The reviewer's cheaper tightening goes with that issue: when `<dest>` already exists before `worktree add`, report "branch made, no worktree", so no worktree is removed — `.agent/scripts/_worktree_helpers.sh:731-733`, `.agent/scripts/worktree_create.sh:80-82`

### False positives
- (Local Review @ `40f5611`) "No issues found. LGTM." is round 5's placeholder line, not a finding (issue 362); it is already ruled in the 12:47 Integrated Review.
