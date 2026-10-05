# Principles Review Guide

How to evaluate work against workspace principles and ADRs. Read this during
issue triage, planning, or PR review. Skills reference specific tables below;
humans use it as a checklist.

## Principle Quick Reference

One row per principle in `docs/principles.md`, in the same order. Judge a change by the
failure the principle's Why line names, not by whether the change mentions the principle.
Skip rows that clearly do not apply.

| Principle | Adherence looks like | Watch for |
|---|---|---|
| Leave a trail; start limits strict | What the agent did and why is recorded where the user can find it later; the user is shown only what a decision needs; the record is no heavier than checking the work requires; a new limit on agent autonomy starts strict and only the user relaxes it | Work with no record of why; a hand-back that dumps everything instead of what the decision needs; records whose cost (commits, entries, text to read) nobody weighed; an agent relaxing its own limits |
| Enforce what matters, as simply as possible | A rule whose breach costs more than checking it has the simplest check that fails when it is broken (a yes/no test at one chokepoint beats a check that interprets state); where to enforce follows ADR-0004 and ADR-0005; a check needed by one project runs from the workspace unless that project chose to carry it | A rule that exists only in prose and matters; a heavy check for a cheap rule; each review round adding more hardening to one check; a check committed into a project that did not choose it |
| Keep one current design | A change that alters how the parts fit updates the design document in the same change, and the plan says which design section changes; accepted ADRs and plans are history, the design document is the current picture; implementation detail goes where the code is (script header, document next to it), not into an ADR | A design change recorded only in a new ADR, issue comment or commit message; an accepted ADR edited in place to describe new behaviour; two copies of the same description that can drift |
| A change includes its consequences | Tests, documents and references that the change made false are updated or deleted in the same PR | A "follow-up" for text or a test the change itself made untrue; partial changes merged. A further improvement that is not a consequence may go to a follow-up issue |
| Only what's needed | The PR or plan names the concrete problem each new file, script, process or document solves; things that no longer solve one are removed; context is loaded and summarised only as far as needed | Speculative features; unnecessary abstraction or premature tooling; a mechanism with no named problem; things added and never removed |
| Small steps; step back when they stop converging | Small changes that can each be reviewed; when the work keeps growing and each fix needs another, the agent stops and proposes the simplest design that covers the cases and the tests found so far, and the replacement must pass the same cases | Large rewrites and all-or-nothing PRs; scope creep beyond the issue; a third or fourth round of patches on the same code with no question about the approach; a proposed rewrite that drops cases earlier rounds found |
| Test what breaks | A fix comes with a test that fails without it; tests check what the code promises, not how it does it; a new case is added to an existing test that shares its setup rather than new scaffolding; an existing check changes only when the behaviour it checks was changed on purpose, and the PR says so | Tests written to raise coverage; tests of framework glue or internal structure; a fix with no failing-first test; an existing test edited to make a failing run pass without saying why |
| Put each thing at the level it applies to | Code and knowledge sit at the widest level where they hold (every project, one kind of project, a single project); nothing committed to the workspace names or depends on a particular project (search the diff for project names; no test depends on a hosted checkout); a general feature was tried on a sample project that is not the one it was built for; workspace-only parts are kept separate and marked; the plan asks whether an improvement applies beyond this module or project | Project-specific config or names in the workspace; the workspace depending on a project; something built for one project and called general without a second try; a general rule placed so narrowly it will be rebuilt elsewhere |
| Use the main tool fully; keep the work tool-neutral | Plans, reviews and progress are plain files any tool can read; each part that depends on one tool says how the work continues without it; the main tool's strengths are used rather than avoided | Plans or state that live only inside one tool's memory or session; a tool-specific part with no stated fallback; hobbling the main tool for a hypothetical other one |
| Ask about what matters, and show how much | Small decisions are made by the agent within its limits and recorded; a question to the user says what it changes and how hard it is to undo; a question that changes the design is asked on its own | A design question folded into a routine checkpoint or bundled with reviewer findings; many small questions; a recommendation offered with no statement of what it commits to |
| Verify before claiming | Each claim in a PR description or hand-back traces to a command run or a file read; "tests pass" names which tests; skipped or failed steps and skipped reviewers are listed as skipped or failed | Quoting a draft as the content of a file without opening it; "done" for a step that was denied, failed or not run; a review the agent approved itself; documentation written from assumption rather than source |
| Look for prior art before building | The plan names what was looked at (existing code, the tools in use, outside practice) and what was taken or rejected; a new mechanism says why the existing one did not fit. Whether to build at all is "Only what's needed"; this row is about how | A new mechanism or design with no mention of what already exists; building a resolver, runner or format that a tool already in use provides |
| Leave in a project only what it chose to carry | A PR to a project contains only project work, unless that project's recorded choice allows workspace files; workspace records go where the project chose (or stay on the workspace side) | Plans, progress entries, review records or agent instructions committed to a project branch by default; a skill that writes into a project without asking first |
| Name the rule before bending it | Asked to bend a rule, the agent names the rule and what bending it risks, then proceeds if harmless or pushes back if not; a go-ahead for one question is not read as approval for something else that was flagged | A short instruction ("just commit", "merge it") acted on by skipping a hook, a test or a flagged gap without saying so; a one-time exception that is not recorded as one |
| Give the user what they need now | The hand-back opens with what the work is and what is needed from the user, in plain words; a question can be answered without scrolling; context is sized to how long the user has been away | A bare issue or PR number or other label standing in for a description; "as above" references in a question; walls of repeated text; a hand-back that opens with process |
| Know whether it works | A new mechanism says how anyone will tell whether it helped and when it will be looked at again; an existing mechanism is kept, changed or removed based on what that showed | A mechanism with no way to tell if it helped; a check added after a failure and never revisited; keeping something because it exists |

## ADR Applicability

| ADR | Triggered when | Key requirement |
|---|---|---|
| 0001 — Adopt ADRs | A design decision is made that future agents/humans need to understand | Record it where it will be found. A change to how the parts fit goes into the matching `docs/design.md` section in the same change (Keep one current design). Write an ADR in `docs/decisions/` (context, decision, consequences) when the decision is significant enough that two independent parts could otherwise choose incompatibly; keep implementation detail out of it. An accepted ADR is history: supersede it, do not edit it |
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
| 0016 — Session roots and the user tier | Touching the user tier (`user_tier_install.sh`, `.agent/user_tier_scripts.txt`, the `SessionStart` hook), promoting a script or hook to `~/.claude`, or changing how a script or skill resolves the workspace root or the current project | A session's root is its cwd, resolved through the registry (registered roots before the workspace checkout); an entry may be promoted only if it is inert outside the workspace and every registered root (`registry_require_root`, or a `# user-tier: inert` / `guarded-by:` marker, enforced by `test_user_tier_guard.sh`); skills resolve the workspace root from `~/.claude/agent-workspace-root` **with the `|| echo .` fallback** — never an env var and never `SessionStart` stdout, which is context text, not environment. Status **Provisional** until #317's gz4d acceptance run passes |

## Consequences Map

| If you change... | Also update... |
|---|---|
| A principle in `docs/principles.md` | This review guide; any skills that reference the principle by name |
| An ADR in `docs/decisions/` | This review guide's ADR table |
| A change to how the parts fit (the design picture) | The matching section of `docs/design.md`, in the same change |
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
| Work-plan directory convention | `plan-task`, `review-plan`, `triage-reviews`, `review-code` skills; `docs/design.md` directory tree |
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
