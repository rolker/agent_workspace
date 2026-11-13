# Plan: dispatch_phase: multi-PR issue routing

## Issue

https://github.com/rolker/agent_workspace/issues/459

## Context

An issue delivered in several pull requests has one timeline and no mark of
where a pull request ended. Evidence, issue 429's `progress.md`: first pre-push
reviews of parts 2 to 4 counted as round 4, 7, 10, 13, and `next` answers
`merge` after each merge. Only `Decision: restart` resets the count today, in two
copies (`restart_start()` in `dispatch_phase.sh`, inline Python in
`review_progress.sh cmd_round`). The host writes the `Decision: merge` checkpoint
before `merge_pr.sh`, so it also precedes a refused merge; a landed merge writes
nothing.

## Approach

Atomic commits, after rebasing on 461 once it merges:

1. **One boundary definition** — new `.agent/scripts/pr_start.py`,
   `pr_start(entries)`, one pass: a `Decision: merge` checkpoint (After `merge`
   or `findings`) arms; a later checkpoint with After `merge`, `findings` or
   `merge-refused` and a non-merge answer disarms; the first start entry while
   armed (`## Plan Authored`, or an `## Implementation` with no `**Addressed**`
   that is `**Branch**`-correlated, or carries a `**PR**` number other than the
   merged pull request's (the newest PR-correlated entry's before the merge
   answer; unknown → not a start), or has no correlation line and is not
   complete; first fix round) is the boundary; a restart checkpoint sets the
   round start (not the pull-request start `sources` reads; first fix round) and
   clears the armed state. A `## Merge (...)` record neither arms nor disarms
   (`merge_pr.sh` writes it at the gate, before the merge, whether or not it
   lands). Entries that are not start entries do not disarm. It relies on ADR-0013's
   correlation table (`**Branch**` only "if no PR exists yet"). Both inline `-c`
   scripts get the script directory through the environment and a plain
   `from pr_start import pr_start` (so `suites_for_files.sh` maps it);
   `restart_start()` and the `cmd_round` loop go; `round_count()` and
   `skill_for()` use it. Tests: see "Tests".
2. **Post-merge route** — a `next` row 3a, checked after rows 2 and 3 and
   before the base-type rows: it fires only when the timeline is armed at its
   end, `--pr none`, AND the newest entry is a checkpoint with `Decision:
   merge` (any `After`, which covers a `merge-refused` checkpoint answered
   `merge`) or a `## Merge (...)` record; it answers `checkpoint:plan`
   (`proceed` to `implement`, `revise` to `plan-task`). Without the newest-entry
   guard it would shadow the plan proceed/revise rows and the phase-failed
   retry/takeover rows (the timeline stays armed until the first start entry)
   and repeat `checkpoint:plan` forever. Row 23 (newest Merge record, `--pr
   open`) is unchanged: with the pull request still open it keeps answering
   `checkpoint:merge-refused`. `--pr none` with a Merge record and no armed
   state (a disarmed refusal) also stays row 23. `merge` and `merge-refused`
   answers are unchanged. Tests: each row of the decision table keeps its
   answer (the existing fixtures), the seven-state walk, both Merge-record
   cases, and both looping sequences (merge, `checkpoint:plan`, `revise` →
   `plan-task`; `revise`, plan-task writes nothing, phase-failed `retry` → the
   retry).
3. **`findings` and `check` read a post-publish `## Local Review`** (own commit,
   the two stay in step), with one shared predicate for the "No issues found.
   LGTM." placeholder of an approved review in `pr_start.py`, used by `findings`
   and `sources`; tests.
4. **Stale boxes** — `cmd_sources` reads the whole timeline and slices from
   `pr_start`; one slice, droppable if review finds it needs more. Test.
