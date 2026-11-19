# Plan: worktree_create.sh exits 1 when only the draft pull request's push failed

## Issue

Issue 516 in rolker/agent_workspace.

## Context

`create_draft_pr` in `.agent/scripts/worktree_create.sh` prints "Push failed — skipping draft PR (non-fatal)" and then `return 1`. With `set -e` on, the script exits 1 before `cd "$ROOT_DIR"`, the "Next steps" text and the pre-commit hook preflight, although the worktree already exists. Every other failure in the function only warns and ends with status 0.

## Approach

1. **Return 0 after the failed push** — in `create_draft_pr`, change `return 1` to `return 0`. The fix stays in the function; the four call sites need no `|| true`.
2. **Make the warning say what to do** — move the `pr_title` computation above the push and build the hint's body text with the same branches the function uses for its body file (skill worktree, `Closes`, `Part of`). After a failed push the warning says the branch is not on origin and prints lines a person can paste and run, in this order: `cd <WORKTREE_DIR>` (absolute; `git push` and `gh_create_pr.sh` take the branch from the current checkout, so both must run there), `git push -u origin <branch>`, then `<SCRIPT_DIR>/gh_create_pr.sh --draft [-R <repo_flag>] [--base <base_flag>] --title <pr_title via printf %q> --body <body via printf %q>`. The script is named by its absolute path (`$SCRIPT_DIR/gh_create_pr.sh`, set at line 34), which exists from every worktree type including a single-repository project worktree. `-R` is added only when `repo_flag` is set and `--base` only when `base_flag` is set. The body is inline: `gh_create_pr.sh` accepts `--body` and adds the signature to it (checked in its header and lines 105-107, 199), so nothing names a file that does not exist. When `HAS_PLAN` is true the plan was not posted, and a further line prints it: `gh pr comment <branch> [-R <repo_flag>] --body-file <absolute plan file>`, run after the PR exists (`gh pr comment` takes a branch name as the selector, so no URL is needed; it runs in the same worktree). The final line is "Push failed" text kept as the first line. Never bare `gh pr create`. Exactly what prints (`W` = worktree directory, `S` = script directory, `B` = branch, `T` = `printf %q` of the title):
   - workspace worktree (`repo_flag`, `base_flag` empty):
     `cd W`; `git push -u origin B`; `S/gh_create_pr.sh --draft --title T --body 'Closes #N'`; and with a plan, `gh pr comment B --body-file <plan>`.
   - single-repository project worktree (`repo_flag` = `$PROJECT_GH_SLUG`): the same lines with `-R <owner/repo>` after `--draft` and `-R <owner/repo>` on the `gh pr comment` line.
   - `--parent-issue` worktree (`base_flag` = `$PR_PARENT_BASE`): the workspace lines with `--base <parent branch>` after `--draft` and the body `$'Closes #N\nPart of #P'` (`printf %q` of the two-line text, as the function writes `Part of #P` on the line after `Closes`); plus `-R` as in the project case if it is a project worktree.
   - skill worktree (`issue_ref` empty, no repo or base): the same `cd`, push and `comment` lines, and `S/gh_create_pr.sh --draft --title T --body B` where `T` quotes `[PLAN] Skill update: <skill>` and `B` quotes `$ISSUE_TITLE` plus "Automated update from the `<skill>` skill." (the function's skill body text; there is no `Closes` line for a skill worktree).
   The title carries `[PLAN]` because `--plan-file` is what reaches this function. The `gh pr comment` line appears in all four when `HAS_PLAN` is true, preceded by the words "the plan was not posted".
3. **Test** — in `.agent/scripts/tests/test_worktree_create.sh`, before the Summary, add a bare origin (`gitq init --bare`, same as `add_origin_ahead`) wired to a fresh `make_ws_repo` sandbox and given its set-up `push origin main` first; only after that push is `hooks/pre-receive` (`exit 1`) written and made executable with `chmod +x` (git skips a non-executable hook, and a hook in place earlier would refuse the set-up push too), and a scratch plan file. Run `run_create` with `--issue <N> --type workspace --plan-file <file>`. Assert: RC is 0; the worktree directory exists on `feature/issue-<N>`; the output has "Push failed" (this stays: it proves the hook refused the push), the hint contains the absolute script path `<sandbox scripts dir>/gh_create_pr.sh` (not the relative `.agent/scripts/...`), `--draft`, the `Closes #<N>` body, the `cd` to the worktree directory, the not-posted plan line, and "To enter this worktree". A second run in a fresh sandbox of the same refused-push case adds `--print-path-only` with stdout captured on its own (`run_create` merges stderr) and asserts stdout is exactly the worktree path and RC is 0; this is the `start-task` call that was broken.
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

## Added after the plan was approved

- A relative `--plan-file` is resolved from the caller's directory (`CALLER_DIR`), where the argument is parsed, not from the workspace root. Asked for by the round 2 `## Local Review (Pre-Push)` (2026-11-19 13:34 -05:00) and fixed by the `## Integrated Review` (2026-11-19 13:39 -05:00, PR #526); `CALLER_DIR` in place of `$PWD` came from the `## Local Review` at `e1b99bf1`.
- The `start-task` SKILL.md and the script's usage text say what a relative plan path is relative to. Asked for in the host's handoff for that `## Integrated Review` fix round (after its `## Checkpoint`, 2026-11-19 13:39 -05:00).
- The hint's `--body` carries the same body as the draft PR's body file, so it now has the `## Summary` heading and the issue title (plan-review note 4 had accepted the hint without them). Follows from suggestion 6 of the round 1 `## Local Review (Pre-Push)` (2026-11-19 13:12 -05:00): build the body once.
