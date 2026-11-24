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

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:13 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review confirms the defect and narrows the issue to it; what it drops is not something the owner asked for in his own words, and the fix stays what the triage row he accepted said: plan review reads the current plan file)
**After**: issue-actions
**Decision**: proceed

The owner started this drive with "start those 3" (2026-11-24), after accepting the triage row "plan review reads the pull request body, not the current plan file". Instructions for the plan (host decisions, listed for the owner's veto):
- Scope: the "PR number" form of review-plan step 1 (lines 70 to 79 of the skill): fetch the head commit, take the issue number from the plan's path or the Closes line and not from the first #N in the body, and read the plan file at the pull request's head, never the body.
- Dropped from the issue's text: "never reads PR comments". In this repository a plan is never in a comment and earlier findings are on the timeline, so reading comments would not fix the defect. If the owner wants plan review to read pull request comments for another reason, that is a separate change.
- Issue 581 is driven at the same time and adds a repository name to the gh calls in the same lines (72, 75) and at line 156; this plan leaves the naming of the repository to that issue and says so, and whichever merges second takes main in first.
- Skill text only. If no test pins it, say so; if one can cheaply pin the wording in test_skill_paths.sh, add it.

## Plan Authored
**Status**: complete
**When**: 2026-11-24 13:15 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-579/plan.md` at `fbbd8387`

Edit only the review-plan skill's PR-number block (step 1): add headRefOid, take the issue number from the plan path, read the plan at the PR head and say the body is a snapshot; one wording check added to test_skill_paths.sh. Repository flag on the same lines is left to issue 581.

## Plan Review
**Status**: complete
**When**: 2026-11-24 13:16 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #579 — review-plan: reviewer reads stale PR body instead of current plan file
**Plan**: `.agent/work-plans/issue-579/plan.md` at `fbbd8387`
**Branch**: `feature/issue-579`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two files, one block of skill text (step 1 "PR number" form) and one `has` check. Matches the Issue Review and the Checkpoint (After: issue-actions, proceed). |
| Issue alignment | Good | The stale-body defect is fixed at its source (line 71's claim, line 72's fields, line 75's issue source, lines 78-79). "Never reads PR comments" is dropped as the checkpoint ordered, but see finding 2 on the reason given. Serves, as checked: "Quality of the work: `docs/design.md#review-loop-and-timeline`" (README.md `### Quality of the work` line 33; design.md `## Review loop and timeline` line 768). |
| File targeting | Good | The plan's reading of the file is right: block at lines 70-79, line 71 the "plan is in the PR body" comment, line 72 the `--json` list without `headRefOid`, line 75 the first-`#N` grep, lines 78-79 the changed-files prose, line 156 step 2's `gh issue view` (left to issue 581), Step 5 note at lines 318-327 with the `git fetch` + `git show <headRefOid>:./...` read. The `--issue` (86-120) and file-path (81-84) forms are untouched; `dispatch_phase.sh:443` uses `--issue`. `has()` exists at `test_skill_paths.sh:273` at top level. |
| Consequences | Needs work | The new step 1 has no stated outcome when the PR changes no plan file, though such PRs exist (finding 1). No other text claims the plan is in the PR body: plan-task (349-352 builds the body; 418-422 says it is a snapshot), run-issue (425, 878-885) and the worktree guide make no such claim. Usage line 44 still reads "read the plan from a draft PR" (finding 6). |
| Principle alignment | Good | Stale text fixed at the reader; only what's needed; a wording pin, as the checkpoint allowed. Design picture unchanged, stated. Prior art named (Step 5 note, `plan-sha --ref`). |
| ADR compliance | Good | ADR-0013 entry shapes unchanged; no ADR triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences]** (must-fix, take during implementation) — The plan says what to do when no plan path is among the changed files only for the issue number ("fall back to the `Closes #<N>` line"), not for the plan itself. Such PRs exist here: `worktree_create.sh --plan-file` (and `/start-task --plan-file`; `.agent/WORKTREE_GUIDE.md:385-392`) opens a `[PLAN]` draft whose only commit is empty and posts the plan as a PR comment (`worktree_create.sh:1293-1295,1379,1401`), body "Closes #N". Under the new text an agent has the issue number and nothing to read, and the old habit (body, or now a comment) is the obvious fill-in. Add one sentence: with no `plan.md` among the changed files, resolve the plan as the `--issue <issue>` form does; if none is found, stop and say so; never take the PR body or a PR comment as the plan. In the same sentence cover two plan files (e.g. a stacked or bookkeeping PR touching another issue's plan): take the one whose `issue-<N>` matches the `Closes` line, otherwise stop and ask.
2. **[Issue alignment]** (suggestion, PR description) — The checkpoint's reason for dropping "never reads PR comments", "a plan is never in a comment here", is not true: `--plan-file` drafts carry the plan only in a comment (finding 1). The drop itself still holds on the other reason (this workspace's reviews are recorded on the progress timeline, and a comment is as much a snapshot as the body). The PR description the plan pre-writes ("a plan is never in a comment") should give the reason that holds, so the owner's veto list is not built on a false fact. No change of scope.
3. **[File targeting]** (suggestion) — Write the plan path in the new prose as `./.agent/work-plans/issue-<issue>/plan.md`, as the Step 5 note does, not `` `.agent/work-plans/...` `` (plan item 4). `test_skill_paths.sh:88` `BAD_RE` fails any `.agent/work-plans/` preceded by a backtick or space in a `session_scope: both` skill outside the Workspace-root section; and `$WS_ROOT/` (today's line 79) is wrong for a repository-relative changed-files path, more so for a project PR.
4. **[File targeting]** (suggestion) — In this block `<N>` is the PR number (`gh pr view <N>`); plan item 4 also writes `issue-<N>` and `git show <headRefOid>:./.agent/work-plans/issue-<N>/plan.md`. Use `<issue>` for the issue number, as Step 5 does, so an agent does not read the plan of issue = PR number.
5. **[Consequences]** (suggestion) — `git fetch -q origin "<headRefName>"` fails for a PR from a fork (the branch is not on origin) and for a PR whose branch was deleted. `git fetch -q origin "pull/<pr>/head"` works for both and still lands `headRefOid`. If taken, change the Step 5 note's fetch line the same way (it is the line the plan points to), or keep both as `headRefName` and say forks are not supported; either is cheap, mixed is not.
6. **[Consequences]** (suggestion) — Usage, line 44: "`<pr-number>` — read the plan from a draft PR (existing behavior)" still invites reading the PR itself. Reword to "read the plan file at a PR's head commit". One line, same file, same defect.
7. **[Principle alignment]** (note) — `has()` already flattens line breaks and runs of spaces (`test_skill_paths.sh:273-281`), so a rewrap cannot break the pin; the plan's "chosen after the wording is written, so the test tracks the text and not a rewrap" needs no extra care beyond picking phrases that do not span inline code marks.

### Summary

The plan reads the file correctly, keeps to the scope the checkpoint set, and leaves `--issue`, the file-path form and line 156 alone. One real gap: the new instructions do not say what to do when a PR changes no plan file, which `--plan-file` drafts do; it is one sentence the implementer can add without a new plan. The rest are wording points.

### Recommended Actions

- [ ] (must-fix) Step 1 PR form: no plan file among the changed files → resolve as `--issue <issue>`, else stop; two plan files → match the `Closes` line, else stop; never the body or a comment
- [ ] (suggestion) PR description: give the reason that holds for dropping PR-comment reading, not "a plan is never in a comment"
- [ ] (suggestion) Write the path as `./.agent/work-plans/issue-<issue>/plan.md` (test_skill_paths BAD_RE; repository-relative)
- [ ] (suggestion) Use `<issue>`, not `<N>`, for the issue number inside the PR block
- [ ] (suggestion) Fetch `pull/<pr>/head` (works for forks) in step 1 and the Step 5 note, or state forks unsupported
- [ ] (suggestion) Usage line 44: "read the plan file at a PR's head commit"
