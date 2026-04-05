# Plan: Scripts and skills bypass git-bug for issue reads (ADR-0010 compliance)

## Issue

https://github.com/rolker/agent_workspace/issues/142

## Context

ADR-0010 requires trying git-bug first for issue reads, falling back to `gh`.
Some scripts and skills comply (`worktree_create.sh`, `plan-task`, `review-plan`,
`dashboard.sh`), but each reinvents the pattern inline. Other scripts and skills
skip git-bug entirely. Discussion on the issue refined the pattern to include
sync-on-miss reads and push-on-write semantics.

Two distinct API patterns exist in compliant code:
- **Text parsing** (`worktree_create.sh`): `git bug select/show` + sed/awk
- **JSON parsing** (skills): `git-bug bug show --format json` + jq

The existing `_worktree_helpers.sh` provides shared functions for worktree
operations but has no issue lookup helpers.

## Approach

### 1. Create shared helper: `.agent/scripts/_issue_helpers.sh`

A sourced utility file (matching `_worktree_helpers.sh` naming convention) with
these functions:

- **`issue_lookup <N> [--repo <slug>] [--root <dir>]`** — single-issue lookup
  returning title, state, and body. Implements the sync-on-miss pattern:
  1. `git bug show` locally (cache hit = done, no network)
  2. Cache miss: `git bug bridge pull github`, retry `git bug show`
  3. Still missing: fall back to `gh issue view`
  4. Log sync operations for transparency ("git-bug: pulling #N from GitHub...")
  
  Output: sets `ISSUE_TITLE`, `ISSUE_STATE`, `ISSUE_BODY` variables (caller
  sources the function). Returns 0 on success, 1 if neither source found the
  issue.

- **`issue_list_open [--repo <slug>] [--root <dir>]`** — list open issues.
  Tries `git bug ls status:open` first, falls back to `gh issue list`. Returns
  one issue per line in `<number>\t<title>` format.

- **`issue_count_open [--repo <slug>] [--root <dir>]`** — count open issues.
  Thin wrapper around `issue_list_open | wc -l` or dedicated `git bug ls`
  count.

