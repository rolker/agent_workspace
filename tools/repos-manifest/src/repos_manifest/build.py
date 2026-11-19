"""`build`: build one distro's layers in the manifest's order with colcon, record each layer
that colcon built, and write the distro's one `setup.bash`.

What `build` trusts is its own record, `.repos-manifest/built-<distro>.yaml`, never colcon's
files: colcon writes `install/setup.bash` after a failed, a partial and even an empty build. A
layer counts as built when its record is there, its `install/setup.bash` is there, and the
layer that was sourced when it was built (its base) is the last layer of the built run below
it. The built run is the distro's layers from the bottom up to the first layer with repos that is
not built; layers with no repos on this machine are passed over. Three things read that one
run: a layer is built with the run's last layer below it sourced, `build <layer>` refuses
when a layer with repos below it is outside the run and not named, and `setup.bash` sources
the run's last layer. See ``docs/design.md``, "build".
"""

from __future__ import annotations

import datetime
import os
import shlex
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

import yaml

from .manifest import UNNAMED_LAYER
from .output import LAYERS_FILE, OPTIONAL_FILE, signals_held
from .signals import Stopped, signal_name, signals_end_the_run, stop_exit
from .system import (
    SETUP_MARKER,
    SETUP_TEXT,
    SYSTEM_DIR,
    Config,
    LayerRecord,
    Refusal,
    current_directory,
    distro_parts,
    find_system,
    hold_build_lock,
    note_lock_holders,
    layer_src_parts,
    one_distro_for,
    oserror_message,
    place_problem,
    put_built_layers,
    read_built,
    read_config,
    replace_file,
    reporting_oserror,
    resolved_parts,
    setup_parts,
    warn,
)
from .yamlload import ManifestError

# The variables a sourced colcon `setup.bash` extends.
PREFIX_VARIABLES = ("COLCON_PREFIX_PATH", "AMENT_PREFIX_PATH", "CMAKE_PREFIX_PATH")

# Sources the setup file given first, then runs the command given after it. The arguments are
# passed as positional parameters, never put into the script's text, and are cleared before
# the source, so the setup file sees none of them. Meanwhile they are kept in variables named
# for this tool, which no setup file or package hook sets.
_SOURCE_THEN_RUN = (
    '_repos_manifest_build_setup=$1; shift; _repos_manifest_build_command=("$@"); set --;'
    ' source "$_repos_manifest_build_setup" && exec "${_repos_manifest_build_command[@]}"'
)


@dataclass
class Layer:
    name: str
    directory: Path  # where colcon runs: the distro's directory for the unnamed layer
    listed: List[str]  # the repo keys its resolved file lists, in order
    on_disk: List[str]  # those whose directory is there
    missing: List[str] = field(default_factory=list)  # not there and not optional

    @property
    def empty(self) -> bool:
        """No repos on this machine: every repo it lists is optional and not on disk."""
        return not self.on_disk and not self.missing

    @property
    def install_setup(self) -> Path:
        return self.directory / "install" / "setup.bash"


def _plain_name(name: str) -> bool:
    return bool(name) and name not in (".", "..") and "/" not in name and "\0" not in name


def read_layers(system: Path, config: Config, distro: Optional[str]) -> List[Layer]:
    """The distro's layers in order and each one's repos, from the resolved files `sync`
    wrote: `layers.txt` and `<layer>.repos`. Nothing is resolved again."""
    resolved = system.joinpath(*resolved_parts(config.layout, distro))
    order_file = resolved / LAYERS_FILE
    try:
        text = order_file.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise ManifestError(
            f"{order_file}: not found; `build` reads the resolved files `sync` writes: run"
            " `repos-manifest sync` first"
        ) from None
    names = [line.strip() for line in text.splitlines() if line.strip() and line[0] != "#"]
    optional_file = resolved / OPTIONAL_FILE
    try:
        optional_text = optional_file.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise ManifestError(
            f"{optional_file}: not found, and `build` reads it to tell an optional repo that"
            " was skipped from one that is missing; run `repos-manifest sync` to write the"
            " resolved files again"
        ) from None
    optional = {
        line.strip() for line in optional_text.splitlines() if line.strip() and line[0] != "#"
    }
    distro_dir = system.joinpath(*distro_parts(config.layout, distro))
    layers = []
    for name in names:
        if not _plain_name(name):
            raise ManifestError(f"{order_file}: {name!r} is not a layer name")
        repos_file = resolved / f"{name}.repos"
        try:
            data = yaml.safe_load(repos_file.read_text(encoding="utf-8"))
        except FileNotFoundError:
            raise ManifestError(
                f"{repos_file}: not found, and {order_file} lists the layer; run"
                " `repos-manifest sync` to write the resolved files again"
            ) from None
        except (yaml.YAMLError, UnicodeDecodeError):
            raise ManifestError(f"{repos_file}: does not read as YAML") from None
        repositories = data.get("repositories") if isinstance(data, dict) else None
        if not isinstance(repositories, dict):
            raise ManifestError(f"{repos_file}: has no `repositories` mapping")
        listed = [str(key) for key in repositories]
        for key in listed:
            if not all(_plain_name(part) for part in key.split("/")):
                raise ManifestError(f"{repos_file}: {key!r} is not a repo key")
        src = system.joinpath(*layer_src_parts(config.layout, distro, name))
        on_disk = [key for key in listed if src.joinpath(*key.split("/")).is_dir()]
        missing = [key for key in listed if key not in on_disk and key not in optional]
        directory = distro_dir if name == UNNAMED_LAYER else distro_dir / name
        layers.append(Layer(name, directory, listed, on_disk, missing))
    return layers


