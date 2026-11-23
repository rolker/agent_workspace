---
issue: 452
---

# Issue #452 — Copilot review becomes optional: one request per pull request, with a cold cross-model read as the fallback

## Issue Review
**Status**: complete
**When**: 2026-11-23 16:58 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #452

### Scope Assessment

**Re-statement against main (2026-11-23).** The issue body (2026-11-12) predates two facts. (1) The owner has now disabled automatic Copilot review on all repositories on GitHub (quota allows a few days a month), not only the 29 repositories the body lists. (2) Pull request 542 (issue 428 part 1) put into `.claude/skills/run-issue/SKILL.md` step 9 a wait of about 900 s when no `copilot-pull-request-reviewer` check-run appears, plus a wait to completion when one is running. Verified in the file: it applies after every publish and every PR-mode Local Review. With automatic review off everywhere, that 900 s is paid on every pull request for a review that will not come. This is now the sharpest part of the issue, and it is a defect introduced after the issue was written.

Current "What is needed", restated:
1. **Step 9 stops waiting for Copilot by default.** No Copilot request is outstanding, so nothing is waited for. The 900 s bound and the "wait for a running check-run" rule apply only after the loop itself requested a Copilot review (once, at the pre-merge point), and the bound is then the "short, stated wait" the issue asks for. The measured arrival times in step 9 (most 1 to 6 min, outliers 17 and 30 min) can inform that bound, but a 900 s wait only when we asked is the ceiling, not the default.
2. **One request per pull request** at the point the pull request is otherwise ready for the merge decision. Verified: installed `gh` 2.104.0 documents `gh pr edit <N> --add-reviewer "@copilot"`, so the request command exists. What it does under exhausted quota is not yet verified; the plan must record that (the issue asks to record what was verified).
3. **Fallback**: one cold read by Codex, else Gemini, through `cross_model_review.sh`, when Copilot is unavailable (quota failure, or no answer in the stated wait).
4. **Absent is normal** in `run-issue` step 9, `triage-reviews`, `fetch_pr_reviews.sh` and `merge_pr.sh`. Verified in `merge_pr.sh`: a running Copilot check-run holds the merge up to `MERGE_PR_CI_TIMEOUT_SECONDS` (default 1800 s), then refuses with the review-pending error unless `--allow-pending-review`. The issue's "a failed or pending Copilot check never holds a merge" conflicts with that hold, which exists to avoid merging before a requested review lands. Decide: keep the hold only for a review the loop requested (or one already running), and never treat absence as pending. This needs a design decision on merge_pr.sh (#300 behaviour), not a quiet change.
5. **Audit**: `audit-project` hygiene item "Copilot auto-review" (SKILL.md line 244, plus the skip rows at 254 and 256 and the prose at 65, 275, 313, 444, 452) and `onboard-project` lines 87 and 654 become "a review by someone other than the author's own session", with Copilot one way to meet it. Acceptance: no finding on a repository with no automatic rule.
6. **Reports**: `host_standing_rules.md` line 36 lists "Gemini, Codex, Copilot"; change to name only reviewers that were asked. `run-issue` and `orchestrator` skills carry the same outside-reviewer line.
7. **Design text**: `docs/design.md` Review loop and timeline (line 742 on; line 864 mentions the Copilot hold; line 287 the hygiene list). Same change (ADR-0017).
8. **Projects**: onboarding and audit do not re-enable the automatic rule and say how to request by hand (`gh pr edit --add-reviewer "@copilot"`).
9. **Tests** with stubbed `gh`.

**Well-scoped?** Borderline. It touches about ten files across skills, scripts, knowledge and design, but all are one concept. It could be one pull request; if the plan grows, split into (a) loop and merge behaviour (items 1 to 4, 6, 9) and (b) audit, onboarding and design text (5, 7, 8). Item 1 is urgent because it costs 900 s per pull request now, so (a) should land first if split.
**Right repo?** Yes. All files are workspace infrastructure. The ruleset removal was already done on GitHub, so nothing remains in project repositories.
**Serves**: Quality of the work (independent review stays in the loop) and "A safeguard has to earn its cost" (a 900 s wait for a review that will not come costs more than it protects) - `docs/design.md#review-loop-and-timeline`
**Design picture?** Changes `docs/design.md#review-loop-and-timeline`: what the independent review is (Gemini and Codex before publishing, one cold read after, Copilot else fallback). The issue records the owner's decision (A and B together), so this is OK to proceed; no new question for the owner, except the merge hold in item 4 below.
**Dependencies**: Issue 428 part 1 (PR 542) is merged, and this changes what it added. Issue 428 remaining parts touch `run-issue` step 9 too (item 5 there, the quota-notice wait), so check for overlap before editing. Related: 342 (external reviewer contract), 353 (reviewer quotas). No blockers.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | Action needed | Rewrite step 9 so it does not wait on a Copilot review nobody requested. As written (900 s after every publish and PR-mode review) it is a standing cost with no review behind it. Wait only after the loop's own single request, with the stated bound. |
| Enforce what matters, as simply as possible | Action needed | Resolve the `merge_pr.sh` review hold against the issue's "a pending Copilot check never holds a merge": decide whether a running check-run on a requested review still holds (up to 1800 s) and record it in the plan; absence must never hold. |
| Keep one current design | OK | Design text is in scope (ADR-0017); owner decision recorded in the issue. Add the all-repositories fact to the design wording. |
| Test what breaks | Watch | Tests must cover: no check-run and no request (no wait), request made then quota failure (fallback cold read), request made and review arrives. Existing `test_merge_pr_gate.sh`, `test_triage_reviews_integration.sh` and `test_cross_model_review.sh` mention Copilot and need review. |
| Verify before claiming | Watch | Record what `gh pr edit --add-reviewer "@copilot"` does with exhausted quota and when the request is accepted but never answered; do not document it from the help text alone. |
| Leave in a project only what it chose to carry | OK | Projects only gain a documented manual request; the automatic rule is not turned back on. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (progress timeline) | Yes | The cold-read fallback must leave an entry on the timeline (acceptance). Check which entry type fits and that run-issue routes on it. |
| ADR-0017 (design with the change) | Yes | `docs/design.md` updated in the same change. |
| ADR-0010 (git-bug first) | No | No issue read/write path changes. |

### Consequences

- `docs/design.md` review loop section, line 864 (merge hold) and line 287 (hygiene list).
- `.claude/skills/run-issue/SKILL.md` step 9 and the hand-back line; `.claude/skills/orchestrator/SKILL.md` outside-reviewer line.
- `.agent/knowledge/host_standing_rules.md` line 36.
- `.claude/skills/audit-project/SKILL.md`, `.claude/skills/onboard-project/SKILL.md`, and `project_integration_audit.sh` if it checks the ruleset.
- `.claude/skills/triage-reviews/SKILL.md` examples and the "absent is normal" wording; `fetch_pr_reviews.sh`; `merge_pr.sh` header comments and hold logic.
- Tests listed above; the skill workflow table in `.agent/knowledge/skill_workflows.md` if step text is described there.

