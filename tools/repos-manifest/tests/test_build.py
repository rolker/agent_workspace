"""`build`: the layers in order with colcon, the record of what was built, the built run, and
the one `setup.bash`. Most tests use a stand-in for colcon (fixtures/stub_colcon); the tests
marked `colcon` build real plain-CMake packages with the colcon on PATH."""

import os
import resource
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
from repos_manifest.signals import Stopped, signals_end_the_run
from repos_manifest.system import SETUP_TEXT, build_lock_file, hold_build_lock

STUB = Path(__file__).parent / "fixtures" / "stub_colcon"
BASE = "_unnamed"


@pytest.fixture
def stub(vcs, monkeypatch, tmp_path):
    """The stand-in colcon first on PATH, its log, and no prefix variable from the caller; no
    file of colcon's default arguments from the caller either."""
    os.chmod(STUB / "colcon", 0o755)
    monkeypatch.setenv("PATH", f"{STUB}{os.pathsep}{os.environ['PATH']}")
    log = tmp_path / "colcon.log"
    monkeypatch.setenv("STUB_COLCON_LOG", str(log))
    for variable in build.PREFIX_VARIABLES + ("STUB_SOURCED", "COLCON_DEFAULTS_FILE"):
        monkeypatch.delenv(variable, raising=False)
    monkeypatch.setenv("COLCON_HOME", str(tmp_path / "colcon-home"))
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
    assert [records[name]["below"] for name in records] == [[], [BASE], [BASE, "mid"]]
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
    assert built(system)["top"]["below"] == [BASE, "mid"]
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
    assert built(system)["top"]["below"] == [BASE]
    assert "mid" not in built(system)
    assert sourced_by_setup(system) == real(system)
    out = capsys.readouterr().out
    assert f"  built: {BASE}\n" in out
    # colcon wrote mid's install/ before it failed: top may have found it through its cache.
    assert (
        "  built without sourcing mid (failed), so not used: top (it may have used what is left"
        f" in {system / 'mid/install'}/ through paths its build directory kept from an earlier"
        " build)\n" in out
    )
    assert "  failed: mid (colcon exited 1)" in out
    assert "not tried" not in out
    assert out.endswith(f"setup.bash: sources {BASE}\n")
    # mid fixed and built alone: top was built without it, so it is not built until rebuilt.
    (system / "mid/src/m/STUB_FAIL").unlink()
    assert run(system, "build", "mid") == 0
    out = capsys.readouterr().out
    assert (
        "  recorded built, not used: top (built on _unnamed, but the built run below it is now"
        " _unnamed, mid)\n" in out
    )
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
    assert f"  built without sourcing {BASE} (failed), so not used: mid (it may have used" in out
    assert f"  built without sourcing {BASE} (failed), so not used: top (it may have used" in out


def test_keep_going_without_output_of_the_failed_layer_names_none(system, stub, capsys):
    (system / "mid/src/m/STUB_FAIL_EARLY").touch()
    capsys.readouterr()
    assert run(system, "build", "--keep-going") == 1
    assert "  built without sourcing mid (failed), so not used: top\n" in capsys.readouterr().out


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
    assert built(system)["top"]["below"] == [BASE]
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
        "  recorded built, not used: top (built on _unnamed, but the built run below it is now"
        " _unnamed, mid)\n" in out
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
    data["layers"]["gone"] = {"time": "t", "repos": ["g"], "below": []}
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


def _no_core_dump():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))  # a SIGQUIT writes no core file


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
        preexec_fn=_no_core_dump,
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


@pytest.mark.parametrize("signum", [signal.SIGTERM, signal.SIGINT, signal.SIGHUP, signal.SIGQUIT])
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
        " that are built, with the repos their record has; not built:"
        f" {BASE} (not built), mid (not built), top (not built); nothing was run" in err
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
    assert built(system) == before  # repos, chain and time as they were
    assert sourced_by_setup(system) == real(system / "top")
    out = capsys.readouterr().out
    assert f"  rebuilt with selection: {BASE}, mid, top\n" in out
    assert "  built:" not in out and out.endswith("setup.bash: sources top\n")
    # A failure still leaves the layer not built; with --keep-going the layer above it is not
    # tried, since it could only be built on another chain than its record's.
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
    assert (
        "built, but its repos differ from its record: mid (new n); nothing was run. Build it"
        " without package selection first, which also records the changed repos:"
        " `repos-manifest build mid`" in err
    )
    assert "not built:" not in err
    # Both kinds at once, each named as what it is, and one step naming every layer in the
    # manifest's order, so that top is built on mid as it will be.
    (system / "top/install/setup.bash").unlink()
    assert run(system, "build", "mid", "top", "--", "--packages-select", "m") == 1
    err = capsys.readouterr().err
    assert "; not built: top (recorded built, but" in err
    assert "; built, but its repos differ from its record: mid (new n); nothing was run" in err
    assert (
        "Build them without package selection first, which also records the changed repos:"
        " `repos-manifest build mid top`\n" in err
    )
    (system / "top/install/setup.bash").write_text("")
    assert built(system)["mid"]["repos"] == ["m"]
    assert run(system, "build", "mid") == 0
    assert "NOTE: n is new in mid since it was last built\n" in capsys.readouterr().out
    assert built(system)["mid"]["repos"] == ["m", "n"]


@pytest.mark.parametrize("given", ["--packages-skip-build-finished", "--packages-skip-build"])
def test_resuming_a_layer_is_not_package_selection(system, stub, given):
    assert run(system, "build", "--", given) == 0
    assert list(built(system)) == [BASE, "mid", "top"]


# --- Packages left out of a whole layer ------------------------------------------------------


