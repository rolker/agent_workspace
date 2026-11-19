"""`build`: build one distro's layers in the manifest's order with colcon, record each layer
that colcon built, and write the distro's one `setup.bash`.

What `build` trusts is its own record, `.repos-manifest/built-<distro>.yaml`, never colcon's
files: colcon writes `install/setup.bash` after a failed, a partial and even an empty build. A
layer counts as built when its record is there, its `install/setup.bash` is there, and the chain
it was built on (the built run below it at the time, which its record holds) is the built run
below it now. The built run is the distro's layers from the bottom up to the first layer with
repos that is not built; layers with no repos on this machine are passed over. Three things
read that one run: a layer is built with the run below it sourced (its last layer's setup
file), `build <layer>` refuses when a layer with repos below it is outside the run and not
named, and `setup.bash` sources the run's last layer. See ``docs/design.md``, "build".
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
    LEFT_OUT,
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
from .yamlload import ManifestError, has_unsafe_char

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


def _not_text(path: Path) -> str:
    return (
        f"{path}: does not read as UTF-8 text; run `repos-manifest sync` to write the resolved"
        " files again"
    )


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
    except UnicodeDecodeError:
        raise ManifestError(_not_text(order_file)) from None
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
    except UnicodeDecodeError:
        raise ManifestError(_not_text(optional_file)) from None
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


def _chain(names: Sequence[str]) -> str:
    return ", ".join(names) if names else "nothing"


def why_not_built(
    layer: Layer, records: Dict[str, LayerRecord], below: Sequence[str]
) -> Optional[str]:
    """Why a layer with repos does not count as built, with `below` the built run under it (its
    layers with repos, from the bottom up); None when it is built."""
    record = records.get(layer.name)
    if record is None:
        return "not built"
    if not layer.install_setup.is_file():
        return f"recorded built, but {layer.install_setup} is missing"
    if list(record.below) != list(below):
        return (
            f"recorded built on {_chain(record.below)}, but the built run below it is now"
            f" {_chain(below)}"
        )
    return None


# The start of `why_not_built`'s reason for a layer whose chain no longer matches.
_CHAIN_CHANGED = "recorded built on "


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
        why = why_not_built(layer, records, run.layers)
        if why is not None:
            run.end, run.why = layer.name, why
            break
        run.layers.append(layer.name)
    return run


# --- setup.bash -----------------------------------------------------------------------------


def real_install_setup(layer: Layer) -> Path:
    """A layer's `install/setup.bash` by the real path of the layer's directory, every link on
    the way resolved: the directory colcon ran in, as it names it itself (it takes its
    install prefix from the directory it runs in, with links resolved). `setup.bash` and the
    closing report both name a layer's setup file this way."""
    return Path(os.path.realpath(layer.directory)) / "install" / "setup.bash"


def setup_text(layers: Sequence[Layer], records, run: Run) -> str:
    if run.last is None:
        return SETUP_TEXT
    layer = next(each for each in layers if each.name == run.last)
    return (
        f"{SETUP_MARKER} The next `repos-manifest build` replaces it.\n"
        f"# It sources the layer {layer.name}, the last layer of the built run,"
        f" built {records[layer.name].time}.\n"
        f"source {shlex.quote(str(real_install_setup(layer)))}\n"
    )


@dataclass
class SetupProblem:
    why: str
    # The file there is not one this tool wrote: it is left alone, and never sources a layer for
    # the tool. False for a failed write, and for a file that cannot be read to tell.
    left_alone: bool


def write_setup(
    system: Path, config: Config, distro: Optional[str], text: str
) -> Optional[SetupProblem]:
    """Write `setup.bash` whole, where nothing is or where the file there is one this tool
    wrote. Returns why it was not written, or None. Never writes through a link."""
    parts = setup_parts(config.layout, distro)
    path = system.joinpath(*parts)
    if os.path.islink(path):
        return SetupProblem(f"{path}: is a link; left as it is", True)
    if os.path.lexists(path):
        if not path.is_file():
            return SetupProblem(f"{path}: is there and is not a file; left as it is", True)
        try:
            there = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            # It may be one this tool wrote, sourcing a layer: not taken for a person's own.
            why = getattr(exc, "strerror", None) or exc
            return SetupProblem(
                f"{path}: cannot be read ({why}), so whether this tool wrote it cannot be told;"
                " left as it is",
                False,
            )
        if not there.startswith(SETUP_MARKER):
            return SetupProblem(
                f"{path}: holds text repos-manifest did not write; left as it is", True
            )
    problem = place_problem(system, parts)
    if problem is not None:
        return SetupProblem(f"{path}: cannot be written: {problem}", False)
    try:
        with stops_held():
            replace_file(system, path, text)
    except OSError as exc:
        return SetupProblem(
            f"{path}: cannot be written: {exc.strerror or type(exc).__name__}", False
        )
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


