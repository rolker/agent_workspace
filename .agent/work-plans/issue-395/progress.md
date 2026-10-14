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

## Plan Review
**Status**: complete
**When**: 2026-10-14 12:21 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #395 — sit-rep: open with a composed orientation (repo, step in progress, proof, path), one source per slot; inbox to one line
**Plan**: `.agent/work-plans/issue-395/plan.md` at `55d7dce6`
**Branch**: `feature/issue-395`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Five files, one PR; the record writer, reader and validator must move together, so splitting would not help. |
| Issue alignment | Good | All seven scope items and the six checkpoint resolutions are carried (resolutions 1-6 map to items 3, 5, roadmap drafts, 4). Serves: "Easy to use ("Work is easy to come back to"), principle "Give the user what they need now", The long view ("Know whether it works"); design section `docs/design.md#documentation-layers`" — checked against README `### Easy to use` / `### The long view` and `docs/principles.md`; "Know whether it works" is the principle serving The long view, not a README phrase. |
| File targeting | Good | Right five files; `update_roadmap.sh` keys on issue number and column 4, not the Item cell (checked); no other reader of the rewritten cells or the acceptance paragraph (grepped). |
| Consequences | Needs work | Existing test assertions break (finding 1); the design doc's gaps paragraph becomes untrue (finding 5). |
| Principle alignment | Needs work | The Regressed group can show a line that could not be checked as failed (finding 3); reworded lines lose their history (finding 4). |
| ADR compliance | Good | ADR-0017: design doc in the same change, but see finding 5. ADR-0016: repo slot reads `git -C "$WS_ROOT"` with the root idiom. ADR-0013 / ADR-0010 not triggered. |
| ROS conventions | N/A | Workspace plan. |

