#!/usr/bin/env bash
# Tests for .agent/scripts/adapter, .agent/scripts/validate_adapter.sh, and
# the single_project adapter (.agent/project_types/single_project/).
#
# Tests run against a sandbox workspace (mktemp) with the real dispatcher,
# validator, and single_project type copied in, so type resolution from the
# registry and per-verb behavior are exercised without touching the real
# workspace. Each sandbox registers one project, demo, at <sandbox>/demo;
# run_in_ws runs from inside it (cwd discovery), run_in_root from the
# sandbox workspace root, where no project resolves (issue #265 part 4).
# Verb tests assert delegation observably (right implementation invoked,
# right cwd) — not just exit codes.
#
# Run: bash .agent/scripts/tests/test_adapter.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

PASS=0

# The adapter (and the build.sh/test.sh shims that exec it) carries the
# user-tier guard added in #317: it refuses when the cwd is neither inside
# its own workspace checkout nor under a registered project root. These
# fixtures drive a SANDBOX workspace, so every invocation runs from inside
# that sandbox -- which is what a real `make build` does too.
run_in_ws() {  # <sandbox> <command> [args...]: from inside the registered demo root
    local sb="$1"; shift
    (cd "$sb/demo" && "$@")
}
run_in_root() {  # <sandbox> <command> [args...]: from the sandbox workspace root
    local sb="$1"; shift
    (cd "$sb" && "$@")
}
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

# One sandbox for the whole run, created at top level (not inside $()) so
# the trap actually fires — see issue #297. Helpers carve per-test
# directories out of it with `mktemp -d -p "$SANDBOX"`, which needs no
# shared state and so survives being called as `sb="$(make_sandbox)"`.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# Create a sandbox workspace with the real dispatcher, validator, and
# single_project type. Echoes the sandbox path.
make_sandbox() {
    local sb
    sb="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$sb/.agent/scripts" "$sb/.agent/project_types"
    cp "$REAL_ROOT/.agent/scripts/adapter" "$sb/.agent/scripts/adapter"
    cp "$REAL_ROOT/.agent/scripts/_project_registry.sh" "$sb/.agent/scripts/_project_registry.sh"
    cp "$REAL_ROOT/.agent/scripts/validate_adapter.sh" "$sb/.agent/scripts/validate_adapter.sh"
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$sb/.agent/project_types/"
    mkdir -p "$sb/demo"
    echo "demo single_project $sb/demo" > "$sb/.agent/projects.local"
    echo "$sb"
}

# Append a key=value line to demo's settings file .agent/projects.d/demo,
# the only place its commands come from (issue #265 part 4).
set_demo_setting() {  # <sandbox> <key=value>
    mkdir -p "$1/.agent/projects.d"
    printf '%s\n' "$2" >> "$1/.agent/projects.d/demo"
}

# Set demo's registered type (the type comes from the registry line).
set_demo_type() {  # <sandbox> <type>
    echo "demo $2 $1/demo" > "$1/.agent/projects.local"
}

# Add a git repo at $1 with origin URL $2.
make_git_repo() {
    local dir="$1" url="$2"
    mkdir -p "$dir"
    git -C "$dir" init --quiet
    git -C "$dir" remote add origin "$url"
}

# Write a stub command that proves it ran and where. Echoes the stub path.
# Optional third arg: exit code for the stub (default 0).
make_stub() {
    local sb="$1" name="$2" rc="${3:-0}"
    mkdir -p "$sb/bin"
    cat > "$sb/bin/$name" <<'EOF'
#!/usr/bin/env bash
echo "STUB_${STUB_NAME}_RAN_IN:$(pwd -P) args:$*"
exit ${STUB_RC}
EOF
    sed -i'' -e "s/\${STUB_NAME}/$name/" -e "s/\${STUB_RC}/$rc/" "$sb/bin/$name"
    chmod +x "$sb/bin/$name"
    echo "$sb/bin/$name"
}

# ---- Dispatcher tests ----

test_default_project_type() {
    echo "TEST: a cwd under the registered root resolves it; its registry type is dispatched"
    local sb out
    sb="$(make_sandbox)"
    mkdir -p "$sb/demo/src/deep"
    out="$(cd "$sb/demo/src/deep" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "project_root is the registered root" "$sb/demo" "$out"
}

test_config_project_type_resolution() {
    echo "TEST: the registry line's type selects the type dir"
    local sb out
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/fake_type"
    cat > "$sb/.agent/project_types/fake_type/adapter.sh" <<'EOF'
adapter_setup() { :; }
adapter_sync() { :; }
adapter_validate() { :; }
adapter_build() { :; }
adapter_test() { :; }
adapter_install() { :; }
adapter_env() { :; }
adapter_project_root() { echo "FAKE_TYPE_ROOT"; }
adapter_repos() { :; }
adapter_scope_for_pr() { :; }
EOF
    set_demo_type "$sb" fake_type
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "fake_type adapter dispatched" "FAKE_TYPE_ROOT" "$out"
}

test_missing_adapter_dir() {
    echo "TEST: a registered type with no adapter fails with a clear error"
    local sb out rc=0
    sb="$(make_sandbox)"
    set_demo_type "$sb" no_such_type
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing type" "no adapter for project type 'no_such_type'" "$out"
}

test_missing_verb_function() {
    echo "TEST: adapter missing a verb function fails with a clear error"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/partial_type"
    echo 'adapter_env() { :; }' > "$sb/.agent/project_types/partial_type/adapter.sh"
    set_demo_type "$sb" partial_type
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names type and verb" "'partial_type' does not implement verb 'build'" "$out"
}

test_unknown_verb() {
    echo "TEST: unknown verb is rejected with usage"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" frobnicate 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "unknown verb named" "unknown verb 'frobnicate'" "$out"
    assert_contains "usage lists contract verbs" "scope_for_pr" "$out"
}

test_no_args_usage() {
    echo "TEST: no arguments prints usage and fails"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "usage line" "Usage: adapter" "$out"
}

test_from_flag_accepted() {
    echo "TEST: --from <dir> resolves like the cwd; a --from that is not a directory is refused"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(run_in_root "$sb" "$sb/.agent/scripts/adapter" --from "$sb/demo" project_root)" || true
    assert_eq "--from the registered root resolves it" "$sb/demo" "$out"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" --from /nonexistent project_root 2>&1)" || rc=$?
    assert_eq "a missing --from: exit 1" "1" "$rc"
    assert_contains "a missing --from: named" "--from '/nonexistent' is not a directory" "$out"
}

