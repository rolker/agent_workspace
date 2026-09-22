# Plan: run-issue: fold in the live-exercise fixes (identity env, BEFORE type string, Copilot wait, scratch hygiene, deferred-suggestion checkpoint)

## Issue

https://github.com/rolker/agent_workspace/issues/307

## Context

The 2026-09-21 live-exercise write-up on #276 (three issues driven end to
end through `/run-issue`) surfaced seven small text/one-line gaps in the
loop's own skill docs and handoff output, plus one checkpoint-routing
question (item 6) that the Issue Review flagged as under-specified. The
owner's Checkpoint on this issue's progress.md resolved item 6: **reuse**
the existing `review_progress.sh check --deferred "<reason>"` convention
(a checked box, deferred or not, is already excluded from
`dispatch_phase.sh`'s `open_findings()` — confirmed at
`dispatch_phase.sh:421-426`, `f.get("checked")` is the only test). No new
`[~]` marker, no changes to `review_progress.sh`'s findings/check logic or
`.agent/knowledge/review_loop_lifecycle.md` — only a new host step
documented in `run-issue/SKILL.md`.

This plan is text edits to two skill docs, a few printed lines in
`dispatch_phase.sh`'s handoff block, and one host-step addition — no
change to the `next` decision table's routing logic.

## Approach

1. **`.claude/skills/run-issue/SKILL.md` step 1 (identity)** — add a line
   before/alongside "Follow `.claude/skills/start-task/SKILL.md` steps
   1–4" stating that `dispatch_phase.sh` hard-fails without
   `AGENT_NAME`/`AGENT_EMAIL` set (confirmed at
   `dispatch_phase.sh:228-231`), so the host must source
   `set_git_identity_env.sh` at the head of every command chain that
   calls it — shell state does not persist between tool calls.

2. **`.claude/skills/run-issue/SKILL.md` step 4 (`BEFORE` count)** — the
   `--type "<entry-type>"` passed to `progress_read.py` (SKILL.md:132)
   must be the exact string `dispatch_phase.sh`'s handoff printed on the
   `entry_type=` line (e.g. `Local Review (Pre-Push)`, not `Local
   Review`) — confirmed the table has both as distinct types
   (`dispatch_phase.sh` test fixtures at lines 373/376 show branch-mode
   vs. PR-mode `review-code` produce different `entry_type=` values).
   Add one clause to the `$BEFORE` code block's surrounding text making
   this explicit.

3. **`.claude/skills/run-issue/SKILL.md` step 9 (waiting for reviews)** —
   add that the wait must also cover the
   `copilot-pull-request-reviewer` check-run completing (or being
   absent), not just CI, before dispatching `triage-reviews` — and note
   that a quota-exhausted Copilot posts a comment-only "review" that is
   not a source for `triage-reviews`. `fetch_pr_reviews.sh` already
   surfaces check-run state; this is a text clarification of what "no
   checks pending" must include, not a script change.

4. **Two handoff-block additions, done together** (`**When**` convention
   and scratch hygiene), following the issue's item-4 grouping:
   - **`dispatch_phase.sh` `cmd_handoff`** (dispatch_phase.sh:233-242):
     add one new printed line, `conventions=`, alongside the existing
     `exit_contract=` line, stating: "`**When**` fields are local time
     with offset (e.g. `2026-09-21 14:40 -04:00`); write scratch files
     to the session scratchpad, never `/tmp` directly, and remove what
     you create." This makes the convention mechanically visible to
     every dispatched phase (ADR-0014: handoff-contract content belongs
     in the printed block, not only in skill prose), not just to `git
     Code` sessions that happen to read this workspace's CLAUDE.md.
   - **`.claude/skills/run-issue/SKILL.md`** — reference the new
     `conventions=` line in step 4 (where the handoff block's other
     printed fields are already listed) so the host knows to relay it
     when pasting the handoff into the sub-agent.

5. **`.claude/skills/run-issue/SKILL.md` step 6 (checkpoints are
   entries) — new host step for deferred suggestions.** Per the owner's
   Checkpoint decision: when the owner's `AskUserQuestion` answer defers
   open suggestion-only findings (a `publish`/`merge`-style decision
   over a `checkpoint:findings` state that leaves suggestions
   intentionally unaddressed), the host must, before the next
   `dispatch_phase.sh next` call, run
   `review_progress.sh check --progress <file> --index <i> --deferred
   "<reason>"` (review_progress.sh:83,444-486) for each such box, citing
   the `**Decided-by**: owner` checkpoint entry's own text as the
   reason. This flips the box to `[x]` with a `(deferred: <reason>)`
   annotation, which `open_findings()` already excludes — no new marker,
   no dispatcher change. Add this as a sub-step under step 6, immediately
   after the `## Checkpoint` entry template, so it stays adjacent to
   the write-before-next-call contract it depends on.

