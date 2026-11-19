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
- [x] (suggestion, Local Review @ 47666fb) The guide sentence says the script prints the command to post the plan, but it does so only when the plan file was found; say "and, if the plan file was found, post the plan" (false documentation, one-line fix; fix now) — `.agent/WORKTREE_GUIDE.md:394`
- [x] (suggestion, Local Review @ 47666fb) A relative --plan-file is resolved against the workspace root after the `cd "$ROOT_DIR"` (line 852), not the caller's cwd; a project session (start-task passes the user's path as typed) gets "Plan file not found", a PR titled [PLAN] with no plan comment. Make PLAN_FILE absolute against $PWD at parse time (the `--plan-file)` case near line 302) and drop the in-function absolutization; update the SB13/relative-plan tests to run from the directory the path is relative to (fix now) — `.agent/scripts/worktree_create.sh`
- [x] (suggestion, Local Review @ 47666fb) When git writes nothing to stderr the warning line ends in "said:" with nothing after it; print the "git push ... said:" phrase only when push_err is non-empty (fix now) — `.agent/scripts/worktree_create.sh`
- [x] (suggestion, Local Review @ 47666fb) Tests: the body-file check after the SB13 case reuses the previous check's fail message (wrong diagnostics on failure); the `grep -q "^pr comment ... $SB13/..."` treats the sandbox path as a regex (use `grep -qxF` with the full line); the --print-path-only case discards stderr and so does not check the warning reached it (fix now) — `.agent/scripts/tests/test_worktree_create.sh`
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

## Implementation
**Status**: complete
**When**: 2026-11-19 13:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent abcbbae1ea267062f, resume 1 of 3)

**PR**: #526 at `c4256be2`
**Addressed**: Integrated Review at `81edecc` (2026-11-19 13:39 -05:00)
**Commits**: 114b032d, e8d94d6b, 3ebf2d67, c4256be2

### Actions
- [x] Guide sentence: now "prints the commands to push the branch, open the draft PR and, if the plan file was found, post the plan by hand" — `.agent/WORKTREE_GUIDE.md:394` (c4256be2)
- [x] Relative --plan-file: made absolute against `$PWD` in the `--plan-file)` parse case, before any cd; the conversion where HAS_PLAN is set is removed. The usage text now says a relative path is relative to the directory the script is run from, and `start-task`'s SKILL.md (the `--plan-file` bullet) says the same, naming the session's directory in step 3; neither said anything before. New test: run from `$SB13/drafts` with `--plan-file "sub/plan 74.md"`; the plan is found, `pr create --draft --title [PLAN] Issue #74`, and the comment gets `$SB13/drafts/sub/plan 74.md`, readable. It fails without the fix ("Plan file not found", no comment). The SB13 and SB14 relative-plan cases already run from the directory their path is relative to (the workspace root); their comments are adjusted — `.agent/scripts/worktree_create.sh` parse loop, usage; `.claude/skills/start-task/SKILL.md` (114b032d)
- [x] No dangling "said:": the "git push -u origin <branch> said:" phrase and git's text print only when push_err is non-empty; otherwise "Push failed — skipping draft PR (non-fatal)." New test via the git double (`STUB_PUSH=silent-fail`, a push that fails with nothing on stderr); fails without the fix — `.agent/scripts/worktree_create.sh` create_draft_pr (e8d94d6b)
- [x] Test points: the body-file check has its own fail message printing the saved body; the SB13 comment check is `grep -qxF` on the full line; the --print-path-only case captures stderr to a file and checks the warning, push line and gh_create_pr.sh line reached it — `.agent/scripts/tests/test_worktree_create.sh` (3ebf2d67)

Departure: the new caller-directory test runs from a subdirectory of the workspace, not a folder outside it, because the user-tier guard refuses a cwd that is neither in the workspace nor under a registered project root (tried first: "refusing to run: ... is neither inside the workspace ...").

Suites run (each on its own with bash; the full pre-commit pass is left to the host):
- test_worktree_create.sh: PASS: 103 / FAIL: 0
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

## Local Review
**Status**: complete
**When**: 2026-11-19 13:56 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ab8fe1f4c5985ec5a, resume 2 of 3)

**PR**: #526 at `e1b99bf1`
**Depth**: Deep (reason: whole-PR diff over 200 lines with plan/progress; same specialists as Standard)
**Must-fix**: 1 | **Suggestions**: 4

