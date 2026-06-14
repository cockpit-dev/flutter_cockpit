---
name: flutter-cockpit
description: Use when a Flutter app or adjacent browser, desktop, device, or host-control task must prove live UI, interaction, route, network, recording, screenshot, or acceptance state with runtime evidence instead of code-only reasoning.
---

# Flutter Cockpit

## Overview

Flutter Cockpit is an AI loop, not a screenshot tool or command catalog. Default to rapid development validation: prove the current change with the cheapest live loop that answers the user, then stop. Claims follow:

`assess -> bootstrap -> baseline -> execute -> observe -> judge -> deliver`

Command success is not product proof; prove state, errors, and evidence.

These stages are decision gates, not a fixed command script or command quota. Satisfy each gate with the smallest fresh evidence available; skip irrelevant commands; choose CLI, MCP, app-first, target-first, persistent-session, or bundle flows.

## When To Use

- Live UI, route, interaction, network, log, screenshot, recording, or acceptance proof is needed.
- A Flutter app, browser, desktop window, simulator, emulator, device, or host needs control.

## First-Time App Wiring

Add `flutter_cockpit`, add `cockpit/main.dart`, and keep the production entrypoint intact. Do not add `flutter_cockpit` imports to production `lib/` code. The default runtime package is intentionally Dart/Flutter-first on mobile and desktop, so using it from `dev_dependencies` must not auto-register Cockpit native plugins into production bundles. In `cockpit/`, wrap with `FlutterCockpitApp` or `FlutterCockpit.runApp`, register `FlutterCockpit.navigatorObserver` only in the cockpit-owned navigator, and enable `CockpitRemoteSessionConfiguration.resolveFromEnvironment(...)`. For app-owned routers, call `FlutterCockpit.setCurrentRouteName(...)`; do not patch production `lib/` unless accepted.

## Stage Protocol

1. **assess**: choose the smallest truthful surface. Default to app-first. If platform/device is unknown, run `list-targets` and use the returned platform, device id, and capability metadata. Do not guess ids, commands, payload keys, or locator types.
2. **bootstrap**: launch once or reuse a handle. `launch-app` returns after readiness; never shell-background it. Reuse `.dart_tool/flutter_cockpit/latest_app.json`. Use target-first only for non-plain surfaces.
3. **baseline**: read before acting, unless a fresh equivalent read already answers the same question. Start with `read-app --profile minimal` or `read-target --profile minimal`; capture route, visible state, reachability, and errors.
4. **execute**: edit, prefer `hot-reload`, and drive UI with `run-command` or short `run-batch`. For route changes, include `expectedRouteName`. After timeout, `remoteUnavailable`, or failed non-idempotent batch, re-read minimal state and resume from the smallest remaining safe step; do not replay blindly.
5. **observe**: read post-action state before judging. Use `read-app`, `read-errors --max-errors 10`, `inspect-ui`, or `read-network`. If focus blocks controls, run `dismissKeyboard`. For visible UI claims, run `capture-screenshot --name <proof-name>`. For animation, transition, gesture, or repro, use framework recording first.
6. **judge**: compare baseline, observed state, and outcome. Do not open screenshots, videos, or raw artifacts unless the content is the unresolved question, the artifact looks wrong, or the user asks.
7. **deliver**: for acceptance work, run `validate-task` and report the smallest useful evidence. `stop-app` is cleanup or recovery only, not a normal loop step.

## Fast Command Pack

Use default AI-readable stdout. Add `--stdout-format json` only for `jq`; add `--output <path>` for file output, and `--output-format json` only for machine-readable files.

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

```bash
printf '%s\n' '{"commandId":"tap-settings","commandType":"tap","locator":{"text":"Settings"},"parameters":{"expectedRouteName":"/settings","routeTimeoutMs":5000}}' >/tmp/flutter_cockpit_command.json
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --command-file /tmp/flutter_cockpit_command.json --profile standard
```

## Escalation Commands

Use these only when the next claim needs them; do not add them to every loop.

Visible final proof:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools capture-screenshot --name acceptance --profile inspect
```

Short deterministic flow:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-batch --commands-file /tmp/flutter_cockpit_batch.json --profile standard
```

Motion, transition, gesture, or bug-repro video:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools start-recording
# optional: add --recording-json '{"purpose":"repro","name":"flow-name"}'
dart run flutter_cockpit_devtools:flutter_cockpit_devtools stop-recording
```

Native/system or non-Flutter surface after Flutter semantics cannot answer it:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-system-capabilities [--platform <platform>] [--device-id <device-or-simulator-id>] [--app-id <app-id>] [--process-id <pid>] [--wda-url http://127.0.0.1:8100]
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-system-action [--platform <platform>] [--device-id <device-or-simulator-id>] [--app-id <app-id>] [--process-id <pid>] [--wda-url http://127.0.0.1:8100] --action <available-action>
```

