"""The repos `status` is tested on, one builder per case, shared by `test_status.py` and
`test_status_agrees_with_sync.py`. Each builder takes a `Case` (a flat system with repo `a`
on main, cloned from a remote with branches dev and other and a tag v1) and leaves repo `a` in
the case's state. Imported by the tests, not collected."""

from __future__ import annotations

import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

import yaml

from helpers import commit_file, git, head, make_remote, make_system, repo, rewrite_manifest, run


@dataclass
class Case:
    tmp: Path
    system: Path
    manifest: Path
    remote: Path
    clone: Path


def make_case(tmp: Path, optional: bool = False) -> Case:
    remote = make_remote(tmp / "remotes", "a", branches=["dev", "other"], tags=["v1"])
    system, manifest = make_system(tmp, {"a": repo(remote, "main", optional=optional)})
    return Case(tmp, system, manifest, remote, system / "src" / "a")


def pin(case: Case, version) -> None:
    def change(data):
        data["repositories"]["a"]["version"] = version

    rewrite_manifest(case.manifest, change)


def set_moving(case: Case, moving) -> None:
    state = case.system / ".repos-manifest/state.yaml"
    data = yaml.safe_load(state.read_text())
    data["distros"]["_unnamed"]["repos"]["a"]["moving"] = moving
    state.write_text(yaml.safe_dump(data))


def sync(case: Case) -> None:
    assert run(case.system, "sync") == 0


def _quiet(*args, cwd) -> int:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, check=False).returncode


# --- expected -------------------------------------------------------------------------------


def on_branch(case):
    pass


def pinned_tag(case):
    pin(case, "v1")
    sync(case)


def pinned_commit(case):
    pin(case, head(case.remote)[:12])
    sync(case)


def behind(case):
    commit_file(case.remote, "one", "1\n")
    git("fetch", "-q", "origin", cwd=case.clone)  # the last fetch, by hand


def behind_held_by_a_work_tree(case):
    behind(case)
    git("worktree", "add", "-q", "-f", str(case.tmp / "wt"), "main", cwd=case.clone)


def changes_on_its_branch(case):
    (case.clone / "README").write_text("mine\n")


def behind_with_changes(case):
    """`sync` stops at the changes before it would fast-forward."""
    behind(case)
    (case.clone / "README").write_text("mine\n")


def url_changed(case):
    """The manifest names a copy of the remote; origin is still the url recorded."""
    copy = case.tmp / "remotes" / "a-copy"
    shutil.copytree(case.remote, copy)

    def change(data):
        data["repositories"]["a"]["url"] = str(copy)

    rewrite_manifest(case.manifest, change)


def url_changed_probe_taken(case):
    """The url changed, and a person has a remote of the name `sync` keeps for the probe."""
    url_changed(case)
    git("remote", "add", "repos-manifest-probe", str(case.remote), cwd=case.clone)


def behind_probe_taken(case):
    behind(case)
    url_changed_probe_taken(case)


def no_version(case):
    """The manifest names no version: origin's default branch, which the clone is on."""
    rewrite_manifest(case.manifest, lambda data: data["repositories"]["a"].pop("version"))


def behind_with_no_version(case):
    no_version(case)
    behind(case)


def commits_only_here(case):
    commit_file(case.clone, "mine", "mine\n", "mine")


def fast_forwarded_by_hand(case):
    """What `merge_pr.sh` does after a pull request merges: past the recorded commit."""
    commit_file(case.remote, "merged", "m\n", "merged")
    git("pull", "-q", "--ff-only", "origin", "main", cwd=case.clone)


def tag_on_no_branch(case):
    """Pinned detached at a tag whose commit no branch of origin holds."""
    git("checkout", "-q", "-b", "side", "main", cwd=case.remote)
    commit_file(case.remote, "side", "s\n", "side")
    git("tag", "v9", cwd=case.remote)
    git("checkout", "-q", "main", cwd=case.remote)
    git("branch", "-q", "-D", "side", cwd=case.remote)
    pin(case, "v9")
    sync(case)


def stopped_move_clean(case):
    set_moving(case, {"from": "1" * 40, "to": head(case.clone)})


def deleted_branch(case):
    """Pinned to dev, which origin then deleted: the remote-tracking ref stays here."""
    pin(case, "dev")
    sync(case)
    git("branch", "-q", "-D", "dev", cwd=case.remote)


# --- different ------------------------------------------------------------------------------


def other_branch(case):
    git("switch", "-q", "--track", "origin/other", cwd=case.clone)


