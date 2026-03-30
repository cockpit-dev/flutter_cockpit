# flutter_cockpit

[简体中文](/Users/iota9star/Development/workspace/flutter/flutter_pilot/README.zh-CN.md)

`flutter_cockpit` is a production-grade AI control and verification stack for Flutter.

It gives AI one closed loop:

- launch or reuse an app
- inspect live route, UI, logs, runtime errors, and diagnostics
- run single commands or batches
- hot reload or hot restart during development
- capture screenshots and recordings
- write and validate delivery bundles
- expose the same workflows through CLI and MCP

## Packages

- [`packages/flutter_cockpit`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/packages/flutter_cockpit): in-app runtime, remote session server, command execution, snapshots, capture, recording
- [`packages/flutter_cockpit_devtools`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/packages/flutter_cockpit_devtools): host-side CLI, MCP server, orchestration, bundle writing, validation, workspace tooling

## Recommended Loop

For active development and debugging:

1. `list-targets`
2. `launch-app --app-json /tmp/app.json`
3. `read-app --app-json /tmp/app.json --profile minimal`
4. `run-command`, `run-batch`, `inspect-ui`, `wait-idle`, `read-errors`, `read-logs`
5. `hot-reload` or `hot-restart`
6. repeat until the app is correct

For delivery:

1. `run-script` when you need a bundle from an already running app
2. `run-task` when the tool should own bootstrap, baseline, execution, and classification
3. `validate-task` when making a final completion claim

The public surface is app-first, not session-handle-first. Persist `app.json` and reuse it across steps. CLI and MCP outputs are normalized to `snake_case`.

## Quick Start

Add cockpit bootstrap under `cockpit/main.dart` and keep the normal production entrypoint unchanged:

```dart
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

import '../lib/app.dart';

Future<void> main() async {
  FlutterCockpit.runApp(
    const MyApp(),
    config: const FlutterCockpitConfig.production(
      initialRouteName: '/inbox',
    ),
  );
}
```

Run the example loop:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir examples/cockpit_demo \
  --target cockpit/main.dart \
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
  --command-json '{"command_id":"assert-inbox","command_type":"assert_text","parameters":{"text":"Inbox"}}'
```

## CLI Surface

Recommended commands:

- `list-targets`
- `launch-app`
- `read-app`
- `inspect-ui`
- `run-command`
- `run-batch`
- `wait-idle`
- `hot-reload`
- `hot-restart`
- `start-recording`
- `stop-recording`
- `read-logs`
- `read-errors`
- `stop-app`
- `run-script`
- `run-task`
- `validate-task`
- `serve-mcp`

Use `--profile minimal|standard|inspect|evidence` to control token cost. Start small and escalate only when needed.

## MCP Surface

Start MCP over stdio:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

Core tools:

- `list_targets`
- `launch_app`
- `list_apps`
- `read_app`
- `inspect_ui`
- `run_command`
- `run_batch`
- `wait_idle`
- `hot_reload`
- `hot_restart`
- `start_recording`
- `stop_recording`
- `read_logs`
- `read_errors`
- `stop_app`
- `run_script`
- `read_task_bundle_summary`
- `run_task`
- `validate_task`

Workspace tools:

- `pub_dev_search`
- `read_package_uris`
- `create_project`
- `analyze_workspace`
- `format_workspace`
- `run_tests`
- `apply_fixes`

Resources:

- `cockpit://workspace/goals`
- `cockpit://workspace/skill-contract`
- `cockpit://workspace/task-bundle-contract`
- `cockpit://workspace/roots`
- `cockpit://workspace/capabilities`
- `cockpit://app/list`
- `cockpit://app/details{?app_id}`
- `cockpit://task/latest`
- `cockpit://task/summary{?bundle_dir}`
- `cockpit://package/read{?workspace_root,uri}`

Prompts:

- `run_closed_loop_task`
- `inspect_before_claiming_done`
- `recover_from_failed_validation`
- `prepare_acceptance_delivery`
- `create_project_with_validation`

## Example And Docs

- Example app: [`examples/cockpit_demo`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/examples/cockpit_demo)
- Runtime package README: [`packages/flutter_cockpit/README.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/packages/flutter_cockpit/README.md)
- Devtools package README: [`packages/flutter_cockpit_devtools/README.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/packages/flutter_cockpit_devtools/README.md)
- Skill: [`skills/flutter-cockpit/SKILL.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/SKILL.md)
- CLI examples: [`skills/flutter-cockpit/examples/cli-command-reference.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/examples/cli-command-reference.md)
- Bundle contract: [`docs/contracts/task-run-bundle.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/docs/contracts/task-run-bundle.md)

Advanced development-session and remote-session building blocks still exist in the Dart API for lower-level hosts, but they are no longer the recommended public loop.

`list_apps` is intentionally MCP-only. CLI is stateless; persist `app.json` and reuse it instead of expecting a host-side app registry.
