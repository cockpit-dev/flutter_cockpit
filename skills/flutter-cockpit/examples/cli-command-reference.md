# CLI Command Reference

Use this reference when you need to execute `flutter_cockpit_devtools` directly and do not want to guess command names or required arguments.

Always prefer copying one of these templates and filling in the concrete paths or IDs.

## Command Prefix

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools <command> ...
```

To inspect live help instead of guessing:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools help <command>
```

## Development Session Loop

### 1. Launch a development session

Android:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-development-session \
  --project-dir /abs/path/to/flutter_app \
  --target cockpit/main.dart \
  --platform android \
  --android-device-id emulator-5554 \
  --session-port 47331 \
  --launch-timeout-seconds 120 \
  --output-json /tmp/flutter_cockpit/development_session.json
```

iOS Simulator:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-development-session \
  --project-dir /abs/path/to/flutter_app \
  --target cockpit/main.dart \
  --platform ios \
  --ios-device-id "iPhone 17 Pro Max" \
  --session-port 47331 \
  --launch-timeout-seconds 120 \
  --output-json /tmp/flutter_cockpit/development_session.json
```

Desktop (macOS, Windows, or Linux):

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-development-session \
  --project-dir /abs/path/to/flutter_app \
  --target cockpit/main.dart \
  --platform macos \
  --session-port 47331 \
  --launch-timeout-seconds 120 \
  --output-json /tmp/flutter_cockpit/development_session.json
```

Use `--platform windows` or `--platform linux` for the other desktop hosts.

Required flags:
- `--project-dir`
- `--platform`

Usually also required:
- `--target`
- `--android-device-id` for Android
- `--ios-device-id` for iOS Simulator
- `--output-json`

### 2. Query development-session status

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  query-development-session \
  --session-json /tmp/flutter_cockpit/development_session.json \
  --output-json /tmp/flutter_cockpit/development_status.json
```

### 3. Hot reload or hot restart

Hot reload:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  reload-development-session \
  --session-json /tmp/flutter_cockpit/development_session.json \
  --mode hot_reload \
  --output-json /tmp/flutter_cockpit/reload.json
```

Hot restart:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  reload-development-session \
  --session-json /tmp/flutter_cockpit/development_session.json \
  --mode hot_restart \
  --output-json /tmp/flutter_cockpit/reload.json
```

### 4. Collect a development probe

Quick probe:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  collect-development-probe \
  --session-json /tmp/flutter_cockpit/development_session.json \
  --profile quick \
  --reason post_reload \
  --checkpoint after_reload \
  --output-json /tmp/flutter_cockpit/probe_after_reload.json
```

Interactive probe:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  collect-development-probe \
  --session-json /tmp/flutter_cockpit/development_session.json \
  --profile interactive \
  --reason manual \
  --checkpoint before_fix \
  --output-json /tmp/flutter_cockpit/probe_before_fix.json
```

Useful values:
- `--profile`: `quick`, `interactive`, `diagnostic`, `forensic`
- `--reason`: `manual`, `post_reload`, `post_action`, `failure`

### 5. Compare two probes

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  compare-development-probe \
  --from-probe-json /tmp/flutter_cockpit/probe_before_fix.json \
  --to-probe-json /tmp/flutter_cockpit/probe_after_reload.json \
  --output-json /tmp/flutter_cockpit/probe_diff.json
```

### 6. Stop the development session

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  stop-development-session \
  --session-json /tmp/flutter_cockpit/development_session.json \
  --output-json /tmp/flutter_cockpit/development_stop.json
```

## Remote Session Workflow

### 1. Launch a remote session

Android:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-remote-session \
  --project-dir /abs/path/to/flutter_app \
  --target cockpit/main.dart \
  --platform android \
  --android-device-id emulator-5554 \
  --session-port 47331 \
  --launch-timeout-seconds 120 \
  --output-json /tmp/flutter_cockpit/session.json
```

iOS Simulator:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-remote-session \
  --project-dir /abs/path/to/flutter_app \
  --target cockpit/main.dart \
  --platform ios \
  --ios-device-id "iPhone 17 Pro Max" \
  --session-port 47331 \
  --launch-timeout-seconds 120 \
  --output-json /tmp/flutter_cockpit/session.json
```