def test_a_skip_list_on_a_first_build_is_recorded_and_the_layers_above_build_on_it(
    system, stub, capsys
):
    capsys.readouterr()
    assert run(system, "build", BASE, "mid", "--", "--packages-skip", "x", "y") == 0
    assert built(system)[BASE]["without"] == {"--packages-skip": ["x", "y"]}
    assert built(system)["mid"]["without"] == {"--packages-skip": ["x", "y"]}
    out = capsys.readouterr().out
    assert f"  built: {BASE}, mid\n" in out
    assert f"  built with --packages-skip x y given to colcon: {BASE}, mid\n" in out
    assert "options given to colcon changed" not in out and "built without sourcing" not in out
    assert sourced_by_setup(system) == real(system / "mid")
    # The layer above builds on it, with no skip option given to its own colcon.
    assert run(system, "build", "top") == 0
    assert "without" not in built(system)["top"]
    assert runs(stub)[-1][1] == "mid"
    assert sourced_by_setup(system) == real(system / "top")
    out = capsys.readouterr().out
    assert "given to colcon:" not in out


def test_the_same_skip_list_again_changes_nothing_and_another_is_named(system, stub, capsys):
    assert run(system, "build", "--", "--packages-skip", "x", "y") == 0
    capsys.readouterr()
    assert run(system, "build", "mid", "--", "--packages-skip", "y", "x") == 0
    assert built(system)["mid"]["without"] == {"--packages-skip": ["y", "x"]}
    out = capsys.readouterr().out
    assert "options given to colcon changed" not in out
    assert "  built with --packages-skip y x given to colcon: mid\n" in out
    # Another list: named, and the layers above stay in the built run (a rebuild in place).
    assert run(system, "build", "mid", "--", "--packages-skip", "z") == 0
    out = capsys.readouterr().out
    assert (
        "  skip and ignore options given to colcon changed: mid (was --packages-skip y x, now"
        " --packages-skip z); what an earlier build installed of a package they skip or ignore"
        " now stays in"
        f" {system / 'mid/install'}/\n" in out
    )
    assert "  built before, in the run: _unnamed, top (on the earlier output of mid)\n" in out
    assert "not used" not in out
    assert sourced_by_setup(system) == real(system / "top")
    # No list: the record drops it, and the change says so.
    assert run(system, "build", "mid") == 0
    assert "without" not in built(system)["mid"]
    out = capsys.readouterr().out
    assert (
        "  skip and ignore options given to colcon changed: mid (was --packages-skip z, now none)\n"
        in out
    )
    assert "given to colcon:" not in out
    assert sourced_by_setup(system) == real(system / "top")


@pytest.mark.parametrize(
    "given, recorded",
    [
        (["--packages-ignore", "x"], {"--packages-ignore": ["x"]}),
        (["--packages-skip-regex", "^x$"], {"--packages-skip-regex": ["^x$"]}),
        (["--packages-ignore-regex", "^x$", "y.*"], {"--packages-ignore-regex": ["^x$", "y.*"]}),
        (["--packages-skip-r", "^x$"], {"--packages-skip-regex": ["^x$"]}),
        (["--packages-ignore-=^x$"], {"--packages-ignore-regex": ["^x$"]}),
        (["--packages-skip=x"], {"--packages-skip": ["x"]}),
        (["--packages-skip", "a", "--packages-skip", "b"], {"--packages-skip": ["b"]}),
        (["--packages-skip", "a", "b"], {"--packages-skip": ["a", "b"]}),
        (
            ["--packages-ignore", "c", "--packages-skip", "a"],
            {"--packages-skip": ["a"], "--packages-ignore": ["c"]},
        ),
        # colcon reads an argument that is not one of its options as a value, `-1` too.
        (["--packages-skip-regex", "-1", "x"], {"--packages-skip-regex": ["-1", "x"]}),
        (
            ["--packages-skip", "a", "--cmake-args", "-DX=1", "--packages-skip-r", "^b$"],
            {"--packages-skip": ["a"], "--packages-skip-regex": ["^b$"]},
        ),
        (["--packages-skip", "a", "--packages-skip-build-finished"], {"--packages-skip": ["a"]}),
        # A list of package names ends at any argument starting with `-`: an option of a colcon
        # extension `build` does not know, which colcon reads as an option when it has it (and
        # otherwise rejects as a package name, building nothing).
        (["--packages-skip", "a", "--meson-args", "x"], {"--packages-skip": ["a"]}),
        (
            ["--packages-ignore", "a", "-x", "b", "--packages-skip-regex", "^c"],
            {"--packages-skip-regex": ["^c"], "--packages-ignore": ["a"]},
        ),
        # colcon strips leading whitespace from a package name, not from a pattern.
        (["--packages-skip", " a", "\tb "], {"--packages-skip": ["a", "b "]}),
        (["--packages-ignore= a"], {"--packages-ignore": ["a"]}),
        (["--packages-skip-regex", " ^a"], {"--packages-skip-regex": [" ^a"]}),
        # A pattern may start with `-`: a regex list ends only at an option colcon has.
        (
            ["--packages-skip-regex", "^a", "--meson-args", "x"],
            {"--packages-skip-regex": ["^a", "--meson-args", "x"]},
        ),
    ],
)
def test_each_way_of_leaving_packages_out_is_recorded_as_colcon_reads_it(
    system, stub, given, recorded
):
    assert run(system, "build", "--", *given) == 0
    assert all(built(system)[name]["without"] == recorded for name in (BASE, "mid", "top"))
    assert runs(stub)[0][2] == f"build {' '.join(given)} --base-paths src/u"


@pytest.mark.parametrize(
    "given", [["--packages-skip"], ["--packages-skip", "b", "--packages-skip"]]
)
def test_an_option_whose_last_occurrence_has_no_values_leaves_nothing_out(
    system, stub, capsys, given
):
    capsys.readouterr()
    assert run(system, "build", "--", *given) == 0
    assert all("without" not in record for record in built(system).values())
    assert "given to colcon:" not in capsys.readouterr().out
    assert run(system, "build") == 0  # the record reads


