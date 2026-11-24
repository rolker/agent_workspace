#!/usr/bin/env python3
"""Review a draft in a local window and leave line-anchored notes (issue #545).

Usage::

    python3 .agent/scripts/review_viewer.py <draft.md> [--notes PATH] [--previous FILE]

A session launches this as a background command; the process exiting when
the owner closes the window is the signal to read the notes file. Standard
library only (tkinter, difflib; ADR-0009).

The window shows the draft read-only with light formatting (headings, bold,
italic, code on grey, table pipes lined up), one display line per file line,
so line numbers match the file. The owner selects a passage and adds a note
(Ctrl+N), adds one note on the whole draft, edits or deletes notes from the
side list (a click jumps to the passage), and records a decision: Approve or
Changes requested. Closing with no decision asks Approve / Changes requested /
Just close; Just close records ``none (notes only)``.

Notes file (default ``<draft>.notes.md`` beside the draft; ``--notes`` puts it
elsewhere, its folder created at the first write). It is rewritten, atomically,
after every change::

    # Review notes: <draft file name>

    Written <local time with offset>

    **Decision**: approve | changes requested | none (notes only)

    ## Note on the whole draft

    <note>

    ## Note <n> (lines <a>-<b>)

    > <passage, quoted from the draft file>

    <note>

No ``**Decision**`` line means none was recorded: the window was killed, or
is still open. Passages are always the file's own text (never the padded
display text of a table), so the agent can find them in the draft.

At the first write of a session an existing notes file is renamed to
``<notes>.prev`` (``os.replace``, one level kept): this round's notes never mix
with the last round's, and the last round's are not lost.

Changes since the last round: on close the draft text as read at launch is
saved to the snapshot ``<notes path without .notes.md>.reviewed`` (a notes path
not ending in ``.notes.md`` gets ``.reviewed`` appended to the whole path). The
next launch on the same notes path diffs the draft against that snapshot and
highlights the added or changed lines (a deleted run marks the line after it).
``--previous FILE`` diffs against FILE instead. No notes are carried over.

Exit codes: 0 the window closed (read the notes file for the decision);
1 an error, said on stderr: a usage error before any window (a bad or
missing argument, a missing draft or ``--previous`` file, unreadable text,
a ``--notes`` path that is a folder or whose notes, ``.prev`` or snapshot
would overwrite the draft or the ``--previous`` file),
or the window failed (an internal error in the window, with its traceback,
or a save on close that failed and the owner chose to close anyway; the
notes file may lack the decision);
2 no display or no tkinter (one line on stderr, no traceback).

A save that fails on close keeps the window open with the error in its
status line; closing again retries, and the owner may close anyway.
"""

# One file on purpose: the window is launched by path with no install step.
# pylint: disable=too-many-lines

import argparse
import contextlib
import dataclasses
import datetime
import difflib
import os
import re
import sys
import tempfile
import traceback
from pathlib import Path
from typing import Callable, Dict, List, Mapping, Optional, Sequence, Set, Tuple

DECISIONS = ("approve", "changes requested", "none (notes only)")

NOTES_FORMAT = """\
Notes file format (default <draft>.notes.md beside the draft):

    # Review notes: <draft file name>

    Written <local time with offset>

    **Decision**: approve | changes requested | none (notes only)

    ## Note on the whole draft

    <note>

    ## Note <n> (lines <a>-<b>)

    > <passage, quoted from the draft file>

    <note>

No **Decision** line means none was recorded."""

CHAT_FALLBACK = """\
Exit code 2 means no window can open here (no display, no tkinter, or the
display refused the connection). Run the same review in chat instead: show the
draft with line numbers (cat -n <draft>), take the owner's comments by line
range, and write the notes file in the format above yourself, with the
**Decision** line he gives."""

# ---------------------------------------------------------------------------
# Display check
# ---------------------------------------------------------------------------


# Platforms whose Tk draws natively, needing neither DISPLAY nor WAYLAND_DISPLAY.
NATIVE_TK_PLATFORMS = ("darwin", "win32")


def check_display(
    env: Mapping[str, str], import_tk: Callable[[], object], platform: str = sys.platform
) -> Optional[str]:
    """Return None if a window may open, else a one-line reason.

    ``import_tk`` imports tkinter (raises ImportError when it is missing).
    The DISPLAY / WAYLAND_DISPLAY test applies only where Tk uses X11 (not
    macOS or native Windows). A display that is set but unreachable, or no
    window system at all on those two, is caught later, when ``Tk()`` raises
    ``TclError``.
    """
    needs_env = platform not in NATIVE_TK_PLATFORMS
    if needs_env and not env.get("DISPLAY") and not env.get("WAYLAND_DISPLAY"):
        return "no display (neither DISPLAY nor WAYLAND_DISPLAY is set)"
    try:
        import_tk()
    except ImportError as exc:
        return f"tkinter is not available ({one_line(str(exc))})"
    return None


def one_line(message: str) -> str:
    """The first non-empty line of a message, for one-line error output."""
    for line in message.splitlines():
        if line.strip():
            return line.strip()
    return message.strip()


# ---------------------------------------------------------------------------
# Lines and light formatting
# ---------------------------------------------------------------------------


