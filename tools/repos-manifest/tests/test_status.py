"""`status` (``docs/design.md``, "status"): one state per repo with its facts, the exit status,
the JSON a script reads and the lines a person reads; and that it changes nothing on disk and
asks nothing over the network. The repos are local git repositories made in a temporary
directory (`status_cases.py`)."""

import json
import os
import shutil
import time

import pytest

from helpers import (
    commit_file,
    git,
    head,
    make_remote,
    make_system,
    repo,
    rewrite_manifest,
    run,
    snapshot,
    snapshot_repo,
    state_of,
)
from repos_manifest import update
from status_cases import CASES, FAILING, make_case, set_moving


def _repos_below(top):
    """Each git repository below `top` (not following links), for `snapshot_repo`."""
    found = []
    for directory, dirs, files in os.walk(top):
        if ".git" in dirs or ".git" in files:
            found.append(directory)
        dirs[:] = [d for d in dirs if d != ".git"]
    return found


def status(system, capsys, *args, expect=None, cwd=None):
    """`status --json` in `system` (or `cwd`), checked to change nothing: the whole system
    directory and every clone in it compare equal before and after, after a tracked file's
    time was touched so that a plain `git status` would rewrite the index."""
    for clone in _repos_below(system):
        readme = os.path.join(clone, "README")
        if os.path.isfile(readme) and not os.path.islink(readme):
            later = time.time() + 5
            os.utime(readme, (later, later))
    before = snapshot(system)
    clones = {c: snapshot_repo(c) for c in _repos_below(system)}
    capsys.readouterr()
    code = run(cwd or system, "status", "--json", *args)
    out = capsys.readouterr()
    assert snapshot(system) == before
    assert {c: snapshot_repo(c) for c in _repos_below(system)} == clones
    if expect is not None:
        assert code == expect, out
    return code, json.loads(out.out) if out.out.strip() else None, out.err


def repo_a(doc, distro=0):
    (found,) = [r for r in doc["distros"][distro]["repos"] if r["key"] == "a"]
    return found


@pytest.mark.parametrize("optional", [False, True], ids=["required", "optional"])
@pytest.mark.parametrize("name", list(CASES))
def test_each_state(vcs, tmp_path, capsys, name, optional):
    build, state, says = CASES[name]
    case = make_case(tmp_path, optional=optional)
    build(case)
    code, doc, _ = status(case.system, capsys)
    found = repo_a(doc)
    if optional and state == "missing":
        state = "skipped"
    assert found["state"] == state, found
    assert says in found["detail"], found
    assert found["optional"] is optional
    fails = state in FAILING and not optional
    assert code == (1 if fails else 0)
    assert doc["ok"] is (not fails) and doc["distros"][0]["ok"] is (not fails)
    assert doc["ok"] is (not fails)