@pytest.mark.parametrize(
    "given",
    [
        ["--packages-ig", "x"],  # --packages-ignore or its -regex form: ambiguous to colcon
        ["--packages-s", "x"],
        ["--packages-skip-", "x"],
        ["--packages-skip-by-dep", "x"],
        ["--packages-skip-up-to", "x"],
        ["--packages-skip-test-passed"],
        ["--packages-skip", "x", "--packages-select", "y"],
        ["--packages-select", "y"],
    ],
)
def test_leaving_out_by_the_graph_or_beside_selection_is_still_refused_on_a_layer_not_built(
    system, stub, capsys, given
):
    capsys.readouterr()
    assert run(system, "build", "--", *given) == 1
    err = capsys.readouterr().err
    # `--packages-s` could be `--packages-start`, refused first for naming packages to find.
    assert "a run with package selection builds only part of a layer" in err or (
        given[0] == "--packages-s" and "--packages-s (--packages-start) names packages" in err
    )
    assert runs(stub) == []
    assert not (system / ".repos-manifest/built-jazzy.yaml").exists()


def test_a_selection_run_keeps_the_recorded_list_and_says_a_given_one_is_not_recorded(
    system, stub, capsys
):
    assert run(system, "build", "--", "--packages-skip", "x") == 0
    before = built(system)
    capsys.readouterr()
    assert run(system, "build", "--", "--packages-select", "m", "--packages-skip", "y") == 0
    assert built(system) == before
    out = capsys.readouterr().out
    assert f"  rebuilt with selection: {BASE}, mid, top\n" in out
    assert (
        "  not recorded, given with package selection: --packages-skip y (a run that builds"
        " only part of a layer gives each layer back the record it had)\n" in out
    )
    assert "given to colcon:" not in out and "options given to colcon changed" not in out


def test_no_unrecorded_line_when_no_layer_of_a_selection_run_was_built(system, stub, capsys):
    assert run(system, "build") == 0
    (system / "mid/src/m/STUB_FAIL").touch()
    capsys.readouterr()
    status = run(system, "build", "mid", "--", "--packages-select", "m", "--packages-skip", "y")
    assert status == 1
    out = capsys.readouterr().out
    assert "  failed: mid (colcon exited" in out
    assert "not recorded" not in out


def test_a_layer_built_leaving_out_under_keep_going_and_not_used_is_named(system, stub, capsys):
    (system / "mid/src/m/STUB_FAIL").touch()
    capsys.readouterr()
    assert run(system, "build", "--keep-going", "--", "--packages-skip", "x") == 1
    assert built(system)["top"]["without"] == {"--packages-skip": ["x"]}
    out = capsys.readouterr().out
    assert f"  built with --packages-skip x given to colcon: {BASE}, top\n" in out
    assert "  built without sourcing mid (failed), so not used: top" in out


def test_a_package_name_with_leading_whitespace_is_the_same_name_to_colcon(system, stub, capsys):
    assert run(system, "build", "--", "--packages-skip", "x") == 0
    capsys.readouterr()
    assert run(system, "build", "mid", "--", "--packages-skip", " x") == 0
    assert built(system)["mid"]["without"] == {"--packages-skip": ["x"]}
    assert "options given to colcon changed" not in capsys.readouterr().out


def test_the_options_are_named_as_given_to_colcon_also_for_a_layer_without_such_packages(
    system, stub, capsys
):
    # No layer of the system has a package `a` or `c`: the line says what colcon was given.
    capsys.readouterr()
    assert run(system, "build", "--", "--packages-ignore", "c", "--packages-skip", "a") == 0
    out = capsys.readouterr().out
    assert (
        f"  built with --packages-skip a --packages-ignore c given to colcon: {BASE}, mid, top\n"
        in out
    )
    assert "leaving out" not in out


def test_a_record_with_a_list_written_by_build_reads_back_for_the_next_build(system, stub):
    given = ["--packages-skip", "a b", "--packages-ignore-regex", "-1", "'q'", "yes", "1"]
    assert run(system, "build", "--", *given) == 0
    assert built(system)["top"]["without"] == {
        "--packages-skip": ["a b"],
        "--packages-ignore-regex": ["-1", "'q'", "yes", "1"],
    }
    assert run(system, "build", "top") == 0
    assert run(system, "build", "top", "--", "--packages-select", "t") == 0


@pytest.mark.parametrize(
    "given, shown, what",
    [
        (
            ["--packages-skip", "grid\nmap"],
            "--packages-skip value 'grid\\x0amap'",
            "holds a control",
        ),
        (
            ["--packages-skip-regex", "^a\t"],
            "--packages-skip-regex value '^a\\x09'",
            "holds a control",
        ),
        # A byte that is not UTF-8 reaches Python as a lone surrogate (`surrogateescape`).
        (
            ["--packages-ignore=grid\udcffmap"],
            "--packages-ignore value 'grid\\xffmap'",
            "is not UTF-8",
        ),
        # Beside package selection too: the report would name it.
        (["--packages-select", "m", "--packages-skip", "a\u202eb"], "'a\\u202eb'", "holds a"),
    ],
)
def test_a_skip_value_the_record_cannot_hold_is_refused_and_the_old_record_survives(
    system, stub, capsys, given, shown, what
):
    assert run(system, "build", "--", "--packages-skip", "x") == 0
    before = (system / ".repos-manifest/built-jazzy.yaml").read_text()
    setup = (system / "setup.bash").read_text()
    count = len(runs(stub))
    capsys.readouterr()
    assert run(system, "build", "--", *given) == 1
    out, err = capsys.readouterr()
    assert f"{shown} {what}" in err and "nothing was run" in err
    assert err.isascii()
    assert out == ""  # no report: nothing ran
    assert len(runs(stub)) == count
    assert (system / ".repos-manifest/built-jazzy.yaml").read_text() == before
    assert (system / "setup.bash").read_text() == setup
    assert run(system, "build") == 0  # the record still reads


