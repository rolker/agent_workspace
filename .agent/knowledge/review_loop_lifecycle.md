# Review Loop Lifecycle

One page for "what happens to an issue, in what order, and who writes what"
— read this instead of six `SKILL.md` files. See ADR-0013 for the entry
vocabulary, ADR-0014 for the handoff contract, and
`.claude/skills/run-issue/SKILL.md` for the orchestrator that drives this
by script rather than by hand.

## Phase order

```
review-issue → plan-task → review-plan → implement
   → review-code --branch      (pre-push; loop with address-findings)
   → publish (push + PR)
   → review-code <PR>          (post-push; loop with address-findings)
   → triage-reviews → merge
```

Each arrow is a human or `/run-issue` deciding to move forward — nothing
in the loop advances a phase on its own judgment (no auto-chaining). A
host running `/orchestrator` may answer a checkpoint itself, only with the
answers that skill's table allows it (never `merge`, `merge-refused`, or
`takeover`), and records it `**Decided-by**: host (<reason>)`.

## Who writes what

| Phase | Entry type (ADR-0013) | Written by |
|---|---|---|
| `review-issue` | `## Issue Review` | `review-issue` step 8 |
| `plan-task` | `## Plan Authored` | `plan-task` |
| `review-plan` | `## Plan Review` | `review-plan` |
| `implement` (the post-plan pass) | `## Implementation` | the dispatched implement pass (no `**Addressed**` field) |
| `address-findings` (every later fix round) | `## Implementation` | `address-findings` (`**Addressed**` names the review it answers) |
| `review-code --branch` | `## Local Review (Pre-Push)` | `review-code`, branch mode |
| `review-code <PR>` | `## Local Review` | `review-code`, PR mode |
| `triage-reviews` | `## Integrated Review` | `triage-reviews` |
| a human's answer to an `AskUserQuestion` checkpoint | `## Checkpoint` | `/run-issue`, on the owner's behalf (`**Decided-by**: owner`) |
| the host's own answer to a checkpoint, within `/orchestrator`'s table | `## Checkpoint` | `/run-issue` (`**Decided-by**: host (<reason>)`) |
| `merge_pr.sh`'s gate under `--report-only` (or `--force-unreviewed`), when a precondition is unmet — the default (enforce, #300) on a workspace PR refuses with no entry | `## Merge (report-only)` / `## Merge (unreviewed)` | `merge_pr.sh` |

Both `## Implementation` writers are dispatched sub-agents (issue #314);
one case still runs inline, and only one — a `checkpoint:phase-failed`
answered `takeover`, where the host finishes *any* failed phase itself and
writes that phase's own entry. A taken-over implement pass adds
`**Mode**: inline` as a record of who wrote it; nothing reads the field.

Every entry lives on `.agent/work-plans/issue-<N>/progress.md`, appended
via `.agent/scripts/progress_append.sh` and read back via
`.agent/scripts/progress_read.py`. This is the only place loop state lives
— not the conversation, not a separate lock file.

## What `run-issue` reads to move on

`.agent/scripts/dispatch_phase.sh next --issue <N> --pr <state>` routes on
the newest `progress.md` entry (plus `--pr`, the one non-timeline input)
and prints an `action=` token. It reads earlier entries for three things
only, all through `.agent/scripts/pr_start.py` (issue 459):
`round_count()` counts the completed `## Local Review (Pre-Push)`
entries on the branch from the start of the current pull request's work,
`skill_for()` looks for an earlier complete `## Implementation` from that
same start to tell a failed address-findings pass from a failed implement
pass, and row 3a asks whether a `merge` answer stands with no new work
after it. The rounds start after the newest `**Decision**: restart`
checkpoint (a restart begins the new work at round 1), or, for an issue
delivered in several pull requests, at the pull-request boundary, whichever
is newer. The boundary is the first start entry after a `merge` answer: a
`## Plan Authored`, or an `**Addressed**`-less `## Implementation` that is
`**Branch**`-correlated, carries a `**PR**` number other than the merged
pull request's, or has no correlation line and is not complete (the next
part's first review is round 1; `pr_start.py`'s docstring has the cases
that are not starts). A non-`merge` answer at `merge`, `findings` or
`merge-refused` withdraws the `merge` answer; a `## Merge (...)` record
changes nothing; a merge by hand with no `merge` answer leaves no boundary
until the host records one (`run-issue` step 13). `review_progress.sh
round` reads the same round start; `sources` cuts at the boundary only, so
a restart keeps the open pull request's earlier reviews. The
routing key is the entry's `base_type` and its fields — never adjacency to
the entry before it. Three routing rules worth remembering because they
read as exceptions:

- **After a merge, with no pull request open, the `plan` checkpoint**
  (row 3a): when the timeline still holds a `merge` answer and the newest
  entry is that answer (any `**After**`) or a `## Merge (...)` record,
  `next --pr none` answers `checkpoint:plan` for the issue's next part
  instead of `merge`. `run-issue` reaches it only in a fresh run for an
  open issue (a landed merge ends the run that made it): it asks the
  issue's state first, and probes a merged pull request as an earlier part
  (`--pr none`), never as `--pr merged`.

