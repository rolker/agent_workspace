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
