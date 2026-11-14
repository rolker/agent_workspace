"""Resolve a manifest's `extends` chain into an ordered list, base first.

Local-path extends resolve relative to the declaring manifest's own directory. Git-backed
extends (`url` + `ref` + `path`) are cloned into a cache directory with `git clone --no-checkout
--branch <ref> --depth 1 -- <url>`, then checked out with `git reset --hard`, and re-used on a
cache hit (same url+ref). The clone is untrusted content, so: the transports git may use are
stated on the command line and in GIT_ALLOW_PROTOCOL; no hook, fsmonitor, submodule, filter
driver or text conversion of the user's configuration runs on it; git's repository-locating
environment variables are removed; git runs without a terminal, with GIT_TERMINAL_PROMPT=0, an
empty core.askPass, no GIT_ASKPASS or SSH_ASKPASS and SSH_ASKPASS_REQUIRE=never, so neither git
nor ssh can ask for a password or passphrase (a credential helper the user configured still
runs); each call that asks the remote is bounded by ROS_MANIFEST_GIT_TIMEOUT (seconds, default
60), after which git's process group is killed, as it is on an interrupt, or on a SIGTERM or
SIGHUP that was not ignored (which is then delivered again to the previous handler);
and the clone is made in a temporary sibling and renamed into the cache only when complete.
The url and ref have already passed the allow-lists in ``schema.py``. This module invokes `git
clone`, `git reset` and `git rev-parse` on the clone; tests point `url` at a local git
repository through a `file://` URL (a plain local path is not an accepted url).

Provenance labels: a manifest read from the local filesystem is labelled with its file path. A
manifest read from a git-backed `extends` clone is labelled `url#ref:path@<commit>` (the commit
the clone holds), never with the cache path: a cache directory may be temporary, and the label
ends up in every generated `.repos` header. The `:` after the ref cannot be part of a git ref,
so a ref holding `/` (`release/2`) still reads unambiguously. A local-path `extends` declared
inside such a clone stays inside it (the escape check below) and is labelled the same way with
its own path.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import signal
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple

from .schema import ExtendsRef, Manifest, load_manifest_file, ManifestError


# The transports a clone may use, stated here rather than left to git's defaults: the ones the
# URL allow-list in ``schema.py`` admits, and nothing else (no `ext::`, which runs a command).
_TRANSPORT_POLICY = (
    "-c",
    "protocol.allow=never",
    "-c",
    "protocol.https.allow=always",
    "-c",
    "protocol.ssh.allow=always",
    "-c",
    "protocol.file.allow=always",
)

# What a clone of an untrusted base never does with the user's configuration: run a hook (a
# global `core.hooksPath` included) or an fsmonitor command. The checkout happens after the
# clone, with every filter, text conversion, ident and encoding attribute switched off in
# `.git/info/attributes`, so no filter driver (git-lfs's would contact a host the base names)
# runs on the tree. No submodule is fetched.
_SAFETY = (
    "-c",
    "core.hooksPath=/dev/null",
    "-c",
    "core.fsmonitor=false",
    "-c",
    "submodule.recurse=false",
    "-c",
    "core.askPass=",
)
_NO_FILTERS = "* -filter -text -ident -working-tree-encoding\n"

# The time limit on each git call that asks a remote, in seconds: ROS_MANIFEST_GIT_TIMEOUT,
# default 60. When it runs out, git and everything it started are killed and the clone fails.
_TIMEOUT_VAR = "ROS_MANIFEST_GIT_TIMEOUT"
_TIMEOUT_DEFAULT = 60

# Names git reads to find a repository (`git rev-parse --local-env-vars`, git 2.53's list as a
# floor). Inherited from a hook they would send the clone into another repository, so they are
# removed from git's environment. GIT_CONFIG_PARAMETERS and GIT_CONFIG_COUNT carry the user's
# own configuration (credentials, url.*.insteadOf) and are kept; the options above are on the
# command line, which wins over them.
_LOCAL_ENV_FLOOR = (
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "GIT_CONFIG",
    "GIT_OBJECT_DIRECTORY",
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_IMPLICIT_WORK_TREE",
    "GIT_GRAFT_FILE",
    "GIT_INDEX_FILE",
    "GIT_NO_REPLACE_OBJECTS",
    "GIT_REPLACE_REF_BASE",
    "GIT_PREFIX",
    "GIT_SHALLOW_FILE",
    "GIT_COMMON_DIR",
)
_KEEP = {"GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT"}


def _git_env() -> dict:
    """The environment for git: the repository-locating names removed, no prompt (terminal,
    askpass), and the transports allowed by the environment too, which a user's own
    `protocol.<name>.allow=always` cannot widen."""
    env = {k: v for k, v in os.environ.items() if k not in _LOCAL_ENV_FLOOR}
    names = set()
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--local-env-vars"], capture_output=True, env=env
        ).stdout
        names = set(out.decode("ascii", errors="replace").split())
    except FileNotFoundError:
        pass
    for name in names - _KEEP:
        env.pop(name, None)
    for name in ("GIT_ASKPASS", "SSH_ASKPASS"):
        env.pop(name, None)
    env["SSH_ASKPASS_REQUIRE"] = "never"
    env["GIT_TERMINAL_PROMPT"] = "0"
    env["GIT_ALLOW_PROTOCOL"] = "https:ssh:file"
    return env


def _git_timeout() -> float:
    raw = os.environ.get(_TIMEOUT_VAR, "")
    if raw == "":
        return float(_TIMEOUT_DEFAULT)
    try:
        value = float(raw)
    except ValueError:
        value = -1.0
    if not value > 0:
        raise ManifestError(
            f"{_TIMEOUT_VAR}='{raw}' is not a number of seconds above 0; unset it for the"
            f" default, {_TIMEOUT_DEFAULT}"
        )
    return value


class _GitTimeout(Exception):
    pass


class _Signalled(BaseException):
    """A SIGTERM or SIGHUP that arrived while git ran (git's group is then killed)."""

    def __init__(self, signum: int) -> None:
        super().__init__(signum)
        self.signum = signum


def _run_git(args: List[str], timeout: Optional[float] = None) -> Tuple[int, bytes]:
    """Run git with `args` in its own session (no controlling terminal, so ssh cannot ask on
    one), stdin closed, stdout captured as bytes, stderr discarded. With `timeout`, git and
    everything still in its process group are killed when it runs out (_GitTimeout); an
    interrupt kills them too, and so does a SIGTERM or a SIGHUP that was not ignored when this
    call began (_Signalled; an ignored one stays ignored). SIGTERM and SIGHUP are caught only
    while git runs, in the main thread; the previous handlers are then put back, with the two
    signals blocked until they are."""
    pending: List[int] = []
    armed = False

    def on_signal(signum, _frame):
        # Until `proc` is set, git's group cannot be killed: the signal waits until it is.
        if armed:
            raise _Signalled(signum)
        pending.append(signum)

    previous = {}
    for sig in (getattr(signal, "SIGTERM", None), getattr(signal, "SIGHUP", None)):
        if sig is None or signal.getsignal(sig) in (signal.SIG_IGN, None):
            continue  # ignored (as under nohup), or a handler Python cannot put back
        try:
            previous[sig] = signal.signal(sig, on_signal)
        except ValueError:  # not the main thread: signals cannot be caught here
            pass
    saved_mask = None

    def block():
        # The cleanup (killing git's group, putting the handlers back) runs with the caught
        # signals blocked, so no handler interrupts it; one that arrives meanwhile is delivered
        # to the previous handler when the mask is put back, last. Only after Popen returned:
        # a child inherits the mask.
        nonlocal saved_mask
        if saved_mask is None and previous and hasattr(signal, "pthread_sigmask"):
            saved_mask = signal.pthread_sigmask(signal.SIG_BLOCK, set(previous))

    proc = None
    try:
        try:
            proc = subprocess.Popen(
                ["git", *args],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                env=_git_env(),
                start_new_session=True,
            )
        except FileNotFoundError:
            pass
        finally:
            armed = True
            if pending:
                raise _Signalled(pending.pop(0))
        if proc is None:
            raise ManifestError(_NO_GIT)
        out, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        block()
        armed = False
        _kill_group(proc)
        raise _GitTimeout() from None
    except BaseException:
        block()
        armed = False
        if proc is not None:
            _kill_group(proc)
        raise
    finally:
        block()
        armed = False
        for sig, handler in previous.items():
            signal.signal(sig, handler)
        if saved_mask is not None:
            signal.pthread_sigmask(signal.SIG_SETMASK, saved_mask)
    return proc.returncode, out


def _kill_group(proc: subprocess.Popen) -> None:
    try:
        if hasattr(os, "killpg"):
            os.killpg(proc.pid, signal.SIGKILL)
        else:  # pragma: no cover - not POSIX
            proc.kill()
    except ProcessLookupError:
        pass
    # git itself is dead now; a program that left its group may still hold the pipe, so the
    # wait for the pipe is short, and only git's exit is waited for.
    try:
        proc.communicate(timeout=2)
    except subprocess.TimeoutExpired:
        proc.wait()


def _cache_key(url: str, ref: str) -> str:
    digest = hashlib.sha256(f"{url}@{ref}".encode()).hexdigest()[:16]
    return digest


def _reject_option_like(value: str, field_name: str) -> None:
    if value.startswith("-"):
        raise ManifestError(
            f"extends {field_name} starts with '-', so git could read it as a command-line"
            " option; it is refused"
        )


_NO_GIT = "git is not installed or not on PATH; it is needed to clone an extends base"

# git's output is captured as bytes and never printed: its stderr quotes the url and the
# remote's own file names, and need not be UTF-8. A failure is reported with git's exit status.


def _clone_or_reuse(url: str, ref: str, cache_dir: Path, source: str = "a manifest") -> Path:
    _reject_option_like(url, "url")
    _reject_option_like(ref, "ref")
    # These two are not the manifest's fault, so they do not name it.
    try:
        cache_dir.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        raise ManifestError(
            f"the extends cache directory {cache_dir} (--cache-dir) cannot be created"
            f" ({exc.strerror or 'an OS error'})"
        ) from None
    dest = cache_dir / _cache_key(url, ref)
    # Only a finished clone is ever at `dest`: it is made in a temporary sibling and renamed
    # there, so a failed, timed-out or interrupted clone leaves no entry a later run trusts.
    if dest.is_dir():
        return dest
    timeout = _git_timeout()
    tmp = Path(tempfile.mkdtemp(prefix=f".{dest.name}.partial-", dir=cache_dir))
    try:
        _clone_into(url, ref, tmp / "clone", timeout, source)
        try:
            os.rename(tmp / "clone", dest)
        except OSError:
            if not dest.is_dir():  # not another run's finished clone
                raise
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return dest


def _clone_into(url: str, ref: str, dest: Path, timeout: float, source: str) -> None:
    """Clone `ref` of `url` one commit deep into `dest`, with no hook and no filter: the clone
    checks nothing out, and the checkout comes after the attributes that switch filters off."""
    clone = [
        *_TRANSPORT_POLICY,
        *_SAFETY,
        "clone",
        "--quiet",
        "--no-checkout",
        "--template=",
        "--no-recurse-submodules",
        "--branch",
        ref,
        "--depth",
        "1",
        "--",
        url,
        str(dest),
    ]
    _git_step(clone, timeout, source, "clone")
    info = dest / ".git" / "info"
    info.mkdir(parents=True, exist_ok=True)
    (info / "attributes").write_text(_NO_FILTERS)
    _git_step(
        [*_SAFETY, "-C", str(dest), "reset", "--quiet", "--hard"], timeout, source, "check out"
    )


def _git_step(args: List[str], timeout: float, source: str, what: str) -> None:
    try:
        code, _ = _run_git(args, timeout)
    except _GitTimeout:
        raise ManifestError(
            f"{source}: could not {what} its extends base within {timeout:g} s (the limit;"
            f" {_TIMEOUT_VAR} raises it); nothing is kept in the cache"
        ) from None
    if code != 0:
        raise ManifestError(
            f"{source}: failed to {what} its extends base (git exited with status {code})"
        )


def _head_commit(clone_dir: Path, source: str) -> str:
    # A cache hit skips the clone, so this may be git's first run (_run_git says so).
    code, out = _run_git([*_SAFETY, "-C", str(clone_dir), "rev-parse", "HEAD"])
    if code != 0:
        raise ManifestError(
            f"{source}: cannot read the commit of its extends base (clone: {clone_dir}; git"
            f" exited with status {code})"
        )
    return out.decode("ascii", errors="replace").strip()


@dataclass(frozen=True)
class _GitOrigin:
    """Where a manifest read from an `extends` clone came from."""

    url: str
    ref: str
    commit: str
    clone_dir: Path

    def label(self, path: Path) -> str:
        rel = path.relative_to(self.clone_dir).as_posix()
        return f"{self.url}#{self.ref}:{rel}@{self.commit}"


def _resolve_one(
    ext: ExtendsRef,
    declaring_dir: Path,
    declaring_origin: Optional[_GitOrigin],
    cache_dir: Path,
    source: str,
) -> Tuple[Path, Optional[_GitOrigin]]:
    """Return the base manifest's path and its git origin (None for the local filesystem).
    `source` is the declaring manifest's label: a message names it, not the base's url or ref."""
    if ext.url is None:
        base = declaring_dir.resolve()
        candidate = (base / ext.path).resolve()
        if not candidate.is_relative_to(base):
            raise ManifestError(
                f"extends path '{ext.path}' escapes its declaring directory {base}: {candidate}"
            )
        if not candidate.is_file():
            raise ManifestError(f"extends path not found: {candidate}")
        # Inside a clone, the escape check keeps it in the same clone: same origin.
        return candidate, declaring_origin
    clone_dir = _clone_or_reuse(ext.url, ext.ref, cache_dir, source).resolve()
    candidate = (clone_dir / ext.path).resolve()
    if not candidate.is_relative_to(clone_dir):
        raise ManifestError(
            f"extends path '{ext.path}' escapes its clone directory {clone_dir}: {candidate}"
        )
    if not candidate.is_file():
        raise ManifestError(
            f"{source}: extends path '{ext.path}' not found in its base (clone: {clone_dir})"
        )
    origin = _GitOrigin(
        url=ext.url,
        ref=ext.ref,
        commit=_head_commit(clone_dir, source),
        clone_dir=clone_dir,
    )
    return candidate, origin


def _os_reason(exc: Exception) -> str:
    """Why a path could not be followed, without the path: an OSError's own text quotes it, and
    past the leaf that path comes from a manifest's `extends`."""
    if isinstance(exc, OSError) and exc.strerror:
        return exc.strerror
    if isinstance(exc, RuntimeError):  # `Path.resolve()` before Python 3.13: a symlink loop
        return "a symlink loop"
    return "an OS error"


def resolve_chain(manifest_path: Path, cache_dir: Optional[Path] = None) -> List[Manifest]:
    """Return the extends chain for `manifest_path`, ordered base-first, leaf last. A path that
    cannot be followed (a name too long, a symlink loop, no permission) is a ManifestError, not
    a traceback."""
    try:
        manifest_path = Path(manifest_path).resolve()
    except (OSError, RuntimeError) as exc:
        raise ManifestError(f"{manifest_path}: cannot be followed ({_os_reason(exc)})") from None
    if cache_dir is None:
        cache_dir = Path.cwd() / ".ros-manifest-cache"
    cache_dir = Path(cache_dir)

    chain: List[Manifest] = []
    seen: set = set()
    current_path = manifest_path
    current_origin: Optional[_GitOrigin] = None  # the leaf is a local file
    while True:
        key = str(current_path)
        if key in seen:
            raise ManifestError(f"extends cycle detected: {' -> '.join(list(seen) + [key])}")
        seen.add(key)
        label = current_origin.label(current_path) if current_origin else None
        manifest = load_manifest_file(current_path, source=label)
        chain.append(manifest)
        if manifest.extends is None:
            break
        try:
            current_path, current_origin = _resolve_one(
                manifest.extends, current_path.parent, current_origin, cache_dir, manifest.source
            )
        except _Signalled as sig:
            # git's group is killed, the partial clone removed and the previous handler back:
            # the signal is delivered again, to end the process or to run the caller's handler
            # (which runs before raise_signal returns, and whose exception propagates).
            signal.raise_signal(sig.signum)
            raise ManifestError(
                f"{manifest.source}: git was stopped by {signal.Signals(sig.signum).name} while"
                " fetching its extends base; nothing is kept in the cache"
            ) from None
        except (OSError, RuntimeError) as exc:
            raise ManifestError(
                f"{manifest.source}: its extends cannot be followed ({_os_reason(exc)})"
            ) from None

    chain.reverse()  # base first
    return chain
