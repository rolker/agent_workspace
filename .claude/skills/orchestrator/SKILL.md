---
name: orchestrator
description: "Interim, until the orchestrator design session. The orchestrator for one root (the 'department head' for that root): keeps the owner at goal level while issues run through /run-issue in the background, decides mechanism questions itself and lists each for his veto, and juggles several issues, a stop time and parked items. Use when the owner asks to run, drive or orchestrate issues."
argument-hint: "[<issue-number> ...] [--stop HH:MM]"
session_scope: both
---

# /orchestrator

## Workspace root

This skill can run in a project session as well as in the workspace. There,
`.agent/...` does not resolve, so every workspace path below is written
`$WS_ROOT/...`, resolved at the head of each command chain:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
```

`~/.claude/agent-workspace-root` is written by `user_tier_install.sh`; with
no user tier the fallback is the cwd, which is right in a workspace session
(ADR-0016).

## What it is

Conduct toward the owner and across issues. Everything about one issue (the
phases, the nine checkpoints, the dispatch, the exit check, the dialog
orientation line, phase reuse, one driver per issue) is `/run-issue`'s;
this skill points there and does not restate it. It conducts only the root
this session was launched in (`/run-issue`, "This session's root").

Before anything else, read the standing rules. They apply throughout, and
each carries its reason:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
cat "$WS_ROOT/.agent/knowledge/host_standing_rules.md"
```

The role name, in status lines and hand-backs, is "orchestrator for
<root>". A Codex or Gemini host follows the rules file and this text by
hand; the dispatching needs Claude Code's Agent tool.

## Decision rights

Only three kinds of question reach the owner. Each has a trigger a host can
test from the text in front of it:

- **Goal meant.** The answer would change what the work is for, its scope,
  or add or drop a behaviour his quoted words ask for or rule out. How a
  behaviour he asked for works (its limits, wording, order, format,
  defaults) is a host decision, listed for veto.
- **Goals in tension.** Two README goals, or two principles, give opposite
  answers. Name both.
- **Outward or hard to undo.** The AGENTS.md "Ask First" list, every merge,
  anything outside the boundary below, deleting data.

Everything else (approach, naming, formats, scripts, wording) is decided
from `docs/principles.md` and `docs/design.md`. **When unsure** whether a
question is mechanism or goal: decide it, list it under "Decisions made
(owner may veto)" with what undoing it costs. A question that changes the
design is the exception: asked alone (standing rules). A mechanism question
that reaches the owner anyway is a defect in the loop: say so in one line
of the hand-back and count it in the issue 398 comment.

## Checkpoints: who answers, with which tokens

`/run-issue` still raises every checkpoint and writes it as a
`## Checkpoint` entry before the next `next` call. The host may answer only
with the tokens below, writing `**Decided-by**: host (<reason>)`; anything
else waits for the owner, written `**Decided-by**: owner`.

| Checkpoint | Host may answer | Owner only |
|---|---|---|
| `issue-actions` | `proceed` | anything that changes scope |
| `plan` | `proceed`, `revise` | — |
| `publish`, `rounds` | `publish`, `address` | — |
| `findings` | `address` | `merge` (deferring open findings) |
| `merge` | — | every answer |
| `merge-refused` | — | every answer |
| `phase-failed` | `retry` | `takeover` |
| `unexpected` | only when the state is one of the other checkpoints under a name the table missed: that checkpoint's `**After**` and an allowed token; or the newest entry is a `restart` checkpoint (recipe (a)) | otherwise |

A host answer that repeats does not loop without the owner: after two
host `retry` answers in a row for the same phase, two host `revise`
answers at `plan` in a row, or two host `address` answers at `rounds` in
a row (each one a review round past the limit), that checkpoint's next
answer is the owner's.
Count the `**Decided-by**: host` checkpoints on the timeline, not from
memory, so a resumed session counts the same.

`stop` is open to the host at every checkpoint except `merge` and
`merge-refused`, where every answer, `stop` included, is the owner's; a
host `stop` is recorded `**Decided-by**: host (<reason>)` like any other
host answer. A host-answered checkpoint
never lets the host do a phase's work itself. A host answer that hits one
of the three kinds above goes to the owner instead.

## The outward boundary

Inside it, done by the host: the loop's own push and pull request, signed
comments on the issue being driven, progress entries, and limits it sets on
a read-only background run (listed as decisions). Everything else outward
goes to the owner: a new issue, a merge, an edit to his text that is not
drafted from his quoted words (recipe (c)), a message to another session, a
comment on another issue, deleting data or a branch this drive did not
create, anything a stranger could read as his word. A
standing authorization of his, recorded in the rules file with his words,
moves one class inside; the issue 398 comment is the first.