AWKWARD = [
    "",
    " ",
    "  x",
    "x ",
    "a b",
    "yes",
    "no",
    "on",
    "1",
    "0x1",
    "1e3",
    "~",
    "null",
    "a: b",
    "- x",
    "-x",
    "-1",
    "#c",
    "x #c",
    "'q'",
    '"q"',
    "\\",
    "a\\nb",
    "*",
    "&a",
    "*a",
    "!tag",
    "%x",
    "@x",
    "`x",
    "{x",
    "[x",
    "|",
    ">",
    "?",
    ",",
    "\u00e9",
    "\u65e5\u672c",
    "\U0001f600",
    "x" * 300,
    "\n",
    "\r",
    "\t",
    "\x00",
    "\x1b[31m",
    "\x7f",
    "\x85",
    "\u2028",
    "\u200b",
    "\u202e",
    "\ufeff",
    "\xa0",
    "\udcff",
    "\ud800",
]


@pytest.mark.parametrize("value", AWKWARD, ids=[ascii(value)[:20] for value in AWKWARD])
@pytest.mark.parametrize("option", ["--packages-skip", "--packages-ignore-regex"])
def test_build_never_writes_a_list_its_own_reader_refuses(system, stub, capsys, option, value):
    from repos_manifest.system import read_built

    assert run(system, "build", "--", "--packages-skip", "x") == 0
    before = read_built(system, "jazzy")
    status = run(system, "build", "--", option, value, "--packages-skip-regex", "z")
    records = read_built(system, "jazzy")  # never refused
    if status == 0:
        expected = build.left_out([option, value, "--packages-skip-regex", "z"])
        assert all(record.without == expected for record in records.values())
    else:
        assert records == before
        assert "nothing was run" in capsys.readouterr().err
    assert run(system, "build") == 0


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
        if len(calls) == 2:  # the rewrite after the first layer was built
            return build.SetupProblem(
                "setup.bash: cannot be written: No space left on device", False
            )
        return real_write(*args)

    monkeypatch.setattr(build, "write_setup", write_setup)
    capsys.readouterr()
    assert run(system, "build") == 1
    out = capsys.readouterr().out
    assert "WARNING: setup.bash: cannot be written: No space left on device\n" in out
    assert "setup.bash: sources top\n" in out
    assert sourced_by_setup(system) == real(system / "top")


@pytest.mark.parametrize("where", ["time", "repos", "below", "layer"])
def test_a_record_with_a_control_character_is_unreadable(system, stub, capsys, where):
    assert run(system, "build") == 0
    path = system / ".repos-manifest/built-jazzy.yaml"
    data = yaml.safe_load(path.read_text())
    bad = "x\nexport EVIL=1"
    if where == "layer":
        data["layers"][bad] = data["layers"].pop("top")
    elif where in ("repos", "below"):
        data["layers"]["top"][where] = [bad]
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


# --- Round 6: the chain, real paths, what colcon leaves, signals, setup.bash, the lock -----


def four_layers(tmp_path):
    """A system with no distros: `u` in the unnamed layer, then `x` (its one repo optional and
    not there yet), `b` and `c`."""
    remotes = tmp_path / "remotes"
    data = {
        "format": 1,
        "layers": ["x", "b", "c"],
        "repositories": {
            "u": repo(make_remote(remotes, "u")),
            "xr": repo(remotes / "xr", None, "x", optional=True),
            "br": repo(make_remote(remotes, "br"), None, "b"),
            "cr": repo(make_remote(remotes, "cr"), None, "c"),
        },
    }
    write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    return system


def test_a_layer_filled_below_takes_every_layer_above_out_of_the_run(stub, tmp_path, capsys):
    """The record holds the whole chain a layer was built on, not only the layer just below:
    x filled and built with b, c above b is not built until it is built on x too."""
    system = four_layers(tmp_path)
    assert run(system, "build") == 0
    assert built(system, BASE)["c"]["below"] == [BASE, "b"]
    make_remote(tmp_path / "remotes", "xr")
    assert run(system, "sync") == 0
    capsys.readouterr()
    assert run(system, "build", "x", "b") == 0
    out = capsys.readouterr().out
    assert "  built: x, b\n" in out
    assert (
        "  recorded built, not used: c (built on _unnamed, b, but the built run below it is now"
        " _unnamed, x, b)\n" in out
    )
    assert "on the earlier output" not in out
    assert out.endswith("setup.bash: sources b\n")
    assert sourced_by_setup(system) == real(system / "b")
    assert built(system, BASE)["b"]["below"] == [BASE, "x"]
    # A plain build rebuilds c, on the whole run below it.
    capsys.readouterr()
    assert run(system, "build") == 0
    assert runs(stub)[-1][0] == str(system / "c") and runs(stub)[-1][1] == "b"
    assert built(system, BASE)["c"]["below"] == [BASE, "x", "b"]
    assert sourced_by_setup(system) == real(system / "c")


def test_a_rebuild_in_place_keeps_the_chain_and_the_layers_above(stub, tmp_path, capsys):
    system = four_layers(tmp_path)
    assert run(system, "build") == 0
    capsys.readouterr()
    assert run(system, "build", "b") == 0
    out = capsys.readouterr().out
    assert f"  built before, in the run: {BASE}, c (on the earlier output of b)\n" in out
    assert sourced_by_setup(system) == real(system / "c")


def test_a_record_in_the_single_base_form_is_read_as_not_built(system, stub, capsys):
    assert run(system, "build") == 0
    path = system / ".repos-manifest/built-jazzy.yaml"
    data = yaml.safe_load(path.read_text())
    for name, below in ((BASE, None), ("mid", BASE), ("top", "mid")):
        data["layers"][name] = {"time": "t", "repos": data["layers"][name]["repos"], "base": below}
    path.write_text(yaml.safe_dump(data))
    capsys.readouterr()
    assert run(system, "build", "top") == 1
    assert f"top is built on {BASE}, which is not built; nothing was run" in capsys.readouterr().err
    assert run(system, "build") == 0
    assert [cwd for cwd, _, _ in runs(stub)][3:] == [
        str(system),
        str(system / "mid"),
        str(system / "top"),
    ]
    assert built(system)["top"]["below"] == [BASE, "mid"]


