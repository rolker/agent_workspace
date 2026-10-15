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

## Checkpoint
**Status**: complete
**When**: 2026-10-14 13:01 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Owner: "The eight findings all seem like small details to me, so let's go with your recommendation." Revise the plan with all eight Plan Review findings accepted. The plan's three open questions are closed as the review said: the inbox "now" bin feeds Suggested next only on an explicit inbox ask; the path shows names and result words without check text; "The proof is" stands. No owner edits to the two roadmap drafts at this point; the owner edits them when the implementation lands.

## Plan Authored
**Status**: complete
**When**: 2026-10-14 13:04 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-395/plan.md` at `e4390723`

Revision after the Plan Review: all eight findings fixed in the plan text (--last contract and last_results hand-off, regressed is true to false/partial only, reword and duplicate-text behaviour, the four changing test assertions, design gaps-paragraph sentence, step table picked by header alone, content below the eight-line block, draft wording), open questions closed.

## Plan Review
**Status**: complete
**When**: 2026-10-14 13:06 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #395 — sit-rep: open with a composed orientation (repo, step in progress, proof, path), one source per slot; inbox to one line
**Plan**: `.agent/work-plans/issue-395/plan.md` at `e4390723`
**Branch**: `feature/issue-395`

Second review, after the revision that answered the first Plan Review's eight findings (checkpoint: revise, all eight accepted). Each finding was checked against `sitrep_checks.sh`, `test_sitrep_checks.sh`, `SKILL.md`, `docs/roadmap.md` and `docs/design.md`, not against the plan's own claims.

### Prior findings

| # | Finding | State | Checked against |
|---|---|---|---|
| 1 | Existing test assertions break | Resolved in substance; the named list misses two (new finding 3) | Test file lines 133, 177, 356, 363, 366, 374-375; runner lines 658-668 (unreadable roadmap emits only the `section` row, so 177 holds) |
| 2 | `--last` contract fails the first run | Resolved: `-` is an empty list, `--last` omitted for no record or an older one, step 2 prints `last_results=`, all three tested. One gap left (new finding 4) | SKILL.md step 2 (`cut -f4`, `cut -f5-`) |
| 3 | Regressed group shows unchecked lines as failed | Resolved: true -> false/partial only, true -> unknown/unchecked is `not-yet` / `changed`, result word in every group, tested | SKILL.md rule "a line that could not be checked never reads as a line that failed" |
| 4 | Reworded and duplicate lines | Resolved: stated (`new` + `gone`, "perhaps reworded"), occurrence-numbered keys, tested | — |
| 5 | Design gaps paragraph goes stale | Resolved: the "net change only" sentence (design.md 110-112) is edited; OQ-3's reason is off (new finding 5) | design.md lines 105, 110-113, 651 |
| 6 | Hard-coded section heading | Resolved: table picked by its `Step`/`Item` header anywhere outside fences; the Format bullet says so. `Step \| Item` heads exactly one roadmap table (line 138; Cutover is `Order \| Item`, line 157) | roadmap.md |
| 7 | What sits outside the eight lines | Resolved: format rows, root-only caveat, flight, inbox, Suggested next below; roadmap-problem line 1 keeps the slug; unchecked deferrals stay `unchecked` | — |
| 8 | Draft wording | Resolved: "first after We are, the second after Also in progress:"; ADR-0016 carries its title. The lowercase start is handled by a new transform (new finding 1) | roadmap.md line 18 (label `**Acceptance case.**` exists today) |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Five files, one PR; unchanged. |
| Issue alignment | Needs work | Serves: "Easy to use ("Work is easy to come back to"), principle "Give the user what they need now", The long view ("Know whether it works"); design section `docs/design.md#documentation-layers`" — unchanged from the first review's check. The issue says the acceptance paragraph is "printed as written"; the new lowercasing rule changes owner text in a way that is wrong for some starts (finding 1). |
| File targeting | Good | Unchanged; no reader of the step-table Item cells besides the new runner pass (`update_roadmap.sh` changes the Status column of a `#N` row). |
| Consequences | Needs work | Two more test assertions break than the plan names (finding 3); one design-doc sentence becomes misleading (finding 5). |
| Principle alignment | Needs work | Test what breaks: the lowercasing rule fails one of its own listed test cases (finding 1). |
| ADR compliance | Good | ADR-0017: design doc in the same change. ADR-0016: workspace remote via `git -C "$WS_ROOT"`. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Approach / Test what breaks]** (Medium) The lowercasing rule contradicts its own test and mangles some starts. Item 1: "first letter lowercased when it is an ASCII capital not followed by a capital or digit". The test list says `I/O` is left alone, but under that rule `I` is followed by `/`, so it becomes `i/O`. The same rule turns a paragraph that starts with a proper noun or "I" ("GeoZui4D ...", "Roland ...", "I ...") into "geoZui4D", "roland", "i", in a slot the issue says is "printed as written". The Format bullet then tells the owner to start with a capital, which invites exactly those starts. It is sound for today's draft ("A run" -> "a run") and for acronyms. The plan's "as the owner decided" (line 238) is not in the record: the checkpoint says "The proof is" stands and that the owner edits the drafts later, not that the paragraph starts with a capital. Fix one way and test it: lowercase only a leading article from a closed list (`A`, `An`, `The`), stated in the Format bullet; or take finding 8's colon label (`**Acceptance case:** a ...`) and drop the transform. Correct the `I/O` test case to match.
2. **[Approach]** (Low) The template `The proof is <proof row>.` appends a period to a paragraph that ends in one (the draft ends "...roots))."), giving "(Sessions and roots).."; the plan's own "Printed by the sit-rep as" shows one. Say the period is added only when the row does not end in `.`, and test it.
3. **[Consequences]** (Low) Test lines 363 and 366 (prose-only and empty Direction section: `cut -f1-3 <<< "$OUT"` compared to one `section` row) also break: the roadmap was read, so `(no step table)` and `(no acceptance case paragraph)` rows follow. The catch-all sentence in item 9 covers them, but the Files to Change and Consequences rows list only 133, 356 and 374-375. Add 363 and 366.
4. **[Approach]** (Low) A malformed `--last` makes `--path-from` exit 2 "with no rows", so the whole path (lines 5-8) is lost, not only the "since" sentence that item 5 words as "not comparable: <reason>". Say step 3 reruns `--path-from` without `--last` on exit 2, so the path still prints with since `none`, and test it.
5. **[Consequences / ADR-0017]** (Low) design.md line 113, "the roadmap holds no status column", reads wrong once the sit-rep reads the step table's `in progress` status; narrow it to the Direction section. The design draft names "each Workspace Redesign step marked in progress" while the runner picks the table by header; say "the step table (header `Step | Item`)". The plan's reason for keeping OQ-3 ("not a measure beyond the acceptance case") answers a different phrase than OQ-3's ("a measure beyond counts of lines true"); per-line results are literally beyond counts, so either reword OQ-3's tail (for example "beyond which lines are true") or give the reason that fits its words.

