---
issue: 181
---

# Issue #181 — cross_model_review.sh: gemini agent fails — `gemini -p` is invoked without a value

## Plan
**Status**: complete
**When**: 2026-05-07 23:30
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-181/plan.md`.

Pass an explicit empty string value to `gemini -p` in both sync and tmux
call sites, keeping stdin as the prompt source so the script's argv-
limit avoidance constraint (line 55 comment) stays honored. Add a code
comment at each site explaining why the `""` is load-bearing. Fix
verified empirically before planning.

## Implementation
**Status**: complete
**When**: 2026-05-07 23:45
**By**: Claude Code Agent (claude-opus-4-7)

- Edited `.agent/scripts/cross_model_review.sh` at two sites: line 61
  (`build_invoke_cmd`, tmux mode) and line 87 (`run_agent_sync`).
  Added 5-line comment block at the tmux site and a 2-line comment at
  the sync site. Both sites now invoke `gemini -p "" < "$prompt"`.
- Diff size: +9/-2 in cross_model_review.sh.

### Smoke tests

- [x] `bash -n` — syntax clean
- [x] `shellcheck --severity=warning` — clean
- [x] **End-to-end sync mode**: `cross_model_review.sh --pr 177
      --agent gemini --sync` produced a real `### Findings` table with
      severity/file/line columns. Pre-fix this run wrote the gemini
      help screen to the findings file. (Tangential observation:
      Gemini hallucinated a "Makefile corruption" finding in this run
      — that's a Gemini-quality concern, not a script bug, so out of
      scope here.)
- [x] **Tmux mode constructed command**: verified by inspection that
      `build_invoke_cmd` now emits `"gemini" -p "" < "$prompt" >
      "$findings" 2>&1` — same shape as the sync invocation, so the
      sync test transitively validates tmux. A separate full tmux
      smoke run would be ceremony given the literal command string is
      identical.
- Smoke-test artifact: the run wrote a temporary findings file to
  `.agent/work-plans/issue-173/` (the issue closed by PR #177). I
  `git restore`d the pre-existing PR-#177 review artifacts so this
  PR's diff is purely the script change — the historical "Review
  failed" record stays intact.
