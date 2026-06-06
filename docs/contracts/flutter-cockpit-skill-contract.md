# Flutter Cockpit Skill Contract

## Purpose

This contract defines what the repository-backed `flutter-cockpit` skill may rely on and what it must require from an agent before the agent claims success.

## Current Capability Dependencies

The skill may depend on these implemented public workflows:

- launchable Flutter target discovery through `list-targets` / `list_targets`
- app bootstrap through `launch-app` / `launch_app`
- target bootstrap through `launch-target` / `launch_target`
- direct remote session bootstrap and control through `launch-remote-session` / `launch_remote_session`, `query-remote-session` / `query_remote_session`, `read-remote-status` / `read_remote_status`, `read-remote-snapshot` / `read_remote_snapshot`, `execute-remote-command` / `execute_remote_command`, and `execute-remote-command-batch` / `execute_remote_command_batch`
- persistent development loops through `launch-development-session` / `launch_development_session`, `query-development-session` / `query_development_session`, `reload-development-session` / `reload_development_session`, `collect-development-probe` / `collect_development_probe`, `compare-development-probe` / `compare_development_probe`, and `stop-development-session` / `stop_development_session`
- tracked app discovery through persisted `app.json` on CLI and `list_apps` on MCP
- bounded app reads through `read-app` / `read_app`
- bounded target reads through `read-target` / `read_target`
- richer UI investigation through `inspect-ui` / `inspect_ui`
- surface-oriented investigation through `inspect-surface` / `inspect_surface`
- single-command control through `run-command` / `run_command`
- named screenshot capture through `capture-screenshot` / `capture_screenshot`
- multi-command control through `run-batch` / `run_batch`
- direct host and target-aware shell execution through `run-shell` / `run_shell`
- Native/System Control Plane discovery through `read-system-capabilities` / `read_system_capabilities`
- bounded Native/System Control Plane actions through `run-system-action` / `run_system_action`
- wait gating through `wait-idle` / `wait_idle`
- network investigation through `read-network` / `read_network`
- reload during development through `hot-reload` / `hot_reload` and `hot-restart` / `hot_restart`
- app-centric log and error reads through `read-logs` / `read_logs` and `read-errors` / `read_errors`
- on-demand recording through `start-recording` / `start_recording` and `stop-recording` / `stop_recording`
- direct remote recording through `start-remote-recording` / `start_remote_recording` and `stop-remote-recording` / `stop_remote_recording`
- bundle production through `run-script` / `run_script`
- full closed-loop orchestration through `run-task` / `run_task`
- final delivery validation through `validate-task` / `validate_task`
- task bundle summary reads through CLI `read-task-bundle-summary` and MCP `read_task_bundle_summary`
- workspace intelligence through `pub_dev_search`, `pub`, `grep_package_uris`, `read_package_uris`, `lsp`, `analyze_files`, `create_project`, `analyze_workspace`, `format_workspace`, `run_tests`, and `apply_fixes`
- multi-signal locators with `text`, `tooltip`, `semanticId`, optional stable `key`, `route`, `type`, fuzzy `path`, nested `ancestor`, and ordered `fallbacks`
- bounded timeouts on interactive commands (`timeoutMs`) and workspace tools (`timeoutSeconds`)
- canonical lower camel case JSON fields across CLI and MCP payloads so shell filters and prompt snippets stay stable
- app-handle metadata preservation across CLI and MCP scripted bundle flows, so `app.json` can carry platform, device, process, and remote-session context while an explicit base URL only overrides the live connection address
- explicit Android and iOS device-id passthrough on app-scoped recording flows, while still preferring `app.json` metadata whenever a handle is available
- host recording prerequisite reporting for web/browser-host flows, so app control, DOM inspection, screenshots, reloads, and runtime reads can stay strict while video proof is classified separately as `blocked_by_environment` when ffmpeg cannot prove startup or output evidence
- completed recording evidence only when an artifact is backed by non-empty bytes or a non-empty source/output file; empty or missing artifact content must be reported as failed evidence, not accepted video proof
- plane-aware task summaries with `targetKind`, `primaryExecutionPlane`, `planesUsed`, `surfaceKindsUsed`, `fallbackCount`, and bounded delivery gates
- structured system-control action parameters in capability metadata, including `required`, `valueType`, `allowedValues`, `minimum`, and `maximum`; default AI-readable output may compact them as `parameters=[name*:type[range](allowed|values)]`

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

