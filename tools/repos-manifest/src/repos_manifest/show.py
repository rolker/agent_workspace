"""What a manifest comes to for a machine, for a person to read (design: "show").

A renderer only: it takes what `selection.resolve` produced and reads no file and no system
directory. `render` is what `show` prints; `init` prints `render_head` once and `render_body`
for each distro it sets up. Every url is printed through `masking.mask_url`.
"""

from __future__ import annotations

from typing import List, Optional

from .manifest import UNNAMED_LAYER
from .masking import mask_url, mask_urls
from .selection import ABSENT_NO_DISTRO, GROUP_OFF, NOT_ON_DISTRO, LeftOut, Resolved

DEFAULT_BRANCH = "(its default branch)"
NONE = "(none)"
UNNAMED_LAYER_HEADING = "(unnamed layer)"
NOTHING_SELECTED = "no repo is selected for this machine"
GAP = "   "  # between the columns of a repo's line


def _name(value: Optional[str]) -> str:
    return value if value is not None else NONE


def render_head(resolved: Resolved, distro: bool = False) -> str:
    """The `manifest` line, a `base` line for each manifest it builds on (reading order), and
    the role line with the groups on; with `distro`, the role line also names the distro."""
    lines = [f"manifest  {mask_urls(resolved.source)}"]
    lines += [f"base      {mask_urls(parent)}" for parent in resolved.bases]
    groups = ", ".join(resolved.groups_on) if resolved.groups_on else NONE
    role = f"role      {_name(resolved.role)}    groups on: {groups}"
    if distro:
        role += f"    distro: {_name(resolved.distro)}"
    lines.append(role)
    return "\n".join(lines)


def reason_words(left: LeftOut) -> str:
    """Why a repo is left out, in the words `show` prints."""
    if left.reason == GROUP_OFF:
        if len(left.groups) == 1:
            return f"group {left.groups[0]} is off"
        return f"none of its groups ({', '.join(left.groups)}) is on"
    if left.reason == NOT_ON_DISTRO:
        return f"not on {left.distro}"
    if left.reason == ABSENT_NO_DISTRO:
        return "absent, and no distro adds it"
    raise ValueError(f"unknown reason {left.reason!r}")


def _version(version: Optional[str]) -> str:
    return version if version is not None else DEFAULT_BRANCH


def render_body(resolved: Resolved) -> str:
    """Each layer with its repos (key, version, url, `optional`, and the manifest the entry
    came from when that is not the first in the chain), then the repos left out and why."""
    repos = [repo for layer in resolved.layers for repo in layer.repos]
    keys = [repo.key for repo in repos] + [left.key for left in resolved.left_out]
    key_width = max((len(key) for key in keys), default=0)
    version_width = max((len(_version(r.version)) for r in repos), default=0)
    from_indent = 2 + key_width + len(GAP) + version_width + len(GAP)
    first = resolved.chain[0]
    lines: List[str] = []
    for layer in resolved.layers:
        lines.append(UNNAMED_LAYER_HEADING if layer.name == UNNAMED_LAYER else layer.name)
        for repo in layer.repos:
            line = (
                f"  {repo.key:<{key_width}}{GAP}{_version(repo.version):<{version_width}}{GAP}"
                f"{mask_url(repo.url)}"
            )
            if repo.optional:
                line += f"{GAP}optional"
            lines.append(line)
            if repo.source and repo.source != first:
                lines.append(" " * from_indent + f"from {mask_urls(repo.source)}")
    blocks = ["\n".join(lines) if lines else NOTHING_SELECTED]
    if resolved.left_out:
        left_lines = ["left out"]
        for left in resolved.left_out:
            left_lines.append(f"  {left.key:<{key_width}}{GAP}{reason_words(left)}")
        blocks.append("\n".join(left_lines))
    return "\n\n".join(blocks)


def render(resolved: Resolved) -> str:
    """What `show` prints: the head with the distro on the role line, then the body."""
    return f"{render_head(resolved, distro=True)}\n\n{render_body(resolved)}"
