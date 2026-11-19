"""Helpers for the tests of `init` and `sync`: local git repositories as remotes, manifests and
a snapshot of a directory. Imported by the tests, not collected."""

from __future__ import annotations

import hashlib
import os
import stat
import subprocess
import sys
from pathlib import Path
from typing import Dict, Iterable, Tuple

import yaml

from repos_manifest.cli import main


def git(*args, cwd=None) -> str:
    done = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True)
    return done.stdout.strip()


def make_remote(
    root: Path, name: str, branches: Iterable[str] = (), tags: Iterable[str] = ()
) -> Path:
    """A git repository at `root/name` with a commit on `main`, and a commit of its own on each
    other branch; each tag is on `main`."""
    path = root / name
    path.mkdir(parents=True)
    git("init", "-q", "-b", "main", cwd=path)
    (path / "README").write_text(f"{name}\n")
    git("add", "README", cwd=path)
    git("commit", "-q", "-m", "first", cwd=path)
    for tag in tags:
        git("tag", tag, cwd=path)
    for branch in branches:
        if branch == "main":
            continue
        git("checkout", "-q", "-b", branch, "main", cwd=path)
        (path / "BRANCH").write_text(f"{branch}\n")
        git("add", "BRANCH", cwd=path)
        git("commit", "-q", "-m", f"on {branch}", cwd=path)
        git("checkout", "-q", "main", cwd=path)
    return path


def write_manifest(path: Path, data: dict) -> Path:
    path.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
    return path


def repo(url, version=None, layer=None, optional=False, groups=None) -> dict:
    entry = {"type": "git", "url": str(url)}
    if version is not None:
        entry["version"] = version
    if layer is not None:
        entry["layer"] = layer
    if optional:
        entry["optional"] = True
    if groups:
        entry["groups"] = list(groups)
    return entry


def snapshot(top: Path) -> Dict[str, Tuple]:
    """Every entry below `top`: its type, content hash or link target, and mode. No times."""
    found: Dict[str, Tuple] = {}
    for directory, dirs, files in os.walk(top):
        for name in sorted(dirs + files):
            path = Path(directory) / name
            info = os.lstat(path)
            relative = str(path.relative_to(top))
            if stat.S_ISLNK(info.st_mode):
                found[relative] = ("link", os.readlink(path))
            elif stat.S_ISDIR(info.st_mode):
                found[relative] = ("dir", stat.S_IMODE(info.st_mode))
            else:
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                found[relative] = ("file", digest, stat.S_IMODE(info.st_mode))
    return found


def run(cwd: Path, *argv) -> int:
    """`repos-manifest <argv>` in-process, with `cwd` as the current directory."""
    previous = os.getcwd()
    os.chdir(cwd)
    try:
        return main([str(a) for a in argv])
    finally:
        os.chdir(previous)


def head(path: Path) -> str:
    return git("rev-parse", "HEAD", cwd=path)


def branch(path: Path) -> str:
    return git("rev-parse", "--abbrev-ref", "HEAD", cwd=path)


def dead_pid() -> int:
    """The process id of a process that has ended."""
    child = subprocess.run(
        [sys.executable, "-c", "import os; print(os.getpid())"],
        check=True,
        capture_output=True,
        text=True,
    )
    return int(child.stdout)


def temporaries(top: Path):
    """Every entry below `top` named like a temporary of the tool."""
    return [p for p in top.rglob(".repos-manifest-tmp-*")]


def cmake_lists(name: str, needs: str = "", bad: bool = False) -> str:
    """A plain CMake package with no compiler: it installs `<name>Config.cmake`, so a package
    in a later layer finds it with `find_package`; `needs` names one it finds; `bad` fails."""
    lines = ["cmake_minimum_required(VERSION 3.10)", f"project({name} NONE)"]
    if needs:
        lines.append(f"find_package({needs} REQUIRED)")
    if bad:
        lines.append(f'message(FATAL_ERROR "{name} is meant to fail")')
    lines += [
        f'file(WRITE ${{CMAKE_CURRENT_BINARY_DIR}}/{name}Config.cmake "set({name}_FOUND TRUE)\\n")',
        f"install(FILES ${{CMAKE_CURRENT_BINARY_DIR}}/{name}Config.cmake"
        f" DESTINATION share/{name}/cmake)",
    ]
    return "\n".join(lines) + "\n"


def make_package_remote(root: Path, name: str, needs: str = "", bad: bool = False) -> Path:
    """A remote as `make_remote` makes, holding one plain CMake package named `name`."""
    path = make_remote(root, name)
    (path / "CMakeLists.txt").write_text(cmake_lists(name, needs, bad))
    git("add", "CMakeLists.txt", cwd=path)
    git("commit", "-q", "-m", "package", cwd=path)
    return path
