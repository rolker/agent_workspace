# Plan: merge_pr.sh review gate looks up a project PR's timeline at the legacy project/ path, not the registry root

## Issue

https://github.com/rolker/agent_workspace/issues/379

## Context

`merge_pr.sh` resolves the project's checkout root once, as `PJ_REPO_ROOT` (line 244, via
`wt_resolve_project_repo_root`: explicit `--project`, else legacy `project/`, else the single registered
project). Cleanup uses it (line 555: `${PJ_REPO_ROOT:-$ROOT_DIR/project}`) but the review gate does not:
line 670 hard-codes `$ROOT_DIR/project`. For a project registered anywhere else, `find_worktree_for_branch`
misses the PR's worktree, so `_gate_progress` is empty and the gate reports "no progress.md" even when a
covering review exists. The same wrong root drives the Step 1.5 record (`_gate_wt` feeds
`progress_append.sh -C` and the push, lines 801-843), so the `Merge (report-only)` record falls to the
PR-comment path instead of the timeline. The main-tree guard loops (lines 685 and 819) list
`$ROOT_DIR` and `$ROOT_DIR/project` only. Project PRs stay report-only (line 929): unchanged, a separate
choice. Owner approved all six actions at the checkpoint (19d9f14).

## Approach

1. **One shared root** — after the `PJ_REPO_ROOT` block (line ~270) set
   `PJ_ROOT_EFFECTIVE="${PJ_REPO_ROOT:-$ROOT_DIR/project}"` with a comment on why it is one variable. Use
   it at line 555 (cleanup) and line 670 (gate: `_gate_wt_repo="$PJ_ROOT_EFFECTIVE"`). Repoint the comment
   at ~250-251 ("default to $ROOT_DIR/project (line ~485)") at the new `PJ_ROOT_EFFECTIVE` line. (A1)
2. **Main-tree guards** — both loops, line 685 (`_ci_is_main`) and line 819 (Step 1.5), become
   `for _mt in "$ROOT_DIR" "$ROOT_DIR/project" "$PJ_ROOT_EFFECTIVE"`, so a registered project's main
   checkout never takes the feature commit. Update the line-815 comment ("legacy project/ checkout") to
   say the project's checkout root. (A2)
3. **Tests** — in `test_merge_pr_gate.sh`, after the project-scope case (~line 525), add a "registered
   project outside project/" group. Synthetic sandbox only (`make_sandbox`; no real hosted project).
   Register with the one-line pattern from `test_merge_pr.sh` (~694, ~718), no new helper:
   `echo "proj_x single_project $sb/projects/proj_x" >> "$sb/.agent/projects.local"`; no `$sb/project/`.
   Build the checkout with a bare `origin`, a `--type project` PR fixture keyed like the existing case,
   and a feature worktree (wherever `find_worktree_for_branch` reports it) holding
   `.agent/work-plans/issue-9/progress.md`. Three scenarios, run as `merge_pr.sh --pr 9 --type project`:
   - **(a) all good** — covering approved review at head plus a decision summary comment. Assert the
     "Review gate: approved review at head ... are present" line (~910), no "no progress.md" reason,
     `pr merge` called, and no `## Merge` record written (a passing gate records nothing).
   - **(b) a gap that is not about the timeline** — the same fixture with the decision summary removed
     (`$APPROVED_AT_HEAD` without a summary; a stale-head variant if cheap). Assert "would have refused"
     names the summary reason and not "no progress.md", `## Merge (report-only)` is committed in the
     registered worktree's `progress.md` and pushed to its bare origin, and no PR comment is posted.
   - **(c) guard** — scenario (b) with the PR branch checked out in the registered main checkout. Assert
     the reason "checked out in the main tree", the PR-comment fallback, and that the checkout's HEAD is
     unchanged. (Today's script also falls back to a comment here, with reason "no open worktree", so the
     reason text is what proves A2.) (A3)
4. **Why these fail today, and why the existing case cannot catch it** — on the current script the lookup
   runs in the missing `$sb/project`, finds no worktree, and reports "no progress.md": (a) loses its
   approved line, (b) posts a comment instead of committing the record, (c) shows reason "no open
   worktree". The case at ~525 builds a legacy `$sb/project` checkout, so `PJ_REPO_ROOT` equals
   `$ROOT_DIR/project` and the hard-coded and registry-aware roots coincide; it also gives the PR no
   timeline. Say this in a comment above the new group. Run the group before step 1 and confirm all three
   fail.
