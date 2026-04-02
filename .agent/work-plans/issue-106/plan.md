# Plan: cross_model_review.sh: add sync mode for sandboxed environments

## Issue

https://github.com/rolker/agent_workspace/issues/106

## Context

`cross_model_review.sh` runs Gemini CLI in a tmux session for adversarial PR
review. Claude Code's sandbox blocks tmux, so the review-code skill's deep-tier
adversarial specialist silently fails with "Cross-model review unavailable."

The script needs a sync mode that runs Gemini directly (no tmux) so it works
in sandboxed environments. The tmux path stays for interactive/background use.

## Approach

1. **Add `--sync` flag to argument parsing** — New optional flag. When passed,
   skip tmux entirely and run Gemini synchronously.

2. **Auto-detect tmux unavailability** — Change the tmux dependency check
   (lines 61-64) from hard exit to setting a `USE_SYNC` flag. If tmux is
   missing or blocked, fall back to sync mode automatically. Print an info
   message when auto-falling back.

3. **Add sync execution path** — After prompt generation (line 182), branch
   on `USE_SYNC`:
   - **Sync**: run `gemini -p < prompt > findings 2>&1` directly, append
     completion/failure marker, then report findings path.
   - **Tmux** (existing): launch tmux session as today.

4. **Update output format** — Sync mode outputs `MODE=sync` and
   `FINDINGS_FILE=<path>` (no `TMUX_SESSION`). Tmux mode output unchanged.

5. **Update AGENTS.md script table description** — Change "Launch Gemini CLI
   adversarial review in tmux" to reflect both modes.

6. **Update review-code SKILL.md** — The deep-tier adversarial section
   references the script. Add a note that sync mode is used automatically in
   sandboxed environments.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/cross_model_review.sh` | Add `--sync` flag, auto-detect fallback, sync execution path |
| `AGENTS.md` | Update script table description (line 279) |
| `.claude/skills/review-code/SKILL.md` | Note sync mode availability near line 232 |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Minimal change: one flag, one branch, auto-detect. No new dependencies or abstractions |
| Workspace vs. project separation | Script is workspace infrastructure, change stays in workspace repo |
| Enforcement over documentation | Auto-detection enforces the fallback; agents don't need to know about the flag |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0003 (project-agnostic) | No | Script is already project-agnostic |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Script output format (new MODE= line) | Callers parsing script output | Yes — review-code SKILL.md |
| Script description in AGENTS.md | Copilot instructions if they reference it | Checked — no reference |

## Open Questions

None.

## Estimated Scope

Single PR.
