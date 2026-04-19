---
issue: 151
---

# Issue #151 — _resolve_work_plans_dir.sh: mangled rule-3 error output and set -u unbound-variable check

## External Review
**Status**: complete
**When**: 2026-04-19
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #152 — 1 review (Copilot), 1 valid, 0 false positives
**CI**: all 8 checks pass

### Actions
- [x] Add `|| true` to `rc=` extraction (defensive; avoid pipeline failure killing the test suite) — `.agent/scripts/tests/test_resolve_work_plans_dir.sh:100`
