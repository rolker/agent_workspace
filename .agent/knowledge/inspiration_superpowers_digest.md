# Inspiration Digest: superpowers

Type: inspiration
Last checked: 2026-03-22
Repo: obra/superpowers @ 8ea39819eed74fe2a0338e71789f06b30e953041

## Survey Summary

### Overview

Superpowers is a composable skills framework and software development methodology
for coding agents. It provides a complete dev workflow: brainstorm -> plan -> implement
(via subagents) -> review -> finish. Skills auto-trigger based on context, enforcing
process as mandatory workflow rather than optional suggestions.

### Skills Architecture and Composability

- Skills are markdown files (`SKILL.md`) with YAML frontmatter (`name`, `description`)
  stored in `skills/<skill-name>/` directories
- Skills can reference sub-documents (e.g., `spec-reviewer-prompt.md`, `testing-anti-patterns.md`)
  that provide specialized prompts or reference material
- A meta-skill `using-superpowers` establishes the skill discovery/invocation pattern —
  agents MUST check for applicable skills before any response
- Skills compose via cross-references (e.g., `subagent-driven-development` references
  `finishing-a-development-branch` after completion)
- Separate `commands/` directory for explicit slash commands (brainstorm, execute-plan,
  write-plan) vs auto-triggered skills
- `agents/` directory contains reusable agent role prompts (e.g., `code-reviewer.md`)
- Hooks (`hooks.json`) trigger session-start bootstrapping across platforms
- Multi-platform support: Claude Code, Cursor, Codex, OpenCode, Gemini CLI

### TDD Methodology and Testing Patterns

- **Iron Law**: No production code without a failing test first — code written before
  tests must be deleted, not adapted
- **Red-Green-Refactor** cycle enforced as a skill, not just a guideline
- Anti-patterns reference document covers common testing mistakes
- Integration tests run actual Claude Code sessions in headless mode, parsing JSONL
  transcripts to verify skill behavior (10-30 min execution)
- Test fixtures use small real projects (Go fractals, Svelte todo app)
- Skill triggering tests verify auto-detection works correctly
- `verification-before-completion` skill enforces evidence-before-claims —
  no completion status without fresh test output in the same message

### Subagent Patterns and Orchestration

- **Subagent-driven-development**: Fresh subagent per task with two-stage review
  (spec compliance first, then code quality)
- Subagents get precisely crafted context — never inherit session history
- Three specialized prompts: `implementer-prompt.md`, `spec-reviewer-prompt.md`,
  `code-quality-reviewer-prompt.md`
- Model selection by task complexity: cheap models for mechanical tasks,
  capable models for design/review
- **Dispatching parallel agents**: One agent per independent problem domain,
  concurrent execution for unrelated failures
- Review loops: if reviewer rejects, implementer fixes and re-submits
- Final whole-implementation code review after all tasks complete
- `SUBAGENT-STOP` tag prevents meta-skills from activating in subagent context

### Development Methodology and Workflows

- **Brainstorming**: Socratic design refinement before coding — explores alternatives,
  presents design in digestible sections, saves design document
- **Writing plans**: Plans assume zero codebase context — bite-sized tasks (2-5 min each)
  with exact file paths, complete code, verification steps
- **Plan header convention**: Every plan includes instructions for which execution
  skill to use, with checkbox syntax for tracking
- **Git worktrees**: Isolated workspace per feature branch, clean test baseline required
- **Finishing workflow**: Verify tests -> present options (merge/PR/keep/discard) -> cleanup
- **Systematic debugging**: Four-phase root cause process — investigation required
  before any fix attempt
- **Code review**: Both requesting and receiving review are separate skills with
  structured processes

### Notable Patterns Worth Studying

1. **Skills as mandatory workflow gates** — not optional suggestions, enforced via
   strong language in meta-skill
2. **Two-stage review** (spec compliance + code quality) as separate concerns
3. **Headless integration tests** that verify skill behavior via transcript parsing
4. **Model selection guidance** for subagent cost/speed optimization
5. **Cross-platform plugin architecture** (Claude Code, Cursor, Codex, OpenCode, Gemini)
6. **Visual brainstorming companion** (browser-based, WebSocket)
7. **"Iron Law" pattern** — critical rules stated as absolutes with explicit
   rationalization-detection ("thinking X? Stop.")

## Activity Snapshot

- 20 open issues, 30 open PRs (very active development)
- Notable themes:
  - Multi-agent coordination improvements (#801 agent-teams, #777 multi-agent collab)
  - Brainstorming enhancements (#849 context awareness, #834 Option Zero)
  - Cross-platform support (Cursor #871, Copilot #850, Trae IDE #811)
  - Subagent improvements (#846 memory override for strategy, #793 CLAUDE.md in subagents)
  - Plan execution fixes (#789 checkbox updates, #809 timeout issues)

## Pending Review

- `skills-as-mandatory-gates` — Pattern of using a meta-skill to enforce skill invocation before any response (2026-03-22)
- `two-stage-subagent-review` — Spec compliance review + code quality review as separate passes with different prompts (2026-03-22)
- `headless-integration-tests` — Testing skills by running actual agent sessions and parsing JSONL transcripts (2026-03-22)
- `verification-before-completion` — Skill that enforces evidence-before-claims, preventing premature success declarations (2026-03-22)
- `model-selection-for-subagents` — Guidance on using cheaper models for mechanical tasks, capable models for design (2026-03-22)
- `visual-brainstorming` — Browser-based visual companion for brainstorming sessions via WebSocket (2026-03-22)
- `systematic-debugging-skill` — Four-phase root cause investigation process enforced as a mandatory skill (2026-03-22)
- `iron-law-pattern` — Documentation pattern using absolute rules + rationalization detection for critical processes (2026-03-22)

## Issued

(none yet)

## Skipped

(none yet)

## Deferred

(none yet)
