#!/usr/bin/env bash
# Tests for the per-machine project registry (issue #227 — #172 step 2):
# .agent/scripts/_project_registry.sh parsing, adapter dispatcher resolution
# (--project, cwd discovery, legacy fallback), per-project command config,
# validate_workspace.py both-shapes support, sync.py --project-root, and
# worktree_create.sh --project wiring.
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

make_sandbox() {
    local sb
    sb="$(mktemp -d -p "$SANDBOX")"
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
    # `-b main`: a new worktree branch starts from the repo's default
    # branch (#323), which resolve_default_branch finds as `main` here
    # (no origin/HEAD, and the origin URLs are fake).
    git -C "$dir" init --quiet -b main
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
    # A registry entry always names its path (issue #265 part 4); the
    # default here is a root registered inside the workspace tree, which
    # ADR-0016 decision 1 allows.
    echo "$name single_project ${path:-projects/$name}" >> "$sb/.agent/projects.local"
    echo "$dir"
}

# ---- Registry parsing tests ----

test_registry_absent_is_legacy() {
    echo "TEST: no registry → project_root refuses, a project/ checkout is not used (issue #265 part 4)"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_git_repo "$sb/project" "git@github.com:owner/legacy.git"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" project_root 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_not_contains "never the project/ root" "$sb/project" "$out"
    assert_contains "says none is registered" "no registered project here (cwd $(cd "$sb" && pwd -P)), and none is registered" "$out"
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
        echo "alpha single_project projects/alpha   # trailing comment"
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
    echo "beta other_type projects/beta" > "$sb/.agent/projects.local"
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
    assert_contains "explains the problem" "no registered project here (cwd $(cd "$sb/projects/orphan" && pwd -P)). Registered: alpha." "$out"
}

test_legacy_unaffected_by_registry() {
    echo "TEST: registry present + cwd outside every root refuses, listing the registered names (issue #265 part 4)"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    make_git_repo "$sb/project" "git@github.com:owner/legacy.git"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" project_root 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "lists the registered project and --project" "Registered: alpha. Pass --project <name>" "$out"
    assert_not_contains "never the project/ root" "$sb/project" "$out"
}

# ---- Per-project command config tests ----

test_build_uses_projects_d_config() {
    echo "TEST: build --project runs the settings file's build in the project root; a legacy <name>.sh and the shared config are not read"
    local sb out stub
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" alphabuild)"
    make_registered_project "$sb" alpha >/dev/null
    mkdir -p "$sb/.agent/projects.d"
    printf 'build=%s\n' "$stub" > "$sb/.agent/projects.d/alpha"
    # The retired files would run something else: never read.
    echo 'BUILD_CMD="false"' > "$sb/.agent/projects.d/alpha.sh"
    echo 'BUILD_CMD="false"' > "$sb/.agent/project_config.sh"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build)" || true
    assert_contains "settings-file stub ran in project root" \
        "STUB_alphabuild_RAN_IN:$(cd "$sb/projects/alpha" && pwd -P)" "$out"
}

test_build_falls_back_to_workspace_config() {
    echo "TEST: build --project with no build setting does not fall back to project_config.sh (issue #265 part 4)"
    local sb out stub rc=0
    sb="$(make_sandbox)"
    stub="$(make_stub "$sb" sharedbuild)"
    make_registered_project "$sb" alpha >/dev/null
    echo "BUILD_CMD=\"$stub\"" > "$sb/.agent/project_config.sh"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha build)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_not_contains "the shared stub does not run" "STUB_sharedbuild_RAN_IN" "$out"
    assert_contains "says there is no build command" "project 'alpha' has no build command" "$out"
}

test_project_command_source_file_only() {
    echo "TEST: project_command_source reports the settings file or missing, never a retired config (issue #265 part 4)"
    local sb out rc
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    mkdir -p "$sb/.agent/projects.d"
    printf 'build=make all\ntest=none\n' > "$sb/.agent/projects.d/alpha"
    echo 'INSTALL_CMD="legacy-install"' > "$sb/.agent/projects.d/alpha.sh"
    echo 'INSTALL_CMD="shared-install"' > "$sb/.agent/project_config.sh"
    assert_eq "a command from the file" "$(printf 'file\tmake all')" "$(reg "$sb" project_command_source "$sb" alpha build)"
    assert_eq "'none' from the file" "$(printf 'file\tnone')" "$(reg "$sb" project_command_source "$sb" alpha test)"
    assert_eq "unset in the file: missing, whatever the retired files say" "$(printf 'missing\t')" "$(reg "$sb" project_command_source "$sb" alpha install)"
    rc=0; out="$(reg "$sb" project_command_source "$sb" alpha bootstrap_url 2>&1)" || rc=$?
    assert_eq "not a command setting: rc 2" "2" "$rc"
    assert_contains "not a command setting: says so" "is not a command setting" "$out"
}

# ---- registry_repo_slugs (issue #295) ----

test_registry_repo_slugs() {
    echo "TEST: registry_repo_slugs prints each registered root's github.com origin slug"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_git_repo "$sb/projects/alpha" "git@github.com:owner/alpha.git"
    make_git_repo "$sb/projects/beta" "https://github.com/owner/beta"
    make_git_repo "$sb/projects/gamma" "file:///nonexistent/gamma.git"
    mkdir -p "$sb/projects/grp" "$sb/projects/nogit"
    make_git_repo "$sb/projects/grp/one" "https://github.com/owner/one.git"
    cat > "$sb/.agent/projects.local" <<EOF
alpha single_project projects/alpha
beta single_project projects/beta
gamma single_project projects/gamma
nogit single_project projects/nogit
grp project $sb/projects/grp
grp-one single_project $sb/projects/grp/one parent=grp
EOF
    out="$(bash -c 'source "$1/.agent/scripts/_project_registry.sh"; registry_repo_slugs "$1"' _ "$sb")" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "slugs (ssh and https, .git stripped; non-GitHub, non-git and parent skipped)" \
        "owner/alpha
owner/beta
owner/one" "$out"
}

test_registry_repo_slugs_no_walk_up() {
    echo "TEST: registry_repo_slugs skips a root that is a plain directory inside another repository"
    local sb out rc=0
    sb="$(make_sandbox)"
    # The workspace sandbox is itself a repository with a GitHub origin, as a
    # real workspace checkout is; a registered root under it that is not a
    # checkout of its own must not borrow that origin.
    make_git_repo "$sb" "https://github.com/owner/workspace.git"
    make_git_repo "$sb/projects/alpha" "git@github.com:owner/alpha.git"
    mkdir -p "$sb/projects/plain" "$sb/projects/plainsub/inner"
    cat > "$sb/.agent/projects.local" <<EOF
alpha single_project projects/alpha
plain single_project projects/plain
plainsub single_project $sb/projects/plainsub/inner
EOF
    out="$(bash -c 'source "$1/.agent/scripts/_project_registry.sh"; registry_repo_slugs "$1"' _ "$sb")" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "only the root that is its own checkout prints a slug" "owner/alpha" "$out"
    assert_not_contains "the enclosing repository's slug is not accepted" "owner/workspace" "$out"
}

test_registry_repo_slugs_absent_or_broken() {
    echo "TEST: registry_repo_slugs prints nothing and returns 0 with no registry or a parse error"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(bash -c 'set -euo pipefail; source "$1/.agent/scripts/_project_registry.sh"; registry_repo_slugs "$1"; echo END' _ "$sb" 2>&1)" || rc=$?
    assert_eq "no registry: exit 0" "0" "$rc"
    assert_eq "no registry: nothing printed" "END" "$out"
    make_git_repo "$sb/projects/alpha" "git@github.com:owner/alpha.git"
    printf 'alpha single_project projects/alpha\nbad name with spaces=\n' > "$sb/.agent/projects.local"
    rc=0
    out="$(bash -c 'set -euo pipefail; source "$1/.agent/scripts/_project_registry.sh"; registry_repo_slugs "$1"; echo END' _ "$sb" 2>&1)" || rc=$?
    assert_eq "parse error: exit 0 under set -e" "0" "$rc"
    assert_eq "parse error: nothing printed" "END" "$out"
}

# ---- main-checkout helpers (issue #295) ----

# Physical path of a directory, or the string as given when it is not one.
phys() {
    [ -n "$1" ] || { echo "<nothing>"; return 0; }
    (cd "$1" 2>/dev/null && pwd -P) || printf '%s\n' "$1"
}

# Both helpers, run for a checkout <dir>: the shell one is given <dir>, the
# Python one finds its root from the copy of lib/workspace.py under <dir>.
# Prints "<shell answer> | <python answer>", both physical paths.
main_checkout_both() {
    local dir="$1" sh_out py_out
    mkdir -p "$dir/.agent/scripts/lib"
    cp "$REAL_ROOT/.agent/scripts/_project_registry.sh" "$dir/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/lib/workspace.py" "$dir/.agent/scripts/lib/"
    sh_out="$(bash -c 'set -euo pipefail; source "$1/.agent/scripts/_project_registry.sh"; registry_main_checkout "$1"' _ "$dir")"
    py_out="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import workspace; print(workspace.get_main_checkout_root())' "$dir/.agent/scripts/lib")"
    printf '%s | %s\n' "$(phys "$sh_out")" "$(phys "$py_out")"
}

test_main_checkout_helpers() {
    echo "TEST: registry_main_checkout and get_main_checkout_root agree on the main checkout"
    local base expect
    base="$(phys "$(mktemp -d -p "$SANDBOX")")"

    # A plain directory nested in a repository that has a registry: the
    # directory itself, never the enclosing repository.
    make_git_repo "$base/outer" "https://github.com/owner/outer.git"
    mkdir -p "$base/outer/.agent" "$base/outer/inner"
    echo "x single_project inner" > "$base/outer/.agent/projects.local"
    expect="$base/outer/inner | $base/outer/inner"
    assert_eq "nested plain directory: itself" "$expect" "$(main_checkout_both "$base/outer/inner")"

    # A directory outside any repository: itself.
    mkdir -p "$base/nogit"
    expect="$base/nogit | $base/nogit"
    assert_eq "non-git directory: itself" "$expect" "$(main_checkout_both "$base/nogit")"

    # A main checkout and a linked worktree of it: the main checkout both times.
    make_git_repo "$base/main" "https://github.com/owner/ws.git"
    seed_commit "$base/main"
    git -C "$base/main" worktree add --quiet -b wt "$base/wt" 2>/dev/null
    expect="$base/main | $base/main"
    assert_eq "main checkout: itself" "$expect" "$(main_checkout_both "$base/main")"
    assert_eq "linked worktree: the main checkout" "$expect" "$(main_checkout_both "$base/wt")"

    # A main checkout made with `git clone --separate-git-dir` (its common
    # dir does not end in /.git): itself, not its git dir.
    git clone --quiet --separate-git-dir="$base/sep.git" "$base/main" "$base/sepmain" 2>/dev/null
    expect="$base/sepmain | $base/sepmain"
    assert_eq "separate-git-dir main checkout: itself" "$expect" "$(main_checkout_both "$base/sepmain")"

    # A linked worktree of that checkout (PR 454's F2): git's first
    # `worktree list` entry is the git dir, not a checkout, so neither helper
    # can name the main checkout. Both fall back to the worktree itself, and
    # both report that they fell back (the decision recorded in issue #265
    # part 4), so a "none registered" message can say instead that no
    # registry was found from this linked worktree.
    git -C "$base/sepmain" worktree add --quiet -b sepwt "$base/sepwt" 2>/dev/null
    expect="$base/sepwt | $base/sepwt"
    assert_eq "separate-git-dir linked worktree: falls back to itself" "$expect" "$(main_checkout_both "$base/sepwt")"
    assert_eq "separate-git-dir linked worktree: both helpers report the fallback" "1 | True" "$(main_checkout_fallback_both "$base/sepwt")"
    assert_eq "a linked worktree whose main checkout is found: no fallback" "0 | False" "$(main_checkout_fallback_both "$base/wt")"
    assert_eq "a main checkout: no fallback" "0 | False" "$(main_checkout_fallback_both "$base/main")"
    assert_eq "a non-git directory: no fallback" "0 | False" "$(main_checkout_fallback_both "$base/nogit")"
}