def missing_repos(layers: Sequence[Layer], chosen: Sequence[str]) -> None:
    """Refuse, before anything runs, a layer this run would build that lacks a repo the
    resolved files list and do not name as optional: only an optional repo may be absent."""
    missing = [
        f"{key} (layer {layer.name})"
        for layer in layers
        if layer.name in chosen
        for key in layer.missing
    ]
    if missing:
        raise Refusal(
            f"not on disk, and not optional: {', '.join(missing)}; nothing was run",
            "Run `repos-manifest sync` to clone what is missing, then build again",
        )


# --- The built run --------------------------------------------------------------------------


def why_not_built(
    layer: Layer, records: Dict[str, LayerRecord], below: Optional[str]
) -> Optional[str]:
    """Why a layer with repos does not count as built, with `below` the last layer of the built
    run under it; None when it is built."""
    record = records.get(layer.name)
    if record is None:
        return "not built"
    if not layer.install_setup.is_file():
        return f"recorded built, but {layer.install_setup} is missing"
    if record.base != below:
        was = record.base if record.base is not None else "nothing"
        now = below if below is not None else "nothing"
        return (
            f"base changed: built on top of {was}, and the built run below it now ends at"
            f" {now} (a layer below was empty, failed or rebuilt since)"
        )
    return None


@dataclass
class Run:
    layers: List[str] = field(default_factory=list)  # the layers with repos in the built run
    end: Optional[str] = None  # the first layer with repos that is not built
    why: Optional[str] = None  # why it is not

    @property
    def last(self) -> Optional[str]:
        return self.layers[-1] if self.layers else None


def built_run(layers: Sequence[Layer], records: Dict[str, LayerRecord]) -> Run:
    """The built run: from the bottom up to the first layer with repos that is not built."""
    run = Run()
    for layer in layers:
        if layer.empty:
            continue
        why = why_not_built(layer, records, run.last)
        if why is not None:
            run.end, run.why = layer.name, why
            break
        run.layers.append(layer.name)
    return run


# --- setup.bash -----------------------------------------------------------------------------


def setup_text(system: Path, layers: Sequence[Layer], records, run: Run) -> str:
    if run.last is None:
        return SETUP_TEXT
    layer = next(each for each in layers if each.name == run.last)
    real = Path(os.path.realpath(system)) / layer.directory.relative_to(system)
    return (
        f"{SETUP_MARKER} The next `repos-manifest build` replaces it.\n"
        f"# It sources the layer {layer.name}, the last layer of the built run,"
        f" built {records[layer.name].time}.\n"
        f"source {shlex.quote(str(real / 'install' / 'setup.bash'))}\n"
    )


def write_setup(system: Path, config: Config, distro: Optional[str], text: str) -> Optional[str]:
    """Write `setup.bash` whole, where nothing is or where the file there is one this tool
    wrote. Returns why it was left alone, or None. Never writes through a link."""
    parts = setup_parts(config.layout, distro)
    path = system.joinpath(*parts)
    if os.path.islink(path):
        return f"{path}: is a link; left as it is"
    if os.path.lexists(path):
        if not path.is_file():
            return f"{path}: is there and is not a file; left as it is"
        try:
            there = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            return (
                f"{path}: cannot be read ({getattr(exc, 'strerror', None) or exc}); left as it is"
            )
        if not there.startswith(SETUP_MARKER):
            return f"{path}: holds text repos-manifest did not write; left as it is"
    problem = place_problem(system, parts)
    if problem is not None:
        return f"{path}: cannot be written: {problem}"
    try:
        with signals_held():
            replace_file(system, path, text)
    except OSError as exc:
        return f"{path}: cannot be written: {exc.strerror or type(exc).__name__}"
    return None


# --- colcon ---------------------------------------------------------------------------------


