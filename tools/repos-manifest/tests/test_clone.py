"""Cloning one missing repo: a destination that exists is never written into, the check on the
real destination, a place filled while the clone ran, and the sweep of a dead run's
temporaries."""

import errno
import os
import stat
import subprocess
import sys

import pytest
import yaml

from helpers import dead_pid, head, make_remote, repo, run, snapshot, temporaries, write_manifest
from repos_manifest import sync
from repos_manifest.sync import rename_failure, sweep_temporaries
from repos_manifest.system import place_problem


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


@pytest.mark.parametrize("kind", ["directory", "empty directory", "link"])
def test_a_destination_that_exists_is_present_and_untouched(setup, tmp_path, capsys, kind):
    system, add = setup
    place = system / "src" / "d"
    if kind == "directory":
        place.mkdir()
        (place / "mine.txt").write_text("a person's work\n")
    elif kind == "empty directory":
        place.mkdir()
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


@pytest.mark.parametrize("kind", ["file", "dangling link"])
@pytest.mark.parametrize("optional", [False, True])
def test_a_place_that_is_not_a_directory_is_reported(setup, tmp_path, capsys, kind, optional):
    system, add = setup
    place = system / "src" / "d"
    if kind == "file":
        place.write_text("a person's file\n")
    else:
        place.symlink_to(tmp_path / "nowhere")
    add("d", optional=optional)
    before = snapshot(tmp_path)
    capsys.readouterr()
    assert run(system, "sync") == (0 if optional else 1)
    after = snapshot(tmp_path)
    resolved = lambda snap: {k: v for k, v in snap.items() if "resolved" not in k}  # noqa: E731
    assert resolved(after) == resolved(before)
    assert _recorded(system) == {"a"}
    out = capsys.readouterr().out
    if optional:
        assert "skipped src/d (optional): is there and is not a directory; left as it is" in out
    else:
        assert "ERROR: src/d: is there and is not a directory; left as it is" in out
        assert "another sync will not change that" in out


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


IN_THE_WAY = (
    "Some repos could not be put in place, and another sync will not change that: the ERROR"
    " lines above say what is in the way.\n"
)
FETCH = "Some repos failed; run `repos-manifest sync` to finish once they can be fetched.\n"


def test_the_closing_advice_says_sync_again_only_for_what_a_sync_can_fix(setup, tmp_path, capsys):
    system, add = setup
    outside = tmp_path / "outside"
    outside.mkdir()
    (system / "src" / "grp").symlink_to(outside)
    add("grp/c")
    capsys.readouterr()
    assert run(system, "sync") == 1
    out = capsys.readouterr().out
    assert out.endswith(IN_THE_WAY) and FETCH not in out, out
    path = tmp_path / "m.manifest.yaml"
    data = yaml.safe_load(path.read_text())
    data["repositories"]["later"] = repo(tmp_path / "remotes" / "later")
    write_manifest(path, data)
    assert run(system, "sync") == 1
    assert capsys.readouterr().out.endswith(FETCH + IN_THE_WAY)
    (system / "src" / "grp").unlink()
    assert run(system, "sync") == 1
    out = capsys.readouterr().out
    assert out.endswith(FETCH) and IN_THE_WAY not in out, out


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
    link = "a link on the way leads outside its place"
    assert place_problem(system, ("src", "a")) is None
    assert place_problem(system, ("src", "grp", "sub", "a")) is None  # not made yet
    (system / "src" / "grp").symlink_to(tmp_path / "out")
    assert place_problem(system, ("src", "grp", "a")) == link
    (system / "core").symlink_to(system / "src")  # a link that stays inside is refused too
    assert place_problem(system, ("core", "src", "a")) == link
    (system / "src" / "file").write_text("x")  # a file where a directory belongs
    assert place_problem(system, ("src", "file", "sub", "a")) == (
        "src/file is on the way and is not a directory"
    )
    (system / "layer").write_text("x")
    assert place_problem(system, ("layer", "src", "a")) == (
        "layer is on the way and is not a directory"
    )


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
        'cat >/dev/null; git init -q "$2/d"; git -C "$2/d" commit -q --allow-empty -m one;'
        f' mkdir -p "{place}"; echo theirs > "{place}/theirs.txt"',
    )
    assert run(system, "sync") == 1
    assert os.listdir(place) == ["theirs.txt"]
    assert "ERROR: src/d: appeared meanwhile; left as it is" in capsys.readouterr().out
    assert temporaries(system) == []
    assert _recorded(system) == {"a"}


