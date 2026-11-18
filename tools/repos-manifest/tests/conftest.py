import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

FIXTURES = Path(__file__).parent / "fixtures"

# The directory of the Python running the tests is appended to PATH, so a `vcs` installed with
# the test extra is found when its environment is not activated; a `vcs` already on PATH wins.
_TEST_PATH = os.pathsep.join([os.environ.get("PATH", ""), os.path.dirname(sys.executable)])


def _vcs_line() -> str:
    vcs = shutil.which("vcs", path=_TEST_PATH)
    if vcs is None:
        return "vcs: not found (install vcs2l or vcstool)"
    done = subprocess.run(
        [vcs, "--version"], capture_output=True, text=True, check=False, env={**os.environ}
    )
    version = done.stdout.strip().splitlines()[-1] if done.stdout.strip() else "?"
    return f"vcs: {vcs} ({version})"


def pytest_report_header(config):
    return _vcs_line()


@pytest.fixture
def fixtures_dir() -> Path:
    return FIXTURES


@pytest.fixture
def vcs(monkeypatch, tmp_path):
    """For a test that clones: `vcs` found on PATH, or the test fails saying what to install;
    git reads no configuration of the person running the tests."""
    monkeypatch.setenv("PATH", _TEST_PATH)
    if shutil.which("vcs") is None:
        pytest.fail(
            "no `vcs` on PATH: install vcs2l or vcstool"
            " (pip install -e tools/repos-manifest[test])"
        )
    monkeypatch.setenv("GIT_CONFIG_GLOBAL", os.devnull)
    monkeypatch.setenv("GIT_CONFIG_NOSYSTEM", "1")
    for who in ("AUTHOR", "COMMITTER"):
        monkeypatch.setenv(f"GIT_{who}_NAME", "Test")
        monkeypatch.setenv(f"GIT_{who}_EMAIL", "test@example.org")
    return shutil.which("vcs")
