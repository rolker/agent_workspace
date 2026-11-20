"""`init` against local git repositories: the trees it makes, `config.yaml`, `state.yaml`, the
resolved files, `setup.bash`, failed and optional repos, and what it prints."""

import os
import subprocess
from pathlib import Path

import pytest
import yaml

from helpers import (
    branch,
    git,
    head,
    make_remote,
    repo,
    run,
    snapshot,
    temporaries,
    write_manifest,
)
from repos_manifest import sync
from repos_manifest.cli import main
from repos_manifest.output import MARKER

FIXTURE = Path(__file__).parent / "fixtures" / "project11" / "project11.manifest.yaml"


@pytest.fixture
def remotes(vcs, tmp_path):
    root = tmp_path / "remotes"
    return {
        "a": make_remote(root, "a", branches=["jazzy", "rolling"]),
        "b": make_remote(root, "b", tags=["v1"]),
        "c": make_remote(root, "c", branches=["dev"]),
    }


@pytest.fixture
def system(tmp_path):
    path = tmp_path / "sys"
    path.mkdir()
    return path


def layered(tmp_path, remotes, distros=("jazzy", "rolling"), **extra):
    """Two layers, three repos: `a` on the distro's branch, `b` at a tag, `grp/c` nested."""
    data = {"format": 1}
    if distros:
        data["distros"] = list(distros)
    data["layers"] = ["underlay", "core"]
    data["groups"] = ["extra"]
    data["roles"] = {"dev": [], "full": ["extra"]}
    a = repo(remotes["a"], "jazzy", "underlay")
    if distros:
        a["distros"] = {"rolling": {"version": "rolling"}}
    data["repositories"] = {
        "a": a,
        "b": repo(remotes["b"], "v1", "core"),
        "grp/c": repo(remotes["c"], "dev", "core", groups=["extra"]),
    }
    data["repositories"].update(extra)
    return write_manifest(tmp_path / "m.manifest.yaml", data)


def plain(tmp_path, remotes):
    """No layers, no distros, no roles."""
    data = {"format": 1, "repositories": {"a": repo(remotes["a"]), "b": repo(remotes["b"], "v1")}}
    return write_manifest(tmp_path / "m.manifest.yaml", data)


def state(system):
    return yaml.safe_load((system / ".repos-manifest" / "state.yaml").read_text())


def config(system):
    return yaml.safe_load((system / ".repos-manifest" / "config.yaml").read_text())


def test_flat_with_no_layers_and_no_distro(remotes, tmp_path, system, capsys):
    plain(tmp_path, remotes)
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    assert sorted(os.listdir(system)) == [".repos-manifest", "setup.bash", "src"]
    assert branch(system / "src" / "a") == "main"
    assert head(system / "src" / "b") == git("rev-parse", "v1", cwd=remotes["b"])
    assert config(system) == {"manifest": "../m.manifest.yaml", "layout": "flat"}
    recorded = state(system)["distros"]["_unnamed"]["repos"]
    assert recorded["a"] == {
        "layer": "_unnamed",
        "version": None,
        "commit": head(system / "src/a"),
        "url": str(remotes["a"]),
    }
    assert recorded["b"]["version"] == "v1"
    assert sorted(os.listdir(system / ".repos-manifest" / "resolved")) == sorted(
        [MARKER, "_unnamed.repos", "layers.txt", "optional.txt"]
    )
    out = capsys.readouterr().out
    assert "Layout: one directory for the system.\n" in out
    assert "cloning src/a\n" in out


def test_flat_with_layers_and_a_distro(remotes, tmp_path, system, capsys):
    layered(tmp_path, remotes)
    rc = run(system, "init", "../m.manifest.yaml", "--distro", "rolling", "--role", "full", "--yes")
    assert rc == 0
    assert sorted(os.listdir(system)) == [".repos-manifest", "core", "setup.bash", "underlay"]
    assert branch(system / "underlay/src/a") == "rolling"
    assert branch(system / "core/src/grp/c") == "dev"
    assert head(system / "core/src/b") == git("rev-parse", "v1", cwd=remotes["b"])
    assert config(system) == {
        "manifest": "../m.manifest.yaml",
        "role": "full",
        "layout": "flat",
        "distros": {"rolling": {}},
    }
    recorded = state(system)["distros"]["rolling"]["repos"]
    assert recorded["a"]["version"] == "rolling" and recorded["a"]["layer"] == "underlay"
    assert recorded["grp/c"] == {
        "layer": "core",
        "version": "dev",
        "commit": head(system / "core/src/grp/c"),
        "url": str(remotes["c"]),
    }
    out = capsys.readouterr().out
    assert (
        "Layout: one directory for the system, with no directory per distro. A distro cannot be"
        " added to this system later. To be able to add one, set up with --distro-dirs.\n" in out
    )


