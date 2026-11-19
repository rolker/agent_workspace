"""`build`: the layers in order with colcon, the record of what was built, the built run, and
the one `setup.bash`. Most tests use a stand-in for colcon (fixtures/stub_colcon); the tests
marked `colcon` build real plain-CMake packages with the colcon on PATH."""

import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest
import yaml

from helpers import make_package_remote, make_remote, repo, run, write_manifest
import repos_manifest
import repos_manifest.cli
from repos_manifest import build
from repos_manifest.system import SETUP_TEXT, build_lock_file, hold_build_lock

STUB = Path(__file__).parent / "fixtures" / "stub_colcon"
BASE = "_unnamed"


@pytest.fixture
def stub(vcs, monkeypatch, tmp_path):
    """The stand-in colcon first on PATH, its log, and no prefix variable from the caller."""
    os.chmod(STUB / "colcon", 0o755)
    monkeypatch.setenv("PATH", f"{STUB}{os.pathsep}{os.environ['PATH']}")
    log = tmp_path / "colcon.log"
    monkeypatch.setenv("STUB_COLCON_LOG", str(log))
    for variable in build.PREFIX_VARIABLES + ("STUB_SOURCED",):
        monkeypatch.delenv(variable, raising=False)
    return log


def runs(log):
    """Each run of the stand-in: (the directory, the layers sourced, the arguments)."""
    if not log.exists():
        return []
    found = []
    for line in log.read_text().splitlines():
        if line.startswith("run "):
            cwd, rest = line[len("run cwd=") :].split(" sourced=", 1)
            sourced, args = rest.split(" args=", 1)
            found.append((cwd, sourced, args))
    return found


def three_layers(tmp_path, mid_optional_missing=False):
    """A flat system for jazzy: `u` in the unnamed layer, `m` in mid, `t` in top."""
    remotes = tmp_path / "remotes"
    mid = repo(make_remote(remotes, "m"), None, "mid")
    if mid_optional_missing:
        mid = repo(remotes / "not-yet", None, "mid", optional=True)
    data = {
        "format": 1,
        "distros": ["jazzy"],
        "layers": ["mid", "top"],
        "repositories": {
            "u": repo(make_remote(remotes, "u")),
            "m": mid,
            "t": repo(make_remote(remotes, "t"), None, "top"),
        },
    }
    path = write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--distro", "jazzy", "--yes") == 0
    return system, path, data


@pytest.fixture
def system(stub, tmp_path):
    return three_layers(tmp_path)[0]


def built(system, distro="jazzy"):
    data = yaml.safe_load((system / f".repos-manifest/built-{distro}.yaml").read_text())
    return data["layers"]


def sourced_by_setup(system, where="setup.bash"):
    """The layer directory `setup.bash` sources, or None for the stub text."""
    text = (system / where).read_text()
    if text == SETUP_TEXT:
        return None
    line = [each for each in text.splitlines() if each.startswith("source ")][0]
    return Path(line.split(" ", 1)[1].strip("'")).parent.parent


def real(path):
    return Path(os.path.realpath(path))


def test_layers_are_built_in_order_each_on_the_one_below(system, stub, capsys):
    capsys.readouterr()
    assert run(system, "build", "--", "--symlink-install") == 0
    done = runs(stub)
    assert [cwd for cwd, _, _ in done] == [str(system), str(system / "mid"), str(system / "top")]
    assert [sourced for _, sourced, _ in done] == ["", "sys", "mid"]
    assert [args for _, _, args in done] == [
        "build --symlink-install --base-paths src/u",
        "build --symlink-install --base-paths src/m",
        "build --symlink-install --base-paths src/t",
    ]
    records = built(system)
    assert list(records) == [BASE, "mid", "top"]
    assert [records[name]["base"] for name in records] == [None, BASE, "mid"]
    assert records["mid"]["repos"] == ["m"]
    assert sourced_by_setup(system) == real(system / "top")
    out = capsys.readouterr().out
    assert f"  built: {BASE}, mid, top\n" in out
    assert out.endswith("setup.bash: sources top\n")
    # The setup.bash it writes runs: it sources top's install/setup.bash.
    done = subprocess.run(
        ["bash", "-c", "source setup.bash && echo $STUB_SOURCED"],
        cwd=system,
        capture_output=True,
        text=True,
        check=True,
    )
    assert done.stdout == "top\n"


def test_the_first_layer_runs_colcon_itself_and_the_others_through_bash(system, stub, monkeypatch):
    started = []
    real_popen = subprocess.Popen

    def popen(argv, **kwargs):
        started.append(list(argv))
        return real_popen(argv, **kwargs)

    monkeypatch.setattr(build.subprocess, "Popen", popen)
    assert run(system, "build") == 0
    assert os.path.basename(started[0][0]) == "colcon" and started[0][1] == "build"
    assert os.path.isabs(started[0][0]) and os.path.isabs(started[1][0])
    assert os.path.basename(started[1][0]) == "bash" and started[1][1] == "-c"
    assert started[1][4] == str(system / "install" / "setup.bash")
    assert os.path.basename(started[1][5]) == "colcon"


def test_a_failed_layer_stops_the_run(system, stub, capsys):
    (system / "mid/src/m/STUB_FAIL").touch()
    capsys.readouterr()
    assert run(system, "build", "--", "--continue-on-error") == 1
    assert [cwd for cwd, _, _ in runs(stub)] == [str(system), str(system / "mid")]
    assert list(built(system)) == [BASE]
    assert sourced_by_setup(system) == real(system)
    out = capsys.readouterr().out
    assert f"  built: {BASE}\n" in out
    assert (
        f"  failed: mid (colcon exited 1); its log is in {system / 'mid' / 'log'}; to use what"
        f" it did build: source {real(system / 'mid')}/install/setup.bash\n" in out
    )
    assert "  not tried: top\n" in out
    assert out.endswith(f"setup.bash: sources {BASE}\n")


def test_a_failure_then_a_rebuild_of_that_layer_brings_the_one_above_back(system, stub, capsys):
    assert run(system, "build") == 0
    (system / "mid/src/m/STUB_FAIL").touch()
    capsys.readouterr()
    assert run(system, "build") == 1
    out = capsys.readouterr().out
    assert "  recorded built, not used: top (above mid, which is not built)\n" in out
    assert sourced_by_setup(system) == real(system)
    assert built(system)["top"]["base"] == "mid"
    (system / "mid/src/m/STUB_FAIL").unlink()
    stub.unlink()
    assert run(system, "build", "mid") == 0
    assert [cwd for cwd, _, _ in runs(stub)] == [str(system / "mid")]
    assert sourced_by_setup(system) == real(system / "top")
    out = capsys.readouterr().out
    assert f"  built before, in the run: {BASE}, top (on the earlier output of mid)\n" in out
    assert out.endswith("setup.bash: sources top\n")


