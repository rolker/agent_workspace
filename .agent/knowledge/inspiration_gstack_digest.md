# Inspiration Digest: gstack

Type: inspiration
Last checked: 2026-03-21
Repo: garrytan/gstack @ 709bed9f4d7d419ef4f806f8b3e91fa53f6c0945

## Survey Summary

gstack is an opinionated Claude Code skills framework that organizes AI-assisted
development into role-based slash commands (CEO, eng manager, designer, QA lead,
release engineer). 21 skills, TypeScript/Bun-based, MIT license.

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
- **Calibration**: File for reasonable-input-unexpected-error. Don't file for
  user's own app bugs, network errors, auth failures.
- **Feedback loop**: Agents report friction -> reports accumulate locally ->
  developer forks gstack -> fixes issues using pre-written reports -> opens PR.
- **Key innovation**: Agents self-report tooling friction with reproduction steps
  pre-written. Barrier to contribution is removed.

## Activity Snapshot

- 20 open issues, 20 open PRs (very active, ~10 days old project)
- Notable open: multi-host adapter RFC (#289), skill namespace pollution (#267),
  skill chain state detection broken (#280), Windows browse issues (#276)
- Notable merged: adversarial spec review loop (v0.9.1.0), multi-agent support
  (v0.9.0), safety hook skills (v0.7.1), test failure ownership triage,
  CEO review handoff context, test coverage catalog
- Rapid versioning: v0.7.x -> v0.9.5.x in ~10 days

## Pending Review

- `review-log-system` — JSONL-based review tracking with staleness detection and readiness dashboard (2026-03-21)
- `fix-first-heuristic` — AUTO-FIX mechanical issues, ASK for judgment calls in review workflow (2026-03-21)
- `diff-aware-qa` — QA that auto-detects affected pages from branch changes (2026-03-21)
- `cognitive-patterns-for-review` — Role-specific cognitive pattern lists (15-18 per role) guiding review personas (2026-03-21)
- `adversarial-spec-review` — Independent subagent for adversarial spec review scoring on 5 dimensions (2026-03-21)
- `scope-mode-selection` — Four explicit scope modes (expand/selective/hold/reduce) for planning reviews (2026-03-21)
- `safety-hooks-careful-freeze` — PreToolUse hooks for destructive command warnings and edit boundary enforcement (2026-03-21)
- `agent-friction-reporting` — "See something, say something" — agents self-report tooling friction with field reports (2026-03-21)
- `completeness-principle` — "Boil the lake" — prefer complete implementation when AI compresses cost (2026-03-21)
- `skill-chaining-pipeline` — Structured skill pipeline where each stage reads outputs from previous stages (2026-03-21)
- `design-review-ai-slop-detection` — Explicit AI slop detection in design review (generic cards, hero sections) (2026-03-21)

## Issued

(none yet)

## Skipped

(none yet)

## Deferred

(none yet)
