# Plan: review-code: untrack cross-model review artifacts

## Issue

https://github.com/rolker/agent_workspace/issues/193

## Context

`cross_model_review.sh` writes `review-<agent>-prompt.md` and
`review-<agent>-findings.md` into `.agent/work-plans/issue-<N>/`, which is
tracked by git. Two amplifiers compound:

1. Codex echoes its full input prompt (and tool-call transcript) into the
   findings file, so a single pass produces a multi-thousand-line file.
2. On a re-review, `git diff base...HEAD` (PR mode: `gh pr diff <N>`)
   includes the previously-committed prompt + findings as `+` lines, which
   the script feeds into the next prompt.

Forensic confirmation in PR #99 (daddy_camp): three review iterations grew
the prompt to 35,489 lines, of which ~91% was prior review artifacts. The
4th pass blew Codex's 1MB context (issue body).

## Approach

Per scope decision (see Open Questions / decision-log convention): minimal
workspace fix + sibling project-repo issue. Defense-in-depth filter,
summary file, and cascade docs deferred to follow-ups.

1. **Add ignore patterns to workspace `.gitignore`.** Two globs targeting
   the artifact filenames under any work-plans dir. Place them in a new
   "Cross-model review artifacts" section with a brief comment explaining
   why (regenerated per run; bloats PR diffs; breaks Codex 1MB context).
   Add a one-line note that the patterns are intentionally suffix-anchored
   (`-prompt.md` / `-findings.md`, not bare `review-*`) so a future
   `review-*-summary.md` audit-trail file is not caught by the same
   patterns. Future-proofs the deferred summary-file follow-up.

2. **Untrack the 4 already-tracked workspace artifacts.** `git ls-files`
   shows 4 review artifacts on main from past merged work
   (`.agent/work-plans/issue-173/review-{codex,gemini}-{prompt,findings}.md`).
   Run `git rm --cached` on them in this PR. Files stay on disk; only the
   index entry goes. Safe to do here because there are no open workspace
   PRs to disrupt (verified). The project-side sibling issue keeps the
   equivalent cleanup optional with a "when no in-flight PRs touch these
   paths" qualifier (project repo has open PR #106).

3. **Note the convention in `cross_model_review.sh` header.** Replace the
   sentence at line 6 — *"These files can be committed as review
   artifacts."* — which becomes incorrect with this change. New text:
   *"These files are gitignored — regenerated each run, not part of the
   audit trail (durable findings live in `progress.md`)."* Single-line
   replacement; no code change. This is the consequences-map cascade for
   the `review-code` skill.

4. **Update `review-code` SKILL.md.** Lines 335–337 describe the script
   writing the prompt/findings paths. Add a one-liner clarifying these
   are gitignored and not part of the audit trail; durable findings live
   in `progress.md` (already the convention).

5. **Verify (acceptance criterion #2).** From this worktree, run
   `cross_model_review.sh --branch main --no-progress --agent gemini`
   (or whichever agent CLI is available) against the local branch.
   Confirm the resulting `review-gemini-{prompt,findings}.md` files
   appear in the temp dir (`--no-progress`) and that
   `git status --porcelain | grep -E 'review-(prompt|findings)'`
   returns nothing. If a non-`--no-progress` form is preferred (writing
   into `.agent/work-plans/issue-193/`), the same grep against the
   worktree's status must return nothing — proving the `.gitignore`
   patterns catch them.

6. **Open a sibling project-repo issue in `rolker/daddy_camp`.** Done
   *after* PR #198 is review-ready, so the sibling issue can reference
   both #193 (workspace) and the workspace PR URL. Body lists the same
   two patterns for `project/.gitignore`, and notes the optional
   `git rm --cached` cleanup for the 8 already-tracked project artifacts
   under `.agent/work-plans/issue-*/review-*-{prompt,findings}.md`
   (qualified: do when no in-flight PRs touch those paths). **This step
   is intentionally a side-effect outside this PR's diff** — the
   project-repo PR is separate work in the daddy_camp worktree.

## Files to Change

| File | Change |
|------|--------|
| `.gitignore` | Add 2 suffix-anchored patterns + section comment + future-proofing note (~6 lines) |
| `.agent/work-plans/issue-173/review-{codex,gemini}-{prompt,findings}.md` (×4) | `git rm --cached` — untrack already-committed artifacts |
| `.agent/scripts/cross_model_review.sh` | Replace line-6 sentence; no code change |
| `.claude/skills/review-code/SKILL.md` | 1 line near the existing "Writes a review prompt to ..." description (~line 335) |
| *(verification, not a file change)* | Run `cross_model_review.sh` and confirm `git status` stays clean |
| *(out-of-PR side effect)* daddy_camp sibling issue | Opened last, via `gh issue create -R rolker/daddy_camp`, links back to #193 + PR #198 |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Scope intentionally minimal — gitignore + two doc touches, no new tooling, no CI scan |
| Enforcement over documentation | `.gitignore` is mechanical enforcement; pre-commit catches `git add -f` accidents |
| A change includes its consequences | Skill and support-script doc updates land in the same PR per the consequences-map row "review-code skill → also update cross_model_review.sh" |
| Workspace serves the product | Fixes a concrete product-blocking failure (PR #99 review broke at the 1MB ceiling) |
| Workspace vs. project separation | Workspace carries the convention; project repo gets a sibling issue. No project-specific assumption leaks into workspace |
| Workspace improvements cascade to projects | Project sibling issue is the cascade. Cascade docs (AGENTS.md snippet / onboard-project check) deferred to a follow-up — flagged but out of scope here per the explicit scope decision |
| Improve incrementally | Single small reviewable PR; reversible (delete the gitignore lines if it backfires) |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 — Project-agnostic workspace | Yes | The pattern is project-agnostic; the workspace `.gitignore` declares the convention without referencing any specific project |
| 0004 — Enforcement hierarchy | Lightly | Single layer (gitignore). Acceptable for the severity; if recurrence shows the layer is insufficient, revisit with the deferred defense-in-depth filter |
| 0005 — Layered enforcement | Lightly | Same — gitignore is the layer; pre-commit naturally protects against `git add -f` |
| 0001 / 0002 / 0006 / 0007 / 0008 / 0009 / 0010 | No | Not triggered |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `review-code` skill | `.agent/scripts/cross_model_review.sh` | Yes — both touched in the same PR (steps 2 + 3) |
| `cross_model_review.sh` header | Script reference table in `AGENTS.md` | No — it's a comment-only change, no behavior or surface-area shift; no AGENTS.md update needed |
| Workflow / convention for review artifacts | Cascade to project repos | Partial — sibling issue opened in daddy_camp; broader cascade docs deferred (Open Questions) |

## Open Questions

- **None blocking.** The scope decision (minimal + sibling, no defense-in-depth, no summary file, no cascade docs) was made up-front via AskUserQuestion. Deferred items live as prose in this plan and will surface again only if the gitignore alone proves insufficient — at which point a new issue should track the follow-up rather than reopening this one.

## Estimated Scope

Single PR. Implementation is ~6 lines of `.gitignore`, 4 untrack lines, two one-liner doc touches, a verification run, and one out-of-diff `gh issue create` call against `daddy_camp`. Total diff target: <40 lines of meaningful change (the 4 `git rm --cached` show as `delete mode 100644 ...` lines, not content).
