# Plan: /start-task — use Bash `cd` uniformly instead of EnterWorktree

## Issue

https://github.com/rolker/agent_workspace/issues/204

## Context

`/start-task` step 4 calls `EnterWorktree(path="$WT")`. EnterWorktree only
accepts paths registered in `git worktree list` for the **current** repo,
so it rejects project worktrees (which belong to the project repo, not the
workspace). Today this causes `/start-task --type project` to half-complete:
the worktree exists on disk but the session stays in the workspace cwd.

The issue (after review) settles on uniform Bash `cd` — drop EnterWorktree
from `/start-task` entirely. One mechanism across `--type workspace`,
`--type project`, and `--skill`. The session-end cleanup prompt is given up
in exchange for `worktree_remove.sh --skill <name>` as the explicit
deletion path (which is already the documented cleanup for skill
worktrees). Cache-coherence and original-dir-return claims tied to
EnterWorktree did not survive two days of side-by-side use.

## Approach

1. **`.claude/skills/start-task/SKILL.md`** — edit every EnterWorktree/ExitWorktree mention. Touchpoints (re-grepped after review-plan flagged the original list was incomplete):
   - Frontmatter `description:` (line 3): drop "via the native EnterWorktree tool" framing
   - "When not to use" 1st bullet (line 19): replace "EnterWorktree refuses" rationale with "avoid nested worktrees"
   - "When not to use" 3rd bullet (line 21): rejustify the Claude-only restriction in terms of the persistent-shell mechanism (Codex/Gemini use per-command shells)
   - Step 3 inline comment (line 90): "Do not call EnterWorktree" → "Do not proceed to step 4"
   - Step 4 (lines 108–118): rename heading from "Enter the worktree via the native tool" to "Enter the worktree"; replace `EnterWorktree(path="$WT")` with `cd "$WT"`; replace the EnterWorktree-specific rationale paragraph with a `cd`-rationale paragraph; rewrite (not name-swap) the failure-mode paragraph for the `cd` failure mode
   - Step 5 (line 122): "After EnterWorktree returns successfully" → "After `cd` returns successfully"
   - Manual verification cases 1, 3 (lines 132, 136): swap EnterWorktree/ExitWorktree mentions for `cd` / `cd -`; **add a new case 3 for `--type project`** (the failure case the issue exists for) and renumber re-entry to case 4, glob safety to case 5
   - "Exit semantics" section (lines 140–144): rewrite for the `cd -` flow; drop ExitWorktree references entirely
   - "Why not just call EnterWorktree directly?" section (lines 146–159): retitle to "Why a wrapper around `cd <path>`?"; reframe content as "what does the wrapper add over plain `cd`" (worktree_create.sh policy + path resolution); drop the cache-coherence claim
   - "Implementation note" (line 163): "invokes EnterWorktree in section 4" → "runs `cd` in section 4"
2. **`CLAUDE.md` — lines 50–56**: rewrite the "Worktree entry" bullet under Claude-Specific Notes for the uniform `cd` flow. Drop the "EnterWorktree native tool ... cache coherence ... in one tool call" framing. Keep the project-vs-workspace coverage point (still true: all policy applies, all types covered) and the Codex/Gemini caveat (rejustified in terms of per-command shells).
3. **`AGENTS.md` — add `### Worktree Entry` subsection** inside `## Worktree Workflow`, placed after the existing `**Multi-project**` paragraph and before the `See WORKTREE_GUIDE.md` line was the original target; revised target is the same position (just before `## Issue-First Policy`). Content: skills auto-entering a worktree use `cd <path>`, with one-paragraph rationale (native tools key off `git worktree list` of the current repo, which rules them out for project worktrees) and the exit/delete pointers.
4. **Manual verification** in a fresh session after the PR merges: run the five SKILL.md cases (`--issue --type workspace`, `--skill research --type workspace`, `--issue --type project`, re-entry, glob safety). The `--type project` case is the new addition and is the case the issue exists for.

## Decisions on review-plan findings (resolved during implementation)

