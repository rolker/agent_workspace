#!/usr/bin/env bash
# Tests for the per-project settings file .agent/projects.d/<name>
# (issue #332, PR 1): its grammar and keys (_project_registry.sh), the one
# writer and project_setting.sh, the records combinations and the refusal
# of a records repository that is a workspace, the provisional defaults
# (asserted through project_records_default, never as literals), the
# dispatcher and adapters reading the keys before the legacy files, and
# validate/dashboard reporting a malformed file.
#
# Every fixture is synthetic, built in a sandbox workspace under $TMPDIR
# (a git repository of its own, with copies of the real scripts); no test
# touches the real workspace, its registry or a real project checkout.
#
# Run: bash .agent/scripts/tests/test_project_file.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

PASS=0
FAIL=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    needle:   ${needle}"
        echo "    haystack: ${haystack}"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    unexpected needle: ${needle}"
        echo "    haystack:          ${haystack}"
        FAIL=$((FAIL + 1))
    fi
}

# ---- Sandbox helpers ----

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

gitq() { git -c user.name=t -c user.email=t@example.invalid -c init.defaultBranch=main "$@"; }

# A sandbox workspace: a git repository with copies of the real scripts and
# adapters committed, an origin remote, and NO workspace marker files (so a
# clone of it is caught by the path check alone).
make_sandbox() {
    local sb
    sb="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$sb/.agent/project_types"
    cp -r "$REAL_ROOT/.agent/scripts" "$sb/.agent/scripts"
    rm -rf "$sb/.agent/scripts/tests"
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$REAL_ROOT/.agent/project_types/ros2_colcon" \
        "$sb/.agent/project_types/"
    printf '.agent/projects.local\n.agent/projects.d/\n.agent/project_config.sh\n.agent/scratchpad/\n' > "$sb/.gitignore"
    gitq -C "$sb" init --quiet
    gitq -C "$sb" add -A
    gitq -C "$sb" commit --quiet -m sandbox
    gitq -C "$sb" remote add origin "git@github.com:example/ws-sandbox.git"
    echo "$sb"
}

# A synthetic project shaped like the Target's acceptance case: a
# single-repository web app, no remote (no GitHub issues or pull requests).
# make_project <sb> <name> → prints its path; registers it.
make_project() {
    local sb="$1" name="$2" dir
    dir="$(mktemp -d -p "$SANDBOX")/$name"
    mkdir -p "$dir/src"
    echo '{"name": "webapp"}' > "$dir/package.json"
    echo "<html></html>" > "$dir/src/index.html"
    gitq -C "$dir" init --quiet
    gitq -C "$dir" add -A
    gitq -C "$dir" commit --quiet -m init
    echo "$name single_project $dir" >> "$sb/.agent/projects.local"
    echo "$dir"
}

# A stub command that prints where it ran and its arguments.
make_stub() {
    local sb="$1" name="$2" rc="${3:-0}"
    mkdir -p "$sb/bin"
    cat > "$sb/bin/$name" <<EOF
#!/usr/bin/env bash
echo "STUB_${name}_RAN_IN:\$(pwd -P) args:\$*"
exit $rc
EOF
    chmod +x "$sb/bin/$name"
    echo "$sb/bin/$name"
}

pfile() { echo "$1/.agent/projects.d/$2"; }

write_pfile() {
    local sb="$1" name="$2"
    mkdir -p "$sb/.agent/projects.d"
    cat > "$(pfile "$sb" "$name")"
}

# Run a registry function inside the sandbox (sourcing its copy).
reg() {
    local sb="$1"
    shift
    bash -c 'source "$1/.agent/scripts/_project_registry.sh"; shift; "$@"' _ "$sb" "$@"
}

ps_run() {
    local sb="$1"
    shift
    (cd "$sb" && "$sb/.agent/scripts/project_setting.sh" "$@")
}

# A git repository at <dir> with an origin remote <url> (empty: none).
make_records_repo() {
    local dir="$1" url="${2:-}"
    mkdir -p "$dir"
    gitq -C "$dir" init --quiet
    echo "records" > "$dir/README"
    gitq -C "$dir" add -A
    gitq -C "$dir" commit --quiet -m init
    [ -n "$url" ] && gitq -C "$dir" remote add origin "$url"
    return 0
}

# ---- Grammar ----

test_no_file_is_all_defaults() {
    echo "TEST: no settings file: valid, every setting at its default"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "check exits 0" "0" "$rc"
    assert_contains "says there is no file" "no settings file for 'alpha'" "$out"
    rc=0
    out="$(ps_run "$sb" get alpha build 2>&1)" || rc=$?
    assert_eq "get of an absent key exits 1" "1" "$rc"
}

test_grammar_comments_blanks_crlf() {
    echo "TEST: comments, blank lines, surrounding blanks and CRLF; '#' inside a command is kept"
    local sb out
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    printf '# a comment\r\n\r\n   build = make all#target \r\n  # indented comment\ntest=make check\n' \
        | write_pfile "$sb" alpha
    out="$(ps_run "$sb" get alpha build)"
    assert_eq "build value trimmed, '#' kept" "make all#target" "$out"
    out="$(ps_run "$sb" get alpha test)"
    assert_eq "test value read" "make check" "$out"
}

