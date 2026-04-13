---
name: flutter-cockpit
description: Use when a Flutter app or adjacent browser, desktop, device, or host-control task must prove live UI, interaction, route, network, or acceptance state with runtime evidence instead of code-only reasoning.
---

# Flutter Cockpit

Use this skill when the task needs live Flutter evidence, not just source inspection.
Default loop: launch or reuse the app, read the smallest useful state, execute one action or short batch, inspect only the next missing fact, then validate delivery before any final claim.
Prefer the lowest-token public surface. In shell-driven work that is usually the shipped CLI. Use MCP when the host specifically needs tool calling, roots-aware state, or a long-lived server surface.
When the surface is not purely Flutter, switch to the same summary-first loop with target-first commands instead of forcing everything through app handles. Desktop Flutter targets still prefer semantic inspection when it is reachable, then fall back to native/window evidence only when that semantic path is unavailable.

## When To Use

- running a Flutter app
- driving an adjacent browser, desktop, device, or host surface when the task is not purely Flutter-semantic
- proving visible UI, route, or interaction state
- reproducing a live bug
- editing Dart or Flutter code and needing focused dependency, analyzer, or symbol facts before another runtime pass
- hot reload or hot restart during implementation
- collecting screenshots, recordings, or bundle-backed acceptance evidence

Do not use it for docs-only edits or static refactors with no runtime claim.

## Required Workflow

1. `preflight`
   On a brand new machine, repo, simulator, or emulator loop, enumerate the actual launchable targets first with `list_targets` / `list-targets` instead of guessing `--platform` or `--device-id`. Reuse the reported target IDs in later launch commands.
2. `bootstrap`
   Use `launch_app` / `launch-app`. Prefer a Cockpit development entrypoint such as `cockpit/main.dart` when the project provides one. On CLI, omit `--app-json` when you are staying in one repo so `launch-app` can reuse `.dart_tool/flutter_cockpit/latest_app.json` automatically; pass an explicit `app.json` only when another step must reopen a named handle outside the current working directory. On MCP, `list_apps` can recover tracked apps.
   For direct system or non-Flutter targets, use `launch_target` / `launch-target` and persist `target.json` when you are on the CLI.
3. `baseline`
   Start with `read_app` / `read-app --profile minimal`.
   For target-first work, start with `read_target` / `read-target --profile minimal`.
4. `execute`
   Prefer `run_command` for one action and `run_batch` for short ordered steps. Use `wait_idle`, `read_network`, `read_errors`, `read_logs`, `hot_reload`, and `hot_restart` only when they answer the next question.
   If a remote session becomes temporarily unavailable after a mutating or route-changing step, use route-aware recovery: re-read minimal route or state before retrying, do not blindly replay a non-idempotent batch, and resume from the smallest remaining step.
   For code-side questions, prefer `lsp`, `analyze_files`, `grep_package_uris`, `read_package_uris`, and `pub` before broader workspace commands.
5. `observe`
   Re-read with the smallest profile that answers the next missing fact. For target-first work, use `inspect_surface` / `inspect-surface` when `read_target` still leaves ambiguity. Desktop Flutter targets may reuse remote semantic inspection; if that path is unavailable, prefer the native/window fallback instead of pretending semantic evidence still exists.
6. `deliver`
   Use `run_script` for a running app, `run_task` for full orchestration, and `validate_task` before any acceptance-facing claim. Treat CLI `run-script` non-zero exit or MCP `run_script` `isError=true` as a failed bundle.

When the repo is this project and the target is the demo app, close the loop with `examples/cockpit_demo/tool/verify_platforms.dart` before a release-facing claim. From the repo root, `dart run examples/cockpit_demo/tool/verify_platforms.dart ...` now auto-resolves `examples/cockpit_demo` as the default `--project-dir`; inside the example directory you can still use `dart run tool/verify_platforms.dart ...`. The default local sweep runs the real macOS, iOS Simulator, and Android Emulator development loops. The `runtime-loop` CI workflow invokes the same verifier explicitly on Linux, Windows, and web too. The verifier auto-avoids busy host ports, cleans Android `adb forward` leftovers, and validates recording through the correct platform driver (`remote`, `browser-host`, `simctl`, or `adb`).
For local macOS web runs where the desktop has not yet granted screen-capture permission to the terminal, Dart, or `ffmpeg`, add `--allow-web-host-recording-prerequisite-failure` so the verifier stays strict for app control, screenshots, and reload flows while surfacing host recording as a structured warning.
When the release claim also covers MCP, target-first control, or workspace tooling, run `packages/flutter_cockpit_devtools/tool/verify_mcp_surface.dart` as well. That verifier exercises the real `serve-mcp` stdio entrypoint, workspace tools, target-first surface flow, and delivery tooling end to end.

