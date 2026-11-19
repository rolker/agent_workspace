"""The system directory's parts that need no clone: where each part goes, which distros a
command uses, `config.yaml` and `state.yaml`."""

import pytest
import yaml

from repos_manifest.yamlload import ManifestError
from repos_manifest.system import (
    Config,
    DistroState,
    RepoRecord,
    config_text,
    distros_for,
    find_system,
    layer_src_parts,
    paths_init_creates,
    put_distro_state,
    read_config,
    read_state,
    resolved_parts,
    setup_parts,
)


@pytest.mark.parametrize(
    "layout,distro,layers,expected",
    [
        ("flat", None, ["_unnamed"], [("src",), ("setup.bash",)]),
        ("flat", "jazzy", ["_unnamed", "core"], [("src",), ("core",), ("setup.bash",)]),
        ("distro-dirs", "jazzy", ["_unnamed"], [("jazzy",)]),
        ("distro-dirs", "jazzy", ["underlay", "core"], [("jazzy",)]),
    ],
)
def test_the_paths_init_creates(layout, distro, layers, expected):
    assert paths_init_creates(layout, distro, layers) == expected


def test_where_each_part_goes():
    assert layer_src_parts("flat", "jazzy", "_unnamed") == ("src",)
    assert layer_src_parts("flat", "jazzy", "core") == ("core", "src")
    assert layer_src_parts("distro-dirs", "jazzy", "_unnamed") == ("jazzy", "src")
    assert layer_src_parts("distro-dirs", "jazzy", "core") == ("jazzy", "core", "src")
    assert resolved_parts("flat", "jazzy") == (".repos-manifest", "resolved")
    assert resolved_parts("distro-dirs", "jazzy") == (".repos-manifest", "resolved", "jazzy")
    assert setup_parts("flat", None) == ("setup.bash",)
    assert setup_parts("distro-dirs", "rolling") == ("rolling", "setup.bash")


def _config(layout="distro-dirs", distros=("jazzy", "rolling")):
    return Config("m.yaml", None, [], layout, list(distros) if distros is not None else None)


def test_which_distros_a_command_uses(tmp_path):
    config = _config()
    assert distros_for(tmp_path, config, [], tmp_path) == ["jazzy", "rolling"]
    assert distros_for(tmp_path, config, [], tmp_path / "notes") == ["jazzy", "rolling"]
    assert distros_for(tmp_path, config, [], tmp_path / "rolling" / "core") == ["rolling"]
    assert distros_for(tmp_path, config, ["rolling"], tmp_path / "jazzy") == ["rolling"]
    with pytest.raises(ManifestError, match="--distro humble: this system does not record it"):
        distros_for(tmp_path, config, ["humble"], tmp_path)
    assert distros_for(tmp_path, _config("flat", None), [], tmp_path) == [None]
    with pytest.raises(ManifestError, match=r"\(it records: none\)"):
        distros_for(tmp_path, _config("flat", None), ["jazzy"], tmp_path)


def test_config_is_written_and_read_back(tmp_path):
    (tmp_path / ".repos-manifest").mkdir()
    config = Config("../m.yaml", "dev", ["ui"], "distro-dirs", ["jazzy", "rolling"])
    text = config_text(config)
    assert yaml.safe_load(text) == {
        "manifest": "../m.yaml",
        "role": "dev",
        "groups": ["ui"],
        "layout": "distro-dirs",
        "distros": {"jazzy": {}, "rolling": {}},
    }
    (tmp_path / ".repos-manifest/config.yaml").write_text(text)
    assert read_config(tmp_path) == config


