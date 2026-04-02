# Plan: Generalize cross-model review to dispatch dynamically based on calling agent

## Issue

https://github.com/rolker/agent_workspace/issues/114

## Context

`cross_model_review.sh` is hardcoded to launch Gemini CLI. The review-code
skill's Deep tier dispatches only to Gemini as the cross-model reviewer.
With three capable CLI agents (Claude, Gemini, Codex), the system should
dynamically select two reviewers that aren't the caller.

The script already has two execution modes (tmux and sync from #106). The
generalization needs to add target-agent selection while preserving both
modes.

## Approach

1. **Add agent config table to `cross_model_review.sh`** — Define a
   `declare -A` map of agent keys to binary names, discovery paths, and
   invocation syntax. Four agents:
   - `gemini`: `gemini -p < prompt > findings`
   - `codex`: `codex exec "$(cat prompt)" > findings` (needs verification)
   - `claude`: `claude -p < prompt > findings`
   - `copilot`: needs invocation verification

2. **Add `--agent <target>` flag** — New required-when-not-default argument.
   Default remains `gemini` for backward compatibility. The flag selects
   which agent config to use for binary discovery and invocation.

3. **Generalize binary discovery** — Replace the hardcoded Gemini binary
   search with a per-agent lookup. Each agent has its own PATH check and
   fallback locations (e.g., `~/.nvm/versions/node/*/bin/codex`,
   `~/.local/bin/claude`).

4. **Generalize artifact naming** — Change `review-gemini-prompt.md`,
   `review-gemini-findings.md`, and `review-gemini-<issue>` tmux session
   names to `review-<agent>-*`.

5. **Update review-code skill (step 5e)** — Replace the hardcoded Gemini
   dispatch with a dynamic loop:
   ```
   CALLER=$AGENT_FRAMEWORK  # check env first, fall back to detect_cli_env.sh
   ALL_REVIEWERS=(gemini codex claude copilot)
   for agent in ALL_REVIEWERS where agent != CALLER:
       launch cross_model_review.sh --pr <N> --agent <agent>
   ```
   Rename section from "Gemini Adversarial Specialist" to "Cross-Model
   Adversarial Specialist". Each invocation is independent — one failing
   doesn't block the other.

6. **Update report template** — Rename "Cross-Model Review (Gemini)" section
   to "Cross-Model Reviews" with sub-sections per agent that was dispatched.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/cross_model_review.sh` | Add `--agent` flag, agent config table, generalized discovery and invocation |
| `.claude/skills/review-code/SKILL.md` | Replace Gemini-specific step 5e with dynamic multi-agent dispatch; update report template |
| `.agent/knowledge/review_depth_classification.md` | Update if it references Gemini specifically |
| `AGENTS.md` | Update script table description if wording changes |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Single script handles all agents via config table — no new scripts or abstractions |
| Workspace vs. project separation | All changes are workspace infrastructure |
| Primary framework first, portability where free | Claude remains the primary framework; this makes cross-model review portable across callers |
| A change includes its consequences | Skill, script, and docs updated together |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0003 | Yes | Agent configs are generic, not project-specific |
| ADR-0005 | Yes | Cross-model review is fast feedback, not load-bearing enforcement |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `cross_model_review.sh` interface | review-code SKILL.md (caller) | Yes |
| review-code SKILL.md report template | Any docs referencing the report format | Yes (review depth classification doc) |
| Script description in AGENTS.md | Other adapter files if they reference it | Yes (checked — only AGENTS.md) |

## Open Questions

- What is the exact non-interactive invocation syntax for Codex CLI and
  GitHub Copilot CLI? Both need verification from real sessions.
- Should dispatch pick exactly two non-caller agents, or all available
  non-caller agents? Two keeps review cost bounded; all-available
  maximizes coverage but adds cost as more agents are onboarded.

## Estimated Scope

Single PR.
