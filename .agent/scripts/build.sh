#!/usr/bin/env bash
# .agent/scripts/build.sh
# Dispatch shim — real logic lives in the project-type adapter (ADR-0011).
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/adapter" build "$@"
