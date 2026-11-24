"""`init`: set up a system directory in the current directory, then sync it.

Every refusal is checked before anything is created, in the order of the design's table, and
the text of every distro's resolved files is built then too, so a manifest whose files cannot
be written out is refused with nothing created.
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
from typing import Callable, List, Optional, Sequence, Tuple

from .fetch_from import FetchFrom, FetchFromError, check_prefix
from .location import GitLocation, Location, check_git_location, is_path
from .output import process_has_ended, signals_held
from .show import render_body, render_head, shown_path
from .signals import Stopped, signal_name, signals_end_the_run, stop_exit
from .sync import (
    FINISH,
    Planned,
    closing,
    plan_distros,
    require_tools,
    resolve_for,
    sync_distros,
)
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


def check_distros(manifest, distros: List[str], distro_dirs: bool, git_form: bool = False) -> None:
    """The design's refusals on the distros, in its order; the manifest has been read.
    `git_form`: the manifest was given in the git form, so another version of it can be named
    with --manifest-ref."""
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
            (
                "Name a distro it lists, or give with --manifest-ref a version of the manifest"
                " that lists the distro"
                if git_form
                else "Name a distro it lists, or add the distro to its `distros:`"
            ),
        )
    if unlisted:
        raise Refusal(
            f"{source}: does not list distro {unlisted[0]!r}; its distros are {listed}",
            (
                "Set up with the distros it lists"
                if git_form
                else "Set up with the distros it lists, or add the distro to its `distros:`"
            ),
        )


GIT_FORM = (
    "Give the manifest in the git form: the url of its repo (such as"
    " git@git.example.org:team/system.git or file:///srv/system.git) with --manifest-path, the"
    " path of the file in the repo, and --manifest-ref for a branch or tag other than the"
    " default"
)


def manifest_location(
    given: str, manifest_ref: Optional[str], manifest_path: Optional[str], system: Path
) -> Location:
    """Where the manifest named on the command line is, by the design's rule: with
    --manifest-path, `given` is the url of the repo the file is in; without it, a path. The
    refusal for an option given with a manifest that is not in the git form, and the checks of
    the git form's url, version and path (``location.check_git_location``)."""
    if manifest_ref is not None or manifest_path is not None:
        option = "--manifest-ref" if manifest_ref is not None else "--manifest-path"
        if is_path(given):
            raise Refusal(
                f"{option} is given, and the manifest {shown_path(given)} is a path on the local"
                " disk, not the git form",
                f"{GIT_FORM}; or leave {option} out",
            )
        if manifest_path is None:
            raise Refusal(
                f"--manifest-ref is given without --manifest-path, so {shown_path(given)} is not"
                " the git form",
                f"{GIT_FORM}; or leave --manifest-ref out",
            )
        return check_git_location(
            given, manifest_ref, manifest_path, "init", ("the manifest's url", *_OPTIONS)
        )
    if not is_path(given) and not os.path.lexists(system / given):
        raise ManifestError(
            f"{shown_path(given)}: is a URL, and this version reads a manifest given as a path"
            " on the local disk or as a file in a git repo; for a file in a git repo, give its"
            " repo's url with --manifest-path (and --manifest-ref for a branch or tag other than"
            " the default)"
        )
    return given


_OPTIONS = ("--manifest-ref", "--manifest-path")


def summary(config: Config, plan: Sequence[Planned]) -> str:
    """What `init` shows before it asks: what `show` prints (the manifest, base and role lines
    once, then for each distro a `distro` line, left out when the manifest has no distros, and
    its layers and the repos left out), each distro's `src/` directories it will create, and
    the `Layout:` line."""
    resolved_distros = [planned.resolved for planned in plan]
    blocks = [render_head(resolved_distros[0])]
    for resolved in resolved_distros:
        body = render_body(resolved)
        if resolved.distro is not None:
            body = f"distro {resolved.distro}\n{body}"
        blocks.append(body)
        create = ["will create"]
        for layer in resolved.layers:
            src = "/".join(layer_src_parts(config.layout, resolved.distro, layer.name))
            create.append(f"  {src}/")
        if len(create) > 1:
            blocks.append("\n".join(create))
    lines = ["\n\n".join(blocks), ""]
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


def _is_process_id(pid: int) -> bool:
    """Whether `pid` can name a process at all (`os.kill` takes it)."""
    try:
        os.kill(pid, 0)
    except (OverflowError, ValueError):
        return False
    except OSError:
        return True
    return True


