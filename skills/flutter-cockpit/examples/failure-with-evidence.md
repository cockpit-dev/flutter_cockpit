# Failure With Evidence Example

Use this pattern when the workflow does not complete successfully and the next operator needs a clean handoff.

## Example Flow

1. Bootstrap or query the session.
2. Run the structured workflow.
3. Read the bundle summaries even when the run failed.
4. Separate environment failures from app failures.
5. Report artifact paths and the next action.

## Classification Examples

- session unreachable after bootstrap -> `blocked_by_environment`
- script run completes but asserts the wrong route or state -> `failed_with_evidence`
- bundle exists but required acceptance evidence is missing -> `needs_more_work`

## Expected Agent Behavior

- reference `manifest`, `handoff`, and `delivery`
- reference `baseline_evidence`, `acceptance_evidence`, or `acceptance_delta` when they explain why the final state is still wrong or incomplete
- include concrete artifact paths when they exist
- state what should happen next:
  - relaunch or repair the environment
  - fix the app behavior and rerun
  - gather missing evidence and rerun acceptance
