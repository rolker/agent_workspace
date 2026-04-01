# Inspiration Digest: superpowers

Type: inspiration
Last checked: 2026-03-31
Repo: obra/superpowers @ dd23728

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

## Changelog Since Last Check

27 commits, 30 files changed.

- Codex App compatibility: full design spec + implementation plan
- Replaced subagent review loops with lightweight inline self-review (applied, reverted, reapplied — architecture in flux)
- Brainstorm server reorg: separating content and state into peer directories
- Named agent dispatch mapping for Codex
- Fixed false frontmatter claim in writing-skills

## Activity Snapshot

- Very active, focused on subagent/TDD skill chain and Codex compat
- Notable: plan-staleness in parallel sessions (#989), two-stage review silently skipped (#995), brainstorm research-first step (#983), WebSocket origin-validation security issue (#1014)

## Pending Review

(none)

## Issued

- `skills-as-mandatory-gates` — Issue #26: Explore auto-triggering skills based on context (2026-03-22)
- `two-stage-subagent-review` — Issue #27: Split subagent review into spec-compliance and code-quality passes (2026-03-22)
- `headless-integration-tests` — Issue #28: Add headless integration tests for skills (2026-03-22)
- `verification-before-completion` — Issue #29: Create verification-before-completion skill (2026-03-22)
- `visual-brainstorming` — Issue #30: Explore visual companion UI for interactive skills (2026-03-22)
- `systematic-debugging-skill` — Issue #31: Add systematic debugging skill (2026-03-22)

## Skipped

(none)

## Deferred

- `model-selection-for-subagents` — Guidance on using cheaper models for mechanical tasks, capable models for design — revisit when subagent usage increases (2026-03-22)
- `iron-law-pattern` — Documentation pattern using absolute rules + rationalization detection for critical processes — keep in mind for future skill writing (2026-03-22)
- `inline-self-review-vs-subagent` — Superpowers pivoting from subagent review to inline self-review (applied, reverted, reapplied); want to understand reasoning before acting (2026-03-31)
