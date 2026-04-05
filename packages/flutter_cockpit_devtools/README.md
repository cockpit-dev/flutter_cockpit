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
- task bundle writing and validation
- workspace tooling for search, package inspection, project creation, analyze, format, test, and fixes

## Install

```yaml
dev_dependencies:
  flutter_cockpit_devtools: any
```

Optional global activation:

```bash
dart pub global activate flutter_cockpit_devtools
flutter_cockpit_devtools --help
flutter_cockpit_mcp
```

## CLI

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --help
```

Recommended app-first loop:

1. `launch-app --app-json /tmp/app.json`
2. `read-app --app-json /tmp/app.json --profile minimal`
3. `run-command` or `run-batch`
4. `inspect-ui`, `read-network`, `read-errors`, `read-logs`, `wait-idle` when needed
5. `hot-reload` or `hot-restart`
6. `run-script`, `run-task`, or `validate-task` for delivery

Recommended code-side loop:

1. `analyze-files --path ...`
2. `lsp --command ...`
3. `grep-package-uris` or `read-package-uris`
4. `pub-dev-search` or `pub`
5. `run-tests` or `analyze-workspace` only when the question is no longer local

CLI JSON output uses lower camel case keys.
`launch-app` auto-detects `cockpit/main.dart` first, then `lib/main.dart`.
`run-script` exits non-zero when the written bundle status is `failed`.
Workspace commands default `--workspace-root` or `--parent-directory` to the current directory.

Minimal verified `run-command` shape:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/app.json \
  --command-json '{"commandId":"assert-inbox","commandType":"assertText","parameters":{"text":"Inbox"}}'
```

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
  --app-json /tmp/app.json \
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

JSON goes to stdout by default, so immediate follow-up reads can use `| jq`. Keep larger payloads in files with `--output-json` only when the response is too large for stdout or another step must reopen the full result later. Prefer `--command-file`, `--commands-file`, or `--config-json` over long inline JSON once the request body stops being trivial.

## MCP

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

Resources and prompts are also exposed for contracts, capabilities, task summaries, roots, package reads, and standard closed-loop guidance.

## Notes

- Persist `app.json` and reuse it. It is the preferred app reference across steps.
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

## Verification

Release-grade MCP verification:

```bash
dart run tool/verify_mcp_surface.dart
```

Package page: [pub.dev/packages/flutter_cockpit_devtools](https://pub.dev/packages/flutter_cockpit_devtools)
