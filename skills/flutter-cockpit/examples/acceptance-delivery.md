# Acceptance Delivery Example

Use this pattern when the task must end with bundle-backed evidence. Do not use it for ordinary edit -> reload -> verify loops; use rapid development validation until the user asks for acceptance, delivery, release readiness, or artifact-backed handoff.

## Recommended Flow

1. confirm this is acceptance-facing work, not a small development check
2. reuse a running app via `app.json`
3. execute `run-script` if the app is already running
4. use `run-task` if the tool should own the whole loop
5. use `validate-task` before claiming completion
6. report only the smallest useful artifact paths from the resulting bundle summary

## Example

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-script \
  --app-json /tmp/flutter_cockpit/app.json \
  --script-json /tmp/flutter_cockpit/script.json \
  --output-root /tmp/flutter_cockpit/out
```

`run-script` exits non-zero when the written bundle status is `failed`.

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/flutter_cockpit/validate_task.json \
  --stdout-format json | jq '{classification,recommendedNextStep,validationFailures}'
```

Use `--output <path>` when another step needs to reopen the full payload from disk. Add `--output-format json` only when that file must be parsed by tools such as `jq`; otherwise the file defaults to the AI-readable semantic render.

## Required Reads

- `manifest.json`
- `handoff.json`
- `delivery.json`
- `gateSummary`, CLI `read-task-bundle-summary`, or MCP `read_task_bundle_summary` output when available
- bundle summary evidence paths
- validation failures when present

The agent must not call the task complete until the validated bundle explains the final state and names the relevant screenshot or recording artifacts.

If validation shows that no bundle-backed proof was required for the user's
actual request, return to the rapid loop instead of manufacturing extra
artifacts.
