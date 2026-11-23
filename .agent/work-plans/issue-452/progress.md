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
