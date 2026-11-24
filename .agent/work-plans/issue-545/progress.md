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
