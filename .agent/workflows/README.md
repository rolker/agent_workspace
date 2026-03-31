# Workflow Templates and Progress Tracking

## Overview

Workflow templates define the steps available for different task types,
distinguished by how involved the human is. The `progress.md` file tracks
what actually happened during an issue's lifecycle.

```
.agent/work-plans/issue-N/
  plan.md        # what we're going to do (stable reference)
  progress.md    # what actually happened (append-only log)
```

## Workflow Types

Templates live in `.agent/workflows/<name>.md`. Each defines the available
steps, who owns them, and when to use that workflow.

| Workflow | Human involvement | When to use |
|----------|------------------|-------------|
| `collaborative` | Key checkpoints (brainstorm, plan, testing) | Features, design work, judgment-heavy tasks |
| `autonomous` | Reviews the PR at the end | Bugfixes, doc updates, clear-cut implementation |
| `guided` | Drives the work, agent assists | Exploration, learning, interactive iteration |
| `direct` | Does the work, agent handles bookkeeping | Content creation, quick changes, minimal review |

Only `collaborative` is defined initially. Others will be added as usage
patterns emerge.

## progress.md Format

### Frontmatter

```yaml
---
workflow: collaborative
issue: 88
---
```

- `workflow`: name of the workflow template (matches a file in `.agent/workflows/`)
- `issue`: GitHub issue number

### Top-level heading

```markdown
# Issue #88 — Lifecycle progress tracking with workflow templates
```

Created by `worktree_create.sh` when `--workflow` is provided.

### Step sections

Each step appends a section when it runs. No blank sections — headers appear
only when work actually happens.

```markdown
## Brainstorm
**Status**: complete
**When**: 2026-03-30 16:00
**By**: Roland + Claude Code (claude-opus-4-6)

Key decisions from the brainstorm session...

## Plan
**Status**: complete
**When**: 2026-03-30 17:00
**By**: Claude Code (claude-opus-4-6)
**Approved by**: Roland

Committed as .agent/work-plans/issue-88/plan.md

## Implement
**Status**: in-progress
**When**: 2026-03-30 18:00
**By**: Claude Code (claude-opus-4-6)

- [x] Update roadmap
- [ ] Create workflow templates
```

### Step metadata fields

| Field | Required | Description |
|-------|----------|-------------|
| **Status** | yes | `complete`, `in-progress`, `skipped`, `blocked` |
| **When** | yes | Date/time the step started or completed |
| **By** | yes | Who performed it (human name, agent name + model) |
| **Approved by** | when applicable | For steps requiring human approval |

### Content

Free-form markdown after the metadata. Can include:
- Decisions made and rationale
- Links to artifacts (commits, PRs, plan files)
- Checklists for multi-part steps
- Notes from human testing
- Review findings and dispositions

### Who writes entries

- **Skills** append their section when they run (brainstorm, plan-task,
  review-code, triage-reviews, etc.)
- **Humans** can write entries directly (e.g., user-testing notes)
- **worktree_create.sh** creates the file with frontmatter and heading

### Extensibility

Workflow templates define their own step vocabulary. The steps listed in
`collaborative.md` are the default for software development. Other workflows
(hardware setup, content creation, research) can define different steps.
progress.md imposes no fixed schema on step names.
