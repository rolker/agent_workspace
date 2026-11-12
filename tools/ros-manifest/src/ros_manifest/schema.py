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
# text, at most _NAME_MAX characters. Group names also allow `:` (`hw:deltat`); nothing else
# needs more. Two names of one kind that differ only in case are refused: on a case-insensitive
# disk one file or checkout would overwrite the other.
_NAME_MAX = 64
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

# URLs: an ALLOW-LIST. A `url` (a repository's, or `extends.url`) is accepted only if one of
# these anchored patterns matches it whole; everything else is refused, and the message lists
# these shapes without echoing the value. No shape has a place for a password, a token, a
# query, a fragment, git's `<transport>::` form, whitespace, or a leading `-` anywhere.
_HOST = r"[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?"
_PORT = r"(?::[0-9]{1,5})?"
_USER = r"[A-Za-z0-9_][A-Za-z0-9_.-]*"  # a plain ssh user name, such as `git`: not a secret
_PATH = r"[A-Za-z0-9_][A-Za-z0-9_./-]*"
_URL_SHAPES = (
    ("https://<host>[:port]/<path>", re.compile(rf"https://{_HOST}{_PORT}/{_PATH}")),
    ("ssh://<user>@<host>[:port]/<path>", re.compile(rf"ssh://{_USER}@{_HOST}{_PORT}/{_PATH}")),
    ("<user>@<host>:<path>", re.compile(rf"{_USER}@{_HOST}:{_PATH}")),
    # For local and test use: a bare clone on this machine.
    ("file:///<absolute path>", re.compile(rf"file:///{_PATH}")),
)
_URL_REFUSED = (
    "is not one of the accepted URL shapes: "
    + ", ".join(shape for shape, _ in _URL_SHAPES)
    + " (host, user and path are letters, digits, '.', '_' and '-', and '/' in a path; none"
    " starts with '-'; no query or fragment). Credentials do not belong in a manifest; use a"
    " credential helper or an ssh remote"
)

# A ref (a repository's `ref`, each per-distro `ref`, `extends.ref`): a branch, tag or commit
# name. It cannot start with `-`, so it cannot be read as a git option.
_REF = re.compile(r"[A-Za-z0-9][A-Za-z0-9._/-]*")
_REF_RULE = (
    "a ref is letters, digits, '.', '_', '/' and '-', starting with a letter or digit, with no"
    " '..' and not ending in '/' or '.lock'"
)

# Characters no key or value may hold: control characters (newline, carriage return, tab, NUL,
# DEL, NEL, ...), line and paragraph separators, invisible format characters (zero-width
# spaces, the byte-order mark, bidirectional overrides such as U+202E) and any space other than
# the ASCII one (no-break space and friends).
_UNSAFE_CATEGORIES = ("Cc", "Cf", "Zl", "Zp")


def has_unsafe_char(text: str) -> bool:
    """True if `text` holds a character that can split a line or hide what a line says."""
    return any(
        unicodedata.category(ch) in _UNSAFE_CATEGORIES
        or (unicodedata.category(ch) == "Zs" and ch != " ")
        for ch in text
    )


_UNSAFE_WHAT = (
    "a control or invisible character (newline, carriage return, a zero-width or bidirectional"
    " character, a non-ASCII space or similar)"
)


class _RefusedYAML(yaml.YAMLError):
    """A YAML construct this loader refuses. `reason` is fixed text, never document content."""

    def __init__(self, reason: str, mark):
        super().__init__(reason)
        self.reason = reason
        self.problem_mark = mark


class _ManifestLoader(yaml.SafeLoader):
    """`yaml.SafeLoader` that refuses aliases (no recursion, no alias bombs; manifests do not
    need them) and duplicate mapping keys (a reader would see one entry, the resolver use the
    other)."""

    def compose_node(self, parent, index):
        if self.check_event(yaml.AliasEvent):
            raise _RefusedYAML("aliases (*name) are not allowed", self.peek_event().start_mark)
        return super().compose_node(parent, index)

    def construct_mapping(self, node, deep=False):
        if isinstance(node, yaml.MappingNode):
            seen = set()
            for key_node, _ in node.value:
                key = self.construct_object(key_node, deep=True)
                try:
                    if key in seen:
                        raise _RefusedYAML("a mapping repeats a key", key_node.start_mark)
                    seen.add(key)
                except TypeError:
                    continue  # an unhashable key: the base class refuses it
        return super().construct_mapping(node, deep)


