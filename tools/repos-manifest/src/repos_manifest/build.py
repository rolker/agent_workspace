"""`build`: build one distro's layers in the manifest's order with colcon, record each layer
that colcon built, and write the distro's one `setup.bash`.

What `build` trusts is its own record, `.repos-manifest/built.yaml`, never colcon's files:
colcon writes `install/setup.bash` after a failed, a partial and even an empty build. A layer
counts as built when its record is there, its `install/setup.bash` is there, and the layer
that was sourced when it was built (its base) is the last layer of the built run below it.
The built run is the distro's layers from the bottom up to the first layer with repos that is
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
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

import yaml

from .manifest import UNNAMED_LAYER
from .output import LAYERS_FILE, signals_held
from .signals import Stopped, signal_name, signals_end_the_run, stop_exit
from .system import (
    SETUP_MARKER,
    SETUP_TEXT,
    SYSTEM_DIR,
    BUILT_FILE,
    Config,
    LayerRecord,
    Refusal,
    current_directory,
    distro_parts,
    find_system,
    layer_src_parts,
    one_distro_for,
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
# the source, so the setup file sees none of them.
_SOURCE_THEN_RUN = (
    'setup=$1; shift; command=("$@"); set --; source "$setup" && exec "${command[@]}"'
)

_STOP_SIGNALS = tuple(
    sig for sig in (getattr(signal, name, None) for name in ("SIGINT", "SIGTERM", "SIGHUP")) if sig
)


@dataclass
class Layer:
    name: str
    directory: Path  # where colcon runs: the distro's directory for the unnamed layer
    listed: List[str]  # the repo keys its resolved file lists, in order
    on_disk: List[str]  # those whose directory is there

    @property
    def empty(self) -> bool:
        return not self.on_disk

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
        directory = distro_dir if name == UNNAMED_LAYER else distro_dir / name
        layers.append(Layer(name, directory, listed, on_disk))
    return layers


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


def find_colcon() -> str:
    """`colcon` on PATH, or beside the Python running this tool (a `colcon` installed in the
    same virtual environment)."""
    beside = os.path.dirname(sys.executable)
    found = shutil.which("colcon", path=os.pathsep.join([os.environ.get("PATH", ""), beside]))
    if found is None:
        raise Refusal(
            f"`colcon` is not found on PATH or in {beside}; `build` needs it",
            "Install colcon (for example colcon-common-extensions) and run it again",
        )
    return found


def _terminal_sent_it() -> bool:
    """The tool is in the foreground process group of its terminal: a Ctrl-C there reached
    every process of the group, colcon included."""
    for stream in (sys.stdin, sys.stdout, sys.stderr):
        try:
            fd = stream.fileno()
            if os.isatty(fd):
                return os.tcgetpgrp(fd) == os.getpgrp()
        except (AttributeError, OSError, ValueError):
            continue
    return False


def run_child(argv: List[str], cwd: Path) -> Tuple[int, Optional[int]]:
    """Run colcon as a child and wait for it. A stop signal to this process is passed on to the
    child (a SIGINT from the terminal is not: the terminal sent it to colcon too), and the run
    waits for the child to end. Returns its exit status and the stop signal, if one came."""
    came: List[int] = []
    child: List[subprocess.Popen] = []

    def on_signal(signum, _frame):
        first = not came
        came.append(signum)
        if not first or not child:
            return
        if signum == getattr(signal, "SIGINT", None) and _terminal_sent_it():
            return
        if child[0].poll() is None:
            child[0].send_signal(signum)

    previous = {}
    for sig in _STOP_SIGNALS:
        if signal.getsignal(sig) in (signal.SIG_IGN, None):
            continue
        try:
            previous[sig] = signal.signal(sig, on_signal)
        except ValueError:  # not the main thread
            pass
    try:
        if came:
            return 0, came[0]
        child.append(subprocess.Popen(argv, cwd=cwd))
        if came and child[0].poll() is None:
            # A signal came while the child was being started, before it could be passed on.
            child[0].send_signal(came[0])
        status = child[0].wait()
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    return status, (came[0] if came else None)


def colcon_argv(
    colcon: str, layer: Layer, base_setup: Optional[Path], colcon_args: Sequence[str]
) -> List[str]:
    """The command for one layer: colcon directly when nothing is sourced, so the environment
    `build` was run in reaches it unchanged; else bash sourcing the base first."""
    command = [colcon, "build", "--base-paths", *(f"src/{key}" for key in layer.on_disk)]
    command += list(colcon_args)
    if base_setup is None:
        return command
    return ["bash", "-c", _SOURCE_THEN_RUN, "repos-manifest-build", str(base_setup), *command]


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
        above = [each.name for each in layers[index + 1 :] if each.name in chosen]
        if above:
            why = run.why if layer.name == run.end else f"it is above {run.end}"
            detail = f" ({why})" if why != "not built" else ""
            raise Refusal(
                f"{above[0]} is built on {layer.name}, which is not built{detail}; nothing was"
                " run",
                f"`build` trusts only its own record in {SYSTEM_DIR}/{BUILT_FILE}, and a system"
                " built by other means (the workspace adapter, by hand) has none. Run a plain"
                f" `repos-manifest build`, or name {layer.name} too",
            )


# --- The run --------------------------------------------------------------------------------


@dataclass
class Progress:
    """What a run has done so far, for its report and for a stop signal."""

    system: Path
    config: Config
    distro: Optional[str]
    layers: List[Layer]
    started: List[str] = field(default_factory=list)
    built: List[str] = field(default_factory=list)
    failed: Optional[Tuple[str, int]] = None  # the layer and colcon's exit status
    skipped: List[str] = field(default_factory=list)
    not_tried: List[str] = field(default_factory=list)
    setup_problem: Optional[str] = None
    setup_written: bool = False


def _now() -> str:
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def _put(progress: Progress, records: Dict[str, LayerRecord]) -> None:
    """Write the distro's records whole, in the layers' order; records of layers no longer
    listed are dropped."""
    names = [layer.name for layer in progress.layers]
    kept = {name: records[name] for name in names if name in records}
    records.clear()
    records.update(kept)
    with signals_held():
        put_built_layers(progress.system, progress.distro, records)


def finish_setup(progress: Progress) -> Run:
    """Write `setup.bash` from the record as it is now; returns the built run it follows."""
    records = read_built(progress.system, progress.distro)
    run = built_run(progress.layers, records)
    text = setup_text(progress.system, progress.layers, records, run)
    progress.setup_problem = write_setup(progress.system, progress.config, progress.distro, text)
    progress.setup_written = progress.setup_problem is None
    return run


def build_layers(
    progress: Progress, chosen: Sequence[str], colcon: Optional[str], colcon_args: Sequence[str]
) -> None:
    system, distro, layers = progress.system, progress.distro, progress.layers
    records = read_built(system, distro)
    for index, layer in enumerate(layers):
        if layer.name not in chosen:
            continue
        if progress.failed is not None:
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
        for note in install_notes(layer, records.get(layer.name)):
            print(f"NOTE: {note}", flush=True)
        records.pop(layer.name, None)
        _put(progress, records)
        progress.started.append(layer.name)
        print(f"building {layer.name} in {layer.directory}", flush=True)
        status, stopped = run_child(
            colcon_argv(colcon, layer, base_setup, colcon_args), layer.directory
        )
        if stopped is not None:
            raise Stopped(stopped)
        if status != 0:
            progress.failed = (layer.name, status)
            continue
        records[layer.name] = LayerRecord(_now(), list(layer.on_disk), below)
        _put(progress, records)
        progress.built.append(layer.name)


def report(progress: Progress, run: Run) -> None:
    layers = progress.layers
    by_name = {layer.name: layer for layer in layers}
    records = read_built(progress.system, progress.distro)
    name = progress.distro if progress.distro is not None else "(no distro)"
    print(f"build, distro {name}:")
    if progress.built:
        print(f"  built: {', '.join(progress.built)}")
    if progress.failed is not None:
        failed, status = progress.failed
        directory = by_name[failed].directory
        real = Path(os.path.realpath(directory))
        print(
            f"  failed: {failed} (colcon exited {status}); its log is in {directory / 'log'};"
            f" to use what it did build: source {shlex.quote(str(real / 'install/setup.bash'))}"
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
    if progress.setup_problem is not None:
        print(f"WARNING: {progress.setup_problem}", flush=True)


def run_build(
    named_distros: Sequence[str], layer_names: Sequence[str], colcon_args: Sequence[str]
) -> int:
    """A stop signal at any point ends the run with one line; once a layer has started,
    `setup.bash` is first written from the record as it then is."""
    holder: List[Progress] = []
    try:
        with signals_end_the_run():
            return _build(named_distros, layer_names, colcon_args, holder)
    except Stopped as exc:
        progress = holder[0] if holder else None
        if progress is None or not progress.started:
            return stop_exit(exc, f"stopped by {signal_name(exc)}; nothing was changed")
        try:
            run = finish_setup(progress)
        except (ManifestError, OSError) as error:
            run, progress.setup_problem = None, str(error)
        done = ", ".join(progress.built) or "none"
        interrupted = [name for name in progress.started if name not in progress.built]
        line = f"stopped by {signal_name(exc)}; layers built in this run: {done}"
        if interrupted and progress.failed is None:
            line += f"; {interrupted[-1]} was stopped and is not built"
        if progress.setup_problem is not None:
            line += f"; {progress.setup_problem}"
        elif run is not None:
            line += f"; setup.bash sources {run.last or 'nothing (nothing is built)'}"
        return stop_exit(exc, line)


def _build(
    named_distros: Sequence[str],
    layer_names: Sequence[str],
    colcon_args: Sequence[str],
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
        layers = read_layers(system, config, distro)
        chosen = chosen_layers(layers, layer_names)
        records = read_built(system, distro)
        refusal(layers, chosen, built_run(layers, records))
        to_build = [layer for layer in layers if layer.name in chosen and not layer.empty]
        colcon = find_colcon() if to_build else None
        for warning in own_prefix_warnings(layers) if to_build else []:
            warn(warning)
        progress = Progress(system, config, distro, layers)
        holder.append(progress)
        build_layers(progress, chosen, colcon, colcon_args)
        if progress.started:
            run = finish_setup(progress)
        else:
            run = built_run(layers, read_built(system, distro))
        report(progress, run)
    failed = progress.failed is not None or progress.setup_problem is not None
    return 1 if failed else 0
