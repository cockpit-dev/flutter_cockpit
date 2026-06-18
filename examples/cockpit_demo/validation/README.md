# cockpit_demo validation examples

These YAML files are copyable examples for Cockpit workflow and delivery
validation. They are intentionally stored under the example app, not in the
framework or skill, because the locators and text assertions are
`cockpit_demo`-specific.

## Fast script against a running app

Launch once, then run the workflow:

```bash
cd examples/cockpit_demo
dart run cockpit launch-app --project-dir . --platform macos --device-id macos --app-json /tmp/cockpit_demo_app.json
dart run cockpit run-script --app-json /tmp/cockpit_demo_app.json --script validation/rapid-smoke.workflow.yaml --output-root /tmp/cockpit_demo_rapid_smoke
dart run cockpit read-task-bundle-summary --bundle-dir /tmp/cockpit_demo_rapid_smoke
```

The example files keep `platform: macos` so they are copyable for local desktop
smoke runs. When replaying the same workflow on another target, pass
`--platform <platform>` to `run-script`; do not duplicate the YAML only to
change the top-level platform.

## Commands-only script

`commands-only.workflow.yaml` demonstrates the shortest supported script shape:
top-level `commands` without explicit workflow nodes. The parser expands it to
command workflow steps, so it is useful for quick deterministic checks that do
not need retry, branch, loop, or recording control.

```bash
dart run cockpit run-script --app-json /tmp/cockpit_demo_app.json --script validation/commands-only.workflow.yaml --output-root /tmp/cockpit_demo_commands_only
```

## Adaptive workflow example

`adaptive-flow.workflow.yaml` demonstrates the workflow control nodes:

- `retry` waits for app readiness.
- `if` handles an optional surface state without failing the run.
- `loop` bounds repeated work and keeps trace entries correlated to the step.
- `captureScreenshot` writes evidence into the task-run bundle.

Run it against the same app handle:

```bash
dart run cockpit run-script --app-json /tmp/cockpit_demo_app.json --script validation/adaptive-flow.workflow.yaml --output-root /tmp/cockpit_demo_adaptive_flow
```

## Comprehensive protocol example

`comprehensive.workflow.yaml` is the broad learning and parser-regression
example. It intentionally covers:

- top-level `environment`
- top-level `recording`
- step-scoped `startRecording` and `stopRecording`
- all workflow node types: `command`, `retry`, `if`, `loop`
- every current `CockpitCommandType`
- command-level `capturePolicy`, `captureFailurePolicy`, `timeoutMs`,
  `snapshotOptions`, and `screenshotRequest`
- locator fallbacks, route expectations, text input, keyboard events,
  gestures, semantic actions, screenshots, and snapshots

This file is useful for learning the full protocol and for parser compatibility
checks. It is intentionally more exhaustive than a normal CI smoke test. Prefer
`rapid-smoke.workflow.yaml` for low-flake automation, then copy only the
comprehensive sections that a real acceptance flow needs.

## Recording-backed workflow

`recorded-acceptance.workflow.yaml` records only the acceptance segment. The
recording defaults to `mode: auto`, so Cockpit prefers system or host recording
and falls back only when the platform adapter allows it.

```bash
dart run cockpit run-script --app-json /tmp/cockpit_demo_app.json --script validation/recorded-acceptance.workflow.yaml --output-root /tmp/cockpit_demo_recorded_acceptance
```

## One-shot delivery validation

`validate-task.macos.yaml` launches the app, records the acceptance segment,
captures screenshot evidence, writes a bundle, and validates delivery gates.

```bash
cd examples/cockpit_demo
dart run cockpit validate-task --config validation/validate-task.macos.yaml --output /tmp/cockpit_demo_validate_task.json --output-format json
```

For CI, prefer the lighter workflow example unless the change specifically needs
recording and strict delivery gates. Heavy recording validation is already
covered by the repository runtime-loop workflow.