### Summary

All eight first-round findings are fixed in the plan text; finding 1 is fixed in substance with two assertions left off its named list. The one transform the revision added, lowercasing the proof's first letter, is not sound as written: it fails its own `I/O` case and lowercases proper nouns. Each finding is a sentence-level plan edit; none changes the structure.

### Recommended Actions

- [ ] Replace the lowercasing rule with a closed-list article rule (A/An/The) or a colon label with no transform; fix the `I/O` test case; drop "as the owner decided" or cite where it was decided.
- [ ] Add the period to "The proof is ..." only when the row does not already end in one; test it.
- [ ] Add test lines 363 and 366 to the named list of assertions that change.
- [ ] On `--path-from` exit 2 with `--last`, rerun without it so the path still prints; test it.
- [ ] Narrow design.md "the roadmap holds no status column" to the Direction section; name the step table by its header in the design draft; fix the OQ-3 reasoning or wording.

## Checkpoint
**Status**: complete
**When**: 2026-10-14 14:46 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Owner: "proceed". Proceed to implementation with the second Plan Review's five leftovers folded in: the implementation applies them to plan.md in its first commit and builds from the corrected plan. The five: (N1) drop the lowercasing transform and print the acceptance paragraph after a colon label, "The proof: <paragraph as written>", no transform and no test for one; (N2) no period appended after the proof paragraph; (N3, finding 1 leftover) test lines 363 and 366 named among the assertions that change; (N4) a malformed --last makes step 3 rerun --path-from without --last, so only the since-last-time sentence is lost, not the path; (N5, finding 5 leftover) docs/design.md: reword "the roadmap holds no status column" now that the sit-rep reads the step table's status, drop the "Workspace Redesign" name from the design draft since the table is picked by its header, and recheck the OQ-3 reasoning against OQ-3's own phrase. The review-code plan-drift check verifies the fold-in.

## Checkpoint
**Status**: complete
**When**: 2026-10-15 12:24 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: implementation
**Decision**: restart

The owner restated the issue at goal level on 2026-10-15 (issue body, "What I want"): what to work on next towards the goals, where in-progress work stands, and what problems he should know about (stale documentation, research or a health check due, measured by work done since). The 2026-10-14 scope (composed orientation slots, per-line change tracking, run-record field) is superseded and folded into the issue body as history. The implementation commit `f293a4bb` serves that scope and is to be reverted by the new plan's first commit (a hard reset was declined; the commit stays in history).

