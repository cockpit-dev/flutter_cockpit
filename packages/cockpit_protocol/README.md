# cockpit_protocol

Platform-neutral Dart protocol models shared by Cockpit clients, runtimes,
drivers, and host tooling.

Most users should depend on `flutter_cockpit` in Flutter apps and `cockpit` for
host tooling. Direct protocol consumers import
`package:cockpit_protocol/cockpit_protocol.dart`. This package has no Flutter SDK
dependency, so CLI, MCP, GUI, and third-party clients can share the same wire
models.

Version 2.0 replaces the former `flutter_cockpit_protocol` package. There is no
compatibility forwarding package.

## Standalone E2E contract

`cockpit.test/v2` is the stable, platform-neutral case contract. A case owns
target requirements, typed constants/inputs/secret references, local
fragments, setup/main/finally sections, bounded control flow, evidence policy,
and explicit safety declarations. The published JSON Schema is
[`schema/cockpit.test.v2.schema.json`](schema/cockpit.test.v2.schema.json).

The protocol deliberately separates authored templates from bound execution
values:

- `CockpitTestCase`, `CockpitTestStepTemplate`, action/condition templates,
  locators, variables, and policies describe an authored case.
- `CockpitTestRunContext` provides the full
  `projectId -> workspaceId -> runId -> caseId -> attemptId` identity chain.
- `CockpitTestAttemptResult`, `CockpitTestError`, step occurrences, and
  `CockpitTestAttemptBundleManifest` are the stable client/report contract.
- Secrets are authored as provider references. Resolved values are not part of
  any protocol object, JSON representation, result, diagnostic, or report.

The package contains no parser, YAML, filesystem, Flutter, driver, service, or
GUI dependency. Host execution belongs to `package:cockpit`; future official
or third-party clients can parse these DTOs and consume the same result and
bundle contracts independently.

Only `schemaVersion: cockpit.test/v2` with `kind: case` is accepted in this
runtime slice. Project/suite documents, batching, scheduling, and service
lifecycle are separate Supervisor capabilities and are not implied by this
case contract.

## Supervisor foundation contract

`cockpit.foundation/v2` is the stable client contract for the per-user
Supervisor. It defines strict DTOs for API/feature negotiation, registered
roots and workspaces, discoverable typed operations, standalone case
submission, run lifecycle and outcome, durable events, immutable artifacts,
leases, pagination, idempotency, and structured failures.

The published contracts are:

- [`schema/cockpit.foundation.v2.schema.json`](schema/cockpit.foundation.v2.schema.json)
  for JSON request, response, resource, and event shapes;
- [`openapi/cockpit.v2.openapi.json`](openapi/cockpit.v2.openapi.json) for the
  authenticated `/api/v2` HTTP and SSE surface;
- `cockpitFoundationV2SchemaJson` and `cockpitV2OpenApiJson` for compiled Dart
  clients that cannot read package data files at runtime.

Requests always reject unknown fields and enum values. Negotiated responses may
ignore additive fields or preserve declared extensible enum values only when
the corresponding feature id was negotiated. API lifecycle (`queued`,
`running`, `completed`) is distinct from product outcome and stability. A
failure keeps one primary error plus ordered cleanup/evidence warnings, so
secondary failures never replace the original cause.

The Workstream 1 API accepts exactly one inline or indexed standalone case per
run. Suite, matrix, aggregate report, native black-box driver, GUI, and AI
exploration capabilities are intentionally absent until their contracts and
runtimes ship. Future official Flutter GUI and third-party clients consume the
same discovery, resource, operation, event, and artifact contracts without an
in-process execution path.
