"""`sync` for a repo that is there, rule by rule (``docs/design.md``, "sync"): a clean clone on
the manifest's version is followed; one on the recorded version is moved to the manifest's new
one; anything a person did (changes, commits, another branch, an operation in progress, an
`origin` of their own) is left as it is and reported, and the repo compares equal, whole, before
and after (`snapshot_repo`)."""

import hashlib
import os
import subprocess
from pathlib import Path

import pytest
import yaml

from helpers import (
    branch,
    commit_file,
    git,
    head,
    make_remote,
    make_system,
    push_commit,
    repo,
    rewrite_manifest,
    run,
    snapshot_repo,
    state_of,
)
from repos_manifest import update
from repos_manifest.selection import Selected


@pytest.fixture
def system(vcs, tmp_path):
    """A flat system with repo `a` on main from a remote with branches dev and other and a tag
    v1; the clone has an ignored file and a linked work tree (on a branch `feature`) outside
    the system."""
    remote = make_remote(tmp_path / "remotes", "a", branches=["dev", "other"], tags=["v1"])
    commit_file(remote, ".gitignore", "*.log\n", "ignore")
    sys_dir, manifest = make_system(tmp_path, {"a": repo(remote, "main")})
    clone = sys_dir / "src" / "a"
    (clone / "local.log").write_text("a person's ignored file\n")
    git("worktree", "add", "-q", "-b", "feature", str(tmp_path / "wt-a"), cwd=clone)
    return sys_dir, manifest, remote, clone


def _pin(manifest, version, key="a"):
    def change(data):
        if version is None:
            data["repositories"][key].pop("version", None)
        else:
            data["repositories"][key]["version"] = version

    rewrite_manifest(manifest, change)


def _sync(sys_dir, capsys, expect=0):
    capsys.readouterr()
    assert run(sys_dir, "sync") == expect
    return capsys.readouterr().out


def _left_alone(sys_dir, clone, capsys, says, fetched=True, expect=0):
    """`sync` leaves the clone exactly as it was and says `says`; the record is unchanged."""
    if fetched:
        git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=fetched)
    recorded = state_of(sys_dir)["a"]
    out = _sync(sys_dir, capsys, expect)
    assert snapshot_repo(clone, fetched=fetched) == before
    assert state_of(sys_dir)["a"] == recorded
    assert says in out, out
    return out


# --- Followed --------------------------------------------------------------------------------


def test_a_clean_clone_on_its_branch_is_fast_forwarded_and_recorded(system, capsys):
    sys_dir, _, remote, clone = system
    push_commit(remote, "one", "1\n")
    new = push_commit(remote, "two", "2\n")
    out = _sync(sys_dir, capsys)
    assert "src/a: fast-forwarded 2 commits\n" in out
    assert "  updated (1): src/a\n" in out
    assert head(clone) == new and branch(clone) == "main"
    assert state_of(sys_dir)["a"]["commit"] == new
    assert "moving" not in state_of(sys_dir)["a"]
    assert (clone / "local.log").read_text() == "a person's ignored file\n"
    assert _sync(sys_dir, capsys) == "distro (no distro):\n  up to date (1)\n"


def test_a_clone_with_no_record_on_the_version_is_followed_and_recorded(system, capsys):
    sys_dir, _, remote, clone = system
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    data["distros"]["_unnamed"]["repos"] = {}
    state.write_text(yaml.safe_dump(data))
    new = push_commit(remote, "one", "1\n")
    assert "fast-forwarded 1 commit" in _sync(sys_dir, capsys)
    assert state_of(sys_dir)["a"] == {
        "layer": "_unnamed",
        "version": "main",
        "commit": new,
        "url": str(remote),
    }


def test_no_version_follows_origins_default_branch(vcs, tmp_path, capsys):
    remote = make_remote(tmp_path / "remotes", "a")
    sys_dir, _ = make_system(tmp_path, {"a": repo(remote)})
    new = push_commit(remote, "one", "1\n")
    assert "fast-forwarded 1 commit" in _sync(sys_dir, capsys)
    assert head(sys_dir / "src/a") == new


@pytest.mark.parametrize("old", ["kept", "deleted"])
def test_no_version_when_origins_default_branch_changes(vcs, tmp_path, capsys, old):
    """The default branch is the one the clone records (origin/HEAD, set at the clone); the
    fetch does not move it. The clone stays on its branch, and is never switched by `sync`."""
    remote = make_remote(tmp_path / "remotes", "a", branches=["trunk"])
    sys_dir, _ = make_system(tmp_path, {"a": repo(remote)})
    clone = sys_dir / "src/a"
    git("symbolic-ref", "HEAD", "refs/heads/trunk", cwd=remote)
    if old == "deleted":
        git("update-ref", "-d", "refs/heads/main", cwd=remote)
        git("checkout", "-q", "-f", "trunk", cwd=remote)
    else:
        push_commit(remote, "one", "1\n", "main")
    out = _sync(sys_dir, capsys, 0 if old == "kept" else 1)
    assert branch(clone) == "main"
    if old == "kept":
        assert "fast-forwarded 1 commit" in out
        git("remote", "set-head", "origin", "--auto", cwd=clone)
        _left_alone(
            sys_dir,
            clone,
            capsys,
            "moved by a person: it is on main; the manifest" " names origin's default branch trunk",
        )
    else:
        assert (
            f"origin's default branch as recorded here, main, is gone from origin; `git -C"
            f" {clone} remote set-head origin --auto` reads it from origin again"
        ) in out
        git("remote", "set-head", "origin", "--auto", cwd=clone)
        _left_alone(sys_dir, clone, capsys, "moved by a person: it is on main")


# --- Moved to the manifest's new version ----------------------------------------------------


def test_changed_pin_to_a_branch_is_followed_and_recorded(system, capsys):
    # The first real use: the manifest names another branch for a cloned repo.
    sys_dir, manifest, remote, clone = system
    _pin(manifest, "dev")
    out = _sync(sys_dir, capsys)
    assert "src/a: moved from main to dev\n" in out
    assert branch(clone) == "dev"
    assert head(clone) == git("rev-parse", "dev", cwd=remote)
    record = state_of(sys_dir)["a"]
    assert record["version"] == "dev" and record["commit"] == head(clone)
    assert "moving" not in record
    assert git("rev-parse", "--abbrev-ref", "dev@{upstream}", cwd=clone) == "origin/dev"
    assert (clone / "local.log").is_file()
    assert "up to date (1)" in _sync(sys_dir, capsys)


def test_changed_pin_back_and_forth_uses_the_local_branch_and_fast_forwards_it(system, capsys):
    sys_dir, manifest, remote, clone = system
    was_main = head(clone)
    _pin(manifest, "dev")
    _sync(sys_dir, capsys)
    new_main = push_commit(remote, "later", "x\n")
    _pin(manifest, "main")
    out = _sync(sys_dir, capsys)
    assert "src/a: moved from dev to main\n" in out
    assert branch(clone) == "main" and head(clone) == new_main
    assert git("rev-parse", "dev", cwd=clone) == git("rev-parse", "dev", cwd=remote)
    assert was_main != new_main


def test_changed_pin_to_a_tag_detaches_at_it_and_then_stays(system, capsys):
    sys_dir, manifest, remote, clone = system
    _pin(manifest, "v1")
    assert "src/a: moved from main to v1" in _sync(sys_dir, capsys)
    assert branch(clone) == "HEAD"
    assert head(clone) == git("rev-parse", "v1^{commit}", cwd=remote)
    push_commit(remote, "later", "x\n")
    out = _sync(sys_dir, capsys)
    assert "up to date (1)" in out
    assert head(clone) == git("rev-parse", "v1^{commit}", cwd=remote)
    assert git("rev-parse", "main", cwd=clone) != git("rev-parse", "main", cwd=remote)


def test_changed_pin_to_a_commit_detaches_at_it(system, capsys):
    sys_dir, manifest, remote, clone = system
    commit = git("rev-parse", "other", cwd=remote)
    _pin(manifest, commit[:10])
    assert f"moved from main to {commit[:10]}" in _sync(sys_dir, capsys)
    assert head(clone) == commit and branch(clone) == "HEAD"
    assert state_of(sys_dir)["a"]["version"] == commit[:10]


@pytest.mark.parametrize("where", ["a local branch", "a local tag", "a detached HEAD"])
def test_a_pin_to_a_commit_origin_does_not_hold_is_not_followed(system, capsys, where):
    sys_dir, manifest, _, clone = system
    git("switch", "-q", "-c", "mine", cwd=clone)
    commit = commit_file(clone, "mine.txt", "mine\n", "a person's commit")
    git("switch", "-q", "main", cwd=clone)
    if where == "a local tag":
        git("tag", "mine-tag", "mine", cwd=clone)
        git("update-ref", "-d", "refs/heads/mine", cwd=clone)
    elif where == "a detached HEAD":
        git("update-ref", "-d", "refs/heads/mine", cwd=clone)
    _pin(manifest, commit)
    _left_alone(
        sys_dir,
        clone,
        capsys,
        f"src/a: left alone: version {commit} is a commit here that no branch of origin, and no"
        " tag origin has, holds; not followed",
    )


def test_a_pin_to_a_commit_held_only_by_a_tag_of_origin_is_followed(system, capsys):
    sys_dir, manifest, remote, clone = system
    git("switch", "-q", "-c", "release", cwd=remote)
    commit = commit_file(remote, "rel.txt", "r\n", "release only")
    git("tag", "r1", cwd=remote)
    git("switch", "-q", "main", cwd=remote)
    git("update-ref", "-d", "refs/heads/release", cwd=remote)
    _pin(manifest, commit)
    assert f"moved from main to {commit}" in _sync(sys_dir, capsys)
    assert head(clone) == commit and branch(clone) == "HEAD"


def test_a_branch_left_behind_by_a_move_keeps_its_commits(system, capsys):
    sys_dir, manifest, _, clone = system
    main = head(clone)
    _pin(manifest, "dev")
    _sync(sys_dir, capsys)
    assert git("rev-parse", "main", cwd=clone) == main


# --- Left alone: what a person did -----------------------------------------------------------


@pytest.mark.parametrize("change", ["modified", "staged", "deleted", "assume-unchanged"])
def test_tracked_changes_leave_it_alone(system, capsys, change):
    sys_dir, manifest, remote, clone = system
    push_commit(remote, "one", "1\n")
    if change == "modified":
        (clone / "README").write_text("mine\n")
    elif change == "staged":
        (clone / "new.txt").write_text("mine\n")
        git("add", "new.txt", cwd=clone)
    elif change == "deleted":
        (clone / "README").unlink()
    else:
        git("update-index", "--assume-unchanged", "README", cwd=clone)
        (clone / "README").write_text("hidden change\n")
    _left_alone(sys_dir, clone, capsys, "src/a: left alone: has uncommitted changes (1 file)")


def test_tracked_changes_also_stop_a_changed_pin(system, capsys):
    sys_dir, manifest, _, clone = system
    (clone / "README").write_text("mine\n")
    _pin(manifest, "dev")
    _left_alone(sys_dir, clone, capsys, "has uncommitted changes (1 file)")
    assert branch(clone) == "main"


def _local_commit(clone):
    return commit_file(clone, "mine.txt", "mine\n", "a local commit")


@pytest.mark.parametrize("case", ["ahead", "diverged", "version changed"])
def test_commits_not_on_origin_leave_it_alone(system, capsys, case):
    sys_dir, manifest, remote, clone = system
    _local_commit(clone)
    if case == "diverged":
        push_commit(remote, "theirs", "x\n")
    if case == "version changed":
        _pin(manifest, "dev")
    out = _left_alone(sys_dir, clone, capsys, "src/a: left alone: has 1 commit not on origin")
    rebase = f"to bring origin's in by hand: git -C {clone} pull --rebase origin main"
    assert (rebase in out) == (case == "diverged")
    assert ("the manifest names dev; it is not switched" in out) == (case == "version changed")