This issue is the rehearsal for the loop carrying a goal-level issue without the owner in the details, before the GeoZui4D acceptance run. Contract: the owner answers only goal-level questions (goal meant; two of his goals in tension; outward or hard-to-undo action). Mechanism decisions are made from docs/principles.md and docs/design.md and listed in each hand-back for veto. A mechanism question reaching the owner is logged as a loop defect. Judged against the three things above and "Work is easy to come back to", not the previous scope.

Evidence that led here: this issue's own timeline cited principles 20 times without once testing the plan's scope against the purpose it serves; both plan reviews rated scope "Good" by file count.

## Issue Review
**Status**: complete
**When**: 2026-10-15 13:10 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #395

### Scope Assessment

**Well-scoped?** Yes, once the previous scope is dropped. The goal is three outputs (what next toward the goals; where in-progress work stands; problems he should know about) in a form that is easy to digest. Today's `/sitrep` already produces the first two from checked facts (Direction lines, deferrals, in-flight branches and PRs, `.claude/skills/sitrep/SKILL.md`). What it lacks is the third (nothing reads staleness, or whether research or an audit is due) and a shape he can take in at a glance (it opens with line counts and an inbox sort). That is a change to one skill file plus, at most, a few read-only commands. The old scope (new runner rows, a per-line run-record field, roadmap cell rewrites) answers a different question: how to compose an orientation paragraph. None of it gives him problems or a due check.
**Right repo?** Yes, workspace.
**Serves**: Easy to use ("Work is easy to come back to") and The long view ("Know whether it works") — `docs/design.md#documentation-layers` (Direction and the healthy/measures gap rows).
**Design picture?** No change if the problems section only reads existing places. It changes Documentation layers only if a new file is added to record a cadence or a last-run date; the decision below avoids that.
**Dependencies**: none blocking. Commit `f293a4bb` on this branch implements the old scope and the new plan's first commit should revert it (the commit stays in history).

### What the principles cut or change

- Give the user what they need now: cuts the report's opening. The first thing he sees is one sentence of direction (the roadmap's in-progress step, or the next Direction line not yet true), then what to do next, then problems. Counts, the inbox sort and the format rows go below, or behind `/sitrep inbox`. The obvious implementation adds sections; this one moves and removes them.
- Only what's needed: cuts the composed-orientation slots, the run-record per-line field, the `--path-from`/`--results-from` modes and the roadmap Item rewrites. "Since last time" can say "first run / lines moved: N" from the existing summary counts. Nothing in the three outputs needs line-level history.
- Verify before claiming: changes how "due" is said. A problem is stated as checked facts ("last audit-workspace re-examination 2026-10-12; 41 commits to main since") and a one-line judgment ("probably due"), never as a bare "due".
- Ask about what matters: cuts the cadence question. The issue says to ask once where a cadence is not written. A standing cadence is a mechanism choice, so v1 carries none: it reports days and work done since, and the agent judges.
- Know whether it works: requires one test of the result, not a unit test of a parser. The acceptance is that the first real sit-rep after merge has a "Problems" section with at least the three checks below printed from commands, and the owner can say in one reading what he would do next.
- A change includes its consequences: changing the skill's report template means its description line, the Rules section, and `docs/design.md` Direction paragraph (ADR-0017), and the old `f293a4bb` tests (`test_sitrep_checks.sh`) go with the revert.
- Enforce what matters, as simply as possible: no new check kinds in the runner. Staleness facts are read by commands in SKILL.md, the way step 3 already reads PRs.

### Smallest change that satisfies the three things

1. **Next toward the goals**: keep the existing source order for "Suggested next" but open the report with it and with the Direction line it advances.
2. **State of in-progress work**: keep the In flight section, one line per branch, ready PRs first (already built).
3. **Problems**: add a Problems section from three checked facts, each a command in SKILL.md: (a) days since the last `/audit-workspace` re-examination (newest `Re-examined` date in the design.md Decision register) and commits to main since; (b) days since the research digest's `Last full refresh` header (`.agent/knowledge/research_digest.md`) and commits since; (c) documentation staleness: `check_design_anchors.sh` result and the number of design-document sections whose files changed since the document's last change-log row (git only). When one looks overdue, the report says so and offers to start `/audit-workspace` or `/research --refresh` in the background; it starts one only when the owner says yes (these write files and use quota; it is an action the owner has not asked for).
4. **Digestibility**: a fixed shape under about fifteen lines: Direction sentence, Suggested next, In flight, Problems, one closing question; inbox and counts last.

