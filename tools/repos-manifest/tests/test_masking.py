"""A url's user name and password are never printed (``docs/design.md``, "sync"): the user
information is found by parsing the whole url, whatever it holds, and is masked in every line
`sync` prints, its own and git's, and in the errors and refusals of a run."""

import subprocess

import pytest

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