Design decisions:
- Use the **text parsing** approach for the shared helper (matches existing
  script conventions; avoids jq dependency for scripts that don't already use it)
- Skills will reference the canonical pattern in `AGENTS.md` rather than
  sourcing the helper (skills are instruction text, not executable code)
- The `--root` flag defaults to the workspace root (needed for `git -C` context)
- Always call `git bug deselect` after `select/show` (follows `worktree_create.sh`)

### 2. Refactor compliant scripts to use the shared helper

Replace inline git-bug-first implementations with sourced helper calls:

- **`worktree_create.sh`** (lines 270-311): Replace ~40 lines with
  `source _issue_helpers.sh` + `issue_lookup "$ISSUE_NUM"`
- **`dashboard.sh`** (lines 379-391): Replace with `issue_count_open`

This validates the helper against known-working behavior before applying it
to new callers.

### 3. Update non-compliant scripts

- **`worktree_enter.sh`** (lines 249-268): Replace gh-only title fetch with
  `source _issue_helpers.sh` + `issue_lookup "$ISSUE_NUM"`. Keep the
  multi-repo retry logic (workspace slug fallback).
- **`merge_pr.sh`** (line 171): Replace gh-only title fetch with
  `issue_lookup "$ISSUE_NUM"`. Only title is needed here (for roadmap matching).

### 4. Update non-compliant skill instructions

Update the git-bug-first pattern text in skill SKILL.md files. These are
instruction text (not executable), so they reference the canonical pattern
rather than sourcing the helper:

- **`review-issue`** step 1: Add git-bug-first lookup before `gh issue view`
- **`what-next`** step 3: Add git-bug list alternative for bridged repos
- **`issue-triage`** step 2: Add git-bug list alternative for bridged repos

For `onboard-project` — skip. `gh issue create` is a write to GitHub;
git-bug create + push is lower value here and the issue review flagged
this as a likely false positive.

### 5. Document canonical pattern in `AGENTS.md`

Add a "git-bug-first Pattern" subsection under "GitHub CLI Patterns":

- When to use git-bug vs `gh` (reads vs writes vs PR ops)
- Sync-on-miss behavior for reads
- Push-on-write behavior for writes
- Reference to `_issue_helpers.sh` for scripts
- Code snippet for skills to copy

### 6. Update ADR-0010 with sync strategy

Append a "Sync Strategy" section documenting:
- Pull-on-miss for reads
- Push-on-write for writes
- `make sync` for bulk reconciliation
- Rationale: avoid always-sync overhead while covering stale-cache case

### 7. Update script reference table in `AGENTS.md`

Add `_issue_helpers.sh` to the script reference table with purpose:
"Shared git-bug-first issue lookup with sync-on-miss (source)".

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_issue_helpers.sh` | **New** — shared helper with `issue_lookup`, `issue_list_open`, `issue_count_open` |
| `.agent/scripts/worktree_create.sh` | Refactor: replace inline git-bug code with sourced helper |
| `.agent/scripts/dashboard.sh` | Refactor: replace inline git-bug code with sourced helper |
| `.agent/scripts/worktree_enter.sh` | Fix: add git-bug-first via sourced helper |
| `.agent/scripts/merge_pr.sh` | Fix: add git-bug-first via sourced helper |
| `.claude/skills/review-issue/SKILL.md` | Fix: add git-bug-first instruction pattern |
| `.claude/skills/what-next/SKILL.md` | Fix: add git-bug list instruction pattern |
| `.claude/skills/issue-triage/SKILL.md` | Fix: add git-bug list instruction pattern |
| `AGENTS.md` | Add git-bug-first pattern docs + script reference entry |
| `docs/decisions/0010-git-bug-is-optional.md` | Append sync strategy section |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Shared helper enforces the pattern in scripts; skill text is advisory but backed by `AGENTS.md` docs |
| A change includes its consequences | `AGENTS.md` docs, ADR update, and script reference table all included in scope |
| Only what's needed | Helper has 3 functions matching 3 observed use cases; no speculative API |
| Improve incrementally | Single PR, mechanical changes; refactors existing compliant code first to validate helper |
| Human control and transparency | Helper logs sync operations so pull-on-miss is visible |
| Workspace improvements cascade to projects | Helper is project-agnostic; any repo with git-bug bridge benefits |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0010 — git-bug installed by default | Yes | This is the ADR being enforced; sync strategy appended to it |
| 0006 — Shared AGENTS.md | Yes | Pattern documented in AGENTS.md; framework adapters checked |
| 0003 — Project-agnostic workspace | Yes | Helper uses `--repo`/`--root` params, not hardcoded repos |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Scripts in `.agent/scripts/` | Script reference table in `AGENTS.md` | Yes (step 7) |
| `AGENTS.md` | Framework adapters (`.github/copilot-instructions.md`, etc.) | Yes — check if adapters reference gh CLI patterns |
| ADR in `docs/decisions/` | Principles review guide ADR table | Yes — verify 0010 description still matches |

## Open Questions

1. **Should existing compliant callers be refactored in this PR or a follow-up?**
   The plan includes refactoring `worktree_create.sh` and `dashboard.sh` to
   validate the helper, but this adds scope. Could defer to a separate PR if
   preferred.

2. **`git-bug` CLI invocation style**: `worktree_create.sh` uses
   `git -C "$ROOT_DIR" bug select/show` while skills use `git-bug bug show --format json`.
   The helper should pick one. Text parsing via `git -C` is more portable
   (works with `--root` param) — confirm this is preferred over JSON+jq.

## Estimated Scope

Single PR. ~10 files changed, but most changes are mechanical (replace inline
pattern with helper call or add instruction text). The shared helper is the
only net-new code (~60-80 lines).
