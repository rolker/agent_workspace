"""What `init` and `sync` rely on `vcs import` for, run on the `vcs` found on PATH (the report
header names it): a one-repo text on stdin, cloned into a directory given as the argument, with
success told by the exit status alone."""

import subprocess

from helpers import branch, git, make_remote


def _import(directory, key, url, version=None):
    lines = ["repositories:", f"  {key}:", "    type: git", f"    url: {url}"]
    if version is not None:
        lines.append(f"    version: {version}")
    return subprocess.run(
        ["vcs", "import", str(directory)],
        input="\n".join(lines) + "\n",
        capture_output=True,
        text=True,
        check=False,
    ).returncode


def test_vcs_version_exits_0(vcs):
    assert subprocess.run([vcs, "--version"], capture_output=True, check=False).returncode == 0


def test_a_repo_is_cloned_at_the_key_on_its_branch(vcs, tmp_path):
    remote = make_remote(tmp_path / "remotes", "a", branches=["dev"])
    target = tmp_path / "t"
    target.mkdir()
    assert _import(target, "a", remote, "dev") == 0
    assert branch(target / "a") == "dev"
    assert git("remote", "get-url", "origin", cwd=target / "a") == str(remote)


def test_a_repo_at_a_tag_is_detached_at_it(vcs, tmp_path):
    remote = make_remote(tmp_path / "remotes", "a", tags=["v1"])
    target = tmp_path / "t"
    target.mkdir()
    assert _import(target, "a", remote, "v1") == 0
    assert git("rev-parse", "HEAD", cwd=target / "a") == git("rev-parse", "v1", cwd=remote)


def test_a_nested_key_lands_below_its_directories(vcs, tmp_path):
    remote = make_remote(tmp_path / "remotes", "c")
    target = tmp_path / "t"
    target.mkdir()
    assert _import(target, "grp/sub/c", remote) == 0
    assert (target / "grp" / "sub" / "c" / "README").is_file()


def test_a_url_that_is_not_a_repository_exits_non_zero(vcs, tmp_path):
    target = tmp_path / "t"
    target.mkdir()
    assert _import(target, "a", tmp_path / "missing") != 0


def test_a_version_that_does_not_exist_exits_non_zero(vcs, tmp_path):
    # vcstool 0.3.0 leaves a clone on the default branch then; the exit status says it failed.
    remote = make_remote(tmp_path / "remotes", "a")
    target = tmp_path / "t"
    target.mkdir()
    assert _import(target, "a", remote, "no-such-branch") != 0
