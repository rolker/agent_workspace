# Plan: Port the review loop from ros2_agent_workspace: progress entry vocabulary, convergence verdict, integrated triage, address-findings, merge gate

## Issue

https://github.com/rolker/agent_workspace/issues/269

## Context

PR #266 (issue #265) was reviewed by hand-emulating the fork's review loop:
fresh-context `review-code`, typed `progress.md` entries, an integrated
triage of Copilot + local findings, address-findings, and a round-2
re-review with a convergence verdict. Round 2 caught two round-1 fixes that
were incomplete and a "parity" test that exercised only one parser —
material defects Copilot plus a single fresh review had not caught.
Emulating the loop by hand costs three subagent runs and manual bookkeeping
per PR, and drifts (this workspace's `triage-reviews` still writes the
retired `## External Review` heading; see Non-migration and Evidence
below). The owner (2026-09-16) wants to read a decision summary, not the
diff, and keeps the merge decision — this port is what makes that summary
trustworthy and repeatable without hand-emulation.

The `review-issue` evaluation of #269 (posted to the issue) found the
8-item scope too large for one PR, a hidden dependency on a
`progress_read.py` port, and a real ADR-0004 gap (merge-gate enforcement
is a single, local-only layer as scoped). The owner's decision comment
(2026-09-16) adopted the split and added six binding adjustments,
folded into this plan:

1. One issue, a PR sequence (mirrors #265).
2. `progress_read.py` (or a minimal parser) is in scope.
3. Refactoring existing inline `git add`/commit call sites onto
   `progress_append.sh` is explicit scope.
4. #265 is a dependency for `progress.md` path resolution; the plan states
   how the timeline is located in both the pre-#265 and design-B layouts.
5. The merge gate is presented as two enforcement layers; the CI /
   branch-protection layer is Ask-First, not assumed.
6. Existing non-conformant `progress.md` files are declared explicitly
   non-migrated.

## PR sequence

Six independently mergeable PRs, in order. Later PRs build on earlier
ones; nothing here needs #265's remaining PRs 2–4 to merge first (see
"#265 dependency and progress.md path resolution" below), so this
sequence can start immediately.

### PR A — ADR + `progress_append.sh` + `progress_read.py`

**Lands**: new ADR (vocabulary: `## Issue Review`, `## Plan Authored`,
`## Plan Review`, `## Local Review`, `## Local Review (Pre-Push)`,
`## Integrated Review`, `## External Review` as recognized predecessor,
`## Implementation`; header schema with offset-bearing `**When**`;
correlation-key table; checkbox findings schema), citing fork ADR-0013 as
source. `.agent/scripts/progress_append.sh` (append + commit in one
prompt-free step, writable-type whitelist, identity fail-loud, idempotency
guard). `.agent/scripts/progress_read.py` (JSON parse of entries,
`--type` filter, correlation-key extraction, fence-aware parsing,
predecessor recognition for `## External Review`).

Adaptations from fork source:
- Both scripts are read as-is from
  `~/project11/.agent/scripts/{progress_append.sh,progress_read.py}` —
  they're generic over `.agent/work-plans/issue-<N>/`, no fork-specific
  paths. The only changes are the entry-type whitelist comment
  cross-reference (points at this workspace's new ADR number, not
  fork ADR-0013) and dropping any fork-only `run-issue`/orchestrator
  references from comments.
- `progress_append.sh`'s `-C <dir>` targets a worktree directly; it does
  not resolve `.agent/work-plans/issue-<N>/progress.md` through the
  design-B `resolve_work_plans_dir` helper. PR A ships it as-is (the
  fork has no design-B equivalent); callers in PR B–F pass `-C` as
  `$WORK_PLANS_DIR`'s containing worktree, resolved by the caller.

**Tests**: `progress_append.sh` — writable-type rejection, idempotent
re-append-after-failed-commit, identity fail-loud when unset, commits
only the one file. `progress_read.py` — one hermetic fixture per entry
type, fence-aware parsing (a `## Foo` heading inside a fenced block does
not produce a phantom entry), predecessor-recognition filter
(`--type "Integrated Review"` also returns `## External Review`),
offset-missing `when_has_offset: false` case.

