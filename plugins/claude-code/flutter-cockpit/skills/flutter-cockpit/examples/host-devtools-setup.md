# Host Devtools Setup Example

Use this when the host needs to drive `flutter_cockpit` from outside the app.

## Install

```yaml
dev_dependencies:
  cockpit: ^1.1.4
```

```bash
dart pub get
```

## Recommended Host Usage

For most hosts, prefer the shipped CLI or MCP server instead of calling low-level Dart services directly.
Default to the low-cost public surface that answers the current task. Do not expose or invoke delivery workflows as the normal edit loop.

CLI:

```bash
dart run cockpit list-targets --help
dart run cockpit launch-app --help
dart run cockpit launch-target --help
dart run cockpit read-target --help
dart run cockpit inspect-surface --help
dart run cockpit run-shell --help
dart run cockpit run-command --help
dart run cockpit read-task-bundle-summary --help
dart run cockpit run-task --help
dart run cockpit validate-task --help
```

MCP:

```bash
dart run cockpit serve-mcp
```

Generic config:

```json
{
  "mcpServers": {
    "flutter-cockpit": {
      "command": "dart",
      "args": [
        "run",
        "cockpit",
        "serve-mcp"
      ]
    }
  }
}
```

## Host Guidance

- persist `app.json` and reuse it
- persist `target.json` and reuse it for target-first loops
- treat `list_apps` as MCP-only state recovery; do not expect an equivalent CLI registry
- prefer `read-app` before taking heavier snapshots
- prefer `read-target` plus `inspect-surface` before reaching for shell control on browser or mixed system targets
- use `run-command` and `run-batch` for active debugging
- use `run-task` and `validate-task` only for final delivery, acceptance, release readiness, or artifact-backed handoff
- prefer the shipped public workspace surfaces: CLI inside shell agents, MCP when the host specifically needs tool calling or roots-aware server state
- use MCP `add_roots` when a task must inspect an adjacent repo or linked package; manual roots merge with host-provided roots instead of replacing them
