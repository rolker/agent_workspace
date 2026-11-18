"""`sync`, part 1: resolve every selected distro, then clone each repo that is missing. A repo
that is already there is not touched.

A missing repo is cloned by one `vcs import` of a one-repo `.repos` text into a temporary
directory in `.repos-manifest/`; on exit status 0 the clone is renamed into its place. So a
path below a layer's `src/` is always a complete clone or something a person put there, and
the only thing this module removes is a temporary directory of its own name pattern.
"""

from __future__ import annotations

import errno
import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Dict, List, Optional, Sequence, Tuple

import yaml

from . import selection
from .output import make_writable, output_files, process_has_ended, signals_held, write_output
from .selection import Resolved, Selected
from .signals import Stopped, signal_name, signals_end_the_run, stop_exit
from .yamlload import ManifestError
from .system import (
    current_directory,
    CONFIG_FILE,
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
    place_problem,
    layer_src_parts,
    oserror_message,
    put_distro_state,
    read_config,
    read_manifest,
    read_state,
    reporting_oserror,
    resolved_parts,
    setup_parts,
    warn,
)

FINISH = "run `repos-manifest sync` to finish"


Env = Dict[str, str]


def require_tools() -> Env:
    """`vcs` and `git` are on PATH, and `vcs --version` runs; what it prints is not read.
    Returns the environment every `vcs` and `git` of the run is given: this process's, without
    the variables that point git at a repository (those `git rev-parse --local-env-vars`
    names, and `GIT_NAMESPACE`, which it does not), so that a run from a git hook or
    `git submodule foreach` acts on its own clones."""
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
    local = set(done.stdout.split()) | {"GIT_NAMESPACE"}
    return {name: value for name, value in os.environ.items() if name not in local}


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
        if process_has_ended(int(match.group("pid"))):
            _remove_temporary(entry)


def _remove_temporary(path: Path) -> None:
    """Remove a temporary this tool made. One that cannot be removed (a clone may still be
    writing into it) is a warning: the next run's sweep removes it."""
    try:
        if path.is_dir() and not path.is_symlink():
            make_writable(path)
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
    fetch: bool = False  # it failed to fetch or had no HEAD, which a later sync may get past


CLONED, PRESENT, SKIPPED, FAILED = "cloned", "present", "skipped", "failed"


def one_repo_text(layer_text: str, key: str) -> str:
    """The `.repos` text for one repo, taken from its layer's resolved file."""
    entry = yaml.safe_load(layer_text)["repositories"][key]
    return yaml.safe_dump({"repositories": {key: entry}}, default_flow_style=False, width=4096)


def vcs_import(directory: Path, text: str, env: Env) -> Tuple[int, str]:
    """`vcs import <directory>` with `text` on stdin; its exit status and what it printed. A
    prompt of git or ssh goes to the terminal."""
    done = subprocess.run(
        ["vcs", "import", str(directory)],
        input=text,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
        env=env,
    )
    return done.returncode, done.stdout


def _head(path: Path, env: Env) -> Optional[str]:
    done = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    return done.stdout.strip() if done.returncode == 0 else None


def rename_failure(exc: OSError, system: Path, place: Path) -> str:
    """Why a clone could not be renamed into place. Clones are made in `.repos-manifest/`, so a
    distro or layer directory on another filesystem refuses every rename; that is said plainly,
    and nothing is copied instead. The message names the place, not the temporary, which is
    removed by the time it is read."""
    if exc.errno == errno.EXDEV:
        return (
            f"{place}: the clone, made in {system / SYSTEM_DIR}, cannot be moved there because"
            " the two are on different filesystems; a system directory must be on one filesystem"
        )
    return f"{place}: {exc.strerror or type(exc).__name__}"


