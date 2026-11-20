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

import fnmatch
import os
import re
import shlex
import stat
import subprocess
from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Callable, Dict, List, Optional, Sequence, Set, Tuple

from .manifest import version_ref
from .masking import mask_url, mask_urls, remember_url  # noqa: F401 (mask_urls: callers)
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
    "--prune",  # sync removes no ref; --no-prune, which it passes, is another word
    "-p",  # fetch's short form of --prune
    "-P",  # fetch's short form of --prune-tags
    "--prune-tags",  # removes local tags in a pruning fetch; --no-prune-tags is another word
    "--discard-changes",  # switch's way of throwing away local changes
    "switch -f",
    "branch -f",
    "push",
    "--force",
    "rebase",
    "pull",
    "--no-verify",
    "branch -d",
    "branch -D",
)

HEX = re.compile(r"[0-9a-f]{7,40}")
OBJECT_ID = re.compile(r"[0-9a-f]{40}|[0-9a-f]{64}")
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
    distro's lock, passed to every `git` that changes the work tree or the configuration.
    `options` are given to every call after `GIT_OPTIONS` (`status` turns a clone's helpers off
    with them; `sync` gives none)."""

    def __init__(self, place: Path, env: Env, lock: Optional[int], options: Sequence[str] = ()):
        self.place = place
        self.options = tuple(options)
        # Output this module reads runs in the C locale, so git's words are the ones the code
        # looks for; output that is only shown keeps the person's language (`shown`).
        self.shown_env = {**env, "GIT_EDITOR": "true"}
        self.env = {k: v for k, v in self.shown_env.items() if k != "LANGUAGE"}
        self.env["LC_ALL"] = "C"
        self.lock = lock

    def run(
        self,
        *args: str,
        change: bool = False,
        prompt: bool = False,
        stdin: Optional[str] = None,
        hold: bool = False,
        shown: bool = False,
    ) -> Tuple[int, str, str]:
        """Exit status, stdout and stderr. A call that may change the work tree or the
        configuration runs with the stop signals held, so it is not cut short by one here
        (a held signal is delivered when it has ended, and `git` inherits it held), and with
        the lock passed to it. A fetch (`hold`) is given the lock too, so a `sync` killed while
        it writes refs does not free the lock before it ends, but not the signals held: a
        Ctrl-C stops a fetch that hangs or asks for a password. Only a fetch may prompt. A
        call whose output is only shown, never read, runs in the person's locale (`shown`);
        every other in the C locale."""
        argv = ["git", "-C", str(self.place), *GIT_OPTIONS, *self.options, *args]
        kwargs = dict(
            input=stdin,
            capture_output=True,
            encoding="utf-8",
            errors="surrogateescape",
            check=False,
            env=self.shown_env if shown else self.env,
        )
        if stdin is None:
            kwargs["stdin"] = None if prompt else subprocess.DEVNULL
        fds = (self.lock,) if self.lock is not None else ()
        if change:
            with signals_held():
                done = subprocess.run(argv, pass_fds=fds, **kwargs)
        elif hold:
            done = subprocess.run(argv, pass_fds=fds, **kwargs)
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


def counted(number: int, word: str) -> str:
    """`1 commit`, `2 commits`."""
    return f"{number} {word}" if number == 1 else f"{number} {word}s"


def set_url_command(place: Path, url: str, key: str) -> str:
    """The command that sets `origin` to `url`. When the url holds credentials, they are not
    printed: the command says where the whole url is."""
    shown = mask_url(url)
    command = f"git -C {quoted(place)} remote set-url origin {quoted(shown)}"
    if shown != url:
        command += f", with the url of {key} as the manifest gives it in place of the one shown"
    return command


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
    """Remove the probe's refs: only refs under its own prefix, each as the ref itself
    (`--no-deref`), so a symbolic ref there is removed and what it points to is never touched.
    The one ref deletion of this module."""
    prefix = f"refs/remotes/{PROBE}/"
    refs = git.out("for-each-ref", "--format=%(refname)", prefix)
    for ref in (refs or "").splitlines():
        if ref.startswith(prefix):
            git.run("update-ref", "--no-deref", "-d", ref, change=True)


def probe_taken(git: Git) -> bool:
    """Whether the clone has a remote of the probe's reserved name (or git cannot say): then
    its refs are a person's, and `sync` neither probes nor removes them."""
    status, printed, _ = git.run(
        "config", "--get-regexp", rf"^remote\.{PROBE}\."
    )  # the name holds no regex character but `-`
    return status != 1 or bool(printed.strip())


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
                f" something else in its place (to let it go on: move it aside, mv"
                f" {quoted(place)} <elsewhere>)"
            )
            continue
        sub = Git(place, git.env, None)
        top = sub.out("rev-parse", "--show-toplevel")
        if top is None or os.path.realpath(top) != os.path.realpath(place):
            found.append(
                f"submodule {path} holds files and is not a repository of its own (to let it go"
                f" on: move them aside, mv {quoted(place)} <elsewhere>)"
            )
            continue
        sub_head = sub.out("rev-parse", "--verify", "-q", "HEAD")
        if sub_head != recorded:
            found.append(
                f"submodule {path} is on {(sub_head or 'no commit')[:12]}, not on"
                f" {recorded[:12]}, the commit recorded here, and the move changes that commit"
                f" (when it holds nothing of yours: git -C {quoted(git.place)} submodule update"
                f" -- {quoted(path)})"
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
        f"{counted(len(paths), 'path')} not tracked here {'is' if len(paths) == 1 else 'are'} in"
        " the way of incoming files: "
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


def same_version(
    one: Optional[str],
    other: Optional[str],
    plain_one: Optional[str] = None,
    plain_other: Optional[str] = None,
) -> bool:
    """Two manifest versions name the same branch, tag or commit, read as vcstool reads them:
    `heads/v1` and `tags/v1` are not the same. A version written without `heads/` or `tags/`
    is of the kind given for it (`plain_one`, `plain_other`: BRANCH, TAG or COMMIT, what it
    named when it was looked up), so `main` that named a branch is `heads/main` and not
    `tags/main`; one whose kind is not given is taken as the same as either kind."""
    if one is None or other is None:
        return one is other
    kind_one, name_one = version_ref(one)
    kind_other, name_other = version_ref(other)
    kind_one = kind_one or plain_one
    kind_other = kind_other or plain_other
    return name_one == name_other and (
        kind_one is None or kind_other is None or kind_one == kind_other
    )


def recorded_kind(git: Git, record: RepoRecord, branch: Optional[str]) -> Optional[str]:
    """What the recorded version named, for a repo where `sync` last put it (`_on_recorded`),
    or None when that cannot be told. The record keeps the version as written, so a version
    without `heads/` or `tags/` is read from where the repo is: on the branch of its name, a
    branch; detached at the recorded commit, a commit when the version is hex digits that
    commit starts with, a tag when the tag of its name here is at that commit and the local
    branch of its name is not, and a branch when the branch is and the tag is not. Otherwise
    it cannot be told: both are at the recorded commit (or, on the branch, the tag is too),
    or neither is (a tag origin moved since, or a branch that moved on after a person
    detached it); the caller then reads the record as the manifest's version when the names
    are the same, as before this rule, so a repo is never moved for a kind it cannot tell."""
    if record.version is None:
        return BRANCH
    kind, name = version_ref(record.version)
    if kind is not None:
        return kind
    commit = record.commit or ""
    tag_there = git.out("rev-parse", "--verify", "-q", f"refs/tags/{name}^{{commit}}") == commit
    if branch is not None:
        return None if tag_there else BRANCH
    if HEX.fullmatch(name) and commit.startswith(name):
        return COMMIT
    branch_there = git.out("rev-parse", "--verify", "-q", f"refs/heads/{name}") == commit
    if tag_there != branch_there:
        return TAG if tag_there else BRANCH
    return None


def ask_origin(git: Git, *patterns: str) -> Tuple[Optional[Dict[str, str]], str]:
    """What origin has now, as `git ls-remote origin <patterns>` lists it: ref to object (a
    peeled tag's commit under `<tag>^{}`); with git's message when it cannot be asked."""
    status, printed, error = git.run("ls-remote", "origin", *patterns, prompt=True)
    if status != 0:
        return None, f"`git ls-remote origin` exited {status}:\n{error.rstrip()}"
    theirs = {}
    for line in printed.splitlines():
        oid, _, ref = line.partition("\t")
        theirs[ref] = oid
    return theirs, ""


Asker = Callable[..., Tuple[Optional[Dict[str, str]], str]]


def ask_local(git: Git, *patterns: str) -> Tuple[Optional[Dict[str, str]], str]:
    """What origin had when the clone last fetched it, read from the refs here and in the shape
    `ask_origin` gives, asking nothing over the network: each remote-tracking ref of origin as
    origin's branch (`refs/heads/<name>`), and each tag here as origin's tag, a peeled tag's
    commit under `<tag>^{}`; only the refs the `patterns` match, as `ls-remote` matches them.
    A tag made here and a remote-tracking ref left from a branch origin deleted count as
    origin's: offline they cannot be told apart. A tag of a tag is peeled to the end, as
    `ls-remote` peels it (a git that peels `%(*objectname)` one level only leaves a tag there,
    and `rev-parse <tag>^{}` peels the rest). The lines are split at `\n` only: a ref name holds
    no control character and no space, but may hold U+2028 and the like, which `splitlines`
    would split at."""
    status, printed, error = git.run(
        "for-each-ref", "--format=%(refname) %(objectname) %(*objectname) %(*objecttype)",
        "refs/remotes/origin/", "refs/tags/",
    )  # fmt: skip
    if status != 0:
        return None, f"`git for-each-ref` exited {status}:\n{error.rstrip()}"
    found: Dict[str, str] = {}
    prefix = "refs/remotes/origin/"
    for line in printed.split("\n"):
        if not line:
            continue
        ref, _, rest = line.partition(" ")
        oid, _, rest = rest.partition(" ")
        peeled, _, peeled_type = rest.partition(" ")
        if peeled_type == "tag":
            peeled = git.out("rev-parse", "--verify", "-q", f"{ref}^{{}}") or ""
            if not peeled:
                return None, f"tag {ref} cannot be peeled to the object it names"
        if ref.startswith(prefix):
            if ref == f"{prefix}HEAD":
                continue
            ref = "refs/heads/" + ref[len(prefix) :]
        found[ref] = oid
        if peeled:
            found[f"{ref}^{{}}"] = peeled

    def asked(ref: str) -> bool:
        plain = ref[: -len("^{}")] if ref.endswith("^{}") else ref
        return any(fnmatch.fnmatchcase(plain, pattern) for pattern in patterns)

    return {ref: oid for ref, oid in found.items() if not patterns or asked(ref)}, ""


def find_version(
    git: Git,
    version: Optional[str],
    record: Optional[RepoRecord] = None,
    ask: Optional[Asker] = None,
) -> Tuple[Optional[Version], Optional[str], bool]:
    """The manifest's version on origin, after a fetch: (version, problem, fetch). Origin is
    asked for the branch or tag itself (`ls-remote`), since `sync` prunes nothing and a
    remote-tracking ref may be left from a branch origin has deleted. A tag counts only when
    origin has it and the tag here is the same object; a commit when it is there and is named
    by 7 to 40 hex digits (whether origin holds it is `commit_on_origin`). `ask` is how origin
    is asked: `ask_origin` when it is not given (looked up at the call, so a test can replace
    it), or `ask_local`, which reads the refs here and asks nothing over the network."""
    if ask is None:
        ask = ask_origin
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
        theirs, problem = ask(git, f"refs/heads/{name}")
        if theirs is None:
            return None, problem, True
        if f"refs/heads/{name}" not in theirs:
            return (
                None,
                f"origin's default branch as recorded here, {name}, is gone from origin;"
                " `git -C <place> remote set-head origin --auto` reads it from origin again",
                False,
            )
        return _branch(git, name, theirs[f"refs/heads/{name}"])
    # `heads/x` is the branch x and `tags/x` the tag x, as vcstool reads them.
    kind, name = version_ref(version)
    patterns = []
    if kind != TAG:
        patterns.append(f"refs/heads/{name}")
    if kind != BRANCH:
        patterns.append(f"refs/tags/{name}")
    theirs, problem = ask(git, *patterns)
    if theirs is None:
        return None, problem, True
    on_branch = theirs.get(f"refs/heads/{name}")
    on_tag = theirs.get(f"refs/tags/{name}")
    if on_branch is not None and on_tag is not None:
        return None, f"version {version} is both a branch and a tag on origin", False
    if on_branch is not None:
        return _branch(git, name, on_branch)
    local_tag = None
    if kind != BRANCH:
        local_tag = git.out("rev-parse", "--verify", "-q", f"refs/tags/{name}")
    if on_tag is not None:
        if local_tag is None:
            return None, f"origin's tag {name} was not fetched here; sync again", True
        if local_tag != on_tag:
            return None, _tag_clash(git, name, theirs, record), False
        tag = git.out("rev-parse", "--verify", "-q", f"refs/tags/{name}^{{commit}}")
        if tag is None:
            what = git.out("cat-file", "-t", f"refs/tags/{name}^{{}}") or "object"
            return (
                None,
                f"tag {name} names a {what}, not a commit; sync follows a tag only to a commit",
                False,
            )
        return Version(TAG, name, tag), None, False
    if local_tag is not None:
        return None, f"version {version} is a tag here, and origin has no such tag", False
    if kind is None and HEX.fullmatch(version):
        commit = git.out("rev-parse", "--verify", "-q", f"{version}^{{commit}}")
        if commit is not None and commit.startswith(version):
            return Version(COMMIT, version, commit), None, False
        if git.out("rev-parse", "--is-shallow-repository") == "true":
            return (
                None,
                f"version {version} is not in this shallow clone's history; sync never deepens"
                " a clone (`git -C <place> fetch --unshallow origin`, run by hand, makes it"
                " whole)",
                False,
            )
    stale = f"refs/remotes/origin/{name}"
    if kind != TAG and git.out("rev-parse", "--verify", "-q", stale) is not None:
        return (
            None,
            f"version {version} is not on origin: origin no longer has the branch {name}"
            f" ({stale} here is left from an earlier fetch; sync removes no remote-tracking"
            " ref)",
            False,
        )
    return None, f"version {version} is not on origin", False


def _branch(git: Git, name: str, theirs: str) -> Tuple[Optional[Version], Optional[str], bool]:
    """Origin's branch `name`, which origin has at `theirs`, as the fetch just brought it."""
    here = git.out("rev-parse", "--verify", "-q", f"refs/remotes/origin/{name}^{{commit}}")
    if here != theirs:
        return (
            None,
            f"origin's {name} is at {theirs[:12]} and was fetched here as"
            f" {(here or 'nothing')[:12]}; origin changed it meanwhile: sync again",
            True,
        )
    return Version(BRANCH, name, here), None, False


def _tag_clash(git: Git, version: str, theirs: Dict[str, str], record: Optional[RepoRecord]) -> str:
    """A tag here and origin's tag of the same name name other objects. Origin "moved" it only
    when the record shows `sync` followed that tag at the commit it holds here; only then is
    deleting it the advice, since then origin had it and HEAD holds its commit."""
    here = git.out("rev-parse", "--verify", "-q", f"refs/tags/{version}^{{commit}}") or "?"
    origins = theirs.get(f"refs/tags/{version}^{{}}") or theirs.get(f"refs/tags/{version}", "?")
    followed = record is not None and record.version is not None
    if followed and version_ref(record.version) in ((None, version), (TAG, version)):
        followed = record.commit == here
    else:
        followed = False
    if followed:
        return (
            f"tag {version} was moved on origin, from {here[:12]}, where sync followed it, to"
            f" {origins[:12]}; sync never replaces a tag: to take origin's, git -C <place> tag"
            f" -d {quoted(version)}, then sync again"
        )
    return (
        f"a tag {version} is here at {here[:12]}, and origin's tag {version} is at"
        f" {origins[:12]}; sync never replaces a tag, and which to keep is for a person to"
        " decide"
    )


def commit_on_origin(
    git: Git, commit: str, ask: Optional[Asker] = None
) -> Tuple[Optional[bool], str]:
    """Whether `commit` is reachable, in the history the clone has, from a branch or a tag that
    origin has now: a ref here that holds it, which origin lists at the same object (a
    remote-tracking ref left from a branch origin deleted does not count); with git's message
    when that cannot be told. `ask` as for `find_version`."""
    if ask is None:
        ask = ask_origin
    status, printed, error = git.run(
        "for-each-ref", "--contains", commit, "--format=%(refname) %(objectname)",
        "refs/remotes/origin/", "refs/tags/",
    )  # fmt: skip
    if status != 0:
        return None, f"`git for-each-ref --contains` exited {status}:\n{error.rstrip()}"
    holders = {}
    for line in printed.splitlines():
        ref, _, oid = line.partition(" ")
        if ref.startswith("refs/remotes/origin/") and ref != "refs/remotes/origin/HEAD":
            holders["refs/heads/" + ref[len("refs/remotes/origin/") :]] = oid
        elif ref.startswith("refs/tags/"):
            holders[ref] = oid
    if not holders:
        return False, ""
    theirs, problem = ask(git, "refs/heads/*", "refs/tags/*")
    if theirs is None:
        return None, problem
    return any(theirs.get(ref) == oid for ref, oid in holders.items()), ""


def ancestor(git: Git, older: str, newer: str) -> bool:
    return git.ok("merge-base", "--is-ancestor", older, newer)


def count(git: Git, *args: str) -> Optional[int]:
    printed = git.out("rev-list", "--count", *args)
    return int(printed) if printed is not None and printed.isdigit() else None


@dataclass
class WorkTree:
    path: str
    head: Optional[str]  # its HEAD's commit; None for a bare entry
    branch: Optional[str]  # the branch checked out there; None when detached


def work_trees(git: Git) -> Optional[List[WorkTree]]:
    """Every work tree of the repo, this one included, as `git worktree list` gives them; None
    when git cannot list them."""
    status, printed, _ = git.run("worktree", "list", "--porcelain")
    if status != 0:
        return None
    found: List[WorkTree] = []
    for line in printed.splitlines():
        if line.startswith("worktree "):
            found.append(WorkTree(line[len("worktree ") :], None, None))
        elif found and line.startswith("HEAD "):
            found[-1].head = line[len("HEAD ") :]
        elif found and line.startswith("branch refs/heads/"):
            found[-1].branch = line[len("branch refs/heads/") :]
    return found


def _text(path: Path) -> Optional[str]:
    """A file's text, or None when it cannot be read."""
    try:
        return path.read_text(encoding="utf-8", errors="surrogateescape")
    except OSError:
        return None


def _git_dirs(git: Git, trees: Sequence[WorkTree]) -> Optional[List[Tuple[str, Path]]]:
    """The git directory of every work tree, with the path of its files: the main one (the
    common directory, at the first path `git worktree list` gives) and each linked one under
    `worktrees/` (at the path its `gitdir` file names); None when they cannot be read."""
    common = git.out("rev-parse", "--git-common-dir")
    if common is None:
        return None
    common_dir = Path(os.path.realpath(git.place / common))
    found = [(trees[0].path if trees else str(common_dir), common_dir)]
    linked = common_dir / "worktrees"
    try:
        entries = sorted(linked.iterdir()) if linked.is_dir() else []
    except OSError:
        return None
    for admin in entries:
        if not admin.is_dir():
            continue
        gitdir = _text(admin / "gitdir")
        path = str(Path(gitdir.strip()).parent) if gitdir and gitdir.strip() else str(admin)
        found.append((path, admin))
    return found


def _operation_holding(admin: Path, branch: str) -> Optional[str]:
    """Why the work tree whose git directory is `admin` holds `branch` through an operation in
    progress there, as git itself counts it (`git branch -f` refuses such a branch): a rebase
    whose `head-name` is that branch, which it returns to; a rebase with `--update-refs` that
    will set it; a bisect started on it (`BISECT_START` holds the branch's name, or a commit
    for one started detached). When an operation is there and what it returns to cannot be
    read, every branch is held. A `git am`, merge, cherry-pick or revert works on `HEAD` as
    it is: on a branch, `git worktree list` names it; detached, it holds none."""
    ref = f"refs/heads/{branch}"
    for name in ("rebase-merge", "rebase-apply"):
        if not os.path.lexists(admin / name):
            continue
        head_name = _text(admin / name / "head-name")
        if head_name is not None:
            if head_name.strip() == ref:
                return f"a rebase of {branch} is stopped there"
        elif name == "rebase-apply" and os.path.lexists(admin / name / "applying"):
            pass  # `git am`: on HEAD as it is
        else:
            return "a rebase is in progress there and the branch it returns to cannot be read"
        updates = admin / name / "update-refs"
        if os.path.lexists(updates):
            listed = _text(updates)
            if listed is None:
                return "a rebase there updates branches (`--update-refs`) that cannot be read"
            if ref in listed.splitlines()[0::3]:
                return f"a rebase there will set {branch} when it ends (`--update-refs`)"
    if os.path.lexists(admin / "BISECT_START"):
        started = _text(admin / "BISECT_START")
        if started is None:
            return "a bisect is in progress there and the branch it returns to cannot be read"
        if started.strip() in (branch, ref):
            return f"a bisect started on {branch} is in progress there"
    return None


def worktree_holding(git: Git, branch: str) -> Optional[str]:
    """Another work tree that holds `branch`, and how, if one does: it has the branch checked
    out (a linked work tree made with `git worktree add -f` can share the branch of this one),
    or an operation in progress there will return to it or set it (`_operation_holding`).
    When the work trees cannot be listed or read, that is said, so the caller leaves the repo
    alone too."""
    trees = work_trees(git)
    if trees is None:
        return "a work tree git cannot list (`git worktree list` fails)"
    here = os.path.realpath(git.place)
    for tree in trees:
        if tree.branch == branch and os.path.realpath(tree.path) != here:
            return _held_in(git, tree.path, "it is checked out there")
    admins = _git_dirs(git, trees)
    own = git.out("rev-parse", "--absolute-git-dir")
    if admins is None or own is None:
        return "work trees whose git directories cannot be read"
    for path, admin in admins:
        if os.path.realpath(admin) == os.path.realpath(own):
            continue
        why = _operation_holding(admin, branch)
        if why is not None:
            return _held_in(git, path, why)
    return None


def _held_in(git: Git, path: str, why: str) -> str:
    """The work tree at `path` that holds a branch, and why; when its directory is gone, the
    command that removes git's entry for it."""
    held = f"the work tree {path} ({why})"
    if not os.path.lexists(path):
        held += (
            f"; that directory no longer exists: if it is gone for good, not on a drive that is"
            f" not mounted, git -C {quoted(git.place)} worktree prune removes git's entries for"
            " work trees whose directories are gone"
        )
    return held


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
        self.symbolic: Optional[str] = None  # HEAD's branch ref when the rules read it

    def new_record(self, commit: str, moving: Optional[Tuple[str, str]] = None) -> RepoRecord:
        return RepoRecord(self.layer, self.repo.version, commit, self.repo.url, moving)

    def left(self, detail: str) -> Done:
        """Left as it is. The record is unchanged, except that the manifest's url is recorded
        when it is not yet."""
        record = self.record
        if record is not None and record.url != self.repo.url:
            self.put(replace(record, url=self.repo.url))
        return Done(LEFT, detail, self.notes)

    def current(self, head: str, said: str, where: str, kind: str) -> Done:
        """On the manifest's version already. When only the record was behind (the manifest
        changed to where the clone already is, or a person moved it there), one line says so;
        a record that gains only the manifest's url, or a first record, says nothing."""
        new = self.new_record(head)
        if self.record != new:
            old = self.record
            if old is not None and not same_version(old.version, self.repo.version, None, kind):
                was = old.version or "no version"
                self.notes.append(f"already on {where}; record updated (was {was})")
            elif old is not None and old.commit != head:
                self.notes.append(f"already on {where} at {head[:12]}; record updated")
            self.put(new)
        return Done(CURRENT, said, self.notes, commit=head)


# Why a repo that is there is left at the first checks (`Blocked.kind`): `sync` says each in
# its own words and leaves the repo; `status` maps the kind to a state.
NOT_GIT, NO_COMMIT = "not-git", "no-commit"
OPERATION, INDEX_LOCK, SPARSE = "in-progress", "index-lock", "sparse"
NO_ORIGIN, SEVERAL_ORIGINS = "no-origin", "several-origins"


@dataclass
class Blocked:
    """A first check that stops `sync` at a repo: what kind of check, and what `sync` says."""

    kind: str
    text: str


def stopped_move(record: Optional[RepoRecord], head: str) -> Optional[str]:
    """The text for a `sync` stopped while moving the repo, when the record's `moving` line
    names the commit the repo is on; None otherwise."""
    if record is None or record.moving is None or head not in record.moving:
        return None
    return (
        f"a sync was stopped while moving this repo from {record.moving[0][:12]} to"
        f" {record.moving[1][:12]}; `git status` shows what it left"
    )


def blocked_early(git: Git) -> Tuple[Optional[Blocked], Optional[Path], Optional[str]]:
    """The first two checks, in order: the place is a git repository of its own, and it has a
    commit checked out. Returns what stops at them, if anything, with the git directory and
    `HEAD`'s commit as far as they were read."""
    status, printed, _ = git.run("rev-parse", "--show-toplevel")
    if status != 0 or os.path.realpath(printed.strip()) != os.path.realpath(git.place):
        return Blocked(NOT_GIT, "is not a git repository of its own"), None, None
    git_dir = Path(git.out("rev-parse", "--absolute-git-dir") or git.place / ".git")
    head = git.out("rev-parse", "--verify", "-q", "HEAD")
    if head is None:
        return Blocked(NO_COMMIT, "has no commit checked out"), git_dir, None
    return None, git_dir, head


def blocked_late(
    git: Git, git_dir: Path, record: Optional[RepoRecord], head: str
) -> Tuple[Optional[Blocked], Optional[str]]:
    """The checks after `blocked_early` (and after `sync` drops a `moving` line that no longer
    describes the repo), in order: no operation in progress, no `index.lock`, not a sparse
    checkout, exactly one `origin` url. Returns what stops at them, if anything, and the url of
    `origin` when there is one. The in-progress and `index.lock` texts carry the stopped-move
    text (`stopped_move`). Reads only."""
    stopped = stopped_move(record, head)
    also = f"; {stopped}" if stopped else ""
    for name, what in IN_PROGRESS:
        if os.path.lexists(git_dir / name):
            return Blocked(OPERATION, f"{what} is in progress{also}"), None
    if os.path.lexists(git_dir / "index.lock"):
        text = f"index.lock exists; another git may be running here{also}"
        return Blocked(INDEX_LOCK, text), None
    status, printed, _ = git.run("config", "--type=bool", "--get", "core.sparseCheckout")
    if status == 0 and printed.strip() == "true":
        return (
            Blocked(
                SPARSE,
                "is a sparse checkout; sync does not update one (its skip-worktree files are"
                " not changes): update it by hand",
            ),
            None,
        )
    status, printed, _ = git.run("config", "--get-all", "remote.origin.url")
    urls = printed.splitlines() if status == 0 else []
    if len(urls) != 1:
        kind = NO_ORIGIN if not urls else SEVERAL_ORIGINS
        return Blocked(kind, "has no single origin"), None
    return None, urls[0]


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
    blocked, git_dir, head = blocked_early(git)
    if blocked is not None:
        return Done(LEFT, blocked.text)
    assert git_dir is not None and head is not None
    stopped = stopped_move(record, head)
    if stopped is None and record is not None and record.moving is not None:
        # The line no longer describes the repo (a person moved it since): it goes.
        record = replace(record, moving=None)
        write(record)
    also = f"; {stopped}" if stopped else ""
    blocked, origin = blocked_late(git, git_dir, record, head)
    if blocked is not None:
        return Done(LEFT, blocked.text)
    assert origin is not None
    for known in (origin, repo.url, record.url if record is not None else None):
        remember_url(known)
    taken = probe_taken(git)
    if not taken:
        delete_probe_refs(git)
    url = repo.url
    notes: List[str] = []
    by_hand = None
    if same_url(origin, url):
        pass
    elif record is not None and record.url is not None and same_url(origin, record.url):
        # The manifest changed the url since the repo was recorded: repoint, unless a local
        # branch, or the HEAD of a work tree, has commits the new url does not have.
        if taken:
            return Done(
                LEFT,
                f"url changed to {mask_url(url)}, and a remote named {PROBE} is set here, a name"
                f" sync keeps for checking a new url; origin stays {mask_url(origin)} (to let"
                f" sync check it: git -C {quoted(place)} remote rename {PROBE} <another name>)",
            )
        done = _repoint(git, origin, url)
        if done is not None:
            return done
        # Recorded at once, so a fetch or version lookup that fails next does not leave the
        # new url read as one a person set.
        record = replace(record, url=url)
        write(record)
        notes.append(f"origin repointed from {mask_url(origin)} to {mask_url(url)}")
    else:
        by_hand = (
            f"origin is {mask_url(origin)}, the manifest says {mask_url(url)}; left as set"
            f" (to use the manifest's: {set_url_command(place, url, repo.key)})"
        )
        notes.append(by_hand)
    turn = _Turn(git, git_dir, repo, layer, record, write, notes)

    changes = tracked_changes(git)
    if changes is None:
        return turn.left("`git status` fails here")
    if changes:
        return turn.left(f"has uncommitted changes ({counted(changes, 'file')}){also}")

    # The refspec is sync's own, and --refmap= keeps git from also applying the person's
    # remote.origin.fetch; --no-prune and --no-prune-tags keep any fetch.prune or
    # remote.origin.prune from removing a ref: the fetch writes origin's remote-tracking refs
    # and new tags, and removes nothing.
    fetch_args = [
        "--no-prune",
        "--no-prune-tags",
        "--no-recurse-submodules",
        "--refmap=",
        "origin",
        "+refs/heads/*:refs/remotes/origin/*",
    ]
    status, printed, error = git.run("fetch", "--tags", *fetch_args, prompt=True, hold=True)
    clashes = CLOBBERED_TAG.findall(error) if status != 0 else []
    if clashes:
        # git updates each ref on its own and exits 1 for a tag it would not replace; the
        # branches are fetched again without tags, so the result rests on an exit status of 0.
        status, printed, error = git.run("fetch", "--no-tags", *fetch_args, prompt=True, hold=True)
        version_kind, version_name = version_ref(repo.version or "")
        for tag in clashes:
            if version_kind == BRANCH or tag != version_name:
                notes.append(
                    f"tag {tag} here and origin's tag {tag} name other objects; sync never"
                    " replaces a tag, and this one is not the manifest's version"
                )
    if status != 0:
        conflicts = _ref_conflicts(git) if "local refs could not be updated" in error else []
        if conflicts:
            return Done(FAILED, _conflicts_note(git, conflicts), notes)
        detail = f"`git fetch origin` exited {status}:\n{(printed + error).rstrip()}"
        return Done(FAILED, detail, notes, fetch=True)

    found, problem, fetch = find_version(git, repo.version, record)
    if found is None:
        problem = (problem or "").replace("<place>", quoted(place))
        if by_hand is not None and not fetch:
            problem += f"; origin was set by hand: {by_hand}"
        return Done(FAILED, problem, notes, fetch=fetch)
    wanted = repo.version if repo.version is not None else f"origin's default branch {found.name}"
    if found.kind == COMMIT:
        on_origin, said_by_git = commit_on_origin(git, found.target)
        if on_origin is None:
            return Done(FAILED, said_by_git, notes, fetch=True)
        if not on_origin:
            return turn.left(
                f"version {repo.version} is a commit here that no branch of origin, and no tag"
                " origin has, holds; not followed"
            )

    symbolic = git.out("symbolic-ref", "-q", "HEAD")
    turn.symbolic = symbolic
    branch = None
    if symbolic is not None and symbolic.startswith("refs/heads/"):
        branch = symbolic[len("refs/heads/") :]
    if branch is not None:
        ahead = count(git, "HEAD", "--not", "--remotes=origin")
        if ahead is None:
            return turn.left("the commits not on origin cannot be counted")
        if ahead:
            detail = f"has {counted(ahead, 'commit')} not on origin"
            if found.kind == BRANCH and branch == found.name:
                if not ancestor(git, found.target, head):
                    detail += (
                        f"; to bring origin's in by hand: git -C {quoted(place)} pull --rebase"
                        f" origin {quoted(found.name)}"
                    )
                else:
                    detail += (
                        f"; origin's {found.name} has nothing this clone lacks, so the commits"
                        " are only here; to publish them (sync never pushes): git -C"
                        f" {quoted(place)} push origin {quoted(branch)}"
                    )
            else:
                detail += f"; the manifest names {wanted}; it is not switched"
            return turn.left(detail)

    # On the manifest's version.
    if found.kind == BRANCH and branch == found.name:
        if head == found.target:
            return turn.current(head, "up to date", found.name, found.kind)
        if not ancestor(git, head, found.target):
            return turn.left(
                f"origin's {found.name} no longer contains this commit (rewritten upstream)"
            )
        holder = worktree_holding(git, branch)
        if holder is not None:
            # A fast-forward moves the branch under that work tree, whose files would stay
            # where they were: git would show its new commits there as staged changes.
            return turn.left(f"branch {branch} is held by {holder}; not fast-forwarded")
        moved = count(git, f"{head}..{found.target}") or 0
        steps = [
            (["merge", "--ff-only", "--no-overwrite-ignore", "-q", found.target], found.target)
        ]
        said = f"fast-forwarded {counted(moved, 'commit')}"
        return _change(turn, head, [found.target], steps, symbolic, said)
    if found.kind != BRANCH and branch is None and head == found.target:
        return turn.current(head, f"pinned at {found.name}", found.name, found.kind)

    # On the recorded version, which the manifest has changed: moved to the new one.
    if record is not None and _on_recorded(git, record, head, branch):
        # The kinds count: a recorded branch `x` and a pin `tags/x` are two versions.
        was = recorded_kind(git, record, branch)
        if not same_version(record.version, repo.version, was, found.kind):
            said = None
            if record.version is not None and version_ref(record.version)[1] == found.name:
                said = f"moved from {was} {found.name} to {found.kind} {found.name}"
            return _move(turn, head, found, said)
        # The same tag, detached where sync put it, and origin's tag now names another commit
        # (the person deleted the stale local tag, as the failed fetch said): followed.
        if found.kind == TAG and branch is None:
            said = f"tag {found.name} was moved on origin: moved from {head[:12]} to it"
            return _move(turn, head, found, said)
        name = version_ref(record.version or "")[1]
        tag = git.out("rev-parse", "--verify", "-q", f"refs/tags/{name}^{{commit}}")
        if was is None and tag is not None and tag == record.commit:
            # The tag of the recorded name is at the recorded commit, and so is the branch:
            # which one sync followed cannot be told, so the repo is not moved, and the report
            # says why rather than calling it a person's move.
            where = f"branch {branch}" if branch is not None else f"a detached HEAD at {head[:12]}"
            also = "" if branch is not None else f", and so is the branch {name}"
            return turn.left(
                f"it is on {where}, and the record ({record.version}) does not say whether sync"
                f" followed the branch or the tag {name}: the tag {name} here is at the recorded"
                f" commit {(record.commit or '')[:12]}{also}; the manifest names {wanted}; not"
                " moved"
            )

    where = branch if branch is not None else f"a detached HEAD at {head[:12]}"
    detail = f"moved by a person: it is on {where}; the manifest names {wanted}"
    if record is not None and not same_version(record.version, repo.version, None, found.kind):
        detail += f" (recorded: {record.version or 'no version'})"
    return turn.left(detail)


@dataclass
class Standing:
    """Where a repo stands against the manifest's version, by the rules `sync` follows after
    its first checks (rules 9 to 12 of "sync"): on it or not, the text, and, on the manifest's
    branch, how many commits of origin's branch it lacks (None elsewhere)."""

    on_version: bool
    text: str
    behind: Optional[int] = None


def standing(
    git: Git,
    repo: Selected,
    record: Optional[RepoRecord],
    found: Version,
    head: str,
    branch: Optional[str],
    unpushed: Optional[int],
    held: Optional[str],
) -> Standing:
    """`status`'s reading of `update_repo`'s rules after the fetch, for a repo whose version
    `found` was found: it acts on nothing. It is a second copy of those rules, not code they
    share; `tests/test_status_agrees_with_sync.py` holds the two in step. `update_repo` reaches
    its rules for the manifest's branch only with no commits that are not on origin (it leaves
    the repo at rule 9 first); this answers those cases too, as `sync` treats them: a branch
    with commits only here is on the manifest's version, and one that origin's branch does not
    contain while it has none only here was rewritten upstream.

    `held` is what stops `sync` at the repo before these rules, as the caller read it (a
    remote of the probe's name with the url changed, then uncommitted changes), or None. Every
    sentence here that says what `sync` does to the repo says that instead when it is given.
    Otherwise a fast-forward, and a move from the recorded version that the manifest changed,
    are said as what `sync` tries: `_change` can still stop either (a path or a submodule in the
    way), and so can a repoint of origin that fails. For the move, the checks `sync` makes
    first are read here, in its order: commits not on origin, then the new branch held by
    another work tree or a local branch of it with commits not on origin. Reads only."""
    wanted = repo.version if repo.version is not None else f"origin's default branch {found.name}"
    if found.kind == BRANCH and branch == found.name:
        if head == found.target:
            return Standing(True, f"on {found.name}, as origin's was when last fetched", 0)
        behind = count(git, f"{head}..{found.target}")
        if ancestor(git, head, found.target):
            text = (
                f"on {found.name}, behind origin's as last fetched (sync tries to fast-forward"
                " it)"
            )
            holder = worktree_holding(git, branch)
            if held is not None:
                text = f"on {found.name}, behind origin's as last fetched; {held}"
            elif holder is not None:
                text = (
                    f"on {found.name}, behind origin's as last fetched; branch {branch} is held"
                    f" by {holder}, so sync does not fast-forward it"
                )
            return Standing(True, text, behind)
        if unpushed:
            text = f"on {found.name}, with {counted(unpushed, 'commit')} not on origin"
            if not ancestor(git, found.target, head):
                text += (
                    f"; to bring origin's in by hand: git -C {quoted(git.place)} pull --rebase"
                    f" origin {quoted(found.name)}"
                )
            else:
                text += (
                    f"; origin's {found.name} has nothing this clone lacks, so the commits are"
                    f" only here; to publish them (sync never pushes): git -C {quoted(git.place)}"
                    f" push origin {quoted(branch)}"
                )
            return Standing(True, text, behind)
        return Standing(
            False,
            f"origin's {found.name} no longer contains this commit (rewritten upstream)",
            behind,
        )
    if found.kind != BRANCH and branch is None and head == found.target:
        return Standing(True, f"pinned at {found.name}")
    where = f"branch {branch}" if branch is not None else f"a detached HEAD at {head[:12]}"
    if record is not None and _on_recorded(git, record, head, branch):
        was = recorded_kind(git, record, branch)
        if not same_version(record.version, repo.version, was, found.kind):
            return Standing(
                False,
                f"it is on {where}, the version recorded ({record.version or 'no version'});"
                f" the manifest now names {wanted}; " + _would_move(git, found, held, unpushed),
            )
        if found.kind == TAG and branch is None:
            return Standing(
                False,
                f"tag {found.name} here is now at {found.target[:12]}, and the repo is at"
                f" {head[:12]}, where sync followed it; " + _would_move(git, found, held, unpushed),
            )
        name = version_ref(record.version or "")[1]
        tag = git.out("rev-parse", "--verify", "-q", f"refs/tags/{name}^{{commit}}")
        if was is None and tag is not None and tag == record.commit:
            also = "" if branch is not None else f", and so is the branch {name}"
            return Standing(
                False,
                f"it is on {where}, and the record ({record.version}) does not say whether sync"
                f" followed the branch or the tag {name}: the tag {name} here is at the recorded"
                f" commit {(record.commit or '')[:12]}{also}; the manifest names {wanted}; sync"
                " does not move it",
            )
    detail = f"it is on {where}; the manifest names {wanted}"
    if record is not None and not same_version(record.version, repo.version, None, found.kind):
        detail += f" (recorded: {record.version or 'no version'})"
    return Standing(False, detail + "; sync does not move it")


def _would_move(git: Git, found: Version, held: Optional[str], unpushed: Optional[int]) -> str:
    """Whether `sync` would try to move a repo from the recorded version to `found`, by the
    checks it makes first (`held`, as for `standing`); `_change` can still stop a move (a path
    or a submodule in the way), so the most it says is that it would try."""
    if held is not None:
        return held
    if unpushed:
        return f"sync leaves it while it has {counted(unpushed, 'commit')} not on origin"
    if found.kind == BRANCH:
        holder = worktree_holding(git, found.name)
        if holder is not None:
            return f"sync leaves it: branch {found.name} is held by {holder}"
        local = git.out("rev-parse", "--verify", "-q", f"refs/heads/{found.name}")
        if local is not None and not ancestor(git, local, found.target):
            return f"sync leaves it: a local branch {found.name} has commits not on origin"
    return "sync would try to move it to that version"


def _on_recorded(git: Git, record: RepoRecord, head: str, branch: Optional[str]) -> bool:
    """Whether the repo is where `sync` last put it: on the recorded branch, or detached at the
    recorded commit (a tag or a commit); for a recorded version not given, on origin's
    default branch."""
    if branch is None:
        return head == record.commit
    if record.version is not None:
        kind, name = version_ref(record.version)
        return kind != TAG and branch == name
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
    # Before the switch, and before the fast-forward of a local branch: another work tree
    # holds the branch when it has it checked out, or a rebase or bisect there will return to
    # it (a rebase sets it at its end, even when it does not exist now).
    holder = worktree_holding(git, found.name)
    if holder is not None:
        return turn.left(f"branch {found.name} is held by {holder}; not switched")
    local = git.out("rev-parse", "--verify", "-q", want)
    if local is None:
        # The branch is made at origin's commit with no tracking, so the switch either does it
        # all or nothing; the upstream is set after, a step whose failure is a note.
        steps = [
            (
                ["switch", "-q", "--no-overwrite-ignore", "-c", found.name, "--no-track"]
                + [found.target],
                found.target,
            )
        ]
        return _change(turn, head, [found.target], steps, want, said, upstream=found.name)
    if not ancestor(git, local, found.target):
        return turn.left(f"a local branch {found.name} has commits not on origin; not switched")
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
    upstream: Optional[str] = None,
) -> Done:
    """Run `steps`, the calls that change the work tree, after the submodule and paths checks:
    each call with the commit it puts `HEAD` on; `want` is the symbolic `HEAD` (None: detached)
    every step ends on, and the last step's commit is the target. A `moving` line is recorded
    before the first call, and the record is written after the state is read and found right.
    Each call is judged by the state it leaves, not its exit status: one that exited non-zero
    (a failing hook) but left `HEAD` where it was to go, with no tracked changes, counts, with a
    note. A call that did not get there is put back (the second of two is undone by switching
    back); if the repo is then not as it was, the result is an error that says what git left.
    `upstream` names a new branch whose upstream (origin's branch of that name) is set last."""
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
    # Read again right before the first call: a person who moved HEAD or committed while the
    # checks ran keeps that, and the repo is left as it is.
    if _position(git) != (head, turn.symbolic):
        return turn.left("HEAD moved while sync was checking the repo; not moved (sync again)")
    # And the tracked files: one a person changed while the checks ran is theirs, not the
    # move's, and the repo is left as it is.
    if tracked_changes(git) != 0:
        return turn.left(
            "a tracked file was changed while sync was checking the repo; not moved (sync"
            " again once it is committed or put back)"
        )
    base = turn.record if turn.record is not None else turn.new_record(head)
    try:
        turn.put(RepoRecord(base.layer, base.version, base.commit, base.url, (head, target)))
    except (OSError, ManifestError) as exc:
        return Done(FAILED, f"its record cannot be written ({exc}); not updated", notes)
    before = Before.read(git, turn.git_dir)
    ran: List[str] = []  # what ran, in order, for a report of a move that did not finish
    for index, (step, end) in enumerate(steps):
        was = _position(git)
        status, printed, error = git.run(*step, change=True, shown=True)
        said_by_git = (printed + error).rstrip()
        ran.append(_what_ran(step, status, was, _position(git)))
        # Judged by the state the step leaves, whatever its exit status: a step that exited 0
        # but left tracked changes (a hook that edits files) stops the move here too.
        if _arrived(git, end, want):
            if status != 0:
                notes.append(f"moved, but `git {step[0]}` exited {status}:\n{said_by_git}")
            continue
        if index > 0 and tracked_changes(git) == 0:
            # Back where it was, from a clean tree only: a change git or a hook made is never
            # carried back onto the branch the repo was on.
            back = ["switch", "-q", "--no-overwrite-ignore", "--detach", before.head]
            if before.symbolic is not None:
                back = [
                    "switch",
                    "-q",
                    "--no-overwrite-ignore",
                    before.symbolic[len("refs/heads/") :],
                ]
            was = _position(git)
            back_status, back_out, back_err = git.run(*back, change=True, shown=True)
            ran.append(_what_ran(back, back_status, was, _position(git)))
            said_by_git = "\n".join(t for t in (said_by_git, (back_out + back_err).rstrip()) if t)
        after = Before.read(git, turn.git_dir)
        if after == before:
            # The record without the moving line; a repo that had none is recorded as one
            # on the version would be (only such a repo is fast-forwarded without a record).
            turn.put(turn.record if turn.record is not None else turn.new_record(head))
            return Done(
                LEFT,
                f"`git {step[0]}` exited {status}; left as it was{_git_said(said_by_git)}",
                notes,
            )
        # What git left is said as it is; the record loses its moving line, so the next sync
        # does not take this for a run that was stopped.
        turn.put(turn.record if turn.record is not None else turn.new_record(head))
        if upstream is not None and git.out(
            "rev-parse", "--verify", "-q", f"refs/heads/{upstream}"
        ):
            if not git.out("config", "--get", f"branch.{upstream}.merge"):
                notes.append(
                    _no_upstream(git, upstream, "the move did not finish, so it was not set")
                )
        return Done(FAILED, _half_changed(git, ran, after, said_by_git), notes)
    if upstream is not None:
        _set_upstream(git, upstream, notes)
    if (git.place / ".gitmodules").is_file():
        notes.append(f"submodules not updated: git -C {quoted(git.place)} submodule update")
    turn.put(turn.new_record(target))
    return Done(UPDATED, said, notes, commit=target)


