# Control Workflow Protocol

This contract defines the stable script format used by `run-script`, `run-remote-control-script`, `run-task`, and task validation flows when a linear command list is not enough.

Use YAML for hand-written AI workflows and JSON for generated workflows. Both formats decode to the same lower camel case object model. Bundle output remains JSON.

Current protocol version: `schemaVersion: 1`.

Machine-readable schema: [`control-workflow.schema.json`](control-workflow.schema.json).
MCP schema resource URI: `cockpit://workspace/control-workflow-schema`.

`schemaVersion` is optional for short hand-written scripts and defaults to `1`, but generated scripts and persisted replay scripts should include it. Parsers must reject unsupported non-`1` values instead of guessing future semantics.

## Top-Level Script

Required:

- `sessionId`
- `taskId`
- `platform`
- either `commands` or `steps`

Optional:

- `schemaVersion`, default `1`
- `environment`
- `recording`
- `failFast`, default `true`

`commands` is the simple linear form. `steps` is the workflow form. Any provided list must be non-empty. When `steps` is present, it is the execution plan; `commands` may remain for legacy replay metadata but is not the preferred source of control flow.

`platform` is the script's default execution target. Reusable workflows may be
run against another target with `run-script --platform <platform>` or MCP
`run_script.platform`; the override also updates `environment.platform` for that
run. Prefer a runtime platform override over copying a workflow file only to
change `platform`.

## Node Types

Every workflow node is an object with:

- `stepType`
- optional `stepId`
- optional `description`

If `stepId` is omitted, the parser assigns a path-like id from the node position. Production scripts should set stable `stepId` values so bundle traces remain readable across runs.
`description` explains the step intent for humans, AI agents, live events, and
timeline UIs. It is metadata only and must not replace executable assertions or
validation gates.

Runtime timeline events for nested nodes include observability metadata in the
event `details`: `workflowStepDepth`, `parentWorkflowStepId`,
`parentWorkflowStepType`, `rootWorkflowStepId`, `relation`, `siblingIndex`, and
for retries or loops, `attempt`/`maxAttempts` or
`iteration`/`maxIterations`. These fields make live boards and downstream tools
able to group internal probe steps under the user-authored workflow node without
changing script execution semantics.

### `command`

Executes one `CockpitCommand`.

Command fields:

- `commandId`, required stable id used in traces and artifacts
- `commandType`, required; supported values are `tap`, `enterText`,
  `focusTextInput`, `setTextEditingValue`, `sendTextInputAction`,
  `sendKeyEvent`, `sendKeyDownEvent`, `sendKeyUpEvent`, `longPress`,
  `doubleTap`, `drag`, `fling`, `swipe`, `pinchZoom`, `rotate`, `panZoom`,
  `multiTouch`, `scrollUntilVisible`, `clearNetworkActivity`,
  `waitForNetworkIdle`, `waitForUiIdle`, `back`, `showOnScreen`, `increase`,
  `decrease`, `dismiss`, `dismissKeyboard`, `waitFor`, `assertVisible`,
  `assertText`, `captureScreenshot`, and `collectSnapshot`
- `locator`, optional target locator
- `parameters`, optional command-specific payload object
- `capturePolicy`, optional; `none`, `afterAction`, `onFailure`, or
  `afterActionAndFailure`
- `captureFailurePolicy`, optional; `failCommand` or `degradeCommand`
- `timeoutMs`, optional command timeout in milliseconds
- `snapshotOptions`, optional snapshot tuning for command evidence
- `screenshotRequest`, optional structured screenshot request

Locator fields are multi-signal by design. Use one or more of `cockpitId`,
`semanticId`, `key`, `text`, `tooltip`, `type`, `route`, `registrationId`, and
`path`; add `index` only to disambiguate duplicate matches; scope with
`ancestor`; add `fallbacks` for non-invasive multi-condition matching. Legacy
`kind`/`value` locators are rejected.

