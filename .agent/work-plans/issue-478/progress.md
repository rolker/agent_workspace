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

## Plan Authored
**Status**: complete
**When**: 2026-11-15 10:08 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-478/plan.md` at `c1950481`

Revision after the Plan Review (6c07c48c): condition (a) is stated always unmet for a skill PR (no PR-comment review reader), _gate_record is forced onto the PR-comment path with a no-commit test, research's post-PR cleanup steps are replaced by the merge, onboard-project uses $WS_ROOT merge_pr.sh --project with the non-origin remote documented, every merge_pr.sh citation in docs/design.md is refreshed, and make generate-skills is dropped.

## Plan Review
**Status**: complete
**When**: 2026-11-15 10:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #478 — merge_pr.sh refuses skill-branch pull requests; they are merged by hand
**Plan**: `.agent/work-plans/issue-478/plan.md` at `c1950481`
**Branch**: `feature/issue-478`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR: script, optional `worktree_remove.sh` selector, tests, design, three skills. |
| Issue alignment | Good | Owner's G1 (Checkpoint 2026-11-15) applied, not reopened. All six findings of the first Plan Review (6c07c48c) are addressed: (1) step 3 states condition (a) is always unmet and no PR-comment review reader is built, tests expect a report-only record on every skill merge; (2) `_gate_record` forced onto the PR-comment path, test that the skill branch HEAD is unchanged; (3) research lines 110/119/135 replaced by the merge line; (4) onboard-project uses `"$WS_ROOT/.agent/scripts/merge_pr.sh" --pr <N> --project <settings-name>`; (5) every `merge_pr.sh` citation in `docs/design.md` refreshed; (6) `make generate-skills` dropped as not applicable. Serves, as checked: "Easy to use, and Trust, control and information - `docs/design.md#merge-gate`". |
| File targeting | Needs work | The non-`origin` remote handling describes behavior the script does not have (finding 1); forcing `_gate_wt` empty also blanks `_ci_wt` (finding 2). |
| Consequences | Good | Design section, Rules row, all line citations, script_reference (if options change), #374 left as follow-up. |
| Principle alignment | Needs work | Finding 1 documents a silent failure where the fix is a few lines (AGENTS.md Quality Standard; "Enforce what matters"). Otherwise reuses existing paths, design updated in the same PR, tests planned. |
| ADR compliance | Good | 0013, 0017, 0002 addressed; 0004/0005 by the owner's recorded choice. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[File targeting / Principle alignment]** (should-fix) — Step 7's non-`origin` statement ("the merge still succeeds but the remote branch is left") does not match the source. `merge_pr.sh` resolves a project PR only through the project root's `origin`: `PJ_REMOTE=$(git -C "$PJ_REPO_ROOT" remote get-url origin)` (line 273); with no `origin` it exits with "has no 'origin' remote configured" (274-277), and with an `origin` that is not the PR's GitHub repo `query_pr "$PJ_REMOTE"` (406) finds no open PR. So a project whose GitHub remote is not `origin` cannot reach the merge at all; it fails loudly and early, which is acceptable, but the skill and usage text must say that (merge such a PR by hand, or name `origin` to the GitHub remote), not the leftover-branch story. Separately, the `|| true` on the remote delete (line 2283) is a real silent failure for every PR, and the fix is within reach: delete through the PR's own repository, independent of remote names (`gh api -X DELETE "repos/$PR_REPO_SLUG/git/refs/heads/$PR_BRANCH"`, treating "reference does not exist" as already deleted), or at minimum replace `|| true` with a warning naming the branch left on the remote and set `_CLEANUP_INCOMPLETE`. Add a test: the remote delete fails and the output names the branch. Drop the "test if the sandbox can name the remote differently" hedge; instead test the no-`origin` refusal message for a project skill PR if the plan documents it.
2. **[File targeting]** (minor) — Step 3 says "force `_gate_wt` empty / force `_gate_record` onto the PR-comment path". `_gate_wt` also feeds `_ci_wt` (lines 870-881), the local fetch that sets the CI target and the review-fix exemption (1522-1523). Blanking it would push skill PRs onto the `gh` headRefOid fallback for no reason. Pick the second form: keep `_gate_wt`, skip the timeline read and force only `_gate_record`'s PR-comment branch for `SKILL_PR`.

