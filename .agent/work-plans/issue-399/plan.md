# Plan: Dispatched passes run the script test suite once per pass, not per commit

## Issue

https://github.com/rolker/agent_workspace/issues/399

## Context

The `validate-script-tests` hook runs the whole suite (about 5 minutes) on every commit touching `.agent/`, `.claude/` and similar. A dispatched implement or fix pass makes several atomic commits, so it pays that cost once per commit (8 of 11 commits in the #321 fix pass, about 40 of 57 minutes). The owner decided on 2026-10-20: the hook stays unchanged; a dispatched pass runs the suite once, before its progress entry. This plan is about placing that rule in the handoff, the skill texts and AGENTS.md, and pinning it in a test, in a way that merges cleanly after the in-flight `feature/issue-321` branch.

The rule, in one wording used everywhere (owner-decided 2026-10-20, scoped to dispatched implement and address-findings passes):

- Set `SKIP=validate-script-tests` only on the intermediate atomic commits of the pass. `--no-verify` stays forbidden.
- Before writing the entry, run `pre-commit run --files <every file changed in the pass>` once, with no SKIP. It includes `validate-script-tests`, so the suite runs exactly once; there is no separate suite run. A failing run is fixed first, then the same command is run again on the final tree.
- Backstop (not an honour system): CI. `make lint` runs `pre-commit run --all-files`, which always runs the full suite, on every push, and `merge_pr.sh` waits for it. The entry commit's own hook is not the backstop: it commits only `.agent/work-plans/issue-<N>/progress.md`, which the hook excludes.
- A hand-run session, or a pass that cannot run the suite, does not get the exemption.

## Approach

1. **`dispatch_phase.sh`, per-skill `case` feeding `conventions=`** — in `cmd_handoff`, after the `exit_contract` if/else and before the `conventions=` echo, add `local pass_rule=""` and `case "$skill" in implement|address-findings) pass_rule=" <rule text>" ;; esac`; the echo becomes `...remove what you create.${pass_rule}"`. Only `implement` and `address-findings` get text; the other five phases' `conventions=` stay byte-identical. No new handoff field (ADR-0014). Header comment gets one sentence naming the rule, placed after line 16 ("...every dispatched phase must follow."), not at the `--skill-prefix` paragraph (lines 20-22).
2. **`address-findings/SKILL.md`** — step 3 (the commit step): state the dispatched-pass exemption (SKIP on intermediate commits, still never `--no-verify`) next to "Never `--no-verify`"; step 4 ("Re-run hooks / quick local checks"): make the once-per-pass run the explicit step (one `pre-commit run --files` on every changed file, no SKIP; fix failures and re-run); step 5: the entry commit is committed as usual, and the text names CI as the backstop.
3. **`run-issue/SKILL.md` step 4** — one short paragraph appended after the `## Implementation` shape paragraph ("The `**PR**` / `**Branch**` correlation line is required..." ends at the paragraph before `### 4a`), stating the same rule for the dispatched implement and fix passes and pointing at the handoff's `conventions=`. Not in the table rows, numbered lists or checkpoint list.
4. **`AGENTS.md`** — the `run_script_tests.sh` Script Reference row only: replace "`SKIP=validate-script-tests` for WIP commits" with the owner-decided once-per-pass rule, dated 2026-10-20, naming CI as the backstop and that `--no-verify` is still never allowed. **AGENTS.md is Ask First: this edit needs the owner's explicit yes at the PR.** The "Always" line "Run pre-commit hooks before committing" is not edited (it stays literally true: SKIP leaves every other hook running).
5. **`.pre-commit-config.yaml`** — comment above the `- id: validate-script-tests` line (outside the block `test_script_tests_hook_scope.sh` parses, which runs from that line to the next `- id:`): the hook runs on every commit; dispatched passes skip it only on intermediate commits and run it once before the entry, so the exemption is not read as hook-skipping. No change to the hook itself.
5b. **`run_script_tests.sh` header, lines 46-48** — the "sanctioned escape for work-in-progress commits" sentence: add one clause pointing to the once-per-pass rule for dispatched passes and to CI as the backstop. Comment only.
6. **Test in `test_dispatch_phase.sh`** — add between the implement exit-contract case (main line 418) and the `--entry-type` / `--model` override case (line 420), where feature/issue-321 has no hunk. Cases: `implement` and `address-findings` `conventions=` lines contain `SKIP=validate-script-tests`, `run_script_tests.sh` and "entry"; the other five (`review-issue`, `plan-task`, `review-plan`, `review-code`, `triage-reviews`) `conventions=` lines contain neither `SKIP` nor `run_script_tests`; every phase's `conventions=` still carries the existing "local time with offset" / "scratchpad" text. Reuse the file's handoff runner.
7. **Verify** — run `test_dispatch_phase.sh` while developing, then one `pre-commit run --files <every changed file>` with no SKIP before the entry (it includes the suite; no separate suite run), repeated after any fix. Per the rule itself, the implementing pass may SKIP on intermediate commits.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/dispatch_phase.sh` | `case` on `$skill` setting `pass_rule`, appended to the `conventions=` echo; one header-comment sentence |
| `.claude/skills/address-findings/SKILL.md` | Steps 3, 4, 5: the once-per-pass rule, CI as backstop |
| `.claude/skills/run-issue/SKILL.md` | One short paragraph at the end of step 4's dispatched-implement section |
| `AGENTS.md` | `run_script_tests.sh` Script Reference row rewritten (Ask First: owner's explicit yes at the PR) |
| `.pre-commit-config.yaml` | Comment above the `- id: validate-script-tests` line |
| `.agent/scripts/tests/run_script_tests.sh` | Header lines 46-48: clause on the once-per-pass rule (comment only) |
| `.agent/scripts/tests/test_dispatch_phase.sh` | Pin: rule in two phases' `conventions=`, absent from the other five |

## Merge with feature/issue-321

Read from the 321 worktree (not edited): 321 changes `dispatch_phase.sh` in the header comment (a round-3 sentence right after the `--skill-prefix` paragraph, line 22), a new round-3 block placed before the `AGENT_NAME` check, and `round_count()`; `run-issue/SKILL.md` at lines 152, 154, 283, 390-405, 416, 686; `test_dispatch_phase.sh` at line 40, after line 228 and 53 lines inserted at main line 431 (between the "no worktree for --issue" case and `# (a) registry lookup`; the `echo ""` in the hunk header is context, not end of file). It does not touch address-findings, AGENTS.md or `.pre-commit-config.yaml`. This plan avoids those hunks: the `case` and the `conventions=` echo sit after the `exit_contract` if/else, a region 321 leaves alone; the header sentence goes after line 16, clear of the `--skill-prefix` paragraph and 321's insertion after line 22; the run-issue paragraph goes after the `## Implementation` shape paragraph (around line 310), clear of line 283 and the 390+ hunks; the test goes between main lines 418 and 420, where 321 has no hunk. Residual risk: the run-issue paragraph is within a few lines of 321 hunks, so git may report adjacent-hunk conflicts; resolve by keeping both.

## Sequencing

Implement on this branch first, then merge `main` after 321 lands and before the final pre-push review. After the merge, re-run `test_dispatch_phase.sh` (321 adds cases to it) and the full suite once.

## Prior Art

The hook's existing `SKIP=validate-script-tests` allowance for WIP commits in AGENTS.md (extended and scoped, not new). Rejected, by the owner: rescoping the hook to changed suites (needs a script-to-suite map that drifts, and suites test scripts together). Possible later step: running suites in parallel inside `run_script_tests.sh`. Nothing new is built.

## Serves

Quality of the work (the full suite still runs before the entry and in CI on every push; only repeats go) — `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to the design picture. The hook, the phases and CI keep their places; the rule is a pass-level convention. The `docs/design.md#rules` row "Hooks are not skipped (no `--no-verify`)" stays true: its enforcer is `CI` (`make lint` runs every hook on all files), which is also this rule's backstop; SKIP on intermediate commits is not `--no-verify`, and CI catches it either way. Cited as the safety net; no edit.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Name the rule before bending it | The exemption is stated as a standing, owner-decided (2026-10-20) rule scoped to dispatched implement and address-findings passes; `--no-verify` stays forbidden; hand-run sessions do not get it |
| Enforce what matters, as simply as possible | Backstop named in every place as CI (`make lint` on push, awaited by `merge_pr.sh`); the entry commit's hook is not claimed as a check. No new mechanism |
| A change includes its consequences | Handoff, both skill texts, the AGENTS.md Script Reference row, the hook comment, the `run_script_tests.sh` header, the test |
| Test what breaks | Test pins presence in two phases and absence in five, so a review handoff never tells a reviewer to skip hooks |
| Know whether it works | Acceptance check below |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0004 / 0005 enforcement layering | Yes | Local pre-commit feedback loses repeats only; CI stays authoritative (there is no pre-push git hook) |
| 0013 progress.md vocabulary | Yes | No new entry type or shape; "before the entry" only |
| 0014 in-process handoff | Yes | Uses the existing `conventions=` field; no new field |
| 0017 design doc | No | No design-picture change |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `conventions=` text | `test_dispatch_phase.sh` handoff cases | Yes |
| The dispatched-pass rule | address-findings skill, run-issue step 4, AGENTS.md row, hook comment, `run_script_tests.sh` header | Yes |
| Implement `exit_contract` text | Unchanged; the rule rides on `conventions=` so 321's region is untouched | Yes (deliberately not edited) |

## Open Questions

None on the mechanism; the owner decided it. Ask First: the AGENTS.md row edit needs his explicit yes at the PR.

## Estimated Scope

Single PR. Acceptance check, named for the PR description: the next dispatched fix pass shows one suite run per pass, not one per commit (look at the pass's commit timings or hook output in its transcript), and CI still runs the full suite on every push.

## Hand-back Notes

The owner's decision text in the issue says the progress-entry commit runs the hook normally. That premise is wrong: the entry commit touches only `.agent/work-plans/`, which the hook excludes, so it runs no suite. His decision stands; CI is the backstop. The PR description corrects the premise and shows him the AGENTS.md row edit for his explicit yes.
