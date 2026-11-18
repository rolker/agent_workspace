"""From a manifest, a role, a distro and extra groups to the repos of each layer."""

import textwrap

import pytest

from repos_manifest.manifest import parse_manifest
from repos_manifest.selection import resolve
from repos_manifest.yamlload import ManifestError

TOP = """\
distros: [jazzy, rolling]
layers: [core, ui]
groups: [sim, ui, hw]
roles:
  robot: []
  dev: [sim, ui]
"""


def _repo(key, extra=""):
    return f"  {key}:\n    type: git\n    url: https://example.org/{key}.git\n{extra}"


def _manifest(*repos, top=TOP):
    return parse_manifest(top + "repositories:\n" + "".join(repos), "m.yaml")


def _keys(resolved):
    return {layer.name: [r.key for r in layer.repos] for layer in resolved.layers}


def _version(resolved, key):
    return {r.key: r.version for layer in resolved.layers for r in layer.repos}.get(key, "gone")


# --- Versions and distros --------------------------------------------------------------------


def test_the_default_version_is_used_without_a_distro_entry():
    m = _manifest(_repo("a", "    version: main\n"))
    assert _version(resolve(m, "robot", "jazzy"), "a") == "main"


def test_a_distro_entry_version_replaces_the_default():
    extra = "    version: jazzy\n    distros:\n      rolling:\n        version: rolling\n"
    m = _manifest(_repo("a", extra))
    assert _version(resolve(m, "robot", "jazzy"), "a") == "jazzy"
    assert _version(resolve(m, "robot", "rolling"), "a") == "rolling"


def test_a_repo_with_no_version_has_none():
    assert _version(resolve(_manifest(_repo("a")), "robot", "jazzy"), "a") is None


def test_a_distro_entry_absent_true_leaves_the_repo_out_on_that_distro():
    m = _manifest(_repo("a", "    distros:\n      rolling:\n        absent: true\n"))
    assert _version(resolve(m, "robot", "jazzy"), "a") is None
    assert _version(resolve(m, "robot", "rolling"), "a") == "gone"


def test_absent_true_on_the_repo_with_a_distro_entry():
    m = _manifest(_repo("a", "    absent: true\n    distros:\n      jazzy:\n        version: x\n"))
    assert _version(resolve(m, "robot", "jazzy"), "a") == "x"
    assert _version(resolve(m, "robot", "rolling"), "a") == "gone"


def test_absent_true_on_the_repo_with_an_empty_distro_entry():
    m = _manifest(_repo("a", "    version: v\n    absent: true\n    distros:\n      jazzy:\n"))
    assert _version(resolve(m, "robot", "jazzy"), "a") == "v"
    assert _version(resolve(m, "robot", "rolling"), "a") == "gone"


def test_absent_true_on_the_repo_with_no_distro_entry():
    m = _manifest(_repo("a", "    absent: true\n"))
    assert _version(resolve(m, "robot", "jazzy"), "a") == "gone"
    assert _version(resolve(m, "robot", "rolling"), "a") == "gone"


def test_absent_true_on_the_repo_with_an_entry_that_says_absent_true():
    m = _manifest(
        _repo("a", "    absent: true\n    distros:\n      jazzy:\n        absent: true\n")
    )
    assert _version(resolve(m, "robot", "jazzy"), "a") == "gone"


def test_absent_false_on_a_distro_entry_keeps_the_repo():
    m = _manifest(
        _repo("a", "    absent: true\n    distros:\n      jazzy:\n        absent: false\n")
    )
    assert _version(resolve(m, "robot", "jazzy"), "a") is None


def test_a_distro_entry_for_a_distro_outside_the_list_is_ignored():
    m = _manifest(_repo("a", "    version: v\n    distros:\n      humble:\n        absent: true\n"))
    assert _version(resolve(m, "robot", "jazzy"), "a") == "v"
    with pytest.raises(ManifestError, match="does not cover distro 'humble'"):
        resolve(m, "robot", "humble")


def test_resolving_for_a_distro_outside_the_list_is_an_error():
    with pytest.raises(ManifestError, match="does not cover distro 'humble'; its distros are"):
        resolve(_manifest(_repo("a")), "robot", "humble")


