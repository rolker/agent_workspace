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

1. **`.claude/skills/start-task/SKILL.md` — step 4**: replace
   `EnterWorktree(path="$WT")` with `cd "$WT"`. Keep step 3 (worktree path
   resolution) and step 1 ("refuse if already in a worktree") unchanged —
   the nested-worktree guard is still useful, the rationale just shifts
   from "EnterWorktree refuses" to "don't nest".
2. **`.claude/skills/start-task/SKILL.md` — step 5 ("Confirm to the user")**:
   drop the "via EnterWorktree" framing; the confirmation message is the
   same content.
3. **`.claude/skills/start-task/SKILL.md` — "Exit semantics" section**:
   rewrite. Today it says "the worktree was created outside of EnterWorktree
   so ExitWorktree will refuse to remove it" and prescribes
   `ExitWorktree(action="keep")`. After this change, exit is just `cd -`
   (or any `cd` away); delete is `worktree_remove.sh --issue <N> --type
   <type>` or `make merge-pr PR=<N>`.
4. **`.claude/skills/start-task/SKILL.md` — "Why not just call EnterWorktree
   directly?" section**: keep the policy-enforcement justification (issue
   lookup, branch naming, allowlist, workflow scaffolding, plan-file PR,
   cross-repo PR targeting). Remove the closing sentence about
   "EnterWorktree only for the session-level switch — which gives smoother
   CWD handling and proper cache coherence on exit" — it's the claim
   discarded by this issue.
5. **`.claude/skills/start-task/SKILL.md` — "When not to use" first
   bullet**: today says "The session is already inside a worktree.
   EnterWorktree refuses in that case." Reword: "/start-task refuses in
   that case (step 1 detects it)" — the behaviour is the same, the cause
   is the skill, not the native tool.
6. **`.claude/skills/start-task/SKILL.md` — "Manual verification" cases
   1–3**: each ends with "EnterWorktree succeeds; session lands in the new
   worktree." Replace with "the `cd` command succeeds; session lands in
   the new worktree." Case 4 (glob safety) is unrelated and unchanged.
7. **`CLAUDE.md` — lines 50–56 ("Worktree entry" bullet under Claude-Specific
   Notes)**: rewrite to describe the uniform `cd` flow. Drop the "enters
   via the native EnterWorktree tool ... with proper cache coherence in
   one tool call" framing. Keep the project-vs-workspace coverage point
   (still true: all policy applies, all types covered) and the
   Codex/Gemini caveat (still true).
8. **`AGENTS.md` — add "Worktree Entry" subsection**: insert under
   `## Worktree Workflow` (after the existing `### Skill Worktree
   Exception` subsection, before `## Issue-First Policy`). Content per
   the issue body's "Convention to document" block: skills auto-entering
   a worktree use `cd <path>`, not EnterWorktree, with one-line rationale
   and the exit/delete pointers.
9. **Manual verification** in a fresh session after the changes land:
   re-run the three SKILL.md cases (`--issue --type workspace`,
   `--skill research --type workspace`, re-entry) plus the case the
   issue exists for: `--issue --type project` against the project repo
   (must end in the project worktree, not the workspace cwd).

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/start-task/SKILL.md` | Step 4 (cd, not EnterWorktree); step 5 (drop EnterWorktree framing); "Exit semantics" section (rewrite for cd flow); "Why not just call EnterWorktree directly?" (drop cache-coherence claim); "When not to use" first bullet (reword); "Manual verification" cases 1–3 (cd, not EnterWorktree) |
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
