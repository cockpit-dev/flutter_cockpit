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

`cockpit.test/v2` is the stable, platform-neutral project, suite, fixture,
matrix, and case contract. Cases own target requirements, typed
constants/inputs/secret references, local fragments, setup/main/finally
sections, bounded control flow, evidence policy, and explicit safety
declarations. Suites own dependency-aware campaigns, scoped fixtures, matrix
expansion, concurrency, retry, fail-fast, and report policy. The published JSON Schema is
[`schema/cockpit.test.v2.schema.json`](schema/cockpit.test.v2.schema.json).

The protocol deliberately separates authored templates from bound execution
values:

- `CockpitTestProject`, `CockpitTestSuite`, `CockpitTestFixture`,
  `CockpitTestCase`, step/action/condition templates, locators, variables, and
  policies describe authored documents.
- `CockpitTestRunContext` provides the full
  `projectId -> workspaceId -> runId -> caseId -> attemptId` identity chain.
- `CockpitTestAttemptResult`, `CockpitTestSuiteReport`, `CockpitTestError`,
  step occurrences, and immutable artifact manifests are the stable
  client/report contract.
- Secrets are authored as provider references. Resolved values are not part of
  any protocol object, JSON representation, result, diagnostic, or report.

The package contains no parser, YAML, filesystem, Flutter, driver, service, or
GUI dependency. Host execution belongs to `package:cockpit`; future official
or third-party clients can parse these DTOs and consume the same result and
bundle contracts independently.

`schemaVersion: cockpit.test/v2` accepts `kind: project`, `kind: suite`, and
`kind: case`. Execution remains a host responsibility: the Supervisor and
isolated workspace workers schedule cases and suites while clients consume the
same DTO, event, and artifact contracts.

## Supervisor foundation contract

`cockpit.foundation/v2` is the stable client contract for the per-user
Supervisor. It defines strict DTOs for API/feature negotiation, registered
roots and workspaces, discoverable typed operations, case and suite
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

The API supports indexed case runs and durable suite campaigns with matrix,
fixture, retry, dependency, concurrency, and aggregate report semantics.
Native black-box execution is selected through registered targets and remains
behind the same operation, event, and artifact contracts. Official or
third-party GUI clients consume these boundaries without linking host runtime
services in-process.
