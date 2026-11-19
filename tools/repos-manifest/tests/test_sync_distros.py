"""`sync` per distro: a distro that does not resolve, or whose lock a build holds, is reported
and the others go on; the lock `sync` holds refuses a build; a built layer whose repos changed
is said to be behind; a stop or a kill while a repo is updated leaves it in a state the next
sync puts right or reports."""

import os
import shutil
import signal
import subprocess
import sys

import pytest
import yaml

from helpers import (
    branch,
    dead_pid,
    git,
    head,
    make_remote,
    push_commit,
    repo,
    rewrite_manifest,
    run,
    settled,
    snapshot,
    snapshot_repo,
    state_of,
    write_manifest,
)
import repos_manifest
from repos_manifest import sync
from repos_manifest.system import (
    LayerRecord,
    build_lock_file,
    built_file,
    hold_build_lock,
    put_built_layers,
)


@pytest.fixture
def two(vcs, tmp_path):
    """A system with a directory per distro, jazzy and rolling, each with repo a on main."""
    remote = make_remote(tmp_path / "remotes", "a", branches=["dev"])
    data = {
        "format": 1,
        "distros": ["jazzy", "rolling"],
        "layers": ["core"],
        "repositories": {"a": repo(remote, "main", "core")},
    }
    manifest = write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    argv = ["init", "../m.manifest.yaml", "--distro-dirs", "--distro", "jazzy"]
    assert run(system, *argv, "--distro", "rolling", "--yes") == 0
    return system, manifest, remote


def test_a_distro_the_manifest_no_longer_lists_is_reported_and_the_others_go_on(two, capsys):
    system, manifest, remote = two
    rewrite_manifest(manifest, lambda d: d.update(distros=["jazzy"]))
    new = push_commit(remote, "one", "1\n")
    rolling = settled(snapshot(system / "rolling"))
    resolved = snapshot(system / ".repos-manifest/resolved/rolling")
    capsys.readouterr()
    assert run(system, "sync") == 1
    out = capsys.readouterr().out
    assert (
        "ERROR: distro rolling: the manifest does not resolve for it; nothing of it has been"
        " moved or removed:"
    ) in out
    assert "does not cover distro 'rolling'" in out
    assert "distro rolling:\n  reported above; nothing of it was changed\n" in out
    assert head(system / "jazzy/core/src/a") == new
    assert settled(snapshot(system / "rolling")) == rolling
    assert snapshot(system / ".repos-manifest/resolved/rolling") == resolved


def test_a_distro_the_manifest_lists_and_the_system_does_not_record_is_not_made(two, capsys):
    system, manifest, _ = two
    rewrite_manifest(manifest, lambda d: d.update(distros=["jazzy", "rolling", "humble"]))
    assert run(system, "sync") == 0
    assert not os.path.lexists(system / "humble")
    assert "humble" not in capsys.readouterr().out


def test_a_distro_whose_lock_a_build_holds_is_reported_and_the_others_go_on(two, capsys):
    system, _, remote = two
    new = push_commit(remote, "one", "1\n")
    resolved = snapshot(system / ".repos-manifest/resolved/rolling")
    before = snapshot_repo(system / "rolling/core/src/a")
    fd = hold_build_lock(system, "rolling")  # as a running build does
    try:
        capsys.readouterr()
        assert run(system, "sync") == 1
    finally:
        os.close(fd)
    out = capsys.readouterr().out
    assert (
        f"ERROR: a build of distro rolling is still running in this system (process"
        f" {os.getpid()}); nothing was changed for it. It holds the lock on"
        f" {build_lock_file(system, 'rolling')}."
    ) in out
    assert snapshot_repo(system / "rolling/core/src/a") == before
    assert snapshot(system / ".repos-manifest/resolved/rolling") == resolved
    assert head(system / "jazzy/core/src/a") == new
    assert run(system, "sync") == 0
    assert head(system / "rolling/core/src/a") == new