def detached_elsewhere(case):
    git("switch", "-q", "--detach", "origin/other", cwd=case.clone)


def manifest_changed_version(case):
    pin(case, "dev")


def manifest_changed_version_with_changes(case):
    pin(case, "dev")
    (case.clone / "README").write_text("mine\n")


def manifest_changed_version_with_commits(case):
    pin(case, "dev")
    commit_file(case.clone, "mine", "mine\n", "mine")


def manifest_changed_to_a_local_branch_with_commits(case):
    pin(case, "dev")
    git("branch", "-q", "--no-track", "dev", "origin/dev", cwd=case.clone)
    git("switch", "-q", "dev", cwd=case.clone)
    commit_file(case.clone, "mine", "mine\n", "mine")
    git("switch", "-q", "main", cwd=case.clone)


def rewritten_upstream(case):
    git("commit", "-q", "--amend", "-m", "rewritten", cwd=case.remote)
    git("fetch", "-q", "origin", cwd=case.clone)


def ahead_on_another_origin_branch(case):
    """HEAD moved by hand past origin's main, onto origin's other: nothing only here."""
    git("merge", "-q", "--ff-only", "origin/other", cwd=case.clone)


def local_tag_origin_lacks(case):
    git("tag", "v7", cwd=case.clone)
    pin(case, "v7")


def moved_tag(case):
    """Pinned at v1; origin moved the tag, and the person deleted the stale tag here and
    fetched again, as `sync`'s failed fetch told them to."""
    pinned_tag(case)
    commit_file(case.remote, "later", "l\n", "later")
    git("tag", "-f", "v1", cwd=case.remote)
    git("tag", "-d", "v1", cwd=case.clone)
    git("fetch", "-q", "--tags", "origin", cwd=case.clone)


# --- left-alone -----------------------------------------------------------------------------


def link_at_the_place(case):
    elsewhere = case.tmp / "elsewhere-a"
    os.rename(case.clone, elsewhere)
    case.clone.symlink_to(elsewhere)


def _side_commit(case):
    git("switch", "-q", "-c", "side", cwd=case.clone)
    commit_file(case.clone, "README", "side\n", "side")
    git("switch", "-q", "main", cwd=case.clone)


def rebase_in_progress(case):
    base = head(case.clone)
    _side_commit(case)
    git("switch", "-q", "-c", "topic", base, cwd=case.clone)
    commit_file(case.clone, "README", "topic\n", "topic")
    assert _quiet("rebase", "side", cwd=case.clone) != 0


def merge_in_progress(case):
    _side_commit(case)
    commit_file(case.clone, "README", "main\n", "main")
    assert _quiet("merge", "side", cwd=case.clone) != 0


def bisect_in_progress(case):
    git("bisect", "start", cwd=case.clone)


def index_lock(case):
    (case.clone / ".git/index.lock").write_text("")


def sparse_checkout(case):
    git("config", "core.sparseCheckout", "true", cwd=case.clone)


def two_origin_urls(case):
    git("config", "--add", "remote.origin.url", str(case.tmp / "elsewhere"), cwd=case.clone)


def stopped_move_in_a_merge(case):
    merge_in_progress(case)
    set_moving(case, {"from": head(case.clone), "to": "2" * 40})


# --- unusable -------------------------------------------------------------------------------


def not_a_git_repository(case):
    shutil.rmtree(case.clone)
    case.clone.mkdir()
    (case.clone / "file").write_text("x\n")


def no_commit(case):
    shutil.rmtree(case.clone)
    case.clone.mkdir()
    git("init", "-q", "-b", "main", cwd=case.clone)


def version_not_fetched(case):
    git("branch", "-q", "new", "main", cwd=case.remote)
    pin(case, "new")


def git_status_fails(case):
    (case.clone / ".git/index").write_bytes(b"not an index")


def no_origin_url(case):
    git("config", "--unset-all", "remote.origin.url", cwd=case.clone)


# --- not at its place -----------------------------------------------------------------------


def missing(case):
    shutil.rmtree(case.clone)


def a_file_at_the_place(case):
    shutil.rmtree(case.clone)
    case.clone.write_text("a file\n")


def a_link_on_the_way(case):
    """The layer's `src` directory is a link to somewhere else, with the clone inside it."""
    src = case.system / "src"
    os.rename(src, case.tmp / "elsewhere-src")
    src.symlink_to(case.tmp / "elsewhere-src")


