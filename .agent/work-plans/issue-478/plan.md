# Plan: merge_pr.sh refuses skill-branch pull requests; they are merged by hand

## Issue

https://github.com/rolker/agent_workspace/issues/478

## Context

`merge_pr.sh` takes `ISSUE_NUM` from the branch (line 450) and exits for `skill/<name>-<timestamp>`.
`ISSUE_NUM` then feeds the roadmap step (~600-650), the gate (~826-1250: `progress.md` path,
`issue_checkout_guard`, record append) and cleanup (~2261, `worktree_remove.sh --issue`). Skill PRs
(`research`, `inspiration-tracker`, workspace; `onboard-project`, project repo) are merged by hand today.

Decided (owner, 2026-11-15, Checkpoint in progress.md): G1 Report-only. A skill PR is gated like a
project PR: CI still awaited; a missing review is printed and recorded as a PR comment; the merge goes
ahead. Host decisions (owner may veto): the worktree is found by the PR's head branch, not
`worktree_remove.sh --skill` (#374 stays separate); the roadmap step is a stated no-op.

## Approach

1. **Classify the branch** — replace the exit at line 450-455 with a branch classifier: `feature/...issue-N`
   sets `ISSUE_NUM`; `skill/<name>-<YYYYMMDD-HHMMSS>...` sets `SKILL_PR=true`, `SKILL_NAME`, `ISSUE_NUM=""`;
   anything else keeps the error (text no longer says skill branches are unsupported). The banner prints
   "skill <name>" instead of "issue #".
2. **Roadmap (Step 1)** — for `SKILL_PR`, print "Skill PR — no issue to mark done, skipping roadmap update" (stated no-op).
3. **Gate (Step 1.5)** — for `SKILL_PR`, force report-only for this PR (same as project PRs), skip the
   `progress.md` timeline lookup, and use the reason "skill pull request: no issue timeline". Condition (a)
   (review entry) is read only from `progress.md` (`progress_read.py "$_gate_progress"`, ~920-934), so for a
   skill PR it is always unmet; **no PR-comment review reader is built** (new machinery the owner did not
   choose). Only (b) (a `## Decision summary` on the PR body/comments) is actually checked. Every skill PR
   merge therefore prints the gap and records a `## Merge (report-only)` comment on the PR, and the merge goes
   ahead. The skill worktree is open, so `_gate_wt` (`find_worktree_for_branch`, ~742) resolves and
   `_gate_record` (~1145-1255) would take its timeline branch and call `progress_append.sh ... "$ISSUE_NUM"`
   with an empty issue. Keep `_gate_wt` (it feeds `_ci_wt`, ~870-881, the local-history CI check): for `SKILL_PR`
   skip only the timeline read and send `_gate_record` to the PR-comment path with its own `why_comment`; no commit
   or push on the skill branch. `_gate_already_recorded` reads PR comments
   only. `--force-unreviewed` keeps its meaning. Guard every `ISSUE_NUM`-derived path (~826-1250) so none runs
   with it empty.
4. **Cleanup (Step 4)** — for `SKILL_PR`, resolve the worktree with `find_worktree_for_branch` (workspace
   root, or the project root for a project PR, as at line 608), `cd "$ROOT_DIR"`, and remove that path
   (add a `--path <worktree>` selector to `worktree_remove.sh`, reusing its uncommitted-changes check, or
   `git worktree remove` if the script cannot take a path; decide when reading the script, keep the check).
   No worktree found: say so and go on to branch deletion. Steps 5-6 (delete branches, sync main, sync project) unchanged.
4b. **Remote-branch delete (Step 5, ~2283, affects every PR)** — replace `git push origin --delete ... || true`
   with a delete through the PR's own repository: `gh api -X DELETE repos/$PR_REPO_SLUG/git/refs/heads/$PR_BRANCH`;
   "already gone" (HTTP 404/422 "Reference does not exist", e.g. GitHub auto-delete on merge) counts as success.
   Any other failure prints a warning naming the branch left behind and sets `_CLEANUP_INCOMPLETE=true` (final
   banner at ~2299 already reports it). No more silent `|| true`.
5. **Header and usage** — drop "Skill worktree branches are not supported" and the "issue-based only" limitation;
   document the skill path and the report-only treatment.
6. **Design** — `docs/design.md#merge-gate`: add the skill-PR bullet (report-only like project PRs, condition (a)
   always unmet, record on the PR, roadmap no-op, worktree resolved by branch); update the Rules row 164 text and
   refresh **every** `merge_pr.sh` line citation (grep the file: row 447, line ~632 "719-864, 1145-1320", Records
   bullet, mechanism 1, others, as #379 did), the Worktrees section if the removal selector changed, and the change log
   (ADR-0017). `.agent/knowledge/script_reference.md` for the new `worktree_remove.sh` option, if added.
7. **Skills** — the merge is `merge_pr.sh` (owner's "merge it"; never `gh pr merge --delete-branch` from a worktree),
   which removes the worktree and branches; the worktree stays until then so review fixes can land and the script finds it.
   - `research/SKILL.md`: replace step 8 "Clean up the worktree when done" (line 110) and the "and clean up" tails
     of lines 119 and 135 with "merged, and the worktree cleaned up, by `.agent/scripts/merge_pr.sh --pr <N>`".
   - `inspiration-tracker/SKILL.md`: after the PR step (~299) add the same merge line; it has no early cleanup step (checked).
   - `onboard-project/SKILL.md` (runs in a project session; PR is in the project repo): after step 7's `gh pr create`
     add `"$WS_ROOT/.agent/scripts/merge_pr.sh" --pr <N> --project <settings-name>` (not `--repo`, which takes the
     package path). Non-`origin` push remote: `merge_pr.sh` fails early and loudly, not silently
     (no `origin` on the project checkout: exit at ~273-277; an `origin` that is not the PR's repository: no PR
     found, ~406). Say so in the skill text and in the usage text (the PR's repo must be reachable as `origin`).
   No `make generate-skills`: it only regenerates `/make_*` from Makefile targets; SKILL.md edits feed nothing generated.
8. **Tests** (`.agent/scripts/tests/`, sandbox + `gh` stub as in `test_merge_pr.sh`; extend that file or
   `test_merge_pr_gate.sh`; a new `test_*.sh` gets `chmod +x`):
   - workspace skill PR merges, worktree and branch removed, main synced, no `progress.md` touched, and no commit
     lands on the skill branch (its HEAD is unchanged by the gate record);
   - roadmap no-op line printed;
   - every skill PR merge (even with a decision summary, since (a) is always unmet) posts a `## Merge (report-only)`
     comment with reason "skill pull request: no issue timeline"; merge proceeds; a duplicate run records once;
   - project-repo skill PR (`onboard-project`, `--type project`): merged, project worktree removed, project synced;
   - two worktrees of the same skill name: only the PR's branch worktree is removed, the other survives;
   - a non-issue, non-skill branch still errors; `--force-unreviewed` on a skill PR still records `Merge (unreviewed)`;
   - remote-branch delete: `gh` stub returning an error for the DELETE call prints the warning naming the branch,
     ends with the "cleanup incomplete" banner and still exits 0 after the merge; a stubbed "Reference does not
     exist" response counts as deleted with no warning; the call targets `repos/<PR slug>/git/refs/heads/<branch>`;
   - non-origin remote: sandbox with no `origin` (project PR) exits 1 with the "no 'origin' remote" error;
   - existing issue-branch cases unchanged (run all three `test_merge_pr*.sh`).
9. **Verify** — `make lint`, the three merge_pr test files, shellcheck on changed scripts.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Branch classifier, skill paths in roadmap, gate, cleanup; remote-branch delete via `gh api`; header/usage |
| `.agent/scripts/worktree_remove.sh` | Optional `--path` selector (step 4) |
| `.agent/scripts/tests/test_merge_pr*.sh` | Skill-branch cases listed in step 8 |
| `docs/design.md` | Merge gate, Rules row, `merge_pr.sh` row, change log |
| `.agent/knowledge/script_reference.md` | Only if options change |
| `.claude/skills/research/SKILL.md` | Replace the post-PR cleanup steps (110, 119, 135) with the merge |
| `.claude/skills/{inspiration-tracker,onboard-project}/SKILL.md` | Name the merge (onboard-project: `$WS_ROOT/...` with `--project`; non-origin remote note) |

## Prior Art

The project-PR report-only path and the no-worktree PR-comment record in `merge_pr.sh` are reused; no new
gate machinery. `find_worktree_for_branch` (already used at line 608) is reused for lookup. Rejected: calling
`worktree_remove.sh --skill` (newest-match, #374); a separate script for skill PRs.

## Serves

Easy to use, and Trust, control and information - `docs/design.md#merge-gate`

## Design Picture

Alters the merge gate: skill PRs get a report-only gate with the record on the PR. `docs/design.md#merge-gate`
(and the Rules row and `merge_pr.sh` row) change in this PR (ADR-0017).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Gate treatment written into `docs/design.md#merge-gate` in the same PR |
| Only what's needed | Reuses existing report-only and PR-comment paths; no new gate |
| Enforcement over documentation | Script path plus a test that fails if a skill branch is refused; skills only point to it |
| Put each thing at the level it applies to | Workspace script; project-repo skill PR covered by the project path |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0013 | Yes | Record is a `Merge (report-only)` PR comment; no timeline entry; duplicate check on comments |
| 0017 | Yes | Step 6 |
| 0002 | Yes | Only the branch's own worktree removed, from the root, never from inside it |
| 0004/0005 | Minor | Owner chose report-only; the choice is recorded in the design |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `merge_pr.sh` header/error text | Usage, `script_reference.md` | Yes |
| Gate treatment | `docs/design.md` Merge gate, Rules row 164, every `merge_pr.sh` line citation | Yes |
| Skill PR step text | Generated skill output | Not applicable (`generate-skills` only builds `/make_*`) |
| `worktree_remove.sh` option | its usage, tests, script_reference | Yes, if added |
| #374 (newest-match) | Separate issue; not fixed here | No, follow-up |

## Open Questions

- None blocking. Veto-able host decisions: branch-based worktree lookup (else fold #374 in); roadmap no-op.

## Estimated Scope

Single PR.
