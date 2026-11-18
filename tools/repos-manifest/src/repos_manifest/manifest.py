"""Reading and checking one manifest in the format of ``docs/spec.md``.

This reads a manifest that stands on its own: one with a `base` is refused for now. It checks
everything "Reading a manifest before using it" in the specification says can be checked on
the text: the file is loaded as data, repo keys are relative paths with no `..` or `.git` part
and none inside another, names are single words, no layer has a reserved name, no `url`,
`version` or location `path` starts with `-`, a `url` uses a transport that only fetches, and
the file has no invisible or direction-changing character. The check on the real destination
(links, names the disk treats as the same) belongs to the commands that write there.

An error message may print a value from the manifest.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

from .yamlload import ManifestError, _load_yaml, _refuse_unsafe_chars, first_unsafe_in_text

FORMAT = 1

_TOP_LEVEL_KEYS = ("format", "base", "distros", "layers", "groups", "roles", "repositories")
_REPO_KEYS = ("type", "url", "version", "absent", "layer", "groups", "distros", "optional")
_DISTRO_ENTRY_KEYS = ("version", "absent")

# The name of a layer, a distro, a group or a role: a single word.
_NAME = re.compile(r"[A-Za-z][A-Za-z0-9_-]*")
_NAME_RULE = "a single word: letters, digits, '_' and '-', starting with a letter"

# The directories of the unnamed layer.
RESERVED_LAYERS = ("src", "build", "install", "log")

# The name of the unnamed first layer in the output; it starts with '_', which no name can.
UNNAMED_LAYER = "_unnamed"

# The transports a `url` may use: they only fetch.
_URL_SCHEMES = ("https://", "http://", "ssh://", "file://")
# git's scp-like form, `[user@]host:path`: a ':' before any '/'. The user, which may be left
# out (an ssh host alias), runs to the last '@' before the host; a host in brackets may hold
# ':' (an IPv6 address). A relative path on the local disk has a '/' before any ':', or no ':'.
_SCP_FORM = re.compile(r"(?:(?P<user>[^/:\[\]]*)@)?(?P<host>\[[^\]/]*\]|[^/:@\[\]]+):(?P<path>.+)")
# git's <transport>::<address> form: a word at the start, then '::'.
_TRANSPORT_FORM = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*::")
_URL_RULE = (
    "a url uses https, http, ssh, file, the [user@]host:path form or an absolute path on the"
    " local disk"
)


@dataclass
class DistroEntry:
    version: Optional[str] = None
    absent: bool = False


@dataclass
class Repo:
    key: str
    type: str
    url: str
    version: Optional[str] = None
    absent: bool = False
    layer: Optional[str] = None  # None: the unnamed first layer
    groups: List[str] = field(default_factory=list)
    distros: Optional[Dict[str, DistroEntry]] = None  # None: no `distros:` key
    optional: bool = False


@dataclass
class Manifest:
    """One manifest in the format of the specification, checked."""

    source: str  # how the manifest is named in messages and output: the location as given
    format: int
    distros: Optional[List[str]]  # None: no `distros:`, one unnamed variant
    layers: List[str]
    groups: List[str]
    roles: Optional[Dict[str, List[str]]]  # None: no `roles:`, one unnamed role
    repositories: Dict[str, Repo]  # in manifest order
    warnings: List[str] = field(default_factory=list)


def has_repositories_key(path: Path) -> bool:
    """True if the file reads, parses as YAML and is a mapping with a top-level `repositories:`
    key: a manifest in this format. Anything else, a file that does not read or parse
    included, is for the earlier reader."""
    try:
        data = _load_yaml(Path(path).read_text(encoding="utf-8"), str(path))
    except (ManifestError, OSError, UnicodeDecodeError, ValueError):
        return False
    return isinstance(data, dict) and "repositories" in data


def load_manifest(path: Path, source: Optional[str] = None) -> Manifest:
    """Read and check the manifest at `path`. `source` names it in messages (default: the path
    as given)."""
    label = source if source is not None else str(path)
    try:
        text = Path(path).read_text(encoding="utf-8")
    except FileNotFoundError:
        raise ManifestError(f"{label}: not found") from None
    except UnicodeDecodeError:
        raise ManifestError(f"{label}: cannot be read as UTF-8 text") from None
    except OSError as exc:
        raise ManifestError(f"{label}: cannot be read ({exc.strerror or 'an OS error'})") from None
    return parse_manifest(text, label)


def parse_manifest(text: str, source: str) -> Manifest:
    """Check one manifest's text and return it as a `Manifest`."""
    bad = first_unsafe_in_text(text)
    if bad:
        line, column, code = bad
        raise ManifestError(
            f"{source}: line {line}, column {column}: the file holds {code}, a control,"
            " invisible or direction-changing character; such characters can make a file read"
            " differently from what it does"
        )
    raw = _load_yaml(text, source)
    if not isinstance(raw, dict):
        raise ManifestError(f"{source}: a manifest is a mapping of keys at the top level")
    _refuse_unsafe_chars(raw, source, "")
    return _Checker(source).manifest(raw)


