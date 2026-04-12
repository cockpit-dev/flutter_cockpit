# flutter_cockpit

[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/LICENSE)
[![flutter_cockpit on pub.dev](https://img.shields.io/pub/v/flutter_cockpit?logo=dart&label=flutter_cockpit)](https://pub.dev/packages/flutter_cockpit)
[![flutter_cockpit_devtools on pub.dev](https://img.shields.io/pub/v/flutter_cockpit_devtools?logo=dart&label=flutter_cockpit_devtools)](https://pub.dev/packages/flutter_cockpit_devtools)

[简体中文](README.zh-CN.md)

`flutter_cockpit` is a production-grade AI control and verification stack for Flutter.

It gives AI one closed loop:

- launch or reuse an app
- launch or reuse a target when the surface is not purely Flutter
- inspect live route, UI, network, logs, runtime errors, and diagnostics
- run single commands or batches
- switch between Flutter semantic, native UI, system, and host planes with explicit capability truth
- hot reload or hot restart during development
- capture screenshots and recordings
- write and validate delivery bundles
- expose the same workflows through CLI and MCP

## Install Packages

```yaml
dependencies:
  flutter_cockpit: ^1.0.0

dev_dependencies:
  flutter_cockpit_devtools: ^1.0.0
```

Package pages:

- [`flutter_cockpit` on pub.dev](https://pub.dev/packages/flutter_cockpit)
- [`flutter_cockpit_devtools` on pub.dev](https://pub.dev/packages/flutter_cockpit_devtools)

Installing the Dart packages does not automatically install the AI skill or expose a globally callable MCP launcher. Those are separate host-side setup steps.

## Install Skill

The repository-owned skill lives at [`skills/flutter-cockpit`](skills/flutter-cockpit).

Preferred: ask the current AI host to install it for you. Copy this prompt:

```text
Install the flutter-cockpit skill for the current AI host by following https://github.com/cockpit-dev/flutter_cockpit/blob/main/skills/flutter-cockpit/INSTALL.md
```

Full host-specific instructions live in [`skills/flutter-cockpit/INSTALL.md`](skills/flutter-cockpit/INSTALL.md).

## Install MCP

`flutter_cockpit` does not ship a separate MCP package. The MCP server is provided by `flutter_cockpit_devtools`.

One-shot launch:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

If the host expects a globally callable command, install devtools globally:

```bash
dart pub global activate flutter_cockpit_devtools
flutter_cockpit_mcp
```

## Configure MCP In Mainstream Agents

Typical local setup command:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

If you already activated `flutter_cockpit_devtools` globally, you can replace the `dart run ... serve-mcp` command below with `flutter_cockpit_mcp`.

### Codex

Add the local stdio server:

```bash
codex mcp add flutterCockpit -- dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

Verify:

```bash
codex mcp list
```

### Claude Code

Add the local stdio server:

```bash
claude mcp add --transport stdio flutter-cockpit -- dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

Verify inside Claude Code with `/mcp`, or from the shell:

```bash
claude mcp list
```

### Cursor

Add a global MCP config at `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "flutter-cockpit": {
      "type": "stdio",
      "command": "dart",
      "args": [
        "run",
        "flutter_cockpit_devtools:flutter_cockpit_devtools",
        "serve-mcp"
      ]
    }
  }
}
```

You can also use `.cursor/mcp.json` in a project for repo-local configuration.

### VS Code

Add a workspace config at `.vscode/mcp.json`, or add the same server entry to your user-profile `mcp.json`:

```json
{
  "servers": {
    "flutterCockpit": {
      "type": "stdio",
      "command": "dart",
      "args": [
        "run",
        "flutter_cockpit_devtools:flutter_cockpit_devtools",
        "serve-mcp"
      ]
    }
  }
}
```

You can also add it from the Command Palette with `MCP: Add Server`.

### OpenCode

Add a global config at `~/.config/opencode/opencode.json`, or add the same block to a repo-local `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "flutterCockpit": {
      "type": "local",
      "command": [
        "dart",
        "run",
        "flutter_cockpit_devtools:flutter_cockpit_devtools",
        "serve-mcp"
      ],
      "enabled": true
    }
  }
}
```

These host commands and config entry points can evolve. If a host UI or command differs on your machine, prefer the host's latest MCP docs:

- Codex: local `codex mcp --help`
- Claude Code: [Connect Claude Code to tools via MCP](https://docs.anthropic.com/en/docs/claude-code/mcp)
- Cursor: [Cursor MCP docs](https://docs.cursor.com/context/model-context-protocol)
- VS Code: [VS Code MCP configuration reference](https://code.visualstudio.com/docs/copilot/reference/mcp-configuration)
- OpenCode: [OpenCode MCP servers](https://opencode.ai/docs/mcp-servers)

## Packages

- [`packages/flutter_cockpit`](packages/flutter_cockpit): in-app runtime, remote session server, command execution, snapshots, capture, recording
- [`packages/flutter_cockpit_devtools`](packages/flutter_cockpit_devtools): host-side CLI, MCP server, orchestration, bundle writing, validation, workspace tooling

## Recommended Loop

For active development and debugging:

1. `list-targets`
2. `launch-app`
3. `read-app --profile minimal`
4. `run-command`, `run-batch`, `inspect-ui`, `read-network`, `wait-idle`, `read-errors`, `read-logs`
5. `hot-reload` or `hot-restart`
6. repeat until the app is correct

For delivery:

1. `run-script` when you need a bundle from an already running app
2. `run-task` when the tool should own bootstrap, baseline, execution, and classification
3. `validate-task` when making a final completion claim

For target-first and non-Flutter/system work:

1. `launch-target`
2. `read-target --profile minimal`
3. `inspect-surface`, `run-shell`, or the existing app/batch commands when the target resolves to a Flutter app
4. `read_task_bundle_summary` or `validate-task` to review `targetKind`, `primaryExecutionPlane`, `planesUsed`, `surfaceKindsUsed`, `fallbackCount`, and fallback gates before claiming success

Target-first flows are platform-aware and capability-truthful:

- `launch-target` persists a normalized `target.json` and maps desktop Flutter launches to `desktopApp` instead of pretending every session is a mobile `flutterApp`.
- `read-target` stays summary-first. App-backed Flutter and desktop targets may reuse remote Flutter summaries, while browser or direct system targets fall back to capability-only summaries when no live semantic plane exists.
- `inspect-surface` prefers the foreground surface for the resolved target. Flutter apps inspect the semantic plane; desktop Flutter targets try remote semantic inspection first and fall back to native/window capture only when that semantic path is unavailable; direct system targets stay capability/capture-first.
- `run-shell` is target-aware. Use `--scope target --target-json /tmp/target.json` to bind shell execution to a normalized target, `--scope android --device-id <id>` for `adb shell`, `--scope ios --device-id <simulator-udid>` for `xcrun simctl spawn`, and desktop host-aligned scopes when the platform truthfully exposes shell control.

The public surface is app-first, not session-handle-first. If you omit `--app-json`, `launch-app` writes the latest handle to `.dart_tool/flutter_cockpit/latest_app.json` in the current working directory, and follow-up app commands reuse it automatically. CLI and MCP output uses lower camel case keys.
When a command accepts both `--app-json` and `--base-url`, precedence is: explicit `--app-json`, then explicit `--base-url`, then the implicit latest-app handle in the current working directory.
Prefer `--command-file`, `--commands-file`, and `--config-json` once a payload stops being trivial.
`launch-app` auto-detects `cockpit/main.dart` first, then `lib/main.dart`.
For code-side questions, prefer `analyze-files`, `lsp`, `grep-package-uris`, `read-package-uris`, and `pub` before workspace-wide commands.
Serialize mutation, then observation. Do not parallelize `run-command` with the `read-app`, `inspect-ui`, or `read-network` step that depends on its side effects.
When the next few mutations are already known and the flow will cross route boundaries such as `/inbox -> /editor -> /inbox`, prefer one ordered `run-batch` over separate `run-command` round-trips to reduce token cost and avoid transition gaps between commands.

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

Verified web loop:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir examples/cockpit_demo \
  --platform web \
  --device-id chrome \
  --app-json /tmp/flutter_cockpit/web_app.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/web_app.json \
  --profile minimal
```

If a browser-backed session reports a real route but `visibleTargetCount: 0`,
rerun `read-app --profile standard` before assuming the app is broken. The
result now surfaces `recommendedNextStep: "recoverBrowserVisibility"` when the
page looks backgrounded, throttled, or still reconnecting.

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/flutter_cockpit/web_app.json \
  --command-json '{"commandId":"assert-inbox","commandType":"assertText","parameters":{"text":"Inbox"}}'
```

For web, the host keeps the public HTTP session surface stable and runs a localhost bridge that the browser app joins over WebSocket.
`hot-reload` and `hot-restart` stay available through the development supervisor, while browser recording remains host-driven and depends on the local desktop granting screen-capture permission.

For the repository example, use the built-in live verifier when you need one proof that the full cross-platform dev loop still works end to end:

```bash
cd examples/cockpit_demo
dart run tool/verify_platforms.dart --output-json /tmp/cockpit_demo_all_platforms_verification.json
```

Without `--platform`, that command runs the local default sweep: macOS, iOS Simulator, and Android Emulator.
The `runtime-loop` CI workflow invokes the same verifier explicitly on Linux, Windows, and web too, one platform per job, so every shipped runtime platform is exercised through the same full command chain.
The web job runs on Linux under `xvfb` with Chrome, which keeps browser recording fully covered in CI even when a local macOS host has not granted screen-capture permission yet.
When the host can run desktop Linux or Windows locally, pass `--platform linux` and `--platform windows` explicitly to extend the sweep beyond the default three platforms.
When you are validating web locally on macOS and the desktop has not granted screen-capture permission to the terminal, Dart, or `ffmpeg` yet, add `--allow-web-host-recording-prerequisite-failure` to keep the verifier strict for every other command while surfacing host-recording as a structured warning instead of a generic failure.

The verifier validates:

- `launch-app`, `read-app`, `inspect-ui`
- `run-batch`, `wait-idle`, `read-network`, `read-errors`, `read-logs`
- `inspect-surface`, screenshot capture, `hot-reload`, `hot-restart`
- platform-aware recording drivers: remote on macOS, Linux, and Windows, `browser-host` on web, `simctl` on iOS Simulator, and `adb` on Android Emulator

It also auto-picks a free session port per platform and cleans Android `adb forward` state after verification so repeated runs do not poison later platforms.
The same `runtime-loop` workflow also runs `packages/flutter_cockpit_devtools/tool/verify_mcp_surface.dart` on macOS to validate the real `serve-mcp` stdio surface, workspace tooling, target-first surface flow, and release delivery tools end to end.

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
- Skill install: [`skills/flutter-cockpit/INSTALL.md`](skills/flutter-cockpit/INSTALL.md)
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
