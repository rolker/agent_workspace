"""Each of `init`'s refusals: exit status 1, the next step in the message, no command or option
that is not built named, and the directory exactly as it was ("A refusal changes nothing")."""

import io
import os
import re
import resource
import signal
import stat
import subprocess
import sys

import pytest

import repos_manifest
from helpers import make_remote, repo, run, snapshot, write_manifest

NOT_BUILT = [
    "add-distro",
    "build",
    "status",
    "show",
    "freeze",
    "--manifest-ref",
    "--local-manifest",
]


@pytest.fixture
def tmp(vcs, tmp_path):
    return tmp_path


def manifest(tmp_path, distros=("jazzy", "rolling"), layers=("core",)):
    remote = tmp_path / "remotes" / "a"
    if not remote.exists():
        make_remote(tmp_path / "remotes", "a", branches=["jazzy", "rolling"])
    data = {"format": 1}
    if distros:
        data["distros"] = list(distros)
    if layers:
        data["layers"] = list(layers)
    data["repositories"] = {
        "a": repo(remote, "jazzy", layers[0] if layers else None),
    }
    return write_manifest(tmp_path / "m.manifest.yaml", data)


def refused(where, capsys, *argv, expect):
    """`init` in `where` is refused with `expect` in its message, and changes nothing."""
    (where / "unrelated.txt").write_text("a person's file\n")
    before = snapshot(where.parent)
    assert run(where, "init", *argv) == 1
    assert snapshot(where.parent) == before
    err = capsys.readouterr().err
    assert expect in err, err
    for name in NOT_BUILT:
        assert re.search(rf"(?<![\w-]){re.escape(name)}(?![\w-])", err) is None, (name, err)
    return err


def _system(tmp_path, name="sys"):
    path = tmp_path / name
    path.mkdir()
    return path


def test_1_a_system_set_up_here(tmp, capsys):
    manifest(tmp)
    system = _system(tmp)
    assert run(system, "init", "../m.manifest.yaml", "--distro", "jazzy", "--yes") == 0
    capsys.readouterr()
    refused(
        system,
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        "--yes",
        expect="Run `repos-manifest sync` there",
    )


@pytest.mark.parametrize("dirs", [False, True])
def test_1_a_system_set_up_above(tmp, capsys, dirs):
    manifest(tmp)
    system = _system(tmp)
    flags = ["--distro-dirs"] if dirs else []
    assert run(system, "init", "../m.manifest.yaml", "--distro", "jazzy", *flags, "--yes") == 0
    capsys.readouterr()
    below = system / ("jazzy/core/src" if dirs else "core/src")
    refused(
        below,
        capsys,
        os.path.relpath(tmp / "m.manifest.yaml", below),
        "--distro",
        "jazzy",
        "--yes",
        expect=f"a system is already set up in {system}",
    )


def test_1b_a_system_dir_with_no_readable_config_is_that_error(tmp, capsys):
    manifest(tmp)
    system = _system(tmp)
    (system / ".repos-manifest").mkdir()
    refused(
        system,
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        "--yes",
        expect=(
            f"config.yaml: not found; repair the file, or, to set up again, move {system} aside"
            " and run `repos-manifest init` in an empty directory"
        ),
    )


def test_2_two_distros_without_distro_dirs(tmp, capsys):
    manifest(tmp)
    refused(
        _system(tmp),
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        "--distro",
        "rolling",
        "--yes",
        expect="Add --distro-dirs",
    )


@pytest.mark.parametrize(
    "listed",
    [("rolling", "Rolling"), ("jazzy", "rolling"), ()],
    ids=["the-manifest-lists-both", "it-lists-one", "it-has-no-distros"],
)
def test_2b_two_distros_that_differ_only_in_case(tmp, capsys, listed):
    # Checked before the manifest is read, so it wins over the rows about the manifest's list.
    manifest(tmp, distros=listed)
    refused(
        _system(tmp),
        capsys,
        "../m.manifest.yaml",
        "--distro-dirs",
        "--distro",
        "rolling",
        "--distro",
        "Rolling",
        "--yes",
        expect="--distro 'rolling' and 'Rolling' differ only in case, and each distro is a"
        " directory. Name one of them",
    )


def test_3_distro_dirs_with_a_manifest_without_distros(tmp, capsys):
    manifest(tmp, distros=())
    refused(
        _system(tmp),
        capsys,
        "../m.manifest.yaml",
        "--distro-dirs",
        "--yes",
        expect="Set up without --distro-dirs and without --distro",
    )