# The stop signals of a `build`: each ends the run, and while colcon runs it is passed on to
# colcon's group. SIGQUIT (Ctrl-\) is one of them, so a Ctrl-\ does not end the tool with
# colcon running on.
_STOP_NAMES = ("SIGINT", "SIGTERM", "SIGHUP", "SIGQUIT")
_STOP = tuple(sig for sig in (getattr(signal, name, None) for name in _STOP_NAMES) if sig)
# How long the tool waits for what is left of colcon's group to go after it is killed.
_GROUP_GONE_SECONDS = 10.0


def stops_held():
    """Hold the stop signals of a `build` (`_STOP`); a held one is delivered at the end."""
    return signals_held(_STOP)


def _signal_group(pgid: int, signum: int) -> None:
    try:
        os.killpg(pgid, signum)
    except (ProcessLookupError, PermissionError):
        pass


def _end_the_rest(pgid: int) -> None:
    """After colcon itself ended, however it ended: kill every process still in its group (a job
    that outlived it) and wait, a bounded time, until the group is gone. A member that is this
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

    A stop signal (`_STOP`) to this process is passed on to colcon's whole group: the first as
    itself, the second as SIGTERM, every later one as SIGKILL. The tool waits for colcon to
    end; then, however colcon ended (by itself, by a stop, or killed from outside), it kills
    whatever is left in colcon's group and waits for it to go, so no job of the build runs on.
    A SIGTSTP (Ctrl-Z) stops colcon's group and then this process; a SIGCONT continues
    colcon's group.

    The handlers are put in place and taken back with the stop signals held, and which signal
    came is read while they are still held: a stop signal that arrives after that goes to the
    handler that was there before, the run's own, which ends the run."""
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
    child = None
    status: Optional[int] = None
    first: Optional[int] = None
    try:
        with stops_held():
            for sig, handler in handlers:
                if signal.getsignal(sig) in (signal.SIG_IGN, None):
                    continue
                try:
                    previous[sig] = signal.signal(sig, handler)
                except ValueError:  # not the main thread
                    pass
        if not came:
            try:
                child = subprocess.Popen(
                    argv,
                    cwd=cwd,
                    start_new_session=True,
                    pass_fds=(lock,) if lock is not None else (),
                )
            except OSError as exc:
                raise ManifestError(
                    f"{argv[0]} could not be started in {cwd}:"
                    f" {exc.strerror or type(exc).__name__}"
                ) from None
            if lock is not None:
                note_lock_holders(lock, [os.getpid(), child.pid])
            # A signal that came while colcon was being started is passed on now. The stop
            # signals are held meanwhile, so the handler and this call never send the same one.
            with stops_held():
                group.append(child.pid)
                forward()
            status = child.wait()
    finally:
        try:
            if child is not None:
                if child.returncode is None:  # not waited for: something went wrong first
                    _signal_group(child.pid, signal.SIGKILL)
                    child.wait()
                _end_the_rest(child.pid)
        finally:
            with stops_held():
                for sig, handler in previous.items():
                    signal.signal(sig, handler)
                first = came[0] if came else None
    return status, first


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

# `LEFT_OUT` (from `system`): `--packages-skip`, `--packages-ignore` and their `-regex` forms
# build the whole layer but the packages their values name, so they are not package selection
# either, and the record keeps them (`left_out`). `--packages-skip-by-dep`,
# `--packages-skip-up-to` and `--packages-skip-test-passed` are: what they leave out follows
# from the dependency graph or from test results in `build/`, not from a list.

# Builds one CMake target and skips the install step (colcon-cmake 0.2.30: "skip install step if
# a specific target was requested"), while colcon still writes the layer's prefix scripts and
# exits 0: a layer built with it has its packages built but not installed. So it is read as
# package selection. `--cmake-target-skip-unavailable` acts only together with it.
INSTALL_SKIPPING = "--cmake-target"