test_outside_worktrees_dir_resolves() {
    echo "TEST: a worktree in a root's worktrees= folder outside its hosting dir resolves that root (issue #265 part 4)"
    local sb out rc=0 stub wt
    sb="$(make_sandbox)"
    # worktrees= lies under the sandbox workspace root, not under demo/.
    echo "demo single_project $sb/demo worktrees=$sb/wt/demo" > "$sb/.agent/projects.local"
    wt="$sb/wt/demo/feature-issue-7"
    mkdir -p "$wt/sub"
    out="$(cd "$wt/sub" && "$sb/.agent/scripts/adapter" project_root 2>&1)" || rc=$?
    assert_eq "project_root from the worktree: exit 0" "0" "$rc"
    assert_eq "project_root from the worktree names demo's root" "$sb/demo" "$out"
    rc=0
    out="$(cd "$wt" && "$sb/.agent/scripts/adapter" env 2>&1)" || rc=$?
    assert_eq "env from the worktree: exit 0" "0" "$rc"
    stub="$(make_stub "$sb" wtbuild)"
    set_demo_setting "$sb" "build=$stub"
    rc=0
    out="$(cd "$wt" && "$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "build from the worktree: exit 0" "0" "$rc"
    assert_contains "build from the worktree runs demo's command" "STUB_wtbuild_RAN_IN" "$out"
    cp "$REAL_ROOT/.agent/scripts/sync_project.py" "$sb/.agent/scripts/sync_project.py"
    cat > "$sb/.agent/project_types/single_project/sync.py" <<'EOF'
import sys
print("SYNC_IMPL_CALLED args:" + " ".join(sys.argv[1:]))
EOF
    out="$(cd "$wt" && python3 "$sb/.agent/scripts/sync_project.py" --dry-run 2>&1)" || true
    assert_contains "sync from the worktree syncs demo, not the workspace alone" \
        "SYNC_IMPL_CALLED args:--project-root $sb/demo --dry-run" "$out"
}

# The first machine's shape, with synthetic names (issue #265 part 4): three
# non-parent projects registered, a project/ symlink to a git checkout in the
# workspace with a shared config whose build command would prove it ran, and
# a cwd in no registered root. Echoes the sandbox.
make_no_project_sandbox() {
    local sb stub
    sb="$(make_sandbox)"
    mkdir -p "$sb/docs" "$sb/.agent/scripts/lib"
    cp "$REAL_ROOT/.agent/scripts/lib/"*.py "$sb/.agent/scripts/lib/"
    git -C "$sb" init --quiet -b main
    for n in alpha beta gamma; do make_git_repo "$sb/roots/$n" "file:///nonexistent/$n.git"; done
    printf 'alpha single_project %s\nbeta single_project %s\ngamma single_project %s\n' \
        "$sb/roots/alpha" "$sb/roots/beta" "$sb/roots/gamma" > "$sb/.agent/projects.local"
    rmdir "$sb/demo"
    make_git_repo "$sb/legacy_checkout" "file:///nonexistent/legacy.git"
    ln -s "$sb/legacy_checkout" "$sb/project"
    stub="$(make_stub "$sb" legacybuild)"
    printf 'BUILD_CMD="%s"\nTEST_CMD="%s"\nINSTALL_CMD="%s"\n' "$stub" "$stub" "$stub" > "$sb/.agent/project_config.sh"
    echo "$sb"
}

test_no_project_refuses() {
    echo "TEST: with no project here, build/test/install refuse and list the registered names; project/ is not used (issue #265 part 4)"
    local sb out rc dir verb
    sb="$(make_no_project_sandbox)"
    for dir in "$sb" "$sb/docs"; do
        for verb in build test install project_root; do
            rc=0
            out="$(cd "$dir" && "$sb/.agent/scripts/adapter" "$verb" 2>&1)" || rc=$?
            assert_eq "$verb from ${dir#"$sb"}/: exit 1" "1" "$rc"
            assert_contains "$verb from ${dir#"$sb"}/: names the cwd, the registered names and the way out" \
                "ERROR: no registered project here (cwd $(cd "$dir" && pwd -P)). Registered: alpha, beta, gamma. Pass --project <name> or register one: .agent/scripts/register_project.sh <path>" "$out"
            assert_not_contains "$verb from ${dir#"$sb"}/: the project/ checkout is not used" "STUB_legacybuild_RAN_IN" "$out"
        done
    done
    : > "$sb/.agent/projects.local"
    rc=0
    out="$(run_in_root "$sb" "$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "nothing registered, project/ present: exit 1" "1" "$rc"
    assert_contains "nothing registered: says so and names the registration script" \
        "no registered project here (cwd $(cd "$sb" && pwd -P)), and none is registered. Register one: .agent/scripts/register_project.sh <path>" "$out"
    assert_not_contains "nothing registered: the project/ checkout is not used" "STUB_legacybuild_RAN_IN" "$out"
}

test_no_project_sync_is_workspace_only() {
    echo "TEST: sync with no project here syncs the workspace alone and says no project was synced"
    local sb out rc=0
    sb="$(make_no_project_sandbox)"
    out="$(run_in_root "$sb" "$sb/.agent/scripts/adapter" sync --dry-run 2>&1)" || rc=$?
    assert_eq "three registered: exit 0" "0" "$rc"
    assert_contains "the workspace is synced" "Checking agent_workspace (workspace)" "$out"
    assert_contains "no project synced; the registered names listed" \
        "No project was synced (none selected; registered: alpha, beta, gamma; pass PROJECT=<name>)" "$out"
    assert_not_contains "the project/ checkout is not synced" "legacy_checkout" "$out"
    : > "$sb/.agent/projects.local"
    rc=0
    out="$(run_in_root "$sb" "$sb/.agent/scripts/adapter" sync --dry-run 2>&1)" || rc=$?
    assert_eq "nothing registered: exit 0" "0" "$rc"
    assert_contains "nothing registered: the pointer" \
        "No project was synced (none registered; register one: .agent/scripts/register_project.sh <path>)" "$out"
}

test_project_flag_unknown_and_cwd_root() {
    echo "TEST: --project <unknown> names the registered projects; a cwd under a registered root resolves it"
    local sb out rc=0
    sb="$(make_no_project_sandbox)"
    out="$(run_in_root "$sb" "$sb/.agent/scripts/adapter" --project nosuch build 2>&1)" || rc=$?
    assert_eq "unknown: exit 1" "1" "$rc"
    assert_contains "unknown: named" "project 'nosuch' is not registered" "$out"
    assert_contains "unknown: lists the registered" "  beta" "$out"
    mkdir -p "$sb/roots/beta/sub"
    out="$(cd "$sb/roots/beta/sub" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "cwd under beta resolves beta" "$sb/roots/beta" "$out"
    : > "$sb/.agent/projects.local"
    rc=0
    out="$(run_in_root "$sb" "$sb/.agent/scripts/adapter" --project nosuch build 2>&1)" || rc=$?
    assert_contains "unknown, nothing registered: points at the registration script" \
        "(no projects registered — register one: .agent/scripts/register_project.sh <path>)" "$out"
    assert_not_contains "unknown, nothing registered: no example-file pointer" "projects.local.example" "$out"
}

# ---- Validator tests ----

test_validator_passes_complete_adapters() {
    echo "TEST: validator passes when all adapters are complete"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "reports single_project complete" "single_project: all 13 verbs implemented" "$out"
}

