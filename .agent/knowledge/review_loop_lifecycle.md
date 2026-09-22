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
in the loop advances a phase on its own judgment (no auto-chaining).

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
| `merge_pr.sh`'s gate, when a precondition is unmet — except `--enforce` on a workspace PR, which refuses with no entry | `## Merge (report-only)` / `## Merge (unreviewed)` | `merge_pr.sh` |

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

`.agent/scripts/dispatch_phase.sh next --issue <N> --pr <state>` reads only
the newest `progress.md` entry (plus `--pr`, the one non-timeline input)
and prints an `action=` token. The routing key is the entry's `base_type`
and its fields — never adjacency to the entry before it. Two routing rules
worth remembering because they read as exceptions:

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
