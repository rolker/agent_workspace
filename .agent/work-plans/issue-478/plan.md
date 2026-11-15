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
   `progress.md` timeline lookup, and add the reason "skill pull request: no issue timeline". Review and
   Decision-summary conditions are still evaluated against the PR (decision summary read from body/comments);
   the gap is printed and recorded through the existing no-worktree PR-comment path of `_gate_record`
   (as `## Merge (report-only)`), with the duplicate check (`_gate_already_recorded`) reading PR comments only.
   `--force-unreviewed` keeps its meaning. Guard every `ISSUE_NUM`-derived path (lines 826-1250) so none runs with it empty.
4. **Cleanup (Step 4)** — for `SKILL_PR`, resolve the worktree with `find_worktree_for_branch` (workspace
   root, or the project root for a project PR, as at line 608), `cd "$ROOT_DIR"`, and remove that path
   (add a `--path <worktree>` selector to `worktree_remove.sh`, reusing its uncommitted-changes check, or
   `git worktree remove` if the script cannot take a path; decide when reading the script, keep the check).
   No worktree found: say so and go on to branch deletion. Steps 5-6 (delete branches, sync main, sync project) unchanged.
5. **Header and usage** — drop "Skill worktree branches are not supported" and the "issue-based only" limitation;
   document the skill path and the report-only treatment.
6. **Design** — `docs/design.md#merge-gate`: add the skill-PR bullet (report-only like project PRs, record on
   the PR, roadmap no-op, worktree resolved by branch); update the Rules row 164 text, the `merge_pr.sh` row
   (line 447) and its line numbers, the Worktrees section if the removal selector changed, and the change log
   (ADR-0017). `.agent/knowledge/script_reference.md` for the new `worktree_remove.sh` option, if added.
7. **Skills** — `research`, `inspiration-tracker`, `onboard-project` SKILL.md: after "create PR", say the merge is
   `.agent/scripts/merge_pr.sh --pr <N>` (owner's "merge it"; never `gh pr merge --delete-branch` from a worktree).
   Run `make generate-skills` if these feed generated output.
8. **Tests** (`.agent/scripts/tests/`, sandbox + `gh` stub as in `test_merge_pr.sh`; extend that file or
   `test_merge_pr_gate.sh`; a new `test_*.sh` gets `chmod +x`):
   - workspace skill PR merges, worktree and branch removed, main synced, no `progress.md` touched;
   - roadmap no-op line printed;
   - missing review/decision summary: printed and recorded as a PR comment, merge proceeds; duplicate run records once;
   - project-repo skill PR (`onboard-project`, `--type project`): merged, project worktree removed, project synced;
   - two worktrees of the same skill name: only the PR's branch worktree is removed, the other survives;
   - a non-issue, non-skill branch still errors; `--force-unreviewed` on a skill PR still records `Merge (unreviewed)`;
   - existing issue-branch cases unchanged (run all three `test_merge_pr*.sh`).
9. **Verify** — `make lint`, the three merge_pr test files, shellcheck on changed scripts.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Branch classifier, skill paths in roadmap, gate, cleanup; header/usage |
| `.agent/scripts/worktree_remove.sh` | Optional `--path` selector (step 4) |
| `.agent/scripts/tests/test_merge_pr*.sh` | Skill-branch cases listed in step 8 |
| `docs/design.md` | Merge gate, Rules row, `merge_pr.sh` row, change log |
| `.agent/knowledge/script_reference.md` | Only if options change |
| `.claude/skills/{research,inspiration-tracker,onboard-project}/SKILL.md` | Name `merge_pr.sh --pr <N>` as the merge path |

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
| Gate treatment | `docs/design.md` Merge gate, Rules row 164, row 447 line numbers | Yes |
| Skill PR step text | Generated skill output (`make generate-skills`) if applicable | Yes |
| `worktree_remove.sh` option | its usage, tests, script_reference | Yes, if added |
| #374 (newest-match) | Separate issue; not fixed here | No, follow-up |

## Open Questions

- None blocking. Veto-able host decisions: branch-based worktree lookup (else fold #374 in); roadmap no-op.

## Estimated Scope

Single PR.
