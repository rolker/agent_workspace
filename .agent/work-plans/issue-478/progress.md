---
issue: 478
---

# Issue #478 — merge_pr.sh refuses skill-branch pull requests

## Issue Review
**Status**: complete
**When**: 2026-11-15 10:01 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #478

### Scope Assessment

**Well-scoped?** Yes, with one decision first. One script (`merge_pr.sh`), its header, tests and the three skills' text fit one PR. The gate question below must be settled before planning, since it decides the size of the change.
**Right repo?** Yes. Workspace repo: `merge_pr.sh`, skills and tests all live there. Skill PRs can target a project repo (`onboard-project` uses a project worktree), so the script's project-type path needs checking too.
**Serves**: Easy to use, and Trust, control and information (merge decided by the owner, a recorded gate) - `docs/design.md#merge-gate`
**Design picture?** Changes `docs/design.md#merge-gate`. The section describes the gate as reading an issue's `progress.md`; a skill PR has none, so the chosen gate treatment (no gate, record on the PR, or lighter) is a design statement and must go into that section in the same change (ADR-0017). The owner should decide it, not the plan.
**Dependencies**: #374 (`worktree_remove.sh --skill` removes the newest worktree on a name match) is open and is a hard prerequisite for the wanted behavior "remove the worktree that belongs to this branch". Either fix #374 first, or have `merge_pr.sh` resolve the worktree by branch itself and not call `--skill` by name. #476 is related, not blocking.

Verified in source: `merge_pr.sh` line 450 derives `ISSUE_NUM` from the branch and exits at 451-455; `ISSUE_NUM` is then used by the roadmap update (~600-650), the gate (~826-1250: `progress.md` path, `issue_checkout_guard`, record append), and cleanup (~2261 `worktree_remove.sh --issue`). So the change is a branch through all of these, not only the extraction. `worktree_remove.sh` has no branch selector, only `--skill <name>`. Existing tests: `test_merge_pr.sh`, `test_merge_pr_gate.sh`, `test_merge_pr_root_resolution.sh`.

Further instance: PR #482 (branch `skill/research-20261115-092631-794043070`, merged) was merged by hand the same four-step way on 2026-11-15, per the owner. That makes #475 and #482 two recent cases, besides #324, #368 and #397.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | The merge-gate section of `docs/design.md` describes an issue-bound gate. The gate treatment for skill PRs (open question in the issue) is an owner decision and must be recorded in `docs/design.md#merge-gate` in the same PR. |
| Only what's needed | Watch | Prefer the smallest gate that keeps the owner's decision: a skill PR has no issue, so any option beyond "no gate" or "record on the PR" (already built for the no-worktree case) adds new machinery. |
| Put each thing at the level it applies to | OK | Workspace script and skills; project-repo skill PRs (onboard-project) need to be handled by the project report-only path. |
| Enforcement over documentation | Watch | The skills' "say how it is merged" item is documentation; the script path is the enforcement. Add a test that fails when a skill branch is refused. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0013 progress.md entry vocabulary | Yes | A record for a skill PR cannot go in an issue timeline; if the PR-comment form is chosen, check the entry types and the duplicate check still apply. |
| 0017 design document is the current picture | Yes | Merge gate section update (see above). |
| 0002 worktree isolation | Yes | Cleanup must remove the worktree of this branch only, and must not run from inside it. |
| 0004 / 0005 enforcement hierarchy | Minor | Gate decision is an enforcement-level choice. |

### Consequences

- `merge_pr.sh` header comment ("Skill worktree branches are not supported") and the error text at line 455.
- `docs/design.md#merge-gate` and its change log; the Worktrees section if the removal selector changes.
- `research`, `inspiration-tracker` and `onboard-project` SKILL.md files (and `.agent/knowledge/script_reference.md` if the options change); regenerate skill output if the repo does so.
- Tests in `test_merge_pr*.sh` for the skill-branch path, including two skill worktrees of one name (#374 case).

### Recommendations

- Ask the owner to decide the gate for skill PRs before the plan is written: no gate, the gate with its record as a PR comment, or something lighter. The issue lists the options; the plan should not choose.
- Settle #374 first or in the same PR, so the worktree removed is the one of the PR's branch (resolve by branch, not newest-by-name).
- Make the roadmap step a no-op for skill PRs (no issue to mark done) and say so in the output, instead of skipping it silently.
- Test the project-repo skill PR case (`onboard-project`) and the two-same-name-worktrees case.
- Update the three skills' PR step to name `merge_pr.sh --pr <N>` as the merge path.

### Actions
- [ ] The merge-gate section of `docs/design.md` describes an issue-bound gate. The gate treatment for skill PRs (open question in the issue) is an owner decision and must be recorded in `docs/design.md#merge-gate` in the same PR.
- [ ] Ask the owner to decide the gate for skill PRs before the plan is written: no gate, the gate with its record as a PR comment, or something lighter. The issue lists the options; the plan should not choose.
- [ ] Settle #374 first or in the same PR, so the worktree removed is the one of the PR's branch (resolve by branch, not newest-by-name).
- [ ] Make the roadmap step a no-op for skill PRs (no issue to mark done) and say so in the output, instead of skipping it silently.
- [ ] Test the project-repo skill PR case (`onboard-project`) and the two-same-name-worktrees case.
- [ ] Update the three skills' PR step to name `merge_pr.sh --pr <N>` as the merge path.

## Checkpoint
**Status**: complete
**When**: 2026-11-15 10:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Owner's answer to "How should merge_pr.sh gate a skill-branch PR?": "G1 Report-only (Recommended)" — like project PRs: CI is still awaited; the missing review is printed and recorded as a comment on the PR; the merge goes ahead on the owner's "merge it". The Merge gate section of docs/design.md records this.

Host decisions for the plan (owner may veto):
- The worktree merge_pr.sh removes for a skill PR is found by the PR's head branch (the worktree that has that branch checked out), not through `worktree_remove.sh --skill <name>`'s newest-match rule, so #374 is not a prerequisite and stays its own issue. Undoing it: fold #374 into this PR instead.
- The roadmap update is a stated no-op for skill PRs (no issue number). Undoing it: none needed.
