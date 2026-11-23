"""`fetch_from` with fallback off, without a sync: the repo's name and the url built from the
prefix, the checks on the prefix and on each built url, the refusal of two repos of one name,
`config.yaml`'s key, `init --fetch-from` refusing before anything is created, `show` and the
resolved files' head comment (``docs/design.md``, "Where repos are fetched from")."""

import json
import os

import pytest
import yaml

from helpers import make_remote, make_system, repo, run, snapshot, write_manifest
from repos_manifest.fetch_from import (
    FetchFrom,
    FetchFromError,
    apply,
    check_prefix,
    effective_url,
    repo_name,
)
from repos_manifest.output import head_comment, output_files
from repos_manifest.selection import Layer, Resolved, Selected
from repos_manifest.system import Config, config_text, read_config
from repos_manifest.yamlload import ManifestError

FIELD = "git@gitcloud:field/"


@pytest.mark.parametrize(
    "url,name",
    [
        ("https://github.com/owner/project11.git", "project11"),
        ("https://github.com/owner/project11", "project11"),
        ("https://github.com/owner/project11/", "project11"),
        ("https://github.com/owner/project11.git/", "project11"),
        ("git@github.com:owner/project11.git", "project11"),
        ("git@github.com:project11.git", "project11"),
        ("ssh://git@host:2222/owner/project11.git", "project11"),
        ("/srv/git/project11.git", "project11"),
        ("file:///srv/git/project11", "project11"),
        ("https://host/owner/a.b-c_d.git", "a.b-c_d"),
    ],
)
def test_the_repo_name_is_the_last_part_of_the_published_url(url, name):
    assert repo_name(url) == name


def test_the_url_is_the_prefix_the_name_and_dot_git():
    assert effective_url(FIELD, "project11") == "git@gitcloud:field/project11.git"
    assert effective_url("git@gitcloud:", "x") == "git@gitcloud:x.git"
    assert effective_url("https://host/field/", "x") == "https://host/field/x.git"


@pytest.mark.parametrize(
    "prefix",
    [
        FIELD,
        "git@gitcloud:",
        "gitcloud:field/",
        "ssh://git@gitcloud/field/",
        "ssh://git@gitcloud:2222/field/",
        "https://git.example.org/field/",
        "file:///srv/mirror/",
        "/srv/mirror/",
    ],
)
def test_a_prefix_a_manifest_url_could_start_with_is_taken(prefix):
    assert check_prefix(prefix, "--fetch-from") == prefix


@pytest.mark.parametrize(
    "prefix,why",
    [
        ("", "is empty, not a url prefix"),
        (["x/"], "is a list, not a url prefix"),
        (3, "is a number, not a url prefix"),
        ("git@gitcloud:field", "does not end in '/', or ':' in the [user@]host: form,"),
        ("https://host:", "does not end in '/' so a repo's name cannot follow it"),
        ("https://host", "does not end in '/' so"),
        ("git@gitcloud/field/", "is refused; a url uses"),
        ("relative/", "is refused; a url uses"),
        ("-oProxyCommand=x/", "starts with '-'"),
        ("ext::sh -c x/", "the <transport>::<address> form is refused"),
        ("fd::3/", "the <transport>::<address> form is refused"),
        ("git://host/field/", "is refused; a url uses"),
        ("ftp://host/field/", "is refused; a url uses"),
        ("ssh://%2dhost/field/", "a '%' in an ssh address is refused"),
        ("https://%2dhost/field/", "a '%' in the user, host or port is refused"),
        ("ssh://-host/field/", "the host starts with '-'"),
        ("ssh:///field/", "the host is empty"),
        ("git@host:o/\nx/", "holds a control or invisible character"),
        ("git@host:field‮/", "holds a control or invisible character"),
        ("git@host:field\t/", "holds a control or invisible character"),
    ],
)
def test_a_prefix_that_is_not_a_url_prefix_is_refused(prefix, why):
    with pytest.raises(ManifestError) as raised:
        check_prefix(prefix, "--fetch-from")
    assert why in str(raised.value)
    assert str(raised.value).startswith("--fetch-from")


def test_a_refused_prefix_is_not_shown_with_its_password():
    with pytest.raises(ManifestError) as raised:
        check_prefix("https://user:s3cret@host:", "--fetch-from")
    assert "s3cret" not in str(raised.value) and "user" not in str(raised.value)
    with pytest.raises(ManifestError) as raised:
        check_prefix("https://user:s3cret@host/a\n/", "--fetch-from")
    assert "s3cret" not in str(raised.value)


