#!/usr/bin/env bash
# Tests for .agent/scripts/adapter, .agent/scripts/validate_adapter.sh, and
# the single_project adapter (.agent/project_types/single_project/).
#
# Tests run against a sandbox workspace (mktemp) with the real dispatcher,
# validator, and single_project type copied in, so PROJECT_TYPE resolution
# and per-verb behavior are exercised without touching the real workspace.
# Verb tests assert delegation observably (right implementation invoked,
# right cwd) — not just exit codes.
#
# Run: bash .agent/scripts/tests/test_adapter.sh

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

SANDBOXES=()
cleanup() {
    local sb
    for sb in ${SANDBOXES[@]+"${SANDBOXES[@]}"}; do
        rm -rf "$sb"
    done
}
trap cleanup EXIT

# Create a sandbox workspace with the real dispatcher, validator, and
# single_project type. Echoes the sandbox path.
make_sandbox() {
    local sb
    sb="$(mktemp -d)"
    SANDBOXES+=("$sb")
    mkdir -p "$sb/.agent/scripts" "$sb/.agent/project_types"
    cp "$REAL_ROOT/.agent/scripts/adapter" "$sb/.agent/scripts/adapter"
    cp "$REAL_ROOT/.agent/scripts/validate_adapter.sh" "$sb/.agent/scripts/validate_adapter.sh"
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$sb/.agent/project_types/"
    echo "$sb"
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
    echo "TEST: PROJECT_TYPE defaults to single_project without config"
    local sb out
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "project_root resolves via default type" "$sb/project" "$out"
}

test_config_project_type_resolution() {
    echo "TEST: PROJECT_TYPE from project_config.sh selects the type dir"
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
    echo 'PROJECT_TYPE=fake_type' > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "fake_type adapter dispatched" "FAKE_TYPE_ROOT" "$out"
}

test_missing_adapter_dir() {
    echo "TEST: unknown PROJECT_TYPE fails with a clear error"
    local sb out rc=0
    sb="$(make_sandbox)"
    echo 'PROJECT_TYPE=no_such_type' > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing type" "no adapter for project type 'no_such_type'" "$out"
}

test_missing_verb_function() {
    echo "TEST: adapter missing a verb function fails with a clear error"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/partial_type"
    echo 'adapter_env() { :; }' > "$sb/.agent/project_types/partial_type/adapter.sh"
    echo 'PROJECT_TYPE=partial_type' > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names type and verb" "'partial_type' does not implement verb 'build'" "$out"
}

test_unknown_verb() {
    echo "TEST: unknown verb is rejected with usage"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/adapter" frobnicate 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "unknown verb named" "unknown verb 'frobnicate'" "$out"
    assert_contains "usage lists contract verbs" "scope_for_pr" "$out"
}

test_no_args_usage() {
    echo "TEST: no arguments prints usage and fails"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/adapter" 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "usage line" "Usage: adapter" "$out"
}

test_from_flag_accepted() {
    echo "TEST: --from <dir> is accepted (reserved for step 2)"
    local sb out
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/adapter" --from /nonexistent project_root)" || true
    assert_eq "still resolves from workspace root" "$sb/project" "$out"
}

# ---- Validator tests ----

test_validator_passes_complete_adapters() {
    echo "TEST: validator passes when all adapters are complete"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/validate_adapter.sh" 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "reports single_project complete" "single_project: all 10 verbs implemented" "$out"
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
    assert_contains "complete type still passes" "single_project: all 10 verbs implemented" "$out"
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
    out="$("$sb/.agent/scripts/adapter" env)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "empty stdout" "" "$out"
}

test_build_requires_config() {
    echo "TEST: build without project_config.sh fails with guidance"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "guidance message" "No project_config.sh found" "$out"
}

test_build_requires_build_cmd() {
    echo "TEST: build with config but no BUILD_CMD fails with guidance"
    local sb out rc=0
    sb="$(make_sandbox)"
    echo 'TEST_CMD="true"' > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the missing var" "BUILD_CMD is not set" "$out"
}