### Recommendations

- Update the issue's "What is needed" before planning: state that automatic Copilot review is off on all GitHub repositories (owner, 2026-11-23), and add the step 9 wait as item one, since it is a regression from PR 542 that costs 900 s per pull request today.
- Land the step 9 fix first (or as the first commit) so the loop stops waiting immediately; the rest can follow in the same pull request.
- Make the merge-hold decision explicit in the plan (keep the hold only for a requested, running review), and record the verified behaviour of `gh pr edit --add-reviewer "@copilot"` under quota failure.
- Check overlap with the remaining parts of issue 428 on `run-issue` step 9 before planning edits there.

### Actions
- [ ] Rewrite step 9 so it does not wait on a Copilot review nobody requested. As written (900 s after every publish and PR-mode review) it is a standing cost with no review behind it. Wait only after the loop's own single request, with the stated bound.
- [ ] Resolve the `merge_pr.sh` review hold against the issue's "a pending Copilot check never holds a merge": decide whether a running check-run on a requested review still holds (up to 1800 s) and record it in the plan; absence must never hold.
- [ ] Update the issue's "What is needed" before planning: state that automatic Copilot review is off on all GitHub repositories (owner, 2026-11-23), and add the step 9 wait as item one, since it is a regression from PR 542 that costs 900 s per pull request today.
- [ ] Land the step 9 fix first (or as the first commit) so the loop stops waiting immediately; the rest can follow in the same pull request.
- [ ] Make the merge-hold decision explicit in the plan (keep the hold only for a requested, running review), and record the verified behaviour of `gh pr edit --add-reviewer "@copilot"` under quota failure.
- [ ] Check overlap with the remaining parts of issue 428 on `run-issue` step 9 before planning edits there.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 16:55 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (every action is how the issue's own goal is met; none changes what the work is for or its scope)
**After**: issue-actions
**Decision**: proceed

The owner's direction for this drive (2026-11-23): "I've disabled automatic copilot reviews on all repos on github due to not having enough quota for more than a few days a month."

How the host settled the six actions, for plan-task to take as given (owner may veto):
- Step 9 wait: the loop waits for a Copilot review only after it has itself requested one (once per pull request, at the pre-merge point); with no request outstanding there is no wait. Fix lands as the first commit.
- Merge hold: `merge_pr.sh` keeps its bounded hold only on a Copilot check-run that exists and is running (which, with the automatic rule off, means one the loop requested); an absent check-run never holds, and a failed or quota-notice one never holds. This keeps the owner's "merge only when clean" rule (a review in flight is read before the merge) and his "nice to have, not something we rely on" (absence costs nothing).
- Issue body: not edited. The issue review's comment on the issue already restates "What is needed" against main with the owner's all-repositories fact; plan-task reads it there.
- One pull request unless the plan finds it too large; if split, loop and merge behaviour first.
- `gh pr edit --add-reviewer "@copilot"` behaviour under exhausted quota: plan records it as unverified and the implementation treats any non-review outcome as "not available"; it is not tested against a real pull request.
- Issue 428's remaining part (item 4, the repository-slug helper) does not touch run-issue step 9; no overlap to wait for.

## Plan Authored
**Status**: complete
**When**: 2026-11-23 16:57 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-452/plan.md` at `1fcece8b`

Step 9 stops waiting unless the loop itself requested Copilot once pre-merge; a Codex/Gemini cold read is the fallback; merge hold only on a running check-run; audit, onboarding, reports and design text follow in one PR (split loop and merge first if large).

## Plan Review
**Status**: complete
**When**: 2026-11-23 16:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #452 — Copilot review becomes optional: one request per pull request, with a cold cross-model read as the fallback
**Plan**: `.agent/work-plans/issue-452/plan.md` at `1fcece8b`
**Branch**: `feature/issue-452`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | About ten files, one idea; the split (loop and merge first) follows the checkpoint. |
| Issue alignment | Needs work | Covers all nine restated items. Serves line, as checked: "Goal 'Quality of the work' with the principle 'A safeguard has to earn its cost': `docs/design.md#review-loop-and-timeline`". The goal and the anchor exist (README.md:33, design.md:742). "A safeguard has to earn its cost" is a bullet under the goal (README.md:37), not a principle in docs/principles.md; the wording is loose but the goal is right. The acceptance "the fallback leaves a timeline entry" rests on a wrong fact (finding 1). |
| File targeting | Needs work | `fetch_pr_reviews.sh` and `orchestrator/SKILL.md` contain no Copilot text (grep), so the planned edits there are new text, not fixes; `skill_workflows.md:32` does name "Copilot review" in the hygiene list and must change (the plan only says "check"); `test_merge_pr_skill.sh` does not pin step 9 (grep). |
| Consequences | Good | design.md 287/864, host_standing_rules.md:36, audit/onboard lines, and the issue 428 overlap are all covered. `project_integration_audit.sh` mentions only `.github/copilot-instructions.md` (line 673), not the ruleset, so nothing to change there. |
| Principle alignment | Needs work | "Test what breaks": the planned merge-gate tests already exist (finding 3); the step 9 change is skill text, which the plan should say has no failing test, not imply stubbed-`gh` coverage. "Verify before claiming": the quota behaviour is honestly marked unverified. |
| ADR compliance | Needs work | ADR-0013 is triggered and its entry vocabulary is closed; the plan says the helper writes the fallback's entry, which it does not (finding 1). ADR-0017 is met (design.md in the same change). ADR-0010 not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[ADR compliance / Issue alignment]** Step 3 says "the helper's own timeline entry is the record". `cross_model_review.sh` writes no progress.md entry: its header (lines 4-11) says it writes prompt and findings files that are gitignored and "not part of the audit trail (durable findings live in progress.md)"; no `review_progress`/`progress_append` call exists in it. So the issue's acceptance ("the fallback leaves an entry on the timeline") has no writer in the plan as written. Resolve before implementing: either run the fallback through `review-code --pr <M>` restricted to one cross-model agent (it writes `## Local Review`, an existing ADR-0013 type that `triage-reviews` and run-issue already route on), or name who writes which existing entry type. A new entry type would need an ADR-0013 change and is not in scope. Also state how the "cold" read is kept cold: `review-code` embeds earlier context, `cross_model_review.sh` alone excludes `.agent/work-plans/**`.
2. **[Issue alignment]** "Once per PR" is recorded only "on the host's PR state" and the hand-back line, which do not survive a session restart (run-issue resumes from progress.md). Say how a resumed host knows a request was already made: for example from `gh pr view --json reviewRequests`/latestReviews, or a Copilot review or check-run in `fetch_pr_reviews.sh` output, or from the fallback's entry. Without it a resume can request twice or skip the fallback.
3. **[Principle alignment: Test what breaks]** Step 4/5's merge-gate cases are already pinned in `test_merge_pr_gate.sh`: failed Copilot run with green CI merges (ci-19), Copilot-only run counts as no checks (ci-22, ci-23), running Copilot with green CI holds (ci-25, plus the no-CI hold at line 2170), and `--allow-pending-review` overrides. `merge_pr.sh` (lines 146, 1741-1830) already implements the checkpoint's merge-hold decision. Step 4 is therefore comments and design text only; state that it was verified and drop the "extend absent/running/failed" tests rather than duplicate them. Name the tests that are actually new (e.g. a `triage-reviews` case with no Copilot review at all), and say the step 9 and fallback changes are skill text with no failing test.
4. **[Issue alignment]** Step 2 does not say what follows when the requested Copilot review (or the fallback) produces findings that are fixed: no second request and no second fallback (once per PR), and the fix goes through the existing PR-mode Local Review (row 22a/22b) and triage, after which step 9 must not wait again. One sentence closes the loop.
5. **[File targeting]** Drop or justify edits to `fetch_pr_reviews.sh` (no Copilot text) and keep the orchestrator change to its line 271 if the wording changes at all ("only the reviewers that were asked"); update `skill_workflows.md:32` ("Copilot review" in the hygiene list) as a definite consequence, not a "check".

Checkpoint decisions: none look wrong. The merge-hold decision matches the code as it stands (finding 3), and the issue 428 non-overlap is consistent with step 9's current text.

### Summary

The plan is the right shape and takes the checkpoint's six decisions correctly, but its fallback rests on a helper that writes no timeline entry, and its "once per PR" state does not survive a restart. Fix those two in the plan and trim the test list to what is new; then it is ready.

### Recommended Actions

- [ ] Replace step 3's "helper's own timeline entry" with a real writer and an existing ADR-0013 entry type (e.g. `review-code --pr` with one cross-model agent writing `## Local Review`), and say how the read stays cold.
- [ ] State how "requested once" and "fallback run once" are detected durably on resume (GitHub state or a timeline entry).
- [ ] Record that `merge_pr.sh` and `test_merge_pr_gate.sh` (ci-19, ci-22, ci-23, ci-25, line 2170) already implement and pin the merge-hold decision; limit step 4 to comments and design text and list only genuinely new tests.
- [ ] Add the after-findings sequence to step 2 (no re-request, existing re-review path, no new wait).
- [ ] Make `skill_workflows.md:32` a definite edit; drop `fetch_pr_reviews.sh` unless a concrete line is named.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 17:00 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (plan review verdict needs-work with two blocking findings; first host revise at plan)
**After**: plan
**Decision**: revise

The owner's direction for this drive (2026-11-23): "I've disabled automatic copilot reviews on all repos on github due to not having enough quota for more than a few days a month."

Revise the plan for all five Plan Review findings. Host decisions on the two blocking ones (owner may veto):
- Finding 1, the fallback's timeline entry: the cold read runs through the existing PR-mode `review-code` path, which writes `## Local Review` (a type the loop already routes on), with one cross-model reviewer (Codex, else Gemini) and a handoff that gives it the final diff only, no earlier review entries or findings. No new entry type, no new writer in `cross_model_review.sh`.
- Finding 2, "requested once" surviving a restart: the durable record is GitHub's own state for the pull request (a Copilot review request, review or check-run already on it, read with `gh pr view --json reviewRequests,reviews` and the check list), plus the fallback's `## Local Review` on the timeline. The host checks these before requesting; nothing new is stored by the host.
Findings 3 to 5 as the review states them: list only new tests (the merge hold already matches the decision and is pinned), say the step 9 and fallback changes are skill text with no failing test, state that fixes after Copilot or fallback findings go through the existing re-review path with no second request and no new wait, drop the `fetch_pr_reviews.sh` and orchestrator edits unless a named line needs them, make `skill_workflows.md:32` a definite edit, and drop `test_merge_pr_skill.sh`.

## Plan Authored
**Status**: complete
**When**: 2026-11-23 17:00 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-452/plan.md` at `71fe90e7`

Revision after plan review: fallback runs as a PR-mode review-code (cross-model only, final diff) writing `## Local Review`; "requested once" is read from GitHub PR state plus the fallback entry; merge hold verified as already implemented and pinned (comments only); tests trimmed to the new triage case; skill_workflows.md:32 a definite edit; fetch_pr_reviews.sh, orchestrator and test_merge_pr_skill.sh dropped.

## Plan Review
**Status**: complete
**When**: 2026-11-23 17:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #452 — Copilot review becomes optional: one request per pull request, with a cold cross-model read as the fallback
**Plan**: `.agent/work-plans/issue-452/plan.md` at `71fe90e7`
**Branch**: `feature/issue-452`

### Earlier findings (first Plan Review)

1. Fallback timeline entry: resolved. Step 3 runs the fallback as PR-mode `review-code` writing `## Local Review`, per the checkpoint; cold-ness holds (`cross_model_review.sh` embeds title, URL and diff only, excluding `.agent/work-plans/**`; the handoff skips 5a-5d and the Claude pass).
2. "Requested once" surviving a restart: partly resolved; a gap remains (new finding 2).
3. Tests: resolved. Step 4 records the merge hold as implemented and pinned (ci-19/22/23/25, `--allow-pending-review`), header comments only; skill text said to have no failing test.
4. After-findings sequence: resolved (step 2, last bullet).
5. File targeting: resolved. `fetch_pr_reviews.sh`, orchestrator and `test_merge_pr_skill.sh` dropped; `skill_workflows.md:32` a definite edit.

Checkpoint decisions: none look wrong.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | About ten files, one concept; split order (loop and merge first) kept. |
| Issue alignment | Needs work | Serves line, as checked: "Goal 'Quality of the work' with the principle 'A safeguard has to earn its cost': `docs/design.md#review-loop-and-timeline`" (README.md:33/37, design.md:742; the "principle" is a bullet under the goal, wording loose, goal right). Gaps in the once-per-PR rule and the fallback's routing (findings 1, 2). |
| File targeting | Good | Files match the work; `test_review_code_convergence.sh` exists and could carry the skill-text pin (finding 3). |
| Consequences | Needs work | The fallback `## Local Review` also counts as a PR-mode review round (finding 1). |
| Principle alignment | Good | Only what's needed, Test what breaks and Verify before claiming handled as the earlier review asked. |
| ADR compliance | Good | ADR-0013: existing `## Local Review` type, no new entry type. ADR-0017: design.md in the same change. ADR-0010 not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment / Consequences]** Step 3 says the fallback's "Findings go through `triage-reviews`." The router does not do that: `dispatch_phase.sh` (the `if base == "Local Review":` block, ~line 1213) sends a `## Local Review` to `triage-reviews` only when `**Verdict**: approved`; any other verdict goes straight to `address-findings`. So a cold read that finds something skips triage (review-code's own lead judgment is the only filter), and an approved one goes to triage and then step 9 ("host waits for reviews first"). Either accept that path and say so in step 3 and the design text, or name the routing change. Also: the fallback entry is a complete PR-mode `## Local Review`, so it counts in the PR-mode round count that `review-code`'s round-3 convergence check uses (review-code SKILL.md ~191-208); a fix round after it can reach round 3 one round early and skip cross-model. State whether that is accepted or how the fallback entry is excluded.
2. **[Issue alignment]** The durable "already requested" check (step 2) reads only GitHub state. When `gh pr edit --add-reviewer "@copilot"` exits non-zero, nothing lands on GitHub, so after the fallback runs, the next pass through the pre-merge point (after a fallback fix round, or on resume) finds no Copilot state and requests again. Make the skip condition "a Copilot request/review/check-run on GitHub **or** a fallback `## Local Review` on the timeline", and name the marker that tells the fallback entry apart from ordinary PR-mode re-reviews (e.g. the `**Depth**` reason text "cold read, cross-model only" that step 3 records, grepped by the host). Likewise say the ~900 s wait happens once, at the request, not whenever a request is visible on GitHub: an accepted-but-unanswered request stays in `reviewRequests`, and step 9 must not wait again on every later round.
3. **[Principle alignment: Test what breaks]** Step 4 leaves the review-code skill-text pin conditional ("check `ls ... | grep review_code`"). The check was run: `.agent/scripts/tests/test_review_code_convergence.sh` exists and pins the round-3 "no cross-model reviewers" path. Make the pin definite (a case for the new handoff words there, or say why not) and add the file to Files to Change. Minor.

