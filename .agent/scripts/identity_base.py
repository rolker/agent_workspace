#!/usr/bin/env python3
"""Derive agent commit emails from the checkout's configured git email.

One parser for the commit-identity hook and the identity shell scripts
(issue #455). No address is stored anywhere in the workspace:

- base: `git config user.email` as resolved from git's config files in the
  current checkout (a clone-level value wins over the global one;
  `--global` is never used; `git -c` and GIT_CONFIG_PARAMETERS /
  GIT_CONFIG_COUNT injection are ignored), with any `+suffix` removed from
  the local part. A clone configured by
  configure_git_identity.sh holds `<local>+<framework>@<domain>`, which
  therefore still yields the same base.
- agent email: `<local>+<suffix>@<domain>`.
- accepted commit email: the base itself, `<local>+<anything>@<domain>`, or
  the configured address verbatim.

A usable address has exactly one `@`, a non-empty local part and a
non-empty domain, and no whitespace, control characters, angle brackets or
commas (the characters that break a `Name <email>` ident or a list). Any
other character is accepted, apostrophes and non-ASCII (`o'brien@x.ie`,
`jürgen@bücher.de`) included: shell safety comes from quoting where a value
is written, not from the character set. No RFC 5322 parsing beyond that.

CLI (prints the address on stdout; on an unset or malformed configured
email prints a message to stderr -- the malformed one shows the value --
and exits 1; bad usage exits 2):

    identity_base.py base
    identity_base.py agent <suffix>
"""

import os
import re
import subprocess
import sys

UNSET_MESSAGE = (
    "git user.email is not set. Run "
    "`git config --global user.email <your-address>` "
    "(or without `--global` for this clone only)"
)

INJECTED_ONLY_MESSAGE = (
    "git user.email is set only through `git -c` or the environment "
    "(GIT_CONFIG_PARAMETERS / GIT_CONFIG_COUNT): those values are ignored "
    "for the identity base, which must come from a config file. Run "
    "`git config --global user.email <your-address>` "
    "(or without `--global` for this clone only)"
)

MALFORMED_MESSAGE = (
    "git user.email {value!r} is not a usable address (expected "
    "<local>@<domain>: exactly one `@`, a non-empty local part and domain, "
    "and no whitespace, control characters, angle brackets or commas). "
    "Fix it with `git config --global user.email <your-address>` "
    "(or without `--global` for this clone only)"
)

# Deliberately simple, not RFC 5322: only what breaks the structure of an
# address or a `Name <email>` ident is refused.
_SUFFIX_RE = re.compile(r"[A-Za-z0-9._-]+")


def _breaks_structure(char):
    return char.isspace() or not char.isprintable() or char in "<>,"


def _parse(email):
    """(local, domain) of a usable address, or None when it is not one."""
    if email.count("@") != 1 or any(_breaks_structure(c) for c in email):
        return None
    local, domain = email.split("@")
    if not local or not domain:
        return None
    return local, domain


class IdentityError(Exception):
    """The configured git email is missing or not a usable address."""


def _file_config_env():
    """The environment without command-line or environment config injection.

    `git -c` (GIT_CONFIG_PARAMETERS), GIT_CONFIG_COUNT / GIT_CONFIG_KEY_<n> /
    GIT_CONFIG_VALUE_<n> and GIT_CONFIG are dropped, so the base is read from
    git's config files only (system, global, local, worktree; normal
    precedence). GIT_CONFIG_GLOBAL / GIT_CONFIG_SYSTEM / GIT_CONFIG_NOSYSTEM
    only choose which files are read, and stay.
    """
    return {
        key: value
        for key, value in os.environ.items()
        if key not in ("GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT", "GIT_CONFIG")
        and not key.startswith(("GIT_CONFIG_KEY_", "GIT_CONFIG_VALUE_"))
    }


def _git_user_email(cwd, env):
    try:
        result = subprocess.run(
            ["git", "config", "user.email"],
            capture_output=True,
            text=True,
            check=False,
            cwd=cwd,
            env=env,
        )
    except OSError:
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def configured_email(cwd=None):
    """`git config user.email` from the config files in cwd, or "" when unset.

    Never from `git -c` or GIT_CONFIG_* injection: this is the base the
    accepted set derives from.
    """
    return _git_user_email(cwd, _file_config_env())


