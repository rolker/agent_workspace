# Plan: ROADMAP.md, /what-next skill, and merge-time roadmap check

## Issue

https://github.com/rolker/agent_workspace/issues/121

## Context

The workspace has `docs/ROADMAP.md` (workspace-wide roadmap). The project
already has `project/ROADMAP.md` (phase checklists with issue references)
and `project/DESIGN.md` already links to it. Nothing enforces roadmap
updates when work completes, and agents don't consult it when choosing work.

Decisions from user input:
- `/what-next` uses roadmap checklist only (no labels/milestones)
- Merge-time check is a soft reminder, not a hard gate
- ROADMAP.md uses phase grouping with checklists, no dates

## Approach

This is two PRs, sequenced as sub-issues of #121. (Sub-issue A from the
original plan — creating project ROADMAP.md — is already complete:
`project/ROADMAP.md` exists with phase checklists and `project/DESIGN.md`
already links to it.)

### Sub-issue A: `/what-next` skill

1. **Create `.claude/skills/what-next/SKILL.md`** — A skill that:
   - Reads `ROADMAP.md` from both workspace (`docs/ROADMAP.md`) and project
     (`project/ROADMAP.md`)
   - Lists unchecked items grouped by phase
   - Cross-references against `gh issue list` to find:
     - Completed items not yet checked off (staleness)
     - Unchecked items without issues (need tickets)
     - Items with open issues ready to start
   - Suggests next work based on phase ordering (earlier phases first,
     items with existing issues preferred over items needing new tickets)

2. **Register the skill** — Run `make generate-skills` if needed, or
   manually create the skill directory.

**Files**: `.claude/skills/what-next/SKILL.md` (new)
**Repo**: workspace (agent_workspace)

### Sub-issue B: Merge-time roadmap reminder

1. **Add roadmap check to `merge_pr.sh`** — After the successful merge
   and sync steps (around line 168), grep the closed issue title against
   both `docs/ROADMAP.md` and `project/ROADMAP.md` (if it exists). If a
   match is found, print a reminder:
   ```
   NOTE: This PR may relate to a roadmap item. Consider updating:
     docs/ROADMAP.md or project/ROADMAP.md
   ```
   This is informational only — not a gate.

2. **Resolve the issue title** — `merge_pr.sh` does not currently have
   `$ISSUE_TITLE`. Add a step to fetch it via
   `gh issue view "$ISSUE_NUM" --json title --jq '.title'` (the issue
   number is already resolved in the script).

3. **Match strategy** — Grep the issue title keywords against ROADMAP.md
   lines. Fuzzy enough to catch relevant items, but not so aggressive it
   fires on every merge. Guard the grep with a file-existence check so
   the reminder is a no-op when no ROADMAP.md exists (ADR-0003 compliance).

**Files**: `.agent/scripts/merge_pr.sh` (edit)
**Repo**: workspace (agent_workspace)

## Files to Change

| File | Change | Sub-issue |
|------|--------|-----------|
| `.claude/skills/what-next/SKILL.md` | New skill: roadmap cross-reference and next-work suggestions | A |
| `.agent/scripts/merge_pr.sh` | Add issue title resolution + soft roadmap reminder after merge | B |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Soft reminder, not hard gate. Skill reads existing files, no new infrastructure |
| A change includes its consequences | merge_pr.sh change is self-contained; skill is additive |
| Workspace vs. project separation | Skill and merge check are workspace; they read project ROADMAP.md conditionally |
| Improve incrementally | Two small PRs rather than one large one |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0003 | Yes | `/what-next` skill and merge check are project-agnostic (work with any project that has ROADMAP.md) |
| ADR-0006 | No | No instruction file changes |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Add new skill | Skill list in adapters if enumerated | Checked — skill lists are auto-generated or not enumerated |
| `merge_pr.sh` | AGENTS.md script table if description changes | No change needed — description stays generic |

## Open Questions

None.

## Estimated Scope

Two sub-issue PRs:
- A: `/what-next` skill (~medium, workspace repo)
- B: merge-time reminder (~small, workspace repo)
