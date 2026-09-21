# ADR-0013: `progress.md` Entry-Type Vocabulary

## Status

Accepted. Scoped exception in [ADR-0014](0014-in-process-phase-handoff.md):
`/run-issue` records `## Checkpoint` entries on the owner's behalf from
`AskUserQuestion` answers.

## Context

`progress.md` files at `.agent/work-plans/issue-<N>/progress.md` are the
workspace's per-issue lifecycle timeline. `plan-task`, `review-plan`,
`review-code`, and `triage-reviews` already write entries to these files, but
each skill invents its own heading and commit mechanism inline: `plan-task`
writes `## Plan`, `review-plan` writes `## Plan Review: PR #<N> — <title>`,
`review-code` writes `## Local Review` / `## Local Review (Pre-Push)`, and
`triage-reviews` still writes `## External Review` (issue #269's port context
below). With no central reference, a future skill author is free to invent
`## Code Review`, `## Triage`, `## Adversarial`, etc., and the timeline
becomes ungrep-able — exactly the failure this ADR's fork source
(`ros2_agent_workspace` ADR-0013, ported below) was written to close there.

This ADR ports that fork ADR-0013 into this workspace (issue #269, PR A of
the review-loop port), adopting its vocabulary, schema, and predecessor-
recognition rule, and extends it with three entry types the fork's own
ADR-0013 does not have, needed for this workspace's own new work (issue #269
PRs A and F):

1. **`## Checkpoint`** — a human-written, machine-checked record that a
   sequencing pause (issue #269's "checkpoint after PR B") was actually
   exercised, not just noted in prose. Not present in the fork's ADR-0013;
   this workspace's `test_checkpoint_269.sh` (PR A) is new work, not a port
   — see "New vocabulary" below.
2. **`## Merge (report-only)`** — a durable record, written by
   `.agent/scripts/merge_pr.sh` via `progress_append.sh`, every time the
   merge gate's report-only mode (PR F, not yet landed as of PR A) evaluates
   its preconditions and finds at least one unmet. Not present in the fork's
   ADR-0013: this workspace's Layer-1 merge gate is new work, not a port.
3. **`## Merge (unreviewed)`** — an audit record for the merge gate's
   `--force-unreviewed` bypass (PR F, not yet landed as of PR A). Same
   reasoning as above.

Both scripts this ADR specifies — `.agent/scripts/progress_append.sh` (the
prompt-free entry appender + committer) and `.agent/scripts/progress_read.py`
(the JSON parser consumers use to filter prior entries) — are ported
essentially as-is from the fork; see their own file headers for the
adaptation notes.

## Decision

Canonicalize the `progress.md` entry-type vocabulary as a workspace
decision. Workflow skills and scripts writing to `progress.md` MUST use one
of the following entry types:

| Entry type | Writer | Purpose |
|---|---|---|
| `## Issue Review` | `review-issue` | Result of evaluating an issue against principles + ADRs before work begins. |
| `## Plan Authored` | `plan-task` | Marker that a plan was committed and a draft PR opened. References the plan-commit SHA. |
| `## Plan Review` | `review-plan` | Independent evaluation of a committed plan; verdict + findings checklist. |
| `## Local Review` | `review-code` post-PR | Local pre-merge review of an existing PR. |
| `## Local Review (Pre-Push)` | `review-code` pre-push | Local review of unpushed commits before opening / updating a PR. |
| `## Integrated Review` | `triage-reviews` | Unified findings table integrating local-review entries + GitHub-side reviews; flags cross-source confirmations. |
| `## External Review` | *(read-only predecessor; see Predecessor recognition)* | Historical per-PR findings table from a single source, as written by this workspace's `triage-reviews` before its issue-#269 PR-C rename. |
| `## Implementation` | `address-findings` (and any future `implement` skill) | Marker that implementation work completed; references the final commit SHA(s). |
| `## Checkpoint` | Human (owner), attesting a sequencing pause was exercised | Durable, field-checked record that a plan's named checkpoint (e.g. issue #269's "checkpoint after PR B") was observed before dependent work resumed. Required fields are defined by the checkpoint's own plan section, not fixed here — issue #269's checkpoint requires `**PR**`, `**Review entry SHA**`, `**Resolver-hit**`, and `**Decision summary URL**`. |
| `## Merge (report-only)` | `.agent/scripts/merge_pr.sh`, via `progress_append.sh` | Durable record of a report-only merge-gate pass where at least one precondition failed — see issue #269 PR F. |
| `## Merge (unreviewed)` | `.agent/scripts/merge_pr.sh`, via `progress_append.sh` (`--force-unreviewed` bypass) | Audit record that a merge bypassed the gate's preconditions entirely — see issue #269 PR F. |

