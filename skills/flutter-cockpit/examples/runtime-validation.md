# Runtime Validation Example

Use this pattern when the task needs live app evidence.

## Recommended Flow

1. `launch-app`
2. `read-app --profile minimal`
3. `run-command` or `run-batch`
4. `inspect-ui`, `read-network`, `read-errors`, `read-logs`, or `wait-idle` only when needed
5. `hot-reload` or `hot-restart` during active development
6. repeat until correct

When the task is not purely Flutter UI, switch to:

1. `launch-target`
2. `read-target --profile minimal`
3. `inspect-surface` or `run-shell`
4. `read_task_bundle_summary` or `validate-task`

Use `run-shell` only when the resolved target truthfully exposes shell control. Browser targets stay `read-target` and `inspect-surface` first; any browser prerequisite checks should use host shell scope instead of a browser device shell.

Target-first example:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-target \
  --project-dir examples/cockpit_demo \
  --platform web \
  --device-id chrome \
  --target-json /tmp/flutter_cockpit/target.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-target \
  --target-json /tmp/flutter_cockpit/target.json \
  --profile minimal
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  inspect-surface \
  --target-json /tmp/flutter_cockpit/target.json \
  --profile inspect
```

## Example

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir examples/cockpit_demo \
  --platform macos \
  --device-id macos \
  --app-json /tmp/flutter_cockpit/app.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile minimal
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/flutter_cockpit/app.json \
  --command-json '{"commandId":"assert-inbox","commandType":"assertText","parameters":{"text":"Inbox"}}'
```

For this repository's demo app, finish the platform sweep with the example-local verifier:

```bash
cd examples/cockpit_demo
dart run tool/verify_platforms.dart --output-json /tmp/cockpit_demo_all_platforms_verification.json
```

Or from the repository root:

```bash
dart run examples/cockpit_demo/tool/verify_platforms.dart --output-json /tmp/cockpit_demo_all_platforms_verification.json
```

Without `--platform`, that command runs the local default sweep on macOS, iOS Simulator, and Android Emulator.
The `runtime-loop` CI workflow invokes the same verifier explicitly on Linux, Windows, and web too, one platform per job.
When the host can run desktop Linux or Windows locally, pass `--platform linux` and `--platform windows` explicitly to extend the sweep.
It validates `run-batch`, `inspect-ui`, `wait-idle`, `read-network`, `read-errors`, `read-logs`, `inspect-surface`, screenshot capture, recording, `hot-reload`, and `hot-restart`.
Recording is platform-aware in that sweep: macOS, Linux, and Windows use the remote recording path, web uses `browser-host`, iOS Simulator uses `simctl`, and Android Emulator uses `adb`.
For local macOS web runs where desktop recording permission is still blocked, add `--allow-web-host-recording-prerequisite-failure` so the verifier reports a structured warning instead of failing the whole runtime loop.

For release-grade MCP and target-first verification in this repository, run:

```bash
cd packages/flutter_cockpit_devtools
dart run tool/verify_mcp_surface.dart
```

That verifier exercises the real `serve-mcp` stdio surface, workspace tooling, target-first commands, and delivery tools (`run-script`, `run-task`, `validate-task`) end to end.

## Expected Agent Behavior

- keep `app.json`
- let `launch-app` auto-detect `cockpit/main.dart` before spelling out a target
- start with the smallest useful profile
- do not trust command success without a follow-up read
- if the workflow used target-first control, inspect `targetKind`, `primaryExecutionPlane`, `planesUsed`, and `fallbackCount` before claiming success
- for network questions, prefer `run-command` -> `wait-idle` -> `read-network`
- prefer app-centric `read-logs` before tailing host-supervisor logs
- prefer `read-network` over full UI snapshots when the missing fact is about requests, failures, or endpoint coverage
- treat `read-logs` with `available=true` and empty `lines` as “no app logs emitted”, not as an automatic failure
- use `blocked_by_environment` when the app never becomes reachable
