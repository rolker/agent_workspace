"""`git` on PATH, new enough, and the environment every `git` and `vcs` of a run is given.

Its own module, imported by ``sync.py``, ``status.py`` and ``fetch.py``, so that reading a
manifest from a git repo gets the same environment as every other git the tool runs without
``fetch.py`` importing ``sync.py`` (which imports the module that imports ``fetch.py``).
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
from typing import Dict

from .yamlload import Refusal

Env = Dict[str, str]

# Named by `git rev-parse --local-env-vars` but carrying configuration, not a repository's place.
CONFIGURATION_VARIABLES = frozenset({"GIT_CONFIG_PARAMETERS", "GIT_CONFIG_COUNT"})


def require_git() -> Env:
    """`git` is on PATH, runs, and is new enough: the git half of `sync.require_tools`, for a
    command that runs git and never `vcs` (`status`), and for reading a manifest from a git
    repo. Returns the environment every `vcs` and `git` of the run is given: this process's,
    without the variables that point git at a particular repository or its parts, so that a run
    from a git hook or `git submodule foreach` acts on its own clones. Those are the names
    `git rev-parse --local-env-vars` prints, less `GIT_CONFIG_PARAMETERS` and
    `GIT_CONFIG_COUNT`, which carry configuration (`git -c`, `GIT_CONFIG_KEY_<n>`) and are
    kept, as git keeps them when it runs a command in another repository; and
    `GIT_NAMESPACE`, which that list does not name."""
    git = shutil.which("git")
    if git is None:
        raise Refusal("`git` is not found on PATH", "Install git")
    try:
        done = subprocess.run(
            [git, "rev-parse", "--local-env-vars"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        done = None
    if done is None or done.returncode != 0:
        raise Refusal(f"`{git} rev-parse --local-env-vars` does not run", "Repair or reinstall git")
    require_git_version(git)
    local = set(done.stdout.split()) - CONFIGURATION_VARIABLES | {"GIT_NAMESPACE"}
    return {name: value for name, value in os.environ.items() if name not in local}


# The oldest git that has every command `sync` runs: `git switch` (with `--no-overwrite-ignore`
# and `--detach`) came in 2.23. The others are older: a fetch that does not replace a tag
# without `--force` (2.20), `config --type` (2.18), `fetch --no-prune-tags` (2.17), `rev-parse
# --is-shallow-repository` (2.15), `status --porcelain=v2` (2.11), `worktree list --porcelain`
# and `for-each-ref --contains` (2.7), `fetch --refmap` (2.1).
GIT_MINIMUM = (2, 23)
_GIT_VERSION = re.compile(r"git version (\d+)\.(\d+)")


def require_git_version(git: str) -> None:
    """Stop with a plain message when `git --version` names a version older than
    `GIT_MINIMUM`. A version it does not print in the usual form is not judged."""
    try:
        printed = subprocess.run(
            [git, "--version"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            check=False,
            env={**os.environ, "LC_ALL": "C"},
        ).stdout
    except OSError:
        raise Refusal(f"`{git} --version` does not run", "Repair or reinstall git") from None
    match = _GIT_VERSION.match(printed.strip())
    if match is None:
        return
    found = (int(match.group(1)), int(match.group(2)))
    if found < GIT_MINIMUM:
        need = ".".join(str(n) for n in GIT_MINIMUM)
        raise Refusal(
            f"git {found[0]}.{found[1]} is on PATH, and this tool needs git {need} or later"
            " (for `git switch`); nothing was changed",
            f"Install git {need} or later",
        )
