"""`repos-manifest` CLI: resolve writes what a manifest comes to for a machine as .repos files,
and validate checks a manifest; show prints what a manifest comes to for a machine; init and
sync set up a system directory and clone its repos; build builds its layers with colcon and
writes its setup.bash.

Every command that reads a manifest reads it in the format of docs/spec.md.
"""

from __future__ import annotations

import argparse
import os
import signal
import sys
from pathlib import Path

from . import output, selection
from .build import run_build
from .fetch_from import FetchFromError
from .init import run_init
from .location import GitLocation
from .manifest import Manifest
from .masking import mask_urls
from .show import render, shown_path
from .signals import Stopped, signal_name, signals_end_the_run, stop_exit
from .status import run_status
from .sync import fetch_from_named, recorded_manifest, resolve_for, run_sync
from .system import (
    SYSTEM_DIR,
    Refusal,
    current_directory,
    find_system,
    one_distro_for,
    read_config,
    read_manifest,
    read_recorded_manifest,
    reporting_oserror,
)
from .yamlload import ManifestError


def _stopped(exc: Stopped, replaced_out=None) -> int:
    """`replaced_out` is the `--out` the new output had replaced when the signal came, if it
    had: a signal held during the swap is delivered after it."""
    name = signal_name(exc)
    if replaced_out is None:
        return stop_exit(exc, f"stopped by {name}; nothing was written")
    return stop_exit(
        exc, f"stopped by {name} after --out {replaced_out} was replaced by the new output"
    )


def _load(args: argparse.Namespace) -> Manifest:
    return read_manifest(args.manifest, Path("."))


def cmd_resolve(args: argparse.Namespace) -> int:
    replaced = []
    try:
        with signals_end_the_run():
            loaded = _load(args)
            resolved = selection.resolve(loaded, args.role, args.distro, args.with_groups or [])
            written = output.write_output(
                Path(args.out),
                output.output_files(resolved),
                on_replaced=lambda: replaced.append(args.out),
            )
    except Stopped as exc:
        return _stopped(exc, replaced[0] if replaced else None)
    if not resolved.layers:
        print("WARNING: no repo is selected for this machine", file=sys.stderr)
    for path in written:
        print(f"wrote {path}")
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    loaded = _load(args)
    for parent in loaded.bases:
        print(f"base: {parent}")
    roles = sorted(loaded.roles) if loaded.roles is not None else [None]
    distros = loaded.distros if loaded.distros is not None else [None]
    if args.role is not None:
        roles = [args.role]
    if args.distro is not None:
        distros = [args.distro]
    for role in roles:
        for distro in distros:
            resolved = selection.resolve(loaded, role, distro, args.with_groups or [])
            count = sum(len(layer.repos) for layer in resolved.layers)
            print(
                f"role {role if role is not None else '(none)'}, distro"
                f" {distro if distro is not None else '(none)'}: {count} repos in"
                f" {len(resolved.layers)} layers"
            )
    print(f"{args.manifest}: valid")
    return 0


def _show_in_system(args: argparse.Namespace, cwd: Path) -> selection.Resolved:
    """`show` with no manifest: what the system directory `cwd` is in records, for the one
    distro "Which distro a command uses" picks. Reads `config.yaml` and the manifest only."""
    system = find_system(cwd)
    if system is None:
        raise Refusal(
            f"no manifest given, and no system directory in {shown_path(str(cwd))} or above it"
            f" (no {SYSTEM_DIR}/ found)",
            "Give the manifest's path, or run show inside a system directory",
        )
    if args.role is not None or args.with_groups:
        given = "--role" if args.role is not None else "--with"
        raise Refusal(
            f"{given} without a manifest: in a system directory show uses what it records",
            "Give the manifest to try another role or other groups",
        )
    config = read_config(system)
    distro = one_distro_for(system, config, [args.distro] if args.distro else [], cwd)
    # The recorded location is read and resolved as sync reads it, a path from the system
    # directory, which need not be the current one, and under its recorded name, so every
    # refusal and warning names it as sync's do; a file in a git repo afresh from the repo.
    # Only once it has read and resolved is a path shown, like the manifests it builds on, as
    # an absolute path with links followed, so that it opens from where show is run.
    try:
        manifest = read_recorded_manifest(system, config)
        resolved = resolve_for(manifest, config, distro, fetch_from_named(system))
    except FetchFromError:
        raise
    except ManifestError as exc:
        raise ManifestError(f"{exc} {recorded_manifest(system, config)}") from None
    if isinstance(config.manifest, GitLocation):
        return resolved  # named by its label, its url masked
    canonical = os.path.realpath(system / config.manifest)
    for layer in resolved.layers:
        for repo in layer.repos:
            if repo.source == resolved.source:
                repo.source = canonical
    resolved.source = canonical
    return resolved


