---
issue: 259
---

# Issue #259 — Trim AGENTS.md to policy + pointers; move reference tables to .agent/knowledge/

## Issue Review
**Status**: complete
**When**: 2026-11-02 12:15 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #259

### Scope Assessment

**Well-scoped?** Yes, with a caveat. One PR is feasible (doc moves plus pointers), but the body's numbers are stale: AGENTS.md is 448 lines / 33,047 bytes today, not 418 / 18.5 KB, and the Script Reference table has grown (about 50 rows, several very long). The ~150-line target now needs roughly 300 lines out; docs/design.md OQ-4 (budget "under 200 lines per file") is the recorded open question this answers, so the target should be restated as a number the owner sets.
**Right repo?** Yes. Workspace repo (AGENTS.md, .agent/knowledge/).
**Serves**: Know whether it works / keep instructions lean, per the README workspace goals; `docs/design.md#instruction-layers` (answers OQ-4).
**Design picture?** Changes `docs/design.md#instruction-layers`: the "AGENTS.md is 442 lines" figure and the Change log row must be updated in the same change (ADR-0017), and OQ-4 closed or reworded once the owner picks a budget. The owner's go-ahead for this drive counts as approval in principle for the instruction-file change; the budget number itself is his call.
**Dependencies**: "After #252's plan lands" no longer holds: #252 is CLOSED. Sibling #258 (skill carving) is independent. Parallel #323 adds a Script Reference row to AGENTS.md on its own branch; whichever merges second rebases, and if this lands first #323's row belongs in the new script_reference file. Fork-side rolker/ros2_agent_workspace#564 coordination still applies.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | Always-loaded layer should hold rules only; reference tables load on demand |
| Keep one current design | Action needed | Update `docs/design.md#instruction-layers` (line/byte counts, OQ-4, Change log row) in the same PR |
| Verify before claiming | Action needed | Re-measure the current sizes and section list; the body's counts (418 lines, ~45 rows, 150 target) are stale, and the "Documentation Accuracy" section it says to keep is now "Verify Before Claiming" |
| Put each thing at the level it applies to | OK | Moves reference material to .agent/knowledge/ with pointers |
| Ask-First for instruction files | Watch | Owner go-ahead in principle recorded; final merge remains his |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0010 (git-bug optional) | Yes | Stays the decision record; its text and `_issue_helpers.sh` line 15 cite AGENTS.md "git-bug-first Pattern" and must be repointed |
| ADR-0017 (design doc current) | Yes | Design change, see above |
| ADR-0013 | No | |

### Consequences

- The SessionStart hook pins nine AGENTS.md headings (`.claude/hooks/session_start_project_layer.sh`, checked by `test_session_start_layer.sh`). None of the sections to move (GitHub CLI Patterns, Build & Test, Script Reference, Worktree Workflow) is pinned, so project sessions lose nothing. The pinned ones must be kept verbatim, including "Verify Before Claiming". Boundaries must keep the three hard CLI rules, since Boundaries is the pinned section that reaches project sessions.
- Repoint references: `_issue_helpers.sh` line 15, ADR-0010 line 69, and links in CLAUDE.md, CODEX.md, copilot and gemini instruction files; grep for "Script Reference", "GitHub CLI Patterns", "git-bug-first Pattern".
- `test_issue_review_entry.sh` mentions the AGENTS.md script row only as fixture text; no change needed. The pre-commit hook scoping (`run_script_tests.sh`) treats AGENTS.md as in-scope, so run the full hooks once.
- CLAUDE.md and AGENTS.md instruction text that tells agents to add Script Reference rows (e.g. review-issue/plan-task consequences maps in principles_review_guide.md) should point at the new file.

### Recommendations

- Re-baseline the body: record 448 lines / 33,047 bytes as "before" and have the owner confirm the target (150 as written, or under 200 per OQ-4).
- Treat the Script Reference as a moved file with a generation or drift check if cheap; otherwise move verbatim and leave generation as follow-up.
- Land before or coordinate with #323: if this merges first, #323 rebases its row into `.agent/knowledge/script_reference.md`.
- Add a size ratchet (line count of AGENTS.md) only if the owner wants it; otherwise leave to #258's pattern.

