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
