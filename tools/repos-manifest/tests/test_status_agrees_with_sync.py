"""`status` and `sync` read a repo the same way: for each case of `status_cases.py`, `status`
runs first, then `sync`, and the state must go with what `sync` then did to the repo. The
pairs that legitimately differ are listed, each with its reason (``docs/design.md``,
"status")."""

import json
import re

import pytest

from helpers import run
from status_cases import CASES, make_case

# What `sync` may do to a repo `status` gave each state.
GOES_WITH = {
    "expected": {"up to date", "updated"},
    "different": {"left alone", "updated"},
    "left-alone": {"left alone"},
    "unusable": {"left alone", "failed"},
    "missing": {"cloned", "failed"},
    "skipped": {"cloned", "skipped"},
    "not-a-directory": {"failed"},
    "blocked-place": {"failed"},
    "in-other-layer": {"failed"},
}

# Cases where `sync` does something else, and why.
DIFFER = {
    # The state is the version; `sync` leaves a repo with commits only here as it is.
    "commits only here": "left alone",
    # The state is the version; `sync` leaves a repo with uncommitted changes as it is, and one
    # where a remote of the probe's name is set while the url changed.
    "on its branch, with changes": "left alone",
    "behind, with changes": "left alone",
    "a url changed, probe remote taken": "left alone",
    "behind, probe remote taken": "left alone",
    # A branch another work tree holds is not fast-forwarded by `sync`.
    "behind, held by a work tree": "left alone",
    # `sync` asks origin, which no longer has the branch; `status` reads the stale ref.
    "a branch origin deleted": "failed",
    # Offline a tag here cannot be told from origin's; `sync` asks origin, which lacks it.
    "a local tag origin lacks": "failed",
    # The version is on origin but was not fetched here yet: `sync` fetches it and moves there.
    "a version not fetched": "updated",
}

SUMMARY = re.compile(r"^  (?P<label>[a-z ,]+) \((?P<count>\d+)\)(?:: (?P<paths>.*))?$")
LABELS = {
    "cloned": "cloned",
    "updated": "updated",
    "left alone": "left alone",
    "failed": "failed",
    "optional, skipped": "skipped",
    "up to date": "up to date",
}


def sync_outcome(out: str, path: str = "src/a") -> str:
    """What `sync`'s summary says it did to the repo at `path`."""
    for line in out.splitlines():
        match = SUMMARY.match(line)
        if match is None or match.group("label") not in LABELS:
            continue
        label = LABELS[match.group("label")]
        if label == "up to date" or path in (match.group("paths") or "").split(", "):
            return label
    raise AssertionError(f"no outcome for {path} in:\n{out}")


@pytest.mark.parametrize("optional", [False, True], ids=["required", "optional"])
@pytest.mark.parametrize("name", list(CASES))
def test_status_agrees_with_what_sync_then_does(vcs, tmp_path, capsys, name, optional):
    build, _, _ = CASES[name]
    case = make_case(tmp_path, optional=optional)
    build(case)
    capsys.readouterr()
    run(case.system, "status", "--json")
    (found,) = json.loads(capsys.readouterr().out)["distros"][0]["repos"]
    run(case.system, "sync")
    outcome = sync_outcome(capsys.readouterr().out)
    allowed = set(GOES_WITH[found["state"]])
    if name in DIFFER:
        allowed = {DIFFER[name]}
    if optional:
        # `sync` turns any failure of an optional repo into "skipped".
        allowed = {"skipped" if each == "failed" else each for each in allowed}
    assert outcome in allowed, (name, found["state"], outcome, found["detail"])
