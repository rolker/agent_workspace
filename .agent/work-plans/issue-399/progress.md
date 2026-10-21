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

## Plan Authored
**Status**: complete
**When**: 2026-10-20 14:54 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-399/plan.md` at `6a1fdc7d`

Revised per the seven Plan Review findings: backstop is CI (the entry commit is excluded from the hook), one pre-commit run before the entry, test cases moved between main lines 418 and 420, header sentence after line 16, AGENTS.md Always edit dropped (script row kept, Ask First), run_script_tests.sh header and design.md Rules row cited, hook comment above the id line. Hand-back notes record the owner's wrong premise.

## Plan Review
**Status**: complete
**When**: 2026-10-21 09:34 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #399 — Dispatched passes run the script test suite once per pass, not per commit
**Plan**: `.agent/work-plans/issue-399/plan.md` at `6a1fdc7d`
**Branch**: `feature/issue-399`

Round 2. Scope: the revised plan against round 1's seven findings, the host's Checkpoint directions and the principles. The mechanism (suite once per dispatched pass; the pre-commit hook itself unchanged) is the owner's 2026-10-20 decision and is not re-opened.

### Round 1 findings

| # | Round 1 finding | Resolved? | Checked against |
|---|---|---|---|
| 1 | Backstop is CI, not the entry commit | Yes | validate.yml: push to `main`/`feature/**`/`fix/**` and PRs to main; Lint job's SKIP list does not include `validate-script-tests`; `make lint` = `pre-commit run --all-files` (Makefile:116); merge_pr.sh waits for CI (step 2, ~line 997). Acceptance now "one suite run per pass" |
| 2 | One pre-commit run, not two | Yes, in the rule; the test still pins the old string (finding 2 below) | Hook has `pass_filenames: false` and a `files:` pattern, so `pre-commit run --files` runs the suite once when any changed file matches |
| 3 | Test placement off 321's hunk | Yes | 321's test hunks: line 40, after 228, after 431; 418–420 is clear |
| 4 | Header sentence off the `--skill-prefix` paragraph | Partly: clear of 321, but the new spot splits a sentence (finding 3 below) | 321 inserts after header line 22 |
| 5 | Drop the AGENTS.md "Always" edit | Yes; the Script Reference row is flagged Ask First for the owner at the PR | — |
| 6 | `run_script_tests.sh` header and design.md Rules row | Yes | Header lines 46–48 match; design.md:155 row, enforcer `CI` |
| 7 | Hook comment above the `- id:` line | Yes | `test_script_tests_hook_scope.sh` reads `^\s*files:` / `^\s*exclude:` from the id line on; a comment cannot match |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Seven files, one rule, one test; one PR. |
| Issue alignment | Good | Covers the issue's Change list. Serves, as checked: "Quality of the work (the full suite still runs before the entry and in CI on every push; only repeats go) — `docs/design.md#review-loop-and-timeline`" — goal at README.md:33, anchor at design.md:423. The acceptance is restated without the issue's wrong "plus the entry commit's hook run", and the hand-back notes carry the correction to the owner. |
| File targeting | Needs work | Right files. `dispatch_phase.sh` header placement splits a sentence (finding 3). |
| Consequences | Needs work | Project-worktree handoffs would carry workspace-only text (finding 1). |
| Principle alignment | Needs work | "Put each thing at the level it applies to" / "Verify before claiming": the rule names a workspace hook and workspace CI but would be printed for project worktrees too (finding 1). "Test what breaks": the pin checks a string the revised rule no longer needs (finding 2). "Name the rule before bending it", "Enforce what matters", "Know whether it works", "Look for prior art": good. |
| ADR compliance | Good | 0004/0005: CI stays the authoritative layer. 0013: no new entry shape. 0014: existing `conventions=` field. 0017: no design-picture change; Rules row cited. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences / Put each thing at the level it applies to] (must-fix, medium)** — The `case` keys only on `$skill`, but `cmd_handoff` also serves `--type project` (dispatch_phase.sh:298, `type` defaults to workspace; run-issue's main use is project issues). In a project worktree the implement / address-findings handoff would tell the agent to SKIP `validate-script-tests` (a workspace-only hook) and name `make lint` CI as the backstop, which a project may not have. Resolution: emit `pass_rule` only when `$type` is `workspace`; add one test case that a `--type project` implement handoff has no rule (the file already builds a project sandbox, `SBP1`, in the `resolve_worktree --type project` block); in address-findings, tie the exemption to the handoff's `conventions=` carrying it, so a project pass or a hand-run session does not apply it.
2. **[Test what breaks] (must-fix, low)** — Step 6 pins `run_script_tests.sh` in the implement / address-findings `conventions=` lines and checks its absence in the other five. That is round 1's wording: the revised rule's one command is `pre-commit run --files`, and naming `run_script_tests.sh` in the handoff invites the separate second run that round 1 finding 2 removed. Resolution: pin `SKIP=validate-script-tests`, `pre-commit run --files` and `CI` in the two phases; check the other five lack `SKIP=validate-script-tests` and `pre-commit run --files`.
3. **[File targeting] (must-fix, low)** — "After line 16" splits a sentence: line 16 reads "workspace conventions every dispatched phase must follow. Output is" and that sentence runs to line 19. Resolution: insert after line 19 ("...only when --prompt-file was given)."); lines 20–22 stay untouched between it and 321's insertion after line 22, so the merge stays clean. Or fold a clause into line 16.
4. **[Consequences] (suggestion, low)** — "Every file changed in the pass" is left for the agent to assemble; a missed file is a missed lint. Name the command, e.g. `pre-commit run --files $(git diff --name-only main...HEAD)` — the whole branch costs no extra suite run, and pre-commit drops deleted paths itself (pre_commit/commands/run.py:75, `os.path.lexists`).
5. **[Verify before claiming] (suggestion, low)** — "So the suite runs exactly once" holds only when a changed file matches the hook's `files:` pattern; a pass touching only `docs/` runs it zero times, as per-commit would. Say "at most once". Likewise "CI on every push" is push to `main`/`feature/**`/`fix/**` plus PRs to main; dispatched passes are on `feature/issue-<N>`, so it holds for them.

### Summary

All seven round 1 findings are resolved, the header one only partly. Three small must-fixes remain: scope the rule to workspace worktrees, pin the right string in the test, and move the header sentence three lines down. The review is converging; all three are line-level edits to the plan, none changes what the work is for.

### Recommended Actions

- [ ] Emit the rule only for `--type workspace`; add a project-type handoff test case showing no rule; make address-findings' exemption conditional on the handoff carrying it.
- [ ] Change the test pin from `run_script_tests.sh` to `SKIP=validate-script-tests`, `pre-commit run --files` and `CI`, with the matching absence check in the other five phases.
- [ ] Put the header sentence after line 19, not line 16.
- [ ] (suggestion) Name the file-list command for the single pre-commit run.
- [ ] (suggestion) Say "at most once" for the suite run.

## Checkpoint
**Status**: complete
**When**: 2026-10-21 09:35 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Plan review round 2 (ee17ac4c): needs-work, all seven round-1 must-fixes resolved, three new must-fixes (workspace-only rule emission, test wording, header insertion point) and two suggestions (name the file-list command, "at most once"). Owner's answer: "Revise (Recommended)".

## Plan Authored
**Status**: complete
**When**: 2026-10-21 09:37 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-399/plan.md` at `c6a7701b`

Revised per plan review round 2: the rule is emitted only for workspace handoffs (project handoff test added, address-findings applies it only when the handoff carries it); test pins `SKIP=validate-script-tests`, `pre-commit run --files` and `CI` instead of `run_script_tests.sh`; header sentence moves to after line 19; the pre-entry run names `pre-commit run --files $(git diff --name-only main...HEAD)`; "at most once" with CI's real trigger set.
