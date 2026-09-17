---
name: address-findings
description: Work through the open action items from the latest review entry in progress.md — a ## Integrated Review (post-PR) or a ## Local Review (Pre-Push) (pre-push) — make each fix, commit atomically with pre-commit hooks, check the box, and record a ## Implementation entry. The close-the-loop phase between a review and its re-review.
---

# Address Findings

## Usage

```
/address-findings [--issue <N>] [--strict-progress] [--no-progress]
```

Run from the issue's worktree (or pass `--issue <N>`). Operates on the
**latest review entry** — a `## Integrated Review` (post-PR triage) or a
`## Local Review (Pre-Push)` (pre-push `review-code`) — in that issue's
`.agent/work-plans/issue-<N>/progress.md`. `--strict-progress` and
`--no-progress` control step 5's persistence exactly as in `review-code`.

## Overview

**Lifecycle position**:
- post-PR: triage-reviews → **address-findings** → review-code (re-review)
- pre-push: review-code (changes-requested) → **address-findings** → review-code (re-review)

A review phase produces the *source review entry* — `triage-reviews` a
`## Integrated Review` (post-PR), or pre-push `review-code` a `## Local Review
(Pre-Push)` (changes-requested). Either is a fix plan of `- [ ]` checkbox
actions (must-fix and suggestions), plus plain-bullet false positives that are
*dismissals, not actions*. This skill consumes that entry — it works each open
action, commits the fix atomically, checks the box, and writes one closing
`## Implementation` entry so the timeline shows what was addressed.

It is deliberately **thin**: it does not re-classify findings (that was the
review's job) and does not re-review its own work (that is the next
`review-code` pass). It only *acts on an agreed fix plan*.

**Entry type** — writes `## Implementation` (an existing ADR-0013 type; no
new type is minted). Ported from `ros2_agent_workspace` (issue #269 PR D);
the fork's orchestrator-routing note and its sub-agent dispatcher line are
dropped — this workspace hands off by printing the next command.

## Steps

### 1. Locate the issue and its progress.md

Resolve `<N>` from `--issue` or the worktree (`$WORKTREE_ISSUE`, else the
`feature/issue-<N>` branch). The file is
`.agent/work-plans/issue-<N>/progress.md` in the issue's worktree. If it
doesn't exist, stop with an error — there's no review to address.

### 2. Read the latest review entry

One call selects the source entry and lists what is open. It picks the
single latest `## Integrated Review` or `## Local Review (Pre-Push)` by
canonical type (a legacy `## External Review` never qualifies; the post-PR
`## Local Review` is not a source either), in file order — never merges
findings across entries, never falls back to an older one:

```bash
.agent/scripts/review_progress.sh findings \
    --progress .agent/work-plans/issue-<N>/progress.md
```

The JSON has `source` (`type`, `when`, `correlation` — the SHA the review
looked at) and `open`: each unchecked finding with its `index`, `text`, and
`source_hint`. Then:

- **`source` is null** — no review has run yet: report "no review entry to
  address — run `review-code --branch` (pre-push) or `triage-reviews`
  (post-PR) first" and exit without a commit. Do **not** act on other entry
  types.
- **`open` is empty** — report "nothing to address — the latest review has
  no open actions" and exit without a commit.

> **Pre-push actions *all* unchecked findings — including suggestions.**
> Post-PR `triage-reviews` curates which findings become actions; pre-push
> `review-code` writes must-fix *and* suggestions as unchecked boxes, so
> this skill actions the suggestions too. Defer any you disagree with via
> step 3.2 rather than skipping them.

### 3. Address each open finding

For each open finding, in listed order (cross-confirmed first):

1. Make the code/doc change the finding calls for. Read the cited
   `file:line` and the surrounding code first — verify the finding against
   the current source before acting (a finding can be stale if an earlier
   round already touched the area).
2. If, on inspection, the finding is **not** actionable (already fixed, or
   a genuine false negative on re-read), do **not** fake a change. Defer
   it: check its box with a reason, so it reads as handled-not-changed:

   ```bash
   .agent/scripts/review_progress.sh check --progress <file> --index <i> \
       --deferred "<one-line reason>"
   ```

   Checking it (rather than leaving it open) is deliberate: a box reflects
   whether the finding still needs attention, and a deferred one does not.
   It also keeps the skill idempotent — a re-run against the same source
   entry acts only on unchecked items and won't re-attempt a deferral.
3. From the issue worktree, stage the files for this finding and commit
   atomically with pre-commit hooks and the agent identity
   (`set_git_identity_env.sh`):

   ```bash
   git commit -m "<area>: <what was fixed> (#<N>)"
   ```

   Never `--no-verify`. One logical fix per commit. The source entry's
   box-check (next step) is the one permitted addition to a finding's
   commit beyond the finding's own files.
4. Check the box for that finding so the timeline tracks resolution — in
   the same commit as the fix, or a trailing progress commit:

   ```bash
   .agent/scripts/review_progress.sh check --progress <file> --index <i>
   ```

   The index is the one `findings` printed; `check` refuses an already
   checked box or an out-of-range index rather than touching another line.

### 4. Re-run hooks / quick local checks

After the last fix, run the relevant quick checks (the linters pre-commit
already ran, plus any suite the changes touch). This is not a full
`review-code` — it's a sanity pass before handing to the re-review.

### 5. Write the `## Implementation` entry

Append one entry through the same persistence call `review-code` step 8
and `triage-reviews` step 7 use (strict / compatibility switch,
`--no-progress`, no-issue skip — see `review-code` step 8 for the four
outcomes; echo the printed line):

```bash
.agent/scripts/review_progress.sh persist --issue "<N>" --branch "<branch>" \
    --title "<issue title>" [--strict] [--no-progress] <<'ENTRY'
## Implementation
**Status**: complete
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <agent name> (<model>)

**Branch**: <branch-name> at `<short-sha>`   <!-- or **PR**: #<N> at `<sha>` if a PR exists -->
**Addressed**: <source entry type> at `<its correlation SHA>` (<its When>)
**Commits**: <short-shas of the fix commits>

### Actions
- [x] <finding addressed> — `file:line`
- [x] <finding consciously deferred> — `file:line` (deferred: <reason>)
ENTRY
```

`## Implementation` is a PR/branch-correlated type in ADR-0013, so the
`**Branch**`/`**PR**` line is required — without it the entry's
correlation parses as null. `**Addressed**` names the source entry's type
and correlation SHA so a reader (and the next review's round counter) can
tie the two together. Every finding from the source entry appears under
Actions, either fixed-and-checked or deferred-checked-with-reason. Do not
push here; the calling session decides when to push.

### Next step

Lifecycle: **Implementation** → **review-code** (re-review the fixes)

Print the next command for the calling session:

```
/review-code --branch      # pre-push: re-review the fixes cold
/review-code <pr-number>   # post-PR: re-review on the PR
```

The re-review reads the diff cold and confirms the findings are genuinely
resolved. This skill never invokes it itself.

## Guidelines

- **Act on the agreed plan, don't re-litigate it** — the review already
  classified each finding. If you disagree with a finding on inspection,
  defer it with a reason; don't silently drop it or argue it in the commit.
- **Never fake resolution** — a checked box on an *actioned* finding must
  correspond to a real commit. A deferred finding is also checked, but
  annotated `(deferred: <reason>)` so it reads as "handled, not changed".
  What you must never do is leave a finding *silently* untouched.
- **Atomic commits** — one finding per commit where practical, so a
  re-review (and a revert) can reason about each fix independently.
- **Stay thin** — no re-classification, no self-review. The next
  `review-code` pass is the quality gate on this work.