def _position(git: Git) -> Tuple[str, Optional[str]]:
    return git.out("rev-parse", "HEAD") or "", git.out("symbolic-ref", "-q", "HEAD")


def _shown(position: Tuple[str, Optional[str]]) -> str:
    commit, symbolic = position
    if symbolic is not None and symbolic.startswith("refs/heads/"):
        return f"{symbolic[len('refs/heads/'):]} at {commit[:12]}"
    return f"detached at {commit[:12]}"


def _what_ran(
    step: Sequence[str], status: int, was: Tuple[str, Optional[str]], now: Tuple[str, Optional[str]]
) -> str:
    """One call of a move, as the report of a move that did not finish gives it."""
    if step[0] == "merge" and was[1] == now[1] and was[0] != now[0] and now[1] is not None:
        return (
            f"`git merge --ff-only` (exit {status}) fast-forwarded"
            f" {now[1][len('refs/heads/'):]} from {was[0][:12]} to {now[0][:12]}"
        )
    moved = f"from {_shown(was)} to {_shown(now)}" if was != now else f"stayed {_shown(now)}"
    return f"`git {step[0]}` (exit {status}): HEAD {moved}"


def _half_changed(git: Git, ran: Sequence[str], after: Before, said: str) -> str:
    """The error for a move that did not get where it was to go and did not leave the repo as
    it was: what ran, in order, where `HEAD` is, and the files that now differ from it, staged
    or not, made since the check just before the first step found none."""
    steps = "; ".join(f"{n}. {what}" for n, what in enumerate(ran, 1))
    staged = (git.out("diff", "--cached", "--name-status", "HEAD") or "").splitlines()
    changed = (git.out("diff", "--name-status") or "").splitlines()
    files = ""
    for label, lines in (("staged", staged), ("changed, not staged", changed)):
        if lines:
            shown = ", ".join(" ".join(line.split("\t", 1)) for line in lines[:SHOWN_PATHS])
            more = f" and {len(lines) - SHOWN_PATHS} more" if len(lines) > SHOWN_PATHS else ""
            files += f"; {label}: {shown}{more}"
    where = _shown((after.head, after.symbolic))
    if files:
        changes = (
            f"{files}. sync's last check, just before the move, found no tracked changes, so"
            " these were made since: by git, a hook it ran, or a person; sync does not put them"
            " back, as it runs no reset or forced"
            f" checkout: `git -C {quoted(git.place)} status` shows them"
        )
    else:
        changes = ", with no tracked changes; sync does not move it back"
    return (
        f"the move left the repo half-changed. What ran, in order: {steps}. HEAD is now"
        f" {where}{changes}, and nothing after the steps above was run here{_git_said(said)}"
    )