def test_a_layer_directory_that_is_a_link_is_named_by_its_real_path(system, stub, tmp_path, capsys):
    """setup.bash and the report name a layer's setup file the same way: through the real
    directory colcon ran in, not through the link."""
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    shutil.move(str(system / "top"), str(elsewhere / "top"))
    os.symlink(elsewhere / "top", system / "top")
    assert run(system, "build") == 0
    text = (system / "setup.bash").read_text()
    assert f"source {elsewhere / 'top' / 'install' / 'setup.bash'}\n" in text
    (system / "top/src/t/STUB_FAIL").touch()
    capsys.readouterr()
    assert run(system, "build", "top") == 1
    out = capsys.readouterr().out
    assert (
        f"to use what it did build: source {elsewhere / 'top' / 'install' / 'setup.bash'}\n" in out
    )


def test_files_of_colcon_default_arguments_are_named_in_a_note(
    system, stub, tmp_path, monkeypatch, capsys
):
    (system / "mid/colcon_defaults.yaml").write_text("build: {packages-select: [m]}\n")
    capsys.readouterr()
    assert run(system, "build") == 0
    out = capsys.readouterr().out
    note = "; `build` sees only the arguments after --, so package selection or a target that"
    assert (
        f"NOTE: colcon reads default arguments from {system / 'mid/colcon_defaults.yaml'}{note}"
        in out
    )
    assert out.count("NOTE: colcon reads default arguments") == 1
    # A skip list set there is not seen either, so the record has no list for it.
    assert (
        " the layer is recorded built as a whole; packages left out there (--packages-skip,"
        " --packages-ignore) are not recorded either\n" in out
    )
    home = tmp_path / "colcon-home"
    home.mkdir()
    (home / "defaults.yaml").write_text("{}\n")
    assert run(system, "build", BASE) == 0
    assert f"NOTE: colcon reads default arguments from {home / 'defaults.yaml'}{note}" in (
        capsys.readouterr().out
    )
    (tmp_path / "mine.yaml").write_text("{}\n")
    monkeypatch.setenv("COLCON_DEFAULTS_FILE", str(tmp_path / "mine.yaml"))
    assert run(system, "build", BASE) == 0
    out = capsys.readouterr().out
    assert f"NOTE: colcon reads default arguments from {tmp_path / 'mine.yaml'}{note}" in out
    assert str(home) not in out


def test_a_job_colcon_leaves_behind_is_ended_when_colcon_exits(system, stub):
    (system / "src/u/STUB_LEAVE").touch()
    assert run(system, "build", BASE) == 0
    assert gone(logged_pid(stub, "left"))


def test_a_colcon_killed_from_outside_has_the_rest_of_its_group_ended(system, stub):
    (system / "src/u/STUB_WAIT").touch()
    tool = start_tool(system)
    wait_until(logged(stub, "waiting"), tool)
    colcon, job = logged_pid(stub, "waiting"), logged_pid(stub, "job")
    os.kill(colcon, signal.SIGKILL)  # as the kernel's out-of-memory killer would
    out, err = tool.communicate(timeout=30)
    assert tool.returncode == 1
    assert gone(job)
    assert f"  failed: {BASE} (colcon exited -9)" in out


def test_a_stop_signal_while_the_handlers_are_put_back_still_ends_the_run(monkeypatch):
    """A stop signal that comes while run_child puts the run's handlers back is held until they
    are all back, and then ends the run through the run's own handler."""
    real_signal = signal.signal
    restored = []

    def put(sig, handler):
        if sig in build._STOP and getattr(handler, "__name__", "") == "on_signal":
            restored.append(sig)
            if len(restored) == 1:
                os.kill(os.getpid(), signal.SIGINT)
        return real_signal(sig, handler)

    with signals_end_the_run():
        monkeypatch.setattr(build.signal, "signal", put)
        with pytest.raises(Stopped) as stopped:
            build.run_child([sys.executable, "-c", "pass"], Path.cwd())
        monkeypatch.setattr(build.signal, "signal", real_signal)
        assert stopped.value.signum == signal.SIGINT
        # Every handler is the run's own again: none of run_child's is left behind.
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            assert getattr(signal.getsignal(sig), "__name__", "") == "on_signal"


def test_a_failed_rewrite_of_setup_bash_before_a_layer_stops_the_run_there(
    system, stub, monkeypatch, capsys
):
    assert run(system, "build") == 0
    real_replace = build.replace_file
    calls = []

    def replace_file(*args):
        calls.append(1)
        if len(calls) == 1:  # the rewrite before mid's colcon
            raise OSError(28, "No space left on device")
        return real_replace(*args)

    monkeypatch.setattr(build, "replace_file", replace_file)
    capsys.readouterr()
    assert run(system, "build", "mid", "top") == 1
    out = capsys.readouterr().out
    assert len(runs(stub)) == 3  # colcon was not started on mid
    assert (
        "  stopped before mid: setup.bash could not be brought into line with the record, so"
        " colcon was not started on it; it keeps its record\n" in out
    )
    assert "  not tried: top\n" in out
    assert f"  built before, in the run: {BASE}, mid, top\n" in out
    assert "cannot be written: No space left on device" in out
    assert list(built(system)) == [BASE, "mid", "top"]  # mid, untouched, has its record back
    assert sourced_by_setup(system) == real(system / "top")


