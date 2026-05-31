---
name: flutter-cockpit
description: Use when a Flutter app or adjacent browser, desktop, device, or host-control task must prove live UI, interaction, route, network, recording, screenshot, or acceptance state with runtime evidence instead of code-only reasoning.
---

# Flutter Cockpit

## Overview

Flutter Cockpit is an AI development loop, not a screenshot tool or command catalog. Default to rapid development validation: prove the current change with the cheapest live loop that answers the user's question, then stop. For every runtime claim, follow the evidence gates in order:

`assess -> bootstrap -> baseline -> execute -> observe -> judge -> deliver`

Command success is not product proof. A command that exits 0 only proves command acceptance. Product correctness requires post-action state, errors, and evidence.

These stages are decision gates, not a fixed command script or command quota. Satisfy each gate with the smallest fresh evidence available; skip irrelevant commands, reuse valid handles and recent reads, and choose CLI, MCP, app-first, target-first, persistent-session, or bundle flows according to the task.

## When To Use

- Live UI, route, interaction, network, log, screenshot, recording, or acceptance proof is needed.
- A Flutter app, web surface, desktop window, simulator, emulator, device, or host surface must be controlled.
- You are iterating with hot reload or hot restart.
- Static code review is insufficient to decide whether the app works.

Do not use for docs-only edits or static refactors with no runtime claim.

## First-Time App Wiring

If the app is not controllable yet, add the runtime package and a dev entrypoint before runtime validation:

1. add `flutter_cockpit` to the Flutter app package and run `flutter pub get`
2. keep the production entrypoint intact
3. add `cockpit/main.dart` that imports the existing app root
4. wrap the root with `FlutterCockpitApp` or `FlutterCockpit.runApp`
5. add `FlutterCockpit.navigatorObserver` to the app navigator
6. enable `CockpitRemoteSessionConfiguration.resolveFromEnvironment(...)`

Minimal `cockpit/main.dart` shape:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

void main() => runApp(buildCockpitDevelopmentApp());

Widget buildCockpitDevelopmentApp() {
  return FlutterCockpitApp(
    config: FlutterCockpitConfig.production(
      remoteSession: CockpitRemoteSessionConfiguration.resolveFromEnvironment(),
    ),
    child: MaterialApp(
      navigatorObservers: <NavigatorObserver>[FlutterCockpit.navigatorObserver],
      home: const ExistingAppRoot(),
    ),
  );
}
```

## Stage Protocol

1. **assess**: decide the smallest truthful surface. Default to app-first. If platform or device is unknown, run `list-targets` and use the returned platform, device id, and capability metadata. Do not guess device ids, command names, payload keys, or locator types.
2. **bootstrap**: launch once or reuse a handle. `launch-app` returns after readiness; never shell-background it. Reuse `.dart_tool/flutter_cockpit/latest_app.json` in the same repo. Use target-first only for non-plain app surfaces. Use direct remote only as an escape hatch.
3. **baseline**: read before acting, unless a fresh equivalent read already answers the same question. Start with `read-app --profile minimal` or `read-target --profile minimal`; capture route, visible state, reachability, and current errors. For code edits, prefer `lsp` or `analyze-files` before workspace-wide tools.
4. **execute**: edit, then prefer `hot-reload`; use `hot-restart` before a clean stop/relaunch. Drive UI with `run-command` or a short `run-batch`. For route-changing taps, include `expectedRouteName` or a follow-up wait. After timeout, `remoteUnavailable`, or a failed non-idempotent batch, re-read minimal route/state and resume from the smallest remaining safe step; do not replay blindly.
5. **observe**: read post-action state before judging. Use `read-app`, `read-errors --max-errors 10`, `inspect-ui`, `read-network`, or bundle summaries according to the next missing fact. Before any visible UI completion claim, run `capture-screenshot --name <proof-name>`. For animation, transition, gesture, or bug-repro proof, use framework recording first: `start-recording` -> act or reload -> `stop-recording`, then verify a completed non-empty artifact.
6. **judge**: compare baseline with observed state and the user's requested outcome. Classify as `completed`, `needs_more_work`, `failed_with_evidence`, or `blocked_by_environment`. Media existence is not semantic proof; screenshot or video proof still needs state/error interpretation.
7. **deliver**: for acceptance-facing work, run `validate-task` and report the smallest useful evidence paths or refs. Attach artifacts only when the host supports it; otherwise report exact paths. `stop-app` is cleanup or recovery only, not a normal loop step.

## Fast Command Pack

Use default AI-readable stdout. Add `--stdout-format json` only for `jq`. Add `--output <path>` for file output; terminal output should then only need the produced path. Use `--output-format json` only for machine-readable files.

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools list-targets
dart run flutter_cockpit_devtools:flutter_cockpit_devtools launch-app --project-dir <dir> --platform <platform> --device-id <id>
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-app --profile minimal
dart run flutter_cockpit_devtools:flutter_cockpit_devtools analyze-files --path <changed-file>
dart run flutter_cockpit_devtools:flutter_cockpit_devtools hot-reload
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-errors --max-errors 10
```

