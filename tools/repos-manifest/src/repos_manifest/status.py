"""`status`: what the system directory holds against what the manifest says, for each distro it
acts on (``docs/design.md``, "status").

It reads only. It takes no lock, writes no resolved file, no record and no setup file, and
makes no network call of its own: every git it runs goes through `update.Git`, which passes
`--no-optional-locks` (so `git status` does not refresh the index), with no fsmonitor hook and
no lazy fetch (`_reading_git`), and the manifest's version is looked up with
`update.ask_local`, in the refs the clone had when it was last fetched. The clean filters a
clone's configuration names run, as they do for `git status`.

Some checks are `sync`'s own code, called by both: `sync.resolve_all`, `sync.layer_moved`,
`system.place_problem_kind`, `update.blocked_early`, `update.blocked_late`,
`update.stopped_move`, `update.tracked_changes`, `update.count`, `update.find_version`,
`update.commit_on_origin` and `update.probe_taken`. The rest is a second copy of `sync`'s
reading, not shared code: `update.standing` (its rules 9 to 12) and, here, the checks on the
place itself (not there, not a directory, a link) and the order in which `sync` stops at the
url and at uncommitted changes before its rules 9 to 12. The copies are held in
step by `tests/test_status_agrees_with_sync.py`. The calls this module may make into `update`
and `sync` are listed in `tests/test_update_safety.py`, which fails on any other.
"""

from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Sequence

from . import sync, update
from .masking import mask_url, mask_urls, remember_url
from .selection import Selected
from .system import (
    SYSTEM_DIR,
    BLOCKED_PLACE,
    Config,
    NOT_A_DIRECTORY,
    RepoRecord,
    current_directory,
    distros_for,
    find_system,
    layer_src_parts,
    place_problem_kind,
    read_config,
    read_state,
    reporting_oserror,
)
from .yamlload import ManifestError

FORMAT = 1

EXPECTED, DIFFERENT = "expected", "different"
LEFT_ALONE, UNUSABLE = "left-alone", "unusable"
MISSING, SKIPPED = "missing", "skipped"
IN_OTHER_LAYER = "in-other-layer"

# Not at its place: `sync` reports each as an error for a repo that is not optional (a missing
# one when it cannot clone it), and `build` refuses the layer.
NOT_AT_PLACE = (MISSING, NOT_A_DIRECTORY, BLOCKED_PLACE, IN_OTHER_LAYER)
# The states that make the exit status 1 for a repo that is not optional.
FAILING = NOT_AT_PLACE + (UNUSABLE,)

# The first checks `sync` stops at, and the state each gives: a repo `status` cannot use as a
# clone of the manifest's version is unusable; work in progress or a lasting setup `sync`
# leaves alone is left-alone. With no `origin` url at all there is nothing to find the
# version in; with several, the clone is a setup a person made.
BLOCKED_STATE = {
    update.NOT_GIT: UNUSABLE,
    update.NO_COMMIT: UNUSABLE,
    update.OPERATION: LEFT_ALONE,
    update.INDEX_LOCK: LEFT_ALONE,
    update.SPARSE: LEFT_ALONE,
    update.NO_ORIGIN: UNUSABLE,
    update.SEVERAL_ORIGINS: LEFT_ALONE,
}
# The checks that stop before `update.blocked_late` reads the url: a repo left alone at one of
# them still has its `origin` named (`fetched_from`), read on its own.
BEFORE_THE_URL = (update.OPERATION, update.INDEX_LOCK, update.SPARSE)

# Two helpers a clone's own configuration could have `status`'s git start, turned off because
# neither can change the answer (``docs/design.md``, "status"): an fsmonitor hook only tells
# git which files it need not look at, and with none git looks at every file; and a partial
# clone does not fetch a missing object (git 2.45 and later know the variable). The clone's
# clean filters do run, as they run for `git status` and for `sync`'s git, so the three count
# the same files as changed.
NO_LAZY_FETCH = {"GIT_NO_LAZY_FETCH": "1"}
NO_FSMONITOR = ("-c", "core.fsmonitor=false")
# In a partial clone, and only there, `git status` counts changes without rename detection: to
# pair a file staged under a new name with the one `HEAD` has, git reads the file `HEAD` has,
# which a partial clone may not hold when `HEAD` was moved without a checkout (`reset --soft`).
# With no rename detection no object the clone lacks is read, on any git version. The cost: a
# staged rename there counts as two files where `sync` and `git status` say one.
NO_RENAMES = ("-c", "status.renames=false")

# `sync` fetches only when nothing stops it first (uncommitted changes, a remote of the probe's
# name with the url changed), so this says a fetch, not a sync, may find it.
AS_FETCHED = "as origin was when this clone was last fetched; a fetch may find it"


