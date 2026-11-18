"""`init`: set up a system directory in the current directory, then sync it.

Every refusal is checked before anything is created, in the order of the design's table.
`.repos-manifest/` is made with its `config.yaml` in one step, written aside and renamed into
place: before that step nothing of the system exists and `init` can be run again; after it,
`sync` finishes what `init` began.
"""

from __future__ import annotations

import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Callable, List, Optional, Sequence

from . import selection
from .output import process_has_ended, signals_held
from .selection import Resolved
from .signals import Stopped, signal_name, signals_end_the_run, stop_exit
from .sync import FINISH, closing, require_tools, sync_distros
from .yamlload import ManifestError
from .system import (
    current_directory,
    CONFIG_FILE,
    LAYOUT_DISTRO_DIRS,
    LAYOUT_FLAT,
    SYSTEM_DIR,
    TEMP_NAME,
    TEMP_PREFIX,
    Config,
    Refusal,
    config_text,
    default_mode,
    find_system,
    layer_src_parts,
    paths_init_creates,
    read_config,
    read_manifest,
    oserror_message,
    reporting_oserror,
    warn,
)

FLAT_LAYOUT_LINE = (
    "Layout: one directory for the system, with no directory per distro. A distro cannot be"
    " added to this system later. To be able to add one, set up with --distro-dirs."
)


def refuse_case_twins(distros: Sequence[str]) -> None:
    """Two distros that differ only in case are refused: each is a directory, and on a disk
    that ignores case they would be one."""
    seen = {}
    for name in distros:
        other = seen.setdefault(name.casefold(), name)
        if other != name:
            raise Refusal(
                f"--distro {other!r} and {name!r} differ only in case, and each distro is a"
                " directory",
                "Name one of them",
            )


def check_distros(manifest, distros: List[str], distro_dirs: bool) -> None:
    """The design's refusals on the distros, in its order; the manifest has been read."""
    listed = manifest.distros
    source = manifest.source
    if distro_dirs and listed is None:
        raise Refusal(
            f"--distro-dirs: {source} has no `distros:`",
            "Set up without --distro-dirs and without --distro",
        )
    if not distros and listed is not None:
        raise Refusal(
            f"{source} has distros ({', '.join(listed)}) and no --distro was given",
            "Name one with --distro",
        )
    if distros and listed is None:
        raise Refusal(f"--distro: {source} has no `distros:`", "Set up without --distro")
    unlisted = [name for name in distros if name not in listed]
    if unlisted and not distro_dirs:
        raise Refusal(
            f"{source}: does not cover distro {unlisted[0]!r}; its distros are {listed}",
            "Name a distro it lists, or add the distro to its `distros:`",
        )
    if unlisted:
        raise Refusal(
            f"{source}: does not list distro {unlisted[0]!r}; its distros are {listed}",
            "Set up with the distros it lists, or add the distro to its `distros:`",
        )


def summary(config: Config, plan: Sequence[Resolved]) -> str:
    """What `init` shows before it asks."""
    lines = [f"Manifest: {config.manifest}"]
    lines.append(f"Role: {config.role if config.role is not None else '(none)'}")
    lines.append(f"Extra groups: {', '.join(config.groups) if config.groups else '(none)'}")
    for resolved in plan:
        count = sum(len(layer.repos) for layer in resolved.layers)
        name = resolved.distro if resolved.distro is not None else "(none)"
        lines.append(f"Distro {name}: {count} repos in {len(resolved.layers)} layers")
        for layer in resolved.layers:
            src = "/".join(layer_src_parts(config.layout, resolved.distro, layer.name))
            lines.append(f"  {src}/")
            for repo in layer.repos:
                version = repo.version if repo.version is not None else "(its default branch)"
                optional = "  (optional)" if repo.optional else ""
                lines.append(f"    {repo.key}  {version}  {repo.url}{optional}")
    if config.layout == LAYOUT_DISTRO_DIRS:
        lines.append("Layout: a directory per distro.")
    elif config.distros is not None:
        lines.append(FLAT_LAYOUT_LINE)
    else:
        lines.append("Layout: one directory for the system.")
    return "\n".join(lines)


def ask(question: str) -> bool:
    print(question, end="", flush=True)
    try:
        reply = sys.stdin.readline()
    except (OSError, ValueError):
        return False
    return reply.strip().lower() in ("y", "yes")


