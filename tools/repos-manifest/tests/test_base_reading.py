"""Reading a manifest that builds on others through `base`: locations, the order of reading,
each manifest read once, a manifest that builds on itself, the checks on each manifest read,
and what `resolve` and `validate` say about the manifests read."""

import os
import re
import textwrap

import pytest

from repos_manifest import base
from repos_manifest.base import load_manifest
from repos_manifest.cli import main
from repos_manifest.yamlload import ManifestError

REPO = "    type: git\n    url: https://example.org/{name}.git\n"


def _write(directory, name, text):
    path = directory / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(text))
    return path


def _repos(*names):
    return "repositories:\n" + "".join(f"  {n}:\n" + REPO.format(name=n) for n in names)


def _real(path):
    return os.path.realpath(path)


@pytest.fixture
def opened(monkeypatch):
    """The real paths of the manifest files read, in order."""
    seen = []
    read_text = base._read_text

    def counting(path, label):
        seen.append(os.path.realpath(path))
        return read_text(path, label)

    monkeypatch.setattr(base, "_read_text", counting)
    return seen


# --- Locations -------------------------------------------------------------------------------


def test_base_may_be_one_path(tmp_path):
    parent = _write(tmp_path, "p.yaml", _repos("a"))
    leaf = _write(tmp_path, "m.yaml", "base: p.yaml\n")
    m = load_manifest(leaf)
    assert list(m.repositories) == ["a"]
    assert m.bases == [_real(parent)]


def test_base_may_be_a_list_read_in_the_order_given(tmp_path):
    first = _write(tmp_path, "p1.yaml", _repos("a"))
    second = _write(tmp_path, "p2.yaml", _repos("b"))
    leaf = _write(tmp_path, "m.yaml", "base: [p1.yaml, p2.yaml]\n")
    m = load_manifest(leaf)
    assert list(m.repositories) == ["a", "b"]
    assert m.bases == [_real(first), _real(second)]


def test_a_relative_path_is_taken_from_the_directory_of_the_manifest_that_names_it(tmp_path):
    _write(tmp_path, "c.yaml", _repos("c"))
    _write(tmp_path, "sub/b.yaml", "base: ../c.yaml\n" + _repos("b"))
    leaf = _write(tmp_path, "top/m.yaml", "base: ../sub/b.yaml\n")
    m = load_manifest(leaf)
    assert list(m.repositories) == ["c", "b"]
    assert m.bases == [_real(tmp_path / "c.yaml"), _real(tmp_path / "sub/b.yaml")]


def test_an_absolute_path_is_read_as_given(tmp_path):
    parent = _write(tmp_path, "elsewhere/p.yaml", _repos("a"))
    leaf = _write(tmp_path, "m.yaml", f"base: {parent}\n")
    assert load_manifest(leaf).bases == [_real(parent)]


def test_a_relative_path_is_taken_from_the_real_directory_of_a_linked_manifest(tmp_path):
    # The manifest is reached through a link in another directory; its parent is beside the
    # file the link leads to.
    _write(tmp_path, "real/p.yaml", _repos("real_parent"))
    _write(tmp_path, "real/m.yaml", "base: p.yaml\n")
    _write(tmp_path, "links/p.yaml", _repos("wrong_parent"))
    (tmp_path / "links/m.yaml").symlink_to(tmp_path / "real/m.yaml")
    m = load_manifest(tmp_path / "links/m.yaml")
    assert list(m.repositories) == ["real_parent"]
    assert m.bases == [_real(tmp_path / "real/p.yaml")]


def test_one_file_reached_by_two_paths_is_one_manifest(tmp_path, opened):
    parent = _write(tmp_path, "p.yaml", _repos("a"))
    (tmp_path / "alias.yaml").symlink_to(parent)
    leaf = _write(tmp_path, "m.yaml", "base: [p.yaml, ./alias.yaml, sub/../p.yaml]\n")
    (tmp_path / "sub").mkdir()
    assert load_manifest(leaf).bases == [_real(parent)]
    assert opened == [_real(leaf), _real(parent)]


