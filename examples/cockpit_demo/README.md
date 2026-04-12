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

Bootstrap the workspace first:

```bash
dart run melos bootstrap
```

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
  --device-id macos \
  --app-json /tmp/flutter_cockpit_demo_macos_app.json
```

Web:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir examples/cockpit_demo \
  --platform web \
  --device-id chrome \
  --app-json /tmp/flutter_cockpit_demo_web_app.json
```

## Full Verifier

Run the example-local verifier:

```bash
cd examples/cockpit_demo
dart run tool/verify_platforms.dart \
  --output-json /tmp/cockpit_demo_verification.json
```

The verifier covers:

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
  --output-json /tmp/cockpit_demo_web_verification.json
```

That mode keeps the verifier strict for app control, screenshots, and reload flows while surfacing blocked browser-host recording as a structured warning.

## What To Inspect

When driving the demo through `read-app` or `read-target`:

- use `selectedPlane` to understand the primary interaction plane
- use `capabilities.capabilityProfile` as the canonical source of platform-specific powers
- use `recordingCapabilities.recordingLimitations` to detect host prerequisites or capture scope constraints before starting a recording

## CI

The repository-level workflow is:

- [`.github/workflows/runtime-loop.yml`](../../.github/workflows/runtime-loop.yml)

That workflow runs the same example verifier per platform and uploads the resulting bundles and logs as CI artifacts.
