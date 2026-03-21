# Plan: Improve inspiration-tracker: digest-first commit and issue-only decisions

## Issue

https://github.com/rolker/agent_workspace/issues/17

## Context

The `inspiration-tracker` skill (`.claude/skills/inspiration-tracker/SKILL.md`)
currently writes the digest only after user decisions (step 8) and offers a
"Port/Adapt now" option that turns a survey skill into an implementation session.
The first real run exposed friction: two separate PRs, a second skill worktree
just for the digest, and implementation work out of scope for discovery.

The skill file is a single markdown document (~314 lines) that defines the
agent's behavior through numbered steps.

## Approach

1. **Create skill worktree early (new step 2.5)** — After ensuring the local
   copy (step 2) and before gathering GitHub context, create and enter a
   `--skill inspiration-tracker` worktree. This gives the skill a branch to
   commit the digest to throughout the run. Move this guidance into the steps
   rather than relying on the agent to figure it out at commit time.

2. **Add digest checkpoint after presenting findings (step 6)** — After step 6
   (present findings interactively), commit the digest with the activity
   snapshot, upstream SHA, and raw findings list. This preserves the research
   even if the conversation ends before decisions are made. Label as
   "initial commit" in the digest.

3. **Replace "Port/Adapt now" with "Open issue"** — In step 6, change the
   decision options from four to three:
   - **Open issue** — create a workspace issue with context
   - **Skip** (with reason) — record in digest
   - **Defer** — record in digest, resurface next run

4. **Simplify step 7 (act on decisions)** — Remove the "Port/Adapt now"
   implementation block entirely. Keep only the "Open issue" and
   "Skip/Defer" paths. The open-issue template already exists and works.

5. **Update step 8 (update digest)** — Change from "write the digest" to
   "update the digest with decisions". The digest already exists from the
   checkpoint in step 6; this step adds the user's skip/defer/issue
   decisions and amends or creates a new commit.

6. **Add step 8.5: push and create PR** — Push the skill branch and create
   a PR for the digest update. This formalizes the single-PR-per-run pattern.

7. **Update guidelines** — Revise the "Skill worktree for digest commits"
   guideline to reflect that the worktree is created at the start, not as an
   afterthought. Remove references to porting worktrees.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/inspiration-tracker/SKILL.md` | All changes above — restructure steps 6-8, add worktree creation step, update guidelines |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Minimal change — same file, same structure, just reordering and simplifying steps |
| A change includes its consequences | No other files reference these internal step numbers; the skill is self-contained |
| Improve incrementally | Small, focused refinement based on real usage feedback |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0002 — Worktree isolation | Yes | Skill already uses worktrees; plan makes the timing explicit |
| 0006 — Shared AGENTS.md | No | No AGENTS.md changes needed |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Skill step numbering | Nothing external — steps are internal to the skill | N/A |
| Decision options (remove "Port/Adapt now") | Nothing — no external code references these options | N/A |

## Open Questions

None — the issue is well-scoped from the discussion.

## Estimated Scope

Single PR, single file change.