Checks the host asked for:
- Old records stay readable: yes. Inserting at field 5 keeps `inbox <n>` at field 4 (step 2's `cut -f4`), and an old record's field 5 is a capture date, never `results `, so the shape test is sound. Gap: what step 3 is handed for an old record vs no record (finding 2).
- Grouping keyed by item text survives a reword: no (finding 4).
- "We are" sentence from the drafted cells: reads correctly ("We are letting projects live anywhere, with sessions started from the project's own root, through the user tier. Also in progress: porting the `ros2_colcon` adapter.").
- Skill names no project: yes; `gz4d` appears only in the roadmap paragraph. The runner names the workspace's own `Priority: Workspace Redesign` heading (finding 6).
- Top block fits eight lines: yes by the checkpoint's definition (1 This is/We are, 2 Also in progress, 3 proof, 4 since, 5-8 four groups); what sits outside it is not said (finding 7).
- Cutover decoy: the Cutover table is under a `###` heading inside the same `##` section, so header picking (`Step`, `Item`) is what excludes it; the plan does that and tests it.

### Findings

1. **[Consequences]** (Medium) The plan says existing tests stay green, but `step` and `proof` rows are emitted on every run, and four assertions in `test_sitrep_checks.sh` expect only Direction rows: line 133 (kind set is exactly `line`), line 177 (roadmap unreadable: exactly one row), line 356 (no Direction section: exactly one row), lines 374-375 (header-only tables: exactly one row). Say which way: emit `step`/`proof` only when the roadmap was read (keeps 177) and change the other three to filter by kind, or list them as tests that change.
2. **[Approach]** (Medium) The `--last` contract contradicts itself. Item 4 passes `--last "<results field, or none>"`, but item 2 exits 2 for any `--last` that is not `N:<word>` pairs, so the first run (`none`) and a record whose field is `-` (no lines, which `--results-from` prints) both fail and the orientation is not composed. Also: shell state does not persist between steps, so say which command output carries the last record's results field to step 3 (e.g. step 2 prints `last_results=<field>|none|older-record`), since "first run" and "the last run recorded no per-line results" are different sentences and `--path-from` cannot tell them apart without `--last`. Fix: omit `--last` for none/older, accept `-` as an empty list, test both.
3. **[Principle alignment]** (Medium) The `regressed` group is "was true in `--last`, is not now", so a true line whose check could not run this time (`unknown`, e.g. gh offline) prints under "Regressed since last run". The skill's own rule (SKILL.md "a line that could not be checked never reads as a line that failed") forbids that. Make `regressed` true -> false (and perhaps partial) only, put true -> unknown/unchecked under Not yet with since `changed`, show the result word in every group, and test it.
4. **[Approach]** (Medium) Keying by `cksum` of the item text survives reordering and added lines, not rewording: a reworded line reads as "a line was added" plus "1 line is gone", and a line that was true, is reworded and is now false is not reported as regressed. The composition loop invites exactly these edits ("if it sounds wrong, edit the roadmap"). State the behaviour in the "since" sentence (e.g. "one line is new and one is gone, perhaps reworded") and test it; two lines with identical text share a key, so say what happens (refuse, or key by text plus occurrence).
5. **[Consequences / ADR-0017]** (Medium) `docs/design.md` Documentation layers, gaps paragraph: "The run record counts lines true from run to run, which shows net change only (one line going true while another goes false reads as no change)" becomes untrue once the record keeps each line's result. Edit that sentence in the same change, alongside the Measures row; check whether the OQ-3 row's "a measure beyond counts of lines true" still reads right (it does if per-line results count as the same measure; say so).
6. **[File targeting]** (Low) The runner hard-codes the heading `Priority: Workspace Redesign`. When that priority finishes or is renamed, the "We are" slot drops out and the fix is a script edit, against the issue's rule that a wrong orientation is fixed by a roadmap edit. At least say in the roadmap Format bullet that the sit-rep reads the table under that heading; better, let the roadmap name the table it reads. The issue names this table, so the plan follows it; flag only.
7. **[Issue alignment]** (Low) Say where the rest goes so the eight-line count holds: `format` rows (today "a problem in the Direction section"), the "Workspace root only" caveat, whether line 1 keeps "This is <slug>." in the roadmap-problem case, and that an `unchecked` deferral in the After group shows `unchecked`, never `due`.
8. **[Roadmap drafts]** (Low) The Format bullet says each in-progress Item cell is read "after We are"; the second is read after "Also in progress:" (an activity phrase reads after both, so only the wording). The acceptance paragraph would start lowercase after a bold label in the roadmap itself ("**Acceptance case.** a ..."); a colon label or letting the runner accept `.` or `:` keeps "The proof is" and reads right in both places. The printed proof keeps a bare "ADR-0016"; owner's call when editing.

### Open questions in the plan

- Suggested next without the sort: answered by recorded design. The issue's acceptance says "the inbox takes one line unless asked for the sort", and the report rule says Suggested next names the fact it rests on; a bin nobody was shown is not such a fact. Keep the plan's choice; not an owner question.
- Dropping check text from the path: follows from checkpoint resolution 2 (one line per group within eight lines); the rows file keeps the checks, and the closing question may name the check of an `unknown` line. Keep; not an owner question.
- "The proof is" vs "The proof:": answered by the issue, scope 1 (`"The proof is ..." ... printed as written`). Not open; the lowercase start is a roadmap wording matter (finding 8), decided when the owner edits the draft.

### Summary

The plan carries every checkpoint resolution and the composed sentences read well, but the `--last` contract fails the first run as written, the Regressed group breaks the skill's unknown-is-not-false rule, the claim that existing tests stay green is wrong, and one design-doc sentence goes stale. Each is a sentence-level plan edit; no restructuring needed.

### Recommended Actions

- [ ] Fix the `--last` contract: omit for no record or an older record, accept `-` as an empty list, and have step 2 print the last record's results field (or which case applies) for step 3; test first run, older record and empty list.
- [ ] Make `regressed` true -> false only; true -> unknown/unchecked goes under Not yet with since `changed`; show the result word in every group; test it.
- [ ] State and test what a reworded Direction line and a duplicated line text produce in "since last time".
- [ ] List the four existing test assertions that change (lines 133, 177, 356, 374-375 of `test_sitrep_checks.sh`) and whether `step`/`proof` rows are emitted when the roadmap was not read.
- [ ] Add the Documentation layers gaps-paragraph sentence ("net change only ...") to the design-doc edits; note OQ-3's wording either way.
- [ ] Say where `format` rows, the "Workspace root only" caveat and the roadmap-problem line sit relative to the eight-line block, and that unchecked deferrals show `unchecked`.
- [ ] Mention in the roadmap Format bullet that the step table is read under the `Priority: Workspace Redesign` heading (or let the roadmap name it); fix "after We are" wording for the second step.
