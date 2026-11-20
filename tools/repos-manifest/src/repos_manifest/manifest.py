"""Reading and checking each manifest of the format of ``docs/spec.md`` on its own.

Each manifest is read as a `Part` that keeps only the keys it gives, so that a later manifest
can be merged over an earlier one key by key (``combine.py``); ``base.py`` reads a manifest and
the manifests it builds on. Here is everything "Reading a manifest before using it" in the
specification says can be checked on the text of one file: the file is loaded as data, repo
keys are relative paths with no `..` or `.git` part, names are single words, no layer has a
reserved name, no `url` or `version` starts with `-`, a `url` uses a transport that only
fetches, and the file has no invisible or direction-changing character. The checks that read
the combination of a chain (a repo is complete, its layer and groups are declared, no repo key
is inside another, no two layer names differ only in case) are in ``combine.py``. The check on
the real destination (links, names the disk treats as the same) belongs to the commands that
write there.

An error message may print a value from the manifest.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from .yamlload import ManifestError, _load_yaml, _refuse_unsafe_chars, first_unsafe_in_text
from .masking import quoted_url, remember_url, type_name

FORMAT = 1

_TOP_LEVEL_KEYS = ("format", "base", "distros", "layers", "groups", "roles", "repositories")
_REPO_KEYS = ("type", "url", "version", "absent", "layer", "groups", "distros", "optional")
_DISTRO_ENTRY_KEYS = ("version", "absent")
# Top-level keys of the earlier format that this one does not have.
_EARLIER_FORMAT_KEYS = ("repos", "extends", "optional_layers", "packages")

_BASE_PATH_ONLY = (
    "this version of the tool reads a location in `base` given as a path only, not yet an"
    " http or https URL or a file in a git repo"
)

# The name of a layer, a distro, a group or a role: a single word.
_NAME = re.compile(r"[A-Za-z][A-Za-z0-9_-]*")
_NAME_RULE = "a single word: letters, digits, '_' and '-', starting with a letter"

# The directories of the unnamed layer.
RESERVED_LAYERS = ("src", "build", "install", "log")

# The name of the unnamed first layer in the output; it starts with '_', which no name can.
UNNAMED_LAYER = "_unnamed"

# The transports a `url` may use: they only fetch.
_URL_SCHEMES = ("https://", "http://", "ssh://", "file://")
# git's <transport>::<address> form: a word at the start, then '::'.
_TRANSPORT_FORM = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*::")
_URL_RULE = (
    "a url uses https, http, ssh, file, the [user@]host:path form or an absolute path on the"
    " local disk"
)


def _colon_before_slash(text: str) -> bool:
    """A ':' before the first '/' (or with no '/') makes `text` a URL, not a path: a scheme, or
    git's `[user@]host:path` form. `./a:b` is a path."""
    colon = text.find(":")
    return colon >= 0 and "/" not in text[:colon]


def _bracketed_host(address: str) -> Optional[Tuple[int, int]]:
    """Where the '[' and the ']' of a host in brackets are in `address`: a '[' at the start, or
    after a user and an '@' (a user with no '/' or ':'), and the first ']' after it. None when
    the address does not start that way."""
    start = address.find("[")
    if start < 0:
        return None
    user = address[:start]
    if user and (not user.endswith("@") or "/" in user or ":" in user):
        return None
    close = address.find("]", start + 1)
    return None if close < 0 else (start, close)


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
    bases: List[str] = field(default_factory=list)  # the manifests it builds on, in reading order


@dataclass
class Part:
    """One manifest as read, checked on its own, with only the keys it gives. A repo entry is
    the mapping of the keys it gives to their checked values (`distros` to a mapping of
    `DistroEntry`)."""

    source: str  # how the manifest is named in messages
    format: int
    base: List[Tuple[str, str]]  # (where in the manifest, the path as written)
    distros: Optional[List[str]]  # None: not given
    layers: List[str]
    groups: List[str]
    roles: Optional[Dict[str, List[str]]]  # None: not given
    repos: Dict[str, Dict[str, object]]  # in manifest order
    warnings: List[str] = field(default_factory=list)