def clone_repo(
    system: Path,
    src: Parts,
    repo: Selected,
    text: str,
    env: Env,
    record: Callable[[str], None],
) -> RepoResult:
    """Clone one repo to `src/<key>` unless something is there. Whatever stops a repo from
    being put in place makes an optional repo skipped and any other repo failed; this is the
    one place that decides it."""
    result = _put_in_place(system, src, repo, text, env, record)
    if result.outcome == FAILED and repo.optional:
        result.outcome = SKIPPED
    return result


def _put_in_place(
    system: Path,
    src: Parts,
    repo: Selected,
    text: str,
    env: Env,
    record: Callable[[str], None],
) -> RepoResult:
    """`record` is given the clone's commit and writes it to the state; the stop signals are
    held over the rename into place and the record together, so a stop never leaves a clone in
    place that is not recorded."""
    key_parts = tuple(repo.key.split("/"))
    parts = src + key_parts
    place = system.joinpath(*parts)
    shown = "/".join(parts)
    if os.path.lexists(place):
        if not place.is_dir():
            return RepoResult(shown, FAILED, "is there and is not a directory; left as it is")
        return RepoResult(shown, PRESENT)
    problem = place_problem(system, parts)
    if problem is not None:
        return RepoResult(shown, FAILED, f"{problem}; not cloned")
    print(f"cloning {shown}", flush=True)
    temporary = Path(
        tempfile.mkdtemp(prefix=f"{TEMP_PREFIX}{os.getpid()}-", dir=system / SYSTEM_DIR)
    )
    try:
        status, printed = vcs_import(temporary, text, env)
        if status != 0:
            detail = f"vcs import exited {status}:\n{printed.rstrip()}"
            return RepoResult(shown, FAILED, detail, fetch=True)
        problem = place_problem(system, parts)
        if problem is not None:
            return RepoResult(shown, FAILED, problem)
        if os.path.lexists(place):
            return RepoResult(shown, FAILED, "appeared meanwhile; left as it is")
        commit = _head(temporary.joinpath(*key_parts), env)
        if commit is None:
            # A remote with no commits yet clones with no HEAD; a later sync gets past it.
            detail = "the clone's HEAD cannot be read; not put in place"
            return RepoResult(shown, FAILED, detail, fetch=True)
        try:
            place.parent.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            return RepoResult(shown, FAILED, oserror_message(exc))
        with signals_held():
            try:
                os.rename(temporary.joinpath(*key_parts), place)
            except OSError as exc:
                return RepoResult(shown, FAILED, rename_failure(exc, system, place))
            record(commit)
        return RepoResult(shown, CLONED, commit=commit)
    finally:
        _remove_temporary(temporary)


@dataclass
class DistroResult:
    distro: Optional[str]
    repos: List[RepoResult] = field(default_factory=list)
    setup_failure: Optional[str] = None  # why the distro's setup.bash could not be created

    def of(self, outcome: str) -> List[RepoResult]:
        return [r for r in self.repos if r.outcome == outcome]


def sync_distro(system: Path, config: Config, resolved: Resolved, env: Env) -> DistroResult:
    """Bring one distro in line with what it resolved to: write its resolved files, clone what
    is missing, record what was cloned. A repo that is there is not touched."""
    distro = resolved.distro
    files = output_files(resolved)
    state = read_state(system, distro)
    resolved_dir = system.joinpath(*resolved_parts(config.layout, distro))
    write_output(
        resolved_dir,
        files,
        label=f"the resolved files' directory {resolved_dir}",
        again="sync",
        elsewhere=f"run `sync` from the system directory or from below it, outside {SYSTEM_DIR}/",
    )
    result = DistroResult(distro)
    for layer in resolved.layers:
        src = layer_src_parts(config.layout, distro, layer.name)
        for repo in layer.repos:

            def record(commit, layer=layer.name, repo=repo):
                state.repos[repo.key] = RepoRecord(layer, repo.version, commit)
                put_distro_state(system, distro, state)

            text = one_repo_text(files[f"{layer.name}.repos"], repo.key)
            done = clone_repo(system, src, repo, text, env, record)
            result.repos.append(done)
            if done.outcome == FAILED:
                print(f"ERROR: {done.path}: {done.detail}", flush=True)
            elif done.outcome == SKIPPED:
                print(f"skipped {done.path} (optional): {done.detail}", flush=True)
    result.setup_failure = create_setup(system, setup_parts(config.layout, distro))
    return result


