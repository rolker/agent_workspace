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


def cmake_lists(name: str, needs: str = "", bad: bool = False, slow: bool = False) -> str:
    """A plain CMake package with no compiler: it installs `<name>Config.cmake`, so a package
    in a later layer finds it with `find_package`; `needs` names one it finds; `bad` fails;
    `slow` builds a target that appends its shell's pid to the file $SLOW_PIDS and sleeps."""
    lines = ["cmake_minimum_required(VERSION 3.10)", f"project({name} NONE)"]
    if needs:
        lines.append(f"find_package({needs} REQUIRED)")
    if bad:
        lines.append(f'message(FATAL_ERROR "{name} is meant to fail")')
    if slow:
        lines.append(f"add_custom_target(slow_{name} ALL COMMAND sh ${{CMAKE_SOURCE_DIR}}/slow.sh)")
    lines += [
        f'file(WRITE ${{CMAKE_CURRENT_BINARY_DIR}}/{name}Config.cmake "set({name}_FOUND TRUE)\\n")',
        f"install(FILES ${{CMAKE_CURRENT_BINARY_DIR}}/{name}Config.cmake"
        f" DESTINATION share/{name}/cmake)",
    ]
    return "\n".join(lines) + "\n"


def make_package_remote(
    root: Path, name: str, needs: str = "", bad: bool = False, slow: bool = False
) -> Path:
    """A remote as `make_remote` makes, holding one plain CMake package named `name`."""
    path = make_remote(root, name)
    (path / "CMakeLists.txt").write_text(cmake_lists(name, needs, bad, slow))
    git("add", "CMakeLists.txt", cwd=path)
    if slow:
        (path / "slow.sh").write_text('echo $$ >>"$SLOW_PIDS"\nexec sleep 300\n')
        git("add", "slow.sh", cwd=path)
    git("commit", "-q", "-m", "package", cwd=path)
    return path


def settled(found: Dict[str, Tuple]) -> Dict[str, Tuple]:
    """A `snapshot` without what every `sync` of a system writes though it changes no repo:
    each clone's `.git/FETCH_HEAD` (its fetch) and the distros' lock files."""
    return {
        path: entry
        for path, entry in found.items()
        if not path.endswith(".git/FETCH_HEAD")
        and not (".repos-manifest/build-" in f"/{path}" and path.endswith(".lock"))
    }


