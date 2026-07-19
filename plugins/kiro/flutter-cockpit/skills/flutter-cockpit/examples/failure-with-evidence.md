# Failure With Evidence Example

Use this pattern when the workflow does not complete successfully and the next operator needs a clean handoff.

## Example Flow

1. Bootstrap or query the session.
2. Run the structured workflow.
3. Read the bundle summaries even when the run failed.
4. Separate environment failures from app failures.
5. Report artifact paths and the next action.

For default CLI output, start with the low-token sections:

- `issues`: compact `issueEvidence`, failed commands, runtime/network/artifact
  issues, gate failures, and evidence paths
- `bundle`: bundle directory, session/task/platform/status, key counts, primary
  artifact paths, and failed gates

For JSON output, start with the low-token fields:

- completed phases before failure
- failed command, route, final state preview, and command error JSON
- bundle `issueEvidence` or persisted `<bundleDir>/issue_evidence.json`
- `errorJson.details.failureDiagnostics`, especially `activation`,
  `resolvedTarget`, `routeChanged`, `uiFingerprintChanged`,
  `visibleTargetCount`, and `targetDiscoveryDiagnostics`
- bounded runtime error messages

Open screenshots, recordings, or full snapshots only when those fields do not
explain the next repair step.

## Classification Examples

- session unreachable after bootstrap -> `blocked_by_environment`
- script run completes but asserts the wrong route or state -> `failed_with_evidence`
- bundle exists but required acceptance evidence is missing -> `needs_more_work`
- mixed app/environment failure with a proven app defect -> the proven app failure keeps the outcome `needs_more_work`; do not downgrade it to `blocked_by_environment`
- required check unavailable or missing -> record the missing proof explicitly; Required missing checks are never `N/A`

## Expected Agent Behavior

- reference `manifest`, `handoff`, and `delivery`
- reference `issueEvidence.failedCommands`, `runtimeIssues`,
  `networkIssues`, `artifactIssues`, `gateFailures`, and `evidencePaths`
  before opening raw artifacts
- reference `baselineEvidence`, `acceptanceEvidence`, or `acceptanceDelta` when they explain why the final state is still wrong or incomplete
- include concrete artifact paths when they exist
- for exact-count assertions, rule out stale local app state before changing locators or UI code
- for interaction failures, prove whether the target was not found, activation
  did not fire, route did not change, UI did not change, or route target
  discovery stayed empty before changing timeouts or platform-specific code
- state whether the next action is to relaunch/repair the environment, fix app behavior and rerun, or gather missing evidence and rerun acceptance
