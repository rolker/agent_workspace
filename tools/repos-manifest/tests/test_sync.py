"""`sync` in part 1: it clones what is missing, touches nothing that is there, and a manifest
that does not resolve changes nothing."""

import os
import shutil
import signal

import pytest
import yaml

from helpers import branch, git, head, make_remote, repo, run, snapshot, write_manifest
from repos_manifest import sync
from repos_manifest.cli import main
from repos_manifest.signals import Stopped


@pytest.fixture
def two_distros(vcs, tmp_path):
    """A system with a directory per distro, jazzy and rolling, each with repos a and b."""
    remotes = tmp_path / "remotes"
    data = {
        "format": 1,
        "distros": ["jazzy", "rolling"],
        "layers": ["core"],
        "repositories": {
            "a": repo(make_remote(remotes, "a", branches=["jazzy", "rolling"]), "jazzy", "core"),
            "b": repo(make_remote(remotes, "b"), None, "core"),
        },
    }
    data["repositories"]["a"]["distros"] = {"rolling": {"version": "rolling"}}
    path = write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    rc = run(
        system,
        "init",
        "../m.manifest.yaml",
        "--distro-dirs",
        "--distro",
        "jazzy",
        "--distro",
        "rolling",
        "--yes",
    )
    assert rc == 0
    return system, path, data


def _state(system):
    return yaml.safe_load((system / ".repos-manifest/state.yaml").read_text())["distros"]


def test_sync_after_init_changes_nothing(two_distros, capsys):
    system, _, _ = two_distros
    before = snapshot(system)
    capsys.readouterr()
    assert run(system, "sync") == 0
    assert snapshot(system) == before
    out = capsys.readouterr().out
    assert "cloning" not in out
    assert (
        out.count("present, not touched (2); updating a repo that is there is not built yet") == 2
    )


def test_a_repo_added_to_the_manifest_is_cloned_and_recorded(two_distros, tmp_path):
    system, path, data = two_distros
    before = _state(system)
    data["repositories"]["c"] = repo(make_remote(tmp_path / "remotes", "c"), None, "core")
    write_manifest(path, data)
    assert run(system, "sync") == 0
    after = _state(system)
    for distro in ("jazzy", "rolling"):
        assert (system / distro / "core/src/c/README").is_file()
        assert after[distro]["repos"]["c"]["commit"] == head(system / distro / "core/src/c")
        for key in ("a", "b"):
            assert after[distro]["repos"][key] == before[distro]["repos"][key]


@pytest.mark.parametrize("where", ["rolling", "rolling/core/src", "jazzy"])
def test_sync_from_inside_a_distro_directory_syncs_that_distro(two_distros, tmp_path, where):
    system, path, data = two_distros
    data["repositories"]["c"] = repo(make_remote(tmp_path / "remotes", "c"), None, "core")
    write_manifest(path, data)
    assert run(system / where, "sync") == 0
    distro = where.split("/")[0]
    other = "jazzy" if distro == "rolling" else "rolling"
    assert (system / distro / "core/src/c").is_dir()
    assert not (system / other / "core/src/c").exists()


def test_sync_from_a_subdirectory_at_the_top_syncs_every_distro(two_distros, tmp_path):
    system, path, data = two_distros
    data["repositories"]["c"] = repo(make_remote(tmp_path / "remotes", "c"), None, "core")
    write_manifest(path, data)
    (system / "notes").mkdir()
    assert run(system / "notes", "sync") == 0
    assert (system / "jazzy/core/src/c").is_dir() and (system / "rolling/core/src/c").is_dir()


def test_distro_names_one_and_leaves_the_other_as_it_was(two_distros, tmp_path):
    system, path, data = two_distros
    data["repositories"]["c"] = repo(make_remote(tmp_path / "remotes", "c"), None, "core")
    write_manifest(path, data)
    jazzy = snapshot(system / "jazzy")
    jazzy_resolved = snapshot(system / ".repos-manifest/resolved/jazzy")
    jazzy_state = _state(system)["jazzy"]
    assert run(system / "jazzy", "sync", "--distro", "rolling") == 0
    assert (system / "rolling/core/src/c").is_dir()
    assert snapshot(system / "jazzy") == jazzy
    assert snapshot(system / ".repos-manifest/resolved/jazzy") == jazzy_resolved
    assert _state(system)["jazzy"] == jazzy_state


def test_a_distro_the_system_does_not_record_is_an_error(two_distros, capsys):
    system, _, _ = two_distros
    before = snapshot(system)
    assert run(system, "sync", "--distro", "humble") == 1
    assert snapshot(system) == before
    assert "--distro humble: this system does not record it (it records: jazzy, rolling)" in (
        capsys.readouterr().err
    )