### Summary

All five earlier findings are addressed and the checkpoints are followed. Three gaps remain. The plan's account of how fallback findings travel does not match the router. The once-per-PR rule can re-request or re-wait after a failed request. The skill-text pin is left conditional. Each is a few sentences of plan text. None changes the approach.

### Recommended Actions

- [ ] Step 3: state the real route of a fallback `## Local Review` (non-approved goes to `address-findings` directly, approved to `triage-reviews`), or name the router change; say how the fallback entry relates to the PR-mode round count.
- [ ] Step 2: skip the request when a fallback `## Local Review` exists, name the marker that identifies it, and tie the ~900 s wait to the request moment only.
- [ ] Step 4 / Files to Change: make the `test_review_code_convergence.sh` (or equivalent) pin for the "cold read, cross-model only" handoff words definite.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 17:06 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (second plan review needs-work, three plan-text gaps, approach unchanged; second host revise at plan in a row, so the next plan answer is the owner's)
**After**: plan
**Decision**: revise

The owner's direction for this drive (2026-11-23): "I've disabled automatic copilot reviews on all repos on github due to not having enough quota for more than a few days a month."

Revise for the three findings of the second Plan Review. Host decisions (owner may veto):
- Finding 1, routing: no router change. The plan states the real route: a fallback `## Local Review` that is approved goes to `triage-reviews`; any other verdict goes to `address-findings` and then the existing PR-mode re-review and triage path, as for any PR-mode Local Review. The fallback counting as a PR-mode round is accepted: it is itself the cross-model read, so a later round-3 convergence check without cross-model reviewers loses nothing the fallback did not already provide. State this in the plan.
- Finding 2, once per PR: adopt the review's fix. Skip the request when GitHub shows a Copilot request, review or check-run, OR a fallback `## Local Review` is on the timeline; name the marker that identifies the fallback entry (its `**Depth**` reason, e.g. "cold read, cross-model only"); the ~900 s wait happens once, right after the request is made, never again on later rounds even while the request stays listed in `reviewRequests`.
- Finding 3: add a definite case to `.agent/scripts/tests/test_review_code_convergence.sh` for the new handoff words and list it under Files to Change.

## Plan Authored
**Status**: complete
**When**: 2026-11-23 17:12 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-452/plan.md` at `e55a68e9`

Second revision: step 3 states the real routing (approved fallback to triage-reviews, other verdicts to address-findings; no router change, verified in dispatch_phase.sh) and accepts the fallback counting as a PR-mode round; step 2 skips the request on GitHub Copilot state OR a fallback Local Review marked by its `**Depth**` "cold read, cross-model only", with the ~900 s wait once at the request; step 4 adds a definite skill-text case to test_review_code_convergence.sh, listed in Files to Change.

## Plan Review
**Status**: complete
**When**: 2026-11-23 17:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #452 — Copilot review becomes optional: one request per pull request, with a cold cross-model read as the fallback
**Plan**: `.agent/work-plans/issue-452/plan.md` at `e55a68e9`
**Branch**: `feature/issue-452`

### Earlier findings (second Plan Review)

1. Fallback routing and round count: resolved. Step 3 states the real route (checked against `dispatch_phase.sh` ~1213: approved `## Local Review` to `triage-reviews`, any other verdict to `address-findings`) and accepts the fallback counting as a PR-mode round, as the checkpoint decided. The PR-mode round-3 words are written by a host, not appended by `dispatch_phase.sh` (its round-3 suffix applies only when there is no `--pr`), so the two handoff phrases do not collide.
2. Once per PR: resolved in substance. Skip on GitHub Copilot state OR the fallback entry, marker named (`**Depth**` containing "cold read, cross-model only"), the ~900 s wait tied to the request moment. Its scoping is incomplete (new finding 1).
3. Skill-text pin: resolved. A definite case in `.agent/scripts/tests/test_review_code_convergence.sh` (file exists), listed in Files to Change.

Checkpoint decisions: none look wrong. One note, not a finding: the issue says the fallback's "findings go through triage like any other source"; under the accepted routing a non-approved fallback reaches `triage-reviews` only after `address-findings` and the PR-mode re-review. The PR description should say so, as a stated deviation.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | About ten files, one concept; split order kept. |
| Issue alignment | Needs work | Serves line, as checked: "Goal 'Quality of the work' with the principle 'A safeguard has to earn its cost': `docs/design.md#review-loop-and-timeline`" (goal and anchor exist; the "principle" is a bullet under the goal, wording loose, goal right). All three acceptance lines are covered (hand-back line in step 6, no-wait default in step 1, audit wording in step 7), except that the fallback marker check can suppress a later PR's cold read (finding 1). |
| File targeting | Good | Files match the work; `test_triage_reviews_integration.sh` and `test_review_code_convergence.sh` both exist. |
| Consequences | Good | Covered as in the earlier reviews. |
| Principle alignment | Good | Only what's needed, Test what breaks (new cases only, skill text said to have no failing test) and Verify before claiming (quota behaviour unverified, stated). |
| ADR compliance | Good | ADR-0013: existing `## Local Review` type; ADR-0017: design.md in the same change; ADR-0010 not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment]** Step 2's timeline condition ("the timeline holds the fallback's `## Local Review`", found by the host grepping for "cold read, cross-model only") is not scoped, and as written it skips both the request and the fallback. Two ways it goes wrong: (a) the issue's second pull request (the plan itself allows a split into PR (a) and PR (b); run-issue step 13 starts a new PR after a `merge` answer) finds PR (a)'s fallback entry and gets neither a Copilot request nor a cold read, missing the acceptance "the cold read's entry is on the timeline" for that PR; (b) a whole-file grep matches the phrase in Checkpoint, Plan Review and Plan Authored entries: this issue's own progress.md already contains it four times (lines 206, 217, 231, 240), so PR 452 itself would skip its fallback. Fix in one sentence: match only a `**Depth**:` line inside a complete `## Local Review` entry from the current pull request's start (`pr_start.py` `pr_start`, the boundary run-issue's "Where a pull request ends" paragraph and review-code's round count already use).