def cmd_show(args: argparse.Namespace) -> int:
    if args.distro == "":
        raise ManifestError("--distro is given an empty name; name the distro to show")
    with reporting_oserror():
        cwd = current_directory()
        if args.manifest is None:
            resolved = _show_in_system(args, cwd)
        else:
            manifest = read_manifest(args.manifest, cwd)
            resolved = selection.resolve(manifest, args.role, args.distro, args.with_groups or [])
    print(render(resolved))
    return 0


def cmd_init(args: argparse.Namespace) -> int:
    return run_init(
        args.manifest,
        args.role,
        args.with_groups or [],
        args.distro or [],
        args.distro_dirs,
        args.yes,
        args.fetch_from,
        args.manifest_ref,
        args.manifest_path,
    )


def cmd_sync(args: argparse.Namespace) -> int:
    return run_sync(args.distro or [])


def cmd_status(args: argparse.Namespace) -> int:
    return run_status(args.distro or [], args.json)


def cmd_build(args: argparse.Namespace) -> int:
    if args.distro == "":
        raise ManifestError("--distro is given an empty name; name the distro to build")
    distros = [args.distro] if args.distro is not None else []
    return run_build(distros, args.layers, args.colcon_args, args.keep_going)


class _Once(argparse.Action):
    """An option that may be given once: a second one is an error, not a silent replacement."""

    def __call__(self, parser, namespace, values, option_string=None):
        if getattr(namespace, self.dest, None) is not None:
            parser.error(f"{option_string} may be given only once")
        setattr(namespace, self.dest, values)


