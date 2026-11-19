---
issue: 522
---

# Issue #522 — run-issue step 11's merge command is refused for a package pull request

## Issue Review
**Status**: complete
**When**: 2026-11-19 14:40 -05:00
**By**: Claude Code (claude-sonnet-5-5)

**Issue**: #522

### Scope Assessment

**Well-scoped?** Yes. The claim checks out: `merge_pr.sh` derives the repo kind from `--repo` (a repo that is neither the workspace's nor the resolved project's remote is `package`) and exits 2 on a `--type` that differs (`merge_pr.sh` lines 442-453, message "Drop --type; it is derived from --repo"). Step 11 of `run-issue` reads `merge_pr.sh --pr <M> --type <type>`, "or `--pr <owner/repo#M>` for a package issue", and the earlier paragraph (lines 51-55) says to pass `--project <project>` wherever the skill passes `--type <type>`, `merge_pr.sh` included. Line 155 repeats "`merge_pr.sh --type` at merge, with `--project` for a project root". Followed literally for a package issue in a project session, that gives `--pr <owner>/<repo>#<M> --type project --project <project>`, which is refused.
**Right repo?** Yes. The skill, the script's tests and `test_skill_paths.sh` are all workspace files.
**Serves**: Quality of the work — `docs/design.md#merge-gate`
**Design picture?** No change. The fix states how a package merge is called; it moves no part.
**Dependencies**: none identified.

**Which fix.** Fix the skill, not the script.
- The script's refusal is deliberate and tested: `test_repo_conflicting_type_rejected` pins it (for `--type workspace`), and the comment at lines 434-441 gives the reason: a wrong `--type` sends cleanup at the wrong checkout. For a package repo, `WORKTREE_TYPE` is cleared at line 455 so the single-repo cleanup path is never taken.
- Accepting `--type project` for a package repo would make `--type project` mean two things in one script: "the project's own repo" (single-repo cleanup) and "a package repo of the project" (manifest cleanup). It would need a special case in the conflict check, which would weaken the guard for the one case it exists for.
- `.agent/WORKTREE_GUIDE.md` (lines 327-334) already gives the package merge without `--type` (`--pr acme/sonar_msgs#57`); the script header's usage does too. The skill is the one text that disagrees.

**`--project` in that call.** Accepted, and optional. It is resolved by `registry_resolve_project_arg` at the top of the script (an unregistered name is refused), and its one effect for a package PR is to narrow the package-worktree lookup to the manifests whose header names that instance (lines 644-646). It is needed only when the same repo and branch are worktreed under two instances (`test_same_repo_under_two_instances_requires_project`). Passing it always is harmless and keeps the lookup to the project the run checked, so the sound text is `--pr <owner/repo#M> [--project <project>]`, with `--project` passed whenever the session's `project=` is not empty. It is not refused with a package `--repo`; only `--type` is.

**Other texts**: no other text gives a package merge command with `--type`. `.agent/knowledge/`, the `orchestrator` skill and `docs/` have none; `.agent/knowledge/script_reference.md` describes the package path without a command line.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | Action needed | The drift needs a pin. Add a `has` line to `.agent/scripts/tests/test_skill_paths.sh` for step 11's package form (no `--type`, `--project` kept), and a case in `test_merge_pr.sh` that `--type project` against a package repo is refused while `--project <name>` with a qualified package `--pr` is accepted. |
| Verify before claiming | OK | Every claim above was read from the script, the skill and the tests. |
| Keep one current design | OK | No design section changes; the `merge_pr.sh` row in `docs/design.md` is checked for any `--type` wording during the work. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0012 | Yes | Package worktrees and repo-qualified merge; the fix matches its "kind derived from the repo" rule. |
| ADR-0016 | No | No user-tier change. |

### Consequences

- Reword step 11 and the sentence at lines 51-55 of `.claude/skills/run-issue/SKILL.md`, and line 155, so a package merge is `--pr <owner/repo#M>` with `--project` and no `--type`.
- If `docs/design.md` or `script_reference.md` repeat the `--type` form for a package merge, update them in the same change.

### Recommendations

- Fix the skill: in step 11 give the package form as `merge_pr.sh --pr <owner/repo#M> [--project <project>]`, state that `--type` is derived from the repo and is not passed, and exempt the package merge in the "wherever this skill passes `--type`" sentence (lines 51-55) and in line 155.
- Add the two pins described under Principle Alignment (the skill text in `test_skill_paths.sh`, the refusal and acceptance in `test_merge_pr.sh`).
- One short plan is enough: three files (the skill, `test_skill_paths.sh`, `test_merge_pr.sh`), one PR, no design change.