# Whether registry_main_checkout_fallback and get_main_checkout_status
# report a fallback for <dir> (needs main_checkout_both's copies there).
main_checkout_fallback_both() {
    local dir="$1" sh_out py_out
    sh_out="$(bash -c 'source "$1/.agent/scripts/_project_registry.sh"; registry_main_checkout_fallback "$1" && echo 1 || echo 0' _ "$dir")"
    py_out="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import workspace; print(workspace.get_main_checkout_status()[1])' "$dir/.agent/scripts/lib")"
    printf '%s | %s\n' "$sh_out" "$py_out"
}

test_main_checkout_fallback_messages() {
    echo "TEST: from a separate-git-dir linked worktree, validate and sync say no registry was found here, never 'none registered' (PR 454's F2)"
    local base out
    base="$(phys "$(mktemp -d -p "$SANDBOX")")"
    make_git_repo "$base/main" "file:///nonexistent/ws.git"
    mkdir -p "$base/main/.agent/scripts/lib" "$base/main/.agent/project_types"
    cp "$REAL_ROOT/.agent/scripts/_project_registry.sh" "$REAL_ROOT/.agent/scripts/validate_workspace.py" \
        "$REAL_ROOT/.agent/scripts/adapter" "$base/main/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/lib/"*.py "$base/main/.agent/scripts/lib/"
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$base/main/.agent/project_types/"
    git -C "$base/main" add -A
    seed_commit "$base/main"
    git clone --quiet --separate-git-dir="$base/sep.git" "$base/main" "$base/sepmain" 2>/dev/null
    git -C "$base/sepmain" worktree add --quiet -b sepwt "$base/sepwt" 2>/dev/null
    out="$(cd "$base/sepwt" && python3 .agent/scripts/validate_workspace.py --verbose 2>&1)" || true
    assert_contains "validate: no registry found from here" "no registry found from this linked worktree; run it from the main checkout" "$out"
    assert_not_contains "validate: never 'no project registered'" "no project registered" "$out"
    out="$(cd "$base/sepwt" && python3 .agent/project_types/single_project/sync.py --dry-run 2>&1)" || true
    assert_contains "sync: no registry found from here" "No project was synced (no registry found from this linked worktree; run it from the main checkout)" "$out"
    assert_not_contains "sync: never 'none registered'" "none registered" "$out"
    out="$(cd "$base/sepmain" && python3 .agent/scripts/validate_workspace.py --verbose 2>&1)" || true
    assert_contains "the separate-git-dir main checkout itself: 'no project registered'" "no project registered" "$out"
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
    echo "ghost single_project projects/ghost" > "$sb/.agent/projects.local"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names the project" "project 'ghost'" "$out"
}

test_validate_unknown_type() {
    echo "TEST: validate flags a registry entry with an unknown project type"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_git_repo "$sb/projects/alpha" "git@github.com:owner/alpha.git"
    echo "alpha no_such_type projects/alpha" > "$sb/.agent/projects.local"
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
    assert_contains "reports the parse error" "expected key=value, got 'junk'" "$out"
}

test_validate_legacy_still_works() {
    echo "TEST: validate with an unregistered project/ checkout and no registry passes (project/ is not read)"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_git_repo "$sb/project" "git@github.com:owner/legacy.git"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "passes" "PASSED" "$out"
}

test_validate_neither_shape() {
    echo "TEST: validate passes with no project registered and no project/ (fresh clone, issue #295)"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    out="$(python3 "$sb/.agent/scripts/validate_workspace.py" --verbose 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "passes" "PASSED" "$out"
    assert_contains "says no project is registered" \
        "no project registered (register one with .agent/scripts/register_project.sh <path>)" "$out"
    assert_not_contains "no project/ guidance" "project/ directory does not exist" "$out"
    assert_not_contains "no make setup prompt" "make setup  (will prompt" "$out"
    [[ -e "$sb/project" ]] && rc=1 || rc=0
    assert_eq "no project/ created" "0" "$rc"
}

test_validate_registered_no_legacy_verbose() {
    echo "TEST: validate --verbose with one registered project and no project/ passes, no 'no project registered' line"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_registered_project "$sb" demo >/dev/null
    out="$(python3 "$sb/.agent/scripts/validate_workspace.py" --verbose 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "entry checked" "project 'demo' (single_project)" "$out"
    assert_not_contains "no 'none registered' line" "no project registered" "$out"
}

test_validate_entry_path_missing_no_legacy() {
    echo "TEST: validate --verbose with no project/ still reports a registry line whose path is missing (issue #295)"
    local sb out rc=0 ghost
    sb="$(make_validate_sandbox)"
    # A line with no path field (a parse error since issue #265 part 4
    # retired the projects/<name> default) and a line naming a path that does
    # not exist: both are reported, and neither reads as "nothing registered".
    ghost="$sb/elsewhere/phantom"
    printf 'ghost single_project\nphantom single_project %s\n' "$ghost" > "$sb/.agent/projects.local"
    out="$(python3 "$sb/.agent/scripts/validate_workspace.py" --verbose 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "the line without a path is a parse error naming the registration script" \
        "'ghost' has no path: a registry entry needs its hosting directory (register it with .agent/scripts/register_project.sh <path>)" "$out"
    assert_contains "the line with a missing path is reported at that path" \
        "project 'phantom': hosting dir does not exist: $ghost" "$out"
    assert_not_contains "not told that nothing is registered" "no project registered" "$out"
    [[ -e "$sb/project" || -e "$sb/projects" || -e "$ghost" ]] && rc=1 || rc=0
    assert_eq "nothing created" "0" "$rc"
}

# ---- Per-type checkout-shape delegation (issue #330) ----

# Minimal real ros2_colcon checkout (no .git at its root): one layer "l1"
# pinning the given repos, a declared distro so adapter_validate's distro
# check passes, registered as <name>. Copies the ros2_colcon adapter into
# the sandbox (make_sandbox copies only single_project). Repos are NOT
# checked out — pass them to checkout_colcon_repos.
# Usage: make_colcon_entry <sb> <name> <repo...>; echoes the hosting dir.
make_colcon_entry() {
    local sb="$1" name="$2"
    shift 2
    cp -r "$REAL_ROOT/.agent/project_types/ros2_colcon" "$sb/.agent/project_types/"
    local proj="$sb/projects/$name"
    local mdir="$proj/configs/manifest"
    mkdir -p "$mdir/repos" "$proj/layers/main/l1_ws/src"
    printf 'l1\n' > "$mdir/layers.txt"
    printf 'git_url: file:///nonexistent/manifest.git\nbranch: fakefox\ndistro: fakefox\n' \
        > "$mdir/bootstrap.yaml"
    {
        echo "repositories:"
        local repo
        for repo in "$@"; do
            echo "  $repo:"
            echo "    type: git"
            echo "    url: file:///nonexistent/${repo}.git"
            echo "    version: fakefox"
        done
    } > "$mdir/repos/l1.repos"
    echo "$name ros2_colcon projects/$name" >> "$sb/.agent/projects.local"
    echo "$proj"
}

checkout_colcon_repos() {
    local proj="$1"
    shift
    local repo
    for repo in "$@"; do
        mkdir -p "$proj/layers/main/l1_ws/src/$repo"
    done
}

test_validate_ros2_colcon_entry_without_git_passes() {
    echo "TEST: validate passes a healthy ros2_colcon entry with no .git at its root"
    local sb out rc=0 proj
    sb="$(make_validate_sandbox)"
    proj="$(make_colcon_entry "$sb" rc pkg_a pkg_b)"
    checkout_colcon_repos "$proj" pkg_a pkg_b
    assert_eq "fixture root has no .git" "absent" "$([ -e "$proj/.git" ] && echo present || echo absent)"
    out="$(python3 "$sb/.agent/scripts/validate_workspace.py" --verbose 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "passes" "PASSED" "$out"
    assert_contains "verbose OK line kept" "project 'rc' (ros2_colcon): $proj OK" "$out"
    assert_not_contains "adapter pass line captured, not printed" "checkout matches the manifest" "$out"
    assert_not_contains "no .git demanded" "not a git repository" "$out"
}

test_validate_ros2_colcon_failure_prefixes_every_line() {
    echo "TEST: a failing ros2_colcon entry reports every adapter line, each prefixed with its name"
    local sb out rc=0 unprefixed
    sb="$(make_validate_sandbox)"
    make_colcon_entry "$sb" rc pkg_a pkg_b >/dev/null
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "first missing repo" \
        "project 'rc': ❌ layer 'l1': repo 'pkg_a' pinned in l1.repos but not checked out" "$out"
    assert_contains "second missing repo (not just the first line)" \
        "project 'rc': ❌ layer 'l1': repo 'pkg_b' pinned in l1.repos but not checked out" "$out"
    assert_contains "summary line prefixed" "project 'rc': Validation failed: 2 issue(s)." "$out"
    # No adapter line may appear without the project prefix.
    unprefixed="$(grep -E "pinned in|Validation failed" <<< "$out" | grep -v "project 'rc': " || true)"
    assert_eq "no raw adapter stderr" "" "$unprefixed"
}

test_validate_parse_error_does_not_blame_healthy_entry() {
    echo "TEST: a malformed registry line does not get blamed on a healthy entry"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    echo "broken single_project extra junk" >> "$sb/.agent/projects.local"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "parse error reported" "expected key=value, got 'junk'" "$out"
    assert_not_contains "healthy entry not blamed" "project 'alpha'" "$out"
}

test_validate_parse_error_verbose_says_shape_not_checked() {
    echo "TEST: under registry parse errors the verbose line says the shape was not checked"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    echo "broken single_project extra junk" >> "$sb/.agent/projects.local"
    out="$(python3 "$sb/.agent/scripts/validate_workspace.py" --verbose 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "says only the hosting dir was checked" \
        "project 'alpha' (single_project): $sb/projects/alpha hosting dir present; shape not checked (registry has parse errors)" "$out"
    assert_not_contains "no bare OK for an unchecked shape" \
        "project 'alpha' (single_project): $sb/projects/alpha OK" "$out"
}

# Register <name> under a stub project type whose adapter_validate body is
# <validate_body>; every other verb is a no-op. Creates the hosting dir.
# Usage: make_stub_type_entry <sb> <name> <validate_body>
make_stub_type_entry() {
    local sb="$1" name="$2" body="$3"
    mkdir -p "$sb/.agent/project_types/stub_type" "$sb/projects/$name"
    {
        local verb
        for verb in setup sync build test install env project_root repos \
            scope_for_pr worktree_repos worktree_env; do
            echo "adapter_${verb}() { :; }"
        done
        echo "adapter_validate() { $body; }"
    } > "$sb/.agent/project_types/stub_type/adapter.sh"
    echo "$name stub_type projects/$name" >> "$sb/.agent/projects.local"
}

test_validate_adapter_timeout() {
    echo "TEST: a hung adapter validate is killed and reported as timed out"
    local sb out rc=0 start elapsed
    sb="$(make_validate_sandbox)"
    # A child process (sleep) holding the output pipes: killing only the
    # dispatcher would still leave the output read blocked.
    make_stub_type_entry "$sb" hang 'sleep 30'
    start="$(date +%s)"
    out="$(WS_ADAPTER_VALIDATE_TIMEOUT=1 run_validate "$sb")" || rc=$?
    elapsed=$(( $(date +%s) - start ))
    assert_eq "exit 1" "1" "$rc"
    assert_contains "reports the timeout" "project 'hang': adapter validate timed out after 1s" "$out"
    assert_eq "returns promptly (not after the 30 s sleep)" "yes" "$([ "$elapsed" -lt 10 ] && echo yes || echo "no (${elapsed}s)")"
}