5. **Package path stays green** — the existing package-worktree case (~480) is untouched and must still
   pass: `PKG_WT_DIR` bypasses `_gate_wt_repo`, and `PJ_ROOT_EFFECTIVE` is not read on that path.
6. **docs/design.md, same PR (A4)** — Worktrees Records bullet (lines 334-343): drop "One gap shows" and
   the "tracked as #379" and "this paragraph is edited" sentences; say the gate and Step 1.5 look up the
   timeline at the registry-aware project root, with only the report-only status remaining. Target item 1
   (line 376) and item 2 (line 380): remove "first to be wrong" / "Finding the record at all is #379".
   Merge gate bullet (lines 501-502): remove the legacy-anchor sentence. Consequences row (line 266):
   drop the "anchored at `$ROOT_DIR/project` (tracked as #379)" clause. Line 636 ("A change that fixes
   #379 ... edits the sentence"): reword to Target only. Change-log row at the end of the table, dated the
   day of the change, section "Worktrees, Merge gate", issue `#379`, new line count from `wc -l`. Leave
   the history rows (648/650) alone.
   **Citation refresh, after the script edit is final:** `grep -n 'merge_pr.sh' docs/design.md` and
   re-read every `merge_pr.sh` line number from the edited file, not only the ones above: the Records
   bullet (801/843, 916/929), Target item 1 (373, "674-675, 829-837", already wrong), the row at 266
   ("379-418", "1612-1628", 555/670/685/819), and any others the grep finds. Inserting the variable shifts
   everything after line ~270.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | `PJ_ROOT_EFFECTIVE` variable; use at lines 555, 670, 685, 819; comments at ~250 and ~815 |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | new registered-project group (scenarios a, b, c); one-line registration, no helper |
| `docs/design.md` | lines 266, 334-343, 376, 380, 501-502, 636; every other `merge_pr.sh` line citation; change-log row |

## Prior Art

`worktree_remove.sh`/cleanup at line 555 already use the registry-aware root; this extends that
resolution to the gate rather than building a resolver. The Records Target (design.md Target 1) would
later replace all hard-coded lookups; it is deliberately not started here. Nothing new is built.

## Serves

Quality of the work (a merge gate whose review check sees the timeline) under `docs/design.md#merge-gate`,
with `docs/design.md#worktrees` (Records text cites this issue).

## Design Picture

No change to how the parts fit: the code is brought in line with the registry-aware root the design
describes. `docs/design.md#worktrees` (Records bullet, Target 1 and 2), `docs/design.md#merge-gate` and the
`merge_pr.sh` consequences row change in this PR, with a change-log row.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Design text naming #379 and its line numbers is edited in the same PR (ADR-0017) |
| Test what breaks | Three scenarios (pass, real gap, guard) on a root other than `project/`, each verified to fail before the fix and each asserting something the pre-fix script does not do; legacy-path case explained, package case kept |
| A change includes its consequences (the guard follows from A1: once the lookup returns the registered checkout, the old guard list would let it take the commit; the "fix it completely" bullet is AGENTS.md Quality Standard) | Main-tree guards and Step 1.5 record path fixed with the lookup; design rows refreshed |
| Only what's needed | One variable, not the Records Target resolver; report-only unchanged |
| Put each thing at the level it applies to | Reuses `PJ_REPO_ROOT`; no project names; sandbox is synthetic |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0011 | Yes | Uses the registry-resolved root |
| ADR-0013 | Yes | Gate reads and Step 1.5 writes `progress.md` in the right repo |
| ADR-0017 | Yes | design.md updated in the same change |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `merge_pr.sh` line numbers | every design.md `merge_pr.sh` citation (266, 334-343, 373, 376, others by grep) | Yes |
| Gate lookup | `merge_pr.sh` header comment ~627 (report-only wording) | Not needed; wording unchanged |
| Dispatch/review_progress paths | Records Target | No — C3, later |

## Revision 2

Change log: test split into pass/gap/guard scenarios (the single case could not pass after the fix); guard
assertion names its reason and checks HEAD; all design.md `merge_pr.sh` citations refreshed; one-line
registration instead of a helper; comment at ~250 repointed.

## Open Questions

None. Line numbers verified against the current files (555, 669-671, 685, 815-819, 929; design.md 266,
334-343, 376, 380, 501-502, 636).

## Estimated Scope

Single PR.
