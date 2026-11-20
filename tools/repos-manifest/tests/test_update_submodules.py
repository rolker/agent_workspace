"""`sync` and the submodules of a repo that is there (``docs/design.md``, "sync"): a move that
removes a checked-out submodule, puts something else in its place, or changes the pointer of
one a person has moved, leaves the whole repo as it was, the submodule's own HEAD, branches and
files included (`snapshot_repo`'s nested repositories); what does not put a submodule's work at
risk is followed."""

import os
import shutil

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
    snapshot_repo,
    state_of,
)

FILE_ALLOW = ("-c", "protocol.file.allow=always")


def _sync(sys_dir, capsys, expect=0):
    capsys.readouterr()
    assert run(sys_dir, "sync") == expect
    return capsys.readouterr().out


def _top_with_submodule(tmp_path):
    sub = make_remote(tmp_path / "remotes", "sub")
    top = make_remote(tmp_path / "remotes", "top", branches=["dev"])
    git(*FILE_ALLOW, "submodule", "add", "-q", str(sub), "sm", cwd=top)
    git("commit", "-q", "-m", "submodule", cwd=top)
    git("checkout", "-q", "dev", cwd=top)
    git("merge", "-q", "--no-edit", "main", cwd=top)
    git("checkout", "-q", "main", cwd=top)
    return sub, top


def _system(tmp_path, top, version="main"):
    sys_dir, manifest = make_system(tmp_path, {"top": repo(top, version)})
    return sys_dir, manifest, sys_dir / "src" / "top"


def _check_out(clone, sub, how):
    """Put the submodule `sm` in the clone: `init` as `git submodule update --init` does (its
    git directory in the superproject's), `clone` as a person's `git clone` into the place (a
    `.git` directory of its own)."""
    if how == "init":
        git(*FILE_ALLOW, "submodule", "update", "--init", "-q", cwd=clone)
    else:
        os.rmdir(clone / "sm")
        git("clone", "-q", str(sub), str(clone / "sm"))
        git("checkout", "-q", "--detach", git("rev-parse", "HEAD:sm", cwd=clone), cwd=clone / "sm")


def _replace_upstream(top, what, branch):
    """A commit on `branch` of `top` that removes the submodule `sm` or puts `what` there."""
    git("checkout", "-q", branch, cwd=top)
    git("rm", "-q", "sm", cwd=top)
    if what == "a file":
        (top / "sm").write_text("now a file\n")
    elif what == "a directory":
        (top / "sm").mkdir()
        (top / "sm" / "README").write_text("a directory of the superproject\n")
    elif what == "a link":
        os.symlink("elsewhere", top / "sm")
    if what != "nothing":
        git("add", "sm", cwd=top)
    git("commit", "-q", "-m", f"sm replaced by {what}", cwd=top)
    git("checkout", "-q", "-f", "main", cwd=top)


def _left_alone(sys_dir, clone, capsys, says, expect=0):
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    recorded = state_of(sys_dir)["top"]
    out = _sync(sys_dir, capsys, expect)
    assert snapshot_repo(clone, fetched=True) == before
    assert state_of(sys_dir)["top"] == recorded
    assert says in out, out
    return out


@pytest.mark.parametrize("what", ["a file", "a directory", "a link", "nothing"])
@pytest.mark.parametrize("how", ["init", "clone"])
@pytest.mark.parametrize("move", ["fast-forward", "pin change"])
def test_a_submodule_the_move_removes_or_replaces_is_left_with_its_work(
    vcs, tmp_path, capsys, what, how, move
):
    sub, top = _top_with_submodule(tmp_path)
    sys_dir, manifest, clone = _system(tmp_path, top)
    _check_out(clone, sub, how)
    git("checkout", "-q", "-b", "mywork", cwd=clone / "sm")
    mine = commit_file(clone / "sm", "mine.txt", "precious\n", "unpushed work")
    branch = "main" if move == "fast-forward" else "dev"
    _replace_upstream(top, what, branch)
    if move == "pin change":
        rewrite_manifest(manifest, lambda d: d["repositories"]["top"].update(version="dev"))
    out = _left_alone(
        sys_dir,
        clone,
        capsys,
        "src/top: left alone: submodule sm is checked out here, and the move removes it or puts"
        f" something else in its place (to let it go on: move it aside, mv {clone / 'sm'}"
        " <elsewhere>); not updated (a submodule has to be dealt with by hand, then sync again)",
    )
    assert "updated" not in out.replace("not updated", "")
    assert git("rev-parse", "mywork", cwd=clone / "sm") == mine


@pytest.mark.parametrize("what", ["a file", "nothing"])
def test_a_submodule_that_is_not_checked_out_is_no_obstacle(vcs, tmp_path, capsys, what):
    _, top = _top_with_submodule(tmp_path)
    sys_dir, _, clone = _system(tmp_path, top)
    assert not os.listdir(clone / "sm")
    _replace_upstream(top, what, "main")
    out = _sync(sys_dir, capsys)
    assert "src/top: fast-forwarded 1 commit" in out
    assert head(clone) == git("rev-parse", "main", cwd=top)
    assert (clone / "sm").is_file() if what == "a file" else not os.path.lexists(clone / "sm")


def _move_pointer(sub, top, branch="main"):
    commit_file(sub, "new", f"after {head(sub)}\n", "new in sub")
    git("checkout", "-q", branch, cwd=top)
    git("-C", "sm", "pull", "-q", "origin", "main", cwd=top)
    git("commit", "-q", "-am", "move the pointer", cwd=top)
    git("checkout", "-q", "-f", "main", cwd=top)


