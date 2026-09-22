"""Merge an extends chain (base-first) into one composed manifest.

Rules (issue #267 design decision 1):
- First definition wins. A repo may be defined by exactly one manifest in the chain; any later
  manifest re-declaring the same repo name (in any layer) is a hard error — extensions add,
  they never remove or re-version a base repo.
- Layers are a fixed, ordered list per manifest; composing preserves the base's order and
  appends any new layer names an extension introduces, in that extension's own listed order.
- Groups and roles may be extended: a later manifest may add repos to a group's list (defaults
  must agree) and may add to a role's subtract/add lists. Redeclaring a role's closure `roots`
  is an error for the same reason repos are — no silent override.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List

from .schema import GroupEntry, Manifest, ManifestError, PackageEntry, RepoEntry, RoleEntry


@dataclass
class MergedRepo:
    entry: RepoEntry
    layer: str
    source: str  # provenance: which manifest file defined it


@dataclass
class MergedManifest:
    layers: List[str]
    repos: Dict[str, MergedRepo] = field(default_factory=dict)  # repo name -> MergedRepo
    layer_repos: Dict[str, List[str]] = field(
        default_factory=dict
    )  # layer -> [repo names], defined order
    groups: Dict[str, GroupEntry] = field(default_factory=dict)
    roles: Dict[str, RoleEntry] = field(default_factory=dict)
    packages: Dict[str, PackageEntry] = field(default_factory=dict)


def merge_chain(chain: List[Manifest]) -> MergedManifest:
    if not chain:
        raise ManifestError("empty manifest chain")

    layers: List[str] = []
    for manifest in chain:
        for layer in manifest.layers:
            if layer not in layers:
                layers.append(layer)

    merged = MergedManifest(layers=layers, layer_repos={layer: [] for layer in layers})

    for manifest in chain:
        for layer, layer_repos in manifest.repos.items():
            for repo_name, entry in layer_repos.items():
                if repo_name in merged.repos:
                    prior = merged.repos[repo_name]
                    raise ManifestError(
                        f"{manifest.source}: repo '{repo_name}' already defined by"
                        f" {prior.source} (layer '{prior.layer}') — extensions may not remove"
                        " or re-version a base repo; first definition wins"
                    )
                merged.repos[repo_name] = MergedRepo(
                    entry=entry, layer=layer, source=manifest.source
                )
                merged.layer_repos[layer].append(repo_name)

        for name, group in manifest.groups.items():
            if name in merged.groups:
                existing = merged.groups[name]
                if existing.default != group.default:
                    raise ManifestError(
                        f"{manifest.source}: group '{name}' redeclares default"
                        f" '{group.default}' (was '{existing.default}' in an earlier manifest)"
                    )
                merged_repos_list = list(existing.repos)
                for r in group.repos:
                    if r not in merged_repos_list:
                        merged_repos_list.append(r)
                merged.groups[name] = GroupEntry(
                    name=name, default=existing.default, repos=merged_repos_list
                )
            else:
                merged.groups[name] = GroupEntry(
                    name=name, default=group.default, repos=list(group.repos)
                )

        for name, role in manifest.roles.items():
            if name in merged.roles:
                existing = merged.roles[name]
                if (existing.roots is not None) != (role.roots is not None):
                    raise ManifestError(
                        f"{manifest.source}: role '{name}' mixes the closure model ('roots') with"
                        " the groups model ('subtract'/'add') across the extends chain"
                    )
                if role.roots is not None:
                    raise ManifestError(
                        f"{manifest.source}: role '{name}' redeclares 'roots' — first definition"
                        " wins; an extension may only add to 'subtract'/'add', not redefine a"
                        " closure role's roots"
                    )
                subtract = list(existing.subtract)
                for g in role.subtract:
                    if g not in subtract:
                        subtract.append(g)
                add = list(existing.add)
                for g in role.add:
                    if g not in add:
                        add.append(g)
                merged.roles[name] = RoleEntry(
                    name=name, subtract=subtract, add=add, roots=existing.roots
                )
            else:
                merged.roles[name] = RoleEntry(
                    name=name, subtract=list(role.subtract), add=list(role.add), roots=role.roots
                )

        for name, pkg in manifest.packages.items():
            if name in merged.packages:
                prior = merged.packages[name]
                raise ManifestError(
                    f"{manifest.source}: package '{name}' already defined (repo"
                    f" '{prior.repo}') — first definition wins"
                )
            merged.packages[name] = pkg

    # Cross-reference validation now that the whole chain is merged.
    for name, group in merged.groups.items():
        for repo_name in group.repos:
            if repo_name not in merged.repos:
                raise ManifestError(f"group '{name}' references undefined repo '{repo_name}'")
    for name, role in merged.roles.items():
        for group_name in role.subtract + role.add:
            if group_name not in merged.groups:
                raise ManifestError(f"role '{name}' references undefined group '{group_name}'")
        if role.roots:
            for pkg_name in role.roots:
                if pkg_name not in merged.packages:
                    raise ManifestError(f"role '{name}' references undefined package '{pkg_name}'")
    for name, pkg in merged.packages.items():
        if pkg.repo not in merged.repos:
            raise ManifestError(f"package '{name}' references undefined repo '{pkg.repo}'")
        for dep in pkg.depend + pkg.exec_depend:
            if dep not in merged.packages:
                raise ManifestError(f"package '{name}' depends on undeclared package '{dep}'")

    return merged
