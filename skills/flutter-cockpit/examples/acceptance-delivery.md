# Acceptance Delivery Example

Use this pattern when the task must end with bundle-backed evidence.

## Recommended Flow

1. reuse a running app via `app.json`
2. execute `run-script` if the app is already running
3. use `run-task` if the tool should own the whole loop
4. use `validate-task` before claiming completion
5. report artifact paths from the resulting bundle summary

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
  --config-json /tmp/flutter_cockpit/validate_task.json | jq '{classification,recommendedNextStep,validationFailures}'
```

Use `--output-json` only when the validation result is too large for stdout or another step needs to reopen the full payload from disk.

## Required Reads

- `manifest.json`
- `handoff.json`
- `delivery.json`
- `gateSummary` or `read_task_bundle_summary` output when available
- bundle summary evidence paths
- validation failures when present

The agent must not call the task complete until the validated bundle explains the final state and names the relevant screenshot or recording artifacts.
