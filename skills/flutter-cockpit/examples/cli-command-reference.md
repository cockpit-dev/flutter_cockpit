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

Launch an app and persist `app.json`:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir /abs/path/to/flutter_app \
  --platform macos \
  --device-id macos \
  --session-port 57331 \
  --mode development \
  --app-json /tmp/flutter_cockpit/app.json
```

Read lightweight state:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile minimal
```

Inspect richer UI state:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  inspect-ui \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile inspect
```

Run one command:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/flutter_cockpit/app.json \
  --command-json '{"command_id":"assert-inbox","command_type":"assert_text","parameters":{"text":"Inbox"}}'
```

Run a short batch:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-batch \
  --app-json /tmp/flutter_cockpit/app.json \
  --commands-json '[
    {"command_id":"wait-1","command_type":"wait_for_ui_idle"},
    {"command_id":"assert-inbox","command_type":"assert_text","parameters":{"text":"Inbox"}}
  ]'
```

Wait for idle:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  wait-idle \
  --app-json /tmp/flutter_cockpit/app.json
```

Read network after an action settles:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-network \
  --app-json /tmp/flutter_cockpit/app.json \
  --uri-contains /api \
  --only-failures
```

Read logs or runtime errors:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-logs \
  --app-json /tmp/flutter_cockpit/app.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-errors \
  --app-json /tmp/flutter_cockpit/app.json
```

Hot reload or hot restart:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  hot-reload \
  --app-json /tmp/flutter_cockpit/app.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  hot-restart \
  --app-json /tmp/flutter_cockpit/app.json
```

Stop the app:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  stop-app \
  --app-json /tmp/flutter_cockpit/app.json
```

## Recording

Start recording:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  start-recording \
  --app-json /tmp/flutter_cockpit/app.json \
  --recording-json '{"purpose":"acceptance","tail_stabilization_ms":1400}'
```

Stop recording:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  stop-recording \
  --app-json /tmp/flutter_cockpit/app.json
```

## Bundle And Delivery

Run a script against a running app:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-script \
  --app-json /tmp/flutter_cockpit/app.json \
  --script-json /tmp/flutter_cockpit/script.json \
  --output-root /tmp/flutter_cockpit/out
```

Run a full task workflow:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-task \
  --config-json /tmp/flutter_cockpit/run_task.json \
  --output-json /tmp/flutter_cockpit/run_task_result.json
```

Validate a full task workflow:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/flutter_cockpit/validate_task.json \
  --output-json /tmp/flutter_cockpit/validate_task_result.json
```

## MCP

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

## Notes

- Persist `app.json` and reuse it across commands.
- `launch-app` auto-detects `cockpit/main.dart` first, then `lib/main.dart`.
- Default to `--profile minimal` or `standard`.
- Escalate to `inspect` or `evidence` only when required.
- `list_apps` is MCP-only; CLI discovery is `app.json`-first.
- `run-script` exits non-zero when the written bundle status is `failed`.
- Write command output to `--output-json` when a later AI step must read structured state.
