# Plan: Adaptive review depth based on diff size

## Issue

https://github.com/rolker/agent_workspace/issues/47

## Context

The `review-code` skill currently applies the same review depth to every PR
regardless of size — a one-line typo fix gets the same 3-specialist treatment
as a 500-line refactor. This wastes tokens and time on small changes while
providing no extra scrutiny for risky large ones.

The roadmap's 5-layer review architecture places adaptive depth as Layer 1
because all downstream layers (cognitive patterns, fix-first, tracking,
learning) need to know the review depth before they run.

Current review-code flow:
1. Gather PR context
2. Load project context
3. Classify changed files
4. Dispatch 3 specialists (static analysis, governance, plan drift) — always all 3
5. Silence filter
6. Report

### Deviations from original issue

The issue (inspired by gstack) specified "cross-model" review at the 200+ tier.
The original gstack implementation dispatches to different LLM models. Rather
than dismissing this as out of scope, we implement cross-model review by
launching Gemini CLI as an additional adversarial reviewer at Deep tier. This
gives genuine model diversity, not just a fresh context window of the same model.

## Approach

### 1. Create a diff classifier knowledge doc

Add `.agent/knowledge/review_depth_classification.md` with:

- **Risk signal taxonomy**: diff size (lines changed), file count, file types
  touched (scripts vs docs vs config), whether tests are included, whether
  the change touches enforcement or governance files
- **Three depth tiers**:
  - **Light** (<50 changed lines, ≤3 files, no override-trigger files):
    Static analysis only. Skip governance deep-dive and plan drift. Produce
    a minimal report.
  - **Standard** (50-199 changed lines, or 4-10 files, or any override-trigger
    file): All 3 specialists + Claude adversarial specialist (fresh, no
    context from other specialists).
  - **Deep** (200+ changed lines, or 10+ files, or cross-layer changes, or
    security-relevant changes): All 3 specialists + Claude adversarial +
    Gemini adversarial (cross-model, via tmux). Both adversarial reviewers
    run fresh and independently.
- **Override-trigger files** (bump to at least Standard):
  - Enforcement: hooks, CI configs, branch protection
  - Governance: `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`,
    `PRINCIPLES.md`, ADRs in `docs/decisions/`, skill definitions in
    `.claude/skills/`, knowledge docs in `.agent/knowledge/`
- **Deep promotion triggers**: Security-relevant changes (auth, permissions,
  secrets handling) always bump to Deep.
- **Tier promotion logic**: Any single signal at a higher tier promotes the
  entire review to that tier.

### 2. Add a Claude adversarial review specialist

Add a 4th specialist to `review-code` that activates at Standard and Deep:

- **Claude Adversarial Specialist**: Launched as a fresh subagent with no
  context from the other specialists. Reads the diff and full files
  independently. Focuses on: missed edge cases, security implications,
  assumption violations, subtle bugs that pattern-matching reviewers miss.
  Reports findings in the same format as other specialists.

The fresh-context model is deliberate: an independent reviewer that happens
to agree with the governance specialist is more convincing than one told what
to look for. The silence filter handles any duplicate findings.

### 3. Create cross-model review script

Add `.agent/scripts/cross_model_review.sh` for Gemini CLI adversarial review
at Deep tier:

**Interface**:
```bash
.agent/scripts/cross_model_review.sh --pr <N> --repo <repo-slug>
```

**Behavior**:
1. Creates `.agent/scratchpad/reviews/<repo>-<issue-N>/` (repo prefix
   disambiguates workspace vs project issues with the same number)
2. Writes `prompt.md` to that directory containing:
   - The PR diff
   - Review mandate: "You are an adversarial reviewer. Find what others
     missed: edge cases, security, incorrect assumptions, subtle bugs."
   - Output format instructions for parseable findings
3. Writes an empty `findings.md` for Gemini to populate
4. Launches a named tmux session (`review-gemini-<repo>-<N>`) running
   Gemini CLI with the prompt, output directed to `findings.md`
5. Returns the tmux session name and findings file path to stdout

