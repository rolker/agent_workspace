"""Manifest YAML loading and structural (single-file) validation.

Cross-manifest validation (does a group reference a repo that actually exists anywhere in the
extends chain, does an extension try to remove/re-version a base repo) happens in ``merge.py``
after the whole chain is loaded — a single manifest file is allowed to reference repos defined
only in a base it extends.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import yaml


class ManifestError(Exception):
    """A manifest file (or a chain of them) is invalid."""


@dataclass
class ExtendsRef:
    # Local-path form: only `path` is set (resolved relative to the manifest that declares it).
    # Git form: `url` + `ref` + `path` (path inside the clone; defaults to "manifest.yaml").
    path: str
    url: Optional[str] = None
    ref: Optional[str] = None


@dataclass
class RepoEntry:
    name: str
    url: str
    ref: str
    type: str = "git"
    # distro -> {"ref": <str>} or {"absent": True}
    distros: dict = field(default_factory=dict)


@dataclass
class GroupEntry:
    name: str
    default: str  # "include" or "exclude"
    repos: list


@dataclass
class RoleEntry:
    name: str
    subtract: list = field(default_factory=list)
    add: list = field(default_factory=list)
    roots: Optional[list] = None  # presence selects the dependency-closure model


@dataclass
class PackageEntry:
    name: str
    repo: str
    depend: list = field(default_factory=list)
    exec_depend: list = field(default_factory=list)


@dataclass
class Manifest:
    """One manifest file's own content (pre-merge)."""

    source: str  # human-readable provenance label (file path or url#ref/path)
    extends: Optional[ExtendsRef]
    layers: list
    repos: dict  # layer -> {repo_name: RepoEntry}
    groups: dict  # name -> GroupEntry
    roles: dict  # name -> RoleEntry
    packages: dict  # name -> PackageEntry


_TOP_LEVEL_KEYS = {"extends", "layers", "repos", "groups", "roles", "packages"}
_REPO_KEYS = {"url", "ref", "type", "distros"}
_GROUP_KEYS = {"default", "repos"}
_ROLE_KEYS = {"subtract", "add", "roots"}
_PACKAGE_KEYS = {"repo", "depend", "exec_depend"}


def _require_dict(value, what: str) -> dict:
    if not isinstance(value, dict):
        raise ManifestError(f"{what} must be a mapping, got {type(value).__name__}")
    return value


def _require_list_of_str(value, what: str) -> list:
    if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
        raise ManifestError(f"{what} must be a list of strings")
    return value


