"""`sync`: resolve every selected distro, then, for each distro, clone each repo that is missing
and bring each one that is there in line with the manifest by the rules of ``update.py``.

A missing repo is cloned by one `vcs import` of a one-repo `.repos` text into a temporary
directory in `.repos-manifest/`; on exit status 0 the clone is renamed into its place. So a
path below a layer's `src/` is always a complete clone or something a person put there, and
the only thing this module removes is a temporary directory of its own name pattern.
"""

from __future__ import annotations

import errno
import os
import shlex
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Callable, Dict, List, Optional, Sequence, Tuple, Union

import yaml

from . import fetch_from, selection, update
from .manifest import Manifest
from .masking import mask_urls
from .output import make_writable, output_files, process_has_ended, signals_held, write_output
from .gitenv import Env, require_git
from .location import GitLocation
from .location import label as location_label
from .selection import Resolved, Selected
from .signals import Stopped, signal_name, signals_end_the_run, stop_exit
from .yamlload import ManifestError
from .system import (
    current_directory,
    CONFIG_FILE,
    DistroState,
    SETUP_TEXT,
    STATE_FILE,
    SYSTEM_DIR,
    TEMP_NAME,
    TEMP_PREFIX,
    Config,
    Parts,
    Refusal,
    RepoRecord,
    distros_for,
    find_system,
    hold_build_lock,
    place_problem,
    layer_src_parts,
    oserror_message,
    put_distro_state,
    read_built,
    read_config,
    read_recorded_manifest,
    read_state,
    reporting_oserror,
    resolved_parts,
    setup_parts,
    warn,
)

FINISH = "run `repos-manifest sync` to finish"


def require_tools() -> Env:
    """`vcs` and `git` are on PATH, and `vcs --version` runs; what it prints is not read.
    Returns the environment every `vcs` and `git` of the run is given (`gitenv.require_git`)."""
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
    return require_git()


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
    outcome: str  # cloned, present, updated, up to date, left alone, skipped (optional), failed
    detail: str = ""
    commit: Optional[str] = None
    fetch: bool = False  # it failed to fetch or had no HEAD, which a later sync may get past
    layer: Optional[str] = None
    place: Optional[Path] = None


CLONED, PRESENT, SKIPPED, FAILED = "cloned", "present", "skipped", "failed"
UPDATED, CURRENT, LEFT = update.UPDATED, update.CURRENT, update.LEFT


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
        commit = _head(temporary.joinpath(*key_parts), env)
        if commit is None:
            # A remote with no commits yet clones with no HEAD; a later sync gets past it.
            detail = "the clone's HEAD cannot be read; not put in place"
            return RepoResult(shown, FAILED, detail, fetch=True)
        problem = place_problem(system, parts)
        if problem is not None:
            return RepoResult(shown, FAILED, problem)
        if os.path.lexists(place):
            return RepoResult(shown, FAILED, "appeared meanwhile; left as it is")
        try:
            place.parent.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            return RepoResult(shown, FAILED, oserror_message(exc))
        with signals_held():
            try:
                os.rename(temporary.joinpath(*key_parts), place)
            except OSError as exc:
                return RepoResult(shown, FAILED, rename_failure(exc, system, place))
            try:
                record(commit)
            except OSError as exc:
                state_file = system / SYSTEM_DIR / STATE_FILE
                why = exc.strerror or type(exc).__name__
                raise ManifestError(
                    f"{place}: the clone is in place but was not recorded in {state_file}: {why}"
                ) from None
            except ManifestError as exc:
                raise ManifestError(
                    f"{place}: the clone is in place but was not recorded: {exc}"
                ) from None
        return RepoResult(shown, CLONED, commit=commit)
    finally:
        _remove_temporary(temporary)


@dataclass
class Planned:
    """A distro as phase one leaves it: what it resolved to, and the name and text of each of
    its resolved files, built before anything is created or changed."""

    resolved: Resolved
    files: Dict[str, str]


@dataclass
class Reported:
    """A distro phase one could not plan: it is reported, and nothing of it is changed."""

    distro: Optional[str]
    problem: str


def plan_distros(resolved: Sequence[Resolved]) -> List[Planned]:
    """Build every distro's resolved files; a manifest whose files cannot be written out (a
    head comment that would hold a control or invisible character) fails here."""
    return [Planned(each, output_files(each)) for each in resolved]