def _type_name(value) -> str:
    if value is None:
        return "nothing"
    if isinstance(value, bool):
        return "true or false"
    return {dict: "a mapping", list: "a list", str: "a string"}.get(
        type(value), f"a {type(value).__name__}"
    )


class _Checker:
    def __init__(self, source: str):
        self.source = source
        self.warnings: List[str] = []

    def error(self, where: str, what: str) -> ManifestError:
        return ManifestError(
            f"{self.source}: {where}: {what}" if where else f"{self.source}: {what}"
        )

    def warn(self, what: str) -> None:
        self.warnings.append(f"{self.source}: {what}")

    # --- values ---------------------------------------------------------------------------

    def string(self, value, where: str) -> str:
        if not isinstance(value, str):
            raise self.error(
                where,
                f"must be a string, got {_type_name(value)} ({value!r}); quote it in the YAML"
                " (unquoted, 1.10 is read as the number 1.1, yes as true)",
            )
        if value == "":
            raise self.error(where, "must not be empty")
        return value

    def boolean(self, value, where: str) -> bool:
        if not isinstance(value, bool):
            raise self.error(where, f"must be true or false, got {_type_name(value)}")
        return value

    def not_an_option(self, value: str, where: str) -> str:
        if value.startswith("-"):
            raise self.error(where, f"{value!r} starts with '-', which git would read as an option")
        return value

    def name(self, value, kind: str, where: str) -> str:
        if not isinstance(value, str) or not _NAME.fullmatch(value):
            raise self.error(where, f"{kind} name {value!r} is not allowed; a name is {_NAME_RULE}")
        return value

    def names(self, value, kind: str, where: str) -> List[str]:
        if not isinstance(value, list):
            raise self.error(where, f"must be a list of {kind} names, got {_type_name(value)}")
        seen: List[str] = []
        for index, item in enumerate(value):
            self.name(item, kind, f"{where}[{index}]")
            if item in seen:
                raise self.error(where, f"names {kind} {item!r} twice")
            seen.append(item)
        return seen

    def url(self, value, where: str) -> str:
        url = self.not_an_option(self.string(value, where), where)
        if _TRANSPORT_FORM.match(url):
            raise self.error(
                where, f"{url!r}: the <transport>::<address> form is refused; {_URL_RULE}"
            )
        scheme = next((s for s in _URL_SCHEMES if url.startswith(s)), None)
        if scheme is not None:
            # The authority runs to the first '/', '?' or '#'; the host follows its last '@'.
            authority = re.split(r"[/?#]", url[len(scheme) :], maxsplit=1)[0]
            user, _, host_port = authority.rpartition("@")
            if host_port.startswith("["):
                close = host_port.find("]")
                if close < 0:
                    raise self.error(where, f"{url!r}: the host has an unclosed '['")
                host, rest = host_port[1:close], host_port[close + 1 :]
                if rest and not rest.startswith(":"):
                    raise self.error(where, f"{url!r} is refused; {_URL_RULE}")
                port = rest[1:]
            else:
                host, _, port = host_port.partition(":")
            self.url_parts_not_options(url, where, user=user, host=host, port=port)
            return url
        if "://" not in url:
            scp = _SCP_FORM.fullmatch(url)
            if scp:
                host = scp.group("host")
                if host.startswith("["):
                    host = host[1:-1]
                self.url_parts_not_options(url, where, user=scp.group("user"), host=host)
                return url
        if url.startswith("/"):
            return url
        raise self.error(where, f"{url!r} is refused; {_URL_RULE}")

    def url_parts_not_options(self, url: str, where: str, **parts: Optional[str]) -> None:
        """No part of a url's authority starts with '-', where ssh would read it as an
        option."""
        for part, text in parts.items():
            if text and text.startswith("-"):
                raise self.error(where, f"{url!r}: the {part} starts with '-'")

    # --- the manifest ---------------------------------------------------------------------

    def manifest(self, raw: dict) -> Manifest:
        for key in raw:
            if key not in _TOP_LEVEL_KEYS:
                self.warn(f"unknown top-level key {key!r} is ignored")

        fmt = raw.get("format", FORMAT)
        if isinstance(fmt, bool) or not isinstance(fmt, int) or fmt < 1:
            raise self.error("format", f"must be a whole number from 1, got {fmt!r}")
        if fmt > FORMAT:
            raise self.error(
                "format", f"is {fmt}; this tool reads format {FORMAT} and earlier versions"
            )

        if "base" in raw:
            raise self.error("base", "this version of the tool cannot read `base` yet")

        distros = None
        if "distros" in raw:
            distros = self.names(raw["distros"], "distro", "distros")
            if not distros:
                raise self.error("distros", "is empty; leave it out for a manifest with no distros")

        layers = self.names(raw.get("layers", []), "layer", "layers")
        for layer in layers:
            if layer in RESERVED_LAYERS:
                raise self.error(
                    "layers",
                    f"a layer cannot be named {layer!r}; {', '.join(RESERVED_LAYERS)} are the"
                    " directories of the unnamed layer",
                )

        groups = self.names(raw.get("groups", []), "group", "groups")

        roles = None
        if "roles" in raw:
            roles_raw = raw["roles"]
            if not isinstance(roles_raw, dict):
                raise self.error(
                    "roles", f"must be a mapping of role names, got {_type_name(roles_raw)}"
                )
            roles = {}
            for role, role_groups in roles_raw.items():
                self.name(role, "role", "roles")
                where = f"roles.{role}"
                if not isinstance(role_groups, list):
                    raise self.error(
                        where,
                        f"must be a list of the groups it switches on ([] for none), got"
                        f" {_type_name(role_groups)}",
                    )
                roles[role] = self.declared_groups(role_groups, groups, where)

        if "repositories" not in raw:
            raise self.error("", "has no `repositories:`")
        repos_raw = raw["repositories"]
        if not isinstance(repos_raw, dict):
            raise self.error(
                "repositories", f"must be a mapping of repos, got {_type_name(repos_raw)}"
            )
        repositories: Dict[str, Repo] = {}
        for key, entry in repos_raw.items():
            repositories[key] = self.repo(key, entry, distros, layers, groups)
        self.no_key_inside_another(list(repositories))

        return Manifest(
            source=self.source,
            format=fmt,
            distros=distros,
            layers=layers,
            groups=groups,
            roles=roles,
            repositories=repositories,
            warnings=self.warnings,
        )

    def declared_groups(self, value, groups: List[str], where: str) -> List[str]:
        names = self.names(value, "group", where)
        for group in names:
            if group not in groups:
                raise self.error(
                    where, f"group {group!r} is not in the top-level `groups:` list {groups}"
                )
        return names

    def repo_key(self, key) -> str:
        if not isinstance(key, str) or key == "":
            raise self.error("repositories", f"a repo key must be a path, got {key!r}")
        where = f"repositories: {key!r}"
        if "\\" in key:
            raise self.error(where, "a repo key is a path with '/' between its parts, no '\\'")
        if key.startswith("/"):
            raise self.error(where, "a repo key is a relative path")
        if key.endswith("/") or "//" in key:
            raise self.error(where, "a repo key has no empty part (no '//', no '/' at the end)")
        for part in key.split("/"):
            if part in (".", "..", ".git"):
                raise self.error(where, f"a repo key has no {part!r} part")
        return key

    def no_key_inside_another(self, keys: List[str]) -> None:
        present = set(keys)
        for key in keys:
            parts = key.split("/")
            for end in range(1, len(parts)):
                outer = "/".join(parts[:end])
                if outer in present:
                    raise self.error(
                        f"repositories: {key!r}",
                        f"is inside repo {outer!r}; one repo is never cloned inside another",
                    )

    def repo(self, key, entry, distros, layers, groups) -> Repo:
        key = self.repo_key(key)
        where = f"repositories.{key}"
        if not isinstance(entry, dict):
            raise self.error(where, f"must be a mapping with type and url, got {_type_name(entry)}")
        for name in entry:
            if name not in _REPO_KEYS:
                self.warn(f"{where}: unknown key {name!r} is ignored and left out of the output")
        for required in ("type", "url"):
            if required not in entry:
                raise self.error(where, f"has no `{required}`")
        repo_type = self.string(entry["type"], f"{where}.type")
        if repo_type != "git":
            raise self.error(
                f"{where}.type",
                f"is {repo_type!r}; the format takes any type a .repos file takes, and these"
                " tools read git repos only",
            )
        repo = Repo(key=key, type=repo_type, url=self.url(entry["url"], f"{where}.url"))
        if "version" in entry:
            repo.version = self.not_an_option(
                self.string(entry["version"], f"{where}.version"), f"{where}.version"
            )
        if "absent" in entry:
            repo.absent = self.boolean(entry["absent"], f"{where}.absent")
        if "optional" in entry:
            repo.optional = self.boolean(entry["optional"], f"{where}.optional")
        if "layer" in entry:
            layer = self.name(entry["layer"], "layer", f"{where}.layer")
            if layer not in layers:
                raise self.error(
                    f"{where}.layer", f"{layer!r} is not in the top-level `layers:` list {layers}"
                )
            repo.layer = layer
        if "groups" in entry:
            repo.groups = self.declared_groups(entry["groups"], groups, f"{where}.groups")
        if "distros" in entry:
            if distros is None:
                raise self.error(
                    f"{where}.distros",
                    "the manifest has no top-level `distros:` list, so no repo may have"
                    " a `distros:` key",
                )
            repo.distros = self.repo_distros(entry["distros"], f"{where}.distros")
        return repo

    def repo_distros(self, value, where: str) -> Dict[str, DistroEntry]:
        if not isinstance(value, dict):
            raise self.error(where, f"must be a mapping of distro names, got {_type_name(value)}")
        result: Dict[str, DistroEntry] = {}
        for distro, entry in value.items():
            self.name(distro, "distro", where)
            entry_where = f"{where}.{distro}"
            if entry is None:  # `jazzy:` with nothing after it: an empty entry, which counts
                entry = {}
            if not isinstance(entry, dict):
                raise self.error(
                    entry_where,
                    f"must be a mapping with `version` or `absent`, got {_type_name(entry)}",
                )
            for name in entry:
                if name not in _DISTRO_ENTRY_KEYS:
                    self.warn(f"{entry_where}: unknown key {name!r} is ignored")
            distro_entry = DistroEntry()
            if "version" in entry:
                distro_entry.version = self.not_an_option(
                    self.string(entry["version"], f"{entry_where}.version"),
                    f"{entry_where}.version",
                )
            if "absent" in entry:
                distro_entry.absent = self.boolean(entry["absent"], f"{entry_where}.absent")
            if distro_entry.absent and distro_entry.version is not None:
                raise self.error(
                    entry_where, "gives both a `version` and `absent: true`; give one of them"
                )
            result[distro] = distro_entry
        return result
