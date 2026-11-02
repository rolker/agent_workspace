# Plan: Small tooling fixes: skill worktrees branch from default, issue wrapper signs, merge-script CI-target wording

## Issue

https://github.com/rolker/agent_workspace/issues/323

## Context

Three independent script fixes, one PR, three atomic commits, each with a test that fails without its fix. Host decisions on the review's open recommendations are folded in: item 3 uses the single-rule variant, item 1 falls back to the local default with a warning, and the order is item 2, item 1, item 3. The review found that no `test_worktree_create*.sh` and no `gh_create_issue` suite exist; both are new. `test_gh_create_pr.sh` and `test_merge_pr_gate.sh` exist and are extended or mirrored.

## Approach

1. **Commit 1: `gh_create_issue.sh` signs like `gh_create_pr.sh`.** Mirror `gh_create_pr.sh`'s contract: parse `--no-signature` (stripped before `gh`), `--body`, `--body-file` and `--body-stdin` is not added (not in the issue). Reuse the same `SIG_MARKER` already-signed check and `SIG_BLOCK` format. Append when `AGENT_NAME` and `AGENT_MODEL` are set. When a body is given, identity is unset and `--no-signature` is absent, exit 2 with the pointer to `set_git_identity_env.sh`. No body flag (interactive) means no signing. Sign a `--body-file` through a temp copy created with a TMPDIR-honouring `mktemp` and the existing trap (merge with the parent-ref temp copy, which already rewrites `ORIGINAL_ARGS[BODY_FILE_ARG_INDEX]`; sign after parent-ref injection so the footer stays last). The signature step also runs before the `GITBUG_CREATE` branch so git-bug-created issues are signed (that branch reads `ORIGINAL_ARGS`). Update the header usage comment and the `AGENTS.md` script-table row.
2. **Test `tests/test_gh_create_issue.sh`** (new, `chmod +x`), modelled on `test_gh_create_pr.sh` (gh shim on PATH capturing argv and body-file, sandbox with a trap, `registry_require_root` satisfied the way `test_user_tier_guard.sh` / the PR suite do it). Cases: `--body` signed; `--body-file` signed and the caller's file untouched; already-signed body not double-signed; `--no-signature` unsigned; identity unset plus body exits 2 naming `set_git_identity_env.sh` with `gh` never called; no body flag passes through; `--no-signature` never reaches `gh`; parent-ref injection (WORKTREE_ISSUE) leaves the footer last. Verify it fails against the pre-fix script. Check that the runner (`run_script_tests.sh` / `suites_for_files.sh`) maps the new suite (the issue-first grep found `run_script_tests.sh` and `test_user_tier_guard.sh` already mention `gh_create_issue`).
3. **Commit 2: worktree base is `origin/<default>`.** In `worktree_create.sh` (workspace path, lines around 852) and in `_wt_add_repo` in `_worktree_helpers.sh` (project/package path, line ~501), replace the bare `git worktree add -b <branch> <dir>` (which starts at the invoking cwd's HEAD) with a start point from `resolve_default_branch` (`_resolve_default_branch.sh`), resolved per repo (`-C "$origin"` in the project loop, so the `.worktree-repos` manifest loop and ADR-0012 stay generic with no project-type checks). Sequence: `git fetch origin <default>` quietly; start at `origin/<default>` if present; if origin is unreachable or the ref is missing, start at the local default branch and print a warning to stderr; if neither resolves, fail with an error rather than silently using HEAD. The existing-branch and `origin/<branch>` tracking paths are unchanged, `--parent-issue` stays the only way to branch from a feature branch (the explicit parent path is unchanged), and the "Parent branch not found; falling back to HEAD" fallback also moves to the default start point with the same warning. A small shared helper (`_wt_default_start_point <repo>`) in `_worktree_helpers.sh` holds the logic so both paths use one rule. Note in `.agent/WORKTREE_GUIDE.md` that new worktrees start from the default branch regardless of cwd.
4. **Test `tests/test_worktree_create.sh`** (new, `chmod +x`): sandbox workspace repo with a bare origin and the script layout `worktree_create.sh` needs (follow how `test_register_project.sh` / `test_project_registry.sh` build sandboxes; the registry guard must pass). Cases: invoked from inside a feature worktree that is ahead of main, `--skill` and `--issue` branches have `merge-base` with main equal to main's tip and none of the feature commits; origin unreachable gives local-default start plus a stderr warning; `--parent-issue` still branches from the parent feature branch; no resolvable default fails rather than using HEAD. If the sandbox cost for `worktree_create.sh` proves high (it calls `gh`/git-bug), shim those as `test_worktree_enter_stderr.sh` does. Must fail against the pre-fix script.
5. **Commit 3: `merge_pr.sh` Step 2 uses the shared bookkeeping set.** In the Step 2 CI-target block, pass the bookkeeping patterns to `_only_bookkeeping_between` alongside the committed paths: `.agent/work-plans/*` plus `BOOKKEEPING_ROADMAP_PATHS`, the same set `MERGE_PR_CI_BOOKKEEPING_PATTERNS` holds. Move that array definition above Step 2 (it is currently defined at ~line 1098) or into `_bookkeeping.sh` next to `BOOKKEEPING_ROADMAP_PATHS` so there is one definition. Reword the success line to cover both causes ("only touches this script's own commits or bookkeeping paths"). The walk-back stays: it still serves the case where the reviewed head itself has no verdict. Check: the review's `_review_bookkeeping_between` already restricts to the one issue's work-plan dir while CI uses any issue's dir; keep the CI scope (any work-plan dir) as the existing comment says.
6. **Test in `test_merge_pr_gate.sh`**: add a fixture on the ci-30 shape (`make_walkback_sandbox`) asserting a host-pushed progress-only commit's output does not contain "is not a merge-time document file" and names the reviewed head as the CI target. Existing tests at the ci-30 sites (lines ~1031-1075, 1124-1146) assert the walk-back wording `CI target: <green> ... bookkeeping commits`; those change if `green` equals `HEAD_REVIEWED` (the fixture sets the PR head to the post-push head; whether `HEAD_REVIEWED` equals `green` depends on the review entry's recorded SHA and must be checked when implementing). Update their expectations to the new line, and keep a walk-back case where the reviewed head has no verdict so the walk-back stays covered. Also confirm ci-31/31b/31c (code or renamed or submodule changes) still refuse the exemption, now that more paths are allowed. Must fail against the pre-fix script (it prints the old line).
7. **Consequence sweep**: grep skills, scripts and docs for callers of `gh_create_issue.sh` that pass a body with no identity set (these now hard-fail), and for text quoting the old CI-target wording or the worktree base.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/gh_create_issue.sh` | Signature injection, `--no-signature`, hard-fail |
| `.agent/scripts/tests/test_gh_create_issue.sh` | New suite (exec bit) |
| `.agent/scripts/worktree_create.sh`, `.agent/scripts/_worktree_helpers.sh` | Default-branch start point with fallback warning |
| `.agent/scripts/tests/test_worktree_create.sh` | New suite (exec bit) |
| `.agent/scripts/merge_pr.sh`, `.agent/scripts/_bookkeeping.sh` | Step 2 allowed set includes bookkeeping patterns; one definition |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | New ci-30 output fixture; adjust walk-back wording expectations |
| `AGENTS.md`, `.agent/WORKTREE_GUIDE.md` | Script-table row for the issue wrapper; worktree base statement |

## Prior Art

`gh_create_pr.sh` for the signature contract (reuse, do not reinvent); `_resolve_default_branch.sh` for the default; `_bookkeeping.sh` / `MERGE_PR_CI_BOOKKEEPING_PATTERNS` for the shared path set; `test_gh_create_pr.sh` and `test_merge_pr_gate.sh` for test layout. Nothing new is being built. Considered and rejected: a duplicated pattern list in `merge_pr.sh` (two rules), and a reworded first line over the walk-back (host decision).

## Serves

Quality of the work and Trust, control and information; `docs/design.md#worktrees`, `docs/design.md#merge-gate`, `docs/design.md#identity`.

