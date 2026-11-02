# Plan: Small tooling fixes: skill worktrees branch from default, issue wrapper signs, merge-script CI-target wording

## Issue

https://github.com/rolker/agent_workspace/issues/323

## Context

Three independent script fixes, one PR, three atomic fix commits plus a fourth, docs-only commit for the `AGENTS.md` row; each fix has a test that fails without its fix. Host decisions on the review's open recommendations are folded in: item 3 uses the single-rule variant, item 1 falls back to the local default with a warning, and the order is item 2, item 1, item 3. The review found that no `test_worktree_create*.sh` and no `gh_create_issue` suite exist; both are new. `test_gh_create_pr.sh` and `test_merge_pr_gate.sh` exist and are extended or mirrored.

## Approach

1. **Commit 1: `gh_create_issue.sh` signs like `gh_create_pr.sh`.** Mirror the PR wrapper's contract exactly: `--no-signature` (stripped before `gh`), `--body`, `--body-file`, and the `--body=` / `--body-file=` forms normalised the same way, the same missing-value errors and the same body-source mutual-exclusion check (`--body-stdin` is not added). Short flags `-b` / `-F` are handled the same way as the long ones (cheap) rather than passing through unsigned. Reuse `SIG_MARKER` / `SIG_BLOCK`. Signing comes after `registry_require_root` (`test_user_tier_guard.sh` probes `--title t --body b` with `AGENT_MODEL` unset and expects "refusing to run"). Append when `AGENT_NAME` and `AGENT_MODEL` are set; with a body, identity unset and no `--no-signature`, exit 2 pointing to `set_git_identity_env.sh`. No body flag (interactive) means no signing. A `--body-file` is signed through a TMPDIR-honouring `mktemp` copy merged with the existing parent-ref temp copy (which already rewrites `ORIGINAL_ARGS[BODY_FILE_ARG_INDEX]`); sign after parent-ref injection so the footer stays last, and before the `GITBUG_CREATE` branch so git-bug issues are signed. **Drop the final `exec gh issue create`** (line ~314) and run `gh` as a normal child so the EXIT trap removes both temp copies, as `gh_create_pr.sh` did; keep the exit status. Update the header usage comment.
2. **Test `tests/test_gh_create_issue.sh`** (new, `chmod +x`), modelled on `test_gh_create_pr.sh` (gh shim on PATH capturing argv and body-file, sandbox with trap, root guard satisfied as in the PR suite). Cases: `--body` and `--body=` signed; `--body-file` and `--body-file=` signed with the caller's file untouched; `-b` / `-F` signed; already-signed body not double-signed; `--no-signature` unsigned and never reaching `gh`; identity unset plus body exits 2 naming `set_git_identity_env.sh`, `gh` never called (also for the `=` forms); missing-value and body plus body-file refused; no body flag passes through; parent-ref injection leaves the footer last; no temp file left behind (the runner's per-run TMPDIR leak check enforces it); the root-guard probe still refuses before signing. Verify it fails against the pre-fix script. Check `run_script_tests.sh` / `suites_for_files.sh` map the new suite.
3. **Docs in commit 1 (ADR-0017).** `docs/design.md`: the Rules row "A pull request carries the AI signature" (drop "Issues and comments are signed by habit only: `gh_create_issue.sh` does not add one"), the Identity bullet that names only `gh_create_pr.sh` as exiting 2 for an unsigned body, and a Change log row. The Rules row is retitled from "A pull request carries the AI signature" to cover pull requests and issues, since its text now names both wrappers. The `AGENTS.md` script-table row for `gh_create_issue.sh` is an instruction-file edit, approved by the owner on 2026-11-02 ("Yes"); it is its own **commit 4** (step 12), not folded in here.
4. **Commit 2: worktree base is `origin/<default>`.** A shared helper `_wt_default_start_point <repo>` in `_worktree_helpers.sh` holds one rule, used by `worktree_create.sh` (workspace path, ~line 852) and `_wt_add_repo` (project/package path, ~line 501; `-C "$origin"` per repo so the `.worktree-repos` loop and ADR-0012 stay generic). Rule: take the ref `resolve_default_branch` returns (a ref such as `main` or `origin/main`, not a name), strip a leading `origin/` before `git fetch origin <name>` (quiet); start at `origin/<name>` if present; if origin is unreachable or the ref missing, start at the local `<name>` with a stderr warning; if nothing resolves, fail with an error whose message includes the hint `git remote set-head origin -a` (never silently HEAD). Create with `git worktree add --no-track -b <branch> <dir> <start>` so the branch stays untracked until the first `push -u`, as today. Existing-branch and `origin/<branch>` tracking paths, and `--parent-issue` (the only way to branch from a feature branch), are unchanged; the "Parent branch not found; falling back to HEAD" fallback moves to the same start point with the warning. The helper sources `_resolve_default_branch.sh` at call time inside `_wt_default_start_point` (not when `_worktree_helpers.sh` is sourced), failing clearly if it is absent, so suites that only source the helpers file do not break.
5. **Existing suites item 1 would break (commit 2).** Chosen approach: copy `_resolve_default_branch.sh` into the hand-picked script copies of `test_project_registry.sh`, `test_precommit_hook_path.sh`, `test_ros2_colcon.sh`, `test_issue_review_entry.sh` and `test_dispatch_phase.sh` (the last two also copy `_worktree_helpers.sh`; call-time sourcing keeps them working unless they reach worktree creation, but the copy is cheap and makes the dependency explicit) (the helper is a real dependency now, so the sandbox must carry it; no weakening of the script). For `test_project_registry.sh`'s `make_git_repo` (and any sandbox where a worktree is expected to succeed, notably `test_worktree_create_skill_project`, which expects exit 0): create repos with `git init -b main`, or set `refs/remotes/origin/HEAD` / local default so `resolve_default_branch` succeeds even with the fake `file:///nonexistent/` origin (then the unreachable-origin path exercises the local-default fallback warning). The refusal stays for a real project on `master` without `origin/HEAD`, with the set-head hint. Run every `test_*.sh` suite (full run, not only the five named) before committing commit 2.
6. **Test `tests/test_worktree_create.sh`** (new, `chmod +x`): sandbox workspace repo with a bare origin and the layout `worktree_create.sh` needs (follow `test_register_project.sh` / `test_project_registry.sh`; shim `gh` / git-bug as `test_worktree_enter_stderr.sh` does if costly). Cases: invoked from inside a feature worktree ahead of main, `--skill` and `--issue` branches have merge-base equal to main's tip and none of the feature commits; the new branch has no upstream (`--no-track`); origin unreachable gives local-default start plus a stderr warning; `--parent-issue` still branches from the parent feature branch; no resolvable default fails (message has the set-head hint) rather than using HEAD; a project worktree resolves its own repo's default. Must fail against the pre-fix script.
7. **Commit 3: `merge_pr.sh` Step 2 uses the shared bookkeeping set.** In the Step 2 CI-target block pass the bookkeeping patterns to `_only_bookkeeping_between` alongside the committed paths: `.agent/work-plans/*` plus `BOOKKEEPING_ROADMAP_PATHS`, the set `MERGE_PR_CI_BOOKKEEPING_PATTERNS` holds. Move that array above Step 2 (or into `_bookkeeping.sh` next to `BOOKKEEPING_ROADMAP_PATHS`) so there is one definition. Reword the success line to cover both causes. The walk-back stays. CI scope remains any work-plan dir.
8. **Review-hold SHA (decision, revised).** The fold changes only the CI target and Step 2's allowed set. The "Copilot review still running" check (`_ci_review_sha`) is held on the head before this run's own pushes, i.e. the newest commit not made by this run (the host-pushed head), not on `HEAD_NOW`: in the stale shape `HEAD_NOW` is this run's own Step 1.5 record commit, so reading it would miss a review running on the host's commit (merged past today, reproduced by the reviewer) and a review re-triggered by this script's own push would deadlock the merge. Implement by capturing `origin/<branch>` before Step 1 / 1.5 push (or walking back from `HEAD_NOW` over single-parent commits whose paths are all in `_ci_committed_paths`). Update the merge_pr.sh comment at ~1199-1206 to say so. ci-32's rule is unchanged (there the reviewed head is the host-pushed head).
9. **Stale comments (commit 3).** Update the three `merge_pr.sh` comments that state Step 2's old rule: the header Steps item 2 ("only diff since then is paths this run committed itself"), the Step 2 comment ("Allowed set here is exactly what THIS run committed"), and the #300 block ("The Step 2 exemption above covers only paths THIS run committed").
10. **Tests in `test_merge_pr_gate.sh` (commit 3).** (a) New fixture in the stale-`headRefOid` shape that reproduces the PR 322 line against the unfixed script: gh's `headRefOid` lags (equals the green head) AND the host commit touches a path this run did not commit (a host `docs/roadmap.md` commit, as the reviewer reproduced). Against the unfixed script the output contains "touches docs/roadmap.md, which is not a merge-time document file" and the CI target is the new head; after the fix the target is the reviewed head and that text is absent. Both runs merge, so assert the printed CI-target line (matching the reworded success line from step 7, which names bookkeeping as well as this run's paths) and the first "Waiting for CI on" SHA, not the merge. Verify fail-before / pass-after by running it against the pre-fix script. A second variant uses another issue's work-plan dir. (b) Step 2-level negatives in the same stale shape: a code commit, code renamed into a work-plan dir, and a submodule bump each still target the new head. (c) A ci-32 analogue in the stale shape pinning item 8: the running Copilot check-run sits on the host's commit (not on `HEAD_NOW`); assert the merge waits. It merges past the review on the unfixed script and holds after the fix. The existing ci-30 (~1031-1075) and ci-31d (~1124-1146) expectations are unaffected (there `HEAD_REVIEWED` is the host-pushed head, so they still go through the walk-back) and are left as they are; ci-31/31b/31c are not claimed as proof for the fold.
11. **Consequence sweep**: grep skills, scripts and docs for callers of `gh_create_issue.sh` passing a body with no identity (now hard-fail), for text quoting the old CI-target wording, and for statements of the worktree base. `.agent/WORKTREE_GUIDE.md` states no base today (only the `--parent-issue` section, ~line 296, mentions branching), so its change is an added sentence stating the base (`origin/<default>`, local default with a warning when offline), not a correction; `docs/design.md#worktrees` likewise states none, so no design row changes for item 1.
12. **Commit 4: `AGENTS.md` script-table row for `gh_create_issue.sh`.** Owner-approved (2026-11-02) instruction-file edit, docs-only, after the three fixes: update the row to say it signs like `gh_create_pr.sh` (`--no-signature`, hard-fail without identity).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/gh_create_issue.sh` | Signature injection, `--no-signature`, `=` / short forms, hard-fail, no final `exec` |
| `.agent/scripts/tests/test_gh_create_issue.sh` | New suite (exec bit) |
| `docs/design.md` | Rules row (retitled to cover issues), Identity bullet, Change log row (ADR-0017) |
| `.agent/scripts/worktree_create.sh`, `.agent/scripts/_worktree_helpers.sh` | Default-branch start point (`--no-track`), fallback warning, set-head hint |
| `.agent/scripts/tests/test_worktree_create.sh` | New suite (exec bit) |
| `.agent/scripts/tests/test_project_registry.sh`, `test_precommit_hook_path.sh`, `test_ros2_colcon.sh`, `test_issue_review_entry.sh`, `test_dispatch_phase.sh` | Copy `_resolve_default_branch.sh` into sandboxes; `-b main` / origin HEAD where a worktree must succeed |
| `.agent/scripts/merge_pr.sh`, `.agent/scripts/_bookkeeping.sh` | Step 2 allowed set includes bookkeeping patterns; one definition; review-hold SHA = host-pushed head (before this run's pushes); three comments updated plus the ~1199 comment |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Stale-headRefOid fixture (asserts CI-target line and first waited SHA), Step 2 negatives, ci-32 analogue with the running review on the host commit |
| `.agent/WORKTREE_GUIDE.md` | Added sentence stating the worktree base |
| `AGENTS.md` (script-table row for `gh_create_issue.sh`) | Commit 4, owner-approved 2026-11-02 |

## Prior Art

`gh_create_pr.sh` for the signature contract (reuse, do not reinvent); `_resolve_default_branch.sh` for the default; `_bookkeeping.sh` / `MERGE_PR_CI_BOOKKEEPING_PATTERNS` for the shared path set; `test_gh_create_pr.sh` and `test_merge_pr_gate.sh` for test layout. Nothing new is being built. Considered and rejected: a duplicated pattern list in `merge_pr.sh` (two rules), and a reworded first line over the walk-back (host decision).

## Serves

Quality of the work and Trust, control and information; `docs/design.md#worktrees`, `docs/design.md#merge-gate`, `docs/design.md#identity`.