def snapshot_repo(path: Path, fetched: bool = False) -> Dict[str, object]:
    """The whole of a repo, to compare before and after: `HEAD` and the branch it is on, every
    ref (less the remote-tracking refs and tags when `fetched`: a fetch may change those),
    the configuration's text, the index, the full status with untracked and ignored files, the
    content hash and mode of every entry outside `.git` (ignored files included), the
    operations in progress, the work trees, and for each repository inside it (a submodule, or
    a clone a person made there) its `HEAD`, branch, refs, configuration and full status."""

    def out(*args):
        done = subprocess.run(
            ["git", "-C", str(path), "--no-optional-locks", *args],
            capture_output=True,
            text=True,
            check=False,
        )
        return done.returncode, done.stdout

    git_dir = Path(out("rev-parse", "--absolute-git-dir")[1].strip())
    common = Path(out("rev-parse", "--path-format=absolute", "--git-common-dir")[1].strip())
    refs = out("for-each-ref", "--format=%(refname) %(objectname)")[1].splitlines()
    if fetched:
        refs = [r for r in refs if not r.startswith(("refs/remotes/", "refs/tags/"))]
    files: Dict[str, Tuple] = {}
    for directory, dirs, names in os.walk(path):
        if Path(directory) == path and ".git" in dirs:
            dirs.remove(".git")
        if Path(directory) == path and ".git" in names:
            names.remove(".git")
        for name in sorted(dirs + names):
            entry = Path(directory) / name
            info = os.lstat(entry)
            relative = str(entry.relative_to(path))
            if stat.S_ISLNK(info.st_mode):
                files[relative] = ("link", os.readlink(entry))
            elif stat.S_ISDIR(info.st_mode):
                files[relative] = ("dir", stat.S_IMODE(info.st_mode))
            else:
                digest = hashlib.sha256(entry.read_bytes()).hexdigest()
                files[relative] = ("file", digest, stat.S_IMODE(info.st_mode))
    states = (
        "rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG"
        " sequencer index.lock"
    ).split()
    # Each repository below the top (a submodule, or a clone a person made inside): its HEAD,
    # its branch, every ref, its configuration and its full status. Its files are in `files`.
    nested = {}
    for directory, dirs, names in os.walk(path):
        if Path(directory) != path and (".git" in dirs or ".git" in names):
            inner = Path(directory)

            def sub(*args, inner=inner):
                done = subprocess.run(
                    ["git", "-C", str(inner), "--no-optional-locks", *args],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                return done.stdout

            inner_common = Path(
                sub("rev-parse", "--path-format=absolute", "--git-common-dir").strip()
            )
            nested[str(inner.relative_to(path))] = {
                "head": sub("rev-parse", "HEAD").strip(),
                "symbolic": sub("symbolic-ref", "-q", "HEAD").strip(),
                "refs": sub("for-each-ref", "--format=%(refname) %(objectname)").splitlines(),
                "config": (inner_common / "config").read_text(),
                "status": sub("status", "--porcelain=v2", "--untracked-files=all", "--ignored"),
            }
        if ".git" in dirs:
            dirs.remove(".git")
    return {
        "head": out("rev-parse", "HEAD")[1].strip(),
        "symbolic": out("symbolic-ref", "-q", "HEAD")[1].strip(),
        "refs": refs,
        "config": (common / "config").read_text(),
        "index": out("ls-files", "-s")[1],
        "status": out("status", "--porcelain=v2", "--untracked-files=all", "--ignored")[1],
        "files": files,
        "in progress": [name for name in states if os.path.lexists(git_dir / name)],
        "worktrees": out("worktree", "list", "--porcelain")[1],
        "nested repositories": nested,
    }


def commit_file(work: Path, name: str, text: str, message: str = "change") -> str:
    """Write `name` in the work tree `work`, commit it, and return the commit."""
    target = work / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)
    git("add", "-f", name, cwd=work)
    git("commit", "-q", "-m", message, cwd=work)
    return git("rev-parse", "HEAD", cwd=work)


def push_commit(remote: Path, name: str, text: str, branch: str = "main") -> str:
    """A new commit on `branch` of the (non-bare) remote `remote`, adding or changing `name`;
    the branch checked out in it afterwards is the one it had."""
    was = git("rev-parse", "--abbrev-ref", "HEAD", cwd=remote)
    git("checkout", "-q", branch, cwd=remote)
    commit = commit_file(remote, name, text, f"{name} on {branch}")
    git("checkout", "-q", was, cwd=remote)
    return commit


def make_system(root: Path, repositories: dict, name: str = "sys", **top) -> Tuple[Path, Path]:
    """A flat system made by `init` at `root/name` from a manifest of `repositories`; returns
    the system and the manifest's path. `top` adds top-level manifest keys (`layers`)."""
    data = {"format": 1, **top, "repositories": repositories}
    manifest = write_manifest(root / f"{name}.manifest.yaml", data)
    system = root / name
    system.mkdir()
    assert run(system, "init", f"../{manifest.name}", "--yes") == 0
    return system, manifest


def rewrite_manifest(manifest: Path, change) -> None:
    """Read the manifest at `manifest`, let `change` alter its data, and write it back."""
    data = yaml.safe_load(manifest.read_text())
    change(data)
    write_manifest(manifest, data)


def state_of(system: Path, distro: str = "_unnamed") -> dict:
    """The repos' records of one distro in `state.yaml`."""
    text = (system / ".repos-manifest/state.yaml").read_text()
    return yaml.safe_load(text)["distros"][distro]["repos"]