- **Section retitle** (finding 2): renamed to "Why a wrapper around `cd <path>`?" (matches new step-4 mechanic).
- **Step-4 failure paragraph** (finding 3): rewritten for the `cd` failure mode (filesystem race, permissions, externally-removed dir) rather than name-swapped.
- **"When not to use" 3rd bullet** (finding 4): bullet **stays**, rejustified in terms of the persistent-shell mechanism (Claude Code keeps shell state across tool calls; Codex/Gemini use per-command shells, so they need `worktree_enter.sh --print-path` / `--shell-snippet` to communicate the cwd back).
- **Memory file timing** (finding 5): post-merge follow-up confirmed. The memory file (`feedback-enterworktree-cross-repo.md`) lives outside the workspace repo (in `~/.claude/projects/.../memory/`), so it isn't bundleable into this PR even if we wanted to. Will note in the PR description that the memory update is deferred and tracked separately.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/start-task/SKILL.md` | Frontmatter description; "When not to use" bullets 1 and 3; step 3 inline comment; step 4 (heading rename + body rewrite + failure-mode paragraph rewrite); step 5 (cd, not EnterWorktree); Manual verification (rewrite cases 1, 3; add new project case; renumber); Exit semantics (rewrite for cd flow); "Why a wrapper..." section (retitle + reframe); Implementation note |
| `CLAUDE.md` | Lines 50–56 worktree-entry bullet: rewrite for uniform `cd` flow |
| `AGENTS.md` | Add `### Worktree Entry` subsection under `## Worktree Workflow` |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Plan removes a conditional, not adds one. The change is net-negative on complexity in `/start-task`. |
| A change includes its consequences | Three-file edit set covers the doc surface that mentions EnterWorktree in this flow. WORKTREE_GUIDE.md, Copilot/Gemini adapters, and AGENT_ONBOARDING.md were grepped — none reference the EnterWorktree-via-/start-task pattern, so no further fan-out. Memory file follow-up is captured as a post-merge note (out of scope here). |
| Capture decisions, not just implementations | The convention lands in AGENTS.md ("Worktree Entry"); rationale lives there and in the issue body (which records the split-vs-uniform decision). |
| Workspace vs. project separation | Preserved — project worktrees still belong to the project repo; this just changes how the session navigates. |
| Primary framework first | Trades a Claude-native tool call for a portable `cd`. Justified by the "imperceptible benefit" data in the issue; documented in the issue body so the choice isn't lost. |
| Enforcement over documentation | Convention is doc-only. Acceptable because `/start-task` is the single entry point; the only way a future skill could regress is by writing its own auto-enter logic, which is rare and reviewable. Not introducing a hook for this. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0002 — Worktree isolation | No (substantively) | Isolation preserved; only the session-entry mechanism changes |
| 0003 — Project-agnostic workspace | No | Changes are generic; no project-specific content added |
| 0004 — Enforcement hierarchy | Light touch | New convention is documentation-only at the AGENTS.md layer. The `/start-task` skill is the single entry point that enforces the convention automatically. No hook needed. |
| 0006 — Shared AGENTS.md | **Yes** | New convention added to `AGENTS.md` (shared layer). `CLAUDE.md` adapter updated in the same PR to match — its current text describes the EnterWorktree-native flow and becomes false otherwise. Copilot/Gemini adapters and `AGENT_ONBOARDING.md` were checked — none reference EnterWorktree, no edits needed. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `AGENTS.md` | Framework adapters if affected | Yes — CLAUDE.md (lines 50–56). Copilot/Gemini adapters grepped, no mentions. |
| A framework skill (`.claude/skills/start-task/SKILL.md`) | That framework's adapter file | Yes — CLAUDE.md is the Claude adapter and is part of the edit set |
| Worktree scripts | `.agent/WORKTREE_GUIDE.md`; AGENTS.md worktree section | N/A — no script changes; AGENTS.md edit is a new subsection. WORKTREE_GUIDE.md grepped (no EnterWorktree mentions, no edit needed) |

## Open Questions

- **Issue title**: still reads "/start-task --type project: use Bash cd instead of EnterWorktree". After the proposal generalized to uniform `cd`, the `--type project` framing in the title is narrower than the change. Consider updating to "/start-task — use Bash cd uniformly instead of EnterWorktree" before merging. Low priority; not blocking.
- **Memory file**: `feedback-enterworktree-cross-repo.md` describes the workaround this issue makes standard. The issue body lists this as a "follow-up after merge". Confirm at review time that we want it post-merge rather than in-PR — keeping it post-merge means the PR is purely workspace-repo changes, no memory-system churn.

## Estimated Scope

Single PR. Three files, all docs/instructions (no executable code, no tests). Manual verification only — no CI test exists for `/start-task` flow (acknowledged in SKILL.md "Manual verification" preamble and issue #188).