def _git_said(said: str) -> str:
    """What git printed, after a colon on lines of its own; or a full stop when it printed
    nothing, so a report never ends in an empty line."""
    return f":\n{said}" if said.strip() else "."


def _fetch_covers(git: Git, branch: str) -> bool:
    """Whether a `remote.origin.fetch` refspec of the clone maps origin's `branch`."""
    printed = git.out("config", "--get-all", "remote.origin.fetch") or ""
    ref = f"refs/heads/{branch}"
    for spec in printed.splitlines():
        source = spec.lstrip("+").split(":", 1)[0]
        if source == ref or (
            source.count("*") == 1
            and ref.startswith(source.split("*")[0])
            and ref.endswith(source.split("*")[1])
        ):
            return True
    return False


def _set_upstream(git: Git, branch: str, notes: List[str]) -> None:
    """Set the new branch's upstream to origin's branch; a failure is a note, since the move is
    done and nothing else depends on it."""
    status, printed, error = git.run(
        "branch", f"--set-upstream-to=refs/remotes/origin/{branch}", branch, change=True, shown=True
    )
    if status == 0:
        return
    why = (
        "the clone's fetch settings (remote.origin.fetch, as a --single-branch or --depth clone"
        f" has them) do not cover origin's {branch}"
        if not _fetch_covers(git, branch)
        else f"`git branch --set-upstream-to` exited {status}: {(printed + error).strip()}"
    )
    notes.append(_no_upstream(git, branch, why))