def not_built_for_selection(
    layers: Sequence[Layer],
    to_build: Sequence[str],
    records: Dict[str, LayerRecord],
    what: str = "package selection",
) -> None:
    """A run with package selection (or `--cmake-target`; `what` names which) builds only part
    of each layer, so it only rebuilds layers that are built, with the repos their record has:
    any other layer it would build is refused before anything runs."""
    not_built, changed = [], []
    for index, layer in enumerate(layers):
        if layer.name not in to_build:
            continue
        below = built_run(layers[:index], records).layers
        reason = why_not_built(layer, records, below)
        if reason is not None:
            not_built.append(f"{layer.name} ({reason})")
            continue
        record = records[layer.name]
        if sorted(record.repos) != sorted(layer.on_disk):
            new = [key for key in layer.on_disk if key not in record.repos]
            gone = [key for key in record.repos if key not in layer.on_disk]
            changes = []
            if new:
                changes.append(f"new {', '.join(new)}")
            if gone:
                changes.append(f"gone {', '.join(gone)}")
            changed.append((layer.name, "; ".join(changes)))
    if not_built or changed:
        found = []
        if not_built:
            found.append(f"not built: {', '.join(not_built)}")
        if changed:
            which = (
                "its repos differ from its record"
                if len(changed) == 1
                else ("their repos differ from their records")
            )
            found.append(
                f"built, but {which}: "
                + ", ".join(f"{name} ({change})" for name, change in changed)
            )
        # One step, every affected layer in the manifest's order, so that following it builds
        # each on the ones below it as they are now.
        affected = {entry.split(" (", 1)[0] for entry in not_built} | {n for n, _ in changed}
        names = [layer.name for layer in layers if layer.name in affected]
        them = "it" if len(names) == 1 else "them"
        step = f"Build {them} without {what} first"
        if changed:
            step += ", which also records the changed repos"
        raise Refusal(
            f"a run with {what} builds only part of a layer, so it only rebuilds"
            f" layers that are built, with the repos their record has; {'; '.join(found)};"
            " nothing was run",
            f"{step}: `repos-manifest build {' '.join(names)}`",
        )


def _option_names(colcon_args: Sequence[str]) -> List[str]:
    return [arg.split("=", 1)[0] for arg in colcon_args if arg.startswith("--") and arg != "--"]


def _could_be(name: str) -> List[str]:
    """The options of `colcon build` that `name` is or abbreviates."""
    if name in COLCON_BUILD_OPTIONS:
        return [name]
    return [option for option in COLCON_BUILD_OPTIONS if option.startswith(name)]


def _left_out_option(name: str) -> Optional[str]:
    """The one option of `LEFT_OUT` that `name` is or abbreviates; None when it is another
    option or could be several (`colcon` rejects such an abbreviation as ambiguous)."""
    could = _could_be(name)
    return could[0] if len(could) == 1 and could[0] in LEFT_OUT else None


def _read_as_option(arg: str) -> bool:
    """`colcon` reads `arg` as one of its options, which ends the values of the option before
    it: `--`, an option of `colcon build` or an abbreviation of one, in either form, or `-h`.
    Any other argument, even one starting with `-` (`-1`, `--foo`), is read as a value: colcon
    reads an argument it does not know as one (checked with colcon-core 0.21.3)."""
    if arg == "--":
        return True
    if arg.startswith("--"):
        return bool(_could_be(arg.split("=", 1)[0]))
    return arg.startswith("-h")


# The options of `LEFT_OUT` whose values are package names: colcon-package-selection 0.2.10
# (`argument_package_name`) rejects a value that starts with `-`, so the layer is not built,
# and strips leading whitespace from the others. The `-regex` forms take any text as a
# pattern, one starting with `-` too.
NAME_LISTS = ("--packages-skip", "--packages-ignore")