def test_a_distro_on_a_flat_system_without_distros_is_an_error(vcs, tmp_path, capsys):
    write_manifest(
        tmp_path / "m.yaml",
        {"format": 1, "repositories": {"a": repo(make_remote(tmp_path / "r", "a"))}},
    )
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.yaml", "--yes") == 0
    assert run(system, "sync", "--distro", "jazzy") == 1
    assert "(it records: none)" in capsys.readouterr().err


def test_a_manifest_whose_resolved_files_cannot_be_written_out_changes_nothing(
    two_distros, tmp_path, capsys
):
    # The recorded path now goes through a folder with a no-break space, which the head comment
    # of every resolved file refuses: sync finds that before it changes anything, though a
    # repo and a setup.bash are missing that it would otherwise make.
    system, path, _ = two_distros
    folder = tmp_path / "a\u00a0b"
    folder.mkdir()
    path.rename(folder / path.name)
    config_path = system / ".repos-manifest/config.yaml"
    config = yaml.safe_load(config_path.read_text())
    config["manifest"] = f"../a\u00a0b/{path.name}"
    config_path.write_text(yaml.safe_dump(config, sort_keys=False))
    shutil.rmtree(system / "jazzy/core/src/a")
    (system / "rolling/setup.bash").unlink()
    before = snapshot(system)
    capsys.readouterr()
    assert run(system, "sync") == 1
    assert snapshot(system) == before
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err == (
        "ERROR: the manifest's output is what failed; nothing was changed: refusing to write the"
        " head comment: the manifest's location or a name holds a control or invisible"
        " character\n"
    )


@pytest.mark.parametrize("change", ["a role it lacks", "not YAML"])
def test_a_manifest_that_does_not_resolve_changes_nothing(two_distros, capsys, change):
    system, path, data = two_distros
    if change == "a role it lacks":
        config = system / ".repos-manifest/config.yaml"
        config.write_text(config.read_text() + "role: robot\n")
    else:
        path.write_text("repositories: [\n")
    before = snapshot(system)
    assert run(system, "sync") == 1
    assert snapshot(system) == before
    err = capsys.readouterr().err
    assert err.startswith("ERROR: the manifest is what failed; nothing was changed: "), err
    # The path it names is the recorded one, taken from the system directory.
    assert err.endswith(
        f" (the manifest's path is `manifest` in {system / '.repos-manifest/config.yaml'}, taken"
        f" from the system directory {system})\n"
    ), err


def test_a_repo_with_local_work_is_not_touched(two_distros):
    system, _, _ = two_distros
    place = system / "jazzy/core/src/a"
    git("checkout", "-q", "-b", "mine", cwd=place)
    (place / "README").write_text("changed\n")
    git("commit", "-q", "-am", "local commit", cwd=place)
    (place / "README").write_text("dirty\n")
    before = snapshot(place)
    status = git("status", "--porcelain=v2", "--branch", cwd=place)
    assert run(system, "sync") == 0
    assert snapshot(place) == before
    assert git("status", "--porcelain=v2", "--branch", cwd=place) == status
    assert branch(place) == "mine"


def test_no_system_here_says_init(vcs, tmp_path, capsys):
    assert run(tmp_path, "sync") == 1
    assert "set one up with `repos-manifest init`" in capsys.readouterr().err


def test_a_sync_stopped_in_the_second_distro_keeps_what_it_finished(
    two_distros, tmp_path, monkeypatch, capsys
):
    system, path, data = two_distros
    for key in ("c", "d"):
        data["repositories"][key] = repo(make_remote(tmp_path / "remotes", key), None, "core")
    write_manifest(path, data)
    real = sync.clone_repo
    calls = []

    def stop_at_the_second_new_repo_of_rolling(system_, src, repo_, text, env, record):
        if src[0] == "rolling" and repo_.key == "d":
            raise Stopped(signal.SIGINT)
        result = real(system_, src, repo_, text, env, record)
        calls.append((src[0], repo_.key, result.outcome))
        return result

    monkeypatch.setattr(sync, "clone_repo", stop_at_the_second_new_repo_of_rolling)
    assert run(system, "sync") == 128 + signal.SIGINT
    assert "stopped by SIGINT; run `repos-manifest sync` to finish" in capsys.readouterr().err
    state = _state(system)
    assert set(state["jazzy"]["repos"]) == {"a", "b", "c", "d"}
    assert set(state["rolling"]["repos"]) == {"a", "b", "c"}
    assert not (system / "rolling/core/src/d").exists()
    monkeypatch.setattr(sync, "clone_repo", real)
    assert run(system, "sync") == 0
    assert set(_state(system)["rolling"]["repos"]) == {"a", "b", "c", "d"}
    assert (system / "rolling/core/src/d/README").is_file()