Snapshot options use fixed lower-camel-case fields: `profile` (`live`,
`baseline`, `investigate`, `forensic`), target/property limits, diagnostic
toggles, `networkQuery`, `runtimeQuery`, and accessibility limits. Network query
fields are `method`, `uriContains`, `onlyFailures`, and `statusCodeAtLeast`.
Runtime query fields are `onlyErrors` and `messageContains`.

Screenshot request fields are `reason` (`baseline`, `before_action`,
`after_action`, `assertion_failure`, `acceptance`), `name`, `includeSnapshot`,
`attachToStep`, and optional `snapshotOptions`.

```yaml
- stepId: tap-settings
  stepType: command
  description: Open settings before checking sync configuration.
  command:
    commandId: tap-settings
    commandType: tap
    locator:
      text: Settings
```

### `startRecording`

Starts a recording at an explicit point in the workflow. Use this when only the risky or user-visible part of a flow needs video evidence. `mode: auto` is the default; it prefers the broadest stable system/host recorder and falls back only when the request allows fallback. Explicit `layer` requests are strict unless `allowFallback: true` is set.

```yaml
- stepId: record-checkout
  stepType: startRecording
  recording:
    purpose: acceptance
    name: checkout-flow
    mode: auto
    attachToStep: true
    tailStabilizationMs: 1400
```

### `stopRecording`

Stops the active workflow recording and attaches the recording artifact to the trace. `settleMs` defaults to `1400` so the final visual state is captured before the recorder is finalized.

```yaml
- stepId: stop-checkout-recording
  stepType: stopRecording
  settleMs: 1400
```

### `if`

Runs a condition command as a probe. A successful probe executes `thenSteps`; a failed probe executes `elseSteps`. Probe failure does not count as a final command failure.

```yaml
- stepId: dismiss-dialog-if-present
  stepType: if
  condition:
    commandId: has-dialog
    commandType: assertText
    parameters:
      text: Allow
  thenSteps:
    - stepType: command
      command:
        commandId: tap-allow
        commandType: tap
        locator:
          text: Allow
  elseSteps: []
```

### `retry`

Retries one command step until it succeeds or `maxAttempts` is reached. `maxAttempts` defaults to `3`. `delayMs` defaults to `0`.

Intermediate failed attempts are recorded as workflow attempt evidence, not final command failures. The final successful or final failed attempt is recorded as the command result when the retry node is part of the main execution path. `retry.step` must be `stepType: command`; wrap branching or loops outside the retry node instead of retrying a nested workflow subtree.

```yaml
- stepId: wait-ready
  stepType: retry
  maxAttempts: 4
  delayMs: 500
  step:
    stepType: command
    command:
      commandId: assert-ready
      commandType: assertText
      parameters:
        text: Ready
```

### `loop`

Runs a condition command before each iteration. When the condition succeeds, child `steps` execute. When the condition fails, the loop stops successfully.

`maxIterations` is required and must be positive. There are no unbounded loops.

```yaml
- stepId: drain-items
  stepType: loop
  maxIterations: 10
  condition:
    commandId: has-delete
    commandType: assertText
    parameters:
      text: Delete
  steps:
    - stepType: command
      command:
        commandId: tap-delete
        commandType: tap
        locator:
          text: Delete
```

## Execution Rules

- Commands receive AI evidence defaults before execution.
- `captureScreenshot` commands use the capture adapter when available.
- Normal command failures obey `failFast`.
- Condition probe failures select control flow and do not fail the task.
- Retry intermediate failures do not fail the task unless the final attempt fails.
- Loop termination by failed condition is success.
- Loop exhaustion at `maxIterations` is recorded as `workflow_loop_exhausted`; it is not a failure by itself because bounded draining workflows often stop at their budget.
- Top-level `recording` starts before the workflow and stops after the workflow, including failure paths.
- Step-level `startRecording` / `stopRecording` records only the selected workflow segment. Each start resolves the recording strategy from that step's own `recording` request. A second start while recording is active is a workflow failure; an unclosed active recording is stopped during cleanup.
- Screenshots and recordings prefer system/host evidence when the platform exposes it and fall back to app/remote evidence when fallback is allowed or the screenshot host capture fails.
- Artifact payloads and source files from probes, attempts, commands, screenshots, and recordings are all carried into the final task-run bundle.

