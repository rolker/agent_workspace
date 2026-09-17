#!/usr/bin/env python3
"""Extract entries from a work-plan ``progress.md`` as JSON.

Ported from ros2_agent_workspace's ``.agent/scripts/progress_read.py``
(issue #269 PR A) — see
``docs/decisions/0013-progress-md-entry-type-vocabulary.md``.

``progress.md`` files (``.agent/work-plans/issue-<N>/progress.md``) are the
per-issue lifecycle timeline. Each entry is a ``## <Entry Type>`` section
following the ADR-0013 schema. This tool parses those entries into structured
JSON so consumers — notably the ``triage-reviews`` integrator and
``merge_pr.sh``'s Layer-1 merge gate (issue #269 PR F) — can filter by entry
type and correlation key without re-parsing markdown.

Usage::

    python3 .agent/scripts/progress_read.py <progress.md> [--type "Entry Type"] ...

Output (stdout) is a JSON object::

    {"file": <path>, "issue": <N or null>, "entries": [ <entry>, ... ]}

Each entry::

    {
      "type": "Plan Review",         # full heading text (may carry a suffix)
      "base_type": "Plan Review",    # canonical type (suffix stripped if non-canonical)
      "recognized": true,            # is base_type a canonical ADR-0013 type?
      "predecessor_of": null,        # "Integrated Review" for External Review
      "status": "complete",
      "when": "2026-05-25 15:27 -04:00",
      "when_has_offset": true,       # ADR-0013 requires an explicit offset
      "by": "...",
      "correlation": {...} or null,
      "findings": [ {"section","checked","source_hint","text"}, ... ]
    }

Correlation by entry type (ADR-0013 "Consume by entry-type filter"):

* ``Issue Review``                         -> ``{"kind":"issue","issue":N}``
* ``Plan Authored`` / ``Plan Review``      -> ``{"kind":"plan","path":..,"sha":..}``
* ``Local Review`` / ``Local Review (Pre-Push)`` / ``Integrated Review`` /
  ``External Review`` / ``Implementation`` / ``Merge (report-only)`` /
  ``Merge (unreviewed)`` -> ``{"kind":"pr","pr":N,"sha":..}`` or
  ``{"kind":"branch","branch":..,"sha":..}``
* ``Checkpoint`` -> ``None`` (no generic correlation key; see the ADR's
  ``## Checkpoint`` row — consumers check its required fields directly).

``--type`` filters the emitted entries to the given type(s), matching on the
full heading, the canonical ``base_type`` (so legacy suffixed headings like
``External Review (Round 5-6)`` match ``External Review``), and predecessor
recognition (filtering ``Integrated Review`` also returns ``External Review``
entries, since ADR-0013 recognizes the latter as the predecessor of the former).

Exit codes: 0 parsed; 1 path is not a file; 2 the file is malformed (an
unterminated code fence would hide every later entry, so the parser refuses
rather than returning a partial, misleading result).
"""

import argparse
import json
import re
import sys
from pathlib import Path

# Canonical entry types (ADR-0013 Decision table).
CANONICAL_TYPES = {
    "Issue Review",
    "Plan Authored",
    "Plan Review",
    "Local Review",
    "Local Review (Pre-Push)",
    "Integrated Review",
    "External Review",
    "Implementation",
    "Checkpoint",
    "Merge (report-only)",
    "Merge (unreviewed)",
}

# ADR-0013 "Predecessor recognition": new writes use the value, but historical
# entries under the key must still be consumed as that value's history.
PREDECESSOR_OF = {"External Review": "Integrated Review"}

# Types whose correlation key is a PR/branch head SHA.
_PR_BRANCH_TYPES = {
    "Local Review",
    "Local Review (Pre-Push)",
    "Integrated Review",
    "External Review",
    "Implementation",
    "Merge (report-only)",
    "Merge (unreviewed)",
}
_PLAN_TYPES = {"Plan Authored", "Plan Review"}
# "Checkpoint" is intentionally in neither set above: it has no generic
# correlation key (ADR-0013's Decision table row for it), so
# _parse_correlation's fallthrough (return None) applies.

# A level-2 heading that is not a level-3 (``### ``) heading.
_ENTRY_HEADING = re.compile(r"^## ([^#].*)$")
_SUBSECTION = re.compile(r"^### (.+)$")
_CHECKBOX = re.compile(r"^- \[([ xX])\]\s+(.*)$")
_LEADING_PAREN = re.compile(r"^\(([^)]*)\)")
_OFFSET = re.compile(r"(?:[+-]\d{2}:\d{2}|Z)$")
# Fenced code block delimiter (``` or ~~~, optionally indented / with info string).
# ASCII space/tab only (CommonMark fence indentation), and deliberately NOT
# ``\s``: Python's ``\s`` also matches NBSP and other Unicode whitespace, which
# the awk matchers in progress_append.sh and test_checkpoint_269.sh do not, so
# the three parsers would disagree on what is a fence (round-3 review).
_FENCE = re.compile(r"^[ \t]*(?:```|~~~)")


