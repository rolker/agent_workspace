---
name: test-engineering
description: Scaffold, debug, and analyze test coverage for project components. Supports multiple test frameworks (GTest, PyTest, Jest, cargo test, go test, etc.).
---

# Test Engineering

## Usage

```
/test-engineering [<component-path>]
```

If no path is given, operate on the component in the current directory.

## Overview

**Lifecycle position**: Utility — use after `audit-project` flags test gaps,
or when asked to "write tests", "add test coverage", "debug test failures",
or "scaffold tests".

Covers the full test development lifecycle for project components: identifying
coverage gaps, scaffolding test files, writing mock interfaces, and debugging
failures. References existing templates rather than embedding them.

## Test Types

| Type | Framework | When to Use | Template |
|------|-----------|-------------|----------|
| C++ unit tests | GTest | Testing functions, classes, algorithms in isolation | `.agent/templates/testing/gtest_template.cpp` |
| Python unit tests | PyTest | Testing Python logic, utilities, data processing | `.agent/templates/testing/pytest_template.py` |
| JavaScript/TypeScript | Jest / Vitest | Testing JS/TS modules and classes | `.agent/templates/testing/jest_template.ts` |
| Rust unit tests | cargo test | Testing Rust functions and modules | `.agent/templates/testing/rust_test_template.rs` |
| Go unit tests | go test | Testing Go functions and packages | `.agent/templates/testing/go_test_template.go` |
| Integration tests | language-appropriate | Testing multi-component interactions | `.agent/templates/testing/integration_template.*` |

## Procedures

### 1. Identify missing test coverage

**Trigger**: "What tests are missing?" or "Analyze test coverage"

1. **Scan component structure**:
   - Check for `test/` or `tests/` directory
   - List existing test files (files matching `*_test.*`, `test_*.*`, `*.test.*`, `*.spec.*`)
   - Identify modules/classes without corresponding tests

2. **Analyze code**:
   - List public APIs (classes, functions) in headers or modules
   - Identify interfaces, services, and handlers
   - Check for complex logic that needs validation

3. **Gap analysis**:
   - Compare code modules with test files
   - Identify untested components
   - Flag untested integration scenarios

4. **Report**:

```
Test Coverage Analysis for <component_name>:

Tested:
  - component_a (test/test_component_a.cpp)
  - utils module (test/test_utils.py)

Missing:
  - module_b (no unit tests)
  - ServiceHandler class (untested API)
  - Integration: component_a -> component_b interaction

Recommendation:
  1. Add test/test_module_b.cpp for unit tests
  2. Add test/test_integration.py for multi-component scenario
```

### 2. Scaffold new tests

**Trigger**: "Create tests for X" or "Scaffold test file"

Read the appropriate template from `.agent/templates/testing/` and adapt it:

#### C++ GTest

1. Create `test/test_<component>.cpp` using `gtest_template.cpp`
2. Update build system (e.g., `CMakeLists.txt` or `Makefile`):
   ```cmake
   # CMake example:
   if(BUILD_TESTING)
     find_package(GTest REQUIRED)
     add_executable(test_<component> test/test_<component>.cpp)
     target_link_libraries(test_<component> GTest::gtest_main <library_name>)
     add_test(NAME test_<component> COMMAND test_<component>)
   endif()
   ```
3. Update dependency manifest to add GTest as a test dependency

#### Python PyTest

1. Create `test/test_<module>.py` using `pytest_template.py`
2. Update dependency manifest:
   ```toml
   # pyproject.toml example:
   [project.optional-dependencies]
   test = ["pytest", "pytest-cov"]
   ```

#### JavaScript/TypeScript Jest

1. Create `test/<module>.test.ts` using `jest_template.ts`
2. Update `package.json`:
   ```json
   {
     "devDependencies": { "jest": "^29", "@types/jest": "^29" },
     "scripts": { "test": "jest" }
   }
   ```

#### Rust

1. Add test module at the bottom of the source file, or create `tests/<component>_test.rs`
2. Run with: `cargo test`

#### Go

1. Create `<component>_test.go` alongside the source file
2. Run with: `go test ./...`

#### Integration tests

1. Create `test/test_<scenario>.*` using the appropriate integration template
2. Integration tests should test interactions between multiple components
   with real (or realistic stub) dependencies

### 3. Debug test failures

**Trigger**: "Test X is failing" or "Debug this test"

#### Reproduce locally

**In a project worktree** (preferred), use the generated convenience scripts:

```bash
./<project>/build.sh
./<project>/test.sh
```

**Generic approach**:

```bash
# Python
cd project/<component> && python -m pytest test/ -v

# JavaScript/TypeScript
cd project/<component> && npm test

# Rust
cd project/<component> && cargo test -- --nocapture

# Go
cd project/<component> && go test ./... -v

# C++ with make
cd project/<component> && make test

# C++ with cmake
cd build && ctest --verbose
```

#### Identify failure type

| Type | Symptoms | Common Fix |
|------|----------|------------|
| Build failure | Missing dependencies, compile errors | Add missing test dependencies |
| Timeout | Test hangs, "timeout" in output | Increase timeout, check for deadlocks |
| Assertion failure | Expected vs actual mismatch | Fix logic or update expectations |
| Missing dependency | Import errors, module not found | Install/declare the missing dependency |
| Race condition | Flaky — passes sometimes, fails others | Use proper synchronization primitives |

#### Common fixes

- **Timeout**: Increase test timeouts for CI environments. Use
  explicit timeout parameters rather than relying on defaults.
- **Race conditions**: Use mutexes, channels, or condition variables —
  never `time.sleep()` or equivalent busy-waits.
- **Missing stubs/mocks**: Identify external dependencies and create
  test doubles that return predictable data.
- **Environment dependencies**: Ensure tests don't rely on system state,
  network access, or external services unless explicitly integration tests.

### 4. Write mock interfaces

**Trigger**: "Create a mock for X" or "Mock this dependency"

Common patterns for isolated testing:

- **Mock external service** (for testing clients): Create a stub that returns
  predetermined responses without hitting a real endpoint.
- **Mock data source** (for testing processors): Create a stub that yields
  known test data.
- **Mock output sink** (for testing producers): Create a recorder that
  captures output for assertion.

Keep mocks minimal — just enough to test the component under test. Prefer
language-native mocking libraries:
- Python: `unittest.mock`, `pytest-mock`
- JavaScript/TypeScript: Jest mocks, `vi.mock()` (Vitest)
- Go: interface-based mocks, `testify/mock`
- Rust: `mockall` crate

## References

- `.agent/templates/testing/gtest_template.cpp` — C++ unit test skeleton
- `.agent/templates/testing/pytest_template.py` — Python unit test skeleton
- `.agent/templates/testing/jest_template.ts` — JavaScript/TypeScript test skeleton
- `.agent/knowledge/documentation_verification.md` — Command cookbook for
  finding public APIs and interfaces (useful for test planning)

## Guidelines

- **Test one thing** — each test case validates one specific behavior.
- **Descriptive names** — `test_publisher_sends_correct_message_type()`.
- **Clean setup/teardown** — fresh state for each test.
- **No flaky tests** — don't rely on timing; use event-based synchronization.
- **Test edge cases** — empty inputs, boundary conditions, error states.
- **Mock external dependencies** — isolate the component under test.
- **Document test intent** — add docstrings/comments explaining what's being
  tested and why.
