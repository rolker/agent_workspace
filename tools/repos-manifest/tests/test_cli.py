import pytest

from repos_manifest import cli
from repos_manifest.cli import main


def test_cli_resolve_writes_files(fixtures_dir, tmp_path, capsys):
    manifest = fixtures_dir / "p11" / "manifest.yaml"
    out = tmp_path / "out"
    rc = main(
        [
            "resolve",
            "--manifest",
            str(manifest),
            "--role",
            "dev",
            "--distro",
            "jazzy",
            "--out",
            str(out),
        ]
    )
    assert rc == 0
    assert (out / "core.repos").is_file()
    captured = capsys.readouterr()
    assert "wrote" in captured.out


def test_cli_resolve_unknown_role_errors(fixtures_dir, tmp_path, capsys):
    manifest = fixtures_dir / "p11" / "manifest.yaml"
    out = tmp_path / "out"
    rc = main(
        [
            "resolve",
            "--manifest",
            str(manifest),
            "--role",
            "nope",
            "--distro",
            "jazzy",
            "--out",
            str(out),
        ]
    )
    assert rc == 1
    assert "unknown role" in capsys.readouterr().err


def test_cli_validate_clean(fixtures_dir, capsys):
    manifest = fixtures_dir / "p11" / "manifest.yaml"
    rc = main(["validate", "--manifest", str(manifest), "--role", "dev", "--distro", "jazzy"])
    assert rc == 0
    assert "no dependency violations" in capsys.readouterr().out


def test_cli_manifest_error_reported(tmp_path, capsys):
    bad = tmp_path / "bad.yaml"
    bad.write_text("layers: []\n")
    rc = main(
        [
            "resolve",
            "--manifest",
            str(bad),
            "--role",
            "x",
            "--distro",
            "jazzy",
            "--out",
            str(tmp_path / "o"),
        ]
    )
    assert rc == 1
    assert "ERROR" in capsys.readouterr().err


@pytest.mark.parametrize("command", ["resolve", "validate"])
@pytest.mark.parametrize("error", [ValueError, KeyError, TypeError, OSError, RuntimeError])
def test_cli_any_other_exception_is_one_fixed_line(command, error, tmp_path, capsys, monkeypatch):
    # The backstop: a route the loader does not turn into a ManifestError prints the exception's
    # type only, never its text (which can quote manifest content) and never a traceback.
    marker = "M4RK3R-s3cr3t"

    def boom(*_args, **_kwargs):
        raise error(f"value {marker}")

    monkeypatch.setattr(cli, "resolve_chain", boom)
    argv = [command, "--manifest", str(tmp_path / "m.yaml"), "--role", "dev", "--distro", "jazzy"]
    if command == "resolve":
        argv += ["--out", str(tmp_path / "o")]
    rc = main(argv)
    captured = capsys.readouterr()
    assert rc == 1
    assert captured.err == f"ERROR: internal error ({error.__name__})\n"
    assert marker not in captured.out


def test_cli_resolve_out_that_cannot_be_created_is_one_line(fixtures_dir, tmp_path, capsys):
    # Round 4: a FileNotFoundError traceback from the emitter.
    (tmp_path / "a-file").write_text("")
    out = tmp_path / "a-file" / "out"
    manifest = fixtures_dir / "p11" / "manifest.yaml"
    argv = ["resolve", "--manifest", str(manifest), "--role", "dev", "--distro", "jazzy"]
    rc = main(argv + ["--out", str(out), "--cache-dir", str(tmp_path / "cache")])
    assert rc == 1
    assert capsys.readouterr().err == f"ERROR: --out {out}: cannot be written (Not a directory)\n"


# --- show ------------------------------------------------------------------------------------

SHOWN = """\
distros: [jazzy, rolling]
groups: [sim]
roles:
  robot: []
repositories:
  a:
    type: git
    url: https://example.org/a.git
    version: main
  s:
    type: git
    url: https://example.org/s.git
    groups: [sim]
"""


def _listing(directory):
    return sorted(str(p.relative_to(directory)) for p in directory.rglob("*"))


def test_cli_show_prints_and_writes_nothing(tmp_path, capsys, monkeypatch):
    (tmp_path / "m.yaml").write_text(SHOWN)
    monkeypatch.chdir(tmp_path)
    before = _listing(tmp_path)
    assert main(["show", "m.yaml", "--role", "robot", "--distro", "jazzy"]) == 0
    out = capsys.readouterr().out
    assert out.startswith(
        "manifest  m.yaml\nrole      robot    groups on: (none)    distro: jazzy\n"
    )
    assert "  a   main   https://example.org/a.git\n" in out
    assert out.endswith("left out\n  s   group sim is off\n")
    assert _listing(tmp_path) == before


def test_cli_show_with_turns_a_group_on(tmp_path, capsys, monkeypatch):
    (tmp_path / "m.yaml").write_text(SHOWN)
    monkeypatch.chdir(tmp_path)
    assert main(["show", "m.yaml", "--role", "robot", "--with", "sim", "--distro", "rolling"]) == 0
    out = capsys.readouterr().out
    assert "groups on: sim    distro: rolling" in out
    assert "left out" not in out


@pytest.mark.parametrize(
    "argv,error",
    [
        (["--distro", "jazzy"], "has roles; give one of ['robot']"),
        (["--role", "robot"], "has distros; give one of ['jazzy', 'rolling']"),
        (["--role", "robot", "--distro", "humble"], "does not cover distro 'humble'"),
        (["--role", "x", "--distro", "jazzy"], "has no role 'x'"),
    ],
)
def test_cli_show_refuses_what_the_manifest_does_not_allow(argv, error, tmp_path, capsys):
    (tmp_path / "m.yaml").write_text(SHOWN)
    assert main(["show", str(tmp_path / "m.yaml"), *argv]) == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("ERROR: ") and error in captured.err


def test_cli_show_a_manifest_that_does_not_read_is_one_error(tmp_path, capsys):
    assert main(["show", str(tmp_path / "missing.yaml")]) == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err.startswith("ERROR: ") and "missing.yaml" in captured.err


def test_cli_show_distro_may_be_given_once(tmp_path, capsys):
    with pytest.raises(SystemExit):
        main(["show", "m.yaml", "--distro", "jazzy", "--distro", "rolling"])
    assert "--distro may be given only once" in capsys.readouterr().err


@pytest.mark.parametrize("before", [["m.yaml"], []])
def test_cli_show_refuses_an_empty_distro_name(before, tmp_path, capsys, monkeypatch):
    # With a manifest or without one, before any file or system directory is read.
    (tmp_path / "m.yaml").write_text(SHOWN)
    monkeypatch.chdir(tmp_path)
    assert main(["show", *before, "--role", "robot", "--distro", ""]) == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert "--distro is given an empty name; name the distro to show" in captured.err
