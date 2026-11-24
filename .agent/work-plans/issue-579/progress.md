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

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:17 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is ready; its one must-fix is a sentence the reviewer says the implementer can add without a new plan, and its suggestions are wording)
**After**: plan
**Decision**: proceed

Implement the plan at fbbd8387 with these instructions, which answer the Plan Review's findings and bind the implementer (host decisions, listed for the owner's veto):
- Finding 1 (must-fix): the new step 1 says what to do when the pull request changes no plan file or more than one. None: find the plan as the --issue form does, for the issue the pull request closes; if none is found, stop and say so. Two or more: take the one whose issue number matches the Closes line, else stop. Never treat the body or a comment as the plan.
- Finding 2: the host's earlier reason for dropping "never reads PR comments" was wrong in fact: a plan can be posted as a pull request comment (worktree_create.sh --plan-file does it). The drop stands on the other reason: reviews are on the progress timeline, and a comment is as much a snapshot as the body. The pull request description gives that reason.
- Finding 3: the plan path is written ./.agent/work-plans/issue-<issue>/plan.md, as the Step 5 note does.
- Finding 4: in this block <N> is the pull request number; the issue number is written <issue>.
- Finding 5: fetch with git fetch origin "pull/<pr>/head", which also works for a fork or a deleted branch, and change the Step 5 fetch the same way so the two agree.
- Finding 6: the usage line (around line 44) says "read the plan file at a PR's head commit".
- No -R is added here: naming the repository on the gh calls is issue 581's.

## Implementation
**Status**: complete
**When**: 2026-11-24 13:19 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-579 at `30f3b337`

- `.claude/skills/review-plan/SKILL.md`, step 1 "PR number" form: the body is called a snapshot, never the plan (nor a PR comment); `--json` gains `headRefOid`; a `gh pr view --json files --jq ... select(test(...))` line lists the plan files the PR changes (issue number `<issue>` from their `issue-<issue>` directory); the Closes line is read only for the none/many cases. One plan file: `git fetch -q origin "pull/<N>/head"` then `git show <headRefOid>:./.agent/work-plans/issue-<issue>/plan.md` from the repository's top folder. More than one: the one matching the closed issue, else stop and list them. None (e.g. a `--plan-file` draft): find it as the `--issue <issue>` form does (Step 5 then uses `--plan <path>`), else stop.
- Same file: usage line now "read the plan file at a PR's head commit"; the Step 5 note's fetch is `pull/<N>/head` too. No `-R` added anywhere (issue 581's).
- `.agent/scripts/tests/test_skill_paths.sh`: one `has` check pinning `headRefName,headRefOid,files,url`, the snapshot sentence, the never-body-or-comment sentence, the `pull/<N>/head` fetch and the `git show` read.
- Checked by hand: the plan-file and Closes lookups run as written against merged PRs 602, 597, 572, 571, 570, 568, 567 (plan path or Closes line found where present; "Part of" bodies give no Closes line, so those PRs only work through their plan file).
- Suite run: `bash .agent/scripts/tests/test_skill_paths.sh` → `test_skill_paths: 213 passed, 0 failed`. The full pre-commit pass and the other suites were left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 13:25 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-579 at `d4c93c8c`
**Base**: origin/main
**Depth**: Deep (reason: 266 changed lines counting the plan and progress files; a `.claude/skills/*/SKILL.md` override trigger alone makes it Standard, which dispatches the same specialists)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 1 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Checked: the three `gh` lines, the jq filter and the grep run as written on PRs 602 (no plan file, Closes 551), 600 (no plan file, Part of 582: stops, as written), 572 (one plan, Closes 563), 568 (one plan, Part of 551), 564 (none, Part of: stops), and 326 (two plan files 265 and 317, Closes 317: the match picks 317). `git fetch -q origin "pull/<N>/head"` + `git show <headRefOid>:./...` read the plan for 572 and 568, both merged with their branches deleted; `plan-sha --ref` works on the fetched oid. A scan of 120 PRs found no PR with one plan file of an issue other than the one it closes. `--issue` and file-path forms untouched; Step 5's `--plan`/`--ref` lines agree. `test_skill_paths.sh`: 213 passed, 0 failed; shellcheck clean. Cross-model: gemini ran (9 findings: 3 kept as suggestions, the "must-fix" ratings downgraded because each failure stops loudly; the rest dropped, one of them shown wrong by the passing test); codex failed (usage limit).

