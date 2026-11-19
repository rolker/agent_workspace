"""`sync` for a repo that is there: the rules, checked in order, that decide whether it is
followed, moved to another version, or left as it is (``docs/design.md``, "sync").

Nothing here loses or silently changes a person's work. A repo is changed only when it is a git
repository of its own, with one `origin`, nothing in progress, no tracked changes, and no
commits that are not on `origin`; and then only by a fast-forward or a switch that git does as
one call, after a check that no file git does not track (untracked or ignored) is where an
incoming file goes. After each such call the repo's state is read again: success is judged by
that state, not by git's exit status. The commands this module never runs are listed in
`NEVER`, and a test reads this file for them.

Every `git` runs with automatic `gc` and `maintenance` off, so nothing it starts in the
background outlives the run with the distro's lock, and with `submodule.recurse` off, so a
submodule is never moved by it.
"""

from __future__ import annotations

import os
import re
import shlex
import stat
import subprocess
from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Callable, Dict, List, Optional, Sequence, Set, Tuple

from .output import signals_held
from .selection import Selected
from .system import RepoRecord
from .yamlload import ManifestError

GIT_OPTIONS = (
    "--no-optional-locks",
    "-c",
    "gc.auto=0",
    "-c",
    "maintenance.auto=false",
    "-c",
    "advice.detachedHead=false",
    "-c",
    "submodule.recurse=false",
)

# The remote-tracking refs of the url probe: a name `sync` reserves, removed at every check.
PROBE = "repos-manifest-probe"

# What a person (or a git that is still running) has in progress, by the entry it leaves in
# the git directory.
IN_PROGRESS = (
    ("rebase-merge", "a rebase"),
    ("rebase-apply", "a rebase or `git am`"),
    ("MERGE_HEAD", "a merge"),
    ("CHERRY_PICK_HEAD", "a cherry-pick"),
    ("REVERT_HEAD", "a revert"),
    ("BISECT_LOG", "a bisect"),
    ("sequencer", "a cherry-pick or revert of several commits"),
)

# Words no git command of this module holds; `tests/test_update_safety.py` reads the file.
NEVER = (
    "reset --hard",
    "checkout -f",
    "clean",
    "stash",
    "gc",
    "prune",
    "push",
    "--force",
    "rebase",
    "pull",
    "--no-verify",
    "branch -d",
    "branch -D",
)

HEX = re.compile(r"[0-9a-f]{7,40}")
CLOBBERED_TAG = re.compile(r"\[rejected\]\s+(\S+)\s+->\s+\S+\s+\(would clobber existing tag\)")

UPDATED, CURRENT, LEFT, FAILED = "updated", "up to date", "left alone", "failed"
BRANCH, TAG, COMMIT = "branch", "tag", "commit"

# How many paths a report names.
SHOWN_PATHS = 10


@dataclass
class Done:
    """What happened to one repo that is there: `outcome` is one of UPDATED (fast-forwarded or
    moved), CURRENT (nothing to do), LEFT (left as it is and reported) and FAILED (an error, or
    a skip for an optional repo); `fetch` when a later sync may get past it."""

    outcome: str
    detail: str = ""
    notes: List[str] = field(default_factory=list)
    fetch: bool = False
    commit: Optional[str] = None


Env = Dict[str, str]


