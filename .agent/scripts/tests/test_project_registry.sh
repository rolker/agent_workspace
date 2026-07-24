#!/usr/bin/env bash
# Tests for the per-machine project registry (issue #227 — #172 step 2):
# .agent/scripts/_project_registry.sh parsing, adapter dispatcher resolution
# (--project, cwd discovery, legacy fallback), per-project command config,
# validate_workspace.py both-shapes support, sync.py --project-root, and
# worktree_create.sh --repo wiring.
#
# Tests run against sandbox workspaces (mktemp) with the real scripts copied
# in, so no test touches the real workspace, its registry, or the network
# (a failing `gh` stub shadows the real CLI for worktree tests).
#
# Run: bash .agent/scripts/tests/test_project_registry.sh

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

# ---- Sandbox helpers ----

SANDBOXES=()
cleanup() {
    local sb
    for sb in ${SANDBOXES[@]+"${SANDBOXES[@]}"}; do
        rm -rf "$sb"
    done
}
trap cleanup EXIT

make_sandbox() {
    local sb
    sb="$(mktemp -d)"
    SANDBOXES+=("$sb")
    mkdir -p "$sb/.agent/scripts/lib" "$sb/.agent/project_types"
    cp "$REAL_ROOT/.agent/scripts/adapter" "$sb/.agent/scripts/adapter"
    cp "$REAL_ROOT/.agent/scripts/_project_registry.sh" "$sb/.agent/scripts/_project_registry.sh"
    cp "$REAL_ROOT/.agent/scripts/validate_adapter.sh" "$sb/.agent/scripts/validate_adapter.sh"
    cp "$REAL_ROOT/.agent/scripts/lib/"*.py "$sb/.agent/scripts/lib/"
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$sb/.agent/project_types/"
    echo "$sb"
}

make_git_repo() {
    local dir="$1" url="$2"
    mkdir -p "$dir"
    git -C "$dir" init --quiet
    git -C "$dir" remote add origin "$url"
}

# Write a stub command that proves it ran and where. Echoes the stub path.
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

# Register a project: make_registered_project <sb> <name> [<path>]
# Creates a git checkout at the hosting dir and appends a registry line.
# The origin URL is a local file:// path that fails fast, so fetch attempts
# (worktree_create's remote-branch probe) never touch the network.
make_registered_project() {
    local sb="$1" name="$2" path="${3:-}"
    local dir="${path:-$sb/projects/$name}"
    make_git_repo "$dir" "file:///nonexistent/${name}.git"
    if [ -n "$path" ]; then
        echo "$name single_project $path" >> "$sb/.agent/projects.local"
    else
        echo "$name single_project" >> "$sb/.agent/projects.local"
    fi
    echo "$dir"
}

# ---- Registry parsing tests ----

test_registry_absent_is_legacy() {
    echo "TEST: no registry → legacy project_root (from a cwd outside projects/)"
    local sb out
    sb="$(make_sandbox)"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "legacy root" "$sb/project" "$out"
}

test_registry_malformed_line_fails() {
    echo "TEST: malformed registry line fails loud"
    local sb out rc=0
    sb="$(make_sandbox)"
    echo "bad name with spaces single_project" > "$sb/.agent/projects.local"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project bad project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the malformed line" "projects.local:1" "$out"
}

test_registry_rejects_dotdot_name() {
    echo "TEST: registry name containing '..' is rejected"
    local sb out rc=0
    sb="$(make_sandbox)"
    echo "a..b single_project" > "$sb/.agent/projects.local"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project a..b project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "flags the name" "invalid project name 'a..b'" "$out"
}

test_registry_comments_and_blanks() {
    echo "TEST: comments and blank lines are ignored"
    local sb out
    sb="$(make_sandbox)"
    {
        echo "# a comment"
        echo ""
        echo "alpha single_project   # trailing comment"
    } > "$sb/.agent/projects.local"
    make_git_repo "$sb/projects/alpha" "git@github.com:owner/alpha.git"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha project_root)" || true
    assert_eq "entry parsed despite comments" "$sb/projects/alpha" "$out"
}

# ---- Dispatcher resolution tests ----

test_project_flag_resolves() {
    echo "TEST: --project <name> resolves root and type from the registry"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha project_root)" || true
    assert_eq "default hosting dir" "$sb/projects/alpha" "$out"
}

test_project_flag_after_verb() {
    echo "TEST: --project is accepted after the verb (shim forwarding)"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" project_root --project alpha)" || true
    assert_eq "same resolution" "$sb/projects/alpha" "$out"
}

test_project_flag_unknown() {
    echo "TEST: --project with an unregistered name fails and lists projects"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project nope project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the unknown project" "'nope' is not registered" "$out"
    assert_contains "lists registered projects" "alpha" "$out"
}