class MalformedProgressError(ValueError):
    """progress.md cannot be parsed safely (e.g. an unterminated code fence).

    Raised rather than returning a partial result: a consumer such as the
    merge gate must not mistake "parser stopped early" for "no such entry".
    The CLI maps it to exit code 2.
    """


def _canonical_base(heading):
    """Map a heading to its canonical ADR-0013 entry type.

    Returns the heading unchanged when it is already canonical (including
    ``Local Review (Pre-Push)``, whose parenthetical is part of the canonical
    name — but NOT ``Merge (report-only)``/``Merge (unreviewed)``, which are
    also canonical-as-is for the same reason). Otherwise strips a trailing
    ``(...)`` suffix and returns the base if that base is canonical — so
    legacy non-conformant headings like ``External Review (Round 5-6)`` are
    still recognized as ``External Review`` (and thus consumed as
    ``Integrated Review`` predecessors) rather than silently dropped by type
    filters. Falls back to the heading unchanged.
    """
    if heading in CANONICAL_TYPES:
        return heading
    match = re.match(r"^(.*?)\s*\([^)]*\)\s*$", heading)
    if match and match.group(1) in CANONICAL_TYPES:
        return match.group(1)
    return heading


def _field(header_lines, name):
    """Return the value of ``**name**:`` found anywhere in the header lines.

    ADR-0013 fixes the field by name, not by line offset, so skill-specific
    fields may precede the canonical correlation field. Returns ``None`` if
    absent.
    """
    pattern = re.compile(r"^\*\*" + re.escape(name) + r"\*\*:\s*(.*)$")
    for line in header_lines:
        match = pattern.match(line.strip())
        if match:
            return match.group(1).strip()
    return None


def _strip_ticks(value):
    return value.strip().strip("`").strip()


def _corr_issue(header_lines):
    raw = _field(header_lines, "Issue")
    match = re.search(r"#?(\d+)", raw) if raw else None
    return {"kind": "issue", "issue": int(match.group(1))} if match else None


def _corr_plan(header_lines):
    raw = _field(header_lines, "Plan")
    # `<path>` at `<sha>`
    match = re.match(r"`?(.+?)`?\s+at\s+`?([0-9a-fA-F]+)`?$", raw) if raw else None
    if not match:
        return None
    return {
        "kind": "plan",
        "path": _strip_ticks(match.group(1)),
        "sha": match.group(2),
    }


def _corr_pr_or_branch(header_lines):
    """``**PR**: #N at `sha``` or, as the alternative, ``**Branch**: <name> at
    `sha```."""
    raw = _field(header_lines, "PR")
    if raw:
        match = re.search(r"#(\d+)\s+at\s+`?([0-9a-fA-F]+)`?", raw)
        if match:
            return {"kind": "pr", "pr": int(match.group(1)), "sha": match.group(2)}
    raw = _field(header_lines, "Branch")
    if raw:
        match = re.match(r"(\S+)\s+at\s+`?([0-9a-fA-F]+)`?", raw)
        if match:
            return {
                "kind": "branch",
                "branch": match.group(1),
                "sha": match.group(2),
            }
    return None


def _parse_correlation(entry_type, header_lines):
    """Extract the correlation key appropriate to ``entry_type`` (ADR-0013)."""
    if entry_type == "Issue Review":
        return _corr_issue(header_lines)
    if entry_type in _PLAN_TYPES:
        return _corr_plan(header_lines)
    if entry_type in _PR_BRANCH_TYPES:
        return _corr_pr_or_branch(header_lines)
    return None


def _parse_findings(body_lines, linenos=None):
    """Collect checkbox items appearing under a ``### `` sub-section of an entry.

    Checkboxes before the first sub-section header are ignored: ADR-0013 places
    findings/actions checkbox lists under `### Findings` / `### Actions` /
    `### Open questions`, so a stray checkbox in the header area is not a finding.
    """
    findings = []
    section = None
    if linenos is None:
        linenos = [None] * len(body_lines)
    for line, lineno in zip(body_lines, linenos):
        sub = _SUBSECTION.match(line)
        if sub:
            section = sub.group(1).strip()
            continue
        box = _CHECKBOX.match(line)
        if box and section is not None:
            text = box.group(2).strip()
            hint = _LEADING_PAREN.match(text)
            findings.append(
                {
                    "section": section,
                    "checked": box.group(1).lower() == "x",
                    "source_hint": hint.group(1) if hint else None,
                    "text": text,
                    # 1-based file line of the checkbox: the authoritative target
                    # for a writer that flips it (review_progress.sh check), so no
                    # second parser has to agree with this one.
                    "line": lineno,
                }
            )
    return findings