@pytest.mark.parametrize(
    "value,match",
    [
        ("https://example.org/p.yaml", "base: 'https://example.org/p.yaml' is a URL, not a path"),
        ("http://example.org/p.yaml", "base: 'http://example.org/p.yaml' is a URL, not a path"),
        ("ftp://example.org/p.yaml", "base: 'ftp://example.org/p.yaml' is a URL, not a path"),
        ("'ext::sh -c x'", "base: 'ext::sh -c x' is a URL, not a path"),
        (
            "{url: 'https://example.org/r.git', version: main, path: p.yaml}",
            # Described, not shown: the mapping may hold a url with a password.
            "base: is a mapping, the form of a file in a git repo",
        ),
        (
            "[p.yaml, {url: 'https://example.org/r.git', path: p.yaml}]",
            "base\\[1\\]: is a mapping, .* git repo",
        ),
        ("12", "base: must be a string, got a int"),
        ("~", "base: must be a string, got nothing"),
        ("''", "base: must not be empty"),
        ("[[p.yaml]]", "base\\[0\\]: must be a string, got a list"),
        ("[]", "base: is empty; leave it out"),
    ],
)
def test_a_location_this_version_cannot_read_is_refused(tmp_path, value, match):
    leaf = _write(tmp_path, "m.yaml", f"base: {value}\n" + _repos("a"))
    with pytest.raises(ManifestError, match=f"^{re.escape(str(leaf))}: {match}"):
        load_manifest(leaf)


def test_a_url_or_git_location_says_this_version_reads_a_path_only(tmp_path):
    for value in ("https://example.org/p.yaml", "{url: 'x', path: p.yaml}"):
        leaf = _write(tmp_path, "m.yaml", f"base: {value}\n" + _repos("a"))
        with pytest.raises(ManifestError, match="reads a location in `base` given as a path only"):
            load_manifest(leaf)


def test_a_path_with_a_colon_after_a_slash_is_a_path(tmp_path):
    _write(tmp_path, "d/a:b.yaml", _repos("a"))
    leaf = _write(tmp_path, "m.yaml", "base: d/a:b.yaml\n")
    assert list(load_manifest(leaf).repositories) == ["a"]


def test_a_missing_parent_names_the_manifest_and_the_base_entry(tmp_path):
    leaf = _write(tmp_path, "m.yaml", "base: [p.yaml, q.yaml]\n")
    _write(tmp_path, "p.yaml", _repos("a"))
    missing = _real(tmp_path / "q.yaml")
    with pytest.raises(
        ManifestError, match=f"^{re.escape(f'{leaf}: base[1]: {missing}: not found')}$"
    ):
        load_manifest(leaf)


def test_a_parent_that_is_not_utf8_names_the_base_entry(tmp_path):
    (tmp_path / "p.yaml").write_bytes(b"\xff\xfe")
    leaf = _write(tmp_path, "m.yaml", "base: p.yaml\n")
    with pytest.raises(ManifestError, match="m.yaml: base: .*p.yaml: cannot be read as UTF-8 text"):
        load_manifest(leaf)


def test_a_manifest_given_as_text_cannot_read_base():
    with pytest.raises(ManifestError, match="m.yaml: base: this version of the tool cannot read"):
        base.parse_manifest("base: p.yaml\n", "m.yaml")


# --- The order of reading, each manifest once, cycles ----------------------------------------


def _diamond(tmp_path):
    c = _write(tmp_path, "c.yaml", _repos("c"))
    a = _write(tmp_path, "a.yaml", "base: c.yaml\n" + _repos("a"))
    b = _write(tmp_path, "b.yaml", "base: c.yaml\n" + _repos("b"))
    leaf = _write(tmp_path, "m.yaml", "base: [a.yaml, b.yaml]\n" + _repos("m"))
    return c, a, b, leaf


def test_the_diamond_is_read_c_a_b_then_the_manifest_each_once(tmp_path, opened):
    c, a, b, leaf = _diamond(tmp_path)
    m = load_manifest(leaf)
    assert m.bases == [_real(c), _real(a), _real(b)]
    assert list(m.repositories) == ["c", "a", "b", "m"]
    # Each file is opened once: the leaf, then the parents as they are reached.
    assert opened == [_real(leaf), _real(a), _real(c), _real(b)]