Suggestion (not blocking): a session that restarts during the ~900 s wait resumes with a Copilot request on GitHub and no fallback entry; by step 2 it skips the request and the wait, but step 3 runs the fallback only on "not available", which that resume never determines. Say that a resumed host seeing a request with no Copilot review or concluded check-run and no fallback entry treats it as "not available" and runs the fallback (no new wait).

### Summary

All three findings of the second review are resolved and the checkpoints are followed. One gap remains: the fallback-entry check must be limited to `## Local Review` `**Depth**` lines since the current PR's start, or a split second PR (and this issue's own PR, by text match) skips its cold read. One sentence of plan text; the approach is unchanged.

### Recommended Actions

- [ ] Step 2: scope the fallback-entry check to a `**Depth**:` line in a complete `## Local Review` entry after the current PR's start (`pr_start.py`), not a grep of the whole timeline.
- [ ] (Suggestion) Step 2/3: on resume with a request listed but unanswered and no fallback entry, treat it as "not available" and run the fallback.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 17:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Owner's answer: "Proceed, fixes in handoff (Recommended)". Implementation goes ahead on plan.md at e55a68e9 with the third Plan Review's findings carried in the implement handoff, to be applied in the code and noted in the Implementation entry:
- F1 (blocking): the "fallback already ran" check counts only a complete `## Local Review` whose `**Depth**:` line carries "cold read, cross-model only" and that was written after the current pull request's start (`pr_start.py`'s boundary); never a whole-file match.
- F2: a Copilot request with no Copilot review, no concluded check-run and no fallback entry counts as "not available", so a run resumed during the wait still runs the fallback.
- Note for the PR description: a non-approved fallback reaches `triage-reviews` only after `address-findings` and the PR-mode re-review, a deviation from the issue's "go through triage like any other source".

