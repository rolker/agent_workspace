# Plan: Replace gh pr checks --watch busy-poll with native Monitor in merge flows

## Issue

https://github.com/rolker/agent_workspace/issues/186

## Context

The friction the issue targets — having to manually `gh pr checks --watch`
twice per merge cycle — shows up in two distinct surfaces:

**Surface 1 (script-internal):** `merge_pr.sh` pushes a roadmap-update
commit (line 306) and *immediately* attempts `gh pr merge` (line 322), with
no wait step in between. CI on the roadmap commit hasn't completed →
`Pull Request is not mergeable` → user runs `gh pr checks --watch` manually
→ retries `make merge-pr`. Hit twice in this session (PRs #185 and #182).

**Surface 2 (agent-side):** During triage-fix-merge cycles, agents (this
session, today) ran `gh pr checks --watch` directly between fix-push and
merge-retry — pure busy-poll in the agent's bash flow.

**Architectural note that re-shapes the plan:** `Monitor` is a Claude Code
SDK *tool*, not a CLI. It cannot be invoked from `merge_pr.sh` (or any
shell). So "Monitor adoption" lives only on Surface 2 (agent-side), not
Surface 1 (script-side). Surface 1 still needs a fix — but it's a plain
bash `gh pr checks --watch` insertion, not a `Monitor` adoption. The two
surfaces merit different mechanisms.

## Approach

1. **Surface 1 — `merge_pr.sh`: add internal wait between roadmap push and
   merge attempt.** Insert a `gh pr checks --watch` (likely `--fail-fast`)
   call immediately after the roadmap commit's `git push` succeeds. This
   is bash; works for *any* caller (manual, Claude Code, Codex, Gemini,
   sandboxed CI). Removes the "manual second invocation" pain entirely.
   Add a `--no-wait` flag to skip when the user knows CI is already green.

2. **Surface 2 — knowledge doc for the agent-side Monitor pattern.** New
   `.agent/knowledge/agent_wait_patterns.md` (or similar) describing when
   to use `Monitor` (Claude Code agents waiting for external events: CI,
   tmux sessions, background subagents) vs busy-poll fallback (other
   frameworks, scripts). Concrete examples for the common cases. No code
   change in this surface — just guidance for future agent flows.

3. **Smoke test for the script-side wait.** Add a script (probably
   `.agent/scripts/test_merge_pr_wait.sh` or a bats-style file) that
   verifies the wait step actually fires. If end-to-end automation is
   awkward (needs a live PR + gh auth), document manual verification as a
   procedure in the script's header comment per acceptance criterion 4 of
   the issue.

4. **Documentation cascade.** Update `AGENTS.md` script-reference table
   row for `merge_pr.sh` (last touched in PR #185 for `cross_model_review.sh`'s
   `--branch`/`--no-progress`; now needs an addendum). Update the script's
   header comment block. Cross-reference the new knowledge doc.

5. **Framework-adapter check.** Per the issue's framework-portability
   acceptance criterion: `merge_pr.sh`'s wait works for all frameworks
   transparently (it's bash). Adapter files (`CODEX.md`,
   `.agent/instructions/gemini-cli.instructions.md`,
   `.github/copilot-instructions.md`) probably need no change since the
   bash flow is identical. Verify by grep; add notes only if any adapter
   describes the merge flow in detail today.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Add wait-for-CI step after the roadmap push (~line 308) and before the merge attempt (~line 322); add `--no-wait` flag; update header comment |
| `.agent/knowledge/agent_wait_patterns.md` (new) | Document Monitor-vs-busy-poll pattern for agent flows; reference from `merge_pr.sh` and `cross_model_review.sh` indirectly via see-also |
| `AGENTS.md` | Update `merge_pr.sh` script-reference row to mention wait behaviour and `--no-wait` |
| `.agent/scripts/test_merge_pr_wait.sh` (new, optional) | Smoke test for the wait path; if full automation isn't feasible, fall back to a documented manual-verification procedure in `merge_pr.sh`'s header |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Script wait step prints status (`Waiting for CI on roadmap commit...`); user sees what's being awaited |
| Capture decisions, not just implementations | This plan's Open Questions captures the Surface-1 vs Surface-2 split |
| A change includes its consequences | Script + AGENTS.md script-reference + knowledge doc updated together |
| Only what's needed | Minimal merge_pr.sh diff (~10 LOC); knowledge doc is short pattern reference |
| Test what breaks | Smoke test in scope (acceptance criterion 4 of the issue); manual verification fallback if needed |
| Workspace vs project separation | Workspace-only |
| Workspace improvements cascade | `merge_pr.sh` works for both repo types unchanged; wait benefits both |
| Primary framework first, portability where free | Script-side bash works everywhere; agent-side `Monitor` is Claude-Code-only with documented busy-poll fallback (matches issue's framework-portability AC) |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0002 — Worktree isolation | Yes | Working in `worktrees/workspace/issue-workspace-186/` |
| 0003 — Project-agnostic workspace | Yes | Workspace-only change |
| 0006 — Shared AGENTS.md | Yes | AGENTS.md row updated; framework adapters checked for cross-references (likely no-op) |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `merge_pr.sh` | `AGENTS.md` script-reference table | Yes (file 3) |
| Add a new knowledge doc | (standalone reference; no cascading deps) | Yes (file 2) |

## Decisions

Captured 2026-05-09 during plan review with Roland. Each decision was asked
one at a time with concrete previews; recommendations were taken on all
three.

1. **Surface scope: both.** Script-side `gh pr checks --watch` in
   `merge_pr.sh` *plus* a new `.agent/knowledge/agent_wait_patterns.md`
   knowledge doc for the agent-side `Monitor` pattern. The script fix
   solves the manual-second-invocation pain for *every* framework
   immediately; the knowledge doc captures the agent-side pattern as
   durable guidance for future Claude Code flows (no consumer required
   today). Matches the issue's framework-portability AC and the
   workspace's "Workspace improvements cascade to projects" principle.

2. **Wait behaviour: `--fail-fast`.** `gh pr checks --watch --fail-fast`
   exits on the first failed check; the script then aborts the merge
   with a useful error pointing at the failed check (and its run URL).
   Saves time on busted CI runs; clear exit-code handling (gh exits 8
   on first-fail). The script translates the failure into a clear
   merge-aborted message rather than letting `set -e` swallow context.

3. **Smoke test: documented manual verification.** ~5 LOC procedure in
   `merge_pr.sh`'s header explaining how to reproduce today's failure
   mode (push a poke commit, run `make merge-pr` immediately) and verify
   the fix avoids it. Honest about test-automation limits — automating
   this would require mocking `gh pr checks --watch` (drift risk) or
   spinning throwaway PRs (network + auth dependencies). Out-of-scope
   for #186; revisit if regression risk grows.

### Resulting flag surface (script-side)

| Flag | Meaning |
|------|---------|
| `--no-wait` | Skip the new internal CI wait (for cases where the user knows CI is green) |
| `--no-roadmap-update` | (existing) skip the roadmap auto-update step |
| `--type workspace\|project` | (existing) override auto-detection |
| `--pr <N>` | (existing) PR number; required |

## Estimated Scope

Single PR. Roughly:
- `merge_pr.sh` changes: ~15 LOC (wait step + flag + minor reshape)
- New knowledge doc: ~80 LOC (pattern overview + 2-3 examples)
- AGENTS.md update: ~1 LOC (script-reference row)
- Optional smoke test: ~30 LOC if mocked, or ~5 LOC of header documentation if manual-only

Total ~100-130 LOC. Same-PR scope; no breakdown needed.

## Implementation Notes

_(populated during implement phase per skill convention)_
