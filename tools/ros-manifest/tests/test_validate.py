from ros_manifest.merge import merge_chain
from ros_manifest.schema import parse_manifest_text
from ros_manifest.validate import build_validation_table, check_dependencies

MANIFEST = """
layers: [core]
repos:
  core:
    operator_repo:
      url: https://example.com/operator.git
      ref: main
    platform_repo:
      url: https://example.com/platform.git
      ref: main
groups:
  platform:
    default: exclude
    repos: [platform_repo]
packages:
  operator_station_bringup:
    repo: operator_repo
    exec_depend: [platform_driver]
  platform_driver:
    repo: platform_repo
roles:
  operator:
    subtract: []
    add: []
  operator_with_platform:
    subtract: []
    add: [platform]
"""


def _merged():
    return merge_chain([parse_manifest_text(MANIFEST, source="t")])


def test_dependency_check_flags_boundary_violation():
    merged = _merged()
    violations = check_dependencies(merged, "operator", "jazzy")
    assert len(violations) == 1
    assert "operator_station_bringup" in violations[0]
    assert "platform_driver" in violations[0]


def test_dependency_check_clean_when_platform_included():
    merged = _merged()
    violations = check_dependencies(merged, "operator_with_platform", "jazzy")
    assert violations == []


def test_validation_table_reasons():
    merged = _merged()
    rows = {r.repo: r for r in build_validation_table(merged, "operator", "jazzy")}
    assert rows["operator_repo"].included is True
    assert rows["operator_repo"].reason == "ungrouped (always included)"
    assert rows["platform_repo"].included is False
    assert "default-exclude" in rows["platform_repo"].reason