class Git:
    """`git -C <place>` with the run's environment and options; `lock` is the descriptor of the
    distro's lock, passed to every `git` that changes the work tree or the configuration."""

    def __init__(self, place: Path, env: Env, lock: Optional[int]):
        self.place = place
        self.env = {**env, "GIT_EDITOR": "true"}
        self.lock = lock

    def run(
        self, *args: str, change: bool = False, prompt: bool = False, stdin: Optional[str] = None
    ) -> Tuple[int, str, str]:
        """Exit status, stdout and stderr. A call that may change the work tree or the
        configuration runs with the stop signals held, so it is not cut short by one here
        (a held signal is delivered when it has ended, and `git` inherits it held), and with
        the lock passed to it. Only a fetch may prompt (for a password or a passphrase)."""
        argv = ["git", "-C", str(self.place), *GIT_OPTIONS, *args]
        kwargs = dict(
            input=stdin,
            capture_output=True,
            encoding="utf-8",
            errors="surrogateescape",
            check=False,
            env=self.env,
        )
        if stdin is None:
            kwargs["stdin"] = None if prompt else subprocess.DEVNULL
        if change:
            with signals_held():
                done = subprocess.run(
                    argv, pass_fds=(self.lock,) if self.lock is not None else (), **kwargs
                )
        else:
            done = subprocess.run(argv, **kwargs)
        return done.returncode, done.stdout, done.stderr

    def out(self, *args: str) -> Optional[str]:
        """What the command printed, stripped, or None when it exited non-zero."""
        status, printed, _ = self.run(*args)
        return printed.strip() if status == 0 else None

    def ok(self, *args: str) -> bool:
        return self.run(*args)[0] == 0


def quoted(text: object) -> str:
    return shlex.quote(str(text))


def same_url(one: str, other: str) -> bool:
    """Two urls name the same place when they are equal after one trailing `/` and then one
    trailing `.git` are taken off each."""

    def plain(url: str) -> str:
        url = url[:-1] if url.endswith("/") else url
        return url[:-4] if url.endswith(".git") else url

    return plain(one) == plain(other)


def tracked_changes(git: Git) -> Optional[int]:
    """How many tracked files differ from `HEAD` in the index or the work tree, with the files
    flagged assume-unchanged or skip-worktree, whose changes git does not show. Untracked and
    ignored files are not counted. A submodule counts when a person changed files tracked in
    it, staged it, or removed it; not when only its checked-out commit differs from the one
    recorded (what a fast-forward that moves its pointer leaves). None when git cannot say."""
    status, printed, _ = git.run(
        "status", "--porcelain=v2", "-z", "--untracked-files=no", "--ignore-submodules=untracked"
    )
    if status != 0:
        return None
    count = 0
    entries = printed.split("\0")
    skip = False
    for entry in entries:
        if skip:  # the original path of a rename or copy
            skip = False
            continue
        if not entry:
            continue
        kind = entry[0]
        if kind == "u":
            count += 1
        elif kind in "12":
            skip = kind == "2"
            fields = entry.split(" ")
            xy, sub = fields[1], fields[2]
            if sub[0] != "S" or xy[0] != "." or xy[1] not in ".M" or sub[2] == "M":
                count += 1
    status, printed, _ = git.run("ls-files", "-v", "-z")
    if status != 0:
        return None
    for entry in printed.split("\0"):
        if entry and (entry[0].islower() or entry[0] == "S"):
            count += 1
    return count


def delete_probe_refs(git: Git) -> None:
    refs = git.out("for-each-ref", "--format=%(refname)", f"refs/remotes/{PROBE}/")
    for ref in (refs or "").splitlines():
        git.run("update-ref", "-d", ref, change=True)


def gitlinks(git: Git, commit: str) -> Optional[Dict[str, str]]:
    """The submodules of `commit`: path to the commit it records. None when git cannot say."""
    status, printed, _ = git.run("ls-tree", "-r", "-z", "--full-tree", commit)
    if status != 0:
        return None
    found = {}
    for entry in printed.split("\0"):
        meta, _, path = entry.partition("\t")
        fields = meta.split(" ")
        if len(fields) == 3 and fields[1] == "commit":
            found[path] = fields[2]
    return found


def _populated(path: Path) -> bool:
    """Whether anything is at `path`: a file, a link, or a directory that is not empty."""
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return False
    if not stat.S_ISDIR(info.st_mode):
        return True
    with os.scandir(path) as entries:
        return any(True for _ in entries)


