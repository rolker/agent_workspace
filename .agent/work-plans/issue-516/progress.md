---
issue: 516
---

# Issue #516 — worktree_create.sh exits 1 when only the draft pull request's push failed

## Issue Review
**Status**: complete
**When**: 2026-11-19 12:49 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #516

### Scope Assessment

**Well-scoped?** Yes. One function return value plus one test; fits one short plan and one PR.
**Right repo?** Yes. `.agent/scripts/worktree_create.sh` and `.agent/scripts/tests/test_worktree_create.sh` are workspace scripts.
**Serves**: A safeguard has to earn its cost (a failed push is reported as non-fatal but acts as fatal) and Isolated worktrees for every task: `docs/design.md#worktrees`
**Design picture?** No change. The design already treats the draft PR as best effort; the fix makes the script match that.
**Dependencies**: none identified. Found in review of #513 (part of #503), which is merged.

Claim checked against the script on this branch (`.agent/scripts/worktree_create.sh`):
- `set -e` is on globally (line 32) and nothing around the call disables it. The call sites (lines 1357-1365) are plain statements inside `if`/`elif` bodies, not conditions, so `set -e` applies.
- `create_draft_pr` (line 1253) does `return 1` after a failed `git push` (about line 1272), printing "skipping draft PR (non-fatal)". The script exits 1 there. Confirmed.
- Skipped after it: `cd "$ROOT_DIR"` (line 1368), the "Next steps" text (line 1373 onward), and the shared pre-commit hook preflight (about line 1386). The worktree and its `env.sh`/`build.sh` already exist by then. Confirmed.
- Other failure paths in `create_draft_pr`: the existing-PR branch ends in `return 0` and its `gh pr comment ... && echo` is not the last command, so it is safe. `git commit ... || true`, `gh pr list ... || echo ""` and `gh pr create` (`&& ... || PR_CREATED=false`) are guarded, and a failed PR creation or plan comment only warns, with the function ending on `rm -f`, status 0. So the push `return 1` is the one non-fatal-by-message path that is fatal. Unguarded commands that could still kill the script under `set -e`: `cd "$git_dir"`, and the two `mktemp` calls. These are real errors, not "non-fatal" claims, so leave them.
- One more effect: after the early return the shell stays in `$git_dir`, which is why the `cd "$ROOT_DIR"` matters if the fix were done at the call sites instead.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| A safeguard has to earn its cost / report what happened | Action needed | The message says "non-fatal" while the exit status says failure. Make the status match the message: return 0 after the warning. |
| Test what you ship (Quality Standard) | Action needed | Add a test with a remote that refuses the push, covering exit 0, worktree exists, warning printed, "Next steps" printed, and the hook preflight reached. |
| Keep one current design | OK | No design change; `docs/design.md#worktrees` needs no edit. |
| Only what's needed | OK | Small, one-function change. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0009 | No | No installs. |
| Others (0010, 0013, 0017) | No | No issue-write, timeline or design change. |

### Consequences

- Callers that read the exit status (`start-task`, phase agents, `run-issue`) then see success when only the PR push failed; they already print the warning. Check `.claude/skills/start-task` and docs for any text that tells callers to treat a nonzero exit from `--plan-file` as "retry" and update it if so.
- No script reference change expected (`script_reference.md` describes flags, not this exit path); grep to confirm.

### Recommendations

- Prefer the fix inside `create_draft_pr`: `return 0` after the push-failed warning (a local `return 0` keeps all call sites correct), rather than `|| true` at four call sites.
- Make the warning actionable: say the branch is not on origin and how to open the PR later, e.g. `git push -u origin <branch>` then `gh pr create --draft`, since "skipping draft PR" alone leaves the user to guess.
- Test in `.agent/scripts/tests/test_worktree_create.sh` with `--plan-file` and an origin whose push is rejected (a `pre-receive` hook that exits 1 in a bare origin, since a missing remote would fail earlier checks); assert exit 0, worktree directory exists, the "Push failed" warning, and "To enter this worktree" present.
- Single short plan is enough; no sub-issues.

### Actions
- [ ] The message says "non-fatal" while the exit status says failure. Make the status match the message: return 0 after the warning.
- [ ] Add a test with a remote that refuses the push, covering exit 0, worktree exists, warning printed, "Next steps" printed, and the hook preflight reached.
- [ ] Prefer the fix inside `create_draft_pr`: `return 0` after the push-failed warning (a local `return 0` keeps all call sites correct), rather than `|| true` at four call sites.
- [ ] Make the warning actionable: say the branch is not on origin and how to open the PR later, e.g. `git push -u origin <branch>` then `gh pr create --draft`, since "skipping draft PR" alone leaves the user to guess.
- [ ] Test in `.agent/scripts/tests/test_worktree_create.sh` with `--plan-file` and an origin whose push is rejected (a `pre-receive` hook that exits 1 in a bare origin); assert exit 0, worktree directory exists, the "Push failed" warning, and "To enter this worktree" present.
- [ ] Single short plan is enough; no sub-issues.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 12:49 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the four open actions are inputs to the plan; none changes the issue's scope)
**After**: issue-actions
**Decision**: proceed

