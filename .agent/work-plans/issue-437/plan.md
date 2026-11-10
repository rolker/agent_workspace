# Plan: A records write from outside any issue worktree commits onto that checkout's main branch, silently

## Issue

Issue 437 in rolker/agent_workspace (workspace repo, `.agent/scripts/`).

## Context

`progress_append.sh` commits a timeline entry in whatever checkout `-C`/cwd names, and
`review_progress.sh persist` in compatibility mode (the default) prints "would have aborted" and
commits anyway. Run from a main checkout, both put a `progress:` commit on `main`, silently. Issue 429's
first pull request (branch `feature/issue-429`, not merged) already routes every records read and write
through one gate, `records_path` / `records_dir` in `.agent/scripts/_resolve_work_plans_dir.sh`, but the
gate is a no-op when no `.worktree-repos` manifest encloses the path, so it does not cover this.

This plan is written against that branch, NOT against this worktree's tree. Line ranges below are as
read on `feature/issue-429` at merge commit e8205e67 and are to be re-checked at implementation.

## Approach

1. **Wait for issue 429's first pull request to merge, then merge main into this branch.** Implementation
   does not start before. Re-read the functions and line ranges named below (all in
   `_resolve_work_plans_dir.sh`: `issue_checkout_guard` 134-165, `records_path` 167-185,
   `records_dir` 187-199, `resolve_work_plans_dir` 201-end; `progress_append.sh` 75-86;
   `review_progress.sh` `_persist_impl` 233-375 with the compatibility branch 306-330 and `cmd_check`
   592-650; `merge_pr.sh` 837-870; `tests/test_package_issue_loop.sh` case 8, 398-511) and adjust.
2. **The signal: the caller states its intent.** `records_path` and `records_dir` take an optional first
   option `--commit` ("this write will be committed in the target checkout"). Without it nothing
   changes: reads and the resolver's own callers (`dispatch_phase.sh`, `merge_pr.sh` lookup,
   `round`/`sources`/`findings`/`plan-sha`, `cross_model_review.sh`) behave as on the 429 branch. No
   inference from the caller's name, the command or the file. An option, not an environment variable,
   so a call site shows its intent and nothing leaks into child scripts.
3. **The second rule, inside `records_path`, after the existing manifest guard.** With `--commit`, judge
   the TARGET checkout `T` (the toplevel of the nearest existing ancestor of the path, which is the `-C`
   directory for `progress_append.sh`; never `$PWD`). Allow only when `T` is the issue's checkout:
   a. a manifest encloses `T`: the existing guard already decides (the entry on `feature/issue-N`;
      package checkouts are full clones, not linked worktrees, so no linked-worktree test applies there);
   b. otherwise `T` is a linked worktree (`git rev-parse --git-dir` differs from `--git-common-dir`),
      its branch is not the default branch (`origin/HEAD`, else `main`/`master`), and either the
      branch matches `feature/issue-N` (case-insensitive, optional `-description`) or the toplevel's
      basename is `issue-*-N`.
   Otherwise refuse (return 1, callers exit 4): a main checkout, a checkout on its default branch, a
   package checkout cloned under a project root outside any worktree, another issue's worktree, a
   `skill/*` worktree. The message names the issue's worktree when `git worktree list --porcelain` in
   `T`'s repository shows a worktree on `feature/issue-N`, else the command that creates it
   (`worktree_create.sh --issue N --type workspace|project`, or `--issue owner/repo#N` for a package
   issue) and states that reads are not refused.
4. **Call sites that state `--commit`:** `progress_append.sh` (`records_dir --commit`, replacing the
   plain call; exit 4 kept); `_persist_impl` compatibility branch (`records_dir --commit`, already
   exit 4); `_persist_impl` strict branch needs nothing new (it ends in `progress_append.sh`), but its
   `|| exit 3` on the append becomes "propagate exit 4" so the refusal keeps its code; `cmd_check`
   (`records_path --commit`, see settle point 3). `merge_pr.sh` keeps calling
   `progress_append.sh -C "$_gate_wt"`: the target is the PR worktree, which passes.
5. **Compatibility mode notice.** After the new refusal, the "would have aborted" notice can fire only
   when `resolve_work_plans_dir` refuses and the new rule does not, i.e. a set `$WORKTREE_ISSUE` that
   differs from the issue while cwd is the right worktree. Keep the notice for that one case; reword
   nothing else. Update the comment block above it.
6. **Fixtures.** Roughly ten suites use plain `git init` repos on `main`
   (`test_address_findings`, `test_issue_review_entry`, `test_plan_correlation`, `test_progress_append`,
   `test_review_code_convergence`, `test_triage_reviews_integration`, `test_dispatch_phase`,
   `test_merge_pr_gate`, `test_resolve_work_plans_dir`, `test_package_issue_loop`). Each that commits a
   timeline needs its fixture moved to a linked worktree on `feature/issue-N` (one shared helper in
   a tests include, not ten copies). Done as the first commit of the implementation, shown red against
   the rule, so a test that was passing only because it wrote on `main` is visible.
