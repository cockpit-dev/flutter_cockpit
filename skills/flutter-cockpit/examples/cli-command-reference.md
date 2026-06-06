# CLI Command Reference

Use this file when you need copy-ready `flutter_cockpit_devtools` commands.

Command prefix:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools <command> ...
```

## Basic App Loop

List available targets:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools list-targets
```

Choose `--platform` and `--device-id` from `list-targets`. Keep placeholders
in copied commands until discovery returns real values. Web ids are browser ids;
mobile ids are the reported emulator, simulator, or physical device ids.

Launch an app:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir /abs/path/to/flutter_app \
  --platform <platform-from-list-targets> \
  --device-id <device-id-from-list-targets> \
  --session-port 57331 \
  --mode development
```

If you omit `--app-json`, the CLI writes the reusable handle to `.dart_tool/flutter_cockpit/latest_app.json` in the current working directory and later app commands reuse it automatically.
When both `--app-json` and `--base-url` are provided, `--app-json` supplies app identity and platform metadata while `--base-url` overrides only the live connection address.
Add `--flavor <name>` when the app uses a non-default Android flavor or Xcode scheme.
For web, keep `--mode development`, and use the exact browser `--device-id` reported by `list-targets`.
Do not append `&` or otherwise background this command. It returns after the
app is ready; the supervisor continues in the background for logs, reloads, and
`stop-app`.

Read lightweight state:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --profile minimal
```

`read-app --profile standard` is still summary-only. It is good for `textPreviews` and counts, but not for a full target inventory.
For platform-specific powers such as browser DOM access, host shell automation, or browser-host recording, prefer `capabilities.capabilityProfile` over the older top-level booleans.

## Target-First Surface Loop

Launch a normalized target and persist `target.json`:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-target \
  --project-dir /abs/path/to/flutter_app \
  --platform <platform-from-list-targets> \
  --device-id <device-id-from-list-targets> \
  --session-port 57331 \
  --target-json /tmp/flutter_cockpit/target.json
```

For browser target-first work, automation launch is not a supported browser path. Use development mode with the concrete browser `--device-id` from `list-targets`, such as `chrome`.
`launch-target` now auto-normalizes the default `flutterApp` target kind to `browserPage` on web and `desktopApp` on desktop, so you usually do not need to pass `--target-kind`.

Read the smallest truthful target state:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-target \
  --target-json /tmp/flutter_cockpit/target.json \
  --profile minimal
```

Inspect the current target surface when the summary is still ambiguous:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  inspect-surface \
  --target-json /tmp/flutter_cockpit/target.json \
  --profile inspect
```

Run a shell command through a normalized target:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-shell \
  --scope target \
  --target-json /tmp/flutter_cockpit/target.json \
  --executable pwd
```

`run-shell` has a bounded default timeout and kills timed-out processes. Add `--timeout-seconds <n>` only when the shell action is known to be slow.

Run platform-explicit shells when you already know the device:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-shell \
  --scope android \
  --device-id emulator-5554 \
  --executable getprop \
  --arg ro.build.version.sdk
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-shell \
  --scope ios \
  --device-id A1B2C3D4-0000-1111-2222-333344445555 \
  --executable defaults \
  --arg read \
  --arg com.apple.Preferences
```

For desktop Flutter targets, `inspect-surface` can reuse remote semantic inspection when it is reachable and fall back to native/window capture only when that semantic path is unavailable.
Browser targets do not expose a direct device shell. For web work, stay on `inspect-surface` and app or target reads, or use `run-shell --scope host` only for host-side browser prerequisites and tooling.

## Native/System Control Plane

Use this only when Flutter semantic commands cannot control the required native UI, system dialog, device shell, desktop window, or non-Flutter surface. Read capabilities first and run only actions reported as `available`.
Capability rows include compact action payload contracts such as `parameters=[x*:integer | wifiBars:integer[0..3] | appearance*:string(light|dark)]`; `*` means required. Use those returned parameter names, ranges, and allowed values instead of guessing JSON keys or flags.

Read exact platform capabilities:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-system-capabilities \
  --platform <platform-from-list-targets> \
  --device-id <device-id-from-list-targets>
```

