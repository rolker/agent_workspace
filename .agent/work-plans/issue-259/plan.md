# Plan: Trim AGENTS.md to policy + pointers; move reference tables to .agent/knowledge/

## Issue

https://github.com/rolker/agent_workspace/issues/259

## Context

Measured 2026-11-02 (`wc`, `awk` on `AGENTS.md`): 448 lines, 33,047 bytes (the body says 418 / 18.5 KB). Sections, in lines:
Terminology 22, Boundaries 33, Communication Standards 8, Quality Standard 24, Tool Usage 14, Worktree Workflow 80 (incl. Worktree Entry), Issue-First Policy 25 (incl. Skill Worktree Exception), AI Signature 10, GitHub CLI Patterns 101 (incl. git-bug-first Pattern, 24), Build & Test 28, Verify Before Claiming 11 (the body calls it "Documentation Accuracy"), Workspace Cleanliness 6, Post-Task Verification 12, Script Reference 51, References 10, plus 13 lines of preamble and adapter table.

Decided with the host (Checkpoint entry): target under 200 lines (OQ-4's reference point), aiming for ~150 where natural; Script Reference moves verbatim, no drift check; size check only if tiny. Issue 252 is closed, so there is no dependency.

## Approach

Five section moves, one commit each, then the budget hook, then the design-doc commit. After every commit `make validate` and pre-commit pass. AGENTS.md ends with one pointer list (in the existing References section) instead of a new section per moved topic.

1. **Script Reference** -> `.agent/knowledge/script_reference.md` (verbatim table and two intro lines, title, one-line "add a row when you add a script" note). Repoint `.claude/skills/audit-workspace/SKILL.md` line 75 (step 3) and line 159 (the "AGENTS.md script table lists ..." example), and `principles_review_guide.md` line 63, to the new file. Index it in `.agent/knowledge/README.md`.
2. **git-bug-first Pattern** (lines 281-304) -> `.agent/knowledge/git_bug_usage.md` verbatim. Repoint `_issue_helpers.sh` line 15 and ADR-0010 line 69. The ADR-0010 edit is a link fix, permitted by ADR-0008's Permitted list ("fixing broken links ... that don't change meaning"), which ADR-0017 excepts from "accepted ADRs are history"; precedent commit 9ad62671 (ADR-0014 reference made a pointer only).
3. **GitHub CLI Patterns** -> `.agent/knowledge/github_cli_patterns.md` (PR wrapper, `--body-file`, never guess URLs, scratchpad repo targeting, merging from worktrees). Boundaries gets two lines: Always "use `gh_create_pr.sh` for PRs", Never "`gh pr merge --delete-branch` from a worktree". Both reach project sessions through the pinned Boundaries section.
4. **Build & Test** -> `.agent/knowledge/build_and_test.md` (config block, adapter paragraph, ADR-0011). AGENTS.md keeps a 6-line section naming the four targets the issue lists (`make build`, `make test`, `make lint`, `make validate`) and the config file.
5. **Worktree Workflow**: keep an 8-line section (isolated worktree rule, `--type` required, two types, sub-issue and skill exceptions in prose, WORKTREE_GUIDE pointer). Move the command blocks and "Worktree Entry" (cd-not-EnterWorktree rationale, exit/delete) to `.agent/WORKTREE_GUIDE.md`, adding only what it lacks (check it first). Repoint `docs/design.md` line 427 (cites AGENTS.md "Worktree Entry") to WORKTREE_GUIDE, and reword `principles_review_guide.md` line 69 to name WORKTREE_GUIDE as the home of the command blocks.
6. **Fallback trims, none touching rule text, applied in this order and only as the measurement needs**: (a) preamble adapter table -> a two-line list; (b) References: group the repeated doc links into three bullets beside the four pointers; (c) last resort, pinned: Skill Worktree Exception, join "Branch naming" and "All other rules" into one line, keeping the onboard-project sentence and the allowlist. Record final lines and bytes after the trim. Condensing any rule text beyond (c) is the one case to stop and ask.
7. **Line-budget hook**: new `.agent/scripts/check_agents_md_budget.sh` (about 12 lines: counts `AGENTS.md` lines, exits 1 naming the count and the 200 limit) and a `.pre-commit-config.yaml` local hook `agents-md-line-budget` (`language: system`, `files: ^AGENTS\.md$`, `pass_filenames: false`). It runs locally and in CI through `make lint` with no change to the CI workflow (Ask First). Test `.agent/scripts/tests/test_agents_md_budget.sh` (`chmod +x`): passes at 200 lines, fails at 201 with the count in the message, errors on a missing file; runs under `run_script_tests.sh`. Not in `validate_workspace.py`, which runs in no gate.
8. **Design doc** (own commit, ADR-0017): `docs/design.md#instruction-layers` figures (442 lines / 26,564 bytes -> measured new), the budget sentence (under 200 lines, enforced by the hook); close OQ-4 (line 743); a Rules-table row (`docs/design.md#rules`, line ~153 columns Rule / Principle or ADR / Enforced by / The check): rule "AGENTS.md stays under 200 lines", principle "Only what's needed", enforced by pre-commit hook `agents-md-line-budget` (and CI via `make lint`); the line-427 repoint; a Change log row (line ~771 style). Verify the nine-pinned-headings mention stays true.

## Size arithmetic

Baseline 448 lines (section lines as measured in Context; they sum to 448). After each move, the section's new size:

| Section | Now | After | Note |
|---|---|---|---|
| Preamble + adapter table | 13 | 8 | lever 6a |
| Terminology | 22 | 22 | |
| Boundaries (pinned) | 33 | 35 | two CLI rules |
| Communication, Quality, Tool Usage (pinned) | 8+24+14 | 46 | |
| Worktree Workflow | 80 | 8 | step 5 |
| Issue-First (pinned) | 25 | 25 | 22 only with lever 6c |
| AI Signature (pinned) | 10 | 10 | |
| GitHub CLI Patterns | 101 | 0 | in the pointer list |
| Build & Test | 28 | 6 | step 4 |
| Verify, Cleanliness, Post-Task (pinned) | 11+6+12 | 29 | |
| Script Reference | 51 | 0 | in the pointer list |
| References | 10 | 10 | grouped docs 3 + 4 pointers + heading, blank, trailing blank |

Sum: 8+22+35+46+8+25+10+6+29+10 = 199 with the above levers 6a and 6b; with 6c, 196. The reviewer's no-lever estimate (about 229, about 209 with the old fallbacks) is reproduced by this table when the four pointer sections, six make targets and 20-line worktree section are put back (+4 sections of ~4 lines, +2, +12 = about +30 vs 199). These are estimates: the real count is taken after the trim and written to the progress entry; the hook enforces under 201 lines (limit 200).

## Pinned headings and tests that read AGENTS.md

The SessionStart hook pins nine headings (`.claude/hooks/session_start_project_layer.sh` `WORKSPACE_SECTIONS`; `test_session_start_layer.sh` line 76 asserts each exists, non-empty): Boundaries; Communication Standards; Quality Standard; Tool Usage; Issue-First Policy; AI Signature (Required on all GitHub Issues/PRs/Comments); Verify Before Claiming; Workspace Cleanliness; Post-Task Verification. None of the moved sections (Worktree Workflow, GitHub CLI Patterns, Build & Test, Script Reference) is pinned; all nine headings stay verbatim and in place. Boundaries, Issue-First and the others grow only by the two rule lines above, and the extractor stops at the next `## `, so keep "Skill Worktree Exception" a `###` inside Issue-First.

Checked, each with its fix:
- `test_session_start_layer.sh`: pinned headings only; no change, run it.
- `test_skill_paths.sh` guard (c): git-greps AGENTS.md for pointers to the retired what-next skill; confirm moved text did not carry one (run it).
- `test_issue_review_entry.sh` line 68: fixture text "Update the script table row in AGENTS.md"; fixture only, no change.
- `.pre-commit-config.yaml` line 89 and `run_script_tests.sh`: AGENTS.md is in scope, new `.agent/knowledge/*.md` files are too; run the full pre-commit once with `.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`.
- `validate.yml` "Validate Documentation": only checks that AGENTS.md exists.
- `validate_workspace.py`: reads no AGENTS.md headings or table rows today (grep); not changed.
- `audit-workspace` SKILL.md and `principles_review_guide.md`: prose pointers, repointed (step 1).
- Adapter files (CLAUDE.md, CODEX.md, `.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`): grep shows links to AGENTS.md as a whole, no heading anchors and none into moved sections; no change. CLAUDE.md `@AGENTS.md` import keeps working.
- ADR-0016 lines 192, 247 mention #259 keeping rendered headings: satisfied.

## Files to Change

| File | Change |
|------|--------|
| `AGENTS.md` | Trim to under 200 lines; pointers; two Boundaries lines |
| `.agent/knowledge/script_reference.md`, `git_bug_usage.md`, `github_cli_patterns.md`, `build_and_test.md` | New, moved text verbatim |
| `.agent/WORKTREE_GUIDE.md` | Receives command blocks and Worktree Entry if missing |
| `.agent/knowledge/README.md` | Index the four new files |
| `.agent/scripts/_issue_helpers.sh`, `docs/decisions/0010-git-bug-is-optional.md` | Repoint "git-bug-first Pattern" citation |
| `.claude/skills/audit-workspace/SKILL.md` (lines 75, 159), `.agent/knowledge/principles_review_guide.md` (lines 63, 69) | Repoint script-table and worktree references |
| `.agent/scripts/check_agents_md_budget.sh`, `.agent/scripts/tests/test_agents_md_budget.sh`, `.pre-commit-config.yaml` | Line-budget hook, its test, hook entry |
| `docs/design.md` | Instruction layers, OQ-4, Rules-table row, line 427 repoint, Change log row |

## Prior Art

Nothing new built. The vendor guidance (under 200 lines per instruction file) is already recorded in docs/design.md; the fork's rolker/ros2_agent_workspace#564 is the same trim; wording is kept close to the existing sections so the later merge is easier. The `References (Read When Needed)` section is the existing pointer pattern reused.

## Serves

Goal "Know whether it works" (keeping the always-loaded instructions lean), `docs/design.md#instruction-layers`.

## Design Picture

Alters the instruction-layers section: size figures, budget now set, OQ-4 closed, Change log row. Updated in the same PR (step 8, ADR-0017).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Reference tables leave the always-loaded layer |
| Keep one current design | design.md updated in the PR |
| Verify before claiming | Sizes re-measured; final numbers measured after the trim, not estimated |
| Put each thing at the level it applies to | Reference to knowledge files, rules stay |
| Enforcement over prose | Line-budget pre-commit hook, run in CI by `make lint`, with a test |
| Test what breaks | Hook test covers 200, 201 and missing file |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0010 git-bug optional | Yes | Stays the decision record; one pointer line repointed |
| 0008 (Permitted list) | Yes | Authority for the ADR-0010 link fix; 0017 excepts it |
| 0011 adapter | Yes | Cited from build_and_test.md, text unchanged |
| 0016 session layer | Yes | Nine pinned headings kept verbatim |
| 0017 design doc current | Yes | Step 8 |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Script Reference location | audit-workspace step 3, principles_review_guide line 63, knowledge README | Yes |
| git-bug section | `_issue_helpers.sh`, ADR-0010 | Yes |
| AGENTS.md size | design.md (figures, Rules row), budget hook and test | Yes |
| Script table rows | Issue 323 (parallel) | Rebase, below |

Issue 323 touches three Script Reference rows: `worktree_create.sh` (AGENTS.md line 400, behaviour: skill/issue worktrees branch from the default branch), `gh_create_issue.sh` (line 416, row exists today; adds the signature injection and `--no-signature`), and `merge_pr.sh` (line 419, CI-target wording). Whichever merges second rebases: if 323 lands first, step 1 takes its rows as they stand then; if this lands first, 323's row edits are re-applied to `.agent/knowledge/script_reference.md`. Do the rebase check before the step 1 commit and again before publish. 323 may also touch line 313 prose ("`gh_create_issue.sh` enforces..."), which moves in step 3.

## Open Questions

- Only if the levers in step 6 do not reach under 200 without condensing rule text: which rule text may be condensed (the budget is the owner's call).

## Estimated Scope

Single PR, eight atomic commits (five moves, budget hook, design doc; repoints ride with their moves).