# Interrupt validate_workspace.py with <signal> while it waits on a stub
# adapter, then assert the adapter and its child are gone. The adapter runs
# in its own session, so without the kill-on-exception wrapper both survive
# as orphans. Python is launched with SIGINT restored to KeyboardInterrupt:
# a background job of a non-interactive shell starts with SIGINT ignored.
# Every recorded pid is SIGKILLed at the end so a failure leaves no stray.
_validate_interrupt_case() {
    local sig="$1" sb pidfile vpid rc=0 pid alive=""
    sb="$(make_validate_sandbox)"
    pidfile="$sb/adapter.pids"
    make_stub_type_entry "$sb" hang "sleep 30 & echo \"\$\$ \$!\" > '$pidfile'; wait"
    python3 -c 'import runpy, signal, sys
signal.signal(signal.SIGINT, signal.default_int_handler)
sys.argv = [sys.argv[1]]
runpy.run_path(sys.argv[0], run_name="__main__")' \
        "$sb/.agent/scripts/validate_workspace.py" >/dev/null 2>&1 &
    vpid=$!
    for _ in $(seq 1 100); do
        [ -s "$pidfile" ] && break
        sleep 0.1
    done
    assert_eq "$sig: adapter started" "yes" "$([ -s "$pidfile" ] && echo yes || echo no)"
    kill "-$sig" "$vpid" 2>/dev/null || true
    wait "$vpid" || rc=$?
    assert_eq "$sig: validate exits non-zero" "yes" "$([ "$rc" -ne 0 ] && echo yes || echo "no (rc=$rc)")"
    # Give init a moment to reap the killed (reparented) processes.
    for _ in $(seq 1 30); do
        alive=""
        for pid in $(cat "$pidfile" 2>/dev/null); do
            kill -0 "$pid" 2>/dev/null && alive="$alive $pid"
        done
        [ -z "$alive" ] && break
        sleep 0.1
    done
    assert_eq "$sig: adapter and its child killed (no orphans)" "" "$alive"
    for pid in $(cat "$pidfile" 2>/dev/null); do
        kill -KILL "$pid" 2>/dev/null || true
    done
}

test_validate_interrupt_kills_adapter() {
    echo "TEST: Ctrl-C / SIGTERM during adapter validate kills the adapter's process group"
    _validate_interrupt_case INT
    _validate_interrupt_case TERM
}

test_validate_adapter_failure_stdout_fallback() {
    echo "TEST: a failing adapter with empty stderr is reported by its stdout lines"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_stub_type_entry "$sb" quiet 'echo "checkout is missing foo"; echo "and bar"; return 3'
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "first stdout line prefixed" "project 'quiet': checkout is missing foo" "$out"
    assert_contains "second stdout line prefixed" "project 'quiet': and bar" "$out"
    assert_not_contains "no generic exit line when stdout names it" "adapter validate exited 3" "$out"

    echo "TEST: a failing adapter with no output at all falls back to the exit code"
    sb="$(make_validate_sandbox)"
    make_stub_type_entry "$sb" silent 'return 4'
    rc=0
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "generic exit line" \
        "project 'silent': checkout shape check failed (adapter validate exited 4)" "$out"
}

test_validate_nested_non_git_entry_fails() {
    echo "TEST: validate fails a registered non-git dir nested inside another repo"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_git_repo "$sb/outer" "file:///nonexistent/outer.git"
    mkdir -p "$sb/outer/inner"
    echo "inner single_project $sb/outer/inner" >> "$sb/.agent/projects.local"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names the project" "project 'inner': ❌ $sb/outer/inner is not a git repository" "$out"
}

test_single_project_scoped_validate_ignores_broken_sibling() {
    echo "TEST: adapter --project <name> validate checks only that project"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    echo "ghost single_project projects/ghost" >> "$sb/.agent/projects.local"   # no checkout
    make_colcon_entry "$sb" rc pkg_a >/dev/null                   # repo missing
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project alpha validate 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "reports its own checkout" "git repository: $sb/projects/alpha" "$out"
    assert_not_contains "sibling ghost not checked" "ghost" "$out"
    assert_not_contains "sibling rc not checked" "projects/rc" "$out"
    assert_not_contains "no whole-workspace run" "Validating workspace" "$out"
}

test_single_project_scoped_validate_nested_dir_fails() {
    echo "TEST: adapter --project <name> validate fails a non-git dir inside another repo"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_git_repo "$sb/outer" "file:///nonexistent/outer.git"
    mkdir -p "$sb/outer/inner"
    echo "inner single_project $sb/outer/inner" >> "$sb/.agent/projects.local"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project inner validate 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "not a git repository" "$sb/outer/inner is not a git repository" "$out"
}

test_single_project_legacy_validate() {
    echo "TEST: adapter validate (no --project) from the workspace refuses; a project/ checkout is not validated (issue #265 part 4)"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" validate 2>&1)" || rc=$?
    assert_eq "nothing registered: exit 1" "1" "$rc"
    assert_contains "nothing registered: names the registration script" "and none is registered. Register one: .agent/scripts/register_project.sh <path>" "$out"
    make_git_repo "$sb/project" "git@github.com:owner/legacy.git"
    rc=0
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" validate 2>&1)" || rc=$?
    assert_eq "a git project/ does not make it pass" "1" "$rc"
    assert_not_contains "project/ is not validated" "single_project checkout is a git repository" "$out"
}

# ---- worktree_create.sh --project wiring ----

# Worktree sandboxes get the worktree scripts, their helpers, and a failing
# gh stub so issue lookups degrade gracefully offline. Their origins cannot
# be reached, so origin cannot say whether it has a branch: every
# worktree_create.sh --issue call below passes --allow-unverified-branch
# (#323), since these tests are about the registry wiring, not the branch
# lookup. The --skill calls do not: a skill branch is minted with a
# timestamp and never looked up on origin, so they work offline as they are.
make_worktree_sandbox() {
    local sb
    sb="$(make_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_create.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_enter.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_worktree_helpers.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_resolve_default_branch.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_issue_helpers.sh" "$sb/.agent/scripts/"
    mkdir -p "$sb/stubbin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/gh"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"
    chmod +x "$sb/stubbin/gh" "$sb/stubbin/git-bug"
    # The sandbox root itself must be a git repo (workspace repo stand-in).
    git -C "$sb" init --quiet -b main
    echo "$sb"
}

# Seed a commit so worktree add has a HEAD to branch from.
seed_commit() {
    local dir="$1"
    (cd "$dir" \
        && git -c user.name=t -c user.email=t@t commit --allow-empty -m init --quiet)
}

test_worktree_create_unknown_repo() {
    echo "TEST: worktree_create --project with unregistered name fails and lists projects"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 999 --type project --project nope 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "names the unknown project" "'nope' is not registered" "$out"
    assert_contains "lists registered projects" "alpha" "$out"
}

test_worktree_create_skill_project() {
    echo "TEST: worktree_create --skill onboard-project --type project: the root's repo on a skill branch, entered and removed by --skill (#332)"
    local sb out rc=0 wtp branch
    sb="$(make_worktree_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --skill onboard-project --type project --project alpha 2>&1)" || rc=$?
    assert_eq "exit 0 ($(tail -n3 <<< "$out"))" "0" "$rc"
    wtp="$(find "$sb/projects/alpha/worktrees" -maxdepth 1 -name 'skill-alpha-onboard-project-*' -type d 2>/dev/null | head -n1)"
    assert_eq "worktree under the root's worktrees/" "yes" "$([ -n "$wtp" ] && echo yes || echo no)"
    branch="$(git -C "$wtp" branch --show-current 2>/dev/null)"
    assert_eq "on a skill/onboard-project-<timestamp> branch (got $branch)" \
        "yes" "$([[ "$branch" =~ ^skill/onboard-project-[0-9]{8}-[0-9]{6}- ]] && echo yes || echo no)"
    assert_eq "a checkout of the alpha repo" \
        "$(cd "$sb/projects/alpha/.git" && pwd -P)" \
        "$(cd "$wtp" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_enter.sh" --skill onboard-project --type project --project alpha --print-path 2>&1)" || rc=$?
    assert_eq "enter --skill finds it" "$wtp" "$out"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_remove.sh" --skill onboard-project --type project --project alpha --force 2>&1)" || rc=$?
    assert_eq "remove --skill exit 0" "0" "$rc"
    assert_eq "the worktree is gone" "no" "$([ -d "$wtp" ] && echo yes || echo no)"

    echo "TEST: worktree_create --skill: a skill not on the allowlist is refused; a root that is not the top of a repo is refused"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --skill plan-task --type project --project alpha 2>&1)" || rc=$?
    assert_eq "plan-task: exit 1" "1" "$rc"
    assert_contains "says the allowlist" "is not in the allowlist" "$out"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --skill research --type project --project alpha 2>&1)" || rc=$?
    assert_eq "research --type project: exit 1" "1" "$rc"
    assert_contains "says research is for workspace worktrees" "--skill research is for --type workspace worktrees, not --type project" "$out"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --skill onboard-project --type workspace 2>&1)" || rc=$?
    assert_eq "onboard-project --type workspace: exit 1" "1" "$rc"
    assert_contains "says onboard-project is for project worktrees" "--skill onboard-project is for --type project worktrees, not --type workspace" "$out"
    mkdir -p "$sb/projects/alpha/sub"
    echo "sub single_project $sb/projects/alpha/sub" >> "$sb/.agent/projects.local"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --skill onboard-project --type project --project sub 2>&1)" || rc=$?
    assert_eq "a root inside another repo: exit 1" "1" "$rc"
    assert_contains "says why" "is not the top of one" "$out"

    echo "TEST: worktree_list.sh: a project named with - and . lists its skill and issue worktrees under that name"
    cp "$REAL_ROOT/.agent/scripts/worktree_list.sh" "$sb/.agent/scripts/"
    local mp
    mp="$(make_registered_project "$sb" my-proj.x)"
    seed_commit "$mp"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --skill onboard-project --type project --project my-proj.x 2>&1)" || rc=$?
    assert_eq "skill worktree of my-proj.x: exit 0 ($(tail -n2 <<< "$out"))" "0" "$rc"
    git -C "$mp" worktree add --quiet -b feature/issue-7 "$mp/worktrees/issue-my-proj.x-7" 2>/dev/null
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_list.sh" --json 2>/dev/null)" || true
    assert_eq "the skill worktree: repo my-proj.x, skill onboard-project" "my-proj.x onboard-project" \
        "$(jq -r '.worktrees[] | select(.type == "project" and .skill != null and (.path | contains("my-proj.x"))) | "\(.repo) \(.skill)"' <<< "$out")"
    assert_eq "the issue worktree: repo my-proj.x, issue 7" "my-proj.x 7" \
        "$(jq -r '.worktrees[] | select(.type == "project" and .issue != null and (.path | contains("my-proj.x"))) | "\(.repo) \(.issue)"' <<< "$out")"
}

test_worktree_create_registry_repo() {
    echo "TEST: worktree_create --project <name> creates the worktree from the registry checkout"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 999 --type project --project alpha 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "worktree exists under the registry name" \
        "yes" "$([ -d "$sb/projects/alpha/worktrees/issue-alpha-999" ] && echo yes || echo no)"
    assert_eq "worktree is a checkout of the alpha repo" \
        "feature/issue-999" \
        "$(git -C "$sb/projects/alpha/worktrees/issue-alpha-999" branch --show-current 2>/dev/null)"
}

test_worktree_create_single_registry_autoselect() {
    echo "TEST: worktree_create without --project auto-selects the single registered project"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 998 --type project 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "announces the auto-selection" "Using registered project 'alpha'" "$out"
    assert_eq "worktree created" \
        "yes" "$([ -d "$sb/projects/alpha/worktrees/issue-alpha-998" ] && echo yes || echo no)"
}

test_worktree_create_dashed_name_roundtrip() {
    echo "TEST: dashed registry name survives create → enter --project round-trip"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" my-proj >/dev/null
    seed_commit "$sb/projects/my-proj"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 996 --type project --project my-proj 2>&1)" || rc=$?
    assert_eq "create exit 0" "0" "$rc"
    assert_eq "worktree dir uses the raw name" \
        "yes" "$([ -d "$sb/projects/my-proj/worktrees/issue-my-proj-996" ] && echo yes || echo no)"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_enter.sh" --issue 996 --type project --project my-proj --print-path 2>&1)" || rc=$?
    assert_eq "enter --project finds it" "0" "$rc"
    assert_eq "enter resolves the same path" \
        "$sb/projects/my-proj/worktrees/issue-my-proj-996" "$out"
}

test_worktree_create_repo_alias() {
    echo "TEST: worktree_create --repo alpha still succeeds (alias for --project)"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 995 --type project --repo alpha 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "worktree exists under the registry name" \
        "yes" "$([ -d "$sb/projects/alpha/worktrees/issue-alpha-995" ] && echo yes || echo no)"
}

test_worktree_create_single_repo_no_manifest_file() {
    echo "TEST: a single_project worktree gets no .worktree-repos and no untracked files"
    local sb out rc=0 wt
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    seed_commit "$sb/projects/alpha"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 994 --type project --project alpha 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    wt="$sb/projects/alpha/worktrees/issue-alpha-994"
    assert_eq "no .worktree-repos file written" \
        "false" "$([ -e "$wt/.worktree-repos" ] && echo true || echo false)"
    assert_eq "worktree checkout has no untracked/uncommitted files" \
        "" "$(git -C "$wt" status --porcelain)"
}