test_build_runs_in_project_root() {
    echo "TEST: build runs BUILD_CMD in the project directory"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" fakebuild)"
    make_git_repo "$sb/project" "git@github.com:owner/repo.git"
    echo "BUILD_CMD=\"$stub\"" > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" build --flag1)" || true
    assert_contains "stub ran in project dir" "STUB_fakebuild_RAN_IN:$(cd "$sb/project" && pwd -P)" "$out"
    assert_contains "args forwarded" "args:--flag1" "$out"
}

test_test_runs_in_project_root() {
    echo "TEST: test runs TEST_CMD in the project directory"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" faketest)"
    make_git_repo "$sb/project" "git@github.com:owner/repo.git"
    echo "TEST_CMD=\"$stub\"" > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" test)" || true
    assert_contains "stub ran in project dir" "STUB_faketest_RAN_IN:$(cd "$sb/project" && pwd -P)" "$out"
}

test_install_noop_when_unset() {
    echo "TEST: install no-ops when INSTALL_CMD is empty or unset"
    local sb out rc=0
    sb="$(make_sandbox)"
    echo 'INSTALL_CMD=""' > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" install)" || rc=$?
    assert_eq "exit 0 with empty INSTALL_CMD" "0" "$rc"
    assert_contains "explains the no-op" "nothing to install" "$out"

    rc=0
    rm "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" install)" || rc=$?
    assert_eq "exit 0 with no config at all" "0" "$rc"
}

test_install_runs_when_set() {
    echo "TEST: install runs INSTALL_CMD in the project directory"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" fakeinstall)"
    make_git_repo "$sb/project" "git@github.com:owner/repo.git"
    echo "INSTALL_CMD=\"$stub\"" > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" install)" || true
    assert_contains "stub ran in project dir" "STUB_fakeinstall_RAN_IN:$(cd "$sb/project" && pwd -P)" "$out"
}

test_build_exit_code_propagation() {
    echo "TEST: build propagates BUILD_CMD's exit code"
    local sb stub rc=0
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" failbuild 7)"
    make_git_repo "$sb/project" "git@github.com:owner/repo.git"
    echo "BUILD_CMD=\"$stub\"" > "$sb/.agent/project_config.sh"
    "$sb/.agent/scripts/adapter" build >/dev/null 2>&1 || rc=$?
    assert_eq "exit code 7 propagated" "7" "$rc"
}

test_build_aborts_on_failing_config() {
    echo "TEST: a failing command inside project_config.sh aborts the build"
    local sb out stub rc=0
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" neverbuild)"
    make_git_repo "$sb/project" "git@github.com:owner/repo.git"
    printf 'BUILD_CMD="%s"\nfalse\n' "$stub" > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" build 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_not_contains "BUILD_CMD was never run" "STUB_neverbuild_RAN_IN" "$out"
}

test_project_type_env_not_inherited() {
    echo "TEST: exported PROJECT_TYPE in the environment is ignored"
    local sb out
    sb="$(make_sandbox)"
    out="$(PROJECT_TYPE=ghost_type "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "config-less default wins over env" "$sb/project" "$out"
}

test_no_new_env_vars_leaked() {
    echo "TEST: WORKSPACE_ROOT/ADAPTER_TYPE_DIR are not exported into BUILD_CMD's env"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/project" "git@github.com:owner/repo.git"
    echo 'BUILD_CMD="env"' > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/adapter" build)" || true
    assert_not_contains "WORKSPACE_ROOT absent" "WORKSPACE_ROOT=" "$out"
    assert_not_contains "ADAPTER_TYPE_DIR absent" "ADAPTER_TYPE_DIR=" "$out"
}

test_repos_format() {
    echo "TEST: repos prints name:path for the configured project"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/project" "git@github.com:owner/repo.git"
    out="$("$sb/.agent/scripts/adapter" repos)" || true
    assert_eq "one name:path line" "project:$sb/project" "$out"
}

