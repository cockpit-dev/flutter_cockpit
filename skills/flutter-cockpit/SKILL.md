---
name: flutter-cockpit
description: Use when a Flutter task must prove live UI, interaction, route, network, or acceptance state with runtime evidence instead of code-only reasoning.
---

# Flutter Cockpit

Use this skill when the task needs live Flutter evidence, not just source inspection.
Default loop: launch or reuse the app, read the smallest useful state, execute one action or short batch, inspect only the next missing fact, then validate delivery before any final claim.
Prefer the lowest-token public surface. In shell-driven work that is usually the shipped CLI. Use MCP when the host specifically needs tool calling, roots-aware state, or a long-lived server surface.

## When To Use

- running a Flutter app
- proving visible UI, route, or interaction state
- reproducing a live bug
- editing Dart or Flutter code and needing focused dependency, analyzer, or symbol facts before another runtime pass
- hot reload or hot restart during implementation
- collecting screenshots, recordings, or bundle-backed acceptance evidence

Do not use it for docs-only edits or static refactors with no runtime claim.

## Required Workflow

1. `bootstrap`
   Use `launch_app` / `launch-app`. Prefer a Cockpit development entrypoint such as `cockpit/main.dart` when the project provides one. On CLI, persist `app.json` and reuse it instead of relaunching. On MCP, `list_apps` can recover tracked apps.
2. `baseline`
   Start with `read_app` / `read-app --profile minimal`.
3. `execute`
   Prefer `run_command` for one action and `run_batch` for short ordered steps. Use `wait_idle`, `read_network`, `read_errors`, `read_logs`, `hot_reload`, and `hot_restart` only when they answer the next question.
   For code-side questions, prefer `lsp`, `analyze_files`, and `pub` before broader workspace commands.
4. `observe`
   Re-read with the smallest profile that answers the next missing fact.
5. `deliver`
   Use `run_script` for a running app, `run_task` for full orchestration, and `validate_task` before any acceptance-facing claim. Treat CLI `run-script` non-zero exit or MCP `run_script` `isError=true` as a failed bundle.

## Locator Guidance

- Start with `key`, `text`, or `semanticId`.
- Add `route`, `type`, `path`, or nested `ancestor` only when ambiguity remains.
- `path` is fuzzy. Segments such as `body`, `slivers`, and numeric indexes are ignored, so shorter structural paths are preferred over brittle full trees.
- Use short ordered `fallbacks` instead of one over-constrained locator.

## Profiles And Timeouts

- `minimal`: fast status, lowest token cost
- `standard`: bounded UI summary and snapshot refs
- `inspect`: failure-oriented diagnostics and deltas
- `evidence`: final or hardest cases only

Default to the smallest profile that answers the current question.
Interactive app commands accept `timeoutMs`. Workspace tools accept `timeoutSeconds`. Raise them only for known slow steps such as long scrolls, `run_task`, or package operations.

For the shortest edit -> reload -> verify loop, use the rapid loop reference instead of escalating every step to bundle-grade evidence.

## Token Discipline

- Prefer `minimal` or `standard` unless the current question is still ambiguous.
- Prefer `read_app` and `inspect_ui` summaries before raw snapshot payloads.
- Prefer `read_network` over snapshot diagnostics when the next question is only about requests, failures, or endpoint coverage.
- For traffic verification, use `run_command` -> `wait_idle` -> `read_network` before escalating to heavier UI inspection.
- Prefer bundle summaries and gate failures before opening large artifact files.
- Ask for one missing fact per step, not every diagnostic dimension at once.
- Prefer `--output-json` plus shell filtering over pasting large raw JSON back into context.
- Prefer `jq -r` or short pipes to extract one route, status, failure code, or readiness field at a time.
- Prefer `--command-file`, `--commands-file`, and `--config-json` files over long inline JSON literals when the payload is more than a few lines.
- Reuse `app.json`, command files, and config files across loops instead of regenerating them in every step.
- Workspace CLI commands default `--workspace-root` or `--parent-directory` to the current directory, so avoid repeating that flag unless you are operating outside the current repo.

## Shell Patterns

- Read one fact instead of the whole payload:
  `flutter_cockpit_devtools read-app --app-json /tmp/flutter_cockpit/app.json --profile minimal | jq '{sessionId,currentRouteName,state}'`
- Extract one scalar when only the next branch decision matters:
  `flutter_cockpit_devtools read-app --app-json /tmp/flutter_cockpit/app.json --profile minimal | jq -r '.currentRouteName'`
- Keep large results off stdout and read only the needed fields later:
  `flutter_cockpit_devtools validate-task --config-json /tmp/validate_task.json --output-json /tmp/validate_task_result.json`
  `jq '{classification,recommendedNextStep,validationFailures}' /tmp/validate_task_result.json`
- For command results, prefer a short projection:
  `flutter_cockpit_devtools run-command --app-json /tmp/flutter_cockpit/app.json --command-file /tmp/command.json --profile standard | jq '{success,commandId,currentRouteName,uiSummary,snapshotRef}'`
- Use pipes only to trim the response. Do not ask the app for heavier profiles unless the filtered low-cost result still leaves the next fact ambiguous.

## Tool Selection

- Launch: `launch_app` / `launch-app`
- Lightweight state: `read_app` / `read-app`
- UI structure or ambiguity: `inspect_ui` / `inspect-ui`
- One action: `run_command` / `run-command`
- Ordered steps: `run_batch` / `run-batch`
- Settle: `wait_idle` / `wait-idle`
- Network activity: `read_network` / `read-network`
- Runtime failures: `read_errors` / `read-errors`
- App-centric logs: `read_logs` / `read-logs`
- Dependency search: `pub_dev_search` / `pub-dev-search`
- Dependency edits: `pub`
- Package source reads: `read_package_uris` / `read-package-uris`
- Focused static checks: `analyze_files` / `analyze-files`
- Code intelligence: `lsp`
- Code changes: `hot_reload`, `hot_restart`
- Evidence capture: `start_recording`, `stop_recording`
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
- treated `run_script` bundle failures as real task failures
- cleaned up owned app processes when the loop is finished or intentionally left them running

## References

- [`examples/rapid-dev-loop.md`](examples/rapid-dev-loop.md)
- [`examples/cli-command-reference.md`](examples/cli-command-reference.md)
- [`examples/runtime-validation.md`](examples/runtime-validation.md)
- [`examples/acceptance-delivery.md`](examples/acceptance-delivery.md)
- [`examples/failure-with-evidence.md`](examples/failure-with-evidence.md)
- [`examples/flutter-app-setup.md`](examples/flutter-app-setup.md)
- [`examples/host-devtools-setup.md`](examples/host-devtools-setup.md)