test_worktree_create_multiple_requires_repo() {
    echo "TEST: worktree_create without --project fails when multiple projects are registered"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    make_registered_project "$sb" beta >/dev/null
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 997 --type project 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "asks for --project and lists alpha and beta" "Registered: alpha, beta. Pass --project <name>" "$out"
}


# ---- Trailing fields, parent roots, worktree dirs, root guard (#265) ----

# Source the registry helper in a subshell and run a function against a
# sandbox. Usage: reg <sb> <function> [args...]
reg() {
    local sb="$1"; shift
    (
        # shellcheck source=/dev/null
        source "$sb/.agent/scripts/_project_registry.sh"
        "$@"
    )
}

# Source the worktree helper (which itself sources the registry helper) in
# a subshell and run a function against a sandbox. Requires
# _worktree_helpers.sh to have been copied into the sandbox (make_sandbox
# does not do this by itself — make_worktree_sandbox does).
# Usage: wt <sb> <function> [args...]
wt() {
    local sb="$1"; shift
    (
        # shellcheck source=/dev/null
        source "$sb/.agent/scripts/_worktree_helpers.sh"
        "$@"
    )
}

# Two-instance parent layout at <sb>/p11-ng. Usage: make_parent_layout <sb> [default_instance]
make_parent_layout() {
    local sb="$1" dflt="${2:-}"
    mkdir -p "$sb/p11-ng"
    make_git_repo "$sb/p11-ng/jazzy" "file:///nonexistent/p11.git"
    make_git_repo "$sb/p11-ng/rolling" "file:///nonexistent/p11.git"
    {
        if [ -n "$dflt" ]; then
            echo "p11 project $sb/p11-ng default_instance=$dflt"
        else
            echo "p11 project $sb/p11-ng"
        fi
        echo "p11-jazzy single_project $sb/p11-ng/jazzy parent=p11 distro=jazzy role=dev"
        echo "p11-rolling single_project $sb/p11-ng/rolling parent=p11 distro=rolling"
    } >> "$sb/.agent/projects.local"
}

test_registry_fields_parse() {
    echo "TEST: trailing key=value fields parse; three-column output unchanged"
    local sb out
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    echo "beta single_project $sb/beta distro=jazzy role=dev worktrees=wt/beta" >> "$sb/.agent/projects.local"
    mkdir -p "$sb/beta"
    out="$(reg "$sb" registry_entries "$sb")"
    assert_eq "three columns for a field-bearing line" \
        "$(printf 'beta\tsingle_project\t%s/beta' "$sb")" "$(grep '^beta' <<< "$out")"
    out="$(reg "$sb" registry_entries_full "$sb")"
    assert_eq "full form carries the fields" \
        "$(printf 'beta\tsingle_project\t%s/beta\tdistro=jazzy role=dev worktrees=%s/wt/beta' "$sb" "$sb")" \
        "$(grep '^beta' <<< "$out")"
    assert_eq "registry_field reads a field" "jazzy" "$(reg "$sb" registry_field "$sb" beta distro)"
    assert_eq "registry_field on a missing field returns 1" "1" \
        "$(reg "$sb" registry_field "$sb" alpha distro >/dev/null 2>&1; echo $?)"
}

test_registry_pathless_entry_fails() {
    echo "TEST: an entry with no path is a parse error in both parsers (issue #265 part 4: no projects/<name> default)"
    local sb out rc=0 line
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    for line in "gamma single_project" "gamma single_project role=ops"; do
        echo "$line" >> "$sb/.agent/projects.local"
        rc=0; out="$(reg "$sb" registry_entries_full "$sb" 2>&1)" || rc=$?
        assert_eq "shell: '$line' → rc 2" "2" "$rc"
        assert_contains "shell: '$line' names the missing path and the registration script" \
            "'gamma' has no path: a registry entry needs its hosting directory (register it with .agent/scripts/register_project.sh <path>)" "$out"
        assert_not_contains "shell: '$line' never defaults to projects/gamma" "$sb/projects/gamma" "$out"
        assert_contains "shell: the healthy entry still prints" "$(printf 'alpha\tsingle_project\t%s/projects/alpha' "$sb")" "$out"
        out="$(cd "$sb" && python3 -c 'import sys; sys.path.insert(0, ".agent/scripts/lib"); from workspace import read_projects_registry; e, err = read_projects_registry("."); print([x["name"] for x in e]); print("\n".join(err))' 2>&1)"
        assert_contains "python: '$line' is an error with the same text" \
            "'gamma' has no path: a registry entry needs its hosting directory (register it with .agent/scripts/register_project.sh <path>)" "$out"
        assert_contains "python: only the healthy entry parses" "['alpha']" "$out"
        sed -i '/^gamma /d' "$sb/.agent/projects.local"
    done
}

test_registry_no_project_message() {
    echo "TEST: registry_no_project_message names the cwd, the registered names and the way out"
    local sb out rc=0
    sb="$(make_sandbox)"
    out="$(reg "$sb" registry_no_project_message "$sb" "$sb/docs")" || rc=$?
    assert_eq "none registered: rc 0" "0" "$rc"
    assert_eq "none registered: the sentence" \
        "no registered project here (cwd $sb/docs), and none is registered. Register one: .agent/scripts/register_project.sh <path>" "$out"
    make_registered_project "$sb" alpha >/dev/null
    out="$(reg "$sb" registry_no_project_message "$sb" "$sb")"
    assert_eq "one registered: the sentence" \
        "no registered project here (cwd $sb). Registered: alpha. Pass --project <name> or register one: .agent/scripts/register_project.sh <path>" "$out"
    make_registered_project "$sb" beta >/dev/null
    make_registered_project "$sb" gamma >/dev/null
    out="$(reg "$sb" registry_no_project_message "$sb" "$sb")"
    assert_eq "three registered: listed in registry order" \
        "no registered project here (cwd $sb). Registered: alpha, beta, gamma. Pass --project <name> or register one: .agent/scripts/register_project.sh <path>" "$out"
    echo "a..b single_project x" >> "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_no_project_message "$sb" "$sb" 2>/dev/null)" || rc=$?
    assert_eq "parse error: rc 2" "2" "$rc"
    assert_contains "parse error: the sentence still prints the parseable names" "Registered: alpha, beta, gamma." "$out"
}

test_registry_fields_rejected() {
    echo "TEST: unknown, malformed and duplicate fields fail loud"
    local sb out rc
    sb="$(make_sandbox)"
    for line in \
        "a single_project $sb/a colour=red" \
        "b single_project $sb/b distro=" \
        "c single_project $sb/c junk" \
        "d single_project $sb/d distro=jazzy distro=rolling" \
        "e single_project $sb/e distro=Jazzy!" \
        "f single_project $sb/f parent=x..y"; do
        echo "$line" > "$sb/.agent/projects.local"
        rc=0
        out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
        assert_eq "rc 2 for: $line" "2" "$rc"
        assert_contains "line reported for: $line" "projects.local:1" "$out"
    done
    echo "a single_project $sb/a colour=red" > "$sb/.agent/projects.local"
    out="$(reg "$sb" registry_entries "$sb" 2>&1)" || true
    assert_contains "unknown field names the known keys" "known: parent worktrees role distro default_instance" "$out"
    # '=' is forbidden in paths (a third token with '=' is a field), so this
    # is rejected as an unknown field rather than silently misparsed.
    echo "eq single_project /srv/project=blue" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "'=' in a path is rejected" "2" "$rc"
    # A value containing '=' (e.g. a worktrees path) is not a duplicate key.
    mkdir -p "$sb/w"
    echo "w single_project $sb/w worktrees=$sb/w/role=foo role=dev" > "$sb/.agent/projects.local"
    assert_eq "value with '=' is not a duplicate key" "dev" "$(reg "$sb" registry_field "$sb" w role 2>&1)"
    assert_eq "worktrees value keeps its '='" "$sb/w/role=foo" "$(reg "$sb" registry_field "$sb" w worktrees 2>&1)"
    # Field tokens are never glob-expanded against the caller's cwd.
    mkdir -p "$sb/globdir/worktrees=wt-secret-evil" "$sb/g"
    echo "g single_project $sb/g worktrees=wt-*" > "$sb/.agent/projects.local"
    assert_eq "no pathname expansion of field tokens" "$sb/wt-*" "$(cd "$sb/globdir" && reg "$sb" registry_field "$sb" g worktrees 2>&1)"
    # The getter itself must not glob either: a file whose name matches a
    # serialized field must not change what registry_field returns.
    mkdir -p "$sb/globdir2" && touch "$sb/globdir2/role=x" "$sb/globdir2/role=y"
    echo "g2 single_project $sb/g2 role=* distro=jazzy" > "$sb/.agent/projects.local"
    rc=0; out="$(cd "$sb/globdir2" && reg "$sb" registry_field "$sb" g2 distro 2>&1)" || rc=$?
    assert_eq "role=* is rejected by the role regex, not expanded" "2" "$rc"
    echo "g2 single_project $sb/g2 worktrees=$sb/g2/role=* distro=jazzy" > "$sb/.agent/projects.local"
    assert_eq "getter does not expand a value that looks like a glob" "$sb/g2/role=*" "$(cd "$sb/globdir2" && reg "$sb" registry_field "$sb" g2 worktrees 2>&1)"
    # CRLF line endings are tolerated and never leak '\r' into paths.
    printf 'crlf single_project %s/crlf distro=jazzy\r\n' "$sb" > "$sb/.agent/projects.local"
    mkdir -p "$sb/crlf"
    assert_eq "CRLF path clean" "$(printf 'crlf\tsingle_project\t%s/crlf' "$sb")" "$(reg "$sb" registry_entries "$sb" 2>&1)"
    assert_eq "CRLF field clean" "jazzy" "$(reg "$sb" registry_field "$sb" crlf distro 2>&1 | od -c | grep -c '\\r' | sed 's/^0$/jazzy/')"
    # distro follows the ros2_colcon rule (no hyphens); role may have them.
    echo "h single_project $sb/h distro=my-distro" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "hyphenated distro rejected" "2" "$rc"
    echo "h single_project $sb/h role=my-role distro=jazzy" > "$sb/.agent/projects.local"
    assert_eq "hyphenated role accepted" "my-role" "$(reg "$sb" registry_field "$sb" h role 2>&1)"
    # Two entries resolving to one directory (literal or symlink alias).
    mkdir -p "$sb/real" && ln -s "$sb/real" "$sb/alias"
    printf 'r1 single_project %s/real\nr2 single_project %s/alias\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "aliased path → rc 2" "2" "$rc"
    assert_contains "names the collision" "'r2' resolves to $sb/real, already registered" "$out"
    assert_eq "first entry kept" "r1" "$(reg "$sb" registry_names "$sb" 2>/dev/null)"
    # Duplicate names are rejected (first definition wins for lookups).
    printf 'dup single_project %s/a\ndup single_project %s/b\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "duplicate name → rc 2" "2" "$rc"
    assert_contains "names the duplicate" "projects.local:2: duplicate project name 'dup'" "$out"
    assert_eq "first definition kept" "$(printf 'dup\tsingle_project\t%s/a' "$sb")" "$(reg "$sb" registry_entries "$sb" 2>/dev/null)"
}

test_registry_parent_rules() {
    echo "TEST: parent= and default_instance= cross-line rules"
    local sb out rc
    sb="$(make_sandbox)"
    echo "inst single_project $sb/inst parent=ghost" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "unregistered parent → rc 2" "2" "$rc"
    assert_contains "names the missing parent" "parent 'ghost' of 'inst' is not registered" "$out"
    printf 'notparent single_project %s/np\ninst single_project %s/inst parent=notparent\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "non-project parent → rc 2" "2" "$rc"
    assert_contains "names the wrong type" "is type 'single_project', not 'project'" "$out"
    assert_eq "valid line still printed" "notparent" "$(reg "$sb" registry_names "$sb" 2>/dev/null)"
    echo "solo single_project $sb/solo default_instance=solo" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_contains "default_instance on non-parent rejected" "only valid on a 'project' line" "$out"
    printf 'p project %s/p default_instance=other\nother single_project %s/o\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_contains "default_instance must be an instance" "default_instance 'other' is not an instance of 'p'" "$out"
    printf 'outer project %s/o\ninner project %s/o/i parent=outer\nleaf single_project %s/o/i/l parent=inner\n' "$sb" "$sb" "$sb" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "nested parent → rc 2" "2" "$rc"
    assert_contains "no nesting" "parent root 'inner' may not itself have a parent" "$out"
}