def test_a_manifest_that_builds_on_itself_is_refused(tmp_path):
    leaf = _write(tmp_path, "m.yaml", "base: m.yaml\n" + _repos("a"))
    with pytest.raises(
        ManifestError,
        match=f"^{re.escape(f'{leaf}: base: a manifest builds on itself: {leaf} -> {leaf}')}$",
    ):
        load_manifest(leaf, source=str(leaf))


def test_a_manifest_that_builds_on_itself_through_others_is_refused_with_the_chain(tmp_path):
    _write(tmp_path, "a.yaml", "base: b.yaml\n" + _repos("a"))
    _write(tmp_path, "b.yaml", "base: [c.yaml, a.yaml]\n")
    _write(tmp_path, "c.yaml", _repos("c"))
    leaf = _write(tmp_path, "m.yaml", "base: a.yaml\n")
    a, b = _real(tmp_path / "a.yaml"), _real(tmp_path / "b.yaml")
    expected = f"{b}: base[1]: a manifest builds on itself: {a} -> {b} -> {a}"
    with pytest.raises(ManifestError, match=f"^{re.escape(expected)}$"):
        load_manifest(leaf)


def test_a_chain_names_the_manifest_asked_for_as_given(tmp_path, monkeypatch):
    _write(tmp_path, "p.yaml", "base: m.yaml\n" + _repos("a"))
    _write(tmp_path, "m.yaml", "base: p.yaml\n")
    monkeypatch.chdir(tmp_path)
    expected = (
        f"base: a manifest builds on itself: m.yaml -> {_real(tmp_path / 'p.yaml')} -> m.yaml"
    )
    with pytest.raises(ManifestError, match=re.escape(expected)):
        load_manifest("m.yaml")


def _line(tmp_path, count):
    """A chain of `count` manifests: m0 builds on m1, ..., the last has the repo."""
    for index in range(count - 1):
        _write(tmp_path, f"m{index}.yaml", f"base: m{index + 1}.yaml\n")
    _write(tmp_path, f"m{count - 1}.yaml", _repos("a"))
    return tmp_path / "m0.yaml"


def test_a_chain_of_64_manifests_is_read(tmp_path):
    assert len(load_manifest(_line(tmp_path, base.MAX_MANIFESTS)).bases) == 63


def test_more_than_64_manifests_are_refused(tmp_path):
    with pytest.raises(ManifestError, match="m63.yaml: base: .*m64.yaml: more than 64 manifests"):
        load_manifest(_line(tmp_path, base.MAX_MANIFESTS + 1))


def test_the_count_takes_in_every_manifest_read_not_only_one_line(tmp_path):
    names = [f"p{index}.yaml" for index in range(base.MAX_MANIFESTS)]
    for name in names:
        _write(tmp_path, name, _repos(name[:-5]))
    leaf = _write(tmp_path, "m.yaml", f"base: [{', '.join(names)}]\n")
    with pytest.raises(ManifestError, match="base\\[63\\]: .*p63.yaml: more than 64 manifests"):
        load_manifest(leaf)


# --- The checks on each manifest read --------------------------------------------------------


@pytest.mark.parametrize(
    "parent,match",
    [
        ("# a\u200bb\n" + _repos("a"), "line 1, column 4: the file holds U\\+200B"),
        ("layers: [1x]\n" + _repos("a"), "layers\\[0\\]: layer name '1x' is not allowed"),
        ("layers: [Build]\n" + _repos("a"), "layers: a layer cannot be named 'Build'"),
        (
            "repositories:\n  a/../b:\n" + REPO.format(name="a"),
            "repositories: 'a/../b': a repo key",
        ),
        # The key is checked before its entry.
        ("repositories:\n  ../x: 5\n", "repositories: '../x': a repo key has no '..' part"),
        ("repositories:\n  a:\n    type: svn\n", "repositories.a.type: is 'svn'"),
        ("repositories:\n  a:\n    url: 'ext::sh'\n", "repositories.a.url: 'ext::sh'"),
        (
            "repositories:\n  a:\n    version: '-x'\n",
            "repositories.a.version: '-x' starts with '-'",
        ),
        ("format: 2\n" + _repos("a"), "format: is 2"),
        ("repositories: [a]\n", "repositories: must be a mapping"),
        ("layers: [x]\n", "has no `repositories:`"),
        ("roles: {}\n" + _repos("a"), "roles: is empty"),
    ],
)
def test_every_check_on_one_manifest_applies_to_a_parent(tmp_path, parent, match):
    path = _write(tmp_path, "p.yaml", parent)
    leaf = _write(tmp_path, "m.yaml", "base: p.yaml\n" + _repos("m"))
    with pytest.raises(ManifestError, match=f"^{re.escape(_real(path))}: {match}"):
        load_manifest(leaf)