def test_an_upstream_that_was_force_pushed_reads_as_commits_not_on_origin(system, capsys):
    sys_dir, _, remote, clone = system
    push_commit(remote, "one", "1\n")
    _sync(sys_dir, capsys)
    git("reset", "-q", "--hard", "HEAD~1", cwd=remote)
    push_commit(remote, "rewritten", "2\n")
    # The old upstream commit reads as one of the clone's own: left alone (part 4 tells them
    # apart).
    _left_alone(sys_dir, clone, capsys, "src/a: left alone: has 1 commit not on origin;")


def test_a_branch_rewound_upstream_while_head_is_on_another_origin_branch(system, capsys):
    sys_dir, _, remote, clone = system
    push_commit(remote, "one", "1\n")
    git("branch", "-f", "keep", "main", cwd=remote)
    _sync(sys_dir, capsys)
    git("reset", "-q", "--hard", "HEAD~1", cwd=remote)
    push_commit(remote, "rewritten", "2\n")
    _left_alone(
        sys_dir,
        clone,
        capsys,
        "src/a: left alone: origin's main no longer contains this commit (rewritten upstream)",
    )


@pytest.mark.parametrize("where", ["another branch", "detached elsewhere"])
def test_a_repo_moved_by_a_person_is_left_alone(system, capsys, where):
    sys_dir, manifest, remote, clone = system
    if where == "another branch":
        git("switch", "-q", "other", cwd=clone)
        says = "moved by a person: it is on other; the manifest names main"
    else:
        git("switch", "-q", "--detach", "origin/other", cwd=clone)
        short = head(clone)[:12]
        says = f"moved by a person: it is on a detached HEAD at {short}; the manifest names main"
    push_commit(remote, "one", "1\n")
    _left_alone(sys_dir, clone, capsys, says)


def test_a_repo_moved_by_a_person_when_the_pin_changes_too(system, capsys):
    sys_dir, manifest, _, clone = system
    git("switch", "-q", "other", cwd=clone)
    _pin(manifest, "dev")
    _left_alone(sys_dir, clone, capsys, "it is on other; the manifest names dev (recorded: main)")


def test_no_record_and_not_on_the_version_is_left_alone(system, capsys):
    sys_dir, manifest, _, clone = system
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    data["distros"]["_unnamed"]["repos"] = {}
    state.write_text(yaml.safe_dump(data))
    _pin(manifest, "dev")
    git("fetch", "-q", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    out = _sync(sys_dir, capsys)
    assert snapshot_repo(clone, fetched=True) == before
    assert "moved by a person: it is on main; the manifest names dev" in out
    assert "a" not in state_of(sys_dir)


def _conflict(clone, how):
    """Leave `how` in progress in the clone, with real git."""
    base = head(clone)
    git("switch", "-q", "-c", "side", cwd=clone)
    commit_file(clone, "README", "side\n", "side")
    git("switch", "-q", "main", cwd=clone)
    if how == "a rebase":
        git("switch", "-q", "-c", "topic", base, cwd=clone)
        commit_file(clone, "README", "topic\n", "topic")
        subprocess.run(["git", "rebase", "side"], cwd=clone, capture_output=True, check=False)
        return
    if how in ("a merge", "a cherry-pick"):
        commit_file(clone, "README", "main\n", "main")
        command = ["merge", "side"] if how == "a merge" else ["cherry-pick", "side"]
        subprocess.run(["git", *command], cwd=clone, capture_output=True, check=False)
        return
    if how == "a revert":
        commit_file(clone, "README", "main\n", "main")
        commit_file(clone, "README", "main again\n", "main again")
        subprocess.run(
            ["git", "revert", "--no-edit", "HEAD~1"], cwd=clone, capture_output=True, check=False
        )
        return
    git("bisect", "start", cwd=clone)


@pytest.mark.parametrize("how", ["a rebase", "a merge", "a cherry-pick", "a revert", "a bisect"])
def test_an_operation_in_progress_is_left_alone(system, capsys, how):
    sys_dir, _, remote, clone = system
    _conflict(clone, how)
    push_commit(remote, "one", "1\n")
    _left_alone(sys_dir, clone, capsys, f"src/a: left alone: {how} is in progress", fetched=False)


def test_an_index_lock_is_left_alone(system, capsys):
    sys_dir, _, remote, clone = system
    (clone / ".git" / "index.lock").write_text("")
    push_commit(remote, "one", "1\n")
    _left_alone(sys_dir, clone, capsys, "index.lock exists; another git may be running here", False)


def test_a_stopped_move_is_worded_from_the_moving_line(system, capsys):
    sys_dir, _, remote, clone = system
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    target = git("rev-parse", "other", cwd=remote)
    data["distros"]["_unnamed"]["repos"]["a"]["moving"] = {"from": head(clone), "to": target}
    state.write_text(yaml.safe_dump(data))
    (clone / "README").write_text("left by a stopped switch, or a person's edit\n")
    _left_alone(
        sys_dir,
        clone,
        capsys,
        f"left alone: has uncommitted changes (1 file); a sync was stopped while moving this"
        f" repo from {head(clone)[:12]} to {target[:12]}; `git status` shows what it left",
    )


def test_a_moving_line_is_not_used_once_a_person_moved_the_repo(system, capsys):
    sys_dir, _, remote, clone = system
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    data["distros"]["_unnamed"]["repos"]["a"]["moving"] = {"from": "1" * 40, "to": "2" * 40}
    state.write_text(yaml.safe_dump(data))
    (clone / "README").write_text("mine\n")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    out = _sync(sys_dir, capsys)
    assert "src/a: left alone: has uncommitted changes (1 file)\n" in out
    assert "a sync was stopped" not in out
    assert snapshot_repo(clone, fetched=True) == before
    assert "moving" not in state_of(sys_dir)["a"]


@pytest.mark.parametrize("why", ["an index.lock", "a merge in progress", "another branch"])
def test_a_moving_line_that_no_longer_describes_the_repo_is_cleared_when_left_alone(
    system, capsys, why
):
    sys_dir, _, remote, clone = system
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    data["distros"]["_unnamed"]["repos"]["a"]["moving"] = {"from": "1" * 40, "to": "2" * 40}
    state.write_text(yaml.safe_dump(data))
    if why == "an index.lock":
        (clone / ".git" / "index.lock").write_text("")
        says = "left alone: index.lock exists; another git may be running here\n"
    elif why == "a merge in progress":
        _conflict(clone, "a merge")
        says = "left alone: a merge is in progress\n"
    else:
        git("switch", "-q", "--track", "origin/dev", cwd=clone)
        says = "left alone: moved by a person"
    before = snapshot_repo(clone)
    out = _sync(sys_dir, capsys)
    assert says in out and "a sync was stopped" not in out, out
    assert snapshot_repo(clone)["head"] == before["head"]
    assert "moving" not in state_of(sys_dir)["a"]


def test_a_moving_line_is_removed_when_the_repo_is_found_on_the_version(system, capsys):
    sys_dir, _, _, clone = system
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    data["distros"]["_unnamed"]["repos"]["a"]["moving"] = {"from": "1" * 40, "to": head(clone)}
    state.write_text(yaml.safe_dump(data))
    assert "up to date (1)" in _sync(sys_dir, capsys)
    assert "moving" not in state_of(sys_dir)["a"]


@pytest.mark.parametrize("mode", ["--cone", "--no-cone"])
def test_a_sparse_checkout_is_left_alone_and_said_to_be_one(system, capsys, mode):
    sys_dir, _, remote, clone = system
    commit_file(remote, "keep/k", "k\n", "keep")
    commit_file(remote, "out/o", "o\n", "out")
    _sync(sys_dir, capsys)
    git("sparse-checkout", "set", mode, "keep", cwd=clone)
    push_commit(remote, "keep/new", "n\n")
    out = _left_alone(
        sys_dir,
        clone,
        capsys,
        "src/a: left alone: is a sparse checkout; sync does not update one (its skip-worktree"
        " files are not changes): update it by hand",
    )
    assert "uncommitted" not in out


def test_no_single_origin_is_left_alone(system, capsys):
    sys_dir, _, _, clone = system
    git("remote", "rename", "origin", "upstream", cwd=clone)
    _left_alone(sys_dir, clone, capsys, "src/a: left alone: has no single origin", False)
    git("remote", "rename", "upstream", "origin", cwd=clone)
    git("config", "--add", "remote.origin.url", "/elsewhere", cwd=clone)
    _left_alone(sys_dir, clone, capsys, "src/a: left alone: has no single origin", False)


def test_a_directory_that_is_not_a_repository_of_its_own_is_left_alone(vcs, tmp_path, capsys):
    # The system is inside a repository of its own: a plain directory at a repo's place is
    # inside that one, not a repository of its own.
    git("init", "-q", str(tmp_path))
    remote = make_remote(tmp_path / "remotes", "a")
    sys_dir, manifest = make_system(tmp_path, {"a": repo(remote)})
    rewrite_manifest(manifest, lambda d: d["repositories"].update(d=repo(remote)))
    (sys_dir / "src" / "d").mkdir()
    (sys_dir / "src" / "d" / "mine").write_text("x\n")
    out = _sync(sys_dir, capsys)
    assert "src/d: left alone: is not a git repository of its own" in out
    assert os.listdir(sys_dir / "src" / "d") == ["mine"]


def test_a_repo_of_another_type_is_left_alone(vcs, tmp_path):
    # The manifest's reader refuses another type today; the rule stands behind it.
    remote = make_remote(tmp_path / "remotes", "a")
    sys_dir, _ = make_system(tmp_path, {"a": repo(remote)})
    before = snapshot_repo(sys_dir / "src/a")
    done = update.update_repo(
        sys_dir / "src/a",
        Selected("a", "hg", str(remote), None, False),
        "_unnamed",
        None,
        dict(os.environ),
        None,
        lambda record: pytest.fail("nothing is recorded"),
    )
    assert (done.outcome, done.detail) == (update.LEFT, "type hg: sync updates git repos only")
    assert snapshot_repo(sys_dir / "src/a") == before


def test_a_local_branch_of_the_new_version_with_commits_not_on_origin_is_not_switched_to(
    system, capsys
):
    sys_dir, manifest, _, clone = system
    git("branch", "-q", "dev", "origin/dev", cwd=clone)
    git("switch", "-q", "dev", cwd=clone)
    _local_commit(clone)
    git("switch", "-q", "main", cwd=clone)
    _pin(manifest, "dev")
    _left_alone(
        sys_dir, clone, capsys, "a local branch dev has commits not on origin; not switched"
    )


def test_a_branch_checked_out_in_a_linked_work_tree_is_not_switched_to(system, tmp_path, capsys):
    sys_dir, manifest, _, clone = system
    git("worktree", "add", "-q", str(tmp_path / "wt-dev"), "-b", "dev", "origin/dev", cwd=clone)
    _pin(manifest, "dev")
    _left_alone(
        sys_dir,
        clone,
        capsys,
        f"branch dev is held by the work tree {tmp_path / 'wt-dev'} (it is checked out there);"
        " not switched",
    )


# --- Fetch and version ----------------------------------------------------------------------


@pytest.mark.parametrize("optional", [False, True])
def test_a_fetch_that_fails(system, capsys, optional):
    sys_dir, manifest, remote, clone = system
    if optional:
        rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(optional=True))
    remote.rename(remote.parent / "gone")
    before = snapshot_repo(clone)
    out = _sync(sys_dir, capsys, 0 if optional else 1)
    assert snapshot_repo(clone) == before
    if optional:
        assert "skipped src/a (optional): `git fetch origin` exited 128" in out
    else:
        assert "ERROR: src/a: `git fetch origin` exited 128" in out
        assert "run `repos-manifest sync` to finish once they can be fetched" in out


