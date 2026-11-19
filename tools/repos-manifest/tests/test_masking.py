"""A url's user name and password are never printed (``docs/design.md``, "sync"): the user
information is found by parsing the whole url, whatever it holds, and is masked in every line
`sync` prints, its own and git's, and in the errors and refusals of a run."""

import subprocess

import pytest
import yaml

from helpers import git, make_remote, make_system, repo, rewrite_manifest, run
from repos_manifest import masking

# (user, password): quotes, a space, '@', ':', '/', '%' escapes and letters beyond ASCII.
AWKWARD = [
    ("alice", "s3cr'tQ"),
    ("alice", 's3cr"tQ'),
    ("alice", "s3cr tQ"),
    ("al ice", "s3cr@tQ"),
    ("alice", "s3:cr:tQ"),
    ("alice", "s3cr/tQ"),
    ("alice", "s3cr%40tQ"),
    ("élise", "sécrètQ"),
    ("ghp_tokenQ", None),
]


def _url(user, password, host="127.0.0.1:9", path="x.git"):
    info = user if password is None else f"{user}:{password}"
    return f"https://{info}@{host}/{path}"


def _secrets(user, password):
    return [s for s in (user, password) if s] + ([password.replace("%40", "@")] if password else [])


@pytest.mark.parametrize("user, password", AWKWARD)
def test_a_registered_url_is_masked_wherever_it_is_quoted(user, password):
    url = _url(user, password)
    masking.remember_url(url)
    for text in (
        url,
        f"origin is {url}, the manifest says /srv/x",
        f"fatal: unable to access '{url}/': Could not connect",
        f'"{url}"',
    ):
        shown = masking.mask_urls(text)
        assert "https://***@127.0.0.1:9/x.git" in shown, shown
        for secret in _secrets(user, password):
            assert secret not in shown, shown


def test_a_decoded_password_is_masked_too():
    masking.remember_url("https://bob:pa%20ss%27Q@h/x")
    assert masking.mask_urls("https://bob:pa ss'Q@h/x") == "https://***@h/x"


@pytest.mark.parametrize(
    "text, shown",
    [
        ("https://zed:p'q@host/x", "https://***@host/x"),
        ("fatal: 'https://zed:pq@host:443/x' gone", "fatal: 'https://***@host:443/x' gone"),
        ("https://zed:p@q@host/x", "https://***@host/x"),
        ("ssh://git@host/x", "ssh://git@host/x"),
        ("git@github.com:o/x.git", "git@github.com:o/x.git"),
        ("https://host/y and /srv/x", "https://host/y and /srv/x"),
    ],
)
def test_a_url_not_registered_is_masked_by_its_shape(text, shown):
    assert masking.mask_urls(text) == shown


def _system(tmp_path):
    remote = make_remote(tmp_path / "remotes", "a")
    sys_dir, manifest = make_system(tmp_path, {"a": repo(remote, "main")})
    return sys_dir, manifest, remote, sys_dir / "src" / "a"


def _all_output(sys_dir, capsys):
    capsys.readouterr()
    status = run(sys_dir, "sync")
    out = capsys.readouterr()
    return status, out.out + out.err


@pytest.mark.parametrize("user, password", AWKWARD)
def test_a_whole_sync_never_prints_an_origins_credentials(vcs, tmp_path, capsys, user, password):
    """An `origin` set by hand to an unreachable url with credentials: the by-hand line, the
    failed fetch's message and the summary hold neither the user name nor the password."""
    sys_dir, _, _, clone = _system(tmp_path)
    git("remote", "set-url", "origin", _url(user, password), cwd=clone)
    status, out = _all_output(sys_dir, capsys)
    assert status == 1
    assert "origin is https://***@127.0.0.1:9/x.git" in out, out
    for secret in _secrets(user, password):
        assert secret not in out, out


@pytest.mark.parametrize("user, password", AWKWARD)
def test_a_whole_sync_never_prints_a_manifests_credentials(vcs, tmp_path, capsys, user, password):
    """The manifest's url changed to one with credentials: whether the manifest refuses it or
    the repoint's probe fails to fetch it, nothing printed holds them."""
    sys_dir, manifest, _, _ = _system(tmp_path)
    rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(url=_url(user, password)))
    status, out = _all_output(sys_dir, capsys)
    assert status == 1
    assert "***@127.0.0.1:9" in out, out
    for secret in _secrets(user, password):
        assert secret not in out, out