def find_program(name: str, also: Sequence[str] = ()) -> Optional[str]:
    """`name` as an absolute path, looked for in the absolute entries of PATH and then in
    `also`. Empty and relative entries of PATH are passed over: they would be read against
    the layer's directory colcon runs in, not the directory `build` was run in."""
    entries = os.environ.get("PATH", "").split(os.pathsep) + list(also)
    usable = [entry for entry in entries if entry and os.path.isabs(entry)]
    found = shutil.which(name, path=os.pathsep.join(usable)) if usable else None
    return os.path.abspath(found) if found is not None else None


def find_colcon() -> str:
    """`colcon` on PATH, or beside the Python running this tool (a `colcon` installed in the
    same virtual environment), as an absolute path."""
    beside = os.path.dirname(os.path.abspath(sys.executable)) if sys.executable else ""
    found = find_program("colcon", [beside] if beside else [])
    if found is None:
        raise Refusal(
            f"`colcon` is not found on PATH or in {beside or 'the directory of this Python'};"
            " `build` needs it (empty and relative PATH entries are not searched)",
            "Install colcon (for example colcon-common-extensions) and run it again",
        )
    return found


def find_bash() -> str:
    found = find_program("bash")
    if found is None:
        raise Refusal(
            "`bash` is not found on PATH; `build` needs it to source the layer below each one"
            " (empty and relative PATH entries are not searched)",
            "Put bash on PATH and run it again",
        )
    return found


# The stop signals the tool takes while colcon runs, in the order of escalation's names.
_STOP = tuple(
    sig for sig in (getattr(signal, name, None) for name in ("SIGINT", "SIGTERM", "SIGHUP")) if sig
)
# How long the tool waits for what is left of colcon's group to go after it is killed.
_GROUP_GONE_SECONDS = 10.0


def _signal_group(pgid: int, signum: int) -> None:
    try:
        os.killpg(pgid, signum)
    except (ProcessLookupError, PermissionError):
        pass


def _end_the_rest(pgid: int) -> None:
    """After colcon itself ended on a stop: kill every process still in its group (a job that
    outlived it) and wait, a bounded time, until the group is gone. A member that is this
    process's own child (as when this process is a subreaper or PID 1) is reaped here, or it
    would stay in the group as a zombie. Members still there at the end are named in a
    warning."""
    _signal_group(pgid, signal.SIGKILL)
    deadline = time.monotonic() + _GROUP_GONE_SECONDS
    while True:
        try:
            while os.waitpid(-pgid, os.WNOHANG)[0] != 0:
                pass
        except ChildProcessError:
            pass
        try:
            os.killpg(pgid, 0)
        except (ProcessLookupError, PermissionError):
            return
        if time.monotonic() >= deadline:
            warn(
                f"processes of colcon's process group {pgid} are still there"
                f" {_GROUP_GONE_SECONDS:g} seconds after it was killed (zombies whose parent"
                f" has not reaped them, or processes that cannot be killed); `pgrep -g {pgid}`"
                " lists them"
            )
            return
        time.sleep(0.02)


def run_child(
    argv: List[str], cwd: Path, lock: Optional[int] = None
) -> Tuple[Optional[int], Optional[int]]:
    """Run colcon in a session (and so a process group) of its own and wait for it to end.
    Returns its exit status (None when it was not started) and the first stop signal, if one
    came. `lock`, the descriptor that holds the distro's build lock, is passed to colcon, so
    the lock is held while colcon runs even if this process is killed outright.

    A SIGINT, SIGTERM or SIGHUP to this process is passed on to colcon's whole group: the
    first as itself, the second as SIGTERM, every later one as SIGKILL. The tool waits for
    colcon to end however it ends; after a stop, it then kills whatever is left in colcon's
    group and waits for it to go, so no job of the stopped build runs on. A SIGTSTP (Ctrl-Z)
    stops colcon's group and then this process; a SIGCONT continues colcon's group."""
    came: List[int] = []
    group: List[int] = []
    sent = [0]

    def forward() -> None:
        while group and sent[0] < len(came):
            nth = sent[0]
            sent[0] += 1
            if nth == 0:
                signum = came[0]
            elif nth == 1:
                signum = signal.SIGTERM
            else:
                signum = signal.SIGKILL
            _signal_group(group[0], signum)
            # A group stopped by a Ctrl-Z takes the signal only once it is continued.
            if signum != signal.SIGKILL and hasattr(signal, "SIGCONT"):
                _signal_group(group[0], signal.SIGCONT)

    def on_stop(signum, _frame):
        came.append(signum)
        forward()

    def on_tstp(_signum, _frame):
        if group:
            _signal_group(group[0], signal.SIGSTOP)
        os.kill(os.getpid(), signal.SIGSTOP)

    def on_cont(_signum, _frame):
        if group:
            _signal_group(group[0], signal.SIGCONT)

    previous = {}
    handlers = [(sig, on_stop) for sig in _STOP]
    tstp = getattr(signal, "SIGTSTP", None)
    if tstp is not None and signal.getsignal(tstp) is signal.SIG_DFL:
        handlers += [(tstp, on_tstp), (signal.SIGCONT, on_cont)]
    for sig, handler in handlers:
        if signal.getsignal(sig) in (signal.SIG_IGN, None):
            continue
        try:
            previous[sig] = signal.signal(sig, handler)
        except ValueError:  # not the main thread
            pass
    child = None
    try:
        if came:
            return None, came[0]
        try:
            child = subprocess.Popen(
                argv,
                cwd=cwd,
                start_new_session=True,
                pass_fds=(lock,) if lock is not None else (),
            )
        except OSError as exc:
            raise ManifestError(
                f"{argv[0]} could not be started in {cwd}: {exc.strerror or type(exc).__name__}"
            ) from None
        if lock is not None:
            note_lock_holders(lock, [os.getpid(), child.pid])
        # A signal that came while colcon was being started is passed on now. The stop
        # signals are held meanwhile, so the handler and this call never send the same one.
        with signals_held():
            group.append(child.pid)
            forward()
        status = child.wait()
        if came:
            _end_the_rest(child.pid)
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    return status, (came[0] if came else None)