def test_an_install_setup_left_by_an_earlier_build_is_removed_before_colcon_starts(
    system, stub, capsys
):
    assert run(system, "build") == 0
    (system / "mid/src/m/STUB_FAIL_EARLY").touch()
    capsys.readouterr()
    assert run(system, "build", "mid") == 1
    assert stub.read_text().splitlines().count("install-setup-at-start=yes") == 0
    out = capsys.readouterr().out
    assert (
        f"  failed: mid (colcon exited 1); its log is in {system / 'mid' / 'log'}; its earlier"
        f" {system / 'mid/install/setup.bash'} was removed when this run started on it and is"
        " not there now\n" in out
    )
    assert "to use what it did build" not in out
    assert not (system / "mid/install/setup.bash").exists()


@pytest.mark.parametrize("given", [["--distro="], ["--distro", ""]])
def test_an_empty_distro_name_is_refused(two_distros, stub, capsys, given):
    assert run(two_distros, "build", *given) == 1
    assert "--distro is given an empty name" in capsys.readouterr().err
    assert runs(stub) == []


@pytest.mark.parametrize("named", ["0", "living"])
def test_the_lock_message_names_only_a_process_that_holds_the_lock(system, stub, capsys, named):
    other = subprocess.Popen(["sleep", "30"])
    fd = hold_build_lock(system, "jazzy")
    try:
        pid = 0 if named == "0" else other.pid
        os.pwrite(fd, f"{pid} {pid}\n".encode(), 0)
        os.ftruncate(fd, len(f"{pid} {pid}\n"))
        assert run(system, "build") == 1
        err = capsys.readouterr().err
        assert "a build of distro jazzy is still running in this system; `fuser -v" in err
        assert "process" not in err.split("; `fuser")[0]
    finally:
        os.close(fd)
        other.kill()
        other.wait()


@pytest.mark.parametrize("name", ["layers.txt", "optional.txt"])
def test_resolved_files_that_are_not_text_give_an_error_naming_them(system, stub, capsys, name):
    path = system / ".repos-manifest/resolved" / name
    path.write_bytes(b"\xff\xfe\x00bad\n")
    assert run(system, "build") == 1
    err = capsys.readouterr().err
    assert f"ERROR: {path}: does not read as UTF-8 text; run `repos-manifest sync`" in err
    assert "internal error" not in err


def test_two_layers_whose_repos_differ_are_named_together(stub, tmp_path, capsys):
    system, path, data = three_layers(tmp_path)
    assert run(system, "build") == 0
    data["repositories"]["n"] = repo(make_remote(tmp_path / "remotes", "n"), None, "mid")
    data["repositories"]["o"] = repo(make_remote(tmp_path / "remotes", "o"), None, "top")
    write_manifest(path, data)
    assert run(system, "sync") == 0
    capsys.readouterr()
    assert run(system, "build", "--", "--packages-select", "m") == 1
    err = capsys.readouterr().err
    assert (
        "built, but their repos differ from their records: mid (new n), top (new o); nothing was"
        " run. Build them without package selection first, which also records the changed repos:"
        " `repos-manifest build mid top`" in err
    )


def test_a_selection_run_says_rebuilt_with_selection_when_stopped(system, stub):
    assert run(system, "build") == 0
    (system / "mid/src/m/STUB_WAIT").touch()
    tool = start_tool(system, "--", "--packages-select", "m")
    wait_until(logged(stub, "waiting"), tool)
    os.kill(tool.pid, signal.SIGTERM)
    out, err = tool.communicate(timeout=30)
    assert f"stopped by SIGTERM; layers rebuilt with selection in this run: {BASE};" in err


def test_a_selection_run_says_rebuilt_with_selection_when_the_record_cannot_be_read(
    system, stub, monkeypatch, capsys
):
    assert run(system, "build") == 0
    real_build_layers = build.build_layers

    def build_layers(progress, *args):
        real_build_layers(progress, *args)
        (system / ".repos-manifest/built-jazzy.yaml").write_text("format: 1\nlayers: 3\n")

    monkeypatch.setattr(build, "build_layers", build_layers)
    capsys.readouterr()
    assert run(system, "build", "--", "--packages-select", "m") == 1
    assert f"  rebuilt with selection in this run: {BASE}, mid, top\n" in capsys.readouterr().out


# --- Round 7: --cmake-target, a failed removal, the defaults note, what is left behind -------


@pytest.mark.parametrize("given", [["--cmake-target", "all"], ["--cmake-target=all"]])
def test_a_cmake_target_is_refused_on_a_layer_not_built(system, stub, capsys, given):
    """`--cmake-target` builds one target and skips the install step, while colcon still exits
    0 and writes install/setup.bash: like package selection, it only rebuilds built layers."""
    capsys.readouterr()
    assert run(system, "build", "--", *given) == 1
    err = capsys.readouterr().err
    assert (
        "a run with `--cmake-target` builds only part of a layer, so it only rebuilds layers that"
        f" are built, with the repos their record has; not built: {BASE} (not built)" in err
    )
    assert (
        f"Build them without `--cmake-target` first: `repos-manifest build {BASE} mid top`" in err
    )
    assert runs(stub) == []
    assert not (system / ".repos-manifest/built-jazzy.yaml").exists()


def test_a_cmake_target_on_built_layers_keeps_their_records(system, stub, capsys):
    assert run(system, "build") == 0
    before = built(system)
    capsys.readouterr()
    assert run(system, "build", "mid", "--", "--cmake-target", "all") == 0
    assert built(system) == before
    assert "  rebuilt with selection: mid\n" in capsys.readouterr().out
    assert run(system, "build", "--", "--packages-select", "m", "--cmake-target", "all") == 0
    assert built(system) == before


def test_cmake_target_skip_unavailable_alone_is_not_selection(system, stub):
    assert run(system, "build", "--", "--cmake-target-skip-unavailable") == 0
    assert list(built(system)) == [BASE, "mid", "top"]