def test_a_tag_clash_on_a_tag_the_manifest_does_not_name_is_a_note(system, capsys):
    # git exits 1 for the tag it will not replace and still fetches the branches; sync fetches
    # the branches again without tags and goes on.
    sys_dir, _, remote, clone = system
    mine = git("rev-parse", "refs/tags/v1", cwd=clone)
    git("tag", "-f", "v1", "other", cwd=remote)
    new = push_commit(remote, "one", "1\n")
    out = _sync(sys_dir, capsys)
    assert (
        "src/a: tag v1 here and origin's tag v1 name other objects; sync never replaces a tag,"
        " and this one is not the manifest's version"
    ) in out, out
    assert "src/a: fast-forwarded 1 commit" in out
    assert head(clone) == new
    assert git("rev-parse", "refs/tags/v1", cwd=clone) == mine


def test_a_tag_of_a_persons_own_that_origin_also_made_is_never_advised_away(system, capsys):
    sys_dir, manifest, remote, clone = system
    git("switch", "-q", "--detach", "origin/other", cwd=clone)
    mine = commit_file(clone, "mine.txt", "mine\n", "a person's commit")
    git("tag", "rel", cwd=clone)
    git("switch", "-q", "main", cwd=clone)
    theirs = git("rev-parse", "dev", cwd=remote)
    git("tag", "rel", "dev", cwd=remote)
    _pin(manifest, "rel")
    git("fetch", "-q", "--no-tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    recorded = state_of(sys_dir)["a"]
    out = _sync(sys_dir, capsys, 1)
    assert snapshot_repo(clone, fetched=True) == before
    assert state_of(sys_dir)["a"] == recorded
    assert (
        f"ERROR: src/a: a tag rel is here at {mine[:12]}, and origin's tag rel is at"
        f" {theirs[:12]}; sync never replaces a tag, and which to keep is for a person to decide"
    ) in out, out
    assert "tag -d" not in out
    assert git("rev-parse", "refs/tags/rel", cwd=clone) == mine


def test_a_tag_moved_on_origin_is_followed_once_the_stale_tag_is_deleted(system, capsys):
    sys_dir, manifest, remote, clone = system
    _pin(manifest, "v1")
    assert "src/a: moved from main to v1" in _sync(sys_dir, capsys)
    old = head(clone)
    git("tag", "-f", "v1", "other", cwd=remote)
    new = git("rev-parse", "other", cwd=remote)
    before = snapshot_repo(clone, fetched=True)
    out = _sync(sys_dir, capsys, 1)
    assert f"git -C {clone} tag -d v1, then sync again" in out
    assert snapshot_repo(clone, fetched=True) == before
    assert git("rev-parse", "refs/tags/v1", cwd=clone) == old
    git("tag", "-d", "v1", cwd=clone)
    out = _sync(sys_dir, capsys)
    assert f"src/a: tag v1 was moved on origin: moved from {old[:12]} to it" in out
    assert "updated (1): src/a" in out
    assert head(clone) == new and branch(clone) == "HEAD"
    assert state_of(sys_dir)["a"]["commit"] == new and state_of(sys_dir)["a"]["version"] == "v1"
    assert "up to date (1)" in _sync(sys_dir, capsys)
    assert head(clone) == new


def test_a_repo_moved_off_the_tag_by_a_person_is_not_taken_for_a_moved_tag(system, capsys):
    sys_dir, manifest, remote, clone = system
    _pin(manifest, "v1")
    _sync(sys_dir, capsys)
    git("switch", "-q", "--detach", "origin/dev", cwd=clone)
    git("tag", "-f", "v1", "other", cwd=remote)
    git("tag", "-d", "v1", cwd=clone)
    _left_alone(sys_dir, clone, capsys, "moved by a person: it is on a detached HEAD at")


def test_the_fetch_never_writes_local_branches_whatever_remote_origin_fetch_says(system, capsys):
    sys_dir, manifest, remote, clone = system
    _pin(manifest, "v1")
    _sync(sys_dir, capsys)
    git("branch", "-q", "dev", "origin/dev", cwd=clone)
    git("worktree", "add", "-q", "--detach", str(clone.parent / "wt-dev"), "dev", cwd=clone)
    mine = commit_file(clone.parent / "wt-dev", "mine.txt", "mine\n", "a person's commit")
    git("worktree", "remove", str(clone.parent / "wt-dev"), cwd=clone)
    git("branch", "-q", "-f", "dev", mine, cwd=clone)
    git("config", "remote.origin.fetch", "+refs/heads/*:refs/heads/*", cwd=clone)
    push_commit(remote, "theirs", "t\n", "dev")
    before = snapshot_repo(clone, fetched=True)
    out = _sync(sys_dir, capsys)
    assert "up to date (1)" in out, out
    assert snapshot_repo(clone, fetched=True) == before
    assert git("rev-parse", "dev", cwd=clone) == mine


@pytest.mark.parametrize("setting", ["fetch", "url"])
def test_a_remote_of_the_probes_name_stops_the_probe_and_keeps_its_refs(system, capsys, setting):
    """A remote a person named like the probe: `sync` neither probes (a `-c` url would be added
    to theirs, and their refspec could write local branches) nor removes its refs; the clone
    is left as it is, whole, and the record keeps the old url, so the next sync says it again."""
    sys_dir, manifest, remote, clone = system
    copy = _bare_copy(remote, "a-copy.git")
    git("branch", "-q", "dev", "origin/dev", cwd=clone)
    if setting == "fetch":
        git("config", f"remote.{update.PROBE}.fetch", "+refs/heads/*:refs/heads/*", cwd=clone)
    else:
        git("remote", "add", update.PROBE, str(remote), cwd=clone)
        git("fetch", "-q", update.PROBE, cwd=clone)
    push_commit(remote, "theirs", "t\n", "dev")
    git("push", "-q", str(copy), "dev:dev", cwd=remote)
    _url(manifest, str(copy))
    before = snapshot_repo(clone)
    out = _sync(sys_dir, capsys)
    assert snapshot_repo(clone) == before
    assert (
        f"src/a: left alone: url changed to {copy}, and a remote named {update.PROBE} is set"
        f" here, a name sync keeps for checking a new url; origin stays {remote}"
    ) in out, out
    assert state_of(sys_dir)["a"]["url"] == str(remote)


@pytest.mark.parametrize("config", [None, "fetch.prune", "remote.origin.prune"])
def test_the_fetch_removes_no_remote_tracking_ref(system, capsys, config):
    """A person's refs fetched by a refspec of their own (pull request heads) and a branch
    origin has deleted stay; `sync` prunes nothing, whatever the configuration asks."""
    sys_dir, _, remote, clone = system
    git("update-ref", "refs/pull/1/head", "dev", cwd=remote)
    git("config", "--add", "remote.origin.fetch", "+refs/pull/*/head:refs/remotes/origin/pr/*",
        cwd=clone)  # fmt: skip
    git("fetch", "-q", "origin", cwd=clone)
    if config:
        git("config", config, "true", cwd=clone)
    git("update-ref", "-d", "refs/heads/other", cwd=remote)
    refs = git("for-each-ref", "--format=%(refname) %(objectname)", "refs/remotes/", cwd=clone)
    assert "refs/remotes/origin/pr/1" in refs and "refs/remotes/origin/other" in refs
    new = push_commit(remote, "one", "1\n")
    out = _sync(sys_dir, capsys)
    assert "src/a: fast-forwarded 1 commit" in out
    after = git("for-each-ref", "--format=%(refname) %(objectname)", "refs/remotes/", cwd=clone)
    kept = [r for r in refs.splitlines() if "origin/main" not in r and "origin/HEAD" not in r]
    assert all(r in after.splitlines() for r in kept), after
    assert head(clone) == new


def test_a_pinned_branch_deleted_on_origin_is_not_followed_from_its_stale_ref(system, capsys):
    sys_dir, manifest, remote, clone = system
    _pin(manifest, "dev")
    _sync(sys_dir, capsys)
    git("checkout", "-q", "main", cwd=remote)
    git("update-ref", "-d", "refs/heads/dev", cwd=remote)
    stale = git("rev-parse", "refs/remotes/origin/dev", cwd=clone)
    before = snapshot_repo(clone)
    out = _sync(sys_dir, capsys, 1)
    assert (
        "ERROR: src/a: version dev is not on origin: origin no longer has the branch dev"
        " (refs/remotes/origin/dev here is left from an earlier fetch; sync removes no"
        " remote-tracking ref)"
    ) in out, out
    assert snapshot_repo(clone) == before
    assert git("rev-parse", "refs/remotes/origin/dev", cwd=clone) == stale


def test_a_commit_held_only_by_a_stale_remote_tracking_ref_is_not_followed(system, capsys):
    sys_dir, manifest, remote, clone = system
    commit = git("rev-parse", "other", cwd=remote)
    git("update-ref", "-d", "refs/heads/other", cwd=remote)
    _pin(manifest, commit)
    _left_alone(
        sys_dir,
        clone,
        capsys,
        f"src/a: left alone: version {commit} is a commit here that no branch of origin, and no"
        " tag origin has, holds; not followed",
    )


def test_a_local_only_tag_is_kept_by_the_fetch(system, capsys):
    sys_dir, _, remote, clone = system
    git("config", "fetch.pruneTags", "true", cwd=clone)
    git("tag", "mine", cwd=clone)
    push_commit(remote, "one", "1\n")
    _sync(sys_dir, capsys)
    assert "mine" in git("tag", cwd=clone).split()


@pytest.mark.parametrize("version", ["nosuch", "abcdef1234"])
def test_a_version_not_on_origin_fails(system, capsys, version):
    sys_dir, manifest, _, clone = system
    _pin(manifest, version)
    out = _sync(sys_dir, capsys, 1)
    assert f"ERROR: src/a: version {version} is not on origin" in out
    assert branch(clone) == "main"


def test_a_version_that_is_both_a_branch_and_a_tag_fails(system, capsys):
    sys_dir, manifest, remote, clone = system
    git("tag", "dev", "other", cwd=remote)
    _pin(manifest, "dev")
    assert "version dev is both a branch and a tag" in _sync(sys_dir, capsys, 1)
    assert branch(clone) == "main"


def test_a_local_tag_absent_from_origin_is_not_taken_as_the_version(system, capsys):
    sys_dir, manifest, _, clone = system
    git("tag", "mine", "origin/other", cwd=clone)
    _pin(manifest, "mine")
    assert "version mine is a tag here, and origin has no such tag" in _sync(sys_dir, capsys, 1)
    assert branch(clone) == "main"


def test_a_local_only_tag_named_like_the_branch_pinned_does_not_count(system, capsys):
    sys_dir, manifest, remote, clone = system
    git("tag", "dev", "origin/other", cwd=clone)
    mine = git("rev-parse", "refs/tags/dev", cwd=clone)
    _pin(manifest, "dev")
    out = _sync(sys_dir, capsys)
    assert "src/a: moved from main to dev" in out
    assert git("symbolic-ref", "HEAD", cwd=clone) == "refs/heads/dev"
    assert head(clone) == git("rev-parse", "refs/heads/dev", cwd=remote)
    assert git("rev-parse", "refs/tags/dev", cwd=clone) == mine
    assert "up to date (1)" in _sync(sys_dir, capsys)


def test_a_local_only_branch_named_like_the_tag_pinned_does_not_count(system, capsys):
    sys_dir, manifest, remote, clone = system
    git("branch", "v1", "origin/other", cwd=clone)
    mine = git("rev-parse", "refs/heads/v1", cwd=clone)
    _pin(manifest, "v1")
    out = _sync(sys_dir, capsys)
    assert "src/a: moved from main to v1" in out
    assert branch(clone) == "HEAD"
    assert head(clone) == git("rev-parse", "refs/tags/v1^{commit}", cwd=remote)
    assert git("rev-parse", "refs/heads/v1", cwd=clone) == mine
    assert "up to date (1)" in _sync(sys_dir, capsys)


# --- The url rule ---------------------------------------------------------------------------


def _bare_copy(remote, name):
    copy = remote.parent / name
    git("clone", "-q", "--bare", str(remote), str(copy))
    return copy


def _url(manifest, url):
    rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(url=str(url)))


