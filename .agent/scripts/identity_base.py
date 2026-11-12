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
- accepted commit email: the base itself, or `<local>+<anything>@<domain>`.

CLI (prints the address on stdout; on an unset or malformed configured
email prints a message to stderr and exits 1; bad usage exits 2):

    identity_base.py base
    identity_base.py agent <suffix>
"""

import os
import subprocess
import sys

UNSET_MESSAGE = (
    "git user.email is not set (or has no valid address). Run "
    "`git config --global user.email <your-address>` "
    "(or without `--global` for this clone only)"
)


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


def split_base(email):
    """Split an address into (local, domain) with any `+suffix` removed.

    Raises IdentityError for an empty value, a value without exactly one
    `@`, whitespace, an empty local part (before or after removing the
    suffix) or an empty domain.
    """
    email = (email or "").strip()
    if not email or email.count("@") != 1 or any(c.isspace() for c in email):
        raise IdentityError(UNSET_MESSAGE)
    local, domain = email.split("@")
    local = local.split("+", 1)[0]
    if not local or not domain:
        raise IdentityError(UNSET_MESSAGE)
    return local, domain


def configured_base(cwd=None):
    """(local, domain) of the checkout's configured git email."""
    return split_base(configured_email(cwd))


def base_email(cwd=None):
    local, domain = configured_base(cwd)
    return f"{local}@{domain}"


def agent_email(suffix, cwd=None):
    """`<local>+<suffix>@<domain>` from the checkout's configured git email."""
    suffix = (suffix or "").strip()
    if not suffix or any(c in suffix for c in "@+") or any(c.isspace() for c in suffix):
        raise ValueError(f"invalid agent email suffix: {suffix!r}")
    local, domain = configured_base(cwd)
    return f"{local}+{suffix}@{domain}"


def is_accepted(email, local, domain):
    """True when email is `<local>@<domain>` or `<local>+<x>@<domain>`."""
    email = (email or "").strip()
    if email.count("@") != 1:
        return False
    e_local, e_domain = email.split("@")
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
