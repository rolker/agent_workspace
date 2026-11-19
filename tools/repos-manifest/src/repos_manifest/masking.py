"""The user name and password of a url are never printed (``docs/design.md``, "sync").

Every url the tool reads (a manifest's, a clone's `origin`, a recorded one) is registered with
`remember_url`, which parses the url whole: its user information is everything between `://`
and the last `@` in it, whatever characters it holds (quotes, spaces, `@`, `:`, `/`, `%`
escapes, any letter). `mask_urls` replaces each registered user information, and its
percent-decoded form, wherever it appears in a text, and then masks any other
`scheme://...@host` it finds by a pattern, for a url the tool did not read itself (one git
prints after an `insteadOf` rewrite). A url whose path holds an `@` has more masked than its
user information; never less.
"""

from __future__ import annotations

import re
from typing import Optional, Set, Tuple
from urllib.parse import unquote

SCHEME = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*://")

# The user information of the urls read in this process.
_KNOWN: Set[str] = set()

# For a url not registered: from `scheme://` to the first `@` that a host and its end follow,
# within one run of characters that are not white space.
_FALLBACK = re.compile(
    r"([A-Za-z][A-Za-z0-9+.-]*://)(\S*?)@"
    r"(?=[A-Za-z0-9._~\-\[\]]+(?::[0-9]*)?(?:[/?#\s'\"),;]|$))"
)


def userinfo_of(url: str) -> Optional[Tuple[str, str]]:
    """The scheme and the user information of a whole url, or None when it has none."""
    match = SCHEME.match(url)
    if match is None:
        return None
    at = url.rfind("@", match.end())
    if at < 0:
        return None
    return match.group(0), url[match.end() : at]


def _kept(scheme: str, userinfo: str) -> bool:
    """An ssh url's user name alone names an account, as in `ssh://git@host/...`."""
    return "ssh" in scheme.lower() and ":" not in userinfo


def remember_url(url: object) -> None:
    """Register the user information of `url`, when it has one that is masked."""
    if not isinstance(url, str):
        return
    found = userinfo_of(url)
    if found is None or not found[1] or _kept(*found):
        return
    _KNOWN.add(found[1])
    _KNOWN.add(unquote(found[1]))


def _masked(match: "re.Match[str]") -> str:
    scheme, userinfo = match.group(1), match.group(2)
    if _kept(scheme, userinfo) or userinfo == "***":
        return match.group(0)
    return f"{scheme}***@"


def mask_urls(text: str) -> str:
    """`text` with the user name and password of every url in it replaced by `***`. An ssh url's
    user name alone is kept; any other user name is masked, since an https one is often a
    token."""
    for info in sorted(_KNOWN, key=len, reverse=True):
        text = text.replace(f"{info}@", "***@")
    return _FALLBACK.sub(_masked, text)


def mask_url(url: str) -> str:
    """One whole url as it is shown: parsed, not matched."""
    remember_url(url)
    return mask_urls(url)
