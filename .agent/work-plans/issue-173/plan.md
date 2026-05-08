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
   Also covers legacy `.workspace-worktrees/` paths naturally: any
   directory `git` knows about as a worktree shows up here regardless
   of where it sits on disk, so the existing `WS_LEGACY` check at
   line 125 becomes unnecessary rather than dropped.

2. **Try both repos for the PR lookup, with collision-safe disambiguation.**
   Replace lines 105–110 with a query loop that calls
   `gh pr view -R <remote> --json state,headRefName,title` against
   *both* the workspace remote and the project remote (if
   `$ROOT_DIR/project` exists), filtering to `state == "OPEN"`. PR
   numbers are repo-local — workspace #84 ≠ project #84 — so "first
   match wins" would silently pick the wrong PR when both repos have
   an open PR with the same number. Behavior:
   - **0 open hits** → error "PR #<N> not open in either workspace or
     project."
   - **exactly 1 hit** → use that repo; this implicitly determines
     `WORKTREE_TYPE` (project if matched against project remote,
     workspace otherwise) when `--type` was not supplied.
   - **2 hits** → error with both titles and require `--type` to
     disambiguate. (Already-merged/closed PRs are filtered out, so
     stale numbers don't pollute the collision check.)
   When `--type` *is* supplied, skip the disambiguation: query only
   the matching repo and short-circuit on its result.

   **Edge cases the loop must surface explicitly (not silently skip):**
   - `$ROOT_DIR/project/.git` exists but `git -C project remote get-url origin`
     returns empty → error "Project repo has no `origin` remote
     configured; cannot resolve project PRs." (The current
     `resolve_gh_repo_args` silently produces no `-R` here, which is
     exactly how Bug 1 manifested — must not regress.)
   - `gh` returns a non-empty error other than not-found (typical:
     "HTTP 401: Bad credentials" when unauthed against one repo but
     authed against the other) → propagate the error from that repo
     verbatim, treat the lookup as inconclusive, and require `--type`
     rather than falling back to the working repo. Silently picking
     the only authed match would be the same class of bug we're fixing.

3. **Use the worktree-list helper everywhere a path is needed.** Lines
   157–161 currently rebuild paths by string concatenation for the
   roadmap-update step. Replace with the same git-worktree-list lookup
   so the path is whatever git actually has, not what the script
   assumes.

4. **Make `make merge-pr` forward extra args via `MERGE_PR_ARGS`.** Add a
   passthrough variable to the Makefile rule. Resolved in favor of
   `MERGE_PR_ARGS` over argument-style (`make merge-pr -- --type project`)
   for consistency with how every other Make passthrough in this workspace
   is exposed. Mostly defensive — once auto-detect works, `--type` should
   rarely be needed; but `--no-roadmap-update` and the both-worktrees-exist
   case still want an escape hatch.

   Literal Makefile edit (one line, line 122):

   ```diff
   -	@$(MAIN_ROOT)/.agent/scripts/merge_pr.sh --pr $(PR)
   +	@$(MAIN_ROOT)/.agent/scripts/merge_pr.sh --pr $(PR) $(MERGE_PR_ARGS)
   ```

   `$(MERGE_PR_ARGS)` defaults to empty (no `?=` initialization needed —
   undefined Make variables expand to nothing). Invocation example:
   `make merge-pr PR=84 MERGE_PR_ARGS="--type project"`.

5. **Smoke-test manually** — committed path. The workspace has no shell-test
   scaffold (no bats, no shunit2), and adding one for a one-off bug fix is
   exactly the kind of speculative tooling "Only what's needed" warns
   against. The PR description will document a deterministic reproduction:
   (a) confirm the original failure on `main` (`make merge-pr PR=<some
   project PR>` → silent exit 1), (b) confirm the fix on the branch (same
   command → succeeds, OR errors with a clear diagnostic when both repos
   have an open PR with the same number). If shell tests become useful
   beyond this fix, that's a separate follow-up issue, not in-scope here.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Replace `resolve_gh_repo_args` + lines 102–143 with: (a) repo-trying loop that determines target repo and `PR_BRANCH` together, (b) git-worktree-list-based worktree detection that also yields the path. Replace lines 156–162's path-building with the same helper. |
| `Makefile` | Add `$(MERGE_PR_ARGS)` passthrough on the `merge-pr:` rule (line 122) — see step 4 for the literal diff. |
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

None — `MERGE_PR_ARGS` resolved in step 4; testing approach committed in step 5.

## Estimated Scope

Single PR, single commit (or two: shell change + Makefile change). ~30–50
lines of script change, 2 lines of Makefile change. Manual smoke test
required since no automated test scaffold exists for `merge_pr.sh`.
