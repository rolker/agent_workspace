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
the emails checked are the author and the committer exactly as git will
record them (`git var GIT_AUTHOR_IDENT` / `GIT_COMMITTER_IDENT`: the
GIT_*_EMAIL variables, `author.email` / `committer.email` / `user.email`
in any config file and `git -c` values all count). An unset or malformed
configured email blocks the commit.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import identity_base  # noqa: E402  pylint: disable=wrong-import-position

DERIVED_COMMAND = 'source .agent/scripts/set_git_identity_env.sh --agent <framework> "<model-id>"'


def main():
    """Verify commit identity is configured correctly."""
    try:
        local, domain = identity_base.configured_base()
    except identity_base.IdentityError as exc:
        print()
        print(f"ERROR: {exc}")
        print()
        return 1

    rejected = []
    for kind, label in (("AUTHOR", "Author email"), ("COMMITTER", "Committer email")):
        email = identity_base.ident_email(kind)
        if not identity_base.is_accepted(email, local, domain):
            rejected.append((label, email))
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
