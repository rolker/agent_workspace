"""The tool's own documents are written for anyone who uses it, so they do not name the
workspace's own caller of the tool: its `ros2_colcon` project-type adapter, the workspace's
`.agent/` scripts, or "the adapter" as if there were one. The word "adapter" in a general sense
("an adapter", "adapters") is allowed. This guards against the design being written around one
caller, as it once was."""

import re
from pathlib import Path

import pytest

TOOL = Path(__file__).parent.parent
DOCUMENTS = [TOOL / "README.md"] + sorted((TOOL / "docs").glob("*.md"))

# Each names the workspace's adapter, or one adapter as the caller.
NAMING_THE_WORKSPACE_ADAPTER = [
    r"ros2_colcon",
    r"\.agent/",
    r"project[- ]type adapter",
    r"workspace(?:'s)? adapter",
    r"\bthe adapter\b",
]


@pytest.mark.parametrize("path", DOCUMENTS, ids=lambda p: p.name)
def test_a_document_does_not_name_the_workspaces_adapter(path):
    text = path.read_text(encoding="utf-8")
    for pattern in NAMING_THE_WORKSPACE_ADAPTER:
        found = re.search(pattern, text, re.IGNORECASE)
        assert found is None, f"{path.name} names the workspace's adapter: {found.group(0)!r}"


@pytest.mark.parametrize(
    "text,named",
    [
        ("The ros2_colcon adapter reads it.", True),
        ("See .agent/scripts/x.sh.", True),
        ("The adapter reads layers.txt.", True),
        ("the workspace's adapter", True),
        ("A project-type adapter calls it.", True),
        ("A caller can write an adapter for its own build tool.", False),
        ("Adapters for other build tools are welcome.", False),
    ],
)
def test_the_rule_bans_naming_the_adapter_not_the_word(text, named):
    found = any(re.search(p, text, re.IGNORECASE) for p in NAMING_THE_WORKSPACE_ADAPTER)
    assert found is named
