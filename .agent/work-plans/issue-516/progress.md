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

## Checkpoint
**Status**: complete
**When**: 2026-11-19 12:51 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's one needs-work finding is about the wording of a hint; mechanism)
**After**: plan
**Decision**: revise

The host takes the Plan Review's three findings as written. (1) The recovery hint is built from the function's own repo_flag, base_flag and pr_title and names gh_create_pr.sh --draft, never bare gh pr create; it also says the plan comment was not posted; the test checks the hint names gh_create_pr.sh. (2) The test's pre-receive hook is made executable, and the "Push failed" assertion stays; the optional preflight-text assertion is dropped. (3) A second run with --print-path-only checks that stdout is exactly the worktree path.

## Plan Authored
**Status**: complete
**When**: 2026-11-19 12:52 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-516/plan.md` at `6c93e19a`

Revision after the plan review: the recovery hint is built from repo_flag, base_flag and pr_title and names gh_create_pr.sh --draft; the test hook is executable and a --print-path-only run checks stdout.

## Plan Review
**Status**: complete
**When**: 2026-11-19 12:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #516 — worktree_create.sh exits 1 when only the draft pull request's push failed
**Plan**: `.agent/work-plans/issue-516/plan.md` at `6c93e19a`
**Branch**: `feature/issue-516`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One function, one test file, one guide sentence. |
| Issue alignment | Good | The first review's three findings are taken as the checkpoint decided: the hint is built from `repo_flag`, `base_flag` and `pr_title` with `gh_create_pr.sh --draft` and mentions the unposted plan, and the test asserts `gh_create_pr.sh` (finding 1); the hook gets `chmod +x`, "Push failed" stays, the preflight block is gone (finding 2); a `--print-path-only` run with stdout captured on its own is added (finding 3). Serves: "A safeguard has to earn its cost (a message that says non-fatal must act non-fatal); Isolated worktrees for every task: `docs/design.md#worktrees`", unchanged and checked in the first review. |
| File targeting | Good | Same three files. |
| Consequences | Good | Unchanged from the first review; callers checked there. |
| Principle alignment | Needs work | The printed recovery line does not run as written (finding 1). |
| ADR compliance | Good | None triggered. |
| ROS conventions | N/A | Workspace plan. |

Checked against `.agent/scripts/gh_create_pr.sh`: it takes `-R`/`--repo` itself (and skips its repo-safety check when given), passes `--draft`, `--base` and `--title` through to `gh pr create`, and reads `--body-file`, signing the body (it hard-fails without `AGENT_NAME`/`AGENT_MODEL`). So the flags are right for all four cases, and the `-R`/`--base` mapping per case in the plan matches the call sites (lines 1357-1365: workspace skill `""`; workspace issue `"" "$PR_PARENT_BASE"`; project skill `"$PROJECT_GH_SLUG"`; project issue `"$PROJECT_GH_SLUG" "$PR_PARENT_BASE"`). `[PLAN] Skill update: <skill>` matches: `ISSUE_TITLE` is set to `Skill update: $SKILL_NAME` before the call and `PLAN_FILE` is always set on this path.

### Findings

1. **[Principle alignment] (needs-work)** — The printed line will not run as written, and following it opens a PR that does not close the issue. (a) `--body-file <file>`: no body file exists at that point. `BODY_FILE` is made by `mktemp` after the push (line 1291) and the function removes it at the end, so the hint can only print a placeholder, and the body the function would have used (`Closes #N`, plus `Part of #<parent>` for a `--parent-issue` worktree) is lost; someone writing their own file can easily leave out `Closes`. Print the body inline instead, e.g. `--body "Closes #N"` (with `Part of #P` when `PARENT_ISSUE_NUM` is set; for a skill worktree the skill line), since `gh_create_pr.sh` adds the signature. (b) Directory and script path: `git push -u origin <branch>` and `gh_create_pr.sh` (which lets `gh pr create` take the head branch from the current checkout) must both run in the worktree, and the plan does not say so. The planned `.agent/scripts/gh_create_pr.sh` is a relative path that exists in a workspace worktree but not in a single-repository project worktree, which is the project's own repository. Print `cd <WORKTREE_DIR>` (or name the directory) and the script as `$SCRIPT_DIR/gh_create_pr.sh`, an absolute path that works from every worktree type. Have the test assert the absolute script path and the `Closes #N` body in the hint.

