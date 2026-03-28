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

## Approach

### 1. Create a diff classifier knowledge doc

Add `.agent/knowledge/review_depth_classification.md` with:

- **Risk signal taxonomy**: diff size (lines changed), file count, file types
  touched (scripts vs docs vs config), whether tests are included, whether
  the change touches enforcement (hooks, CI, branch protection)
- **Three depth tiers**:
  - **Light** (<50 changed lines, ≤3 files, no enforcement files): Static
    analysis only. Skip governance deep-dive and plan drift. Produce a
    minimal report.
  - **Standard** (50-199 changed lines, or 4-10 files, or any enforcement
    file): All 3 specialists run once. Current behavior.
  - **Deep** (200+ changed lines, or 10+ files, or cross-layer changes):
    All 3 specialists + adversarial pass. Adversarial pass re-reviews the
    combined findings from a fresh perspective, looking for missed issues
    and challenging the other specialists' conclusions.
- **Override rules**: Enforcement files (hooks, CI configs, branch protection)
  always bump to at least Standard. Security-relevant changes (auth,
  permissions, secrets handling) always bump to Deep.
- **Tier promotion logic**: Any single signal at a higher tier promotes the
  entire review to that tier.

### 2. Add an adversarial review specialist

Add a 4th specialist to `review-code` that only activates at Deep tier:

- **Adversarial Specialist**: Launched as a fresh subagent with no context
  from the other specialists. Reads the diff and full files independently.
  Focuses on: missed edge cases, security implications, assumption
  violations, subtle bugs that pattern-matching reviewers miss. Reports
  findings in the same format as other specialists.

### 3. Modify review-code skill to use depth tiers

Update `.claude/skills/review-code/SKILL.md`:

- **After step 1** (Gather PR context): Add a new step "Classify review
  depth" that applies the risk signals from the knowledge doc to determine
  the tier (Light/Standard/Deep).
- **Step 4** (Dispatch specialists): Conditionally dispatch based on tier:
  - Light: static analysis only
  - Standard: static analysis + governance + plan drift (current behavior)
  - Deep: all 3 + adversarial specialist
- **Step 6** (Report): Add the tier to the report header so the user sees
  why a particular depth was chosen. Include the risk signals that
  determined the tier.
- **User override**: Document that the user can request a specific tier
  (e.g., `/review-code 42 --depth deep`) to override the automatic
  classification. The skill text should note this as an option but the
  classifier determines the default.

### 4. Update the report format

Add to the report header:

```markdown
**Review depth**: <Light|Standard|Deep> (reason: <primary signal>)
```

For Light reviews, use a condensed report format — just static analysis
findings and a one-line governance note ("No governance concerns for a
change of this scope").

### 5. Update consequences

- Update `principles_review_guide.md` consequences map: "If you change
  review-code skill → also update review_depth_classification.md"
- Update `ROADMAP.md`: mark #47 as "in progress"

## Files to Change

| File | Change |
|------|--------|
| `.agent/knowledge/review_depth_classification.md` | **New** — risk signal taxonomy, tier definitions, override rules |
| `.claude/skills/review-code/SKILL.md` | Add depth classification step, conditional specialist dispatch, adversarial specialist, updated report format |
| `.agent/knowledge/principles_review_guide.md` | Add consequence entry for review depth doc |
| `docs/ROADMAP.md` | Mark #47 as in progress |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Three tiers is the minimum useful granularity. Light skips unnecessary work; Deep adds scrutiny only when warranted. No speculative features. |
| Improve incrementally | Adds one new concept (depth tiers) to the existing skill. Doesn't restructure specialists or change the report pipeline. |
| A change includes its consequences | Consequences map updated. Roadmap updated. No tests to update (skills are not programmatically tested yet — tracked in #28). |
| Human control and transparency | Tier and reasoning shown in report header. User can override with --depth flag. |
| Enforcement over documentation | The tier logic lives in the skill instructions (enforced by the agent reading the skill), not in a standalone doc that could be ignored. The knowledge doc is a reference, not standalone enforcement. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0001 — Adopt ADRs | No | This is an enhancement to an existing skill, not a new design decision. The 5-layer architecture is already documented in the roadmap. |
| 0006 — Shared AGENTS.md | No | Changes are to Claude Code skill files, not shared agent instructions. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| review-code skill | principles_review_guide.md consequences map | Yes (step 5) |
| review-code skill | ROADMAP.md status | Yes (step 5) |
| review-code skill | Non-Claude adapters | No — review-code is Claude Code-specific |

## Open Questions

None — the issue, roadmap, and 5-layer architecture provide clear direction.

## Estimated Scope

Single PR. Four files changed (one new). The knowledge doc and skill update
are the bulk of the work; consequences updates are mechanical.