### Actions
- [ ] Update `docs/design.md#instruction-layers` (line/byte counts, OQ-4, Change log row) in the same PR
- [ ] Re-measure the current sizes and section list; the body's counts (418 lines, ~45 rows, 150 target) are stale, and the "Documentation Accuracy" section it says to keep is now "Verify Before Claiming"
- [ ] Re-baseline the body: record 448 lines / 33,047 bytes as "before" and have the owner confirm the target (150 as written, or under 200 per OQ-4).
- [ ] Treat the Script Reference as a moved file with a generation or drift check if cheap; otherwise move verbatim and leave generation as follow-up.
- [ ] Land before or coordinate with #323: if this merges first, #323 rebases its row into `.agent/knowledge/script_reference.md`.
- [ ] Add a size ratchet (line count of AGENTS.md) only if the owner wants it; otherwise leave to #258's pattern.

## Checkpoint
**Status**: complete
**When**: 2026-11-02 12:16 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the review's open actions are mechanism: design-doc update, re-measuring, verbatim move, coordination with issue 323; the two it routed to the owner, line target and size ratchet, are decided below from the recorded design and listed for veto; none changes the issue's scope)
**After**: issue-actions
**Decision**: proceed

The issue review (ebfb8718) found the issue well scoped; its dependency on issue 252 no longer holds (closed), the body's sizes are stale (AGENTS.md is 448 lines, 33,047 bytes), and "Documentation Accuracy" is now "Verify Before Claiming". Plan-task takes the six actions as plan inputs.

### Decisions made (owner may veto)
- Line target: under 200 lines, the reference point docs/design.md OQ-4 records; aim for the issue's 150 where it comes naturally — undoing it: a number in the plan.
- A size check on AGENTS.md (fails when it passes the budget) is added only if it is one short hook or an existing validator's line; otherwise no ratchet — undoing it: drop the check.
- The Script Reference table moves verbatim; a drift check against the scripts' own --help is out of scope — undoing it: a follow-up issue.
- Coordination with issue 323: whichever merges second rebases; 323's new row goes into the moved file if 259 lands first — undoing it: none.

## Plan Authored
**Status**: complete
**When**: 2026-11-02 12:18 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-259/plan.md` at `4d731111`

Move Script Reference, git-bug notes, GitHub CLI patterns, Build & Test and the worktree command blocks to knowledge files with pointers, one commit each, then a line-budget check and the design-doc update; expected size is near 205 lines before fallback trims reach under 200.

## Plan Review
**Status**: complete
**When**: 2026-11-02 12:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #259 — Trim AGENTS.md to policy + pointers; move reference tables to .agent/knowledge/
**Plan**: `.agent/work-plans/issue-259/plan.md` at `4d731111`
**Branch**: `feature/issue-259`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, doc moves plus one check; seven atomic commits is right-sized |
| Issue alignment | Good | Covers every move the issue lists, the three hard CLI rules in Boundaries, the adapter-file check and before/after measurement. Serves, as checked: "Goal "Know whether it works" (keeping the always-loaded instructions lean), `docs/design.md#instruction-layers`." — the README goal and the anchor exist. All six issue-review actions are taken up (re-baseline, design doc, verbatim move, 323 coordination, size check per the checkpoint) |
| File targeting | Needs work | Two references into moved text are not listed (finding 3) |
| Consequences | Needs work | The size estimate is about 20 lines low, so the plan as written ends at its own "stop and ask" branch (finding 1) |
| Principle alignment | Needs work | The line-budget check sits where no PR runs it (finding 2); the first fallback lever trims a pinned section (finding 5) |
| ADR compliance | Needs work | The ADR-0010 edit is permitted by ADR-0008; the plan should cite it instead of treating the edit as a departure (finding 4) |
| ROS conventions | N/A | Workspace plan |