def split_lines(text: str) -> List[str]:
    """Split on newlines only, as an editor numbers lines (``cat -n``).

    ``str.splitlines`` also splits on form feeds and other separators, which
    would put the window's line numbers out of step with the file's. A
    trailing newline does not start an extra line; a trailing CR is dropped.
    """
    if text == "":
        return []
    lines = text.split("\n")
    if lines[-1] == "":
        lines.pop()
    return [line[:-1] if line.endswith("\r") else line for line in lines]


Span = Tuple[int, int, int, str]  # (line 1-based, start col, end col, tag)


@dataclasses.dataclass
class Formatted:
    """The display text and how it maps back to the file.

    ``lines[i]`` is the display of file line ``i + 1``. ``colmaps[i]`` is None
    when the display line equals the file line, else a list of length
    ``len(lines[i]) + 1`` giving, for each display column, the file column.
    """

    lines: List[str]
    colmaps: List[Optional[List[int]]]
    spans: List[Span]

    @property
    def text(self) -> str:
        return "\n".join(self.lines)

    def to_raw_col(self, line: int, col: int) -> int:
        cmap = self.colmaps[line - 1]
        if cmap is None:
            return col
        return cmap[min(max(col, 0), len(cmap) - 1)]


FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
HEADING_RE = re.compile(r"^\s{0,3}#{1,6}(\s|$)")
INLINE_CODE_RE = re.compile(r"(`+)(.+?)\1")
BOLD_RE = re.compile(r"(\*\*|__)(?=\S)(.+?)(?<=\S)\1")
ITALIC_RE = re.compile(
    r"(?<![\w*])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![\w*])"
    r"|(?<![\w_])_(?=[^\s_])(.+?)(?<=[^\s_])_(?![\w_])"
)
SEPARATOR_CELL_RE = re.compile(r"^:?-+:?$")


def _escaped(line: str, i: int) -> bool:
    """Whether the character at ``i`` follows an odd run of backslashes."""
    run = 0
    while i - run - 1 >= 0 and line[i - run - 1] == "\\":
        run += 1
    return run % 2 == 1


def _table_cells(line: str) -> Tuple[str, List[Tuple[int, str]]]:
    """Split a table row into its indent and (file column, text) cells.

    A pipe after an odd number of backslashes is escaped and stays inside its
    cell; after an even number (``\\\\|``, an escaped backslash) it splits.
    Cell text is stripped; its file column is where the stripped text starts.
    """
    indent = line[: len(line) - len(line.lstrip())]
    pipes = [i for i, ch in enumerate(line) if ch == "|" and not _escaped(line, i)]
    bounds = [len(indent) - 1] + pipes + [len(line)]
    segments = []
    for left, right in zip(bounds, bounds[1:]):
        segments.append((left + 1, line[left + 1 : right]))
    # The segment before the leading pipe is the indent: drop it. A trailing
    # pipe leaves an empty last segment: drop it too.
    segments = segments[1:]
    if pipes and pipes[-1] == len(line.rstrip()) - 1 and segments:
        segments = segments[:-1]
    cells = []
    for start, seg in segments:
        lead = len(seg) - len(seg.lstrip())
        cells.append((start + lead, seg.strip()))
    return indent, cells


def _align_table(rows: Sequence[str]) -> List[Tuple[str, List[int]]]:
    """Pad a block of table rows so the pipes line up.

    Returns, per row, the display line and its display-to-file column map.
    """
    parsed = [_table_cells(row) for row in rows]
    # The delimiter row is the block's second row, when every cell is dashes.
    # Any other row of dashes (a row of N/A) is data and is shown as typed.
    separator = [
        k == 1 and bool(cells) and all(SEPARATOR_CELL_RE.match(c) for _, c in cells)
        for k, (_, cells) in enumerate(parsed)
    ]
    widths: List[int] = []
    for is_sep, (_, cells) in zip(separator, parsed):
        for k, (_, cell) in enumerate(cells):
            if k == len(widths):
                widths.append(0)
            if not is_sep:
                widths[k] = max(widths[k], len(cell))
    widths = [max(w, 3) for w in widths]
    out = []
    for row, is_sep, (indent, cells) in zip(rows, separator, parsed):
        # (display text, file column of each of its characters)
        parts: List[Tuple[str, Sequence[int]]] = [(indent, range(len(indent)))]
        pipe_col = row.find("|", len(indent))
        parts.append(("|", [max(pipe_col, 0)]))
        for k, (start, cell) in enumerate(cells):
            end = start + len(cell)
            if is_sep:
                left = ":" if cell.startswith(":") else "-"
                right = ":" if len(cell) > 1 and cell.endswith(":") else "-"
                body = left + "-" * (widths[k] - 2) + right
                parts.append((" ", [start]))
                parts.append((body, [min(start + i, end) for i in range(len(body))]))
                parts.append((" ", [end]))
            else:
                pad = widths[k] - len(cell)
                parts.append((" ", [start]))
                parts.append((cell, range(start, end)))
                parts.append((" " * (pad + 1), [end] * (pad + 1)))
            nxt = row.find("|", end)
            parts.append(("|", [nxt if nxt >= 0 else len(row)]))
        cmap = [col for _, cols in parts for col in cols] + [len(row)]
        out.append(("".join(text for text, _ in parts), cmap))
    return out