def left_out(colcon_args: Sequence[str]) -> Dict[str, List[str]]:
    """The skip and ignore options the arguments give `colcon`: each option of `LEFT_OUT`
    given, named in full, to its values as `colcon` reads them. An option's values run to the
    next argument `colcon` reads as one of its options, the `=value` form has one, and of an
    option given more than once only the last occurrence counts. A list of package names
    (`NAME_LISTS`) also ends at any argument that starts with `-`: where `colcon` builds, that
    is an option of a `colcon` extension `COLCON_BUILD_OPTIONS` does not have, since `colcon`
    rejects such a package name; and its values are recorded with leading whitespace stripped,
    as `colcon` strips it. An option whose last occurrence has no values is not named."""
    found: Dict[str, List[str]] = {}
    taking: Optional[str] = None
    for arg in colcon_args:
        ends = taking in NAME_LISTS and arg.startswith("-")
        if not _read_as_option(arg) and not ends:
            if taking is not None:
                found[taking].append(arg.lstrip() if taking in NAME_LISTS else arg)
            continue
        taking = None
        if not _read_as_option(arg):
            continue  # an option `build` does not know: what follows is its, not the list's
        name, equals, value = arg.partition("=")
        option = _left_out_option(name) if arg.startswith("--") else None
        if option is not None:
            given = value.lstrip() if option in NAME_LISTS else value
            found[option] = [given] if equals else []
            taking = None if equals else option
    return {option: found[option] for option in LEFT_OUT if found.get(option)}


def _shown(value: str) -> str:
    """`value` quoted, with each character that a line cannot show as itself written as an
    escape: a control or invisible character as `\\uXXXX` (`\\xXX` below 0x100), and a byte of
    the argument that is not UTF-8 (Python holds it as a lone surrogate) as `\\xXX`."""
    out = []
    for ch in value:
        code = ord(ch)
        if 0xDC80 <= code <= 0xDCFF:
            out.append(f"\\x{code - 0xDC00:02x}")
        elif ch == "\\" or has_unsafe_char(ch):
            out.append(f"\\x{code:02x}" if code < 0x100 else f"\\u{code:04x}")
        else:
            out.append(ch)
    return "'" + "".join(out) + "'"


def _newly_given(was: Dict[str, List[str]], now: Dict[str, List[str]]) -> bool:
    """`now` names a package or a pattern `was` did not: only then can a package an earlier
    build installed be left out now and stay in `install/`. A skipped and an ignored package
    are both not built, so a name counts once whichever of the two names it; a pattern is
    compared as text."""

    def kinds(without):
        names = {value for option in NAME_LISTS for value in without.get(option, [])}
        patterns = {
            value
            for option, values in without.items()
            if option not in NAME_LISTS
            for value in values
        }
        return names, patterns

    (was_names, was_patterns), (now_names, now_patterns) = kinds(was), kinds(now)
    return bool(now_names - was_names or now_patterns - was_patterns)


def refused_values(colcon_args: Sequence[str]) -> None:
    """Refuse, before anything runs, a skip or ignore value the record cannot hold as one line
    of plain text: one that holds a control or invisible character (the rule names and values
    of a manifest follow) or that is not UTF-8. Such a value would be written into the layer's
    record, which `read_built` then refuses, or would break the report that names it."""
    for option, values in left_out(colcon_args).items():
        for value in values:
            try:
                value.encode("utf-8")
            except UnicodeEncodeError:
                what = "is not UTF-8"
            else:
                if not has_unsafe_char(value):
                    continue
                what = "holds a control or invisible character"
            raise Refusal(
                f"the {option} value {_shown(value)} {what}, which the layer's record cannot"
                " hold as one line of text; nothing was run",
                "Give the package name or pattern in plain text",
            )


def without_text(without: Dict[str, List[str]]) -> str:
    """A record's `without` as the report names it, as colcon's arguments:
    `--packages-skip a b --packages-ignore c`."""
    if not without:
        return "none"
    return " ".join(
        " ".join([option, *(shlex.quote(value) for value in values)])
        for option, values in without.items()
    )


def _same_without(one: Dict[str, List[str]], other: Dict[str, List[str]]) -> bool:
    """Two lists of options leave the same packages out: the same options, each with the same
    values in any order."""
    return {option: set(values) for option, values in one.items()} == {
        option: set(values) for option, values in other.items()
    }


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
    refused_values(colcon_args)