Verified in the code, as asked:
- Pinned headings: the nine in the plan match `WORKSPACE_SECTIONS` in `.claude/hooks/session_start_project_layer.sh` exactly, and `test_session_start_layer.sh` asserts them; none of the moved sections is pinned.
- Readers of AGENTS.md (`git grep AGENTS.md` over `.agent/ .claude/ .github/ Makefile .pre-commit-config.yaml`, plus `docs/`): the plan's list is complete for tests and hooks. One further suite reads the path but not headings: `test_script_tests_hook_scope.sh` maps `AGENTS.md` to suites by path, so no change. The other hits (`merge_pr.sh` 687/826 and `cross_model_review.sh` 639 citing branch rules, `orchestrator/SKILL.md` 55 citing Ask First, `project_integration_audit.sh`, `discover_governance.sh`, test fixtures) refer to sections that stay or to the file as a whole. The two misses are prose pointers (finding 3).
- Size: measured section lengths (awk over `## ` headings) match the plan's Context. Applying the plan's own per-step targets: 448 − 47 (Script Reference 51 → 4) − 95 (GitHub CLI 101 → 6) + 2 (Boundaries lines) − 19 (Build & Test 28 → 9) − 60 (Worktree Workflow 80 → 20) = about 229, not 205-210. Step 6's levers (Skill Worktree Exception 12 → ~3, adapter table 7 → 1, References 10 → ~5) take off about 20 more, leaving about 209.

### Findings

1. **[Consequences]** (medium) After-size estimate is low by about 20 lines: the plan's per-step targets give ~229 after steps 1-5 and ~209 after all of step 6, so implementation would stop on an owner question. Which text to cut is mechanism, not the owner's budget question. Name more rule-free levers in the plan now and re-estimate. Examples: put the four new pointers in one pointer list (or the existing References section) instead of four `##` sections, which saves the heading and blank lines of each. Keep the four `make` targets the issue names, not six. Bring Worktree Workflow to ~12 lines. Keep the "stop and ask" only for cutting rule text.
2. **[Principle alignment]** (medium) "Enforce what matters, as simply as possible": `validate_workspace.py` runs only through `make validate` and `dashboard.sh`, not in CI and not as a hook. A PR that grows AGENTS.md past 200 lines would pass every gate. The dashboard would also report it as "Workspace configuration issue", and that validator otherwise checks only local setup. The `validate-documentation` job in `.github/workflows/validate.yml` already loops over `AGENTS.md`. One `wc -l` test there fails on the PR that breaks the budget, and it is the same size as the planned change. Put the check there, and add a `docs/design.md#rules` row for it (Enforced by `CI`) in step 8. If it stays in the validator, the plan needs a test case for it ("Test what breaks").
3. **[File targeting]** (low) Two missed references: `docs/design.md` line 427 cites `AGENTS.md`, "Worktree Entry", which step 5 moves to `WORKTREE_GUIDE.md`; repoint it in step 8. `.claude/skills/audit-workspace/SKILL.md` line 159 uses "AGENTS.md script table lists ..." as its example; repoint it with line 75 in step 1. `principles_review_guide.md` line 69 ("`AGENTS.md` worktree section") stays true for the trimmed section. It should name WORKTREE_GUIDE as the home of the command blocks.
4. **[ADR compliance]** (low) Answer to the planner's open question. Editing ADR-0010's pointer line is allowed. ADR-0017's Decision reads "Accepted ADRs are history: superseded, not edited, apart from ADR-0008 addendums". ADR-0008's Permitted list includes "Fixing broken links ... that don't change meaning". Once the section moves, "See `AGENTS.md` "git-bug-first Pattern"" is a broken pointer, so repointing it is an ADR-0008 fix and does not depart from the rule. `docs/design.md` line 684 ("none is edited here") is about the decision-register rewrite, not every edit. The design.md register row for 0008 says the same: "a references list or link and typo fixes". Precedent: 9ad62671 made ADR-0014's reference a pointer only. Add ADR-0008 to the ADR table as the authority, drop "at the host's instruction" from step 2, and remove the first Open Question.
5. **[Principle alignment]** (low) Step 6's first lever condenses "Skill Worktree Exception", which sits inside the pinned Issue-First Policy section. The SessionStart hook renders that section into project sessions, and `/onboard-project` runs there with `--type project --project <name>`. Use levers outside the nine pinned sections first. If this one is still needed, keep the onboard-project sentence.

### Summary

The plan is sound in shape: moves, pointers, pinned headings and repoints are correct, and the reader list it gives is complete for tests and hooks. Two things need fixing before implementation. It will not reach its 200-line target with the levers it names. Its size check sits in a validator no PR runs. Both are small plan edits.

