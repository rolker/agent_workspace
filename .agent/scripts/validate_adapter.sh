#!/usr/bin/env bash
# .agent/scripts/validate_adapter.sh
# Verify every project-type adapter implements the full adapter contract.
#
# Iterates .agent/project_types/*/adapter.sh, sources each in a subshell,
# and asserts every verb in REQUIRED_VERBS (imported from the dispatcher —
# single source of truth) is defined as an adapter_<verb> function.
#
# Usage:
#   .agent/scripts/validate_adapter.sh
#
# Exit codes: 0 all adapters complete; 1 any adapter missing verbs or
# malformed. Wired to pre-commit and CI (ADR-0004/0005).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Sourcing the dispatcher defines REQUIRED_VERBS and WORKSPACE_ROOT
# without dispatching.
# shellcheck source=adapter
source "$SCRIPT_DIR/adapter"

TYPES_DIR="$WORKSPACE_ROOT/.agent/project_types"
FAILED=0
CHECKED=0

if [ ! -d "$TYPES_DIR" ]; then
    echo "ERROR: $TYPES_DIR does not exist" >&2
    exit 1
fi

for type_dir in "$TYPES_DIR"/*/; do
    type_name="$(basename "$type_dir")"
    adapter_file="$type_dir/adapter.sh"

    if [ ! -f "$adapter_file" ]; then
        echo "❌ $type_name: missing adapter.sh"
        FAILED=1
        continue
    fi

    # Source in a subshell so one type's functions can't mask another's
    # gaps; the subshell prints the verbs it found missing.
    missing="$(
        # shellcheck source=/dev/null
        source "$adapter_file" >/dev/null 2>&1 || { echo "__SOURCE_FAILED__"; exit 0; }
        for verb in "${REQUIRED_VERBS[@]}"; do
            declare -F "adapter_${verb}" >/dev/null || echo "$verb"
        done
    )"

    if [ "$missing" = "__SOURCE_FAILED__" ]; then
        echo "❌ $type_name: adapter.sh failed to source"
        FAILED=1
    elif [ -n "$missing" ]; then
        echo "❌ $type_name: missing verbs:"
        # shellcheck disable=SC2001
        echo "$missing" | sed 's/^/     adapter_/'
        FAILED=1
    else
        echo "✅ $type_name: all ${#REQUIRED_VERBS[@]} verbs implemented"
    fi
    CHECKED=$((CHECKED + 1))
done

if [ "$CHECKED" -eq 0 ]; then
    echo "ERROR: no project types found under $TYPES_DIR" >&2
    exit 1
fi

exit "$FAILED"