def submodules_in_the_way(git: Git, head: str, targets: Sequence[str]) -> Optional[List[str]]:
    """What, of the submodules of `head`, a move to each of `targets` would put at risk: a
    submodule the move removes or replaces with something else (a file, a link, a directory of
    the superproject's), when its directory holds anything; and a submodule whose pointer the
    move changes, when its directory holds a checkout that is not on the commit `head` records
    (a person committed or moved it there), or is not a repository of its own. Whether the
    submodule's content could be lost is never judged: it is left to a person. None when git
    cannot list the submodules."""
    here = gitlinks(git, head)
    if here is None:
        return None
    if not here:
        return []
    theirs = []
    for target in targets:
        links = gitlinks(git, target)
        if links is None:
            return None
        theirs.append(links)
    found: List[str] = []
    for path, recorded in sorted(here.items()):
        after = [links.get(path) for links in theirs]
        if all(commit == recorded for commit in after):
            continue
        place = git.place / path
        if not _populated(place):
            continue
        if any(commit is None for commit in after):
            found.append(
                f"submodule {path} is checked out here, and the move removes it or puts"
                " something else in its place"
            )
            continue
        sub = Git(place, git.env, None)
        top = sub.out("rev-parse", "--show-toplevel")
        if top is None or os.path.realpath(top) != os.path.realpath(place):
            found.append(f"submodule {path} holds files and is not a repository of its own")
            continue
        sub_head = sub.out("rev-parse", "--verify", "-q", "HEAD")
        if sub_head != recorded:
            found.append(
                f"submodule {path} is on {(sub_head or 'no commit')[:12]}, not on"
                f" {recorded[:12]}, the commit recorded here, and the move changes that commit"
            )
    return found


def submodules_note(paths: Sequence[str]) -> str:
    return (
        f"{'; '.join(paths)}; not updated (a submodule has to be dealt with by hand, then sync"
        " again)"
    )


def in_the_way(git: Git, head: str, targets: Sequence[str]) -> Optional[List[str]]:
    """The paths in the work tree, not tracked in `head`, that a move from `head` to each of
    `targets` would overwrite or remove: for each path a target adds, the path itself, or a
    directory of it that is there and is not a directory (`lstat`: a link is never taken for a
    directory) or that holds a file not tracked in `head`; and each directory on the way to it
    that is there and is not a directory. A tracked path git replaces itself. None when git
    cannot list the paths."""
    added: Set[str] = set()
    for target in targets:
        status, printed, _ = git.run(
            "diff", "--name-only", "--no-renames", "--diff-filter=A", "-z", head, target
        )
        if status != 0:
            return None
        added.update(name for name in printed.split("\0") if name)
    if not added:
        return []
    status, printed, _ = git.run("ls-tree", "-r", "-z", "--name-only", "--full-tree", head)
    if status != 0:
        return None
    tracked = {name for name in printed.split("\0") if name}
    found: List[str] = []
    seen: Set[str] = set()

    def hit(path: str) -> None:
        if path not in seen:
            seen.add(path)
            found.append(path)

    for path in sorted(added):
        parts = path.split("/")
        blocked = False
        for depth in range(1, len(parts)):
            above = "/".join(parts[:depth])
            try:
                info = os.lstat(git.place / above)
            except FileNotFoundError:
                break
            if stat.S_ISDIR(info.st_mode):
                continue
            if above not in tracked:
                hit(above)
            blocked = True
            break
        if blocked:
            continue
        try:
            info = os.lstat(git.place / path)
        except FileNotFoundError:
            continue
        if path in tracked:
            continue
        if not stat.S_ISDIR(info.st_mode):
            hit(path)
        elif _holds_untracked(git.place, path, tracked):
            hit(path)
    return found


def _holds_untracked(top: Path, directory: str, tracked: Set[str]) -> bool:
    """Whether the directory `directory` of the work tree holds anything that is not a
    directory and not tracked: a file, a link, or a repository of its own."""
    for here, dirs, files in os.walk(top / directory):
        relative = os.path.relpath(here, top)
        for name in list(dirs):
            path = os.path.join(here, name)
            if not stat.S_ISDIR(os.lstat(path).st_mode):  # a link to a directory
                if f"{relative}/{name}" not in tracked:
                    return True
                dirs.remove(name)
        for name in files:
            if f"{relative}/{name}" not in tracked:
                return True
    return False