## Design Picture

Worktrees keeps its intent (item 1 makes it true); Merge gate's "one rule in `_bookkeeping.sh`" stays true and is strengthened. One exception: item 2 makes the `docs/design.md#rules` row on issue signing and the Identity bullet false, so both are updated, with a Change log row, in the same change.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Each commit carries a test verified to fail without the fix; two new suites because none exist |
| Small steps | Three separable fix commits in order 2, 1, 3, then a docs-only fourth |
| A change includes its consequences | Step 7 sweep, docs rows, adjusted fixtures |
| Leave a trail | Unsigned issue hard-fails, as for PRs |
| Level of application | No project names; default branch resolved per repo |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0002 Worktree isolation | Yes | Item 1 keeps isolation, fixes the base |
| 0012 Worktree composition | Yes | Fix in the generic loop and helper, per-repo default, no type checks |
| 0013 progress.md | No | |
| 0017 Design doc kept current | Yes | Item 2 changes the Rules row and Identity bullet; updated with a Change log row in commit 1 |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `gh_create_issue.sh` | `docs/design.md` Rules row, Identity bullet, Change log; callers passing a body without identity | Yes. AGENTS.md script row: commit 4 (owner-approved) |
| worktree base | WORKTREE_GUIDE.md; three suites with hand-picked script copies; registry sandboxes on `master` | Yes |
| CI-target / Step 2 rule | three stale comments in `merge_pr.sh`; new fixtures; review-hold SHA | Yes |
| New suites | runner mapping (`suites_for_files.sh`) so the pre-commit hook runs them | Yes, checked in step 2 |

## Open Questions

- None open.

## Estimated Scope

Single PR, four commits (three fixes, then the `AGENTS.md` row).
