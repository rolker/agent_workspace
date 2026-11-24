---
issue: 579
---

# Issue #579 — review-plan: reviewer reads stale PR body instead of current plan file

## Issue Review
**Status**: complete
**When**: 2026-11-24 13:14 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #579

### Scope Assessment

**Well-scoped?** Yes, once trimmed. The defect is present here as described, in `.claude/skills/review-plan/SKILL.md` step 1, "PR number" form, lines 70-79. Line 71 says "plan is in the PR body" and line 72 fetches `title,body,baseRefName,headRefName,files,url`; line 75 takes the linked issue from the first `#N` in that body. `plan-task` step 8 builds that body once, as `Closes #<N>` plus a copy of `plan.md` (`plan-task/SKILL.md` lines 349-352), and `plan-task` itself says inline plan edits during implementation leave the body a snapshot (lines 418-422). So a plan review run by PR number can judge a stale snapshot. What does not apply: the issue's "never reads PR comments". The plan is never in a comment, so reading comments would not help; drop it. The loop itself is not exposed: `dispatch_phase.sh` line 443 runs `review-plan --issue <N>`, which reads the live file. Only the by-hand `/review-plan <pr-number>` form is affected. Lines 78-79 already tell the reader to find `plan.md` in the PR's changed files, and the Step 5 note already gives the correct read (`git show <headRefOid>:./.agent/work-plans/issue-<issue>/plan.md`), but the `--json` list in line 72 does not fetch `headRefOid`, and the body is still presented as the plan.
**Right repo?** Yes, workspace skill file.
**Serves**: Quality of the work — `docs/design.md#review-loop-and-timeline`
**Design picture?** No change. The design section describes the phases, not which form of `review-plan` reads what.
**Dependencies**: none. Issue 581 (the `-R` repository flag on the `gh` calls in review-issue, plan-task and review-plan) edits the same skill file; see Consequences.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep text current, stale text fails quietly (the "Serves: Quality of the work" principle on stale text) | OK | This is the issue; the fix is to make the PR form read the plan file at the PR head, not the body snapshot. |
| Only what's needed | Watch | Keep the fix to lines 70-79 of the review-plan skill. Do not add comment reading, and do not change plan-task, which already documents the snapshot. |
| Test what breaks | Watch | A skill-text-only change; the plan should say so rather than invent a test. If a test greps skill text for the `headRefOid` instruction, name it. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (review timeline) | No | The entry shapes are unchanged. |
| ADR-0022 (parts with own design) | No | |

### Consequences

- Smallest correct scope, all in `.claude/skills/review-plan/SKILL.md`, "PR number" form: (a) line 71 comment, which wrongly says the plan is in the PR body; (b) line 72, add `headRefOid` to the `--json` fields (the body can stay for the title and `Closes` reference, but is not the plan); (c) line 75, take the issue number from the plan path's `issue-<N>` directory (or the `Closes #N` line), not the first `#` in a snapshot body; (d) lines 78-79, say to read the plan with `git show <headRefOid>:./.agent/work-plans/issue-<N>/plan.md` after fetching the head, and that the PR body is only a snapshot. The Step 5 text near the `plan-sha` call (the `git fetch` and `--ref` lines) already does this and can be pointed to.
- Where this meets issue 581: 581 adds the repository flag to the `gh` calls at lines 72, 75 and 156 (line 156 is step 2, not touched here). This issue's edits are the prose at lines 70-71 and 78-79, the content of line 72's `--json` list, and the source of line 75's issue number. Lines 72 and 75 will conflict textually if both land in parallel; the cheapest split is that 579 writes those two lines with the final fields and 581 only inserts `-R rolker/agent_workspace` on top, or whichever merges second rebases on those two lines.
- No change to `plan-task`, `dispatch_phase.sh` or the design document.

### Recommendations

- Scope the issue to the "PR number" form of review-plan step 1 (lines 70-79). Drop the "never reads PR comments" part, since the plan is not in comments.
- In the plan, name which of lines 72 and 75 this issue owns and which `-R` insertions 581 owns, so the two plans stay apart.
- State in the plan that the change is skill text only and has no test, or name the test if one is added.

### Actions
- [ ] Scope the issue to the "PR number" form of review-plan step 1 (lines 70-79). Drop the "never reads PR comments" part, since the plan is not in comments.
- [ ] In the plan, name which of lines 72 and 75 this issue owns and which `-R` insertions 581 owns, so the two plans stay apart.
- [ ] State in the plan that the change is skill text only and has no test, or name the test if one is added.
