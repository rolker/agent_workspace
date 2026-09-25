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

## Plan Authored
**Status**: complete
**When**: 2026-09-25 08:25 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-350/plan.md` at `e9d9b4f`

Pin `-s read-only -a never` before `exec` in the codex `run_cli` call in `_cli_review.sh` (flag order matters: `-a` is a top-level flag, confirmed on codex-cli 0.156.1), and tighten `test_cross_model_review.sh`'s codex-argv assertion to check that the flags precede `exec` rather than just checking `exec` is present. Grep confirmed no other workspace code path invokes codex or expects it to write during a review turn.

## Plan Review
**Status**: complete
**When**: 2026-09-25 08:31 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #350 — Pin codex's sandbox/approval flags in _cli_review.sh instead of relying on CLI defaults
**Plan**: `.agent/work-plans/issue-350/plan.md` at `e9d9b4f`
**Branch**: `feature/issue-350`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One argv change plus one test assertion; single PR. |
| Issue alignment | Good | Covers the issue's recommendation and all three Issue Review actions (placement assertion, 0.156.1 version note, write-expectation grep). |
| File targeting | Good | `_cli_review.sh:311` is the only place codex is run. Re-grepped `.agent/scripts`, `.claude`, `Makefile`, `.github`: no other `codex exec`/`codex -s`/`-a` invocation, so nothing else expects write access. Two stale comments sit in the same files (finding 2). |
| Consequences | Good | Test assertion is covered. The mock's argv parser finds `-o` by scanning, so it keeps working when flags come first; the `^-o$` and prompt-not-on-argv assertions are unaffected. |
| Principle alignment | Good | Explicit over implicit; the tightened exact-prefix assertion locks in placement. |
| ADR compliance | Good | ADR-0015: dispatch and failure handling are unchanged. No other ADRs triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment]** — The plan's evidence shows only that `codex -s read-only -a never exec --help` *parses*, not that `exec` *honours* top-level flags. I re-verified parsing on 0.156.1 (`codex exec -a never` exits 2; the top-level form exits 0). I also ran a local probe that makes no model call: `codex debug prompt-input` renders the permissions block. There, top-level `-s danger-full-access` changes `sandbox_mode` from `read-only`, and top-level `-a never` adds "Approval policy is currently never". So root `-s`/`-a` do reach a subcommand's config. That is strong evidence, but it comes from `debug`, not `exec`. Suggest citing the probe in the code comment or PR. After the first live codex review, confirm the rollout's turn context in `~/.codex/sessions` shows read-only/never. Also note: 0.156.1's `-a` accepts only `on-request|never`, so `never` is valid.
2. **[File targeting]** — `_cli_review.sh:76-77`'s header already says "Verified against codex-cli 0.155.1 … `codex exec [PROMPT]`", and the mock's comment at `test_cross_model_review.sh:2708` reads "codex exec [-o FILE]". Update both to the new invocation and version. Don't add a second, separate verification note beside the stale one.
3. **[Consequences]** — The sketched assertion's `"-s\nread-only\n-a\nnever\nexec"` is a double-quoted string, which holds literal backslash-n rather than newlines against `head -n 5` output. Use `$'-s\nread-only\n-a\nnever\nexec'` (or compare `paste -sd' '` output). The plan already flags the wiring as adjustable.

### Summary

The plan is sound and minimal. Its central claims (flag placement, no other codex call sites, test impact) check out against the code and the installed codex-cli 0.156.1. The three findings are small implementation notes, not plan changes. Ready for implementation.

### Recommended Actions

- [ ] Update the `_cli_review.sh` header verification note (0.155.1 → 0.156.1, new invocation) and the mock comment at test line ~2708 instead of adding a parallel note.
- [ ] Write the exact-prefix assertion with real newlines (`$'...'`) so it can actually pass or fail on placement.
- [ ] Record the `codex debug prompt-input` probe (top-level `-s`/`-a` take effect) in the PR description alongside the 0.156.1 version note.

## Checkpoint
**Status**: complete
**When**: 2026-09-25 08:36 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed — approve the plan; the implementer folds in the three Plan Review notes (7ddc882): flags-applied evidence for the PR description, update the two stale comments, use $'...' in the placement assertion.

## Implementation
**Status**: complete
**When**: 2026-09-25 08:45 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-350 at `9fe0818`

- `.agent/scripts/_cli_review.sh`: codex now runs as `codex -s read-only -a never exec -o <file>`; rationale comment above the call (flags are top-level and must precede `exec`); header verification note updated in place (0.155.1 → 0.156.1, new invocation, `codex debug prompt-input` evidence) — Plan Review note 2.
- `.agent/scripts/tests/test_cross_model_review.sh`: `test_agents_all_succeed` asserts the exact leading argv `$'-s\nread-only\n-a\nnever\nexec'` (real newlines — Plan Review note 3); mock codex comment updated in place.
- Suite: 662 passed, 0 failed. Mutation check (each restored afterwards): flags after `exec`, flags missing, and `-a`/`-s` swapped each fail exactly the new assertion (661/1).
- Evidence for the PR (Plan Review note 1): on codex-cli 0.156.1, `codex debug prompt-input` with no flags renders `sandbox_mode` `workspace-write` from this trusted cwd; with top-level `-s read-only -a never` it renders `read-only` plus "Approval policy is currently never". `codex exec -a never --help` exits 2; `codex -s read-only -a never exec --help` exits 0. No live codex review turn was run.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-25 08:54 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-350 at `e881924`
**Base**: main
**Depth**: Deep (reason: security-relevant — sandbox/approval policy of a headless reviewer reading untrusted diffs; 274 changed lines incl. work-plan)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 1 | **Ship**: recommended — no must-fix findings

### Findings
- [ ] No issues found. LGTM.

### Specialists
- Static analysis: shellcheck --severity=warning (workspace .venv) clean on both changed scripts.
- Governance: ADR-0015 untouched (dispatch mode unchanged); AGENTS.md script table and knowledge docs carry no codex argv that went stale.
- Plan drift: none — both planned files changed as planned, Plan Review notes folded in.
- Claude adversarial: no findings; suite 662 passed / 0 failed; confirmed on codex-cli 0.156.1 that unflagged `codex debug prompt-input` in a trusted project renders `workspace-write`, and `-s read-only -a never` renders `read-only` / approval `never`; `-o` still written under read-only.
- Cross-model: gemini EXIT=0 no issues; codex EXIT=0 no issues (ran via the worktree's patched `_cli_review.sh`, i.e. with the new pinned flags — it reported it could not run the suite "in this read-only environment"); copilot not dispatched (quota exhausted).