def _split_frontmatter(text):
    """Return (issue_number_or_None, body_without_frontmatter, line_offset).

    ``line_offset`` is how many lines were stripped before ``body`` starts, so
    body-relative line numbers + offset are file line numbers (1-based).
    """
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            front = text[3:end]
            # Only treat the block as YAML frontmatter if it actually contains a
            # `key:` line; otherwise a leading `---` horizontal rule with a later
            # `---` would swallow real body content.
            if re.search(r"^\s*[\w-]+:\s", front, re.MULTILINE):
                body = text[end + 4 :].lstrip("\n")
                match = re.search(r"^\s*issue:\s*(\d+)\s*$", front, re.MULTILINE)
                issue = int(match.group(1)) if match else None
                return issue, body, text.count("\n") - body.count("\n")
    return None, text, 0


def _split_entries(body):
    """Yield (heading, [lines], [body_line_numbers]) for each ``## `` entry block.

    Fence-aware: lines inside fenced code blocks are skipped entirely, so a
    ``## <Type>`` heading or checkbox quoted inside a ``` ```markdown ``` block
    (e.g. an embedded template or a quoted prior entry) does not produce a
    phantom entry. Downstream parsing (header fields, findings) therefore never
    sees fenced content.
    """
    entries = []
    current_heading = None
    current_lines = []
    current_linenos = []
    in_fence = False
    fence_open_line = None
    for lineno, line in enumerate(body.splitlines(), start=1):
        if _FENCE.match(line):
            in_fence = not in_fence
            fence_open_line = lineno if in_fence else None
            continue
        if in_fence:
            continue
        heading = _ENTRY_HEADING.match(line)
        if heading:
            if current_heading is not None:
                entries.append((current_heading, current_lines, current_linenos))
            current_heading = heading.group(1).strip()
            current_lines = []
            current_linenos = []
        elif current_heading is not None:
            current_lines.append(line)
            current_linenos.append(lineno)
    if in_fence:
        # Fence state spans the file, so an unterminated fence in ANY entry
        # would silently swallow every later heading — including a real
        # ``## Checkpoint`` the merge gate depends on. Fail loudly instead.
        raise MalformedProgressError(
            f"unterminated code fence opened at body line {fence_open_line}; "
            "every later entry would be hidden — close the fence in progress.md"
        )
    if current_heading is not None:
        entries.append((current_heading, current_lines, current_linenos))
    return entries


def parse_progress(text, path=None):
    """Parse ``progress.md`` text into the JSON-able dict described in the
    module docstring."""
    issue, body, offset = _split_frontmatter(text)
    result = {"file": path, "issue": issue, "entries": []}

    for heading, lines, linenos in _split_entries(body):
        # Header lines run until the first ``### `` sub-section.
        header_lines = []
        for line in lines:
            if _SUBSECTION.match(line):
                break
            header_lines.append(line)

        when = _field(header_lines, "When")
        base = _canonical_base(heading)
        entry = {
            "type": heading,
            "base_type": base,
            "recognized": base in CANONICAL_TYPES,
            "predecessor_of": PREDECESSOR_OF.get(base),
            "status": _field(header_lines, "Status"),
            "when": when,
            "when_has_offset": bool(when and _OFFSET.search(when.strip())),
            "by": _field(header_lines, "By"),
            "correlation": _parse_correlation(base, header_lines),
            "findings": _parse_findings(lines, [n + offset for n in linenos]),
        }
        result["entries"].append(entry)

    return result


def _matches_type(entry, wanted):
    """True if ``entry`` should be emitted for the ``--type`` filter.

    Matches on the full heading, on the canonical base type (so legacy
    suffixed headings like ``External Review (Round 5-6)`` match
    ``External Review``), and on predecessor recognition (requesting
    ``Integrated Review`` also matches ``External Review`` entries).
    """
    if entry["type"] in wanted or entry.get("base_type") in wanted:
        return True
    return entry["predecessor_of"] in wanted


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("path", help="path to a progress.md file")
    parser.add_argument(
        "--type",
        action="append",
        default=[],
        dest="types",
        metavar="ENTRY_TYPE",
        help="filter to this entry type (repeatable); Integrated Review also "
        "matches External Review predecessors",
    )
    args = parser.parse_args(argv)

    path = Path(args.path)
    if not path.is_file():
        print(f"error: not a file: {path}", file=sys.stderr)
        return 1

    try:
        result = parse_progress(path.read_text(encoding="utf-8"), path=str(path))
    except MalformedProgressError as exc:
        print(f"error: {path}: {exc}", file=sys.stderr)
        return 2
    if args.types:
        wanted = set(args.types)
        result["entries"] = [e for e in result["entries"] if _matches_type(e, wanted)]

    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