def fenced_lines(raw: Sequence[str]) -> List[bool]:
    """Which lines are inside a code fence, its opening and closing lines included.

    As CommonMark has it: a backtick fence's info string holds no backtick
    (so a line starting with triple-backtick inline code opens no fence), and
    a closing fence is the same character, at least as long, with nothing
    after it but spaces (so an info-string line inside a fence does not close
    it). An unclosed fence runs to the end of the draft.
    """
    out: List[bool] = []
    opener: Optional[str] = None
    for line in raw:
        m = FENCE_RE.match(line)
        if opener is not None:
            out.append(True)
            if (
                m
                and m.group(1)[0] == opener[0]
                and len(m.group(1)) >= len(opener)
                and not m.group(2).strip()
            ):
                opener = None
        elif m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
            opener = m.group(1)
            out.append(True)
        else:
            out.append(False)
    return out


def light_format(text: str) -> Formatted:
    """Display lines, column maps and style spans for the draft text.

    Markers (``#``, ``**``, backticks) stay visible, so every display line is
    the file line except table rows, which are padded to line up the pipes.
    """
    raw = split_lines(text)
    lines = list(raw)
    colmaps: List[Optional[List[int]]] = [None] * len(raw)
    spans: List[Span] = []
    fenced = fenced_lines(raw)
    table_start: Optional[int] = None

    def flush_table(end: int) -> None:
        if table_start is None:
            return
        for offset, (disp, cmap) in enumerate(_align_table(raw[table_start:end])):
            idx = table_start + offset
            if disp != raw[idx]:
                lines[idx] = disp
                colmaps[idx] = cmap

    for i, line in enumerate(raw):
        if fenced[i]:
            flush_table(i)
            table_start = None
            spans.append((i + 1, 0, len(line), "code"))
            continue
        if line.lstrip().startswith("|"):
            if table_start is None:
                table_start = i
        else:
            flush_table(i)
            table_start = None
    flush_table(len(raw))

    for i, disp in enumerate(lines):
        if not fenced[i]:
            spans.extend(_inline_spans(i + 1, disp))
    spans.sort()
    return Formatted(lines, colmaps, spans)


def _inline_spans(lineno: int, line: str) -> List[Span]:
    spans: List[Span] = []
    if HEADING_RE.match(line):
        spans.append((lineno, 0, len(line), "heading"))
    if line.lstrip().startswith("|"):
        spans.append((lineno, 0, len(line), "table"))
    code = [(m.start(), m.end()) for m in INLINE_CODE_RE.finditer(line)]
    spans.extend((lineno, a, b, "code") for a, b in code)

    def outside_code(a: int, b: int) -> bool:
        return all(b <= ca or a >= cb for ca, cb in code)

    for m in BOLD_RE.finditer(line):
        if outside_code(m.start(), m.end()):
            spans.append((lineno, m.start(), m.end(), "bold"))
    for m in ITALIC_RE.finditer(line):
        if outside_code(m.start(), m.end()):
            spans.append((lineno, m.start(), m.end(), "italic"))
    return spans


# ---------------------------------------------------------------------------
# Selections and passages
# ---------------------------------------------------------------------------

Index = Tuple[int, int]  # (line 1-based, display column)


def parse_index(index: str) -> Index:
    """A Tk text index "L.C" as (line, column)."""
    line, col = index.split(".")
    return int(line), int(col)


def selection_to_range(start: Index, end: Index) -> Tuple[int, int]:
    """The file lines a selection covers.

    A selection that ends at column 0 of a later line (a whole line selected
    with its newline) ends on the line before.
    """
    first, last = start[0], end[0]
    if end[1] == 0 and last > first:
        last -= 1
    return first, last


def passage_text(raw_text: str, fmt: Formatted, start: Index, end: Index) -> str:
    """The file's own text for a display selection (never the padded display)."""
    raw = split_lines(raw_text)
    if not raw:
        return ""
    (la, ca), (lb, cb) = start, end
    # A selection ending at column 0 of a later line ends on the line before
    # (as selection_to_range): drop that one empty last segment, and only it,
    # so blank lines inside the range stay quoted.
    ends_at_line_start = cb == 0 and la < lb <= len(raw)
    # Tk's last index ("end") sits one line past the text: clamp to the file.
    la = min(max(la, 1), len(raw))
    ra = fmt.to_raw_col(la, ca)
    if lb > len(raw):
        lb, rb = len(raw), len(raw[-1])
    else:
        rb = fmt.to_raw_col(lb, cb)
    if la == lb:
        return raw[la - 1][ra:rb]
    segments = [raw[la - 1][ra:]] + raw[la : lb - 1] + [raw[lb - 1][:rb]]
    if ends_at_line_start:
        segments.pop()
    return "\n".join(segments)


# ---------------------------------------------------------------------------
# Notes
# ---------------------------------------------------------------------------


@dataclasses.dataclass
class Note:
    first: int
    last: int
    passage: str
    text: str
    anchor: Optional[Tuple[Index, Index]] = dataclasses.field(default=None, compare=False)


