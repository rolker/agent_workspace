# Inspiration Digest: superpowers

Type: inspiration
Last checked: 2026-05-07
Repo: obra/superpowers
- main @ f2cbfbe (Release v5.1.0, 2026-05-04)
- dev  @ 7f02ccd (active development, 2026-05-06)

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
- Separate `commands/` directory for explicit slash commands deprecated in v5.1.0 —
  shims removed (brainstorm/execute-plan/write-plan)
- `agents/` directory contained reusable agent role prompts; `code-reviewer.md` was
  lifted into the requesting-code-review skill in v5.1.0
- Hooks (`hooks.json`) trigger session-start bootstrapping across platforms
- Multi-platform support: Claude Code, Cursor, Codex (now first-class via `.codex-plugin/`),
  OpenCode, Gemini CLI, Junie, Factory Droid, Lingma, Kimi Code

### TDD Methodology and Testing Patterns

- **Iron Law**: No production code without a failing test first — code written before
  tests must be deleted, not adapted
- **Red-Green-Refactor** cycle enforced as a skill, not just a guideline
- Anti-patterns reference document covers common testing mistakes
- **Drill/evals harness (NEW in dev, post-v5.1.0)**: Python-based skill compliance
  benchmark replacing shell-script tests. Drives agents through real tmux sessions,
  evaluates with LLM verifier + deterministic assertions, supports multi-backend
  comparison (Claude/Codex/Gemini variants). 30+ scenarios covering worktree handling,
  skill triggering, SDD workflow, review/spec/verification, tool mapping. 122-test
  pytest suite. See `evals/docs/design.md` for full architecture.
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
- **Subagent-model-reconciliation skill (NEW, PR #1496)**: explicit pre-execution
  decision framework for picking models per subagent step
- **Dispatching parallel agents**: One agent per independent problem domain,
  concurrent execution for unrelated failures; documented single-message-N-blocks
  mechanic (PR #1470)
- Review loops: if reviewer rejects, implementer fixes and re-submits
- Final whole-implementation code review after all tasks complete
- `SUBAGENT-STOP` tag prevents meta-skills from activating in subagent context

### Development Methodology and Workflows

- **Brainstorming**: Socratic design refinement before coding — explores alternatives,
  presents design in digestible sections, saves design document
- **Writing plans**: Plans assume zero codebase context — bite-sized tasks (2-5 min each)
  with exact file paths, complete code, verification steps
- **Plan-review-cycle skill (NEW, merged PR #1473)**: adversarial plan review between
  writing-plans and executing-plans
- **Plan header convention**: Every plan includes instructions for which execution
  skill to use, with checkbox syntax for tracking
- **Git worktrees**: Isolated workspace per feature branch; v5.1.0 added consent gates,
  native-tool preference, detached-HEAD handling for Codex
- **Finishing workflow**: Verify tests -> present options (merge/PR/keep/discard) -> cleanup
- **Systematic debugging**: Four-phase root cause process — investigation required
  before any fix attempt
- **Code review**: Both requesting and receiving review are separate skills with
  structured processes; v5.1.0 lifted the code-reviewer agent into the skill body

### Notable Patterns Worth Studying

1. **Skills as mandatory workflow gates** — not optional suggestions, enforced via
   strong language in meta-skill
2. **Two-stage review** (spec compliance + code quality) as separate concerns
3. **Drill/evals harness** — multi-backend skill behavior tests with LLM verifier
   and deterministic assertions
4. **Model selection guidance** for subagent cost/speed optimization
5. **Cross-platform plugin architecture** (Claude Code, Cursor, Codex, OpenCode,
   Gemini, Junie, Factory, Lingma, Kimi)
6. **Visual brainstorming companion** (browser-based, WebSocket)
7. **"Iron Law" pattern** — critical rules stated as absolutes with explicit
   rationalization-detection ("thinking X? Stop.")
8. **Adversarial plan-review-cycle** between plan-writing and execution
9. **Lifecycle event hooks** (PR #1461) — exposes events beyond SessionStart for
   external plugin authors

## Changelog Since Last Check (2026-03-31 → 2026-05-07)

**Main range** dd23728..f2cbfbe: 24 commits, 53 files. Released as **v5.1.0**.
**Dev range** f2cbfbe..7f02ccd: 21 commits, 142 files (mostly the evals lift).

### v5.1.0 (released 2026-05-04)

- **Native Codex plugin** — `.codex-plugin/`, sync-to-codex-plugin tooling, removed
  legacy `.codex/INSTALL.md` and CHANGELOG.md
- **Worktree rototill** (PRI-974) — design + plan in `docs/superpowers/`, native
  preference test, consent gates, detached-HEAD handling
- **Deprecated shims removed** — `commands/brainstorm.md`, `commands/execute-plan.md`,
  `commands/write-plan.md`
- **code-reviewer agent lifted** into `requesting-code-review` skill (agents/ folder
  shrank)
- **OpenCode bootstrap caching** at module level (eliminates per-step file I/O)
- **Cursor Windows hooks** fixed via run-hook.cmd
- **Skill content edits** — executing-plans, finishing-a-development-branch,
  systematic-debugging (stale path refs), using-git-worktrees, writing-plans,
  using-superpowers references for codex/copilot/gemini tools

### Post-v5.1.0 dev branch

- **Drill → evals/ lift** (PR #1488) — major addition. Full Python eval harness
  with 30+ scenarios, multi-backend support, LLM verifier + deterministic
  assertions, 122-test pytest suite. Bash-based skill-triggering and
  subagent-driven-dev tests removed; coverage moved into drill scenarios.
- **Pre-commit hooks** added (`.pre-commit-config.yaml`)
- **Adversarial review findings** addressed before drill landed

### Notable open work (not yet merged into dev)

- PR #1496 — subagent-model-reconciliation skill
- PR #1486 — cross-platform skill compatibility (agent-neutral prose,
  source-verified per-runtime tool refs)
- PR #1499 — pi extension and eval backend
- PR #1497 — Devkit DotNet (.NET/Blazor/DDD skills, orchestrator agent)
- PR #1473 — plan-review-cycle skill (merged 2026-05-05)
- PR #1471 — script-vs-prose decision guidance for skill steps
- PR #1470 — dispatching-parallel-agents single-message-N-blocks mechanic docs
- PR #1461 — lifecycle event hooks for external plugin authors
- PR #1450 — spec-driven-slicing skill

### Notable open issues

- #1495 — evidence-quoted safety screen (companion to verification-before-completion)
- #1490 — full automation BRAINSTORM→PLAN→IMPLEMENT
- #1487 — writing-skills v5.0.7: '3+ combined pressures' anchor pattern misapplied
- #1456 — make using-superpowers opt-in to auto-load
- #1442 — expose lifecycle events beyond SessionStart
- #1441 — Opus 4.7 with auto mode doesn't respect execution gates
- #1267 — writing-skills: when to extract deterministic steps to scripts vs prose
- #1255 — explicit architecture confirmation step between brainstorming and writing-plans
- #1248 — TDD-driven refactoring may degrade domain design
- #1218 — infinite code review loop in subagent-driven-development

## Activity Snapshot

- ~60 open issues, ~30 open PRs (sampled). Very active.
- v5.1.0 released 2026-05-04 (PR #1468); dev branch already 21 commits ahead.
- Big themes since last check: native Codex plugin, worktree rototill, drill/evals
  harness, deprecated shim removal, lifecycle hooks, adversarial review patterns.

## Pending Review

(none — all 2026-05-07 items triaged below)

## Roadmapped

- `drill-evals-harness` — added to ROADMAP.md "To Consider" 2026-05-07.
  Python-based skill compliance benchmark with multi-backend support, scenario
  YAMLs, LLM verifier + deterministic assertions. Source: obra/superpowers
  evals/ on dev (PR #1488).
- `plan-review-cycle-skill` — added to ROADMAP.md "To Consider" 2026-05-07.
  Adversarial plan review between writing-plans and executing-plans
  (PR #1473 merged). Compare with daddy_camp's existing /review-plan skill.

## Issued (historical, 2026-03-22)

- `skills-as-mandatory-gates` — Issue #26
- `two-stage-subagent-review` — Issue #27
- `headless-integration-tests` — Issue #28
- `verification-before-completion` — Issue #29
- `visual-brainstorming` — Issue #30
- `systematic-debugging-skill` — Issue #31

## Skipped

- `using-superpowers-opt-in-bootstrap` (2026-05-07) — Daddy_camp has no analogous
  always-on session-start prompt injection. CLAUDE.md/AGENTS.md load once per
  session; settings.json hooks fire on specific events without injecting prompt
  text. Pattern noted for the workspace-context system but no direct adoption.

## Deferred

- `iron-law-pattern` — Documentation pattern using absolute rules + rationalization
  detection for critical processes — keep in mind for future skill writing
  (2026-03-22)
- `inline-self-review-vs-subagent` — Superseded 2026-05-07: plan-review-cycle
  skill shipped (PR #1473); now tracked via the `plan-review-cycle-skill`
  Roadmapped entry.
- `model-selection-for-subagents` — Superseded 2026-05-07 by
  `subagent-model-reconciliation` (Deferred below; PR #1496 still open).
- `subagent-model-reconciliation` (2026-05-07) — PR #1496 still open upstream;
  defer until merged so we can study the final shape. Resolves our older
  `model-selection-for-subagents` deferral.
- `writing-skills-script-vs-prose` (2026-05-07) — Issue #1267 / PR #1471.
  Useful but not pressing; revisit when authoring the next batch of skills.
- `lifecycle-event-hooks` (2026-05-07) — PR #1461 / issue #1442. No concrete
  need today; flag if we ever want skill-to-skill reactivity beyond
  settings.json hooks.
- `lift-agent-into-skill` (2026-05-07) — v5.1.0 pattern. Note for next
  reorganization of `.claude/agents/`; some 1:1 agent→skill pairs in
  daddy_camp may be inlining candidates.
- `cross-platform-skill-compatibility` (2026-05-07) — PR #1486. AGENTS.md
  Tool Mapping table covers the workspace-level mapping; revisit if/when
  we run skills under Codex or Gemini.
- `worktree-consent-gate` (2026-05-07) — v5.1.0 pattern. Daddy_camp's
  workflow is friction-averse with 4-5 concurrent agents; auto-creation
  is currently preferred. Native-tool preference also conflicts with our
  cross-runtime stance. Keep on radar if worktree volume becomes a problem.
- `evidence-quoted-safety-screen` (2026-05-07) — Issue #1495. Pattern is
  interesting but enforcement mechanism (hook? skill? AGENTS.md tightening?)
  unclear; revisit after upstream lands a concrete skill.