def paths_note(git: Git, paths: Sequence[str]) -> str:
    ignored = set()
    status, printed, _ = git.run("check-ignore", "-z", "--stdin", stdin="\0".join(paths))
    if status in (0, 1):
        ignored = {name for name in printed.split("\0") if name}
    shown = [f"{p} (ignored)" if p in ignored else p for p in paths[:SHOWN_PATHS]]
    more = f" and {len(paths) - SHOWN_PATHS} more" if len(paths) > SHOWN_PATHS else ""
    return (
        f"{len(paths)} paths not tracked here are in the way of incoming files: "
        f"{', '.join(shown)}{more}; not updated (move them aside, then sync again)"
    )


@dataclass
class Before:
    """What a failed call must not have changed."""

    head: str
    symbolic: Optional[str]
    config: str
    index: str
    status: str

    @staticmethod
    def read(git: Git, git_dir: Path) -> "Before":
        return Before(
            git.out("rev-parse", "HEAD") or "",
            git.out("symbolic-ref", "-q", "HEAD"),
            _read(git_dir, "config"),
            git.out("ls-files", "-s") or "",
            git.out("status", "--porcelain=v2", "--untracked-files=no") or "",
        )


def _read(git_dir: Path, name: str) -> str:
    common = git_dir
    commondir = git_dir / "commondir"
    if commondir.is_file():
        common = (git_dir / commondir.read_text().strip()).resolve()
    try:
        return (common / name).read_text(encoding="utf-8", errors="surrogateescape")
    except OSError:
        return ""


@dataclass
class Version:
    kind: str  # BRANCH, TAG or COMMIT
    name: str  # the branch's name (for a version not given, origin's default branch)
    target: str  # the commit


def find_version(git: Git, version: Optional[str]) -> Tuple[Optional[Version], Optional[str], bool]:
    """The manifest's version on origin, after a fetch: (version, problem, fetch). A tag
    counts only when origin has it, not a local tag of the same name; a commit when it is
    there and is named by 7 to 40 hex digits."""
    if version is None:
        ref = git.out("symbolic-ref", "-q", "refs/remotes/origin/HEAD")
        prefix = "refs/remotes/origin/"
        if not ref or not ref.startswith(prefix):
            return (
                None,
                "the manifest names no version and origin's default branch is not known here"
                " (no refs/remotes/origin/HEAD); `git -C <place> remote set-head origin --auto`"
                " sets it",
                False,
            )
        name = ref[len(prefix) :]
        target = git.out("rev-parse", "--verify", "-q", f"{ref}^{{commit}}")
        if target is None:
            return None, f"origin's default branch {name} cannot be read", False
        return Version(BRANCH, name, target), None, False
    branch = git.out("rev-parse", "--verify", "-q", f"refs/remotes/origin/{version}^{{commit}}")
    tag = None
    local_tag = git.out("rev-parse", "--verify", "-q", f"refs/tags/{version}")
    if local_tag is not None:
        # Only a tag origin has counts, and only when it is origin's (the same object).
        status, printed, error = git.run(
            "ls-remote", "--tags", "origin", f"refs/tags/{version}", prompt=True
        )
        if status != 0:
            return None, f"`git ls-remote origin` exited {status}:\n{error.rstrip()}", True
        theirs = {}
        for line in printed.splitlines():
            oid, _, ref = line.partition("\t")
            theirs[ref] = oid
        origins = theirs.get(f"refs/tags/{version}")
        if origins is not None and branch is not None:
            return None, f"version {version} is both a branch and a tag", False
        if origins is not None and origins != local_tag:
            return None, f"tag {version} here is not origin's tag {version}", False
        if origins is not None:
            tag = git.out("rev-parse", "--verify", "-q", f"refs/tags/{version}^{{commit}}")
        elif branch is None:
            return None, f"version {version} is a tag here, and origin has no such tag", False
    if branch is not None:
        return Version(BRANCH, version, branch), None, False
    if tag is not None:
        return Version(TAG, version, tag), None, False
    if HEX.fullmatch(version):
        commit = git.out("rev-parse", "--verify", "-q", f"{version}^{{commit}}")
        if commit is not None and commit.startswith(version):
            return Version(COMMIT, version, commit), None, False
    return None, f"version {version} is not on origin", False