def test_a_hand_set_origin_with_credentials_and_a_manifest_url_with_them(vcs, tmp_path, capsys):
    sys_dir, manifest, remote, clone = _system(tmp_path)
    secret = _url("alice", "p w'Q", host="example.invalid")
    git("config", f"url.{remote}.insteadOf", secret, cwd=clone)
    git("remote", "set-url", "origin", secret, cwd=clone)
    other = _url("bob", 'o"thQ', host="example.invalid", path="y.git")
    rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(url=other))
    status, out = _all_output(sys_dir, capsys)
    for word in ("alice", "p w'Q", "bob", 'o"thQ'):
        assert word not in out, out
    assert "remote set-url origin 'https://***@example.invalid/y.git'" in out, out
    assert status in (0, 1)
    done = subprocess.run(
        ["git", "config", "--get", "remote.origin.url"], cwd=clone, capture_output=True, text=True
    )
    assert done.stdout.strip() == secret


@pytest.mark.parametrize("password", ["s3cr'tQ", "s3cr tQ"])
@pytest.mark.parametrize("command", ["sync", "resolve"])
def test_a_refused_url_is_not_printed_in_the_error(vcs, tmp_path, capsys, password, command):
    """The manifest refuses the url (the <transport>::<address> form): the error, a distro's
    report or the run's, quotes it with its credentials masked."""
    sys_dir, manifest, _, _ = _system(tmp_path)
    bad = f"foo::https://alice:{password}@example.invalid/x.git"
    rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(url=bad))
    capsys.readouterr()
    argv = (
        ["sync"]
        if command == "sync"
        else ["resolve", "--manifest", manifest, "--out", tmp_path / "o"]
    )
    assert run(sys_dir, *argv) == 1
    out = capsys.readouterr()
    text = out.out + out.err
    assert "the <transport>::<address> form is refused" in text, text
    assert password not in text and "alice" not in text, text


# --- What is never masked (round 3) -------------------------------------------------------


def test_a_file_url_whose_path_holds_an_at_masks_nothing(vcs, tmp_path, capsys):
    """A system under a directory named `w@x`, its repo from a `file://` url and an origin set
    by hand to another one: the by-hand line prints both urls and the command whole."""
    root = tmp_path / "w@x"
    remote = make_remote(root / "remotes", "a")
    sys_dir, _ = make_system(root, {"a": repo(f"file://{remote}", "main")})
    clone = sys_dir / "src" / "a"
    other = root / "remotes" / "a2"
    git("clone", "-q", "--bare", str(remote), str(other))
    git("remote", "set-url", "origin", f"file://{other}", cwd=clone)
    status, out = _all_output(sys_dir, capsys)
    assert status == 0, out
    assert "***" not in out, out
    assert (
        f"src/a: origin is file://{other}, the manifest says file://{remote}; left as set (to use"
        f" the manifest's: git -C {clone} remote set-url origin file://{remote})"
    ) in out, out


@pytest.mark.parametrize(
    "registered, text",
    [
        ("https://main@example.org/r.git", "git -C /srv/main@2/src/a switch main"),
        ("https://main@example.org/r.git", "echo origin/main@{upstream}"),
        ("https://git@example.org/r.git", "origin is git@github.com:org/r.git"),
        ("file:///srv/w@x/remotes/a", "git -C /srv/w@x/sys/src/a status"),
        ("git@github.com:org/r.git", "git@github.com:org/r.git"),
    ],
)
def test_what_follows_no_scheme_is_never_masked(registered, text):
    masking.remember_url(registered)
    assert masking.mask_urls(text) == text


@pytest.mark.parametrize("password", ["git", "main", "a"])
def test_a_password_that_is_a_common_word_is_masked_only_in_its_url(password):
    """The registered text is `alice:<password>`, matched only right after `://`: the url is
    masked, and a printed command holding the word, or `<word>@`, is not touched."""
    url = f"https://alice:{password}@example.org/r.git"
    masking.remember_url(url)
    command = f"git -C /srv/{password}@1/src/a switch {password} && echo {password}@{{u}}"
    shown = masking.mask_urls(f"origin is {url}; to fix: {command}")
    assert shown == f"origin is https://***@example.org/r.git; to fix: {command}"