Verified by hand at e1b99bf1:
- test_worktree_create.sh: 103 passed / 0 failed. test_skill_paths.sh: 163 passed / 0 failed. shellcheck --severity=warning: clean on both scripts.
- Relative --plan-file: sandboxes running origin/main (dd53c590) and HEAD side by side, with a registered single-repository project and a gh stub that records calls. On HEAD, each of these cases found its plan, and the comment read it:
  - from the workspace root (`plan-root.md`);
  - from a subdirectory (`sub/` with `plan-sub.md`);
  - from the project root (`--type project --project demo`, `plan-proj.md`);
  - through start-task step 3's own invocation shape (`set -f`, an unquoted `$ARGUMENTS` with `--print-path-only`) from the project root, which also printed the right WT.
- On main the same cases gave:
  - the workspace root: the plan comment missing (it ran inside the worktree);
  - the other three: "Plan file not found", with the PR still titled [PLAN].
- No caller in the repo depends on the old root-relative resolution. The --plan-file mentions in WORKTREE_GUIDE, WORKFORCE_PROTOCOL and docs/design.md use absolute example paths. The usage text and the start-task SKILL.md:230 sentence match the code, and start-task step 3 runs the script from the session's directory without a cd.
- CI at e1b99bf1: Validate Documentation, Validate Adapter Contract and repos-manifest tests (3.10, 3.14) pass in both runs; Lint (pre-commit) still pending in both. No GitHub reviews or comments.

Outside reviewers:
- Claude adversarial (fresh subagent): ran, no must-fix, 2 suggestions; the tracking-line one has substance.
- gemini: ran, EXIT=0, 6 suggestions.
  - Wrong: the pre-push hook stdout point (git runs hooks with stdout sent to stderr), and the cwd-after-return point (the caller runs `cd "$ROOT_DIR"`).
  - Trivial: whitespace-only stderr and the `//` path from `/`.
  - Repeated from earlier rounds: the test path quoting and the gh_create_pr.sh flags (already verified by paste trials).
- codex: ran, EXIT=0.
  - It repeated the deferred user-tier guard finding (not raised again).
  - It made a GH_REPO-override point. Not raised: the success path's `gh pr create` without --repo honours GH_REPO the same way, so the hint matches it.
  - Control characters in remote hook output: low; git already relays remote sideband output to the terminal on an ordinary push.
  - The plan-drift notes are folded into the last finding below.

### Findings
- [x] (must-fix) The PR body (its Decision summary) has sentences that are now false or stale; fixing it is a body edit, no code change: (deferred: no code change here: the host corrected the PR #526 body on the pull request (Left open list, the caller-relative path change, the success-path sentence, Reviews and outcomes with 103 passed))
  - "Left open, on purpose: Five suggestions from the last review..." lists the guide sentence, the relative --plan-file, the dangling "said:" and the test points as open, but all four are fixed at e1b99bf1. Only the `**Authored-By**:` title point (with the user-tier guard) is still open.
  - "Also fixed... The path is now made absolute once" leaves out that a relative path is now relative to the caller's directory. That is a behaviour change: a path relative to the workspace root, given from elsewhere, is no longer found.
  - "Unchanged: the success path... apart from the relative-path fix": the four sandbox cases predate the caller-relative change, and the push's stdout is now hidden too (next finding).
  - "Reviews and outcomes: ... Two pre-push code reviews ... test_worktree_create.sh: 101 passed" omits the integrated review, its fix round and this PR review, and the suite now passes 103.
  — PR #526 body
- [x] (suggestion) A successful push no longer shows git's stdout line "branch '<b>' set up to track 'origin/<b>'." The push used `2>/dev/null` before and now uses `2>&1 >/dev/null` on every path; reproduced by the adversarial reviewer. Harmless, but undisclosed: either say so, or drop only stderr on success (Claude adversarial) — `.agent/scripts/worktree_create.sh:1290`
- [x] (suggestion) The parse case uses `$PWD`; `CALLER_DIR` (line 40) holds the same value and exists for this purpose, which would keep "caller's directory" in one place (Claude adversarial) — `.agent/scripts/worktree_create.sh:307`
- [x] (suggestion) Remote hook output is relayed raw, so terminal control characters in it reach the screen; stripping them with `tr -d` or `cat -v` before indenting would keep the pasted lines legible (codex, low) — `.agent/scripts/worktree_create.sh:1296-1299`
- [x] (suggestion) The plan does not mention the caller-relative --plan-file change, the start-task SKILL.md edit, or the full Summary body in the hint; a line under the plan's Approach or the PR body's "what changes" would record the scope (codex) — `.agent/work-plans/issue-516/plan.md`

## Implementation
**Status**: complete
**When**: 2026-11-19 14:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent abcbbae1ea267062f, resume 2 of 3)