@pytest.mark.parametrize("how", ["init", "clone"])
@pytest.mark.parametrize("where", ["a commit of a person's", "a branch of a person's"])
def test_a_submodule_a_person_moved_stops_a_move_of_its_pointer(vcs, tmp_path, capsys, how, where):
    sub, top = _top_with_submodule(tmp_path)
    sys_dir, _, clone = _system(tmp_path, top)
    _check_out(clone, sub, how)
    if where == "a branch of a person's":
        git("checkout", "-q", "-b", "mywork", cwd=clone / "sm")
    mine = commit_file(clone / "sm", "mine.txt", "precious\n", "unpushed work")
    _move_pointer(sub, top)
    recorded = git("rev-parse", "HEAD:sm", cwd=clone)
    _left_alone(
        sys_dir,
        clone,
        capsys,
        f"src/top: left alone: submodule sm is on {mine[:12]}, not on {recorded[:12]}, the commit"
        " recorded here, and the move changes that commit (when it holds nothing of yours: git"
        f" -C {clone} submodule update -- sm); not updated",
    )
    assert head(clone / "sm") == mine


def test_a_submodule_on_its_recorded_commit_with_untracked_files_is_followed(vcs, tmp_path, capsys):
    sub, top = _top_with_submodule(tmp_path)
    sys_dir, _, clone = _system(tmp_path, top)
    _check_out(clone, sub, "init")
    (clone / "sm" / "notes.txt").write_text("a person's untracked file\n")
    before = snapshot_repo(clone)["nested repositories"]
    _move_pointer(sub, top)
    out = _sync(sys_dir, capsys)
    assert "src/top: fast-forwarded 1 commit" in out
    assert "src/top: submodules not updated" in out
    assert snapshot_repo(clone)["nested repositories"] == before
    assert (clone / "sm" / "notes.txt").read_text() == "a person's untracked file\n"


def test_a_submodule_left_behind_by_an_earlier_sync_stops_the_next_pointer_move(
    vcs, tmp_path, capsys
):
    """`sync` does not update submodules: after it moved the pointer, the submodule is on the
    old commit; a later pointer move is then left to a person, never made over it."""
    sub, top = _top_with_submodule(tmp_path)
    sys_dir, _, clone = _system(tmp_path, top)
    _check_out(clone, sub, "init")
    old = head(clone / "sm")
    _move_pointer(sub, top)
    assert "fast-forwarded 1 commit" in _sync(sys_dir, capsys)
    _move_pointer(sub, top)
    _left_alone(sys_dir, clone, capsys, f"submodule sm is on {old[:12]}, not on")
    # The command the report gives lets the next sync follow.
    git(*FILE_ALLOW, "submodule", "update", "-q", "--", "sm", cwd=clone)
    assert "fast-forwarded 1 commit" in _sync(sys_dir, capsys)


def test_a_tracked_file_replaced_by_a_submodule_is_followed(vcs, tmp_path, capsys):
    sub = make_remote(tmp_path / "remotes", "sub")
    top = make_remote(tmp_path / "remotes", "top")
    commit_file(top, "sm", "a file first\n", "sm is a file")
    sys_dir, _, clone = _system(tmp_path, top)
    git("rm", "-q", "sm", cwd=top)
    git(*FILE_ALLOW, "submodule", "add", "-q", str(sub), "sm", cwd=top)
    git("commit", "-q", "-m", "sm becomes a submodule", cwd=top)
    out = _sync(sys_dir, capsys)
    assert "src/top: fast-forwarded 1 commit" in out
    assert (clone / "sm").is_dir() and not os.listdir(clone / "sm")


def test_a_directory_with_an_ignored_file_replaced_by_a_submodule_is_left(vcs, tmp_path, capsys):
    sub = make_remote(tmp_path / "remotes", "sub")
    top = make_remote(tmp_path / "remotes", "top")
    commit_file(top, ".gitignore", "*.log\n", "ignore")
    commit_file(top, "sm/a", "tracked\n", "sm is a directory")
    sys_dir, _, clone = _system(tmp_path, top)
    (clone / "sm" / "keep.log").write_text("a person's ignored file\n")
    git("rm", "-q", "-r", "sm", cwd=top)
    shutil.rmtree(top / "sm", ignore_errors=True)
    git(*FILE_ALLOW, "submodule", "add", "-q", str(sub), "sm", cwd=top)
    git("commit", "-q", "-m", "sm becomes a submodule", cwd=top)
    _left_alone(sys_dir, clone, capsys, "in the way of incoming files: sm")
    assert (clone / "sm" / "keep.log").is_file()


@pytest.mark.parametrize("setting", ["fetch.recurseSubmodules=true", "submodule.recurse=true"])
def test_the_fetch_never_goes_into_a_submodule(vcs, tmp_path, capsys, monkeypatch, setting):
    monkeypatch.setenv("GIT_ALLOW_PROTOCOL", "file")
    sub, top = _top_with_submodule(tmp_path)
    sys_dir, _, clone = _system(tmp_path, top)
    _check_out(clone, sub, "init")
    key, value = setting.split("=")
    git("config", key, value, cwd=clone)
    before = snapshot_repo(clone)["nested repositories"]
    _move_pointer(sub, top)
    out = _sync(sys_dir, capsys)
    assert "src/top: fast-forwarded 1 commit" in out
    assert snapshot_repo(clone)["nested repositories"] == before
