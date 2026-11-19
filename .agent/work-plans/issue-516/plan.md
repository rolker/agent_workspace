# Plan: worktree_create.sh exits 1 when only the draft pull request's push failed

## Issue

Issue 516 in rolker/agent_workspace.

## Context

`create_draft_pr` in `.agent/scripts/worktree_create.sh` prints "Push failed — skipping draft PR (non-fatal)" and then `return 1`. With `set -e` on, the script exits 1 before `cd "$ROOT_DIR"`, the "Next steps" text and the pre-commit hook preflight, although the worktree already exists. Every other failure in the function only warns and ends with status 0.

## Approach

1. **Return 0 after the failed push** — in `create_draft_pr`, change `return 1` to `return 0`. The fix stays in the function; the four call sites need no `|| true`.
2. **Make the warning say what to do** — move the `pr_title` computation above the push so the hint can use it. After a failed push the warning says the branch is not on origin, that the plan comment was not posted (only when `HAS_PLAN` is true), and prints a recovery that would run: `git push -u origin <branch>`, then `.agent/scripts/gh_create_pr.sh --draft --title "<pr_title>" --body-file <file>`, with `-R <repo_flag>` added when `repo_flag` is set and `--base <base_flag>` added when `base_flag` is set (`gh_create_pr.sh` passes `--draft` and `--base` through to `gh pr create` and takes `-R`; the package-worktree message near line 1215 words its command the same way). Never bare `gh pr create`. What it prints:
   - workspace worktree (`repo_flag` and `base_flag` empty): `gh_create_pr.sh --draft --title "[PLAN] <issue title>" --body-file <file>`.
   - single-repository project worktree (`repo_flag` is `$PROJECT_GH_SLUG`): the same plus `-R <owner/repo>`.
   - `--parent-issue` worktree (`base_flag` is `$PR_PARENT_BASE`): the same as the workspace line plus `--base <parent branch>` (plus `-R` too if it is a project worktree).
   - skill worktree (`issue_ref` empty, no repo or base): `gh_create_pr.sh --draft --title "[PLAN] Skill update: <skill>" --body-file <file>`.
   The title carries `[PLAN]` because `--plan-file` is what reaches this function. The plan-not-posted sentence appears in all four when `HAS_PLAN` is true.
3. **Test** — in `.agent/scripts/tests/test_worktree_create.sh`, before the Summary, add a bare origin (`gitq init --bare`, same as `add_origin_ahead`) whose `hooks/pre-receive` is `exit 1` and is made executable with `chmod +x` (git skips a non-executable hook, the push would succeed and the path under test would not be reached), wired to a fresh `make_ws_repo` sandbox, and a scratch plan file. Run `run_create` with `--issue <N> --type workspace --plan-file <file>`. Assert: RC is 0; the worktree directory exists on `feature/issue-<N>`; the output has "Push failed" (this stays: it proves the hook refused the push), the hint names `gh_create_pr.sh`, and "To enter this worktree". A second run in a fresh sandbox of the same refused-push case adds `--print-path-only` with stdout captured on its own (`run_create` merges stderr) and asserts stdout is exactly the worktree path and RC is 0; this is the `start-task` call that was broken.
4. **Documents** — read `start-task` SKILL.md, `.agent/WORKTREE_GUIDE.md` and `.agent/knowledge/script_reference.md`. None says that a non-zero exit from `--plan-file` means "push failed" or tells callers to retry. SKILL.md line 174 ("exit non-zero on real failures") stays true. No sentence changes. WORKTREE_GUIDE "Draft PRs with Plan File" gets one added sentence: a failed push warns and the worktree is still made.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/worktree_create.sh` | `return 0`, `pr_title` moved above the push, and the recovery hint in `create_draft_pr` |
| `.agent/scripts/tests/test_worktree_create.sh` | Refused-push tests (no new file, so no `chmod` on the test; the hook inside the test gets `chmod +x`) |
| `.agent/WORKTREE_GUIDE.md` | One sentence under "Draft PRs with Plan File" |

## Prior Art

Nothing new is being built. The test reuses `make_ws_repo`, `gitq` and `run_create`, and a bare origin built as `add_origin_ahead` does.

## Serves

A safeguard has to earn its cost (a message that says non-fatal must act non-fatal); Isolated worktrees for every task: `docs/design.md#worktrees`.

## Design Picture

No change to the design picture. The design already treats the draft PR as best effort.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Report what happened | The exit status now matches the "non-fatal" message, and the warning says how to recover. |
| Test what you ship | A refused-push test covers exit, worktree, warning and next steps. |
| Only what's needed | One function, one test; the other failure paths (`cd`, `mktemp`) are real errors and stay as they are. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0009, 0010, 0013, 0017 | No | No installs, issue writes or design change. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `worktree_create.sh` exit status on push failure | `start-task` skill, WORKTREE_GUIDE, script_reference | Yes: checked, only the one guide sentence |

## Open Questions

None.

## Estimated Scope

Single PR.
