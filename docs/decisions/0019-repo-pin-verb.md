# ADR-0019: The `repo_pin` Adapter Verb

## Status

Accepted (2026-11-12). Extends [ADR-0011](0011-project-type-adapter-contract.md)'s
adapter contract with one verb, as [ADR-0012](0012-worktree-composition-is-an-adapter-concern.md)
extended it with two: the contract is now 13 verbs.

## Context

A pull request for an issue in a package repository of a multi-repository
project must target the branch the project pins that repository at, not the
forge's default branch (issue #429; the owner's note of 2026-11-10 on that
issue). The case that makes it matter: a repository pinned at one branch in
the project's manifest whose forge default is another, so a pull request
opened the ordinary way targets the wrong branch, and a feature branch cut
from the default holds the wrong history.

Where the pin is written differs per project type. A `ros2_colcon` project
pins each repository in the `version:` of its entry in the layer's `.repos`
file; a single-repository project pins nothing, and its base is its default
branch. Generic scripts (the worktree creation path, `dispatch_phase.sh`,
`run-issue`'s publish step) need the answer without reading a type's files:
reading `.repos` from a generic script would branch on the type, which
ADR-0011 forbids. The verb passes ADR-0011's test ("the workflow needs this,
and the how differs per project type").

Adding a verb changes ADR-0011's decision text (its verb table), so per
[ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md) it is a new ADR,
with only a Status-line note on ADR-0011, the route ADR-0012 took.

## Decision

Add `repo_pin` to `REQUIRED_VERBS` (13 verbs):

- `repo_pin <repo> [--layer <l>]` prints one line `<ref><TAB><kind>` and
  exits 0, or exits 1 with the reason on stderr. `<repo>` is the repository's
  name as the type knows it (the directory name a `.repos` entry or
  `adapter repos` uses), which can differ from the forge name in an issue
  reference.
- `<kind>` is one of `branch`, `tag`, `commit`, `unknown`. Only a `branch`
  can be a pull request's base; a caller refuses the other three and names
  them. The verb does not decide that; it only reports.
- **`ros2_colcon`** reads the `version:` of `<repo>` in the manifest's
  `repos/<layer>.repos` files, YAML quotes stripped (a `#` starts a comment
  only right after the key or after whitespace, so a comment alone is an
  empty `version:`, refused; a quoted value counts only when nothing but a
  comment follows its closing quote and, double-quoted, it holds no
  backslash escape; a ref still holding a quote, backslash or carriage
  return is refused). vcstool checks out `str()` of the value PyYAML's
  `safe_load` gives, so an unquoted value is refused only when YAML's
  reading changes the text: a bool other than `True` or `False` (`yes`,
  `true`, `Off` read as `True` or `False`), null, one starting with a YAML
  indicator character, or an int or float whose `str()` is not the text
  (`version: 1.10` is the float 1.1 there, `017` the int 15). The error
  says what vcstool would check out instead and asks for quotes;
  `version: "1.10"` is accepted. An int written `0`, `2024`, `-5` or as an
  all-digit sha, and a float such as `2.0`, `1.5` or `0.3` (at most 15
  significant digits, an integer part of at most 16, not `0.0000…`), and
  the bools `True` and `False`, come back unchanged and are accepted
  unquoted. The check is an explicit
  pattern list in the adapter, with no YAML library. An entry with no `version:` key pins
  nothing, and the verb exits 1 saying so rather than reporting the default
  branch. A repository pinned in
  more than one layer at different refs needs `--layer`, and without it the
  verb exits 1 naming each layer and ref; the same ref in several layers is
  one answer. The kind comes from git, in the package checkout under the
  layer's `src/`: on origin, `refs/heads/<ref>` is a branch, then
  `refs/tags/<ref>` a tag (a same-named tag does not stop a branch), then a
  40- or 64-hex ref (either case) is a commit, else unknown. A remote-tracking ref left
  behind after the branch was deleted on origin is not enough when origin
  answers. When origin cannot be asked, or the repository is not cloned, the
  local refs (`refs/remotes/origin/<ref>`, `refs/tags/<ref>`) decide and a
  note on stderr says the answer is unverified.
- **`single_project`** accepts only the name `adapter repos` prints and
  prints its default branch with kind `branch`: `refs/remotes/origin/HEAD`
  as git recorded it, else what `git ls-remote --symref origin HEAD` names.
  When neither answers it exits 1; it never guesses a name such as `main`.
  It refuses `--layer`.

Plain git answers every case; no forge is asked. Every query to origin is
bounded as worktree creation's are (#323): `GIT_TERMINAL_PROMPT=0` and,
where `timeout` is installed, the `WT_FETCH_TIMEOUT` limit (default 60s),
so a prompt or a stalled host cannot hang a caller. A query that times out
counts as origin not answering: `ros2_colcon` falls to the unverified local
answer, and `single_project` without a recorded `origin/HEAD` exits 1
naming the timeout.

## Consequences

**Positive:**
- A package pull request's base and its branch's start point can come from
  the project's own manifest, with no forge default branch read and no
  type knowledge in the generic scripts.
- A pin that cannot be a base (a tag, a commit, an unknown ref) is reported
  as such, so callers refuse it instead of guessing.

**Negative:**
- The contract grows to 13 verbs; every future type implements one more,
  and `validate_adapter.sh` makes skipping it impossible.
- The kind is only as current as the last answer from origin; offline, it
  comes from local refs and is marked unverified, and a caller that creates
  a branch must check origin itself before starting from it.

## References

- [ADR-0011](0011-project-type-adapter-contract.md) — the adapter contract
  this extends (+1 verb, 13 total)
- [ADR-0012](0012-worktree-composition-is-an-adapter-concern.md) — the
  previous extension (+2 verbs) and the package worktrees whose base this
  verb answers
- [ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md) — why this is
  a new ADR rather than an edit of ADR-0011's verb table
- Issue #429 (run-issue for a package repository's issue), whose part 2
  adds this verb; issue #436 had planned it as its own pull request