def _no_upstream(git: Git, branch: str, why: str) -> str:
    place = quoted(git.place)
    return (
        f"branch {branch} has no upstream configured: {why}; to set one by hand: git -C {place}"
        f" config {quoted(f'branch.{branch}.remote')} origin && git -C {place} config"
        f" {quoted(f'branch.{branch}.merge')} {quoted(f'refs/heads/{branch}')}"
    )


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
            f"remote.{PROBE}.url={url}",  # url-text: a git argument, not a message
            "fetch",
            "--no-tags",
            "--no-prune",
            "--no-recurse-submodules",
            "--refmap=",
            PROBE,
            f"+refs/heads/*:refs/remotes/{PROBE}/*",
            prompt=True,
            hold=True,
        )
        if status != 0:
            return Done(
                FAILED,
                f"the manifest's url changed to {mask_url(url)}, and fetching from it failed"
                f" (origin stays {mask_url(origin)}): `git fetch` exited {status}:"
                f"\n{(printed + error).rstrip()}",
                fetch=True,
            )
        trees = work_trees(git)
        if trees is None:
            return Done(
                LEFT,
                f"url changed to {mask_url(url)}; the work trees cannot be listed; origin stays"
                f" {mask_url(origin)}",
            )
        # The HEAD of every work tree, a detached one included, counts with the branches; a
        # work tree on a branch with no commit yet (`worktree add --orphan`) lists the null id
        # and has nothing to count.
        heads = [
            t.head
            for t in trees
            if t.head is not None and OBJECT_ID.fullmatch(t.head) and t.head.strip("0")
        ]
        local = count(git, "--branches", "HEAD", *heads, "--not", f"--remotes={PROBE}")
        if local is None:
            return Done(LEFT, f"url changed to {mask_url(url)}; its commits cannot be counted")
        if local:
            names = []
            refs = git.out("for-each-ref", "--format=%(refname:short)", "refs/heads/") or ""
            for name in refs.splitlines():
                if count(git, f"refs/heads/{name}", "--not", f"--remotes={PROBE}"):
                    names.append(f"branch {name}")
            for tree in trees:
                if tree.branch is None and tree.head is not None and tree.head in heads:
                    if count(git, tree.head, "--not", f"--remotes={PROBE}"):
                        names.append(f"the detached HEAD of {tree.path}")
            which = f" ({', '.join(names)})" if names else " (on HEAD)"
            return Done(
                LEFT,
                f"url changed to {mask_url(url)} but {counted(local, 'local commit')}{which}"
                f" {'is' if local == 1 else 'are'} not on it; origin stays {mask_url(origin)}",
            )
        status, _, error = git.run("remote", "set-url", "origin", url, change=True, shown=True)
        if status != 0:
            return Done(FAILED, f"`git remote set-url origin` exited {status}: {error.strip()}")
        return None
    finally:
        delete_probe_refs(git)


