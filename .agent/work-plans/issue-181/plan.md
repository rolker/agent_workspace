# Plan: cross_model_review.sh — gemini agent fails because `-p` is invoked without a value

## Issue

https://github.com/rolker/agent_workspace/issues/181

## Context

`cross_model_review.sh --agent gemini` (used by `/review-code` Deep tier)
fails: gemini's argparse rejects `-p` without a value, dumps the help
screen, and `--- Review failed ---` gets written to the findings file
with no actual review content. Filed during PR #177's Deep-tier review,
where Codex worked but Gemini's findings file was just the help dump.

Two parallel call sites need the same fix:

- **Sync mode** (`merge_pr.sh:87` … wait, this is `cross_model_review.sh:87`) — `run_agent_sync` case branch.
- **Tmux mode** (`cross_model_review.sh:61`) — `build_invoke_cmd` case
  branch.

**Important constraint** (from the script's own line 55 comment): "All
agents use stdin-based invocation to avoid argv limits on large diffs."
Deep-tier reviews routinely contain 1000+ line diffs and can exceed
`ARG_MAX` (commonly 128 KB on Linux). So the fix cannot be the
"obvious" `gemini -p "$(cat "$prompt")"` — that inlines the prompt as
an argv item and reintroduces the size limit. The fix must keep stdin
as the prompt-delivery path.

## Approach

Fix both call sites by passing an explicit empty string value to `-p`,
which (per `gemini --help`) is appended with stdin: "Run in non-interactive
(headless) mode with the given prompt. Appended to input on stdin (if any)."

Empirically verified before planning:

```bash
$ /home/roland/.nvm/versions/node/v24.14.0/bin/gemini -p "" \
    -m gemini-2.5-flash <<<'Reply with exactly the word OK and nothing else.'
OK   # exit 0
```

So the literal fix is one token per call site (`-p` → `-p ""`).

1. **Fix sync path** (`cross_model_review.sh:87`): replace
   `"$bin" -p < "$prompt" > "$findings" 2>&1` with
   `"$bin" -p "" < "$prompt" > "$findings" 2>&1`.

2. **Fix tmux path** (`cross_model_review.sh:61`): same change inside the
   shell-string echo.

3. **Add a code comment** explaining *why* the empty string is required.
   The historical record of this bug (filed and fixed in the same day)
   needs to live next to the code so the next agent who edits this
   doesn't drop the `""` thinking it's a typo.

4. **Smoke test** by running the dispatch end-to-end against PR #177
   (or any merged workspace PR) with `--agent gemini`. Verify the
   findings file contains a real `### Findings` section, not the help
   screen.

5. **Out of scope (separate issues if confirmed):**
   - `claude` and `copilot` cases use the same `-p < file` pattern (lines
     68-71, 89-91). They might have the same bug, but the actual claude
     CLI accepts `-p` without a value (different argparse), and copilot
     CLI behavior is unverified. **Don't speculatively change them
     here** — file follow-up issues only if a real failure is observed
     for either agent.
   - Adding a post-invocation sanity check ("does the findings file look
     like a CLI help dump?") would catch future breakage for *any*
     agent, not just gemini. Worth doing eventually, but it's its own
     hardening change with its own design decisions (regex tightness,
     false-positive handling, retry semantics) — keep this PR narrowly
     scoped to the filed bug.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/cross_model_review.sh` | Add `""` after `-p` for the gemini case in both `build_invoke_cmd` (line 61) and `run_agent_sync` (line 87). Add a 1-line code comment at each site. |
| `.agent/work-plans/issue-181/progress.md` | Plan + implementation history. |

No tests added — workspace has no shell-test scaffold (same precedent as
#173). Manual smoke test deterministically reproduces pre-fix failure
and post-fix success; documented in PR description.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Verified the fix empirically *before* writing the plan (one-line gemini invocation returned "OK"). PR description will document the deterministic repro. |
| Only what's needed | Two literal tokens + 2 comment lines. Resist scope creep into claude/copilot cases (separate issues if real failures emerge) and post-invocation sanity checks (separate hardening change). |
| A change includes its consequences | The `""` is load-bearing — losing it on a future edit reintroduces the bug. Mitigate via code comment, not just commit message. |
| Capture decisions | Code comment captures *why* the empty string is required (avoids a future "looks like a typo, let me clean it up" regression). |
| Improve incrementally | One commit, ~6 LOC of script change. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0001 — ADRs | No | Bug fix; no architectural decision worth recording. |
| 0007 — Retain Make + dependency tracking | No | No Makefile changes. |
| Others | No | Script fix entirely contained to `cross_model_review.sh`. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `cross_model_review.sh` invocation pattern for gemini | Documentation that explains the script's behavior | **No update needed** — `cross_model_review.sh` is documented in `AGENTS.md`'s Script Reference table only by purpose ("Cross-model adversarial review"); the fix doesn't change that. |
| Adversarial-review behavior | `/review-code` skill description | **No update needed** — Deep tier already says "Cross-model adversarial (all available non-caller agents, via `cross_model_review.sh`)". The fix makes that line accurate for gemini. |

## Open Questions

None. The fix is empirically verified, the constraint (stdin to avoid
argv limits) is clear, and scope is bounded.

## Estimated Scope

Single PR, single commit. ~6 LOC of script change (2 token additions +
2 single-line comments) + progress.md. Manual smoke test against any
merged workspace PR.
