---
issue: 350
---

# Issue #350 — Pin codex's sandbox/approval flags in _cli_review.sh instead of relying on CLI defaults

## Issue Review
**Status**: complete
**When**: 2026-09-25 08:13 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #350

### Scope Assessment

**Well-scoped?** Yes — a single-file fix to `_cli_review.sh`'s codex invocation (`codex -s read-only -a never exec -o <file>` in place of relying on CLI defaults), plus the matching update to the codex-argv assertion in `test_cross_model_review.sh`. Both land in one PR.

**Right repo?** Yes — `_cli_review.sh` is a workspace script (`.agent/scripts/_cli_review.sh`), and this is workspace-infrastructure hardening, not project content.

**Dependencies**: None identified. The issue notes the same fix was already applied locally in the `ros2_agent_workspace` fork (issue #660 there); no blocking relationship to any open workspace issue.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Human control and transparency | OK | Pinning explicit flags makes the sandbox/approval posture visible in the script rather than implicit in CLI defaults — improves transparency. |
| Enforcement over documentation | OK | The fix is itself an enforcement change (explicit flags checked by a test), not a doc-only note. |
| A change includes its consequences | Watch | Issue already flags the test-suite assertion (`test_cross_model_review.sh`) that needs updating since flag placement changes `codex`'s first argv token from `exec` to `-s`. Confirmed in this review: `test_cross_model_review.sh:2849` asserts `head -n 1 codex.argv == "exec"`, which will break unless updated in the same PR. |
| Only what's needed | OK | Two flags, no new abstraction. |
| Test what breaks | Watch | The existing test checks argv shape but not that `-a`/`-s` precede `exec`; the PR should add/adjust an assertion that specifically locks in correct flag placement (not just update the existing one to keep it green), since the whole point of the issue is that flag *placement* is easy to get backwards (`-a` after `exec` errors per codex-cli 0.156.1). |
| Workspace improvements cascade to projects | OK | Issue notes the same fix was already made independently in the `ros2_agent_workspace` fork; landing it here keeps the two in sync, consistent with the "reference implementation" principle. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Yes | Touches `_cli_review.sh`, one of the ADR's named surfaces. This fix only pins CLI flags on the codex arm; it doesn't touch dispatch mode, parallelism, or per-agent failure handling, so no conflict with the ADR's requirements. |
| 0009 — Python package management | No | N/A, bash script only. |

### Consequences

- Update the codex-argv assertion in `.agent/scripts/tests/test_cross_model_review.sh` (currently asserts `head -n 1 codex.argv == "exec"`) to match the new invocation, and add an assertion that verifies `-s`/`-a` appear *before* `exec` on argv — not just that they're present — since flag placement is the actual failure mode this issue is about.
- No other workspace docs (`docs/decisions/`, `.agent/knowledge/`) reference codex's sandbox/approval flags directly, so no further doc updates are triggered.

### Recommendations

- Verify the pinned flags against the currently-installed codex-cli version in CI/dev environments (issue confirms 0.156.1 locally); note the version checked in the PR description since CLI flag contracts can shift across releases.
- Confirm `-s read-only -a never` doesn't change codex's behavior in a way that breaks an existing passing review turn (e.g., if some current usage relies on write access) — grep for any workspace code path that expects codex to write files during a review turn before merging.

### Actions
- [ ] The existing test checks argv shape but not that `-a`/`-s` precede `exec`; the PR should add/adjust an assertion that specifically locks in correct flag placement (not just update the existing one to keep it green), since the whole point of the issue is that flag placement is easy to get backwards (`-a` after `exec` errors per codex-cli 0.156.1).
- [ ] Verify the pinned flags against the currently-installed codex-cli version in CI/dev environments (issue confirms 0.156.1 locally); note the version checked in the PR description since CLI flag contracts can shift across releases.
- [ ] Confirm `-s read-only -a never` doesn't change codex's behavior in a way that breaks an existing passing review turn (e.g., if some current usage relies on write access) — grep for any workspace code path that expects codex to write files during a review turn before merging.

## Checkpoint
**Status**: complete
**When**: 2026-09-25 08:18 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed to planning — the planner folds the three Issue Review actions into the plan (flag-placement test, codex-cli 0.156.1 check, grep for code expecting codex write access); the plan returns to the owner before any code.