test_validator_flags_missing_verbs() {
    echo "TEST: validator lists missing verbs and exits nonzero"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/partial_type"
    printf 'adapter_env() { :; }\nadapter_build() { :; }\n' \
        > "$sb/.agent/project_types/partial_type/adapter.sh"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "flags partial_type" "partial_type: missing verbs" "$out"
    assert_contains "lists a missing verb" "adapter_scope_for_pr" "$out"
    assert_contains "complete type still passes" "single_project: all 13 verbs implemented" "$out"
}

test_validator_flags_missing_adapter_file() {
    echo "TEST: validator flags a type dir without adapter.sh"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/empty_type"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "flags empty_type" "empty_type: missing adapter.sh" "$out"
}

test_validator_checks_registration_refused() {
    echo "TEST: validator checks a type's registration_refused list like unused_settings: known keys, once each, with a reason (#569)"
    local sb out rc list k
    sb="$(make_sandbox)"
    # The sandbox holds single_project only; the grammar is the same for
    # every type, so ros2_colcon's shipped list is checked from there.
    list="$sb/.agent/project_types/single_project/registration_refused"
    cp "$REAL_ROOT/.agent/project_types/ros2_colcon/registration_refused" "$list"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "the shipped ros2_colcon list: exit 0" "0" "$rc"
    assert_not_contains "the shipped list: no complaint" "registration_refused is invalid" "$out"
    for k in source source_ref source_path; do
        assert_contains "the shipped list refuses $k" $'\n'"$k " $'\n'"$(cat "$list")"
    done
    printf 'source a reason\nsourc a typo\nsource again\nsource_ref\n' > "$list"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "a bad list: exit 1" "1" "$rc"
    assert_contains "a bad list: flagged" "single_project: registration_refused is invalid" "$out"
    assert_contains "unknown key named with its line" "line 2: unknown settings key 'sourc'" "$out"
    assert_contains "duplicate named" "line 3: 'source' is listed twice" "$out"
    assert_contains "missing reason named" "line 4: 'source_ref' has no reason" "$out"
}

test_validator_checks_unused_settings() {
    echo "TEST: validator checks a type's unused_settings list: known keys, once each, with a reason (#332)"
    local sb out rc list
    sb="$(make_sandbox)"
    list="$sb/.agent/project_types/single_project/unused_settings"
    printf '# comment\r\n\r\nbootstrap_url cloned by hand\r\n' > "$list"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "a valid list (CRLF, comments, blanks): exit 0" "0" "$rc"
    assert_not_contains "a valid list: no complaint" "unused_settings is invalid" "$out"

    printf 'bootstrap_url cloned by hand\nbuld a typo\nbootstrap_url again\ntest\n' > "$list"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "a bad list: exit 1" "1" "$rc"
    assert_contains "a bad list: flagged" "single_project: unused_settings is invalid" "$out"
    assert_contains "unknown key named with its line" "line 2: unknown settings key 'buld'" "$out"
    assert_contains "duplicate named" "line 3: 'bootstrap_url' is listed twice" "$out"
    assert_contains "missing reason named" "line 4: 'test' has no reason" "$out"

    if [ "$(id -u)" -ne 0 ]; then
        printf 'bootstrap_url cloned by hand\n' > "$list"
        chmod 000 "$list"
        rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
        chmod 644 "$list"
        assert_eq "an unreadable list: exit 1" "1" "$rc"
        assert_contains "an unreadable list: says why" "unused_settings exists but is not a readable file" "$out"
    else
        echo "  SKIP: unreadable-list case (running as root)"
    fi

    # The shipped list (source, source_ref, source_path: issue #436) is
    # valid: each a known key, once, with a reason.
    cp "$REAL_ROOT/.agent/project_types/single_project/unused_settings" "$list"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "the shipped single_project list: exit 0" "0" "$rc"
    local k
    for k in bootstrap_url source source_ref source_path; do
        assert_contains "the shipped list refuses $k" $'\n'"$k " $'\n'"$(cat "$list")"
    done
    printf 'source\nsource_ref cloned by hand\nsourc a typo\n' > "$list"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "source without a reason, a misspelt source key: exit 1" "1" "$rc"
    assert_contains "source without a reason named" "line 1: 'source' has no reason" "$out"
    assert_contains "misspelt source key named" "line 3: unknown settings key 'sourc'" "$out"

    rm -f "$list"
    rc=0; "$sb/.agent/scripts/validate_adapter.sh" >/dev/null 2>&1 || rc=$?
    assert_eq "no list at all: exit 0" "0" "$rc"
}

test_validator_checks_registration_conf() {
    echo "TEST: validator requires each type's registration.conf: every key once, valid values (#332)"
    local sb out rc conf
    sb="$(make_sandbox)"
    conf="$sb/.agent/project_types/single_project/registration.conf"
    printf '# comment\r\n\r\nrequired_commands=build test\r\nsetup=never\r\nrun=none\r\nmanifest=none\r\n' > "$conf"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "a valid file (CRLF, comments, blanks, run=none): exit 0" "0" "$rc"
    assert_not_contains "a valid file: no complaint" "registration.conf is missing or invalid" "$out"

    printf 'required_commands=build bootstrap\nsetup=sometimes\nsetup=never\nrun=\nextra=1\nmanifest=url\n' > "$conf"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "a bad file: exit 1" "1" "$rc"
    assert_contains "a bad file: flagged" "single_project: registration.conf is missing or invalid" "$out"
    assert_contains "unknown command named with its line" "line 1: required_commands: 'bootstrap' is not one of: build test install" "$out"
    assert_contains "bad setup value named" "line 2: setup must be 'never' or 'when-missing'" "$out"
    assert_contains "duplicate key named" "line 3: 'setup' is set twice" "$out"
    assert_contains "empty value named" "line 4: empty value for 'run'" "$out"
    assert_contains "unknown key named" "line 5: unknown key 'extra'" "$out"
    assert_contains "bad manifest value named" "line 6: manifest must be 'none' or 'local-file', got 'url'" "$out"

    printf 'required_commands=build\nsetup=never\n' > "$conf"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "a missing key: exit 1" "1" "$rc"
    assert_contains "a missing key named" "'run' is not set" "$out"
    assert_contains "a missing manifest key named" "'manifest' is not set" "$out"

    printf 'required_commands=none\nsetup=never\nrun=install\nmanifest=none\n' > "$conf"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "run=install (registration never runs install): exit 1" "1" "$rc"
    assert_contains "run=install named" "run: 'install' is not one of: build test" "$out"

    printf 'test the type never reads it\n' > "$sb/.agent/project_types/single_project/unused_settings"
    printf 'required_commands=build test\nsetup=never\nrun=build\nmanifest=none\n' > "$conf"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "a required command the type never reads: exit 1" "1" "$rc"
    assert_contains "the contradiction named" "'test' is required, but the type's unused_settings says it never reads it" "$out"

    rm -f "$conf"
    rc=0; out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "no registration.conf: exit 1" "1" "$rc"
    assert_contains "a missing file named" "registration.conf: missing" "$out"
}

