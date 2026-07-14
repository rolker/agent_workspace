#!/usr/bin/env bash
# .agent/scripts/validate_adapter.sh
# Verify every project-type adapter implements the full adapter contract.
#
# Iterates .agent/project_types/*/adapter.sh, sources each in a subshell,
# and asserts every verb in REQUIRED_VERBS (imported from the dispatcher —
# single source of truth) is defined as an adapter_<verb> function.
# Also enforces the silent-at-source contract requirement and rejects
# adapters that call exit at top level.
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

SOURCE_STDOUT="$(mktemp)"
trap 'rm -f "$SOURCE_STDOUT"' EXIT

for type_dir in "$TYPES_DIR"/*/; do
    # An unmatched glob stays literal; skip non-directories so an empty
    # project_types/ falls through to the CHECKED=0 error below.
    [ -d "$type_dir" ] || continue
    type_name="$(basename "$type_dir")"
    adapter_file="$type_dir/adapter.sh"

    if [ ! -f "$adapter_file" ]; then
        echo "❌ $type_name: missing adapter.sh"
        FAILED=1
        CHECKED=$((CHECKED + 1))
        continue
    fi

    # Source in a subshell so one type's functions can't mask another's
    # gaps. The trailing __COMPLETE__ sentinel is the proof the verb loop
    # actually ran: a top-level `exit` in the adapter (any status) kills
    # the subshell before the sentinel, so its absence means the source
    # didn't finish cleanly — never a pass. `|| true` keeps a nonzero
    # subshell exit from tripping the validator's set -e.
    result="$(
        ADAPTER_TYPE_DIR="${type_dir%/}"
        export WORKSPACE_ROOT ADAPTER_TYPE_DIR
        # shellcheck source=/dev/null
        source "$adapter_file" > "$SOURCE_STDOUT" 2>/dev/null || exit 1
        if [ -s "$SOURCE_STDOUT" ]; then
            echo "__NOISY_SOURCE__"
        fi
        for verb in "${REQUIRED_VERBS[@]}"; do
            declare -F "adapter_${verb}" >/dev/null || echo "$verb"
        done
        echo "__COMPLETE__"
    )" || true

    if [[ "$result" != *"__COMPLETE__"* ]]; then
        echo "❌ $type_name: adapter.sh failed to source (or called exit at top level)"
        FAILED=1
    else
        missing="$(printf '%s\n' "$result" | grep -v '^__COMPLETE__$' | grep -v '^__NOISY_SOURCE__$' || true)"
        noisy=false
        if [[ "$result" == *"__NOISY_SOURCE__"* ]]; then
            noisy=true
        fi

        if [ -n "$missing" ]; then
            echo "❌ $type_name: missing verbs:"
            # shellcheck disable=SC2001
            echo "$missing" | sed 's/^/     adapter_/'
            FAILED=1
        fi
        if [ "$noisy" = true ]; then
            echo "❌ $type_name: adapter.sh writes to stdout when sourced (must be silent — 'adapter env' output is eval'd by callers)"
            FAILED=1
        fi
        if [ -z "$missing" ] && [ "$noisy" = false ]; then
            echo "✅ $type_name: all ${#REQUIRED_VERBS[@]} verbs implemented"
        fi
    fi
    CHECKED=$((CHECKED + 1))
done

if [ "$CHECKED" -eq 0 ]; then
    echo "ERROR: no project types found under $TYPES_DIR" >&2
    exit 1
fi

exit "$FAILED"