def test_a_build_is_refused_while_a_sync_of_its_distro_holds_the_lock(two, capsys):
    system, _, _ = two
    fd = hold_build_lock(system, "jazzy", holder="sync")
    try:
        assert build_lock_file(system, "jazzy").read_text() == f"sync {os.getpid()}\n"
        capsys.readouterr()
        assert run(system, "build", "--distro", "jazzy") == 1
    finally:
        os.close(fd)
    err = capsys.readouterr().err
    assert (
        f"a sync of distro jazzy is still running in this system (process {os.getpid()});"
        " nothing was run"
    ) in err, err
    assert "colcon" not in err


def test_a_sync_whose_process_ended_while_its_git_runs_names_fuser(two, capsys):
    # A killed sync's git may still hold the lock; the file names only the sync, never a git.
    system, _, _ = two
    fd = hold_build_lock(system, "jazzy", holder="sync")
    try:
        os.pwrite(fd, f"sync {dead_pid()}\n".encode(), 0)
        capsys.readouterr()
        assert run(system, "sync", "--distro", "jazzy") == 1
    finally:
        os.close(fd)
    out = capsys.readouterr().out
    lock = build_lock_file(system, "jazzy")
    assert (
        f"a sync of distro jazzy is still running in this system; `fuser -v {lock}` names the"
        " process that holds its lock; nothing was changed for it"
    ) in out


def test_init_takes_the_lock_for_its_first_sync(vcs, tmp_path, monkeypatch):
    remote = make_remote(tmp_path / "remotes", "a")
    write_manifest(tmp_path / "m.yaml", {"format": 1, "repositories": {"a": repo(remote)}})
    system = tmp_path / "sys"
    system.mkdir()
    taken = []
    real = sync.hold_build_lock

    def hold(system_, distro, holder="build"):
        taken.append((distro, holder))
        return real(system_, distro, holder)

    monkeypatch.setattr(sync, "hold_build_lock", hold)
    assert run(system, "init", "../m.yaml", "--yes") == 0
    assert taken == [(None, "sync")]


def test_a_built_layer_whose_repos_changed_is_said_to_be_behind(two, capsys):
    system, _, remote = two
    put_built_layers(system, "jazzy", {"core": LayerRecord("2026-11-19T10:00:00", ["a"], [])})
    record = built_file(system, "jazzy").read_bytes()
    push_commit(remote, "one", "1\n")
    capsys.readouterr()
    assert run(system, "sync") == 0
    out = capsys.readouterr().out
    note = (
        "layer core was built before and 1 of its repos changed since; `repos-manifest build`"
        " brings it, and the layers above it, up to date"
    )
    assert out.count(note) == 1  # jazzy only: rolling was never built
    assert built_file(system, "jazzy").read_bytes() == record
    assert run(system, "sync") == 0
    assert note not in capsys.readouterr().out


def test_an_unreadable_build_record_is_a_warning(two, capsys):
    system, _, remote = two
    built_file(system, "jazzy").write_text("format: 9\nlayers: {}\n")
    push_commit(remote, "one", "1\n")
    capsys.readouterr()
    assert run(system, "sync") == 0
    assert "whether a built layer is behind is not said" in capsys.readouterr().err


def test_a_moved_repo_holding_the_manifest_says_the_next_sync_reads_it(vcs, tmp_path, capsys):
    remote = make_remote(tmp_path / "remotes", "m")
    data = {"format": 1, "repositories": {"m": repo(remote, "main")}}
    write_manifest(remote / "m.manifest.yaml", data)
    git("add", "m.manifest.yaml", cwd=remote)
    git("commit", "-q", "-m", "the manifest", cwd=remote)
    system = tmp_path / "sys"
    system.mkdir()
    shutil.copy(remote / "m.manifest.yaml", tmp_path / "first.yaml")
    assert run(system, "init", "../first.yaml", "--yes") == 0
    config = system / ".repos-manifest/config.yaml"
    config.write_text(config.read_text().replace("../first.yaml", "src/m/m.manifest.yaml"))
    push_commit(remote, "other", "x\n")
    capsys.readouterr()
    assert run(system, "sync") == 0
    assert (
        "src/m: holds the manifest, which this sync read before it was moved; the next sync"
        " reads its new text"
    ) in capsys.readouterr().out


# --- A stop or a kill while a repo is updated -------------------------------------------------


