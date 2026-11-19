"""The system directory: finding it, `config.yaml`, where each part of it is, `state.yaml`, and
reading the manifest a system was set up from.

Layout (``docs/design.md``, "The system directory" and "More than one distro"): a flat system
holds one distro, or none, directly in the system directory; with ``--distro-dirs`` each distro
has a directory of its own. In either, the unnamed first layer's repos are in ``src/`` and a
named layer's in ``<layer>/src/``.

Every temporary this tool makes in a system, after ``init``'s first step, is in
``.repos-manifest/`` and is named ``.repos-manifest-tmp-<pid>-<8 characters>``.
"""

from __future__ import annotations

import os
import re
import sys
import tempfile
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

import yaml

from .base import load_manifest
from .manifest import UNNAMED_LAYER, Manifest
from .yamlload import ManifestError

SYSTEM_DIR = ".repos-manifest"
CONFIG_FILE = "config.yaml"
STATE_FILE = "state.yaml"
RESOLVED_DIR = "resolved"
SETUP_FILE = "setup.bash"
LAYOUT_FLAT = "flat"
LAYOUT_DISTRO_DIRS = "distro-dirs"
NO_DISTRO = "_unnamed"  # the state's key for a system whose manifest has no distros
STATE_FORMAT = 1

TEMP_PREFIX = ".repos-manifest-tmp-"
TEMP_NAME = re.compile(re.escape(TEMP_PREFIX) + r"(?P<pid>[0-9]+)-[a-z0-9_]{8}")

SETUP_TEXT = (
    "# Written by repos-manifest. Nothing is built here yet.\n"
    'echo "repos-manifest: nothing is built here yet" >&2\n'
    "return 1 2>/dev/null || exit 1\n"
)

Parts = Tuple[str, ...]


class Refusal(ManifestError):
    """A command refuses to go on; nothing was changed. The message gives the next step."""

    def __init__(self, condition: str, next_step: str):
        super().__init__(f"{condition}. {next_step}")


def oserror_message(exc: OSError) -> str:
    """An error on the disk as one line: the path, a second path if there was one, and why."""
    where = " -> ".join(str(name) for name in (exc.filename, exc.filename2) if name is not None)
    reason = exc.strerror or type(exc).__name__
    return f"{where}: {reason}" if where else reason


@contextmanager
def reporting_oserror():
    """An `OSError` from the disk ends the command with a message naming its path and reason."""
    try:
        yield
    except OSError as exc:
        raise ManifestError(oserror_message(exc)) from None


def warn(message: str) -> None:
    print(f"WARNING: {message}", file=sys.stderr)


def current_directory() -> Path:
    """The current directory; one that has been removed is an error with a plain message."""
    try:
        return Path(os.getcwd())
    except FileNotFoundError:
        raise ManifestError(
            "the current directory no longer exists; change to one that does and run it again"
        ) from None


def default_mode(full: int) -> int:
    """The mode a plain `mkdir` (0o777) or `open` (0o666) would give under the umask."""
    umask = os.umask(0)
    os.umask(umask)
    return full & ~umask


# --- config.yaml ----------------------------------------------------------------------------


@dataclass
class Config:
    manifest: str  # as given to init; a relative path is taken from the system directory
    role: Optional[str]
    groups: List[str]
    layout: str
    distros: Optional[List[str]]  # in order; None when the manifest has no distros

    @property
    def distro_keys(self) -> List[Optional[str]]:
        return list(self.distros) if self.distros is not None else [None]


def config_text(config: Config) -> str:
    data: Dict[str, object] = {"manifest": config.manifest}
    if config.role is not None:
        data["role"] = config.role
    if config.groups:
        data["groups"] = list(config.groups)
    data["layout"] = config.layout
    if config.distros is not None:
        data["distros"] = {name: {} for name in config.distros}
    return yaml.safe_dump(data, default_flow_style=False, sort_keys=False, width=4096)


def _kind(value) -> str:
    """What a YAML value is, for a message about a file's shape."""
    if value is None:
        return "empty"
    for kind, name in ((bool, "a boolean"), (dict, "a mapping"), (list, "a list")):
        if isinstance(value, kind):
            return name
    for kind, name in ((str, "a string"), (int, "an int"), (float, "a number")):
        if isinstance(value, kind):
            return name
    return f"a {type(value).__name__}"


def _check_keys(
    value, where: str, required: Sequence[str], optional: Optional[Sequence[str]], bad
) -> None:
    """`value` is a mapping with every key of `required` and no key outside `required` and
    `optional`; `optional` None allows any other key. `where` is its dotted place in the file,
    empty for the whole file."""
    named = f"`{where}` " if where else ""
    if not isinstance(value, dict):
        raise bad(f"{named}is {_kind(value)}, not a mapping")
    for key in value:
        if optional is not None and key not in required and key not in optional:
            inside = f"{where}.{key}" if where else key
            raise bad(f"`{inside}` is not read by this version")
    for key in required:
        if key not in value:
            raise bad(f"{named}has no `{key}`")