**PR**: #526 at `4414296c`
**Addressed**: Local Review at `e1b99bf1` (its entry committed as f2db50af)
**Commits**: 994e6b34, 1d7215c3, 637b477b, 4414296c

### Actions
- [x] (must-fix) PR body stale sentences — PR #526 body (deferred: no code change here; the host corrected the body on the pull request)
- [x] A successful push shows git's stdout again: the push runs as `{ push_err="$(git push ... 2>&1 >&4 4>&-)"; } 4>&1`, so stdout (the "branch ... set up to track ..." line) goes out as before and stderr is kept only for the failure warning. New test on the SB13 success case asserts the line; fails without the fix. Sandbox comparison with origin/main (dd53c590): a successful `--issue 77 --type workspace --plan-file <abs>` run printed the same lines on main and HEAD, the only differences being two commit hashes — `.agent/scripts/worktree_create.sh` create_draft_pr (1d7215c3)
- [x] The parse case uses `$CALLER_DIR` (set at line 40, before the argument loop, to the same `$PWD`). No test can fail without it, since both hold the same value at that point; the existing relative-plan tests still pass — `.agent/scripts/worktree_create.sh:307` (994e6b34)
- [x] Control characters other than tab and newline are dropped from git's error (`tr -d '\000-\010\013-\037\177'`) before it is indented. New test: a pre-receive hook printing `\033[31mred\033[0m alert\r`; the warning shows `remote: [31mred[0m alert` with no ESC or CR; fails without the fix — `.agent/scripts/worktree_create.sh` create_draft_pr (637b477b)
- [x] Plan section "Added after the plan was approved": the caller-relative `--plan-file`, the start-task SKILL.md and usage text, and the hint's body with the Summary heading, each with the review entry that asked for it — `.agent/work-plans/issue-516/plan.md` (4414296c)

Note for the PR body: its sentence that after a successful push git's "branch ... set up to track ..." line is no longer shown is now false (1d7215c3 restores it).

Suites run (each on its own with bash; the full pre-commit pass is left to the host):
- test_worktree_create.sh: PASS: 105 / FAIL: 0
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

## Local Review
**Status**: complete
**When**: 2026-11-19 14:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ab8fe1f4c5985ec5a, resume 3 of 3)

**PR**: #526 at `007b26db`
**Depth**: Deep (reason: whole-PR diff over 200 lines with plan/progress; same specialists as Standard)
**Must-fix**: 1 | **Suggestions**: 5

Checked by hand at 007b26db:
- Tests and lint:
  - test_worktree_create.sh: 105 passed / 0 failed.
  - test_skill_paths.sh: 163 passed / 0 failed.
  - shellcheck --severity=warning: clean on both scripts.
- Success path compared with origin/main (dd53c590) in sandboxes (a gh stub that records calls, absolute plan path). Three cases:
  - workspace worktree;
  - single-repository project worktree;
  - workspace worktree with --print-path-only.
- In all three:
  - the full output and the gh calls and body were identical to main's, apart from the init commit's short sha;
  - git's "set up to track" line shows as on main;
  - under --print-path-only it goes to stderr and stdout is the path alone.
- The tr filter keeps bytes >= 0x80 and tab, and drops ESC and CR. With GNU sed under a UTF-8 locale an invalid byte passes and sed exits 0.

PR body, sentence by sentence against the code:
- True: "What changes", "What it prints after a failed push", the relative-path behaviour change (resolved from CALLER_DIR; usage text and start-task:230 say so; no repo caller passed a root-relative path), "The success path", "Left open, on purpose" (the two deferred points) and "105 passed".
- False: "the plan was silently not posted even when the push worked". On main, a new draft PR's plan comment failure printed "⚠️  Failed to post plan comment (non-fatal)" (main worktree_create.sh:1340-1341). Only the existing-PR branch (main:1284-1285) was silent. The adversarial reviewer found this on its own.

