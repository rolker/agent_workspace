"""`show` with no manifest, inside a system directory: it uses what `config.yaml` records and the
distro "Which distro a command uses" picks, and writes nothing."""

import pytest

from repos_manifest.cli import main
from repos_manifest.system import CONFIG_FILE, SYSTEM_DIR, Config, config_text

MANIFEST = """\
distros: [jazzy, rolling]
groups: [sim, hw]
roles:
  robot: [hw]
  developer: [sim, hw]
repositories:
  a:
    type: git
    url: https://example.org/a.git
    version: main
    distros:
      rolling:
        version: next
  s:
    type: git
    url: https://example.org/s.git
    groups: [sim]
"""


def _system(tmp_path, distros, layout="flat", role="robot", groups=()):
    """A system directory as `init` records it, with nothing cloned; the manifest's path is
    relative, so it is taken from the system directory."""
    system = tmp_path / "sys"
    (system / SYSTEM_DIR).mkdir(parents=True)
    (system / "m.yaml").write_text(MANIFEST)
    config = Config("m.yaml", role, list(groups), layout, distros)
    (system / SYSTEM_DIR / CONFIG_FILE).write_text(config_text(config))
    for distro in distros if layout == "distro-dirs" else []:
        (system / distro).mkdir()
    return system


def _listing(directory):
    return sorted(str(p.relative_to(directory)) for p in directory.rglob("*"))


def test_show_uses_what_the_system_records_from_a_directory_below_it(tmp_path, capsys, monkeypatch):
    system = _system(tmp_path, ["jazzy"], groups=["sim"])
    (system / "src").mkdir()
    monkeypatch.chdir(system / "src")
    before = _listing(system)
    assert main(["show"]) == 0
    out = capsys.readouterr().out
    assert out.startswith(
        "manifest  m.yaml\nrole      robot    groups on: hw, sim    distro: jazzy\n"
    )
    # The recorded group `sim` is on, so `s` is shown.
    assert "  a   main                   https://example.org/a.git\n" in out
    assert "  s   (its default branch)   https://example.org/s.git\n" in out
    assert "left out" not in out
    assert _listing(system) == before


@pytest.mark.parametrize("argv", [["--role", "developer"], ["--with", "sim"]])
def test_show_without_a_manifest_refuses_a_role_or_groups(argv, tmp_path, capsys, monkeypatch):
    monkeypatch.chdir(_system(tmp_path, ["jazzy"]))
    assert main(["show", *argv]) == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert "in a system directory show uses what it records" in captured.err
    assert "Give the manifest to try another role" in captured.err


def test_show_with_a_manifest_inside_a_system_tries_another_role(tmp_path, capsys, monkeypatch):
    monkeypatch.chdir(_system(tmp_path, ["jazzy"]))
    assert main(["show", "m.yaml", "--role", "developer", "--distro", "rolling"]) == 0
    out = capsys.readouterr().out
    assert "groups on: sim, hw    distro: rolling" in out
    assert "  a   next" in out


@pytest.mark.parametrize("argv", [[], ["--role", "developer"], ["--with", "sim"]])
def test_show_outside_a_system_with_no_manifest_says_what_to_give(
    argv, tmp_path, capsys, monkeypatch
):
    # With --role or --with too: the missing manifest is the problem, not the role.
    monkeypatch.chdir(tmp_path)
    assert main(["show", *argv]) == 1
    err = capsys.readouterr().err
    assert f"no manifest given, and no system directory in {tmp_path} or above it" in err
    assert "Give the manifest's path, or run show inside a system directory" in err
    assert "in a system directory show uses what it records" not in err


def test_show_at_the_top_of_a_system_with_several_distros_asks_for_one(
    tmp_path, capsys, monkeypatch
):
    monkeypatch.chdir(_system(tmp_path, ["jazzy", "rolling"], layout="distro-dirs"))
    assert main(["show"]) == 1
    assert "this system has several distros (jazzy, rolling); name one" in capsys.readouterr().err
    assert main(["show", "--distro", "rolling"]) == 0
    assert "distro: rolling" in capsys.readouterr().out


def test_show_inside_a_distros_directory_uses_that_distro(tmp_path, capsys, monkeypatch):
    system = _system(tmp_path, ["jazzy", "rolling"], layout="distro-dirs")
    monkeypatch.chdir(system / "rolling")
    assert main(["show"]) == 0
    out = capsys.readouterr().out
    assert "distro: rolling" in out
    assert "  a   next" in out


def test_show_refuses_a_distro_the_system_does_not_record(tmp_path, capsys, monkeypatch):
    monkeypatch.chdir(_system(tmp_path, ["jazzy"]))
    assert main(["show", "--distro", "rolling"]) == 1
    assert "--distro rolling: this system does not record it" in capsys.readouterr().err


def test_a_manifest_that_does_not_read_names_where_its_path_is_recorded(
    tmp_path, capsys, monkeypatch
):
    system = _system(tmp_path, ["jazzy"])
    (system / "m.yaml").unlink()
    monkeypatch.chdir(system)
    assert main(["show"]) == 1
    err = capsys.readouterr().err
    assert "m.yaml" in err
    assert f"(the manifest's path is `manifest` in {system / SYSTEM_DIR / CONFIG_FILE}" in err
