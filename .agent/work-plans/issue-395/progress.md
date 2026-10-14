---
issue: 395
---

# Issue #395 — sit-rep: open with a composed orientation

## Issue Review
**Status**: complete
**When**: 2026-10-14 11:27 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #395

### Scope Assessment

**Well-scoped?** Mostly — seven items across the check runner, the skill, the run record, the roadmap and the design doc is one PR's worth only if the run-record gap below is settled first; otherwise split the record change out.
**Right repo?** Yes — workspace (skill, `sitrep_checks.sh`, roadmap, design doc).
**Serves**: Easy to use ("Work is easy to come back to"), The long view ("Know whether it works") — `docs/design.md#documentation-layers`
**Design picture?** Changes Documentation layers (Direction row) — the issue records the owner's decision (2026-10-14) and names the design update (scope item 7), so no re-ask.
**Dependencies**: none identified; #388 and the all-roots loop are explicitly out of scope.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | OK | Decision recorded in the issue; Direction row update is in scope (ADR-0017). |
| Give the user what they need now | OK | This is the principle the issue serves. |
| Verify before claiming | Watch | Orientation slots each read a file or command this run (git remote, roadmap tables), consistent with the skill's rule. The "in progress" rows must be read through the check runner, not by the model scanning the roadmap, so the slot keeps a command as its source. |
| A change includes its consequences | Action needed | "Since last time ... in words" and "regressed since last run" cannot be composed from the current run record: `sitrep` step 4 records only `lines t/n deferrals t/n`, the inbox count and the last inbox line, not per-line results. The issue does not put a record-format change in scope. Either add it (a per-line result field, with the writer in step 4, the reader in step 2, and `--summary-from` validation moving together) or cut those two phrases back to counts. |
| A change includes its consequences | Action needed | The "eight lines" top block does not fit as written: five sentences plus a six-row Direction path is already eleven. Define how a line is counted (the path as one chain on one or two lines, or only unresolved rows expanded) or the acceptance test cannot be passed. |
| Enforce what matters, as simply as possible | Watch | Zero-or-more-than-two in-progress rows is a yes/no check at the right place. Two tables in the roadmap carry `in progress` (the step table: steps 5 and 6; the Cutover table: rows 2 and 7), so the table must be picked by its `| Step | Item |` header inside the Workspace Redesign section, as the Direction tables are picked by header. |
| Test what breaks | Watch | Item 5 says tests like the rest of the script: include a fixture with the Cutover table also holding in-progress rows (must not count), and the new row kind must be accepted by `--summary-from` validation (which rejects unknown kinds) or the run record breaks. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0017 — Design document is the current picture | Yes | Item 7 covers it. |
| 0013 — progress.md vocabulary | No | The run record is a machine-local file, not a progress entry. |
| 0016 — session roots | Watch | The skill runs in project sessions via `$WS_ROOT`; the git-remote slot must name the workspace repo, not the cwd's, and keep the `|| echo .` idiom. |

### Consequences

- `sitrep_checks.sh` header, `--summary-from` row validation and `test_sitrep_checks.sh` for a new row kind (or output mode) for the step table.
- `.claude/skills/sitrep/SKILL.md` steps 1, 2, 4 and 5 (report template, Rules) and its description line.
- `docs/roadmap.md` Direction Format paragraph if the runner now reads outside the Direction section.
- No `AGENTS.md` script-table entry mentions the sit-rep scripts, so none to update.

### Recommendations

- Item 6 misreads the table: step 5's Item cell is already short ("Hosted projects anywhere, project-rooted sessions via the user tier (design B)"); the paragraph of PR numbers is its Notes cell. Reword the scope as plain-wording the Item cells of the in-progress rows (drop "design B"), not moving detail out of them.
- Make the Item cells grammatical after "We are ...": steps 5 and 6 would compose as "We are Hosted projects anywhere ... and Port `ros2_colcon` adapter". Write the cells as activity phrases ("making hosted projects work anywhere ...") and say so in the roadmap header, since the wrong-sounding-means-stale loop depends on the cell reading as a sentence.
- Say what the report shows when exactly two rows are in progress and they are unrelated (today: steps 5 and 6) so the composed "We are" still reads as one direction, or decide one row is marked and the other is not.
- State where the `gz4d`-style project name comes from: the acceptance-case paragraph prints as written from the roadmap, and the skill text must name no project (project-agnostic rule).

### Actions
- [ ] "Since last time ... in words" and "regressed since last run" cannot be composed from the current run record: `sitrep` step 4 records only `lines t/n deferrals t/n`, the inbox count and the last inbox line, not per-line results. The issue does not put a record-format change in scope. Either add it (a per-line result field, with the writer in step 4, the reader in step 2, and `--summary-from` validation moving together) or cut those two phrases back to counts.
- [ ] The "eight lines" top block does not fit as written: five sentences plus a six-row Direction path is already eleven. Define how a line is counted (the path as one chain on one or two lines, or only unresolved rows expanded) or the acceptance test cannot be passed.
- [ ] Item 6 misreads the table: step 5's Item cell is already short ("Hosted projects anywhere, project-rooted sessions via the user tier (design B)"); the paragraph of PR numbers is its Notes cell. Reword the scope as plain-wording the Item cells of the in-progress rows (drop "design B"), not moving detail out of them.
- [ ] Make the Item cells grammatical after "We are ...": steps 5 and 6 would compose as "We are Hosted projects anywhere ... and Port `ros2_colcon` adapter". Write the cells as activity phrases ("making hosted projects work anywhere ...") and say so in the roadmap header, since the wrong-sounding-means-stale loop depends on the cell reading as a sentence.
- [ ] Say what the report shows when exactly two rows are in progress and they are unrelated (today: steps 5 and 6) so the composed "We are" still reads as one direction, or decide one row is marked and the other is not.
- [ ] State where the `gz4d`-style project name comes from: the acceptance-case paragraph prints as written from the roadmap, and the skill text must name no project (project-agnostic rule).

## Checkpoint
**Status**: complete
**When**: 2026-10-14 12:12 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Owner: "Go with your proposed, I think." The proposal accepted all six Issue Review actions with these resolutions: (1) add a per-line result field to the sit-rep run record so "since last time" can be composed in words; (2) the path renders grouped (done / regressed / not yet / after), one line per group, which defines the eight-line top block; (3) scope item 6 reworded: plain-word the step table's Item cells, the notes stay; (4) in-progress Item cells written as activity phrases that read after "We are"; (5) two in-progress steps are listed in table order, "We are X. Also in progress: Y", the table is not changed; (6) the skill names no project; gz4d appears only in the roadmap paragraph printed verbatim. The five watch items go to the plan as written.

## Plan Authored
**Status**: complete
**When**: 2026-10-14 12:15 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-395/plan.md` at `55d7dce6`

The runner gains `step` and `proof` rows plus `--results-from` and `--path-from`, the run record gains a per-line `results` field (old records still read), and the skill composes a top block of at most eight lines from those command outputs with the inbox cut to one line. Roadmap drafts, design doc rows and tests are in the plan; three open questions are listed for plan review.
