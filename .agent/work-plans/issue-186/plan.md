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

## Open Questions

These are the architectural decisions worth your eyes before implement.
Numbered so you can answer "1=A, 2=B, ..." or override individually.

1. **Surface-1 vs Surface-2 vs both.** Three options:
   - **(a) Both** (Recommended): script-side `gh pr checks --watch` in
     `merge_pr.sh` *plus* agent-side knowledge doc for the `Monitor` pattern.
     Script fix solves today's pain immediately for everyone; knowledge doc
     captures the pattern for future agent-flow uses (without requiring a
     code change to consume it).
   - **(b) Script-side only**: just add the wait to `merge_pr.sh`. Simpler
     PR; defer the agent-side `Monitor` knowledge doc until a concrete
     agent-flow use case appears.
   - **(c) Agent-side only**: no script change; build a `/merge-pr`
     slash command that wraps `merge_pr.sh` and uses `Monitor` for the
     wait. Larger architectural change; `merge_pr.sh` stays wait-less for
     non-Claude agents (still the manual-second-invocation pain for them).

   Option **(a)** matches the issue's scope ("merge flows" + framework
   portability), gives the immediate win, and leaves room for follow-up.

2. **Wait timeout / fail-fast behaviour.** `gh pr checks --watch` defaults
   to "wait forever". Three reasonable choices for the script:
   - **(a) `--fail-fast`** (Recommended): exits on first failed check;
     the script then aborts the merge with a useful error pointing at the
     failed check. Saves time on busted CI runs.
   - **(b) Plain `--watch`**: wait until all checks complete, then merge
     if green or fail with a generic error if not.
   - **(c) Wrapped in `timeout`**: e.g. `timeout 10m gh pr checks --watch`.
     Defends against runaway CI but introduces another knob.

3. **Smoke-test feasibility.** The wait path is hard to test end-to-end
   without a live PR. Three options:
   - **(a) Document manual verification** (Recommended for first cut):
     a script-header procedure that explains how to reproduce today's
     failure mode in a sandbox, and verify the fix avoids it. Low cost,
     honest about test-automation limits.
   - **(b) Mocked smoke test**: stub `gh pr checks --watch` with a
     scripted success/failure sequence. Decent coverage; some risk of
     drift from real `gh` behaviour.
   - **(c) Real-PR smoke test**: spin a throwaway PR each run. High
     fidelity; needs network, gh auth, and PR-cleanup logic.

## Estimated Scope

Single PR. Roughly:
- `merge_pr.sh` changes: ~15 LOC (wait step + flag + minor reshape)
- New knowledge doc: ~80 LOC (pattern overview + 2-3 examples)
- AGENTS.md update: ~1 LOC (script-reference row)
- Optional smoke test: ~30 LOC if mocked, or ~5 LOC of header documentation if manual-only

Total ~100-130 LOC. Same-PR scope; no breakdown needed.

## Implementation Notes

_(populated during implement phase per skill convention)_
