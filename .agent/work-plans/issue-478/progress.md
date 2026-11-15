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

## Plan Authored
**Status**: complete
**When**: 2026-11-15 10:05 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-478/plan.md` at `536ca532`

Classify skill/<name>-<ts> branches in merge_pr.sh and gate them report-only (owner's G1) with the record on the PR; roadmap stated no-op; remove the worktree found by head branch; design, three skills and tests (incl. project-repo skill PR, two same-name worktrees) updated in one PR.

## Plan Review
**Status**: complete
**When**: 2026-11-15 10:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #478 — merge_pr.sh refuses skill-branch pull requests; they are merged by hand
**Plan**: `.agent/work-plans/issue-478/plan.md` at `536ca532`
**Branch**: `feature/issue-478`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One script, an optional `worktree_remove.sh` selector, tests, design and three skills: one PR. |
| Issue alignment | Good | All four "What is wanted" items and every review-issue recommendation are covered; the owner's G1 (Checkpoint 2026-11-15) is applied as decided and not reopened; #374 handled by branch lookup per the host decision. Serves, as checked: "Easy to use, and Trust, control and information - `docs/design.md#merge-gate`" (both goals exist in README Workspace goals; section exists). |
| File targeting | Needs work | Gate condition (a) and the `_gate_record` path need sharper statements (findings 1, 2); the `research` skill's own "clean up the worktree" step conflicts with merge-time cleanup (finding 3); the `onboard-project` merge command is wrong for a project session (finding 4). |
| Consequences | Needs work | `docs/design.md` cites `merge_pr.sh` line numbers outside row 447 (finding 5); `make generate-skills` is irrelevant (finding 6). |
| Principle alignment | Good | Reuses the report-only and PR-comment paths (Only what's needed); design updated in the same PR (Keep one current design); tests that fail on a refused skill branch (Test what breaks); prior art stated. |
| ADR compliance | Good | 0013 (PR-comment record, comment-only duplicate check), 0017 (step 6), 0002 (branch's own worktree, removed from root) addressed. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[File targeting]** (should-fix) — Step 3 says "Review and Decision-summary conditions are still evaluated against the PR". In source, condition (a) is read only from `progress.md` (`progress_read.py "$_gate_progress"`, merge_pr.sh ~920-934); nothing reads review entries from PR comments. For a skill PR (a) is therefore always unmet, and only (b) (Decision summary on the PR) is actually checked. State that, so the implementer does not build a new PR-comment review reader (new machinery the owner did not choose), and make the tests expect that every skill PR merge posts a `## Merge (report-only)` comment with the reason "skill pull request: no issue timeline".
2. **[File targeting]** (should-fix) — A skill PR's worktree is open, so `_gate_wt` resolves (`find_worktree_for_branch`, line 742) and `_gate_record` (1145-1255) would take its timeline branch and call `progress_append.sh ... "$ISSUE_NUM"` with an empty issue. "The existing no-worktree PR-comment path" is not reached on its own: the plan should say `_gate_record` is forced to the PR-comment path for `SKILL_PR` with its own `why_comment`, and a test should assert no commit lands on the skill branch.
3. **[File targeting]** (should-fix) — `.claude/skills/research/SKILL.md` lines 110, 119, 135 say "create PR, and clean up" / "Clean up the worktree when done" right after the PR is opened. With merge_pr.sh now removing the worktree at merge, step 7 must replace that cleanup step (leave the worktree until the merge, so review fixes can land and merge_pr.sh finds it), not only add a merge line after "create PR".
4. **[File targeting]** (should-fix) — Step 7 gives the merge as `.agent/scripts/merge_pr.sh --pr <N>` for all three skills. `onboard-project` runs in a project session (its SKILL.md uses `$WS_ROOT/.agent/scripts/...`), so the path must be `"$WS_ROOT/.agent/scripts/merge_pr.sh"`, and the PR is in the project repo: name `--project <settings-name>` (not `--repo`, which sends the PR down the package path and its "nothing local to clean up" branch at ~2246-2254). The skill also allows pushing to a remote not named `origin`; merge_pr.sh resolves and deletes branches through `origin` — say what happens then, or test/document it as a limitation.
5. **[Consequences]** (minor) — Step 6 refreshes only the `merge_pr.sh` row (447). `docs/design.md` also cites `merge_pr.sh` line ranges at line 632 ("719-864, 1145-1320") and elsewhere; refresh every `merge_pr.sh` line citation (grep the file), as #379 did.
6. **[Consequences]** (minor) — Step 7 and the Consequences row "Generated skill output (`make generate-skills`) if applicable": `generate-skills` runs `generate_make_skills.sh`, which only regenerates `/make_*` commands from Makefile `.PHONY` targets; SKILL.md text edits feed nothing generated. Drop the step and the row (state "not applicable").

### Summary

The approach is sound and follows the owner's G1 decision, reusing existing gate paths. Before implementing, tighten step 3 (what the gate actually checks for a skill PR and forcing the PR-comment record) and step 7 (research's early cleanup, onboard-project's command in a project session), and widen the design line-number refresh.

### Recommended Actions

- [ ] Step 3: state that condition (a) is always unmet for a skill PR (no PR-comment review reader is built); tests expect a `## Merge (report-only)` comment on every skill PR merge.
- [ ] Step 3: force `_gate_record` to the PR-comment path for `SKILL_PR` (the skill worktree is open); test that no commit is added to the skill branch.
- [ ] Step 7: replace the `research` skill's "clean up the worktree" steps (lines 110, 119, 135) with "merged and cleaned up by merge_pr.sh".
- [ ] Step 7: for `onboard-project`, use `"$WS_ROOT/.agent/scripts/merge_pr.sh" --pr <N> --project <settings-name>`; address the non-`origin` remote case.
- [ ] Step 6: refresh every `merge_pr.sh` line citation in `docs/design.md`, not only row 447.
- [ ] Drop `make generate-skills` from step 7 and the Consequences table.

## Checkpoint
**Status**: complete
**When**: 2026-11-15 10:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (Plan Review verdict needs-work: four should-fix and two minor findings, all plan amendments within the owner's G1 decision; none needs the owner)
**After**: plan
**Decision**: revise

Read the newest Plan Review (6c07c48c). Revise the plan for all six findings: condition (a) is always unmet for a skill PR (no new PR-comment review reader; expect a report-only record on every skill merge); force _gate_record onto the PR-comment path for skill PRs with a test that no commit lands on the skill branch; replace research SKILL.md's post-PR cleanup steps; onboard-project's merge call uses --project and the plan handles or documents a non-origin push remote; refresh every merge_pr.sh line citation in docs/design.md; drop the make generate-skills step.
