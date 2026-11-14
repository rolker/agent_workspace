"""An `extends` base is untrusted content: its clone must not run the user's hooks or filter
drivers, follow an inherited GIT_DIR, reach a transport other than https, ssh or file, or wait on
a stalled remote past the time limit; a failed clone leaves nothing in the cache."""

import hashlib
import os
import signal
import stat
import subprocess
import sys
import time
from pathlib import Path

import pytest

from ros_manifest import extends
from ros_manifest.extends import resolve_chain
from ros_manifest.schema import ManifestError


def _git(cwd: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


def _script(path: Path, body: str) -> Path:
    path.write_text("#!/bin/sh\n" + body)
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return path


def _base_repo(tmp_path: Path, attributes: str = "") -> Path:
    """A local repository holding manifest.yaml (and .gitattributes when given), branch main."""
    remote = tmp_path / "base_repo"
    remote.mkdir()
    _git(remote, "init", "-q", "-b", "main")
    (remote / "manifest.yaml").write_text(
        "layers: [underlay]\nrepos:\n  underlay:\n    a:\n"
        "      url: https://example.com/a.git\n      ref: main\n"
    )
    if attributes:
        (remote / ".gitattributes").write_text(attributes)
    _git(remote, "add", "-A")
    _git(remote, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "init")
    return remote


def _leaf(tmp_path: Path, url: str) -> Path:
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text(
        f"extends:\n  path: manifest.yaml\n  url: {url}\n  ref: main\n"
        "layers: [core]\nrepos:\n  core:\n    b:\n      url: https://example.com/b.git\n"
        "      ref: main\n"
    )
    return leaf


def _user_config(monkeypatch, pairs) -> None:
    """Set git configuration the way a user's global file would apply it, for this process."""
    monkeypatch.setenv("GIT_CONFIG_COUNT", str(len(pairs)))
    for i, (key, value) in enumerate(pairs):
        monkeypatch.setenv(f"GIT_CONFIG_KEY_{i}", key)
        monkeypatch.setenv(f"GIT_CONFIG_VALUE_{i}", value)


def _tree_hash(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        st = path.lstat()
        digest.update(f"{path.relative_to(root)} {st.st_mode} {st.st_mtime_ns}\n".encode())
        if path.is_file() and not path.is_symlink():
            digest.update(path.read_bytes())
    return digest.hexdigest()


def test_user_hooks_and_filter_drivers_do_not_run_on_a_base(tmp_path, monkeypatch):
    remote = _base_repo(tmp_path, attributes="* filter=spy\n")
    spy_log = tmp_path / "spy.log"
    hooks = tmp_path / "userhooks"
    hooks.mkdir()
    for hook in ("post-checkout", "reference-transaction"):
        _script(hooks / hook, f'echo {hook} >> "{spy_log}"\n')
    spy = _script(tmp_path / "spyfilter", f'echo filter >> "{spy_log}"\ncat\n')
    _user_config(
        monkeypatch,
        [
            ("core.hooksPath", str(hooks)),
            ("filter.spy.smudge", str(spy)),
            ("filter.spy.required", "true"),
        ],
    )
    chain = resolve_chain(_leaf(tmp_path, remote.as_uri()), cache_dir=tmp_path / "cache")
    assert len(chain) == 2
    assert not spy_log.exists(), spy_log.read_text()
    # Control: the same configuration does run both for a plain clone.
    subprocess.run(
        ["git", "clone", "-q", remote.as_uri(), str(tmp_path / "plain")],
        check=True,
        capture_output=True,
    )
    ran = spy_log.read_text()
    assert "filter" in ran and "post-checkout" in ran


def test_an_inherited_git_dir_does_not_redirect_the_clone(tmp_path, monkeypatch):
    remote = _base_repo(tmp_path)
    victim = tmp_path / "victim"
    victim.mkdir()
    _git(victim, "init", "-q", "-b", "main")
    (victim / "notes.txt").write_text("mine\n")
    _git(victim, "add", "notes.txt")
    _git(victim, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "mine")
    before = _tree_hash(victim)
    monkeypatch.setenv("GIT_DIR", str(victim / ".git"))
    monkeypatch.setenv("GIT_WORK_TREE", str(victim))
    monkeypatch.setenv("GIT_INDEX_FILE", str(victim / ".git" / "index"))
    chain = resolve_chain(_leaf(tmp_path, remote.as_uri()), cache_dir=tmp_path / "cache")
    assert len(chain) == 2
    assert chain[0].source.startswith(remote.as_uri() + "#main:manifest.yaml@")
    assert _tree_hash(victim) == before


def test_a_stalled_remote_fails_within_the_limit_and_leaves_no_cache_entry(tmp_path, monkeypatch):
    # An ssh remote whose "ssh" never answers, as a stalled host or a prompt would.
    hang = _script(tmp_path / "hang-ssh", "exec sleep 30\n")
    monkeypatch.setenv("GIT_SSH_COMMAND", str(hang))
    monkeypatch.setenv("ROS_MANIFEST_GIT_TIMEOUT", "1")
    cache = tmp_path / "cache"
    started = time.monotonic()
    with pytest.raises(ManifestError, match=r"within 1 s \(the limit; ROS_MANIFEST_GIT_TIMEOUT"):
        resolve_chain(_leaf(tmp_path, "ssh://git@example.invalid/base.git"), cache_dir=cache)
    assert time.monotonic() - started < 15
    assert list(cache.iterdir()) == []


def test_a_bad_time_limit_is_named(tmp_path, monkeypatch):
    monkeypatch.setenv("ROS_MANIFEST_GIT_TIMEOUT", "soon")
    remote = _base_repo(tmp_path)
    with pytest.raises(ManifestError, match="ROS_MANIFEST_GIT_TIMEOUT='soon' is not a number"):
        resolve_chain(_leaf(tmp_path, remote.as_uri()), cache_dir=tmp_path / "cache")


def test_a_failed_clone_leaves_no_cache_entry(tmp_path):
    cache = tmp_path / "cache"
    with pytest.raises(ManifestError, match="failed to clone its extends base"):
        resolve_chain(_leaf(tmp_path, (tmp_path / "missing").as_uri()), cache_dir=cache)
    assert list(cache.iterdir()) == []


def test_a_user_rule_cannot_reach_another_transport(tmp_path, monkeypatch):
    # The user allowed ext:: and sends this url to it; the clone still refuses it.
    marker = tmp_path / "ext-ran"
    spy = _script(tmp_path / "ext-spy", f'touch "{marker}"\nexit 1\n')
    _user_config(
        monkeypatch,
        [
            ("protocol.ext.allow", "always"),
            (f"url.ext::{spy} .insteadOf", "file:///alias/"),
        ],
    )
    with pytest.raises(ManifestError, match="failed to clone its extends base"):
        resolve_chain(_leaf(tmp_path, "file:///alias/base.git"), cache_dir=tmp_path / "cache")
    assert not marker.exists()
    # Control: with that configuration plain git does run it.
    subprocess.run(
        ["git", "ls-remote", "file:///alias/base.git"], capture_output=True, env=dict(os.environ)
    )
    assert marker.exists()


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def _gone_within(pid: int, seconds: float) -> bool:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if not _alive(pid):
            return True
        time.sleep(0.1)
    return False


def _group_gone_within(pgid: int, seconds: float) -> bool:
    # A killed member of git's group stays a zombie until its new parent reaps it, so the
    # group may still answer for a moment after the kill.
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            os.killpg(pgid, 0)
        except ProcessLookupError:
            return True
        time.sleep(0.1)
    return False


def _resolver_with_stalled_clone(tmp_path, prelude="", limit="60"):
    """Start the resolver in a process of its own, cloning from an ssh remote whose "ssh"
    records its pid and then never answers; `prelude` runs first in that process. Returns the
    process, the ssh's pid once it is running, and the cache directory. Its stdout is the
    message of a ManifestError, printed."""
    pidfile = tmp_path / "ssh.pid"
    hang = _script(tmp_path / "hang-ssh", f'echo $$ > "{pidfile}"\nexec sleep 30\n')
    cache = tmp_path / "cache"
    leaf = _leaf(tmp_path, "ssh://git@example.invalid/base.git")
    src = str(Path(extends.__file__).resolve().parents[1])
    code = (
        "import sys, signal; from pathlib import Path\n"
        "from ros_manifest.extends import resolve_chain\n"
        "from ros_manifest.schema import ManifestError\n"
        f"{prelude}\n"
        "try:\n"
        "    resolve_chain(Path(sys.argv[1]), cache_dir=Path(sys.argv[2]))\n"
        "except ManifestError as exc:\n"
        "    print(exc, flush=True)\n"
    )
    env = dict(os.environ, GIT_SSH_COMMAND=str(hang), ROS_MANIFEST_GIT_TIMEOUT=limit)
    env["PYTHONPATH"] = src + os.pathsep + env.get("PYTHONPATH", "")
    proc = subprocess.Popen(
        [sys.executable, "-c", code, str(leaf), str(cache)],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    deadline = time.monotonic() + 20
    while not (pidfile.exists() and pidfile.read_text().strip()):
        if time.monotonic() >= deadline:
            proc.kill()
            proc.wait()
            pytest.fail("the stalled ssh was never reached")
        time.sleep(0.1)
    return proc, int(pidfile.read_text().strip()), cache


def _stop(proc) -> None:
    if proc.poll() is None:
        proc.kill()
    proc.communicate()


@pytest.mark.parametrize("signum", [signal.SIGTERM, signal.SIGHUP])
def test_a_signal_while_git_runs_kills_git_and_leaves_no_partial_clone(tmp_path, signum):
    # The default disposition: the signal goes to the resolver alone, not to git's session,
    # and the resolver ends by it once git's group is killed and the partial clone removed.
    proc, ssh_pid, cache = _resolver_with_stalled_clone(tmp_path)
    try:
        proc.send_signal(signum)
        assert proc.wait(timeout=10) == -signum
        assert _gone_within(ssh_pid, 5), "git's ssh outlived the resolver"
        assert list(cache.iterdir()) == []
    finally:
        _stop(proc)


def test_an_ignored_hangup_does_not_end_the_clone(tmp_path):
    # Under nohup SIGHUP is ignored; a hangup must leave the resolver and its clone running,
    # here until the clone's own end, the time limit.
    proc, ssh_pid, cache = _resolver_with_stalled_clone(
        tmp_path, prelude="signal.signal(signal.SIGHUP, signal.SIG_IGN)", limit="3"
    )
    try:
        proc.send_signal(signal.SIGHUP)
        time.sleep(0.5)
        assert proc.poll() is None, "the resolver ended on an ignored hangup"
        assert _alive(ssh_pid), "git's ssh was killed on an ignored hangup"
        out, _ = proc.communicate(timeout=15)
        assert proc.returncode == 0
        assert b"within 3 s (the limit" in out
        assert list(cache.iterdir()) == []
    finally:
        _stop(proc)


def test_a_callers_own_sigterm_handler_runs_after_git_is_killed(tmp_path):
    marker = tmp_path / "handler-ran"
    proc, ssh_pid, cache = _resolver_with_stalled_clone(
        tmp_path,
        prelude=(
            "def mine(signum, frame):\n"
            f"    open({str(marker)!r}, 'w').write('ran')\n"
            "signal.signal(signal.SIGTERM, mine)"
        ),
    )
    try:
        proc.send_signal(signal.SIGTERM)
        out, _ = proc.communicate(timeout=10)
        assert proc.returncode == 0
        assert marker.read_text() == "ran"
        assert b"git was stopped by SIGTERM" in out
        assert _gone_within(ssh_pid, 5), "git's ssh outlived the clone"
        assert list(cache.iterdir()) == []
    finally:
        _stop(proc)


def _record_git(monkeypatch, then=None):
    """Patch Popen to record git's own process (not the `git rev-parse --local-env-vars` that
    _git_env runs first) and to call `then()` right after git is forked."""
    started = []
    real_popen = subprocess.Popen

    def popen(*args, **kwargs):
        child = real_popen(*args, **kwargs)
        if "--local-env-vars" not in args[0]:
            started.append(child)
            if then is not None:
                then()
        return child

    monkeypatch.setattr(extends.subprocess, "Popen", popen)
    return started


def test_a_signal_while_git_is_being_started_still_kills_git(monkeypatch):
    # A SIGTERM after git is forked but before `_run_git` holds it: git must still be killed.
    started = _record_git(monkeypatch, then=lambda: os.kill(os.getpid(), signal.SIGTERM))
    before = signal.getsignal(signal.SIGTERM)
    with pytest.raises(extends._Signalled):
        extends._run_git(["-c", "alias.hang=!sleep 30", "hang"], timeout=60)
    assert signal.getsignal(signal.SIGTERM) is before
    assert len(started) == 1
    assert _group_gone_within(started[0].pid, 5), "git's group was left running"
    started[0].communicate()


@pytest.fixture
def callers_handlers():
    """A caller's own SIGTERM and SIGHUP handlers (recording what they get) and a signal mask
    of its own (SIGUSR1 blocked), all put back after the test."""
    got = []

    def term(signum, _frame):
        got.append(signum)

    def hup(signum, _frame):
        got.append(signum)

    old = {s: signal.signal(s, h) for s, h in ((signal.SIGTERM, term), (signal.SIGHUP, hup))}
    old_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGUSR1})
    try:
        yield {"term": term, "hup": hup, "got": got, "mask": {signal.SIGUSR1} | set(old_mask)}
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, old_mask)
        for s, h in old.items():
            signal.signal(s, h)