def has_repositories_key(path: Path) -> bool:
    """True if the file reads, parses as YAML and is a mapping with a top-level `repositories:`
    or `base:` key: a manifest in this format (one that builds on others may give no repos).
    Anything else, a file that does not read or parse included, is for the earlier reader."""
    try:
        data = _load_yaml(Path(path).read_text(encoding="utf-8"), str(path))
    except (ManifestError, OSError, UnicodeDecodeError, ValueError):
        return False
    return isinstance(data, dict) and ("repositories" in data or "base" in data)


def read_problem(path: Path, source: Optional[str] = None) -> Optional[str]:
    """Why the file at `path` cannot be read or parsed as YAML, as an error message; None if it
    can be. Says nothing about whether it is a valid manifest."""
    label = source if source is not None else str(path)
    try:
        _load_yaml(_read_text(Path(path), label), label)
    except ManifestError as exc:
        return str(exc)
    return None


def _read_text(path: Path, label: str) -> str:
    # newline="": the text as it is on the disk, so a carriage return is not turned into a
    # newline before the check on the text sees it.
    try:
        with open(path, encoding="utf-8", newline="") as file:
            return file.read()
    except FileNotFoundError:
        raise ManifestError(f"{label}: not found") from None
    except UnicodeDecodeError:
        raise ManifestError(f"{label}: cannot be read as UTF-8 text") from None
    except OSError as exc:
        raise ManifestError(f"{label}: cannot be read ({exc.strerror or 'an OS error'})") from None


def parse_part(text: str, source: str) -> Part:
    """Check one manifest's text on its own and return it as a `Part`."""
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
    return _Checker(source).part(raw)


