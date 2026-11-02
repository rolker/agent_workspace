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
