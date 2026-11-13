# Plan: dispatch_phase: multi-PR issue routing

## Issue

https://github.com/rolker/agent_workspace/issues/459

## Context

An issue delivered in several pull requests leaves one timeline. Two things go
wrong (real evidence: issue 429's `progress.md`, first pre-push reviews of
parts 2 to 4 counted as round 4, 7, 10, 13; `next` answers `merge` after each
merge). Root cause: the timeline has no "a pull request ended here" mark.
Today only `**Decision**: restart` resets the count, in two copies
(`restart_start()` in `dispatch_phase.sh`, inline Python in `review_progress.sh
cmd_round`).

Facts checked in source: the host writes the `## Checkpoint` (`After`
`merge` or `findings`, `Decision: merge`) BEFORE `merge_pr.sh` runs, and it is
committed in the PR, so it is on the base branch after a merge. A refused merge
leaves it followed by `## Merge (report-only|unreviewed)`, a `merge-refused`
checkpoint, `Integrated Review`, or a PR-correlated `Implementation` with
`**Addressed**`. A merge that lands writes nothing. After a landed merge the new
work starts with `## Plan Authored`, or (plan already covers it) a
`**Branch**`-correlated `## Implementation`.

## The design question for the owner

### (i) How the timeline shows "a pull request ended here"

**Proposal: a `Decision: merge` checkpoint, then the first entry that starts
new work after it.** Start entries are `## Plan Authored`, or an
`## Implementation` with a `**Branch**` correlation and no `**Addressed**`.
That entry is the first entry of the next pull request; everything before it
belongs to earlier pull requests. One pass over the entries, shared:

    start = 0; armed = False
    for i, e in entries:
        restart checkpoint            -> start = i+1; armed = False
        merge-decision checkpoint     -> armed = True
        armed and is_start_entry(e)   -> start = i; armed = False

A refused or failed merge is never a boundary: nothing after it is a start
entry (the fix path writes PR-correlated, `Addressed` Implementations, and the
refusal path writes Merge records and checkpoints), so `armed` stays set until a
real next part begins. Restart and merge compose by position. No new entry
type (ADR-0013), no `gh` call, no host step to forget.

Alternatives rejected:
- *Merge checkpoint that is not the newest entry*: a refused merge is followed
  by Merge records and checkpoints, so it would read a refusal as a boundary.
- *`**PR**` number change between correlated entries*: pre-push reviews and
  Implementations carry `**Branch**`, not a PR; the number changes only after
  the next publish, too late for the pre-push round count that is the bug.
- *Asking GitHub*: `next` is `gh`-free by design and round counting runs
  offline; GitHub is used only host-side, in (ii).
- *Host-written "merged" checkpoint after the merge*: needs a new `After` value
  (vocabulary change), runs in a worktree the merge just removed, and is a
  step a crash between merge and write silently skips.

### (ii) What `next` answers after a merge when the issue stays open

The timeline alone cannot say "a part remains" or "the plan covers it": the plan
is prose in `plan.md`, not on the timeline. Smallest honest mechanism: the host
asks GitHub whether issue N is still open after the merge (that is what
`Part of #N` versus `Closes #N` encodes; closed means the last part, run ends).

In `next`, a new row before the `merge` rows: newest entry is a merge-decision
checkpoint and `--pr none` answers `plan-task` (reason: a pull request ended
here, plan the remaining part). Nothing is left to merge when no PR exists, and a
refused or failed merge leaves its PR open (`--pr open`), so it still answers
`merge`/`merge-refused` as today. The shortcut needs no code: when the host reads
`plan.md` and the plan covers the next part, it writes the existing
`## Checkpoint` `After: plan`, `Decision: proceed` (`Decided-by: host (...)`),
and the existing row answers `implement`. If the host cannot tell, it asks the
owner. Rejected: `next` guessing `implement` (a wrong guess builds against a
stale plan); a parts table in `progress.md` (new vocabulary); always a
checkpoint (stops the owner after every merge for a question the host can
answer).

Run-issue's PR probe lists `--state all`: a recreated branch with the same name
finds the old MERGED pull request and `next` short-circuits to `done` (row 1).
The multi-pull-request section says a MERGED pull request counts only when its
`headRefOid` equals the local HEAD, so a recreated branch probes as `none`.

**For the owner.** Edits `docs/design.md#review-loop-and-timeline`: the "next
step is routed on the newest entry" bullet (round count and failed-Implementation
skill count from the newest pull request boundary, merge-then-no-PR row), the
`review-code` and `merge` table rows ("one pull request" wording). Undo: easy;
revert the helper, one row and docs, no entry or file format changes, old
timelines read the same. Recommendation: adopt both as proposed. "Not now"
leaves the workaround in place: the host answers each post-merge step by hand
and writes a `restart` checkpoint (which also hides that pull request's
history from `skill_for`) or `Decided-by: host` address/publish checkpoints past
inflated round counts, as 429 did.

## Approach

Atomic commits, in order:

