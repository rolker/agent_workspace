# Plan: Prevent gh CLI from targeting wrong repo when in scratchpad clones

## Issue

https://github.com/rolker/agent_workspace/issues/72

## Context

When an agent `cd`s into a scratchpad clone (e.g.,
`.agent/scratchpad/inspiration/<name>/`), the `gh` CLI resolves repo context
from the clone's git remote instead of the workspace or project repo. This
caused an issue to be accidentally created on an external project
(garrytan/gstack#337).

`gh_create_issue.sh` is the primary risk — it passes through to `gh issue
create` without `-R`, relying on directory context. Other scripts
(`cross_model_review.sh`, `fetch_pr_reviews.sh`) also lack explicit `-R`
flags. Meanwhile, `merge_pr.sh` and `worktree_create.sh` already have
robust repo-targeting patterns worth reusing.

## Approach

1. **Add repo-safety check to `gh_create_issue.sh`** — After the existing
   `REPO_ROOT` detection (line 34), compare the detected repo's remote
   against the workspace repo (and project repo if configured). If they
   don't match and no `-R` flag was passed, abort with a clear error. Reuse
   the `extract_gh_slug()` pattern from `worktree_create.sh` for slug
   extraction and comparison. This is the layer-2 safeguard from the issue.

2. **Add `-R` pass-through support to `gh_create_issue.sh`** — Parse `-R`
   from the arguments. If present, skip the repo-safety check (the caller
   explicitly chose a target). If absent and the repo doesn't match, suggest
   the correct `-R` value in the error message.

3. **Add AGENTS.md rule** — Under "GitHub CLI Patterns", add a subsection
   requiring explicit `-R <owner/repo>` on repo-targeting `gh` commands when
   running from scratchpad clones or non-worktree directories. This is the
   layer-1 documentation guard from the issue.

4. **Add `-R` flag to `cross_model_review.sh`** — The `gh pr view` and
   `gh pr diff` calls (lines 188, 212-213, 247) don't pass `-R`. Since
   this script runs inside worktrees (not scratchpad clones), the risk is
   lower, but adding explicit repo targeting is defensive and consistent.
   Detect the repo slug from the current worktree's remote.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/gh_create_issue.sh` | Add repo-safety check and `-R` parsing |
| `AGENTS.md` | Add "Repo targeting in scratchpad clones" rule under GitHub CLI Patterns |
| `.agent/scripts/cross_model_review.sh` | Add `-R` flag to `gh pr` calls |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Layer 2 (script safeguard) enforces what layer 1 (AGENTS.md rule) documents |
| A change includes its consequences | AGENTS.md rule + script safeguard + downstream script fixes |
| Only what's needed | No new abstractions — reuse existing `extract_gh_slug()` pattern inline |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0002 (Worktree Isolation) | Yes | Worktree scripts already handle `-R` correctly; this fixes the gap in non-worktree contexts |
| ADR-0003 (Project-Agnostic) | Yes | Repo slugs are runtime-discovered from git remotes, not hardcoded |
| ADR-0006 (AGENTS.md Shared Rules) | Yes | New rule goes in shared AGENTS.md, not framework-specific files |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| AGENTS.md GitHub CLI Patterns | Framework adapters if they duplicate the section | No — checked, they don't duplicate it |
| `gh_create_issue.sh` interface | Callers of the script | No — interface is unchanged (new check is internal) |
| `cross_model_review.sh` gh calls | Nothing — internal change only | Yes |

## Open Questions

None.

## Estimated Scope

Single PR.

## Review: Standard — 2026-04-04

**PR**: #124 at `9f987e0`
**Must-fix**: 1 | **Suggestions**: 4
**Status**: Pending

### Findings
- [x] (must-fix) Non-GitHub remotes produce junk slugs causing false-positive abort — `gh_create_issue.sh:101`
- [x] (suggestion) `-R` without argument silently ignored instead of erroring — `gh_create_issue.sh:64`
- [x] (suggestion) Exit code 2 overloaded (repo-mismatch vs GitHub CLI error) — `gh_create_issue.sh:133`
- [ ] (suggestion) AGENTS.md implies broader enforcement than exists — `AGENTS.md:213`
- [ ] (suggestion) `fetch_pr_reviews.sh` also lacks `-R` — deferred or oversight?
