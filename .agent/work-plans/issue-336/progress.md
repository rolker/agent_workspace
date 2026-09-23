---
issue: 336
---

# Issue #336 — Gemini (agy) reviews fail on real branches: headless read_file denied, output-token limit on large prompts

## Issue Review
**Status**: complete
**When**: 2026-09-23 14:31 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #336

### Scope Assessment

**Well-scoped?** Yes, for the primary Gemini fix — two concrete failure modes (headless `read_file` denial, output-token-limit truncation) with a clear acceptance test (a Deep-tier branch review completing with a real Gemini review). The owner-approved addendum (claude arm of `_cli_review.sh` misreading `.error` vs `.errors`) is a distinct root cause bundled into the same issue; verified against `.agent/scripts/_cli_review.sh` lines ~332-334 (fails on non-zero exit before reading JSON) and ~367 (`read_claude_field ERROR_MSG '(.error // "") | ...'`) — the comment's description matches the code exactly. Bundling is defensible (same failure class: helper misreads its CLI's real output) but the two fixes touch different scripts (`_agy_review.sh`/`cross_model_review.sh` vs `_cli_review.sh`) and should land as separate commits/PRs-worth of diff within the branch so review isn't conflating two root causes. The comment already declines a retitle — noted as an accepted decision, not a gap.

**Right repo?** Yes — workspace infra (`.agent/scripts/`).

**Dependencies**: #320 (already merged per current `main`), #313, #288 (both referenced, prior art for the denial-handling pattern), #340 (source of the claude-arm addendum), #342 (broader external-reviewer contract, explicitly ordered *after* this issue — correct sequencing, #336 should not absorb #342's isolation/schema/size-gate scope).

### Correction to prior framing

One piece of context this review was given is inaccurate against current code: the "## Tool Use" section containing "You may read files in the repository for surrounding context" is **not** shared across all agents. In `cross_model_review.sh` (~line 1113), that block is appended only when `agent == "gemini"`, with an explicit comment: "Not added for codex/claude/copilot — codex reads files through the shell, so the line would cost it context." So a Gemini-only prompt change (e.g., removing the file-read line, per the issue's own second option) carries no risk to codex/claude/copilot — the isolation is already in place. The plan should not spend effort re-deriving or preserving this isolation; it already exists.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | OK | Issue explicitly requires mock coverage for both new failure shapes and replacing the claude mocks with live-captured shapes (confirmed stale: `test_cross_model_review.sh` ~line 3266 encodes an `.error` shape not reproduced against claude 2.1.280's actual `.errors` array). |
| Enforcement over documentation | OK | Fix targets the helper scripts and their test mocks directly, not a doc-only change. |
| A change includes its consequences | Watch | Per the review guide's consequences map, touching `cross_model_review.sh` should also prompt a check of `.agent/knowledge/review_depth_classification.md` — likely a no-op here since this is a bug fix, not a depth-tier change, but the plan should confirm rather than assume. |
| Human control and transparency | OK | The `~/.gemini/antigravity-cli/settings.json` permission-allow option is correctly framed in the issue as the owner's machine-config call, not something to be silently added by the agent. |
| Only what's needed | Watch | The issue leaves both the read_file-permission route and the prompt-change route open ("decide in the plan"); the plan-review gate should confirm the implementer picked one deliberately rather than doing both, and that it didn't reach for #342's fuller contract (no-file-tools + size gate) when the narrower prompt tweak suffices for #336. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Yes | Touches `cross_model_review.sh` and `_agy_review.sh`/`_cli_review.sh` (per-agent helpers). Fix must preserve one background job per agent, per-agent timeout, and the own-marker/own-`EXIT=`-line failure contract — nothing here appears to require changing that shape, but the plan should say so explicitly. |
| 0013 — progress.md entry-type vocabulary | No | No progress.md schema change implied. |
| 0009 — Python package management | No | Not applicable (bash/jq). |

### Consequences

- If the output-token-limit fix adds a length instruction to the gemini prompt or a continue/retry path in `_agy_review.sh`, confirm `.agent/knowledge/review_depth_classification.md` doesn't need a corresponding note (Deep-tier prompt size is the trigger condition here).
- The claude-arm mock replacement (owner's addendum) should record the CLI version alongside each captured shape, as the comment itself specifies — this is a testable acceptance item, not just a nice-to-have.

### Recommendations

- Keep the Gemini fix and the claude-arm `.error`/`.errors` fix as clearly separable diffs/commits inside one branch, since they are unrelated root causes bundled by convenience, not by shared code path.
- Have the plan state explicitly which of the two Gemini options (permission allow-rule vs. prompt change) it is taking, and why — the issue defers this decision to the plan, so review-plan should treat an unaddressed choice as a gap.
- When replacing the claude test mocks, keep the existing `.error`-shape assertions if they still exercise a real (if rarer) shape, rather than deleting the only coverage for a string-valued `.error`; add the newly-discovered `.errors` array as additional cases.

### Actions
- [ ] Keep the Gemini fix and the claude-arm `.error`/`.errors` fix as clearly separable diffs/commits inside one branch, since they are unrelated root causes bundled by convenience, not by shared code path.
- [ ] Have the plan state explicitly which of the two Gemini options (permission allow-rule vs. prompt change) it is taking, and why — the issue defers this decision to the plan, so review-plan should treat an unaddressed choice as a gap.
- [ ] When replacing the claude test mocks, keep the existing `.error`-shape assertions if they still exercise a real (if rarer) shape, rather than deleting the only coverage for a string-valued `.error`; add the newly-discovered `.errors` array as additional cases.
