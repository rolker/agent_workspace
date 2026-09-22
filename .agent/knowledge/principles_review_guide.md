# Principles Review Guide

How to evaluate work against workspace principles and ADRs. Read this during
issue triage, planning, or PR review. Skills reference specific tables below;
humans use it as a checklist.

## Principle Quick Reference

| Principle | Adherence looks like | Watch for |
|---|---|---|
| Human control and transparency | PR explains what, how, and why; no hidden side effects; controls are configurable | Unexplained automation, invisible state changes, choices without rationale |
| Enforcement over documentation | New rule has a hook, CI check, or guardrail — not just markdown | Rules that exist only in docs; bypassing existing enforcement |
| Capture decisions, not just implementations | Design choice recorded in ADR or issue; rationale survives the author | Decisions buried in commit messages or chat; "why" missing from the record |
| A change includes its consequences | Tests, docs, and dependent references updated in the same PR | "Follow-up" items for stale docs or broken tests; partial changes merged |
| Only what's needed | Minimal files, process, and resource use; solves a concrete pain | Speculative features, bloated context, unnecessary abstraction, premature tooling |
| Improve incrementally | Small, reviewable change; workspace is better after than before | Large rewrites, all-or-nothing PRs, scope creep beyond the issue |
| Test what breaks | Tests target regressions that matter — timing, sensors, degraded conditions | Coverage-chasing, testing framework glue, no tests for risky logic |
| Workspace vs. project separation | Workspace infra is project-agnostic; project content in project repos | Project-specific config leaking into workspace; workspace depending on a project |
| Workspace improvements cascade to projects | New workflow pattern is portable; workspace is the reference implementation | Improvements locked to one repo; patterns that can't be adopted downstream |
| Primary framework first, portability where free | Full use of active framework; rules naturally portable are expressed portably | Hobbling the primary tool for hypothetical frameworks; framework lock-in where avoidable |
| The workspace serves the product | Infrastructure investment tied to concrete product acceleration; operational friction fixes justified by product impact | Sustained workspace-heavy PR ratio without product delivery; tooling that solves problems the product doesn't have; infrastructure built for its own sake |

## ADR Applicability

| ADR | Triggered when | Key requirement |
|---|---|---|
| 0001 — Adopt ADRs | A design decision is made that future agents/humans need to understand | Record in `docs/decisions/` with context, decision, and consequences |
| 0002 — Worktree isolation | Any feature work begins | Use worktree, not branch switch; enforced by worktree scripts and pre-commit hooks |
| 0003 — Project-agnostic workspace *(superseded by 0011)* | — | Superseded: single-repo assumption replaced by the adapter contract; separation doctrine lives on in 0011 |
| 0004 — Enforcement hierarchy | A new compliance rule is proposed | Enforce at multiple layers (instructions → hooks → CI); no single layer sufficient |
| 0005 — Layered enforcement | Adding or modifying enforcement | CI/branch protection is authoritative; pre-commit provides local feedback; framework hooks provide early feedback |
| 0006 — Shared AGENTS.md | Changing agent instructions | Shared rules in `AGENTS.md`; framework adapters are thin wrappers |
| 0007 — Retain Make with Dependency Tracking | Changing the Makefile or proposing a different task runner | Keep Make; use stamp-file dependencies for incremental setup and build |
| 0008 — Permit cross-reference addendums in ADRs | Editing an accepted ADR | Status-line notes pointing at related ADRs and References-section additions are permitted; substantive edits (Decision rewording, position reversal, Consequences changes) still require superseding |
| 0009 — Python package management | Installing Python packages or modifying `.venv` | Use .venv for dev tools; never bare pip install |
| 0010 — git-bug installed by default | Adding or modifying issue lookup scripts, bootstrap, or sync | git-bug installed by default; scripts use `_issue_helpers.sh` (git-bug first with sync-on-miss, fall back to `gh`); graceful degradation required |
| 0011 — Project-type adapter contract | Adding workspace content, touching build/test/setup/sync scripts, or anything that branches on project shape | Shape-specific behavior lives in `.agent/project_types/<type>/adapter.sh` behind the 12-verb contract; workspace content stays project-agnostic; `validate_adapter.sh` must pass |
| 0012 — Worktree composition is an adapter concern | Touching worktree creation/removal/listing, or any script that composes a multi-repo worktree | Multi-repo composition knowledge lives behind `worktree_repos`/`worktree_env` adapter verbs, not in generic worktree scripts; those scripts loop over the `.worktree-repos` manifest and never check project type; no symlink fallback anywhere in the creation path |
| 0013 — `progress.md` entry-type vocabulary | Writing a new `progress.md` entry from a workflow skill or script, or introducing a new entry type | Use one of the canonical `## <Entry Type>` headings from the ADR's Decision table; write via `.agent/scripts/progress_append.sh`; a new type requires a superseding ADR, not an addendum |
| 0014 — In-process phase handoff | Touching `dispatch_phase.sh`, the `run-issue` skill, or a phase's task-line / entry-type / model tier | One dispatch path (Agent tool, in-process only); the handoff contract (worktree, task, identity, model, exit contract) prints from `dispatch_phase.sh`; exit checked mechanically via `--check-exit`, never assumed from a sub-agent's own summary; one driver per issue; checkpoint entries carry `**Decided-by**: owner` |
| 0015 — Parallel sync is the only review dispatch mode | Touching `cross_model_review.sh`, its per-agent helpers, or the `review-code` skill's dispatch step | No tmux mode and no `--sync`; one background job per agent, all in parallel, each bounded by a per-agent timeout; failure is per agent (own marker, own `EXIT=` line); `review-code` dispatches once with `--agents` and reads `EXIT=` per agent, never the script's overall status |