Notes for the implementer (not blocking):
- Quote the title with `printf '%q'` (or single quotes with escaping) when printing it: an issue title with `"`, `$` or a backtick would break a double-quoted line.
- In the test, add the `pre-receive` hook to the bare origin after the initial `push origin main` (as `add_origin_ahead` does it), or that setup push is refused too.
- When `HAS_PLAN` is true the hint could also print the `gh pr comment <url> --body-file <plan file>` step, using the plan file's absolute path; saying it was not posted is the minimum the checkpoint asked for.

### Summary

The three findings of the first review are resolved as the checkpoint decided, and the `gh_create_pr.sh` flags are right for all four worktree kinds. The recovery line still cannot be run as printed: it points at a body file that does not exist and at a relative script path that a project worktree lacks, and it does not say to run it in the worktree.

### Recommended Actions

- [ ] Print the body inline (`Closes #N`, `Part of #P` when set; the skill line for a skill worktree) instead of `--body-file <file>`.
- [ ] Print the worktree directory to run from and the script as `$SCRIPT_DIR/gh_create_pr.sh`; assert both and the `Closes` body in the test.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 12:54 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second plan review's one needs-work finding is that the printed recovery line would not run; mechanism; this is the host's second revise in a row, so a third answer at this checkpoint is the owner's)
**After**: plan
**Decision**: revise

The host takes the second Plan Review's finding and its three notes as written. The hint prints the worktree directory to run from, then git push -u origin <branch>, then the script by its absolute path ($SCRIPT_DIR/gh_create_pr.sh) with --draft, -R and --base when set, the title quoted with printf %q, and the body inline (--body with the same Closes / Part of text the function would have written; gh_create_pr.sh adds the signature), with no --body-file naming a file that does not exist. When a plan file was given it also prints the gh pr comment step for the plan that was not posted. The test adds the refusing hook after its set-up push, and asserts the absolute script path and the Closes body in the hint.

## Plan Authored
**Status**: complete
**When**: 2026-11-19 12:55 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-516/plan.md` at `d3e7f045`

Second revision: the failed-push hint prints the worktree directory, git push, then the absolute-path gh_create_pr.sh line with --draft, -R and --base when set, printf %q title and an inline --body (Closes / Part of, or the skill text), plus the gh pr comment line for the unposted plan; the test adds the refusing hook after the set-up push and asserts the absolute path and Closes body.

## Plan Review
**Status**: complete
**When**: 2026-11-19 12:56 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #516 — worktree_create.sh exits 1 when only the draft pull request's push failed
**Plan**: `.agent/work-plans/issue-516/plan.md` at `d3e7f045`
**Branch**: `feature/issue-516`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One function, one test file, one guide sentence. |
| Issue alignment | Good | The second review's finding and three notes are resolved as the checkpoint decided: `cd <WORKTREE_DIR>` first, `git push -u origin <branch>`, the script by its absolute path `$SCRIPT_DIR/gh_create_pr.sh`, `--draft` with `-R`/`--base` only when set, title through `printf %q`, inline `--body` with the function's own `Closes` / `Part of` / skill text (no `--body-file` naming a missing file), the `gh pr comment <branch> [-R]` line for the unposted plan, and the refusing hook added after the set-up push. Serves: "A safeguard has to earn its cost (a message that says non-fatal must act non-fatal); Isolated worktrees for every task: `docs/design.md#worktrees`", unchanged and checked in the first review. |
| File targeting | Good | Same three files. |
| Consequences | Good | Unchanged from the first review; callers checked there. |
| Principle alignment | Good | Every printed line runs as written in all four cases (checked below). |
| ADR compliance | Good | None triggered. |
| ROS conventions | N/A | Workspace plan. |

