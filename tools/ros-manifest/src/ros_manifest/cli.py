"""`ros-manifest` CLI: resolve and validate."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .emit import emit_manifest
from .extends import resolve_chain
from .merge import merge_chain
from .schema import ManifestError
from .selectors import select_repos
from .validate import build_validation_table, check_dependencies


def _load_merged(manifest_path: str, cache_dir: str | None):
    chain = resolve_chain(Path(manifest_path), Path(cache_dir) if cache_dir else None)
    return merge_chain(chain)


def cmd_resolve(args: argparse.Namespace) -> int:
    merged = _load_merged(args.manifest, args.cache_dir)
    if args.role not in merged.roles:
        print(f"ERROR: unknown role '{args.role}' (known: {sorted(merged.roles)})", file=sys.stderr)
        return 1
    selected = select_repos(merged, args.role)
    written = emit_manifest(merged, selected, args.role, args.distro, Path(args.out))
    if not written:
        print(
            f"WARNING: role '{args.role}' distro '{args.distro}' selected zero repos",
            file=sys.stderr,
        )
    for layer, path in written.items():
        print(f"wrote {path} ({layer})")
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ros-manifest", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    resolve_p = sub.add_parser(
        "resolve", help="Resolve a manifest for a role/distro and emit .repos files"
    )
    resolve_p.add_argument("--manifest", required=True, help="Path to the leaf manifest YAML file")
    resolve_p.add_argument("--role", required=True)
    resolve_p.add_argument("--distro", required=True)
    resolve_p.add_argument("--out", required=True, help="Output directory for <layer>.repos files")
    resolve_p.add_argument("--cache-dir", default=None, help="Cache dir for git-backed extends")
    resolve_p.set_defaults(func=cmd_resolve)

    validate_p = sub.add_parser(
        "validate", help="Print the per-role validation table and dependency check"
    )
    validate_p.add_argument("--manifest", required=True)
    validate_p.add_argument("--role", required=True)
    validate_p.add_argument("--distro", required=True)
    validate_p.add_argument("--cache-dir", default=None)
    validate_p.set_defaults(func=cmd_validate)

    return parser


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except ManifestError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