def _add_with(sub_parser: argparse.ArgumentParser) -> None:
    sub_parser.add_argument(
        "--with",
        dest="with_groups",
        action="append",
        metavar="GROUP",
        help="An extra group to switch on, on top of the role's; may be given more than once",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="repos-manifest", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    resolve_p = sub.add_parser(
        "resolve", help="Resolve a manifest for a role/distro and emit .repos files"
    )
    resolve_p.add_argument("--manifest", required=True, help="Path to the manifest YAML file")
    resolve_p.add_argument("--role", help="The role, when the manifest has roles")
    resolve_p.add_argument("--distro", help="The distro, when the manifest has distros")
    _add_with(resolve_p)
    resolve_p.add_argument("--out", required=True, help="Output directory")
    resolve_p.set_defaults(func=cmd_resolve, parser=resolve_p)

    validate_p = sub.add_parser(
        "validate",
        help="Check a manifest: the file, and every role and distro it lists",
    )
    validate_p.add_argument("--manifest", required=True)
    validate_p.add_argument("--role", help="Check only this role")
    validate_p.add_argument("--distro", help="Check only this distro")
    _add_with(validate_p)
    validate_p.set_defaults(func=cmd_validate, parser=validate_p)

    show_p = sub.add_parser(
        "show",
        help=(
            "Print what a manifest comes to for a role and distro, with what is left out and"
            " why; with no manifest, what the system directory you are in records"
        ),
    )
    show_p.add_argument(
        "manifest",
        nargs="?",
        help="Path to the manifest file (default: the one the system directory records)",
    )
    show_p.add_argument("--role", help="The role, when the manifest has roles")
    _add_with(show_p)
    show_p.add_argument(
        "--distro",
        action=_Once,
        help="The distro, when the manifest has distros; in a system, one it records",
    )
    show_p.set_defaults(func=cmd_show, parser=show_p)

    init_p = sub.add_parser(
        "init",
        help="Set up a system directory here from a manifest, then clone its repos",
    )
    init_p.add_argument(
        "manifest",
        help=("Path to the manifest file; with --manifest-path, the url of the git repo it is in"),
    )
    init_p.add_argument(
        "--manifest-ref",
        action=_Once,
        metavar="REF",
        help="The branch or tag of the manifest's repo to read (default: its default branch)",
    )
    init_p.add_argument(
        "--manifest-path",
        action=_Once,
        metavar="PATH",
        help="The path of the manifest file in its git repo; the manifest is then the repo's url",
    )
    init_p.add_argument("--role", help="The role of this machine, when the manifest has roles")
    _add_with(init_p)
    init_p.add_argument(
        "--distro",
        action="append",
        help="The distro, when the manifest has distros; more than one with --distro-dirs",
    )
    init_p.add_argument(
        "--distro-dirs", action="store_true", help="Give each distro a directory of its own"
    )
    init_p.add_argument(
        "--fetch-from",
        action=_Once,
        metavar="PREFIX",
        help=(
            "Fetch every repo from another place: the url PREFIX, the repo's name and .git"
            " (such as git@git.example.org:field/); a repo missing there is an error"
        ),
    )
    init_p.add_argument("--yes", action="store_true", help="Set up without asking")
    init_p.set_defaults(func=cmd_init, parser=init_p)

    sync_p = sub.add_parser(
        "sync",
        help=(
            "Resolve the system's manifest again, clone the repos that are missing and update"
            " the ones that are there"
        ),
    )
    sync_p.add_argument(
        "--distro", action="append", help="Sync only this distro; may be given more than once"
    )
    sync_p.set_defaults(func=cmd_sync, parser=sync_p)

    status_p = sub.add_parser(
        "status",
        help=(
            "Show what the system directory holds against what the manifest says; changes"
            " nothing and fetches no repo (a manifest recorded in a git repo is read from it)."
            " Exit status 1 when a repo that is not optional is not at its place or cannot be"
            " used"
        ),
    )
    status_p.add_argument(
        "--distro", action="append", help="Show only this distro; may be given more than once"
    )
    status_p.add_argument(
        "--json", action="store_true", help="Print one JSON document a script can read"
    )
    status_p.set_defaults(func=cmd_status, parser=status_p)

    build_p = sub.add_parser(
        "build",
        help=(
            "Build one distro's layers in order with colcon and write its setup.bash; arguments"
            " after -- go to colcon for every layer"
        ),
        usage="%(prog)s [-h] [--distro DISTRO] [--keep-going] [LAYER ...] [-- COLCON_ARGS ...]",
        epilog=(
            "Arguments after -- are passed to colcon for every layer built; --base-paths,"
            " --paths, --install-base and --build-base are refused."
        ),
    )
    build_p.add_argument(
        "--distro", action=_Once, help="The distro to build, when there are several; once"
    )
    build_p.add_argument(
        "--keep-going",
        action="store_true",
        help=(
            "After a layer fails, still try the later ones, each on the layers below it that"
            " are built; what they build is not used until the failed layer is fixed"
        ),
    )
    build_p.add_argument(
        "layers", nargs="*", metavar="LAYER", help="Build only these layers (default: every one)"
    )
    build_p.set_defaults(func=cmd_build, parser=build_p, colcon_args=[])

    return parser


def main(argv=None) -> int:
    parser = build_parser()
    argv = list(sys.argv[1:] if argv is None else argv)
    passed: list = []
    if argv[:1] == ["build"] and "--" in argv:
        # What follows the first `--` goes to colcon; argparse would take it as layer names.
        at = argv.index("--")
        argv, passed = argv[:at], argv[at + 1 :]
    args = parser.parse_args(argv)
    if passed:
        args.colcon_args = passed
    try:
        return args.func(args)
    except ManifestError as exc:
        print(f"ERROR: {mask_urls(str(exc))}", file=sys.stderr)
        return 1
    except Exception as exc:
        # The backstop for a route the loader does not turn into a ManifestError: the
        # exception's text, and a traceback, can quote manifest content. Only its type is shown.
        print(f"ERROR: internal error ({type(exc).__name__})", file=sys.stderr)
        return 1


_STOP_SIGNALS = tuple(
    getattr(signal, name) for name in ("SIGINT", "SIGTERM", "SIGHUP") if hasattr(signal, name)
)


def run() -> None:
    """The command's entry point. A run stopped by a signal has printed its message and removed
    its temporary output; the process then ends by that signal, as a tool does, so that a shell
    loop over `resolve` stops on a Ctrl-C. (For SIGTERM and SIGHUP `_stopped` has delivered it
    already; Python's own SIGINT handler would raise KeyboardInterrupt instead.)"""
    code = main()
    signum = code - 128
    if signum in _STOP_SIGNALS:
        signal.signal(signum, signal.SIG_DFL)
        signal.raise_signal(signum)
    sys.exit(code)


if __name__ == "__main__":
    run()
