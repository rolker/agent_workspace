"""Reading the text of a manifest from a git repo (``docs/design.md``, "Where the manifest comes
from").

The repo is cloned bare and shallow, at the branch or tag asked for, into a temporary directory
of its own (`tempfile.mkdtemp`, named `repos-manifest-...`, in the system's temporary
directory, never in a system directory), and the file is taken out of it with `git ls-tree`
and `git cat-file blob`. A bare clone has no work tree: nothing is checked out, so no hook,
filter or smudge runs. The temporary directory is removed when the read ends, however it ends
(a stop signal included); only a SIGKILL of the tool can leave it behind. Nothing is kept
between runs: every read is fresh.

git is run as it is set up on the machine, in the environment `gitenv.require_git` gives:
whatever lets a person clone the repo by hand lets the tool read the manifest (ssh keys, an
ssh agent, `~/.ssh/config`, a credential helper), but for one case below. Only the url's own
transport is allowed (`GIT_ALLOW_PROTOCOL`), so a redirect cannot take an https read to plain
http or anywhere else. git checks that after it applies a url rewrite from the person's
configuration (`url.<base>.insteadOf`), so a rewrite to another transport, such as https to
ssh for a forge, is refused; the message then says to give the url the rewrite leads to, which
`git ls-remote --get-url <url>` prints, as the manifest's url.

With a terminal, git runs in the tool's process group and may ask for a password or a
passphrase, with no time limit; it is ended by its pid on a stop signal. With none, as in CI,
git runs in a session of its own with `GIT_TERMINAL_PROMPT=0`, so it cannot ask and fails at
once, and the read has `TIME_LIMIT` seconds as a whole; then, or on a stop signal, git's whole
process group is ended (git and the helpers it started, such as ssh or git-remote-https).

A file larger than `SIZE_LIMIT` is refused before it is read.
"""

from __future__ import annotations

import os
import re
import shlex
import shutil
import signal
import subprocess
import tempfile
import time
from typing import List, Optional, Tuple

from .gitenv import Env, require_git
from .location import GitLocation
from .manifest import decode_text, version_ref
from .masking import mask_url, mask_urls
from .yamlload import ManifestError, has_unsafe_char

# The read of one manifest from a git repo, with no terminal: seconds for the whole read.
TIME_LIMIT = 60
# The largest manifest read from a git repo, in bytes (1 MiB).
SIZE_LIMIT = 1024 * 1024

# The modes `git ls-tree` gives a file it can read, and what the others are.
_FILE_MODES = ("100644", "100755")
_OTHER_MODES = {"120000": "a link", "160000": "a submodule", "040000": "a directory"}

# What git (in the C locale) prints when the branch or tag asked for is not in the repo.
_NOT_FOUND = re.compile(r"Remote branch .* not found in upstream")
# What git prints when the transport it would use is not in `GIT_ALLOW_PROTOCOL`: since the url
# given always has its own allowed, a rewrite in git's configuration led it to another. (A
# redirect to another transport is refused by curl in other words.)
_NOT_ALLOWED = re.compile(r"transport '[^']*' not allowed")


class _TimedOut(Exception):
    """git did not end before the read's deadline."""


def has_terminal() -> bool:
    """Whether a person can be asked: `/dev/tty` opens."""
    try:
        fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
    except OSError:
        return False
    os.close(fd)
    return True


def allowed_protocols(url: str) -> str:
    """`GIT_ALLOW_PROTOCOL` for a url that passed the url rules: its own transport only, and
    https besides for an http url (a redirect from http to https is safe; the other way is
    not). The `[user@]host:path` form is ssh; an absolute path is git's file transport."""
    for scheme, allowed in (
        ("https://", "https"),
        ("http://", "http:https"),
        ("ssh://", "ssh"),
        ("file://", "file"),
    ):
        if url.startswith(scheme):
            return allowed
    return "file" if url.startswith("/") else "ssh"