def ancestor(git: Git, older: str, newer: str) -> bool:
    return git.ok("merge-base", "--is-ancestor", older, newer)


def count(git: Git, *args: str) -> Optional[int]:
    printed = git.out("rev-list", "--count", *args)
    return int(printed) if printed is not None and printed.isdigit() else None


def worktree_holding(git: Git, branch: str) -> Optional[str]:
    """The path of another work tree that has `branch` checked out, if one has."""
    printed = git.out("worktree", "list", "--porcelain") or ""
    here = os.path.realpath(git.place)
    path = None
    for line in printed.splitlines():
        if line.startswith("worktree "):
            path = line[len("worktree ") :]
        elif line == f"branch refs/heads/{branch}" and path is not None:
            if os.path.realpath(path) != here:
                return path
    return None


class _Turn:
    """One repo's turn: what the rules after the url rule share."""

    def __init__(self, git, git_dir, repo, layer, record, write, notes):
        self.git: Git = git
        self.git_dir: Path = git_dir
        self.repo: Selected = repo
        self.layer: str = layer
        self.record: Optional[RepoRecord] = record
        self.put: Callable[[RepoRecord], None] = write
        self.notes: List[str] = notes

    def new_record(self, commit: str, moving: Optional[Tuple[str, str]] = None) -> RepoRecord:
        return RepoRecord(self.layer, self.repo.version, commit, self.repo.url, moving)

    def left(self, detail: str) -> Done:
        """Left as it is. The record is unchanged, except that the manifest's url is recorded
        when it is not yet."""
        record = self.record
        if record is not None and record.url != self.repo.url:
            self.put(replace(record, url=self.repo.url))
        return Done(LEFT, detail, self.notes)

    def current(self, head: str, said: str) -> Done:
        if self.record != self.new_record(head):
            self.put(self.new_record(head))
        return Done(CURRENT, said, self.notes, commit=head)