The Issue Review confirmed the claim against the script and found the push failure to be the only "non-fatal" path that is fatal. Its four actions go to the plan as written: return 0 inside create_draft_pr on a failed push; the warning says how to open the pull request later; a test in test_worktree_create.sh with an origin that refuses the push; a check of start-task and the documents for text that tells callers to retry on a non-zero exit.

## Plan Authored
**Status**: complete
**When**: 2026-11-19 12:50 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-516/plan.md` at `47cf2630`

Return 0 from create_draft_pr after a failed push, with a warning that says how to open the pull request later. Test with a bare origin whose pre-receive hook refuses the push (exit 0, worktree exists, warning, next steps). The documents need one added sentence in WORKTREE_GUIDE and no corrections.

## Plan Review
**Status**: complete
**When**: 2026-11-19 12:51 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #516 — worktree_create.sh exits 1 when only the draft pull request's push failed
**Plan**: `.agent/work-plans/issue-516/plan.md` at `47cf2630`
**Branch**: `feature/issue-516`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One function, one test, one guide sentence; a single PR. |
| Issue alignment | Good | Covers the issue and the Issue Review's actions (fix inside `create_draft_pr`, actionable warning, refused-push test, check of callers' docs). Serves: "A safeguard has to earn its cost (a message that says non-fatal must act non-fatal); Isolated worktrees for every task: `docs/design.md#worktrees`". The anchor exists (`docs/design.md` "## Worktrees"); the goal is quoted as a bullet of README "Quality of the work" rather than the section name, same form the Issue Review used. |
| File targeting | Good | The three files are the right ones. No caller needs a change (checked below). |
| Consequences | Good | Callers checked: `start-task` calls `worktree_create.sh ... --print-path-only` in an `elif`; with the fix it gets the path (stdout is redirected to stderr until line 1434 prints the path), so the session enters the worktree instead of stopping and offering `worktree_remove.sh`. That is the intended outcome. `run-issue` does not pass `--plan-file`; its PR probe (`gh pr list --head ... isDraft`) sees no PR after a failed push and answers `--pr none`, and the publish step then creates the PR with `gh_create_pr.sh`, which is correct. No script reads the exit status or output to learn whether a draft exists. `script_reference.md` does not describe this exit path. |
| Principle alignment | Needs work | The warning's recovery commands (finding 1). Test design is sound otherwise (finding 2). |
| ADR compliance | Good | No ADR triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment / AGENTS.md rule] (needs-work)** — The planned hint `git push -u origin <branch>`, then `gh pr create --draft` is wrong in three of the cases the function serves. It names bare `gh pr create`, which AGENTS.md forbids for PRs (`.agent/scripts/gh_create_pr.sh` adds the AI signature and checks the target repo); for a project worktree `create_draft_pr` passes `--repo "$PROJECT_GH_SLUG"`, which the hint drops; and for a `--parent-issue` worktree it passes `--base "$PR_PARENT_BASE"`, so the hint as planned would open the PR against the default branch. Print the command from the function's own variables: `gh_create_pr.sh --draft --title "<pr_title>"` plus `-R <repo_flag>` and `--base <base_flag>` when set (the package-worktree message at line 1215 already uses this form), and say that the plan was not posted as a comment when `HAS_PLAN` is true. Have the test assert the hint names `gh_create_pr.sh`, not `gh pr create`.
2. **[Test] (low)** — The `pre-receive` hook must be `chmod +x`; git skips a non-executable hook, the push then succeeds and the path under test is not reached. The plan's "no new file, so no `chmod`" is about the test file; say the hook needs it. The "Push failed" assertion guards against this silently, so it must stay. Without the fix the test fails on RC (current code exits 1), so it does exercise the bug. The conditional "hook preflight" block is unnecessary: RC 0 already proves the script ran to its end, past the preflight.
3. **[Test] (low, optional)** — `start-task` uses `--print-path-only`; a second run of the same refused-push case with that flag, asserting stdout is exactly the worktree path, would cover the caller that was actually broken. `run_create` merges stderr, so this needs stdout captured on its own.

Checked and fine: the empty `chore: start work on #N` commit made before the push stays on the local branch only; it is the same commit the success path pushes, and it goes up with the first later push, so it is harmless. A re-run of `/start-task` finds the existing worktree through `worktree_enter.sh` and makes no second commit.

### Summary

The fix and its placement are right, and no caller relies on the old exit status. The one change before implementation is the warning's recovery command, which must use `gh_create_pr.sh` with the repo and base the function already knows.

### Recommended Actions

- [ ] Build the warning's recovery command from `repo_flag`, `base_flag` and `pr_title` with `gh_create_pr.sh --draft`, and mention the unposted plan; assert `gh_create_pr.sh` in the test.
- [ ] Make the test's `pre-receive` hook executable and keep the "Push failed" assertion; drop the conditional preflight block.
- [ ] Optionally add a `--print-path-only` run asserting stdout is exactly the worktree path.
