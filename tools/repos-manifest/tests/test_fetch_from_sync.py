"""`fetch_from` with fallback off, through `init`, `sync` and `status`, on local git repos only:
the published place is `remotes/<name>` (the url the manifest names), and "the field server" is
`field/<name>.git`, a copy of the same repos under another path prefix. No network and no ssh
(``docs/design.md``, "Where repos are fetched from").

A new system made with `init --fetch-from` clones from the field server. An existing system
gets the key by an edit of `config.yaml`, and the next `sync` moves each clone's `origin` by the
url rule: a clean clone is repointed, a clone with commits the server lacks keeps its origin and
is left alone with the two ways on, an unreachable place keeps origin and fails the repo."""

import json
import shlex
import shutil
import subprocess
from pathlib import Path
from types import SimpleNamespace

import pytest
import yaml

from helpers import (
    commit_file,
    git,
    head,
    make_remote,
    repo,
    run,
    snapshot_repo,
    state_of,
    write_manifest,
)
from repos_manifest.selection import Selected
from repos_manifest.update import _repoint_steps, built_url_note, push_to_place


def _origin(clone):
    return git("config", "--get", "remote.origin.url", cwd=clone)


def _copy(remote, place, name="a"):
    """A bare copy of `remote` at `place/<name>.git`: the same repo at another place."""
    place.mkdir(parents=True, exist_ok=True)
    copy = place / f"{name}.git"
    git("clone", "-q", "--bare", str(remote), str(copy))
    return copy


def _set_fetch_from(system, prefix):
    """The hand edit of `config.yaml` an existing system gets the key by (no command)."""
    config = system / ".repos-manifest/config.yaml"
    data = yaml.safe_load(config.read_text())
    if prefix is None:
        data.pop("fetch_from", None)
    else:
        data["fetch_from"] = {"prefix": str(prefix)}
    config.write_text(yaml.safe_dump(data, sort_keys=False))


def _sync(system, capsys, expect=0):
    capsys.readouterr()
    assert run(system, "sync") == expect
    return capsys.readouterr().out


def _status(system, capsys):
    capsys.readouterr()
    run(system, "status", "--json")
    (found,) = json.loads(capsys.readouterr().out)["distros"][0]["repos"]
    return found


def _manifest(tmp_path, repositories, **top):
    return write_manifest(
        tmp_path / "m.manifest.yaml", {"format": 1, **top, "repositories": repositories}
    )


@pytest.fixture
def published(vcs, tmp_path):
    """The published repo `remotes/a` and a manifest naming it; the field server's copy."""
    remote = make_remote(tmp_path / "remotes", "a", branches=["dev"])
    manifest = _manifest(tmp_path, {"a": repo(remote, "main")})
    field = tmp_path / "field"
    _copy(remote, field)
    return tmp_path, remote, manifest, field


@pytest.fixture
def existing(published, capsys):
    """A system made without `fetch_from`, so each clone's origin is the published url."""
    tmp_path, remote, manifest, field = published
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    capsys.readouterr()
    return system, remote, manifest, field, system / "src" / "a"


# --- A new system ----------------------------------------------------------------------------


def test_init_with_fetch_from_clones_every_repo_from_the_place(published, capsys):
    tmp_path, remote, manifest, field = published
    text = manifest.read_text()
    system = tmp_path / "sys"
    system.mkdir()
    argv = ["init", "../m.manifest.yaml", "--fetch-from", f"{field}/", "--yes"]
    assert run(system, *argv) == 0
    out = capsys.readouterr().out
    clone = system / "src/a"
    assert _origin(clone) == f"{field}/a.git"
    assert state_of(system)["a"]["url"] == f"{field}/a.git"
    assert f"fetch from  {field}/\n" in out and f"{field}/a.git" in out
    resolved = (system / ".repos-manifest/resolved/_unnamed.repos").read_text()
    assert f"url: {field}/a.git" in resolved and f"# fetch from: {field}/\n" in resolved
    config = yaml.safe_load((system / ".repos-manifest/config.yaml").read_text())
    assert config["fetch_from"] == {"prefix": f"{field}/", "fallback": False}
    assert manifest.read_text() == text
    # A second sync is quiet.
    out = _sync(system, capsys)
    assert "up to date (1)" in out and "origin" not in out