**Enforcement**: mechanical (test suite); the whitelist is itself the
enforcement for "only ADR-0013-vocabulary types get committed."

### PR B — `review-code`: `progress_append.sh` refactor + convergence + decision summary

**Lands**: (a) refactors this workspace's existing step-8 inline
`git add && git commit` (already present, already writing
`## Local Review` / `## Local Review (Pre-Push)` with ADR-0013-conformant
headings — see Evidence) onto `progress_append.sh`; (b) adds the
convergence assessment (Round = prior `## Local Review (Pre-Push)`
entries for this branch + 1; Ship: recommended with no must-fix, or at
round ≥ 2 with ≤ 2 mechanical non-rising must-fixes; continue otherwise),
surfaced in the report header (`**Round**`, `**Ship**`) and the
`progress.md` entry; (c) the decision-summary report shape (behaviour
change in plain words; findings and what was done; open human calls with
a recommendation; what was verified) as an additional top-of-report
section, alongside — not replacing — the existing findings tables.

**Dropped, documented as absent**: Ollama `local_review.sh` / the
`--local` specialist (workspace has no local-model serving story; would
need its own issue if wanted), the Copilot-CLI `--copilot` specialist and
its untrusted-PR gate (workspace has no `copilot` CLI integration
today — separate scope), and the container dispatcher
(`dispatch_subagent.sh --mode container`) — this workspace has no
container-mode orchestrator; `review-code` stays a directly-invoked skill,
not something a `run-issue`-style host dispatches.

