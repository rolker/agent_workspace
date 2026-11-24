---
issue: 582
---

# Issue #582 — Promote BizzyBoat deployment lifecycle conventions into workspace capabilities

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 12:17 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-582 at `128f7e88`
**Base**: origin/main
**Depth**: Light (reason: 1 file, +1 line, docs/roadmap.md is no override trigger)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 1 | **Ship**: recommended — no must-fix findings

### Findings
- [ ] No issues found. LGTM.

### Checks
- Diff against origin/main is the one owner-approved deferral row in `docs/roadmap.md`, directly after "The fork cutover" row, wording verbatim.
- Format rules met: issue numbers in the prose, the check cell is `gh-issue` checks joined with ` ; `; the cell reads true only when both field-mode issues are closed (a mixed cell is `partial`, which the sit-rep never lists as due).
- `sitrep_checks.sh --root .`: one `deferral` row, result `false`; no `format` row; `--summary` gives `deferrals 3/11`.
- Issues are what the row says, all open: 582 deployment mode umbrella, 580 deployment-logging workflow, 583 recovery checklist, 208 and 209 field mode.
- No consequent change: `docs/design.md` states no deferral count; the five-path fixture in `test_sitrep_checks.sh` is an inline copy, not the live roadmap; `update_roadmap.sh --issue 582 --dry-run` finds no entry, so merging leaves the row alone.
- Static analysis: no linter profile for `.md`; pre-commit on the file passed.
- Plan drift: skipped, no work plan (the owner asked for this row directly).
- Claude adversarial and cross-model (gemini, codex): skipped, Light tier dispatches neither.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 12:17 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the pre-push review approved with nothing open; the host's pre-commit pass over the changed files passed)
**After**: publish
**Decision**: publish

One row in the roadmap's deferral table, in the owner's words, added on his word: "add it to the roadmap" (2026-11-24), after he was shown the row and asked what it would change. This issue has no issue review, plan or plan review on its timeline: the change is one row of text the owner approved word for word, with nothing designed (a host decision, listed for his veto). The pull request says Part of #582; the issue stays open.