### Findings
- [x] (suggestion) Closing-issue lookup: the grep misses `Closes: #N`, `Closed`/`Fix`/`Fixed`, `owner/repo#N`, has no word boundary, and `head -1` can take a `#N` quoted in the body's plan copy or drop a second closed issue; `gh pr view <N> --json closingIssuesReferences --jq '.closingIssuesReferences[].number'` is GitHub's own parse (checked: 602→551, 326→317, 572→563, 568/600→none), and `body` can then leave line 72 so the snapshot never enters the reviewer's context — `.claude/skills/review-plan/SKILL.md:72,78`
- [x] (suggestion) The plan-file filter is unanchored (`test("work-plans/issue-...")` also lists e.g. `tests/fixtures/work-plans/issue-1/plan.md`) while the read is the fixed `./.agent/work-plans/...` path; anchor it as `^\.agent/work-plans/issue-[0-9]+/plan[.]md$` so the list and the read name the same file — `.claude/skills/review-plan/SKILL.md:75`
- [x] (suggestion) No-plan-file case goes straight to the local `--issue` lookup; first try `git show <headRefOid>:./.agent/work-plans/issue-<issue>/plan.md` (PR 602: the plan of 551 is at its head, unchanged, committed by PR 568), so a checkout that is behind the PR does not quietly supply an older copy — `.claude/skills/review-plan/SKILL.md:96-101`
- [x] (suggestion) For issue 581's split: this block now has three `gh` calls (lines 72, 75, 78), not the two 581's plan names; say so in the PR description so the `-R` reaches the new one whichever merges second — `.claude/skills/review-plan/SKILL.md:75`

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 1 approved with four suggestions; three of them make the new step read the right file in cases the reviewer reproduced, one of which fails quietly today, and fixing them before the push costs one short round and no extra CI run)
**After**: publish
**Decision**: address

Address the four suggestions of the Local Review at f3476f54 before publishing (host decisions, listed for the owner's veto):
- 1: find the issue the pull request closes with GitHub's own parse (gh pr view <N> --json closingIssuesReferences), not a grep of the body, and take body out of the first gh call so the stale snapshot never reaches the reviewer.
- 2: anchor the plan-file filter to ^\.agent/work-plans/issue-[0-9]+/plan[.]md$ so the list and the read name the same file.
- 3: for a pull request that changes no plan file, first try the plan at the pull request's head (git show <headRefOid>:./.agent/work-plans/issue-<issue>/plan.md), and only then the local --issue lookup; a checkout behind the pull request must not quietly supply an older copy.
- 4: the block now has three gh calls; say so in the entry, for the pull request text, so the repository flag issue 581 adds reaches all three whichever merges second.
Outside reviewers in round 1: Gemini ran (three points kept); Codex did not run, it hit its usage limit.

## Implementation
**Status**: complete
**When**: 2026-11-24 13:28 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-579 at `b8fcca14`
**Addressed**: Local Review (Pre-Push) at `d4c93c8c` (2026-11-24 13:25 -05:00)
**Commits**: b8fcca14

### Actions
- [x] Closed issues from GitHub's parse: `gh pr view <N> --json closingIssuesReferences --jq '.closingIssuesReferences[].number'` replaces the body grep, and `body` is out of the first call's field list. Several closed issues: with several plan files, take the one plan file whose issue is among them if exactly one is, else stop and name the plan files and the closed issues; with no plan file, stop. One clause added from the tries: GitHub lists no closed issue for a PR into a branch other than the default one (PRs 211, 131, 130, into feature branches, say "Closes" in the body and list none), so such a PR with no plan file stops, loudly — `.claude/skills/review-plan/SKILL.md:72,78,93-101`
- [x] Plan-file filter anchored: `select(test("^[.]agent/work-plans/issue-[0-9]+/plan[.]md$"))`, the same regex as the review's `^\.agent/...`, written `[.]` because the jq string would need `\\.` and `test_skill_paths.sh`'s workspace-relative path rule (BAD_RE) flags `\.agent/` preceded by a backslash — `.claude/skills/review-plan/SKILL.md:75`
- [x] No plan file: read `git show <headRefOid>:./.agent/work-plans/issue-<issue>/plan.md` at the head first (the fetch and the read now sit in one block above the three cases); only when that file does not exist at the head, the local `--issue` lookup. Step 5 note's two comment lines say which case takes `--ref` (a plan read at the head) and which `--plan <path>` (the `--issue` fallback); the case text says the same — `.claude/skills/review-plan/SKILL.md:96-111,338-343`
- [x] Three `gh` calls, for the pull request text: "The PR-number block of review-plan step 1 now has three `gh pr view` calls (metadata, plan files, closed issues), not the two issue 581's plan names; whichever of 579 and 581 merges second adds the repository flag to all three." — `.claude/skills/review-plan/SKILL.md:72,75,78`

### Tries (read-only, this repository, each head fetched with `pull/<N>/head`)
- 602: plan files none; closes 551; `git show` at 95e16bd4 reads the plan of 551 (194 lines). Found at the head, no local lookup.
- 572: plan file issue-563; closes 563; read at 4e26d6d9 (137 lines).
- 568: plan file issue-551; closes none ("Part of"); one plan file needs no closed issue, read at 865c944b (194 lines).
- 600: plan files none; closes none: stops before any read (for the record, `git show` of a guessed issue-582 path prints `fatal: path ... does not exist`, the "not at the head" signal).
- 326: plan files issue-265 and issue-317; closes 317: exactly one matches, issue-317 read at 0eec16a6 (450 lines).

### Checks
- `bash .agent/scripts/tests/test_skill_paths.sh` → `test_skill_paths: 213 passed, 0 failed` (the 579 pin now also holds the body-free field list, the anchored filter, the `closingIssuesReferences` call and "Only when that file does not exist at the head"). Commit hooks ran with `SKIP=validate-script-tests`; the full pre-commit pass and the other suites were left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 13:29 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a14409e982e4e9029, resume 1 of 3)
**Verdict**: approved

