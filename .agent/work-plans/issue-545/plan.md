# Plan: A simple local viewer for reviewing a draft and sending annotations back to the agent

## Issue

https://github.com/rolker/agent_workspace/issues/545

## Context

A trial (80 lines of tkinter) let the owner select a passage in a draft, attach a note, and
record a decision; the process exit on window close told the agent to read the notes file.
The owner's four UX answers (2026-11-23) and the host's mechanism decisions (Checkpoint,
After: issue-actions) are the spec and are not reopened: light formatting, edit/delete +
whole-draft note + side list, changes-only second round, ask on close.

## Approach

All logic lives in pure functions in `review_viewer.py`; the tkinter layer only binds them to widgets.

1. **Pure core in `.agent/scripts/review_viewer.py`** (stdlib only, ADR-0009):
   - `check_display(env, import_tk)` returns None or a one-line reason (no `DISPLAY`/`WAYLAND_DISPLAY`, tkinter import fails).
   - `light_format_spans(text)` returns `(line, start_col, end_col, tag)` spans: heading, bold, italic, code (inline and fenced, monospace on grey), table rows (pipes aligned by padding computed per table block). Display text keeps one display line per file line, so line numbers match the file.
   - `selection_to_range(display_index_a, display_index_b)`: maps selection end points to `(first_line, last_line)`, treating a selection ending at column 0 of a line as ending on the previous line.
   - `Note` / `Review` dataclasses with add, edit, delete, whole-draft note (at most one, edited in place).
   - `render_notes(review)` and `parse_notes(text)`: trial format (`# Review notes: <draft>`, `**Decision**:` line, `## Note n (lines a-b)` with blockquote then note) plus `## Note on the whole draft`; decision values `approve`, `changes requested`, `none (notes only)`. Parse exists so a relaunch on the same notes path does not discard notes silently: the file is read at start, and notes from it are NOT carried into the new round (owner Q3), so the old file is renamed to `<notes>.prev` before the first write. Writer is atomic (temp file + rename) and runs after every change.
   - `changed_lines(old, new)` via `difflib.SequenceMatcher`, returning the set of new-file line numbers added or changed (deletions mark the neighbouring line).
   - `snapshot_path(notes_path)` = notes path minus `.notes.md` plus `.reviewed`; `load_previous(args)`; `--previous <file>` overrides.
2. **Thin GUI layer**: `ScrolledText` (read-only) with tags from the spans, changed-line background, noted-passage highlight; right-hand side list (`Listbox`) of notes, click jumps to and flashes the passage; buttons Add note (Ctrl+N), Note on whole draft, Edit, Delete, Approve, Changes requested. Add/edit use a small text dialog. On close: if no decision, ask Approve / Changes requested / Just close (Just close writes `none (notes only)`); then save the shown text to the `.reviewed` snapshot; exit 0.
3. **CLI**: `review_viewer.py <draft.md> [--notes PATH] [--previous FILE]`; default notes `<draft>.notes.md` beside the draft. Exit 0 normal close; exit 2 with one stderr line (no traceback) when no display or tkinter; exit 1 for a missing draft. Unhandled GUI exceptions after `Tk()` succeeds still exit non-zero after the last write.
4. **Tests** `.agent/scripts/tests/test_review_viewer.py` (unittest) plus wrapper `test_review_viewer.sh` modelled on `test_progress_read.sh` (with `# covers:` line; `chmod +x`): cover the notes writer/parser round trip (including multi-line passages, whole-draft note, each decision), line-range mapping edge cases, light-format spans (nested bold in heading, code fences, table alignment with uneven cells), `changed_lines`, snapshot path, display check cases, the CLI exit 2 under an empty environment (subprocess), exit 1 for missing draft, and renaming of a stale notes file. Optional smoke under `xvfb-run` skipped with a message when absent. Add the `.py` entry to the `ROOT_READERS` map in `test_script_tests_hook_scope.sh` if its check requires it (verify by running that suite).
5. **Docs in the same PR (ADR-0017)**: `docs/design.md#review-loop-and-timeline` gains a short paragraph on the local draft review step (notes file, decision, exit codes, chat fallback, the host records the decision in an existing `## Checkpoint` entry, no new entry type); `.agent/knowledge/script_reference.md` row; chat-fallback instructions (`cat -n`, same notes format) in the script's `--help` epilog and the script_reference row. No change to `docs/design.md#worktrees`: the notes path is chosen by the launcher.
6. **Verify**: run the new suite, `test_script_tests_hook_scope.sh`, `test_design_anchors.sh`, and `make lint`; launch once under WSLg (or xvfb) with a sample draft to check the look.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/review_viewer.py` | New: pure core and thin tkinter layer (executable) |
| `.agent/scripts/tests/test_review_viewer.py` | New: unit and CLI tests |
| `.agent/scripts/tests/test_review_viewer.sh` | New: wrapper, `chmod +x` |
| `.agent/scripts/tests/test_script_tests_hook_scope.sh` | Add `.py` suite to the reader map if required |
| `.agent/knowledge/script_reference.md` | Add the script row |
| `docs/design.md` | Local review step in Review loop and timeline |

## Prior Art

The trial script (issue #545 first comment) is the base: notes format, launch-as-background, close-as-signal. Taken as is. Rejected: a terminal viewer (out of scope), full Markdown rendering (owner chose light formatting), carrying old notes into round two (owner chose changes only), git-based previous-round lookup (fails for untracked drafts). `progress_read.py` plus its `.sh` wrapper is the existing pattern for a Python script with unittest coverage.

## Serves

Trust, control and information (the owner reviews drafts and records approval) and "A safeguard has to earn its cost" in `README.md#workspace-goals`; `docs/design.md#review-loop-and-timeline`.

## Design Picture

Changes `docs/design.md#review-loop-and-timeline`: a local draft-review step with a notes file and a recorded decision becomes a way the owner answers at a checkpoint. Updated in this PR.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Design section updated in the same PR |
| Only what's needed | Exactly the owner's features; no note carry-over, no rendering beyond light styling, no skill wiring |
| Test what breaks | Logic in pure functions with tests; GUI thin; display-less exit tested |
| Tool-neutral | Plain Markdown notes; chat fallback writes the same format |
| Leave a trail | Notes file and decision persist, rewritten atomically after every change |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 project-agnostic | Yes | No project, repo or GitHub assumption; notes path is an argument |
| 0009 Python policy | Yes | Standard library only |
| 0013 entry vocabulary | No new type | Host summarises the decision in an existing Checkpoint |
| 0017 design is current picture | Yes | Step 5 |
| 0010 / #544 | Related | Format free of GitHub assumptions |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Add a script | `script_reference.md` | Yes |
| Add a test suite | hook-scope reader map, exec bit on wrapper | Yes |
| New review step | design section | Yes |
| Skills that draft for approval | line offering the viewer | No, follow-up issue |

## Open Questions

- None for the owner. Implementer's choice to confirm in review: a relaunch on an existing notes path renames the old file to `.prev` rather than overwriting or appending (nothing is lost, old notes are not carried over).

## Estimated Scope

Single PR (one script about 400 lines, tests, two doc edits). If review finds it too large, split the side list and changes-only highlighting into a second PR.
