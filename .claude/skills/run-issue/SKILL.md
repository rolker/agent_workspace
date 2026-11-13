---
name: run-issue
description: "Claude Code only — drives one GitHub issue through the full review loop (review-issue → plan-task → review-plan → implement → review-code → publish → triage-reviews → merge), dispatching each phase to a fresh sub-agent via the Agent tool and pausing at AskUserQuestion checkpoints. Depends on `.agent/scripts/dispatch_phase.sh` and the Agent tool, neither of which Codex/Gemini sessions can drive the same way."
argument-hint: "<issue-number | owner/repo#N> [--type workspace|project] [--layer <l> --package-repos <a,b>] [--base <branch>] [--resume]"
session_scope: both
---

# /run-issue

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

## This session's root

A session works only under the root it was launched in: the workspace
checkout, or a registered project root (ADR-0018 decision 6; `docs/design.md`,
"Sessions and roots"). An issue of another root is not driven from here; it
is driven by a session started in that root, and this session may open an
issue there (or add an inbox line) instead. Reading across roots is fine.

Check this **once, before step 1**:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/session_root.sh" [--type <type>]
```

Pass `--type` only when the user gave it. The script prints `root=`,
`type=` and `project=` for this session's root. If it exits non-zero,
**stop and report its message**: it names the directory to start a session
in for this issue, or says why this directory is no session's root. Do not
work around it with `cd`.

For the rest of the run, `<type>` below is the user's `--type`, or the
printed `type=` when none was given. When `<type>` is `project` and the
printed `project=` is not empty, pass `--project <project>` wherever this
skill passes `--type <type>` (start-task's arguments, every
`dispatch_phase.sh` call and `merge_pr.sh`), so every script resolves the
same project the check did.

## Skill names in this session

In a project session the workspace skills arrive through the
`agent-workspace` Claude Code plugin and are named
`/agent-workspace:<skill>`; the bare `/<skill>` there may be the project's
own skill of the same name (ADR-0018). In a workspace session they are
bare. Every dispatched task line must use the name *this* session has.
`--type` does not say which; the location does: the directory this
session was launched in, which is where it still is before step 1 (and the
session never leaves its root, above). Read it there, once, and keep the
value for the run. Never re-read it after step 1: inside a package
repository's checkout `skill_prefix.sh` and `session_root.sh` both refuse
(a session there does not read that root's local settings), and nothing
in the phase skills calls them.

Find out **once, before step 1**, by running:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/skill_prefix.sh"
```

It decides by location, not by anything this session has to copy or
interpret: `skill_prefix=` (bare) when the session is in the workspace
checkout's git repository (the checkout, a worktree of it, or a root like
`p11-jazzy` inside it), `skill_prefix=agent-workspace:` when it is in a
registered project root. The installer never enables the plugin in the
workspace, because the plugin's source is the workspace's own
`.claude/skills`: enabling it there would load every shipped skill twice.
Remember the printed value for the whole run and pass it on every handoff
call in step 4 as `--skill-prefix agent-workspace:` (omit the flag when it
printed empty). Where this skill's text names another workspace skill by
its bare slash command, invoke the prefixed form in a plugin session too.

