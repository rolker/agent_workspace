"""Reading a manifest from a git repo (``fetch.py``): which file of which version is read, what
is refused, the time limit with no terminal, the transports allowed, and the temporary clone.

Every repo is local: a `file://` url, a stub ssh that runs `git-upload-pack` on a local repo,
or a server on 127.0.0.1. The tests run as with no terminal (`fetch.has_terminal` is False), so
nothing waits for a person, whoever runs them."""

from __future__ import annotations

import os
import time
from pathlib import Path

import pytest

from githttp import GitServer, SilentServer, processes_naming
from helpers import git

from repos_manifest import fetch
from repos_manifest.fetch import allowed_protocols, read_git_file
from repos_manifest.location import GitLocation
from repos_manifest.system import read_manifest
from repos_manifest.yamlload import ManifestError

MANIFEST = "format: 1\nrepositories:\n  a:\n    type: git\n    url: https://example.org/a.git\n"


@pytest.fixture(autouse=True)
def no_terminal(vcs, monkeypatch, tmp_path):
    """No terminal, and the temporary clones in a directory of the test's own."""
    monkeypatch.setattr(fetch, "has_terminal", lambda: False)
    temporary = tmp_path / "tmp"
    temporary.mkdir()
    monkeypatch.setattr("tempfile.tempdir", str(temporary))
    return temporary


def make_repo(root: Path, files, name="sys") -> Path:
    """A repo at `root/name` with `files` (name -> text, or bytes) committed on `main`."""
    path = root / name
    path.mkdir(parents=True)
    git("init", "-q", "-b", "main", cwd=path)
    commit(path, files)
    return path


def commit(path: Path, files, message="change") -> None:
    for name, text in files.items():
        target = path / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(text, bytes):
            target.write_bytes(text)
        else:
            target.write_text(text, encoding="utf-8", newline="")
    git("add", "-A", cwd=path)
    git("commit", "-q", "-m", message, cwd=path)


def at(repo: Path, path="m.yaml", version=None) -> GitLocation:
    return GitLocation(f"file://{repo}", version, path)


def test_reads_the_file_on_the_default_branch(tmp_path):
    repo = make_repo(tmp_path, {"m.yaml": MANIFEST})
    assert read_git_file(at(repo)) == MANIFEST


def test_reads_a_branch_and_a_tag(tmp_path):
    repo = make_repo(tmp_path, {"m.yaml": "on main\n"})
    git("tag", "v1", cwd=repo)
    git("checkout", "-q", "-b", "jazzy", cwd=repo)
    commit(repo, {"m.yaml": "on jazzy\n"})
    git("checkout", "-q", "main", cwd=repo)
    commit(repo, {"m.yaml": "main moved on\n"})
    assert read_git_file(at(repo, version="jazzy")) == "on jazzy\n"
    assert read_git_file(at(repo, version="v1")) == "on main\n"
    assert read_git_file(at(repo, version="heads/jazzy")) == "on jazzy\n"
    assert read_git_file(at(repo, version="tags/v1")) == "on main\n"
    assert read_git_file(at(repo)) == "main moved on\n"


def test_heads_and_tags_name_the_kind_they_say(tmp_path):
    repo = make_repo(tmp_path, {"m.yaml": "x\n"})
    git("tag", "v1", cwd=repo)
    git("branch", "rel", cwd=repo)
    with pytest.raises(ManifestError, match="heads/v1 names a branch, and v1 in the repo is a tag"):
        read_git_file(at(repo, version="heads/v1"))
    with pytest.raises(ManifestError, match="tags/rel names a tag, and rel in the repo is a"):
        read_git_file(at(repo, version="tags/rel"))


def test_reads_a_file_in_a_subdirectory_and_a_file_that_is_executable(tmp_path):
    repo = make_repo(tmp_path, {"sys/m.yaml": "deep\n", "run.yaml": "exec\n"})
    os.chmod(repo / "run.yaml", 0o755)
    commit(repo, {})  # the new mode
    assert read_git_file(at(repo, "sys/m.yaml")) == "deep\n"
    assert read_git_file(at(repo, "run.yaml")) == "exec\n"


@pytest.mark.parametrize(
    "path,why",
    [
        ("missing.yaml", "there is no file missing.yaml in the repo at that version"),
        ("./m.yaml", "there is no file ./m.yaml in the repo"),
        ("d/", "there is no file d/ in the repo"),
        ("d//x.yaml", "there is no file d//x.yaml in the repo"),
        ("link/x.yaml", "there is no file link/x.yaml in the repo"),
        ("*.yaml", "there is no file *.yaml in the repo"),
        ("d", "d is a directory in the repo, not a file"),
        ("m-link.yaml", "m-link.yaml is a link in the repo, not a file"),
    ],
)
def test_only_a_file_of_exactly_that_path_is_read(tmp_path, path, why):
    repo = make_repo(tmp_path, {"m.yaml": "x\n", "d/x.yaml": "y\n"})
    os.symlink("d", repo / "link")
    os.symlink("m.yaml", repo / "m-link.yaml")
    commit(repo, {})
    with pytest.raises(ManifestError) as raised:
        read_git_file(at(repo, path))
    assert why in str(raised.value)