def sweep_asides(system: Path) -> None:
    """Remove what an ended `init` left in the person's directory: a directory of the aside's
    name, not a link, whose process has ended, that is empty or holds only `config.yaml`.
    Anything else of that name is left, and named in a warning."""
    for entry in system.iterdir():
        match = TEMP_NAME.fullmatch(entry.name)
        if match is None or entry.is_symlink():
            continue
        if not process_has_ended(int(match.group("pid"))):
            continue
        config = entry / CONFIG_FILE
        ours = entry.is_dir() and all(child == config for child in entry.iterdir())
        if not ours or config.is_symlink() or (os.path.lexists(config) and not config.is_file()):
            warn(
                f"{entry}: named like a temporary of repos-manifest, but not what init leaves;"
                " left as it is"
            )
            continue
        try:
            config.unlink(missing_ok=True)
            entry.rmdir()
        except OSError as exc:
            warn(f"{oserror_message(exc)}; a temporary of this tool, left for the next init")


def make_system_dir(system: Path, config: Config, on_made: Callable[[], None]) -> None:
    """`.repos-manifest/` with its `config.yaml`, in one rename from a directory made aside.
    `on_made` is called right after the rename, before a stop signal held over it arrives."""
    sweep_asides(system)
    try:
        aside = Path(tempfile.mkdtemp(prefix=f"{TEMP_PREFIX}{os.getpid()}-", dir=system))
    except OSError as exc:
        why = exc.strerror or type(exc).__name__
        raise ManifestError(f"{system}: cannot be written ({why}); nothing was set up") from None
    try:
        (aside / CONFIG_FILE).write_text(config_text(config), encoding="utf-8")
        os.chmod(aside / CONFIG_FILE, default_mode(0o666))
        os.chmod(aside, default_mode(0o777))
        if os.path.lexists(system / SYSTEM_DIR):
            raise ManifestError(
                f"{system / SYSTEM_DIR}: appeared while init was running; nothing was set up"
            )
        with signals_held():
            os.rename(aside, system / SYSTEM_DIR)
            on_made()
    finally:
        if os.path.lexists(aside):
            shutil.rmtree(aside, ignore_errors=True)


def run_init(
    manifest_location: str,
    role: Optional[str],
    groups: Sequence[str],
    distros: Sequence[str],
    distro_dirs: bool,
    yes: bool,
) -> int:
    """A stop signal at any point ends the run with one line, which says whether the system
    was made."""
    made: List[bool] = []
    try:
        with signals_end_the_run():
            return _init(manifest_location, role, groups, distros, distro_dirs, yes, made)
    except Stopped as exc:
        then = FINISH if made else "nothing was created"
        return stop_exit(exc, f"stopped by {signal_name(exc)}; {then}")


def _init(
    manifest_location: str,
    role: Optional[str],
    groups: Sequence[str],
    distros: Sequence[str],
    distro_dirs: bool,
    yes: bool,
    made: List[bool],
) -> int:
    system = current_directory()
    distros = list(dict.fromkeys(distros))
    with reporting_oserror():
        found = find_system(system)
        if found is not None:
            read_config(found)  # one that cannot be read is that error, not the refusal
            raise Refusal(
                f"a system is already set up in {found}",
                "Run `repos-manifest sync` there to bring it in line with its manifest",
            )
        if len(distros) > 1 and not distro_dirs:
            raise Refusal(
                f"{len(distros)} distros given without --distro-dirs", "Add --distro-dirs"
            )
        refuse_case_twins(distros)
        manifest = read_manifest(manifest_location, system)
        check_distros(manifest, distros, distro_dirs)
        layout = LAYOUT_DISTRO_DIRS if distro_dirs else LAYOUT_FLAT
        config = Config(
            manifest=manifest_location,
            role=role,
            groups=list(groups),
            layout=layout,
            distros=distros if manifest.distros is not None else None,
        )
        plan = [selection.resolve(manifest, role, distro, groups) for distro in config.distro_keys]
        for resolved in plan:
            layers = [layer.name for layer in resolved.layers]
            for parts in paths_init_creates(layout, resolved.distro, layers):
                if os.path.lexists(system.joinpath(*parts)):
                    raise Refusal(
                        f"{system.joinpath(*parts)}: exists, and init would create it",
                        "Move it out of the way, or set up in another directory",
                    )
        env = require_tools()
        if not yes and not sys.stdin.isatty():
            raise Refusal(
                "the input is not a terminal, so init cannot ask before it sets up",
                "Give --yes to set up without asking",
            )
        print(summary(config, plan), flush=True)
        if not yes and not ask(f"Set up this system in {system}? [y/N] "):
            print("Nothing was created.")
            return 1
        make_system_dir(system, config, lambda: made.append(True))
        try:
            with reporting_oserror():
                results = sync_distros(system, config, plan, env)
        except ManifestError as exc:
            raise ManifestError(f"{exc}; the system is set up: {FINISH}") from None
    print("The system is set up.")
    return closing(results)
