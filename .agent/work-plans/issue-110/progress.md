---
issue: 110
---

# Issue #110 — Permission allowlist: share workspace-level rules and automate analysis

## Local Review
**Status**: complete
**When**: 2026-04-04 20:15
**By**: Claude Code Agent (claude-opus-4-6)
**Verdict**: changes-requested

**PR**: #132 at `f41db1a`
**Depth**: Deep (reason: 237 lines, enforcement + governance files)
**Must-fix**: 4 | **Suggestions**: 6

### Findings
- [x] (must-fix) `Bash(git add *)` auto-allowed but is Tier 3 write op — removed in `5809636`
- [x] (must-fix) `Bash(.agent/scripts/worktree_remove.sh *)` allows `--force` data-loss path — removed in `5809636`
- [x] (must-fix) `gh api` normalization collapses POST/DELETE into Tier 1 read-only — added write-flag heuristic in `5809636`
- [x] (must-fix) Compound command extraction only checks first command — changed to most-dangerous-component in `5809636`
- [x] (suggestion) Missing `git push --force-with-lease` in deny list — added in `5809636`
- [x] (suggestion) Missing `rm -r *` in deny list — added in `5809636`
- [ ] (suggestion) Path normalization misses scripts/ symlink — `SKILL.md:68`
- [ ] (suggestion) Non-Claude adapter skill lists not updated — consequences gap

## External Review
**Status**: complete
**When**: 2026-04-04 20:45
**By**: Claude Code Agent (claude-opus-4-6)

**PR**: #132 — 2 review(s), 7 valid, 3 false positives
**CI**: all-pass

### Actions
- [x] Replace `$WORKTREE_MAIN_TREE` with `git rev-parse --show-toplevel`
- [x] Update `make` normalization to use 2 tokens for `make <target>`
- [x] Narrow Tier 1 git commands to read-only forms
- [x] Add JSON parse fallback for truncated `input_summary`
- [x] Add `Bash(git fetch)` no-args form to allowlist
- [x] Narrow `git-bug` rules to read-only subcommands
- [x] Update progress.md to reflect current findings
