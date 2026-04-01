# Plan: Research skill: fix project worktree path and per-topic staleness tracking

## Issue

https://github.com/rolker/agent_workspace/issues/45

## Context

The `/research` skill has two problems:

1. **Project worktree instructions reference ROS-specific `--type layer`** that doesn't
   exist in this general-purpose workspace. The workspace scope already works correctly
   with `--skill research --type workspace`. The project scope needs `--type project`.

2. **Single digest-level timestamp hides per-entry staleness.** Adding one topic today
   updates `<!-- Last updated: YYYY-MM-DD -->`, making the entire digest appear fresh.
   The `--refresh` workflow has no way to identify which specific entries are stale.

The existing workspace digest (`.agent/knowledge/research_digest.md`) has 14 entries,
all with `**Added**` dates but no `**Last verified**` dates.

## Approach

1. **Update SKILL.md project-scope worktree instructions** — Replace the `--type layer`
   worktree commands with `--type project` equivalents. Remove references to layer/manifest
   repo concepts that don't apply to general-purpose workspaces.

2. **Add per-entry `**Last verified**` field to the digest format** — Update the format
   template in SKILL.md to include `**Last verified**: YYYY-MM-DD` alongside the existing
   `**Added**` date.

3. **Update `--refresh` workflow to use per-entry staleness** — Modify the refresh
   instructions to: check each entry's `Last verified` date (or `Added` if no verification
   yet), identify entries older than 30/90 days, and prioritize stale entries for refresh.

4. **Backfill existing digest entries** — Add `**Last verified**: YYYY-MM-DD` to all 14
   existing entries in `research_digest.md`, using their `Added` date as the initial value
   (they haven't been verified since creation).

5. **Change top-level timestamp semantics** — The `<!-- Last updated -->` comment becomes
   the date of the last `--refresh` run, not the last topic addition. Update the comment
   text to reflect this.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/research/SKILL.md` | Fix project worktree instructions; update digest format template; update `--refresh` workflow |
| `.agent/knowledge/research_digest.md` | Backfill `Last verified` dates; update top-level timestamp comment semantics |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Workspace vs. project separation | The fix makes the skill work with `--type project` worktrees instead of ROS-specific layer worktrees, improving project-agnosticism |
| A change includes its consequences | Both the skill instructions and the existing digest are updated together |
| Only what's needed | Option 3 from the issue (both timestamps) is adopted as it's the clearest approach. No new tooling or automation added |
| Enforcement over documentation | Per-entry dates are still documentation-level. Mechanical enforcement (e.g., a script that flags stale entries) could be a follow-up but is not needed now |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0003 (project-agnostic) | Yes | Removing ROS-specific `--type layer` references makes the skill work for any project type |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Digest format template in SKILL.md | Existing digest entries | Yes (step 4) |
| Top-level timestamp semantics | SKILL.md comments about staleness checking | Yes (step 5) |
| Project worktree instructions | Any other docs referencing research project worktrees | No other references found |

## Open Questions

None. The approach is straightforward and all acceptance criteria map directly to plan steps.

## Estimated Scope

Single PR.