### Schema

Every entry begins with:

```markdown
## <Entry Type>
**Status**: complete | partial | failed
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <agent name> (<model>)
```

The `**When**` value MUST carry an explicit numeric UTC offset
(e.g. `2026-05-20 01:45 -04:00`, `2026-05-20 05:45 +00:00`). Local-time
display is preferred — agents write the wall-clock time of the host
that produced the entry, and the offset records the rule (including
DST) that was in effect. Bare `HH:MM` without an offset is not
schema-conformant: cross-host handoff and post-DST reads both depend
on the offset being present. Use a numeric offset here rather than a
TZ abbreviation (`EDT`, `PST`, etc.); abbreviations are ambiguous
across regions and silently shift across DST boundaries.

`Z` is accepted as a synonym for `+00:00` (per RFC 3339 / ISO 8601),
so `2026-05-20 05:45 Z` and `2026-05-20 05:45 +00:00` are equivalent.

In the entry's header section (typically near the top, before any
`### Findings` / `### Actions` / `### Notes` sub-sections), every
entry MUST include the canonical correlation-key field for its entry
type, so consumers (notably `triage-reviews` and `merge_pr.sh`'s
Layer-1 gate) can filter by entry-type + correlation-key without
parsing prose. Exact position within the header is not constrained —
skill-specific fields like `**Verdict**` may appear before or after
the canonical field; consumers locate by field name, not by line
offset.