## Consequences Map

| If you change... | Also update... |
|---|---|
| A principle in `docs/PRINCIPLES.md` | This review guide; any skills that reference the principle by name |
| An ADR in `docs/decisions/` | This review guide's ADR table |
| `AGENTS.md` | Framework adapters if affected (`.github/copilot-instructions.md`, etc.) |
| A script in `.agent/scripts/` | Script reference table in `AGENTS.md`; `Makefile` if it has a target |
| The adapter contract (`REQUIRED_VERBS` in `.agent/scripts/adapter`) | Every `.agent/project_types/*/adapter.sh`; ADR-0011 (or a new ADR per ADR-0008 if the verb count changes); `test_adapter.sh` |
| A template in `.agent/templates/` | Docs that reference the template; skills that use it |
| A framework skill (e.g., `.claude/skills/`) | That framework's adapter file; regenerate skills if needed |
| Workflow skill list (add/remove a skill) | Skill list in non-Claude adapters (`.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`, `.agent/AGENT_ONBOARDING.md`) |
| Project interfaces or public APIs | Downstream consumers, documentation, tests |
| Worktree scripts | `.agent/WORKTREE_GUIDE.md`; `AGENTS.md` worktree section |
| `review-code` skill | `.agent/knowledge/review_depth_classification.md`; `.agent/scripts/cross_model_review.sh` |
| Review depth classification doc | `review-code` skill (if tier definitions change) |
| Work-plan directory convention | `plan-task`, `review-plan`, `triage-reviews`, `review-code` skills; `ARCHITECTURE.md` directory tree |
| `progress.md` entries (`## Plan Authored`, `## Plan Review`, `## Local Review`, `## Local Review (Pre-Push)`, `## Integrated Review`, `## Implementation` — ADR-0013) | `plan-task`, `review-plan`, `review-code`, `triage-reviews`, `address-findings` write them via `review_progress.sh persist`; `round` / `sources` / `findings` / `plan-sha` read them back — change an entry's shape or correlation field and the writer, the readers, and ADR-0013's tables move together |
| A phase's entry type, verdict field, or `progress.md` shape | `.agent/scripts/dispatch_phase.sh`'s per-skill tables and `next`'s decision-table rows, `test_dispatch_phase.sh`'s fixtures, `.agent/knowledge/review_loop_lifecycle.md` |

## Governance Layering

Workspace and project repos may both have principles, ADRs, and agent guides.
When both exist:

- **Workspace principles** govern *process* — how work is done (worktrees,
  PR workflow, documentation standards)
- **Project principles** govern *domain* — what is built (sensor behavior,
  mission logic, safety constraints)
- **Project rules take precedence** on domain questions
- **Both apply**; neither is optional
- When they conflict on process, flag it — don't silently pick one
