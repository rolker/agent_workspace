"""From a manifest, a role, a distro and extra groups to the repos of each layer.

Rules, from ``docs/spec.md``: a repo in no group is always selected, and a repo in groups is
selected when any of them is on; the groups on are the role's and the extra ones. A repo's
`version` is its default and a distro's entry can replace it; `absent: true` on a distro's entry
leaves the repo out on that distro, and `absent: true` on the repo leaves it out on every distro
that has no entry for it. Layers come in order, the unnamed first layer before every named one.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional, Sequence

from .manifest import UNNAMED_LAYER, Manifest, Repo
from .yamlload import ManifestError


@dataclass
class Selected:
    """One repo as a machine gets it."""

    key: str
    type: str
    url: str
    version: Optional[str]
    optional: bool


@dataclass
class Layer:
    name: str  # UNNAMED_LAYER for the unnamed first layer
    repos: List[Selected]


@dataclass
class Resolved:
    """What resolving produces: the repos of each layer, in layer order, with only the layers
    that have repos for this machine; and which of the selected repos are optional."""

    source: str
    role: Optional[str]
    distro: Optional[str]
    extra_groups: List[str]
    layers: List[Layer]
    bases: List[str] = field(default_factory=list)  # the manifests it builds on, reading order

    @property
    def optional(self) -> List[str]:
        return [repo.key for layer in self.layers for repo in layer.repos if repo.optional]


def check_role_and_distro(
    manifest: Manifest, role: Optional[str], distro: Optional[str], extra_groups: Sequence[str]
) -> List[str]:
    """Refuse a role, distro or extra group the manifest does not allow; return the groups that
    are on."""
    source = manifest.source
    if manifest.roles is None:
        if role is not None:
            raise ManifestError(f"{source}: has no `roles:`, so no role is given (got {role!r})")
        on = []
    else:
        if role is None:
            raise ManifestError(f"{source}: has roles; give one of {sorted(manifest.roles)}")
        if role not in manifest.roles:
            raise ManifestError(
                f"{source}: has no role {role!r}; its roles are {sorted(manifest.roles)}"
            )
        on = list(manifest.roles[role])
    if manifest.distros is None:
        if distro is not None:
            raise ManifestError(
                f"{source}: has no `distros:`, so no distro is given (got {distro!r})"
            )
    else:
        if distro is None:
            raise ManifestError(f"{source}: has distros; give one of {manifest.distros}")
        if distro not in manifest.distros:
            raise ManifestError(
                f"{source}: does not cover distro {distro!r}; its distros are {manifest.distros}"
            )
    for group in extra_groups:
        if group not in manifest.groups:
            raise ManifestError(
                f"{source}: extra group {group!r} is not in the top-level `groups:` list"
                f" {manifest.groups}"
            )
        if group not in on:
            on.append(group)
    return on


def _version_on(repo: Repo, distro: Optional[str]):
    """(present, version) of `repo` on `distro`."""
    entry = None
    if distro is not None and repo.distros is not None:
        entry = repo.distros.get(distro)
    if entry is None:
        return not repo.absent, repo.version
    if entry.absent:
        return False, None
    return True, entry.version if entry.version is not None else repo.version


def resolve(
    manifest: Manifest,
    role: Optional[str] = None,
    distro: Optional[str] = None,
    extra_groups: Sequence[str] = (),
) -> Resolved:
    on = check_role_and_distro(manifest, role, distro, extra_groups)
    by_layer = {name: [] for name in [None] + manifest.layers}
    for repo in manifest.repositories.values():
        if repo.groups and not any(group in on for group in repo.groups):
            continue
        present, version = _version_on(repo, distro)
        if not present:
            continue
        by_layer[repo.layer].append(Selected(repo.key, repo.type, repo.url, version, repo.optional))
    layers = [
        Layer(UNNAMED_LAYER if name is None else name, repos)
        for name, repos in by_layer.items()
        if repos
    ]
    return Resolved(manifest.source, role, distro, list(extra_groups), layers, list(manifest.bases))