## Common Development Modes

- **Rapid dev loop** (see `examples/rapid-dev-loop.md`): edit, `launch-app`, `read-app --profile minimal`, `hot-reload`, run a single `run-command`, and re-read just what answers the next question.
- **Target-first quick loop** (desktop, browser, or host workloads): `launch-target`, `read-target --profile minimal`, inspect the surface only when needed, and execute one `run-command` or bounded `run-batch` instead of relaunching the whole application surface.
- **Delivery/validation loop** (final evidence): rely on `run-task` → `validate-task` (or the repo-specific `verify_platforms.dart`) and capture recordings/logs before claiming readiness.
- **First-day integration mode**: mirror `examples/flutter-app-setup.md` to add a cockpit entrypoint, wiring, and remote session config before launching any command.

## First-Day New App Integration Checklist

1. Add the `flutter_cockpit` dependency (package or git) and run `flutter pub get`/`dart pub get` in the app package.
2. Keep the existing production entrypoint untouched and add `cockpit/main.dart` + `cockpit/cockpit_bootstrap.dart` with the minimal `FlutterCockpitApp` bootstrap plus `FlutterCockpit.navigatorObserver` on the `MaterialApp`.
3. Resolve `CockpitRemoteSessionConfiguration` from the environment so `launch-app` can drive the app through `FLUTTER_PILOT_REMOTE_*` dart-defines without replicating the production bootstrap.
4. Gate rebuild tracking and tap feedback behind `bool.fromEnvironment` flags so they stay debug-only, and keep the cockpit wiring thin by delegating real services to the existing app shell.
5. Before claiming a new-integration workflow, run `dart run examples/cockpit_demo/tool/verify_platforms.dart --platform <target> ...` (add `--allow-web-host-recording-prerequisite-failure` on macOS web when screen capture permission is missing) and confirm the demo targets cycle cleanly on macOS, iOS Simulator, Android Emulator, and web/Windows/Linux as needed.

## Preferred Commands and Payload Shapes

- `list-targets`: `dart run flutter_cockpit_devtools:flutter_cockpit_devtools list-targets` before any first-day launch, simulator/emulator bootstrap, or device-specific `run-shell` command. Do not guess `--device-id` values when this command can enumerate them.
- `launch-app`: `dart run flutter_cockpit_devtools:flutter_cockpit_devtools launch-app --project-dir examples/cockpit_demo --platform macos --device-id macos --session-port 57331 --mode development`. Omit `--app-json` to reuse `.dart_tool/flutter_cockpit/latest_app.json` in the current repo; use `--app-json /tmp/app.json` only when you must share the handle between directories.
- `read-app`: `dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-app --profile minimal` (upgrade to `--profile standard` for counts/textPreviews or `--profile inspect` for missing locators). Add `--app-json <file>` when reading from a non-default handle or `--output-json` when future steps depend on the structured payload.
- `run-command`: keep JSON lean. Example command file:

```json
{
  "commandId": "assert-inbox",
  "commandType": "assertText",
  "locator": {
    "text": "Inbox",
    "ancestor": {
      "route": "/inbox"
    }
  }
}
```

Invoke it with `dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --command-file /tmp/flutter_cockpit/command.json --profile standard` and project only the needed fields with `jq`.
- `run-batch`: keep the sequence short and deterministic. Example payload:

```json
[
  {"commandId": "wait-1", "commandType": "waitForUiIdle"},
  {"commandId": "assert-inbox", "commandType": "assertText", "parameters": {"text": "Inbox"}}
]
```

