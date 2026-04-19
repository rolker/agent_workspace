---
issue: 149
---

# Issue #149 — cross_model_review.sh: loose #N fallback routes artifacts to wrong issue when no Closes/Fixes/Resolves keyword

## External Review
**Status**: complete
**When**: 2026-04-19
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #154 — 1 review (Copilot), 4 valid, 0 false positives
**CI**: all 8 checks pass

### Actions
- [x] (must) Separate `gh pr view` failure from empty-body case; distinct error message for auth/network failures — `.agent/scripts/cross_model_review.sh:~253`
- [x] (polish) Narrow `require_value`'s `-*` check to `--*` so `--issue -5` produces the integer-validator's message — `.agent/scripts/cross_model_review.sh:~129`
- [x] (test) Escape `|` in `assert_contains` pattern for "no 'Closes|Fixes|Resolves...'" — `.agent/scripts/tests/test_cross_model_review.sh:488`
- [x] (test) Assert `--json body` is not called when `--issue` is passed — `.agent/scripts/tests/test_cross_model_review.sh:407`