def effective_email(cwd=None):
    """`git config user.email` as a commit in cwd would use it, `-c` included."""
    return _git_user_email(cwd, None)


def ident_email(kind, cwd=None):
    """(email, error) for the email git will record as `kind` ("AUTHOR" or
    "COMMITTER").

    `git var GIT_<kind>_IDENT` with the full environment, so every source git
    itself uses counts: GIT_<kind>_EMAIL, `<kind>.email` and `user.email` in
    any config file, and `git -c` / GIT_CONFIG_* injection. When git cannot
    resolve the ident (e.g. `user.useConfigOnly` with no `user.name`), email
    is "" and error names what git said (its `fatal:` line), so a caller
    never reports a set email as unset.
    """
    command = f"git var GIT_{kind}_IDENT"
    try:
        result = subprocess.run(
            command.split(),
            capture_output=True,
            text=True,
            check=False,
            cwd=cwd,
        )
    except OSError as exc:
        return "", f"`{command}` could not run: {exc}"
    ident = result.stdout.strip()
    start, end = ident.rfind("<"), ident.rfind(">")
    if result.returncode == 0 and 0 <= start < end:
        return ident[start + 1 : end], ""
    lines = [line.strip() for line in result.stderr.splitlines() if line.strip()]
    fatal = [line for line in lines if line.startswith("fatal:")]
    said = (fatal or lines or [f"exit {result.returncode}, no ident printed"])[-1]
    return "", f"`{command}` failed: {said}"


def split_base(email):
    """Split an address into (local, domain) with any `+suffix` removed.

    Raises IdentityError with UNSET_MESSAGE for an empty value, and with
    MALFORMED_MESSAGE (which shows the value) for anything that is not a
    plain `<local>@<domain>` (see _parse) or whose local part is empty once
    the suffix is removed.
    """
    email = (email or "").strip()
    if not email:
        raise IdentityError(UNSET_MESSAGE)
    parsed = _parse(email)
    if parsed is None:
        raise IdentityError(MALFORMED_MESSAGE.format(value=email))
    local, domain = parsed
    local = local.split("+", 1)[0]
    if not local:
        raise IdentityError(MALFORMED_MESSAGE.format(value=email))
    return local, domain


def configured_base(cwd=None):
    """(local, domain) of the checkout's configured git email.

    An email present only through `git -c` / GIT_CONFIG_* injection gets
    INJECTED_ONLY_MESSAGE rather than the plain "not set" one.
    """
    email = configured_email(cwd)
    if not email.strip() and effective_email(cwd).strip():
        raise IdentityError(INJECTED_ONLY_MESSAGE)
    return split_base(email)


def base_email(cwd=None):
    local, domain = configured_base(cwd)
    return f"{local}@{domain}"


def agent_email(suffix, cwd=None):
    """`<local>+<suffix>@<domain>` from the checkout's configured git email."""
    suffix = (suffix or "").strip()
    if not _SUFFIX_RE.fullmatch(suffix):
        raise ValueError(f"invalid agent email suffix: {suffix!r}")
    local, domain = configured_base(cwd)
    return f"{local}+{suffix}@{domain}"


def is_accepted(email, local, domain, configured=None):
    """True when email is `<local>@<domain>` or `<local>+<x>@<domain>`, or
    the configured address itself (verbatim: a configured `u+@x.org`, whose
    empty suffix gives base `u@x.org`, is what git commits with)."""
    email = (email or "").strip()
    if configured and email == configured.strip():
        return True
    parsed = _parse(email)
    if parsed is None:
        return False
    e_local, e_domain = parsed
    if e_domain.lower() != domain.lower():
        return False
    if e_local == local:
        return True
    prefix = local + "+"
    return e_local.startswith(prefix) and len(e_local) > len(prefix)


def main(argv):
    if len(argv) == 1 and argv[0] == "base":
        func = base_email
        args = ()
    elif len(argv) == 2 and argv[0] == "agent":
        func = agent_email
        args = (argv[1],)
    else:
        print("usage: identity_base.py base | identity_base.py agent <suffix>", file=sys.stderr)
        return 2
    try:
        print(func(*args))
    except IdentityError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