test_registry_type_resolution() {
    echo "TEST: registry project type selects the adapter (not workspace config)"
    local sb out
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/other_type"
    cat > "$sb/.agent/project_types/other_type/adapter.sh" <<'EOF'
adapter_setup() { :; }
adapter_sync() { :; }
adapter_validate() { :; }
adapter_build() { :; }
adapter_test() { :; }
adapter_install() { :; }
adapter_env() { :; }
adapter_project_root() { echo "OTHER_TYPE_ROOT"; }
adapter_repos() { :; }
adapter_scope_for_pr() { :; }
EOF
    echo "beta other_type" > "$sb/.agent/projects.local"
    mkdir -p "$sb/projects/beta"
    # Workspace config says single_project; the registry entry must win.
    echo 'PROJECT_TYPE=single_project' > "$sb/.agent/project_config.sh"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project beta project_root)" || true
    assert_eq "registry type dispatched" "OTHER_TYPE_ROOT" "$out"
}

test_cwd_discovery() {
    echo "TEST: cwd inside a hosting dir resolves that project"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    mkdir -p "$sb/projects/alpha/src/deep"
    out="$(cd "$sb/projects/alpha/src/deep" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "resolved from cwd" "$sb/projects/alpha" "$out"
}

test_from_flag_discovery() {
    echo "TEST: --from <dir> resolves like cwd discovery"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    mkdir -p "$sb/projects/alpha/src"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --from "$sb/projects/alpha/src" project_root)" || true
    assert_eq "resolved from --from dir" "$sb/projects/alpha" "$out"
}

test_custom_path_entry() {
    echo "TEST: registry path field overrides the default hosting dir"
    local sb out custom
    sb="$(make_sandbox)"
    custom="$sb/elsewhere/alpha_checkout"
    make_registered_project "$sb" alpha "$custom" >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha project_root)" || true
    assert_eq "custom path used" "$custom" "$out"
    out="$(cd "$custom" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "cwd discovery works on custom path" "$custom" "$out"
}

test_unregistered_under_projects_fails() {
    echo "TEST: cwd under projects/ without a matching entry fails loud"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    mkdir -p "$sb/projects/orphan"
    out="$(cd "$sb/projects/orphan" && "$sb/.agent/scripts/adapter" project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "explains the problem" "no registered project owns it" "$out"
}

test_legacy_unaffected_by_registry() {
    echo "TEST: registry present + cwd outside projects/ still resolves legacy"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "legacy root wins outside projects/" "$sb/project" "$out"
}

# ---- Per-project command config tests ----

test_build_uses_projects_d_config() {
    echo "TEST: build --project uses .agent/projects.d/<name>.sh in the project root"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" alphabuild)"
    make_registered_project "$sb" alpha >/dev/null
    mkdir -p "$sb/.agent/projects.d"
    echo "BUILD_CMD=\"$stub\"" > "$sb/.agent/projects.d/alpha.sh"
    # Workspace config would run something else — must not be used.
    echo 'BUILD_CMD="false"' > "$sb/.agent/project_config.sh"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build)" || true
    assert_contains "per-project stub ran in project root" \
        "STUB_alphabuild_RAN_IN:$(cd "$sb/projects/alpha" && pwd -P)" "$out"
}

test_build_falls_back_to_workspace_config() {
    echo "TEST: build --project falls back to project_config.sh without projects.d file"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" sharedbuild)"
    make_registered_project "$sb" alpha >/dev/null
    echo "BUILD_CMD=\"$stub\"" > "$sb/.agent/project_config.sh"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build)" || true
    assert_contains "shared stub ran in project root" \
        "STUB_sharedbuild_RAN_IN:$(cd "$sb/projects/alpha" && pwd -P)" "$out"
}

# ---- sync.py --project-root ----

test_sync_project_root() {
    echo "TEST: adapter --project sync targets the registry checkout (--dry-run)"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha sync --dry-run 2>&1)" || rc=$?
    assert_eq "sync exits 0" "0" "$rc"
    assert_contains "project checkout targeted" "project (alpha)" "$out"
}

# ---- validate_workspace.py tests ----

run_validate() {
    local sb="$1"
    python3 "$sb/.agent/scripts/validate_workspace.py" 2>&1
}

make_validate_sandbox() {
    local sb
    sb="$(make_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/validate_workspace.py" "$sb/.agent/scripts/"
    echo "$sb"
}

test_validate_registry_only() {
    echo "TEST: validate passes on a registry-only machine (no legacy project/)"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "passes" "PASSED" "$out"
}

test_validate_missing_checkout() {
    echo "TEST: validate flags a registered project without a checkout"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    echo "ghost single_project" > "$sb/.agent/projects.local"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names the project" "project 'ghost'" "$out"
}

test_validate_unknown_type() {
    echo "TEST: validate flags a registry entry with an unknown project type"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_git_repo "$sb/projects/alpha" "git@github.com:owner/alpha.git"
    echo "alpha no_such_type" > "$sb/.agent/projects.local"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names the type" "unknown project type 'no_such_type'" "$out"
}

