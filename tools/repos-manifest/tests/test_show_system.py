"""`show` with no manifest, inside a system directory: it uses what `config.yaml` records and the
distro "Which distro a command uses" picks, and writes nothing."""

import os

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
    # The recorded path is relative to the system directory, not to src/: it is printed as an
    # absolute path, which opens from here.
    assert out.startswith(
        f"manifest  {os.path.realpath(system / 'm.yaml')}\n"
        "role      robot    groups on: hw, sim    distro: jazzy\n"
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


def test_show_in_a_system_prints_every_manifest_as_an_absolute_path(tmp_path, capsys, monkeypatch):
    # The recorded manifest builds on one in another directory and adds a repo: the manifest,
    # base and from lines all name absolute paths, each manifest the same way on every line.
    system = _system(tmp_path, ["jazzy"])
    (tmp_path / "published").mkdir()
    (tmp_path / "published" / "base.yaml").write_text(MANIFEST)
    (system / "m.yaml").write_text(
        "base: ../published/base.yaml\nrepositories:\n  n:\n    type: git\n"
        "    url: https://example.org/n.git\n"
    )
    (system / "src").mkdir()
    monkeypatch.chdir(system / "src")
    assert main(["show"]) == 0
    lines = capsys.readouterr().out.splitlines()
    leaf = os.path.realpath(system / "m.yaml")
    base = os.path.realpath(tmp_path / "published" / "base.yaml")
    assert lines[:2] == [f"manifest  {leaf}", f"base      {base}"]
    at = lines.index("  n   (its default branch)   https://example.org/n.git")
    assert lines[at + 1].strip() == f"from {leaf}"
    assert all(os.path.isfile(path) for path in (leaf, base))


def _record(system, manifest):
    config = Config(manifest, "robot", [], "flat", ["jazzy"])
    (system / SYSTEM_DIR / CONFIG_FILE).write_text(config_text(config))


def test_show_opens_the_recorded_path_as_sync_does_and_prints_it_canonical(
    tmp_path, capsys, monkeypatch
):
    # `sub/../m.yaml` opens, since sub/ exists: show reads it and prints the path canonical.
    system = _system(tmp_path, ["jazzy"])
    (system / "sub").mkdir()
    _record(system, "sub/../m.yaml")
    monkeypatch.chdir(system)
    assert main(["show"]) == 0
    assert capsys.readouterr().out.startswith(f"manifest  {os.path.realpath(system / 'm.yaml')}\n")


def test_a_recorded_path_that_resolves_only_once_canonicalised_is_refused_as_sync_refuses_it(
    tmp_path, capsys, monkeypatch
):
    # `missing/../m.yaml` names m.yaml once `..` is taken away by hand, but the system opens it
    # through missing/, which does not exist: show and sync both refuse it, by its recorded path.
    system = _system(tmp_path, ["jazzy"])
    _record(system, "missing/../m.yaml")
    monkeypatch.chdir(system)
    recorded = f"(the manifest's path is `manifest` in {system / SYSTEM_DIR / CONFIG_FILE}"
    assert main(["show"]) == 1
    shown = capsys.readouterr()
    assert shown.out == ""
    assert "missing/../m.yaml" in shown.err and recorded in shown.err
    assert main(["sync"]) == 1
    synced = capsys.readouterr().err
    assert "missing/../m.yaml" in synced and recorded in synced