def test_a_submodule_is_refused(tmp_path):
    repo = make_repo(tmp_path, {"m.yaml": "x\n"})
    commit_id = git("rev-parse", "HEAD", cwd=repo)
    git("update-index", "--add", "--cacheinfo", f"160000,{commit_id},sub", cwd=repo)
    git("commit", "-q", "-m", "a submodule", cwd=repo)
    with pytest.raises(ManifestError, match="sub is a submodule in the repo, not a file"):
        read_git_file(at(repo, "sub"))


def test_a_file_over_the_size_limit_is_refused_and_one_at_it_is_read(tmp_path):
    at_limit = "#" * (fetch.SIZE_LIMIT - 1) + "\n"
    repo = make_repo(tmp_path, {"big.yaml": at_limit + "x", "ok.yaml": at_limit})
    with pytest.raises(ManifestError, match=r"is 1048577 bytes; a manifest is read up to 1048576"):
        read_git_file(at(repo, "big.yaml"))
    assert len(read_git_file(at(repo, "ok.yaml"))) == fetch.SIZE_LIMIT


def test_a_commit_is_not_a_version_and_the_message_says_a_branch_or_tag_is_meant(tmp_path):
    repo = make_repo(tmp_path, {"m.yaml": "x\n"})
    commit_id = git("rev-parse", "HEAD", cwd=repo)
    with pytest.raises(ManifestError) as raised:
        read_git_file(at(repo, version=commit_id))
    said = str(raised.value)
    assert f"the repo has no branch or tag {commit_id}: a branch or tag is meant" in said
    assert "Remote branch" in said  # git's own words


def test_an_unreachable_repo_is_not_told_a_branch_or_tag_is_meant(tmp_path):
    with pytest.raises(ManifestError) as raised:
        read_git_file(at(tmp_path / "nowhere", version="jazzy"))
    said = str(raised.value)
    assert "git could not fetch the repo (exit status 128)" in said
    assert "a branch or tag is meant" not in said


def test_a_file_that_is_not_utf8_is_refused(tmp_path):
    repo = make_repo(tmp_path, {"m.yaml": b"\xff\xfe"})
    with pytest.raises(ManifestError, match="m.yaml: cannot be read as UTF-8 text"):
        read_git_file(at(repo))


@pytest.mark.parametrize(
    "text,why",
    [
        (MANIFEST + "# a\u200bb\n", "line 6, column 4: the file holds U+200B"),
        (MANIFEST + "# a\rb\n", "the file holds U+000D"),
        ("format: 1\nrepos: {}\n", "is in the earlier format"),
        ("format: 1\nrepositories:\n  ../a: {type: git, url: /x}\n", "has no '..' part"),
        (
            "format: 1\nrepositories:\n  a: {type: git, url: 'ext::sh -c x'}\n",
            "the <transport>::<address> form is refused",
        ),
        (
            "base: other.yaml\n" + MANIFEST,
            "base: this version of the tool reads `base` in a manifest read from a file on the"
            " local disk, not yet in one read from a git repo",
        ),
    ],
)
def test_the_checks_of_every_manifest_apply_to_one_read_from_git(tmp_path, text, why):
    repo = make_repo(tmp_path, {"m.yaml": text})
    with pytest.raises(ManifestError) as raised:
        read_manifest(at(repo), tmp_path)
    said = str(raised.value)
    assert said.startswith(f"file://{repo}  (its default branch)  m.yaml: "), said
    assert why in said, said


def test_a_manifest_read_from_git_is_named_by_its_location(tmp_path):
    repo = make_repo(tmp_path, {"m.yaml": MANIFEST})
    loaded = read_manifest(at(repo, version="main"), tmp_path)
    assert loaded.source == f"file://{repo}  main  m.yaml"
    assert list(loaded.repositories) == ["a"]


def test_the_temporary_clone_is_removed_after_a_read_and_after_a_failure(tmp_path, no_terminal):
    repo = make_repo(tmp_path, {"m.yaml": MANIFEST})
    read_git_file(at(repo))
    assert list(no_terminal.iterdir()) == []
    with pytest.raises(ManifestError):
        read_git_file(at(repo, "missing.yaml"))
    with pytest.raises(ManifestError):
        read_git_file(at(tmp_path / "nowhere"))
    assert list(no_terminal.iterdir()) == []


