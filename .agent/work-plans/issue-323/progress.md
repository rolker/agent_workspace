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