| Entry type | Required field |
|---|---|
| `## Issue Review` | `**Issue**: #<N>` |
| `## Plan Authored`, `## Plan Review` | `` **Plan**: `<path>` at `<plan-commit-sha>` `` (commit SHA, not blob SHA — see [Consume by entry-type filter](#consume-by-entry-type-filter)) |
| `## Local Review`, `## Local Review (Pre-Push)`, `## Integrated Review`, `## External Review`, `## Implementation`, `## Merge (report-only)`, `## Merge (unreviewed)` | `` **PR**: #<N> at `<sha>` `` (or `` **Branch**: <name> at `<sha>` `` if no PR exists yet) |
| `## Checkpoint` | No single canonical correlation field — see the Decision table's `## Checkpoint` row; required fields are the plan section that defines the checkpoint. |

After that, additional skill-specific fields are permitted but should
follow existing precedents (verdict, must-fix/suggestion counts,
sources column for integrated entries, etc.). Findings, actions, or
open questions go in a `### Findings`, `### Actions`, or
`### Open questions` sub-section as a checkbox list — sources for
each item should be inline (e.g., `- [ ] (suggestion, Copilot R2) …`)
when known. `### Open questions` is reserved for decisions that need
human input before implementation (used by `## Plan Authored`);
`### Findings` and `### Actions` are the general-purpose forms.

### Consume by entry-type filter

Downstream skills and scripts that aggregate or react to prior work
(notably `triage-reviews` and `merge_pr.sh`'s Layer-1 gate) MUST consume
prior entries by **filtering on entry type and the correlation key
appropriate to that type**, not by re-classifying:

| Entry type | Correlation key |
|---|---|
| `## Issue Review` | issue number (no SHA — issue body is the reference) |
| `## Plan Authored`, `## Plan Review` | plan-commit SHA — the SHA of the commit that last updated `plan.md` (not the PR head, not the file's blob SHA) |
| `## Local Review`, `## Local Review (Pre-Push)`, `## Integrated Review`, `## External Review`, `## Implementation`, `## Merge (report-only)`, `## Merge (unreviewed)` | PR / branch head SHA |
| `## Checkpoint` | none defined generically — this entry type correlates to the plan section that named the checkpoint, not to a PR/branch/plan SHA; consumers that need to verify it (e.g. `test_checkpoint_269.sh`) check its required fields directly. |

A finding present in both a `## Local Review` at head `<sha>` and a
GitHub-side Copilot review at the same head is a **cross-source
confirmation** — keep both with a sources column, do not collapse.
More generally, cross-source confirmation is keyed by entry type +
the entry's correlation key (per the table above): issue number for
`## Issue Review`, plan-commit SHA for `## Plan Authored` / `## Plan
Review`, PR/branch head SHA for the others. E.g., a `## Plan Review`
and a `## Plan Authored` for the same plan-commit SHA agree on a
finding.

### Predecessor recognition

`## External Review` is the recognized predecessor of `## Integrated
Review`. Unlike the fork, this workspace never went through a
transitional period where `triage-reviews` wrote `## External Review` and
later switched — issue #269 PR C renames `triage-reviews`'s write target
directly, with no phase-A period to model. `## External Review` is
therefore a **read-only predecessor from day one** in this workspace:
existing entries under that heading (see Non-migration below) remain as
historical artifacts, and `progress_read.py` recognizes it as the
predecessor of `## Integrated Review` for `--type` filtering, but no new
entry ever writes it.

### Non-migration statement

Existing `progress.md` files predate this ADR and use non-conformant
headings — e.g. `.agent/work-plans/issue-265/progress.md` (on `main`,
merged) has `## Plan`, `## Plan review`, `## Implement — PR 1 of 4
(registry)`, none of which match this ADR's vocabulary. Per the fork's own
ADR-0013 precedent ("Predecessor recognition" / no migration of historical
files), **this ADR performs no migration of existing `progress.md`
files.** They remain as historical artifacts, readable by eye but not
guaranteed to parse cleanly under `progress_read.py`'s correlation-key
extraction (e.g. `## Plan` will not match a `--type "Plan Authored"`
filter — there is no predecessor-recognition entry for it, unlike
`## External Review` → `## Integrated Review`, because those headings
were never a *named* predecessor type, just ad hoc prose). New entries
from this ADR onward, on any issue, use the vocabulary above; no existing
file is rewritten by this ADR's adoption.

## Consequences

**Positive:**
- Vocabulary lives in one place reviewers and skill authors actually
  look (`docs/decisions/`) rather than spread across five `SKILL.md`
  files where it would silently drift.
- The "consume by entry-type filter" rule gives `triage-reviews` and the
  merge gate a single filter mechanism instead of each re-inventing it.
- Cross-source confirmations are an explicit signal class.

**Negative:**
- Adds one decision document to `docs/decisions/`. Mitigation: the
  document is short and the canonical-vocab decision is what makes the
  timeline composable.
- A future workflow skill author has to either pick an existing entry
  type or introduce a new one via a **superseding ADR**. Per
  [ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md), adding an
  entry type changes this ADR's Decision table and Consequences, which is
  a substantive change, not a cross-reference addendum — it requires a
  superseding ADR, not an addendum note. The supersession-only rule is the
  intended friction.
- Existing `progress.md` files are left non-conformant (Non-migration
  statement above); `progress_read.py`'s correlation-key extraction will
  not recognize their old headings except where a predecessor mapping
  exists.

## References

- [ADR-0001](0001-adopt-architecture-decision-records.md) — Adopt
  Architecture Decision Records (parent; this ADR captures a workspace
  decision per ADR-0001's rule).
- `ros2_agent_workspace` ADR-0013 (`docs/decisions/0013-progress-md-entry-type-vocabulary.md`
  in that repo) — source this ADR ports from. That repo is not a GitHub
  remote reachable from this one; see issue #269 for the port context.
- Issue [#286](https://github.com/rolker/agent_workspace/issues/286) —
  how `merge_pr.sh` consumes the PR/branch head SHA key: a review entry
  at SHA `R` is read as current for head `H` when `R` is an ancestor of
  `H` and only merge-time document files (the issue's `progress.md`, the
  roadmap files) changed between them, because recording the review
  itself commits `progress.md` on the branch. One helper
  (`_only_bookkeeping_between`) applies the rule for both the gate and
  the CI target (#284). Cross-reference addendum per ADR-0008; the key
  itself is unchanged.
- Issue [#269](https://github.com/rolker/agent_workspace/issues/269) — Port
  the review loop from `ros2_agent_workspace`: this ADR is PR A of that
  port's PR sequence.
- [Principles review guide](../../.agent/knowledge/principles_review_guide.md) — references this ADR in the ADR-applicability table.
- [ADR-0014](0014-in-process-phase-handoff.md) — `/run-issue`'s handoff
  contract and its scoped exception recording `## Checkpoint` entries on
  the owner's behalf. Consumers' routing rules — **Verdict** for `## Local
  Review` / `## Local Review (Pre-Push)`, open boxes for `## Issue Review`
  / `## Integrated Review` — are defined in ADR-0014's Decision and in
  `dispatch_phase.sh`, not restated here.
