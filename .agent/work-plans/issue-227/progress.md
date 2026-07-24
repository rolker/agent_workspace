---
issue: 227
---

# Issue #227 — Multi-tenant hosting: projects/<name>/ discovery alongside legacy project/ symlink (#172 step 2)

## External Review
**Status**: complete
**When**: 2026-07-24 09:45
**By**: Claude Code Agent (claude-fable-5)

**PR**: #232 — 1 review (Copilot), 1 valid, 1 false positive
**CI**: all-pass (lint, docs validation, adapter contract ×2)

### Actions
- [x] Fix: worktree_create.sh — for registry-selected projects, use the raw
  registry name as REPO_SLUG instead of sanitizing `.`/`-` to `_`; the
  registry charset (`[A-Za-z0-9][A-Za-z0-9._-]*`) is already a subset of
  what `wt_project_base` accepts, and `enter`/`remove --repo <name>` locate
  the worktree by the raw name. Reject `..` inside registry names (bash +
  python parsers) so `wt_project_base`'s path-traversal rule can never be
  hit by a registered name. Add a test with a dashed project name.
- [x] No action: adapter `set -- ${ARGS[@]+"${ARGS[@]}"}` quoting concern is
  a false positive — the inner expansion is quoted (standard empty-array
  idiom, verified: "a b" and "c*" survive intact; same idiom used in
  test_adapter.sh / test_project_registry.sh).

## External Review (round 2)
**Status**: complete
**When**: 2026-07-24 10:05
**By**: Claude Code Agent (claude-fable-5)

**PR**: #232 — 2 reviews total; round 2 (head e9950b5): 2 comments, 2 valid
**CI**: all-pass

### Actions
- [x] Fix: dashboard.sh — escape the dot in all three `sed 's|.git$||'`
  slug-stripping pipelines (lines 386/390/397); unescaped `.` makes the
  pattern strip 4 chars from repo names ending in "git" even without a
  literal `.git` suffix. Two occurrences are pre-existing, one was added
  by this PR — fix all three.
- [x] Fix: dashboard.sh — clear REGISTRY_ENTRIES in the parse-error handler
  so later sections (sync, registered-projects report, GitHub queries)
  don't act on a partial project list; the health-check failure banner
  carries the diagnosis.