STUB_GIT = """#!/bin/sh
sub=""
skip=0
for a in "$@"; do
  if [ "$skip" = 1 ]; then skip=0; continue; fi
  case "$a" in -C|-c) skip=1;; -*) ;; *) sub="$a"; break;; esac
done
if [ "$sub" = "$STUB_ON" ]; then
  case "$STUB_DO" in
    kill-before) kill -9 "$PPID"; sleep 5; exit 1;;
    kill-after) "$REAL_GIT" "$@"; s=$?; kill -9 "$PPID"; exit "$s";;
    term-during) kill -TERM "$PPID"; sleep 0.3; exec "$REAL_GIT" "$@";;
    fail) echo "stub refuses" >&2; exit 1;;
    plant) printf 'precious\n' >"$STUB_PLANT"; exec "$REAL_GIT" "$@";;
  esac
fi
exec "$REAL_GIT" "$@"
"""


def _sync_with_stub(tmp_path, system, on, do, plant=""):
    """`sync` in a process of its own, with a `git` first on PATH that acts on the subcommand
    `on` as `do` says (`plant`: write the file `plant` just before it); returns the process."""
    stub = tmp_path / "stub-bin" / "git"
    stub.parent.mkdir(exist_ok=True)
    stub.write_text(STUB_GIT)
    stub.chmod(0o755)
    env = {
        **os.environ,
        "PATH": os.pathsep.join([str(stub.parent), os.environ["PATH"]]),
        "REAL_GIT": shutil.which("git"),
        "STUB_ON": on,
        "STUB_DO": do,
        "STUB_PLANT": str(plant),
        "PYTHONPATH": os.path.dirname(os.path.dirname(repos_manifest.__file__)),
    }
    done = subprocess.run(
        [sys.executable, "-m", "repos_manifest.cli", "sync", "--distro", "jazzy"],
        cwd=system,
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )
    return done


def test_a_kill_before_the_fetch_changes_nothing_and_the_next_sync_follows(two, tmp_path, capsys):
    system, _, remote = two
    clone = system / "jazzy/core/src/a"
    new = push_commit(remote, "one", "1\n")
    before = snapshot_repo(clone)
    recorded = state_of(system, "jazzy")
    done = _sync_with_stub(tmp_path, system, "fetch", "kill-before")
    assert done.returncode == -signal.SIGKILL, done.stderr
    assert snapshot_repo(clone) == before
    assert state_of(system, "jazzy") == recorded
    assert run(system, "sync", "--distro", "jazzy") == 0
    assert head(clone) == new


@pytest.mark.parametrize("on", ["merge", "switch"])
def test_a_kill_after_the_move_is_recorded_by_the_next_sync(two, tmp_path, capsys, on):
    system, manifest, remote = two
    clone = system / "jazzy/core/src/a"
    if on == "merge":
        target = push_commit(remote, "one", "1\n")
    else:
        rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(version="dev"))
        target = git("rev-parse", "dev", cwd=remote)
    done = _sync_with_stub(tmp_path, system, on, "kill-after")
    assert done.returncode == -signal.SIGKILL, done.stderr
    assert head(clone) == target
    assert state_of(system, "jazzy")["a"]["moving"]["to"] == target
    capsys.readouterr()
    assert run(system, "sync", "--distro", "jazzy") == 0
    assert "up to date (1)" in capsys.readouterr().out
    record = state_of(system, "jazzy")["a"]
    assert record["commit"] == target and "moving" not in record


@pytest.mark.parametrize("on", ["merge", "switch"])
def test_a_stop_signal_while_git_moves_the_repo_waits_for_it(two, tmp_path, capsys, on):
    # The signal is held while the git that changes the tree runs (and git inherits it held):
    # the move is whole, and the run ends after it with the signal.
    system, manifest, remote = two
    clone = system / "jazzy/core/src/a"
    if on == "merge":
        target = push_commit(remote, "one", "1\n")
    else:
        rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(version="dev"))
        target = git("rev-parse", "dev", cwd=remote)
    done = _sync_with_stub(tmp_path, system, on, "term-during")
    assert done.returncode == -signal.SIGTERM, done.stderr
    assert "stopped by SIGTERM" in done.stderr
    assert head(clone) == target
    assert git("status", "--porcelain", "--untracked-files=no", cwd=clone) == ""
    assert branch(clone) == ("main" if on == "merge" else "dev")
    capsys.readouterr()
    assert run(system, "sync", "--distro", "jazzy") == 0
    assert "moving" not in state_of(system, "jazzy")["a"]


