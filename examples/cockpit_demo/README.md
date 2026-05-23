# cockpit_demo

`cockpit_demo` is the repository's production-grade validation app for `flutter_cockpit` and `flutter_cockpit_devtools`.

It is not a throwaway sample. The demo is the executable proof target used by:

- local development-loop validation
- platform verifier runs
- runtime-loop CI
- real web bridge coverage
- MCP surface verification

## Supported Validation Targets

- `macos`
- `ios` simulator
- `android` emulator
- `linux`
- `windows`
- `web` in Chrome

The local default verifier sweep runs `macos`, `ios`, and `android`.
CI extends the same verifier to `linux`, `windows`, and `web`.

## Local Setup

Use Flutter 3.32.0 or newer for this repository and demo app.

Bootstrap the workspace first:

```bash
dart run melos bootstrap
```

Host prerequisites for the full verifier:

- install `ffmpeg` on the host machine; desktop and browser-host recording flows depend on it
- for local web verification, install Chrome and allow the browser plus host capture stack to use screen recording
- for iOS simulator verification, Xcode command-line tools and `xcrun simctl` must be available
- for Android verification, `adb` plus a bootable emulator must already be available

If you want to validate web locally, prepare the generated worker and wasm assets:

```bash
cd examples/cockpit_demo
dart run tool/prepare_web_assets.dart
```

That script compiles `web/drift_worker.dart` into `web/drift_worker.js` and copies `sqlite3.wasm` into the web bundle.

## Launch Examples

macOS:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir examples/cockpit_demo \
  --platform macos \
  --device-id macos
```

Web:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir examples/cockpit_demo \
  --platform web \
  --device-id chrome
```

When `--app-json` is omitted, `launch-app` writes the reusable handle to `.dart_tool/flutter_cockpit/latest_app.json` in the current working directory. The next `read-app`, `inspect-ui`, `run-command`, `hot-reload`, and `stop-app` calls can reuse it without extra flags.
If a command also accepts `--base-url`, precedence is explicit `--app-json`, then explicit `--base-url`, then the implicit latest-app handle in the working directory.

## Target-First Examples

When the task is not purely an app-first semantic loop, drive the same demo through the target-first surface:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-target \
  --project-dir examples/cockpit_demo \
  --platform web \
  --device-id chrome \
  --target-json /tmp/cockpit_demo_target.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-target \
  --target-json /tmp/cockpit_demo_target.json \
  --profile minimal
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  inspect-surface \
  --target-json /tmp/cockpit_demo_target.json \
  --profile inspect
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-shell \
  --scope host \
  --executable pwd
```

Persist `target.json` the same way you persist `app.json`: keep it around for the whole loop instead of relaunching the target on every step. Browser targets do not expose a direct device shell, so browser prerequisite checks stay on `--scope host`.

## Full Verifier

For fast feature development on the local machine, run the rapid verifier first:

```bash
dart run examples/cockpit_demo/tool/verify_rapid_dev.dart \
  --output /tmp/cockpit_demo_rapid_dev.json
```

The rapid verifier defaults to `macos`, `ios`, and `android`. It is intentionally
lighter than the full verifier: it launches the app, creates one high-priority
task due today, proves the `Queue brief` summary, hot reloads, re-asserts the
state, captures one screenshot, reads runtime errors, and stops the app.
Use it for the normal AI edit -> reload -> assert loop before paying the cost
of recordings, network/log reads, hot restart, and Sync Lab conflict recovery.

The rapid verifier also isolates the demo database before launch on Android,
iOS Simulator, and macOS. If it fails, inspect the output JSON before rerunning:
`verifiedCommands` shows the last completed phase, `failureDetails` includes
the failed command and final text previews, and `runtimeErrorPreviews` carries
bounded Flutter runtime errors. A `Queue brief` count larger than expected is a
state-isolation problem until those fields prove a UI bug.

Run the example-local verifier:

```bash
cd examples/cockpit_demo
dart run tool/verify_platforms.dart \
  --output /tmp/cockpit_demo_verification.json
```

From the repository root you can also run:

```bash
dart run examples/cockpit_demo/tool/verify_platforms.dart \
  --output /tmp/cockpit_demo_verification.json
```

The tool now resolves `examples/cockpit_demo` as its default `--project-dir` automatically when launched through the repository-owned entrypoint.

The full verifier covers:

- `launch-app`
- `read-app`
- `inspect-ui`
- `run-batch`
- `wait-idle`
- `read-network`
- `read-errors`
- `read-logs`
- `inspect-surface`
- screenshot capture
- recording
- `hot-reload`
- `hot-restart`

Recording is platform-aware:

- `remote` on `macos`, `linux`, and `windows`
- `browser-host` on `web`
- `simctl` on `ios`
- `adb` on `android`

For local macOS web validation, if the desktop has not yet granted screen-capture permission to the terminal, Dart, or `ffmpeg`, use:

```bash
cd examples/cockpit_demo
dart run tool/verify_platforms.dart \
  --platform web \
  --allow-web-host-recording-prerequisite-failure \
  --output /tmp/cockpit_demo_web_verification.json
```

That mode keeps the verifier strict for app control, screenshots, and reload flows while surfacing blocked browser-host recording as a structured warning.

## What To Inspect

When driving the demo through `read-app` or `read-target`:

- use `selectedPlane` to understand the primary interaction plane
- use `capabilities.capabilityProfile` as the canonical source of platform-specific powers
- use `recordingCapabilities.recordingLimitations` to detect host prerequisites or capture scope constraints before starting a recording
- use `syncStatus`, `pendingTaskCount`, `failedTaskCount`, and `conflictTaskCount` as the summary-first sync health view before opening heavier inspections
- when the next few actions are already known and the flow will cross routes such as `/inbox -> /editor -> /inbox`, prefer one `run-batch` instead of multiple `run-command` calls; this is both lower-token and more stable for short editor or settings loops

The example now also ships a repository-owned Sync Lab workflow covering:

- queued local edits
- mixed sync outcomes
- conflict-only filtering
- in-product conflict resolution
- retry after resolution

## CI

The repository-level workflow is:

- [`.github/workflows/runtime-loop.yml`](../../.github/workflows/runtime-loop.yml)

That workflow runs the same example verifier per platform and uploads the resulting bundles and logs as CI artifacts.