test_repos_resolves_symlink_name() {
    echo "TEST: repos uses the resolved directory name for a symlinked project"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/real_project_checkout" "git@github.com:owner/repo.git"
    ln -s "$sb/real_project_checkout" "$sb/project"
    out="$("$sb/.agent/scripts/adapter" repos)" || true
    assert_eq "resolved name, unresolved path" \
        "real_project_checkout:$sb/project" "$out"
}

test_repos_unconfigured() {
    echo "TEST: repos fails when project/ is not configured"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/adapter" repos 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "points at make setup" "run: make setup" "$out"
}

test_scope_for_pr_ssh() {
    echo "TEST: scope_for_pr parses SSH origin URLs"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/repo_ssh" "git@github.com:owner1/repo1.git"
    out="$("$sb/.agent/scripts/adapter" scope_for_pr "$sb/repo_ssh")" || true
    assert_eq "owner/repo from SSH form" "owner1/repo1" "$out"
}

test_scope_for_pr_https() {
    echo "TEST: scope_for_pr parses HTTPS origin URLs"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/repo_https" "https://github.com/owner2/repo2.git"
    out="$("$sb/.agent/scripts/adapter" scope_for_pr "$sb/repo_https")" || true
    assert_eq "owner/repo from HTTPS form" "owner2/repo2" "$out"
}

test_scope_for_pr_walks_up() {
    echo "TEST: scope_for_pr resolves from a subdirectory of the repo"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/repo_walk" "git@github.com:owner3/repo3.git"
    mkdir -p "$sb/repo_walk/deep/sub/dir"
    out="$("$sb/.agent/scripts/adapter" scope_for_pr "$sb/repo_walk/deep/sub/dir")" || true
    assert_eq "walked up to repo root" "owner3/repo3" "$out"
}

test_scope_for_pr_ssh_url_with_port() {
    echo "TEST: scope_for_pr parses ssh:// URLs with a port"
    local sb out
    sb="$(make_sandbox)"
    make_git_repo "$sb/repo_port" "ssh://git@github.com:22/owner4/repo4.git"
    out="$("$sb/.agent/scripts/adapter" scope_for_pr "$sb/repo_port")" || true
    assert_eq "port not captured into owner/repo" "owner4/repo4" "$out"
}