@dataclass
class RepoStatus:
    key: str
    path: str  # relative to the system directory
    layer: str
    optional: bool
    state: str = ""
    detail: str = ""
    version: Optional[str] = None  # what the manifest names
    head: Optional[str] = None
    changes: Optional[int] = None
    unpushed: Optional[int] = None
    behind: Optional[int] = None
    stopped_move: bool = False
    url: str = ""
    fetched_from: Optional[str] = None

    def fails(self) -> bool:
        return not self.optional and self.state in FAILING


@dataclass
class DistroStatus:
    """One distro: `ok` when it would not fail the exit status on its own (it resolved, and no
    repo of it that is not optional is in a failing state); `problem` when it cannot be read or
    resolved, and then no repos."""

    distro: Optional[str]
    ok: bool = True
    problem: Optional[str] = None
    repos: List[RepoStatus] = field(default_factory=list)
    not_in_manifest: List[Dict[str, str]] = field(default_factory=list)


def run_status(named_distros: Sequence[str], as_json: bool) -> int:
    """The command: 1 when a repo that is not optional is not at its place or is unusable, or
    a distro cannot be read or resolved; 0 otherwise. A system directory that cannot be found
    or read is a `ManifestError`, which the caller reports (exit status 1)."""
    cwd = current_directory()
    with reporting_oserror():
        system = find_system(cwd)
        if system is None:
            raise ManifestError(
                f"no system directory in {cwd} or above it (no {SYSTEM_DIR}/ found); set one up"
                " with `repos-manifest init`"
            )
        config = read_config(system)
        distros = distros_for(system, config, named_distros, cwd)
        env = {**sync.require_git(), **NO_LAZY_FETCH}  # `status` runs git, never `vcs`
        plan = _plan(system, config, distros)
        results = [distro_status(system, config, each, env) for each in plan]
    ok = all(result.ok for result in results)
    if as_json:
        print(json.dumps(_document(system, config, results, ok), indent=2))
    else:
        _print(system, config, distros, results)
    return 0 if ok else 1


def _plan(system: Path, config: Config, distros: Sequence[Optional[str]]):
    """Each distro resolved in memory, as `sync` resolves it; a manifest that cannot be read
    is reported for every distro."""
    try:
        return sync.resolve_all(system, config, distros)
    except ManifestError as exc:
        return [sync.Reported(distro, str(exc)) for distro in distros]


def distro_status(system: Path, config: Config, planned, env: Dict[str, str]) -> DistroStatus:
    """One distro's repos."""
    if isinstance(planned, sync.Reported):
        return DistroStatus(planned.distro, ok=False, problem=mask_urls(planned.problem))
    resolved = planned.resolved
    distro = resolved.distro
    state = read_state(system, distro)
    result = DistroStatus(distro)
    # Every url read is registered before any text is masked, as `sync` registers them, so a
    # credential the masking pattern alone would miss (one holding a space or a quote) is
    # masked wherever it appears.
    for layer in resolved.layers:
        for repo in layer.repos:
            remember_url(repo.url)
            remember_url(repo.published)
    for record in state.repos.values():
        remember_url(record.url)
    for layer in resolved.layers:
        src = layer_src_parts(config.layout, distro, layer.name)
        for repo in layer.repos:
            parts = src + tuple(repo.key.split("/"))
            found = RepoStatus(
                key=repo.key,
                path="/".join(parts),
                layer=layer.name,
                optional=repo.optional,
                version=repo.version,
                # The manifest's url; with `fetch_from`, the url fetched from is only in the
                # text, and `fetched_from` is origin's.
                url=mask_url(repo.published or repo.url),
            )
            _place(system, config, distro, repo, layer.name, parts, state.repos, env, found)
            found.detail = mask_urls(found.detail)
            result.repos.append(found)
    keys = {repo.key for layer in resolved.layers for repo in layer.repos}
    for key, record in state.repos.items():
        if key in keys:
            continue
        parts = layer_src_parts(config.layout, distro, record.layer) + tuple(key.split("/"))
        if os.path.lexists(system.joinpath(*parts)):
            result.not_in_manifest.append({"key": key, "path": "/".join(parts)})
    result.ok = not any(repo.fails() for repo in result.repos)
    return result


def _place(
    system: Path,
    config: Config,
    distro: Optional[str],
    repo: Selected,
    layer: str,
    parts,
    records: Dict[str, RepoRecord],
    env: Dict[str, str],
    found: RepoStatus,
) -> None:
    """The checks on the repo's place, in `sync`'s order: the layer the record gives, then the
    place itself (the check on the real destination, not a directory, a link), then the repo."""
    had = records.get(repo.key)
    if had is not None and had.layer != layer:
        moved = sync.layer_moved(system, config, distro, repo, layer, had.layer)
        if moved is not None:
            found.state, found.detail = IN_OTHER_LAYER, moved.detail
            return
    place = system.joinpath(*parts)
    kind, problem = place_problem_kind(system, parts)
    if kind is not None:
        found.state, found.detail = kind, problem
        return
    if not os.path.lexists(place):
        found.state = SKIPPED if repo.optional else MISSING
        found.detail = "is not there; sync clones it"
        return
    if not place.is_dir():
        found.state, found.detail = NOT_A_DIRECTORY, "is there and is not a directory"
        return
    if os.path.islink(place):
        found.state = LEFT_ALONE
        found.detail = (
            f"is a link to {os.readlink(place)}; sync does not update a repo through a link"
        )
        return
    _repo(place, repo, had, env, found)


