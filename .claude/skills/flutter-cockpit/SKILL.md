---
name: flutter-cockpit
description: Use when Flutter or host-control tasks must prove live UI, interaction, route, network, recording, screenshot, or acceptance state with runtime evidence.
---

# Flutter Cockpit

## Overview

Default to rapid development validation: prove changes with the cheapest live loop that answers the user, then stop.

`assess -> bootstrap -> baseline -> execute -> observe -> judge -> deliver`

Command success is not product proof; verify state, errors, evidence.

These stages are decision gates, not a fixed command script or command quota. Satisfy each gate with the smallest fresh evidence available; skip irrelevant commands; choose CLI, MCP, app-first, target-first, persistent-session, or bundle flows. [`references/protocol.md`](references/protocol.md).

## When To Use

- Live UI, route, interaction, network, log, screenshot, recording, or acceptance proof.
- Flutter app, browser, desktop window, simulator, emulator, device, or host control.

## First-Time App Wiring

Add `flutter_cockpit`, add `cockpit/main.dart`, and keep the production entrypoint intact. Do not add `flutter_cockpit` imports to production `lib/` code. In `cockpit/`, wrap with `FlutterCockpitApp` or `FlutterCockpit.runApp`, register `FlutterCockpit.navigatorObserver` only in the cockpit-owned navigator, and enable `CockpitRemoteSessionConfiguration.resolveFromEnvironment(...)`. For app-owned routers, call `FlutterCockpit.setCurrentRouteName(...)`.

## Stage Protocol

1. **assess**: choose the smallest truthful surface. Default to app-first. If platform/device is unknown, run `list-targets` and use the returned platform, device id, and capability metadata. Do not guess ids, payload keys, or locators.
2. **bootstrap**: launch once or reuse a handle. `launch-app` returns after readiness; never shell-background it. Reuse `.dart_tool/flutter_cockpit/latest_app.json`; use target-first only for non-app surfaces.
3. **baseline**: read before acting, unless a fresh equivalent read already answers the same question. Start with `read-app --profile minimal` or `read-target --profile minimal`; capture route, state, errors.
4. **execute**: edit, prefer `hot-reload`, and drive UI with `run-command` or short `run-batch`. For route changes, include `expectedRouteName`. After timeout, `remoteUnavailable`, or failed non-idempotent batch, re-read minimal state and resume from the smallest remaining safe step; do not replay blindly.
5. **observe**: read post-action state before judging. Use `read-app`, `read-errors --max-errors 10`, `inspect-ui`, or `read-network`. If focus blocks controls, run `dismissKeyboard`. For visible UI claims, run `capture-screenshot --name <proof-name>`. For animation, transition, gesture, or repro, use `start-recording` / `stop-recording`.
6. **judge**: compare baseline, observed state, and outcome. Do not open screenshots, videos, or raw artifacts unless the content is the unresolved question, the artifact looks wrong, or user asks.
7. **deliver**: for acceptance work, run `validate-task` and report the smallest useful evidence. `stop-app` is cleanup or recovery only, not a normal loop step.

## Fast Command Pack

Default stdout is AI-readable. Add `--stdout-format json` only for `jq`; add `--output <path>` for files, `--output-format json` for machine-readable files.

```bash
dart run cockpit list-targets
dart run cockpit launch-app --project-dir <dir> --platform <platform> --device-id <id>
dart run cockpit read-app --profile minimal
dart run cockpit analyze-files --path <changed-file>
dart run cockpit hot-reload
dart run cockpit read-errors --max-errors 10
```

```bash
printf '%s\n' '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}' >/tmp/flutter_cockpit_command.json
dart run cockpit run-command --command-file /tmp/flutter_cockpit_command.json --profile standard
```

```bash
printf '%s\n' '{"commandId":"tap-settings","commandType":"tap","locator":{"text":"Settings"},"parameters":{"expectedRouteName":"/settings","routeTimeoutMs":5000}}' >/tmp/flutter_cockpit_command.json
dart run cockpit run-command --command-file /tmp/flutter_cockpit_command.json --profile standard
```

## Escalation Commands

Use these only when the next claim needs them.

Final proof:

```bash
dart run cockpit capture-screenshot --name acceptance --profile inspect
```

`capture-screenshot` uses app metadata, prefers system/host capture, falls back to app capture, and comes before external screenshot tools.

Short deterministic flow:

```bash
dart run cockpit run-batch --commands-file /tmp/flutter_cockpit_batch.json --profile standard
```

Motion, transition, gesture, or repro video:

```bash
dart run cockpit start-recording
# optional: add --recording-json '{"purpose":"repro","name":"flow-name"}'
dart run cockpit stop-recording
```

Recording defaults to `mode:auto`: app handles prefer system/host capture and fall back only when allowed. For strict layer, pass `--recording-json` with `layer` and `allowFallback:false`.

Native/system or non-Flutter surface after Flutter semantics cannot answer it:

```bash
dart run cockpit read-system-capabilities [--platform <platform>] [--device-id <device-or-simulator-id>] [--app-id <app-id>] [--process-id <pid>] [--wda-url http://127.0.0.1:8100]
dart run cockpit run-system-action [--platform <platform>] [--device-id <device-or-simulator-id>] [--app-id <app-id>] [--process-id <pid>] [--wda-url http://127.0.0.1:8100] --action <available-action>
```

