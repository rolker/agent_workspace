"""Where the current pull request's work starts on an issue's timeline.

The one definition of the "a pull request ended here" boundary (issue 459),
read by ``dispatch_phase.sh next`` (round counting, the failed-phase skill
mapping, the post-merge route) and by ``review_progress.sh`` (``round``,
``sources``). Both load it with a plain ``from pr_start import ...`` after
putting this directory on ``sys.path`` from the environment, so
``tests/suites_for_files.sh`` maps a change here to their suites.

Input is ``progress_read.py``'s ``entries`` list (file order is
chronological). One pass over it gives two starts and the armed state:

- the **round start**: the newest of a restart and a pull-request boundary.
  Rounds count from it (``next``'s round count and failed-phase mapping,
  ``review_progress.sh round``).
- the **pull-request start**: the newest pull-request boundary only (a
  restart does not move it). ``review_progress.sh sources`` lists the review
  entries from it, so a restart recorded while a pull request is open keeps
  that pull request's earlier reviews, open boxes included, in triage input.

The pass:

- ``## Checkpoint`` with **Decision**: restart: the round start moves to the
  next entry, and the merge state is cleared (the owner restated the goal).
  The pull-request start does not move.
- ``## Checkpoint`` with **Decision**: merge and **After**: merge or findings
  arms: the pull request may have merged. The merged pull request's number
  is taken there: the number of the newest PR-correlated entry before the
  answer (the review the merge answer was given on); none when there is no
  such entry.
- ``## Checkpoint`` with **After**: merge, findings or merge-refused and any
  other answer disarms: that merge was not made or did not land. A
  ``merge`` answer at merge-refused neither arms nor disarms (an earlier arm
  stands, with its number).
- While armed, the first start entry is the boundary (both starts move
  there) and disarms. A start entry is:

  - a ``## Plan Authored``, whatever its **Status**;
  - an ``## Implementation`` with no **Addressed** value that is
    Branch-correlated (ADR-0013: **Branch** only "if no PR exists yet"),
    whatever its **Status**: a failed first implementation of the next part
    is that part's start, so its retry is ``implement``;
  - an ``## Implementation`` with no **Addressed** value whose **PR** number
    is not the merged pull request's (a draft pull request of the next part
    existed before its first implementation). One with the merged pull
    request's own number is a fix to that pull request (issue 332, entry
    64), not a start. When the merged number is unknown (no PR-correlated
    entry before the merge answer, or no number on the line), it is not a
    start: a missed boundary over-counts rounds, which raises the rounds
    checkpoint early (the owner is asked), while a false one would reset the
    round count and drop the earlier reviews' open boxes from ``sources``
    silently;
  - an ``## Implementation`` with no **Addressed** value and no correlation
    line only when its **Status** is not ``complete`` (a failed or partial
    first implementation that stopped before writing the line). A complete
    one is a pass that lost its lines (a fix pass that lost **Addressed**
    too), not a start.

- A ``## Merge (...)`` record neither arms nor disarms: ``merge_pr.sh`` writes
  it at the gate, before the merge, whether or not the merge lands.
- Every other entry changes nothing; an entry that is not a start entry
  never disarms.

Limitations: a merge made by hand with no ``merge`` answer recorded leaves
no boundary. The host records the owner's merge as a ``merge`` checkpoint
(**Decided-by**: owner), or a ``restart``, before the next part. A restart
recorded after a merge answer clears the arm, so a part started after it
moves the round start (the restart) but not the pull-request start.
"""

from collections import namedtuple

ARM_AFTERS = ("merge", "findings")
DISARM_AFTERS = ("merge", "findings", "merge-refused")

Scan = namedtuple("Scan", "round_start pr_start armed")


def _norm(value):
    return (value or "").strip().lower()


def _status(entry):
    return _norm(entry.get("status") or (entry.get("fields") or {}).get("Status"))


def _pr_number(entry):
    c = entry.get("correlation") or {}
    if c.get("kind") != "pr":
        return None
    try:
        return int(c.get("pr"))
    except (TypeError, ValueError):
        return None


def _is_start_entry(entry, merged_pr):
    base = entry.get("base_type")
    if base == "Plan Authored":
        return True
    if base != "Implementation":
        return False
    if ((entry.get("fields") or {}).get("Addressed") or "").strip():
        return False
    kind = (entry.get("correlation") or {}).get("kind")
    if kind == "branch":
        return True
    if kind == "pr":
        number = _pr_number(entry)
        return merged_pr is not None and number is not None and number != merged_pr
    return _status(entry) != "complete"


def scan(entries):
    """Return ``Scan(round_start, pr_start, armed)``: the index of the first
    entry the rounds count from (the newest restart or pull-request
    boundary), the index of the first entry of the current pull request
    (the newest pull-request boundary), 0 when there is none, and whether
    the timeline is armed at its end (a ``merge`` answer with no start entry
    after it)."""
    rstart = pstart = 0
    armed = False
    merged_pr = last_pr = None
    for i, entry in enumerate(entries):
        if entry.get("base_type") == "Checkpoint":
            fields = entry.get("fields") or {}
            after = _norm(fields.get("After"))
            decision = _norm(fields.get("Decision"))
            if decision == "restart":
                rstart = i + 1
                armed = False
            elif decision == "merge":
                if after in ARM_AFTERS:
                    armed = True
                    merged_pr = last_pr
            elif after in DISARM_AFTERS:
                armed = False
            continue
        if armed and _is_start_entry(entry, merged_pr):
            rstart = pstart = i
            armed = False
        number = _pr_number(entry)
        if number is not None:
            last_pr = number
    return Scan(rstart, pstart, armed)


def round_start(entries):
    """Index of the first entry the rounds count from."""
    return scan(entries).round_start


def pr_start(entries):
    """Index of the first entry of the current pull request's work."""
    return scan(entries).pr_start


def merge_armed(entries):
    """True when a ``merge`` answer stands with no start entry after it."""
    return scan(entries).armed


def is_lgtm_placeholder(entry, finding):
    """The ``- [ ] No issues found. LGTM.`` box review-code leaves unchecked
    on an approved review: not an open finding."""
    verdict = _norm((entry.get("fields") or {}).get("Verdict"))
    return verdict == "approved" and (finding.get("text") or "").strip().startswith(
        "No issues found"
    )