def update_repo(
    place: Path,
    repo: Selected,
    layer: str,
    record: Optional[RepoRecord],
    env: Env,
    lock: Optional[int],
    write: Callable[[RepoRecord], None],
) -> Done:
    """Bring one repo that is there in line with the manifest, or leave it as it is and say
    why. `write` records the repo in `state.yaml`; an error from it while the repo is being
    changed ends the run (the caller says the repo may be changed but not recorded)."""
    if repo.type != "git":
        return Done(LEFT, f"type {repo.type}: sync updates git repos only")
    git = Git(place, env, lock)
    status, printed, error = git.run("rev-parse", "--show-toplevel")
    if status != 0 or os.path.realpath(printed.strip()) != os.path.realpath(place):
        return Done(LEFT, "is not a git repository of its own")
    git_dir = Path(git.out("rev-parse", "--absolute-git-dir") or place / ".git")
    head = git.out("rev-parse", "--verify", "-q", "HEAD")
    if head is None:
        return Done(LEFT, "has no commit checked out")
    stopped = None
    if record is not None and record.moving is not None and head in record.moving:
        stopped = (
            f"a sync was stopped while moving this repo from {record.moving[0][:12]} to"
            f" {record.moving[1][:12]}; `git status` shows what it left"
        )
    for name, what in IN_PROGRESS:
        if os.path.lexists(git_dir / name):
            return Done(LEFT, stopped or f"{what} is in progress")
    if os.path.lexists(git_dir / "index.lock"):
        return Done(LEFT, stopped or "index.lock exists; another git may be running here")

    status, printed, _ = git.run("config", "--get-all", "remote.origin.url")
    urls = printed.splitlines() if status == 0 else []
    if len(urls) != 1:
        return Done(LEFT, "has no single origin")
    origin = urls[0]
    delete_probe_refs(git)
    url = repo.url
    notes: List[str] = []
    by_hand = None
    if same_url(origin, url):
        pass
    elif record is not None and record.url is not None and same_url(origin, record.url):
        # The manifest changed the url since the repo was recorded: repoint, unless a local
        # branch has commits the new url does not have.
        done = _repoint(git, origin, url)
        if done is not None:
            return done
        notes.append(f"origin repointed from {origin} to {url}")
    else:
        by_hand = (
            f"origin is {origin}, the manifest says {url}; left as set (to use the manifest's:"
            f" git -C {quoted(place)} remote set-url origin {quoted(url)})"
        )
        notes.append(by_hand)
    turn = _Turn(git, git_dir, repo, layer, record, write, notes)

    changes = tracked_changes(git)
    if changes is None:
        return turn.left("`git status` fails here")
    if changes:
        return turn.left(stopped or f"has uncommitted changes ({changes} files)")

    status, printed, error = git.run(
        "fetch", "--prune", "--no-prune-tags", "--tags", "origin", prompt=True
    )
    if status != 0:
        detail = f"`git fetch origin` exited {status}:\n{(printed + error).rstrip()}"
        clobbered = CLOBBERED_TAG.search(error)
        if clobbered:
            tag = clobbered.group(1)
            detail += (
                f"\ntag {tag} was moved on origin, and sync never replaces a tag: to take"
                f" origin's, git -C {quoted(place)} tag -d {quoted(tag)}, then sync again"
            )
        return Done(FAILED, detail, notes, fetch=True)

    found, problem, fetch = find_version(git, repo.version)
    if found is None:
        problem = (problem or "").replace("<place>", quoted(place))
        if by_hand is not None and not fetch:
            problem += f"; origin was set by hand: {by_hand}"
        return Done(FAILED, problem, notes, fetch=fetch)
    wanted = repo.version if repo.version is not None else f"origin's default branch {found.name}"

    symbolic = git.out("symbolic-ref", "-q", "HEAD")
    branch = None
    if symbolic is not None and symbolic.startswith("refs/heads/"):
        branch = symbolic[len("refs/heads/") :]
    if branch is not None:
        ahead = count(git, "HEAD", "--not", "--remotes=origin")
        if ahead is None:
            return turn.left("the commits not on origin cannot be counted")
        if ahead:
            detail = f"has {ahead} commits not on origin"
            if found.kind == BRANCH and branch == found.name:
                if not ancestor(git, found.target, head):
                    detail += (
                        f"; to bring origin's in by hand: git -C {quoted(place)} pull --rebase"
                        f" origin {quoted(found.name)}"
                    )
            else:
                detail += f"; the manifest names {wanted}; it is not switched"
            return turn.left(detail)

    # On the manifest's version.
    if found.kind == BRANCH and branch == found.name:
        if head == found.target:
            return turn.current(head, "up to date")
        if not ancestor(git, head, found.target):
            return turn.left(
                f"origin's {found.name} no longer contains this commit (rewritten upstream)"
            )
        moved = count(git, f"{head}..{found.target}")
        steps = [
            (["merge", "--ff-only", "--no-overwrite-ignore", "-q", found.target], found.target)
        ]
        said = f"fast-forwarded {moved} commits"
        return _change(turn, head, [found.target], steps, symbolic, said)
    if found.kind != BRANCH and branch is None and head == found.target:
        return turn.current(head, f"pinned at {found.name}")

    # On the recorded version, which the manifest has changed: moved to the new one.
    if record is not None and _on_recorded(git, record, head, branch):
        if record.version != repo.version:
            return _move(turn, head, found)
        # The same tag, detached where sync put it, and origin's tag now names another commit
        # (the person deleted the stale local tag, as the failed fetch said): followed.
        if found.kind == TAG and branch is None:
            said = f"tag {found.name} was moved on origin: moved from {head[:12]} to it"
            return _move(turn, head, found, said)

    where = branch if branch is not None else f"a detached HEAD at {head[:12]}"
    detail = f"moved by a person: it is on {where}; the manifest names {wanted}"
    if record is not None and record.version != repo.version:
        detail += f" (recorded: {record.version or 'no version'})"
    return turn.left(detail)