For desktop window evidence, add the app/window context from launch metadata:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-system-capabilities \
  --platform macos \
  --app-id <platform-app-id>
```

On Windows and Linux, use `--app-id <platform-app-id>` or
`--process-id <pid>` according to the returned launch metadata.

For shell pipelines, `--stdout-format json` exposes the same contract as structured
`capabilities[].parameters[]` entries:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-system-capabilities \
  --platform ios \
  --device-id <ios-simulator-udid> \
  --stdout-format json | jq '.capabilities[] | select(.action=="setStatusBar") | .parameters'
```

Drive a desktop native/system control after reading capabilities:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform macos \
  --app-id <bundle-id> \
  --action activateWindow

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform macos \
  --action tap \
  --x 120 \
  --y 240
```

Run a short Android system tap:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action tap \
  --x 120 \
  --y 240
```

Bring an Android app to the foreground when the package id is known:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --app-id <android-package-id> \
  --action activateWindow
```

Send an Android key event or terminate the app when a clean relaunch is needed:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action pressKey \
  --key enter

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --app-id <android-package-id> \
  --action terminateApp
```

Set Android emulator development environment state:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action setAppearance \
  --appearance dark

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action setContentSize \
  --content-size accessibility-large

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action setLocation \
  --latitude 37.3349 \
  --longitude -122.009

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action setOrientation \
  --orientation landscape

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action setNetworkSpeed \
  --network-speed full

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action setNetworkDelay \
  --network-delay none
```

iOS simulator app activation and permission setup:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform ios \
  --device-id <ios-simulator-udid> \
  --app-id <ios-bundle-id> \
  --action activateWindow

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform ios \
  --device-id <ios-simulator-udid> \
  --app-id <ios-bundle-id> \
  --action grantPermission \
  --permission photos
```

Set iOS simulator appearance, content size, or location for responsive and permission-sensitive flows:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform ios \
  --device-id <ios-simulator-udid> \
  --action setAppearance \
  --appearance dark

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform ios \
  --device-id <ios-simulator-udid> \
  --action setContentSize \
  --content-size accessibility-large

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform ios \
  --device-id <ios-simulator-udid> \
  --action setLocation \
  --latitude 37.3349 \
  --longitude -122.009

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform ios \
  --device-id <ios-simulator-udid> \
  --action setStatusBar \
  --time 09:41 \
  --data-network wifi \
  --wifi-mode active \
  --wifi-bars 3 \
  --battery-state charged \
  --battery-level 100

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform ios \
  --device-id <ios-simulator-udid> \
  --action clearStatusBar
```

Use iOS simulator clipboard when a native paste flow needs setup:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform ios \
  --device-id <ios-simulator-udid> \
  --action setClipboard \
  --text "value to paste"

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform ios \
  --device-id <ios-simulator-udid> \
  --action getClipboard
```

Read host/device system state as a low-token capability smoke check:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform macos \
  --action readSystemState
```

Read process/window context before choosing a native target:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action readProcessList

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform macos \
  --action readWindows

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform windows \
  --action readWindows

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform linux \
  --action readWindows
```

Read a bounded native desktop accessibility tree when Flutter semantics cannot see the target:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform macos \
  --app-id <bundle-id> \
  --action readUiTree \
  --max-depth 4 \
  --max-nodes 120

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform windows \
  --process-id <pid> \
  --action readUiTree \
  --max-depth 4 \
  --max-nodes 120
```

Capture a native/system screenshot to a real file:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action captureScreenshot \
  --name system-proof \
  --output-path /tmp/flutter_cockpit/system-proof.png
```

Record a native/system flow without blocking the agent:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action startRecording \
  --name system-flow \
  --purpose repro \
  --mode native \
  --layer system

# drive the system/native flow, then stop
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-system-action \
  --platform android \
  --device-id emulator-5554 \
  --action stopRecording \
  --output-path /tmp/flutter_cockpit/system-flow.mp4
```

Inspect richer UI state:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  inspect-ui \
  --profile inspect
```