# Forwarded colcon options `build` refuses: each moves or replaces what the record stands on.
REFUSED_OPTIONS = {
    "--base-paths": "it would replace the repos `build` gives colcon for the layer",
    "--paths": "it would build other packages than the layer's repos",
    "--install-base": "it would move the output away from <layer>/install/, which the record"
    " and setup.bash stand on",
    "--build-base": "it would move colcon's build directory away from <layer>/build/, where"
    " every layer keeps its own",
}

# The options of `colcon build` with colcon-core 0.21.3 and the usual extensions, to tell an
# abbreviation that colcon reads as one option from one it rejects as ambiguous.
COLCON_BUILD_OPTIONS = (
    "--allow-overriding", "--ament-cmake-args", "--base-paths", "--build-base",
    "--catkin-cmake-args", "--catkin-skip-building-tests", "--cmake-args",
    "--cmake-clean-cache", "--cmake-clean-first", "--cmake-force-configure", "--cmake-target",
    "--cmake-target-skip-unavailable", "--continue-on-error", "--event-handlers", "--executor",
    "--help", "--ignore-user-meta", "--install-base", "--merge-install", "--metas", "--mixin",
    "--mixin-files", "--packages-above", "--packages-above-and-dependencies",
    "--packages-above-depth", "--packages-end", "--packages-ignore", "--packages-ignore-regex",
    "--packages-select", "--packages-select-build-failed", "--packages-select-by-dep",
    "--packages-select-regex", "--packages-select-test-failures", "--packages-skip",
    "--packages-skip-build-finished", "--packages-skip-by-dep", "--packages-skip-regex",
    "--packages-skip-test-passed", "--packages-skip-up-to", "--packages-start",
    "--packages-up-to", "--packages-up-to-regex", "--parallel-workers", "--paths",
    "--symlink-install", "--test-result-base",
)  # fmt: skip

# Package selection colcon must resolve in the packages it finds: given a package a layer
# does not have, colcon exits 1 ("Package '<name>' specified with ... was not found"; the
# regex form fails too). Checked with colcon-core 0.21.3. The other `--packages-` options
# only warn about a name they do not find.
RESOLVING_SELECTION = (
    "--packages-up-to", "--packages-up-to-regex", "--packages-above",
    "--packages-above-and-dependencies", "--packages-above-depth", "--packages-start",
    "--packages-end",
)  # fmt: skip


# Builds what an earlier build of the layer did not finish, the rest being built already: it
# completes the layer, so it is not package selection. (`--packages-select-build-failed` is:
# a package that was never tried is not built by it.)
RESUMING = "--packages-skip-build-finished"


def not_built_for_selection(
    layers: Sequence[Layer], to_build: Sequence[str], records: Dict[str, LayerRecord]
) -> None:
    """A run with package selection builds only part of each layer, so it only rebuilds layers
    that are built, with the repos their record has: any other layer it would build is refused
    before anything runs."""
    why = []
    for index, layer in enumerate(layers):
        if layer.name not in to_build:
            continue
        below = built_run(layers[:index], records).last
        reason = why_not_built(layer, records, below)
        record = records.get(layer.name)
        if reason is None and sorted(record.repos) != sorted(layer.on_disk):
            new = [key for key in layer.on_disk if key not in record.repos]
            gone = [key for key in record.repos if key not in layer.on_disk]
            changes = []
            if new:
                changes.append(f"new {', '.join(new)}")
            if gone:
                changes.append(f"gone {', '.join(gone)}")
            reason = f"its repos differ from its record: {'; '.join(changes)}"
        if reason is not None:
            why.append((layer.name, reason))
    if why:
        names = [name for name, _ in why]
        raise Refusal(
            "a run with package selection builds only part of a layer, so it only rebuilds"
            " layers that are built; not built: "
            + ", ".join(f"{name} ({reason})" for name, reason in why)
            + "; nothing was run",
            "Build them without package selection first: `repos-manifest build"
            f" {' '.join(names)}`",
        )