### Actions
- [ ] The drift needs a pin. Add a `has` line to `.agent/scripts/tests/test_skill_paths.sh` for step 11's package form (no `--type`, `--project` kept), and a case in `test_merge_pr.sh` that `--type project` against a package repo is refused while `--project <name>` with a qualified package `--pr` is accepted.
- [ ] Fix the skill: in step 11 give the package form as `merge_pr.sh --pr <owner/repo#M> [--project <project>]`, state that `--type` is derived from the repo and is not passed, and exempt the package merge in the "wherever this skill passes `--type`" sentence (lines 51-55) and in line 155.
- [ ] Add the two pins described under Principle Alignment (the skill text in `test_skill_paths.sh`, the refusal and acceptance in `test_merge_pr.sh`).
- [ ] One short plan is enough: three files (the skill, `test_skill_paths.sh`, `test_merge_pr.sh`), one PR, no design change.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 14:35 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the open actions are the plan's content; none changes the issue's scope)
**After**: issue-actions
**Decision**: proceed

The Issue Review confirmed the claim and found the skill to be the only text that disagrees with the script. The host takes its recommendation: the skill is changed, not the script (the refusal is deliberate and pinned by a test). A package merge takes --pr <owner/repo#M> with --project when the session's project is not empty, and no --type. The three actions go to the plan as written.