@dataclasses.dataclass
class Review:
    draft_name: str
    notes: List[Note] = dataclasses.field(default_factory=list)
    whole: Optional[str] = None
    decision: Optional[str] = None

    def add(self, note: Note) -> int:
        self.notes.append(note)
        return len(self.notes) - 1

    def edit(self, index: int, text: str) -> None:
        self.notes[index].text = text

    def delete(self, index: int) -> None:
        del self.notes[index]

    def set_whole(self, text: Optional[str]) -> None:
        """Set, replace, or (with None or blank) remove the whole-draft note."""
        self.whole = text if text and text.strip() else None

    def decide(self, decision: str) -> None:
        if decision not in DECISIONS:
            raise ValueError(f"unknown decision: {decision!r}")
        self.decision = decision


def render_notes(review: Review, written: Optional[datetime.datetime] = None) -> str:
    when = (written or datetime.datetime.now().astimezone()).isoformat(timespec="seconds")
    out = [f"# Review notes: {review.draft_name}", "", f"Written {when}", ""]
    if review.decision:
        out += [f"**Decision**: {review.decision}", ""]
    if review.whole:
        out += ["## Note on the whole draft", "", review.whole.strip("\n"), ""]
    for n, note in enumerate(review.notes, start=1):
        quoted = "\n".join(("> " + p) if p else ">" for p in note.passage.split("\n"))
        out += [f"## Note {n} (lines {note.first}-{note.last})", "", quoted, ""]
        out += [note.text.strip("\n"), ""]
    return "\n".join(out)


NOTE_HEAD_RE = re.compile(r"^## Note (\d+) \(lines (\d+)-(\d+)\)$")
WHOLE_HEAD = "## Note on the whole draft"


def parse_notes(text: str) -> Review:
    """Read a notes file back (used by the format's round-trip test).

    A note's text that itself holds a ``## Note`` heading line cannot be told
    from the next note; the window writes what the owner typed as is.
    """
    lines = text.split("\n")
    title = lines[0][len("# Review notes: ") :] if lines else ""
    review = Review(title)
    sections: List[Tuple[str, List[str]]] = []
    for line in lines[1:]:
        if line.startswith("**Decision**: ") and not sections:
            review.decision = line[len("**Decision**: ") :].strip()
        elif line == WHOLE_HEAD or NOTE_HEAD_RE.match(line):
            sections.append((line, []))
        elif sections:
            sections[-1][1].append(line)
    for head, body in sections:
        body_text = "\n".join(body).strip("\n")
        if head == WHOLE_HEAD:
            review.whole = body_text
            continue
        m = NOTE_HEAD_RE.match(head)
        assert m is not None
        quote: List[str] = []
        rest = body_text.split("\n")
        while rest and (rest[0] == ">" or rest[0].startswith("> ")):
            quote.append(rest.pop(0)[2:])
        review.add(
            Note(int(m.group(2)), int(m.group(3)), "\n".join(quote), "\n".join(rest).strip("\n"))
        )
    return review