def _load_yaml(text: str, source: str):
    """Load one document. A failure is reported with fixed text and a position only: PyYAML's
    own messages quote document content (a line, a tag), which may hold a secret."""
    try:
        return yaml.load(text, Loader=_ManifestLoader)  # noqa: S506 (a SafeLoader subclass)
    except _RefusedYAML as exc:
        mark = exc.problem_mark
        raise ManifestError(
            f"{source}: invalid YAML at line {mark.line + 1}, column {mark.column + 1}:"
            f" {exc.reason}"
        ) from None
    except yaml.YAMLError as exc:
        mark = getattr(exc, "problem_mark", None)
        where = f" at line {mark.line + 1}, column {mark.column + 1}" if mark else ""
        raise ManifestError(f"{source}: invalid YAML{where}") from None
    except RecursionError:
        raise ManifestError(f"{source}: invalid YAML: nested too deeply") from None
    except Exception:
        # PyYAML's constructor lets Python's own errors through, not as a YAMLError: `!!float x`
        # and `!!int 0xx` raise ValueError, `!!bool x` KeyError, `2024-13-45` ValueError. Their
        # text quotes the value, and so would a traceback.
        raise ManifestError(f"{source}: invalid YAML") from None


def _refuse_unsafe_chars(node, source: str, where: str) -> None:
    """Every string in the document, key or value, must be one line of plain text. The message
    names where the string is and never echoes it (it may be a URL that carries a secret)."""
    if isinstance(node, dict):
        for key, value in node.items():
            if isinstance(key, str) and has_unsafe_char(key):
                raise ManifestError(
                    f"{source}: a key under {where or 'the top level'} contains {_UNSAFE_WHAT};"
                    " names must be one line of plain text"
                )
            _refuse_unsafe_chars(value, source, f"{where}.{key}" if where else str(key))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            _refuse_unsafe_chars(value, source, f"{where}[{index}]")
    elif isinstance(node, str) and has_unsafe_char(node):
        raise ManifestError(
            f"{source}: {where} contains {_UNSAFE_WHAT}; values must be one line of plain text"
        )


def _check_name(kind: str, name, source: str, where: str) -> None:
    pattern, allowed = _NAME_RULES[kind]
    if isinstance(name, str) and pattern.fullmatch(name) and len(name) <= _NAME_MAX:
        return
    quote_hint = "" if isinstance(name, str) else " (quote it in the YAML)"
    shown = repr(name) if not isinstance(name, str) or len(name) <= _NAME_MAX else "(too long)"
    raise ManifestError(
        f"{source}: {where}: {kind} name {shown} is not allowed{quote_hint}; a {kind} name"
        f" is {allowed}, at most {_NAME_MAX} characters"
    )


def refuse_case_twins(names, kind: str, source: str) -> None:
    """Refuse two names of one kind that differ only in case. Used per manifest here, and
    across the composed chain in ``merge.py``."""
    by_fold: dict = {}
    for name in names:
        other = by_fold.setdefault(name.casefold(), name)
        if other != name:
            raise ManifestError(
                f"{source}: {kind} names {other!r} and {name!r} differ only in case; on a"
                " case-insensitive disk one would overwrite the other"
            )


def _require_str(value, source: str, where: str) -> str:
    if not isinstance(value, str):
        raise ManifestError(
            f"{source}: {where} must be a string, got {type(value).__name__}; quote it in the"
            " YAML (unquoted, 1.10 is read as the number 1.1, yes as true, 2024-01-01 as a date)"
        )
    return value


def _check_url(url: str, source: str, where: str) -> None:
    """Accept `url` only if one shape of the allow-list matches it whole. Never echoes it."""
    if not any(pattern.fullmatch(url) for _, pattern in _URL_SHAPES):
        raise ManifestError(f"{source}: {where} {_URL_REFUSED}")


