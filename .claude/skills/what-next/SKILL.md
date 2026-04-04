---
name: what-next
description: Read ROADMAP.md files, cross-reference with GitHub issues, detect staleness, and suggest prioritized next work.
---

# What Next

## Usage

```
/what-next [--workspace-only] [--project-only]
```

Without flags, checks both workspace and project roadmaps.

## Overview

**Lifecycle position**: Utility — run when choosing what to work on next.

Reads `ROADMAP.md` from the workspace and project repos, cross-references
checklist items against GitHub issues, and surfaces:
- Completed items not yet checked off (staleness)
- Unchecked items without issues (work needing tickets)
- Items with open issues ready to start
- A prioritized suggestion for next work

## Steps

### 1. Locate roadmap files

Check for roadmaps in both repos:

- **Workspace**: `docs/ROADMAP.md`
- **Project**: `project/ROADMAP.md`

If a file doesn't exist, skip that repo (don't error). If neither exists,
report "No ROADMAP.md found in workspace or project" and stop.

If `--workspace-only` or `--project-only` was specified, check only that repo.

### 2. Parse roadmap checklists

Read each ROADMAP.md and extract checklist items. Two formats are supported:

**Simple checklists** (project style):
```markdown
## Phase 2 — Interactions & Core Loop (next)

- [x] Phaser 4 spike — validated Phaser v4 RC6 (PR #38)
- [ ] Object interaction system (triggers + behaviors from design doc)
```

Extract: `{phase, text, checked, issue_refs}` where `issue_refs` are any
`#<N>` or `PR #<N>` references found in the item text.

**Table format** (workspace style):
```markdown
## Priority: Improve Local Reviews

| Item | Issue | Status | Source | Notes |
|------|-------|--------|--------|-------|
| Adaptive review depth | #47 | done | gstack | ... |
| Cognitive review patterns | #54 | planned | gstack | ... |
```

Tables may have varying column counts (e.g., the Unphased section uses 4
columns without `Source`). Find the `Item`, `Issue`, and `Status` columns
by matching header names, not by column position.

Extract: `{section, item, issue_ref, status}` where status is the value in
the `Status` column.

**Sections to skip**: `Decided Against` (rejected items) and `To Consider`
(unvetted inspiration-tracker findings, bullet-point format, not actionable
roadmap entries). Only parse sections that contain checklist or table items.

### 3. Fetch open and recently closed issues

Resolve the `<owner/repo>` slug for each repo:

```bash
# Workspace repo
WS_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')

# Project repo (if project/ has its own .git)
PJ_REPO=$(git -C project remote get-url origin 2>/dev/null | sed -nE 's|.*github\.com[:/](.+)(\.git)?$|\1|p')
```

For each repo that has a roadmap:

```bash
# Open issues
gh issue list --repo <owner/repo> --state open --json number,title,labels,url,assignees --limit 200

# Recently closed (up to 100 most recent, to detect staleness)
gh issue list --repo <owner/repo> --state closed --json number,title,closedAt,url --limit 100
```

### 4. Cross-reference

For each roadmap item, classify it:

**Simple checklist items:**

| Item state | Issue state | Classification |
|------------|-------------|----------------|
| `- [ ]` | No issue ref | **Needs ticket** — unchecked, no tracking |
| `- [ ]` | Open issue, has assignee or linked PR | **In progress** — someone is working on it |
| `- [ ]` | Open issue, no assignee or PR | **Ready to start** — has a ticket, not yet claimed |
| `- [ ]` | Closed issue | **Stale** — issue closed but item not checked off |
| `- [x]` | Any | **Done** — no action needed |

To detect in-progress state for simple checklists (which lack a status column),
check the open issue for assignees (from the `assignees` field fetched in
step 3) or linked pull requests:
```bash
gh pr list --repo <owner/repo> --search "linked:issue:#<N>" --state open --json number --jq 'length'
```
If the issue has assignees or an open linked PR, classify as **In progress**.

**Table items:**

| Status column | Issue state | Classification |
|---------------|-------------|----------------|
| `done` | Any | **Done** — no action needed |
| `planned` | Open issue | **Ready to start** |
| `planned` | No issue | **Needs ticket** |
| `planned` | Closed issue | **Stale** — issue closed but status not updated |
| `in progress` | Open issue | **In progress** — someone is working on it |
| `in progress` | No issue | **In progress (no ticket)** — work started but untracked; needs an issue |
| `deferred` | Any | **Deferred** — intentionally postponed |
| `subsumed by #N` | Any | **Subsumed** — covered by another item |

### 5. Prioritize suggestions

Rank ready-to-start items by:

1. **Phase ordering** — earlier phases first (Phase 2 before Phase 3;
   higher-priority sections before lower in workspace roadmap)
2. **Has issue** — items with existing open issues preferred over items
   needing new tickets (less setup friction)
3. **Dependencies** — if an item's text references another item or issue
   as a prerequisite, it ranks below that prerequisite

### 6. Produce the report

```markdown
## What Next

**Workspace roadmap**: <found/not found>
**Project roadmap**: <found/not found>

### Stale Items (need roadmap update)

| Repo | Section | Item | Issue | Why stale |
|------|---------|------|-------|-----------|
| workspace | Improve Local Reviews | Adaptive review depth | #47 | Issue closed but status still "planned" |
| project | Phase 2 | Object interaction system | #99 | Issue closed but item unchecked |

### Needs Ticket

| Repo | Section | Item | Notes |
|------|---------|------|-------|
| project | Phase 2 | Robot butler NPC | No issue reference found |

### Suggested Next Work

Prioritized list of ready-to-start items:

1. **[project] Phase 2**: Object interaction system — #<N>
2. **[workspace] Improve Local Reviews**: Cognitive review patterns — #54
3. **[workspace] Reduce Agent Coordination Overhead**: Web dashboard — #64

### In Progress

| Repo | Section | Item | Issue |
|------|---------|------|-------|
| workspace | Reduce Coordination | Permission prompt reduction | (no issue) |

### Summary

<1-3 sentence assessment: how current are the roadmaps? what's the
highest-impact next item?>
```

Omit any section that has no items (e.g., if no stale items, skip that table).

## Guidelines

- **Read-only** — this skill does not modify roadmap files, create issues, or
  check off items. It reports what it finds and the user decides what to act on.
- **Phase ordering matters** — earlier phases represent foundational work that
  may block later phases. Always prioritize them.
- **Fuzzy matching for staleness** — when checking if a closed issue matches a
  roadmap item, compare the issue title against the item text. An exact `#N`
  reference is definitive; title-keyword overlap is suggestive (note as
  "possible match" rather than definitive).
- **Don't over-report** — skip `done` and `subsumed` items from the report
  unless they're stale. The user wants to know what needs attention, not a
  full inventory.
- **Cross-repo awareness** — workspace and project roadmaps serve different
  purposes. Workspace tracks agent infrastructure improvements; project tracks
  product features. Don't mix priorities between them — present each in its
  own context.
- **Respect deferred items** — items marked `deferred` were intentionally
  postponed. List them only if asked, not in the default report.