Checked per case against `.agent/scripts/gh_create_pr.sh` and `create_draft_pr` (lines 1253-1350, call sites 1357-1365):
- `gh_create_pr.sh` accepts `--body` (header line 14, parse at 103-110) and signs it by appending to the `--body` argument (lines 206-225); `-R` sets `GH_REPO`, which skips the repo-safety check (line 134); `--draft`, `--base`, `--title` pass through (lines 47-48). Its user-tier guard (`registry_require_root`, line 87) accepts the current directory when it is inside the workspace checkout or under a registered project root: a workspace worktree (`worktrees/workspace/...`) and a project worktree in the default `<project>/worktrees` both pass, which is why the `cd W` line first matters.
- Workspace issue worktree: `cd W`; push; `S/gh_create_pr.sh --draft --title T --body <Closes #N>`; runs, targets origin of the worktree, base is the default branch, as the function would.
- Single-repository project worktree: same with `-R <PROJECT_GH_SLUG>`, matching the function's `--repo`; `gh pr comment B -R <slug>` selects the PR by branch.
- `--parent-issue` worktree: `--base <PR_PARENT_BASE>` matches the function's `--base`; body `printf %q` of `$'Closes #N\nPart of #P'` prints as `$'Closes #N\nPart of #P'`, which bash expands back to the two lines the function writes.
- Skill worktree: no `-R`/`--base` for workspace skills (`create_draft_pr "$WORKTREE_DIR" ""`), `-R` for an `onboard-project` skill worktree; no `Closes`; title `[PLAN] Skill update: <skill>`; body is the skill text. Runs.
- `gh pr comment <branch>`: accepted per `gh pr comment --help` (host-checked); run from the worktree, so the branch resolves in the right repository.

### Findings

None blocking. Notes for the implementer:
1. **[Test] (low)** — `printf %q 'Closes #516'` prints `Closes\ #516` (checked), so a test asserting the literal text `Closes #516` in the output will fail. Assert the escaped form, or the `printf %q` result computed in the test.
2. **[Hint] (low)** — Quote the `cd` path and the `--body-file <plan>` path with `printf %q` too; a worktree or plan path with a space would otherwise break the pasted line.
3. **[Hint] (low)** — `gh_create_pr.sh` hard-fails with instructions when `AGENT_NAME`/`AGENT_MODEL` are unset in the shell where the line is pasted (`worktree_create.sh` defaults them inside its own process only). Its error says what to do, so the line still behaves correctly; one hint line naming `set_git_identity_env.sh` would save a round trip.
4. **[Hint] (low)** — The inline body is shorter than the function's (no `## Summary` and title). It still closes the issue; adding the title is optional.
5. **[Pre-existing, no action]** — A project whose `worktrees=` override lies outside both the project root and the workspace checkout would be refused by `gh_create_pr.sh`'s user-tier guard (`registry_require_root` uses `registry_resolve_from_dir`, not the session resolver). This is the wrapper's existing behavior for any PR from such a worktree, not something this plan introduces.

### Summary

The finding and notes of the second review are resolved as the checkpoint decided, and each printed line runs as written and opens the same pull request the function would have opened, in all four cases. Ready for implementation; the notes above are small and for the implementer.

### Recommended Actions

- [ ] In the test, match the `printf %q` form of the `Closes` body.
- [ ] Quote the printed `cd` and plan-file paths with `printf %q`.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 12:56 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (third plan review: ready, five low notes)
**After**: plan
**Decision**: proceed

The third Plan Review found every printed line runs as written in all four cases. Its notes 1 to 3 go to the implementer in the handoff: the test matches the escaped form printf %q prints for the body; the printed cd path and plan-file path are quoted with printf %q too; the hint names set_git_identity_env.sh, since gh_create_pr.sh stops when AGENT_NAME or AGENT_MODEL is unset. Note 4 (the inline body has no Summary heading or issue title) is accepted as it is. Note 5 is older behaviour and no action.

## Implementation
**Status**: complete
**When**: 2026-11-19 13:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-516 at `1ac07db1`

