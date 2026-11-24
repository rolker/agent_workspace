"""Tests for review_viewer.py (issue #545).

Everything the window does is tested here without a window: the notes file
format and its round trip, line ranges from a selection, the light
formatting (spans and table alignment), the passage quoted from the file
text, changes since the last round, the snapshot and .prev files, the
display check, and the CLI exits (1 for a missing file, 2 with one line and
no traceback when no window can open). A build of the window itself runs
only under xvfb-run, and is skipped with a message when that is absent.

Run with: python3 -m unittest test_review_viewer  (from this directory)
or via the .agent/scripts/tests/test_review_viewer.sh wrapper.
"""

import datetime
import io
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPTS))
import review_viewer as rv  # noqa: E402

SCRIPT = str(SCRIPTS / "review_viewer.py")

TABLE_DRAFT = """\
# Plan

| Step | Owner |
|------|-------|
| one | host |
| two | owner |

Done.
"""


class TempDirTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()  # pylint: disable=consider-using-with
        self.dir = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()


class SplitLinesTest(unittest.TestCase):
    def test_newline_only(self):
        self.assertEqual(rv.split_lines("a\fb\nc\n"), ["a\fb", "c"])

    def test_crlf_and_no_trailing_newline(self):
        self.assertEqual(rv.split_lines("a\r\nb"), ["a", "b"])

    def test_empty(self):
        self.assertEqual(rv.split_lines(""), [])

    def test_blank_last_line_kept(self):
        self.assertEqual(rv.split_lines("a\n\n"), ["a", ""])


class SelectionRangeTest(unittest.TestCase):
    def test_single_line(self):
        self.assertEqual(rv.selection_to_range((3, 2), (3, 9)), (3, 3))

    def test_multi_line(self):
        self.assertEqual(rv.selection_to_range((3, 2), (5, 4)), (3, 5))

    def test_ending_at_column_zero_ends_on_previous_line(self):
        self.assertEqual(rv.selection_to_range((3, 0), (4, 0)), (3, 3))

    def test_column_zero_same_line_is_not_moved(self):
        self.assertEqual(rv.selection_to_range((3, 0), (3, 0)), (3, 3))

    def test_parse_index(self):
        self.assertEqual(rv.parse_index("12.7"), (12, 7))


