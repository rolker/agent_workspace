"""`fetch_from` with fallback off, without a sync: the repo's name and the url built from the
prefix, the checks on the prefix and on each built url, the refusal of two repos of one name,
`config.yaml`'s key, `init --fetch-from` refusing before anything is created, `show` and the
resolved files' head comment (``docs/design.md``, "Where repos are fetched from")."""

import json
import os

import pytest
import yaml

from helpers import git, make_remote, make_system, repo, run, snapshot, write_manifest
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
        "gitcloud:",
        "git@[::1]:",
        "gitcloud:field/",
        "ssh://git@gitcloud/field/",
        "ssh://git@gitcloud:2222/field/",
        "https://git.example.org/field/",
        "https://host/owner/",
        "ssh://git@host/field/",
        "ssh://git@host:2222/field/",
        "file:///srv/mirror/",
        "file://localhost/srv/mirror/",
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
        # A trailing ':' in the [user@]host: form only, with nothing after the host.
        ("/srv/mirror:", "ends in ':' but is not in the [user@]host: form"),
        ("git@host:field:", "ends in ':' but is not in the [user@]host: form"),
        ("host:field:", "ends in ':' but is not in the [user@]host: form"),
        # The url rules read `user` as the host, and `pass@host:` as the path.
        ("user:pass@host:", "ends in ':' but is not in the [user@]host: form"),
        ("./mirror:", "is refused; a url uses"),
        # A scheme with no host: the repo's name would be read as the host.
        ("https://", "has no host, so a repo's name after it would be read as the host"),
        ("http://", "has no host, so a repo's name after it would be read as the host"),
        ("file://", "has no host, so a repo's name after it would be read as the host"),
        # A scheme with an empty host and a path: with a place such as https:///, git takes the
        # first part of the path, here the repo's name, as the host and contacts it; the other
        # forms git refuses itself. The rule refuses them all, so no url with an empty host
        # reaches git.
        ("https:///", "the host is empty"),
        ("https://@/", "the host is empty"),
        ("http://:80/", "the host is empty"),
        ("https:///field/", "the host is empty"),
        # A repo's name must end up in the path, never in a query or a fragment.
        ("https://h/f/?a=/", "holds a '?' or a '#'"),
        ("https://h/f#/", "holds a '?' or a '#'"),
        ("https://h/f/#", "holds a '?' or a '#'"),
        ("git@host:f?x/", "holds a '?' or a '#'"),
        ("/srv/m#x/", "holds a '?' or a '#'"),
        # '%' where the url rules refuse it, with a ':' ending too.
        ("git@%2dhost:", "a '%' in an ssh address is refused"),
        ("git@host:%2d/", "a '%' in an ssh address is refused"),
        ("https://u%40x@host/f/", "a '%' in the user, host or port is refused"),
    ],
)
def test_a_prefix_that_is_not_a_url_prefix_is_refused(prefix, why):
    with pytest.raises(ManifestError) as raised:
        check_prefix(prefix, "--fetch-from")
    assert why in str(raised.value)
    assert str(raised.value).startswith("--fetch-from")


def test_a_prefix_with_an_empty_host_is_refused_without_its_password():
    with pytest.raises(ManifestError) as raised:
        check_prefix("https://user:s3cret@/field/", "--fetch-from")
    assert "the host is empty" in str(raised.value)
    assert "s3cret" not in str(raised.value) and "user" not in str(raised.value)


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


def _in_distro(distro, *repos):
    return Resolved("m.yaml", None, distro, [], [Layer("_unnamed", list(repos))])


def test_two_repos_of_one_name_in_two_distros_of_one_system_are_refused():
    one = _in_distro("one", _repo("a", "https://github.com/one/tools.git"))
    two = _in_distro("two", _repo("b", "https://github.com/two/tools.git"))
    for resolved, system in ((one, [one, two]), (two, [one, two]), (one, [two])):
        with pytest.raises(FetchFromError) as raised:
            apply(resolved, FetchFrom(FIELD), "--fetch-from", system)
        text = str(raised.value)
        assert "a (distro one)" in text and "b (distro two)" in text
        assert "are both named tools" in text


def test_a_distro_that_selects_neither_of_two_repos_of_one_name_is_not_refused():
    one = _in_distro("one", _repo("a", "https://github.com/one/tools.git"))
    two = _in_distro("two", _repo("b", "https://github.com/two/tools.git"))
    three = _in_distro("three", _repo("c", "https://github.com/one/c.git"))
    done = apply(three, FetchFrom(FIELD), "--fetch-from", [one, two, three])
    assert done.layers[0].repos[0].url == "git@gitcloud:field/c.git"