### Recommended Actions

- [ ] Re-estimate the after-size from the per-step targets (~229, then ~209) and add rule-free levers (one pointer list instead of four sections, four `make` targets, tighter Worktree Workflow) so the plan reaches under 200 without an owner stop
- [ ] Move the line-budget check to the `validate-documentation` CI job (or add a test if it stays in `validate_workspace.py`), and add a `docs/design.md#rules` row for it in step 8
- [ ] Add `docs/design.md` line 427 ("Worktree Entry" citation) to step 8 and `audit-workspace/SKILL.md` line 159 to step 1
- [ ] Cite ADR-0008 for the ADR-0010 pointer fix and drop that Open Question
- [ ] Order step 6 levers so pinned sections are trimmed last, keeping the onboard-project sentence

## Checkpoint
**Status**: complete
**When**: 2026-11-02 12:22 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (plan review needs-work with two medium findings; revising is within the checkpoint table; first host revise on this issue)
**After**: plan
**Decision**: revise

The plan review (99962a2a) found the size estimate about 20 lines low (about 229 after the moves, 209 after the fallbacks), so the plan needs trims that touch no rule text; the line-budget check placed in validate_workspace.py would run in no gate; two prose references into moved text are missing; the ADR-0010 repoint is allowed (ADR-0008 permits fixing links, precedent 9ad62671); pinned sections are trimmed last.

### Decisions made (owner may veto)
- The line-budget check becomes a small pre-commit hook with a test, so it runs locally and in CI through make lint without a change to the CI workflow (which is Ask First) — undoing it: move the check.
- Extra trims that touch no rule text: one pointer list in place of four new sections, the four make targets the issue names, a shorter worktree section; pinned sections last — undoing it: a plan line each.

## Plan Authored
**Status**: complete
**When**: 2026-11-02 12:23 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-259/plan.md` at `6150c64b`

Revised after plan review: size arithmetic shown section by section (about 199 lines, 196 with the last pinned lever), a pre-commit line-budget hook with a test replaces the validator check, missing references added, ADR-0010 repoint cited to ADR-0008.

## Plan Review
**Status**: complete
**When**: 2026-11-02 12:26 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #259 — Trim AGENTS.md to policy + pointers; move reference tables to .agent/knowledge/
**Plan**: `.agent/work-plans/issue-259/plan.md` at `6150c64b`
**Branch**: `feature/issue-259`

Second review, of the plan revised after the first `## Plan Review` (99962a2a, needs-work). All five earlier findings are resolved; what remains is low.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, eight atomic commits; the hook adds one script, one config entry and one suite |
| Issue alignment | Good | Every move the issue lists, the hard CLI rules in Boundaries (the "never guess URLs" rule is already in Never), the four `make` targets, the adapter-file check, before/after measurement. Serves, as checked: "Goal "Know whether it works" (keeping the always-loaded instructions lean), `docs/design.md#instruction-layers`." |
| File targeting | Good | Repointed references are the complete set (verified below) |
| Consequences | Good | Size arithmetic now reaches the target; one small consequence missing (finding 4) |
| Principle alignment | Good | The budget now has a check that fails the PR that breaks it, with a test; pinned sections are trimmed last |
| ADR compliance | Good | ADR-0008 cited for the ADR-0010 link fix; ADR-0016 headings kept; ADR-0017 step 8 (finding 1 sharpens it) |
| ROS conventions | N/A | Workspace plan |