test_grammar_errors() {
    echo "TEST: unknown key, duplicate key, empty value, no '=' and bad values are errors naming file and line"
    local sb out rc
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    local f
    f="$(pfile "$sb" alpha)"

    printf 'build=make\nbuld=make\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "unknown key: exit 2" "2" "$rc"
    assert_contains "unknown key named with file:line" "$f:2: unknown key 'buld'" "$out"
    assert_contains "known keys listed" "known keys: build test install bootstrap_url location location_path tracking instructions" "$out"

    printf 'build=make\nbuild=make all\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "duplicate key: exit 2" "2" "$rc"
    assert_contains "duplicate named" "$f:2: duplicate key 'build'" "$out"

    printf 'test=\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "empty value: exit 2" "2" "$rc"
    assert_contains "empty value named" "$f:1: empty value for 'test'" "$out"

    printf 'just words\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "no '=': exit 2" "2" "$rc"
    assert_contains "no '=' named" "$f:1: expected key=value" "$out"

    printf 'location=elsewhere\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "bad location: exit 2" "2" "$rc"
    assert_contains "bad location named" "location must be 'project' or 'outside'" "$out"

    printf 'location=outside\nlocation_path=relative/dir\ntracking=untracked\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "relative location_path: exit 2" "2" "$rc"
    assert_contains "absolute path required" "location_path must be an absolute path" "$out"

    printf 'bootstrap_url=ftp://host/bootstrap.yaml\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "bad bootstrap_url: exit 2" "2" "$rc"

    printf 'instructions=maybe\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "bad instructions: exit 2" "2" "$rc"
}

test_command_shell_syntax_refused() {
    echo "TEST: a command with shell syntax is refused with 'point the key at a script'"
    local sb out rc v
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    for v in 'cmake -S . -B build && cmake --build build' 'make | tee log' 'echo "hi"' "echo 'hi'" \
        'make $TARGET' 'make; make test' 'make > log' 'run (x)' 'make `x`' 'a\b'; do
        printf 'build=%s\n' "$v" | write_pfile "$sb" alpha
        rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
        assert_eq "refused: $v" "2" "$rc"
        assert_contains "points at a script: $v" "point the key at a script" "$out"
    done
    printf 'build=none\ntest=./scripts/test.sh --fast\ninstall=/opt/tools/deploy *.whl\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "none, a relative script and a glob-looking word are accepted" "0" "$rc"
}

test_registry_refuses_dot_sh_name() {
    echo "TEST: a registry name ending in .sh is refused (it would collide with a legacy file)"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir -p "$sb/proj"
    echo "tools.sh single_project $sb/proj" > "$sb/.agent/projects.local"
    out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "parse fails" "2" "$rc"
    assert_contains "says why" "may not end in '.sh'" "$out"
}

# ---- Records combinations and defaults ----

test_absent_pair_resolves_to_default() {
    echo "TEST: an absent location/tracking pair resolves to the accepts-footprint default, (project, project)"
    local sb out dflt dloc dtrack rec
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    printf 'build=make\n' | write_pfile "$sb" alpha
    dflt="$(reg "$sb" project_records_default "$sb" alpha accepts-footprint)"
    IFS=$'\t' read -r dloc dtrack _ <<< "$dflt"
    rec="$(reg "$sb" project_records_check "$sb" alpha 2>/dev/null)"
    assert_eq "resolved pair equals project_records_default's" "$dloc	$dtrack	" "$rec"
    assert_eq "and that default is (project, project)" "project	project" "$dloc	$dtrack"
    # The zero-footprint mode never resolves a file: no file says it.
    out="$(reg "$sb" project_records_default "$sb" alpha zero-footprint)"
    assert_contains "zero-footprint mode is marked provisional" "provisional" "$out"
    assert_contains "accepts-footprint default is marked provisional" "provisional" "$dflt"
}

test_default_outside_layout_comes_from_the_function() {
    echo "TEST: location=outside without location_path uses project_records_default's layout"
    local sb out layout rec
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    printf 'location=outside\ntracking=untracked\n' | write_pfile "$sb" alpha
    layout="$(reg "$sb" project_records_default "$sb" alpha zero-footprint | cut -f3)"
    rec="$(reg "$sb" project_records_check "$sb" alpha 2>/dev/null || true)"
    assert_eq "location_path filled from the function" "outside	untracked	$layout" "$rec"
    out="$(reg "$sb" project_records_check "$sb" alpha 2>&1 >/dev/null || true)"
    assert_contains "said to be the provisional default" "provisional default" "$out"
}

test_valid_combinations_on_acceptance_shape() {
    echo "TEST: the acceptance shape (no-remote web app) validates with every valid combination"
    local sb out rc dir recs
    sb="$(make_sandbox)"
    dir="$(make_project "$sb" webapp)"
    recs="$(mktemp -d -p "$SANDBOX")"

    printf 'location=project\ntracking=project\n' | write_pfile "$sb" webapp
    rc=0; out="$(ps_run "$sb" check webapp 2>&1)" || rc=$?
    assert_eq "(project, project): valid and honoured, exit 0" "0" "$rc"

    printf 'location=project\ntracking=untracked\n' | write_pfile "$sb" webapp
    rc=0; out="$(ps_run "$sb" check webapp 2>&1)" || rc=$?
    assert_eq "(project, untracked): valid, not yet honoured, exit 3" "3" "$rc"
    assert_contains "flagged not yet honoured, citing the lookup issue" "not yet honoured" "$out"
    assert_contains "cites #393" "#393" "$out"

    printf 'location=outside\nlocation_path=%s/untracked\ntracking=untracked\n' "$recs" | write_pfile "$sb" webapp
    rc=0; out="$(ps_run "$sb" check webapp 2>&1)" || rc=$?
    assert_eq "(outside, untracked): exit 3" "3" "$rc"

    make_records_repo "$recs/repo" "git@example.org:someone/webapp-records.git"
    printf 'location=outside\nlocation_path=%s/repo\ntracking=repo\n' "$recs" | write_pfile "$sb" webapp
    rc=0; out="$(ps_run "$sb" check webapp 2>&1)" || rc=$?
    assert_eq "(outside, repo) with a separate records repository: exit 3" "3" "$rc"

    printf 'location=outside\nlocation_path=%s/not-yet\ntracking=repo\n' "$recs" | write_pfile "$sb" webapp
    rc=0; out="$(ps_run "$sb" check webapp 2>&1)" || rc=$?
    assert_eq "(outside, repo) not cloned yet: valid, exit 3" "3" "$rc"
    assert_contains "unverifiable until cloned" "unverifiable until cloned" "$out"
    [ -n "$dir" ]
}

