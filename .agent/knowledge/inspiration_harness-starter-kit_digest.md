# Inspiration Digest: harness-starter-kit

Type: inspiration
Last checked: 2026-09-14
Repo: harnessworks/harness-starter-kit @ 62437bec264b2deed83353e8209660d645e86828

First-run survey. Registry interest areas: enforcement-backed instruction
design, safety guardrails for agent workflows, harness bootstrap /
starter-kit UX, prompt-engineering-as-configuration patterns. The registry
comment asks whether "harness engineering" as a discipline has developed
enforcement-backed patterns beyond ours (ADR-0004 / ADR-0005).

## Survey Summary

Harness Starter Kit (MIT, Python, created 2026-05-26) is a **prompt-first
kit for retrofitting agent governance onto an existing repository**. The
user pastes an adoption prompt into their coding agent; the agent clones the
kit as read-only reference, inspects the target repo, and adds "the smallest
useful harness pieces" (agent instructions, drift checks, memory records, an
adoption report). It is explicitly *not* an installer: the target repo is the
source of truth and the kit must never overwrite wholesale. Its working
model is `Harness = Instructions + Constraints + Feedback + Memory +
Evaluation + Governance`, with a decision table mapping a gap to the artifact
type to add and the rule "prefer enforceable constraints and feedback over
more prose".

