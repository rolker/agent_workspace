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
    (clone / "README").write_text("left by a stopped switch\n")
    _left_alone(
        sys_dir,
        clone,
        capsys,
        f"a sync was stopped while moving this repo from {head(clone)[:12]} to {target[:12]};"
        " `git status` shows what it left",
    )


def test_a_moving_line_is_not_used_once_a_person_moved_the_repo(system, capsys):
    sys_dir, _, remote, clone = system
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    data["distros"]["_unnamed"]["repos"]["a"]["moving"] = {"from": "1" * 40, "to": "2" * 40}
    state.write_text(yaml.safe_dump(data))
    (clone / "README").write_text("mine\n")
    out = _left_alone(sys_dir, clone, capsys, "has uncommitted changes (1 files)")
    assert "a sync was stopped" not in out


def test_a_moving_line_is_removed_when_the_repo_is_found_on_the_version(system, capsys):
    sys_dir, _, _, clone = system
    state = sys_dir / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    data["distros"]["_unnamed"]["repos"]["a"]["moving"] = {"from": "1" * 40, "to": head(clone)}
    state.write_text(yaml.safe_dump(data))
    assert "up to date (1)" in _sync(sys_dir, capsys)
    assert "moving" not in state_of(sys_dir)["a"]


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


def test_a_tag_moved_on_origin_is_reported_with_its_next_step(system, capsys):
    sys_dir, _, remote, clone = system
    git("tag", "-f", "v1", "other", cwd=remote)
    out = _sync(sys_dir, capsys, 1)
    assert (
        f"tag v1 was moved on origin, and sync never replaces a tag: to take origin's, git -C"
        f" {clone} tag -d v1, then sync again"
    ) in out
    assert git("rev-parse", "v1^{commit}", cwd=clone) != git("rev-parse", "other", cwd=remote)


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
    assert "version dev is not on origin; origin was set by hand: origin is" in out
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