## Implementation
**Status**: complete
**When**: 2026-11-23 17:23 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-452 at `dbc3435d`

Four commits on plan.md at `e55a68e9`, with the third Plan Review's findings applied per the owner's checkpoint:

- `21bb534b` (first commit, the urgent fix): `run-issue` step 9 no longer waits for Copilot unless the loop itself requested it. Triage is dispatched at once on the sources that exist; the 900 s / 1800 s bounds and the "what ends the wait" rule apply only to the one wait after the loop's own request. The could-not-review-notice paragraph is kept.
- `10747e37`: new `run-issue` step 9a (pre-merge request once per PR, at `checkpoint:merge`, then the cold read when Copilot is not available, with the real routing and the round-count consequence stated); `review-code` step 2 gains the converse of the round-3 words ("cold read, cross-model only": skip 5a-5d, run 5e with the one named agent, no earlier findings, record the words on `**Depth**`); new `review_progress.sh cold-read` subcommand; `pr_start.py` docstring and `merge_pr.sh` header comment only (merge hold verified unchanged); `script_reference.md` row.
- `f1470394`: `triage-reviews` (absent Copilot is normal, Sources examples), `host_standing_rules.md` outside-reviewer line (only the reviewers that were asked), `audit-project` hygiene item "Copilot auto-review" becomes "Independent review" (in place whenever the project uses PRs, no GitHub call, no finding without the automatic rule, never re-enabled, hand request `gh pr edit <N> --add-reviewer "@copilot"`; skipped on `github=no` and `prs=no`), `onboard-project` (never turns the rule on; hand request), `skill_workflows.md:32`.
- `dbc3435d`: `docs/design.md` (ADR-0017): Review loop and timeline bullet, Merge gate hold wording, hygiene list; three change-log rows.

**F1 applied (blocking)**: "the cold read already ran" is `review_progress.sh cold-read --progress <file>`, not a grep. It answers `cold_read=yes` only for a `## Local Review` (base type exactly that, never Pre-Push) with **Status** complete whose parsed `**Depth**` field contains "cold read, cross-model only", among the entries from `pr_start.py`'s `pr_start` (a restart does not move it). Tested: the words in a Checkpoint body, a Plan Review body and a finding line give `no`; a pre-push, partial or failed marked review gives `no`; a merged earlier PR's cold read gives `no` after the next part's start, the next PR's own gives `yes`; a restart keeps `yes`. On this issue's own timeline, which holds the words 7 times, it prints `cold_read=no`.
**F2 applied**: step 9a item 2 says a Copilot request or check-run with no Copilot review and no concluded check-run (and step 1 `no`) is "not available": the cold read runs with no new wait, so a run resumed during the wait still gets its fallback. A could-not-review notice is "not available" too.
**Deviation to carry to the PR description**: a non-approved cold read reaches `triage-reviews` only after `address-findings` and the PR-mode re-review (router unchanged: `dispatch_phase.sh` routes a `## Local Review` on `**Verdict**`), not "through triage like any other source" as the issue says; review-code's own lead judgment is the filter before the fix.
**Beyond the plan's file list**: `review_progress.sh` (the `cold-read` subcommand, so F1's scoped check is code with tests rather than host prose), `pr_start.py` (docstring), `script_reference.md`, `test_package_issue_loop.sh` (its dispatch-table pin lists every subcommand and needs a records-gate entry-point row for each), `test_skill_paths.sh` (it pinned the old audit item name).
**Unverified**: what `gh pr edit --add-reviewer "@copilot"` does under exhausted quota or when accepted and never answered (not tried against a real PR); every outcome that is not a review counts as "not available". Request reviewer login matching on `reviewRequests` ("a login that names Copilot") is not checked against a live response.