If it exits non-zero (an unregistered location, or a repository nested in
a root, which the root's plugin does not reach), **stop and report its
message**.
Do not guess a prefix.

**The `|| echo .` fallback is required, not decoration.** The user tier is
optional — `--check` and ADR-0016 both say so — and on a machine without it
the file does not exist. A bare `cat` would leave `$WS_ROOT` empty and turn
every command below into `/.agent/scripts/...`, which is worse than the
relative path it replaced. With the fallback, `$WS_ROOT` is `.` and a
workspace session behaves exactly as it did before this idiom existed.

**An issue of a package repository requires the user tier.** Step 1 moves
the host into the owning repository's checkout, where `.` has no
`.agent/scripts`; and the session root of such an issue is a project root,
where `.` never had them. Capturing an absolute `$WS_ROOT` once before the
`cd` would not survive either, since shell state does not persist between
tool calls. So step 1 stops before anything is created when
`~/.claude/agent-workspace-root` is missing, which is the loudest failure:
one message naming the installer, rather than a missing-file error at
whichever call comes first.

Host orchestrator for one issue's review loop. `run-issue` itself never
implements, reviews, or writes code — it enters the worktree, asks
`$WS_ROOT/.agent/scripts/dispatch_phase.sh next` what happens next, dispatches that
phase to a fresh sub-agent, checks whether the phase kept its exit contract,
and pauses at `AskUserQuestion` checkpoints. The decision table lives in the
script, not here — see "Action tokens" below for where to read it.

## Usage

```
/run-issue <issue-number | owner/repo#N> [--type workspace|project]
           [--layer <l> --package-repos <a,b>] [--base <branch>] [--resume]
```

- `<issue-number>` — the GitHub issue driving the loop. Below, `<ref>` is
  the issue as given and `<N>` its number.
- `owner/repo#N` — an issue of a package repository in a multi-repository
  project (ADR-0012 package worktrees, `--type project`). One owning
  repository per run; sibling repositories in the worktree are there to
  build against, not to commit in.
- `--layer`, `--package-repos` — passed through to `/start-task` for a
  package issue whose worktree does not exist yet; without them creation
  refuses with `worktree_create.sh`'s own message. Re-entry needs neither.
- `--base <branch>` — a package issue only: the base branch of the owning
  repository's pull request, overriding the project's pin of that
  repository. Without it the base is the pin (`adapter repo_pin`, read by
  `dispatch_phase.sh base` in step 1, and by `worktree_create.sh` itself
  when it is given no `--base`), never the forge's default branch; a
  pin that is a tag, a commit or unknown stops step 1 and asks for
  `--base`. Once the worktree records a base, a different `--base` is
  refused.
- `--type` — `workspace` or `project`, exactly the value `/start-task` and
  `dispatch_phase.sh` take; default: the type of this session's root
  ("This session's root" above). It must name this session's root, or the
  run stops before step 1. Threaded to every `dispatch_phase.sh` call,
  `worktree_create.sh` at entry, `gh_create_pr.sh` targeting at publish,
  and `merge_pr.sh --type` at merge, with `--project` for a project root.
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
   → review-code <PR>  (post-push re-review; loop with address-findings)
   → triage-reviews → merge
```

Nine checkpoint kinds pause the loop along this path:
`issue-actions`, `plan`, `publish`, `rounds`, `findings`, `merge`,
`merge-refused`, `phase-failed`, `unexpected`. The owner answers through
`AskUserQuestion`, or the host answers within `/orchestrator`'s checkpoint
table (step 6, "No auto-chaining"). Every checkpoint answer is
recorded as a durable `## Checkpoint` entry on `progress.md` **before** the
next `dispatch_phase.sh next` call — the timeline alone is the state
machine, so `/run-issue <N>` on a half-done issue resumes from the newest
entry with no state anywhere else.

**One dispatch path.** Every phase — dispatched or inline — is handed off
the same way: `dispatch_phase.sh --issue <ref> --skill <phase> [--pr <M>]
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
outside it — issue #147). For a package issue, check the user tier first
("Workspace root" above), and stop if this prints anything:

```bash
test -s ~/.claude/agent-workspace-root || echo "stop: an issue of a package repository needs the user tier (the workspace's user_tier_install.sh)"
```

Next, the base branch of a package issue's pull request: the branch its
owning repository's `feature/issue-<N>` starts from and the pull request
targets (issue 429). Run it for every issue; it prints `base=<branch>` for
a package issue and nothing for any other, decided by the worktree `<ref>`
resolves to (a bare number can name a package worktree), or, before the
worktree exists, by `--layer`/`--package-repos`. It reads the project's
pin (or `--base`), refuses a pin that is not a branch, and, for a worktree
made before the base was recorded, records it in the manifest only after
checking, with one bounded fetch, that the owning branch started there: it
carries no commit beyond origin's `<base>` that another origin branch has
(a branch started from origin's default branch while the pin is another
branch is refused, naming the commits' count and branch; recreate the
worktree, or pass the `--base` it was started from). For an existing
worktree, `--layer` and `--package-repos` must match its manifest. Stop on a
refusal:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
B="$($WS_ROOT/.agent/scripts/dispatch_phase.sh base --issue <ref> --type <type> [--project <project>] [--layer <l> --package-repos <a,b>] [--base <branch>])" \
  || { echo "STOP: dispatch_phase.sh base refused (see above); do not continue"; exit 1; }
echo "${B:-no package base}"
```

Keep the branch after `base=` as `<base>` for the run (step 7 needs it); no
line means the issue has no package base.

Follow `$WS_ROOT/.claude/skills/start-task/SKILL.md` steps
1–4 with `--issue <ref> --type <type>` (and `--layer`, `--package-repos` when
given, with `--base <base>` beside them, so the owning branch starts from
origin's `<base>` and the manifest records it; never `--base` without
them, which only creation takes). Creation always resolves a base for the
owning branch (the `--base` given, else the pin; neither giving a branch
refuses), and an owning branch that already exists locally or on origin
gets `base=` only after the same check as above, else creation refuses and
rolls back. If step 1 there refuses (already in a
worktree), stop and tell the user to exit first.

Then move to the directory the issue's work and records happen in, which
`dispatch_phase.sh where` decides, the same answer every handoff gives a
phase as `worktree=`. The block stops when `where` refuses or prints
nothing, because `cd ""` succeeds silently and would leave the host where
it was:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
D="$($WS_ROOT/.agent/scripts/dispatch_phase.sh where --issue <ref> --type <type> [--project <project>])" \
  && [[ -n "$D" && -d "$D" ]] && cd "$D" && pwd \
  || { echo "STOP: dispatch_phase.sh where refused or printed nothing (see above); do not continue"; exit 1; }
```

For a workspace or single-repository issue that is the worktree
`/start-task` entered. For a package issue it is the checkout of the
owning repository inside the package worktree, not the worktree's top
folder, which is no repository of its own. `where` refuses when `gh` there
resolves another repository (a checkout with an `upstream` remote) and
names the `gh repo set-default` that fixes it; `where` also refuses when
`gh` fails or gives no answer. On `STOP`, stop and report it. From here on
the host's own commands run in that directory, `<dir>` below (the line the
block printed): the pull-request probe, `git push`,
`check_branch_updates.sh`, `gh_create_pr.sh`, `fetch_pr_reviews.sh`, and
`progress_append.sh` for checkpoints.

**`cd <dir> &&` at the head of every host command chain after step 1**,
the same rule `conventions=` gives every dispatched phase: the shell can
return to the session's start folder between tool calls, and a chain that
lost the `cd` runs `git push` or `gh_create_pr.sh` against whatever
repository it starts in. The blocks below leave it out for brevity; the
host adds it. The one exception is step 11, whose chain starts with `cd
<root> &&` instead.

**Identity, on every command chain.** `dispatch_phase.sh`'s handoff mode
hard-fails with exit 2 when `AGENT_NAME`/`AGENT_EMAIL` are unset — there is
no fallback to the human's git config. Shell state does not persist between
tool calls, so source the identity in the *same* chain as every
`dispatch_phase.sh` call (and every `progress_append.sh` / `git commit`),
not once at the start of the run. `--agent claude-code` derives the email
from the checkout's git email (`<local>+claude-code@<domain>`, issue #455);
no address is written into the command:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
source $WS_ROOT/.agent/scripts/set_git_identity_env.sh --agent claude-code "<model-id>" \
  && $WS_ROOT/.agent/scripts/dispatch_phase.sh --issue <ref> --skill <phase> [...]
```

### 2. Probe PR state

```bash
gh pr list --head "$(git branch --show-current)" --state all \
  --json number,state,isDraft,title
```

No result → `--pr none`. A result with `isDraft == true` → still `--pr
none` (a pre-existing `[PLAN]` draft the publish step below will take over
by `isDraft`, not by title — see step 8). Otherwise map GitHub `state`
(`OPEN`/`MERGED`/`CLOSED`) to `open`/`merged`/... — a closed-not-merged PR
is outside this loop's action-token vocabulary; stop and hand it to the
user. Keep the PR number `<M>` for every `--pr <M>` call below.

### 3. Ask `next` what happens next

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/dispatch_phase.sh next --issue <ref> --pr <none|draft|open|merged> [--type <type>]
```

Prints `action=<token>`, `reason=<one line>`, and, depending on the row:
`round=<n>`, `phase=<skill>`, `mode=inline`. Read the full contract and the
28-row decision table in the script's header comment and inline comments
(`$WS_ROOT/.agent/scripts/dispatch_phase.sh`) — this skill does not restate them.
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
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
D="$($WS_ROOT/.agent/scripts/dispatch_phase.sh where --issue <ref> --type <type> [--project <project>])" \
  && [[ -n "$D" && -d "$D" ]] \
  || { echo "STOP: dispatch_phase.sh where refused or printed nothing (see above); do not dispatch"; exit 1; }
PF="$D/.agent/work-plans/issue-<N>/progress.md"
BEFORE=0
[[ -f "$PF" ]] && BEFORE=$(python3 $WS_ROOT/.agent/scripts/progress_read.py "$PF" --type "<entry-type>" \
    | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["entries"]))')
echo "BEFORE=$BEFORE"
```

`PF` comes from `where`, never from the worktree's top folder: for a
package issue that folder holds no timeline, so a count there is always 0
while `--check-exit` counts the owning checkout's, and a second entry of
the same type would read as written when the phase wrote nothing. For
the same reason the block stops on `STOP` rather than going on with an
empty `D`: a path of `/.agent/...` would count 0 too.

`<entry-type>` is the **exact** string the handoff block's `entry_type=`
line printed for this dispatch — `Local Review (Pre-Push)`, not `Local
Review`. The two are distinct types in `skill_entry_type()` (branch-mode
vs. PR-mode `review-code`), and `--check-exit` counts the same exact type,
so a `$BEFORE` taken against the other one silently reports `MISSING` or a
false `OK`.

then:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/dispatch_phase.sh --issue <ref> --skill <phase> [--pr <M>] [--type <type>] [--skill-prefix agent-workspace:]
```

(`--skill-prefix` exactly as "Skill names in this session" decided.)
It prints the handoff block: `worktree=`, `package_worktree=` (a package
issue only), `task=`, `agent_name=`, `agent_email=` (the derived address
the identity line above exported), `model=`, `entry_type=`,
`exit_contract=`, `conventions=`.
Paste the task line, the worktree (and the package worktree, whose
`env.sh`, `build.sh` and `test.sh` the phase builds and tests with), the
exit contract, and the `conventions=` line (the `**When**` format,
scratch-file hygiene, and `cd <worktree> &&` at the head of every command
chain, which every dispatched phase must follow) into a fresh Agent tool call using the
printed `model=` as the model override. The dispatched phase
fetches its own inputs (issue/PR body via `gh`) — nothing is injected.

After the sub-agent returns, check the exit contract:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/dispatch_phase.sh --check-exit --issue <ref> --skill <phase> [--pr <M>] [--type <type>] --before "$BEFORE"
```

`status=OK` (with `sha=`) → continue to the next `next` call. `status=
PARTIAL|FAILED|MISSING` → this is always `checkpoint:phase-failed`, never a
silent retry: surface the phase, the outcome, and the last entry's text (or
"no entry written") in an `AskUserQuestion` offering re-dispatch, takeover,
or stop, then write the `## Checkpoint` entry (below) before calling `next`
again. A host running `/orchestrator` may answer `retry` or `stop` itself,
within that skill's limit on repeated host answers; `takeover` is always
the owner's answer.