def test_a_registered_user_name_never_masks_an_ssh_url_with_that_name():
    masking.remember_url("https://git@example.org/r.git")
    assert masking.mask_urls("ssh://git@host/x and https://git@example.org/r.git") == (
        "ssh://git@host/x and https://***@example.org/r.git"
    )


# --- Every command, every url key, passwords that repr escapes (round 4) -------------------

ESCAPED = [
    ("aliceQ", "a'b\" cQ"),  # both quotes and a space: repr escapes the quote
    ("aliceQ", "p\\ qQ"),  # a backslash and a space
    ('bo"b q', "x%41%40yQ"),  # % escapes (decoded: "xA@yQ") and a user with a quote
    ("ünïQ", "cødé zQ"),  # letters beyond ASCII
]


def _url_forms(user, password):
    info = f"{user}:{password}"
    return {
        "repo url": f"https://{info}@127.0.0.1:9/x.git",
        "transport form": f"foo::https://{info}@127.0.0.1:9/x.git",
        "ssh with no path": f"ssh://{info}@127.0.0.1:9",
        "file url": f"file://{info}@localhost/nonexistent/x.git",
    }


def _forbidden(user, password):
    words = {user, password, repr(password)[1:-1], repr(user)[1:-1]}
    if "%" in password:
        from urllib.parse import unquote

        words.add(unquote(password))
    return [w for w in words if len(w) > 2]


def _command_output(capsys, cwd, *argv):
    capsys.readouterr()
    run(cwd, *argv)
    out = capsys.readouterr()
    return out.out + out.err


@pytest.mark.parametrize("user, password", ESCAPED)
@pytest.mark.parametrize("form", ["repo url", "transport form", "ssh with no path", "file url"])
def test_no_command_prints_a_password_in_any_url(vcs, tmp_path, capsys, user, password, form):
    url = _url_forms(user, password)[form]
    data = {"format": 1, "repositories": {"a": repo(url, "main")}}
    manifest = tmp_path / "m.manifest.yaml"
    manifest.write_text(yaml.safe_dump(data, allow_unicode=True), encoding="utf-8")
    texts = {
        "resolve": _command_output(
            capsys, tmp_path, "resolve", "--manifest", manifest, "--out", tmp_path / "out"
        ),
        "validate": _command_output(capsys, tmp_path, "validate", "--manifest", manifest),
    }
    (tmp_path / "fresh").mkdir()
    texts["init"] = _command_output(capsys, tmp_path / "fresh", "init", manifest, "--yes")
    sys_dir, good, _, _ = _system(tmp_path / "s")
    rewrite_manifest(good, lambda d: d["repositories"]["a"].update(url=url))
    texts["sync"] = _command_output(capsys, sys_dir, "sync")
    for command, text in texts.items():
        for word in _forbidden(user, password):
            assert word not in text, f"{command} printed {word!r}:\n{text}"


@pytest.mark.parametrize("user, password", ESCAPED)
def test_an_extends_url_of_the_earlier_format_prints_no_password(tmp_path, capsys, user, password):
    url = f"https://{user}:{password}@127.0.0.1:9/base.git"
    leaf = tmp_path / "leaf.yaml"
    leaf.write_text(
        yaml.safe_dump(
            {
                "extends": {"path": "manifest.yaml", "url": url, "ref": "main"},
                "layers": ["core"],
                "roles": {"dev": {}},
            },
            allow_unicode=True,
        ),
        encoding="utf-8",
    )
    for argv in (
        ["resolve", "--manifest", leaf, "--out", tmp_path / "o"],
        ["validate", "--manifest", leaf],
    ):
        argv += ["--role", "dev", "--distro", "jazzy", "--cache-dir", tmp_path / "c"]
        text = _command_output(capsys, tmp_path, *argv)
        for word in _forbidden(user, password):
            assert word not in text, f"{argv[0]} printed {word!r}:\n{text}"


@pytest.mark.parametrize(
    "url, shown",
    [
        ("file://u:SECRETPWQ@localhost/x.git", "file://***@localhost/x.git"),
        ("file:///srv/w@x/remotes/a", "file:///srv/w@x/remotes/a"),
        ("file://bobQ@localhost/x.git", "file://bobQ@localhost/x.git"),
    ],
)
def test_a_file_urls_user_and_password_are_masked_and_its_path_is_not(url, shown):
    assert masking.mask_url(url) == shown
    assert masking.quoted_url(url) == repr(shown)