1. **Shared boundary** — new `.agent/scripts/pr_start.py` (`pr_start(entries)`,
   the pseudocode above, the one definition). `dispatch_phase.sh` inline Python
   and `review_progress.sh cmd_round` import it (`sys.path` from `SCRIPT_DIR`),
   replacing `restart_start()` and the inline loop; `round_count()` and
   `skill_for()` use the result. Header comments say "one definition in
   `pr_start.py`". Tests (`test_dispatch_phase.sh`, `test_review_code_convergence.sh`,
   which holds the `round` cases): refused-merge timeline (merge checkpoint, Merge
   record, merge-refused checkpoint, address Implementation: count unchanged);
   landed merge then Plan Authored (round 1); landed merge then Branch
   Implementation (shortcut); restart plus merge; the 429 sequence (four pull
   requests, first review of each part is round 1 for `next` and `round`); and the
   failed-first-Implementation of part 2 maps to `implement`. Each fails without the
   change.
2. **Post-merge route** — the `next` row and header-table text; tests: merge
   checkpoint newest with `--pr none` is `plan-task`; with `--pr open` still `merge`;
   `After: findings` too; plan/proceed after it is `implement`.
3. **`findings` reads post-publish `## Local Review`** — `cmd_findings` and
   `cmd_check` take `Local Review` as a source (the two stay in step); test: a
   `## Local Review` newer than the `Integrated Review` is the source. Own commit.
4. **Stale boxes (conditional)** — `cmd_sources` reads the whole timeline and
   slices from `pr_start`, so entries of merged pull requests stop appearing as
   `dropped_entries` "stale". It falls out of the same helper with one slice; if
   review finds it needs more, drop this commit. Test with a merged part's
   open box.
5. **Docs** — run-issue `SKILL.md`: a "Multi-pull-request issues" section
   (`Part of #N` in each body but the last, which says `Closes #N`; after each
   merge check the issue is open, recreate worktree and branch from the base, the
   merged-PR probe rule, the plan/proceed shortcut) and step 2's probe note;
   `docs/design.md` as above; `review_loop_lifecycle.md` lines 55-60;
   `script_reference.md` (`pr_start.py`); header comments.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/pr_start.py` | New (imported only, no exec bit) |
| `.agent/scripts/dispatch_phase.sh` | Import helper in `cmd_next` Python; new row; header text (lines ~86-93, ~107-120) |
| `.agent/scripts/review_progress.sh` | `cmd_round`, `cmd_findings`, `cmd_check`, `cmd_sources`; header |
| `.agent/scripts/tests/test_dispatch_phase.sh`, `test_review_code_convergence.sh`, `test_address_findings.sh` | Cases above |
| `.claude/skills/run-issue/SKILL.md`, `docs/design.md`, `.agent/knowledge/review_loop_lifecycle.md`, `.agent/knowledge/script_reference.md` | Docs |

## Sequencing with pull request 461 (open)

Planned against main plus 461. 461 changes `dispatch_phase.sh` only at
`cmd_handoff` ~line 529 (pre-push task line) and `base`; this change edits
`cmd_next`, which is outside it, and the `round` call there is untouched.
Expected merges: `run-issue/SKILL.md` (461 hunks near lines 80, 234, 478, 757-790,
853, 882, 953-977; mine: step 2 probe note ~310 and a new section, placed at a
heading boundary), `docs/design.md` (461 hunks at 381, 473-512, 549-558,
596-605, 678-690; mine: the bullet at ~605-609 sits next to the 596-605 hunk,
and the table rows at ~589), `script_reference.md` (461 at lines 31-48; mine is
one row elsewhere). Not touched by 461: `review_progress.sh`, its tests,
`test_dispatch_phase.sh`. Rebase after 461 merges, before implementing.

## Prior Art

The existing restart rule (`restart_start()`, `cmd_round`) is extended, not
replaced; nothing external was needed.

## Serves

Keep work moving without the owner (the review loop driven by `/run-issue`) —
`docs/design.md#review-loop-and-timeline`

## Design Picture

Changes it: round counting per pull request and the route after a merge, in
`docs/design.md#review-loop-and-timeline` (same change, ADR-0017).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | One shared boundary definition; design text updated in the same change |
| Enforce what matters, as simply as possible | One pass, no new entry type, no new host step except one `gh issue view` |
| Test what breaks | Refused-merge, restart-plus-merge and a 429-modelled timeline for both scripts |
| A change includes its consequences | Docs, lifecycle note, script reference, headers listed above |
| Small steps | Five commits; 3 and 4 are separable |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0013 | Yes | No new entry type or `After` value; uses `Checkpoint`, `Plan Authored`, `Implementation` |
| 0014 | Yes | Handoff contract unchanged; exit checks stay mechanical |
| 0017 | Yes | `docs/design.md` edited in the same change |
| 0004/0005 | No | `merge_pr.sh` and its head-vs-review gate untouched |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Round rule | Both scripts, `review_loop_lifecycle.md`, design bullet | Yes |
| Post-merge row | run-issue table text, design | Yes |
| `findings` source | `check` (same selection) | Yes |

## Open Questions

- Owner: adopt (i) and (ii) as proposed (see "For the owner").
- Does `findings` listing an unchecked `LGTM` placeholder box of an approved
  `Local Review` need filtering? Pre-Push has the same placeholder; check in
  commit 3 and mirror whatever it does.
- The `headRefOid == HEAD` probe rule is untested against `gh`; verify the field
  name when writing the section.

## Estimated Scope

Single pull request, five commits; commits 3 and 4 can be split off.