**Branch**: feature/issue-579 at `c6ffd39c`
**Base**: origin/main
**Depth**: Deep (reason: whole-diff classification as in round 1; run as a convergence check on round 1's four suggestions and the fix diff f3476f54..c6ffd39c, per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 2 | **Ship**: recommended — no must-fix findings; all four round-1 suggestions closed

Round 1's four, each closed: (1) `closingIssuesReferences` replaces the body grep and `body` is gone from the first call; (2) the filter is anchored, `^[.]agent/...`, the same regex as `^\.agent/...`, and the `[.]` form is the right way around the BAD_RE path rule; (3) with no plan file the head is read first, and the local `--issue` lookup only when the file is missing there, with Step 5's `--ref`/`--plan` comments matching; (4) three `gh` calls recorded in the Implementation entry for the pull request text. The extra stop for a pull request into a branch other than the default one is right: PR 211 (into feature/issue-172) says "Closes #210" in its body and GitHub lists no closed issue; such a PR with no plan file now stops with a message, and with one plan file (211 itself) it still reads it. Tries, read-only: 602 (no plan file, closes 551, plan read at head 95e16bd4, plan-sha --ref 7ab07af2), 568 (one plan, closes none, read), 600 (none, closes none: stops), 326 (two plans, closes 317: issue-317 read), 211 (one plan, into a feature branch: read). `test_skill_paths.sh`: 213 passed, 0 failed. Claude adversarial, Gemini and Codex not run this round (convergence check; per handoff, no Gemini and no Codex; Codex also at its usage limit).

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:35 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 2 of the pre-push review approved with nothing open, Ship: recommended; the host's full pre-commit pass over the changed files passed, every hook, no SKIP, on 3a56f8b7)
**After**: publish
**Decision**: publish

Two pre-push rounds: round 1 approved with four suggestions, fixed before publishing on the host's answer; round 2, a convergence check with no outside reviewers, found all four closed and nothing new. Outside reviewers in round 1: Gemini ran (three points kept); Codex did not run (usage limit).

## Local Review
**Status**: complete
**When**: 2026-11-24 13:37 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #604 at `b059dcfe`
**Depth**: Deep (reason: cold read, cross-model only: codex, per handoff)
**Must-fix**: 1 | **Suggestions**: 1

Codex ran (EXIT=0, complete review); no other specialist ran (cold read). Lead checked both findings against the changed block and against the worktree layout.

### Findings
- [x] (must-fix) PR-number form's fallback (no plan file at the head) hands off to the `--issue` lookup, which after the PR repo's own top folder checks the workspace worktree `issue-workspace-<N>` and then every registered project's `issue-*-<N>` worktree by number alone: for a project PR, an open worktree of another repository's issue with the same number is silently read as this PR's plan (the right project worktree is checked after the workspace one). Limit the fallback to the PR's own repository (its top folder and its own worktree dir) and stop otherwise — `.claude/skills/review-plan/SKILL.md:108`
- [x] (suggestion) `git fetch -q origin "pull/<N>/head"` (step 1 and Step 5 note) assumes `origin` is the repository the PR belongs to; in a fork checkout the fetch fails or gets another PR. Not silent: `git show <headRefOid>:...` exits 128 when the head commit was not fetched. Same repository-identity question as issue 581; the old Step 5 text also fetched from `origin` — `.claude/skills/review-plan/SKILL.md:93`

## Implementation
**Status**: complete
**When**: 2026-11-24 13:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a6b043f1791fcc0ee, resume 1 of 3)

