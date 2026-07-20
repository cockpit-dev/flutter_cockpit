# Cockpit 2.0 Foundation Migration Inventory

## Purpose and baseline

This inventory is the factual migration input for the remaining Supervisor
foundation tasks. It records the tree after the protocol replacement and the
standalone `cockpit.test/v2` compiler, importer, runner, and attempt-bundle
hardening commits. It does not introduce an alternative case format, runner,
or report format.

Current published package graph:

```text
cockpit -> cockpit_protocol
flutter_cockpit -> cockpit_protocol
```

`cockpit_protocol` has no production package dependency other than
`collection`; `cockpit` depends on `cockpit_protocol`; and
`flutter_cockpit` depends on `cockpit_protocol` and Flutter SDK packages.
`cockpit` currently declares `cockpit` and `cockpit_mcp` executables only.

The final graph remains exactly the graph above. `cockpitd` and
`cockpit_worker` become private executables of `cockpit`, not packages. The
retired `flutter_cockpit_protocol` package name must have no production
reference.

## Current public and executable surface

### Protocol exports and dependencies

`packages/cockpit_protocol/lib/cockpit_protocol.dart` exports the neutral
runtime/control/capture/recording/session models and the complete standalone
test surface: `CockpitTestCase`, actions, conditions, locators, diagnostics,
imports, policies, runs, values, variables, bundles, and the embedded
`cockpitTestV2SchemaJson`. `cockpit_protocol` is retained as the final public
DTO/schema owner; Task 1 adds the foundation DTOs, foundation schema, and
OpenAPI document there.

`packages/cockpit/lib/cockpit.dart` exports infrastructure, artifacts,
adapters, application services, CLI, MCP, host platform/session/remote code,
DevTools classes, the case runner, compiler, importer, and secret resolver.
The public barrel is narrowed in Tasks 4, 6, and 7: supervisor client-facing
types remain public, while application services and worker adapters become
internal implementation assets.

`packages/flutter_cockpit/lib/flutter_cockpit.dart` exports in-app protocol
models. `flutter_cockpit_flutter.dart` adds Flutter runtime, capture,
gesture, and observer implementation; `flutter_cockpit_remote_bridge.dart`
adds the remote bridge endpoint. All three remain app/runtime assets and are
not a Supervisor API.

Executable entrypoints:

| Current file | Current role | 2.0 disposition |
| --- | --- | --- |
| `packages/cockpit/bin/cockpit.dart` | default CLI; directly creates `CockpitCommandRunner` | retain as the sole CLI distribution; Task 7 makes it a Supervisor client |
| `packages/cockpit/bin/cockpit_mcp.dart` | stdio MCP; directly creates `CockpitMcpServer.standard()` | retain as the sole MCP distribution; Task 7 makes it a Supervisor client |
| `packages/cockpit/bin/cockpit_development_supervisor.dart` | private Flutter development-session child process | delete after Task 4 replaces its role with workspace worker ownership |
| `packages/cockpit/bin/cockpitd.dart` | absent | add privately in Task 6 |
| `packages/cockpit/bin/cockpit_worker.dart` | absent | add privately in Task 4 |

### Default CLI commands (56)

The default list is constructed in
`packages/cockpit/lib/src/cli/cockpit_command_runner.dart`. Commands with no
2.0 capability below are deleted rather than re-exposed under a new spelling.

