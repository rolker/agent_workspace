"""What `sync` never does to a repo that is there: no git command that can lose or rewrite a
person's work is in the update module, the paths check refuses every file git does not track
that an incoming file would replace, and a repo left alone is the same, byte for byte, after
the run. The whole repo is compared with `snapshot_repo`.

`NEVER` and its scan do not look for every form that can lose work. `update.py` does fetch
with a forced refspec into remote-tracking refs (`+refs/heads/*:refs/remotes/origin/*`, and
into its own probe refs under `refs/remotes/`), and does run `update-ref --no-deref -d` on
those probe refs only, the one ref deletion it makes (`--no-deref`: a symbolic ref there is
removed itself, never what it points to; a test below holds it to that); neither touches a
local branch, a tag or the work tree. The scan does not look for
these forms, nor for `reset --merge`, `reset --keep` and `checkout -B`, which `update.py` does
not run."""

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
from repos_manifest import status as status_module
from repos_manifest import sync as sync_module
from repos_manifest import update

UPDATE = Path(update.__file__)


GIT_CALLS = ("run", "out", "ok", "count", "ask_origin", "ask", "ask_local")
# The names a git call may spread with `*`: each is a function's own parameter (`args`,
# `patterns`, whose callers the scan reads as git calls too), a
# step taken from a list literal (`step`, `back`), or a list literal or `GIT_OPTIONS` bound in
# the module, all of which the scan reads; `patterns` in `find_version` is built of `refs/...`
# texts; and `heads`, the commit ids `git worktree list` gives, each checked to be one.
SPREAD = {"args", "patterns", "step", "back", "fetch_args", "GIT_OPTIONS", "heads"}


def _called(call: ast.Call) -> str:
    return getattr(call.func, "attr", getattr(call.func, "id", ""))


