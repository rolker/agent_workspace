# Plan: cross_model_review.sh fails when invoked outside target repo worktree

## Issue

https://github.com/rolker/agent_workspace/issues/133

## Context

`cross_model_review.sh` silently produces empty reviews when invoked from
outside the target repo's worktree. Four root causes identified: (1) `gh`
commands use the current directory's remote instead of the PR's repo, (2)
issue number extraction uses a fragile regex, (3) artifact directory resolves
to main tree instead of the issue's worktree, (4) empty diffs are not
detected, so agents launch with no content.

The script already derives `GH_REPO_SLUG` from `git remote get-url origin`
(line 149) and passes it via `GH_REPO_ARGS`. This works when invoked from
the correct repo but fails when invoked from the workspace repo for a
project PR.

## Approach

1. **Add `--repo` flag** — Accept `-R <owner/repo>` to override the
   auto-detected repo slug. When provided, use it for all `gh` commands.
   When omitted, keep the existing `git remote` auto-detection as fallback.

2. **Add `--work-dir` flag** — Accept an explicit directory for artifact
   placement. When provided, use `<work-dir>/.agent/work-plans/issue-<N>/`
   instead of `$(git rev-parse --show-toplevel)/...`. When omitted, keep
   the existing `git rev-parse` behavior.

3. **Fix issue number extraction** — Replace the fragile `#[0-9]*` grep
   with explicit parsing of GitHub close keywords (`Closes`, `Fixes`,
   `Resolves`) with case-insensitive matching. Keep the `#N` fallback but
   make it more precise. Handle cross-repo references
   (`Closes owner/repo#N`).

4. **Add empty diff guard** — After writing the diff into the prompt file,
   check that it contains actual diff content (not just the markdown
   fences). If empty, write an error marker to the findings file and exit
   with code 3 instead of launching the agent.

5. **Update review-code skill invocation** — Update the example in
   `SKILL.md` to show the `--repo` flag usage, since the caller knows
   which repo the PR belongs to.

6. **Update AGENTS.md script reference** — Add note about new flags.

7. **Add tests** — Create `.agent/scripts/tests/test_cross_model_review.sh`
   with unit tests for: repo flag passthrough, issue extraction from PR
   body, empty diff guard, artifact path with `--work-dir`.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/cross_model_review.sh` | Add `--repo`, `--work-dir` flags; fix issue extraction; add empty diff guard |
| `.claude/skills/review-code/SKILL.md` | Update invocation examples to pass `--repo` |
| `AGENTS.md` | Update script reference table description |
| `.agent/scripts/tests/test_cross_model_review.sh` | New: unit tests for the four fixes |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Empty diff guard surfaces errors instead of silently failing — directly improves transparency |
| A change includes its consequences | Plan includes SKILL.md and AGENTS.md updates alongside the script fix |
| Only what's needed | Four targeted fixes, no refactoring beyond the bug scope |
| Test what breaks | Tests target the specific failure modes that caused silent failures in production use |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0002 — Worktree isolation | Yes | `--work-dir` flag allows callers to point artifacts at the correct worktree |
| 0003 — Project-agnostic workspace | Yes | `--repo` flag makes the script work for any project repo, not just the one matching the current directory |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `.agent/scripts/cross_model_review.sh` | Script reference in `AGENTS.md` | Yes (step 6) |
| `.agent/scripts/cross_model_review.sh` | `review-code` SKILL.md invocation | Yes (step 5) |
| Script interface (new flags) | Makefile targets | N/A — no Makefile target wraps this script |

## Open Questions

None — the issue is well-specified and the fixes are straightforward.

## Estimated Scope

Single PR.