def _on_recorded(git: Git, record: RepoRecord, head: str, branch: Optional[str]) -> bool:
    """Whether the repo is where `sync` last put it: on the recorded branch, or detached at the
    recorded commit (a tag or a commit); for a recorded version not given, on origin's
    default branch."""
    if branch is None:
        return head == record.commit
    if record.version is not None:
        return branch == record.version
    ref = git.out("symbolic-ref", "-q", "refs/remotes/origin/HEAD") or ""
    return ref == f"refs/remotes/origin/{branch}"


def _move(turn: _Turn, head: str, found: Version, said: Optional[str] = None) -> Done:
    """From the recorded version to the manifest's: one `git switch`, or, to a branch that
    exists locally, a switch and then a fast-forward."""
    git = turn.git
    if said is None:
        said = f"moved from {turn.record.version or 'the default branch'} to {found.name}"
    if found.kind != BRANCH:
        steps = [
            (["switch", "-q", "--no-overwrite-ignore", "--detach", found.target], found.target)
        ]
        return _change(turn, head, [found.target], steps, None, said)
    want = f"refs/heads/{found.name}"
    local = git.out("rev-parse", "--verify", "-q", want)
    if local is None:
        track = f"refs/remotes/origin/{found.name}"
        steps = [
            (
                ["switch", "-q", "--no-overwrite-ignore", "-c", found.name, "--track", track],
                found.target,
            )
        ]
        return _change(turn, head, [found.target], steps, want, said)
    if not ancestor(git, local, found.target):
        return turn.left(f"a local branch {found.name} has commits not on origin; not switched")
    holder = worktree_holding(git, found.name)
    if holder is not None:
        return turn.left(f"branch {found.name} is checked out in {holder}; not switched")
    steps = [(["switch", "-q", "--no-overwrite-ignore", found.name], local)]
    if local != found.target:
        steps.append(
            (["merge", "--ff-only", "--no-overwrite-ignore", "-q", found.target], found.target)
        )
    return _change(turn, head, [local, found.target], steps, want, said)