CI at 007b26db: Validate Documentation, Validate Adapter Contract and repos-manifest tests (3.10, 3.14) pass in both runs; Lint (pre-commit) is pending in both. No GitHub reviews or comments.

Outside reviewers:
- Claude adversarial (fresh subagent): ran.
  - It found the same false sentence and 2 suggestions.
  - It checked the fd-4 push line: the exit status is git's, the stdout under --print-path-only goes to stderr, and fd 4 is closed for git.
  - It found the body bytes identical to main's.
- gemini: ran, EXIT=0, 6 suggestions. New with substance: the locale point (finding 2), the C1 note (folded into finding 3) and the test gap (finding 4). The rest repeat points already ruled on: whitespace-only stderr, [PLAN] with a missing plan file, the `//` path from `/`, and the gh_create_pr.sh -R check.
- codex: ran, EXIT=0, 2 points it called must-fix, neither held:
  - Head-only PR lookup for a stacked branch: the success path's own existing-PR check is `gh pr list --head` without a base too, so the hint matches it, and a brand-new branch already having a PR against another base is contrived.
  - Credentials in git's stderr under GIT_TRACE_CURL=1 with GIT_TRACE_REDACT=0: that needs the user to switch redaction off, and the script's fetch error already prints git's stderr. Without those settings git strips credentials (checked in the round 2 pre-push review).
  - Suggestions: xpg_echo undoing %q (off by default in a non-interactive bash; not raised); the plan-drift note (repeated; the plan now has its "Added after the plan was approved" section).

### Findings
- [x] (must-fix) PR body, "Also fixed..." paragraph: "the plan was silently not posted even when the push worked" is false for the usual case. On main a new draft PR got "⚠️  Failed to post plan comment (non-fatal)" (main:1340-1341), and only an already-existing PR got nothing (main:1284-1285). Suggested wording: "was not posted, with only a generic 'Failed to post plan comment' warning (none when the PR already existed)". Body edit only — PR #526 body (deferred: no code change here: the host corrected this sentence in the PR #526 body)
- [x] (suggestion) Under `set -e` the warning's display pipeline exits with sed's status. BSD sed under a UTF-8 locale can fail on invalid bytes from a remote hook and would then end the script. Not reproducible with GNU sed here. `LC_ALL=C` on tr and sed avoids it (gemini) — `.agent/scripts/worktree_create.sh:1302-1303`
- [x] (suggestion) Dropping ESC leaves the rest of a colour sequence (`[31m`) in the shown text, and UTF-8 C1 controls (U+009B CSI) pass through. Stripping whole `ESC[...letter` sequences first would read cleaner. Cosmetic (Claude adversarial, gemini) — `.agent/scripts/worktree_create.sh:1302`
- [x] (suggestion) No test checks that a successful push under --print-path-only keeps git's tracking line off stdout. The fd-4 redirection was checked by hand only (gemini) — `.agent/scripts/tests/test_worktree_create.sh`
- [x] (suggestion) PR body, "Reviews and outcomes": "four small suggestions, fixed with tests". The CALLER_DIR refactor and the plan note have no test of their own. "fixed (two with new tests)" would be exact — PR #526 body (deferred: no code change here: the host corrected this sentence in the PR #526 body)
- [x] (suggestion) This predates the PR and is out of scope: under --print-path-only, git push (and any ssh it starts) inherits fd 3, the caller's `$(...)` pipe. A lingering ssh ControlMaster could keep start-task's `WT=$(...)` waiting. `3>&-` on the push would close it (Claude adversarial) — `.agent/scripts/worktree_create.sh:168,1292`

## Implementation
**Status**: complete
**When**: 2026-11-19 14:20 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent abcbbae1ea267062f, resume 3 of 3)

**PR**: #526 at `76b2cf2f`
**Addressed**: Local Review at `007b26db` (its entry committed as bea0b66b)
**Commits**: 7059eb83, 76b2cf2f

