"""Manifest YAML loading and structural (single-file) validation.

Cross-manifest validation (does a group reference a repo that actually exists anywhere in the
extends chain, does an extension try to remove/re-version a base repo) happens in ``merge.py``
after the whole chain is loaded — a single manifest file is allowed to reference repos defined
only in a base it extends.

A manifest, and every manifest it `extends`, is untrusted input: its names become file paths
and its values become lines of generated files a consumer trusts. The rules that keep it from
breaking out of either are all here, at parse time (see "Untrusted-input rules" below); the
emitter refuses anything that reached it by another route.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional
from urllib.parse import urlsplit

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

    source: str  # human-readable provenance label (file path, or url#ref:path@<commit>)
    extends: Optional[ExtendsRef]
    layers: list
    optional_layers: list  # subset of `layers` whose fetch/build may fail without aborting
    repos: dict  # layer -> {repo_name: RepoEntry}
    groups: dict  # name -> GroupEntry
    roles: dict  # name -> RoleEntry
    packages: dict  # name -> PackageEntry


_TOP_LEVEL_KEYS = {
    "extends",
    "layers",
    "optional_layers",
    "repos",
    "groups",
    "roles",
    "packages",
}
_REPO_KEYS = {"url", "ref", "type", "distros"}
_GROUP_KEYS = {"default", "repos"}
_ROLE_KEYS = {"subtract", "add", "roots"}
_PACKAGE_KEYS = {"repo", "depend", "exec_depend"}


# --- Untrusted-input rules -------------------------------------------------------------------
#
# Names become file paths (`<layer>.repos`, the checkout directory `vcs import` makes for a
# repository) and lines of `layers.txt` / `optional_layers.txt` / `.repos` headers, so each
# kind of name has a strict pattern: no `/`, no leading `.` or `#`, nothing that is not plain
# text. Group names also allow `:` (`hw:deltat`); nothing else needs more.
_NAME_RULES = {
    # The ros2_colcon adapter's own rule for a layer name.
    "layer": (re.compile(r"[A-Za-z0-9_-]+"), "letters, digits, '_' and '-'"),
    "repository": (
        re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]*"),
        "letters, digits, '_', '.' and '-', not starting with '.' or '-'",
    ),
    "group": (
        re.compile(r"[A-Za-z0-9_][A-Za-z0-9_:-]*"),
        "letters, digits, '_', ':' and '-', not starting with ':' or '-'",
    ),
    "role": (
        re.compile(r"[A-Za-z0-9_][A-Za-z0-9_-]*"),
        "letters, digits, '_' and '-', not starting with '-'",
    ),
    "distro": (re.compile(r"[a-z][a-z0-9_]*"), "lower-case letters, digits and '_'"),
}

# An ssh remote names a user (`ssh://git@host/...`, `git@host:path`); that is not a secret.
_SSH_SCHEMES = {"ssh", "git+ssh", "ssh+git"}
_SSH_USER = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]*")
_CREDENTIALS_REFUSED = (
    "credentials do not belong in a manifest; use a credential helper or an ssh remote"
)


def has_control_char(text: str) -> bool:
    """True if `text` holds a control character (newline, carriage return, tab, NUL, DEL, ...)
    or a Unicode line or paragraph separator: anything that can end or split a line."""
    return any(unicodedata.category(ch) in ("Cc", "Zl", "Zp") for ch in text)


def _refuse_control_chars(node, source: str, where: str) -> None:
    """Every string in the document, key or value, must be single-line text. The message names
    where the string is and never echoes it (it may be a URL that carries a secret)."""
    if isinstance(node, dict):
        for key, value in node.items():
            if isinstance(key, str) and has_control_char(key):
                raise ManifestError(
                    f"{source}: a key under {where or 'the top level'} contains a control"
                    " character (newline, carriage return or similar); names must be one line"
                    " of plain text"
                )
            _refuse_control_chars(value, source, f"{where}.{key}" if where else str(key))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            _refuse_control_chars(value, source, f"{where}[{index}]")
    elif isinstance(node, str) and has_control_char(node):
        raise ManifestError(
            f"{source}: {where} contains a control character (newline, carriage return or"
            " similar); values must be one line of plain text"
        )


def _check_name(kind: str, name, source: str, where: str) -> None:
    pattern, allowed = _NAME_RULES[kind]
    if isinstance(name, str) and pattern.fullmatch(name):
        return
    quote_hint = "" if isinstance(name, str) else " (quote it in the YAML)"
    raise ManifestError(
        f"{source}: {where}: {kind} name {name!r} is not allowed{quote_hint}; a {kind} name"
        f" is {allowed}"
    )


def _require_str(value, source: str, where: str) -> str:
    if not isinstance(value, str):
        raise ManifestError(
            f"{source}: {where} must be a string, got {type(value).__name__}; quote it in the"
            " YAML (unquoted, 1.10 is read as the number 1.1, yes as true, 2024-01-01 as a date)"
        )
    return value


def _refuse_credentials(url: str, source: str, where: str) -> None:
    """Refuse a URL whose userinfo may carry a secret, without ever echoing the URL.

    Allowed: no userinfo at all (`https://host/path`, `file:///path`, a local path), and a
    plain user name on an ssh remote (`ssh://git@host/path`, scp-style `git@host:path`).
    Refused: a password or token after a colon in the userinfo, in any form; and any userinfo
    on a non-ssh URL (`https://<token>@host/...` is how a token is usually written there)."""
    try:
        if "://" in url:
            parts = urlsplit(url)
            if not parts.scheme:
                raise ManifestError(f"{source}: {where} has '://' but no valid scheme before it")
            ssh = parts.scheme.lower() in _SSH_SCHEMES
            # A `#` or `?` inside the userinfo ends the authority early, leaving the rest
            # (password and `@host`) in the fragment or query: fail closed.
            hidden = "@" in parts.query or "@" in parts.fragment
        else:
            head = url.split("/", 1)[0]
            userinfo, at_sign, _ = head.rpartition("@")
            if ":" not in head or not at_sign:
                return  # a local path, or scp-style `host:path` with no user
            # scp-style `[user@]host:path`: git's short form of ssh://[user@]host/path.
            parts = urlsplit(f"ssh://{userinfo}@host")
            ssh = True
            hidden = parts.hostname != "host"  # same early end, as above
        username, password = parts.username, parts.password
    except ValueError:
        raise ManifestError(f"{source}: {where} cannot be parsed as a URL") from None
    if hidden or password is not None:
        raise ManifestError(f"{source}: {where}: {_CREDENTIALS_REFUSED}")
    if username is not None and not (ssh and _SSH_USER.fullmatch(username)):
        raise ManifestError(f"{source}: {where}: {_CREDENTIALS_REFUSED}")


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
        # Position and problem only: PyYAML's own message quotes the offending line, which may
        # hold a URL that carries a secret.
        mark = getattr(exc, "problem_mark", None)
        where = f" at line {mark.line + 1}, column {mark.column + 1}" if mark else ""
        problem = getattr(exc, "problem", None) or type(exc).__name__
        raise ManifestError(f"{source}: invalid YAML{where}: {problem}") from None
    if raw is None:
        raw = {}
    raw = _require_dict(raw, source)
    _refuse_control_chars(raw, source, "")

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
        for key in ("path", "url", "ref"):
            if key in ext:
                _require_str(ext[key], source, f"extends.{key}")
        if "url" in ext:
            _refuse_credentials(ext["url"], source, "extends.url")
        extends_ref = ExtendsRef(path=ext["path"], url=ext.get("url"), ref=ext.get("ref"))

    layers = _require_list_of_str(raw.get("layers", []), f"{source}: layers")
    if not layers:
        raise ManifestError(f"{source}: layers must be a non-empty list")
    for index, layer in enumerate(layers):
        _check_name("layer", layer, source, f"layers[{index}]")
    if len(set(layers)) != len(layers):
        raise ManifestError(f"{source}: layers contains duplicates: {layers}")

    optional_layers = _require_list_of_str(
        raw.get("optional_layers", []), f"{source}: optional_layers"
    )
    if len(set(optional_layers)) != len(optional_layers):
        raise ManifestError(f"{source}: optional_layers contains duplicates: {optional_layers}")
    for layer in optional_layers:
        if layer not in layers:
            raise ManifestError(
                f"{source}: optional_layers names '{layer}', which is not in this manifest's own"
                f" 'layers' list {layers}"
            )

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
            _check_name("repository", repo_name, source, f"repos.{layer}")
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
            where = f"repos.{layer}.{repo_name}"
            for key in ("url", "ref", "type"):
                if key in entry:
                    _require_str(entry[key], source, f"{where}.{key}")
            _refuse_credentials(entry["url"], source, f"{where}.url")
            distros_raw = _require_dict(
                entry.get("distros", {}), f"{source}: repos.{layer}.{repo_name}.distros"
            )
            distros = {}
            for distro, dval in distros_raw.items():
                _check_name("distro", distro, source, f"{where}.distros")
                dval = _require_dict(dval, f"{source}: repos.{layer}.{repo_name}.distros.{distro}")
                if "ref" in dval:
                    _require_str(dval["ref"], source, f"{where}.distros.{distro}.ref")
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
        _check_name("group", name, source, "groups")
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
        _check_name("role", name, source, "roles")
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
        optional_layers=optional_layers,
        repos=repos,
        groups=groups,
        roles=roles,
        packages=packages,
    )


def load_manifest_file(path: Path, source: Optional[str] = None) -> Manifest:
    """Load one manifest file. `source` is its provenance label; it defaults to the file path
    (a git-backed `extends` base passes `url#ref:path@<commit>` instead, see ``extends.py``)."""
    path = Path(path)
    if not path.is_file():
        raise ManifestError(f"manifest not found: {path}")
    return parse_manifest_text(path.read_text(), source=source if source else str(path))
