import subprocess
from pathlib import Path

import pytest

from ros_manifest.extends import resolve_chain
from ros_manifest.merge import merge_chain
from ros_manifest.schema import ManifestError


def _write(path: Path, text: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


def test_local_extends_chain_order(tmp_path):
    base = _write(
        tmp_path / "base.yaml",
        """
layers: [underlay]
repos:
  underlay:
    a:
      url: https://example.com/a.git
      ref: main
""",
    )
    leaf = _write(
        tmp_path / "leaf.yaml",
        f"""
extends:
  path: {base.name}
layers: [core]
repos:
  core:
    b:
      url: https://example.com/b.git
      ref: main
""",
    )
    chain = resolve_chain(leaf)
    assert [m.source for m in chain] == [str(base), str(leaf)]
    merged = merge_chain(chain)
    assert merged.layers == ["underlay", "core"]
    assert set(merged.repos) == {"a", "b"}


def test_extends_may_not_redefine_base_repo(tmp_path):
    base = _write(
        tmp_path / "base.yaml",
        """
layers: [underlay]
repos:
  underlay:
    a:
      url: https://example.com/a.git
      ref: main
""",
    )
    leaf = _write(
        tmp_path / "leaf.yaml",
        f"""
extends:
  path: {base.name}
layers: [underlay]
repos:
  underlay:
    a:
      url: https://example.com/a.git
      ref: DIFFERENT
""",
    )
    chain = resolve_chain(leaf)
    with pytest.raises(ManifestError, match="already defined"):
        merge_chain(chain)


def test_local_extends_path_escape_is_rejected(tmp_path):
    outside = _write(
        tmp_path / "outside.yaml",
        "layers: [underlay]\n"
        "repos:\n"
        "  underlay:\n"
        "    a:\n"
        "      url: https://example.com/a.git\n"
        "      ref: main\n",
    )
    nested_dir = tmp_path / "manifests" / "leaf"
    leaf = _write(
        nested_dir / "leaf.yaml",
        f"""
extends:
  path: ../../{outside.name}
layers: [core]
""",
    )
    with pytest.raises(ManifestError, match="escapes"):
        resolve_chain(leaf)


def test_local_extends_nested_path_still_works(tmp_path):
    base = _write(
        tmp_path / "config" / "manifest.yaml",
        """
layers: [underlay]
repos:
  underlay:
    a:
      url: https://example.com/a.git
      ref: main
""",
    )
    leaf = _write(
        tmp_path / "leaf.yaml",
        """
extends:
  path: config/manifest.yaml
layers: [core]
""",
    )
    chain = resolve_chain(leaf)
    assert [m.source for m in chain] == [str(base), str(leaf)]


def test_extends_cycle_is_error(tmp_path):
    a = tmp_path / "a.yaml"
    b = tmp_path / "b.yaml"
    _write(a, "extends:\n  path: b.yaml\nlayers: [x]\n")
    _write(b, "extends:\n  path: a.yaml\nlayers: [x]\n")
    with pytest.raises(ManifestError, match="cycle"):
        resolve_chain(a)


def test_group_can_be_extended_with_more_repos(tmp_path):
    base = _write(
        tmp_path / "base.yaml",
        """
layers: [core]
repos:
  core:
    a:
      url: https://example.com/a.git
      ref: main
    b:
      url: https://example.com/b.git
      ref: main
groups:
  gui:
    default: exclude
    repos: [a]
""",
    )
    leaf = _write(
        tmp_path / "leaf.yaml",
        f"""
extends:
  path: {base.name}
layers: [core]
groups:
  gui:
    default: exclude
    repos: [b]
""",
    )
    merged = merge_chain(resolve_chain(leaf))
    assert set(merged.groups["gui"].repos) == {"a", "b"}


def test_group_default_mismatch_on_extend_is_error(tmp_path):
    base = _write(
        tmp_path / "base.yaml",
        """
layers: [core]
repos:
  core:
    a:
      url: https://example.com/a.git
      ref: main
groups:
  gui:
    default: exclude
    repos: [a]
""",
    )
    leaf = _write(
        tmp_path / "leaf.yaml",
        f"""
extends:
  path: {base.name}
layers: [core]
groups:
  gui:
    default: include
    repos: []
""",
    )
    with pytest.raises(ManifestError, match="redeclares default"):
        merge_chain(resolve_chain(leaf))


def _git(cwd: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


@pytest.mark.skipif(
    subprocess.run(["git", "--version"], capture_output=True).returncode != 0,
    reason="git not available",
)
def test_git_backed_extends_local_clone_no_network(tmp_path):
    # A "remote" manifest repo that is really just a local git repo — resolve_chain only ever
    # calls `git clone`, and this exercises that path without any network access.
    remote = tmp_path / "remote_manifest_repo"
    remote.mkdir()
    _git(remote, "init", "-q")
    _git(remote, "config", "user.email", "t@example.com")
    _git(remote, "config", "user.name", "t")
    _write(
        remote / "manifest.yaml",
        """
layers: [underlay]
repos:
  underlay:
    a:
      url: https://example.com/a.git
      ref: main
""",
    )
    _git(remote, "add", "-A")
    _git(remote, "commit", "-q", "-m", "init")
    _git(remote, "branch", "-m", "main")

    leaf = _write(
        tmp_path / "leaf.yaml",
        f"""
extends:
  path: manifest.yaml
  url: {remote}
  ref: main
layers: [core]
repos:
  core:
    b:
      url: https://example.com/b.git
      ref: main
""",
    )
    cache_dir = tmp_path / "cache"
    chain = resolve_chain(leaf, cache_dir=cache_dir)
    merged = merge_chain(chain)
    assert merged.layers == ["underlay", "core"]
    assert set(merged.repos) == {"a", "b"}
    # Re-resolving reuses the cache instead of re-cloning.
    chain2 = resolve_chain(leaf, cache_dir=cache_dir)
    assert len(chain2) == 2


def test_git_backed_extends_rejects_option_like_url(tmp_path, monkeypatch):
    called = []
    monkeypatch.setattr(subprocess, "run", lambda *a, **k: called.append((a, k)))

    leaf = _write(
        tmp_path / "leaf.yaml",
        """
extends:
  path: manifest.yaml
  url: --upload-pack=evil
  ref: main
layers: [core]
""",
    )
    with pytest.raises(ManifestError, match="looks like a command-line option"):
        resolve_chain(leaf, cache_dir=tmp_path / "cache")
    assert called == []


def test_git_backed_extends_rejects_option_like_ref(tmp_path, monkeypatch):
    called = []
    monkeypatch.setattr(subprocess, "run", lambda *a, **k: called.append((a, k)))

    leaf = _write(
        tmp_path / "leaf.yaml",
        """
extends:
  path: manifest.yaml
  url: https://example.com/repo.git
  ref: -x
layers: [core]
""",
    )
    with pytest.raises(ManifestError, match="looks like a command-line option"):
        resolve_chain(leaf, cache_dir=tmp_path / "cache")
    assert called == []


@pytest.mark.skipif(
    subprocess.run(["git", "--version"], capture_output=True).returncode != 0,
    reason="git not available",
)
def test_git_backed_extends_path_escape_is_rejected(tmp_path):
    remote = tmp_path / "remote_manifest_repo"
    remote.mkdir()
    _git(remote, "init", "-q")
    _git(remote, "config", "user.email", "t@example.com")
    _git(remote, "config", "user.name", "t")
    _write(remote / "manifest.yaml", "layers: [underlay]\n")
    _git(remote, "add", "-A")
    _git(remote, "commit", "-q", "-m", "init")
    _git(remote, "branch", "-m", "main")

    leaf = _write(
        tmp_path / "leaf.yaml",
        f"""
extends:
  path: ../../outside.yaml
  url: {remote}
  ref: main
layers: [core]
""",
    )
    cache_dir = tmp_path / "cache"
    with pytest.raises(ManifestError, match="escapes"):
        resolve_chain(leaf, cache_dir=cache_dir)