- `.agent/scripts/worktree_create.sh`: `create_draft_pr` returns 0 after a failed push, so the script goes on to `cd "$ROOT_DIR"`, the next steps and the hook preflight. `pr_title` is computed above the push. The warning now prints, each quoted with `printf %q`: `cd <worktree>`, `git push -u origin <branch>`, `<scripts dir>/gh_create_pr.sh --draft [-R <repo>] [--base <parent>] --title <[PLAN] title> --body <Closes #N[ / Part of #P] or the skill text>`, and when a plan file was given, "The plan was not posted" with `gh pr comment <branch> [-R <repo>] --body-file <absolute plan>`. It names `set_git_identity_env.sh` (path quoted), since `gh_create_pr.sh` stops when `AGENT_NAME`/`AGENT_MODEL` are unset.
- `.agent/scripts/tests/test_worktree_create.sh`: a bare origin whose `pre-receive` hook (written after the set-up push, `chmod +x`) refuses pushes; `--issue 71 --plan-file` asserts exit 0, the worktree on `feature/issue-71`, "Push failed", the quoted `cd`, the push line, the absolute `gh_create_pr.sh --draft` line with the `printf %q` form of `Closes #71`, `set_git_identity_env.sh`, the not-posted plan line and "To enter this worktree"; a second sandbox with `--print-path-only` asserts exit 0 and stdout exactly the worktree path. With `return 1` put back temporarily all three checks fail (checked).
- `.agent/WORKTREE_GUIDE.md`: one sentence under "Draft PRs with Plan File": a failed push warns, prints the commands, and the worktree is still made; the failed push alone does not make the script exit non-zero.
- Paste trial: a sandbox workspace whose path has a space (`my ws`), all `.agent/scripts/*.sh` copied in, a local bare origin refusing pushes, `gh` stubbed to log its arguments. `worktree_create.sh --issue 81 --type workspace --plan-file "<sandbox>/plan 516.md"` exited 0 and printed the hint. After removing the hook, the four printed lines (cd, push, gh_create_pr.sh, gh pr comment) were saved as-is and run with `bash -e` with AGENT_NAME/AGENT_MODEL set: exit 0, the branch landed on origin, gh got `pr create --draft --title "[PLAN] Issue #81" --body "Closes #81" + signature` and `pr comment feature/issue-81 --body-file "<sandbox>/plan 516.md"` with the space intact. Sandbox removed.
- Departures: the worktree directory name in the tests is `issue-origin11-71` / `issue-origin12-72` (the slug comes from the bare origin's name), not `issue-workspace-<N>`; the guide sentence is worded "does not make it exit non-zero" rather than "exits 0", which the code cannot promise for other failures.

Suites run (each on its own with bash; the full pre-commit pass is left to the host):
- test_worktree_create.sh: PASS: 93 / FAIL: 0
- test_merge_pr.sh: Results: 170 passed, 0 failed
- test_merge_pr_skill.sh: 132 passed, 0 failed
- test_precommit_hook_path.sh: 19 passed, 0 failed
- test_project_registry.sh: Results: 425 passed, 0 failed
- test_validate_workspace_stale.sh: 126 passed, 0 failed
- test_user_tier_install.sh: 276 passed, 0 failed
- test_records_write_gate.sh: 68 passed, 0 failed
- test_ros2_colcon.sh: Results: 1375 passed, 0 failed, 0 skipped
- test_skill_paths.sh: 163 passed, 0 failed
- test_user_tier_guard.sh: 64 passed, 0 failed
- test_package_issue_loop.sh: 220 passed, 0 failed

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 13:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-516 at `f5c68a46`
**Base**: main
**Depth**: Deep (reason: 452 changed lines with plan/progress; code diff ~105 lines; Deep dispatches the same specialists as Standard)
**Must-fix**: 0 | **Suggestions**: 6
**Round**: 1 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Verified by hand: test_worktree_create.sh 93 passed / 0 failed; shellcheck --severity=warning clean on both scripts. Sandbox trial (workspace path with a space, plan path with a space, refusing pre-receive hook, gh stub logging arguments, issue title `Fix $(touch PWNED) & 'q' "dq" \`bt\``): workspace, --parent-issue 5 and --skill research worktrees each exit 0 and print the hint; --print-path-only exits 0 with stdout exactly the worktree path. With the hook removed, the pasted lines pushed each branch and gh received `pr create --draft [--base feature/issue-5] --title "[PLAN] <title verbatim>" --body "Closes #N[\nPart of #5] + signature"` (skill: the skill body text) and `pr comment <branch> --body-file "<plan path with space>"`; no command substitution ran. Success path unchanged (pr_title only moved). WORKTREE_GUIDE sentence matches the code. Outside reviewers: Claude adversarial (fresh subagent) ran, no must-fix; gemini ran (EXIT=0), 8 suggestions, mostly test coverage, 2 with substance; codex ran (EXIT=0), 1 claimed must-fix judged a suggestion (pre-existing gh_create_pr.sh guard, plan-review note 5), 2 suggestions.

### Findings
- [x] (suggestion) The warning says "The branch ... is not on origin" and the push's stderr goes to /dev/null; a non-fast-forward rejection of an existing remote branch makes that sentence false and hides why. Say the push failed and show git's error (gemini, codex) — `.agent/scripts/worktree_create.sh:1274-1279`
- [x] (suggestion) Pre-existing: a relative --plan-file passes the -f check against ROOT_DIR, but the success path's `gh pr comment --body-file "$PLAN_FILE"` runs after `cd "$git_dir"` and cannot read it. Resolve PLAN_FILE to an absolute path once where HAS_PLAN is set; the hint then needs no plan_abs (Claude adversarial) — `.agent/scripts/worktree_create.sh:1226-1231,1325,1347`
- [x] (suggestion) The new tests cover only a workspace worktree with an absolute plan; no case pins the -R, --base/Part of, skill-body or relative-plan branches of the hint, the title's [PLAN] prefix (`--title "*"` matches anything), or that no `gh pr create` runs after the refused push (a recording gh stub would). Add a --parent-issue case and a relative plan case (Claude adversarial, gemini, codex) — `.agent/scripts/tests/test_worktree_create.sh:1115-1171`
- [x] (suggestion) The printed gh_create_pr.sh line is refused by its user-tier guard in a project whose `worktrees=` directory lies outside both the project root and the workspace; pre-existing wrapper behaviour (plan-review note 5, checkpoint: no action), worth its own issue against gh_create_pr.sh / registry_require_root (codex) — `.agent/scripts/gh_create_pr.sh:87` (deferred: host checkpoint 2026-11-19 13:10: older behaviour of another script (gh_create_pr.sh's user-tier guard), not changed here; the host proposes an issue for it to the owner)
- [x] (suggestion) The hint always runs gh_create_pr.sh; if a PR already exists for the branch (e.g. a re-run whose push was rejected) it fails with gh's "already exists". One line saying to skip it when `gh pr list --head <branch>` shows a PR would cover it (Claude adversarial) — `.agent/scripts/worktree_create.sh:1290-1296`
- [x] (suggestion) The hint's body text (skill text / Closes / Part of) duplicates the BODY_FILE heredoc branches; building it once above the push would keep the two from drifting (gemini) — `.agent/scripts/worktree_create.sh:1282-1288`

## Checkpoint
**Status**: complete
**When**: 2026-11-19 13:10 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review approved with six suggestions; five are small, in reach, and two of them are about a hidden error and an existing bug on the same lines, which the Quality Standard says to fix now)
**After**: publish
**Decision**: address

The full pre-commit pass was not run: the answer changes the code, so the pass runs on the head that follows. Fixed in this round: suggestion 1 (the warning says the push failed and shows git's own error, and does not claim the branch is absent from origin); suggestion 2 (PLAN_FILE is made absolute once where HAS_PLAN is set, which also fixes the success path's plan comment for a relative path); suggestion 3 (tests for the -R, --base / Part of, skill-body and relative-plan branches of the hint, the [PLAN] title, and that no pr create runs after the refused push); suggestion 5 (one line saying to skip the create step when a pull request for the branch already exists); suggestion 6 (the body is built once, above the push, and used by both the hint and the body file). Suggestion 4 (the user-tier guard in gh_create_pr.sh refusing a worktree folder outside both the project root and the workspace) is older behaviour of another script and is not changed here; the host proposes an issue for it to the owner.

## Implementation
**Status**: complete
**When**: 2026-11-19 13:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-516 at `b285d884`
**Addressed**: Local Review (Pre-Push) at `f5c68a46` (2026-11-19 13:12 -05:00)
**Commits**: 969f2670, 2dab4cd4, e11af985, d74f8943, 5f29acd8, b285d884

### Actions
- [x] Suggestion 1: the warning says "Push failed ... git push -u origin <branch> said:" and prints git's own stderr indented (trailing padding of `remote:` lines trimmed, b285d884); the "is not on origin" sentence is gone; tests assert the hook's `remote:` line and "pre-receive hook declined" appear and the old claim does not — `.agent/scripts/worktree_create.sh` create_draft_pr (e11af985, b285d884)
- [x] Suggestion 2: `PLAN_FILE` is made absolute (against `$PWD`, which is ROOT_DIR there) where `HAS_PLAN=true` is set; `plan_abs` is gone. Reproduced first: a new success-path test (relative `notes/plan 73.md`, recording gh stub) failed with `comment-file missing: notes/plan 73.md`; it passes after the fix — `.agent/scripts/worktree_create.sh` HAS_PLAN block (969f2670)
- [x] Suggestion 3: `make_recording_gh` stub; tests for the [PLAN] title and no `pr create`/`pr comment`/`pr list` after the refused push, `--parent-issue` (`--base feature/issue-80`, `Part of #80`) with a relative plan (absolute path in the comment line), `--skill research` (skill title and body), and a single-repository project (`-R acme/demo15` on the create, list and comment lines; its origin is a local bare repo at `.../github.com/acme/demo15.git` so the slug reads). Mutation-checked: dropping `return 0`, `-R`, `--base`, `[PLAN]` or `Part of` each fails a test — `.agent/scripts/tests/test_worktree_create.sh` (5f29acd8)
- [x] Suggestion 4: user-tier guard in gh_create_pr.sh — `.agent/scripts/gh_create_pr.sh:87` (deferred: host checkpoint 2026-11-19 13:10: older behaviour of another script, not changed here; the host proposes an issue for it to the owner)
- [x] Suggestion 5: one line after the create line: "Skip the gh_create_pr.sh line if `gh pr list --head <branch> [-R <repo>]` already shows a pull request."; test fails without it — `.agent/scripts/worktree_create.sh` (d74f8943)
- [x] Suggestion 6: `pr_body` (## Summary, title, Closes [+ Part of] or the skill text) is built once above the push; the hint's `--body` and the body file (`pr_body` + signature via printf) both use it. The hint's body now carries the Summary heading and title too (it did not before); tests assert both forms — `.agent/scripts/worktree_create.sh` (2dab4cd4)

Paste trial (sandbox workspace `my ws` under a path with a space, all `.agent/scripts` and `.agent/project_types` copied in, local bare origins under `.../github.com/acme/` whose pre-receive hook prints a line and refuses, gh stubbed to log its arguments): (a) `--issue 81 --type workspace --parent-issue 80 --plan-file "notes/plan 81.md"` and (b) `--issue 91 --type project --project demo --plan-file <abs plan>` each exited 0, ran no gh pr create/comment, and printed git's rejection lines and the hint. After removing the hook, the cd, push, gh_create_pr.sh and gh pr comment lines were saved as printed and run with `bash -e` (AGENT_NAME/AGENT_MODEL set): exit 0 both times, each branch landed on origin, gh got (a) `pr create --draft --base feature/issue-80 --title "[PLAN] Issue #81" --body "## Summary\n\nIssue #81\n\nCloses #81\nPart of #80" + signature` and `pr comment feature/issue-81 --body-file "<ws>/notes/plan 81.md"`; (b) `pr create --draft --repo acme/demo --title "[PLAN] Issue #91" ...` and `pr comment feature/issue-91 -R acme/demo --body-file ...`. Sandbox removed. Departure: the project's folder had no space in its path, since projects.local refuses paths with spaces.

`.agent/WORKTREE_GUIDE.md` line 394 checked: still true as written (warns, prints the commands, makes the worktree, failed push alone does not make it exit non-zero); not changed.

Suites run (each on its own with bash; the full pre-commit pass is left to the host):
- test_worktree_create.sh: PASS: 101 / FAIL: 0
- test_precommit_hook_path.sh: 19 passed, 0 failed
- test_merge_pr_skill.sh: 132 passed, 0 failed
- test_user_tier_guard.sh: 64 passed, 0 failed
- test_validate_workspace_stale.sh: 126 passed, 0 failed
- test_user_tier_install.sh: 276 passed, 0 failed
- test_package_issue_loop.sh: 220 passed, 0 failed
- test_records_write_gate.sh: 68 passed, 0 failed
- test_skill_paths.sh: 163 passed, 0 failed
- test_project_registry.sh: Results: 425 passed, 0 failed
- test_merge_pr.sh: Results: 170 passed, 0 failed
- test_ros2_colcon.sh: Results: 1375 passed, 0 failed, 0 skipped

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 13:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent ab8fe1f4c5985ec5a, resume 1 of 3)

**Branch**: feature/issue-516 at `47666fbf`
**Base**: main
**Depth**: Deep (reason: whole-branch diff over 200 lines with plan/progress; same specialists as Standard)
**Must-fix**: 0 | **Suggestions**: 5
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Verified by hand: test_worktree_create.sh 101 passed / 0 failed; shellcheck --severity=warning clean on both scripts. I compared the success path against origin/main (dd53c590) in sandboxes with a working origin and a recording gh stub, using four cases: a workspace worktree and a single-repository project worktree, each with an absolute and a relative --plan-file. The issue title was `T $(x) 'q' %s`. In all four cases gh got the same calls and arguments (pr list, pr create --draft --title "[PLAN] ..." --body-file [--repo acme/...]), and the body file was byte-identical. The only difference was the intended fix: on main, a relative plan path made the plan comment read `notes/plan rel.md` from inside the worktree, so the comment failed; on the branch it reads the absolute path, and the comment posts. Credential check: with origin set to `https://user:s3cretTOKEN@127.0.0.1:9/...` and --allow-unverified-branch, the warning showed git's error as `unable to access 'https://127.0.0.1:9/acme/x.git/'`, and the token appeared 0 times in the output (git strips credentials from URLs in its messages; the script's existing fetch error already prints the same form). Paste check: the multi-line body survived printf %q (`$'## Summary\n\nT $(x) \'q\' %s\n\nCloses #202'`). The pasted lines ran under bash -e (exit 0), and gh_create_pr.sh passed gh a body equal to the body file's. Outside reviewers: Claude adversarial (fresh subagent) ran, no must-fix; it found the body bytes identical for titles with %s, $(x), backticks and \\, and made 4 suggestions. gemini ran (EXIT=0) with 5 suggestions, 2 of substance. Its pre-push hook stdout point does not hold, because git sends hook stdout to stderr. codex ran (EXIT=0). It repeated the deferred user-tier guard finding (not raised again, per host decision) and made 1 suggestion.

### Findings
- [ ] (suggestion) The guide sentence says the script prints the command to "post the plan", but that line is printed only when the plan file was found (HAS_PLAN); "and, if the plan file was found, post the plan" would be exact (Claude adversarial) — `.agent/WORKTREE_GUIDE.md:394`
- [ ] (suggestion) Pre-existing, now encoded by the new comment and test: a relative --plan-file is resolved against the workspace root (cd at line 852), not the caller's cwd, so a relative path given from a project root or a subdirectory is "not found" and the PR is still titled [PLAN]. Making the path absolute at parse time would match what callers expect (Claude adversarial) — `.agent/scripts/worktree_create.sh:302,1231-1233`
- [ ] (suggestion) When git prints nothing on stderr, the warning ends in a dangling "said:"; gate that phrase on a non-empty push_err (Claude adversarial, gemini) — `.agent/scripts/worktree_create.sh:1294-1296`
- [ ] (suggestion) An issue title containing `**Authored-By**:` now appears in the hint's --body, so gh_create_pr.sh treats the body as already signed and the pasted PR goes unsigned, while the success path always signs (codex) — `.agent/scripts/worktree_create.sh:1276-1285,1303`
- [ ] (suggestion) Tests: the body-file check after the SB13 case reuses the previous check's fail label and prints the wrong log; the `grep -q "^pr comment ... $SB13/..."` treats the sandbox path as a regex (use -xF); the --print-path-only case does not check that the warning reached stderr (Claude adversarial, gemini) — `.agent/scripts/tests/test_worktree_create.sh:1227,1253-1262`

## Checkpoint
**Status**: complete
**When**: 2026-11-19 13:37 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 2 approved with no must-fix; the host's full pre-commit pass over the branch passed at 70e6632b, every hook, no SKIP)
**After**: publish
**Decision**: publish

Round 2, with the outside reviewers, approved the branch and left five suggestions, which the pull request lists. The full pass ran on head 70e6632b with exit 0, the script test suites included.

## Integrated Review
**Status**: complete
**When**: 2026-11-19 13:39 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #526 at `81edecc`
**Sources**: 3 (Local Review (Pre-Push) round 2 @ `47666fb` (covers 81edecc via bookkeeping), Local Review (Pre-Push) round 1 @ `f5c68a46` (all boxes closed; its deferred user-tier guard finding re-checked), CI rollup). No GitHub reviews, inline or conversation comments; no Copilot review requested.
**Cross-source confirmations**: 0
**CI**: pending

Checked by hand at 81edecc: test_worktree_create.sh 101 passed / 0 failed. The PR body has a level-2 `## Decision summary` heading (read from `gh pr view 526 --json body`). Body claims checked against the code: git's stderr is shown, the hint lines (cd, push, gh_create_pr.sh --draft with -R/--base/title/body, skip-if-exists line, identity reminder) match `create_draft_pr`; one imprecision: "when a plan file was given, the gh pr comment line" is printed only when the plan file was found (HAS_PLAN), the same point as finding 1. ROOT_DIR is the workspace root (`worktree_create.sh:35`), confirming finding 2 for project sessions.

### Findings
- [ ] (suggestion, Local Review @ 47666fb) The guide sentence says the script prints the command to post the plan, but it does so only when the plan file was found; say "and, if the plan file was found, post the plan" (false documentation, one-line fix; fix now) — `.agent/WORKTREE_GUIDE.md:394`
- [x] (suggestion, Local Review @ 47666fb) A relative --plan-file is resolved against the workspace root after the `cd "$ROOT_DIR"` (line 852), not the caller's cwd; a project session (start-task passes the user's path as typed) gets "Plan file not found", a PR titled [PLAN] with no plan comment. Make PLAN_FILE absolute against $PWD at parse time (the `--plan-file)` case near line 302) and drop the in-function absolutization; update the SB13/relative-plan tests to run from the directory the path is relative to (fix now) — `.agent/scripts/worktree_create.sh`
- [ ] (suggestion, Local Review @ 47666fb) When git writes nothing to stderr the warning line ends in "said:" with nothing after it; print the "git push ... said:" phrase only when push_err is non-empty (fix now) — `.agent/scripts/worktree_create.sh`
- [ ] (suggestion, Local Review @ 47666fb) Tests: the body-file check after the SB13 case reuses the previous check's fail message (wrong diagnostics on failure); the `grep -q "^pr comment ... $SB13/..."` treats the sandbox path as a regex (use `grep -qxF` with the full line); the --print-path-only case discards stderr and so does not check the warning reached it (fix now) — `.agent/scripts/tests/test_worktree_create.sh`
- [x] (suggestion, Local Review @ 47666fb) An issue title containing `**Authored-By**:` lands in the hint's --body, so gh_create_pr.sh treats it as signed and the pasted PR goes unsigned (deferred: rightly left; the cause is `gh_body_is_signed` in `_gh_create_args.sh:310`, which treats the marker anywhere in any body as a signature, for every caller; a fix in the hint alone would paper over it. Belongs with the gh_create_pr.sh issue the host is proposing to the owner)
- [x] (suggestion, Local Review @ f5c68a46, codex) gh_create_pr.sh's user-tier guard (`registry_require_root`, `.agent/scripts/gh_create_pr.sh:87`) refuses a worktree folder outside both the project root and the workspace, so the pasted line is refused there (deferred: host checkpoint 2026-11-19 13:10; older behaviour of another script, unchanged here and disclosed in the PR body; rightly left for its own issue)

### False positives
- (none)

## Checkpoint
**Status**: complete
**When**: 2026-11-19 13:39 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the triage left four findings open, all small and valid; a review with open findings is sent back for fixes)
**After**: findings
**Decision**: address

The four open findings are fixed as the Integrated Review says: the guide sentence; a relative --plan-file made absolute against the caller's directory when the argument is parsed; no dangling "said:" when git wrote nothing; the three test points. The pull request body's sentence that the plan comment line is printed "when a plan file was given" is corrected by the host to "when the plan file was found".