def parse_manifest_text(text: str, source: str) -> Manifest:
    """Parse and structurally validate one manifest document. Does not resolve `extends`."""
    try:
        raw = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        raise ManifestError(f"{source}: invalid YAML: {exc}") from exc
    if raw is None:
        raw = {}
    raw = _require_dict(raw, source)

    unknown = set(raw) - _TOP_LEVEL_KEYS
    if unknown:
        raise ManifestError(f"{source}: unknown top-level key(s): {sorted(unknown)}")

    extends_ref: Optional[ExtendsRef] = None
    if "extends" in raw:
        ext = _require_dict(raw["extends"], f"{source}: extends")
        if "path" not in ext:
            raise ManifestError(f"{source}: extends must set 'path'")
        if "url" in ext and "ref" not in ext:
            raise ManifestError(f"{source}: extends with 'url' must also set 'ref'")
        extends_ref = ExtendsRef(path=ext["path"], url=ext.get("url"), ref=ext.get("ref"))

    layers = _require_list_of_str(raw.get("layers", []), f"{source}: layers")
    if not layers:
        raise ManifestError(f"{source}: layers must be a non-empty list")
    if len(set(layers)) != len(layers):
        raise ManifestError(f"{source}: layers contains duplicates: {layers}")

    repos_raw = _require_dict(raw.get("repos", {}), f"{source}: repos")
    repos: dict = {layer: {} for layer in layers}
    for layer, layer_repos in repos_raw.items():
        if layer not in repos:
            raise ManifestError(
                f"{source}: repos declares layer '{layer}' not present in this manifest's own"
                f" 'layers' list {layers}"
            )
        layer_repos = _require_dict(layer_repos, f"{source}: repos.{layer}")
        for repo_name, entry in layer_repos.items():
            entry = _require_dict(entry, f"{source}: repos.{layer}.{repo_name}")
            unknown_repo_keys = set(entry) - _REPO_KEYS
            if unknown_repo_keys:
                raise ManifestError(
                    f"{source}: repos.{layer}.{repo_name}: unknown key(s)"
                    f" {sorted(unknown_repo_keys)}"
                )
            if "url" not in entry:
                raise ManifestError(f"{source}: repos.{layer}.{repo_name}: missing 'url'")
            if "ref" not in entry:
                raise ManifestError(
                    f"{source}: repos.{layer}.{repo_name}: missing 'ref' (default ref)"
                )
            distros_raw = _require_dict(
                entry.get("distros", {}), f"{source}: repos.{layer}.{repo_name}.distros"
            )
            distros = {}
            for distro, dval in distros_raw.items():
                dval = _require_dict(dval, f"{source}: repos.{layer}.{repo_name}.distros.{distro}")
                has_ref = "ref" in dval
                has_absent = dval.get("absent", False)
                if has_ref and has_absent:
                    raise ManifestError(
                        f"{source}: repos.{layer}.{repo_name}.distros.{distro}: cannot set both"
                        " 'ref' and 'absent'"
                    )
                if not has_ref and not has_absent:
                    raise ManifestError(
                        f"{source}: repos.{layer}.{repo_name}.distros.{distro}: must set 'ref' or"
                        " 'absent: true'"
                    )
                distros[distro] = {"ref": dval["ref"]} if has_ref else {"absent": True}
            repos[layer][repo_name] = RepoEntry(
                name=repo_name,
                url=entry["url"],
                ref=entry["ref"],
                type=entry.get("type", "git"),
                distros=distros,
            )

    groups_raw = _require_dict(raw.get("groups", {}), f"{source}: groups")
    groups = {}
    for name, gval in groups_raw.items():
        gval = _require_dict(gval, f"{source}: groups.{name}")
        unknown_group_keys = set(gval) - _GROUP_KEYS
        if unknown_group_keys:
            raise ManifestError(
                f"{source}: groups.{name}: unknown key(s) {sorted(unknown_group_keys)}"
            )
        default = gval.get("default")
        if default not in ("include", "exclude"):
            raise ManifestError(
                f"{source}: groups.{name}: 'default' must be 'include' or 'exclude',"
                f" got {default!r}"
            )
        group_repos = _require_list_of_str(gval.get("repos", []), f"{source}: groups.{name}.repos")
        groups[name] = GroupEntry(name=name, default=default, repos=group_repos)

    roles_raw = _require_dict(raw.get("roles", {}), f"{source}: roles")
    roles = {}
    for name, rval in roles_raw.items():
        rval = _require_dict(rval, f"{source}: roles.{name}")
        unknown_role_keys = set(rval) - _ROLE_KEYS
        if unknown_role_keys:
            raise ManifestError(
                f"{source}: roles.{name}: unknown key(s) {sorted(unknown_role_keys)}"
            )
        subtract = _require_list_of_str(
            rval.get("subtract", []), f"{source}: roles.{name}.subtract"
        )
        add = _require_list_of_str(rval.get("add", []), f"{source}: roles.{name}.add")
        roots = rval.get("roots")
        if roots is not None:
            roots = _require_list_of_str(roots, f"{source}: roles.{name}.roots")
            if subtract or add:
                raise ManifestError(
                    f"{source}: roles.{name}: 'roots' (closure model) cannot be combined with"
                    " 'subtract'/'add' (groups model) on the same role"
                )
        roles[name] = RoleEntry(name=name, subtract=subtract, add=add, roots=roots)

    packages_raw = _require_dict(raw.get("packages", {}), f"{source}: packages")
    packages = {}
    for name, pval in packages_raw.items():
        pval = _require_dict(pval, f"{source}: packages.{name}")
        unknown_pkg_keys = set(pval) - _PACKAGE_KEYS
        if unknown_pkg_keys:
            raise ManifestError(
                f"{source}: packages.{name}: unknown key(s) {sorted(unknown_pkg_keys)}"
            )
        if "repo" not in pval:
            raise ManifestError(f"{source}: packages.{name}: missing 'repo'")
        depend = _require_list_of_str(pval.get("depend", []), f"{source}: packages.{name}.depend")
        exec_depend = _require_list_of_str(
            pval.get("exec_depend", []), f"{source}: packages.{name}.exec_depend"
        )
        packages[name] = PackageEntry(
            name=name, repo=pval["repo"], depend=depend, exec_depend=exec_depend
        )

    return Manifest(
        source=source,
        extends=extends_ref,
        layers=layers,
        repos=repos,
        groups=groups,
        roles=roles,
        packages=packages,
    )


def load_manifest_file(path: Path) -> Manifest:
    path = Path(path)
    if not path.is_file():
        raise ManifestError(f"manifest not found: {path}")
    return parse_manifest_text(path.read_text(), source=str(path))