## Design Picture

No change to the design picture. Worktrees keeps its intent (item 1 makes it true); Merge gate's "one rule in `_bookkeeping.sh`" stays true and is strengthened.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Each commit carries a test verified to fail without the fix; two new suites because none exist |
| Small steps | Three separable commits in order 2, 1, 3 |
| A change includes its consequences | Step 7 sweep, docs rows, adjusted fixtures |
| Leave a trail | Unsigned issue hard-fails, as for PRs |
| Level of application | No project names; default branch resolved per repo |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0002 Worktree isolation | Yes | Item 1 keeps isolation, fixes the base |
| 0012 Worktree composition | Yes | Fix in the generic loop and helper, per-repo default, no type checks |
| 0013 progress.md | No | |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `gh_create_issue.sh` | AGENTS.md script row; callers passing a body without identity | Yes |
| worktree base | WORKTREE_GUIDE.md | Yes |
| CI-target wording | walk-back fixtures in `test_merge_pr_gate.sh` | Yes |
| New suites | runner mapping (`suites_for_files.sh`) so the pre-commit hook runs them | Yes, checked in step 2 |

## Open Questions

- None for the owner. Implementer to check whether `HEAD_REVIEWED` equals the walk-back's green head in the ci-30 fixtures (step 6); if the fold cannot keep the walk-back reachable, say so in the PR.

## Estimated Scope

Single PR, three commits.
