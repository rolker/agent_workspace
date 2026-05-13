---
issue: 204
---

# Issue #204 — /start-task --type project: use Bash cd instead of EnterWorktree (cross-repo limitation)

## Plan
**Status**: complete
**When**: 2026-05-13 16:30
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-204/plan.md`.

Replace `EnterWorktree(path="$WT")` in `/start-task` step 4 with `cd "$WT"`,
uniformly across all modes. Update `.claude/skills/start-task/SKILL.md`
(step 4 + exit semantics + verification cases), `CLAUDE.md` lines 50–56
(adapter description), and add a `### Worktree Entry` subsection to
`AGENTS.md`. No script changes, no hook changes — `/start-task` is the
single entry point that enforces the new convention.

## Review (plan)
**Status**: complete
**When**: 2026-05-13 17:00
**By**: Claude Code Agent (claude-opus-4-7)

Self-review on PR #205: structurally sound, but file-targeting needs work.
Plan undercounted the SKILL.md touchpoint list — re-grep found five
additional EnterWorktree/ExitWorktree references (frontmatter description,
"When not to use" 3rd bullet, step 3 inline comment, step 4 failure-mode
paragraph, Implementation note). Also flagged: section retitle for "Why
not just call EnterWorktree directly?", failure-mode paragraph needs
rewrite not name-swap, "When not to use" 3rd bullet rationale needs
rejustification, and memory file timing.

Plan updated inline (`plan.md`) before implementation began to reflect
the expanded touchpoint list and decisions on findings 2–5.

## Implement
**Status**: complete
**When**: 2026-05-13 17:15
**By**: Claude Code Agent (claude-opus-4-7)

Three files edited per the (updated) plan:
- `.claude/skills/start-task/SKILL.md` — ten distinct touchpoints (frontmatter,
  two "When not to use" bullets, step 3 inline comment, step 4 heading + body
  + failure paragraph, step 5, manual verification (rewrite 1, 3; add project
  case; renumber), exit semantics, "Why a wrapper..." section (retitled +
  reframed), implementation note). Post-edit grep shows the only remaining
  EnterWorktree mentions are explanatory: line 116 explains *why* `cd` works
  uniformly (EnterWorktree wouldn't), line 136 explains what the new project
  verification case validates. Both intentional.
- `CLAUDE.md` lines 50–58 — worktree-entry bullet rewritten for uniform `cd`
  flow; Codex/Gemini caveat rejustified in terms of per-command shells.
- `AGENTS.md` — new `### Worktree Entry` subsection inside `## Worktree
  Workflow`, placed before `## Issue-First Policy`. Covers the convention,
  the rationale (native tools key off `git worktree list` of the current
  repo), and the exit/delete pointers.

No script changes. No hook changes. Manual verification (the five SKILL.md
cases) is post-merge work since `/start-task` cannot be invoked from inside
an existing worktree (it refuses; this is step 1 of the skill).

Follow-up after merge (out of scope here): update
`feedback-enterworktree-cross-repo.md` in `~/.claude/projects/.../memory/`
— the workaround it describes is now the standard, so the memory should be
retired or rewritten as a historical note.