test_validator_rejects_toplevel_exit() {
    echo "TEST: validator rejects an adapter that exits at top level (any status)"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/exiting_type"
    echo 'exit 0' > "$sb/.agent/project_types/exiting_type/adapter.sh"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "exit-0 adapter flagged, not passed" \
        "exiting_type: adapter.sh failed to source" "$out"

    rc=0
    echo 'exit 1' > "$sb/.agent/project_types/exiting_type/adapter.sh"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit-1 adapter: validator still exits 1" "1" "$rc"
    assert_contains "exit-1 adapter gets a diagnostic" \
        "exiting_type: adapter.sh failed to source" "$out"
}

test_validator_rejects_noisy_source() {
    echo "TEST: validator rejects an adapter that prints during source"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/noisy_type"
    {
        echo 'echo "loading noisy adapter..."'
        sed -n '/^adapter_setup/,$p' "$sb/.agent/project_types/single_project/adapter.sh"
    } > "$sb/.agent/project_types/noisy_type/adapter.sh"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "noisy source flagged" \
        "noisy_type: adapter.sh writes to stdout when sourced" "$out"
}

test_validator_empty_types_dir() {
    echo "TEST: validator reports empty project_types/ clearly"
    local sb out rc=0
    sb="$(make_sandbox)"
    rm -rf "$sb/.agent/project_types/single_project"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "clear no-types diagnostic, no literal glob" \
        "no project types found" "$out"
}

# ---- single_project verb tests ----

test_env_emits_nothing() {
    echo "TEST: single_project env emits nothing and exits 0"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" env)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "empty stdout" "" "$out"
}

test_build_requires_config() {
    echo "TEST: build with no build command anywhere fails with guidance"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "guidance message" "project 'demo' has no build command" "$out"
    assert_contains "names the setting command" "project_setting.sh set demo build=<command>" "$out"
}

test_build_requires_build_cmd() {
    echo "TEST: build with a test command but no build command fails with guidance"
    local sb out rc=0
    sb="$(make_sandbox)"
    set_demo_setting "$sb" "test=true"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing command" "project 'demo' has no build command" "$out"
}

test_build_runs_in_project_root() {
    echo "TEST: build runs the build setting in the project directory"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" fakebuild)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    set_demo_setting "$sb" "build=$stub"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build --flag1)" || true
    assert_contains "stub ran in project dir" "STUB_fakebuild_RAN_IN:$(cd "$sb/demo" && pwd -P)" "$out"
    assert_contains "args forwarded" "args:--flag1" "$out"
}

test_test_runs_in_project_root() {
    echo "TEST: test runs the test setting in the project directory"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" faketest)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    set_demo_setting "$sb" "test=$stub"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" test)" || true
    assert_contains "stub ran in project dir" "STUB_faketest_RAN_IN:$(cd "$sb/demo" && pwd -P)" "$out"
}

test_install_noop_when_unset() {
    echo "TEST: install no-ops when the settings file has no install key"
    local sb out rc=0
    sb="$(make_sandbox)"
    set_demo_setting "$sb" "build=true"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" install)" || rc=$?
    assert_eq "exit 0 with no install key" "0" "$rc"
    assert_contains "explains the no-op" "nothing to install" "$out"

    rc=0
    rm "$sb/.agent/projects.d/demo"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" install)" || rc=$?
    assert_eq "exit 0 with no settings file at all" "0" "$rc"
}

test_install_runs_when_set() {
    echo "TEST: install runs the install setting in the project directory"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" fakeinstall)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    set_demo_setting "$sb" "install=$stub"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" install)" || true
    assert_contains "stub ran in project dir" "STUB_fakeinstall_RAN_IN:$(cd "$sb/demo" && pwd -P)" "$out"
}

test_build_exit_code_propagation() {
    echo "TEST: build propagates the build command's exit code"
    local sb stub rc=0
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" failbuild 7)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    set_demo_setting "$sb" "build=$stub"
    run_in_ws "$sb" "$sb/.agent/scripts/adapter" build >/dev/null 2>&1 || rc=$?
    assert_eq "exit code 7 propagated" "7" "$rc"
}

test_build_aborts_on_failing_config() {
    echo "TEST: a retired project_config.sh is never sourced: a failing command in it does not stop the build (issue #265 part 4)"
    local sb out stub rc=0
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" settingsbuild)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    printf 'echo SHARED_CONFIG_SOURCED\nfalse\n' > "$sb/.agent/project_config.sh"
    set_demo_setting "$sb" "build=$stub"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "the settings command ran" "STUB_settingsbuild_RAN_IN" "$out"
    assert_not_contains "the shared config was not sourced" "SHARED_CONFIG_SOURCED" "$out"
}

test_retired_settings_note() {
    echo "TEST: a retired <name>.sh or shared project_config.sh that still sets something prints a NOTE naming each setting (issue #265 part 4)"
    local sb out stub rc
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" settingsbuild)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    set_demo_setting "$sb" "build=$stub"
    printf 'BUILD_CMD="make"\nTEST_CMD="make test"\n' > "$sb/.agent/project_config.sh"
    rc=0; out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "shared: the build still runs (exit 0)" "0" "$rc"
    assert_contains "shared: the NOTE names the file" "NOTE: project 'demo': .agent/project_config.sh is no longer read (issue #265 part 4), and it still sets:" "$out"
    assert_contains "shared: the missing key with its command" "sets TEST_CMD=\"make test\", which .agent/projects.d/demo lacks and nothing reads any more: .agent/scripts/project_setting.sh set demo test=<command> (or test=none)" "$out"
    assert_not_contains "shared: a key the settings file has is not named" "sets BUILD_CMD" "$out"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build 2>/dev/null)" || true
    assert_not_contains "the NOTE is on stderr only" "NOTE:" "$out"

    printf 'BUILD_CMD="make"\n' > "$sb/.agent/projects.d/demo.sh"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build 2>&1)" || true
    assert_contains "a <name>.sh with nothing left: the NOTE says delete it" "NOTE: project 'demo': .agent/projects.d/demo.sh is no longer read (issue #265 part 4) and holds nothing left to move: delete it" "$out"
    assert_not_contains "a <name>.sh replaces the shared file for its project (N3)" "project_config.sh" "$out"
    printf 'INSTALL_CMD="make install"\n' >> "$sb/.agent/projects.d/demo.sh"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build 2>&1)" || true
    assert_contains "a <name>.sh with a missing key: named" ".agent/projects.d/demo.sh sets INSTALL_CMD=\"make install\", which .agent/projects.d/demo lacks" "$out"

    rm -f "$sb/.agent/projects.d/demo.sh" "$sb/.agent/project_config.sh"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build 2>&1)" || true
    assert_not_contains "no retired file: no NOTE" "NOTE:" "$out"
}

