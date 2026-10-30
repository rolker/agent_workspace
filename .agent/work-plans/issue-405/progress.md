---
issue: 405
---

# Issue #405 — Decision register: record the 2026-10-27 re-examination of nine ADRs

## Local Review
**Status**: complete
**When**: 2026-10-30 09:55 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**PR**: #406 at `dd9f5e0`
**Depth**: Standard (reason: docs/design.md treated as a governance file, as in prior reviews; 1 file, +10 -9)
**Must-fix**: 1 | **Suggestions**: 2

### Findings
- [ ] (must-fix) PR body is stale after the merge resolution: its Decision summary says the change-log row is dated 2026-10-27 with file length 757; the row is now 2026-10-30 with 844 (the re-examined date stays 2026-10-27) — PR #406 description
- [ ] (suggestion) Standing rule says `in force` means nothing found contradicts the ADR, but the ADR-0007 cell records that its key behaviours differ from the Makefile; add a clause allowing an owner-decided note on `in force` when the Decision itself holds (owner chose this 2026-10-27), so rule and cell agree — `docs/design.md:679-684,696`
- [ ] (suggestion) ADR-0007 cell cites `Makefile lines 98-116, 182-193`, which drift on any Makefile edit; the stamp and target names the note already gives are enough (Gemini) — `docs/design.md:696`
