# Host Devtools Setup Example

Use this when the host needs to drive `flutter_cockpit` from outside the app.

## Install

```yaml
dev_dependencies:
  flutter_cockpit_devtools: any
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
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-task --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools validate-task --help
```

MCP:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

## Host Guidance

- persist `app.json` and reuse it
- treat `list_apps` as MCP-only state recovery; do not expect an equivalent CLI registry
- prefer `read-app` before taking heavier snapshots
- use `run-command` and `run-batch` for active debugging
- use `run-task` and `validate-task` for final delivery work
- prefer the shipped public workspace surfaces: CLI inside shell agents, MCP when the host specifically needs tool calling or roots-aware server state
