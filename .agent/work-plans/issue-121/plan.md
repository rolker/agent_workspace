# Plan: ROADMAP.md, /what-next skill, and merge-time roadmap check

## Issue

https://github.com/rolker/agent_workspace/issues/121

## Context

The workspace has `docs/ROADMAP.md` (UX improvements roadmap). The project
has phases in `DESIGN.md` but no standalone `ROADMAP.md`. Nothing enforces
roadmap updates when work completes, and agents don't consult it when
choosing work.

Decisions from user input:
- `/what-next` uses roadmap checklist only (no labels/milestones)
- Merge-time check is a soft reminder, not a hard gate
- ROADMAP.md uses phase grouping with checklists, no dates

## Approach

This is three PRs, sequenced as sub-issues of #121.

### Sub-issue A: Project ROADMAP.md

1. **Create `project/ROADMAP.md`** — Extract the Phases checklist from
   `project/DESIGN.md` (lines 833-909) into a standalone file. Group by
   phase with `- [x]`/`- [ ]` checklists. Include issue references where
   they exist (e.g., "PR #38", "PR #42").

2. **Update `project/DESIGN.md`** — Replace the inline Phases checklist
   with a link: "See [ROADMAP.md](ROADMAP.md) for the current phase
   checklist." Keep the narrative context (phase descriptions) in DESIGN.md.

3. **No changes to workspace `docs/ROADMAP.md`** — It already exists and
   is maintained through brainstorm sessions.

**Files**: `project/ROADMAP.md` (new), `project/DESIGN.md` (edit)
**Repo**: project (daddy_camp)

### Sub-issue B: `/what-next` skill

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

### Sub-issue C: Merge-time roadmap reminder

1. **Add roadmap check to `merge_pr.sh`** — After the successful merge
   and sync steps (around line 168), grep the closed issue title against
   both `docs/ROADMAP.md` and `project/ROADMAP.md` (if it exists). If a
   match is found, print a reminder:
   ```
   NOTE: This PR may relate to a roadmap item. Consider updating:
     docs/ROADMAP.md or project/ROADMAP.md
   ```
   This is informational only — not a gate.

2. **Match strategy** — Use the PR's linked issue title (already resolved
   earlier in the script as `$ISSUE_TITLE`) and grep for keywords against
   ROADMAP.md lines. Fuzzy enough to catch relevant items, but not so
   aggressive it fires on every merge.

**Files**: `.agent/scripts/merge_pr.sh` (edit)
**Repo**: workspace (agent_workspace)

## Files to Change

| File | Change | Sub-issue |
|------|--------|-----------|
| `project/ROADMAP.md` | New file: phase checklist extracted from DESIGN.md | A |
| `project/DESIGN.md` | Replace Phases section with link to ROADMAP.md | A |
| `.claude/skills/what-next/SKILL.md` | New skill: roadmap cross-reference and next-work suggestions | B |
| `.agent/scripts/merge_pr.sh` | Add soft roadmap reminder after merge | C |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Soft reminder, not hard gate. Skill reads existing files, no new infrastructure |
| A change includes its consequences | DESIGN.md updated when Phases moves to ROADMAP.md |
| Workspace vs. project separation | Project ROADMAP lives in project repo; skill and merge check are workspace |
| Improve incrementally | Three small PRs rather than one large one |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0003 | Yes | `/what-next` skill and merge check are project-agnostic (work with any project that has ROADMAP.md) |
| ADR-0006 | No | No instruction file changes |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `project/DESIGN.md` (remove Phases) | `project/ROADMAP.md` (must exist first) | Yes |
| Add new skill | Skill list in adapters if enumerated | Checked — skill lists are auto-generated or not enumerated |
| `merge_pr.sh` | AGENTS.md script table if description changes | No change needed — description stays generic |

## Open Questions

None.

## Estimated Scope

Three sub-issue PRs:
- A: project ROADMAP.md (~small, project repo)
- B: `/what-next` skill (~medium, workspace repo)
- C: merge-time reminder (~small, workspace repo)