test_registry_instances_and_default() {
    echo "TEST: registry_instances / registry_default_instance"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_parent_layout "$sb"
    assert_eq "instances listed" "$(printf 'p11-jazzy\np11-rolling')" "$(reg "$sb" registry_instances "$sb" p11)"
    out="$(reg "$sb" registry_default_instance "$sb" p11 2>&1)" || rc=$?
    assert_eq "two instances, no default → rc 1" "1" "$rc"
    assert_contains "lists the instances" "--project p11-jazzy" "$out"
    assert_contains "hints at default_instance" "default_instance=" "$out"
    assert_eq "non-parent name passes through" "p11-jazzy" "$(reg "$sb" registry_default_instance "$sb" p11-jazzy)"
    sb="$(make_sandbox)"
    make_parent_layout "$sb" p11-rolling
    assert_eq "default_instance honoured" "p11-rolling" "$(reg "$sb" registry_default_instance "$sb" p11)"
    sb="$(make_sandbox)"
    mkdir -p "$sb/one"
    printf 'p project %s/one\nonly single_project %s/one/a parent=p\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    mkdir -p "$sb/one/a"
    assert_eq "single instance used without a default" "only" "$(reg "$sb" registry_default_instance "$sb" p)"
}

test_registry_worktree_dir() {
    echo "TEST: registry_worktree_dir: default, override, unregistered name refused (issue #265 part 4)"
    local sb out rc
    sb="$(make_sandbox)"
    make_registered_project "$sb" alpha >/dev/null
    echo "beta single_project $sb/beta worktrees=$sb/beta/.wt" >> "$sb/.agent/projects.local"
    echo "gamma single_project $sb/gamma worktrees=wt/gamma" >> "$sb/.agent/projects.local"
    assert_eq "default under the hosting dir" "$sb/projects/alpha/worktrees" "$(reg "$sb" registry_worktree_dir "$sb" alpha)"
    assert_eq "absolute override under the entry's path" "$sb/beta/.wt" "$(reg "$sb" registry_worktree_dir "$sb" beta)"
    assert_eq "relative override resolves against the workspace" "$sb/wt/gamma" "$(reg "$sb" registry_worktree_dir "$sb" gamma)"
    rc=0; out="$(reg "$sb" registry_worktree_dir "$sb" legacy 2>&1)" || rc=$?
    assert_eq "unregistered name → rc 1" "1" "$rc"
    assert_contains "unregistered name: refused with the registered names and the way out" \
        "ERROR: project 'legacy' is not registered (registered: alpha, beta, gamma); register it: .agent/scripts/register_project.sh <path>" "$out"
    assert_not_contains "unregistered name: never the retired location" "worktrees/project" "$out"
    assert_eq "rejects a traversal name" "1" "$(reg "$sb" registry_worktree_dir "$sb" "../../outside" >/dev/null 2>&1; echo $?)"
    assert_eq "rejects a slash" "1" "$(reg "$sb" registry_worktree_dir "$sb" "a/b" >/dev/null 2>&1; echo $?)"
    rc=0; out="$(reg "$sb" registry_resolve_project_arg "$sb" legacy 2>&1)" || rc=$?
    assert_eq "registry_resolve_project_arg: unregistered name → rc 1" "1" "$rc"
    assert_contains "registry_resolve_project_arg: the same refusal, never the name printed back" \
        "ERROR: project 'legacy' is not registered (registered: alpha, beta, gamma)" "$out"
    assert_eq "registry_resolve_project_arg: a registered name prints back" "alpha" "$(reg "$sb" registry_resolve_project_arg "$sb" alpha)"
    # An override outside both the entry's path and the workspace would be
    # refused by registry_require_root, so the parser rejects it up front.
    echo "delta single_project $sb/delta worktrees=/tmp/elsewhere" > "$sb/.agent/projects.local"
    local rc=0 out
    out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "worktrees outside root → rc 2" "2" "$rc"
    assert_contains "says where it must lie" "must lie under $sb/delta or under the workspace root" "$out"
    # A relative override that climbs out with '..' is normalized before the
    # containment check, so it is rejected too.
    echo "eps single_project $sb/eps worktrees=../outside" > "$sb/.agent/projects.local"
    rc=0; out="$(reg "$sb" registry_entries "$sb" 2>&1)" || rc=$?
    assert_eq "worktrees=../outside → rc 2" "2" "$rc"
    echo "zeta single_project $sb/zeta worktrees=$sb/zeta/../zeta/wt" > "$sb/.agent/projects.local"
    assert_eq "'..' that stays inside is normalized and kept" "$sb/zeta/wt" "$(reg "$sb" registry_worktree_dir "$sb" zeta 2>&1)"
    echo "eta single_project $sb/eta/../eta" > "$sb/.agent/projects.local"
    assert_eq "entry path itself is normalized" "$(printf 'eta\tsingle_project\t%s/eta' "$sb")" "$(reg "$sb" registry_entries "$sb" 2>&1)"
    echo "a..b single_project" > "$sb/.agent/projects.local"
    assert_eq "parse error → rc 2" "2" "$(reg "$sb" registry_worktree_dir "$sb" alpha >/dev/null 2>&1; echo $?)"
}

test_registry_require_root() {
    echo "TEST: registry_require_root accepts workspace and registered roots, refuses elsewhere"
    local sb out rc outside
    sb="$(make_sandbox)"
    # Sibling of the per-test sandbox under $SANDBOX, never a child of it:
    # the point of this dir is to sit outside the sandbox workspace root.
    outside="$(mktemp -d -p "$SANDBOX")"
    make_registered_project "$sb" alpha "$outside/alpha" >/dev/null
    mkdir -p "$outside/alpha/deep" "$outside/unrelated"
    assert_eq "workspace root ok" "0" "$(reg "$sb" registry_require_root "$sb" "$sb"; echo $?)"
    assert_eq "inside workspace ok" "0" "$(reg "$sb" registry_require_root "$sb" "$sb/.agent"; echo $?)"
    assert_eq "registered root ok" "0" "$(reg "$sb" registry_require_root "$sb" "$outside/alpha/deep"; echo $?)"
    rc=0; out="$(reg "$sb" registry_require_root "$sb" "$outside/unrelated" 2>&1)" || rc=$?
    assert_eq "unrelated dir refused" "1" "$rc"
    assert_contains "says why" "refusing to run" "$out"
    assert_contains "names the registry" "projects.local" "$out"
    rc=0; out="$(reg "$sb" registry_require_root "$sb" "$sb/nope" 2>&1)" || rc=$?
    assert_eq "missing dir refused" "1" "$rc"
    echo "a..b single_project" > "$sb/.agent/projects.local"
    assert_eq "parse error → rc 2 (never guess)" "2" "$(reg "$sb" registry_require_root "$sb" "$outside/unrelated" >/dev/null 2>&1; echo $?)"
}

test_adapter_parent_resolves_instance() {
    echo "TEST: adapter resolves a parent root to its default_instance / only instance"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_parent_layout "$sb" p11-rolling
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project p11 project_root)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "--project parent → default instance root" "$sb/p11-ng/rolling" "$out"
    out="$(cd "$sb/p11-ng" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "cwd at parent → default instance root" "$sb/p11-ng/rolling" "$out"
    out="$(cd "$sb/p11-ng/jazzy" && "$sb/.agent/scripts/adapter" project_root)" || true
    assert_eq "cwd inside an instance → that instance (longest match)" "$sb/p11-ng/jazzy" "$out"
}

test_adapter_parent_ambiguous_fails() {
    echo "TEST: adapter on a parent with several instances and no default fails and lists them"
    local sb out rc=0
    sb="$(make_sandbox)"
    make_parent_layout "$sb"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project p11 project_root 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "lists jazzy" "--project p11-jazzy" "$out"
    assert_contains "lists rolling" "--project p11-rolling" "$out"
}

test_adapter_registry_distro_and_role_exported() {
    echo "TEST: adapter exposes registry role/distro fields to the adapter type"
    local sb out
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/probe"
    cat > "$sb/.agent/project_types/probe/adapter.sh" <<'EOF'
adapter_setup() { :; }
adapter_sync() { :; }
adapter_validate() { :; }
adapter_build() { :; }
adapter_test() { :; }
adapter_install() { :; }
adapter_env() { :; }
adapter_project_root() { echo "role=${ACTIVE_PROJECT_ROLE:-} distro=${ACTIVE_PROJECT_DISTRO:-}"; }
adapter_repos() { :; }
adapter_scope_for_pr() { :; }
adapter_worktree_repos() { :; }
adapter_worktree_env() { :; }
EOF
    mkdir -p "$sb/x"
    echo "x probe $sb/x role=operator distro=jazzy" > "$sb/.agent/projects.local"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project x project_root)" || true
    assert_eq "fields reach the adapter" "role=operator distro=jazzy" "$out"
    echo "x probe $sb/x" > "$sb/.agent/projects.local"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project x project_root)" || true
    assert_eq "absent fields are empty" "role= distro=" "$out"
}

test_validate_parent_root() {
    echo "TEST: validate accepts a parent root with instances; flags missing dir / no instances"
    local sb out rc=0
    sb="$(make_validate_sandbox)"
    make_parent_layout "$sb" p11-rolling
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    rc=0
    echo "lonely project $sb/lonely" >> "$sb/.agent/projects.local"
    mkdir -p "$sb/lonely"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "parent without instances → exit 1" "1" "$rc"
    assert_contains "names it" "parent root 'lonely': no instances registered" "$out"
    rc=0
    sb="$(make_validate_sandbox)"
    printf 'p project %s/missing\ni single_project %s/i parent=p\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    make_git_repo "$sb/i" "file:///nonexistent/i.git"
    out="$(run_validate "$sb")" || rc=$?
    assert_eq "parent dir missing → exit 1" "1" "$rc"
    assert_contains "names the dir" "parent root 'p': directory does not exist" "$out"
}