def is_url(location: str, base: Path) -> bool:
    """A manifest location that is a URL: it has `://` and no path of that name exists."""
    return "://" in location and not os.path.lexists(base / location)


ONLY_A_PATH = "a path; this version reads a manifest given as a path only"


def read_config(system: Path) -> Config:
    """`config.yaml`, read and checked whole: it has exactly the shape `config_text` writes, and
    each error names the file and what is wrong."""
    path = system / SYSTEM_DIR / CONFIG_FILE

    def bad(why: str) -> ManifestError:
        return ManifestError(
            f"{path}: {why}; repair the file, or, to set up again, move {system} aside and run"
            " `repos-manifest init` in an empty directory"
        )

    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise bad("not found") from None
    except OSError as exc:
        raise bad(f"cannot be read ({exc.strerror or type(exc).__name__})") from None
    except (yaml.YAMLError, UnicodeDecodeError):
        raise bad("does not read as YAML") from None
    _check_keys(data, "", ("manifest", "layout"), ("role", "groups", "distros"), bad)
    manifest = data["manifest"]
    if not isinstance(manifest, str):
        raise bad(f"`manifest` is {_kind(manifest)}, not {ONLY_A_PATH}")
    if is_url(manifest, system):
        raise bad(f"`manifest` is a URL, not {ONLY_A_PATH}")
    role = data.get("role")
    if "role" in data and not isinstance(role, str):
        raise bad(f"`role` is {_kind(role)}, not a name")
    groups = data.get("groups", [])
    if not isinstance(groups, list):
        raise bad(f"`groups` is {_kind(groups)}, not a list of names")
    for group in groups:
        if not isinstance(group, str):
            raise bad(f"`groups` holds {_kind(group)}, not a name")
    layout = data["layout"]
    if layout not in (LAYOUT_FLAT, LAYOUT_DISTRO_DIRS):
        raise bad(f"`layout` is {layout!r}, not {LAYOUT_FLAT} or {LAYOUT_DISTRO_DIRS}")
    distros = data.get("distros")
    if "distros" not in data:
        if layout == LAYOUT_DISTRO_DIRS:
            raise bad(f"`layout` is {LAYOUT_DISTRO_DIRS} and there is no `distros`")
    else:
        if not isinstance(distros, dict):
            raise bad(f"`distros` is {_kind(distros)}, not a mapping of each distro's settings")
        if not distros:
            raise bad("`distros` is empty; a system with distros records at least one")
        if layout == LAYOUT_FLAT and len(distros) > 1:
            raise bad(f"`layout` is {LAYOUT_FLAT} and there are {len(distros)} distros")
        for name, settings in distros.items():
            if not isinstance(name, str):
                raise bad(f"`distros` has {name!r} as a name")
            _check_keys(settings, f"distros.{name}", (), (), bad)
    return Config(
        manifest=manifest,
        role=role,
        groups=list(groups),
        layout=layout,
        distros=list(distros) if distros is not None else None,
    )


def find_system(start: Path) -> Optional[Path]:
    """The system directory: `start` or the nearest directory above it that holds
    `.repos-manifest`."""
    for directory in [start, *start.parents]:
        if os.path.lexists(directory / SYSTEM_DIR):
            return directory
    return None


def distros_for(
    system: Path, config: Config, named: Sequence[str], cwd: Path
) -> List[Optional[str]]:
    """The distros a command acts on ("Which distro a command uses"): those named, which must be
    recorded; else the distro whose directory `cwd` is inside; else every one, in order."""
    if named:
        recorded = config.distros or []
        for name in named:
            if name not in recorded:
                listed = ", ".join(recorded) if recorded else "none"
                raise ManifestError(
                    f"--distro {name}: this system does not record it (it records: {listed})"
                )
        return list(dict.fromkeys(named))
    if config.layout == LAYOUT_DISTRO_DIRS:
        for name in config.distros or []:
            inside = system / name
            if cwd == inside or inside in cwd.parents:
                return [name]
    return config.distro_keys


# --- Where each part is ---------------------------------------------------------------------


def distro_parts(layout: str, distro: Optional[str]) -> Parts:
    """The distro's directory below the system directory: none in a flat system."""
    return (distro,) if layout == LAYOUT_DISTRO_DIRS else ()


def layer_src_parts(layout: str, distro: Optional[str], layer: str) -> Parts:
    layer_dir = () if layer == UNNAMED_LAYER else (layer,)
    return distro_parts(layout, distro) + layer_dir + ("src",)


def resolved_parts(layout: str, distro: Optional[str]) -> Parts:
    return (SYSTEM_DIR, RESOLVED_DIR) + distro_parts(layout, distro)


def setup_parts(layout: str, distro: Optional[str]) -> Parts:
    return distro_parts(layout, distro) + (SETUP_FILE,)