The stages are evidence gates, not a fixed command quota. The default path must optimize for rapid development validation: use the cheapest live loop that answers the user's question, reuse fresh valid evidence, and escalate only when the current layer cannot reduce the remaining uncertainty. The main skill must be self-contained for the core app-wiring, launch, edit, reload, observe, evidence, and delivery loop; reference files are optional deep dives, not prerequisites for basic usage. The skill must not reward running extra recording, evidence profiles, bundle validation, or raw artifact reads when they do not improve the decision.

The skill must be platform-discovery-first. Platform and device ids must come from `list-targets`, MCP target discovery, or an explicit user-provided target, then platform capabilities must be read from returned metadata. Action parameter contracts must be read from returned metadata before choosing recording, shell, browser, simulator, emulator, or desktop behavior.

### `bootstrap`

The agent must launch or reuse an app and persist `app.json` when possible.

The skill must not teach session-handle-first workflows as the default path.
For non-Flutter or direct system surfaces, the skill may switch to target-first bootstrap with `launch_target` / `launch-target`, but it should still prefer the smallest truthful capability surface instead of pretending every target is a Flutter app.

### `baseline`

The agent must read current state before key actions.

Minimum baseline:

- app reachability
- current route or equivalent app state
- profile-appropriate evidence for the task
- the smallest profile that can answer the current question

For target-first flows, replace app-specific reads with `read_target` / `read-target` and `inspect_surface` / `inspect-surface` while keeping the same summary-first discipline.
The skill may assume `read_target` can return capability-only summaries for browser or direct system targets, and `inspect_surface` may prefer native/window evidence instead of a Flutter semantic tree when that is the smaller truthful surface.

For code-editing work, the agent should prefer `lsp` and `analyze_files` before falling back to workspace-wide analysis.

### `execute`

The agent must prefer `run_command` and short `run_batch` loops during active debugging.
The skill must teach route-aware recovery for `remoteUnavailable`, transport timeouts, or reconnect windows that happen after a mutating or route-changing step. In that situation the agent must re-read minimal route or state before retrying, resume from the smallest remaining step, and must not blindly replay a non-idempotent batch.

The skill must not teach full bundle orchestration as the default loop for every small change.
The skill must teach that a small edit can be complete after focused static checks, hot reload, a minimal post-action read, current errors, and final visible evidence when applicable.

### `observe`

The agent must inspect post-action state and not trust command success alone.
The skill must treat current route or equivalent state as the first recovery checkpoint after a transient transport failure. If the route already advanced, the agent should continue from the next valid checkpoint instead of replaying the whole mutation sequence.

For bundle-backed work, the agent must inspect the resulting summary and evidence paths.

The skill must teach token discipline:

- prefer `minimal` and `standard` before `inspect` or `evidence`
- prefer bundle summaries before raw artifact files
- prefer bundle `issueEvidence` or `<bundleDir>/issue_evidence.json` before raw `steps.json`, full diagnostics snapshots, screenshots, recordings, or CI log spelunking; it is the first problem-collection packet for failed commands, runtime errors, network failures, artifact issues, gate failures, and evidence paths
- prefer inline snapshot summaries and `artifactDownloads` metadata before downloading externalized diagnostics artifacts
- prefer CLI `errorJson.code`, `errorJson.message`, and `errorJson.details` before interpreting prose stderr when a non-usage command exits non-zero
- prefer `errorJson.details.failureDiagnostics` before guessing fixes for interaction or route failures; this packet must be treated as the first root-cause source for resolved target, activation path, action completion, route changes, UI fingerprint changes, visible targets, and target discovery diagnostics
- preserve remote endpoint error codes such as `bridgeUnavailable`, `artifactNotFound`, `recordingStartFailed`, and `invalidPayload` so agents can choose the correct recovery path instead of treating every non-2xx response as reachability loss
- treat `invalidPayload` as a caller payload or option problem that must be corrected before retrying
- request one missing fact at a time instead of all diagnostics by default
- prefer `run_shell` target scopes only when the resolved platform truthfully exposes shell control, instead of pretending every browser or system target has an attached shell

### `deliver`

The agent must use `validate_task` before a final completion claim on acceptance-facing work.
When a bundle is involved, the skill must treat plane-aware gates and fallback summaries as first-class signals, not optional decoration.

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
- `blocked_by_environment`, including host-level recording prerequisites such as missing screen-capture permission or missing ffmpeg startup/output evidence
- `needs_more_work`

## Non-Goals

The skill must not:

- claim success from command completion alone
- force every workflow through the heaviest profile
- require capabilities that are not present on the current mainline
- imply that bundle generation automatically sends files to the user