test_retired_settings_not_run_for_machine_verbs() {
    echo "TEST: the machine-read verbs never source a retired file; the verbs a person runs still say what it holds (review suggestion)"
    local sb out verb marker
    sb="$(make_sandbox)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    set_demo_setting "$sb" "build=true"
    set_demo_setting "$sb" "test=true"
    marker="$sb/sourced.log"
    printf 'echo sourced >> "%s"\nINSTALL_CMD="make install"\n' "$marker" > "$sb/.agent/project_config.sh"
    for verb in project_root env repos; do
        rm -f "$marker"
        out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" "$verb" 2>&1)" || true
        assert_eq "$verb: the retired file is not run" "no" "$([ -e "$marker" ] && echo yes || echo no)"
        assert_not_contains "$verb: no NOTE" "NOTE:" "$out"
    done
    for verb in build test; do
        rm -f "$marker"
        out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" "$verb" 2>&1)" || true
        assert_contains "$verb: the NOTE names the retired setting" "sets INSTALL_CMD=\"make install\"" "$out"
    done
}

test_install_refuses_with_retired_install_command() {
    echo "TEST: install with no install setting refuses while a retired file still sets INSTALL_CMD (plan review N2)"
    local sb out stub rc
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" settingsinstall)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    set_demo_setting "$sb" "build=true"
    printf 'INSTALL_CMD="%s"\n' "$stub" > "$sb/.agent/project_config.sh"
    rc=0; out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" install 2>&1)" || rc=$?
    assert_eq "shared INSTALL_CMD, no install key: exit 1" "1" "$rc"
    assert_contains "says so and names the command" "ERROR: project 'demo' has no install setting, and the install command in .agent/project_config.sh is no longer run: set it with .agent/scripts/project_setting.sh set demo install=<command> (or install=none)" "$out"
    assert_not_contains "never 'nothing to install'" "nothing to install" "$out"
    assert_not_contains "the retired command does not run" "STUB_settingsinstall_RAN_IN" "$out"
    rm -f "$sb/.agent/project_config.sh"
    printf 'INSTALL_CMD="%s"\n' "$stub" > "$sb/.agent/projects.d/demo.sh"
    rc=0; out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" install 2>&1)" || rc=$?
    assert_eq "legacy .sh INSTALL_CMD: exit 1 too" "1" "$rc"
    assert_contains "names the .sh" "the install command in .agent/projects.d/demo.sh is no longer run" "$out"
    set_demo_setting "$sb" "install=$stub"
    rc=0; out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" install 2>&1)" || rc=$?
    assert_eq "with install set: exit 0" "0" "$rc"
    assert_contains "with install set: the settings command runs" "STUB_settingsinstall_RAN_IN" "$out"
    set_demo_setting "$sb" "test=true"
    printf 'build=true\ninstall=none\n' > "$sb/.agent/projects.d/demo"
    rc=0; out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" install 2>&1)" || rc=$?
    assert_eq "install=none: exit 0" "0" "$rc"
}

test_install_refuses_when_retired_file_unreadable() {
    echo "TEST: install with no install setting refuses when a retired file cannot be sourced: unknown is never 'nothing to install' (review M2)"
    local sb out stub rc
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" settingsinstall)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    set_demo_setting "$sb" "build=true"
    printf 'INSTALL_CMD="%s"\nfalse\n' "$stub" > "$sb/.agent/project_config.sh"
    rc=0; out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" install 2>&1)" || rc=$?
    assert_eq "shared file that cannot be sourced, no install key: exit 1" "1" "$rc"
    assert_contains "the NOTE says the file cannot be sourced" ".agent/project_config.sh cannot be sourced, so what is left in it for 'demo' is unknown" "$out"
    assert_contains "the NOTE heading says what it sets cannot be told (review round 2)" "NOTE: project 'demo': .agent/project_config.sh is no longer read (issue #265 part 4), and what it still sets cannot be told:" "$out"
    assert_not_contains "never 'and it still sets:' above a cannot-be-told line" "and it still sets:" "$out"
    assert_contains "the refusal says it cannot be told" "ERROR: project 'demo' has no install setting, and whether .agent/project_config.sh holds an install command that is no longer run cannot be told (above)" "$out"
    assert_not_contains "never 'nothing to install'" "nothing to install" "$out"
    assert_not_contains "the retired command does not run" "STUB_settingsinstall_RAN_IN" "$out"
    rm -f "$sb/.agent/project_config.sh"
    printf 'exit 3\n' > "$sb/.agent/projects.d/demo.sh"
    rc=0; out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" install 2>&1)" || rc=$?
    assert_eq "a <name>.sh that cannot be sourced: exit 1 too" "1" "$rc"
    assert_contains "names the .sh" "whether .agent/projects.d/demo.sh holds an install command that is no longer run cannot be told" "$out"
    set_demo_setting "$sb" "install=none"
    rc=0; out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" install 2>&1)" || rc=$?
    assert_eq "with install=none the settings file decides: exit 0" "0" "$rc"
}

test_project_type_env_not_inherited() {
    echo "TEST: exported PROJECT_TYPE in the environment is ignored (the registry names the type)"
    local sb out
    sb="$(make_sandbox)"
    out="$(PROJECT_TYPE=ghost_type run_in_ws "$sb" "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "the registry type wins over env" "$sb/demo" "$out"
}

test_no_new_env_vars_leaked() {
    echo "TEST: WORKSPACE_ROOT/ADAPTER_TYPE_DIR are not exported into the build command's env"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    set_demo_setting "$sb" "build=env"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" build)" || true
    assert_not_contains "WORKSPACE_ROOT absent" "WORKSPACE_ROOT=" "$out"
    assert_not_contains "ADAPTER_TYPE_DIR absent" "ADAPTER_TYPE_DIR=" "$out"
}

test_repos_format() {
    echo "TEST: repos prints name:path for the configured project"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" repos)" || true
    assert_eq "one name:path line" "demo:$sb/demo" "$out"
}

test_repos_resolves_symlink_name() {
    echo "TEST: repos uses the resolved directory name for a symlinked project"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/real_project_checkout" "git@github.com:owner/repo.git"
    rmdir "$sb/demo"
    ln -s "$sb/real_project_checkout" "$sb/demo"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" repos)" || true
    assert_eq "resolved name, unresolved path" \
        "real_project_checkout:$sb/demo" "$out"
}

test_repos_unconfigured() {
    echo "TEST: repos fails when the project is not checked out, and from the workspace with no project selected"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" repos 2>&1)" || rc=$?
    assert_eq "not checked out: exits nonzero" "1" "$rc"
    assert_contains "not checked out: says where" "project 'demo' is not checked out at $sb/demo" "$out"
    rc=0
    out="$(run_in_root "$sb" "$sb/.agent/scripts/adapter" repos 2>&1)" || rc=$?
    assert_eq "no project selected: exits nonzero" "1" "$rc"
    assert_contains "points at register_project.sh" "register one: .agent/scripts/register_project.sh <path>" "$out"
    assert_not_contains "no make setup pointer" "make setup" "$out"
}

test_scope_for_pr_ssh() {
    echo "TEST: scope_for_pr parses SSH origin URLs"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/repo_ssh" "git@github.com:owner1/repo1.git"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" scope_for_pr "$sb/repo_ssh")" || true
    assert_eq "owner/repo from SSH form" "owner1/repo1" "$out"
}

test_scope_for_pr_https() {
    echo "TEST: scope_for_pr parses HTTPS origin URLs"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/repo_https" "https://github.com/owner2/repo2.git"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" scope_for_pr "$sb/repo_https")" || true
    assert_eq "owner/repo from HTTPS form" "owner2/repo2" "$out"
}

