# Workspace Knowledge

Workspace-level guidance for AI agents. All files in this directory are
version-controlled and apply regardless of which project repository is
checked out in `project/`.

## IDE Setup
- **[VS Code Setup Guide](vscode_setup.md)**: Makefile tasks, C++/Python IntelliSense, worktree workflow, and Claude Code extension integration.

## Agent Workflows
- **[Skill Workflows](skill_workflows.md)**: Per-issue lifecycle sequence, governance skill index, and utility skill catalog.
- **[Principles Review Guide](principles_review_guide.md)**: Evaluation criteria for workspace principles and ADRs. Used by lifecycle skills (triage, planning, review) and as a manual checklist.
- **[Documentation Verification](documentation_verification.md)**: Mandatory verification workflow for writing accurate package documentation. Includes command cookbook and hallucination anti-patterns.
- **[Inspiration Registry](inspiration_registry.yml)**: Tracked external projects for the `/inspiration-tracker` skill. Per-project digests are created alongside this file on first run.

## Project-Specific Knowledge

Project-specific conventions and architecture docs are available via
`.agent/project_knowledge/` (a symlink to the manifest repo's
`.agents/workspace-context/` directory, created by `setup_project.sh`). This symlink
may not exist if the project repo has not set up `.agents/workspace-context/`.

## Project-Level Agent Guides

Project repositories may contain a `.agents/README.md` at their root with repo-specific
guidance for agents. To create one, use the template at
[`../templates/project_agents_guide.md`](../templates/project_agents_guide.md).

---
*Note: This index is manually maintained. Update it when adding new knowledge files.*
