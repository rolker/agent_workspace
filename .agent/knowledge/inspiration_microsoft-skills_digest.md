# Inspiration Digest: microsoft-skills

Type: inspiration
Last checked: 2026-03-22
Repo: microsoft/skills @ 949a48d50f0c3289f72a61c653bf8cb0cd148e07

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

## Activity Snapshot

- 11 open issues, 17 open PRs (moderately active)
- Notable themes:
  - Block --no-verify hook (#202, #204)
  - Agent Framework skills (#191)
  - Credential-free dev skills (#196, #199)
  - Entra Agent ID skill (#195)
  - Auto-sync from Copilot for Azure (#206, #207)

## Pending Review

- `progressive-skill-disclosure` — Three-level skill loading (metadata -> body -> references) with explicit token budget guidance (2026-03-22)
- `agent-handoff-protocol` — Structured agent-to-agent handoffs with tool scoping and role specialization (2026-03-22)
- `skill-test-harness` — YAML scenario-based testing with acceptance criteria for skills (2026-03-22)
- `continual-learning-hook` — Session-aware hook with two-tier SQLite memory and TTL-based decay (2026-03-22)
- `context-rot-awareness` — Explicit guidance against loading too many skills, with selective loading as default (2026-03-22)
- `success-indicators-pattern` — Observable behaviors section in Agents.md that confirms principles are working (2026-03-22)

## Issued

(none yet)

## Skipped

(none yet)

## Deferred

(none yet)
