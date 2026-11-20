"""`show`'s renderer: what a manifest comes to for a machine, as the design's sketch prints it."""

import os
import textwrap

import pytest

from repos_manifest.base import load_manifest, parse_manifest
from repos_manifest.selection import resolve
from repos_manifest.show import render, render_body, render_head

SYSTEM = """\
distros: [jazzy, rolling]
layers: [underlay, core, platforms]
groups: [simulation, echoboat-hardware, ben-hardware]
roles:
  robot: []
  developer: [simulation]
repositories:
  geographic_info:
    type: git
    url: https://github.com/ros-geographic-info/geographic_info.git
    version: ros2
    layer: underlay
  unh_marine_autonomy:
    type: git
    url: https://github.com/example/unh_marine_autonomy.git
    version: jazzy
    layer: core
  site_config:
    type: git
    url: git@github.com:example/site_config.git
    version: jazzy
    layer: core
    optional: true
  vrx:
    type: git
    url: https://github.com/example/vrx.git
    layer: platforms
    groups: [simulation]
  ben_bringup:
    type: git
    url: https://github.com/example/ben_bringup.git
    layer: platforms
    groups: [ben-hardware]
"""

PROJECT11 = """\
base: system.manifest.yaml
repositories:
  echoboat_bringup:
    type: git
    url: https://github.com/example/echoboat_bringup.git
    version: jazzy
    layer: platforms
    groups: [echoboat-hardware]
  new_planner:
    type: git
    url: https://github.com/example/new_planner.git
    layer: core
    absent: true
    distros:
      rolling:
        version: main
  geographic_info:
    version: ros2-fixed
"""


@pytest.fixture
def chain(tmp_path, monkeypatch):
    """The sketch's manifest: project11.manifest.yaml building on system.manifest.yaml, read
    from the directory that holds them. Returns the base's name as the output gives it."""
    (tmp_path / "system.manifest.yaml").write_text(SYSTEM)
    (tmp_path / "project11.manifest.yaml").write_text(PROJECT11)
    monkeypatch.chdir(tmp_path)
    return os.path.realpath(tmp_path / "system.manifest.yaml")


def _resolved(role="robot", distro="jazzy", extra=("echoboat-hardware",)):
    manifest = load_manifest("project11.manifest.yaml", source="project11.manifest.yaml")
    return resolve(manifest, role, distro, list(extra))


def test_show_prints_the_sketch_of_the_design(chain):
    # A repo the leaf only re-versions came from the base and is not marked; one the leaf brings
    # is marked with the leaf's name, under its url.
    expected = f"""\
manifest  project11.manifest.yaml
base      {chain}
role      robot    groups on: echoboat-hardware    distro: jazzy

underlay
  geographic_info       ros2-fixed   https://github.com/ros-geographic-info/geographic_info.git
core
  unh_marine_autonomy   jazzy        https://github.com/example/unh_marine_autonomy.git
  site_config           jazzy        git@github.com:example/site_config.git   optional
platforms
  echoboat_bringup      jazzy        https://github.com/example/echoboat_bringup.git
                                     from project11.manifest.yaml

left out
  vrx                   group simulation is off
  ben_bringup           group ben-hardware is off
  new_planner           not on jazzy"""
    assert render(_resolved()) == expected


def test_a_repo_with_no_version_prints_its_default_branch_and_a_distro_brings_it_back(chain):
    out = render(_resolved("developer", "rolling", ()))
    assert "  new_planner           main" in out
    assert (
        "  vrx                   (its default branch)   https://github.com/example/vrx.git" in out
    )
    assert out.endswith(
        "left out\n"
        "  ben_bringup           group ben-hardware is off\n"
        "  echoboat_bringup      group echoboat-hardware is off"
    )
    assert "role      developer    groups on: simulation    distro: rolling\n" in out


def test_the_head_without_the_distro_and_the_body_make_the_whole(chain):
    resolved = _resolved()
    head = render_head(resolved)
    assert head.splitlines()[-1] == "role      robot    groups on: echoboat-hardware"
    assert render(resolved) == (render_head(resolved, distro=True) + "\n\n" + render_body(resolved))


def _plain(text):
    return parse_manifest(textwrap.dedent(text), "plain.yaml")


def test_a_manifest_with_no_roles_or_distros_prints_none_and_the_unnamed_layer():
    m = _plain(
        """\
        repositories:
          a:
            type: git
            url: https://example.org/a.git
            version: main
          gone:
            type: git
            url: https://example.org/gone.git
            absent: true
        """
    )
    assert render(resolve(m)) == (
        "manifest  plain.yaml\n"
        "role      (none)    groups on: (none)    distro: (none)\n"
        "\n"
        "(unnamed layer)\n"
        "  a      main   https://example.org/a.git\n"
        "\n"
        "left out\n"
        "  gone   absent, and no distro adds it"
    )


def test_a_repo_whose_groups_are_all_off_names_them():
    m = _plain(
        """\
        groups: [sim, hw]
        repositories:
          a:
            type: git
            url: https://example.org/a.git
            groups: [sim, hw]
        """
    )
    out = render(resolve(m))
    assert out.endswith("left out\n  a   none of its groups (sim, hw) is on")
    assert "no repo is selected for this machine" in out


def test_a_url_with_a_password_prints_masked():
    m = _plain(
        """\
        repositories:
          a:
            type: git
            url: https://user:s3cret@example.org/a.git
        """
    )
    out = render(resolve(m))
    assert "s3cret" not in out
    assert "user" not in out
    assert "https://***@example.org/a.git" in out