### Actions
- [x] (must-fix) PR body "Also fixed..." sentence — PR #526 body (deferred: no code change here; the host corrected it on the pull request)
- [x] The warning's filter runs `sed` and `tr` under `LC_ALL=C`, and the pipeline ends in `|| true`, so it can never end the script under set -e. Test: a pre-receive hook prints an invalid byte (`\377`), and a sed double plays BSD sed on the indent filter (`STUB_SED=locale` fails on the byte unless LC_ALL=C; `STUB_SED=always` fails in any locale). Both cases exit 0 and print the hint, and the locale case shows the line. Dropping `LC_ALL=C` fails the locale case, and dropping `|| true` fails the always case (rc=1) — `.agent/scripts/worktree_create.sh` create_draft_pr (7059eb83)
- [x] Whole CSI sequences (`ESC [ params intermediates final`, e.g. colour codes) and the UTF-8 C1 controls (U+0080–U+009F) are removed. A carriage return becomes a line break, and the remaining control characters other than tab and newline are dropped. sed uses \001 as its delimiter, since the CSI ranges cover every printable character. The control-character test now expects `remote: red alert` with no `[31m`/`[0m`, ESC or CR; it fails without the fix — `.agent/scripts/worktree_create.sh` create_draft_pr (7059eb83, one commit with the item above because both change the same filter and the byte ranges need LC_ALL=C)
- [x] Test: a successful push under --print-path-only leaves stdout exactly the worktree path, and stderr has git's `branch 'feature/issue-75' set up to track 'origin/feature/issue-75'.` line — `.agent/scripts/tests/test_worktree_create.sh` (76b2cf2f)
- [x] (PR body) "four small suggestions, fixed with tests" — PR #526 body (deferred: no code change here; the host corrected it on the pull request)
- [x] Under --print-path-only the script opens fd 3 (`exec 3>&1` at line 168; the `exec 1>&2` after it only redirects fd 1). The push now closes fd 3 (`3>&-`), as well as fd 4, which it already closed. Test: a git double records `/proc/$$/fd` at the push. Without the fix it started with `0 1 2 255 3`; with the fix fd 3 is absent. The test skips where /proc is missing. Other git calls in the script (fetch, ls-remote) still inherit fd 3; they were not in the finding and are not changed — `.agent/scripts/worktree_create.sh` create_draft_pr (76b2cf2f)

Suites run (each on its own with bash; the full pre-commit pass is left to the host):
- test_worktree_create.sh: PASS: 109 / FAIL: 0
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

## Local Review
**Status**: complete
**When**: 2026-11-19 14:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #526 at `d72f2389`
**Depth**: Deep (reason: round 3 convergence check per handoff; scope is the round 2 findings and the fix diff bea0b66b..d72f2389)
**Must-fix**: 0 | **Suggestions**: 3

Checked by hand at d72f2389:
- test_worktree_create.sh: 109 passed / 0 failed. shellcheck --severity=warning (.venv): clean on worktree_create.sh and test_worktree_create.sh.
- Each new test bites. The suite against mutated copies: without `3>&-`, 1 FAIL (the push started with fds 0 1 2 255 3); with the bea0b66b script, 4 FAIL (fd 3, colour codes, both invalid-byte cases with rc=1); without LC_ALL=C on the last sed, 1 FAIL (the locale case).
- The filter by hand: `\e[1;31mred\e[0m` gives `red` with no `[31m`; an OSC title or hyperlink loses ESC and BEL but leaves `]0;title` text; a lone ESC at the end of a line is dropped; an unterminated `\e[12` leaves `[12`; é, ï, 日本語, ✓, U+00A0, Ă, ł and Â pass unchanged (only `\302` followed by 0x80-0x9f is removed, and `\302` is never a continuation byte); `\377` passes with no error; CR becomes a line break; tab is kept; a 200000-byte line passes whole.
- fd 3: closed only inside the push's command substitution. Without --print-path-only fd 3 is not open and `3>&-` is harmless; with it, the path still reaches stdout through `echo >&3` (line 1474), as the new test shows. The push's own output goes to fd 4 and its stderr to the captured text, neither touched. The script sets no pipefail, so `|| true` decides the pipeline's status.
- PR body, the three paragraphs: every clause holds against the code and progress.md, including the corrected plan-comment sentence ("only a generic 'Failed to post plan comment' warning (and none when the pull request already existed)") and the new sentence on the second PR review (one false sentence, five suggestions, the four in the code fixed with tests, 109 passed).
- CI at d72f2389: Validate Documentation passes in both runs and repos-manifest tests (3.14) in one; Lint (pre-commit), Validate Adapter Contract and the rest still pending at 14:23.

Outside reviewers:
- Claude adversarial (fresh subagent, same scope): no must-fix; reproduced the mutants independently; 2 suggestions (findings 1 and 2).
- Cross-model: skipped (round-3 convergence check, per handoff).

