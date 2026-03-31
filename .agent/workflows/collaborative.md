# Workflow: Collaborative

Human participates at key checkpoints. Agent drives between checkpoints.
Use for features, design work, and tasks where judgment calls matter.

## Steps

| Step | Owner | Description |
|------|-------|-------------|
| brainstorm | human checkpoint | Explore approaches. Agent presents options, human decides direction. Includes assessing the issue for readiness. |
| plan | human approves | Agent drafts work plan, human reviews and approves before implementation begins. |
| plan-review | agent | Independent evaluation of the committed plan (scope, approach, principle alignment). |
| implement | agent | Write code, make changes. Agent drives; human available for questions. |
| local-review | agent | Pre-push self-review against the diff. Catch what external review would flag. |
| user-testing | human | Human verifies behavior — runs the build, checks the UI, tests the workflow. |
| pr | agent | Open the pull request. |
| external-review | agent triages, human decides | Copilot/human review. Agent triages findings, human decides what to fix vs. dismiss. |
| merge | human | Human merges when satisfied. |

## When to Use

- New features that affect user-visible behavior
- Design changes or architectural decisions
- Work where "does this feel right?" matters more than "does this pass tests?"
- Tasks where the human has domain knowledge the agent lacks

## When to Use a Different Workflow

- Straightforward bugfixes with clear reproduction steps: consider `autonomous`
- Human driving with agent assistance: consider `guided`
- Creative content (maps, assets) with minimal review: consider `direct`
