"""
Workspace Management Library

Provides common functions for discovering and managing repositories in the
general-purpose Agent Workspace (single-repo model).
"""

import subprocess
from pathlib import Path


def get_workspace_root():
    """Get the absolute path to the workspace root directory."""
    # This file is in .agent/scripts/lib/, so go up 3 levels
    lib_dir = Path(__file__).parent
    scripts_dir = lib_dir.parent
    agent_dir = scripts_dir.parent
    workspace_root = agent_dir.parent
    return str(workspace_root)


def get_project_path():
    """
    Return the Path to the project/ directory (may not exist yet).
    """
    return Path(get_workspace_root()) / "project"


def is_project_configured():
    """
    Return True if project/ exists and is a valid git repo.
    """
    project = get_project_path()
    return project.exists() and (project / ".git").exists()


def get_project_remote_url():
    """
    Return the remote URL of the project repo, or None if not configured.
    """
    project = get_project_path()
    if not is_project_configured():
        return None
    try:
        result = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            cwd=str(project),
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip() or None
    except subprocess.CalledProcessError:
        return None


def extract_github_owner_repo(url):
    """
    Extract owner and repo name from a GitHub URL.

    Args:
        url (str): GitHub URL (https or git format)

    Returns:
        tuple: (owner, repo_name) or (None, None) if not a valid GitHub URL
    """
    if not url:
        return None, None

    # Handle https URLs
    if url.startswith("https://github.com/"):
        path = url.replace("https://github.com/", "").rstrip("/")
        if path.endswith(".git"):
            path = path[:-4]
        parts = path.split("/")
        if len(parts) >= 2:
            return parts[0], parts[1]

    # Handle git@ URLs
    if url.startswith("git@github.com:"):
        path = url.replace("git@github.com:", "")
        if path.endswith(".git"):
            path = path[:-4]
        parts = path.split("/")
        if len(parts) >= 2:
            return parts[0], parts[1]

    return None, None
