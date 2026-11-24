---
issue: 581
---

# Issue #581 — review-issue: make owning-repo resolution cwd-independent

## Issue Review
**Status**: complete
**When**: 2026-11-24 13:13 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #581

### Scope Assessment

**Well-scoped?** Yes, once narrowed — the title says review-issue, the body adds plan-task and review-plan. The defect is one shared pattern (a bare `gh` call, and a git-bug slug the skill leaves as the placeholder `<owner/repo>`), so one small helper plus a one-line change at each call site fits one pull request. Small, as the triage note says. Not "verified" in full: the issue names two lines; the real list is longer (below).
**Right repo?** Yes — skills and `.agent/scripts/` are workspace infrastructure.
**Serves**: Quality of the work — `docs/design.md#review-loop-and-timeline`
**Design picture?** No change — the rule that an issue's phase reads and writes in its owning repository is already in `docs/design.md#worktrees` / ADR-0012; this brings three skills in line with it.
**Dependencies**: none identified open. Issue 579 (review-plan reads the pull request body) edits the same file; see the file split under Recommendations. Numbers written with `#` in the issue body (#445, #260) were written in the fork and are not issues here.

**Where a bare call can act on the wrong repository (checked in this worktree, from the files):**
- review-issue step 1, line 90: `gh issue view <N> --json ...`; step 7, line 244: `gh issue comment <N> --body-file ...`. Both confirmed as the issue says.
- Lines 65-67 (git-bug lookup): `_REPO_SLUG="<owner/repo>"  # resolve from git remote` is a placeholder the agent fills in by hand, from the cwd's remote. Same defect, one step earlier, and not in the issue text. The same placeholder is in plan-task line 67 and review-plan line 132.
- plan-task: line 91 (`gh issue view`), line 182 (`gh issue view <N> --json url`, which decides the worktree type and so is circular when the cwd is wrong), line 201 (issue URL), lines 347-359 (`gh pr list/edit/create` for the draft pull request; the dispatched pass uses `--no-pr`, a standalone run does not).
- review-plan: line 156 (`gh issue view "$ISSUE_NUM"`), lines 72 and 75 (`gh pr view <N>` and the `grep -o '#[0-9]*'` of the body, which takes a bare number as an issue in the cwd's repository).
- The skills never post with `gh` except review-issue step 7; `review_progress.sh persist` writes to the cwd checkout's work-plans (it checks the path is `<repo-root>/.agent/work-plans/issue-<N>`), which is right only if the cwd is the owning checkout.

**What protects `/run-issue` today:** the handoff prints the bare number (`skill_task_line`, dispatch_phase.sh:438-441) and runs the phase from the owning checkout (`cd <that checkout> &&`). For a package worktree (a `.worktree-repos` manifest, ADR-0012) `resolve_issue_dir ... 1` (dispatch_phase.sh:~345-398) also asks `gh repo view` in that checkout and refuses when it differs from the manifest header's `owner/repo#N` — the case that matters being an `upstream` remote that gh prefers over origin — printing the `gh repo set-default` fix. So the run-issue path is protected for package issues. It is not protected for a workspace or single-repository worktree (the check is skipped when the directory is the worktree itself), and not at all for a standalone `/review-issue 581`, `/plan-task 581`, `/review-plan --issue 581`: they take whatever the cwd resolves.

**What no longer applies in the issue text:** the number references (#445 is a fork issue; #260 here is the fork cutover triage), and "only /run-issue is protected" is true only for package issues. Line numbers 90 and 244 still match. The claim that the skills "can" hit the wrong repository is true but narrower than it reads: a bare number is by definition the cwd's repository, so a run from the right directory is correct. The failure needs a wrong cwd, or a cwd whose gh default differs from its origin (upstream remote).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Put each thing at the level it applies to | OK | One helper under `.agent/scripts/` used by three skills, not three copies of an idiom in prose. |
| Only what's needed | Watch | Do not make the skills accept a free-form repository argument in addition to the number unless a real caller needs it; the smallest form is `<N>` or `<owner/repo#N>` (the ref form dispatch already uses), resolved once. |
| A safeguard has to earn its cost | OK | The failure is a comment posted on a stranger's issue, not undoable; a one-time resolution that prints the repository it chose is cheap. |
| Verify before claiming | Watch | The fix must be shown by a test that runs the skill's resolution from a second repository with an `upstream` remote, not only from the workspace. |
| Keep one current design | OK | No design change (above). |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0012 (worktree composition) | Yes | The owning repository is the one holding `feature/issue-<N>`; the fix must not reinvent how it is found. |
| ADR-0010 (git-bug optional) | Yes | The git-bug slug placeholder is part of the defect; keep the gh fallback when git-bug is absent. |
| ADR-0013 (progress.md entries) | Watch | No change to entry shape; persistence stays in the cwd's owning checkout. |
| ADR-0016 (user tier) | Watch | The new script must resolve through `$WS_ROOT` like the others. |

### Consequences

- `.agent/knowledge/script_reference.md` gains the new script; `.agent/knowledge/github_cli_patterns.md` gets the "name the repository on every gh call" rule if it is not there.
- `.agent/scripts/tests/test_skill_paths.sh` covers skill text; add a suite for the helper (ref forms, upstream-vs-origin mismatch, non-GitHub remote refused).
- run-issue step 2 already uses `-R owner/repo` (SKILL.md line ~310); the dispatch check can call the same helper instead of its own copy, or be left alone.

### Recommendations

- Add one helper (a function in `.agent/scripts/_issue_helpers.sh` or a small script) that takes `<N>` or `<owner/repo#N>` and prints the owning `owner/repo`: from the ref when qualified; otherwise from `gh repo view --json nameWithOwner` in the cwd, refusing when it differs from the origin remote's GitHub slug (`extract_gh_slug`) — the same check dispatch_phase.sh already makes for package worktrees — and naming `gh repo set-default`. The skills then put the result in `_REPO_SLUG` (replacing the hand-filled placeholder) and add `-R "$_REPO"` to every `gh issue/pr` call; step 1 prints the repository it chose so a mismatch is visible.
- Cover all three skills in this one pull request (review-issue lines 65-90 and 244; plan-task 67, 91, 182, 201, 347-359; review-plan 72-75, 132, 156), and retitle or note the scope: the issue title names review-issue only.
- Keep the file split with issue 579: this issue touches only `review-plan/SKILL.md` step 2 (the issue read, lines ~122-160, one `-R` and the `_REPO_SLUG` line) and the two `gh pr view` lines in step 1 (72 and 75). 579 owns the rest of step 1 (reading the plan file instead of the PR body) and step 5-6. Lines 72-75 sit inside 579's step; if both plans edit them, land 579 first or have 579 leave those two lines alone.
- Test from a second repository with an `upstream` remote, and say in the pull request which cases were run.

### Actions
- [ ] Add a helper that takes `<N>` or `<owner/repo#N>` and prints the owning `owner/repo` (from the ref, else gh in the cwd, refusing when it differs from the origin slug); skills set `_REPO_SLUG` from it and add `-R "$_REPO"` to every gh issue/pr call
- [ ] Cover all three skills in this one pull request (review-issue lines 65-90 and 244; plan-task 67, 91, 182, 201, 347-359; review-plan 72-75, 132, 156), and note that the issue title names review-issue only
- [ ] Keep the file split with issue 579: this issue touches only review-plan step 2 (the issue read, lines ~122-160) and the two `gh pr view` lines 72 and 75 in step 1; 579 owns the rest of step 1 and steps 5-6; land 579 first or have 579 leave lines 72-75 alone
- [ ] Test from a second repository with an `upstream` remote, and say in the pull request which cases were run
