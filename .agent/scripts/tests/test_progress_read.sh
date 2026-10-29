#!/usr/bin/env bash
# .agent/scripts/tests/test_progress_read.sh
# Thin wrapper so run_script_tests.sh's `test_*.sh` glob picks up the
# progress_read.py unit tests (test_progress_read.py), matching this repo's
# existing shell-test naming convention while keeping the Python-side
# assertions in a real unittest module (richer parametrization than a
# shell fixture would allow).
#
# Run: bash .agent/scripts/tests/test_progress_read.sh
#
# Selection declaration for run_script_tests.sh --files (issue #410): the
# module is named only as a `unittest` argument, which suites_for_files.sh
# cannot derive.
# covers: .agent/scripts/tests/test_progress_read.py

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"
exec python3 -m unittest test_progress_read -v
