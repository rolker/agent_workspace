"""
Workspace Management Library

Provides common functions for discovering and managing repositories in the
general-purpose Agent Workspace: the legacy single-repo model (project/)
and the per-machine project registry (.agent/projects.local, issue #227).
"""

import re
import subprocess
from pathlib import Path

# Mirror the validation rules in .agent/scripts/_project_registry.sh.
_REGISTRY_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
_REGISTRY_TYPE_RE = re.compile(r"^[a-z0-9][a-z0-9_]*$")


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


def is_project_configured(project=None):
    """
    Return True if the project checkout exists and is a valid git repo.

    Defaults to the legacy project/ directory; pass a Path to check a
    registry-hosted project instead.
    """
    if project is None:
        project = get_project_path()
    project = Path(project)
    if not project.exists():
        return False
    if (project / ".git").exists():
        return True
    # project may be a symlink to a checkout
    return (project.resolve() / ".git").exists()


def get_projects_registry_path(root=None):
    """Return the Path of the per-machine project registry (issue #227)."""
    if root is None:
        root = get_workspace_root()
    return Path(root) / ".agent" / "projects.local"


def read_projects_registry(root=None):
    """
    Parse .agent/projects.local (issue #227).

    Returns (entries, errors) where entries is a list of dicts with keys
    'name', 'type', and 'path' (absolute Path), and errors is a list of
    human-readable strings for malformed lines. A missing registry file
    yields ([], []) — the registry is optional.
    """
    if root is None:
        root = get_workspace_root()
    root = Path(root)
    registry = get_projects_registry_path(root)
    entries = []
    errors = []
    if not registry.is_file():
        return entries, errors
    for lineno, raw in enumerate(registry.read_text().splitlines(), start=1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        fields = line.split()
        if len(fields) > 3:
            errors.append(f"{registry}:{lineno}: too many fields (paths must not contain spaces)")
            continue
        name = fields[0]
        ptype = fields[1] if len(fields) > 1 else ""
        path = fields[2] if len(fields) > 2 else f"projects/{name}"
        if not _REGISTRY_NAME_RE.match(name):
            errors.append(f"{registry}:{lineno}: invalid project name '{name}'")
            continue
        if not _REGISTRY_TYPE_RE.match(ptype):
            errors.append(f"{registry}:{lineno}: invalid or missing project type for '{name}'")
            continue
        abs_path = Path(path)
        if not abs_path.is_absolute():
            abs_path = root / path
        entries.append({"name": name, "type": ptype, "path": abs_path})
    return entries, errors


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