def test_keep_going_tries_later_layers_without_using_them(system, stub, capsys):
    (system / "mid/src/m/STUB_FAIL").touch()
    capsys.readouterr()
    assert run(system, "build", "--keep-going") == 1
    done = runs(stub)
    assert [cwd for cwd, _, _ in done] == [str(system), str(system / "mid"), str(system / "top")]
    assert done[2][1] == "sys"  # top is built on the unnamed layer, without mid
    assert built(system)["top"]["base"] == BASE
    assert "mid" not in built(system)
    assert sourced_by_setup(system) == real(system)
    out = capsys.readouterr().out
    assert f"  built: {BASE}\n" in out
    assert "  built without mid (failed); not used: top\n" in out
    assert "  failed: mid (colcon exited 1)" in out
    assert "not tried" not in out
    assert out.endswith(f"setup.bash: sources {BASE}\n")
    # mid fixed and built alone: top was built without it, so it is not built until rebuilt.
    (system / "mid/src/m/STUB_FAIL").unlink()
    assert run(system, "build", "mid") == 0
    out = capsys.readouterr().out
    assert "  top: base changed: built on top of _unnamed, and the built run below it now" in out
    assert sourced_by_setup(system) == real(system / "mid")
    assert run(system, "build") == 0
    assert runs(stub)[-1][1] == "mid"
    assert sourced_by_setup(system) == real(system / "top")


def test_keep_going_with_a_failure_in_the_first_layer(system, stub, capsys):
    (system / "src/u/STUB_FAIL").touch()
    assert run(system, "build", "--keep-going") == 1
    assert [sourced for _, sourced, _ in runs(stub)] == ["", "", ""]
    assert list(built(system)) == ["mid", "top"]
    assert (system / "setup.bash").read_text() == SETUP_TEXT
    out = capsys.readouterr().out
    assert f"  built without {BASE} (failed); not used: mid\n" in out
    assert f"  built without {BASE} (failed); not used: top\n" in out


def test_a_failure_in_the_first_layer_leaves_the_stub(system, stub, capsys):
    (system / "src/u/STUB_FAIL").touch()
    assert run(system, "build") == 1
    assert (system / "setup.bash").read_text() == SETUP_TEXT
    assert capsys.readouterr().out.endswith("setup.bash: nothing is built\n")


def test_a_rebuild_of_the_first_layer_keeps_the_ones_above(system, stub, capsys):
    assert run(system, "build") == 0
    capsys.readouterr()
    assert run(system, "build", BASE) == 0
    assert list(built(system)) == [BASE, "mid", "top"]
    assert sourced_by_setup(system) == real(system / "top")
    out = capsys.readouterr().out
    assert (
        f"  built before, in the run: mid (on the earlier output of {BASE}),"
        f" top (on the earlier output of {BASE})\n" in out
    )


def test_the_record_of_a_layer_is_gone_while_colcon_builds_it(system, stub):
    assert run(system, "build") == 0
    assert run(system, "build", "mid") == 0
    during = yaml.safe_load(Path(f"{stub}.built-jazzy-during-mid").read_text())["layers"]
    assert list(during) == [BASE, "top"]


def test_a_layer_empty_when_the_one_above_was_built_and_filled_later(stub, tmp_path, capsys):
    system, _, _ = three_layers(tmp_path, mid_optional_missing=True)
    capsys.readouterr()
    assert run(system, "build") == 0
    out = capsys.readouterr().out
    assert "  skipped, no repos on this machine: mid\n" in out
    assert built(system)["top"]["base"] == BASE
    assert [sourced for _, sourced, _ in runs(stub)] == ["", "sys"]
    make_remote(tmp_path / "remotes", "not-yet")
    assert run(system, "sync") == 0
    assert run(system, "build", "top") == 1
    err = capsys.readouterr().err
    assert "top is built on mid, which is not built; nothing was run" in err
    assert "Run a plain `repos-manifest build`, or name mid too" in err
    assert run(system, "build", BASE) == 0
    out = capsys.readouterr().out
    assert "  not built: mid\n" in out
    assert "  recorded built, not used: top (above mid, which is not built)\n" in out
    assert sourced_by_setup(system) == real(system)
    stub.unlink()
    assert run(system, "build") == 0
    assert [sourced for _, sourced, _ in runs(stub)][1:] == ["sys", "mid"]
    assert sourced_by_setup(system) == real(system / "top")


def test_a_lower_layer_filled_and_built_alone_makes_the_one_above_not_built(stub, tmp_path, capsys):
    system, _, _ = three_layers(tmp_path, mid_optional_missing=True)
    assert run(system, "build") == 0
    make_remote(tmp_path / "remotes", "not-yet")
    assert run(system, "sync") == 0
    capsys.readouterr()
    assert run(system, "build", BASE, "mid") == 0
    out = capsys.readouterr().out
    assert (
        "  top: base changed: built on top of _unnamed, and the built run below it now ends" in out
    )
    assert sourced_by_setup(system) == real(system / "mid")


def test_a_layer_whose_install_is_gone_is_not_built(system, stub, capsys):
    assert run(system, "build") == 0
    shutil.rmtree(system / "mid/install")
    assert run(system, "build", "top") == 1
    assert "top is built on mid, which is not built (recorded built, but" in capsys.readouterr().err
    assert run(system, "build", BASE) == 0
    out = capsys.readouterr().out
    assert f"  mid: recorded built, but {system / 'mid/install/setup.bash'} is missing\n" in out
    assert "  recorded built, not used: top (above mid, which is not built)\n" in out
    assert sourced_by_setup(system) == real(system)


def test_records_of_layers_no_longer_listed_are_dropped(system, stub):
    assert run(system, "build", BASE) == 0
    path = system / ".repos-manifest/built-jazzy.yaml"
    data = yaml.safe_load(path.read_text())
    data["layers"]["gone"] = {"time": "t", "repos": ["g"], "base": None}
    path.write_text(yaml.safe_dump(data))
    assert run(system, "build", BASE) == 0
    data = yaml.safe_load(path.read_text())
    assert list(data["layers"]) == [BASE]


def test_named_layers_are_built_in_the_manifests_order(system, stub, capsys):
    assert run(system, "build", BASE) == 0
    assert run(system, "build", "top") == 1
    assert "top is built on mid, which is not built" in capsys.readouterr().err
    assert len(runs(stub)) == 1
    assert run(system, "build", "top", "mid", "top") == 0
    assert [cwd for cwd, _, _ in runs(stub)][1:] == [str(system / "mid"), str(system / "top")]


def test_an_unknown_layer_is_an_error_listing_the_layers(system, stub, capsys):
    assert run(system, "build", "nope") == 1
    assert f"no layer nope in this distro; its layers are: {BASE}, mid, top" in (
        capsys.readouterr().err
    )
    assert runs(stub) == []