def in_another_layer(case):
    """The manifest gives the repo a layer; its record, and the clone, are in the unnamed one."""

    def change(data):
        data["layers"] = ["core"]
        data["repositories"]["a"]["layer"] = "core"

    rewrite_manifest(case.manifest, change)


# name: (builder, state, a piece of the detail)
CASES = {
    "on its branch": (on_branch, "expected", "on main"),
    "pinned at a tag": (pinned_tag, "expected", "pinned at v1"),
    "pinned at a commit": (pinned_commit, "expected", "pinned at"),
    "behind origin": (behind, "expected", "behind origin's"),
    "behind, held by a work tree": (behind_held_by_a_work_tree, "expected", "is held by"),
    "on its branch, with changes": (changes_on_its_branch, "expected", "on main"),
    "behind, with changes": (
        behind_with_changes,
        "expected",
        "sync leaves it while it has uncommitted changes (1 file)",
    ),
    "a url changed": (url_changed, "expected", "sync tries to repoint origin"),
    "a url changed, probe remote taken": (
        url_changed_probe_taken,
        "expected",
        "a remote named repos-manifest-probe is set here",
    ),
    "behind, probe remote taken": (
        behind_probe_taken,
        "expected",
        "sync leaves it while a remote named repos-manifest-probe is set here",
    ),
    "no version": (no_version, "expected", "on main, as origin's was"),
    "behind, no version": (behind_with_no_version, "expected", "sync tries to fast-forward it"),
    "commits only here": (commits_only_here, "expected", "1 commit not on origin"),
    "fast-forwarded by hand": (fast_forwarded_by_hand, "expected", "on main"),
    "a tag on no branch": (tag_on_no_branch, "expected", "pinned at v9"),
    "a stopped move, clean": (stopped_move_clean, "expected", "a sync was stopped"),
    "a branch origin deleted": (deleted_branch, "expected", "on dev"),
    "another branch": (other_branch, "different", "it is on branch other"),
    "detached elsewhere": (detached_elsewhere, "different", "a detached HEAD"),
    "the manifest changed version": (
        manifest_changed_version,
        "different",
        "sync would try to move it",
    ),
    "changed version, with changes": (
        manifest_changed_version_with_changes,
        "different",
        "sync leaves it while it has uncommitted changes",
    ),
    "changed version, with commits": (
        manifest_changed_version_with_commits,
        "different",
        "sync leaves it while it has 1 commit not on origin",
    ),
    "changed to a local branch with commits": (
        manifest_changed_to_a_local_branch_with_commits,
        "different",
        "a local branch dev has commits not on origin",
    ),
    "rewritten upstream": (rewritten_upstream, "different", "(rewritten upstream)"),
    "ahead on another origin branch": (
        ahead_on_another_origin_branch,
        "different",
        "(rewritten upstream)",
    ),
    "a local tag origin lacks": (local_tag_origin_lacks, "different", "sync would try"),
    "a moved tag": (moved_tag, "different", "sync would try to move it"),
    "a link at the place": (link_at_the_place, "left-alone", "is a link to"),
    "a rebase in progress": (rebase_in_progress, "left-alone", "a rebase is in progress"),
    "a merge in progress": (merge_in_progress, "left-alone", "a merge is in progress"),
    "a bisect in progress": (bisect_in_progress, "left-alone", "a bisect is in progress"),
    "an index.lock": (index_lock, "left-alone", "index.lock exists"),
    "a sparse checkout": (sparse_checkout, "left-alone", "is a sparse checkout"),
    "two origin urls": (two_origin_urls, "left-alone", "has no single origin"),
    "a stopped move in a merge": (stopped_move_in_a_merge, "left-alone", "a sync was stopped"),
    "not a git repository": (not_a_git_repository, "unusable", "not a git repository"),
    "no commit": (no_commit, "unusable", "has no commit checked out"),
    "a version not fetched": (version_not_fetched, "unusable", "version new is not on origin"),
    "git status fails": (git_status_fails, "unusable", "`git status` fails here"),
    "no origin url": (no_origin_url, "unusable", "has no single origin"),
    "missing": (missing, "missing", "is not there"),
    "a file at the place": (a_file_at_the_place, "not-a-directory", "is not a directory"),
    "a link on the way": (a_link_on_the_way, "blocked-place", "a link on the way"),
    "in another layer": (in_another_layer, "in-other-layer", "the manifest now has it in layer"),
}

# The states that fail the exit status for a repo that is not optional.
FAILING = {"unusable", "missing", "not-a-directory", "blocked-place", "in-other-layer"}
