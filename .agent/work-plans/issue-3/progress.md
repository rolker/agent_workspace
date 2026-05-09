---
issue: 3
---

# Issue #3 — Add branch mode to /review-code (local pre-push self-review)

## Plan
**Status**: complete
**When**: 2026-05-09 11:44
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-3/plan.md`.

Add `--branch [<base>]` to `/review-code` and `cross_model_review.sh` so the
existing review pipeline can run on a local branch diff before the PR exists.
Five architectural decisions surfaced as Open Questions for approval before
implement.

## Plan Review
**Status**: complete
**When**: 2026-05-09 11:50
**By**: Claude Code Agent (claude-opus-4-7) + Roland

Walked five architectural decisions one at a time with concrete previews.
Outcomes (see plan.md `## Decisions` for detail):

1. Default base ref: dynamic resolution via new `_resolve_default_branch.sh`
   helper; manifest hook reserved for #172 landing.
2. Static analysis: on by default in both modes, `--skip-static` toggle.
3. Branch parse failure: hard error + `--no-progress` opt-in.
4. `--pr` + `--branch`: mutually exclusive.
5. Self-test: same PR.

Plan refined: helper file added (5 files instead of 4); flag surface
table added; estimated scope bumped to ~300 LOC.

## Implement
**Status**: complete (pending self-test)
**When**: 2026-05-09 12:30
**By**: Claude Code Agent (claude-opus-4-7)

Five files landed across two commits (`3ffc237` script + helper,
`9a6a40b` skill + docs).

### Decisions

Local choices made during implement that weren't pre-decided in the plan
review. Skim and redirect anything that's wrong before self-test.

1. **Helper function name** — `resolve_default_branch`, not
   `resolve_default_base_ref`. Picked the user-facing semantic ("what's
   this repo's default branch?") over the operational one. Internally
   the function returns a ref directly usable in `git diff <ref>...HEAD`.

2. **Helper return strategy** — prefers a local branch ref (`main`),
   falls back to `origin/<branch>` if the local ref doesn't exist. Both
   forms work as the left-hand side of `git diff ...HEAD`, so callers
   don't need to know which form they got.

3. **Manifest hook = inert comment block, not stub function** — the
   block is marked clearly with the schema sketch but contains no code
   today. Stub functions for inert behavior felt like over-engineering.
   When #172's manifest schema lands, the wire-up is a few lines inside
   the existing comment.

4. **`--no-progress` artifact dir = `mktemp -d`** — when no per-issue
   work-plans dir applies, ephemeral `/tmp` was preferred over
   `.agent/scratchpad/` because findings in this mode are session-only
   by intent. Scratchpad is for things you might come back to.

5. **`ISSUE_NUMBER="noprogress"` sentinel** — used for SESSION_NAME and
   findings filename construction in branch+`--no-progress` mode. Two
   concurrent `--no-progress` runs collide on session name; tmux's
   existing session-kill behavior handles this (newer kills older,
   matching how PR-mode re-runs already work).

6. **`TARGET_LABEL` variable** — introduced one mode-aware label
   computed once instead of forking every status-message `printf`
   throughout the run-review block. Keeps the sync/tmux invocation
   blocks unchanged.

7. **Branch-mode prompt header** — emits `Title / Branch / Base / HEAD`
   instead of `Title / URL / PR Number`. The agent receives concrete
   refs it can mentally check against, and there's no fake "PR Number"
   to misread.

8. **Step 8 entry header `## Local Review (Pre-Push)`** — chose this
   over `## Pre-Push Review` so it sorts next to `## Local Review`
   alphabetically and the relationship is obvious. Both can coexist on
   one issue's timeline without overwriting.

9. **Helper marked executable (`chmod +x`)** — matches the convention
   of `_resolve_work_plans_dir.sh` (also 755) and satisfies pre-commit's
   "shebang implies executable" rule. Helpers are still sourced, not
   executed; the executable bit is documentation-only.

### Plan correction (already committed inline)

`--skip-static` was originally listed in `cross_model_review.sh`'s flag
surface; removed during implement because that script only dispatches
the cross-model adversarial specialist. Static analysis lives in the
skill's Step 5a, so the flag belongs to the skill only. Plan-task
inline-edit convention applied: plan.md updated in the same commit as
the script changes (`3ffc237`).

### What's next

Self-test (task 4): run the new branch mode against this very branch
(`feature/issue-3`), triage findings, fix inline if minor.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-05-09 13:35
**By**: Claude Code Agent (claude-opus-4-7) + gemini + codex (cross-model)
**Verdict**: approved (all findings addressed inline)

**Branch**: `feature/issue-3` at `cf4060b`
**Base**: `main`
**Depth**: Deep (reason: 724 changed lines + governance-file overrides)
**Must-fix**: 4 | **Suggestions**: 7 | **Declined**: 2

### Findings

- [x] (must-fix) TARGET_LABEL referenced BRANCH_NAME before metadata block — `cross_model_review.sh:398`
- [x] (must-fix) `--branch <ref>` didn't normalize BASE_REF when only origin/<ref> exists — `cross_model_review.sh:419`
- [x] (must-fix) Branch-name regex matched `feature/issue-3foo` and `feature/issue-03` (silent misrouting, #149 pattern) — `cross_model_review.sh:300`
- [x] (must-fix) tmux session name collision under `--no-progress` — `cross_model_review.sh:396`
- [x] (suggestion) Script reference row missed `--branch`/`--no-progress` — `AGENTS.md:350`
- [x] (suggestion) Helper swallowed bad `repo_root` errors — `_resolve_default_branch.sh:33`
- [x] (suggestion) Helper "main fallback" error wording misleading — `_resolve_default_branch.sh:71`
- [x] (suggestion) SKILL.md referenced undefined `BASE_ARG` — `SKILL.md:1b snippet`
- [x] (suggestion) SKILL.md ambiguous about depth keywords passing to script — `SKILL.md:5e dispatch`
- [x] (suggestion) `gh repo view` called in branch mode (wasted round-trip) — `cross_model_review.sh:241`
- [x] (suggestion) `--no-progress` artifact-dir asymmetry undocumented — `cross_model_review.sh:382`

### Declined

- (D1) `mktemp -d` cleanup trap — users want to inspect findings after script exits; OS cleans /tmp on boot. Comment added.
- (D2) `_resolve_default_branch.sh` `origin` assumption — consistent with workspace convention; manifest hook (#172) is the future home for repo-specific overrides.

### Cross-model summary

- Gemini (pre-fix): TARGET_LABEL ordering, BASE_REF normalization, mktemp trap (declined), BASE_ARG, origin assumption (declined)
- Codex (pre-fix): TARGET_LABEL ordering, BASE_REF normalization (independent confirm of gemini)
- Claude adversarial subagent: tmux collision, regex tightening, repo_root validation, error wording, depth-keyword passthrough, gh repo view efficiency, no-progress comment

### Fix commit

`cf4060b` — applied all must-fixes plus all suggestions worth fixing inline. Smoke test (`./cross_model_review.sh --branch --agent gemini`) passes clean post-fix.
