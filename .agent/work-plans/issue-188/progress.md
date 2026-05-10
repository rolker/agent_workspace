---
issue: 188
---

# Issue #188 — /start-task: $ARGUMENTS quoting breaks every multi-flag invocation

## Plan
**Status**: complete
**When**: 2026-05-09 17:30
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-188/plan.md`.

Drop the quotes around `$ARGUMENTS` in `start-task/SKILL.md` (Option C
from `/review-issue` discussion); rewrite "Argument handling" honestly;
add embedded-whitespace bullet to "When not to use"; add manual-
verification procedure (same pattern as merge_pr.sh in #186). Single
file, ~30 LOC. No Open Questions — design resolved during issue review.

## Plan Review
**Status**: complete
**When**: 2026-05-09 17:45
**By**: Claude Code Agent (claude-opus-4-7)

Three findings — one substantive, two minor:

1. **Glob expansion footgun** (substantive): unquoted `$ARGUMENTS`
   enables glob expansion on values containing `*`, `?`, `[`, `]`
   (e.g. `--branch main*`, `--plan-file /tmp/*.md`). Plan accepts
   this implicitly. Recommend either bracketing the invocation with
   `set -f` / `set +f` (small + robust) or documenting the
   limitation alongside the embedded-whitespace one. Lean `set -f`.
2. **"verified via grep" claim was unverified** at the time the
   plan was written; turned out correct on actual verification.
   Minor process note.
3. **Manual verification section placement and content** not pinned
   down in the plan; reasonable defaults exist (after "Argument
   handling"; cover --issue+--type and --skill+--type cases).
   Resolvable inline during implement.

Recommended action before implement: resolve finding #1 (glob
handling). Findings #2 and #3 close themselves during execution.