def test_one_published_repo_selected_by_two_distros_is_taken():
    one = _in_distro("one", _repo("a", "https://github.com/one/tools.git"))
    two = _in_distro("two", _repo("a", "https://github.com/one/tools"))
    done = apply(one, FetchFrom(FIELD), "--fetch-from", [one, two])
    assert done.layers[0].repos[0].url == "git@gitcloud:field/tools.git"


def test_a_repo_of_another_distro_that_gives_no_name_is_refused_there_not_here():
    one = _in_distro("one", _repo("a", "https://github.com/one/a.git"))
    two = _in_distro("two", _repo("b", "https://github.com/"))
    assert apply(one, FetchFrom(FIELD), "--fetch-from", [one, two]).fetch_from == FIELD
    with pytest.raises(FetchFromError, match="repo b: its url"):
        apply(two, FetchFrom(FIELD), "--fetch-from", [one, two])


def test_one_repo_listed_twice_with_one_url_is_taken():
    resolved = _resolved(
        _repo("a", "https://github.com/one/tools.git"),
        _repo("b", "https://github.com/one/tools"),
    )
    done = apply(resolved, FetchFrom(FIELD), "--fetch-from")
    assert {r.url for r in done.layers[0].repos} == {"git@gitcloud:field/tools.git"}


@pytest.mark.parametrize("url", ["https://host/owner/..", "/srv/_x", "git@host:o/to?ols"])
def test_a_name_that_cannot_follow_a_prefix_is_refused(url):
    with pytest.raises(FetchFromError, match="not a repo name a prefix can be followed by"):
        apply(_resolved(_repo("a", url)), FetchFrom(FIELD), "--fetch-from")


@pytest.mark.parametrize(
    "url",
    [
        "https://host/o/real.git?x=/other",
        "https://host/o/repo#a/b",
        "https://example.org?target=/tools.git",
        "http://host/o/r.git?x=1",
        "https://user:s3cret@host/o/r.git#x",
    ],
)
def test_an_http_url_with_a_query_or_a_fragment_is_refused(url):
    """A query can change which repo the server gives, so no name is read from such a url."""
    with pytest.raises(FetchFromError, match="with a '\\?' or a '#' is refused"):
        repo_name(url)
    with pytest.raises(FetchFromError) as raised:
        apply(_resolved(_repo("a", url)), FetchFrom(FIELD), "--fetch-from")
    assert "repo a: its url" in str(raised.value) and "s3cret" not in str(raised.value)


@pytest.mark.parametrize(
    "url,name",
    [
        ("ssh://git@host/o/x?y/tools.git", "tools"),
        ("git@host:o/a#b/tools.git", "tools"),
        ("file:///srv/a?b/tools.git", "tools"),
        ("/srv/a#b/tools", "tools"),
    ],
)
def test_a_question_mark_or_a_hash_in_an_ssh_or_file_path_is_part_of_the_path(url, name):
    """git reads these urls' paths literally, '?' and '#' included, and so does the name."""
    assert repo_name(url) == name


@pytest.mark.parametrize(
    "url",
    [
        "https://host/",
        "https://host",
        "https://host:8443/",
        "https://user:pw@host/",
        "ssh://git@host:2222/",
        "file://host",
        "git@host:/",
    ],
)
def test_a_url_with_no_path_after_its_host_gives_no_name(url):
    """The name is never read out of the host, the port or the user information."""
    with pytest.raises(FetchFromError, match="no path after its host"):
        repo_name(url)
    with pytest.raises(FetchFromError, match="repo a: its url .* gives no name"):
        apply(_resolved(_repo("a", url)), FetchFrom(FIELD), "--fetch-from")


@pytest.mark.parametrize("url", ["/srv/b/.git", "git@host:owner/.git", "https://h/o/.git/"])
def test_a_last_path_part_of_dot_git_gives_an_empty_name(url):
    with pytest.raises(FetchFromError, match="leaves the repo's name empty"):
        repo_name(url)


@pytest.mark.parametrize(
    "url",
    [
        "/srv/team:tools.git",
        "https://h/o/foo:bar.git",
        "ssh://git@h/o/foo:bar.git",
        "git@host:o/foo:bar",
        "user:pass@host:repo",
    ],
)
def test_a_colon_in_the_last_path_part_is_part_of_the_name_and_refused(url):
    """git reads the whole last part as the path's last part, so the name is all of it, never
    what follows the ':' (which would fetch another repo); a name with ':' is refused."""
    with pytest.raises(FetchFromError, match="not a repo name a prefix can be followed by"):
        repo_name(url)


