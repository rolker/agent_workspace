---
issue: 313
---

# Issue #313 — cross_model_review.sh: codex/claude/copilot arms have no result validation

## Issue Review
**Status**: complete
**When**: 2026-09-22 12:43 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #313

### Scope Assessment

**Well-scoped?** Yes — the ask is narrow and mechanical: give the codex,
claude, and copilot arms of `run_agent_sync` in `.agent/scripts/cross_model_review.sh`
the same result-validation contract `_agy_review.sh` already gives the gemini
arm (#288): distinguish "CLI exited 0 with a real review" from "CLI exited 0
with an empty/error/denied/timed-out response". Confirmed in the current tree
(post-PR #318, ADR-0015): the three arms are still bare
`timeout ... "$bin" ... < "$prompt" > "$findings" 2>&1`, success gated on exit
code alone. Three independent per-CLI investigations plus tests is a
reasonable single-PR scope, but it is three CLIs' worth of undocumented
failure-mode research (denied tool, timeout, API error, each CLI's own
markers) — if that research turns up materially different shapes per CLI
(likely, given codex's own comment about full-prompt echo), consider landing
codex first as the concrete, already-diagnosed case and following with
claude/copilot once their failure shapes are confirmed, rather than
discovering all three shapes inside one PR.

**Right repo?** Yes — `.agent/scripts/cross_model_review.sh` and its helpers
are workspace infrastructure.

**Dependencies**: #212 (copilot `-p ""` / `--allow-all-tools` invocation bug)
overlaps directly — the copilot arm here can't be validated against a broken
invocation, so #212 should land first or be folded into this issue's copilot
work rather than treated as a parallel, unrelated fix. #320 (Standard tier +
plan context for gemini/codex) is sequenced after this per the issue's own
"Related" note and needs no changes here. The codex-echo finding in the
issue's comment (`-o/--output-last-message <FILE>`) is pre-researched and
ready to implement; claude and copilot need the same discovery step from
scratch.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | Action needed | The bug this issue fixes is exactly "validation exists only for one of four agents" — the fix must give codex/claude/copilot the same forced validation gate `_agy_review.sh` gives gemini (own findings-file ownership + truncate-first + fail() helper + `EXIT=` semantics), not just better logging that a human has to notice. |
| Test what breaks | Action needed | This is timing/process-exit/silent-failure territory exactly where the workspace principle calls for tests, and the issue itself asks for "Tests with a mock per CLI" — that must not be treated as optional scope. |
| A change includes its consequences | Watch | `review-code`'s dispatch step and any doc describing "how cross_model_review reports failure" should be checked for per-agent assumptions once codex/claude/copilot start failing with reasons in the findings file instead of always exit-code-only. |
| Improve incrementally | OK | Extends an already-landed pattern (ADR-0015 background jobs + EXIT= lines) rather than restructuring dispatch. |
| Only what's needed | Watch | Three CLIs' worth of per-agent helper scripts (mirroring `_agy_review.sh`) is the natural shape but is real new surface area — confirm each CLI actually needs its own helper file versus a shared validator parameterized by CLI-specific markers, to avoid three near-duplicate scripts. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Yes | This issue touches `cross_model_review.sh` and per-agent helpers directly. The ADR's requirement ("failure is per agent — own marker, own `EXIT=` line") is already partially met by the background-job structure from #318; this issue closes the remaining gap where a per-agent "own marker" exists (`EXIT=0`) but doesn't reflect a real validation result for three of the four agents. Any new helper scripts should be added to the ADR's referenced set and to the Script Reference table (see Consequences). |
| 0013 — progress.md entry-type vocabulary | No | Not touched by this change. |

### Consequences

- `AGENTS.md`'s Script Reference table lists `_agy_review.sh` under
  `cross_model_review.sh`; new per-CLI helper scripts (if that's the shape
  chosen) need their own rows, following the pattern already set.
- If the fix changes what a failed agent's findings file/marker looks like,
  `review-code`'s reading of `EXIT=` per agent (ADR-0015's own requirement)
  should be re-checked against the new failure-reason content, even though
  the `EXIT=` contract itself isn't changing.

### Recommendations

- Confirm the copilot arm's fix doesn't collide with #212's separate
  invocation-flag fix — do #212 first, or scope this issue's copilot work to
  include the `-p ""`/`--allow-all-tools` correction so a single PR doesn't
  ship copilot validation logic against a call that's still broken upstream.
- Before writing three near-duplicate `_codex_review.sh` / `_claude_review.sh`
  / `_copilot_review.sh` helpers, check whether the common truncate-first /
  fail() / EXIT-marker skeleton can be factored into a shared function each
  CLI-specific script parameterizes, rather than copy-pasting `_agy_review.sh`
  three times.

### Actions
- [ ] The bug this issue fixes is exactly "validation exists only for one of four agents" — the fix must give codex/claude/copilot the same forced validation gate `_agy_review.sh` gives gemini (own findings-file ownership + truncate-first + fail() helper + `EXIT=` semantics), not just better logging that a human has to notice.
- [ ] This is timing/process-exit/silent-failure territory exactly where the workspace principle calls for tests, and the issue itself asks for "Tests with a mock per CLI" — that must not be treated as optional scope.
- [ ] Confirm the copilot arm's fix doesn't collide with #212's separate invocation-flag fix — do #212 first, or scope this issue's copilot work to include the `-p ""`/`--allow-all-tools` correction so a single PR doesn't ship copilot validation logic against a call that's still broken upstream.
- [ ] Before writing three near-duplicate `_codex_review.sh` / `_claude_review.sh` / `_copilot_review.sh` helpers, check whether the common truncate-first / fail() / EXIT-marker skeleton can be factored into a shared function each CLI-specific script parameterizes, rather than copy-pasting `_agy_review.sh` three times.
