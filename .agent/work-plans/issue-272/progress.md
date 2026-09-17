---
issue: 272
---

# Issue #272 — pre-commit silently unavailable in worktrees unless the workspace venv is activated

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 14:11 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-272 at `3f196ce`
**Base**: main
**Depth**: Standard (reason: Makefile + two scripts, ~150 lines)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix (cross-confirmed by governance + adversarial), fixed in 64d97ca

### Findings
- [x] (must-fix, cross-confirmed) shared venv installed from the worktree's requirements.txt — `Makefile` → WS_ROOT/requirements.txt everywhere
- [x] (must-fix, cross-confirmed) validate checked existence, the hook checks -x — `.agent/scripts/validate_workspace.py` → os.access X_OK
- [x] (suggestion) make clean now clears the shared stamps — documented in the Makefile comment; intended (stamps are main-tree state)
- [ ] (suggestion) bare-repo WS_ROOT would be the bare dir itself — not a supported layout; noted
- [ ] (suggestion) #239 remains open for MAIN_ROOT itself — stated in the PR
