"""`sync` in part 1: it clones what is missing, touches nothing that is there, and a manifest
that does not resolve changes nothing."""

import signal

import pytest
import yaml

from helpers import branch, git, head, make_remote, repo, run, snapshot, write_manifest
from repos_manifest import sync
from repos_manifest.signals import Stopped


@pytest.fixture
def two_distros(vcs, tmp_path):
    """A system with a directory per distro, jazzy and rolling, each with repos a and b."""
    remotes = tmp_path / "remotes"
    data = {
        "format": 1,
        "distros": ["jazzy", "rolling"],
        "layers": ["core"],
        "repositories": {
            "a": repo(make_remote(remotes, "a", branches=["jazzy", "rolling"]), "jazzy", "core"),
            "b": repo(make_remote(remotes, "b"), None, "core"),
        },
    }
    data["repositories"]["a"]["distros"] = {"rolling": {"version": "rolling"}}
    path = write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    rc = run(
        system,
        "init",
        "../m.manifest.yaml",
        "--distro-dirs",
        "--distro",
        "jazzy",
        "--distro",
        "rolling",
        "--yes",
    )
    assert rc == 0
    return system, path, data


def _state(system):
    return yaml.safe_load((system / ".repos-manifest/state.yaml").read_text())["distros"]


def test_sync_after_init_changes_nothing(two_distros, capsys):
    system, _, _ = two_distros
    before = snapshot(system)
    capsys.readouterr()
    assert run(system, "sync") == 0
    assert snapshot(system) == before
    out = capsys.readouterr().out
    assert "cloning" not in out
    assert (
        out.count("present, not touched (2); updating a repo that is there is not built yet") == 2
    )


def test_a_repo_added_to_the_manifest_is_cloned_and_recorded(two_distros, tmp_path):
    system, path, data = two_distros
    before = _state(system)
    data["repositories"]["c"] = repo(make_remote(tmp_path / "remotes", "c"), None, "core")
    write_manifest(path, data)
    assert run(system, "sync") == 0
    after = _state(system)
    for distro in ("jazzy", "rolling"):
        assert (system / distro / "core/src/c/README").is_file()
        assert after[distro]["repos"]["c"]["commit"] == head(system / distro / "core/src/c")
        for key in ("a", "b"):
            assert after[distro]["repos"][key] == before[distro]["repos"][key]


@pytest.mark.parametrize("where", ["rolling", "rolling/core/src", "jazzy"])
def test_sync_from_inside_a_distro_directory_syncs_that_distro(two_distros, tmp_path, where):
    system, path, data = two_distros
    data["repositories"]["c"] = repo(make_remote(tmp_path / "remotes", "c"), None, "core")
    write_manifest(path, data)
    assert run(system / where, "sync") == 0
    distro = where.split("/")[0]
    other = "jazzy" if distro == "rolling" else "rolling"
    assert (system / distro / "core/src/c").is_dir()
    assert not (system / other / "core/src/c").exists()


def test_sync_from_a_subdirectory_at_the_top_syncs_every_distro(two_distros, tmp_path):
    system, path, data = two_distros
    data["repositories"]["c"] = repo(make_remote(tmp_path / "remotes", "c"), None, "core")
    write_manifest(path, data)
    (system / "notes").mkdir()
    assert run(system / "notes", "sync") == 0
    assert (system / "jazzy/core/src/c").is_dir() and (system / "rolling/core/src/c").is_dir()


def test_distro_names_one_and_leaves_the_other_as_it_was(two_distros, tmp_path):
    system, path, data = two_distros
    data["repositories"]["c"] = repo(make_remote(tmp_path / "remotes", "c"), None, "core")
    write_manifest(path, data)
    jazzy = snapshot(system / "jazzy")
    jazzy_resolved = snapshot(system / ".repos-manifest/resolved/jazzy")
    jazzy_state = _state(system)["jazzy"]
    assert run(system / "jazzy", "sync", "--distro", "rolling") == 0
    assert (system / "rolling/core/src/c").is_dir()
    assert snapshot(system / "jazzy") == jazzy
    assert snapshot(system / ".repos-manifest/resolved/jazzy") == jazzy_resolved
    assert _state(system)["jazzy"] == jazzy_state


