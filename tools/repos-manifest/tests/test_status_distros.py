"""`status` on a system with a directory per distro: which distros it covers ("Which distro a
command uses"), and a distro whose manifest no longer resolves."""

import json
import shutil

import pytest

from helpers import make_remote, repo, rewrite_manifest, run, write_manifest


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
    return system, manifest


def _status(cwd, capsys, *args):
    capsys.readouterr()
    code = run(cwd, "status", "--json", *args)
    out = capsys.readouterr()
    return code, json.loads(out.out) if out.out.strip() else None, out.err


def test_the_top_of_the_system_covers_every_distro_in_order(two, capsys):
    system, _ = two
    code, doc, _ = _status(system, capsys)
    assert code == 0
    assert doc["layout"] == "distro-dirs"
    assert doc["recorded_distros"] == ["jazzy", "rolling"]
    assert [d["distro"] for d in doc["distros"]] == ["jazzy", "rolling"]
    assert [d["repos"][0]["path"] for d in doc["distros"]] == [
        "jazzy/core/src/a",
        "rolling/core/src/a",
    ]
    assert all(d["repos"][0]["state"] == "expected" for d in doc["distros"])


def test_inside_a_distros_directory_only_that_one(two, capsys):
    system, _ = two
    code, doc, _ = _status(system / "rolling" / "core", capsys)
    assert code == 0
    assert [d["distro"] for d in doc["distros"]] == ["rolling"]
    assert doc["recorded_distros"] == ["jazzy", "rolling"]


def test_distro_names_some(two, capsys):
    system, _ = two
    _, doc, _ = _status(system, capsys, "--distro", "rolling")
    assert [d["distro"] for d in doc["distros"]] == ["rolling"]
    _, doc, _ = _status(system / "jazzy", capsys, "--distro", "rolling", "--distro", "jazzy")
    assert [d["distro"] for d in doc["distros"]] == ["rolling", "jazzy"]


def test_a_distro_the_system_does_not_record_is_an_error(two, capsys):
    system, _ = two
    code, doc, err = _status(system, capsys, "--distro", "humble")
    assert code == 1 and doc is None
    assert "--distro humble: this system does not record it (it records: jazzy, rolling)" in err


def test_a_distro_that_no_longer_resolves_is_reported_and_the_other_listed(two, capsys):
    system, manifest = two
    rewrite_manifest(manifest, lambda d: d.update(distros=["jazzy"]))
    code, doc, _ = _status(system, capsys)
    assert code == 1 and doc["ok"] is False
    jazzy, rolling = doc["distros"]
    assert jazzy["ok"] is True and jazzy["repos"][0]["state"] == "expected"
    assert rolling["ok"] is False and "repos" not in rolling
    assert "the manifest does not resolve for it" in rolling["problem"]
    capsys.readouterr()
    assert run(system, "status") == 1
    out = capsys.readouterr().out
    assert "distros set up jazzy (shown), rolling (shown)\n" in out
    assert "distro rolling:\n  ERROR: distro rolling: the manifest does not resolve" in out


def test_a_missing_repo_in_one_distro_fails_the_exit_status(two, capsys):
    system, _ = two
    shutil.rmtree(system / "rolling/core/src/a")
    code, doc, _ = _status(system, capsys)
    assert code == 1
    assert [d["repos"][0]["state"] for d in doc["distros"]] == ["expected", "missing"]
    code, _, _ = _status(system, capsys, "--distro", "jazzy")
    assert code == 0
