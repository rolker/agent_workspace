#!/usr/bin/env bash
# .agent/scripts/tests/test_issue_helpers.sh
# Tests for .agent/scripts/_issue_helpers.sh's extract_gh_slug (issue 428):
# a remote URL gives owner/repo only when it is a github.com remote, with
# the grammar of sitrep_root.sh's gh_slug (issue 418).
#
# One table of URLs runs through extract_gh_slug and through gh_slug (the
# Python block sitrep_root.sh defines, taken from the script itself), so the
# two grammars cannot drift apart unnoticed. The intended differences are
# marked in the table ("differs"): the local test-fixture path form only.
#
# Hermetic: sources the helper file (it only defines functions) and runs
# python3 on text read from sitrep_root.sh. No git, no gh, no network.
#
# Run: bash .agent/scripts/tests/test_issue_helpers.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS="$SCRIPT_DIR/../_issue_helpers.sh"
SITREP_ROOT="$SCRIPT_DIR/../sitrep_root.sh"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# shellcheck source=../_issue_helpers.sh
source "$HELPERS"

# <url>|<expected slug, empty for none>|<same|differs>: "differs" marks an
# intended difference from gh_slug (gh_slug gives nothing there).
TABLE=(
    'git@github.com:o/r.git|o/r|same'
    'git@github.com:o/r|o/r|same'
    'https://github.com/o/r|o/r|same'
    'https://github.com/o/r/|o/r|same'
    'https://github.com/o/r.git/|o/r|same'
    'https://user:token@github.com/o/r.git|o/r|same'
    'http://github.com/o/r|o/r|same'
    'ssh://git@github.com/o/r.git|o/r|same'
    'ssh://git@github.com:22/o/r.git|o/r|same'
    'ssh://github.com/o/r|o/r|same'
    'git://github.com/o/r.git|o/r|same'
    'GIT@GITHUB.COM:o/r|o/r|same'
    'https://GitHub.Com/Acme-1/my_repo.v2.git|Acme-1/my_repo.v2|same'
    'git@github.com:o/r.git.git|o/r.git|same'
    'git@github.com:o/.github.git|o/.github|same'
    'git@github.com:o/.git|o/.git|same'
    '/tmp/x/fake_remotes/github.com/o/r.git|o/r|differs'
    '/tmp/x/fake_remotes/github.com/o/r|o/r|differs'
    '/tmp/github.com/a/fake_remotes/github.com/o/r.git|o/r|differs'
    'git@gitlab.com:o/r.git||same'
    'git@gitlab.com:acme/w.git||same'
    'https://gitlab.com/o/r||same'
    'https://example.com/o/r||same'
    'https://notgithub.com/o/r||same'
    'git@github.com.evil.example:o/r||same'
    'https://github.com.evil.example/o/r||same'
    'https://www.github.com/o/r||same'
    'https://ssh.github.com/o/r||same'
    'ssh://git@ssh.github.com:443/o/r.git||same'
    'https://github.example.com/o/r||same'
    'git@gitlab.com:group/github.com/o/r.git||same'
    'https://gitlab.com/github.com/o/r||same'
    '/x/notgithub.com/o/r.git||same'
    '/x/github.com.evil/o/r.git||same'
    '/x/GITHUB.COM/o/r.git||same'
    'x/github.com/o/r.git||same'
    'file:///x/github.com/o/r.git||same'
    'ssh://git@github.com/tmp/x/github.com/o/r.git||same'
    'https://github.com/o/r/extra||same'
    'https://github.com/o||same'
    'git@github.com:o/r/x.git||same'
    'git@github.com:-o/r||same'
    'git@github.com:o/-r||same'
    'git@github.com:o_x/r||same'
    'HTTPS://github.com/o/r||same'
    'https://github.com/o/r extra||same'
    ' git@github.com:o/r||same'
    'o/r||same'
    '||same'
)

echo "TEST: extract_gh_slug accepts github.com remotes and nothing else"
for row in "${TABLE[@]}"; do
    IFS='|' read -r url want _ <<< "$row"
    got="$(extract_gh_slug "$url")"
    if [[ "$got" == "$want" ]]; then
        pass "'$url' -> '${want}'"
    else
        fail "'$url': want '$want', got '$got'"
    fi
done

echo "TEST: the same table through sitrep_root.sh's gh_slug (parity)"
# The Python block sitrep_root.sh runs (between "read -r -d '' PYLIB <<'PY'"
# and "PY"); it only defines functions, so running it has no effect.
PYLIB="$(sed -n "/^read -r -d '' PYLIB <<'PY'\$/,/^PY\$/p" "$SITREP_ROOT" | sed '1d;$d')"
if ! command -v python3 >/dev/null 2>&1; then
    echo "  SKIP: no python3 (gh_slug is Python)"
elif [[ "$PYLIB" != *"def gh_slug("* ]]; then
    fail "gh_slug not found in sitrep_root.sh's PYLIB block: the parity table cannot run (was it moved or renamed?)"
else
    urls=()
    for row in "${TABLE[@]}"; do urls+=("${row%%|*}"); done
    mapfile -t py_out < <(printf '%s\0' "${urls[@]}" | python3 -I -c "$PYLIB
import sys
for u in sys.stdin.read().split('\0')[:-1]:
    print(gh_slug(u))")
    if [[ "${#py_out[@]}" -ne "${#TABLE[@]}" ]]; then
        fail "gh_slug gave ${#py_out[@]} answers for ${#TABLE[@]} rows"
    else
        for i in "${!TABLE[@]}"; do
            IFS='|' read -r url want kind <<< "${TABLE[$i]}"
            py="${py_out[$i]}"
            if [[ "$kind" == same ]]; then
                [[ "$py" == "$want" ]] && pass "parity '$url' -> '$want'" \
                    || fail "parity '$url': extract_gh_slug '$want', gh_slug '$py'"
            else
                # The intended difference: the local fixture path form.
                [[ -z "$py" ]] && pass "intended difference '$url': gh_slug gives nothing" \
                    || fail "intended difference '$url': gh_slug now gives '$py'; update the table"
            fi
        done
    fi
fi

echo ""
echo "test_issue_helpers: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