def paths_init_creates(layout: str, distro: Optional[str], layers: Sequence[str]) -> List[Parts]:
    """The paths directly below the system directory, or the distro's directory, that `init`
    creates for one distro, other than `.repos-manifest`."""
    if layout == LAYOUT_DISTRO_DIRS:
        return [distro_parts(layout, distro)]
    tops = [layer_src_parts(layout, distro, layer)[:1] for layer in layers]
    return list(dict.fromkeys(tops + [setup_parts(layout, distro)]))


def place_problem(system: Path, parts: Parts) -> Optional[str]:
    """The check on the real destination, before a clone and again before its rename: why
    `parts` cannot be put in place, or None. The directory that will hold it must be, with
    every link resolved, the system directory's real path joined with the parts above it, so a
    link on the way, a layer directory or a directory of a repo's key, fails it; and the
    nearest of those directories that exists must be a directory, not a file."""
    target = system.joinpath(*parts)
    expected = os.path.join(os.path.realpath(system), *parts[:-1])
    if os.path.realpath(target.parent) != expected:
        return "a link on the way leads outside its place"
    for depth in range(len(parts) - 1, 0, -1):
        above = system.joinpath(*parts[:depth])
        if os.path.lexists(above):
            if not above.is_dir():
                return f"{'/'.join(parts[:depth])} is on the way and is not a directory"
            break
    return None


# --- Files in .repos-manifest/ --------------------------------------------------------------


def replace_file(system: Path, path: Path, text: str) -> None:
    """Write `path` whole: a temporary file in `.repos-manifest/`, then one rename."""
    handle, temporary = tempfile.mkstemp(
        prefix=f"{TEMP_PREFIX}{os.getpid()}-", dir=system / SYSTEM_DIR
    )
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as file:
            file.write(text)
        os.chmod(temporary, default_mode(0o666))
        os.replace(temporary, path)
    finally:
        if os.path.lexists(temporary):
            os.unlink(temporary)


@dataclass
class RepoRecord:
    layer: str
    version: Optional[str]
    commit: str


@dataclass
class DistroState:
    repos: Dict[str, RepoRecord] = field(default_factory=dict)


def state_key(distro: Optional[str]) -> str:
    return distro if distro is not None else NO_DISTRO


def _read_state_data(system: Path) -> dict:
    """`state.yaml`, read and checked whole: it has exactly the shape `put_distro_state`
    writes, and each error names the file and what is wrong."""
    path = system / SYSTEM_DIR / STATE_FILE

    def bad(why: str) -> ManifestError:
        return ManifestError(f"{path}: {why}; repair or remove it")

    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {"format": STATE_FORMAT, "distros": {}}
    except (yaml.YAMLError, UnicodeDecodeError):
        raise bad("does not read as YAML") from None
    _check_keys(data, "", ("format", "distros"), (), bad)
    if data["format"] != STATE_FORMAT or isinstance(data["format"], bool):
        raise bad(
            f"`format` is {data['format']!r}, not {STATE_FORMAT}, the one this version writes"
        )
    _check_keys(data["distros"], "distros", (), None, bad)
    for distro, entry in data["distros"].items():
        where = f"distros.{distro}"
        _check_keys(entry, where, ("repos",), (), bad)
        _check_keys(entry["repos"], f"{where}.repos", (), None, bad)
        for key, record in entry["repos"].items():
            at = f"{where}.repos.{key}"
            _check_keys(record, at, ("layer", "version", "commit"), (), bad)
            for name in ("layer", "version", "commit"):
                value = record[name]
                if not isinstance(value, str) and not (name == "version" and value is None):
                    what = "a string or empty" if name == "version" else "a string"
                    raise bad(f"`{at}.{name}` is {_kind(value)}, not {what}")
    return data


def read_state(system: Path, distro: Optional[str]) -> DistroState:
    entry = _read_state_data(system)["distros"].get(state_key(distro)) or {}
    repos = {
        key: RepoRecord(record.get("layer"), record.get("version"), record.get("commit"))
        for key, record in (entry.get("repos") or {}).items()
    }
    return DistroState(repos)


def put_distro_state(system: Path, distro: Optional[str], state: DistroState) -> None:
    """Replace one distro's entry; every other distro's is written back as it was read."""
    data = _read_state_data(system)
    data["distros"][state_key(distro)] = {
        "repos": {
            key: {"layer": record.layer, "version": record.version, "commit": record.commit}
            for key, record in state.repos.items()
        }
    }
    text = yaml.safe_dump(data, default_flow_style=False, sort_keys=False, width=4096)
    replace_file(system, system / SYSTEM_DIR / STATE_FILE, text)


# --- The manifest ---------------------------------------------------------------------------


def read_manifest(location: str, base: Path) -> Manifest:
    """Read the manifest at `location`, a path taken from `base` when relative, and the
    manifests it builds on through its own `base` key (``base.py``); the one place a command
    reads a manifest. Its warnings go to stderr."""
    path = base / location
    if "://" in location and not os.path.lexists(path):
        raise ManifestError(
            f"{location}: only a manifest given as a file path is read in this version"
        )
    loaded = load_manifest(path, source=location)
    for warning in loaded.warnings:
        warn(warning)
    return loaded