**PR**: #604 at `f31885eb`
**Addressed**: Local Review at `b059dcfe` (2026-11-24 13:37 -05:00)
**Commits**: f31885eb

Host directions (host decisions, listed for the owner's veto): fix the must-fix by narrowing, not widening: in the PR-number form the only local fallback is the plan file in the checkout the skill is run from, and if it is not there, stop and name the path; never send the reader to the Issue number form's search; leave the `--issue` form unchanged, since it is the loop's own route and outside this pull request; keep the Step 5 note in agreement. Suggestion: one clause where the fetch is introduced saying `origin` must be the pull request's repository, and that a failed fetch or `git show` stops with git's message and never reads another copy; naming the repository on the `gh` calls stays issue 581's. Update the wording pin only as needed.

### Actions
- [x] (must-fix) No plan file at the head: the one local fallback is now `$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<issue>/plan.md`, the checkout the skill runs from; if it is not there, stop and say so, naming the path looked at. The text says never to search other worktrees or registered projects (the Issue number form's search), because another repository's issue can have the same number. The `--issue` form is unchanged. Step 5's comment now says "the PR-number form's local fallback", and the case text says that file takes `--plan <path>` — `.claude/skills/review-plan/SKILL.md:107-117,354-355`
- [x] (suggestion) Where the fetch is introduced: "`origin` must be that repository. If the fetch fails, or `git show` fails for any reason other than the file not existing at that commit (the no-plan-file case below), stop and show git's message; never read another copy." The exception keeps the no-plan-file case working, because there a missing file at the head is the expected signal for the local fallback. The `gh` calls still name no repository; that stays issue 581's — `.claude/skills/review-plan/SKILL.md:84-89`

### Checks
- The pinned sentences are unchanged. The issue 579 pin in `test_skill_paths.sh` gained two phrases: "Never search other worktrees or registered projects" and "stop and show git's message; never read another copy".
- `bash .agent/scripts/tests/test_skill_paths.sh` → `test_skill_paths: 213 passed, 0 failed`. Commits used `SKIP=validate-script-tests`; the full pre-commit pass and the other suites were left to the host.

## Local Review
**Status**: complete
**When**: 2026-11-24 13:40 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a14409e982e4e9029, resume 2 of 3)
**Verdict**: changes-requested

**PR**: #604 at `0ec8c6fb`
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 0

Scope: the cold read's two findings and the fix diff 22d217e3..0ec8c6fb. Cross-model: skipped (round-3 convergence check, per handoff). Cold read's must-fix (fallback searched other worktrees and registered projects): closed; the no-plan-file fallback is now only `$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<issue>/plan.md`, else stop naming the path; the `--issue` form is unchanged (no diff lines in it). Cold read's suggestion (`origin` assumed): closed in wording ("`origin` must be that repository", stop on a failed fetch), but see the finding. The three cases and Step 5's `--ref`/`--plan` comments agree. `test_skill_paths.sh`: 213 passed, 0 failed.

Tried, in this worktree: `git show 95e16bd4…:./.agent/work-plans/issue-582/plan.md` (commit present, path missing) prints `fatal: path '.agent/work-plans/issue-582/plan.md' does not exist in '95e16bd4…'`, exit 128; `git show 0123456789abcdef0123456789abcdef01234567:./.agent/work-plans/issue-582/plan.md` (commit absent) prints the same `fatal: path ... does not exist in '<sha>'`, exit 128. `git cat-file -e "<sha>^{commit}"` tells them apart: 0 when present, 128 "Not a valid object name" when absent.

### Findings
- [ ] (must-fix) The text's exception "fails for any reason other than the file not existing at that commit" cannot be judged from `git show`: for a full SHA that was never fetched, git prints the same "path ... does not exist in '<sha>'" with the same exit 128 as for a missing file. When the fetch succeeds but does not bring `<headRefOid>` (an `origin` that is another repository holding a pull request with the same number, or the PR force-pushed between `gh pr view` and the fetch), the no-plan-file case reads that as "no plan at the head" and quietly takes the local fallback, the wrong-repository read the cold read's must-fix was about. Mechanical fix: after the fetch, `git cat-file -e "<headRefOid>^{commit}"`, and stop with git's message if it fails; then a failed `git show` really means the file is missing — `.claude/skills/review-plan/SKILL.md:85-92`