def test_init_with_a_repo_missing_at_the_place_fails_it_and_leaves_nothing(published, capsys):
    tmp_path, _, _, _ = published
    system = tmp_path / "sys"
    system.mkdir()
    empty = tmp_path / "empty"
    empty.mkdir()
    argv = ["init", "../m.manifest.yaml", "--fetch-from", f"{empty}/", "--yes"]
    assert run(system, *argv) == 1
    out = capsys.readouterr().out
    assert "ERROR: src/a: vcs import exited" in out
    assert not (system / "src/a").exists()


# --- An existing system, the key added by hand -----------------------------------------------


def test_a_clean_clone_is_repointed_and_a_second_sync_is_quiet(existing, capsys):
    system, remote, _, field, clone = existing
    _set_fetch_from(system, f"{field}/")
    found = _status(system, capsys)
    assert found["state"] == "expected"
    assert f"fetch_from now names {field}/a.git" in found["detail"]
    assert "set by hand" not in found["detail"]
    assert found["url"] == str(remote) and found["fetched_from"] == str(remote)
    before = snapshot_repo(clone)
    out = _sync(system, capsys)
    assert f"src/a: origin repointed from {remote} to {field}/a.git" in out
    assert _origin(clone) == f"{field}/a.git"
    assert state_of(system)["a"]["url"] == f"{field}/a.git"
    after = snapshot_repo(clone)
    assert after["files"] == before["files"] and after["head"] == before["head"]
    out = _sync(system, capsys)
    assert "up to date (1)" in out and "origin" not in out
    found = _status(system, capsys)
    assert found["state"] == "expected" and found["fetched_from"] == f"{field}/a.git"
    assert "fetch_from" not in found["detail"] and found["url"] == str(remote)


def test_the_place_is_followed_after_the_repoint(existing, capsys):
    system, _, _, field, clone = existing
    _set_fetch_from(system, f"{field}/")
    work = field.parent / "work"
    git("clone", "-q", str(field / "a.git"), str(work))
    new = commit_file(work, "field-fix", "f\n", "field fix")
    git("push", "-q", "origin", "main", cwd=work)
    out = _sync(system, capsys)
    assert "origin repointed from" in out and "fast-forwarded" in out
    assert head(clone) == new


def test_uncommitted_changes_are_repointed_and_the_repo_left_for_them(existing, capsys):
    system, _, _, field, clone = existing
    _set_fetch_from(system, f"{field}/")
    (clone / "README").write_text("mine\n")
    out = _sync(system, capsys)
    assert "origin repointed from" in out
    assert "src/a: left alone: has uncommitted changes (1 file)" in out
    assert _origin(clone) == f"{field}/a.git"
    assert (clone / "README").read_text() == "mine\n"


def test_commits_not_at_the_place_keep_origin_and_name_the_ways_on(existing, capsys):
    system, remote, _, field, clone = existing
    _set_fetch_from(system, f"{field}/")
    commit_file(clone, "mine", "mine\n", "mine")
    found = _status(system, capsys)
    assert found["state"] == "expected" and "sync tries to repoint origin" in found["detail"]
    # status names the step sync names: a push to the place, not to origin.
    push = f"git -C {clone} push {field}/a.git refs/heads/main:refs/heads/main"
    assert f"to push them there (sync never pushes): {push}" in found["detail"]
    assert "push origin" not in found["detail"]
    before = snapshot_repo(clone)
    recorded = state_of(system)["a"]
    out = _sync(system, capsys)
    assert snapshot_repo(clone) == before
    assert state_of(system)["a"] == recorded
    assert (
        f"src/a: left alone: url changed to {field}/a.git but 1 local commit (branch main) is"
        f" not on it; origin stays {remote}" in out
    )
    assert push in out
    assert f"remote set-url origin {field}/a.git" in out
    assert "left alone (1): src/a" in out
    # Once the commit is at the place, the next sync repoints.
    git("push", "-q", str(field / "a.git"), "main", cwd=clone)
    out = _sync(system, capsys)
    assert "origin repointed from" in out
    assert _origin(clone) == f"{field}/a.git"