**Evaluate while porting**:
- Convergence (#537 in the fork) — cited in fork ADR/SKILL text as the
  origin of the round/ship logic; UNVERIFIED beyond that citation (no
  access to fork's own issue tracker from this repo to confirm outcome
  metrics; taken on the fork SKILL.md's own account).
- `progress_append.sh` adoption (#594) — same: cited in the fork
  SKILL.md, not independently re-verified here.
- What changes here: the entry heading is already correct in this
  workspace (unlike `triage-reviews`, which needs a rename — see PR C);
  this PR's real work is the convergence math and decision-summary shape,
  plus the mechanical swap to `progress_append.sh`.

**Tests**: convergence round-counting against a fixture `progress.md`
with 0/1/2 prior `## Local Review (Pre-Push)` entries; ship-verdict cases
(no must-fix → recommended; round 2, 2 mechanical must-fixes → recommended;
round 1, 3 must-fixes → continue).

**Enforcement**: mechanical (round-counting test); decision-summary shape
is prose guidance (Suggestion-tier per the guidance-doc calibration this
workspace already applies), no new mechanical check.

### PR C — `triage-reviews`: `## Integrated Review`

**Lands**: renames the write target from `## External Review` to
`## Integrated Review` (the current, non-transitional ADR-0013 name —
this workspace never went through the fork's phase-A/phase-B split, so
there is no transitional period to model); reads prior
`## Local Review` / `## Local Review (Pre-Push)` entries via
`progress_read.py --type` filters instead of only GitHub-side reviews;
adds the cross-source-confirmation table (same correlation-key-at-head-SHA
rule as the fork); refactors its existing inline commit onto
`progress_append.sh`.

**Dropped**: none — this item is a rename + integration, not new
capability the fork gates behind other absent infrastructure.

**Evaluate while porting**: the fork's own ADR-0013 records `## External
Review` as a *predecessor* it once wrote and retired (#470 phase B,
#485/#486) — this workspace instead goes straight to `## Integrated
Review` for new writes, since it never had a phase-A period to
transition from. `## External Review` is read-only-predecessor from day
one here (see Non-migration).

**Tests**: a fixture `progress.md` with one `## Local Review` and one
GitHub Copilot finding at the same head SHA asserts the pair surfaces as
a single cross-source-confirmed row, not two.

**Enforcement**: mechanical (fixture test); no whitelist gate on
`triage-reviews`'s own write (it always writes the one type).

### PR D — `address-findings` (new skill)

**Lands**: ported largely as-is from
`~/project11/.claude/skills/address-findings/SKILL.md` — reads the latest
`## Integrated Review` or `## Local Review (Pre-Push)` entry via
`progress_read.py`, works each unchecked finding (fix-and-check or
defer-and-check-with-reason), commits atomically, writes
`## Implementation` via `progress_append.sh`.

**Dropped**: the `#492`-flagged disambiguation note about a future
`run-issue` orchestrator needing to tell an `implement`-skill
`## Implementation` apart from an `address-findings` `## Implementation`
by what precedes it — no orchestrator exists here, so this is dropped as
inapplicable (there is no automatic router to disambiguate for). The
dispatcher invocation line (`dispatch_subagent.sh --mode ...`) is dropped;
this workspace's lifecycle skills hand off by printing the next command
for a human or the calling session to run, not via a subagent dispatcher.

**Evaluate while porting**: no fork issue/PR citation available for this
skill specifically beyond the SKILL.md's own framing (#481 phase C) —
UNVERIFIED as an outcome claim; the port is taken on the shape of the
skill, not a track record.

**Tests**: a fixture progress.md with 2 unchecked findings (1 must-fix, 1
suggestion) exercises fix-and-check and defer-and-check paths, and asserts
the resulting `## Implementation` entry's `**Addressed**` field points at
the source entry.

**Enforcement**: mechanical (fixture test) for the entry-shape contract;
"never fake resolution" (every checkbox real or deferred-with-reason)
stays instructions-only, same as the fork.

### PR E — `plan-task` / `review-plan` entry headings

**Lands**: `plan-task` step 6 writes `## Plan Authored` (not the current
`## Plan`), with the `**Plan**: \`<path>\` at \`<plan-commit-sha>\`` field
(the plan-commit SHA — the commit that last touched `plan.md` — not the
PR head). `review-plan` writes `## Plan Review` (not the current
`## Plan Review: PR #<N> — <title>` as a heading — the title moves into
the entry body, the heading becomes the plain ADR-0013 type) with the same
`**Plan**:` correlation field. Both refactor onto `progress_append.sh`.

**Dropped**: none.

**Evaluate while porting**: this workspace's #265 timeline
(`.agent/work-plans/issue-265/progress.md`, evidence below) shows both
skills already run and already produce useful entries under the old
headings (`## Plan`, `## Plan review`) — this PR is a rename + correlation
field addition, not new capability. No fork issue/PR citation beyond
ADR-0013 itself (the plan-commit-SHA distinction, "not the PR head, not
the file's blob SHA," is ADR-0013's own text, ported verbatim as the
schema requirement).

**Tests**: `plan-task`/`review-plan` fixture entries parsed by
`progress_read.py --type "Plan Authored" --type "Plan Review"` and their
`correlation.sha` asserted against the plan-commit SHA of a synthetic
two-commit fixture repo (one commit touches `plan.md`, a second touches
something else — the correlation must key off the first, not HEAD).

**Enforcement**: mechanical (correlation-parsing test).

### PR F — merge gate (local + Ask-First CI decision) + PR template

**Lands**:
- **Layer 1 (this repo's scope, done in this PR)**: `merge_pr.sh` gains a
  pre-merge check that reads the target PR's linked issue `progress.md`
  via `progress_read.py --type "Local Review" --type "Integrated Review"`
  and refuses to proceed (exit non-zero, explicit message) unless the
  latest such entry's correlation SHA matches the PR head SHA and its
  status is not `changes-requested`-equivalent (i.e., `**Verdict**:
  approved` for `## Local Review`, or an `## Integrated Review` with no
  unchecked must-fix findings). `--force-unreviewed` bypasses with a
  loud warning banner (mirrors the existing human-gate banner pattern
  already in this repo's `merge_pr.sh` — see Files to Change). Never
  auto-merges; the human "type MERGE to confirm" banner this repo's
  `merge_pr.sh` already has stays the actual merge gate — this check
  only adds a *precondition* before that banner is reached.
- **Layer 2 (Ask-First, NOT implemented in this PR — see Open
  Questions)**: a GitHub required status check or branch-protection rule
  enforcing the same precondition server-side, so a direct "Merge" click
  on GitHub bypasses nothing. AGENTS.md requires owner approval before
  changing CI or branch-protection config; this PR documents the design
  (what check would run, what it would assert) but does not implement or
  enable it. Flagged for the owner at plan read (see Open Questions).
- PR template gains a "Decision summary" section mirroring PR B's report
  shape (behaviour change; findings and what was done; open human calls;
  what was verified) — replacing/augmenting the current
  "Documentation and test impact" / "Architecture impact" checklists,
  which stay (see Files to Change).

**Dropped/UNVERIFIED**: the fork's own `merge_pr.sh`
(`~/project11/.agent/scripts/merge_pr.sh`) has **no such gate today** —
grepping it for "Local Review" / "progress" / "force-unreviewed" /
"decision summary" returns nothing (confirmed by direct read). This item
is therefore not a straight port: issue #269's own body describes the
target behavior ("`merge_pr.sh` refuses ... unless `--force-unreviewed`
... no `## Local Review` entry ... no decision summary comment"), but no
fork source file implements it. Cite: UNVERIFIED against fork source; the
design below is authored fresh from the issue body's spec, using this
workspace's existing `merge_pr.sh` banner/gate idioms (already present in
this repo's script — see grep evidence in Files to Change) as the
implementation pattern.

**Tests**: `merge_pr.sh` refuses (exit non-zero, no worktree/branch
mutation) against a sandbox PR with (a) no `## Local Review` entry at any
SHA, (b) a `## Local Review` at a stale SHA, (c) a `## Local Review` with
`**Verdict**: changes-requested`; proceeds past the check (reaches the
human confirmation banner) with a matching-SHA `**Verdict**: approved`
entry; `--force-unreviewed` bypasses all three refusal cases with the
warning banner present in its output.

**Enforcement**: mechanical (Layer 1, this PR); Layer 2 is explicitly
**not yet enforced** pending the Ask-First decision (ADR-0004 gap, noted
honestly rather than assumed either way).

## #265 dependency and progress.md path resolution

#265 (open; design B) will move worktrees — and therefore, per design B's
own text, the natural home for per-issue artifacts — out from under the
workspace's own tree and root them under whichever repo/root owns the
worktree, once PRs 2–4 land. #265 PR 1 (registry + resolution) is merged;
PRs 2–4 are not. Every skill this plan touches resolves
`progress.md`/`plan.md` the same way today:

> Check `.agent/work-plans/issue-<N>/progress.md` in the owning repo's
> worktree first; if absent, fall back to the current worktree; create in
> the owning worktree if neither exists.

This resolution rule is **already path-convention-agnostic** — it doesn't
hardcode `<ws>/worktrees/...`, it walks from "the owning repo's worktree,"
whatever `worktree_create.sh`/`registry_worktree_dir` resolve that to be.
None of PRs A–F need to change this rule: `progress_append.sh`'s `-C <dir>`
and `progress_read.py`'s plain file-path argument are both worktree-path
inputs supplied by the calling skill, not something either script resolves
itself. The dependency is therefore soft, not hard: PRs A–F work correctly
under both today's layout (worktrees under `<ws>/worktrees/workspace/`) and
design B's post-PR-4 layout (worktrees under each root), because they take
the resolved worktree path as an argument rather than reconstructing it.
No PR in this sequence blocks on #265 PRs 2–4 landing first; no PR in this
sequence needs to change once they do. This is a design property to
verify, not just assert — PR A's test suite includes one case that invokes
`progress_append.sh -C <dir>` from a `-C` path outside the conventional
`<ws>/worktrees/...` tree (a plain `mktemp -d` git repo) to confirm nothing
in the script assumes the workspace-relative layout.

## Non-migration statement

Existing `progress.md` files predate this port and use non-conformant
headings: `.agent/work-plans/issue-265/progress.md` (on `main`, merged)
has `## Plan`, `## Plan review`, `## Implement — PR 1 of 4 (registry)` —
none of which match the new ADR's vocabulary (`## Plan Authored`,
`## Plan Review`, `## Implementation`). Per the fork's own ADR-0013
precedent ("Predecessor recognition" / "no migration of historical
files"), **this port performs no migration of existing `progress.md`
files**. They remain as historical artifacts, readable by eye but not
guaranteed to parse cleanly under `progress_read.py`'s correlation-key
extraction (e.g., `## Plan` won't match a `--type "Plan Authored"`
filter — there is no predecessor-recognition entry for it, unlike
`## External Review` → `## Integrated Review`, because #265's headings
were never a *named* predecessor type, just ad hoc prose). New entries
from PR B onward, on any issue, use the new vocabulary; issue #265's file
is not touched by this port.

## Files to Change

| File | Change |
|------|--------|
| `docs/decisions/0013-progress-md-entry-type-vocabulary.md` (new; number TBD at commit time — next available) | New ADR, vocabulary + schema, cites fork ADR-0013 as source (PR A) |
| `.agent/scripts/progress_append.sh` (new) | Ported from fork, comment cross-references updated (PR A) |
| `.agent/scripts/progress_read.py` (new) | Ported from fork as-is (PR A) |
| `.agent/scripts/tests/test_progress_append.sh`, `.agent/scripts/tests/test_progress_read.py` (new) | Hermetic fixtures per entry type, whitelist, idempotency, fence-awareness, offset detection (PR A) |
| `.claude/skills/review-code/SKILL.md` | Convergence assessment, decision-summary section, `progress_append.sh` swap, documented absences (Ollama/Copilot/container) (PR B) |
| `.agent/scripts/tests/test_review_code_convergence.sh` (new) | Round-counting + ship-verdict fixture cases (PR B) |
| `.claude/skills/triage-reviews/SKILL.md` | `## External Review` → `## Integrated Review`, prior-entry integration, cross-source table, `progress_append.sh` swap (PR C) |
| `.agent/scripts/tests/test_triage_reviews_integration.sh` (new) | Cross-source-confirmation fixture (PR C) |
| `.claude/skills/address-findings/SKILL.md` (new) | Ported from fork, dispatcher references dropped (PR D) |
| `.agent/scripts/tests/test_address_findings.sh` (new) | Fix/defer fixture (PR D) |
| `.claude/skills/plan-task/SKILL.md` | `## Plan` → `## Plan Authored`, plan-commit-SHA correlation field, `progress_append.sh` swap (PR E) |
| `.claude/skills/review-plan/SKILL.md` | `## Plan Review: PR #<N> — <title>` → `## Plan Review` (title moves to body), correlation field, `progress_append.sh` swap (PR E) |
| `.agent/scripts/tests/test_plan_correlation.sh` (new) | Plan-commit-SHA correlation fixture (PR E) |
| `.agent/scripts/merge_pr.sh` | Layer-1 gate: `progress_read.py`-backed precondition check, `--force-unreviewed` bypass (PR F) |
| `.agent/scripts/tests/test_merge_pr_gate.sh` (new) | Refusal/pass/bypass cases (PR F) |
| `.github/PULL_REQUEST_TEMPLATE.md` | Decision-summary section (PR F) |
| `.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`, `.agent/AGENT_ONBOARDING.md` | Add `address-findings` to skill lists (PR D) |
| `.agent/knowledge/principles_review_guide.md` | New ADR row in the ADR-applicability table (PR A) |
| `.agent/knowledge/review_depth_classification.md` | Note convergence/round fields now appear in the review-code report header (PR B) |
| `.agent/scripts/cross_model_review.sh` | Confirm no `progress.md`-header assumptions break (spot-check only; PR B) |
| `ARCHITECTURE.md` | `.agent/work-plans/issue-<N>/progress.md` entry-type vocabulary note, cross-reference the new ADR (PR A) |
| `Makefile` | New `.PHONY` test targets if the test harness needs one per PR; run `make generate-skills` if any `.PHONY` target changes (each PR, as needed) |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Every PR pairs its behavior change with a hermetic test (PR A's whitelist test, PR B's round-counting, PR C's cross-source fixture, PR D's fix/defer fixture, PR E's correlation fixture, PR F's refusal/pass/bypass cases). PR F Layer 2 is the one deliberately-unenforced-so-far item, and it's called out, not hidden. |
| Capture decisions, not just implementations | PR A puts the vocabulary in an ADR, not five SKILL.md copies (the exact failure mode ADR-0013 itself documents and this workspace already exhibits: `triage-reviews` still says `## External Review`). |
| A change includes its consequences | Files to Change lists every skill-list/knowledge-doc consequence flagged by the `review-issue` comment and the Consequences Map. |
| Only what's needed | Ollama, Copilot-CLI, and container-dispatch specialists are explicitly dropped, not silently ported as dead code. |
| Improve incrementally | Six independently mergeable PRs, each with its own tests, per the owner's adjustment #1. |
| Test what breaks | Each PR's Tests subsection is concrete (fixture shape, not "add tests"). |
| Human control and transparency | Merge gate never auto-merges; the CI/branch-protection layer is Ask-First, not assumed; convergence verdicts are advisory, never blocking. |
| Workspace vs. project separation | Nothing project-specific introduced; all vocabulary and scripts are generic over any `.agent/work-plans/issue-<N>/`. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0001 (Adopt ADRs) | Yes | PR A is a new ADR, ordinary authorship — no addendum mechanics needed. |
| ADR-0004 (Enforcement hierarchy) | Yes | PR F's merge gate is explicitly presented as two layers; Layer 1 (local script) ships in this sequence, Layer 2 (CI/branch-protection) is named as a real gap and routed through Ask-First rather than assumed done or assumed out of scope. |
| ADR-0008 (Cross-reference addendums) | No, not yet | PR A authors a brand-new ADR (ordinary ADR-0001 process), not an edit to an accepted one — ADR-0008 doesn't apply to authorship. It will apply the first time this new ADR needs a navigational update after landing (e.g., if a future skill adds a new consumer of the vocabulary) — flagged for later, not actionable now. |
| ADR-0011 (Adapter contract) | Watch, not blocking | `merge_pr.sh`'s existing gate/banner logic and the new Layer-1 check are not adapter-verb-routed (same ad hoc-per-repo pattern the #265 plan's own review already flagged as pre-existing, not a regression this PR introduces). Not fixed here — out of scope for a review-loop port. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `progress.md` entry-type vocabulary (new ADR) | `.agent/knowledge/principles_review_guide.md` ADR-applicability table | Yes (PR A) |
| `review-code` Step 8 / report shape | `.agent/knowledge/review_depth_classification.md`, `.agent/scripts/cross_model_review.sh` | Yes (PR B) |
| New `address-findings` skill | Framework adapter skill lists (`.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`, `.agent/AGENT_ONBOARDING.md`) | Yes (PR D) |
| Work-plan progress-entry schema (headings, correlation fields) | `plan-task`, `review-plan`, `triage-reviews`, `review-code` skills; `ARCHITECTURE.md` directory-tree/vocabulary reference | Yes (PRs A/B/C/E; `ARCHITECTURE.md` in PR A) |
| Merge-gate behavior | PR template (decision summary), `merge_pr.sh` docs/help text | Yes (PR F) |
| Merge-gate enforcement layer 2 (CI/branch protection) | Branch-protection config, CI workflow | **Not included** — Ask-First, owner decision required before any implementation (Open Questions) |

## Open Questions

- **Layer 2 (CI/branch-protection) for the merge gate** — implement now as
  a follow-up issue after PR F, or defer indefinitely and accept
  local-only (bypassable via direct GitHub UI merge) enforcement? This is
  an AGENTS.md Ask-First item; the owner must decide before any CI/
  branch-protection change is made, per the host decision comment's
  adjustment #5.
- **New ADR number** — this plan doesn't pin the exact ADR number (next
  available at PR A's commit time is 0013 as of this writing, matching the
  fork's own number coincidentally, but that's not guaranteed if another
  ADR lands first). Confirm at PR A implementation time, not now.
- **Test-harness convention for the six new `.agent/scripts/tests/test_*`
  files** — this workspace's existing test runner conventions should be
  followed exactly (shell vs. Python per script under test); confirm the
  harness entry point (`make test` / `.agent/scripts/adapter test`) picks
  them up automatically or needs a registration step.

## Estimated Scope

Six PRs (A–F), each independently mergeable and individually tested, per
the owner's adjustment #1. PR A is the foundation (nothing downstream
compiles/tests cleanly without it). PR B and PR E can land in either order
relative to each other (both depend only on PR A); PR C depends on PR A
(reads `## Local Review` via `progress_read.py`) but not on PR B. PR D
depends on PR C (`## Integrated Review`) and on PR B (`## Local Review
(Pre-Push)`) as its two possible source-entry types. PR F depends on PR A
(`progress_read.py`) only, not on B–E, and per the issue's own framing
does not need to wait on C–E. No PR in this sequence is blocked on #265
PRs 2–4.
