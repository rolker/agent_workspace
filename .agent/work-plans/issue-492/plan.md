# Plan: "product" vs "project" in AGENTS.md, and a status note on four ADRs

## Issue

https://github.com/rolker/agent_workspace/issues/492

## Context

Follow-up to issue 265 part 4 (PR 491). AGENTS.md says "product" twice where it means the project, and four ADRs still describe shapes that part 4 retired. The owner approved the exact wording on 2026-11-17 ("yes to both"). The wording below is quoted from the issue body and is not to be improved.

## Approach

1. **AGENTS.md, one commit.** Line 10: replace "the managed product, any folder" with "what is being built: any folder". Line 29 (table row): replace "The product being built (its registered folder)" with "The project's own files (its registered folder)". Line count stays 200: the new line 10 is shorter than the old, so the Project bullet keeps its three lines and nothing is reflowed. Result:
   `- **Project**: what is being built: any folder registered with the workspace (`register_project.sh`),`
   `  wherever it lives. A hosting service is optional; git is meant to be, but registration still needs it.`
   `  Features, deployment and user-facing behavior are project scope.`
2. **Four ADRs, one commit.** Under the existing text of each `## Status` section, add a blank line and the note as its own paragraph (decision text is not edited):
   - ADR-0002: "Note (2026-11-17): the `worktrees/project/<repo>/` location named below is retired; a project's worktrees live under its registered root (issue #265 part 4)."
   - ADR-0003: "Note (2026-11-17): the `project/` directory in the reusability test is retired; a project is any registered folder (issue #265 part 4)."
   - ADR-0011: "Note (2026-11-17): the `project/` location and `.agent/project_config.sh` named below are retired; the type and commands come from the registry and the project's settings file (issue #265 part 4)."
   - ADR-0018: "Note (2026-11-17): the 'legacy unregistered `project/`' exception in decision 6 no longer exists; the fallback was removed (issue #265 part 4)." One note under Status covers both places that carry the retired wording (decision 6, about line 261, and the Consequences list, about line 304); neither is edited.
3. **Verify.** `grep -n -i product AGENTS.md` finds nothing; `wc -l AGENTS.md` is 200; `check_agents_md_budget.sh`, `check_design_anchors.sh` and `test_skill_paths.sh` pass; `git diff --stat` shows only AGENTS.md and the four ADRs.
4. **PR** body says `Closes #492`.

## Files to Change

| File | Change |
|------|--------|
| `AGENTS.md` | Two phrases (lines 10 and 29) |
| `docs/decisions/0002-worktree-isolation-over-branch-switching.md` | Status note |
| `docs/decisions/0003-workspace-infrastructure-is-project-agnostic.md` | Status note |
| `docs/decisions/0011-project-type-adapter-contract.md` | Status note |
| `docs/decisions/0018-plugin-based-skill-delivery.md` | Status note |

## Prior Art

Nothing new is built. ADR-0008 already permits addendums to Accepted ADRs; ADR-0018 and ADR-0011 Status sections already carry dated supersession and amendment paragraphs in this form.

## Serves

Trust and information goals ("Trust, control and information"): rules and records that match the current system. Design section: `docs/design.md#documentation-layers`.

## Design Picture

No change to the design picture. Part 4's design-document changes already landed in PR 491.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Verify before claiming | Notes restate what PR 491 retired, owner-approved text; no new claims. |
| Atomic commits | One commit per logical change (AGENTS.md; the ADR notes). |
| Ask First | AGENTS.md and ADR edits are covered by the owner's "yes to both", for this text only. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0002, 0003, 0011, 0018 | Yes | Status-note edits only; decision text untouched. |
| 0008 | Yes | Permits addendums in Accepted ADRs; no new ADR is created. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| AGENTS.md | `agents-md-line-budget` hook (`check_agents_md_budget.sh`, limit 200) | Checked: stays 200 lines |
| AGENTS.md | `test_skill_paths.sh` scans AGENTS.md for old skill paths | Checked: it pins no phrase being changed |
| ADR text | `check_design_anchors.sh` | Checked: reads anchors, not these phrases |
| The changed phrases | Any other file quoting them | Searched: only the old work plans and progress files of issues 265 and 295 (history, left alone) |

## Open Questions

None.

## Estimated Scope

Single PR, five files, two commits.