def test_a_detached_work_tree_with_commits_not_at_the_place_keeps_origin(existing, capsys):
    system, remote, _, field, clone = existing
    _set_fetch_from(system, f"{field}/")
    git("switch", "-q", "--detach", cwd=clone)
    commit_file(clone, "mine", "mine\n", "mine")
    before = snapshot_repo(clone)
    out = _sync(system, capsys)
    assert snapshot_repo(clone) == before
    assert "1 local commit (the detached HEAD of" in out
    assert f"origin stays {remote}" in out
    assert f"push {field}/a.git <commit>:refs/heads/<a branch>" in out


def test_the_printed_push_names_the_branch_where_a_tag_has_its_name(existing, capsys):
    """A tag `main` here would make `git push <url> main` ambiguous; the command sync prints
    pushes the branch, and the next sync repoints."""
    system, _, _, field, clone = existing
    _set_fetch_from(system, f"{field}/")
    git("tag", "main", "HEAD", cwd=clone)
    commit_file(clone, "mine", "mine\n", "mine")
    out = _sync(system, capsys)
    (line,) = [each for each in out.splitlines() if "push them there first" in each]
    command = line.split("push them there first (", 1)[1].split("), and sync again", 1)[0]
    assert command == f"git -C {clone} push {field}/a.git refs/heads/main:refs/heads/main"
    subprocess.run(shlex.split(command), check=True, capture_output=True)
    assert git("rev-parse", "refs/heads/main", cwd=field / "a.git") == head(clone)
    assert "origin repointed from" in _sync(system, capsys)


def test_a_masked_url_in_the_push_says_where_the_whole_url_is():
    url = "https://field-user:s3cret@git.example.org/field/a.git"
    for_branch = push_to_place(Path("/s/src/a"), url, "main")
    assert for_branch == (
        "git -C /s/src/a push 'https://***@git.example.org/field/a.git'"
        " refs/heads/main:refs/heads/main"
    )
    assert push_to_place(Path("/s/src/a"), url, None).endswith(" <commit>:refs/heads/<a branch>")
    note = built_url_note(url, "a")
    assert note == " (with the url of a as fetch_from builds it in place of the one shown)"
    assert built_url_note("git@gitcloud:field/a.git", "a") == ""
    selected = Selected("a", "git", url, "main", False, "m.yaml", published="https://h/o/a.git")
    git_here = SimpleNamespace(place=Path("/s/src/a"))
    steps = _repoint_steps(git_here, selected, ["branch main", "the detached HEAD of /s/w"])
    assert steps.count(note) == 1
    assert "s3cret" not in steps and "field-user" not in steps
    assert "refs/heads/main:refs/heads/main && git -C /s/src/a push" in steps


def test_an_origin_already_at_the_place_is_left_and_recorded(existing, capsys):
    system, _, _, field, clone = existing
    git("remote", "set-url", "origin", f"{field}/a.git", cwd=clone)
    _set_fetch_from(system, f"{field}/")
    found = _status(system, capsys)
    assert found["state"] == "expected" and "fetch_from" not in found["detail"]
    before = snapshot_repo(clone, fetched=True)
    out = _sync(system, capsys)
    assert "origin" not in out and "up to date (1)" in out
    assert snapshot_repo(clone, fetched=True) == before
    assert state_of(system)["a"]["url"] == f"{field}/a.git"


def test_an_origin_set_by_hand_elsewhere_is_left_as_set(existing, capsys):
    system, remote, _, field, clone = existing
    mine = _copy(remote, field.parent / "mine")
    git("remote", "set-url", "origin", str(mine), cwd=clone)
    _set_fetch_from(system, f"{field}/")
    found = _status(system, capsys)
    assert (
        f"set by hand; fetch_from names {field}/a.git (the manifest says {remote}), and sync"
        " leaves origin as it is" in found["detail"]
    )
    for _ in range(2):
        out = _sync(system, capsys)
        assert (
            f"src/a: origin is {mine}, fetch_from names {field}/a.git (the manifest says"
            f" {remote}); left as set (to use it:" in out
        )
        assert _origin(clone) == str(mine)


