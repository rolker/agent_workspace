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

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 14:15 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**Branch**: feature/issue-272 at `64d97ca`
**Base**: main
**Depth**: Standard (reason: re-review of the fix commit)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 2 | **Ship**: recommended — both round-1 items verified fixed by dry-run and tests; no new findings

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-09-17 14:30 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #282 at `aecf5eb`
**Sources**: 2 (Copilot @ `aecf5eb`; Local Review (Pre-Push) rounds 1-2 @ `64d97ca`, no open findings)
**Cross-source confirmations**: 0
**CI**: all-pass

### Findings
- [ ] (must-fix, Copilot) setup/repair/clean mutate the now-shared venv, stamps, and hook without a lock — `Makefile`
- [ ] (must-fix, Copilot) worktree_create's hook preflight always checks the workspace hook, wrong for project worktrees — `.agent/scripts/worktree_create.sh`

### False positives
- none

## Implementation
**Status**: complete
**When**: 2026-09-17 14:30 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #282 at `cbe4f8f`
**Addressed**: Integrated Review at `aecf5eb` (Copilot round 1)
**Commits**: cbe4f8f

### Actions
- [x] shared-state recipes under flock; clean keeps the lock's directory — `Makefile`
- [x] hook preflight keyed on the new worktree's own common dir — `.agent/scripts/worktree_create.sh`

## Local Review
**Status**: complete
**When**: 2026-09-17 14:40 -0400
**By**: Claude Code Agent (claude-opus-5, fresh-context verifier; integrated by claude-fable-5-1)
**Verdict**: approved

**PR**: #282 at `cbe4f8f`
**Depth**: standard (reason: round 3, verifying the Copilot fixes from the Integrated Review)
**Must-fix**: 0 | **Suggestions**: 2

Both Integrated Review findings verified fixed: the shared-venv recipes serialize under flock (two parallel setup-dev runs proven non-interleaving), and the project-worktree preflight names the project repo's hook. 19/19 and 208/208 suites green.

### Findings
- [x] (suggestion) hook preflight on a package worktree resolved the enclosing repo, not the package repos that commit — `.agent/scripts/worktree_create.sh:1036` (fixed in `ee80a63`, test added to `test_ros2_colcon.sh`)
- [ ] (suggestion) `make setup`'s git-bug and project-clone stamps still run outside the lock; pre-existing, both recipes can prompt interactively so holding the lock across them would stall a second agent on a prompt — `Makefile:175-188` (deferred: stated in the PR body)

## Merge (report-only)
**Status**: complete
**When**: 2026-09-17 14:49 -04:00
**By**: merge_pr.sh (Claude Code Agent)

**PR**: #282 at `46641ce`
**Mode**: report-only
**Scope**: workspace
**Conditions**: latest Local Review entry is at `cbe4f8f`, not the PR head `46641ce` (stale review)
