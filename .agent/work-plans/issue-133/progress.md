---
issue: 133
---

# Issue #133 — cross_model_review.sh fails when invoked outside target repo worktree

## Plan
**Status**: complete
**When**: 2026-04-05 20:45
**By**: Claude Code Agent (claude-opus-4-6)

Plan file: `.agent/work-plans/issue-133/plan.md`.

Four targeted fixes: add `--repo` and `--work-dir` flags for explicit repo/artifact targeting, fix issue number extraction regex, and add empty diff guard with error surfacing.

## Implementation
**Status**: complete
**When**: 2026-04-05 21:00
**By**: Claude Code Agent (claude-opus-4-6)

All four fixes applied to `cross_model_review.sh`. Updated `review-code` SKILL.md invocation examples and AGENTS.md script reference. Added 14-test suite in `tests/test_cross_model_review.sh` covering argument parsing, issue extraction, artifact placement, and empty diff guard.

## External Review
**Status**: complete
**When**: 2026-04-05 21:20
**By**: Claude Code Agent (claude-opus-4-6)

**PR**: #145 — 1 review(s), 3 valid (all Copilot), 0 false positives
**CI**: all-pass

### Actions
- [x] Remove dead first mock `gh` heredoc in test_repo_flag_accepted
- [x] Fix stderr capture redirection in test_empty_diff_guard
- [x] Add --repo slug validation (exit 2 on invalid pattern)
- [x] Add test for invalid --repo slug (16 tests total now)

## External Review (round 2)
**Status**: complete
**When**: 2026-04-05 21:30
**By**: Claude Code Agent (claude-opus-4-6)

**PR**: #145 — 2 review(s), 2 valid (Copilot round 2), 2 stale (already addressed)
**CI**: all-pass

### Actions
- [x] Move --repo slug validation before gh dependency check (deterministic exit codes)
- [x] Make test_invalid_repo_slug hermetic with setup/mock PATH

## External Review (round 3)
**Status**: complete
**When**: 2026-04-05 21:45
**By**: Claude Code Agent (claude-opus-4-6)

**PR**: #145 — 3 review(s), 3 valid (Copilot round 3), 4 stale (already addressed)
**CI**: all-pass

### Actions
- [x] Add word boundary to close keyword regex (prevents "encloses"/"prefixes" false matches)
- [x] Resolve --work-dir to absolute path via cd/pwd
- [x] Add substring false-positive test cases (19 tests total)

## External Review (round 4)
**Status**: complete
**When**: 2026-04-05 22:00
**By**: Claude Code Agent (claude-opus-4-6)

**PR**: #145 — 4 review(s), 2 valid (Copilot round 4), 7 stale (already addressed)
**CI**: all-pass

### Actions
- [x] Add || true to fallback grep pipeline (pipefail abort on no-match)
- [x] Validate --work-dir existence before cd (clear error instead of cryptic cd failure)
