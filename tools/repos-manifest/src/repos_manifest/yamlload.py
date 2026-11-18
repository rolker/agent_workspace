"""Loading a manifest's YAML safely, and the character rules for its text.

Shared by both readers: the earlier one (``schema.py``) and the one for the format in
``docs/spec.md`` (``manifest.py``). Loading never runs code: the loader is PyYAML's safe loader,
which also refuses aliases and repeated keys.
"""

from __future__ import annotations

import unicodedata

import yaml


class ManifestError(Exception):
    """A manifest file (or a chain of them) is invalid."""


# Characters no key or value may hold: control characters (newline, carriage return, tab, NUL,
# DEL, NEL, ...), line and paragraph separators, invisible format characters (zero-width
# spaces, the byte-order mark, bidirectional overrides such as U+202E) and any space other than
# the ASCII one (no-break space and friends).
_UNSAFE_CATEGORIES = ("Cc", "Cf", "Zl", "Zp")


def has_unsafe_char(text: str) -> bool:
    """True if `text` holds a character that can split a line or hide what a line says."""
    return any(
        unicodedata.category(ch) in _UNSAFE_CATEGORIES
        or (unicodedata.category(ch) == "Zs" and ch != " ")
        for ch in text
    )


# What a whole file's text may hold that a value may not: the ends of lines and a tab.
_TEXT_ALLOWED = frozenset("\n\r\t")


def first_unsafe_in_text(text: str):
    """The first character of a whole file's text, comments included, that is a control
    character, invisible or changes the direction of text, as ``(line, column, code point)``;
    None if there is none. Newline, carriage return and tab are allowed here."""
    line, column = 1, 1
    for ch in text:
        if ch not in _TEXT_ALLOWED and has_unsafe_char(ch):
            return line, column, f"U+{ord(ch):04X}"
        if ch == "\n":
            line, column = line + 1, 1
        else:
            column += 1
    return None


_UNSAFE_WHAT = (
    "a control or invisible character (newline, carriage return, a zero-width or bidirectional"
    " character, a non-ASCII space or similar)"
)


class _RefusedYAML(yaml.YAMLError):
    """A YAML construct this loader refuses. `reason` is fixed text, never document content."""

    def __init__(self, reason: str, mark):
        super().__init__(reason)
        self.reason = reason
        self.problem_mark = mark


class _ManifestLoader(yaml.SafeLoader):
    """`yaml.SafeLoader` that refuses aliases (no recursion, no alias bombs; manifests do not
    need them) and duplicate mapping keys (a reader would see one entry, the resolver use the
    other)."""

    def compose_node(self, parent, index):
        if self.check_event(yaml.AliasEvent):
            raise _RefusedYAML("aliases (*name) are not allowed", self.peek_event().start_mark)
        return super().compose_node(parent, index)

    def construct_mapping(self, node, deep=False):
        if isinstance(node, yaml.MappingNode):
            seen = set()
            for key_node, _ in node.value:
                key = self.construct_object(key_node, deep=True)
                try:
                    if key in seen:
                        raise _RefusedYAML("a mapping repeats a key", key_node.start_mark)
                    seen.add(key)
                except TypeError:
                    continue  # an unhashable key: the base class refuses it
        return super().construct_mapping(node, deep)

    def construct_yaml_int(self, node):
        # PyYAML builds a hex, octal or binary integer of any length, outside Python's
        # 4300-digit limit; the first repr() or f-string of it then raises ValueError.
        value = super().construct_yaml_int(node)
        if value.bit_length() > _INT_BITS_MAX:
            raise _RefusedYAML("a number too large", node.start_mark)
        return value


# No manifest field needs a number past 64 bits.
_INT_BITS_MAX = 64
_ManifestLoader.add_constructor("tag:yaml.org,2002:int", _ManifestLoader.construct_yaml_int)


def _load_yaml(text: str, source: str):
    """Load one document. A failure is reported with fixed text and a position only: PyYAML's
    own messages quote document content (a line, a tag), which may hold a secret."""
    try:
        return yaml.load(text, Loader=_ManifestLoader)  # noqa: S506 (a SafeLoader subclass)
    except _RefusedYAML as exc:
        mark = exc.problem_mark
        raise ManifestError(
            f"{source}: invalid YAML at line {mark.line + 1}, column {mark.column + 1}:"
            f" {exc.reason}"
        ) from None
    except yaml.YAMLError as exc:
        mark = getattr(exc, "problem_mark", None)
        where = f" at line {mark.line + 1}, column {mark.column + 1}" if mark else ""
        raise ManifestError(f"{source}: invalid YAML{where}") from None
    except RecursionError:
        raise ManifestError(f"{source}: invalid YAML: nested too deeply") from None
    except Exception:
        # PyYAML's constructor lets Python's own errors through, not as a YAMLError: `!!float x`
        # and `!!int 0xx` raise ValueError, `!!bool x` KeyError, `2024-13-45` ValueError. Their
        # text quotes the value, and so would a traceback.
        raise ManifestError(f"{source}: invalid YAML") from None


def _refuse_unsafe_chars(node, source: str, where: str) -> None:
    """Every string in the document, key or value, must be one line of plain text. The message
    names where the string is and never echoes it (it may be a URL that carries a secret)."""
    if isinstance(node, dict):
        for key, value in node.items():
            if isinstance(key, str) and has_unsafe_char(key):
                raise ManifestError(
                    f"{source}: a key under {where or 'the top level'} contains {_UNSAFE_WHAT};"
                    " names must be one line of plain text"
                )
            _refuse_unsafe_chars(value, source, f"{where}.{key}" if where else str(key))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            _refuse_unsafe_chars(value, source, f"{where}[{index}]")
    elif isinstance(node, str) and has_unsafe_char(node):
        raise ManifestError(
            f"{source}: {where} contains {_UNSAFE_WHAT}; values must be one line of plain text"
        )