def test_a_failed_removal_of_install_setup_keeps_the_record_and_stops_the_run(system, stub, capsys):
    if os.geteuid() == 0:
        pytest.skip("root removes a file from a read-only directory")
    assert run(system, "build") == 0
    before = built(system)
    os.chmod(system / "mid/install", 0o555)
    try:
        capsys.readouterr()
        assert run(system, "build", "mid", "top") == 1
    finally:
        os.chmod(system / "mid/install", 0o755)
    out = capsys.readouterr().out
    assert len(runs(stub)) == 3  # colcon was not started on mid
    assert (
        f"  stopped before mid: {system / 'mid/install/setup.bash'} cannot be removed before colcon"
        " writes it again (Permission denied), so colcon was not started on it; it keeps its"
        " record\n" in out
    )
    assert "  not tried: top\n" in out
    assert f"  built before, in the run: {BASE}, mid, top\n" in out
    assert built(system) == before
    assert sourced_by_setup(system) == real(system / "top")


def test_a_defaults_file_that_is_not_there_is_not_named(
    system, stub, tmp_path, monkeypatch, capsys
):
    monkeypatch.setenv("COLCON_DEFAULTS_FILE", str(tmp_path / "missing.yaml"))
    home = tmp_path / "colcon-home"
    home.mkdir()
    (home / "defaults.yaml").write_text("{}\n")  # not read: COLCON_DEFAULTS_FILE is set
    capsys.readouterr()
    assert run(system, "build", BASE) == 0
    assert "NOTE: colcon reads default arguments" not in capsys.readouterr().out
    # A relative path is read by colcon in the layer's directory, where it runs.
    monkeypatch.setenv("COLCON_DEFAULTS_FILE", "mine.yaml")
    (system / "mid/mine.yaml").write_text("{}\n")
    assert run(system, "build", BASE, "mid") == 0
    out = capsys.readouterr().out
    assert f"NOTE: colcon reads default arguments from {system / 'mid/mine.yaml'};" in out
    assert out.count("NOTE: colcon reads default arguments") == 1


def test_a_layer_built_on_a_shorter_chain_notes_what_is_left_below(stub, tmp_path, capsys):
    system, path, data = three_layers(tmp_path)
    assert run(system, "build") == 0
    data["layers"] = ["top"]
    del data["repositories"]["m"]
    write_manifest(path, data)
    assert run(system, "sync") == 0
    capsys.readouterr()
    assert run(system, "build") == 0
    out = capsys.readouterr().out
    assert (
        "  built on a shorter chain than before: top (it may have used what is left in"
        f" {system / 'mid/install'}/ through paths its build directory kept from an earlier"
        " build)\n" in out
    )
    assert built(system)["top"]["below"] == [BASE]


def test_a_stop_before_colcon_writes_install_setup_says_it_was_removed(system, stub):
    assert run(system, "build") == 0
    (system / "mid/src/m/STUB_WAIT_EARLY").touch()
    tool = start_tool(system, "mid")
    wait_until(logged(stub, "waiting"), tool)
    os.kill(tool.pid, signal.SIGTERM)
    out, err = tool.communicate(timeout=30)
    assert (
        f"mid was stopped and is not built; its earlier {system / 'mid/install/setup.bash'} was"
        " removed when this run started on it and is not there now; setup.bash sources" in err
    )


def test_a_setup_bash_the_tool_cannot_read_stops_the_run_before_colcon(system, stub, capsys):
    if os.geteuid() == 0:
        pytest.skip("root reads a file without read permission")
    assert run(system, "build") == 0
    before = built(system)
    os.chmod(system / "setup.bash", 0)
    try:
        capsys.readouterr()
        assert run(system, "build") == 1
    finally:
        os.chmod(system / "setup.bash", 0o644)
    out = capsys.readouterr().out
    assert len(runs(stub)) == 3  # colcon was not started
    assert f"  stopped before {BASE}: setup.bash could not be brought into line" in out
    assert "cannot be read (Permission denied), so whether this tool wrote it" in out
    assert built(system) == before


@pytest.mark.colcon
def test_real_colcon_a_cmake_target_installs_nothing_so_it_is_selection(real_colcon, tmp_path):
    system = packages_system(tmp_path, {"good2": {"needs": "good"}})
    assert run(system, "build", "--", "--cmake-target", "all") == 1
    assert not (system / ".repos-manifest/built-_unnamed.yaml").exists()
    assert run(system, "build") == 0
    before = built(system, "_unnamed")
    assert run(system, "build", "--", "--cmake-target", "all") == 0
    assert built(system, "_unnamed") == before
    assert sourced_by_setup(system) == real(system / "top")


# --- Round 8: the defaults file as colcon finds it, an ambiguous --cmake ------------------


@pytest.mark.parametrize(
    "case, named",
    [
        ("unset", "home"),
        ("existing", "given"),
        ("missing", None),
        ("empty", None),
        ("directory", None),
        ("relative", "layer"),
    ],
)
def test_the_defaults_note_names_what_colcon_reads(
    system, stub, tmp_path, monkeypatch, case, named
):
    """Checked with colcon-defaults 0.2.9 and `colcon list`: with COLCON_DEFAULTS_FILE unset colcon
    reads $COLCON_HOME/defaults.yaml; set, it reads that path only when it is a file (an empty
    value, a missing path and a directory are none, and no other global file is read); a
    relative path is read in the directory colcon runs in."""
    home = tmp_path / "colcon-home"
    home.mkdir()
    (home / "defaults.yaml").write_text("{}\n")
    given = tmp_path / "given.yaml"
    given.write_text("{}\n")
    (tmp_path / "a-directory").mkdir()
    (system / "mid/rel.yaml").write_text("{}\n")
    value = {
        "existing": str(given),
        "missing": str(tmp_path / "missing.yaml"),
        "empty": "",
        "directory": str(tmp_path / "a-directory"),
        "relative": "rel.yaml",
    }.get(case)
    if value is not None:
        monkeypatch.setenv("COLCON_DEFAULTS_FILE", value)
    mid = next(
        layer
        for layer in build.read_layers(system, build.read_config(system), "jazzy")
        if layer.name == "mid"
    )
    found = build.colcon_defaults_files() + build.colcon_defaults_files(mid)
    expected = {
        "home": [str(home / "defaults.yaml")],
        "given": [str(given)],
        "layer": [str(system / "mid/rel.yaml")],
        None: [],
    }[named]
    assert found == expected