@dataclass
class DistroResult:
    distro: Optional[str]
    repos: List[RepoResult] = field(default_factory=list)
    setup_failure: Optional[str] = None  # why the distro's setup.bash could not be created
    setup_note: Optional[str] = None  # what is at setup.bash's place when it is not a file
    reported: Optional[str] = None  # why nothing of the distro was changed
    gone: List[str] = field(default_factory=list)  # recorded, left the manifest, on disk

    def of(self, outcome: str) -> List[RepoResult]:
        return [r for r in self.repos if r.outcome == outcome]


def _say(done: RepoResult) -> None:
    """The line for a repo as it is handled; an up-to-date or present repo has none. What
    `sync` or git says is passed through the masking filter (`mask_urls`), which masks a url's
    user name and password within the limits the design lists (``docs/design.md``, "sync")."""
    detail = mask_urls(done.detail)
    if done.outcome == FAILED:
        print(f"ERROR: {done.path}: {detail}", flush=True)
    elif done.outcome == SKIPPED:
        print(f"skipped {done.path} (optional): {detail}", flush=True)
    elif done.outcome == UPDATED:
        print(f"{done.path}: {detail}", flush=True)
    elif done.outcome == LEFT:
        print(f"{done.path}: left alone: {detail}", flush=True)


def layer_moved(
    system: Path, config: Config, distro: Optional[str], repo: Selected, layer: str, old: str
) -> Optional[RepoResult]:
    """The rule for a repo the manifest has given another layer: when its old place is there,
    it is not moved and nothing is cloned at the new place; the result says what to run. None
    when the old place is gone, and the repo is handled at its new place."""
    key_parts = tuple(repo.key.split("/"))
    old_parts = layer_src_parts(config.layout, distro, old) + key_parts
    new_parts = layer_src_parts(config.layout, distro, layer) + key_parts
    old_place, new_place = system.joinpath(*old_parts), system.joinpath(*new_parts)
    if not os.path.lexists(old_place):
        return None
    shown = "/".join(new_parts)
    if os.path.lexists(new_place):
        detail = (
            f"the manifest now has it in layer {layer}, and {'/'.join(old_parts)}, where it"
            " was, is there too; both are left as they are"
        )
    else:
        detail = (
            f"the manifest now has it in layer {layer}; it is in {old_place}. To move it:"
            f" mkdir -p {shlex.quote(str(new_place.parent))} &&"
            f" mv {shlex.quote(str(old_place))} {shlex.quote(str(new_place))}"
        )
    outcome = SKIPPED if repo.optional else FAILED
    return RepoResult(shown, outcome, detail, layer=layer)


def present_repo(
    system: Path,
    parts: Parts,
    repo: Selected,
    layer: str,
    state: DistroState,
    distro: Optional[str],
    env: Env,
    lock: Optional[int],
) -> RepoResult:
    """A repo whose place is there: the checks on the place, then the rules of `update.py`."""
    place = system.joinpath(*parts)
    shown = "/".join(parts)
    skip = SKIPPED if repo.optional else FAILED
    problem = place_problem(system, parts)
    if problem is not None:
        return RepoResult(shown, skip, f"{problem}; left alone")
    if not place.is_dir():
        return RepoResult(shown, skip, "is there and is not a directory; left as it is")
    state_file = system / SYSTEM_DIR / STATE_FILE

    def write(record: RepoRecord) -> None:
        state.repos[repo.key] = record
        with signals_held():
            put_distro_state(system, distro, state)

    had = state.repos.get(repo.key)
    if had is not None and had.layer != layer:
        # Moved by hand to the layer the manifest gives it: the record names where it is now,
        # whatever the rules below then do with it.
        try:
            write(replace(had, layer=layer))
        except (OSError, ManifestError) as exc:
            why = exc.strerror if isinstance(exc, OSError) else str(exc)
            return RepoResult(shown, skip, f"its record cannot be written ({why}); left as it is")
    if os.path.islink(place):
        return RepoResult(
            shown,
            LEFT,
            f"is a link to {os.readlink(place)}; sync does not update a repo through a link",
        )
    try:
        done = update.update_repo(place, repo, layer, state.repos.get(repo.key), env, lock, write)
    except OSError as exc:
        why = exc.strerror or type(exc).__name__
        raise ManifestError(
            f"{place}: the repo may have been changed and was not recorded in {state_file}: {why}"
        ) from None
    except ManifestError as exc:
        raise ManifestError(
            f"{place}: the repo may have been changed and was not recorded: {exc}"
        ) from None
    for note in done.notes:
        print(f"{shown}: {mask_urls(note)}", flush=True)
    outcome = done.outcome
    if outcome == FAILED and repo.optional:
        outcome = SKIPPED
    return RepoResult(shown, outcome, done.detail, done.commit, done.fetch, layer, place)


