"""Resolve a manifest's `extends` chain into an ordered list, base first.

Local-path extends resolve relative to the declaring manifest's own directory. Git-backed
extends (`url` + `ref` + `path`) are cloned into a cache directory with `git clone --branch
<ref> --depth 1 -- <url> <dest>`, with the transports allowed stated on the command line, and
re-used on a cache hit (same url+ref). The url and ref have already passed the allow-lists in
``schema.py``. This module only ever invokes `git clone` (and `git rev-parse` on the clone) — it
never fetches over the network in tests, which point `url` at a local git repository through a
`file://` URL (a plain local path is not an accepted url).

Provenance labels: a manifest read from the local filesystem is labelled with its file path. A
manifest read from a git-backed `extends` clone is labelled `url#ref:path@<commit>` (the commit
the clone holds), never with the cache path: a cache directory may be temporary, and the label
ends up in every generated `.repos` header. The `:` after the ref cannot be part of a git ref,
so a ref holding `/` (`release/2`) still reads unambiguously. A local-path `extends` declared
inside such a clone stays inside it (the escape check below) and is labelled the same way with
its own path.
"""

from __future__ import annotations

import hashlib
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple

from .schema import ExtendsRef, Manifest, load_manifest_file, ManifestError


# The transports a clone may use, stated here rather than left to git's defaults: the ones the
# URL allow-list in ``schema.py`` admits, and nothing else (no `ext::`, which runs a command).
_TRANSPORT_POLICY = (
    "-c",
    "protocol.allow=never",
    "-c",
    "protocol.https.allow=always",
    "-c",
    "protocol.ssh.allow=always",
    "-c",
    "protocol.file.allow=always",
)


def _cache_key(url: str, ref: str) -> str:
    digest = hashlib.sha256(f"{url}@{ref}".encode()).hexdigest()[:16]
    return digest


def _reject_option_like(value: str, field_name: str) -> None:
    if value.startswith("-"):
        raise ManifestError(
            f"extends {field_name} '{value}' looks like a command-line option "
            "(starts with '-') and is rejected to prevent git argument injection"
        )


def _clone_or_reuse(url: str, ref: str, cache_dir: Path) -> Path:
    _reject_option_like(url, "url")
    _reject_option_like(ref, "ref")
    cache_dir.mkdir(parents=True, exist_ok=True)
    dest = cache_dir / _cache_key(url, ref)
    if dest.is_dir():
        return dest
    result = subprocess.run(
        ["git", *_TRANSPORT_POLICY, "clone", "--branch", ref, "--depth", "1", "--", url, str(dest)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ManifestError(f"failed to clone extends source {url}@{ref}: {result.stderr.strip()}")
    return dest


def _head_commit(clone_dir: Path, url: str, ref: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(clone_dir), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ManifestError(
            f"cannot read the commit of extends source {url}@{ref} (clone: {clone_dir}):"
            f" {result.stderr.strip()}"
        )
    return result.stdout.strip()


@dataclass(frozen=True)
class _GitOrigin:
    """Where a manifest read from an `extends` clone came from."""

    url: str
    ref: str
    commit: str
    clone_dir: Path

    def label(self, path: Path) -> str:
        rel = path.relative_to(self.clone_dir).as_posix()
        return f"{self.url}#{self.ref}:{rel}@{self.commit}"


def _resolve_one(
    ext: ExtendsRef, declaring_dir: Path, declaring_origin: Optional[_GitOrigin], cache_dir: Path
) -> Tuple[Path, Optional[_GitOrigin]]:
    """Return the base manifest's path and its git origin (None for the local filesystem)."""
    if ext.url is None:
        base = declaring_dir.resolve()
        candidate = (base / ext.path).resolve()
        if not candidate.is_relative_to(base):
            raise ManifestError(
                f"extends path '{ext.path}' escapes its declaring directory {base}: {candidate}"
            )
        if not candidate.is_file():
            raise ManifestError(f"extends path not found: {candidate}")
        # Inside a clone, the escape check keeps it in the same clone: same origin.
        return candidate, declaring_origin
    clone_dir = _clone_or_reuse(ext.url, ext.ref, cache_dir).resolve()
    candidate = (clone_dir / ext.path).resolve()
    if not candidate.is_relative_to(clone_dir):
        raise ManifestError(
            f"extends path '{ext.path}' escapes its clone directory {clone_dir}: {candidate}"
        )
    if not candidate.is_file():
        raise ManifestError(
            f"extends path '{ext.path}' not found in {ext.url}@{ext.ref} (clone: {clone_dir})"
        )
    origin = _GitOrigin(
        url=ext.url,
        ref=ext.ref,
        commit=_head_commit(clone_dir, ext.url, ext.ref),
        clone_dir=clone_dir,
    )
    return candidate, origin


def _os_reason(exc: Exception) -> str:
    """Why a path could not be followed, without the path: an OSError's own text quotes it, and
    past the leaf that path comes from a manifest's `extends`."""
    if isinstance(exc, OSError) and exc.strerror:
        return exc.strerror
    if isinstance(exc, RuntimeError):  # `Path.resolve()` before Python 3.13: a symlink loop
        return "a symlink loop"
    return "an OS error"


def resolve_chain(manifest_path: Path, cache_dir: Optional[Path] = None) -> List[Manifest]:
    """Return the extends chain for `manifest_path`, ordered base-first, leaf last. A path that
    cannot be followed (a name too long, a symlink loop, no permission) is a ManifestError, not
    a traceback."""
    try:
        manifest_path = Path(manifest_path).resolve()
    except (OSError, RuntimeError) as exc:
        raise ManifestError(f"{manifest_path}: cannot be followed ({_os_reason(exc)})") from None
    if cache_dir is None:
        cache_dir = Path.cwd() / ".ros-manifest-cache"
    cache_dir = Path(cache_dir)

    chain: List[Manifest] = []
    seen: set = set()
    current_path = manifest_path
    current_origin: Optional[_GitOrigin] = None  # the leaf is a local file
    while True:
        key = str(current_path)
        if key in seen:
            raise ManifestError(f"extends cycle detected: {' -> '.join(list(seen) + [key])}")
        seen.add(key)
        label = current_origin.label(current_path) if current_origin else None
        manifest = load_manifest_file(current_path, source=label)
        chain.append(manifest)
        if manifest.extends is None:
            break
        try:
            current_path, current_origin = _resolve_one(
                manifest.extends, current_path.parent, current_origin, cache_dir
            )
        except (OSError, RuntimeError) as exc:
            raise ManifestError(
                f"{manifest.source}: its extends cannot be followed ({_os_reason(exc)})"
            ) from None

    chain.reverse()  # base first
    return chain