@pytest.mark.parametrize("what", ["a link", "a file"])
def test_a_resolved_directory_that_cannot_be_written_is_named_without_resolves_options(
    two_distros, tmp_path, capsys, what
):
    system, _, _ = two_distros
    resolved = system / ".repos-manifest/resolved/rolling"
    shutil.rmtree(resolved)
    if what == "a link":
        (tmp_path / "elsewhere").mkdir()
        resolved.symlink_to(tmp_path / "elsewhere")
    else:
        resolved.write_text("a person's file\n")
    assert run(system, "sync", "--distro", "rolling") == 1
    err = capsys.readouterr().err
    assert f"the resolved files' directory {resolved}: " in err, err
    assert "--out" not in err and "resolve" not in err.replace("resolved", ""), err


@pytest.mark.parametrize(
    "file,text",
    [
        ("config.yaml", "manifest: ../m.manifest.yaml\nlayout: distro-dirs\n"),
        ("config.yaml", "manifest: ../m.manifest.yaml\nlayout: distro-dirs\ndistros: {}\n"),
        ("config.yaml", "manifest: ../m.manifest.yaml\nlayout: flat\ndistros: {}\n"),
        ("config.yaml", "manifest: ../m.manifest.yaml\ngroups: abc\nlayout: distro-dirs\n"),
        ("state.yaml", "format: 1\ndistros: {rolling: 5}\n"),
        ("state.yaml", "format: 1\ndistros: {rolling: {repos: {a: x}}}\n"),
    ],
)
def test_a_config_or_state_of_the_wrong_shape_is_an_error_that_names_it(
    two_distros, capsys, file, text
):
    system, _, _ = two_distros
    (system / ".repos-manifest" / file).write_text(text)
    before = snapshot(system)
    capsys.readouterr()
    assert run(system, "sync") == 1
    assert snapshot(system) == before
    err = capsys.readouterr().err
    assert f"ERROR: {system}/.repos-manifest/{file}: " in err, err
    assert "internal error" not in err


def test_a_setup_bash_that_cannot_be_created_is_reported_and_the_other_distros_go_on(
    two_distros, capsys
):
    # A file where the jazzy directory belongs: its repos and its setup.bash cannot be put in
    # place; rolling, after it, is synced as usual.
    system, _, _ = two_distros
    shutil.rmtree(system / "jazzy")
    (system / "jazzy").write_text("a person's file\n")
    (system / "rolling" / "setup.bash").unlink()
    capsys.readouterr()
    assert run(system, "sync") == 1
    out = capsys.readouterr().out
    jazzy, rolling = out.split("distro rolling:")
    assert f"ERROR: {system / 'jazzy' / 'setup.bash'}: cannot be created: " in jazzy
    assert jazzy.index("distro jazzy:") < jazzy.index("setup.bash: cannot be created")
    # sync wrote it, so its first line names the tool, not `init`.
    first = (system / "rolling" / "setup.bash").read_text().splitlines()[0]
    assert first == "# Written by repos-manifest. Nothing is built here yet."
    assert (system / "jazzy").read_text() == "a person's file\n"


@pytest.mark.skipif(os.geteuid() == 0, reason="root can write anywhere")
def test_a_setup_bash_in_a_read_only_directory_is_reported_with_its_reason(two_distros, capsys):
    system, _, _ = two_distros
    (system / "jazzy" / "setup.bash").unlink()
    (system / "jazzy").chmod(0o500)
    try:
        capsys.readouterr()
        assert run(system, "sync") == 1
    finally:
        (system / "jazzy").chmod(0o700)
    out = capsys.readouterr().out
    setup = system / "jazzy" / "setup.bash"
    assert f"ERROR: {setup}: cannot be created: Permission denied\n" in out
    assert not os.path.lexists(setup)
    assert "distro rolling:" in out


@pytest.mark.skipif(not hasattr(signal, "SIGXFSZ"), reason="needs RLIMIT_FSIZE")
def test_a_setup_bash_that_cannot_be_written_whole_is_not_left_behind(tmp_path):
    # A file-size limit below the stub's size makes the write fail part way, as a full disk
    # does; what the call created is removed, and the failure is reported.
    resource = pytest.importorskip("resource")
    path = tmp_path / "setup.bash"
    soft, hard = resource.getrlimit(resource.RLIMIT_FSIZE)
    previous = signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
    resource.setrlimit(resource.RLIMIT_FSIZE, (16, hard))
    try:
        failure = sync.create_setup(tmp_path, ("setup.bash",))
    finally:
        resource.setrlimit(resource.RLIMIT_FSIZE, (soft, hard))
        signal.signal(signal.SIGXFSZ, previous)
    assert failure is not None and failure.startswith(f"{path}: cannot be created: ")
    assert not os.path.lexists(path)
    # One that is there is never touched, even when it is not a whole stub.
    path.write_text("# Written")
    assert sync.create_setup(tmp_path, ("setup.bash",)) is None
    assert path.read_text() == "# Written"