def _repo(
    place: Path,
    repo: Selected,
    record: Optional[RepoRecord],
    env: Dict[str, str],
    found: RepoStatus,
) -> None:
    git = _reading_git(place, env)
    blocked, git_dir, head = update.blocked_early(git)
    if blocked is not None:
        found.state, found.detail = BLOCKED_STATE[blocked.kind], blocked.text
        return
    if _partial(git):
        git = _reading_git(place, env, partial=True)
    found.head = head
    # A `moving` line that does not name HEAD no longer describes the repo; `sync` drops it,
    # `status` only does not use it.
    stopped = update.stopped_move(record, head)
    found.stopped_move = stopped is not None
    blocked, origin = update.blocked_late(git, git_dir, record, head)
    if blocked is not None and blocked.kind in BEFORE_THE_URL:
        origin = _single_origin(git)
        found.fetched_from = mask_url(origin) if origin is not None else None
    remember_url(origin)  # None when there is no single origin: nothing to register
    if blocked is not None:
        found.state, found.detail = BLOCKED_STATE[blocked.kind], blocked.text
        if blocked.kind in (update.OPERATION, update.INDEX_LOCK):
            return  # `sync`'s text for these carries the stopped move already
    elif origin == "":
        # `sync` takes the empty value for one url, and its fetch fails: there is no url whose
        # refs `status` could answer from.
        found.state, found.detail = UNUSABLE, "has no origin url (it is set to an empty value)"
    else:
        found.state, found.detail = _version(git, place, repo, record, head, origin, found)
    if stopped is not None:
        found.detail += f"; {stopped}"


def _reading_git(place: Path, env: Dict[str, str], partial: bool = False) -> update.Git:
    """`update.Git` for `status`: with no fsmonitor hook (`-c` on the command line comes after
    the configuration git reads from files and from the environment, so it wins), and the
    clone's filter drivers as they are, as `git status` and `sync` run them; in a partial clone
    (`partial`) with no rename detection either."""
    return update.Git(place, env, None, options=NO_FSMONITOR + (NO_RENAMES if partial else ()))


def _partial(git: update.Git) -> bool:
    """Whether the clone is a partial clone: its configuration names a promisor remote (or the
    older `extensions.partialClone`). Reads the configuration only."""
    if git.out("config", "--get", "extensions.partialClone"):
        return True
    status, printed, _ = git.run("config", "--type=bool", "--get-regexp", r"^remote\..*\.promisor$")
    return status == 0 and any(line.endswith(" true") for line in printed.splitlines())


def _single_origin(git: update.Git) -> Optional[str]:
    """The url of `origin` when it has exactly one, read from the configuration; None
    otherwise."""
    status, printed, _ = git.run("config", "--get-all", "remote.origin.url")
    urls = printed.splitlines() if status == 0 else []
    return urls[0] if len(urls) == 1 else None


def _version(git, place, repo, record, head, origin, found):
    """The state and text of a repo that is a git repository with a commit, nothing in
    progress, and one `origin` url."""
    found.fetched_from = mask_url(origin)
    repoint = _repoints(origin, repo, record)
    taken = repoint and update.probe_taken(git)
    remote_note = _remote_note(origin, repo, record, taken)
    changes = update.tracked_changes(git)
    if changes is None:
        return UNUSABLE, "`git status` fails here"
    # What stops `sync` at the repo before its rules, in its order.
    held = None
    if taken:
        held = f"sync leaves it while a remote named {update.PROBE} is set here"
    elif changes:
        many = update.counted(changes, "file")
        held = f"sync leaves it while it has uncommitted changes ({many})"
    symbolic = git.out("symbolic-ref", "-q", "HEAD")
    branch = None
    if symbolic is not None and symbolic.startswith("refs/heads/"):
        branch = symbolic[len("refs/heads/") :]
    unpushed = None
    if branch is not None:
        unpushed = update.count(git, "HEAD", "--not", "--remotes=origin")
        if unpushed is None:
            return UNUSABLE, "the commits not on origin cannot be counted"
    version, problem, _ = update.find_version(git, repo.version, record, ask=update.ask_local)
    if version is None:
        problem = (problem or "").replace("<place>", update.quoted(place))
        return UNUSABLE, f"{problem} ({AS_FETCHED}){remote_note}"
    found.changes, found.unpushed = changes, unpushed
    if version.kind == update.COMMIT:
        on_origin, said = update.commit_on_origin(git, version.target, ask=update.ask_local)
        if on_origin is None:
            found.changes = found.unpushed = None
            return UNUSABLE, said
        if not on_origin:
            return (
                DIFFERENT,
                f"version {repo.version} is a commit here that no branch of origin, and no tag"
                f" origin has, holds; sync does not follow it{remote_note}",
            )
    # With `fetch_from`, commits only here go to the place `sync` would repoint origin to.
    push_to = repo.url if repoint and not taken and repo.published is not None else None
    standing = update.standing(
        git, repo, record, version, head, branch, unpushed, held, push_to=push_to
    )
    found.behind = standing.behind
    return (EXPECTED if standing.on_version else DIFFERENT), standing.text + remote_note