test_scope_for_pr_walks_up() {
    echo "TEST: scope_for_pr resolves from a subdirectory of the repo"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/repo_walk" "git@github.com:owner3/repo3.git"
    mkdir -p "$sb/repo_walk/deep/sub/dir"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" scope_for_pr "$sb/repo_walk/deep/sub/dir")" || true
    assert_eq "walked up to repo root" "owner3/repo3" "$out"
    touch "$sb/repo_walk/deep/sub/dir/file.txt"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" scope_for_pr "$sb/repo_walk/deep/sub/dir/file.txt")" || true
    assert_eq "file path resolves via its parent dir" "owner3/repo3" "$out"
}

test_scope_for_pr_ssh_url_with_port() {
    echo "TEST: scope_for_pr parses ssh:// URLs with a port"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/repo_port" "ssh://git@github.com:22/owner4/repo4.git"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" scope_for_pr "$sb/repo_port")" || true
    assert_eq "port not captured into owner/repo" "owner4/repo4" "$out"
}

test_scope_for_pr_requires_path() {
    echo "TEST: scope_for_pr without a path argument fails"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" scope_for_pr 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "explains the requirement" "requires a path argument" "$out"
}

# ---- worktree_repos / worktree_env (ADR-0012, single_project) ----

test_worktree_repos_single_entry() {
    echo "TEST: single_project worktree_repos prints one entry, rel path '.'"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" worktree_repos --issue 42)" || true
    assert_eq "project dir, ., default branch" \
        "$sb/demo	.	feature/issue-42" "$out"
}

test_worktree_repos_accepts_qualified_issue() {
    echo "TEST: single_project worktree_repos accepts a qualified owner/repo#N issue"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" worktree_repos --issue owner/repo#42)" || true
    assert_eq "trailing number extracted for the branch" \
        "$sb/demo	.	feature/issue-42" "$out"
}

test_worktree_repos_rejects_layer_flags() {
    echo "TEST: single_project worktree_repos rejects --layer/--package-repos"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" worktree_repos --issue 42 --layer platforms 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "explains no layers to worktree" "does not support --layer" "$out"
}

test_worktree_repos_requires_issue() {
    echo "TEST: worktree_repos without --issue fails"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" worktree_repos 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "explains the requirement" "requires --issue" "$out"
}

# ---- repo_pin (ADR-0019, single_project) ----

# project/ as a committed repo on branch trunk whose origin is a local bare
# repo with HEAD at trunk. Leaves origin/HEAD unset locally.
make_pin_project() {  # <sb>
    local sb="$1"
    git init --quiet --bare -b trunk "$sb/origin.git"
    mkdir -p "$sb/demo"
    git -C "$sb/demo" init --quiet -b trunk
    git -C "$sb/demo" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
    git -C "$sb/demo" remote add origin "$sb/origin.git"
    git -C "$sb/demo" push --quiet origin trunk
    git -C "$sb/demo" fetch --quiet origin
}

test_repo_pin_from_origin_head() {
    echo "TEST: single_project repo_pin prints the default branch recorded as origin/HEAD"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_pin_project "$sb"
    git -C "$sb/demo" branch --quiet stable
    git -C "$sb/demo" push --quiet origin stable
    git -C "$sb/demo" fetch --quiet origin
    # Recorded locally as stable: the local record answers, not the remote.
    git -C "$sb/demo" remote set-head origin stable >/dev/null
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" repo_pin demo 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "origin/HEAD's branch, kind branch" "stable	branch" "$out"
}

test_repo_pin_asks_origin_without_origin_head() {
    echo "TEST: single_project repo_pin asks origin for HEAD when origin/HEAD is not recorded"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_pin_project "$sb"
    git -C "$sb/demo" remote set-head origin --delete >/dev/null 2>&1 || true
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" repo_pin demo 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "origin's HEAD, kind branch" "trunk	branch" "$out"
}

test_repo_pin_undetermined_fails() {
    echo "TEST: single_project repo_pin fails when neither origin/HEAD nor origin answers"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_pin_project "$sb"
    git -C "$sb/demo" remote set-head origin --delete >/dev/null 2>&1 || true
    git -C "$sb/demo" remote set-url origin "$sb/no-such-origin.git"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" repo_pin demo 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "says why" "cannot determine the default branch" "$out"
    assert_contains "origin unreachable: says origin could not be asked" \
        "origin could not be asked (git ls-remote exited" "$out"
    assert_not_contains "origin unreachable: not 'did not name its HEAD'" "did not name its HEAD" "$out"
    assert_not_contains "no guessed main" "main	branch" "$out"
    # Origin answers but its HEAD names no branch it has: that wording.
    git -C "$sb/demo" remote set-url origin "$sb/origin.git"
    git --git-dir="$sb/origin.git" symbolic-ref HEAD refs/heads/nothere
    rc=0
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" repo_pin demo 2>&1)" || rc=$?
    assert_eq "origin names no HEAD: exits 1" "1" "$rc"
    assert_contains "origin names no HEAD: says so" "origin did not name its HEAD" "$out"
}

test_repo_pin_hanging_origin_is_bounded() {
    echo "TEST: single_project repo_pin bounds its origin query and names the timeout"
    if ! command -v timeout >/dev/null 2>&1; then
        echo "  SKIP: no timeout command"
        return 0
    fi
    local sb out rc=0 shim pidfile started elapsed reached=no
    sb="$(make_sandbox)"
    make_pin_project "$sb"
    git -C "$sb/demo" remote set-head origin --delete >/dev/null 2>&1 || true
    # An ssh origin whose "ssh" blocks, as a passphrase or host-key prompt
    # or a stalled host would. Only WT_FETCH_TIMEOUT can end it; the
    # ceiling below is far above the 2s limit and far below the block.
    shim="$sb/hang-ssh"
    pidfile="$sb/hang-ssh.pid"
    printf '#!/usr/bin/env bash\necho $$ > "%s"\nexec sleep 300\n' "$pidfile" > "$shim"
    chmod +x "$shim"
    git -C "$sb/demo" remote set-url origin "ssh://git@example.invalid/project.git"
    started=$SECONDS
    out="$(GIT_SSH_COMMAND="$shim" WT_FETCH_TIMEOUT=2 \
        run_in_ws "$sb" "$sb/.agent/scripts/adapter" repo_pin demo 2>&1)" || rc=$?
    elapsed=$((SECONDS - started))
    if [ -s "$pidfile" ]; then
        reached=yes
        kill "$(< "$pidfile")" 2>/dev/null || true
    fi
    assert_eq "the hanging ssh was reached" "yes" "$reached"
    assert_eq "exits 1" "1" "$rc"
    assert_contains "names the timeout" "origin did not answer within 2s" "$out"
    assert_eq "ended by WT_FETCH_TIMEOUT, not by the block (${elapsed}s < 60s)" "yes" \
        "$([ "$elapsed" -lt 60 ] && echo yes || echo no)"
}

