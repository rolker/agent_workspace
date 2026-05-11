#!/usr/bin/env bash
# Tests for .claude/hooks/block-bash-tool-mapping.sh
#
# Run: bash .agent/scripts/tests/test_block_bash_tool_mapping.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/../../../.claude/hooks/block-bash-tool-mapping.sh"

if [[ ! -x "$HOOK" ]]; then
    echo "FATAL: hook not found or not executable at $HOOK"
    exit 1
fi

# Tests need a writable HOME so the sidecar log doesn't pollute the real one
TMP_HOME=$(mktemp -d /tmp/tool-mapping-test-XXXXXX)
trap 'rm -rf "$TMP_HOME"' EXIT
mkdir -p "$TMP_HOME/.claude"

PASS=0
FAIL=0

run_hook() {
    # $1 = command-string ; echoes nothing ; returns hook exit code
    local cmd="$1"
    local input
    input=$(jq -n --arg cmd "$cmd" '{
        session_id: "test", tool_name: "Bash",
        tool_input: {command: $cmd, description: "test"},
        cwd: "/tmp", permission_mode: "default"
    }')
    # shellcheck disable=SC2034
    local exit_code
    HOME="$TMP_HOME" bash "$HOOK" <<< "$input"
}

assert_blocks() {
    local label="$1" cmd="$2"
    local rc
    run_hook "$cmd" >/dev/null 2>&1
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
        echo "  PASS [block]:   $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL [block]:   $label  (expected exit 2, got $rc)"
        echo "     command: $cmd"
        FAIL=$((FAIL + 1))
    fi
}

assert_allows() {
    local label="$1" cmd="$2"
    local rc
    run_hook "$cmd" >/dev/null 2>&1
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "  PASS [allow]:   $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL [allow]:   $label  (expected exit 0, got $rc)"
        echo "     command: $cmd"
        FAIL=$((FAIL + 1))
    fi
}

echo
echo "=== Block cases ==="
assert_blocks "cat single file"                "cat README.md"
assert_blocks "cat multiple files"             "cat src/a.ts src/b.ts"
assert_blocks "head -N file (short flag)"      "head -5 file.md"
assert_blocks "head -n N file"                 "head -n 50 log.txt"
assert_blocks "head file (no count)"           "head file.txt"
assert_blocks "tail -N file"                   "tail -100 log.txt"
assert_blocks "tail -n N file"                 "tail -n 200 log.txt"
assert_blocks "find -name"                     "find . -name '*.ts'"
assert_blocks "find -type -name"               "find . -type f -name '*.md'"
assert_blocks "find no args (just path)"       "find ."
assert_blocks "sed -n line print"              "sed -n '40,80p' file.txt"
assert_blocks "sed -n single line"             "sed -n 5p file"
# Regression cases for the broken char-class heuristic. Each of these uses a
# real-world filename that contains lowercase 's', 'd', or 'p' — characters
# that the original heuristic mistook for sed-script tokens, causing
# false-negatives on the marquee case.
assert_blocks "sed -n on README.md"            "sed -n '5,10p' README.md"
assert_blocks "sed -n on notes.md"             "sed -n '5,10p' notes.md"
assert_blocks "sed -n on package.json"         "sed -n '1,20p' package.json"
assert_blocks "sed -n on src/main.rs"          "sed -n 5p src/main.rs"
assert_blocks "sed -ne combined cluster"       "sed -ne '5,10p' README.md"
assert_blocks "sed -i in-place"                "sed -i 's/x/y/' file.txt"
assert_blocks "sed -i with extension"          "sed -i.bak 's/x/y/' file.txt"
assert_blocks "sed --in-place long form"       "sed --in-place 's/x/y/' file.txt"
# Combined-cluster in-place forms — these previously bypassed has_sed_inplace.
assert_blocks "sed -ni combined cluster"       "sed -ni 's/x/y/' file.txt"
assert_blocks "sed -in combined cluster"       "sed -in 's/x/y/' file.txt"
assert_blocks "sed -niE combined with -E"      "sed -niE 's/x/y/' file.txt"
# Bare-find enumeration (documented as broader than just -name searches)
assert_blocks "find bare path"                 "find /etc"
assert_blocks "find single arg path"           "find ."

echo
echo "=== Allow cases (early-outs: pipes/redirects/heredocs) ==="
assert_allows "cat with pipe"                  "cat foo | grep bar"
assert_allows "cat with redirect"              "cat foo > out.txt"
assert_allows "cat with heredoc"               "cat <<EOF > out.md"
assert_allows "head with pipe"                 "git log | head -5"
assert_allows "tail with pipe"                 "git log | tail -5"
assert_allows "find with pipe"                 "find . | head -10"
assert_allows "sed with pipe"                  "echo hi | sed 's/i/o/'"
assert_allows "compound command (&&)"          "cd /tmp && cat file"
assert_allows "command substitution"           "cat \$(echo file.txt)"

echo
echo "=== Allow cases (special-mode flags) ==="
assert_allows "head -c byte mode"              "head -c 100 file.bin"
assert_allows "head -c attached form"          "head -c100 file.bin"
assert_allows "head --bytes long form"         "head --bytes=100 file.bin"
assert_allows "tail -f follow"                 "tail -f /var/log/syslog"
assert_allows "tail -F retry follow"           "tail -F /var/log/syslog"
assert_allows "tail --follow"                  "tail --follow=name /var/log/x"
assert_allows "find with -exec"                "find . -name '*.tmp' -exec rm {} +"
assert_allows "find with -delete"              "find . -name '*.tmp' -delete"
assert_allows "find with -mtime"               "find . -mtime -7"
assert_allows "find with -size"                "find . -size +1M"
assert_allows "find with -newer"               "find . -newer ref.txt"
assert_allows "find -print0"                   "find . -print0"
assert_allows "sed stream substitution"        "sed 's/x/y/' file"
assert_allows "sed without flags or file"      "sed"
# sed -n alone with one non-flag token = script only, stdin source (would be
# piped in real use → early-outed; this synthetic standalone test confirms
# the non-flag-count branch correctly distinguishes script-only from script+file).
assert_allows "sed -n script only (stdin)"     "sed -n '5p'"

echo
echo "=== Allow cases (unrelated commands) ==="
assert_allows "plain echo"                     "echo hello"
assert_allows "git log"                        "git log -5"
assert_allows "make target"                    "make test"
assert_allows "python script"                  "python3 script.py"
assert_allows "empty command"                  ""

echo
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
