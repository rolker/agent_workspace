#!/usr/bin/env bash
# .agent/scripts/tests/test_review_viewer.sh
# Thin wrapper so run_script_tests.sh's `test_*.sh` glob picks up the
# review_viewer.py unit tests (test_review_viewer.py), as
# test_progress_read.sh does for progress_read.py.
#
# Run: bash .agent/scripts/tests/test_review_viewer.sh
#
# Selection declaration for run_script_tests.sh --files (issue #410): the
# module is named only as a `unittest` argument, which suites_for_files.sh
# cannot derive.
# covers: .agent/scripts/tests/test_review_viewer.py

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"
exec python3 -m unittest test_review_viewer -v
