#!/usr/bin/env python3
"""
Pre-commit hook to block commits with unconfigured or unrecognized git identity.

Agents frequently commit with wrong identity when they forget to run
set_git_identity_env.sh. This hook catches that before it becomes a problem.

No address is hardcoded (issue #455). The accepted set derives from the
checkout's configured `git config user.email` (a clone value wins over the
global one), with any `+suffix` removed: `<local>@<domain>` (the human) or
`<local>+<anything>@<domain>` (an agent). The base is read from git's
config files only, never from the environment (`git -c`,
GIT_CONFIG_PARAMETERS and GIT_CONFIG_COUNT injection are ignored for it);
the emails checked are GIT_AUTHOR_EMAIL when set, else the effective
`user.email` (a `git -c user.email=...` value included), and
GIT_COMMITTER_EMAIL when set. An unset or malformed configured email
blocks the commit.
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import identity_base  # noqa: E402  pylint: disable=wrong-import-position

DERIVED_COMMAND = 'source .agent/scripts/set_git_identity_env.sh --agent <framework> "<model-id>"'


def get_commit_email():
    """Get the email that will be used for the next commit.

    GIT_AUTHOR_EMAIL env var takes precedence over git config user.email
    (as the commit resolves it, `git -c` included).
    """
    email = os.environ.get("GIT_AUTHOR_EMAIL", "").strip()
    if email:
        return email
    return identity_base.effective_email()


def main():
    """Verify commit identity is configured correctly."""
    try:
        local, domain = identity_base.configured_base()
    except identity_base.IdentityError as exc:
        print()
        print(f"ERROR: {exc}")
        print()
        return 1

    email = get_commit_email()
    committer = os.environ.get("GIT_COMMITTER_EMAIL", "").strip()
    rejected = []
    if not identity_base.is_accepted(email, local, domain):
        rejected.append(("Current email", email))
    if committer and not identity_base.is_accepted(committer, local, domain):
        rejected.append(("Committer email (GIT_COMMITTER_EMAIL)", committer))
    if not rejected:
        return 0

    print()
    print("ERROR: Commit identity is not configured or not recognized!")
    print()
    for label, value in rejected:
        print(f"  {label}: {value or '(not set)'}")
    print()
    print("  Accepted (derived from this checkout's git user.email):")
    print(f"    {local}@{domain}, {local}+*@{domain}")
    print()
    print("  To fix, source the identity derived from the machine's git email:")
    print(f"    {DERIVED_COMMAND}")
    print("  e.g. --agent claude-code or --agent codex; or --detect.")
    print()
    print("  Likely cause: an old setup line with a literal email address, or a")
    print("  branch not yet updated from main (its scripts or hook predate the")
    print("  derived identity). Update the branch from main, then re-source.")
    print()
    return 1


if __name__ == "__main__":
    sys.exit(main())