Run one command:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --command-json '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}'
```

Tap a route-changing control with a top-level locator:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --command-json '{"commandId":"tap-settings","commandType":"tap","locator":{"text":"Settings"},"parameters":{"expectedRouteName":"/settings","routeTimeoutMs":5000}}' \
  --profile standard
```

Enter text into a field:

```bash
jq -n --arg text "Draft release checklist" '{
  commandId: "enter-title",
  commandType: "enterText",
  locator: {
    type: "TextField",
    ancestor: {
      route: "<editor-route>"
    }
  },
  parameters: {
    text: $text
  }
}' >/tmp/flutter_cockpit/enter_text.json

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --command-file /tmp/flutter_cockpit/enter_text.json \
  --profile standard --stdout-format json | jq '{success: .command.success, route: .uiSummary.routeName}'
```

Scroll to a deep control with one locator:

```bash
jq -n '{
  commandId: "reveal-sync-card",
  commandType: "scrollUntilVisible",
  locator: {
    text: "Acceptance bundles",
    ancestor: {
      route: "/settings"
    }
  },
  parameters: {
    maxScrolls: 8,
    viewportFraction: 0.55
  }
}' >/tmp/flutter_cockpit/scroll_command.json

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --command-file /tmp/flutter_cockpit/scroll_command.json \
  --profile standard --stdout-format json | jq '{command: .command.success, route: .uiSummary.routeName, visible: .uiSummary.visibleTargetCount}'
```

Run a short batch:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-batch \
  --commands-json '[
    {"commandId":"wait-1","commandType":"waitForUiIdle"},
    {"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}
  ]'
```

If a banner, snackbar, or bottom sheet appears, or a collection mutation changes layout, do not assume the next target stayed in the same place. Re-anchor or scroll again before the next deep tap.

Wait for idle:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools wait-idle
```

Capture final visible proof without writing command JSON:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  capture-screenshot \
  --name acceptance \
  --profile inspect
```

## Persistent Development Loop

Use this when one app will be edited and reloaded repeatedly. The default
app-first loop is still cheaper for short tasks.

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-development-session \
  --project-dir /abs/path/to/flutter_app \
  --platform <platform-from-list-targets> \
  --device-id <device-id-from-list-targets> \
  --session-json /tmp/flutter_cockpit/dev_session.json \
  --app-json /tmp/flutter_cockpit/app.json
```

`launch-development-session` also writes an app handle. Use that handle for
app-scoped recording commands instead of external screen-recording tools.

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  collect-development-probe \
  --session-json /tmp/flutter_cockpit/dev_session.json \
  --profile quick \
  --checkpoint before_edit \
  --output /tmp/flutter_cockpit/before_probe.json \
  --output-format json
```

After edits:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  reload-development-session \
  --session-json /tmp/flutter_cockpit/dev_session.json \
  --mode hot_reload
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  collect-development-probe \
  --session-json /tmp/flutter_cockpit/dev_session.json \
  --profile quick \
  --reason post_reload \
  --checkpoint after_reload \
  --output /tmp/flutter_cockpit/after_probe.json \
  --output-format json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  compare-development-probe \
  --from-probe-json /tmp/flutter_cockpit/before_probe.json \
  --to-probe-json /tmp/flutter_cockpit/after_probe.json
```

Stop the persistent session when the loop ends:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  stop-development-session \
  --session-json /tmp/flutter_cockpit/dev_session.json
```

## Direct Remote Session Loop

Use this only when you intentionally want the lower-level session handle surface
instead of the app-first `app.json` commands.

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-remote-session \
  --project-dir /abs/path/to/flutter_app \
  --platform <platform-from-list-targets> \
  --device-id <device-id-from-list-targets> \
  --session-json /tmp/flutter_cockpit/session.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-remote-status \
  --session-json /tmp/flutter_cockpit/session.json \
  --profile minimal
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  execute-remote-command-batch \
  --session-json /tmp/flutter_cockpit/session.json \
  --commands-file /tmp/flutter_cockpit/commands.json \
  --default-profile minimal \
  --final-snapshot-profile standard
```

