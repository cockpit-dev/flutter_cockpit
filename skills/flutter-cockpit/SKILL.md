---
name: flutter-cockpit
description: Use when a Flutter task must prove live UI, interaction, route, network, or acceptance state with runtime evidence instead of code-only reasoning.
---

# Flutter Cockpit

Use this skill when the task needs live Flutter evidence, not just source inspection.
Default loop: launch or reuse the app, read the smallest useful state, execute one action or short batch, inspect only the next missing fact, then validate delivery before any final claim.

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
   Use `launch_app` / `launch-app`. On CLI, persist `app.json`. On MCP, `list_apps` can recover tracked apps.
2. `baseline`
   Start with `read_app` / `read-app --profile minimal`.
3. `execute`
   Prefer `run_command` for one action and `run_batch` for short ordered steps. Use `wait_idle`, `read_errors`, `read_logs`, `hot_reload`, and `hot_restart` only when they answer the next question.
   For code-side questions, prefer `lsp`, `analyze_files`, and `pub` before broader workspace commands.
4. `observe`
   Re-read with the smallest profile that answers the next missing fact.
5. `deliver`
   Use `run_script` for a running app, `run_task` for full orchestration, and `validate_task` before any acceptance-facing claim. Treat CLI `run-script` non-zero exit or MCP `run_script` `isError=true` as a failed bundle.

## Locator Guidance

- Start with `key`, `text`, or `semantic_id`.
- Add `route`, `type`, `path`, or nested `ancestor` only when ambiguity remains.
- `path` is fuzzy. Segments such as `body`, `slivers`, and numeric indexes are ignored, so shorter structural paths are preferred over brittle full trees.
- Use short ordered `fallbacks` instead of one over-constrained locator.

## Profiles And Timeouts

- `minimal`: fast status, lowest token cost
- `standard`: bounded UI summary and snapshot refs
- `inspect`: failure-oriented diagnostics and deltas
- `evidence`: final or hardest cases only

Default to the smallest profile that answers the current question.
Interactive app commands accept `timeout_ms`. Workspace tools accept `timeout_seconds`. Raise them only for known slow steps such as long scrolls, `run_task`, or package operations.

For the shortest edit -> reload -> verify loop, use the rapid loop reference instead of escalating every step to bundle-grade evidence.

## Token Discipline

- Prefer `minimal` or `standard` unless the current question is still ambiguous.
- Prefer `read_app` and `inspect_ui` summaries before raw snapshot payloads.
- Prefer bundle summaries and gate failures before opening large artifact files.
- Ask for one missing fact per step, not every diagnostic dimension at once.

## Tool Selection

- Launch: `launch_app` / `launch-app`
- Lightweight state: `read_app` / `read-app`
- UI structure or ambiguity: `inspect_ui` / `inspect-ui`
- One action: `run_command` / `run-command`
- Ordered steps: `run_batch` / `run-batch`
- Settle: `wait_idle` / `wait-idle`
- Runtime failures: `read_errors` / `read-errors`
- App-centric logs: `read_logs` / `read-logs`
- Dependency search: `pub_dev_search`
- Dependency edits: `pub`
- Package source reads: `read_package_uris`
- Focused static checks: `analyze_files`
- Code intelligence: `lsp`
- Code changes: `hot_reload`, `hot_restart`
- Evidence capture: `start_recording`, `stop_recording`
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

## References

- [`examples/rapid-dev-loop.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/examples/rapid-dev-loop.md)
- [`examples/cli-command-reference.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/examples/cli-command-reference.md)
- [`examples/runtime-validation.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/examples/runtime-validation.md)
- [`examples/acceptance-delivery.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/examples/acceptance-delivery.md)
- [`examples/host-devtools-setup.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/examples/host-devtools-setup.md)
