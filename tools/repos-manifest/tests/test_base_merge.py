"""How manifests combine through `base` (docs/spec.md, "How manifests combine"): one test per
rule, and the checks made on the combination, each naming the manifest that gave the value."""

import os
import re
import textwrap

import pytest

from repos_manifest.base import load_manifest
from repos_manifest.manifest import DistroEntry
from repos_manifest.selection import resolve
from repos_manifest.yamlload import ManifestError

PUBLISHED = """\
distros: [jazzy, rolling]
layers: [core, ui]
groups: [sim]
roles:
  robot: []
  dev: [sim]
repositories:
  nav:
    type: git
    url: https://example.org/nav.git
    version: jazzy
    layer: core
    groups: [sim]
    distros:
      rolling:
        version: rolling
      humble:
        absent: true
  site:
    type: git
    url: https://example.org/site.git
    optional: true
    absent: true
    distros:
      jazzy: {}
  viz:
    type: git
    url: https://example.org/viz.git
    layer: ui
"""


def _chain(tmp_path, *texts):
    """Write a chain: the first text stands on its own, each later one builds on the one
    before. Returns the path of the last."""
    path = None
    for index, text in enumerate(texts):
        path = tmp_path / f"m{index}.yaml"
        top = f"base: m{index - 1}.yaml\n" if index else ""
        path.write_text(top + textwrap.dedent(text))
    return path


def _merged(tmp_path, *later):
    return load_manifest(_chain(tmp_path, PUBLISHED, *later))


def _refused(tmp_path, texts, source_index, match):
    with pytest.raises(ManifestError, match=match) as info:
        load_manifest(_chain(tmp_path, *texts))
    source = tmp_path / f"m{source_index}.yaml"
    named = str(source) if source_index == len(texts) - 1 else os.path.realpath(source)
    assert str(info.value).startswith(f"{named}: "), str(info.value)


# --- A repo entry ----------------------------------------------------------------------------


def test_a_repo_entry_merges_key_by_key(tmp_path):
    # An entry that gives only `url` changes where the repo is fetched from and nothing else.
    m = _merged(tmp_path, "repositories:\n  nav:\n    url: https://example.org/fork/nav.git\n")
    nav = m.repositories["nav"]
    assert nav.url == "https://example.org/fork/nav.git"
    assert (nav.type, nav.version, nav.layer, nav.groups) == ("git", "jazzy", "core", ["sim"])
    assert nav.distros == {
        "rolling": DistroEntry(version="rolling"),
        "humble": DistroEntry(absent=True),
    }


def test_a_key_the_later_entry_gives_replaces_the_earlier_value_whole(tmp_path):
    m = _merged(
        tmp_path,
        """\
        repositories:
          nav:
            groups: []
            distros:
              rolling:
                version: main
        """,
    )
    nav = m.repositories["nav"]
    assert nav.groups == []
    assert nav.distros == {"rolling": DistroEntry(version="main")}  # humble is gone


def test_a_new_version_without_distros_keeps_the_earlier_per_distro_entries(tmp_path):
    m = _merged(tmp_path, "repositories:\n  nav:\n    version: main\n")
    nav = m.repositories["nav"]
    assert nav.version == "main"
    assert nav.distros["rolling"] == DistroEntry(version="rolling")


def test_an_empty_distros_block_clears_the_inherited_per_distro_entries(tmp_path):
    m = _merged(tmp_path, "repositories:\n  nav:\n    version: main\n    distros: {}\n")
    nav = m.repositories["nav"]
    assert nav.distros == {}
    picked = resolve(m, "dev", "rolling").layers[0].repos[0]
    assert (picked.key, picked.version) == ("nav", "main")


def test_an_empty_distros_block_drops_an_inherited_absent_true(tmp_path):
    later = "distros: [jazzy, rolling, humble]\nrepositories:\n  nav:\n    distros: {}\n"
    m = _merged(tmp_path, later)
    assert [r.key for r in resolve(m, "dev", "humble").layers[0].repos] == ["nav"]


def test_absent_false_undoes_an_earlier_absent_true(tmp_path):
    m = _merged(tmp_path, "repositories:\n  site:\n    absent: false\n")
    assert m.repositories["site"].absent is False
    selected = [r.key for layer in resolve(m, "robot", "rolling").layers for r in layer.repos]
    assert "site" in selected


