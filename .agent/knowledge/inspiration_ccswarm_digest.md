# Inspiration Digest: ccswarm

Type: inspiration
Last checked: 2026-11-13
Repo: nwiizo/ccswarm @ 2d4f7c7434e1ac1280a8dfb808ae32885803759a
Previously checked: 2026-09-22 (no commit SHA recorded: the first survey was
done from the README and GitHub API without a clone)

First-run survey. Registry interest areas: Sangha quorum model (shared
acceptance criteria, per-agent assessment, recorded decision);
evidence-backed objection / dissent handling in review gates;
multi-provider agent abstraction (Claude Code / Codex / copilot probing);
flow authoring (YAML-defined stage pipelines, faceted prompting); run
recording and replay (NDJSON event log, run diff/replay/undo).

## Survey Summary

ccswarm (MIT, Rust) is a workflow engine for AI coding agents whose
stated product core is "Sangha": a quorum-based decision process —
shared acceptance criteria, separate per-agent assessments, evidence-
backed objections, revision, and a recorded decision — layered over a
`plan → Sangha quorum → implement → review → fix` default pipeline.
Claude Code and Codex execute the actual work; ccswarm governs how the
workflow advances between stages.

The README is unusually explicit about what is aspirational vs. shipped
(a documentation habit worth noting on its own): "Sangha counts approval
markers only from completed reviews and rejects an unreachable quorum.
Evidence-bound acceptance, objection resolution, and checkpoint recovery
are the next design, not shipped guarantees." This directly answers the
registry's framing question — **checkpoint recovery is confirmed
unshipped**, consistent with the "inspiration only" designation in the
registry entry.

### Interest-area findings

**1. Sangha quorum model.** A pipeline stage can request `sangha:`
assessment from a named set of members (e.g. `planner`, `reviewer`,
`qa`), each ending its response with `SANGHA_DECISION=APPROVE` or
`SANGHA_DECISION=REVISE`; a `quorum:` count gates advancement. Today's
acceptance predicate is a bare count of successful approvals — it does
not yet resolve dissent (a REVISE vote doesn't get argued down, it just
doesn't count toward quorum) or bind the vote to independently-run
machine checks (the README states required checks need separate
execution and Sangha currently bypasses the ordinary stage-gate path
entirely). Compare against this workspace's sequential
`review-code → triage-reviews` loop: ccswarm's shape is *parallel,
role-differentiated votes converging on one go/no-go*, where this
workspace's is *one reviewer pass, then one integrator pass reconciling
findings from multiple sources* (local review + GitHub comments). The
two are not the same axis — quorum is about several independent voices
agreeing before proceeding; triage-reviews is about reconciling
findings after the fact — but a quorum-style gate is a plausible answer
to "should more than one review persona weigh in on a plan before
implementation starts" (the mandatory plan-review gate this workspace
already has, currently a single review-plan pass).

