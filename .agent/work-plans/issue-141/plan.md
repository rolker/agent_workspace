# Plan: Auto-update roadmap status at merge time in merge_pr.sh

## Issue

https://github.com/rolker/agent_workspace/issues/141

## Context

`merge_pr.sh` currently has a "roadmap reminder" (step 5, lines 169-198) that
does keyword matching to suggest the user *might* want to update the roadmap.
This creates busywork — the user must manually edit the roadmap in a follow-up
PR, which can conflict with other roadmap edits landing concurrently.

The issue proposes replacing the passive reminder with an active update at
merge time. The review comment recommends starting conservatively with explicit
`#N` matching only, making the feature opt-out, and handling commit/push
failures gracefully.

## Approach

1. **Create `update_roadmap.sh` helper script** — Keeps merge_pr.sh focused
   and makes the logic independently testable. The helper:
   - Takes `--issue <N>` and optional `--dry-run` flag
   - Searches `docs/ROADMAP.md` for `#<N>` in the Issue column of table rows;
     if found and Status != `done`, updates to `done`
   - Searches `project/ROADMAP.md` for `#<N>` in checklist items (`- [ ]`
     lines); if found, changes to `- [x]`
   - Prints what was changed (or "no roadmap entries found") for transparency
   - Returns exit code 0 regardless (never blocks the merge)

2. **Integrate into merge_pr.sh** — Replace lines 169-198 (step 5: roadmap
   reminder) with a call to `update_roadmap.sh`. If the helper reports
   changes, commit them to the feature branch and push before merging. Add
   `--no-roadmap-update` flag to merge_pr.sh for opt-out.

3. **Reorder merge_pr.sh steps** — The roadmap update must happen *before*
   the merge (step 1), not after. New order:
   - Step 1 (new): Roadmap update — run helper, commit + push if changes
   - Step 2: Merge the PR
   - Step 3-5: Worktree removal, branch cleanup, sync (unchanged)

4. **Update AGENTS.md script reference** — Add `update_roadmap.sh` to the
   table and update `merge_pr.sh` description to mention auto-update.

5. **Add tests** — Shell tests for `update_roadmap.sh` covering:
   - Table format: issue found with non-done status → updated to done
   - Table format: issue already done → no change
   - Checklist format: issue found unchecked → checked
   - No match → no changes, clean exit
   - `--dry-run` reports but doesn't modify

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/update_roadmap.sh` | New helper script (matching + updating logic) |
| `.agent/scripts/merge_pr.sh` | Add `--no-roadmap-update` flag; replace step 5 reminder with pre-merge call to helper; reorder steps |
| `AGENTS.md` | Add `update_roadmap.sh` to script reference table; update `merge_pr.sh` description |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Opt-out via `--no-roadmap-update`; helper prints exactly what it changed; changes are visible in the PR diff before merge completes |
| Enforcement over documentation | Replaces a manual reminder (documentation) with automation (enforcement). Good direction per review. |
| A change includes its consequences | Plan includes AGENTS.md script reference update and tests |
| Only what's needed | Explicit `#N` matching only — no fuzzy matching. Conservative per review recommendation #1 |
| Improve incrementally | Single script + integration into existing flow, not a rewrite |
| Workspace vs. project separation | The helper modifies `project/ROADMAP.md` from workspace infrastructure. This is pragmatic (markdown checkbox flip), but kept project-agnostic: it uses the same `#N` pattern matching regardless of which project is configured. No project-specific logic. |
| Workspace improvements cascade | The roadmap update logic works for any project repo using either format |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 — Project-agnostic workspace | Watch | Matching strategy is format-aware but project-agnostic: table format (`#N` in Issue column) and checklist format (`#N` anywhere in `- [ ]` line). No project-specific tuning. |
| 0010 — git-bug optional | No | Roadmap update uses file content, not issue lookup |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `.agent/scripts/merge_pr.sh` | Script reference in `AGENTS.md` | Yes — step 4 |
| `.agent/scripts/merge_pr.sh` | `Makefile` merge-pr target | No change needed — target already calls the script |
| Add `.agent/scripts/update_roadmap.sh` | Script reference in `AGENTS.md` | Yes — step 4 |

## Open Questions

- **Commit authoring**: The roadmap commit will be authored by whoever runs
  the merge script (the agent's git identity). Is this acceptable, or should
  it use a distinct "automation" identity? (Recommendation: use current identity
  — it's the same agent doing the merge.)
- **Branch protection on feature branch**: If the feature branch has protection
  rules that prevent pushing after approval, the roadmap commit will fail. The
  plan handles this by making the failure non-blocking (helper returns 0, merge
  proceeds without the roadmap update). Is a warning message sufficient?

## Estimated Scope

Single PR. The helper script is ~60-80 lines; merge_pr.sh changes are
surgical (flag parsing, step reorder, replace reminder block). Tests add
another ~80-100 lines.
