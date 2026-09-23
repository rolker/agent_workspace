---
issue: 334
---

# Issue #334 — Docs reorganisation: move planning docs into docs/ with lowercase names; ARCHITECTURE.md becomes docs/design.md; discovery accepts both spellings

## Issue Review
**Status**: complete
**When**: 2026-09-23 12:52 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #334

### Scope Assessment

**Well-scoped?** Yes — mechanical, no content decisions (deferred to companion issue #335), single PR feasible.
**Right repo?** Yes — workspace infrastructure (`docs/`, scripts, skills, templates).
**Dependencies**: #335 (design-document content) depends on this landing first; issue states that correctly.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| A change includes its consequences | OK | Issue explicitly scopes script updates + tests + reference sweep in the same PR. |
| Workspace vs. project separation | OK | Scope item 4 correctly keeps discovery from forcing a naming convention on projects. |
| Only what's needed | OK | Scope is mechanical; content rewrite explicitly deferred. |
| Enforcement over documentation | Watch | Acceptance relies on a manual `grep` sweep rather than a script/test asserting no stale references remain; consider whether `discover_governance.sh`'s own test suite should assert this. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0008 (cross-reference addendums in ADRs) | Yes | Issue correctly treats ADR bodies as immutable and doesn't propose editing them. |
| ADR-0013 (progress.md vocabulary) | No | Not touched by this issue. |

### Consequences

- Confirmed: `merge_pr.sh`'s bookkeeping allow-list and `update_roadmap.sh`'s discovery both need the `docs/roadmap.md` path, with `test_merge_pr_gate.sh` coverage — matches the issue's claim.
- Confirmed: `discover_governance.sh`'s `scan_scope()` runs identically over both the workspace root and a registered project (`scan_scope "$ROOT_DIR" "workspace"` at line 82, `scan_scope "$project_dir" "project"` at line 88). Moving the workspace's own `ARCHITECTURE.md` to `docs/design.md` will make the workspace's own architecture doc disappear from discovery unless a `docs/design.md` (or equivalent) check is added — this is a workspace-scope consequence, not just the project-scope "don't force a convention" concern the issue frames it as. The acceptance criterion ("Governance discovery finds both old- and new-spelling files in a project") doesn't cover this workspace-scope regression; recommend widening it.
- `.agent/knowledge/inspiration_*_digest.md` files (e.g. `inspiration_ros2_agent_workspace_digest.md`, `inspiration_engram_digest.md`) contain historical, factual statements about other repos' `ROADMAP.md`/`ARCHITECTURE.md` files. These match the acceptance criterion's `grep` sweep but must not be rewritten — doing so would misstate what those external/historical snapshots actually said. The stated exemption list ("outside ADR bodies and historical work plans") doesn't cover them; recommend adding inspiration digests to the exemption.

### Recommendations

- Verify against the repo before merging (this review already caught two count/claim errors) rather than trusting the issue's numbers verbatim.
- Add `.agent/knowledge/inspiration_*_digest.md` to the acceptance criterion's exemption list alongside ADR bodies and historical work plans.
- Extend the "discovery accepts both spellings" acceptance test to also cover the workspace's own scan (root scope), not only a project fixture — otherwise `discover_governance.sh` output for the workspace itself loses its architecture-doc line after the move.

### Actions
- [ ] Add `.agent/knowledge/inspiration_*_digest.md` to the acceptance criterion's exemption list alongside ADR bodies and historical work plans.
- [ ] Extend the "discovery accepts both spellings" acceptance test to also cover the workspace's own scan (root scope), not only a project fixture — otherwise `discover_governance.sh` output for the workspace itself loses its architecture-doc line after the move.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 12:56 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed (Recommended): plan with both Issue Review actions — (1) the "accepts both spellings" test also covers the workspace's own scan (discover_governance.sh scan_scope runs on the workspace root too; after the move it must still find docs/design.md), (2) exempt .agent/knowledge/inspiration_*_digest.md from the old-path sweep — and the three corrections: discover_governance.sh / project_governance.md do not look for ROADMAP.md (only PRINCIPLES.md and ARCHITECTURE.md); nine skills read the principles, not eight; no ADR mentions these paths, so there is no ADR References work.

## Plan Authored
**Status**: complete
**When**: 2026-09-23 13:40 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-334/plan.md` at `26e871f`

Mechanical `git mv` of `ARCHITECTURE.md`→`docs/design.md`,
`docs/ROADMAP.md`→`docs/roadmap.md`, `docs/PRINCIPLES.md`→`docs/principles.md`;
`discover_governance.sh` gains new-spelling checks (accepts both) plus a new
test suite; `merge_pr.sh`/`update_roadmap.sh`/their tests get path fixes; a
~20-file reference sweep excludes ADR bodies, inspiration digests, and
historical work-plans. Owner decided CLAUDE.md stays at the root (retirement
is a separate later issue) — folded into the plan, no open questions remain.