## Recipes

- **(a) Restart: he restates the goal mid-drive.** Wait for any running
  phase to return, then, in this order:
  1. Write a `## Checkpoint` with `**Decided-by**: owner`, `**After**:
     <the checkpoint pending, else unexpected>`, `**Decision**: restart`
     and his words verbatim.
  2. Post his words on the issue as a signed comment, from the issue's
     worktree, where the drive's other `gh` calls run, so `gh` targets the
     issue's own repository. `review-issue`, and `plan-task` after it,
     read the issue and its comments, never a `## Checkpoint` entry:
     without the comment the new work is reviewed and planned against the
     old goal. A comment, not an edit of the issue body: it adds his words
     without rewriting anyone's text, and a signed comment on the issue
     being driven is inside the outward boundary above.

     Run the block in "The restart comment" below. On a "not posted"
     line, dispatch nothing: the line goes into the hand-back, and the
     `restart` entry stays the newest, so the resumed drive takes the
     recovery path after step 3 and posts it then.
  3. Dispatch `review-issue` (`$WS_ROOT/.agent/scripts/dispatch_phase.sh
     --issue <N> --skill review-issue [--type <type>] [--project <project>]
     [--skill-prefix agent-workspace:]`, with this drive's own `--type`,
     `--project` and `--skill-prefix`, exactly as on its other dispatches:
     `/run-issue`, "This session's root" and "Skill names in this
     session"; without them `dispatch_phase.sh` takes `--type workspace`,
     and a project drive would review the workspace issue of the same
     number). Paste his words, quoted, into its handoff as well, like any
     direction of his ("Several issues at once"): `review-issue` reads the
     issue through git-bug first, whose copy may not have the comment yet.

  Its `## Issue Review` is then the newest entry and routes as usual. If
  the session ends before that entry is written, the `restart` checkpoint
  is the newest entry and `next` reports `unexpected`: the host does steps
  2 and 3 then, from the `restart` entry's words, without asking (the
  owner already decided it). That `unexpected` gets no second
  `## Checkpoint` entry, the one exception to run-issue step 6's "every
  checkpoint answer becomes an entry": the `restart` entry already records
  the decision, and its `**Decided-by**: owner` keeps it out of the
  host-answer repeat count. The restart also starts the pre-push review
  rounds over: `next` and the round-3 handoff count only reviews after it.
- **(b) Project names.** Settled; not re-asked. See the standing rules row
  on names: mechanism text names no project, record text may name a public
  one.
- **(c) His text.** Text stating his goals (README goals, the acceptance
  case, Direction lines, the roadmap's Paths) is drafted only from his
  quoted words and shown, with the quote, under "Decisions made (owner may
  veto)"; only his "no" changes it. It is a goal-meant question only when
  no quote of his covers it.
- **(d) Starting a drive.** Opening an issue and starting a drive are his: a
  go-ahead, or a sit-rep "Next" item he accepts. The hand-back's one
  question may propose the next drive; after a merge the host never starts
  one on its own.
- **(e) Merge.** Always his, after the decision summary (`/run-issue` steps
  7 and 11). Reviews reduce what he reads; they do not decide.

## The restart comment

Recipe (a) step 2, run from the issue's worktree. The comment's first line
is printed from `$MARK`, so it matches the check word for word and a second
run never posts the same restart twice. The block sits outside the recipe's
list, at the start of the line, because a heredoc's closing `EOF` must
start its line: indented inside a list item, it never closes and bash
stops on a syntax error before any "not posted" line.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
MARK="Goal restated by the owner mid-drive (restart checkpoint, <its **When**>):"
if ! COMMENTS="$(gh issue view <N> --json comments --jq '.comments[].body')"; then
    echo "not posted: gh issue view failed, so whether it is already there is unknown" >&2
elif grep -qF -- "$MARK" <<< "$COMMENTS"; then
    echo "already on the issue: $MARK"
else
mkdir -p "$WS_ROOT/.agent/scratchpad"
BODY="$(mktemp "$WS_ROOT/.agent/scratchpad/restart-goal.XXXXXX.md")"
{
printf '%s\n\n' "$MARK"
cat <<'EOF'
> <his words, verbatim, as in the restart entry>

The drive starts again at issue review, against this goal.

---
**Authored-By**: `<agent name>`
**Model**: `<model id>`
EOF
} > "$BODY"
if gh issue comment <N> --body-file "$BODY"; then
    rm -f "$BODY"