def test_without_resolved_files_build_says_to_run_sync(system, stub, capsys):
    os.unlink(system / ".repos-manifest/resolved/layers.txt")
    assert run(system, "build") == 1
    assert "run `repos-manifest sync` first" in capsys.readouterr().err


@pytest.fixture
def two_distros(stub, tmp_path):
    remotes = tmp_path / "remotes"
    data = {
        "format": 1,
        "distros": ["jazzy", "rolling"],
        "layers": ["core"],
        "repositories": {"a": repo(make_remote(remotes, "a"), None, "core")},
    }
    write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    argv = ("init", "../m.manifest.yaml", "--distro-dirs", "--distro", "jazzy", "--distro")
    assert run(system, *argv, "rolling", "--yes") == 0
    return system


def test_with_several_distros_build_takes_one(two_distros, stub, capsys):
    system = two_distros
    assert run(system, "build") == 1
    assert "this system has several distros (jazzy, rolling); name one" in capsys.readouterr().err
    assert run(system, "build", "--distro", "rolling") == 0
    assert [cwd for cwd, _, _ in runs(stub)] == [str(system / "rolling/core")]
    assert sourced_by_setup(system, "rolling/setup.bash") == real(system / "rolling/core")
    assert (system / "jazzy/setup.bash").read_text() == SETUP_TEXT
    assert run(system / "jazzy/core", "build") == 0
    assert list(built(system, "jazzy")) == ["core"]
    with pytest.raises(SystemExit):
        run(system, "build", "--distro", "jazzy", "--distro", "rolling")
    assert "--distro may be given only once" in capsys.readouterr().err


@pytest.mark.parametrize("kind", ["text", "directory", "dangling link", "link to a file"])
def test_a_setup_bash_not_written_by_the_tool_is_left_alone(system, stub, tmp_path, kind, capsys):
    setup = system / "setup.bash"
    setup.unlink()
    if kind == "text":
        setup.write_text("source /opt/mine/setup.bash\n")
    elif kind == "directory":
        setup.mkdir()
    elif kind == "dangling link":
        setup.symlink_to(tmp_path / "nowhere")
    else:
        (tmp_path / "target").write_text(SETUP_TEXT)
        setup.symlink_to(tmp_path / "target")
    before = os.lstat(setup)
    assert run(system, "build") == 1
    assert list(built(system)) == [BASE, "mid", "top"]
    after = os.lstat(setup)
    assert (before.st_mode, before.st_ino) == (after.st_mode, after.st_ino)
    if kind == "link to a file":
        assert (tmp_path / "target").read_text() == SETUP_TEXT
    out = capsys.readouterr().out
    assert "setup.bash: sources top (not rewritten in this run)\n" in out
    assert f"WARNING: {setup}: " in out and "left as it is" in out


def test_a_built_yaml_that_does_not_read_is_an_error_naming_it(system, stub, capsys):
    path = system / ".repos-manifest/built-jazzy.yaml"
    path.write_text("format: 1\nlayers: {mid: {time: 1}}\n")
    assert run(system, "build") == 1
    assert f"ERROR: {path}: " in capsys.readouterr().err
    assert runs(stub) == []


def test_without_colcon_build_says_so_before_any_layer(system, stub, tmp_path, monkeypatch, capsys):
    empty = tmp_path / "empty"
    empty.mkdir()
    monkeypatch.setenv("PATH", str(empty))
    monkeypatch.setattr(build.sys, "executable", str(empty / "python3"))
    assert run(system, "build") == 1
    assert "`colcon` is not found on PATH" in capsys.readouterr().err
    assert not (system / ".repos-manifest/built-jazzy.yaml").exists()


def test_the_install_note_names_removed_and_added_repos(stub, tmp_path, capsys):
    system, path, data = three_layers(tmp_path)
    assert run(system, "build") == 0
    data["repositories"]["m"]["layer"] = "top"
    data["repositories"]["n"] = repo(make_remote(tmp_path / "remotes", "n"), None, "mid")
    write_manifest(path, data)
    assert run(system, "sync") == 0
    capsys.readouterr()
    assert run(system, "build", "mid") == 0
    out = capsys.readouterr().out
    assert (
        f"NOTE: {system / 'mid/install'}/ may hold what an earlier build installed of m, which"
        " is no longer part of this layer; build it afresh to drop it\n" in out
    )
    assert "NOTE: n is new in mid since it was last built\n" in out


def test_a_prefix_variable_holding_this_systems_output_is_warned_about(
    system, stub, monkeypatch, capsys
):
    monkeypatch.setenv("CMAKE_PREFIX_PATH", f"/opt/elsewhere:{system / 'mid/install/m'}")
    assert run(system, "build", BASE) == 0
    err = capsys.readouterr().err
    assert f"WARNING: CMAKE_PREFIX_PATH holds {system / 'mid/install/m'}, which is this" in err
    monkeypatch.setenv("CMAKE_PREFIX_PATH", "/opt/elsewhere")
    assert run(system, "build", BASE) == 0
    assert "WARNING" not in capsys.readouterr().err