@pytest.mark.parametrize(
    "text,why",
    [
        (None, "not found"),
        ("manifest: [\n", "does not read as YAML"),
        ("- a\n", "is a list, not a mapping"),
        ("layout: flat\n", "has no `manifest`"),
        ("manifest: m.yaml\n", "has no `layout`"),
        ("manifest: m.yaml\nlayout: tall\n", "`layout` is 'tall'"),
        ("manifest: [m.yaml]\nlayout: flat\n", "`manifest` is a list, not a path; this"),
        (
            "manifest: {url: g, version: j, path: m.yaml}\nlayout: flat\n",
            "`manifest` is a mapping, not a path; this version reads a manifest given as a path",
        ),
        (
            "manifest: https://example.org/m.yaml\nlayout: flat\n",
            "`manifest` is a URL, not a path; this version reads a manifest given as a path only",
        ),
        ("manifest: m.yaml\nlayout: flat\nfetch_from: x\n", "`fetch_from` is not read by this"),
        ("manifest: m.yaml\nlayout: flat\nlocal_manifest: a\n", "`local_manifest` is not read"),
        ("manifest: m.yaml\nlayout: flat\nremotes: {a: b}\n", "`remotes` is not read by this"),
        ("manifest: m.yaml\nrole:\nlayout: flat\n", "`role` is empty, not a name"),
        ("manifest: m.yaml\nrole: [a]\nlayout: flat\n", "`role` is a list, not a name"),
        ("manifest: m.yaml\ngroups: abc\nlayout: flat\n", "`groups` is a string, not a list"),
        ("manifest: m.yaml\ngroups: [a, [b]]\nlayout: flat\n", "`groups` holds a list"),
        ("manifest: m.yaml\nlayout: flat\ndistros: jazzy\n", "`distros` is a string, not"),
        ("manifest: m.yaml\nlayout: flat\ndistros: [jazzy]\n", "`distros` is a list, not"),
        ("manifest: m.yaml\nlayout: flat\ndistros: {}\n", "`distros` is empty"),
        ("manifest: m.yaml\nlayout: distro-dirs\n", "`layout` is distro-dirs and there is"),
        ("manifest: m.yaml\nlayout: distro-dirs\ndistros:\n", "`distros` is empty, not a"),
        (
            "manifest: m.yaml\nlayout: flat\ndistros: {jazzy: {}, rolling: {}}\n",
            "`layout` is flat and there are 2 distros",
        ),
        ("manifest: m.yaml\nlayout: flat\ndistros: {1: {}}\n", "`distros` has 1 as a name"),
        ("manifest: m.yaml\nlayout: flat\ndistros: {jazzy: 3}\n", "`distros.jazzy` is an int"),
        ("manifest: m.yaml\nlayout: flat\ndistros: {jazzy: }\n", "`distros.jazzy` is empty"),
        (
            "manifest: m.yaml\nlayout: flat\ndistros: {jazzy: {manifest_version: j}}\n",
            "`distros.jazzy.manifest_version` is not read by this version",
        ),
    ],
)
def test_a_config_that_cannot_be_used_names_the_file(tmp_path, text, why):
    (tmp_path / ".repos-manifest").mkdir()
    if text is not None:
        (tmp_path / ".repos-manifest/config.yaml").write_text(text)
    with pytest.raises(ManifestError) as raised:
        read_config(tmp_path)
    assert str(raised.value).startswith(f"{tmp_path}/.repos-manifest/config.yaml: {why}")


def test_the_system_is_found_from_below(tmp_path):
    (tmp_path / ".repos-manifest").mkdir()
    (tmp_path / "a" / "b").mkdir(parents=True)
    assert find_system(tmp_path / "a" / "b") == tmp_path


def test_writing_one_distros_state_leaves_the_others_as_they_were(tmp_path):
    (tmp_path / ".repos-manifest").mkdir()
    put_distro_state(tmp_path, "jazzy", DistroState({"a": RepoRecord("core", "jazzy", "1" * 40)}))
    put_distro_state(tmp_path, "rolling", DistroState({"a": RepoRecord("core", None, "2" * 40)}))
    text = (tmp_path / ".repos-manifest/state.yaml").read_text()
    jazzy_part = yaml.safe_dump(yaml.safe_load(text)["distros"]["jazzy"])
    put_distro_state(
        tmp_path, "rolling", DistroState({"b": RepoRecord("_unnamed", "v1", "3" * 40)})
    )
    after = yaml.safe_load((tmp_path / ".repos-manifest/state.yaml").read_text())
    assert yaml.safe_dump(after["distros"]["jazzy"]) == jazzy_part
    assert read_state(tmp_path, "rolling").repos == {"b": RepoRecord("_unnamed", "v1", "3" * 40)}
    assert after["format"] == 1
    assert [p.name for p in (tmp_path / ".repos-manifest").iterdir()] == ["state.yaml"]


