---
issue: 197
---

# Issue #197 — claude permissions: reduce prompt friction (umbrella) — log truncation, gh_create_pr.sh wrapper, tool-mapping nudge hook

## Local Review
**Status**: complete
**When**: 2026-05-10 05:55
**By**: Claude Code Agent (claude-opus-4-7)
**Verdict**: changes-requested

**PR**: #200 at `20992ab`
**Depth**: Deep (reason: enforcement files + 329 lines + security-relevant)
**Must-fix**: 3 | **Suggestions**: 3

### Findings
- [x] (must-fix) `sed -n 'EXPR' <file>` heuristic uses char-class `[pPdDsSyYqQ;{}]` to detect sed-script vs file path — broken on real filenames. Fixed in 9227e26 by replacing with non-flag-token count (script + file = 2 → block). — `.claude/hooks/block-bash-tool-mapping.sh:178`
- [x] (must-fix) Combined short-flag `-ni` bypasses in-place detection. Fixed in 9227e26: `has_sed_inplace` now matches `-*i*` against any single-dash cluster. — `.claude/hooks/block-bash-tool-mapping.sh:158`
- [x] (must-fix) Bare `find <path>` blocks broader than doc claimed. Resolved in 9227e26 by updating CLAUDE.md and stderr message to match actual behavior (Glob covers bare-path enumeration too). — `.claude/hooks/block-bash-tool-mapping.sh:134`
- [x] (suggestion) Added 11 regression tests in 9227e26: sed -n against README.md/notes.md/package.json/src/main.rs, sed -ni/-in/-niE combined clusters, bare find /etc and find ., sed -n script-only (stdin allow). — `.agent/scripts/tests/test_block_bash_tool_mapping.sh`
- [ ] (suggestion) Block message advertises bypass ("add a pipe or redirect"). Honest but could be tightened. Deferred — low priority. — `.claude/hooks/block-bash-tool-mapping.sh:emit_block`
- [x] (suggestion) `mkdir -p "$(dirname "$LOG_FILE")"` added in 9227e26. — `.claude/hooks/block-bash-tool-mapping.sh:log`

### Governance concerns
- "A change includes its consequences" — test fixtures didn't include realistic filenames, hiding a marquee bug
- "Test what breaks" — 43 tests but fixture-name coincidence avoided exercising the broken char-class

### Cross-model
Not dispatched this pass — Claude adversarial findings substantive enough to fix first; re-review after.

## External Review
**Status**: complete
**When**: 2026-05-11 13:30
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 — 2 review(s), 2 valid, 0 false positives (4 stale-but-addressed, 1 plan-file artifact skipped)
**CI**: all-pass (8/8)

### Actions
- [x] Harden `LOG_FILE="${HOME}/..."` against unset `HOME` — fixed in `dc52801` (`${HOME:-/tmp}`)
- [x] Remove unused `local exit_code` + SC2034 suppression — fixed in `67d576c`

## External Review (re-triage)
**Status**: complete
**When**: 2026-05-11 13:45
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `903be0c` — 1 new Copilot review (1 comment)
**CI**: all-pass (8/8)

### Actions
- [x] Add `--` end-of-options handling — fixed in `d735122`. Split TOKENS into FLAG_ARGS (pre-`--`) and POS_ARGS (post-`--`, always positional). Closes both gaps: `cat -- -file` now blocks; `sed -- 'expr' -input` now falls through. 11 regression tests added; 65/65 pass.

## External Review (re-triage 2)
**Status**: complete
**When**: 2026-05-11 14:00
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `e31ce0b` — 1 new Copilot review (2 comments)
**CI**: all-pass (8/8)

### Actions
- [x] Align `find` docs with bare-find blocking — fixed in `c2cfdd3`. Updated CLAUDE.md and hook header from `find <path> [...]` to `find [path] [...]` (path optional, bare `find` defaults to `.`). Added `find` (no args) test; 66/66 pass.

## External Review (re-triage 3)
**Status**: complete
**When**: 2026-05-11 14:20
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `4d7f408` — 1 new Copilot review (3 comments, same root cause)
**CI**: all-pass (8/8)

### Actions
- [x] Strip single-quoted regions before compound/redirect early-out — fixed in `eeb96f4`. Marquee bypass closed: `sed -n '1p;2p' README.md` now blocks (was exiting 0). 8 regression tests added; 74/74 pass. Known approximation: literal `>`/`<`/`;` inside double quotes still bypass (rare; documented inline).
