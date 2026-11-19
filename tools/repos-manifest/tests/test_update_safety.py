"""What `sync` never does to a repo that is there: no git command that can lose or rewrite a
person's work is in the update module, the paths check refuses every file git does not track
that an incoming file would replace, and a repo left alone is the same, byte for byte, after
the run. The whole repo is compared with `snapshot_repo`."""

import ast
import re
import os
from pathlib import Path

import pytest

from helpers import (
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

UPDATE = Path(update.__file__)


GIT_CALLS = ("run", "out", "ok", "count", "ask_origin")
# The names a git call may spread with `*`: each is a function's own parameter (`args`,
# `patterns`, whose callers the scan reads as git calls too), a
# step taken from a list literal (`step`, `back`), or a list literal or `GIT_OPTIONS` bound in
# the module, all of which the scan reads.
SPREAD = {"args", "patterns", "step", "back", "fetch_args", "GIT_OPTIONS"}


def _called(call: ast.Call) -> str:
    return getattr(call.func, "attr", getattr(call.func, "id", ""))


def git_argument_texts(source: str):
    """The git arguments a module's source can run, each list as one text: the constant
    arguments of every `run`, `out`, `ok`, `count` and `ask_origin` call (the last two pass
    theirs to git), every list literal (a step's arguments) and `GIT_OPTIONS`. Tuples elsewhere
    are names and messages, not arguments.

    What it cannot see: an argument held in a variable that is not a list literal (a tuple,
    a string built at run time). `update.py` is written so that this does not matter: every
    git argument is a constant in a call or in a list literal, and the only names a git call
    spreads are those of `SPREAD`, which the test below holds it to."""
    tree = ast.parse(source)
    found = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and _called(node) in GIT_CALLS:
            found.append([a.value for a in node.args if isinstance(a, ast.Constant)])
        elif isinstance(node, ast.List):
            found.append([e.value for e in node.elts if isinstance(e, ast.Constant)])
        elif isinstance(node, ast.Assign) and any(
            getattr(target, "id", "") == "GIT_OPTIONS" for target in node.targets
        ):
            found.append([e.value for e in node.value.elts])
    return [" ".join(str(w) for w in words) for words in found if words]


@pytest.mark.parametrize("word", update.NEVER)
def test_the_update_module_runs_no_command_that_can_lose_work(word):
    texts = git_argument_texts(UPDATE.read_text())
    assert any(text.startswith("merge --ff-only") for text in texts)  # the scan reads steps
    assert any(text.startswith("fetch --tags") for text in texts)  # and calls
    assert any(text.startswith("--no-prune --no-prune-tags") for text in texts)
    for text in texts:
        assert f" {word} " not in f" {text} ", f"{word!r} in {text!r}"


@pytest.mark.parametrize(
    "source, hit",
    [
        ('git.run("fetch", "--prune", "origin")\n', True),
        ('git.run("fetch", "-p", "origin")\n', True),
        ('args = ["fetch", "--prune-tags"]\n', False),
        ('args = ["--no-prune", "--no-prune-tags", "origin"]\n', False),
    ],
)
def test_pruning_flags_are_forbidden_and_no_prune_is_not(source, hit):
    texts = git_argument_texts(source)
    found = [w for w in ("--prune", "-p") for t in texts if f" {w} " in f" {t} "]
    assert {"--prune", "-p"} <= set(update.NEVER)
    assert bool(found) == hit, (texts, found)


BUNDLED = re.compile(r"-[A-Za-z]{2,}")


def bundled_with(texts, letters="pPf"):
    """Short flags bundled into one word (`-pt`, `-fq`) that hold a forbidden letter."""
    return [
        word
        for text in texts
        for word in text.split()
        if BUNDLED.fullmatch(word) and any(letter in word for letter in letters)
    ]


def test_no_bundled_short_flag_holds_p_or_f():
    assert bundled_with(git_argument_texts(UPDATE.read_text())) == []


@pytest.mark.parametrize(
    "source, hit",
    [
        ('git.run("fetch", "-P", "origin")\n', True),
        ('git.run("fetch", "--prune", "--prune-tags", "origin")\n', True),
        ('steps = [["switch", "-f", "dev"]]\n', True),
        ('steps = [["switch", "--discard-changes", "dev"]]\n', True),
        ('git.run("branch", "-f", "dev", "x")\n', True),
        ('git.run("fetch", "-pt", "origin")\n', True),
        ('git.run("switch", "-fq", "dev")\n', True),
        ('git.run("fetch", "--no-prune", "--no-prune-tags", "-q", "origin")\n', False),
        ('count(git, "HEAD", "--not", "--remotes=origin")\n', False),
    ],
)
def test_the_scan_catches_each_way_of_forcing_or_pruning(source, hit):
    texts = git_argument_texts(source)
    words = [w for w in update.NEVER for t in texts if f" {w} " in f" {t} "]
    assert bool(words or bundled_with(texts)) == hit, (texts, words)


def test_a_git_call_spreads_only_names_the_scan_reads():
    tree = ast.parse(UPDATE.read_text())
    spread = {
        arg.value.id
        for node in ast.walk(tree)
        if isinstance(node, ast.Call) and _called(node) in GIT_CALLS
        for arg in node.args
        if isinstance(arg, ast.Starred) and isinstance(arg.value, ast.Name)
    }
    assert spread <= SPREAD, spread - SPREAD
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and any(
            getattr(t, "id", "") == "fetch_args" for t in node.targets
        ):
            assert isinstance(node.value, ast.List)


def test_the_scan_finds_a_forbidden_command():
    source = 'git.run("stash", "push")\nsteps = [["reset", "--hard", "x"]]\n'
    texts = git_argument_texts(source)
    assert "stash push" in texts and "reset --hard x" in texts


def test_every_git_call_turns_off_gc_maintenance_and_submodule_recursion():
    options = " ".join(update.GIT_OPTIONS)
    for setting in ("gc.auto=0", "maintenance.auto=false", "submodule.recurse=false"):
        assert f"-c {setting}" in options


# --- The paths check, on every call that changes the tree ----------------------------------


@pytest.fixture
def system(vcs, tmp_path):
    """A flat system with repo `a` on main, cloned from a remote whose `.gitignore` ignores
    `*.log` and `cache/`; the remote also has a branch `dev` and a tag `v1`."""
    remote = make_remote(tmp_path / "remotes", "a", branches=["dev"], tags=["v1"])
    commit_file(remote, ".gitignore", "*.log\ncache/\n", "ignore")
    git("branch", "-f", "dev", "main", cwd=remote)
    sys_dir, manifest = make_system(tmp_path, {"a": repo(remote, "main")})
    return sys_dir, manifest, remote, sys_dir / "src" / "a"


def _incoming(remote, path, branch="main"):
    return push_commit(remote, path, "incoming\n", branch)


def _pin(manifest, version):
    def change(data):
        data["repositories"]["a"]["version"] = version

    rewrite_manifest(manifest, change)


def _tag(remote, name, path):
    """A tag `name` on a new commit of a side branch that adds `path`."""
    git("checkout", "-q", "-b", f"side-{name}", "main", cwd=remote)
    commit_file(remote, path, "incoming\n", f"for {name}")
    git("tag", name, cwd=remote)
    git("checkout", "-q", "main", cwd=remote)


def _move_kind(kind, remote, manifest, clone, path):
    """Make the manifest's change that brings `path` in by a move of `kind`."""
    if kind == "fast-forward":
        _incoming(remote, path)
    elif kind == "switch to a new branch":
        git("branch", "-f", "dev2", "main", cwd=remote)
        _incoming(remote, path, "dev2")
        _pin(manifest, "dev2")
    elif kind == "switch to a local branch, then fast-forward":
        git("branch", "-f", "dev3", "main", cwd=remote)
        git("fetch", "-q", "origin", cwd=clone)
        git("branch", "-q", "dev3", "origin/dev3", cwd=clone)
        _incoming(remote, path, "dev3")
        _pin(manifest, "dev3")
    else:  # a detached switch to a tag
        _tag(remote, "v9", path)
        _pin(manifest, "v9")


KINDS = [
    "fast-forward",
    "switch to a new branch",
    "switch to a local branch, then fast-forward",
    "detached switch to a tag",
]


@pytest.mark.parametrize("kind", KINDS)
@pytest.mark.parametrize("what", ["ignored", "untracked"])
def test_a_file_git_does_not_track_where_an_incoming_file_goes_stops_the_move(
    system, capsys, kind, what
):
    sys_dir, manifest, remote, clone = system
    name = "local.log" if what == "ignored" else "local.txt"
    (clone / name).write_text("a person's file\n")
    _move_kind(kind, remote, manifest, clone, name)
    git("fetch", "-q", "--tags", "origin", cwd=clone)  # what sync fetches, so refs compare
    before = snapshot_repo(clone, fetched=True)
    recorded = state_of(sys_dir)["a"]
    capsys.readouterr()
    assert run(sys_dir, "sync") == 0
    assert snapshot_repo(clone, fetched=True) == before
    assert (clone / name).read_text() == "a person's file\n"
    out = capsys.readouterr().out
    shown = f"{name} (ignored)" if what == "ignored" else name
    assert (
        f"src/a: left alone: 1 paths not tracked here are in the way of incoming files: {shown};"
        " not updated" in out
    ), out
    assert {k: v for k, v in state_of(sys_dir)["a"].items() if k != "moving"} == recorded


@pytest.mark.parametrize("kind", KINDS)
def test_a_file_where_an_incoming_directory_goes_stops_the_move(system, capsys, kind):
    sys_dir, manifest, remote, clone = system
    (clone / "cache.log").write_text("a person's file\n")  # ignored, where a directory comes
    _move_kind(kind, remote, manifest, clone, "cache.log/inside")
    git("fetch", "-q", "--tags", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    capsys.readouterr()
    assert run(sys_dir, "sync") == 0
    assert snapshot_repo(clone, fetched=True) == before
    assert "in the way of incoming files: cache.log (ignored)" in capsys.readouterr().out


def _dir_becomes_a_file(remote):
    """A tracked directory `foo` on main; returns what replaces it, upstream, with a file."""
    commit_file(remote, "foo/a", "a\n", "a directory")

    def replace():
        git("rm", "-q", "-r", "foo", cwd=remote)
        commit_file(remote, "foo", "now a file\n", "the directory is a file")

    return replace


def test_a_directory_replaced_by_a_file_holding_an_ignored_file_stops_it(system, capsys):
    sys_dir, _, remote, clone = system
    replace = _dir_becomes_a_file(remote)
    assert run(sys_dir, "sync") == 0
    (clone / "foo" / "keep.log").write_text("PRECIOUS\n")
    replace()
    git("fetch", "-q", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    capsys.readouterr()
    assert run(sys_dir, "sync") == 0
    assert snapshot_repo(clone, fetched=True) == before
    assert (clone / "foo" / "keep.log").read_text() == "PRECIOUS\n"
    assert "in the way of incoming files: foo;" in capsys.readouterr().out


def test_a_directory_replaced_by_a_file_holding_only_tracked_files_is_followed(system, capsys):
    sys_dir, _, remote, clone = system
    replace = _dir_becomes_a_file(remote)
    assert run(sys_dir, "sync") == 0
    replace()
    assert run(sys_dir, "sync") == 0
    assert (clone / "foo").read_text() == "now a file\n"
    assert head(clone) == head(remote)


def test_an_ignored_link_where_an_incoming_directory_goes_is_never_taken_for_one(
    system, tmp_path, capsys
):
    sys_dir, _, remote, clone = system
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    (elsewhere / "x").write_text("X\n")
    (clone / ".git" / "info" / "exclude").write_text("lnk\n")
    (clone / "lnk").symlink_to(elsewhere)
    commit_file(remote, "lnk/new", "n\n", "a directory where the link is")
    git("fetch", "-q", "origin", cwd=clone)
    before = snapshot_repo(clone, fetched=True)
    capsys.readouterr()
    assert run(sys_dir, "sync") == 0
    assert snapshot_repo(clone, fetched=True) == before
    assert os.path.islink(clone / "lnk")
    assert os.listdir(elsewhere) == ["x"]
    assert "in the way of incoming files: lnk (ignored)" in capsys.readouterr().out


def test_more_than_ten_paths_in_the_way_are_counted(system, capsys):
    sys_dir, _, remote, clone = system
    for n in range(12):
        (clone / f"f{n:02}.log").write_text("mine\n")
        commit_file(remote, f"f{n:02}.log", "incoming\n", f"file {n}")
    assert run(sys_dir, "sync") == 0
    out = capsys.readouterr().out
    assert "12 paths not tracked here are in the way of incoming files: f00.log (ignored)" in out
    assert "f09.log (ignored) and 2 more; not updated" in out


def test_untracked_files_elsewhere_do_not_stop_a_fast_forward(system, capsys):
    sys_dir, _, remote, clone = system
    (clone / "notes.txt").write_text("mine\n")
    (clone / "build.log").write_text("ignored\n")
    _incoming(remote, "new.txt")
    assert run(sys_dir, "sync") == 0
    assert head(clone) == head(remote)
    assert (clone / "notes.txt").read_text() == "mine\n"
    assert (clone / "build.log").read_text() == "ignored\n"
    assert "src/a: fast-forwarded 1 commits" in capsys.readouterr().out