class LightFormatTest(unittest.TestCase):
    def tags(self, text, line):
        return {s[3]: (s[1], s[2]) for s in rv.light_format(text).spans if s[0] == line}

    def test_heading_with_nested_bold(self):
        tags = self.tags("## A **b** c\n", 1)
        self.assertEqual(tags["heading"], (0, 12))
        self.assertEqual(tags["bold"], (5, 10))

    def test_italic_and_snake_case(self):
        spans = rv.light_format("an *it* and _u_ but snake_case_name\n").spans
        italics = [(a, b) for _, a, b, t in spans if t == "italic"]
        self.assertEqual(italics, [(3, 7), (12, 15)])

    def test_bold_is_not_italic(self):
        tags = [s[3] for s in rv.light_format("**b**\n").spans]
        self.assertEqual(tags, ["bold"])

    def test_inline_code_hides_inner_markup(self):
        spans = rv.light_format("x `a **b** c` y\n").spans
        self.assertEqual([(s[1], s[2], s[3]) for s in spans], [(2, 13, "code")])

    def test_code_fence_lines_are_code_and_unstyled(self):
        text = "```\n# not a heading\n| not | table |\n```\nafter **b**\n"
        fmt = rv.light_format(text)
        self.assertEqual(fmt.lines, rv.split_lines(text))
        by_line = {}
        for line, _a, _b, tag in fmt.spans:
            by_line.setdefault(line, []).append(tag)
        self.assertEqual(by_line, {1: ["code"], 2: ["code"], 3: ["code"], 4: ["code"], 5: ["bold"]})

    def test_tilde_fence_needs_matching_close(self):
        text = "~~~~\n```\nstill code\n~~~~\nplain\n"
        tags = {s[0]: s[3] for s in rv.light_format(text).spans}
        self.assertEqual(tags.get(3), "code")
        self.assertNotIn(5, tags)

    def test_inline_triple_backticks_open_no_fence(self):
        text = "```x``` is inline code\n# heading\n"
        self.assertEqual(rv.fenced_lines(rv.split_lines(text)), [False, False])
        tags = {s[0]: s[3] for s in rv.light_format(text).spans if s[3] == "heading"}
        self.assertEqual(tags, {2: "heading"})

    def test_info_string_line_does_not_close_a_fence(self):
        text = "```\n```python\nstill code\n```\nafter\n"
        self.assertEqual(rv.fenced_lines(rv.split_lines(text)), [True] * 4 + [False])

    def test_tilde_fence_may_hold_backticks_in_info(self):
        text = "~~~ a`b\ncode\n~~~\nplain\n"
        self.assertEqual(rv.fenced_lines(rv.split_lines(text)), [True, True, True, False])

    def test_four_space_indent_is_no_fence(self):
        self.assertEqual(rv.fenced_lines(["    ```", "x"]), [False, False])

    def test_table_alignment_with_uneven_cells(self):
        fmt = rv.light_format(TABLE_DRAFT)
        rows = fmt.lines[2:6]
        self.assertEqual(
            rows,
            [
                "| Step | Owner |",
                "| ---- | ----- |",
                "| one  | host  |",
                "| two  | owner |",
            ],
        )
        pipes = {tuple(i for i, ch in enumerate(r) if ch == "|") for r in rows}
        self.assertEqual(len(pipes), 1, "pipes must line up in every row")
        self.assertEqual(len(fmt.lines), len(rv.split_lines(TABLE_DRAFT)))

    def test_separator_keeps_alignment_colons(self):
        fmt = rv.light_format("| a | b | c |\n|:-|-:|:-:|\n")
        self.assertEqual(fmt.lines[1], "| :-- | --: | :-: |")

    def test_dash_data_cell_is_not_a_separator(self):
        fmt = rv.light_format("| a | b |\n|---|---|\n| x | - |\n")
        self.assertEqual(fmt.lines, ["| a   | b   |", "| --- | --- |", "| x   | -   |"])

    def test_escaped_pipe_stays_in_cell(self):
        fmt = rv.light_format("| a\\|b | c |\n| x | y |\n")
        self.assertEqual(fmt.lines, ["| a\\|b | c   |", "| x    | y   |"])

    def test_unchanged_lines_have_no_column_map(self):
        fmt = rv.light_format("plain\n| a | b |\n")
        self.assertIsNone(fmt.colmaps[0])
        self.assertEqual(fmt.to_raw_col(1, 3), 3)


class PassageTest(unittest.TestCase):
    """F1: a quoted passage is the file's own text, never the padded display."""

    def test_table_cell_selection_maps_to_file_text(self):
        fmt = rv.light_format(TABLE_DRAFT)
        disp = fmt.lines[4]  # "| one  | host  |"
        start = disp.index("one")
        end = disp.index("host") + len("host")
        passage = rv.passage_text(TABLE_DRAFT, fmt, (5, start), (5, end))
        self.assertEqual(passage, "one | host")
        self.assertIn(passage, TABLE_DRAFT)

    def test_selection_into_padding_stops_at_cell_end(self):
        fmt = rv.light_format(TABLE_DRAFT)
        passage = rv.passage_text(TABLE_DRAFT, fmt, (5, 0), (5, len(fmt.lines[4])))
        self.assertEqual(passage, "| one | host |")

    def test_multi_line_whole_lines(self):
        fmt = rv.light_format(TABLE_DRAFT)
        passage = rv.passage_text(TABLE_DRAFT, fmt, (5, 0), (7, 0))
        self.assertEqual(passage, "| one | host |\n| two | owner |")

    def test_trailing_blank_line_in_range_is_quoted(self):
        """Lines 1-3 with blank line 3 quote three lines, not two."""
        text = "a\nb\n\nc\n"
        fmt = rv.light_format(text)
        passage = rv.passage_text(text, fmt, (1, 0), (4, 0))
        self.assertEqual(passage, "a\nb\n")
        self.assertEqual(rv.selection_to_range((1, 0), (4, 0)), (1, 3))
        self.assertEqual(len(passage.split("\n")), 3)

    def test_selection_ending_mid_line_keeps_its_text(self):
        text = "a\n\nbc\n"
        fmt = rv.light_format(text)
        self.assertEqual(rv.passage_text(text, fmt, (1, 0), (3, 1)), "a\n\nb")

    def test_selection_to_tk_end_is_clamped(self):
        text = "a\nbc\n"
        fmt = rv.light_format(text)
        self.assertEqual(rv.passage_text(text, fmt, (2, 0), (3, 0)), "bc")