test_refused_combinations() {
    echo "TEST: refused combinations stop check and the dispatcher"
    local sb out rc
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null

    printf 'location=outside\nlocation_path=/srv/r\ntracking=project\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "(outside, project) refused" "2" "$rc"

    printf 'tracking=repo\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "(project, repo) refused" "2" "$rc"
    assert_contains "says repo needs outside" "needs location=outside" "$out"

    printf 'location_path=/srv/r\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "location_path without outside refused" "2" "$rc"

    printf 'location=outside\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "outside without tracking refused" "2" "$rc"

    rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha project_root 2>&1)" || rc=$?
    assert_eq "dispatcher stops on a refused combination" "1" "$rc"
}

# ---- A records repository must not be a workspace ----

refuse_case() {
    local label="$1" sb="$2" recdir="$3" needle="$4" out rc=0
    printf 'location=outside\nlocation_path=%s\ntracking=repo\n' "$recdir" | write_pfile "$sb" alpha
    out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "$label: refused (exit 2)" "2" "$rc"
    assert_contains "$label: plain rule stated" "a records repository must not be a workspace" "$out"
    assert_contains "$label: names the check" "$needle" "$out"
}

test_records_repo_workspace_by_remote_url() {
    echo "TEST: records repository whose remote is the workspace's (another URL form) is refused"
    local sb recs
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    recs="$(mktemp -d -p "$SANDBOX")"
    make_records_repo "$recs/r1" "https://GitHub.com/Example/ws-sandbox.git/"
    refuse_case "https form of the scp remote" "$sb" "$recs/r1" "is the workspace's remote 'origin'"
    make_records_repo "$recs/r2" "ssh://git@github.com:22/example/ws-sandbox"
    refuse_case "ssh form with a port" "$sb" "$recs/r2" "is the workspace's remote 'origin'"
}

test_records_repo_workspace_by_local_path() {
    echo "TEST: records repository whose remote is a local path or file:// URL at the workspace or a worktree is refused"
    local sb recs wt
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    recs="$(mktemp -d -p "$SANDBOX")"
    gitq clone --quiet "$sb" "$recs/clone"
    refuse_case "git clone of the workspace checkout" "$sb" "$recs/clone" "is the workspace checkout or one of its worktrees"
    make_records_repo "$recs/fileurl" "file://$sb"
    refuse_case "file:// URL" "$sb" "$recs/fileurl" "is the workspace checkout or one of its worktrees"
    wt="$(mktemp -d -p "$SANDBOX")/wt"
    gitq -C "$sb" worktree add --quiet -b wt-branch "$wt"
    make_records_repo "$recs/towt" "$wt"
    refuse_case "a remote at a workspace worktree" "$sb" "$recs/towt" "is the workspace checkout or one of its worktrees"
}

test_records_repo_workspace_by_contents() {
    echo "TEST: records repository containing the workspace marker files is refused, whatever its remote"
    local sb recs
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    recs="$(mktemp -d -p "$SANDBOX")"

    make_records_repo "$recs/fork1" "git@other-host.example:someone-else/renamed-fork.git"
    mkdir -p "$recs/fork1/.agent"
    echo "# list" > "$recs/fork1/.agent/user_tier_scripts.txt"
    refuse_case "user_tier_scripts.txt in the working tree" "$sb" "$recs/fork1" ".agent/user_tier_scripts.txt"

    make_records_repo "$recs/fork2" "https://example.org/x/y.git"
    mkdir -p "$recs/fork2/.claude-plugin"
    printf '{\n  "name": "agent-workspace",\n  "skills": []\n}\n' > "$recs/fork2/.claude-plugin/plugin.json"
    refuse_case "plugin.json naming the workspace plugin" "$sb" "$recs/fork2" ".claude-plugin/plugin.json"

    make_records_repo "$recs/fork3" ""
    mkdir -p "$recs/fork3/.agent"
    echo "# list" > "$recs/fork3/.agent/user_tier_scripts.txt"
    gitq -C "$recs/fork3" add -A
    gitq -C "$recs/fork3" commit --quiet -m markers
    rm "$recs/fork3/.agent/user_tier_scripts.txt"
    refuse_case "a marker only in HEAD" "$sb" "$recs/fork3" "in its HEAD commit"

    # Another plugin's manifest is not a marker.
    local out rc=0
    make_records_repo "$recs/other" "https://example.org/x/records.git"
    mkdir -p "$recs/other/.claude-plugin"
    printf '{"name": "some-other-plugin"}\n' > "$recs/other/.claude-plugin/plugin.json"
    printf 'location=outside\nlocation_path=%s\ntracking=repo\n' "$recs/other" | write_pfile "$sb" alpha
    out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "another plugin's manifest: valid (exit 3)" "3" "$rc"
}

test_records_dir_inside_workspace_repo() {
    echo "TEST: tracking=repo inside the workspace's own repository is refused; untracked records under its scratchpad validate"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    mkdir -p "$sb/.agent/scratchpad/records"
    refuse_case "a directory of the workspace repository" "$sb" "$sb/.agent/scratchpad/records" "in the workspace's own repository"
    printf 'location=outside\nlocation_path=%s\ntracking=untracked\n' "$sb/.agent/scratchpad/records" | write_pfile "$sb" alpha
    out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "untracked records under the scratchpad: valid (exit 3)" "3" "$rc"
    assert_not_contains "not refused" "must not be a workspace" "$out"
}

test_dispatcher_refuses_workspace_records_repo() {
    echo "TEST: the dispatcher stops when the records repository is a workspace"
    local sb out rc=0 recs
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    recs="$(mktemp -d -p "$SANDBOX")"
    gitq clone --quiet "$sb" "$recs/clone"
    printf 'location=outside\nlocation_path=%s\ntracking=repo\n' "$recs/clone" | write_pfile "$sb" alpha
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha project_root 2>&1)" || rc=$?
    assert_eq "exits 1" "1" "$rc"
    assert_contains "says why" "a records repository must not be a workspace" "$out"
}

