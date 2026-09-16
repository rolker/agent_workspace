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
_REGISTRY_ROLE_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
# Pseudo-type of a parent root (issue #265): groups instances, has no adapter.
REGISTRY_PARENT_TYPE = "project"
# Trailing key=value fields accepted on a registry line (issue #265).
REGISTRY_FIELD_KEYS = ("parent", "worktrees", "role", "distro", "default_instance")


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
    Parse .agent/projects.local (issue #227; trailing fields and parent
    roots: issue #265).

    Returns (entries, errors) where entries is a list of dicts with keys
    'name', 'type', 'path' (absolute Path), and 'fields' (dict of the
    trailing key=value fields, with 'worktrees' made absolute), and errors
    is a list of human-readable strings for malformed lines. A missing
    registry file yields ([], []) — the registry is optional. Cross-line
    rules (parent must be a registered REGISTRY_PARENT_TYPE entry;
    default_instance must be an instance of that parent) are reported as
    errors and drop the offending line, matching _project_registry.sh.
    """
    if root is None:
        root = get_workspace_root()
    root = Path(root)
    registry = get_projects_registry_path(root)
    parsed = []
    errors = []
    if not registry.is_file():
        return [], errors
    for lineno, raw in enumerate(registry.read_text().splitlines(), start=1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        tokens = line.split()
        name = tokens[0]
        ptype = tokens[1] if len(tokens) > 1 else ""
        rest = tokens[2:]
        path = ""
        if rest and "=" not in rest[0]:
            path = rest[0]
            rest = rest[1:]
        if not _REGISTRY_NAME_RE.match(name) or ".." in name:
            errors.append(f"{registry}:{lineno}: invalid project name '{name}'")
            continue
        if not _REGISTRY_TYPE_RE.match(ptype):
            errors.append(f"{registry}:{lineno}: invalid or missing project type for '{name}'")
            continue
        fields = {}
        bad = None
        for tok in rest:
            key, sep, value = tok.partition("=")
            if not sep or not key or not value:
                bad = (
                    f"{registry}:{lineno}: expected key=value, got '{tok}' "
                    "(paths must not contain spaces)"
                )
                break
            if key not in REGISTRY_FIELD_KEYS:
                known = " ".join(REGISTRY_FIELD_KEYS)
                bad = f"{registry}:{lineno}: unknown field '{key}' for '{name}' (known: {known})"
                break
            if key in fields:
                bad = f"{registry}:{lineno}: duplicate field '{key}' for '{name}'"
                break
            if key in ("parent", "default_instance") and (
                not _REGISTRY_NAME_RE.match(value) or ".." in value
            ):
                bad = f"{registry}:{lineno}: invalid {key} '{value}' for '{name}'"
                break
            if key in ("role", "distro") and not _REGISTRY_ROLE_RE.match(value):
                bad = f"{registry}:{lineno}: invalid {key} '{value}' for '{name}'"
                break
            if key == "worktrees" and not Path(value).is_absolute():
                value = str(root / value)
            fields[key] = value
        if bad:
            errors.append(bad)
            continue
        if not path:
            path = f"projects/{name}"
        abs_path = Path(path)
        if not abs_path.is_absolute():
            abs_path = root / path
        parsed.append((lineno, {"name": name, "type": ptype, "path": abs_path, "fields": fields}))

    # First definition wins for lookups; a repeated name is an error.
    by_name = {}
    for _, e in parsed:
        by_name.setdefault(e["name"], e)
    entries = []
    seen = set()
    for lineno, entry in parsed:
        name, ptype, fields = entry["name"], entry["type"], entry["fields"]
        if name in seen:
            errors.append(f"{registry}:{lineno}: duplicate project name '{name}'")
            continue
        seen.add(name)
        parent = fields.get("parent")
        if parent is not None:
            if ptype == REGISTRY_PARENT_TYPE:
                errors.append(
                    f"{registry}:{lineno}: parent root '{name}' may not itself have a parent "
                    "(no nesting)"
                )
                continue
            ref = by_name.get(parent)
            if ref is None:
                errors.append(
                    f"{registry}:{lineno}: parent '{parent}' of '{name}' is not registered"
                )
                continue
            if ref["type"] != REGISTRY_PARENT_TYPE:
                errors.append(
                    f"{registry}:{lineno}: parent '{parent}' of '{name}' is type "
                    f"'{ref['type']}', not '{REGISTRY_PARENT_TYPE}'"
                )
                continue
        dflt = fields.get("default_instance")
        if dflt is not None:
            if ptype != REGISTRY_PARENT_TYPE:
                errors.append(
                    f"{registry}:{lineno}: default_instance is only valid on a "
                    f"'{REGISTRY_PARENT_TYPE}' line ('{name}' is '{ptype}')"
                )
                continue
            ref = by_name.get(dflt)
            if ref is None or ref["fields"].get("parent") != name:
                errors.append(
                    f"{registry}:{lineno}: default_instance '{dflt}' is not an instance of '{name}'"
                )
                continue
        entries.append(entry)
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