test_validate_python_parser_matches_shell() {
    echo "TEST: python and shell parsers produce the same entries and the same errors"
    local sb shell_out py_out
    sb="$(make_sandbox)"
    make_parent_layout "$sb" p11-rolling
    echo "bad single_project $sb/bad colour=red" >> "$sb/.agent/projects.local"
    echo "p11 single_project $sb/dup" >> "$sb/.agent/projects.local"
    echo "nest project $sb/nest parent=p11" >> "$sb/.agent/projects.local"
    printf 'crlf single_project %s/crlf distro=jazzy\r\n' "$sb" >> "$sb/.agent/projects.local"
    echo "far single_project $sb/far worktrees=/tmp/elsewhere" >> "$sb/.agent/projects.local"
    echo "climb single_project $sb/climb worktrees=../outside" >> "$sb/.agent/projects.local"
    mkdir -p "$sb/real2" "$sb/crlf" && ln -s "$sb/real2" "$sb/alias2"
    echo "r1 single_project $sb/real2" >> "$sb/.agent/projects.local"
    echo "r2 single_project $sb/alias2" >> "$sb/.agent/projects.local"
    echo "h single_project $sb/h distro=my-distro" >> "$sb/.agent/projects.local"
    echo "w single_project $sb/w worktrees=$sb/w/../w/x" >> "$sb/.agent/projects.local"
    echo "tools.sh single_project $sb/tools" >> "$sb/.agent/projects.local"
    echo "kit.SH single_project $sb/kit" >> "$sb/.agent/projects.local"
    echo "box.sH single_project $sb/box" >> "$sb/.agent/projects.local"
    # Shell: entries as name|type|path|fields, then errors without the file prefix.
    shell_out="$( { reg "$sb" registry_entries_full "$sb" 2>/dev/null | tr '\t' '|' || true; echo "--errors--"; reg "$sb" registry_entries_full "$sb" 2>&1 >/dev/null | sed -E 's/^ERROR: [^:]+:([0-9]+): /\1: /' || true; } )"
    # Python: the same shape from read_projects_registry.
    py_out="$(cd "$sb/.agent/scripts/lib" && python3 -c "
import workspace
entries, errors = workspace.read_projects_registry('$sb')
for e in entries:
    fields = ' '.join(f'{k}={v}' for k, v in e['fields'].items())
    print(f\"{e['name']}|{e['type']}|{e['path']}|{fields}\")
print('--errors--')
for err in errors:
    print(err.split(':', 1)[1].lstrip() if err.startswith('$sb') else err)
")"
    if [[ "$shell_out" != "$py_out" ]]; then
        echo "  --- parser diff (shell < > python) ---"
        diff <(printf '%s\n' "$shell_out") <(printf '%s\n' "$py_out") | sed 's/^/    /' || true
    fi
    assert_eq "identical entries and errors from both parsers" "$shell_out" "$py_out"
    assert_contains "the comparison covered the '..' escape" "for 'climb' must lie under" "$shell_out"
    assert_contains "the comparison covered the alias collision" "'r2' resolves to $sb/real2" "$shell_out"
    assert_contains "the comparison kept the in-root '..' override" "w|single_project|$sb/w|worktrees=$sb/w/x" "$shell_out"
    assert_contains "the comparison covered a name ending in .sh" "invalid project name 'tools.sh': a name may not end in '.sh'" "$shell_out"
    assert_not_contains "neither parser keeps the .sh name" "tools.sh|" "$py_out"
    assert_contains "the comparison covered an upper-case .SH" "invalid project name 'kit.SH': a name may not end in '.sh', in any letter case" "$shell_out"
    assert_contains "the comparison covered a mixed-case .sH, naming project 'box'" "legacy .agent/projects.d/<name>.sh of project 'box')" "$shell_out"
    assert_not_contains "neither parser keeps a mixed-case name" "kit.SH|" "$py_out"
}

test_worktree_create_parent_default_instance() {
    echo "TEST: worktree_create --project <parent> uses the default instance"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_parent_layout "$sb" p11-rolling
    seed_commit "$sb/p11-ng/rolling"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 996 --type project --project p11 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "announces the instance" "Using instance 'p11-rolling' of 'p11'" "$out"
    assert_eq "worktree keyed by the instance name" \
        "yes" "$([ -d "$sb/p11-ng/rolling/worktrees/issue-p11-rolling-996" ] && echo yes || echo no)"
}

test_worktree_parent_round_trip() {
    echo "TEST: create/enter/remove --project <parent> all resolve to the same instance"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    make_parent_layout "$sb" p11-rolling
    seed_commit "$sb/p11-ng/rolling"
    (cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 994 --type project --project p11 >/dev/null 2>&1) || rc=$?
    assert_eq "create exit 0" "0" "$rc"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_enter.sh" --issue 994 --type project --project p11 --print-path 2>&1)" || rc=$?
    assert_eq "enter --project parent finds the instance worktree" "$sb/p11-ng/rolling/worktrees/issue-p11-rolling-994" "$out"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_remove.sh" --issue 994 --type project --project p11 --force 2>&1)" || rc=$?
    assert_eq "remove --project parent exit 0" "0" "$rc"
    assert_eq "worktree gone" "no" "$([ -d "$sb/p11-ng/rolling/worktrees/issue-p11-rolling-994" ] && echo yes || echo no)"
}

test_worktree_create_parent_not_autoselected() {
    echo "TEST: worktree_create without --project never auto-selects a parent root"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    mkdir -p "$sb/one"
    printf 'p project %s/one\nonly single_project %s/one/a parent=p\n' "$sb" "$sb" > "$sb/.agent/projects.local"
    make_git_repo "$sb/one/a" "file:///nonexistent/a.git"
    seed_commit "$sb/one/a"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 995 --type project 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "auto-selects the instance, not the parent" "Using registered project 'only'" "$out"
}

test_worktree_create_ignores_project_checkout() {
    echo "TEST: worktree_create --type project with only a project/ checkout and nothing registered refuses (issue #265 part 4)"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    make_git_repo "$sb/project" "file:///nonexistent/legacyrepo.git"
    seed_commit "$sb/project"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 993 --type project 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names the cwd and the registration script" \
        "no registered project here (cwd $sb), and none is registered. Register one: .agent/scripts/register_project.sh <path>" "$out"
    assert_eq "nothing created under the retired location" \
        "no" "$([ -e "$sb/worktrees/project" ] && echo yes || echo no)"
    assert_eq "no branch made in the project/ checkout" \
        "false" "$(git -C "$sb/project" show-ref --verify --quiet refs/heads/feature/issue-993 && echo true || echo false)"
}

test_worktree_create_uses_registered_root_not_project_checkout() {
    echo "TEST: with a project/ checkout and one registered project, worktree_create uses the registered root (issue #265 part 4)"
    local sb out rc=0 other
    sb="$(make_worktree_sandbox)"
    make_git_repo "$sb/project" "file:///nonexistent/myrepo.git"
    seed_commit "$sb/project"
    other="$(make_registered_project "$sb" myrepo)"
    seed_commit "$other"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 995 --type project 2>&1)" || rc=$?
    assert_eq "exit 0 (out: ${out:0:160})" "0" "$rc"
    assert_eq "worktree created under the registered project's root" \
        "yes" "$([ -d "$other/worktrees/issue-myrepo-995" ] && echo yes || echo no)"
    assert_eq "nothing created under the retired location" \
        "no" "$([ -e "$sb/worktrees/project" ] && echo yes || echo no)"
    assert_eq "the project/ checkout is not touched" \
        "false" "$(git -C "$sb/project" show-ref --verify --quiet refs/heads/feature/issue-995 && echo true || echo false)"
}

test_worktree_create_several_registered_needs_a_name() {
    echo "TEST: worktree_create --type project with several registered and no --project refuses and lists them; from inside one root it uses that root"
    local sb out rc=0 a
    sb="$(make_worktree_sandbox)"
    make_git_repo "$sb/project" "file:///nonexistent/legacyrepo.git"
    seed_commit "$sb/project"
    a="$(make_registered_project "$sb" alpha)"
    seed_commit "$a"
    make_registered_project "$sb" beta >/dev/null
    make_registered_project "$sb" gamma >/dev/null
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 996 --type project 2>&1)" || rc=$?
    assert_eq "from the workspace root: exit 1" "1" "$rc"
    assert_contains "lists the registered names and --project" \
        "no registered project here (cwd $sb). Registered: alpha, beta, gamma. Pass --project <name> or register one: .agent/scripts/register_project.sh <path>" "$out"
    rc=0
    out="$(cd "$a" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 996 --type project 2>&1)" || rc=$?
    assert_eq "from inside alpha's root: exit 0 (out: ${out:0:160})" "0" "$rc"
    assert_eq "the worktree is alpha's" "yes" "$([ -d "$a/worktrees/issue-alpha-996" ] && echo yes || echo no)"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 997 --type project --project nosuch 2>&1)" || rc=$?
    assert_eq "--project <unregistered>: exit 1" "1" "$rc"
    assert_contains "--project <unregistered>: names it" "project 'nosuch' is not registered" "$out"
}

test_worktree_scripts_cwd_in_worktrees_override() {
    echo "TEST: create, enter, remove and wt_resolve_project_repo_root take the root a cwd is in, by its worktrees= dir too (review suggestion)"
    local sb out rc=0 a wtd
    sb="$(make_worktree_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    a="$sb/roots/alpha"
    make_git_repo "$a" "file:///nonexistent/alpha.git"
    seed_commit "$a"
    echo "alpha single_project $a worktrees=wt/alpha" >> "$sb/.agent/projects.local"
    make_registered_project "$sb" beta >/dev/null
    make_registered_project "$sb" gamma >/dev/null
    mkdir -p "$sb/wt/alpha" "$sb/projects/beta/worktrees"
    wtd="$(cd "$sb/wt/alpha" && pwd -P)"
    out="$(cd "$wtd" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 501 --type project 2>&1)" || rc=$?
    assert_eq "create from alpha's worktrees= dir: exit 0 (out: ${out:0:200})" "0" "$rc"
    assert_not_contains "create: never 'no registered project here'" "no registered project here" "$out"
    assert_eq "create: the worktree is alpha's" "yes" "$([ -d "$wtd/issue-alpha-501" ] && echo yes || echo no)"
    rc=0
    out="$(cd "$wtd/issue-alpha-501" && wt "$sb" wt_resolve_project_repo_root "$sb" 2>&1)" || rc=$?
    assert_eq "wt_resolve_project_repo_root from the worktree: exit 0" "0" "$rc"
    assert_eq "wt_resolve_project_repo_root from the worktree: alpha's root" "$a" "$out"
    rc=0
    out="$(cd "$wtd" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_enter.sh" --issue 501 --type project --print-path 2>&1)" || rc=$?
    assert_eq "enter from alpha's worktrees= dir: exit 0 (out: ${out:0:200})" "0" "$rc"
    assert_contains "enter: alpha's worktree, not 'Multiple projects'" "$wtd/issue-alpha-501" "$out"
    rc=0
    out="$(cd "$a" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_enter.sh" --issue 501 --type project --print-path 2>&1)" || rc=$?
    assert_eq "enter from alpha's hosting dir: exit 0 (out: ${out:0:200})" "0" "$rc"
    rc=0
    out="$(cd "$wtd" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_remove.sh" --issue 501 --type project --force 2>&1)" || rc=$?
    assert_eq "remove from alpha's worktrees= dir: exit 0 (out: ${out:0:200})" "0" "$rc"
    assert_eq "remove: the worktree is gone" "no" "$([ -d "$wtd/issue-alpha-501" ] && echo yes || echo no)"
    # --type omitted: a cwd in alpha's worktrees= dir (inside the workspace
    # tree) derives --type project --project alpha, not workspace (review
    # round 2, suggestion 1).
    rc=0
    out="$(cd "$wtd" && wt "$sb" registry_derive_type_from_dir "$sb" "$wtd" 2>&1)" || rc=$?
    assert_eq "derive from alpha's worktrees= dir: project alpha" "$(printf 'project\talpha')" "$out"
    rc=0
    out="$(cd "$wtd" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 502 2>&1)" || rc=$?
    assert_eq "create with --type omitted from alpha's worktrees= dir: exit 0 (out: ${out:0:200})" "0" "$rc"
    assert_contains "create: derived --type project --project alpha" "derived --type project --project alpha" "$out"
    assert_eq "create: alpha's worktree, not a workspace one" "yes|no" \
        "$([ -d "$wtd/issue-alpha-502" ] && echo yes || echo no)|$(ls -d "$sb"/worktrees/workspace/*502* >/dev/null 2>&1 && echo yes || echo no)"
    rc=0
    out="$(cd "$wtd" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_enter.sh" --issue 502 --print-path 2>&1)" || rc=$?
    assert_eq "enter with --type omitted: exit 0 (out: ${out:0:200})" "0" "$rc"
    assert_contains "enter with --type omitted: alpha's worktree" "$wtd/issue-alpha-502" "$out"
}

test_malformed_registry_fails_closed_for_legacy_enumeration_and_remove() {
    echo "TEST: a malformed registry makes project removal and listing refuse, never list or delete on partial state"
    local sb out rc=0
    sb="$(make_worktree_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    make_registered_project "$sb" foo >/dev/null
    mkdir -p "$sb/projects/foo/worktrees"
    git -C "$sb/projects/foo" worktree add -q "$sb/projects/foo/worktrees/issue-foo-43" -b feature/issue-43 >/dev/null 2>&1
    echo "junk" >> "$sb/.agent/projects.local"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_remove.sh" --issue 43 --type project --project foo --force 2>&1)" || rc=$?
    assert_eq "worktree_remove refuses (non-zero)" "true" "$([ "$rc" -ne 0 ] && echo true || echo false)"
    assert_eq "names the malformed registry" "1" "$(grep -c 'registry is malformed' <<< "$out")"
    assert_eq "worktree untouched" "yes" "$([ -d "$sb/projects/foo/worktrees/issue-foo-43" ] && echo yes || echo no)"
    # worktree_list.sh: warns and says NOT LISTED instead of silently "0 project worktrees"
    cp "$REAL_ROOT/.agent/scripts/worktree_list.sh" "$sb/.agent/scripts/"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_list.sh" 2>&1)" || rc=$?
    assert_eq "worktree_list exit 0 (read-only)" "0" "$rc"
    assert_eq "worktree_list warns about the malformed registry" "1" "$(grep -c 'registry (.agent/projects.local) is malformed' <<< "$out")"
    assert_eq "worktree_list summary says NOT LISTED, not a count of 0" "1" "$(grep -c 'Project worktrees:   NOT LISTED' <<< "$out")"
    # a pre-#25 project/worktrees entry must not be shown either (detail vs summary would contradict)
    mkdir -p "$sb/project/worktrees/issue-foo-99"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_list.sh" 2>&1)" || true
    assert_eq "no [project] entries at all while the registry is malformed" "0" "$(grep -c '^\[project\]' <<< "$out")"
    # workspace worktrees stay visible
    mkdir -p "$sb/worktrees/workspace/issue-workspace-42"
    git -C "$sb" worktree add -q "$sb/worktrees/workspace/issue-workspace-42" -b feature/issue-42 >/dev/null 2>&1
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_list.sh" 2>&1)" || true
    assert_eq "workspace worktree still listed alongside the warning" "1" "$(grep -c '^\[workspace\] Issue #42' <<< "$out")"
    # --json carries the state in the document: project null + flag, not a silent 0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_list.sh" --json 2>/dev/null)" || true
    assert_eq "--json: summary.project is null" "null" "$(jq -r '.summary.project' <<< "$out")"
    assert_eq "--json: summary.registry_malformed is true" "true" "$(jq -r '.summary.registry_malformed' <<< "$out")"
    assert_eq "--json: workspace count still 1" "1" "$(jq -r '.summary.workspace' <<< "$out")"
}

