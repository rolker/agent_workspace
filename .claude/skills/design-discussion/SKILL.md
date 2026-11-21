---
name: design-discussion
description: A two-way conversation about whether an idea or a design in progress is a good one. Finds blind spots on both sides, researches alternatives, and helps the user decide to continue, prune, shelve, or just see it more clearly. Never implements.
session_scope: both
---

# Design discussion

> **Trial version.** Written after one session on an existing design. It stays a trial
> until two uses are recorded, one on a fresh idea and one on an existing design. The
> outcome of those uses, and whether to settle, revise or remove the skill, goes in a
> comment on the workspace issue that introduced it (#370). Revisit when both uses are
> done, or on 2026-12-31 if they are not, whichever comes first; at that point the skill
> is revised or removed, not left as a trial. A rule marked *untested* came from no
> observed failure and is here for the trial to test. A rule with a *Why* came from a
> failure seen in a real session; it can go when its reason does.

## Usage

```
/design-discussion <topic>
```

Use it when the user asks whether something is a good idea, asks for holes to be found,
or wants help deciding whether to keep going. Reach for it before the first
implementation issue of a new design, not only when doubts appear. It is a conversation.
It produces no code and no plan.

Run the conversation on the strongest model available. Send research and measurements to
cheaper agents.

## Where summaries live

Summaries are private working notes, kept in the workspace's git-ignored scratchpad, never
under a project's checkout. Resolve the folder at the head of each command chain (shell
state does not persist between tool calls):

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
if [ "$WS_ROOT" = . ]; then
  # No user tier on this machine: use the main checkout of the current repository,
  # so a summary written from a worktree survives the worktree's removal.
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  [ -n "$common" ] && WS_ROOT="$(dirname "$common")"
fi
DD_DIR="$WS_ROOT/.agent/scratchpad/design-discussions"
git -C "$WS_ROOT" check-ignore -q .agent/scratchpad/design-discussions/probe.md \
  && echo "dd_dir=$DD_DIR" || echo "dd_dir="