@pytest.mark.parametrize("optional", [False, True], ids=["required", "optional"])
@pytest.mark.parametrize("kind", ["no such path", "not a repo"])
def test_a_place_that_cannot_be_fetched_keeps_origin_and_fails(
    vcs, tmp_path, capsys, kind, optional
):
    remote = make_remote(tmp_path / "remotes", "a")
    _manifest(tmp_path, {"a": repo(remote, "main", optional=optional)})
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../m.manifest.yaml", "--yes") == 0
    clone = system / "src/a"
    place = tmp_path / "field"
    if kind == "not a repo":
        (place / "a.git").mkdir(parents=True)
    _set_fetch_from(system, f"{place}/")
    before = snapshot_repo(clone)
    recorded = state_of(system)["a"]
    assert recorded["url"] == str(remote)
    out = _sync(system, capsys, 0 if optional else 1)
    assert snapshot_repo(clone) == before
    assert _origin(clone) == str(remote)
    assert (
        f"the url to fetch from changed to {place}/a.git, and fetching from it failed (origin"
        f" stays {remote})" in out
    )
    if optional:
        assert "optional, skipped (1): src/a" in out
    else:
        assert "failed (1): src/a" in out and "run `repos-manifest sync` to finish" in out
    # The record keeps the url origin still has, so the clone is not taken for one set by
    # hand: once the place exists, the next sync repoints it.
    assert state_of(system)["a"] == recorded
    shutil.rmtree(place / "a.git", ignore_errors=True)
    _copy(remote, place)
    out = _sync(system, capsys)
    assert f"origin repointed from {remote} to {place}/a.git" in out
    assert _origin(clone) == f"{place}/a.git"
    assert state_of(system)["a"]["url"] == f"{place}/a.git"


def test_a_remote_of_the_probes_name_keeps_origin(existing, capsys):
    system, remote, _, field, clone = existing
    git("remote", "add", "repos-manifest-probe", str(remote), cwd=clone)
    _set_fetch_from(system, f"{field}/")
    out = _sync(system, capsys)
    assert "a remote named repos-manifest-probe is set here" in out
    assert _origin(clone) == str(remote)


def test_a_record_with_no_url_is_repointed(existing, capsys):
    system, remote, _, field, clone = existing
    state = system / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    del data["distros"]["_unnamed"]["repos"]["a"]["url"]
    state.write_text(yaml.safe_dump(data))
    _set_fetch_from(system, f"{field}/")
    found = _status(system, capsys)
    assert "the url recorded; fetch_from now names" in found["detail"]
    out = _sync(system, capsys)
    assert f"origin repointed from {remote} to {field}/a.git" in out
    assert state_of(system)["a"]["url"] == f"{field}/a.git"


def test_a_changed_prefix_repoints_again(existing, capsys):
    system, _, _, field, clone = existing
    _set_fetch_from(system, f"{field}/")
    _sync(system, capsys)
    other = _copy(field / "a.git", field.parent / "field2")
    _set_fetch_from(system, f"{other.parent}/")
    out = _sync(system, capsys)
    assert f"origin repointed from {field}/a.git to {other}" in out
    assert _origin(clone) == str(other)


def test_removing_fetch_from_repoints_back_unless_commits_are_only_at_the_place(existing, capsys):
    system, remote, _, field, clone = existing
    _set_fetch_from(system, f"{field}/")
    _sync(system, capsys)
    # A commit pushed to the place only: removing the key does not abandon it.
    commit_file(clone, "field-only", "f\n", "field only")
    git("push", "-q", "origin", "main", cwd=clone)
    _set_fetch_from(system, None)
    before = snapshot_repo(clone)
    out = _sync(system, capsys)
    assert snapshot_repo(clone) == before
    assert f"url changed to {remote} but 1 local commit (branch main) is not on it" in out
    assert _origin(clone) == f"{field}/a.git"
    # The published repo gets it; then the clone goes back.
    git("push", "-q", str(remote), "main:refs/heads/field", cwd=clone)
    git("switch", "-q", "main", cwd=remote)
    git("merge", "-q", "--ff-only", "field", cwd=remote)
    out = _sync(system, capsys)
    assert f"origin repointed from {field}/a.git to {remote}" in out
    assert state_of(system)["a"]["url"] == str(remote)