def atomic_write(
    path: Path, content: str, before_replace: Optional[Callable[[], None]] = None
) -> None:
    """Write via a temp file in the same folder and rename over the target.

    ``before_replace`` runs once the content is safely in the temp file, just
    before the rename; if it raises, the target is left as it was.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix="." + path.name + ".", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
        if before_replace is not None:
            before_replace()
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


class NotesWriter:  # pylint: disable=too-few-public-methods
    """Writes the notes file; the first write moves a previous one to ``.prev``.

    The rename happens at the first write, not at launch, so a window closed
    or killed before any change leaves the old notes file where it was. It
    happens only once the new notes are written to a temp file, and is undone
    if the final rename fails, so a failed first write leaves the old notes
    file at the notes path rather than no file at all.
    """

    def __init__(self, path: Path):
        self.path = path
        self.prev_path = Path(str(path) + ".prev")
        self._rotated = False

    def write(self, content: str) -> None:
        if self._rotated:
            atomic_write(self.path, content)
            return
        moved = []

        def rotate() -> None:
            if self.path.exists():
                os.replace(self.path, self.prev_path)
                moved.append(True)

        try:
            atomic_write(self.path, content, before_replace=rotate)
        except BaseException:
            if moved and not self.path.exists():
                os.replace(self.prev_path, self.path)  # put the old notes back
            raise
        self._rotated = True


# ---------------------------------------------------------------------------
# Changes since the last round
# ---------------------------------------------------------------------------


def snapshot_path(notes_path: Path) -> Path:
    """Where the draft shown in this round is kept for the next round's diff.

    ``x.notes.md`` -> ``x.reviewed``; any other notes path gets ``.reviewed``
    appended to the whole name.
    """
    name = notes_path.name
    if name.endswith(".notes.md") and name != ".notes.md":
        return notes_path.with_name(name[: -len(".notes.md")] + ".reviewed")
    return notes_path.with_name(name + ".reviewed")


def changed_lines(old: str, new: str) -> Set[int]:
    """1-based lines of ``new`` added or changed relative to ``old``.

    Both are the raw file texts. A deleted run marks the line after it (the
    last line when the deletion was at the end).
    """
    a, b = split_lines(old), split_lines(new)
    marked: Set[int] = set()
    matcher = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
    for tag, _i1, _i2, j1, j2 in matcher.get_opcodes():
        if tag in ("replace", "insert"):
            marked.update(range(j1 + 1, j2 + 1))
        elif tag == "delete" and b:
            marked.add(min(j1 + 1, len(b)))
    return marked


class UsageError(Exception):
    """A problem with the arguments or the files they name (exit 1)."""


def _same_file(a: Path, b: Path) -> bool:
    if a.resolve() == b.resolve():
        return True
    try:
        return a.exists() and b.exists() and os.path.samefile(a, b)
    except OSError:
        return False


def check_paths(draft: Path, notes: Path, previous: Optional[Path] = None) -> None:
    """Refuse a notes path whose writes would land on an input or a folder.

    The window writes three paths: the notes file, its ``.prev`` and the
    ``.reviewed`` snapshot. None may be a folder, and none may be the draft
    or the ``--previous`` file, except that the snapshot may be the
    ``--previous`` file: that file is read at launch, and replacing it on
    close is what every round does to the snapshot. A path that cannot be
    checked (a folder that may not be searched, a symlink loop) is refused.
    """
    try:
        _check_paths(draft, notes, previous)
    except (OSError, RuntimeError) as exc:
        raise UsageError(f"cannot check the --notes path {notes}: {one_line(str(exc))}") from exc


def _check_paths(draft: Path, notes: Path, previous: Optional[Path]) -> None:
    if notes.is_dir():
        raise UsageError(f"--notes names a folder, not a file: {notes}")
    written = {
        "notes file": notes,
        "notes .prev file": Path(str(notes) + ".prev"),
        ".reviewed snapshot": snapshot_path(notes),
    }
    inputs = {"draft": draft}
    if previous is not None:
        inputs["--previous file"] = previous
    for wname, wpath in written.items():
        if wpath.is_dir():
            raise UsageError(f"the {wname} path is a folder: {wpath}")
        for iname, ipath in inputs.items():
            if wname == ".reviewed snapshot" and iname == "--previous file":
                continue
            if _same_file(wpath, ipath):
                raise UsageError(
                    f"the {wname} would overwrite the {iname} ({wpath}); "
                    "choose another --notes path"
                )


def read_text(path: Path, what: str) -> str:
    try:
        if not path.is_file():
            raise UsageError(f"{what} not found: {path}")
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise UsageError(f"cannot read {what} {path}: {one_line(str(exc))}") from exc


# ---------------------------------------------------------------------------
# Session: everything the window does, without the window
# ---------------------------------------------------------------------------


class Session:
    """One review round: the draft as read at launch, the notes, the writer."""

    def __init__(self, draft: Path, notes_path: Path, previous: Optional[Path] = None):
        self.draft = draft
        check_paths(draft, notes_path, previous)
        self.raw_text = read_text(draft, "draft")
        self.formatted = light_format(self.raw_text)
        self.writer = NotesWriter(notes_path)
        prev_file = previous if previous is not None else self.snapshot
        if previous is not None:
            prev_text: Optional[str] = read_text(previous, "--previous file")
        elif self.snapshot.is_file():
            prev_text = read_text(self.snapshot, "last round's snapshot")
        else:
            prev_text = None
        self.previous_file = prev_file if prev_text is not None else None
        self.changed = changed_lines(prev_text, self.raw_text) if prev_text is not None else set()
        self.review = Review(draft.name)

    @property
    def notes_path(self) -> Path:
        return self.writer.path

    @property
    def snapshot(self) -> Path:
        """Where the draft as read at launch is kept for the next round."""
        return snapshot_path(self.writer.path)

    def note_from_selection(self, start: Index, end: Index, text: str) -> int:
        """Add a note on a display selection; the caller saves."""
        first, last = selection_to_range(start, end)
        passage = passage_text(self.raw_text, self.formatted, start, end)
        return self.review.add(Note(first, last, passage, text, anchor=(start, end)))

    def save(self) -> None:
        self.writer.write(render_notes(self.review))

    def finish(self, decision: str) -> None:
        """Record the decision, write the notes, keep the shown draft for next round."""
        self.review.decide(decision)
        self.save()
        atomic_write(self.snapshot, self.raw_text)


# ---------------------------------------------------------------------------
# The window (thin: every rule above is tested without it)
# ---------------------------------------------------------------------------


# pylint: disable-next=too-many-instance-attributes
class ViewerApp:  # pragma: no cover - needs a display; smoke-tested under xvfb
    def __init__(self, root, session: Session):
        # pylint: disable=import-outside-toplevel
        import tkinter as tk
        from tkinter import font as tkfont
        from tkinter import scrolledtext

        self.tk = tk
        self.root = root
        self.session = session
        # Set when the window failed; main() then exits 1, not 0.
        self.failed: Optional[str] = None
        self._closing = False
        # Dialogs open now. The window manager's close button is not held off
        # by a dialog's grab, so on_close ignores it while this is above 0.
        self._modal_depth = 0
        self._flash_timer: Optional[str] = None
        root.report_callback_exception = self._callback_error
        root.title(f"Review: {session.draft.name}")
        root.geometry("1200x800")

        family = tkfont.nametofont("TkFixedFont").actual("family")
        base = tkfont.Font(family=family, size=11)
        self.fonts = {
            "base": base,
            "bold": tkfont.Font(family=family, size=11, weight="bold"),
            "italic": tkfont.Font(family=family, size=11, slant="italic"),
            "heading": tkfont.Font(family=family, size=12, weight="bold"),
        }

        panes = tk.PanedWindow(root, orient=tk.HORIZONTAL, sashrelief=tk.RAISED)
        panes.pack(fill=tk.BOTH, expand=True)
        self.text = scrolledtext.ScrolledText(panes, wrap=tk.WORD, font=base, padx=10, pady=10)
        # ScrolledText lives in its own frame (with the scrollbar): add that.
        panes.add(self.text.frame, stretch="always", minsize=400)
        side = tk.Frame(panes)
        tk.Label(side, text="Notes (click to jump)", anchor="w").pack(fill=tk.X)
        self.listbox = tk.Listbox(side, activestyle="dotbox", exportselection=False)
        self.listbox.pack(fill=tk.BOTH, expand=True)
        panes.add(side, minsize=220, width=300)
        self._build_text()

        toolbar = tk.Frame(root)
        buttons = [
            ("Add note (Ctrl+N)", self.add_note),
            ("Note on whole draft", self.whole_note),
            ("Edit", self.edit_note),
            ("Delete", self.delete_note),
            ("Approve", lambda: self.decide("approve")),
            ("Changes requested", lambda: self.decide("changes requested")),
        ]
        for label, command in buttons:
            tk.Button(toolbar, text=label, command=command).pack(side=tk.LEFT, padx=3, pady=4)
        self.status = tk.StringVar()
        tk.Label(toolbar, textvariable=self.status, anchor="w").pack(side=tk.LEFT, padx=10)
        toolbar.pack(fill=tk.X)

        # On the text widget too, ahead of its class bindings: Tk's Text class
        # binds Control-n to <<NextLine>>, which moves the cursor and clears the
        # selection before a root binding would run. "break" stops that.
        for seq in ("<Control-n>", "<Control-N>"):
            self.text.bind(seq, lambda _e: self.add_note() or "break")
            root.bind(seq, lambda _e: self.add_note() or "break")
        self.listbox.bind("<<ListboxSelect>>", self.jump)
        self.listbox.bind("<Double-Button-1>", lambda _e: self.edit_note())
        self.listbox.bind("<Delete>", lambda _e: self.delete_note())
        root.protocol("WM_DELETE_WINDOW", self.on_close)

        msg = f"Select text, then Add note. Notes go to {session.notes_path}"
        if session.previous_file is not None:
            msg += f" | {len(session.changed)} line(s) changed since {session.previous_file.name}"
        self.status.set(msg)

    def _build_text(self) -> None:
        tk, st, fmt = self.tk, self.text, self.session.formatted
        st.insert("1.0", fmt.text)
        st.tag_configure("heading", font=self.fonts["heading"])
        st.tag_configure("bold", font=self.fonts["bold"])
        st.tag_configure("italic", font=self.fonts["italic"])
        st.tag_configure("code", background="#ececec")
        st.tag_configure("table", foreground="#202060")
        st.tag_configure("changed", background="#dcebff")
        st.tag_configure("noted", background="#fff3b0")
        st.tag_configure("flash", background="#ffb060")
        for line, a, b, tag in fmt.spans:
            st.tag_add(tag, f"{line}.{a}", f"{line}.{b}")
        for line in sorted(self.session.changed):
            # Through the newline, so a changed blank line still shows.
            st.tag_add("changed", f"{line}.0", f"{line}.0 lineend +1c")
        # Tags configured after the widget was made sit above "sel"; the
        # selection must stay visible over every one of them, so it goes last.
        for tag in ("changed", "noted", "flash", "sel"):
            st.tag_raise(tag)
        st.configure(state=tk.DISABLED)

    # -- helpers ----------------------------------------------------------

    @contextlib.contextmanager
    def _modal(self):
        self._modal_depth += 1
        try:
            yield
        finally:
            self._modal_depth -= 1

    def _callback_error(self, exc_type, exc, tb) -> None:
        """An exception in a Tk callback: report it and make the exit non-zero.

        Tk's default prints the traceback and carries on, so the run would
        still exit 0. The window stays open (the notes so far may be saved),
        unless the error came while closing, which would otherwise trap the
        owner in a window that cannot close.
        """
        traceback.print_exception(exc_type, exc, tb, file=sys.stderr)
        self.failed = f"internal error: {exc_type.__name__}: {one_line(str(exc))}"
        print(f"review_viewer: {self.failed}", file=sys.stderr)
        if self._closing:
            self.root.destroy()
            return
        self.status.set(f"INTERNAL ERROR ({self.failed}); the viewer exits with an error.")

    def _refresh(self) -> None:
        review = self.session.review
        self.listbox.delete(0, self.tk.END)
        if review.whole:
            self.listbox.insert(self.tk.END, "Whole draft: " + review.whole.split("\n")[0][:60])
        for n, note in enumerate(review.notes, start=1):
            first_line = note.text.split("\n")[0][:50]
            self.listbox.insert(self.tk.END, f"{n} (lines {note.first}-{note.last}): {first_line}")
        self.text.tag_remove("noted", "1.0", self.tk.END)
        for note in review.notes:
            if note.anchor:
                (la, ca), (lb, cb) = note.anchor
                self.text.tag_add("noted", f"{la}.{ca}", f"{lb}.{cb}")

    def _selected(self) -> Optional[int]:
        """The selected list row as -1 (whole-draft note) or a note index."""
        sel = self.listbox.curselection()
        if not sel:
            return None
        row = sel[0]
        if self.session.review.whole:
            return -1 if row == 0 else row - 1
        return row

    def _save(self, message: str) -> bool:
        try:
            self.session.save()
        except OSError as exc:
            from tkinter import messagebox  # pylint: disable=import-outside-toplevel

            with self._modal():
                messagebox.showerror("Notes not saved", str(exc), parent=self.root)
            self.status.set(f"NOT SAVED: {one_line(str(exc))}")
            return False
        self.status.set(message)
        return True

    def _run_dialog(self, dialog) -> None:
        """Show a dialog and wait until it closes; the caller is inside _modal().

        A minimised main window is restored first: a transient dialog does not
        map while its master is iconified, and waiting for it would hang. A
        grab that fails (another application holds one, or the dialog is
        already gone) is skipped, and the dialog still works without it.
        """
        try:
            if self.root.state() == "iconic":
                self.root.deiconify()
            dialog.wait_visibility()
            dialog.grab_set()
        except self.tk.TclError:
            pass
        if dialog.winfo_exists():
            self.root.wait_window(dialog)

    def _ask_text(self, title: str, prompt: str, initial: str = "") -> Optional[str]:
        tk = self.tk
        # Inside _modal() from the start: building and showing the dialog runs
        # the event loop, and a close then must not open a second one.
        with self._modal():
            dialog = tk.Toplevel(self.root)
            dialog.title(title)
            dialog.transient(self.root)
            tk.Label(dialog, text=prompt + "  (Ctrl+Enter to save)", anchor="w").pack(fill=tk.X)
            box = tk.Text(dialog, width=70, height=8, wrap=tk.WORD, font=self.fonts["base"])
            box.insert("1.0", initial)
            box.pack(fill=tk.BOTH, expand=True, padx=6, pady=4)
            result: Dict[str, Optional[str]] = {"value": None}

            def ok(_event=None):
                result["value"] = box.get("1.0", "end-1c")
                dialog.destroy()
                return "break"

            row = tk.Frame(dialog)
            tk.Button(row, text="Save", command=ok).pack(side=tk.LEFT, padx=4, pady=4)
            tk.Button(row, text="Cancel", command=dialog.destroy).pack(side=tk.LEFT, padx=4)
            row.pack()
            box.bind("<Control-Return>", ok)
            box.focus_set()
            self._run_dialog(dialog)
        return result["value"]

    # -- actions ----------------------------------------------------------

    def add_note(self) -> None:
        try:
            a, b = self.text.index("sel.first"), self.text.index("sel.last")
        except self.tk.TclError:
            self.status.set("Select a passage first (or use Note on whole draft).")
            return
        text = self._ask_text("Note", "Note on the selected passage:")
        if not text or not text.strip():
            return
        self.session.note_from_selection(parse_index(a), parse_index(b), text)
        self._refresh()
        count = len(self.session.review.notes)
        self._save(f"{count} note(s) saved to {self.session.notes_path.name}")

    def whole_note(self) -> None:
        review = self.session.review
        text = self._ask_text(
            "Note on the whole draft", "Note on the whole draft:", review.whole or ""
        )
        if text is None:
            return
        review.set_whole(text)
        self._refresh()
        self._save("Whole-draft note " + ("saved." if review.whole else "removed."))

    def edit_note(self) -> None:
        idx = self._selected()
        if idx is None:
            self.status.set("Pick a note in the list first.")
            return
        if idx == -1:
            self.whole_note()
            return
        note = self.session.review.notes[idx]
        text = self._ask_text("Edit note", f"Note {idx + 1}:", note.text)
        if not text or not text.strip():
            return
        self.session.review.edit(idx, text)
        self._refresh()
        self._save(f"Note {idx + 1} edited.")

    def delete_note(self) -> None:
        from tkinter import messagebox  # pylint: disable=import-outside-toplevel

        idx = self._selected()
        if idx is None:
            self.status.set("Pick a note in the list first.")
            return
        label = "the whole-draft note" if idx == -1 else f"note {idx + 1}"
        with self._modal():
            sure = messagebox.askyesno("Delete note", f"Delete {label}?", parent=self.root)
        if not sure:
            return
        if idx == -1:
            self.session.review.set_whole(None)
        else:
            self.session.review.delete(idx)
        self._refresh()
        self._save(f"Deleted {label}.")

    def jump(self, _event=None) -> None:
        idx = self._selected()
        if idx is None or idx == -1:
            return
        anchor = self.session.review.notes[idx].anchor
        if not anchor:
            return
        (la, ca), (lb, cb) = anchor
        a, b = f"{la}.{ca}", f"{lb}.{cb}"
        self.text.see(a)
        if self._flash_timer is not None:  # an earlier jump's timer: restart it
            self.root.after_cancel(self._flash_timer)
        self.text.tag_remove("flash", "1.0", self.tk.END)
        self.text.tag_add("flash", a, b)
        self._flash_timer = self.root.after(900, self._end_flash)

    def _end_flash(self) -> None:
        self._flash_timer = None
        self.text.tag_remove("flash", "1.0", self.tk.END)

    def decide(self, decision: str) -> None:
        self.session.review.decide(decision)
        self._save(f"Decision recorded: {decision}. Close the window when done.")

    def _ask_decision(self) -> Optional[str]:
        tk = self.tk
        # Inside _modal() from the start: building and showing the dialog runs
        # the event loop, and a close then must not open a second one.
        with self._modal():
            dialog = tk.Toplevel(self.root)
            dialog.title("Close without a decision?")
            dialog.transient(self.root)
            tk.Label(dialog, text="No decision recorded. Close with:", padx=12, pady=8).pack()
            choice: Dict[str, Optional[str]] = {"value": None}

            def pick(value: str) -> None:
                choice["value"] = value
                dialog.destroy()

            row = tk.Frame(dialog)
            for label, value in (
                ("Approve", "approve"),
                ("Changes requested", "changes requested"),
                ("Just close (notes only)", "none (notes only)"),
            ):
                tk.Button(row, text=label, command=lambda v=value: pick(v)).pack(
                    side=tk.LEFT, padx=4, pady=8
                )
            row.pack(padx=8)
            self._run_dialog(dialog)
        return choice["value"]

    def on_close(self) -> None:
        if self._modal_depth:  # a dialog is open: finish or cancel it first
            return
        decision = self.session.review.decision or self._ask_decision()
        if decision is None:  # the dialog was dismissed: keep reviewing
            return
        self._closing = True
        try:
            self.session.finish(decision)
        except OSError as exc:
            self._closing = False
            self._close_failed(one_line(str(exc)))
            return
        self.root.destroy()

    def _close_failed(self, reason: str) -> None:
        """A save on close failed: keep the window open unless the owner insists."""
        from tkinter import messagebox  # pylint: disable=import-outside-toplevel

        self.status.set(f"NOT SAVED on close: {reason}. Close again to retry.")
        with self._modal():
            give_up = messagebox.askyesno(
                "Notes not saved",
                f"Could not save on close:\n{reason}\n\n"
                "Close anyway? The notes file may not hold the decision, "
                "and the viewer exits with an error.",
                default="no",
                parent=self.root,
            )
        if give_up:
            self.failed = f"could not save on close: {reason}"
            print(f"review_viewer: {self.failed}", file=sys.stderr)
            self.root.destroy()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


class _Parser(argparse.ArgumentParser):
    """argparse exits 2 on a usage error; 2 here means "no window": exit 1."""

    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(1, f"{self.prog}: error: {message}\n")


def build_parser() -> argparse.ArgumentParser:
    parser = _Parser(
        prog="review_viewer.py",
        description="Review a draft in a local window and leave line-anchored notes.",
        epilog=NOTES_FORMAT + "\n\n" + CHAT_FALLBACK,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("draft", type=Path, help="the draft to review (Markdown or text)")
    parser.add_argument(
        "--notes", type=Path, help="notes file (default: <draft>.notes.md beside the draft)"
    )
    parser.add_argument(
        "--previous",
        type=Path,
        help="diff against this file instead of the last round's .reviewed snapshot",
    )
    return parser


def _import_tkinter():
    import tkinter  # pylint: disable=import-outside-toplevel

    return tkinter


def _resolve(path: Path, what: str) -> Path:
    try:
        return path.resolve()
    except (OSError, RuntimeError) as exc:  # a symlink loop is RuntimeError up to 3.12
        raise UsageError(f"cannot resolve {what} {path}: {one_line(str(exc))}") from exc


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        draft = _resolve(args.draft, "draft")
        notes_path = _resolve(args.notes or Path(str(draft) + ".notes.md"), "--notes path")
        previous = _resolve(args.previous, "--previous file") if args.previous else None
        session = Session(draft, notes_path, previous)
    except UsageError as exc:
        print(f"review_viewer: {exc}", file=sys.stderr)
        return 1
    except (OSError, RuntimeError) as exc:  # e.g. a folder that may not be searched
        print(f"review_viewer: cannot use the given paths: {one_line(str(exc))}", file=sys.stderr)
        return 1

    reason = check_display(os.environ, _import_tkinter)
    if reason is not None:
        print(f"review_viewer: {reason}; review in chat instead (see --help)", file=sys.stderr)
        return 2
    tk = _import_tkinter()
    try:
        root = tk.Tk()
    except tk.TclError as exc:
        print(
            f"review_viewer: cannot open a window ({one_line(str(exc))}); "
            "review in chat instead (see --help)",
            file=sys.stderr,
        )
        return 2
    app = ViewerApp(root, session)
    root.mainloop()
    return 1 if app.failed else 0


if __name__ == "__main__":
    sys.exit(main())
