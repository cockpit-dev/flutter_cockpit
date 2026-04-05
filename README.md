# flutter_cockpit

[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/LICENSE)
[![flutter_cockpit on pub.dev](https://img.shields.io/pub/v/flutter_cockpit?logo=dart&label=flutter_cockpit)](https://pub.dev/packages/flutter_cockpit)
[![flutter_cockpit_devtools on pub.dev](https://img.shields.io/pub/v/flutter_cockpit_devtools?logo=dart&label=flutter_cockpit_devtools)](https://pub.dev/packages/flutter_cockpit_devtools)

[简体中文](README.zh-CN.md)

`flutter_cockpit` is a production-grade AI control and verification stack for Flutter.

It gives AI one closed loop:

- launch or reuse an app
- inspect live route, UI, network, logs, runtime errors, and diagnostics
- run single commands or batches
- hot reload or hot restart during development
- capture screenshots and recordings
- write and validate delivery bundles
- expose the same workflows through CLI and MCP

## Install Packages

```yaml
dependencies:
  flutter_cockpit: any

dev_dependencies:
  flutter_cockpit_devtools: any
```

Package pages:

- [`flutter_cockpit` on pub.dev](https://pub.dev/packages/flutter_cockpit)
- [`flutter_cockpit_devtools` on pub.dev](https://pub.dev/packages/flutter_cockpit_devtools)

## Packages

- [`packages/flutter_cockpit`](packages/flutter_cockpit): in-app runtime, remote session server, command execution, snapshots, capture, recording
- [`packages/flutter_cockpit_devtools`](packages/flutter_cockpit_devtools): host-side CLI, MCP server, orchestration, bundle writing, validation, workspace tooling

## Recommended Loop

For active development and debugging:

1. `list-targets`
2. `launch-app --app-json /tmp/app.json`
3. `read-app --app-json /tmp/app.json --profile minimal`
4. `run-command`, `run-batch`, `inspect-ui`, `read-network`, `wait-idle`, `read-errors`, `read-logs`
5. `hot-reload` or `hot-restart`
6. repeat until the app is correct

For delivery:

1. `run-script` when you need a bundle from an already running app
2. `run-task` when the tool should own bootstrap, baseline, execution, and classification
3. `validate-task` when making a final completion claim

The public surface is app-first, not session-handle-first. Persist `app.json` and reuse it across steps. CLI and MCP output uses lower camel case keys.
Prefer `--command-file`, `--commands-file`, and `--config-json` once a payload stops being trivial.
`launch-app` auto-detects `cockpit/main.dart` first, then `lib/main.dart`.
For code-side questions, prefer `analyze-files`, `lsp`, `grep-package-uris`, `read-package-uris`, and `pub` before workspace-wide commands.

Locators are multi-signal. Start with `text`, `tooltip`, or `semanticId`. Use `key` only when the app already exposes a legitimate stable key for product reasons, then add `route`, `type`, `path`, nested `ancestor`, or short `fallbacks` only when needed. `path` matching is fuzzy and ignores noise such as `body`, `slivers`, and numeric indexes.

## Quick Start

Add cockpit bootstrap under `cockpit/main.dart` and keep the normal production entrypoint unchanged:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

import 'package:your_app/app_shell.dart';

Future<void> main() async {
  runApp(buildCockpitDevelopmentApp());
}

Widget buildCockpitDevelopmentApp() {
  return FlutterCockpitApp(
    config: FlutterCockpitConfig.production(
      remoteSession: CockpitRemoteSessionConfiguration.resolveFromEnvironment(
        fallback: const CockpitRemoteSessionConfiguration(
          enabled: true,
          host: '127.0.0.1',
          port: 47331,
        ),
      ),
    ),
    child: MaterialApp(
      navigatorObservers: <NavigatorObserver>[
        FlutterCockpit.navigatorObserver,
      ],
      home: const AppShell(),
    ),
  );
}
```

Replace `package:your_app/app_shell.dart` with the import that already exposes your app root widget or bootstrap. `launch-app` injects the `FLUTTER_PILOT_REMOTE_*` dart-defines, so `resolveFromEnvironment(...)` enables the remote control surface without taking over the production bootstrap.
If the existing app already owns `MaterialApp`, wrap that shell with `FlutterCockpitApp` and add `FlutterCockpit.navigatorObserver` to its navigator instead of nesting a second `MaterialApp`.

Run the example loop:

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

## CLI Surface

Recommended commands:

- `list-targets`
- `launch-app`
- `read-app`
- `inspect-ui`
- `run-command`
- `run-batch`
- `read-network`
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
`run-script` now exits non-zero when the written bundle status is `failed`.
For dependency and source questions, prefer `analyze-files`, `lsp`, `grep-package-uris`, `read-package-uris`, and `pub` before broader workspace passes.

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
- `read_network`
- `read_logs`
- `read_errors`
- `stop_app`
- `run_script`
- `read_task_bundle_summary`
- `run_task`
- `validate_task`

Workspace tools:

- `pub_dev_search`
- `pub`
- `grep_package_uris`
- `read_package_uris`
- `lsp`
- `analyze_files`
- `create_project`
- `analyze_workspace`
- `format_workspace`
- `run_tests`
- `apply_fixes`

Resources:

- `cockpit://workspace/skill-contract`
- `cockpit://workspace/task-bundle-contract`
- `cockpit://workspace/roots`
- `cockpit://workspace/capabilities`
- `cockpit://app/list`
- `cockpit://app/details{?appId}`
- `cockpit://task/latest`
- `cockpit://task/summary{?bundleDir}`
- `cockpit://package/read{?workspaceRoot,uri}`

Prompts:

- `run_closed_loop_task`
- `inspect_before_claiming_done`
- `recover_from_failed_validation`
- `prepare_acceptance_delivery`
- `create_project_with_validation`

## Example And Docs

- Example app: [`examples/cockpit_demo`](examples/cockpit_demo)
- Runtime package README: [`packages/flutter_cockpit/README.md`](packages/flutter_cockpit/README.md)
- Devtools package README: [`packages/flutter_cockpit_devtools/README.md`](packages/flutter_cockpit_devtools/README.md)
- Skill: [`skills/flutter-cockpit/SKILL.md`](skills/flutter-cockpit/SKILL.md)
- App setup reference: [`skills/flutter-cockpit/examples/flutter-app-setup.md`](skills/flutter-cockpit/examples/flutter-app-setup.md)
- CLI examples: [`skills/flutter-cockpit/examples/cli-command-reference.md`](skills/flutter-cockpit/examples/cli-command-reference.md)
- Skill contract: [`docs/contracts/flutter-cockpit-skill-contract.md`](docs/contracts/flutter-cockpit-skill-contract.md)
- Bundle contract: [`docs/contracts/task-run-bundle.md`](docs/contracts/task-run-bundle.md)

## Acknowledgements

Thanks to the Dart team's official [Dart Tooling MCP Server](https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server) for establishing a strong MCP tooling foundation for Dart and Flutter workflows.
`flutter_cockpit` builds on that foundation and further optimizes the exposed methods for AI-first application development, including app-first handles, lower-token defaults, bounded result shapes, and closed-loop delivery workflows.

Advanced development-session and remote-session building blocks still exist in the Dart API for lower-level hosts, but they are no longer the recommended public loop.

`list_apps` is intentionally MCP-only. CLI is stateless; persist `app.json` and reuse it instead of expecting a host-side app registry.
Interactive app commands use `timeoutMs`. Workspace tools use `timeoutSeconds`.
For code-side work, CLI and MCP expose the same workspace intelligence. In shell agents, CLI plus compact stdout pipes such as `jq` is usually the cheapest path; add `--output-json` only when another step needs to reopen the full result.