**Suites run** (each on its own with `bash`, final results): `test_review_code_convergence.sh`: 50 passed, 0 failed; `test_triage_reviews_integration.sh`: 70 passed, 0 failed; `test_package_issue_loop.sh`: 225 passed, 0 failed; `test_skill_paths.sh`: 200 passed, 0 failed; `test_dispatch_phase.sh`: 244 passed, 0 failed; `test_address_findings.sh`: 24 passed, 0 failed; `test_checkpoint_269.sh`: 43 passed, 0 failed; `test_issue_review_entry.sh`: 6 passed, 0 failed; `test_merge_pr.sh`: 175 passed, 0 failed; `test_merge_pr_gate.sh`: 213 passed, 0 failed; `test_merge_pr_root_resolution.sh`: 6 passed, 0 failed; `test_merge_pr_skill.sh`: 132 passed, 0 failed; `test_plan_correlation.sh`: 18 passed, 0 failed; `test_project_registry.sh`: 425 passed, 0 failed; `test_records_write_gate.sh`: 68 passed, 0 failed; `test_user_tier_guard.sh`: 64 passed, 0 failed. `test_package_issue_loop.sh` (2 pins) and `test_skill_paths.sh` (a workspace-relative path and a reworded pinned phrase) failed on the first run and were fixed and re-run. No `test_review_progress*.sh` or `test_pr_start*.sh` exists. Full pre-commit pass left to the host.

### Decision summary

- **Step 9 stops waiting**: automatic Copilot review is off on every repository (owner, 2026-11-23), so after publish and every PR-mode re-review the loop dispatches `triage-reviews` at once; no ~900 s wait for a review nobody asked for.
- **One Copilot request per PR** (`run-issue` step 9a), at the `merge` checkpoint: `gh pr edit <M> --add-reviewer "@copilot"`, waited for once (about 900 s, up to 1800 s while its check-run runs), never again on later rounds.
- **Cold read as fallback**: when Copilot is not available (request fails, could-not-review notice, no answer in the bound, or an unanswered request found on resume), one PR-mode `review-code` reads the final diff with one cross-model agent (Codex, else Gemini), no earlier findings, and records "cold read, cross-model only" on `**Depth**`.
- **"Asked once" survives a restart** with nothing new stored: GitHub's state plus `review_progress.sh cold-read`, which reads only that `**Depth**` field of a complete PR-mode `## Local Review` since the current PR's start (`pr_start.py`).
- **Routing deviation (stated)**: an approved cold read goes to `triage-reviews`; any other verdict goes to `address-findings` and the PR-mode re-review first, then triage, rather than "through triage like any other source" as the issue asked. No router change. The cold read counts as a PR-mode round for the round-3 check (accepted: it is itself the cross-model read).
- **Merge hold unchanged** (verified, already pinned by `test_merge_pr_gate.sh`): only a running review check-run holds; absent, failed or quota notice never holds. Header comment only.
- **Audit and onboarding**: "Copilot auto-review" becomes "Independent review", in place whenever the project uses PRs, no finding without the automatic rule, never re-enabled; hand request documented.
- **Unverified**: the request's behaviour under exhausted quota; any non-review outcome counts as "not available".

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 18:18 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-452 at `6ed21d63`
**Base**: main
**Depth**: Deep (reason: 18 files, +837/-69; skill and governance files)
**Must-fix**: 3 | **Suggestions**: 8
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) Step 9a item 1 builds the `cold-read --progress` path as `<worktree>/.agent/work-plans/...`; for a package issue the timeline is in the owning checkout, so a missing file gives a silent `cold_read=no` and a second cold read on every merge pass. Use the `D=$(dispatch_phase.sh where ...)` / `PF` pattern of lines 267/383/665 — `.claude/skills/run-issue/SKILL.md:1091`
- [x] (must-fix) Step 9a item 2 has no branch for a concluded `copilot-pull-request-reviewer` check-run with no Copilot review (step 9 lets the wait end on any conclusion; bullet 2 requires "no concluded check-run"). Classify it as "not available" (Gemini + Codex, cross-confirmed) — `.claude/skills/run-issue/SKILL.md:1108-1112`
- [x] (must-fix) Step 9a runs only on `action=checkpoint:merge`; a `findings` checkpoint answered `merge` (row 21) merges with no Copilot request and no cold read, missing the acceptance line "the cold read's entry is on the timeline". Run 9a before a `findings` checkpoint that offers `merge`, or state the skip to the owner — `.claude/skills/run-issue/SKILL.md:1080-1083`
- [x] (suggestion) A failed cold read (`**Status**: failed`) goes to `phase-failed`; a `retry` re-dispatches a plain step-4 review-code without the cold-read words (a full review, no marker, then a second cold read). Say a retry keeps the cold-read task line and switches to Gemini when Codex failed — `.claude/skills/run-issue/SKILL.md:1134`
- [x] (suggestion) "Review still running after 1800 s" and a resumed run with a running check-run are "not available", but `merge_pr.sh` still holds on that running check-run and refuses (review-pending) unless the owner passes `--allow-pending-review`; name that outcome in 9a — `.claude/skills/run-issue/SKILL.md:986-990`
- [x] (suggestion) Outside-reviewer line says Copilot "not requested yet" before the pre-merge point, contradicting the same paragraph and `host_standing_rules.md:36` ("Copilot is not named until it is requested") — `.claude/skills/run-issue/SKILL.md:1167`
- [x] (suggestion) The could-not-review paragraph still says "dispatch `triage-reviews`" while 9a treats the notice as "not available" and goes to the cold read; say which comes first during 9a's wait — `.claude/skills/run-issue/SKILL.md:954`
- [x] (suggestion) 9a runs before step 9's unread-review re-fetch, so an unread review with findings can lead to the one request/cold read being spent on a pre-fix diff; run the unread-review check first — `.claude/skills/run-issue/SKILL.md:1084`
- [x] (suggestion) 9a item 2 bullet 1 counts any Copilot review in the PR's history (e.g. one requested by hand on an early commit) as "available, nothing more requested"; say whether it must be on the head or accept it explicitly — `.claude/skills/run-issue/SKILL.md:1108`
- [x] (suggestion) The "Independent review" hygiene item is "in place" whenever the project uses PRs, with no check at all, so it can never report anything; consider dropping it (the issue allowed that) or checking something real — `.claude/skills/audit-project/SKILL.md:244`
- [x] (suggestion) Stale text: "we have Copilot review working via default behavior" — `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md:877`

