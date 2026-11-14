"""An `extends` base is untrusted content: its clone must not run the user's hooks or filter
drivers, follow an inherited GIT_DIR, reach a transport other than https, ssh or file, or wait on
a stalled remote past the time limit; a failed clone leaves nothing in the cache."""

import hashlib
import os
import stat
import subprocess
import time
from pathlib import Path

import pytest

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