@pytest.mark.parametrize(
    "url,allowed",
    [
        ("https://example.org/x.git", "https"),
        ("http://example.org/x.git", "http:https"),
        ("ssh://git@example.org/x.git", "ssh"),
        ("git@example.org:team/x.git", "ssh"),
        ("example:x.git", "ssh"),
        ("file:///srv/x.git", "file"),
        ("/srv/x.git", "file"),
    ],
)
def test_only_the_urls_own_transport_is_allowed(url, allowed):
    assert allowed_protocols(url) == allowed


def test_an_absolute_path_is_read_as_a_local_repo(tmp_path):
    repo = make_repo(tmp_path, {"m.yaml": MANIFEST})
    assert read_git_file(GitLocation(str(repo), None, "m.yaml")) == MANIFEST


@pytest.fixture
def served(tmp_path):
    root = tmp_path / "served"
    root.mkdir()
    server = GitServer(root)
    yield server
    server.close()


def test_reads_over_http_and_follows_a_redirect_within_http(tmp_path, served):
    make_repo(served.root, {"m.yaml": MANIFEST}, name="sys.git")
    assert read_git_file(GitLocation(f"{served.url}/sys.git", None, "m.yaml")) == MANIFEST
    served.redirects["/old.git"] = f"{served.url}/sys.git"
    assert read_git_file(GitLocation(f"{served.url}/old.git", None, "m.yaml")) == MANIFEST
    assert any(path.startswith("/old.git/") for path in served.requests)


def test_a_redirect_to_another_transport_is_refused(tmp_path, served):
    repo = make_repo(tmp_path, {"m.yaml": MANIFEST})
    served.redirects["/old.git"] = f"file://{repo}"
    with pytest.raises(ManifestError, match="git could not fetch the repo"):
        read_git_file(GitLocation(f"{served.url}/old.git", None, "m.yaml"))


def test_with_no_terminal_a_password_is_not_asked_for_and_the_read_fails_at_once(served):
    served.unauthorised = True
    started = time.monotonic()
    with pytest.raises(ManifestError) as raised:
        read_git_file(GitLocation(f"{served.url}/sys.git", None, "m.yaml"))
    assert time.monotonic() - started < 30
    assert "terminal prompts disabled" in str(raised.value)


def test_a_credential_in_the_url_is_masked_in_the_message_and_git_text(served):
    served.unauthorised = True
    url = f"http://someone:s3cret@127.0.0.1:{served.server_address[1]}/sys.git"
    with pytest.raises(ManifestError) as raised:
        read_git_file(GitLocation(url, None, "m.yaml"))
    said = str(raised.value)
    assert "s3cret" not in said and "someone" not in said
    assert "http://***@127.0.0.1" in said


@pytest.fixture
def silent():
    server = SilentServer()
    yield server
    server.close()


def test_with_no_terminal_a_server_that_hangs_is_given_up_on_at_the_limit(
    silent, monkeypatch, no_terminal
):
    monkeypatch.setattr(fetch, "TIME_LIMIT", 2)
    url = f"{silent.url}/sys.git"
    started = time.monotonic()
    with pytest.raises(ManifestError, match="git did not finish within 2 seconds and was stopped"):
        read_git_file(GitLocation(url, None, "m.yaml"))
    assert time.monotonic() - started < 20
    # git and the helper it started for http (git-remote-http) were ended, the whole group.
    assert processes_naming(url) == []
    assert list(no_terminal.iterdir()) == []


def test_a_private_repo_over_ssh_is_read_with_the_persons_ssh(tmp_path, monkeypatch):
    """git's ssh is the person's (`GIT_SSH_COMMAND`, as `~/.ssh/config` or an agent would be):
    a stub that records how it was called and runs `git-upload-pack` on a local repo."""
    repo = make_repo(tmp_path, {"m.yaml": MANIFEST})
    log = tmp_path / "ssh.log"
    stub = tmp_path / "ssh-stub"
    stub.write_text(
        "#!/bin/sh\n" f'echo "$@" >> "{log}"\n' 'for last; do :; done\nexec sh -c "$last"\n'
    )
    stub.chmod(0o755)
    monkeypatch.setenv("GIT_SSH_COMMAND", str(stub))
    monkeypatch.setenv("GIT_SSH_VARIANT", "simple")
    location = GitLocation(f"git@private.example.invalid:{repo}", "main", "m.yaml")
    assert read_git_file(location) == MANIFEST
    called = log.read_text()
    assert "git@private.example.invalid" in called and "git-upload-pack" in called
