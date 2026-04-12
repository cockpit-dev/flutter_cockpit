# flutter_cockpit_devtools

[![pub package](https://img.shields.io/pub/v/flutter_cockpit_devtools?logo=dart&label=pub.dev)](https://pub.dev/packages/flutter_cockpit_devtools)
[![pub points](https://img.shields.io/pub/points/flutter_cockpit_devtools?logo=dart)](https://pub.dev/packages/flutter_cockpit_devtools/score)
[![likes](https://img.shields.io/pub/likes/flutter_cockpit_devtools?logo=dart)](https://pub.dev/packages/flutter_cockpit_devtools/score)
[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit_devtools/LICENSE)

[简体中文](README.zh-CN.md)

`flutter_cockpit_devtools` is the host-side package for `flutter_cockpit`.

It provides:

- AI-first CLI commands
- an MCP server with the same workflows
- target-first entrypoints for non-Flutter, native, and host-level control
- task bundle writing and validation
- workspace tooling for search, package inspection, project creation, analyze, format, test, and fixes

## Install

```yaml
dev_dependencies:
  flutter_cockpit_devtools: ^1.0.0
```

Optional global activation:

```bash
dart pub global activate flutter_cockpit_devtools
flutter_cockpit_devtools --help
flutter_cockpit_mcp
```

`flutter_cockpit_mcp` is the global MCP launcher exposed by this package. If you do not need a global command, you can also run MCP directly with:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

Typical host setup:

- Codex:
  `codex mcp add flutterCockpit -- dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp`
- Claude Code:
  `claude mcp add --transport stdio flutter-cockpit -- dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp`
- Cursor:
  add a `flutter-cockpit` stdio server in `~/.cursor/mcp.json` or `.cursor/mcp.json`
- VS Code:
  add a stdio server in `.vscode/mcp.json` or your profile `mcp.json` under `"servers"`
- OpenCode:
  add a local MCP entry in `~/.config/opencode/opencode.json` or repo-local `opencode.json` under `"mcp"`

For the fuller host-specific setup guide, see the repository README section:

- [Configure MCP In Mainstream Agents](https://github.com/cockpit-dev/flutter_cockpit#configure-mcp-in-mainstream-agents)

## CLI

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --help
```

Recommended app-first loop:

1. `launch-app`
2. `read-app --profile minimal`
3. `run-command` or `run-batch`
4. `inspect-ui`, `read-network`, `read-errors`, `read-logs`, `wait-idle` when needed
5. `hot-reload` or `hot-restart`
6. `run-script`, `run-task`, or `validate-task` for delivery

Target-first loop when the agent needs direct system or non-Flutter control:

1. `launch-target`
2. `read-target --profile minimal`
3. `inspect-surface` or `run-shell`
4. `read_task_bundle_summary` or `validate-task`

Recommended code-side loop:

1. `analyze-files --path ...`
2. `lsp --command ...`
3. `grep-package-uris` or `read-package-uris`
4. `pub-dev-search` or `pub`
5. `run-tests` or `analyze-workspace` only when the question is no longer local

CLI JSON output uses lower camel case keys.
If `launch-app` omits `--app-json`, it persists the current app handle at `.dart_tool/flutter_cockpit/latest_app.json` in the working directory and later app commands reuse it automatically.
`launch-app` auto-detects `cockpit/main.dart` first, then `lib/main.dart`.
`run-script` exits non-zero when the written bundle status is `failed`.
Workspace commands default `--workspace-root` or `--parent-directory` to the current directory.
Serialize mutation, then observation. Do not run a mutating `run-command` in parallel with the `read-app`, `inspect-ui`, or `read-network` call that depends on its result.

Minimal verified `run-command` shape:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/app.json \
  --command-json '{"commandId":"assert-inbox","commandType":"assertText","parameters":{"text":"Inbox"}}'
```

Verified web development loop:

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

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  hot-restart \
  --app-json /tmp/flutter_cockpit/web_app.json
```

On web, `launch-app` now stands up a host-side bridge on `localhost` and lets the browser app connect back over WebSocket while keeping the existing HTTP app surface (`/health`, `/snapshot`, `/commands/execute`, `/recording/*`) stable for agents.
Host-side browser recording still depends on the desktop OS granting screen-capture permission to the browser and capture stack; when that host permission or device policy blocks capture, `stop-recording` returns a structured failure result instead of hanging the session.
The repository `runtime-loop` workflow also runs `examples/cockpit_demo/tool/verify_platforms.dart --platform web` on Linux under `xvfb`, so screenshot, recording, hot reload, and hot restart all stay covered by a real end-to-end web job.
For local macOS web validation, `examples/cockpit_demo/tool/verify_platforms.dart --platform web --allow-web-host-recording-prerequisite-failure` keeps the verifier strict for app control, screenshots, and reload flows while downgrading missing desktop recording permission into a structured warning.

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
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --profile minimal | jq '{currentRouteName,state}'
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/validate_task.json | jq '{classification,recommendedNextStep,validationFailures}'

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/validate_task.json \
  --output-json /tmp/validate_task_result.json
```

JSON goes to stdout in compact form by default, so immediate follow-up reads can use `| jq` with minimal token overhead. Keep larger payloads in pretty-printed files with `--output-json` only when the response is too large for stdout or another step must reopen the full result later. Prefer `--command-file`, `--commands-file`, or `--config-json` over long inline JSON once the request body stops being trivial.

## MCP

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

Core tools:

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

Resources and prompts are also exposed for contracts, capabilities, task summaries, roots, package reads, and standard closed-loop guidance.

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
- `read_task_bundle_summary` and `validate-task` now expose plane-aware delivery state, including `targetKind`, `primaryExecutionPlane`, `planesUsed`, `surfaceKindsUsed`, `fallbackCount`, and bounded fallback gates.

## Verification

Release-grade MCP verification:

```bash
dart run tool/verify_mcp_surface.dart
```

This verifier exercises the real `serve-mcp` stdio surface, workspace tooling, target-first commands, and delivery tools end to end.
The repository `runtime-loop` workflow runs it on macOS as the MCP and target-first release gate.

Package page: [pub.dev/packages/flutter_cockpit_devtools](https://pub.dev/packages/flutter_cockpit_devtools)