## Plan Authored
**Status**: complete
**When**: 2026-11-19 14:45 -05:00
**By**: Claude Code (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-522/plan.md` at `423afd2f`

Reword step 11, the --project sentence and the usage line of run-issue so a package merge is --pr <owner/repo#M> with --project when project= is not empty and no --type; pin the text in test_skill_paths.sh, add the missing --type project refusal case to test_merge_pr.sh, and fix the design.md row.

## Plan Review
**Status**: complete
**When**: 2026-11-19 14:38 -05:00
**By**: Claude Code (claude-opus-5-5)
**Verdict**: ready

**Issue**: #522 — run-issue step 11's merge command is refused for a package pull request
**Plan**: `.agent/work-plans/issue-522/plan.md` at `423afd2f`
**Branch**: `feature/issue-522`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four files, one PR: three passages of the run-issue skill, one `has` pin, one refusal case, one design row. |
| Issue alignment | Good | Takes the issue's first option (the skill changes) with a pin in both suites, as the issue asks. Covers every Issue Review action; the "`--project` with a qualified package `--pr` is accepted" half is already pinned by `test_same_repo_under_two_instances_requires_project` (exit 0 with `--project inst2`), checked. Serves: "Quality of the work: `docs/design.md#merge-gate`" — goal exists at `README.md` "### Quality of the work", anchor at `docs/design.md` "## Merge gate". |
| File targeting | Good | Checked other merge-time texts: `orchestrator`, `triage-reviews` and `host_standing_rules.md` give no `merge_pr.sh` command line; `onboard-project` (`--pr <M> --project <name>`), `research`/`inspiration-tracker` (`--pr <N>`), the Makefile `merge-pr` target (no `--type`) and AGENTS.md's Never line (`merge_pr.sh --pr <N>`) give or imply no refused form. In run-issue only lines 51-55, 155 and 1025 carry the `--type` merge wording. |
| Consequences | Good | Skill, pin, script suite and design row are all listed. Main has moved (PR 526) but `git diff HEAD main` is empty for the skill, `merge_pr.sh`, both test files and `docs/design.md`. |
| Principle alignment | Good | The new sentences match `merge_pr.sh`: with a qualified `--pr` (sets `REPO_ARG`) the project-root block is skipped, `PJ_REMOTE` stays empty, so any non-workspace repo is `package` and any `--type` other than empty is refused with exit 2 ("Drop --type; it is derived from --repo"); `--project` is resolved first by `registry_resolve_project_arg` (an unregistered name exits 1, but `project=` from `session_root.sh` is always a registered root) and only narrows the manifest lookup. The pin's three fixed texts are all absent from today's skill (checked with the suite's own flattening), so it fails first. Test-what-breaks: the new `test_merge_pr.sh` case pins the refusal of the exact form the skill produced. |
| ADR compliance | Good | ADR-0012 (repo kind derived from the repository) is followed; ADR-0016 not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences]** (low) — The `docs/design.md` row the plan edits (line 529) also says the run-issue skill's `--type` "defaults to `workspace`", while the skill (lines 150-151) defaults to the type of the session's root (only `agent start-task` defaults to `workspace`), and its Lines column cites `SKILL.md` 47-54, which step 2's longer sentence moves further. Since the row is being touched, correct the default wording for the skill and refresh the line cite in the same edit.
2. **[Issue alignment]** (low) — The skill's Scope section (lines 1205-1206) says a sibling's own pull request "is merged with `--pr <owner/sibling#M>`" and says nothing of `--project`, while the new step 11 passes `--project` for the owning package PR. Not a wrong command (the script accepts it, and without `--project` the two-instance case stops with exit 2 and lists the `--project` choices), but adding "with `--project <project>` when `project=` is not empty" there would make the two read alike.
3. **[File targeting]** (note) — In the new test, `--project` is resolved before the `--type`/`--repo` check, so the name passed must be registered in the sandbox (e.g. via `make_package_worktree`'s instance, as `inst2` is), or the case exits 1 for the wrong reason; the plan already tells the implementer to check this. Asserting the exit is 2 (not merely non-zero) keeps it honest.

### Summary

The plan is accurate against `merge_pr.sh` and its suite, its three sentences give a host a command the script accepts, no other merge-time text gives the refused form, and the pin fails on today's text. Two low-severity wording improvements; ready for implementation.

### Recommended Actions

- [ ] While editing the `docs/design.md` run-issue row, fix "defaults to `workspace`" for the skill and the `SKILL.md` line cite.
- [ ] Optionally add the `--project` clause to the sibling sentence in the skill's Scope section.
- [ ] In the new `test_merge_pr.sh` case, use a registered `--project` name and assert exit 2 exactly.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 14:38 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (plan review: ready, two low findings and a note)
**After**: plan
**Decision**: proceed

The Plan Review's two low findings and its note go to the implementer in the handoff: in the docs/design.md row the plan edits, correct "defaults to workspace" (run-issue's --type defaults to the type of the session's root) and the SKILL.md line reference; give the skill's Scope sentence about a sibling repository's pull request the same --project clause as the new step 11; the new test_merge_pr.sh case passes a --project name registered in its sandbox and asserts exit 2 exactly.

## Implementation
**Status**: complete
**When**: 2026-11-19 14:42 -05:00
**By**: Claude Code (claude-opus-5-5)
**Branch**: feature/issue-522 at `6e413324`

- `.claude/skills/run-issue/SKILL.md`: step 11 gives a workspace or single-repository merge as `merge_pr.sh --pr <M> --type <type>` (with `--project` when `project=` is not empty) and a package merge as `merge_pr.sh --pr <owner/repo#M>` with `--project` when `project=` is not empty and never `--type`, saying why (the script derives the kind and refuses a differing `--type`). The `--project` sentence near the top (lines 51-58) limits "wherever this skill passes `--type`" to a workspace or single-repository merge and says a package merge passes `--project` and no `--type`; the `--type` usage line (152-159) says the same; the Scope sentence on a sibling's own pull request gains the same `--project` clause and "no `--type`" (Plan Review finding 2).
- `.agent/scripts/tests/test_skill_paths.sh`: one `has` pin with the plan's three fixed texts; run against the unchanged skill first, it failed on the step 11 text.
- `.agent/scripts/tests/test_merge_pr.sh`: `test_repo_type_project_rejected_for_package_repo` runs `--pr owner/pkg_a#561 --type project --project demo` (`demo` registered by `make_package_worktree`) and asserts exit 2 exactly, the conflict and "Drop --type" messages, no `pr merge` call and the worktree intact.
- `docs/design.md` inventory row for `run-issue`/`agent start-task`: the skill's `--type` defaults to the type of the session's root (`agent start-task`'s to `workspace`), the package exception is added, and the `SKILL.md` cite is now 45-58, 152-159 (Plan Review finding 1). No heading moved.
- The commands checked against `merge_pr.sh`: the package form with `--project` and no `--type` by the suite's `test_same_repo_under_two_instances_requires_project` (`--pr owner/pkg_a#560 --project inst2`, exit 0); the refused form by the new case; the single-repository form by reading the code path (`--project` resolved at line 234, used for the project root at line 330, unchanged by this work).
- `merge_pr.sh` not changed. No departure from the plan beyond the two review findings the checkpoint carried.

Suites, each run on its own with `bash`:
- `test_skill_paths.sh`: `test_skill_paths: 164 passed, 0 failed`
- `test_merge_pr.sh`: `=== Results: 175 passed, 0 failed ===`
- `test_package_issue_loop.sh`: `test_package_issue_loop: 220 passed, 0 failed`
- `test_script_tests_hook_scope.sh`: `test_script_tests_hook_scope: 342 passed, 0 failed`
- `test_dispatch_phase.sh`: `test_dispatch_phase: 236 passed, 0 failed`
- `test_design_anchors.sh`: `test_design_anchors: 82 passed, 0 failed` (the `docs/design.md` anchor hook also passed on commit)

The full pre-commit pass was left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 14:46 -05:00
**By**: Claude Code (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-522 at `27d01ee3`
**Base**: origin/main
**Depth**: Standard (reason: governance file `.claude/skills/run-issue/SKILL.md` changed)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 1 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Verified: test_skill_paths.sh 164/0 and test_merge_pr.sh 175/0 pass; the new pin fails (1 failure) against origin/main's SKILL.md; the new test fails (exit 0, a merge logged) with merge_pr.sh's conflict `exit 2` removed; shellcheck clean on both test files. Every step-11 form (workspace, single-repository project, package with `--project`, sibling) checked against merge_pr.sh 173-188, 227-235, 327-349, 427-456, 590-680; session_root.sh prints an empty `project=` for the workspace. No other host-followed text gives `--type` on a package merge. Cross-model: gemini completed (its `SKILL.md 45-58` off-by-one claim is false: line 58 ends the sentence), codex completed.

### Findings
- [x] (suggestion) Unintended edit drops the space in an unrelated address-findings label ("finding;a dispatched"); restore it — `.agent/scripts/tests/test_skill_paths.sh:776`
- [x] (suggestion) New test's title/comment imply the refusal is package-specific; with a qualified `--pr`, PJ_REMOTE is never set so `--type project` is refused for any repo (merge_pr.sh 444-445 is dead under `--repo`; a follow-up issue for the script, out of scope here) — `.agent/scripts/tests/test_merge_pr.sh:664`
- [x] (suggestion) "finds the package worktree" is unqualified: a `--project` whose resolved instance differs from the manifest header filters every manifest out and the merge proceeds silently with no cleanup (pre-existing script behaviour) — `.claude/skills/run-issue/SKILL.md:1035`
- [x] (suggestion) The row merges two entry points: `agent start-task` forwards `--type` only to worktree creation; dispatch, PR targeting and merge are run-issue's — `docs/design.md:529` (deferred: predates the branch; the host's checkpoint leaves it out of this issue)

## Checkpoint
**Status**: complete
**When**: 2026-11-19 14:46 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review approved with four suggestions; one is an unintended edit to an unrelated line, which is not published as it is)
**After**: publish
**Decision**: address

The full pre-commit pass was not run: the answer changes the code, so the pass runs on the head that follows. Fixed in this round: suggestion 1 (restore the space dropped from an unrelated address-findings label in test_skill_paths.sh), suggestion 2 (the new test's title and comment say what is true: with a qualified --pr the script refuses any --type that differs from the derived kind, package or not), suggestion 3 (the skill's "finds the package worktree" gets its condition: when --project names the instance the worktree was made under). Suggestion 4 (the docs/design.md row mixes two entry points) predates the branch and is left; the second half of suggestion 2 (merge_pr.sh treats a qualified --pr for a project's own pull request as a package pull request) is a script matter outside this issue, which the host proposes to the owner as an issue.

## Implementation
**Status**: complete
**When**: 2026-11-19 14:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-522 at `a62e6809`
**Addressed**: Local Review (Pre-Push) at `27d01ee3` (2026-11-19 14:46 -05:00)
**Commits**: 34dba88c, ca5b3bfe, a62e6809

### Actions
- [x] Restored the space dropped from the unrelated address-findings label; `git diff origin/main` on the file now shows only the new pin — `.agent/scripts/tests/test_skill_paths.sh:776`
- [x] Renamed the new test to `test_qualified_pr_differing_type_project_rejected` and reworded its title and comment: with a repo-qualified `--pr` the script derives the kind from the repository and refuses any `--type` that differs; assertions unchanged — `.agent/scripts/tests/test_merge_pr.sh:664`
- [x] "finds the package worktree" now carries its condition: when `--project` names the instance the worktree was made under, which the session's `project=` does; no pin covers that sentence, so the pin is unchanged — `.claude/skills/run-issue/SKILL.md:1035`
- [x] The design.md row mixing two entry points — `docs/design.md:529` (deferred: predates the branch; the host's checkpoint leaves it out of this issue)

### Checks
- `bash .agent/scripts/tests/test_skill_paths.sh`: `test_skill_paths: 164 passed, 0 failed`
- `bash .agent/scripts/tests/test_merge_pr.sh`: `=== Results: 175 passed, 0 failed ===`
- Commits used `SKIP=validate-script-tests`; the full pre-commit pass is left to the host.