def test_a_state_of_the_shape_this_version_writes_is_read(tmp_path):
    (tmp_path / ".repos-manifest").mkdir()
    text = (
        F
        + "distros:\n  jazzy:\n    repos:\n      a: "
        + REC
        + "\n      b: {layer: x, version: null, commit: d}\n"
    )
    (tmp_path / ".repos-manifest/state.yaml").write_text(text)
    assert read_state(tmp_path, "jazzy").repos == {
        "a": RepoRecord("core", "v", "abc"),
        "b": RepoRecord("x", None, "d"),
    }


def test_a_missing_state_is_empty_and_one_that_does_not_parse_names_the_file(tmp_path):
    (tmp_path / ".repos-manifest").mkdir()
    assert read_state(tmp_path, "jazzy").repos == {}
    (tmp_path / ".repos-manifest/state.yaml").write_text("distros: [\n")
    with pytest.raises(ManifestError, match=r"\.repos-manifest/state.yaml: does not read as YAML"):
        read_state(tmp_path, "jazzy")


F = "format: 1\n"
REC = "{layer: core, version: v, commit: abc}"


@pytest.mark.parametrize(
    "text,why",
    [
        ("- a\n", "is a list, not a mapping"),
        ("distros: {}\n", "has no `format`"),
        (F, "has no `distros`"),
        ("format: 2\ndistros: {}\n", "`format` is 2, not 1, the one this version writes"),
        ("format: true\ndistros: {}\n", "`format` is True, not 1"),
        (F + "distros: {}\nlocks: x\n", "`locks` is not read by this version"),
        (F + "distros: []\n", "`distros` is a list, not a mapping"),
        (F + "distros: {jazzy: 5}\n", "`distros.jazzy` is an int, not a mapping"),
        (F + "distros: {jazzy: }\n", "`distros.jazzy` is empty, not a mapping"),
        (F + "distros: {jazzy: {}}\n", "`distros.jazzy` has no `repos`"),
        (F + "distros: {jazzy: {repos: {}, x: 1}}\n", "`distros.jazzy.x` is not read by this"),
        (F + "distros: {jazzy: {repos: [a]}}\n", "`distros.jazzy.repos` is a list, not a mapping"),
        (F + "distros: {jazzy: {repos: {a: x}}}\n", "`distros.jazzy.repos.a` is a string, not a"),
        (
            F + "distros: {jazzy: {repos: {a: {layer: core, version: v}}}}\n",
            "`distros.jazzy.repos.a` has no `commit`",
        ),
        (
            F + "distros: {jazzy: {repos: {a: {layer: core, version: v, commit: c, url: 3}}}}\n",
            "`distros.jazzy.repos.a.url` is an int, not a string",
        ),
        (
            F + "distros: {jazzy: {repos: {a: {layer: core, version: v, commit: c, mine: u}}}}\n",
            "`distros.jazzy.repos.a.mine` is not read by this version",
        ),
        (
            F + "distros: {jazzy: {repos: {a: {layer: core, version: v, commit: c,"
            " moving: {from: x}}}}}\n",
            "`distros.jazzy.repos.a.moving` has no `to`",
        ),
        (
            F + "distros: {jazzy: {repos: {a: {layer: [x], version: v, commit: c}}}}\n",
            "`distros.jazzy.repos.a.layer` is a list, not a string",
        ),
        (
            F + "distros: {jazzy: {repos: {a: {layer: core, version: v, commit: 5}}}}\n",
            "`distros.jazzy.repos.a.commit` is an int, not a string",
        ),
        (
            F + "distros: {jazzy: {repos: {a: {layer: core, version: v, commit: }}}}\n",
            "`distros.jazzy.repos.a.commit` is empty, not a string",
        ),
        (
            F + "distros: {jazzy: {repos: {a: {layer: core, version: 3, commit: c}}}}\n",
            "`distros.jazzy.repos.a.version` is an int, not a string or empty",
        ),
    ],
)
def test_a_state_that_cannot_be_used_names_the_file_and_what_is_wrong(tmp_path, text, why):
    (tmp_path / ".repos-manifest").mkdir()
    (tmp_path / ".repos-manifest/state.yaml").write_text(text)
    for call in (
        lambda: read_state(tmp_path, "rolling"),
        lambda: put_distro_state(tmp_path, "rolling", DistroState()),
    ):
        with pytest.raises(ManifestError) as raised:
            call()
        assert str(raised.value).startswith(f"{tmp_path}/.repos-manifest/state.yaml: {why}")
        assert str(raised.value).endswith("; repair or remove it")