### Summary

The revision addresses all six earlier findings and stays within the owner's G1. One should-fix remains: the non-`origin` remote case is described wrongly, and the silent `|| true` remote-branch delete should be replaced by a deletion through the PR's repository or a warning naming the branch, with a test. Ready once that and the minor `_gate_wt` wording are fixed.

### Recommended Actions

- [ ] Step 7 / usage: state that a project whose GitHub remote is not `origin` is refused by `merge_pr.sh` (line 273-277 / 406), and what the skill does then; drop the "merge succeeds, branch left" claim.
- [ ] Step 4/5: replace `|| true` on the remote-branch delete (line 2283) with deletion through `$PR_REPO_SLUG` via `gh api` (already-deleted treated as success), or at least a warning naming the branch and `_CLEANUP_INCOMPLETE=true`; add a test for the failure output.
- [ ] Step 3: keep `_gate_wt` (it feeds `_ci_wt`); for `SKILL_PR` skip only the timeline read and force `_gate_record` onto the PR-comment path.

## Checkpoint
**Status**: complete
**When**: 2026-11-15 10:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (second Plan Review, e7d1ffab: one should-fix and one minor, both within G1; second host revise in a row, so the next plan checkpoint is the owner's)
**After**: plan
**Decision**: revise

Revise for the second Plan Review's two findings: (1) correct the non-origin remote case (merge_pr.sh fails early and loudly: no origin exits at ~273-277; an origin that is not the PR's repo finds no PR at ~406) and say so in the skill and usage text; replace the silent `|| true` remote-branch delete (~2283) with a delete through the PR's own repo (`gh api -X DELETE repos/$PR_REPO_SLUG/git/refs/heads/$PR_BRANCH`, already-gone counts as success), and on failure a warning naming the branch plus _CLEANUP_INCOMPLETE, with a test; (2) keep _gate_wt (it feeds _ci_wt); for skill PRs skip only the timeline read and send _gate_record to the PR-comment path.