test_worktree_create_outoftree_root_exclusion() {
    echo "TEST: worktree_create under a registered root OUTSIDE the sandbox's own tree writes .git/info/exclude, idempotently"
    local sb outside out rc=0
    sb="$(make_worktree_sandbox)"
    # Sibling of the per-test sandbox under $SANDBOX, never a child of it:
    # the point of this dir is to sit outside the sandbox workspace root.
    outside="$(mktemp -d -p "$SANDBOX")"
    make_registered_project "$sb" faraway "$outside/faraway"
    seed_commit "$outside/faraway"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 111 --type project --project faraway 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "worktree created under the out-of-tree root's own worktrees/ dir" \
        "yes" "$([ -d "$outside/faraway/worktrees/issue-faraway-111" ] && echo yes || echo no)"
    assert_eq "exclude line written" \
        "1" "$(grep -cxF 'worktrees/' "$outside/faraway/.git/info/exclude" 2>/dev/null || echo 0)"
    assert_eq "git status in the root is clean (worktrees/ excluded)" \
        "" "$(git -C "$outside/faraway" status --porcelain --ignored=no 2>/dev/null)"

    # A second worktree in the same root must not duplicate the exclude line.
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 112 --type project --project faraway 2>&1)" || rc=$?
    assert_eq "second create exit 0" "0" "$rc"
    assert_eq "exclude file still has exactly one 'worktrees/' line (idempotent)" \
        "1" "$(grep -cxF 'worktrees/' "$outside/faraway/.git/info/exclude")"
}

test_wt_ensure_exclusion_is_type_agnostic() {
    echo "TEST: wt_ensure_exclusion writes only the exclude line for a ros2_colcon root — no type-specific marker (ADR-0012: that is the adapter's worktree_env job)"
    local sb rc=0
    sb="$(make_worktree_sandbox)"
    make_registered_project "$sb" p11colcon >/dev/null
    sed -i'' -e "s|^p11colcon single_project|p11colcon ros2_colcon|" "$sb/.agent/projects.local"
    wt "$sb" wt_ensure_exclusion "$sb" p11colcon || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "no COLCON_IGNORE written by the generic helper" \
        "no" "$([ -e "$sb/projects/p11colcon/worktrees/COLCON_IGNORE" ] && echo yes || echo no)"
    assert_eq "exclude line written (it's a git repo)" \
        "1" "$(grep -cxF 'worktrees/' "$sb/projects/p11colcon/.git/info/exclude" 2>/dev/null || echo 0)"
    assert_eq "helper source compares no project-type string literal" \
        "0" "$(grep -c '"ros2_colcon"' "$sb/.agent/scripts/_worktree_helpers.sh")"

    # Idempotent: calling again must not duplicate the exclude line.
    rc=0
    wt "$sb" wt_ensure_exclusion "$sb" p11colcon || rc=$?
    assert_eq "second call exit 0" "0" "$rc"
    assert_eq "exclude line still appears exactly once" \
        "1" "$(grep -cxF 'worktrees/' "$sb/projects/p11colcon/.git/info/exclude")"
}

test_retired_worktree_locations_not_found() {
    echo "TEST: a worktree under a retired location (worktrees/project/<n>/, project/worktrees/) is not counted, listed, entered or removed (issue #265 part 4)"
    local sb out rc=0 twt
    sb="$(make_worktree_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_list.sh" "$sb/.agent/scripts/"
    make_registered_project "$sb" later >/dev/null
    twt="$sb/worktrees/project/later/issue-later-42"
    mkdir -p "$(dirname "$twt")"
    git -C "$sb/projects/later" worktree add -q "$twt" -b feature/issue-42 >/dev/null 2>&1
    mkdir -p "$sb/project/worktrees/issue-later-42" "$sb/.workspace-worktrees/issue-workspace-42"
    assert_eq "fixture: retired-location worktree exists" "yes" "$([ -d "$twt" ] && echo yes || echo no)"
    assert_eq "not counted" "0" "$(wt "$sb" wt_count_project_worktrees "$sb")"
    assert_eq "not enumerated" "" "$(wt "$sb" wt_registry_worktree_dirs "$sb")"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_list.sh" 2>&1)" || true
    assert_eq "not listed" "0" "$(grep -c '^\[project\]' <<< "$out")"
    assert_not_contains "no retired location in the listing" "worktrees/project" "$out"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" bash -c 'source "$1/.agent/scripts/worktree_enter.sh" --issue 42 --type project --project later' _ "$sb" 2>&1)" || rc=$?
    assert_eq "enter --project later: not found (non-zero)" "true" "$([ "$rc" -ne 0 ] && echo true || echo false)"
    assert_contains "enter says no worktree" "No project worktree found for issue #42" "$out"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_remove.sh" --issue 42 --type project --project later --force 2>&1)" || rc=$?
    assert_eq "remove --project later: exit 1" "1" "$rc"
    assert_contains "remove says no worktree" "No project worktree found for issue #42" "$out"
    assert_eq "the worktree is untouched" "yes" "$([ -d "$twt" ] && echo yes || echo no)"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" bash -c 'source "$1/.agent/scripts/worktree_enter.sh" --issue 42 --type project --project nosuch' _ "$sb" 2>&1)" || rc=$?
    assert_eq "enter --project <unregistered>: refused" "true" "$([ "$rc" -ne 0 ] && echo true || echo false)"
    assert_contains "enter names the unregistered project" "project 'nosuch' is not registered" "$out"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_remove.sh" --issue 42 --type project --project nosuch --force 2>&1)" || rc=$?
    assert_eq "remove --project <unregistered>: exit 1" "1" "$rc"
    assert_contains "remove names the unregistered project" "project 'nosuch' is not registered" "$out"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_list.sh" --json 2>/dev/null)" || true
    assert_eq "list --json: no project worktree" "0" "$(jq -r '.summary.project' <<< "$out")"
}

test_worktree_remove_unresolvable_owner_removes_nothing() {
    echo "TEST: worktree_remove resolves every entry's owner first; one it cannot resolve removes nothing (plan S2)"
    local sb out rc=0 wt origin_a
    sb="$(make_worktree_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_list.sh" "$sb/.agent/scripts/"
    make_registered_project "$sb" agg >/dev/null
    origin_a="$sb/origins/pkg_a"
    make_git_repo "$origin_a" "file:///nonexistent/pkg_a.git"
    seed_commit "$origin_a"
    wt="$sb/projects/agg/worktrees/issue-agg-owner-pkg_a-77"
    mkdir -p "$wt/l1_ws/src"
    git -C "$origin_a" worktree add -q "$wt/l1_ws/src/pkg_a" -b feature/issue-77 >/dev/null 2>&1
    # The second entry exists but is not a git worktree: its owner cannot be
    # resolved, and there is no project/ checkout to fall back on.
    mkdir -p "$wt/l1_ws/src/pkg_b"
    {
        printf '# project=agg issue=owner/pkg_a#77 layer=l1\n'
        printf '%s\t%s\t%s\n' "$origin_a" "l1_ws/src/pkg_a" "feature/issue-77"
        printf '%s\t%s\t%s\n' "$sb/origins/pkg_b" "l1_ws/src/pkg_b" "feature/issue-77"
    } > "$wt/.worktree-repos"
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_remove.sh" --issue owner/pkg_a#77 --type project --project agg --force 2>&1)" || rc=$?
    assert_eq "exit 1" "1" "$rc"
    assert_contains "names the entry whose owner is unknown" "cannot resolve the repository that owns $wt/l1_ws/src/pkg_b; nothing was removed" "$out"
    assert_eq "the first entry is still a worktree" "yes" "$([ -d "$wt/l1_ws/src/pkg_a" ] && git -C "$origin_a" worktree list | grep -qF "$wt/l1_ws/src/pkg_a" && echo yes || echo no)"
    assert_eq "the aggregate dir is kept" "yes" "$([ -f "$wt/.worktree-repos" ] && echo yes || echo no)"
    assert_not_contains "never advises --path, which refuses the same entry (review suggestion)" "--path" "$out"
    assert_contains "advises deleting the entry by hand, then running again" "delete it by hand (rm -r $wt/l1_ws/src/pkg_b), then run this command again" "$out"
    # Following the advice works: the entry gone, the removal goes through.
    rm -r "$wt/l1_ws/src/pkg_b"
    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" "$sb/.agent/scripts/worktree_remove.sh" --issue owner/pkg_a#77 --type project --project agg --force 2>&1)" || rc=$?
    assert_eq "after the advised deletion: exit 0 (out: ${out:0:200})" "0" "$rc"
    assert_eq "after the advised deletion: the first entry is no longer a worktree" "no" "$(git -C "$origin_a" worktree list | grep -qF "$wt/l1_ws/src/pkg_a" && echo yes || echo no)"
}

test_wt_ensure_exclusion_noop_for_unregistered() {
    echo "TEST: wt_ensure_exclusion is a no-op for an unregistered project name"
    local sb rc=0
    sb="$(make_worktree_sandbox)"
    make_git_repo "$sb/project" "file:///nonexistent/legacyrepo.git"
    local before after
    before="$(cat "$sb/project/.git/info/exclude" 2>/dev/null || true)"
    wt "$sb" wt_ensure_exclusion "$sb" legacyrepo || rc=$?
    assert_eq "exit 0 (silent no-op)" "0" "$rc"
    after="$(cat "$sb/project/.git/info/exclude" 2>/dev/null || true)"
    assert_eq "exclude file untouched for an unregistered project" "$before" "$after"
}

test_registry_worktree_enumeration_for_dashboard() {
    echo "TEST: wt_registry_worktree_dirs / wt_count_project_worktrees enumerate an out-of-tree registered root (dashboard.sh's own enumeration function)"
    local sb outside rc=0 out
    sb="$(make_worktree_sandbox)"
    # Sibling of the per-test sandbox under $SANDBOX, never a child of it:
    # the point of this dir is to sit outside the sandbox workspace root.
    outside="$(mktemp -d -p "$SANDBOX")"
    make_registered_project "$sb" gz4d "$outside/gz4d"
    seed_commit "$outside/gz4d"

    # Before any worktree exists, the root's worktree dir isn't there yet —
    # enumeration returns nothing for it (dashboard.sh must not crash or
    # miscount on a freshly-registered, never-worktreed root).
    out="$(wt "$sb" wt_registry_worktree_dirs "$sb")" || rc=$?
    assert_eq "no entries before any worktree exists" "" "$out"
    assert_eq "count is 0" "0" "$(wt "$sb" wt_count_project_worktrees "$sb")"

    (cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 222 --type project --project gz4d >/dev/null 2>&1)
    out="$(wt "$sb" wt_registry_worktree_dirs "$sb")"
    assert_eq "enumerates the out-of-tree root by name and worktree dir" \
        "gz4d	$outside/gz4d/worktrees" "$out"
    assert_eq "count reflects the one worktree just created" \
        "1" "$(wt "$sb" wt_count_project_worktrees "$sb")"
}