def test_a_place_made_while_the_clones_head_is_read_is_left_as_it_is(setup, monkeypatch, capsys):
    # Reading the clone's HEAD runs a git; the last check of the place comes after it, so an
    # empty directory made meanwhile is found, not replaced by the rename.
    system, add = setup
    add("d")
    place = system / "src" / "d"
    read_head = sync._head

    def head_while_a_place_is_made(path, env):
        place.mkdir()
        return read_head(path, env)

    monkeypatch.setattr(sync, "_head", head_while_a_place_is_made)
    capsys.readouterr()
    assert run(system, "sync") == 1
    assert os.listdir(place) == []
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


def test_a_clone_that_cannot_be_moved_to_another_filesystem_says_so(tmp_path):
    # A distro or layer directory that is a separate mount: the rename from .repos-manifest/
    # fails with EXDEV. No test here can mount one, so the message is checked on the error.
    system = tmp_path / "sys"
    place = system / "rolling" / "src" / "a"
    temporary = system / ".repos-manifest" / ".repos-manifest-tmp-1-abcd_123" / "a"
    exc = OSError(errno.EXDEV, os.strerror(errno.EXDEV), str(temporary), None, str(place))
    assert rename_failure(exc, system, place) == (
        f"{place}: the clone, made in {system / '.repos-manifest'}, cannot be moved there"
        " because the two are on different filesystems; a system directory must be on one"
        " filesystem"
    )
    other = OSError(errno.EACCES, os.strerror(errno.EACCES), str(temporary), None, str(place))
    # The temporary is gone by the time the message is read, so it names only the place.
    assert rename_failure(other, system, place) == f"{place}: Permission denied"


@pytest.mark.parametrize("what", ["link on the way", "file on the way", "appeared meanwhile"])
@pytest.mark.parametrize("optional", [False, True])
def test_whatever_stops_a_repo_skips_it_when_optional_and_fails_it_otherwise(
    setup, tmp_path, monkeypatch, capsys, what, optional
):
    # One rule: an optional repo that cannot be put in place is skipped and listed with the
    # reason, and the exit status stays 0; any other repo is an error and the status is 1.
    system, add = setup
    add("grp/c", optional=optional)
    if what == "link on the way":
        (tmp_path / "outside").mkdir()
        (system / "src" / "grp").symlink_to(tmp_path / "outside")
    elif what == "file on the way":
        (system / "src" / "grp").write_text("a person's file\n")
    else:
        place = system / "src" / "grp" / "c"
        _stub_vcs(tmp_path, monkeypatch, f'cat >/dev/null; mkdir -p "$2/grp/c" "{place}"')
    capsys.readouterr()
    assert run(system, "sync") == (0 if optional else 1)
    out = capsys.readouterr().out
    if optional:
        assert "skipped src/grp/c (optional): " in out
        assert "optional, skipped (1): src/grp/c" in out
        assert "ERROR" not in out and "Some repos" not in out
    else:
        assert "ERROR: src/grp/c: " in out
        assert "failed (1): src/grp/c" in out
    assert _recorded(system) == {"a"}
    assert temporaries(system) == []


