"""`sync`, part 1: resolve every selected distro, then clone each repo that is missing. A repo
that is already there is not touched.

A missing repo is cloned by one `vcs import` of a one-repo `.repos` text into a temporary
directory in `.repos-manifest/`; on exit status 0 the clone is renamed into its place. So a
path below a layer's `src/` is always a complete clone or something a person put there, and
the only thing this module removes is a temporary directory of its own name pattern.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Sequence, Tuple

import yaml

from . import output, selection
from .output import output_files, write_output
from .selection import Resolved, Selected
from .signals import Stopped, signal_name, signals_end_the_run, stop_exit
from .yamlload import ManifestError
from .system import (
    SETUP_TEXT,
    SYSTEM_DIR,
    TEMP_NAME,
    TEMP_PREFIX,
    Config,
    Parts,
    Refusal,
    RepoRecord,
    distros_for,
    find_system,
    is_in_place,
    layer_src_parts,
    oserror_message,
    put_distro_state,
    read_config,
    read_manifest,
    read_state,
    replace_file,
    reporting_oserror,
    resolved_parts,
    setup_parts,
    warn,
)

FINISH = "run `repos-manifest sync` to finish"


def require_tools() -> None:
    """`vcs` and `git` are on PATH, and `vcs --version` runs; what it prints is not read."""
    vcs = shutil.which("vcs")
    if vcs is None:
        raise Refusal("`vcs` is not found on PATH", "Install vcs2l or vcstool, which provide it")
    try:
        works = (
            subprocess.run(
                [vcs, "--version"],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            ).returncode
            == 0
        )
    except OSError:
        works = False
    if not works:
        raise Refusal(f"`{vcs} --version` does not run", "Repair or reinstall vcs2l or vcstool")
    if shutil.which("git") is None:
        raise Refusal("`git` is not found on PATH", "Install git")


def sweep_temporaries(directory: Path) -> None:
    """Remove what a run that has ended left in `directory`: an entry whose whole name is a
    temporary's, that is not a link, and whose process has ended. Nothing else is looked
    into. Called once per run, before the run makes anything there."""
    if not directory.is_dir():
        return
    for entry in directory.iterdir():
        match = TEMP_NAME.fullmatch(entry.name)
        if match is None or entry.is_symlink():
            continue
        if output._process_has_ended(int(match.group("pid"))):
            _remove_temporary(entry)


def _remove_temporary(path: Path) -> None:
    """Remove a temporary this tool made. One that cannot be removed (a clone may still be
    writing into it) is a warning: the next run's sweep removes it."""
    try:
        if path.is_dir() and not path.is_symlink():
            output._make_writable(path)
            shutil.rmtree(path)
        else:
            path.unlink()
    except OSError as exc:
        warn(f"{oserror_message(exc)}; a temporary of this tool, left for the next run to remove")


@dataclass
class RepoResult:
    path: str  # below the system directory
    outcome: str  # cloned, present, skipped (optional), failed
    detail: str = ""
    commit: Optional[str] = None


CLONED, PRESENT, SKIPPED, FAILED = "cloned", "present", "skipped", "failed"


def one_repo_text(layer_text: str, key: str) -> str:
    """The `.repos` text for one repo, taken from its layer's resolved file."""
    entry = yaml.safe_load(layer_text)["repositories"][key]
    return yaml.safe_dump({"repositories": {key: entry}}, default_flow_style=False, width=4096)


def vcs_import(directory: Path, text: str) -> Tuple[int, str]:
    """`vcs import <directory>` with `text` on stdin; its exit status and what it printed. A
    prompt of git or ssh goes to the terminal."""
    done = subprocess.run(
        ["vcs", "import", str(directory)],
        input=text,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    return done.returncode, done.stdout


def _head(path: Path) -> Optional[str]:
    done = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
    )
    return done.stdout.strip() if done.returncode == 0 else None


def clone_repo(system: Path, src: Parts, repo: Selected, text: str) -> RepoResult:
    """Clone one repo to `src/<key>` unless something is there."""
    key_parts = tuple(repo.key.split("/"))
    parts = src + key_parts
    place = system.joinpath(*parts)
    shown = "/".join(parts)
    failed = SKIPPED if repo.optional else FAILED
    if os.path.lexists(place):
        return RepoResult(shown, PRESENT)
    if not is_in_place(system, parts):
        return RepoResult(shown, FAILED, "a link on the way leads outside its place; not cloned")
    print(f"cloning {shown}", flush=True)
    temporary = Path(
        tempfile.mkdtemp(prefix=f"{TEMP_PREFIX}{os.getpid()}-", dir=system / SYSTEM_DIR)
    )
    try:
        status, printed = vcs_import(temporary, text)
        if status != 0:
            return RepoResult(shown, failed, f"vcs import exited {status}:\n{printed.rstrip()}")
        if not is_in_place(system, parts):
            return RepoResult(shown, FAILED, "a link on the way leads outside its place")
        if os.path.lexists(place):
            return RepoResult(shown, FAILED, "appeared meanwhile; left as it is")
        try:
            place.parent.mkdir(parents=True, exist_ok=True)
            os.rename(temporary.joinpath(*key_parts), place)
        except OSError as exc:
            return RepoResult(shown, FAILED, oserror_message(exc))
        return RepoResult(shown, CLONED, commit=_head(place))
    finally:
        _remove_temporary(temporary)