test_merge_pr_finds_worktree_under_registered_root() {
    echo "TEST: worktree_remove.sh (as merge_pr.sh drives it) finds a worktree under an out-of-tree registered root"
    local sb outside out rc=0
    sb="$(make_worktree_sandbox)"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_list.sh" "$sb/.agent/scripts/"
    # Sibling of the per-test sandbox under $SANDBOX, never a child of it:
    # the point of this dir is to sit outside the sandbox workspace root.
    outside="$(mktemp -d -p "$SANDBOX")"
    make_registered_project "$sb" faraway2 "$outside/faraway2"
    seed_commit "$outside/faraway2"
    (cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 333 --type project --project faraway2 >/dev/null 2>&1)
    assert_eq "worktree exists under the out-of-tree root" \
        "yes" "$([ -d "$outside/faraway2/worktrees/issue-faraway2-333" ] && echo yes || echo no)"

    # wt_resolve_project_repo_root (used by merge_pr.sh) must resolve the
    # registered root, not the (nonexistent) legacy project/ symlink.
    out="$(wt "$sb" wt_resolve_project_repo_root "$sb" faraway2)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "resolves to the out-of-tree checkout" "$outside/faraway2" "$out"

    rc=0
    out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_remove.sh" --issue 333 --type project --project faraway2 --force 2>&1)" || rc=$?
    assert_eq "remove exit 0" "0" "$rc"
    assert_eq "worktree removed from under the out-of-tree root" \
        "no" "$([ -d "$outside/faraway2/worktrees/issue-faraway2-333" ] && echo yes || echo no)"
}

# Helper invocation SKILL.md's review-plan `--issue <N>` fallback
# prescribes: enumerate every root's worktree dir via
# wt_registry_worktree_dirs, and glob each for
# issue-*-<issue>/.agent/work-plans/issue-<issue>/plan.md. Defined at file
# scope (not inline in the test) so `wt` — which runs its command in the
# same sourced subshell rather than a fresh process — can call it directly.
# Usage: _review_plan_find_plan <root_dir> <issue>
_review_plan_find_plan() {
    local root_dir="$1" issue="$2" name wtdir plan found=""
    while IFS=$'\t' read -r name wtdir; do
        for plan in "$wtdir"/issue-*-"$issue"/.agent/work-plans/issue-"$issue"/plan.md; do
            [ -f "$plan" ] && { found="$plan"; break 2; }
        done
    done < <(wt_registry_worktree_dirs "$root_dir")
    echo "$found"
}

# review-plan's SKILL.md `--issue <N>` fallback prescribes enumerating
# wt_registry_worktree_dirs and globbing each for
# issue-*-<N>/.agent/work-plans/issue-<N>/plan.md (issue #273 round-1
# review — the fallback used to only glob the legacy
# worktrees/project/*/issue-*-<N>/ path, which can never see a project
# worktree under a registered out-of-tree root). SKILL.md is prose, so this
# test exercises the helper invocation it prescribes (_review_plan_find_plan
# above) rather than parsing the doc.
test_review_plan_issue_fallback_finds_plan_under_registered_root() {
    echo "TEST: review-plan's --issue <N> fallback (wt_registry_worktree_dirs) finds a plan file under a registered out-of-tree root"
    local sb outside rc=0 out
    sb="$(make_worktree_sandbox)"
    # Sibling of the per-test sandbox under $SANDBOX, never a child of it:
    # the point of this dir is to sit outside the sandbox workspace root.
    outside="$(mktemp -d -p "$SANDBOX")"
    make_registered_project "$sb" faraway3 "$outside/faraway3"
    seed_commit "$outside/faraway3"
    (cd "$sb" && PATH="$sb/stubbin:$PATH" \
        "$sb/.agent/scripts/worktree_create.sh" --allow-unverified-branch --issue 444 --type project --project faraway3 >/dev/null 2>&1)
    local plan_dir="$outside/faraway3/worktrees/issue-faraway3-444/.agent/work-plans/issue-444"
    mkdir -p "$plan_dir"
    echo "plan body" > "$plan_dir/plan.md"

    out="$(wt "$sb" _review_plan_find_plan "$sb" 444)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "finds the plan file under the registered out-of-tree root" \
        "$plan_dir/plan.md" "$out"
}

# ---- Run all tests ----
echo "=== project registry / multi-tenant hosting tests ==="
echo ""

test_registry_absent_is_legacy
test_registry_malformed_line_fails
test_registry_repo_slugs
test_registry_repo_slugs_no_walk_up
test_registry_repo_slugs_absent_or_broken
test_main_checkout_helpers
test_main_checkout_fallback_messages
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
test_project_command_source_file_only
test_sync_project_root
test_validate_registry_only
test_validate_missing_checkout
test_validate_unknown_type
test_validate_malformed_registry
test_validate_legacy_still_works
test_validate_neither_shape
test_validate_registered_no_legacy_verbose
test_validate_entry_path_missing_no_legacy
test_validate_ros2_colcon_entry_without_git_passes
test_validate_ros2_colcon_failure_prefixes_every_line
test_validate_parse_error_does_not_blame_healthy_entry
test_validate_parse_error_verbose_says_shape_not_checked
test_validate_adapter_timeout
test_validate_adapter_failure_stdout_fallback
test_validate_interrupt_kills_adapter
test_validate_nested_non_git_entry_fails
test_single_project_scoped_validate_ignores_broken_sibling
test_single_project_scoped_validate_nested_dir_fails
test_single_project_legacy_validate
test_worktree_create_unknown_repo
test_worktree_create_registry_repo
test_worktree_create_skill_project
test_worktree_create_single_registry_autoselect
test_worktree_create_dashed_name_roundtrip
test_worktree_create_repo_alias
test_worktree_create_single_repo_no_manifest_file
test_worktree_create_multiple_requires_repo
test_registry_fields_parse
test_registry_pathless_entry_fails
test_registry_no_project_message
test_registry_fields_rejected
test_registry_parent_rules
test_registry_instances_and_default
test_registry_worktree_dir
test_registry_require_root
test_adapter_parent_resolves_instance
test_adapter_parent_ambiguous_fails
test_adapter_registry_distro_and_role_exported
test_validate_parent_root
test_validate_python_parser_matches_shell
test_worktree_create_parent_default_instance
test_worktree_parent_round_trip
test_worktree_create_parent_not_autoselected
test_worktree_create_ignores_project_checkout
test_worktree_create_uses_registered_root_not_project_checkout
test_worktree_create_several_registered_needs_a_name
test_worktree_scripts_cwd_in_worktrees_override
test_malformed_registry_fails_closed_for_legacy_enumeration_and_remove
test_worktree_create_outoftree_root_exclusion
test_wt_ensure_exclusion_is_type_agnostic
test_retired_worktree_locations_not_found
test_worktree_remove_unresolvable_owner_removes_nothing
test_wt_ensure_exclusion_noop_for_unregistered
test_registry_worktree_enumeration_for_dashboard
test_merge_pr_finds_worktree_under_registered_root

# --------------------------------------------------------------------------
# registry_derive_type_from_dir (#317): the cwd-derived --type/--project that
# makes --type optional on the worktree scripts.
# --------------------------------------------------------------------------
test_derive_type_from_dir() {
    echo ""
    echo "--- registry_derive_type_from_dir ---"
    local sb alpha beta
    sb="$(make_sandbox)"
    alpha="$(make_registered_project "$sb" alpha "$sb/roots/alpha")"
    beta="$(make_registered_project "$sb" beta "$sb/roots/beta")"

    assert_eq "a registered root derives project + its name" \
        "project	alpha" "$(reg "$sb" registry_derive_type_from_dir "$sb" "$alpha")"

    mkdir -p "$beta/src/deep"
    assert_eq "a directory inside a registered root derives that project" \
        "project	beta" "$(reg "$sb" registry_derive_type_from_dir "$sb" "$beta/src/deep")"

    assert_eq "the workspace checkout derives workspace, with no project" \
        "workspace	" "$(reg "$sb" registry_derive_type_from_dir "$sb" "$sb")"

    mkdir -p "$sb/worktrees/workspace/issue-workspace-1"
    assert_eq "a workspace worktree derives workspace" \
        "workspace	" "$(reg "$sb" registry_derive_type_from_dir "$sb" "$sb/worktrees/workspace/issue-workspace-1")"

    # Neither: an unrelated directory outside the workspace and every root.
    local outside
    outside="$(mktemp -d -p "$SANDBOX")"
    local out rc=0
    out="$(reg "$sb" registry_derive_type_from_dir "$sb" "$outside" 2>/dev/null)" || rc=$?
    if [[ "$rc" -eq 1 && -z "$out" ]]; then
        echo "  PASS: an unrelated directory derives nothing (return 1)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: an unrelated directory derived '$out' (rc=$rc)"
        FAIL=$((FAIL + 1))
    fi

    # A project registered INSIDE the workspace tree is still a project:
    # registered roots are checked before the workspace-checkout branch.
    local inner
    inner="$(make_registered_project "$sb" inner "$sb/inner")"
    assert_eq "a project registered inside the workspace tree still derives project" \
        "project	inner" "$(reg "$sb" registry_derive_type_from_dir "$sb" "$inner")"
}


test_source_combination_table() {
    echo "TEST: _project_source_combination (#436): the source keys together, pure"
    local sb row entries want got rc
    sb="$(make_sandbox)"
    # entries (key<TAB>value lines, '|' between) => ok, or a fragment of the reason
    while IFS='=' read -r row want; do
        [ -n "$row" ] || continue
        entries="$(tr '|' '\n' <<< "$row" | sed 's/:/\t/')"
        rc=0; got="$(reg "$sb" _project_source_combination "$entries" demo)" || rc=$?
        if [ "$want" = ok ]; then
            assert_eq "accepted: $row" "0" "$rc"
        else
            assert_eq "refused: $row" "1" "$rc"
            assert_contains "says why: $row" "$want" "$got"
            assert_contains "names the three-key unset: $row" "unset demo source source_ref source_path" "$got"
        fi
    done <<'ROWS'
build:make=ok
source:/m.yaml=ok
source:https://h/m.git|source_ref:main=ok
source:https://h/m.git|source_ref:main|source_path:a/m.yaml=ok
source_ref:main=source_ref is only valid with source
source_path:m.yaml=source_path is only valid with source
source:https://h/m.git=source_ref (the branch, tag or commit to use) is required
source:/m.yaml|source_ref:main=so source_ref does not apply
source:/m.yaml|source_path:m.yaml=so source_path does not apply
source:/m.yaml|bootstrap_url:https://h/b.yaml=one source only
ROWS
}

test_dispatcher_exports_source_keys() {
    echo "TEST: the dispatcher hands source, source_ref, source_path and role/distro to the adapter (#436)"
    local sb proj out
    sb="$(make_sandbox)"
    mkdir -p "$sb/.agent/project_types/probe_type" "$sb/.agent/projects.d"
    cat > "$sb/.agent/project_types/probe_type/adapter.sh" <<'EOF2'
adapter_project_root() {
    echo "src=${ACTIVE_PROJECT_SOURCE}|ref=${ACTIVE_PROJECT_SOURCE_REF}|path=${ACTIVE_PROJECT_SOURCE_PATH}|role=${ACTIVE_PROJECT_ROLE}|distro=${ACTIVE_PROJECT_DISTRO}"
}
EOF2
    proj="$(mktemp -d -p "$SANDBOX")"
    echo "probe probe_type $proj role=dev distro=fakefox" > "$sb/.agent/projects.local"
    printf 'source=https://example.invalid/m.git\nsource_ref=v1\nsource_path=x/m.yaml\n' > "$sb/.agent/projects.d/probe"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project probe project_root 2>&1)"
    assert_eq "every value reaches the adapter" "src=https://example.invalid/m.git|ref=v1|path=x/m.yaml|role=dev|distro=fakefox" "$out"
    rm -f "$sb/.agent/projects.d/probe"
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project probe project_root 2>&1)"
    assert_eq "unset keys are empty" "src=|ref=|path=|role=dev|distro=fakefox" "$out"
    printf 'source_ref=v1\n' > "$sb/.agent/projects.d/probe"
    local rc=0
    out="$(cd "$sb" && "$sb/.agent/scripts/adapter" --project probe project_root 2>&1)" || rc=$?
    assert_eq "an invalid combination stops the dispatcher" "1" "$rc"
    assert_contains "and names the rule" "source_ref is only valid with source" "$out"
}


test_review_plan_issue_fallback_finds_plan_under_registered_root
test_derive_type_from_dir
test_source_combination_table
test_dispatcher_exports_source_keys

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
