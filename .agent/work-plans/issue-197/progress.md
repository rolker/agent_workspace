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

## External Review (re-triage 4)
**Status**: complete
**When**: 2026-05-11 14:35
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `f850f79` — 1 new Copilot review (2 comments)
**CI**: all-pass (8/8)

### Actions
- [x] Allow `find --help`/`--version` (informational, not enumeration) and rewrite the misleading "nudge, not a parser" comment to match block-on-match behavior — fixed in `c0f7616`. 2 regression tests added; 76/76 pass.

## External Review (re-triage 5)
**Status**: complete
**When**: 2026-05-11 14:50
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `ad67a10` — 1 new Copilot review (2 comments)
**CI**: all-pass (8/8)

### Actions
- [x] Extend quote-stripping to double-quoted regions (when free of `$(`/backticks) — fixed in `bacc64b`. Closes `sed -n "1p;2p" file` bypass. Preserves `cat "$(cmd)"` early-out.
- [x] Make `head`/`tail` numeric exemption stateful — fixed in `bacc64b`. `head 123` now blocks (was bypassing as "count"); only numeric tokens immediately after `-n`/`--lines`/`-c`/`--bytes` are exempted. 9 regression tests added; 85/85 pass.

## External Review (re-triage 6)
**Status**: complete
**When**: 2026-05-12 09:30
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `cdcc90e` — 1 new Copilot review (4 comments: 3 valid, 1 false positive)
**CI**: all-pass (8/8)

### Actions
- [x] Defer `umask`/`mkdir -p` until after the Bash check (hook is wildcard PreToolUse so was running for every tool call) — fixed in `8f7c803`.
- [x] Add `command -v jq` guard at top of test script for clear missing-dep error — fixed in `8f7c803`.
- [x] Split CLAUDE.md Tool Mapping row to match hook's granular sed behavior (`sed -i`/`awk -i` → Edit; `sed -n` → Read/Grep) — fixed in `8f7c803`.
- [n/a] Heredoc leading-space concern: **false positive**. Verified with `cat -A` — stderr is left-aligned, no indentation.

## External Review (re-triage 7)
**Status**: complete
**When**: 2026-05-12 09:45
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `4ea18fe` — 1 new Copilot review (1 comment)
**CI**: all-pass (8/8)

### Actions
- [x] Move `umask`/`mkdir -p` into `emit_block()` so allowed Bash calls and non-Bash tool calls never touch `~/.claude/` — fixed in `f406daa`. Verified empirically: allowed `echo hello` leaves test $HOME empty.

## External Review (re-triage 8)
**Status**: complete
**When**: 2026-05-12 10:00
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `4e5b841` — 1 new Copilot review (3 comments)
**CI**: all-pass (8/8)

### Actions
- [x] Strip backslash-escape pairs (`\X`) from COMPOUND_CHECK before metachar early-out — fixed in `091656f`. Closes `cat file\>bar.txt` bypass (was exit 0).
- [x] Fix CLAUDE.md awk row: `awk -i` is gawk's include-library flag, not in-place. Move awk to its own broad row (`awk (any)` → Edit); keep sed granular — fixed in `091656f`.
- [x] Simplify `"${FLAG_ARGS[@]:+${FLAG_ARGS[@]}}"` to `"${FLAG_ARGS[@]}"` (7 occurrences); safe under `set -u` on bash 4.4+ — fixed in `091656f`. 88/88 pass.

## External Review (re-triage 9)
**Status**: complete
**When**: 2026-05-12 10:15
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `c9a23c5` — 1 new Copilot review (3 comments)
**CI**: all-pass (8/8)

### Actions
- [x] Add newline/CR to compound early-out — fixed in `255c0a5`. Multi-line bash snippets (`cat foo\nls bar`) no longer treated as simple cat. Test added.
- [x] Skip sed `-n` block when `-f` is present (external sed script — content unknown) — fixed in `255c0a5`. `-e` inline still blocks. 2 -f allow tests + 2 -e block tests added.
- [x] Update CLAUDE.md "Enforced by hook" + hook header to call out the `-e` block / `-f` pass-through nuance — fixed in `255c0a5`.

## External Review (re-triage 10)
**Status**: complete
**When**: 2026-05-12 10:25
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `ea82982` — 1 new Copilot review (1 comment)
**CI**: all-pass (8/8)

### Actions
- [x] Reword the operational-find list in the hook header docstring as illustrative ("e.g. ...") rather than exhaustive — fixed in `d7caa1e`. Avoids drift as the code's allowlist grows.

## External Review (re-triage 11)
**Status**: complete
**When**: 2026-05-12 10:40
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #200 at `674c28c` — 1 new Copilot review (1 comment, multiple bypasses)
**CI**: all-pass (8/8)

### Actions
- [x] Normalize HEAD against wrappers, env-assignments, and path prefix — fixed in `95682e3`. Closes bypasses: `/bin/cat`, `sudo cat`, `command cat`, `env cat`, `nohup cat`, `time cat`, `FOO=1 cat`, stacked wrappers, etc. 14 regression tests added; 108/108 pass. Documented limitation: wrapper-with-flags forms (`sudo -u user cat`) still bypass — per-wrapper flag tables would be disproportionate for a nudge hook.