Short answer to the registry question: the kit has **not** developed an
enforcement hierarchy beyond ADR-0004/0005 — it deliberately stays
observe-only by default and defers pre-commit/CI/runtime-hook enforcement to
an unbuilt "policy proposal" workflow (ROADMAP.md "Policy-Driven
Enforcement"). Where it *is* ahead of us is narrower and concrete: it
mechanically validates its **memory** artifacts (failure records must cite a
real, existing detection check; implementation diffs without an ADR diff
trigger a warning), and it ships a **coupling diagnostic** that finds rules
without checks and checks without rules. Those are enforcement-backed
versions of our "Capture decisions" and "A change includes its consequences"
principles, which we enforce only by prose and periodic `/audit-workspace`.

### Governance model

- `AGENTS.md` at root (~200 lines): core rules, command routing, a "Project
  Analysis Rule" (read these dirs first), validation commands, commit/PR
  rules. Same shape as ours; no CLAUDE.md layering, no framework adapters
  beyond the agent-skills package (below).
- Ten ADRs in `docs/decisions/` and eleven failure records in
  `docs/failures/` for the kit itself — it dogfoods its own memory model.
- Approval gates are prose: "do not delete, archive, move, or rename files
  without explicit approval for the specific files". No hook enforces them.
- ADR-0003 (gate placement): every check is classified as **normal
  completion gate**, **focused**, or **manual**, with a written reason.
  Deterministic/local/fast checks must be in the normal gate or justify why
  not; live-API/credential/slow checks stay out. Adoption reports must carry
  these fields and `check_effectiveness_plan.py` validates their presence.
- Upstream issue #56 (open, unanswered) proposes a **cost-ascending
  artifact ladder** with an enforceability gate: edit an existing
  instruction → extend an existing check → reuse an existing verification
  command → only then add a new script/CI check, stopping at the lightest
  rung that "catches the failure rather than documents it". Note the
  direction is the inverse of our ADR-0005 ("CI-first, then pull checks
  closer to the point of work"); both agree that prose-only rules are not
  rules.

### Skills / commands

- Five prompt-convention commands in `commands/*.md`: `/harness adopt`
  (first-time, may edit), `/harness doctor` (diagnostic, no edits),
  `/harness update` (pull newer kit, selectively patch), `/harness refresh`
  (find stale/duplicated guidance already in the target), `/harness review`
  (adversarial review of current diff; `review sub-agent` variant spawns a
  read-only reviewer). Each command doc has a **Required Report Format**
  block and a **Safety Rules** block — the report format is the
  prompt-engineering-as-configuration pattern: the report shape *is* the
  contract, and tests assert the wording (`tests/test_repository_hygiene.py`).
- `agent-skills/` packages the same workflows as a Codex plugin and a Claude
  Code plugin (marketplace install). One router skill (`harness/SKILL.md`)
  dispatches on subcommand to bundled `references/*.md`, preferring the
  canonical `commands/*.md` from a local kit clone when present.
  `check_agent_skills_package.py` is a CI drift check that keeps the plugin
  from becoming a second source of truth.
- Failure record 0002 is a nice lesson for our subagent patterns: the
  spawned reviewer subagent reported "single-agent fallback" because it
  evaluated tool availability from *its* restricted runtime. Fix: reviewer
  mode and fallback reason are owned by the parent orchestrator; the subagent
  prompt forbids self-assessment of mode. Regression-tested.

### Isolation strategy

Thin. "Isolate agent work safely" in the README means file-boundary
discipline (forbidden paths, generated outputs, secrets kept out of task
flow), not worktrees or containers. Benchmark tasks (`benchmarks/tasks/*.json`)
carry an expected file boundary and a forbidden file boundary that a separate
runner checks. No worktree or sandbox guidance at all — well behind our
ADR-0004 container/worktree layers.

### Identity management

None. No AI signature, no commit identity handling, no per-framework
identity. Commit rules are conventional-commits-if-present.

### Testing approach

- 14 unittest modules; the notable ones are **repository-hygiene tests that
  pin governance wording** (e.g. the "prefer enforceable constraints"
  sentence, reviewer-mode ownership rule) and **golden-fixture tests for
  Doctor output**. That is a cheap way to make prose rules regression-tested
  without an LLM eval.
- `benchmarks/` holds eight deterministic task specs (prompt + file
  boundaries + oracle commands) for an external generic runner
  (`harness-agent-benchmark-runner`). Same idea as our roadmapped
  drill/evals-harness item; smaller.
- Effectiveness is deliberately separated from health: Doctor scores
  repository evidence, and a `task-outcome.yaml` template + effectiveness
  report template are the only path to claiming agent improvement. The kit is
  unusually honest that its own dogfood reports "do not prove" anything.

### CI/CD patterns

- Single workflow `harness-check.yml` (PR + weekly cron): unittest,
  py_compile, then the seven `scripts/check_*.py` drift checks. Decision
  memory runs with `--base <PR base sha>` on PRs. No pre-commit config, no
  branch-protection guidance, no merge-time enforcement beyond the workflow.
- The check scripts are the enforcement substance:
  - `check_failure_memory.py` — every `docs/failures/*.md` must have eight
    sections; the "Detection Or Prevention Check" section must name a
    concrete test/fixture/script path, `make` target, package script, CI
    workflow, or checklist, **and the script verifies the cited path or
    Makefile target actually exists**. Non-committal prose ("should be
    added", "planned", "todo") fails. A "no check is practical" escape
    requires both a concrete blocker and a future review signal.
  - `check_decision_memory.py` — diff against base; if watched
    implementation paths changed and `docs/decisions/**` did not, print the
    trigger question and require an ADR, a citation, or an explanation.
    Rules in `.harness/decision-memory-rules.json`. Warn by default,
    `--fail-on-warning` optional.
  - `check_structure.py` — forbidden filename patterns from
    `.harness/structure-rules.json` (`temp_*`, `*_new.*`, `*_old.*`,
    `*_backup.*`, `*.bak`).
  - `check_docs_drift.py` — stale path references and broken local links in
    docs; `check_encoding_hygiene.py`; `check_effectiveness_plan.py`.
  - `harness_doctor.py` — six-element score plus **coupling findings**:
    Orphan Constraint (check script with no doc/CI binding), Orphan Feedback
    (workflow references a script that does not exist), Unoperationalized
    Memory (failure record without recurrence linkage; records exist but
    AGENTS.md does not route to them), Unevaluated Memory, Ungoverned Change
    Type (no approval path for delete/move/overwrite), Promotion Gap
    (repeated failures never promoted into conventions/checks). Gates
    (`--min-score`, `--fail-on critical-coupling`) are optional and off.

### Documentation patterns

- `docs/` is organised as memory categories: `decisions/`, `failures/`,
  `conventions/`, `domain/`, plus `checklists/`, `templates/`, `theory/`,
  `scoring/`. Agent instructions must route to the memory dirs (Doctor
  scores this).
- Failure records have a fixed schema (Date Observed, Failure Type, Goal,
  What Happened, Why It Failed, Current Replacement, Detection Or Prevention
  Check, Agent Guidance). ADRs add an "Agent Guidance" section and a "Known
  Limits And Follow-Up" section — the latter is a good habit we lack.
- `.harness/source.json` in the *target* repo records which kit commit the
  target was last synced to; `/harness update` diffs against it and
  classifies each kit change as safe candidate / patch carefully / reference
  only / manual review.
- Stack "profiles" (`templates/profiles/<stack>/`: python, typescript,
  nextjs, django, flask, fastapi, spring, android, react, vue, go, rust) are
  reference snippets with merge-only config fragments (`pyproject.harness.toml`,
  `package-scripts.harness.json`, `gitignore.harness.txt`) and a
  `check_harness.py` entry point; each must ship a fixture and smoke test.

### Relevance to the workspace redesign (issue #172)

Nothing here changes the direction of #172, but three pieces map onto it
closely enough to be worth reading before the manifest work lands:

1. **Kit → target propagation is our workspace → manifest problem.** The
   kit's `.harness/source.json` + `/harness update` (record synced commit;
   classify each upstream change; never overwrite; report applied /
   skipped / deferred) is a worked model of "workspace improvements cascade
   to projects" (PRINCIPLES.md) for the M level. A manifest could carry the
   workspace commit it was last reconciled against, and `/onboard-project`
   / `/audit-project` could diff against it instead of re-auditing from
   scratch.
2. **Profiles vs project-type adapters.** Kit profiles are reference-only
   snippets chosen by stack; our adapters are an executable verb contract
   (`setup/sync/validate/build/test/env/...`) chosen by project *shape*.
   These are orthogonal axes (a `single_project` adapter could host a python
   or a go repo). The kit's rule that a profile must ship a fixture + smoke
   test before it is accepted is the same bar we set with
   `validate_adapter.sh` — no new idea, but confirmation.
3. **"Target repo is the source of truth; never inject wholesale"** is the
   kit's founding ADR (0001) and matches the #172 P-X rule (external repos
   never receive agent files). The kit's `/harness refresh` (find stale or
   duplicated guidance already in the target) is the maintenance verb we do
   not have for manifests.