def package_selection(colcon_args: Sequence[str], to_build: Sequence[str]) -> str:
    """What in the arguments builds only part of a layer, as the messages name it ("" when
    nothing does): package selection (any `--packages-` option but `RESUMING` and those of
    `LEFT_OUT`) and `INSTALL_SKIPPING`, or an abbreviation that could be one. A package
    selection colcon must resolve in the layer's packages is refused, before anything runs,
    when the run would build more than one layer."""
    selecting = False
    skipping = False
    for name in _option_names(colcon_args):
        could = _could_be(name)
        if INSTALL_SKIPPING in could and len(could) > 1:
            raise Refusal(
                f"{name} (colcon would reject it as ambiguous, and it could be"
                f" {', '.join(could)}) is not passed to colcon; nothing was run",
                "Give the option in full",
            )
        if INSTALL_SKIPPING in could:
            skipping = True
            continue
        if not (name.startswith("--packages") or any(o.startswith("--packages-") for o in could)):
            continue
        if could == [RESUMING]:
            continue  # it completes a layer: not a selection
        if _left_out_option(name) is not None:
            continue  # the whole layer but the packages named: not a selection
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
    kinds = ["package selection"] if selecting else []
    kinds += [f"`{INSTALL_SKIPPING}`"] if skipping else []
    return " and ".join(kinds)


def colcon_argv(
    colcon: str,
    layer: Layer,
    base_setup: Optional[Path],
    colcon_args: Sequence[str],
    bash: str = "bash",
) -> List[str]:
    """The command for one layer: colcon directly when nothing is sourced, so the environment
    `build` was run in reaches it unchanged; else bash sourcing `base_setup`, the setup file of
    the built run's last layer below it, first."""
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
    # A rewrite of setup.bash before a layer's colcon failed: the run stops before that colcon.
    setup_blocked: Optional[str] = None
    halted: Optional[str] = None  # the layer the run stopped before colcon started on it
    halted_why: Optional[str] = None  # why it stopped there
    halted_kept: bool = False  # that layer had a record, which it keeps
    # Layers whose install/setup.bash from an earlier build was removed before their colcon.
    removed_setup: List[str] = field(default_factory=list)
    # Layer: the directories `install/` left by layers its last chain had and this one lacks.
    left_behind: Dict[str, List[str]] = field(default_factory=dict)
    wrote_setup: List[str] = field(default_factory=list)  # layers whose colcon wrote it this run
    ready: bool = False  # the checks have passed: every way the run ends now settles
    selection: str = ""  # what in the arguments builds part of a layer (`package_selection`)
    # Layer: the skip and ignore options given to its colcon (`left_out`), for each layer built
    # with some.
    without: Dict[str, Dict[str, List[str]]] = field(default_factory=dict)
    # Layer: the options its record had before and those it has now, when they differ.
    without_changed: Dict[str, Tuple[Dict[str, List[str]], Dict[str, List[str]]]] = field(
        default_factory=dict
    )
    # Skip and ignore options given beside `selection`: not recorded, since such a run gives each
    # layer back the record it had.
    unrecorded: Dict[str, List[str]] = field(default_factory=dict)

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
    with stops_held():
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
        text = setup_text(progress.layers, records, run)
    except (ManifestError, OSError) as exc:
        _setup_failed(progress, f"setup.bash not rewritten: {exc}")
        return None
    problem = write_setup(progress.system, progress.config, progress.distro, text)
    if problem is not None:
        _setup_failed(progress, problem.why, problem.left_alone)
    else:
        progress.setup_problem = None
        progress.setup_written = True
    return run


def _setup_failed(progress: Progress, problem: str, left_alone: bool = False) -> None:
    """A rewrite of setup.bash failed: it stays failed for the run's exit status and report,
    even if a later rewrite works, since setup.bash was out of line with the record meanwhile.
    `left_alone`: the file there is not one this tool replaces, so it never sources a layer
    for the tool; any other failure may leave a setup.bash of the tool's sourcing a layer."""
    progress.setup_problem = problem
    if not left_alone:
        progress.setup_blocked = problem
    progress.setup_written = False
    if problem not in progress.setup_problems:
        progress.setup_problems.append(problem)


def _defaults_file() -> str:
    """The global file of default arguments colcon-defaults reads (0.2.9): the one
    COLCON_DEFAULTS_FILE names whenever the variable is set, even to an empty value, else
    `$COLCON_HOME/defaults.yaml` (`~/.colcon/` when COLCON_HOME is unset or empty). A relative
    path is read by colcon against the layer's directory, where it runs. colcon reads it only
    when it is a file; an empty value is no file. With COLCON_DEFAULTS_FILE set colcon reads no
    other global file, but it still reads the `colcon_defaults.yaml` of its directory."""
    if "COLCON_DEFAULTS_FILE" in os.environ:
        return os.environ["COLCON_DEFAULTS_FILE"]
    home = os.environ.get("COLCON_HOME") or os.path.join(os.path.expanduser("~"), ".colcon")
    return os.path.join(home, "defaults.yaml")


