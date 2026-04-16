---
name: flutter-cockpit
description: Use when a Flutter app or adjacent browser, desktop, device, or host-control task must prove live UI, interaction, route, network, or acceptance state with runtime evidence instead of code-only reasoning.
---

# Flutter Cockpit

Use this skill when source inspection is not enough and the task needs live runtime truth.
Prefer the shipped CLI in shell-driven work. Use MCP only when the host specifically needs tool calling, roots-aware state, or the stdio server surface.
Keep context small: read this file first, then open exactly one reference doc only when the next step needs exact command syntax or payload shape.

## First-Use Guardrails

- Never invent command names, flags, `commandType` values, or locator keys.
- If the exact syntax you need is not in this file, run `dart run flutter_cockpit_devtools:flutter_cockpit_devtools help <command>` before executing anything.
- On a fresh machine or simulator loop, always start with `list-targets`. Do not guess `--device-id`.
- MCP `launch_app` and `launch_target` mirror the CLI device rules: desktop may omit `deviceId`, but android, ios, and web still need the explicit ID from `list-targets`.
- In one repo, prefer the implicit `.dart_tool/flutter_cockpit/latest_app.json` handle instead of repeating `--app-json` everywhere.
- Prefer `app-first` unless you specifically need target-first surface truth. It is the lowest-friction path for reload, logs, errors, network reads, screenshots, and cleanup.

## When To Use

- running a Flutter app or target and proving visible UI, route, interaction, network, logs, errors, screenshots, recordings, or acceptance bundles
- reproducing a live bug where code-only reasoning is insufficient
- hot reload or hot restart during implementation
- driving adjacent browser, desktop, device, or host surfaces when the task is not purely Flutter-semantic
- answering code-side questions that still need focused Dart or package facts before another runtime pass

Do not use it for docs-only edits or static refactors with no runtime claim.

## Default Loops

- `app-first` is the default:
  `list-targets` -> `launch-app` -> `read-app --profile minimal` -> `run-command` or `run-batch` -> re-read the smallest surface that answers the next question -> `hot-reload` or `hot-restart` after edits -> `stop-app`
- `target-first` is for browser, desktop, mixed-system, host-controlled, or direct surface truth:
  `list-targets` -> `launch-target --target-json /tmp/target.json --output-json /tmp/launch_target.json` -> `read-target --target-json /tmp/target.json --profile minimal` -> `inspect-surface` only if the small read is still ambiguous
- `code-side` is for symbols, diagnostics, and dependency truth before another runtime pass:
  `analyze-files` -> `lsp` -> `grep-package-uris` -> workspace-wide tools only after the scoped tools stop answering the question
- `evidence` stays minimal:
  use `captureScreenshot` for one still proof; use `start-recording` and `stop-recording` only for motion, transition, or acceptance proof; report artifact refs or paths, not just success

## Handle Rules

- `launch-app` always gives you the most reusable app handle path. In one repo, later app commands can usually reuse `.dart_tool/flutter_cockpit/latest_app.json` automatically.
- `launch-target --target-json ...` persists only `target.json`. That is enough for `read-target` and `inspect-surface`, but not always enough for app-scoped commands such as `stop-app`, `hot-reload`, `hot-restart`, or `read-logs`.
- If you choose target-first and may later need app-scoped commands, also persist `--output-json /tmp/launch_target.json`; the launch result includes the embedded app handle under `.app`. Safe extraction:
  `jq '.app' /tmp/launch_target.json > /tmp/app.json`
- If the task is primarily "edit -> reload -> verify inside one Flutter app", use `launch-app`, not `launch-target`.

## Minimum Command Truth

Use these canonical forms on first contact. If you need something beyond them, open command help or the CLI reference.

- Discover launchable targets:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools list-targets`
- App-first launch:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools launch-app --project-dir <dir> --platform <android|ios|macos|windows|linux|web> --device-id <id>`
  `--device-id` is required for android, ios, and web. Desktop defaults to the platform.
  Add `--flavor <name>` for consumer apps that do not build through the default scheme or flavor.
- Target-first launch:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools launch-target --project-dir <dir> --platform <platform> --device-id <id> --target-json /tmp/target.json --output-json /tmp/launch_target.json`
  The default `--target-kind flutterApp` auto-normalizes to `desktopApp` and `browserPage` when the platform capability profile requires it, so add `--target-kind <...>` only when you need a specific persisted kind.
  For web, use the exact browser device ID from `list-targets` such as `chrome`; do not guess `web`, and stay on `mode: development`.
- Lowest-cost app read:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-app --profile minimal`
  Valid profiles are `minimal`, `standard`, `inspect`, `evidence`.
- Lowest-cost target read:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-target --target-json /tmp/target.json --profile minimal`
- One command:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --command-file /tmp/command.json --profile standard`
  Minimal shape:
  `{"commandId":"tap-save","commandType":"tap","locator":{"text":"Save"}}`