# ---- The writer and project_setting.sh ----

test_set_get_list_idempotent() {
    echo "TEST: set writes, get reads, list shows; an identical second set changes no byte"
    local sb out f before
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    f="$(pfile "$sb" alpha)"
    out="$(ps_run "$sb" set alpha build=./scripts/build.sh "test=make check" instructions=none)"
    assert_contains "reports the write" "updated $f" "$out"
    assert_eq "file content" "build=./scripts/build.sh
test=make check
instructions=none" "$(cat "$f")"
    assert_eq "get" "make check" "$(ps_run "$sb" get alpha test)"
    out="$(ps_run "$sb" list alpha)"
    assert_contains "list shows a key" "build=./scripts/build.sh" "$out"
    assert_contains "list shows the records default as provisional" "location=project tracking=project (location: default, provisional)" "$out"
    before="$(cksum < "$f")"
    out="$(ps_run "$sb" set alpha build=./scripts/build.sh "test=make check")"
    assert_contains "second identical set says unchanged" "unchanged $f" "$out"
    assert_eq "no byte changed" "$before" "$(cksum < "$f")"
}

test_set_keeps_comments_and_order() {
    echo "TEST: set replaces a key in place and keeps comments; unset removes; last unset removes the file"
    local sb f out
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    f="$(pfile "$sb" alpha)"
    printf '# commands\nbuild=make\n# tests next\ntest=make test\n' | write_pfile "$sb" alpha
    ps_run "$sb" set alpha build=./b.sh install=none >/dev/null
    assert_eq "in place, comments kept, new key appended" "# commands
build=./b.sh
# tests next
test=make test
install=none" "$(cat "$f")"
    ps_run "$sb" unset alpha test >/dev/null
    assert_not_contains "test removed" "test=" "$(cat "$f")"
    printf 'build=make\n' | write_pfile "$sb" alpha
    out="$(ps_run "$sb" unset alpha build)"
    assert_contains "last key removed: file removed" "removed $f" "$out"
    assert_eq "file gone" "no" "$([ -e "$f" ] && echo yes || echo no)"
}

test_composite_keys_refused() {
    echo "TEST: a key made of several known keys ('build test', 'location location_path') is unknown, in the parser and the writer"
    local sb f out rc ck
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    f="$(pfile "$sb" alpha)"
    for ck in "build test" "location location_path" "test install" "tracking instructions"; do
        printf '%s=foo\n' "$ck" | write_pfile "$sb" alpha
        rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
        assert_eq "parser, '$ck': check exits 2" "2" "$rc"
        assert_contains "parser, '$ck': named as an unknown key" "$f:1: unknown key '$ck'" "$out"
        rc=0; out="$(ps_run "$sb" get alpha build 2>&1)" || rc=$?
        assert_eq "parser, '$ck': get on the invalid file exits 2" "2" "$rc"
        rm -f "$f"

        rc=0; out="$(ps_run "$sb" set alpha "$ck=foo" 2>&1)" || rc=$?
        assert_eq "writer, '$ck': set exits 1" "1" "$rc"
        assert_contains "writer, '$ck': named as an unknown key" "unknown key '$ck'" "$out"
        assert_eq "writer, '$ck': no file written" "no" "$([ -e "$f" ] && echo yes || echo no)"
        rc=0; out="$(ps_run "$sb" unset alpha "$ck" 2>&1)" || rc=$?
        assert_eq "writer, '$ck': unset exits 1" "1" "$rc"
    done
    assert_eq "no temporary file left" "" "$(find "$sb/.agent/projects.d" -name '.alpha.*' 2>/dev/null)"
}

# A file's permission bits in octal (GNU stat, else BSD stat).
fmode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

test_set_keeps_mode_and_symlink() {
    echo "TEST: set keeps an existing file's mode and a symlinked file's link; a new file is 644"
    local sb f out rc target
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    make_project "$sb" beta >/dev/null
    f="$(pfile "$sb" alpha)"

    ps_run "$sb" set alpha build=make >/dev/null
    assert_eq "new file is 644" "644" "$(fmode "$f")"
    chmod 600 "$f"
    ps_run "$sb" set alpha "test=make check" >/dev/null
    assert_eq "mode 600 kept after set" "600" "$(fmode "$f")"
    ps_run "$sb" unset alpha test >/dev/null
    assert_eq "mode 600 kept after unset" "600" "$(fmode "$f")"
    assert_eq "content right" "build=make" "$(cat "$f")"

    target="$(mktemp -d -p "$SANDBOX")/beta.settings"
    printf '# kept elsewhere\nbuild=make\n' > "$target"
    chmod 640 "$target"
    ln -s "$target" "$(pfile "$sb" beta)"
    rc=0; out="$(ps_run "$sb" set beta "test=make check" 2>&1)" || rc=$?
    assert_eq "set through a symlink: exit 0" "0" "$rc"
    assert_eq "still a symlink" "yes" "$([ -L "$(pfile "$sb" beta)" ] && echo yes || echo no)"
    assert_eq "link still points at the target" "$target" "$(readlink "$(pfile "$sb" beta)")"
    assert_eq "target rewritten, comment kept" "$(printf '# kept elsewhere\nbuild=make\ntest=make check')" "$(cat "$target")"
    assert_eq "target mode 640 kept" "640" "$(fmode "$target")"
    assert_eq "get reads through the link" "make check" "$(ps_run "$sb" get beta test)"
    assert_eq "no temporary file left beside the target" "" "$(find "$(dirname "$target")" -name '.beta.*')"

    printf 'build=make\n' > "$target"
    rc=0; out="$(ps_run "$sb" unset beta build 2>&1)" || rc=$?
    assert_eq "unset of the last key through a symlink: exit 0" "0" "$rc"
    assert_eq "link kept when nothing is left" "yes" "$([ -L "$(pfile "$sb" beta)" ] && echo yes || echo no)"
    assert_eq "target emptied" "" "$(cat "$target")"
    assert_eq "target still exists" "yes" "$([ -f "$target" ] && echo yes || echo no)"
    rc=0; ps_run "$sb" check beta >/dev/null 2>&1 || rc=$?
    assert_eq "an empty target checks valid" "0" "$rc"
}

