# Review Depth Classification

How to determine the appropriate review depth for a PR. Used by the
`review-code` skill to scale review effort to change risk.

## Risk Signals

Collect these from PR metadata (`gh pr view` output):

| Signal | Source | How to measure |
|--------|--------|----------------|
| Lines changed | `additions + deletions` | Total lines added and removed |
| File count | `files` array length | Number of files in the diff |
| File types | File paths | Categorize each file (see below) |
| Override triggers | File paths | Check against override-trigger list |
| Tests included | File paths | Whether the diff includes files in `test/`, `tests/`, or named `test_*`, `*_test.*` — absence of tests for code changes is a risk signal (does not affect tier, but noted in review) |

### File type categories

| Category | Examples |
|----------|---------|
| Code | `.py`, `.cpp`, `.hpp`, `.sh`, `.js`, `.ts` |
| Config | `.yaml`, `.yml`, `.json`, `.toml`, `.xml` |
| Documentation | `.md`, `.rst`, `.txt` |
| Enforcement | See override-trigger list below |
| Governance | See override-trigger list below |
| Test | Files in `test/`, `tests/`, or named `test_*`, `*_test.*` |

## Depth Tiers

### Light

**Criteria**: All of the following:
- <50 changed lines (additions + deletions)
- ≤3 files
- No override-trigger files

**Specialists dispatched**:
- Static analysis only

**Report format**: Condensed — static analysis findings plus a one-line
governance note ("No governance concerns for a change of this scope").

### Standard

**Criteria**: Any of the following (and no Deep triggers):
- 50–199 changed lines
- 4–9 files
- Any override-trigger file present

**Specialists dispatched**:
- Static analysis
- Governance
- Plan drift
- Claude adversarial (fresh — no context from other specialists)

**Report format**: Full report with all sections.

### Deep

**Criteria**: Any of the following:
- 200+ changed lines
- 10+ files
- Cross-layer changes (files in both workspace and project directories)
- Any Deep promotion trigger

**Specialists dispatched**:
- Static analysis
- Governance
- Plan drift
- Claude adversarial (fresh — no context from other specialists)
- Gemini adversarial (cross-model, via `cross_model_review.sh` in tmux)

**Report format**: Full report with all sections plus a Cross-Model Review
section for Gemini findings.

## Override-Trigger Files

These files have outsized impact relative to their size. Their presence in a
diff bumps the review to at least **Standard**, regardless of line count or
file count.

### Enforcement files

- `.github/workflows/*.yml` (CI)
- `.pre-commit-config.yaml`
- `.claude/settings.json`, `.claude/hooks/*`
- Branch-protection-as-code files (e.g., `.github/settings.yml`, `.github/branch-protection.yml`)

### Governance files

- `AGENTS.md`, `CLAUDE.md`
- `.github/copilot-instructions.md`
- `.agent/instructions/*.md`
- `docs/PRINCIPLES.md`, `PRINCIPLES.md`
- `docs/decisions/*.md` (ADRs)
- `.claude/skills/*/SKILL.md` (skill definitions)
- `.agent/knowledge/*.md` (knowledge docs)

## Deep Promotion Triggers

These signals always bump the review to **Deep**, regardless of other signals:

- Security-relevant changes: authentication, authorization, permissions,
  secrets handling, credential management, token storage
- Cross-layer changes: files modified in both workspace infrastructure
  (`.agent/`, `.claude/`, `docs/`) and project code simultaneously

## Tier Promotion Logic

1. Start at Light
2. Check all signals — if any signal meets Standard criteria, promote to Standard
3. Check all signals — if any signal meets Deep criteria, promote to Deep
4. Any single signal at a higher tier promotes the entire review

The highest tier triggered wins. There is no mechanism to downgrade a tier
based on other signals.

## User Override

The user can request a specific tier by including a depth keyword in the
`/review-code` invocation:

- `/review-code 42 light` — force Light review
- `/review-code 42 standard` — force Standard review
- `/review-code 42 deep` — force Deep review

User overrides take precedence over automatic classification. This allows
forcing a thorough review on a small change, or a quick review on a large
but low-risk change (e.g., bulk formatting).
