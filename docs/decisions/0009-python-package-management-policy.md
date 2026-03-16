# ADR-0009: Python package management policy

## Status

Accepted

## Context

The workspace uses Python dev tools (pre-commit) installed into a `.venv` by the
Makefile, but there is no documented policy for how Python packages should be
managed. Ubuntu 24.04 enforces PEP 668, which blocks bare `pip install` on
system Python with an "externally managed environment" error — but agents don't
know this and may attempt `pip install --break-system-packages` or other
workarounds.

Without guidance, agents face three questions every time they need a Python tool:

1. **Where does it go?** — system (`apt`/`rosdep`), workspace `.venv`, or `pipx`?
2. **How is it recorded?** — `requirements.txt`, `package.xml`, or ad hoc?
3. **What is explicitly forbidden?** — bare `pip install` on system Python?

The workspace already has a `.venv` and Makefile target (`setup-dev.done`), but
the install list was hardcoded. There was no `requirements.txt` for
reproducibility, and no documentation of the decision criteria.

[#339]: https://github.com/rolker/ros2_agent_workspace/issues/339

## Decision

**Use a two-tier placement model for Python packages, with PEP 668 as the
OS-level guardrail and `requirements.txt` as the reproducible baseline.**

### Tier 1: Workspace `.venv` (dev tools)

Use for workspace-level developer tools that are wired into `make` targets.

- **Criteria**: tool is used by workspace automation (Makefile, CI, pre-commit)
  and is not a ROS 2 build dependency
- **Examples**: `pre-commit`
- **Managed by**: `requirements.txt` at repo root, installed via
  `make lint` → `setup-dev.done` target
- **Agents may add packages** to `.venv` for ephemeral use during a task
  (e.g., a linter, formatter, or analysis tool), but only via
  `.venv/bin/pip install`. If the tool should persist, add it to
  `requirements.txt` via PR.

### Tier 2: `pipx` (user-facing CLI tools)

Use for standalone CLI tools that a developer wants available globally but
isolated from system Python.

- **Criteria**: tool is a CLI application, not imported as a library, and not
  needed by workspace automation
- **Examples**: `cookiecutter`, `sphinx-autobuild`
- **Managed by**: individual developers; not tracked in workspace config

### What is forbidden

- **Bare `pip install`** (outside `.venv`) — PEP 668 blocks this on Ubuntu
  24.04+. Do not use `--break-system-packages` to circumvent it.
- **`sudo pip install`** — never install Python packages as root.
- **Modifying system Python** in any way that bypasses the package manager.

### Project repos are independent

Project repos manage their own Python dependencies (e.g., their own
`requirements.txt`, `setup.py`, or `pyproject.toml`). This ADR governs the
workspace repo only.

## Consequences

**Positive:**
- Agents have clear criteria for where to install Python packages — no guessing
- `requirements.txt` makes dev-tool installation reproducible across machines
  and CI
- PEP 668 provides OS-level enforcement against the most dangerous action
  (bare `pip install` on system Python); AGENTS.md rules provide agent-level
  awareness
- The two-tier model is simple enough to remember: .venv for dev tools,
  pipx for personal CLIs

**Negative:**
- Agents must activate `.venv` (or use `.venv/bin/pip`) to install packages,
  which adds a step (mitigated: the Makefile handles this automatically for
  `requirements.txt` contents)
- `requirements.txt` must be kept in sync with actual usage (mitigated: starts
  minimal with only `pre-commit`; additions go through PR review)
- The policy doesn't cover project-repo Python packaging (intentional: project
  repos are independent per ADR-0003)
