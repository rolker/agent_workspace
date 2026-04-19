# Inspiration Digest: gstack

Type: inspiration
Last checked: 2026-04-19
Repo: garrytan/gstack @ 22a4451e0edb13fd67c1900537f8b106d025f2a3
Previously checked: 2026-03-31 @ db35b8e

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

## Roadmapped

- `cross-project-retrospective` — Cross-workspace retrospective analyzing friction patterns across repos, starting with fork sources (2026-03-31)
- `test-coverage-catalog` — Shared audit of test status across skills and scripts as dashboard layer (2026-03-31)

## Skipped

- `/autoplan` — Automated plan generation pipeline; already covered by workflow templates from #88 (2026-03-31)
- `gstack-multi-host-platform` — Declarative multi-host platform + OpenCode/Slate/Cursor/OpenClaw integration (#793, #816, #832). We're Claude Code–focused; multi-host targeting isn't our concern (2026-04-19)
- `gstack-browser-data-platform` — Browser data platform for AI agents (#907). Gstack domain, not ours (2026-04-19)
- `gstack-team-install-mode` — Team-friendly install mode (#809). Solo-user here (2026-04-19)
- `gstack-security-waves` — Security fix waves 1/3 (#810, #988). Gstack-specific vulnerabilities (2026-04-19)
- `gstack-design-html` — /design-html from any starting point (#734). Gstack domain (2026-04-19)
- `gstack-aquavoice-triggers` — Voice-friendly skill triggers for AquaVoice (v0.14.6.0). Gstack domain (2026-04-19)
- `gstack-cookie-picker` — Cookie picker auth token leak fix (#904). Gstack domain (2026-04-19)
- `gstack-plan-devex-review` — New /plan-devex-review persona (#784). Pattern interesting but not a current need; no analogue motivated in daddy_camp (2026-04-19)

## Deferred

- `deploy-pipeline-automation` — /land-and-deploy + /canary + /benchmark full deploy pipeline (2026-03-22)
- `cross-model-outside-voices` — Using second model for design critique and plan review; investigate Codex as reviewer separately (2026-03-31)
- `gstack-recursive-self-improvement` — "Recursive self-improvement — operational learning + full skill wiring" (#647). Title ambiguous; concept may map to our "Copilot learning loop" but needs investigation before triaging. Revisit next run (2026-04-19)
- `gstack-relationship-closing` — Office-hours adapts to repeat users (#937). Memory/relationship layer; may become relevant if multi-session agent memory evolves. Revisit (2026-04-19)

## Changelog (2026-03-31 → 2026-04-19)

55 commits, 300 files. v0.11.6.0 → v1.3.0.0+. Very active; ~30 versioned
releases in 19 days. Major themes:

### Session intelligence and context

- **v0.15.0.0 (#733)** — Session Intelligence Layer: /checkpoint + /health + context recovery
- **v1.0.1.0 (#1064)** — Renamed /checkpoint → /context-save + /context-restore
- **v0.18.1.0 (#1030)** — Context rot defense for /ship: subagent isolation, clean step numbering

### Review quality and reliability

- **v0.15.2.0 (#760)** — Adaptive gating + cross-review dedup for review army
- **v0.15.6.1 (#804)** — Anti-skip rule for all review skills (forces reviews to actually run)
- **v1.3.0.0 (#1040)** — Open agents learnings + cross-model benchmark skill

### UX for agent-user interactions

- **v0.17.0.0 (#1000)** — UX behavioral foundations + ux-audit command
- **v1.1.2.0 (#1065)** — Mode-posture energy fix for /plan-ceo-review and /office-hours: generic writing-style rules were flattening distinct mode personalities (expansion / forcing / wild) into diagnostic-pain framing. Fix uses paired examples + gate-tier tests so regression can't silently ship

### Permission prompt friction

- **v0.15.12.0 (#993)** — Avoid tilde-in-assignment to silence Claude Code permission prompts

### Multi-host platform (out of scope for us)

- **v0.15.5.0 (#793)** — Declarative multi-host + OpenCode, Slate, Cursor, OpenClaw
- **v0.15.9.0 (#816)** — OpenClaw integration v2: prompt is the bridge
- **v0.15.10.0 (#832)** — Native OpenClaw skills + ClaHub publishing
- **v0.18.0.0 (#1005)** — Confusion Protocol, Hermes + GBrain hosts, brain-first resolver

### New skills and roles

- **v0.15.3.0 (#784)** — /plan-devex-review + /devex-review
- **v0.16.0.0 (#907)** — Browser data platform for AI agents
- **v0.13.8.0 (#647)** — Recursive self-improvement: operational learning + full skill wiring

### Meta / release engineering

- **v1.0.0.0 (#1039)** — gstack v1: simpler prompts + real LOC receipts
- **v0.15.15.1 (#868)** — Pair-agent tunnel 15-second drop fix
- **v1.1.1.0 (#1063)** — Detect + repair VERSION/package.json drift in /ship

## Pending roadmap add (after PR #157 merges)

These items were triaged this run but not added to docs/ROADMAP.md "To
Consider" yet because PR #157 is actively reshaping that section. Append
once #157 lands.

- `gstack-session-intelligence-layer` — **To Consider** — Session Intelligence
  Layer pattern from gstack v0.15.0.0 (#733): /checkpoint + /health + context
  recovery. Direct match for daddy_camp's attention-handoff concern (see also
  per-session context card from ros2 digest). Investigate the /health pattern
  specifically — status check for a session without switching into it
- `gstack-adaptive-gating-review-dedup` — **To Consider** — Multi-specialist
  review dedup + adaptive gating from gstack v0.15.2.0 (#760). Feeds
  /review-code refinement; complements silence-filter pattern we already have
- `gstack-anti-skip-rule-for-reviews` — **To Consider** — Forces review skills
  to actually execute their checks rather than claim success. Reliability
  pattern from gstack v0.15.6.1 (#804); directly applicable to /review-code
  when under time pressure
- `gstack-ux-behavioral-foundations` — **To Consider** — UX foundations + ux-audit
  command from gstack v0.17.0.0 (#1000). Intersects with CLI-first principle
  from 2026-04-19 session
- `gstack-mode-posture-preservation` — **To Consider** — Paired-examples
  pattern + gate-tier tests for mode-specific posture preservation (gstack
  v1.1.2.0, #1065). Audit our scope-mode (#56) and brainstorm multi-level
  (#71) skills for similar flatten-risk; add judge-rubric tests

## Tightened interest_areas (2026-04-19)

Updated in registry same PR. Dropped "browser-based QA" and
de-emphasized release engineering; added "session and context management"
and "agent-user UX patterns". See inspiration_registry.yml for comments
explaining the change.
