import pytest

from ros_manifest.merge import merge_chain
from ros_manifest.schema import ManifestError, parse_manifest_text
from ros_manifest.selectors import (
    resolve_distro_ref,
    select_repos_by_closure,
    select_repos_by_groups,
)


def _merged(text: str):
    return merge_chain([parse_manifest_text(text, source="t")])


DISTRO_MANIFEST = """
layers: [core]
repos:
  core:
    a:
      url: https://example.com/a.git
      ref: jazzy
      distros:
        rolling:
          ref: rolling
    b:
      url: https://example.com/b.git
      ref: jazzy
      distros:
        rolling:
          absent: true
roles:
  dev: {}
"""


def test_distro_default_ref():
    merged = _merged(DISTRO_MANIFEST)
    assert resolve_distro_ref(merged, "a", "jazzy") == "jazzy"
    assert resolve_distro_ref(merged, "b", "jazzy") == "jazzy"


def test_distro_override_ref():
    merged = _merged(DISTRO_MANIFEST)
    assert resolve_distro_ref(merged, "a", "rolling") == "rolling"


def test_distro_absent_repo():
    merged = _merged(DISTRO_MANIFEST)
    assert resolve_distro_ref(merged, "b", "rolling") is None


GROUPS_MANIFEST = """
layers: [core]
repos:
  core:
    base_repo:
      url: https://example.com/base.git
      ref: main
    gui_repo:
      url: https://example.com/gui.git
      ref: main
    hw_repo:
      url: https://example.com/hw.git
      ref: main
groups:
  gui:
    default: include
    repos: [gui_repo]
  hw:deltat:
    default: exclude
    repos: [hw_repo]
roles:
  operator:
    subtract: [gui]
    add: []
  izzyboat:
    subtract: []
    add: ["hw:deltat"]
  dev:
    subtract: []
    add: []
"""


def test_groups_default_role_includes_default_include_excludes_default_exclude():
    merged = _merged(GROUPS_MANIFEST)
    selected = select_repos_by_groups(merged, "dev")
    assert selected == {"base_repo", "gui_repo"}


def test_groups_role_subtracts_default_include_group():
    merged = _merged(GROUPS_MANIFEST)
    selected = select_repos_by_groups(merged, "operator")
    assert selected == {"base_repo"}


def test_groups_role_opts_into_default_exclude_group():
    merged = _merged(GROUPS_MANIFEST)
    selected = select_repos_by_groups(merged, "izzyboat")
    assert selected == {"base_repo", "gui_repo", "hw_repo"}


def test_groups_roles_compose():
    # izzyboat = platform (no subtract) + hw:deltat (add) — matches the issue's composition
    # example. A role that both subtracts gui and adds hw:deltat gets neither gui nor loses hw.
    merged = _merged(
        GROUPS_MANIFEST.replace(
            "  dev:\n    subtract: []\n    add: []\n",
            '  bizzyboat:\n    subtract: [gui]\n    add: ["hw:deltat"]\n',
        )
    )
    selected = select_repos_by_groups(merged, "bizzyboat")
    assert selected == {"base_repo", "hw_repo"}


CLOSURE_MANIFEST = """
layers: [core]
repos:
  core:
    bringup_repo:
      url: https://example.com/bringup.git
      ref: main
    nav_repo:
      url: https://example.com/nav.git
      ref: main
    platform_repo:
      url: https://example.com/platform.git
      ref: main
    unrelated_repo:
      url: https://example.com/unrelated.git
      ref: main
packages:
  izzyboat_bringup:
    repo: bringup_repo
    exec_depend: [nav2_stack]
  nav2_stack:
    repo: nav_repo
    depend: [platform_driver]
  platform_driver:
    repo: platform_repo
    depend: []
  unused_pkg:
    repo: unrelated_repo
    depend: []
roles:
  izzyboat_closure:
    roots: [izzyboat_bringup]
"""


def test_closure_model_walks_exec_depend_and_depend():
    merged = _merged(CLOSURE_MANIFEST)
    selected = select_repos_by_closure(merged, "izzyboat_closure")
    assert selected == {"bringup_repo", "nav_repo", "platform_repo"}
    assert "unrelated_repo" not in selected


def test_groups_model_rejects_closure_role():
    merged = _merged(CLOSURE_MANIFEST)
    with pytest.raises(ManifestError, match="closure model"):
        select_repos_by_groups(merged, "izzyboat_closure")


def test_unknown_role_is_error():
    merged = _merged(GROUPS_MANIFEST)
    with pytest.raises(ManifestError, match="unknown role"):
        select_repos_by_groups(merged, "nope")
