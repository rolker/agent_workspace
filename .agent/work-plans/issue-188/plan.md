# Plan: /start-task: $ARGUMENTS quoting breaks every multi-flag invocation

## Issue

https://github.com/rolker/agent_workspace/issues/188

## Context

PR #182 introduced `/start-task` as a slash command. Its skill body invokes `worktree_enter.sh` and `worktree_create.sh` with `"$ARGUMENTS"` — quoted. The quoting was added in commit `cc23db5` to address a `/review-issue` finding ("`$ARGUMENTS` interpolation is unquoted — values with spaces or shell metacharacters break"), but it overcorrected: the quotes turn the user's flags into a single positional argument, so every multi-flag invocation fails immediately with `Error: Unknown option --issue 186 --type workspace`.

Confirmed by today's session — first real downstream exercise of `/start-task` (running `/start-task --issue 186 --type workspace` for the plan-task on #186) hit the bug; falling back to the manual `worktree_create.sh` + `EnterWorktree` flow was a ~30-second detour.

The issue body was reviewed via `/review-issue`; the recommended-fix shape and the smoke-test framing came out of that review. Most architectural decisions are resolved already.

## Approach

1. **Drop the quotes around `$ARGUMENTS`** in both `worktree_enter.sh` and `worktree_create.sh` invocations in `start-task/SKILL.md`. Two-line change in step 3 of the skill body.

2. **Rewrite the "Argument handling" section** to be honest about what slash-command argument forwarding can and cannot do. Today's wording claims the quoting "preserves spacing within a single value (e.g. `--branch \"feature/foo bar\"`)" — false. Replace with: typical case (multiple flags, no embedded whitespace) works; embedded-whitespace cases aren't supported (slash-command boundary flattens user-supplied quotes); shell-metacharacter values still warrant a refusal-or-warn pattern.

3. **Add an embedded-whitespace bullet to "When not to use"**: "Values containing embedded whitespace (e.g. `--branch \"feature/foo bar\"`). Slash-command argument forwarding flattens user-supplied quotes; the inner whitespace will not be preserved across the boundary. Call `worktree_create.sh` directly for those cases."

4. **Add a "Manual verification" section** to `start-task/SKILL.md` modelled on the procedure that landed in `merge_pr.sh`'s header in #186. Step-by-step that exercises the typical-case multi-flag invocation and confirms behaviour. Acknowledges automation is out of scope (no Claude Code SDK test harness available).

5. **No CLAUDE.md / AGENT_ONBOARDING.md updates needed.** Both reference `/start-task` only by name; the flag interface is unchanged from the user's perspective (broken multi-flag invocations now work; single-flag invocations were never broken). Verify by grep before committing.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/start-task/SKILL.md` | Drop quotes around `$ARGUMENTS` (step 3, two occurrences); rewrite "Argument handling" section; add embedded-whitespace bullet to "When not to use"; add new "Manual verification" section |

That's it. Single file, ~30 LOC of edits.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Bug fix improves error visibility — today's failure mode is `Error: Unknown option --issue 186 --type workspace` which is opaque; the fix removes the failure |
| Capture decisions, not just implementations | Issue body and `/review-issue` comment capture the design rationale (Option C selected, `read -ra` rejected with reason) |
| A change includes its consequences | Single skill file affected; consequences-map row "framework skill → adapter file" checked — no edits needed since flag interface is preserved |
| Only what's needed | Minimal fix; doesn't expand `/start-task`'s feature surface |
| Test what breaks | Manual-verification procedure documented per AC #4; automated equivalent declined honestly (same as #186's smoke test framing) |
| Workspace vs project separation | Workspace-only |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0002 — Worktree isolation | Yes | Working in `worktrees/workspace/issue-workspace-188/` |
| 0003 — Project-agnostic workspace | Yes | Workspace-only change |
| 0006 — Shared AGENTS.md | No | Skill is Claude-Code-only by design (per its frontmatter); other framework adapters don't reference its flag interface |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `.claude/skills/start-task/SKILL.md` | CLAUDE.md / `.agent/AGENT_ONBOARDING.md` if flag interface changes | N/A — flag interface is unchanged from user perspective; only broken behaviour is fixed |

## Decisions

Resolved during `/review-issue` on this issue — no Open Questions remaining for the user. Captured here for the implementer's reference:

1. **Fix shape: drop the quotes around `$ARGUMENTS`** (Option C from the original issue body's menu). `read -ra` array-read was considered and rejected — bash IFS-based word splitting fragments embedded-whitespace values the same way as unquoted expansion.
2. **Embedded-whitespace case is unsolvable at the slash-command boundary** — by the time `$ARGUMENTS` arrives in the skill body it's a flat string with no quote-preservation. The fix accepts this limitation honestly and documents it in "When not to use."
3. **Smoke test: documented manual verification only** — no automated test. Slash-command bodies are markdown instructions, not standalone executables; end-to-end testing needs a Claude Code SDK harness we don't have set up. Same rationale as `merge_pr.sh`'s manual verification in #186.

## Estimated Scope

Single PR. ~30 LOC across the skill file. No new tests (manual-verification procedure documented in SKILL.md per AC #4). No CLAUDE.md / AGENTS.md updates needed.

## Implementation Notes

_(populated during implement phase per skill convention)_