def _check_ref(ref: str, source: str, where: str) -> None:
    if not _REF.fullmatch(ref) or ".." in ref or ref.endswith(("/", ".lock")):
        raise ManifestError(f"{source}: {where} is not an accepted ref; {_REF_RULE}")


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
    raw = _load_yaml(text, source)
    if raw is None:
        raw = {}
    raw = _require_dict(raw, source)
    unknown = set(raw) - _TOP_LEVEL_KEYS
    if unknown:
        raise ManifestError(
            f"{source}: unknown top-level key(s): {sorted(repr(k) for k in unknown)}"
        )
    _refuse_unsafe_chars(raw, source, "")

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
            _check_url(ext["url"], source, "extends.url")
            _check_ref(ext["ref"], source, "extends.ref")
        extends_ref = ExtendsRef(path=ext["path"], url=ext.get("url"), ref=ext.get("ref"))

    layers = _require_list_of_str(raw.get("layers", []), f"{source}: layers")
    if not layers:
        raise ManifestError(f"{source}: layers must be a non-empty list")
    for index, layer in enumerate(layers):
        _check_name("layer", layer, source, f"layers[{index}]")
    if len(set(layers)) != len(layers):
        raise ManifestError(f"{source}: layers contains duplicates: {layers}")
    refuse_case_twins(layers, "layer", source)

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
                    f" {sorted(unknown_repo_keys, key=repr)}"
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
            _check_url(entry["url"], source, f"{where}.url")
            _check_ref(entry["ref"], source, f"{where}.ref")
            distros_raw = _require_dict(
                entry.get("distros", {}), f"{source}: repos.{layer}.{repo_name}.distros"
            )
            distros = {}
            for distro, dval in distros_raw.items():
                _check_name("distro", distro, source, f"{where}.distros")
                dval = _require_dict(dval, f"{source}: repos.{layer}.{repo_name}.distros.{distro}")
                if "ref" in dval:
                    _require_str(dval["ref"], source, f"{where}.distros.{distro}.ref")
                    _check_ref(dval["ref"], source, f"{where}.distros.{distro}.ref")
                if "absent" in dval and not isinstance(dval["absent"], bool):
                    raise ManifestError(
                        f"{source}: {where}.distros.{distro}.absent must be true or false"
                        f" (a YAML boolean), got {type(dval['absent']).__name__}"
                    )
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

    refuse_case_twins(
        [name for layer_repos in repos.values() for name in layer_repos], "repository", source
    )

    groups_raw = _require_dict(raw.get("groups", {}), f"{source}: groups")
    groups = {}
    for name, gval in groups_raw.items():
        _check_name("group", name, source, "groups")
        gval = _require_dict(gval, f"{source}: groups.{name}")
        unknown_group_keys = set(gval) - _GROUP_KEYS
        if unknown_group_keys:
            raise ManifestError(
                f"{source}: groups.{name}: unknown key(s) {sorted(unknown_group_keys, key=repr)}"
            )
        default = gval.get("default")
        if default not in ("include", "exclude"):
            raise ManifestError(
                f"{source}: groups.{name}: 'default' must be 'include' or 'exclude',"
                f" got {default!r}"
            )
        group_repos = _require_list_of_str(gval.get("repos", []), f"{source}: groups.{name}.repos")
        groups[name] = GroupEntry(name=name, default=default, repos=group_repos)

    refuse_case_twins(groups, "group", source)

    roles_raw = _require_dict(raw.get("roles", {}), f"{source}: roles")
    roles = {}
    for name, rval in roles_raw.items():
        _check_name("role", name, source, "roles")
        rval = _require_dict(rval, f"{source}: roles.{name}")
        unknown_role_keys = set(rval) - _ROLE_KEYS
        if unknown_role_keys:
            raise ManifestError(
                f"{source}: roles.{name}: unknown key(s) {sorted(unknown_role_keys, key=repr)}"
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

    refuse_case_twins(roles, "role", source)

    packages_raw = _require_dict(raw.get("packages", {}), f"{source}: packages")
    packages = {}
    for name, pval in packages_raw.items():
        pval = _require_dict(pval, f"{source}: packages.{name}")
        unknown_pkg_keys = set(pval) - _PACKAGE_KEYS
        if unknown_pkg_keys:
            raise ManifestError(
                f"{source}: packages.{name}: unknown key(s) {sorted(unknown_pkg_keys, key=repr)}"
            )
        if "repo" not in pval:
            raise ManifestError(f"{source}: packages.{name}: missing 'repo'")
        # Unchecked, a list here reached merge.py as a dict key: a TypeError and a traceback.
        _require_str(pval["repo"], source, f"packages.{name}.repo")
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