**User visibility**: The tmux session lets the user `tmux attach -t
review-gemini-<repo>-<N>` to monitor progress or provide input if Gemini
needs it. The scratchpad files provide a full audit trail of what was asked
and what was found.

### 4. Modify review-code skill to use depth tiers

Update `.claude/skills/review-code/SKILL.md`:

- **After step 1** (Gather PR context): Add a new step "Classify review
  depth" that applies the risk signals from the knowledge doc to determine
  the tier (Light/Standard/Deep).
- **Step 4** (Dispatch specialists): Conditionally dispatch based on tier:
  - Light: static analysis only
  - Standard: static analysis + governance + plan drift + Claude adversarial
  - Deep: all of Standard + Gemini adversarial (via cross_model_review.sh)
- **Step 6** (Report): Add the tier to the report header so the user sees
  why a particular depth was chosen. Include the risk signals that
  determined the tier. Incorporate Gemini findings into the unified report
  when present.
- **User override**: If the argument contains a depth keyword (e.g.,
  `/review-code 42 deep` or `/review-code 42 light`), use that tier
  instead of the automatic classification.

### 5. Update the report format

Add to the report header:

```markdown
**Review depth**: <Light|Standard|Deep> (reason: <primary signal>)
```

For Light reviews, use a condensed report format — just static analysis
findings and a one-line governance note ("No governance concerns for a
change of this scope").

For Deep reviews, add a cross-model section:

```markdown
### Cross-Model Review (Gemini)

| # | File | Line | Finding |
|---|------|------|---------|
| 1 | `path` | 42 | Description |
```

### 6. Update consequences

- Update `principles_review_guide.md` consequences map: add entries for
  review depth doc and cross-model review script
- Update `ROADMAP.md`: mark #47 as in progress

## Files to Change

| File | Change |
|------|--------|
| `.agent/knowledge/review_depth_classification.md` | **New** — risk signal taxonomy, tier definitions, override-trigger files, promotion rules |
| `.agent/scripts/cross_model_review.sh` | **New** — launches Gemini CLI adversarial review in tmux with scratchpad audit trail |
| `.claude/skills/review-code/SKILL.md` | Add depth classification step, conditional specialist dispatch, Claude adversarial specialist, Gemini integration, updated report format, user override |
| `.agent/knowledge/principles_review_guide.md` | Add consequence entries for new files |
| `docs/ROADMAP.md` | Mark #47 as in progress |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Three tiers is the minimum useful granularity. Light skips unnecessary work; Deep adds cross-model scrutiny only when warranted. Gemini script is minimal — prompt file, tmux launch, findings file. |
| Improve incrementally | Adds depth tiers and adversarial review to the existing skill. Doesn't restructure existing specialists or change the report pipeline. |
| A change includes its consequences | Consequences map updated. Roadmap updated. Script reference table in AGENTS.md needs updating for new script. No tests to update (skills are not programmatically tested yet — tracked in #28). |
| Human control and transparency | Tier and reasoning shown in report header. User can override depth via keyword. tmux session visible for Gemini monitoring. Scratchpad provides audit trail. |
| Enforcement over documentation | Tier logic lives in the skill instructions (enforced by the agent reading the skill). The knowledge doc is a reference that the skill explicitly loads, not a standalone hope. |
| Primary framework first, portability where free | Claude adversarial uses Claude Code subagents (framework-native). Gemini review uses a portable shell script that any framework could invoke. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0001 — Adopt ADRs | No | Enhancement to existing skill; 5-layer architecture already documented in roadmap. |
| 0006 — Shared AGENTS.md | Yes — new script | Add `cross_model_review.sh` to script reference table in AGENTS.md. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| review-code skill | principles_review_guide.md consequences map | Yes (step 6) |
| review-code skill | ROADMAP.md status | Yes (step 6) |
| Add new script | AGENTS.md script reference table | Yes (noted in ADR compliance) |
| review-code skill | Non-Claude adapters | No — review-code is Claude Code-specific |

## Open Questions

None — all review findings resolved through discussion.

## Estimated Scope

Single PR. Five files changed (two new). The knowledge doc, cross-model script,
and skill update are the bulk of the work; consequences updates are mechanical.
