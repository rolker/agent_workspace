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


def test_optional_layers_union_across_extends_in_chain_order(tmp_path):
    base = _write(
        tmp_path / "base.yaml",
        """
layers: [underlay, sim, site]
optional_layers: [site, sim]
""",
    )
    leaf = _write(
        tmp_path / "leaf.yaml",
        f"""
extends:
  path: {base.name}
layers: [site, extra]
optional_layers: [extra, site]
""",
    )
    merged = merge_chain(resolve_chain(leaf))
    # The leaf may only mark layers in its own list; it re-lists the base's 'site'.
    # Base first (its own order), then the leaf's new names; 'site' is not repeated.
    assert merged.optional_layers == ["site", "sim", "extra"]


def test_optional_layer_outside_composed_layers_is_error_at_merge():
    # parse_manifest_text already refuses this per file; merge_chain re-checks against the
    # composed list, so a Manifest built any other way cannot slip an unknown layer through.
    from ros_manifest.schema import Manifest

    bad = Manifest(
        source="handmade",
        extends=None,
        layers=["core"],
        optional_layers=["ghost"],
        repos={"core": {}},
        groups={},
        roles={},
        packages={},
    )
    with pytest.raises(ManifestError, match="optional layer 'ghost'"):
        merge_chain([bad])


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
  url: {remote.as_uri()}
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
    with pytest.raises(ManifestError, match="extends.url is not one of the accepted URL shapes"):
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
    with pytest.raises(ManifestError, match="extends.ref is not an accepted ref"):
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
  url: {remote.as_uri()}
  ref: main
layers: [core]
""",
    )
    cache_dir = tmp_path / "cache"
    with pytest.raises(ManifestError, match="escapes"):
        resolve_chain(leaf, cache_dir=cache_dir)


def _manifest_repo(path: Path, files: dict) -> str:
    """A local git repository holding `files` on branch main; returns its HEAD commit."""
    path.mkdir()
    _git(path, "init", "-q")
    _git(path, "config", "user.email", "t@example.com")
    _git(path, "config", "user.name", "t")
    for rel, text in files.items():
        _write(path / rel, text)
    _git(path, "add", "-A")
    _git(path, "commit", "-q", "-m", "init")
    _git(path, "branch", "-m", "main")
    return _head(path)


def _head(path: Path) -> str:
    return subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=path, check=True, capture_output=True, text=True
    ).stdout.strip()


_BASE_TEXT = """
layers: [underlay]
repos:
  underlay:
    a:
      url: https://example.com/a.git
      ref: main
"""


@pytest.mark.skipif(
    subprocess.run(["git", "--version"], capture_output=True).returncode != 0,
    reason="git not available",
)
def test_git_backed_extends_provenance_is_url_ref_path_commit(tmp_path):
    # Issue 267 decision 5: generated files say which manifest contributed each repository.
    # A base read from a clone is labelled by where it came from, never by the cache path,
    # which may be a temporary directory that is gone after the resolve.
    from ros_manifest.emit import emit_layer
    from ros_manifest.selectors import select_repos

    remote = tmp_path / "base_repo"
    commit = _manifest_repo(remote, {"config/manifest.yaml": _BASE_TEXT})
    url = remote.as_uri()  # file://...
    leaf = _write(
        tmp_path / "leaf.yaml",
        f"""
extends:
  path: config/manifest.yaml
  url: {url}
  ref: main
layers: [core]
repos:
  core:
    b:
      url: https://example.com/b.git
      ref: main
roles:
  dev: {{}}
""",
    )
    cache_one = tmp_path / "tmp-one.cache"
    chain = resolve_chain(leaf, cache_dir=cache_one)
    label = f"{url}#main:config/manifest.yaml@{commit}"
    assert [m.source for m in chain] == [label, str(leaf)]

    merged = merge_chain(chain)
    assert merged.repos["a"].source == label
    text = emit_layer(merged, "underlay", select_repos(merged, "dev"), role="dev", distro="jazzy")
    assert f"#   a: {label}\n" in text
    assert str(cache_one) not in text

    # A second resolve through a different (fresh) cache writes the same header.
    chain_two = resolve_chain(leaf, cache_dir=tmp_path / "tmp-two.cache")
    assert [m.source for m in chain_two] == [label, str(leaf)]

    # A new commit on the base, resolved through a fresh cache, is named in the label.
    _write(remote / "config" / "manifest.yaml", _BASE_TEXT + "optional_layers: [underlay]\n")
    _git(remote, "commit", "-q", "-am", "second")
    new_commit = _head(remote)
    assert new_commit != commit
    chain_three = resolve_chain(leaf, cache_dir=tmp_path / "tmp-three.cache")
    assert chain_three[0].source == f"{url}#main:config/manifest.yaml@{new_commit}"


@pytest.mark.skipif(
    subprocess.run(["git", "--version"], capture_output=True).returncode != 0,
    reason="git not available",
)
def test_local_extends_inside_a_clone_keeps_the_git_label(tmp_path):
    # A base in the clone extends a sibling file by local path: that file is labelled from the
    # same clone (url, ref, its own path, the same commit), not by the cache path.
    remote = tmp_path / "base_repo"
    commit = _manifest_repo(
        remote,
        {
            "distro/common.yaml": _BASE_TEXT,
            "distro/manifest.yaml": "extends:\n  path: common.yaml\nlayers: [mid]\n",
        },
    )
    url = remote.as_uri()
    leaf = _write(
        tmp_path / "leaf.yaml",
        f"""