The kit's gate-placement classification (normal / focused / manual) could
become an adapter-level concept: `adapter test` is the normal gate; focused
and manual checks need a home in the manifest's `.project_config`.

## Activity Snapshot

- 113 stars, 8 forks, MIT. Created 2026-05-26; v0.1.7 → v0.1.16 in three
  weeks (2026-06-02 → 2026-06-18), then **no commits, PRs, or releases since
  2026-06-18** (three months at time of survey).
- One dominant author (188 of ~197 commits); three other contributors with
  2–4 commits each (translations, README).
- 14 open issues, all self-filed or good-first-issue placeholders (Rails /
  Laravel / iOS profiles, GitLab CI note, monorepo example). 0 open PRs, 0
  merged PRs and 0 closed issues in the last 30 days. Issue #56 (2026-06-23,
  the enforceability-ladder proposal above) is the only substantive external
  contribution and has no maintainer response.
- Listed in Awesome-AI-Agents and github/awesome-copilot; launch essay on
  dev.to. Recognition without follow-through so far.
- Verdict on tracking: the design is finished enough to be worth this one
  survey; the project looks dormant. Recommend keeping it tracked for one
  more round at low cadence and moving it to "watched, not tracked" if there
  is still no activity.

## Pending Review (2026-09-14 round)

- `failure-memory-with-detection-link` — Adopt a failure-record schema
  (`docs/failures/NNNN-*.md`) whose "Detection Or Prevention Check" section
  is mechanically validated: cited test/script/workflow paths and `make`
  targets must exist, non-committal prose is rejected, and "no check is
  practical" needs a concrete blocker plus a revisit signal. Enforcement-backed
  form of our "A change includes its consequences" and "Test what breaks"
  principles; we currently capture recurring agent mistakes only in ADR
  context sections and memory files. Source: `scripts/check_failure_memory.py`,
  ADR 0004, `docs/failures/000-template.md`. Workspace relevance: **High**.
  (2026-09-14)
- `decision-memory-diff-warning` — Pre-commit/CI check: if watched
  implementation paths (`.agent/scripts/**`, `.claude/skills/**`,
  `.github/workflows/**`, `Makefile`) changed in a PR and `docs/decisions/**`
  did not, print the trigger question and require an ADR, an ADR citation,
  or an explicit "no decision memory needed" line in the PR body. Directly
  enforces "Capture decisions, not just implementations", which today has
  no hook or CI check behind it (ADR-0004: an instruction-only rule will
  eventually be violated). Warn-by-default with
  an opt-in fail flag, rules in a JSON file. Source:
  `scripts/check_decision_memory.py`, `.harness/decision-memory-rules.json`,
  ADR 0002. Workspace relevance: **High**. (2026-09-14)