def git_argument_texts(source: str):
    """The git arguments a module's source can run, each list as one text: the constant
    arguments of every `run`, `out`, `ok`, `count`, `ask_origin`, `ask` and `ask_local` call
    (the last four pass theirs to git; `ask` is the parameter `find_version` and
    `commit_on_origin` call through), every list literal (a step's arguments) and
    `GIT_OPTIONS`. Tuples elsewhere are names and messages, not arguments.

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


def forbidden(text: str, never=update.NEVER):
    """The entries of `never` in one git argument text. A one-word entry is any word of the
    text. A command with its flag (`switch -f`) is the command and then the flag anywhere
    after it, not only next to it: `switch -q -f dev` holds `switch -f`."""
    words = text.split()
    found = []
    for entry in never:
        command, *flag = entry.split()
        if command not in words:
            continue
        after = words[words.index(command) + 1 :]
        if not flag or all(f in after for f in flag):
            found.append(entry)
    return found


@pytest.mark.parametrize("word", update.NEVER)
def test_the_update_module_runs_no_command_that_can_lose_work(word):
    texts = git_argument_texts(UPDATE.read_text())
    assert any(text.startswith("merge --ff-only") for text in texts)  # the scan reads steps
    assert any(text.startswith("fetch --tags") for text in texts)  # and calls
    assert any(text.startswith("--no-prune --no-prune-tags") for text in texts)
    for text in texts:
        assert word not in forbidden(text, (word,)), f"{word!r} in {text!r}"


@pytest.mark.parametrize(
    "source, hit",
    [
        ('git.run("fetch", "--prune", "origin")\n', True),
        ('git.run("fetch", "-p", "origin")\n', True),
        ('args = ["fetch", "--prune-tags"]\n', True),  # forbidden: it prunes local tags
        ('args = ["--no-prune", "--no-prune-tags", "origin"]\n', False),
    ],
)
def test_pruning_flags_are_forbidden_and_no_prune_is_not(source, hit):
    texts = git_argument_texts(source)
    found = [w for t in texts for w in forbidden(t)]
    assert {"--prune", "-p", "--prune-tags"} <= set(update.NEVER)
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
        ('git.run("fetch", "--prune-tags", "origin")\n', True),  # NEVER's --prune-tags alone
        ('steps = [["switch", "-q", "-f", "dev"]]\n', True),  # a flag not next to its command
        ('git.run("branch", "-q", "-f", "dev", "x")\n', True),
        ('steps = [["reset", "-q", "--hard", "x"]]\n', True),
        ('git.run("switch", "-q", "dev")\n', False),
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
    words = [w for t in texts for w in forbidden(t)]
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


def test_the_only_ref_deletion_is_of_probe_refs_without_following_a_symbolic_ref():
    texts = [t for t in git_argument_texts(UPDATE.read_text()) if t.startswith("update-ref")]
    assert texts == ["update-ref --no-deref -d"], texts
    source = UPDATE.read_text()
    body = source[source.index("def delete_probe_refs") : source.index("def probe_taken")]
    assert 'prefix = f"refs/remotes/{PROBE}/"' in body and "ref.startswith(prefix)" in body


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
        f"src/a: left alone: 1 path not tracked here is in the way of incoming files: {shown};"
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
    assert "src/a: fast-forwarded 1 commit" in capsys.readouterr().out


def test_every_fetch_passes_no_recurse_submodules_and_no_prune():
    """Pull request 535's second review: the url probe's fetch, like the main one, passes
    `--no-recurse-submodules` and `--no-prune`, so the person's `fetch.recurseSubmodules` and
    `fetch.prune` never apply to it (the main fetch spreads `fetch_args`, which hold both)."""
    texts = git_argument_texts(UPDATE.read_text())
    fetches = [t for t in texts if "fetch" in t.split() and "--refmap=" in t.split()]
    assert any(t.startswith("-c") for t in fetches), fetches  # the probe's is among them
    for text in fetches:
        words = text.split()
        assert "--no-recurse-submodules" in words and "--no-prune" in words, text


# --- `status` reads only -----------------------------------------------------------------

STATUS = Path(status_module.__file__)

# The git commands `status.py` and the functions of `update` it reaches may run, and the
# functions of `update` and `sync` it may call: each reads only. A call to any other (`_move`,
# `_change`, `_repoint`, `delete_probe_refs`, `update_repo`, `left_the_manifest`, ...) fails the
# scan. `config` reads only in the forms `CONFIG_READS` names, and `worktree` only as `list`.
READ_ONLY_GIT = {
    "rev-parse",
    "symbolic-ref",
    "config",
    "for-each-ref",
    "rev-list",
    "merge-base",
    "status",
    "ls-files",
    "ls-tree",
    "cat-file",
    "worktree",
}
CONFIG_READS = {"--get", "--get-all", "--get-regexp", "--list", "-l"}
CONFIG_WRITES = {
    "--add",
    "--unset",
    "--unset-all",
    "--replace-all",
    "--rename-section",
    "--remove-section",
    "--edit",
    "-e",
    "set",
    "unset",
    "rename-section",
    "remove-section",
    "edit",
}
STATUS_MAY_CALL = {
    "update": {
        "Git",
        "blocked_early",
        "blocked_late",
        "stopped_move",
        "tracked_changes",
        "count",
        "find_version",
        "commit_on_origin",
        "ask_local",
        "standing",
        "probe_taken",
        "same_url",
        "quoted",
        "counted",
    },
    "sync": {"require_git", "resolve_all", "layer_moved", "Reported"},
}
# What a function `status` reaches in `update.py` may not pass or call: a git that changes the
# work tree or the configuration (`change`), holds the lock (`hold`) or may prompt (`prompt`,
# only a fetch or `ls-remote`), or a function that writes or asks origin.
WRITES = {"change", "hold", "prompt"}
NEVER_REACHED = {"_move", "_change", "_repoint", "delete_probe_refs", "ask_origin", "update_repo"}
# What a function `status` reaches in `sync.py` may not call: a function that writes a file,
# a directory, a record or a lock, clones, or updates a repo.
SYNC_NEVER_CALLED = {
    "write_output",
    "put_distro_state",
    "hold_build_lock",
    "make_writable",
    "write_text",
    "write_bytes",
    "mkdir",
    "makedirs",
    "mkdtemp",
    "rename",
    "unlink",
    "rmtree",
    "remove",
    "rmdir",
    "symlink_to",
    "open",
    "update_repo",
    "present_repo",
    "sync_distros",
    "left_the_manifest",
}
# The commands `require_git` runs: `git rev-parse --local-env-vars` and `git --version`.
SYNC_SUBPROCESS_WORDS = {"rev-parse", "--local-env-vars", "--version"}


def _module_attributes(tree, module):
    return {
        node.attr
        for node in ast.walk(tree)
        if isinstance(node, ast.Attribute)
        and isinstance(node.value, ast.Name)
        and node.value.id == module
    }


def _git_call_words(node):
    """The constant arguments of a call `git.run`, `git.out` or `git.ok` (any receiver for
    `status.py`'s own), or None when `node` is not one. Every argument must be a constant or a
    spread `SPREAD` allows, and the first a constant: a subcommand the scan can read."""
    if not (isinstance(node, ast.Call) and _called(node) in ("run", "out", "ok")):
        return None
    if (
        not isinstance(node.func, ast.Attribute)
        or getattr(node.func.value, "id", "") == "subprocess"
    ):
        return None
    assert node.args and isinstance(node.args[0], ast.Constant), ast.dump(node)
    for arg in node.args:
        if isinstance(arg, ast.Starred):
            assert getattr(arg.value, "id", "") in SPREAD, ast.dump(node)
    return [a.value for a in node.args if isinstance(a, ast.Constant)]


def _check_reading(words, where):
    """`words` is a git command that reads only."""
    assert words[0] in READ_ONLY_GIT, (where, words)
    if words[0] == "config":
        assert set(words) & CONFIG_READS, (where, words)
        assert not set(words) & CONFIG_WRITES, (where, words)
    if words[0] == "worktree":
        assert words[1:2] == ["list"], (where, words)


def test_status_calls_only_reading_functions_of_update_and_sync():
    tree = ast.parse(STATUS.read_text())
    constants = {name for name in dir(update) if name.isupper()}
    for module, allowed in STATUS_MAY_CALL.items():
        used = _module_attributes(tree, module) - constants
        assert used <= allowed, (module, used - allowed)


def test_status_runs_only_reading_git_commands_itself():
    tree = ast.parse(STATUS.read_text())
    seen = 0
    for node in ast.walk(tree):
        words = _git_call_words(node)
        if words is None:
            continue
        seen += 1
        _check_reading(words, "status.py")
        assert not {k.arg for k in node.keywords} & WRITES
    assert seen >= 1  # the scan sees `status.py`'s own calls


def test_status_asks_the_local_refs_never_origin():
    """`find_version` and `commit_on_origin` ask origin over the network unless they are given
    `ask`; every call `status.py` makes passes `ask=update.ask_local`."""
    tree = ast.parse(STATUS.read_text())
    calls = [
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.Call) and _called(node) in ("find_version", "commit_on_origin")
    ]
    assert len(calls) == 2
    for call in calls:
        (ask,) = [k.value for k in call.keywords if k.arg == "ask"]
        assert ast.unparse(ask) == "update.ask_local"


def _walk(path, start):
    """The functions of the module at `path` that `start` reach by calls, each with its node."""
    tree = ast.parse(path.read_text())
    functions = {node.name: node for node in tree.body if isinstance(node, ast.FunctionDef)}
    reached, todo = {}, sorted(set(start) & set(functions))
    while todo:
        name = todo.pop()
        if name in reached:
            continue
        reached[name] = functions[name]
        for node in ast.walk(functions[name]):
            if isinstance(node, ast.Call) and _called(node) in functions:
                todo.append(_called(node))
    return reached


def test_what_status_reaches_in_update_neither_writes_nor_asks_origin():
    reached = _walk(UPDATE, STATUS_MAY_CALL["update"])
    commands = 0
    for name, function in reached.items():
        for node in ast.walk(function):
            if isinstance(node, ast.Call):
                assert not {k.arg for k in node.keywords} & WRITES, (name, ast.dump(node))
            words = _git_call_words(node)
            if words is not None:
                commands += 1
                _check_reading(words, name)
    assert "standing" in reached and "worktree_holding" in reached  # the walk follows calls
    assert commands > 20  # and reads the git commands of what it reaches
    assert not set(reached) & NEVER_REACHED, set(reached) & NEVER_REACHED


def test_what_status_reaches_in_sync_writes_nothing():
    reached = _walk(Path(sync_module.__file__), STATUS_MAY_CALL["sync"])
    assert {"require_git", "resolve_all", "layer_moved", "plan_distros"} <= set(reached)
    assert "require_tools" not in reached  # `vcs` is never run
    commands = 0
    for name, function in reached.items():
        for node in ast.walk(function):
            if not isinstance(node, ast.Call):
                continue
            assert _called(node) not in SYNC_NEVER_CALLED, (name, ast.dump(node))
            if _called(node) == "run" and getattr(node.func.value, "id", "") == "subprocess":
                commands += 1
                words = {e.value for e in node.args[0].elts if isinstance(e, ast.Constant)}
                assert words <= SYNC_SUBPROCESS_WORDS, (name, words)
    assert commands == 2  # `git rev-parse --local-env-vars` and `git --version`


def test_the_scan_of_a_git_command_catches_a_write():
    for words in (["config", "remote.origin.url", "x"], ["config", "--unset", "a.b"]):
        with pytest.raises(AssertionError):
            _check_reading(words, "a test")
    with pytest.raises(AssertionError):
        _check_reading(["worktree", "prune"], "a test")
    with pytest.raises(AssertionError):
        _check_reading(["update-ref", "-d", "refs/x"], "a test")
    _check_reading(["config", "--type=bool", "--get", "core.sparseCheckout"], "a test")


def test_the_scan_of_status_catches_a_writing_call():
    tree = ast.parse("update._move(turn, head, found)\nsync.left_the_manifest(a, b, c, d, e)\n")
    assert _module_attributes(tree, "update") - STATUS_MAY_CALL["update"] == {"_move"}
    assert _module_attributes(tree, "sync") - STATUS_MAY_CALL["sync"] == {"left_the_manifest"}