7. **New tests** (a new `tests/test_records_commit_gate.sh` in the style of case 8's enumeration, each
   asserting exit 4, the message naming the worktree or creating command, `git log` of every checkout
   unchanged and `git status` clean): (a) `progress_append.sh <N>` and `persist` (compatibility and
   `--strict`) from the workspace main checkout; (b) `-C <main checkout>` from inside the issue's
   worktree (cwd is right, target is wrong); (c) from a package checkout cloned under a project root
   outside any worktree; (d) from another issue's worktree; (e) a detached HEAD in a worktree named
   `issue-*-N` (allowed) and in a differently named one (refused); (f) a `skill/*` worktree with an
   issue number (refused) and `persist --issue ""` there (still a skip); (g) `review_progress.sh check`
   from main (refused, file unchanged); (h) must succeed: `progress_append.sh -C <the issue's
   worktree> N` run from the main checkout, as `merge_pr.sh` does, and `merge_pr.sh`'s gate record end to
   end through `test_merge_pr_gate.sh`; (i) reads from the root still succeed (`round`, `sources`,
   `plan-sha`, `dispatch_phase.sh next`); (j) a workspace issue and a project issue (single-repo project
   worktree), both directions. Add the `--commit` enumeration to case 8's class test so a new entry
   point cannot skip it.
8. **Loop still works end to end on a workspace issue:** `test_dispatch_phase.sh`,
   `test_review_code_convergence.sh`, `test_triage_reviews_integration.sh`, `test_address_findings.sh`,
   `test_plan_correlation.sh`, `test_issue_review_entry.sh`, `test_merge_pr_gate.sh`,
   `test_progress_append.sh` and `test_package_issue_loop.sh` all pass after step 6; run
   `make lint` and `make test`.
9. **Docs in the same pull request:** `docs/design.md` Records bullet (the records-gate sentence 429
   adds gets one more: a committing write is refused when its target is not the issue's worktree; reads
   are not), its change log row; `.agent/knowledge/script_reference.md` rows for
   `_resolve_work_plans_dir.sh`, `progress_append.sh`, `review_progress.sh` (exit 4); header exit-code
   comments in `progress_append.sh`, `review_progress.sh`, `_resolve_work_plans_dir.sh`; the
   `docs/design.md` B2 line (settle point 4); `run-issue` wording that persistence "refuses outside the
   worktree" needs no change, it becomes true for every mode.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_resolve_work_plans_dir.sh` | `--commit` option and the second rule in `records_path` / `records_dir`; header comment |
| `.agent/scripts/progress_append.sh` | `records_dir --commit`; header |
| `.agent/scripts/review_progress.sh` | `--commit` in persist compatibility and `check`; strict path keeps exit 4; notice narrowed |
| `.agent/scripts/tests/` | new `test_records_commit_gate.sh`; shared worktree fixture helper; fixture moves in the suites listed in step 6 |
| `docs/design.md`, `.agent/knowledge/script_reference.md` | Records bullet, change log, B2 line, script rows |

## Prior Art

Issue 429's gate (the one function, the manifest guard) is extended, not paralleled. `merge_pr.sh`
already skips a main tree for the gate record by comparing toplevels; the new rule is the same idea
moved into the gate so every writer gets it. Rejected: a git `pre-commit`/`reference-transaction` hook
(not present in every clone, and the scripts run `git commit` themselves); inferring intent from the
caller; refusing reads (the sit-rep and dispatcher read from the root on purpose).

## Serves

Leave a trail that is where the loop reads it (README workspace goals); `docs/design.md#rules` (start
limits strict) and the Records bullet of `docs/design.md#worktrees`.

## Design Picture

Extends the records-gate paragraph issue 429 adds to the Records bullet of `docs/design.md` by one
sentence; no new design question. No other section changes.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Leave a trail | A commit lands only on the issue's own branch; the refusal names the worktree |
| Only what is needed | One option and one rule in the existing function; no new script or mechanism |
| Test what you ship | Refusals assert nothing was committed anywhere; the legitimate `-C` writer is a test |
| Keep one current design | design.md, script reference and headers in the same pull request |
| Quality standard | Compatibility mode no longer commits after a notice; no half-fix left |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0013 progress.md entry types | Yes | Writers remain the only appenders; message and validation unchanged |
| 0012 package worktrees | Yes | Manifest case left to 429's guard; package clones are not required to be linked worktrees |
| 0016 user tier | Yes | `_resolve_work_plans_dir.sh` stays inert (functions only) |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `records_path` signature (optional leading option) | every caller of `records_path`/`records_dir`; none breaks without the option | Yes (steps 3-4) |
| Compatibility mode refuses | Test fixtures on plain `main` repos | Yes (step 6) |
| Notice semantics | B2 line in design.md | Yes (step 9) |
| `merge_pr.sh` gate record | Nothing; target is the PR worktree | Yes, tested (7h) |

## Open Questions

None for the owner on meaning. Mechanism details listed in progress.md for veto.

## Estimated Scope

Single pull request, after issue 429's first pull request merges.