class NotesFormatTest(unittest.TestCase):
    WHEN = datetime.datetime(2026, 11, 23, 12, 0, tzinfo=datetime.timezone.utc)

    def review(self):
        review = rv.Review("plan.md")
        review.add(rv.Note(3, 4, "first line\n\nthird line", "Fix this.\nAnd that."))
        review.add(rv.Note(9, 9, "x", "Short."))
        review.set_whole("Overall fine.")
        return review

    def test_render_layout(self):
        review = self.review()
        review.decide("changes requested")
        out = rv.render_notes(review, self.WHEN)
        self.assertEqual(
            out,
            "# Review notes: plan.md\n\nWritten 2026-11-23T12:00:00+00:00\n\n"
            "**Decision**: changes requested\n\n"
            "## Note on the whole draft\n\nOverall fine.\n\n"
            "## Note 1 (lines 3-4)\n\n> first line\n>\n> third line\n\nFix this.\nAnd that.\n\n"
            "## Note 2 (lines 9-9)\n\n> x\n\nShort.\n",
        )

    def test_no_decision_line_while_undecided(self):
        self.assertNotIn("**Decision**", rv.render_notes(self.review(), self.WHEN))

    def test_round_trip_each_decision(self):
        for decision in rv.DECISIONS:
            with self.subTest(decision=decision):
                review = self.review()
                review.decide(decision)
                back = rv.parse_notes(rv.render_notes(review, self.WHEN))
                self.assertEqual(back, review)

    def test_round_trip_without_whole_note(self):
        review = rv.Review("d.md")
        review.add(rv.Note(1, 2, "> already quoted", "n"))
        self.assertEqual(rv.parse_notes(rv.render_notes(review)), review)

    def test_unknown_decision_refused(self):
        with self.assertRaises(ValueError):
            rv.Review("d").decide("maybe")

    def test_edit_delete_and_whole_note(self):
        review = self.review()
        review.edit(1, "Changed.")
        self.assertEqual(review.notes[1].text, "Changed.")
        review.delete(0)
        self.assertEqual([n.text for n in review.notes], ["Changed."])
        review.set_whole("Replaced.")
        self.assertEqual(review.whole, "Replaced.")
        review.set_whole("  ")
        self.assertIsNone(review.whole)
        self.assertNotIn("whole draft", rv.render_notes(review))


class ChangedLinesTest(unittest.TestCase):
    def test_first_round_no_changes(self):
        self.assertEqual(rv.changed_lines("a\nb\n", "a\nb\n"), set())

    def test_replace_and_insert(self):
        self.assertEqual(rv.changed_lines("a\nb\nc\n", "a\nB\nc\nd\n"), {2, 4})

    def test_delete_marks_following_line(self):
        self.assertEqual(rv.changed_lines("a\nb\nc\n", "a\nc\n"), {2})

    def test_delete_at_end_marks_last_line(self):
        self.assertEqual(rv.changed_lines("a\nb\n", "a\n"), {1})

    def test_table_cell_change_marks_only_that_row(self):
        """F1: one wider cell re-pads the whole table display; only its row is marked."""
        new = TABLE_DRAFT.replace("| two | owner |", "| two | the owner himself |")
        old_disp = rv.light_format(TABLE_DRAFT).lines
        new_disp = rv.light_format(new).lines
        self.assertNotEqual(old_disp[2], new_disp[2], "fixture must re-pad other rows")
        self.assertEqual(rv.changed_lines(TABLE_DRAFT, new), {6})


