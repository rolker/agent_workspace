---
issue: 142
---

# Issue #142 — Scripts and skills bypass git-bug for issue reads (ADR-0010 compliance)

## Plan
**Status**: complete
**When**: 2026-04-05 23:30
**By**: Claude Code Agent (claude-opus-4-6)

Plan file: `.agent/work-plans/issue-142/plan.md`.

Create a shared `_issue_helpers.sh` with sync-on-miss reads (git-bug first,
pull on cache miss, fall back to gh). Refactor existing callers (including
fixing broken `git bug select` invocations in worktree_create.sh) and update
non-compliant scripts and skill instructions. Document the canonical pattern
in AGENTS.md and append sync strategy to ADR-0010.

## Plan update
**Status**: complete
**When**: 2026-04-05 23:50
**By**: Claude Code Agent (claude-opus-4-6)

Major plan revision after discovering:
1. `git bug select` doesn't exist in v0.10.1 — existing "compliant" code is
   broken (silently falls back to gh every time)
2. Correct invocation is `git bug bug select/show/etc.`
3. GitHub issue number lookup requires metadata filter:
   `git bug bug -m "github-url=https://github.com/OWNER/REPO/issues/N"`
4. Switched from text parsing to JSON output (`--format json`) since the
   metadata lookup inherently needs structured parsing

## Local Review
**Status**: complete
**When**: 2026-04-06 00:45
**By**: Claude Code Agent (claude-opus-4-6)
**Verdict**: changes-requested

**PR**: #143 at `8c8b9ab`
**Depth**: Deep (reason: 671 lines, 13 files, governance files modified)
**Must-fix**: 3 | **Suggestions**: 4

### Findings
- [ ] (must-fix) jq dependency unguarded on gh fallback path in issue_lookup — `_issue_helpers.sh:100-107`
- [ ] (must-fix) Lost multi-repo fallback in worktree_enter.sh — only tries workspace slug now — `worktree_enter.sh:253-265`
- [ ] (must-fix) Incomplete sync-on-miss retry in review-issue skill snippet — `review-issue/SKILL.md:722-727`
- [ ] (suggestion) plan-task and review-plan skills use wrong git-bug lookup pattern (human_id != GitHub issue number)
- [ ] (suggestion) issue_list_open uses fragile $? pattern vs idiomatic if-assignment in issue_count_open — `_issue_helpers.sh:180-181`
- [ ] (suggestion) issue_list_open returns different ID types (git-bug short_id vs GitHub number) — `_issue_helpers.sh:182-184`
- [ ] (suggestion) Duplicated slug extraction in merge_pr.sh and worktree_enter.sh — consider sharing extract_gh_slug — `merge_pr.sh:174-187`

## External Review
**Status**: complete
**When**: 2026-04-06 01:30
**By**: Claude Code Agent (claude-opus-4-6)

**PR**: #143 — 2 review(s), 3 valid, 3 false positives
**CI**: all-pass

### Actions
- [x] Guard git-bug path in issue_list_open/issue_count_open — only use when --repo matches bridged repo
- [x] Add direct gh fallback in worktree_create.sh when slug extraction fails
- [x] Rewrite what-next and issue-triage skill snippets — git-bug is count-only, gh is primary for cross-referencing

## External Review (round 2)
**Status**: complete
**When**: 2026-04-06 02:00
**By**: Claude Code Agent (claude-opus-4-6)

**PR**: #143 — 3 review(s), 3 valid, 2 false positives
**CI**: all-pass

### Actions
- [ ] Add repo-slug guard to issue_lookup git-bug path — skip git-bug when --repo doesn't match --root's remote
- [ ] Update what-next and issue-triage skill snippets — add `| wc -l` to git-bug "count only" line
- [ ] Update --repo documentation in _issue_helpers.sh and AGENTS.md — mark as required for list/count
