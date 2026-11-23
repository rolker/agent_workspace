# Plan: Copilot review becomes optional: one request per pull request, with a cold cross-model read as the fallback

## Issue

https://github.com/rolker/agent_workspace/issues/452

## Context

The owner has disabled automatic Copilot review on all GitHub repositories (2026-11-23). PR 542 (issue 428 part 1) put into `run-issue` step 9 a ~900 s wait when no `copilot-pull-request-reviewer` check-run appears, after every publish and PR-mode Local Review. That is now paid on every PR for a review nobody asked for. The issue review's comment restates "What is needed" against main; the checkpoint settled six open questions (taken as given below).

## Approach

Commit 1 (urgent, lands first; if the work is split, PR (a) = steps 1-4, PR (b) = steps 5-8):

1. **`run-issue` step 9 rewrite** (`.claude/skills/run-issue/SKILL.md` ~915-990) — default: no Copilot request outstanding, so no wait; dispatch `triage-reviews` on the sources that exist. Keep the "wait ends on conclusion or a head-commit review" rule and the 900 s / 1800 s bounds only for a review the loop itself requested. Remove "confirmed absent" waiting. Keep the could-not-review-notice paragraph (a notice is read, never held on).
2. **Pre-merge request, once per PR** (new sub-step in step 9, after the last fix round, before the merge checkpoint).
   - *Durable "requested once" state*: before requesting, the host reads GitHub's own state for the PR: `gh pr view <M> --json reviewRequests,reviews` and the check-run list (a Copilot request, review or `copilot-pull-request-reviewer` check-run already present = already requested; do not request again). The fallback's `## Local Review` entry on the timeline is the record that the fallback ran. Nothing new is stored by the host, so a resumed run cannot request twice or run the fallback twice.
   - Request: `gh pr edit <M> --add-reviewer "@copilot"`, once; wait at most ~900 s for a head-commit review or a check-run conclusion. Outcomes: review arrived (triage reads it); non-zero exit, quota notice, no check-run, or no answer in the bound = "not available".
   - Verified: `gh` 2.104.0 `gh pr edit --help` documents `--add-reviewer "@copilot"`. Not verified: behaviour under exhausted quota or accepted-but-unanswered; recorded as unverified, any non-review outcome is "not available", not tested against a real PR.
   - *After findings*: fixes from a Copilot or fallback review go through the existing fix-round path (`address-findings`, then the PR-mode Local Review, rows 22a/22b, and `triage-reviews`). No second request, no second fallback, and step 9 does not wait again.
3. **Fallback cold read** — on "not available" and no earlier fallback `## Local Review` on the timeline, the host dispatches one PR-mode `review-code --pr <M>` restricted to one cross-model reviewer (Codex, else Gemini), its handoff giving the final diff only (no earlier review entries or findings; the helper already excludes `.agent/work-plans/**`). It writes `## Local Review`, an existing ADR-0013 type the loop already routes on; no new entry type and no new writer in `cross_model_review.sh` (which writes no entry: verified from its header). `review-code/SKILL.md` has only the "no cross-model reviewers" handoff words today (round-3 check), so add the converse: handoff words "cold read, cross-model only" that skip 5a-5d and the Claude adversarial pass, run 5e with the one named agent, and record `**Depth**` accordingly. Findings go through `triage-reviews`. Exactly one fallback read per PR.
4. **`merge_pr.sh` and tests** — verified, no code change: `merge_pr.sh` (lines ~146, 1741-1830) already implements the checkpoint's merge-hold decision (hold only on a running Copilot check-run; absent, failed or notice never holds), pinned by `test_merge_pr_gate.sh` ci-19, ci-22, ci-23, ci-25, the no-CI hold near line 2170, and the `--allow-pending-review` override. Edit only the header comments to say "a review the loop requested (the automatic rule is off everywhere)". New tests only where behaviour is new: a `test_triage_reviews_integration.sh` case with no Copilot review at all (normal, no wait or error), and a `review-code` skill-text pin if an existing skill-text test pattern fits (check `ls .agent/scripts/tests | grep review_code`). The step 9 and fallback changes are skill text; there is no failing test for them, and the plan does not claim stubbed-`gh` coverage of them. New `test_*.sh` files, if any, need `chmod +x`.

Commit 2+ (consequences):