def test_optional_false_undoes_an_earlier_optional_true(tmp_path):
    m = _merged(tmp_path, "repositories:\n  site:\n    optional: false\n")
    assert m.repositories["site"].optional is False
    assert resolve(m, "robot", "jazzy").optional == []


def test_a_later_manifest_moves_a_repo_to_another_layer(tmp_path):
    m = _merged(tmp_path, "layers: [drivers]\nrepositories:\n  site:\n    layer: drivers\n")
    assert m.repositories["site"].layer == "drivers"
    layers = resolve(m, "dev", "jazzy").layers
    assert [(layer.name, [r.key for r in layer.repos]) for layer in layers] == [
        ("core", ["nav"]),
        ("ui", ["viz"]),
        ("drivers", ["site"]),
    ]


def test_the_order_of_repos_is_where_each_first_appears(tmp_path):
    later = "repositories:\n  new:\n    type: git\n    url: https://example.org/new.git\n"
    later += "  nav:\n    version: main\n"
    assert list(_merged(tmp_path, later).repositories) == ["nav", "site", "viz", "new"]


# --- Roles, groups, layers, distros ----------------------------------------------------------


def test_a_role_replaces_the_earlier_one_of_the_same_name_and_a_new_role_goes_on_the_end(tmp_path):
    m = _merged(tmp_path, "groups: [ui]\nroles:\n  robot: [ui]\n  lab: [sim, ui]\n")
    assert m.roles == {"robot": ["ui"], "dev": ["sim"], "lab": ["sim", "ui"]}


def test_groups_add_to_the_earlier_list(tmp_path):
    m = _merged(tmp_path, "groups: [ui, sim, hw]\n")
    assert m.groups == ["sim", "ui", "hw"]


def test_layers_add_to_the_earlier_list_and_a_listed_layer_keeps_its_place(tmp_path):
    m = _merged(tmp_path, "layers: [ui, top, core]\n")
    assert m.layers == ["core", "ui", "top"]


def test_top_level_distros_replaces_the_earlier_list(tmp_path):
    m = _merged(tmp_path, "distros: [rolling]\n")
    assert m.distros == ["rolling"]
    with pytest.raises(ManifestError, match="does not cover distro 'jazzy'"):
        resolve(m, "robot", "jazzy")


def test_what_is_not_given_stays_as_the_earlier_manifest_gave_it(tmp_path):
    m = _merged(tmp_path, "repositories:\n  viz:\n    version: v2\n")
    assert m.distros == ["jazzy", "rolling"]
    assert m.layers == ["core", "ui"]
    assert m.roles == {"robot": [], "dev": ["sim"]}


# --- Which manifests must be complete --------------------------------------------------------


def test_a_later_manifest_may_have_no_repositories(tmp_path):
    m = _merged(tmp_path, "roles:\n  robot: [sim]\n")
    assert list(m.repositories) == ["nav", "site", "viz"]
    assert m.roles["robot"] == ["sim"]


@pytest.mark.parametrize("missing", ["type", "url"])
def test_a_new_entry_must_be_complete(tmp_path, missing):
    entry = {"type": "    type: git\n", "url": "    url: https://example.org/n.git\n"}
    del entry[missing]
    later = "repositories:\n  new:\n" + "".join(entry.values())
    _refused(
        tmp_path,
        [PUBLISHED, later],
        1,
        f"repositories.new: has no `{missing}`; a repo that no manifest read before it has is new",
    )


def test_a_misspelt_key_is_a_new_entry_and_is_refused(tmp_path):
    _refused(
        tmp_path,
        [PUBLISHED, "repositories:\n  nva:\n    url: https://example.org/fork/nav.git\n"],
        1,
        "repositories.nva: has no `type`.*is the key misspelt",
    )


# --- The diamond -----------------------------------------------------------------------------