Use `--commands-json` or `--commands-file` with `--profile minimal`/`standard` depending on how much verification you need.
- `hot-reload`: `dart run flutter_cockpit_devtools:flutter_cockpit_devtools hot-reload` (pipe through `jq` to read `status.reloadGeneration`, `lastReloadSucceeded`, `lastReloadMode`). If the UI delta is missing, re-read the changed control and relaunch before assuming the reload silently failed.
- `start-recording`: `dart run flutter_cockpit_devtools:flutter_cockpit_devtools start-recording --recording-json '{"purpose":"acceptance","tailStabilizationMs":1400}'` to cover acceptance-grade footage. Keep recording handles scoped to the loop, and stop with `stop-recording` before exit.
- `stop-recording`: `dart run flutter_cockpit_devtools:flutter_cockpit_devtools stop-recording` to finalize the capture.
- `run-task`: `dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-task --config-json /tmp/flutter_cockpit/run_task.json` and read the summary with `jq '{classification,recommendedNextStep}'` before declaring delivery.
- `validate-task`: `dart run flutter_cockpit_devtools:flutter_cockpit_devtools validate-task --config-json /tmp/flutter_cockpit/validate_task.json` (add `--output-json` when later steps need the structured result) and inspect `validationFailures` before claiming success.
- `verify_platforms.dart`: from the repo root, `dart run examples/cockpit_demo/tool/verify_platforms.dart --platform macos` (add `--allow-web-host-recording-prerequisite-failure` for blocked host recording) to prove each platform loop works; inside `examples/cockpit_demo`, run `dart run tool/verify_platforms.dart ...`.

## Command Schema Gotchas and Anti-Patterns

- Do not guess device IDs, simulator UDIDs, or desktop target names from memory. Run `list-targets` first and use the emitted values directly in `launch-app`, `launch-target`, or platform-scoped `run-shell`.
- Do not invent new `commandType` strings or locator keys; reuse the repo samples in `examples/cli-command-reference.md` and the Flutter Cockpit API names.
- Avoid large inline JSON arguments. When the payload is multi-line, keep it in a file and pass it via `--command-file`, `--commands-file`, `--config-json`, or `--recording-json` so you can inspect or re-run it easily.
- Do not rely on `uiSummary.textPreviews` echoing the entered text. Instead, verify the following control, route change, or saved state entry.
- When `scrollUntilVisible` repeatedly hits the wrong boundary, add `reverse` only after you know the target is above or below, and prefer tighter locators (`text` + `ancestor.route`, `type`, or `index`) before layering brittle paths.
- After a transient `remoteUnavailable`, re-read the route or minimal state before replaying the command batch; do not blindly retry a `run-batch` whose earlier step might already have succeeded.
- Keep `commandId` unique within a loop to avoid confusing past statuses, and do not send more than one mutating `run-command` without an intervening read/confirm step.
- Prefer the repo-provided CLI commands and JSON shapes instead of inventing new tooling; reference the `examples/cli-command-reference.md` file whenever you are unsure which options already exist.

## Locator Guidance

- Start with `text`, `tooltip`, or `semanticId`.
- Use `key` only when the app already exposes a legitimate stable key for product reasons. Do not add automation-only keys or selectors to application code.
- Add `route`, `type`, `path`, or nested `ancestor` only when ambiguity remains.
- `path` is fuzzy. Segments such as `body`, `slivers`, and numeric indexes are ignored, so shorter structural paths are preferred over brittle full trees.
- Use short ordered `fallbacks` instead of one over-constrained locator.
- When the same label appears in multiple visible regions, add `index` or a nearby `ancestor` before reaching for any lower-level signal.
- For text inputs, do not assume the target text will equal the visible field label. If the field target is ambiguous, combine `type` with `ancestor` or a nearby section heading, then verify the downstream saved state instead of the raw input echo.
- `scrollUntilVisible` probes between internal scroll segments and can stop early when a target becomes visible mid-search, so prefer one precise locator over manual repeated blind scroll commands.
- If the current direction hits a scroll boundary first, `scrollUntilVisible` can recover by trying the opposite direction once. Use explicit `reverse` only when you already know the target region is above the current viewport.
- On long settings pages, forms, or dashboards, reveal a stable section heading or card first, then target deeper controls inside that section. Jumping straight to a deeply nested off-screen control can overshoot or time out.
- After selection banners, snackbars, or bottom sheets appear, assume list geometry changed. Re-anchor the next row or control instead of reusing the pre-overlay scroll position.
- After a command inserts, removes, filters, or reorders collection items, re-anchor from a stable visible signal before the next deep collection-level gesture.
- After `hot-reload` or `hot-restart`, do not assume the route or scroll position reset. Re-read minimal state, then re-anchor from a known section before sending the next deep locator.
- A successful `hot-reload` or `hot-restart` status only proves the request completed and the app became reachable again. Re-read the specific control you changed, and relaunch once if the intended UI delta still does not appear.

