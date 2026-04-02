# Plan: Investigate onboarding OpenAI Codex CLI as agent framework

## Issue

https://github.com/rolker/agent_workspace/issues/107

## Context

Codex already reads `AGENTS.md`, but the workspace does not treat it as a
first-class framework. Current gaps include missing Codex entries in the
adapter tables, no identity/config mappings in the framework scripts, no
Codex runtime detection path, and stale onboarding references that would make
Codex support drift-prone even if added.

## Approach

1. **Verify Codex runtime facts** - Confirm the actual install path, session
   markers, and model-reporting behavior from a real Codex session or
   official OpenAI docs before changing detection logic.
2. **Add Codex to the shared entry points** - Update `AGENTS.md` and
   `.agent/AI_RULES.md` so Codex appears in the framework adapter tables and
   the workspace no longer treats it as "Other".
3. **Choose the adapter shape** - Keep ADR-0006 intact by using `AGENTS.md`
   for shared rules and only adding a thin Codex adapter file if Codex needs
   framework-specific setup or usage notes.
4. **Extend identity support** - Add Codex to
   `.agent/scripts/framework_config.sh`,
   `.agent/scripts/detect_cli_env.sh`,
   `.agent/scripts/detect_agent_identity.sh`, and
   `.agent/scripts/set_git_identity_env.sh` so explicit and auto-detected
   Codex sessions resolve to a stable name, email, and model flow.
5. **Repair onboarding docs** - Update `.agent/AGENT_ONBOARDING.md` and
   `.agent/AI_IDENTITY_STRATEGY.md` to include Codex as a host-based
   framework and remove stale adapter references that already point to
   missing files.
6. **Check workflow consequences** - Verify the commit-identity hook,
   worktree automation, and draft PR signature paths still behave correctly
   when Codex is the active framework.
7. **Validate end-to-end in Codex** - Run the workspace flow from a Codex
   session: identity setup, worktree creation, `gh` usage, and documentation
   behavior, then document any Codex-specific limitations.

## Files to Change

| File | Change |
|------|--------|
| `AGENTS.md` | Add Codex to the adapter table and keep framework guidance accurate |
| `.agent/AI_RULES.md` | Keep redirect table aligned with `AGENTS.md` |
| `.agent/AGENT_ONBOARDING.md` | Fix stale references and clarify Codex onboarding |
| `.agent/AI_IDENTITY_STRATEGY.md` | Add Codex-specific identity guidance and examples |
| `.agent/scripts/framework_config.sh` | Add Codex name, email, and fallback model mappings |
| `.agent/scripts/detect_cli_env.sh` | Add Codex session detection using confirmed markers |
| `.agent/scripts/detect_agent_identity.sh` | Support Codex model detection and fallback behavior |
| `.agent/scripts/set_git_identity_env.sh` | Add `--agent codex` support and update usage text |
| `.agent/hooks/check-commit-identity.py` | Verify guidance still matches Codex usage; update text only if needed |
| `CODEX.md` | Add a thin adapter only if verification shows Codex benefits from one |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Codex setup and limitations should be explicit and easy to verify |
| Enforcement over documentation | Identity support must live in scripts and checks, not prose alone |
| A change includes its consequences | Docs, adapter tables, and identity scripts must be updated together |
| Workspace vs. project separation | The change stays workspace-only and project-agnostic |
| Workspace improvements cascade to projects | Codex support should become a reusable pattern for other repos |
| Primary framework first, portability where free | Preserve Claude-first optimizations while adding Codex where cheap and consistent |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0006 | Yes | Keep shared rules in `AGENTS.md`; any Codex adapter stays thin |
| ADR-0004 | Yes | Add script-level support, not just documentation changes |
| ADR-0005 | Yes | Treat Codex detection as fast feedback, not load-bearing enforcement |
| ADR-0003 | Yes | Keep Codex support generic and not tied to a specific project |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `AGENTS.md` adapter table | Redirect docs and any framework adapters | Yes |
| Identity scripts | Identity docs and setup examples | Yes |
| Onboarding references | Missing or stale adapter paths | Yes |
| Codex detection | Worktree and PR signature behavior | Yes |

## Open Questions

- Which Codex session variables are stable enough for reliable auto-detection?
- Does Codex need a dedicated `CODEX.md`, or is `AGENTS.md` plus script support sufficient?
- What default email and model naming convention should Codex use in this workspace?

## Estimated Scope

Single PR, sequenced as: verify Codex runtime behavior, update shared docs,
update identity scripts, then validate the full workflow from a Codex session.