def test_the_role_and_with_select_the_repos(remotes, tmp_path, system):
    layered(tmp_path, remotes)
    assert (
        run(system, "init", "../m.manifest.yaml", "--distro", "jazzy", "--role", "dev", "--yes")
        == 0
    )
    assert not (system / "core/src/grp").exists()
    other = system.parent / "other"
    other.mkdir()
    rc = run(
        other,
        "init",
        "../m.manifest.yaml",
        "--distro",
        "jazzy",
        "--role",
        "dev",
        "--with",
        "extra",
        "--yes",
    )
    assert rc == 0
    assert (other / "core/src/grp/c").is_dir()
    assert config(other)["groups"] == ["extra"]


def test_distro_dirs_with_two_distros(remotes, tmp_path, system, capsys):
    layered(tmp_path, remotes)
    rc = run(
        system,
        "init",
        "../m.manifest.yaml",
        "--distro-dirs",
        "--distro",
        "jazzy",
        "--distro",
        "rolling",
        "--role",
        "full",
        "--yes",
    )
    assert rc == 0
    assert sorted(os.listdir(system)) == [".repos-manifest", "jazzy", "rolling"]
    for distro in ("jazzy", "rolling"):
        assert sorted(os.listdir(system / distro)) == ["core", "setup.bash", "underlay"]
        assert branch(system / distro / "underlay/src/a") == distro
        assert (system / ".repos-manifest/resolved" / distro / "layers.txt").is_file()
        assert set(state(system)["distros"][distro]["repos"]) == {"a", "b", "grp/c"}
    assert config(system)["distros"] == {"jazzy": {}, "rolling": {}}
    assert config(system)["layout"] == "distro-dirs"
    out = capsys.readouterr().out
    assert "Distro jazzy: 3 repos in 2 layers\n" in out
    assert "Distro rolling: 3 repos in 2 layers\n" in out
    assert "  rolling/underlay/src/\n" in out
    assert "Layout: a directory per distro.\n" in out


def test_distro_dirs_with_no_layers(remotes, tmp_path, system):
    data = {"format": 1, "distros": ["jazzy"], "repositories": {"a": repo(remotes["a"], "jazzy")}}
    write_manifest(tmp_path / "m.manifest.yaml", data)
    assert (
        run(system, "init", "../m.manifest.yaml", "--distro-dirs", "--distro", "jazzy", "--yes")
        == 0
    )
    assert sorted(os.listdir(system / "jazzy")) == ["setup.bash", "src"]
    assert branch(system / "jazzy/src/a") == "jazzy"


def test_the_resolved_files_are_what_resolve_writes(remotes, tmp_path, system):
    layered(tmp_path, remotes)
    rc = run(system, "init", "../m.manifest.yaml", "--distro", "jazzy", "--role", "full", "--yes")
    assert rc == 0
    out = tmp_path / "out"
    rc = run(
        system,
        "resolve",
        "--manifest",
        "../m.manifest.yaml",
        "--role",
        "full",
        "--distro",
        "jazzy",
        "--out",
        out,
    )
    assert rc == 0
    assert snapshot(out) == snapshot(system / ".repos-manifest/resolved")


def test_a_manifest_with_base_sets_up_the_merged_chain(remotes, tmp_path, system, capsys):
    """`base` is taken from the manifest's own directory, not from where `init` runs."""
    shared = tmp_path / "manifests"
    shared.mkdir()
    parent = {"format": 1, "layers": ["underlay", "core"]}
    parent["repositories"] = {"a": repo(remotes["a"], "jazzy", "underlay")}
    parent = write_manifest(shared / "parent.manifest.yaml", parent)
    leaf = {"format": 1, "base": "parent.manifest.yaml"}
    leaf["repositories"] = {"b": repo(remotes["b"], "v1", "core")}
    write_manifest(shared / "leaf.manifest.yaml", leaf)
    assert run(system, "init", "../manifests/leaf.manifest.yaml", "--yes") == 0
    assert sorted(os.listdir(system)) == [".repos-manifest", "core", "setup.bash", "underlay"]
    assert branch(system / "underlay/src/a") == "jazzy"
    assert head(system / "core/src/b") == git("rev-parse", "v1", cwd=remotes["b"])
    assert config(system) == {"manifest": "../manifests/leaf.manifest.yaml", "layout": "flat"}
    recorded = state(system)["distros"]["_unnamed"]["repos"]
    assert recorded == {
        "a": {
            "layer": "underlay",
            "version": "jazzy",
            "commit": head(system / "underlay/src/a"),
            "url": str(remotes["a"]),
        },
        "b": {
            "layer": "core",
            "version": "v1",
            "commit": head(system / "core/src/b"),
            "url": str(remotes["b"]),
        },
    }
    resolved = (system / ".repos-manifest/resolved/layers.txt").read_text()
    assert f"# base: {os.path.realpath(parent)}\n" in resolved
    capsys.readouterr()
    assert run(system, "sync") == 0
    assert "cloning" not in capsys.readouterr().out


