---
issue: 141
---

# Issue #141 — Auto-update roadmap status at merge time in merge_pr.sh

## Plan
**Status**: complete
**When**: 2026-04-05 22:30
**By**: Claude Code Agent (claude-opus-4-6)

Plan file: `.agent/work-plans/issue-141/plan.md`.

Replace the passive roadmap reminder in merge_pr.sh with a new `update_roadmap.sh` helper that auto-updates roadmap entries using explicit `#N` matching before merging. Opt-out via `--no-roadmap-update` flag.

## Implementation
**Status**: complete
**When**: 2026-04-06 00:45
**By**: Claude Code Agent (claude-opus-4-6)

Implemented per plan:
1. `update_roadmap.sh` — searches both roadmap formats (table + checklist)
   for explicit `#N` matches, updates status to done/checked. Supports --dry-run.
2. `merge_pr.sh` — added --no-roadmap-update flag, replaced step 5 roadmap
   reminder with pre-merge auto-update (new step 1). Commits and pushes
   roadmap changes to feature branch before merging. Failures non-blocking.
3. AGENTS.md script reference updated.

## Local Review
**Status**: complete
**When**: 2026-04-06 01:15
**By**: Claude Code Agent (claude-opus-4-6)
**Verdict**: changes-requested

**PR**: #144 at `c9d1b06`
**Depth**: Deep (reason: 351 lines, governance file AGENTS.md)
**Must-fix**: 4 | **Suggestions**: 3

### Findings
- [ ] (must-fix) Roadmap update runs on wrong branch (ROOT_DIR is main, not feature) — `merge_pr.sh:131-161`
- [ ] (must-fix) Absolute paths + bare git push target wrong branch — `merge_pr.sh:148,157`
- [ ] (must-fix) set -eo pipefail contradicts "always exits 0" — `update_roadmap.sh:15`
- [ ] (must-fix) \b in grep not portable — `update_roadmap.sh:111`
- [ ] (suggestion) Tests promised in plan step 5 but not included
- [ ] (suggestion) sed replacement fragile if status contains regex metacharacters — `update_roadmap.sh:83`
- [ ] (suggestion) sed could match wrong column if status text appears elsewhere in row — `update_roadmap.sh:83`

## External Review
**Status**: complete
**When**: 2026-04-06 01:45
**By**: Claude Code Agent (claude-opus-4-6)

**PR**: #144 — 2 review(s), 4 valid, 4 false positives
**CI**: all-pass

### Actions
- [ ] Guard _WT_TOPLEVEL: add `|| echo ""` to rev-parse, skip staging if empty
- [ ] Move FOUND_MATCH=true in checklist section to after `- [ ]` check
- [ ] Design decision: project roadmap update in project worktrees (accept limitation or add --ws-root)

## External Review (round 2)
**Status**: complete
**When**: 2026-04-06 02:15
**By**: Claude Code Agent (claude-opus-4-6)

**PR**: #144 — 3 review(s), 1 valid, 1 false positive (13 previously addressed)
**CI**: all-pass

### Actions
- [ ] Validate ISSUE_NUM is numeric after argument parsing in update_roadmap.sh