def _option_names(colcon_args: Sequence[str]) -> List[str]:
    return [arg.split("=", 1)[0] for arg in colcon_args if arg.startswith("--") and arg != "--"]


def _could_be(name: str) -> List[str]:
    """The options of `colcon build` that `name` is or abbreviates."""
    if name in COLCON_BUILD_OPTIONS:
        return [name]
    return [option for option in COLCON_BUILD_OPTIONS if option.startswith(name)]


def refused_arguments(colcon_args: Sequence[str]) -> None:
    """Refuse, before anything runs, an argument after `--` that colcon would read as part of
    what the record stands on: a plain argument first (`colcon build` takes none, and it would
    be read as a value of an option `build` adds), a `--` (after which colcon would read the
    options `build` adds as plain arguments), and an option, or an abbreviation of one, that
    moves or replaces the layer's repos or output."""
    next_step = "Leave it out; `build` gives each layer's colcon its repos and its directory itself"
    if colcon_args and not colcon_args[0].startswith("-"):
        raise Refusal(
            f"{colcon_args[0]!r} after -- is not an option, and `colcon build` takes no plain"
            " argument; nothing was run",
            "Pass only colcon's options after --; name layers before it",
        )
    if "--" in colcon_args:
        raise Refusal(
            "a second -- is not passed to colcon: colcon would read the options `build` adds"
            " after it as plain arguments; nothing was run",
            next_step,
        )
    for name in _option_names(colcon_args):
        if len(name) <= 2:
            continue
        could = _could_be(name)
        for option, why in REFUSED_OPTIONS.items():
            if not option.startswith(name):
                continue
            if name == option:
                given = name
            elif could == [option] or not could:
                given = f"{name} (colcon reads it as {option})"
            else:
                given = f"{name} (colcon would reject it as ambiguous, and it could be {option})"
            raise Refusal(f"{given} is not passed to colcon: {why}; nothing was run", next_step)


def package_selection(colcon_args: Sequence[str], to_build: Sequence[str]) -> bool:
    """Whether the arguments select packages (any `--packages-` option but `RESUMING`): a run
    with one builds only part of a layer. One colcon must resolve in the layer's packages is
    refused, before anything runs, when the run would build more than one layer."""
    selecting = False
    for name in _option_names(colcon_args):
        could = _could_be(name)
        if not (name.startswith("--packages") or any(o.startswith("--packages-") for o in could)):
            continue
        if could == [RESUMING]:
            continue  # it completes a layer: not a selection
        selecting = True
        resolving = [option for option in could if option in RESOLVING_SELECTION]
        if resolving and len(to_build) > 1:
            which = name if name == resolving[0] else f"{name} ({' or '.join(resolving)})"
            raise Refusal(
                f"{which} names packages colcon must find in each layer it builds, and a layer"
                " without them fails; this run would build"
                f" {len(to_build)} layers ({', '.join(to_build) or 'none'}); nothing was run",
                "Name the one layer that has those packages: `repos-manifest build <layer> --"
                " ...`",
            )
    return selecting


def colcon_argv(
    colcon: str,
    layer: Layer,
    base_setup: Optional[Path],
    colcon_args: Sequence[str],
    bash: str = "bash",
) -> List[str]:
    """The command for one layer: colcon directly when nothing is sourced, so the environment
    `build` was run in reaches it unchanged; else bash sourcing the base first."""
    # `--base-paths` comes last, so no forwarded argument is read as one of its paths and a
    # forwarded option with several values ends at it.
    command = [colcon, "build", *colcon_args]
    command += ["--base-paths", *(f"src/{key}" for key in layer.on_disk)]
    if base_setup is None:
        return command
    return [bash, "-c", _SOURCE_THEN_RUN, "repos-manifest-build", str(base_setup), *command]


# --- Checks before the first layer ----------------------------------------------------------


def own_prefix_warnings(layers: Sequence[Layer]) -> List[str]:
    """An entry of a prefix variable that is, or is under, an `install/` of this system's
    layers: the shell has sourced this system's own output."""
    installs = sorted({os.path.realpath(layer.directory / "install") for layer in layers})
    found = []
    for variable in PREFIX_VARIABLES:
        for entry in os.environ.get(variable, "").split(os.pathsep):
            if not entry:
                continue
            real = os.path.realpath(entry)
            if any(real == top or real.startswith(top + os.sep) for top in installs):
                found.append(
                    f"{variable} holds {entry}, which is this system's own output: the layers"
                    " would be built with it already on their path. Build in a shell that has"
                    " not sourced this system's setup.bash"
                )
    return found


