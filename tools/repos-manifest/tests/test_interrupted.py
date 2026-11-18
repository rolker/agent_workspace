"""An interrupted `init`: before its config step nothing exists and `init` runs again; after
it, `sync` finishes. A stopped clone leaves no path and no temporary; a killed run's temporary
is swept by the next run."""

import io
import os
import shutil
import signal
import subprocess
import sys

import pytest
import yaml

from helpers import dead_pid, make_remote, repo, run, snapshot, temporaries, write_manifest
import repos_manifest
from repos_manifest import init, sync
from repos_manifest.signals import Stopped


@pytest.fixture
def manifest(vcs, tmp_path):
    remotes = tmp_path / "remotes"
    data = {
        "format": 1,
        "distros": ["jazzy"],
        "layers": ["underlay", "core"],
        "repositories": {
            "a": repo(make_remote(remotes, "a", branches=["jazzy"]), "jazzy", "underlay"),
            "b": repo(make_remote(remotes, "b"), None, "core"),
            "c": repo(make_remote(remotes, "c"), None, "core"),
        },
    }
    return write_manifest(tmp_path / "m.manifest.yaml", data)


def _system(tmp_path, name="sys"):
    path = tmp_path / name
    path.mkdir()
    return path


def _tree(system):
    """The paths below the system directory, without the inside of the clones' .git, and the
    text of config.yaml and of state.yaml without the commits."""
    paths = sorted(
        str(p.relative_to(system))
        for p in system.rglob("*")
        if ".git" not in p.relative_to(system).parts[:-1]
    )
    state = yaml.safe_load((system / ".repos-manifest/state.yaml").read_text())
    return paths, (system / ".repos-manifest/config.yaml").read_text(), state


INIT = ("init", "../m.manifest.yaml", "--distro", "jazzy", "--yes")


def test_stopped_at_the_question_nothing_is_created(manifest, tmp_path, monkeypatch, capsys):
    class StoppedTerminal(io.StringIO):
        def isatty(self):
            return True

        def readline(self, *args):
            raise Stopped(signal.SIGINT)

    system = _system(tmp_path)
    monkeypatch.setattr("sys.stdin", StoppedTerminal())
    assert run(system, "init", "../m.manifest.yaml", "--distro", "jazzy") == 128 + signal.SIGINT
    assert os.listdir(system) == []
    assert "stopped by SIGINT; nothing was created" in capsys.readouterr().err


def test_stopped_after_the_config_step_sync_finishes(manifest, tmp_path, monkeypatch, capsys):
    system = _system(tmp_path)

    def stop(*args):
        raise Stopped(signal.SIGINT)

    monkeypatch.setattr(init, "sync_distros", stop)
    assert run(system, *INIT) == 128 + signal.SIGINT
    assert "stopped by SIGINT; run `repos-manifest sync` to finish" in capsys.readouterr().err
    assert os.listdir(system) == [".repos-manifest"]
    assert os.listdir(system / ".repos-manifest") == ["config.yaml"]
    monkeypatch.undo()
    # init again is refused; sync makes everything.
    assert run(system, *INIT) == 1
    assert "a system is already set up" in capsys.readouterr().err
    assert run(system, "sync") == 0
    whole = _system(tmp_path, "whole")
    assert run(whole, *INIT) == 0
    assert _tree(system)[:2] == _tree(whole)[:2]
    ours, theirs = _tree(system)[2], _tree(whole)[2]
    for record in (ours, theirs):
        for entry in record["distros"]["jazzy"]["repos"].values():
            entry.pop("commit")
    assert ours == theirs


def test_stopped_during_a_clone_leaves_no_path_and_sync_finishes(
    manifest, tmp_path, monkeypatch, capsys
):
    system = _system(tmp_path)
    real = sync.vcs_import

    def vcs_import(directory, text, env):
        if "  b:" in text:
            (directory / "b" / ".git").mkdir(parents=True)  # a clone half made
            raise Stopped(signal.SIGINT)
        return real(directory, text, env)

    monkeypatch.setattr(sync, "vcs_import", vcs_import)
    assert run(system, *INIT) == 128 + signal.SIGINT
    assert not os.path.lexists(system / "core/src/b")
    assert temporaries(system) == []
    assert (system / "underlay/src/a/.git").is_dir()
    state = yaml.safe_load((system / ".repos-manifest/state.yaml").read_text())
    assert set(state["distros"]["jazzy"]["repos"]) == {"a"}
    monkeypatch.undo()
    assert run(system, "sync") == 0
    assert (system / "core/src/b/README").is_file() and (system / "core/src/c/README").is_file()
    assert (system / "setup.bash").is_file()