def test_a_distro_the_system_does_not_record_is_an_error(two_distros, capsys):
    system, _, _ = two_distros
    before = snapshot(system)
    assert run(system, "sync", "--distro", "humble") == 1
    assert snapshot(system) == before
    assert "--distro humble: this system does not record it (it records: jazzy, rolling)" in (
        capsys.readouterr().err
    )


def test_a_distro_on_a_flat_system_without_distros_is_an_error(vcs, tmp_path, capsys):
    write_manifest(
        tmp_path / "m.yaml",
        {"format": 1, "repositories": {"a": repo(make_remote(tmp_path / "r", "a"))}},
    )
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.yaml", "--yes") == 0
    assert run(system, "sync", "--distro", "jazzy") == 1
    assert "(it records: none)" in capsys.readouterr().err


@pytest.mark.parametrize("change", ["a role it lacks", "not YAML"])
def test_a_manifest_that_does_not_resolve_changes_nothing(two_distros, capsys, change):
    system, path, data = two_distros
    if change == "a role it lacks":
        config = system / ".repos-manifest/config.yaml"
        config.write_text(config.read_text() + "role: robot\n")
    else:
        path.write_text("repositories: [\n")
    before = snapshot(system)
    assert run(system, "sync") == 1
    assert snapshot(system) == before
    assert "ERROR: the manifest is what failed; nothing was changed: " in capsys.readouterr().err


def test_a_repo_with_local_work_is_not_touched(two_distros):
    system, _, _ = two_distros
    place = system / "jazzy/core/src/a"
    git("checkout", "-q", "-b", "mine", cwd=place)
    (place / "README").write_text("changed\n")
    git("commit", "-q", "-am", "local commit", cwd=place)
    (place / "README").write_text("dirty\n")
    before = snapshot(place)
    status = git("status", "--porcelain=v2", "--branch", cwd=place)
    assert run(system, "sync") == 0
    assert snapshot(place) == before
    assert git("status", "--porcelain=v2", "--branch", cwd=place) == status
    assert branch(place) == "mine"


def test_no_system_here_says_init(vcs, tmp_path, capsys):
    assert run(tmp_path, "sync") == 1
    assert "set one up with `repos-manifest init`" in capsys.readouterr().err


def test_a_sync_stopped_in_the_second_distro_keeps_what_it_finished(
    two_distros, tmp_path, monkeypatch, capsys
):
    system, path, data = two_distros
    for key in ("c", "d"):
        data["repositories"][key] = repo(make_remote(tmp_path / "remotes", key), None, "core")
    write_manifest(path, data)
    real = sync.clone_repo
    calls = []

    def stop_at_the_second_new_repo_of_rolling(system_, src, repo_, text):
        if src[0] == "rolling" and repo_.key == "d":
            raise Stopped(signal.SIGINT)
        result = real(system_, src, repo_, text)
        calls.append((src[0], repo_.key, result.outcome))
        return result

    monkeypatch.setattr(sync, "clone_repo", stop_at_the_second_new_repo_of_rolling)
    assert run(system, "sync") == 128 + signal.SIGINT
    assert "stopped by SIGINT; run `repos-manifest sync` to finish" in capsys.readouterr().err
    state = _state(system)
    assert set(state["jazzy"]["repos"]) == {"a", "b", "c", "d"}
    assert set(state["rolling"]["repos"]) == {"a", "b", "c"}
    assert not (system / "rolling/core/src/d").exists()
    monkeypatch.setattr(sync, "clone_repo", real)
    assert run(system, "sync") == 0
    assert set(_state(system)["rolling"]["repos"]) == {"a", "b", "c", "d"}
    assert (system / "rolling/core/src/d/README").is_file()
