#!/usr/bin/env bash
# .agent/scripts/setup_project.sh
# Dispatch shim — real logic lives in the project-type adapter (ADR-0011).
# single_project's implementation: .agent/project_types/single_project/setup.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/adapter" setup "$@"
