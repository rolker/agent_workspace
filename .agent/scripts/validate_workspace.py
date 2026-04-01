#!/usr/bin/env python3
"""
Validate workspace configuration.

Checks that:
1. project/ exists and is a valid git repo
2. project/ has a remote configured
3. .venv shebangs match the current workspace path
4. pre-commit hook points to a valid Python path

Usage:
    python3 validate_workspace.py [--verbose]
"""

import sys
import subprocess
import argparse
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
sys.path.insert(0, str(SCRIPT_DIR / "lib"))

from workspace import get_workspace_root, get_project_path, get_project_remote_url


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


def validate_workspace(verbose=False):
    """Validate workspace configuration. Returns True if valid."""
    get_workspace_root()  # validate we're in a workspace
    project = get_project_path()

    print("Validating workspace...")
    print()

    issues = []

    # Check project/ exists
    if not project.exists():
        issues.append("project/ directory does not exist")
        issues.append("  Run: make setup  (will prompt for repo URL or path)")
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

    # Check remote URL
    remote_url = get_project_remote_url()
    if not issues:
        if not remote_url:
            issues.append("project/ has no remote 'origin' configured")
        elif verbose:
            print(f"  project remote: {remote_url}")

    # Check venv shebangs for stale paths (workspace was renamed/moved)
    workspace_root = Path(get_workspace_root())
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

    # Check pre-commit hook for stale Python path
    hook_file = workspace_root / ".git" / "hooks" / "pre-commit"
    if hook_file.exists():
        try:
            hook_content = hook_file.read_text()
            for line in hook_content.split("\n"):
                if line.startswith("INSTALL_PYTHON="):
                    hook_python = line.split("=", 1)[1].strip().strip("'\"")
                    expected_hook = str(workspace_root / ".venv" / "bin" / "python3")
                    if hook_python != expected_hook:
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

    is_valid = validate_workspace(args.verbose)
    sys.exit(0 if is_valid else 1)


if __name__ == "__main__":
    main()