def test_a_url_changed_in_the_manifest_repoints_origin(system, capsys):
    sys_dir, manifest, remote, clone = system
    moved = _bare_copy(remote, "a-moved.git")
    _url(manifest, moved)
    out = _sync(sys_dir, capsys)
    assert f"src/a: origin repointed from {remote} to {moved}" in out
    assert git("config", "--get", "remote.origin.url", cwd=clone) == str(moved)
    assert state_of(sys_dir)["a"]["url"] == str(moved)
    assert git("for-each-ref", "refs/remotes/repos-manifest-probe/", cwd=clone) == ""
    assert "repointed" not in _sync(sys_dir, capsys)


def test_a_repointed_url_is_recorded_when_the_version_then_fails(system, capsys):
    sys_dir, manifest, remote, clone = system
    copy = _bare_copy(remote, "a-copy.git")
    _url(manifest, str(copy))
    _pin(manifest, "nosuch")
    out = _sync(sys_dir, capsys, 1)
    assert f"src/a: origin repointed from {remote} to {copy}" in out
    assert "ERROR: src/a: version nosuch is not on origin" in out
    assert git("remote", "get-url", "origin", cwd=clone) == str(copy)
    assert state_of(sys_dir)["a"]["url"] == str(copy)
    _pin(manifest, "main")
    copy2 = _bare_copy(remote, "a-copy2.git")
    _url(manifest, str(copy2))
    assert f"src/a: origin repointed from {copy} to {copy2}" in _sync(sys_dir, capsys)


def test_a_url_changed_with_local_commits_not_on_it_leaves_origin(system, capsys):
    sys_dir, manifest, remote, clone = system
    moved = _bare_copy(remote, "a-moved.git")
    git("switch", "-q", "other", cwd=clone)
    _local_commit(clone)
    git("switch", "-q", "main", cwd=clone)
    _url(manifest, moved)
    out = _left_alone(
        sys_dir,
        clone,
        capsys,
        f"url changed to {moved} but 1 local commit (branch other) is not on it; origin"
        f" stays {remote}",
        fetched=False,
    )
    assert git("for-each-ref", "refs/remotes/repos-manifest-probe/", cwd=clone) == ""
    assert "src/a: left alone" in out


def test_a_url_changed_and_the_new_one_cannot_be_fetched(system, capsys):
    sys_dir, manifest, remote, clone = system
    _url(manifest, remote.parent / "nowhere.git")
    before = snapshot_repo(clone)
    out = _sync(sys_dir, capsys, 1)
    assert snapshot_repo(clone) == before
    assert "the url to fetch from changed to" in out and f"(origin stays {remote})" in out


def test_an_origin_set_by_a_person_is_left_as_set_and_followed(system, capsys):
    sys_dir, _, remote, clone = system
    mine = _bare_copy(remote, "a-mine.git")
    git("remote", "set-url", "origin", str(mine), cwd=clone)
    new = push_commit(remote, "one", "1\n")
    git("push", "-q", str(mine), "main", cwd=remote)
    out = _sync(sys_dir, capsys)
    assert (
        f"src/a: origin is {mine}, the manifest says {remote}; left as set (to use the"
        f" manifest's: git -C {clone} remote set-url origin {remote})"
    ) in out
    assert "fast-forwarded 1 commit" in out
    assert head(clone) == new
    assert git("config", "--get", "remote.origin.url", cwd=clone) == str(mine)
    assert state_of(sys_dir)["a"]["url"] == str(remote)
    assert "left as set" in _sync(sys_dir, capsys)  # every run


def test_a_system_with_no_recorded_url_never_repoints(system, capsys):
    # A system made before the record held urls: an origin that differs is a person's.
    sys_dir, manifest, remote, clone = system
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    del data["distros"]["_unnamed"]["repos"]["a"]["url"]
    state.write_text(yaml.safe_dump(data))
    moved = _bare_copy(remote, "a-moved.git")
    _url(manifest, moved)
    out = _sync(sys_dir, capsys)
    assert f"origin is {remote}, the manifest says {moved}; left as set" in out
    assert git("config", "--get", "remote.origin.url", cwd=clone) == str(remote)
    assert state_of(sys_dir)["a"]["url"] == str(moved)


SECRET_A = "https://alice:s3cret@example.invalid/a"
SECRET_B = "https://alice:s3cret@example.invalid/b"


def test_credentials_in_a_hand_set_origin_are_never_printed(system, capsys):
    sys_dir, _, remote, clone = system
    git("remote", "set-url", "origin", SECRET_A, cwd=clone)
    git("config", f"url.{remote}.insteadOf", SECRET_A, cwd=clone)
    new = push_commit(remote, "one", "1\n")
    out = _sync(sys_dir, capsys)
    assert "s3cret" not in out and "alice" not in out, out
    assert (
        f"src/a: origin is https://***@example.invalid/a, the manifest says {remote}; left as"
        f" set (to use the manifest's: git -C {clone} remote set-url origin {remote})"
    ) in out
    assert head(clone) == new


def test_credentials_in_the_manifests_url_are_never_printed(system, capsys):
    sys_dir, manifest, remote, clone = system
    copy = _bare_copy(remote, "a-copy.git")
    git("config", f"url.{copy}.insteadOf", SECRET_B, cwd=clone)
    _url(manifest, SECRET_B)
    out = _sync(sys_dir, capsys)
    assert "s3cret" not in out and "alice" not in out, out
    assert f"src/a: origin repointed from {remote} to https://***@example.invalid/b" in out
    assert git("config", "--get", "remote.origin.url", cwd=clone) == SECRET_B
    other = _bare_copy(remote, "a-other.git")
    git("remote", "set-url", "origin", str(other), cwd=clone)
    out = _sync(sys_dir, capsys)
    assert "s3cret" not in out and "alice" not in out, out
    assert (
        f"src/a: origin is {other}, the manifest says https://***@example.invalid/b; left as"
        f" set (to use the manifest's: git -C {clone} remote set-url origin"
        " 'https://***@example.invalid/b', with the url of a as the manifest gives it in place"
        " of the one shown)"
    ) in out


@pytest.mark.parametrize(
    "text, shown",
    [
        ("https://alice:s3cret@host/x", "https://***@host/x"),
        ("https://ghp_token@host/x", "https://***@host/x"),
        ("fatal: 'https://a:p@ss@host/x/' not found", "fatal: 'https://***@host/x/' not found"),
        ("ssh://git@host/x", "ssh://git@host/x"),
        ("ssh://git:pw@host/x", "ssh://***@host/x"),
        ("git@github.com:o/x.git", "git@github.com:o/x.git"),
        ("/srv/git/x and https://host/y", "/srv/git/x and https://host/y"),
    ],
)
def test_mask_urls(text, shown):
    assert update.mask_urls(text) == shown


def test_a_url_equal_but_for_a_trailing_slash_or_git_is_the_same(system, capsys):
    sys_dir, manifest, remote, clone = system
    _url(manifest, f"{remote}.git/")
    out = _sync(sys_dir, capsys)
    assert "left as set" not in out and "repointed" not in out
    assert git("config", "--get", "remote.origin.url", cwd=clone) == str(remote)


def test_an_insteadof_rewrite_compares_the_raw_url_and_probes_through_it(system, capsys):
    sys_dir, manifest, remote, clone = system
    moved = _bare_copy(remote, "a-moved.git")
    git("config", f"url.{moved.parent}/.insteadOf", "mirror:", cwd=clone)
    _url(manifest, f"mirror:{moved.name}")
    out = _sync(sys_dir, capsys)
    assert f"origin repointed from {remote} to mirror:{moved.name}" in out
    assert git("config", "--get", "remote.origin.url", cwd=clone) == f"mirror:{moved.name}"


def test_probe_refs_left_by_a_killed_run_are_removed_at_the_next_check(system, capsys):
    sys_dir, _, _, clone = system
    git("update-ref", "refs/remotes/repos-manifest-probe/main", "HEAD", cwd=clone)
    _sync(sys_dir, capsys)
    assert git("for-each-ref", "refs/remotes/repos-manifest-probe/", cwd=clone) == ""


def test_a_version_missing_from_an_origin_set_by_hand_says_so(system, capsys):
    sys_dir, manifest, remote, clone = system
    mine = remote.parent / "a-fork.git"
    git("init", "-q", "--bare", str(mine))
    git("push", "-q", str(mine), "main", cwd=remote)
    git("remote", "set-url", "origin", str(mine), cwd=clone)
    _pin(manifest, "dev")
    out = _sync(sys_dir, capsys, 1)
    assert (
        "version dev is not on origin: origin no longer has the branch dev"
        " (refs/remotes/origin/dev here is left from an earlier fetch; sync removes no"
        " remote-tracking ref); origin was set by hand: origin is"
    ) in out, out
    assert f"git -C {clone} remote set-url origin {remote}" in out


# --- Submodules, shallow clones, hooks --------------------------------------------------------


def _with_submodule(tmp_path):
    sub = make_remote(tmp_path / "remotes", "sub")
    top = make_remote(tmp_path / "remotes", "top")
    git(
        "-c", "protocol.file.allow=always", "submodule", "add", "-q", str(sub), "sm", cwd=top
    )  # fmt: skip
    git("commit", "-q", "-m", "submodule", cwd=top)
    return sub, top


def test_a_clone_with_a_submodule_is_followed_and_then_up_to_date(vcs, tmp_path, capsys):
    sub, top = _with_submodule(tmp_path)
    sys_dir, _ = make_system(tmp_path, {"top": repo(top, "main")})
    clone = sys_dir / "src/top"
    git(
        "-c", "protocol.file.allow=always", "submodule", "update", "--init", "-q", cwd=clone
    )  # fmt: skip
    push_commit(sub, "new", "x\n")
    git("-C", "sm", "pull", "-q", "origin", "main", cwd=top)
    git("commit", "-q", "-am", "move the pointer", cwd=top)
    out = _sync(sys_dir, capsys)
    assert "src/top: fast-forwarded 1 commit" in out
    assert f"src/top: submodules not updated: git -C {clone} submodule update" in out
    out = _sync(sys_dir, capsys)
    assert "up to date (1)" in out and "uncommitted" not in out


def test_a_submodule_with_changed_tracked_files_is_left_alone(vcs, tmp_path, capsys):
    sub, top = _with_submodule(tmp_path)
    sys_dir, _ = make_system(tmp_path, {"top": repo(top, "main")})
    clone = sys_dir / "src/top"
    git(
        "-c", "protocol.file.allow=always", "submodule", "update", "--init", "-q", cwd=clone
    )  # fmt: skip
    (clone / "sm" / "README").write_text("mine\n")
    push_commit(top, "later", "x\n")
    out = _sync(sys_dir, capsys)
    assert "src/top: left alone: has uncommitted changes (1 file)" in out


def test_a_shallow_clone_is_followed_and_stays_shallow(vcs, tmp_path, capsys):
    remote = make_remote(tmp_path / "remotes", "a")
    for n in range(3):
        push_commit(remote, f"f{n}", "x\n")
    sys_dir, _ = make_system(tmp_path, {"a": repo(remote, "main")})
    clone = sys_dir / "src/a"
    # Made shallow by hand, as `vcs import --shallow` would clone it.
    subprocess.run(["rm", "-rf", str(clone)], check=True)
    git("clone", "-q", "--depth", "1", "-b", "main", f"file://{remote}", str(clone))
    git("remote", "set-url", "origin", str(remote), cwd=clone)
    new = push_commit(remote, "later", "x\n")
    assert "fast-forwarded 1 commit" in _sync(sys_dir, capsys)
    assert head(clone) == new
    assert (clone / ".git" / "shallow").is_file()
    assert "up to date (1)" in _sync(sys_dir, capsys)