```bash
printf '%s\n' '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}' >/tmp/flutter_cockpit_command.json
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --command-file /tmp/flutter_cockpit_command.json --profile standard
```

## Escalation Commands

Use these only when the next claim needs them; do not add them to every loop.

Visible final proof:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools capture-screenshot --name acceptance --profile standard
```

Short deterministic flow:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-batch --commands-file /tmp/flutter_cockpit_batch.json --profile standard
```

Motion, transition, gesture, or bug-repro video:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools start-recording
dart run flutter_cockpit_devtools:flutter_cockpit_devtools stop-recording
```

Acceptance, release readiness, or artifact-backed handoff:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools validate-task --config-json /tmp/flutter_cockpit_validate_task.json
```

## Development Defaults

- Fast path for most edits: reuse or launch app -> `read-app --profile minimal` -> edit -> `hot-reload` -> smallest post-action read -> `read-errors --max-errors 10` -> one named screenshot only for visible UI claims.
- Use `minimal -> standard -> inspect -> evidence`; escalate only when the current layer cannot answer the next question.
- Be flexible on commands, strict on proof. A tiny text edit may only need analyze, hot reload, minimal read, and errors; an acceptance flow may need batch, recording, and validation.
- Every command should reduce uncertainty for the current task. Do not run recording, evidence profiles, bundle validation, or raw artifact reads just because they exist.
- Keep platform and device placeholders until `list-targets` returns real values; read capabilities before choosing shell, recording, browser, or native paths.
- Prefer file inputs: `--command-file`, `--commands-file`, and config JSON. Inline JSON only when tiny.
- Safe command types: `tap`, `enterText`, `assertText`, `waitForUiIdle`, `scrollUntilVisible`, `captureScreenshot`.
- Safe locator keys: `text`, `tooltip`, `semanticId`, `type`, `ancestor`, `index`, `fallbacks`. Do not set `type: Text` for button labels; use text alone or the inspected control type.
- For repeated labels, combine accessible text with `route` or `ancestor`.
- Use auto screenshots as debugging breadcrumbs, not final proof. Use an explicit named screenshot for final visible proof.
- Keep the app alive while more edits are likely. Stop only when the user asks, the session is stuck, `hot-restart` cannot recover, or a clean rebuild/relaunch is required.

## Failure Recovery

- If syntax is unclear, run `help <command>` or open one reference file for exact payload shape. Do not open every example by default.
- On non-zero exit, read `errorJson.code`, `errorJson.message`, and `details` before prose stderr. Treat `invalidPayload` as caller JSON/option error, not app failure.
- Use `failureDiagnostics` before changing locators, timeouts, route waits, or retry strategy.
- For bundles, read default AI summaries, `read-task-bundle-summary`, and `issueEvidence` before raw snapshots, videos, screenshots, or CI logs.
- Classify missing ffmpeg, missing screen-capture permission, simulator/device unavailability, and missing recording startup/output evidence as `blocked_by_environment` unless app evidence proves otherwise.

## Other Surfaces

- Target-first: `launch-target --target-json <file>` -> `read-target --profile minimal` -> `inspect-surface` only when needed.
- Persistent development: `launch-development-session` -> `collect-development-probe --profile quick` -> edit -> `reload-development-session --mode hot_reload` -> collect or compare probe. Use the app handle for screenshots and recording.
- MCP is equivalent to CLI when the host provides it. Use roots-aware MCP for adjacent packages, persisted app discovery, or task-bundle summary reads.
- Code-side facts before broad tools: `grep-package-uris`, `read-package-uris`, `pub`, `lsp`, `analyze-files`, `run-tests`.

## Common Mistakes

- Running random commands after reading the skill instead of walking the seven stages.
- Relaunching or stopping after every edit instead of hot reload plus bounded reads.
- Treating command success, bundle completion, or artifact existence as product proof.
- Using external screenshot or recording tools before framework screenshot or recording.
- Opening large artifacts before summaries identify the missing fact.
- Claiming completion without baseline, post-action state, errors, and evidence paths.

## Reference Map

- exact CLI syntax and payload shapes: [`examples/cli-command-reference.md`](examples/cli-command-reference.md)
- shortest edit -> reload -> verify loop: [`examples/rapid-dev-loop.md`](examples/rapid-dev-loop.md)
- first-day new app integration: [`examples/flutter-app-setup.md`](examples/flutter-app-setup.md)
- host CLI and MCP setup: [`examples/host-devtools-setup.md`](examples/host-devtools-setup.md)
- runtime and release validation: [`examples/runtime-validation.md`](examples/runtime-validation.md)
- acceptance bundles and delivery evidence: [`examples/acceptance-delivery.md`](examples/acceptance-delivery.md)
- failure reporting with evidence: [`examples/failure-with-evidence.md`](examples/failure-with-evidence.md)
