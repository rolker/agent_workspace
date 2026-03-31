# Plan: Lifecycle progress tracking with workflow templates

## Issue

https://github.com/rolker/agent_workspace/issues/88

## Context

The current issue-to-merge workflow has no single artifact tracking what
happened. The plan file captures intent; review summaries (#83) capture one
step's output; but brainstorm decisions, implementation progress, review
cycles, and user testing are scattered across conversation context that
disappears between sessions.

Roland wants a paper trail — one file per issue that shows the full lifecycle.
Different tasks need different workflows (autonomous bugfix vs. collaborative
feature vs. hands-on content creation), distinguished by how involved the
human is, not by what's being built.

## Approach

### 1. Update roadmap

Add #88 to the Coordination track. Annotate #33, #36, #49 as subsumed by #88.
Update the "Storage model" and "Plan as review accumulator" cross-cutting
decisions to reflect the shift from plan-as-accumulator to progress.md.

### 2. Create collaborative workflow template

Create `.agent/workflows/collaborative.md` — the first workflow template.
Defines the steps, their order, who owns each step, and what each step
records in progress.md.

Steps for the collaborative workflow:
- brainstorm (human checkpoint)
- plan (human approves)
- plan-review (agent)
- implement (agent)
- local-review (agent)
- user-testing (human)
- pr (agent)
- external-review (agent triages, human decides)
- merge (human)

The template is a reference document, not executable — skills read it to
understand their role and what's expected before and after them.

### 3. Define progress.md format

Document the format in `.agent/workflows/README.md`:

- **Frontmatter**: `workflow`, `issue` (machine-readable metadata)
- **Top-level heading**: issue number and title
- **Step sections**: appended by skills (or humans) as they run. Each section
  has a heading, status/when/by metadata, and free-form content.
- **No blank sections**: headers appear only when work happens. The workflow
  template defines what's available; progress.md records what occurred.

### 4. Update worktree_create.sh

Add optional `--workflow <name>` flag. When provided:
- Validate the workflow name exists in `.agent/workflows/`
- Create `progress.md` in `.agent/work-plans/issue-N/` with frontmatter
  and a top-level heading (issue number + title from GitHub)
- Default: no workflow, no progress.md (backward compatible)

Update usage text and examples.

## Files to Change

| File | Change |
|------|--------|
| `docs/ROADMAP.md` | Add #88, annotate #33/#36/#49, update cross-cutting decisions |
| `.agent/workflows/collaborative.md` | New: first workflow template |
| `.agent/workflows/README.md` | New: progress.md format spec |
| `.agent/scripts/worktree_create.sh` | Add `--workflow` flag, initialize progress.md |

## Not in Scope

- Updating individual skills to append to progress.md (incremental follow-ups)
- Other workflow templates (autonomous, guided, direct — added when needed)
- Migrating #83's review-in-plan to progress.md (future evolution)
- Enforcement or validation that steps run in order

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Roadmap, format spec, and script updated together |
| Only what's needed | One workflow template, not four. Optional flag, not required. |
| Improve incrementally | Lays foundation; skills adopt progress.md one at a time |
| Capture decisions, not just implementations | Format spec and workflow README explain the why |
| Workspace vs. project separation | Workflow templates are project-agnostic |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Add `--workflow` to worktree_create.sh | Usage text, AGENTS.md examples | Yes (usage text); AGENTS.md deferred until workflow is proven |
| Add `.agent/workflows/` directory | .gitignore check (should be tracked) | Yes |
| Shift from plan-as-accumulator to progress.md | Roadmap cross-cutting decisions | Yes |

## Open Questions

1. Should `--workflow` eventually become required (with a default), or stay
   optional indefinitely? Start optional, revisit after adoption.

---
**Authored-By**: `Claude Code Agent`
**Model**: `claude-opus-4-6`
