---
name: run-issue
description: "Claude Code only — drives one GitHub issue through the full review loop (review-issue → plan-task → review-plan → implement → review-code → publish → triage-reviews → merge), dispatching each phase to a fresh sub-agent via the Agent tool and pausing at AskUserQuestion checkpoints. Depends on `.agent/scripts/dispatch_phase.sh` and the Agent tool, neither of which Codex/Gemini sessions can drive the same way."
argument-hint: "<issue-number> [--type workspace|project] [--resume]"
---

# /run-issue

Host orchestrator for one issue's review loop. `run-issue` itself never
implements, reviews, or writes code — it enters the worktree, asks
`.agent/scripts/dispatch_phase.sh next` what happens next, dispatches that
phase to a fresh sub-agent, checks whether the phase kept its exit contract,
and pauses at `AskUserQuestion` checkpoints. The decision table lives in the
script, not here — see "Action tokens" below for where to read it.

## Usage

```
/run-issue <issue-number> [--type workspace|project] [--resume]
```

- `<issue-number>` — the GitHub issue driving the loop.
- `--type` — `workspace` (default) or `project`, exactly the value
  `/start-task` and `dispatch_phase.sh` take. Threaded to every
  `dispatch_phase.sh` call, `worktree_create.sh` at entry,
  `gh_create_pr.sh` targeting at publish, and `merge_pr.sh --type` at merge.
- `--resume` — re-asks the newest `## Checkpoint` entry when it answered
  `stop` (see "Resume" below). Without it, a `stop` checkpoint ends the run.

## When to use

- Driving an issue's review loop unattended between checkpoints, once a
  plan exists or is about to be authored.

## When not to use

- **Not Claude Code.** `run-issue` depends on the Agent tool (to dispatch a
  phase into a fresh sub-agent) and `AskUserQuestion` (to pause at a
  checkpoint), exactly as `/start-task`'s Claude-Code-only note explains for
  its own dependency on a persistent shell. Codex / Gemini sessions keep
  driving `review-issue` → `plan-task` → ... → `triage-reviews` by hand.
- **A second `run-issue` (or hand edit to `progress.md`) is already driving
  this issue.** One driver per issue (ADR-0014) — `dispatch_phase.sh
  --check-exit` can only report `MISSING` or an unexpected entry when this is
  violated, not detect it directly.

## Overview

```
review-issue → plan-task → review-plan → implement
   → review-code --branch  (pre-push; loop with address-findings up to MAX_ROUNDS)
   → publish (push + gh pr create, or gh pr edit + gh pr ready for a pre-existing draft)
   → review-code <PR>  (post-push re-review; SKIPPED when the pushed head is
                        the head the pre-push review approved — loop with
                        address-findings otherwise)
   → triage-reviews → merge
```

Nine checkpoint kinds pause for `AskUserQuestion` along this path:
`issue-actions`, `plan`, `publish`, `rounds`, `findings`, `merge`,
`merge-refused`, `phase-failed`, `unexpected`. Every checkpoint answer is
recorded as a durable `## Checkpoint` entry on `progress.md` **before** the
next `dispatch_phase.sh next` call — the timeline alone is the state
machine, so `/run-issue <N>` on a half-done issue resumes from the newest
entry with no state anywhere else.

**One dispatch path.** Every phase — dispatched or inline — is handed off
the same way: `dispatch_phase.sh --issue <N> --skill <phase> [--pr <M>]
[--type <type>]` prints the handoff block, and the host pastes it into a
fresh-context sub-agent via the Agent tool, using the model the handoff
names. No container mode, no `--context-file`, no auth preflight — phases
fetch their own issue/PR bodies with `gh` exactly as they do run by hand.

## Steps

### 1. Enter the worktree

