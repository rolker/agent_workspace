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

## Plan Review
**Status**: complete
**When**: 2026-10-20 14:52 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #399 — Dispatched passes run the script test suite once per pass, not per commit
**Plan**: `.agent/work-plans/issue-399/plan.md` at `2281176b`
**Branch**: `feature/issue-399`

Scope of this review: placement, wording and consequences. The mechanism (suite once per dispatched pass, hook unchanged) is the owner's 2026-10-20 decision and is not re-opened.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Six files, one rule, one test; one PR. |
| Issue alignment | Needs work | Covers every item in the issue's Change list and the issue review's recommendations. Serves, as checked: "Quality of the work (the full suite remains the gate before any push; only repeats go) — `docs/design.md#review-loop-and-timeline`" — goal exists in README.md (`### Quality of the work`: "economical, but never at the cost of quality"), anchor resolves (design.md:423). The backstop wording it carries is factually wrong (finding 1). |
| File targeting | Needs work | Right files. The test insertion point and the header sentence both land on 321 hunks, against the plan's own claim (findings 3, 4). `run_script_tests.sh` header also states the SKIP allowance and is not listed (finding 6). |
| Consequences | Needs work | Backstop named in five places is not the one that exists; the real one is CI (finding 1). The pre-entry step as worded runs the suite twice (finding 2). |
| Principle alignment | Needs work | "Verify before claiming" / "Enforce what matters": the "not an honour system" claim rests on the entry commit running the suite, which it does not. "Name the rule before bending it": scoping and `--no-verify` wording are good. "Test what breaks": presence-in-two / absence-in-five test is right. "Only what's needed": the AGENTS.md Always-line qualifier is not needed (finding 5). |
| ADR compliance | Good | 0004/0005 hold once the backstop is named as CI (the authoritative layer). 0013: no new entry shape. 0014: existing `conventions=` field, no new field. 0017: no design-picture change, but see finding 6 on `docs/design.md#rules`. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences / Verify before claiming] (high)** — The named backstop does not exist. The entry commit (`progress_append.sh` / `review_progress.sh persist`) commits only `.agent/work-plans/issue-<N>/progress.md` (`git commit -- <file>`, progress_append.sh:21), and the hook excludes that path (`exclude: ^\.agent/work-plans/`, .pre-commit-config.yaml:76), so "the entry commit runs the hook normally" executes no suite. There is also no pre-push git hook: only `pre-commit` is installed and every local hook is `stages: [pre-commit]`. The real mechanical backstop is CI: the Lint job runs `make lint` = `pre-commit run --all-files`, which always runs `validate-script-tests` (run_script_tests.sh header; `docs/design.md#rules` row "Hooks are not skipped", enforced by `CI`), and `merge_pr.sh` waits for CI before merging. Resolution: in the handoff text, both skills, the AGENTS.md row and the hook comment, name the backstop as CI on push plus `merge_pr.sh`'s CI wait; drop the claim that the entry commit runs the suite (keeping "the entry commit is not SKIPped" is harmless but checks nothing). Fix the acceptance check to match ("one suite run per pass", not "plus the entry commit's hook run"). The owner's decision text contains the same premise ("the progress-entry commit runs the hook normally"); his decision stands, but the correction should be shown to him with the PR.
2. **[Consequences] (medium)** — The pre-entry step runs the suite twice. `pre-commit run --files <changed>` without SKIP runs `validate-script-tests` itself whenever any changed file matches its `files:` pattern, so "run `run_script_tests.sh` once and `pre-commit run --files ...`" costs about 10 minutes, not 5. Resolution (listed for veto): one command, `pre-commit run --files <every file changed in the pass>` with no SKIP — it runs the suite exactly when a per-commit hook would have and every lint hook too; or keep the explicit suite run and set `SKIP=validate-script-tests` on the `pre-commit run`. Also say the run is against the final tree: after fixing a failure, run it again.
3. **[File targeting / merge claim] (medium)** — The test placement collides with 321. 321 inserts 53 lines at main line 431, i.e. between the "handoff: no worktree for --issue" case (test_dispatch_phase.sh:429) and `TEST: resolve_worktree` / `# (a) registry lookup` (433) — exactly where the plan puts its cases. The plan read the hunk header's context text `echo ""` as end-of-file. Resolution: place the new cases after the implement exit-contract case (line 418) and before the `--entry-type` / `--model` override case (line 420); 321 has no hunk there (its hunks: 40, after 228, after 431).
4. **[File targeting / merge claim] (low)** — `dispatch_phase.sh` header: "the end of the handoff usage text" is the `--skill-prefix` paragraph (lines 20–22), and 321 inserts its round-3 sentence right after line 22, so this is a certain conflict, contradicting "away from the `--skill-prefix` paragraph". Resolution: put the sentence after line 16 ("...every dispatched phase must follow.") or rely on the code comment beside the new `case`. Verified clean: the `case` + `conventions=` echo (321's `cmd_handoff` hunk ends before the `AGENT_NAME` check, ~20 lines above); the run-issue paragraph after the `## Implementation` shape paragraph (~line 310; 321's nearest hunks at 282–286 and 389+); 321 touches none of address-findings, AGENTS.md, `.pre-commit-config.yaml`.
5. **[Principle: Only what's needed / Ask First] (low)** — Step 4(a), the AGENTS.md "Always" line qualifier, is outside the owner's decided Change list, AGENTS.md is Ask-First, and the line stays literally true (SKIP leaves every other pre-commit hook running). Resolution: drop 4(a); the Script Reference row (in the decided list) carries the rule.
6. **[Consequences] (low)** — Two more places state the SKIP allowance or the backstop: `run_script_tests.sh` header lines 46–48 ("sanctioned escape for work-in-progress commits") and `docs/design.md#rules` row "Hooks are not skipped (no `--no-verify`)". Resolution: one clause in the script header pointing to the once-per-pass rule (or say why it is left); in Design Picture, say the Rules row stays true because CI is its enforcer, and cite it as the backstop.
7. **[File targeting] (low)** — `.pre-commit-config.yaml`: keep the new comment above the `- id: validate-script-tests` line. `test_script_tests_hook_scope.sh` extracts the block from that line to the next `- id:` and reads the first `files:` / `exclude:` lines; a comment above the id is outside what it parses.

### Summary

Placement of the handoff `case`, the run-issue paragraph and the address-findings text is sound, and the two-in / five-out test is the right pin. Not ready as written: the backstop it states in five places does not run (the entry commit is excluded from the hook; there is no pre-push hook — CI is the real gate), the pre-entry step doubles the suite run, and the test placement collides with the 321 branch. All fixes are wording and placement; none changes what the work is for.

### Recommended Actions

- [ ] Replace the backstop wording everywhere with CI (`make lint` on push runs the full suite) plus `merge_pr.sh`'s CI wait; drop "the entry commit's hook run executes the suite"; fix the acceptance check to match.
- [ ] Make the pre-entry step one suite run, not two (single `pre-commit run --files <changed>` with no SKIP, or SKIP on the pre-commit run beside an explicit suite run); re-run after a fix.
- [ ] Move the test cases to between test_dispatch_phase.sh:418 and :420; correct the 321 merge paragraph (321 inserts at main line 431).
- [ ] Move the `dispatch_phase.sh` header sentence off the `--skill-prefix` paragraph (after line 16), or drop it in favour of the code comment.
- [ ] Drop the AGENTS.md "Always" line qualifier (step 4a).
- [ ] Add the `run_script_tests.sh` header clause and the `docs/design.md#rules` note in Design Picture.
- [ ] Keep the `.pre-commit-config.yaml` comment above the hook's `- id:` line.

## Checkpoint
**Status**: complete
**When**: 2026-10-20 14:51 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (plan review verdict needs-work; all seven findings are wording and placement, none goal-level; the owner's mechanism decision of 2026-10-20 stands)
**After**: plan
**Decision**: revise
Revise per the Plan Review's seven findings. Host directions: the safety net is CI (make lint runs the suite on every push; merge_pr.sh waits for it), not the entry commit's hook, which skips work-plans; name CI in every place and change the acceptance check to "one suite run per pass". Run `pre-commit run --files <every file changed in the pass>` once before the entry, with no separate suite run (that run includes the suite), and again after any fix. Drop the AGENTS.md "Always" line edit; the AGENTS.md script-reference row stays in the plan but is flagged for the owner's explicit yes at the PR (Ask First). Move the test cases to between the implement exit-contract case and the --entry-type override case; put the header sentence after line 16; cite the run_script_tests.sh header and the design.md Rules row; keep the hook comment above the id line. The correction to the owner's decision text (entry hook does not run the suite) goes to him in the hand-back.
