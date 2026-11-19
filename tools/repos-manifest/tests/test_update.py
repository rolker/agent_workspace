"""`sync` for a repo that is there, rule by rule (``docs/design.md``, "sync"): a clean clone on
the manifest's version is followed; one on the recorded version is moved to the manifest's new
one; anything a person did (changes, commits, another branch, an operation in progress, an
`origin` of their own) is left as it is and reported, and the repo compares equal, whole, before
and after (`snapshot_repo`)."""

import os
import subprocess

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
    assert "fast-forwarded 1 commits" in _sync(sys_dir, capsys)
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
    assert "fast-forwarded 1 commits" in _sync(sys_dir, capsys)
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
        assert "fast-forwarded 1 commits" in out
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
    _left_alone(sys_dir, clone, capsys, "src/a: left alone: has uncommitted changes (1 files)")


def test_tracked_changes_also_stop_a_changed_pin(system, capsys):
    sys_dir, manifest, _, clone = system
    (clone / "README").write_text("mine\n")
    _pin(manifest, "dev")
    _left_alone(sys_dir, clone, capsys, "has uncommitted changes (1 files)")
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
    out = _left_alone(sys_dir, clone, capsys, "src/a: left alone: has 1 commits not on origin")
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
    _left_alone(sys_dir, clone, capsys, "src/a: left alone: has 1 commits not on origin;")


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
        f"left alone: has uncommitted changes (1 files); a sync was stopped while moving this"
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
    assert "src/a: left alone: has uncommitted changes (1 files)\n" in out
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
        sys_dir, clone, capsys, f"branch dev is checked out in {tmp_path / 'wt-dev'}; not switched"
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
    assert "src/a: fast-forwarded 1 commits" in out
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


def test_the_url_probe_never_writes_local_branches_whatever_its_config_says(system, capsys):
    sys_dir, manifest, remote, clone = system
    copy = _bare_copy(remote, "a-copy.git")
    git("branch", "-q", "dev", "origin/dev", cwd=clone)
    mine = git("rev-parse", "dev", cwd=clone)
    git("config", f"remote.{update.PROBE}.fetch", "+refs/heads/*:refs/heads/*", cwd=clone)
    push_commit(remote, "theirs", "t\n", "dev")
    git("push", "-q", str(copy), "dev:dev", cwd=remote)
    _url(manifest, str(copy))
    out = _sync(sys_dir, capsys)
    assert f"src/a: origin repointed from {remote} to {copy}" in out, out
    assert git("rev-parse", "dev", cwd=clone) == mine
    assert "feature" in git("branch", "--format=%(refname:short)", cwd=clone).split()


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
    assert "src/a: fast-forwarded 1 commits" in out
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
        f"url changed to {moved} but 1 local commits (branches other) are not on it; origin"
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
    assert "the manifest's url changed to" in out and f"(origin stays {remote})" in out


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
    assert "fast-forwarded 1 commits" in out
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
    assert "src/top: fast-forwarded 1 commits" in out
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
    assert "src/top: left alone: has uncommitted changes (1 files)" in out


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
    assert "fast-forwarded 1 commits" in _sync(sys_dir, capsys)
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
    out = _sync(sys_dir, capsys, 1)
    assert "`git switch` exited 0 and left the repo half-changed: HEAD was at" in out, out
    assert f"is at {local[:12]} (refs/heads/dev); changed, not staged: M README" in out, out
    assert head(clone) == local  # not fast-forwarded on a tree a hook changed
    assert "moving" not in state_of(sys_dir)["a"]


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
        says = "left alone: has 1 commits not on origin"
    elif work == "a changed file":
        (old / "README").write_text("mine\n")
        says = "left alone: has uncommitted changes (1 files)"
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