## Plan Authored
**Status**: complete
**When**: 2026-11-15 10:11 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-478/plan.md` at `5438f827`

Revision after plan review: non-origin remotes fail early (corrected description); remote-branch delete goes through the PR's repo via gh api with a warning and _CLEANUP_INCOMPLETE on failure, with tests; _gate_wt kept, skill PRs skip only the timeline read and record on the PR.

## Plan Review
**Status**: complete
**When**: 2026-11-15 10:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #478 — merge_pr.sh refuses skill-branch pull requests; they are merged by hand
**Plan**: `.agent/work-plans/issue-478/plan.md` at `5438f827`
**Branch**: `feature/issue-478`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one PR (script, optional `worktree_remove.sh` selector, tests, design, three skills). |
| Issue alignment | Good | Owner's G1 applied, not reopened. Both findings of the second Plan Review (e7d1ffab) addressed: (1) step 7 now states a non-`origin` remote fails early and loudly (no `origin`: exit ~273-277; wrong `origin`: no PR ~406), says so in skill and usage text, and tests the no-`origin` refusal; step 4b replaces the silent `|| true` remote delete (line 2283) with a delete through `$PR_REPO_SLUG`, already-gone counted as success, other failures warn by branch name and set `_CLEANUP_INCOMPLETE`, with tests; (2) step 3 keeps `_gate_wt` (feeds `_ci_wt`) and skips only the timeline read. Serves, as checked: "Easy to use, and Trust, control and information - `docs/design.md#merge-gate`". |
| File targeting | Good | Files match the steps; `PR_REPO_SLUG` is set before Step 5 (lines 349-436), and the final banner already reads `_CLEANUP_INCOMPLETE` with a `:-false` default (~2297). |
| Consequences | Good | Design section, Rules row, all line citations, script_reference (if options change), #374 left as follow-up. Step 4b changes behavior for every PR; the design change-log entry should name it (covered by step 6's change log). |
| Principle alignment | Good | One minor prior-art note (finding 1). |
| ADR compliance | Good | 0013, 0017, 0002 addressed; 0004/0005 by the owner's recorded choice. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment — prior art]** (minor, non-blocking) — `merge_pr.sh` already has a non-silent remote-branch delete in the package-PR path (lines ~2118-2133): `ls-remote --exit-code` rc 2 = "already gone", else `push origin --delete` with git's stderr and `_CLEANUP_INCOMPLETE=true`. Step 4b introduces a second mechanism (`gh api -X DELETE`) without citing it. Either reuse that pattern (factor a small helper used by both paths; the plan already establishes that `origin` must be the PR's repo, and a sandbox bare remote tests it without a new `gh` stub branch) or keep `gh api` and say why. Implementer's choice; just keep the two paths consistent and name the choice in the Prior Art section or PR description.

### Summary

Both earlier findings are resolved and the plan stays within G1. One minor prior-art note on the remote-branch delete; it does not block implementation. Ready.

### Recommended Actions

- [ ] Step 4b: reuse (or factor out) the package-path delete at ~2118-2133, or state why `gh api` is preferred; keep both paths' behavior consistent.

## Checkpoint
**Status**: complete
**When**: 2026-11-15 10:17 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Owner's answer to "Proceed to implementation?" after the third Plan Review (ready, 9c87f026): "Proceed (Recommended)". The review's one minor note goes to the implementer: the package-PR path already deletes the remote branch without hiding failures (~2118-2133); reuse it through a shared helper, or keep gh api and make the two paths behave the same.

## Implementation
**Status**: complete
**When**: 2026-11-15 10:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-478 at `df6f4895`

- `merge_pr.sh`: branch classifier accepts `skill/<name>-<YYYYMMDD>-<HHMMSS>[-<n>]` (`SKILL_PR`, banner "skill <name>"); any other non-issue branch is still refused, and a skill branch in a package repository is refused. Roadmap step prints "Skill PR — no issue to mark done". Gate: report-only for skill PRs in every mode, no timeline read (`_gate_wt` kept for `_ci_wt`), reason "skill pull request: no issue timeline", record always posted as a PR comment (nothing committed or pushed on the skill branch); duplicate check on PR comments; `--force-unreviewed` records `Merge (unreviewed)`. Step 4 removes the worktree git reports on the PR's head branch via `worktree_remove.sh --path`.
- Remote-branch delete (Plan Review 3's minor note): reused the package path's mechanism through a shared helper, `delete_remote_branch` (ls-remote rc 2 = already gone; else `push origin --delete`, failure prints git's stderr naming the branch and sets `_CLEANUP_INCOMPLETE`), used by both the package path and the workspace/project path, which had a silent `|| true`. The plan's `gh api` delete was not built: one mechanism, offline-testable, and `origin` is the PR's repository on every path.
- `worktree_remove.sh --path <worktree>`: linked single-repository worktree top folder only (main checkout, sub-folder refused); keeps the uncommitted-changes check.
- Tests: new `test_merge_pr_skill.sh` (68 checks: workspace and project skill PRs, report-only record and dedup, decision summary still unmet, force-unreviewed, two same-skill worktrees, no worktree, non-skill branches refused, refused remote delete -> "cleanup incomplete", already-gone issue branch, no-origin refusal, `--path` refusals); ROOT_READERS entry added in `test_script_tests_hook_scope.sh`.
- Docs: `docs/design.md` Merge gate (skill-PR and remote-delete bullets), Rules row, Table 1 rows, Records bullet, mechanism 1 and all `merge_pr.sh`/`worktree_remove.sh` citations refreshed, Worktrees note, change-log row; `script_reference.md` rows.
- Skills: research (early cleanup steps replaced), inspiration-tracker, onboard-project (`merge_pr.sh --pr <M> --project <settings-name>`, non-origin remote note) name the merge.
- Verification: `pre-commit run --files $(git diff --name-only main...HEAD)` passed with no SKIP; the script-test hook ran all 39 suites (mapper chose ALL), shellcheck and design-anchor checks passed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-15 10:57 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-478 at `396d4aad`
**Base**: main
**Depth**: Deep (reason: 972 changed lines, 11 files; skill and knowledge files)
**Must-fix**: 2 | **Suggestions**: 6
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) Skill PR with no worktree never runs `cd "$ROOT_DIR"`, so Step 6 `git pull --ff-only` pulls the caller's current checkout (or aborts under `set -e` with no upstream) and still prints "Workspace synced"; hoist the `cd` above the `_SK_WT` check and add a test run from another directory — `.agent/scripts/merge_pr.sh:2341-2352,2387`
- [x] (must-fix) Classifier accepts any `skill/<name>-<timestamp>`, so a workspace PR on a hand-named skill branch skips the enforced gate; accept only `worktree_create.sh`'s `ALLOWED_SKILLS` (one shared list), with a test — `.agent/scripts/merge_pr.sh:501`
- [x] (suggestion) Local branch delete still `branch -d ... 2>/dev/null || true`; next to the new "one rule" remote delete and the docs' "deletes its branches" claim, print git's stderr and set `_CLEANUP_INCOMPLETE` as the package path does — `.agent/scripts/merge_pr.sh:2379`
- [x] (suggestion) `worktree_remove.sh --path` accepts a package worktree's entry (contradicts the "single-repository only" doc claim) and does not check the path's repository against `--type`/`--project`; refuse an ancestor with `.worktree-repos` and compare the git common dir — `.agent/scripts/worktree_remove.sh:245-268`
- [x] (suggestion) Main checkout on the skill branch: `--path` correctly refuses, but merge_pr prints "check for uncommitted changes"; name the real reason or skip a main tree — `.agent/scripts/merge_pr.sh:2347-2350`
- [x] (suggestion) `delete_remote_branch`: use `refs/heads/$branch` in `ls-remote` (pattern tail-matches `x/$branch`), and treat a push failing with "remote ref does not exist" (auto-delete race) as gone — `.agent/scripts/merge_pr.sh:257-271`
- [x] (suggestion) Fork PR: `origin` delete can hit a same-named base-repo branch; pre-existing (old `push --delete || true` did the same), check `headRepositoryOwner` or open a follow-up — `.agent/scripts/merge_pr.sh:264`
- [x] (suggestion) Follow-up issue, not this PR: research's `gh pr create --fill` adds no AI signature, and inspiration-tracker's quoted heredoc posts literal `$AGENT_NAME`/`$AGENT_MODEL` (both pre-existing, untouched by this diff) — `.claude/skills/research/SKILL.md:109`, `.claude/skills/inspiration-tracker/SKILL.md:290-299` (deferred: proposed to the owner as a follow-up issue)

## Implementation
**Status**: complete
**When**: 2026-11-15 11:16 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-478 at `fbd10caf`
**Addressed**: Local Review (Pre-Push) at `396d4aad` (2026-11-15 10:57 -05:00)
**Commits**: e3479395, 6cb352f1, a716475b, 520b1371, 969b99e1, 13687f6c, fbd10caf

### Actions
- [x] (must-fix) `cd "$ROOT_DIR"` hoisted to the top of Step 4 on every path; test runs merge_pr.sh from another worktree with no upstream and checks the workspace root's main is fast-forwarded and the caller's checkout untouched (fails without the fix) — `.agent/scripts/merge_pr.sh` Step 4 (e3479395)
- [x] (must-fix) `ALLOWED_SKILLS`, `is_allowed_skill`, `skill_worktree_type` moved to `_worktree_helpers.sh` (one list for worktree_create.sh and merge_pr.sh); the classifier takes a skill branch only for an allowlisted name; test: `skill/handmade-...` and `skill/research-x-...` refused, nothing merged — `.agent/scripts/merge_pr.sh:501` (6cb352f1)
- [x] (suggestion) Step 5's local `branch -d` reports a kept branch with git's stderr and marks the cleanup incomplete (absent branch is a no-op); test with an unmerged local commit — `.agent/scripts/merge_pr.sh` Step 5 (a716475b)
- [x] (suggestion) `worktree_remove.sh --path` refuses a folder under a `.worktree-repos` manifest and a worktree whose git common dir is not the `--type`/`--project` repository; merge_pr.sh passes `--project`; tests for package entry and both type mismatches; script_reference.md and design.md updated — `.agent/scripts/worktree_remove.sh` (520b1371)
- [x] (suggestion) A main checkout on the skill branch is named as such (never removed, cleanup incomplete), and Step 6 skips the pull when the workspace checkout is on the merged branch (it had aborted under `set -e`); test — `.agent/scripts/merge_pr.sh` Step 4/6 (969b99e1)
- [x] (suggestion) `ls-remote ... refs/heads/<branch>` in delete_remote_branch and the package sibling cleanup; "remote ref does not exist" from push --delete counts as already gone; tests for a tail-matching `x/<branch>` and the race (both fail without the fix) — `.agent/scripts/merge_pr.sh:257-271` (13687f6c)
- [x] (suggestion) Fork PR: the PR lookup reads `isCrossRepository`; delete_remote_branch leaves origin alone with a message for a cross-repository PR; test; design.md bullet updated — `.agent/scripts/merge_pr.sh:264` (fbd10caf)
- [x] (suggestion) AI signature in research's `gh pr create --fill` and inspiration-tracker's quoted heredoc — `.claude/skills/research/SKILL.md:109`, `.claude/skills/inspiration-tracker/SKILL.md:290-299` (deferred: proposed to the owner as a follow-up issue)

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP on the final tree: all hooks passed, exit 0; `validate-script-tests` ran every suite (full run: a `.agent/scripts/_*.sh` helper, `_worktree_helpers.sh`, changed).
- `test_merge_pr_skill.sh` 112 passed, 0 failed; `test_worktree_create.sh` 79 passed, 0 failed (also run directly while fixing).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-15 11:21 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-478 at `5a1317c7`
**Base**: main
**Depth**: Deep (reason: 1376 changed lines, 13 files; skill, knowledge and design files; fix round keeps whole-diff tier)
**Must-fix**: 2 | **Suggestions**: 4
**Round**: 2 | **Ship**: recommended — round 2: 2 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

Round 1's seven addressed findings checked: all fixed as described (cd hoisted, shared allowlist, local delete reported, --path refusals, main-checkout named, exact ref + race, fork guard on origin). Finding 8 deferred by owner, not re-raised. Two regressions from the fix round below (1, 2).

### Findings
- [x] (must-fix) Step 5's local `git branch -d` (now reported, a716475b) runs before Step 6's pull: a merged branch with no upstream (worktree_create.sh makes it `--no-track`; a plain `git push origin <b>`) or a pruned tracking ref is checked against the unpulled local main, fails "not fully merged", and an ordinary merged PR ends "cleanup incomplete" with a "branch -D if abandoned" hint; the test hides it (`add_worktree` puts the branch at main). Delete after the sync (both workspace and project checkouts), add a test with a branch carrying its own commit and no upstream — `.agent/scripts/merge_pr.sh:2414-2457`, `.agent/scripts/tests/test_merge_pr_skill.sh:115`
- [x] (must-fix) `docs/design.md` merge_pr.sh line citations are stale after the fix round (e.g. PJ_ROOT_EFFECTIVE 344 cited 329; lookups 707/842 cited 676/811; main-tree guards 978/1291 cited 947/1260; project report-only 1583/1600 cited 1552/1569; cleanup ~2411-2457 cited 2371-2394; mechanism 1 and Records ranges likewise); refresh all — `docs/design.md:447,560-567`
- [x] (suggestion) Classifier checks only `is_allowed_skill`: also require `skill_worktree_type` to match the PR's repo type and refuse a cross-repository (fork) PR as a skill PR, so `skill/onboard-project-<ts>` on the workspace or a fork's `skill/research-<ts>` does not get the report-only gate — `.agent/scripts/merge_pr.sh:530`
- [x] (suggestion) Main-checkout detection compares two `rev-parse ... 2>/dev/null` outputs; a stale worktree whose folder is gone gives two empty strings and is misreported as "the main checkout"; require a non-empty git-dir first — `.agent/scripts/merge_pr.sh:2378`
- [x] (suggestion) Auto-delete race match `*"remote ref does not exist"*` depends on git's locale; run the push with `LC_ALL=C` or re-check `ls-remote` (rc 2 = gone) after a failed push — `.agent/scripts/merge_pr.sh:277`
- [x] (suggestion) Fork PR: origin delete is skipped, but Step 4/5 still remove a local worktree and `branch -d` a local branch that only shares the head's name; skip local cleanup when `PR_CROSS_REPO` is true — `.agent/scripts/merge_pr.sh:2375,2414`

## Implementation
**Status**: complete
**When**: 2026-11-15 11:37 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent ab4465ed7661b5e22, resume 1 of 3)

**Branch**: feature/issue-478 at `6676cd24`
**Addressed**: Local Review (Pre-Push) at `5a1317c7` (2026-11-15 11:21 -05:00)
**Commits**: 4fd1c142, e73e989b, c125e3fb, 0945c3e5, b9fe05fe, 6676cd24

### Actions
- [x] (must-fix) Local `branch -d` moved after Step 6's syncs (workspace and project); the remote delete stays in Step 5. Test: a branch with its own commit, pushed without upstream, merged on origin's main first; deleted, no warning, clean banner (3 failures without the fix) — `.agent/scripts/merge_pr.sh` Steps 5-6 (4fd1c142)
- [x] (must-fix) Every `merge_pr.sh` / `worktree_remove.sh` line citation in `docs/design.md` (Table 1 rows, Records bullet, project-timeline bullet, mechanism 1) refreshed last, each number checked against the line it names in the final file; change-log row extended — `docs/design.md:446-447,549-565,638` (6676cd24)
- [x] (suggestion) Classifier also requires `skill_worktree_type` to match the PR's repository type and refuses a cross-repository PR as a skill PR; tests for onboard-project on the workspace, research on the project, a fork skill PR (nothing merged); fork remote-delete test moved to an issue branch — `.agent/scripts/merge_pr.sh:530` (e73e989b)
- [x] (suggestion) Main-checkout check needs a non-empty git dir; a stale entry whose folder is gone is pruned with a note; test (4 failures without the fix) — `.agent/scripts/merge_pr.sh` Step 4 (c125e3fb)
- [x] (suggestion) Race detection re-asks `ls-remote` after a failed push (rc 2 = gone) instead of matching git's English message; test's push fails with a French message (3 failures without the fix) — `.agent/scripts/merge_pr.sh` `delete_remote_branch` (0945c3e5)
- [x] (suggestion) Fork PR: Step 4 and the local branch delete leave a same-named local worktree and branch alone; test; header and design.md bullet updated — `.agent/scripts/merge_pr.sh` Steps 4-6 (b9fe05fe)

### Notes
- Finding 8 of the first round stays deferred by the host, pending the owner's answer on a follow-up issue (not "deferred by the owner").

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP on the final tree: every hook passed, exit 0; `validate-script-tests` ran every suite (full run: the branch changes the shared helper `_worktree_helpers.sh`).
- `test_merge_pr_skill.sh` 132 passed, 0 failed (also run directly while fixing).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-15 11:39 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent ae4f8ccbe340f2017, resume 1 of 3)
**Verdict**: approved

**Branch**: feature/issue-478 at `8220d187`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: round 2 findings 1-6 against 4fd1c142..6676cd24, and regressions in that diff only. Cross-model: skipped (round-3 convergence check, per handoff). All six fixed as described: local `branch -d` now after both syncs and after the remote delete (so a tracking ref removed by `push --delete` no longer matters); design.md citations spot-checked against the final file (350, 460-509, 645-668, 728, 841/863, 999/1312, 1024/1437, 1604/1621, 2448-2503 all land on the named code); classifier refuses a fork PR and a skill/repo-type mismatch before SKILL_PR is set; main-checkout check needs a non-empty git dir and a missing folder is pruned; race decided by a second `ls-remote` exit code; fork PR leaves local worktree and branch alone. No regressions found. `test_merge_pr_skill.sh` 132 passed, 0 failed (run here); shellcheck --severity=warning clean on merge_pr.sh and the test.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-15 11:39 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (round 3 pre-push review e2660137 approved, Ship: recommended, 0 must-fix, 0 suggestions)
**After**: publish
**Decision**: publish

Push the branch and open the pull request with the round 3 Decision summary.