def _resolved(*repos):
    return Resolved("m.yaml", None, None, [], [Layer("_unnamed", list(repos))])


def _repo(key, url):
    return Selected(key, "git", url, "main", False, "m.yaml")


def test_apply_builds_each_url_and_keeps_the_published_one():
    resolved = _resolved(
        _repo("a", "https://github.com/one/a.git"), _repo("b", "git@github.com:two/b")
    )
    done = apply(resolved, FetchFrom(FIELD), "--fetch-from")
    (layer,) = done.layers
    assert [(r.url, r.published) for r in layer.repos] == [
        ("git@gitcloud:field/a.git", "https://github.com/one/a.git"),
        ("git@gitcloud:field/b.git", "git@github.com:two/b"),
    ]
    assert done.fetch_from == FIELD
    # The input is not changed.
    assert resolved.layers[0].repos[0].url == "https://github.com/one/a.git"
    assert resolved.fetch_from is None


def test_two_repos_of_one_name_and_different_owners_are_refused():
    resolved = _resolved(
        _repo("a", "https://github.com/one/tools.git"),
        _repo("b", "https://github.com/two/Tools.git"),
    )
    with pytest.raises(FetchFromError) as raised:
        apply(resolved, FetchFrom(FIELD), "`fetch_from` in /s/.repos-manifest/config.yaml")
    text = str(raised.value)
    assert text.startswith("`fetch_from` in /s/.repos-manifest/config.yaml: repos a and b")
    assert "both named Tools" in text


def test_one_repo_listed_twice_with_one_url_is_taken():
    resolved = _resolved(
        _repo("a", "https://github.com/one/tools.git"),
        _repo("b", "https://github.com/one/tools"),
    )
    done = apply(resolved, FetchFrom(FIELD), "--fetch-from")
    assert {r.url for r in done.layers[0].repos} == {"git@gitcloud:field/tools.git"}


@pytest.mark.parametrize(
    "url", ["https://host/owner/..", "git@host:-x", "git@host:owner/.git", "/srv/_x"]
)
def test_a_name_that_cannot_follow_a_prefix_is_refused(url):
    with pytest.raises(FetchFromError, match="not a repo name a prefix can be followed by"):
        apply(_resolved(_repo("a", url)), FetchFrom(FIELD), "--fetch-from")


def test_the_config_key_is_written_and_read_back(tmp_path):
    config = Config("m.yaml", None, [], "flat", None, FetchFrom(FIELD))
    text = config_text(config)
    assert yaml.safe_load(text)["fetch_from"] == {"prefix": FIELD, "fallback": False}
    (tmp_path / ".repos-manifest").mkdir()
    (tmp_path / ".repos-manifest/config.yaml").write_text(text)
    assert read_config(tmp_path) == config


def test_a_missing_fallback_is_false(tmp_path):
    (tmp_path / ".repos-manifest").mkdir()
    (tmp_path / ".repos-manifest/config.yaml").write_text(
        f"manifest: m.yaml\nlayout: flat\nfetch_from:\n  prefix: '{FIELD}'\n"
    )
    assert read_config(tmp_path).fetch_from == FetchFrom(FIELD, False)


def test_a_bad_prefix_in_the_config_names_the_file_and_masks_the_password(tmp_path):
    (tmp_path / ".repos-manifest").mkdir()
    (tmp_path / ".repos-manifest/config.yaml").write_text(
        "manifest: m.yaml\nlayout: flat\nfetch_from: {prefix: 'https://u:s3cret@host:'}\n"
    )
    with pytest.raises(ManifestError) as raised:
        read_config(tmp_path)
    text = str(raised.value)
    assert text.startswith(f"{tmp_path}/.repos-manifest/config.yaml: `fetch_from.prefix`")
    assert "s3cret" not in text


# --- with a system ----------------------------------------------------------------------------


def _manifest(tmp_path, repositories):
    return write_manifest(tmp_path / "m.manifest.yaml", {"format": 1, "repositories": repositories})


@pytest.mark.parametrize(
    "prefix,why",
    [
        ("https://host:", "does not end in '/'"),
        ("ext::sh/", "the <transport>::<address> form is refused"),
        ("git@gitcloud:field", "does not end in"),
    ],
)
def test_init_refuses_a_bad_prefix_before_anything_is_created(vcs, tmp_path, capsys, prefix, why):
    remote = make_remote(tmp_path / "remotes", "a")
    _manifest(tmp_path, {"a": repo(remote, "main")})
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--fetch-from", prefix, "--yes") == 1
    err = capsys.readouterr().err
    assert why in err and "nothing was set up" in err
    assert os.listdir(system) == []