Net effect on code: SKILL.md and its tests of behaviour only; revert `f293a4bb`; no runner change.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | Action needed | Drop the old scope's runner modes, run-record field and roadmap cell rewrites; none of them delivers a "problems" output or a due check. |
| Give the user what they need now | Action needed | Reorder the report so direction, next step, in-progress work and problems come first, and counts and the inbox sort come last. |
| Verify before claiming | Action needed | Each problem line prints its facts (dates, commits since) from a command run this invocation, then a judgment; no uncommunicated thresholds. |
| Ask about what matters, and show how much | OK | No cadence question to the owner; thresholds are the agent's judgment now and become a rule only if he vetoes. |
| Know whether it works | Watch | Judge by the first real run: does the Problems section print three checked facts, and is the next step one he accepts? Look again after a week of use. |
| A change includes its consequences | Watch | Description line, Rules, Direction paragraph in design.md, and removal of the old tests. |
| Leave in a project only what it chose to carry | Watch | In a project session the audit and research facts are the workspace's; the report says the Problems section is the workspace's only, and does not read the project (zero footprint). |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0017 — Design document is the current picture | Yes | One Direction/sit-rep paragraph update in the same change. |
| 0016 — session roots | Watch | `$WS_ROOT` idiom for every new command. |
| 0013 — progress.md vocabulary | No | The report is not a progress entry. |

### Consequences

- `.claude/skills/sitrep/SKILL.md`: description, steps 3 and 5, Rules.
- `docs/design.md` sit-rep/Direction paragraph and change-log row; OQ-3's wording ("a measure beyond counts of lines true") fits unchanged.
- Revert of `f293a4bb` including its additions to `.agent/scripts/tests/test_sitrep_checks.sh`.

### Recommendations

- Plan first commit reverts `f293a4bb`; the plan states what each principle above cut, not that it is served.
- Add the Problems section (audit, research, documentation staleness) as read-only commands in SKILL.md; no new runner kinds and no new files.
- Reorder the report: direction sentence, suggested next, in-progress work, problems, then counts and inbox; target under about fifteen lines for the top.
- When something looks overdue the report offers to start it in the background and starts it only on a yes.
- Acceptance: run `/sitrep` for real after merge and confirm the three Problems facts print and the owner can name his next step from the first screen; look again after a week.

### Decisions made (owner may veto)

- **No cadence setting.** The report gives days and work done since and says "probably due"; no stored threshold. A veto ("audit every N days") becomes a standing rule and a one-line roadmap entry.
- **Last audit is read from the newest `Re-examined` date in the Decision register**, since `/audit-workspace` keeps no run log; the report names this as the source so a wrong date is traceable.
- **Overdue work is offered, not started**, because it writes files and uses quota.
- **The old per-line "since last time" and path/regressed grouping are dropped**; "since last time" shrinks to the existing counts.
- **Roadmap Item cells and acceptance paragraph are not rewritten by this issue.**
- **No new files or runner check kinds**, so no Documentation layers change.

No owner-level questions: the goal reading (next step, in-progress state, problems, easy to digest) matches the issue text, no two goals conflict, and nothing outward-facing or hard to undo happens.

### Actions
- [ ] Drop the old scope's runner modes, run-record field and roadmap cell rewrites; none of them delivers a "problems" output or a due check.
- [ ] Reorder the report so direction, next step, in-progress work and problems come first, and counts and the inbox sort come last.
- [ ] Each problem line prints its facts (dates, commits since) from a command run this invocation, then a judgment; no uncommunicated thresholds.
- [ ] Plan first commit reverts `f293a4bb`; the plan states what each principle above cut, not that it is served.
- [ ] Add the Problems section (audit, research, documentation staleness) as read-only commands in SKILL.md; no new runner kinds and no new files.
- [ ] Reorder the report: direction sentence, suggested next, in-progress work, problems, then counts and inbox; target under about fifteen lines for the top.
- [ ] When something looks overdue the report offers to start it in the background and starts it only on a yes.
- [ ] Acceptance: run `/sitrep` for real after merge and confirm the three Problems facts print and the owner can name his next step from the first screen; look again after a week.

## Plan Authored
**Status**: complete
**When**: 2026-10-15 12:27 -0400
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-395/plan.md` at `c853c528`

Replacement plan for the restated goal: first commit reverts f293a4bb; sit-rep report reordered (direction, next, in flight, problems, then counts and inbox); Suggested next is the first unmet Direction line plus the branch its issue names; new Problems step reads audit, research and documentation staleness with read-only commands and starts a due read-only check in the background; writes are only offered. Files: SKILL.md, design.md row.