5. **Docs and run-issue** (`SKILL.md` step 2 text; `dispatch_phase.sh` row 1 is
   unchanged and is reached only by an explicit `--pr merged`):
   - A general step before the PR probe: ask the issue's state (`gh issue view
     <N>`; for `owner/repo#N`, `-R owner/repo`). Closed ends the run (`done`). A
     `gh` failure or offline stops the run with the error, never read as open or
     closed.
   - What closes an issue: a last pull request with `Closes #N` merged to the
     default branch; a pull request into a non-default base never does, so the
     host tells the owner at the merge hand-back and the owner closes it; an issue
     delivered in parts is closed by the last part (earlier ones say `Part of
     #N`). The loop never closes an issue itself.
   - Probe on an open issue: a merged pull request is an earlier part. Take an
     open or draft pull request on the branch if there is one, otherwise `none`.
     If the old worktree survived the merge (local HEAD equals a merged pull
     request's `headRefOid`), stop and say so; do not route. Tested by a
     skill-text check where one exists and by the `next` tests; the probe is host
     prose, not script code.
   - The post-merge `checkpoint:plan` dialog shows the pull request just merged,
     that the issue is still open and why it can be (a non-default base, or a
     `Part of` body by mistake: then answer `stop` and close), the parts delivered,
     and the newest Plan Review's plan commit against the current one. `proceed` is
     offered only when `plan.md` is unchanged since that review
     (`review_progress.sh plan-sha`) and the plan names a part not yet delivered;
     otherwise answer `revise`.
   - A multi-pull-request section: `Part of #N`, worktree and branch recreated
     after each merge, the hand-merge remedy (the host records the owner's merge
     as a `merge` checkpoint, `Decided-by: owner`, before the next part, or a
     `restart`).
   - `docs/design.md`, `review_loop_lifecycle.md`, `script_reference.md`, script
     headers.

## Tests

`pr_start` directly, then `next` and `round` on synthetic timelines, plus a handoff
test that part 2's first pre-push `review-code` task line has no "no cross-model
reviewers". Expected results, from a throwaway replay of the final rule over real
timelines (0-based entry index) and synthetic sequences:

| Timeline | Boundary (start) | Armed at end |
|---|---|---|
| 429 on main (three pull requests; the fourth fixture is 461's head) | 25, 50 | yes |
| 332 (four pull requests, one hand-merged) | 67, 81 (the part after PR 403 has none) | yes |
| 451, 455, 354, 307 (single pull request) | none | yes |
| merge, stop, merge, Plan Authored | the Plan Authored | no |
| merge, Merge record, landed, Plan Authored (was wrong) | the Plan Authored | no |
| merge, record, merge-refused/retriage, review, merge, Plan Authored | the Plan Authored | no |
| merge, record, merge-refused/address, Branch fix | none | no |
| merge, refusal, `address` checkpoint, Branch Implementation (merge-from-main) | none | no |
| merge, Branch Implementation, no checkpoint between (the other order) | the Implementation | no |
| merge, PR-correlated fix, merge, Plan Authored | the Plan Authored | no |
| merge, restart, Plan Authored, merge, Plan Authored | the last Plan Authored | no |
| hand merge: review, Branch Implementation, no merge checkpoint | none (known limitation) | no |
| merge, record, merge-refused answered `merge`, Plan Authored (issue-307 shape plus a part) | the Plan Authored | no |
| merge, plan `proceed`, FAILED Branch Implementation (a start entry counts whatever its Status) | the Implementation; its retry dispatches `implement` | no |

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/pr_start.py` | New: boundary and placeholder predicate (imported, no exec bit) |
| `.agent/scripts/dispatch_phase.sh`, `review_progress.sh` | Use it; new row; `findings`, `check`, `sources`; headers |
| `.agent/scripts/tests/test_dispatch_phase.sh`, `test_review_code_convergence.sh`, `test_address_findings.sh` | Cases above |
| `.claude/skills/run-issue/SKILL.md`, `docs/design.md`, `.agent/knowledge/review_loop_lifecycle.md`, `.agent/knowledge/script_reference.md` | Docs |
| `.agent/scripts/tests/test_triage_reviews_integration.sh`, `test_skill_paths.sh` | Added in implementation: `sources` cases (the merged part's boxes, a restart keeps the open pull request's reviews), the run-issue prose pins and the issue-state block against a stub `gh` |
| `.claude/skills/address-findings/SKILL.md` | Added in implementation: names the post-publish `## Local Review` as a source and the LGTM placeholder |
| `.claude/skills/review-code/SKILL.md`, `.agent/knowledge/review_depth_classification.md` | Added in the first fix round: the round count starts at the current pull request's start (newer of a restart and the boundary) |

Merge with 461 (planned against main plus 461): it edits `cmd_handoff` ~line 529
and `base` (not `cmd_next`), `run-issue/SKILL.md`, `docs/design.md` (the
"next step" bullet near its 596-605 hunk), `script_reference.md`, and appends to
429's `progress.md`; not `review_progress.sh` or `test_dispatch_phase.sh`.

## Prior Art

Extends the existing restart rule. Real timelines replayed for the rule: 429 (to
461's head), 332, 354, 455, 451.

## Serves

Keep work moving without the owner (the review loop driven by `/run-issue`) —
`docs/design.md#review-loop-and-timeline`

## Design Picture

Changes it: round counting per pull request and the route after a merge
(`docs/design.md#review-loop-and-timeline`, same change, ADR-0017).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforce what matters, as simply as possible | One shared rule, no new entry type |
| Test what breaks | Refused merge, false boundary, hand merge, restart plus merge, real 429 and 332 shapes |
| A change includes its consequences | Docs, headers, close path |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0013 | Yes | No new type or field; relies on its `**Branch**` rule |
| 0014 | Yes | Handoff contract unchanged |
| 0017 | Yes | Design edited in the same change |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Round rule | Both scripts, lifecycle note, design | Yes |
| Post-merge row | run-issue, design | Yes |
| `findings` source | `check` | Yes |

## Open Questions

- The owner's question below.

## Estimated Scope

Single pull request, five commits; 3 and 4 can be split off.

## Owner's question: how multi-pull-request issues are routed

**What changes in the design** (`docs/design.md#review-loop-and-timeline`): the
"next step is routed on the newest entry" bullet and the table rows for
`review-code` and `merge`. Review rounds are counted per pull request instead of
per issue, and a merge on an open issue gets a defined next step. Today the
design assumes one pull request per issue.

**Rule 1, where a pull request ends.** After you answer `merge`, the next new
work (a new plan, or the first implementation on a fresh branch) starts the next
pull request; earlier reviews stop counting toward the three-round limit. A
refused or failed merge does not count, and the merge gate's own record does
nothing either way. Limitation: a merge done by hand with no `merge` answer
recorded leaves no boundary; the host then records it (or a `restart`) before the
next part. Rejected in a line: "the merge answer is not the newest entry",
a pull request number change, asking GitHub, or a new "merged" entry each fail on
refusals, timing, offline use or a new entry type.

**Rule 2, after a merge.** A merged pull request on an open issue is treated as an
earlier part, not as the end. The run first asks GitHub whether the issue is
closed and ends if so; if it cannot read the state it stops, never guessing. If
the issue is open and the old worktree survived the merge (still at the merged
pull request's head), the run stops and says so instead of routing. If the
issue is open and no pull request is open, the plan checkpoint is asked:
`revise` plans the next part; `proceed` goes straight to implementing and is
offered only when the plan is unchanged since its last review and names a part
not yet delivered. The dialog shows the pull request just merged, why the issue
is still open, the parts delivered, and the reviewed plan's commit against the
current one. Where nothing closes the issue (a pull request into a non-default
base), the host tells you at the merge and you close it; the loop never closes
an issue itself.

**How hard to undo:** easy; one helper, one row, a run-issue step and docs; no
entry format changes. Single-pull-request timelines read the same; timelines of
issues with several pull requests count fewer rounds, which is the point.

**Recommendation:** adopt both rules.

**"Not now":** the host keeps routing the step after each merge by hand and
records `restart` or `Decided-by: host` answers past the inflated round counts,
as on issue 429.