def _as_before(handlers) -> None:
    assert signal.getsignal(signal.SIGTERM) is handlers["term"]
    assert signal.getsignal(signal.SIGHUP) is handlers["hup"]
    assert signal.pthread_sigmask(signal.SIG_BLOCK, []) == handlers["mask"]


_HANG = ["-c", "alias.hang=!sleep 30", "hang"]


@pytest.mark.parametrize("path", ["exit", "timeout", "signal", "no git"])
def test_handlers_and_mask_are_as_before_on_every_path(
    callers_handlers, monkeypatch, path, tmp_path
):
    if path == "exit":
        assert extends._run_git(["--version"])[0] == 0
    elif path == "timeout":
        with pytest.raises(extends._GitTimeout):
            extends._run_git(_HANG, timeout=0.5)
    elif path == "signal":
        _record_git(monkeypatch, then=lambda: os.kill(os.getpid(), signal.SIGTERM))
        with pytest.raises(extends._Signalled):
            extends._run_git(_HANG, timeout=60)
    else:
        monkeypatch.setenv("PATH", str(tmp_path))
        with pytest.raises(ManifestError, match="git is not installed"):
            extends._run_git(["--version"])
    _as_before(callers_handlers)
    assert callers_handlers["got"] == []


# A signal that arrives during the cleanup is held (blocked) and raised as _Signalled once the
# previous handlers and the mask are back, so resolve_chain removes the partial clone before
# it delivers the signal again to the previous handler: the caller's handler gets nothing from
# _run_git itself.