@pytest.mark.parametrize(
    "keys", ["repos: {}\n", "extends: {path: x.yaml}\n", "optional_layers: []\nrepos: {}\n"]
)
def test_a_parent_in_the_earlier_format_is_refused(tmp_path, keys):
    path = _write(tmp_path, "p.yaml", keys)
    leaf = _write(tmp_path, "m.yaml", "base: p.yaml\n" + _repos("m"))
    with pytest.raises(ManifestError, match=f"^{re.escape(_real(path))}: is in the earlier format"):
        load_manifest(leaf)


def test_a_manifest_with_no_base_names_a_bad_repo_key_before_its_entry(tmp_path):
    # As part 1 does: the key's error, not the entry's.
    leaf = _write(tmp_path, "m.yaml", "repositories:\n  ../x: 5\n")
    with pytest.raises(ManifestError, match=r"repositories: '\.\./x': a repo key has no '\.\.'"):
        load_manifest(leaf)


def test_the_old_project11_fixture_as_a_parent_is_refused_as_the_earlier_format(tmp_path):
    # Its `roles:` and `layers:` are in the earlier shape too; the format is named first.
    old = os.path.join(os.path.dirname(__file__), "fixtures", "p11", "manifest.yaml")
    leaf = _write(tmp_path, "m.yaml", f"base: {old}\n" + _repos("m"))
    with pytest.raises(ManifestError, match=f"^{re.escape(_real(old))}: is in the earlier format"):
        load_manifest(leaf)


def test_a_manifest_with_base_and_no_repositories_is_valid(tmp_path):
    _write(tmp_path, "p.yaml", _repos("a"))
    leaf = _write(tmp_path, "m.yaml", "base: p.yaml\n")
    assert list(load_manifest(leaf).repositories) == ["a"]


def test_warnings_of_every_manifest_come_in_reading_order_with_its_name(tmp_path):
    parent = _write(tmp_path, "p.yaml", "colour: blue\n" + _repos("a"))
    leaf = _write(tmp_path, "m.yaml", "base: p.yaml\nsize: 2\n")
    assert load_manifest(leaf).warnings == [
        f"{_real(parent)}: unknown top-level key 'colour' is ignored",
        f"{leaf}: unknown top-level key 'size' is ignored",
    ]


# --- The command -----------------------------------------------------------------------------


def test_a_manifest_with_only_base_goes_to_the_reader_for_this_format(tmp_path, capsys):
    _write(tmp_path, "p.yaml", _repos("a"))
    leaf = _write(tmp_path, "m.yaml", "base: p.yaml\n")
    assert main(["validate", "--manifest", str(leaf)]) == 0
    assert capsys.readouterr().out.endswith(f"{leaf}: valid\n")


def test_resolve_reports_a_problem_in_a_parent_with_the_parents_name(tmp_path, capsys):
    parent = _write(tmp_path, "p.yaml", "repositories:\n  a:\n    type: svn\n")
    leaf = _write(tmp_path, "m.yaml", "base: p.yaml\n")
    assert main(["resolve", "--manifest", str(leaf), "--out", str(tmp_path / "out")]) == 1
    assert capsys.readouterr().err.startswith(f"ERROR: {_real(parent)}: repositories.a.type:")
    assert not (tmp_path / "out").exists()


@pytest.mark.parametrize(
    "text,is_url",
    [
        ("C:foo", True),
        ("host:path", True),
        ("a:b/c.yaml", True),
        ("https://example.org/m.yaml", True),
        ("./a:b.yaml", False),
        ("a/b:c.yaml", False),
        ("p.yaml", False),
    ],
)
def test_one_rule_tells_a_url_from_a_path_for_url_and_base(text, is_url):
    # The url check and `base` share it: a ':' before the first '/' makes a URL.
    from repos_manifest.manifest import _colon_before_slash

    assert _colon_before_slash(text) is is_url
