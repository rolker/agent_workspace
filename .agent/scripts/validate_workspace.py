#!/usr/bin/env python3
"""
Validate workspace configuration.

Checks that:
1. A project checkout is configured — legacy project/ symlink and/or
   registry entries in .agent/projects.local (issue #227); both shapes
   may coexist during migration
2. Configured checkouts have the shape their project type expects: the
   legacy project/ is a git repo with a remote; each registry entry's
   checkout is checked by its own type's adapter (`adapter --project <name>
   validate` — a .git at the root for single_project, the manifest's layers
   and repos for ros2_colcon). When the registry has parse errors, entries
   are only checked for a present hosting dir.
3. Registry entries are well-formed and name project types that have
   adapters (ADR-0011)
4. .venv shebangs match the current workspace path
5. pre-commit hook points to a valid Python path

Usage:
    python3 validate_workspace.py [--verbose]
"""

import os
import signal
import sys
import subprocess
import argparse
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
sys.path.insert(0, str(SCRIPT_DIR / "lib"))

from workspace import (
    get_workspace_root,
    get_project_path,
    get_project_remote_url,
    read_projects_registry,
    REGISTRY_PARENT_TYPE,
)


def get_git_branch(repo_path):
    """Get the current branch of a git repository."""
    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            cwd=str(repo_path),
            capture_output=True,
            text=True,
            check=True,
        )
        branch = result.stdout.strip()
        return branch if branch else None
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


# Bound on one project's `adapter validate`. The verb is local filesystem
# checks (single_project: one `git rev-parse`; ros2_colcon: a manifest walk
# with a stat per pinned repo) that finish in well under a second, so 60 s
# leaves ample room for a cold or network filesystem while still stopping a
# hung adapter from hanging `make validate`. Overridable for tests.
ADAPTER_VALIDATE_TIMEOUT_ENV = "WS_ADAPTER_VALIDATE_TIMEOUT"
ADAPTER_VALIDATE_TIMEOUT_DEFAULT = 60.0


def adapter_validate_timeout():
    """Seconds allowed for one `adapter validate` run (env override, else 60)."""
    raw = os.environ.get(ADAPTER_VALIDATE_TIMEOUT_ENV, "")
    try:
        value = float(raw)
    except ValueError:
        return ADAPTER_VALIDATE_TIMEOUT_DEFAULT
    return value if value > 0 else ADAPTER_VALIDATE_TIMEOUT_DEFAULT


def kill_process_group(proc):
    """SIGKILL proc's whole process group (proc leads its own session).

    Any OSError is ignored: the group may already be gone (ESRCH), and macOS
    returns EPERM for a group whose members are all zombies.
    """
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except OSError:
        pass


