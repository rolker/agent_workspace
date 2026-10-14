# Plan: sit-rep: open with a composed orientation (repo, step in progress, proof, path), one source per slot; inbox to one line

## Issue

https://github.com/rolker/agent_workspace/issues/395

## Context

The sit-rep (`.claude/skills/sitrep/SKILL.md`) opens with counts and a 17-line
inbox dump. Its rule is that every statement comes from a command run this
invocation, and nothing it runs says what the workspace is doing or why. The
issue (owner decisions 2026-10-14, six Issue Review actions accepted) adds an
orientation composed each run from fixed slots, one named source per slot, so
a wrong-sounding line means the roadmap is stale and the fix is a roadmap
edit. The checkpoint on `progress.md` records the six resolutions and five
watch items; this plan carries them (see "Resolutions carried").

What exists today, read for this plan:

- `sitrep_checks.sh` reads only the `## Direction` section (tables picked by
  header `| Line | Check |` and `| Deferral | Revisit check |`) and prints
  rows `kind  item  result  check  date`; `--summary-from` validates each row
  with `ROW_RE` (kinds `line|deferral|format|section`, five fields, known
  result word, date) and prints `lines t/n deferrals t/n`.
- The run record line is `when  workspace  <summary>  inbox <n>  <last inbox
  line, itself 4 TAB fields>`; step 2 reads it with `cut -f4` and `cut -f5-`.
- The roadmap's Workspace Redesign step table has header `| Step | Item |
  Issue | Status | Notes |` (steps 5 and 6 are `in progress`); the Cutover
  table under it (`| Order | Item | ...`) also has `in progress` rows (2, 7).
  `Step | Item` is the header of exactly one table in `docs/roadmap.md`
  (checked: the only other `Order`/`Step`-led table is the Cutover one).
- `test_sitrep_checks.sh` runs the skill's own shell blocks by step number
  (`skill_step <n>` = first bash block under `### <n>.`).

## Approach

Rows and the record carry the facts; the skill only composes sentences from
them. All logic that can be wrong lives in `sitrep_checks.sh` and is tested.