test_scope_for_pr_requires_path() {
    echo "TEST: scope_for_pr without a path argument fails"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$("$sb/.agent/scripts/adapter" scope_for_pr 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "explains the requirement" "requires a path argument" "$out"
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
    make_conflicted_clone "$sb" "$sb/project"
    out="$("$sb/.agent/scripts/adapter" setup 2>&1)" || rc=$?
    assert_eq "setup still exits 0" "0" "$rc"
    assert_contains "reports the pull failure" "Pull failed" "$out"
    assert_eq "repo left clean, not mid-rebase" "clean" "$(rebase_state "$sb/project")"
}

test_setup_replaces_broken_symlink() {
    echo "TEST: setup removes a broken symlink at project/ before symlinking"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_git_repo "$sb/real_checkout" "git@github.com:owner/repo.git"
    ln -s "$sb/nonexistent_target" "$sb/project"
    out="$(echo "$sb/real_checkout" | "$sb/.agent/scripts/adapter" setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "symlink created" "Symlinked: project" "$out"
    assert_eq "project/ now points at the checkout" \
        "$(cd "$sb/real_checkout" && pwd -P)" "$(readlink "$sb/project")"
}

test_setup_replaces_valid_symlink_to_nonrepo() {
    echo "TEST: setup removes a valid symlink to a non-repo dir before symlinking"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir "$sb/not_a_repo"
    ln -s "$sb/not_a_repo" "$sb/project"
    make_git_repo "$sb/real_checkout" "git@github.com:owner/repo.git"
    out="$(echo "$sb/real_checkout" | "$sb/.agent/scripts/adapter" setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "project/ now points at the checkout" \
        "$(cd "$sb/real_checkout" && pwd -P)" "$(readlink "$sb/project")"
}

test_setup_removes_empty_placeholder_dir() {
    echo "TEST: setup still removes an empty placeholder directory (regression)"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir "$sb/project"
    make_git_repo "$sb/real_checkout" "git@github.com:owner/repo.git"
    out="$(echo "$sb/real_checkout" | "$sb/.agent/scripts/adapter" setup 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "project/ now points at the checkout" \
        "$(cd "$sb/real_checkout" && pwd -P)" "$(readlink "$sb/project")"
}

test_setup_preserves_nonempty_dir() {
    echo "TEST: setup does NOT delete a non-empty project/ directory"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir "$sb/project"
    echo "precious" > "$sb/project/data.txt"
    make_git_repo "$sb/real_checkout" "git@github.com:owner/repo.git"
    out="$(echo "$sb/real_checkout" | "$sb/.agent/scripts/adapter" setup 2>&1)" || rc=$?
    assert_eq "setup fails" "1" "$rc"
    assert_eq "existing file untouched" "precious" "$(< "$sb/project/data.txt")"
}

test_sync_aborts_failed_rebase() {
    echo "TEST: sync.py aborts an in-progress rebase after a failed pull"
    local sb out rc=0
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/scripts/lib"
    cp "$REAL_ROOT/.agent/scripts/lib/"*.py "$sb/.agent/scripts/lib/"
    make_conflicted_clone "$sb" "$sb/project"
    out="$(python3 "$sb/.agent/project_types/single_project/sync.py" 2>&1)" || rc=$?
    assert_eq "sync exits 0" "0" "$rc"
    assert_contains "reports the pull failure" "Update failed" "$out"
    assert_eq "repo left clean, not mid-rebase" "clean" "$(rebase_state "$sb/project")"
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
    out="$("$sb/.agent/scripts/adapter" setup --answer 42)" || true
    assert_contains "implementation invoked with args" "SETUP_IMPL_CALLED args:--answer 42" "$out"
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
    out="$(python3 "$sb/.agent/scripts/sync_project.py" --dry-run)" || true
    assert_contains "full chain reached the implementation" "SYNC_IMPL_CALLED args:--dry-run" "$out"
}

test_build_shim_chain() {
    echo "TEST: build.sh shim dispatches through the adapter"
    local sb out stub
    sb="$(make_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/build.sh" "$sb/.agent/scripts/build.sh"
    chmod +x "$sb/.agent/scripts/build.sh"
    stub="$(make_stub "$sb" shimbuild)"
    make_git_repo "$sb/project" "git@github.com:owner/repo.git"
    echo "BUILD_CMD=\"$stub\"" > "$sb/.agent/project_config.sh"
    out="$("$sb/.agent/scripts/build.sh")" || true
    assert_contains "stub reached via shim in project dir" \
        "STUB_shimbuild_RAN_IN:$(cd "$sb/project" && pwd -P)" "$out"
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
test_project_type_env_not_inherited
test_validator_passes_complete_adapters
test_validator_flags_missing_verbs
test_validator_flags_missing_adapter_file
test_validator_rejects_toplevel_exit
test_validator_rejects_noisy_source
test_validator_empty_types_dir
test_env_emits_nothing
test_build_requires_config
test_build_requires_build_cmd
test_build_runs_in_project_root
test_build_exit_code_propagation
test_build_aborts_on_failing_config
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
test_setup_aborts_failed_rebase
test_setup_replaces_broken_symlink
test_setup_replaces_valid_symlink_to_nonrepo
test_setup_removes_empty_placeholder_dir
test_setup_preserves_nonempty_dir
test_sync_aborts_failed_rebase
test_setup_delegates
test_sync_shim_chain
test_sync_real_implementation_runs
test_build_shim_chain

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