## Profiles And Timeouts

- `minimal`: fast status, lowest token cost
- `standard`: bounded UI summary and snapshot refs
- `inspect`: failure-oriented diagnostics and deltas
- `evidence`: final or hardest cases only

Default to the smallest profile that answers the current question.
`read-app --profile standard` gives summary counts and `textPreviews`, not a full target inventory. Escalate to `inspect-ui` only when you truly need keys, semantic IDs, or a richer target list.
Interactive app commands accept `timeoutMs`. Workspace tools accept `timeoutSeconds`. Raise them only for known slow steps such as long scrolls, `run_task`, or package operations.
If `remoteUnavailable` happens after a mutating step, do not just increase the timeout and replay everything. Re-read minimal route or state before retrying so you can tell whether the mutation already committed.
If deep controls still miss under sticky headers or footers, lower `viewportFraction` before escalating to heavier inspection.

For the shortest edit -> reload -> verify loop, use the rapid loop reference instead of escalating every step to bundle-grade evidence.

## Token Discipline

- Prefer `minimal` or `standard` unless the current question is still ambiguous.
- Prefer `read_app` and `inspect_ui` summaries before raw snapshot payloads.
- Prefer `run_batch` over repeated `run_command` round-trips when the next few mutations are already known and must stay ordered.
- Prefer `run_batch` for short route-crossing flows such as open editor -> fill fields -> save. It keeps the mutation chain ordered inside one remote loop and avoids paying extra token and stability cost on each intermediate route transition.
- When a mutating or route-changing step hits `remoteUnavailable` or a transport timeout, switch to route-aware recovery: re-read minimal route or state before retrying, confirm whether the route already advanced, and resume from the smallest remaining step.
- If the sequence is non-idempotent, do not blindly replay a non-idempotent batch. Split the flow into smaller checkpoints or continue from the next verified route instead.
- Prefer `read_network` over snapshot diagnostics when the next question is only about requests, failures, or endpoint coverage.
- For traffic verification, use `run_command` -> `wait_idle` -> `read_network` before escalating to heavier UI inspection.
- Prefer bundle summaries and gate failures before opening large artifact files.
- Ask for one missing fact per step, not every diagnostic dimension at once.
- Prefer compact stdout projections such as `| jq` for immediate branch decisions. Add `--output-json` only when the result is too large for stdout or a later step must reopen the full payload.
- Prefer the default latest-app handle in one workspace instead of repeating `--app-json` on every command.
- When both are accepted, remember the app reference precedence: explicit `--app-json`, then explicit `--base-url`, then the implicit latest-app handle in the current working directory.
- Prefer `grep_package_uris` before opening large dependency files blindly; search first, then read only the matching package URI.
- Prefer `jq -r` or short pipes to extract one route, status, failure code, or readiness field at a time.
- Prefer `--command-file`, `--commands-file`, and `--config-json` files over long inline JSON literals when the payload is more than a few lines.
- Reuse `app.json`, command files, and config files across loops instead of regenerating them in every step.
- Workspace CLI commands default `--workspace-root` or `--parent-directory` to the current directory, so avoid repeating that flag unless you are operating outside the current repo.
- Do not parallelize `run-command` with dependent `read-app`, `read-network`, or `inspect-ui` calls when the second step depends on the first step's side effects. Serialize mutation, then observation, to avoid racey route and scroll state.

## Shell Patterns

- Read one fact instead of the whole payload:
  `flutter_cockpit_devtools read-app --profile minimal | jq '{sessionId,currentRouteName,state}'`
- Extract one scalar when only the next branch decision matters:
  `flutter_cockpit_devtools read-app --profile minimal | jq -r '.currentRouteName'`
- Reload commands report status under nested fields:
  `flutter_cockpit_devtools hot-reload --app-json /tmp/flutter_cockpit/app.json | jq '{reloadGeneration: .status.reloadGeneration, lastReloadSucceeded: .status.lastReloadSucceeded, lastReloadMode: .status.lastReloadMode}'`
- For immediate branch decisions, keep task results on stdout and project only the needed fields:
  `flutter_cockpit_devtools validate-task --config-json /tmp/validate_task.json | jq '{classification,recommendedNextStep,validationFailures}'`
