#!/bin/bash
# discover_governance.sh — Scan workspace and project repos for governance documents.
#
# Outputs a TSV inventory: path<tab>type<tab>size<tab>scope
#   scope: "workspace" or the project repo directory name
#   type:  principles | adr | agent-guide | architecture | agents-config | workspace-context
#   size:  bytes for files, file count for workspace-context directories
#
# Usage:
#   .agent/scripts/discover_governance.sh [--json]
#
# With --json, outputs JSON lines instead of TSV.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=_real_case_path.sh
if ! source "$SCRIPT_DIR/_real_case_path.sh" 2>/dev/null; then
    # A read-only report: without the helper, still report, using the
    # candidate spelling that found each file (exact on case-sensitive
    # filesystems; on a case-insensitive one a file may be reported under
    # the probe's spelling rather than its stored name) — and say so.
    echo "WARNING: _real_case_path.sh not found next to discover_governance.sh; reporting candidate spellings as-is" >&2
    real_case_relpath() { printf '%s\n' "$2"; }
fi

OUTPUT_JSON=false
if [[ "${1:-}" == "--json" ]]; then
    OUTPUT_JSON=true
fi

emit() {
    local path="$1" type="$2" size="$3" scope="$4"
    local relpath="${path#"$ROOT_DIR"/}"
    if $OUTPUT_JSON; then
        printf '{"path":"%s","type":"%s","size":%s,"scope":"%s"}\n' \
            "$relpath" "$type" "$size" "$scope"
    else
        printf '%s\t%s\t%s\t%s\n' "$relpath" "$type" "$size" "$scope"
    fi
}

check_file() {
    local path="$1" type="$2" scope="$3"
    if [[ -f "$path" ]]; then
        local size
        # Report the name the file is stored under, not the candidate
        # spelling that found it: on a case-insensitive filesystem the
        # docs/PRINCIPLES.md probe also opens a stored docs/principles.md.
        path="$ROOT_DIR/$(real_case_relpath "$ROOT_DIR" "${path#"$ROOT_DIR"/}")"
        size=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null || echo 0)
        emit "$path" "$type" "$size" "$scope"
    fi
}

# check_file_alt <path> <type> <scope> <earlier-path>...
# Like check_file, but skips <path> when it is the same file as one of the
# earlier spellings already checked — on a case-insensitive filesystem
# (macOS default) docs/principles.md and docs/PRINCIPLES.md resolve to one
# file and must be reported once (under its stored name, via check_file).
check_file_alt() {
    local path="$1" type="$2" scope="$3"
    shift 3
    local earlier
    for earlier in "$@"; do
        [[ "$path" -ef "$earlier" ]] && return 0
    done
    check_file "$path" "$type" "$scope"
}

check_dir() {
    local dir="$1" type="$2" scope="$3" pattern="${4:-*.md}"
    if [[ -d "$dir" ]]; then
        while IFS= read -r -d '' file; do
            local size
            size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
            emit "$file" "$type" "$size" "$scope"
        done < <(find "$dir" -maxdepth 1 -name "$pattern" -type f -print0 2>/dev/null)
    fi
}

check_directory() {
    local dir="$1" type="$2" scope="$3"
    if [[ -d "$dir" ]]; then
        local count
        count=$(find "$dir" -type f 2>/dev/null | wc -l)
        emit "$dir" "$type" "$count" "$scope"
    fi
}

scan_scope() {
    local dir="$1" scope="$2"

    # Both spellings are accepted: the root/uppercase names (ARCHITECTURE.md,
    # PRINCIPLES.md) and the lowercase docs/ names the workspace itself uses
    # (docs/design.md, docs/principles.md). Projects are not forced into
    # either convention.
    check_file     "$dir/PRINCIPLES.md"       principles    "$scope"
    check_file     "$dir/docs/PRINCIPLES.md"  principles    "$scope"
    check_file_alt "$dir/docs/principles.md"  principles    "$scope" "$dir/docs/PRINCIPLES.md"
    check_file     "$dir/ARCHITECTURE.md"     architecture  "$scope"
    check_file     "$dir/docs/design.md"      architecture  "$scope"
    check_file "$dir/AGENTS.md"           agents-config "$scope"
    check_file "$dir/.agents/README.md"   agent-guide   "$scope"
    check_dir  "$dir/docs/decisions"      adr           "$scope"
    check_directory "$dir/.agents/workspace-context" workspace-context "$scope"
}

# Header (TSV only)
if ! $OUTPUT_JSON; then
    printf '%s\t%s\t%s\t%s\n' "path" "type" "size" "scope"
fi

# Scan workspace root
scan_scope "$ROOT_DIR" "workspace"

# Scan project repo under project/
if [[ -d "$ROOT_DIR/project" ]] && [[ ! -L "$ROOT_DIR/project" ]] || [[ -L "$ROOT_DIR/project" ]]; then
    project_dir="$ROOT_DIR/project"
    if [[ -d "$project_dir" ]]; then
        scan_scope "$project_dir" "project"
    fi
fi
