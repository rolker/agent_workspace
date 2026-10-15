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

## Plan Review
**Status**: complete
**When**: 2026-10-15 12:31 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #395 — sit-rep: when I ask "what's next?", say what to work on towards the goals, where in-progress work stands, and what problems I should know about
**Plan**: `.agent/work-plans/issue-395/plan.md` at `c853c528`
**Branch**: `feature/issue-395`

### Evaluation

Tested first against the owner's three wants, by running today's checks (`sitrep_checks.sh` on main, `worktree_list.sh --json`, `gh pr list`) and reading what the planned rules would print.

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | Right shape and small (revert, one skill, one design row), and it adds the missing third want. But on today's facts the planned report gets want 1 wrong (findings 1, 2) and leaves want 2 where it is (finding 3). Smallest fix stays small: one roadmap line, two lookups in In flight, a changed direction line. |
| Issue alignment | Needs work | Covers all three wants and the issue review's actions, and correctly overrides the review's "offered, not started" with the owner's own words ("you might even launch it in the background"). Misses "where something is not written down, ask": the research cadence IS written (research skill, 30 days per entry) and the plan ignores it (finding 4). Serves: Easy to use ("Work is easy to come back to") and The long view ("Know whether it works"); `docs/design.md#documentation-layers` — checked, the goal and section exist. |
| File targeting | Needs work | `docs/roadmap.md` Direction table needs one line (finding 1). Otherwise right. |
| Consequences | Needs work | design.md gap paragraph on "healthy" (finding 9); project-session and non-Claude paths for the background start (finding 8). |
| Principle alignment | Needs work | See findings; each says what the principle cuts or changes. |
| ADR compliance | Good | ADR-0017 handled in the same change; ADR-0016 `$WS_ROOT` idiom noted; ADR-0013 not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment — want 1, Suggested next]** The rule gives the wrong answer on today's roadmap. Today's rows: lines 1–4 `true`, line 5 "A `/run-issue` run started from the project root reaches the merge checkpoint" `unchecked` (empty check cell), line 6 "ADR-0016 is promoted" `false`. Step 3 contradicts itself: "first unmet (result not `true`)" picks line 5, but "an `unknown`/`unchecked` line is still not a source" skips it to line 6, the last link, which is the very fault the plan sets out to fix. Taking line 5 instead does no better: it names no issue, and issue 332 (onboard-project registers and audits projects) is named nowhere in the roadmap, so the rule prints "nothing in flight advances it" while `feature/issue-332` is the work that serves it. Issue 332's own body records that onboarding is "held before the gz4d acceptance run". The Direction chain is missing that link. Fix: (a) unmet = any result but `true`, with the result word printed (an `unknown` first line says "check could not run", and the rule does not skip past it, because the chain is ordered); (b) match only on the line's own cell (`(#N)` / `gh-issue N`), and drop "a `#N` in the Direction prose", which would match the Format paragraph's literal `(#N)` and the deferral rows' #265/#295; (c) add a Direction line before line 5, "The acceptance project is onboarded through onboard-project (#332)", check `gh-issue 332 closed`; (d) write the expected output on today's roadmap into the plan's acceptance step: "Next: the acceptance project is onboarded — onboard-project registers projects… (issue 332), in flight on feature/issue-332". The plan's Context also misstates the old rule: it picks line 6 (ADR promotion), not the run line, because line 5 is unchecked.
2. **[Give the user what they need now — direction sentence]** "Acceptance-case paragraph, first sentence, printed as written" prints today: "ADR-0016 stays Provisional until a `/run-issue` run started from a project root passes through the merge checkpoint ([Sessions and roots](design.md#sessions-and-roots))." That is an unlabelled ADR number and a status rule, not a direction, and the project (gz4d) is in the third sentence. Cut the paragraph from the top. The direction line becomes "Acceptance case: <t> of <n> lines true; next on the path: <first unmet line's text>". Direction lines are already plain words, so nothing gets rewritten. The full paragraph moves down to the counts section.
3. **[Issue alignment — want 2; labels]** In flight is called "already built", but on today's facts its line for issue 332 reads "feature/issue-332; 2 days ago: progress: implementation for #332". The issue number has no title, which breaks the report's own rule, and it does not say where the work stands. `worktree_list.sh --json` gives `issue`, so add the issue title (git-bug first, then `gh`) and the latest `progress.md` entry heading and Status (`progress_read.py`), e.g. "onboard-project registers projects… (issue 332): Implementation complete, not yet reviewed, no pull request". That is two lookups, and they are the whole of want 2.
4. **[Background-start line; Ask about what matters]** The audit is read-only, as the plan says. `audit-workspace/SKILL.md` "Report, don't fix": it reads files and runs `worktree_list.sh`, and its only write is a PR it asks about afterwards. The anchor checker is read-only too: no temp files, no git writes, exit 0 on main. Research is a writer: every `/research` mode creates a worktree, commits, pushes and opens a pull request. The plan's "proposals only" background run is therefore not `/research --refresh`. SKILL.md must give the prompt's exact read-only subset (`--refresh` steps 2–4: read the digest, find stale entries, survey; no worktree, commit, push or PR) and return the proposed entries. Research also has a written cadence: entries more than 30 days past `Last verified` are stale, and more than 90 days are flagged. So for research, "probably due" applies that rule (today all 19 entries were verified 2026-04-19) instead of the agent's judgment. Parse only the leading date of `Last full refresh:`, since the line carries a parenthetical.
5. **[Verify before claiming — "work done since"]** The commit counts as planned are mostly bookkeeping. On main since 2026-10-09: 260 commits, of which 106 touch more than `.agent/work-plans`. Since design.md last changed: 5 under `.agent .claude docs`, of which 1 is not a work-plan commit. Count with `git -C "$WS_ROOT" rev-list --count --no-merges <sha>..main -- . ':!.agent/work-plans'`, from the commit that set the date where there is one. Name `main` explicitly, because `$WS_ROOT` falls back to `.`, which in a worktree session is a feature branch.
6. **[Verify before claiming — audit date]** The newest `Re-examined` date (2026-10-09) comes from the design rewrite, not an audit. The register says "while this document was rewritten or since by `/audit-workspace`". Label it "newest ADR re-examination (Decision register)", never "last audit". Add the fact the column gives for free: 10 of 18 ADRs "not yet". The plan's example date 2026-10-12 is not in the register.
7. **[Only what's needed — anchor check]** `check_design_anchors.sh` runs in pre-commit and CI, so it passes on main by construction. It is not a staleness measure. Print it only when it fails.
8. **[Leave in a project only what it chose to carry; Use the main tool fully, keep the work tool-neutral]** `audit-workspace` and `research` have no `session_scope`, so the plugin does not ship them to project sessions. In a project session they cannot be started; the Problems line says "run /audit-workspace from the workspace". Without the Agent tool (Codex, agy), it is offered, not started.
9. **[A change includes its consequences / Keep one current design]** The Documentation layers gap paragraph says the Direction section "says … not what healthy means". The Problems section is a first form of health signals, so add one clause there as well as the Direction-row sentence.
10. **[Labels]** The rest of the planned report is labelled, with three exceptions. Unlabelled numbers come in through roadmap text printed as written: "(#379)" in line 4, "(#265, PR 4)" and "(#295)" in deferrals, and "ADR-0016" in line 6. Apply the existing rule ("no issue or pull request number without its title beside it") to them, and extend it to ADR numbers (title from the ADR file's H1).

### Summary

This plan is the first on the issue that targets the three wants, and its size is right. On today's roadmap, though, its Suggested-next rule names the last link or "nothing in flight" instead of the onboarding work. Its direction sentence opens with an unlabelled ADR number, its In flight line still has no title or stage, and its research background run quietly departs from a skill that writes. Revise, then ready.

### Recommended Actions

- [ ] Fix step 3's contradiction (unmet = not `true`; do not skip past an `unknown`); match on the line's own cell only; add the onboarding Direction line (#332, `gh-issue 332 closed`) to `docs/roadmap.md` and the file table; put today's expected Suggested-next output in the acceptance step; correct the Context sentence about the old rule.
- [ ] Replace the direction sentence with "<t> of <n> lines true; next on the path: <first unmet line>"; move the acceptance paragraph below.
- [ ] In flight: add the issue title and the latest progress.md entry heading and Status for worktree lines.
- [ ] Research: spell out the read-only prompt subset; use the research skill's 30/90-day rule for "probably due"; parse the leading date only.
- [ ] Commit counts: `--no-merges`, exclude `.agent/work-plans`, range from the dating commit, on `main` in `$WS_ROOT`.
- [ ] Audit fact labelled "newest ADR re-examination", plus the count of "not yet" rows.
- [ ] Anchor check printed only on failure.
- [ ] Project session and non-Claude framework: offer only, with where to run it.
- [ ] design.md: one clause in the "healthy" gap paragraph as well as the Direction row and change-log row.
- [ ] Label every `#N` and ADR number printed from roadmap text.

### Decisions made (owner may veto)

- Onboarding is a Direction line before the run line. The source is issue 332's own "held before the gz4d acceptance run". It changes the acceptance chain's wording, not its goal.
- The direction line is built from the Direction lines, not the acceptance paragraph. The paragraph is not rewritten.
- Research's "due" uses the research skill's written 30-day rule. The audit and documentation facts still carry no threshold.
- The background research run is read-only and returns proposals. Applying them (worktree, commit, PR) is offered.
- The anchor check is silent unless it fails.
- In a project session, or without the Agent tool, due checks are offered and never started.

No owner-level questions: the goal reading matches the issue, no two goals conflict, and nothing outward-facing or hard to undo is planned.

## Plan Authored
**Status**: complete
**When**: 2026-10-15 12:34 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-395/plan.md` at `2c1401ab`

Revision after Plan Review 92b16637. Adds a roadmap Direction line (acceptance project onboarded, issue 332) before the run line; Suggested next treats unchecked as unmet; the direction sentence is built from the Direction lines; In flight shows issue title and latest progress entry type and status; research due follows the skill's 30-day rule with a spelled-out read-only background prompt; commit counts exclude work-plan and merge commits (git command in the plan); anchor check prints only on failure; project sessions and no-Agent-tool sessions are offered, not started. No owner-level questions.

## Plan Review
**Status**: complete
**When**: 2026-10-15 12:36 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #395 — sit-rep: when I ask "what's next?", say what to work on towards the goals, where in-progress work stands, and what problems I should know about
**Plan**: `.agent/work-plans/issue-395/plan.md` at `2c1401ab`
**Branch**: `feature/issue-395`

Round 2, convergence check on the revision after Plan Review 92b16637. Facts run this review: `sitrep_checks.sh` on main (lines 1–4 `true`, run line `unchecked`, ADR line `false`; no deferral due), `worktree_list.sh --json` (feature/issue-332, feature/issue-395), `gh pr list` (no open pull requests), `gh issue view 332` (open), `progress_read.py` on 332's timeline (last entry "Implementation complete"), issue 332's plan.

### Round-1 must-fixes

1. **Suggested-next rule (round-1 finding 1)**: resolved. Step 4: "unmet means any result other than `true` … an `unchecked` line counts as unmet and is not skipped … an `unknown` first line reads 'check could not run'"; "matched only on the line's own cell … No matching in the Direction prose". Step 2 adds the onboarding line; step 10 writes the expected output; Context now says the old rule "lands on the last link, the ADR promotion". One new defect in the added line's check, below (finding 1).
2. **Direction sentence (finding 2)**: resolved. Step 3: "built from the Direction lines, not the acceptance paragraph: '<t> lines of <n> true; next: <first unmet line's text>'"; the paragraph moves to the counts section.
3. **In flight shows where work stands (finding 3)**: resolved. Step 6: issue title (git-bug, then `gh`), latest progress entry type and status from `progress_read.py`, pull request with title; commit subject dropped.
4. **Research is a writer; written cadence (finding 4)**: resolved. Step 7: "the background run is not that skill", read-only prompt spelled out; step 5 applies the research skill's 30/90-day rule and parses the leading date of `Last full refresh:` only.
5. **Commit counts (finding 5)**: resolved. Step 5: `git -C "$WS_ROOT" rev-list --count --no-merges <sha>..main -- . ':!.agent/work-plans'`, on `main`, from the dating commit.

Round-1 findings 6–10 (audit label and "not yet" count, anchor check on failure only, project session and no-Agent-tool offer, design.md gap clause, ADR and `#N` labels) are also folded in (steps 4, 5, 7, 9).

### Walk-through on today's facts (plan as written, the new line inserted fifth)

```
## Sit-rep, 2026-10-15
4 of 7 Direction lines true; next: The acceptance project is onboarded (#332, onboard-project registers projects and audits workspace integration) — false.
**Suggested next**: that line — in flight on feature/issue-332, issue 332 (onboard-project registers projects and audits workspace integration): Implementation complete, no pull request yet.
**In flight**:
- feature/issue-332: onboard-project registers projects and audits workspace integration (issue 332): Implementation complete, no pull request yet
- feature/issue-395: sit-rep: when I ask "what's next?"… (issue 395): Plan Review complete, no pull request yet
```

Today it reads right. It says in plain words that the next step is onboarding the acceptance project and that feature/issue-332 is the work in flight for it. It goes wrong once issue 332 closes (finding 1).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Revert, one skill, one roadmap line, design.md edits. Each piece serves one of the three wants. |
| Issue alignment | Needs work | All three wants are covered, and every round-1 must-fix is resolved. The new line's check turns it true before the acceptance project is onboarded (finding 1). Serves: Easy to use ("Work is easy to come back to") and The long view ("Know whether it works"); `docs/design.md#documentation-layers`. Checked. |
| File targeting | Good | `docs/roadmap.md` added. |
| Consequences | Good | Description, Rules, "Reads only" claim, design.md row, gap clause, change log, revert of the tests. |
| Principle alignment | Needs work | Verify before claiming: a Direction line has to be true only when its check proves what it says (finding 1). |
| ADR compliance | Good | ADR-0017 handled in the same change; ADR-0016 `$WS_ROOT` idiom used. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Verify before claiming — the new Direction line's check]** (must-fix) `gh-issue 332 closed` shows that the onboard-project work merged. It does not show that the acceptance project was onboarded. Issue 332's own plan ("Acceptance to test") lists "The first real use (gz4d onboarding run) — not a test: the separate run you named, after PR 3". Once 332 closes, the planned line reads `true` while gz4d has not been onboarded. The report then says "5 of 7 true; next: A `/run-issue` run started from the project root…", which skips the onboarding run. Nothing on disk records "onboarded" yet; 332 is still designing that. Exact change: in plan step 2, step 10, the Files table and the Decisions list, the line becomes "The acceptance project is onboarded through onboard-project (#332)" with an **empty check cell**. It reads `unchecked`, which the new rule counts as unmet and does not skip, and step 2's confirmation becomes "reads `unchecked`". Add a Consequences row: when 332 lands a record of onboarding, its check goes in this cell, a roadmap edit the sit-rep will prompt. Today's output changes only "false" to "unchecked". After 332 merges it reads "next: The acceptance project is onboarded… — unchecked; nothing in flight advances it", which is true: the onboarding run is the next step.

### Summary

All five round-1 must-fixes are resolved by the plan's own text, and on today's roadmap the report puts onboarding first with the 332 branch in flight. One must-fix remains, a one-cell change: the added line's check proves that the tool merged, not that the project was onboarded. With it, the plan is ready. It can be folded into the implementation's first plan.md commit, as on 2026-10-14.

### Recommended Actions

- [ ] Leave the new Direction line's check cell empty and word the line "The acceptance project is onboarded through onboard-project (#332)". Update steps 2 and 10, the Files table and the Decisions to match, and add the Consequences row (332 supplies the check once onboarding is recorded).

### Decisions made (owner may veto)

- The onboarding line is `unchecked` until onboarding leaves a record. No new check kind, and no marker file is invented here.
- The walk-through is the acceptance evidence for the report order. The long issue title is printed beside each number as written, not shortened.

No owner-level questions: the goal reading matches the issue, no two goals conflict, and nothing outward-facing or hard to undo is planned.

## Checkpoint
**Status**: complete
**When**: 2026-10-15 12:37 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (under the issue's contract: no owner-level question arose)
**After**: plan
**Decision**: proceed

Plan Review round 2 (50ceea68): all five round-1 must-fixes resolved; the walk-through against today's roadmap and worktrees reads right ("next: the acceptance project is onboarded; in flight on feature/issue-332"). One must-fix left, a single table cell: the new Direction line's check `gh-issue 332 closed` would turn true when the onboard-project work merges, before the acceptance project is actually onboarded. Resolution: the implementer folds it into the plan as its first commit, wording the line "The acceptance project is onboarded through onboard-project (#332)" with an empty check, so it reads `unchecked` until onboarding is recorded somewhere. No third plan review; the pre-push code review sees both.

Decisions made this round (owner may veto): the onboarding line stays unchecked until onboarding is recorded; long issue titles print in full; the host decided the checkpoint itself, since the contract reserves the owner for goal-level questions only and none arose.

## Implementation
**Status**: complete
**When**: 2026-10-15 13:23 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-395 at `9e433cfe`

Implemented the plan at `2c1401ab`, with Plan Review 50ceea68's must-fix folded in first.

### Commits

- `f886fe85` Fold the round-2 plan review's must-fix into the #395 plan: the onboarding line is "The acceptance project is onboarded through onboard-project (#332)" with an empty check cell (reads `unchecked`); steps 2 and 10, Files, Consequences (new row: 332 supplies the check once onboarding is recorded), Decisions.
- `993b018a` Revert of `f293a4bb` (old-scope runner modes and their tests). `sitrep_checks.sh` and `test_sitrep_checks.sh` are byte-identical to `69f33366`; `test_sitrep_checks.sh`: 141 passed, 0 failed.
- `2ee42294` roadmap: the onboarding Direction line, before the project-root run line. `sitrep_checks.sh` reads it `unchecked`.
- `7220e06c` sitrep skill rewrite plus tests. Report order: direction sentence, Suggested next, In flight, Problems (about 15 lines), then counts with the acceptance-case paragraph, inbox (one line; sort only on `/sitrep inbox`), deferrals. Steps 1-4 keep their numbers and blocks. Step 3 gains a second block (issue title, latest timeline entry via `progress_read.py`). New step 5: the first non-`true` line, with issue and ADR titles and the branch or pull request its own cells name. New step 6: Problems, read from local main, with commit counts by `git -C "$WS_ROOT" rev-list --count --no-merges <sha>..main -- <paths> ':!.agent/work-plans'`. New step 7: start or offer a due check, with both prompts written out. New step 8: the report and its rules. The description, Usage and "What it is" are updated. Tests: `skill_step` takes a block index; new cases for step 3 block 2, step 5 and step 6.
- `75743968` design.md: Documentation layers Direction row sentence, gaps-paragraph clause (the Problems section is a first form of health signals), change-log row (756 lines).
- `9e433cfe` roadmap: the scenario 4 "first form" paragraph describes the new order.

### Verification

- `bash .agent/scripts/tests/run_script_tests.sh`: all 37 suites passed (368 s). `test_sitrep_checks.sh`: 154 passed, 0 failed. `test_skill_paths.sh`: 58 passed, 0 failed.
- `bash .agent/scripts/check_design_anchors.sh`: exit 0, no output.
- `pre-commit run --all-files` (workspace `.venv`; bare `pre-commit` is not on PATH): exit 0, every hook Passed or Skipped.

### Dry run (real workspace, 2026-10-15)

Steps 1, 2, 3, 5 and 6 were run by hand. Step 1 used `--root` set to the main checkout and `--roadmap` set to this branch's roadmap, so the new line is included. Step 4 was not run, so no run-record line was written, and its rows file was removed. No background check was started. The audit and the research survey would both have been started in the background (workspace session, Agent tool available). The first ten lines:

```
## Sit-rep, 2026-10-15
4 of 7 Direction lines true; next: The acceptance project is onboarded through onboard-project (#332, onboard-project registers projects and audits workspace integration (overrides, conflicting instructions, ignore rules, misplaced conventions, unverified registration)) — unchecked (no check yet).
**Suggested next**: that line — in flight on feature/issue-332, onboard-project registers projects and audits workspace integration (…) (issue 332): Implementation complete, no pull request yet.
**In flight**:
- feature/issue-332: onboard-project registers projects and audits workspace integration (…) (issue 332): Implementation complete; no pull request yet
- feature/issue-395: sit-rep: when I ask "what's next?", say what to work on towards the goals, … (issue 395): Checkpoint complete; no pull request yet
**Problems**:
- Audit: newest ADR re-examination (Decision register) 2026-10-09, 6 days and 124 commits ago; 9 of 18 ADRs not yet re-examined — probably due; would start in the background (not started: dry run).
- Research: 19 of 19 digest entries last verified more than 30 days ago (19 more than 90); last full refresh 2026-04-19 — probably due; would start in the background (not started: dry run).
- Documentation: docs/design.md last changed 2026-10-13, 2 days ago; 17 commits since touched .agent/, .claude/ or docs/ — recent.
```

(The "(…)" stands for the full title printed earlier on the line; the real report prints it in full.)

### Deviations

- Issue titles come from `gh issue view` first and from the git-bug cache (`issue_lookup`) only when gh fails, marked "(offline: git-bug cache)". The plan said git-bug first. Checked here: the cache still holds issue 395's old title ("sit-rep: open with a composed orientation …"), and a sit-rep that prints a stale title breaks "Verify before claiming".
- The research prompt reads `<workspace root>/.agent/knowledge/research_digest.md` instead of the bare relative path. `test_skill_paths.sh` rejects workspace-relative paths in a `session_scope: both` skill. The `show` helper takes `$WS_ROOT/<path>` for the same reason.
- The plan's Files table did not name two changes made here: `docs/roadmap.md`'s scenario 4 paragraph (it described the old report order, a consequence), and new tests in `test_sitrep_checks.sh`.

### Decisions made (owner may veto)

- Steps 1-4 keep their numbers. The new steps are 5 (next step), 6 (problems), 7 (start or offer) and 8 (report), so the existing step tests keep running unchanged.
- Step 5 gets the line's text through a quoted here-document (`<<'ROW'`), so an apostrophe or `$` in roadmap text stays as written. A `gh-issue owner/repo#N` check names no workspace branch.
- Problems are read from committed `main` (`git show main:<path>`), not the working tree, so a worktree session sees what has landed.
- Added tests for step 3's second block and for steps 5 and 6: number extraction, worktree matching, no-remote behaviour, ADR titles, the acceptance paragraph, commit counts that skip merges and work-plan-only commits, the 30/90-day rule, the anchor check printed only on failure, and "cannot tell" with no history. The plan cut parser tests "as the proof"; these are regression guards for code the skill runs, not the acceptance test.
- A project worktree's issue title is looked up in that worktree's own remote, and its timeline is read where it exists. `session_root.sh` says reading across roots is allowed; nothing is written.
- An In flight line puts the worktree part first and the pull request part second. With a matching pull request, its title follows after "; ".

### Noticed, not changed

- Step 2 prints `inbox_oldest=# Inbox`: the real inbox file starts with a heading line, which the step counts as an entry. This is existing behaviour and outside this plan.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-15 13:32 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-395 at `c1bb3f26`
**Base**: main
**Depth**: Deep (reason: 543 changed lines outside work plans; skill and design.md are governance files)
**Must-fix**: 4 | **Suggestions**: 8
**Round**: 1 | **Ship**: continue — round 1: 4 must-fix; first round always re-reviews after fixes

Run in branch mode (not `--pr 396`) so the entry is the Pre-Push type the exit contract names; the diff is the same. Specialists: static (shellcheck not installed, so not run; `test_sitrep_checks.sh` 154/0 and `test_skill_paths.sh` 58/0 run), governance, plan drift, Claude adversarial, cross-model Gemini (complete, EXIT=0) and Codex (complete, EXIT=0). Step 6 was run against the real workspace: audit 18 ADRs / 9 not yet, newest 2026-10-09, 124 commits; research 19/19 past 90 days; design.md 2026-10-13, 17 commits. Revert checked: no diff under `.agent/scripts/` between `69f33366` and `993b018a`, and `sitrep_checks.sh` at HEAD is identical to `69f33366`.

Owner readability (priority 1): all three wants are present and ordered first. The top block repeats the next line's ~150-character issue title up to three times (finding 4). The background-start rule holds: it starts only in a workspace session with the Agent tool. The audit prompt matches the audit skill (report only; its one write is a PR it asks about). The research prompt correctly avoids the writing skill. The skill names no project.

### Findings
- [x] (must-fix) Decision-register awk splits on escaped `\|`: the ADR-0002 row (`workspace\|project`) reads `[Worktrees](#worktrees)` as its Re-examined value, so a re-examination date there is silently lost; strip `\|` before splitting (`{ gsub(/\\\|/, "") }`), also skip `| --- |` separators (`$2 !~ /^[ :-]+$/`), and add a test row with `\|` — `.claude/skills/sitrep/SKILL.md:403-407`
- [x] (must-fix) Package worktrees (ADR-0012, `.worktree-repos`): the listed path is an aggregate directory, so `git -C "$path" remote get-url origin` gives no remote or an enclosing repo's, and the wrong issue's title is printed; when `$path/.worktree-repos` exists take the repo from its header `issue=<owner/repo>#<N>`, look for progress.md in the manifest entries' checkouts, and add a test — `.claude/skills/sitrep/SKILL.md:208-221`
- [x] (must-fix) The git-bug fallback `issue_lookup` runs `git bug bridge pull github` on a cache miss, writing refs, which breaks the skill's "Reads only" claim; use a cache-only read (`_issue_lookup_gitbug "$root" "https://github.com/$slug/issues/$n"`) or drop the fallback, in both places — `.claude/skills/sitrep/SKILL.md:215,348`
- [x] (must-fix) The top block is harder to read than it needs to be: the direction sentence, Suggested next and In flight each print the next line's full issue title (dry run: the same ~150-character title three times in lines 2-5). Print each title once, in full, where it first appears, and refer to it later as "issue <N>". The direction sentence gives the count, the line and its result word; Suggested next gives the in-flight state; In flight marks that branch "(the next step, above)" — `.claude/skills/sitrep/SKILL.md:532-538,566-575`
- [x] (suggestion) Research survey restarts every session while any entry is stale (today 19/19), a 19-topic web survey per `/sitrep`; cap the background prompt to the 3 oldest entries — `.claude/skills/sitrep/SKILL.md:510-519`
- [x] (suggestion) The audit prompt names no root; a background agent whose cwd is a feature worktree audits that branch, so prefix "From <workspace root> (the main checkout), ..." — `.claude/skills/sitrep/SKILL.md:506-509`
- [x] (suggestion) The research prompt should say "Last verified (or Added if never verified)" like step 6, and give the research skill's path (`<workspace root>/.claude/skills/research/SKILL.md`) — `.claude/skills/sitrep/SKILL.md:513-516`
- [x] (suggestion) jq guard: `(.closingIssuesReferences // [])[]`, and skip refs with no `.repository`; null aborts the pull-request lookup (reproduced, rc=5) — `.claude/skills/sitrep/SKILL.md:358-360`
- [x] (suggestion) Step 6 reads local `main`, which can lag `origin/main`; print `main..origin/main` count when the ref exists, or label the facts "as of local main" — `.claude/skills/sitrep/SKILL.md:384-389`
- [x] (suggestion) No test exercises step 5's `gh pr list --jq` filter; add a stub `gh` returning JSON (closing refs present, empty, null) and assert the `pull_request` row — `.agent/scripts/tests/test_sitrep_checks.sh`
- [x] (suggestion) A due deferral no longer reaches the top block while any line is unmet (it is only in "Deferrals due" at the bottom); list due deferrals under Problems — `.claude/skills/sitrep/SKILL.md:576-583`
- [x] (suggestion) The "about 15 lines" budget has no rule for many worktrees; cap In flight at 5 lines then "and <k> more" — `.claude/skills/sitrep/SKILL.md:523-538`

### Dismissed
- Gemini 3 (`gh-issue N` needs a trailing space): the grammar always has a state word after N (`sitrep_checks.sh:87-88`). Gemini 4 (`Provisional, not yet`): the register cell is `not yet`. Gemini 5 (skill worktrees dropped): block 1's JSON still lists them, as the text says. Gemini 6 (ADR title not on line 1): every ADR's line 1 is `# `. Gemini 8 (trailing slash): the prefix strip still matches. Gemini 7 (gh before git-bug): the recorded, justified deviation, kept.
- Adversarial 4 (first unmet line is "registered", `unknown`): an artifact of running the worktree's copy of the runner, whose root has no registry; the skill runs `$WS_ROOT`'s.

### Decisions made (owner may veto)
- Issue titles from gh first, git-bug cache only on failure: departs from ADR-0010; accepted because the cache held a stale title.
- A long issue title is printed once, in full, then "issue <N>" (finding 4); not shortened, per Plan Review 50ceea68.
- Background research stays auto-started (the owner's words allow it); the cost is handled by the cap in the suggestion, not by asking.
- Branch mode used for this review to match the Pre-Push entry type.

No owner-level questions.

## Implementation
**Status**: complete
**When**: 2026-10-15 14:20 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-395 at `4837c2c7`
**Addressed**: Local Review (Pre-Push) at `c1bb3f26` (2026-10-15 13:32 -04:00)
**Commits**: 586b42e4 24534642 8089eea7 b16f443d 55aadb73 458bc51d 3059ce17 115f2930 87ab8c3a d1377d7a 853eaf68 c2103310 4837c2c7

Address-findings pass on the pre-push review, with the host's wording fixes and the owner's go-ahead to name the project in the roadmap.

### Actions
- [x] (must-fix) Decision-register awk drops escaped `\|` before splitting and skips spaced separators; test row with `\|` holding the newest date, confirmed failing on the old awk — `586b42e4`, `.claude/skills/sitrep/SKILL.md` step 6
- [x] (must-fix) Package worktrees: repository from the `.worktree-repos` header (`issue=<owner/repo>#<N>`); bare `issue=<N>` only when every checkout agrees, else "unknown (its checkouts are in different repositories)"; timeline looked for at the aggregate root, then each listed checkout; tests for both header forms — `b16f443d`, step 3
- [x] (must-fix) git-bug fallback is cache-only (`_issue_lookup_gitbug`) in steps 3 and 5; stub-git-bug test proves no `bridge` call on a miss, confirmed failing on the old code — `8089eea7`
- [x] (must-fix) Titles once: an issue's title prints only in its In flight line, which is marked ", the next step"; elsewhere "issue <N>" — `c2103310`, step 8
- [x] (suggestion) Background research covers the 3 oldest stale entries — `115f2930`, step 7
- [x] (suggestion) Audit prompt runs "From <workspace root> (the main checkout ...)", the path git names first, since `$WS_ROOT` falls back to the cwd — `458bc51d`, step 7
- [x] (suggestion) Research prompt says "Last verified (or Added, if never verified)" and gives the research skill's path and section — `3059ce17`, step 7
- [x] (suggestion) jq guard `(.closingIssuesReferences // [])[]`, refs without a repository skipped — `55aadb73`, step 5
- [x] (suggestion) `main_behind_origin` printed (no fetch); report says when above 0, or heads Problems "(as of local main)" — `87ab8c3a`, step 6
- [x] (suggestion) Stub gh applying `--jq` with real jq: null refs (placed first, so the old filter aborts; confirmed), branch match, closing ref here; not another repo, bare ref, empty, or fork — `55aadb73`, `test_sitrep_checks.sh`
- [x] (suggestion) Due deferrals listed under Problems on every run — `c2103310`, step 8
- [x] (suggestion) In flight capped at five lines, then "and <k> more: <names>"; the next step's branch always shown — `c2103310`, step 8

### Host wording fixes
- `c2103310`: "4 of 7 steps done"; result words from a table (done / not yet done / not yet done (no automatic check) / partly done (its checks disagree) / could not be checked); "last design-decision review", "design decisions not yet reviewed", "research topics"; Suggested next restates the line as an action, then "In flight on <branch>: <state>", with no "that line".
- `853eaf68`: line 2 is the first sentence of the Direction section's `**Acceptance case.**` paragraph, read by an awk + regex block in step 5 that runs even when the checks did not; absent paragraph, line left out; tests (a link with dots, one sentence, a paragraph outside the section).
- `d1377d7a`: In flight states from a table in step 3 (Plan Review → plan reviewed, not yet implemented; Checkpoint after plan, proceed → plan approved, implementing; Implementation → implemented, plus "no pull request yet" in the report; Local Review → in code review; Integrated Review → review findings being addressed; plus issue review, plan authored, other checkpoint decisions, merge records). Unknown entries print as they are. A test covers every row.
- `24534642` (owner, via host): the Direction line reads "GeoZui4D (`gz4d`) is onboarded through onboard-project (#332)", check cell still empty; the plan's quotes follow. The skill names no project.
- `4837c2c7`: plan step 10 (acceptance) expects the reworded top block.

### Verification
- `bash .agent/scripts/tests/run_script_tests.sh`: all 37 suites passed (379 s); `test_sitrep_checks.sh` 166 passed, 0 failed; `test_skill_paths.sh` 58 passed, 0 failed.
- `bash .agent/scripts/check_design_anchors.sh`: exit 0.
- `pre-commit run --all-files` (the main checkout's `.venv`; the worktree has none): exit 0.
- Intermediate commits used `SKIP=validate-script-tests` (the documented WIP skip); `test_sitrep_checks.sh` ran before each, and the full suite ran on the final tree. The first commit ran every hook.

### Dry run (real workspace, 2026-10-15)

Steps 1, 2, 3, 5 and 6 by hand from this branch's skill, `$WS_ROOT` the main checkout, step 1 with this branch's roadmap. Step 4 not run; no background check started. First twelve non-blank lines:

```
## Sit-rep, 2026-10-15
ADR-0016 stays Provisional until a `/run-issue` run started from a project root passes through the merge checkpoint ([Sessions and roots](design.md#sessions-and-roots)).
4 of 7 steps done; next: GeoZui4D (`gz4d`) is onboarded through onboard-project (issue 332) — not yet done (no automatic check).
**Suggested next**: Onboard GeoZui4D (`gz4d`) through onboard-project (issue 332). In flight on feature/issue-332: implemented, no pull request yet.
**In flight**:
- feature/issue-395: sit-rep: when I ask "what's next?", say what to work on towards the goals, where in-progress work stands, and what problems I should know about (issue 395): in code review; pull request 396: ready
- feature/issue-332: onboard-project registers projects and audits workspace integration (overrides, conflicting instructions, ignore rules, misplaced conventions, unverified registration) (issue 332), the next step: implemented, no pull request yet
**Problems**:
- Audit: last design-decision review 2026-10-09, 6 days and 124 commits ago; 9 of 18 design decisions not yet reviewed — probably due; would start in the background (not started: dry run).
- Research: 19 of 19 research topics last checked more than 30 days ago (19 more than 90); last full refresh 2026-04-19 — probably due; the 3 oldest would start in the background (not started: dry run).
- Documentation: docs/design.md last changed 2026-10-13, 2 days ago; 17 commits since touched .agent/, .claude/ or docs/ — recent.
**Steps**: 4 of 7 done. Not yet done: GeoZui4D (`gz4d`) is onboarded through onboard-project (issue 332) — not yet done (no automatic check); A `/run-issue` run started from the project root reaches the merge checkpoint — not yet done (no automatic check); ADR-0016 (Session roots and the user tier) is promoted from Provisional to Accepted — not yet done.
```

Facts behind it: rows `lines 4/7 deferrals 0/4`; step 3 states "implemented" (332) and "in code review" (395); PR 396 ready, no review decision; `main_behind_origin=0`; no deferral due.

### Decisions made (owner may veto)
- Line 2 prints the roadmap's sentence as written, so it carries "ADR-0016", "`/run-issue`" and a markdown link. If it reads wrong, the fix is the roadmap's acceptance paragraph, not the skill.
- In the next-step sentence `(#<N>` reads `(issue <N>`; otherwise the line is as written.
- Suggested next is the one place the skill rewords a fact (the line as an action), with the line printed as written just above it; "What it is" says so.
- A pull request joined to a branch is "pull request <M>" (the issue title labels the line); the PR title prints only for a PR with no worktree.
- State words for entries the host did not list (issue review, plan written, other checkpoint decisions, merge records, partial/failed status) are mine; an unknown entry prints as it is. "No timeline" reads "no progress record yet".
- "could not be checked" for `unknown`; "partly done (its checks disagree)" for `partial`.
- Due deferrals sit under Problems; the bottom Deferrals line gives the count and those with no automatic check.
- The step 8 rewrite carries must-fix 4 and suggestions 11 and 12 in one commit, since they are one template.

### Noticed, not changed
- One `test_sitrep_checks.sh` run of eleven reported 165/1; ten reruns, including the full suite, were clean. I could not catch which case; the step 1 kill-timing test is the likely one (pre-existing).
- Step 2 still prints `inbox_oldest=# Inbox` (heading counted as an entry), as the last entry noted.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-15 14:27 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-395 at `6d836b60`
**Base**: main
**Depth**: Deep (reason: whole-branch diff 4 files +804 -87 outside work plans; skill and design.md are governance files; fix rounds classify on the whole diff, #320)
**Must-fix**: 4 | **Suggestions**: 4
**Round**: 2 | **Ship**: continue — round 2: 4 must-fix is high; another independent read warranted

Round 2: convergence check on round 1 (`c1bb3f26`) plus the fix pass `c1bb3f26..6d836b60`. Run in branch mode, not `--pr 396`: PR mode writes `## Local Review`, and the loop expects this Pre-Push entry type with a round counter; the diff is the same. Specialists: governance, plan drift, Claude adversarial (fresh subagent on the fix diff), cross-model Gemini and Codex (the skill's rule: a fix round is classified on the whole diff, so Deep, so cross-model runs again).

**Round-1 findings, all twelve resolved**: escaped pipe `586b42e4` (test "(skill 6) audit", row with `\|` holding the newest date); package worktrees `b16f443d` (three "(skill 3) package worktree" tests; new gaps below); cache-only git-bug `8089eea7` ("(skill 5) a cache miss does not pull from GitHub"); titles once `c2103310` (dry run prints each title once); research cap `115f2930`; audit root `458bc51d`; research prompt wording `3059ce17`; jq guard and gh stub test `55aadb73` ("(skill 5) pull requests: null references…"); behind origin `87ab8c3a` ("(skill 6) no origin/main", "(skill 6) origin/main one commit ahead"); due deferrals under Problems and the In flight cap `c2103310`. The template items (titles once, deferrals, cap) have no test, and the dry run is their evidence.

**Suite**: `bash .agent/scripts/tests/run_script_tests.sh` gave "all 37 suites passed in 319s"; `test_sitrep_checks` 166 passed, 0 failed; `test_skill_paths` 58 passed, 0 failed. Earlier commits skipped the script-test hook (`SKIP=validate-script-tests`); this run on `6d836b60` is the check.

**Flaky run (165/1)**: the implementation entry does not name the test, and its output was not kept. I ran `test_sitrep_checks.sh` four more times concurrently, to load the machine: 166/0 each time. I cannot tell which case it was. The likely candidates are the timing tests that were already on main and that this branch does not change: "(interrupt now) …", "(skill 1) TERM" (each asserts the killed check is gone after a fixed `sleep 0.2`) and "(timeout) unknown after Ns". This looks like a fixture timing margin, not a race in the new skill code. Not pursued in this pull request (decision below).

**Reviewers**: Gemini ran (EXIT=0) with 5 findings: one taken (must-fix 2), the rest dismissed below. Codex ran (EXIT=0) with 3 findings, all taken (must-fix 3 and 4). Copilot's hosted review failed on both heads (`c1bb3f26`, `6d836b60`): "the user who requested the review has reached their quota limit", so it found nothing. Claude adversarial: no must-fix; 4 suggestions (two folded into must-fix 3 and 4).

**Owner readability**: I read the dry-run top block against his three wants. Next step: present, and the next step is right (onboard GeoZui4D, in flight on feature/issue-332). Where in-progress work stands: present, in state words. Problems: present, judged. Line 2 fails "easier to digest" (must-fix 1). It is the first line he reads, and it is all mechanism: "ADR-0016 stays Provisional until a `/run-issue` run started from a project root passes through the merge checkpoint ([Sessions and roots](design.md#sessions-and-roots))", with a bare ADR number and raw markdown link syntax. Everything else in the top block uses his vocabulary. "(issue 332)" in lines 3-4 is labelled by the line's own words, and its title follows in In flight under the round-1 "titles once" rule.

### Findings
- [x] (must-fix) Report line 2 is mechanism vocabulary with a bare number. In the roadmap, make the acceptance paragraph's first sentence the goal in the owner's 2026-10-14 words, e.g. "Run an issue in GeoZui4D (`gz4d`) from the project's own directory, all the way to where it is ready to merge." Keep the ADR-0016 sentence second. In the skill, line 2 also gets an ADR's title beside its number and prints a markdown link as its text, as the next-step sentence does. Add a test for the link and the ADR title. — `docs/roadmap.md:21`, `.claude/skills/sitrep/SKILL.md:740`
- [x] (must-fix) Step 3's `while IFS=$'\t' read -r type repo branch issue path` loses a field when one is empty. Tab is IFS whitespace, so consecutive tabs collapse. A worktree with no branch (detached HEAD, e.g. mid-rebase) or no repo shifts every later field: the issue number becomes the path, and the title and state are looked up for the wrong thing. Reproduced: `IFS=$'\t' read -r a b c d <<< $'x\t\tz\tw'` gives b=z. Print a placeholder (`-`) for empty fields in the python, or use a non-whitespace separator (`$'\x1f'`), and add a test with an empty branch. — `.claude/skills/sitrep/SKILL.md:206-207`
- [x] (must-fix) Package worktree lookups can mix repositories. (a) The timeline search walks every listed checkout and takes the first `issue-<N>/progress.md`, so a checkout of another repository with its own issue N supplies the state beside this issue's title. Search only the aggregate root and the checkouts whose remote is the issue's repository. (b) With a bare `issue=<N>` header, a checkout with no GitHub remote resets the agreement (`[ -z "$agree" ]`), so "no remote, then foo/bar" resolves to foo/bar. Count an empty slug as disagreeing. Add tests for both. — `.claude/skills/sitrep/SKILL.md:216-231,252`
- [x] (must-fix) Three state words say the opposite of the record. (1) `Merge (report-only)` is written when the merge check found problems and the merge went ahead (`merge_pr.sh:638-641`), not when it was held; say e.g. "merged past the merge check's findings". (2) A complete `Integrated Review` with no open boxes is not "review findings being addressed"; read the entry's `findings` (`checked`) and say "reviews triaged, nothing open" when none are open. Apply the same to `Local Review`: its Verdict or open boxes give "code review asked for changes" or "code review passed". (3) Look entries up by `base_type`, so the legacy `External Review (round 2)` headings map too. Update step 3's table and the state test. — `.claude/skills/sitrep/SKILL.md:257-268,305-316`
- [x] (suggestion) "implemented, no pull request yet" applies to every worktree with no joined pull request. Project worktrees are never joined, so the phrase is wrong for them; limit it to `type: "workspace"`. — `.claude/skills/sitrep/SKILL.md:785-787`
- [x] (suggestion) Checkpoint decisions `retry` (after phase-failed) and `restart` (after implementation) fall through to "checkpoint after phase-failed: retry". Map them to words, e.g. "a step failed; retrying" and "implementation restarting". — `.claude/skills/sitrep/SKILL.md:276-279`
- [x] (suggestion) Step 3's cache-only git-bug fallback has no test; only step 5's does. Add the same stub-git-bug case for step 3. — `.agent/scripts/tests/test_sitrep_checks.sh`
- [x] (suggestion) The Documentation problem line prints paths (".agent/, .claude/ or docs/"). Say "the workspace's scripts, skills or docs" in the report; the paths stay in step 6. — `.claude/skills/sitrep/SKILL.md:690-691`

### Dismissed
- Gemini 2 (`gh-issue N` needs a trailing space): same as round 1. The grammar always puts a state word after N (`sitrep_checks.sh:87-88`).
- Gemini 3 (`(#1, #2)` catches only the first): the Direction Format paragraph has each number written `(#N)`, and no line has two.
- Gemini 4 (`feature/issue-<N>-desc` branches missed): `worktree_create.sh:531` names `feature/issue-<N>`, and the closing-reference match covers custom names.
- Gemini 5 ("e.g. " splits the acceptance sentence): roadmap text, and the roadmap holds none. A wrong-sounding line 2 is fixed in the roadmap (the design's loop).

### Decisions made (owner may veto)
- Line 2's goal sentence is drafted from the owner's own 2026-10-14 words ("The next major step is running an issue in GeoZui4D"), not invented, and the ADR-0016 sentence stays as the second sentence.
- The flaky 165/1 case is not chased in this pull request. It is unidentified, did not recur in five runs (one full suite, four concurrent), and its likely source is the kill-timing tests already on main.
- Branch mode used instead of `--pr 396`, to write the Pre-Push entry type the loop counts rounds on.
- Cross-model re-ran in round 2, because the skill classifies fix rounds on the whole diff (#320).

No owner-level questions.

## Implementation
**Status**: complete
**When**: 2026-10-15 14:47 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-395 at `c8f02bee`
**Addressed**: Local Review (Pre-Push) at `6d836b60` (2026-10-15 14:27 -04:00)
**Commits**: 13d13937 0998d239 0f57a603 e441fbd9 84c6b175 f82ff94f 6ba42c52 35020d44 cb821906 c8f02bee

Address-findings pass on round 2: four must-fix and four suggestions, all actioned, none deferred.

### Actions
- [x] (must-fix) Report line 2: the roadmap's acceptance paragraph replaced with the host's text from the owner's words (`13d13937`); the OQ-2 note is now its own paragraph, unchanged. Step 5's acceptance block renders every piece of roadmap text the report prints (acceptance case, plus Direction lines and deferrals pasted between `TEXT` markers): a markdown link as its text, an ADR number with its file's title unless a parenthesis follows; tests for links, titles, no doubling, `(#N)` after an ADR, a missing ADR file, the placeholder (`0998d239`) — `docs/roadmap.md:18`, `.claude/skills/sitrep/SKILL.md` step 5
- [x] (must-fix) Step 3 reads each worktree field by name with jq; no branch reads `(no branch)`; test with a null branch, an empty branch and no repo beside a complete worktree, confirmed failing on the old `read` (`0f57a603`) — step 3
- [x] (must-fix) Package worktrees: title cache and timeline only from checkouts whose remote is the issue's repository; with a bare `issue=<N>`, a checkout with no GitHub remote disagrees; unknown repository gives unknown title and state; tests for a same-numbered timeline in another repository (listed first, and alone), a no-remote checkout, a bare header all in one repository, confirmed failing on the old code (`e441fbd9`) — step 3
- [x] (must-fix) State words from base type plus open boxes: "code reviewed" / "reviews triaged", then "<k> findings to address" or "nothing open"; `Merge (report-only)` reads "merged although the merge check found problems"; suffixed headings such as `External Review (round 2)` map; the full mapping is step 3's table; tests for each case, confirmed failing on the old code (`84c6b175`). Follow-up: review-code's unchecked "No issues found. LGTM." placeholder is not counted, with a test (`f82ff94f`) — step 3
- [x] (suggestion) "implemented, no pull request yet" only for workspace worktrees (`35020d44`) — step 8
- [x] (suggestion) Checkpoint phase-failed retry/takeover and merge-refused retriage get state words, with tests; there is no `restart` decision in the run-issue vocabulary, so none is mapped (`6ba42c52`) — step 3
- [x] (suggestion) Step 3 cache-only git-bug test: gh failing, cached title, a miss, no `bridge` call (`c8f02bee`) — `test_sitrep_checks.sh`
- [x] (suggestion) The documentation problem line says "the design document" and "the workspace's scripts, skills or docs", not paths (`cb821906`) — steps 6 and 8

### Verification
- `bash .agent/scripts/tests/run_script_tests.sh`: all 37 suites passed (272 s); `test_sitrep_checks` 175 passed, 0 failed; `test_skill_paths` 58 passed, 0 failed.
- `bash .agent/scripts/check_design_anchors.sh`: exit 0.
- `pre-commit run --all-files` (the main checkout's `.venv`): exit 0.
- Commits used `SKIP=validate-script-tests`; `test_sitrep_checks.sh` ran before each, and the full suite ran on `c8f02bee`.

### Dry run (real workspace, 2026-10-15)

Steps 1, 2, 3, 5 and 6 by hand from this branch's skill, `$WS_ROOT` the main checkout, steps 1 and 5 with this branch's roadmap. Step 4 not run; no background check started. First twelve non-blank lines:

```
## Sit-rep, 2026-10-15
A bare project that was never onboarded is made ready and used: GeoZui4D (`gz4d`) is registered, onboarded, and an issue there runs through the loop with the workspace's goals and principles visibly driving the work.
4 of 7 steps done; next: GeoZui4D (`gz4d`) is onboarded through onboard-project (issue 332) — not yet done (no automatic check).
**Suggested next**: Onboard GeoZui4D (`gz4d`) through onboard-project (issue 332). In flight on feature/issue-332: implemented, no pull request yet.
**In flight**:
- feature/issue-395: sit-rep: when I ask "what's next?", say what to work on towards the goals, where in-progress work stands, and what problems I should know about (issue 395): code reviewed, nothing open; pull request 396: ready
- skill/research-20261015-142112-924701598; pull request 397: ready
- feature/issue-332: onboard-project registers projects and audits workspace integration (overrides, conflicting instructions, ignore rules, misplaced conventions, unverified registration) (issue 332), the next step: implemented, no pull request yet
**Problems**:
- Audit: last design-decision review 2026-10-09, 6 days and 124 commits ago; 9 of 18 design decisions not yet reviewed — probably due; would start in the background (not started: dry run).
- Research: 19 of 19 research topics last checked more than 30 days ago (19 more than 90); last full refresh 2026-04-19 — probably due; the 3 oldest would start in the background (not started: dry run).
- Documentation: the design document last changed 2026-10-13, 2 days ago; 17 commits since changed the workspace's scripts, skills or docs — recent.
```

Facts behind it: rows `lines 4/7 deferrals 0/4`; step 5 `acceptance_rest` = "Until that run passes the merge checkpoint, ADR-0016 (Session roots and the user tier) stays Provisional (Sessions and roots)." and `text=ADR-0016 (Session Roots and the User Tier) is promoted from Provisional to Accepted`; step 3 states "implemented" (332) and "code reviewed, nothing open" (395, whose boxes this pass checked); PRs 396 and 397 ready; `main_behind_origin=0`; no deferral due.

### Decisions made (owner may veto)
- The acceptance paragraph is the host's text as given. The OQ-2 sentences, which were in the same paragraph, are kept word for word as a second paragraph, including "The run's target is the `gz4d` project", which now repeats the first paragraph.
- One renderer for all roadmap text, in step 5's acceptance block; the session pastes the lines and deferrals it prints. Step 5's per-line ADR lookup is removed.
- An ADR's title comes from its file, in the file's capitals ("Session Roots and the User Tier"); a number already followed by a parenthesis is left alone, so the roadmap's own lower-case title stands. An ADR with no file stays bare.
- Review state words are mine: "code reviewed" / "reviews triaged", then the open count or "nothing open". The LGTM placeholder is excluded, found while fixing (review-code leaves it unchecked on an approval).
- A package worktree's aggregate root is no longer searched for a timeline unless it is itself a listed checkout of the issue's repository: work plans are written at the checkout's top level.
- A worktree with no branch prints "(no branch)". Step 3 uses jq, already needed by `sitrep_checks.sh`.
- All four suggestions were actioned rather than deferred; `restart` is not mapped because the run-issue vocabulary has no such decision.

### Noticed, not changed
- A skill worktree's In flight line has no title, so pull request 397 reads as a bare branch name; a pull request joined to a skill worktree could carry its own title.
- Step 2 still prints `inbox_oldest=# Inbox` (pre-existing).

No owner-level questions.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-15 14:56 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-395 at `68ca0e09`
**Base**: main
**Depth**: Deep (reason: whole-branch diff 4 files +974 -90 outside work plans; skill and roadmap are governance files; fix rounds classify on the whole diff, #320)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings; every round-2 item resolved with a test

Round 3: narrow convergence check, scoped by the host to round 2's items (entry `e70b2d91`), regressions in the fix diff `6d836b60..68ca0e09` (work plans excluded), the suite, and the dry-run report. External reviewers (Gemini, Codex) were not run: the host excluded them for a convergence check. Copilot's hosted review on PR 396 at `68ca0e09` failed again ("the user who requested the review has reached their quota limit"), as on both earlier heads, so it found nothing.

**Round-2 items, all eight resolved**:
- Must-fix 1, line 2 mechanism vocabulary: roadmap acceptance paragraph now opens with the goal (`13d13937`); step 5 renders all printed roadmap text, links as their text, ADR numbers with the file's title (`0998d239`); test "(skill 5) links print as their text; an ADR number gets its file's title unless a parenthesis follows…", plus the placeholder test.
- Must-fix 2, empty fields shift: step 3 reads fields by name with jq (`0f57a603`); test "(skill 3) no branch or no repo: the issue and path stay in place, read as (no branch)".
- Must-fix 3, package worktrees mix repositories: timeline and title cache only from checkouts of the issue's repository; a no-remote checkout disagrees (`e441fbd9`); five "(skill 3) package worktree…" tests (pkg4–pkg7 and the gh-call check).
- Must-fix 4, state words: base type plus open boxes, report-only reads "merged although…" (`84c6b175`, `f82ff94f`); state table test has 22 cases incl. `External Review (round 2)` and the LGTM placeholder.
- Suggestion, "no pull request yet" only for workspace worktrees: `35020d44` (template rule; dry run is its evidence, no test).
- Suggestion, checkpoint retry/takeover/retriage words: `6ba42c52`, three state-table cases. Round 2 also named `restart`; that was my error: `dispatch_phase.sh:678-686` has no such decision (the run-issue "restart" is a host restart).
- Suggestion, step 3 cache-only git-bug test: `c8f02bee`, tests "(skill 3) gh failing: the title comes from the git-bug cache…" and "(skill 3) a cache miss does not pull from GitHub".
- Suggestion, documentation line in words: `cb821906` (template wording; no test).

**Regression read of the fix diff**: none found. Checked: jq field reads on null/absent keys; `cut -f2` on manifest lines (always tab-separated, `wt_write_manifest`); a header slug with no matching checkout (title from gh, state "no progress record yet"); the ADR regex on `ADR-0042 (#9)`; the removed step-4 `adr` rows have no remaining reader; `base_type`, `findings[].checked` and `.text` exist in `progress_read.py`; the new checkpoint pairs match `dispatch_phase.sh` row 23/27 vocabulary.

**Suite**: `bash .agent/scripts/tests/run_script_tests.sh` exit 0, "all 37 suites passed in 335s"; `test_sitrep_checks` 175 passed, 0 failed; `test_skill_paths` 58 passed, 0 failed.

**Dry-run report (Implementation at `68ca0e09`) read as the owner**: no wrong or misleading sentence. Checked against facts: issue 332 has a workspace worktree (`feature/issue-332`) and no open pull request, so "implemented, no pull request yet" is true; open pull requests are exactly 396 and 397, both ready; issue 395's latest review entry had all 8 boxes checked when the dry run read it, so "code reviewed, nothing open" is what the record says.

### Findings
- [ ] No issues found. LGTM.

### Decisions made (owner may veto)
- The aggregate root of a package worktree is no longer searched for a timeline (round 2 had said "the aggregate root and…"). Accepted: `progress_append.sh` writes at the git top level, and the aggregate root is not a checkout; only `worktree_create.sh --workflow` writes there, an entry-less header the old code would have stopped at.
- The acceptance sentence is the host's wording, not the one round 2 drafted; both come from the owner's 2026-10-14 statement. Not re-litigated.
- The two template-only suggestions (no-PR wording, documentation wording) stand on the dry run with no test, as round 2 accepted for the template items.

No owner-level questions.