def test_4_no_distro_with_a_manifest_with_distros(tmp, capsys):
    manifest(tmp)
    refused(_system(tmp), capsys, "../m.manifest.yaml", "--yes", expect="Name one with --distro")


def test_5_a_distro_with_a_manifest_without_distros(tmp, capsys):
    manifest(tmp, distros=())
    refused(
        _system(tmp),
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        "--yes",
        expect="Set up without --distro",
    )


def test_6_a_distro_not_listed_flat(tmp, capsys):
    manifest(tmp)
    err = refused(
        _system(tmp),
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "humble",
        "--yes",
        expect="Name a distro it lists, or add the distro to its `distros:`",
    )
    assert "does not cover distro 'humble'" in err


def test_7_a_distro_not_listed_with_distro_dirs(tmp, capsys):
    manifest(tmp)
    refused(
        _system(tmp),
        capsys,
        "../m.manifest.yaml",
        "--distro-dirs",
        "--distro",
        "jazzy",
        "--distro",
        "humble",
        "--yes",
        expect="Set up with the distros it lists, or add the distro to its `distros:`",
    )


@pytest.mark.parametrize(
    "existing,flags",
    [
        ("core", []),
        ("setup.bash", []),
        ("jazzy", ["--distro-dirs"]),
    ],
)
def test_8_a_path_init_would_create_exists(tmp, capsys, existing, flags):
    manifest(tmp)
    system = _system(tmp)
    if existing.endswith(".bash"):
        (system / existing).write_text("mine\n")
    else:
        (system / existing).mkdir()
    refused(
        system,
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        *flags,
        "--yes",
        expect=f"{system / existing}: exists, and init would create it. Move it out of the way",
    )


def test_8_src_of_the_unnamed_layer(tmp, capsys):
    manifest(tmp, distros=(), layers=())
    system = _system(tmp)
    (system / "src").mkdir()
    refused(system, capsys, "../m.manifest.yaml", "--yes", expect=f"{system / 'src'}: exists")


def _stub(tmp_path, name, body):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    path = bin_dir / name
    path.write_text(f"#!/bin/sh\n{body}\n")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return bin_dir


def test_9_no_vcs_on_path(tmp, capsys, monkeypatch):
    manifest(tmp)
    system = _system(tmp)
    monkeypatch.setenv("PATH", str(_stub(tmp, "git", "exit 0")))
    refused(
        system,
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        "--yes",
        expect="`vcs` is not found on PATH. Install vcs2l or vcstool",
    )


def test_9_vcs_but_no_git_on_path(tmp, capsys, monkeypatch):
    manifest(tmp)
    system = _system(tmp)
    monkeypatch.setenv("PATH", str(_stub(tmp, "vcs", "exit 0")))
    refused(
        system,
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        "--yes",
        expect="`git` is not found on PATH. Install git",
    )


def test_9_a_git_that_cannot_list_its_local_variables(tmp, capsys, monkeypatch):
    manifest(tmp)
    system = _system(tmp)
    _stub(tmp, "vcs", "exit 0")
    monkeypatch.setenv("PATH", str(_stub(tmp, "git", "exit 1")))
    refused(
        system,
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        "--yes",
        expect="rev-parse --local-env-vars` does not run. Repair or reinstall git",
    )


def test_10_input_not_a_terminal_without_yes(tmp, capsys, monkeypatch):
    manifest(tmp)
    monkeypatch.setattr("sys.stdin", io.StringIO("y\n"))
    refused(
        _system(tmp),
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        expect="Give --yes to set up without asking",
    )


class _Terminal(io.StringIO):
    def isatty(self):
        return True


@pytest.mark.parametrize("reply", ["n\n", "\n", ""])
def test_11_the_question_answered_no(tmp, capsys, monkeypatch, reply):
    manifest(tmp)
    system = _system(tmp)
    monkeypatch.setattr("sys.stdin", _Terminal(reply))
    (system / "unrelated.txt").write_text("a person's file\n")
    before = snapshot(tmp)
    assert run(system, "init", "../m.manifest.yaml", "--distro", "jazzy") == 1
    assert snapshot(tmp) == before
    out = capsys.readouterr().out
    assert "Set up this system in" in out
    assert out.endswith("Nothing was created.\n")