| Capability | Current commands | Final typed operation/resource and owner |
| --- | --- | --- |
| targets and server diagnostics | `list-targets`, `read-system-capabilities` | `target.list`, `system.capabilities` - **Supervisor** |
| roots and project creation | `create-project` | `root.register`/`root.unregister` resources and `project.create` - **root-scoped Supervisor operation** |
| workspace tooling | `analyze-files`, `analyze-workspace`, `apply-fixes`, `format-workspace`, `grep-package-uris`, `lsp`, `pub`, `pub-dev-search`, `read-package-uris`, `run-tests` | `analyze.files`, `analyze.workspace`, `fix.workspace`, `format.workspace`, `package.uris.grep`, `lsp.request`, `package.pub`, `package.search`, `package.uris.read`, `test.workspace` - **workspace worker**, except `package.search` - **root-scoped Supervisor operation**. `test.workspace` retains Dart/Flutter unit and widget workspace testing; deferred Cockpit suite/project execution remains absent. |
| app and target lifecycle | `launch-app`, `launch-target`, `stop-app`, `read-app`, `read-target`, `list-targets` | `app.launch`, `target.launch`, `app.stop`, `app.get`, `target.get`, `target.list` - **workspace worker**, except `target.list` - **Supervisor** |
| remote session lifecycle | `launch-remote-session`, `query-remote-session`, `read-remote-status`, `read-remote-snapshot`, `collect-remote-snapshot`, `execute-remote-command`, `execute-remote-command-batch`, `wait-remote-ui-idle` | `session.remote.launch`, `session.remote.get`, `session.remote.status`, `snapshot.remote.read`, `snapshot.remote.collect`, `command.remote.execute`, `command.remote.batch`, `ui.remote.waitIdle` - **workspace worker** |
| development-session lifecycle | `launch-development-session`, `query-development-session`, `reload-development-session`, `stop-development-session`, `collect-development-probe`, `compare-development-probe` | `session.development.launch`, `session.development.get`, `session.development.reload`, `session.development.stop`, `development.probe.collect`, `development.probe.compare` - **workspace worker** |
| UI and evidence reads | `inspect-ui`, `inspect-surface`, `capture-screenshot`, `read-logs`, `read-network`, `read-errors`, `read-task-bundle-summary` | `ui.inspect`, `surface.inspect`, `evidence.screenshot.capture`, `logs.read`, `network.read`, `errors.read` - **workspace worker**. Published artifact reads are the `artifact.read` resource - **Supervisor**. |
| interactive control | `run-command`, `run-batch`, `run-shell`, `run-system-action`, `run-script`, `run-remote-control-script`, `hot-reload`, `hot-restart`, `wait-idle` | `command.run`, `command.batch`, `shell.run`, `system.action`, `app.reload`, `app.restart`, `ui.waitIdle` - **workspace worker**; legacy script/control-workflow execution is deleted (not a v2 case route) |
| recording | `start-recording`, `stop-recording`, `start-remote-recording`, `stop-remote-recording` | `recording.start`, `recording.stop` - **workspace worker** |
| legacy task workflow | `run-task`, `validate-task` | delete; standalone `case.validate` and `case.run` replace only the supported validation/run path - **workspace worker** |
| client/legacy hosting | `serve-mcp`, `devtools` | delete; `cockpit_mcp` and `cockpitd` own their respective transports - **Supervisor** for daemon lifecycle |

The final CLI additionally exposes only Supervisor-client resources: daemon
start/status/stop/restart/logs/doctor, root registration/list/removal,
workspace registration/rebind/removal/list, operation discovery/execution,
case validation/run, run get/cancel/events, and artifact read. No current
default command is allowed to retain direct service construction.

### MCP production surface (58 tools, 13 resources, 5 prompts)

`CockpitMcpServer.standard()` in
`packages/cockpit/lib/src/mcp/cockpit_mcp_server.dart` directly constructs all
services, session/latest stores, and tools. Task 7 replaces it with bounded
Supervisor-client resources and typed operation calls.