6. **`.claude/skills/plan-task/SKILL.md` — test-file exec bit.** Add a
   line to the plan-generation guidance (near "Concrete, not generic" in
   the Guidelines section, or as a note in step 5's plan template
   instructions) that new `test_*.sh` files need `chmod +x` or the
   `check-shebang-scripts-are-executable` pre-commit hook fails the
   commit — so a plan calling for a new test script includes the exec
   bit as an explicit step, not an implicit assumption.

7. **`.agent/scripts/tests/test_dispatch_phase.sh` — one assertion, not a
   new fixture row.** Item 6's routing logic is unchanged (confirmed:
   `open_findings()` doesn't inspect annotation text, only `checked`),
   so no new decision-table row fixture is needed — the plan explicitly
   declines that part of the issue's "Fixture in `test_dispatch_phase.sh`
   either way" framing, per the Checkpoint's resolution. What *does*
   change is `cmd_handoff`'s printed output (item 4's new
   `conventions=` line), which the existing `run_handoff` test block
   (test_dispatch_phase.sh:356-395) already exercises with substring
   assertions — add one `[[ "$out" == *"conventions="* ]]` check
   (extending the existing `review-issue` handoff assertion at line
   362-365, which already checks for `exit_contract`/`Never push`) so
   the new line is covered, without adding a new sandbox fixture.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/run-issue/SKILL.md` | Step 1: source-identity note. Step 4: exact `entry_type=` string + `conventions=` line reference. Step 9: Copilot check-run wait. Step 6: new deferred-suggestion host sub-step. |
| `.agent/scripts/dispatch_phase.sh` | `cmd_handoff`: print a new `conventions=` line (When format + scratch hygiene) alongside `exit_contract=`. |
| `.claude/skills/plan-task/SKILL.md` | Add test-file exec-bit guidance. |
| `.agent/scripts/tests/test_dispatch_phase.sh` | Extend the existing handoff assertion to cover the new `conventions=` line. |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Item 4/5's convention text moves from "only in SKILL.md prose" to "printed by the script every dispatch sees" — enforcement-leaning, matching ADR-0014. Item 6 (deferred boxes) stays a host-followed step because it depends on the owner's checkpoint answer, which no script can infer; documenting it as an explicit sub-step (not silently expecting it) is the appropriate level given no reader/writer change is needed. |
| A change includes its consequences | Confirmed no consequence to `review_progress.sh` or `review_loop_lifecycle.md` is needed for item 6, per the reuse decision — verified `open_findings()`'s only test is `checked`, independent of annotation text. |
| Only what's needed | Declined the `[~]` marker alternative and its wider blast radius (review_progress.sh, lifecycle doc) per the Checkpoint's explicit "no new marker" decision. |
| Test what breaks | Items 1, 2, 3, 5, 6 are text-only (matches existing skill-doc convention: untested, same as items 1-5/7 in the Issue Review's assessment). Item 4's handoff line is a script output change and gets the one added assertion. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0014 — In-process phase handoff | Yes | The new `conventions=` line is exactly the kind of handoff-contract content ADR-0014 requires `dispatch_phase.sh` to print, not leave only in skill prose. |
| 0013 — `progress.md` entry-type vocabulary | No | Reuse decision means no new checkbox state, no `progress_read.py`/`review_progress.sh` changes — confirmed not triggered, matching the Issue Review's conditional note. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `dispatch_phase.sh` `cmd_handoff` output | `test_dispatch_phase.sh` handoff assertions | Yes — item 7 |
| `run-issue/SKILL.md` step 6 (new host sub-step) | `review_progress.sh`, `review_loop_lifecycle.md` | No — explicitly declined per Checkpoint decision; no reader/writer change needed |
| `plan-task/SKILL.md` guidance | none (doc-only, informs future plans) | N/A |

## Open Questions

None — the owner's Checkpoint already resolved the one open decision
(item 6's mechanism).

## Estimated Scope

Single PR. This issue's own drive through `/run-issue` is the acceptance
test, plus `.agent/scripts/tests/run_script_tests.sh` green (covers the
extended `test_dispatch_phase.sh` assertion).
