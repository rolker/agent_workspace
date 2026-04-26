# Plan: Port quality-doctrine batch from ros2_agent_workspace

## Issue

https://github.com/rolker/agent_workspace/issues/164

## Context

Port four upstream items (ros2_agent_workspace @ `395b1c5`, range `8465ebd...395b1c5`) bundled as a coherent quality doctrine + enforcement pass:

1. **AGENTS.md Quality Standard section** (upstream PR #438) — public-release framing
2. **plan-task `## During implementation` section** (upstream PR #450) — `--no-pr` flag is already present locally (commit `680d895`); only port the new section
3. **ADR-0008 cross-reference addendums** — port upstream's ADR-0012 content under the next-available local sequential number (per ADR-0001's "numbered sequentially" rule); generalize Context to drop upstream-specific PR #448 trigger
4. **triage-reviews column rename + tightened wording** (upstream PR #441) — preserve local Step 7 (Update progress.md) and `issue-*/plan.md` path convention

Per the review-issue comment: also update `.agent/knowledge/principles_review_guide.md` to add an ADR-0008 row (consequences-map requirement).

Local files diverge from upstream (git-bug-first lookup in plan-task; local Guidelines bullets in triage-reviews) — port by merging, not overwriting.

## Approach

Implement as four atomic commits on `feature/issue-164`, then a final commit for the consequences-map update. Single PR.

1. **Commit 1 — AGENTS.md Quality Standard** — Insert a new `## Quality Standard` section after `## Communication Standards`, before `## Tool Usage`. Replace upstream's "robot boats on open water" intro with a public-release framing. Adapt bullet 3 from "field fixes" to "code from outside the normal review path" (covers field imports, cherry-picks, copy-pastes, hurried agent commits).
2. **Commit 2 — plan-task `## During implementation` section** — Append upstream's section after Step 9, before `## Guidelines`. Do not touch `--no-pr` (already present from `680d895`). Use upstream's exact `## Implementation Notes` capitalization. Adapt path references to local `issue-*/plan.md` convention (upstream uses `PLAN_ISSUE-*.md`).
3. **Commit 3 — ADR-0008** — Create `docs/decisions/0008-permit-cross-reference-addendums-in-adrs.md` (next available sequential number; ADR-0001 mandates sequential numbering). Port upstream's ADR-0012 content except the Context: drop the PR #448-specific trigger paragraph; reframe motivation around the inherited-ADRs discoverability gap (older ADRs lack forward links). Update References to point at agent_workspace ADRs only. Internal cross-references (`ADR-0011`) update to existing local ADRs that illustrate the same scoped-exception pattern, or are kept generic.
4. **Commit 4 — triage-reviews tightening** — In `.claude/skills/triage-reviews/SKILL.md`: rename column `Reasoning` → `Justification`; change example wording `Why it's not applicable` → `Specific reason the failure mode cannot occur`; add upstream's "Justify every false positive" bullet to the Guidelines section (after the existing `Governance alignment` bullet) but **keep** local's `No GitHub review actions` and `Plan-first workflow PRs` bullets and the `issue-*/plan.md` path.
5. **Commit 5 — consequences map update** — Add ADR-0008 row to the ADR Applicability table in `.agent/knowledge/principles_review_guide.md`.

Run `make lint` (pre-commit) before pushing. Verify final grep: no remaining "Reasoning" column header in triage-reviews; no upstream PR #448 reference in ADR-0008.

## Files to Change

| File | Change |
|------|--------|
| `AGENTS.md` | New `## Quality Standard` section between Communication Standards and Tool Usage (~12 lines) |
| `.claude/skills/plan-task/SKILL.md` | Append `## During implementation` section (~35 lines) before `## Guidelines` |
| `docs/decisions/0008-permit-cross-reference-addendums-in-adrs.md` | New file (~80 lines), Context generalized for inherited-ADR setting |
| `.claude/skills/triage-reviews/SKILL.md` | Column rename + wording tighten + new Guidelines bullet (preserve local extensions) |
| `.agent/knowledge/principles_review_guide.md` | Add ADR-0008 row to ADR Applicability table |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Capture decisions, not just implementations | ADR-0012 is the recorded decision; Quality Standard codifies behavioral norms in AGENTS.md |
| A change includes its consequences | Step 5 adds the ADR-0012 row to the review guide as part of this PR (not deferred) |
| Workspace vs. project separation | All edits are workspace-generic; Quality Standard reframed away from upstream's robotics phrasing |
| Improve incrementally | Atomic commits per item make selective revert and review tractable despite four-item bundle |
| Enforcement over documentation | Item #1 (Quality Standard) is doctrine; item #4 (triage-reviews tightening) is its enforcement leg in the dismissal flow |
| Only what's needed | Each item solves a concrete pain identified in the inspiration digest; no speculative additions |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0001 (Adopt ADRs) | Yes | New ADR-0008 follows Status / Context / Decision / Consequences / References structure; numbering is sequential per ADR-0001's "numbered sequentially (0001, 0002, ...)" rule (ADR-0008 is the next available local number; the missing 0008 slot in `docs/decisions/` is filled rather than skipped) |
| ADR-0006 (Shared AGENTS.md) | Yes (low impact) | Verified pre-flight: framework adapters (`CLAUDE.md`, `.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`) do not reference AGENTS.md section names by title — adding a new section requires no adapter edits. Re-confirm before merge |
| ADR-0008 (this PR) | Yes — being added | Once accepted, permits the deferred ADR-0001/0002 status-line addendums (intentionally held for a follow-up PR) |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| An ADR in `docs/decisions/` | `principles_review_guide.md` ADR table | Yes — Step 5 |
| `AGENTS.md` | Framework adapters if affected | No update needed (verified above) |
| A framework skill (`.claude/skills/...`) | That framework's adapter file; regenerate skills if needed | No update needed (CLAUDE.md doesn't enumerate skills; not added to a workflow list) |

## Open Questions

- None blocking. The Context generalization for ADR-0012 is the only judgment call — propose draft text in the commit and let review iterate if the framing reads off.

## Estimated Scope

Single PR, 5 atomic commits, ~150 net lines added.