## Trace Contract

`steps.json` is the full action log. `trace.json` is the compact derived index.

Workflow execution may emit these action types:

- `workflow_if`
- `workflow_loop_iteration`
- `workflow_loop_exhausted`
- `workflow_retry_attempt`
- `workflow_command_attempt`
- `recording_start_requested`
- `recording_started`
- `recording_stopped`
- `recording_failed`

Trace entries may include:

- `stepIndex`
- `actionType`
- `workflowStepId`
- `workflowStepType`
- `commandId`
- `commandType`
- `status`
- `conditionCommandId`
- `conditionSuccess`
- `selectedBranch`
- `iteration`
- `attempt`
- `artifactRefs`
- `captureRefs`
- `commandError`
- `conditionError`
- `failureSummary`

Consumers should read `trace.json` first for step-to-artifact correlation, then open `steps.json` only when the compact trace does not explain the next action.

## Minimal Complete Script

Top-level `commands` is the shortest linear form. It is expanded to command
workflow steps at runtime.

```yaml
schemaVersion: 1
sessionId: quick-proof
taskId: inbox-proof
platform: macos
failFast: true
commands:
  - commandId: assert-inbox
    commandType: assertText
    parameters:
      text: Inbox
  - commandId: capture-inbox
    commandType: captureScreenshot
    screenshotRequest:
      reason: acceptance
      name: inbox-proof
      includeSnapshot: true
      attachToStep: true
```

Use `steps` when the flow needs retry, branch, loop, or explicit recording
control:

```yaml
schemaVersion: 1
sessionId: dev-flow
taskId: checkout-proof
platform: android
environment:
  platform: android
  flutterVersion: 3.38.9
  dartVersion: 3.10.8
failFast: true
steps:
  - stepId: open-checkout
    stepType: command
    command:
      commandId: tap-checkout
      commandType: tap
      locator:
        text: Checkout
  - stepId: wait-success
    stepType: retry
    maxAttempts: 4
    delayMs: 500
    step:
      stepType: command
      command:
        commandId: assert-success
        commandType: assertText
        parameters:
          text: Order complete
```

Run it:

```bash
dart run cockpit run-script --app-json /tmp/flutter_cockpit/app.json --script /tmp/flutter_cockpit/workflow.yaml --platform android --output-root /tmp/flutter_cockpit/out
```

Open the optional full-fidelity board over the same output root:

```bash
dart run cockpit devtools --history-root /tmp/flutter_cockpit/out
```

The board groups runs by workflow `sessionId`, opens the current latest scope,
and rewrites the URL to that concrete scope. Use one stable `sessionId` per
development or validation job, `taskId` for the current objective, and `runId`
for one execution attempt. Reuse the same `sessionId` for retries of the same
job so its timeline, artifacts, and failures remain isolated from unrelated
work under the same `--history-root`; use the `all runs` scope only for
intentional cross-session audit. The main timeline is scope-level: retries with
the same `sessionId` render together in execution order, while run details and
bundle panels remain per-run. Artifact links carry the owning run and event key
so repeated relative paths stay traceable. Pass `--scope latest` only for a
board that should keep following the newest job. Run-index responses include
`scopeMode`; `scope=current` and `scope=latest` are aliases for the current
latest scope.

For tool-owned bootstrap and validation, embed the same script object under the
task config `script` field and run:

```bash
dart run cockpit run-task --config /tmp/flutter_cockpit/run_task.yaml
dart run cockpit validate-task --config /tmp/flutter_cockpit/validate_task.yaml
```