class SnapshotPathTest(unittest.TestCase):
    def test_notes_suffix_replaced(self):
        self.assertEqual(rv.snapshot_path(Path("/r/plan.md.notes.md")), Path("/r/plan.md.reviewed"))

    def test_other_name_gets_suffix_appended(self):
        self.assertEqual(rv.snapshot_path(Path("/r/review.txt")), Path("/r/review.txt.reviewed"))

    def test_bare_suffix_name(self):
        self.assertEqual(rv.snapshot_path(Path("/r/.notes.md")), Path("/r/.notes.md.reviewed"))


class SessionTest(TempDirTest):
    """The window's actions, driven without the window."""

    def make(self, text=TABLE_DRAFT, notes=None, previous=None):
        draft = self.dir / "plan.md"
        draft.write_text(text, encoding="utf-8")
        notes = notes or Path(str(draft) + ".notes.md")
        return rv.Session(draft, notes, previous)

    def test_two_rounds_snapshot_is_raw_text(self):
        """F1: the snapshot holds the file text, so round two marks only the changed cell's row."""
        first = self.make()
        disp = first.formatted.lines[4]
        first.note_from_selection((5, disp.index("one")), (5, disp.index("host") + 4), "Who?")
        first.save()
        first.finish("changes requested")
        snapshot = self.dir / "plan.md.reviewed"
        self.assertEqual(snapshot.read_text(encoding="utf-8"), TABLE_DRAFT)
        notes = (self.dir / "plan.md.notes.md").read_text(encoding="utf-8")
        self.assertIn("## Note 1 (lines 5-5)\n\n> one | host\n\nWho?", notes)
        self.assertIn("**Decision**: changes requested", notes)

        second = self.make(TABLE_DRAFT.replace("| one | host |", "| one | the whole host team |"))
        self.assertEqual(second.changed, {5})
        self.assertEqual(second.previous_file, snapshot)
        self.assertEqual(second.review.notes, [], "old notes are not carried over")

    def test_first_round_has_no_previous(self):
        session = self.make()
        self.assertIsNone(session.previous_file)
        self.assertEqual(session.changed, set())

    def test_previous_overrides_snapshot(self):
        (self.dir / "plan.md.reviewed").write_text("unrelated\n", encoding="utf-8")
        other = self.dir / "older.md"
        other.write_text(TABLE_DRAFT.replace("Done.", "Not done."), encoding="utf-8")
        session = self.make(previous=other)
        self.assertEqual(session.changed, {8})
        self.assertEqual(session.previous_file, other)

    def test_missing_previous_is_usage_error(self):
        with self.assertRaises(rv.UsageError):
            self.make(previous=self.dir / "nope.md")

    def test_missing_draft_is_usage_error(self):
        with self.assertRaises(rv.UsageError):
            rv.Session(self.dir / "nope.md", self.dir / "n.notes.md")

    def test_stale_notes_renamed_to_prev_at_first_write_only(self):
        notes = self.dir / "plan.md.notes.md"
        notes.write_text("round one\n", encoding="utf-8")
        prev = self.dir / "plan.md.notes.md.prev"
        prev.write_text("round zero\n", encoding="utf-8")
        session = self.make()
        self.assertEqual(
            notes.read_text(encoding="utf-8"), "round one\n", "nothing moves at launch"
        )
        session.review.set_whole("x")
        session.save()
        self.assertEqual(prev.read_text(encoding="utf-8"), "round one\n", "one level, overwritten")
        session.review.set_whole("y")
        session.save()
        self.assertEqual(prev.read_text(encoding="utf-8"), "round one\n", "renamed once only")
        self.assertIn("y", notes.read_text(encoding="utf-8"))

    def test_notes_elsewhere_creates_folder_and_snapshot_beside_it(self):
        notes = self.dir / "reviews" / "plan.notes.md"
        session = self.make(notes=notes)
        session.finish("none (notes only)")
        self.assertIn("**Decision**: none (notes only)", notes.read_text(encoding="utf-8"))
        self.assertEqual(
            (self.dir / "reviews" / "plan.reviewed").read_text(encoding="utf-8"), TABLE_DRAFT
        )
        leftovers = [p.name for p in notes.parent.iterdir() if p.name.endswith(".tmp")]
        self.assertEqual(leftovers, [])


