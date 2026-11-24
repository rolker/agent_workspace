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