def colcon_defaults_files(layer: Optional[Layer] = None) -> List[str]:
    """The files of default arguments colcon will read that are there, as colcon finds them:
    without `layer`, the defaults file when its path is absolute; with `layer`, the defaults
    file when its path is relative (read in the layer's directory) and the layer's
    `colcon_defaults.yaml`. A file that is not there is not named: colcon reads nothing from
    it. `build` sees only the arguments after `--`, not what these files set."""
    path = _defaults_file()
    if layer is None:
        return [path] if os.path.isabs(path) and os.path.isfile(path) else []
    found = []
    if path and not os.path.isabs(path) and (layer.directory / path).is_file():
        found.append(str(layer.directory / path))
    workspace = layer.directory / "colcon_defaults.yaml"
    if workspace.is_file() and not any(
        os.path.realpath(each) == os.path.realpath(workspace) for each in found
    ):
        found.append(str(workspace))  # each file once, though colcon may read it twice
    return found


def _defaults_note(path: str) -> str:
    return (
        f"colcon reads default arguments from {path}; `build` sees only the arguments after --, so"
        " package selection or a target that skips the install set there is not seen, and the"
        " layer is recorded built as a whole; packages left out there (--packages-skip,"
        " --packages-ignore) are not recorded either"
    )


def _remove_install_setup(layer: Layer) -> Tuple[bool, Optional[str]]:
    """Remove the layer's `install/setup.bash` before its colcon starts, so that one there when
    colcon has ended was written by that colcon: no file time is relied on. Returns whether a
    file was removed, and why it could not be, or None."""
    try:
        os.unlink(layer.install_setup)
    except FileNotFoundError:
        return False, None
    except OSError as exc:
        return False, (
            f"{layer.install_setup} cannot be removed before colcon writes it again"
            f" ({exc.strerror or type(exc).__name__})"
        )
    return True, None


def build_layers(
    progress: Progress,
    chosen: Sequence[str],
    colcon: Optional[str],
    colcon_args: Sequence[str],
    keep_going: bool = False,
    bash: str = "bash",
    selection: str = "",
) -> None:
    """Build the chosen layers in order. After a failed layer the later ones are not tried,
    unless `keep_going`: then each is built on the built run below it, which leaves the failed
    layer out, and its record is written with that chain, but it is outside the built run and
    so not used until it is built again on top of the failed layer, fixed.

    With `selection` (package selection or `--cmake-target` among colcon's arguments) colcon
    builds only part of a layer, and every layer the run builds was checked to be built: when
    colcon succeeds the layer gets back the record it had, unchanged. A layer that could only
    be built on another chain than its record's (after a failure, with `keep_going`) is not
    tried.

    When `setup.bash` cannot be brought into line with the record before a layer's colcon, or
    the layer's `install/setup.bash` cannot be removed, the layer gets its record back (colcon
    has not touched it) and the run stops there."""
    system, distro, layers = progress.system, progress.distro, progress.layers
    records = read_built(system, distro)
    without = {} if selection else left_out(colcon_args)
    if selection:
        progress.unrecorded = left_out(colcon_args)
    noted = False
    for index, layer in enumerate(layers):
        if layer.name not in chosen:
            continue
        if (progress.stopped_at and not keep_going) or progress.halted:
            if not layer.empty:
                progress.not_tried.append(layer.name)
            continue
        if layer.empty:
            progress.skipped.append(layer.name)
            continue
        below = built_run(layers[:index], records).layers
        base_setup = None
        if below:
            base_setup = next(each for each in layers if each.name == below[-1]).install_setup
        had = records.get(layer.name)
        if selection and (had is None or had.below != below):
            progress.not_tried.append(layer.name)
            continue
        if not noted:
            noted = True
            for path in colcon_defaults_files():
                print(f"NOTE: {_defaults_note(path)}", flush=True)
        for note in install_notes(layer, had):
            print(f"NOTE: {note}", flush=True)
        for path in colcon_defaults_files(layer):
            print(f"NOTE: {_defaults_note(path)}", flush=True)
        records.pop(layer.name, None)
        _put(progress, records, lambda: progress.started.append(layer.name))
        # setup.bash stops sourcing this layer (or one above it) before colcon writes to it.
        progress.setup_blocked = None
        settle(progress)
        if progress.setup_blocked is not None:
            # It may still source this layer: colcon is not started.
            _halt(
                progress,
                records,
                layer,
                had,
                "setup.bash could not be brought into line" " with the record",
            )
            continue
        removed, problem = _remove_install_setup(layer)
        if problem is not None:
            _halt(progress, records, layer, had, problem)
            continue
        if removed:
            progress.removed_setup.append(layer.name)
        if had is not None:
            left = _left_behind(progress, had.below, below)
            if left:
                progress.left_behind[layer.name] = left
        print(f"building {layer.name} in {layer.directory}", flush=True)
        status, stopped = run_child(
            colcon_argv(colcon, layer, base_setup, colcon_args, bash),
            layer.directory,
            progress.lock,
        )
        if stopped is not None:
            raise Stopped(stopped)
        wrote = layer.install_setup.is_file()
        if wrote:
            progress.wrote_setup.append(layer.name)
        if status != 0:
            progress.failed.append((layer.name, status))
            continue
        if not wrote:
            # colcon exited 0 and wrote no install/setup.bash: nothing was built (`--help`).
            progress.failed.append((layer.name, None))
            continue
        if selection:
            records[layer.name] = had  # the record it had: repos, chain, time and list unchanged
        else:
            records[layer.name] = LayerRecord(
                _now(), list(layer.on_disk), list(below), dict(without)
            )
            if without:
                progress.without[layer.name] = without
            if had is not None and not _same_without(had.without, without):
                progress.without_changed[layer.name] = (had.without, without)
        _put(progress, records, lambda: progress.built.append(layer.name))
        settle(progress)