- `coupling-findings-for-audit-workspace` — Add Doctor's coupling taxonomy
  to `/audit-workspace`: Orphan Constraint (hook/script with no CI or doc
  binding), Orphan Feedback (CI/Makefile references a script that does not
  exist), Unoperationalized Memory (ADR consequences never wired to a check),
  Ungoverned Change Type (no approval path for a destructive class of
  change), Promotion Gap (repeated friction never promoted into a rule or
  check). Our audit already does the first two informally; the taxonomy
  makes findings comparable across runs and could exit nonzero in CI.
  Source: `scripts/harness_doctor.py` `coupling_findings()`, ADR 0007.
  Workspace relevance: **Medium**. (2026-09-14)
- `manifest-source-tracking-and-update` — For #172: give each project
  manifest a `.agent/workspace-source.json` (workspace commit last reconciled
  against) and a `/harness update`-style verb that diffs workspace changes
  since that commit, classifies each as safe candidate / patch carefully /
  reference only / manual review, never overwrites, and reports applied /
  skipped / deferred. Plus a `refresh` verb that finds stale or duplicated
  guidance already in the manifest. Concrete model for "workspace
  improvements cascade to projects" at the M level. Source:
  `commands/harness-update.md`, `commands/harness-refresh.md`. Workspace
  relevance: **High** (for #172 specifically). (2026-09-14)
- `gate-placement-normal-focused-manual` — Require every check added to
  the workspace or an adapter to be classified normal-gate / focused /
  manual with a reason, in the PR template and in `adapter test` docs;
  deterministic local checks must be in the normal gate or justify why not.
  Cheap report-field rule; could later become part of the #172 adapter
  contract. Source: ADR 0003, `docs/checklists/verification-scripts.md`.
  Workspace relevance: **Medium**. (2026-09-14)
- `adapter-file-drift-check` — CI check that framework adapter files
  (`CLAUDE.md`, `CODEX.md`, `.github/copilot-instructions.md`, Gemini
  instructions) stay thin routers over `AGENTS.md` and do not restate or
  contradict it, modelled on `check_agent_skills_package.py` which keeps the
  kit's Codex/Claude plugin from becoming a second source of truth. Also
  covers the generated `/make_*` skills. Source:
  `scripts/check_agent_skills_package.py`, ADR 0008. Workspace relevance:
  **Medium**. (2026-09-14)
- `governance-wording-regression-tests` — Pin load-bearing sentences in
  AGENTS.md / PRINCIPLES.md / skill files with plain unit tests
  (`tests/test_repository_hygiene.py` pattern) so a well-meaning edit cannot
  silently drop a rule. Lighter than the roadmapped drill/evals harness;
  complements it. Source: `tests/test_repository_hygiene.py`. Workspace
  relevance: **Medium**. (2026-09-14)
- `structure-rules-forbidden-filenames` — Pre-commit hook rejecting
  `temp_*`, `*_new.*`, `*_old.*`, `*_backup.*`, `*.bak` outside scratchpad,
  from a small JSON rules file. Mechanical form of the "Workspace
  Cleanliness" rule. Source: `scripts/check_structure.py`,
  `.harness/structure-rules.json`. Workspace relevance: **Low**.
  (2026-09-14)
- `enforceability-ladder-vs-adr-0005` — Informational: upstream issue #56
  proposes a cost-ascending ladder (edit instruction → extend existing check
  → reuse verification command → new script/CI) gated by "does it catch the
  failure or only document it". Our ADR-0005 is strength-ascending
  (CI-first, then pull closer). Worth a one-paragraph note in ADR-0005 or the
  principles review guide acknowledging the alternative and why we chose
  CI-first; no behaviour change. Source: harnessworks/harness-starter-kit#56.
  Workspace relevance: **Low**. (2026-09-14)
- `benchmark-task-json-boundaries` — Repo-owned benchmark task specs
  (prompt + expected file boundary + forbidden file boundary + oracle
  commands) consumed by a generic external runner. Overlaps the existing
  roadmapped drill/evals-harness item; only the file-boundary oracle is new.
  Source: `benchmarks/tasks/*.json`, `benchmarks/README.md`. Workspace
  relevance: **Low**. (2026-09-14)

## Roadmapped

(none yet — awaiting triage)

## Skipped

(none yet — awaiting triage)

## Deferred

(none yet — awaiting triage)