5. **Triage** — `triage-reviews/SKILL.md` ("Sources", examples): absent Copilot is the ordinary case. `fetch_pr_reviews.sh` has no Copilot text (grep), so it is not edited.
6. **Reports** — `.agent/knowledge/host_standing_rules.md` line 36 ("Gemini, Codex, Copilot" becomes the reviewers that were asked) and the `run-issue` hand-back/outside-reviewer lines (~940, ~967). `orchestrator/SKILL.md` line 271 already says "one line per outside reviewer" with no Copilot text; leave it unless implementation shows a named line needs it.
7. **Audit and onboarding** — `audit-project/SKILL.md` (hygiene item ~244, skip rows ~254/256, prose ~65, 275, 313, 444, 452) and `onboard-project/SKILL.md` (~87, 654): item becomes "a review by someone other than the author's own session"; Copilot one way; no finding on a repo with no automatic rule; no re-enabling of the rule; give the hand request `gh pr edit <N> --add-reviewer "@copilot"`. `project_integration_audit.sh` mentions only `.github/copilot-instructions.md` (line 673); no change. `.agent/knowledge/skill_workflows.md` line 32 names "Copilot review" in the hygiene list: definite edit.
8. **Design text** (ADR-0017) — `docs/design.md` Review loop and timeline (~742 on, merge hold ~864, hygiene list ~287): independent review = Gemini and Codex before publishing plus one cold read after (Copilot if requested and available, else Codex/Gemini via `review-code`); state auto-review is off everywhere.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/run-issue/SKILL.md` | Step 9 rewrite, pre-merge request with GitHub-state check, fallback dispatch, hand-back line |
| `.claude/skills/review-code/SKILL.md` | Handoff words for a cross-model-only cold read |
| `.claude/skills/triage-reviews/SKILL.md` | Absent Copilot is normal |
| `.claude/skills/audit-project/SKILL.md`, `.claude/skills/onboard-project/SKILL.md` | Hygiene item reworded; manual request |
| `.agent/scripts/merge_pr.sh` | Header comments only |
| `.agent/knowledge/host_standing_rules.md`, `.agent/knowledge/skill_workflows.md` | Reviewer-line wording; hygiene list (line 32) |
| `docs/design.md` | Review loop and timeline, hygiene list |
| `.agent/scripts/tests/test_triage_reviews_integration.sh` | Case: no Copilot review present |

## Prior Art

PR 542's step 9 bounds (900 s, 1800 s) and `merge_pr.sh`'s existing hold are reused, narrowed to requested reviews. `cross_model_review.sh` (via `review-code` 5e) already provides the cold read and `review-code` writes the timeline entry; `gh pr edit --add-reviewer "@copilot"` is the existing request command (help text read). Rejected: re-adding a ruleset rule (burns quota per push), a local-model reviewer (out of scope).

## Serves

Goal "Quality of the work" with the principle "A safeguard has to earn its cost": `docs/design.md#review-loop-and-timeline`.

## Design Picture

Changes `docs/design.md#review-loop-and-timeline` (what the independent review is, the merge hold) and the hygiene list; updated in this change.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | No wait without a request; one request and one fallback read per PR |
| Enforce what matters, as simply as possible | Merge hold kept only for a running check-run; absence/failure never holds |
| Keep one current design | design.md edited in the same change |
| Test what breaks | Merge-hold cases already pinned (ci-19/22/23/25); only the no-Copilot triage case is new; skill text has no failing test, said so |
| Verify before claiming | Request command read from `--help`; quota behaviour stated as unverified |
| Leave in a project only what it chose to carry | Automatic rule not re-enabled; manual request documented |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | Yes | Fallback read is a PR-mode `review-code` writing `## Local Review`; no new entry type |
| ADR-0017 | Yes | design.md in the same PR |
| ADR-0010 | No | No issue read/write change |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| step 9 wait | hand-back line, standing rule, review-code handoff words | Yes |
| merge hold wording | design.md ~864, merge_pr.sh header | Yes |
| hygiene item | audit-project, onboard-project, skill_workflows.md:32, design.md ~287 | Yes |
| issue 428 remaining part | none (repo-slug helper; no step 9 overlap) | Yes, checked |

## Open Questions

- None blocking. Merge-hold decision, the fallback through `review-code`, durable request state from GitHub, and the unverified quota behaviour are settled by the checkpoints (owner may veto).

## Estimated Scope

One PR (about ten files, one concept); if it grows, split loop and merge behaviour first, then audit, onboarding and design text.