@pytest.mark.parametrize(
    "url",
    [
        "https://user:s3cret@host/",
        "https://tok3n@host:8443/",
        "https://user:s3cret@host/o/foo:bar.git",
        "https://user:s3cret@host/o/.git",
    ],
)
def test_a_url_that_gives_no_name_is_not_shown_with_its_password(url):
    with pytest.raises(FetchFromError) as raised:
        apply(_resolved(_repo("a", url)), FetchFrom(FIELD), "--fetch-from")
    text = str(raised.value)
    assert "https://***@host" in text
    assert "s3cret" not in text and "tok3n" not in text and "user" not in text


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
    out = capsys.readouterr().out
    assert "repos a and b are both named tools" in out
    # `status` changes nothing ever, so it does not say what it left unchanged.
    assert "fetch_from refuses it, so status checks none of its repos" in out
    assert "nothing of it has been changed" not in out
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
    # The head's values start in one column, the `fetch from` line's too.
    head_lines = out.split("\n\n", 1)[0].splitlines()
    assert [line.split()[0] for line in head_lines] == ["manifest", "fetch", "role"]
    assert all(line[11] == " " and line[12] != " " for line in head_lines)


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


def _two_distros_two_tools(tmp_path):
    """A manifest with distros one and two, where one selects tools from owner one and two
    selects tools from owner two: two published repos of one name, one in each distro."""
    one = make_remote(tmp_path / "one", "tools")
    two = make_remote(tmp_path / "two", "tools")
    data = {
        "format": 1,
        "distros": ["one", "two"],
        "repositories": {
            "a": {**repo(one, "main"), "distros": {"two": {"absent": True}}},
            "b": {**repo(two, "main"), "distros": {"one": {"absent": True}}},
        },
    }
    return write_manifest(tmp_path / "m.manifest.yaml", data)


DISTRO_DIRS = ["--distro-dirs", "--distro", "one", "--distro", "two"]


def test_init_refuses_two_repos_of_one_name_in_two_distros(vcs, tmp_path, capsys):
    _two_distros_two_tools(tmp_path)
    system = tmp_path / "sys"
    system.mkdir()
    argv = ["init", "../m.manifest.yaml", *DISTRO_DIRS, "--fetch-from", f"{tmp_path}/place/"]
    assert run(system, *argv, "--yes") == 1
    err = capsys.readouterr().err
    assert "--fetch-from: repos a (distro one) and b (distro two) are both named tools" in err
    assert "nothing was set up" in err
    assert os.listdir(system) == []


def test_sync_status_and_show_refuse_two_repos_of_one_name_in_two_distros(vcs, tmp_path, capsys):
    _two_distros_two_tools(tmp_path)
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", *DISTRO_DIRS, "--yes") == 0
    config = system / ".repos-manifest/config.yaml"
    config.write_text(config.read_text() + f"fetch_from:\n  prefix: {tmp_path}/place/\n")
    said = "repos a (distro one) and b (distro two) are both named tools"
    before = {k: v for k, v in snapshot(system).items() if "build-" not in k}
    capsys.readouterr()
    assert run(system, "sync") == 1
    out = capsys.readouterr().out
    assert f"distro one: nothing of it has been changed: `fetch_from` in {config}: {said}" in out
    assert f"distro two: nothing of it has been changed: `fetch_from` in {config}: {said}" in out
    assert {k: v for k, v in snapshot(system).items() if "build-" not in k} == before
    assert run(system, "status") == 1
    assert capsys.readouterr().out.count(said) == 2
    for distro in ("one", "two"):
        assert run(system, "show", "--distro", distro) == 1
        assert said in capsys.readouterr().err


def test_one_published_repo_in_two_distros_is_fetched_from_the_place(vcs, tmp_path, capsys):
    one = make_remote(tmp_path / "one", "tools")
    place = make_remote(tmp_path / "place", "tools.git")
    data = {"format": 1, "distros": ["one", "two"], "repositories": {"a": repo(one, "main")}}
    write_manifest(tmp_path / "m.manifest.yaml", data)
    system = tmp_path / "sys"
    system.mkdir()
    argv = ["init", "../m.manifest.yaml", *DISTRO_DIRS, "--fetch-from", f"{tmp_path}/place/"]
    assert run(system, *argv, "--yes") == 0
    for distro in ("one", "two"):
        origin = git("remote", "get-url", "origin", cwd=system / distro / "src/a").strip()
        assert origin == str(place)