def start_tool(system, *argv, env=None):
    """`repos-manifest build <argv>` as a process of its own, to send signals to."""
    package = str(Path(repos_manifest.__file__).parent.parent)
    return subprocess.Popen(
        [sys.executable, "-m", "repos_manifest.cli", "build", *argv],
        cwd=system,
        env={**os.environ, **(env or {}), "PYTHONPATH": package},
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def wait_until(check, tool, seconds=30):
    deadline = time.monotonic() + seconds
    while not check():
        assert time.monotonic() < deadline, "timed out"
        assert tool is None or tool.poll() is None, tool.communicate()
        time.sleep(0.05)


def logged(log, text):
    return lambda: text in (log.read_text() if log.exists() else "")


def logged_pid(log, what):
    line = [each for each in log.read_text().splitlines() if each.startswith(f"{what} pid=")][-1]
    return int(line.split("=", 1)[1])


def state(pid):
    """The state letter of a process (R, S, T, Z, ...), or None when it is gone."""
    try:
        text = Path(f"/proc/{pid}/stat").read_text()
    except (FileNotFoundError, ProcessLookupError):
        return None
    return text.rsplit(")", 1)[1].split()[0]


def gone(pid, seconds=10):
    deadline = time.monotonic() + seconds
    while state(pid) not in (None, "Z", "X"):
        if time.monotonic() > deadline:
            return False
        time.sleep(0.05)
    return True


@pytest.mark.parametrize("signum", [signal.SIGTERM, signal.SIGINT, signal.SIGHUP])
def test_a_stop_signal_to_the_tool_ends_colcons_whole_group_and_is_waited_for(system, stub, signum):
    assert run(system, "build", BASE) == 0
    (system / "mid/src/m/STUB_WAIT").touch()
    tool = start_tool(system)
    wait_until(logged(stub, "waiting"), tool)
    job, colcon = logged_pid(stub, "job"), logged_pid(stub, "waiting")
    os.kill(tool.pid, signum)
    out, err = tool.communicate(timeout=30)
    assert tool.returncode == -signum
    short = signal.Signals(signum).name[3:]
    assert stub.read_text().splitlines()[-1] == f"got {short}"
    # colcon itself, and a job of its group that ignores the stop signals, are both gone.
    assert gone(colcon) and gone(job)
    assert list(built(system)) == [BASE]
    assert sourced_by_setup(system) == real(system)
    assert (
        f"stopped by SIG{short}; layers built in this run: {BASE}; mid was stopped and is not"
        f" built; setup.bash sources {BASE}" in err
    )
    assert "top" not in [os.path.basename(cwd) for cwd, _, _ in runs(stub)]


def test_colcon_runs_in_a_session_of_its_own(system, stub):
    (system / "src/u/STUB_WAIT").touch()
    tool = start_tool(system)
    wait_until(logged(stub, "waiting"), tool)
    colcon = logged_pid(stub, "waiting")
    try:
        assert os.getsid(colcon) == colcon and os.getpgid(colcon) == colcon
        assert os.getpgid(colcon) != os.getpgid(tool.pid)
    finally:
        os.kill(tool.pid, signal.SIGTERM)
        tool.communicate(timeout=30)


def test_a_second_and_a_third_stop_signal_escalate(system, stub):
    (system / "src/u/STUB_WAIT").touch()
    (system / "src/u/STUB_STUBBORN").touch()
    tool = start_tool(system)
    wait_until(logged(stub, "waiting"), tool)
    colcon, job = logged_pid(stub, "waiting"), logged_pid(stub, "job")
    os.kill(tool.pid, signal.SIGINT)
    wait_until(logged(stub, "got INT"), tool)
    os.kill(tool.pid, signal.SIGINT)  # the second: SIGTERM to colcon's group
    wait_until(logged(stub, "got TERM"), tool)
    assert tool.poll() is None  # colcon has not ended, so the tool waits
    os.kill(tool.pid, signal.SIGINT)  # the third: SIGKILL to colcon's group
    out, err = tool.communicate(timeout=30)
    assert tool.returncode == -signal.SIGINT
    assert gone(colcon) and gone(job)
    assert f"stopped by SIGINT; layers built in this run: none; {BASE} was stopped" in err
    assert (system / "setup.bash").read_text() == SETUP_TEXT


def test_a_ctrl_z_stops_colcon_with_the_tool_and_a_continue_continues_both(system, stub):
    (system / "src/u/STUB_WAIT").touch()
    tool = start_tool(system)
    wait_until(logged(stub, "waiting"), tool)
    colcon = logged_pid(stub, "waiting")
    os.kill(tool.pid, signal.SIGTSTP)
    wait_until(lambda: state(colcon) == "T" and state(tool.pid) == "T", None)
    os.kill(tool.pid, signal.SIGCONT)
    wait_until(lambda: state(colcon) not in ("T", None) and state(tool.pid) != "T", None)
    # Closing the terminal of a stopped job: SIGHUP, then SIGCONT, as the kernel and the shell
    # send them. The build ends with the tool.
    os.kill(tool.pid, signal.SIGTSTP)
    wait_until(lambda: state(colcon) == "T" and state(tool.pid) == "T", None)
    os.kill(tool.pid, signal.SIGHUP)
    os.kill(tool.pid, signal.SIGCONT)
    out, err = tool.communicate(timeout=30)
    assert tool.returncode == -signal.SIGHUP
    assert gone(colcon) and gone(logged_pid(stub, "job"))
    assert "got HUP" in stub.read_text()


@pytest.mark.parametrize("window", ["removal", "success"])
def test_a_stop_held_during_a_record_write_finds_the_run_in_agreement_with_it(
    system, stub, monkeypatch, capsys, window
):
    """A stop signal held during a write of the record is taken right after it: the message,
    the record and setup.bash then all describe the state that write made."""
    assert run(system, "build") == 0
    real_put = build.put_built_layers
    writes = []

    def put(*args):
        real_put(*args)
        writes.append(1)
        if len(writes) == (1 if window == "removal" else 2):
            os.kill(os.getpid(), signal.SIGINT)  # held: delivered when the write is done

    monkeypatch.setattr(build, "put_built_layers", put)
    capsys.readouterr()
    assert run(system, "build", "mid") == 128 + signal.SIGINT
    err = capsys.readouterr().err
    if window == "removal":
        assert list(built(system)) == [BASE, "top"]
        assert sourced_by_setup(system) == real(system)
        assert (
            "stopped by SIGINT; layers built in this run: none; mid was stopped and is not"
            f" built; setup.bash sources {BASE}" in err
        )
        assert len(runs(stub)) == 3  # colcon was not started for mid
    else:
        assert list(built(system)) == [BASE, "mid", "top"]
        assert sourced_by_setup(system) == real(system / "top")
        assert "stopped by SIGINT; layers built in this run: mid; setup.bash sources top" in err
        assert "was stopped" not in err


def test_colcon_is_not_taken_from_an_empty_or_relative_path_entry(
    system, stub, tmp_path, monkeypatch, capsys
):
    rel = system / "relbin"
    rel.mkdir()
    (rel / "colcon").write_text("#!/bin/sh\nexit 7\n")
    os.chmod(rel / "colcon", 0o755)
    empty = tmp_path / "empty"
    empty.mkdir()
    monkeypatch.setattr(build.sys, "executable", str(empty / "python3"))
    monkeypatch.setenv("PATH", os.pathsep.join(["relbin", ""]))
    assert run(system, "build") == 1
    assert "`colcon` is not found on PATH" in capsys.readouterr().err
    assert not (system / ".repos-manifest/built-jazzy.yaml").exists()
    # An absolute entry after them is used, and colcon runs by its absolute path in each layer.
    monkeypatch.setenv("PATH", os.pathsep.join(["relbin", "", str(STUB), "/usr/bin", "/bin"]))
    assert run(system, "build") == 0
    assert len(runs(stub)) == 3


def test_colcon_that_cannot_be_started_leaves_setup_bash_in_line_with_the_record(
    system, stub, monkeypatch, capsys
):
    assert run(system, "build") == 0

    def popen(argv, **kwargs):
        raise PermissionError(13, "Permission denied")

    monkeypatch.setattr(build.subprocess, "Popen", popen)
    capsys.readouterr()
    assert run(system, "build", "mid") == 1
    err = capsys.readouterr().err
    assert "could not be started in" in err and "Permission denied" in err
    assert f"; setup.bash sources {BASE}" in err
    assert list(built(system)) == [BASE, "top"]
    assert sourced_by_setup(system) == real(system)


@pytest.mark.parametrize(
    "arg",
    [
        "--base-paths",
        "--paths=src/x",
        "--install-base",
        "--install-base=elsewhere",
        "--build-base",
        "--build-b=elsewhere",
        "--install-b",
    ],
)
def test_forwarded_options_that_move_what_the_record_stands_on_are_refused(
    system, stub, capsys, arg
):
    assert run(system, "build", "--", "--symlink-install", arg, "x") == 1
    err = capsys.readouterr().err
    assert "is not passed to colcon: it would" in err and "nothing was run" in err
    assert runs(stub) == []
    assert not (system / ".repos-manifest/built-jazzy.yaml").exists()


def test_colcon_exiting_0_without_writing_install_setup_is_not_built(system, stub, capsys):
    capsys.readouterr()
    assert run(system, "build", "--", "--help") == 1
    out = capsys.readouterr().out
    assert (
        f"  not built: {BASE} (colcon exited 0 but did not write"
        f" {system / 'install/setup.bash'}, so nothing was built)\n" in out
    )
    assert "  not tried: mid, top\n" in out
    assert built(system) == {}
    assert (system / "setup.bash").read_text() == SETUP_TEXT
    # An install/setup.bash left by an earlier build does not count: colcon did not write it.
    assert run(system, "build") == 0
    assert run(system, "build", "mid", "--", "--help") == 1
    assert list(built(system)) == [BASE, "top"]
    assert sourced_by_setup(system) == real(system)


def test_each_distro_has_its_own_record(two_distros, stub):
    system = two_distros
    assert run(system, "build", "--distro", "rolling") == 0
    assert not (system / ".repos-manifest/built-jazzy.yaml").exists()
    before = (system / ".repos-manifest/built-rolling.yaml").read_text()
    assert run(system, "build", "--distro", "jazzy") == 0
    assert (system / ".repos-manifest/built-rolling.yaml").read_text() == before
    assert list(built(system, "jazzy")) == ["core"]


def test_a_second_build_of_the_same_distro_at_once_is_refused(two_distros, stub):
    system = two_distros
    (system / "jazzy/core/src/a/STUB_WAIT").touch()
    tool = start_tool(system, "--distro", "jazzy")
    wait_until(logged(stub, "waiting"), tool)
    second = start_tool(system, "--distro", "jazzy")
    try:
        try:
            out, err = second.communicate(timeout=30)
        except subprocess.TimeoutExpired:
            second.terminate()  # it ends its colcon's group too
            second.communicate(timeout=30)
            raise
        assert second.returncode == 1
        assert (
            "a build of distro jazzy is still running in this system"
            f" (process {tool.pid}); nothing was run" in err
        )
        # A build of another distro at the same time takes its own lock and record.
        assert run(system, "build", "--distro", "rolling") == 0
        assert list(built(system, "rolling")) == ["core"]
    finally:
        os.kill(tool.pid, signal.SIGTERM)
        tool.communicate(timeout=30)
    assert len([each for each in runs(stub) if each[0].endswith("jazzy/core")]) == 1
    (system / "jazzy/core/src/a/STUB_WAIT").unlink()
    assert run(system, "build", "--distro", "jazzy") == 0  # the lock went with the process


def test_setup_bash_stops_sourcing_a_layer_before_colcon_writes_to_it(system, stub):
    assert run(system, "build") == 0
    assert run(system, "build", "mid") == 0
    during = Path(f"{stub}.setup-during-mid").read_text()
    assert f"source {real(system)}/install/setup.bash" in during


def test_setup_bash_is_brought_into_line_when_no_layer_starts(stub, tmp_path, capsys):
    system, _, _ = three_layers(tmp_path, mid_optional_missing=True)
    assert run(system, "build") == 0
    (system / "setup.bash").write_text(SETUP_TEXT)
    capsys.readouterr()
    assert run(system, "build", "mid") == 0
    out = capsys.readouterr().out
    assert "  skipped, no repos on this machine: mid\n" in out
    assert out.endswith("setup.bash: sources top\n")
    assert sourced_by_setup(system) == real(system / "top")


def test_an_empty_layer_named_alone_is_skipped_not_refused(stub, tmp_path, capsys):
    system, _, _ = three_layers(tmp_path, mid_optional_missing=True)
    capsys.readouterr()
    assert run(system, "build", "mid") == 0
    out = capsys.readouterr().out
    assert "  skipped, no repos on this machine: mid\n" in out
    assert runs(stub) == []


def test_the_failed_line_offers_install_setup_only_when_it_is_there(system, stub, capsys):
    (system / "mid/src/m/STUB_FAIL_EARLY").touch()
    capsys.readouterr()
    assert run(system, "build") == 1
    out = capsys.readouterr().out
    assert f"  failed: mid (colcon exited 1); its log is in {system / 'mid' / 'log'}\n" in out
    assert "to use what it did build" not in out


def test_a_setup_file_that_sets_common_names_does_not_change_the_command(system, stub):
    assert run(system, "build", BASE) == 0
    with open(system / "install/setup.bash", "a") as handle:
        handle.write("setup=/nowhere; command=(false); cmd=false\n")
    assert run(system, "build", "mid") == 0
    assert runs(stub)[-1][0] == str(system / "mid")


def test_build_help_shows_the_colcon_arguments(capsys):
    with pytest.raises(SystemExit):
        repos_manifest.cli.main(["build", "--help"])
    assert "[-- COLCON_ARGS ...]" in capsys.readouterr().out


# --- Round 2: the lock with colcon, arguments, missing repos, package selection ----------


def lock_holders(path):
    """The pids of the processes that have `path` open."""
    found = []
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            links = [os.readlink(fd) for fd in (proc / "fd").iterdir()]
        except OSError:
            continue
        if str(path) in links:
            found.append(int(proc.name))
    return found


def test_the_lock_is_held_by_colcon_after_the_tool_is_killed_outright(system, stub, capsys):
    (system / "src/u/STUB_WAIT").touch()
    tool = start_tool(system)
    wait_until(logged(stub, "waiting"), tool)
    colcon = logged_pid(stub, "waiting")
    lock = build_lock_file(system, "jazzy")
    assert colcon in lock_holders(lock)
    try:
        os.kill(tool.pid, signal.SIGKILL)
        tool.wait(timeout=30)  # its pipes stay open in colcon
        assert state(colcon) not in (None, "Z")  # colcon runs on in its own session
        capsys.readouterr()
        assert run(system, "build") == 1
        err = capsys.readouterr().err
        assert (
            f"a build of distro jazzy is still running in this system: its colcon (process"
            f" {colcon}) still runs, though the `repos-manifest build` that started it (process"
            f" {tool.pid}) has ended; nothing was run" in err
        )
    finally:
        os.killpg(colcon, signal.SIGKILL)
    assert gone(colcon)
    wait_until(lambda: not lock_holders(lock), None)
    (system / "src/u/STUB_WAIT").unlink()
    assert run(system, "build") == 0


def test_a_lock_whose_named_processes_have_ended_says_how_to_find_its_holder(system, stub, capsys):
    fd = hold_build_lock(system, "jazzy")
    try:
        os.pwrite(fd, b"999999998 999999999\n", 0)
        assert run(system, "build") == 1
        err = capsys.readouterr().err
        assert "a build of distro jazzy is still running in this system; `fuser -v" in err
        assert "999999998" not in err
    finally:
        os.close(fd)


def test_a_plain_argument_first_after_the_separator_is_refused(system, stub, capsys):
    assert run(system, "build", "--", "mid/src/m") == 1
    err = capsys.readouterr().err
    assert "'mid/src/m' after -- is not an option, and `colcon build` takes no plain" in err
    assert run(system, "build", "--", "--symlink-install", "--", "x") == 1
    assert "a second -- is not passed to colcon" in capsys.readouterr().err
    assert runs(stub) == []
    assert not (system / ".repos-manifest/built-jazzy.yaml").exists()


def test_the_layers_paths_come_after_the_forwarded_arguments(system, stub):
    assert run(system, "build", BASE) == 0
    assert run(system, "build", BASE, "--", "--packages-select", "a", "b") == 0
    assert runs(stub)[-1][2] == "build --packages-select a b --base-paths src/u"


@pytest.mark.parametrize(
    "arg, said",
    [
        ("--b", "--b (colcon would reject it as ambiguous, and it could be --base-paths)"),
        ("--pa", "--pa (colcon would reject it as ambiguous, and it could be --paths)"),
        ("--install-b", "--install-b (colcon reads it as --install-base)"),
        ("--build-base=x", "--build-base is not passed"),
    ],
)
def test_an_abbreviation_is_named_for_what_colcon_would_do_with_it(system, stub, capsys, arg, said):
    assert run(system, "build", "--", arg) == 1
    assert said in capsys.readouterr().err


def test_a_required_repo_missing_from_disk_is_refused(system, stub, tmp_path, capsys):
    shutil.move(str(system / "mid/src/m"), str(tmp_path / "m-away"))
    assert run(system, "build", "mid") == 1
    err = capsys.readouterr().err
    assert "not on disk, and not optional: m (layer mid); nothing was run" in err
    assert "Run `repos-manifest sync`" in err
    assert run(system, "build") == 1
    assert runs(stub) == []
    assert run(system, "build", BASE) == 0  # a run that does not build mid is not refused


def test_a_layer_with_some_required_repos_missing_is_refused(stub, tmp_path, capsys):
    remotes = tmp_path / "remotes"
    data = {
        "format": 1,
        "repositories": {
            "a": repo(make_remote(remotes, "a")),
            "b": repo(make_remote(remotes, "b")),
        },
    }
    write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    shutil.rmtree(system / "src/b")
    capsys.readouterr()
    assert run(system, "build") == 1
    assert f"not on disk, and not optional: b (layer {BASE})" in capsys.readouterr().err
    assert runs(stub) == []


def test_package_selection_colcon_must_resolve_needs_one_layer(system, stub, capsys):
    assert run(system, "build", "--", "--packages-up-to", "m") == 1
    err = capsys.readouterr().err
    assert "--packages-up-to names packages colcon must find in each layer it builds" in err
    assert "this run would build 3 layers (_unnamed, mid, top); nothing was run" in err
    assert run(system, "build", "--", "--packages-ab=m") == 1
    assert "--packages-ab (--packages-above" in capsys.readouterr().err
    assert runs(stub) == []
    assert run(system, "build") == 0
    assert run(system, "build", "mid", "--", "--packages-up-to", "m") == 0
    assert runs(stub)[-1][2] == "build --packages-up-to m --base-paths src/m"


def test_package_selection_colcon_must_resolve_with_one_layer_with_repos(stub, tmp_path):
    system, _, _ = three_layers(tmp_path, mid_optional_missing=True)
    assert run(system, "build", BASE, "top", "--", "--packages-above", "t") == 1
    assert run(system, "build", "mid", "--", "--packages-above", "t") == 0  # mid: no repos
    assert run(system, "build") == 0
    assert run(system, "build", "mid", "top", "--", "--packages-above", "t") == 0
    assert runs(stub)[-1][2] == "build --packages-above t --base-paths src/t"


@pytest.mark.parametrize(
    "selection",
    [["--packages-select", "u"], ["--packages-sel", "u"], ["--packages-select-build-failed"]],
)
def test_a_selection_run_that_would_build_a_layer_not_built_is_refused(
    system, stub, capsys, selection
):
    capsys.readouterr()
    assert run(system, "build", "--", *selection) == 1
    err = capsys.readouterr().err
    assert (
        "a run with package selection builds only part of a layer, so it only rebuilds layers"
        f" that are built; not built: {BASE} (not built), mid (not built), top (not built);"
        " nothing was run" in err
    )
    assert (
        f"Build them without package selection first: `repos-manifest build {BASE} mid top`" in err
    )
    assert runs(stub) == []
    assert not (system / ".repos-manifest/built-jazzy.yaml").exists()
    assert run(system, "build", BASE) == 0
    assert run(system, "build", "--", *selection) == 1
    assert "not built: mid (not built), top (not built);" in capsys.readouterr().err
    assert run(system, "build", BASE, "--", *selection) == 0  # only the built layer


def test_a_selection_run_rebuilds_built_layers_and_gives_back_their_records(system, stub, capsys):
    assert run(system, "build") == 0
    before = built(system)
    capsys.readouterr()
    assert run(system, "build", "--", "--packages-select", "m", "--packages-select", "t") == 0
    assert [args for _, _, args in runs(stub)][3:] == [
        "build --packages-select m --packages-select t --base-paths src/u",
        "build --packages-select m --packages-select t --base-paths src/m",
        "build --packages-select m --packages-select t --base-paths src/t",
    ]
    assert built(system) == before  # repos, base and time as they were
    assert sourced_by_setup(system) == real(system / "top")
    out = capsys.readouterr().out
    assert f"  built: {BASE}, mid, top\n" in out and out.endswith("setup.bash: sources top\n")
    # A failure still leaves the layer not built; with --keep-going the layer above it is not
    # tried, since it could only be built on another base than its record's.
    (system / "mid/src/m/STUB_FAIL").touch()
    assert run(system, "build", "--keep-going", "--", "--packages-select", "m") == 1
    out = capsys.readouterr().out
    assert "  failed: mid (colcon exited 1)" in out and "  not tried: top\n" in out
    assert list(built(system)) == [BASE, "top"]
    assert built(system)["top"] == before["top"]
    assert sourced_by_setup(system) == real(system)


def test_a_layer_whose_repos_differ_from_its_record_is_not_built_for_a_selection(
    stub, tmp_path, capsys
):
    system, path, data = three_layers(tmp_path)
    assert run(system, "build") == 0
    data["repositories"]["n"] = repo(make_remote(tmp_path / "remotes", "n"), None, "mid")
    write_manifest(path, data)
    assert run(system, "sync") == 0
    capsys.readouterr()
    assert run(system, "build", "mid", "--", "--packages-select", "m") == 1
    err = capsys.readouterr().err
    assert "not built: mid (its repos differ from its record: new n); nothing was run" in err
    assert built(system)["mid"]["repos"] == ["m"]
    assert run(system, "build", "mid") == 0
    assert "NOTE: n is new in mid since it was last built\n" in capsys.readouterr().out
    assert built(system)["mid"]["repos"] == ["m", "n"]


@pytest.mark.parametrize("given", ["--packages-skip-build-finished", "--packages-skip-build"])
def test_resuming_a_layer_is_not_package_selection(system, stub, given):
    assert run(system, "build", "--", given) == 0
    assert list(built(system)) == [BASE, "mid", "top"]


def test_the_lock_file_is_written_before_it_is_cut_to_length(system, monkeypatch):
    from repos_manifest import system as system_module

    calls = []
    real_pwrite, real_ftruncate = os.pwrite, os.ftruncate
    monkeypatch.setattr(
        system_module.os, "pwrite", lambda *a: calls.append("write") or real_pwrite(*a)
    )
    monkeypatch.setattr(
        system_module.os, "ftruncate", lambda *a: calls.append("cut") or real_ftruncate(*a)
    )
    fd = hold_build_lock(system, "jazzy")
    try:
        system_module.note_lock_holders(fd, [123456789, 2])
        system_module.note_lock_holders(fd, [7])
        assert build_lock_file(system, "jazzy").read_text() == "7\n"
    finally:
        os.close(fd)
    assert calls == ["write", "cut"] * 3


def test_the_wait_for_the_group_reaps_its_own_zombies(system, stub):
    """As a subreaper (or PID 1) the tool inherits colcon's orphaned jobs: it reaps them while
    it waits for the group to go, rather than waiting out the whole bound."""
    (system / "src/u/STUB_WAIT").touch()
    package = str(Path(repos_manifest.__file__).parent.parent)
    code = (
        "import ctypes, sys; ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0);"
        " sys.argv = ['repos-manifest', 'build']; from repos_manifest.cli import run; run()"
    )
    tool = subprocess.Popen(
        [sys.executable, "-c", code],
        cwd=system,
        env={**os.environ, "PYTHONPATH": package},
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    wait_until(logged(stub, "waiting"), tool)
    job = logged_pid(stub, "job")
    os.kill(tool.pid, signal.SIGTERM)
    began = time.monotonic()
    out, err = tool.communicate(timeout=30)
    assert time.monotonic() - began < build._GROUP_GONE_SECONDS / 2
    assert tool.returncode == -signal.SIGTERM
    assert gone(job)
    assert "still there" not in err


def test_processes_that_outlive_the_wait_are_named_in_a_warning(monkeypatch, capsys):
    monkeypatch.setattr(build, "_GROUP_GONE_SECONDS", 0.1)
    calls = []

    def killpg(pgid, signum):
        calls.append(signum)  # the group never goes

    monkeypatch.setattr(build.os, "killpg", killpg)
    build._end_the_rest(4242424)
    assert signal.SIGKILL in calls
    err = capsys.readouterr().err
    assert "processes of colcon's process group 4242424 are still there" in err
    assert "`pgrep -g 4242424` lists them" in err


def test_a_stop_with_its_terminal_gone_still_ends_by_the_signal(system, stub):
    (system / "src/u/STUB_WAIT").touch()
    tool = start_tool(system)
    wait_until(logged(stub, "waiting"), tool)
    tool.stderr.close()  # the message cannot be printed: the tool must still end by SIGHUP
    os.kill(tool.pid, signal.SIGHUP)
    tool.wait(timeout=30)
    tool.stdout.close()
    assert tool.returncode == -signal.SIGHUP


def test_a_failed_rewrite_of_setup_bash_fails_the_run_even_if_a_later_one_works(
    system, stub, monkeypatch, capsys
):
    real_write = build.write_setup
    calls = []

    def write_setup(*args):
        calls.append(1)
        if len(calls) == 1:
            return "setup.bash: cannot be written: No space left on device"
        return real_write(*args)

    monkeypatch.setattr(build, "write_setup", write_setup)
    capsys.readouterr()
    assert run(system, "build") == 1
    out = capsys.readouterr().out
    assert "WARNING: setup.bash: cannot be written: No space left on device\n" in out
    assert "setup.bash: sources top\n" in out
    assert sourced_by_setup(system) == real(system / "top")


@pytest.mark.parametrize("where", ["time", "repos", "base", "layer"])
def test_a_record_with_a_control_character_is_unreadable(system, stub, capsys, where):
    assert run(system, "build") == 0
    path = system / ".repos-manifest/built-jazzy.yaml"
    data = yaml.safe_load(path.read_text())
    bad = "x\nexport EVIL=1"
    if where == "layer":
        data["layers"][bad] = data["layers"].pop("top")
    elif where == "repos":
        data["layers"]["top"]["repos"] = [bad]
    else:
        data["layers"]["top"][where] = bad
    path.write_text(yaml.safe_dump(data))
    capsys.readouterr()
    assert run(system, "build") == 1
    assert f"ERROR: {path}: " in capsys.readouterr().err
    assert "EVIL" not in (system / "setup.bash").read_text()


def test_a_stop_before_the_checks_end_releases_the_lock(system, stub, monkeypatch, capsys):
    def warnings(layers):
        os.kill(os.getpid(), signal.SIGINT)
        return []

    monkeypatch.setattr(build, "own_prefix_warnings", warnings)
    assert run(system, "build") == 128 + signal.SIGINT
    assert "stopped by SIGINT; nothing was changed" in capsys.readouterr().err
    os.close(hold_build_lock(system, "jazzy"))  # not refused: the lock was released


# --- With the real colcon -------------------------------------------------------------------


def _real_colcon_or_skip():
    missing = [tool for tool in ("colcon", "cmake") if shutil.which(tool) is None]
    if missing:
        why = f"{' and '.join(missing)} not on PATH"
        if os.environ.get("REPOS_MANIFEST_REQUIRE_COLCON") == "1":
            pytest.fail(f"{why}, and REPOS_MANIFEST_REQUIRE_COLCON=1")
        pytest.skip(why)


@pytest.fixture
def real_colcon(vcs, monkeypatch):
    _real_colcon_or_skip()
    for variable in build.PREFIX_VARIABLES:
        monkeypatch.delenv(variable, raising=False)


def packages_system(tmp_path, top_packages):
    remotes = tmp_path / "remotes"
    data = {
        "format": 1,
        "layers": ["top"],
        "repositories": {"good": repo(make_package_remote(remotes, "good"))},
    }
    for name, kwargs in top_packages.items():
        data["repositories"][name] = repo(make_package_remote(remotes, name, **kwargs), None, "top")
    write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    return system


@pytest.mark.colcon
def test_real_colcon_builds_a_layer_on_the_one_below(real_colcon, tmp_path):
    system = packages_system(tmp_path, {"good2": {"needs": "good"}})
    assert run(system, "build") == 0
    done = subprocess.run(
        ["bash", "-c", "source setup.bash && echo $CMAKE_PREFIX_PATH"],
        cwd=system,
        capture_output=True,
        text=True,
        check=True,
    )
    prefixes = done.stdout.strip().split(":")
    assert str(real(system / "top/install/good2")) in prefixes
    assert str(real(system / "install/good")) in prefixes


@pytest.mark.colcon
@pytest.mark.parametrize("keep_on", [False, True])
def test_real_colcon_a_failing_package_fails_the_layer(real_colcon, tmp_path, keep_on):
    system = packages_system(tmp_path, {"bad": {"bad": True}, "good2": {"needs": "good"}})
    extra = ["--", "--executor", "sequential"] + (["--continue-on-error"] if keep_on else [])
    assert run(system, "build", *extra) == 1
    assert list(built(system, "_unnamed")) == [BASE]
    assert sourced_by_setup(system) == real(system)
    # colcon writes install/setup.bash after a failed build; only the record says it failed.
    assert (system / "top/install/setup.bash").is_file()
    assert (system / "top/install/good2").is_dir() == keep_on


@pytest.mark.colcon
@pytest.mark.parametrize("signum", [signal.SIGTERM, signal.SIGINT])
def test_real_colcon_a_stop_leaves_no_job_of_the_build_running(real_colcon, tmp_path, signum):
    system = packages_system(tmp_path, {"slow": {"slow": True}})
    pids = tmp_path / "slow.pids"
    tool = start_tool(system, env={"SLOW_PIDS": str(pids)})
    wait_until(lambda: pids.exists() and pids.read_text().strip(), tool, seconds=120)
    job = int(pids.read_text().split()[0])
    assert state(job) not in (None, "Z")
    os.kill(tool.pid, signum)
    out, err = tool.communicate(timeout=60)
    assert tool.returncode == -signum
    # The make job and the sleep it runs were in colcon's group: none of it runs on.
    assert gone(job, seconds=0)
    assert list(built(system, "_unnamed")) == [BASE]
    assert sourced_by_setup(system) == real(system)
    assert "top was stopped and is not built" in err


@pytest.mark.colcon
def test_real_colcon_merge_install_keeps_the_chain(real_colcon, tmp_path):
    system = packages_system(tmp_path, {"good2": {"needs": "good"}})
    assert run(system, "build", "--", "--merge-install") == 0
    done = subprocess.run(
        ["bash", "-c", "source setup.bash && echo $CMAKE_PREFIX_PATH"],
        cwd=system,
        capture_output=True,
        text=True,
        check=True,
    )
    prefixes = done.stdout.strip().split(":")
    assert str(real(system / "top/install")) in prefixes
    assert str(real(system / "install")) in prefixes


@pytest.mark.colcon
def test_real_colcon_only_colcon_and_the_tool_hold_the_lock(real_colcon, tmp_path):
    """colcon starts its jobs with the lock's descriptor closed, so a job, or a daemon a job
    leaves behind, does not hold the lock; colcon itself does, after the tool is killed."""
    system = packages_system(tmp_path, {"slow": {"slow": True}})
    pids = tmp_path / "slow.pids"
    tool = start_tool(system, env={"SLOW_PIDS": str(pids)})
    wait_until(lambda: pids.exists() and pids.read_text().strip(), tool, seconds=120)
    job = int(pids.read_text().split()[0])
    lock = build_lock_file(system, None)
    colcon = os.getpgid(job)
    try:
        assert sorted(lock_holders(lock)) == sorted([tool.pid, colcon])
        os.kill(tool.pid, signal.SIGKILL)
        tool.wait(timeout=30)  # its pipes stay open in colcon
        assert lock_holders(lock) == [colcon]
        done = subprocess.run(
            [sys.executable, "-m", "repos_manifest.cli", "build"],
            cwd=system,
            env={**os.environ, "PYTHONPATH": str(Path(repos_manifest.__file__).parent.parent)},
            capture_output=True,
            text=True,
            timeout=60,
        )
        assert done.returncode == 1
        assert f"its colcon (process {colcon}) still runs" in done.stderr
    finally:
        os.killpg(colcon, signal.SIGKILL)
    assert gone(job) and gone(colcon)
    wait_until(lambda: not lock_holders(lock), None)


@pytest.mark.colcon
def test_real_colcon_package_selection(real_colcon, tmp_path):
    system = packages_system(tmp_path, {"good2": {"needs": "good"}, "other": {}})
    assert run(system, "build", "--", "--packages-up-to", "good2") == 1
    assert run(system, "build", "--", "--packages-select", "good2") == 1
    assert not (system / ".repos-manifest/built-_unnamed.yaml").exists()
    assert run(system, "build") == 0
    before = built(system, "_unnamed")
    # The unnamed layer has no good2: colcon builds nothing there, exits 0 and still writes
    # its install/setup.bash, so the layer keeps its record.
    assert run(system, "build", "--", "--packages-select", "good2") == 0
    assert run(system, "build", "top", "--", "--packages-up-to", "good2") == 0
    assert built(system, "_unnamed") == before
    assert sourced_by_setup(system) == real(system / "top")


@pytest.mark.colcon
def test_real_colcon_a_failed_layer_is_resumed_and_recorded(real_colcon, tmp_path):
    system = packages_system(tmp_path, {"bad": {"bad": True}, "good2": {"needs": "good"}})
    assert run(system, "build", "--", "--continue-on-error") == 1
    assert list(built(system, "_unnamed")) == [BASE]
    lists = system / "top/src/bad/CMakeLists.txt"
    lists.write_text(lists.read_text().replace("message(FATAL_ERROR", "message(STATUS"))
    # Only the packages that failed: selection, refused on a layer that is not built.
    assert run(system, "build", "top", "--", "--packages-select-build-failed") == 1
    assert list(built(system, "_unnamed")) == [BASE]
    # Every package not finished yet: it completes the layer, which is then recorded.
    assert run(system, "build", "top", "--", "--packages-skip-build-finished") == 0
    assert list(built(system, "_unnamed")) == [BASE, "top"]
    assert sourced_by_setup(system) == real(system / "top")
