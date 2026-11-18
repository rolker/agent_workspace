"""The tool's own documents are written for anyone who uses it: they do not name a particular
caller's adapter."""

from pathlib import Path

import pytest

TOOL = Path(__file__).parent.parent
# prototype.md describes the earlier reader and goes with it.
DOCUMENTS = [TOOL / "README.md"] + [
    p for p in sorted((TOOL / "docs").glob("*.md")) if p.name != "prototype.md"
]


@pytest.mark.parametrize("path", DOCUMENTS, ids=lambda p: p.name)
def test_a_document_does_not_name_a_callers_adapter(path):
    text = path.read_text(encoding="utf-8").lower()
    for word in ("ros2_colcon", "adapter"):
        assert word not in text, f"{path.name} names {word!r}"