extends:
  path: distro/manifest.yaml
  url: {url}
  ref: main
layers: [core]
""",
    )
    chain = resolve_chain(leaf, cache_dir=tmp_path / "cache")
    assert [m.source for m in chain] == [
        f"{url}#main:distro/common.yaml@{commit}",
        f"{url}#main:distro/manifest.yaml@{commit}",
        str(leaf),
    ]


@pytest.mark.skipif(
    subprocess.run(["git", "--version"], capture_output=True).returncode != 0,
    reason="git not available",
)
def test_label_with_a_slash_in_the_ref_is_unambiguous(tmp_path):
    # `url#ref:path@commit`: a git ref cannot hold `:`, so `release/2` and the path stay apart.
    remote = tmp_path / "base_repo"
    commit = _manifest_repo(remote, {"config/manifest.yaml": _BASE_TEXT})
    _git(remote, "branch", "release/2")
    url = remote.as_uri()
    leaf = _write(
        tmp_path / "leaf.yaml",
        f"extends:\n  path: config/manifest.yaml\n  url: {url}\n  ref: release/2\nlayers: [core]\n",
    )
    chain = resolve_chain(leaf, cache_dir=tmp_path / "cache")
    label = chain[0].source
    assert label == f"{url}#release/2:config/manifest.yaml@{commit}"
    ref, _, rest = label.partition("#")[2].partition(":")
    assert (ref, rest.rpartition("@")[0]) == ("release/2", "config/manifest.yaml")


def test_clone_states_the_transport_policy(tmp_path, monkeypatch):
    # The transports the clone may use are on the command line, not left to git's defaults:
    # everything refused, then https, ssh and file allowed; `--` before the url.
    from ros_manifest import extends

    calls = []

    def fake_run(argv, **kwargs):
        calls.append(argv)
        return subprocess.CompletedProcess(argv, 1, "", "stop here")

    monkeypatch.setattr(subprocess, "run", fake_run)
    with pytest.raises(ManifestError, match="failed to clone"):
        extends._clone_or_reuse("https://example.com/a.git", "main", tmp_path / "cache")
    argv = calls[0]
    clone = argv.index("clone")
    policy = argv[1:clone]
    assert policy[:2] == ["-c", "protocol.allow=never"]
    assert {policy[i] for i in range(3, len(policy), 2)} == {
        "protocol.https.allow=always",
        "protocol.ssh.allow=always",
        "protocol.file.allow=always",
    }
    assert argv[-3:-1] == ["--", "https://example.com/a.git"]


def test_a_failed_clone_reports_git_s_status_not_its_output(tmp_path, monkeypatch):
    # Round 4: git's stderr was decoded as text (a UnicodeDecodeError traceback when the remote's
    # file names are not UTF-8) and, when it decoded, quoted in the message.
    from ros_manifest import extends

    def fake_run(argv, **kwargs):
        assert "text" not in kwargs
        return subprocess.CompletedProcess(argv, 128, b"", b"\xff" * 300 + b" remote-file-name")

    monkeypatch.setattr(subprocess, "run", fake_run)
    with pytest.raises(ManifestError) as info:
        extends._clone_or_reuse("https://example.com/a.git", "main", tmp_path / "cache", "leaf")
    assert str(info.value) == (
        "leaf: failed to clone its extends base (git exited with status 128)"
    )


def _git_based_leaf(tmp_path):
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text(
        "extends:\n  path: manifest.yaml\n  url: file:///nonexistent/b.git\n  ref: main\n"
        "layers: [core]\nroles:\n  dev: {}\n"
    )
    return leaf


def test_missing_git_has_its_own_message(tmp_path, monkeypatch, capsys):
    # Round 4: it read "its extends cannot be followed (No such file or directory)".
    from ros_manifest.cli import main

    monkeypatch.setenv("PATH", str(tmp_path / "empty"))
    leaf = _git_based_leaf(tmp_path)
    argv = ["validate", "--manifest", str(leaf), "--role", "dev", "--distro", "jazzy"]
    assert main(argv + ["--cache-dir", str(tmp_path / "cache")]) == 1
    assert capsys.readouterr().err == (
        "ERROR: git is not installed or not on PATH; it is needed to clone an extends base\n"
    )


def test_an_uncreatable_cache_dir_has_its_own_message(tmp_path, capsys):
    from ros_manifest.cli import main

    (tmp_path / "a-file").write_text("")
    cache = tmp_path / "a-file" / "cache"
    leaf = _git_based_leaf(tmp_path)
    argv = ["validate", "--manifest", str(leaf), "--role", "dev", "--distro", "jazzy"]
    assert main(argv + ["--cache-dir", str(cache)]) == 1
    assert capsys.readouterr().err == (
        f"ERROR: the extends cache directory {cache} (--cache-dir) cannot be created"
        " (Not a directory)\n"
    )