def test_a_signal_while_git_is_being_killed_is_raised_after_the_cleanup(
    callers_handlers, monkeypatch
):
    groups = []
    real_kill_group = extends._kill_group

    def kill_group_signalled(proc):
        groups.append(proc.pid)
        os.kill(os.getpid(), signal.SIGTERM)
        real_kill_group(proc)

    monkeypatch.setattr(extends, "_kill_group", kill_group_signalled)
    with pytest.raises(extends._Signalled) as raised:
        extends._run_git(_HANG, timeout=0.5)
    assert raised.value.signum == signal.SIGTERM
    _as_before(callers_handlers)
    assert callers_handlers["got"] == []
    assert _group_gone_within(groups[0], 5), "git's group was left running"


def test_a_signal_while_the_handlers_are_put_back_is_raised_after_the_cleanup(
    callers_handlers, monkeypatch
):
    real_signal = signal.signal

    def restore_then_hangup(signum, handler):
        old = real_signal(signum, handler)
        if handler is callers_handlers["term"]:  # SIGTERM is put back first, SIGHUP next
            os.kill(os.getpid(), signal.SIGHUP)
        return old

    monkeypatch.setattr(extends.signal, "signal", restore_then_hangup)
    with pytest.raises(extends._Signalled) as raised:
        extends._run_git(["--version"])
    monkeypatch.undo()
    assert raised.value.signum == signal.SIGHUP
    _as_before(callers_handlers)
    assert callers_handlers["got"] == []