@dataclass
class DistroResult:
    distro: Optional[str]
    repos: List[RepoResult] = field(default_factory=list)

    def of(self, outcome: str) -> List[RepoResult]:
        return [r for r in self.repos if r.outcome == outcome]


def sync_distro(system: Path, config: Config, resolved: Resolved) -> DistroResult:
    """Bring one distro in line with what it resolved to: write its resolved files, clone what
    is missing, record what was cloned. A repo that is there is not touched."""
    distro = resolved.distro
    files = output_files(resolved)
    state = read_state(system, distro)
    resolved_dir = system.joinpath(*resolved_parts(config.layout, distro))
    write_output(
        resolved_dir, files, label=f"the resolved files' directory {resolved_dir}", again="sync"
    )
    result = DistroResult(distro)
    added = False
    try:
        for layer in resolved.layers:
            src = layer_src_parts(config.layout, distro, layer.name)
            for repo in layer.repos:
                text = one_repo_text(files[f"{layer.name}.repos"], repo.key)
                done = clone_repo(system, src, repo, text)
                result.repos.append(done)
                if done.outcome == FAILED:
                    print(f"ERROR: {done.path}: {done.detail}", flush=True)
                elif done.outcome == SKIPPED:
                    print(f"skipped {done.path} (optional): {done.detail}", flush=True)
                elif done.outcome == CLONED:
                    state.repos[repo.key] = RepoRecord(layer.name, repo.version, done.commit)
                    added = True
    finally:
        if added:
            put_distro_state(system, distro, state)
    setup = setup_parts(config.layout, distro)
    if not os.path.lexists(system.joinpath(*setup)) and is_in_place(system, setup):
        system.joinpath(*setup).parent.mkdir(parents=True, exist_ok=True)
        replace_file(system, system.joinpath(*setup), SETUP_TEXT)
    return result


def report(result: DistroResult) -> None:
    name = result.distro if result.distro is not None else "(no distro)"
    print(f"distro {name}:")
    for outcome, label in ((CLONED, "cloned"), (FAILED, "failed"), (SKIPPED, "optional, skipped")):
        repos = result.of(outcome)
        if repos:
            print(f"  {label} ({len(repos)}): {', '.join(r.path for r in repos)}")
    present = len(result.of(PRESENT))
    if present:
        print(f"  present, not touched ({present}); updating a repo that is there is not built yet")


def sync_distros(system: Path, config: Config, plan: Sequence[Resolved]) -> int:
    """Phase two of `init` and `sync`: one sweep of `.repos-manifest/`, then each distro.
    Exit status 1 when a repo that is not optional failed."""
    sweep_temporaries(system / SYSTEM_DIR)
    status = 0
    for resolved in plan:
        result = sync_distro(system, config, resolved)
        report(result)
        if result.of(FAILED):
            status = 1
    return status


def resolve_all(system: Path, config: Config, distros: Sequence[Optional[str]]) -> List[Resolved]:
    """Phase one: read the manifest and resolve each distro in memory. A failure here changes
    nothing."""
    try:
        manifest = read_manifest(config.manifest, system)
        return [
            selection.resolve(manifest, config.role, distro, config.groups) for distro in distros
        ]
    except ManifestError as exc:
        raise ManifestError(f"the manifest is what failed; nothing was changed: {exc}") from None


def run_sync(named_distros: Sequence[str]) -> int:
    cwd = Path(os.getcwd())
    with reporting_oserror():
        system = find_system(cwd)
        if system is None:
            raise ManifestError(
                f"no system directory in {cwd} or above it (no {SYSTEM_DIR}/ found); set one up"
                " with `repos-manifest init`"
            )
        config = read_config(system)
        distros = distros_for(system, config, named_distros, cwd)
        plan = resolve_all(system, config, distros)
        require_tools()
        try:
            with signals_end_the_run():
                status = sync_distros(system, config, plan)
        except Stopped as exc:
            return stop_exit(exc, f"stopped by {signal_name(exc)}; {FINISH}")
    if status:
        print(f"Some repos failed; {FINISH} once they can be fetched.")
    return status