test_repo_pin_other_name_fails() {
    echo "TEST: single_project repo_pin refuses a name other than the one repos prints"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_pin_project "$sb"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" repo_pin other_repo 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the known repo" "no repository 'other_repo' in this project (known: demo)" "$out"
}

test_repo_pin_rejects_layer_and_requires_name() {
    echo "TEST: single_project repo_pin rejects --layer and needs a name"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_pin_project "$sb"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" repo_pin demo --layer l1 2>&1)" || rc=$?
    assert_eq "--layer exits nonzero" "1" "$rc"
    assert_contains "no layers" "does not support --layer" "$out"
    rc=0
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" repo_pin 2>&1)" || rc=$?
    assert_eq "no name exits nonzero" "1" "$rc"
    assert_contains "names the usage" "repo_pin requires a repository name" "$out"
}

test_validator_flags_missing_repo_pin() {
    echo "TEST: validator flags a type that implements every verb but repo_pin"
    local sb out rc=0 v
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/no_pin_type"
    cp "$sb/.agent/project_types/single_project/unused_settings" \
        "$sb/.agent/project_types/single_project/registration.conf" \
        "$sb/.agent/project_types/no_pin_type/"
    for v in setup sync validate build test install env project_root repos scope_for_pr worktree_repos worktree_env; do
        echo "adapter_${v}() { :; }"
    done > "$sb/.agent/project_types/no_pin_type/adapter.sh"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "flags no_pin_type" "no_pin_type: missing verbs" "$out"
    assert_contains "names repo_pin" "adapter_repo_pin" "$out"
    assert_not_contains "no other verb missing" "adapter_worktree_env" "$out"
}

test_worktree_env_emits_nothing() {
    echo "TEST: single_project worktree_env emits nothing and exits 0"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" worktree_env --worktree "$sb/anything")" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "empty stdout" "" "$out"
}

# ---- setup.sh / sync.py robustness tests (issue #222) ----

# Build an origin repo and a clone at $2 primed for a rebase conflict:
# origin's default branch gains a commit the clone doesn't have, and the
# clone gains a local commit touching the same line. The clone ends up on
# 'main', clean, so setup/sync will attempt `git pull --rebase` and fail
# mid-rebase.
make_conflicted_clone() {
    local sb="$1" clone="$2"
    local origin="$sb/origin_repo"
    mkdir -p "$origin"
    git -C "$origin" init --quiet -b main
    echo "base" > "$origin/f.txt"
    git -C "$origin" add f.txt
    git -C "$origin" -c user.name=t -c user.email=t@t commit -m base --quiet
    git clone --quiet "$origin" "$clone" 2>/dev/null
    git -C "$clone" config user.name t
    git -C "$clone" config user.email t@t
    echo "upstream" > "$origin/f.txt"
    git -C "$origin" -c user.name=t -c user.email=t@t commit -am upstream --quiet
    echo "local" > "$clone/f.txt"
    git -C "$clone" commit -am local --quiet
}

# Echo "clean" if no rebase is in progress in repo $1, else "mid-rebase".
rebase_state() {
    local repo="$1"
    if [ -d "$repo/.git/rebase-merge" ] || [ -d "$repo/.git/rebase-apply" ]; then
        echo "mid-rebase"
    else
        echo "clean"
    fi
}

test_setup_aborts_failed_rebase() {
    echo "TEST: setup aborts an in-progress rebase after a failed pull"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_conflicted_clone "$sb" "$sb/demo"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" setup 2>&1)" || rc=$?
    assert_eq "setup still exits 0" "0" "$rc"
    assert_contains "reports the pull failure" "Pull failed" "$out"
    assert_eq "repo left clean, not mid-rebase" "clean" "$(rebase_state "$sb/demo")"
}

test_setup_requires_project_root() {
    echo "TEST: setup.sh without --project-root refuses; it never makes a project/ (issue #265 part 4)"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_git_repo "$sb/real_checkout" "git@github.com:owner/repo.git"
    out="$(echo "$sb/real_checkout" | run_in_root "$sb" "$sb/.agent/project_types/single_project/setup.sh" 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "says what setup is for" "setup brings up a registered project" "$out"
    assert_contains "names the registration script" "Register one first: .agent/scripts/register_project.sh <path>" "$out"
    assert_eq "no project/ made" "no" "$([ -e "$sb/project" ] || [ -L "$sb/project" ] && echo yes || echo no)"
}

test_setup_refuses_non_checkout() {
    echo "TEST: setup of a registered root that is not a git checkout refuses; nothing is cloned, linked or deleted"
    local sb out rc=0
    sb="$(make_sandbox)"
    echo "precious" > "$sb/demo/data.txt"
    make_git_repo "$sb/real_checkout" "git@github.com:owner/repo.git"
    out="$(echo "$sb/real_checkout" | run_in_ws "$sb" "$sb/.agent/scripts/adapter" setup 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names the root" "$sb/demo is not a git checkout; nothing was changed." "$out"
    assert_contains "says why, true to today's code" "a single_project needs a git repository today (adapter validate checks it). If its line in .agent/projects.local names the wrong folder, fix the line." "$out"
    assert_not_contains "never tells a registered folder to clone (git is meant to be optional; review suggestion)" "Clone" "$out"
    assert_eq "existing file untouched" "precious" "$(< "$sb/demo/data.txt")"
    assert_eq "no symlink made" "no" "$([ -L "$sb/demo" ] && echo yes || echo no)"
    rm -r "$sb/demo"
    rc=0
    out="$(run_in_root "$sb" "$sb/.agent/project_types/single_project/setup.sh" --project-root "$sb/demo" 2>&1)" || rc=$?
    assert_eq "a registered root that does not exist: exit 1" "1" "$rc"
    assert_contains "says it does not exist" "$sb/demo does not exist; nothing was changed." "$out"
    assert_not_contains "a missing root: no 'Clone' either" "Clone" "$out"
    assert_eq "nothing created" "no" "$([ -e "$sb/demo" ] && echo yes || echo no)"
}

test_sync_aborts_failed_rebase() {
    echo "TEST: sync.py aborts an in-progress rebase after a failed pull"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/scripts/lib"
    cp "$REAL_ROOT/.agent/scripts/lib/"*.py "$sb/.agent/scripts/lib/"
    make_conflicted_clone "$sb" "$sb/demo"
    out="$(python3 "$sb/.agent/project_types/single_project/sync.py" --project-root "$sb/demo" 2>&1)" || rc=$?
    assert_eq "sync exits 0" "0" "$rc"
    assert_contains "reports the pull failure" "Update failed" "$out"
    assert_eq "repo left clean, not mid-rebase" "clean" "$(rebase_state "$sb/demo")"
}

# ---- Delegation / shim-chain tests ----

test_setup_delegates() {
    echo "TEST: setup delegates to the type's setup.sh"
    local sb out
    sb="$(make_sandbox)"
    cat > "$sb/.agent/project_types/single_project/setup.sh" <<'EOF'
#!/usr/bin/env bash
echo "SETUP_IMPL_CALLED args:$*"
EOF
    chmod +x "$sb/.agent/project_types/single_project/setup.sh"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/adapter" setup --answer 42)" || true
    assert_contains "implementation invoked with the root and the args" \
        "SETUP_IMPL_CALLED args:--project-root $sb/demo --answer 42" "$out"
}