def _narrow_clone(clone, remote, how):
    """Clone `remote` again at `clone` as a person would with `how`: a --single-branch clone,
    or a --depth 1 one (which is single-branch too); its fetch settings cover main only."""
    subprocess.run(["rm", "-rf", str(clone)], check=True)
    if how == "--single-branch":
        git("clone", "-q", "--single-branch", "-b", "main", str(remote), str(clone))
    else:
        git("clone", "-q", "--depth", "1", "-b", "main", f"file://{remote}", str(clone))
        git("remote", "set-url", "origin", str(remote), cwd=clone)
    (clone / "local.log").write_text("a person's ignored file\n")


@pytest.mark.parametrize("how", ["--single-branch", "--depth 1"])
@pytest.mark.parametrize("to", ["dev", "v1", "commit"])
def test_a_narrow_clone_is_moved_whole_or_not_at_all(system, capsys, how, to):
    sys_dir, manifest, remote, clone = system
    _narrow_clone(clone, remote, how)
    target = {
        "dev": git("rev-parse", "dev", cwd=remote),
        "v1": git("rev-parse", "v1^{commit}", cwd=remote),
        "commit": git("rev-parse", "other", cwd=remote),
    }[to]
    _pin(manifest, target if to == "commit" else to)
    before = snapshot_repo(clone)
    out = _sync(sys_dir, capsys)
    assert "updated (1): src/a" in out and "ERROR" not in out, out
    after = snapshot_repo(clone)
    assert head(clone) == target
    # Nothing staged or changed: only the person's file, untracked or ignored on the target.
    status = git("status", "--porcelain", "--untracked-files=all", "--ignored", cwd=clone)
    assert status in ("?? local.log", "!! local.log"), status
    assert after["files"]["local.log"] == before["files"]["local.log"]
    assert after["config"] == before["config"]
    if to == "dev":
        assert git("symbolic-ref", "HEAD", cwd=clone) == "refs/heads/dev"
        assert (
            f"src/a: branch dev has no upstream configured: the clone's fetch settings"
            f" (remote.origin.fetch, as a --single-branch or --depth clone has them) do not"
            f" cover origin's dev; to set one by hand: git -C {clone} config branch.dev.remote"
            f" origin && git -C {clone} config branch.dev.merge refs/heads/dev"
        ) in out, out
    else:
        assert branch(clone) == "HEAD"
    assert state_of(sys_dir)["a"]["commit"] == target and "moving" not in state_of(sys_dir)["a"]
    assert "up to date (1)" in _sync(sys_dir, capsys)


def test_a_new_branch_gets_its_upstream_when_the_fetch_settings_cover_it(system, capsys):
    sys_dir, manifest, _, clone = system
    _pin(manifest, "dev")
    out = _sync(sys_dir, capsys)
    assert "no upstream" not in out
    assert git("rev-parse", "--abbrev-ref", "dev@{upstream}", cwd=clone) == "origin/dev"


def test_a_commit_pin_beyond_a_shallow_clones_history_says_so(system, capsys):
    sys_dir, manifest, remote, clone = system
    push_commit(remote, "one", "1\n")
    old = git("rev-parse", "main~1", cwd=remote)  # in no tag's history: the fetch keeps it out
    _narrow_clone(clone, remote, "--depth 1")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    _pin(manifest, old)
    out = _sync(sys_dir, capsys, 1)
    assert (
        f"ERROR: src/a: version {old} is not in this shallow clone's history; sync never deepens"
        f" a clone (`git -C {clone} fetch --unshallow origin`, run by hand, makes it whole)"
    ) in out, out
    assert snapshot_repo(clone, fetched=True) == before


def test_a_failing_post_checkout_hook_after_the_switch_still_counts_as_moved(system, capsys):
    sys_dir, manifest, remote, clone = system
    hook = clone / ".git" / "hooks" / "post-checkout"
    hook.write_text("#!/bin/sh\necho hook says no >&2\nexit 3\n")
    hook.chmod(0o755)
    _pin(manifest, "dev")
    out = _sync(sys_dir, capsys)
    assert "src/a: moved, but `git switch` exited 1:\nhook says no\nsrc/a: moved from main" in out
    assert branch(clone) == "dev"
    assert state_of(sys_dir)["a"]["version"] == "dev"


def test_a_failing_post_checkout_hook_in_a_two_step_move_still_counts_as_moved(system, capsys):
    """The switch to a local branch that is behind, then its fast-forward: the hook fails the
    switch after it has switched, and the move goes on and ends on origin's commit."""
    sys_dir, manifest, remote, clone = system
    git("branch", "-q", "dev", "origin/dev", cwd=clone)
    new = push_commit(remote, "more", "x\n", "dev")
    hook = clone / ".git" / "hooks" / "post-checkout"
    hook.write_text("#!/bin/sh\necho hook says no >&2\nexit 1\n")
    hook.chmod(0o755)
    _pin(manifest, "dev")
    out = _sync(sys_dir, capsys)
    assert "src/a: moved, but `git switch` exited 1:\nhook says no\nsrc/a: moved from main" in out
    assert "updated (1): src/a" in out and "ERROR" not in out
    assert branch(clone) == "dev" and head(clone) == new
    assert state_of(sys_dir)["a"]["version"] == "dev"
    assert state_of(sys_dir)["a"]["commit"] == new
    assert "moving" not in state_of(sys_dir)["a"]
    assert "up to date (1)" in _sync(sys_dir, capsys)


def test_a_hook_that_edits_a_tracked_file_stops_a_two_step_move_after_its_switch(system, capsys):
    sys_dir, manifest, remote, clone = system
    git("branch", "-q", "dev", "origin/dev", cwd=clone)
    local = git("rev-parse", "dev", cwd=clone)
    push_commit(remote, "more", "x\n", "dev")
    hook = clone / ".git" / "hooks" / "post-checkout"
    hook.write_text("#!/bin/sh\necho edited by a hook >>README\nexit 0\n")
    hook.chmod(0o755)
    _pin(manifest, "dev")
    was = head(clone)
    out = _sync(sys_dir, capsys, 1)
    assert (
        "the move left the repo half-changed. What ran, in order: 1. `git switch` (exit 0): HEAD"
        f" from main at {was[:12]} to dev at {local[:12]}. HEAD is now dev at {local[:12]};"
        " changed, not staged: M README. sync's last check, just before the move, found no"
        " tracked changes, so these were made since: by git, a hook it ran,"
    ) in out, out
    assert head(clone) == local  # not fast-forwarded on a tree a hook changed
    assert "moving" not in state_of(sys_dir)["a"]


def test_a_post_merge_hook_that_edits_a_file_is_reported_with_the_fast_forward(system, capsys):
    """Case 1a of the round-3 review: the fast-forward ran, then a hook edited a file. The
    report says the local branch was fast-forwarded, from and to which commit, and the tree a
    hook changed is not switched back (so the edit is not carried onto main)."""
    sys_dir, manifest, remote, clone = system
    git("branch", "-q", "dev", "origin/dev", cwd=clone)
    local = git("rev-parse", "dev", cwd=clone)
    new = push_commit(remote, "more", "x\n", "dev")
    hook = clone / ".git" / "hooks" / "post-merge"
    hook.write_text("#!/bin/sh\necho by-hook >>README\n")
    hook.chmod(0o755)
    _pin(manifest, "dev")
    was = head(clone)
    out = _sync(sys_dir, capsys, 1)
    assert (
        "the move left the repo half-changed. What ran, in order: 1. `git switch` (exit 0): HEAD"
        f" from main at {was[:12]} to dev at {local[:12]}; 2. `git merge --ff-only` (exit 0)"
        f" fast-forwarded dev from {local[:12]} to {new[:12]}. HEAD is now dev at {new[:12]};"
        " changed, not staged: M README. sync's last check, just before the move, found no"
        " tracked changes, so these were made since: by git, a hook it ran,"
    ) in out, out
    assert branch(clone) == "dev" and head(clone) == new
    assert git("diff", "--name-only", "main", "--", "README", cwd=clone) == "README"
    git("checkout", "--", "README", cwd=clone)
    # Cleaned up by the person: the repo is on the manifest's version, and is recorded.
    assert "up to date (1)" in _sync(sys_dir, capsys)
    assert state_of(sys_dir)["a"]["version"] == "dev"


# --- The record and the layer ----------------------------------------------------------------


def test_a_repo_that_left_the_manifest_is_listed_and_kept(system, capsys):
    sys_dir, manifest, remote, clone = system
    rewrite_manifest(manifest, lambda d: d["repositories"].update(b=repo(remote)))
    _sync(sys_dir, capsys)
    rewrite_manifest(manifest, lambda d: d["repositories"].pop("a"))
    out = _sync(sys_dir, capsys)
    assert "  no longer in the manifest, left on disk (1): src/a\n" in out
    assert clone.is_dir() and "a" in state_of(sys_dir)
    subprocess.run(["rm", "-rf", str(clone)], check=True)
    out = _sync(sys_dir, capsys)
    assert "no longer in the manifest" not in out
    assert "a" not in state_of(sys_dir)


@pytest.fixture
def layered(vcs, tmp_path):
    remote = make_remote(tmp_path / "remotes", "a")
    sys_dir, manifest = make_system(
        tmp_path, {"a": repo(remote, "main", "core")}, layers=["core", "extra"]
    )
    return sys_dir, manifest, remote


@pytest.mark.parametrize("optional", [False, True])
def test_a_repo_given_another_layer_is_reported_with_the_mv_command(layered, capsys, optional):
    sys_dir, manifest, _ = layered

    def change(data):
        data["repositories"]["a"]["layer"] = "extra"
        if optional:
            data["repositories"]["a"]["optional"] = True

    rewrite_manifest(manifest, change)
    old, new = sys_dir / "core/src/a", sys_dir / "extra/src/a"
    before = snapshot_repo(old)
    out = _sync(sys_dir, capsys, 0 if optional else 1)
    assert snapshot_repo(old) == before and not os.path.lexists(new)
    command = f"mkdir -p {new.parent} && mv {old} {new}"
    said = "skipped extra/src/a (optional): " if optional else "ERROR: extra/src/a: "
    said += f"the manifest now has it in layer extra; it is in {old}. To move it: "
    assert (said + command) in out
    assert state_of(sys_dir)["a"]["layer"] == "core"
    subprocess.run(command, shell=True, check=True)
    out = _sync(sys_dir, capsys)
    assert "up to date (1)" in out
    assert state_of(sys_dir)["a"]["layer"] == "extra"


@pytest.mark.parametrize("work", ["a local commit", "a changed file", "an index.lock"])
def test_a_repo_moved_by_hand_to_its_new_layer_and_left_alone_records_the_layer(
    layered, capsys, work
):
    sys_dir, manifest, remote = layered
    old, new = sys_dir / "core/src/a", sys_dir / "extra/src/a"
    if work == "a local commit":
        commit_file(old, "mine", "mine\n", "a person's commit")
        says = "left alone: has 1 commit not on origin"
    elif work == "a changed file":
        (old / "README").write_text("mine\n")
        says = "left alone: has uncommitted changes (1 file)"
    else:
        (old / ".git" / "index.lock").write_text("")
        says = "left alone: index.lock exists"
    push_commit(remote, "later", "x\n")
    rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(layer="extra"))
    out = _sync(sys_dir, capsys, 1)
    command = f"mkdir -p {new.parent} && mv {old} {new}"
    assert command in out
    subprocess.run(command, shell=True, check=True)
    git("fetch", "-q", "--tags", "origin", cwd=new)
    before = snapshot_repo(new, fetched=True)
    out = _sync(sys_dir, capsys)
    assert f"extra/src/a: {says}" in out, out
    assert snapshot_repo(new, fetched=True) == before
    assert state_of(sys_dir)["a"]["layer"] == "extra"
    out = _sync(sys_dir, capsys)
    assert "mv " not in out and state_of(sys_dir)["a"]["layer"] == "extra"


