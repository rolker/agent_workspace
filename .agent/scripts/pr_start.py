"""Where the current pull request's work starts on an issue's timeline.

The one definition of the "a pull request ended here" boundary (issue 459),
read by ``dispatch_phase.sh next`` (round counting, the failed-phase skill
mapping, the post-merge route) and by ``review_progress.sh`` (``round``,
``sources``). Both load it with a plain ``from pr_start import ...`` after
putting this directory on ``sys.path`` from the environment, so
``tests/suites_for_files.sh`` maps a change here to their suites.

Input is ``progress_read.py``'s ``entries`` list (file order is
chronological). One pass over it:

- ``## Checkpoint`` with **Decision**: restart: the work starts at the next
  entry, and the merge state is cleared (the owner restated the goal).
- ``## Checkpoint`` with **Decision**: merge and **After**: merge or findings
  arms: the pull request may have merged.
- ``## Checkpoint`` with **After**: merge, findings or merge-refused and any
  other answer disarms: that merge was not made or did not land. A
  ``merge`` answer at merge-refused neither arms nor disarms (an earlier arm
  stands).
- While armed, the first start entry is the boundary (the work starts
  there) and disarms. A start entry is a ``## Plan Authored``, or an
  ``## Implementation`` with no **Addressed** value that is not correlated
  to a pull request (ADR-0013: **Branch** only "if no PR exists yet"; a fix
  written while the pull request is open carries **PR**). It counts whatever
  its **Status**: a failed first implementation of the next part is that
  part's start, so its retry is ``implement``.
- A ``## Merge (...)`` record neither arms nor disarms: ``merge_pr.sh`` writes
  it at the gate, before the merge, whether or not the merge lands.
- Every other entry changes nothing; a PR-correlated entry never disarms.

Limitation: a merge made by hand with no ``merge`` answer recorded leaves no
boundary. The host records the owner's merge as a ``merge`` checkpoint
(**Decided-by**: owner), or a ``restart``, before the next part.
"""

ARM_AFTERS = ("merge", "findings")
DISARM_AFTERS = ("merge", "findings", "merge-refused")


def _norm(value):
    return (value or "").strip().lower()


def _is_start_entry(entry):
    base = entry.get("base_type")
    if base == "Plan Authored":
        return True
    if base == "Implementation":
        fields = entry.get("fields") or {}
        if (fields.get("Addressed") or "").strip():
            return False
        return (entry.get("correlation") or {}).get("kind") != "pr"
    return False


def scan(entries):
    """Return ``(start, armed)``: the index of the first entry of the current
    pull request's work (0 when no boundary), and whether the timeline is
    armed at its end (a ``merge`` answer with no start entry after it)."""
    start = 0
    armed = False
    for i, entry in enumerate(entries):
        if entry.get("base_type") == "Checkpoint":
            fields = entry.get("fields") or {}
            after = _norm(fields.get("After"))
            decision = _norm(fields.get("Decision"))
            if decision == "restart":
                start = i + 1
                armed = False
            elif decision == "merge":
                if after in ARM_AFTERS:
                    armed = True
            elif after in DISARM_AFTERS:
                armed = False
            continue
        if armed and _is_start_entry(entry):
            start = i
            armed = False
    return start, armed


def pr_start(entries):
    """Index of the first entry of the current pull request's work."""
    return scan(entries)[0]


def merge_armed(entries):
    """True when a ``merge`` answer stands with no start entry after it."""
    return scan(entries)[1]


def is_lgtm_placeholder(entry, finding):
    """The ``- [ ] No issues found. LGTM.`` box review-code leaves unchecked
    on an approved review: not an open finding."""
    verdict = _norm((entry.get("fields") or {}).get("Verdict"))
    return verdict == "approved" and (finding.get("text") or "").strip().startswith(
        "No issues found"
    )
