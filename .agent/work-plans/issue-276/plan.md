# Plan: Port run-issue from ros2_agent_workspace — in-process orchestrator over the #269 review loop

## Issue

https://github.com/rolker/agent_workspace/issues/276

## Context

The owner's need is workflow management: one host that drives an issue
through its phases and hands back decision summaries, so the human holds
decisions rather than context. Issue #269 (all six PRs merged 2026-09-17)
ported the phases' machinery: typed `progress.md` entries (ADR-0013),
`review_progress.sh` (round / verdict / persist / sources / findings /
check / plan-sha), `address-findings`, `triage-reviews` as integrator, and
the merge gate. Every phase now writes one typed entry and reads the ones
before it. What is missing is the driver that reads the newest entry and
dispatches the next phase.

The fork's `run-issue` (609 lines) plus `dispatch_subagent.sh` (647 lines)
is that driver. Roughly half of it exists only because phases once ran in
docker containers without GitHub auth: `--mode container`,
`docker_run_agent.sh`, the `--check` auth preflight and read-only token,
`--context-file` host-fetch-and-splice with its nonce fencing, the
"choosing a mode" section, and fork ADRs 0015/0019's container columns.
The owner's decision (2026-09-17, recorded in #276): auto mode replaced
containers; port **in-process only** and bring none of that. The fork's
own #607 already defaults to in-process under auto mode.

**Verified against this tree (2026-09-17; revision markers show what
each review round corrected):**
- Every phase the decision table names exists here: `plan-task`
  (`## Plan Authored`), `review-plan` (`## Plan Review`), `review-code`
  (branch mode writes `## Local Review (Pre-Push)` with
  `**Round**`/`**Ship**`), `triage-reviews` (`## Integrated Review`),
  `address-findings` (`## Implementation`). **Revision 2:** `review-issue`
  exists but writes only a GitHub issue comment (`review-issue/SKILL.md`
  step 7); it writes no `## Issue Review` entry although ADR-0013 names
  one. The table's first rows cannot fire until it does, so PR 1 (its
  own PR, revision 4) gives `review-issue` a persistence step.
- There is no `implement` skill here. The fork's run-issue (read directly
  from the scratchpad clone at `.agent/scratchpad/inspiration/
  ros2_agent_workspace`, SKILL.md lines 432-439: "there is no `implement`
  skill yet. After `## Plan Review`, the host runs implementation
  inline") runs implementation inline too; the workspace's older
  inspiration digest saying otherwise is stale. This port keeps
  implementation inline. **Revision 4:** the inline pass writes its own
  `## Implementation` entry (below), so the timeline never has a gap
  between `## Plan Review` and the first pre-push review.
- `review_progress.sh findings` already selects "the latest Integrated
  Review or Local Review (Pre-Push)"; `progress_read.py` emits
  `base_type`, `fields`, `correlation`, and `findings[].checked`.
  **Revision 5:** `**Ship**` is *not* a readable field — `review-code`
  writes it on the `**Round**` line (`review-code/SKILL.md:627`), so
  `fields` has only `Round` with the ship text embedded; `next` keys on
  `**Verdict**` alone, which is its own line. `review_progress.sh round`
  requires `--branch` and prints the *upcoming* round number; `next`
  counts completed pre-push entries itself (below). The decision table
  can be evaluated mechanically from that JSON.
- **Revision 4 (corrects revisions 2-3):** the merge gate (PR F,
  `merge_pr.sh` Step 1.5) did not flag a *pre-push* review on #273. The
  record (`.agent/work-plans/issue-265/progress.md:370-378`) says the
  latest post-PR `## Local Review` was at `6737065` while the head was
  `1b5ff2d`: a merge-from-main commit landed after the last review, and
  pre-push entries are a distinct type the gate never selects. Revision
  2's "gate accepts a pre-push review at the head" (former PR 0) rested
  on that misreading and would not have changed the #273 outcome. It is
  dropped. The real question (should a review at the tip survive a later
  merge-from-main?) is Open Question 5, with a recommendation that needs
  no gate change: in run-issue's own flow the entry the gate reads is
  always the `## Integrated Review` that `triage-reviews` writes at the
  PR head, and run-issue merges main *before* the final review rather
  than after it.
