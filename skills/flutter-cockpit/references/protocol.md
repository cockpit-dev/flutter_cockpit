# Flutter Cockpit Protocol Reference

Use this as the skill-local protocol map when MCP resources are unavailable or
the repo root is not already loaded. Load only the contract that reduces the
current uncertainty.

## Reference Contract

This file is the stable, low-token reference entry for agents that already
loaded the `flutter-cockpit` skill. It is not the full development workflow and
must not replace the main `SKILL.md` fast path.

Resolution order:

1. Prefer the MCP resource URI when MCP is available.
2. Fall back to the repo file when working from a monorepo checkout.
3. Fall back to `packages/flutter_cockpit_devtools/doc/contracts/` or
   `doc/contracts/` when running from a published devtools package.

Load only the contract needed for the current uncertainty; do not bulk-load the
whole contract set.

## Entry Points

| Need | MCP resource | Repo file |
| ---- | ------------ | --------- |
| Protocol map | `cockpit://workspace/protocol` | `docs/contracts/flutter-cockpit-protocol.md` |
| Fast AI development loop | `cockpit://workspace/ai-development-protocol` | `docs/contracts/ai-development-protocol.md` |
| Workflow YAML/JSON syntax | `cockpit://workspace/control-workflow-protocol` | `docs/contracts/control-workflow-protocol.md` |
| Workflow machine schema | `cockpit://workspace/control-workflow-schema` | `docs/contracts/control-workflow.schema.json` |
| Bundle traceability | `cockpit://workspace/task-bundle-contract` | `docs/contracts/task-run-bundle.md` |
| Skill maintenance contract | `cockpit://workspace/skill-contract` | `docs/contracts/flutter-cockpit-skill-contract.md` |

Published devtools packages ship the same files under
`doc/contracts/`; monorepo checkouts also expose them under
`packages/flutter_cockpit_devtools/doc/contracts/`.

## Selection Rules

- Start with `cockpit://workspace/protocol` when MCP is available.
- For normal edit loops, open only the AI development protocol.
- For E2E scripts, branches, conditions, retry, or loop behavior, open the
  workflow protocol and schema.
- For produced artifacts, open the bundle contract before raw screenshots,
  recordings, or full step logs.
- For skill edits, open the skill contract.
- Do not load every contract by default.

## Stable Boundaries

- CLI stdout defaults to AI-readable output.
- Use `--stdout-format json` for pipes and `--output <path> --output-format json`
  for machine-readable files.
- Workflow files may be YAML or JSON; persisted bundle files are JSON.
- Workflow nodes include `command`, `if`, `retry`, `loop`, `startRecording`,
  and `stopRecording`.
- Unsupported platform actions must be unavailable or blocked by environment,
  not reported as successful.
- Product proof requires live state or traceable artifacts, not command success
  or file existence alone.
