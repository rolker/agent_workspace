# Inspiration Digest: cc-harness-skills

Type: inspiration
Last checked: 2026-09-14
Repo: LearnPrompt/cc-harness-skills @ 389965038a38d555008530eb618c80a5ff250883

## Survey Summary

cc-harness-skills is a six-skill "harness pack" (MIT, ~2k lines total,
Python helpers) that packages behaviours reverse-engineered from a
publicly mirrored copy of the Claude Code source into host-agnostic
`SKILL.md` bundles installable in Claude Code, Codex, and OpenClaw
(`cp -R` into the host's skills dir, or `npx skills add`). Each bundle's
`references/source-notes.md` names the internal Claude Code source files
it was distilled from (e.g. `src/services/compact/prompt.ts`,
`src/services/autoDream/`, `src/tools/SleepTool/`). The repo is not a
framework: there is no governance, no hooks, no worktree/isolation
model, no identity handling, and no CI. It is six prompts plus six
trivial scripts plus release/marketing docs.

### Skills / commands

| Slug | What it is | Helper script does |
|---|---|---|
| `verification-gate` | Read-only post-implementation challenge pass; output is findings-first, then **verified / unverified / failed** tri-state; rule "never imply validation ran if it did not" | `git status/diff --stat/--name-only` to JSON |
| `structured-context-compressor` | Nine-section continuation summary (request+intent, concepts, files, errors+fixes, problem solving, **all user messages**, pending, current work, next aligned step) | prints the nine headings |
| `dream-memory` | Periodic consolidation pass: merge topic files, prune stale/contradicted, normalize relative→absolute dates, keep `MEMORY.md` as a one-line-pointer index (caps: 200 lines / 25 KB) | reports index size vs caps, recent topic files |
| `memory-extractor` | Extract durable memories from recent turns into four types: `user`, `feedback`, `project`, `reference`; rule "never store code-state facts that should be re-read from source" | frontmatter manifest of existing topic files |
| `swarm-coordinator` | Coordinator owns planning/routing/synthesis; workers own bounded execution; phases research → synthesis → implementation → verification; "one owner per write surface" | emits a JSON/markdown task board skeleton |
| `kairos-lite` | Bounded proactive loop: schedule/trigger → bounded work → brief → sleep/expire; no background writes without opt-in | emits a cron-style job spec |

The prompts are short (10–25 lines each) and generic; the value is in
the rules they state, not in any mechanism.

### Mapping to workspace categories

- **Governance model**: none. No instruction files, no policy, no
  enforcement. The only "rules" are inside the prompt templates.
- **Skills/commands**: flat `skills/<slug>/{SKILL.md, README.md,
  references/{prompt-template,source-notes}.md, scripts/}` — the same
  three-level progressive-disclosure shape this workspace already
  adopted (ROADMAP row "Progressive skill disclosure", done). Prompt
  bodies live in `references/`, which is the skill-carving direction
  in the ROADMAP's "Skill carving / token reduction" item.
- **Isolation strategy**: none (verification-gate is "read-only by
  default" as a prompt rule only).
- **Identity management**: none.
- **Testing approach**: `skills/check_all.sh` — structural smoke test
  (SKILL.md, `references/`, `scripts/` exist; `py_compile` the helper
  scripts). `TEST_REPORT.md` records a manual "reply AVAILABLE or
  UNAVAILABLE" load test per host via `claude -p` / `openclaw skills
  info` / `codex exec`. No behavioural tests.
- **CI/CD patterns**: no GitHub Actions. Release via `publish_all.sh`
  → ClawHub, plus `.claude-plugin/marketplace.json` for the Claude Code
  plugin marketplace. Semver tag plan documented in `skills/README.md`.
- **Documentation patterns**: per-skill README + bilingual root README.
  Quality signal: root README and `skills/README.md` link to the
  author's local absolute paths (`/Users/carl/Downloads/codegod/...`),
  i.e. broken on GitHub, unfixed across three releases.

### Interest-area assessment

- **Context compression / token reduction**: the nine-section
  continuation template is the only concrete artefact. It is a
  handoff/compaction format, not a token-reduction technique — nothing
  here about carving skill bodies, catalog size, or eval floors. The
  registry comment's hope that this feeds the skill-carving thread is
  not borne out.
- **Verification (evidence-before-claims)**: the tri-state
  verified/unverified/failed vocabulary and "findings before summary"
  are crisp and portable, but the workspace already has stronger
  versions: AGENTS.md "Post-Task Verification", `/review-code`'s
  adversarial specialist, `/triage-reviews`, and ROADMAP row #29
  "Verification-before-completion skill" (superpowers-sourced, planned).
- **Memory management**: the four-type taxonomy, "no code-state facts"
  rule, and index-only `MEMORY.md` with size caps match what Claude
  Code's auto-memory already does for this workspace (the memory index
  is already pointer-style). The engram digest already covers the
  deeper memory questions (authoritative-channel promotion).
- **Multi-agent coordination**: the coordinator/worker split and
  "one owner per write surface" are already how `/review-code`
  orchestrates specialists and how `.agent/WORKFORCE_PROTOCOL.md` and
  the ROADMAP "Subagent review economics" item frame dispatch.
- **Cross-harness portability**: the mechanism is just "same SKILL.md
  copied into three host dirs". The workspace's adapter files
  (`CLAUDE.md`, `CODEX.md`, gemini instructions) already solve the
  harder half (per-framework tool mapping and identity).

### Relevance to the workspace redesign (issue #172)

Nothing here touches project-type adapters, a multi-tenant project
registry, per-project manifests, or role/distro variants. The only
adjacent detail is that every bundle ships a `source-notes.md`
provenance file naming what it was derived from — a small pattern the
`/skill-importer` attribution check already requires in spirit. No
change to the #172 path.

### Provenance caveat

The pack is explicitly distilled from a mirrored copy of Claude Code's
own source (source-notes cite internal `src/...` paths). Any verbatim
import should go through `/skill-importer`'s source/safety check with
that in mind; paraphrasing the *rules* (which are generic) carries no
such concern.

## Activity Snapshot

- 0 open issues, 0 open PRs; 0 issues and 0 PRs ever opened in the repo.
- 232 stars, 62 forks, single author. Created 2026-04-01.
- 10 commits total. Substantive content (all six SKILL.md, prompts,
  scripts) is unchanged since v0.1.0 on 2026-04-01. v0.2.0 (2026-06-13)
  and v0.2.1 (2026-07-10) are README/badges/marketplace/Chinese-README/
  branding-footer only. Last push 2026-07-10.
- The registry's "very active" note (2026-07-14) was wrong at the time
  it was written; the repo is effectively a one-shot drop with a
  marketing refresh.

## Pending Review (2026-09-14 round)

- `verification-tristate-vocabulary` — adopt the explicit
  **verified / unverified / failed** output vocabulary and the "never
  imply validation ran if it did not" rule as a source annotation on
  ROADMAP row #29 (Verification-before-completion skill) and/or the
  `/review-code` adversarial specialist's output contract. Prompt-level
  only; no mechanism to port. Source: `skills/verification-gate/`
  (2026-09-14)
- `nine-section-continuation-summary` — the compaction template
  (esp. "preserve all user messages / corrections that changed
  direction" and "next step aligned to the most recent explicit
  request") as a candidate shape for the `progress.md` top checkpoint
  block / the Session Intelligence Layer `/context-save` item. Source:
  `skills/structured-context-compressor/references/prompt-template.md`
  (2026-09-14)
- `memory-no-code-state-rule` — memory-audit criterion: never store
  code-structure/file-location facts that drift; keep the memory index
  pointer-only with an explicit size cap (200 lines / 25 KB). Overlaps
  the existing engram-sourced "Authoritative-channel promotion" memory
  audit item; candidate to fold in rather than stand alone. Source:
  `skills/dream-memory/`, `skills/memory-extractor/` (2026-09-14)
- `skill-bundle-structural-lint` — a `check_all.sh`-style structural
  check (every skill dir has SKILL.md + expected subdirs; helper
  scripts compile) as a cheap `make validate` / `/audit-workspace`
  addition. The superpowers-sourced "drill / evals harness" roadmap
  item is the behavioural superset. Source: `skills/check_all.sh`
  (2026-09-14)
- `swarm-phase-split` — research → synthesis → implementation →
  verification with one-owner-per-write-surface. Already how
  `/review-code` and WORKFORCE_PROTOCOL work; no delta identified.
  Source: `skills/swarm-coordinator/` (2026-09-14)
- `kairos-proactive-job-spec` — bounded scheduled jobs with expiry.
  Claude Code's native `/loop` and `/schedule` cover this; workspace
  policy avoids unattended daemons. Source: `skills/kairos-lite/`
  (2026-09-14)
- `tracking-status` — the registry comment overstates activity; content
  frozen since 2026-04-01 with no issue tracker. Decide whether to keep
  the entry (changelog mode will be near-empty) or mark it dormant/
  remove it. (2026-09-14)

## Roadmapped

(none yet)

## Skipped

(none yet)

## Deferred

(none yet)
