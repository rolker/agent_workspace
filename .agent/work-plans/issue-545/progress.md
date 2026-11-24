---
issue: 545
---

# Issue #545 — A simple local viewer for reviewing a draft and sending annotations back to the agent

## Issue Review
**Status**: complete
**When**: 2026-11-23 12:00 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #545

### Scope Assessment

**Well-scoped?** Yes, once the owner's decisions below are taken as the spec. One script plus its test and doc lines fits a single PR. The "ideas not tried" (edit or delete, whole-draft note, side list, changes-only round) are now decided and add size, so the plan should stage them: core viewer and notes file first, side list and changes-only second, in the same PR only if it stays reviewable.
**Right repo?** Yes. The viewer is workspace tooling a session launches; it holds nothing project-specific (ADR-0003).
**Serves**: Trust, control and information (the user reviews drafts and records approval) and "A safeguard has to earn its cost" (a stock-Python window, no install, in place of chat comments that must describe where they apply) -- `docs/design.md#review-loop-and-timeline`
**Design picture?** Changes `docs/design.md#review-loop-and-timeline`: a local draft-review step with a notes file and a recorded decision is a new way the owner answers at a checkpoint. The owner's UX decisions below are recorded; the open placement question (notes file versus the work's record) touches the Records part of `docs/design.md#worktrees` and is a mechanism choice for the host, so the plan updates the design section in the same change (ADR-0017). No `Action needed` re-ask.
**Dependencies**: Related to #544 (GitHub-optional backends, open): the notes file and decision are the local review venue it needs. #545 does not block on #544; keep the notes format tool-neutral so #544 can consume it.

