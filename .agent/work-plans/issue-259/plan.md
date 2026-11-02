# Plan: Trim AGENTS.md to policy + pointers; move reference tables to .agent/knowledge/

## Issue

https://github.com/rolker/agent_workspace/issues/259

## Context

Measured 2026-11-02 (`wc`, `awk` on `AGENTS.md`): 448 lines, 33,047 bytes (the body says 418 / 18.5 KB). Sections, in lines:
Terminology 22, Boundaries 33, Communication Standards 8, Quality Standard 24, Tool Usage 14, Worktree Workflow 80 (incl. Worktree Entry), Issue-First Policy 25 (incl. Skill Worktree Exception), AI Signature 10, GitHub CLI Patterns 101 (incl. git-bug-first Pattern, 24), Build & Test 28, Verify Before Claiming 11 (the body calls it "Documentation Accuracy"), Workspace Cleanliness 6, Post-Task Verification 12, Script Reference 51, References 10, plus 13 lines of preamble and adapter table.

Decided with the host (Checkpoint entry): target under 200 lines (OQ-4's reference point), aiming for ~150 where natural; Script Reference moves verbatim, no drift check; size check only if tiny. Issue 252 is closed, so there is no dependency.

## Approach

Five section moves, one commit each, then the design-doc commit. After every commit AGENTS.md holds a pointer "See `.agent/knowledge/<file>.md`", and `make validate` and pre-commit pass.

1. **Script Reference** -> `.agent/knowledge/script_reference.md` (verbatim table and the two intro lines, with a title and a one-line "add a row when you add a script" note). Pointer in AGENTS.md (~4 lines). Repoint `.claude/skills/audit-workspace/SKILL.md` step 3 (line 75) and `principles_review_guide.md` line 63 to the new file. Add the file to `.agent/knowledge/README.md` index.
2. **git-bug-first Pattern** (lines 281-304) -> `.agent/knowledge/git_bug_usage.md` verbatim. Repoint `_issue_helpers.sh` line 15 and ADR-0010 line 69 to it. ADR-0010 is an accepted ADR ("history, not edited", docs/design.md decision register); only this pointer line is changed, at the host's instruction. Flagged in Open Questions.
3. **GitHub CLI Patterns** (PR wrapper, `--body-file`, never guess URLs, scratchpad repo targeting, merging from worktrees) -> `.agent/knowledge/github_cli_patterns.md`. Boundaries already carries the wrapper-adjacent rules (`--body-file`, never construct URLs, no `--no-verify`); add the third hard rule "never `gh pr merge --delete-branch` from a worktree" to Never, and "use `gh_create_pr.sh` for PRs" to Always. Pointer section ~6 lines. The pinned Boundaries section is what project sessions see, so those rules reach them.
4. **Build & Test** -> `.agent/knowledge/build_and_test.md` (config block, adapter paragraph, ADR-0011). AGENTS.md keeps the six `make` targets and the pointer (~9 lines).
5. **Worktree Workflow**: keep the "isolated worktree, `--type` required, two types" rule, the sub-issue and skill exceptions in prose, and a pointer to `.agent/WORKTREE_GUIDE.md`. Move the command blocks and "Worktree Entry" (cd-not-EnterWorktree rationale, exit/delete) to `.agent/WORKTREE_GUIDE.md` (check it first; add only what it lacks, no duplication). Target ~20 lines. The `/start-task` note in CLAUDE.md already covers entry for Claude.
6. **Measure and close the gap.** Expected after 1-5: about 205-210 lines, so not yet under 200. Fallback levers, in this order, none touching a rule: condense Skill Worktree Exception (12 lines) to the allowlist sentence plus a WORKTREE_GUIDE pointer; collapse the adapter table in the preamble to a one-line list; trim References to entries not repeated above. Record final lines and bytes. If still over 200, stop and ask (see Open Questions).
7. **Size check**: add ~6 lines to `validate_workspace.py` (`validate_workspace()`, appended to `issues`) failing when `AGENTS.md` exceeds 200 lines, with the number named in the message. `make validate` runs it. No new hook, no new test suite.
8. **Design doc** (own commit, ADR-0017): `docs/design.md#instruction-layers` figures (442 lines / 26,564 bytes -> new), status wording, the budget sentence now set at under 200 lines and where the check lives; close OQ-4 (line 743); add a Change log row (line ~771 style). Also the Sessions and roots mention of nine pinned headings stays true; verify.

## Pinned headings and tests that read AGENTS.md

The SessionStart hook pins nine headings (`.claude/hooks/session_start_project_layer.sh` `WORKSPACE_SECTIONS`; `test_session_start_layer.sh` line 76 asserts each exists, non-empty): Boundaries; Communication Standards; Quality Standard; Tool Usage; Issue-First Policy; AI Signature (Required on all GitHub Issues/PRs/Comments); Verify Before Claiming; Workspace Cleanliness; Post-Task Verification. None of the moved sections (Worktree Workflow, GitHub CLI Patterns, Build & Test, Script Reference) is pinned; all nine headings stay verbatim and in place. Boundaries, Issue-First and the others grow only by the two rule lines above, and the extractor stops at the next `## `, so keep "Skill Worktree Exception" a `###` inside Issue-First.

Checked, each with its fix:
- `test_session_start_layer.sh`: pinned headings only; no change, run it.
- `test_skill_paths.sh` guard (c): git-greps AGENTS.md for pointers to the retired what-next skill; confirm moved text did not carry one (run it).
- `test_issue_review_entry.sh` line 68: fixture text "Update the script table row in AGENTS.md"; fixture only, no change.
- `.pre-commit-config.yaml` line 89 and `run_script_tests.sh`: AGENTS.md is in scope, new `.agent/knowledge/*.md` files are too; run the full pre-commit once with `.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`.
- `validate.yml` "Validate Documentation": only checks that AGENTS.md exists.
- `validate_workspace.py`: reads no AGENTS.md headings or table rows today (grep), other than the new check in step 7.
- `audit-workspace` SKILL.md and `principles_review_guide.md`: prose pointers, repointed (steps 1).
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
| `.claude/skills/audit-workspace/SKILL.md`, `.agent/knowledge/principles_review_guide.md` | Repoint script-table references |
| `.agent/scripts/validate_workspace.py` | AGENTS.md line-budget check |
| `docs/design.md` | Instruction layers, OQ-4, Change log row |

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
| Enforcement over prose | Line-budget check in `make validate` |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0010 git-bug optional | Yes | Stays the decision record; one pointer line repointed |
| 0011 adapter | Yes | Cited from build_and_test.md, text unchanged |
| 0016 session layer | Yes | Nine pinned headings kept verbatim |
| 0017 design doc current | Yes | Step 8 |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Script Reference location | audit-workspace step 3, principles_review_guide line 63, knowledge README | Yes |
| git-bug section | `_issue_helpers.sh`, ADR-0010 | Yes |
| AGENTS.md size | design.md, validator | Yes |
| Script table rows | Issue 323 (parallel) | Rebase, below |

Issue 323 touches three Script Reference rows: `worktree_create.sh` (AGENTS.md line 400, behaviour: skill/issue worktrees branch from the default branch), `gh_create_issue.sh` (line 416, row exists today; adds the signature injection and `--no-signature`), and `merge_pr.sh` (line 419, CI-target wording). Whichever merges second rebases: if 323 lands first, step 1 takes its rows as they stand then; if this lands first, 323's row edits are re-applied to `.agent/knowledge/script_reference.md`. Do the rebase check before the step 1 commit and again before publish. 323 may also touch line 313 prose ("`gh_create_issue.sh` enforces..."), which moves in step 3.

## Open Questions

- ADR-0010 is an accepted ADR; editing its pointer line departs from "ADRs are history". Done at the host's instruction, as a one-line pointer fix.
- If the fallback levers do not reach under 200, which rule text may be condensed (the budget is the owner's call)?

## Estimated Scope

Single PR, seven atomic commits.
