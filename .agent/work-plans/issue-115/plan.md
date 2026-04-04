# Plan: Enable offline plan-review cycle via git-bug and local file paths

## Issue

https://github.com/rolker/agent_workspace/issues/115

## Context

The `plan-task` and `review-plan` skills currently require GitHub network
access for two operations that could be local:

1. **Issue metadata** — both skills call `gh issue view` for title/body.
   `worktree_create.sh` already has a git-bug-first pattern (lines 270-284)
   that falls back to `gh`.

2. **PR as interchange** — `plan-task` creates a draft PR (step 8) and
   `review-plan` only accepts a PR number as input. The plan is committed
   locally at `.agent/work-plans/issue-<N>/plan.md`, so a local path or
   issue number should suffice.

PR #120 (merged) rewired both skills to write `progress.md`. The current
code is on `main` at `b466907`.

## Approach

1. **Extract a reusable git-bug-first issue-read pattern** — Add a
   documented code block to both skills' step 1 that mirrors
   `worktree_create.sh`: try `git bug select <N> && git bug show`, parse
   title/body/state, `git bug deselect`, then fall back to `gh issue view`
   if git-bug didn't provide the data. This is instruction-level only (SKILL.md
   prose), not a shared script — skills are markdown instructions, not
   executable code.

2. **plan-task: make PR creation optional** — In step 8, add a condition:
   skip PR creation when `gh` is unavailable (test with
   `command -v gh &>/dev/null && gh auth status &>/dev/null`) or when the
   user passes `--no-pr`. The plan is still committed locally. Update the
   Usage section to document `--no-pr`.

3. **review-plan: accept file path or issue number** — Change step 1 to
   accept three input forms:
   - `<pr-number>` (existing behavior, unchanged)
   - `<file-path>` (direct path to plan.md)
   - `--issue <N>` (resolves to `.agent/work-plans/issue-<N>/plan.md`)
   When using file path or issue number, read issue context from git-bug
   first, fall back to `gh`. Update the Usage section.

4. **review-plan: git-bug-first for issue context** — In step 2, apply the
   same git-bug-first pattern for reading issue metadata.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/plan-task/SKILL.md` | Step 1: git-bug-first issue read. Step 8: conditional PR creation. Usage: document `--no-pr`. |
| `.claude/skills/review-plan/SKILL.md` | Usage + Step 1: accept file path / `--issue <N>`. Steps 1-2: git-bug-first issue read. |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Minimal change — two files, instruction-level only, no new scripts |
| Enforcement over documentation | git-bug fallback is a resilience pattern, not a rule needing enforcement |
| A change includes its consequences | Consequences table below covers affected docs |
| Improve incrementally | Extends existing git-bug pattern to two more skills |
| Workspace improvements cascade | Pattern is portable — any framework's plan skills benefit |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0010 (git-bug) | Yes | git-bug tried first, `gh` fallback, graceful degradation if neither available |
| ADR-0006 (shared AGENTS.md) | No | Changes are skill-specific, not shared instruction changes |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `plan-task` skill usage (new `--no-pr` flag) | Skill description if it references PR creation as mandatory | Yes — step 2 |
| `review-plan` skill usage (new input forms) | Skill description in frontmatter if needed | Yes — step 3 |

## Open Questions

- None. The git-bug pattern is well-established in `worktree_create.sh` and
  the acceptance criteria are clear.

## Estimated Scope

Single PR.