def _ref_conflicts(git: Git) -> List[Tuple[str, str]]:
    """Remote-tracking refs here, of branches origin no longer has, that stand in the way of a
    branch origin has now (`origin/release` and origin's `release/next`): (ref here, origin's
    branch). git names neither in its message."""
    theirs, _ = ask_origin(git, "refs/heads/*")
    if theirs is None:
        return []
    names = {ref[len("refs/heads/") :] for ref in theirs if ref.startswith("refs/heads/")}
    prefix = "refs/remotes/origin/"
    printed = git.out("for-each-ref", "--format=%(refname)", prefix) or ""
    here = [ref[len(prefix) :] for ref in printed.splitlines() if ref.startswith(prefix)]
    found = []
    for old in here:
        if old in names or old == "HEAD":
            continue
        for new in sorted(names):
            if new.startswith(old + "/") or old.startswith(new + "/"):
                found.append((prefix + old, new))
    return found


def _conflicts_note(git: Git, conflicts: Sequence[Tuple[str, str]]) -> str:
    place = quoted(git.place)
    parts = [
        f"{old} here, left from a branch origin no longer has, is in the way of origin's"
        f" branch {new}"
        for old, new in conflicts
    ]
    olds = sorted({o for o, _ in conflicts})
    commands = " && ".join(f"git -C {place} update-ref -d {quoted(old)}" for old in olds)
    keep = " && ".join(f"git -C {place} branch <a new name> {quoted(old)}" for old in olds)
    return (
        f"the fetch cannot write origin's branches: {'; '.join(parts)}. sync removes no"
        " remote-tracking ref of origin, and another sync will not change this. Removing it"
        " may remove the only ref here to commits origin has since deleted; to keep them, make"
        f" a local branch at it first ({keep}). To clear it: {commands}, then sync again"
    )
