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

**Verified against this tree (2026-09-17; revision 2 corrections
marked):**
- Every phase the decision table names exists here: `plan-task`
  (`## Plan Authored`), `review-plan` (`## Plan Review`), `review-code`
  (branch mode writes `## Local Review (Pre-Push)` with
  `**Round**`/`**Ship**`), `triage-reviews` (`## Integrated Review`),
  `address-findings` (`## Implementation`). **Revision 2:** `review-issue`
  exists but writes only a GitHub issue comment (`review-issue/SKILL.md`
  step 7); it writes no `## Issue Review` entry although ADR-0013 names
  one. The table's first two rows cannot fire until it does, so PR 1
  gives `review-issue` a persistence step through `review_progress.sh
  persist` (same pattern as PR E gave `review-plan`, `--soft`), writing
  `## Issue Review` with `**Issue**: #<N>` and the open-question actions
  as checkboxes.
- There is no `implement` skill here. The fork's run-issue (read directly
  from the scratchpad clone at `.agent/scratchpad/inspiration/
  ros2_agent_workspace`, SKILL.md lines 432-439: "there is no `implement`
  skill yet. After `## Plan Review`, the host runs implementation
  inline") runs implementation inline too; the workspace's older
  inspiration digest saying otherwise is stale. This port keeps
  implementation inline and adds the table row for a dispatched
  `implement` only when such a skill exists.
- `review_progress.sh findings` already selects "the latest Integrated
  Review or Local Review (Pre-Push)"; `progress_read.py` emits
  `base_type`, `fields` (e.g. `Verdict`, `Ship`), `correlation`, and
  `findings[].checked`. The decision table can be evaluated mechanically
  from that JSON.
