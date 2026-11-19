# Plan: worktree_create.sh exits 1 when only the draft pull request's push failed

## Issue

Issue 516 in rolker/agent_workspace.

## Context

`create_draft_pr` in `.agent/scripts/worktree_create.sh` prints "Push failed — skipping draft PR (non-fatal)" and then `return 1`. With `set -e` on, the script exits 1 before `cd "$ROOT_DIR"`, the "Next steps" text and the pre-commit hook preflight, although the worktree already exists. Every other failure in the function only warns and ends with status 0.

## Approach

1. **Return 0 after the failed push** — in `create_draft_pr`, change `return 1` to `return 0`. The fix stays in the function; the four call sites need no `|| true`.
2. **Make the warning say what to do** — the message states the branch is not on origin and gives the way to open the pull request later: `git push -u origin <branch>`, then `gh pr create --draft`.
3. **Test** — in `.agent/scripts/tests/test_worktree_create.sh`, before the Summary, add a bare origin (`gitq init --bare`, same as `add_origin_ahead`) whose `hooks/pre-receive` is `exit 1`, wired to a fresh `make_ws_repo` sandbox, and a scratch plan file. Run `run_create` with `--issue <N> --type workspace --plan-file <file>`. Assert: RC is 0; the worktree directory exists on `feature/issue-<N>`; the output has "Push failed" and the new "git push -u origin" hint; the output has "To enter this worktree". A second assertion block covers the hook preflight text if the sandbox reaches it (checked while writing the test; dropped if the sandbox has no hook to report).
4. **Documents** — read `start-task` SKILL.md, `.agent/WORKTREE_GUIDE.md` and `.agent/knowledge/script_reference.md`. None says that a non-zero exit from `--plan-file` means "push failed" or tells callers to retry. SKILL.md line 174 ("exit non-zero on real failures") stays true. No sentence changes. WORKTREE_GUIDE "Draft PRs with Plan File" gets one added sentence: a failed push warns and the worktree is still made.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/worktree_create.sh` | `return 0` and the longer warning in `create_draft_pr` |
| `.agent/scripts/tests/test_worktree_create.sh` | Refused-push test (no new file, so no `chmod`) |
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