- `## Checkpoint` is a writable ADR-0013 type (`_progress_entry.sh`
  whitelist) whose required fields are set by whichever plan section
  defines the checkpoint; ADR-0013 describes it as human-written. Revision
  4 has run-issue record every `AskUserQuestion` outcome as a
  `## Checkpoint` entry on the owner's behalf (the owner decides, the
  host is the scribe); ADR-0013's row gains that one clause in PR 2.
- The Agent tool is available to the host session (Claude Code). A phase
  dispatched with it runs with the host's auto-mode permissions, so no
  permission prompts and no separate auth. That is the whole reason the
  container path can go.

## Approach

### 1. `run-issue` skill (host, never dispatched)

`.claude/skills/run-issue/SKILL.md`, ported from the fork with these
changes:

- **Enters the worktree first.** Before anything else (including
  `review-issue`), run-issue creates or enters the issue's worktree with
  `/start-task` semantics (`worktree_create.sh` if `find_worktree_by_issue`
  finds none, then `cd`). Every persistence step below resolves through
  `_resolve_work_plans_dir.sh`, which refuses outside the issue's
  worktree, so this ordering is what makes the first table row's entry
  land (revision 4, review finding 4).
- **One dispatch path.** "How phases are dispatched" shrinks to: build
  the handoff with `.agent/scripts/dispatch_phase.sh --issue <N> --skill
  <phase>` (below) and run it in a fresh-context sub-agent via the Agent
  tool. No `--mode`, no container prose, no `--context-file`, no auth
  preflight. Phases fetch their own issue/PR bodies with `gh` exactly as
  they do when run by hand.
- **Decision table** is code: the skill calls `dispatch_phase.sh next`
  (§2) each turn and routes on the printed `action=` token. The skill
  prose lists the tokens and what the host does for each; it does not
  restate the rules. The rows are in §2.
- **Checkpoints are entries.** Every `AskUserQuestion` outcome is
  recorded as a `## Checkpoint` entry (via `progress_append.sh`) with
  `**By**: <owner>`, `**Recorded-by**: run-issue (<host agent>)`,
  `**After**: <checkpoint name>` (one of the eight `checkpoint:` names
  in §2), `**Decision**: <token>` (from the per-checkpoint vocabulary in
  §2), and the owner's answer text. `**After**` and `**Decision**` are
  the fields `next` routes on; entry adjacency is never used (revision
  5). ADR-0013 lets each plan define its checkpoint's required fields,
  so no ADR edit is needed for `next` to read them. This is what makes the state machine total: the
  timeline alone says whether a checkpoint was passed, so `/run-issue
  <N>` on a half-done issue resumes from the newest entry with no state
  outside `progress.md` (revision 4, review finding 3). Checkpoints kept
  from the fork: after Issue Review with open actions; after Plan Review
  (always); before publish; after an Integrated Review with open
  findings; before merge; after any failed or partial phase; after three
  pre-push rounds. Every dialog opens with the re-orientation header
  `<repo>#<N> (PR #M): <title> — phase X of Y (<phase>); <state>` and
  embeds the finding text verbatim; every Bash description opens with
  `<repo>#<N> <phase>:` (the fork's rule and the owner's own).
- **Inline implementation writes `## Implementation`.** When `next` says
  `implement`, the host implements in the worktree and then appends
  `## Implementation` (`**Status**: complete|partial`, `**Branch**: <name>
  at <sha>`, `**Plan**: <path> at <plan-sha>` via `review_progress.sh
  plan-sha`, a short list of what changed). Same type `address-findings`
  writes; `next` tells them apart by the preceding entry.
