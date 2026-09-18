# ADR-0014: In-Process Phase Handoff for `/run-issue`

## Status

Accepted.

## Context

Issue #276 ports the fork's composable review-loop orchestrator
(`ros2_agent_workspace` `/run-issue` + `dispatch_subagent.sh`, its
ADR-0015 "handoff context contract" and ADR-0019 "dispatch default flipped
to in-process") into this workspace, now that `review-issue` (PR 1) and
`triage-reviews` (issue #269) both write ADR-0013-conformant `progress.md`
entries and the loop has a total decision table (`dispatch_phase.sh next`,
PR 2 of #276).

The fork's `dispatch_subagent.sh` supported two dispatch modes: in-process
(the Agent tool, a fresh sub-agent sharing the host's session) and headless
container (a subscription-token CLI invocation with no GitHub credentials
in either direction, fenced from untrusted PR content via
`--context-file`). ADR-0019 there records why containers stopped being the
default: once "auto mode" (no per-tool-call approval) removed the
prompt-cost argument for container dispatch, six review rounds on the
container launcher found it mounted the whole workspace read-write,
forwarded the human's own credentials, and withheld GitHub write auth only
by configuration — the container was containing machine state, not
untrusted input. This workspace never built a container dispatcher (Tier-3
deferred, per the digest in
`.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`), so there is
no migration to perform: `dispatch_phase.sh` (PR 2) is in-process only from
its first line, and this ADR records that as the decision rather than as a
default flip.

Three further questions need a durable answer, not just a script comment:
what the host and a dispatched phase promise each other (the handoff
contract), what happens when two drivers touch the same issue at once (the
fork's ADR-0015 states a convention, not a lock), and which model tier each
phase runs at (an owner call with real usage-budget consequences, not an
implementation detail).

## Decision

**One dispatch path, in-process only.** Every phase — dispatched or the
inline `implement` pass — is handed off through
`.agent/scripts/dispatch_phase.sh --issue <N> --skill <phase> [--pr <M>]
[--type <type>]`, which prints a handoff block, and the host pastes it into
a fresh-context sub-agent via the Agent tool. There is no `--mode`, no
container path, no `--context-file` untrusted-input fence, and no auth
preflight: a dispatched phase fetches its own issue/PR bodies with `gh`
exactly as it does when run by hand, so there is nothing to fence — the
fork's `--context-file` existed to hand a container the untrusted PR body
without giving it `gh` credentials to fetch it itself; that problem does
not exist when the phase runs with the host's own tools.

**The handoff contract.** The host provides, on every dispatch:

- the resolved **worktree** path (`dispatch_phase.sh` locates it via
  `find_worktree_by_issue`, refusing with exit 2 if none exists for
  `--issue`/`--type`);
- the phase's literal **task** line — one entry in a fixed per-skill table,
  carrying the arguments each `SKILL.md` actually parses, so the handoff
  never improvises a phase's own usage;
- the commit **identity** (`agent_name=`/`agent_email=` from
  `AGENT_NAME`/`AGENT_EMAIL`, which the caller must have sourced via
  `set_git_identity_env.sh` first — no fallback to the human's own git
  config, so a dispatched phase's commits are never misattributed);
- the **model** to stamp in the entry's `**By**` field (the per-phase tier
  below, or `--model <alias>` override);
- the **exit contract**: append exactly one entry of the expected
  ADR-0013 type; if the phase cannot finish, still append it with
  `**Status**: partial` or `failed` and say why; never push (the host owns
  every push — see the `run-issue` skill).

The phase promises back exactly that one typed entry and nothing else: no
chaining to another phase, no push, no second entry of a different type
for the same unit of work.

**What the host checks.** `dispatch_phase.sh --check-exit --issue <N>
--skill <phase> [--pr <M>] --before <count>` is the only verification —
comparing the entry count of the expected type (read from the same
per-skill table, so a PR-mode `review-code` dispatch checks for
`## Local Review`, not `## Local Review (Pre-Push)`) before and after the
dispatch. It reports `OK <sha>` (the newest such entry's `**Status**:
complete`), `PARTIAL`, `FAILED`, or `MISSING` (no new entry of the expected
type at all) — a mechanical count, not a content review. The host never
assumes an outcome from the sub-agent's own turn-ending prose; it always
asks the script.

**Why in-process is the only mode.** Per ADR-0004's enforcement hierarchy,
this exit check is a fast, local, convention-plus-mechanical-check layer —
there is no server-side enforcement that a dispatched phase kept the
contract, the same way there is none for a human running `/plan-task` by
hand. `--check-exit`'s count comparison is what makes a broken contract
visible immediately (as `MISSING`/`PARTIAL`/`FAILED`, always routed to a
`checkpoint:phase-failed` — see the `run-issue` skill and
`dispatch_phase.sh next` row 3) rather than silently ignored.

**One driver per issue.** A second `/run-issue` on the same issue, or a
hand edit to `progress.md` while one is running, is out of contract. There
is no lock: `--check-exit`'s entry-count comparison is the only detection,
and it reports `MISSING` or an unexpected entry type rather than guessing
at what a concurrent writer did. This mirrors the fork's ADR-0015
convention, adapted for a workspace with no server-side lock primitive for
`progress.md` writes.

**Per-phase model tier** (owner decision, 2026-09-17, scoped to this
loop): `review-plan`, `review-code`, `triage-reviews`, `address-findings`,
and the inline `implement` pass dispatch on **Opus** — the phases that
carry judgment (evaluating a plan, a diff, or a fix, or writing the
implementation itself). `review-issue` and `plan-task` dispatch on
**Sonnet** — cheaper, and the owner confirmed usage headroom for this tier
on 2026-09-17. `--model <alias>` overrides per dispatch. This tier is not a
new workspace-wide default for other work; it is scoped to phases
dispatched through `dispatch_phase.sh` inside this loop.

**Checkpoints are entries, recorded on the owner's behalf.** `run-issue`
writes a `## Checkpoint` entry for every `AskUserQuestion` outcome, via
`progress_append.sh`, with `**Decided-by**: owner` naming that the entry
records the human's answer rather than a phase's own output, plus
`**After**: <checkpoint name>` and `**Decision**: <token>` (the fields
`dispatch_phase.sh next` routes on) and, on a `phase-failed` checkpoint,
`**Phase**: <skill>` copied from the `phase=` line `next` printed. This is
the mechanism that makes the state machine total: the timeline alone says
whether a checkpoint was passed, with nothing held in the conversation or
any other file.

## Consequences

**Positive:**
- No container surface area to secure, patch, or explain — the mounts,
  credential forwarding, and write-auth configuration ADR-0019 flagged
  never exist here.
- The exit contract is mechanically checked (`--check-exit`), not trusted
  from a sub-agent's own summary; a broken contract surfaces as a
  checkpoint, never a silent skip.
- The model tier is a single table in `dispatch_phase.sh`, overridable per
  dispatch, so a usage-budget change is a one-line edit, not a re-plan.
- Checkpoint entries give `progress.md` a complete audit trail of every
  human decision in the loop, in the same file and format as phase output.

**Negative:**
- No lock enforces one-driver-per-issue; a violation is detected only after
  the fact, as an unexplained `MISSING` or unexpected entry type at the
  next `--check-exit` or `next` call.
- The model tier is a workspace-specific, time-scoped judgment call (usage
  headroom as of 2026-09-17), not a permanent policy; revisiting it needs
  no ADR, just an edit to `dispatch_phase.sh`'s table, but the rationale
  here can go stale if usage headroom changes.
- `dispatch_phase.sh`'s per-skill task-line table duplicates each phase's
  own usage block; a `SKILL.md` usage change that isn't mirrored here
  silently produces a stale task line (mitigated by
  `test_dispatch_phase.sh`'s literal task-line assertions, which fail loud
  on drift, not by any automatic sync).

## References

- [ADR-0004](0004-enforcement-hierarchy-for-agent-compliance.md) — the
  enforcement layer `--check-exit` sits at (fast, local, mechanical count;
  no server-side layer for this convention).
- [ADR-0013](0013-progress-md-entry-type-vocabulary.md) — the entry-type
  vocabulary every handoff's exit contract and every `## Checkpoint` entry
  conform to; this ADR adds no new entry type, only the recorded-by-host
  convention for `## Checkpoint`.
- Issue [#269](https://github.com/rolker/agent_workspace/issues/269) — the
  review-loop port whose entry vocabulary and `triage-reviews` rename this
  loop depends on.
- Issue [#276](https://github.com/rolker/agent_workspace/issues/276) — this
  port (PR 1 `review-issue` persistence, PR 2 `dispatch_phase.sh`, PR 3
  this ADR + the `run-issue` skill + docs, PR 4 the live exercise).
- `ros2_agent_workspace` ADR-0015 ("handoff context contract") and
  ADR-0019 ("dispatch default flipped to in-process") — the fork ADRs this
  one adapts. That repo is not a GitHub remote reachable from this one; see
  `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md` for the
  port context. Declined from the fork's design: the container dispatch
  mode itself (never built here), the `--context-file` untrusted-input
  fence (no purpose without a container), and Copilot-CLI dispatch (no
  `copilot` CLI integration in this workspace's `review-code`).