Verified in the code, as asked:
- Size table: measured AGENTS.md (awk over `## ` headings) gives preamble 13, Terminology 22, Boundaries 33, Communication 8, Quality 24, Tool Usage 14, Worktree Workflow 80, Issue-First 25, AI Signature 10, GitHub CLI 101, Build & Test 28, Verify 11, Cleanliness 6, Post-Task 12, Script Reference 51, References 10: sum 448 = `wc -l`, and 33,047 bytes. The After column sums to 199. Each After figure is reachable: the preamble as H1, sentence, two-line adapter list (8); References as three grouped doc bullets plus four pointers (the current eight doc links group naturally); Build & Test 6; Worktree Workflow 8 is the tightest. Lever 6c saves 2 lines, not 3 (the joined lines are "Branch naming", a blank, "All other rules"), so 197, not 196 (finding 5).
- Hook in CI: `.github/workflows/validate.yml` job "Lint (pre-commit)" runs `make lint`, which is `$(PRE_COMMIT) run --all-files` (Makefile line 116). A local hook with `files: ^AGENTS\.md$` runs under `--all-files` because AGENTS.md matches, and the job's `SKIP` list names only the four local-state hooks. `language: system` local hooks already run there (`check-design-anchors`, `validate-adapter-contract`). No workflow change needed. The new suite is found by `run_script_tests.sh` (globs `test_*.sh`) and is mapped to the new script by `suites_for_files.sh`'s reference derivation, since both sit under the `validate-script-tests` scope `^\.agent/`.
- References: `git grep -i` over the tree (outside AGENTS.md and work plans) for the moved section names ("Script Reference", "script table", "GitHub CLI Patterns", "git-bug-first", "Build & Test", "Worktree Workflow", "Worktree Entry", "Repo Targeting", "Merging PRs from Worktrees", `AGENTS.md#`) and every `AGENTS.md` mention finds exactly the plan's set: `docs/design.md` 427, `audit-workspace/SKILL.md` 75 and 159, `principles_review_guide.md` 63 and 69, `_issue_helpers.sh` 15, ADR-0010 69. The other hits stay true: `cross_model_review.sh` 639 (branch naming, in Boundaries), `merge_pr.sh` 687/826 (Never), design.md 647 ("adapter file listed in AGENTS.md", still listed after 6a), `CODEX.md` "Worktree Entry" (its own section, no link into AGENTS.md), `.agent/templates/project_agents_guide.md` "Build & Test" (a template heading), the inspiration digest (a record), ADR-0006 line 12 (history).

### Findings