def _trip(signum: int) -> None:
    """Simulate `signum` arriving: its Python handler runs at the interpreter's next check, with
    no OS signal (so a blocked mask does not hold it back). PyErr_SetInterruptEx is Python 3.10+.
    """
    import ctypes

    fn = ctypes.pythonapi.PyErr_SetInterruptEx
    fn.argtypes = [ctypes.c_int]
    fn.restype = ctypes.c_int
    assert fn(signum) == 0


def _trip_at_the_block(monkeypatch, signum: int, after: bool) -> None:
    """Make `signum` arrive as the cleanup blocks the caught signals: just before the masking
    call takes effect, or (after=True) inside it, once the mask has changed."""
    real = signal.pthread_sigmask
    done = []

    def masking(how, sigs):
        if how == signal.SIG_BLOCK and set(sigs) and not done:
            done.append(how)
            if after:
                old = real(how, sigs)
                _trip(signum)
                return old
            _trip(signum)
        return real(how, sigs)

    monkeypatch.setattr(extends.signal, "pthread_sigmask", masking)


def test_a_signal_at_the_start_of_the_cleanup_reaches_the_callers_handler(
    callers_handlers, monkeypatch, tmp_path
):
    # git exited normally; the signal lands as the cleanup begins, before the block.
    remote = _base_repo(tmp_path)
    cache = tmp_path / "cache"
    _trip_at_the_block(monkeypatch, signal.SIGTERM, after=False)
    with pytest.raises(ManifestError, match="git was stopped by SIGTERM"):
        resolve_chain(_leaf(tmp_path, remote.as_uri()), cache_dir=cache)
    monkeypatch.undo()
    _as_before(callers_handlers)
    assert callers_handlers["got"] == [signal.SIGTERM]
    assert list(cache.iterdir()) == []


