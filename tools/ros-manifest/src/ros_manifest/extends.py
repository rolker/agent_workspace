"""Resolve a manifest's `extends` chain into an ordered list, base first.

Local-path extends resolve relative to the declaring manifest's own directory. Git-backed
extends (`url` + `ref` + `path`) are cloned into a cache directory with `git clone --branch
<ref> --depth 1 <url> <dest>` and re-used on a cache hit (same url+ref). This module only ever
invokes `git clone` — it never fetches over the network in tests, which point `url` at a local
git repository (a `file://` path or a plain local path both work with `git clone`).
"""

from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path
from typing import List, Optional

from .schema import ExtendsRef, Manifest, load_manifest_file, ManifestError


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
        ["git", "clone", "--branch", ref, "--depth", "1", "--", url, str(dest)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ManifestError(f"failed to clone extends source {url}@{ref}: {result.stderr.strip()}")
    return dest


def _resolve_one(ext: ExtendsRef, declaring_dir: Path, cache_dir: Path) -> Path:
    if ext.url is None:
        base = declaring_dir.resolve()
        candidate = (base / ext.path).resolve()
        if not candidate.is_relative_to(base):
            raise ManifestError(
                f"extends path '{ext.path}' escapes its declaring directory {base}: {candidate}"
            )
        if not candidate.is_file():
            raise ManifestError(f"extends path not found: {candidate}")
        return candidate
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
    return candidate


def resolve_chain(manifest_path: Path, cache_dir: Optional[Path] = None) -> List[Manifest]:
    """Return the extends chain for `manifest_path`, ordered base-first, leaf last."""
    manifest_path = Path(manifest_path).resolve()
    if cache_dir is None:
        cache_dir = Path.cwd() / ".ros-manifest-cache"
    cache_dir = Path(cache_dir)

    chain: List[Manifest] = []
    seen: set = set()
    current_path = manifest_path
    while True:
        key = str(current_path)
        if key in seen:
            raise ManifestError(f"extends cycle detected: {' -> '.join(list(seen) + [key])}")
        seen.add(key)
        manifest = load_manifest_file(current_path)
        chain.append(manifest)
        if manifest.extends is None:
            break
        current_path = _resolve_one(manifest.extends, current_path.parent, cache_dir)

    chain.reverse()  # base first
    return chain