def _change(
    turn: _Turn,
    head: str,
    targets: Sequence[str],
    steps: Sequence[Tuple[Sequence[str], str]],
    want: Optional[str],
    said: str,
) -> Done:
    """Run `steps`, the calls that change the work tree, after the submodule and paths checks:
    each call with the commit it puts `HEAD` on; `want` is the symbolic `HEAD` (None: detached)
    every step ends on, and the last step's commit is the target. A `moving` line is recorded
    before the first call, and the record is written after the state is read and found right.
    Each call is judged by the state it leaves, not its exit status: one that exited non-zero
    (a failing hook) but left `HEAD` where it was to go, with no tracked changes, counts, with a
    note. A call that did not get there is put back (the second of two is undone by switching
    back); if the repo is then not as it was, the result is an error with what git left."""
    git, notes = turn.git, turn.notes
    target = steps[-1][1]
    submodules = submodules_in_the_way(git, head, targets)
    if submodules is None:
        return turn.left("the submodules cannot be listed; not updated")
    if submodules:
        return turn.left(submodules_note(submodules))
    blocking = in_the_way(git, head, targets)
    if blocking is None:
        return turn.left("the incoming files cannot be listed; not updated")
    if blocking:
        return turn.left(paths_note(git, blocking))
    base = turn.record if turn.record is not None else turn.new_record(head)
    try:
        turn.put(RepoRecord(base.layer, base.version, base.commit, base.url, (head, target)))
    except (OSError, ManifestError) as exc:
        return Done(FAILED, f"its record cannot be written ({exc}); not updated", notes)
    before = Before.read(git, turn.git_dir)
    for index, (step, end) in enumerate(steps):
        status, printed, error = git.run(*step, change=True)
        said_by_git = (printed + error).rstrip()
        if status == 0:
            continue
        if _arrived(git, end, want):
            notes.append(f"moved, but `git {step[0]}` exited {status}:\n{said_by_git}")
            continue
        if index > 0:  # undo the first step: back where it was
            back = ["switch", "-q", "--no-overwrite-ignore", "--detach", before.head]
            if before.symbolic is not None:
                back = [
                    "switch",
                    "-q",
                    "--no-overwrite-ignore",
                    before.symbolic[len("refs/heads/") :],
                ]
            git.run(*back, change=True)
        after = Before.read(git, turn.git_dir)
        if after == before:
            if turn.record is not None:
                turn.put(turn.record)  # without the moving line
            return Done(
                LEFT,
                f"`git {step[0]}` exited {status}; left as it was:\n{said_by_git}",
                notes,
            )
        return Done(
            FAILED,
            f"`git {step[0]}` exited {status} and left the repo changed: HEAD was"
            f" {before.head[:12]} ({before.symbolic or 'detached'}), is {after.head[:12]}"
            f" ({after.symbolic or 'detached'}); `git status` shows the rest, and nothing more"
            f" was run here:\n{said_by_git}",
            notes,
        )
    if not _arrived(git, target, want):
        return Done(
            FAILED,
            f"git exited 0, and the repo is not on {target[:12]} with no tracked changes;"
            " `git status` shows what it left, and nothing more was run here",
            notes,
        )
    if (git.place / ".gitmodules").is_file():
        notes.append(f"submodules not updated: git -C {quoted(git.place)} submodule update")
    turn.put(turn.new_record(target))
    return Done(UPDATED, said, notes, commit=target)


def _arrived(git: Git, target: str, want: Optional[str]) -> bool:
    if git.out("rev-parse", "HEAD") != target:
        return False
    if git.out("symbolic-ref", "-q", "HEAD") != want:
        return False
    return tracked_changes(git) == 0


def _repoint(git: Git, origin: str, url: str) -> Optional[Done]:
    """Point `origin` at `url` when every local branch, and `HEAD`, is on it; else leave it.
    Returns None when repointed. The probe's refs are removed however it ends."""
    try:
        status, printed, error = git.run(
            "-c",
            f"remote.{PROBE}.url={url}",
            "-c",
            f"remote.{PROBE}.fetch=+refs/heads/*:refs/remotes/{PROBE}/*",
            "fetch",
            "--no-tags",
            PROBE,
            prompt=True,
        )
        if status != 0:
            return Done(
                FAILED,
                f"the manifest's url changed to {url}, and fetching from it failed (origin stays"
                f" {origin}): `git fetch` exited {status}:\n{(printed + error).rstrip()}",
                fetch=True,
            )
        local = count(git, "--branches", "HEAD", "--not", f"--remotes={PROBE}")
        if local is None:
            return Done(LEFT, f"url changed to {url}; its commits cannot be counted")
        if local:
            names = []
            heads = git.out("for-each-ref", "--format=%(refname:short)", "refs/heads/") or ""
            for name in heads.splitlines():
                if count(git, f"refs/heads/{name}", "--not", f"--remotes={PROBE}"):
                    names.append(name)
            which = f" (branches {', '.join(names)})" if names else " (on HEAD)"
            return Done(
                LEFT,
                f"url changed to {url} but {local} local commits{which} are not on it; origin"
                f" stays {origin}",
            )
        status, _, error = git.run("remote", "set-url", "origin", url, change=True)
        if status != 0:
            return Done(FAILED, f"`git remote set-url origin` exited {status}: {error.strip()}")
        return None
    finally:
        delete_probe_refs(git)