**Owner decisions (2026-11-23, answered in the session; plan-task starts from these)**
- Q1 Look of the draft: "Light formatting (Recommended)": plain text with styling (headings, bold/italic, code in monospace on a grey background, table pipes lined up in columns); line numbers still match the file.
- Q2 Note features: "Edit or delete a note, Note on the whole draft, Side list of notes" (all three; click a note in the side list to jump to its passage).
- Q3 Second-round review: "Seems like 1 could get complicated so 2 is my lean." Option 2 is "Changes only": highlight what changed since the last round, without carrying the old notes over. (Option 1, rejected as complicated: earlier notes in a side list with the agent's replies, tickable.)
- Q4 Close without a decision: "Ask on close (Recommended)": closing with no decision asks Approve / Changes requested / Just close (notes only).

**Answers to the issue's open questions**
- Q2 (finish signal): window close = process exit of a background command (worked in the trial). Settled.
- Q3 (render Markdown): settled by owner Q1: light formatting, not full rendering.
- Q1 and Q4 (notes file, no display): see Recommendations.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Watch | A new review step touches `docs/design.md#review-loop-and-timeline` (and Records in `#worktrees` if notes join the work's record); update in the same PR (ADR-0017). |
| Only what's needed | Watch | Owner chose a bigger feature set than the 80-line trial. Each feature is his decision, so keep to it; do not add more (no previous-round note carry-over, no Markdown rendering beyond the light styling). |
| Test what breaks | Watch | Tkinter is hard to test. Keep notes-file writing, line-range mapping, diff-against-previous and the no-display exit in pure functions with tests; the GUI layer stays thin. |
| Use the main tool fully; keep the work tool-neutral | OK | Notes file is plain Markdown any agent reads; no Claude-only launch assumption beyond "run as a background command". |
| Look for prior art before building | OK | Trial script exists and is the starting point. |
| Leave a trail; start limits strict | OK | Notes file and decision are a durable review record. |
| Put each thing at the level it applies to | OK | Workspace tooling, project-agnostic. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0003 Workspace infrastructure is project-agnostic | Yes | Script must not assume a project, a repo layout or GitHub. |
| 0009 Python package management policy | Yes | Standard library only (tkinter, difflib); no pip install. |
| 0013 progress.md entry-type vocabulary | Maybe | Do not add an entry type. If the decision should reach the timeline, the host records it in an existing `## Checkpoint` entry; a new type needs a superseding ADR. |
| 0017 Design document is the current picture | Yes | Update the design section in the same change. |
| 0010 git-bug optional / #544 | Related | Keep the format free of GitHub assumptions. |

### Consequences

- `.agent/knowledge/script_reference.md`: add the script.
- `docs/design.md#review-loop-and-timeline`: describe the local review step.
- A test under `.agent/scripts/tests/`, and the Makefile or `validate` wiring if scripts are listed there.
- Any skill that drafts for approval (issue, plan, review, PR body) gets a line saying it may launch the viewer; scope that to a follow-up unless the plan keeps it small.

### Recommendations

- Start plan-task from the four owner decisions above (Q1 light formatting, Q2 edit/delete + whole-draft note + side list with click-to-jump, Q3 changes-only second round, Q4 ask on close). Do not reopen them.
- Script location: `.agent/scripts/review_viewer.py` (a Python script among the workspace scripts, launched by a session as a background command; process exit on window close is the done signal). Tests in `.agent/scripts/tests/`. Standard library only.
- Notes file: keep the trial's format (`<draft>.notes.md`, a `**Decision**:` line, `## Note n (lines a-b)` with the passage as a blockquote, then the note), add a `## Note on the whole draft` section for the no-selection note, and write `**Decision**: none (notes only)` for "Just close". Default location is beside the draft (works for drafts in scratchpads or ignored folders, as in the trial), with a `--notes <path>` option. When the review belongs to an issue, the launching skill passes `--notes .agent/work-plans/issue-<N>/reviews/<draft-name>.notes.md` so the record sits with `progress.md`; the host (not the viewer) summarises the decision in the existing checkpoint entry. Rewrite the file after every change, as in the trial.
- Changes since the last round need the previous round's copy of the draft. Recommend the viewer snapshots the draft it showed to `<notes-path minus .notes.md>.reviewed` (beside the notes file) when the window closes, and on the next launch diffs the draft against that snapshot (difflib) to highlight changed lines, with no notes carried over (owner Q3). That needs no git or GitHub, works for untracked drafts, and the first launch simply has no snapshot and shows no highlights. An explicit `--previous <file>` overrides it.
- No display: the viewer checks the display (no `DISPLAY` or `WAYLAND_DISPLAY`, or `import tkinter` or `Tk()` failing) and exits with code 2 and a one-line message, never a traceback. The agent then falls back to the same review in chat: it shows the draft with line numbers (`cat -n`), takes the owner's comments by line range, and writes the same notes-file format itself. A terminal viewer is out of scope.
- Exit codes so the agent can tell outcomes apart: 0 window closed normally (read the notes file for the decision), 2 no display or no tkinter. The decision lives only in the notes file.
- Test the pure parts (notes writer, line-range from selection, diff highlighting, display check) without opening a window; one smoke run under `xvfb` is optional if available.

### Actions
- [ ] Start plan-task from the four owner decisions above (Q1 light formatting, Q2 edit/delete + whole-draft note + side list with click-to-jump, Q3 changes-only second round, Q4 ask on close). Do not reopen them.
- [ ] Script location: `.agent/scripts/review_viewer.py`, tests in `.agent/scripts/tests/`, standard library only.
- [ ] Notes file: trial format plus whole-draft note and `none (notes only)` decision; default beside the draft, `--notes <path>` to place it under `.agent/work-plans/issue-<N>/reviews/` when tied to an issue.
- [ ] Changes since the last round: viewer snapshots the shown draft to `<notes stem>.reviewed` on close and diffs against it next launch; `--previous <file>` overrides; no old notes carried over.
- [ ] No display: exit code 2 with a one-line message; agent falls back to chat review with line numbers and writes the same notes format.
- [ ] Test the pure parts without a window (notes writer, line ranges, diff highlights, display check).

## Checkpoint
**Status**: complete
**When**: 2026-11-23 21:28 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (the owner's four UX answers are recorded in the Issue Review; the open points are mechanism, none changes what the work is for)
**After**: issue-actions
**Decision**: proceed

Plan from the owner's Q1-Q4 answers as recorded, without reopening them. The issue review's mechanism recommendations are adopted (owner may veto):
- Script: `.agent/scripts/review_viewer.py`, standard library only; launched as a background command; window close (process exit) is the done signal.
- Notes file: the trial's format plus a whole-draft note section and `**Decision**: none (notes only)` for "Just close"; rewritten after every change. Default beside the draft; `--notes <path>` lets the launcher put it under `.agent/work-plans/issue-<N>/reviews/` when the review belongs to an issue. The host records the decision in an existing `## Checkpoint` entry; no new entry type.
- Changes since the last round: on close the viewer saves the text it showed as `<notes stem>.reviewed`; the next launch diffs against it (difflib) and highlights changed lines; `--previous <file>` overrides; first launch shows none.
- No display: check `DISPLAY`/`WAYLAND_DISPLAY` and catch a failed tkinter import or `Tk()`; exit 2 with one line, no traceback; the agent then runs the review in chat and writes the same notes format. No terminal viewer.
- Tests on the pure parts (notes writer, line ranges, diff highlighting, light-formatting spans, display check); the GUI layer stays thin. `script_reference.md` row and the design section in the same PR (ADR-0017). Skills offering the viewer: a follow-up, not this PR.

## Plan Authored
**Status**: complete
**When**: 2026-11-23 21:29 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-545/plan.md` at `354d2251`

Single-PR plan: a stdlib review_viewer.py whose logic (notes format, line ranges, light-format spans, changed lines, display check) is pure and unit-tested, with a thin tkinter layer; design section and script_reference row in the same PR.

## Plan Review
**Status**: complete
**When**: 2026-11-23 21:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #545 — A simple local viewer for reviewing a draft and sending annotations back to the agent
**Plan**: `.agent/work-plans/issue-545/plan.md` at `354d2251`
**Branch**: `feature/issue-545`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One script, one test module plus wrapper, two doc edits; a fallback split (side list and changes-only to a second PR) is named. |
| Issue alignment | Needs work | All four owner answers and every Checkpoint mechanism decision are carried. Serves: "Trust, control and information (the owner reviews drafts and records approval) and "A safeguard has to earn its cost" in `README.md#workspace-goals`; `docs/design.md#review-loop-and-timeline`" (goal section exists; the safeguard line is a bullet under Quality of the work; anchor exists). Gaps: the `Tk()` failure path (finding 2) and what text the snapshot holds (finding 1). |
| File targeting | Good | `test_progress_read.py` is a `ROOT_READERS` key (`[test_progress_read.py]=".agent/scripts"`), so `test_review_viewer.py` will almost certainly need the same entry; the plan already lists the file conditionally and verifies by running the suite. |
| Consequences | Good | Script row, design section, hook-scope map, exec bit, skill wiring deferred to a follow-up as the Checkpoint decided. |
| Principle alignment | Good | Pure core and thin GUI (Test what breaks); design section in the same PR; prior art (trial, `progress_read.py` pattern) named with rejections. `parse_notes` is borderline Only what's needed (suggestion 3). |
| ADR compliance | Good | 0003 (notes path is an argument), 0009 (stdlib), 0013 (no new entry type), 0017 (step 5). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment]** — The snapshot is defined as "the shown text", and the passage quote is unspecified, but the display text differs from the file: table rows are padded to align pipes (step 1, `light_format_spans`). If the `.reviewed` snapshot holds display text and round two diffs the raw draft against it, every table line shows as changed (owner Q3 "highlight what changed" becomes wrong); if both sides are display text, a change to one cell re-pads and marks the whole table. Likewise the trial quoted `st.get(a, b)`; with padding the blockquote no longer matches the file text the agent edits. Resolution: state that the snapshot is the raw draft text as read at launch, `changed_lines` runs on raw texts, and the passage quote is taken from the raw file (lines a-b, or the selected span mapped back to file columns), and add a test with a table row so a display-text snapshot fails it.
2. **[Issue alignment]** — The Checkpoint (and issue review) require exit 2 when `Tk()` fails, not only when the env vars are missing or the import fails. `check_display` covers env and import only; step 3's "Unhandled GUI exceptions after `Tk()` succeeds" implies the `Tk()` failure is handled but no step says so, and the tests list only the empty-environment case. This path is real: a Wayland-only session (`WAYLAND_DISPLAY` set, no `DISPLAY`/XWayland) or a dead forwarded X display passes the env check and then raises `TclError` with a traceback. Resolution: catch `tkinter.TclError` from `Tk()` and exit 2 with the one-line message; test it with a bogus `DISPLAY` (e.g. `DISPLAY=:9999`) in the subprocess test.

**Suggestions (do not by themselves need another plan round)**

3. **[Principle alignment]** — `.prev` rename: sound, keep it. It keeps the host's "read the notes after exit" reading only this round (owner Q3), loses nothing on a relaunch before the host read the old file, and covers a chat-fallback notes file too. Make it happen at the first write (as the plan says), not at start, so a window killed before any change leaves the old file in place; use `os.replace` so an existing `.prev` is overwritten (one level of history is enough, since the host acts between rounds). Given the rename, `parse_notes` and "the file is read at start" serve nothing at run time; keep a parser only if it is used for the writer round-trip test, and say so, or drop it.
4. **[Issue alignment]** — `snapshot_path` assumes the notes path ends in `.notes.md`; say what happens otherwise (e.g. append `.reviewed` to the full notes path) and test it. Also say what a `--previous` path that does not exist does (exit 1 with one line, like a missing draft, seems right).
5. **[Consequences]** — When a launcher later puts notes under `.agent/work-plans/issue-<N>/reviews/` (tracked, not ignored), the `.reviewed` and `.prev` files land there too. Not this PR's change, but the follow-up issue for skill wiring should note it.

### Summary

The plan carries the owner's four answers and the host's mechanism decisions faithfully and is well structured. Two small gaps would make the implementation wrong in reachable cases: the snapshot and passage must be raw file text (display padding breaks the changes-only highlight), and a `Tk()` failure must exit 2 rather than traceback. Both are one-line plan edits plus a test each.

### Recommended Actions

- [ ] Specify that the `.reviewed` snapshot, the `changed_lines` inputs and the noted passage use the raw draft text, not the padded display text; add a table-row test.
- [ ] Add `Tk()` `TclError` handling to the exit-2 path and a subprocess test with an unreachable `DISPLAY`.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 21:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (plan review needs-work on two one-line gaps with stated fixes; carried into the implement handoff, as the owner chose for issue 452's plan on 2026-11-23, to save a plan round)
**After**: plan
**Decision**: proceed

Implement plan.md at 354d2251 with the Plan Review's findings and suggestions applied in the code, and noted in the Implementation entry:
- F1: the `.reviewed` snapshot, the `changed_lines` inputs and every quoted passage use the raw draft text, never the padded display text; selection maps to raw lines; a test with a table row whose cell changes marks only that line.
- F2: `Tk()` raising `TclError` (dead or missing X display, Wayland-only) exits 2 with the one-line message, no traceback; a subprocess test with `DISPLAY=:9999`.
- Suggestions adopted: the `.prev` rename happens at the first write, with `os.replace`, one level of history; keep `parse_notes` only if the writer's round-trip test uses it; state what `snapshot_path` does for a notes path not ending in `.notes.md`; a missing `--previous` file exits 1 with one line; the skill-wiring follow-up note says `.reviewed` and `.prev` files land in the tracked `reviews/` folder.

## Implementation
**Status**: complete
**When**: 2026-11-23 21:44 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-545 at `27098645`

- `73a479f4` `.agent/scripts/review_viewer.py` (new, executable, stdlib only): pure core (`check_display`, `split_lines`, `light_format` with display-to-file column maps, `selection_to_range`, `passage_text`, `Note`/`Review`, `render_notes`/`parse_notes`, `NotesWriter`, `snapshot_path`, `changed_lines`, `Session`) and a thin tkinter `ViewerApp` (text pane, side list with click-to-jump and flash, Add note Ctrl+N, Note on whole draft, Edit, Delete, Approve, Changes requested, ask on close: Approve / Changes requested / Just close). Markdown markers stay visible and styled; only table rows are padded, so every display line is its file line.
- `73a479f4` tests: `.agent/scripts/tests/test_review_viewer.py` (55 tests) and wrapper `test_review_viewer.sh` (`# covers:` line, +x); `test_script_tests_hook_scope.sh` gains `[test_review_viewer.py]=".agent/scripts"` in `ROOT_READERS`.
- `27098645` `docs/design.md#review-loop-and-timeline`: local draft review bullet plus change-log row (ADR-0017); `.agent/knowledge/script_reference.md` row.

Plan Review findings and suggestions applied:
- F1: the `.reviewed` snapshot is `Session.raw_text` (the file as read at launch); `changed_lines` takes raw texts; every passage comes from `passage_text`, which maps display columns back to file columns. Tests: `test_table_cell_change_marks_only_that_row` (a wider cell re-pads every row's display, only its row is marked), `test_two_rounds_snapshot_is_raw_text`, `PassageTest`.
- F2: `Tk()` raising `TclError` exits 2 with one stderr line, no traceback; `test_unreachable_display_exits_2` runs the CLI with `DISPLAY=:9999`.
- `.prev`: `NotesWriter` renames an existing notes file with `os.replace` at the first write only (one level); tested, including "nothing moves at launch".
- `parse_notes` kept: the writer round-trip tests use it (each decision, whole-draft note, multi-line and blank-line passages).
- `snapshot_path`: `x.notes.md` -> `x.reviewed`; any other name (and a bare `.notes.md`) gets `.reviewed` appended; tested.
- A missing `--previous` file exits 1 with one line; tested (also a missing draft).
- Follow-up note for the skill-wiring issue (not opened by this pass): a launcher passing `--notes .agent/work-plans/issue-<N>/reviews/<name>.notes.md` puts the `.reviewed` snapshot and the `.prev` notes beside it, in that tracked folder, so the launcher must commit or ignore them deliberately.

Choices made here: no `**Decision**` line while undecided (a killed window leaves none); dismissing the ask-on-close dialog keeps the window open; the notes folder is created at the first write; a failed write shows an error and "NOT SAVED" in the status bar; a failed save on close prints one stderr line and still exits 0.

Suites run (each on its own):
- `bash .agent/scripts/tests/test_review_viewer.sh`: `Ran 55 tests` / `OK (skipped=1)`; the skip is the window-build smoke, which runs only under `xvfb-run` (not installed here).
- `bash .agent/scripts/tests/test_script_tests_hook_scope.sh`: `test_script_tests_hook_scope: 357 passed, 0 failed`.
- `bash .agent/scripts/tests/test_skill_paths.sh`: `test_skill_paths: 200 passed, 0 failed`.
- `bash .agent/scripts/tests/test_design_anchors.sh`: `test_design_anchors: 82 passed, 0 failed`.
- `pre-commit run --files` on the three new files with `SKIP=validate-script-tests`: black, flake8, pylint, shellcheck pass. Full pass left to the host.

Not verified: the tkinter layer (`ViewerApp`) has not run. No xvfb here, the GUI was not launched (per handoff), and a withdrawn-window build check was denied. Its first real use, or an xvfb run of the smoke test, is its first exercise.

Process note: an early `pre-commit run --files` without `SKIP` started the validate-script-tests hook, which selected every suite (a new `.agent/scripts` file reaches every suite that copies the whole folder). It was stopped partway; two orphaned fake-codex processes from its `test_cross_model_review.sh` run may still be alive until their own 1800 s timeout (killing them was denied).

### Decision summary

- New `.agent/scripts/review_viewer.py`: a stdlib tkinter window for reviewing a draft. It implements the owner's four answers: light formatting, edit/delete plus whole-draft note plus side list, changes-only second round, ask on close. Window close is the done signal; exit 2 with one line means review in chat in the same notes format.
- Notes and the `.reviewed` snapshot always hold the file's own text, never the padded table display (Plan Review F1). A dead or refused display exits 2 with no traceback (F2).
- A relaunch moves the old notes file to `.prev` at the first write. No notes carry over to the next round.
- The design section and the script reference are updated in this PR. Skills that offer the viewer are a follow-up; their `reviews/` folder will hold `.reviewed` and `.prev` files.
- The GUI layer has not run here. The pure core has 55 tests.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 21:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-545 at `83984c7b`
**Base**: main
**Depth**: Standard (reason: new 904-line script plus tests and design-doc change; not security or cross-layer)
**Must-fix**: 5 | **Suggestions**: 7
**Round**: 1 | **Ship**: continue — round 1: 5 must-fix; first round always re-reviews after fixes

Cross-model: gemini complete, codex complete. Claude adversarial complete. Static analysis (pre-commit black/flake8/pylint/shellcheck on changed files) clean; `test_review_viewer.sh` 55 tests OK (1 skipped, xvfb). GUI not launched (per handoff). Implementer's four choices judged consistent with the owner's Q1/Q4 answers: markers visible with only tables padded (Q1 "plain text with styling", line numbers match); no Decision line until one is made; dismissing the ask-on-close dialog keeps the window open (but see the re-entry suggestion); notes folder made at first write.

### Findings
- [x] (must-fix) Ctrl+N never works after a mouse selection: the text widget has focus (TextButton1 focuses even when disabled) and Tk's Text class `<<NextLine>>` (Control-n) runs `TextSetCursor`, which removes `sel` before the root binding runs, so add_note reports "Select a passage first". Bind `<Control-n>`/`<Control-N>` on `self.text` returning "break" (keep the root binding) — `.agent/scripts/review_viewer.py:633` (Claude adversarial, gemini, lead; verified in /usr/share/tcltk/tk8.6/text.tcl:110,579,775 and tk.tcl:320)
- [x] (must-fix) Selection is invisible over code, changed, noted and flash text: tags configured after widget creation sit above `sel`, and the raises push them further; add `st.tag_raise("sel")` last — `.agent/scripts/review_viewer.py:647-660` (lead, Claude adversarial)
- [x] (must-fix) A failed save on close prints to stderr (unread for a background command), destroys the window and exits 0, so the host reads a notes file without the decision as "closed normally"; keep the window open with an error dialog or exit non-zero. Plan step 3 also said unhandled GUI exceptions after `Tk()` exit non-zero: Tk callback errors currently go to report_callback_exception and the run still exits 0 — `.agent/scripts/review_viewer.py:836-840,898-900` (all three reviewers)
- [x] (must-fix) Argparse usage errors (unknown option, missing draft) exit 2, the code the contract reserves for "no window, review in chat"; verified: `review_viewer.py --bogus x` exits 2. Override `ArgumentParser.error` to exit 1 and test it — `.agent/scripts/review_viewer.py:874` (gemini, verified)
- [x] (must-fix) `--notes` is not validated: naming the draft renames the draft to `.prev` and overwrites it with notes; an existing directory is renamed to `<dir>.prev`; a snapshot path that resolves to the draft (`x.reviewed` draft, `x.notes.md` notes) overwrites the draft on close; `--notes /` raises ValueError in snapshot_path. Refuse with exit 1 when notes, `.prev` or snapshot collide with the draft or `--previous`, or notes is a directory; add tests — `.agent/scripts/review_viewer.py:476-497,538-543,876` (codex, gemini, Claude adversarial)
- [x] (suggestion) Changed-line highlight runs `L.0` to `L.0 lineend`, zero width on a blank line, so an added blank line or a deletion marker landing on one shows nothing; extend to `lineend +1c` — `.agent/scripts/review_viewer.py:658`
- [x] (suggestion) `passage_text` rstrips every trailing newline, so lines 3-5 with blank line 5 quote only two lines under "lines 3-5"; drop only the one empty segment when the selection ends at column 0 — `.agent/scripts/review_viewer.py:353`
- [x] (suggestion) Closing the main window while a note or decision dialog is open re-enters on_close (grab does not block WM_DELETE_WINDOW), losing a half-typed note or stacking a second decision dialog; ignore on_close while a dialog is open — `.agent/scripts/review_viewer.py:723-725,832`
- [x] (suggestion) Flash removal timer is not cancelled, so a second jump within 900 ms loses its flash early; keep and `after_cancel` the id — `.agent/scripts/review_viewer.py:799`
- [x] (suggestion) A data cell of `-` (common N/A) is treated as a separator cell and displayed as a full dash run (verified: `| x | - |` shows `| x   | --- |`); treat a row as separator only when every cell matches — `.agent/scripts/review_viewer.py:202-219`
- [x] (suggestion) `check_display` exits 2 whenever DISPLAY and WAYLAND_DISPLAY are unset, which refuses macOS and native Windows where Tk needs neither; apply the env check on Linux only and rely on `Tk()` TclError elsewhere (or state Linux-only) — `.agent/scripts/review_viewer.py:92`
- [x] (suggestion) Fence detection is prefix-only: a paragraph line starting with triple-backtick inline code opens a fence to the end of the draft, and an info-string line inside a fence closes it — `.agent/scripts/review_viewer.py:156,255-260`

## Implementation
**Status**: complete
**When**: 2026-11-23 21:59 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-545 at `86f8cfb1`
**Addressed**: Local Review (Pre-Push) at `83984c7b` (2026-11-23 21:50 -05:00)
**Commits**: a3d0ee12, 431e4239, 73989800, 890861bb, f4b6d866, b38e4bae, 1730c9a0, 653d7f19, 402b5807, 0525e28d, ef6332a5, 86f8cfb1

### Actions
- [x] (must-fix) Ctrl+N after a mouse selection: `<Control-n>`/`<Control-N>` bound on the text widget returning "break" (root binding kept) — `.agent/scripts/review_viewer.py` ViewerApp.__init__ (a3d0ee12)
- [x] (must-fix) Selection invisible over tags: `sel` raised last after changed/noted/flash — `_build_text` (431e4239)
- [x] (must-fix) Failed save on close: window stays open, error in the status line ("NOT SAVED on close: ... Close again to retry") plus a "Close anyway?" dialog (default no); closing anyway exits 1. Tk callback exceptions go to `report_callback_exception` → traceback on stderr, status line, exit 1 at close; an exception during close also destroys the window so the owner is not trapped. Docstring and script_reference.md exit codes updated; 6 tests on an app built without a display (CloseAndErrorTest) (73989800)
- [x] (must-fix) Argparse usage errors exit 1 (ArgumentParser subclass overriding `error`), 2 kept for "no window"; CLI tests for `--bogus` and no argument (890861bb)
- [x] (must-fix) `--notes` validated by `check_paths` before anything is read or written: refuses (exit 1) a notes path that is a folder (incl. `/`), a notes/.prev/snapshot path that is a folder or the draft, a notes/.prev path that is the `--previous` file; compares resolved paths and `samefile`. One conscious narrowing: the snapshot may equal `--previous` (it is read at launch, and replacing it on close is every round's normal step), so `--previous <x>.reviewed` is not refused. CheckPathsTest (9 tests) and a CLI test that the draft is untouched (f4b6d866). Module passed pylint's 1000-line limit: `too-many-lines` disabled at module level with the reason (single file launched by path)
- [x] (suggestion) Changed-line mark extended to `lineend +1c` so a blank line shows it (b38e4bae; display only, no test without a window)
- [x] (suggestion) `passage_text` drops only the one empty segment of a selection ending at column 0; blank lines inside the range stay quoted; 2 tests, round trip checked (1730c9a0)
- [x] (suggestion) on_close ignored while any dialog (note, decision, delete confirm, error, close-anyway) is open, via a `_modal()` depth counter; test (653d7f19)
- [x] (suggestion) Flash timer id kept and `after_cancel`ed on the next jump (402b5807; display only, no test without a window)
- [x] (suggestion) A row is a separator only when every cell matches; `| x | - |` shows as typed; test (0525e28d)
- [x] (suggestion) DISPLAY/WAYLAND_DISPLAY test skipped on `darwin` and `win32` (`check_display` takes `platform`, default `sys.platform`); `Tk()` TclError still gives exit 2 there; test (ef6332a5)
- [x] (suggestion) Fence detection moved to `fenced_lines` (both passes): backtick info string may not hold a backtick, a closing fence has only spaces after it, indent up to three spaces; 4 tests (86f8cfb1)

### Checks
- `bash .agent/scripts/tests/test_review_viewer.sh`: `Ran 81 tests ... OK (skipped=1)` (the skip is the xvfb window smoke test: xvfb-run is not installed here, so the window itself was not built; the GUI was not launched)
- `bash .agent/scripts/tests/test_script_tests_hook_scope.sh`: `test_script_tests_hook_scope: 357 passed, 0 failed`
- `bash .agent/scripts/tests/test_skill_paths.sh` (script_reference.md changed): `test_skill_paths: 200 passed, 0 failed`
- Commits ran every hook except validate-script-tests (SKIP per #465). The full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 22:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ada1d3b19e629ea27, resume 1 of 3)

**Branch**: feature/issue-545 at `b86cca30`
**Base**: main
**Depth**: Standard (reason: whole-branch diff, new ~1080-line script plus tests and design-doc change; fix-round classified on the whole diff)
**Must-fix**: 2 | **Suggestions**: 5
**Round**: 2 | **Ship**: recommended — round 2: 2 mechanical must-fix (prev 5), not rising; fix and ship rather than another full round

Cross-model: gemini complete, codex complete. Claude adversarial complete (no must-fix). Static analysis (pre-commit black/flake8/pylint/shellcheck on changed files) clean; `test_review_viewer.sh` 81 tests OK (1 skipped, xvfb). `--help` exits 0, `--bogus x` exits 1. GUI not launched. All 12 round-1 findings verified fixed; the three display-only fixes read closely and judged correct: Ctrl+N is bound on the text widget and returns "break", so it runs before the Text class binding and the root binding does not double-fire; `sel` is raised last; the flash timer id is cleared in `_end_flash` before a later `after_cancel`. Host decisions held: a failed save on close keeps the window open, a callback error exits 1, usage errors exit 1, and the snapshot may be the `--previous` file. Dropped: the decision kept after a failed close-save (that is the intended retry), the `# covers:` selection concern (suites_for_files.sh selects test_review_viewer.sh, verified in round 1), and parse_notes heading collision (documented limit, test-only reader).

### Findings
- [x] (must-fix) The `--help` epilog says to "write the notes file in the format above", but `--help` shows no format: the format is only in the module docstring. Exit 2's stderr points to `--help`, and plan step 5 put the fallback there. Put the notes format template in the epilog or description; add a test that `--help` shows `**Decision**` and `## Note` — `.agent/scripts/review_viewer.py:87-92,1023-1039` (gemini, verified)
- [x] (must-fix) `_ask_text` and `_ask_decision` call `wait_visibility()` and `grab_set()` before entering `_modal()`. `wait_visibility` runs the event loop with depth 0, and blocks while the root is iconified, because a transient dialog does not map. A second close (e.g. from the taskbar of a minimised window) therefore nests a second decision dialog; the inner pick finishes and destroys the root, then the outer one calls finish/destroy on a dead app and the clean close exits 1. `grab_set` can also raise TclError ("another application has grab", or the dialog already closed), leaving an orphan dialog whose Save goes nowhere. Enter `_modal()` before building the Toplevel and catch TclError from `grab_set` (carry on without the grab) — `.agent/scripts/review_viewer.py:855-858,969-972` (Claude adversarial, gemini)
- [x] (suggestion) A data row whose cells are all `-` (a row of N/A) is still drawn as a separator (verified: `| - | - |` shows `| --- | --- |`), contradicting the comment; treat only the second row of a table block as the delimiter row — `.agent/scripts/review_viewer.py:222-224` (lead, Claude adversarial)
- [x] (suggestion) A pipe after an escaped backslash (`\\|`) is treated as escaped; count the preceding backslashes and treat the pipe as escaped only when the count is odd (display only) — `.agent/scripts/review_viewer.py:197-198` (codex, gemini)
- [x] (suggestion) `Path.resolve()` (symlink loop, RuntimeError on Python 3.12 and earlier) and `is_dir()` (PermissionError) in `main` and `check_paths` give a traceback instead of a one-line exit 1 — `.agent/scripts/review_viewer.py:570,1050-1052` (Claude adversarial, gemini)
- [x] (suggestion) The CLI tests for exit 2 (empty env, `DISPLAY=:9999`) would open a real window on macOS or Windows now that `check_display` skips the env test there; skip them when `sys.platform in NATIVE_TK_PLATFORMS` — `.agent/scripts/tests/test_review_viewer.py:511-522` (gemini)
- [x] (suggestion) `NotesWriter.write` moves the old notes to `.prev` before the new write succeeds; a failed first write leaves no file at the notes path (nothing lost, the old file is in `.prev`). Write the temp file first, then rotate and replace — `.agent/scripts/review_viewer.py:525-530` (gemini)

## Implementation
**Status**: complete
**When**: 2026-11-23 22:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent aa2aa4994d25273cb, resume 1 of 3)

**Branch**: feature/issue-545 at `d525d219`
**Addressed**: Local Review (Pre-Push) at `b86cca30` (2026-11-23 22:07 -05:00)
**Commits**: 44045b7e, f2b27bbd, 246ab84b, 9a88a9cf, a7fb015e, 4cedfb1f, d525d219

### Actions
- [x] (must-fix) `--help` had no notes format: a `NOTES_FORMAT` template now sits in the epilog ahead of the chat fallback ("the format above"); test checks `# Review notes:`, `**Decision**: approve`, both `## Note` headings and the quote line, and that the template comes before "format above" — `.agent/scripts/review_viewer.py` (44045b7e)
- [x] (must-fix) `_ask_text` and `_ask_decision` now build and show their dialog inside `_modal()`; new `_run_dialog` deiconifies a minimised main window first (a transient dialog does not map while its master is iconified), carries on without the grab when `wait_visibility`/`grab_set` raise TclError, and waits only if the dialog still exists. Tests with a fake tk: a close delivered during `wait_visibility` opens no second decision dialog and the root survives; a failed grab still waits on the dialog (f2b27bbd)
- [x] (suggestion) Only a table block's second row can be the delimiter row; `| - | - |` data row shown as typed; test (246ab84b)
- [x] (suggestion) A pipe is escaped only after an odd run of backslashes (`_escaped`); test for `a\\|` splitting (9a88a9cf)
- [x] (suggestion) Symlink loop (RuntimeError on 3.12) and PermissionError from `resolve`/`is_dir`/`is_file` now give a one-line exit 1 (`_resolve` in main, a wrapper in `check_paths`, `read_text`, plus a final OSError/RuntimeError net in main); CLI tests for a self-symlink draft and an unsearchable `--notes` folder (a7fb015e)
- [x] (suggestion) The two exit-2 CLI tests skip when `sys.platform` is in `NATIVE_TK_PLATFORMS`; the symlink test skips off POSIX (4cedfb1f)
- [x] (suggestion) `NotesWriter` rotates the old notes to `.prev` only after the new content is in the temp file (`atomic_write(before_replace=...)`), and moves it back if the final rename fails, so the notes path is never left empty; tests for a failed mkstemp and a failed rename (d525d219)

### Checks
- `bash .agent/scripts/tests/test_review_viewer.sh`: `Ran 90 tests ... OK (skipped=1)` (skip: xvfb window smoke test, xvfb-run not installed; the GUI was not launched)
- `bash .agent/scripts/tests/test_script_tests_hook_scope.sh`: `test_script_tests_hook_scope: 357 passed, 0 failed`
- test_skill_paths.sh not run: no skill or knowledge text changed this round.
- Commits ran every hook except validate-script-tests (SKIP per #465). The full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 22:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent ada1d3b19e629ea27, resume 2 of 3)

**Branch**: feature/issue-545 at `c3b4be74`
**Base**: main
**Depth**: Standard (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings

Scope: the round-2 review's 7 findings and the fix diff since `0c509811` (7 commits). Cross-model: skipped (round-3 convergence check, per handoff). Static analysis (pre-commit on `review_viewer.py` and its test) clean; `test_review_viewer.sh` 90 tests OK (1 skipped, xvfb). The GUI was not launched. All 7 findings were verified fixed:
- `--help` now prints the notes format ahead of the chat fallback (checked the output).
- Both dialogs are built inside `_modal()`.
- `_run_dialog` restores a minimised main window before `wait_visibility`. It catches TclError from `wait_visibility` and `grab_set`, and waits only if `winfo_exists()`, which returns 0 rather than raising for a destroyed dialog. A close during startup or a failed grab neither nests a second dialog nor orphans one. Fake-tk tests cover both.
- Only a table's second row is the delimiter row (checked: `| - | - |` shows as typed).
- A pipe is escaped only after an odd run of backslashes.
- `_resolve`, `check_paths` and `read_text` turn OSError/RuntimeError into a one-line exit 1, while UsageError still passes through `read_text`.
- The exit-2 CLI tests skip on macOS and Windows.
- `.prev` order: the new content is in the temp file before the old notes move, and a failed final rename moves them back, so the notes path is never empty. A failed rotate leaves everything in place. The named side effect is accepted. When the final rename fails, the `.prev` from two rounds back has already been overwritten. A successful write would overwrite it the same way, since only one level of history is kept (plan review suggestion 3), so nothing is lost that a success would keep.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 22:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (round-3 pre-push review approved with nothing open; the host's full pre-commit pass passed, exit 0)
**After**: publish
**Decision**: publish

Pushing and opening the pull request. The GUI window has not been run on a display; that is stated in the Decision summary and offered to the owner before the merge.