- Keep large results off stdout and read only the needed fields later:
  `flutter_cockpit_devtools validate-task --config-json /tmp/validate_task.json --output-json /tmp/validate_task_result.json`
  `jq '{classification,recommendedNextStep,validationFailures}' /tmp/validate_task_result.json`
- Search a dependency package, then read only the matched file:
  `flutter_cockpit_devtools grep-package-uris --package flutter --query ThemeData | jq -r '.packages[0].files[0].packageUri'`
- For command results, prefer a short projection:
  `flutter_cockpit_devtools run-command --app-json /tmp/flutter_cockpit/app.json --command-file /tmp/command.json --profile standard | jq '{success,commandId,currentRouteName,uiSummary,snapshotRef}'`
- After `enterText`, do not rely on `uiSummary.textPreviews` to echo the field contents. Prefer verifying the next state transition, dependent control, or downstream saved result.
- Use pipes only to trim the response. Do not ask the app for heavier profiles unless the filtered low-cost result still leaves the next fact ambiguous.

## Tool Selection

- Enumerate launchable devices: `list_targets` / `list-targets`
- Launch: `launch_app` / `launch-app`
- Target launch: `launch_target` / `launch-target`
- Lightweight state: `read_app` / `read-app`
- Target state: `read_target` / `read-target`
- UI structure or ambiguity: `inspect_ui` / `inspect-ui`
- Surface structure: `inspect_surface` / `inspect-surface`
- One action: `run_command` / `run-command`
- Ordered steps: `run_batch` / `run-batch`
- Direct host or target shell: `run_shell` / `run-shell`
- Settle: `wait_idle` / `wait-idle`
- Network activity: `read_network` / `read-network`
- Runtime failures: `read_errors` / `read-errors`
- App-centric logs: `read_logs` / `read-logs`
- Dependency search: `pub_dev_search` / `pub-dev-search`
- Dependency edits: `pub`
- Dependency source search: `grep_package_uris` / `grep-package-uris`
- Package source reads: `read_package_uris` / `read-package-uris`
- Focused static checks: `analyze_files` / `analyze-files`
- Code intelligence: `lsp`
- Code changes: `hot_reload` / `hot-reload`, `hot_restart` / `hot-restart`
- Evidence capture: `start_recording` / `start-recording`, `stop_recording` / `stop-recording`
- Cleanup: `stop_app` / `stop-app` when you launched the app for this loop
- Running-app bundle: `run_script` / `run-script`
- Full orchestration: `run_task` / `run-task`
- Final delivery gate: `validate_task` / `validate-task`

## Completion Gate

Do not report completion unless you have:

- verified the app is reachable
- executed the relevant flow against the live app
- read post-action state instead of trusting command success alone
- used `validate_task` / `validate-task` for final acceptance-facing claims
- identified concrete evidence paths when a bundle is involved
- read plane-aware bundle signals such as `targetKind`, `primaryExecutionPlane`, `planesUsed`, `surfaceKindsUsed`, `fallbackCount`, and fallback gates before declaring success
- treated `run_script` bundle failures as real task failures
- cleaned up owned app processes when the loop is finished or intentionally left them running

## Capability Truth

- Treat `capabilities.capabilityProfile` as the canonical source for platform-specific powers such as browser DOM access, host shell automation, and screen recording.
- The legacy booleans (`supportsInAppControl`, `supportsFlutterViewCapture`, `supportsNativeScreenCapture`, `supportsHostAutomation`) are still useful fast filters, but when they and `capabilityProfile` differ, prefer the richer `capabilityProfile`.
- Distinguish target platform from host prerequisites. A web target can truthfully expose browser-host recording in `capabilityProfile` while `recordingLimitations` still warns that the local desktop has not granted screen-capture permission yet.

## References

- [`examples/rapid-dev-loop.md`](examples/rapid-dev-loop.md)
- [`examples/cli-command-reference.md`](examples/cli-command-reference.md)
- [`examples/runtime-validation.md`](examples/runtime-validation.md)
- [`examples/acceptance-delivery.md`](examples/acceptance-delivery.md)
- [`examples/failure-with-evidence.md`](examples/failure-with-evidence.md)
- [`examples/flutter-app-setup.md`](examples/flutter-app-setup.md)
- [`examples/host-devtools-setup.md`](examples/host-devtools-setup.md)
