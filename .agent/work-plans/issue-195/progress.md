---
issue: 195
---

# Issue #195 — claude permissions: allowlist read-only utilities, workspace scripts, git -C; GC settings.local.json

## External Review
**Status**: complete
**When**: 2026-05-10 04:30
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #196 — 1 review (Copilot bot), 8 inline comments, 6 valid, 1 false positive, 2 nuanced
**CI**: all-pass (8 checks)

### Actions
- [ ] Narrow `Bash(command *)` → `Bash(command -v *)`, `Bash(command -V *)` (HIGH: arbitrary-command bypass)
- [ ] Remove `Bash(find *)` (MEDIUM: -exec/-delete)
- [ ] Remove `Bash(.agent/scripts/merge_pr.sh *)`, `Bash(*/.agent/scripts/merge_pr.sh *)`, `Bash(make merge-pr *)`, `Bash(make merge-pr)` (HIGH: backdoors `gh pr merge *` which was explicitly excluded from this PR)
- [ ] Remove `Bash(make test *)`, `Bash(make test)` (MEDIUM: runs arbitrary $TEST_CMD from gitignored config; correct scope is settings.local.json where it already lives)
- [ ] Remove `Bash(make deploy *)`, `Bash(make deploy)`, `Bash(make e2e *)`, `Bash(make e2e)` (LOW: targets do not exist in workspace Makefile — wrong-repo carryover from settings.local.json)
- [ ] Tighten PR/issue body language: "All read-only or output-only" overclaims for `gh_create_issue.sh`/`update_roadmap.sh` (they write state); replace with "checked-in workspace scripts". Acknowledge `awk`/`sed` shell-escape risk explicitly.
- [ ] (Optional) Reply on Copilot comments #5 (`git -C * fetch` — false positive; mirrors existing allowed `git fetch *`) and #7 (`gh_create_issue.sh`/`update_roadmap.sh` — consistent with `worktree_create.sh` precedent).
