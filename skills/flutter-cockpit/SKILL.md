---
name: flutter-cockpit
description: Use when a Flutter app or adjacent browser, desktop, device, or host-control task must prove live UI, interaction, route, network, or acceptance state with runtime evidence instead of code-only reasoning.
---

# Flutter Cockpit

## Overview

Use this skill when source inspection is not enough and the task needs live runtime truth. Prefer the CLI in shell-driven work. Use MCP only when the host specifically needs tool calling, roots-aware state, or the stdio server.

Keep context small: read this file first, then open exactly one reference doc only when the next step needs exact command syntax or payload shape.

## When To Use

- Prove visible UI, route, interaction, network, logs, errors, screenshots, recordings, or acceptance state.
- Reproduce a live bug where code-only reasoning is insufficient.
- Drive adjacent browser, desktop, device, or host surfaces outside pure Flutter semantics.
- Iterate with hot reload or hot restart during implementation.
- Ask focused Dart/package facts before the next runtime pass.

Do not use it for docs-only edits or static refactors with no runtime claim.

## Quick Reference

- Fresh machine: `list-targets` first. Do not guess `--device-id`; android, ios, and web need the explicit id from discovery.
- App-first default: `launch-app` -> `read-app --profile minimal` -> `run-command` or `run-batch` -> smallest post-action read -> `hot-reload` or `hot-restart` after edits -> `stop-app`.
- Target-first only when surface truth is not a plain app handle: `launch-target --target-json /tmp/target.json --output /tmp/launch_target.json --output-format json` -> `read-target --profile minimal` -> `inspect-surface` only if still ambiguous.
- Persistent edit loop: `launch-development-session` -> `collect-development-probe --profile quick` -> edit -> `reload-development-session --mode hot_reload` -> collect/compare probe -> stop session.
- Direct remote is an escape hatch: `launch-remote-session` -> `read-remote-status --profile minimal` -> `execute-remote-command` or batch -> snapshot only if needed.
- Code-side truth: `analyze-files`, `lsp`, `grep-package-uris`, `read-package-uris`, and `pub` before workspace-wide tools.

## Copy-Ready Commands

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools list-targets
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app --project-dir <dir> --platform <platform> --device-id <id>
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-app --profile minimal
```

```bash
mkdir -p /tmp/flutter_cockpit
printf '%s\n' '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}' \
  >/tmp/flutter_cockpit/command.json
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command --command-file /tmp/flutter_cockpit/command.json --profile standard
```

```bash
printf '%s\n' '[{"commandId":"wait-1","commandType":"waitForUiIdle"},{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}]' \
  >/tmp/flutter_cockpit/commands.json
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-batch --commands-file /tmp/flutter_cockpit/commands.json --profile minimal --final-profile standard
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools hot-reload
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-errors --max-errors 10
dart run flutter_cockpit_devtools:flutter_cockpit_devtools stop-app
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task --config-json /tmp/flutter_cockpit/validate_task.json
```

Safe first command types: `tap`, `enterText`, `assertText`, `waitForUiIdle`, `scrollUntilVisible`, `captureScreenshot`.

Safe first locator keys: `text`, `tooltip`, `semanticId`, `type`, `ancestor`, `index`, `fallbacks`. Use `key` only when the app already exposes a legitimate stable key.

## High-Value Rules

- If syntax is unclear, run `dart run flutter_cockpit_devtools:flutter_cockpit_devtools help <command>` before guessing.
- Prefer `app-first` unless target-first surface truth is the real question. In one repo, reuse `.dart_tool/flutter_cockpit/latest_app.json` instead of repeating `--app-json`.
- If target-first may later need app commands, persist `--output /tmp/launch_target.json --output-format json` and extract the embedded app handle with `jq '.app' /tmp/launch_target.json > /tmp/app.json`.
- Default stdout is AI-readable, not JSON. Use `--stdout-format json` only for `jq`; use `--output <path>` for files and add `--output-format json` only for machine-readable files.
- Prefer file inputs: `--command-file`, `--commands-file`, and config JSON once payloads stop being trivial.
- Start with `minimal` or `standard`; ask for one missing fact at a time before escalating to `inspect`, `evidence`, raw artifacts, or downloaded diagnostics.
- For route-changing taps, include `parameters.expectedRouteName`. Auto activation uses it to verify the direct/semantic path quickly, fall back to a user-like gesture when safe, and return better diagnostics instead of spending the whole timeout on a stale route.
- `run-command`, `run-batch`, and `run-script` automatically attach best-effort after-action screenshots to key mutating commands such as tap, text input, scroll, drag, and back. Keep explicit `captureScreenshot` for final acceptance or named proof shots.
- When a CLI command exits non-zero, first read `errorJson` with `code`, `message`, and optional `details`. For non-usage failures, use that compact payload before the prose `Error:` line. Do not collapse all remote failures: `remoteUnavailable`, `bridgeUnavailable`, `artifactNotFound`, `recordingStartFailed`, and `invalidPayload` need different next actions.
- Treat `invalidPayload` as a command or option defect. Fix the JSON shape, query parameter, profile, or locator payload before retrying.
- After `remoteUnavailable`, a timeout, hot reload, or hot restart, re-read minimal route or state before retrying. Do not blindly replay a non-idempotent batch.
- Prefer `run-batch` for route-crossing flows such as open editor -> fill fields -> save.
- Use screenshots for still proof and recordings only for motion, transition, or acceptance proof. Report artifact refs or output paths, not just success.
- Treat web browser-host recording as a host environment gate. If recording start reports ffmpeg startup/output evidence missing, record the prerequisite warning and do not claim video proof.
- For iOS recording without `app.json`, pass `--ios-device-id <id>`. Prefer `app.json` because it carries platform, device, process, and session metadata.
- Command success is not product proof. Re-read post-action state before judging.
- Stop apps or sessions you launched.

## Common Mistakes

- Guessing `device-id`, command names, flags, `commandType`, or locator keys instead of using discovery and help.
- Rerunning full validation after every small edit instead of hot reload plus a bounded read.
- Treating `target.json` as an app handle for `stop-app`, reload, or app-scoped recording.
- Adding automation-only keys instead of using multi-signal locators.
- Opening large snapshots or artifacts before summaries explain the next repair.
- Treating a finished run, screenshot, or bundle as enough proof without post-action state or validation output.
- Assuming framework-repo verifier scripts exist in a consumer app.

## Reference Map

- exact CLI syntax and payload shapes: [`examples/cli-command-reference.md`](examples/cli-command-reference.md)
- shortest edit -> reload -> verify loop: [`examples/rapid-dev-loop.md`](examples/rapid-dev-loop.md)
- first-day new app integration: [`examples/flutter-app-setup.md`](examples/flutter-app-setup.md)
- host CLI and MCP setup: [`examples/host-devtools-setup.md`](examples/host-devtools-setup.md)
- runtime and release validation: [`examples/runtime-validation.md`](examples/runtime-validation.md)
- acceptance bundles and delivery evidence: [`examples/acceptance-delivery.md`](examples/acceptance-delivery.md)
- failure reporting with evidence: [`examples/failure-with-evidence.md`](examples/failure-with-evidence.md)