def _halt(progress: Progress, records, layer: Layer, had: Optional[LayerRecord], why: str):
    """Stop the run before colcon starts on `layer`: the layer, untouched, gets back the record
    it had, setup.bash is brought into line with it, and the later layers are not tried."""
    if had is not None:
        records[layer.name] = had
    _put(progress, records, lambda: progress.started.remove(layer.name))
    progress.halted, progress.halted_why, progress.halted_kept = layer.name, why, had is not None
    settle(progress)


def _left_behind(progress: Progress, was: Sequence[str], now: Sequence[str]) -> List[str]:
    """The `install/` directories still on disk of the layers a layer's last chain (`was`) had
    and its chain now lacks because they left the manifest or have no repos now: a rebuild can
    still find their earlier output through paths its build directory kept."""
    by_name = {layer.name: layer for layer in progress.layers}
    distro_dir = progress.system.joinpath(*distro_parts(progress.config.layout, progress.distro))
    found = []
    for name in was:
        if name in now:
            continue
        layer = by_name.get(name)
        if layer is not None and not layer.empty:
            continue  # not built: the run below stops under it, or --keep-going says so
        if layer is not None:
            directory = layer.directory
        elif name == UNNAMED_LAYER:
            directory = distro_dir
        elif _plain_name(name):
            directory = distro_dir / name
        else:
            continue
        if (directory / "install").is_dir():
            found.append(f"{directory / 'install'}/")
    return found


def _removed_note(progress: Progress, layer: Layer) -> str:
    """For a layer whose colcon ended without writing `install/setup.bash` again: the earlier
    one was removed before colcon started, so a shell that sources it directly finds none."""
    if layer.name not in progress.removed_setup or layer.install_setup.exists():
        return ""
    return (
        f"; its earlier {layer.install_setup} was removed when this run started on it and is"
        " not there now"
    )