test_set_refuses_unusable_path() {
    echo "TEST: set refuses a path that exists but is not a readable regular file, directly or through a symlink"
    local sb f out rc other
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    f="$(pfile "$sb" alpha)"
    other="$(mktemp -d -p "$SANDBOX")"

    mkdir -p "$f"
    rc=0; out="$(ps_run "$sb" set alpha build=make 2>&1)" || rc=$?
    assert_eq "directory: exit 1" "1" "$rc"
    assert_contains "directory: says why" "$f exists but is not a regular file" "$out"
    assert_eq "directory: nothing moved inside it" "" "$(ls -A "$f")"
    rmdir "$f"

    mkdir -p "$other/dir"
    ln -s "$other/dir" "$f"
    rc=0; out="$(ps_run "$sb" set alpha build=make 2>&1)" || rc=$?
    assert_eq "symlink to a directory: exit 1" "1" "$rc"
    assert_contains "symlink to a directory: says why" "is not a regular file" "$out"
    assert_eq "symlink to a directory: nothing moved inside it" "" "$(ls -A "$other/dir")"
    rm -f "$f"

    if [ "$(id -u)" -ne 0 ]; then
        printf 'build=make\ntest=make check\n' | write_pfile "$sb" alpha
        chmod 000 "$f"
        rc=0; out="$(ps_run "$sb" set alpha install=make 2>&1)" || rc=$?
        assert_eq "mode 000 file: exit 1" "1" "$rc"
        assert_contains "mode 000 file: says why" "$f is not readable" "$out"
        chmod 600 "$f"
        assert_eq "mode 000 file: settings kept" "$(printf 'build=make\ntest=make check')" "$(cat "$f")"
        rm -f "$f"

        printf 'build=make\n' > "$other/locked"
        chmod 000 "$other/locked"
        ln -s "$other/locked" "$f"
        rc=0; out="$(ps_run "$sb" set alpha install=make 2>&1)" || rc=$?
        assert_eq "symlink to a mode 000 file: exit 1" "1" "$rc"
        assert_contains "symlink to a mode 000 file: says why" "is not readable" "$out"
        chmod 600 "$other/locked"
        assert_eq "symlink to a mode 000 file: settings kept" "build=make" "$(cat "$other/locked")"
        rm -f "$f"
    else
        echo "  SKIP: mode 000 cases (running as root, which reads any file)"
    fi
    assert_eq "no temporary file left" "" "$(find "$sb/.agent/projects.d" "$other" -name '.alpha.*')"
}

test_symlink_cases() {
    echo "TEST: symlinked settings files: dangling and unresolvable links are errors everywhere; link to link and relative targets work"
    local sb f out rc store
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    f="$(pfile "$sb" alpha)"
    store="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$sb/.agent/projects.d"

    ln -s "$store/missing" "$f"
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "dangling: check exits 2" "2" "$rc"
    assert_contains "dangling: named" "$f is a symlink (to '$store/missing') that does not resolve to an existing file" "$out"
    assert_not_contains "dangling: never 'OK'" "OK:" "$out"
    rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha env 2>&1)" || rc=$?
    assert_eq "dangling: the adapter stops" "1" "$rc"
    assert_contains "dangling: the adapter says why" "does not resolve to an existing file" "$out"
    rc=0; out="$(ps_run "$sb" set alpha build=make 2>&1)" || rc=$?
    assert_eq "dangling: set refused" "1" "$rc"
    assert_eq "dangling: no target created" "no" "$([ -e "$store/missing" ] && echo yes || echo no)"
    rm -f "$f"

    ln -s "$store/loop-b" "$store/loop-a"
    ln -s "$store/loop-a" "$store/loop-b"
    ln -s "$store/loop-a" "$f"
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "unresolvable (loop): check exits 2" "2" "$rc"
    assert_contains "unresolvable (loop): named" "does not resolve to an existing file" "$out"
    rc=0; out="$(ps_run "$sb" set alpha build=make 2>&1)" || rc=$?
    assert_eq "unresolvable (loop): set refused" "1" "$rc"
    rm -f "$f" "$store/loop-a" "$store/loop-b"

    printf 'build=make\n' > "$store/real"
    ln -s "$store/real" "$store/middle"
    ln -s "$store/middle" "$f"
    assert_eq "link to link: get reads the final target" "make" "$(ps_run "$sb" get alpha build)"
    rc=0; ps_run "$sb" set alpha "test=make check" >/dev/null 2>&1 || rc=$?
    assert_eq "link to link: set exits 0" "0" "$rc"
    assert_eq "link to link: final target rewritten" "$(printf 'build=make\ntest=make check')" "$(cat "$store/real")"
    assert_eq "link to link: first link kept" "$store/middle" "$(readlink "$f")"
    assert_eq "link to link: second link kept" "$store/real" "$(readlink "$store/middle")"
    rm -f "$f"

    mkdir -p "$sb/.agent/store"
    printf 'build=make\n' > "$sb/.agent/store/alpha.cfg"
    ln -s ../store/alpha.cfg "$f"
    assert_eq "relative target: get reads it" "make" "$(ps_run "$sb" get alpha build)"
    rc=0; ps_run "$sb" set alpha install=make >/dev/null 2>&1 || rc=$?
    assert_eq "relative target: set exits 0" "0" "$rc"
    assert_eq "relative target: target rewritten" "$(printf 'build=make\ninstall=make')" "$(cat "$sb/.agent/store/alpha.cfg")"
    assert_eq "relative target: link still relative" "../store/alpha.cfg" "$(readlink "$f")"
    assert_eq "no temporary file left" "" "$(find "$sb/.agent" "$store" -name '.alpha.*')"
}

