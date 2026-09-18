"""Acceptance test: resolving the p11 fixture manifest for role=dev must reproduce the real
project11 .repos files exactly (modulo the provenance header), for both jazzy and rolling — the
project11 jazzy/rolling manifest branches differ by exactly 3 lines today (confirmed against the
live checkouts at projects/p11-jazzy and projects/p11-rolling in the workspace repo), and this
fixture is authored to reproduce that with a single manifest + one per-distro ref override."""

import pytest

from ros_manifest.emit import emit_layer, strip_provenance_header
from ros_manifest.extends import resolve_chain
from ros_manifest.merge import merge_chain
from ros_manifest.selectors import select_repos

LAYERS = ["underlay", "core", "platforms", "site", "sensors", "simulation", "ui"]


@pytest.fixture
def merged(fixtures_dir):
    manifest_path = fixtures_dir / "p11" / "manifest.yaml"
    return merge_chain(resolve_chain(manifest_path))


@pytest.mark.parametrize("distro", ["jazzy", "rolling"])
def test_resolved_repos_match_fixture_exactly(merged, fixtures_dir, distro):
    selected = select_repos(merged, "dev")
    expected_dir = fixtures_dir / "p11" / "expected" / distro
    for layer in LAYERS:
        got = emit_layer(merged, layer, selected, role="dev", distro=distro)
        expected_path = expected_dir / f"{layer}.repos"
        assert expected_path.is_file(), f"missing expected fixture {expected_path}"
        want = expected_path.read_text()
        assert got is not None, f"layer {layer} resolved to nothing for distro {distro}"
        assert strip_provenance_header(got) == want, f"mismatch for layer={layer} distro={distro}"


def test_dev_role_selects_all_44_repos(merged):
    selected = select_repos(merged, "dev")
    assert len(selected) == 44


def test_rolling_only_differs_by_unh_marine_autonomy_ref(merged):
    from ros_manifest.selectors import resolve_distro_ref

    diffs = [
        name
        for name in merged.repos
        if resolve_distro_ref(merged, name, "jazzy") != resolve_distro_ref(merged, name, "rolling")
    ]
    assert diffs == ["unh_marine_autonomy"]
    assert resolve_distro_ref(merged, "unh_marine_autonomy", "jazzy") == "jazzy"
    assert resolve_distro_ref(merged, "unh_marine_autonomy", "rolling") == "rolling"