def test_a_manifest_not_found_after_the_system_moved_says_where_its_path_comes_from(
    two_distros, tmp_path, capsys
):
    system, _, _ = two_distros
    moved = tmp_path / "elsewhere" / "sys"
    moved.parent.mkdir()
    system.rename(moved)
    capsys.readouterr()
    assert run(moved, "sync") == 1
    err = capsys.readouterr().err
    assert "the manifest is what failed; nothing was changed: ../m.manifest.yaml" in err
    assert (
        f"(the manifest's path is `manifest` in {moved / '.repos-manifest/config.yaml'}, taken"
        f" from the system directory {moved})\n"
    ) in err


def test_sync_from_inside_the_resolved_files_says_where_to_run_it(two_distros, capsys):
    system, _, _ = two_distros
    inside = system / ".repos-manifest" / "resolved" / "jazzy"
    capsys.readouterr()
    assert run(inside, "sync", "--distro", "jazzy") == 1
    err = capsys.readouterr().err
    assert err.endswith(
        "which replacing it would delete from under this shell; run `sync` from the system"
        " directory or from below it, outside .repos-manifest/\n"
    ), err


@pytest.mark.parametrize("argv", [["sync"], ["init", "/m.manifest.yaml", "--yes"]])
def test_a_current_directory_that_no_longer_exists_is_a_plain_error(tmp_path, capsys, argv):
    gone = tmp_path / "gone"
    gone.mkdir()
    previous = os.getcwd()
    os.chdir(gone)
    try:
        gone.rmdir()
        assert main(argv) == 1
    finally:
        os.chdir(previous)
    assert capsys.readouterr().err == (
        "ERROR: the current directory no longer exists; change to one that does and run it"
        " again\n"
    )


def test_a_flat_system_whose_manifest_gains_distros_says_to_set_one_up_anew(vcs, tmp_path, capsys):
    remotes = tmp_path / "remotes"
    data = {"format": 1, "repositories": {"a": repo(make_remote(remotes, "a"))}}
    path = write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    write_manifest(path, {"format": 1, "distros": ["jazzy", "rolling"], **data})
    before = snapshot(system)
    capsys.readouterr()
    assert run(system, "sync") == 1
    assert snapshot(system) == before
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err == (
        "ERROR: ../m.manifest.yaml: the manifest now has distros (jazzy, rolling), and this"
        " system directory was set up without one; nothing in it has been moved or changed."
        " A system with distros is set up in a new directory with `repos-manifest init`, with"
        " `--distro-dirs` to hold more than one distro. (the manifest's path is `manifest` in"
        f" {system / '.repos-manifest/config.yaml'}, taken from the system directory {system})\n"
    )
    # No option it names is refused: sync takes no --distro-dirs, and --distro is not named.
    assert "--distro " not in captured.err and "sync --" not in captured.err


@pytest.mark.parametrize("what", ["a directory", "a dangling link", "a link to a file", "a file"])
def test_what_is_at_setup_bash_is_left_and_named_unless_it_is_a_file(
    two_distros, tmp_path, capsys, what
):
    system, _, _ = two_distros
    setup = system / "jazzy" / "setup.bash"
    setup.unlink()
    if what == "a directory":
        setup.mkdir()
    elif what == "a dangling link":
        setup.symlink_to(tmp_path / "nowhere")
    elif what == "a link to a file":
        (tmp_path / "mine.bash").write_text("# mine\n")
        setup.symlink_to(tmp_path / "mine.bash")
    else:
        setup.write_text("# mine\n")
    before = snapshot(system)
    capsys.readouterr()
    assert run(system, "sync") == 0
    assert snapshot(system) == before
    out = capsys.readouterr().out
    note = f"WARNING: {setup}: is there and is not a file; left as it is\n"
    if what in ("a directory", "a dangling link"):
        jazzy = out[out.index("distro jazzy:") : out.index("distro rolling:")]
        assert jazzy.endswith(note)
    else:
        assert "WARNING" not in out


def test_init_names_a_directory_made_at_setup_bash_while_it_runs(
    vcs, tmp_path, monkeypatch, capsys
):
    # init refuses a setup.bash that is there before it starts; one made while it runs is
    # left as it is, and a directory is named.
    remotes = tmp_path / "remotes"
    data = {"format": 1, "repositories": {"a": repo(make_remote(remotes, "a"))}}
    write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    check = sync.place_problem

    def a_directory_is_made_meanwhile(system_, parts):
        if parts[-1] == "setup.bash":
            (system_ / "setup.bash").mkdir()
        return check(system_, parts)

    monkeypatch.setattr(sync, "place_problem", a_directory_is_made_meanwhile)
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    out = capsys.readouterr().out
    assert f"WARNING: {system / 'setup.bash'}: is there and is not a file; left as it is\n" in out
    assert (system / "setup.bash").is_dir()
