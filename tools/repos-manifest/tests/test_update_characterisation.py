"""What `sync` says, today, for a repo it leaves at its first checks: written before those checks
were shared with `status` (issue 502, `status` shows what differs from the manifest), and kept
so that the sharing changes none of it. The answers come in a fixed order: not a git repo of
its own, no commit checked out, an operation in progress, `index.lock`, a sparse checkout, not
exactly one `origin`. A `moving` line that names the commit the repo is on adds the stopped-move
text to the in-progress and `index.lock` messages; one that does not is dropped, and only after
the no-commit answer."""

import shutil
import subprocess

import pytest
import yaml

from helpers import commit_file, git, head, make_remote, make_system, repo, run, state_of


@pytest.fixture
def system(vcs, tmp_path):
    """A flat system with repo `a` on main, from a remote with a branch `other`."""
    remote = make_remote(tmp_path / "remotes", "a", branches=["other"])
    sys_dir, _ = make_system(tmp_path, {"a": repo(remote, "main")})
    return sys_dir, remote, sys_dir / "src" / "a"


def _sync(sys_dir, capsys):
    capsys.readouterr()
    assert run(sys_dir, "sync") == 0
    return capsys.readouterr().out


def _set_moving(sys_dir, moving):
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    data["distros"]["_unnamed"]["repos"]["a"]["moving"] = moving
    state.write_text(yaml.safe_dump(data))


def _merge_in_progress(clone):
    """A merge stopped on a conflict, with real git."""
    git("switch", "-q", "-c", "side", cwd=clone)
    commit_file(clone, "README", "side\n", "side")
    git("switch", "-q", "main", cwd=clone)
    commit_file(clone, "README", "main\n", "main")
    done = subprocess.run(["git", "merge", "side"], cwd=clone, capture_output=True, check=False)
    assert done.returncode != 0 and (clone / ".git/MERGE_HEAD").exists()


def _rebase_in_progress(clone):
    base = head(clone)
    git("switch", "-q", "-c", "side", cwd=clone)
    commit_file(clone, "README", "side\n", "side")
    git("switch", "-q", "-c", "topic", base, cwd=clone)
    commit_file(clone, "README", "topic\n", "topic")
    done = subprocess.run(["git", "rebase", "side"], cwd=clone, capture_output=True, check=False)
    assert done.returncode != 0 and (clone / ".git/rebase-merge").exists()


def _stopped(moving):
    return (
        f"a sync was stopped while moving this repo from {moving['from'][:12]} to"
        f" {moving['to'][:12]}; `git status` shows what it left"
    )


@pytest.mark.parametrize("how", ["a merge", "a rebase"])
def test_an_operation_in_progress_carries_the_stopped_move_when_moving_names_head(
    system, capsys, how
):
    sys_dir, remote, clone = system
    if how == "a merge":
        _merge_in_progress(clone)
    else:
        _rebase_in_progress(clone)
    moving = {"from": head(clone), "to": git("rev-parse", "other", cwd=remote)}
    _set_moving(sys_dir, moving)
    out = _sync(sys_dir, capsys)
    assert f"src/a: left alone: {how} is in progress; {_stopped(moving)}\n" in out, out
    assert state_of(sys_dir)["a"]["moving"] == moving


def test_an_index_lock_carries_the_stopped_move_when_moving_names_head(system, capsys):
    sys_dir, remote, clone = system
    (clone / ".git/index.lock").write_text("")
    moving = {"from": git("rev-parse", "other", cwd=remote), "to": head(clone)}
    _set_moving(sys_dir, moving)
    out = _sync(sys_dir, capsys)
    assert (
        "src/a: left alone: index.lock exists; another git may be running here;"
        f" {_stopped(moving)}\n"
    ) in out, out
    assert state_of(sys_dir)["a"]["moving"] == moving


@pytest.mark.parametrize("how", ["a rebase", "a bisect"])
def test_a_moving_line_not_naming_head_is_dropped_with_no_suffix_on_an_operation(
    system, capsys, how
):
    sys_dir, _, clone = system
    if how == "a rebase":
        _rebase_in_progress(clone)
    else:
        git("bisect", "start", cwd=clone)
    _set_moving(sys_dir, {"from": "1" * 40, "to": "2" * 40})
    out = _sync(sys_dir, capsys)
    assert f"src/a: left alone: {how} is in progress\n" in out, out
    assert "a sync was stopped" not in out
    assert "moving" not in state_of(sys_dir)["a"]


def _no_commit(clone):
    """The clone replaced by a git repository with no commit (as a clone of an empty remote)."""
    shutil.rmtree(clone)
    clone.mkdir()
    git("init", "-q", "-b", "main", cwd=clone)


def test_no_commit_checked_out_is_said_before_the_moving_line_is_touched(system, capsys):
    sys_dir, _, clone = system
    _no_commit(clone)
    moving = {"from": "1" * 40, "to": "2" * 40}
    _set_moving(sys_dir, moving)
    out = _sync(sys_dir, capsys)
    assert "src/a: left alone: has no commit checked out\n" in out, out
    assert state_of(sys_dir)["a"]["moving"] == moving


def test_not_a_git_repository_of_its_own_comes_first(system, capsys):
    sys_dir, _, clone = system
    shutil.rmtree(clone)
    clone.mkdir()
    (clone / "file").write_text("x\n")
    _set_moving(sys_dir, {"from": "1" * 40, "to": "2" * 40})
    out = _sync(sys_dir, capsys)
    assert "src/a: left alone: is not a git repository of its own\n" in out, out
    assert "moving" in state_of(sys_dir)["a"]


def test_no_commit_comes_before_an_index_lock(system, capsys):
    sys_dir, _, clone = system
    _no_commit(clone)
    (clone / ".git/index.lock").write_text("")
    assert "src/a: left alone: has no commit checked out\n" in _sync(sys_dir, capsys)


def test_an_operation_in_progress_comes_before_an_index_lock_and_a_sparse_checkout(system, capsys):
    sys_dir, _, clone = system
    git("bisect", "start", cwd=clone)
    (clone / ".git/index.lock").write_text("")
    git("config", "core.sparseCheckout", "true", cwd=clone)
    assert "src/a: left alone: a bisect is in progress\n" in _sync(sys_dir, capsys)


def test_an_index_lock_comes_before_a_sparse_checkout(system, capsys):
    sys_dir, _, clone = system
    git("config", "core.sparseCheckout", "true", cwd=clone)
    (clone / ".git/index.lock").write_text("")
    out = _sync(sys_dir, capsys)
    assert "src/a: left alone: index.lock exists; another git may be running here\n" in out


def test_a_sparse_checkout_comes_before_two_origin_urls(system, capsys, tmp_path):
    sys_dir, _, clone = system
    git("config", "core.sparseCheckout", "true", cwd=clone)
    git("config", "--add", "remote.origin.url", str(tmp_path / "elsewhere"), cwd=clone)
    out = _sync(sys_dir, capsys)
    assert "src/a: left alone: is a sparse checkout; sync does not update one" in out, out


@pytest.mark.parametrize("how", ["two urls", "no url"])
def test_not_exactly_one_origin_url_is_no_single_origin(system, capsys, tmp_path, how):
    sys_dir, _, clone = system
    if how == "two urls":
        git("config", "--add", "remote.origin.url", str(tmp_path / "elsewhere"), cwd=clone)
    else:
        git("config", "--unset-all", "remote.origin.url", cwd=clone)
    assert "src/a: left alone: has no single origin\n" in _sync(sys_dir, capsys)