def test_what_a_changes_in_c_stays_changed_unless_b_changes_it_again(tmp_path):
    (tmp_path / "c.yaml").write_text(PUBLISHED)
    (tmp_path / "a.yaml").write_text(
        "base: c.yaml\nrepositories:\n  nav:\n    version: from_a\n  viz:\n    version: from_a\n"
    )
    (tmp_path / "b.yaml").write_text("base: c.yaml\nrepositories:\n  viz:\n    version: from_b\n")
    leaf = tmp_path / "m.yaml"
    leaf.write_text("base: [a.yaml, b.yaml]\n")
    m = load_manifest(leaf)
    # B is read after A and does not read C again, so A's change to nav stays.
    assert m.repositories["nav"].version == "from_a"
    assert m.repositories["viz"].version == "from_b"


# --- The checks on the combination -----------------------------------------------------------


def test_a_repo_may_name_a_layer_a_later_manifest_adds(tmp_path):
    small = "repositories:\n  sonar:\n    type: git\n    url: https://example.org/s.git\n"
    later = "layers: [drivers]\nrepositories:\n  sonar:\n    layer: drivers\n"
    assert load_manifest(_chain(tmp_path, small, later)).repositories["sonar"].layer == "drivers"


def test_a_layer_not_in_the_combined_layers_names_the_manifest_that_gave_it(tmp_path):
    _refused(
        tmp_path,
        [PUBLISHED, "repositories:\n  nav:\n    layer: drivers\n"],
        1,
        re.escape("repositories.nav.layer: 'drivers' is not in the top-level `layers:` list"),
    )


def test_a_new_repo_may_name_a_group_of_an_earlier_manifest(tmp_path):
    later = (
        "repositories:\n  my_sim:\n    type: git\n    url: https://example.org/my_sim.git\n"
        "    groups: [sim]\n"
    )
    assert _merged(tmp_path, later).repositories["my_sim"].groups == ["sim"]


@pytest.mark.parametrize(
    "later,where",
    [
        ("repositories:\n  nav:\n    groups: [hw]\n", "repositories.nav.groups"),
        ("roles:\n  robot: [hw]\n", "roles.robot"),
    ],
)
def test_a_group_not_in_the_combined_groups_names_the_manifest_that_gave_it(tmp_path, later, where):
    _refused(
        tmp_path,
        [PUBLISHED, later],
        1,
        re.escape(f"{where}: group 'hw' is not in the top-level `groups:` list ['sim']"),
    )


def test_a_repo_distros_key_is_allowed_by_a_parents_distros(tmp_path):
    later = "repositories:\n  viz:\n    distros:\n      rolling:\n        absent: true\n"
    assert _merged(tmp_path, later).repositories["viz"].distros == {
        "rolling": DistroEntry(absent=True)
    }


def test_a_repo_distros_key_with_no_distros_in_the_chain_is_refused(tmp_path):
    small = "repositories:\n  a:\n    type: git\n    url: https://example.org/a.git\n"
    later = "repositories:\n  a:\n    distros:\n      jazzy: {}\n"
    _refused(
        tmp_path,
        [small, later],
        1,
        re.escape("repositories.a.distros: no manifest of the chain has a top-level `distros:`"),
    )


def test_a_parent_whose_repo_distros_are_covered_by_a_later_distros_list(tmp_path):
    # "No distros:" is judged on the combination: a later manifest may add the list.
    parent = "repositories:\n  a:\n    type: git\n    url: https://example.org/a.git\n"
    parent += "    distros:\n      jazzy: {}\n"
    leaf = "distros: [jazzy]\n"
    assert load_manifest(_chain(tmp_path, parent, leaf)).distros == ["jazzy"]


def test_a_repo_key_inside_another_across_manifests_names_the_later_manifest(tmp_path):
    later = "repositories:\n  nav/sub:\n    type: git\n    url: https://example.org/s.git\n"
    _refused(tmp_path, [PUBLISHED, later], 1, "'nav/sub'.*is inside repo 'nav'")


def test_a_repo_that_holds_an_earlier_one_names_the_later_manifest(tmp_path):
    parent = "repositories:\n  a/b:\n    type: git\n    url: https://example.org/b.git\n"
    later = "repositories:\n  a:\n    type: git\n    url: https://example.org/a.git\n"
    _refused(tmp_path, [parent, later], 1, "'a/b'.*is inside repo 'a'")


def test_layer_names_that_differ_only_in_case_across_manifests_are_refused(tmp_path):
    _refused(
        tmp_path,
        [PUBLISHED, "layers: [Core]\n"],
        1,
        "layers: layers 'core' and 'Core' differ only in case",
    )