Read network after an action settles:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-network \
  --uri-contains /api \
  --only-failures
```

Read logs or runtime errors:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-logs
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-errors
```

Hot reload or hot restart:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  hot-reload --stdout-format json | jq '{reloadGeneration: .status.reloadGeneration, lastReloadSucceeded: .status.lastReloadSucceeded, lastReloadMode: .status.lastReloadMode}'
```

Then verify the changed control. If the intended copy or layout delta is still missing, relaunch once before assuming the app ignored your code edit.

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  hot-restart --stdout-format json | jq '{reloadGeneration: .status.reloadGeneration, lastReloadSucceeded: .status.lastReloadSucceeded, lastReloadMode: .status.lastReloadMode}'
```

Stop the app only for cleanup or recovery:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools stop-app
```

## Recording

Assumes a prior `launch-app` or `launch-development-session` in the same workspace, or an explicit reusable app handle.
Use recording only when motion, transition, repro timing, or acceptance video is part of the current proof. For static copy, spacing, color, route, or error checks, prefer hot reload plus minimal reads and a still screenshot when visible proof is needed.

Start recording:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  start-recording
```

The default request is a repro recording with auto mode, a sortable filename,
and a 1400 ms tail. Add `--recording-json` only for acceptance evidence, full
screen capture, or strict layer/fallback control.

Stop recording:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  stop-recording \
  --app-json /tmp/flutter_cockpit/app.json
```

For normal development proof, use `state: "completed"` plus the returned
recording artifact ref. Do not add separate file or content validation unless
the recording command failed, the artifact metadata is contradictory, or the
user explicitly asks to inspect media content.

When an iOS recording command has only `--base-url` and cannot read an
`app.json` handle, pass `--ios-device-id <id>` so the host-side simulator or
device adapter can select the right recorder. Prefer `app.json` when available
because it also preserves platform app id, process id, and remote-session
metadata.

For development-loop recording, do not leave flutter_cockpit for `simctl`,
QuickTime, Chrome DevTools, or shell screen capture until framework recording
has failed with a concrete `recordingStrategyUnavailable`,
`recordingStartFailed`, or environment-prerequisite message. Use
bare `start-recording` before the risky edit/reload/interaction window and
`stop-recording` immediately after the proof point, or use
`run-batch --recording-json` when the whole flow is deterministic or needs
explicit acceptance/full recording options.

For local web validation, keep browser app control, screenshots, reloads, and
runtime-error reads strict. If browser-host recording is blocked only because
the desktop has not granted screen-capture permission yet or ffmpeg cannot prove
startup/output evidence, classify that as an environment prerequisite warning
and keep the app-control result separate. Do not claim video recording coverage
for that run unless the recording command reports a completed artifact.

## Bundle And Delivery

Use this section for acceptance, release readiness, or artifact-backed handoff. It is not the default loop for small edits.

Run a script against a running app:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-script \
  --app-json /tmp/flutter_cockpit/app.json \
  --script-json /tmp/flutter_cockpit/script.json \
  --output-root /tmp/flutter_cockpit/out
```

Prefer `--app-json` for `run-script` even when `--base-url` is known. The app
handle preserves platform, device, process, and remote-session metadata used by
host screenshots and recordings; `--base-url` only overrides the live HTTP
connection.

Run a full task workflow:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-task \
  --config-json /tmp/flutter_cockpit/run_task.json
```

Validate a full task workflow:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/flutter_cockpit/validate_task.json
```

Read the compact delivery summary from an existing bundle:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-task-bundle-summary \
  --bundle-dir /tmp/flutter_cockpit/out/20260530T060304005006Z_session-1