def test_a_signal_inside_the_masking_call_leaves_no_signal_blocked(callers_handlers, monkeypatch):
    _trip_at_the_block(monkeypatch, signal.SIGTERM, after=True)
    with pytest.raises(extends._Signalled):
        extends._run_git(["--version"])
    monkeypatch.undo()
    _as_before(callers_handlers)


def test_the_handler_kills_git_when_the_signal_escapes_the_cleanup(callers_handlers, monkeypatch):
    # The signal lands as the cleanup of a timed-out git begins, so the cleanup's own kill is
    # skipped: the handler must have killed git's group itself.
    started = _record_git(monkeypatch)
    _trip_at_the_block(monkeypatch, signal.SIGTERM, after=False)
    with pytest.raises(extends._Signalled):
        extends._run_git(_HANG, timeout=0.5)
    monkeypatch.undo()
    _as_before(callers_handlers)
    # The cleanup's kill, which also reaps git, was skipped: git is a zombie until reaped here.
    assert started[0].wait(timeout=5) == -signal.SIGKILL, "git was left running"
    assert _group_gone_within(started[0].pid, 5), "git's group was left running"
    started[0].communicate()


def test_a_signal_pending_at_the_unmask_leaves_no_partial_clone(tmp_path):
    # The default disposition: a SIGTERM while git's group is killed (after the time limit) is
    # held, then raised, so the partial clone is removed before the resolver ends by it.
    proc, ssh_pid, cache = _resolver_with_stalled_clone(
        tmp_path,
        prelude=(
            "import os, ros_manifest.extends as ex\n"
            "real_kill_group = ex._kill_group\n"
            "def kill_group(p):\n"
            "    os.kill(os.getpid(), signal.SIGTERM)\n"
            "    real_kill_group(p)\n"
            "ex._kill_group = kill_group"
        ),
        limit="1",
    )
    try:
        assert proc.wait(timeout=15) == -signal.SIGTERM
        assert _gone_within(ssh_pid, 5), "git's ssh outlived the resolver"
        assert list(cache.iterdir()) == []
    finally:
        _stop(proc)


def test_a_timed_out_git_returns_soon_after_the_limit_while_a_child_holds_its_stdout(tmp_path):
    # A program that left git's group and holds git's stdout (the one pipe _run_git reads;
    # stderr is /dev/null) must not keep _run_git waiting more than its 2 s bound after the
    # kill. In a clone git's own children (ssh, a remote helper) get pipes of git's, not this
    # one, so the holder is started the way any git child that inherits stdout would be: by an
    # alias that runs a command.
    holder_pid = tmp_path / "holder.pid"
    hold = _script(
        tmp_path / "hold",
        f'"{sys.executable}" -c "import os, time; os.setsid();'
        f" open('{holder_pid}', 'w').write(str(os.getpid())); time.sleep(20)\" &\n"
        "exec sleep 30\n",
    )
    started = time.monotonic()
    try:
        with pytest.raises(extends._GitTimeout):
            extends._run_git(["-c", f"alias.hold=!{hold}", "hold"], timeout=1)
        assert time.monotonic() - started < 6
        assert holder_pid.exists(), "the detached holder never started"
    finally:
        if holder_pid.exists() and holder_pid.read_text().strip():
            try:
                os.kill(int(holder_pid.read_text().strip()), signal.SIGKILL)
            except ProcessLookupError:
                pass


def test_no_askpass_runs(tmp_path, monkeypatch):
    # The user's askpass, by core.askPass and by GIT_ASKPASS and SSH_ASKPASS, is not run when git
    # needs a password under the resolver's options and environment; plain git does run it.
    marker = tmp_path / "askpass-ran"
    spy = _script(tmp_path / "askpass-spy", f'touch "{marker}"\necho nope\n')
    _user_config(monkeypatch, [("core.askPass", str(spy))])
    monkeypatch.setenv("GIT_ASKPASS", str(spy))
    monkeypatch.setenv("SSH_ASKPASS", str(spy))
    ask = b"protocol=https\nhost=example.invalid\n\n"
    subprocess.run(
        ["git", *extends._SAFETY, "credential", "fill"],
        input=ask,
        capture_output=True,
        env=extends._git_env(),
        start_new_session=True,
    )
    assert not marker.exists()
    # Control: plain git with the same configuration asks the spy.
    subprocess.run(
        ["git", "credential", "fill"],
        input=ask,
        capture_output=True,
        env=dict(os.environ, GIT_TERMINAL_PROMPT="0"),
        start_new_session=True,
    )
    assert marker.exists()
