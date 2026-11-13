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
   or `findings`) arms; the armed state is disarmed by a `## Merge (...)` record
   or by a later checkpoint with After `merge`, `findings` or `merge-refused` and
   a non-merge answer; the first start entry while armed (`## Plan Authored`, or
   an `## Implementation` with `**Branch**` and no `**Addressed**`) is the
   boundary; a restart checkpoint sets the start and clears the armed state.
   PR-correlated entries do not disarm. It relies on ADR-0013's correlation
   table (`**Branch**` only "if no PR exists yet"). Both inline `-c` scripts
   get the script directory through the environment and a plain
   `from pr_start import pr_start` (so `suites_for_files.sh` maps it);
   `restart_start()` and the `cmd_round` loop go; `round_count()` and
   `skill_for()` use the result. Tests: `pr_start` directly; `next` and `round`
   on synthetic timelines for a refused merge, a merge-from-main
   `Implementation` while armed (no false boundary), restart plus merge, a hand
   merge with no merge checkpoint (no boundary: the known limitation), and
   fixtures modelled on 429 at 461's head (four pull requests) and the real
   332 shape; a handoff test that part 2's first pre-push review task line has
   no "no cross-model reviewers".
2. **Post-merge route** — a `next` row: newest entry is a merge-decision
   checkpoint and `--pr none` answers `checkpoint:plan` (`proceed` goes to
   `implement`, `revise` to `plan-task`, both in the table). A refused or failed
   merge leaves its PR open (`--pr open`), so `merge` and `merge-refused` are
   unchanged. Tests for each.
3. **`findings` and `check` read a post-publish `## Local Review`** (own commit,
   the two stay in step), with one shared predicate for the "No issues found.
   LGTM." placeholder of an approved review in `pr_start.py`,
   used by `findings` and `sources`; tests.
4. **Stale boxes** — `cmd_sources` reads the whole timeline and slices from
   `pr_start`; one slice, droppable if review finds it needs more. Test.
5. **Docs and run-issue** — step 2 gains a general step before the PR probe: if
   the issue is closed, the run ends (`done`), so a finished one-PR issue never
   resumes into a plan. What closes it: a last pull request with `Closes #N`
   merged to the default branch; a pull request whose base is not the default
   branch never closes it, so the host tells the owner at the merge hand-back
   and the owner closes it; an issue delivered in parts is closed by the last
   part's `Closes #N` (earlier ones say `Part of #N`). The loop never closes an
   issue itself. A new multi-pull-request section: `Part of #N`, worktree and
   branch recreated after each merge, the hand-merge remedy (the host records the
   owner's merge as a `merge` checkpoint, `Decided-by: owner`, before the next
   part, or a `restart`). Also `docs/design.md`, `review_loop_lifecycle.md`,
   `script_reference.md`, script headers.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/pr_start.py` | New: boundary and placeholder predicate (imported, no exec bit) |
| `.agent/scripts/dispatch_phase.sh`, `review_progress.sh` | Use it; new row; `findings`, `check`, `sources`; headers |
| `.agent/scripts/tests/test_dispatch_phase.sh`, `test_review_code_convergence.sh`, `test_address_findings.sh` | Cases above |
| `.claude/skills/run-issue/SKILL.md`, `docs/design.md`, `.agent/knowledge/review_loop_lifecycle.md`, `.agent/knowledge/script_reference.md` | Docs |

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
per issue, and a merge on an open issue now has a defined next step. Today the
design assumes one pull request per issue.

**Rule 1, where a pull request ends.** After you answer `merge`, the next piece of
new work (a new plan, or the first implementation on a fresh branch) starts the
next pull request; reviews before that point stop counting toward the three-round
limit. A merge that was refused or failed does not count: fix and re-merge
entries do not start a new one. Limitation: a merge done by hand with no merge
answer recorded leaves no boundary; the host then records your merge as a
`merge` answer (or a `restart`) before the next part.
Rejected: "the merge answer is not the newest entry" (a refusal adds entries
after it); the pull request number changing (it only changes after the next
publish, too late); asking GitHub (the router stays offline); a new "merged"
entry (needs a new entry type and a step a crash can skip).

**Rule 2, after a merge with the issue still open.** The router cannot know a part
remains, so before anything else the run ends if the issue is closed (a last pull
request saying `Closes #N`, merged to the default branch). If it is open and
no pull request exists, the router asks the plan checkpoint: `proceed` goes to
implement when the plan already covers the next part, `revise` plans it.
Where nothing closes the issue (a pull request into a non-default base), the host
tells you at the merge and you close it; the loop never closes an issue itself.

**How hard to undo:** easy; one helper, one row and docs, no entry format
change; old timelines read the same.

**Recommendation:** adopt both rules.

**"Not now":** the host keeps routing the step after each merge by hand and
records `restart` or `Decided-by: host` answers past the inflated round counts,
as on issue 429.
