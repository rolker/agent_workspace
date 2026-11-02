#!/usr/bin/env bash
# check_agents_md_budget.sh -- AGENTS.md stays at most 200 lines (issue #259).
#
# AGENTS.md is loaded into every session of every framework, so it holds
# rules and pointers; reference material goes to .agent/knowledge/. Run by
# the `agents-md-line-budget` pre-commit hook (also `make lint` and CI).
#
# Usage: check_agents_md_budget.sh [<file>]
#   <file> defaults to AGENTS.md at the root of the repository this script
#   lives in; the test suite passes fixture files.
# Exit: 0 within budget, 1 over budget, 2 file missing or unreadable.

set -euo pipefail

LIMIT=200
# -P: through the repo-root `scripts/` symlink, a logical path's `../..`
# would be the checkout's parent (as in capture.sh).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FILE="${1:-$(cd "$SCRIPT_DIR/../.." && pwd -P)/AGENTS.md}"

if [[ ! -f "$FILE" || ! -r "$FILE" ]]; then
    echo "check_agents_md_budget: cannot read $FILE" >&2
    exit 2
fi

# awk counts a last line that has no newline; `wc -l` would not.
LINES=$(awk 'END { print NR }' "$FILE")
if (( LINES > LIMIT )); then
    echo "AGENTS.md is $LINES lines, over the budget of $LIMIT ($FILE)." >&2
    echo "Move reference material to .agent/knowledge/ and leave a pointer." >&2
    exit 1
fi