class CheckPathsTest(TempDirTest):
    """--notes may not write over the draft, --previous, or a folder."""

    def setUp(self):
        super().setUp()
        self.draft = self.dir / "plan.md"
        self.draft.write_text("x\n", encoding="utf-8")
        self.old = self.dir / "old.md"
        self.old.write_text("y\n", encoding="utf-8")

    def refused(self, notes, previous=None, needle=""):
        with self.assertRaises(rv.UsageError) as ctx:
            rv.check_paths(self.draft, notes, previous)
        self.assertIn(needle, str(ctx.exception))
        return str(ctx.exception)

    def test_default_and_elsewhere_are_fine(self):
        rv.check_paths(self.draft, Path(str(self.draft) + ".notes.md"))
        rv.check_paths(self.draft, self.dir / "sub" / "r.notes.md", self.old)

    def test_notes_is_the_draft(self):
        self.refused(self.draft, needle="notes file would overwrite the draft")

    def test_notes_through_another_spelling(self):
        self.refused(self.dir / "sub" / ".." / "plan.md", needle="overwrite the draft")

    def test_prev_is_the_draft(self):
        notes = self.dir / "plan"
        draft = self.dir / "plan.prev"
        draft.write_text("x\n", encoding="utf-8")
        with self.assertRaises(rv.UsageError) as ctx:
            rv.check_paths(draft, notes)
        self.assertIn(".prev file would overwrite the draft", str(ctx.exception))

    def test_snapshot_is_the_draft(self):
        draft = self.dir / "x.reviewed"
        draft.write_text("x\n", encoding="utf-8")
        with self.assertRaises(rv.UsageError) as ctx:
            rv.check_paths(draft, self.dir / "x.notes.md")
        self.assertIn("snapshot would overwrite the draft", str(ctx.exception))

    def test_notes_or_prev_is_previous(self):
        self.refused(self.old, self.old, needle="notes file would overwrite the --previous file")
        prev_target = self.dir / "n.md.prev"
        prev_target.write_text("z\n", encoding="utf-8")
        self.refused(
            self.dir / "n.md", prev_target, needle=".prev file would overwrite the --previous"
        )

    def test_snapshot_may_be_previous(self):
        snap = self.dir / "plan.md.reviewed"
        snap.write_text("x\n", encoding="utf-8")
        rv.check_paths(self.draft, Path(str(self.draft) + ".notes.md"), snap)

    def test_folders_refused(self):
        self.refused(self.dir, needle="--notes names a folder")
        self.refused(Path("/"), needle="--notes names a folder")
        (self.dir / "r.reviewed").mkdir()
        self.refused(self.dir / "r.notes.md", needle="snapshot path is a folder")
        (self.dir / "q.notes.md.prev").mkdir()
        self.refused(self.dir / "q.notes.md", needle=".prev file path is a folder")

    def test_draft_left_untouched_by_refused_session(self):
        with self.assertRaises(rv.UsageError):
            rv.Session(self.draft, self.draft)
        self.assertEqual(self.draft.read_text(encoding="utf-8"), "x\n")
        self.assertFalse(Path(str(self.draft) + ".prev").exists())


