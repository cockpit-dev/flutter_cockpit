# cockpit

[![pub package](https://img.shields.io/pub/v/cockpit?logo=dart&label=pub.dev)](https://pub.dev/packages/cockpit)
[![pub points](https://img.shields.io/pub/points/cockpit?logo=dart)](https://pub.dev/packages/cockpit/score)
[![likes](https://img.shields.io/pub/likes/cockpit?logo=dart)](https://pub.dev/packages/cockpit/score)
[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/cockpit/LICENSE)

[简体中文](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/cockpit/README.zh-CN.md)

`cockpit` is the host-side package for `flutter_cockpit`.

It provides:

- AI-first CLI commands
- an MCP server with the same workflows
- target-first entrypoints for non-Flutter, native, and host-level control
- task bundle writing and validation
- workspace tooling for search, package inspection, project creation, analyze, format, test, and fixes

## Install

Requires Dart 3.8.0 or newer. Use a Flutter 3.32.0+ SDK when running it from a
Flutter workspace.

```yaml
dev_dependencies:
  cockpit: ^1.1.0
```

Optional global activation:

```bash
dart pub global activate cockpit
cockpit --help
cockpit_mcp
```

`cockpit_mcp` is the global MCP launcher exposed by this package. If you do not need a global command, you can also run MCP directly with:

```bash
dart run cockpit serve-mcp
```

Toolchain resolution:

- Explicit executable variables win: `DART`, `DART_BIN`, `FLUTTER`, `FLUTTER_BIN`.
- SDK root variables are supported next: `DART_ROOT`, `DART_SDK`, `FLUTTER_ROOT`, `FLUTTER_SDK`.
- If only `FLUTTER_ROOT` or `FLUTTER_SDK` is set, Dart commands use the bundled Flutter Dart SDK.
- If none are set, Dart commands prefer the current Dart SDK executable before falling back to `dart` on `PATH`; Flutter commands prefer the Flutter SDK around the current bundled Dart executable before falling back to `flutter` on `PATH`.

Typical host setup:

- Codex:
  `codex mcp add flutterCockpit -- dart run cockpit serve-mcp`
- Claude Code:
  `claude mcp add --transport stdio flutter-cockpit -- dart run cockpit serve-mcp`
- Cursor:
  add a `flutter-cockpit` stdio server in `~/.cursor/mcp.json` or `.cursor/mcp.json`
- VS Code:
  add a stdio server in `.vscode/mcp.json` or your profile `mcp.json` under `"servers"`
- OpenCode:
  add a local MCP entry in `~/.config/opencode/opencode.json` or repo-local `opencode.json` under `"mcp"`

For the fuller host-specific setup guide, see the repository README section:

- [Configure MCP In Mainstream Agents](https://github.com/cockpit-dev/flutter_cockpit#configure-mcp-in-mainstream-agents)

A copyable generic MCP config is also shipped at
[`example/mcp_config.json`](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/cockpit/example/mcp_config.json).

## CLI

```bash
dart run cockpit --help
dart run cockpit run-command --help
```

Recommended app-first loop:

1. `launch-app`
2. `read-app --profile minimal`
3. `run-command` or `run-batch`
4. `inspect-ui`, `read-network`, `read-errors`, `read-logs`, `wait-idle` when needed
5. `hot-reload` or `hot-restart`
6. `run-script`, `run-task`, or `validate-task` for delivery

For full-fidelity observability of delivery runs, point the local dashboard at
the same output root used by the run:

```bash
dart run cockpit devtools --history-root /tmp/flutter_cockpit/out
```

The command stays running until interrupted and serves only on loopback by
default. Use CLI/MCP summaries for low-token agent decisions; use the dashboard
when timeline, screenshots, recordings, or bundle files need human inspection.
Runs are grouped by workflow `sessionId`. Treat `sessionId` as the isolated
development or validation job, `taskId` as the current objective, and `runId` as
one execution attempt. Reuse a `sessionId` for retries of the same job and use a
new `sessionId` for unrelated work. The dashboard opens the current latest scope
and pins the URL to that concrete scope, with a selector for older sessions or
`all runs` when cross-session audit is intentional. Pass `--scope latest` only
when you want it to keep following the newest job. `scope=current` and
`scope=latest` API URLs resolve to the current latest scope, while the UI
distinguishes `pinned scope` from `following latest`. Timelines render the
active session/scope across its runs in execution order; run details and bundle
panels track the selected run. Artifact links include the owning run and event
key so repeated relative paths stay traceable. The dashboard can also parse
workflow YAML/JSON and submit `runScript` or `validateTask` payloads as
background jobs under the same history root. Board-submitted runs need the
executable envelope that CLI normally supplies, such as `sessionHandle`,
`baseUrl`, `outputRoot`, and platform ids; keep those fields when switching
between JSON and YAML instead of pasting only the inner workflow. In-flight
submitted jobs remain visible before their live history files are written, and
completed submitted jobs expose bundle summaries and artifacts through the same
run API when the bundle remains under the history root. Run lists are paged for
long-lived history roots while scope totals remain visible.
Large or partially written bundle JSON is reported through `summaryFileIssues`
instead of failing the dashboard. The run detail panel exposes `download bundle`
through `GET /api/runs/<runId>/bundle-download`; the response is a
token-protected streamed tar with `download_manifest.json`, `run_metadata.json`,
`bundle/**`, and `live/**`, plus `missingRoots` for live-only or partial runs.

Target-first loop when the agent needs direct system or non-Flutter control:

1. `launch-target`
2. `read-target --profile minimal`
3. `inspect-surface` or `run-shell` when the resolved platform truthfully exposes shell control
4. `read-task-bundle-summary` or `validate-task` for bundle-backed delivery review

Native/System Control Plane when Flutter semantics cannot control the required
surface:

1. `read-system-capabilities --platform <platform> ...`
2. run only actions reported as `available` with `run-system-action`
3. use the returned `parameters` contract instead of guessing payload keys
4. use direct flags for common setup: `--appearance`, `--content-size`,
   `--font-scale`, `--latitude/--longitude`, `--orientation`,
   `--network-speed`, `--network-delay`, status-bar flags, and
   `--max-depth/--max-nodes`; use `--app-path`, `--grant-permissions`,
   `--keep-data`, `--source-path`, and `--destination-path` for app/package
   and file/media setup; use `--name`, `--purpose`, `--mode`, `--layer`, and
   `--output-path` for system screenshots and recordings
5. read post-action app, target, or system state before judging the result

Use scene-level macros for real debugging blockers instead of composing many
low-level actions by hand: `resolveBlockers` handles common dialogs, keyboard
and system UI blockers, and app recovery; `preparePermissions` batches
permission grant/revoke/reset; `recoverToApp` brings the app foreground without
killing data; `tapNotification` expands the notification surface, matches
title/body/tag/text, and taps the notification; `stabilizeForScreenshot`
collapses noisy system state, dismisses keyboard when available, fixes
orientation/appearance/status bar where supported, and recovers the app;
`readFocusState` reports keyboard/focus state for blocker diagnosis.

When `.dart_tool/flutter_cockpit/latest_app.json` exists, system commands reuse
its platform, device id, process id, and platform app id. iOS simulator
permissions should prefer `grantPermission`, which uses deterministic
`simctl privacy grant`. For iOS simulator native UI or system dialogs that
Flutter semantics and `simctl` cannot handle, run WebDriverAgent separately.
Cockpit probes `http://127.0.0.1:8100` by default for iOS simulator sessions;
pass `--wda-url` or set `FLUTTER_COCKPIT_IOS_WDA_URL` only for a custom
endpoint. Native actions stay blocked unless the endpoint is reachable. When it
is reachable, `tap`, `longPress`, `drag`, `typeText`, `pressKey`,
`dismissSystemDialog`, `dismissKeyboard`, `expandNotifications`,
`expandQuickSettings`, `collapseSystemUi`, `tapNotification`, `resolveBlockers`,
`setOrientation`, `readFocusState`, and `readUiTree` can be reported as
available and executed with `run-system-action`.

Simulator support is intentionally capability-truthful:

- Android emulator uses `adb` for native tap/drag/text/key input, Back/Home,
  volume keys, app install/uninstall/launch/terminate/data clear, permission
  grant/revoke/reset, URL/settings entry, appearance, text scale, location,
  orientation, emulator network speed/delay, notification shade, quick settings,
  system UI collapse, SystemUI demo-mode status bar overrides
  (`setStatusBar`/`clearStatusBar`), shell notifications, file push/pull, media
  import with media scanning, screenshots, recordings, UI tree dumps,
  process/window/system state reads, device info reads, notification state
  reads, logcat tails (`readSystemLogs`), battery simulation (`setBattery`),
connectivity toggles (`setConnectivity`), and bounded shell commands.
`dismissSystemDialog --decision accept|dismiss` first tries common
  Android permission/system dialog buttons with UIAutomator; `dismiss` can fall
  back to Back. Notification taps use notification expansion plus UIAutomator
  text matching.
- iOS simulator uses `simctl` for app install/uninstall/launch/terminate/data
  clear, privacy grant/revoke/reset, URL and Settings entry, appearance, content
  size, location, status bar overrides, pasteboard, simulated APNS pushes, app
  container push/pull, media import, screenshots, recordings, process reads,
  simulator/device info reads, locale switching (`setLocale`, relaunch the app
afterwards), unified log reads (`readSystemLogs`), and bounded `simctl spawn`
commands.
- iOS simulator native UI actions require a reachable WebDriverAgent endpoint:
  tap, long press, drag, text/key input, Home, keyboard dismissal, system dialog
  accept/dismiss, notification center, Control Center, notification taps,
  orientation, focus reads, and native UI tree reads.
- iOS simulator volume keys and clear-all-notifications have no stable public
  `simctl`/XCTest simulator API. They remain `unsupported` or `blocked` instead
  of pretending to be automated. Use returned fallbacks, WDA-backed actions when
  available, or app-level assertions.
- Desktop hosts (macOS/Windows/Linux) expose host-plane actions through
  built-in tooling: URL and system settings entry (`open
  x-apple.systempreferences:` / `ms-settings:`), host appearance (System
  Events / registry / gsettings), clipboard, host file push/pull and media
  copy, app activation/recovery/termination, focus and device/system reads,
  host system log reads (`readSystemLogs` via `log show`, `journalctl`, or
  `Get-WinEvent`), process/window lists, notifications (`osascript display
  notification` / `notify-send`), macOS TCC `resetPermission` via `tccutil`,
  window-targeted
  input, native UI tree reads (macOS/Windows), and window screenshots and
  recordings. Host-global surfaces with no stable app-scoped tooling — Home,
  volume keys, status bar, notification-center expansion, simulated location,
  orientation — stay `unsupported` or `blocked` truthfully.
- Web (browser) targets keep DOM-plane input blocked until a browser driver or
  bridge is configured, but screenshots and recordings are available through
  the host window adapters when the browser app id or process id is known
  (macOS hosts require the app id).

Default AI-readable capability rows include compact parameter metadata such as
`parameters=[x*:integer | wifiBars:integer[0..3] | appearance*:string(light|dark)]`.
JSON output includes the same contract as structured `parameters` entries with
`required`, `valueType`, `allowedValues`, `minimum`, and `maximum`.
It also includes `actionGroups`, so agents can discover all available
permission, notification, file, media, evidence, device-state, and inspection
actions without hard-coding platform-specific action names.

Recommended code-side loop:

1. `analyze-files --path ...`
2. `lsp --command ...`
3. `grep-package-uris` or `read-package-uris`
4. `pub-dev-search` or `pub`
5. `run-tests` or `analyze-workspace` only when the question is no longer local

CLI JSON output uses lower camel case keys.
If `launch-app` omits `--app-json`, it persists the current app handle at `.dart_tool/flutter_cockpit/latest_app.json` in the working directory and later app commands reuse it automatically.
`launch-app` is intentionally a short command: it waits for the app to become ready, writes the handle, and exits. In development mode, a background supervisor keeps `flutter run --machine`, logs, hot reload, hot restart, and `stop-app` control alive, so agents should not run `launch-app` with shell backgrounding.
`run-shell` is bounded and killable by default. Keep the default timeout for quick probes; pass `--timeout-seconds <n>` only for known-slow shell work.
When a command accepts both `--app-json` and `--base-url`, precedence is: explicit `--app-json`, then explicit `--base-url`, then the implicit `.dart_tool/flutter_cockpit/latest_app.json` handle in the current working directory.
`launch-app` auto-detects `cockpit/main.dart` first, then `lib/main.dart`.
`run-script --script <workflow.yaml|script.json>` accepts YAML or JSON scripts.
Use YAML for hand-written `if`, `retry`, bounded `loop`, and
`startRecording` / `stopRecording` workflows, and JSON for generated scripts.
The protocol map is shipped with this package at
[`doc/contracts/flutter-cockpit-protocol.md`](doc/contracts/flutter-cockpit-protocol.md).
The AI development protocol is shipped with this package
at [`doc/contracts/ai-development-protocol.md`](doc/contracts/ai-development-protocol.md).
The workflow protocol is shipped at
[`doc/contracts/control-workflow-protocol.md`](doc/contracts/control-workflow-protocol.md)
with the machine schema at
[`doc/contracts/control-workflow.schema.json`](doc/contracts/control-workflow.schema.json).
`run-script` and `run-remote-control-script` exit non-zero when the written bundle status is `failed`.
Workspace commands default `--workspace-root` or `--parent-directory` to the current directory.
Serialize mutation, then observation. Do not run a mutating `run-command` in parallel with the `read-app`, `inspect-ui`, or `read-network` call that depends on its result.
When the next few steps are already known and the flow will cross a route boundary such as list -> editor -> list, prefer one ordered `run-batch` over separate `run-command` round-trips. It cuts token cost and avoids route-transition gaps between commands.
`read-app` and snapshots expose focus state. When `uiSummary.focus.isTextInputFocus` is true or a software keyboard covers the next target, run `dismissKeyboard` as a locator-free command before scrolling or tapping again.
Use product-specific locator signals. Short repeated action labels such as `Open`, `Edit`, or `Save` are fine as fallbacks, but they should not be the only signal when multiple rows or cards can expose the same word. Prefer the full accessible label from `read-app` / `inspect-ui`, then add `route`, `type`, or `ancestor` only as needed.
For route-changing `tap` commands, set `parameters.expectedRouteName`. Add `parameters.routeTimeoutMs` for CI, recording, simulator, or other acceptance flows where runner latency is expected; `timeoutMs` remains the hard command ceiling. Follow critical route crossings with `waitFor` on `parameters.routeName`. To wait for spinners, dialogs, or routes to disappear, use `waitFor` with `parameters.absent: true`.
`capture-screenshot` uses app metadata when available and prefers system/host
capture before falling back to app capture with fallback metadata.
`run-command`, `run-batch`, and `run-script` default key mutating commands to
best-effort after-action screenshots attached to the command step. This gives
agents key-frame evidence for taps, text input, scrolls, drags, and back
navigation without adding per-command JSON. Use `capture-screenshot` for final
acceptance or any named proof artifact that must be strict.

For AI-first development, build project-owned rapid verifiers around the same
small loop: launch, drive one representative flow, hot reload, assert the
changed state, capture one still artifact when useful, read runtime errors, and
stop the app. Keep failure JSON compact enough for an agent to inspect before
opening full snapshots or rerunning expensive validation. Useful fields are
completed phases, failed command metadata, final route or state preview, bounded
runtime error previews, and artifact refs.

Minimal verified `run-command` shape:

```bash
dart run cockpit \
  run-command \
  --app-json /tmp/app.json \
  --command-json '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}'
```

Verified web development loop:

```bash
dart run cockpit \
  launch-app \
  --project-dir <project-dir> \
  --platform web \
  --device-id chrome \
  --app-json /tmp/flutter_cockpit/web_app.json
```

Project launch inputs are shared across launch commands:

```bash
dart run cockpit launch-app \
  --project-dir <project-dir> \
  --platform <platform> \
  --device-id <device-id> \
  --flavor staging \
  --dart-define API_URL=https://example.test \
  --dart-define-from-file config/dev.json \
  --env API_TOKEN=secret \
  --flutter-arg=--web-renderer=canvaskit
```

`--env` is passed to the child Flutter/build process and is not written into
app or session handles. `--flutter-arg` is repeatable and accepts one CLI
argument string; quote it when a Flutter flag needs a separate value, for
example `--flutter-arg "--enable-experiment records"`. It rejects
cockpit-managed flags such as `--target`, `-d`, `--flavor`, `--machine`,
`--debug`, `--profile`, `--release`, and dart-define flags.

```bash
dart run cockpit \
  read-app \
  --app-json /tmp/flutter_cockpit/web_app.json \
  --profile minimal
```

If a browser-backed session reports a real route but `visibleTargetCount: 0`,
rerun `read-app --profile standard` before assuming the app is broken. The
result now surfaces `recommendedNextStep: "recoverBrowserVisibility"` when the
page looks backgrounded, throttled, or still reconnecting.

```bash
dart run cockpit \
  hot-restart \
  --app-json /tmp/flutter_cockpit/web_app.json
```

On web, `launch-app` now stands up a host-side bridge on `127.0.0.1` and lets the browser app connect back over WebSocket while keeping the existing HTTP app surface (`/health`, `/snapshot`, `/commands/execute`, `/recording/*`) stable for agents.
Host-side browser recording still depends on the desktop OS granting screen-capture permission to the browser and capture stack; when that host permission or device policy blocks capture, `stop-recording` returns a structured failure result instead of hanging the session.
For project-owned web validation, keep app control, screenshots, and reload checks strict. Treat missing desktop screen-capture permission as a structured environment warning only when the app-control path still passes.

Locator rules:

- Start with `text`, `tooltip`, or `semanticId`.
- Use `key` only when the app already exposes a legitimate stable key for product reasons. Do not add automation-only keys.
- Add `route`, `type`, `path`, and nested `ancestor` only when ambiguity remains.
- `path` is fuzzy: segments like `body`, `slivers`, and numeric indexes are ignored, so shapes such as `scaffold.body/custom_scroll_view.slivers/0/...` can still match the same target.
- Use `fallbacks` for a short ordered backup list instead of one oversized locator.
- `scrollUntilVisible` probes between internal scroll segments, so agents should prefer one good locator and tune `viewportFraction` before falling back to manual repeated scroll commands.

## Token-Saving Shell Patterns

When the host is a shell agent, prefer the CLI surface plus small `jq` projections:

```bash
dart run cockpit \
  read-app \
  --profile minimal --stdout-format json | jq '{currentRouteName,state}'
```

```bash
dart run cockpit \
  validate-task \
  --config /tmp/validate_task.yaml --stdout-format json | jq '{classification,recommendedNextStep,validationFailures}'

dart run cockpit \
  validate-task \
  --config /tmp/validate_task.yaml \
  --output /tmp/validate_task_result.json \
  --output-format json
```

Review an existing task-run bundle without reopening large raw artifacts:

```bash
dart run cockpit \
  read-task-bundle-summary \
  --bundle-dir /tmp/flutter_cockpit/out/20260530T060304005006Z_session-1
```

Default stdout is the full AI-readable semantic render. Add `--stdout-format json` for immediate `jq` projections. Keep larger payloads on disk with `--output <path>`; add `--output-format json` only when a later step must reopen structured JSON. Prefer `--command-file`, `--commands-file`, or `--config` over long inline JSON once the request body stops being trivial; use YAML for hand-written task/workflow configs and JSON for generated configs.

## MCP

```bash
dart run cockpit serve-mcp
```

Recommended app and target tools:

- `list_targets`
- `launch_app`
- `launch_target`
- `list_apps`
- `read_app`
- `read_target`
- `inspect_ui`
- `inspect_surface`
- `run_command`
- `run_batch`
- `capture_screenshot`
- `read_system_capabilities`
- `run_system_action`
- `run_shell`
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

Advanced remote-session tools:

- `list_active_sessions`
- `launch_remote_session`
- `query_remote_session`
- `read_remote_status`
- `read_remote_snapshot`
- `collect_remote_snapshot`
- `execute_remote_command`
- `execute_remote_command_batch`
- `wait_remote_ui_idle`
- `start_remote_recording`
- `stop_remote_recording`

Development-session tools:

- `launch_development_session`
- `query_development_session`
- `reload_development_session`
- `collect_development_probe`
- `compare_development_probe`
- `read_session_logs`
- `stop_development_session`

`list_apps`, `list_active_sessions`, and `read_session_logs` are MCP-only by
design: they read the long-lived MCP server's in-process session registry. The
stateless CLI covers the same workflow through app handles —
`.dart_tool/flutter_cockpit/latest_app.json` plus explicit `--app-json` files —
so a CLI listing command would always report an empty registry.

Workspace and roots tools:

- `add_roots`
- `remove_roots`
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

Resources and prompts are also exposed for contracts, capabilities, task
summaries, roots, package reads, and standard closed-loop guidance. Read
`cockpit://workspace/protocol` first for the contract map,
`cockpit://workspace/ai-development-protocol` for the AI development loop, and
`cockpit://workspace/control-workflow-protocol` when an MCP host needs the
script protocol for `run_script`. Use
`cockpit://workspace/control-workflow-schema` when a tool needs the
machine-readable workflow schema.

## Notes

- Persist `app.json` and reuse it. It is the preferred app reference across steps.
- If you stay in one repo, the default `.dart_tool/flutter_cockpit/latest_app.json` handle is the lowest-friction path and usually removes the need to keep passing `--app-json`.
- For apps wired for Cockpit, prefer the Cockpit development entrypoint such as `cockpit/main.dart`; that is where network observation and the remote control surface are enabled.
- If the app makes live HTTP calls, keep platform permissions aligned with that behavior: Android needs `INTERNET`, and Apple targets need outbound client entitlement plus local-network ATS allowance for loopback HTTP.
- `list_apps` is MCP-only because the CLI does not keep an in-memory app registry across invocations.
- `read_logs` reads app-centric runtime lines first. `available=true` with an empty `lines` array is valid when the app emitted no runtime logs.
- `read_network` is the low-token path for endpoint summaries, recent failures, and optional bounded entries. Prefer `run_command` -> `wait_idle` -> `read_network` over `inspect_ui` when the question is only about network traffic.
- On long pages, reveal a stable card or section first. If a deep control still misses under sticky chrome, lower `viewportFraction` before escalating to `inspect_ui`.
- `pub` keeps dependency edits bounded and returns previews instead of full `pub` logs by default.
- Shell agents usually get the lowest token cost from the CLI surface. Tool-calling hosts can use the matching MCP tools instead of reopening large command payloads in model context.
- `analyze_files` is the low-token path for focused diagnostics; use `analyze_workspace` only when the question is workspace-wide.
- `lsp` uses relative paths plus 1-based line and column inputs so agents do not need file URIs or zero-based math.
- Use `minimal`, `standard`, `inspect`, and `evidence` profiles to trade off token cost against detail.
- Interactive app commands accept `timeoutMs`. Workspace tools accept `timeoutSeconds`. Keep the default unless the task is known to be slow.
- `pub_dev_search` uses a bounded network path and a local Python fallback when direct TLS fetches fail on the host.
- Advanced low-level session services still exist in the Dart API, but the recommended public loop is app-first.
- CLI `read-task-bundle-summary`, MCP `read_task_bundle_summary`, and `validate-task` expose plane-aware delivery state, including `targetKind`, `primaryExecutionPlane`, `planesUsed`, `surfaceKindsUsed`, `fallbackCount`, and bounded fallback gates.

## Verification

Repository-only MCP verification is maintained in the source tree at
[`packages/cockpit/tool/verify_mcp_surface.dart`](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/cockpit/tool/verify_mcp_surface.dart).
It exercises the real `serve-mcp` stdio surface, workspace tooling,
target-first commands, and delivery tools end to end.
The repository `runtime-loop` workflow runs it on macOS as the MCP and
target-first release gate:
[`runtime-loop.yml`](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml).

Package page: [pub.dev/packages/cockpit](https://pub.dev/packages/cockpit)
