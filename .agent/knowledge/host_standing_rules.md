# Host Standing Rules

The owner's standing rules for a host session: the session that drives
issues through the review loop and talks to the owner. Every framework
reads this file (a Claude Code host loads it through `/orchestrator`; a
Codex or Gemini host follows it by hand). The rules apply in every root;
rules for one root only wait for the orchestrator design session
(issue 398, the orchestrator design log).

Each rule carries its reason. An outside audit of this pipeline
(2026-10-15) found that rules with reasons are followed by intent, and
rules without them only literally. A rule here without a reason is a
defect; `test_skill_paths.sh` fails on an empty reason cell.

A rule the owner gives in one session reaches no other session until it is
written down. So a new rule, or a veto that becomes one, is added here in
the same turn it is given, with his words as the reason, and the change
goes through a pull request like any other.

## Rules

| Rule | Reason | Source |
|---|---|---|
| The owner decides every merge. The host asks after posting the decision summary, then waits; a converged review and green CI are not his say. | He does not want to read pull request details but wants to keep the merge decision: reviews reduce what he reads, they do not replace his say (owner, 2026-09-16). On a project pull request the merge gate is report-only, so nothing but this rule stops a host merge there. | `docs/design.md`, Rules ("The owner decides every merge"); owner, 2026-09-16 |
| A merge happens only when everything is clean, unless the owner says a review or CI may be skipped for that merge. | "By default, a merge should only happen when everything is clean unless I say we can skip a review or CI." (owner, 2026-09-22) | Owner, 2026-09-22 |
| A review that comes back with open findings goes to the owner; the host never merges past it. In `/orchestrator`'s checkpoint table, `merge` at `findings` is his answer only. | "If a review comes back with issues, then don't merge, ask me first." (owner, 2026-09-22) | Owner, 2026-09-22 |
| `merge_pr.sh`'s relaxing flags (`--report-only`, `--no-wait`, `--allow-pending-review`, `--force-unreviewed`) are passed only when the owner said so for that merge. | Each one merges something the gate or the CI wait would have held; that is the skip only he can grant (rule above). | `run-issue/SKILL.md` step 11; owner, 2026-09-22 |
| During a drive the host does not edit repository files. Implement and fix passes go to background agents, with the owner's directions quoted in the handoff. The one exception is `takeover` at `phase-failed`, which only the owner answers, or his "do it yourself" for that step. | "One reason the run issue workflow uses background agents is so I can keep on interacting with the main agent while things are happening. Having you do the work might be faster, but I lose access to my orchestrator." (owner, 2026-09-22) | Owner, 2026-09-22; `dispatch_phase.sh` row 27 |
| The review-plan phase runs before any implementation, prototypes included. Under the 2026-10-15 contract the host may answer the `plan` checkpoint; the review itself is never skipped. | A prototype shipped with its plan, before review, and the review then found two security defects (2026-09-16): "Going forward, review the plan before implementing." | Owner, 2026-09-16; issue 321 body |
| Review depth: a second code-review round only when the first found a real defect (a must-fix); a third round is a narrow convergence check with no cross-model reviewers. The first half is the ship verdict's rule, written once in `review_progress.sh verdict` (review-code step 6): round 1 with no must-fix gives `ship=recommended`, with any must-fix `continue`. The second half is the owner's standing exception to review-code's fix-round rule (issue 320), written where that rule lives: `review_depth_classification.md`, "Round-3 convergence check", and review-code step 2. `dispatch_phase.sh` puts the scope (the prior round's findings and the fix diff) and the words "no cross-model reviewers" on a pre-push review-code task line at round 3 or later. | Each round costs about 20 to 25 minutes, and a convergence check re-reads only the fixes; external reviewers have already read the whole diff twice by then. | Issue 321 body ("Review depth follows the audit's rule"); the owner's 2026-10-15 audit is background only |
| Wall-clock time comes before token use: fewer serial rounds, no waits on things that will not arrive, a timeout of about twice the expected duration. | "I'm more concerned with time efficiency than usage efficiency since we are within usage budget." (owner, 2026-09-22) | Owner, 2026-09-22 |
| Near a stop time the owner named, no phase starts that cannot finish before it; a running phase within about 10 minutes of a clean commit is not stopped. A skipped launch is never silent: give the per-phase estimate and ask start or hold. | A phase killed at shutdown wastes its credit (2026-09-21); "Don't decide not to start stuff without asking me." (owner, 2026-09-24) | Owner, 2026-09-21, 09-22, 09-24 |
| Every issue or pull request number carries a plain-words label, every time it is mentioned. | "I don't remember issue numbers, so mentioning an issue number in a response without what it is leaves me asking questions like that." (owner, 2026-09-22) | Owner, 2026-09-22; his global status-line rule |
| At each checkpoint and hand-back, one line per outside reviewer (Gemini, Codex, Copilot): ran, failed or skipped, with the reason, and whether it found anything of substance. A "ran" that is suspiciously short is flagged. | A quota or permission failure costs coverage silently; showing it is the defence (trial started 2026-09-23, kept by the issue 321 hand-back shape). | Owner, 2026-09-23; issue 321 body |
| Anything the owner decides on is presented in the session, condensed to what changes his decision; a link is never the thing to read. | "I don't want to have to go read things on github, I want you to present it to me in the session in a concise way." (owner, 2026-09-17) | Owner, 2026-09-17 |
| A dialog or hand-back is never one dense paragraph: an orientation line, short labelled items, then the question; the text being decided is inside the dialog itself. | "next time make the question easier to read, not just an unformatted block of text" (owner, 2026-09-21); he does not reliably see the terminal above a dialog. | Owner, 2026-09-21, 10-08, 10-09 |
| A list the owner will refer back to uses bold stable IDs in bullets (`- **Q1** ...`), never a numbered list. | The terminal renumbers ordered lists, so his "item 3" and the host's differed (2026-09-25). | Owner, 2026-09-25 |
| When background agents report while the owner is away, each response is a line or two; results are held for one combined report. | Stacked responses are read out of order, and repeating full context in each was rejected the same day (2026-10-02). | Owner, 2026-10-02 |
| Before a design question, find and quote what `docs/design.md`, the ADRs and the roadmap already record, and ask only what they leave open. | "I had to answer a question that I'm sure was discussed in the redesign. Did the information get lost or just not consulted?" (owner, 2026-10-13) | Owner, 2026-10-13 |
| A question that changes the design is asked on its own, with what it changes, how hard it is to undo, a recommendation, and "not now" offered. | "Under pressure, it's easy to skim questions, accept the recommended answer without realizing the importance of the question." (owner, 2026-10-01) | Owner, 2026-10-01; principle "Ask about what matters, and show how much" |
| Text that states the owner's goals (README goals, the acceptance case, Direction lines, the Paths) is written from his quoted words with the smallest edit, and listed for his veto with the quote. No taglines or corporate polish. | Goals he accepted fastest were his own sentences; polish "makes it seem like this was written by a corporate department, or by AI, instead of a lone developer" (owner, 2026-09-25). | Owner, 2026-09-25; `/orchestrator` recipe (c) |
| Mechanism text (skills, scripts, templates, tests) names no project. Record text (roadmap Direction, change log, ADR history, work plans) may name a project whose repository is public, checked with `gh repo view <owner/repo> --json visibility`. Settled: not re-asked. | "we should not depend on a specific project as this workspace should be agnostic" (owner, 2026-07-14); an acceptance line is checkable only if it names the real project (owner, 2026-10-15); public only (owner, 2026-10-12). | Owner, 2026-07-14, 10-12, 10-15 |
| How another person's project differs from the workspace's expectations is worded as a working style the workspace accommodates, never as criticism. | "anything about the differences with this project and our expectations should be worded diplomatically, not as criticism" (owner, 2026-10-09) | Owner, 2026-10-09 |
| A veto becomes a rule in this table, with his words as the reason, in the same turn. | A rule given in one terminal is invisible to the other hosts until it is written where both read it (issue 321, field notes of 2026-09-22). | Issue 321 body and comments |
| Standing authorization: after each issue a `/orchestrator` session drives, it posts one signed comment on issue 398 (the orchestrator design log) with the four headings the skill gives. No other comment on another issue is covered. | The owner asked for the log until the design session (comment on issue 321, 2026-10-15): it is the evidence that session works from. | Owner, 2026-10-15 |

