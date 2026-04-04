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

`read-app --profile standard` is still summary-only. It is good for `textPreviews` and counts, but not for a full target inventory.

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
  --command-json '{"commandId":"assert-inbox","commandType":"assertText","parameters":{"text":"Inbox"}}'
```

Enter text into a field:

```bash
jq -n --arg text "Draft release checklist" '{
  commandId: "enter-title",
  commandType: "enterText",
  locator: {
    key: "task-title-input",
    ancestor: {
      route: "/editor"
    }
  },
  parameters: {
    text: $text
  }
}' >/tmp/flutter_cockpit/enter_text.json

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/flutter_cockpit/app.json \
  --command-file /tmp/flutter_cockpit/enter_text.json \
  --profile standard | jq '{success: .command.success, route: .uiSummary.routeName}'
```

Scroll to a deep control with one locator:

```bash
jq -n '{
  commandId: "reveal-sync-card",
  commandType: "scrollUntilVisible",
  locator: {
    key: "settings-sync-card",
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
  --app-json /tmp/flutter_cockpit/app.json \
  --command-file /tmp/flutter_cockpit/scroll_command.json \
  --profile standard | jq '{command: .command.success, route: .uiSummary.routeName, visible: .uiSummary.visibleTargetCount}'
```

Run a short batch:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-batch \
  --app-json /tmp/flutter_cockpit/app.json \
  --commands-json '[
    {"commandId":"wait-1","commandType":"waitForUiIdle"},
    {"commandId":"assert-inbox","commandType":"assertText","parameters":{"text":"Inbox"}}
  ]'
```

If a banner, snackbar, or bottom sheet appears after one command, do not assume the next row stayed in the same place. Re-anchor or scroll again before the next deep tap.

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
  --app-json /tmp/flutter_cockpit/app.json | jq '{reloadGeneration: .status.reloadGeneration, lastReloadSucceeded: .status.lastReloadSucceeded, lastReloadMode: .status.lastReloadMode}'
```

Then verify the changed control. If the intended copy or layout delta is still missing, relaunch once before assuming the app ignored your code edit.

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  hot-restart \
  --app-json /tmp/flutter_cockpit/app.json | jq '{reloadGeneration: .status.reloadGeneration, lastReloadSucceeded: .status.lastReloadSucceeded, lastReloadMode: .status.lastReloadMode}'
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
  --recording-json '{"purpose":"acceptance","tailStabilizationMs":1400}'
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
  --output-json /tmp/flutter_cockpit/runTaskResult.json
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
- `scrollUntilVisible` already probes between internal scroll segments. Prefer a better locator or a smaller `viewportFraction` over manual repeated blind scroll commands.
- When `scrollUntilVisible` hits the wrong boundary first, it can recover by trying the opposite direction once. Keep explicit `reverse` for cases where you already know the target is above the current viewport.
- After `hot-restart`, do not assume route and scroll position reset. Re-read route, then re-anchor or switch `reverse` if the target region is now above the viewport.
- `enterText` success does not guarantee that `uiSummary.textPreviews` will echo the entered value. Prefer validating the next visible control, route change, or saved list state.
- `list_apps` is MCP-only; CLI discovery is `app.json`-first.
- `run-script` exits non-zero when the written bundle status is `failed`.
- Write command output to `--output-json` when a later AI step must read structured state.
- Prefer the lowest-cost public surface: in shell agents, CLI + command files + `jq` usually costs fewer tokens than reopening large payloads in model context; in tool-calling hosts, MCP is fine.

## Pipe And jq Examples

Search a dependency package before opening files:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  grep-package-uris \
  --package flutter \
  --query ThemeData \
  --output-json /tmp/flutter_cockpit/grep_package_uris.json

jq '{summary, firstMatch: .packages[0].files[0].packageUri}' /tmp/flutter_cockpit/grep_package_uris.json
```

Read only the route and state:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile minimal | jq '{sessionId,currentRouteName,state}'
```

Extract one scalar:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile minimal | jq -r '.currentRouteName'
```

Keep a larger result on disk, then read only the needed fields:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/flutter_cockpit/validate_task.json \
  --output-json /tmp/flutter_cockpit/validate_task_result.json
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
