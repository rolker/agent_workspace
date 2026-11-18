"""repos_manifest — prototype general ROS 2 multi-repo manifest resolver.

**Extraction candidate.** See agent_workspace issue #267: this package is designed to be
extracted into its own repository. Its name, CLI command and directory are repos-manifest, chosen
by the owner in issue #497. Nothing
outside ``tools/repos-manifest/`` imports this package directly; the intended integration surface
is the ``repos-manifest`` CLI only.
"""

__version__ = "0.1.0"