def install_notes(layer: Layer, record: Optional[LayerRecord]) -> List[str]:
    if record is None or not (layer.directory / "install").is_dir():
        return []
    install = layer.directory / "install"
    notes = [
        f"{install}/ may hold what an earlier build installed of {key}, which is no longer"
        " part of this layer; build it afresh to drop it"
        for key in record.repos
        if key not in layer.on_disk
    ]
    notes += [
        f"{key} is new in {layer.name} since it was last built"
        for key in layer.on_disk
        if key not in record.repos
    ]
    return notes


def chosen_layers(layers: Sequence[Layer], names: Sequence[str]) -> List[str]:
    """The layers named, in the manifest's order, each once; all of them when none is named."""
    known = [layer.name for layer in layers]
    if not names:
        return known
    for name in names:
        if name not in known:
            raise ManifestError(
                f"no layer {name} in this distro; its layers are: {', '.join(known) or 'none'}"
            )
    return [name for name in known if name in names]


def refusal(layers: Sequence[Layer], chosen: Sequence[str], run: Run) -> None:
    """A layer with repos below a chosen one that is outside the built run and not chosen
    itself: refused before anything runs."""
    for index, layer in enumerate(layers):
        if layer.empty or layer.name in chosen or layer.name in run.layers:
            continue
        above = [
            each.name for each in layers[index + 1 :] if each.name in chosen and not each.empty
        ]
        if above:
            why = run.why if layer.name == run.end else f"it is above {run.end}"
            detail = f" ({why})" if why != "not built" else ""
            raise Refusal(
                f"{above[0]} is built on {layer.name}, which is not built{detail}; nothing was"
                " run",
                f"`build` trusts only its own record in {SYSTEM_DIR}/, and a system"
                " built by other means (another tool, by hand) has none. Run a plain"
                f" `repos-manifest build`, or name {layer.name} too",
            )


# --- The run --------------------------------------------------------------------------------


@dataclass
class Progress:
    """What a run has done so far, for its report and for a stop signal. `started` and `built`
    change in the same held step as the record's write that makes them true, so a stop
    signal finds them and the record in agreement."""

    system: Path
    config: Config
    distro: Optional[str]
    layers: List[Layer]
    lock: Optional[int] = None  # the descriptor that holds the distro's build lock
    started: List[str] = field(default_factory=list)
    built: List[str] = field(default_factory=list)
    # layer, colcon's status; None when colcon exited 0 and wrote no install/setup.bash
    failed: List[Tuple[str, Optional[int]]] = field(default_factory=list)
    skipped: List[str] = field(default_factory=list)
    not_tried: List[str] = field(default_factory=list)
    setup_problem: Optional[str] = None  # why the last rewrite of setup.bash failed
    setup_problems: List[str] = field(default_factory=list)  # every such reason in the run
    setup_written: bool = False
    ready: bool = False  # the checks have passed: every way the run ends now settles

    @property
    def stopped_at(self) -> List[str]:
        """The layers that failed: later ones are not tried."""
        return [name for name, _ in self.failed]

    def release(self) -> None:
        if self.lock is not None:
            os.close(self.lock)
            self.lock = None


def _now() -> str:
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def _put(progress: Progress, records: Dict[str, LayerRecord], then) -> None:
    """Write the distro's records whole, in the layers' order, and note in `progress` what the
    write did (`then`), with the stop signals held across both; records of layers no longer
    listed are dropped."""
    names = [layer.name for layer in progress.layers]
    kept = {name: records[name] for name in names if name in records}
    records.clear()
    records.update(kept)
    with signals_held():
        put_built_layers(progress.system, progress.distro, records)
        then()


def settle(progress: Progress) -> Optional[Run]:
    """Bring `setup.bash` into line with the record as it is now; returns the built run it
    follows, or None when the record cannot be read (`setup_problem` then says why). The one
    place `setup.bash` is written after the checks: before and after each layer and on every
    way a run ends."""
    try:
        records = read_built(progress.system, progress.distro)
        run = built_run(progress.layers, records)
        text = setup_text(progress.system, progress.layers, records, run)
    except (ManifestError, OSError) as exc:
        _setup_failed(progress, f"setup.bash not rewritten: {exc}")
        return None
    problem = write_setup(progress.system, progress.config, progress.distro, text)
    if problem is not None:
        _setup_failed(progress, problem)
    else:
        progress.setup_problem = None
        progress.setup_written = True
    return run


