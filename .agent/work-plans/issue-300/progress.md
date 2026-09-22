---
issue: 300
---

# Issue #300 — merge_pr.sh: Copilot's review check-run ('changes recommended', no findings) is counted as a CI failure and blocks the merge

## Issue Review
**Status**: complete
**When**: 2026-09-22 10:09 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #300

### Scope Assessment

**Well-scoped?** Yes — one script (`.agent/scripts/merge_pr.sh`, `_ci_poll_state` around lines 978–1021) plus a test-fixture addition to `test_merge_pr_gate.sh`/`test_merge_pr.sh`. Fits a single PR.
**Right repo?** Yes — `merge_pr.sh` is workspace infrastructure.
**Dependencies**: None open. #276, #299, #286, #290 (all referenced as prior context) are closed/merged; nothing blocks starting this.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | OK | Fix belongs in the script's own classification logic, not a doc note; issue already asks for regression fixtures. |
| A change includes its consequences | Action needed | Issue only names `test_merge_pr_gate.sh` (or `test_merge_pr.sh`) as the target — confirm which suite actually owns `_ci_poll_state` coverage today and add fixtures there, not a new file. |
| Test what breaks | OK | Issue proposes exact fixtures (copilot failure + Lint success → success; copilot failure + Lint in_progress → pending) — targets the real regression. |
| Human control and transparency | OK | "Print which check-run(s) caused a failed verdict" directly serves this; keep it in scope. |
| Only what's needed | Watch | "Better, a small allow/deny list" is presented as an upgrade over a single hardcoded name — scope the allowlist to the one confirmed case (`copilot-pull-request-reviewer`) unless a second offending check-run is already known, rather than speculatively generalizing. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0013 — progress.md entry-type vocabulary | No | No new entry type; this is a script bugfix. |
| 0011 — Project-type adapter contract | No | `merge_pr.sh` classification logic is generic, not project-shape-dependent. |
| 0004/0005 — Enforcement hierarchy | Watch | The fix is itself an enforcement mechanism (merge gate); regression must be caught by the test suite, not left to manual verification — issue already covers this via fixtures. |

### Consequences

- No documentation elsewhere describes the current "every check-run counts as CI" behavior, so no doc updates are needed beyond the script comment the issue already requests ("a comment naming the Copilot case").

### Recommendations

- The fix must exclude the check-run **by name/app-slug, for any conclusion** (`failure`, `cancelled`, `timed_out`, `action_required`, `startup_failure`, `stale` — all currently checked at line 1007), not by matching the "Changes recommended" / "Findings: None" message text. The bug recurred on PR #308 (issue #307) today with `copilot-pull-request-reviewer` reporting conclusion `failure` for a *different* reason (Copilot quota exhaustion, not a review verdict) — a message-text-based exclusion would have missed that case. The issue's own proposed fix (exclude by check-run name near the top of the script) already gets this right; flagging so implementation doesn't regress toward a message-based heuristic.
- The fix must not add any new wait, poll, or extra `gh api` round trip — it's a pure classification/filter change over data `_ci_poll_state` already fetches. Confirm the implementation only adds a name-based `jq select(... | not)` filter, not a second lookup.
- Since Copilot's review is already consumed by `triage-reviews` → `## Integrated Review`, the diagnostic print (recommendation 3 in the issue) should make clear in its output that the excluded check-run was *not* used to block the merge, to avoid an operator assuming it was silently ignored entirely.

### Actions
- [ ] Issue only names `test_merge_pr_gate.sh` (or `test_merge_pr.sh`) as the target — confirm which suite actually owns `_ci_poll_state` coverage today and add fixtures there, not a new file.
- [ ] The fix must exclude the check-run by name/app-slug, for any conclusion (`failure`, `cancelled`, `timed_out`, `action_required`, `startup_failure`, `stale` — all currently checked at line 1007), not by matching the "Changes recommended" / "Findings: None" message text. The bug recurred on PR #308 (issue #307) today with `copilot-pull-request-reviewer` reporting conclusion `failure` for a different reason (Copilot quota exhaustion, not a review verdict) — a message-text-based exclusion would have missed that case. The issue's own proposed fix (exclude by check-run name near the top of the script) already gets this right; flagging so implementation doesn't regress toward a message-based heuristic.
- [ ] The fix must not add any new wait, poll, or extra `gh api` round trip — it's a pure classification/filter change over data `_ci_poll_state` already fetches. Confirm the implementation only adds a name-based `jq select(... | not)` filter, not a second lookup.
- [ ] Since Copilot's review is already consumed by `triage-reviews` → `## Integrated Review`, the diagnostic print (recommendation 3 in the issue) should make clear in its output that the excluded check-run was not used to block the merge, to avoid an operator assuming it was silently ignored entirely.
