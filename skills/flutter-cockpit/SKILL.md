---
name: flutter-cockpit
description: Use when a Flutter app or adjacent browser, desktop, device, or host-control task must prove live UI, interaction, route, network, or acceptance state with runtime evidence instead of code-only reasoning.
---

# Flutter Cockpit

## Overview

Use Flutter Cockpit when code inspection is not enough. The goal is an AI-native loop: launch once, read the smallest runtime truth, edit, hot reload, verify with commands, collect proof, and keep the app alive for the next edit.

Prefer CLI in shell-driven work. Use MCP when the host needs tool calls, roots-aware state, or the stdio server. Open one reference file only when exact payload syntax is missing.

## When To Use

- Prove UI, route, interaction, network, logs, errors, screenshots, recordings, or acceptance state.
- Reproduce live bugs where static reasoning is insufficient.
- Drive browser, desktop, device, simulator, emulator, or host surfaces around Flutter.
- Iterate with hot reload or hot restart during implementation.
- Ask focused Dart/package facts before a runtime pass.

Do not use it for docs-only edits or static refactors with no runtime claim.

## Quick Reference

- Discover first: `list-targets`. Do not guess `--device-id`; Android, iOS, and web need the discovered id.
- Default app flow: `launch-app` -> `read-app --profile minimal` -> edit -> `hot-reload` -> `run-command` or `run-batch` -> smallest read -> `read-errors` -> named `captureScreenshot` before UI completion claim. Keep app alive for next edit.
- Evidence: key mutating commands auto-attach best-effort screenshots. Use explicit `captureScreenshot` for final still proof. For development recording, stay inside flutter_cockpit: use bare `start-recording` -> interact/reload -> `stop-recording` for manual windows; use `run-batch --recording-json` only when the whole flow is deterministic or needs acceptance/full options. Verify a completed non-empty artifact.
- Output: default stdout is AI-readable. Use `--stdout-format json` only for `jq`. Use `--output <path>` for files and `--output-format json` only for machine-readable file output.
- Stop policy: `stop-app` is cleanup or recovery, not a loop step. Stop when the user asks, when ending a session you launched, when the supervisor is stuck, when `hot-restart` cannot recover, or when a clean rebuild/relaunch is needed.
- Escalate only when needed: `minimal` -> `standard` -> `inspect` -> `evidence`. Ask one missing fact per cycle.
- App-first by default. Use target-first only when the surface is not a plain app handle.