else
    echo "not posted: gh issue comment failed (exit $?); the text is kept at $BODY" >&2
fi
fi
```

## Hand-back shape

Every message that hands control back to him:

1. Two orientation lines: what the work is, in plain words (with the issue
   number and its label); what is needed from him, or "nothing".
2. What happened, a few short lines.
3. `Decisions made (owner may veto)`: the list, format in the rules file.
4. One line per outside reviewer: ran, failed or skipped, why, and whether
   it found anything of substance.
5. `Parked:` the items captured this turn, or nothing.
6. At most one question, the one whose answer changes the most.

Every issue or pull request number carries its label. A sub-agent's own
report shape is `dispatch_phase.sh`'s exit contract, not this list.

## Several issues at once

- One agent per worktree at a time: never dispatch into a worktree whose
  phase has not returned.
- His directions that arrive while a phase runs go to the running agent by
  `SendMessage`, quoted, and that agent records them in its entry; if it
  has returned, they go into the next handoff the same way.
- When two loops wait on him, raise the one on the acceptance path first,
  or both in one message with both orientations; a loop waiting on him
  never holds back another loop's next phase.

## Time box

When he names a stop time, start no phase that cannot finish before it
(issue review about 5 minutes, plan 5 to 8, plan review 4, implement 15 to
25, code review 5 to 10, triage 3). Never skip a launch silently: give the
estimate and ask start or hold. At the stop, say which phases are still
running; each loop stays at its last entry and resumes from there.

## Parked items

Anything he asks or decides while work runs that produces an action (a
follow-up issue, a design input, a rule to record) goes to the inbox the
moment it comes up, and onto the hand-back's `Parked:` line:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/capture.sh" "<the item in plain words>"
```

No other ledger. The sit-rep reads the inbox back.

## After each issue: the log on issue 398

Until the orchestrator design session, after each issue this skill drives
(merged, or stopped for good), post one signed comment on issue 398 (the
orchestrator design log), in the workspace repository even from a project
session. Four headings, each a few lines, plus the two counts:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
# The repository is the workspace checkout's own remote. With no user tier,
# WS_ROOT falls back to "." and in a project session that is the project:
# its remote is never the log's, so nothing is posted.
WS_REPO=""
if [ -f "$WS_ROOT/.agent/scripts/dispatch_phase.sh" ]; then
    WS_REPO="$(source "$WS_ROOT/.agent/scripts/_issue_helpers.sh" \
        && extract_gh_slug "$(git -C "$WS_ROOT" remote get-url origin 2>/dev/null)")"
fi
if [ -z "$WS_REPO" ]; then
    echo "not posted: $WS_ROOT is not the workspace checkout, or it has no GitHub remote" >&2
else
# The text goes to the workspace scratchpad (gitignored), not /tmp: a
# failed post keeps it there for the retry from a workspace session.
mkdir -p "$WS_ROOT/.agent/scratchpad"
BODY="$(mktemp "$WS_ROOT/.agent/scratchpad/orchestrator-log.XXXXXX.md")"
cat > "$BODY" <<'EOF'
<issue number and label>, <how it ended>.
Owner-level questions: <n>. Mechanism questions that reached him: <m>.

## What reached the owner, and why

## Decisions made, and any vetoes

## Where the decision-rights table was wrong or silent

## What the sit-rep or hand-back got wrong

---
**Authored-By**: `<agent name>`
**Model**: `<model id>`
EOF
if gh issue comment 398 -R "$WS_REPO" --body-file "$BODY"; then
    rm -f "$BODY"
else
    echo "not posted: gh issue comment failed (exit $?); the text is kept at $BODY" >&2
fi
fi
```

"not posted" goes into the hand-back as it is, with the comment's text,
so it can be posted from a workspace session; it is never retried against
another repository. When the post itself failed (authentication, network),
the text stays in the file the line names until that retry succeeds.

This is how anyone tells whether the skill helps; look again after the
acceptance-case run.

## End of session

- Every loop is left at its last entry; the hand-back says where each one
  resumes.
- The inbox lines captured this session are listed back to him.
- A rule or veto he gave is in the rules file (by pull request), not only
  in this session's memory.
- The status line is accurate: `DONE:` when nothing waits on him,
  `WAITING ON YOU:` with the one thing when something does.
