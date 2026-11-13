---
name: address-findings
description: Work through the open action items from the latest review entry in progress.md — a ## Integrated Review (post-PR), a ## Local Review (post-PR re-review) or a ## Local Review (Pre-Push) (pre-push) — make each fix, commit atomically with pre-commit hooks, check the box, and record a ## Implementation entry. The close-the-loop phase between a review and its re-review.
session_scope: both
---

# Address Findings

## Workspace root

This skill can run in a **project** session — a session started in a project
checkout, not in the workspace. There, `$WS_ROOT/.agent/scripts/...` does not resolve:
those paths belong to the workspace, and the cwd is somewhere else entirely.

Every workspace path below is therefore written `$WS_ROOT/.agent/scripts/...`.
Resolve `$WS_ROOT` at the head of each command chain, because shell state does
not persist between tool calls:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/<script>" ...
```

`~/.claude/agent-workspace-root` is written by
`.agent/scripts/user_tier_install.sh`. It is a plain file, not an environment
variable and not `SessionStart` hook output — hook stdout is context text and
never reaches a tool call's shell (ADR-0016).

**The `|| echo .` fallback is required, not decoration.** The user tier is
optional — `--check` and ADR-0016 both say so — and on a machine without it
the file does not exist. A bare `cat` would leave `$WS_ROOT` empty and turn
every command below into `/.agent/scripts/...`, which is worse than the
relative path it replaced. With the fallback, `$WS_ROOT` is `.` and a
workspace session behaves exactly as it did before this idiom existed.

## Usage

```
/address-findings [--issue <N>] [--strict-progress] [--no-progress]
```

Run from the issue's worktree (or pass `--issue <N>`). Operates on the
**latest review entry** — a `## Integrated Review` (post-PR triage), a
`## Local Review` (a PR-mode `review-code` re-review) or a
`## Local Review (Pre-Push)` (pre-push `review-code`) — in that issue's
`$WS_ROOT/.agent/work-plans/issue-<N>/progress.md`. `--strict-progress` and
`--no-progress` control step 5's persistence exactly as in `review-code`.

## Overview

**Lifecycle position**:
- post-PR: triage-reviews → **address-findings** → review-code (re-review)
- post-PR re-review: review-code (PR mode, changes-requested) → **address-findings** → review-code
- pre-push: review-code (changes-requested) → **address-findings** → review-code (re-review)

A review phase produces the *source review entry* — `triage-reviews` a
`## Integrated Review` (post-PR), PR-mode `review-code` a `## Local Review`
(changes-requested re-review), or pre-push `review-code` a `## Local Review
(Pre-Push)` (changes-requested). Each is a fix plan of `- [ ]` checkbox
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
`$WS_ROOT/.agent/work-plans/issue-<N>/progress.md` in the issue's worktree. If it
doesn't exist, stop with an error — there's no review to address.

### 2. Read the latest review entry

One call selects the source entry and lists what is open. It picks the
single latest `## Integrated Review`, `## Local Review (Pre-Push)` or
`## Local Review` by canonical type (a legacy `## External Review` never
qualifies), in file order — never merges findings across entries, never falls
back to an older one. The `No issues found. LGTM.` box an approved review
leaves unchecked is not listed as open when the entry's summary line counts
`**Must-fix**: 0 | **Suggestions**: 0`; otherwise (a count above zero, or
no summary line) it is listed like any other box:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/review_progress.sh findings \
    --progress "$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<N>/progress.md"
