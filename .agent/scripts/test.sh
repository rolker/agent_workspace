#!/usr/bin/env bash
# .agent/scripts/test.sh
# Dispatch shim — real logic lives in the project-type adapter (ADR-0011).
# user-tier: guarded-by:adapter -- this shim only execs `adapter`, which
# calls registry_require_root before any project action (#265 PR 3).
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/adapter" test "$@"
