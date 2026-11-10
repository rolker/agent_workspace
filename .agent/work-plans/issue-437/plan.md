# Plan: A records write from outside any issue worktree commits onto that checkout's main branch, silently

## Issue

Issue 437 in rolker/agent_workspace (workspace repo, `.agent/scripts/`).

## Context

`progress_append.sh` commits a timeline entry in whatever checkout `-C`/cwd names, and
`review_progress.sh persist` in compatibility mode (the default) prints "would have aborted" and commits
anyway. Run from a main checkout, both put a `progress:` commit on `main`, silently. Issue 429's first
pull request (branch `feature/issue-429`, not merged) routes every records read and write through one
gate, `records_path` / `records_dir` in `.agent/scripts/_resolve_work_plans_dir.sh`; it is a no-op when
no `.worktree-repos` manifest encloses the path, so it does not cover this.

Written against that branch, not this worktree's tree. Line ranges are as read at `4fcb3fe2` and are to
be re-checked at implementation. Revision 2 follows the plan review (needs-work) and the host checkpoint.

## Approach

1. **Wait for issue 429's first pull request to merge, then merge main into this branch.**
   Implementation does not start before. Re-check, in `_resolve_work_plans_dir.sh`:
   `issue_checkout_guard` 169-, `records_path` 255-293, `records_dir` 294-306, `resolve_work_plans_dir`
   307-, rule 2b inside it; `progress_append.sh` 78-86; `review_progress.sh` `_persist_impl` 235-,
   compatibility branch 316-, commit at ~355, `cmd_check` 592-; `merge_pr.sh` ~837-870 (gate record,
   `progress_append.sh -C "$_gate_wt"`); the four skill passages in step 8.
2. **The signal: the caller states its intent.** `records_path` and `records_dir` take an optional first
   option `--write` ("this call changes the timeline; the target must be the issue's checkout").
   Without it nothing changes: reads and every other caller (`dispatch_phase.sh`, `merge_pr.sh`
   lookup, `round`/`sources`/`findings`/`plan-sha`, `cross_model_review.sh`, the resolver's own rules)
   behave as on the 429 branch. Opt-in, not default-refuse: defaulting would need about a dozen read
   call sites flagged and a missed one breaks the dispatcher and the sit-rep from the root.
3. **One helper, `_wpd_checkout_is_issue <dir> <N>`, in the same file.** It judges the checkout whose
   toplevel is `<dir>`: refuse when its branch is the default branch (`origin/HEAD`, else `main` or
   `master`); when its branch matches `feature/issue-M` (case-insensitive, optional `-description`) the
   BRANCH decides (`M` equals `N`; the folder is not consulted); only for a detached HEAD or a branch
   not of that shape does the folder decide (`issue-*-N`, exact trailing number). No linked-worktree
   condition. `resolve_work_plans_dir` rule 2b is rewritten to call the same helper (cwd as the
   directory), so the commit gate and the resolver cannot drift. Manifest case: the existing 429 guard
   still decides first; the owning checkout is on `feature/issue-N`, so no package carve-out is needed.
4. **The second rule, in `records_path`, after the manifest guard:** with `--write`, the target `T` is the
   git toplevel of the nearest existing ancestor of the path (the `-C` directory for
   `progress_append.sh`; never `$PWD`); refuse unless `_wpd_checkout_is_issue T N`. Refusal returns 1
   (callers exit 4) and names the issue's worktree (from `git worktree list --porcelain` in `T`'s
   repository, the entry on `feature/issue-N`) or the creating command
   (`worktree_create.sh --issue N --type workspace|project`; `--issue owner/repo#N` for a package issue),
   and says reads are not refused.
5. **Call sites that state `--write`:** `progress_append.sh` (`records_dir --write`); `_persist_impl`
   compatibility branch (`records_dir --write`, already exit 4); `cmd_check` (`records_path --write`: it
   changes the timeline without committing, no caller ticks from the root, and a tick left in a main
   checkout is a stranded dirty edit). Strict persist needs nothing new but propagates
   `progress_append.sh`'s exit 4 instead of turning it into 3. `merge_pr.sh` is unchanged: the target of
   its `-C` write is the PR worktree.
6. **Compatibility mode notice.** The new refusal precedes the "would have aborted" notice. The notice
   fires only when `resolve_work_plans_dir` refuses and the helper passes: `$WORKTREE_ISSUE` names
   another issue while the cwd is right, or `WORK_PLANS_DIR_OVERRIDE` is set. Keep it for those; update
   the comment block.