- **Merge-from-main before the final review, not after.** Before each
  `review-code --branch` dispatch the host runs
  `check_branch_updates.sh`; if the branch is behind, it merges main
  first, so the reviewed SHA is the SHA that gets pushed. At the merge
  checkpoint, if `merge_pr.sh`'s gate reports "stale review" (main moved
  after `triage-reviews`), the host offers "re-run triage-reviews at the
  new head" rather than merging past the gate (Open Question 5, decided).
  A `merge` action whose script run does not end with the PR merged (an
  `--enforce` refusal writes no entry and exits 1; a report-only run can
  record its entry and still fail later, #284) is always followed by a
  `checkpoint:merge-refused` and its `## Checkpoint` entry, so the table
  never re-emits `merge` on the same state (revision 5).
- **Publish step**: GitHub only (no field mode — #208/#209 are separate);
  `gh pr create` via `gh_create_pr.sh` with the pinned Decision summary
  in the body (the gate's condition (b)). PR state is not inferred from
  the timeline: the host reads it with `gh pr list --head <branch>
  --state all --json number,state,isDraft` and passes it to `next` as
  `--pr <state>`; an open non-`[PLAN]` PR means already published.
- **Waiting for reviews**: after publish the host waits for CI and bot
  reviews to settle (`fetch_pr_reviews.sh` shows no pending checks) before
  dispatching `triage-reviews`; `triage-reviews` with only the local
  pre-push review as a source still writes its `## Integrated Review`,
  which is the entry the merge gate reads.
- **No auto-chaining** (Scope E) kept: phases never dispatch each other.
- **Dropped**: the container mode and everything listed in Context; the
  Copilot opt-in paragraph (no Copilot specialist here); field-mode
  branch; `--context-file`.

### 2. `dispatch_phase.sh` (new script, replaces `dispatch_subagent.sh`)

`.agent/scripts/dispatch_phase.sh --issue <N> --skill <phase>
[--prompt-file <f>] [--entry-type <T>] [--model <alias>]`:

- **Worktree lookup vs refusal** (revision 4, review finding 5): the
  script locates issue N's worktree with `find_worktree_by_issue`
  (`_worktree_helpers.sh`) and fails with exit 2 if there is none;
  `_resolve_work_plans_dir.sh` is not a locator and is used only where
  something is written (persistence steps inside the phases, the host's
  own `## Checkpoint` / `## Implementation` appends), where its
  refuse-outside-the-worktree rule (#147) is the point.
- Expected entry type from a skill→entry-type table (`review-issue` →
  Issue Review, `plan-task` → Plan Authored, `review-plan` → Plan Review,
  `review-code` → Local Review (Pre-Push), `triage-reviews` → Integrated
  Review, `address-findings` → Implementation).
- Prints the **handoff block** to stdout: the task line ("run
  `/<skill>` for issue #N in worktree <path>"), the commit-identity
  literals (`AGENT_NAME`/`AGENT_EMAIL` from `set_git_identity_env.sh`, no
  fallback to the human config), the model to stamp in `**By**`, and the
  exit contract (append the expected entry; `**Status**: partial|failed`
  if you cannot finish; never push). The host pastes it into the Agent
  tool. This is the fork's contract minus the container clauses and
  minus the untrusted-context fence (no injected body: the phase fetches
  its own).
- **Exit-contract check**: `--check-exit --issue <N> --skill <phase>
  --before <count>` compares the entry count of the expected type before
  and after the dispatch (via `progress_read.py`) and reports `OK <sha>`,
  `PARTIAL`, `FAILED`, or `MISSING` so the host never assumes an outcome.
- **Per-phase model table** (revision 3, owner decision): `review-plan`,
  `review-code`, `triage-reviews`, `address-findings`, and the inline
  implementation pass → `opus`; `review-issue`, `plan-task` → `sonnet`;
  `--model <alias>` overrides per dispatch. Aliases only. This is the
  fork's tier; the owner confirmed usage headroom for it on 2026-09-17.
  It is scoped to this loop and is not a new default for other work
  (review finding 8).
- **Failed or partial phases** (revision 2): `--check-exit` reporting
  `PARTIAL`, `FAILED`, or `MISSING` is always a checkpoint, never a
  silent retry. The host surfaces the phase, the outcome, and the last
  entry's text (or "no entry written") and offers: re-dispatch the same
  phase, take over inline, or stop. The fork's guideline "surface, don't
  swallow" becomes a table row, not prose.
- **Resume** (revision 2, made real in revision 4): every invocation
  re-derives the next action from the newest entry; checkpoints and the
  inline implementation both leave entries, so nothing lives outside
  `progress.md`.
- **One driver per issue** (revision 2): a stated convention, recorded in
  ADR-0014 — a second `run-issue` on the same issue, or hand edits to
  `progress.md` mid-run, are out of contract; `--check-exit`'s
  entry-count comparison is the only detection and it reports
  `MISSING`/unexpected type rather than guessing.
- **Claude Code only** (revision 2): run-issue depends on the Agent tool
  and `AskUserQuestion`; its description says so, exactly as
  `start-task` does. Codex/Gemini sessions keep driving phases by hand.

#### `dispatch_phase.sh next` — the contract (revision 4, pinned; revision 5 made total)

```
dispatch_phase.sh next --issue <N> --pr <none|draft|open|merged> [--progress <file>]
```

- **Inputs.** `--pr` is required and is the only non-timeline input; the
  host reads it from `gh`, tests pass it. `--progress <file>` feeds a
  fixture timeline; without it the script resolves
  `<worktree>/.agent/work-plans/issue-<N>/progress.md` via
  `find_worktree_by_issue`. A progress file that does not exist yet is an
  **empty timeline** (the first phases create it; `triage-reviews`
  already treats it so); exit 2 is only for a `--progress` path the
  caller named that is missing, or no worktree for `--issue`. No `gh`
  call inside `next`, ever.
- **Output.** Exactly these lines on stdout, in this order:
  `action=<token>`, `reason=<one line>`, then `round=<n>` when the
  action concerns the pre-push loop, and `mode=inline` when a phase is to
  be run by the host itself rather than dispatched. Nothing else.
- **Exit codes.** 0 = action decided; 2 = usage; 3 = malformed timeline
  (`progress_read.py` exit 2 propagated, its message on stderr).
- **Routing keys.** The newest entry `E` (its `base_type`, `fields`,
  `findings[]`), `--pr`, and for `## Checkpoint` entries their
  `**After**` and `**Decision**` fields. Adjacency to the entry before
  `E` is never consulted (revision 5, review finding 9). `round` is the
  count of `## Local Review (Pre-Push)` entries whose
  `correlation.branch` equals the newest such entry's branch (hermetic
  under `--progress`; `MAX_ROUNDS=3` compares against this count of
  *completed* rounds, so the third `needs-work` review surfaces).
  "Open" means an unchecked `findings[]` box. "`## Local Review`" below
  means that exact `base_type`; the pre-push type is always written out.
- **Tokens.** `review-issue`, `plan-task`, `review-plan`, `implement`,
  `review-code`, `address-findings`, `publish`, `triage-reviews`,
  `merge`, `done`, and `checkpoint:<name>` for name in `issue-actions`,
  `plan`, `publish`, `rounds`, `findings`, `merge`, `merge-refused`,
  `phase-failed`, `unexpected`. One token per row; a checkpoint row never
  bundles the following action.
- **Checkpoint decision vocabulary** (what the host may write in
  `**Decision**`, per `**After**`; anything else is a malformed entry,
  exit 3):

| `**After**` | Allowed `**Decision**` |
|---|---|
| `issue-actions` | `proceed`, `stop` (the owner's answers to the actions are the entry text; `plan-task` reads them) |
| `plan` | `proceed`, `revise`, `stop` |
| `publish`, `rounds` | `publish`, `address`, `stop` |
| `findings`, `merge` | `merge`, `address`, `stop` |
| `merge-refused` | `retriage`, `address`, `stop` |
| `phase-failed` | `retry`, `takeover`, `stop`; plus `**Phase**: <skill>` naming the failed phase |
| `unexpected` | `stop` only — run-issue ends and tells the human how to continue by hand |

- **Rows** (first match wins; the early rows exist so that `merged`,
  `stop` and failures can never be intercepted — review finding 7):

| # | Condition | `action=` |
|---|---|---|
| 1 | `--pr merged` | `done` |
| 2 | `E` is `## Checkpoint` with `**Decision**: stop` | `done` |
| 3 | `E` has `**Status**: partial` or `failed` | `checkpoint:phase-failed` |
| 4 | no entries (including no file) | `review-issue` |
| 5 | `E` is `## Issue Review`, open boxes | `checkpoint:issue-actions` |
| 6 | `E` is `## Issue Review`, none open | `plan-task` |
| 7 | Checkpoint `issue-actions` / `proceed` | `plan-task` |
| 8 | `E` is `## Plan Authored` | `review-plan` |
| 9 | `E` is `## Plan Review` (any verdict) | `checkpoint:plan` |
| 10 | Checkpoint `plan` / `proceed` | `implement` (+ `mode=inline`) |
| 11 | Checkpoint `plan` / `revise` | `plan-task` |
| 12 | `E` is `## Implementation` | `review-code` (`--branch` when `--pr none`, PR mode otherwise) |
| 13 | `E` is `## Local Review (Pre-Push)`, `**Verdict**: approved` | `checkpoint:publish` |
| 14 | `E` is `## Local Review (Pre-Push)`, not approved, `round` ≥ `MAX_ROUNDS` | `checkpoint:rounds` (+ `round=`) |
| 15 | `E` is `## Local Review (Pre-Push)`, not approved | `address-findings` (+ `round=`) |
| 16 | Checkpoint `publish` or `rounds` / `publish`, `--pr none` | `publish` |
| 17 | Checkpoint `publish` or `rounds` / `publish`, `--pr draft` or `open` | `triage-reviews` |
| 18 | Checkpoint `publish` or `rounds` / `address` | `address-findings` |
| 19 | `E` is `## Integrated Review` or `## Local Review`, open boxes | `checkpoint:findings` |
| 20 | `E` is `## Integrated Review` or `## Local Review`, none open | `checkpoint:merge` |
| 21 | Checkpoint `findings` or `merge` / `merge` | `merge` |
| 22 | Checkpoint `findings` or `merge` / `address` | `address-findings` |
| 23 | `E` is `## Merge (report-only)` or `## Merge (unreviewed)` (and, by row 1, the PR is not merged) | `checkpoint:merge-refused` |
| 24 | Checkpoint `merge-refused` / `retriage` | `triage-reviews` |
| 25 | Checkpoint `merge-refused` / `address` | `address-findings` |
| 26 | Checkpoint `phase-failed` / `retry` | the skill token from `**Phase**` (`implement` + `mode=inline` when the phase was the inline pass) |
| 27 | Checkpoint `phase-failed` / `takeover` | the skill token from `**Phase**` + `mode=inline` |
| 28 | anything else (e.g. `## External Review`, a Checkpoint whose `**After**` no row names) | `checkpoint:unexpected` |

  Totality argument the test encodes: every entry type ADR-0013 lists
  has a row (`External Review` deliberately lands on 28); every
  `checkpoint:` name × allowed decision has a row (`stop` by row 2); a
  `merge` action that does not end merged always produces a new entry
  (row 23 or the host's `merge-refused` checkpoint after an `--enforce`
  refusal, which writes no entry itself), so no row can re-emit the same
  action on the same timeline. `test_dispatch_phase.sh` has one fixture
  per row plus three end-to-end timelines (clean run to merge;
  needs-work plan then revise; three pre-push rounds then stop) that must
  never hit row 28.

### 3. `review-issue` persistence (revision 4, review finding 4)

`review-issue/SKILL.md` gains step 8, the same shape PR E gave
`review-plan`: the posted comment **is** the entry. The entry is
`## Issue Review` with the ADR-0013 header (`**Status**`, `**When**`,
`**By**`), `**Issue**: #<N>`, then the comment body verbatim minus the
signature, then a `### Actions` section whose checkboxes are, in this
order: every **Principle Alignment** row whose status is `Action needed`
(one box per row, text = the row's Notes), then every **Recommendations**
bullet (one box each). No other section becomes a checkbox. Persisted via
`review_progress.sh persist --issue <N> --strict --soft`; run by hand
outside a worktree, `--soft` prints the notice and writes nothing, as
`review-plan` does today. Under run-issue the worktree always exists
first (§1), so the entry always lands.

### 4. Merge gate: unchanged

`merge_pr.sh` is not touched. In run-issue's flow the entry the gate's
condition (a) reads is the `## Integrated Review` that `triage-reviews`
writes at the PR head, and the merge-from-main rule in §1 keeps the head
at the reviewed SHA. Whether the gate should *also* accept an older
review across a merge-from-main is Open Question 5.

### 5. Handoff ADR

`docs/decisions/0014-in-process-phase-handoff.md`: the phase handoff
contract as it stands without containers — what the host provides (task,
identity, model, exit contract, worktree), what the phase promises (one
typed entry, no push, no chaining), what the host checks (entry count by
type), why in-process is the only mode (auto mode; ADR-0004 layer:
convention plus a mechanical exit check, no server-side enforcement), the
**one-driver-per-issue** convention and what breaks it, and the
**per-phase model tier** with its rationale (review phases and
implementation carry the judgment and get Opus; issue review and planning
are cheaper and get Sonnet; scoped to this loop, overridable per
dispatch). Cites fork ADR-0015/0019 as sources and states what was
declined. It also records, in its Decision, that `run-issue` writes
`## Checkpoint` entries on the owner's behalf from `AskUserQuestion`
answers with `**Recorded-by**`, `**After**`, `**Decision**`. **ADR-0013**
is not reworded (ADR-0008 forbids softening an accepted Decision inline):
it gets the permitted Status-line note "Scoped exception in ADR-0014:
checkpoint entries recorded by run-issue" and a References line, in the
same PR as ADR-0014 (revision 5, review finding 5).

### 6. Knowledge note

`.agent/knowledge/review_loop_lifecycle.md`: one page — the phase order,
which skill writes which entry, what run-issue reads to move on, and
where the human checkpoints are. Replaces the need to read six SKILL.md
files to understand the loop.

## Files to Change

| File | Change | PR |
|------|--------|----|
| `.claude/skills/review-issue/SKILL.md` | Step 8: `## Issue Review` entry via `review_progress.sh persist --strict --soft`; `### Actions` checkboxes from Action-needed rows + Recommendations | 1 |
| `.agent/scripts/tests/test_issue_review_entry.sh` (new) | A fixture comment persisted per step 8 parses with `correlation.kind == "issue"` and exactly the Action-needed rows + Recommendations as `findings[]` | 1 |
| `.agent/scripts/dispatch_phase.sh` (new) | Handoff block emitter, skill→entry-type and skill→model tables, `--check-exit`, `next` per the contract above | 2 |
| `.agent/scripts/tests/test_dispatch_phase.sh` (new) | Hermetic: handoff content (identity literals, model, exit contract, worktree); exit 2 when no worktree; exit check OK/PARTIAL/FAILED/MISSING; one fixture per `next` row (28) plus three end-to-end timelines; missing file = empty timeline; `round=` count and `MAX_ROUNDS`; `--pr` branches; exit 3 on a malformed fixture or an out-of-vocabulary `**Decision**` | 2 |
| `docs/decisions/0013-progress-md-entry-type-vocabulary.md` | Status-line scoped-exception note + References line pointing at ADR-0014 (ADR-0008 permitted form; Decision text untouched) | 3 |
| `.claude/skills/run-issue/SKILL.md` (new) | Host orchestrator: worktree entry, `next` routing, checkpoint entries, inline `## Implementation`, merge-from-main rule, publish, wait-for-reviews; in-process only | 3 |
| `docs/decisions/0014-in-process-phase-handoff.md` (new) | Handoff contract ADR incl. one-driver convention, model tier, and the run-issue-recorded checkpoint rule | 3 |
| `.agent/knowledge/review_loop_lifecycle.md` (new) | Lifecycle one-pager | 3 |
| `.agent/knowledge/principles_review_guide.md` | ADR-0014 row; consequences row (entry types ↔ `dispatch_phase.sh next`) | 3 |
| `.agent/AGENT_ONBOARDING.md` | Skill list gains `run-issue` | 3 |
| `AGENTS.md` | Script Reference row for `dispatch_phase.sh` (standing rule 2 on #269 covers script rows) | 3 |
| `ARCHITECTURE.md` | One paragraph: the lifecycle and its driver | 3 |

Not touched: `merge_pr.sh` (revision 4), `dispatch_subagent.sh`,
`docker_run_agent.sh`, container docs — never ported. `review-code` /
`triage-reviews` / `address-findings` already print their next command;
run-issue reads entries, not prompts.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Nine checkpoint kinds; nothing publishes or merges without `AskUserQuestion`; each answer is a durable `## Checkpoint` entry; every dialog self-contained (owner's own rule) |
| Enforcement over documentation | The decision table is code (`dispatch_phase.sh next`) with a fixture test per row and a pinned stdout/exit contract; the exit contract is checked mechanically; the skill prose routes on script output |
| Capture decisions, not just implementations | ADR-0014 records the no-container decision, the handoff contract, the one-driver rule and the model tier; checkpoint entries record the owner's per-issue decisions |
| Only what's needed | Container path, field mode, Copilot opt-in, context injection, and the gate widening all declined; no `implement` skill invented |
| Improve incrementally | Four PRs; each is one thing; the loop is usable by hand after PR 2 and unattended after PR 3 |
| Test what breaks | Decision table rows, exit check, worktree lookup failure, handoff literals, the review-issue entry shape — all fixture-tested; the skill prose is thin over them |
| Workspace serves the product | Pure workspace infra, but it is the thing the owner asked for to manage project work with less context load |

## ADR Compliance

| ADR | Requirement | This plan |
|---|---|---|
| 0002 worktree isolation | Phases work in the issue's worktree only | run-issue enters the worktree first; handoff names it; every write goes through `_resolve_work_plans_dir.sh` |
| 0004 enforcement hierarchy | Say which layer a rule sits at | Exit contract = convention + mechanical count check (fast local layer); no server layer, stated in ADR-0014 |
| 0009 python packaging | No new deps | Bash + `progress_read.py` only |
| 0008 ADR amendments | Substantive changes supersede; Status notes permitted | ADR-0013's Decision text is untouched; it gets a Status-line scoped-exception note pointing at ADR-0014, which carries the new rule |
| 0013 entry vocabulary | Only canonical types; a checkpoint's required fields come from the plan that defines it | run-issue writes `## Checkpoint` (fields defined in §1) and `## Implementation`, both canonical |

## Consequences

| If you change... | Also update... |
|---|---|
| A phase's entry type or verdict field | `dispatch_phase.sh` tables + `next`, its test, ADR-0013's table, the lifecycle note |
| The decision table (`next` rows or tokens) | `test_dispatch_phase.sh` row cases, run-issue SKILL.md's token list, the lifecycle note |
| The handoff contract | ADR-0014, `dispatch_phase.sh`, the test's literal assertions |
| review-issue's comment sections | Step 8's checkbox sources, `test_issue_review_entry.sh` |
| `merge_pr.sh`'s gate records or its enforce behaviour (what it writes, when it exits 1) | `next` rows 21-25 and their fixtures; the skill's merge-refused checkpoint text |
| `review-code`'s `**Round**`/`**Verdict**` lines | `next` rows 13-15, `round` counting, their fixtures |

## Open Questions

1. **Model tier per phase — decided (owner, 2026-09-17).** Usage has
   headroom, so the fork's tier is adopted: `review-plan`, `review-code`,
   `triage-reviews`, `address-findings`, and inline implementation on
   Opus; `review-issue` and `plan-task` on Sonnet; `--model` overrides per
   dispatch. The host session itself stays on whatever the owner runs.
2. **Implementation phase inline (decided, flag if you disagree).** Kept
   inline in the host, matching the fork today; it writes its own
   `## Implementation` entry. A dispatched `implement` skill would be a
   follow-up issue and needs no new table row.
3. **Three-round surface — decided.** A constant (`MAX_ROUNDS=3`) in
   `dispatch_phase.sh`, not a flag: it is the same three-round rule the
   owner set on #269, it is only a point where the human is asked (never
   a hard stop), and a knob nobody tunes is surface area.
4. **Where run-issue runs from — not an owner question.** The skill
   enters the issue's worktree itself (`/start-task` semantics) before
   anything else, so it works from wherever the session started.
5. **Should a review at the branch tip still count after a
   merge-from-main lands on the PR head? — decided (owner, 2026-09-17):
   no, a merge from main gets a new review.** Revisions 2-3 said the
   owner had agreed to widen the gate for pre-push reviews; that rested
   on a misreading of the #273 gate run (Context) and is withdrawn.
   Adopted as recommended: **no gate change.** A
   merge-from-main can change behaviour (main's changes plus the
   branch's, together, were never reviewed), so the gate is right to
   call it stale. run-issue avoids the situation by merging main *before*
   the final review, and offers a cheap `triage-reviews` re-run at the
   merge checkpoint when main moved afterwards.

## Estimated Scope

Four PRs, each independently mergeable, each through the review loop
(revision 4 re-split per review finding 6; revision 5 moved the ADR-0013
note to PR 3):

- **PR 1 — `review-issue` writes `## Issue Review`** (SKILL.md step 8 +
  `test_issue_review_entry.sh`). Small, an ADR-0013 conformance gap open
  since #269, independently motivated; `next`'s first rows depend on it.
- **PR 2 — the dispatcher** (`dispatch_phase.sh` + `test_dispatch_phase.sh`).
  One script and its test; the largest PR, ~700 lines.
- **PR 3 — the skill + ADR-0014 + docs** (`run-issue/SKILL.md`,
  ADR-0014, the ADR-0013 Status note, lifecycle note, onboarding,
  AGENTS.md row, ARCHITECTURE paragraph, principles guide rows). Prose
  over PR 2's mechanics.
- **PR 4 — live exercise**: drive one small real issue end to end with
  `/run-issue`, record the checkpoints hit and the entries written as a
  note on #276, fix what it surfaces. Its merge is the owner's call; it
  is the first time the loop runs unattended between checkpoints.

Blast radius: no existing script changes behaviour. `review-issue` gains
a `--soft` persistence step (a notice when run outside a worktree, as
`review-plan` already does); ADR-0013 gains a Status-line note;
everything else is new files.
