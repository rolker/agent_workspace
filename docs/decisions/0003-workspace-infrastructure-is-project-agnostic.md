# ADR-0003: Workspace Infrastructure Is Project-Agnostic

## Status

Accepted

## Context

This workspace was designed to work with any single-repo project, not a specific one.
The workspace infrastructure (worktree workflows, agent instructions, build scripts,
CI pipelines) is generic — it should serve any project without modification.

The key concern is project independence: the managed project repo must never depend on
workspace conventions. It should always be usable, buildable, and testable standalone.
The workspace serves the project, not the other way around.

## Decision

The workspace repo contains only generic agent infrastructure. Project-specific content
belongs in the project repo.

Separation:
- **Workspace repo** owns: infrastructure for building and working with projects
  (worktree workflows, agent instruction patterns, templates, scripts, generic knowledge).
- **Project repo** owns: everything needed to use the project standalone — architecture,
  ADRs, conventions, package-specific documentation.
- The project repo's source of truth is its own `remote.origin.url` — no workspace
  configuration file stores the project URL.

Reusability test: someone should be able to use this workspace for a different project
by configuring a new `project/` directory, without needing to remove project-specific
content from the workspace itself.

## Consequences

**Positive:**
- The workspace is reusable across any single-repo project
- Clean separation of concerns — workspace improvements don't require project knowledge
- The project repo works standalone without the workspace

**Negative:**
- Requires ongoing discipline to keep project-specific content out of workspace files