| Capability | Current MCP tools/resources | Final typed operation/resource and owner |
| --- | --- | --- |
| root and workspace discovery | tools `add_roots`, `remove_roots`; resources `cockpit://workspace/roots`, `cockpit://workspace/capabilities`, `cockpit://workspace/protocol`, `cockpit://workspace/ai-development-protocol`, `cockpit://workspace/skill-contract`, `cockpit://workspace/task-bundle-contract`, `cockpit://workspace/control-workflow-protocol`, `cockpit://workspace/control-workflow-schema` | `/roots`, `/workspaces`, `/capabilities`, operation discovery - **Supervisor**; the six checked-in contract documents are **internal-only reusable assets**, not public v2 resources |
| project/package tooling | tools `create_project`, `pub_dev_search`, `pub`, `read_package_uris`, `grep_package_uris`, `lsp`, `analyze_files`, `analyze_workspace`, `format_workspace`, `run_tests`, `apply_fixes`; resource `cockpit://package/read{?workspaceRoot,uri}` | same typed kinds as CLI, including retained `test.workspace` - **workspace worker** for Dart/Flutter unit and widget workspace testing. `project.create` and `package.search` are **root-scoped Supervisor operations**; deferred Cockpit suite/project execution remains absent. |
| targets/apps/sessions | tools `list_targets`, `list_active_sessions`, `list_apps`, `launch_app`, `launch_target`, `launch_remote_session`, `query_remote_session`, `read_remote_status`, `read_remote_snapshot`, `collect_remote_snapshot`, `launch_development_session`, `query_development_session`, `reload_development_session`, `collect_development_probe`, `compare_development_probe`, `read_session_logs`, `stop_development_session`, `stop_app`, `read_app`, `read_target`; resources `cockpit://app/list`, `cockpit://app/details{?appId}` | `target.list` - **Supervisor**. `list_active_sessions` becomes Supervisor `session.list` plus `workspace.sessions`; `list_apps` becomes worker `app.list` plus `workspace.apps`; `read_session_logs` becomes worker `session.logs.read` plus `workspace.sessionLogs`; `read_app` becomes worker `app.get` plus `workspace.app`. Each named resource kind is keyed by `workspaceId`; retained app/target/session lifecycle and reads are **workspace worker** operations unless explicitly owned by the Supervisor. |
| UI/control/evidence | tools `hot_reload`, `hot_restart`, `inspect_ui`, `inspect_surface`, `run_command`, `capture_screenshot`, `run_batch`, `execute_remote_command`, `execute_remote_command_batch`, `read_system_capabilities`, `run_system_action`, `run_shell`, `wait_idle`, `wait_remote_ui_idle`, `read_logs`, `read_network`, `read_errors`, `read_task_bundle_summary`; resources `cockpit://task/latest`, `cockpit://task/summary{?bundleDir}` | retained typed operations - **workspace worker**; `system.capabilities` - **Supervisor**; final output/artifact resource is authorized and indexed by **Supervisor** |
| recording | tools `start_recording`, `stop_recording`, `start_remote_recording`, `stop_remote_recording` | `recording.start`/`recording.stop` - **workspace worker** |
| legacy task/script | tools `run_remote_control_script` (advertised as `run_script`), `run_task`, `validate_task` | delete; only `case.validate` and standalone `case.run` are retained - **workspace worker** |
| old resources | registered resources `cockpit://app/list`, `cockpit://app/details{?appId}`, `cockpit://task/latest`, `cockpit://task/summary{?bundleDir}`, and `cockpit://package/read{?workspaceRoot,uri}` | replace with `workspace.apps`, `workspace.app`, `workspace.sessions`, `workspace.sessionLogs`, workspace-scoped latest-run, document/case/run, and artifact resources. Delete only the global latest fallback and legacy task-bundle resource. `cockpit_active_sessions_resource.dart` and `cockpit_development_session_resource.dart` exist but are not registered by `CockpitMcpServer.standard()`; treat them as internal/deleted inventory, not production resources. |
| prompts | `run_closed_loop_task`, `inspect_before_claiming_done`, `recover_from_failed_validation`, `prepare_acceptance_delivery`, `create_project_with_validation` | delete from the production MCP surface; source files may remain checked-in guidance assets but are not Supervisor operations/resources |

The final MCP production surface is exactly the compact v2 client surface:
daemon, roots, workspaces, advertised operations, documents/cases,
standalone runs, run cancellation/event observation, and artifact read. Its
resources and tools must not call application-service constructors.

## Deleted DevTools surface and current state

`CockpitDevtoolsServer` is a loopback, optional-token server constructed by
the `devtools` command. It accepts `GET`, `HEAD`, and `POST` under `/api/` and
is entirely deleted in Task 6. Its public 1.x routes are:

| Route | Current behavior | 2.0 disposition |
| --- | --- | --- |
| `POST /api/workflows/parse` | parses legacy control scripts | delete |
| `GET|POST /api/runs` | lists legacy history or submits `runScript`/`validateTask` jobs | delete; v2 standalone run submission is `POST /api/v2/workspaces/{workspaceId}/runs` |
| `GET /api/events` | aggregates historical events by fallback scope | delete; v2 events are run-scoped |
| `GET /api/runs/{runId}/job` | in-memory job state | delete |
| `POST /api/runs/{runId}/cancel` | records request and returns `cancelUnsupported` | delete; v2 cancellation is durable |
| `GET /api/runs/{runId}/state` | serves live JSON state | delete |
| `GET /api/runs/{runId}/events.ndjson` | serves live event file | delete |
| `GET /api/runs/{runId}/events` | polling SSE over the live event file | delete; v2 SSE supports durable replay |
| `GET /api/runs/{runId}/bundle-summary` | reads legacy bundle summary | delete |
| `GET /api/runs/{runId}/bundle-download` | creates a tar download | delete |
| `GET /api/runs/{runId}/artifacts/{path...}` | serves bundle artifact paths | delete; v2 uses opaque artifact ids and digest checks |
| `GET /api/runs/{runId}/bundle/{path...}` | serves arbitrary confined bundle paths | delete |