def test_a_distro_is_required_when_the_manifest_has_distros():
    with pytest.raises(ManifestError, match="has distros; give one of"):
        resolve(_manifest(_repo("a")), "robot", None)


def test_no_distro_is_given_to_a_manifest_without_distros():
    m = _manifest(_repo("a"), top="")
    assert _keys(resolve(m)) == {"_unnamed": ["a"]}
    with pytest.raises(ManifestError, match="has no `distros:`, so no distro is given"):
        resolve(m, None, "jazzy")


# --- Groups and roles ------------------------------------------------------------------------


def test_a_repo_in_no_group_is_always_selected_and_a_grouped_one_only_when_on():
    m = _manifest(_repo("plain"), _repo("sim", "    groups: [sim]\n"))
    assert _keys(resolve(m, "robot", "jazzy")) == {"_unnamed": ["plain"]}
    assert _keys(resolve(m, "dev", "jazzy")) == {"_unnamed": ["plain", "sim"]}


def test_a_repo_in_two_groups_is_selected_when_either_is_on():
    m = _manifest(_repo("a", "    groups: [hw, ui]\n"))
    assert _keys(resolve(m, "dev", "jazzy")) == {"_unnamed": ["a"]}
    assert _keys(resolve(m, "robot", "jazzy")) == {}


def test_extra_groups_are_switched_on_with_the_role():
    m = _manifest(_repo("a", "    groups: [hw]\n"))
    assert _keys(resolve(m, "robot", "jazzy", ["hw"])) == {"_unnamed": ["a"]}


def test_an_extra_group_not_in_groups_is_an_error():
    with pytest.raises(ManifestError, match="extra group 'gpu' is not in the top-level"):
        resolve(_manifest(_repo("a")), "robot", "jazzy", ["gpu"])


def test_a_role_is_required_when_the_manifest_has_roles():
    with pytest.raises(ManifestError, match="has roles; give one of"):
        resolve(_manifest(_repo("a")), None, "jazzy")


def test_an_unknown_role_is_an_error():
    with pytest.raises(ManifestError, match="has no role 'pilot'"):
        resolve(_manifest(_repo("a")), "pilot", "jazzy")


def test_no_role_is_given_to_a_manifest_without_roles():
    m = _manifest(_repo("a"), top="distros: [jazzy]\n")
    assert _keys(resolve(m, None, "jazzy")) == {"_unnamed": ["a"]}
    with pytest.raises(ManifestError, match="has no `roles:`, so no role is given"):
        resolve(m, "robot", "jazzy")


# --- Layers ----------------------------------------------------------------------------------


def test_layers_come_in_order_with_the_unnamed_layer_first_and_empty_ones_left_out():
    m = _manifest(
        _repo("u", "    layer: ui\n"),
        _repo("c", "    layer: core\n"),
        _repo("x"),
        _repo("s", "    layer: ui\n    groups: [sim]\n"),
    )
    assert _keys(resolve(m, "dev", "jazzy")) == {"_unnamed": ["x"], "core": ["c"], "ui": ["u", "s"]}
    m2 = _manifest(
        _repo("c", "    layer: core\n"), _repo("s", "    layer: ui\n    groups: [sim]\n")
    )
    assert [layer.name for layer in resolve(m2, "robot", "jazzy").layers] == ["core"]


def test_the_optional_repos_are_the_selected_ones_in_layer_then_manifest_order():
    m = _manifest(
        _repo("u", "    layer: ui\n    optional: true\n"),
        _repo("c2", "    layer: core\n    optional: true\n"),
        _repo("c1", "    layer: core\n"),
        _repo("x", "    optional: true\n    groups: [sim]\n"),
    )
    assert resolve(m, "robot", "jazzy").optional == ["c2", "u"]
    assert resolve(m, "dev", "jazzy").optional == ["x", "c2", "u"]


def test_a_plain_repos_file_resolves_to_itself_in_one_layer():
    text = textwrap.dedent(
        """\
        repositories:
          a:
            type: git
            url: https://example.org/a.git
            version: main
          b/c:
            type: git
            url: https://example.org/c.git
        """
    )
    resolved = resolve(parse_manifest(text, "plain.repos"))
    assert _keys(resolved) == {"_unnamed": ["a", "b/c"]}
    assert [r.version for r in resolved.layers[0].repos] == ["main", None]