## Implementation
**Status**: complete
**When**: 2026-11-23 18:22 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-452 at `5d5c332f`
**Addressed**: Local Review (Pre-Push) at `6ed21d63` (2026-11-23 18:18 -05:00)
**Commits**: 780eb5b6 6dad3c90 cf2f4080 927ebf39 73f435d3 5a682a4b a8a40573 7d82d8e2 9f06ca0a 194703fa 5d5c332f

### Actions
- [x] (must-fix 1) 9a item 1 reads the timeline at `PF` from `dispatch_phase.sh where`, stops on a missing file, says why (a package issue's worktree has no timeline; a missing file reads `cold_read=no`) — `.claude/skills/run-issue/SKILL.md` step 9a item 1 (780eb5b6)
- [x] (must-fix 2) a concluded `copilot-pull-request-reviewer` check-run with no Copilot review is "not available", in item 2's state bullets and among the outcomes after the request — `.claude/skills/run-issue/SKILL.md` step 9a item 2 (6dad3c90)
- [x] (must-fix 3, host-settled) 9a runs before every merge: at `checkpoint:merge` and on a `findings` checkpoint answered `merge` (after step 11's re-fetch, before `merge_pr.sh`); a merge answer stands only when 9a has nothing left to route, else the loop returns to a checkpoint; step 11 and design.md (Independent review bullet, change-log row) updated — `.claude/skills/run-issue/SKILL.md` steps 9a/9/11, `docs/design.md` (cf2f4080, 5d5c332f)
- [x] (suggestion 1) a failed or partial cold read goes to `phase-failed`; a retry keeps the cold-read task line, names Gemini when Codex failed; a takeover writes the same cold read — `.claude/skills/run-issue/SKILL.md` step 9a item 3 (927ebf39)
- [x] (suggestion 2, host-settled) a check-run still running past 1800 s: "not available" sends 9a to the cold read, but `merge_pr.sh` keeps its hold and refuses without `--allow-pending-review`, which only the owner grants at the merge checkpoint — `.claude/skills/run-issue/SKILL.md` step 9 wait bullet and 9a item 2 (73f435d3)
- [x] (suggestion 3) outside-reviewer line no longer says Copilot "not requested yet"; Copilot is named only once requested, matching `host_standing_rules.md` — `.claude/skills/run-issue/SKILL.md` end of 9a (5a682a4b)
- [x] (suggestion 4) could-not-review paragraph: during 9a's wait the notice goes to the cold read first, triage reads it later; outside 9a's wait, triage at once — `.claude/skills/run-issue/SKILL.md` step 9 (a8a40573)
- [x] (suggestion 5, host-settled with must-fix 3) 9a runs after step 9's unread-review re-fetch, stated in 9a and in the re-fetch paragraph — `.claude/skills/run-issue/SKILL.md` (cf2f4080)
- [x] (suggestion 6) a Copilot review on any commit of the pull request counts, accepted explicitly with the reason (a head-only rule would re-request after every fix round; a hand-requested earlier review counts as the one request) — `.claude/skills/run-issue/SKILL.md` step 9a item 2 (7d82d8e2)
- [x] (suggestion 7) audit-project's Independent review item is marked informational (never `missing`), says what meets it (pull requests merged through the review loop's cold read) and its report line; `test_skill_paths.sh` asserts both phrases — `.claude/skills/audit-project/SKILL.md` §8, `.agent/scripts/tests/test_skill_paths.sh` (9f06ca0a)
- [x] (suggestion 8) stale "Copilot review working via default behavior" replaced with a dated note that automatic review is off — `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md:877` (194703fa)

### Checks
- `bash .agent/scripts/tests/test_skill_paths.sh`: `test_skill_paths: 200 passed, 0 failed` (skill/knowledge text and that suite changed).
- No script under `.agent/scripts/` changed, so no other suite applies. Commits made with `SKIP=validate-script-tests` (dispatched-pass hook rule); the full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 18:28 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ae1d788436c60f74d, resume 1 of 3)

**Branch**: feature/issue-452 at `2a058ffe`
**Base**: main
**Depth**: Deep (reason: whole diff 19 files, +968/-75; skill and governance files)
**Must-fix**: 2 | **Suggestions**: 8
**Round**: 2 | **Ship**: recommended — round 2: 2 mechanical must-fix (prev 3), not rising — fix and ship rather than another full round

### Findings
- [x] (must-fix) The cold read (and its retry) can go to a resumed `review-code` agent under step 4a, which already holds every earlier finding, defeating "no earlier review entries or findings"; add the cold read and its retry to 4a's never-reuse list, or say "fresh agent" in 9a item 3 — `.claude/skills/run-issue/SKILL.md:528` / `:1192-1214`
- [x] (must-fix) With neither Codex nor Gemini available, the merge question is asked again but that answer does not stand (not in the "nothing to route" list at :1114-1116), and step 11 re-runs 9a on every `findings`-answered merge: an endless re-ask; an unread could-not-review notice is also never triaged on that path, so step 11's re-fetch blocks the merge again. Send an unread notice to `triage-reviews` first, and say a merge answer given after "no cold read possible" stands — `.claude/skills/run-issue/SKILL.md:1110-1116, 1196-1205, 1286`
- [x] (suggestion) The three new change-log rows give 1239 lines; `wc -l docs/design.md` prints 1240 — `docs/design.md:1184-1186`
- [x] (suggestion) With `github=unknown` the Independent review item is reported "in place (informational)" though there may be no GitHub PR; list it under `not checked: github=unknown` (adversarial + Gemini) — `.claude/skills/audit-project/SKILL.md:244, 274-277`
- [x] (suggestion) A check-run that concludes `success` a few seconds before Copilot's review is visible becomes "not available" and spends the cold read; re-poll once briefly on a non-failure conclusion — `.claude/skills/run-issue/SKILL.md:967, 1184`
- [x] (suggestion) When both Codex and Gemini fail the cold read, a `takeover` stamps a Claude-only review with "cold read, cross-model only"; route it to the no-agent owner-decision path instead — `.claude/skills/run-issue/SKILL.md:1205-1213`
- [x] (suggestion) `cold-read` does not match the entry's PR number, so a PR closed and replaced without a `merge` checkpoint inherits the old PR's cold read (Codex) — `.agent/scripts/review_progress.sh:815`
- [x] (suggestion) In cold-read mode review-code's PR-mode step 1a still fetches `comments,reviews` into the lead's context; give cold-read mode a metadata query without them (Codex) — `.claude/skills/review-code/SKILL.md:116, 219`
- [x] (suggestion) "A review not yet read", below" points to a section above (line 1035) — `.claude/skills/run-issue/SKILL.md:1100`
- [x] (suggestion) The Plan Review fixture writes `Depth:` without bold, so it never tests the `base_type` guard on a parsed `**Depth**` field; use `**Depth**: cold read, cross-model only` — `.agent/scripts/tests/test_review_code_convergence.sh:306`