7. **Tests.** (a) New `tests/test_records_write_gate.sh`, in the style of case 8, each refusal asserting
   exit 4, the message, `git log` of every checkout unchanged and the files untouched: `progress_append.sh`
   and `persist` (compatibility and `--strict`) from the workspace main checkout; `-C <main>` from inside
   the issue's worktree; from a package checkout cloned under a project root outside any worktree; from
   another issue's worktree (7 from 17, 17 from 7, 1 from 17); a folder `issue-workspace-20` on branch
   `feature/issue-21` writing issue 20 (refused, branch decides); a detached HEAD in `issue-*-N`
   (allowed) and in another folder (refused); a custom branch in `issue-*-N` (allowed); a `skill/*`
   worktree with an issue number (refused); `check` from main (refused); a workspace issue and a
   single-repo project issue. Must succeed: `progress_append.sh -C <the issue's worktree> N` from the
   main checkout (the merge script's write), a sub-issue worktree for its own number, and reads from the
   root (`round`, `sources`, `plan-sha`, `dispatch_phase.sh next`). (b) A **static test** in the same file:
   every `git ... commit` in `.agent/scripts/*.sh` whose pathspec is under `.agent/work-plans/`
   (including through a variable such as `$file_rel`) must be in a script that calls `records_dir --write`
   or `records_path --write`; the set of such scripts must be exactly `progress_append.sh` and
   `review_progress.sh`, so a third committing writer without the flag fails the suite. (c) Existing
   suites: `test_progress_append.sh` gets a feature-branch fixture (`init -b feature/issue-7`) and its
   validation cases on issues 42 and 55 renumbered to the fixture's issue (the gate runs before entry
   validation); four assertions flip on purpose: the "persist compat in a mismatched worktree commits with
   a notice" case in `test_plan_correlation.sh`, `test_review_code_convergence.sh` and
   `test_triage_reviews_integration.sh` (now a refusal), and `test_package_issue_loop.sh`'s "check from
   WS ticks its own box" (now a refusal).
   Loop still works end to end on a workspace issue: `test_dispatch_phase.sh`, `test_merge_pr_gate.sh`,
   `test_resolve_work_plans_dir.sh`, `test_issue_review_entry.sh` pass unchanged; the suites in (c) pass
   after their edits; then `make lint` and `make test`.
8. **Docs and skill texts, same pull request.** `docs/design.md`: the records-gate sentence in the Records
   bullet gets one more sentence (a write that changes a timeline is refused unless its target is the
   issue's checkout; reads are not) and a change-log row. `.agent/knowledge/script_reference.md` rows
   for the resolver, `progress_append.sh`, `review_progress.sh`; exit-code header comments. The four
   skill passages that say compatibility mode commits after the notice: `plan-task` SKILL.md ~284-292,
   `review-code` ~725-736, `triage-reviews` ~372-381, `address-findings` ~202. Each now says: the same
   refusal as strict, except when `WORKTREE_ISSUE` names another issue or the override is set. A comment
   on issue 269's parked strict-mode item (not a design.md edit; no such line exists there).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_resolve_work_plans_dir.sh` | `--write` option, `_wpd_checkout_is_issue`, rule 2b uses it; header |
| `.agent/scripts/progress_append.sh` | `records_dir --write`; header |
| `.agent/scripts/review_progress.sh` | `--write` in persist compatibility and `check`; strict keeps exit 4; notice narrowed |
| `.agent/scripts/tests/test_records_write_gate.sh` | new: refusal cases, allowed cases, static test |
| `.agent/scripts/tests/test_progress_append.sh` + 4 flipped assertions | fixture and renumbering; flips named in step 7(c) |
| `.claude/skills/{plan-task,review-code,triage-reviews,address-findings}/SKILL.md` | compatibility-mode text |
| `docs/design.md`, `.agent/knowledge/script_reference.md` | Records sentence, change log, script rows |

## Prior Art

Issue 429's gate is extended, not paralleled. `merge_pr.sh` already skips a main tree for its gate record
by comparing toplevels; this moves the idea into the gate. Resolver rule 2b already matches branch and
folder; the helper unifies it. Rejected: a git hook (not in every clone; the scripts run `git commit`
themselves); inferring intent from the caller; refusing reads; the linked-worktree condition (review
ran both variants: it adds 43 failing assertions in six suites and disagrees with rule 2b).

## Serves

Goal: "Trust, control and information" (README, workspace goals); design: `docs/design.md#worktrees`
(the Records bullet) and `docs/design.md#rules`.

## Design Picture

Extends the Records bullet's records-gate paragraph (added by issue 429) by one sentence. No other
section changes.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Leave a trail | A timeline commit lands only in the issue's own checkout; refusal names the worktree |
| Only what is needed | One option, one helper, one rule in the existing function; no linked-worktree condition |
| Test what you ship | Refusals assert nothing was committed; the legitimate `-C` writer is a test |
| Enforce what matters | The static test fails when a committing writer omits `--write` |
| Keep one current design | design.md, script reference, headers and four skills in the same pull request |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0013 progress.md entry types | Yes | Writers unchanged; new writers go through `progress_append.sh`, which carries the flag |
| 0012 package worktrees | Yes | Manifest case left to 429's guard |
| 0016 user tier | Yes | `_resolve_work_plans_dir.sh` stays inert |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Compatibility mode refuses | Four skill texts; issue 269 parked item; tests with a mismatched worktree | Yes (steps 7, 8) |
| Rule 2b uses the helper | `test_resolve_work_plans_dir.sh` must stay green | Yes (7c) |
| `check` follows the write rule | `test_package_issue_loop.sh` assertion | Yes (7c) |

## Open Questions

None on meaning. For the owner's veto (what undoing costs):
- Compatibility mode becomes strict except when `WORKTREE_ISSUE` names another issue or the override is
  set. The "would have aborted" notices issue 269's parked B2 item waits for will therefore stop because
  those cases now refuse, not because runs got cleaner. Strict mode is NOT flipped here; B2 stays the
  owner's call. Undo: drop `--write` from the compat branch (one line).
- `--write` as an opt-in flag, enforced by the static test. Undo: rename, or flip the default (about a
  dozen call sites).
- `check` follows the write rule. Undo: one flag.
- Branch decides over folder when the branch names an issue. Undo: one condition in the helper.
- Separate convention question, not decided here: should a main checkout on a feature branch be refused?
  Today it passes (rule 2b already accepts it). Refusing needs a linked-worktree condition and would
  force the fixture moves the review measured.

## Estimated Scope

Single pull request, after issue 429's first pull request merges.
