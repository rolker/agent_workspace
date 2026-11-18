"""Combining the manifests of a chain, and the checks that read the combination.

The rules of "How manifests combine" in ``docs/spec.md``, applied to the parts in reading order,
a later one over an earlier one:

- A repo entry is merged key by key: a key the later entry gives replaces the earlier value as
  a whole, a key it does not give keeps the earlier value. A repo's place in the order is where
  it first appears.
- A role replaces the earlier one of the same name; a new role goes on the end.
- `groups:` and `layers:` add to the earlier list; a name already listed keeps its place.
- `distros:`, when given, replaces the earlier list.

Every merged value keeps the name of the manifest that gave it, and a check on the combination
names that manifest. A manifest that stands on its own is a chain of one.
"""

from __future__ import annotations

from typing import Dict, List, NamedTuple, Optional, Sequence

from .manifest import FORMAT, Manifest, Part, Repo
from .yamlload import ManifestError


def _error(source: str, where: str, what: str) -> ManifestError:
    return ManifestError(f"{source}: {where}: {what}" if where else f"{source}: {what}")


class _Given(NamedTuple):
    """A value and the manifest that gave it."""

    value: object
    source: str


def merge_parts(parts: Sequence[Part], bases: Sequence[str] = ()) -> Manifest:
    """Merge `parts`, in reading order with the manifest that was asked for last, and check the
    result. `bases` names the parents in reading order, for the output's head comment."""
    distros: Optional[_Given] = None
    layers: Dict[str, str] = {}  # name -> the manifest that added it, in order
    groups: Dict[str, str] = {}
    roles: Optional[Dict[str, _Given]] = None
    repos: Dict[str, Dict[str, _Given]] = {}
    first: Dict[str, int] = {}  # repo key -> index of the part it first appears in
    brought: Dict[str, List[str]] = {}  # repo key -> the keys of its entry where it first appears
    warnings: List[str] = []

    for index, part in enumerate(parts):
        warnings.extend(part.warnings)
        if part.distros is not None:
            distros = _Given(part.distros, part.source)
        for name in part.layers:
            layers.setdefault(name, part.source)
        for name in part.groups:
            groups.setdefault(name, part.source)
        if part.roles is not None:
            roles = {} if roles is None else roles
            for name, role_groups in part.roles.items():
                roles[name] = _Given(role_groups, part.source)
        for key, given in part.repos.items():
            if key not in repos:
                repos[key] = {}
                first[key] = index
                brought[key] = list(given)
            for name, value in given.items():
                repos[key][name] = _Given(value, part.source)

    layer_list, group_list = list(layers), list(groups)
    _check_layer_case(layers)
    if roles is not None:
        for name, role in roles.items():
            _check_declared(role.value, group_list, role.source, f"roles.{name}")
    repositories: Dict[str, Repo] = {}
    for key, given in repos.items():
        _check_complete(key, brought[key], parts[first[key]].source, first[key] > 0)
        repositories[key] = _repo(key, given)
        _check_repo(key, given, distros, layer_list, group_list, len(parts) > 1)
    _check_no_key_inside_another(repos, first, parts)

    leaf = parts[-1]
    return Manifest(
        source=leaf.source,
        format=FORMAT,
        distros=None if distros is None else list(distros.value),
        layers=layer_list,
        groups=group_list,
        roles=None if roles is None else {name: list(r.value) for name, r in roles.items()},
        repositories=repositories,
        warnings=warnings,
        bases=list(bases),
    )


def _check_layer_case(layers: Dict[str, str]) -> None:
    # Layer names are file and directory names, and some disks treat names that differ only in
    # case as one; so they are compared without case.
    by_case: Dict[str, str] = {}
    for layer, source in layers.items():
        if layer.lower() in by_case:
            raise _error(
                source,
                "layers",
                f"layers {by_case[layer.lower()]!r} and {layer!r} differ only in case; some"
                " disks treat them as one",
            )
        by_case[layer.lower()] = layer


def _check_declared(names: List[str], groups: List[str], source: str, where: str) -> None:
    for group in names:
        if group not in groups:
            raise _error(
                source, where, f"group {group!r} is not in the top-level `groups:` list {groups}"
            )


def _check_complete(key: str, brought: List[str], source: str, has_earlier: bool) -> None:
    """A repo's entry has `type` and `url` in the manifest where its key first appears in
    reading order, `source`; a later manifest may then change any key. `brought` is the keys
    that manifest gave."""
    for required in ("type", "url"):
        if required not in brought:
            hint = (
                "; a repo that no manifest read before it has is new and needs it: is the key"
                " misspelt?"
                if has_earlier
                else ""
            )
            raise _error(source, f"repositories.{key}", f"has no `{required}`{hint}")


def _repo(key: str, given: Dict[str, _Given]) -> Repo:
    """The merged entry as a `Repo`; `_check_complete` has passed, and a later manifest cannot
    take a key away."""
    values = {name: g.value for name, g in given.items()}
    return Repo(
        key=key,
        type=values["type"],
        url=values["url"],
        version=values.get("version"),
        absent=values.get("absent", False),
        layer=values.get("layer"),
        groups=list(values.get("groups", [])),
        distros=values.get("distros"),
        optional=values.get("optional", False),
    )


def _check_repo(
    key: str,
    given: Dict[str, _Given],
    distros: Optional[_Given],
    layers: List[str],
    groups: List[str],
    chain: bool,
) -> None:
    where = f"repositories.{key}"
    if "layer" in given and given["layer"].value not in layers:
        raise _error(
            given["layer"].source,
            f"{where}.layer",
            f"{given['layer'].value!r} is not in the top-level `layers:` list {layers}",
        )
    if "groups" in given:
        _check_declared(given["groups"].value, groups, given["groups"].source, f"{where}.groups")
    if "distros" in given and distros is None:
        raise _error(
            given["distros"].source,
            f"{where}.distros",
            (
                "no manifest of the chain has a top-level `distros:` list"
                if chain
                else "the manifest has no top-level `distros:` list"
            )
            + ", so no repo may have a `distros:` key",
        )


def _check_no_key_inside_another(
    repos: Dict[str, Dict[str, _Given]], first: Dict[str, int], parts: Sequence[Part]
) -> None:
    """No repo key is another followed by '/' and more. The message names the manifest that
    brought in the later of the two."""
    for key in repos:
        parts_of_key = key.split("/")
        for end in range(1, len(parts_of_key)):
            outer = "/".join(parts_of_key[:end])
            if outer in repos:
                source = parts[max(first[key], first[outer])].source
                raise _error(
                    source,
                    f"repositories: {key!r}",
                    f"is inside repo {outer!r}; one repo is never cloned inside another",
                )