test_sync_shim_chain() {
    echo "TEST: sync_project.py shim → adapter → type's sync.py"
    local sb out
    sb="$(make_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/sync_project.py" "$sb/.agent/scripts/sync_project.py"
    chmod +x "$sb/.agent/scripts/sync_project.py"
    cat > "$sb/.agent/project_types/single_project/sync.py" <<'EOF'
import sys
print("SYNC_IMPL_CALLED args:" + " ".join(sys.argv[1:]))
EOF
    out="$(run_in_ws "$sb" python3 "$sb/.agent/scripts/sync_project.py" --dry-run)" || true
    assert_contains "full chain reached the implementation" "SYNC_IMPL_CALLED args:--project-root $sb/demo --dry-run" "$out"
    out="$(run_in_root "$sb" python3 "$sb/.agent/scripts/sync_project.py" --dry-run)" || true
    assert_contains "with no project here, the workspace-only sync" "SYNC_IMPL_CALLED args:--dry-run" "$out"
}

test_build_shim_chain() {
    echo "TEST: build.sh shim dispatches through the adapter"
    local sb out stub
    sb="$(make_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/build.sh" "$sb/.agent/scripts/build.sh"
    chmod +x "$sb/.agent/scripts/build.sh"
    stub="$(make_stub "$sb" shimbuild)"
    make_git_repo "$sb/demo" "git@github.com:owner/repo.git"
    set_demo_setting "$sb" "build=$stub"
    out="$(run_in_ws "$sb" "$sb/.agent/scripts/build.sh")" || true
    assert_contains "stub reached via shim in project dir" \
        "STUB_shimbuild_RAN_IN:$(cd "$sb/demo" && pwd -P)" "$out"
}

test_sync_real_implementation_runs() {
    echo "TEST: the real moved sync.py imports its lib and runs (--dry-run)"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/scripts/lib"
    cp "$REAL_ROOT/.agent/scripts/lib/"*.py "$sb/.agent/scripts/lib/"
    out="$(python3 "$sb/.agent/project_types/single_project/sync.py" --dry-run 2>&1)" || rc=$?
    assert_eq "exits 0" "0" "$rc"
    assert_contains "lib import worked and sync ran" "Checking agent_workspace (workspace)" "$out"
}

# Real chain (sync_project.py -> adapter -> sync.py) in a sandbox
# workspace that is a git checkout, with no project/ (issue #295).
make_sync_sandbox() {
    local sb
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/scripts/lib"
    cp "$REAL_ROOT/.agent/scripts/lib/"*.py "$sb/.agent/scripts/lib/"
    cp "$REAL_ROOT/.agent/scripts/sync_project.py" "$sb/.agent/scripts/sync_project.py"
    chmod +x "$sb/.agent/scripts/sync_project.py"
    git -C "$sb" init --quiet -b main
    rm -f "$sb/.agent/projects.local"
    rmdir "$sb/demo"
    echo "$sb"
}

test_sync_nothing_registered() {
    echo "TEST: sync with no project/ and no registry syncs the workspace and says no project was synced"
    local sb out rc=0
    sb="$(make_sync_sandbox)"
    out="$(run_in_root "$sb" python3 "$sb/.agent/scripts/sync_project.py" --dry-run 2>&1)" || rc=$?
    assert_eq "exits 0" "0" "$rc"
    assert_contains "workspace synced" "Checking agent_workspace (workspace)" "$out"
    assert_contains "no project synced, pointer named" \
        "No project was synced (none registered; register one: .agent/scripts/register_project.sh <path>)" "$out"
    assert_not_contains "no make setup pointer" "Run: make setup" "$out"
    assert_contains "completes" "Sync complete." "$out"
}

test_sync_registered_none_selected() {
    echo "TEST: sync with a registered project, none selected and no project/ names the registered ones"
    local sb out rc=0
    sb="$(make_sync_sandbox)"
    make_git_repo "$sb/elsewhere/demo" "file:///nonexistent/demo.git"
    echo "demo single_project $sb/elsewhere/demo" > "$sb/.agent/projects.local"
    out="$(run_in_root "$sb" python3 "$sb/.agent/scripts/sync_project.py" --dry-run 2>&1)" || rc=$?
    assert_eq "exits 0" "0" "$rc"
    assert_contains "names the registered project" \
        "No project was synced (none selected; registered: demo; pass PROJECT=<name>)" "$out"
    assert_not_contains "does not say none registered" "none registered" "$out"
}

# ---- Run all tests ----
echo "=== adapter / validate_adapter / single_project tests ==="
echo ""

test_default_project_type
test_config_project_type_resolution
test_missing_adapter_dir
test_missing_verb_function
test_unknown_verb
test_no_args_usage
test_from_flag_accepted
test_outside_worktrees_dir_resolves
test_no_project_refuses
test_no_project_sync_is_workspace_only
test_project_flag_unknown_and_cwd_root
test_project_type_env_not_inherited
test_validator_passes_complete_adapters
test_validator_flags_missing_verbs
test_validator_flags_missing_adapter_file
test_validator_checks_unused_settings
test_validator_checks_registration_refused
test_validator_checks_registration_conf
test_validator_rejects_toplevel_exit
test_validator_rejects_noisy_source
test_validator_empty_types_dir
test_env_emits_nothing
test_build_requires_config
test_build_requires_build_cmd
test_build_runs_in_project_root
test_build_exit_code_propagation
test_build_aborts_on_failing_config
test_retired_settings_note
test_retired_settings_not_run_for_machine_verbs
test_install_refuses_with_retired_install_command
test_install_refuses_when_retired_file_unreadable
test_no_new_env_vars_leaked
test_test_runs_in_project_root
test_install_noop_when_unset
test_install_runs_when_set
test_repos_format
test_repos_resolves_symlink_name
test_repos_unconfigured
test_scope_for_pr_ssh
test_scope_for_pr_https
test_scope_for_pr_ssh_url_with_port
test_scope_for_pr_walks_up
test_scope_for_pr_requires_path
test_worktree_repos_single_entry
test_worktree_repos_accepts_qualified_issue
test_worktree_repos_rejects_layer_flags
test_worktree_repos_requires_issue
test_worktree_env_emits_nothing
test_repo_pin_from_origin_head
test_repo_pin_asks_origin_without_origin_head
test_repo_pin_undetermined_fails
test_repo_pin_hanging_origin_is_bounded
test_repo_pin_other_name_fails
test_repo_pin_rejects_layer_and_requires_name
test_validator_flags_missing_repo_pin
test_setup_aborts_failed_rebase
test_setup_requires_project_root
test_setup_refuses_non_checkout
test_sync_aborts_failed_rebase
test_setup_delegates
test_sync_shim_chain
test_sync_real_implementation_runs
test_sync_nothing_registered
test_sync_registered_none_selected
test_build_shim_chain

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
