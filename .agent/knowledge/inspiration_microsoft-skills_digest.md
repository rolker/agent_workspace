# Inspiration Digest: microsoft-skills

> **ARCHIVED** — 2026-04-19. Removed from active `inspiration_registry.yml`
> tracking. Recon scan 2026-04-19 (since 2026-03-31) showed 23 merged PRs,
> 20 of which are mechanical Azure plugin syncs (`Sync plugin files from
> GitHub-Copilot-for-Azure ...`). The remaining 3 are either Azure-specific
> (KQL language mastery skill, Azure-skills CHANGELOG population) or
> structural (outer skills folder removal). Signal-to-noise collapsed.
>
> This digest is retained for historical reference. If microsoft/skills
> pivots back toward general skill-architecture contributions worth
> tracking, re-add to the registry.

Type: inspiration (archived)
Last checked: 2026-03-31
Repo: microsoft/skills @ a8af084

## Survey Summary

### Overview

Microsoft's skills repo is a collection of 132+ domain-specific knowledge packages
for AI coding agents, focused on Azure SDKs and Microsoft AI Foundry. It provides
skills, custom agents, Agents.md templates, MCP configurations, hooks, and a
plugin marketplace. Cross-platform: GitHub Copilot, Claude Code, OpenCode.

### Skills Architecture and SDK Grounding

- **Skill structure**: Each skill is a directory with `SKILL.md` (YAML frontmatter +
  markdown body) plus optional `scripts/`, `references/`, `assets/` subdirectories
- **Three-level progressive disclosure**: metadata (~100 words, always in context) ->
  SKILL.md body (<5k words, on trigger) -> references (unlimited, as needed)
- **Naming convention**: `<service>-<language>` suffix (e.g., `azure-cosmos-py`)
- **Language-organized categories**: `skills/python/foundry/`, `skills/dotnet/data/`,
  etc. with symlinks to canonical `.github/skills/` directory
- **Plugin system**: `marketplace.json` defines installable plugin packages, each with
  `skills/`, `agents/`, `commands/` directories
- **Installation via `npx skills add`**: Interactive wizard for selecting skills,
  installs to agent-appropriate directory, symlinks for multi-agent setups
- **Skill creator meta-skill**: Guides creation of new skills with emphasis on
  conciseness ("Does this justify its token cost?") and degrees of freedom
- **Context rot warning**: Explicitly warns against loading too many skills —
  "diluted attention, wasted tokens, conflated patterns"
- **Test harness**: `pnpm harness <skill-name> --mock --verbose` with YAML scenario
  files and acceptance criteria in `references/`

### Custom Agent Patterns

- **Role-specific agents** in `.github/agents/`: `planner.agent.md`,
  `backend.agent.md`, `frontend.agent.md`, `infrastructure.agent.md`,
  `scaffolder.agent.md`, `presenter.agent.md`
- **Agent frontmatter**: `name`, `description`, `tools` (array of allowed tools),
  `handoffs` (structured handoff definitions to other agents)
- **Planner agent** is read-only (tools: read, search, web) — creates plans then
  hands off to implementation agents via structured handoffs
- **Handoff protocol**: Each handoff specifies `label`, `agent`, `prompt`, `send`
  — enabling agent-to-agent task delegation
- **Tool scoping**: Agents declare which tools they can use, constraining capability
  (e.g., planner can't edit, backend can edit)

### Agents.md Conventions

- **Dual-file pattern**: `Agents.md` + `.github/copilot-instructions.md` with
  overlapping content (similar to our AGENTS.md + CLAUDE.md split)
- **Core principles section**: Think Before Coding, Simplicity First, Surgical
  Changes, Goal-Driven Execution (TDD) — each with concrete examples and "the test"
  statements
- **Clean Architecture diagram**: Layered boundaries (Presentation -> Application ->
  Domain -> Infrastructure) with explicit dependency rules
- **SDK Quick Reference table**: Package -> Purpose -> Install command
- **Do's and Don'ts lists**: Concrete actionable items with checkmark/cross notation
- **Success Indicators**: Observable behaviors that confirm principles are working
- **Skills section in Agents.md**: Describes skill catalog, selection guidance,
  creation workflow — making Agents.md the entry point for skill discovery
- **Conventions section**: Code style, git patterns, testing patterns — all compact

### Other Notable Patterns

- **Continual Learning hook**: Session-aware hook that tracks tool outcomes, reflects
  on patterns at session end, stores insights in two-tier SQLite (global + local),
  with 60-day TTL decay for low-value learnings
- **MCP server pre-configuration**: `.vscode/mcp.json` with categorized servers
  (documentation, development, utilities)
- **Auto-sync workflows**: GitHub Actions that sync skills from upstream repos
  (e.g., Copilot for Azure)

## Changelog Since Last Check

35 commits, 179 files changed. Mostly automated sync.

- Entra Agent ID sidecar: SDK sidecar reference for polyglot agent auth
- Plugin install path fix for Copilot CLI
- CODEOWNERS file added
- 15+ automated plugin syncs from Copilot for Azure pipeline

## Activity Snapshot

- 3 open issues, moderate PR activity
- Mostly maintenance and upstream sync; no major new patterns

## Pending Review

(none)

## Issued

- `progressive-skill-disclosure` — Issue #39: Explore progressive skill disclosure with token budget guidance (2026-03-22)
- `agent-handoff-protocol` — Issue #40: Explore structured agent handoffs with tool scoping (2026-03-22)
- `skill-test-harness` — Issue #41: Explore YAML scenario-based skill testing (2026-03-22)
- `continual-learning-hook` — Issue #42: Explore automated continual learning across sessions (2026-03-22)
- `success-indicators-pattern` — Issue #43: Add success indicators section to AGENTS.md (2026-03-22)

## Skipped

(none)

## Deferred

- `context-rot-awareness` — Guidance against loading too many skills — revisit as skill count grows (2026-03-22)