`CockpitLiveRunStore` persists `history/runs/<safe-name>/live/` with
`events.ndjson`, `live_state.json`, `index.json`, lock file, and per-scope
indexes. It and the `CockpitLiveRun*`, redactor, and DevTools tests are
deleted/replaced by Tasks 5-6. The DevTools run map retains at most 200
in-memory jobs; it is not durable worker truth.

Current in-memory-only stores that must not survive as global 2.0 ownership:

| Current store | State | Final owner/disposition |
| --- | --- | --- |
| `CockpitSessionRegistry` | development and remote records keyed by session/app identity, with global latest-by-app lookup | worker owns durable session truth; replace the global lookup with a **Supervisor** active-session reference index keyed by `workspaceId`, exposed as `session.list`/`workspace.sessions` |
| `CockpitLatestTaskStore` | one process-local latest task snapshot | replace with a **Supervisor** latest-run reference index keyed by `workspaceId`; delete only the global latest fallback |
| `CockpitInteractiveSnapshotStore` | TTL/size-bounded snapshots keyed by session key | move behind worker-owned opaque refs if required by retained interactive operations - **workspace worker** |
| `CockpitInteractiveSessionLock` | process-local per-session serialization | replace with Supervisor lease acquisition plus worker serialization - **Supervisor** for lease, **workspace worker** for local execution |
| `CockpitMcpRootsTracker` | client native/fallback root list | replace with registered allowed-root resources - **Supervisor** |

## Retained worker runtime and adapters

The case runtime is already complete and is retained without parallel
implementation: `src/test/cockpit_test_document_compiler.dart`, action
lowerer, variable binder, safety policy, secret resolver, explicit
`cockpit_control_workflow_importer.dart`, `src/runner/cockpit_case_runner.dart`,
execution kernel/control/lease, and
`src/artifacts/cockpit_test_attempt_{recorder,bundle_writer}.dart`. The worker
validates via `case.validate` and runs one normalized standalone case via
`case.run`; it persists the normalized case/source map and dispatches the
existing runner. The importer is an offline-only migration operation and never
creates a 1.x runtime route.

These retained implementation families move behind the workspace worker:

| Current family | Examples | Final owner |
| --- | --- | --- |
| application services | analyze/fix/format/test, app/target/session lifecycle, LSP, package URI, remote command, inspect/read, shell/system, capture/recording, task artifacts | **workspace worker**, except `CockpitCreateProjectService` and `CockpitPubDevSearchService` become root-scoped Supervisor adapters; legacy task orchestration is deleted |
| remote/session/development | `src/remote/`, `src/session/`, `src/development/`, including Flutter launch machine client | **workspace worker** |
| platform/capture/recording/system-control adapters | `src/platform/`, `src/capture/`, `src/recording/`, `src/system_control/` | **workspace worker**, subject to Supervisor leases/ports before mutation |
| Flutter automation bridge | `CockpitRemoteAutomationAdapter`, remote capture/recording adapters, web bridge, app-side remote endpoint | **workspace worker** owns host adapters; `flutter_cockpit` remains the in-app asset |
| artifacts | attempt bundle reader/writer, task-run writer, validation, video/keyframe helpers | worker writes immutable attempts; **Supervisor** verifies/indexes/authorizes artifact resources and retention |
| generic infrastructure | clock, file system, process manager, SDK environment, HTTP client | internal-only reusable assets usable by foundation/supervisor/worker; not public operations |

The following are intentionally absent from the final foundation: Cockpit
suite/project execution, multi-case/matrix runs, aggregate reports, native
black-box driver, GUI, Web/desktop driver, and AI exploration. Existing
`run-tests`/`run_tests` retain Dart/Flutter unit and widget workspace testing
through `test.workspace`; legacy task orchestration and DevTools
report/bundle endpoints must not become accidental substitutes.

## Source-to-destination migration table

