# Plan: merge_pr.sh — project PRs fail silently when `--type` is omitted

## Issue

https://github.com/rolker/agent_workspace/issues/173

## Context

`make merge-pr PR=<N>` and `merge_pr.sh --pr <N>` (without `--type`) silently
exit 1 on every project PR. The issue body identifies two bugs in
`.agent/scripts/merge_pr.sh`:

1. **Auto-detect runs after the lookup that needs it.** Lines 105–110 call
   `gh pr view` against the workspace remote (because `WORKTREE_TYPE` is
   still empty, so `resolve_gh_repo_args` returns no `-R`). For project
   PRs this returns empty, the script bails with `ERROR: Could not fetch
   PR #<N>` and exits 1 — *before* line 121's auto-detect block ever
   runs.

2. **Path globs don't match the actual worktree layout.** Lines 122–123
   (and 157, 161 in the roadmap-update path) check
   `worktrees/project/issue-project-<N>`, but `worktree_create.sh:15`
   documents the layout as `worktrees/project/<repo>/issue-<slug>-<N>`
   (e.g. `worktrees/project/daddy_camp/issue-daddy_camp-66`). The
   project path will never resolve, so even if Bug 1 were fixed,
   auto-detect would still silently fall through to the "no worktree
   found" branch.

3. **Bonus:** `make merge-pr` doesn't forward extra args, so even
   knowing the workaround, you can't `make merge-pr PR=<N> --type project`.

## Approach

Fix both root causes; make `--type` optional in practice. Order matters:
Bug 1's fix needs the path glob from Bug 2 to be correct.

1. **Replace path-based auto-detect with `git worktree list` enumeration.**
   For each repo (workspace at `$ROOT_DIR`, project at `$ROOT_DIR/project`
   if present), parse `git worktree list --porcelain` and find the
   worktree whose `branch` line matches `refs/heads/feature/issue-<N>`.
   Sidesteps both the multi-project path layout *and* any future path
   convention drift — git is the authority on where worktrees live.

2. **Try both repos for the PR lookup.** Replace lines 105–110 with a
   loop that calls `gh pr view -R <remote>` against the workspace remote
   first, then the project remote (if `$ROOT_DIR/project` exists). Use
   the first repo that returns a non-empty `headRefName`; remember that
   repo so subsequent `gh pr merge` uses it. Bail with a clearer message
   if neither returns. This also implicitly determines
   `WORKTREE_TYPE` (project if matched against project remote, workspace
   otherwise) when `--type` was not supplied.

3. **Use the worktree-list helper everywhere a path is needed.** Lines
   157–161 currently rebuild paths by string concatenation for the
   roadmap-update step. Replace with the same git-worktree-list lookup
   so the path is whatever git actually has, not what the script
   assumes.

4. **Make `make merge-pr` forward extra args.** Add a `MERGE_PR_ARGS`
   passthrough variable to the Makefile rule. Mostly defensive — once
   auto-detect works, `--type` should rarely be needed; but
   `--no-roadmap-update` and the both-worktrees-exist case still want
   an escape hatch.

5. **Smoke-test manually.** Reproduce the original failure mode (would
   need a project PR), then verify the fix flows. Steps documented in
   the PR description so the reviewer can replay.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Replace `resolve_gh_repo_args` + lines 102–143 with: (a) repo-trying loop that determines target repo and `PR_BRANCH` together, (b) git-worktree-list-based worktree detection that also yields the path. Replace lines 156–162's path-building with the same helper. |
| `Makefile` | Add `MERGE_PR_ARGS` passthrough on the `merge-pr:` rule. |
| `.agent/work-plans/issue-173/progress.md` | Plan + implementation steps as work proceeds. |

No changes to AGENTS.md / docs needed: documented usage today is `make
merge-pr PR=<N>` with no type flag. The fix makes that command actually
work as documented.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Failure mode is silent and bites every project PR merge — exactly the kind of "concrete pain" justifying the fix. The bug was filed *because* I tripped over it during a real merge. |
| A change includes its consequences | The script's external interface stays the same (`--type` becomes optional but still respected); no caller changes are needed. AGENTS.md script-reference table already lists `merge_pr.sh`; no entry update required. |
| Only what's needed | Resist the urge to refactor the whole script. Fix only the two bugs and the Makefile passthrough; leave the rest of the merge → cleanup → sync flow untouched. |
| Capture decisions, not just implementations | The choice of `git worktree list --porcelain` over path globbing is the load-bearing design decision — note it in a code comment so the next agent who edits this script doesn't reintroduce path assumptions. |
| Improve incrementally | Single PR, small diff (~30–50 LOC of changes plus shell helper). |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0001 — ADRs | No | Bug fix; no new architectural decision worth recording. |
| 0007 — Retain Make with dependency tracking | Watch | Adding `MERGE_PR_ARGS` is a passthrough variable, not a new target or dependency edge. No stamp-file impact. |
| 0010 — git-bug optional | No | Script already sources `_issue_helpers.sh`; this fix doesn't touch the issue-lookup path. |
| Others (0002–0006, 0008–0009) | No | Worktree-isolation, AGENTS.md, enforcement layering, Python — none triggered. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `merge_pr.sh` interface (here: behavior, not signature) | Documentation that references it (`AGENTS.md` "Script Reference") | **No update needed** — the doc says "Merge PR (auto-updates roadmap), remove worktree, delete branch, sync main" without mentioning `--type`. The fix makes that line accurate. |
| Makefile rule | `AGENTS.md` Build & Test section if user-facing | **No update needed** — `MERGE_PR_ARGS` is a power-user escape hatch, not part of the documented happy path. |
| Auto-detection helper | Other scripts that detect worktrees by path | **None found** — `worktree_remove.sh` and `worktree_list.sh` use their own helpers; this fix only changes `merge_pr.sh`. |

## Open Questions

- **Forward args via `MERGE_PR_ARGS` or argument-style (`make merge-pr -- --type project`)?**
  The first is what every other Make passthrough convention does; the
  second is closer to bare-script invocation. Defaulting to
  `MERGE_PR_ARGS` for consistency with how Make is normally extended,
  unless you'd prefer the argument-style.

## Estimated Scope

Single PR, single commit (or two: shell change + Makefile change). ~30–50
lines of script change, 2 lines of Makefile change. Manual smoke test
required since no automated test scaffold exists for `merge_pr.sh`.