def sweep_asides(system: Path) -> None:
    """Remove what an ended `init` left in the person's directory: a directory of the aside's
    name, not a link, whose process has ended, that is empty or holds only `config.yaml`.
    Any other entry of that name, a link among them, is left, and named in a warning. Called
    before this run makes its own aside."""
    for entry in system.iterdir():
        match = TEMP_NAME.fullmatch(entry.name)
        if match is None:
            continue
        config = entry / CONFIG_FILE
        directory = not entry.is_symlink() and entry.is_dir()
        ours = directory and all(child == config for child in entry.iterdir())
        if not ours or config.is_symlink() or (os.path.lexists(config) and not config.is_file()):
            warn(
                f"{entry}: named like a temporary of repos-manifest, but not what init leaves;"
                " left as it is"
            )
            continue
        pid = int(match.group("pid"))
        if not process_has_ended(pid):
            if 0 < pid and _is_process_id(pid):
                warn(
                    f"{entry}: a temporary of repos-manifest whose process is still running"
                    " (another init may be setting up here); left as it is"
                )
            else:
                warn(
                    f"{entry}: named like a temporary of repos-manifest, but not what init"
                    " leaves; left as it is"
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
        try:
            (aside / CONFIG_FILE).write_text(config_text(config), encoding="utf-8")
            os.chmod(aside / CONFIG_FILE, default_mode(0o666))
            os.chmod(aside, default_mode(0o777))
        except OSError as exc:
            why = exc.strerror or type(exc).__name__
            raise ManifestError(
                f"{system / SYSTEM_DIR / CONFIG_FILE}: cannot be written ({why}); nothing was"
                " set up"
            ) from None
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
    manifest_given: str,
    role: Optional[str],
    groups: Sequence[str],
    distros: Sequence[str],
    distro_dirs: bool,
    yes: bool,
    fetch_from: Optional[str] = None,
    manifest_ref: Optional[str] = None,
    manifest_path: Optional[str] = None,
) -> int:
    """A stop signal at any point ends the run with one line, which says whether the system
    was made. `fetch_from` is the prefix of `--fetch-from`, when given; `manifest_ref` and
    `manifest_path` are --manifest-ref and --manifest-path."""
    made: List[bool] = []
    try:
        with signals_end_the_run():
            return _init(
                manifest_given,
                role,
                groups,
                distros,
                distro_dirs,
                yes,
                made,
                fetch_from,
                (manifest_ref, manifest_path),
            )
    except Stopped as exc:
        then = FINISH if made else "nothing was created"
        return stop_exit(exc, f"stopped by {signal_name(exc)}; {then}")


def _init(
    manifest_given: str,
    role: Optional[str],
    groups: Sequence[str],
    distros: Sequence[str],
    distro_dirs: bool,
    yes: bool,
    made: List[bool],
    fetch_from: Optional[str] = None,
    git_options: Tuple[Optional[str], Optional[str]] = (None, None),
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
        location = manifest_location(manifest_given, *git_options, system)
        git_form = isinstance(location, GitLocation)
        place = None
        if fetch_from is not None:
            try:
                place = FetchFrom(check_prefix(fetch_from, "--fetch-from"))
            except ManifestError as exc:
                raise ManifestError(f"{exc}; nothing was set up") from None
        env = None
        if git_form:
            # git reads the manifest, so the tools are checked before the read.
            env = require_tools()
            manifest = read_manifest(location, system, env=env)
        else:
            manifest = read_manifest(location, system)
        check_distros(manifest, distros, distro_dirs, git_form)
        layout = LAYOUT_DISTRO_DIRS if distro_dirs else LAYOUT_FLAT
        config = Config(
            manifest=location,
            role=role,
            groups=list(groups),
            layout=layout,
            distros=distros if manifest.distros is not None else None,
            fetch_from=place,
        )
        try:
            resolved_distros = [
                resolve_for(manifest, config, distro, "--fetch-from")
                for distro in config.distro_keys
            ]
        except FetchFromError as exc:
            raise ManifestError(f"{exc}; nothing was set up") from None
        try:
            plan = plan_distros(resolved_distros)
        except ManifestError as exc:
            raise ManifestError(f"{exc}; nothing was set up") from None
        for resolved in (planned.resolved for planned in plan):
            layers = [layer.name for layer in resolved.layers]
            for parts in paths_init_creates(layout, resolved.distro, layers):
                if os.path.lexists(system.joinpath(*parts)):
                    raise Refusal(
                        f"{system.joinpath(*parts)}: exists, and init would create it",
                        "Move it out of the way, or set up in another directory",
                    )
        if env is None:
            env = require_tools()
        if not yes and not sys.stdin.isatty():
            raise Refusal(
                "the input is not a terminal, so init cannot ask before it sets up",
                "Give --yes to set up without asking",
            )
        print(summary(config, plan), flush=True)
        if not yes and not ask(f"Set up this system in {shown_path(str(system))}? [y/N] "):
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