def report(progress: Progress, run: Optional[Run]) -> None:
    layers = progress.layers
    by_name = {layer.name: layer for layer in layers}
    name = progress.distro if progress.distro is not None else "(no distro)"
    print(f"build, distro {name}:")
    if run is None:  # the record cannot be read now; settle() said why
        print(f"  {_built_label(progress)} in this run: {', '.join(progress.built) or 'none'}")
        for problem in progress.setup_problems:
            print(f"WARNING: {problem}", flush=True)
        return
    records = read_built(progress.system, progress.distro)
    used = [name for name in progress.built if name in run.layers]
    if used:
        print(f"  {_built_label(progress)}: {', '.join(used)}")
    given = [name for name in progress.built if name in progress.without]
    for text in dict.fromkeys(without_text(progress.without[name]) for name in given):
        names = [name for name in given if without_text(progress.without[name]) == text]
        print(f"  built with {text} given to colcon: {', '.join(names)}")
    for name in progress.built:
        if name in progress.without_changed:
            was, now = progress.without_changed[name]
            line = (
                f"  skip and ignore options given to colcon changed: {name} (was"
                f" {without_text(was)}, now {without_text(now)})"
            )
            if _newly_given(was, now):
                line += (
                    "; what an earlier build installed of a package they skip or ignore now"
                    " stays in"
                    f" {by_name[name].directory / 'install'}/"
                )
            print(line)
    if progress.unrecorded and progress.built:  # no line when no layer was built
        print(
            f"  not recorded, given with {progress.selection}: {without_text(progress.unrecorded)}"
            " (a run that builds only part of a layer gives each layer back the record it had)"
        )
    for name in progress.built:
        if name in progress.left_behind:
            print(
                f"  built on a shorter chain than before: {name} (it may have used what is left"
                f" in {', '.join(progress.left_behind[name])} through paths its build directory"
                " kept from an earlier build)"
            )
    failed_names = progress.stopped_at
    for name in progress.built:
        if name in run.layers:
            continue
        below = [each.name for each in layers[: layers.index(by_name[name])]]
        without = [failed for failed in failed_names if failed in below] or [run.end]
        left = [
            f"{by_name[each].directory / 'install'}/"
            for each in without
            if each is not None and (by_name[each].directory / "install").is_dir()
        ]
        line = (
            f"  built without sourcing {', '.join(map(str, without))} (failed), so not used: {name}"
        )
        if left:
            # Seen with colcon-core 0.21.3 and CMake: a package's CMake cache keeps the path
            # where it found a package of the failed layer, and the build uses it again.
            line += (
                f" (it may have used what is left in {', '.join(left)} through paths its build"
                " directory kept from an earlier build)"
            )
        print(line)
    for failed, status in progress.failed:
        layer = by_name[failed]
        if status is None:
            print(
                f"  not built: {failed} (colcon exited 0 but did not write"
                f" {layer.install_setup}, so nothing was built){_removed_note(progress, layer)}"
            )
            continue
        line = (
            f"  failed: {failed} (colcon exited {status}); its log is in {layer.directory / 'log'}"
        )
        if failed in progress.wrote_setup:
            line += (
                "; to use what it did build:"
                f" source {shlex.quote(str(real_install_setup(layer)))}"
            )
        else:
            line += _removed_note(progress, layer)
        print(line)
    if progress.halted is not None:
        kept = "; it keeps its record" if progress.halted_kept else ""
        print(
            f"  stopped before {progress.halted}: {progress.halted_why}, so colcon was not"
            f" started on it{kept}"
        )
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
        if layer.name == run.end and run.why.startswith(_CHAIN_CHANGED):
            chain = run.why[len("recorded ") :]
            print(f"  recorded built, not used: {layer.name} ({chain})")
        elif layer.name == run.end and run.why != "not built":
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


def _built_label(progress: Progress) -> str:
    return "rebuilt with selection" if progress.selection else "built"


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
            with signals_end_the_run(also=("SIGQUIT",)):
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
            label = _built_label(progress)
            line = f"stopped by {signal_name(exc)}; layers {label} in this run: {done}"
            if interrupted and interrupted[-1] not in progress.stopped_at:
                line += f"; {interrupted[-1]} was stopped and is not built"
                stopped_layer = next(
                    each for each in progress.layers if each.name == interrupted[-1]
                )
                line += _removed_note(progress, stopped_layer)
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
        progress = Progress(system, config, distro, layers, selection=selection)
        holder.append(progress)  # from here run_build releases the lock however the run ends
        progress.lock = hold_build_lock(system, distro)
        records = read_built(system, distro)
        refusal(layers, chosen, built_run(layers, records))
        if selection:
            not_built_for_selection(layers, [layer.name for layer in to_build], records, selection)
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
    failed = bool(progress.stopped_at) or bool(progress.setup_problems) or bool(progress.halted)
    return 1 if failed else 0
