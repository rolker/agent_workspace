---
issue: 255
---

# Issue #255 — Rename worktree scripts' --repo <name> to --project <name> (keep --repo as alias)

## External Review
**Status**: complete
**When**: 2026-09-15 10:20
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #256 — 1 review(s), 3 valid, 0 false positives
**CI**: all-pass

### Actions
- [ ] worktree_enter.sh:171 and worktree_remove.sh:149 — say "Multiple projects registered" (these list project hosting dirs, not git repos)
- [ ] start-task SKILL.md:106 — compatibility note wrongly says worktree_create.sh rejects `--project`; both scripts accept it, `--repo-slug` is only the naming slug