def sync_distro(system: Path, config: Config, planned: Planned, env: Env) -> DistroResult:
    """Bring one distro in line with what it resolved to, holding its lock throughout: write
    the resolved files built for it, clone what is missing, update what is there, record each
    repo. A lock held by a build or another sync of the distro is a `Refusal`, raised before
    anything is changed."""
    distro = planned.resolved.distro
    lock = hold_build_lock(system, distro, holder="sync")
    try:
        return _sync_distro(system, config, planned, env, lock)
    finally:
        os.close(lock)


def _sync_distro(
    system: Path, config: Config, planned: Planned, env: Env, lock: int
) -> DistroResult:
    resolved, files = planned.resolved, planned.files
    distro = resolved.distro
    state = read_state(system, distro)
    resolved_dir = system.joinpath(*resolved_parts(config.layout, distro))
    try:
        write_output(
            resolved_dir,
            files,
            label=f"the resolved files' directory {resolved_dir}",
            again="sync",
            elsewhere=(
                f"run `sync` from the system directory or from below it, outside {SYSTEM_DIR}/"
            ),
        )
    except ManifestError as exc:
        # Reported for this distro, whose repos are not touched; the other distros go on.
        raise Refusal(str(exc), "None of this distro's repos was touched") from None
    result = DistroResult(distro)
    for layer in resolved.layers:
        src = layer_src_parts(config.layout, distro, layer.name)
        for repo in layer.repos:

            def record(commit, layer=layer.name, repo=repo):
                state.repos[repo.key] = RepoRecord(layer, repo.version, commit, repo.url)
                put_distro_state(system, distro, state)

            had = state.repos.get(repo.key)
            done = None
            if had is not None and had.layer != layer.name:
                done = layer_moved(system, config, distro, repo, layer.name, had.layer)
            parts = src + tuple(repo.key.split("/"))
            if done is None and os.path.lexists(system.joinpath(*parts)):
                done = present_repo(system, parts, repo, layer.name, state, distro, env, lock)
            if done is None:
                text = one_repo_text(files[f"{layer.name}.repos"], repo.key)
                done = clone_repo(system, src, repo, text, env, record)
                done.layer = layer.name
            result.repos.append(done)
            _say(done)
    left_the_manifest(system, config, resolved, state, result)
    built_note(system, config, distro, resolved, result)
    result.setup_failure = create_setup(system, setup_parts(config.layout, distro))
    result.setup_note = setup_note(system.joinpath(*setup_parts(config.layout, distro)))
    return result


def left_the_manifest(
    system: Path, config: Config, resolved: Resolved, state: DistroState, result: DistroResult
) -> None:
    """A repo recorded and no longer in the manifest: its directory is left on disk and listed;
    the record of one whose directory is gone is dropped. Nothing is deleted."""
    distro = resolved.distro
    keys = {repo.key for layer in resolved.layers for repo in layer.repos}
    dropped = False
    for key, record in list(state.repos.items()):
        if key in keys:
            continue
        parts = layer_src_parts(config.layout, distro, record.layer) + tuple(key.split("/"))
        if os.path.lexists(system.joinpath(*parts)):
            result.gone.append("/".join(parts))
        else:
            del state.repos[key]
            dropped = True
    if dropped:
        with signals_held():
            put_distro_state(system, distro, state)