test_unknown_key_repair() {
    echo "TEST: a misspelt key is named with its repair, and unset removes it; set still refuses an unknown key"
    local sb f out rc
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    f="$(pfile "$sb" alpha)"
    printf '# mine\nbuld=make\nbuild=make\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_eq "check exits 2" "2" "$rc"
    assert_contains "the error names the unset repair" "remove it with: .agent/scripts/project_setting.sh unset alpha 'buld', or edit the file by hand" "$out"
    rc=0; out="$(ps_run "$sb" set alpha test=make 2>&1)" || rc=$?
    assert_eq "set on the broken file: exit 2" "2" "$rc"
    assert_contains "the replayed error names the project, not the temporary file" "unset alpha 'buld'" "$out"
    rc=0; out="$(ps_run "$sb" set alpha buld=other 2>&1)" || rc=$?
    assert_eq "set of an unknown key: still exit 1" "1" "$rc"
    rc=0; out="$(ps_run "$sb" unset alpha nosuch 2>&1)" || rc=$?
    assert_eq "unset of an unknown key the file lacks: exit 1" "1" "$rc"
    assert_contains "named as unknown" "unknown key 'nosuch'" "$out"
    rc=0; out="$(ps_run "$sb" unset alpha buld 2>&1)" || rc=$?
    assert_eq "unset of the misspelt key: exit 0" "0" "$rc"
    assert_eq "only that line removed, comment kept" "$(printf '# mine\nbuild=make')" "$(cat "$f")"
    rc=0; ps_run "$sb" check alpha >/dev/null 2>&1 || rc=$?
    assert_eq "the repaired file checks valid" "0" "$rc"

    printf 'build=make\nbuild=make all\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" check alpha 2>&1)" || rc=$?
    assert_contains "a duplicate names the hand edit" "edit the file by hand to keep one line" "$out"
}

test_set_refusals() {
    echo "TEST: set refuses invalid results, unknown keys, unregistered names and parent roots, leaving the file as it was"
    local sb f out rc before
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    f="$(pfile "$sb" alpha)"
    ps_run "$sb" set alpha build=make >/dev/null
    before="$(cat "$f")"

    rc=0; out="$(ps_run "$sb" set alpha "build=make && make install" 2>&1)" || rc=$?
    assert_eq "shell syntax: exit 2" "2" "$rc"
    assert_contains "names the real file" "$f" "$out"
    assert_not_contains "never names the temporary file" "/.alpha." "$out"
    assert_eq "file unchanged" "$before" "$(cat "$f")"
    assert_eq "no temporary file left" "" "$(find "$sb/.agent/projects.d" -name '.alpha.*')"

    rc=0; out="$(ps_run "$sb" set alpha colour=blue 2>&1)" || rc=$?
    assert_eq "unknown key: exit 1" "1" "$rc"

    rc=0; out="$(ps_run "$sb" set nobody build=make 2>&1)" || rc=$?
    assert_eq "unregistered: exit 1" "1" "$rc"
    assert_contains "says not registered" "not registered" "$out"

    mkdir -p "$sb/parent/inst"
    gitq -C "$sb/parent/inst" init --quiet
    printf 'fam project %s default_instance=fam-a\nfam-a single_project %s parent=fam\n' \
        "$sb/parent" "$sb/parent/inst" >> "$sb/.agent/projects.local"
    rc=0; out="$(ps_run "$sb" set fam build=make 2>&1)" || rc=$?
    assert_eq "parent root: exit 1" "1" "$rc"
    assert_contains "settings belong to instances" "settings belong to its instances" "$out"
}

test_set_refuses_non_default_records() {
    echo "TEST: set refuses any records combination but the default until the lookup lands (#393)"
    local sb f out rc
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    f="$(pfile "$sb" alpha)"
    rc=0; out="$(ps_run "$sb" set alpha location=outside tracking=untracked location_path=/srv/r 2>&1)" || rc=$?
    assert_eq "refused, exit 1" "1" "$rc"
    assert_contains "says not honoured" "not honoured until the records lookup lands" "$out"
    assert_contains "cites the follow-up issue" "#393" "$out"
    assert_eq "nothing written" "no" "$([ -e "$f" ] && echo yes || echo no)"
    rc=0; out="$(ps_run "$sb" set alpha tracking=untracked 2>&1)" || rc=$?
    assert_eq "(project, untracked) refused too" "1" "$rc"
    rc=0; out="$(ps_run "$sb" set alpha location=project tracking=project 2>&1)" || rc=$?
    assert_eq "the default pair is stored" "0" "$rc"
    # A hand-written non-default file: unrelated keys can still be set.
    printf 'location=project\ntracking=untracked\n' | write_pfile "$sb" alpha
    rc=0; out="$(ps_run "$sb" set alpha build=make 2>&1)" || rc=$?
    assert_eq "an unrelated key on a hand-written file" "0" "$rc"
    rc=0; out="$(ps_run "$sb" unset alpha location tracking 2>&1)" || rc=$?
    assert_eq "unsetting the pair together returns to the default" "0" "$rc"
}

test_worktree_copy_reads_main_and_refuses_writes() {
    echo "TEST: from a linked worktree, project_setting.sh reads the main checkout's files and refuses to write"
    local sb wt out rc=0
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    ps_run "$sb" set alpha build=make >/dev/null
    wt="$(mktemp -d -p "$SANDBOX")/wt"
    gitq -C "$sb" worktree add --quiet -b wt-read "$wt"
    out="$(cd "$wt" && "$wt/.agent/scripts/project_setting.sh" get alpha build)"
    assert_eq "get reads the main checkout's file" "make" "$out"
    out="$(cd "$wt" && "$wt/.agent/scripts/project_setting.sh" set alpha build=other 2>&1)" || rc=$?
    assert_eq "set refused" "1" "$rc"
    assert_contains "points at the main checkout's copy" "$sb/.agent/scripts/project_setting.sh set alpha" "$out"
    assert_eq "main file unchanged" "make" "$(ps_run "$sb" get alpha build)"
}

