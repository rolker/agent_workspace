# Plan: inspiration-tracker: registry edits bypass skill worktree

## Issue

https://github.com/rolker/agent_workspace/issues/21

## Context

The inspiration-tracker skill's "add" flow (step 11 in SKILL.md) edits
`.agent/knowledge/inspiration_registry.yml` without specifying that this
must happen inside the skill worktree. The worktree is created in step 3,
but the "add" flow jumps from step 1 directly to step 11 — skipping step 3.
This leaves registry edits as uncommitted changes on `main`.

Evidence: the `gstack` entry was added to the registry in the main tree
and is currently dirty in `git status`.

## Approach

1. **Reorder the add flow in SKILL.md** — Insert a worktree step between
   the current steps 4 ("Configure type-specific fields") and 5 ("Add to
   registry"). The add flow should create/enter the skill worktree before
   writing the registry file, then commit the registry change in the
   worktree.

2. **Commit the orphaned gstack registry entry** — Move the dirty
   `inspiration_registry.yml` change from `main` into this PR branch so
   it goes through a proper PR.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/inspiration-tracker/SKILL.md` | Add worktree creation step between steps 4 and 5 of the add flow |
| `.agent/knowledge/inspiration_registry.yml` | Commit the existing gstack entry (already written, just not committed) |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | The fix is documentation-only (SKILL.md instructions). Enforcement would require the skill runner to check worktree state — out of scope for this fix, acceptable since the skill is interactive. |
| A change includes its consequences | The orphaned registry edit is included in this PR. No other consequences identified. |
| Improve incrementally | Minimal change — reorder one section of the skill doc. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0002 — Worktree isolation | Yes | This fix ensures the add flow respects worktree isolation |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `.claude/skills/inspiration-tracker/SKILL.md` | Claude adapter (regenerate skills if trigger changes) | No — trigger/description unchanged |

## Open Questions

None — the fix is straightforward.

## Estimated Scope

Single PR.