### Findings
- [ ] (suggestion) A CRLF line from a remote hook leaves an extra line holding only `remote:` (git turns the `\r` into a new `remote:` prefix and the filter makes it its own line); dropping a `\r` just before a newline would avoid it (Claude adversarial, reproduced with a pre-receive hook) — `.agent/scripts/worktree_create.sh:1315`
- [ ] (suggestion) PR body, "Reviews and outcomes": "whole escape sequences are removed" holds for CSI (colour) sequences only; an OSC sequence leaves `]0;title`. "whole colour (CSI) sequences" would be exact. The code comment already says CSI. Also "four small findings ... fixed with tests": the guide-sentence fix has no test, the same point the last review made about the next sentence — PR #526 body
- [ ] (suggestion) The comment line "pattern takes in. LC_ALL=C makes" is wrapped short — `.agent/scripts/worktree_create.sh:1308`

## Integrated Review
**Status**: complete
**When**: 2026-11-19 14:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a747933b6dc344bea, resume 1 of 3)

**PR**: #526 at `81c36f2` (code head `d72f2389`; 81c36f2 adds only this issue's progress.md)
**Sources**: 2 (Local Review @ `d72f2389`, round 3 convergence check; CI rollup). No GitHub reviews, inline or conversation comments; no Copilot review requested. The two earlier PR-mode Local Reviews (at `e1b99bf1`, `007b26db`) have every box closed by their Implementation entries; the two points in the body's "Left open, on purpose" were ruled on in the Integrated Review at `81edecc` and are judged again below.
**Cross-source confirmations**: 0
**CI**: pending

CI at d72f2389 (14:27): Validate Documentation, Validate Adapter Contract and repos-manifest tests (3.10, 3.14) pass in both runs. Lint (pre-commit) is in progress in both, started 19:21:13Z, about 6 minutes in. Slow, not stuck: on the two previous heads (007b26db, b16709b9) the same job took 9 to 14 minutes and passed.

PR body read again (`gh pr view 526 --json body`): it has the level-2 `## Decision summary` heading. The two clauses the round 3 review named are corrected: "whole colour (CSI) escape sequences are removed ..., while other sequences lose only their control bytes" matches the sed pattern at `worktree_create.sh:1314`, and "the code changes with tests (the fourth was one sentence of the guide)" matches the Implementation entry at c4256be2. The rest of the body agrees with progress.md (109 passed, the review rounds, the two left-open points).

This pull request has had three fix rounds on suggestions. None of the points below would harm or mislead a user, so none is sent back.

### Findings
- [x] (suggestion, Local Review @ d72f2389) A CRLF line from a remote hook leaves an extra line holding only `remote:` in the warning (deferred: rightly left; cosmetic only. git's error text is all still shown and the hint lines after it are unaffected; the extra line carries no false information and appears only when a remote hook writes CRLF)
- [x] (suggestion, Local Review @ d72f2389) PR body: "whole escape sequences are removed" held for CSI only, and "fixed with tests" missed that the guide-sentence fix has no test (addressed: the host corrected both clauses in the PR #526 body; checked above)
- [x] (suggestion, Local Review @ d72f2389) The comment line "pattern takes in. LC_ALL=C makes" is wrapped short (deferred: rightly left; layout of a comment, the text is correct and complete) — `.agent/scripts/worktree_create.sh:1308`
- [x] (suggestion, Local Review (Pre-Push) @ f5c68a46, codex) gh_create_pr.sh's user-tier guard (`registry_require_root`, `gh_create_pr.sh:87`) refuses the pasted line from a worktree folder outside both the project root and the workspace (deferred: rightly left; older behaviour of another script for any PR from such a worktree, the refusal is loud with its own message, and the PR body discloses it; host checkpoint 2026-11-19 13:10 proposes its own issue)
- [x] (suggestion, Local Review @ 47666fb, codex) An issue title containing `**Authored-By**:` makes the pasted `--body` look already signed, so that PR would get no signature (deferred: rightly left; the cause is `gh_body_is_signed` in `_gh_create_args.sh:310`, which reads the marker anywhere in any body for every caller, and the fix belongs there; the trigger needs an issue title quoting the marker; disclosed in the PR body and should go into the same gh_create_pr.sh issue)

### False positives
- (none)
