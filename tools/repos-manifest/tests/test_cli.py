import pytest

from repos_manifest import cli
from repos_manifest.cli import main
from repos_manifest.manifest import _EARLIER_FORMAT_KEYS

from helpers import make_remote, make_system, repo, run, snapshot

# A manifest in the earlier format, in the shape of the project11 manifest it was used for: no
# `repositories:` and no `base:` key, its repos under `repos:` by layer, each with a `ref`.
EARLIER_FORMAT = """\
layers:
  - core
repos:
  core:
    a:
      url: https://example.org/a.git
      ref: jazzy
roles:
  dev:
    subtract: []
    add: []
"""

# A manifest in the earlier format that gives no repos of its own, only the one it extends.
EARLIER_FORMAT_EXTENDS = """\
extends:
  path: base.yaml
layers: [core]
optional_layers: [core]
"""

# A manifest with a `base:` key and its repos under the earlier format's `repos:`.
EARLIER_FORMAT_WITH_BASE = """\
base: base.yaml
repos:
  core: {}
"""


def _argv(command, manifest, out):
    if command == "show":
        return ["show", str(manifest), "--role", "dev", "--distro", "jazzy"]
    argv = [command, "--manifest", str(manifest), "--role", "dev", "--distro", "jazzy"]
    return argv + (["--out", str(out)] if command == "resolve" else [])


@pytest.mark.parametrize(
    "text,keys",
    [
        (EARLIER_FORMAT, "`repos:`"),
        (EARLIER_FORMAT_EXTENDS, "`extends:`, `optional_layers:`"),
        (EARLIER_FORMAT_WITH_BASE, "`repos:`"),
    ],
)
@pytest.mark.parametrize("command", ["resolve", "show", "validate"])
def test_a_manifest_in_the_earlier_format_is_refused_naming_the_format(
    command, text, keys, tmp_path, capsys, monkeypatch
):
    # The tool reads one format. A manifest with no `repositories:` key and a top-level key of
    # the earlier format is refused, whether or not it has a `base:` (which is not read), naming
    # that format and the specification, and nothing is written.
    (tmp_path / "old.yaml").write_text(text)
    monkeypatch.chdir(tmp_path)
    out = tmp_path / "out"
    assert main(_argv(command, "old.yaml", out)) == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err == (
        f"ERROR: old.yaml: is in the earlier format (it has {keys} and no `repositories:`);"
        " this tool reads it only in the format of the specification, docs/spec.md\n"
    )
    assert not out.exists()
    assert sorted(p.name for p in tmp_path.iterdir()) == ["old.yaml"]


@pytest.mark.parametrize("key", _EARLIER_FORMAT_KEYS)
@pytest.mark.parametrize("command", ["resolve", "show", "validate"])
def test_each_key_of_the_earlier_format_is_refused(command, key, tmp_path, capsys, monkeypatch):
    # Every key of the tuple the tool checks, alone, so a key added to it is tested too.
    (tmp_path / "old.yaml").write_text(f"{key}: {{}}\n")
    monkeypatch.chdir(tmp_path)
    out = tmp_path / "out"
    assert main(_argv(command, "old.yaml", out)) == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err == (
        f"ERROR: old.yaml: is in the earlier format (it has `{key}:` and no `repositories:`);"
        " this tool reads it only in the format of the specification, docs/spec.md\n"
    )
    assert sorted(p.name for p in tmp_path.iterdir()) == ["old.yaml"]


@pytest.mark.parametrize("command", ["sync", "status"])
def test_a_recorded_manifest_now_in_the_earlier_format_changes_nothing(
    command, vcs, tmp_path, capsys
):
    # A system set up from a manifest that is now in the earlier format: `sync` and `status`
    # stop on it with the same message (the error line `sync` prints, a report line of
    # `status`), exit 1 and change nothing.
    remote = make_remote(tmp_path / "remotes", "a")
    system, manifest = make_system(tmp_path, {"a": repo(remote)})
    manifest.write_text(EARLIER_FORMAT)
    before = snapshot(tmp_path)
    capsys.readouterr()
    assert run(system, command) == 1
    assert snapshot(tmp_path) == before
    captured = capsys.readouterr()
    refusal = (
        "ERROR: the manifest is what failed; nothing was changed: ../sys.manifest.yaml: is in"
        " the earlier format (it has `repos:` and no `repositories:`); this tool reads it only"
        " in the format of the specification, docs/spec.md (the manifest's path is `manifest`"
        f" in {system / '.repos-manifest/config.yaml'}, taken from the system directory"
        f" {system})\n"
    )
    if command == "sync":
        assert (captured.out, captured.err) == ("", refusal)
    else:
        assert captured.err == ""
        assert f"\n  {refusal}" in captured.out, captured.out


@pytest.mark.parametrize(
    "argv",
    [
        ["resolve", "--layout", "manifest-dir"],
        ["resolve", "--layout", "flat"],
        ["resolve", "--cache-dir", "c"],
        ["validate", "--cache-dir", "c"],
    ],
)
def test_the_options_of_the_earlier_format_are_not_accepted(argv, tmp_path, capsys):
    rest = ["--manifest", str(tmp_path / "m.yaml")]
    rest += ["--out", str(tmp_path / "out")] if argv[0] == "resolve" else []
    with pytest.raises(SystemExit) as excinfo:
        main(argv + rest)
    assert excinfo.value.code == 2
    assert f"unrecognized arguments: {' '.join(argv[1:])}" in capsys.readouterr().err
    assert not (tmp_path / "out").exists()


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
    assert capsys.readouterr().err == f"ERROR: {bad}: has no `repositories:`\n"


# `show` is left out: it reports an OSError of its own (``reporting_oserror``).
@pytest.mark.parametrize("command", ["resolve", "validate"])
@pytest.mark.parametrize("error", [ValueError, KeyError, TypeError, OSError, RuntimeError])
def test_cli_any_other_exception_is_one_fixed_line(command, error, tmp_path, capsys, monkeypatch):
    # The backstop: a route the reader does not turn into a ManifestError prints the exception's
    # type only, never its text (which can quote manifest content) and never a traceback. The
    # reader is the first thing each command calls, so the manifest need not exist.
    marker = "M4RK3R-s3cr3t"

    def boom(*_args, **_kwargs):
        raise error(f"value {marker}")

    monkeypatch.setattr(cli, "read_manifest", boom)
    rc = main(_argv(command, tmp_path / "m.yaml", tmp_path / "o"))
    captured = capsys.readouterr()
    assert rc == 1
    assert captured.err == f"ERROR: internal error ({error.__name__})\n"
    assert marker not in captured.out


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
        "manifest    m.yaml\nrole        robot    groups on: (none)    distro: jazzy\n"
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