```

Default stdout is the AI-readable result. Use `--stdout-format json | jq ...`
only when a shell pipeline needs structured filtering.
For ordinary development, stop at the rapid loop once the post-action state, current errors, and any required named screenshot answer the user's question.

## MCP

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

When an MCP host already supplies roots but the task needs an adjacent repo,
call `add_roots`; manual roots merge with native roots instead of replacing
them.

## Notes

- Persist `app.json` and reuse it across commands.
- `launch-app` auto-detects `cockpit/main.dart` first, then `lib/main.dart`.
- Default to rapid development validation: ask the runtime for the smallest fact that reduces current uncertainty, then stop.
- Default to `--profile minimal` or `standard`.
- Escalate to `inspect` or `evidence` only when required.
- Large forensic snapshots stay summary-first in normal reads. If a result has
  `artifactDownloads`, inspect those paths only when the summary and
  diagnostics ref are not enough; use `collect-remote-snapshot
  --emit-artifact-when-large --output <path> --output-format json` to preserve deferred evidence
  metadata, and add `--download-diagnostics-artifacts` only when you
  intentionally need the full externalized diagnostics payload in the JSON
  output.
- `scrollUntilVisible` already probes between internal scroll segments. Prefer a better locator or a smaller `viewportFraction` over manual repeated blind scroll commands.
- When `scrollUntilVisible` hits the wrong boundary first, it can recover by trying the opposite direction once. Keep explicit `reverse` for cases where you already know the target is above the current viewport.
- After `hot-restart`, do not assume route and scroll position reset. Re-read route, then re-anchor or switch `reverse` if the target region is now above the viewport.
- `enterText` success does not guarantee that `uiSummary.textPreviews` will echo the entered value. Prefer validating the next visible control, route change, or saved list state.
- When a locator returns `ambiguousTarget`, prefer adding `index`, `ancestor`, or `type` before changing any app code.
- `list_apps` is MCP-only. CLI app recovery is `app.json` or `.dart_tool/flutter_cockpit/latest_app.json` first; target discovery is `list-targets`.
- For target-first CLI loops, persist `target.json` and reuse it across commands the same way you reuse `app.json`.
- `run-script` exits non-zero when the written bundle status is `failed`.
- Write command output to `--output <path> --output-format json` when a later AI step must read structured state with tools such as `jq`; otherwise `--output <path>` defaults to the AI-readable semantic render.
- Prefer the lowest-cost public surface: in shell agents, CLI + command files + `jq` usually costs fewer tokens than reopening large payloads in model context; in tool-calling hosts, MCP is fine.

For short dependent flows, prefer `run-batch` so one request carries the whole ordered chain:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-batch \
  --app-json /tmp/flutter_cockpit/app.json \
  --commands-file /tmp/flutter_cockpit/commands.json \
  --profile minimal --stdout-format json | jq '{summary, commandStatuses: [.results[] | {id: .command.commandId, success: .command.success}]}'
```

When the same short flow needs motion or acceptance video, wrap the batch with recording instead of manually pairing `start-recording` and `stop-recording`:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-batch \
  --app-json /tmp/flutter_cockpit/app.json \
  --commands-file /tmp/flutter_cockpit/commands.json \
  --recording-json '{"purpose":"acceptance","name":"acceptance","tailStabilizationMs":1400}' \
  --profile minimal \
  --final-profile standard \
  --stdout-format json | jq '{summary, recording: .recordingResult.artifact.relativePath, finalRoute: .finalSnapshot.routeName}'
```

For iOS batch recording without `app.json`, add `--ios-device-id <id>` for the
same reason as manual start/stop recording.

## Pipe And jq Examples

Search a dependency package before opening files:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  grep-package-uris \
  --package flutter \
  --query ThemeData --stdout-format json | jq '{summary, firstMatch: .packages[0].files[0].packageUri}'
```

Read only the route and state:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile minimal --stdout-format json | jq '{sessionId,currentRouteName,state}'
```

Extract one scalar:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile minimal --stdout-format json | jq -r '.currentRouteName'
```

Keep a larger result on disk, then read only the needed fields:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/flutter_cockpit/validate_task.json \
  --output /tmp/flutter_cockpit/validate_task_result.json \
  --output-format json
```

```bash
jq '{classification,recommendedNextStep,validationFailures}' \
  /tmp/flutter_cockpit/validate_task_result.json
```

Prefer command files over long inline JSON:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/flutter_cockpit/app.json \
  --command-file /tmp/flutter_cockpit/command.json \
  --profile standard
```