**The dispatched implement pass.** `action=implement` has no `SKILL.md` of
its own — no `/implement` slash command exists, so `skill_task_line()`
prints a literal instruction ("implement the plan at
`$WS_ROOT/.agent/work-plans/issue-<N>/plan.md` on this branch") and the handoff's
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

**Hook rule for the dispatched implement and fix passes** (owner-decided
2026-10-20, issue #399). A workspace `implement` or `address-findings`
handoff's `conventions=` carries it; paste it verbatim. The pass sets
`SKIP=validate-script-tests` on its intermediate commits only (never
`--no-verify`). Before writing the entry it runs, once and with no SKIP,
the main checkout's venv pre-commit, which the rule prints by absolute
path because a worktree has no `.venv`:

```text
<main checkout>/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)
```

That run includes the script suites whenever a changed file that still
exists matches the hook, so they run once per pass, not once per commit:
the suites the branch's changed files reach, or every suite when the
branch deletes an in-scope file or touches a shared helper, the runner or
the hook config (issue #410). CI (`make lint`, every hook on all files,
awaited by `merge_pr.sh`) is the backstop, runs every suite, and covers a
branch that only deletes a script. Review phases and project handoffs carry no such rule.

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

This case uses `$WS_ROOT/.agent/scripts/progress_append.sh <N> --title "<issue
title>" <<'ENTRY'` (the script header documents the exact stdin/flag
contract).

### 6. Checkpoints are entries, written before the next call

Every checkpoint answer, the owner's `AskUserQuestion` outcome or the
host's own, becomes a `## Checkpoint` entry, appended via
`progress_append.sh` **before** the next `dispatch_phase.sh next` call —
this is a contract line, not a suggestion; `next` reads the timeline, not
the conversation.

```markdown
## Checkpoint
**Status**: complete
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <host agent> (<model>)
**Decided-by**: owner | host (<reason>)
**After**: <checkpoint name>
**Decision**: <token from the vocabulary below>
**Phase**: <skill>   <!-- only on an `After: phase-failed` entry -->

<the owner's answer text verbatim, or the host's reason and what it read>
```

`**After**` is one of the nine checkpoint names above (from
`checkpoint:<name>` in `action=`). `**Decision**` is the owner's answer,
constrained per `**After**` (`dispatch_phase.sh`'s header comment has the
full table; anything outside it routes `next` to row 28,
`checkpoint:unexpected`, on the *next* call — write within the vocabulary).
`**Phase**` is copied from the `phase=` line `next` printed with the
`checkpoint:phase-failed` action; omit it for every other `**After**`.
`**Decided-by**: owner` records that this entry captures the human's answer
to an `AskUserQuestion`, not a phase's own output. `**Decided-by**: host
(<reason>)` records that the host answered it itself, with a token
`/orchestrator`'s checkpoint table allows the host; nothing routes on this
field, it is the record a later reader checks the host against. One owner
answer outside the vocabulary is recorded by the host: `**Decision**:
restart`, when he restates the goal mid-drive (`/orchestrator`, recipe
(a)); it is followed by a signed comment carrying his words on the issue
(review-issue reads the issue, not this entry), posted only after the
host has shown him the exact comment and he has said yes, every time (on
a no nothing is posted and the host asks him how the restated goal should
reach the issue), and a `review-issue` dispatch with his words quoted in
its handoff, and in the `plan-task` handoff after it (both read a git-bug copy of the issue that
may not have the comment yet). If the
session ends before that dispatch writes its entry, `next` routes the
`restart` entry to row 28, `checkpoint:unexpected`, and the host checks
first whether the comment is already there; if not, shows him the comment
and posts it on his yes, and dispatches `review-issue` (recipe (a)) rather
than asking again whether to restart. When the check itself fails, nothing
is asked, posted or dispatched: the "not posted" line goes into the
hand-back and the `restart` entry stays the newest. Until a `## Checkpoint` with `**After**:
plan` and `**Decision**: proceed` follows the newest `restart` entry, the
host quotes that entry's words into every `review-issue`, `plan-task` and
`review-plan` handoff, on a resumed drive too: a session that ends after
the `## Issue Review` resumes at `plan-task`, a plan checkpoint answered
`revise` routes back to `plan-task` after the `## Plan Authored` entry,
and nothing else carries his words to either phase or to `review-plan`.

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
doesn't land: a merge attempt whose gate preconditions failed under
`--report-only` records `## Merge (report-only)` (or `## Merge (unreviewed)`
under `--force-unreviewed`) — written whether or not the merge itself then
succeeds — and while `--pr` is not `merged` that newest entry routes to
`checkpoint:merge-refused` (row 23); answering that `retriage` writes a
fresh `## Integrated Review`, and row 19 re-raises `checkpoint:findings` on
those same still-open boxes. The re-route only happens when a merge entry
was actually written, and two paths write none — the same caveat step 11
records. The gate's **default** refusal on a *workspace* PR (enforce, since
#300) exits 1 before any record, and a *passing* gate records nothing
either, so a run whose gate approved but whose merge then fails — CI,
mergeability, a review check-run still running, or `gh pr merge` — also
exits 1 with no entry. On both, there is no newest merge entry for
`dispatch_phase.sh` to route on and no `checkpoint:merge-refused` re-route;
the host surfaces the script's own error text at the merge checkpoint
instead. For each such box, run:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
D="$($WS_ROOT/.agent/scripts/dispatch_phase.sh where --issue <ref> --type <type> [--project <project>])" \
  && [[ -n "$D" && -d "$D" ]] \
  || { echo "STOP: dispatch_phase.sh where refused or printed nothing (see above); check no box"; exit 1; }
PF="$D/.agent/work-plans/issue-<N>/progress.md"
$WS_ROOT/.agent/scripts/review_progress.sh findings --progress "$PF"   # <i> comes from here
$WS_ROOT/.agent/scripts/review_progress.sh check --progress "$PF" --index <i> \
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

**Every dialog is self-contained.** Open every `AskUserQuestion` with:

```
<repo>#<N> (PR #M): <title> — phase X of Y (<phase>); <state>
```

embedding the finding text verbatim — never "the four findings above" or
"as triaged". A message ending a turn opens with the same header line when
the host drives `/run-issue` on its own; under `/orchestrator` it follows
that skill's hand-back shape instead, whose two orientation lines say what
the work is, with the issue number and its label, and what is needed from
him. Every Bash tool-call description opens with `<repo>#<N> <phase>:` so
the user can orient from the permission prompt alone.

**Dialog layout.** This shapes the `question` text of every
`AskUserQuestion`; a message ending a turn opens as the paragraph above
says. A dialog is never one dense string: real line breaks, and a blank
line between the header, the items and the question.

- Every `questions[i].question` opens with the header line above. The
  dialog shows one question at a time, so each one stands alone.
- Each finding or other item being decided is a bullet with a bold stable
  ID (`- **F1** ...`), never a numbered list, which the terminal renumbers.
  The verbatim text may wrap onto further lines; each item starts a new
  line, never two items on one line.
- F numbers count across the whole dialog and never restart: if the first
  question holds F1 to F3, the next one starts at F4. `Qn` names each
  question, one per `questions[]` entry, and opens its closing sentence, so
  a reply such as "F3 no, Q2 yes" has one meaning. A `Qn` is the question,
  not an item.
- Each `options[].description` says what that answer changes and how hard
  it is to undo. The recommended option comes first.

```
<repo>#<N> (PR #M): <title> — phase X of Y (<phase>); <state>

- **F1** <label>: <finding text, verbatim; may wrap onto further lines>
- **F2** <label>: <finding text, verbatim>

**Q1** <the one-sentence question>
```

A worked example, for a made-up repository: a two-question dialog after
a first code review. The first question:

```
acme-widgets#57 (PR #61): Retry failed uploads — phase 5 of 8 (review-code); round 1 found 4 issues (F4 in Q2)

- **F1** upload.py:88 (must-fix): "the retry loop never stops when the server answers 413"
- **F2** upload.py:121 (suggestion): "the backoff delay is not capped, so the tenth retry waits 17 minutes"
- **F3** tests/test_upload.py (suggestion): "no test covers a retry that succeeds on the second try"

**Q1** Fix F1 now and leave F2 and F3 for a later pull request?
```

Its options, recommended first: "Fix F1 now (recommended)": adds one fix
commit and a second review round, undone by reverting that commit; "Fix
F1, F2 and F3": the same plus two small changes, undone the same way;
"Publish as is": F1 ships, which fails on a 413 and needs a new pull
request to undo. The second question opens with the same header, its
pointer turned to Q1, and continues the numbering:

```
acme-widgets#57 (PR #61): Retry failed uploads — phase 5 of 8 (review-code); round 1 found 4 issues (F1 to F3 in Q1)

- **F4** README.md (out of scope): "the setup section still names the old upload endpoint"

**Q2** Open a separate issue for F4 rather than fix it in this pull request?
```

### 7. Publish

`action=publish` (`--pr none` only, row 16): push the branch, then create
the PR:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
git push -u origin "$(git branch --show-current)"
$WS_ROOT/.agent/scripts/gh_create_pr.sh [-R <owner/repo> --base <base>] --title "<title>" --body-stdin <<'EOF'
## Decision summary

<the pinned Decision summary from the last review-code / implementation>
EOF
```

Pass `-R <owner/repo>` (the repository part of `<ref>`) for a package
issue: `gh_create_pr.sh` otherwise refuses a repository that is neither the
workspace's nor the project's. Pass `--base <base>` too (step 1; every
handoff for a package issue also names it as `base=`): without it `gh`
targets the repository's default branch, which need not be the branch the
project pins and the feature branch started from. `merge_pr.sh` reports a
pull request whose base differs from the worktree's recorded one. A
workspace or single-repository issue passes neither.

**The heading must be exactly `## Decision summary`** — level 2, at the
top level of the PR body, never re-nested under a sub-agent's own heading
(`### Decision summary` inside a `## Review` section does not count).
`merge_pr.sh` greps that literal string when it checks gate condition (b)
(the `# (b) decision summary on the PR` block under `--- Step 1.5:
Review-loop merge gate ---`); a re-nested or reworded heading makes the gate
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
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/check_branch_updates.sh
```

If behind, merge main into the branch first, so the SHA `review-code`
reviews is the SHA that gets pushed — a merge-from-main after the review
would leave the review stale at the merge checkpoint.

### 9. Waiting for reviews

After publish, and after every PR-mode `## Local Review` (a re-review of a
fix, row 22a/22b), wait for the **review sources** to be in before
dispatching `triage-reviews`:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/fetch_pr_reviews.sh --pr <M>
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
that passed records no entry at all (`merge_pr.sh`'s
`if [[ "${#_gate_reasons[@]}" -eq 0 ]]` branch at the end of Step 1.5 —
it prints its approval and records nothing; the caveat step 11 repeats),
so a merge that then fails on CI leaves `next` with no
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
`action=merge` (row 21), `cd` to this session's root first: the `root=`
that `session_root.sh` printed before step 1. Inside the worktree, `git
rev-parse --show-toplevel` is the worktree itself (for a package issue, its
owning checkout), which the merge removes.

```bash
cd "<root>"
```

then run `$WS_ROOT/.agent/scripts/merge_pr.sh --pr <M> --type <type>`, or
`--pr <owner/repo#M>` for a package issue, so the script targets the
package repository and finds the package worktree. Until the merge gate
reads a package issue's timeline (the second pull request of issue 429),
its record for a package pull request says the worktree "carries no issue
timeline" and is posted as a pull-request comment; it stays report-only. The gate
enforces by default on workspace PRs (#300): a gap refuses with exit 1 and
no entry. Only the owner says skip — `--report-only` (record and proceed),
`--no-wait` (skip the CI wait) and `--allow-pending-review` (merge under a
review check-run that is still running) are passed only on the owner's
explicit answer for that merge, never on the host's judgment. If the merge
does not end merged *and* the run recorded a merge entry — a `--report-only`
run (or `--force-unreviewed`) records its own `## Merge (report-only)` /
`## Merge (unreviewed)` entry and can still fail later — the next `next`
call routes to `checkpoint:merge-refused` (row 23) — surface it and record
the owner's answer (`retriage`, `address`, or `stop`) as a `## Checkpoint`
entry the same way as any other checkpoint. The entry-less paths do not
re-route: the default (enforce) refusal on a *workspace* PR exits 1 with no
entry (on a project PR the gate falls through to the report-only branch),
and a gate that passed records nothing, so a later CI, mergeability,
pending-review, or `gh pr merge` failure leaves no entry either — surface
the script's error text and ask the owner at the merge checkpoint.
Bookkeeping-only commits after the reviewed head (progress.md, work plans,
roadmap) need no new review and no new CI wait: the gate and the CI target
both walk back over them.
`--pr merged` short-circuits
`next` to `action=done` before any worktree or progress resolution is
attempted (row 1) — the worktree may already be gone.

One precondition belongs to step 9, not here: if the latest `## Integrated
Review` recorded `**CI**: pending`, CI is re-checked *before* the merge
checkpoint is presented, and a CI failure is put to the owner at that
checkpoint and recorded as `**Decision**: address`, which routes to
`address-findings` — not dispatched directly, and never as a fresh
`triage-reviews` (the `merge` checkpoint's vocabulary has no `retriage`; a
re-triage need is answered `address` too). Do not let a pending-CI triage reach
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
`$WS_ROOT/.agent/scripts/dispatch_phase.sh`'s header comment and inline comments —
read there, not here. This skill's job is routing on the printed token
(dispatch per step 4 — `implement` included — inline per step 5 (a
takeover), publish
per step 7, merge per step 11, checkpoint per step 6, `done` ends the run
cleanly) — it does not re-derive or restate the table.

## No auto-chaining

Phases never dispatch each other. Each `next` call decides exactly one
step, and every checkpoint is written as an entry before the call that
moves past it (step 6).

The host may answer a checkpoint itself, with the tokens `/orchestrator`'s
table allows, written `Decided-by: host (<reason>)`. `merge` and
`merge-refused` always wait for the owner, and so do `takeover` at
`phase-failed` and `merge` at `findings`. A host-answered checkpoint never
lets the host do a phase's work itself. Without `/orchestrator` (or the
owner's standing rule for this drive), the host pauses at every checkpoint
for the owner's answer.

## One driver per issue

A second `run-issue` on the same issue, or a hand edit to `progress.md`
mid-run, is out of contract (ADR-0014). `--check-exit`'s entry-count
comparison is the only detection available, and it reports `MISSING` or an
unexpected type rather than guessing at what happened.

## Scope

What this loop deliberately does not cover, per the owner's own notes on
the plan for issue #276 and the plan for issue 429:

- **Field mode** (#208/#209) — the publish and merge steps here are
  GitHub-only; a non-GitHub publish path is a separate, later change to
  those two steps, not something this loop's design anticipates.
- **Where a project issue's records go under other records settings** —
  `--type project` runs end to end with the records in the repository the
  issue belongs to (the default setting). A records location outside the
  repository, or untracked records, is the records lookup of issue 393.
- **More than one owning repository per issue.** An ADR-0012 package
  issue (`owner/repo#N`) is driven in the checkout of the one repository
  that owns it; sibling repositories in the package worktree are for
  building against. The records gate (`records_path` in
  `_resolve_work_plans_dir.sh`) refuses them, and the worktree's top
  folder, for every records read and write a script makes:
  `progress_append.sh`, every `review_progress.sh` subcommand that takes
  a path (`findings` and `check` included), the resolver and
  `dispatch_phase.sh`. It does not guard a write from outside any
  worktree, which commits on that checkout's own branch. Composition stays
  the adapter's (ADR-0012): `run-issue` passes `--layer` and
  `--package-repos` through and reads only the worktree's
  `.worktree-repos` manifest, through `dispatch_phase.sh`.
