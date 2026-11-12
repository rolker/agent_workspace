import pytest

from ros_manifest import cli
from ros_manifest.cli import main


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
