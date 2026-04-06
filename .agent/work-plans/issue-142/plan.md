# Plan: Scripts and skills bypass git-bug for issue reads (ADR-0010 compliance)

## Issue

https://github.com/rolker/agent_workspace/issues/142

## Context

ADR-0010 requires trying git-bug first for issue reads, falling back to `gh`.
Some scripts and skills attempt compliance (`worktree_create.sh`, `plan-task`,
`review-plan`, `dashboard.sh`), but each reinvents the pattern inline. Other
scripts and skills skip git-bug entirely. Discussion on the issue refined the
pattern to include sync-on-miss reads and push-on-write semantics.

### Critical finding: existing "compliant" code is broken

Investigation revealed that the existing git-bug code in `worktree_create.sh`
uses `git bug select` — a command that **does not exist** in git-bug v0.10.1.
The correct invocation is `git bug bug select`. This means all "compliant"
single-issue lookups silently fail and fall back to `gh` every time.

### git-bug CLI patterns (verified on v0.10.1)

**Lookup by GitHub issue number** (two-step via metadata filter):
```bash
# Step 1: Find git-bug ID via bridge metadata
BUG_ID=$(git -C "$ROOT" bug bug \
  -m "github-url=https://github.com/OWNER/REPO/issues/N" \
  --format json | jq -r '.[0].human_id // empty')

# Step 2: Get full details
git -C "$ROOT" bug bug show "$BUG_ID" --format json
```

The bridge stores `github-url` metadata on each synced bug. The list command
(`git bug bug`) supports `-m key=value` filtering; the show command does not
expose metadata. So lookup requires: list-with-filter to get the ID, then
show for full details.

**List open issues**: `git -C "$ROOT" bug bug status:open`

**Key facts**:
- `git -C` works with all `git bug` subcommands (repo targeting)
- `--format json` works on both list and show
- `show --format json` includes title, status, comments, but NOT metadata
- `select`/`deselect` exist as `git bug bug select`/`deselect` (not `git bug select`)
- The metadata filter requires the full GitHub URL, so the helper needs the repo slug

### Existing utility infrastructure

`_worktree_helpers.sh` provides shared functions for worktree operations.
The new `_issue_helpers.sh` follows the same naming convention.

## Approach

### 1. Create shared helper: `.agent/scripts/_issue_helpers.sh`

A sourced utility file with these functions:

- **`issue_lookup <N> --repo <slug> [--root <dir>]`** — single-issue lookup
  returning title, state, and body. Implements the sync-on-miss pattern:
  1. Query git-bug via metadata filter:
     `git bug bug -m "github-url=https://github.com/$REPO/issues/$N" --format json`
  2. Cache miss: `git bug bridge pull github`, log it, retry the query
  3. Still missing: fall back to `gh issue view`
  
  Output: sets `ISSUE_TITLE`, `ISSUE_STATE`, `ISSUE_BODY` variables (caller
  sources the function). Returns 0 on success, 1 if neither source found the
  issue.

- **`issue_list_open [--repo <slug>] [--root <dir>]`** — list open issues.
  Tries `git bug bug status:open --format json` first, falls back to
  `gh issue list`. Returns JSON array with number, title, status.

- **`issue_count_open [--repo <slug>] [--root <dir>]`** — count open issues.
  Uses `git bug bug status:open` line count, falls back to `gh api`.

Design decisions:
- Use **JSON output** (`--format json`) for structured parsing — avoids fragile
  text parsing with sed/awk, and jq is already a workspace dependency
- `--repo` is required for single-issue lookup (needed to construct the GitHub
  URL for metadata matching); optional for list/count (git-bug lists from the
  local repo's bridge)
- Skills will reference the canonical pattern in `AGENTS.md` rather than
  sourcing the helper (skills are instruction text, not executable code)
- The `--root` flag defaults to the workspace root (needed for `git -C` context)

### 2. Fix and refactor existing git-bug callers

Replace broken inline implementations with sourced helper calls:

- **`worktree_create.sh`** (lines 270-311): Currently uses `git bug select`
  (wrong command — silently fails every time). Replace ~40 lines with
  `source _issue_helpers.sh` + `issue_lookup "$ISSUE_NUM"`.
- **`dashboard.sh`** (lines 379-391): Working (`git bug bug` list path is
  correct here). Replace with `issue_count_open` for consistency.

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

None — resolved during planning:
- Existing callers will be refactored in this PR (confirmed by Roland)
- CLI style: use `git -C "$ROOT" bug bug` with `--format json` (combines
  `-C` repo targeting with structured output; verified working on v0.10.1)
- The `worktree_create.sh` git-bug code is broken (`git bug select` doesn't
  exist) — this PR fixes it, not just adds compliance

## Estimated Scope

Single PR. ~10 files changed, but most changes are mechanical (replace inline
pattern with helper call or add instruction text). The shared helper is the
only net-new code (~60-80 lines).
