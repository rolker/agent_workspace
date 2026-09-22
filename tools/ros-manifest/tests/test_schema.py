import pytest

from ros_manifest.schema import ManifestError, parse_manifest_text


def test_minimal_valid_manifest():
    text = """
layers: [core]
repos:
  core:
    foo:
      url: https://example.com/foo.git
      ref: main
"""
    m = parse_manifest_text(text, source="t")
    assert m.layers == ["core"]
    assert m.repos["core"]["foo"].url == "https://example.com/foo.git"
    assert m.repos["core"]["foo"].type == "git"


def test_empty_layers_is_error():
    with pytest.raises(ManifestError, match="non-empty"):
        parse_manifest_text("layers: []\n", source="t")


def test_duplicate_layers_is_error():
    with pytest.raises(ManifestError, match="duplicates"):
        parse_manifest_text("layers: [a, a]\n", source="t")


def test_unknown_top_level_key_is_error():
    with pytest.raises(ManifestError, match="unknown top-level key"):
        parse_manifest_text("layers: [a]\nbogus: 1\n", source="t")


def test_repo_missing_url_is_error():
    text = """
layers: [core]
repos:
  core:
    foo:
      ref: main
"""
    with pytest.raises(ManifestError, match="missing 'url'"):
        parse_manifest_text(text, source="t")


def test_repo_missing_ref_is_error():
    text = """
layers: [core]
repos:
  core:
    foo:
      url: https://example.com/foo.git
"""
    with pytest.raises(ManifestError, match="missing 'ref'"):
        parse_manifest_text(text, source="t")


def test_repo_in_undeclared_layer_is_error():
    text = """
layers: [core]
repos:
  other:
    foo:
      url: https://example.com/foo.git
      ref: main
"""
    with pytest.raises(ManifestError, match="layer 'other'"):
        parse_manifest_text(text, source="t")


def test_distro_ref_and_absent_together_is_error():
    text = """
layers: [core]
repos:
  core:
    foo:
      url: https://example.com/foo.git
      ref: main
      distros:
        rolling:
          ref: rolling
          absent: true
"""
    with pytest.raises(ManifestError, match="cannot set both"):
        parse_manifest_text(text, source="t")


def test_distro_neither_ref_nor_absent_is_error():
    text = """
layers: [core]
repos:
  core:
    foo:
      url: https://example.com/foo.git
      ref: main
      distros:
        rolling: {}
"""
    with pytest.raises(ManifestError, match="must set 'ref' or"):
        parse_manifest_text(text, source="t")


def test_group_bad_default_is_error():
    text = """
layers: [core]
repos:
  core:
    foo:
      url: https://example.com/foo.git
      ref: main
groups:
  g:
    default: maybe
    repos: [foo]
"""
    with pytest.raises(ManifestError, match="must be 'include' or 'exclude'"):
        parse_manifest_text(text, source="t")


def test_role_roots_with_subtract_is_error():
    text = """
layers: [core]
roles:
  r:
    roots: [pkg]
    subtract: [g]
"""
    with pytest.raises(ManifestError, match="cannot be combined"):
        parse_manifest_text(text, source="t")


def test_invalid_yaml_is_error():
    with pytest.raises(ManifestError, match="invalid YAML"):
        parse_manifest_text("layers: [a\n", source="t")


def test_extends_url_without_ref_is_error():
    text = """
extends:
  path: manifest.yaml
  url: https://example.com/repo.git
layers: [core]
"""
    with pytest.raises(ManifestError, match="must also set 'ref'"):
        parse_manifest_text(text, source="t")
