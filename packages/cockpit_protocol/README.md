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
