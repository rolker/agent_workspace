# Inspiration Digest: gstack

Type: inspiration
Last checked: 2026-03-22
Repo: garrytan/gstack @ dbd98aff32e3e68f4976dcc38e76a007a2c4a08a

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

## Changelog Since Last Check (v0.9.5.0 - v0.9.9.0)

6 commits, 89 files changed, +12,023/-3,441 lines.

### v0.9.9.0 — Harder Office Hours
- `/office-hours` now pushes back harder on confident founders
- Anti-sycophancy rules: banned phrases like "that's an interesting approach"
- 5 worked pushback patterns (BAD vs GOOD responses)
- Post-Q1 framing check challenges undefined terms and hidden assumptions
- Gated escape hatch: asks 2 more questions before letting founders skip

### v0.9.8.0 — Deploy Pipeline + Pre-Merge Readiness
- **`/land-and-deploy`** — merge, deploy, verify in one command. Auto-detects deploy platform (Fly.io, Render, Vercel, Netlify, Heroku, GH Actions). Offers revert at every failure point.
- **`/canary`** — post-deploy monitoring loop with screenshots, baseline comparison, anomaly alerts
- **`/benchmark`** — performance regression detection: Core Web Vitals, bundle sizes, page load baselines
- **`/setup-deploy`** — one-time deploy config written to CLAUDE.md
- `/review` now includes Performance & Bundle Impact analysis
- E2E tests 3-5x faster (Sonnet for structure, Opus for quality)
- `--retry 2` on all E2E tests

### v0.9.7.0 — Plan File Review Report
- Every plan file now shows which reviews have run (appended markdown table)
- Richer review log data: scope proposals, issue counts, before/after scores

### v0.9.6.0 — Auto-Scaled Adversarial Review
- Review thoroughness scales with diff size automatically
  - <50 lines: skip adversarial
  - 50-199: cross-model adversarial challenge
  - 200+: four full passes (Claude structured, Codex structured, Claude adversarial, Codex adversarial)
- Claude adversarial subagent mode (attacker perspective)
- Dashboard shows "Adversarial" instead of "Codex Review"

### v0.9.5.0 — Builder Ethos (Search Before Building)
- ETHOS.md: four principles (Golden Age, Boil the Lake, Search Before Building, Build for Yourself)
- Three layers of knowledge: tried-and-true, new-and-popular, first-principles
- Every workflow skill now searches before recommending patterns
- "Eureka moments" — when first-principles reasoning reveals conventional wisdom is wrong
- `/office-hours` adds Landscape Awareness phase
- `/plan-eng-review` adds search check for architectural patterns
- `/investigate` searches on hypothesis failure
- CEO review saves context on `/office-hours` handoff

## Activity Snapshot

- 20 open issues, 10 open PRs
- Active development: deploy pipeline, adversarial review, office-hours rigor
- Rapid versioning: v0.9.5.0 -> v0.9.9.0 in ~2 days

## Pending Review

- `deploy-pipeline-automation` — /land-and-deploy + /canary + /benchmark: full merge-to-production-verified pipeline with auto-detected platforms and revert-at-every-step. (2026-03-22)
- `auto-scaled-adversarial-review` — Review thoroughness scales with diff size: skip adversarial for <50 lines, full 4-pass for 200+. Claude adversarial subagent mode. (2026-03-22)
- `anti-sycophancy-patterns` — Hardened office-hours: banned phrases, worked pushback examples (BAD vs GOOD), gated escape hatch. Pattern for making AI skills push back harder. (2026-03-22)
- `plan-file-review-report` — Review status appended directly to plan files as markdown table. Anyone reading the plan sees review status at a glance. (2026-03-22)
- `search-before-building-integration` — Skills search before recommending: runtime built-ins, current best practices, first-principles reasoning. Three-layer knowledge framework. (2026-03-22)

## Issued

- `gstack-inspiration-revisit` — Issue #19: revisit all 11 deferred gstack findings (2026-03-21)

## Skipped

(none)

## Deferred

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