| Source today | Task | Destination/disposition |
| --- | --- | --- |
| `packages/cockpit_protocol/lib/cockpit_protocol.dart`, `schema/cockpit.test.v2.schema.json`, test schema/export tests | 1 | retain test-v2 exports; add `lib/src/foundation/`, `schema/cockpit.foundation.v2.schema.json`, `openapi/cockpit.v2.openapi.json`, generated embeds, and foundation contract tests |
| `packages/cockpit/lib/src/infrastructure/` | 2 | retain reusable interfaces; add `src/foundation/` home paths, locked atomic storage, canonical paths, identity, ids, token permissions |
| `CockpitMcpRootsTracker`, workspace-root/list/create services, session/latest stores | 2 | replace with `src/registry/` allowed roots, workspace marker/registry, workspace-scoped session/run indexes, and Supervisor `workspaceId`-keyed active-session/latest-run reference indexes; delete only global latest fallback |
| process/session port handling in `src/development/`, `src/remote/`, session lock | 3 | add `src/supervisor/lease_registry.dart` and port allocator; workers no longer choose global identity ports |
| application, adapters, platform, capture, recording, remote, session, development, runner, test, artifacts families | 4 | add `src/worker/` RPC peer/server/operation registry/runtime factory; retain application assets only as worker-internal adapters; delete `bin/cockpit_development_supervisor.dart` |
| `CockpitLiveRunStore`, live events/state, task/attempt artifact writers | 5 | replace DevTools projection with worker per-run durable NDJSON and immutable attempt roots; add Supervisor event/artifact projection and replay |
| `src/devtools/`, `devtools_command.dart`, `cockpit_devtools_server_test.dart`, `cockpit_live_run_store_test.dart` | 6 | delete; add `src/supervisor/` discovery, lifecycle, HTTP/SSE API server/client and private `bin/cockpitd.dart` |
| `src/cli/`, `src/mcp/`, `bin/cockpit.dart`, `bin/cockpit_mcp.dart`, CLI/MCP tests | 7 | retain executables and transport shells; replace direct construction with public v2 Supervisor client; delete old default commands/tools/resources/prompts and add client/API tests |
| package/export/metadata, integration, graph, schema, route, bypass tests | 8 | update package graph and exports; add conformance, two-workspace, daemon/worker recovery, lease, SSE, and forbidden-scan coverage |

## Required tests and forbidden scans

The current `cockpit` package has 226 test files. Retain and relocate the
runtime/adapter unit coverage under `test/src/application`, `adapters`,
`capture`, `recording`, `remote`, `platform`, `session`, `development`,
`system_control`, `runner`, `test`, `artifacts`, and `validation` as worker
coverage where the capability is retained. Preserve the existing test-v2
compiler/importer/runner/attempt-bundle coverage and
`packages/cockpit_protocol/test` schema/protocol coverage unchanged.

Replace the current direct-client suites under `test/src/cli`, `test/src/mcp`,
and `test/src/devtools` with v2 client, Supervisor HTTP/SSE, discovery/auth,
worker-RPC, root/workspace scope, lease/port, event/artifact, and recovery
contract/integration tests. Delete DevTools-specific tests with the old server.
Keep `cockpit_exports_test.dart` and root package/metadata tests updated for
the final public graph.

Task 8 must make these source scans part of the gate, with narrowly documented
test/offline-importer exemptions only where stated:

| Scan | Required result |
| --- | --- |
| `flutter_cockpit_protocol` | absent from production and package metadata |
| legacy implicit execution | no production route constructs/runs a 1.x workflow; only the explicit offline importer may read it |
| old HTTP routes | no production `'/api/'` routes remain; public server paths begin at `'/api/v2/'` |
| direct application-service construction | absent from CLI, MCP, public HTTP handlers, and foreground wrappers; permitted only in worker adapters and tests |
| DevTools | `CockpitDevtoolsServer`, `cockpit devtools`, and old `/api` resources absent from production |
| latest/root bypass | no global latest fallback; Supervisor active-session and latest-run references are keyed by `workspaceId`, and every workspace/session/run/artifact request carries and checks workspace ownership |
| package graph | only sibling dependency edges `cockpit -> cockpit_protocol` and `flutter_cockpit -> cockpit_protocol`; no reverse or cross-package dependency |

## Inventory conclusion

The retained production work divides into exactly three owner classes:

| Final owner | Kinds |
| --- | --- |
| **Supervisor** | daemon lifecycle/discovery/auth, server/capability discovery, `target.list`, `system.capabilities`, allowed-root/workspace registries, admission, leases, ports, worker lifecycle, `workspaceId`-keyed `session.list`/`workspace.sessions` and latest-run reference indexes, cross-workspace run/event/artifact indexes, artifact authorization/retention, and public v2 resources |
| **root-scoped Supervisor operation** | `project.create`, `package.search` |
| **workspace worker** | all retained workspace analysis/format/fix/`test.workspace`/package/LSP, target/app/session truth including `app.list`/`workspace.apps`, `app.get`/`workspace.app`, and `session.logs.read`/`workspace.sessionLogs`, remote/development, UI/control, shell/system, capture/recording, document/case validation, standalone case run, event truth, and immutable attempt production |

No retained capability has more than one final operation owner. The old public
DevTools API, global latest fallback state, legacy task/script execution, and
Cockpit suite/project or aggregate execution are deletions, not migration
targets.