## Copy-Ready Commands

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools list-targets
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app --project-dir <dir> --platform <platform> --device-id <id>
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-app --profile minimal
```

```bash
mkdir -p /tmp/flutter_cockpit
printf '%s\n' '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}' \
  >/tmp/flutter_cockpit/command.json
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command --command-file /tmp/flutter_cockpit/command.json --profile standard
```

```bash
printf '%s\n' '[{"commandId":"wait-1","commandType":"waitForUiIdle"},{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}]' \
  >/tmp/flutter_cockpit/commands.json
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-batch --commands-file /tmp/flutter_cockpit/commands.json --profile minimal --final-profile standard
```

```bash
printf '%s\n' '{"commandId":"acceptance-shot","commandType":"captureScreenshot","screenshotRequest":{"reason":"acceptance","name":"acceptance","includeSnapshot":true,"attachToStep":true}}' \
  >/tmp/flutter_cockpit/capture.json
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command --command-file /tmp/flutter_cockpit/capture.json --profile evidence
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools start-recording
dart run flutter_cockpit_devtools:flutter_cockpit_devtools stop-recording
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools hot-reload
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-errors --max-errors 10
dart run flutter_cockpit_devtools:flutter_cockpit_devtools stop-app
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task --config-json /tmp/flutter_cockpit/validate_task.json
```

## Development Rules

- Do not shell-background `launch-app`. It returns after readiness; the supervisor keeps logs, hot reload, hot restart, and `stop-app` control alive.
- In one repo, reuse `.dart_tool/flutter_cockpit/latest_app.json`; do not repeat `--app-json` unless operating from another cwd or a named handle.
- Prefer file inputs: `--command-file`, `--commands-file`, config JSON. Inline JSON only when tiny.
- Safe first command types: `tap`, `enterText`, `assertText`, `waitForUiIdle`, `scrollUntilVisible`, `captureScreenshot`.
- Safe locator keys: `text`, `tooltip`, `semanticId`, `type`, `ancestor`, `index`, `fallbacks`. Do not set `type: Text` for button labels; use text alone or the inspected control type. Use `key` only for existing stable keys.
- For repeated labels such as `Open` or `Save`, prefer full accessible text plus `route` or `ancestor`.
- Prefer `run-batch` for route-crossing flows such as open editor -> fill fields -> save. Do not blindly replay a non-idempotent batch after timeout or `remoteUnavailable`; re-read minimal route/state first and resume from the smallest remaining step.
- For route-changing taps, include `parameters.expectedRouteName`; add `parameters.routeTimeoutMs` for CI, simulator, recording, or acceptance latency. Follow critical crossings with `waitFor` on `parameters.routeName`.
- Do not use external screen-recording tools before trying framework recording. `launch-app` and `launch-development-session` write `.dart_tool/flutter_cockpit/latest_app.json`; app-scoped bare `start-recording`, `stop-recording`, and `run-batch --recording-json` reuse it by default.
- Do not wait until the final response to collect evidence. Use auto screenshots after mutations; before claiming visible UI completion, run one named `captureScreenshot`. Report artifact refs or output paths.
- Command success is not product proof. Re-read post-action state before judging.

## Failure Recovery

- If syntax is unclear, run `dart run flutter_cockpit_devtools:flutter_cockpit_devtools help <command>` before guessing.
- When a CLI command exits non-zero, read `errorJson.code`, `errorJson.message`, and optional `details` before prose. Differentiate `remoteUnavailable`, `bridgeUnavailable`, `artifactNotFound`, `recordingStartFailed`, and `invalidPayload`.
- Treat `invalidPayload` as a caller command/option defect. Fix JSON shape, query parameter, profile, or locator before retrying.
- Before changing a locator, timeout, platform branch, or retry strategy, inspect `errorJson.details.failureDiagnostics` when present.
- For bundle-backed failures, read default AI `issues` first; use `issueEvidence` or `<bundleDir>/issue_evidence.json` only when structured filtering is needed.
- Treat web browser-host recording as an environment gate. If ffmpeg startup/output evidence missing is reported, record the prerequisite warning and do not claim video proof.
- For iOS recording without `app.json`, pass `--ios-device-id <id>`. Prefer `app.json` because it carries platform, device, process, and session metadata.
- If Xcode says `FlutterAppDelegate.h has been modified`, treat it as stale iOS PCH cache: run `flutter clean` in the app and relaunch once.

## Other Surfaces

- Target-first: `launch-target --target-json /tmp/target.json --output /tmp/launch_target.json --output-format json` -> `read-target --profile minimal` -> `inspect-surface`. If app commands may be needed, extract the embedded handle with `jq '.app' /tmp/launch_target.json > /tmp/app.json`.
- Persistent sessions: `launch-development-session` writes both development and app handles -> `collect-development-probe --profile quick` -> edit -> `reload-development-session --mode hot_reload` -> collect/compare probe. Use the app handle for recording; stop only for cleanup or recovery.
- Direct remote is an escape hatch: `launch-remote-session` -> `read-remote-status --profile minimal` -> `execute-remote-command` or batch -> snapshot only if needed.
- Code-side truth before workspace-wide tools: `analyze-files`, `lsp`, `grep-package-uris`, `read-package-uris`, `pub`.
- MCP roots: if a host already provides roots but the task needs an adjacent repo or linked package, call `add_roots`; manual roots merge with native roots. Bundle summary is also available as MCP `read_task_bundle_summary`.
- `run-shell` is bounded and killable by default; raise `--timeout-seconds <n>` only for known-slow host, adb, or simctl work.

## Common Mistakes

- Guessing device ids, command names, flags, command types, or locator keys instead of using discovery and help.
- Relaunching or stopping after every edit instead of hot reload plus bounded reads.
- Treating `target.json` as an app handle for `stop-app`, reload, or app-scoped recording.
- Adding automation-only keys instead of using multi-signal locators.
- Opening large snapshots or artifacts before summaries explain the next repair.
- Treating a finished run, screenshot, or bundle as enough proof without post-action state or validation output.
- Assuming framework-repo verifier scripts exist in a consumer app.

## Reference Map

- exact CLI syntax and payload shapes: [`examples/cli-command-reference.md`](examples/cli-command-reference.md)
- shortest edit -> reload -> verify loop: [`examples/rapid-dev-loop.md`](examples/rapid-dev-loop.md)
- first-day new app integration: [`examples/flutter-app-setup.md`](examples/flutter-app-setup.md)
- host CLI and MCP setup: [`examples/host-devtools-setup.md`](examples/host-devtools-setup.md)
- runtime and release validation: [`examples/runtime-validation.md`](examples/runtime-validation.md)
- acceptance bundles and delivery evidence: [`examples/acceptance-delivery.md`](examples/acceptance-delivery.md)
- failure reporting with evidence: [`examples/failure-with-evidence.md`](examples/failure-with-evidence.md)
