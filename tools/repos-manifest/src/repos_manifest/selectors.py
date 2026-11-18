"""Distro-ref resolution and the two role selector models (groups, dependency closure)."""

from __future__ import annotations

from typing import Dict, Optional, Set

from .merge import MergedManifest
from .schema import ManifestError


def resolve_distro_ref(merged: MergedManifest, repo_name: str, distro: str) -> Optional[str]:
    """Return the ref to use for `repo_name` under `distro`, or None if absent for that distro."""
    repo = merged.repos[repo_name].entry
    override = repo.distros.get(distro)
    if override is None:
        return repo.ref
    if override.get("absent"):
        return None
    return override["ref"]


def repos_present_for_distro(merged: MergedManifest, distro: str) -> Set[str]:
    return {name for name in merged.repos if resolve_distro_ref(merged, name, distro) is not None}


def select_repos_by_groups(merged: MergedManifest, role_name: str) -> Set[str]:
    """Groups model: every repo is included by default unless it's in a default-exclude group
    the role hasn't opted into, or in a default-include group the role has subtracted."""
    if role_name not in merged.roles:
        raise ManifestError(f"unknown role '{role_name}'")
    role = merged.roles[role_name]
    if role.roots is not None:
        raise ManifestError(
            f"role '{role_name}' uses the closure model (roots) — use --model closure"
        )

    # Map repo -> set of groups it belongs to, split by each group's default.
    include_groups_of: Dict[str, list] = {name: [] for name in merged.repos}
    exclude_groups_of: Dict[str, list] = {name: [] for name in merged.repos}
    for group in merged.groups.values():
        for repo_name in group.repos:
            if group.default == "include":
                include_groups_of[repo_name].append(group.name)
            else:
                exclude_groups_of[repo_name].append(group.name)

    subtracted = set(role.subtract)
    added = set(role.add)
    selected = set()
    for repo_name in merged.repos:
        in_default_include_groups = include_groups_of[repo_name]
        in_default_exclude_groups = exclude_groups_of[repo_name]
        if in_default_exclude_groups:
            # Excluded unless the role opts into at least one of its exclude-groups.
            if added & set(in_default_exclude_groups):
                selected.add(repo_name)
            continue
        if in_default_include_groups:
            # Included unless the role subtracts every include-group it's in.
            if set(in_default_include_groups) <= subtracted:
                continue
            selected.add(repo_name)
            continue
        # Ungrouped repos are always included.
        selected.add(repo_name)
    return selected


def select_repos_by_closure(merged: MergedManifest, role_name: str) -> Set[str]:
    """Dependency-closure model: role.roots are root packages; depend/exec_depend reachability
    over merged.packages selects the rest. Returns the set of repos backing the reachable
    packages."""
    if role_name not in merged.roles:
        raise ManifestError(f"unknown role '{role_name}'")
    role = merged.roles[role_name]
    if role.roots is None:
        raise ManifestError(
            f"role '{role_name}' uses the groups model (subtract/add) — use --model groups"
        )

    visited: Set[str] = set()
    stack = list(role.roots)
    while stack:
        pkg_name = stack.pop()
        if pkg_name in visited:
            continue
        visited.add(pkg_name)
        pkg = merged.packages[pkg_name]
        for dep in pkg.depend + pkg.exec_depend:
            if dep not in visited:
                stack.append(dep)

    return {merged.packages[name].repo for name in visited}


def select_repos(merged: MergedManifest, role_name: str) -> Set[str]:
    """Dispatch to the model implied by the role's own declaration."""
    role = merged.roles.get(role_name)
    if role is None:
        raise ManifestError(f"unknown role '{role_name}'")
    if role.roots is not None:
        return select_repos_by_closure(merged, role_name)
    return select_repos_by_groups(merged, role_name)
