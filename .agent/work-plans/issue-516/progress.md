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
