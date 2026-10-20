# Plan: Dispatched passes run the script test suite once per pass, not per commit

## Issue

https://github.com/rolker/agent_workspace/issues/399

## Context

The `validate-script-tests` hook runs the whole suite (about 5 minutes) on every commit touching `.agent/`, `.claude/` and similar. A dispatched implement or fix pass makes several atomic commits, so it pays that cost once per commit (8 of 11 commits in the #321 fix pass, about 40 of 57 minutes). The owner decided on 2026-10-20: the hook stays unchanged; a dispatched pass runs the suite once, before its progress entry. This plan is about placing that rule in the handoff, the skill texts and AGENTS.md, and pinning it in a test, in a way that merges cleanly after the in-flight `feature/issue-321` branch.

The rule, in one wording used everywhere (owner-decided 2026-10-20, scoped to dispatched implement and address-findings passes):

- Set `SKIP=validate-script-tests` only on the intermediate atomic commits of the pass. `--no-verify` stays forbidden.
- Before writing the entry, run the full suite (`.agent/scripts/tests/run_script_tests.sh`) once and `pre-commit run --files <every changed file>`. A failing run is fixed first.
- The entry commit runs the hook normally.
- Backstop (not an honour system): the entry commit's own hook run executes the suite, and the pre-push gate is unchanged; nothing is pushed before either.
- A hand-run session, or a pass that cannot run the suite, does not get the exemption.

## Approach

1. **`dispatch_phase.sh`, per-skill `case` feeding `conventions=`** — in `cmd_handoff`, after the `exit_contract` if/else and before the `conventions=` echo, add `local pass_rule=""` and `case "$skill" in implement|address-findings) pass_rule=" <rule text>" ;; esac`; the echo becomes `...remove what you create.${pass_rule}"`. Only `implement` and `address-findings` get text; the other five phases' `conventions=` stay byte-identical. No new handoff field (ADR-0014). Header comment gets one sentence naming the rule.
2. **`address-findings/SKILL.md`** — step 3 (the commit step): state the dispatched-pass exemption (SKIP on intermediate commits, still never `--no-verify`) next to "Never `--no-verify`"; step 4 ("Re-run hooks / quick local checks"): make the once-per-pass run the explicit step (full suite plus pre-commit on all changed files, fix failures first); step 5: the entry commit runs the hook normally.
3. **`run-issue/SKILL.md` step 4** — one short paragraph appended after the `## Implementation` shape paragraph ("The `**PR**` / `**Branch**` correlation line is required..." ends at the paragraph before `### 4a`), stating the same rule for the dispatched implement and fix passes and pointing at the handoff's `conventions=`. Not in the table rows, numbered lists or checkpoint list.
4. **`AGENTS.md`** — (a) the "Always" line "Run pre-commit hooks before committing" gets a short qualifier pointing to the Script Reference row; (b) the `run_script_tests.sh` row: replace "`SKIP=validate-script-tests` for WIP commits" with the owner-decided once-per-pass rule, dated 2026-10-20, naming the backstop and that `--no-verify` is still never allowed.
5. **`.pre-commit-config.yaml`** — comment above `validate-script-tests`: the hook runs on every commit; dispatched passes skip it only on intermediate commits and run the suite once before the entry, so the exemption is not read as hook-skipping. No change to the hook itself.
6. **Test in `test_dispatch_phase.sh`** — add after the existing handoff cases (after the "no worktree for --issue" case, before the `# (a) registry lookup` block), not at the end of the file. Cases: `implement` and `address-findings` `conventions=` lines contain `SKIP=validate-script-tests`, `run_script_tests.sh` and "entry"; the other five (`review-issue`, `plan-task`, `review-plan`, `review-code`, `triage-reviews`) `conventions=` lines contain neither `SKIP` nor `run_script_tests`; every phase's `conventions=` still carries the existing "local time with offset" / "scratchpad" text. Reuse the file's handoff runner.
7. **Verify** — run the changed suite, then `run_script_tests.sh` once; `pre-commit run --files` on the changed files. Per the rule itself, the implementing pass may SKIP on intermediate commits and run the suite once before its entry.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/dispatch_phase.sh` | `case` on `$skill` setting `pass_rule`, appended to the `conventions=` echo; one header-comment sentence |
| `.claude/skills/address-findings/SKILL.md` | Steps 3, 4, 5: the once-per-pass rule |
| `.claude/skills/run-issue/SKILL.md` | One short paragraph at the end of step 4's dispatched-implement section |
| `AGENTS.md` | "Always" hook line qualifier; `run_script_tests.sh` row rewritten |
| `.pre-commit-config.yaml` | Comment above `validate-script-tests` |
| `.agent/scripts/tests/test_dispatch_phase.sh` | Pin: rule in two phases' `conventions=`, absent from the other five |

## Merge with feature/issue-321

Read from the 321 worktree (not edited): 321 changes `dispatch_phase.sh` in the header comment (near the `--skill-prefix` paragraph), a new round-3 block placed before the `AGENT_NAME` check, and `round_count()`; `run-issue/SKILL.md` at lines 152, 154, 283, 390-405, 416, 686; `test_dispatch_phase.sh` at line 40, after line 228 and at the end of the file (before the final `echo ""`). It does not touch address-findings, AGENTS.md or `.pre-commit-config.yaml`. This plan avoids those hunks: the `case` and the `conventions=` echo sit after the `exit_contract` if/else, a region 321 leaves alone; the header sentence goes at the end of the handoff usage text, away from the `--skill-prefix` paragraph; the run-issue paragraph goes after the `## Implementation` shape paragraph (around line 310), clear of line 283 and the 390+ hunks; the test goes mid-file, not at the end. Residual risk: the header comment and the run-issue paragraph are within a few lines of 321 hunks, so git may report adjacent-hunk conflicts; resolve by keeping both.

## Sequencing

Implement on this branch first, then merge `main` after 321 lands and before the final pre-push review. After the merge, re-run `test_dispatch_phase.sh` (321 adds cases to it) and the full suite once.

## Prior Art

The hook's existing `SKIP=validate-script-tests` allowance for WIP commits in AGENTS.md (extended and scoped, not new). Rejected, by the owner: rescoping the hook to changed suites (needs a script-to-suite map that drifts, and suites test scripts together). Possible later step: running suites in parallel inside `run_script_tests.sh`. Nothing new is built.

## Serves

Quality of the work (the full suite remains the gate before any push; only repeats go) — `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to the design picture. The hook, the phases and the push gate keep their places; the rule is a pass-level convention.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Name the rule before bending it | The exemption is stated as a standing, owner-decided (2026-10-20) rule scoped to dispatched implement and address-findings passes; `--no-verify` stays forbidden; hand-run sessions do not get it |
| Enforce what matters, as simply as possible | Backstop named in every place: the entry commit's hook run and the unchanged pre-push gate. No new mechanism |
| A change includes its consequences | Handoff, both skill texts, the AGENTS.md "Always" line and Script Reference row, the hook comment, the test |
| Test what breaks | Test pins presence in two phases and absence in five, so a review handoff never tells a reviewer to skip hooks |
| Know whether it works | Acceptance check below |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0004 / 0005 enforcement layering | Yes | Local pre-commit feedback loses repeats only; pre-push and CI stay authoritative |
| 0013 progress.md vocabulary | Yes | No new entry type or shape; "before the entry" only |
| 0014 in-process handoff | Yes | Uses the existing `conventions=` field; no new field |
| 0017 design doc | No | No design-picture change |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `conventions=` text | `test_dispatch_phase.sh` handoff cases | Yes |
| The dispatched-pass rule | address-findings skill, run-issue step 4, AGENTS.md line and row, hook comment | Yes |
| Implement `exit_contract` text | Unchanged; the rule rides on `conventions=` so 321's region is untouched | Yes (deliberately not edited) |

## Open Questions

None; the owner decided the mechanism and the wording.

## Estimated Scope

Single PR. Acceptance check, named for the PR description: the next dispatched fix pass shows one suite run plus the entry commit's hook run, not one per commit (look at the pass's commit timings or hook output in its transcript), and the suite still runs in full before any push.
