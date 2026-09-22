## Summary

<!-- Brief description of what changed and why. -->

## Decision summary

<!-- The section the owner reads instead of the diff. Keep this exact
     heading: merge_pr.sh's review gate looks for "## Decision summary" on
     the PR (body or a comment) before merging. Same shape review-code
     produces. The gate is local to merge_pr.sh and enforced by default on
     workspace PRs (--report-only opts out); there is no server-side check
     yet (that is an Ask-First decision). -->

**What changed**: <1-3 sentences, plain language, no diff references>

**Reviews and outcomes**: <round/ship verdict if review-code; findings count and verdict if triage-reviews/integrated review>

**Open human calls**: <anything requiring a human decision, or "None">

**Verified**: <what was actually run/checked to confirm the above, e.g. "tests pass; grep confirmed X">

**Recommendation**: <merge / needs-work / hold, one line>

## Related issue

<!-- Link to the issue this PR addresses. -->
Closes #

## What changed

<!-- Bullet list of the key changes. -->

-

## Testing

<!-- How was this tested? make test, manual verification, etc. -->

-

## Documentation and test impact

<!-- Consider what else needs updating as a consequence of this change. -->

- [ ] No impact (no behavior, API, or interface changes)
- [ ] Impact considered (check all that apply below):
  - [ ] Tests added or updated
  - [ ] Documentation updated (README, `.agents/README.md`)
  - [ ] Dependent references updated

## Architecture impact

- [ ] No architecture impact (routine change within existing patterns)
- [ ] Architecture-relevant change (check all that apply below):
  - [ ] Modifies agent workflow or instruction files
  - [ ] Changes workspace structure or scripts

### If architecture-relevant:
- [ ] ARCHITECTURE.md updated (or confirmed still accurate)
- [ ] ADR created in `docs/decisions/` (if a new architectural decision)