test_run_through_scripts_symlink() {
    echo "TEST: project_setting.sh run through the root 'scripts' symlink finds its own workspace"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    ln -s .agent/scripts "$sb/scripts"
    out="$(cd "$sb" && "$sb/scripts/project_setting.sh" set alpha build=make 2>&1)" || rc=$?
    assert_eq "set through the symlink: exit 0" "0" "$rc"
    assert_contains "writes this workspace's file" "updated $(cd "$sb" && pwd -P)/.agent/projects.d/alpha" "$out"
    rc=0; out="$(cd "$sb" && "$sb/scripts/project_setting.sh" get alpha build 2>&1)" || rc=$?
    assert_eq "get through the symlink: exit 0" "0" "$rc"
    assert_eq "get reads this workspace's file" "make" "$out"
    assert_eq "nothing written beside the sandbox" "no" "$([ -e "$(dirname "$sb")/.agent" ] && echo yes || echo no)"
}

# ---- Dispatcher and adapters ----

test_build_test_install_from_file() {
    echo "TEST: build/test/install come from the settings file first, split into argv, no shell, no globbing"
    local sb dir stub out real
    sb="$(make_sandbox)"
    dir="$(make_project "$sb" alpha)"
    real="$(cd "$dir" && pwd -P)"
    stub="$(make_stub "$sb" filecmd)"
    make_stub "$sb" legacycmd >/dev/null
    make_stub "$sb" sharedcmd >/dev/null
    mkdir -p "$sb/.agent/projects.d"
    echo "BUILD_CMD=\"$sb/bin/legacycmd\"" > "$sb/.agent/projects.d/alpha.sh"
    echo "BUILD_CMD=\"$sb/bin/sharedcmd\"" > "$sb/.agent/project_config.sh"
    touch "$dir/a.txt" "$dir/b.txt"
    printf 'build=%s --fast *.txt\ntest=%s t\ninstall=%s i\n' "$stub" "$stub" "$stub" | write_pfile "$sb" alpha
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build extra 2>&1)"
    assert_contains "file key wins over legacy and shared, runs in the root, extra args appended, no globbing" \
        "STUB_filecmd_RAN_IN:$real args:--fast *.txt extra" "$out"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha test 2>&1)"
    assert_contains "test from the file" "STUB_filecmd_RAN_IN:$real args:t" "$out"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha install 2>&1)"
    assert_contains "install from the file" "STUB_filecmd_RAN_IN:$real args:i" "$out"
}

test_relative_script_path() {
    echo "TEST: a command whose first word is a relative script path runs from the project root"
    local sb dir out
    sb="$(make_sandbox)"
    dir="$(make_project "$sb" alpha)"
    mkdir -p "$dir/scripts"
    printf '#!/usr/bin/env bash\necho "PROJECT_SCRIPT_RAN $*"\n' > "$dir/scripts/build.sh"
    chmod +x "$dir/scripts/build.sh"
    printf 'build=./scripts/build.sh one two\n' | write_pfile "$sb" alpha
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build 2>&1)"
    assert_contains "script ran with its words" "PROJECT_SCRIPT_RAN one two" "$out"
}

test_none_values() {
    echo "TEST: build=none, test=none and install=none are recorded no-ops (exit 0)"
    local sb out rc
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    echo 'BUILD_CMD="false"' > "$sb/.agent/project_config.sh"
    printf 'build=none\ntest=none\ninstall=none\n' | write_pfile "$sb" alpha
    rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build 2>&1)" || rc=$?
    assert_eq "build=none exits 0" "0" "$rc"
    assert_contains "build=none says so" "nothing to build" "$out"
    rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha test 2>&1)" || rc=$?
    assert_eq "test=none exits 0" "0" "$rc"
    assert_contains "test=none says so" "no tests" "$out"
    rc=0; out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha install 2>&1)" || rc=$?
    assert_eq "install=none exits 0" "0" "$rc"
    assert_contains "install=none says so" "nothing to install" "$out"
}

test_shared_fallback_is_loud() {
    echo "TEST: a registered project falling through to the shared config gets a note; a legacy file does not"
    local sb dir stub out
    sb="$(make_sandbox)"
    dir="$(make_project "$sb" alpha)"
    stub="$(make_stub "$sb" sharedcmd)"
    echo "BUILD_CMD=\"$stub\"" > "$sb/.agent/project_config.sh"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build 2>&1)"
    assert_contains "shared command still runs" "STUB_sharedcmd_RAN_IN" "$out"
    assert_contains "note on stderr" "project 'alpha' has no build command of its own; using the shared .agent/project_config.sh" "$out"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build 2>/dev/null)"
    assert_not_contains "the note is on stderr, not stdout" "has no build command of its own" "$out"
    mkdir -p "$sb/.agent/projects.d"
    make_stub "$sb" legacycmd >/dev/null
    echo "BUILD_CMD=\"$sb/bin/legacycmd\"" > "$sb/.agent/projects.d/alpha.sh"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build 2>&1)"
    assert_contains "legacy file used" "STUB_legacycmd_RAN_IN" "$out"
    assert_not_contains "no note for the legacy file" "has no build command of its own" "$out"
    [ -n "$dir" ]
}

test_missing_test_command_names_the_setting() {
    echo "TEST: a registered project with no test command anywhere fails and names project_setting.sh"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    printf 'build=make\n' | write_pfile "$sb" alpha
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha test 2>&1)" || rc=$?
    assert_eq "exits 1" "1" "$rc"
    assert_contains "guidance" "project_setting.sh set alpha test=<command>" "$out"
}