```

The JSON has `source` (`type`, `when`, `correlation` — the SHA the review
looked at) and `open`: each unchecked finding with its `index`, `text`, and
`source_hint`. Then:

- **`source` is null** — no review has run yet: report "no review entry to
  address — run `review-code --branch` (pre-push) or `triage-reviews`
  (post-PR) first" and exit without a commit. Do **not** act on other entry
  types.
- **A host full-pass failure** — when the handoff, or the newest
  `## Checkpoint` entry (`**After**: publish` or `rounds`, `**Decision**:
  address`), quotes a failure of the host's full pre-commit pass
  (`run-issue` step 7), that failure is an open finding, in addition to
  `open` and even when `open` is empty (an approved review leaves it
  empty). Act on it in step 3 like any other finding, with no box to check
  (skip 3.4 for it), and list it under Actions in step 5.
- **`open` is empty and no host full-pass failure is quoted** — report
  "nothing to address — the latest review has no open actions" and exit
  without a commit.

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
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
   $WS_ROOT/.agent/scripts/review_progress.sh check --progress <file> --index <i> \
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

   **Dispatched pass** (owner-decided 2026-11-13, issue #465): only when
   the handoff's `conventions=` line carries the hook rule — a workspace
   pass dispatched by `/run-issue` — set `SKIP=validate-script-tests` on
   every commit, the step 5 entry's commit included, so the script suites
   do not run on any commit. Every other hook still runs, and
   `--no-verify` is still never allowed. A hand-run session or a project
   pass has no such line and commits with every hook, as above.
4. Check the box for that finding so the timeline tracks resolution — in
   the same commit as the fix, or a trailing progress commit:

   ```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
   $WS_ROOT/.agent/scripts/review_progress.sh check --progress <file> --index <i>
   ```

   The index is the one `findings` printed; `check` refuses an already
   checked box or an out-of-range index rather than touching another line.

### 4. Re-run hooks / quick local checks

After the last fix, run the relevant quick checks (the linters pre-commit
already ran, plus any suite the changes touch). This is not a full
`review-code` — it's a sanity pass before handing to the re-review.

A dispatched pass whose handoff carries the hook rule (step 3) runs no
full pre-commit pass over the branch: that pass is the host's, once per
pull request before the push (`run-issue` step 7), and after publish CI
checks every push. Follow the rule as the handoff prints it: run the
suites that test what you changed, each on its own with
`bash <worktree>/.agent/scripts/tests/<suite>`, the issue worktree's own
copy (never `$WS_ROOT`'s, which is the main checkout's) — the
`test_<name>.sh` and any `test_<name>_*.sh` of each script you changed,
`test_skill_paths.sh` when you changed skill or knowledge text, and any
suite file you changed. A changed script with no suite of its own gets
none; name it in step 5's entry. If a suite fails, fix the cause (a commit
of its own) and run that suite again before step 5. Step 5's entry names
each suite you ran with its result line and says the full pass was left
to the host. A run of every suite takes about 4 minutes at 4 jobs (240 s),
against 14 to 18 minutes at one job (824 to 1069 s), measured 2026-11-13
on a 16-CPU machine; that cost is why it runs once per pull request.

### 5. Write the `## Implementation` entry

Append one entry through the same persistence call `review-code` step 8
and `triage-reviews` step 7 use (strict / compatibility switch,
`--no-progress`, no-issue skip — see `review-code` step 8 for the four
outcomes; compatibility refuses like strict outside issue `<N>`'s
checkout, and commits after the notice only when `WORKTREE_ISSUE` names
another issue or `WORK_PLANS_DIR_OVERRIDE` is set; echo the printed line):

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/review_progress.sh persist --issue "<N>" --branch "<branch>" \
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
tie the two together. When the pass acted on a host full-pass failure
(step 2), `**Addressed**` names it, never left empty (`next` tells this
pass from the implement pass by that field), as
`**Addressed**: host full pass at <head sha> (Checkpoint <its When>)`,
followed by the review entry as above when that entry's open boxes were
worked too. Every finding
from the source entry, and a quoted host-pass failure, appears under
Actions, either fixed-and-checked or deferred-checked-with-reason. Do not
push here; the calling session decides when to push.

The entry is committed like the fixes: with every hook, or, in a
dispatched pass whose handoff carries the hook rule, with
`SKIP=validate-script-tests` too (step 3). It touches only the issue's
work-plan directory, which `validate-script-tests` excludes either way.
The checks on a dispatched pass's commits are the host's full pass before
the push and CI after it: `make lint` runs every hook on all files on
pushes to `main`, `feature/**` and `fix/**` and on PRs to main, and
`merge_pr.sh` waits for it.

### Next step

Lifecycle: **Implementation** → **review-code** (re-review the fixes)

Print the next command for the calling session:

```
/review-code --branch      # pre-push: re-review the fixes cold
/review-code <pr-number>   # post-PR: re-review on the PR
```

The re-review reads the diff cold and confirms the findings are genuinely
resolved. This skill never invokes it itself. The re-review's depth tier
is the whole diff's, exactly as a first review's — never lowered because
the fix round is small (`review-code` step 2).

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