def test_setup_bash_says_nothing_is_built_and_fails_when_sourced(remotes, tmp_path, system):
    plain(tmp_path, remotes)
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    done = subprocess.run(
        ["bash", "-c", "source setup.bash; echo status $?"],
        cwd=system,
        capture_output=True,
        text=True,
        check=False,
    )
    assert done.stdout == "status 1\n"
    assert "nothing is built here yet" in done.stderr


def test_a_setup_bash_made_while_init_runs_is_not_replaced(remotes, tmp_path, system, monkeypatch):
    plain(tmp_path, remotes)
    checked = sync.place_problem

    def a_person_writes_setup_bash_meanwhile(system_, parts):
        if parts[-1] == "setup.bash":
            (system_ / "setup.bash").write_text("# mine\n")
        return checked(system_, parts)

    monkeypatch.setattr(sync, "place_problem", a_person_writes_setup_bash_meanwhile)
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    assert (system / "setup.bash").read_text() == "# mine\n"
    assert temporaries(system) == []


def test_a_repo_that_cannot_be_fetched_is_an_error_and_the_others_go_on(
    remotes, tmp_path, system, capsys
):
    missing = tmp_path / "remotes" / "later"
    data = {
        "format": 1,
        "repositories": {"a": repo(remotes["a"]), "later": repo(missing), "b": repo(remotes["b"])},
    }
    write_manifest(tmp_path / "m.manifest.yaml", data)
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 1
    assert sorted(os.listdir(system / "src")) == ["a", "b"]
    assert temporaries(system) == []
    assert set(state(system)["distros"]["_unnamed"]["repos"]) == {"a", "b"}
    captured = capsys.readouterr()
    assert "ERROR: src/later: vcs import exited" in captured.out
    assert "failed (1): src/later" in captured.out
    assert "run `repos-manifest sync` to finish" in captured.out
    # Once the remote is there, sync clones it.
    make_remote(tmp_path / "remotes", "later")
    assert run(system, "sync") == 0
    assert (system / "src/later/README").is_file()
    assert set(state(system)["distros"]["_unnamed"]["repos"]) == {"a", "b", "later"}


def test_an_optional_repo_that_cannot_be_fetched_is_skipped_and_listed(
    remotes, tmp_path, system, capsys
):
    data = {
        "format": 1,
        "repositories": {
            "a": repo(remotes["a"]),
            "maybe": repo(tmp_path / "nowhere", optional=True),
        },
    }
    write_manifest(tmp_path / "m.manifest.yaml", data)
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    assert sorted(os.listdir(system / "src")) == ["a"]
    assert set(state(system)["distros"]["_unnamed"]["repos"]) == {"a"}
    out = capsys.readouterr().out
    assert "optional, skipped (1): src/maybe" in out
    assert "  maybe  (its default branch)" in out and "(optional)" in out
    # Listed every time.
    assert run(system, "sync") == 0
    assert "optional, skipped (1): src/maybe" in capsys.readouterr().out


@pytest.mark.skipif(os.name == "posix" and os.geteuid() == 0, reason="root can write anywhere")
def test_a_directory_that_cannot_be_written_names_it_and_the_reason(
    remotes, tmp_path, system, capsys
):
    plain(tmp_path, remotes)
    system.chmod(0o500)
    try:
        assert run(system, "init", "../m.manifest.yaml", "--yes") == 1
        assert os.listdir(system) == []
    finally:
        system.chmod(0o700)
    err = capsys.readouterr().err
    assert f"ERROR: {system}: cannot be written (Permission denied); nothing was set up\n" in err
    assert ".repos-manifest-tmp-" not in err


def test_git_variables_naming_another_repository_do_not_reach_the_clones(
    remotes, tmp_path, system, monkeypatch
):
    # As in a git hook or `git submodule foreach`: every git the tool runs would otherwise act
    # on that repository, and state.yaml would record its commit for every repo.
    layered(tmp_path, remotes)
    other = make_remote(tmp_path, "other")
    other_before = snapshot(other)
    monkeypatch.setenv("GIT_DIR", str(other / ".git"))
    monkeypatch.setenv("GIT_WORK_TREE", str(other))
    monkeypatch.setenv("GIT_INDEX_FILE", str(other / ".git" / "index"))
    rc = run(system, "init", "../m.manifest.yaml", "--distro", "jazzy", "--role", "full", "--yes")
    for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
        monkeypatch.delenv(name)
    assert rc == 0
    assert snapshot(other) == other_before
    recorded = state(system)["distros"]["jazzy"]["repos"]
    for key, place in (("a", "underlay/src/a"), ("b", "core/src/b"), ("grp/c", "core/src/grp/c")):
        assert (system / place / ".git").is_dir(), place
        assert (system / place / "README").is_file(), place
        assert recorded[key]["commit"] == head(system / place), key
    assert head(system / "underlay/src/a") == git("rev-parse", "jazzy", cwd=remotes["a"])