def test_a_second_step_that_fails_is_undone_and_the_repo_left_as_it_was(two, tmp_path, capsys):
    # Back to a branch that exists locally and is behind: a switch, then a fast-forward. The
    # fast-forward fails, so the switch is undone.
    system, manifest, remote = two
    clone = system / "jazzy/core/src/a"
    rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(version="dev"))
    assert run(system, "sync", "--distro", "jazzy") == 0
    push_commit(remote, "one", "1\n")
    rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(version="main"))
    git("fetch", "-q", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    recorded = state_of(system, "jazzy")["a"]
    done = _sync_with_stub(tmp_path, system, "merge", "fail")
    assert done.returncode == 0, done.stdout + done.stderr
    assert "src/a: left alone: `git merge` exited 1; left as it was:\nstub refuses" in done.stdout
    assert snapshot_repo(clone, fetched=True) == before
    assert branch(clone) == "dev"
    assert state_of(system, "jazzy")["a"] == recorded


@pytest.mark.parametrize("on", ["merge", "switch"])
def test_an_ignored_file_made_just_before_the_move_is_never_overwritten(two, tmp_path, capsys, on):
    # The paths check found nothing; an ignored file appears where an incoming file goes
    # between the check and git's call (a build writing a log): git itself refuses.
    system, manifest, remote = two
    clone = system / "jazzy/core/src/a"
    push_commit(remote, ".gitignore", "*.log\n")
    assert run(system, "sync", "--distro", "jazzy") == 0
    if on == "merge":
        push_commit(remote, "incoming.log", "theirs\n")
    else:
        push_commit(remote, "incoming.log", "theirs\n", "dev")
        rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(version="dev"))
    git("fetch", "-q", "origin", cwd=clone)
    was = head(clone)
    recorded = state_of(system, "jazzy")["a"]
    done = _sync_with_stub(tmp_path, system, on, "plant", clone / "incoming.log")
    assert done.returncode == 0, done.stdout + done.stderr
    assert f"src/a: left alone: `git {on}` exited" in done.stdout
    assert "left as it was" in done.stdout
    assert (clone / "incoming.log").read_text() == "precious\n"
    assert head(clone) == was and branch(clone) == "main"
    assert state_of(system, "jazzy")["a"] == recorded


def test_a_failed_fast_forward_of_a_repo_with_no_record_leaves_no_moving_line(
    two, tmp_path, capsys
):
    system, _, remote = two
    clone = system / "jazzy/core/src/a"
    state = system / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    del data["distros"]["jazzy"]["repos"]["a"]
    state.write_text(yaml.safe_dump(data))
    push_commit(remote, "one", "1\n")
    was = head(clone)
    done = _sync_with_stub(tmp_path, system, "merge", "fail")
    assert done.returncode == 0, done.stdout + done.stderr
    assert "src/a: left alone: `git merge` exited 1; left as it was" in done.stdout
    record = state_of(system, "jazzy")["a"]
    assert "moving" not in record and record["commit"] == was


def test_resolved_files_that_cannot_be_written_are_reported_for_that_distro(two, capsys):
    system, _, remote = two
    jazzy = system / ".repos-manifest/resolved/jazzy"
    shutil.rmtree(jazzy)
    jazzy.write_text("a file where the directory goes\n")
    new = push_commit(remote, "one", "1\n")
    capsys.readouterr()
    assert run(system, "sync") == 1
    out = capsys.readouterr().out
    assert (
        f"ERROR: the resolved files' directory {jazzy}: exists and is not a directory" in out
    ), out
    assert "None of this distro's repos was touched" in out
    assert "distro jazzy:\n  reported above; nothing of it was changed" in out
    assert head(system / "rolling/core/src/a") == new
    assert head(system / "jazzy/core/src/a") != new