Use `parameters=[name*:type[range](allowed|values)]`; `*` means required. Do not guess payload keys. Commands reuse `.dart_tool/flutter_cockpit/latest_app.json` and resolve platform app ids. `--app-id` means native app id. On parameter errors, re-run `read-system-capabilities`, copy metadata, and send only that payload. For `dismissSystemDialog`, use `--decision accept` or `--decision dismiss`; omit it to accept.
Use JSON `actionGroups` instead of hard-coded platform lists. Android uses adb. iOS Simulator uses simctl plus WDA; WDA actions stay blocked unless reachable. Unsupported simulator actions stay blocked instead of faked. For native crash logs before runtime attaches, use `run-system-action --action readSystemLogs`. `activateWindow` on iOS Simulator must not terminate Flutter debug or hot-reload sessions; use `terminateApp` only for restart.
Trust only actions reported as `available`. Desktop coordinates use screen pixels. macOS host screenshots/recordings need `--app-id`; Windows/Linux can use `--app-id` or `--process-id`. If not `available`, follow its requirement/fallback or report `blocked_by_environment`.

Acceptance, release, or artifact handoff:

```bash
dart run cockpit validate-task --config /tmp/flutter_cockpit_validate_task.yaml
```

Workflow script for branch/retry/loop E2E. Prefer YAML by hand and JSON when generated. Schema: [`references/protocol.md`](references/protocol.md), `cockpit://workspace/control-workflow-protocol`, `cockpit://workspace/control-workflow-schema`.

```yaml
schemaVersion: 1
sessionId: dev-flow
taskId: checkout-proof
platform: android
failFast: true
steps:
  - stepId: record-flow
    stepType: startRecording
    recording:
      purpose: acceptance
      name: checkout-proof
      mode: auto
      attachToStep: true
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
  - stepId: stop-recording
    stepType: stopRecording
```

```bash
dart run cockpit run-script --app-json /tmp/flutter_cockpit/app.json --script /tmp/flutter_cockpit/workflow.yaml --platform <platform> --output-root /tmp/flutter_cockpit/out
```

Use `--platform` to run one reusable workflow on the current target. Read `issue_evidence.json` for failure, `trace.json` for artifact mapping, and `validation.json` only after `validate-task`.

Board:

```bash
dart run cockpit devtools --history-root /tmp/flutter_cockpit/out
```

Use same `--output-root`. `sessionId` isolates one job, `taskId` names the objective, and `runId` is one attempt. Reuse `sessionId` for retries; use a new one for unrelated work. The board pins latest `sessionId`; use selector/`all runs` for audit and `--scope latest` to follow. Timeline is scope-level, details/bundles stay per-run, and artifact links carry owning run/event. Submitted jobs and completed in-root bundles share the run API. For handoff, click `download bundle` or GET `/api/runs/<runId>/bundle-download`; the streamed tar contains `download_manifest.json`, `run_metadata.json`, `bundle/**`, `live/**`, with absent parts in `missingRoots`. Board launches need executable envelope: `sessionHandle`, `baseUrl`, `outputRoot`, platform ids.

## Development Defaults

- Fast path for most edits: reuse/launch -> `read-app --profile minimal` -> edit -> `hot-reload` -> post-action read -> `read-errors --max-errors 10` -> screenshot for visible claims.
- Use `minimal -> standard -> inspect -> evidence`; escalate only when needed.
- Be flexible on commands, strict on proof.
- Every command should reduce uncertainty. Do not run recording, evidence profiles, bundle validation, or raw artifact reads just because they exist.
- Keep platform and device placeholders until `list-targets` returns real values; read capabilities before choosing shell, recording, browser, or native paths.
- Prefer file inputs: `--command-file`, `--commands-file`, `--config`; YAML by hand, JSON when generated.
- Safe commands: `tap`, `enterText`, `dismissKeyboard`, `assertText`, `scrollUntilVisible`.
- Safe locator keys: `text`, `tooltip`, `semanticId`, `type`, `ancestor`, `index`, `fallbacks`. Do not set `type: Text` for button labels.
- Keep the app alive while more edits are likely. Stop only when asked, stuck, `hot-restart` cannot recover, or clean rebuild/relaunch is required.

## Failure Recovery

- If syntax is unclear, run `help <command>`.
- On non-zero exit, read `errorJson.code`, `errorJson.message`, and `details` before prose stderr.
- Use `failureDiagnostics` before changing locators, timeouts, route waits, or retry strategy.
- For bundles, read AI summaries, `read-task-bundle-summary`, and `issueEvidence` before raw artifacts.
- Classify missing ffmpeg, capture permission, simulator/device, or recording evidence as `blocked_by_environment` unless app evidence proves otherwise.

## Other Surfaces

- Target-first: `launch-target --target-json <file>` -> `read-target --profile minimal` -> `inspect-surface` only when needed.
- Native/System Control Plane: `read-system-capabilities` first, then `run-system-action` only for actions reported as `available` using the returned `parameters` contract.
- Persistent development: `launch-development-session` -> `collect-development-probe --profile quick` -> edit -> `reload-development-session --mode hot_reload` -> collect or compare probe. Use the app handle for screenshots and recording.
- MCP is equivalent to CLI when available.
- Code facts before broad tools: `grep-package-uris`, `read-package-uris`, `pub`, `lsp`, `analyze-files`, `run-tests`.

## Common Mistakes

- Running random commands instead of walking the seven stages.
- Relaunching or stopping after every edit.
- Treating command success, bundle completion, or artifact existence as product proof.
- Using external screenshot or recording tools first.
- Opening large artifacts before summaries identify the missing fact.
- Claiming completion without baseline, post-action state, errors, and evidence.
