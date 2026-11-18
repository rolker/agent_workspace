"""`repos-manifest` CLI: resolve and validate.

A manifest with a top-level `repositories:` key is read by the reader for the format in
docs/spec.md (``manifest.py``); any other file, one that does not read or parse included, by
the reader for the earlier shape (``schema.py`` and ``extends.py``).
"""

from __future__ import annotations

import argparse
import signal
import sys
from contextlib import contextmanager
from pathlib import Path

from . import manifest as new_manifest
from . import output, selection
from .emit import LAYOUT_FLAT, LAYOUT_MANIFEST_DIR, LAYOUTS, emit_manifest
from .extends import resolve_chain
from .merge import merge_chain
from .schema import ManifestError
from .selectors import select_repos
from .validate import build_validation_table, check_dependencies


def _load_merged(manifest_path: str, cache_dir: str | None):
    chain = resolve_chain(Path(manifest_path), Path(cache_dir) if cache_dir else None)
    return merge_chain(chain)


def _require_old_flags(args: argparse.Namespace) -> None:
    """The earlier shape needs --role and --distro, and takes no --with."""
    missing = [
        flag for flag, value in (("--role", args.role), ("--distro", args.distro)) if not value
    ]
    if missing:
        args.parser.error(f"the following arguments are required: {', '.join(missing)}")
    if getattr(args, "with_groups", None):
        args.parser.error("--with is for a manifest in the format of docs/spec.md")


class Stopped(BaseException):
    """SIGTERM or SIGHUP arrived while resolving."""

    def __init__(self, signum: int):
        super().__init__(signum)
        self.signum = signum


@contextmanager
def _signals_end_the_run():
    """While resolving, SIGTERM and SIGHUP end the run through an exception, so that the
    `finally` blocks that remove temporary output run. A signal that was ignored stays ignored."""
    previous = {}

    def on_signal(signum, _frame):
        raise Stopped(signum)

    for name in ("SIGTERM", "SIGHUP"):
        sig = getattr(signal, name, None)
        if sig is None or signal.getsignal(sig) in (signal.SIG_IGN, None):
            continue
        try:
            previous[sig] = signal.signal(sig, on_signal)
        except ValueError:  # not the main thread: signals cannot be caught here
            pass
    try:
        yield
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def _stopped(exc: Stopped, replaced_out=None) -> int:
    """`replaced_out` is the `--out` the new output had replaced when the signal came, if it
    had: a signal held during the swap is delivered after it."""
    name = signal.Signals(exc.signum).name
    if replaced_out is None:
        print(f"ERROR: stopped by {name}; nothing was written", file=sys.stderr)
    else:
        print(
            f"ERROR: stopped by {name} after --out {replaced_out} was replaced by the new output",
            file=sys.stderr,
        )
    # The previous handlers are back: the signal is delivered again, to end the process as it
    # would have or to run the caller's own handler.
    signal.raise_signal(exc.signum)
    return 128 + exc.signum


def _load_new(args: argparse.Namespace) -> new_manifest.Manifest:
    loaded = new_manifest.load_manifest(Path(args.manifest), source=args.manifest)
    for warning in loaded.warnings:
        print(f"WARNING: {warning}", file=sys.stderr)
    return loaded


def cmd_resolve_new(args: argparse.Namespace) -> int:
    if args.layout is not None:
        raise ManifestError(
            f"--layout {args.layout} is not available yet for a manifest in the format of"
            " docs/spec.md; leave it out for the default layout"
        )
    if args.cache_dir is not None:
        raise ManifestError("--cache-dir is for a manifest in the earlier format")
    replaced = []
    try:
        with _signals_end_the_run():
            loaded = _load_new(args)
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


def cmd_validate_new(args: argparse.Namespace) -> int:
    if args.cache_dir is not None:
        raise ManifestError("--cache-dir is for a manifest in the earlier format")
    loaded = _load_new(args)
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


def cmd_resolve(args: argparse.Namespace) -> int:
    if new_manifest.has_repositories_key(Path(args.manifest)):
        return cmd_resolve_new(args)
    _require_old_flags(args)
    if args.layout is None:
        args.layout = LAYOUT_FLAT
    merged = _load_merged(args.manifest, args.cache_dir)
    if args.role not in merged.roles:
        print(f"ERROR: unknown role '{args.role}' (known: {sorted(merged.roles)})", file=sys.stderr)
        return 1
    selected = select_repos(merged, args.role)
    out = Path(args.out)
    try:
        written = emit_manifest(merged, selected, args.role, args.distro, out, layout=args.layout)
    except OSError as exc:
        print(
            f"ERROR: --out {out}: cannot be written ({exc.strerror or 'an OS error'})",
            file=sys.stderr,
        )
        return 1
    if not written:
        print(
            f"WARNING: role '{args.role}' distro '{args.distro}' selected zero repos",
            file=sys.stderr,
        )
    for layer, path in written.items():
        print(f"wrote {path} ({layer})")
    if args.layout == LAYOUT_MANIFEST_DIR:
        print(f"wrote {out / 'layers.txt'}")
        print(f"wrote {out / 'optional_layers.txt'}")
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    if new_manifest.has_repositories_key(Path(args.manifest)):
        return cmd_validate_new(args)
    _require_old_flags(args)
    merged = _load_merged(args.manifest, args.cache_dir)
    if args.role not in merged.roles:
        print(f"ERROR: unknown role '{args.role}' (known: {sorted(merged.roles)})", file=sys.stderr)
        return 1
    rows = build_validation_table(merged, args.role, args.distro)
    width = max((len(r.repo) for r in rows), default=4)
    for row in rows:
        status = "INCLUDE" if row.included else "exclude"
        print(f"  {row.repo:<{width}}  [{row.layer:<12}]  {status:<8}  {row.reason}")
    violations = check_dependencies(merged, args.role, args.distro)
    if violations:
        print(f"\n{len(violations)} dependency violation(s):", file=sys.stderr)
        for v in violations:
            print(f"  - {v}", file=sys.stderr)
        return 1
    print("\nno dependency violations")
    return 0


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
    resolve_p.add_argument(
        "--layout",
        choices=LAYOUTS,
        default=None,
        help=(
            "For a manifest in the earlier format only. flat (default): <out>/<layer>.repos"
            " only. manifest-dir: <out>/repos/<layer>.repos plus <out>/layers.txt and"
            " <out>/optional_layers.txt"
        ),
    )
    resolve_p.add_argument("--cache-dir", default=None, help="Cache dir for git-backed extends")
    resolve_p.set_defaults(func=cmd_resolve, parser=resolve_p)

    validate_p = sub.add_parser(
        "validate",
        help=(
            "Check a manifest: for the format of docs/spec.md, the file and every role and"
            " distro it lists; for the earlier format, the per-role table and dependency check"
        ),
    )
    validate_p.add_argument("--manifest", required=True)
    validate_p.add_argument("--role", help="Check only this role")
    validate_p.add_argument("--distro", help="Check only this distro")
    _add_with(validate_p)
    validate_p.add_argument("--cache-dir", default=None)
    validate_p.set_defaults(func=cmd_validate, parser=validate_p)

    return parser


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except ManifestError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:
        # The backstop for a route the loader does not turn into a ManifestError: the
        # exception's text, and a traceback, can quote manifest content. Only its type is shown.
        print(f"ERROR: internal error ({type(exc).__name__})", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
