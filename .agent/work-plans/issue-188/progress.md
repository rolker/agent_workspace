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

## Implement
**Status**: complete (pending self-test)
**When**: 2026-05-09 18:00
**By**: Claude Code Agent (claude-opus-4-7)

Single commit (`d7b5b80`) — 5 edits to `.claude/skills/start-task/SKILL.md`,
+30/-3 LOC. Pre-commit clean.

### Decisions

Local choices made during implement that weren't pre-decided in the
plan or plan-review. Skim before self-test.

1. **Manual verification section placement: between Steps and Exit
   semantics.** Plan-review finding #3 left this open. Alternatives
   were before "Why not just call EnterWorktree directly?" or at
   the top of file. Chose lifecycle order: Steps → Manual
   verification (proves Steps work) → Exit semantics. The "post-
   action verification" reads naturally after the action it
   verifies.

2. **`set +f` placement: first statement of each branch (not after
   the if/elif/else block).** A trailing `set +f` after the block
   wouldn't fire on the `else exit 1` path. Per-branch placement is
   uniform and exits clean.

3. **Argument-handling rewrite shape: three-paragraph form.** Plan
   said "rewrite to be honest" without prescribing structure. Chose
   intro paragraph + two-bullet limitation list (embedded
   whitespace, shell metacharacters) for readability. Single dense
   paragraph would have been shorter but harder to scan.

4. **Shell-metacharacter framing in the new Argument-handling
   section.** Kept the original advice ("agent should warn the
   user and refuse") but updated framing to acknowledge that
   globbing is now disabled while other metacharacters (`;`, `$`,
   backticks) still warrant care. Honest about residual risk
   instead of implying the bracket solves all sharp edges.

5. **Manual verification: included a "structural check" item.**
   Testing glob suppression against real files would be fragile
   (depends on cwd contents). Inspect-the-source check ("confirm
   `set -f`/`set +f` bracket is intact") is a valid form of
   verification and matches how the workspace already verifies
   other structural properties. Avoids the smoke-test churn issue.

6. **Inline comment about `set +f` placement** in the bash code:
   "Restored in every branch exit" — so future maintainers don't
   wonder why each branch starts with `set +f` rather than seeing
   one trailing line.

### What's next

Self-test: invoke `/start-task --issue <test-N> --type workspace`
or `--skill research --type workspace` from the main tree. Most
realistic test is the next worktree creation in this session — if
that fails, the fix didn't take. The session itself becomes the
dogfood.