## Already enforced, so no rule text here

Written once, where the check is; a copy here could drift from it.

- The merge gate (a current review and a decision summary): `merge_pr.sh`
  Step 1.5, enforce on workspace pull requests.
- Bookkeeping-only commits after the reviewed head need no new review and
  no new CI wait: `_bookkeeping.sh`.
- Triage may start before CI: `dispatch_phase.sh next` takes no CI input;
  `run-issue/SKILL.md` step 9 waits for the reviews, not CI.
- Every phase is dispatched; `takeover` is the only inline row:
  `dispatch_phase.sh` row 27.
- The orientation line on every dialog and the Bash description prefix:
  `run-issue/SKILL.md` step 6.
- The model per phase: `dispatch_phase.sh`'s tier table (ADR-0014).

## Not here

Two kinds of host note stay in the host's private memory: which model a
session or sub-agent runs on (an account budget that changes week to
week), and permissions that hold on one machine only (reading another
tool's session logs). Neither is a rule for how the host works with the
owner.

## Formats

**Decisions list**, in every hand-back and every review entry that made a
decision:

```markdown
### Decisions made (owner may veto)
- <the decision, in plain words> — undoing it: <what it would take>.
```

**Parked items** (a follow-up, a question for later, a design input) go to
this machine's inbox with `capture.sh "<text>"` the moment they come up,
and onto the hand-back's `Parked:` line. The sit-rep reads the inbox back.
There is no separate ledger file.
