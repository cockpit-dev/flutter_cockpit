# Flutter Cockpit Protocol

This is the stable entry point for AI agents and MCP hosts that need to load
Flutter Cockpit context with minimum guessing. Start here, then open only the
specific contract needed for the current task.

MCP resource URI: `cockpit://workspace/protocol`.

## Contract Map

| Need | File | MCP resource |
| ---- | ---- | ------------ |
| Default AI development loop | `docs/contracts/ai-development-protocol.md` | `cockpit://workspace/ai-development-protocol` |
| Workflow script syntax and execution rules | `docs/contracts/control-workflow-protocol.md` | `cockpit://workspace/control-workflow-protocol` |
| Machine validation for workflow YAML/JSON | `docs/contracts/control-workflow.schema.json` | `cockpit://workspace/control-workflow-schema` |
| Bundle layout and artifact traceability | `docs/contracts/task-run-bundle.md` | `cockpit://workspace/task-bundle-contract` |
| Maintainer-facing skill guarantees | `docs/contracts/flutter-cockpit-skill-contract.md` | `cockpit://workspace/skill-contract` |

Published package fallback copies live under
`packages/cockpit/doc/contracts/` and
`doc/contracts/` when the current directory is the cockpit package root.

## Loading Policy

1. Load this protocol entry first when the host supports MCP resources.
2. For normal app development, load the AI development protocol.
3. For scripted E2E, branch, retry, loop, or replayable flows, load the
   workflow protocol and schema.
4. For produced evidence bundles, load the task bundle contract before reading
   raw artifacts.
5. For skill or prompt maintenance, load the skill contract.

Do not load every contract by default. Each opened document should reduce a
specific uncertainty in the current development or validation loop.

## CLI And MCP Defaults

`serve-mcp` exposes this entry point by default. Override only when embedding a
custom contract set:

```bash
dart run cockpit serve-mcp \
  --protocol-file docs/contracts/flutter-cockpit-protocol.md
```

The default CLI stdout is AI-readable. Use `--stdout-format json` for shell
pipelines and `--output <path> --output-format json` when another program must
reopen structured output from disk.

## Stability Rules

- Resource URIs are stable public context boundaries.
- Contract files may add fields or sections but must not remove shipped
  meanings without a major protocol revision.
- Unsupported platform capabilities must be reported as unavailable or blocked
  by environment, not simulated as success.
- Product proof requires live state or artifact evidence, not command success
  alone.