1. **[ADR compliance]** (low) Step 8 does not say the Instruction layers block changes status. It is labelled `proposed` and opens "Nothing here is built"; once the hook lands, the budget is built, so the status and that sentence change (ADR-0017). OQ-4's row names the Owner as decider and AGENTS.md changes as Ask First; the budget number and the new hook (precedent: `check-design-anchors` was "approved by the owner 2026-10-09") were host decisions listed for veto. Close OQ-4 citing that, and put both in the PR's decision summary so the merge checkpoint is where the owner confirms them.
2. **[Principle alignment]** (low) The hook's `files: ^AGENTS\.md$` means a commit that edits only `check_agents_md_budget.sh` or the hook entry does not run the check locally; `check-design-anchors` lists its own script and `.pre-commit-config.yaml` in `files:`. Do the same. Also say the script's interface (an optional path, default the repo root's `AGENTS.md`), since the 200/201/missing-file test needs to point it at a fixture.
3. **[Consequences]** (low) `docs/design.md` line 142 says each Rules-table rule "is stated in `AGENTS.md` or the principles"; the new row's rule would be stated in neither. One line in AGENTS.md (for example in References: "this file stays at most 200 lines; reference material goes to `.agent/knowledge/`") fixes that and tells the next editor why the hook fails. Use one wording throughout: the plan says "under 200" but the hook passes at 200.
4. **[Consequences]** (low) `principles_review_guide.md` line 63: a new script in `.agent/scripts/` gets a Script reference row. Add `check_agents_md_budget.sh` to `script_reference.md` (and the consequences table).
5. **[Consequences]** (low) Arithmetic: lever 6c gives 23 for Issue-First, total 197, not 22 and 196. With 199 as the estimate and 200 as the limit, the margin is one line; the real count after the trim decides, as the plan says.

### Summary

The revised plan resolves all five earlier findings: the section table matches the file and reaches 199, the budget check runs in CI through `make lint` with no workflow change, and the repointed references are complete. The remaining findings are low and can be taken during implementation. Ready.

### Recommended Actions

- [ ] Step 8: change the Instruction layers status and "Nothing here is built", close OQ-4 as host-decided for owner confirmation, and list the budget and the new hook in the PR's decision summary
- [ ] Hook `files:` also matches `check_agents_md_budget.sh` and `.pre-commit-config.yaml`; script takes an optional path for the test
- [ ] State the budget in one AGENTS.md line, with one wording ("at most 200 lines") matching the hook
- [ ] Add a `script_reference.md` row for `check_agents_md_budget.sh`
- [ ] Correct lever 6c to 2 lines (197) when recording the final count

## Checkpoint
**Status**: complete
**When**: 2026-11-02 12:27 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (second plan review verdict ready with five low findings only; proceed is within the checkpoint table; the lows go into the implement handoff)
**After**: plan
**Decision**: proceed

The second plan review (80134dda) approved the plan: the size table sums to the file's 448 lines and lands at 199 (197 with the last lever); the budget hook runs in CI through make lint with no workflow change; the reference set is complete. Five lows for the implementer: the design doc's Instruction layers section drops "proposed" and "Nothing here is built", and OQ-4 is closed as a host decision for owner confirmation, listed in the decision summary; the hook's files pattern also matches the check script and the pre-commit config, and the script takes an optional path for its test; one AGENTS.md line states the budget, worded "at most 200" everywhere; the new script gets a script_reference.md row; the last trim saves 2 lines, so 197.

### Decisions made (owner may veto)
- The AGENTS.md line budget is at most 200 lines, closing OQ-4 — undoing it: the number in the hook and the design doc.
- One AGENTS.md line states that budget, so the design doc's claim that every Rules-table rule is stated in AGENTS.md or the principles stays true — undoing it: drop the line.

## Implementation
**Status**: complete
**When**: 2026-11-02 12:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-259 at `56f8824b`

Implemented the plan as written; the five low findings of the final plan review are taken.

### Sizes (for the PR description)
- `AGENTS.md` before: 448 lines, 33,047 bytes (`wc`, main at 8ac07e28)
- `AGENTS.md` after: 199 lines, 10,513 bytes (`wc`, at 56f8824b)
- Trims used: 6a (adapter table to a two-line list) and 6b (grouped References). 6c (Skill Worktree Exception) was not needed; no rule text was shortened.

### Commits
- `d936b57e` Script Reference moved verbatim to `.agent/knowledge/script_reference.md`; audit-workspace step 3 and its example, and the review guide's script row, repointed; knowledge README indexes it
- `acbc12ab` git-bug-first Pattern moved verbatim to `.agent/knowledge/git_bug_usage.md`; `_issue_helpers.sh` and ADR-0010 repointed (link fix under ADR-0008's Permitted list)
- `03cf10f9` GitHub CLI Patterns moved to `.agent/knowledge/github_cli_patterns.md` (subheadings one level up); Boundaries gains Always "use `gh_create_pr.sh` for PRs" and Never "`gh pr merge --delete-branch` from a worktree"
- `b25cc765` Build & Test details moved to `.agent/knowledge/build_and_test.md`; AGENTS.md keeps a short section naming the config file and `make build`, `make test`, `make lint`, `make validate`
- `05084c82` Worktree Workflow cut to the rule, `--type`, the two types, the sub-issue and skill exceptions and a pointer; Worktree Entry moved verbatim to `.agent/WORKTREE_GUIDE.md` with the `worktree_list.sh` line (the guide already had the other command blocks); `docs/design.md` Worktrees citation and the review guide's worktree row repointed
- `d2e3cb17` Trims 6a and 6b
- `6e123aae` `check_agents_md_budget.sh [<file>]` (exit 0 within budget, 1 over, 2 file missing) and the `agents-md-line-budget` local hook, `files:` matching only `AGENTS.md`, the script and `.pre-commit-config.yaml`, so ordinary commits skip it; `test_agents_md_budget.sh` covers 200 (pass), 201 (fail, count and limit named), 201 without a final newline (fail), missing file (exit 2); the one AGENTS.md budget line ("at most 200 lines"); the script's `script_reference.md` row
- `56f8824b` `docs/design.md`: Instruction layers `proposed` to `decided`, "Nothing here is built" dropped, measured sizes, the budget and the hook; Rules row (`hook`, principle "Only what's needed"); OQ-4 answered; Change log row

### Decisions made (owner may veto)
- The always-loaded budget is at most 200 lines for `AGENTS.md`, closing OQ-4; a host decision recorded for the owner's confirmation at the merge. Undoing it: the number in the hook, the AGENTS.md line and the design doc.
- A new pre-commit hook, `agents-md-line-budget`, holds the budget locally and in CI through `make lint` (no CI workflow change). Undoing it: remove the hook entry, script and suite.

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP: exit 0; every hook passed or had no files, including `validate-script-tests` (every suite, since the branch touches `.pre-commit-config.yaml` and the `_issue_helpers.sh` helper), `check-design-anchors`, `agents-md-line-budget`, shellcheck, yamllint
- Run by hand before the hook commit: `test_agents_md_budget.sh` (4/4), `test_session_start_layer.sh`, `test_skill_paths.sh`, `test_script_tests_hook_scope.sh`: all passed
- `make validate` fails in this worktree only because the worktree has no `project/` symlink (the main checkout's points at an existing directory); it reports no other failure. It was not run from the main checkout.

### Not done or noted
- Issue 323 has not landed on main (checked `origin/main` at 12:20); whichever merges second re-applies its three Script Reference rows, now in `.agent/knowledge/script_reference.md`.
- Kept as existing rule text, not changed: the Worktree Workflow line "`--type` is **required**", which `WORKTREE_GUIDE.md` Quick Start contradicts since #317 (it says `--type` is optional when the cwd decides). Worth a separate fix.
- `docs/design.md` Instruction layers item 3 still says "22 skills"; not re-counted here.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-02 12:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-259 at `c870ceae`
**Base**: main
**Depth**: Deep (reason: 17 files, 1,040 changed lines; AGENTS.md and .pre-commit-config.yaml are override triggers)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 1 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Checked: each moved section diffed against `git show main:AGENTS.md` (Script Reference, git-bug-first, GitHub CLI Patterns, Build & Test identical apart from headings, intro lines and the new budget-script row; Worktree Entry identical in WORKTREE_GUIDE.md, whose existing blocks already held the other worktree commands); repoints in design.md, audit-workspace, the review guide, `_issue_helpers.sh` and ADR-0010 present, no stale AGENTS.md section references found by grep; all nine pinned headings present, `test_session_start_layer.sh` 49/49; `test_agents_md_budget.sh` 4/4; checker exit 0 on the 199-line file; shellcheck clean; the hook's `files:` matches only AGENTS.md, the script and the config; `wc` confirms 199 lines / 10,513 bytes and design.md 860 lines. Cross-model: gemini and codex both completed, no issues.

### Findings
- [ ] (suggestion) The new Never line points to `make merge-pr PR=<N>`, a workspace Makefile target; Boundaries is pinned into project sessions, where the hook's workspace-root note covers `.agent/scripts/...` paths but not make targets — name `.agent/scripts/merge_pr.sh --pr <N>` instead — `AGENTS.md:62`
- [ ] (suggestion) The suite never runs the checker with no argument, the way the hook calls it, so a broken default-path resolution would pass; add a case asserting exit 0 on the repository's AGENTS.md — `.agent/scripts/tests/test_agents_md_budget.sh:57`
- [ ] (suggestion) Hook name `... (issue #259)` is unquoted, so YAML reads ` #259)` as a comment and the name shows as "...(issue" (same as the existing `check-design-anchors` hook); quote it — `.pre-commit-config.yaml:73`
- [ ] (suggestion) OQ-4 row says "the owner approved the #259 trim on 2026-11-02"; the timeline records a go-ahead in principle for the drive with the final approval at the merge; word it as recorded — `docs/design.md:748`

## Checkpoint
**Status**: complete
**When**: 2026-11-02 12:47 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (pre-push review approved, round 1, ship recommended, 0 must-fix; the 4 suggestions stay open on the review entry for triage with the external reviews, per the review-depth rule: a second round only on a must-fix)
**After**: publish
**Decision**: publish

Pre-push review (90b0b854): approved, 0 must-fix, 4 suggestions (the Never line names a make target that project sessions do not have; no test runs the checker with no argument; the hook name's unquoted "#259)" reads as a YAML comment; the OQ-4 row's wording on the owner's approval). Gemini ran, no issues; Codex ran, no issues, read-only so it ran no fixtures; the Claude subagent ran, nothing must-fix. Publishing; the suggestions go to triage.
