# How it works

Written last; see the change log.

# The design

This part of the file is the current picture of how the workspace's parts fit together, and it is the
authority for it (ADR-0017). A fact is in only if two parts could otherwise choose incompatibly, or a
newcomer cannot see it from the code; detail that belongs next to the code (a script header, a
document beside it) stays there and is linked, not copied. The file holds the current picture, the
ADRs in `docs/decisions/` hold the reasons and the history of each decision, and each issue's
`progress.md` holds that issue's history. A change that alters how the parts fit updates the matching
section here in the same change, so the file is checked at merge. Where this file and an ADR disagree,
this file wins; the Decision register says which ADRs still govern.

Every `##` section below has a `Now` block: what the code does today, each line followed by the
script, ADR or file it was checked against. A section has a `Target` block only where the target
differs from what is built. Each block opens with one `Status:` line taking exactly one of these five
values, and a block holds statements of one status. A question goes to Open questions with a pointer,
never into a block that claims a status. `Now` states only what the code does today; the one
exception is a part with nothing built, whose single block is labelled `Now` and carries `proposed`.
Each proposal inside a `Target` block starts with "Proposed:" and moves to `Now` in the change that
builds it.

| Status | Means |
|---|---|
| `decided` | An owner decision is on record, cited (ADR number or issue and date), and the code does it |
| `decided, not built` | Decided and cited; the code does not do it yet |
| `decided, not proven` | Decided and built, but the acceptance test has not run (ADR-0016 is Provisional until the `/run-issue` run from a project root in #317) |
| `proposed` | Agent or owner suggestion, not decided |
| `open` | A question, listed under Open questions. An `open` block holds only a pointer to where the question is tracked (an issue number or the Open questions row), no question text |

## Change log

One row per change to this file, appended in the same change that alters a section: date, section, one
line, issue, and the line count of the document after the change.

| Date | Section | Change | Issue | Lines |
|---|---|---|---|---|
| 2026-10-09 | Whole file | Skeleton. Rewrite starts from the plan's section table: `# How it works` is a stub (written last), `# The design` opens with the admission rule and the Status key, and everything the old file held that now lives next to the code is gone (destinations landed in #377) | #335 | 40 |
