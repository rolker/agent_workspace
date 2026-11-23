"""`fetch_from`: every repo fetched from another place, named by a url prefix in the system's
`config.yaml` (``docs/design.md``, "Where repos are fetched from").

For each repo the url to fetch from is the prefix, the repo's name (the last part of its
published url's path, without a `.git` ending) and `.git`. `apply` gives a resolved system
those urls: each `Selected.url` becomes the built url and `Selected.published` keeps the
manifest's, so
`init`, `sync`, `status` and `show` all act on the built url through the same code, and `sync`'s
url rule moves a clone's `origin` to it.

Only `fallback: false` is built: a repo missing at the place is an error. `fallback: true` is
refused where the config is read (``system.read_config``).

The prefix is machine-local, but it becomes a git argument, so it and every url built from it
pass the rules a manifest's url passes (``manifest.check_url``), and the prefix holds no control
or invisible character.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, replace
from typing import Dict, Optional, Sequence, Tuple

from .manifest import check_url, url_path
from .masking import quoted_url, remember_url, type_name
from .selection import Layer, Resolved
from .yamlload import ManifestError, has_unsafe_char

# What a repo's name may be: it is put after the prefix, so it is one path part that cannot be
# read as an option or as `.` or `..`.
NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")


@dataclass(frozen=True)
class FetchFrom:
    prefix: str
    fallback: bool = False


class FetchFromError(ManifestError):
    """`fetch_from` cannot be applied to what the manifest resolves to."""


def repo_name(url: str) -> str:
    """The repo's name in its published url: the last part of the url's path, as the url rules
    separate the path from the scheme, user, host and port (``manifest.url_path``), with one
    trailing `/` and then one trailing `.git` taken off. The whole last part is the name, as git
    reads the path, so a `:` in it is part of it (and refused, below). A `FetchFromError` that
    says why when there is none: a url with no path after its host, an empty name (a last part
    of `.git`), or one a prefix cannot be followed by. The message names neither the url nor
    the name: the caller names the url, masked."""
    try:
        path = url_path(url, "", "url")
    except ManifestError:
        raise FetchFromError("it is not a url a manifest may name") from None
    if path.endswith("/"):
        path = path[:-1]
    last = path.rpartition("/")[2]
    if last == "":
        raise FetchFromError("it has no path after its host, so it names no repo")
    name = last[:-4] if last.endswith(".git") else last
    if name == "":
        raise FetchFromError("its last path part is '.git', which leaves the repo's name empty")
    if not NAME.fullmatch(name):
        raise FetchFromError(
            "its last path part is not a repo name a prefix can be followed by (letters,"
            " digits, '.', '_' and '-', starting with a letter or digit)"
        )
    return name


def effective_url(prefix: str, name: str) -> str:
    """The url a repo of name `name` is fetched from."""
    return f"{prefix}{name}.git"


def check_prefix(prefix: object, named: str) -> str:
    """A prefix as `config.yaml` or `--fetch-from` gives it (`named` says which), or a
    `ManifestError` that says what is wrong without showing a user name or password. A prefix
    holds no control or invisible character and no `?` or `#` (a repo's name after it would be
    in a query or a fragment, not the path). It ends in `/`, or in `:` in the `[user@]host:`
    form only, with nothing after the host: the url rules (``manifest.url_path``) read the
    whole of `x` after it as the path (`https://host:` would read the repo's name as a port,
    `/srv/mirror:` is a path on the local disk, `git@host:field:` and `user:pass@host:` have a
    path before the `:`). With a repo name after it, it is a url a manifest may name."""
    if not isinstance(prefix, str) or prefix == "":
        raise ManifestError(f"{named} is {_kind(prefix)}, not a url prefix")
    remember_url(prefix)  # before any message that quotes it
    if has_unsafe_char(prefix):
        raise ManifestError(f"{named} {quoted_url(prefix)} holds a control or invisible character")
    if "?" in prefix or "#" in prefix:
        raise ManifestError(
            f"{named} {quoted_url(prefix)} holds a '?' or a '#', so a repo's name after it"
            " would not be in the url's path"
        )
    with_name = f"{named} {quoted_url(prefix)}, with a repo name after it"
    if prefix.endswith("/"):
        check_url(prefix + "x", "", with_name)
        return prefix
    scp_like = "://" not in prefix
    if prefix.endswith(":") and scp_like:
        if url_path(prefix + "x", "", with_name) == "x":
            return prefix
        raise ManifestError(
            f"{named} {quoted_url(prefix)} ends in ':' but is not in the [user@]host: form,"
            " with nothing after the host, so a repo's name after it would not be the whole"
            " path; end it in '/'"
        )
    ends = "'/', or ':' in the [user@]host: form," if scp_like else "'/'"
    raise ManifestError(
        f"{named} {quoted_url(prefix)} does not end in {ends} so a repo's name cannot follow it"
    )


def _kind(value: object) -> str:
    """What a value that is not a prefix is, without showing it."""
    if value is None or value == "":
        return "empty"
    if isinstance(value, bool):
        return "true or false"
    if isinstance(value, (int, float)):
        return "a number"
    return type_name(value)


def apply(
    resolved: Resolved, fetch_from: FetchFrom, named: str, system: Sequence[Resolved] = ()
) -> Resolved:
    """A copy of `resolved` whose repos are fetched from `fetch_from`'s place: each repo's
    `url` is the url built from the prefix and its name, and `published` the manifest's.
    `named` says where the setting is, for messages; `system` is what every distro of the
    system resolves to, before `fetch_from` (`resolved`'s own distro may be among them).
    Refuses, with a `FetchFromError`, a repo whose name cannot follow a prefix, a built url a
    manifest could not name, and two repos selected anywhere in `resolved` and `system`
    whose names are one (ignoring case) and whose published urls differ: both would be
    fetched from one place, and one of them would be the wrong repo."""
    prefix = fetch_from.prefix
    remember_url(prefix)
    layers = []
    for layer in resolved.layers:
        repos = []
        for repo in layer.repos:
            remember_url(repo.url)
            try:
                name = repo_name(repo.url)
            except FetchFromError as exc:
                raise FetchFromError(
                    f"{named}: repo {repo.key}: its url {quoted_url(repo.url)} gives no name to"
                    f" put after the prefix: {exc}"
                ) from None
            url = effective_url(prefix, name)
            try:
                check_url(url, "", f"{named}: repo {repo.key}")
            except ManifestError as exc:
                raise FetchFromError(str(exc)) from None
            repos.append(replace(repo, url=url, published=repo.url))
        layers.append(Layer(layer.name, repos))
    # In the system's order, so each distro's message names the two repos in one order.
    distros = [resolved if other.distro == resolved.distro else other for other in system]
    if not any(other is resolved for other in distros):
        distros.insert(0, resolved)
    _one_repo_per_name(resolved, distros, prefix, named)
    return replace(resolved, layers=layers, fetch_from=prefix)


def _one_repo_per_name(
    resolved: Resolved, distros: Sequence[Resolved], prefix: str, named: str
) -> None:
    """Refuse two repos, selected in any of `distros`, whose names are one (ignoring case) and
    whose published urls differ, when `resolved` selects a repo of that name: a distro that
    selects neither is not refused for them. The same published repo in several distros, or
    listed twice, is one repo. A repo that gives no name is skipped here: it is refused where
    its own distro is applied."""
    # Imported here: `update` imports `system`, which imports this module.
    from .update import same_url  # pylint: disable=import-outside-toplevel

    mine = set()
    for layer in resolved.layers:
        for repo in layer.repos:
            try:
                mine.add(repo_name(repo.url).casefold())
            except FetchFromError:
                continue
    seen: Dict[str, Tuple[str, Optional[str], str]] = {}
    for distro in distros:
        for layer in distro.layers:
            for repo in layer.repos:
                remember_url(repo.url)
                try:
                    name = repo_name(repo.url)
                except FetchFromError:
                    continue
                if name.casefold() not in mine:
                    continue
                other = seen.setdefault(name.casefold(), (repo.key, distro.distro, repo.url))
                if same_url(other[2], repo.url):
                    continue
                first = _repo_in(other[0], other[1])
                second = _repo_in(repo.key, distro.distro)
                raise FetchFromError(
                    f"{named}: repos {first} and {second} are both named {name} at"
                    f" {quoted_url(prefix)} ({quoted_url(other[2])} and {quoted_url(repo.url)}),"
                    " so one of them would be fetched from the other's place; this version"
                    " fetches every repo from the prefix, so a system with two repos of one"
                    " name, in one distro or in two, is not fetched this way"
                )


def _repo_in(key: str, distro: Optional[str]) -> str:
    """A repo named for a message: its key, and its distro when there is one."""
    return key if distro is None else f"{key} (distro {distro})"