def built_note(
    system: Path, config: Config, distro: Optional[str], resolved: Resolved, result: DistroResult
) -> None:
    """For each layer `build` has built whose repos this sync cloned or moved: a line that
    says the build is behind. Only read; `build` alone writes its record. Also a line when the
    manifest's own file is in a repo this sync moved: this run read it before."""
    changed: Dict[str, int] = {}
    for done in result.repos:
        if done.outcome in (CLONED, UPDATED) and done.layer is not None:
            changed[done.layer] = changed.get(done.layer, 0) + 1
    if isinstance(config.manifest, GitLocation):
        manifest = None  # read from its repo, not from a clone in the system
    else:
        manifest = os.path.realpath(system / config.manifest)
    for done in result.of(UPDATED) if manifest is not None else ():
        if done.place is not None:
            inside = os.path.realpath(done.place) + os.sep
            if manifest.startswith(inside):
                print(
                    f"{done.path}: holds the manifest, which this sync read before it was"
                    " moved; the next sync reads its new text",
                    flush=True,
                )
    if not changed:
        return
    try:
        built = read_built(system, distro)
    except ManifestError as exc:
        warn(f"{exc}; whether a built layer is behind is not said")
        return
    for layer in resolved.layers:
        if layer.name in changed and layer.name in built:
            print(
                f"layer {layer.name} was built before and {changed[layer.name]} of its repos"
                " changed since; `repos-manifest build` brings it, and the layers above it, up"
                " to date",
                flush=True,
            )


def setup_note(path: Path) -> Optional[str]:
    """A line for what is at `setup.bash`'s place when it is not a regular file or a link to
    one, such as a directory or a dangling link; it is left as it is."""
    if os.path.lexists(path) and not path.is_file():
        return f"{path}: is there and is not a file; left as it is"
    return None


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
    if result.reported is not None:
        print("  reported above; nothing of it was changed")
        return
    for outcome, label in (
        (CLONED, "cloned"),
        (UPDATED, "updated"),
        (LEFT, "left alone"),
        (FAILED, "failed"),
        (SKIPPED, "optional, skipped"),
    ):
        repos = result.of(outcome)
        if repos:
            print(f"  {label} ({len(repos)}): {', '.join(r.path for r in repos)}")
    current = len(result.of(CURRENT))
    if current:
        print(f"  up to date ({current})")
    if result.gone:
        print(
            f"  no longer in the manifest, left on disk ({len(result.gone)}):"
            f" {', '.join(result.gone)}"
        )
    if result.setup_failure is not None:
        print(f"ERROR: {result.setup_failure}", flush=True)
    if result.setup_note is not None:
        print(f"WARNING: {result.setup_note}", flush=True)


def sync_distros(
    system: Path, config: Config, plan: Sequence[Union[Planned, Reported]], env: Env
) -> List[DistroResult]:
    """Phase two of `init` and `sync`: one sweep of `.repos-manifest/`, then each distro, which
    writes only what phase one built. A distro phase one reported, or whose lock is held, is
    reported and the others go on."""
    sweep_temporaries(system / SYSTEM_DIR)
    results = []
    for planned in plan:
        if isinstance(planned, Reported):
            result = DistroResult(planned.distro, reported=planned.problem)
            print(f"ERROR: {mask_urls(planned.problem)}", flush=True)
        else:
            try:
                result = sync_distro(system, config, planned, env)
            except Refusal as exc:
                distro = planned.resolved.distro
                result = DistroResult(distro, reported=str(exc))
                print(f"ERROR: {mask_urls(str(exc))}", flush=True)
        report(result)
        results.append(result)
    return results


def closing(results: Sequence[DistroResult]) -> int:
    """Print what to do about the repos that failed; returns the exit status, 1 when a distro
    was reported or a repo that is not optional failed. Running sync again is advised only for
    what a sync can fix."""
    failed = [repo for result in results for repo in result.of(FAILED)]
    if any(repo.fetch for repo in failed):
        print(f"Some repos failed; {FINISH} once they can be fetched.")
    if any(not repo.fetch for repo in failed):
        print(
            "Some repos could not be put in place or updated, and another sync will not change"
            " that: the ERROR lines above say what is in the way."
        )
    reported = any(result.reported is not None for result in results)
    return 1 if failed or reported or any(result.setup_failure for result in results) else 0


def recorded_manifest(system: Path, config: Config) -> str:
    """Said after a message that names the manifest by its recorded location, so that a
    relative path, taken from the system directory, is not read as taken from the current
    directory; and a file in a git repo is known to be read from the repo, not from a clone."""
    recorded = system / SYSTEM_DIR / CONFIG_FILE
    if isinstance(config.manifest, GitLocation):
        return (
            f"(the manifest is `manifest` in {recorded}: a file in a git repo, read from the"
            " repo afresh at every run)"
        )
    return (
        f"(the manifest's path is `manifest` in {recorded}, taken from the system directory"
        f" {system})"
    )


