# Host Devtools Setup Example

Use this when the host needs to drive `flutter_cockpit` from outside the app.

## Install

```yaml
dev_dependencies:
  flutter_cockpit_devtools: ^1.0.0
```

```bash
dart pub get
```

## Recommended Host Usage

For most hosts, prefer the shipped CLI or MCP server instead of calling low-level Dart services directly.

CLI:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools list-targets --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools launch-app --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools launch-target --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-target --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools inspect-surface --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-shell --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-task-bundle-summary --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-task --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools validate-task --help
```

MCP:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

Generic config:

```json
{
  "mcpServers": {
    "flutter-cockpit": {
      "command": "dart",
      "args": [
        "run",
        "flutter_cockpit_devtools:flutter_cockpit_devtools",
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
- use `run-task` and `validate-task` for final delivery work
- prefer the shipped public workspace surfaces: CLI inside shell agents, MCP when the host specifically needs tool calling or roots-aware server state
- use MCP `add_roots` when a task must inspect an adjacent repo or linked package; manual roots merge with host-provided roots instead of replacing them