def read_git_file(location: GitLocation, env: Optional[Env] = None) -> str:
    """The text of the file `location` names. `env` is the run's git environment; without one
    it is `require_git`'s. A failure is a `ManifestError` that names the location (its url
    masked) and says why, with git's own words, masked, when git failed."""
    if env is None:
        env = require_git()
    terminal = has_terminal()
    env = {**env, "LC_ALL": "C", "GIT_ALLOW_PROTOCOL": allowed_protocols(location.url)}
    if not terminal:
        env["GIT_TERMINAL_PROMPT"] = "0"
    deadline = None if terminal else time.monotonic() + TIME_LIMIT
    label = location.label()
    directory = tempfile.mkdtemp(prefix="repos-manifest-")
    try:
        clone = os.path.join(directory, "manifest.git")
        kind, name = version_ref(location.version) if location.version else (None, None)
        args = ["clone", "--bare", "--depth", "1", "--no-tags", "--quiet"]
        if name is not None:
            args += ["--branch", name]
        args += ["--", location.url, clone]
        code, _, err = _git(args, env, directory, deadline, terminal, label)
        if code != 0:
            raise ManifestError(_clone_failed(label, location, code, err))
        at = ["--git-dir", clone]
        if kind is not None:
            _check_kind(at, env, directory, deadline, terminal, location, kind, name)
        oid = _find_file(at, env, directory, deadline, terminal, location)
        code, data, err = _git(
            [*at, "cat-file", "blob", oid], env, directory, deadline, terminal, label
        )
        if code != 0:
            raise ManifestError(f"{label}: git cannot read the file: {_git_words(err)}")
        return decode_text(data, label)
    finally:
        shutil.rmtree(directory, ignore_errors=True)


def _clone_failed(label: str, location: GitLocation, code: int, err: str) -> str:
    said = f"{label}: git could not fetch the repo (exit status {code}): {_git_words(err)}"
    version = location.version
    if version is not None and _NOT_FOUND.search(err):
        said += (
            f"; the repo has no branch or tag {version}: a branch or tag is meant (a manifest"
            " is not read at a commit in this version)"
        )
    elif _NOT_ALLOWED.search(err):
        shown = mask_url(location.url)
        command = f"git ls-remote --get-url {shlex.quote(shown)}"
        said += (
            "; the read allows only the transport the url names, and a url rewrite in git's"
            " configuration (url.<base>.insteadOf) can lead git to another; give as the"
            f" manifest's url the url the rewrite leads to, which `{command}` prints"
        )
    return said


def _check_kind(at, env, cwd, deadline, terminal, location: GitLocation, kind, name) -> None:
    """A version `heads/x` names a branch and `tags/x` a tag; git's `--branch x` takes either,
    a branch first. The refs the clone got say which it took."""
    code, out, err = _git(
        [*at, "for-each-ref", "--format=%(refname)", f"refs/heads/{name}", f"refs/tags/{name}"],
        env,
        cwd,
        deadline,
        terminal,
        location.label(),
    )
    if code != 0:
        raise ManifestError(f"{location.label()}: git cannot read the clone: {_git_words(err)}")
    refs = out.decode("utf-8", "replace").split()
    branch = f"refs/heads/{name}" in refs
    if kind == "branch" and not branch:
        raise ManifestError(
            f"{location.label()}: {location.version} names a branch, and {name} in the repo is"
            " a tag"
        )
    if kind == "tag" and branch:
        raise ManifestError(
            f"{location.label()}: {location.version} names a tag, and {name} in the repo is a"
            " branch, which git takes before a tag of the same name"
        )