def test_init_refuses_two_repos_of_one_name_before_anything_is_created(vcs, tmp_path, capsys):
    one = make_remote(tmp_path / "one", "tools")
    two = make_remote(tmp_path / "two", "tools")
    _manifest(tmp_path, {"a": repo(one, "main"), "b": repo(two, "main")})
    system = tmp_path / "sys"
    system.mkdir()
    argv = ["init", "../m.manifest.yaml", "--fetch-from", f"{tmp_path}/place/", "--yes"]
    assert run(system, *argv) == 1
    err = capsys.readouterr().err
    assert "--fetch-from: repos a and b are both named tools" in err
    assert "nothing was set up" in err
    assert os.listdir(system) == []


def test_the_same_name_refusal_in_a_system_is_reported_by_sync_and_status(vcs, tmp_path, capsys):
    one = make_remote(tmp_path / "one", "tools")
    system, manifest = make_system(tmp_path, {"a": repo(one, "main")})
    two = make_remote(tmp_path / "two", "tools")
    data = yaml.safe_load(manifest.read_text())
    data["repositories"]["b"] = repo(two, "main")
    write_manifest(manifest, data)
    config = system / ".repos-manifest/config.yaml"
    config.write_text(config.read_text() + f"fetch_from:\n  prefix: {tmp_path}/place/\n")
    before = snapshot(system)
    capsys.readouterr()
    assert run(system, "sync") == 1
    out = capsys.readouterr().out
    assert f"`fetch_from` in {config}: repos a and b are both named tools" in out
    assert "nothing of it has been changed" in out
    assert {k: v for k, v in snapshot(system).items() if "build-" not in k} == {
        k: v for k, v in before.items() if "build-" not in k
    }
    assert run(system, "status") == 1
    assert "repos a and b are both named tools" in capsys.readouterr().out
    assert run(system, "show") == 1
    assert "repos a and b are both named tools" in capsys.readouterr().err


def _system_with_prefix(tmp_path, prefix):
    remote = make_remote(tmp_path / "remotes", "a")
    system, _ = make_system(tmp_path, {"a": repo(remote, "main")})
    config = system / ".repos-manifest/config.yaml"
    config.write_text(config.read_text() + f"fetch_from:\n  prefix: '{prefix}'\n")
    return system, remote


def test_show_prints_the_url_fetched_from_and_the_prefix(vcs, tmp_path, capsys):
    system, remote = _system_with_prefix(tmp_path, FIELD)
    capsys.readouterr()
    assert run(system, "show") == 0
    out = capsys.readouterr().out
    assert "fetch from  git@gitcloud:field/\n" in out
    assert "git@gitcloud:field/a.git" in out
    assert str(remote) not in out


def test_show_and_status_mask_a_password_in_the_prefix(vcs, tmp_path, capsys):
    system, _ = _system_with_prefix(tmp_path, "https://field-user:s3cret@git.example.org/field/")
    capsys.readouterr()
    assert run(system, "show") == 0
    out = capsys.readouterr().out
    assert "fetch from  https://***@git.example.org/field/" in out
    assert "https://***@git.example.org/field/a.git" in out
    run(system, "status", "--json")
    document = capsys.readouterr().out
    run(system, "status")
    text = capsys.readouterr().out
    for said in (out, document, text):
        assert "s3cret" not in said and "field-user" not in said
    (found,) = json.loads(document)["distros"][0]["repos"]
    assert "fetch_from now names https://***@git.example.org/field/a.git" in found["detail"]


def test_the_head_comment_names_the_prefix_masked():
    resolved = apply(
        _resolved(_repo("a", "https://github.com/one/a.git")),
        FetchFrom("https://u:s3cret@git.example.org/field/"),
        "--fetch-from",
    )
    head = head_comment(resolved)
    assert head.splitlines()[-1] == "# fetch from: https://***@git.example.org/field/"
    assert "s3cret" not in head
    files = output_files(resolved)
    assert "url: https://u:s3cret@git.example.org/field/a.git" in files["_unnamed.repos"]
    assert "fetch from" not in head_comment(_resolved(_repo("a", "https://h/o/a.git")))