def test_a_missing_defaults_file_still_leaves_the_layers_own_named(
    system, stub, tmp_path, monkeypatch, capsys
):
    monkeypatch.setenv("COLCON_DEFAULTS_FILE", str(tmp_path / "missing.yaml"))
    (system / "mid/colcon_defaults.yaml").write_text("{}\n")
    capsys.readouterr()
    assert run(system, "build") == 0
    out = capsys.readouterr().out
    assert (
        f"NOTE: colcon reads default arguments from {system / 'mid/colcon_defaults.yaml'};" in out
    )
    assert out.count("NOTE: colcon reads default arguments") == 1


@pytest.mark.parametrize("given", ["--cmake", "--cmake-t", "--cmake-targ"])
def test_an_ambiguous_abbreviation_of_cmake_target_is_refused_as_ambiguous(
    system, stub, capsys, given
):
    assert run(system, "build", "--", given, "all") == 1
    err = capsys.readouterr().err
    assert f"{given} (colcon would reject it as ambiguous, and it could be" in err
    assert "--cmake-target, --cmake-target-skip-unavailable) is not passed to colcon" in err
    assert "a run with `--cmake-target`" not in err
    assert runs(stub) == []


@pytest.mark.parametrize("given", ["colcon_defaults.yaml", "./colcon_defaults.yaml"])
def test_a_relative_defaults_file_that_is_the_layers_own_is_named_once(
    system, stub, monkeypatch, capsys, given
):
    monkeypatch.setenv("COLCON_DEFAULTS_FILE", given)
    (system / "mid/colcon_defaults.yaml").write_text("{}\n")
    capsys.readouterr()
    assert run(system, "build") == 0
    assert capsys.readouterr().out.count("NOTE: colcon reads default arguments") == 1


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


@pytest.mark.colcon
def test_real_colcon_a_layer_filled_below_takes_the_layers_above_out_of_the_run(
    real_colcon, tmp_path
):
    """The reviewer's case: x optional and absent, b and c built; x's repo put back and
    `build x b`: c was built without x in its environment, so setup.bash sources b, which
    brings x in, and a plain build rebuilds c."""
    remotes = tmp_path / "remotes"
    data = {
        "format": 1,
        "layers": ["x", "b", "c"],
        "repositories": {
            "u": repo(make_package_remote(remotes, "u")),
            "xp": repo(remotes / "xp", None, "x", optional=True),
            "bp": repo(make_package_remote(remotes, "bp", needs="u"), None, "b"),
            "cp": repo(make_package_remote(remotes, "cp", needs="bp"), None, "c"),
        },
    }
    write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    assert run(system, "build") == 0
    make_package_remote(remotes, "xp", needs="u")
    assert run(system, "sync") == 0
    assert run(system, "build", "x", "b") == 0
    assert sourced_by_setup(system) == real(system / "b")

    def prefixes():
        done = subprocess.run(
            ["bash", "-c", "source setup.bash && echo $CMAKE_PREFIX_PATH"],
            cwd=system,
            capture_output=True,
            text=True,
            check=True,
        )
        return done.stdout.strip().split(":")

    assert str(real(system / "x/install/xp")) in prefixes()
    assert run(system, "build") == 0
    assert sourced_by_setup(system) == real(system / "c")
    assert str(real(system / "x/install/xp")) in prefixes()
    assert built(system, BASE)["c"]["below"] == [BASE, "x", "b"]


@pytest.mark.colcon
def test_real_colcon_a_skip_list_on_a_first_build(real_colcon, tmp_path, capsys):
    """The issue's case: a layer with a package that cannot build, built leaving it out on a
    system built for the first time, and a layer above built on it."""
    remotes = tmp_path / "remotes"
    data = {
        "format": 1,
        "layers": ["mid", "top"],
        "repositories": {
            "good": repo(make_package_remote(remotes, "good")),
            "bad": repo(make_package_remote(remotes, "bad", bad=True), None, "mid"),
            "mid2": repo(make_package_remote(remotes, "mid2", needs="good"), None, "mid"),
            "top2": repo(make_package_remote(remotes, "top2", needs="mid2"), None, "top"),
        },
    }
    write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    assert run(system, "build", "--", "--packages-select", "mid2") == 1  # still refused
    capsys.readouterr()
    assert run(system, "build", "--", "--packages-skip", "bad") == 0
    assert list(built(system, "_unnamed")) == [BASE, "mid", "top"]
    assert built(system, "_unnamed")["mid"]["without"] == {"--packages-skip": ["bad"]}
    assert not (system / "mid/install/bad").exists()
    assert (system / "mid/install/mid2").is_dir() and (system / "top/install/top2").is_dir()
    assert sourced_by_setup(system) == real(system / "top")
    out = capsys.readouterr().out
    assert f"  built with --packages-skip bad given to colcon: {BASE}, mid, top\n" in out
    assert run(system, "build", "mid", "--", "--packages-skip-regex", "^ba") == 0
    out = capsys.readouterr().out
    assert (
        "  skip and ignore options given to colcon changed: mid (was --packages-skip bad, now"
        " --packages-skip-regex '^ba')" in out
    )
    assert sourced_by_setup(system) == real(system / "top")


@pytest.mark.colcon
def test_real_colcon_the_last_occurrence_of_a_skip_option_counts(real_colcon, tmp_path):
    system = packages_system(tmp_path, {"bad": {"bad": True}, "other": {}})
    assert run(system, "build", "--", "--packages-skip", "other", "--packages-skip", "bad") == 0
    assert built(system, "_unnamed")["top"]["without"] == {"--packages-skip": ["bad"]}
    assert (system / "top/install/other").is_dir()
    assert not (system / "top/install/bad").exists()