def test_the_facts_of_a_repo_on_its_branch(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    _, doc, _ = status(case.system, capsys, expect=0)
    found = repo_a(doc)
    assert found == {
        "key": "a",
        "path": "src/a",
        "layer": found["layer"],
        "optional": False,
        "state": "expected",
        "detail": found["detail"],
        "version": "main",
        "head": head(case.clone),
        "changes": 0,
        "unpushed": 0,
        "behind": 0,
        "stopped_move": False,
        "url": str(case.remote),
        "fetched_from": str(case.remote),
    }


def test_behind_is_counted_as_last_fetched(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    commit_file(case.remote, "one", "1\n")
    commit_file(case.remote, "two", "2\n")
    assert repo_a(status(case.system, capsys)[1])["behind"] == 0  # not fetched yet
    git("fetch", "-q", "origin", cwd=case.clone)
    found = repo_a(status(case.system, capsys)[1])
    assert found["state"] == "expected" and found["behind"] == 2


def test_changes_and_commits_only_here_are_facts_beside_the_state(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    commit_file(case.clone, "mine", "mine\n", "mine")
    (case.clone / "README").write_text("changed\n")
    commit_file(case.remote, "theirs", "t\n")
    git("fetch", "-q", "origin", cwd=case.clone)
    found = repo_a(status(case.system, capsys, expect=0)[1])
    assert (found["state"], found["changes"], found["unpushed"]) == ("expected", 1, 1)
    assert found["behind"] == 1  # counted on the manifest's branch whatever else is there
    assert "pull --rebase" in found["detail"]


def test_a_detached_head_has_no_unpushed_count(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    CASES["a tag on no branch"][0](case)
    found = repo_a(status(case.system, capsys, expect=0)[1])
    assert found["unpushed"] is None and found["changes"] == 0 and found["behind"] is None


@pytest.mark.parametrize("name", ["a merge in progress", "not a git repository", "no commit"])
def test_left_alone_and_unusable_have_no_counts(vcs, tmp_path, capsys, name):
    case = make_case(tmp_path)
    CASES[name][0](case)
    found = repo_a(status(case.system, capsys)[1])
    assert (found["changes"], found["unpushed"], found["behind"]) == (None, None, None)


def test_a_stopped_move_is_a_fact_and_its_text_is_said_once(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    CASES["a stopped move in a merge"][0](case)
    found = repo_a(status(case.system, capsys, expect=0)[1])
    assert found["stopped_move"] is True
    assert found["detail"].count("a sync was stopped") == 1


def test_a_moving_line_that_does_not_name_head_is_not_used_and_not_dropped(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    set_moving(case, {"from": "1" * 40, "to": "2" * 40})
    found = repo_a(status(case.system, capsys, expect=0)[1])
    assert found["stopped_move"] is False and "a sync was stopped" not in found["detail"]
    assert "moving" in state_of(case.system)["a"]


def test_a_url_the_manifest_changed_is_said_to_be_repointed_by_sync(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    copy = tmp_path / "remotes" / "a-copy"
    shutil.copytree(case.remote, copy)

    def change(data):
        data["repositories"]["a"]["url"] = str(copy)

    rewrite_manifest(case.manifest, change)
    found = repo_a(status(case.system, capsys, expect=0)[1])
    assert found["fetched_from"] == str(case.remote) and found["url"] == str(copy)
    assert "the url recorded" in found["detail"]
    assert "sync tries to repoint origin" in found["detail"]


def test_a_probe_remote_with_the_url_changed_is_said_to_stop_sync(vcs, tmp_path, capsys):
    """Must-fix 1 of the first review: `sync` leaves such a repo before its rules, so neither
    the url nor the fast-forward is said to happen."""
    case = make_case(tmp_path)
    CASES["behind, probe remote taken"][0](case)
    found = repo_a(status(case.system, capsys, expect=0)[1])
    assert found["state"] == "expected" and found["behind"] == 1
    assert "fast-forward" not in found["detail"] and "repoint" not in found["detail"]
    assert "sync leaves origin, and the repo, as they are" in found["detail"]


def test_behind_with_changes_is_not_said_to_be_fast_forwarded(vcs, tmp_path, capsys):
    """Must-fix 1 of the first review: `sync` leaves a repo with uncommitted changes before it
    would fast-forward it; the state stays expected."""
    case = make_case(tmp_path)
    CASES["behind, with changes"][0](case)
    found = repo_a(status(case.system, capsys, expect=0)[1])
    assert (found["state"], found["changes"], found["behind"]) == ("expected", 1, 1)
    assert "fast-forward" not in found["detail"]
    assert "sync leaves it while it has uncommitted changes (1 file)" in found["detail"]


def test_a_url_set_by_hand_is_said_and_credentials_are_masked(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    secret = "https://someone:hunter2@example.invalid/a.git"
    git("remote", "set-url", "origin", secret, cwd=case.clone)
    _, doc, _ = status(case.system, capsys, expect=0)
    found = repo_a(doc)
    assert "set by hand" in found["detail"] and "sync leaves origin" in found["detail"]
    assert found["fetched_from"] == "https://***@example.invalid/a.git"
    assert found["state"] == "expected"  # the refs of the last fetch still answer
    capsys.readouterr()
    run(case.system, "status")
    assert "hunter2" not in capsys.readouterr().out
    assert "hunter2" not in json.dumps(doc)


def test_a_repo_no_longer_in_the_manifest_is_listed(vcs, tmp_path, capsys):
    one = make_remote(tmp_path / "remotes", "one")
    two = make_remote(tmp_path / "remotes", "two")
    system, manifest = make_system(tmp_path, {"one": repo(one), "two": repo(two)})
    rewrite_manifest(manifest, lambda d: d["repositories"].pop("two"))
    _, doc, _ = status(system, capsys, expect=0)
    assert doc["distros"][0]["not_in_manifest"] == [{"key": "two", "path": "src/two"}]
    assert [r["key"] for r in doc["distros"][0]["repos"]] == ["one"]
    capsys.readouterr()
    run(system, "status")
    assert "  src/two  not-in-manifest: recorded by sync, still on disk\n" in (
        capsys.readouterr().out
    )


# --- The place --------------------------------------------------------------------------


@pytest.fixture
def keyed(vcs, tmp_path):
    """A flat system with repo `g/b` (key with a directory) and repo `c`."""
    b = make_remote(tmp_path / "remotes", "b")
    c = make_remote(tmp_path / "remotes", "c")
    system, manifest = make_system(tmp_path, {"g/b": repo(b), "c": repo(c)})
    return system, manifest


def _by_key(doc, key):
    (found,) = [r for r in doc["distros"][0]["repos"] if r["key"] == key]
    return found


def test_a_file_on_the_way_is_not_a_directory(keyed, capsys):
    system, _ = keyed
    shutil.rmtree(system / "src/g")
    (system / "src/g").write_text("a file\n")
    _, doc, _ = status(system, capsys, expect=1)
    found = _by_key(doc, "g/b")
    assert found["state"] == "not-a-directory"
    assert "src/g is on the way and is not a directory" in found["detail"]
    capsys.readouterr()
    assert run(system, "sync") == 1  # and `sync` reports it as an error
    assert "  failed (1): src/g/b\n" in capsys.readouterr().out


@pytest.mark.parametrize("where", ["inside", "outside"])
def test_a_link_on_the_way_is_a_blocked_place(keyed, tmp_path, capsys, where):
    system, _ = keyed
    target = system / "elsewhere" if where == "inside" else tmp_path / "outside"
    shutil.move(str(system / "src/g"), str(target))
    (system / "src/g").symlink_to(target)
    _, doc, _ = status(system, capsys, expect=1)
    assert _by_key(doc, "g/b")["state"] == "blocked-place"
    assert _by_key(doc, "c")["state"] == "expected"
    capsys.readouterr()
    assert run(system, "sync") == 1  # and `sync` reports it as an error
    assert "  failed (1): src/g/b\n" in capsys.readouterr().out


def test_a_repo_the_manifest_moved_to_another_layer(vcs, tmp_path, capsys):
    remote = make_remote(tmp_path / "remotes", "a")
    system, manifest = make_system(
        tmp_path, {"a": repo(remote, "main", "core")}, layers=["core", "extra"]
    )
    rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(layer="extra"))
    _, doc, _ = status(system, capsys, expect=1)
    found = repo_a(doc)
    assert found["state"] == "in-other-layer" and found["path"] == "extra/src/a"
    assert "the manifest now has it in layer extra" in found["detail"]
    assert "mv " in found["detail"]
    assert state_of(system)["a"]["layer"] == "core"
    capsys.readouterr()
    assert run(system, "sync") == 1  # and `sync` reports it as an error
    assert "  failed (1): extra/src/a\n" in capsys.readouterr().out


# --- Nothing written, nothing asked over the network ---------------------------------------


def test_status_writes_no_lock_record_or_resolved_file(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    shutil.rmtree(case.system / ".repos-manifest/resolved")
    (case.system / "setup.bash").unlink()
    for lock in (case.system / ".repos-manifest").glob("*.lock"):
        lock.unlink()  # the one `init`'s sync left
    status(case.system, capsys, expect=0)
    assert not os.path.lexists(case.system / ".repos-manifest/resolved")
    assert not os.path.lexists(case.system / "setup.bash")
    assert not list((case.system / ".repos-manifest").glob("*.lock"))
    assert git("for-each-ref", "refs/remotes/repos-manifest-probe/", cwd=case.clone) == ""


def test_status_answers_with_the_remote_gone(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    shutil.move(str(case.remote), str(tmp_path / "gone"))
    found = repo_a(status(case.system, capsys, expect=0)[1])
    assert found["state"] == "expected"


@pytest.mark.parametrize("name", ["on its branch", "pinned at a commit", "pinned at a tag"])
def test_status_runs_no_ls_remote_and_no_fetch(vcs, tmp_path, capsys, monkeypatch, name):
    case = make_case(tmp_path)
    CASES[name][0](case)
    real = update.Git.run

    def refusing(self, *args, **kwargs):
        assert "ls-remote" not in args and "fetch" not in args, args
        return real(self, *args, **kwargs)

    monkeypatch.setattr(update.Git, "run", refusing)
    assert repo_a(status(case.system, capsys, expect=0)[1])["state"] == "expected"


def test_find_version_looks_up_ask_origin_when_it_is_called(vcs, tmp_path, monkeypatch):
    """`ask` is resolved at the call, so a test that replaces `ask_origin` reaches it."""
    case = make_case(tmp_path)
    asked = []

    def fake(git_, *patterns):
        asked.append(patterns)
        return {}, ""

    monkeypatch.setattr(update, "ask_origin", fake)
    git_ = update.Git(case.clone, dict(os.environ), None)
    update.find_version(git_, "main")
    assert asked == [("refs/heads/main", "refs/tags/main")]


def test_ask_local_reads_the_refs_as_ls_remote_gives_them(vcs, tmp_path):
    case = make_case(tmp_path)
    git("tag", "-a", "-m", "annotated", "v2", cwd=case.clone)
    git_ = update.Git(case.clone, dict(os.environ), None)
    theirs, problem = update.ask_local(git_, "refs/heads/*", "refs/tags/*")
    assert problem == ""
    assert theirs["refs/heads/main"] == head(case.clone)
    assert theirs["refs/heads/other"] == git("rev-parse", "origin/other", cwd=case.clone)
    assert "refs/heads/HEAD" not in theirs
    assert theirs["refs/tags/v2^{}"] == head(case.clone)
    assert theirs["refs/tags/v2"] == git("rev-parse", "v2", cwd=case.clone)
    only, _ = update.ask_local(git_, "refs/heads/dev")
    assert list(only) == ["refs/heads/dev"]


# --- Output and exit status ---------------------------------------------------------------


def test_the_json_document(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    _, doc, err = status(case.system, capsys, expect=0)
    assert err == ""
    assert {k: v for k, v in doc.items() if k != "distros"} == {
        "format": 1,
        "ok": True,
        "system": str(case.system),
        "manifest": "../sys.manifest.yaml",
        "role": None,
        "groups": [],
        "layout": "flat",
        "recorded_distros": None,
    }
    (distro,) = doc["distros"]
    assert set(distro) == {"distro", "ok", "problem", "repos", "not_in_manifest"}
    assert (distro["distro"], distro["ok"], distro["problem"]) == (None, True, None)


def test_the_lines_a_person_reads(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    commit_file(case.clone, "mine", "mine\n", "mine")
    (case.clone / "README").write_text("changed\n")
    capsys.readouterr()
    assert run(case.system, "status") == 0
    out = capsys.readouterr().out
    assert out.startswith(f"system {case.system}\nmanifest ../sys.manifest.yaml\n")
    assert "role (none)\ngroups (none)\ndistro (no distro):\n" in out
    assert "  src/a  expected: on main, with 1 commit not on origin;" in out
    assert out.rstrip().endswith("[1 file changed, 1 commit not on origin]")


def test_a_missing_repo_exits_1_and_says_so(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    shutil.rmtree(case.clone)
    capsys.readouterr()
    assert run(case.system, "status") == 1
    assert "  src/a  missing: is not there; sync clones it\n" in capsys.readouterr().out


def test_a_bad_option_is_the_parsers_exit_status_2(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    with pytest.raises(SystemExit) as stopped:
        run(case.system, "status", "--nonsense")
    assert stopped.value.code == 2


def test_outside_a_system_is_an_error(vcs, tmp_path, capsys):
    (tmp_path / "empty").mkdir()
    capsys.readouterr()
    assert run(tmp_path / "empty", "status", "--json") == 1
    out = capsys.readouterr()
    assert out.out == "" and "no system directory" in out.err


def test_an_unreadable_manifest_is_reported_for_each_distro(vcs, tmp_path, capsys):
    case = make_case(tmp_path)
    case.manifest.write_text("format: [\n")
    code, doc, _ = status(case.system, capsys, expect=1)
    (distro,) = doc["distros"]
    assert distro["ok"] is False and "the manifest is what failed" in distro["problem"]
    assert "repos" not in distro and doc["ok"] is False
