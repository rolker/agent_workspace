# Inspiration Digest: gstack

Type: inspiration
Last checked: 2026-03-31
Repo: garrytan/gstack @ db35b8e

## Survey Summary

gstack is an opinionated Claude Code skills framework that organizes AI-assisted
development into role-based slash commands (CEO, eng manager, designer, QA lead,
release engineer). 25+ skills, TypeScript/Bun-based, MIT license.

### Review & QA Workflow

- **/review**: Staff Engineer persona. Two-pass review (CRITICAL + INFORMATIONAL).
  Fix-First heuristic: AUTO-FIX mechanical issues, ASK for judgment calls. Includes
  scope drift detection, design-review-lite for frontend changes, Greptile comment
  triage, and optional Codex adversarial review.
- **/qa**: QA Lead + Bug-Fix Engineer. Opens real browser (Playwright), finds bugs,
  fixes with atomic commits, re-verifies with screenshots. Three tiers (quick/standard/
  exhaustive). Diff-aware mode auto-detects affected pages from branch changes.
  Auto-generates regression tests for every fix.
- **/qa-only**: Same methodology as /qa but report-only (never edits files).
- **/design-review**: Senior Product Designer. 11 phases from first impression
  through fix loop with before/after screenshots. AI slop detection. Design score
  + AI slop score baselines.
- **Review logs**: JSONL at `~/.gstack/projects/{slug}/{branch}-reviews.jsonl`.
  Each entry records skill, timestamp, status, findings count, commit SHA.
  Staleness detection compares stored SHA to HEAD.
- **Review Readiness Dashboard**: Built into /ship. Shows all review statuses,
  staleness indicators, and CLEARED/NOT CLEARED verdict. Eng review is required
  gate; CEO/design/codex are informational.

### Planning Methodology

- **/office-hours**: YC office hours partner. Two modes: Startup (interrogative,
  six hard questions exposing real vs hypothetical demand) and Builder (generative
  design partner). Produces versioned design docs. "Push twice on each answer" —
  first is polished, real answer comes 2-3 pushes in.
- **/plan-ceo-review**: CEO persona with 18 cognitive patterns. Four scope modes
  (expansion/selective/hold/reduction). Includes adversarial spec review loop via
  independent subagent scoring on 5 dimensions. Error Rescue Map forces explicit
  exception classes and rescue actions.
- **/plan-eng-review**: Senior eng manager with 15 cognitive patterns. Scope
  challenge (8+ files = red flag), architecture review with ASCII diagrams, test
  plan generation, performance review.
- **/plan-design-review**: Senior product designer. 7 review passes each rated
  0-10 and looped until 8+. AI slop detection. Responsive/accessibility checks.
  Edits plan in-place with missing design decisions.
- **Skill chaining**: office-hours -> plan-ceo-review -> plan-eng-review ->
  [build] -> review -> qa -> ship. Each reads outputs from previous skills.
- **Completeness principle ("Boil the Lake")**: AI compresses effort 10-100x,
  so prefer complete implementation over shortcuts when cost is minutes more.

### Release Engineering

- **/ship**: Fully automated release conductor. Merge base -> run tests -> pre-landing
  review -> Greptile triage -> Codex review -> version bump -> CHANGELOG -> cross-doc
  consistency -> TODOS cleanup -> commit & push -> PR creation. Smart versioning:
  auto-decides MICRO/PATCH, asks for MINOR/MAJOR. Multi-gate review readiness.
- **/document-release**: Post-ship documentation updater. Per-file audit of README,
  ARCHITECTURE, CONTRIBUTING, CLAUDE.md, CHANGELOG. Auto-updates factual corrections,
  asks about risky narrative changes.
- **/land-and-deploy**: Post-merge deployment. Auto-detects platform, runs canary
  verification. Offers revert at every failure point.
- **/canary**: Post-deploy monitoring loop. Screenshots, baseline comparison, anomaly alerts.
- **/benchmark**: Performance regression detection. Core Web Vitals, bundle sizes.

### Safety Controls

- **/careful**: PreToolUse hook on Bash. Warns before destructive commands (rm -rf,
  DROP TABLE, git push --force, etc.). User can override. Safe exceptions for
  build artifacts (node_modules, dist, etc.).