def _setup_failed(progress: Progress, problem: str) -> None:
    """A rewrite of setup.bash failed: it stays failed for the run's exit status and report,
    even if a later rewrite works, since setup.bash was out of line with the record meanwhile."""
    progress.setup_problem = problem
    progress.setup_written = False
    if problem not in progress.setup_problems:
        progress.setup_problems.append(problem)


def _stamp(path: Path) -> Optional[Tuple[int, int, int]]:
    try:
        found = os.stat(path)
    except OSError:
        return None
    return (found.st_ino, found.st_mtime_ns, found.st_ctime_ns)


def build_layers(
    progress: Progress,
    chosen: Sequence[str],
    colcon: Optional[str],
    colcon_args: Sequence[str],
    keep_going: bool = False,
    bash: str = "bash",
    selection: bool = False,
) -> None:
    """Build the chosen layers in order. After a failed layer the later ones are not tried,
    unless `keep_going`: then each is built on the built run's last layer below it, which
    leaves the failed layer out, and its record is written, but it is outside the built run
    and so not used until it is built again on top of the failed layer, fixed.

    With `selection` (package selection among colcon's arguments) colcon builds only part of
    a layer, and every layer the run builds was checked to be built: when colcon succeeds the
    layer gets back the record it had, unchanged. A layer that could only be built on another
    base than its record's (after a failure, with `keep_going`) is not tried."""
    system, distro, layers = progress.system, progress.distro, progress.layers
    records = read_built(system, distro)
    for index, layer in enumerate(layers):
        if layer.name not in chosen:
            continue
        if progress.stopped_at and not keep_going:
            if not layer.empty:
                progress.not_tried.append(layer.name)
            continue
        if layer.empty:
            progress.skipped.append(layer.name)
            continue
        below = built_run(layers[:index], records).last
        base_setup = None
        if below is not None:
            base_setup = next(each for each in layers if each.name == below).install_setup
        had = records.get(layer.name)
        if selection and (had is None or had.base != below):
            progress.not_tried.append(layer.name)
            continue
        for note in install_notes(layer, records.get(layer.name)):
            print(f"NOTE: {note}", flush=True)
        records.pop(layer.name, None)
        _put(progress, records, lambda: progress.started.append(layer.name))
        # setup.bash stops sourcing this layer (or one above it) before colcon writes to it.
        settle(progress)
        before = _stamp(layer.install_setup)
        print(f"building {layer.name} in {layer.directory}", flush=True)
        status, stopped = run_child(
            colcon_argv(colcon, layer, base_setup, colcon_args, bash),
            layer.directory,
            progress.lock,
        )
        if stopped is not None:
            raise Stopped(stopped)
        if status != 0:
            progress.failed.append((layer.name, status))
            continue
        after = _stamp(layer.install_setup)
        if after is None or after == before:
            # colcon exited 0 and wrote no install/setup.bash: nothing was built (`--help`).
            progress.failed.append((layer.name, None))
            continue
        if selection:
            records[layer.name] = had  # the record it had: repos, base and time unchanged
        else:
            records[layer.name] = LayerRecord(_now(), list(layer.on_disk), below)
        _put(progress, records, lambda: progress.built.append(layer.name))
        settle(progress)


def report(progress: Progress, run: Optional[Run]) -> None:
    layers = progress.layers
    by_name = {layer.name: layer for layer in layers}
    name = progress.distro if progress.distro is not None else "(no distro)"
    print(f"build, distro {name}:")
    if run is None:  # the record cannot be read now; settle() said why
        print(f"  built in this run: {', '.join(progress.built) or 'none'}")
        for problem in progress.setup_problems:
            print(f"WARNING: {problem}", flush=True)
        return
    records = read_built(progress.system, progress.distro)
    used = [name for name in progress.built if name in run.layers]
    if used:
        print(f"  built: {', '.join(used)}")
    failed_names = progress.stopped_at
    for name in progress.built:
        if name in run.layers:
            continue
        below = [each.name for each in layers[: layers.index(by_name[name])]]
        without = [failed for failed in failed_names if failed in below]
        print(f"  built without {', '.join(without) or run.end} (failed); not used: {name}")
    for failed, status in progress.failed:
        layer = by_name[failed]
        if status is None:
            print(
                f"  not built: {failed} (colcon exited 0 but did not write"
                f" {layer.install_setup}, so nothing was built)"
            )
            continue
        line = (
            f"  failed: {failed} (colcon exited {status}); its log is in {layer.directory / 'log'}"
        )
        if layer.install_setup.is_file():
            real = Path(os.path.realpath(layer.directory))
            line += (
                "; to use what it did build:"
                f" source {shlex.quote(str(real / 'install/setup.bash'))}"
            )
        print(line)
    if progress.not_tried:
        print(f"  not tried: {', '.join(progress.not_tried)}")
    if progress.skipped:
        print(f"  skipped, no repos on this machine: {', '.join(progress.skipped)}")
    others = [
        layer
        for layer in layers
        if not layer.empty
        and layer.name not in progress.started
        and (layer.name not in progress.not_tried or layer.name in records)
    ]
    rebuilt = set(progress.built)
    earlier = []
    for layer in others:
        if layer.name not in run.layers:
            continue
        lower = [each.name for each in layers[: layers.index(layer)] if each.name in rebuilt]
        if lower:
            earlier.append(f"{layer.name} (on the earlier output of {', '.join(lower)})")
        else:
            earlier.append(layer.name)
    if earlier:
        print(f"  built before, in the run: {', '.join(earlier)}")
    for layer in others:
        if layer.name in run.layers:
            continue
        if layer.name == run.end and run.why != "not built":
            print(f"  {layer.name}: {run.why}")
        elif layer.name in records:
            print(f"  recorded built, not used: {layer.name} (above {run.end}, which is not built)")
        else:
            print(f"  not built: {layer.name}")
    if run.last is None:
        print("setup.bash: nothing is built", end="")
    else:
        print(f"setup.bash: sources {run.last}", end="")
    print("" if progress.setup_written else " (not rewritten in this run)")
    for problem in progress.setup_problems:
        print(f"WARNING: {problem}", flush=True)