- Short ordered batch:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-batch --commands-file /tmp/commands.json --profile minimal --final-profile standard`
  Minimal shape:
  `[{"commandId":"wait-1","commandType":"waitForUiIdle"},{"commandId":"assert-inbox","commandType":"assertText","parameters":{"text":"Inbox"}}]`
- Wait for settle:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools wait-idle`
- Reload code:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools hot-reload`
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools hot-restart`
- Runtime evidence:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-network --uri-contains /api --only-failures`
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-errors --max-errors 10`
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-logs --max-lines 40`
- Screenshot evidence:
  use `run-command` with `commandType: "captureScreenshot"`
  Minimal shape:
  `{"commandId":"capture-acceptance","commandType":"captureScreenshot","screenshotRequest":{"reason":"acceptance","name":"acceptance","includeSnapshot":true,"attachToStep":true}}`
- Recording evidence:
  after `launch-app` in the same workspace, or with an explicit app handle:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools start-recording --app-json /tmp/app.json --recording-json '{"purpose":"acceptance","name":"acceptance","tailStabilizationMs":1400}'`
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools stop-recording --app-json /tmp/app.json`
- End the loop:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools stop-app`
- Delivery gate:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools validate-task --config-json /tmp/validate_task.json`
- Focused code-side checks:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools analyze-files --path lib/main.dart`
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools lsp --command hover --path lib/main.dart --line 12 --column 8`
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools grep-package-uris --package flutter --query ThemeData`
- MCP server:
  `dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp`

Common `commandType` values that are safe to reach for first: `tap`, `enterText`, `assertText`, `waitForUiIdle`, `scrollUntilVisible`, `captureScreenshot`.
Common locator keys that are safe to reach for first: `text`, `tooltip`, `semanticId`, `type`, `ancestor`, `index`, `fallbacks`. Use `key` only when the app already exposes a legitimate stable key.

## High-Value Rules

- Prefer `minimal` or `standard` profiles first. Ask for one missing fact at a time.
- Prefer compact stdout first. Use `--output-json` only when the result is too large for stdout or a later step must reopen the full payload.
- Prefer `--command-file`, `--commands-file`, and config files once JSON stops being trivial. Do not fight shell quoting with long inline payloads.
- After `remoteUnavailable`, a transport timeout, `hot-reload`, or `hot-restart`, re-read minimal route or state before retrying. Do not blindly replay a non-idempotent batch.
- Prefer `run-batch` for route-crossing flows such as open editor -> fill fields -> save. It is cheaper and more stable than many separate `run-command` round-trips.
- For text inputs, tighten locators with `type` and `ancestor` when labels collide, then verify downstream saved state instead of relying on `uiSummary.textPreviews`.
- Use screenshots for still-state proof and recordings for motion, transition, or acceptance proof. Do not record by default when one screenshot and a bounded state read already answer the question.
- Prefer `capabilities.capabilityProfile` over legacy booleans when deciding shell, recording, browser-host, DOM, or capture behavior.
- For code-side questions, prefer `analyze-files`, `lsp`, `grep-package-uris`, `read-package-uris`, and `pub` before workspace-wide commands.
- Command success is not proof of product correctness. Re-read post-action state before judging success.
- For screenshots and recordings, report artifact refs or output paths from the result. Do not just say capture succeeded.
- On failures, report concrete status, evidence paths, and the next repair or retry step. Do not stop at prose error summary.
- Do not assume framework-repo verifier scripts exist in a consumer app. Only run repo-owned scripts when they are actually present in the current workspace.
- Stop apps you launched when the loop ends.

## Common Mistakes

- guessing `device-id`, command names, flags, or locator keys instead of using `list-targets` and `help <command>`
- jumping straight to `inspect` or `evidence` when `minimal` or `standard` would answer the next question
- rerunning a full validation loop after every small edit instead of using `hot-reload` plus a bounded re-read
- starting recording too early, too late, or for every routine check instead of reserving it for motion, transitions, or acceptance evidence
- using `target.json` as if it were automatically an app handle for `stop-app`, `hot-reload`, or `read-logs`
- treating a finished run, screenshot, or bundle as enough proof without reading post-action state or validation output

## Reference Map

- exact CLI syntax and payload shapes: [`examples/cli-command-reference.md`](examples/cli-command-reference.md)
- shortest edit -> reload -> verify loop: [`examples/rapid-dev-loop.md`](examples/rapid-dev-loop.md)
- first-day new app integration: [`examples/flutter-app-setup.md`](examples/flutter-app-setup.md)
- host CLI and MCP setup: [`examples/host-devtools-setup.md`](examples/host-devtools-setup.md)
- runtime and release validation: [`examples/runtime-validation.md`](examples/runtime-validation.md)
- acceptance bundles and delivery evidence: [`examples/acceptance-delivery.md`](examples/acceptance-delivery.md)
- failure reporting with evidence: [`examples/failure-with-evidence.md`](examples/failure-with-evidence.md)