# A value of the wrong type is described by its kind, never shown: a url inside it would not
# be masked.
_type_name = type_name


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
                f"must be a string, got {_type_name(value)}; quote it in the YAML (unquoted,"
                " 1.10 is read as the number 1.1, yes as true)",
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
            raise self.error(
                where, f"{quoted_url(value)} starts with '-', which git would read as an option"
            )
        return value

    def version(self, value, where: str) -> str:
        """A version that git cannot read as an option, as given or as vcstool passes it: it
        takes a leading `heads/` or `tags/` off and checks out the rest, which is not empty."""
        version = self.not_an_option(self.string(value, where), where)
        for prefix in ("heads/", "tags/"):
            if version == prefix:
                raise self.error(
                    where,
                    f"{quoted_url(version)} names nothing after {quoted_url(prefix)}, which vcstool"
                    " takes off",
                )
            if version.startswith(prefix) and version[len(prefix) :].startswith("-"):
                raise self.error(
                    where,
                    f"{quoted_url(version)} starts with '-' after {quoted_url(prefix)}, which"
                    " vcstool takes off; git would read the rest as an option",
                )
        return version

    def name(self, value, kind: str, where: str) -> str:
        if not isinstance(value, str) or not _NAME.fullmatch(value):
            raise self.error(
                where, f"{kind} name {quoted_url(value)} is not allowed; a name is {_NAME_RULE}"
            )
        return value

    def names(self, value, kind: str, where: str) -> List[str]:
        if not isinstance(value, list):
            raise self.error(where, f"must be a list of {kind} names, got {_type_name(value)}")
        seen: List[str] = []
        for index, item in enumerate(value):
            self.name(item, kind, f"{where}[{index}]")
            if item in seen:
                raise self.error(where, f"names {kind} {quoted_url(item)} twice")
            seen.append(item)
        return seen

    def url(self, value, where: str) -> str:
        remember_url(value)  # before any message that quotes it
        url = self.not_an_option(self.string(value, where), where)
        if _TRANSPORT_FORM.match(url):
            raise self.error(
                where, f"{quoted_url(url)}: the <transport>::<address> form is refused; {_URL_RULE}"
            )
        scheme = next((s for s in _URL_SCHEMES if url.startswith(s)), None)
        if scheme is not None:
            rest = url[len(scheme) :]
            if scheme == "ssh://":
                brackets = self.ssh_address(url, rest, where)
                # As git reads it, the part with the user, host and port runs to the first
                # '/' after the host; not to a '?' or a '#'.
                slash = rest.find("/", brackets[1] + 1 if brackets else 0)
                if slash < 0:
                    raise self.error(
                        where, f"{quoted_url(url)}: an ssh url has no path after the host"
                    )
            else:
                # Not handed to ssh: the user, host and port run to the first '/', and a '%',
                # '[' or ']' after it is the path's business.
                slash = rest.find("/")
            authority = rest if slash < 0 else rest[:slash]
            self.authority(
                url, authority, _bracketed_host(authority), where, ssh=scheme == "ssh://"
            )
            return url
        if "://" not in url and _colon_before_slash(url):
            # git's scp-like form, `[user@]host:path`: the host ends at the first ':' after it.
            brackets = self.ssh_address(url, url, where)
            sep = url.find(":", brackets[1] + 1 if brackets else 0)
            if sep <= 0 or sep == len(url) - 1:
                raise self.error(where, f"{quoted_url(url)} is refused; {_URL_RULE}")
            self.authority(url, url[:sep], brackets, where, ssh=True)
            if url[sep + 1] == "-":
                # git refuses such a path ("strange pathname") rather than hand it to ssh.
                raise self.error(where, f"{quoted_url(url)}: the path starts with '-'")
            return url
        # No ':', or a '/' before the first ':': a path on the local disk.
        if url.startswith("/"):
            return url
        raise self.error(where, f"{quoted_url(url)} is refused; {_URL_RULE}")

    def ssh_address(self, url: str, address: str, where: str) -> Optional[Tuple[int, int]]:
        """Check an address git hands to ssh (after `ssh://`, or the scp form), and return
        where the brackets of its host are. git decodes '%' escapes in it and looks for a host
        in brackets anywhere in it, so neither is allowed outside the host: no '%' at all, and
        a '[' and a ']' only as one pair around the host at the start of the address."""
        if "%" in url:
            raise self.error(where, f"{quoted_url(url)}: a '%' in an ssh address is refused")
        brackets = _bracketed_host(address)
        allowed = brackets or ()
        for index, char in enumerate(address):
            if char in "[]" and index not in allowed:
                raise self.error(
                    where,
                    f"{quoted_url(url)}: in an ssh address, '[' and ']' are allowed only around"
                    " the host",
                )
        return brackets

    def authority(
        self,
        url: str,
        text: str,
        brackets: Optional[Tuple[int, int]],
        where: str,
        *,
        ssh: bool,
    ) -> None:
        """Check the user, host and port in `text`, the part of a url before the path, with
        `brackets` where the brackets of its host are: no '%' (git decodes it in a url with
        '://', so a '%2d' would be a '-'), and none starts with '-', where ssh would read it as
        an option. In an address handed to ssh (`ssh`), the host is not empty."""
        if "%" in text:
            raise self.error(
                where, f"{quoted_url(url)}: a '%' in the user, host or port is refused"
            )
        if brackets:
            start, close = brackets
            outer_user, inner, rest = (
                text[: max(start - 1, 0)],
                text[start + 1 : close],
                text[close + 1 :],
            )
            if rest and not rest.startswith(":"):
                raise self.error(where, f"{quoted_url(url)} is refused; {_URL_RULE}")
            # Inside the brackets, ssh still reads a user before the last '@', and git a port
            # after a ':'.
            user, _, host_port = inner.rpartition("@")
            host = host_port
            parts = [
                ("user", outer_user),
                ("user", user),
                ("host", host),
                ("port", host_port.partition(":")[2]),
                ("port", rest[1:]),
            ]
        else:
            user, _, host_port = text.rpartition("@")
            host, _, port = host_port.partition(":")
            parts = [("user", user), ("host", host), ("port", port)]
        if ssh and not host:
            raise self.error(where, f"{quoted_url(url)}: the host is empty")
        for part, value in parts:
            if value.startswith("-"):
                raise self.error(where, f"{quoted_url(url)}: the {part} starts with '-'")

    # --- one manifest, as read -------------------------------------------------------------

    def part(self, raw: dict) -> Part:
        """Check everything that can be checked on this manifest alone, and keep only the keys
        it gives. The checks that read the combination of a chain are in ``combine.py``."""
        if "repositories" not in raw:
            # Before anything else: the earlier format's other keys have other shapes too.
            old = [key for key in _EARLIER_FORMAT_KEYS if key in raw]
            if old:
                raise self.error(
                    "",
                    f"is in the earlier format (it has {', '.join(f'`{k}:`' for k in old)} and no"
                    " `repositories:`); this tool reads it only in the format of the"
                    " specification",
                )

        for key in raw:
            if key not in _TOP_LEVEL_KEYS:
                self.warn(f"unknown top-level key {quoted_url(key)} is ignored")

        fmt = raw.get("format", FORMAT)
        if isinstance(fmt, bool) or not isinstance(fmt, int) or fmt < 1:
            shown = fmt if isinstance(fmt, int) and not isinstance(fmt, bool) else _type_name(fmt)
            raise self.error("format", f"must be a whole number from 1, got {shown}")
        if fmt > FORMAT:
            raise self.error(
                "format", f"is {fmt}; this tool reads format {FORMAT} and earlier versions"
            )

        base = self.base_locations(raw["base"]) if "base" in raw else []

        distros = None
        if "distros" in raw:
            distros = self.names(raw["distros"], "distro", "distros")
            if not distros:
                raise self.error("distros", "is empty; leave it out for a manifest with no distros")

        layers = self.names(raw.get("layers", []), "layer", "layers")
        for layer in layers:
            if layer.lower() in RESERVED_LAYERS:
                raise self.error(
                    "layers",
                    f"a layer cannot be named {quoted_url(layer)}; {', '.join(RESERVED_LAYERS)} are"
                    " the directories of the unnamed layer, in any case",
                )

        groups = self.names(raw.get("groups", []), "group", "groups")

        roles = None
        if "roles" in raw:
            roles_raw = raw["roles"]
            if not isinstance(roles_raw, dict):
                raise self.error(
                    "roles", f"must be a mapping of role names, got {_type_name(roles_raw)}"
                )
            if not roles_raw:
                raise self.error("roles", "is empty; leave it out for a manifest with no roles")
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
                roles[role] = self.names(role_groups, "group", where)

        repos: Dict[str, Dict[str, object]] = {}
        if "repositories" not in raw:
            if not base:
                # A manifest that builds on none has the repos; one with `base` may add none.
                raise self.error("", "has no `repositories:`")
        else:
            repos_raw = raw["repositories"]
            if not isinstance(repos_raw, dict):
                raise self.error(
                    "repositories", f"must be a mapping of repos, got {_type_name(repos_raw)}"
                )
            for key, entry in repos_raw.items():
                key = self.repo_key(key)  # the key before its entry, as part 1 does
                repos[key] = self.repo(key, entry)

        return Part(
            source=self.source,
            format=fmt,
            base=base,
            distros=distros,
            layers=layers,
            groups=groups,
            roles=roles,
            repos=repos,
            warnings=self.warnings,
        )

    def base_locations(self, value) -> List[Tuple[str, str]]:
        """`base:` is one location or a list of them. Each is returned with where it is in the
        manifest (`base`, or `base[i]` in a list). This version reads a location given as a
        path; a string with a ':' before its first '/' is a URL, not a path."""
        if isinstance(value, list):
            if not value:
                raise self.error(
                    "base", "is empty; leave it out for a manifest that builds on none"
                )
            located = [(f"base[{index}]", item) for index, item in enumerate(value)]
        else:
            located = [("base", value)]
        result = []
        for where, location in located:
            if isinstance(location, dict):
                raise self.error(
                    where,
                    f"is a mapping, the form of a file in a git repo; {_BASE_PATH_ONLY}",
                )
            path = self.string(location, where)
            if _colon_before_slash(path):
                raise self.error(
                    where, f"{quoted_url(path)} is a URL, not a path; {_BASE_PATH_ONLY}"
                )
            result.append((where, path))
        return result

    def repo_key(self, key) -> str:
        if not isinstance(key, str) or key == "":
            raise self.error("repositories", f"a repo key must be a path, got {quoted_url(key)}")
        where = f"repositories: {quoted_url(key)}"
        if "\\" in key:
            raise self.error(where, "a repo key is a path with '/' between its parts, no '\\'")
        if key.startswith("/"):
            raise self.error(where, "a repo key is a relative path")
        if key.startswith("#"):
            # optional.txt lists repo keys one per line, and its readers skip `#` lines.
            raise self.error(where, "a repo key does not start with '#'")
        if key != key.strip():
            # A reader of optional.txt may trim its lines, or skip a blank one.
            raise self.error(where, "a repo key does not start or end with white space")
        if key.endswith("/") or "//" in key:
            raise self.error(where, "a repo key has no empty part (no '//', no '/' at the end)")
        for part in key.split("/"):
            if part in (".", "..", ".git"):
                raise self.error(where, f"a repo key has no {quoted_url(part)} part")
        return key

    def repo(self, key: str, entry) -> Dict[str, object]:
        """The keys a repo entry gives, each checked. Whether the entry is complete is judged
        where its key first appears in the order of reading, and whether its layer, groups and
        distros are declared on the combination; both are in ``combine.py``."""
        where = f"repositories.{key}"
        if not isinstance(entry, dict):
            raise self.error(where, f"must be a mapping with type and url, got {_type_name(entry)}")
        for name in entry:
            if name not in _REPO_KEYS:
                self.warn(
                    f"{where}: unknown key {quoted_url(name)} is ignored and left out of the output"
                )
        given: Dict[str, object] = {}
        if "type" in entry:
            repo_type = self.string(entry["type"], f"{where}.type")
            if repo_type != "git":
                raise self.error(
                    f"{where}.type",
                    f"is {quoted_url(repo_type)}; the format takes any type a .repos file takes,"
                    " and these tools read git repos only",
                )
            given["type"] = repo_type
        if "url" in entry:
            given["url"] = self.url(entry["url"], f"{where}.url")
        if "version" in entry:
            given["version"] = self.version(entry["version"], f"{where}.version")
        if "absent" in entry:
            given["absent"] = self.boolean(entry["absent"], f"{where}.absent")
        if "optional" in entry:
            given["optional"] = self.boolean(entry["optional"], f"{where}.optional")
        if "layer" in entry:
            given["layer"] = self.name(entry["layer"], "layer", f"{where}.layer")
        if "groups" in entry:
            given["groups"] = self.names(entry["groups"], "group", f"{where}.groups")
        if "distros" in entry:
            given["distros"] = self.repo_distros(entry["distros"], f"{where}.distros")
        return given

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
                    self.warn(f"{entry_where}: unknown key {quoted_url(name)} is ignored")
            distro_entry = DistroEntry()
            if "version" in entry:
                distro_entry.version = self.version(entry["version"], f"{entry_where}.version")
            if "absent" in entry:
                distro_entry.absent = self.boolean(entry["absent"], f"{entry_where}.absent")
            if distro_entry.absent and distro_entry.version is not None:
                raise self.error(
                    entry_where, "gives both a `version` and `absent: true`; give one of them"
                )
            result[distro] = distro_entry
        return result