class DisplayCheckTest(unittest.TestCase):
    @staticmethod
    def ok():
        return object()

    @staticmethod
    def missing():
        raise ImportError("No module named '_tkinter'")

    def test_no_display_vars(self):
        reason = rv.check_display({}, self.ok, "linux")
        self.assertIn("no display", reason)

    def test_native_tk_platforms_skip_the_env_test(self):
        for platform in ("darwin", "win32"):
            with self.subTest(platform=platform):
                self.assertIsNone(rv.check_display({}, self.ok, platform))
                reason = rv.check_display({}, self.missing, platform)
                self.assertIn("tkinter is not available", reason)

    def test_x11(self):
        self.assertIsNone(rv.check_display({"DISPLAY": ":0"}, self.ok))

    def test_wayland_only(self):
        self.assertIsNone(rv.check_display({"WAYLAND_DISPLAY": "wayland-0"}, self.ok))

    def test_no_tkinter(self):
        reason = rv.check_display({"DISPLAY": ":0"}, self.missing)
        self.assertIn("tkinter is not available", reason)
        self.assertNotIn("\n", reason)

    def test_one_line(self):
        self.assertEqual(rv.one_line("\n  first\nsecond"), "first")


class CliTest(TempDirTest):
    def run_cli(self, args, env):
        base = {"PATH": os.environ.get("PATH", "/usr/bin:/bin")}
        base.update(env)
        return subprocess.run(
            [sys.executable, SCRIPT] + args,
            env=base,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )

    def draft(self):
        path = self.dir / "d.md"
        path.write_text("hello\n", encoding="utf-8")
        return path

    def assert_one_line(self, result, code, needle):
        self.assertEqual(result.returncode, code, result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(len(result.stderr.strip().splitlines()), 1, result.stderr)
        self.assertIn(needle, result.stderr)

    def test_no_display_exits_2(self):
        result = self.run_cli([str(self.draft())], {})
        self.assert_one_line(result, 2, "no display")
        self.assertFalse((self.dir / "d.md.notes.md").exists())

    def test_unreachable_display_exits_2(self):
        """F2: Tk() raising TclError (dead X display) exits 2, no traceback."""
        result = self.run_cli([str(self.draft())], {"DISPLAY": ":9999"})
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(len(result.stderr.strip().splitlines()), 1, result.stderr)
        self.assertIn("review in chat instead", result.stderr)

    def test_missing_draft_exits_1(self):
        result = self.run_cli([str(self.dir / "nope.md")], {})
        self.assert_one_line(result, 1, "draft not found")

    def test_missing_previous_exits_1(self):
        result = self.run_cli([str(self.draft()), "--previous", str(self.dir / "gone.md")], {})
        self.assert_one_line(result, 1, "--previous file not found")

    def test_notes_on_the_draft_exits_1(self):
        draft = self.draft()
        result = self.run_cli([str(draft), "--notes", str(draft)], {"DISPLAY": ":0"})
        self.assert_one_line(result, 1, "would overwrite the draft")
        self.assertEqual(draft.read_text(encoding="utf-8"), "hello\n")

    def test_unknown_option_exits_1_not_2(self):
        """2 is reserved for "no window"; argparse's own usage exit is 2."""
        result = self.run_cli([str(self.draft()), "--bogus", "x"], {})
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("unrecognized arguments", result.stderr)

    def test_no_draft_argument_exits_1(self):
        result = self.run_cli([], {})
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("required", result.stderr)

    def test_help_has_chat_fallback(self):
        result = self.run_cli(["--help"], {})
        self.assertEqual(result.returncode, 0)
        self.assertIn("cat -n", result.stdout)


class FakeRoot:  # pylint: disable=too-few-public-methods
    def __init__(self):
        self.destroyed = False

    def destroy(self):
        self.destroyed = True


class FakeVar:  # pylint: disable=too-few-public-methods
    def __init__(self):
        self.value = ""

    def set(self, value):
        self.value = value


class CloseAndErrorTest(TempDirTest):
    """The window's close and error paths, on an app built without a display."""

    def app(self, finish_error=None):
        draft = self.dir / "plan.md"
        draft.write_text("hello\n", encoding="utf-8")
        session = rv.Session(draft, Path(str(draft) + ".notes.md"))
        if finish_error is not None:

            def fail(_decision):
                raise finish_error

            session.finish = fail
        app = rv.ViewerApp.__new__(rv.ViewerApp)
        app.root, app.status, app.session = FakeRoot(), FakeVar(), session
        app.failed, app._closing = None, False  # pylint: disable=protected-access
        app._modal_depth = 0  # pylint: disable=protected-access
        session.review.decide("approve")
        return app

    def close(self, app, answer):
        with mock.patch("tkinter.messagebox.askyesno", return_value=answer) as ask:
            with mock.patch("sys.stderr", new_callable=io.StringIO) as err:
                app.on_close()
        return ask, err.getvalue()

    def test_close_saves_and_destroys(self):
        app = self.app()
        ask, _ = self.close(app, False)
        ask.assert_not_called()
        self.assertTrue(app.root.destroyed)
        self.assertIsNone(app.failed)
        self.assertTrue((self.dir / "plan.md.reviewed").exists())

    def test_close_ignored_while_a_dialog_is_open(self):
        app = self.app()
        with app._modal():  # pylint: disable=protected-access
            ask, _ = self.close(app, True)
        ask.assert_not_called()
        self.assertFalse(app.root.destroyed)
        self.assertFalse((self.dir / "plan.md.reviewed").exists())
        self.assertEqual(app._modal_depth, 0)  # pylint: disable=protected-access
        self.close(app, True)
        self.assertTrue(app.root.destroyed)

    def test_failed_save_keeps_window_open_with_status(self):
        app = self.app(OSError("No space left on device"))
        ask, err = self.close(app, False)
        ask.assert_called_once()
        self.assertFalse(app.root.destroyed)
        self.assertIn("NOT SAVED on close: No space left on device", app.status.value)
        self.assertIsNone(app.failed)
        self.assertEqual(err, "")
        self.assertFalse(app._closing)  # pylint: disable=protected-access

    def test_failed_save_close_anyway_marks_failure(self):
        app = self.app(OSError("read-only file system"))
        _, err = self.close(app, True)
        self.assertTrue(app.root.destroyed)
        self.assertIn("could not save on close", app.failed)
        self.assertIn("read-only file system", err)

    def callback_error(self, app):
        err = io.StringIO()
        try:
            raise KeyError("boom")
        except KeyError:
            with mock.patch("sys.stderr", err):
                app._callback_error(*sys.exc_info())  # pylint: disable=protected-access
        return err.getvalue()

    def test_callback_error_marks_failure_and_keeps_window(self):
        app = self.app()
        err = self.callback_error(app)
        self.assertIn("Traceback", err)
        self.assertIn("internal error: KeyError", app.failed)
        self.assertIn("INTERNAL ERROR", app.status.value)
        self.assertFalse(app.root.destroyed)

    def test_callback_error_while_closing_destroys(self):
        app = self.app()
        app._closing = True  # pylint: disable=protected-access
        self.callback_error(app)
        self.assertTrue(app.root.destroyed)


SMOKE = """\
import sys, tkinter
sys.path.insert(0, sys.argv[1])
import review_viewer as rv
from pathlib import Path
from unittest import mock
session = rv.Session(Path(sys.argv[2]), Path(sys.argv[2] + ".notes.md"))
root = tkinter.Tk()
app = rv.ViewerApp(root, session)
root.update()
session.note_from_selection((5, 2), (5, 5), "n")
app._refresh()
root.update()
root.destroy()
print("ok")
"""


class WindowSmokeTest(TempDirTest):
    def test_window_builds_under_xvfb(self):
        xvfb = shutil.which("xvfb-run")
        if not xvfb:
            self.skipTest("xvfb-run not installed; window build not exercised")
        draft = self.dir / "plan.md"
        draft.write_text(TABLE_DRAFT, encoding="utf-8")
        result = subprocess.run(
            [xvfb, "-a", sys.executable, "-c", SMOKE, str(SCRIPTS), str(draft)],
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ok", result.stdout)


if __name__ == "__main__":
    unittest.main()