1. **Check runner: step and proof rows.** When the roadmap file was read, a
   second pass over it (same fence tracking and `split_row`) emits:
   - `step` rows from every table, anywhere outside code fences, whose first
     two header cells are `Step` and `Item` (case-insensitive; the Status
     column is located by its header name `Status`, so a column added later
     does not break it). The runner names no section heading: the roadmap
     says which table it reads by having that header (the Format bullet says
     so), so finishing or renaming the Workspace Redesign priority needs a
     roadmap edit, not a script edit. The Cutover table has a different header
     and is ignored by construction. One row per row whose Status is
     `in progress`: `step  <Item cell>  true  Step <n>  <date>`, in table
     order. When the count is 0 or more than 2, instead one row
     `step  (roadmap problem: <k> steps marked in progress; expected 1 or 2)
     false  none  <date>`. When no such table exists:
     `step  (no step table)  unchecked  none  <date>`.
   - one `proof` row: the Direction section's paragraph that starts
     `**Acceptance case.**`, label removed, lines joined with single spaces,
     markdown link targets dropped (`[text](url)` becomes `text`) and the first
     letter lowercased when it is an ASCII capital not followed by a capital
     or digit (so `A run` reads `a run` after "The proof is", and an acronym
     such as `ADR-0016` is left alone); those two are the only transforms.
     Result `true`; absent: `proof  (no acceptance case
     paragraph)  unchecked  none  <date>`. The text after the label starts
     with a capital in the roadmap ("**Acceptance case.** A `/run-issue`
     run ..."), hence the lowercasing above.
   - **When the roadmap was not read** (file missing or unreadable, exit 3
     path), no `step` or `proof` rows are emitted: the output stays the one
     `section` row, so the existing unreadable-roadmap test (line 177) holds.
     When it was read but has no Direction section or empty tables, `step` and
     `proof` rows are still emitted (they do not depend on the Direction
     section), after the `section` row.
   - `step` and `proof` rows do not count toward `summarize` and do not
     affect the "(no rows in the Line or Deferral tables)" test, which is
     decided before these rows are added.
2. **Check runner: `--summary-from` and the new modes, one reader.** Move the
   rows-file load and validation out of the `--summary-from` branch into one
   function used by all three modes, with `ROW_RE` accepting `step|proof`.
   Add:
   - `--results-from <rows-file>`: prints the per-line field, one
     `<key>:<result>` per `line` row in order, comma-joined. The key is
     `<cksum of item text>.<n>`, where `cksum` is POSIX decimal and `n` counts
     earlier rows with identical text (1 for the first). Keying by text
     instead of position survives reordering and added lines; the occurrence
     number makes two lines with identical text compare pairwise in file
     order instead of colliding. Empty list prints `-`.
   - `--path-from <rows-file> [--last <field>]`: prints one TAB row per
     `line` row, `<group>  <item>  <result>  <since>`, with group `done`
     (result true), `regressed` (was `true` in `--last`, is now `false` or
     `partial`: a check ran and failed) or `not-yet` (everything else, so a
     line that was true and now cannot be checked, `unknown` or `unchecked`,
     is `not-yet` with since `changed`, never `regressed`; the report prints
     the result word in every group). Since is one of `now-true`,
     `regressed`, `changed` (any other result change), `same`, `new` (no
     such key in `--last`), `none` (no `--last`). Then one `gone  <count>`
     row when `--last` has keys the roadmap no longer has, then the
     `deferral` rows as `after  <item>  <result>` (group `after`; due when
     result is true; an `unchecked` deferral stays `unchecked`).
   - **`--last` contract.** The argument is the field text itself: `-` (a
     record of a run with no lines) is a valid empty list; otherwise
     `[0-9]+\.[0-9]+:<result word>` pairs, comma-joined. Anything else exits 2
     with a message and no rows (a hand-edited record is never half-compared).
     "No record" and "older record without the field" have no field: the
     caller omits `--last`, and every `since` is `none`.
   - **Reworded and duplicate lines.** A reworded Direction line has a new
     key, so it reads as one `new` line plus one `gone`; a line that was true,
     is reworded and is now false is therefore not reported as regressed, and
     the report words it so: `a line was added and a line is gone (perhaps
     reworded)` when both are present, never as a regression. Duplicate text
     compares pairwise by occurrence; deleting the first of two identical
     lines reads as the second one `gone`.
   Same exit codes as `--summary-from` (2 unreadable/invalid, 3 roadmap not
   read). Header comment updated: kinds, modes, record field, grammar.
3. **Run record: one new field, and how step 3 receives it.** The line becomes `when  workspace
   <summary>  inbox <n>  results <field>  <last inbox line>`. Inserting at
   field 5 moves the seen inbox line to `-f6-`. Readers handle both shapes: if
   field 5 starts `results `, seen line = `-f6-`; otherwise it is an older
   record, seen line = `-f5-` and there is no per-line baseline. Step 2
   prints one more line, `last_results=<field>` (the record's results field,
   `-` included), `last_results=none` (no record at all, i.e. first run) or
   `last_results=older-record` (a record without the field), so step 3, which
   shares no shell state with step 2, is told which case applies from that
   printed line and nothing else. The writer
   (step 5 after renumbering) takes the field from `--results-from "$rows"`
   and does not write the record if that fails, like the summary does.
4. **Skill, new step 3 "Compose the orientation and the path"** (between the
   inbox step and the in-flight step; in-flight, record and report become
   steps 4, 5, 6, and the tests' `run_step` numbers move with them). It runs
   `sitrep_checks.sh --path-from "$rows"`, adding `--last "<field>"` only when
   step 2 printed one, and prints the `step` and `proof` rows from the saved
   rows file (so every slot is a command's output), plus the workspace repo
   slug from `git -C "$WS_ROOT" remote get-url origin` through
   `extract_gh_slug` (the workspace's remote, not the cwd's; keeps the
   `|| echo .` root idiom). If step 1 left no `rows_file`, the report says the
   orientation and path were not composed, with the reason.
5. **Skill report template (step 6), the top block.** Composed paragraph,
   slots in this order, a slot with no source left out, never filled from
   memory or conversation:
   - Line 1: `This is <slug>. We are <step Item cell>.` (slug from the git
     remote; no project name in the skill text).
   - Line 2, only when two steps are in progress: `Also in progress:
     <second Item cell>.` (the second cell is written to read after "Also in
     progress:", the first after "We are"; an activity phrase reads after
     both) Zero or more than two: one line instead,
     `Roadmap problem: <the step row's text>; the orientation cannot say what
     we are doing until the step table is fixed.`
   - Line 3: `The proof is <proof row>.` (printed as written).
   - Line 4: since last time, in words from the `since` column: names each
     line that went true, regressed or changed (with its result word, so
     `true -> unknown` reads as could not be checked, not as failed), says
     `a line was added` / `<n> lines are gone` for `new` / `gone` (both
     present: `a line was added and a line is gone (perhaps reworded)`),
     `nothing moved since <date>` when all `same`, `first run` for
     `last_results=none`, `the last run recorded no per-line results` for
     `last_results=older-record`, or `not comparable: <reason>`.
   - Lines 5-8: the path, one line per non-empty group in this order: `Done:`
     (true lines), `Regressed since last run:` (true -> false/partial only),
     `Not yet:` (each line in every group carries its result word in
     parentheses, so `unknown`/`unchecked` never read as `false`), `After:`
     (deferrals; `due` only when the result is `true`, an `unchecked`
     deferral shows `unchecked`). Checks are not printed (the rows file still
     holds them).
   - **Line counting, which the acceptance test needs:** a line is one
     newline-terminated report line, not a terminal wrap; the top block is
     lines 1-8, at most eight (seven with one step in progress), because each
     slot is one sentence and each path group is one line.
   - **Below the top block** (after a blank line, in this order, none of it
     counted in the eight): `format` rows ("a problem in the Direction
     section", unchanged wording), the "Workspace root only" caveat when it
     applies, then work in flight, the one-line inbox, Suggested next and the
     closing question as the skill has them. In the roadmap-problem case
     (zero or more than two steps, or no step table) line 1 is still `This is
     <slug>.` and line 2 is the `Roadmap problem:` sentence, so the block is
     at most seven lines then plus the path.
6. **Skill, inbox collapsed.** The report's Inbox part is one line: count,
   new since last run, and the new lines in a few words each (at most three,
   then `and <k> more`); `new unknown` keeps its reason. The five-bin sort and
   the first-20 list print only when invoked as `/sitrep inbox`; usage section
   and description line say so. "Suggested next" source 4 (the inbox `now`
   bin) applies only on `/sitrep inbox`; otherwise the chain stops at work in
   flight and may read "nothing from this run's facts", with one closing
   question allowed to offer the sort. `Not yet true` bullets with checks
   leave the report (the path line replaces them).
7. **Roadmap rewrites** (drafts below; the owner edits). Direction header
   paragraph: one bullet added to the Format list saying the Acceptance case
   paragraph is printed after "The proof is", and that the sit-rep reads the
   table whose header is `| Step | Item | ... | Status |` (today the Workspace
   Redesign step table; the Cutover table is not it) and prints the Item cell
   of each row marked in progress after "We are" (the second after "Also in
   progress:"), so they are written as phrases that read there; a cell that
   reads wrong there is the one to edit.
8. **Design doc.** Documentation layers, Direction row: one paragraph (draft
   below) stating the composition rule and the wrong-sounding-means-stale
   loop; the Measures row's text says the run record also keeps each line's
   result; the gaps paragraph sentence "The run record counts lines true from
   run to run, which shows net change only (one line going true while another
   goes false reads as no change) and says nothing about whether a change
   helped beyond that case" (line 110-112) is edited in the same change: the
   record now keeps each line's result, so a line going true while another
   goes false is visible; what stays true is that it says nothing about
   whether a change helped beyond the acceptance case. OQ-3's row ("a measure
   beyond counts of lines true", line 651) still reads right: per-line results
   are the same measure at finer grain, not a measure beyond the acceptance
   case, so its wording stays, checked in this change; one Change log row dated for the merge (same table as the others).
9. **Tests** (`test_sitrep_checks.sh`, same file, same style): see the list
   under "Test cases", including the four existing assertions that change
   (line numbers in the current file): line 133 (kind set is exactly `line`)
   filters to `line` rows, since `step` and `proof` rows now follow; line 356
   (no Direction section: exactly one row) and lines 374-375 (header-only
   tables: exactly one row) count and compare only `section` rows, because
   the roadmap was read and `step`/`proof` rows follow; line 177 (roadmap
   unreadable: exactly one row) stays as is, since no `step`/`proof` rows are
   emitted when the roadmap was not read. Any other whole-output assertion
   the suite shows failing is changed the same way. Run `bash .agent/scripts/tests/test_sitrep_checks.sh`,
   `test_skill_paths.sh`, `test_update_roadmap.sh`, then
   `check_design_anchors.sh` and pre-commit.

## Roadmap drafts

Direction, acceptance case paragraph. Today: "ADR-0016 stays Provisional
until a `/run-issue` run started from a project root passes through the merge
checkpoint ([Sessions and roots](design.md#sessions-and-roots)). Design
question OQ-2 ([Open questions](design.md#open-questions)) asks where that
run is tracked: here. The run's target is the `gz4d` project, as step 5 of
the Workspace Redesign table below says." Draft (two paragraphs; the second
is not the acceptance case so the sit-rep does not print it):

> **Acceptance case.** A `/run-issue` run, started from a project root on the
> `gz4d` project, that gets through the merge checkpoint. Until one does,
> ADR-0016 (Session roots and the user tier) stays Provisional
> ([Sessions and roots](design.md#sessions-and-roots)).
>
> Design question OQ-2 ([Open questions](design.md#open-questions)) asks where
> that run is tracked: here. Step 5 of the Workspace Redesign table below
> names the project.

Printed by the sit-rep as: "The proof is a `/run-issue` run, started from a
project root on the `gz4d` project, that gets through the merge checkpoint.
Until one does, ADR-0016 (Session roots and the user tier) stays Provisional
(Sessions and roots)." (The roadmap paragraph starts with a capital after its
label, as the owner decided; the runner lowercases that one first letter,
item 1.)

Workspace Redesign step table, Item cells of the rows marked in progress only
(Notes cells, statuses and every other row untouched):

> Step 5, today: "Hosted projects anywhere, project-rooted sessions via the
> user tier (design B)". Draft: "letting projects live anywhere, with
> sessions started from the project's own root, through the user tier"
>
> Step 6, today: "Port `ros2_colcon` adapter". Draft: "porting the
> `ros2_colcon` adapter"

Printed as: "We are letting projects live anywhere, with sessions started from
the project's own root, through the user tier. Also in progress: porting the
`ros2_colcon` adapter."

Format list, one added bullet (draft):

> - The sit-rep opens by reading two things here aloud: the acceptance case
>   paragraph, after "The proof is" (write it as a sentence with a capital; the
>   first letter is lowercased there), and the Item cell of each row marked
>   in progress in the table headed `| Step | Item | ... | Status |`, the
>   first after "We are", the second after "Also in progress:". Write the
>   cells as activity phrases so they read in both places. If the opening
>   sounds wrong, this is the text to edit.

Design doc, Documentation layers, Direction row, added paragraph (draft):

> The sit-rep opens with an orientation composed on each run from named
> sources, one per slot: the workspace's git remote (which repo), the Item
> cell of each Workspace Redesign step marked in progress (what we are doing;
> one or two such steps, otherwise the sit-rep reports a roadmap problem), the
> Direction section's acceptance-case paragraph (the proof), and the Direction
> lines with this run's results set against the last run record's (the path
> and what moved). A slot with no source is left out, never filled from
> memory. The orientation is not authored in the skill, so it cannot go
> stale; when it sounds wrong, the roadmap is stale and the roadmap is what
> gets edited.

## Test cases (new, in `test_sitrep_checks.sh`)

- Step rows: two in-progress step rows in table order with Item text and
  `Step n`; the Cutover table (header `Order | Item`) with in-progress rows is
  not counted; zero in progress and three in progress give the one problem
  row (`false`); a roadmap with no `Step | Item` table gives the `unchecked`
  row; the table is found under any heading; an unreadable roadmap emits no
  `step`/`proof` rows; a read roadmap without a Direction section still emits
  them; a fenced example of the
  section is not the section; Status found by header name when columns move;
  `\|` in an Item cell; the Direction rows and the summary are unchanged by
  the step rows (existing tests stay green).
- Proof row: label removed, wrapped lines joined, link targets dropped, the
  first capital lowercased (`A run` yes; `ADR-0016 ...` and `I/O` no), a
  second paragraph not included, absent paragraph gives `unchecked`; a
  `**Acceptance case.**` paragraph outside the Direction section is ignored.
- `--summary-from` accepts `step` and `proof` rows and still rejects an
  unknown kind and a cut-off row; summary counts ignore them.
- `--results-from`: same order as the lines, stable across a reorder, two
  identical-text lines get keys `.1` and `.2`, `-` for no lines; refuses the same bad files as `--summary-from`.
- `--path-from`: each group; `now-true`, `regressed` (true -> false and
  true -> partial), `changed`, `same`, `new`, `none`, `gone`; true ->
  `unknown` and true -> `unchecked` land in `not-yet` with `changed`, never
  `regressed`; a reordered roadmap compares by item; a reworded line reads as
  `new` plus `gone` (and a true -> false reword is not `regressed`); two
  identical lines compare pairwise, and deleting the first reads as one
  `gone`; `after` rows with a due deferral and with an `unchecked` one (shown
  `unchecked`); no `--last` gives all `none`; `--last -` (empty list) is
  accepted and gives all `new`; a malformed `--last` exits 2 with a message
  and no rows; roadmap-not-read exits 3.
- Skill steps: step 2 prints `last_results=` as the field, `none` (no record)
  and `older-record` (no field), and step 3 omits `--last` for the last two;
  step 3 prints the slug from the workspace remote (not the
  cwd's), prints the step and proof rows from the saved file, and says so
  without a `rows_file`; the record step writes the `results` field and an
  older record (no field) still gives the right seen inbox line and `inbox_new`
  in step 2; the existing step 2/4 tests move to the new numbers; the report wording
  for each case (first run, older record, empty list, reword); the full
  record round trip (write, then read `last results`, then `--path-from`).
- `test_skill_paths.sh`: the description line still names the trigger
  phrases ("what's next", "what should I work on", "where are we").

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/sitrep_checks.sh` | `step` and `proof` rows (only when the roadmap was read; no section heading hard-coded); shared rows loader; `--results-from`, `--path-from`; `ROW_RE` kinds; header comment (grammar, kinds, modes, exit codes) |
| `.agent/scripts/tests/test_sitrep_checks.sh` | cases above; assertions at lines 133, 356 and 374-375 change (filter by kind), line 177 stays; step numbers moved for the renumbered skill steps; record fixtures gain the `results` field and one older-shape record |
| `.claude/skills/sitrep/SKILL.md` | description line; usage (`/sitrep inbox`); "What it is"; step 2 reads the new record shape; new step 3; steps renumbered; record step writes `results`; report template and rules (top block, path groups, one-line inbox, Suggested next source 4 on ask) |
| `docs/roadmap.md` | acceptance-case paragraph, Item cells of steps 5 and 6, Format-list bullet (drafts above) |
| `docs/design.md` | Documentation layers Direction row paragraph, Measures row (run record keeps per-line results), the gaps-paragraph "net change only" sentence, Change log row; OQ-3 wording checked, unchanged |

No `AGENTS.md` script-table entry mentions the sit-rep scripts; none to add.

## Prior Art

- `sitrep_checks.sh` already has the table picker, fence tracking, `split_row`
  and the `--summary-from` validator; the new rows and modes reuse them
  rather than adding a second reader. The step table is picked by header just
  as the Direction tables are.
- The run record and `inbox_new` already show the pattern for anchoring on
  the last record; the per-line field follows it, keyed by item text plus occurrence so a
  reordered roadmap still compares (a reworded line does not, and is
  reported as added plus gone).
- Rejected: reading the in-progress rows and the proof paragraph by having the
  model scan the roadmap (breaks "every statement from a command run this
  invocation"); keying results by position (a reorder reads as everything
  moving); a separate orientation file or authored text in the skill (the
  issue's decision: composed, not authored); an issue-number link between
  deferrals and lines (deferrals carry only a revisit check, so "after" is
  listed, not linked).

## Serves

Easy to use ("Work is easy to come back to"), principle "Give the user what
they need now", The long view ("Know whether it works"); design section
`docs/design.md#documentation-layers`.

## Design Picture

Yes: `docs/design.md#documentation-layers`, the Direction row (composition
rule and the wrong-sounding-means-stale loop) and the Measures row (the run
record keeps each line's result), plus a Change log row, in this PR (ADR-0017).
Nothing else in the design changes.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Direction and Measures rows and the Change log updated in the same change. |
| Give the user what they need now | The top block is the orientation and the path in at most eight lines; the inbox is one line unless asked. |
| Verify before claiming | Each slot is a command's output: git remote, `step` rows, `proof` row, `--path-from`; none read by the model from the roadmap. A slot without a source is dropped. |
| A change includes its consequences | Record writer, reader and `--summary-from` validation change together; old records still read; tests, description line, design doc, roadmap header and the skill's rules move with them. |
| Enforce what matters, as simply as possible | One yes/no check at the right place (1 or 2 steps in progress), one extra record field, no new file. |
| Test what breaks | Cutover-table decoy, 0/3 in progress, old-shape record, empty and malformed `--last`, reword and duplicate text, unknown-is-not-false, `--summary-from` with the new kinds. |
| Only what's needed | The `gone` and `changed` outputs and the `after` group each exist because the sit-rep would otherwise say nothing about a removed line, an unknown-to-false move, or deferrals; nothing links deferrals to lines. |
| Put each thing at the level it applies to | The skill names no project; `gz4d` appears only in the roadmap paragraph printed as written. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0017 Design document is the current picture | Yes | Design doc updated in this change (item 8). |
| 0016 Session roots and the user tier | Watch | Repo slot reads `git -C "$WS_ROOT"` (the workspace, not the cwd); `$WS_ROOT` idiom with the `|| echo .` fallback kept on every new block. |
| 0013 progress.md vocabulary | No | The run record is a machine-local file, not a progress entry. |
| 0010 git-bug first | No | No issue reads added; the slug uses `extract_gh_slug` as step 4 does today. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Rows grammar (`step`, `proof`) | `ROW_RE`, header comment, `--summary-from` tests, skill step 1's kind list | Yes |
| Run record shape | Skill steps 2 and 5, test fixtures, design Measures row | Yes |
| Skill step numbers | `skill_step`/`run_step` calls in the tests; any "step N" cross-reference inside the skill | Yes |
| Existing test assertions on row counts and kinds | Lines 133, 356, 374-375 change; line 177 holds | Yes |
| Run record per-line results | Design gaps paragraph ("net change only"), OQ-3 wording (checked) | Yes |
| Roadmap Item cells and acceptance paragraph | Format bullet; nothing else reads those cells (`update_roadmap.sh` keys on issue number and the Status column; grepped) | Yes |
| Skill description / usage | `test_skill_paths.sh` trigger-phrase check | Yes |

## Resolutions carried (from the checkpoint)

1. Per-line result field in the record: item 3. 2. Grouped path, one line per
group, defines the eight-line block: item 5. 3. Item cells plain-worded, Notes
untouched: roadmap drafts. 4. Item cells are activity phrases reading after
"We are", stated in the roadmap Format bullet: roadmap drafts. 5. Two steps
listed in table order, "We are X. Also in progress: Y", statuses unchanged:
item 5. 6. Skill names no project: item 4 and Principles row. Watch items:
command-sourced slots (items 1, 4); Cutover decoy and header pick (item 1,
tests); `--summary-from` accepts the new kinds (item 2, tests); `$WS_ROOT`
workspace remote (item 4); roadmap Format paragraph updated (item 7).

## Open Questions

None. Closed at the checkpoint: the inbox "now" bin feeds Suggested next only
on an explicit `/sitrep inbox` (item 6); the path shows names and result words
without check text (item 5); "The proof is" stands, with the acceptance
paragraph starting with a capital after its label (item 1 lowercases it).

## Estimated Scope

Single PR: the runner, record, skill, tests, roadmap and design doc change
together because the record writer, reader and validator must move in one
change.
