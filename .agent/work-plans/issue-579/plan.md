# Plan: review-plan: reviewer reads stale PR body instead of current plan file

## Issue

https://github.com/rolker/agent_workspace/issues/579 (numbers written with `#` in the issue body belong to the older repository it came from, not this one)

## Context

`/review-plan <pr-number>` (`.claude/skills/review-plan/SKILL.md`, step 1, "PR number" form, lines 70-79) says "plan is in the PR body", fetches `title,body,...`, and takes the issue number from the first `#N` in that body. The body is a snapshot `plan-task` step 8 copied once; inline plan edits during implementation never reach it. A plan review by PR number can therefore judge stale text. The loop itself is not exposed (`dispatch_phase.sh` runs `review-plan --issue <N>`, which reads the live file); only the by-hand PR form is. The Step 5 note (lines 318-327) already gives the correct read, `git show <headRefOid>:./.agent/work-plans/issue-<issue>/plan.md`.

Scope was narrowed by the issue review and the checkpoint: the issue's "never reads PR comments" is dropped, because a plan is never in a comment here and earlier findings are on the timeline. Reading PR comments for some other reason would be a separate change.

## Approach

Edit only the "PR number" block of step 1 (lines 70-79):

1. **Line 71 comment** — change `# PR metadata and body (plan is in the PR body)` to say the body is only a snapshot, not the plan; the plan is read at the PR head (below).
2. **Line 72 `--json` list** — add `headRefOid` (`title,body,baseRefName,headRefName,headRefOid,files,url`).
3. **Lines 74-75 (issue number)** — replace "first `#N` in the body" with: take `<N>` from the `issue-<N>` directory in the plan path found in the PR's changed files; fall back to the `Closes #<N>` line only when no plan path is among them. Keep the command as one `gh pr view <N> --json ...` line whose only job is to name the issue.
4. **Lines 78-79 (prose)** — say: find `.agent/work-plans/issue-<N>/plan.md` in the changed files, then `git fetch -q origin "<headRefName>"` and read it with `git show <headRefOid>:./.agent/work-plans/issue-<N>/plan.md` from the repository's top folder (same read the Step 5 note describes; point to it rather than repeat it). State that the PR body is a snapshot and is never the plan.

Split with issue 581 (same file, planned in parallel): this plan owns the content of line 72's `--json` field list and the source of line 75's issue number, plus the prose at lines 71 and 78-79. Issue 581 owns inserting `-R <repository>` on the `gh` calls at lines 72, 75 and 156. This plan does not add `-R` anywhere and does not touch line 156. Whichever merges second takes `main` in first and resolves the two shared lines by combining (final fields from here, `-R` from 581).

Test: add one `has` check in `.agent/scripts/tests/test_skill_paths.sh` (the helper at line 273 already exists), placed before the final summary, asserting the review-plan skill says `headRefOid` is fetched in the PR form and that the PR body is a snapshot, not the plan. Pin short fixed phrases that the new wording uses, chosen after the wording is written, so the test tracks the text and not a rewrap.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/review-plan/SKILL.md` | "PR number" block of step 1, lines 70-79, as above |
| `.agent/scripts/tests/test_skill_paths.sh` | one `has "$SKILLS/review-plan/SKILL.md" ...` check pinning the `headRefOid` read and the snapshot statement |

## Prior Art

The Step 5 note in the same skill and `review_progress.sh plan-sha --ref` already read the plan at the PR head; this change makes step 1 agree with them. `plan-task`'s own "During implementation" text already says the body is a snapshot. Nothing new is built.

## Serves

Quality of the work: `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to the design picture; the design section describes the phases, not which form of `review-plan` reads what.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep text current; stale text fails quietly | The fix makes the PR form read the file at the PR head, not a snapshot |
| Only what's needed | Only lines 70-79 of one skill; no comment reading, no change to `plan-task`, `dispatch_phase.sh` or the design document |
| Test what breaks | Skill text only, so the check is a wording pin in the existing skill-text test, not a behaviour test |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 (review timeline) | No | Entry shapes unchanged |
| ADR-0022 (parts with own design) | No | |

No new ADR. Mechanism text names no project.

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| review-plan step 1 PR form | Step 5 `plan-sha` note (already correct) | No change needed; pointed to |
| Lines 72 and 75 | Issue 581's `-R` edits to the same lines | Split stated above; second merge takes main in |
| Skill wording | `test_skill_paths.sh` | Yes, one `has` check |

## Open Questions

None.

## Estimated Scope

Single small PR. Check: run `.agent/scripts/tests/test_skill_paths.sh` (the only suite touched). The PR will say: the by-PR-number form of `review-plan` now reads the plan file at the PR head instead of the body snapshot and takes the issue number from the plan path; "never reads PR comments" from the issue is deliberately not done (a plan is never in a comment); `-R` on the same lines is left to issue 581; verification is that one test run, named. Closes #579.
