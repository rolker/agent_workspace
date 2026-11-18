"""Reading a manifest and the manifests it builds on through `base`.

The order of reading, from "How manifests combine" in ``docs/spec.md``: a manifest's parents in
the order it names them, each after its own parents, then the manifest itself. Each manifest is
read once, the first time it is reached; a manifest that builds on itself, directly or through
others, is an error that names the chain.

This version reads a location given as a path on the local disk. A relative path is taken from
the directory of the manifest that names it, after following links. A manifest is identified by
its real path (links followed), which is also how it is named as a parent in messages and in
the head comment of the output, so one file reached by two paths is one manifest.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Dict, List, Optional

from .combine import merge_parts
from .manifest import Manifest, Part, _read_text, parse_part
from .yamlload import ManifestError

# The most manifests one resolve reads, the one asked for included.
MAX_MANIFESTS = 64


def parse_manifest(text: str, source: str) -> Manifest:
    """Check the text of a manifest that stands on its own. A `base` is refused: there is no
    file for a relative path to be taken from."""
    part = parse_part(text, source)
    if part.base:
        raise ManifestError(
            f"{source}: base: this version of the tool cannot read `base` in a manifest given"
            " as text; it reads it in a manifest read from a file"
        )
    return merge_parts([part])


def load_manifest(path: Path, source: Optional[str] = None) -> Manifest:
    """Read the manifest at `path` and every manifest it builds on, and combine them. `source`
    names the manifest in messages and output (default: the path as given)."""
    label = source if source is not None else str(path)
    reader = _Reader()
    reader.visit(os.path.realpath(path), label, _read_text(Path(path), label))
    return merge_parts(reader.parts, [part.source for part in reader.parts[:-1]])


class _Reader:
    """Reads a chain depth first and keeps the parts in reading order."""

    def __init__(self) -> None:
        self.parts: List[Part] = []
        self.done: Dict[str, Part] = {}
        self.active: List[str] = []  # real paths of the manifests being read, the leaf first
        self.labels: Dict[str, str] = {}

    def visit(self, real: str, label: str, text: str) -> None:
        self.active.append(real)
        self.labels[real] = label
        part = parse_part(text, label)
        directory = os.path.dirname(real)
        for where, written in part.base:
            parent = os.path.realpath(os.path.join(directory, written))
            if parent in self.active:
                chain = self.active[self.active.index(parent) :] + [parent]
                raise ManifestError(
                    f"{label}: {where}: a manifest builds on itself: "
                    + " -> ".join(self.labels[step] for step in chain)
                )
            if parent in self.done:
                continue
            if len(self.done) + len(self.active) >= MAX_MANIFESTS:
                raise ManifestError(
                    f"{label}: {where}: {parent}: more than {MAX_MANIFESTS} manifests would be"
                    f" read through `base`; at most {MAX_MANIFESTS} are"
                )
            self.visit(parent, parent, _read_text(Path(parent), f"{label}: {where}: {parent}"))
        self.active.pop()
        self.done[real] = part
        self.parts.append(part)
