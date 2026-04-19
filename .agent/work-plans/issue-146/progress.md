---
issue: 146
---

# Issue #146 — merge_pr.sh fails to detect worktrees when invoked from inside a worktree

## External Review
**Status**: complete
**When**: 2026-04-19
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #155 — 1 review (Copilot), 1 valid, 0 false positives
**CI**: all 8 checks pass

### Actions
- [ ] Capture initial branch via `git symbolic-ref --short HEAD` and check out by that instead of hardcoded `main`/`master` — `.agent/scripts/tests/test_merge_pr_root_resolution.sh:~27`