def _find_file(at, env, cwd, deadline, terminal, location: GitLocation) -> str:
    """The object of the file at `location.path`: the one entry `git ls-tree` gives whose name
    is exactly the path, a regular file no larger than `SIZE_LIMIT`. `--literal-pathspecs`, so
    no character of the path is a pattern."""
    label = location.label()
    code, out, err = _git(
        ["--literal-pathspecs", *at, "ls-tree", "-z", "-l", "HEAD", "--", location.path],
        env,
        cwd,
        deadline,
        terminal,
        label,
    )
    if code != 0:
        raise ManifestError(f"{label}: git cannot list the repo: {_git_words(err)}")
    entries: List[Tuple[str, str, str, str]] = []
    for record in out.split(b"\0"):
        if not record:
            continue
        head, _, name = record.partition(b"\t")
        mode, _, rest = head.decode("ascii", "replace").partition(" ")
        _, _, rest = rest.partition(" ")
        oid, _, size = rest.strip().partition(" ")
        entries.append((mode, oid, size.strip(), name.decode("utf-8", "surrogateescape")))
    found = [entry for entry in entries if entry[3] == location.path]
    if len(entries) != 1 or not found:
        raise ManifestError(
            f"{label}: there is no file {location.path} in the repo at that version (a path is"
            " written from the top of the repo as git names it: no './', no '/' at the end,"
            " and not through a link)"
        )
    mode, oid, size, _ = found[0]
    if mode in _OTHER_MODES:
        raise ManifestError(
            f"{label}: {location.path} is {_OTHER_MODES[mode]} in the repo, not a file"
        )
    if mode not in _FILE_MODES:
        raise ManifestError(f"{label}: {location.path} is not a file in the repo (mode {mode})")
    if not size.isdigit() or int(size) > SIZE_LIMIT:
        raise ManifestError(
            f"{label}: {location.path} is {size} bytes; a manifest is read up to {SIZE_LIMIT}"
            " bytes (1 MiB)"
        )
    return oid


def _git_words(err: str) -> str:
    """What git printed on stderr, for a message: its lines joined, each url's user name and
    password masked, and a control or invisible character written as an escape."""
    lines = [line.strip() for line in err.splitlines() if line.strip()]
    text = " / ".join(lines) if lines else "it printed nothing"
    return "".join(_shown(ch) for ch in mask_urls(text))


def _shown(ch: str) -> str:
    if not has_unsafe_char(ch):
        return ch
    code = ord(ch)
    if code < 0x100:
        return f"\\x{code:02x}"
    return f"\\u{code:04x}" if code <= 0xFFFF else f"\\U{code:08x}"


def _git(
    args: List[str],
    env: Env,
    cwd: str,
    deadline: Optional[float],
    terminal: bool,
    label: str,
) -> Tuple[int, bytes, str]:
    """Run `git <args>`: (exit status, stdout, stderr as text). The one function that runs git
    to read a manifest. With no terminal, git starts a session of its own and the whole
    process group is ended when `deadline` passes or the run is stopped; with one, git stays
    in the tool's group, has no deadline, and is ended by its pid when the run is stopped."""
    try:
        proc = subprocess.Popen(
            ["git", *args],
            cwd=cwd,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=not terminal,
        )
    except OSError as exc:
        raise ManifestError(f"{label}: git cannot be run ({exc.strerror})") from None
    try:
        timeout = None if deadline is None else max(deadline - time.monotonic(), 0)
        try:
            out, err = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            raise _TimedOut() from None
    except _TimedOut:
        _end(proc, terminal)
        raise ManifestError(
            f"{label}: git did not finish within {TIME_LIMIT} seconds and was stopped; with no"
            " terminal, nothing can ask for a password, so a read that waits is ended"
        ) from None
    except BaseException:
        _end(proc, terminal)
        raise
    return proc.returncode, out, err.decode("utf-8", "replace")


def _end(proc: subprocess.Popen, terminal: bool) -> None:
    """End git: its whole process group when it has one of its own (no terminal), else its pid
    alone, since it shares the tool's group. Then wait for it, so nothing is left running. Its
    pipes are closed, not read: a helper of git's left in the tool's group may hold them."""
    try:
        if terminal:
            proc.kill()
        else:
            os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    proc.wait()
    for stream in (proc.stdout, proc.stderr):
        if stream is not None:
            stream.close()