- **/freeze**: PreToolUse hook on Edit/Write. Blocks edits outside a specified
  directory. State file at `~/.gstack/freeze-dir.txt`. Returns "deny" not "ask".
- **/guard**: Combination of careful + freeze. Single command for maximum safety.
- **/unfreeze**: Clears freeze boundary.
- Three-tier hierarchy: Light (careful/warn) -> Medium (freeze/block edits) ->
  Heavy (guard/both).

### Agent Friction Reporting ("See Something, Say Something")

- **Contributor mode**: Opt-in via `gstack-config set gstack_contributor true`.
- **Mechanism**: At end of each major workflow step, agent rates experience 0-10.
  If not 10, files a field report to `~/.gstack/contributor-logs/{slug}.md`.
- **Report template**: Title, what tried, what happened, rating, repro steps,
  raw output, "what would make this a 10", date/version/skill metadata.
- **Constraints**: Max 3 reports per session, non-blocking, skip existing slugs.
- **Key innovation**: Agents self-report tooling friction with reproduction steps
  pre-written. Barrier to contribution is removed.

## Changelog Since Last Check (v0.9.9.0 - v0.11.6.0)

68 commits, 291 files changed.

- v0.10.0.0: /autoplan — auto-review pipeline
- v0.10.1.0: Test coverage catalog — shared audit across plan/ship/review
- v0.10.2.0: /retro global — cross-project AI coding retrospective
- v0.11.1.1: Plan files always show review status
- v0.11.2.0: Codex compatibility (1024-char cap, Kiro support)
- v0.11.3.0: Design outside voices — cross-model design critique
- v0.11.4.0: Codex second opinion in /office-hours
- v0.11.6.0: /cso v2 — infrastructure-first security audit
- v0.9.9.1: Cross-model outside voice in plan reviews

## Activity Snapshot

- 700+ issues, very active community
- Rapid versioning: v0.9.9.0 -> v0.11.6.0 in ~9 days
- Multi-model integration (Codex, cross-model critique) is a major theme

## Pending Review

(none)

## Issued

- `auto-scaled-adversarial-review` — Issue #47: adaptive review depth based on diff size (2026-03-22)
- `anti-sycophancy-patterns` — Issue #48: anti-sycophancy patterns for brainstorm/review skills (2026-03-22)
- `plan-file-review-report` — Issue #49: embed review status in work plan files (2026-03-22)
- `search-before-building` — Issue #50: search-before-building step in recommendation skills (2026-03-22)
- `review-log-system` — Issue #51: JSONL review tracking with staleness detection (2026-03-22)
- `fix-first-heuristic` — Issue #52: fix-first heuristic for review skills (2026-03-22)
- `diff-aware-qa` — Issue #53: diff-aware test targeting from branch changes (2026-03-22)
- `cognitive-patterns-for-review` — Issue #54: cognitive pattern lists for review personas (2026-03-22)
- `adversarial-spec-review` — Issue #55: adversarial spec review subagent for plan review (2026-03-22)
- `scope-mode-selection` — Issue #56: explicit scope modes for planning reviews (2026-03-22)
- `safety-hooks-careful-freeze` — Issue #57: PreToolUse safety hooks hierarchy (2026-03-22)
- `agent-friction-reporting` — Issue #58: agent friction self-reporting with field reports (2026-03-22)
- `completeness-principle` — Issue #59: completeness principle for AI-assisted development (2026-03-22)
- `skill-chaining-pipeline` — Issue #60: skill chaining pipeline with handoff context (2026-03-22)
- `design-review-ai-slop-detection` — Issue #61: AI slop detection in design review (2026-03-22)
- `gstack-inspiration-revisit` — Issue #19: revisit all 11 deferred gstack findings (2026-03-21)

## Skipped

(none)

## Roadmapped

- `cross-project-retrospective` — Cross-workspace retrospective analyzing friction patterns across repos, starting with fork sources (2026-03-31)
- `test-coverage-catalog` — Shared audit of test status across skills and scripts as dashboard layer (2026-03-31)

## Skipped

- `/autoplan` — Automated plan generation pipeline; already covered by workflow templates from #88 (2026-03-31)

## Deferred

- `deploy-pipeline-automation` — /land-and-deploy + /canary + /benchmark full deploy pipeline (2026-03-22)
- `cross-model-outside-voices` — Using second model for design critique and plan review; investigate Codex as reviewer separately (2026-03-31)
