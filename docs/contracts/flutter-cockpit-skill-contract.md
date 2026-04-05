# Flutter Cockpit Skill Contract

## Purpose

This contract defines what the repository-backed `flutter-cockpit` skill may rely on and what it must require from an agent before the agent claims success.

## Current Capability Dependencies

The skill may depend on these implemented public workflows:

- app bootstrap through `launch-app` / `launch_app`
- tracked app discovery through persisted `app.json` on CLI and `list_apps` on MCP
- bounded app reads through `read-app` / `read_app`
- richer UI investigation through `inspect-ui` / `inspect_ui`
- single-command control through `run-command` / `run_command`
- multi-command control through `run-batch` / `run_batch`
- wait gating through `wait-idle` / `wait_idle`
- network investigation through `read-network` / `read_network`
- reload during development through `hot-reload` / `hot_reload` and `hot-restart` / `hot_restart`
- app-centric log and error reads through `read-logs` / `read_logs` and `read-errors` / `read_errors`
- on-demand recording through `start-recording` / `start_recording` and `stop-recording` / `stop_recording`
- bundle production through `run-script` / `run_script`
- full closed-loop orchestration through `run-task` / `run_task`
- final delivery validation through `validate-task` / `validate_task`
- task bundle summary reads through `read_task_bundle_summary`
- workspace intelligence through `pub_dev_search`, `pub`, `grep_package_uris`, `read_package_uris`, `lsp`, `analyze_files`, `create_project`, `analyze_workspace`, `format_workspace`, `run_tests`, and `apply_fixes`
- multi-signal locators with `text`, `tooltip`, `semanticId`, optional stable `key`, `route`, `type`, fuzzy `path`, nested `ancestor`, and ordered `fallbacks`
- bounded timeouts on interactive commands (`timeoutMs`) and workspace tools (`timeoutSeconds`)
- canonical lower camel case JSON fields across CLI and MCP payloads so shell filters and prompt snippets stay stable

The skill may also rely on public context resources for roots, contracts, capabilities, apps, task summaries, and package reads. Treat any extra repository-specific context document as optional host configuration, not a default framework dependency.

## Mandatory Workflow Stages

The skill must enforce this order:

1. `assess`
2. `bootstrap`
3. `baseline`
4. `execute`
5. `observe`
6. `judge`
7. `deliver`

### `bootstrap`

The agent must launch or reuse an app and persist `app.json` when possible.

The skill must not teach session-handle-first workflows as the default path.

### `baseline`

The agent must read current state before key actions.

Minimum baseline:

- app reachability
- current route or equivalent app state
- profile-appropriate evidence for the task
- the smallest profile that can answer the current question

For code-editing work, the agent should prefer `lsp` and `analyze_files` before falling back to workspace-wide analysis.

### `execute`

The agent must prefer `run_command` and short `run_batch` loops during active debugging.

The skill must not teach full bundle orchestration as the default loop for every small change.

### `observe`

The agent must inspect post-action state and not trust command success alone.

For bundle-backed work, the agent must inspect the resulting summary and evidence paths.

The skill must teach token discipline:

- prefer `minimal` and `standard` before `inspect` or `evidence`
- prefer bundle summaries before raw artifact files
- request one missing fact at a time instead of all diagnostics by default

### `deliver`

The agent must use `validate_task` before a final completion claim on acceptance-facing work.

## Completion Gate

The skill must forbid `completed` unless the agent has:

- verified live app reachability
- executed the relevant workflow against the running app
- read post-action state
- validated delivery evidence for acceptance-facing claims
- identified artifact paths when a bundle is involved

## Failure Taxonomy

The skill must require explicit use of:

- `completed`
- `failed_with_evidence`
- `blocked_by_environment`
- `needs_more_work`

## Non-Goals

The skill must not:

- claim success from command completion alone
- force every workflow through the heaviest profile
- require capabilities that are not present on the current mainline
- imply that bundle generation automatically sends files to the user
