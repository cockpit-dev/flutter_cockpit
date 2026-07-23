# cockpit

[![pub package](https://img.shields.io/pub/v/cockpit?logo=dart&label=pub.dev)](https://pub.dev/packages/cockpit)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/cockpit/LICENSE)

[简体中文](README.zh-CN.md)

`cockpit` is the authenticated host client and headless execution package for
Cockpit 2.0. It contains the Supervisor daemon, isolated workspace worker,
resource-oriented CLI, and a thin MCP server. It does not bundle a GUI or a web
dashboard.

## Install

Cockpit requires Dart 3.8 or newer. Use the Dart SDK bundled with Flutter 3.32
or newer for Flutter workspaces.

```yaml
dev_dependencies:
  cockpit: ^2.0.0
```

The package publishes four executables:

- `cockpit`: interactive resource commands
- `cockpit_mcp`: MCP stdio server
- `cockpitd`: Supervisor daemon and foreground CI runner
- `cockpit_worker`: private workspace worker process

## Interactive Workspaces

The CLI starts the per-user Supervisor when an interactive API command needs
it. Register every project root and checkout explicitly:

```bash
dart run cockpit daemon start
dart run cockpit root add --path /work/projects --label projects
dart run cockpit workspace register --root-id <rootId> --path /work/projects/app-a
dart run cockpit workspace register --root-id <rootId> --path /work/projects/app-b
dart run cockpit workspace list
```

Workspace commands accept `--workspace-id`. When it is omitted, Cockpit
resolves the current directory against registered active workspaces and
requires exactly one match. It never selects a global latest run, active
session, or unrelated checkout.

```bash
cd /work/projects/app-a
dart run cockpit operation list
dart run cockpit case list
```

`operation run` accepts typed JSON only and executes an advertised operation.
The descriptor controls scope and idempotency; there is no arbitrary URL or
HTTP method transport.

```bash
dart run cockpit operation run \
  --kind analyze.workspace \
  --workspace-id <workspaceId> \
  --input-json '{}'
```

## Canonical Case Replay

Validate a case document, then submit an indexed case using its canonical
document digest. Replays use explicit workspace, document, case, and
idempotency identities.

```bash
dart run cockpit case validate \
  --workspace-id <workspaceId> \
  --file example/cases/flutter_login.yaml

dart run cockpit case run \
  --workspace-id <workspaceId> \
  --document-id <documentId> \
  --case-id flutter-login \
  --idempotency-key ci-login-001 \
  --inputs-json '{}'

dart run cockpit run get --run-id <runId>
dart run cockpit run events --run-id <runId> --after-sequence 0
```

Run events use authenticated SSE with `afterSequence` and `Last-Event-ID`
resume support. Gap, terminal, and disconnect states are explicit. Artifacts
are read with expected size and SHA-256 values and are rejected when response
metadata or bytes differ.

## Foreground CI

CI uses the same HTTP API and worker boundary as interactive mode. Foreground
mode owns the daemon lifetime, registers the supplied checkout, submits the
provided `CockpitRunSubmission` JSON, waits for terminal run truth, and exits
with a process status derived from the run outcome.

```bash
dart run cockpitd \
  --home=/tmp/cockpit-ci \
  --foreground-workspace=/workspace/app \
  --foreground-submission=/workspace/run-submission.json
```

The submission contains the canonical case source, idempotency key, inputs,
and required features. Foreground mode fills the registered `workspaceId`.

## API Discovery

`CockpitDaemonLifecycleClient.ensure()` initializes the Cockpit home, validates
process identity, and returns the current discovery record. Production clients
then:

1. send its bearer token only to the discovered loopback endpoint;
2. read `GET /api/v2/server`;
3. negotiate API major/minor and required features;
4. decode public foundation DTOs strictly;
5. use only advertised `/api/v2` resources and operations.

The shared `CockpitSupervisorApiClient` implements this flow for the CLI and
MCP server, including 1 MiB response limits, bounded pagination, SSE resume,
structured API errors, and artifact integrity checks.

## MCP

Run the dedicated executable:

```bash
dart run cockpit_mcp
```

```json
{
  "mcpServers": {
    "cockpit": {
      "command": "dart",
      "args": ["run", "cockpit_mcp"]
    }
  }
}
```

MCP exposes bounded resources for server, capabilities, roots, workspaces,
operations, cases, and runs. Its tools cover root/workspace lifecycle,
advertised operation execution, case validation/run, run get/cancel/events,
and artifact reads. Every tool crosses the authenticated Supervisor HTTP
boundary; the MCP process does not construct application services.

## Client Boundary

The public `/api/v2` resources, SSE stream, foundation DTOs, and artifact
integrity contract are the only client boundary. A future Flutter GUI or
third-party SDK must use that protocol and must not link Supervisor application
services in-process.

Generated `report.html` files remain portable run artifacts. They are not a
server UI and do not require an HTML route in `cockpitd`.

See [`doc/contracts`](doc/contracts) for protocol material and
[`example/cases`](example/cases) for canonical YAML and JSON cases.