def _repoints(origin: str, repo: Selected, record: Optional[RepoRecord]) -> bool:
    """Whether `origin` is the url recorded (`update.was_recorded`) and `sync` now wants
    another: the case where `sync` tries to repoint it."""
    return not update.same_url(origin, repo.url) and update.was_recorded(origin, repo, record)


def _remote_note(origin: str, repo: Selected, record: Optional[RepoRecord], taken: bool) -> str:
    """When `origin` is not the url `sync` wants: what `sync` does about it. `taken` when a
    remote of the probe's name is set here (`update.probe_taken`, read only for a url to
    repoint). With `fetch_from`, the url wanted is the one built from its prefix, and the text
    names the manifest's too."""
    if update.same_url(origin, repo.url):
        return ""
    shown, wanted = mask_url(origin), mask_url(repo.url)
    if repo.published is not None:
        says = f"fetch_from names {wanted} (the manifest says {mask_url(repo.published)})"
        now_says = f"fetch_from now names {wanted}"
    else:
        says, now_says = f"the manifest says {wanted}", f"the manifest now says {wanted}"
    if not _repoints(origin, repo, record):
        return f"; fetched from {shown}, set by hand; {says}, and sync leaves origin as it is"
    if taken:
        return (
            f"; fetched from {shown}, the url recorded; {now_says}, and a remote named"
            f" {update.PROBE} is set here, a name sync keeps for checking a new url, so sync"
            " leaves origin, and the repo, as they are"
        )
    return (
        f"; fetched from {shown}, the url recorded; {now_says}, and sync tries to repoint"
        " origin to it: it fetches from the new url first, and leaves origin, and the repo, as"
        " they are when that fails or a local commit is not on the new url"
    )


def _document(system: Path, config: Config, results: Sequence[DistroStatus], ok: bool) -> dict:
    distros = []
    for result in results:
        entry = {"distro": result.distro, "ok": result.ok, "problem": result.problem}
        if result.problem is None:
            entry["repos"] = [asdict(r) for r in result.repos]
            entry["not_in_manifest"] = list(result.not_in_manifest)
        distros.append(entry)
    return {
        "format": FORMAT,
        "ok": ok,
        "system": str(system),
        "manifest": mask_url(config.manifest),
        "role": config.role,
        "groups": list(config.groups),
        "layout": config.layout,
        "recorded_distros": list(config.distros) if config.distros is not None else None,
        "distros": distros,
    }


def _facts(repo: RepoStatus) -> str:
    said = []
    if repo.changes:
        said.append(f"{update.counted(repo.changes, 'file')} changed")
    if repo.unpushed:
        said.append(f"{update.counted(repo.unpushed, 'commit')} not on origin")
    if repo.behind:
        said.append(f"{repo.behind} behind origin")
    return f" [{', '.join(said)}]" if said else ""


def _print(
    system: Path,
    config: Config,
    acted_on: Sequence[Optional[str]],
    results: Sequence[DistroStatus],
) -> None:
    print(f"system {system}")
    print(f"manifest {mask_url(config.manifest)}")
    print(f"role {config.role if config.role is not None else '(none)'}")
    print(f"groups {', '.join(config.groups) if config.groups else '(none)'}")
    if config.distros is not None:
        marked = [f"{d} (shown)" if d in acted_on else d for d in config.distros]
        print(f"distros set up {', '.join(marked)}")
    for result in results:
        name = result.distro if result.distro is not None else "(no distro)"
        print(f"distro {name}:")
        if result.problem is not None:
            print(f"  ERROR: {result.problem}")
            continue
        for repo in result.repos:
            optional = " (optional)" if repo.optional else ""
            print(f"  {repo.path}  {repo.state}{optional}: {repo.detail}{_facts(repo)}")
        for gone in result.not_in_manifest:
            print(f"  {gone['path']}  not-in-manifest: recorded by sync, still on disk")