Desktop (macOS, Windows, or Linux):

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-remote-session \
  --project-dir /abs/path/to/flutter_app \
  --target cockpit/main.dart \
  --platform macos \
  --session-port 47331 \
  --launch-timeout-seconds 120 \
  --output-json /tmp/flutter_cockpit/session.json
```

Use `--platform windows` or `--platform linux` for the other desktop hosts.

### 2. Query remote-session health

Using the saved handle:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  query-remote-session \
  --session-json /tmp/flutter_cockpit/session.json \
  --output-json /tmp/flutter_cockpit/session_health.json
```

Using a base URL directly:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  query-remote-session \
  --base-url http://127.0.0.1:47331 \
  --output-json /tmp/flutter_cockpit/session_health.json
```

For Android base URL access from the host, add:

```bash
--android-device-id emulator-5554
```

### 3. Collect a remote snapshot

Baseline snapshot:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  collect-remote-snapshot \
  --session-json /tmp/flutter_cockpit/session.json \
  --profile baseline \
  --include-accessibility-summary \
  --output-json /tmp/flutter_cockpit/baseline_snapshot.json
```

Investigate-level snapshot with network and runtime evidence:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  collect-remote-snapshot \
  --session-json /tmp/flutter_cockpit/session.json \
  --profile investigate \
  --include-network-activity \
  --include-runtime-activity \
  --network-uri-contains /api/ \
  --runtime-only-errors \
  --output-json /tmp/flutter_cockpit/investigate_snapshot.json
```

Useful optional flags:
- `--include-style-details`
- `--include-diagnostic-properties`
- `--include-accessibility-summary`
- `--emit-artifact-when-large`
- `--max-targets`
- `--max-network-entries`
- `--max-runtime-entries`
- `--network-method`
- `--network-status-code-at-least`
- `--runtime-message-contains`

### 4. Run a control script against a live session

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-remote-control-script \
  --session-json /tmp/flutter_cockpit/session.json \
  --script-json /abs/path/to/control_script.json \
  --output-root /tmp/flutter_cockpit/out
```

Useful optional flags:
- `--android-device-id` for Android host forwarding
- `--ios-device-id` for iOS Simulator host recording
- no device-id flag is needed for macOS, Windows, or Linux desktop runs

## Task Workflow

`run-task` and `validate-task` both consume JSON config files. Do not guess the payload shape; start from a concrete template.

### Minimal `run-task` config

```json
{
  "launch": {
    "projectDir": "/abs/path/to/flutter_app",
    "target": "cockpit/main.dart",
    "platform": "android",
    "androidDeviceId": "emulator-5554",
    "sessionPort": 47331,
    "launchTimeoutSeconds": 120
  },
  "script": {
    "sessionId": "todo-acceptance-session",
    "taskId": "todo-acceptance-task",
    "commands": [
      {
        "type": "captureScreenshot",
        "reason": "baseline"
      }
    ]
  },
  "outputRoot": "/tmp/flutter_cockpit/out"
}
```

Run it:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-task \
  --config-json /tmp/flutter_cockpit/run_task.json \
  --output-json /tmp/flutter_cockpit/run_task_result.json
```

### Minimal `validate-task` config

```json
{
  "launch": {
    "projectDir": "/abs/path/to/flutter_app",
    "target": "cockpit/main.dart",
    "platform": "android",
    "androidDeviceId": "emulator-5554",
    "sessionPort": 47331,
    "launchTimeoutSeconds": 120
  },
  "script": {
    "sessionId": "todo-validate-session",
    "taskId": "todo-validate-task",
    "commands": [
      {
        "type": "captureScreenshot",
        "reason": "acceptance"
      }
    ]
  },
  "outputRoot": "/tmp/flutter_cockpit/out",
  "requireAcceptanceSemanticEvidence": true,
  "requireAcceptanceMarkdown": true,
  "requirePrimaryScreenshot": true
}
```

Run it:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/flutter_cockpit/validate_task.json \
  --output-json /tmp/flutter_cockpit/validate_task_result.json
```

## Practical Rules

- Prefer `launch-development-session` for iterative edit/reload work.
- Prefer `launch-remote-session` for one-off runtime verification or when you need a reusable live session without hot reload.
- Prefer `run-task` when the workflow is ready for structured orchestration.
- Prefer `validate-task` only when you are ready to make a final completion claim.
- Write every command result to `--output-json` so later AI steps can read structured state instead of scraping terminal text.
