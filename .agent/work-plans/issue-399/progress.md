---
issue: 399
---

# Issue #399 — Dispatched passes run the script test suite once per pass, not per commit

## Issue Review
**Status**: complete
**When**: 2026-10-20 14:43 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #399

### Scope Assessment

**Well-scoped?** Yes. One PR: one rule stated in five places (handoff line, two skill texts, AGENTS.md row, hook comment) plus one test. The decision, the rejected alternative and the acceptance are already in the body.
**Right repo?** Yes. Workspace (`dispatch_phase.sh`, skills, `AGENTS.md`, `.pre-commit-config.yaml`); nothing names a project.
**Serves**: Quality of the work (the full suite stays the gate before any push; only repeated runs go, per the owner's wall-clock-over-tokens rule) — `docs/design.md#review-loop-and-timeline`
**Design picture?** No change. The hook, the phases and the push gate keep their places; the rule is a pass-level convention. `docs/design.md` mentions the hook only as the `test` verb's entry, which stays true. The owner already decided (2026-10-20), so no design question to ask.
**Dependencies**: Overlaps in-flight `feature/issue-321`, which edits `dispatch_phase.sh` (a new round-3 block in `cmd_handoff` ending just above the `exit_contract`/`conventions=` echoes, plus the `round_count` block), `.claude/skills/run-issue/SKILL.md` (hunks around lines 149, 282, 391, 402, 418, 697) and `test_dispatch_phase.sh`. No functional dependency; merge order only.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Name the rule before bending it | Action needed | The change exempts intermediate commits from a hook, close to the AGENTS.md Never rule on skipping hooks. The body names the rule and keeps `--no-verify` forbidden, but the wording must say the exemption is a standing, owner-decided rule for dispatched passes only (SKIP on intermediate commits, hook still runs on the entry commit), and that a hand-run session or a pass that cannot run the suite does not get it. Record the owner decision date in the AGENTS.md row. |
| Enforce what matters, as simply as possible | Action needed | The new gate ("run the full suite once before the entry") is prose-only: nothing fails if a pass SKIPs commits and never runs the suite. Name the backstop: the entry commit's own hook run executes the suite regardless, and the pre-push gate is unchanged. State that in the handoff text and the AGENTS.md row so it is not read as an honour system. |
| A change includes its consequences | Watch | Beyond the listed five, the implement exit contract in `dispatch_phase.sh` and the AGENTS.md "Always" line "Run pre-commit hooks before committing" also describe the pass and are qualified by the new rule. Pre-commit on every changed file, run once, still covers the lint hooks that SKIP does not skip. |
| Test what breaks | Watch | The pinned test should assert the text for `implement` and `address-findings` and its absence for the other five phases, so a review handoff never tells a reviewer to skip hooks. Add the case to the existing handoff block of `test_dispatch_phase.sh`, not new scaffolding. |
| Small steps; step back when they stop converging | OK | Small and placeable: the owner's chosen alternative needs no new mechanism. |
| Know whether it works | Watch | The acceptance says what a pass runs, not how anyone tells later. Cheap check: the next dispatched fix pass should show one suite run plus the entry commit's hook run; say where that is looked at. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0004 / 0005 — Enforcement layering | Yes | Pre-commit stays local feedback; CI and the pre-push run stay authoritative. The change removes repeats at the local layer only. |
| 0013 — progress.md vocabulary | Yes | "Before writing its progress entry" only; no new entry type or shape. |
| 0014 — In-process phase handoff | Yes | Touches the handoff and run-issue step 4; stays on the one dispatch path and the existing `conventions=` field, no new handoff field. |
| 0017 — Design doc is the current picture | No | No change to how the parts fit; no ADR needed. |

### Consequences

- AGENTS.md "Script Reference" row for `run_script_tests.sh` and the hook comment (both already listed in the issue).
- Framework adapters: none needed (shared `AGENTS.md` plus Claude-skill text; Codex/Gemini follow `AGENTS.md`).
- Merge order with the in-flight 321 branch: see Recommendations.

### Recommendations

- Place the `dispatch_phase.sh` change as a small per-skill `case` that sets a variable used by the `conventions=` echo, touching only that line and leaving the `exit_contract` if/else (the nearest text 321 changes) alone, so it merges cleanly after 321.
- Add the run-issue step 4 text as one short paragraph in the implement-pass section (around line 285), not in the table rows or numbered lists 321 edits; rebase on `main` after 321 lands, re-run `test_dispatch_phase.sh`, and append the new test case at the end of the handoff block.
- Word the rule as owner-decided and pass-scoped: SKIP only on intermediate atomic commits of a dispatched implement / address-findings pass; full suite plus pre-commit on all changed files before the entry; the entry commit runs the hook; `--no-verify` stays forbidden; a failing run is fixed first.
- Make the pinned test check that the other five phases' `conventions=` do not carry the rule.
- Say in the PR how the result is looked at: the next dispatched fix pass shows one suite run, not one per commit.

## Plan Authored
**Status**: complete
**When**: 2026-10-20 14:46 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-399/plan.md` at `2281176b`

Once-per-pass rule (owner-decided 2026-10-20) added as a per-skill case feeding the conventions= echo in dispatch_phase.sh for implement and address-findings only, plus address-findings steps 3-5, one run-issue step 4 paragraph, the AGENTS.md hook line and script row, the hook comment, and a pinned test placed mid-file. Placed clear of feature/issue-321's hunks; main merges in after 321 lands.