test_malformed_file_stops_dispatcher() {
    echo "TEST: a malformed settings file stops every verb, naming file and line"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    printf 'build=make\nbogus=1\n' | write_pfile "$sb" alpha
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha env 2>&1)" || rc=$?
    assert_eq "env exits 1" "1" "$rc"
    assert_contains "names file and line" "$(pfile "$sb" alpha):2: unknown key 'bogus'" "$out"
    rc=0
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha env 2>/dev/null)" || rc=$?
    assert_eq "nothing on stdout for eval'ing callers" "" "$out"
}

test_validate_reports_malformed_file() {
    echo "TEST: make validate (validate_workspace.py) reports a malformed settings file through the adapter"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    printf 'tracking=repo\n' | write_pfile "$sb" alpha
    out="$(cd "$sb" && python3 "$sb/.agent/scripts/validate_workspace.py" 2>&1)" || rc=$?
    assert_eq "validate fails" "1" "$rc"
    assert_contains "names the project" "project 'alpha'" "$out"
    assert_contains "names the settings file" "$(pfile "$sb" alpha)" "$out"
}

test_dashboard_reports_settings_files() {
    echo "TEST: the dashboard fails an invalid settings file, warns a not-yet-honoured one and an orphan"
    local sb out
    sb="$(make_sandbox)"
    make_project "$sb" alpha >/dev/null
    make_project "$sb" beta >/dev/null
    printf 'bogus=1\n' | write_pfile "$sb" alpha
    printf 'location=project\ntracking=untracked\n' | write_pfile "$sb" beta
    printf 'build=make\n' | write_pfile "$sb" ghost
    out="$(cd "$sb" && PATH="$sb/nogh:$PATH" "$sb/.agent/scripts/dashboard.sh" --quick 2>&1 || true)"
    assert_contains "invalid file fails" "project 'alpha': settings file .agent/projects.d/alpha is invalid" "$out"
    assert_contains "not-yet-honoured warns" "project 'beta': records settings in .agent/projects.d/beta are valid but not yet honoured (#393)" "$out"
    assert_contains "orphan warns" "settings file .agent/projects.d/ghost belongs to no registered project" "$out"

    # A file name is compared as a fixed string: 'web.app' must not match
    # the registered 'webXapp' (as a regex '.' matches any character), and
    # a file name starting with '-' is a name, not a grep option.
    make_project "$sb" webXapp >/dev/null
    make_project "$sb" dot.name >/dev/null
    printf 'build=make\n' | write_pfile "$sb" web.app
    printf 'build=make\n' | write_pfile "$sb" dot.name
    printf 'build=make\n' | write_pfile "$sb" -x
    out="$(cd "$sb" && PATH="$sb/nogh:$PATH" "$sb/.agent/scripts/dashboard.sh" --quick 2>&1 || true)"
    assert_contains "'.' in a file name matches only itself" "settings file .agent/projects.d/web.app belongs to no registered project" "$out"
    assert_not_contains "a dotted registered name's own file is not an orphan" "projects.d/dot.name belongs to no registered project" "$out"
    assert_contains "a leading '-' is a name" "settings file .agent/projects.d/-x belongs to no registered project" "$out"
    assert_not_contains "grep never reads the name as an option" "Usage: grep" "$out"
}

test_bootstrap_url_precedence() {
    echo "TEST: ros2_colcon bootstrap URL: env, then bootstrap_url, then legacy MANIFEST_BOOTSTRAP_URL"
    local sb out
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/projects.d" "$sb/host"
    echo 'MANIFEST_BOOTSTRAP_URL="https://legacy.example/b.yaml"' > "$sb/.agent/projects.d/p.sh"
    run_url() {
        bash -c '
            WORKSPACE_ROOT="$1"; ACTIVE_PROJECT_NAME=p; ACTIVE_PROJECT_ROOT="$1/host"
            ACTIVE_PROJECT_CONFIG="$1/.agent/projects.d/p.sh"; ACTIVE_PROJECT_BOOTSTRAP_URL="$2"
            source "$1/.agent/project_types/ros2_colcon/adapter.sh"
            _rc_bootstrap_url' _ "$sb" "$1"
    }
    out="$(run_url "https://file.example/b.yaml")"
    assert_eq "settings-file key beats the legacy variable" "https://file.example/b.yaml" "$out"
    out="$(run_url "")"
    assert_eq "legacy variable when the key is absent" "https://legacy.example/b.yaml" "$out"
    out="$(BOOTSTRAP_URL="https://env.example/b.yaml" run_url "https://file.example/b.yaml")"
    assert_eq "environment override first" "https://env.example/b.yaml" "$out"
}

test_no_file_is_all_defaults
test_grammar_comments_blanks_crlf
test_grammar_errors
test_command_shell_syntax_refused
test_registry_refuses_dot_sh_name
test_absent_pair_resolves_to_default
test_default_outside_layout_comes_from_the_function
test_valid_combinations_on_acceptance_shape
test_refused_combinations
test_records_repo_workspace_by_remote_url
test_records_repo_workspace_by_local_path
test_records_repo_workspace_by_contents
test_records_dir_inside_workspace_repo
test_dispatcher_refuses_workspace_records_repo
test_set_get_list_idempotent
test_set_keeps_comments_and_order
test_composite_keys_refused
test_set_keeps_mode_and_symlink
test_set_refuses_unusable_path
test_symlink_cases
test_unknown_key_repair
test_set_refusals
test_set_refuses_non_default_records
test_worktree_copy_reads_main_and_refuses_writes
test_run_through_scripts_symlink
test_build_test_install_from_file
test_relative_script_path
test_none_values
test_shared_fallback_is_loud
test_missing_test_command_names_the_setting
test_malformed_file_stops_dispatcher
test_validate_reports_malformed_file
test_dashboard_reports_settings_files
test_bootstrap_url_precedence

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