- `merge_pr.sh`'s gate (PR F) is report-only and reads only post-PR
  `## Local Review` / `## Integrated Review`; the first live run flagged a
  pre-push review at the head as "stale" (#269 comment). run-issue's
  pre-push loop produces exactly that shape, so this plan includes the
  gate accepting a `## Local Review (Pre-Push)` at the head (owner said
  to fold this in, 2026-09-17).
- The Agent tool is available to the host session (Claude Code). A phase
  dispatched with it runs with the host's auto-mode permissions, so no
  permission prompts and no separate auth. That is the whole reason the
  container path can go.

## Approach

### 1. `run-issue` skill (host, never dispatched)

`.claude/skills/run-issue/SKILL.md`, ported from the fork with these
changes:

- **One dispatch path.** "How phases are dispatched" shrinks to: build
  the handoff with `.agent/scripts/dispatch_phase.sh --issue <N> --skill
  <phase>` (below) and run it in a fresh-context sub-agent via the Agent
  tool. No `--mode`, no container prose, no `--context-file`, no auth
  preflight. Phases fetch their own issue/PR bodies with `gh` exactly as
  they do when run by hand.
- **Decision table** kept verbatim in semantics, re-keyed on this
  workspace's entries. Rows: none → `review-issue`; `## Issue Review`
  (open questions) → checkpoint then `plan-task`; `## Plan Authored` →
  `review-plan`; `## Plan Review` → checkpoint (always), then inline
  implementation, then `review-code --branch`; `## Local Review
  (Pre-Push)` approved → publish checkpoint; changes-requested →
  `address-findings` then `review-code --branch`; PR published →
  `triage-reviews` after review comments land (async wait checkpoint);
  `## Integrated Review` open findings → checkpoint then
  `address-findings`; none → merge checkpoint (`make merge-pr`); bare
  `## Local Review` (someone ran post-PR review-code by hand) routed like
  Integrated Review; `## Implementation` preceded by a review entry →
  `review-code` re-review. Route on `**Ship**`: `recommended` ends the
  pre-push loop; after three rounds surface the loop state regardless
  (the same three-round rule the owner set as a standing rule on #269).
- **Checkpoints** kept: after Issue Review with open questions; after
  Plan Review (always); after an Integrated Review with non-trivial
  findings; before push, PR creation, and merge. Every `AskUserQuestion`
  opens with the re-orientation header `<repo>#<N> (PR #M): <title> —
  phase X of Y (<phase>); <state>` and embeds the finding text verbatim;
  every Bash description opens with `<repo>#<N> <phase>:`. This is the
  fork's rule and matches the owner's own instructions (status line,
  self-contained dialogs).
- **Publish step**: GitHub only (no field mode — #208/#209 are separate);
  idempotency guard (an open non-`[PLAN]` PR on the branch means already
  published); `gh pr create` via `gh_create_pr.sh` with the pinned
  Decision summary in the body (the gate's condition (b)).
- **No auto-chaining** (Scope E) kept: phases never dispatch each other.
- **Dropped**: the container mode and everything listed in Context; the
  Copilot opt-in paragraph (no Copilot specialist here); field-mode
  branch; `--context-file`.

### 2. `dispatch_phase.sh` (new script, replaces `dispatch_subagent.sh`)

`.agent/scripts/dispatch_phase.sh --issue <N> --skill <phase>
[--prompt-file <f>] [--entry-type <T>] [--model <alias>]`:

- Resolves the issue's worktree with `_resolve_work_plans_dir.sh`'s
  rules (refuses outside the matching worktree, #147) and the expected
  entry type from a skill→entry-type table (`review-issue` → Issue
  Review, `plan-task` → Plan Authored, `review-plan` → Plan Review,
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
- **Per-phase model table** (revision 2): every dispatched phase →
  `sonnet` by default, per the owner's standing rule (main session on
  Fable, sub-agents on Sonnet); `--model <alias>` overrides per dispatch.
  The fork's Opus tier for review phases is NOT ported by default — Open
  Question 1 asks whether any phase should get it. Aliases only.
- **Failed or partial phases** (revision 2): `--check-exit` reporting
  `PARTIAL`, `FAILED`, or `MISSING` is always a checkpoint, never a
  silent retry. The host surfaces the phase, the outcome, and the last
  entry's text (or "no entry written") and offers: re-dispatch the same
  phase, take over inline, or stop. The fork's guideline "surface, don't
  swallow" becomes a table row, not prose.
- **Resume** (revision 2): every invocation re-derives the next action
  from the newest entry, so `/run-issue <N>` on a half-done issue simply
  continues; the skill states this and never keeps state outside
  `progress.md`.
- **One driver per issue** (revision 2): a stated convention, recorded in
  ADR-0014 — a second `run-issue` on the same issue, or hand edits to
  `progress.md` mid-run, are out of contract; `--check-exit`'s
  entry-count comparison is the only detection and it reports
  `MISSING`/unexpected type rather than guessing.
- **Claude Code only** (revision 2): run-issue depends on the Agent tool
  and `AskUserQuestion`; its description says so, exactly as
  `start-task` does. Codex/Gemini sessions keep driving phases by hand.
- **`next` subcommand**: `dispatch_phase.sh next --issue <N>` evaluates
  the decision table mechanically from the timeline (newest entry type,
  verdict, ship, open findings, preceding entry) and prints
  `action=<dispatch review-plan | implement | publish | triage | merge |
  address-findings | review-code | ask:<reason>>` with a one-line reason.
  The skill routes on this output instead of re-deriving the table in
  prose every round, and the table becomes testable.

### 3. Merge gate: accept a pre-push review at the head

`merge_pr.sh` Step 1.5 condition (a) also accepts a `## Local Review
(Pre-Push)` whose correlation SHA is the PR head and whose `**Verdict**`
is `approved` (the reader's `--type` list gains it). A post-PR entry at
the head still takes precedence when both exist. One test case in
`test_merge_pr_gate.sh`.

### 4. Handoff ADR

`docs/decisions/0014-in-process-phase-handoff.md`: the phase handoff
contract as it stands without containers — what the host provides (task,
identity, model, exit contract, worktree), what the phase promises (one
typed entry, no push, no chaining), what the host checks (entry count by
type), and why in-process is the only mode (auto mode; ADR-0004 layer:
convention plus a mechanical exit check, no server-side enforcement).
Cites fork ADR-0015/0019 as sources and states what was declined.

### 5. Knowledge note

`.agent/knowledge/review_loop_lifecycle.md`: one page — the phase order,
which skill writes which entry, what run-issue reads to move on, and
where the human checkpoints are. Replaces the need to read six SKILL.md
files to understand the loop.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/run-issue/SKILL.md` (new) | Host orchestrator: decision table, checkpoints with re-orientation headers, publish step, guidelines; in-process dispatch only |
| `.agent/scripts/dispatch_phase.sh` (new) | Handoff block emitter, skill→entry-type and skill→model tables, `--check-exit`, `next` decision-table evaluator |
| `.agent/scripts/tests/test_dispatch_phase.sh` (new) | Hermetic: handoff content (identity literals, model, exit contract, worktree), refusal outside the worktree, exit check OK/PARTIAL/FAILED/MISSING, every decision-table row from fixture timelines incl. the Ship rule and the three-round surface, the bare Local Review fallback, Implementation-preceded-by routing |
| `.agent/scripts/merge_pr.sh` | Gate condition (a) accepts `## Local Review (Pre-Push)` at the head (**PR 0**, its own small PR) |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Pre-push-at-head passes; stale pre-push still refused (PR 0) |
| `.claude/skills/review-issue/SKILL.md` | New persistence step: `## Issue Review` entry via `review_progress.sh persist --soft`, open questions as checkboxes (PR 1) |
| `.agent/scripts/tests/test_issue_review_entry.sh` (new) | The entry parses with `correlation.kind == "issue"` and its open-question checkboxes are what `dispatch_phase.sh next` routes on (PR 1) |
| `docs/decisions/0014-in-process-phase-handoff.md` (new) | Handoff contract ADR |
| `.agent/knowledge/review_loop_lifecycle.md` (new) | Lifecycle one-pager |
| `.agent/knowledge/principles_review_guide.md` | ADR-0014 row; consequences row for the decision table (skill entry types ↔ `dispatch_phase.sh next`) |
| `.agent/AGENT_ONBOARDING.md` | Skill list gains `run-issue` |
| `AGENTS.md` | Script Reference rows for `dispatch_phase.sh` (standing rule 2 on #269 covers script rows) |
| `ARCHITECTURE.md` | One paragraph: the lifecycle and its driver |

Not touched: `dispatch_subagent.sh`, `docker_run_agent.sh`, container
docs — never ported. `review-code` / `triage-reviews` / `address-findings`
already print their next command; run-issue reads entries, not prompts.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Four mandatory checkpoints; nothing publishes or merges without `AskUserQuestion`; every dialog self-contained (owner's own rule) |
| Enforcement over documentation | The decision table is code (`dispatch_phase.sh next`) with a test per row; the exit contract is checked mechanically; the skill prose routes on script output |
| Capture decisions, not just implementations | ADR-0014 records the no-container decision and the handoff contract; the plan records why in-process only |
| Only what's needed | Container path, field mode, Copilot opt-in, context injection all declined; no `implement` skill invented |
| Improve incrementally | Three PRs (below); run-issue is usable after PR 1 with hand-driven dispatch, fully after PR 2 |
| Test what breaks | Decision table, exit check, worktree refusal, handoff literals — all fixture-tested; the skill prose is thin over them |
| Workspace serves the product | Pure workspace infra, but it is the thing the owner asked for to manage project work with less context load |

## ADR Compliance

| ADR | Requirement | This plan |
|---|---|---|
| 0002 worktree isolation | Phases work in the issue's worktree only | Handoff names the worktree; `_resolve_work_plans_dir.sh` refuses elsewhere |
| 0004 enforcement hierarchy | Say which layer a rule sits at | Exit contract = convention + mechanical count check (fast local layer); no server layer, stated in ADR-0014 |
| 0009 python packaging | No new deps | Bash + `progress_read.py` only |
| 0013 entry vocabulary | Only canonical types | run-issue writes no entry itself; phases write theirs; `next` reads by `base_type` |

## Consequences

| If you change... | Also update... |
|---|---|
| A phase's entry type or verdict field | `dispatch_phase.sh` tables + `next`, its test, ADR-0013's table, the lifecycle note |
| The decision table | `test_dispatch_phase.sh` row cases, run-issue SKILL.md, the lifecycle note |
| The handoff contract | ADR-0014, `dispatch_phase.sh`, the test's literal assertions |

## Open Questions

1. **Model tier per phase (owner).** Default is Sonnet for every dispatched
   phase per the standing rule. The fork gives review-plan, review-code,
   triage-reviews, and address-findings Opus. Should any phase here get a
   larger model by default, or stay on Sonnet with `--model` as the
   per-run override?
2. **Implementation phase inline (decided, flag if you disagree).** Kept
   inline in the host, matching the fork today. A dispatched `implement`
   skill would be a follow-up issue; the table gets its "bare
   Implementation" row then.
3. **Three-round surface.** The plan hard-codes surfacing the loop state
   after three pre-push rounds, matching the standing rule on #269. Keep
   as a constant, or a flag?
4. **Where run-issue runs from.** The host must be inside the issue's
   worktree for `_resolve_work_plans_dir.sh` to resolve. `/run-issue <N>`
   will `cd` via `/start-task` semantics first (create or enter). Confirm
   that is acceptable for a session that started elsewhere.

## Estimated Scope

Four PRs, each independently mergeable, each through the review loop
(revision 2 split the gate change out):

- **PR 0 — gate accepts a pre-push review at the head** (`merge_pr.sh`
  condition (a) + one test). Tiny, load-bearing, independently motivated
  by the first live gate run on #273.
- **PR 1 — dispatcher + decision table + review-issue entry + ADR**
  (`dispatch_phase.sh`, its test, `review-issue/SKILL.md` persistence
  step and its test, ADR-0014). Largest; ~600 lines of script and test.
- **PR 2 — the skill + docs** (`run-issue/SKILL.md`, lifecycle note,
  onboarding, AGENTS.md rows, ARCHITECTURE paragraph). Prose over PR 1's
  mechanics.
- **PR 3 — live exercise**: drive one small real issue end to end with
  `/run-issue`, record the checkpoints hit and the entries written as a
  `## Checkpoint`-style note on #276, fix what it surfaces. Its merge is
  the owner's call; it is the first time the loop runs unattended
  between checkpoints.

Blast radius: nothing existing changes behaviour except the gate's
condition (a), which only widens what passes and stays report-only.
