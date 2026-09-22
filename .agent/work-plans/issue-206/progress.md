---
issue: 206
---

# Issue #206 — cross_model_review.sh: reconsider tmux-default; sync should be parallel (and gstack has a non-tmux pattern worth borrowing)

## Issue Review
**Status**: complete
**When**: 2026-09-22 10:43 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #206

### Scope Assessment

**Well-scoped?** Partially. The core ask — replace the sequential `--sync`
fallback with a parallel `&`+`wait` dispatch and make it the default, keeping
tmux behind an explicit `--tmux` flag — is a single reviewable PR. Two things
should be split out before implementation:
1. The gstack `benchmark-models` adapter-pattern discussion is explicitly
   speculative ("if multi-agent review becomes a workspace-wide pattern
   beyond review-code") — not part of this change; treat as a reference,
   not scope.
2. The `rolker` comment reports a separate, already-diagnosed bug: `copilot
   -p < prompt` is broken against the current Copilot CLI (missing an empty
   value for `-p` and `--allow-all-tools`). Verified still present at HEAD
   (`cross_model_review.sh` lines 104 and 124, both `build_invoke_cmd` and
   `run_agent_sync`). The commenter themselves suggested filing it
   separately — do that; it's an independent one-line fix unrelated to the
   dispatch-mode question and shouldn't block or bloat this PR.

**Right repo?** Yes — `cross_model_review.sh` and the `review-code` skill
are workspace infrastructure.

**Dependencies**: None blocking. Downstream `rolker/ros2_agent_workspace#461`
is watching this decision for its Copilot-only port but isn't blocking.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| A change includes its consequences | Action needed | `.claude/skills/review-code/SKILL.md` step 5d currently documents three sequential invocations (lines 325-332 at HEAD) — must be rewritten to the new `--agents` single-invocation shape in the same PR, not as follow-up. The consequences map (`principles_review_guide.md`) explicitly pairs `review-code` skill changes with `cross_model_review.sh` changes. |
| Capture decisions, not just implementations | Action needed | No ADR documents the tmux-dispatch decision today (only work-plan/knowledge-digest mentions from issues #2, #65, #66, #106, #181). Reversing a default that was deliberately chosen for interactivity is exactly the kind of decision ADR-0001 asks to be recorded — file a new ADR (or extend an existing one via ADR-0008 addendum if the reversal is framed as a correction) rather than letting the rationale live only in this issue thread. |
| Only what's needed | Watch | Keep the gstack adapter-pattern (`Promise.allSettled`, typed per-agent `RunResult`) out of scope — it requires a bun/node runtime the workspace doesn't otherwise depend on. The proposal's own bash `&`+`wait` option satisfies the actual need without new runtime dependencies. |
| Test what breaks | Action needed | The new parallel-dispatch path (background jobs, per-agent exit-code files, `wait -n` or equivalent) needs its own coverage in `test_cross_model_review.sh` (currently 1344 lines with an existing mock-tmux test from #311) — background-job error handling in bash is exactly the kind of logic that fails silently if untested. |
| Improve incrementally | OK | Scoped correctly (parallel-sync-default) this is an incremental, reviewable change. |
| Workspace improvements cascade to projects | Watch | If `--agents` becomes the recommended invocation, downstream consumers reading `cross_model_review.sh` as a reference (the linked `ros2_agent_workspace#461` port) should see the pattern land before or alongside their port to avoid diverging. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0001 — Adopt ADRs | Yes | See "Capture decisions" above — this reverses a prior, deliberate default with no ADR of record. |
| 0013 — progress.md entry-type vocabulary | Yes (process, not content) | Standard for any issue driven through the review loop; no special handling needed beyond the normal `review_progress.sh persist` calls. |
| 0011 — Project-type adapter contract | No | `cross_model_review.sh` doesn't branch on project shape; this is agent-dispatch logic, not project-type logic. |

### Consequences

- `.claude/skills/review-code/SKILL.md` step 5d (sequential per-agent invocation examples) must be updated to the new `--agents` shape.
- `cross_model_review.sh`'s own usage header (currently documents tmux as default, lines 22-26/39-46) must be rewritten.
- `test_cross_model_review.sh` needs new tests for the parallel-sync path, not just a rename of the existing sync test.
- `.agent/knowledge/` digests referencing tmux dispatch (`research_digest.md`, inspiration digests) are historical notes, not living docs — no update needed, but don't let plan-task confuse them for current behavior docs.

### Recommendations

- Split the Copilot `-p`/`--allow-all-tools` fix into its own issue (trivial, already diagnosed) and land it independently of this decision.
- File or extend an ADR capturing the tmux-default reversal before or alongside the implementation PR, per ADR-0001.
- Keep the gstack adapter-pattern out of this issue's scope; reference it in the ADR's "considered alternatives" instead of implementing it.
- Add explicit background-job/error-handling test cases (partial failure, one agent times out while others succeed) to `test_cross_model_review.sh` as part of the same PR.

### Actions
- [ ] `.claude/skills/review-code/SKILL.md` step 5d currently documents three sequential invocations (lines 325-332 at HEAD) — must be rewritten to the new `--agents` single-invocation shape in the same PR, not as follow-up. The consequences map (`principles_review_guide.md`) explicitly pairs `review-code` skill changes with `cross_model_review.sh` changes.
- [ ] No ADR documents the tmux-dispatch decision today (only work-plan/knowledge-digest mentions from issues #2, #65, #66, #106, #181). Reversing a default that was deliberately chosen for interactivity is exactly the kind of decision ADR-0001 asks to be recorded — file a new ADR (or extend an existing one via ADR-0008 addendum if the reversal is framed as a correction) rather than letting the rationale live only in this issue thread.
- [ ] The new parallel-dispatch path (background jobs, per-agent exit-code files, `wait -n` or equivalent) needs its own coverage in `test_cross_model_review.sh` (currently 1344 lines with an existing mock-tmux test from #311) — background-job error handling in bash is exactly the kind of logic that fails silently if untested.
- [ ] Split the Copilot `-p`/`--allow-all-tools` fix into its own issue (trivial, already diagnosed) and land it independently of this decision.
- [ ] File or extend an ADR capturing the tmux-default reversal before or alongside the implementation PR, per ADR-0001.
- [ ] Keep the gstack adapter-pattern out of this issue's scope; reference it in the ADR's "considered alternatives" instead of implementing it.
- [ ] Add explicit background-job/error-handling test cases (partial failure, one agent times out while others succeed) to `test_cross_model_review.sh` as part of the same PR.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 10:46 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed. The plan must address the four review actions: a new ADR recording the tmux-default reversal (gstack pattern under considered alternatives, out of scope); rewrite the review-code skill's dispatch step to the single-invocation shape in the same PR; explicit parallel-dispatch failure-mode tests (one agent fails, one times out while others succeed); the Copilot -p / --allow-all-tools fix stays in #212 and out of this PR.