```

`~/.claude/agent-workspace-root` is written by the user-tier install
(`user_tier_install.sh`) and names the workspace's main checkout. Without it, the
fallback is the current repository's main checkout, which is the workspace only in a
workspace session.

If `dd_dir=` comes back empty, the folder is not git-ignored there (a project session on a
machine without the user tier, or no git repository at all). Then write no file: say so
once, keep the session's notes and the summary in the conversation only, and skip the
lookup of earlier sessions with a one-line note that it was skipped.

The scratchpad is working space, not a home for decisions. It stays on one machine and is
not tracked. A decision lives where the root keeps decisions (its design document,
roadmap or issues), and only the user moves it there, each move on its own yes.

## Steps

### 1. Prepare quietly

- **On resuming** a discussion (the user comes back to one, or an earlier session on this
  topic is found), the first output is the one-liner of the overall task, then progress
  against its plan, then only the context needed for the detail being resumed. *Why: a
  resumed session went straight into the detail, and the user had to ask for the context.*
- Look in `$DD_DIR` for earlier sessions on this topic (file names are
  `<date>-<plain-topic>.md`; also search their text for the topic's words). If there is
  one, say so before anything else.
- **Existing design:** read it and its history, and measure what exists: how much data,
  how much code, who uses it, how much effort has gone in. List where the design's
  decisions and evidence live: the main document, its decision record or change log,
  unmerged branches, issue comments, and working directories outside git. *Why: a
  conclusion that parked a branch also parked design corrections that existed only on
  that branch, and the evidence for the decided sections sat in an untracked directory.*
  **Fresh idea:** look at what the project already has that partly solves it, and at what
  others do.
- Write down the decisions and assumptions you can see, including your own assumptions
  about what the user wants. Keep them in the session file in `$DD_DIR` (created if
  absent), or in the conversation when there is no folder (see above). Step 5 checks them
  against the user's answers.
- Look facts up yourself. Ask the user only what they alone know.

### 2. Purpose before critique

Ask why the work was started, what must be true when it is done, who it is for, and what
kind of session this is: a fresh idea or an existing design, and whether the aim is to
clarify, to test, or to decide between continuing, pruning and shelving.

Give no verdict before these are answered. *Why: an agent judged a design before it knew
why the work had been started; the real reason came out four rounds in.*

### 3. Attack

- A few objections, ranked, each with evidence and each tied to a goal the user stated.
- Before showing an objection, write the strongest one-line reply to it and ask what
  happens if it is ignored. Drop the ones that lose. *Why: objections were oversold and
  only corrected when the user asked what would be lost.*
- Research alternatives. Say plainly where the research does not support them.

### 4. Defend

- **Existing design:** say what would be lost by changing course. Then go through the
  design's own decision list, item by item, and mark each one *kept*, *waits*, *changed* or
  *dropped*. *Why: "what do we lose" answered in features hid decisions that were quietly
  reversed.*
  **Fresh idea:** make the case for doing nothing and the case for the smallest version.
- Correct anything you oversold in step 3.

### 5. Rounds

- Take a position on each answer and say what would change it.
- After the user answers, say which of your written assumptions broke and whether your
  position moved.
- List your own assumptions and invite the user to attack them. The user can say
  "attack this", "defend this" or "switch sides" at any time.
- Questions. *Why: a first reply was a long report with seven questions.*
  - usually two to five in a turn; more than five means you have not chosen;
  - no question may depend on the answer to another one in the same turn;
  - keep to the recent part of the conversation; going back to an open item is fine if
    you say that is what you are doing;
  - no recommended answers on questions about purpose.
- Park a detail only when it does not block work at the level the discussion is at and
  can be solved later without significant redesign. Say both when parking it.
- Every few rounds, show a short list of what is still open. *(untested)*
- Before a conclusion counts, ask the user to state it in their own words. *Why: short
  assent ("sounds good") to the agent's framing accepted structures that were never
  stated as decisions.*
- Use the user's words. Give each thing a plain name the first time and keep to it.
  Define a term before leaning on it. Never use an issue or PR number as a name. *Why:
  the agent used names the user did not recognise, and numbers as names.*

### 6. Land

- Any of these is a valid ending: continue, prune, shelve, or clearer but undecided.
- **Existing design**, before the landing counts:
  - show the step 4 list with the *changed* and *dropped* items first;
  - check every new term in the conclusion against the existing decisions;
  - if the design says how it may be changed, follow that, or say plainly that the
    landing sets it aside;
  - name any settled work the conclusion strands, and where it is.

  "The existing design still stands" is not a landing statement on its own. *Why: a
  landing that said so left settled items unnamed, changed others without saying, and
  suspended a decision the design's own change rule protected.*
- Say where the conversation ended up, the one assumption the conclusion rests on, the
  cheapest test of that assumption, and what is still open.
- If the conclusion follows your own framing, say so.

### 7. Record

- Always keep a summary: `$DD_DIR/<date>-<plain-topic>.md`, or in the conversation when
  there is no folder (see "Where summaries live"). It holds the user's goals in their own
  words, what was agreed, what waits and what that costs, and what is open.
- Anything visible (an issue, a comment, an edit to a design document or roadmap) is
  optional and only on the user's say. Each next step is approved on its own.
- **On a "continue" landing**, offer to draft the session root's roadmap Direction line
  for the work, and the issues that line needs. The root is the workspace, or the project
  the session was started in; its roadmap is the one
  `"$WS_ROOT/.agent/scripts/sitrep_root.sh"` reports as `roadmap=` (`docs/roadmap.md`,
  else `ROADMAP.md`). A Direction line comes with a check that says whether it is true
  (the `| Line | Check |` table; the grammar is in that roadmap's Format notes and the
  header of `sitrep_checks.sh`). Show each draft in the conversation. Write the line,
  and file each issue, only on the user's yes to that item, through the root's usual
  route for changes. If the root has no roadmap or no Direction section, say so and offer
  the drafts as text only. Deriving a whole roadmap from a design is not part of this
  skill.
- **On a prune or shelve landing written somewhere visible**, offer a second pass by a
  fresh session (or a different model) that reads only the visible record and the
  design's decision record, and reports what the record does not account for. *Why: a
  fresh session, asked only whether the note was a useful redirect, found most of what
  the discussing session had missed in one read of the history.*
- Never start building.

## What this is not

- `brainstorm` lists options in one pass. This is a conversation that attacks and defends.
- `review-plan` and `review-issue` check a written plan or issue against the rules. This
  asks whether the thing should exist in its current form.