def create_setup(system: Path, parts: Parts) -> Optional[str]:
    """Create `setup.bash` where nothing is, in one exclusive create, so that a file made
    meanwhile is left as it is. Returns why it could not be created, or None. The stop signals
    are held over the create and the write, and a file this call created but could not write
    whole is removed, so no empty or partial `setup.bash` is left."""
    path = system.joinpath(*parts)
    if os.path.lexists(path):
        return None
    problem = place_problem(system, parts)
    if problem is not None:
        return f"{path}: cannot be created: {problem}"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with signals_held():
            try:
                handle = open(path, "x", encoding="utf-8", newline="\n")
            except FileExistsError:
                return None  # made meanwhile, and left as it is
            try:
                with handle:
                    handle.write(SETUP_TEXT)
            except OSError:
                path.unlink()
                raise
    except OSError as exc:
        # The path once: the reason alone when the error is about the file itself.
        reason = oserror_message(exc)
        if exc.filename2 is None and exc.filename is not None and Path(exc.filename) == path:
            reason = exc.strerror or type(exc).__name__
        return f"{path}: cannot be created: {reason}"
    return None


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
    if result.setup_failure is not None:
        print(f"ERROR: {result.setup_failure}", flush=True)


def sync_distros(
    system: Path, config: Config, plan: Sequence[Resolved], env: Env
) -> List[DistroResult]:
    """Phase two of `init` and `sync`: one sweep of `.repos-manifest/`, then each distro."""
    sweep_temporaries(system / SYSTEM_DIR)
    results = []
    for resolved in plan:
        result = sync_distro(system, config, resolved, env)
        report(result)
        results.append(result)
    return results


def closing(results: Sequence[DistroResult]) -> int:
    """Print what to do about the repos that failed; returns the exit status, 1 when a repo
    that is not optional failed. Running sync again is advised only for what a sync can fix."""
    failed = [repo for result in results for repo in result.of(FAILED)]
    if any(repo.fetch for repo in failed):
        print(f"Some repos failed; {FINISH} once they can be fetched.")
    if any(not repo.fetch for repo in failed):
        print(
            "Some repos could not be put in place, and another sync will not change that: the"
            " ERROR lines above say what is in the way."
        )
    return 1 if failed or any(result.setup_failure for result in results) else 0


def resolve_all(system: Path, config: Config, distros: Sequence[Optional[str]]) -> List[Resolved]:
    """Phase one: read the manifest and resolve each distro in memory. A failure here changes
    nothing."""
    failed = "the manifest is what failed; nothing was changed"
    try:
        manifest = read_manifest(config.manifest, system)
    except ManifestError as exc:
        recorded = system / SYSTEM_DIR / CONFIG_FILE
        raise ManifestError(
            f"{failed}: {exc} (the manifest's path is `manifest` in {recorded}, taken from the"
            f" system directory {system})"
        ) from None
    try:
        return [
            selection.resolve(manifest, config.role, distro, config.groups) for distro in distros
        ]
    except ManifestError as exc:
        raise ManifestError(f"{failed}: {exc}") from None


def run_sync(named_distros: Sequence[str]) -> int:
    """A stop signal at any point ends the run with one line, which says whether anything was
    changed."""
    changing: List[bool] = []
    try:
        with signals_end_the_run():
            return _sync(named_distros, changing)
    except Stopped as exc:
        then = FINISH if changing else "nothing was changed"
        return stop_exit(exc, f"stopped by {signal_name(exc)}; {then}")


def _sync(named_distros: Sequence[str], changing: List[bool]) -> int:
    cwd = current_directory()
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
        env = require_tools()
        changing.append(True)
        results = sync_distros(system, config, plan, env)
    return closing(results)
