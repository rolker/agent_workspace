"""Where a manifest is: a path on the local disk (a string), or a file in a git repo
(`GitLocation`), the forms of "Locations" in ``docs/spec.md`` that this version reads for the
manifest a system or `init` names.

A git location's `url`, `version` and `path` pass the rules a repo's `url` and `version` pass
("These apply to a repo and to a location ... alike"), through the one checker of
``manifest.py``; `path` is relative and has no `..` part. None of the three holds a control or
invisible character. `check_git_location` is the one function that checks them, for `init`'s
options and for `config.yaml` alike.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Tuple, Union

from .manifest import _colon_before_slash, check_url, check_version
from .masking import mask_url, quoted_url, remember_url
from .yamlload import ManifestError, has_unsafe_char

# How a git location with no `version` is shown: the repo's default branch is read.
DEFAULT_BRANCH = "(its default branch)"


@dataclass(frozen=True)
class GitLocation:
    """A file in a git repo: the repo's `url`, a branch or tag (`version`, None for the
    default branch), and the file's `path` in the repo. `published` is the url the manifest's
    repo is published at, when `url` is the one `fetch_from` built from it."""

    url: str
    version: Optional[str]
    path: str
    published: Optional[str] = None

    def label(self) -> str:
        """The location in messages and output, its url masked: `url  version  path`, with
        the published url after a url `fetch_from` built."""
        shown = mask_url(self.url)
        if self.published is not None:
            shown += f" (fetch_from, for {mask_url(self.published)})"
        version = self.version if self.version is not None else DEFAULT_BRANCH
        return f"{shown}  {version}  {self.path}"


Location = Union[str, GitLocation]


def is_path(text: str) -> bool:
    """A location written as a string is a path when it has no ':' before its first '/' (the
    spec's rule: `./a:b` is a path, `host:x` and `https://h/x` are URLs)."""
    return not _colon_before_slash(text)


def label(location: Location) -> str:
    """A location as messages name it: a path as given, a git location by `GitLocation.label`."""
    return location.label() if isinstance(location, GitLocation) else location


def check_git_location(
    url: object,
    version: object,
    path: object,
    source: str,
    named: Tuple[str, str, str] = ("url", "version", "path"),
) -> GitLocation:
    """The git location of `url`, `version` (None for the default branch) and `path`, each
    checked: the url and the version by the rules a repo's url and version pass, the path as
    relative, not starting with '-' and with no '..' part, and none of the three holding a
    control or invisible character. A path git names otherwise (`./x`, `x/`, `a//b`) passes
    here and is not found in the repo: the reader takes only the entry of exactly that name.
    An error names `source` and the value's name in `named` (`url`, `version` and `path` in
    `config.yaml`; the argument and the options on `init`'s command line)."""
    remember_url(url)  # before any message that quotes it
    for value, name in zip((url, version, path), named):
        if isinstance(value, str) and has_unsafe_char(value):
            raise ManifestError(
                f"{source}: {name}: {quoted_url(value)} holds a control or invisible character"
            )
    check_url(url, named[0], source)
    if version is not None:
        check_version(version, named[1], source)
    _check_path(path, named[2], source)
    return GitLocation(url, version, path)  # type: ignore[arg-type]


def _check_path(path: object, name: str, source: str) -> None:
    if not isinstance(path, str) or path == "":
        raise ManifestError(f"{source}: {name}: is not a path in the repo")
    if path.startswith("-"):
        raise ManifestError(
            f"{source}: {name}: {quoted_url(path)} starts with '-', which git would read as an"
            " option"
        )
    if path.startswith("/"):
        raise ManifestError(
            f"{source}: {name}: {quoted_url(path)} is absolute; the path of a file in a repo is"
            " relative to the top of the repo"
        )
    if ".." in path.split("/"):
        raise ManifestError(f"{source}: {name}: {quoted_url(path)} has a '..' part")
