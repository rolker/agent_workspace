#!/usr/bin/env python3
"""
Sync Workspace and Project Repositories

Safely synchronizes workspace and project repositories by pulling updates on
default branches and fetching on feature branches. Respects dirty working
directories and detached HEAD states.

Usage:
    python3 sync_project.py [--dry-run]
"""

import sys
import subprocess
import argparse
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
sys.path.insert(0, str(SCRIPT_DIR / "lib"))

from workspace import get_workspace_root, get_project_path, is_project_configured


def run_git_cmd(repo_path, cmd_args, dry_run=False):
    """Run a git command in the given repo path."""
    full_cmd = ["git"] + cmd_args
    if dry_run:
        print(f"[DRY-RUN] {repo_path.name}: {' '.join(full_cmd)}")
        return True, ""
    try:
        result = subprocess.run(
            full_cmd, cwd=str(repo_path), capture_output=True, text=True, check=True
        )
        return True, result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return False, e.stderr.strip()


def is_dirty(repo_path):
    """Check if repo has uncommitted changes."""
    success, output = run_git_cmd(repo_path, ["status", "--porcelain"], dry_run=False)
    return success and bool(output)


def get_current_branch(repo_path):
    """Get the current checked out branch."""
    success, output = run_git_cmd(repo_path, ["branch", "--show-current"], dry_run=False)
    return output if success else None


def sync_repo(repo_path, repo_name, dry_run=False):
    """Synchronize a single repository. Returns True if sync proceeded."""
    print(f"Checking {repo_name}...")

    if not repo_path.exists():
        print(f"  ❌ Path does not exist: {repo_path}")
        return False

    if is_dirty(repo_path):
        if dry_run:
            print("  ⚠️  (Dry run) Would skip: Uncommitted changes detected.")
        else:
            print("  ⚠️  Skipping: Uncommitted changes detected.")
        return False

    branch = get_current_branch(repo_path)
    if not branch:
        print("  ❌ Skipping: Detached HEAD or invalid git state.")
        return False

    if branch in ["main", "master", "develop"]:
        print(f"  On default branch '{branch}'. Pulling updates...")
        success, output = run_git_cmd(repo_path, ["pull", "--rebase"], dry_run)
        if success:
            if dry_run:
                print("     (Dry run successful)")
            elif "Already up to date." in output:
                print("     ✅ Already up to date.")
            else:
                print(f"     ✅ Updated:\n{output}")
        else:
            print(f"     ❌ Update failed: {output}")
    else:
        print(f"  On feature branch '{branch}'. Fetching only...")
        success, output = run_git_cmd(repo_path, ["fetch"], dry_run)
        if success:
            if dry_run:
                print("     (Dry run successful)")
            else:
                s_success, s_msg = run_git_cmd(repo_path, ["status", "-sb"], False)
                if s_success and "behind" in s_msg:
                    print("     ⚠️  Branch is behind remote. Run 'git rebase' manually.")
                else:
                    print("     ✅ Fetched.")
        else:
            print(f"     ❌ Fetch failed: {output}")

    return True


def main():
    parser = argparse.ArgumentParser(description="Safely sync workspace and project repositories.")
    parser.add_argument("--dry-run", action="store_true", help="Simulate actions without executing.")
    args = parser.parse_args()

    root_dir = Path(get_workspace_root())
    project_dir = get_project_path()

    # Sync workspace repo
    sync_repo(root_dir, "agent_workspace (workspace)", args.dry_run)

    # Sync project repo
    if is_project_configured():
        sync_repo(project_dir, f"project ({project_dir.resolve().name})", args.dry_run)
    else:
        print("Checking project...")
        print("  ⚠️  project/ not configured. Run: make setup")

    print("\n✅ Sync complete.")


if __name__ == "__main__":
    main()