- **`## Local Review` and `## Local Review (Pre-Push)` route on
  `**Verdict**` alone** (`approved` vs. not), never on open findings —
  `review-code` writes an unchecked "LGTM" placeholder box even on an
  approved review, and open-findings routing would misfire on it.
- **`## Issue Review` and `## Integrated Review` route on open
  checkboxes** — an unchecked `### Actions` / `### Findings` box means the
  loop pauses at a checkpoint (`issue-actions` / `findings`) before moving
  on; none open means proceed straight to the next phase or the `merge`
  checkpoint.

`round` — the pre-push review-loop counter compared against `MAX_ROUNDS`
(3) — counts only `## Local Review (Pre-Push)` entries with
`**Status**: complete` on the current branch; a partial or failed review
that got retried does not inflate the count.

## Exit contract and dispatch

`/run-issue` hands each phase to a fresh sub-agent (ADR-0014): the host
prints the handoff block with `dispatch_phase.sh --issue <N> --skill <phase>`
and pastes it into a new Agent tool call, so no phase inherits another's
context and the phase fetches its own inputs with `gh`. Two exceptions: a
repeat of a phase already run in the same drive may resume that phase's agent
(`run-issue` section 4a), and when the owner chooses takeover at a
`phase-failed` checkpoint (decision-table row 27, `mode=inline`) the host runs
that phase itself in the worktree (`run-issue` section 5). Inside
`review-code`, the external reviewers run through `cross_model_review.sh`,
whose single dispatch mode (parallel and synchronous) is ADR-0015.

After the sub-agent returns, the host does not take its word for it.
`dispatch_phase.sh --check-exit --issue <N> --skill <phase> --before <count>`
(plus `--pr <M>`, which `triage-reviews` requires and which switches
`review-code` to its PR-mode entry type, `## Local Review`; and `--type` /
`--project` for a project worktree) compares the number of entries of the
phase's expected type before and after the dispatch and prints one `status=`
result:

- `OK` (with the worktree's `sha=`): the newest entry of that type is
  `**Status**: complete` and, for an implement / address-findings
  `## Implementation` entry, it carries the `**PR**` / `**Branch**` line.
- `PARTIAL`: its status is `partial`, or it is a complete implement /
  address-findings `## Implementation` entry that lacks the `**PR**` /
  `**Branch**` line `merge_pr.sh`'s review gate needs.
- `FAILED`: its status is `failed`.
- `MISSING`: no new entry of the expected type appeared, or its status is
  not `complete`, `partial` or `failed`.

`--check-exit` can also exit 2 (usage: no worktree for the issue, unknown
`--skill`, missing `--pr` for `triage-reviews`, a non-integer `--before`) or 3
(`progress.md` could not be parsed) with no `status=` line; that is an error
in the check itself, not an `OK`.

Any returned status other than `OK` (`PARTIAL`, `FAILED`, `MISSING`) is a
`phase-failed` checkpoint, never a silent retry: the owner picks retry,
takeover or stop. An exit of 2 or 3 means the check itself failed, so it is
fixed and re-run; it is not a phase outcome and raises no checkpoint.

## Where the human checkpoints are

Nine checkpoint kinds, each an `AskUserQuestion` the host asks before
writing a `## Checkpoint` entry and calling `next` again:

| Checkpoint | Asked when |
|---|---|
| `issue-actions` | `## Issue Review` has open `### Actions` boxes |
| `plan` | after every `## Plan Review`, regardless of verdict |
| `publish` | a pre-push review approved — about to push / open a PR |
| `rounds` | the pre-push loop hit `MAX_ROUNDS` without approval |
| `findings` | `## Integrated Review` has open findings |
| `merge` | `## Integrated Review` has no open findings — about to merge |
| `merge-refused` | a merge attempt did not end merged |
| `phase-failed` | a dispatched or inline phase's entry is partial or failed |
| `unexpected` | no row in the decision table matches the current state |

Each checkpoint's allowed `**Decision**` values are fixed
(`dispatch_phase.sh`'s header comment has the full table); anything outside
that vocabulary routes the *next* call to `checkpoint:unexpected` rather
than being silently accepted.

## Where `/run-issue` sits

`/run-issue <N> [--type workspace|project] [--resume]` is the one script
that walks this whole table without a human re-deriving it by hand each
turn: it enters the worktree, calls `next`, dispatches the named phase
(taking it over inline only after a `phase-failed` checkpoint answered
`takeover`), checks the exit contract, and pauses at every checkpoint.
Codex/Gemini sessions still drive `review-issue` → ... → `triage-reviews`
one skill at a time; the table above is exactly what they're following by
reading `SKILL.md` files instead of a script's output.