def fetch_from_named(system: Path) -> str:
    """Where a system's `fetch_from` is, for messages."""
    return f"`fetch_from` in {system / SYSTEM_DIR / CONFIG_FILE}"


def resolve_for(manifest: Manifest, config: Config, distro: Optional[str], named: str) -> Resolved:
    """What a system resolves to for `distro`: the manifest resolved with the system's role
    and groups, then, when `config.yaml` has `fetch_from`, each repo given the url built from
    its prefix (`fetch_from.apply`; `named` says where the setting is). The one place `init`,
    `sync`, `status` and `show` resolve a system, so they never differ in the urls they use.
    With `fetch_from`, every other distro the system is set up for is resolved too, so that two
    repos of one name are refused across the whole system, not only within `distro`; a distro
    that does not resolve is left out of that check (it is reported where it is resolved)."""
    resolved = selection.resolve(manifest, config.role, distro, config.groups)
    if config.fetch_from is None:
        return resolved
    system = []
    for other in config.distro_keys:
        if other == distro:
            system.append(resolved)
            continue
        try:
            system.append(selection.resolve(manifest, config.role, other, config.groups))
        except ManifestError:
            continue
    return fetch_from.apply(resolved, config.fetch_from, named, system)


def resolve_all(
    system: Path,
    config: Config,
    distros: Sequence[Optional[str]],
    changes: bool = True,
    env: Optional[Env] = None,
) -> List[Union[Planned, Reported]]:
    """Phase one: read the manifest, then resolve each distro and build its resolved files, in
    memory. A manifest that cannot be read ends the run with nothing changed; a distro that
    does not resolve, or whose files cannot be written out, is reported, and nothing of it is
    changed, while the others go on. `changes` is false for `status`, which changes nothing:
    a distro `fetch_from` refuses is then reported as refused, without `sync`'s words about
    what it left unchanged. `env` is the run's git environment, for a manifest read from a
    git repo."""
    try:
        manifest = read_recorded_manifest(system, config, env)
    except ManifestError as exc:
        said = recorded_manifest(system, config)
        raise ManifestError(
            f"the manifest is what failed; nothing was changed: {exc} {said}"
        ) from None
    if config.distros is None and manifest.distros is not None:
        # A flat system set up from a manifest with no distros: it cannot gain one.
        return [
            Reported(
                None,
                f"{location_label(config.manifest)}: the manifest now has distros"
                f" ({', '.join(manifest.distros)}), and this system directory was set up"
                " without one; nothing in it has been moved or changed. A system with distros"
                " is set up in a new directory with `repos-manifest init`, with `--distro-dirs`"
                f" to hold more than one distro. {recorded_manifest(system, config)}",
            )
        ]
    plan: List[Union[Planned, Reported]] = []
    for distro in distros:
        named = f"distro {distro}" if distro is not None else "the system"
        try:
            resolved = resolve_for(manifest, config, distro, fetch_from_named(system))
        except fetch_from.FetchFromError as exc:
            said = (
                "nothing of it has been changed"
                if changes
                else "fetch_from refuses it, so status checks none of its repos"
            )
            plan.append(Reported(distro, f"{named}: {said}: {exc}"))
            continue
        except ManifestError as exc:
            plan.append(
                Reported(
                    distro,
                    f"{named}: the manifest does not resolve for it; nothing of it has been"
                    f" moved or removed: {exc} {recorded_manifest(system, config)}",
                )
            )
            continue
        try:
            plan.extend(plan_distros([resolved]))
        except ManifestError as exc:
            plan.append(
                Reported(
                    distro,
                    f"{named}: the manifest's output is what failed; nothing of it was changed:"
                    f" {exc} {recorded_manifest(system, config)}",
                )
            )
    return plan


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
        if isinstance(config.manifest, GitLocation):
            # git is needed to read the manifest, so the tools are checked before the read.
            env = require_tools()
            plan = resolve_all(system, config, distros, env=env)
        else:
            plan = resolve_all(system, config, distros)
            env = require_tools()
        changing.append(True)
        results = sync_distros(system, config, plan, env)
    return closing(results)