def test_a_repo_given_another_layer_whose_old_place_is_gone_is_cloned_there(layered, capsys):
    sys_dir, manifest, _ = layered
    rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(layer="extra"))
    subprocess.run(["rm", "-rf", str(sys_dir / "core/src/a")], check=True)
    out = _sync(sys_dir, capsys)
    assert "cloned (1): extra/src/a" in out
    assert state_of(sys_dir)["a"]["layer"] == "extra"


def test_a_repo_given_another_layer_then_build_refuses_that_layer(layered, capsys):
    sys_dir, manifest, _ = layered
    rewrite_manifest(manifest, lambda d: d["repositories"]["a"].update(layer="extra"))
    _sync(sys_dir, capsys, 1)
    assert run(sys_dir, "build") == 1
    err = capsys.readouterr().err
    assert "not on disk, and not optional: a (layer extra)" in err, err


def test_the_url_is_recorded_for_a_repo_left_alone(system, capsys):
    sys_dir, _, remote, clone = system
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    del data["distros"]["_unnamed"]["repos"]["a"]["url"]
    state.write_text(yaml.safe_dump(data))
    (clone / "README").write_text("mine\n")
    _sync(sys_dir, capsys)
    assert state_of(sys_dir)["a"]["url"] == str(remote)


# --- Pull request 535's first review -------------------------------------------------------


def test_a_branch_also_checked_out_in_another_work_tree_is_not_fast_forwarded(
    system, tmp_path, capsys
):
    """Must-fix 1: `git worktree add -f` puts main in a second work tree too. A fast-forward
    would move main under it and leave its files behind (git shows the new commits there as
    staged deletions); the clone is left alone, and both work trees are unchanged, whole."""
    sys_dir, _, remote, clone = system
    other = tmp_path / "wt-main"
    git("worktree", "add", "-q", "-f", str(other), "main", cwd=clone)
    push_commit(remote, "one", "1\n")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True), snapshot_repo(other, fetched=True)
    recorded = state_of(sys_dir)["a"]
    out = _sync(sys_dir, capsys)
    assert (snapshot_repo(clone, fetched=True), snapshot_repo(other, fetched=True)) == before
    assert (
        f"src/a: left alone: branch main is held by the work tree {other} (it is checked out"
        " there); not fast-forwarded" in out
    )
    assert git("status", "--porcelain", cwd=other) == ""
    assert state_of(sys_dir)["a"] == recorded


def test_a_linked_work_tree_on_another_branch_is_unaffected_by_a_fast_forward(
    system, tmp_path, capsys
):
    """The fixture's linked work tree is on `feature`: the clone's main is fast-forwarded and
    that work tree is the same, whole, after."""
    sys_dir, _, remote, clone = system
    linked = tmp_path / "wt-a"
    (linked / "work.txt").write_text("a person's file\n")
    before = snapshot_repo(linked, fetched=True)
    new = push_commit(remote, "one", "1\n")
    assert "src/a: fast-forwarded 1 commit" in _sync(sys_dir, capsys)
    assert head(clone) == new
    after = snapshot_repo(linked, fetched=True)
    # The shared refs gained main's new commit; everything of the linked work tree is as it was.
    for key in ("head", "symbolic", "index", "status", "files", "in progress"):
        assert after[key] == before[key], key


def test_a_local_branch_held_by_another_work_tree_is_not_switched_to(system, tmp_path, capsys):
    """The two-step move's switch and fast-forward of an existing local branch: not done when
    another work tree has that branch checked out."""
    sys_dir, manifest, remote, clone = system
    other = tmp_path / "wt-dev"
    git("worktree", "add", "-q", str(other), "-b", "dev", "origin/dev", cwd=clone)
    push_commit(remote, "more", "x\n", "dev")
    _pin(manifest, "dev")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True), snapshot_repo(other, fetched=True)
    out = _sync(sys_dir, capsys)
    assert (snapshot_repo(clone, fetched=True), snapshot_repo(other, fetched=True)) == before
    assert (
        f"branch dev is held by the work tree {other} (it is checked out there); not switched"
        in out
    )


@pytest.mark.parametrize("written", ["heads/main", "main"])
def test_a_heads_version_is_the_branch_and_is_followed(vcs, tmp_path, capsys, written):
    """Must-fix 2: `heads/main` is branch main, as vcstool reads it: the system syncs, follows
    a new commit, and moves to another pin written either way."""
    remote = make_remote(tmp_path / "remotes", "a", branches=["dev"], tags=["v1"])
    sys_dir, manifest = make_system(tmp_path, {"a": repo(remote, written)})
    clone = sys_dir / "src/a"
    assert _sync(sys_dir, capsys) == "distro (no distro):\n  up to date (1)\n"
    new = push_commit(remote, "one", "1\n")
    assert "src/a: fast-forwarded 1 commit" in _sync(sys_dir, capsys)
    assert head(clone) == new and branch(clone) == "main"
    assert state_of(sys_dir)["a"]["version"] == written
    _pin(manifest, "heads/dev")
    assert "src/a: moved from " in _sync(sys_dir, capsys)
    assert branch(clone) == "dev" and head(clone) == git("rev-parse", "dev", cwd=remote)
    _pin(manifest, "tags/v1")
    assert "to v1" in _sync(sys_dir, capsys)
    assert head(clone) == git("rev-parse", "v1^{commit}", cwd=remote)
    assert _sync(sys_dir, capsys) == "distro (no distro):\n  up to date (1)\n"
    _pin(manifest, "main")
    assert "to main" in _sync(sys_dir, capsys)
    assert branch(clone) == "main"


def test_a_tags_version_is_the_tag_and_never_a_branch_of_its_name(vcs, tmp_path, capsys):
    """`tags/v1` is the tag v1 even where origin also has a branch v1; `v1` alone would be
    refused there as both."""
    remote = make_remote(tmp_path / "remotes", "a", branches=["v1"], tags=["v1"])
    sys_dir, manifest = make_system(tmp_path, {"a": repo(remote, "tags/v1")})
    clone = sys_dir / "src/a"
    assert head(clone) == git("rev-parse", "refs/tags/v1^{commit}", cwd=remote)
    assert _sync(sys_dir, capsys) == "distro (no distro):\n  up to date (1)\n"
    _pin(manifest, "heads/v1")
    assert "src/a: moved from tag v1 to branch v1" in _sync(sys_dir, capsys)
    assert git("symbolic-ref", "HEAD", cwd=clone) == "refs/heads/v1"


