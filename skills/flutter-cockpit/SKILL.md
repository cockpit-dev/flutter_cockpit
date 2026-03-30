---
name: flutter-cockpit
description: Use when a Flutter task must prove live UI, interaction, route, network, or acceptance state with runtime evidence instead of code-only reasoning.
---

# Flutter Cockpit

## Overview

Use this skill when the task needs live Flutter evidence, not just source inspection.

Default loop:

1. launch or reuse the app
2. read the smallest useful state
3. execute one command or a short batch
4. inspect only the next missing fact
5. repeat until stable
6. validate delivery before any final claim

## When To Use

Use this skill when the task involves:

- running a Flutter app
- checking visible UI, route, or interaction state
- reproducing a bug in a live app
- hot reload or hot restart during implementation
- collecting screenshots or recordings
- producing bundle-backed acceptance evidence

Do not use this skill for docs-only edits or purely static refactors with no runtime claim.

## Required Workflow

1. `assess`
   If the claim depends on live UI, route, interaction, logs, or acceptance evidence, use this skill.
2. `bootstrap`
   Use `launch_app` / `launch-app`. On CLI, persist `app.json`. On MCP, `list_apps` can recover tracked apps.
3. `baseline`
   Start with `read_app` / `read-app --profile minimal`. Escalate only if that does not answer the next question.
4. `execute`
   Prefer `run_command` for one action and `run_batch` for short ordered sequences. Use `wait_idle`, `read_errors`, `read_logs`, `hot_reload`, and `hot_restart` only as needed.
5. `observe`
   Re-read with the smallest profile that answers the next missing fact. Default to `minimal` or `standard`, then escalate to `inspect`, then `evidence`.
6. `judge`
   Use `completed`, `failed_with_evidence`, `blocked_by_environment`, or `needs_more_work`.
7. `deliver`
   Use `run_script` for a running app, `run_task` for full orchestration, and `validate_task` before any acceptance-facing completion claim.

## Result Profiles

- `minimal`
  Fast status, lowest token cost.
- `standard`
  Adds bounded UI summary and snapshot refs.
- `inspect`
  Adds failure-oriented diagnostics and deltas.
- `evidence`
  Use only for the final or hardest cases.

Default to the smallest profile that answers the current question.

## Token Discipline

- Prefer `minimal` or `standard` unless the current question is still ambiguous.
- Prefer `read_app` and `inspect_ui` summaries before raw snapshot payloads.
- Prefer bundle summaries and gate failures before opening large artifact files.
- Ask for one missing fact per step, not every diagnostic dimension at once.

## Tool Selection

| Need | Preferred surface |
| --- | --- |
| Launch the app | `launch_app` / `launch-app` |
| Read current route and lightweight state | `read_app` / `read-app` |
| Investigate UI structure or ambiguity | `inspect_ui` / `inspect-ui` |
| Execute one action | `run_command` / `run-command` |
| Execute several ordered actions | `run_batch` / `run-batch` |
| Wait for UI to settle | `wait_idle` / `wait-idle` |
| Check runtime failures | `read_errors` / `read-errors` |
| Read app-centric logs | `read_logs` / `read-logs` |
| Reload code changes | `hot_reload`, `hot_restart` |
| Start and stop evidence recording | `start_recording`, `stop_recording` |
| Produce a bundle from a running app | `run_script` / `run-script` |
| Full closed-loop orchestration | `run_task` / `run-task` |
| Final delivery gate | `validate_task` / `validate-task` |

## Completion Gate

Do not report completion unless you have:

- verified the app is reachable
- executed the relevant flow against the live app
- read post-action state instead of trusting command success alone
- used `validate_task` / `validate-task` for final acceptance-facing claims
- identified concrete evidence paths when a bundle is involved

## Red Flags

Stop and correct the workflow if you catch yourself thinking:

- “The command passed, so the UI must be right.”
- “I can skip a baseline because this change is small.”
- “I should always ask for the biggest snapshot.”
- “One screenshot is enough to claim final completion.”
- “The app is already running, so I do not need `app.json`.”

## References

- [`examples/cli-command-reference.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/examples/cli-command-reference.md)
- [`examples/runtime-validation.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/examples/runtime-validation.md)
- [`examples/acceptance-delivery.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/examples/acceptance-delivery.md)
- [`examples/host-devtools-setup.md`](/Users/iota9star/Development/workspace/flutter/flutter_pilot/skills/flutter-cockpit/examples/host-devtools-setup.md)
