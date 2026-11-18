"""Cloning one missing repo: a destination that exists is never written into, the check on the
real destination, a place filled while the clone ran, and the sweep of a dead run's
temporaries."""

import os
import stat
import subprocess
import sys

import pytest
import yaml

from helpers import dead_pid, make_remote, repo, run, snapshot, temporaries, write_manifest
from repos_manifest.sync import sweep_temporaries
from repos_manifest.system import is_in_place


@pytest.fixture
def setup(vcs, tmp_path):
    """A flat system with no distro, its manifest and one cloned repo `a`; `add(key, ...)` adds
    a repo to the manifest."""
    remote = make_remote(tmp_path / "remotes", "r")
    path = tmp_path / "m.manifest.yaml"
    data = {"format": 1, "repositories": {"a": repo(remote)}}
    write_manifest(path, data)
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0

    def add(key, layer=None, optional=False):
        if layer is not None:
            data.setdefault("layers", [])
            if layer not in data["layers"]:
                data["layers"].append(layer)
        data["repositories"][key] = repo(remote, layer=layer, optional=optional)
        write_manifest(path, data)

    return system, add


def _recorded(system):
    return set(
        yaml.safe_load((system / ".repos-manifest/state.yaml").read_text())["distros"]["_unnamed"][
            "repos"
        ]
    )


def test_a_nested_key_arrives_with_its_directories_made(setup):
    system, add = setup
    add("grp/sub/c")
    assert run(system, "sync") == 0
    assert (system / "src/grp/sub/c/README").is_file()
    assert sorted(os.listdir(system / "src/grp")) == ["sub"]
    assert temporaries(system) == []


@pytest.mark.parametrize("kind", ["directory", "empty directory", "file", "link"])
def test_a_destination_that_exists_is_present_and_untouched(setup, tmp_path, capsys, kind):
    system, add = setup
    place = system / "src" / "d"
    if kind == "directory":
        place.mkdir()
        (place / "mine.txt").write_text("a person's work\n")
    elif kind == "empty directory":
        place.mkdir()
    elif kind == "file":
        place.write_text("a person's file\n")
    else:
        (tmp_path / "elsewhere").mkdir()
        place.symlink_to(tmp_path / "elsewhere")
    add("d")
    before = snapshot(tmp_path)
    capsys.readouterr()
    assert run(system, "sync") == 0
    after = snapshot(tmp_path)
    resolved = lambda snap: {k: v for k, v in snap.items() if "resolved" not in k}  # noqa: E731
    assert resolved(after) == resolved(before)
    assert _recorded(system) == {"a"}
    assert "present, not touched (2)" in capsys.readouterr().out


def test_a_link_inside_src_on_the_way_refuses_the_repo(setup, tmp_path, capsys):
    system, add = setup
    outside = tmp_path / "outside"
    outside.mkdir()
    (system / "src" / "grp").symlink_to(outside)
    add("grp/c")
    add("b")
    assert run(system, "sync") == 1
    assert os.listdir(outside) == []
    assert (system / "src/b/README").is_file()
    assert _recorded(system) == {"a", "b"}
    assert "ERROR: src/grp/c: a link on the way leads outside its place" in capsys.readouterr().out
    assert temporaries(system) == []


def test_a_layer_directory_that_is_a_link_refuses_its_repos(setup, tmp_path, capsys):
    system, add = setup
    outside = tmp_path / "outside"
    outside.mkdir()
    (system / "core").symlink_to(outside)
    add("c", layer="core")
    assert run(system, "sync") == 1
    assert os.listdir(outside) == []
    assert "ERROR: core/src/c: a link on the way" in capsys.readouterr().out


def test_the_check_on_the_real_destination(tmp_path):
    system = tmp_path / "sys"
    (system / "src").mkdir(parents=True)
    (tmp_path / "out").mkdir()
    assert is_in_place(system, ("src", "a"))
    assert is_in_place(system, ("src", "grp", "sub", "a"))  # not made yet
    (system / "src" / "grp").symlink_to(tmp_path / "out")
    assert not is_in_place(system, ("src", "grp", "a"))
    (system / "core").symlink_to(system / "src")  # a link that stays inside is refused too
    assert not is_in_place(system, ("core", "src", "a"))


def _stub_vcs(tmp_path, monkeypatch, body):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    stub = bin_dir / "vcs"
    stub.write_text("#!/bin/sh\n" 'if [ "$1" = --version ]; then exit 0; fi\n' f"{body}\n")
    stub.chmod(stub.stat().st_mode | stat.S_IXUSR)
    monkeypatch.setenv("PATH", f"{bin_dir}{os.pathsep}{os.environ['PATH']}")


def test_a_place_filled_while_cloning_is_left_as_it_is(setup, tmp_path, monkeypatch, capsys):
    # Another run (or a person) fills the place while this run's clone is made.
    system, add = setup
    add("d")
    place = system / "src" / "d"
    _stub_vcs(
        tmp_path,
        monkeypatch,
        f'cat >/dev/null; mkdir -p "$2/d" "{place}"; echo theirs > "{place}/theirs.txt"',
    )
    assert run(system, "sync") == 1
    assert os.listdir(place) == ["theirs.txt"]
    assert "ERROR: src/d: appeared meanwhile; left as it is" in capsys.readouterr().out
    assert temporaries(system) == []
    assert _recorded(system) == {"a"}


def test_a_failed_clone_leaves_nothing_but_the_message(setup, tmp_path, monkeypatch, capsys):
    # vcs leaves a part-made clone in its directory and fails: only that directory is removed.
    system, add = setup
    add("d")
    _stub_vcs(tmp_path, monkeypatch, 'cat >/dev/null; mkdir -p "$2/d/.git"; echo broken; exit 1')
    before = snapshot(system / "src")
    assert run(system, "sync") == 1
    assert snapshot(system / "src") == before
    assert temporaries(system) == []
    assert "ERROR: src/d: vcs import exited 1:\nbroken" in capsys.readouterr().out


def _temporary(directory, pid, rest="abcd_123", kind="dir"):
    path = directory / f".repos-manifest-tmp-{pid}-{rest}"
    if kind == "dir":
        (path / "half" / ".git").mkdir(parents=True)
        (path / "half" / "file").write_text("x")
        os.chmod(path / "half", 0o500)
    else:
        path.write_text("x")
    return path


def test_the_sweep_removes_only_a_dead_runs_temporaries(tmp_path):
    directory = tmp_path / "d"
    directory.mkdir()
    dead = dead_pid()
    sleeper = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
    try:
        gone = [_temporary(directory, dead), _temporary(directory, dead, "efgh_456", "file")]
        kept = [
            _temporary(directory, sleeper.pid),
            directory / ".repos-manifest-tmp-foo",
            directory / f".repos-manifest-tmp-{dead}-abcd_123-more",
            directory / "keep",
        ]
        for path in kept[1:]:
            path.mkdir()
        link = directory / f".repos-manifest-tmp-{dead}-link_123"
        link.symlink_to(directory / "keep")
        kept.append(link)
        before = snapshot(directory)
        sweep_temporaries(directory)
        assert not any(os.path.lexists(p) for p in gone)
        assert all(os.path.lexists(p) for p in kept)
        assert {k: v for k, v in before.items() if k.split("/")[0] in {p.name for p in kept}} == (
            snapshot(directory)
        )
    finally:
        sleeper.kill()
        sleeper.wait()
        for path in directory.rglob("*"):
            if path.is_dir() and not path.is_symlink():
                path.chmod(0o700)