## Implementation
**Status**: complete
**When**: 2026-11-23 18:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af605468d1e45efa8, resume 1 of 3)

**Branch**: feature/issue-452 at `a3cc8a43`
**Addressed**: Local Review (Pre-Push) at `2a058ffe` (2026-11-23 18:28 -05:00)
**Commits**: 5c60c91d dcb5a15f c54078c9 94a67200 b0ac5c81 e573715d c04fe975 dadd8d63 7c7449e9 d11452a0 a3cc8a43

### Actions
- [x] (must-fix 1) the cold read and any retry of it are on step 4a's never-reuse list and always go to a fresh agent; 9a item 3 says so too — `.claude/skills/run-issue/SKILL.md` step 4a, step 9a item 3 (5c60c91d)
- [x] (must-fix 2) with neither Codex nor Gemini available: an unread Copilot notice goes to `triage-reviews` first; the outside-reviewer line says "no cold read possible"; a `merge` answer given after that stands (step 11 does not re-run 9a for it; the Checkpoint text records it) — `.claude/skills/run-issue/SKILL.md` step 9a intro and item 3, step 11 (dcb5a15f)
- [x] (suggestion 1) change-log rows for #452 give 1240 lines, matching `wc -l` — `docs/design.md:1184-1186` (c54078c9)
- [x] (suggestion 2) with `github=unknown`, independent review is reported `not checked: github=unknown` with branch protection and component labels; `test_skill_paths.sh` pins the phrase — `.claude/skills/audit-project/SKILL.md` (94a67200)
- [x] (suggestion 3) a Copilot check-run concluding other than `failure` with no review on the head gets one more poll about 60 s later before "not available" — `.claude/skills/run-issue/SKILL.md` step 9 wait, step 9a item 2 (b0ac5c81). Skill text only, no suite covers host polling.
- [x] (suggestion 4) a takeover writes the cold-read words only when the host itself runs Codex or Gemini; with neither, it writes a complete `## Local Review` of its own read with `**Depth**: <tier> (reason: no cold read possible: Codex and Gemini unavailable)` (no marker, so `cold-read` stays `no`; not `failed`, which would loop back to phase-failed), and the next pass takes the no-agent path — `.claude/skills/run-issue/SKILL.md` step 9a item 3 (e573715d)
- [x] (suggestion 5) `review_progress.sh cold-read --pr <M>`: only a cold read correlated to that pull request counts; 9a passes it; script_reference.md and design.md updated; three new cases in `test_review_code_convergence.sh` — `.agent/scripts/review_progress.sh` cmd_cold_read (dadd8d63)
- [x] (suggestion 6) review-code step 1a gives cold-read mode a metadata query without `comments,reviews`; text pin added — `.claude/skills/review-code/SKILL.md` step 1a, step 2 (7c7449e9)
- [x] (suggestion 7) "A review not yet read", below -> above — `.claude/skills/run-issue/SKILL.md:1110` (d11452a0)
- [x] (suggestion 8) the Plan Review fixture writes `**Depth**: cold read, cross-model only`, now a parsed field (checked: `progress_read.py` returns it as the entry's Depth), so the `base_type` guard is exercised — `.agent/scripts/tests/test_review_code_convergence.sh:306` (a3cc8a43)
- [x] (found while testing, not a review finding) round 1's step 9a `where` block made `test_package_issue_loop.sh` count 4 blocks against its expected 3 (1 failure); the test now expects 4 and adds a case: 9a's block on a package issue with no timeline stops, never prints `cold_read=no` (c04fe975)

### Checks
- `bash .agent/scripts/tests/test_address_findings.sh`: `24 passed, 0 failed`
- `bash .agent/scripts/tests/test_issue_review_entry.sh`: `6 passed, 0 failed`
- `bash .agent/scripts/tests/test_package_issue_loop.sh`: `228 passed, 0 failed` (was 226 passed, 1 failed before c04fe975)
- `bash .agent/scripts/tests/test_plan_correlation.sh`: `18 passed, 0 failed`
- `bash .agent/scripts/tests/test_review_code_convergence.sh`: `54 passed, 0 failed`
- `bash .agent/scripts/tests/test_records_write_gate.sh`: `68 passed, 0 failed`
- `bash .agent/scripts/tests/test_dispatch_phase.sh`: `244 passed, 0 failed`
- `bash .agent/scripts/tests/test_triage_reviews_integration.sh`: `70 passed, 0 failed`
- `bash .agent/scripts/tests/test_skill_paths.sh`: `200 passed, 0 failed`
- Suites chosen by the grep for `review_progress.sh` (the one script changed), plus test_skill_paths.sh (skill text). Commits used `SKIP=validate-script-tests`; the full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 18:41 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent ae1d788436c60f74d, resume 2 of 3)

**Branch**: feature/issue-452 at `6e9b7618`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings

Cross-model: skipped (round-3 convergence check, per handoff). Scope: the round-2 entry's 10 findings and the fix diff 179e333d..6e9b7618, including the extra `cold-read --pr` and review-code step 1a changes. All 10 verified fixed; `cold-read --pr` takes the PR number run-issue's `<M>` holds and matches the entry's parsed `**PR**` correlation (tested yes/no/usage). Suites: test_review_code_convergence 54/0, test_package_issue_loop 228/0, test_skill_paths 200/0.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 18:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (the full pass failed; the owner's 2026-11-13 rule sends a failure back as findings)
**After**: publish
**Decision**: address

The host's full pre-commit pass over the branch (`pre-commit run --files $(git diff --name-only origin/main...HEAD)`, no SKIP) failed in the script-tests hook:

```
run_script_tests: 1 of 49 suites failed in 619s: test_script_tests_hook_scope.sh
  FAIL: 'test_review_code_convergence.sh' derives a real repo root (matched the root-derivation scan) but has no ROOT_READERS entry -- add one naming the out-of-tree prefixes it reads, or an empty entry if it only reads its own sandbox
test_script_tests_hook_scope: 347 passed, 1 failed
```

The same suite passes on main (347 passed, 0 failed), so the branch's changes to `test_review_code_convergence.sh` caused it. Every other hook and the other 48 suites passed.
