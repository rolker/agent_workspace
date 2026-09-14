# Inspiration Digest: superpowers

Type: inspiration
Last checked: 2026-09-14
Repo: obra/superpowers
- main @ b36e0829c6d0140e93cfef2ca599b1b07d4a7797 (= v6.3.0, released 2026-08-12)
- dev  @ d3d9d2b (142 ahead / 0 behind main — large unreleased backlog)
- Previously checked: main @ d884ae04edebef577e82ff7c4e143debd0bbec99
  (post-v6.1.1), dev @ 92164e2 on 2026-07-14

## Changelog (2026-07-14 → 2026-09-14)

53 commits, 76 files on main (compare `d884ae0...b36e082`). Two releases:
**v6.2.0** (2026-07-23) and **v6.3.0** (2026-08-12; squash-merged as one
commit, PR #2125). `main` has been static since; `dev` carries 142
unreleased commits, most of them a new `diagnosing-superpowers` skill
(PR #2236) and an intent-preservation rewrite of brainstorming /
writing-plans (PR #2258). Issue tracker: ~30 open, ~80 closed since last
check, ~40 open PRs — very active, heavily agent-authored, and the
maintainer's 94% PR-rejection posture (`CLAUDE.md`) is now the defining
governance artifact of the repo.

### Harness-adapter contract hardened (v6.3.0 + `docs/porting-to-a-new-harness.md`)

Two new harnesses (Devin CLI `.devin-plugin/`, Hermes Agent
`.hermes-plugin/` — the first Python-shaped plugin) and a rewritten
porting guide that reads as a **formal adapter contract**:

- Three components, strictly separated: harness-agnostic skills (source of
  truth, never edited per harness), a per-harness *tool mapping*
  (`references/<harness>-tools.md`), and a per-harness *bootstrap*
  (Shape A shell-hook / Shape B in-process plugin / Shape C
  instructions-file). Routing table picks the shape from what the
  harness exposes.
- **Definition of done** is a checklist ending in a mandatory live
  acceptance test ("Let's make a react todo list" must auto-trigger
  brainstorming) plus per-harness tests in `tests/<harness>/`.
- **Rule 2: everything ships through the harness's own install mechanism;
  never edit the user's files.** A port that can't deliver the bootstrap
  via the install artifact is declared unsupportable rather than worked
  around.
- **Version lockstep across N manifests**: `.version-bump.json` lists
  every per-harness manifest + version field; `scripts/bump-version.sh`
  bumps all of them and audits for stragglers (new test suite
  `tests/version-bump/`). A new manifest not registered there "ships
  stale" — named as a gotcha.
- "You may not need a new directory at all" — some harnesses just load an
  existing manifest; the guide tells porters to check before adding a
  type.

- **Workspace relevance (issue #172 redesign): High — as a design
  reference, not a code port.** This is the same problem as project-type
  adapters, one level up: shared core + thin per-variant layer + a
  contract each variant must satisfy + a validator that proves it. Direct
  analogues worth borrowing when writing the adapter ADRs and
  `validate_adapter.sh` follow-ups: (1) a written *definition of done*
  per adapter including a behavioural acceptance test, not just "verbs
  exist"; (2) the "never write into the user's / upstream repo's files"
  rule maps onto the P-X external-repo level in #172's durability table;
  (3) a `.version-bump.json`-style registry of every per-type manifest
  that a release script must touch is the pattern for keeping
  `.agent/project_types/<type>/` metadata in lockstep; (4) the "does an
  existing type already cover this?" gate before adding a type. Nothing
  here contradicts #172's direction; it corroborates it and supplies
  checklist detail.

### SDD: rulings-not-stalls, plan-scoped workspace, batching, no nesting (v6.2.0 / v6.3.0)

- **Rulings, not stalls** (#2077) — a running plan does not wait on a
  human. Conflicts, ambiguities, plan defects, cap exceptions get a
  ledgered `Ruling: <what> — <why> — <cost if wrong>` and work continues.
  Only four hard stops remain: irreversible/destructive ops,
  security-sensitive actions, side effects outside the worktree (merge,
  push to shared branch, publish), and a plan so broken every path is a
  guess. Every ruling is re-surfaced in a "Rulings I made" section of the
  finish report. Motivating data: a donated session parked 8h48m on a
  question the controller could have decided; 15/15 baseline controllers
  stalled on a seeded conflict.
- **Plan-scoped SDD workspace** (v6.2.0) — `.superpowers/sdd/<plan>/`
  per plan, ledger's first line names its plan, workspace deleted when
  the final review is clean (git history is the durable record). Fixed a
  real cross-plan contamination bug where a second run read the first
  run's ledger. Related open issues #2293/#2267 already want the ledger
  to also carry in-flight dispatches and cross-task discoveries.
- **Batch small same-shape tasks into one dispatch** (#2078) — the
  per-task dispatch+review overhead is only worth paying when the task
  needs its own judgment/tests/review surface. Baseline mined from 174
  SDD sessions.
- **Dispatched subagents never dispatch subagents** (#2059) — a Codex
  audit found one branch review grow to 129 sessions at depth 12, all
  inheriting the root's top-tier model. Implementers and reviewers are
  now leaf nodes.
- **Resume-based fix loop with five-round breaker** (v6.2.0) — rounds 1–3
  resume the original implementer, rounds 4–5 use a fresh implementer on
  a more capable model, then the controller adjudicates. Scoped
  `re-review-prompt.md` checks the fixes only.
- **`Spec:` pointer in plans** (#2086) — SDD reads the spec at setup;
  conflicts resolve against the spec, rulings without a reachable spec
  are marked provisional.

- **Workspace relevance: Medium-high.** The rulings rule is the piece
  that matters most here: our `WORKFORCE_PROTOCOL` and review skills
  have "ask the user" as the default escape hatch, which is exactly the
  stall shape upstream measured. A bounded "decide, ledger, surface at
  the end" rule with the same four hard stops would fit our
  friction-averse multi-agent setup. Batching and the no-nesting rule are
  small additions to the already-roadmapped `sdd-review-economics` item
  rather than new entries. The plan-scoped workspace maps onto our
  per-issue `work-plans/` + `_resolve_work_plans_dir.sh` (we already key
  artifacts by issue; the upstream lesson is "delete at plan end, and
  name the owner in the artifact").

### Brainstorming three-path router + intent preservation (v6.3.0, dev)

- **Spike / Bounded / Architectural** classification announced before
  the first question (#2063). Ceremony scales (spike: 2–3 sentences +
  nod; bounded: short in-chat design; architectural: full spec + plan),
  approval never does. One-way ratchet: hidden complexity upgrades the
  path mid-task, nothing downgrades. Evidence: 65 graded live reps across
  three harnesses. Motivated by a 2-week audit of one person's real Codex
  window (2,240 sessions) showing full-ceremony documents were the wasted
  part, not the approval.
- **dev (#2258, unreleased)**: "Establish Shared Understanding" —
  discover intent, write back understanding separating what was said
  from assumptions, carry it into the design artifact. Approval is bound
  to the stage actually presented: "approval of an idea or feature scope
  does not approve artifacts that do not exist yet." writing-plans now
  asks for plan review before execution-method choice, and honours an
  execution method the user already supplied instead of re-asking.

- **Workspace relevance: Medium.** Our `/plan-task` → `/review-plan`
  pipeline is always full-ceremony; a spike/bounded off-ramp is the
  obvious gap and the `AGENTS.md` "trivial fixes don't need an issue"
  clause is the only scaling we have. The "approval is stage-bound"
  language is convergent with the personal CLAUDE.md rule "a go-ahead
  answers only the question actually asked" — upstream reached the same
  rule from eval data.

### writing-good-tests replaces testing-anti-patterns (v6.2.0)

Rebuilt as a positive two-principle catalog: (1) every test names the
break it catches, (2) every test exercises the real thing. New content
beyond the old anti-patterns list: derive expectations independently of
the code under test (mirror assertions), no change detectors, **behaviour
not text** ("asserting a script/skill/config contains an exact line proves
only that the source is the source" — run it and assert effects; prose for
humans earns no test), test your boundary not the framework's, a
pre-finish **mutation check**, and gate functions before writing a test
body / before adding a mock. Deleting TDD's "Why Order Matters" section
outright measurably degraded test-first behaviour (8/10 → 5/10), so the
arguments were folded into rationalization rows instead.

- **Workspace relevance: Medium-high.** Directly applicable to our
  `test-engineering` skill and to how we test shell scripts and skills:
  several workspace tests grep script text rather than run the script
  (the "string-presence trap" named here). The fold-don't-delete finding
  is also a caution for the roadmapped `skill-carving-token-reduction`
  work — measure before cutting persuasion prose.

### Skills compression sweep, eval-gated (v6.2.0)

Recap / social-proof / benefits sections removed across 12 skills; every
load-bearing argument moved into a rationalization-table row or its point
of use. Each cut micro-tested with subagent probes; the one cut that
degraded behaviour was reworked, not shipped. `finishing-a-development-
branch` no longer offers "discard" in the completion menu (explicit
request + typed `discard` only), PR creation is forge-agnostic, and
**worktree removal never `--force`s on its own** — if `git worktree
remove` refuses on untracked files, show `status --porcelain -uall` and
ask (#2024; two real users lost plan docs to `--force`).

- **Workspace relevance: Low-medium.** Fourth data point for
  `skill-carving-token-reduction` (method: eval-gated cuts, fold into
  tables). The worktree guard is already covered: `worktree_remove.sh`
  refuses on uncommitted changes unless `--force`, and `merge_pr.sh`
  calls it without `--force`. No action.

### diagnosing-superpowers skill (dev, PR #2236 — unreleased)

Evidence-based post-mortem of a session that went wrong: intake → locate
transcripts on disk (Claude Code + Codex formats) → dispatch one analyst
subagent per dimension in parallel (skill-timeline, plan-adherence,
repeated-work, stumbles, quality-evidence, request-conflicts,
cost-and-time) → report with mandatory `path:line` citations → optional
GitHub-issue draft → optional scrubbed bundle export with a scrub + audit
loop until CLEAN. Hard rules: read-only on session files, one transcript
line can be a megabyte (context-safety reference), "you report; you do
not diagnose superpowers".

- **Workspace relevance: Medium.** We have no session-forensics
  capability; `/triage-reviews` and `/review-code` look at diffs, never
  at transcripts. The analyst-per-dimension fan-out and the
  no-citation-no-finding rule are reusable shapes; the transcript
  discovery reference (`references/session-discovery.md`) is the
  concrete part worth reading if we ever build a "why did that agent
  session cost so much" skill. Also relevant to the roadmapped
  `drill-evals-harness` item as a complementary *retrospective* tool.

### Other notable

- **Gemini CLI support restored** (#1959 revert, v6.2.0) — the v6.1.0
  "EOLed by Google" removal was premature; `gemini-tools.md` is back.
  Closes the watch item from last round; our Gemini adapter file was
  never affected.
- **Windows SessionStart hook via `shell: "bash"`** (v6.2.0) — Claude
  Code ≥ 2.1.81 honours a `shell` key on hooks; older versions ignore it.
  Useful fact if our `settings.json` hooks ever need to run on Windows.
- **Codex efficiency campaign** (#2060–#2062) — explicit model+effort on
  every spawn with a config backstop; event-driven bounded waits took
  wait-timeouts from 65–78% to 0%. Codex-specific mechanics; the
  "name the model on every dispatch" rule is already in
  `sdd-review-economics`.
- **Open issues worth a glance**: #2245 (four dispatch checks that
  silently fail — base commit, spawned model, enumerable scope,
  parallel-dispatch isolation), #2286 (verification-before-completion
  never asks where the evidence came from), #2292 ("GREEN measures
  compliance, not outcome" for skill evals), #2280 (per-skill config
  files), #2050 (dispatched subagent committed to main instead of the
  worktree — isolation not enforced). Open PR #2193 extends mandatory
  model naming to all dispatches outside SDD.

### Deferred-item status changes

- `lifecycle-event-hooks` (PR #1461 / issue #1442) — PR #1461 no longer
  in the open list; issue #1442 closed. Nothing shipped under that name.
  Close.
- `harness-neutral-skill-prose` — porting guide now makes the
  skills-name-actions rule explicit and non-negotiable ("never edit skill
  bodies to fit your harness"). Stays deferred; still no Codex/Gemini
  skill use here.
- `worktree-consent-gate` — v6.2.0 removed the *discard* offer and added
  the untracked-file guard; the creation-consent gate itself is
  unchanged. Stays deferred.
- `iron-law-pattern` — v6.2.0's fold-don't-delete eval result is the
  first hard evidence that rationalization tables carry behaviour.
  Stays deferred, note strengthened.

## Pending Review (2026-09-14 round)

- `harness-adapter-contract` — rewritten `docs/porting-to-a-new-harness.md`
  + `.version-bump.json` lockstep as a design reference for #172's
  project-type adapter contract: per-adapter definition of done with a
  behavioural acceptance test, never-write-upstream-files rule for
  external repos, manifest registry a release script must touch,
  "existing type already covers this?" gate (2026-09-14)
- `sdd-rulings-not-stalls` — controller decides non-catastrophic
  conflicts, ledgers `Ruling: what — why — cost if wrong`, surfaces all
  rulings at finish; four hard stops only. Candidate rule for
  `WORKFORCE_PROTOCOL` / review skills' "ask the user" default
  (2026-09-14)
- `writing-good-tests-principles` — name-the-break / exercise-the-real-
  thing catalog, behaviour-not-text rule for script and skill tests,
  mutation check; feed into `test-engineering` and workspace test
  conventions (2026-09-14)
- `brainstorm-three-path-router` — spike/bounded/architectural
  classification with one-way ratchet; stage-bound approval language.
  Candidate off-ramp for the `/plan-task` → `/review-plan` pipeline
  (2026-09-14)
- `session-diagnosis-skill` — dev-branch `diagnosing-superpowers`:
  transcript forensics with analyst-per-dimension fan-out and
  `path:line`-or-nothing findings; complements `drill-evals-harness`
  (2026-09-14)
- `sdd-batching-and-no-nesting` — batch same-shape micro-tasks into one
  dispatch; dispatched subagents never dispatch subagents. Small
  additions to the roadmapped `sdd-review-economics` entry rather than a
  new item (2026-09-14)

## Changelog (2026-05-07 → 2026-07-14)

188 commits, 135 files on main. Two major releases: **v6.0.0**
(2026-06-16) and v6.1.x. The v6 release notes are unusually thorough and
worth reading in full (`gh release view v6.0.0 -R obra/superpowers`).

### SDD review-economics rewrite (v6.0.0 headline)

A long run of cost/quality experiments on real projects reshaped
subagent-driven development's per-task review. Their evals: similar
quality ~2× faster with ~50% fewer tokens. The individual mechanisms are
the portable part:

- **One reviewer per task, two verdicts** — a single task-reviewer prompt
  reads the diff once, returns spec-compliance + quality verdicts, plus a
  "can't verify from the diff" verdict for requirements in untouched code.
  One broad whole-branch review on the best model at the end.
- **Work moves as files, not pasted text** — "a pasted diff parks itself
  permanently in the most expensive context"; `task-brief` and
  `review-package` scripts write task text and diff to files the subagent
  reads.
- **Every dispatch must state its model** — left to choose, controllers
  stopped naming one, and an unnamed model inherits the session's most
  expensive tier (one run put all 26 reviewers on top tier). Convergent
  with ros2's #539 (dispatch defaulted to wrong model tier). Upstream
  *rejected* a dedicated skill for this (PR #1496 closed: "one line in
  your instructions file beats a new skill + eval cost of touching five
  behavior-shaping files") and baked it into SDD templates instead.
- **The controller can't coach reviewers** — real runs caught controllers
  telling reviewers to skip a finding or pre-rate it "Minor at most", and
  the flaw shipped. Suppressing findings and pre-rating severity banned;
  plan-mandated defects get reported for the human to decide.
- **Reviewers are read-only and skeptical of rationales** — no working-tree
  mutation (a reviewer's `git checkout` had orphaned commits); an
  implementer's "left it that way on purpose" doesn't dismiss a finding.
- **Evidence + resume** — findings cite file:line, implementer reports move
  to files with red/green test evidence, and a progress ledger lets a
  context-lost controller resume rather than redo.

- **Workspace relevance**: High. We dispatch review subagents
  (review-code specialists, cross_model_review) and the anti-coaching,
  files-not-paste, mandatory-model, and read-only-reviewer rules are all
  cheap to adopt piecemeal.

### Plan structure upgrades (v6.0.0)

- **Global Constraints block** — rules binding every task (version floors,
  naming, exact values) copied verbatim into the plan so they reach
  implementers/reviewers downstream.
- **Per-task Interfaces block** — what each task consumes/produces, so an
  implementer seeing only its own task knows its neighbors' contracts.
- **Right-sizing guidance** — a task should earn its own test cycle and
  review pass; fold setup/config/docs into the task that needs them. Their
  A/B: one fix round vs two-to-four for control (which also shipped a bug).

- **Workspace relevance**: Medium-high. Direct enhancement candidates for
  our plan-task skill's plan format.

### Writing-skills guidance (v6.0.0 + #1741)

- **Match the Form to the Failure** — a table for picking guidance form: a
  flat "don't do X" works for discipline slips but backfires when the
  problem is output *shape*, where a worked example wins.
- **Micro-Test Wording** — sample a phrasing a handful of times against a
  no-guidance control before committing; run-to-run variance is a warning.

- **Workspace relevance**: Medium. We author skills continuously; this is
  distilled craft knowledge. Resolves the prior
  `writing-skills-script-vs-prose` deferral (that guidance landed as part
  of this).

### Harness-neutral skill prose (v6.0.0, includes merged PR #1486)

Skills rewritten from Claude Code dialect ("use the Task tool", "put it in
CLAUDE.md") to action vocabulary ("dispatch a subagent", "your
instructions file"), with a per-harness tool reference mapping actions to
tools (Claude Code, Codex, Copilot, Gemini, Pi, Antigravity).
`finishing-a-development-branch` went forge-neutral (no hardcoded
`gh pr create`).

- **Workspace relevance**: Medium. Our AGENTS.md + adapter-file structure
  already does the workspace-level version; the *skill-body* neutrality
  pattern applies if our skills ever run under Codex/Gemini (which the
  workspace nominally supports). Resolves the prior
  `cross-platform-skill-compatibility` deferral.

### Token reduction (again — third convergent source)

#1848 compressed the using-superpowers bootstrap, #1847 pruned per-harness
tool-mapping boilerplate, #1932 folded index-style Integration sections
into points of use. Same quarter: gstack carved skills (56% catalog token
cut), ros2 opened #564 to slim AGENTS.md. Three tracked sources
independently attacking always-loaded instruction mass.

- **Workspace relevance**: Feeds the just-roadmapped
  `skill-carving-token-reduction` item; no separate entry needed. The
  convergence itself is the signal.

### Other notable

- **Evals moved to a submodule** (separate repo) — `tests/` now holds
  plugin-code tests, `evals/` skill-behavior tests, split documented in
  `docs/testing.md`. Our roadmapped `drill-evals-harness` item's source
  pointer should follow the submodule when picked up.
- **Gemini CLI support removed as "EOLed by Google" (#1846) then restored
  by revert (#1959)** — churn suggests the EOL claim was wrong or
  premature. Watch only; our Gemini adapter file is unaffected.
- **Visual companion security model** (per-session key, sandboxed file
  server, DNS-rebinding defense) — good patterns if we ever ship a local
  web tool; no current need.
- **testing-anti-patterns reframed as writing-good-tests** (#1935);
  finishing-a-development-branch modernized with a rationalization table
  (#1933).

### Deferred-item status changes

- `subagent-model-reconciliation` — PR #1496 **closed unmerged**; core
  insight adopted differently in v6 (mandatory model naming in SDD
  templates). Resolve into the SDD finding.
- `cross-platform-skill-compatibility` — PR #1486 **merged** + v6
  expansion. Resolved into the harness-neutral finding.
- `evidence-quoted-safety-screen` — issue #1495 **closed** upstream
  without a shipped skill. Close.
- `writing-skills-script-vs-prose` — landed as part of v6 writing-skills
  guidance. Resolved into that finding.
- `lifecycle-event-hooks` (PR #1461) — still open upstream. Stays
  deferred.

## Pending Review (2026-07-14 round)

(none — all items triaged below)

## Roadmapped (2026-07-14 decisions)

Added to ROADMAP.md "To Consider" under "From superpowers (2026-07-14)":

- `sdd-review-economics` (2026-07-14) — also resolves the
  `subagent-model-reconciliation` deferral (PR #1496 closed unmerged;
  insight adopted via mandatory model naming)
- `plan-structure-blocks` (2026-07-14)
- `skill-authoring-guidance` (2026-07-14) — also resolves the
  `writing-skills-script-vs-prose` deferral

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
  (PR #1473 merged). Compare with our existing /review-plan skill.

## Issued (historical, 2026-03-22)

- `skills-as-mandatory-gates` — Issue #26
- `two-stage-subagent-review` — Issue #27
- `headless-integration-tests` — Issue #28
- `verification-before-completion` — Issue #29
- `visual-brainstorming` — Issue #30
- `systematic-debugging-skill` — Issue #31

## Skipped

- `using-superpowers-opt-in-bootstrap` (2026-05-07) — This workspace has no analogous
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
  `subagent-model-reconciliation`; that in turn resolved 2026-07-14 into
  the Roadmapped `sdd-review-economics` item (PR #1496 closed unmerged,
  insight adopted in v6 SDD templates).
- `subagent-model-reconciliation` — **Resolved 2026-07-14** into the
  Roadmapped `sdd-review-economics` item.
- `writing-skills-script-vs-prose` — **Resolved 2026-07-14** into the
  Roadmapped `skill-authoring-guidance` item (landed upstream as Match
  Form to Failure / Micro-Test Wording).
- `lifecycle-event-hooks` (2026-05-07) — PR #1461 / issue #1442 still open
  upstream 2026-07-14. No concrete need today; flag if we ever want
  skill-to-skill reactivity beyond settings.json hooks.
- `lift-agent-into-skill` (2026-05-07) — v5.1.0 pattern. Note for next
  reorganization of `.claude/agents/`; some 1:1 agent→skill pairs in
  this workspace may be inlining candidates.
- `harness-neutral-skill-prose` (2026-07-14) — v6.0.0 action-vocabulary
  rewrite + per-harness tool references. Supersedes the 2026-05-07
  `cross-platform-skill-compatibility` deferral (PR #1486 merged). Our
  skills only run under Claude Code today; revisit if Codex/Gemini skill
  use becomes real.
- `worktree-consent-gate` (2026-05-07) — v5.1.0 pattern. This workspace's
  workflow is friction-averse with 4-5 concurrent agents; auto-creation
  is currently preferred. Native-tool preference also conflicts with our
  cross-runtime stance. Keep on radar if worktree volume becomes a problem.
  (Related v6 change, no action: upstream worktrees moved from a global
  dir into the project — matching the layout we already use.)
- `evidence-quoted-safety-screen` — **Closed 2026-07-14**: issue #1495
  closed upstream without a shipped skill. No local need emerged.