def test_a_symbolic_probe_ref_is_removed_itself_and_its_target_kept(system, capsys):
    """Must-fix 3: a symbolic ref under the probe's prefix pointing at a local branch. The
    probe cleanup removes the symbolic ref, never the branch it points to."""
    sys_dir, _, _, clone = system
    git("branch", "topic", cwd=clone)
    topic = git("rev-parse", "topic", cwd=clone)
    probe = f"refs/remotes/{update.PROBE}/x"
    git("symbolic-ref", probe, "refs/heads/topic", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    _sync(sys_dir, capsys)
    after = snapshot_repo(clone, fetched=True)
    assert git("rev-parse", "topic", cwd=clone) == topic
    assert git("for-each-ref", f"refs/remotes/{update.PROBE}/", cwd=clone) == ""
    assert after == before


def test_a_detached_linked_work_tree_with_a_commit_not_on_the_new_url_stops_a_repoint(
    system, tmp_path, capsys
):
    """Must-fix 4b: the HEAD of every work tree counts, a detached one included: its commit is
    not on the new url, so origin is not repointed, and both work trees are unchanged."""
    sys_dir, manifest, remote, clone = system
    moved = _bare_copy(remote, "a-moved.git")
    detached = tmp_path / "wt-detached"
    git("worktree", "add", "-q", "--detach", str(detached), "main", cwd=clone)
    mine = commit_file(detached, "mine.txt", "a person's work\n")
    _url(manifest, moved)
    before = snapshot_repo(clone), snapshot_repo(detached)
    recorded = state_of(sys_dir)["a"]
    out = _sync(sys_dir, capsys)
    assert (snapshot_repo(clone), snapshot_repo(detached)) == before
    assert (
        f"src/a: left alone: url changed to {moved} but 1 local commit (the detached HEAD of"
        f" {detached}) is not on it; origin stays {remote}"
    ) in out, out
    assert git("remote", "get-url", "origin", cwd=clone) == str(remote)
    assert state_of(sys_dir)["a"] == recorded
    assert head(detached) == mine


def test_commits_only_here_get_the_push_command_not_pull(system, capsys):
    """Must-fix 4a: origin's branch has nothing the clone lacks, so the line gives the `push`
    command to publish the commits (sync never pushes); `pull --rebase` is for the other case."""
    sys_dir, _, _, clone = system
    commit_file(clone, "mine.txt", "mine\n")
    out = _left_alone(sys_dir, clone, capsys, "src/a: left alone: has 1 commit not on origin;")
    assert (
        "origin's main has nothing this clone lacks, so the commits are only here; to publish"
        f" them (sync never pushes): git -C {clone} push origin main"
    ) in out, out
    assert "pull --rebase" not in out


def test_a_stale_remote_tracking_ref_in_the_way_is_named_with_its_command(system, capsys):
    """origin replaced its branch `release` with `release/next`: the clone's `origin/release`
    is in the way of the new ref. The error names both and the command that clears it, and
    the closing line does not say another sync will get past it."""
    sys_dir, _, remote, clone = system
    git("branch", "release", "main", cwd=remote)
    git("fetch", "-q", "origin", cwd=clone)
    git("branch", "-m", "release", "release/next", cwd=remote)
    push_commit(remote, "one", "1\n")
    before = snapshot_repo(clone, fetched=True)
    out = _sync(sys_dir, capsys, 1)
    assert snapshot_repo(clone, fetched=True) == before
    assert (
        "ERROR: src/a: the fetch cannot write origin's branches: refs/remotes/origin/release"
        " here, left from a branch origin no longer has, is in the way of origin's branch"
        " release/next. sync removes no remote-tracking ref of origin, and another sync will"
        " not change this. Removing it may remove the only ref here to commits origin has since"
        " deleted; to keep them, make a local branch at it first (git -C"
        f" {clone} branch <a new name> refs/remotes/origin/release). To clear it: git -C"
        f" {clone} update-ref -d refs/remotes/origin/release, then sync again"
    ) in out, out
    assert "once they can be fetched" not in out
    assert "another sync will not change that" in out


def test_the_stale_ref_commands_keep_commits_origin_deleted_when_run_in_order(system, capsys):
    """Pull request 535's second review: origin deleted `release`, whose last commit only the
    clone's `origin/release` still holds. The two printed commands, run as printed (a name in
    place of `<a new name>`), keep that commit on a local branch and clear the way; the next
    sync then fetches."""
    sys_dir, _, remote, clone = system
    git("checkout", "-q", "-b", "release", "main", cwd=remote)
    only = commit_file(remote, "only", "only on release\n", "only on release")
    git("checkout", "-q", "main", cwd=remote)
    git("fetch", "-q", "origin", cwd=clone)
    git("branch", "-D", "release", cwd=remote)
    git("branch", "release/next", "main", cwd=remote)
    out = _sync(sys_dir, capsys, 1)
    keep = out.split("make a local branch at it first (", 1)[1].split(")", 1)[0]
    clear = out.split("To clear it: ", 1)[1].split(", then sync again", 1)[0]
    for command in (keep.replace("<a new name>", "kept"), clear):
        subprocess.run(command, shell=True, check=True)
    assert git("rev-parse", "kept", cwd=clone) == only
    assert "src/a: " not in _sync(sys_dir, capsys)


@pytest.mark.parametrize("what", ["tree", "blob"])
def test_a_tag_that_names_a_tree_or_a_blob_is_an_error(system, capsys, what):
    sys_dir, manifest, remote, clone = system
    target = "HEAD^{tree}" if what == "tree" else "HEAD:README"
    git("tag", "odd", target, cwd=remote)
    _pin(manifest, "odd")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    out = _sync(sys_dir, capsys, 1)
    assert snapshot_repo(clone, fetched=True) == before
    assert f"ERROR: src/a: tag odd names a {what}, not a commit" in out, out


def test_the_printed_upstream_commands_quote_the_branch(tmp_path):
    git_ = update.Git(tmp_path / "a b", {}, None)
    line = update._no_upstream(git_, "we'ird", "why")
    assert "git -C 'tmp" not in line  # the place is quoted whole
    assert "config 'branch.we'\"'\"'ird.remote' origin" in line, line
    assert "'refs/heads/we'\"'\"'ird'" in line, line


def test_git_output_that_is_read_runs_in_the_c_locale_and_shown_output_does_not(tmp_path):
    git_ = update.Git(tmp_path, {"LANG": "de_DE.UTF-8", "LANGUAGE": "de"}, None)
    assert git_.env["LC_ALL"] == "C" and "LANGUAGE" not in git_.env
    assert git_.shown_env["LANGUAGE"] == "de" and "LC_ALL" not in git_.shown_env


def test_a_git_older_than_the_minimum_stops_the_run(system, tmp_path, capsys, monkeypatch):
    sys_dir, _, remote, clone = system
    fake = tmp_path / "old-git"
    fake.mkdir()
    real = subprocess.run(["which", "git"], capture_output=True, text=True).stdout.strip()
    (fake / "git").write_text(
        f'#!/bin/sh\nif [ "$1" = "--version" ]; then echo "git version 2.22.5"; exit 0; fi\n'
        f'exec {real} "$@"\n'
    )
    (fake / "git").chmod(0o755)
    monkeypatch.setenv("PATH", f"{fake}:{os.environ['PATH']}")
    push_commit(remote, "one", "1\n")
    before = snapshot_repo(clone)
    capsys.readouterr()
    assert run(sys_dir, "sync") == 1
    err = capsys.readouterr().err
    assert snapshot_repo(clone) == before
    assert (
        "ERROR: git 2.22 is on PATH, and this tool needs git 2.23 or later (for `git switch`);"
        " nothing was changed. Install git 2.23 or later"
    ) in err, err


@pytest.mark.parametrize("move", ["fast-forward", "switch"])
def test_head_moved_during_the_checks_leaves_the_repo_alone(system, capsys, monkeypatch, move):
    """HEAD is read again right before the first call: a commit a person makes, or a branch
    they switch to, while the checks run is kept, and nothing is moved."""
    sys_dir, manifest, remote, clone = system
    push_commit(remote, "one", "1\n")
    if move == "switch":
        _pin(manifest, "v1")
    real = update.in_the_way

    def meanwhile(git_, head_, targets):
        found = real(git_, head_, targets)
        if move == "fast-forward":
            commit_file(clone, "mine.txt", "made meanwhile\n")
        else:
            git("switch", "-q", "-c", "mine", cwd=clone)
        return found

    monkeypatch.setattr(update, "in_the_way", meanwhile)
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    out = _sync(sys_dir, capsys)
    assert "src/a: left alone: HEAD moved while sync was checking the repo; not moved" in out
    if move == "fast-forward":
        assert (clone / "mine.txt").read_text() == "made meanwhile\n"
        assert git("log", "-1", "--format=%s", cwd=clone) == "change"
    else:
        assert branch(clone) == "mine"
    assert "moving" not in state_of(sys_dir)["a"]


@pytest.mark.parametrize("move", ["fast-forward", "switch"])
def test_a_tracked_edit_during_the_checks_leaves_the_repo_alone(system, capsys, monkeypatch, move):
    """Pull request 535's second review: a tracked file a person edits while the checks run
    is theirs. The tracked files are read again right before the first call; the repo is
    left alone, whole, and the report does not call the edit a half-change of the move."""
    sys_dir, manifest, remote, clone = system
    push_commit(remote, "one", "1\n")
    if move == "switch":
        _pin(manifest, "v1")
    real = update.in_the_way
    edited = {}

    def meanwhile(git_, head_, targets):
        found = real(git_, head_, targets)
        (clone / "README").write_text("a person's edit\n")
        edited["state"] = snapshot_repo(clone, fetched=True)
        return found

    monkeypatch.setattr(update, "in_the_way", meanwhile)
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    recorded = state_of(sys_dir)["a"]
    out = _sync(sys_dir, capsys)
    assert snapshot_repo(clone, fetched=True) == edited["state"]
    assert (
        "src/a: left alone: a tracked file was changed while sync was checking the repo; not"
        " moved (sync again once it is committed or put back)"
    ) in out, out
    assert "half-changed" not in out
    assert state_of(sys_dir)["a"] == recorded


def test_a_clone_already_on_the_new_version_says_its_record_was_updated(system, capsys):
    """The owner's case: the pin changed, and the clone was switched there by hand already;
    one line names the repo, and the record follows."""
    sys_dir, manifest, _, clone = system
    _pin(manifest, "dev")
    git("switch", "-q", "dev", cwd=clone)
    out = _sync(sys_dir, capsys)
    assert "src/a: already on dev; record updated (was main)\n" in out, out
    assert "  up to date (1)\n" in out
    assert state_of(sys_dir)["a"]["version"] == "dev"
    assert _sync(sys_dir, capsys) == "distro (no distro):\n  up to date (1)\n"


def test_a_clone_a_person_fast_forwarded_says_its_record_was_updated(system, capsys):
    sys_dir, _, remote, clone = system
    new = push_commit(remote, "one", "1\n")
    git("pull", "-q", "--ff-only", "origin", "main", cwd=clone)
    out = _sync(sys_dir, capsys)
    assert f"src/a: already on main at {new[:12]}; record updated\n" in out, out
    assert state_of(sys_dir)["a"]["commit"] == new


# --- Pull request 535's second review ------------------------------------------------------


def _git_dir_files(work_tree):
    """Every file of a linked work tree's own git directory (`.git/worktrees/<id>`): its HEAD,
    index and the state of an operation in progress there, by content."""
    git_dir = Path(git("rev-parse", "--absolute-git-dir", cwd=work_tree))
    return {
        str(path.relative_to(git_dir)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(git_dir.rglob("*"))
        if path.is_file()
    }


def _whole(*trees):
    """Every work tree, whole, and each linked one's git directory: to compare before and
    after. Remote-tracking refs and tags are left out, as the fetch may change them."""
    found = [snapshot_repo(tree, fetched=True) for tree in trees]
    found += [_git_dir_files(tree) for tree in trees[1:]]
    return found


def _sequence_editor(*lines):
    """A GIT_SEQUENCE_EDITOR that puts `lines` before the rebase's own to-do list."""
    text = "".join(f"{line}\\n" for line in lines)
    return f'sh -c \'printf "{text}" | cat - "$1" >"$1.new" && mv "$1.new" "$1"\' --'


def _rebase(work_tree, *args, editor=None):
    env = dict(os.environ)
    if editor is not None:
        env["GIT_SEQUENCE_EDITOR"] = editor
    return subprocess.run(
        ["git", "rebase", *args], cwd=work_tree, env=env, capture_output=True, text=True
    )


def _main_held(sys_dir, clone, other, remote, capsys, why):
    """origin's main gains a commit; the clone's main, held by the work tree `other`, is not
    fast-forwarded; every work tree is the same, whole, after; the record is unchanged."""
    push_commit(remote, "new", "new\n")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = _whole(clone, other)
    recorded = state_of(sys_dir)["a"]
    out = _sync(sys_dir, capsys)
    assert _whole(clone, other) == before
    assert state_of(sys_dir)["a"] == recorded
    assert (
        f"src/a: left alone: branch main is held by the work tree {other} ({why}); not"
        " fast-forwarded"
    ) in out, out
    return out


def test_a_branch_under_an_interactive_rebase_in_another_work_tree_is_not_fast_forwarded(
    system, tmp_path, capsys
):
    """Must-fix 1, the reviewer's case: `git worktree add -f` on main, then `rebase -i`
    stopped at `break` and a commit made there. git lists that work tree as detached; its
    `rebase-merge/head-name` names main, which the rebase sets when it ends. The rebase then
    ends as the person meant, with their commit on main."""
    sys_dir, _, remote, clone = system
    other = tmp_path / "wt main"
    git("worktree", "add", "-q", "-f", str(other), "main", cwd=clone)
    stopped = _rebase(other, "-i", "HEAD", editor=_sequence_editor("break"))
    assert stopped.returncode == 0, stopped.stderr
    mine = commit_file(other, "mine.txt", "made during the rebase\n")
    assert "detached" in git("worktree", "list", "--porcelain", cwd=clone)
    _main_held(sys_dir, clone, other, remote, capsys, "a rebase of main is stopped there")
    assert _rebase(other, "--continue").returncode == 0
    assert git("rev-parse", "main", cwd=clone) == mine


def test_a_branch_whose_rebase_stopped_on_a_conflict_in_another_work_tree_is_not_moved(
    system, tmp_path, capsys
):
    """Must-fix 1: a rebase of main stopped on a conflict in another work tree."""
    sys_dir, _, remote, clone = system
    commit_file(tmp_path / "wt-a", ".gitignore", "other\n")  # on the fixture's `feature`
    other = tmp_path / "wt-main"
    git("worktree", "add", "-q", "-f", str(other), "main", cwd=clone)
    stopped = _rebase(other, "--onto", "feature", "main~1")
    assert stopped.returncode != 0 and "CONFLICT" in stopped.stdout + stopped.stderr
    _main_held(sys_dir, clone, other, remote, capsys, "a rebase of main is stopped there")


def test_a_branch_a_bisect_started_on_in_another_work_tree_is_not_moved(system, tmp_path, capsys):
    """Must-fix 1: a bisect started on main in another work tree, which has checked out a
    commit to test (detached); `BISECT_START` names main, where `bisect reset` returns."""
    sys_dir, _, remote, clone = system
    for n in range(3):
        push_commit(remote, f"c{n}", f"{n}\n")
    git("pull", "-q", "--ff-only", "origin", "main", cwd=clone)
    other = tmp_path / "wt-main"
    git("worktree", "add", "-q", "-f", str(other), "main", cwd=clone)
    root = git("rev-list", "--max-parents=0", "main", cwd=clone)
    git("bisect", "start", "main", root, cwd=other)
    assert branch(other) == "HEAD"
    why = "a bisect started on main is in progress there"
    _main_held(sys_dir, clone, other, remote, capsys, why)


def test_a_branch_a_rebase_will_update_in_another_work_tree_is_not_switched_to(
    system, tmp_path, capsys
):
    """Must-fix 1: `rebase --update-refs` of a branch built on the local branch dev, stopped:
    dev is in its `update-refs` list (git itself then refuses `git branch -f dev`). The
    manifest moves to dev: not switched, and every work tree is the same after."""
    sys_dir, manifest, remote, clone = system
    git("branch", "dev", "origin/dev", cwd=clone)
    other = tmp_path / "wt-topic"
    git("worktree", "add", "-q", "-b", "topic", str(other), "dev", cwd=clone)
    commit_file(other, "topic.txt", "on topic\n")
    stopped = _rebase(other, "-i", "--update-refs", "dev~1", editor=_sequence_editor("break"))
    assert stopped.returncode == 0, stopped.stderr
    git_dir = Path(git("rev-parse", "--absolute-git-dir", cwd=other))
    assert "refs/heads/dev" in (git_dir / "rebase-merge" / "update-refs").read_text()
    push_commit(remote, "more", "x\n", "dev")
    _pin(manifest, "dev")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = _whole(clone, other)
    out = _sync(sys_dir, capsys)
    assert _whole(clone, other) == before
    assert (
        f"src/a: left alone: branch dev is held by the work tree {other} (a rebase there will"
        " set dev when it ends (`--update-refs`)); not switched"
    ) in out, out


def test_an_operation_whose_branch_cannot_be_read_holds_every_branch(system, tmp_path, capsys):
    """Must-fix 1: a detached work tree with a rebase in progress whose `head-name` is missing:
    which branch it returns to cannot be told, so no branch is moved."""
    sys_dir, _, remote, clone = system
    other = tmp_path / "wt-detached"
    git("worktree", "add", "-q", "--detach", str(other), "main", cwd=clone)
    (Path(git("rev-parse", "--absolute-git-dir", cwd=other)) / "rebase-merge").mkdir()
    _main_held(
        sys_dir, clone, other, remote, capsys,
        "a rebase is in progress there and the branch it returns to cannot be read",
    )  # fmt: skip


@pytest.mark.parametrize("operation", ["rebase", "am"])
def test_an_operation_on_a_detached_head_in_another_work_tree_holds_no_branch(
    system, tmp_path, capsys, operation
):
    """The neighbours of must-fix 1: a rebase of a detached HEAD (`head-name` is `detached
    HEAD`) and a `git am` on one return to no branch, so the clone's main is fast-forwarded,
    and that work tree is the same after."""
    sys_dir, _, remote, clone = system
    linked = tmp_path / "wt-a"
    commit_file(linked, ".gitignore", "other\n")  # on the fixture's `feature`
    other = tmp_path / "wt-detached"
    if operation == "rebase":
        git("worktree", "add", "-q", "--detach", str(other), "main", cwd=clone)
        assert _rebase(other, "--onto", "feature", "main~1").returncode != 0
    else:
        git("worktree", "add", "-q", "--detach", str(other), "main~1", cwd=clone)
        patch = git("format-patch", "-1", "--stdout", "feature", cwd=clone) + "\n"
        done = subprocess.run(["git", "am"], cwd=other, input=patch, capture_output=True, text=True)
        assert done.returncode != 0
    git_dir = Path(git("rev-parse", "--absolute-git-dir", cwd=other))
    assert (git_dir / ("rebase-merge" if operation == "rebase" else "rebase-apply")).exists()
    new = push_commit(remote, "new", "new\n")
    before = _whole(other)[0], _git_dir_files(other)
    assert "src/a: fast-forwarded 1 commit" in _sync(sys_dir, capsys)
    assert head(clone) == new
    after = snapshot_repo(other, fetched=True)
    for key in ("head", "symbolic", "index", "status", "files", "in progress"):
        assert after[key] == before[0][key], key
    assert _git_dir_files(other) == before[1]


def test_a_local_branch_under_a_rebase_in_another_work_tree_is_not_switched_to(
    system, tmp_path, capsys
):
    """Must-fix 1, the two-step move: the manifest moves to dev, a local branch that another
    work tree is rebasing; neither the switch nor the fast-forward of dev runs."""
    sys_dir, manifest, remote, clone = system
    other = tmp_path / "wt-dev"
    git("worktree", "add", "-q", "-b", "dev", str(other), "origin/dev", cwd=clone)
    stopped = _rebase(other, "-i", "HEAD", editor=_sequence_editor("break"))
    assert stopped.returncode == 0, stopped.stderr
    push_commit(remote, "more", "x\n", "dev")
    _pin(manifest, "dev")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = _whole(clone, other)
    out = _sync(sys_dir, capsys)
    assert _whole(clone, other) == before
    assert (
        f"src/a: left alone: branch dev is held by the work tree {other} (a rebase of dev is"
        " stopped there); not switched"
    ) in out, out


def test_a_work_tree_whose_directory_is_gone_is_named_with_the_prune_command(
    system, tmp_path, capsys
):
    """A work tree holding main whose directory was deleted: the line says the directory is
    gone and gives `git worktree prune`; run as printed, the next sync fast-forwards."""
    sys_dir, _, remote, clone = system
    other = tmp_path / "wt-main"
    git("worktree", "add", "-q", "-f", str(other), "main", cwd=clone)
    subprocess.run(["rm", "-rf", str(other)], check=True)
    new = push_commit(remote, "new", "new\n")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    out = _sync(sys_dir, capsys)
    assert snapshot_repo(clone, fetched=True) == before
    assert (
        f"branch main is held by the work tree {other} (it is checked out there); that"
        " directory no longer exists: if it is gone for good, not on a drive that is not"
        f" mounted, git -C {clone} worktree prune removes git's entries for work trees whose"
        " directories are gone; not fast-forwarded"
    ) in out, out
    command = out.split("not mounted, ", 1)[1].split(" removes git's", 1)[0]
    subprocess.run(command, shell=True, check=True)
    assert "src/a: fast-forwarded 1 commit" in _sync(sys_dir, capsys)
    assert head(clone) == new


def test_a_work_tree_on_a_branch_with_no_commit_does_not_stop_a_repoint(system, tmp_path, capsys):
    """`git worktree add --orphan` lists HEAD as the null id: it has no commit to count, and
    the url is repointed; that work tree is the same after."""
    sys_dir, manifest, remote, clone = system
    lonely = tmp_path / "wt-lonely"
    made = subprocess.run(
        ["git", "worktree", "add", "-q", "--orphan", "-b", "lonely", str(lonely)],
        cwd=clone, capture_output=True, text=True,
    )  # fmt: skip
    if made.returncode != 0:
        pytest.skip(f"this git has no `worktree add --orphan`: {made.stderr.strip()}")
    moved = _bare_copy(remote, "a-moved.git")
    _url(manifest, moved)
    before = _git_dir_files(lonely), snapshot_repo(lonely)["files"]
    out = _sync(sys_dir, capsys)
    assert f"src/a: origin repointed from {remote} to {moved}" in out, out
    assert git("remote", "get-url", "origin", cwd=clone) == str(moved)
    assert (_git_dir_files(lonely), snapshot_repo(lonely)["files"]) == before


# Must-fix 2: a version's kind counts in the comparison with the record.


def _one(tmp_path, version, **remote):
    origin = make_remote(tmp_path / "remotes", "a", **remote)
    sys_dir, manifest = make_system(tmp_path, {"a": repo(origin, version)})
    return sys_dir, manifest, origin, sys_dir / "src/a"


def _commit_on(origin, name, branch="main"):
    """A commit on a new branch of `origin` from `branch`, which stays checked out there."""
    git("checkout", "-q", "-b", name, branch, cwd=origin)
    commit = commit_file(origin, f"{name}.txt", f"{name}\n", f"on {name}")
    git("checkout", "-q", "main", cwd=origin)
    return commit


def test_a_branch_pin_changed_to_the_tag_of_its_name_is_moved_to_the_tag(vcs, tmp_path, capsys):
    """The reviewer's case: on branch release, origin gains a tag release elsewhere, and the
    pin becomes `tags/release`: moved to the tag, not "moved by a person". With both on
    origin, plain `release` stays the error it was, and `heads/release` is the branch."""
    sys_dir, manifest, origin, clone = _one(tmp_path, "main")
    tip = _commit_on(origin, "release")
    _pin(manifest, "release")
    assert "src/a: moved from main to release" in _sync(sys_dir, capsys)
    assert git("symbolic-ref", "HEAD", cwd=clone) == "refs/heads/release" and head(clone) == tip
    git("tag", "release", "main", cwd=origin)
    _pin(manifest, "tags/release")
    out = _sync(sys_dir, capsys)
    assert "src/a: moved from branch release to tag release" in out, out
    assert head(clone) == git("rev-parse", "main", cwd=origin) and branch(clone) == "HEAD"
    assert git("rev-parse", "refs/heads/release", cwd=clone) == tip  # the branch is kept
    assert state_of(sys_dir)["a"]["version"] == "tags/release"
    assert _sync(sys_dir, capsys) == "distro (no distro):\n  up to date (1)\n"
    _pin(manifest, "heads/release")
    assert "src/a: moved from tag release to branch release" in _sync(sys_dir, capsys)
    assert git("symbolic-ref", "HEAD", cwd=clone) == "refs/heads/release" and head(clone) == tip
    _pin(manifest, "release")
    out = _sync(sys_dir, capsys, 1)
    assert "ERROR: src/a: version release is both a branch and a tag on origin" in out, out


def test_a_tag_recorded_as_a_plain_name_then_pinned_as_the_branch_is_moved(vcs, tmp_path, capsys):
    """The other way round: `v2` was the tag (origin had no branch v2); origin gains a branch
    v2, and the pin becomes `heads/v2`: moved to the branch."""
    sys_dir, manifest, origin, clone = _one(tmp_path, "main", tags=["v2"])
    _pin(manifest, "v2")
    assert "src/a: moved from main to v2" in _sync(sys_dir, capsys)
    assert branch(clone) == "HEAD"
    tip = _commit_on(origin, "v2")
    _pin(manifest, "heads/v2")
    out = _sync(sys_dir, capsys)
    assert "src/a: moved from tag v2 to branch v2" in out, out
    assert git("symbolic-ref", "HEAD", cwd=clone) == "refs/heads/v2" and head(clone) == tip


def test_a_tags_version_then_a_plain_name_that_is_now_a_branch_is_moved(vcs, tmp_path, capsys):
    """`tags/v3` recorded; origin deletes the tag and has a branch v3, and the pin becomes
    plain `v3`, which is now the branch: moved to it."""
    sys_dir, manifest, origin, clone = _one(tmp_path, "tags/v3", tags=["v3"])
    assert branch(clone) == "HEAD"
    git("tag", "-d", "v3", cwd=origin)
    tip = _commit_on(origin, "v3")
    _pin(manifest, "v3")
    out = _sync(sys_dir, capsys)
    assert "src/a: moved from tag v3 to branch v3" in out, out
    assert git("symbolic-ref", "HEAD", cwd=clone) == "refs/heads/v3" and head(clone) == tip


def test_a_branch_and_a_tag_both_at_the_recorded_commit_leave_the_repo_alone(vcs, tmp_path, capsys):
    """The record keeps `rel` as written. When origin's new tag rel is at the very commit the
    branch rel was recorded at, which of the two sync followed cannot be told: the repo is
    left as it is, and the report says why, not "moved by a person"."""
    sys_dir, manifest, origin, clone = _one(tmp_path, "main")
    tip = _commit_on(origin, "rel")
    _pin(manifest, "rel")
    _sync(sys_dir, capsys)
    git("tag", "rel", tip, cwd=origin)
    _pin(manifest, "tags/rel")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    out = _sync(sys_dir, capsys)
    assert snapshot_repo(clone, fetched=True) == before
    assert (
        "src/a: left alone: it is on branch rel, and the record (rel) does not say whether sync"
        f" followed the branch or the tag rel: the tag rel here is at the recorded commit"
        f" {tip[:12]}; the manifest names tags/rel; not moved"
    ) in out, out
    assert "moved by a person" not in out


def test_a_recorded_branch_a_person_detached_is_still_theirs(vcs, tmp_path, capsys):
    """The neighbour: a person detaches HEAD at the recorded commit of branch rel, and the
    manifest does not change: left alone as moved by a person, as before."""
    sys_dir, manifest, origin, clone = _one(tmp_path, "main")
    tip = _commit_on(origin, "rel")
    _pin(manifest, "rel")
    _sync(sys_dir, capsys)
    git("switch", "-q", "--detach", "rel", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    out = _sync(sys_dir, capsys)
    assert snapshot_repo(clone, fetched=True) == before
    assert f"moved by a person: it is on a detached HEAD at {tip[:12]}" in out, out
