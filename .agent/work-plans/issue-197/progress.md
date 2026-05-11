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
- [ ] (must-fix) `sed -n 'EXPR' <file>` heuristic uses char-class `[pPdDsSyYqQ;{}]` to detect sed-script vs file path, but those chars are present in nearly every real filename (README.md, notes.md, package.json, src/main.rs all bypass). Headline case broken — test fixtures used `file.txt`/`log.txt`/`file` which lack the chars, masking the bug. — `.claude/hooks/block-bash-tool-mapping.sh:178`
- [ ] (must-fix) Combined short-flag `-ni` bypasses in-place detection (`has_sed_inplace` only checks `-i`, `-i.*`, `-i[!-]*`, `--in-place`). `sed -ni 's/x/y/' file.txt` writes in-place but is allowed. — `.claude/hooks/block-bash-tool-mapping.sh:158`
- [ ] (must-fix) Bare `find <path>` blocks, broader than CLAUDE.md's documented `find PATH -name PAT` framing. Either narrow trigger or update doc (recommend update doc — bare-find enumeration is what Glob is for). — `.claude/hooks/block-bash-tool-mapping.sh:134`
- [ ] (suggestion) Add tests using real filenames (`README.md`, `notes.md`, `src/main.rs`, `package.json`) for `sed -n`, and `sed -ni`/`sed -in` combined-flag tests. — `.agent/scripts/tests/test_block_bash_tool_mapping.sh`
- [ ] (suggestion) Block message advertises bypass ("add a pipe or redirect"). Honest but could be tightened. — `.claude/hooks/block-bash-tool-mapping.sh:emit_block`
- [ ] (suggestion) `mkdir -p "$(dirname "$LOG_FILE")"` before sidecar-log append so logging works on a fresh `~/.claude/` setup. — `.claude/hooks/block-bash-tool-mapping.sh:log`

### Governance concerns
- "A change includes its consequences" — test fixtures didn't include realistic filenames, hiding a marquee bug
- "Test what breaks" — 43 tests but fixture-name coincidence avoided exercising the broken char-class

### Cross-model
Not dispatched this pass — Claude adversarial findings substantive enough to fix first; re-review after.
