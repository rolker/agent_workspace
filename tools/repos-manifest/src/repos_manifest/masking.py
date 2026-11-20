"""Masking the user name and password of a url in what the tool prints (``docs/design.md``,
"sync"). It is a guard against accidents, not a guarantee: a credential belongs in a credential
helper or an ssh key, not in a manifest url.

Every url the tool reads (a manifest's, a clone's `origin`, a recorded one) is registered with
`remember_url`, which parses the url whole: its user information (a `file://` url's aside,
below) is everything between `://` and the last `@` in it, whatever characters it holds
(quotes, spaces, `@`, `:`, `/`, `%` escapes, any letter). `mask_urls` replaces each
registered user information, and its percent-decoded form, where it follows `://` in a text,
and then masks any other
`scheme://...@host` it finds by a pattern, for a url the tool did not read itself (one git
prints after an `insteadOf` rewrite). Nothing not after `://` is masked: a local path holding
`@`, `git@github.com:...` and `origin/main@{upstream}` are printed as they are. In a `file://`
url, user information is only in its authority, the text between `file://` and the first `/`
after it: the text before the last `@` there, when that text holds a `:`. A path is never
masked (`file:///srv/w@x/...`, `file://localhost/srv/a:b/w@x`), and so neither is a password
that holds a `/`, which cannot be told from a path. An https url whose path holds an `@` can
have more masked than its user information; never less.

Messages that put a url into text where the source scan sees it, and the manifest reader's
messages, do it through `mask_url` (plain) or `quoted_url` (quoted for display, as `repr`
would), so a url is masked before it is quoted or escaped.
`quoted_url` given a value that is not a string shows only what kind of value it is (`a list`,
`a mapping`), nothing of its content. A test walks the tool's source for values formatted into
text whose names say they are urls (``tests/test_url_messages.py`` names what it cannot see).
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
    """The scheme and the user information of a whole url (its first `scheme://`, wherever it
    is, as in git's `<transport>::<address>` form), or None when it has none."""
    match = SCHEME.search(url)
    if match is None:
        return None
    if match.group(0).lower() == "file://":
        userinfo = _file_userinfo(url[match.end() :])
        return None if userinfo is None else (match.group(0), userinfo)
    at = url.rfind("@", match.end())
    if at < 0:
        return None
    return match.group(0), url[match.end() : at]


def _file_userinfo(rest: str) -> Optional[str]:
    """The user information of a `file://` url, from the text after `file://`: only in the
    authority, the text before the first `/`, and only the text before the last `@` there when
    it holds a `:` (`user:password@host/srv/w@x`: the `@` in the path is not part of it). A path
    is never masked, so a password holding a `/` (`user:pass/word@host/...`) is not either: it
    cannot be told from a path, and git's file transport ignores user information."""
    slash = rest.find("/")
    head = rest if slash < 0 else rest[:slash]
    at = head.rfind("@")
    if at >= 0 and ":" in head[:at]:
        return head[:at]
    return None


def _kept(scheme: str, userinfo: str) -> bool:
    """An ssh url's user name alone names an account, as in `ssh://git@host/...`. In a
    `file://` url, text before an `@` that holds a `/` reaches into the path, which is never
    masked, and a bare name is not a secret either; only an authority's `user:password` is."""
    if scheme.lower() == "file://":
        return "/" in userinfo or ":" not in userinfo
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
        # Only right after a scheme, and by the same rule as any url: an ssh url's bare user
        # name and a file url are kept, whichever url registered the text.
        pattern = re.compile(r"([A-Za-z][A-Za-z0-9+.-]*://)(" + re.escape(info) + r")@")
        text = pattern.sub(_masked, text)
    return _FALLBACK.sub(_masked, text)


def mask_url(url: str) -> str:
    """One whole url as it is shown: parsed, not matched."""
    remember_url(url)
    return mask_urls(url)


def type_name(value: object) -> str:
    """What kind of value `value` is, in words (`a list`, `a mapping`), for a message that
    describes a value of the wrong type without showing it."""
    if value is None:
        return "nothing"
    if isinstance(value, bool):
        return "true or false"
    return {dict: "a mapping", list: "a list", str: "a string"}.get(
        type(value), f"a {type(value).__name__}"
    )


def quoted_url(value: object) -> str:
    """A url, or any value a message quotes where a url may be. A string is shown as `repr`
    would show it, with the user information masked first, so no escaping can hide it from the
    masking. Any other value (a list, a mapping, a number) is described by its kind alone, with
    nothing of its content: a url inside it is never parsed, so it is never shown."""
    if isinstance(value, str):
        return repr(mask_url(value))
    return type_name(value)