**2. Evidence-backed objection handling — not real yet.** The README's
own framing ("Evidence-bound acceptance, objection resolution... are
the next design, not shipped guarantees") means there is no worked
implementation to study for *how* an objection gets evidence attached
or resolved today; `docs/SANGHA_PRODUCT_CORE.md` (not fetched in this
survey — see Clone note) is where the design lives. Nothing actionable
to extract from this interest area on a first pass beyond noting the
gap exists and matches the registry's own caution.

**3. Multi-provider agent abstraction.** `AgentProvider` trait with
Claude/Codex/Copilot implementations; `ccswarm doctor` probes CLI
availability and treats a missing `ANTHROPIC_API_KEY` as a warning
rather than a hard failure when a provider CLI is already
locally-authenticated. Precedence for provider selection is explicit
and layered: stage YAML `provider:` > global `--provider` flag >
`CCSWARM_PROVIDER` env > Claude default, with unknown providers failing
validation rather than silently falling back. The Copilot provider is
notable for *failing fast with a stated reason* rather than degrading
silently: `gh copilot suggest` is interactive and returns shell-command
strings, not file edits, so code-generation requests through it are
rejected outright. This "fail closed with a clear reason instead of a
degraded silent path" pattern is worth comparing against any place this
workspace's own multi-framework (Claude/Codex/Gemini) tooling might
silently no-op on an unsupported combination instead of erroring.

**4. Flow authoring.** `ccswarm flow new/render/check/eject`, YAML
stage definitions under `.ccswarm/flows/`, and "faceted prompting"
(persona/policy/knowledge facets browsable via `ccswarm facets`) give a
declarative, inspectable pipeline definition with a preview command
(`flow render` shows the composed prompt per stage before running it).
This workspace's phase pipeline (`review-issue → plan-task →
review-plan → implement → review-code → publish → triage-reviews →
merge`) is fixed and defined in `/run-issue`'s dispatch logic rather
than as data; a `render`-equivalent "show me the composed prompt for
phase X before dispatching" preview does not exist today and could be
useful for debugging a misbehaving phase dispatch without actually
running it.

**5. Run recording and replay.** Every run gets an NDJSON event log
(`ccswarm/events`); `ccswarm run view/diff/replay` inspect or
re-execute a recorded run, `cost <run-id>` gives a per-stage/per-agent
cost breakdown, and `undo` is explicitly advisory — it prints `git log`
since the run started rather than rewriting history. This workspace's
closest equivalent is `progress.md`'s ADR-0013 timeline entries plus git
history itself; there is no single "replay this run" command and no
per-stage cost breakdown (cost/usage is tracked at the session level
per the owner's memory notes on model-usage balance, not per
review-loop run). A `run diff <a> <b>` (compare two runs' timelines)
equivalent could be useful for comparing two `/run-issue` drives of the
same issue after a plan revision.

### Activity Snapshot (2026-09-22)

- 152 stars, MIT, Rust, created 2025-06-11 (~15 months old, oldest of
  the three projects added this round). `pushedAt` 2026-09-14 — over a
  week stale at time of survey, versus same-day activity on the other
  two.
- **0 open issues.** The 10 "open PRs" sampled are entirely
  dependabot/renovate-style dependency bumps (`actions/setup-node`,
  `cucumber`, `tracing-subscriber`, `tar`, `sysinfo`, `chrono`, `log`,
  `serde`, `futures`) plus one real fix (#84, Windows build gating).
  Zero substantive feature PRs open.
- Recent commits (5 most recent, all pre-dating the dependency-bump
  PRs) show real feature work as of 2026-09: "Fix false provider
  failures and standalone Node test execution", two release commits
  (v0.10.0 "validated Sangha votes and complete artifacts", v0.10.1
  "live app generation and browser verification"), and a "v0.10.0
  trustworthy execution roadmap" commit — i.e. development is
  concentrated in direct pushes/releases rather than a PR-review flow,
  consistent with a single-maintainer project (no CI-visible outside
  contribution in the sampled window besides the dependency bumps).
- Assessment: real, actively-developed single-maintainer project with
  an unusually honest gap disclosure (shipped vs. designed), but thin
  external contribution signal (dependency bots only) and a week-plus
  gap since last push at time of check. Consistent with the registry's
  "inspiration only" framing — track the Sangha design as it matures,
  not a near-term adoption candidate.

### Clone note

Per skill step 2, a local shallow clone would normally live at
`<MAIN_ROOT>/.agent/scratchpad/inspiration/ccswarm/`. This first-run
survey was done from the GitHub README + `gh api` activity endpoints
only (no local clone); `docs/SANGHA_PRODUCT_CORE.md`,
`docs/MULTI_AGENT_REDESIGN.md`, and the `sangha`/`governance` module
source were not read and would be needed before any roadmap decision on
the quorum-gate interest area.

## Changelog (2026-09-22 → 2026-11-13)

Method note: the 2026-09-22 survey recorded no commit SHA, so the GitHub
compare API could not be used (no base). Used instead the 14 commits since
2026-09-22 from `gh api repos/nwiizo/ccswarm/commits?since=2026-09-22T00:00:00Z`,
`gh release list`, and `CHANGELOG.md` in the new shallow clone (HEAD 2d4f7c7,
commit date 2026-11-07; clone at `.agent/scratchpad/inspiration/ccswarm/` in
the main checkout). Commit diffs were not read; the `CHANGELOG.md` entries for
0.11.0 and 0.10.2 and the README were.

**Release state**: the last GitHub release and tag is v0.10.2 (2026-10-09).
`CHANGELOG.md` has a dated `[0.11.0] - 2026-11-06` section and the README
tells users to install the Herdr plugin with `--ref v0.11.0`, but no
v0.11.0 tag or release exists on GitHub as of this check (`gh release list`,
`gh api repos/nwiizo/ccswarm/tags`). Treat 0.11.0 as untagged.

Changes (all from the 0.11.0 section of `CHANGELOG.md` unless stated):

- **Sangha gates now run (interest area 1).** "Sangha stages run their
  `gates` once approvals reach quorum. A failed gate fails the stage with
  `gate_failed`, even when every member approved; a round below quorum skips
  the gates. Previously Sangha dispatch bypassed the gates." Machine checks
  are bound to the vote outcome, not run by members. This closes the exact
  gap the 2026-09-22 survey named (see corrections).
- **Routing by status, not text (interest area 2/4).** Rule conditions
  `success`/`failure` follow a stage's top-level status instead of words in
  its output; a failed stage quoting a success tag no longer routes as
  success. A rejected Sangha round or failed gate now stops the default flow
  rather than continuing to implement.
- **Read-only enforcement.** Codex stages (including Sangha members) with
  `permission: readonly` run under `codex exec --sandbox read-only`; a
  rate-limit fallback to a provider that cannot enforce read-only fails
  with an error. The AI rule judge is read-only too.
- **Herdr dependency (breaking, interest area 3).** Local provider calls now
  run in background tabs of a Herdr (terminal workspace manager) 0.9.5+ pane
  and fail before retrying outside Herdr; remote A2A execution unchanged.
  New stage `execution: live` for interactive Claude Code sessions with
  user answers; Herdr notifications on finish / awaiting approval.
- **Large removal.** Library modules never reached by the CLI were deleted
  (`governance`, `hooks`, `identity`, `resource`, agent orchestration and
  type-state builders, session management), plus the `ccswarm task` command,
  bridge context history, session persistence, multi-turn continuation and
  provider resume flags, and `ccswarm doctor --error`.
- **Run tooling (interest area 5).** `run view|diff`, `cost`, `tail`,
  `replay`, `undo`, `session view` accept the 8-character run ID or any
  unique prefix. README still says `undo` is advisory (lists commits) and
  `replay` re-executes the task.
- **Process hygiene.** CI runs the release workflow's checks (format, strict
  Clippy, locked tests, rustdoc) plus a dependency audit on every PR;
  RustSec advisories patched in the lockfile; Ctrl-C now cleans up the stage
  tab, provider process and temp directory.
- **Unchanged since the survey**: the README still states that evidence-bound
  acceptance, objection resolution and checkpoint recovery are "the next
  design, not shipped guarantees" (README lines 14-17), so checkpoint
  recovery remains unshipped. The Copilot provider still fails fast
  (README line 141).

**Corrections to the 2026-09-22 survey**

- Survey finding 1 said Sangha "currently bypasses the ordinary stage-gate
  path entirely" and that required checks could not be bound to the vote.
  False since 0.11.0 (unreleased/untagged): gates run once after quorum.
- Survey finding 3 (multi-provider abstraction, Claude/Codex/Copilot probing)
  omitted that local execution now requires Herdr; "Copilot compatibility
  names fail fast" stands.
- The "5 most recent commits" in the survey's snapshot (v0.10.0 / v0.10.1
  release commits, 2026-09) are older than the Herdr/gate work; development
  was not stalled as the "week-plus gap since last push" suggested.
- The "Clone note" is superseded by the clone made on this run;
  `docs/SANGHA_PRODUCT_CORE.md` exists in the clone but was only grepped for
  its gate table (line 211), not read in full.

## Activity Snapshot

Snapshot 2026-11-13 (supersedes the 2026-09-22 snapshot above for counts):

- 157 stars (was 152), MIT, Rust, not archived, default branch `master`,
  `pushedAt` 2026-11-07T11:56Z (six days before this check).
- 0 open issues; 16 open PRs, of which 15 are dependabot bumps (#72-#83,
  #86-#88) and one is a Windows build fix from an outside
  contributor (#84, open since 2026-08-12, no maintainer response seen).
- 14 commits since 2026-09-22 in three bursts: 2026-10-09 (v0.10.2),
  2026-11-06 and 2026-11-07 (Herdr, gates, status routing, cleanup).
  Single-maintainer direct pushes plus merged self-authored PRs (#89-#91).
- Verdict: still active, with the work the survey said was "next"
  (gate binding) now landed on master. Not a candidate for archiving.

## Pending Review

New in the 2026-11-13 check:

(none pending from this round)

Carried from 2026-09-22, still undecided (`quorum-gate-for-plan-review` is
partly sharpened by `ccswarm-1`; its note that Sangha "bypasses gates" is
no longer true):

- `quorum-gate-for-plan-review` — Evaluate whether a Sangha-style
  multiple-persona quorum vote (rather than a single review-plan pass)
  is worth adding to the mandatory plan-review gate; needs a read of
  `docs/SANGHA_PRODUCT_CORE.md` first since the shipped acceptance
  predicate is only a bare approval count today, not evidence-bound.
  (2026-09-22)
- `fail-fast-unsupported-provider-pattern` — ccswarm's Copilot provider
  fails fast with a stated reason ("interactive, returns shell strings
  not file edits") instead of silently degrading. Check whether any
  Claude/Codex/Gemini-specific workspace tooling has an unsupported
  combination that currently no-ops or degrades silently instead of
  erroring with a reason. (2026-09-22)
- `flow-render-dry-run-preview` — `ccswarm flow render` previews a
  stage's composed prompt without executing it. Consider whether
  `/run-issue`'s phase dispatch could use an equivalent preview for
  debugging a misbehaving phase without actually running it.
  (2026-09-22)
- `per-run-ndjson-event-log-and-diff` — `ccswarm run diff <a> <b>`
  compares two recorded runs' timelines. Consider whether comparing two
  `/run-issue` drives of the same issue (e.g. before/after a plan
  revision) would benefit from a similar structured diff over
  `progress.md` timeline entries rather than manual reading.
  (2026-09-22)

## Roadmapped

(none)

## Skipped

- `ccswarm-1` `quorum-then-machine-gates-ordering` — the workspace already
  follows the rule: merge waits on CI for the reviewed commit, and hooks run
  regardless of reviews (2026-11-13)
- `ccswarm-2` `route-by-status-not-by-text` — checked 2026-11-13:
  `dispatch_phase.sh` routes on the parsed `Status` / `Verdict` fields of the
  progress entry via `progress_read.py`, not on free text (2026-11-13)
- `ccswarm-4` `prune-unreached-code` — informational parallel to this
  workspace's "rules without enforcement" audits (2026-11-13)
- `ccswarm-5` `watch-untagged-release` — informational: only matters if the
  0.11.0 tag appears and local-provider behaviour is relied on (2026-11-13)

## Deferred

- `ccswarm-3` `read-only-enforced-not-requested` — repeats the earlier
  undecided `fail-fast-unsupported-provider-pattern` item (2026-11-13)