Before anything else — including dispatching `review-issue` — enter or
create issue `<N>`'s worktree with `/start-task` semantics: `cd` into it, not
a framework-native worktree-entry tool (same reasoning as `/start-task`:
`dispatch_phase.sh`'s own worktree lookup and every persistence step below
resolve relative to the worktree, and `_resolve_work_plans_dir.sh` refuses
outside it — issue #147). Follow `.claude/skills/start-task/SKILL.md` steps
1–4 with `--issue <N> --type <type>`. If step 1 there refuses (already in a
worktree), stop and tell the user to exit first.

**Identity, on every command chain.** `dispatch_phase.sh`'s handoff mode
hard-fails with exit 2 when `AGENT_NAME`/`AGENT_EMAIL` are unset — there is
no fallback to the human's git config. Shell state does not persist between
tool calls, so source the identity in the *same* chain as every
`dispatch_phase.sh` call (and every `progress_append.sh` / `git commit`),
not once at the start of the run:

```bash
source .agent/scripts/set_git_identity_env.sh "<agent name>" "<agent email>" "<model-id>" \
  && .agent/scripts/dispatch_phase.sh --issue <N> --skill <phase> [...]
```

### 2. Probe PR state

```bash
gh pr list --head "$(git branch --show-current)" --state all \
  --json number,state,isDraft,title,headRefOid
```

No result → `--pr none`. A result with `isDraft == true` → still `--pr
none` (a pre-existing `[PLAN]` draft the publish step below will take over
by `isDraft`, not by title — see step 8). Otherwise map GitHub `state`
(`OPEN`/`MERGED`/`CLOSED`) to `open`/`merged`/... — a closed-not-merged PR
is outside this loop's action-token vocabulary; stop and hand it to the
user. Keep the PR number `<M>` for every `--pr <M>` call below, and the
`headRefOid` as `<H>` for step 3's `--head`.

### 3. Ask `next` what happens next

```bash
.agent/scripts/dispatch_phase.sh next --issue <N> --pr <none|draft|open|merged> [--type <type>] [--head <H>]
```

**Pass `--head <H>`** (step 2's `headRefOid`) whenever a PR exists
(`--pr draft|open`). It answers one question for the table: after a clean
pre-push review, `publish` pushed exactly the commits that review named, so
a PR-mode `review-code <M>` on them would re-read an unchanged diff.
Given `--head`, an approving `## Local Review (Pre-Push)` whose SHA still
covers the head — the same commit, or an ancestor with only bookkeeping
files changed since (`merge_pr.sh`'s own #286 equivalence rule) — routes
straight to `triage-reviews`; if code changed after that review, it routes
to `review-code` as before. Omitting `--head` is safe but wasteful: the
state falls back to `checkpoint:publish` and the redundant re-review
returns. The `## Integrated Review` then cites the pre-push entry as its
local source — `review_progress.sh sources` already correlates the two by
head SHA, so nothing extra is needed to keep the source count honest.

Prints `action=<token>`, `reason=<one line>`, and, depending on the row:
`round=<n>`, `phase=<skill>`, `mode=inline`. Read the full contract and the
28-row decision table in the script's header comment and inline comments
(`.agent/scripts/dispatch_phase.sh`) — this skill does not restate them.
Route on `action=` per "Action tokens" below.

### 4. Dispatching a phase

**Check `mode=inline` first.** If the `next` output from step 3 included a
`mode=inline` line, do not dispatch — go to step 5 instead. Since issue
#314 exactly one row still emits it: a `checkpoint:phase-failed` /
`takeover` answer (row 27), which emits it for the named phase whatever
that phase is — `test_dispatch_phase.sh`'s `"row 27: takeover always
carries mode=inline"` fixture pins this. `action=implement` (rows 10, 26
when `**Phase**: implement`) is *not* one of them any more: the post-plan
implementation pass is dispatched like every other phase. Only an
`action=<skill>` with no `mode=inline` line is actually dispatched below.

For any such `action=` naming a skill (`review-issue`, `plan-task`,
`review-plan`, `implement`, `review-code`, `address-findings`,
`triage-reviews`), record
the current entry count for the expected type as `$BEFORE` — the same
missing-file-is-zero rule `--check-exit` itself applies (`progress_read.py`
exits 1 on a file that doesn't exist yet, e.g. before `review-issue`'s
first run, so guard it rather than calling the script unconditionally):

```bash
PF="<worktree>/.agent/work-plans/issue-<N>/progress.md"
BEFORE=0
[[ -f "$PF" ]] && BEFORE=$(python3 .agent/scripts/progress_read.py "$PF" --type "<entry-type>" \
    | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["entries"]))')
```

`<entry-type>` is the **exact** string the handoff block's `entry_type=`
line printed for this dispatch — `Local Review (Pre-Push)`, not `Local
Review`. The two are distinct types in `skill_entry_type()` (branch-mode
vs. PR-mode `review-code`), and `--check-exit` counts the same exact type,
so a `$BEFORE` taken against the other one silently reports `MISSING` or a
false `OK`.

then:

```bash
.agent/scripts/dispatch_phase.sh --issue <N> --skill <phase> [--pr <M>] [--type <type>]
```

prints the handoff block: `worktree=`, `task=`, `agent_name=`,
`agent_email=`, `model=`, `entry_type=`, `exit_contract=`, `conventions=`.
Paste the task line, the worktree, the exit contract, and the
`conventions=` line (the `**When**` format and scratch-file hygiene every
dispatched phase must follow) into a fresh Agent tool call using the
printed `model=` as the model override. The dispatched phase
fetches its own inputs (issue/PR body via `gh`) — nothing is injected.

After the sub-agent returns, check the exit contract:

```bash
.agent/scripts/dispatch_phase.sh --check-exit --issue <N> --skill <phase> [--pr <M>] [--type <type>] --before "$BEFORE"
```

`status=OK` (with `sha=`) → continue to the next `next` call. `status=
PARTIAL|FAILED|MISSING` → this is always `checkpoint:phase-failed`, never a
silent retry: surface the phase, the outcome, and the last entry's text (or
"no entry written") in an `AskUserQuestion` offering re-dispatch, takeover,
or stop, then write the `## Checkpoint` entry (below) before calling `next`
again.

**The dispatched implement pass.** `action=implement` has no `SKILL.md` of
its own — no `/implement` slash command exists, so `skill_task_line()`
prints a literal instruction ("implement the plan at
`.agent/work-plans/issue-<N>/plan.md` on this branch") and the handoff's
`exit_contract=` names the entry shape outright. Paste that contract
verbatim; the dispatched agent commits its own work (the host still owns
every push, step 10) and appends:

```markdown
## Implementation
**Status**: complete | partial | failed
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <agent name> (<model>)
**PR**: #<M> at `<sha>`   <!-- or **Branch**: <name> at `<sha>` before a PR exists -->

<short list of what changed>
```

The `**PR**` / `**Branch**` correlation line is required, not decorative:
`## Implementation` is a PR/branch-correlated type in ADR-0013, and without
it the entry's correlation parses null — which breaks the pre-push round
counter's branch correlation and `merge_pr.sh`'s head-vs-review
correlation. The entry carries **no** `**Mode**` field (that marker belongs
to a takeover, step 5) and no `**Addressed**` field (that one is
`address-findings`' and is what `next`'s `skill_for()` routes a failed
`## Implementation` on).

### 4a. Reusing a running sub-agent for a repeat phase

Every phase above is dispatched to a *fresh* sub-agent by default. One
narrow exception buys back the 5–8 minutes a fresh agent spends
re-orienting on the same branch it just reviewed: for a **repeat** of a
phase already run on this issue in this drive, resume the agent that ran it
instead of dispatching a new one.

Keep a per-issue map of phase → agent id for the current drive. Before
dispatching `review-code` round ≥ 2, `address-findings` round ≥ 2, or a
repeat `triage-reviews` on the same PR, check the map: if that phase's
agent is still live, resume it with `SendMessage` carrying the *normal*
handoff block plus one extra line — "you already hold this branch; read
only `progress.md` entries newer than your last one". If the agent is gone
(or the map is empty), dispatch fresh exactly as today.

**The trade-off, stated.** Resuming the *reviewer* for `review-code` round
≥ 2 gives up one thing on purpose: that round's lead reviewer already knows
the code it is re-reading, so it no longer comes to the diff cold. The
independence the pre-push loop depends on is kept where it does the work —
`review-code` spawns its adversarial specialist fresh on every round, and
that sub-review never resumes. Round 1 is never reused (see below), so the
first read of any branch is always cold.

**Never reuse**: round 1 of any phase; an agent from a different issue; an
agent already resumed 3 times; or any agent from before a merge-from-main
landed on the branch (its view of the diff is stale). A resumed agent is
held to the *same* exit contract and the same `--check-exit` check as a
fresh one — nothing about the contract relaxes.

**A reuse is recorded, so the never-list is checkable.** A resumed phase's
own entry adds one field:

```markdown
**Dispatch**: resumed (agent <id>, resume <n> of 3)
```

Its absence means a fresh dispatch. Nothing reads this field — it is a
record, not a lock — but it is what makes the resume count survive a
`/run-issue <N> --resume` (or any host restart), which loses the in-session
phase → agent map entirely. Without it the policy would silently stop
applying and no later reviewer could tell. Tell the resumed agent to
include the line; say the resume number in the `SendMessage` itself, since
the agent cannot count its own resumes.

### 5. Running a phase inline (`mode=inline`)

Any `action=<token>` carrying `mode=inline` (from step 4's check) means the
host runs that phase itself, in the worktree, instead of dispatching a
sub-agent. Since issue #314 exactly one case produces it:

- **A `checkpoint:phase-failed` / `takeover` answer** (row 27) — the phase
  named in `**Phase**` failed or produced only a partial entry, and the
  owner chose to have the host finish it rather than re-dispatch. Row 27
  always prints `mode=inline` for the named phase (the takeover-always
  fixture cited in step 4), so this branch fires for *any* phase, not only
  `implement`. The host does the phase's own work and writes **exactly the
  entry that phase would have written** (its `SKILL.md`'s own persistence
  step and entry shape — e.g. a taken-over `review-plan` still writes
  `## Plan Review` with a verdict and findings checklist). `**Mode**:
  inline` is added **only** when the phase taken over is the post-plan
  implement pass (i.e. `**Phase**: implement`); every other taken-over
  phase's entry carries no `**Mode**` field at all, identical in shape to
  what a normal dispatch of that phase would have written.

  `**Mode**: inline` is now purely informational — **no dispatcher reads
  it**. Until issue #314 it was how `next`'s `skill_for()` told the
  implement pass from `address-findings`; that classifier keys on
  `**Addressed**` instead, and nothing else ever consumed `**Mode**`. It
  stays because it is the only durable record that the host, not a
  sub-agent, produced the entry.

This case uses `.agent/scripts/progress_append.sh <N> --title "<issue
title>" <<'ENTRY'` (the script header documents the exact stdin/flag
contract).

### 6. Checkpoints are entries, written before the next call

Every `AskUserQuestion` outcome becomes a `## Checkpoint` entry, appended
via `progress_append.sh` **before** the next `dispatch_phase.sh next` call
— this is a contract line, not a suggestion; `next` reads the timeline, not
the conversation.

```markdown
## Checkpoint
**Status**: complete
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <host agent> (<model>)
**Decided-by**: owner
**After**: <checkpoint name>
**Decision**: <token from the vocabulary below>
**Phase**: <skill>   <!-- only on an `After: phase-failed` entry -->

<the owner's answer text verbatim>
```

`**After**` is one of the nine checkpoint names above (from
`checkpoint:<name>` in `action=`). `**Decision**` is the owner's answer,
constrained per `**After**` (`dispatch_phase.sh`'s header comment has the
full table; anything outside it routes `next` to row 28,
`checkpoint:unexpected`, on the *next* call — write within the vocabulary).
`**Phase**` is copied from the `phase=` line `next` printed with the
`checkpoint:phase-failed` action; omit it for every other `**After**`.
`**Decided-by**: owner` records that this entry captures the human's answer
to an `AskUserQuestion`, not a phase's own output.

**Deferred suggestion-only boxes.** One case needs a second write alongside
the `## Checkpoint` entry: an `**After**: findings` checkpoint answered
`merge` while suggestion-only boxes in the latest `## Integrated Review`'s
`### Findings` section are still open. This is **not** what unblocks the
merge — row 21 routes `**After**: findings` + `**Decision**: merge` to
`merge` unconditionally, without looking at open boxes
(`dispatch_phase.sh`'s `if after in ("findings", "merge")` block;
`test_dispatch_phase.sh` fixture `"row 21: checkpoint findings answered
merge -> merge"`). Close them because they are the durable record that the
owner deferred them, and because the re-route *is* reachable when the merge
doesn't land: a merge attempt whose gate preconditions failed records
`## Merge (report-only)` (or `## Merge (unreviewed)` under
`--force-unreviewed`) — written whether or not the merge itself then
succeeds — and while `--pr` is not `merged` that newest entry routes to
`checkpoint:merge-refused` (row 23); answering that `retriage` writes a
fresh `## Integrated Review`, and row 19 re-raises `checkpoint:findings` on
those same still-open boxes. The re-route only happens when a merge entry
was actually written, and two paths write none — the same caveat step 11
records. An `--enforce` refusal on a *workspace* PR exits 1 before any
record (`merge_pr.sh:896-903`), and a *passing* gate records nothing
either (`:889-890`), so a run whose gate approved but whose merge then
fails — CI, mergeability, or `gh pr merge` — also exits 1 with no entry.
On both, there is no newest merge entry for `dispatch_phase.sh` to route
on and no `checkpoint:merge-refused` re-route. For each such box, run:

```bash
PF="<worktree>/.agent/work-plans/issue-<N>/progress.md"
.agent/scripts/review_progress.sh findings --progress "$PF"   # <i> comes from here
.agent/scripts/review_progress.sh check --progress "$PF" --index <i> \
  --deferred "<the owner's reason, from the checkpoint entry's own text>"
```

`<i>` is the `index` field `findings` printed for that box — never a
hand-count. It is 0-based over **every** checkbox line in the latest review
entry, not just the ones under `### Findings`, so a section-relative count
defers the wrong line: `check` only verifies that the indexed line is an
unchecked box, not that it is the box you meant. Re-assign `PF` in the same
chain as the `check` call — shell state does not persist between tool
calls, so step 4's `PF` is gone by the time this runs.

This flips `- [ ]` to `- [x] … (deferred: <reason>)`; a checked box is
excluded from `open_findings()` whatever its annotation, so no new marker
and no dispatcher change is involved. `check` rewrites `progress.md` in
place and does **not** commit — the host commits the flipped file itself
(a plain `git commit` of `progress.md`, in the same chain as the identity
source), after the `## Checkpoint` entry and before the next
`dispatch_phase.sh next` call.

**Every dialog is self-contained.** Open every `AskUserQuestion` (and every
message ending a turn) with:

```
<repo>#<N> (PR #M): <title> — phase X of Y (<phase>); <state>
```

embedding the finding text verbatim — never "the four findings above" or
"as triaged". Every Bash tool-call description opens with `<repo>#<N>
<phase>:` so the user can orient from the permission prompt alone.

### 7. Publish

`action=publish` (`--pr none` only, row 16): push the branch, then create
the PR:

```bash
git push -u origin "$(git branch --show-current)"
.agent/scripts/gh_create_pr.sh --title "<title>" --body-stdin <<'EOF'
## Decision summary

<the pinned Decision summary from the last review-code / implementation>
EOF
```

**The heading must be exactly `## Decision summary`** — level 2, at the
top level of the PR body, never re-nested under a sub-agent's own heading
(`### Decision summary` inside a `## Review` section does not count).
`merge_pr.sh` greps that literal string when it checks gate condition (b)
(`merge_pr.sh:760-761`); a re-nested or reworded heading makes the gate
report the summary missing and the merge is refused. When the text comes
from a dispatched phase's report, copy the body and re-head it at level 2
yourself.

**Pre-existing draft PR** (a `[PLAN]` draft opened by hand before
`run-issue` took over — step 2 reports `isDraft: true` as `--pr none`): in
the same turn, retitle and replace the body instead of creating a second
PR, then mark it ready — keying on `isDraft`, not the title, is what makes
the PR-state probe read `open` on the next loop:

```bash
gh pr edit <M> --title "<real title>" --body-file <body-with-AI-signature>
gh pr ready <M>
```

`gh_create_pr.sh` injects the AI signature on create; `gh pr edit` does
not, so append it to the body file yourself before this call.

### 8. Merge-from-main before the final pre-push review

Before every `review-code --branch` dispatch (row 12, `--pr none`), check
whether the branch is behind:

```bash
.agent/scripts/check_branch_updates.sh
```

If behind, merge main into the branch first, so the SHA `review-code`
reviews is the SHA that gets pushed — a merge-from-main after the review
would leave the review stale at the merge checkpoint.

### 9. Waiting for reviews

After publish, and after every PR-mode `## Local Review` (a re-review of a
fix, row 22a/22b), wait for the **review sources** to be in before
dispatching `triage-reviews`:

```bash
.agent/scripts/fetch_pr_reviews.sh --pr <M>
```

The wait condition is the reviews, not CI. Wait until the
`copilot-pull-request-reviewer` check-run has completed (or is confirmed
absent from the check list entirely) and any requested human reviews are
in — otherwise `triage-reviews` runs before Copilot's review exists and
triages a source that lands minutes later. **CI may still be running**:
that is the wall-clock saving, since a triage of the review sources does
not depend on the CI verdict. One case looks like a completed review but
is not: when Copilot's quota is exhausted it posts a plain issue comment
saying so instead of a review — that comment is not a review source for
`triage-reviews`, so note it and move on rather than waiting further.

When CI has not settled, say so in the dispatch: the `## Integrated
Review` records `**CI**: pending` (a value in `triage-reviews`' own `**CI**`
vocabulary) instead of `all-pass` / `failures-noted`. `merge_pr.sh` still
gates the merge on CI regardless — triaging early never merges anything
early.

**Re-check CI before the merge checkpoint.** After an `## Integrated
Review` that recorded `**CI**: pending`, run `fetch_pr_reviews.sh --pr
<M>` again before presenting the `merge` checkpoint, and do not present it
while CI is still running.

If CI has since *failed*, **do not dispatch anything off the table.** The
loop was about to raise a checkpoint here anyway (`checkpoint:merge`, or
`checkpoint:findings` when the `## Integrated Review` still has open
boxes) — raise that same checkpoint, with the failing checks quoted
verbatim in the dialog, so the question the owner answers is "merge, or
address the CI failure first?" rather than "merge?". Record the answer as
the ordinary `## Checkpoint` entry (step 6): `**After**: merge` (or
`findings`, whichever the loop raised) with `**Decision**: address`, which
`next` routes to `address-findings` on the following call — row 22, the
`if after in ("findings", "merge")` block. `**Decision**: stop` and
`**Decision**: merge` are the other two answers; `merge`'s vocabulary has
no `retriage`, so a failure that needs re-triaging against the review
sources is answered `address` and picked up by the fix round's own
`review-code` → `triage-reviews` cycle.

This is the whole point of routing it through an entry: a bare dispatch
would leave the newest entry the `## Integrated Review` with no open
findings, so a `/run-issue <N>` resume would re-derive `checkpoint:merge`
and walk straight back into the failing merge. Discovering the failure
inside `merge_pr.sh` instead is a dead end for the same reason — a gate
that passed records no entry at all (`merge_pr.sh:889-890`, the caveat
step 11 repeats), so a merge that then fails on CI leaves `next` with no
newest entry to route on and no `checkpoint:merge-refused` re-route.

`triage-reviews` with only the local review as
a source still writes `## Integrated Review` — the only entry type that
reaches the `findings`/`merge` checkpoints.

### 10. The host owns every push

Dispatched phases never push — the exit contract in every handoff says so.
The host pushes: at publish (step 7), after every `## Implementation`
written while a PR exists (before the next `review-code <M>` or
`triage-reviews` dispatch, so the head those phases correlate on contains
the fix), and before `review-code --branch` when a merge-from-main just
landed (step 8). One exception: `merge_pr.sh` pushes its own `## Merge
(...)` record commit from inside its own gate — that is the merge script's
contract, not a phase's, and `run-issue` leaves it alone.

The host also pushes the entry commits that come *after* the last review —
the `## Integrated Review` `triage-reviews` writes and every `## Checkpoint`
entry recorded on the way to the merge checkpoint — before running
`merge_pr.sh`. This is safe even though those commits move the head past
the SHA the review named: the merge gate (`merge_pr.sh`, #286) treats a
review at SHA `R` as still current for head `H` when `R` is an ancestor of
`H` and only bookkeeping files (`progress.md`, the roadmap) changed between
them (`_only_bookkeeping_between`). See ADR-0013's References for the gate
rule.

### 11. Leave the worktree before merging

`merge_pr.sh` removes the worktree and deletes the branch. Before
`action=merge` (row 21), `cd` to the main tree first:

```bash
cd "$(git rev-parse --show-toplevel)"
```

then run `.agent/scripts/merge_pr.sh --pr <M> --type <type>`. If the merge
does not end merged *and* the run recorded a merge entry — a report-only
run (or `--force-unreviewed`) records its own `## Merge (report-only)` /
`## Merge (unreviewed)` entry and can still fail later — the next `next`
call routes to `checkpoint:merge-refused` (row 23) — surface it and record
the owner's answer (`retriage`, `address`, or `stop`) as a `## Checkpoint`
entry the same way as any other checkpoint. The entry-less paths do not
re-route: an `--enforce` refusal on a *workspace* PR exits 1 with no entry
(on a project PR `--enforce` falls through to the report-only branch,
`merge_pr.sh:896,904-908`), and a gate that passed records nothing, so a
later CI, mergeability, or `gh pr merge` failure leaves no entry either.
`--pr merged` short-circuits
`next` to `action=done` before any worktree or progress resolution is
attempted (row 1) — the worktree may already be gone.

One precondition belongs to step 9, not here: if the latest `## Integrated
Review` recorded `**CI**: pending`, CI is re-checked *before* the merge
checkpoint is presented, and a CI failure routes to `address-findings` (or
a fresh `triage-reviews`). Do not let a pending-CI triage reach
`merge_pr.sh` — the entry-less failure paths above are exactly what that
re-check avoids.

### 12. Resume

Every `dispatch_phase.sh next` call re-derives the next action from the
newest `progress.md` entry; nothing lives outside the file. One
qualification: `stop` is absorbing — while a `stop` checkpoint is the
newest entry, `next` returns `action=done` with `reason=` naming the
stopped checkpoint. `/run-issue <N> --resume` re-asks that exact
checkpoint (same `**After**`, and `**Phase**` if the row carried one) and
records the new answer as a fresh `## Checkpoint` entry, which then routes
normally on the following `next` call.

## Action tokens

`next`'s full vocabulary (`review-issue`, `plan-task`, `review-plan`,
`implement`, `review-code`, `address-findings`, `publish`,
`triage-reviews`, `merge`, `done`, and `checkpoint:<name>` for the nine
checkpoint names) and the 28-row decision table that produces them live in
`.agent/scripts/dispatch_phase.sh`'s header comment and inline comments —
read there, not here. This skill's job is routing on the printed token
(dispatch per step 4 — `implement` included — inline per step 5 (a
takeover), publish
per step 7, merge per step 11, checkpoint per step 6, `done` ends the run
cleanly) — it does not re-derive or restate the table.

## No auto-chaining

Phases never dispatch each other, and `run-issue` never advances past a
checkpoint on its own judgment. Each `next` call decides exactly one step;
the host always pauses at a checkpoint for the owner's actual answer before
writing the entry that unblocks the next call.

## One driver per issue

A second `run-issue` on the same issue, or a hand edit to `progress.md`
mid-run, is out of contract (ADR-0014). `--check-exit`'s entry-count
comparison is the only detection available, and it reports `MISSING` or an
unexpected type rather than guessing at what happened.

## Scope

Three things this loop deliberately does not cover, per the owner's own
notes on the plan for issue #276:

- **Field mode** (#208/#209) — the publish and merge steps here are
  GitHub-only; a non-GitHub publish path is a separate, later change to
  those two steps, not something this loop's design anticipates.
- **`--type project` end to end** — threaded through `run-issue` and
  `dispatch_phase.sh` today, but its path still inherits `merge_pr.sh`'s
  legacy single-repo project handling; a full multi-project story follows
  issue #265, not this loop.
- **ADR-0012 package worktrees** (`--issue owner/repo#N --layer …`) — out
  of scope here. Multi-repo worktree composition is an adapter concern
  (ADR-0012), not orchestrator logic; `run-issue` stays repo-agnostic and
  does not grow layer/package awareness.
