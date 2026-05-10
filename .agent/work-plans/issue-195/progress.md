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
- [x] Narrow `Bash(command *)` → `Bash(command -v *)`, `Bash(command -V *)` (HIGH: arbitrary-command bypass) — commit f7ace0d
- [x] Remove `Bash(find *)` (MEDIUM: -exec/-delete) — commit f7ace0d
- [x] Remove `Bash(.agent/scripts/merge_pr.sh *)`, `Bash(*/.agent/scripts/merge_pr.sh *)`, `Bash(make merge-pr *)`, `Bash(make merge-pr)` (HIGH: backdoors `gh pr merge *` which was explicitly excluded from this PR) — commit f7ace0d
- [x] Remove `Bash(make test *)`, `Bash(make test)` (MEDIUM: runs arbitrary $TEST_CMD from gitignored config; correct scope is settings.local.json where it already lives) — commit f7ace0d
- [x] Remove `Bash(make deploy *)`, `Bash(make deploy)`, `Bash(make e2e *)`, `Bash(make e2e)` (LOW: targets do not exist in workspace Makefile — wrong-repo carryover from settings.local.json) — commit f7ace0d
- [x] Tighten PR body language: replaced "All read-only or output-only" overclaim with explicit "checked-in workspace scripts" trust-model framing; awk/sed shell-escape risk acknowledged in new "Trust model" section.
- [ ] (Optional) Reply on Copilot comments #5 (`git -C * fetch` — false positive; mirrors existing allowed `git fetch *`) and #7 (`gh_create_issue.sh`/`update_roadmap.sh` — consistent with `worktree_create.sh` precedent).

## External Review (round 2)
**Status**: complete
**When**: 2026-05-10 04:55
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #196 — 2 reviews total, 5 new comments at HEAD `7cf3d59` (round-1 changes verified addressed). 1 valid, 2 re-raised judgment calls, 1 universal-shell concern, 1 consistency suggestion.
**CI**: all-pass (8 checks)

### Actions
- [x] Narrow `Bash(git -C * branch *)` to read-only forms — commit 1a8d2b6.
- [ ] Decide on `awk *` and `sed -n *` (re-raised by Copilot — bot's persistence raises the bar on dismissal). Options: keep with acknowledgment, or move to settings.local.json.
- [ ] (Optional) Add `*/.agent/scripts/gh_create_issue.sh *` and `*/.agent/scripts/update_roadmap.sh *` path variants for consistency with surrounding pattern.
- [ ] (Optional) Add explicit acknowledgment in PR body that `echo`/`printf`/`cat` redirection is a universal shell property, not a property unique to this PR's additions.