def test_an_origin_spelled_otherwise_with_unpushed_commits_is_left_on_every_run(existing, capsys):
    """The same place in two spellings (a path, and a `file://` url, standing for
    `git@host:field/x.git` and `ssh://git@host/field/x.git`) is two urls to this version: a
    clone recorded in one, with a commit not pushed, is left alone on every run."""
    system, _, _, field, clone = existing
    _set_fetch_from(system, f"{field}/")
    _sync(system, capsys)
    _set_fetch_from(system, f"file://{field}/")
    commit_file(clone, "mine", "mine\n", "mine")
    for _ in range(2):
        before = snapshot_repo(clone)
        out = _sync(system, capsys)
        assert snapshot_repo(clone) == before
        assert (
            f"left alone: url changed to file://{field}/a.git but 1 local commit (branch main)"
            f" is not on it; origin stays {field}/a.git" in out
        )


def test_a_repo_named_otherwise_on_the_server_fails_loudly_and_keeps_origin(existing, capsys):
    system, remote, _, field, clone = existing
    (field / "a.git").rename(field / "a-renamed.git")
    _set_fetch_from(system, f"{field}/")
    out = _sync(system, capsys, 1)
    assert f"fetching from it failed (origin stays {remote})" in out
    assert _origin(clone) == str(remote)


def test_a_field_system_from_a_hand_made_copy_switched_in_one_edit_moves_nothing(published, capsys):
    """A field system set up from a hand-made copy of the manifest naming the server's urls,
    then pointed at the published manifest and given `fetch_from` in one edit: origin is the
    place already, so nothing moves and `status` names no repoint."""
    tmp_path, remote, manifest, field = published
    copy = _manifest(tmp_path, {"a": repo(field / "a.git", "main")})
    copy = copy.rename(tmp_path / "copy.manifest.yaml")
    manifest = _manifest(tmp_path, {"a": repo(remote, "main")})
    system = tmp_path / "sys"
    system.mkdir()
    assert run(system, "init", "../copy.manifest.yaml", "--yes") == 0
    clone = system / "src/a"
    assert _origin(clone) == f"{field}/a.git"
    config = system / ".repos-manifest/config.yaml"
    data = yaml.safe_load(config.read_text())
    data["manifest"] = f"../{manifest.name}"
    data["fetch_from"] = {"prefix": f"{field}/"}
    config.write_text(yaml.safe_dump(data, sort_keys=False))
    found = _status(system, capsys)
    assert found["state"] == "expected" and "repoint" not in found["detail"]
    before = snapshot_repo(clone, fetched=True)
    out = _sync(system, capsys)
    assert "origin" not in out and "up to date (1)" in out
    assert snapshot_repo(clone, fetched=True) == before


def test_each_distro_is_repointed(vcs, tmp_path, capsys):
    remote = make_remote(tmp_path / "remotes", "a")
    _manifest(tmp_path, {"a": repo(remote, "main")}, distros=["jazzy", "rolling"])
    field = tmp_path / "field"
    _copy(remote, field)
    system = tmp_path / "sys"
    system.mkdir()
    argv = ["init", "../m.manifest.yaml", "--distro-dirs", "--distro", "jazzy"]
    assert run(system, *argv, "--distro", "rolling", "--yes") == 0
    _set_fetch_from(system, f"{field}/")
    out = _sync(system, capsys)
    for distro in ("jazzy", "rolling"):
        assert f"{distro}/src/a: origin repointed from {remote} to {field}/a.git" in out
        assert _origin(system / distro / "src/a") == f"{field}/a.git"
        assert state_of(system, distro)["a"]["url"] == f"{field}/a.git"


def test_a_new_repo_in_an_existing_system_is_cloned_from_the_place(existing, capsys):
    system, _, manifest, field, _ = existing
    other = make_remote(field.parent / "remotes", "b")
    _copy(other, field, "b")
    data = yaml.safe_load(manifest.read_text())
    data["repositories"]["b"] = repo(other, "main")
    write_manifest(manifest, data)
    _set_fetch_from(system, f"{field}/")
    _sync(system, capsys)
    assert _origin(system / "src/b") == f"{field}/b.git"
    shutil.rmtree(field / "b.git")
    shutil.rmtree(system / "src/b")
    out = _sync(system, capsys, 1)
    assert "ERROR: src/b: vcs import exited" in out and not (system / "src/b").exists()
