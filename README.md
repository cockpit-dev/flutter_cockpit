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

Minimum toolchain: Flutter 3.32.0 or newer, which includes Dart 3.8.0 or newer.
This floor keeps `flutter_test`, `dart_mcp`, and the host-side AI tooling on a
single dependency graph without `dependency_overrides`.

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
When a command accepts both `--app-json` and `--base-url`, `--app-json` supplies app identity, platform, and recording metadata while the explicit `--base-url` overrides only the live connection address. If `--app-json` is omitted, explicit `--base-url` wins over the implicit latest-app handle in the current working directory.
Prefer `--command-file`, `--commands-file`, and `--config-json` once a payload stops being trivial.
`launch-app` auto-detects `cockpit/main.dart` first, then `lib/main.dart`.
For code-side questions, prefer `analyze-files`, `lsp`, `grep-package-uris`, `read-package-uris`, and `pub` before workspace-wide commands.
Serialize mutation, then observation. Do not parallelize `run-command` with the `read-app`, `inspect-ui`, or `read-network` step that depends on its side effects.
When the next few mutations are already known and the flow will cross route boundaries such as list -> editor -> list, prefer one ordered `run-batch` over separate `run-command` round-trips to reduce token cost and avoid transition gaps between commands.
For route-changing `tap`, include `parameters.expectedRouteName`; add `parameters.routeTimeoutMs` only when the route transition is intentionally slow. `timeoutMs` is the hard command ceiling, not the default route wait.
When an app summary already exposes bounded workflow counters or state fields, prefer those fields before reopening a heavier inspection payload.

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

Replace `package:your_app/app_shell.dart` with the import that already exposes your app root widget or bootstrap. `launch-app` injects the `FLUTTER_COCKPIT_REMOTE_*` dart-defines, so `resolveFromEnvironment(...)` enables the remote control surface without taking over the production bootstrap.
If the existing app already owns `MaterialApp`, wrap that shell with `FlutterCockpitApp` and add `FlutterCockpit.navigatorObserver` to its navigator instead of nesting a second `MaterialApp`.

Run a minimal app loop:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir <project-dir> \
  --platform <platform> \
  --device-id <device-id> \
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
  --command-json '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}'
```

Run the same loop on web with the exact browser device ID reported by `list-targets`:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir <project-dir> \
  --platform web \
  --device-id <browser-device-id> \
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
  --command-json '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}'
```

For web, the host keeps the public HTTP session surface stable and runs a
`127.0.0.1` bridge that the browser app joins over WebSocket. Browser DOM
inspection, screenshots, `hot-reload`, and `hot-restart` should stay strict in
normal development verification. Browser-host recording is a separate host
environment gate: it depends on macOS/desktop screen-capture permission for the
terminal, Dart, ffmpeg, and the browser host app, and it should fail at
recording start when ffmpeg cannot prove startup or output evidence.

For AI-first project validation, keep two verifier tiers:

- A rapid verifier for the normal edit -> reload -> assert loop. It should launch the app, drive one representative production flow, hot reload, assert the changed state, capture one still artifact when useful, read runtime errors, and stop the app. Its JSON should stay compact: completed phases, failed command metadata, final route or state preview, bounded runtime error previews, and artifact refs.
- A release verifier for the expensive surfaces. It should add recordings, hot restart, network and log reads, target-first inspection, multi-platform coverage, and acceptance or delivery gates.

Platform-specific capture should be capability-driven rather than hard-coded:
desktop and physical devices may use remote or host adapters, web may use
browser-host capture when the host permission gate passes, iOS simulators may
use simulator-native tooling, and Android emulators may use device tooling. If a
host permission blocks recording while app control still passes, report it as a
structured environment warning with the recorder failure reason instead of
masking the app result.
Treat completed recording as evidence only when the stop result includes an
artifact backed by non-empty bytes or a non-empty source/output file; empty or
missing artifact content is a failed evidence result, not video proof.
When a command accepts both `app.json` and `baseUrl`, keep passing the handle whenever available: the handle carries platform, device, process, and remote-session metadata, while `baseUrl` only overrides the live HTTP connection. For iOS recording without an app handle, pass `iosDeviceId` / `--ios-device-id` so the host-side simulator or device adapter can select the right recorder.

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

Advanced public commands are available when the default app-first path is not
the smallest truthful surface:

- use `launch-remote-session`, `query-remote-session`,
  `read-remote-status`, `read-remote-snapshot`,
  `execute-remote-command`, and `execute-remote-command-batch` for direct
  remote-session loops
- use `launch-development-session`, `reload-development-session`,
  `collect-development-probe`, `compare-development-probe`, and
  `stop-development-session` for persistent edit-reload-probe loops
- use `start-remote-recording` and `stop-remote-recording` only when working
  directly with a remote session instead of an app handle

Use `--profile minimal|standard|inspect|evidence` to control token cost. Start small and escalate only when needed.
When a CLI command exits non-zero, first look for `errorJson: {...}` on stderr.
For non-usage failures, the `code`, `message`, and optional `details` fields are
the machine-readable recovery surface for AI agents; the prose `Error:` line is
only a human summary.
Remote endpoint failures keep their original codes when possible, such as
`bridgeUnavailable`, `artifactNotFound`, `recordingStartFailed`, or
`invalidPayload`, so recovery can target the bridge, artifact transfer,
recording prerequisite, or payload issue directly instead of retrying blindly.
Large forensic snapshots stay summary-first in normal app and command reads. If
the result includes `artifactDownloads`, treat those paths as deferred evidence
and fetch or collect the full diagnostics artifact only when the summary cannot
explain the next repair or acceptance decision.
For `collect-remote-snapshot`, `--emit-artifact-when-large` asks the app to
externalize oversized diagnostics, while `--download-diagnostics-artifacts`
explicitly pulls that deferred artifact into the command output. Keep the
download flag off unless the AI step truly needs the full forensic payload.
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
For code-side work, CLI and MCP expose the same workspace intelligence. In shell agents, default CLI stdout is the full AI-readable semantic render. Add `--stdout-format json` for `jq` pipelines, or `--output <path> --output-format json` when another step must reopen structured JSON from disk.
