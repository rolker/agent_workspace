"""A system whose manifest is a file in a git repo: `init` with `--manifest-path` and
`--manifest-ref`, what `config.yaml` records, `sync`, `status` and `show` reading it afresh,
`fetch_from` acting on the manifest's own repo, and `init`'s refusals for the two options.

Every repo is local (`file://`), or served on 127.0.0.1; the tests run as with no terminal."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

import pytest
import yaml

from helpers import git, make_remote, repo, run, snapshot, write_manifest

from repos_manifest import fetch
from repos_manifest.location import GitLocation
from repos_manifest.system import read_config


@pytest.fixture(autouse=True)
def no_terminal(vcs, monkeypatch, tmp_path):
    monkeypatch.setattr(fetch, "has_terminal", lambda: False)
    temporary = tmp_path / "tmp"
    temporary.mkdir()
    monkeypatch.setattr("tempfile.tempdir", str(temporary))
    return temporary


@pytest.fixture
def remotes(tmp_path):
    root = tmp_path / "remotes"
    for name in ("a", "b"):
        make_remote(root, name, branches=["jazzy", "rolling"])
    return root


def manifest_data(remotes: Path, *keys, distros=("jazzy", "rolling")) -> dict:
    data = {"format": 1, "distros": list(distros)}
    data["repositories"] = {key: repo(f"file://{remotes / key}", "jazzy") for key in keys}
    return data


def manifest_repo(root: Path, data: dict, path="sys/m.yaml", name="sys") -> Path:
    """A repo holding the manifest `data` at `path`, on `main`."""
    where = root / name
    where.mkdir(parents=True)
    git("init", "-q", "-b", "main", cwd=where)
    publish(where, data, path)
    return where


def publish(where: Path, data: dict, path="sys/m.yaml") -> None:
    (where / path).parent.mkdir(parents=True, exist_ok=True)
    write_manifest(where / path, data)
    git("add", "-A", cwd=where)
    git("commit", "-q", "-m", "manifest", cwd=where)


@pytest.fixture
def system(tmp_path):
    path = tmp_path / "system"
    path.mkdir()
    return path


def test_init_reads_the_manifest_from_its_repo_and_records_where_it_is(
    remotes, tmp_path, system, capsys, no_terminal
):
    holder = manifest_repo(tmp_path, manifest_data(remotes, "a"))
    url = f"file://{holder}"
    code = run(system, "init", url, "--manifest-path", "sys/m.yaml", "--distro", "jazzy", "--yes")
    out = capsys.readouterr().out
    assert code == 0, out
    assert out.startswith(f"manifest    {url}  (its default branch)  sys/m.yaml\n")
    assert git("rev-parse", "--abbrev-ref", "HEAD", cwd=system / "src" / "a") == "jazzy"
    recorded = yaml.safe_load((system / ".repos-manifest/config.yaml").read_text())
    assert recorded["manifest"] == {"url": url, "path": "sys/m.yaml"}
    assert read_config(system).manifest == GitLocation(url, None, "sys/m.yaml")
    head = (system / ".repos-manifest/resolved/_unnamed.repos").read_text().splitlines()[1]
    assert head == f"# manifest: {url}  (its default branch)  sys/m.yaml"
    assert list(no_terminal.iterdir()) == []  # the temporary clone is gone
    assert not (system / "sys").exists()  # and nothing of it was put in the system


def test_init_reads_the_branch_or_tag_given(remotes, tmp_path, system):
    holder = manifest_repo(tmp_path, manifest_data(remotes, "a"))
    git("checkout", "-q", "-b", "jazzy", cwd=holder)
    publish(holder, manifest_data(remotes, "a", "b"))
    git("checkout", "-q", "main", cwd=holder)
    url = f"file://{holder}"
    argv = ["init", url, "--manifest-ref", "jazzy", "--manifest-path", "sys/m.yaml"]
    assert run(system, *argv, "--distro", "jazzy", "--yes") == 0
    assert (system / "src" / "b").is_dir()
    recorded = yaml.safe_load((system / ".repos-manifest/config.yaml").read_text())
    assert recorded["manifest"] == {"url": url, "version": "jazzy", "path": "sys/m.yaml"}


@pytest.fixture
def refused(system, capsys):
    """`init` in `system` with `argv` is refused with `expect` in its message, and changes
    nothing."""

    def check(*argv, expect):
        (system / "unrelated.txt").write_text("a person's file\n")
        before = snapshot(system.parent)
        assert run(system, "init", *argv) == 1
        assert snapshot(system.parent) == before
        err = capsys.readouterr().err
        assert expect in err, err
        return err

    return check


def test_an_option_of_the_git_form_with_a_path_is_refused(tmp_path, refused):
    write_manifest(tmp_path / "m.yaml", {"format": 1, "repositories": {}})
    for option in ("--manifest-path", "--manifest-ref"):
        err = refused(
            "../m.yaml",
            option,
            "x",
            "--yes",
            expect=f"{option} is given, and the manifest ../m.yaml is a path on the local disk,"
            " not the git form. Give the manifest in the git form",
        )
        assert f"or leave {option} out" in err
    # An absolute path is a path too: the local git form is a file:// url.
    refused(
        str(tmp_path / "m.yaml"),
        "--manifest-path",
        "m.yaml",
        "--yes",
        expect="is a path on the local disk, not the git form",
    )


def test_manifest_ref_without_manifest_path_is_refused(refused):
    refused(
        "https://example.org/m.yaml",
        "--manifest-ref",
        "jazzy",
        "--yes",
        expect="--manifest-ref is given without --manifest-path, so https://example.org/m.yaml"
        " is not the git form",
    )


@pytest.mark.parametrize(
    "argv,expect",
    [
        (["-x", "--manifest-path", "m.yaml"], None),  # argparse's own: an option
        (["file:///srv/x.git", "--manifest-path", "-m"], None),
        (
            ["file:///srv/x.git", "--manifest-path", "../m.yaml"],
            "init: --manifest-path: '../m.yaml' has a '..' part",
        ),
        (
            ["file:///srv/x.git", "--manifest-path", "/m.yaml"],
            "init: --manifest-path: '/m.yaml' is absolute",
        ),
        (
            ["file:///srv/x.git", "--manifest-path=-m"],
            "init: --manifest-path: '-m' starts with '-'",
        ),
        (
            ["file:///srv/x.git", "--manifest-ref=-x", "--manifest-path", "m"],
            "init: --manifest-ref: '-x' starts with '-'",
        ),
        (
            ["ext::sh -c x", "--manifest-path", "m"],
            "init: the manifest's url: 'ext::sh -c x': the <transport>::<address> form",
        ),
        (
            ["ssh://-oProxyCommand=x/y", "--manifest-path", "m"],
            "the host starts with '-'",
        ),
        (
            ["git@host:x%2d.git", "--manifest-path", "m"],
            "a '%' in an ssh address is refused",
        ),
        (
            ["https:///x.git", "--manifest-path", "m"],
            "'https:///x.git': the host is empty",
        ),
        (
            ["file:///srv/x.git", "--manifest-path", "m​.yaml"],
            "init: --manifest-path: 'm\\u200b.yaml' holds a control or invisible character",
        ),
    ],
)
def test_the_git_forms_values_are_checked_before_anything_is_read(argv, expect, refused):
    if expect is None:
        with pytest.raises(SystemExit):
            refused(*argv, "--yes", expect="")
        return
    refused(*argv, "--yes", expect=expect)


def test_git_and_vcs_are_checked_before_a_manifest_in_git_is_read(
    tmp_path, system, capsys, monkeypatch
):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    os.symlink(shutil.which("git"), bin_dir / "git")
    monkeypatch.setenv("PATH", str(bin_dir))
    argv = ["init", f"file://{tmp_path}/nowhere", "--manifest-path", "m.yaml", "--yes"]
    assert run(system, *argv) == 1
    err = capsys.readouterr().err
    assert "`vcs` is not found on PATH" in err
    assert "git could not fetch" not in err


def test_a_distro_the_manifest_lacks_names_manifest_ref_as_the_next_step(
    remotes, tmp_path, refused
):
    holder = manifest_repo(tmp_path, manifest_data(remotes, "a", distros=("jazzy",)))
    refused(
        f"file://{holder}",
        "--manifest-path",
        "sys/m.yaml",
        "--distro",
        "humble",
        "--yes",
        expect="Name a distro it lists, or give with --manifest-ref a version of the manifest"
        " that lists the distro",
    )


def test_a_manifest_read_from_git_that_names_a_base_is_refused(tmp_path, refused):
    holder = manifest_repo(
        tmp_path, {"format": 1, "base": "other.yaml", "repositories": {}}, path="m.yaml"
    )
    refused(
        f"file://{holder}",
        "--manifest-path",
        "m.yaml",
        "--yes",
        expect="base: this version of the tool reads `base` in a manifest read from a file on"
        " the local disk, not yet in one read from a git repo",
    )


def test_a_manifest_at_a_commit_is_refused_with_a_branch_or_tag_meant(tmp_path, refused):
    holder = manifest_repo(tmp_path, {"format": 1, "repositories": {}}, path="m.yaml")
    commit = git("rev-parse", "HEAD", cwd=holder)
    refused(
        f"file://{holder}",
        "--manifest-ref",
        commit,
        "--manifest-path",
        "m.yaml",
        "--yes",
        expect=f"the repo has no branch or tag {commit}: a branch or tag is meant",
    )
