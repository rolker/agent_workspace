# Plan: Append review summary to plan file (review accumulator)

## Issue

https://github.com/rolker/agent_workspace/issues/83

## Context

The `review-code` skill produces a structured report in the conversation but
doesn't persist it. The roadmap's "plan as review accumulator" decision says
all review types should append status to the plan file. The plan file already
exists at `.agent/work-plans/issue-<N>/plan.md` and is git-tracked.

The skill currently has 7 steps. Step 7 ("Produce the report") outputs
markdown to the conversation. We need a new step 8 that appends a compact
summary to the plan file.

## Approach

### Step 1: Add step 8 to review-code skill

Add a new step after step 7 in `.claude/skills/review-code/SKILL.md`:

**Step 8: Persist review summary**

After outputting the report to the conversation, locate the plan file for the
reviewed issue. If found, append a structured review block. If not found,
skip with a note in the conversation (not all PRs have plans).

The appended block format:

```markdown
## Review: <tier> — <YYYY-MM-DD>

**PR**: #<N> at `<short-sha>`
**Must-fix**: <count> | **Suggestions**: <count>
**Status**: Pending

### Findings
- [ ] (must-fix) <one-line summary> — `file:line`
- [ ] (suggestion) <one-line summary> — `file:line`
```

Key design points:
- **Locating the plan file**: Use the issue number resolved in step 1. Check
  `.agent/work-plans/issue-<N>/plan.md` in the current repo (workspace or
  project worktree). If the PR targets a project repo but the plan is in the
  workspace, check both.
- **Staleness**: When a new review block is appended and an older block exists,
  mark the older block's status as `Superseded by review on <date>`.
- **No plan file**: Skip with a note in the conversation: "No plan file found
  — review summary not persisted."
- **Checkbox format**: Findings use `- [ ]` so they can be checked off as
  addressed, providing a visible progress indicator.

### Step 2: Update consequences map

Add entry to `principles_review_guide.md`:

| If you change... | Also update... |
|---|---|
| Review accumulator format | `review-code`, `triage-reviews` skills |

### Step 3: Update roadmap

Already done in this branch — #47 marked done, #83 added, #51 deferred.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/review-code/SKILL.md` | Add step 8 (persist review summary) |
| `.agent/knowledge/principles_review_guide.md` | Add consequences map entry |
| `docs/ROADMAP.md` | Already updated in this branch |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Review findings visible in git-tracked plan file; checkbox format shows progress |
| Capture decisions | The review summary persists findings that previously lived only in conversation |
| A change includes its consequences | Consequences map updated; roadmap updated |
| Only what's needed | Minimal change — one new step in one skill, no new tooling |
| Improve incrementally | Small addition that solves a concrete pain (lost review findings) |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 — Project-agnostic | Yes | Plan file format is generic; works for any project |
| 0006 — Shared AGENTS.md | No | No instruction file changes |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `review-code` skill | `review_depth_classification.md`, `cross_model_review.sh` | Not needed — no tier changes |
| Work-plan directory convention | Consuming skills | Not needed — using existing convention |

## Open Questions

- Should `triage-reviews` also append to the plan file? Leaning no for now —
  triage is a read-only assessment of existing comments, not a new review.
  Can add later if useful.

## Estimated Scope

Single PR. Three file changes, one new step in the skill.