def test_a_killed_runs_temporary_in_the_system_dir_is_swept_by_init(manifest, tmp_path):
    system = _system(tmp_path)
    leftover = system / f".repos-manifest-tmp-{dead_pid()}-abcd_123"
    leftover.mkdir()
    (leftover / "config.yaml").write_text("manifest: x\n")
    assert run(system, *INIT) == 0
    assert not leftover.exists()


def test_a_killed_runs_clone_temporary_is_swept_by_sync(manifest, tmp_path):
    system = _system(tmp_path)
    assert run(system, *INIT) == 0
    leftover = system / ".repos-manifest" / f".repos-manifest-tmp-{dead_pid()}-abcd_123"
    (leftover / "b" / ".git").mkdir(parents=True)
    assert run(system, "sync") == 0
    assert temporaries(system) == []


def test_a_killed_run_loses_at_most_the_repo_in_progress(manifest, tmp_path):
    # A `vcs` in front of the real one kills the run (SIGKILL, which nothing can hold) while it
    # clones b: a, cloned before it, is recorded.
    real = shutil.which("vcs")
    stub = tmp_path / "bin" / "vcs"
    stub.parent.mkdir()
    stub.write_text(
        "#!/bin/sh\n"
        'if [ "$1" != import ]; then exec "$REAL_VCS" "$@"; fi\n'
        "text=$(cat)\n"
        'case "$text" in *"  b:"*) kill -9 "$PPID"; sleep 5; exit 1;; esac\n'
        'printf "%s\\n" "$text" | exec "$REAL_VCS" "$@"\n'
    )
    stub.chmod(0o755)
    system = _system(tmp_path)
    env = {
        **os.environ,
        "PATH": os.pathsep.join([str(stub.parent), os.environ["PATH"]]),
        "REAL_VCS": real,
        "PYTHONPATH": os.path.dirname(os.path.dirname(repos_manifest.__file__)),
    }
    done = subprocess.run(
        [sys.executable, "-c", "import sys; from repos_manifest.cli import main; sys.exit(main())"]
        + list(INIT),
        cwd=system,
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
    )
    assert done.returncode == -signal.SIGKILL, done.stderr
    state = yaml.safe_load((system / ".repos-manifest/state.yaml").read_text())
    assert set(state["distros"]["jazzy"]["repos"]) == {"a"}
    assert (system / "underlay/src/a/README").is_file()
    assert not os.path.lexists(system / "core/src/b")
    assert run(system, "sync") == 0
    state = yaml.safe_load((system / ".repos-manifest/state.yaml").read_text())
    assert set(state["distros"]["jazzy"]["repos"]) == {"a", "b", "c"}


@pytest.mark.parametrize("what", ["another file", "a subdirectory", "a file of that name"])
def test_inits_sweep_leaves_what_it_did_not_make_and_says_so(manifest, tmp_path, capsys, what):
    system = _system(tmp_path)
    leftover = system / f".repos-manifest-tmp-{dead_pid()}-abcd_123"
    if what == "a file of that name":
        leftover.write_text("a person's file\n")
    else:
        leftover.mkdir()
        (leftover / "config.yaml").write_text("manifest: x\n")
        if what == "another file":
            (leftover / "notes.txt").write_text("a person's notes\n")
        else:
            (leftover / "work").mkdir()
    before = snapshot(leftover) if leftover.is_dir() else leftover.read_text()
    assert run(system, *INIT) == 0
    assert (snapshot(leftover) if leftover.is_dir() else leftover.read_text()) == before
    err = capsys.readouterr().err
    assert f"WARNING: {leftover}: named like a temporary of repos-manifest, but" in err, err


def test_inits_sweep_removes_an_empty_aside(manifest, tmp_path):
    system = _system(tmp_path)
    leftover = system / f".repos-manifest-tmp-{dead_pid()}-abcd_123"
    leftover.mkdir()
    assert run(system, *INIT) == 0
    assert not leftover.exists()