def delegate_shape_check(workspace_root, name):
    """Run `adapter --project <name> validate`; return issue lines (empty = OK).

    Both output streams are captured: the adapter's pass line must not print
    inline in the one-line-per-project report, and every failure line is
    reported prefixed with the project's name (not raw adapter stderr).

    The run is bounded by adapter_validate_timeout(). The adapter runs in its
    own session so a timeout kills the whole process group: killing only the
    dispatcher would leave any child it spawned holding the output pipes open,
    and collecting the output would then hang anyway. The group is also
    killed when the wait is interrupted (Ctrl-C, SIGTERM), since its own
    session never receives the terminal's signal.
    """
    adapter = workspace_root / ".agent" / "scripts" / "adapter"
    timeout = adapter_validate_timeout()
    try:
        # pylint: disable-next=consider-using-with  # killpg needs the Popen
        proc = subprocess.Popen(
            [str(adapter), "--project", name, "validate"],
            cwd=str(workspace_root),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
    except OSError as exc:
        return [f"project '{name}': cannot run the adapter's validate verb: {exc}"]
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        kill_process_group(proc)
        proc.communicate()
        return [f"project '{name}': adapter validate timed out after {timeout:g}s"]
    except BaseException:
        # Ctrl-C (KeyboardInterrupt) or SIGTERM (SystemExit, see main): the
        # adapter's own session keeps it out of the terminal's foreground
        # group, so the signal never reached it. Kill it before unwinding or
        # it outlives validate as an orphan.
        kill_process_group(proc)
        proc.wait()
        raise
    result = subprocess.CompletedProcess(proc.args, proc.returncode, stdout, stderr)
    if result.returncode == 0:
        return []
    lines = [line.strip() for line in result.stderr.splitlines() if line.strip()]
    if not lines:
        # An adapter that reports its failure on stdout still names the
        # problem; prefer its words over the generic exit-code line.
        lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not lines:
        return [
            f"project '{name}': checkout shape check failed "
            f"(adapter validate exited {result.returncode})"
        ]
    return [f"project '{name}': {line}" for line in lines]


def validate_workspace(verbose=False):
    """Validate workspace configuration. Returns True if valid."""
    workspace_root = Path(get_workspace_root())
    project = get_project_path()

    print("Validating workspace...")
    print()

    issues = []

    # Registry shape (.agent/projects.local, issue #227)
    registry_entries, registry_errors = read_projects_registry(workspace_root)
    for err in registry_errors:
        issues.append(f"projects.local: {err}")

    # Check project/ exists (legacy shape). A registry with entries makes
    # the legacy symlink optional — both shapes may coexist.
    if not project.exists():
        if not registry_entries:
            issues.append("project/ directory does not exist")
            issues.append("  Run: make setup  (will prompt for repo URL or path)")
        elif verbose:
            print("  legacy project/ not configured (registry projects present)")
    elif not (project / ".git").exists():
        # Could be a symlink to a git repo
        resolved = project.resolve()
        if not (resolved / ".git").exists():
            issues.append("project/ exists but is not a git repository")
            issues.append("  Run: make setup  (will re-configure the project)")
        else:
            if verbose:
                print(f"  project/ is a symlink → {resolved}")
    else:
        if verbose:
            branch = get_git_branch(project)
            print(f"  project/ is a git repo (branch: {branch or 'detached HEAD'})")

    # Check remote URL (legacy shape only — registry checkouts are validated
    # per entry below and don't require a remote named 'origin' here)
    remote_url = get_project_remote_url()
    if not issues and project.exists():
        if not remote_url:
            issues.append("project/ has no remote 'origin' configured")
        elif verbose:
            print(f"  project remote: {remote_url}")

    # Validate registry entries: known project type, valid checkout
    for entry in registry_entries:
        name, ptype, path = entry["name"], entry["type"], entry["path"]
        if ptype == REGISTRY_PARENT_TYPE:
            # Parent root (issue #265): a directory that groups instances;
            # no adapter, need not be a git repository.
            instances = [e["name"] for e in registry_entries if e["fields"].get("parent") == name]
            if not path.is_dir():
                issues.append(f"parent root '{name}': directory does not exist: {path}")
            elif not instances:
                issues.append(
                    f"parent root '{name}': no instances registered "
                    f"(add parent={name} to its instances)"
                )
            elif verbose:
                print(f"  parent root '{name}': {path} OK ({', '.join(instances)})")
            continue
        adapter_file = workspace_root / ".agent" / "project_types" / ptype / "adapter.sh"
        if not adapter_file.is_file():
            issues.append(
                f"project '{name}': unknown project type '{ptype}' "
                f"(no adapter at .agent/project_types/{ptype}/)"
            )
        if not path.exists():
            issues.append(f"project '{name}': hosting dir does not exist: {path}")
            issues.append("  Clone the project there or fix .agent/projects.local")
            continue
        # The checkout's shape is the type's business (ADR-0011, issue #330):
        # delegate to `adapter --project <name> validate` rather than
        # hard-coding one type's shape (a .git at the root) for every entry.
        # Skip delegation when the registry has parse errors: the dispatcher
        # refuses every lookup then, which would blame healthy projects for
        # an unrelated line — the parse error is already reported once above.
        if not adapter_file.is_file():
            continue  # unknown type, already reported: no adapter to call
        if not registry_errors:
            shape_issues = delegate_shape_check(workspace_root, name)
            if shape_issues:
                issues.extend(shape_issues)
                continue
        if verbose:
            if registry_errors:
                # Only the hosting dir's presence was checked: say so rather
                # than a bare OK that reads as "shape verified".
                print(
                    f"  project '{name}' ({ptype}): {path} hosting dir present; "
                    "shape not checked (registry has parse errors)"
                )
            else:
                print(f"  project '{name}' ({ptype}): {path} OK")

    # Check venv shebangs for stale paths (workspace was renamed/moved)
    venv_pip = workspace_root / ".venv" / "bin" / "pip"
    if venv_pip.exists():
        try:
            shebang = venv_pip.read_text().split("\n", 1)[0]
            if shebang.startswith("#!"):
                interpreter = shebang[2:].strip().split()[0]
                expected_prefix = str(workspace_root / ".venv" / "bin" / "python")
                if not interpreter.startswith(expected_prefix):
                    issues.append("venv has stale shebangs (workspace was renamed/moved)")
                    issues.append("  Run: make repair")
                elif verbose:
                    print("  venv shebangs: OK")
            elif verbose:
                print("  venv shebangs: OK (no shebang found)")
        except OSError:
            pass
    elif verbose:
        print("  venv: not installed (run make setup)")

    # Check the pre-commit hook for a stale interpreter path. The hook lives
    # in the MAIN checkout's .git/hooks (shared by every worktree), so ask git
    # for the common dir rather than assuming .git is a directory here
    # (issue #272: from a worktree, .git is a file and the old check said
    # "not installed" while the shared hook was silently broken).
    hook_file = None
    try:
        common = subprocess.run(
            ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
            cwd=str(workspace_root),
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        hook_file = Path(common) / "hooks" / "pre-commit"
        hook_root = Path(common).parent
    except (subprocess.CalledProcessError, FileNotFoundError):
        hook_file = workspace_root / ".git" / "hooks" / "pre-commit"
        hook_root = workspace_root
    if hook_file.exists():
        try:
            hook_content = hook_file.read_text()
            for line in hook_content.split("\n"):
                if line.startswith("INSTALL_PYTHON="):
                    hook_python = line.split("=", 1)[1].strip().strip("'\"")
                    expected_hook = str(hook_root / ".venv" / "bin" / "python3")
                    # The hook itself tests `-x`, so mirror that: a present but
                    # non-executable interpreter still falls through to PATH.
                    if not os.access(hook_python, os.X_OK) or not Path(hook_python).is_file():
                        issues.append(
                            "pre-commit hook points to a Python that no longer exists: "
                            f"{hook_python}"
                        )
                        issues.append(
                            "  Every commit in every worktree fails with '`pre-commit` not found'"
                        )
                        issues.append(f"  Expected: {expected_hook}")
                        issues.append("  Run: make repair")
                    elif hook_python != expected_hook:
                        issues.append(f"pre-commit hook points to wrong path: {hook_python}")
                        issues.append(f"  Expected: {expected_hook}")
                        issues.append("  Run: make repair")
                    elif verbose:
                        print("  pre-commit hook: OK")
                    break
        except OSError:
            pass
    elif verbose:
        print("  pre-commit hook: not installed (run make setup)")

    print("=" * 60)
    print("Workspace Validation Results")
    print("=" * 60)

    if issues:
        print("❌ Workspace validation FAILED")
        for msg in issues:
            print(f"   {msg}")
        print("=" * 60)
        return False

    print("✅ Workspace validation PASSED!")
    if verbose:
        print(f"   project remote: {remote_url}")
    print("=" * 60)
    return True


def main():
    parser = argparse.ArgumentParser(description="Validate workspace configuration")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    args = parser.parse_args()

    # Turn SIGTERM into SystemExit so cleanup runs: delegate_shape_check kills
    # the adapter's process group on the way out (the default SIGTERM action
    # would end this process at once and orphan the adapter).
    signal.signal(signal.SIGTERM, lambda signum, _frame: sys.exit(128 + signum))

    is_valid = validate_workspace(args.verbose)
    sys.exit(0 if is_valid else 1)


if __name__ == "__main__":
    main()
