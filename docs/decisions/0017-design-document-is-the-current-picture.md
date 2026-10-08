# ADR-0017: The Design Document Is the Current Picture; ADRs Record Decisions

## Status

Accepted. Scopes the trigger in
[ADR-0001](0001-adopt-architecture-decision-records.md) and the role of
accepted ADRs. Owner decision 2026-10-08 (#335).

## Context

ADR-0001 asks for an ADR whenever reverting a decision would cause problems.
Since then the log has grown to sixteen, each recording one decision at a
time, and nothing holds the overall picture. Implementation detail such as
script lifecycles has landed in ADRs, where it goes stale. The principle
"Keep one current design" in [docs/principles.md](../principles.md) makes
[docs/design.md](../design.md) the authority for how the parts fit today.

## Decision

- A change to how the parts fit updates the matching section of
  `docs/design.md` in the same change.
- An ADR is written when a decision is significant enough that two
  independent parts could otherwise choose incompatibly. It records context,
  decision and consequences, and keeps implementation detail where the code
  is (script header, document next to it).
- Accepted ADRs are history: superseded, not edited, apart from
  [ADR-0008](0008-permit-cross-reference-addendums-in-accepted-adrs.md)
  addendums.

## Consequences

- Fewer ADRs. The design document carries the current picture and has to be
  kept current; the review guide's "Keep one current design" row checks
  that.
- `docs/design.md` is rewritten to carry that picture (#335, phase 3). Until
  then, existing ADRs stand as written; where one disagrees with the design
  document, the design document wins and the ADR is superseded when next
  touched.
- ADR-0001's "would reverting cause problems?" bar is replaced by the one
  above. The review guide's ADR-0001 row states the operational rule.