def test_the_question_escapes_a_control_character_in_the_systems_path(tmp, capsys, monkeypatch):
    # A system directory named with a newline: the question names it on one line, the newline
    # escaped, so it cannot print a line of its own. (A manifest's path with such a character is
    # refused before anything is printed, since the resolved files' head comment names it.)
    manifest(tmp)
    system = _system(tmp, "sys\nERROR: fake")
    monkeypatch.setattr("sys.stdin", _Terminal("n\n"))
    assert run(system, "init", "../m.manifest.yaml", "--distro", "jazzy") == 1
    out = capsys.readouterr().out
    assert f"Set up this system in {tmp}/sys\\x0aERROR: fake? [y/N] " in out
    assert "\nERROR: fake" not in out


def test_the_question_answered_yes_sets_up(tmp, capsys, monkeypatch):
    manifest(tmp)
    system = _system(tmp)
    monkeypatch.setattr("sys.stdin", _Terminal("yes\n"))
    assert run(system, "init", "../m.manifest.yaml", "--distro", "jazzy") == 0
    assert (system / "core/src/a/.git").is_dir()


def test_12_the_earlier_row_wins(tmp, capsys):
    manifest(tmp)
    system = _system(tmp)
    assert run(system, "init", "../m.manifest.yaml", "--distro", "jazzy", "--yes") == 0
    capsys.readouterr()
    # 1 before 2.
    refused(
        system,
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        "--distro",
        "rolling",
        expect="a system is already set up",
    )
    # 4 before 8.
    other = _system(tmp, "other")
    (other / "core").mkdir()
    refused(other, capsys, "../m.manifest.yaml", "--yes", expect="Name one with --distro")


def test_a_manifest_given_as_a_url_is_not_read_in_this_version(tmp, capsys):
    refused(
        _system(tmp),
        capsys,
        "https://example.org/m.manifest.yaml",
        "--yes",
        expect="only a manifest given as a file path is read in this version",
    )


def test_a_role_the_manifest_lacks_is_the_resolvers_error(tmp, capsys):
    manifest(tmp)
    refused(
        _system(tmp),
        capsys,
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        "--role",
        "robot",
        "--yes",
        expect="has no `roles:`, so no role is given",
    )


def test_a_manifest_whose_resolved_files_cannot_be_written_out_creates_nothing(tmp, capsys):
    # A no-break space in a folder on the manifest's path would go into the head comment of
    # every resolved file, which refuses it; init finds that before it creates anything.
    folder = tmp / "a\u00a0b"
    folder.mkdir()
    manifest(tmp).rename(folder / "m.manifest.yaml")
    system = _system(tmp)
    err = refused(
        system,
        capsys,
        "../a\u00a0b/m.manifest.yaml",
        "--distro",
        "jazzy",
        "--yes",
        expect="ERROR: refusing to write the head comment: the manifest's location or a name"
        " holds a control or invisible character; nothing was set up\n",
    )
    assert os.listdir(system) == ["unrelated.txt"]
    assert "the system is set up" not in err


def test_a_config_yaml_that_cannot_be_written_names_it_and_sets_nothing_up(tmp):
    # A file size limit makes the write of config.yaml fail, as a full disk would.
    manifest(tmp, distros=(), layers=())
    system = _system(tmp)
    before = snapshot(system)

    def a_small_file_size_limit():
        signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
        resource.setrlimit(resource.RLIMIT_FSIZE, (8, 8))

    env = {
        **os.environ,
        "PYTHONPATH": os.path.dirname(os.path.dirname(repos_manifest.__file__)),
    }
    done = subprocess.run(
        [sys.executable, "-m", "repos_manifest.cli", "init", "../m.manifest.yaml", "--yes"],
        cwd=system,
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        preexec_fn=a_small_file_size_limit,
    )
    assert done.returncode == 1, done.stderr
    assert done.stderr.endswith(
        f"ERROR: {system / '.repos-manifest' / 'config.yaml'}: cannot be written"
        " (File too large); nothing was set up\n"
    ), done.stderr
    assert snapshot(system) == before


def test_a_manifest_in_the_earlier_format_sets_nothing_up(tmp, capsys):
    # The one-line refusal of `resolve`, `show` and `validate` (`test_cli.py`), and nothing
    # written in the directory.
    (tmp / "old.manifest.yaml").write_text("layers: [core]\nrepos: {core: {}}\n")
    err = refused(
        _system(tmp),
        capsys,
        "../old.manifest.yaml",
        "--yes",
        expect="is in the earlier format (it has `repos:` and no `repositories:`)",
    )
    assert err == (
        "ERROR: ../old.manifest.yaml: is in the earlier format (it has `repos:` and no"
        " `repositories:`); this tool reads it only in the format of the specification,"
        " docs/spec.md\n"
    )