def test_git_configuration_passed_in_the_environment_reaches_the_clones(
    remotes, tmp_path, system, monkeypatch
):
    # A url rewrite passed as GIT_CONFIG_COUNT and its pairs, as a person or a CI system does;
    # the manifest's urls start with a prefix that only the rewrite makes a real path. A file://
    # url, because git does not rewrite a plain local path.
    made_up = f"file://{tmp_path / 'made-up'}/"
    data = {
        "format": 1,
        "repositories": {
            "a": repo(f"{made_up}a"),
            "b": repo(f"{made_up}b", "v1"),
        },
    }
    write_manifest(tmp_path / "m.manifest.yaml", data)
    monkeypatch.setenv("GIT_CONFIG_COUNT", "1")
    monkeypatch.setenv("GIT_CONFIG_KEY_0", f"url.{tmp_path / 'remotes'}/.insteadOf")
    monkeypatch.setenv("GIT_CONFIG_VALUE_0", made_up)
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    assert head(system / "src" / "a") == head(remotes["a"])
    assert head(system / "src" / "b") == git("rev-parse", "v1^{commit}", cwd=remotes["b"])


def test_the_environment_keeps_configuration_and_drops_the_config_file(vcs, monkeypatch):
    # GIT_CONFIG names a file for `git config` alone; git drops it, as the tool does, when it
    # runs a command in another repository, and keeps the two that carry configuration.
    monkeypatch.setenv("GIT_CONFIG", "/elsewhere/config")
    monkeypatch.setenv("GIT_CONFIG_PARAMETERS", "'core.abbrev'='12'")
    monkeypatch.setenv("GIT_CONFIG_COUNT", "0")
    env = sync.require_tools()
    assert "GIT_CONFIG" not in env
    assert env["GIT_CONFIG_PARAMETERS"] == "'core.abbrev'='12'"
    assert env["GIT_CONFIG_COUNT"] == "0"


def _project11_with_local_remotes(tmp_path):
    """The project11 fixture with every url pointing at one local remote that has a branch for
    each version the fixture names."""
    data = yaml.safe_load(FIXTURE.read_text())
    versions = set()
    for entry in data["repositories"].values():
        versions.add(entry.get("version"))
        for on in (entry.get("distros") or {}).values():
            if on and on.get("version"):
                versions.add(on["version"])
    remote = make_remote(tmp_path / "remotes", "one", branches=sorted(v for v in versions if v))
    for entry in data["repositories"].values():
        entry["url"] = str(remote)
    return write_manifest(tmp_path / "project11.manifest.yaml", data)


def test_the_owners_shape_distro_dirs_rolling_developer(vcs, tmp_path, system):
    _project11_with_local_remotes(tmp_path)
    rc = run(
        system,
        "init",
        "../project11.manifest.yaml",
        "--distro-dirs",
        "--distro",
        "rolling",
        "--role",
        "developer",
        "--yes",
    )
    assert rc == 0
    out = tmp_path / "out"
    assert (
        run(
            system,
            "resolve",
            "--manifest",
            "../project11.manifest.yaml",
            "--role",
            "developer",
            "--distro",
            "rolling",
            "--out",
            out,
        )
        == 0
    )
    assert snapshot(out) == snapshot(system / ".repos-manifest/resolved/rolling")
    layers = (out / "layers.txt").read_text().split("\n")
    layers = [line for line in layers if line and not line.startswith("#")]
    assert len(layers) == 7
    recorded = state(system)["distros"]["rolling"]["repos"]
    for layer in layers:
        listed = yaml.safe_load((out / f"{layer}.repos").read_text())["repositories"]
        for key, entry in listed.items():
            place = system / "rolling" / layer / "src" / key
            assert (place / ".git").is_dir(), place
            assert branch(place) == entry.get("version", "main")
            assert recorded[key]["commit"] == head(place)
    assert temporaries(system) == []


def test_help_lists_init_and_sync(capsys):
    with pytest.raises(SystemExit):
        main(["--help"])
    out = capsys.readouterr().out
    assert "init" in out and "sync" in out
