# Plan: Copilot review becomes optional: one request per pull request, with a cold cross-model read as the fallback

## Issue

https://github.com/rolker/agent_workspace/issues/452

## Context

The owner has disabled automatic Copilot review on all GitHub repositories (2026-11-23). PR 542 (issue 428 part 1) put into `run-issue` step 9 a ~900 s wait when no `copilot-pull-request-reviewer` check-run appears, after every publish and PR-mode Local Review. That is now paid on every PR for a review nobody asked for. The issue review's comment restates "What is needed" against main; the checkpoint settled six open questions (taken as given below).

## Approach

Commit 1 (urgent, lands first; if the work is split, PR (a) = steps 1-5, PR (b) = steps 6-9):

1. **`run-issue` step 9 rewrite** (`.claude/skills/run-issue/SKILL.md` ~915-990) — default: no Copilot request outstanding, so no wait; dispatch `triage-reviews` on the sources that exist. Keep the "wait ends on conclusion or a head-commit review" rule and the 900 s / 1800 s bounds only for the case where the loop itself requested a review. Remove "confirmed absent" waiting. Keep the could-not-review-notice paragraph (a notice is read, never held on).
2. **Pre-merge request, once per PR** (new sub-step in step 9, before the merge checkpoint) — after the last fix round: run `gh pr edit <M> --add-reviewer "@copilot"` once, record on the host's PR state that it was requested (a `## Review Requested`-free approach: the request is noted on the hand-back outside-reviewer line and in the following entry, no new entry type). Wait at most ~900 s for a head-commit review or a check-run conclusion. Outcomes: review arrived (triage reads it); command non-zero, quota notice, no check-run or no answer in the bound = "not available". Verified: `gh` 2.104.0 `gh pr edit --help` documents `--add-reviewer "@copilot"`. Not verified: behaviour under exhausted quota or accepted-but-unanswered; recorded as unverified, any non-review outcome is "not available", not tested against a real PR.
3. **Fallback cold read** — on "not available", run one `cross_model_review.sh --pr <M> --agent codex` (else `--agent gemini`) of the final diff with no earlier-round context; the helper's own timeline entry is the record (ADR-0013: the helper writes its entry; step 3 below confirms which entry type run-issue routes on, `## Local Review`-family vs `## External Review` is a predecessor-only name). Findings go through `triage-reviews`. Exactly one fallback read per PR.
4. **`merge_pr.sh`** (`.agent/scripts/merge_pr.sh` ~52, 146, 1741-1830, header comments) — decision: keep the bounded hold only on a Copilot check-run that exists and is running; absence never holds; a failed or quota-notice conclusion never holds. Make the header comments and the issue text say so; add tests only if the code path changes (read first; likely comment/doc plus tests pinning the three cases).
5. **Tests with stubbed `gh`** — extend `test_merge_pr_gate.sh` (absent / running / failed check-run), `test_triage_reviews_integration.sh` (no Copilot review is normal; notice review read), `test_cross_model_review.sh` (fallback invocation shape), and `test_merge_pr_skill.sh` if it pins step 9 text. No test touches a real PR or quota. Review each for Copilot-presence assumptions. New `test_*.sh` files, if any, need `chmod +x`.

Commit 2+ (consequences):

6. **Triage and fetch** — `triage-reviews/SKILL.md` ("Sources", examples) and `fetch_pr_reviews.sh` comments: absent Copilot is the ordinary case.
7. **Reports** — `.agent/knowledge/host_standing_rules.md` line 36, `run-issue` hand-back line, `orchestrator/SKILL.md`: one line per outside reviewer that was asked; Copilot appears only when requested.
8. **Audit and onboarding** — `audit-project/SKILL.md` (hygiene item ~244, skip rows ~254/256, prose ~65, 275, 313, 444, 452) and `onboard-project/SKILL.md` (~87, 654): item becomes "a review by someone other than the author's own session"; Copilot one way; no finding on a repo with no automatic rule; they do not re-enable the rule and give the hand request `gh pr edit <N> --add-reviewer "@copilot"`. Check `project_integration_audit.sh` (grep found no Copilot reference; confirm).
9. **Design text** (ADR-0017) — `docs/design.md` Review loop and timeline (~742 on, merge hold ~864, hygiene list ~287): independent review = Gemini and Codex before publishing plus one cold read after (Copilot if requested and available, else Codex/Gemini); state auto-review is off everywhere. Check `.agent/knowledge/skill_workflows.md` for step text.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/run-issue/SKILL.md` | Step 9 rewrite, pre-merge request, fallback, hand-back line |
| `.claude/skills/orchestrator/SKILL.md` | Outside-reviewer line |
| `.claude/skills/triage-reviews/SKILL.md` | Absent Copilot is normal |
| `.claude/skills/audit-project/SKILL.md`, `.claude/skills/onboard-project/SKILL.md` | Hygiene item reworded; manual request |
| `.agent/scripts/merge_pr.sh`, `.agent/scripts/fetch_pr_reviews.sh` | Comments; hold only on running check-run |
| `.agent/knowledge/host_standing_rules.md`, `.agent/knowledge/skill_workflows.md` | Reviewer-line wording, step text if present |
| `docs/design.md` | Review loop and timeline, hygiene list |
| `.agent/scripts/tests/test_merge_pr_gate.sh`, `test_triage_reviews_integration.sh`, `test_cross_model_review.sh`, `test_merge_pr_skill.sh` | Stubbed-`gh` cases for absent / running / failed / fallback |

## Prior Art

PR 542's step 9 bounds (900 s, 1800 s) and `merge_pr.sh`'s existing hold are reused, narrowed to requested reviews. `cross_model_review.sh` already provides the cold read; `gh pr edit --add-reviewer "@copilot"` is the existing request command (help text read). Rejected: re-adding a ruleset rule (burns quota per push), a local-model reviewer (out of scope).

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
| Test what breaks | Stubbed-`gh` tests for absent, running, failed, fallback |
| Verify before claiming | Request command read from `--help`; quota behaviour stated as unverified |
| Leave in a project only what it chose to carry | Automatic rule not re-enabled; manual request documented |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | Yes | Fallback read leaves a timeline entry; confirm entry type and run-issue routing before editing |
| ADR-0017 | Yes | design.md in the same PR |
| ADR-0010 | No | No issue read/write change |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| step 9 wait | hand-back line, orchestrator line, standing rule | Yes |
| merge hold wording | design.md ~864, merge_pr.sh header | Yes |
| hygiene item | audit-project, onboard-project, design.md ~287 | Yes |
| issue 428 remaining part | none (repo-slug helper; no step 9 overlap) | Yes, checked |

## Open Questions

- Which timeline entry type records the fallback cold read (the helper's own entry vs a named one); resolved by reading `cross_model_review.sh` and run-issue routing at step 3, not an owner question.
- Merge-hold decision and unverified quota behaviour are settled by the checkpoint (owner may veto).

## Estimated Scope

One PR (about ten files, one concept); if it grows, split loop and merge behaviour first, then audit, onboarding and design text.
