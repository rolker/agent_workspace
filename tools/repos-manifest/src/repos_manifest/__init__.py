"""repos_manifest: reads a manifest of the repos of a ROS 2 project made of many repos, writes
what it comes to for a machine, and sets up, syncs and builds a system directory from it.

The integration surface is the ``repos-manifest`` CLI only; nothing outside
``tools/repos-manifest/`` imports this package directly, so that it can be moved into a
repository of its own (agent_workspace issue #267). Its name, CLI command and directory are
repos-manifest, chosen in issue #497.
"""

__version__ = "0.1.0"