def test_git_namespace_in_the_environment_does_not_reach_the_clones(setup, tmp_path, monkeypatch):
    # GIT_NAMESPACE makes a clone from a local path see no refs; git's --local-env-vars does
    # not list it, so the tool removes it with them.
    system, add = setup
    add("b")
    monkeypatch.setenv("GIT_NAMESPACE", "elsewhere")
    assert run(system, "sync") == 0
    monkeypatch.delenv("GIT_NAMESPACE")
    state = yaml.safe_load((system / ".repos-manifest/state.yaml").read_text())
    remote_head = head(tmp_path / "remotes" / "r")
    assert state["distros"]["_unnamed"]["repos"]["b"]["commit"] == remote_head
    assert head(system / "src" / "b") == remote_head


def test_a_clone_whose_head_cannot_be_read_is_that_repos_failure(
    setup, tmp_path, monkeypatch, capsys
):
    system, add = setup
    add("d")
    _stub_vcs(tmp_path, monkeypatch, 'cat >/dev/null; git init -q "$2/d"')
    capsys.readouterr()
    assert run(system, "sync") == 1
    assert "ERROR: src/d: the clone's HEAD cannot be read; not put in place" in (
        capsys.readouterr().out
    )
    assert not os.path.lexists(system / "src" / "d")
    assert _recorded(system) == {"a"}
    assert temporaries(system) == []


def test_a_remote_with_no_commits_yet_is_a_failure_a_later_sync_fixes(setup, tmp_path, capsys):
    # Nothing is in the way: once the remote has a commit, another sync clones it, and the
    # closing advice says so.
    system, add = setup
    empty = tmp_path / "remotes" / "empty"
    empty.mkdir()
    subprocess.run(["git", "init", "-q", "-b", "main", str(empty)], check=True)
    path = tmp_path / "m.manifest.yaml"
    data = yaml.safe_load(path.read_text())
    data["repositories"]["e"] = repo(empty)
    write_manifest(path, data)
    capsys.readouterr()
    assert run(system, "sync") == 1
    out = capsys.readouterr().out
    assert "ERROR: src/e: " in out
    assert out.endswith(FETCH) and IN_THE_WAY not in out, out
    assert not os.path.lexists(system / "src" / "e")
    (empty / "README").write_text("e\n")
    subprocess.run(["git", "-C", str(empty), "add", "README"], check=True)
    subprocess.run(["git", "-C", str(empty), "commit", "-q", "-m", "first"], check=True)
    assert run(system, "sync") == 0
    assert head(system / "src" / "e") == head(empty)
    assert _recorded(system) == {"a", "e"}


@pytest.mark.parametrize("where", ["src/grp", "core"])
def test_a_file_where_a_directory_belongs_is_found_before_the_clone(
    setup, tmp_path, monkeypatch, capsys, where
):
    system, add = setup
    add("grp/c", layer="core" if where == "core" else None)
    (system / where).write_text("a person's file\n")
    _stub_vcs(tmp_path, monkeypatch, f'touch "{tmp_path}/cloned"; exit 1')
    capsys.readouterr()
    assert run(system, "sync") == 1
    out = capsys.readouterr().out
    assert f": {where} is on the way and is not a directory; not cloned" in out
    assert "cloning" not in out
    assert not (tmp_path / "cloned").exists()


def test_a_clone_put_in_place_but_not_recorded_says_so(setup, monkeypatch, capsys):
    system, add = setup
    add("d")

    def no_room(*_):
        raise OSError(errno.ENOSPC, "No space left on device", "/elsewhere/tmp-file")

    monkeypatch.setattr(sync, "put_distro_state", no_room)
    capsys.readouterr()
    assert run(system, "sync") == 1
    state_file = system / ".repos-manifest" / "state.yaml"
    assert capsys.readouterr().err == (
        f"ERROR: {system / 'src' / 'd'}: the clone is in place but was not recorded in"
        f" {state_file}: No space left on device\n"
    )
    assert (system / "src" / "d" / "README").is_file()
    assert _recorded(system) == {"a"}
