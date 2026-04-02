---
name: research
description: Survey external sources on a topic and maintain living research digests. Workspace digest is tracked; project digest lives in the manifest repo.
---

# Research

## Usage

```
/research <topic>                      # Add to workspace digest (default)
/research --scope project <topic>      # Add to project digest
/research --ingest <url>               # Extract takeaways from a URL
/research --refresh                    # Re-survey known topics, prune stale entries
```

## Overview

**Lifecycle position**: Utility — not tied to the per-issue lifecycle. Use any
time to survey external sources or maintain research digests.

Maintain living research digests that capture external best practices, emerging
techniques, and relevant developments. This is **external research** — surveying
sources outside the workspace. For project introspection, use
`gather-project-knowledge`.

## Digests

Two digests, each git-tracked so they're shared across agents and sessions:

### Workspace digest

**Location**: `.agent/knowledge/research_digest.md` (git-tracked in the workspace repo;
create with the digest format below if it doesn't exist)

Topics relevant to any project using this workspace:
- Agent workflow patterns and multi-framework coordination
- CI/CD for AI-assisted development
- Governance automation and enforcement patterns
- Build system and tooling developments
- Worktree and git workflow patterns

### Project digest

**Location**: `.agents/workspace-context/research_digest.md` (in the project repo,
git-tracked — commit there via a project worktree)

Topics specific to the project domain (varies by project).

## Digest Format

```markdown
# Research Digest: <scope>

<!-- Last full refresh: YYYY-MM-DD -->
<!-- Run /research --refresh periodically to re-survey stale entries -->

## <Topic Title>

**Added**: YYYY-MM-DD | **Last verified**: YYYY-MM-DD | **Sources**: [link1](url), [link2](url)

Key takeaways:
- <concise finding>
- <concise finding>

**Relevance**: <why this matters to the workspace/project>

---

## <Next Topic>
...
```

**Staleness rules**: An entry is stale when its `Last verified` date (or `Added`
date if never verified) exceeds 30 days. Entries older than 90 days should be
flagged for review or removal. The top-level `Last full refresh` timestamp
records when `--refresh` last ran across all entries — it is not updated when
individual topics are added.

## Workflow

### Worktree setup

The worktree type depends on the scope:

- **Workspace scope** (default): use a `--skill research` worktree — no issue needed.
  ```bash
  .agent/scripts/worktree_create.sh --skill research --type workspace
  source .agent/scripts/worktree_enter.sh --skill research
  ```

- **Project scope** (`--scope project`): the project digest lives in the project
  repo, so you need a GitHub issue and a project worktree.
  ```bash
  .agent/scripts/worktree_create.sh --issue <N> --type project
  source .agent/scripts/worktree_enter.sh --issue <N> --type project
  ```

### Adding research (`/research <topic>`)

1. Set up the worktree for the appropriate scope (see above)
2. Search the web for current information on the topic
3. Read and synthesize relevant sources
4. Check the existing digest for related entries — update rather than duplicate
5. Append or update the entry in the appropriate digest (set both `Added` and
   `Last verified` to today for new entries; update `Last verified` for existing)
6. Commit in the correct repo: workspace digest commits go in the workspace
   repo; project digest commits go in the project repo (not the workspace)
7. Push and create a PR: `git push -u origin HEAD && gh pr create --fill`
8. Clean up the worktree when done

### Ingesting a URL (`/research --ingest <url>`)

1. Set up the worktree for the appropriate scope (see above)
2. Fetch and read the URL content
3. Extract key takeaways relevant to the workspace or project
4. Determine scope (workspace or project) from content — or ask if unclear
5. Append to the appropriate digest
6. Commit, push, create PR, and clean up

### Refreshing (`/research --refresh`)

1. Set up the worktree for the appropriate scope (see above)
2. Read the digest for the target scope
3. Identify stale entries by checking each entry's `Last verified` date
   (or `Added` date if never verified):
   - **>30 days**: prioritize for re-survey
   - **>90 days**: flag for review or removal
4. For each stale entry (oldest first):
   - Search for updates on the topic
   - Update findings if new information exists
   - Update the entry's `Last verified` date to today
   - Mark as stale or remove if no longer relevant
5. Update the top-level `Last full refresh` timestamp to today
6. Commit, push, create PR, and clean up

## Guidelines

- **External sources only** — this skill surveys the web, papers, docs, and
  community resources. It does not scan the workspace codebase.
- **Concise entries** — each topic should be 5-15 lines. The digest is a
  reference, not a literature review.
- **Cite sources** — every entry needs at least one link.
- **Dedup** — check for existing entries on the same topic before adding.
  Update existing entries rather than creating duplicates.
- **Commit each update** — so the digest history is traceable.
- **Staleness** — tracked per entry via `Last verified`. Entries >30 days
  are prioritized for refresh; >90 days are flagged for review or removal.
  Fast-moving topics may need shorter windows.
