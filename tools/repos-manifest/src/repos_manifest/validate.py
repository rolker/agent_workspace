"""Per-role validation table and the ROS-aware dependency check."""

from __future__ import annotations

from dataclasses import dataclass
from typing import List

from .merge import MergedManifest
from .selectors import resolve_distro_ref, select_repos


@dataclass
class ValidationRow:
    repo: str
    layer: str
    included: bool
    reason: str


def _reason_groups(merged: MergedManifest, role_name: str, repo_name: str, included: bool) -> str:
    role = merged.roles[role_name]
    include_groups = [
        g.name for g in merged.groups.values() if g.default == "include" and repo_name in g.repos
    ]
    exclude_groups = [
        g.name for g in merged.groups.values() if g.default == "exclude" and repo_name in g.repos
    ]
    if exclude_groups:
        opted_in = sorted(set(exclude_groups) & set(role.add))
        if included:
            return f"opted into default-exclude group(s) {opted_in}"
        return f"default-exclude group(s) {exclude_groups}, not opted in by role"
    if include_groups:
        subtracted = sorted(set(include_groups) & set(role.subtract))
        if included:
            return f"default-include group(s) {include_groups}, not subtracted"
        return f"default-include group(s) {include_groups} all subtracted by role: {subtracted}"
    return "ungrouped (always included)"


def build_validation_table(
    merged: MergedManifest, role_name: str, distro: str
) -> List[ValidationRow]:
    selected = select_repos(merged, role_name)
    role = merged.roles[role_name]
    rows: List[ValidationRow] = []
    for layer in merged.layers:
        for repo_name in merged.layer_repos[layer]:
            present = resolve_distro_ref(merged, repo_name, distro) is not None
            included = present and repo_name in selected
            if not present:
                reason = f"absent for distro '{distro}'"
            elif role.roots is not None:
                reason = (
                    "reachable from role roots" if included else "not reachable from role roots"
                )
            else:
                reason = _reason_groups(merged, role_name, repo_name, included)
            rows.append(
                ValidationRow(repo=repo_name, layer=layer, included=included, reason=reason)
            )
    return rows


def check_dependencies(merged: MergedManifest, role_name: str, distro: str) -> List[str]:
    """A selected package's depend/exec_depend must resolve to a repo also selected (and present
    for the distro). Returns a list of human-readable violation strings; empty means clean."""
    selected = select_repos(merged, role_name)
    present = {
        name for name in merged.repos if resolve_distro_ref(merged, name, distro) is not None
    }
    active = selected & present

    violations: List[str] = []
    for pkg_name, pkg in merged.packages.items():
        if pkg.repo not in active:
            continue  # package's own repo isn't part of this role/distro resolution
        for dep_name in pkg.depend + pkg.exec_depend:
            dep_pkg = merged.packages.get(dep_name)
            if dep_pkg is None:
                continue  # already caught as a merge-time error; defensive here
            if dep_pkg.repo not in active:
                violations.append(
                    f"package '{pkg_name}' (repo '{pkg.repo}') depends on '{dep_name}'"
                    f" (repo '{dep_pkg.repo}'), which is not selected for role '{role_name}'"
                    f" distro '{distro}'"
                )
    return violations