test_validate_malformed_registry() {
    echo "TEST: validate flags malformed registry lines"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_git_repo "$sb/project" "git@github.com:owner/legacy.git"
    echo "alpha single_project extra junk" > "$sb/.agent/projects.local"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "reports the parse error" "too many fields" "$out"
}

test_validate_legacy_still_works() {
    echo "TEST: validate on a legacy-only machine behaves as before"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_git_repo "$sb/project" "git@github.com:owner/legacy.git"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "passes" "PASSED" "$out"
}

test_validate_neither_shape() {
    echo "TEST: validate still fails when neither shape is configured"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "legacy guidance kept" "project/ directory does not exist" "$out"
}

# ---- worktree_create.sh --repo wiring ----

# Worktree sandboxes get the worktree scripts, their helpers, and a failing
# gh stub so issue lookups degrade gracefully offline.
make_worktree_sandbox() {
    local sb
    sb="$(make_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_create.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_enter.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_worktree_helpers.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_issue_helpers.sh" "$sb/.agent/scripts/"
    mkdir -p "$sb/stubbin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/gh"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"
    chmod +x "$sb/stubbin/gh" "$sb/stubbin/git-bug"
    # The sandbox root itself must be a git repo (workspace repo stand-in).
    git -C "$sb" init --quiet
    echo "$sb"
}

# Seed a commit so worktree add has a HEAD to branch from.
seed_commit() {
    local dir="$1"
    (cd "$dir" \
        && git -c user.name=t -c user.email=t@t commit --allow-empty -m init --quiet)
}

test_worktree_create_unknown_repo() {
    echo "TEST: worktree_create --repo with unregistered name fails and lists projects"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 999 --type project --repo nope 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the unknown project" "'nope' is not registered" "$out"
    assert_contains "lists registered projects" "alpha" "$out"
}

test_worktree_create_registry_repo() {
    echo "TEST: worktree_create --repo <name> creates the worktree from the registry checkout"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 999 --type project --repo alpha 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "worktree exists under the registry name" \
        "yes" "$([ -d "$sb/worktrees/project/alpha/issue-alpha-999" ] && echo yes || echo no)"
    assert_eq "worktree is a checkout of the alpha repo" \
        "feature/issue-999" \
        "$(git -C "$sb/worktrees/project/alpha/issue-alpha-999" branch --show-current 2>/dev/null)"
}

test_worktree_create_single_registry_autoselect() {
    echo "TEST: worktree_create without --repo auto-selects the single registered project"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 998 --type project 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "announces the auto-selection" "Using registered project 'alpha'" "$out"
    assert_eq "worktree created" \
        "yes" "$([ -d "$sb/worktrees/project/alpha/issue-alpha-998" ] && echo yes || echo no)"
}

test_worktree_create_dashed_name_roundtrip() {
    echo "TEST: dashed registry name survives create → enter --repo round-trip"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" my-proj >/dev/null
    seed_commit "$sb/projects/my-proj"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 996 --type project --repo my-proj 2>&1)" || rc=$?
    assert_eq "create exit 0" "0" "$rc"
    assert_eq "worktree dir uses the raw name" \
        "yes" "$([ -d "$sb/worktrees/project/my-proj/issue-my-proj-996" ] && echo yes || echo no)"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_enter.sh" --issue 996 --type project --repo my-proj --print-path 2>&1)" || rc=$?
    assert_eq "enter --repo finds it" "0" "$rc"
    assert_eq "enter resolves the same path" \
        "$sb/worktrees/project/my-proj/issue-my-proj-996" "$out"
}

test_worktree_create_multiple_requires_repo() {
    echo "TEST: worktree_create without --repo fails when multiple projects are registered"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    make_registered_project "$sb" beta >/dev/null
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --issue 997 --type project 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "asks for --repo" "Use --repo to specify" "$out"
    assert_contains "lists alpha" "--repo alpha" "$out"
    assert_contains "lists beta" "--repo beta" "$out"
}

# ---- Run all tests ----
echo "=== project registry / multi-tenant hosting tests ==="
echo ""

test_registry_absent_is_legacy
test_registry_malformed_line_fails
test_registry_rejects_dotdot_name
test_registry_comments_and_blanks
test_project_flag_resolves
test_project_flag_after_verb
test_project_flag_unknown
test_registry_type_resolution
test_cwd_discovery
test_from_flag_discovery
test_custom_path_entry
test_unregistered_under_projects_fails
test_legacy_unaffected_by_registry
test_build_uses_projects_d_config
test_build_falls_back_to_workspace_config
test_sync_project_root
test_validate_registry_only
test_validate_missing_checkout
test_validate_unknown_type
test_validate_malformed_registry
test_validate_legacy_still_works
test_validate_neither_shape
test_worktree_create_unknown_repo
test_worktree_create_registry_repo
test_worktree_create_single_registry_autoselect
test_worktree_create_dashed_name_roundtrip
test_worktree_create_multiple_requires_repo

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