Use `parameters=[name*:type[range](allowed|values)]`; `*` means required. Do not guess payload keys.
Both commands reuse `.dart_tool/flutter_cockpit/latest_app.json` and resolve platform app ids by default. `--app-id` means native app id; current Cockpit app id maps to `platformAppId` when available. On iOS simulator, prefer `grantPermission`; use WebDriverAgent only when Flutter semantics and simctl cannot handle native UI, system dialogs, keyboard/focus, orientation, notifications, Notification Center, or Control Center. Cockpit probes `http://127.0.0.1:8100` unless configured; WDA actions stay blocked unless reachable.
If `run-system-action` returns `invalidSystemActionParameter` or `missingSystemActionParameter`, re-run `read-system-capabilities`, copy lower-camel-case parameter names, required markers, allowed values, and numeric ranges, then send only that payload.
For `dismissSystemDialog`, use `--decision accept` for the primary action or `--decision dismiss` for the cancel/deny action; omit it to accept.
For native blockers, prefer `resolveBlockers`. Use `preparePermissions`, `stabilizeForScreenshot`, `readFocusState`, and `tapNotification`; then read app state and errors.
Use `actionGroups` in JSON output to find capability groups without hard-coding platform lists.
Android Emulator uses adb for input, lifecycle, permissions, settings, orientation, networking, connectivity/battery simulation, notifications, demo-mode status bar, recovery, files/media, evidence, UI tree, focus/IME, state, logcat (`readSystemLogs`), and bounded shell.
iOS Simulator uses simctl for lifecycle, privacy, locale, status bar, pasteboard, app-container files, media, recovery, evidence, device info, unified log (`readSystemLogs`), and bounded `simctl spawn`; non-absolute shell runs through `/bin/sh -lc`. WDA covers native UI, keyboard/focus, orientation, notifications, and system dialogs/blockers. Unsupported simulator actions remain blocked instead of faked.
When the app crashes before the runtime observer attaches, use `run-system-action --action readSystemLogs` for native logs instead of `read-logs`.
`activateWindow` is non-destructive on iOS Simulator and should not terminate an existing Flutter debug or hot-reload session; use `terminateApp` only when a restart is intentional.
Trust only actions reported as `available`.
Desktop coordinates use screen pixels. macOS host screenshots/recordings need `--app-id`; Windows/Linux can use `--app-id` or `--process-id`. Desktop hosts also expose settings entry, host appearance, clipboard, host file/media copy, focus/device reads, notifications, and macOS `tccutil` permission resets; web evidence uses host window capture once the browser app id or process id is known. If an action is not `available`, follow its requirement/fallback or report `blocked_by_environment`.

Acceptance, release readiness, or artifact-backed handoff:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools validate-task --config-json /tmp/flutter_cockpit_validate_task.json
```

## Development Defaults

- Fast path for most edits: reuse or launch app -> `read-app --profile minimal` -> edit -> `hot-reload` -> smallest post-action read -> `read-errors --max-errors 10` -> screenshot for visible UI claims.
- Use `minimal -> standard -> inspect -> evidence`; escalate only when needed.
- Be flexible on commands, strict on proof.
- Every command should reduce uncertainty. Do not run recording, evidence profiles, bundle validation, or raw artifact reads just because they exist.
- Keep platform and device placeholders until `list-targets` returns real values; read capabilities before choosing shell, recording, browser, or native paths.
- Prefer file inputs: `--command-file`, `--commands-file`, config JSON.
- Safe commands: `tap`, `enterText`, `dismissKeyboard`, `assertText`, `scrollUntilVisible`.
- Safe locator keys: `text`, `tooltip`, `semanticId`, `type`, `ancestor`, `index`, `fallbacks`; Do not set `type: Text` for button labels.
- Keep the app alive while more edits are likely. Stop only when the user asks, the session is stuck, `hot-restart` cannot recover, or a clean rebuild/relaunch is required.

## Failure Recovery

- If syntax is unclear, run `help <command>` or open one reference file.
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
- Relaunching or stopping after every edit instead of hot reload plus bounded reads.
- Treating command success, bundle completion, or artifact existence as product proof.
- Using external screenshot or recording tools before framework screenshot or recording.
- Opening large artifacts before summaries identify the missing fact.
- Claiming completion without baseline, post-action state, errors, and evidence.

## Reference Map

Deep dives: [`examples/cli-command-reference.md`](examples/cli-command-reference.md), [`examples/rapid-dev-loop.md`](examples/rapid-dev-loop.md), [`examples/flutter-app-setup.md`](examples/flutter-app-setup.md), [`examples/host-devtools-setup.md`](examples/host-devtools-setup.md), [`examples/runtime-validation.md`](examples/runtime-validation.md), [`examples/acceptance-delivery.md`](examples/acceptance-delivery.md), [`examples/failure-with-evidence.md`](examples/failure-with-evidence.md).
