# ADR-0008: Permit Cross-Reference Addendums in Accepted ADRs

## Status

Accepted. Narrows the immutability rule from
[ADR-0001](0001-adopt-architecture-decision-records.md).

## Context

[ADR-0001](0001-adopt-architecture-decision-records.md) established that
*"ADRs are immutable once accepted — supersede rather than edit"*. The
intent of that rule is sound: substantive edits to accepted ADRs
(rewording the Decision, reversing position, changing Consequences) can
silently reverse settled decisions and undermine the "check
`docs/decisions/` before proposing changes" discoverability the practice
depends on.

But a strict read of "immutable" also blocks a useful, low-risk class of
edit: **cross-reference addendums** — pointers from one ADR to another
that was written later. Specifically:

- A Status-line note like *"Scoped exception in ADR-N permits ..."*
  on an older ADR, making the relationship discoverable from the older
  ADR.
- A References section at the end of an ADR listing related ADRs (earlier
  or later) that inform or qualify it.

These additions are purely navigational. They don't restate, reword, or
reverse the original Decision — they point at additional decisions the
reader should know about. Without them, relationships between ADRs are
only visible when reading the newer ADR, not the older one.

This workspace inherited its `docs/decisions/` set from
`ros2_agent_workspace`, where ADRs accumulated incrementally over many
issues. Older ADRs predate later ADRs that scope, qualify, or partially
supersede them, and have no forward links. Without a permitted-addendum
rule, the only options are (a) leave older ADRs without forward
references, hurting discoverability, or (b) supersede an ADR purely to
add a navigational pointer, inflating the supersede mechanism.

## Decision

Narrow ADR-0001's immutability rule: cross-reference addendums to
accepted ADRs are permitted; substantive changes still require
superseding.

### Permitted (cross-reference addendums)

- Updating the **Status** line to note a related ADR (e.g. *"Scoped
  exception in ADR-N…"*)
- Adding or appending to a **References** section listing related ADRs
- Fixing broken links, typos in metadata, or formatting nits that don't
  change meaning

### Still requires a new/superseding ADR (substantive changes)

- Rewording the **Decision** section
- Reversing or softening the position
- Adding or removing **Consequences** that weren't previously recorded
- Anything a reader could mistake for "this ADR now says something
  different"

### How to tell the difference

Ask: *if someone reads only the edited ADR without knowing about the
change, will they get a misleading picture of what was originally
decided?* If yes → supersede. If no → addendum is fine.

## Consequences

**Positive:**
- Relationships between ADRs are discoverable from both directions —
  forward (newer ADR references older) and backward (older ADR notes
  newer).
- Keeps the supersede mechanism for what it's designed for: substantive
  change. Navigation isn't change.
- Self-bootstrapping: the one-line Status update to ADR-0001 that
  records this narrowing (*"narrowed by ADR-0008"*) is itself the first
  addendum permitted under this rule.

**Negative:**
- Slippery-slope risk — if the "cross-reference" category expands
  gradually, substantive edits could sneak in under the label. The "how
  to tell" test above is the guardrail.
- One more thing for ADR authors to think about when touching existing
  ADRs. Mitigated by the rule-of-thumb being quick to apply.

## References

- [ADR-0001](0001-adopt-architecture-decision-records.md) — Adopt
  Architecture Decision Records (this ADR narrows ADR-0001's
  immutability rule)