def _setup_says(progress: Progress, run: Optional[Run]) -> str:
    said = list(progress.setup_problems)
    if progress.setup_problem is None:
        if run is None or run.last is None:
            said.append("setup.bash sources nothing (nothing is built)")
        else:
            said.append(f"setup.bash sources {run.last}")
    return "; ".join(said)


def run_build(
    named_distros: Sequence[str],
    layer_names: Sequence[str],
    colcon_args: Sequence[str],
    keep_going: bool = False,
) -> int:
    """A stop signal at any point ends the run with one line. Once the checks have passed and
    the distro's lock is held, every way the run ends first brings `setup.bash` into line with
    the record (`settle`), and the line says what both hold."""
    holder: List[Progress] = []
    try:
        try:
            with signals_end_the_run():
                return _build(named_distros, layer_names, colcon_args, keep_going, holder)
        except Stopped as exc:
            progress = holder[0] if holder else None
            if progress is None or not progress.ready:
                if progress is not None:
                    progress.release()
                return stop_exit(exc, f"stopped by {signal_name(exc)}; nothing was changed")
            run = settle(progress)
            done = ", ".join(progress.built) or "none"
            interrupted = [name for name in progress.started if name not in progress.built]
            line = f"stopped by {signal_name(exc)}; layers built in this run: {done}"
            if interrupted and interrupted[-1] not in progress.stopped_at:
                line += f"; {interrupted[-1]} was stopped and is not built"
            line += f"; {_setup_says(progress, run)}"
            return stop_exit(exc, line)
    finally:
        if holder:
            holder[0].release()


def _build(
    named_distros: Sequence[str],
    layer_names: Sequence[str],
    colcon_args: Sequence[str],
    keep_going: bool,
    holder: List[Progress],
) -> int:
    cwd = current_directory()
    with reporting_oserror():
        system = find_system(cwd)
        if system is None:
            raise ManifestError(
                f"no system directory in {cwd} or above it (no {SYSTEM_DIR}/ found); set one up"
                " with `repos-manifest init`"
            )
        config = read_config(system)
        distro = one_distro_for(system, config, named_distros, cwd)
        refused_arguments(colcon_args)
        layers = read_layers(system, config, distro)
        chosen = chosen_layers(layers, layer_names)
        missing_repos(layers, chosen)
        to_build = [layer for layer in layers if layer.name in chosen and not layer.empty]
        selection = package_selection(colcon_args, [layer.name for layer in to_build])
        progress = Progress(system, config, distro, layers)
        holder.append(progress)  # from here run_build releases the lock however the run ends
        progress.lock = hold_build_lock(system, distro)
        records = read_built(system, distro)
        refusal(layers, chosen, built_run(layers, records))
        if selection:
            not_built_for_selection(layers, [layer.name for layer in to_build], records)
        colcon = find_colcon() if to_build else None
        bash = find_bash() if to_build else "bash"
        for warning in own_prefix_warnings(layers) if to_build else []:
            warn(warning)
        progress.ready = True
        try:
            build_layers(progress, chosen, colcon, colcon_args, keep_going, bash, selection)
        except ManifestError as exc:
            run = settle(progress)
            raise ManifestError(f"{exc}; {_setup_says(progress, run)}") from None
        except OSError as exc:
            run = settle(progress)
            raise ManifestError(f"{oserror_message(exc)}; {_setup_says(progress, run)}") from None
        except Exception:
            settle(progress)
            raise
        run = settle(progress)
        report(progress, run)
    failed = bool(progress.stopped_at) or bool(progress.setup_problems)
    return 1 if failed else 0
