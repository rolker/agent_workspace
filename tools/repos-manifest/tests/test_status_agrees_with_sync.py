"""`status` and `sync` read a repo the same way: for each case of `status_cases.py`, `status`
runs first, then `sync`, and two things are checked against what `sync` then did to the repo.
The state must go with `sync`'s outcome, and every sentence of `status`'s text that says what
`sync` does must be what `sync` then did, so a false prediction fails even when the state is
right. `standing` in `update.py` is a second copy of `sync`'s rules 9 to 12, not code they
share, and this test is what holds the two in step. The cases that legitimately differ are
listed, each with its reason (``docs/design.md``, "status")."""

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

# Cases where `sync` does something else than the state goes with, and why.
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

# Cases whose text is not checked against `sync`, and why: the ones `status` cannot know
# offline (the design lists them).
CLAIMS_DIFFER = {
    # `status` reads the local tag as origin's, so it says `sync` would try to move there;
    # `sync` asks origin, which lacks it, and fails.
    "a local tag origin lacks",
}

# Each sentence of `status`'s text that says what `sync` does, as a pattern, with the outcome
# `sync` must then report for the repo and a pattern its output must hold.
CLAIMS = [
    (r"sync tries to fast-forward it", {"updated"}, r"src/a: fast-forwarded \d+ commit"),
    (r"so sync does not fast-forward it", {"left alone"}, r"is held by .*; not fast-forwarded"),
    (
        r"sync would try to move it to that version",
        {"updated"},
        r"src/a: (moved|tag \S+ was moved)",
    ),
    (
        r"sync leaves it while it has uncommitted changes \(\d+ files?\)",
        {"left alone"},
        r"left alone: has uncommitted changes \(\d+ files?\)",
    ),
    (
        r"sync leaves it while it has \d+ commits? not on origin",
        {"left alone"},
        r"left alone: has \d+ commits? not on origin",
    ),
    (
        r"sync leaves it while a remote named repos-manifest-probe is set here",
        {"left alone"},
        r"a remote named repos-manifest-probe is set here",
    ),
    (
        r"so sync leaves origin, and the repo, as they are",
        {"left alone"},
        r"a remote named repos-manifest-probe is set here",
    ),
    (r"sync leaves it: branch \S+ is held by", {"left alone"}, r"is held by .*; not switched"),
    (
        r"sync leaves it: a local branch \S+ has commits not on origin",
        {"left alone"},
        r"a local branch \S+ has commits not on origin; not switched",
    ),
    (r"sync does not move it", {"left alone", "up to date"}, r""),
    (r"sync does not follow it", {"left alone"}, r"; not followed"),
    (r"sync tries to repoint origin to it", None, r"origin repointed from"),
    (r"sync leaves origin as it is", None, r"left as set"),
    (r"sync clones it", {"cloned"}, r""),
    (r"sync does not update a repo through a link", {"left alone"}, r"through a link"),
    (r"sync does not update one", {"left alone"}, r"is a sparse checkout"),
]

# Sentences that name `sync` without saying what it does next.
NOT_CLAIMS = [
    r"a sync was stopped while moving this repo",
    r"where sync followed it",
    r"whether sync followed the branch or the tag",
    r"\(sync never pushes\)",
    r"a name sync keeps for checking a new url",
]

SUMMARY = re.compile(r"^  (?P<label>[a-z ,]+) \((?P<count>\d+)\)(?:: (?P<paths>.*))?$")
LABELS = {
    "cloned": "cloned",
    "updated": "updated",
    "left alone": "left alone",
    "failed": "failed",
    "optional, skipped": "skipped",
    "up to date": "up to date",
}


def sync_outcome(out: str, path: str) -> str:
    """What `sync`'s summary says it did to the repo at `path`."""
    for line in out.splitlines():
        match = SUMMARY.match(line)
        if match is None or match.group("label") not in LABELS:
            continue
        label = LABELS[match.group("label")]
        if label == "up to date" or path in (match.group("paths") or "").split(", "):
            return label
    raise AssertionError(f"no outcome for {path} in:\n{out}")


def claims_in(detail: str):
    """The claims `detail` makes about `sync`; fails on a sentence that names `sync` and is
    neither a known claim nor a known non-claim, so a new prediction must be added here."""
    rest = detail
    found = []
    for said, outcome, shown in CLAIMS:
        if re.search(said, rest):
            found.append((said, outcome, shown))
            rest = re.sub(said, "", rest)
    for said in NOT_CLAIMS:
        rest = re.sub(said, "", rest)
    assert not re.search(r"\bsync\b", rest), f"an unchecked claim about sync in: {detail}"
    return found


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
    out = capsys.readouterr().out
    outcome = sync_outcome(out, found["path"])
    allowed = set(GOES_WITH[found["state"]])
    if name in DIFFER:
        allowed = {DIFFER[name]}
    if optional:
        # `sync` turns any failure of an optional repo into "skipped".
        allowed = {"skipped" if each == "failed" else each for each in allowed}
    assert outcome in allowed, (name, found["state"], outcome, found["detail"])
    claims = claims_in(found["detail"])
    if name in CLAIMS_DIFFER:
        return
    for said, then, shown in claims:
        if then is not None:
            assert outcome in then, (name, said, outcome, out)
        assert re.search(shown, out), (name, said, shown, out)


def test_a_false_prediction_fails_the_claim_check():
    """The check reads the text, not only the state: a fast-forward said where `sync` left the
    repo for its changes is caught, and so is a sentence about `sync` the check does not know."""
    detail = "on main, behind origin's as last fetched (sync tries to fast-forward it)"
    ((_, then, shown),) = claims_in(detail)
    out = "src/a: left alone: has uncommitted changes (1 file)\n"
    assert "left alone" not in then and not re.search(shown, out)
    with pytest.raises(AssertionError, match="an unchecked claim"):
        claims_in("on main; sync rebases it")
